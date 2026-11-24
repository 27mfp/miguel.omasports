.pragma library
.import "core.js" as Core

// Match normalization, selection, merging, live-clock helpers, and identity comparison.

var _liveClockCache = {}

function mergePages(pages) {
  var matches = []
  var seen = {}
  var source = Core.arrayFrom(pages)
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

function parseClockMinute(timeStr) {
  if (!timeStr) return 0
  var s = String(timeStr).replace(/[\u200e\u200f\s]/g, "").toUpperCase()
  if (s === "HT") return 45.5
  if (s === "FT") return 999
  var m = s.match(/^(\d{1,3})/)
  if (m) return parseInt(m[1], 10) || 0
  return 0
}

function mergeMatchUpdates(existing, updates) {
  var result = Core.arrayFrom(existing).slice()
  var indexes = {}
  for (var i = 0; i < result.length; i++) {
    if (result[i] && result[i].id) indexes[String(result[i].id)] = i
  }
  var source = Core.arrayFrom(updates)
  for (var j = 0; j < source.length; j++) {
    var match = source[j]
    if (!match || !match.id) continue
    var key = String(match.id)
    if (indexes[key] === undefined) {
      indexes[key] = result.length
      result.push(match)
    } else {
      var prev = result[indexes[key]]
      // Never allow a finished match to regress back to live or upcoming due to stale cache:
      if (prev && prev.status === "finished" && match.status !== "finished") {
        match = Object.assign({}, match, {
          status: "finished",
          statusReason: prev.statusReason || match.statusReason || "FT",
          scoreText: prev.scoreText || match.scoreText,
          homeScore: prev.homeScore !== undefined ? prev.homeScore : match.homeScore,
          awayScore: prev.awayScore !== undefined ? prev.awayScore : match.awayScore,
          liveTime: ""
        })
      }
      // Protect live matches from stale SSR cache regression:
      // A team page fixture cache from FotMob often serves frozen 1' data.
      // Never allow a live match clock to regress from e.g. 47' or HT back to 1'.
      else if (prev && prev.status === "live" && match.status === "live") {
        var prevMin = parseClockMinute(prev.liveTime)
        var newMin = parseClockMinute(match.liveTime)
        if (prevMin > 0 && newMin > 0 && newMin < prevMin) {
          match = Object.assign({}, match, {
            liveTime: prev.liveTime,
            scoreText: prev.scoreText || match.scoreText,
            homeScore: prev.homeScore !== undefined ? prev.homeScore : match.homeScore,
            awayScore: prev.awayScore !== undefined ? prev.awayScore : match.awayScore
          })
        } else if (prevMin > 0 && (newMin <= 0 || !match.liveTime)) {
          match = Object.assign({}, match, { liveTime: prev.liveTime })
        }
      }
      result[indexes[key]] = match
    }
  }
  return result
}

function mergeLeaguePages(existing, updates) {
  var result = Core.arrayFrom(existing).slice()
  var indexes = {}
  for (var i = 0; i < result.length; i++) {
    var oldPage = result[i]
    if (oldPage && oldPage.league && oldPage.league.id)
      indexes[String(oldPage.league.id)] = i
  }
  var source = Core.arrayFrom(updates)
  for (var j = 0; j < source.length; j++) {
    var page = source[j]
    if (!page || !page.league || !page.league.id) continue
    var key = String(page.league.id)
    if (indexes[key] === undefined) {
      indexes[key] = result.length
      result.push(page)
    } else {
      result[indexes[key]] = page
    }
  }
  return result
}

function teamOptionsForSport(sport, matches) {
  var s = String(sport || "football").toLowerCase()
  if (s === "nba") return Core.nbaTeams
  if (s === "f1") return Core.f1Drivers
  if (s === "nfl") return Core.nflTeams
  if (s === "mlb") return Core.mlbTeams
  if (s === "nhl") return Core.nhlTeams

  var byId = {}
  for (var p = 0; p < Core.popularFootballClubs.length; p++) {
    var club = Core.popularFootballClubs[p]
    byId[String(club.value)] = club
  }

  var source = Core.arrayFrom(matches)
  for (var i = 0; i < source.length; i++) {
    var match = source[i]
    if (!match) continue
    if (match.home && match.home.id && match.home.name) {
      var hId = String(match.home.id)
      if (!byId[hId]) {
        byId[hId] = {
          value: hId,
          label: match.home.name,
          description: match.leagueName || "Football"
        }
      }
    }
    if (match.away && match.away.id && match.away.name) {
      var aId = String(match.away.id)
      if (!byId[aId]) {
        byId[aId] = {
          value: aId,
          label: match.away.name,
          description: match.leagueName || "Football"
        }
      }
    }
  }
  var list = []
  for (var key in byId) list.push(byId[key])
  list.sort(function(a, b) { return a.label.localeCompare(b.label) })
  return list
}

function isFollowedTeam(teamId, teamIds) {
  var id = String(teamId || "").trim().toLowerCase()
  if (!id) return false
  var ids = (typeof teamIds === "string" || typeof teamIds === "number") ? [teamIds] : Core.arrayFrom(teamIds)
  for (var i = 0; i < ids.length; i++) {
    if (String(ids[i] || "").trim().toLowerCase() === id) return true
  }
  return false
}

function isNumericIdentifier(value) {
  return /^\d+$/.test(String(value || "").trim())
}

function compareMatchTimes(a, b) {
  var ta = Core.parseMatchTimeMs(a)
  var tb = Core.parseMatchTimeMs(b)
  if (isNaN(ta) && isNaN(tb)) return 0
  if (isNaN(ta)) return 1
  if (isNaN(tb)) return -1
  return ta - tb
}

function matchesForTeam(matches, teamIdOrIds, sport) {
  var s = String(sport || "football").toLowerCase()
  var rawIds = Array.isArray(teamIdOrIds) ? teamIdOrIds : [teamIdOrIds]
  var ids = []
  for (var k = 0; k < rawIds.length; k++) {
    var str = String(rawIds[k] || "").trim().toLowerCase()
    if (str && ids.indexOf(str) === -1) ids.push(str)
  }
  if (ids.length === 0) return []

  var result = []
  var seen = {}
  var source = Core.arrayFrom(matches)
  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (!m || seen[m.id]) continue
    var homeId = String(m.home && m.home.id || "").toLowerCase()
    var awayId = String(m.away && m.away.id || "").toLowerCase()
    var homeName = String(m.home && m.home.name || "").trim().toLowerCase()
    var awayName = String(m.away && m.away.name || "").trim().toLowerCase()
    var homeShort = String(m.home && m.home.shortName || "").trim().toLowerCase()
    var awayShort = String(m.away && m.away.shortName || "").trim().toLowerCase()
    // F1 races may carry driver/constructor ids on the match payload itself
    // (per-race participation), in addition to the home/away placeholders.
    var driverId = String(m.driverId || "").toLowerCase()
    var constructorId = String(m.constructorId || "").toLowerCase()

    var matchFound = false
    for (var j = 0; j < ids.length; j++) {
      var id = ids[j]
      // Provider ids are authoritative. Do not use substring matching for
      // numeric ids: team id "7" must not match a team named "76ers".
      if (homeId === id || awayId === id) {
        matchFound = true
        break
      }
      if (!isNumericIdentifier(id) && (homeName === id || awayName === id || homeShort === id || awayShort === id)) {
        matchFound = true
        break
      }
      // F1: a favorite is a driver or constructor id, which only lives on
      // race payloads (not on home/away placeholders). Without this branch
      // every followed driver would see zero races.
      if (s === "f1" && (driverId === id || constructorId === id)) {
        matchFound = true
        break
      }
    }
    if (matchFound) {
      seen[m.id] = true
      result.push(m)
    }
  }
  result.sort(compareMatchTimes)
  return result
}

function matchesForLeague(matches, leagueId) {
  var id = String(leagueId || "")
  if (!id) return Core.arrayFrom(matches)
  var result = []
  var source = Core.arrayFrom(matches)
  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (m && String(m.leagueId) === id) result.push(m)
  }
  result.sort(compareMatchTimes)
  return result
}

function featuredMatchForTeam(teamMatches) {
  var source = Core.arrayFrom(teamMatches)
  if (source.length === 0) return null

  // 1. Live match first
  for (var i = 0; i < source.length; i++) {
    if (source[i] && source[i].status === "live") return source[i]
  }

  // 2. Next upcoming match
  var now = Date.now()
  var bestUpcoming = null
  var bestUpcomingTime = Infinity
  for (var j = 0; j < source.length; j++) {
    var m = source[j]
    if (!m || m.status !== "upcoming") continue
    var t = Core.parseMatchTimeMs(m)
    if (isNaN(t) || t < now) continue
    if (t < bestUpcomingTime) {
      bestUpcomingTime = t
      bestUpcoming = m
    }
  }
  if (bestUpcoming) return bestUpcoming

  // 3. Most recent finished match
  var bestFinished = null
  var bestFinishedTime = -Infinity
  for (var k = 0; k < source.length; k++) {
    var fm = source[k]
    if (!fm || fm.status !== "finished") continue
    var ft = Core.parseMatchTimeMs(fm)
    if (isNaN(ft)) continue
    if (ft > bestFinishedTime) {
      bestFinishedTime = ft
      bestFinished = fm
    }
  }
  return bestFinished || source[0]
}

function teamIdForMatch(match, teamIds) {
  if (!match) return ""
  var ids = (typeof teamIds === "string" || typeof teamIds === "number") ? [teamIds] : Core.arrayFrom(teamIds)
  for (var i = 0; i < ids.length; i++) {
    var id = String(ids[i] || "").trim()
    var normalized = id.toLowerCase()
    if (id && (String(match.home && match.home.id || "").toLowerCase() === normalized
        || String(match.away && match.away.id || "").toLowerCase() === normalized)) return id
  }
  return ""
}

function teamOutcomeForTeams(match, teamIds) {
  return teamOutcome(match, teamIdForMatch(match, teamIds))
}

function isStandingsRowFavorite(row, teamIds, selectedTeamName) {
  if (!row) return false
  if (isFollowedTeam(row.id, teamIds) || isFollowedTeam(row.teamId, teamIds)) return true
  var name = String(selectedTeamName || "").trim().toLowerCase()
  if (!name) return false
  return String(row.name || "").trim().toLowerCase() === name
    || String(row.shortName || "").trim().toLowerCase() === name
}

function teamOutcome(match, teamId) {
  if (!match || match.status !== "finished") return ""
  var id = String(teamId || "").toLowerCase()
  var homeId = String(match.home && match.home.id || "").toLowerCase()
  var awayId = String(match.away && match.away.id || "").toLowerCase()
  var isHome = homeId === id
  var isAway = awayId === id
  if (!isHome && !isAway) return ""

  var hs = parseInt(match.homeScore, 10) || 0
  var as = parseInt(match.awayScore, 10) || 0
  if (hs === as) return "draw"
  if (isHome) return hs > as ? "win" : "loss"
  return as > hs ? "win" : "loss"
}

function matchOutcomeForTeams(match, teamIds) {
  return teamOutcomeForTeams(match, teamIds)
}

function teamLiveState(match, teamId) {
  if (!match || match.status !== "live") return ""
  var id = String(teamId || "").toLowerCase()
  var homeId = String(match.home && match.home.id || "").toLowerCase()
  var awayId = String(match.away && match.away.id || "").toLowerCase()
  var isHome = homeId === id
  var isAway = awayId === id
  if (!isHome && !isAway) return ""

  var hs = parseInt(match.homeScore, 10) || 0
  var as = parseInt(match.awayScore, 10) || 0
  if (hs === as) return "tied"
  if (isHome) return hs > as ? "leading" : "trailing"
  return as > hs ? "leading" : "trailing"
}

function teamLiveStateForTeams(match, teamIds) {
  return teamLiveState(match, teamIdForMatch(match, teamIds))
}

function matchLiveStateForTeams(match, teamIds) {
  return teamLiveStateForTeams(match, teamIds)
}

function generalMatchOutcome(match) {
  if (!match || match.status !== "finished") return ""
  var hs = parseInt(match.homeScore, 10) || 0
  var as = parseInt(match.awayScore, 10) || 0
  if (hs === as) return "draw"
  return hs > as ? "home" : "away"
}

function groupMatches(matches) {
  var source = Core.arrayFrom(matches)
  if (source.length === 0) return []

  var live = []
  var upcoming = []
  var recent = []

  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (!m) continue
    if (m.status === "live") live.push(m)
    else if (m.status === "upcoming") upcoming.push(m)
    else recent.push(m)
  }

  live.sort(compareMatchTimes)
  upcoming.sort(compareMatchTimes)
  recent.sort(function(a, b) {
    var aTime = Core.parseMatchTimeMs(a)
    var bTime = Core.parseMatchTimeMs(b)
    if (isNaN(aTime) && isNaN(bTime)) return 0
    if (isNaN(aTime)) return 1
    if (isNaN(bTime)) return -1
    return bTime - aTime
  })

  var groups = []
  if (live.length > 0) {
    groups.push({ key: "live", label: "Live Matches", matches: live })
  }
  if (upcoming.length > 0) {
    groups.push({ key: "upcoming", label: "Upcoming Fixtures", matches: upcoming })
  }
  if (recent.length > 0) {
    groups.push({ key: "recent", label: "Recent Results", matches: recent.slice(0, 10) })
  }
  return groups
}

function formatMatchDate(timeStr) {
  var t = Core.parseMatchTimeMs({ time: timeStr })
  if (isNaN(t)) return "TBD"
  var d = new Date(t)
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()]
}

function matchStatusText(match) {
  if (!match) return ""
  if (match.status === "live") return match.liveTime || "LIVE"
  if (match.status === "finished") return "FT"
  if (match.status === "cancelled") return match.statusReason || "Cancelled"
  return formatMatchDate(match.time)
}

function resetLiveClockCache() {
  _liveClockCache = {}
}

function cleanLiveTime(str) {
  if (!str) return ""
  return String(str).replace(/[\u200e\u200f]/g, "").trim()
}

function interpolateLiveTime(match, nowMs, fetchedAtMs) {
  if (!match || match.status !== "live") {
    if (match && match.id && _liveClockCache[String(match.id)]) {
      delete _liveClockCache[String(match.id)]
    }
    return match ? String(match.liveTime || "") : ""
  }
  if (match.sport && match.sport !== "football") return String(match.liveTime || "")
  var lt = String(match.liveTime || "")
  var now = Number(nowMs) || Date.now()
  var matchId = match.id ? String(match.id) : ""

  // If liveTime is missing or generic "LIVE", check kickoff elapsed time as fallback
  if (!lt || lt === "LIVE") {
    if (match.time) {
      var kickoffMs0 = Core.parseMatchTimeMs(match)
      if (!isNaN(kickoffMs0) && now > kickoffMs0) {
        var elapsed0 = Math.floor((now - kickoffMs0) / 60000)
        if (elapsed0 >= 1 && elapsed0 < 45) return "\u200e" + Math.max(1, elapsed0) + "\u2019\u200e"
        if (elapsed0 >= 45 && elapsed0 < 62) return "HT"
        if (elapsed0 >= 62 && elapsed0 < 115) return "\u200e" + Math.min(90, elapsed0 - 15) + "\u2019\u200e"
        if (elapsed0 >= 115) return "\u200e90+’\u200e"
      }
    }
    return lt || "LIVE"
  }

  // Only tick a bare minute like "13" / "13’" — never "8:44", "45+2’", "HT"…
  // (strip invisible LRM/RLM bi-di control chars FotMob wraps its clocks in)
  var cleaned = lt.replace(/[\u200e\u200f\s]/g, "")
  if (cleaned.toUpperCase() === "HT") {
    if (matchId && _liveClockCache[matchId]) delete _liveClockCache[matchId]
    return "HT"
  }

  var m = cleaned.match(/^(\d{1,3})[\u2019\u2032']?$/)
  if (!m) return lt
  var base = parseInt(m[1], 10)
  if (base < 0 || base > 130) return lt

  var baseModified = false
  // Kickoff wall-clock sanity guard:
  // If the match kicked off >= 15 minutes ago, but the reported clock is <= 5'
  // (a known FotMob SSR cache artifact where team pages serve frozen 1' data),
  // derive the realistic base minute from elapsed time since kickoff.
  if (match.time) {
    var kickoffMs = Core.parseMatchTimeMs(match)
    if (!isNaN(kickoffMs) && now > kickoffMs) {
      var elapsed = Math.floor((now - kickoffMs) / 60000)
      if (elapsed >= 15 && base <= 5) {
        if (elapsed < 45) {
          base = Math.max(1, elapsed)
          baseModified = true
        } else if (elapsed < 62) {
          if (matchId && _liveClockCache[matchId]) delete _liveClockCache[matchId]
          return "HT"
        } else if (elapsed < 115) {
          base = Math.min(90, elapsed - 15)
          baseModified = true
        } else {
          return "\u200e90+’\u200e"
        }
      }
    }
  }

  // Monotonic tracking for identified matches across polling cycles:
  if (matchId) {
    var fetchMs = Number(fetchedAtMs) || now
    var entry = _liveClockCache[matchId]
    if (!entry || base > entry.maxBase || baseModified) {
      entry = {
        maxBase: base,
        anchorMs: fetchMs,
        highestMinute: base,
        updatedAt: now
      }
      _liveClockCache[matchId] = entry
    } else {
      entry.updatedAt = now
    }

    var ageSinceAnchor = (now - entry.anchorMs) / 60000
    var rawDrift = (isFinite(ageSinceAnchor) && ageSinceAnchor > 0) ? Math.floor(ageSinceAnchor) : 0
    var effectiveDrift = Math.min(rawDrift, 8)
    var currentMin = Math.max(entry.highestMinute, entry.maxBase + effectiveDrift)

    if (entry.maxBase <= 45 && currentMin > 45) currentMin = 45
    if (entry.maxBase <= 90 && currentMin > 90) currentMin = 90
    entry.highestMinute = currentMin

    if (currentMin === base && !baseModified && effectiveDrift === 0) {
      return lt
    }
    return "\u200e" + String(currentMin) + "\u2019\u200e"
  }

  // Unidentified matches (e.g. ad-hoc unit test objects without id):
  var age = (now - Number(fetchedAtMs)) / 60000
  var drift = (isFinite(age) && age > 0) ? Math.floor(age) : 0
  if (drift <= 0 && !baseModified) return lt
  var effective = Math.min(drift, 8)
  var current = base + effective
  if (base <= 45 && current > 45) {
    return "\u200e45\u2019\u200e"
  }
  if (base <= 90 && current > 90) {
    return "\u200e90\u2019\u200e"
  }
  return "\u200e" + String(current) + "\u2019\u200e"
}

function formatLiveClock(match, nowMs, fetchedAtMs) {
  if (!match) return { minuteText: "", phase: "", statusText: "", kickoffText: "", fullLabel: "" }
  var rawLiveTime = interpolateLiveTime(match, nowMs, fetchedAtMs)
  var cleanTime = cleanLiveTime(rawLiveTime)
  var ko = match.time ? Core.formatKickoff(match.time) : ""
  var kickoffText = ko ? ("Started " + ko) : ""

  if (match.status !== "live") {
    return {
      minuteText: cleanTime,
      phase: match.status === "finished" ? "FT" : (ko ? ("Starts " + ko) : "Upcoming"),
      statusText: cleanTime || match.statusReason || "",
      kickoffText: kickoffText,
      fullLabel: cleanTime
    }
  }

  var phase = ""
  var sport = match.sport || "football"

  if (sport === "football") {
    var upper = cleanTime.toUpperCase()
    if (upper === "HT" || upper.indexOf("HALF") !== -1) {
      phase = "Half Time"
      cleanTime = "HT"
    } else if (upper.indexOf("PEN") !== -1) {
      phase = "Penalties"
    } else if (upper.indexOf("ET") !== -1 || upper.indexOf("AET") !== -1) {
      phase = "Extra Time"
    } else {
      var minMatch = cleanTime.match(/^(\d{1,3})(?:\+(\d{1,2}))?/)
      if (minMatch) {
        var baseM = parseInt(minMatch[1], 10)
        var addedM = minMatch[2] ? parseInt(minMatch[2], 10) : 0
        if (baseM < 45) {
          phase = "1st Half"
        } else if (baseM === 45 && addedM > 0) {
          phase = "1st Half Stoppage"
        } else if (baseM === 45) {
          phase = "1st Half"
        } else if (baseM < 90) {
          phase = "2nd Half"
        } else if (baseM === 90 && addedM > 0) {
          phase = "Stoppage Time"
        } else if (baseM >= 90) {
          phase = "Stoppage Time"
        }
      } else {
        phase = "Live"
      }
    }
  } else if (sport === "nba" || sport === "nfl") {
    if (cleanTime.toLowerCase().indexOf("half") !== -1) phase = "Halftime"
    else if (cleanTime.indexOf("Q1") !== -1 || cleanTime.indexOf("1st") !== -1) phase = "1st Quarter"
    else if (cleanTime.indexOf("Q2") !== -1 || cleanTime.indexOf("2nd") !== -1) phase = "2nd Quarter"
    else if (cleanTime.indexOf("Q3") !== -1 || cleanTime.indexOf("3rd") !== -1) phase = "3rd Quarter"
    else if (cleanTime.indexOf("Q4") !== -1 || cleanTime.indexOf("4th") !== -1) phase = "4th Quarter"
    else if (cleanTime.indexOf("OT") !== -1) phase = "Overtime"
    else phase = "Live"
  } else if (sport === "nhl") {
    if (cleanTime.indexOf("1st") !== -1) phase = "1st Period"
    else if (cleanTime.indexOf("2nd") !== -1) phase = "2nd Period"
    else if (cleanTime.indexOf("3rd") !== -1) phase = "3rd Period"
    else if (cleanTime.indexOf("OT") !== -1) phase = "Overtime"
    else phase = "Live"
  } else if (sport === "mlb") {
    phase = cleanTime
  } else if (sport === "f1") {
    phase = "Grand Prix"
  } else {
    phase = "Live"
  }

  var fullLabel = phase && cleanTime && phase !== cleanTime
    ? (phase + " · " + cleanTime)
    : (cleanTime || "LIVE")

  return {
    minuteText: cleanTime || "LIVE",
    phase: phase,
    statusText: fullLabel,
    kickoffText: kickoffText,
    fullLabel: fullLabel
  }
}

function leagueLabel(id) {
  var s = String(id || "")
  if (s === "nba") return "NBA"
  if (s === "f1") return "Formula 1"
  if (s === "nfl") return "NFL"
  if (s === "mlb") return "MLB"
  if (s === "nhl") return "NHL"
  for (var i = 0; i < Core.supportedLeagues.length; i++) {
    if (Core.supportedLeagues[i].value === s) return Core.supportedLeagues[i].label
  }
  return "League " + s
}

function sportMeta(sport) {
  var s = String(sport || "football").toLowerCase()
  for (var i = 0; i < Core.supportedSports.length; i++) {
    if (Core.supportedSports[i].value === s) return Core.supportedSports[i]
  }
  return Core.supportedSports[0]
}

function shortTournamentName(name) {
  var s = String(name || "").trim()
  if (!s) return ""
  // ESPN league display names are long; the date column only fits siglas
  if (s.indexOf("National Basketball Association") !== -1) return "NBA"
  if (s.indexOf("National Football League") !== -1 && s.indexOf("Conference") === -1) return "NFL"
  if (s.indexOf("Major League Baseball") !== -1) return "MLB"
  if (s.indexOf("National Hockey League") !== -1) return "NHL"
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

function reconcileMatchDetails(matches, detailsMap) {
  var result = Core.arrayFrom(matches).slice()
  var map = detailsMap || {}
  var now = Date.now()
  for (var i = 0; i < result.length; i++) {
    var m = result[i]
    if (!m || !m.id) continue
    var d = map[String(m.id)]
    var updated = false
    var mObj = null

    // 1. Check detailsMap for FT / Full-Time / Extra Time / Penalties
    var isFT = d && (d.finished === true || d.reason === "FT" || d.reason === "AET" || d.reason === "PEN" || (d.statusLong && /full|extra|penalt|finish|ended/i.test(d.statusLong)))
    if (isFT && m.status === "live") {
      if (!mObj) mObj = Object.assign({}, m)
      mObj.status = "finished"
      mObj.statusReason = d.reason || m.statusReason || "FT"
      mObj.liveTime = ""
      updated = true
    }

    // 2. Wall-clock expiry guard for football:
    // A football match cannot remain live > 165 minutes after kickoff
    if (m.status === "live" && (!m.sport || m.sport === "football") && m.time) {
      var koMs = Date.parse(m.time)
      if (!isNaN(koMs) && (now - koMs) > 165 * 60 * 1000) {
        if (!mObj) mObj = Object.assign({}, m)
        mObj.status = "finished"
        mObj.statusReason = m.statusReason || "FT"
        mObj.liveTime = ""
        updated = true
      }
    }

    // 3. Update liveScore / liveTime from details if match is live
    if (d && (!mObj ? m.status : mObj.status) === "live") {
      if (d.liveScore && d.liveScore !== m.scoreText) {
        if (!mObj) mObj = Object.assign({}, m)
        mObj.scoreText = d.liveScore
        updated = true
      }
      if (d.liveTime && d.liveTime !== m.liveTime) {
        if (!mObj) mObj = Object.assign({}, m)
        mObj.liveTime = d.liveTime
        updated = true
      }
    }

    if (updated && mObj) {
      result[i] = mObj
    }
  }
  return result
}

function liveMatches(matches, detailsMap, nowMs) {
  var result = []
  var source = Core.arrayFrom(matches)
  var map = detailsMap || {}
  var now = typeof nowMs === "number" && isFinite(nowMs) ? nowMs : Date.now()
  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (!m || m.status !== "live") continue
    var d = map[String(m.id)]
    if (d && (d.finished === true || d.reason === "FT" || d.reason === "AET" || d.reason === "PEN" || d.statusLong === "Full-Time" || (d.statusLong && /full|extra|penalt|finish|ended/i.test(d.statusLong)))) continue
    if ((!m.sport || m.sport === "football") && m.time) {
      var koMs = Date.parse(m.time)
      if (!isNaN(koMs) && (now - koMs) > 165 * 60 * 1000) continue
    }
    result.push(m)
  }
  result.sort(compareMatchTimes)
  return result
}

function matchLine(match) {
  if (!match) return ""
  var home = (match.home && (match.home.shortName || match.home.name)) || ""
  var away = (match.away && (match.away.shortName || match.away.name)) || ""
  var line = home + " " + (match.scoreText || "–") + " " + away
  if (match.liveTime) line += " · " + match.liveTime
  return line
}

function leagues() { return Core.supportedLeagues }

function sports() { return Core.supportedSports }

function buildPersistedState(cur, saved, ui) {
  var sportSettings = {}
  var sportsList = ["nba", "f1", "nfl", "mlb", "nhl"]
  for (var s = 0; s < sportsList.length; s++) {
    var spk = sportsList[s]
    var prevSp = saved[spk] || {}
    if (cur === spk) {
      var curIds = Core.arrayFrom(ui.selectedTeamIds)
      sportSettings[spk] = {
        teamIds: curIds,
        // Panel does not pass selectedTeamId; derive it so JSON.stringify
        // (and therefore ignoredStateSignature) matches Core.parseState's output.
        teamId: String(ui.selectedTeamId || (curIds.length > 0 ? curIds[0] : "")),
        teamName: ui.selectedTeamName,
        standingsGroup: ui.standingsLeagueId,
        tab: ui.tabName
      }
    } else {
      sportSettings[spk] = prevSp
    }
  }

  var fb = saved.football || {}
  var fbLeagueIds = cur === "football"
    ? (ui.selectedLeagueIds || fb.leagueIds)
    : (fb.leagueIds || ui.selectedLeagueIds)
  var fbTeamIds = cur === "football" ? ui.selectedTeamIds : (fb.teamIds || (fb.teamId ? [fb.teamId] : []))
  var payload = Core.statePayload(
    cur,
    fbLeagueIds,
    fbTeamIds,
    cur === "football" ? ui.selectedTeamName : fb.teamName,
    saved.refreshMinutes,
    cur === "football" ? ui.standingsLeagueId : fb.standingsLeagueId,
    sportSettings,
    ui.antiSpoiler,
    ui.enableNotifications,
    ui.backgroundUpdates !== undefined ? ui.backgroundUpdates : (saved.backgroundUpdates !== false),
    ui.showBarTicker !== undefined ? ui.showBarTicker : (saved.showBarTicker !== false),
    ui.showSpotlight !== undefined ? ui.showSpotlight : (saved.showSpotlight !== false)
  )
  // Keep Core.statePayload's positional API stable; add the active football tab at
  // the persistence boundary where the UI-specific field belongs.
  payload.football.tab = cur === "football" ? Core.normalizeTab(ui.tabName) : Core.normalizeTab(fb.tab)
  return payload
}

function sameTeamData(a, b) {
  if (!a || !b) return a === b
  return String(a.id || "") === String(b.id || "")
    && String(a.name || "") === String(b.name || "")
    && String(a.shortName || "") === String(b.shortName || "")
    && String(a.abbr || "") === String(b.abbr || "")
    && String(a.record || "") === String(b.record || "")
    && String(a.logo || "") === String(b.logo || "")
}

function sameSessions(a, b) {
  var first = Core.arrayFrom(a)
  var second = Core.arrayFrom(b)
  if (first.length !== second.length) return false
  for (var i = 0; i < first.length; i++) {
    if (!first[i] || !second[i]) return false
    if (String(first[i].name || "") !== String(second[i].name || "")
        || String(first[i].shortName || "") !== String(second[i].shortName || "")
        || String(first[i].time || "") !== String(second[i].time || "")) return false
  }
  return true
}

function sameMatches(a, b) {
  if (a === b) return true
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false
  // Linescores (NBA/NFL quarters, NHL periods, MLB innings) are intentionally
  // excluded from the fingerprint. Total score already drives the visible delta
  // and including period-level updates would force a Repeater teardown for
  // every poll — which is how the live tab flickers every 3-4 seconds.
  // Add `linescores` here only if you also fix the Repeater churn.
  for (var i = 0; i < a.length; i++) {
    var x = a[i]
    var y = b[i]
    if (!x || !y) return false
    if (String(x.id) !== String(y.id)
        || String(x.status || "") !== String(y.status || "")
        || Number(x.homeScore || 0) !== Number(y.homeScore || 0)
        || Number(x.awayScore || 0) !== Number(y.awayScore || 0)
        || String(x.statusReason || "") !== String(y.statusReason || "")
        || String(x.scoreText || "") !== String(y.scoreText || "")
        || String(x.liveTime || "") !== String(y.liveTime || "")
        || String(x.time || "") !== String(y.time || "")
        || String(x.leagueId || "") !== String(y.leagueId || "")
        || String(x.leagueName || "") !== String(y.leagueName || "")
        || String(x.round || "") !== String(y.round || "")
        || String(x.venue || "") !== String(y.venue || "")
        || String(x.pageUrl || "") !== String(y.pageUrl || "")
        || String(x.raceName || "") !== String(y.raceName || "")
        || String(x.circuitName || "") !== String(y.circuitName || "")
        || String(x.countryFlag || "") !== String(y.countryFlag || "")
        || !sameTeamData(x.home, y.home)
        || !sameTeamData(x.away, y.away)
        || !sameSessions(x.sessions, y.sessions)) return false
  }
  return true
}

function sameRows(a, b) {
  if (a === b) return true
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false
  for (var i = 0; i < a.length; i++) {
    var x = a[i]
    var y = b[i]
    if (!x || !y) return false
    if (String(x.pos || "") !== String(y.pos || "")
        || String(x.id || "") !== String(y.id || "")
        || String(x.name || "") !== String(y.name || "")
        || String(x.shortName || "") !== String(y.shortName || "")
        || String(x.abbr || "") !== String(y.abbr || "")
        || String(x.logo || "") !== String(y.logo || "")
        || String(x.flag || "") !== String(y.flag || "")
        || String(x.teamId || "") !== String(y.teamId || "")
        || String(x.teamName || "") !== String(y.teamName || "")
        || String(x.pts || "") !== String(y.pts || "")
        || String(x.gd || "") !== String(y.gd || "")
        || String(x.pct || "") !== String(y.pct || "")
        || String(x.gb || "") !== String(y.gb || "")
        || Number(x.played || 0) !== Number(y.played || 0)
        || Number(x.wins || 0) !== Number(y.wins || 0)
        || Number(x.draws || 0) !== Number(y.draws || 0)
        || Number(x.losses || 0) !== Number(y.losses || 0)
        || String(x.zone || "") !== String(y.zone || "")) return false
  }
  return true
}

function sameGroups(a, b) {
  if (a === b) return true
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false
  for (var i = 0; i < a.length; i++) {
    var x = a[i]
    var y = b[i]
    if (!x || !y) return false
    if ((x.key || "") !== (y.key || "") || (x.label || "") !== (y.label || "")) return false
    if (!sameMatches(x.matches || [], y.matches || [])) return false
  }
  return true
}
