.pragma library

// Build a support-friendly diagnostic summary from already-sanitized values.
// Deliberately excludes favourite team names, provider URLs, filesystem paths,
// tokens, and raw error text; only stable codes and counts leave the panel.

function errorCode(persistenceError, errorMessage) {
  if (persistenceError) {
    if (String(persistenceError).indexOf("save") !== -1) return "state-write"
    return "state-read"
  }
  var message = String(errorMessage || "")
  if (!message) return "none"
  if (message.indexOf("Select at least") !== -1) return "no-selection"
  if (message.indexOf("Some leagues") !== -1) return "provider-partial"
  if (message.indexOf("Favorite team schedule") !== -1) return "team-unavailable"
  if (message.indexOf("F1 race calendar") !== -1) return "f1-calendar-unavailable"
  if (message.indexOf("F1 standings") !== -1) return "f1-standings-unavailable"
  if (message.indexOf("Standings could not") !== -1) return "standings-unavailable"
  if (message.indexOf("Scores could not") !== -1) return "scores-unavailable"
  if (message.indexOf("Unable to load") !== -1) return "provider-unavailable"
  return "provider-error"
}

function dataState(s) {
  if (s.loading) return "loading"
  if (s.persistenceError || s.errorMessage) return "error"
  if (!s.hasData) return s.fetchedOnce ? "empty-window" : "unconfigured"
  if (s.loadedFromCache) return "cached"
  return "ready"
}

function build(s) {
  var state = s || {}
  var updated = Number(state.lastUpdatedMs) > 0
    ? new Date(Number(state.lastUpdatedMs)).toISOString()
    : "never"
  var lines = [
    "OmaSports diagnostics",
    "plugin: miguel.omasports " + String(state.pluginVersion || "unknown"),
    "sport: " + String(state.sport || "unknown") + " (" + String(state.provider || "unknown") + ")",
    "panel: " + (state.opened ? "open" : "closed") + ", mock=" + (state.mock ? "on" : "off"),
    "qt: " + String(state.qtVersion || "unknown") + " (" + String(state.platform || "unknown") + ")",
    "data: " + dataState(state),
    "last-update: " + updated,
    "last-error: " + errorCode(state.persistenceError, state.errorMessage),
    "failed-sources: " + String(state.failedSources || 0),
    "cache: " + String(state.knownCrests || 0) + " crests, " + String(state.pendingCrests || 0) + " pending",
    "prefs: background=" + (state.backgroundUpdates ? "on" : "off") +
      " ticker=" + (state.showBarTicker ? "on" : "off") +
      " spotlight=" + (state.showSpotlight ? "on" : "off") +
      " news=" + (state.showNewsWire ? "on" : "off") +
      " anti-spoiler=" + (state.antiSpoiler ? "on" : "off") +
      " notifications=" + (state.enableNotifications ? "on" : "off")
  ]
  return lines.join("\n")
}
