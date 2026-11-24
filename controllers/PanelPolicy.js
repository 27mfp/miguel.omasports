.pragma library

// Pure polling/status policy shared by Panel.qml. Keeping these decisions out
// of the declarative component makes them easy to reason about and test, and
// leaves Panel.qml responsible for signal wiring and QML state mutation.

function relativeAge(nowMs, lastUpdatedMs) {
  var mins = Math.floor(Math.max(0, Number(nowMs) - Number(lastUpdatedMs)) / 60000)
  if (mins < 1) return "just now"
  if (mins < 60) return mins + " min ago"
  var h = Math.floor(mins / 60)
  return h + "h" + (mins % 60 > 0 ? (mins % 60) + "m" : "") + " ago"
}

function statusLine(state) {
  var s = state || {}
  if (s.loading && !s.hasData) return "󰥔 Loading " + s.activeSportLabel + "…"
  if (s.loading) return "󰥔 Updating scores…"
  if (s.persistenceError) return s.persistenceError
  if (s.errorMessage) return s.errorMessage
  if (!s.hasData) {
    return s.fetchedOnce
      ? "Nothing scheduled in the next few days."
      : "Follow teams or leagues to track " + s.activeSportLabel + "."
  }
  var age = relativeAge(s.nowMs, s.lastUpdatedMs)
  if (s.fastPolling) return "● LIVE · updated " + age
  if (s.loadedFromCache) return "Cached · updated " + age
  return "Updated " + age
}

function hasLiveFollowedMatch(teamMatches) {
  var matches = teamMatches || []
  for (var i = 0; i < matches.length; i++) {
    if (matches[i] && matches[i].status === "live") return true
  }
  return false
}

function shouldFastPoll(monitoringAllowed, liveCount, followedLive) {
  if (followedLive) return true
  return !!monitoringAllowed && Number(liveCount) > 0
}

function livePollIntervalMs(sport) {
  if (sport === "nba" || sport === "nfl" || sport === "mlb" || sport === "nhl") {
    return 15000 // ESPN direct JSON API
  }
  return 20000 // FotMob & F1: safe edge-cache floor
}

function nextPollDelay(monitoringAllowed, opened, slowRefreshMs, fastPolling, sport) {
  if (!monitoringAllowed) return 0
  if (fastPolling) return livePollIntervalMs(sport)
  if (opened) return Math.min(slowRefreshMs, 60000)
  return slowRefreshMs
}

function ipcAllowed(lastIpcAt, nowMs, minGapMs) {
  return (Number(nowMs) - Number(lastIpcAt || 0)) >= Number(minGapMs || 250)
}
