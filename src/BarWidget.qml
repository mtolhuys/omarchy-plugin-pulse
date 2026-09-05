import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root

  moduleName: "io.github.mtolhuys.plugin-pulse"

  readonly property string buildIdentity: "plugin-pulse-widget-v014"
  readonly property var pulseService: bar && bar.shell
    ? bar.shell.serviceFor("io.github.mtolhuys.plugin-pulse") : null
  readonly property var snapshot: pulseService ? pulseService.snapshot : Model.emptySnapshot()
  readonly property bool collecting: pulseService && pulseService.collectState === "collecting"
  readonly property bool busy: collecting
  readonly property string activeMetric: metric
  readonly property var enabledPluginIds: {
    var ids = []
    var plugins = snapshot.plugins || []
    for (var i = 0; i < plugins.length; i++) {
      if (plugins[i] && plugins[i].enabled === true)
        ids.push(plugins[i].id)
    }
    return ids
  }
  readonly property var chartSeries: Model.chartSeries(snapshot, activeMetric, enabledPluginIds)
  readonly property bool estimated: snapshot.hasEstimatedHistory === true
  readonly property string authorValue: pulseService ? String(pulseService.authorDraft || snapshot.author || "") : ""
  readonly property string resolutionValue: pulseService ? String(pulseService.resolution || "daily") : "daily"

  property bool popupOpen: false
  property string metric: "views"
  property string authorEdit: ""
  property string settingsPanel: ""
  property bool confirmClear: false
  property string confirmDeleteAuthor: ""
  property string confirmRemovePlugin: ""
  property string authorAddDraft: ""
  property string pluginAddDraft: ""
  property real selectedTs: 0

  readonly property bool settingsOpen: settingsPanel !== ""
  readonly property int enabledAuthorCount: {
    var authors = snapshot.authors || []
    var n = 0
    for (var i = 0; i < authors.length; i++) {
      if (authors[i] && (authors[i].enabled === true || authors[i].active === true))
        n++
    }
    return n
  }
  readonly property string enabledAuthorsLabel: {
    var authors = snapshot.authors || []
    var keys = []
    for (var i = 0; i < authors.length; i++) {
      if (authors[i] && (authors[i].enabled === true || authors[i].active === true))
        keys.push(String(authors[i].key || ""))
    }
    if (!keys.length) return "no authors"
    if (keys.length === 1) return keys[0]
    if (keys.length === 2) return keys[0] + " · " + keys[1]
    return keys.length + " authors"
  }

  readonly property var timeSlice: Model.sliceAtTime(chartSeries, selectedTs || 0)

  readonly property bool opened: popupOpen
  readonly property bool popoutSwitchClosing: false
  readonly property real openPanelIndicatorWidth: button.labelWidth

  function open() {
    popupOpen = true
    selectedTs = 0
    authorEdit = authorValue || ""
    if (pulseService) {
      if (!snapshot.ok) pulseService.refreshSnapshot()
      if (!snapshot.lastCollectAt) pulseService.collectNow()
    }
  }

  function close() {
    settingsPanel = ""
    confirmClear = false
    confirmDeleteAuthor = ""
    confirmRemovePlugin = ""
    authorAddDraft = ""
    pluginAddDraft = ""
    popupOpen = false
  }
  function closeForPopoutSwitch() { close() }
  function toggle() { popupOpen ? close() : open() }

  function setResolution(value) {
    selectedTs = 0
    if (pulseService) pulseService.setResolution(value)
  }

  function setMetric(value) {
    selectedTs = 0
    metric = value
  }

  function refresh() {
    selectedTs = 0
    if (pulseService) pulseService.collectNow()
  }

  function clearTimeSelection() {
    selectedTs = 0
  }

  function toggleSettingsPanel(panel) {
    var next = String(panel || "")
    settingsPanel = settingsPanel === next ? "" : next
    confirmDeleteAuthor = ""
    confirmRemovePlugin = ""
  }

  function authorIsEnabled(modelData) {
    return !!(modelData && (modelData.enabled === true || modelData.active === true))
  }

  function toggleAuthorRow(key, currentlyEnabled) {
    if (!pulseService) return
    var author = String(key || "").trim()
    if (!author) return
    authorEdit = author
    confirmDeleteAuthor = ""
    if (currentlyEnabled)
      pulseService.disableAuthor(author)
    else
      pulseService.enableAuthor(author)
  }

  function addTrackedAuthor() {
    if (!pulseService) return
    var author = String(authorAddDraft || "").trim()
    if (!author) return
    authorEdit = author
    authorAddDraft = ""
    confirmDeleteAuthor = ""
    pulseService.addAuthor(author)
  }

  function requestDeleteAuthor(key) {
    var author = String(key || "").trim()
    if (!author) return
    if (confirmDeleteAuthor === author) {
      confirmDeleteAuthor = ""
      if (pulseService) pulseService.deleteAuthor(author)
      return
    }
    confirmDeleteAuthor = author
  }

  function addTrackedPlugin() {
    if (!pulseService) return
    var id = String(pluginAddDraft || "").trim()
    if (!id) return
    pluginAddDraft = ""
    confirmRemovePlugin = ""
    pulseService.addPlugin(id)
  }

  function requestRemovePlugin(pluginId) {
    var id = String(pluginId || "").trim()
    if (!id) return
    if (confirmRemovePlugin === id) {
      confirmRemovePlugin = ""
      if (pulseService) pulseService.removePlugin(id)
      return
    }
    confirmRemovePlugin = id
  }

  function chipLabel(name, id) {
    var label = Model.shortPluginName(name, id)
    if (label.length > 22)
      return label.slice(0, 21) + "…"
    return label
  }

  function togglePlugin(pluginId, enabled) {
    if (pulseService) pulseService.togglePlugin(pluginId, enabled)
  }

  readonly property bool allPluginsSelected: {
    var plugins = snapshot.plugins || []
    if (!plugins.length)
      return false
    for (var i = 0; i < plugins.length; i++) {
      if (!plugins[i] || plugins[i].enabled !== true)
        return false
    }
    return true
  }

  function setAllPlugins(enabled) {
    if (pulseService)
      pulseService.setAllPlugins(enabled === true)
  }

  function colorForKey(key) {
    var k = String(key || "")
    if (k.indexOf("#") === 0)
      return k
    if (key === "urgent") return Color.urgent
    if (key === "muted") return Color.muted
    if (key === "foreground") return Color.popups.text
    return Color.accent
  }

  function statusLabel() {
    if (!pulseService) return "Service unavailable"
    if (collecting) return "Refreshing marketplace stats…"
    if (pulseService.collectState === "failed" || pulseService.snapshotState === "failed")
      return pulseService.lastError || "Refresh failed"
    if (!snapshot.ok) return "Waiting for first collect"
    return "Tracking " + snapshot.series.length + " plugin"
      + (snapshot.series.length === 1 ? "" : "s")
  }

  function freshnessLabel() {
    if (!snapshot.lastCollectAt) return "NOT REFRESHED"
    return Model.formatWhen(snapshot.lastCollectAt).toUpperCase()
  }

  function stateSnapshot() {
    return {
      buildIdentity: buildIdentity,
      opened: opened,
      resolution: resolutionValue,
      metric: metric,
      author: authorValue,
      seriesCount: snapshot.series ? snapshot.series.length : 0,
      estimated: estimated,
      dbBytes: snapshot.dbBytes,
      collecting: collecting
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onAuthorValueChanged: {
    if (!authorAddField.activeFocus) authorEdit = authorValue || authorEdit
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.barSize
    tooltipText: "Plugin Pulse — " + root.statusLabel() + " · left open · middle refresh"
    active: root.estimated || root.collecting
    activeColor: Color.accent
    Accessible.name: "Plugin Pulse"
    Accessible.role: Accessible.Button

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    PulseIcon {
      width: Math.min(parent.width, parent.height) * 0.55
      height: width
      anchors.centerIn: parent
      foreground: button.foreground
      accent: button.activeColor
      active: button.active || root.collecting
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: root.settingsPanel === "authors" ? authorAddField
      : (root.settingsPanel === "plugins" ? pluginAddField : lineChart)
    contentWidth: popup.fittedContentWidth(Style.space(520))
    contentHeight: popup.fittedContentHeight(panelColumn.implicitHeight)

    Flickable {
      id: panelScroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: panelColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height + 2
      QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AlwaysOff }
      QQC.ScrollBar.horizontal: QQC.ScrollBar { policy: QQC.ScrollBar.AlwaysOff }
      focus: true

      Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: {
          if (root.confirmDeleteAuthor) root.confirmDeleteAuthor = ""
          else if (root.confirmRemovePlugin) root.confirmRemovePlugin = ""
          else if (root.confirmClear) root.confirmClear = false
          else if (root.settingsPanel !== "") root.settingsPanel = ""
          else root.close()
        }
      }

      Shortcut {
        sequence: "Left"
        enabled: root.popupOpen && !root.settingsOpen
        context: Qt.WindowShortcut
        onActivated: lineChart.stepBy(-1)
      }

      Shortcut {
        sequence: "Right"
        enabled: root.popupOpen && !root.settingsOpen
        context: Qt.WindowShortcut
        onActivated: lineChart.stepBy(1)
      }

      Column {
        id: panelColumn
        width: panelScroll.width
        spacing: Style.space(5)

        Item {
          width: parent.width
          height: Math.max(headerIcon.height, refreshButton.height, headerTitles.height)

          Row {
            id: headerLeft
            anchors.left: parent.left
            anchors.right: refreshButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            BorderSurface {
              id: headerIcon
              width: Style.space(28)
              height: width
              color: Style.selectedFillFor(Color.accent, Color.accent)
              borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)
              radius: Style.cornerRadius

              PulseIcon {
                width: parent.width * 0.62
                height: width
                anchors.centerIn: parent
                foreground: Color.accent
                accent: Color.accent
                active: true
              }
            }

            Column {
              id: headerTitles
              width: Math.max(0, headerLeft.width - Style.space(28) - Style.space(10))
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: "Plugin Pulse"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }

              Text {
                width: parent.width
                text: root.statusLabel()
                color: root.collecting ? Color.accent : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }
            }
          }

          Button {
            id: refreshButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "↻"
            tooltipText: "Refresh marketplace stats"
            focusable: true
            enabled: !!root.pulseService && !root.busy
            opacity: enabled ? 1 : 0.35
            onClicked: root.refresh()
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: [
              { id: "hourly", label: "Hourly" },
              { id: "daily", label: "Daily" },
              { id: "weekly", label: "Weekly" },
              { id: "monthly", label: "Monthly" }
            ]

            delegate: Button {
              required property var modelData
              text: modelData.label
              selected: root.resolutionValue === modelData.id
              focusable: true
              onClicked: root.setResolution(modelData.id)
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: [
              { id: "views", label: "Views" },
              { id: "copies", label: "Copies" },
              { id: "hearts", label: "Hearts" }
            ]

            delegate: Button {
              required property var modelData
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              selected: root.metric === modelData.id
              bordered: root.metric === modelData.id
              focusable: true
              onClicked: root.setMetric(modelData.id)
            }
          }

          Item { width: Style.space(8); height: 1 }

          Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Author"
            selected: root.settingsPanel === "authors"
            bordered: root.settingsPanel === "authors"
            focusable: true
            onClicked: root.toggleSettingsPanel("authors")
          }

          Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Plugins"
            selected: root.settingsPanel === "plugins"
            bordered: root.settingsPanel === "plugins"
            focusable: true
            onClicked: root.toggleSettingsPanel("plugins")
          }
        }

        BorderSurface {
          visible: root.settingsPanel === "authors"
          width: parent.width
          implicitHeight: settingsColumn.implicitHeight + Style.space(12)
          color: Style.normalFillFor(Color.popups.text, Color.accent)
          borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
          radius: Style.cornerRadius

          Column {
            id: settingsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(8)
            spacing: Style.space(6)

            Text {
              width: parent.width
              text: "Authors"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              textFormat: Text.PlainText
            }

            Text {
              width: parent.width
              text: "Enable adds that author’s plugins to the pool · trash removes the author"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }

            Flickable {
              id: authorsFlick
              width: parent.width
              height: Math.min(
                Style.space(132),
                Math.max(Style.space(36), authorsList.implicitHeight)
              )
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              contentWidth: width
              contentHeight: authorsList.implicitHeight
              interactive: contentHeight > height + 1
              flickableDirection: Flickable.VerticalFlick
              QQC.ScrollBar.vertical: QQC.ScrollBar {
                id: authorsScrollBar
                policy: authorsFlick.contentHeight > authorsFlick.height
                  ? QQC.ScrollBar.AlwaysOn
                  : QQC.ScrollBar.AlwaysOff
                implicitWidth: 2
                width: 2
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                contentItem: Rectangle {
                  implicitWidth: 2
                  width: 2
                  radius: 1
                  color: Util.alpha(
                    Color.popups.text,
                    authorsScrollBar.hovered || authorsScrollBar.pressed ? 0.5 : 0.28
                  )
                }
                background: Item { implicitWidth: 2 }
              }

              Column {
                id: authorsList
                width: Math.max(1, authorsFlick.width - 6)
                spacing: Style.space(3)

                Repeater {
                  model: root.snapshot.authors || []

                  delegate: Row {
                    required property var modelData
                    width: authorsList.width
                    spacing: Style.space(4)

                    Button {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Math.max(
                        Style.space(80),
                        parent.width - trashAuthorButton.width - Style.space(4)
                      )
                      text: (root.authorIsEnabled(modelData) ? "✓  " : "") + Model.safeLabel(modelData.key)
                      leftAlign: true
                      selected: root.authorIsEnabled(modelData)
                      bordered: root.authorIsEnabled(modelData)
                      focusable: true
                      tooltipText: modelData.pluginCount + " plugins · "
                        + modelData.sampleCount + " samples"
                      onClicked: root.toggleAuthorRow(modelData.key, root.authorIsEnabled(modelData))
                    }

                    Button {
                      id: trashAuthorButton
                      anchors.verticalCenter: parent.verticalCenter
                      iconText: root.confirmDeleteAuthor === String(modelData.key) ? "!" : "⌫"
                      bordered: root.confirmDeleteAuthor === String(modelData.key)
                      selected: root.confirmDeleteAuthor === String(modelData.key)
                      foreground: Color.urgent
                      accent: Color.urgent
                      focusable: true
                      Accessible.name: root.confirmDeleteAuthor === String(modelData.key)
                        ? "Confirm purge " + modelData.key
                        : "Delete " + modelData.key
                      tooltipText: root.confirmDeleteAuthor === String(modelData.key)
                        ? "Click again to permanently purge " + modelData.key
                        : "Delete " + modelData.key + " and purge stored plugins"
                      onClicked: root.requestDeleteAuthor(modelData.key)
                    }
                  }
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: authorAddField
                width: parent.width - addAuthorButton.width - Style.space(6)
                text: root.authorAddDraft
                placeholderText: "add author"
                selectByMouse: true
                Accessible.name: "Add author"
                onTextEdited: root.authorAddDraft = text
                onAccepted: root.addTrackedAuthor()
                TapHandler { onTapped: authorAddField.forceActiveFocus() }
              }

              Button {
                id: addAuthorButton
                text: "Add"
                bordered: true
                selected: true
                focusable: true
                onClicked: root.addTrackedAuthor()
              }
            }
          }
        }

        BorderSurface {
          visible: root.settingsPanel === "plugins"
          width: parent.width
          implicitHeight: pluginsSettingsColumn.implicitHeight + Style.space(12)
          color: Style.normalFillFor(Color.popups.text, Color.accent)
          borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
          radius: Style.cornerRadius

          Column {
            id: pluginsSettingsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(8)
            spacing: Style.space(6)

            Text {
              width: parent.width
              text: "Plugins"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              textFormat: Text.PlainText
            }

            Text {
              width: parent.width
              text: "Pool of tracked plugins · trash removes one · chart chips still toggle visibility"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }

            Flickable {
              id: pluginsFlick
              width: parent.width
              height: Math.min(
                Style.space(132),
                Math.max(Style.space(36), pluginsList.implicitHeight)
              )
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              contentWidth: width
              contentHeight: pluginsList.implicitHeight
              interactive: contentHeight > height + 1
              flickableDirection: Flickable.VerticalFlick
              QQC.ScrollBar.vertical: QQC.ScrollBar {
                id: pluginsScrollBar
                policy: pluginsFlick.contentHeight > pluginsFlick.height
                  ? QQC.ScrollBar.AlwaysOn
                  : QQC.ScrollBar.AlwaysOff
                implicitWidth: 2
                width: 2
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                contentItem: Rectangle {
                  implicitWidth: 2
                  width: 2
                  radius: 1
                  color: Util.alpha(
                    Color.popups.text,
                    pluginsScrollBar.hovered || pluginsScrollBar.pressed ? 0.5 : 0.28
                  )
                }
                background: Item { implicitWidth: 2 }
              }

              Column {
                id: pluginsList
                width: Math.max(1, pluginsFlick.width - 6)
                spacing: Style.space(3)

                Repeater {
                  model: root.snapshot.plugins || []

                  delegate: Row {
                    required property var modelData
                    width: pluginsList.width
                    spacing: Style.space(4)

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Math.max(
                        Style.space(80),
                        parent.width - trashPluginButton.width - Style.space(4)
                      )
                      spacing: Style.space(1)

                      Text {
                        width: parent.width
                        text: Model.safeLabel(root.chipLabel(modelData.name, modelData.id))
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                      }

                      Text {
                        width: parent.width
                        text: Model.safeLabel(
                          (modelData.author ? modelData.author + " · " : "")
                          + String(modelData.id || "")
                        )
                        color: Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideMiddle
                        textFormat: Text.PlainText
                      }
                    }

                    Button {
                      id: trashPluginButton
                      anchors.verticalCenter: parent.verticalCenter
                      iconText: root.confirmRemovePlugin === String(modelData.id) ? "!" : "⌫"
                      bordered: root.confirmRemovePlugin === String(modelData.id)
                      selected: root.confirmRemovePlugin === String(modelData.id)
                      foreground: Color.urgent
                      accent: Color.urgent
                      focusable: true
                      Accessible.name: root.confirmRemovePlugin === String(modelData.id)
                        ? "Confirm remove " + modelData.id
                        : "Remove " + modelData.id
                      tooltipText: root.confirmRemovePlugin === String(modelData.id)
                        ? "Click again to remove " + modelData.id
                        : "Remove " + modelData.id + " from the pool"
                      onClicked: root.requestRemovePlugin(modelData.id)
                    }
                  }
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: pluginAddField
                width: parent.width - addPluginButton.width - Style.space(6)
                text: root.pluginAddDraft
                placeholderText: "plugin id"
                selectByMouse: true
                Accessible.name: "Add plugin"
                onTextEdited: root.pluginAddDraft = text
                onAccepted: root.addTrackedPlugin()
                TapHandler { onTapped: pluginAddField.forceActiveFocus() }
              }

              Button {
                id: addPluginButton
                text: "Add"
                bordered: true
                selected: true
                focusable: true
                onClicked: root.addTrackedPlugin()
              }
            }
          }
        }

        BorderSurface {
          width: parent.width
          height: root.settingsOpen
            ? Style.space(120)
            : (root.selectedTs > 0 ? Style.space(260) : Style.space(168))
          color: Util.alpha(Color.popups.text, 0.035)
          borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
          radius: Style.cornerRadius
          clip: true

          Column {
            anchors.fill: parent
            anchors.margins: root.selectedTs > 0 && !root.settingsOpen
              ? Style.space(8) : Style.space(10)
            spacing: Style.space(4)

            LineChart {
              id: lineChart
              width: parent.width
              height: root.settingsOpen
                ? Style.space(100)
                : (root.selectedTs > 0 ? Style.space(120) : Style.space(148))
              series: root.chartSeries
              metric: root.metric
              resolution: root.resolutionValue
              selectedTs: root.selectedTs
              accentColor: Color.accent
              foregroundColor: Color.popups.text
              mutedColor: Color.muted
              urgentColor: Color.urgent
              onSelectionChanged: function(ts) { root.selectedTs = ts }
            }

            Row {
              width: parent.width
              visible: root.selectedTs > 0 && !root.settingsOpen
              height: visible ? Style.space(16) : 0
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - clearSliceButton.width - Style.space(6)
                text: Model.formatSliceWhen(root.selectedTs, root.resolutionValue)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }

              Button {
                id: clearSliceButton
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear"
                focusable: true
                tooltipText: "Clear time selection"
                onClicked: root.clearTimeSelection()
              }
            }

            SliceChart {
              width: parent.width
              height: visible ? Style.space(100) : 0
              visible: root.selectedTs > 0 && !root.settingsOpen
              slices: root.timeSlice
              title: Model.formatSliceWhen(root.selectedTs, root.resolutionValue)
              accentColor: Color.accent
              foregroundColor: Color.popups.text
              mutedColor: Color.muted
            }
          }
        }

        BorderSurface {
          width: parent.width
          height: Style.space(176)
          color: Style.normalFillFor(Color.popups.text, Color.accent)
          borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
          radius: Style.cornerRadius
          clip: true

          Column {
            id: totalsColumn
            anchors.fill: parent
            anchors.margins: Style.space(9)
            spacing: Style.space(6)

            readonly property real scrollGutter: 6
            readonly property real contentW: Math.max(1, width - scrollGutter)
            readonly property real nameColW: contentW * 0.40
            readonly property real metricColW: (contentW - nameColW) / 3

            Row {
              width: totalsColumn.contentW

              Text {
                width: parent.width - freshnessText.width
                text: "Totals"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
                textFormat: Text.PlainText
              }

              Text {
                id: freshnessText
                text: root.freshnessLabel()
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.6
                textFormat: Text.PlainText
              }
            }

            Row {
              width: totalsColumn.contentW

              Item { width: totalsColumn.nameColW; height: 1 }

              Text {
                width: totalsColumn.metricColW
                text: "VIEWS"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.7
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
              }

              Text {
                width: totalsColumn.metricColW
                text: "COPIES"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.7
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
              }

              Text {
                width: totalsColumn.metricColW
                text: "HEARTS"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.7
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
              }
            }

            Row {
              width: totalsColumn.contentW

              Item { width: totalsColumn.nameColW; height: 1 }

              Text {
                width: totalsColumn.metricColW
                text: Model.formatCount(root.snapshot.totals.views)
                color: root.metric === "views" ? Color.accent : Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
              }

              Text {
                width: totalsColumn.metricColW
                text: Model.formatCount(root.snapshot.totals.copies)
                color: root.metric === "copies" ? Color.accent : Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
              }

              Text {
                width: totalsColumn.metricColW
                text: Model.formatCount(root.snapshot.totals.hearts)
                color: root.metric === "hearts" ? Color.accent : Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
              }
            }

            Flickable {
              id: totalsSeriesFlick
              width: parent.width
              height: Math.max(Style.space(56), parent.height - y)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              contentWidth: width
              contentHeight: totalsSeriesColumn.implicitHeight
              interactive: contentHeight > height + 1
              flickableDirection: Flickable.VerticalFlick
              QQC.ScrollBar.vertical: QQC.ScrollBar {
                id: totalsScrollBar
                policy: totalsSeriesFlick.contentHeight > totalsSeriesFlick.height
                  ? QQC.ScrollBar.AlwaysOn
                  : QQC.ScrollBar.AlwaysOff
                implicitWidth: 2
                width: 2
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                minimumSize: 0.12
                contentItem: Rectangle {
                  implicitWidth: 2
                  width: 2
                  radius: 1
                  color: Util.alpha(
                    Color.popups.text,
                    totalsScrollBar.hovered || totalsScrollBar.pressed ? 0.5 : 0.28
                  )
                }
                background: Item { implicitWidth: 2 }
              }

              Column {
                id: totalsSeriesColumn
                width: Math.max(1, totalsSeriesFlick.width - totalsColumn.scrollGutter)
                spacing: Style.space(3)

                Repeater {
                  model: root.snapshot.series || []

                  delegate: Row {
                    required property var modelData
                    required property int index
                    width: totalsSeriesColumn.width

                    Item {
                      width: totalsColumn.nameColW
                      height: Math.max(nameDot.height, nameLabel.height)
                      anchors.verticalCenter: parent.verticalCenter

                      Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)

                        Rectangle {
                          id: nameDot
                          anchors.verticalCenter: parent.verticalCenter
                          width: 8
                          height: 8
                          radius: width / 2
                          color: root.colorForKey(Model.colorForPluginId(modelData.id, root.snapshot.plugins))
                        }

                        Text {
                          id: nameLabel
                          width: Math.max(0, parent.width - nameDot.width - Style.space(8))
                          text: Model.safeLabel(root.chipLabel(modelData.name, modelData.id))
                          color: Color.popups.text
                          font.family: Style.font.family
                          font.pixelSize: Style.font.bodySmall
                          elide: Text.ElideRight
                          textFormat: Text.PlainText
                        }
                      }
                    }

                    Text {
                      width: totalsColumn.metricColW
                      text: Model.formatCount(modelData.totals.views)
                      color: Color.popups.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      horizontalAlignment: Text.AlignRight
                      textFormat: Text.PlainText
                    }

                    Text {
                      width: totalsColumn.metricColW
                      text: Model.formatCount(modelData.totals.copies)
                      color: Color.popups.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      horizontalAlignment: Text.AlignRight
                      textFormat: Text.PlainText
                    }

                    Text {
                      width: totalsColumn.metricColW
                      text: Model.formatCount(modelData.totals.hearts)
                      color: Color.popups.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      horizontalAlignment: Text.AlignRight
                      textFormat: Text.PlainText
                    }
                  }
                }
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(5)

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - allPluginsButton.width - Style.space(8)
              text: "Plugins"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
              textFormat: Text.PlainText
            }

            Button {
              id: allPluginsButton
              anchors.verticalCenter: parent.verticalCenter
              text: root.allPluginsSelected ? "None" : "All"
              bordered: true
              focusable: true
              tooltipText: root.allPluginsSelected
                ? "Deselect all plugins"
                : "Select all plugins"
              onClicked: root.setAllPlugins(!root.allPluginsSelected)
            }
          }

          Flow {
            width: parent.width
            spacing: Style.space(5)

            Repeater {
              model: root.snapshot.plugins || []

              delegate: Row {
                required property var modelData
                required property int index
                spacing: Style.space(4)

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 8
                  height: 8
                  radius: width / 2
                  color: root.colorForKey(Model.colorForPluginId(modelData.id, root.snapshot.plugins))
                  opacity: modelData.enabled === true ? 1 : 0.35
                }

                Button {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.chipLabel(modelData.name, modelData.id)
                  selected: modelData.enabled === true
                  focusable: true
                  tooltipText: Model.shortPluginName(modelData.name, modelData.id)
                    + (modelData.enabled ? " · hide" : " · show")
                  onClicked: root.togglePlugin(modelData.id, !(modelData.enabled === true))
                }
              }
            }
          }
        }

        BorderSurface {
          width: parent.width
          implicitHeight: storageRow.implicitHeight + Style.space(10)
          color: Style.normalFillFor(Color.popups.text, Color.accent)
          borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
          radius: Style.cornerRadius

          Row {
            id: storageRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(8)
            spacing: Style.space(6)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - clearButton.width
                - (root.confirmClear ? cancelClearButton.width + Style.space(12) : Style.space(6))
              text: Model.formatBytes(root.snapshot.dbBytes) + " · "
                + Model.safeLabel(root.enabledAuthorsLabel)
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
              textFormat: Text.PlainText
            }

            Button {
              id: clearButton
              anchors.verticalCenter: parent.verticalCenter
              text: root.confirmClear ? "Confirm" : "Clear"
              bordered: root.confirmClear
              foreground: root.confirmClear ? Color.urgent : Color.popups.text
              accent: root.confirmClear ? Color.urgent : Color.accent
              focusable: true
              tooltipText: "Delete all stored samples"
              enabled: !!root.pulseService && !root.busy
              opacity: enabled ? 1 : 0.35
              onClicked: {
                if (!root.confirmClear) {
                  root.confirmClear = true
                  return
                }
                root.confirmClear = false
                if (root.pulseService) root.pulseService.clearHistory()
              }
            }

            Button {
              id: cancelClearButton
              anchors.verticalCenter: parent.verticalCenter
              visible: root.confirmClear
              text: "Cancel"
              focusable: true
              onClicked: root.confirmClear = false
            }
          }
        }
      }
    }
  }

  IpcHandler {
    target: "plugin-pulse"

    function state(): string { return JSON.stringify(root.stateSnapshot()) }
    function open(): string { root.open(); return "opened" }
    function close(): string { root.close(); return "closed" }
    function toggle(): string { root.toggle(); return root.opened ? "opened" : "closed" }
    function refresh(): string { root.refresh(); return "started" }
  }
}
