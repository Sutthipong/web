#!/usr/bin/env bash

echo 'run.sh: running acceptance-tests-drone'

declare -a UNEXPECTED_FAILED_SCENARIOS
declare -a UNEXPECTED_PASSED_SCENARIOS
declare -a UNEXPECTED_NIGHTWATCH_EXIT_STATUSES
SCENARIOS_THAT_PASSED=0
SCENARIOS_THAT_FAILED=0

yarn run acceptance-tests-drone | tee -a 'logfile.txt'
ACCEPTANCE_TESTS_EXIT_STATUS=${PIPESTATUS[0]}
echo ${ACCEPTANCE_TESTS_EXIT_STATUS}
if [ $ACCEPTANCE_TESTS_EXIT_STATUS -ne 0 ]; then
  echo 'The acceptance test exited with error status '${ACCEPTANCE_TESTS_EXIT_STATUS}

  FAILED_SCENARIOS="$(grep -F ') Scenario:' logfile.txt)"
  echo "////////////////////"
  echo "$(<logfile.txt)"
  echo "+++++++++++++++++++++++++++++++++++"
  echo ${FAILED_SCENARIOS}
  echo "----------------------------------"
  FAILED_SCENARIO_PATHS=()
  for FAILED_SCENARIO in ${FAILED_SCENARIOS}; do
    if [[ $FAILED_SCENARIO =~ "tests/acceptance/features/" ]]; then
      SUITE_PATH=$(dirname ${FAILED_SCENARIO})
      SUITE=$(basename ${SUITE_PATH})
      SCENARIO=$(basename ${FAILED_SCENARIO})
      SUITE_SCENARIO="${SUITE}/${SCENARIO}"
      FAILED_SCENARIO_PATHS+="${SUITE_SCENARIO} "
    fi
  done
fi

echo ${FAILED_SCENARIO_PATHS}

if [ $ACCEPTANCE_TESTS_EXIT_STATUS -eq 0 ]; then
  # Find the count of scenarios that passed
  SCENARIO_RESULTS_COLORED=$(grep -E '^[0-9]+[[:space:]]scenario(|s)[[:space:]]\(' logfile.txt)
  SCENARIO_RESULTS=$(echo "${SCENARIO_RESULTS_COLORED}" | sed "s/\x1b[^m]*m//g")
  # They all passed, so just get the first number.
  # The text looks like "1 scenario (1 passed)" or "123 scenarios (123 passed)"
  [[ ${SCENARIO_RESULTS} =~ ([0-9]+) ]]
  SCENARIOS_THAT_PASSED=$((SCENARIOS_THAT_PASSED + BASH_REMATCH[1]))
elif [ $ACCEPTANCE_TESTS_EXIT_STATUS -ne 0 ]; then
  echo 'The acceptance test run exited with error status '${ACCEPTANCE_TESTS_EXIT_STATUS}
  # Find the count of scenarios that passed and failed
  SCENARIO_RESULTS_COLORED=$(grep -E '^[0-9]+[[:space:]]scenario(|s)[[:space:]]\(' logfile.txt)
  SCENARIO_RESULTS=$(echo "${SCENARIO_RESULTS_COLORED}" | sed "s/\x1b[^m]*m//g")
  if [[ ${SCENARIO_RESULTS} =~ [0-9]+[^0-9]+([0-9]+)[^0-9]+([0-9]+)[^0-9]+ ]]; then
    # Some passed and some failed, we got the second and third numbers.
    # The text looked like "15 scenarios (6 passed, 9 failed)"
    SCENARIOS_THAT_PASSED=$((SCENARIOS_THAT_PASSED + BASH_REMATCH[1]))
    SCENARIOS_THAT_FAILED=$((SCENARIOS_THAT_FAILED + BASH_REMATCH[2]))
  elif [[ ${SCENARIO_RESULTS} =~ [0-9]+[^0-9]+([0-9]+)[^0-9]+ ]]; then
    # All failed, we got the second number.
    # The text looked like "4 scenarios (4 failed)"
    SCENARIOS_THAT_FAILED=$((SCENARIOS_THAT_FAILED + BASH_REMATCH[1]))
  fi
fi

if [ -n "${EXPECTED_FAILURES_FILE}" ]; then
  echo "Checking expected failures"

  #  printf "%s" "$(<$EXPECTED_FAILURES_FILE)"
  #  echo "$(<$EXPECTED_FAILURES_FILE)"

  # Check that every failed scenario is in the list of expected failures
  for FAILED_SCENARIO_PATH in ${FAILED_SCENARIO_PATHS}; do
    grep -x ${FAILED_SCENARIO_PATH} ${EXPECTED_FAILURES_FILE} >/dev/null
    if [ $? -ne 0 ]; then
      echo "Error: Scenario ${FAILED_SCENARIO_PATH} failed but was not expected to fail."
      UNEXPECTED_FAILED_SCENARIOS+="${FAILED_SCENARIO_PATH} "
    fi
  done

  # Check that every scenario in the expected failures did fail
  while IFS= read -r line; do
    # Ignore comment lines (starting with hash) or the empty lines
    if [[ ("$line" =~ ^#) || (-z "$line") ]]; then
      continue
    fi
    EXPECTED_FAILURE_SUITE=$(dirname "${line}")

    if [ -n "${TEST_PATHS}" ]; then
      # If the expected failure is not in the suite that is currently being run,
      # then do not try and check that it failed.
      RUN_SUITE_SCENARIO=()
      for TEST_PATH in "${TEST_PATHS}"; do
        SUITE=$(basename ${TEST_PATH})
        RUN_SUITE_SCENARIO+="^${SUITE}/ "
      done
      REGEX_TO_MATCH="^${EXPECTED_FAILURE_SUITE}/"

      if ! [[ " ${RUN_SUITE_SCENARIO[@]} " == *"${REGEX_TO_MATCH} "* ]]; then
        continue
      fi
    fi

    if [ -n "${TEST_CONTEXT}" ]; then
      # If the expected failure is not in the suite that is currently being run,
      # then do not try and check that it failed.
      RUN_SUITE_SCENARIO=()
      for CONTEXT in "${TEST_CONTEXT}"; do
        RUN_SUITE_SCENARIO+="^${CONTEXT}/ "
      done
      REGEX_TO_MATCH="^${EXPECTED_FAILURE_SUITE}/"

      if ! [[ " ${RUN_SUITE_SCENARIO[@]} " == *"${REGEX_TO_MATCH} "* ]]; then
        continue
      fi
    fi

    if [ ${ACCEPTANCE_TESTS_EXIT_STATUS} -ne 0 ] && [ ${#FAILED_SCENARIO_PATHS[@]} -eq 0 ]
	then
		# Nightwatch had some problem and there were no failed scenarios reported
		# So the problem is something else.
		# Possibly there were missing step definitions. Or Nightwatch crashed badly, or...
		echo "Unexpected failure or crash"
		UNEXPECTED_NIGHTWATCH_EXIT_STATUSES+=("The running suite had nightwatch exit status ${ACCEPTANCE_TESTS_EXIT_STATUS}")
	fi


    if ! [[ " ${FAILED_SCENARIO_PATHS[@]} " == *"$line"* ]]; then
      echo "Error: Scenario $line was expected to fail but did not fail."
      UNEXPECTED_PASSED_SCENARIOS+="$line "
    fi
  done <"$EXPECTED_FAILURES_FILE"
fi

for FAILED_SCENARIO_PATH in ${FAILED_SCENARIO_PATHS}; do

  if [ -n "${EXPECTED_FAILURES_FILE}" ]; then
    grep -x ${FAILED_SCENARIO_PATH} ${EXPECTED_FAILURES_FILE} >/dev/null

    if [ $? -eq 0 ]; then
      echo "Notice: Scenario ${FAILED_SCENARIO_PATH} is expected to fail so do not rerun it."
      continue
    fi
  fi

  echo "Rerun failed scenario: ${FAILED_SCENARIO_PATH}"
  yarn run acceptance-tests-drone tests/acceptance/features/${FAILED_SCENARIO_PATH} | tee -a 'logfile.txt'
  BEHAT_EXIT_STATUS=${PIPESTATUS[0]}
  if [ ${BEHAT_EXIT_STATUS} -eq 0 ]; then
    # The scenario was not expected to fail but had failed and is present in the
    # unexpected_failures list. We've checked the scenario with a re-run and
    # it passed. So remove it from the unexpected_failures list.
    for i in "${!UNEXPECTED_FAILED_SCENARIOS[@]}"; do
      if [ "${UNEXPECTED_FAILED_SCENARIOS[i]}" == "${FAILED_SCENARIO_PATH}" ]; then
        unset "UNEXPECTED_FAILED_SCENARIOS[i]"
      fi
    done
  else
    echo "test rerun failed with exit status: ${BEHAT_EXIT_STATUS}"
    # The scenario is not expected to fail but is failing also after the rerun.
    # Since it is already reported in the unexpected_failures list, there is no
    # need to touch that again. Continue processing the next scenario to rerun.
  fi
done

TOTAL_SCENARIOS=$((SCENARIOS_THAT_PASSED + SCENARIOS_THAT_FAILED))

echo "runsh: Total ${TOTAL_SCENARIOS} scenarios (${SCENARIOS_THAT_PASSED} passed, ${SCENARIOS_THAT_FAILED} failed)"

if [ ${#UNEXPECTED_FAILED_SCENARIOS[@]} -gt 0 ]; then
  UNEXPECTED_FAILURE=true
else
  UNEXPECTED_FAILURE=false
fi

if [ ${#UNEXPECTED_PASSED_SCENARIOS[@]} -gt 0 ]; then
  UNEXPECTED_SUCCESS=true
else
  UNEXPECTED_SUCCESS=false
fi

if [ ${#UNEXPECTED_NIGHTWATCH_EXIT_STATUSES[@]} -gt 0 ]
then
	UNEXPECTED_NIGHTWATCH_EXIT_STATUS=true
else
	UNEXPECTED_NIGHTWATCH_EXIT_STATUS=false
fi

if [ "${UNEXPECTED_FAILURE}" = false ] && [ "${UNEXPECTED_SUCCESS}" = false ] && [ "${UNEXPECTED_NIGHTWATCH_EXIT_STATUS}" = false ]; then
  FINAL_EXIT_STATUS=0
else
  FINAL_EXIT_STATUS=1
fi

if [ -n "${EXPECTED_FAILURES_FILE}" ]
then
	echo "runsh: Exit code after checking expected failures: ${FINAL_EXIT_STATUS}"
fi

if [ "${UNEXPECTED_FAILURE}" = true ]
then
  tput setaf 3; echo "runsh: Total unexpected failed scenarios throughout the test run:"
  tput setaf 1; printf "%s\n" "${UNEXPECTED_FAILED_SCENARIOS[@]}"
else
  tput setaf 2; echo "runsh: There were no unexpected failures."
fi

if [ "${UNEXPECTED_SUCCESS}" = true ]
then
  tput setaf 3; echo "runsh: Total unexpected passed scenarios throughout the test run:"
  tput setaf 1; printf "%s\n" "${UNEXPECTED_PASSED_SCENARIOS[@]}"
else
  tput setaf 2; echo "runsh: There were no unexpected success."
fi

if [ "${UNEXPECTED_NIGHTWATCH_EXIT_STATUS}" = true ]
then
  tput setaf 3; echo "runsh: The following test runs exited with non-zero status:"
  tput setaf 1; printf "%s\n" "${UNEXPECTED_NIGHTWATCH_EXIT_STATUSES[@]}"
fi

exit ${FINAL_EXIT_STATUS}
