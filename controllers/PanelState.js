.pragma library

// State-management helpers for Panel.qml. The panel remains the owner of QML
// properties and process objects; these functions keep parsing, migration
// decisions, serialization and file-path construction in one testable place.

function stateFilePath(home) {
  return String(home || "") + "/.config/omarchy/sports-favorites.json"
}

function tabName(tabIndex) {
  if (tabIndex === 3) return "settings"
  if (tabIndex === 2) return "standings"
  if (tabIndex === 1) return "live"
  return "fixtures"
}

function loadedState(raw, ignoredSignature, parseState) {
  var next = parseState(String(raw || ""))
  var signature = JSON.stringify(next)
  return {
    state: next,
    signature: signature,
    ownWrite: ignoredSignature !== "" && signature === ignoredSignature
  }
}

function settings(state, fallbacks) {
  var saved = state || {}
  var defaults = fallbacks || {}
  return {
    activeSport: String(saved.sport || "football"),
    antiSpoiler: saved.antiSpoiler === true,
    enableNotifications: saved.notifications !== false,
    showNewsWire: saved.showNewsWire !== false,
    backgroundUpdates: saved.backgroundUpdates !== undefined
      ? saved.backgroundUpdates === true
      : defaults.backgroundUpdates === true,
    showBarTicker: saved.showBarTicker !== undefined
      ? saved.showBarTicker === true
      : defaults.showBarTicker === true,
    showSpotlight: saved.showSpotlight !== false
  }
}

function persistedState(activeSport, savedState, ui, buildPersistedState) {
  var next = buildPersistedState(activeSport, savedState, {
    tabName: ui.tabName,
    selectedLeagueIds: ui.selectedLeagueIds,
    selectedTeamIds: ui.selectedTeamIds,
    selectedTeamName: ui.selectedTeamName,
    standingsLeagueId: ui.standingsLeagueId,
    antiSpoiler: ui.antiSpoiler,
    enableNotifications: ui.enableNotifications,
    backgroundUpdates: ui.backgroundUpdates,
    showBarTicker: ui.showBarTicker,
    showSpotlight: ui.showSpotlight
  })
  next.showNewsWire = ui.showNewsWire
  next.backgroundUpdates = ui.backgroundUpdates
  next.showBarTicker = ui.showBarTicker
  next.showSpotlight = ui.showSpotlight
  return next
}

function serialize(state) {
  return JSON.stringify(state, null, 2) + "\n"
}

function selectedLeagueNameList(activeSport, activeSportLabel, leagueIds, labelFor, arrayFrom) {
  if (activeSport !== "football") return activeSportLabel
  var names = []
  var ids = arrayFrom(leagueIds)
  for (var i = 0; i < ids.length; i++) names.push(labelFor(ids[i]))
  return names.join(", ")
}
