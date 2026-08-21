.pragma library

// The league catalogue follows Golazo's supported FotMob IDs. The page is
// deliberately kept local so opening the picker never needs a discovery call.
var supportedLeagues = [
  { value: "47", label: "Premier League", description: "England", region: "Europe" },
  { value: "87", label: "La Liga", description: "Spain", region: "Europe" },
  { value: "54", label: "Bundesliga", description: "Germany", region: "Europe" },
  { value: "146", label: "2. Bundesliga", description: "Germany", region: "Europe" },
  { value: "208", label: "3. Liga", description: "Germany", region: "Europe" },
  { value: "512", label: "Regionalliga", description: "Germany", region: "Europe" },
  { value: "55", label: "Serie A", description: "Italy", region: "Europe" },
  { value: "86", label: "Serie B", description: "Italy", region: "Europe" },
  { value: "53", label: "Ligue 1", description: "France", region: "Europe" },
  { value: "110", label: "Ligue 2", description: "France", region: "Europe" },
  { value: "9227", label: "Women's Super League", description: "England", region: "Europe" },
  { value: "9907", label: "Liga F", description: "Spain", region: "Europe" },
  { value: "9676", label: "Frauen-Bundesliga", description: "Germany", region: "Europe" },
  { value: "10178", label: "Serie A Femminile", description: "Italy", region: "Europe" },
  { value: "9667", label: "Première Ligue Féminine", description: "France", region: "Europe" },
  { value: "67", label: "Allsvenskan", description: "Sweden", region: "Europe" },
  { value: "38", label: "Austrian Bundesliga", description: "Austria", region: "Europe" },
  { value: "40", label: "Belgian First Division", description: "Belgium", region: "Europe" },
  { value: "48", label: "EFL Championship", description: "England", region: "Europe" },
  { value: "108", label: "EFL League One", description: "England", region: "Europe" },
  { value: "109", label: "EFL League Two", description: "England", region: "Europe" },
  { value: "196", label: "Ekstraklasa", description: "Poland", region: "Europe" },
  { value: "57", label: "Eredivisie", description: "Netherlands", region: "Europe" },
  { value: "218", label: "League of Ireland First Division", description: "Ireland", region: "Europe" },
  { value: "126", label: "League of Ireland Premier Division", description: "Ireland", region: "Europe" },
  { value: "61", label: "Primeira Liga", description: "Portugal", region: "Europe" },
  { value: "10215", label: "Primeira Liga Qualification", description: "Portugal", region: "Europe" },
  { value: "185", label: "Liga Portugal 2", description: "Portugal", region: "Europe" },
  { value: "9668", label: "Liga Portugal 2 Qualification", description: "Portugal", region: "Europe" },
  { value: "64", label: "Scottish Premiership", description: "Scotland", region: "Europe" },
  { value: "135", label: "Super League 1", description: "Greece", region: "Europe" },
  { value: "46", label: "Superligaen", description: "Denmark", region: "Europe" },
  { value: "85", label: "1. Division", description: "Denmark", region: "Europe" },
  { value: "59", label: "Eliteserien", description: "Norway", region: "Europe" },
  { value: "203", label: "1. Divisjon", description: "Norway", region: "Europe" },
  { value: "71", label: "Süper Lig", description: "Turkey", region: "Europe" },
  { value: "69", label: "Swiss Super League", description: "Switzerland", region: "Europe" },
  { value: "63", label: "Russian Premier League", description: "Russia", region: "Europe" },
  { value: "441", label: "Ukrainian Premier League", description: "Ukraine", region: "Europe" },
  { value: "42", label: "UEFA Champions League", description: "Europe", region: "Europe" },
  { value: "10216", label: "UEFA Conference League", description: "Europe", region: "Europe" },
  { value: "73", label: "UEFA Europa League", description: "Europe", region: "Europe" },
  { value: "50", label: "UEFA Euro", description: "Europe", region: "Europe" },
  { value: "292", label: "UEFA Women's Euro", description: "Europe", region: "Europe" },
  { value: "9375", label: "Women's UEFA Champions League", description: "Europe", region: "Europe" },
  { value: "138", label: "Copa del Rey", description: "Spain", region: "Europe" },
  { value: "139", label: "Supercopa de España", description: "Spain", region: "Europe" },
  { value: "132", label: "FA Cup", description: "England", region: "Europe" },
  { value: "209", label: "DFB Pokal", description: "Germany", region: "Europe" },
  { value: "10650", label: "Women's DFB Pokal", description: "Germany", region: "Europe" },
  { value: "141", label: "Coppa Italia", description: "Italy", region: "Europe" },
  { value: "134", label: "Coupe de France", description: "France", region: "Europe" },
  { value: "186", label: "Taça de Portugal", description: "Portugal", region: "Europe" },
  { value: "187", label: "Taça da Liga", description: "Portugal", region: "Europe" },
  { value: "188", label: "Supertaça Cândido de Oliveira", description: "Portugal", region: "Europe" },
  { value: "297", label: "CONCACAF Champions Cup", description: "North America", region: "Americas" },
  { value: "298", label: "CONCACAF Gold Cup", description: "North America", region: "Americas" },
  { value: "9821", label: "CONCACAF Nations League", description: "North America", region: "Americas" },
  { value: "268", label: "Brasileirão Série A", description: "Brazil", region: "Americas" },
  { value: "8814", label: "Brasileirão Série B", description: "Brazil", region: "Americas" },
  { value: "9067", label: "Copa do Brasil", description: "Brazil", region: "Americas" },
  { value: "10077", label: "Supercopa do Brasil", description: "Brazil", region: "Americas" },
  { value: "10244", label: "Paulista", description: "Brazil", region: "Americas" },
  { value: "10272", label: "Carioca", description: "Brazil", region: "Americas" },
  { value: "10273", label: "Mineiro", description: "Brazil", region: "Americas" },
  { value: "10274", label: "Gaúcho", description: "Brazil", region: "Americas" },
  { value: "9429", label: "Nordeste", description: "Brazil", region: "Americas" },
  { value: "10291", label: "Goiano", description: "Brazil", region: "Americas" },
  { value: "44", label: "Copa America", description: "South America", region: "Americas" },
  { value: "9490", label: "Copa Colombia", description: "Colombia", region: "Americas" },
  { value: "45", label: "Copa Libertadores", description: "South America", region: "Americas" },
  { value: "299", label: "Copa Sudamericana", description: "South America", region: "Americas" },
  { value: "491", label: "Recopa Sudamericana", description: "South America", region: "Americas" },
  { value: "112", label: "Liga Profesional", description: "Argentina", region: "Americas" },
  { value: "274", label: "Primera A", description: "Colombia", region: "Americas" },
  { value: "9125", label: "Primera B", description: "Colombia", region: "Americas" },
  { value: "161", label: "Primera Division", description: "Uruguay", region: "Americas" },
  { value: "273", label: "Primera Division", description: "Chile", region: "Americas" },
  { value: "131", label: "Liga 1", description: "Peru", region: "Americas" },
  { value: "246", label: "Serie A", description: "Ecuador", region: "Americas" },
  { value: "130", label: "MLS", description: "USA", region: "Americas" },
  { value: "8972", label: "USL Championship", description: "USA", region: "Americas" },
  { value: "9296", label: "USL League One", description: "USA", region: "Americas" },
  { value: "9134", label: "NWSL", description: "USA", region: "Americas" },
  { value: "10699", label: "USL Gainsbridge Super League", description: "USA", region: "Americas" },
  { value: "230", label: "Liga MX", description: "Mexico", region: "Americas" },
  { value: "536", label: "Saudi Pro League", description: "Saudi Arabia", region: "Global" },
  { value: "525", label: "AFC Champions League Elite", description: "Asia", region: "Global" },
  { value: "9469", label: "AFC Champions League Two", description: "Asia", region: "Global" },
  { value: "9478", label: "Indian Super League", description: "India", region: "Global" },
  { value: "223", label: "J. League", description: "Japan", region: "Global" },
  { value: "9080", label: "K League 1", description: "South Korea", region: "Global" },
  { value: "9137", label: "Chinese League One", description: "China", region: "Global" },
  { value: "535", label: "Qatar Stars League", description: "Qatar", region: "Global" },
  { value: "113", label: "A-League", description: "Australia", region: "Global" },
  { value: "526", label: "CAF Champions League", description: "Africa", region: "Global" },
  { value: "519", label: "Egyptian Premier League", description: "Egypt", region: "Global" },
  { value: "537", label: "Premier Soccer League", description: "South Africa", region: "Global" },
  { value: "530", label: "Botola Pro", description: "Morocco", region: "Global" },
  { value: "289", label: "Africa Cup of Nations", description: "International", region: "Global" },
  { value: "77", label: "FIFA World Cup", description: "International", region: "Global" },
  { value: "76", label: "Women's FIFA World Cup", description: "International", region: "Global" },
  { value: "78", label: "FIFA Club World Cup", description: "International", region: "Global" },
  { value: "9806", label: "UEFA Nations League", description: "International", region: "Global" },
  { value: "10304", label: "Finalissima", description: "International", region: "Global" },
  { value: "489", label: "Club Friendlies", description: "International", region: "Global" },
  { value: "114", label: "International Friendlies", description: "International", region: "Global" }
]

var supportedSports = [
  { value: "football", label: "Football / soccer", description: "FotMob data" }
]

function defaultState() {
  return {
    version: 1,
    sport: "football",
    leagueIds: ["61"],
    teamId: "",
    teamName: "",
    refreshMinutes: 15,
    standingsLeagueId: ""
  }
}

function arrayFrom(value) {
  if (!value || typeof value.length !== "number" || typeof value === "string") return []
  var result = []
  for (var i = 0; i < value.length; i++) result.push(value[i])
  return result
}

function normalizeLeagueIds(value) {
  var result = []
  var seen = {}
  var source = arrayFrom(value)
  for (var i = 0; i < source.length && result.length < 12; i++) {
    var id = String(source[i] || "")
    if (!id || seen[id]) continue
    seen[id] = true
    result.push(id)
  }
  return result
}

function parseState(raw) {
  var fallback = defaultState()
  var parsed = null
  try {
    parsed = JSON.parse(String(raw || ""))
  } catch (e) {
    return fallback
  }
  if (!parsed || typeof parsed !== "object") return fallback

  var ids = parsed.leagueIds
  if (!ids || typeof ids.length !== "number") ids = parsed.leagueId ? [parsed.leagueId] : fallback.leagueIds
  var minutes = parseInt(parsed.refreshMinutes, 10)
  if (isNaN(minutes)) minutes = fallback.refreshMinutes

  return {
    version: 1,
    sport: "football",
    leagueIds: normalizeLeagueIds(ids),
    teamId: String(parsed.teamId || ""),
    teamName: String(parsed.teamName || ""),
    refreshMinutes: Math.max(5, Math.min(60, minutes)),
    standingsLeagueId: String(parsed.standingsLeagueId || "")
  }
}

function statePayload(sport, leagueIds, teamId, teamName, refreshMinutes, standingsLeagueId) {
  return {
    version: 1,
    sport: String(sport || "football"),
    leagueIds: normalizeLeagueIds(leagueIds),
    teamId: String(teamId || ""),
    teamName: String(teamName || ""),
    refreshMinutes: Math.max(5, Math.min(60, parseInt(refreshMinutes, 10) || 15)),
    standingsLeagueId: String(standingsLeagueId || "")
  }
}

function extractPageProps(html) {
  var source = String(html || "")
  var markerIndex = source.indexOf("__NEXT_DATA__")
  if (markerIndex < 0) throw "FotMob page did not contain __NEXT_DATA__"
  var start = source.indexOf(">", markerIndex)
  if (start < 0) throw "FotMob page data tag was incomplete"
  start += 1
  var end = source.indexOf("</script>", start)
  if (end < 0) throw "FotMob page data tag did not close"

  var wrapper
  try {
    wrapper = JSON.parse(source.slice(start, end))
  } catch (e) {
    throw "FotMob page data was not valid JSON"
  }
  if (!wrapper || !wrapper.props || !wrapper.props.pageProps)
    throw "FotMob page data did not include fixtures"
  return wrapper.props.pageProps
}

function cleanPageUrl(value) {
  var url = String(value || "")
  var hash = url.indexOf("#")
  return hash >= 0 ? url.slice(0, hash) : url
}

function bool(value) {
  return value === true || value === 1 || value === "true"
}

function scoreParts(scoreText) {
  var match = String(scoreText || "").match(/(\d+)\s*[-:]\s*(\d+)/)
  if (!match) return { home: null, away: null, text: "" }
  return { home: parseInt(match[1], 10), away: parseInt(match[2], 10), text: match[1] + "–" + match[2] }
}

function parseMatch(raw, league) {
  var status = raw && raw.status ? raw.status : {}
  var reasonShort = String(status.reason && status.reason.short || "").toUpperCase().trim()
  var reasonLong = String(status.reason && status.reason.long || "").toUpperCase().trim()
  var score = scoreParts(status.scoreStr)
  if (score.home === null && status.score) {
    score.home = parseInt(status.score.home, 10)
    score.away = parseInt(status.score.away, 10)
    if (!isNaN(score.home) && !isNaN(score.away)) score.text = score.home + "–" + score.away
  }

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
  return {
    id: String(raw && raw.id || ""),
    leagueId: String(league.id || ""),
    leagueName: String(league.name || ""),
    round: String(raw && raw.round || ""),
    home: { id: String(home.id || ""), name: String(home.name || ""), shortName: String(home.shortName || home.name || "") },
    away: { id: String(away.id || ""), name: String(away.name || ""), shortName: String(away.shortName || away.name || "") },
    status: state,
    homeScore: score.home,
    awayScore: score.away,
    scoreText: score.text,
    statusReason: String(status.reason && status.reason.short || ""),
    liveTime: status.liveTime && status.liveTime.short ? String(status.liveTime.short) : (state === "live" ? "LIVE" : ""),
    time: String(status.utcTime || ""),
    pageUrl: cleanPageUrl(raw && raw.pageUrl)
  }
}

// Per-match enrichment from the match page: stadium, referee, attendance, halftime.
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
  if (status.halftimeScore) out.halftimeScore = String(status.halftimeScore)
  if (status.reason && status.reason.long) out.statusLong = String(status.reason.long)

  for (var key in out) return out
  return null
}

// Classify a zero-based table position through FotMob's own legend so zone
// colors follow the competition's rules (CL/Europe vs relegation) instead of
// hardcoding league-specific cutoffs.
function zoneFromLegend(legend, idx) {
  var source = arrayFrom(legend)
  for (var i = 0; i < source.length; i++) {
    var entry = source[i]
    var indices = arrayFrom(entry && entry.indices)
    for (var j = 0; j < indices.length; j++) {
      if (parseInt(indices[j], 10) !== idx) continue
      var title = String(entry.title || "").toLowerCase()
      if (title.indexOf("relegation") >= 0) return "relegation"
      return "europe"
    }
  }
  return ""
}

// pageProps.table[0].data.table.all is a flat row list with plain keys;
// cups and early-season competitions may omit the table entirely.
function parseStandings(props) {
  var groups = arrayFrom(props && props.table)
  var group = groups.length > 0 ? groups[0] : null
  var data = group && group.data ? group.data : null
  var views = null
  var legend = []
  if (data && data.table) {
    views = data.table
    legend = arrayFrom(data.legend)
  } else if (data && data.tables && data.tables.length > 0) {
    views = data.tables[0].table
    legend = arrayFrom(data.tables[0].legend || data.legend)
  }
  var rows = arrayFrom(views && views.all)

  var result = []
  for (var i = 0; i < rows.length && result.length < 30; i++) {
    var r = rows[i]
    if (!r || !r.name) continue
    result.push({
      pos: parseInt(r.idx, 10) || (i + 1),
      id: String(r.id || ""),
      name: String(r.name || ""),
      shortName: String(r.shortName || r.name || ""),
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

function parseLeaguePage(html, requestedId) {
  var props = extractPageProps(html)
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

// Parses a dedicated team page (https://www.fotmob.com/teams/<id>) to extract
// ALL fixtures across every competition (Champions League, Cups, League, etc.)
function parseTeamPage(html, requestedTeamId) {
  var props = extractPageProps(html)
  var fallback = props.fallback || {}
  var teamKey = "team-" + requestedTeamId
  var teamData = fallback[teamKey] || null
  if (!teamData) {
    for (var k in fallback) {
      if (k.indexOf("team-") === 0 && fallback[k] && fallback[k].fixtures) {
        teamData = fallback[k]
        break
      }
    }
  }
  if (!teamData || !teamData.fixtures || !teamData.fixtures.allFixtures) return []
  var rawFixtures = arrayFrom(teamData.fixtures.allFixtures.fixtures)
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

function mergePages(pages) {
  var matches = []
  var seen = {}
  var source = arrayFrom(pages)
  for (var i = 0; i < source.length; i++) {
    var pageMatches = source[i] && source[i].matches ? source[i].matches : []
    for (var j = 0; j < pageMatches.length; j++) {
      var match = pageMatches[j]
      if (!match || !match.id || seen[match.id]) continue
      seen[match.id] = true
      matches.push(match)
    }
  }
  return matches
}

function teamOptions(matches) {
  var byId = {}
  var source = arrayFrom(matches)
  for (var i = 0; i < source.length; i++) {
    var match = source[i]
    var league = match.leagueName || leagueLabel(match.leagueId)
    var teams = [match.home, match.away]
    for (var j = 0; j < teams.length; j++) {
      var team = teams[j]
      var id = String(team.id || team.name || "")
      if (!id || !team.name) continue
      if (!byId[id]) {
        byId[id] = {
          value: id,
          label: team.name,
          description: league || ""
        }
      }
    }
  }
  var result = []
  for (var key in byId) result.push(byId[key])
  result.sort(function(a, b) { return a.label.localeCompare(b.label) })
  return result
}

function matchesForTeam(matches, teamId) {
  var id = String(teamId || "")
  if (!id) return []
  var result = []
  var source = arrayFrom(matches)
  for (var i = 0; i < source.length; i++) {
    var match = source[i]
    if (String(match.home.id) === id || String(match.away.id) === id) result.push(match)
  }
  result.sort(function(a, b) {
    var rank = { live: 0, upcoming: 1, finished: 2, cancelled: 3 }
    var stateDifference = (rank[a.status] || 9) - (rank[b.status] || 9)
    if (stateDifference !== 0) return stateDifference
    var aTime = Date.parse(a.time || "")
    var bTime = Date.parse(b.time || "")
    if (a.status === "finished") return bTime - aTime
    return aTime - bTime
  })
  return result.slice(0, 8)
}

function matchesForLeague(matches, leagueId) {
  var id = String(leagueId || "")
  if (!id) return []
  var result = []
  var source = arrayFrom(matches)
  for (var i = 0; i < source.length; i++) {
    var match = source[i]
    if (String(match.leagueId) === id) result.push(match)
  }
  result.sort(function(a, b) {
    var rank = { live: 0, upcoming: 1, finished: 2, cancelled: 3 }
    var stateDifference = (rank[a.status] || 9) - (rank[b.status] || 9)
    if (stateDifference !== 0) return stateDifference
    var aTime = Date.parse(a.time || "")
    var bTime = Date.parse(b.time || "")
    if (a.status === "finished") return bTime - aTime
    return aTime - bTime
  })
  return result
}

function teamOutcome(match, teamId) {
  if (!match) return ""
  var id = String(teamId || "")
  if (!id) return ""
  if (match.status !== "finished" && match.status !== "live") return ""
  var h = match.homeScore
  var a = match.awayScore
  if (h === null || h === undefined || isNaN(h) || a === null || a === undefined || isNaN(a)) {
    var parts = scoreParts(match.scoreText)
    h = parts.home
    a = parts.away
  }
  if (h === null || a === null || isNaN(h) || isNaN(a)) return ""
  var isHome = String(match.home.id) === id
  var isAway = String(match.away.id) === id
  if (!isHome && !isAway) return ""
  var teamGoals = isHome ? h : a
  var oppGoals = isHome ? a : h
  if (teamGoals > oppGoals) return "win"
  if (teamGoals < oppGoals) return "loss"
  return "draw"
}

function featuredMatchForTeam(teamMatches) {
  var list = arrayFrom(teamMatches)
  if (list.length === 0) return null
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].status === "live") return list[i]
  }
  var upcoming = []
  for (var j = 0; j < list.length; j++) {
    if (list[j] && list[j].status === "upcoming") upcoming.push(list[j])
  }
  if (upcoming.length > 0) {
    upcoming.sort(function(a, b) { return Date.parse(a.time || "") - Date.parse(b.time || "") })
    return upcoming[0]
  }
  return list[0]
}

function leagueLabel(id) {
  var key = String(id || "")
  for (var i = 0; i < supportedLeagues.length; i++)
    if (supportedLeagues[i].value === key) return supportedLeagues[i].label
  return key ? "League " + key : ""
}

function matchStatusText(match) {
  if (!match) return ""
  var reason = match.statusReason || ""
  if (match.status === "live") {
    if (match.liveTime) return "Live " + match.liveTime
    return reason || "Live"
  }
  if (match.status === "finished") return reason || "FT"
  if (match.status === "cancelled") return reason || "Cancelled"
  return ""
}

function matchScoreText(match) {
  if (!match) return ""
  if (match.scoreText) return match.scoreText
  return "—"
}

function formatMatchDate(timeString) {
  var t = Date.parse(timeString || "")
  if (isNaN(t)) return ""
  var d = new Date(t)
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()]
}

function groupMatches(matches, now, formatDay) {
  var list = arrayFrom(matches)
  if (list.length === 0) return []

  var live = []
  var upcoming = []
  var finished = []

  for (var i = 0; i < list.length; i++) {
    var m = list[i]
    if (!m) continue
    if (m.status === "live") live.push(m)
    else if (m.status === "upcoming") upcoming.push(m)
    else finished.push(m)
  }

  upcoming.sort(function(a, b) { return Date.parse(a.time || "") - Date.parse(b.time || "") })
  finished.sort(function(a, b) { return Date.parse(b.time || "") - Date.parse(a.time || "") })

  var groups = []
  if (live.length > 0) groups.push({ label: "Live Matches", matches: live })
  if (upcoming.length > 0) groups.push({ label: "Upcoming Fixtures", matches: upcoming })
  if (finished.length > 0) groups.push({ label: "Recent Results", matches: finished })
  return groups
}

function cachePayload(pages, details) {
  var matches = []
  var standings = {}
  var source = arrayFrom(pages)
  for (var i = 0; i < source.length; i++) {
    var page = source[i]
    if (!page || !page.league) continue
    var trimmedMatches = arrayFrom(page.matches).slice(0, 300)
    matches = mergeTwoMatchLists(matches, trimmedMatches)
    var rows = arrayFrom(page.standings)
    if (rows.length > 0 && String(page.league.id) !== "") standings[String(page.league.id)] = rows.slice(0, 30)
  }
  return {
    version: 3,
    savedAt: new Date().toISOString(),
    matches: matches.slice(0, 300),
    standings: standings,
    details: details && typeof details === "object" ? details : {}
  }
}

function mergeTwoMatchLists(a, b) {
  var seen = {}
  var result = []
  var combined = arrayFrom(a).concat(arrayFrom(b))
  for (var i = 0; i < combined.length; i++) {
    var m = combined[i]
    if (!m || !m.id || seen[m.id]) continue
    seen[m.id] = true
    result.push(m)
  }
  return result
}

// Disk cache reader. Rejects anything older than two days or missing core
// fields so a corrupt or ancient cache never renders as fake live data.
function parseCache(raw) {
  var parsed = null
  try {
    parsed = JSON.parse(String(raw || ""))
  } catch (e) {
    return null
  }
  if (!parsed || typeof parsed !== "object") return null
  var savedAt = Date.parse(parsed.savedAt || "")
  if (isNaN(savedAt)) return null
  if (Date.now() - savedAt > 48 * 60 * 60 * 1000) return null

  var matches = []
  var source = arrayFrom(parsed.matches)
  for (var i = 0; i < source.length && matches.length < 300; i++) {
    var m = source[i]
    if (!m || !m.id || !m.home || !m.away || !m.home.name || !m.away.name) continue
    if (m.status !== "live" && m.status !== "upcoming" && m.status !== "finished" && m.status !== "cancelled") continue
    matches.push(m)
  }
  if (matches.length === 0) return null

  var standings = {}
  var rawStandings = parsed.standings && typeof parsed.standings === "object" ? parsed.standings : {}
  for (var key in rawStandings) {
    var rows = arrayFrom(rawStandings[key])
    var cleanRows = []
    for (var j = 0; j < rows.length && cleanRows.length < 30; j++) {
      var row = rows[j]
      if (!row || !row.name) continue
      cleanRows.push(row)
    }
    if (cleanRows.length > 0) standings[String(key)] = cleanRows
  }

  var details = {}
  var rawDetails = parsed.details && typeof parsed.details === "object" ? parsed.details : {}
  for (var dkey in rawDetails) {
    var entry = rawDetails[dkey]
    if (entry && typeof entry === "object" && (entry.stadium || entry.referee))
      details[String(dkey)] = entry
  }
  return { savedAt: savedAt, matches: matches, standings: standings, details: details }
}

// Live matches across every followed league, soonest kickoff first.
function liveMatches(matches, detailsMap) {
  var result = []
  var source = arrayFrom(matches)
  var map = detailsMap || {}
  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (!m || m.status !== "live") continue
    var d = map[String(m.id)]
    if (d && (d.statusLong === "Full-Time" || d.reason === "FT" || d.finished === true)) continue
    result.push(m)
  }
  result.sort(function(a, b) { return Date.parse(a.time || "") - Date.parse(b.time || "") })
  return result
}

// One-line score summary for the Live tab rows.
function matchLine(match) {
  if (!match) return ""
  var home = match.home.shortName || match.home.name
  var away = match.away.shortName || match.away.name
  var line = home + " " + (match.scoreText || "–") + " " + away
  if (match.liveTime) line += " · " + match.liveTime
  return line
}

// Formats tournament names concisely so long names never clip in fixture rows.
function shortTournamentName(name) {
  var s = String(name || "").trim()
  if (!s) return ""
  if (s.indexOf("Champions League Qualification") !== -1) return "UCL Qual."
  if (s.indexOf("Champions League") !== -1) return "Champions Lg"
  if (s.indexOf("Europa League Qualification") !== -1) return "UEL Qual."
  if (s.indexOf("Europa League") !== -1) return "Europa League"
  if (s.indexOf("Conference League Qualification") !== -1) return "UECL Qual."
  if (s.indexOf("Conference League") !== -1) return "Conf. League"
  if (s.indexOf("Primeira Liga") !== -1 || s.indexOf("Liga Portugal") !== -1) return "Liga Portugal"
  if (s.indexOf("Premier League") !== -1) return "Premier Lg"
  if (s.indexOf("Taca de Portugal") !== -1 || s.indexOf("Taça de Portugal") !== -1) return "Taça Portugal"
  if (s.indexOf("Taca da Liga") !== -1 || s.indexOf("Taça da Liga") !== -1) return "Taça da Liga"
  if (s.indexOf("Copa del Rey") !== -1) return "Copa del Rey"
  if (s.indexOf("Supercopa") !== -1) return "Supercopa"
  if (s.indexOf("Club Friendlies") !== -1) return "Friendly"
  return s
}

function leagues() { return supportedLeagues }
function sports() { return supportedSports }
