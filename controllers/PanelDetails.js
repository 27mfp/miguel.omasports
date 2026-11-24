.pragma library

// Pure football detail-enrichment helpers. Panel.qml owns the QML Process
// objects and queue cursor; these functions decide what to fetch and how a
// parsed detail response updates the existing maps/arrays.

function copyMap(source) {
  var out = {}
  for (var key in source) out[key] = source[key]
  return out
}

function wantedDetails(monitoringAllowed, sport, allMatches, matchDetails, teamMatchesRaw, teamMatches, nowMs, api) {
  if (!monitoringAllowed || sport !== "football") return []
  var wanted = []
  var live = api.liveMatches(allMatches, matchDetails, nowMs)
  for (var i = 0; i < live.length && wanted.length < 8; i++) {
    var lid = String(live[i].id)
    if (wanted.indexOf(lid) === -1) wanted.push(lid)
  }
  var source = teamMatchesRaw && teamMatchesRaw.length > 0 ? teamMatchesRaw : teamMatches
  for (var j = 0; j < source.length && wanted.length < 8; j++) {
    var tid = String(source[j].id)
    if (wanted.indexOf(tid) === -1 && (!matchDetails[tid] || (source[j] && source[j].status === "live"))) wanted.push(tid)
  }
  return wanted.slice(0, 8)
}

function enrich(raw, id, matchDetails, matchEvents, matchForm, matchStats, api) {
  var parsed = api.parseDetails(raw)
  if (!parsed) return null
  var details = copyMap(matchDetails)
  details[id] = parsed
  var result = { parsed: parsed, details: details, events: null, form: null, stats: null }

  var props = api.extractPageProps(raw)
  if (props && props.content) {
    var evs = api.parseFotmobEvents(props.content)
    if (evs && (evs.goals.length > 0 || evs.redCards.length > 0)) {
      result.events = copyMap(matchEvents)
      result.events[id] = evs
    }
    if (props.content.overview && props.content.overview.teams) {
      var form = api.parseFotmobForm(props.content.overview.teams)
      if (form && (form.home.length > 0 || form.away.length > 0)) {
        result.form = copyMap(matchForm)
        result.form[id] = form
      }
    }
    if (props.content.stats) {
      var stats = api.parseFotmobStats(props.content.stats)
      if (stats) {
        result.stats = copyMap(matchStats)
        result.stats[id] = stats
      }
    }
  }
  return result
}

function isFullTime(parsed) {
  return parsed.finished === true || parsed.reason === "FT" || parsed.reason === "AET" || parsed.reason === "PEN" ||
    (parsed.statusLong && /full|extra|penalt|finish|ended/i.test(parsed.statusLong))
}

function applyToMatches(matches, id, parsed, isFT, api) {
  var next = api.arrayFrom(matches)
  var touched = false
  for (var i = 0; i < next.length; i++) {
    if (String(next[i].id) !== id) continue
    var copy = Object.assign({}, next[i])
    if (isFT && copy.status === "live") {
      copy.status = "finished"
      copy.statusReason = parsed.reason || "FT"
      copy.liveTime = ""
      touched = true
    }
    if (parsed.liveTime && copy.status === "live") {
      copy.liveTime = parsed.liveTime
      touched = true
    }
    if (parsed.liveScore && copy.status === "live") {
      copy.scoreText = parsed.liveScore
      touched = true
    }
    next[i] = copy
  }
  return { matches: next, touched: touched }
}

function applyToTeamMatches(matches, id, parsed, isFT, api) {
  var next = api.arrayFrom(matches)
  var touched = false
  for (var i = 0; i < next.length; i++) {
    if (String(next[i].id) !== id) continue
    var copy = Object.assign({}, next[i])
    if (isFT && copy.status === "live") {
      copy.status = "finished"
      copy.statusReason = parsed.reason || "FT"
      copy.liveTime = ""
      touched = true
    }
    if (parsed.liveTime && copy.status === "live") {
      copy.liveTime = parsed.liveTime
      touched = true
    }
    if (parsed.liveScore && copy.status === "live") {
      copy.scoreText = parsed.liveScore
      touched = true
    }
    next[i] = copy
    break
  }
  return { matches: next, touched: touched }
}

function reconcile(parsed, id, allMatches, teamMatchesRaw, api) {
  var isFT = isFullTime(parsed)
  var all = applyToMatches(allMatches, id, parsed, isFT, api)
  var team = applyToTeamMatches(teamMatchesRaw, id, parsed, isFT, api)
  return {
    allMatches: all.matches,
    allTouched: all.touched,
    teamMatchesRaw: team.matches,
    teamTouched: team.touched
  }
}
