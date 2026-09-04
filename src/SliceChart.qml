import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var slices: []
  property string title: ""
  property color accentColor: Color.accent
  property color foregroundColor: Color.popups.text
  property color mutedColor: Color.muted

  implicitHeight: Style.space(100)

  readonly property real total: {
    var sum = 0
    var list = slices || []
    for (var i = 0; i < list.length; i++) {
      var v = Number(list[i] && list[i].value)
      if (isFinite(v) && v > 0) sum += v
    }
    return sum
  }

  function colorFor(key) {
    var k = String(key || "")
    if (k.indexOf("#") === 0)
      return k
    return accentColor
  }

  function truncateName(name) {
    var s = String(name || "")
    if (s.length > 16)
      return s.slice(0, 15) + "…"
    return s
  }

  Row {
    anchors.fill: parent
    spacing: Style.space(8)

    // Left ~58%: horizontal bars
    Item {
      id: barsPane
      width: parent.width * 0.58 - Style.space(4)
      height: parent.height
      clip: true

      Column {
        anchors.fill: parent
        spacing: Style.space(3)
        visible: root.total > 0

        Repeater {
          model: root.slices || []

          delegate: Item {
            required property var modelData
            width: barsPane.width
            height: Style.space(14)

            readonly property real frac: {
              var v = Number(modelData.value || 0)
              if (!(root.total > 0) || !(v > 0)) return 0
              return Math.max(0, Math.min(1, v / root.total))
            }

            Text {
              id: nameLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(72)
              text: root.truncateName(modelData.name)
              color: root.foregroundColor
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }

            Rectangle {
              anchors.left: nameLabel.right
              anchors.leftMargin: Style.space(4)
              anchors.right: valueLabel.left
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(7)
              radius: height / 2
              color: Util.alpha(root.foregroundColor, 0.08)

              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * frac
                radius: parent.radius
                color: root.colorFor(modelData.colorKey)
              }
            }

            Text {
              id: valueLabel
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(36)
              text: {
                var v = Number(modelData.value || 0)
                if (!isFinite(v)) return "—"
                if (v >= 1000000) return (v / 1000000).toFixed(1).replace(/\.0$/, "") + "M"
                if (v >= 1000) return (v / 1000).toFixed(1).replace(/\.0$/, "") + "k"
                return String(Math.round(v))
              }
              color: root.mutedColor
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              textFormat: Text.PlainText
            }
          }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: !(root.total > 0)
        text: "No data at this time"
        color: root.mutedColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
      }
    }

    // Right ~42%: pie
    Item {
      width: parent.width * 0.42 - Style.space(4)
      height: parent.height

      Canvas {
        id: pieCanvas
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - Style.space(4)
        height: width
        antialiasing: true

        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          ctx.clearRect(0, 0, width, height)

          var cx = width / 2
          var cy = height / 2
          var r = Math.max(8, Math.min(width, height) / 2 - 2)
          var list = root.slices || []
          var sum = root.total

          if (!(sum > 0)) {
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.strokeStyle = String(Util.alpha(root.foregroundColor, 0.14))
            ctx.lineWidth = 2
            ctx.stroke()
            return
          }

          var angle = -Math.PI / 2
          for (var i = 0; i < list.length; i++) {
            var item = list[i]
            var v = Number(item && item.value)
            if (!isFinite(v) || v <= 0) continue
            var sweep = (v / sum) * Math.PI * 2
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.arc(cx, cy, r, angle, angle + sweep)
            ctx.closePath()
            ctx.fillStyle = String(root.colorFor(item.colorKey))
            ctx.fill()
            angle += sweep
          }

          // Donut hole
          var hole = r * 0.42
          ctx.globalCompositeOperation = "destination-out"
          ctx.beginPath()
          ctx.arc(cx, cy, hole, 0, Math.PI * 2)
          ctx.fill()
          ctx.globalCompositeOperation = "source-over"

          ctx.beginPath()
          ctx.arc(cx, cy, r, 0, Math.PI * 2)
          ctx.strokeStyle = String(Util.alpha(root.foregroundColor, 0.1))
          ctx.lineWidth = 1
          ctx.stroke()
        }

        Connections {
          target: root
          function onSlicesChanged() { pieCanvas.requestPaint() }
          function onTotalChanged() { pieCanvas.requestPaint() }
          function onAccentColorChanged() { pieCanvas.requestPaint() }
          function onForegroundColorChanged() { pieCanvas.requestPaint() }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
      }
    }
  }
}
