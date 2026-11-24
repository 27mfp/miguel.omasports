.pragma library
.import "../core.js" as Core
.import "../urls.js" as Urls

// ESPN JSON parsing (scoreboards, standings, broadcast, leaders, news).

function parseEspnScoreboard(raw, sportName, defaultLeagueName) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var events = Core.arrayFrom(json.events)
  var matches = []

  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    if (!e) continue
    var comp = (e.competitions && e.competitions[0]) || {}
    var competitors = Core.arrayFrom(comp.competitors)
    var home = { id: "", name: "Home", shortName: "Home", record: "" }
    var away = { id: "", name: "Away", shortName: "Away", record: "" }
    var homeScore = 0
    var awayScore = 0

    for (var c = 0; c < competitors.length; c++) {
      var item = competitors[c]
      if (!item) continue
      var team = item.team || {}
      var rec = (item.records && item.records[0] && item.records[0].summary) || ""
      var tObj = {
        id: String(team.id || ""),
        name: String(team.displayName || team.name || "Team"),
        shortName: String(team.shortDisplayName || team.name || team.abbreviation || "Team"),
        abbr: String(team.abbreviation || ""),
        record: rec,
        logo: String(team.logo || (team.logos && team.logos[0] && team.logos[0].href) || "")
      }
      if (item.homeAway === "home") {
        home = tObj
        homeScore = parseInt(item.score, 10) || 0
      } else if (item.homeAway === "away") {
        away = tObj
        awayScore = parseInt(item.score, 10) || 0
      }
    }

    var st = e.status || {}
    var stType = st.type || {}
    var stateStr = String(stType.state || "pre").toLowerCase()
    var status = "upcoming"
    var statusName = String(stType.name || "").toUpperCase()
    if (/CANCEL|POSTPON/.test(statusName)) status = "cancelled"
    else if (/SUSPEND|DELAY/.test(statusName)) status = stateStr === "in" ? "live" : "upcoming"
    else if (stateStr === "in") status = "live"
    else if (stateStr === "post") status = "finished"

    var scoreText = ""
    if (status === "live" || status === "finished") {
      scoreText = homeScore + "–" + awayScore
    }

    var liveTime = ""
    if (status === "live") {
      liveTime = String(stType.shortDetail || st.displayClock || "LIVE")
    }

    var homeLines = []
    var awayLines = []
    for (var cl = 0; cl < competitors.length; cl++) {
      var competitor = competitors[cl]
      if (!competitor || typeof competitor !== "object") continue
      var lines = Core.arrayFrom(competitor.linescores).map(function(l) {
        return l && typeof l.value === "number" && isFinite(l.value) ? l.value : null
      })
      if (competitor.homeAway === "home") homeLines = lines
      else if (competitor.homeAway === "away") awayLines = lines
    }

    var leagueTitle = (json.leagues && json.leagues[0] && json.leagues[0].name) || defaultLeagueName

    matches.push({
      id: String(e.id || ""),
      sport: sportName,
      leagueId: sportName,
      leagueName: leagueTitle,
      venue: String((comp.venue && comp.venue.fullName) || ""),
      round: (comp.season && comp.season.slug) || "",
      home: home,
      away: away,
      status: status,
      homeScore: homeScore,
      awayScore: awayScore,
      scoreText: scoreText,
      linescores: { home: homeLines, away: awayLines },
      statusReason: String(stType.shortDetail || ""),
      liveTime: liveTime,
      time: String(e.date || ""),
      pageUrl: (comp.headlines && comp.headlines[0] && comp.headlines[0].video && comp.headlines[0].video.links && comp.headlines[0].video.links.web && comp.headlines[0].video.links.web.href) || ("https://www.espn.com/" + sportName)
    })
  }
  return matches
}

function parseEspnStandings(raw, sportName) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return {} }
  if (!json || typeof json !== "object") return {}
  var groups = Core.arrayFrom(json.children)
  var result = {}

  for (var g = 0; g < groups.length; g++) {
    var group = groups[g]
    if (!group) continue
    var groupName = String(group.name || ("Group " + (g + 1)))
    var entries = (group.standings && group.standings.entries) ? Core.arrayFrom(group.standings.entries) : []
    var rows = []

    for (var e = 0; e < entries.length; e++) {
      var entry = entries[e]
      if (!entry) continue
      var team = entry.team || {}
      var stats = Core.arrayFrom(entry.stats)
      var statMap = {}
      for (var s = 0; s < stats.length; s++) {
        if (stats[s] && stats[s].name) statMap[stats[s].name] = stats[s]
      }

      var wins = parseInt((statMap.wins && statMap.wins.displayValue) || (statMap.wins && statMap.wins.value), 10) || 0
      var losses = parseInt((statMap.losses && statMap.losses.displayValue) || (statMap.losses && statMap.losses.value), 10) || 0
      var ties = parseInt((statMap.ties && statMap.ties.displayValue) || (statMap.otLosses && statMap.otLosses.displayValue) || (statMap.ties && statMap.ties.value), 10) || 0
      var played = wins + losses + ties
      var pts = (statMap.pts && statMap.pts.displayValue) || (statMap.points && statMap.points.displayValue) || (statMap.winPercent && statMap.winPercent.displayValue) || (wins + "W")
      // Total points/runs/goals difference, not the per-game average.
      var diff = (statMap.pointDifferential && statMap.pointDifferential.displayValue) || (statMap.runDifferential && statMap.runDifferential.displayValue) || (statMap.pointsDiff && statMap.pointsDiff.displayValue) || (statMap.differential && statMap.differential.displayValue) || "-"
      var pct = (statMap.winPercent && statMap.winPercent.displayValue)
        || (played > 0 ? ((wins + ties * 0.5) / played).toFixed(3) : ".000")
      var gb = statMap.gamesBehind
        ? String(statMap.gamesBehind.displayValue !== undefined ? statMap.gamesBehind.displayValue : statMap.gamesBehind.value)
        : "–"
      var seed = parseInt((statMap.playoffSeed && statMap.playoffSeed.displayValue), 10) || (e + 1)
      var logoUrl = (team.logos && team.logos[0] && team.logos[0].href) || (team.logo) || ""

      var zone = ""
      if (sportName === "nfl") {
        if (seed <= 7) zone = "europe"
      } else if (sportName === "nhl") {
        if (seed <= 8) zone = "europe"
      } else if (sportName === "mlb") {
        if (seed <= 6) zone = "europe"
      } else {
        // NBA: top 6 playoff seeds, 7-10 play-in
        if (seed <= 6) zone = "europe"
        else if (seed <= 10) zone = "playin"
      }

      rows.push({
        pos: String(seed),
        id: String(team.id || ""),
        name: String(team.displayName || team.name || "Team"),
        shortName: String(team.shortDisplayName || team.name || team.abbreviation || "Team"),
        abbr: String(team.abbreviation || ""),
        logo: String(logoUrl),
        played: played,
        wins: wins,
        draws: ties,
        losses: losses,
        gd: String(diff),
        pct: String(pct).replace(/^0\./, "."),
        gb: gb,
        pts: String(pts),
        zone: zone
      })
    }
    rows.sort(function(a, b) { return (parseInt(a.pos, 10) || 99) - (parseInt(b.pos, 10) || 99) })
    result[groupName] = rows
  }
  return result
}

function parseEspnBroadcast(comp) {
  if (!comp || typeof comp !== "object") return ""
  var broadcasts = Core.arrayFrom(comp.broadcasts)
  if (broadcasts.length === 0) return ""
  for (var i = 0; i < broadcasts.length; i++) {
    var b = broadcasts[i]
    if (b && b.market === "national" && Array.isArray(b.names) && b.names.length > 0) {
      return String(b.names[0])
    }
  }
  for (var j = 0; j < broadcasts.length; j++) {
    var b2 = broadcasts[j]
    if (b2 && Array.isArray(b2.names) && b2.names.length > 0) {
      return String(b2.names[0])
    }
  }
  return ""
}

function parseEspnGameLeaders(comp) {
  if (!comp || typeof comp !== "object") return []
  var leaders = Core.arrayFrom(comp.leaders)
  if (leaders.length === 0) return []
  var result = []
  for (var i = 0; i < leaders.length; i++) {
    var cat = leaders[i]
    if (!cat) continue
    var catName = String(cat.shortDisplayName || cat.abbreviation || cat.displayName || "")
    var topAthletes = Core.arrayFrom(cat.leaders)
    if (topAthletes.length === 0) continue
    var top = topAthletes[0]
    if (!top) continue
    var athlete = top.athlete || {}
    var val = String(top.displayValue || top.value || "")
    var name = String(athlete.shortName || athlete.displayName || athlete.fullName || "Player")
    result.push({
      category: catName,
      player: name,
      displayValue: val,
      headshot: String(athlete.headshot || "")
    })
  }
  return result
}

function parseEspnNews(raw) {
  var json = null
  try { json = typeof raw === "string" ? JSON.parse(raw) : raw } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var articles = Core.arrayFrom(json.articles)
  var result = []
  for (var i = 0; i < Math.min(articles.length, 5); i++) {
    var a = articles[i]
    if (!a || !a.headline) continue
    var link = (a.links && a.links.web && a.links.web.href) || ""
    var img = (a.images && a.images[0] && a.images[0].url) || ""
    result.push({
      headline: String(a.headline || "").trim(),
      description: String(a.description || "").trim(),
      published: String(a.published || ""),
      // News is rendered as a clickable external link. Keep the same
      // provider-host boundary used by Urls.matchExternalUrl instead of allowing a
      // provider payload to launch an arbitrary HTTPS destination.
      url: Urls.trustedHttpsUrl(link, ["espn.com"]),
      image: String(img)
    })
  }
  return result
}
