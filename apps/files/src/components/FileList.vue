<template>
  <!-- TODO: Take care of outside click overall and not just in files list -->
  <div :id="id" class="uk-position-relative">
    <div class="uk-flex uk-flex-column uk-height-1-1">
      <resize-observer @notify="$_resizeHeader" />
      <oc-grid
        v-if="fileData.length > 0"
        id="files-table-header"
        ref="headerRow"
        key="files-list-results-existence"
        gutter="small"
        flex
        class="oc-px-s oc-pt-rm oc-pb-xs oc-border-b"
      >
        <div id="files-list-header-checkbox" class="uk-text-center">
          <oc-checkbox
            id="filelist-check-all"
            class="oc-ml-s"
            :hide-label="true"
            :label="$gettext('Select all items')"
            :value="selectedAll"
            @input="toggleAll"
          />
        </div>
        <slot name="headerColumns" />
        <div
          v-if="$scopedSlots.rowActions"
          class="uk-text-nowrap uk-text-meta uk-text-right uk-width-small"
        >
          <translate translate-context="Short column label in files table for the actions"
            >Actions</translate
          >
        </div>
      </oc-grid>
      <div v-if="loading" id="files-list-loading-message" class="uk-position-center">
        <div class="uk-text-center">
          <oc-spinner id="files-list-progress" size="large" :aria-hidden="true" aria-label="" />
          <div class="uk-text-muted uk-text-large">
            <slot name="loadingMessage" />
          </div>
        </div>
      </div>
      <div v-else id="files-list-container" class="uk-overflow-auto">
        <div
          v-if="folderNotFound"
          key="files-list-folder-not-found"
          class="uk-position-center files-list-not-found-message"
        >
          <not-found-message />
        </div>
        <div
          v-else-if="fileData.length === 0"
          key="files-list-results-absence"
          class="uk-position-center files-list-no-content-message"
        >
          <slot name="noContentMessage" />
        </div>
        <RecycleScroller
          v-else
          v-slot="{ item: rowItem, index, active }"
          :key="fileData.length"
          class="uk-height-1-1"
          :items="fileData"
          :item-size="_rowHeight"
        >
          <div
            :data-is-visible="active"
            :class="{ 'files-list-row-disabled': rowDisabled(rowItem) }"
            @click="selectRow(rowItem, $event)"
          >
            <oc-grid
              :id="'file-row-' + rowItem.viewId"
              :ref="index === 0 ? 'firstRow' : null"
              gutter="small"
              flex
              class="file-row oc-p-s oc-border-b"
              :class="_rowClasses(rowItem)"
            >
              <div id="files-list-row-checkbox" class="uk-flex uk-flex-center">
                <oc-checkbox
                  class="oc-ml-s"
                  :value="isSelected(rowItem)"
                  :option="rowItem"
                  :label="labelSelectSingleItem(rowItem)"
                  :hide-label="true"
                  size="large"
                  @click.native.stop
                  @input="toggleFileSelect(rowItem)"
                />
              </div>
              <div
                :ref="index === 0 ? 'firstRowNameColumn' : null"
                class="uk-width-expand uk-flex uk-flex-middle"
              >
                <file-item
                  :key="rowItem.viewId"
                  :item="rowItem"
                  :show-path="showResourcePath"
                  :indicators="resourceIndicators(rowItem)"
                  :has-two-rows="hasTwoRows"
                  :display-preview="displayPreview"
                  :are-indicators-clickable="areIndicatorsClickable"
                  @click.native.stop="
                    resourceClickHandler
                      ? resourceClickHandler(rowItem)
                      : triggerDefaultResourceAction(rowItem)
                  "
                />
              </div>
              <slot name="rowColumns" :item="rowItem" :index="index" />
              <div
                v-if="actionsEnabled"
                class="uk-flex uk-flex-middle uk-flex-right"
                :class="{ 'uk-width-small': $scopedSlots.rowActions }"
              >
                <slot name="rowActions" :item="rowItem" />
                <oc-button
                  class="files-list-row-show-actions"
                  :aria-label="$gettext('Show resource actions')"
                  variation="raw"
                  @click.stop="openActionsAccordion(rowItem)"
                >
                  <oc-icon name="more_vert" class="uk-text-middle" />
                </oc-button>
              </div>
            </oc-grid>
          </div>
        </RecycleScroller>
      </div>
      <div v-if="!loading" class="uk-width-1-1 uk-text-center oc-p-s">
        <slot name="footer" />
      </div>
    </div>
  </div>
</template>
<script>
import { mapGetters, mapActions, mapState, mapMutations } from 'vuex'
import { RecycleScroller } from 'vue-virtual-scroller'
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css'

import MixinFilesListIndicators from '../mixins/filesListIndicators'
import MixinFileActions from '../mixins/fileActions'
import MixinRoutes from '../mixins/routes'

const FileItem = () => import('./FileItem.vue')
const NotFoundMessage = () => import('./FilesLists/NotFoundMessage.vue')

export default {
  name: 'FileList',
  components: {
    NotFoundMessage,
    RecycleScroller,
    FileItem
  },
  mixins: [MixinFilesListIndicators, MixinFileActions, MixinRoutes],
  props: {
    id: {
      type: String,
      required: true
    },
    fileData: {
      type: Array,
      required: true
    },
    loading: {
      type: Boolean,
      default: false
    },
    compactMode: {
      type: Boolean,
      default: false
    },
    selectableRow: {
      type: Boolean,
      required: false,
      default: true
    },
    hasTwoRows: {
      type: Boolean,
      required: false,
      default: false
    },
    rowDisabled: {
      type: Function,
      required: false,
      default: () => false
    },
    actionsEnabled: {
      type: Boolean,
      required: false,
      default: false
    },
    displayPreview: {
      type: Boolean,
      required: false,
      default: true
    },
    areIndicatorsClickable: {
      type: Boolean,
      required: false,
      default: true
    },
    resourceClickHandler: {
      type: Function,
      required: false,
      default: null
    }
  },
  computed: {
    ...mapState(['route']),
    ...mapGetters('Files', [
      'selectedFiles',
      'highlightedFile',
      'actionsInProgress',
      'currentFolder'
    ]),
    ...mapGetters(['configuration']),

    selectedAll() {
      return this.selectedFiles.length === this.fileData.length && this.fileData.length !== 0
    },

    item() {
      return this.$route.params.item
    },

    _rowHeight() {
      return this.hasTwoRows ? 67 : 55
    },

    showResourcePath() {
      return this.isFavoritesRoute || this.isTrashbinRoute
    },

    folderNotFound() {
      return (this.isListRoute || this.isPublicFilesRoute) && this.currentFolder === null
    }
  },
  watch: {
    compactMode(val) {
      // sidebar opens, recalculate header sizes
      this.$_resizeHeader()
    }
  },
  mounted() {
    this.$_resizeHeader()
  },
  methods: {
    ...mapActions('Files', [
      'setHighlightedFile',
      'resetFileSelection',
      'addFileSelection',
      'toggleFileSelection'
    ]),
    ...mapMutations('Files', ['SET_APP_SIDEBAR_EXPANDED_ACCORDION']),

    isSelected(item) {
      return this.selectedFiles.indexOf(item) > -1
    },

    isHighlighted(item) {
      return this.highlightedFile && item.id === this.highlightedFile.id
    },

    labelSelectSingleItem(item) {
      const labelSelectSingleFileText = this.$gettext('Select file %{name}')
      const labelSelectSingleFolderText = this.$gettext('Select folder %{name}')

      return this.$gettextInterpolate(
        item.type === 'file' ? labelSelectSingleFileText : labelSelectSingleFolderText,
        { name: item.name },
        true
      )
    },
    $_ocFileName(item) {
      if (this.isFavoritesRoute) {
        const pathSplit = item.path.substr(1).split('/')
        if (pathSplit.length === 2) return `${pathSplit[pathSplit.length - 2]}/${item.basename}`
        if (pathSplit.length > 2) return `…/${pathSplit[pathSplit.length - 2]}/${item.basename}`
      }
      return item.basename
    },
    _rowClasses(item) {
      const classes = []
      if (!this.hasTwoRows) {
        classes.push('file-row-s')
      }
      if (this.isHighlighted(item)) {
        classes.push('oc-background-selected')
      }
      return classes
    },
    selectRow(item, event) {
      if (!this.selectableRow || this.rowDisabled(item)) {
        return
      }

      if (item.status && (item.status === 1 || item.status === 2)) return

      event.stopPropagation()
      this.setHighlightedFile(item)
    },

    toggleFileSelect(item) {
      this.toggleFileSelection(item)
      this.$emit('toggle', item)
    },

    toggleAll() {
      if (this.selectedAll) {
        this.resetFileSelection()
      } else {
        const selectedFiles = this.fileData.slice()
        for (const item of selectedFiles) {
          if (!this.selectedFiles.includes(item)) {
            this.addFileSelection(item)
          }
        }
      }
    },

    $_resizeHeader() {
      setTimeout(() => {
        const headerRow = this.$refs.headerRow
        const firstRow = this.$refs.firstRow
        const headerCheckbox = document.querySelector('#files-list-header-checkbox')
        const firstRowCheckbox = document.querySelector('#files-list-row-checkbox')

        if (headerRow && firstRow) {
          headerRow.$el.style.width = getComputedStyle(firstRow.$el).width
        }

        if (headerCheckbox && firstRowCheckbox) {
          headerCheckbox.style.width = getComputedStyle(firstRowCheckbox).width
        }
      })
    },

    resourceIndicators(resource) {
      if (this.folderNotFound) {
        return
      }

      if (this.isListRoute || this.isFavoritesRoute) {
        return this.indicatorArray(resource)
      }
    },

    triggerDefaultResourceAction(resource) {
      let actions = this.$_fileActions_editorActions.concat(this.$_fileActions_systemActions)

      actions = actions.filter(action => {
        return (
          action.isEnabled({
            resource: resource,
            parent: this.currentFolder
          }) && action.canBeDefault
        )
      })

      actions[0].handler(resource, actions[0].handlerData)
    },

    openActionsAccordion(resource) {
      this.setHighlightedFile(resource)
      this.SET_APP_SIDEBAR_EXPANDED_ACCORDION('files-actions')
    }
  }
}
</script>

<style>
#files-table-header {
  box-sizing: border-box;
}

.files-list-row-disabled {
  opacity: 0.3;
  pointer-events: none;
}

#files-list-header-checkbox {
  width: 34px;
}

.file-row {
  box-sizing: border-box;
  min-height: 67px;
  max-height: 67px;
}
.file-row-s {
  min-height: 55px;
  max-height: 55px;
}
</style>
