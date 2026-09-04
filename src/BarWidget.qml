import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root

  moduleName: "io.github.mtolhuys.plugin-pulse"

  readonly property string buildIdentity: "plugin-pulse-widget-v010"
  readonly property var pulseService: bar && bar.shell
    ? bar.shell.serviceFor("io.github.mtolhuys.plugin-pulse") : null
  readonly property var snapshot: pulseService ? pulseService.snapshot : Model.emptySnapshot()
  readonly property bool collecting: pulseService && pulseService.collectState === "collecting"
  readonly property bool busy: collecting
  readonly property string activeMetric: metric
  readonly property var chartSeries: Model.chartSeries(snapshot, activeMetric, null)
  readonly property bool estimated: snapshot.hasEstimatedHistory === true
  readonly property string authorValue: pulseService ? String(pulseService.authorDraft || snapshot.author || "") : ""
  readonly property string resolutionValue: pulseService ? String(pulseService.resolution || "daily") : "daily"

  property bool popupOpen: false
  property string metric: "views"
  property string authorEdit: "mtolhuys"
  property bool settingsOpen: false
  property bool confirmClear: false

  readonly property bool opened: popupOpen
  readonly property bool popoutSwitchClosing: false
  readonly property real openPanelIndicatorWidth: button.labelWidth

  function open() {
    popupOpen = true
    authorEdit = authorValue || "mtolhuys"
    if (pulseService) {
      if (!snapshot.ok) pulseService.refreshSnapshot()
      if (!snapshot.lastCollectAt) pulseService.collectNow()
    }
  }

  function close() {
    settingsOpen = false
    confirmClear = false
    popupOpen = false
  }
  function closeForPopoutSwitch() { close() }
  function toggle() { popupOpen ? close() : open() }

  function setResolution(value) {
    if (pulseService) pulseService.setResolution(value)
  }

  function setMetric(value) {
    metric = value
  }

  function refresh() {
    if (pulseService) pulseService.collectNow()
  }

  function saveAuthor() {
    if (!pulseService) return
    pulseService.setAuthor(authorEdit)
    settingsOpen = false
  }

  function togglePlugin(pluginId, enabled) {
    if (pulseService) pulseService.togglePlugin(pluginId, enabled)
  }

  function colorForKey(key) {
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
    if (!authorField.activeFocus) authorEdit = authorValue || authorEdit
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: pulseIcon
    active: root.estimated || root.collecting
    activeColor: Color.accent
    tooltipText: "Plugin Pulse — " + root.statusLabel() + " · left open · middle refresh"
    Accessible.name: "Plugin Pulse"
    Accessible.role: Accessible.Button

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    // Live collect marker — never the only visible affordance.
    Rectangle {
      visible: root.collecting
      z: 2
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Style.space(2)
      anchors.topMargin: Style.space(2)
      width: Style.space(6)
      height: width
      radius: width / 2
      color: Color.accent
      border.width: 1
      border.color: Color.background
    }
  }

  Component {
    id: pulseIcon
    // Solid bars (not Canvas) so the glyph always paints in the bar.
    Item {
      id: glyph
      readonly property color ink: button.active ? button.activeColor : button.foreground

      Row {
        id: bars
        anchors.centerIn: parent
        spacing: Math.max(1.5, glyph.width * 0.08)
        height: glyph.height * 0.72

        Repeater {
          model: [0.42, 0.92, 0.62, 0.78]
          delegate: Rectangle {
            required property real modelData
            width: Math.max(2.5, glyph.width * 0.14)
            height: bars.height * modelData
            anchors.bottom: parent.bottom
            radius: 1
            color: glyph.ink
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: root.settingsOpen ? authorField : panelScroll
    contentWidth: popup.fittedContentWidth(Style.space(520))
    contentHeight: popup.fittedContentHeight(Math.min(panelColumn.implicitHeight, Style.space(640)))

    Flickable {
      id: panelScroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: panelColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }
      focus: true

      Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: {
          if (root.confirmClear) root.confirmClear = false
          else if (root.settingsOpen) root.settingsOpen = false
          else root.close()
        }
      }

      Column {
        id: panelColumn
        width: panelScroll.width
        spacing: Style.space(9)

        Row {
          width: parent.width
          spacing: Style.space(10)

          BorderSurface {
            width: Style.space(36)
            height: width
            color: Style.selectedFillFor(Color.accent, Color.accent)
            borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)
            radius: Style.cornerRadius

            Text {
              anchors.centerIn: parent
              text: "⌁"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              textFormat: Text.PlainText
            }
          }

          Column {
            width: parent.width - Style.space(36) - Style.space(10) - refreshButton.width
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Plugin Pulse"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
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

          Button {
            id: refreshButton
            anchors.verticalCenter: parent.verticalCenter
            iconText: "↻"
            tooltipText: "Refresh marketplace stats"
            focusable: true
            enabled: !!root.pulseService && !root.busy
            opacity: enabled ? 1 : 0.35
            onClicked: root.refresh()
          }
        }

        BorderSurface {
          visible: root.estimated
          width: parent.width
          implicitHeight: estimateRow.implicitHeight + Style.space(16)
          color: Util.alpha(Color.accent, 0.08)
          borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)
          radius: Style.cornerRadius

          Row {
            id: estimateRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(9)
            spacing: Style.space(8)

            Text {
              text: "≈"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              textFormat: Text.PlainText
            }

            Text {
              width: parent.width - parent.children[0].width - Style.space(8)
              text: "Estimated history — smooth curves seeded from each plugin’s listing date until the first live observation."
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
            }
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
              text: modelData.label
              selected: root.metric === modelData.id
              bordered: root.metric === modelData.id
              focusable: true
              onClicked: root.setMetric(modelData.id)
            }
          }

          Item { width: Style.space(8); height: 1 }

          Button {
            text: "Author"
            iconText: "✎"
            selected: root.settingsOpen
            focusable: true
            onClicked: root.settingsOpen = !root.settingsOpen
          }
        }

        BorderSurface {
          visible: root.settingsOpen
          width: parent.width
          implicitHeight: settingsColumn.implicitHeight + Style.space(18)
          color: Style.normalFillFor(Color.popups.text, Color.accent)
          borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
          radius: Style.cornerRadius

          Column {
            id: settingsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(9)
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: "Marketplace author filter"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              textFormat: Text.PlainText
            }

            Text {
              width: parent.width
              text: "Matches author name, plugin id, or repository URL. Default is mtolhuys."
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: authorField
                width: parent.width - saveAuthorButton.width - Style.space(8)
                text: root.authorEdit
                placeholderText: "mtolhuys"
                selectByMouse: true
                Accessible.name: "Author filter"
                onTextEdited: root.authorEdit = text
                onAccepted: root.saveAuthor()
                TapHandler { onTapped: authorField.forceActiveFocus() }
              }

              Button {
                id: saveAuthorButton
                text: "Save"
                bordered: true
                selected: true
                focusable: true
                onClicked: root.saveAuthor()
              }
            }
          }
        }

        BorderSurface {
          width: parent.width
          height: Style.space(220)
          color: Util.alpha(Color.popups.text, 0.035)
          borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
          radius: Style.cornerRadius
          clip: true

          LineChart {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            series: root.chartSeries
            metric: root.metric
            accentColor: Color.accent
            foregroundColor: Color.popups.text
            mutedColor: Color.muted
            urgentColor: Color.urgent
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Text {
            width: parent.width
            text: "Plugins"
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            textFormat: Text.PlainText
          }

          Flow {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.snapshot.plugins || []

              delegate: Button {
                required property var modelData
                required property int index
                text: Model.shortPluginName(modelData.name, modelData.id)
                selected: modelData.enabled === true
                focusable: true
                tooltipText: modelData.enabled ? "Hide from chart" : "Show on chart"
                onClicked: root.togglePlugin(modelData.id, !(modelData.enabled === true))

                Rectangle {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(6)
                  width: Style.space(8)
                  height: width
                  radius: width / 2
                  color: root.colorForKey(Model.seriesPalette(index))
                  opacity: modelData.enabled === true ? 1 : 0.35
                }
              }
            }
          }
        }

        BorderSurface {
          width: parent.width
          implicitHeight: totalsColumn.implicitHeight + Style.space(18)
          color: Style.normalFillFor(Color.popups.text, Color.accent)
          borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
          radius: Style.cornerRadius

          Column {
            id: totalsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(9)
            spacing: Style.space(8)

            Row {
              width: parent.width

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
              width: parent.width
              spacing: Style.space(12)

              Repeater {
                model: [
                  { key: "views", label: "Views", value: root.snapshot.totals.views },
                  { key: "copies", label: "Copies", value: root.snapshot.totals.copies },
                  { key: "hearts", label: "Hearts", value: root.snapshot.totals.hearts }
                ]

                delegate: Column {
                  required property var modelData
                  width: (parent.width - Style.space(24)) / 3
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    text: modelData.label.toUpperCase()
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 0.7
                    textFormat: Text.PlainText
                  }

                  Text {
                    width: parent.width
                    text: Model.formatCount(modelData.value)
                    color: root.metric === modelData.key ? Color.accent : Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    font.bold: true
                    textFormat: Text.PlainText
                  }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(3)

              Repeater {
                model: root.snapshot.series || []

                delegate: Row {
                  required property var modelData
                  width: totalsColumn.width
                  spacing: Style.space(8)

                  Text {
                    width: parent.width * 0.42
                    text: Model.safeLabel(Model.shortPluginName(modelData.name, modelData.id))
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                  }

                  Text {
                    width: parent.width * 0.18
                    text: Model.formatCount(modelData.totals.views)
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    horizontalAlignment: Text.AlignRight
                    textFormat: Text.PlainText
                  }

                  Text {
                    width: parent.width * 0.18
                    text: Model.formatCount(modelData.totals.copies)
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    horizontalAlignment: Text.AlignRight
                    textFormat: Text.PlainText
                  }

                  Text {
                    width: parent.width * 0.18
                    text: Model.formatCount(modelData.totals.hearts)
                    color: Color.muted
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

        BorderSurface {
          width: parent.width
          implicitHeight: storageColumn.implicitHeight + Style.space(18)
          color: Style.normalFillFor(Color.popups.text, Color.accent)
          borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
          radius: Style.cornerRadius

          Column {
            id: storageColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(9)
            spacing: Style.space(8)

            Row {
              width: parent.width

              Column {
                width: parent.width - Style.space(8)
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: "Local history store"
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                  textFormat: Text.PlainText
                }

                Text {
                  width: parent.width
                  text: Model.formatBytes(root.snapshot.dbBytes) + "  ·  author “"
                    + Model.safeLabel(root.authorValue) + "”"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                  textFormat: Text.PlainText
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Button {
                text: "Archive"
                focusable: true
                tooltipText: "Copy DB to archive and drop estimated seed points"
                enabled: !!root.pulseService && !root.busy
                opacity: enabled ? 1 : 0.35
                onClicked: if (root.pulseService) root.pulseService.archiveHistory()
              }

              Button {
                text: root.confirmClear ? "Confirm clear" : "Clear"
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
