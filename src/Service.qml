import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property string omarchyPath: ""

  readonly property string buildIdentity: "plugin-pulse-service-v019"
  readonly property string sourceDir: manifest ? String(manifest.__sourceDir || "") : ""
  readonly property string helperPath: sourceDir ? sourceDir + "/bin/pulse" : ""

  property string collectState: "idle"
  property string snapshotState: "idle"
  property string lastError: ""
  property string resolution: "daily"
  property string authorDraft: ""
  property var snapshot: Model.emptySnapshot()
  property var plugins: []
  property var series: []
  property double updatedAt: 0
  property bool expectedStop: false
  property string pendingAction: ""
  property string settingsPanel: ""
  property bool notificationsEnabled: false
  property int collectIntervalMin: 60

  readonly property int collectIntervalMs: Math.max(5, collectIntervalMin) * 60 * 1000
  readonly property int initialCollectDelayMs: 2500

  function runHelper(process, args) {
    if (!helperPath || process.running) return false
    process.command = [helperPath].concat(args)
    process.running = true
    return true
  }

  function refreshSnapshot() {
    if (!helperPath) {
      lastError = "Plugin helper is missing"
      snapshotState = "failed"
      return false
    }
    if (snapshotProcess.running) return false
    snapshotState = snapshot.ok ? "ready" : "loading"
    return runHelper(snapshotProcess, ["snapshot", "--resolution", resolution])
  }

  function collectNow(forceAuthor) {
    if (!helperPath) {
      lastError = "Plugin helper is missing"
      collectState = "failed"
      return false
    }
    if (collectProcess.running) return false
    collectState = "collecting"
    lastError = ""
    var args = ["collect"]
    var author = String(forceAuthor || "").trim()
    if (author) args = args.concat(["--author", author])
    return runHelper(collectProcess, args)
  }

  function setResolution(value) {
    var next = String(value || "daily")
    if (["hourly", "daily", "weekly", "monthly"].indexOf(next) < 0) next = "daily"
    if (resolution === next) {
      refreshSnapshot()
      return true
    }
    resolution = next
    return refreshSnapshot()
  }

  function setAuthor(value) {
    // Back-compat: UI select toggles enable instead of single-active filter
    return enableAuthor(value)
  }

  function enableAuthor(value) {
    var author = String(value || "").trim()
    if (!author || author.length > 120) {
      lastError = "Author must be 1–120 characters"
      return false
    }
    if (authorProcess.running) return false
    authorDraft = author
    pendingAction = "collect-after-author"
    return runHelper(authorProcess, ["enable-author", author])
  }

  function disableAuthor(value) {
    var author = String(value || "").trim()
    if (!author || author.length > 120) {
      lastError = "Author must be 1–120 characters"
      return false
    }
    if (authorProcess.running) return false
    pendingAction = "refresh-after-delete"
    return runHelper(authorProcess, ["disable-author", author])
  }

  function toggleAuthorEnabled(value, enabled) {
    return enabled ? enableAuthor(value) : disableAuthor(value)
  }

  function addAuthor(value) {
    var author = String(value || "").trim()
    if (!author || author.length > 120) {
      lastError = "Author must be 1–120 characters"
      return false
    }
    if (authorProcess.running) return false
    authorDraft = author
    pendingAction = "collect-after-author"
    return runHelper(authorProcess, ["add-author", author])
  }

  function deleteAuthor(value) {
    var author = String(value || "").trim()
    if (!author || author.length > 120) {
      lastError = "Author must be 1–120 characters"
      return false
    }
    if (authorProcess.running) return false
    pendingAction = "refresh-after-delete"
    return runHelper(authorProcess, ["delete-author", author])
  }

  function addPlugin(pluginId) {
    var id = String(pluginId || "").trim()
    if (!id) {
      lastError = "Plugin id required"
      return false
    }
    if (pluginProcess.running) return false
    pendingAction = "collect-after-plugin"
    return runHelper(pluginProcess, ["add-plugin", id])
  }

  function removePlugin(pluginId) {
    var id = String(pluginId || "").trim()
    if (!id) {
      lastError = "Plugin id required"
      return false
    }
    if (pluginProcess.running) return false
    pendingAction = "refresh-after-plugin"
    return runHelper(pluginProcess, ["remove-plugin", id])
  }

  function togglePlugin(pluginId, enabled) {
    if (toggleProcess.running) return false
    var state = enabled ? "on" : "off"
    return runHelper(toggleProcess, ["toggle-plugin", String(pluginId || ""), state])
  }

  function setAllPlugins(enabled) {
    if (toggleProcess.running) return false
    var state = enabled ? "on" : "off"
    return runHelper(toggleProcess, ["set-plugins", state])
  }

  function archiveHistory() {
    if (archiveProcess.running) return false
    return runHelper(archiveProcess, ["archive"])
  }

  function clearHistory() {
    if (clearProcess.running) return false
    return runHelper(clearProcess, ["clear"])
  }

  function applySettings(settings) {
    if (!settings || typeof settings !== "object")
      return
    notificationsEnabled = settings.notifications === true
    var mins = Number(settings.collectIntervalMin || 60)
    if ([5, 15, 30, 60].indexOf(mins) < 0)
      mins = 60
    var intervalChanged = collectIntervalMin !== mins
    if (intervalChanged)
      collectIntervalMin = mins
    // Always arm on first settings; re-arm when interval changes.
    // armCollectTimer reads collectIntervalMin (already assigned above).
    if (!collectTimerArmed || intervalChanged)
      armCollectTimer()
  }

  function setNotifications(enabled) {
    if (settingsProcess.running) return false
    pendingAction = "refresh-after-settings"
    return runHelper(settingsProcess, ["set-notifications", enabled ? "on" : "off"])
  }

  function setCollectInterval(minutes) {
    if (settingsProcess.running) return false
    var mins = Number(minutes || 60)
    if ([5, 15, 30, 60].indexOf(mins) < 0) {
      lastError = "Refresh interval must be 5, 15, 30, or 60 minutes"
      return false
    }
    pendingAction = "refresh-after-settings"
    return runHelper(settingsProcess, ["set-collect-interval", String(mins)])
  }

  function emitGrowthAlerts(alerts) {
    if (!notificationsEnabled || !alerts || !alerts.length)
      return
    var lines = []
    var limit = Math.min(alerts.length, 6)
    for (var i = 0; i < limit; i++) {
      var a = alerts[i]
      if (!a) continue
      var bits = []
      var hearts = Number(a.heartsDelta || 0)
      var copies = Number(a.copiesDelta || 0)
      // Colored emoji icons for hearts / copies in the toast body.
      if (hearts > 0) bits.push("❤️ +" + hearts)
      if (copies > 0) bits.push("📋 +" + copies)
      if (!bits.length) continue
      var label = String(a.name || a.id || "plugin")
      if (label.indexOf("Omarchy ") === 0)
        label = label.slice(8)
      lines.push(label + " · " + bits.join(" · "))
    }
    if (!lines.length) return
    var body = lines.join("\n")
    if (alerts.length > limit)
      body += "\n…"
    var icon = sourceDir ? (sourceDir + "/assets/notification-icon.png") : ""
    var args = [
      "omarchy-notification-send",
      "--app-name", "Plugin Pulse",
      "-u", "normal"
    ]
    if (icon)
      args = args.concat(["-i", icon, "--image", icon])
    args = args.concat(["Marketplace growth", body])
    Quickshell.execDetached(args)
  }

  function applySnapshotOutput(raw) {
    var parsed = Model.parseSnapshot(raw)
    snapshot = parsed
    plugins = parsed.plugins || []
    series = parsed.series || []
    applySettings(parsed.settings)
    authorDraft = parsed.author || authorDraft
    updatedAt = Date.now()
    if (!parsed.ok) {
      snapshotState = "failed"
      lastError = parsed.message || parsed.error || "Snapshot failed"
      return false
    }
    snapshotState = "ready"
    lastError = ""
    return true
  }

  function stateSnapshot() {
    return {
      buildIdentity: buildIdentity,
      collectState: collectState,
      snapshotState: snapshotState,
      resolution: resolution,
      author: authorDraft,
      settingsPanel: settingsPanel,
      lastError: lastError,
      updatedAt: updatedAt,
      hasEstimatedHistory: snapshot.hasEstimatedHistory === true,
      pluginCount: snapshot.plugins ? snapshot.plugins.length : 0,
      seriesCount: snapshot.series ? snapshot.series.length : 0,
      totals: snapshot.totals,
      dbBytes: snapshot.dbBytes,
      lastCollectAt: snapshot.lastCollectAt,
      notificationsEnabled: notificationsEnabled,
      collectIntervalMin: collectIntervalMin,
      collectTimerArmed: collectTimerArmed,
      collectTimerRunning: collectTimer.running,
      collectTimerIntervalMs: collectTimerIntervalMs,
      collectTimerArmedAt: collectTimerArmedAt,
      collectTimerFireCount: collectTimerFireCount
    }
  }

  Process {
    id: collectProcess
    command: []
    stdout: StdioCollector {
      id: collectStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: collectStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (root.expectedStop) {
        root.expectedStop = false
        root.collectState = "idle"
        return
      }
      var parsed = Model.parseJson(collectStdout.text, null)
      if (exitCode !== 0 || !parsed || parsed.ok === false) {
        root.collectState = "failed"
        root.lastError = Model.diagnosticText(
          (parsed && parsed.message) || collectStderr.text,
          "Could not refresh marketplace stats")
        return
      }
      root.collectState = "ready"
      root.lastError = ""
      if (parsed.settings)
        root.applySettings(parsed.settings)
      root.emitGrowthAlerts(parsed.alerts || [])
      root.refreshSnapshot()
    }
  }

  Process {
    id: snapshotProcess
    command: []
    stdout: StdioCollector {
      id: snapshotStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: snapshotStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && !String(snapshotStdout.text || "").trim()) {
        root.snapshotState = "failed"
        root.lastError = Model.diagnosticText(snapshotStderr.text, "Could not load history")
        return
      }
      root.applySnapshotOutput(snapshotStdout.text)
    }
  }

  Process {
    id: authorProcess
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      id: authorStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = Model.diagnosticText(authorStderr.text, "Could not update authors")
        root.pendingAction = ""
        return
      }
      if (root.pendingAction === "collect-after-author") {
        root.pendingAction = ""
        root.collectNow()
      } else if (root.pendingAction === "refresh-after-delete") {
        root.pendingAction = ""
        root.refreshSnapshot()
      } else {
        root.refreshSnapshot()
      }
    }
  }

  Process {
    id: pluginProcess
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      id: pluginStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = Model.diagnosticText(pluginStderr.text, "Could not update plugins")
        root.pendingAction = ""
        return
      }
      if (root.pendingAction === "collect-after-plugin") {
        root.pendingAction = ""
        root.collectNow()
      } else {
        root.pendingAction = ""
        root.refreshSnapshot()
      }
    }
  }

  Process {
    id: toggleProcess
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      id: toggleStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = Model.diagnosticText(toggleStderr.text, "Could not toggle plugin")
        return
      }
      root.refreshSnapshot()
    }
  }


  Process {
    id: settingsProcess
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      id: settingsStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = Model.diagnosticText(settingsStderr.text, "Could not update settings")
        root.pendingAction = ""
        return
      }
      root.pendingAction = ""
      root.refreshSnapshot()
    }
  }

  Process {
    id: archiveProcess
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      id: archiveStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = Model.diagnosticText(archiveStderr.text, "Archive failed")
        return
      }
      root.refreshSnapshot()
    }
  }

  Process {
    id: clearProcess
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      id: clearStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = Model.diagnosticText(clearStderr.text, "Clear failed")
        return
      }
      root.refreshSnapshot()
    }
  }

  property bool collectTimerArmed: false
  property double collectTimerArmedAt: 0
  property int collectTimerIntervalMs: 0
  property int collectTimerFireCount: 0

  function armCollectTimer() {
    // Compute ms from collectIntervalMin directly — do NOT read collectIntervalMs
    // inside onCollectIntervalMinChanged; that binding can still be stale.
    var mins = Number(root.collectIntervalMin || 60)
    if ([5, 15, 30, 60].indexOf(mins) < 0)
      mins = 60
    var ms = mins * 60 * 1000
    collectTimer.stop()
    collectTimer.interval = ms
    collectTimerIntervalMs = ms
    collectTimerArmedAt = Date.now()
    collectTimerArmed = true
    collectTimer.start()
    console.log("plugin-pulse: armed collect timer", ms, "ms (", mins, "min)")
  }

  Timer {
    id: collectTimer
    // Interval always set explicitly via armCollectTimer — do not bind
    // `running: true` or a changing interval binding (both have been flaky).
    interval: 60 * 60 * 1000
    repeat: true
    running: false
    onTriggered: {
      root.collectTimerFireCount += 1
      console.log("plugin-pulse: collect timer fired", root.collectTimerFireCount)
      root.collectNow()
    }
  }

  Timer {
    id: startupTimer
    interval: root.initialCollectDelayMs
    repeat: false
    running: true
    onTriggered: {
      root.refreshSnapshot()
      root.collectNow()
      // Periodic timer is armed from applySettings once snapshot/collect
      // settings are known (avoids a stale 60‑min arm on boot).
    }
  }

  IpcHandler {
    target: "plugin-pulse-service"

    function state(): string { return JSON.stringify(root.stateSnapshot()) }
    function collect(): string { return root.collectNow() ? "started" : "busy" }
    function snapshot(): string { return root.refreshSnapshot() ? "started" : "busy" }
    function setResolution(value: string): string {
      return root.setResolution(value) ? root.resolution : "rejected"
    }
    function setAuthor(value: string): string {
      return root.setAuthor(value) ? "started" : "rejected"
    }
  }

  Component.onDestruction: {
    if (collectProcess.running) {
      expectedStop = true
      collectProcess.running = false
    }
  }
}
