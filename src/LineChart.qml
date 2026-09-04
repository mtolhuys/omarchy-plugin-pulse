import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var series: []
  property string metric: "views"
  property color accentColor: Color.accent
  property color foregroundColor: Color.popups.text
  property color mutedColor: Color.muted
  property color urgentColor: Color.urgent
  property color gridColor: Util.alpha(Color.popups.text, 0.12)
  property bool showDots: false

  readonly property var colorMap: ({
    accent: accentColor,
    foreground: foregroundColor,
    muted: mutedColor,
    urgent: urgentColor
  })

  function colorFor(key) {
    var k = String(key || "")
    if (k.indexOf("#") === 0)
      return k
    return colorMap[key] || accentColor
  }

  function bounds() {
    var minT = Number.POSITIVE_INFINITY
    var maxT = Number.NEGATIVE_INFINITY
    var minV = 0
    var maxV = 1
    for (var i = 0; i < series.length; i++) {
      var points = series[i] && series[i].points ? series[i].points : []
      for (var j = 0; j < points.length; j++) {
        var p = points[j]
        if (!p) continue
        var t = Number(p.t)
        var v = Number(p.v)
        if (!isFinite(t) || !isFinite(v)) continue
        if (t < minT) minT = t
        if (t > maxT) maxT = t
        if (v > maxV) maxV = v
      }
    }
    if (!isFinite(minT) || !isFinite(maxT) || maxT <= minT) {
      var now = Math.floor(Date.now() / 1000)
      minT = now - 86400
      maxT = now
    }
    if (maxV <= minV) maxV = minV + 1
    // headroom
    maxV = maxV * 1.08
    return { minT: minT, maxT: maxT, minV: minV, maxV: maxV }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var padL = 2
      var padR = 2
      var padT = 8
      var padB = 8
      var w = Math.max(1, width - padL - padR)
      var h = Math.max(1, height - padT - padB)
      var b = root.bounds()
      var spanT = Math.max(1, b.maxT - b.minT)
      var spanV = Math.max(1, b.maxV - b.minV)

      function xAt(t) { return padL + ((t - b.minT) / spanT) * w }
      function yAt(v) { return padT + (1 - ((v - b.minV) / spanV)) * h }

      // grid
      ctx.strokeStyle = String(root.gridColor)
      ctx.lineWidth = 1
      ctx.beginPath()
      for (var g = 1; g <= 3; g++) {
        var gy = padT + (h * g / 4)
        ctx.moveTo(padL, gy)
        ctx.lineTo(padL + w, gy)
      }
      ctx.stroke()

      if (!root.series || root.series.length === 0) {
        ctx.fillStyle = String(root.mutedColor)
        ctx.font = "12px sans-serif"
        ctx.textAlign = "center"
        ctx.fillText("No samples yet", width / 2, height / 2)
        return
      }

      for (var i = 0; i < root.series.length; i++) {
        var item = root.series[i]
        var points = item && item.points ? item.points : []
        if (points.length === 0) continue
        var stroke = String(root.colorFor(item.colorKey))
        ctx.strokeStyle = stroke
        ctx.lineWidth = 2.5
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.beginPath()
        var started = false
        var lastX = 0
        var lastY = 0
        for (var j = 0; j < points.length; j++) {
          var p = points[j]
          if (!p) continue
          var x = xAt(Number(p.t))
          var y = yAt(Number(p.v))
          lastX = x
          lastY = y
          if (!started) {
            ctx.moveTo(x, y)
            started = true
          } else {
            ctx.lineTo(x, y)
          }
        }
        ctx.stroke()

        // Always mark the latest point so short series stay visible.
        if (started) {
          ctx.fillStyle = stroke
          ctx.beginPath()
          ctx.arc(lastX, lastY, 3, 0, Math.PI * 2)
          ctx.fill()
        }

        if (root.showDots) {
          ctx.fillStyle = stroke
          for (var k = 0; k < points.length; k++) {
            var q = points[k]
            ctx.beginPath()
            ctx.arc(xAt(Number(q.t)), yAt(Number(q.v)), 2.5, 0, Math.PI * 2)
            ctx.fill()
          }
        }
      }
    }
  }

  onSeriesChanged: canvas.requestPaint()
  onMetricChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onAccentColorChanged: canvas.requestPaint()
  onForegroundColorChanged: canvas.requestPaint()
  onMutedColorChanged: canvas.requestPaint()
  onUrgentColorChanged: canvas.requestPaint()
}
