import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root
  focus: true
  activeFocusOnTab: true

  property var series: []
  property string metric: "views"
  property string resolution: "daily"
  property real selectedTs: 0
  property color accentColor: Color.accent
  property color foregroundColor: Color.popups.text
  property color mutedColor: Color.muted
  property color urgentColor: Color.urgent
  property color gridColor: Util.alpha(Color.popups.text, 0.12)
  property bool showDots: false

  property real hoverTs: 0

  readonly property var colorMap: ({
    accent: accentColor,
    foreground: foregroundColor,
    muted: mutedColor,
    urgent: urgentColor
  })

  signal selectionChanged(real ts)

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
    maxV = maxV * 1.08
    return { minT: minT, maxT: maxT, minV: minV, maxV: maxV }
  }

  // 0 means none — paint cursor at latest without owning a selection.
  function effectiveSelectedTs() {
    var b = bounds()
    if (selectedTs > 0)
      return selectedTs
    return b.maxT
  }

  function tsAtX(px) {
    var padL = 4
    var padR = 4
    var w = Math.max(1, width - padL - padR)
    var b = bounds()
    var spanT = Math.max(1, b.maxT - b.minT)
    var ratio = Math.max(0, Math.min(1, (px - padL) / w))
    var target = b.minT + ratio * spanT
    var snap = Model.nearestTimestamp(series, target)
    return snap || target
  }

  function selectAtX(px) {
    var snap = tsAtX(px)
    if (selectedTs !== snap)
      selectionChanged(snap)
    canvas.requestPaint()
  }

  function stepBy(delta) {
    var current = selectedTs > 0 ? selectedTs : effectiveSelectedTs()
    var next = Model.stepTimestamp(series, current, delta)
    if (next > 0)
      selectionChanged(next)
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Left) {
      stepBy(-1)
      event.accepted = true
    } else if (event.key === Qt.Key_Right) {
      stepBy(1)
      event.accepted = true
    }
  }

  function formatTick(t, minT, maxT) {
    var res = String(resolution || "daily")
    var d = new Date(t * 1000)
    if (res === "hourly") {
      if ((maxT - minT) > 86400)
        return Qt.formatDateTime(d, "MMM d · HH:mm")
      return Qt.formatDateTime(d, "HH:mm")
    }
    if (res === "monthly")
      return Qt.formatDateTime(d, "MMM yyyy")
    return Qt.formatDateTime(d, "MMM d")
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var padL = 4
      var padR = 4
      var padT = 8
      var padB = 22
      var w = Math.max(1, width - padL - padR)
      var h = Math.max(1, height - padT - padB)
      var b = root.bounds()
      var spanT = Math.max(1, b.maxT - b.minT)
      var spanV = Math.max(1, b.maxV - b.minV)

      function xAt(t) { return padL + ((t - b.minT) / spanT) * w }
      function yAt(v) { return padT + (1 - ((v - b.minV) / spanV)) * h }

      // Horizontal grid
      ctx.strokeStyle = String(root.gridColor)
      ctx.lineWidth = 1
      ctx.beginPath()
      for (var g = 1; g <= 3; g++) {
        var gy = padT + (h * g / 4)
        ctx.moveTo(padL, gy)
        ctx.lineTo(padL + w, gy)
      }
      ctx.stroke()

      var tickCount = 5
      var ticks = []
      for (var ti = 0; ti < tickCount; ti++)
        ticks.push(b.minT + (spanT * ti / (tickCount - 1)))

      // Faint vertical grid at ticks
      ctx.strokeStyle = String(Util.alpha(root.foregroundColor, 0.06))
      ctx.beginPath()
      for (var vg = 0; vg < ticks.length; vg++) {
        var vx = xAt(ticks[vg])
        ctx.moveTo(vx, padT)
        ctx.lineTo(vx, padT + h)
      }
      ctx.stroke()

      if (!root.series || root.series.length === 0) {
        ctx.fillStyle = String(root.mutedColor)
        ctx.font = "12px sans-serif"
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillText("No samples yet", width / 2, padT + h / 2)
      } else {
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

      // Optional hover scrubber (faint)
      if (root.hoverTs > 0 && !(scrub.pressed)) {
        var hx = xAt(root.hoverTs)
        if (hx >= padL && hx <= padL + w) {
          ctx.strokeStyle = String(Util.alpha(root.foregroundColor, 0.18))
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.moveTo(hx, padT)
          ctx.lineTo(hx, padT + h)
          ctx.stroke()
        }
      }

      // Soft vertical cursor at selected (or latest when none)
      var cursorTs = root.effectiveSelectedTs()
      if (cursorTs >= b.minT && cursorTs <= b.maxT) {
        var cx = xAt(cursorTs)
        ctx.strokeStyle = String(Util.alpha(root.accentColor, root.selectedTs > 0 ? 0.7 : 0.35))
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.moveTo(cx, padT)
        ctx.lineTo(cx, padT + h)
        ctx.stroke()
      }

      // X-axis labels
      ctx.fillStyle = String(root.mutedColor)
      ctx.font = "10px sans-serif"
      ctx.textBaseline = "top"
      for (var li = 0; li < ticks.length; li++) {
        var tt = ticks[li]
        var lx = xAt(tt)
        var label = root.formatTick(tt, b.minT, b.maxT)
        if (li === 0) {
          ctx.textAlign = "left"
          lx = padL
        } else if (li === ticks.length - 1) {
          ctx.textAlign = "right"
          lx = padL + w
        } else {
          ctx.textAlign = "center"
        }
        ctx.fillText(label, lx, padT + h + 4)
      }
    }
  }

  MouseArea {
    id: scrub
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    preventStealing: true

    onClicked: function(mouse) {
      root.forceActiveFocus()
      root.selectAtX(mouse.x)
    }
    onPressed: function(mouse) {
      root.forceActiveFocus()
      root.selectAtX(mouse.x)
    }
    onPositionChanged: function(mouse) {
      if (pressed) {
        root.selectAtX(mouse.x)
      } else {
        root.hoverTs = root.tsAtX(mouse.x)
        canvas.requestPaint()
      }
    }
    onExited: {
      root.hoverTs = 0
      canvas.requestPaint()
    }
  }

  onSeriesChanged: canvas.requestPaint()
  onMetricChanged: canvas.requestPaint()
  onResolutionChanged: canvas.requestPaint()
  onSelectedTsChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onAccentColorChanged: canvas.requestPaint()
  onForegroundColorChanged: canvas.requestPaint()
  onMutedColorChanged: canvas.requestPaint()
  onUrgentColorChanged: canvas.requestPaint()
}
