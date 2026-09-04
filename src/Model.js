.pragma library

function parseJson(raw, fallback) {
  try {
    var text = String(raw || "").trim()
    if (!text) return fallback
    return JSON.parse(text)
  } catch (error) {
    return fallback
  }
}

function emptySnapshot() {
  return {
    ok: false,
    author: "mtolhuys",
    resolution: "daily",
    stepSeconds: 86400,
    rangeStart: 0,
    rangeEnd: 0,
    plugins: [],
    series: [],
    totals: { views: 0, copies: 0, hearts: 0 },
    hasEstimatedHistory: false,
    lastCollectAt: null,
    dbBytes: 0,
    dbPath: "",
    generatedAt: 0,
    error: "",
    message: ""
  }
}

function parseSnapshot(raw) {
  var parsed = parseJson(raw, null)
  if (!parsed || typeof parsed !== "object") {
    var failed = emptySnapshot()
    failed.error = "invalid-json"
    failed.message = "Could not parse helper output"
    return failed
  }
  if (parsed.ok === false) {
    var err = emptySnapshot()
    err.error = String(parsed.error || "failed")
    err.message = String(parsed.message || "Helper failed")
    err.author = String(parsed.author || err.author)
    return err
  }
  return {
    ok: true,
    author: String(parsed.author || "mtolhuys"),
    resolution: String(parsed.resolution || "daily"),
    stepSeconds: Number(parsed.stepSeconds || 86400),
    rangeStart: Number(parsed.rangeStart || 0),
    rangeEnd: Number(parsed.rangeEnd || 0),
    plugins: Array.isArray(parsed.plugins) ? parsed.plugins : [],
    series: Array.isArray(parsed.series) ? parsed.series : [],
    totals: {
      views: Number((parsed.totals && parsed.totals.views) || 0),
      copies: Number((parsed.totals && parsed.totals.copies) || 0),
      hearts: Number((parsed.totals && parsed.totals.hearts) || 0)
    },
    hasEstimatedHistory: parsed.hasEstimatedHistory === true,
    lastCollectAt: parsed.lastCollectAt == null ? null : Number(parsed.lastCollectAt),
    dbBytes: Number(parsed.dbBytes || 0),
    dbPath: String(parsed.dbPath || ""),
    generatedAt: Number(parsed.generatedAt || 0),
    error: "",
    message: ""
  }
}

function formatCount(value) {
  var n = Number(value || 0)
  if (!isFinite(n)) return "—"
  if (n >= 1000000) return (n / 1000000).toFixed(1).replace(/\.0$/, "") + "M"
  if (n >= 1000) return (n / 1000).toFixed(1).replace(/\.0$/, "") + "k"
  return String(Math.round(n))
}

function formatBytes(value) {
  var n = Number(value || 0)
  if (!isFinite(n) || n < 0) return "—"
  if (n < 1024) return Math.round(n) + " B"
  if (n < 1048576) return (n / 1024).toFixed(1).replace(/\.0$/, "") + " KiB"
  return (n / 1048576).toFixed(2).replace(/\.?0+$/, "") + " MiB"
}

function formatWhen(epochSeconds) {
  var n = Number(epochSeconds || 0)
  if (!n) return "Never"
  return Qt.formatDateTime(new Date(n * 1000), "MMM d · HH:mm")
}

function shortPluginName(name, id) {
  var label = String(name || "")
  if (label.indexOf("Omarchy ") === 0) label = label.slice(8)
  if (!label) {
    var parts = String(id || "").split(".")
    label = parts.length ? parts[parts.length - 1] : "plugin"
  }
  return label
}

function safeLabel(value) {
  return String(value || "").replace(/[\u0000-\u001f]/g, " ")
}

function seriesPalette(index) {
  // Fixed distinct hex palette (dark-UI friendly); independent of theme greys.
  var palette = ["#5B8CFF", "#3DDC97", "#FFB020", "#FF6B6B", "#C084FC", "#22D3EE"]
  return palette[index % palette.length]
}

function colorForPluginId(id, plugins) {
  var list = plugins || []
  var needle = String(id || "")
  for (var i = 0; i < list.length; i++) {
    if (list[i] && String(list[i].id || "") === needle)
      return seriesPalette(i)
  }
  // Stable fallback if id is missing from plugins list.
  var h = 0
  for (var j = 0; j < needle.length; j++)
    h = ((h << 5) - h) + needle.charCodeAt(j)
  return seriesPalette(Math.abs(h))
}

function chartSeries(snapshot, metric, enabledIds) {
  var out = []
  var series = snapshot && Array.isArray(snapshot.series) ? snapshot.series : []
  var plugins = snapshot && Array.isArray(snapshot.plugins) ? snapshot.plugins : []
  var allow = enabledIds && enabledIds.length ? enabledIds : null
  for (var i = 0; i < series.length; i++) {
    var item = series[i]
    if (!item) continue
    if (allow && allow.indexOf(item.id) < 0) continue
    var points = item.metrics && item.metrics[metric] ? item.metrics[metric] : []
    out.push({
      id: item.id,
      name: shortPluginName(item.name, item.id),
      colorKey: colorForPluginId(item.id, plugins),
      points: points
    })
  }
  return out
}

function diagnosticText(raw, fallback) {
  var text = String(raw || "").trim()
  if (!text) return fallback
  var first = text.split("\n")[0]
  return first.length > 240 ? first.slice(0, 237) + "…" : first
}
