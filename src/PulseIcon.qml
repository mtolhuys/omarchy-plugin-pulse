import QtQuick

Item {
  id: root

  property color foreground: "#ffffffff"
  property color accent: foreground
  property bool active: false

  implicitWidth: 18
  implicitHeight: 18

  onForegroundChanged: canvas.requestPaint()
  onAccentChanged: canvas.requestPaint()
  onActiveChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var size = Math.min(width, height)
      var pad = Math.max(1.5, size * 0.12)
      var w = Math.max(1, width - pad * 2)
      var h = Math.max(1, height - pad * 2)
      var stroke = root.active ? root.accent : root.foreground
      var lineW = Math.max(1.4, size * 0.1)

      // Normalized sparkline: slight dip then strong rise (marketplace growth).
      var pts = [
        [0.00, 0.78],
        [0.22, 0.62],
        [0.40, 0.70],
        [0.62, 0.42],
        [0.82, 0.28],
        [1.00, 0.12]
      ]

      function xAt(t) { return pad + t * w }
      function yAt(v) { return pad + v * h }

      // Soft fill under the curve.
      ctx.beginPath()
      ctx.moveTo(xAt(pts[0][0]), yAt(1))
      for (var i = 0; i < pts.length; i++)
        ctx.lineTo(xAt(pts[i][0]), yAt(pts[i][1]))
      ctx.lineTo(xAt(pts[pts.length - 1][0]), yAt(1))
      ctx.closePath()
      ctx.fillStyle = String(stroke)
      ctx.globalAlpha = 0.16
      ctx.fill()
      ctx.globalAlpha = 1

      // Curve.
      ctx.beginPath()
      ctx.moveTo(xAt(pts[0][0]), yAt(pts[0][1]))
      for (var j = 1; j < pts.length; j++)
        ctx.lineTo(xAt(pts[j][0]), yAt(pts[j][1]))
      ctx.strokeStyle = String(stroke)
      ctx.lineWidth = lineW
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.stroke()

      // End dot (latest observation).
      var last = pts[pts.length - 1]
      var r = Math.max(1.6, size * 0.12)
      ctx.beginPath()
      ctx.arc(xAt(last[0]), yAt(last[1]), r, 0, Math.PI * 2)
      ctx.fillStyle = String(stroke)
      ctx.fill()
    }
  }
}
