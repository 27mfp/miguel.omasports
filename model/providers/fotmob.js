.pragma library
.import "../core.js" as Core
.import "../urls.js" as Urls

// FotMob HTML/JSON parsing (league page, team page, match details, events, stats).

function extractPageProps(html) {
  if (!html) return {}
  if (typeof html === "object") {
    if (html.props && html.props.pageProps) return html.props.pageProps
    return html
  }
  if (typeof html !== "string") return {}
  var trimmed = html.trim()
  if ((trimmed.charAt(0) === "{" && trimmed.charAt(trimmed.length - 1) === "}") ||
      (trimmed.charAt(0) === "[" && trimmed.charAt(trimmed.length - 1) === "]")) {
    try {
      var direct = JSON.parse(trimmed)
      if (direct && direct.props && direct.props.pageProps) return direct.props.pageProps
      if (direct && typeof direct === "object") return direct
    } catch (e) {}
  }
  var scriptTags = /<script(?=\s|>)((?:[^"'<>]|"[^"]*"|'[^']*')*)>/gi
  var script
  while ((script = scriptTags.exec(html)) !== null) {
    var attributes = /([^\s"'<>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>]+)))?/g
    var id = ""
    var type = ""
    var attribute
    while ((attribute = attributes.exec(script[1])) !== null) {
      var name = attribute[1].toLowerCase()
      var value = attribute[2] || attribute[3] || attribute[4] || ""
      if (name === "id") id = value
      if (name === "type") type = value
    }
    if (id !== "__NEXT_DATA__" || type.toLowerCase() !== "application/json") continue

    var start = scriptTags.lastIndex
    var end = html.indexOf("</script>", start)
    if (end === -1) return {}
    try {
      var parsed = JSON.parse(html.substring(start, end))
      return (parsed && parsed.props && parsed.props.pageProps) || {}
    } catch (e) {
      return {}
    }
  }
  return {}
}

function parseScore(status) {
  if (!status) return { home: 0, away: 0, text: "" }
  if (typeof status.scoreStr === "string" && status.scoreStr.indexOf("-") !== -1) {
    var parts = status.scoreStr.split("-")
    var home = parseInt(parts[0].trim(), 10) || 0
    var away = parseInt(parts[1].trim(), 10) || 0
    return { home: home, away: away, text: home + "–" + away }
  }
  var aggregate = status.aggregateStr || ""
  if (aggregate) return { home: 0, away: 0, text: aggregate }
  return { home: 0, away: 0, text: "" }
}

function parseMatch(raw, league) {
  var score = parseScore(raw && raw.status)
  var status = raw && raw.status ? raw.status : {}
  var bool = function(v) { return v === true || v === "true" }

  var reasonShort = String(status.reason && status.reason.short || "").toUpperCase()
  var reasonLong = String(status.reason && status.reason.long || "").toUpperCase()

  var isFinishedReason = reasonShort === "FT" || reasonShort === "AET" || reasonShort === "PEN" || reasonLong.indexOf("FULL") !== -1 || reasonLong.indexOf("AFTER EXTRA") !== -1 || reasonLong.indexOf("PENALTIES") !== -1 || bool(status.finished)
  var isCancelledReason = reasonShort === "CANC" || reasonShort === "POSTP" || reasonShort === "ABD" || reasonLong.indexOf("CANCEL") !== -1 || reasonLong.indexOf("POSTP") !== -1 || reasonLong.indexOf("ABANDON") !== -1 || bool(status.cancelled)

  var state = "upcoming"
  if (isCancelledReason) {
    state = "cancelled"
  } else if (isFinishedReason) {
    state = "finished"
  } else if (bool(status.ongoing) || (bool(status.started) && !bool(status.finished) && !isFinishedReason)) {
    state = "live"
  }

  var home = raw && raw.home ? raw.home : {}
  var away = raw && raw.away ? raw.away : {}
  var homeId = String(home.id || "")
  var awayId = String(away.id || "")
  var homeLogo = homeId !== "" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + homeId + ".png") : ""
  var awayLogo = awayId !== "" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + awayId + ".png") : ""

  return {
    id: String(raw && raw.id || ""),
    sport: "football",
    leagueId: String(league.id || ""),
    leagueName: String(league.name || ""),
    round: String(raw && raw.round || ""),
    home: { id: homeId, name: String(home.name || ""), shortName: String(home.shortName || home.name || ""), logo: homeLogo },
    away: { id: awayId, name: String(away.name || ""), shortName: String(away.shortName || away.name || ""), logo: awayLogo },
    status: state,
    homeScore: score.home,
    awayScore: score.away,
    scoreText: score.text,
    statusReason: String(status.reason && status.reason.short || ""),
    liveTime: status.liveTime && status.liveTime.short ? String(status.liveTime.short).replace(/[\u200e\u200f]/g, "").trim() : (state === "live" ? "LIVE" : ""),
    time: String(status.utcTime || ""),
    pageUrl: Urls.cleanPageUrl(raw && raw.pageUrl)
  }
}

function parseDetails(html) {
  var props = extractPageProps(html)
  var content = props.content || {}
  var facts = content.matchFacts || {}
  var box = facts.infoBox || {}
  var header = props.header || {}
  var status = header.status || {}

  var out = {}
  var stadium = box.Stadium || null
  if (stadium && stadium.name) {
    out.stadium = String(stadium.name)
    if (stadium.city) out.city = String(stadium.city)
  }
  var referee = box.Referee || null
  if (referee && referee.text) out.referee = String(referee.text)
  if (typeof box.Attendance === "number" && box.Attendance > 0) out.attendance = box.Attendance
  var gen = props.general || {}
  if (gen.leagueRoundName) out.round = String(gen.leagueRoundName)
  if (status.halftimeScore) {
    out.halftimeScore = String(status.halftimeScore)
  } else {
    var evList = (facts.events && facts.events.events) || facts.events || (content.matchFacts && content.matchFacts.events && content.matchFacts.events.events) || []
    if (Array.isArray(evList)) {
      for (var i = 0; i < evList.length; i++) {
        var ev = evList[i]
        if (ev && ev.type === "Half" && ev.halfStrShort === "HT" && typeof ev.homeScore === "number" && typeof ev.awayScore === "number") {
          out.halftimeScore = ev.homeScore + " – " + ev.awayScore
          break
        }
      }
    }
  }
  if (status.reason && status.reason.long) out.statusLong = String(status.reason.long)
  if (status.reason && status.reason.short) out.reason = String(status.reason.short)
  if (status.finished === true) out.finished = true
  if (status.liveTime && status.liveTime.short) {
    out.liveTime = String(status.liveTime.short).replace(/[\u200e\u200f]/g, "").trim()
  }
  if (!status.finished && status.scoreStr) {
    out.liveScore = String(status.scoreStr)
  }

  return Object.keys(out).length > 0 ? out : null
}

function parseStandings(props) {
  var table = props && props.table ? props.table : []
  var tableBlock = null
  if (Array.isArray(table)) {
    tableBlock = table.length > 0 ? table[0] : null
  } else if (table && typeof table === "object") {
    tableBlock = table
  }
  var tableData = tableBlock && tableBlock.data ? tableBlock.data : {}
  var tableValues = tableData.table || {}
  var rows = Core.arrayFrom(tableValues.all)
  var legend = Core.arrayFrom(tableData.legend)
  var result = []
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    var tId = String(r.id || "")
    result.push({
      pos: String(r.idx || (i + 1)),
      id: tId,
      name: String(r.name || ""),
      shortName: String(r.shortName || r.name || ""),
      logo: tId !== "" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + tId + ".png") : "",
      played: parseInt(r.played, 10) || 0,
      wins: parseInt(r.wins, 10) || 0,
      draws: parseInt(r.draws, 10) || 0,
      losses: parseInt(r.losses, 10) || 0,
      gd: parseInt(r.goalConDiff, 10) || 0,
      pts: parseInt(r.pts, 10) || 0,
      zone: zoneFromLegend(legend, i)
    })
  }
  return result
}

function zoneFromLegend(legend, idx) {
  var source = Core.arrayFrom(legend)
  for (var i = 0; i < source.length; i++) {
    var entry = source[i]
    if (!entry || !entry.indices) continue
    var indices = Core.arrayFrom(entry.indices)
    for (var j = 0; j < indices.length; j++) {
      if (Number(indices[j]) === idx) {
        var key = String(entry.title || "").toLowerCase()
        if (key.indexOf("champions league") !== -1 || key.indexOf("promotion") !== -1 || key.indexOf("qualification") !== -1 || key.indexOf("playoff") !== -1)
          return "europe"
        if (key.indexOf("relegation") !== -1 || key.indexOf("bottom") !== -1)
          return "relegation"
      }
    }
  }
  return ""
}

function parseLeaguePage(html, requestedId) {
  var props = extractPageProps(html)
  // A page with no provider payload at all (bot-wall, consent page, rate-limit
  // HTML) is a fetch failure, not an empty league — returning null lets the
  // caller retry instead of silently rendering nothing
  if (!props.details && !props.fixtures && !props.table) return null
  var details = props.details || {}
  var fixtures = props.fixtures || {}
  var league = {
    id: String(details.id || requestedId || ""),
    name: String(details.name || "League " + (requestedId || "")),
    country: String(details.country || "")
  }
  var matches = []
  var source = fixtures.allMatches || []
  for (var i = 0; i < source.length; i++) {
    var match = parseMatch(source[i], league)
    if (match.id && match.home.name && match.away.name) matches.push(match)
  }
  return { league: league, matches: matches, standings: parseStandings(props) }
}

function findTeamPageData(html, requestedTeamId) {
  var props = extractPageProps(html)
  if (props.fixtures && props.fixtures.allFixtures) return props
  var fallback = props.fallback || {}
  var teamKey = "team-" + String(requestedTeamId || "")
  // The fallback map can contain several team payloads. Never substitute the
  // first available team when the requested key is absent: that would show a
  // different club's schedule after a provider schema change.
  return fallback[teamKey] || null
}

function isTeamPagePayload(html, requestedTeamId) {
  var teamData = findTeamPageData(html, requestedTeamId)
  return !!(teamData && teamData.fixtures && teamData.fixtures.allFixtures)
}

function parseTeamPage(html, requestedTeamId) {
  var teamData = findTeamPageData(html, requestedTeamId)
  if (!teamData || !teamData.fixtures || !teamData.fixtures.allFixtures) return []
  var rawFixtures = Core.arrayFrom(teamData.fixtures.allFixtures.fixtures)
  var matches = []
  for (var i = 0; i < rawFixtures.length; i++) {
    var f = rawFixtures[i]
    var t = f.tournament || {}
    var league = {
      id: String(t.leagueId || ""),
      name: String(t.name || "Competition"),
      country: ""
    }
    var match = parseMatch(f, league)
    if (match.id && match.home.name && match.away.name) matches.push(match)
  }
  return matches
}

function parseFotmobEvents(raw) {
  if (!raw) return { goals: [], redCards: [] }
  var evList = []
  if (Array.isArray(raw)) {
    evList = raw
  } else if (typeof raw === "object") {
    var mf = raw.matchFacts || raw
    var evObj = mf.events || {}
    evList = Array.isArray(evObj.events) ? evObj.events : (Array.isArray(evObj) ? evObj : [])
  }
  var goals = []
  var redCards = []
  for (var i = 0; i < evList.length; i++) {
    var e = evList[i]
    if (!e) continue
    var type = String(e.type || "")
    var min = e.time !== undefined ? String(e.time) : (e.timeStr !== undefined ? String(e.timeStr) : "")
    if (e.overloadTime) min += "+" + e.overloadTime
    var player = String(e.nameStr || (e.player && (e.player.name || e.player.fullName)) || "Player")
    var isHome = Boolean(e.isHome)

    if (type === "Goal") {
      var suffix = e.ownGoal ? " (OG)" : (e.isPenaltyShootoutEvent || e.suffix === "Pen" ? " (P)" : "")
      var assist = ""
      if (e.assistInput) assist = String(e.assistInput)
      else if (e.assistStr) assist = String(e.assistStr).replace(/^assist by /i, "")
      goals.push({
        minute: min ? min + "'" : "",
        player: player + suffix,
        assist: assist,
        isHome: isHome
      })
    } else if (type === "Card" && (e.card === "Red" || e.card === "YellowRed")) {
      redCards.push({
        minute: min ? min + "'" : "",
        player: player,
        isHome: isHome
      })
    }
  }
  return { goals: goals, redCards: redCards }
}

function parseFotmobForm(teamForm) {
  if (!teamForm) return { home: [], away: [] }
  var homeList = []
  var awayList = []
  if (Array.isArray(teamForm)) {
    var hRaw = Array.isArray(teamForm[0]) ? teamForm[0] : []
    var aRaw = Array.isArray(teamForm[1]) ? teamForm[1] : []
    for (var i = 0; i < Math.min(hRaw.length, 5); i++) {
      var r = hRaw[i]
      if (r && r.resultString) homeList.push(String(r.resultString).toUpperCase())
    }
    for (var j = 0; j < Math.min(aRaw.length, 5); j++) {
      var r2 = aRaw[j]
      if (r2 && r2.resultString) awayList.push(String(r2.resultString).toUpperCase())
    }
  }
  return { home: homeList, away: awayList }
}

function parseFotmobStats(stats) {
  if (!stats || typeof stats !== "object") return null
  var allStats = []
  if (stats.Periods && stats.Periods.All && Array.isArray(stats.Periods.All.stats)) {
    allStats = stats.Periods.All.stats
  } else if (Array.isArray(stats)) {
    allStats = stats
  }
  var possession = null
  var xG = null
  var shotsOnTarget = null
  for (var i = 0; i < allStats.length; i++) {
    var group = allStats[i]
    var items = (group && Array.isArray(group.stats)) ? group.stats : []
    for (var j = 0; j < items.length; j++) {
      var it = items[j]
      if (!it || !it.key) continue
      var key = String(it.key).toLowerCase()
      if (key === "ballpossesion" || key === "possession") {
        if (Array.isArray(it.stats) && it.stats.length >= 2) {
          possession = [parseInt(it.stats[0], 10) || 50, parseInt(it.stats[1], 10) || 50]
        }
      } else if (key === "expected_goals" || key === "xg") {
        if (Array.isArray(it.stats) && it.stats.length >= 2) {
          xG = [String(it.stats[0]), String(it.stats[1])]
        }
      } else if (key === "shotsontarget" || key === "shots_on_target") {
        if (Array.isArray(it.stats) && it.stats.length >= 2) {
          shotsOnTarget = [parseInt(it.stats[0], 10) || 0, parseInt(it.stats[1], 10) || 0]
        }
      }
    }
  }
  if (!possession && !xG && !shotsOnTarget) return null
  return {
    possession: possession || [50, 50],
    xG: xG || ["0.0", "0.0"],
    shotsOnTarget: shotsOnTarget || [0, 0]
  }
}
