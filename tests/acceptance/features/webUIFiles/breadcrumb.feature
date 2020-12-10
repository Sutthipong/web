Feature: access breadcrumb
  As a user
  I want to browse to parent folders using breadcrumb
  So that I can access resources with ease

  Background:
    Given user "user1" has been created with default attributes

  Scenario: Breadcrumb navigation should not happen on last segment
    Given user "user1" has created folder "simple-folder/subfolder"
    And user "user1" has logged in using the webUI
    When the user opens folder "simple-folder" using the webUI
    And the user opens folder "subfolder" using the webUI
    Then clickable breadcrumb for folder "simple-folder" should be displayed on the webUI
    And non-clickable breadcrumb for folder "subfolder" should be displayed on the webUI

  Scenario: Select breadcrumb inside folder with problematic name
    Given user "user1" has created folder "folder%2Fwith%2FSlashes"
    And user "user1" has created folder "folder%2Fwith%2FSlashes/subfolder"
    And user "user1" has logged in using the webUI
    When the user opens folder "folder%2Fwith%2FSlashes" using the webUI
    And the user opens folder "subfolder" using the webUI
    And the user browses to folder "folder%2Fwith%2FSlashes" using the breadcrumb on the webUI
    Then no message should be displayed on the webUI

  @issue-1883
  Scenario: Reload webUI inside the problematic folder
    Given user "user1" has created folder "folder%2Fwith%2FSlashes"
    And user "user1" has logged in using the webUI
    When the user opens folder "folder%2Fwith%2FSlashes" using the webUI
    And the user reloads the current page of the webUI
    Then there should be a not found error page displayed on the webUI
#    Then no message should be displayed on the webUI

  Scenario: breadcrumb for double quotes
    Given user "user1" has created folder "\'single-double quotes\""
    And user "user1" has created folder "\'single-double quotes\"/\"inner\" double quotes"
    And user "user1" has logged in using the webUI
    When the user opens folder "\'single-double quotes\"" using the webUI
    And the user opens folder "\"inner\" double quotes" using the webUI
    Then clickable breadcrumb for folder "\'single-double quotes\"" should be displayed on the webUI
    And non-clickable breadcrumb for folder "\"inner\" double quotes" should be displayed on the webUI

  Scenario: Check breadCrumb for home folder
    Given the property "homeFolder" of "options" has been set to "/0" in web config file
    And user "user1" has logged in using the webUI
    Then breadcrumb for folder "0" should be displayed on the webUI
