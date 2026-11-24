.pragma library
.import "../core.js" as Core

// Jolpica Formula 1 parsing (calendar, standings, results, podium, pole).

function f1CountryFlag(countryName, raceName) {
  var c = String(countryName || "").toLowerCase()
  var r = String(raceName || "").toLowerCase()

  if (c.indexOf("australia") !== -1 || r.indexOf("australian") !== -1) return "🇦🇺"
  if (c.indexOf("portugal") !== -1 || r.indexOf("portuguese") !== -1 || r.indexOf("portim") !== -1) return "🇵🇹"
  if (c.indexOf("china") !== -1 || r.indexOf("chinese") !== -1 || r.indexOf("shanghai") !== -1) return "🇨🇳"
  if (c.indexOf("japan") !== -1 || r.indexOf("japanese") !== -1 || r.indexOf("suzuka") !== -1) return "🇯🇵"
  if (c.indexOf("bahrain") !== -1 || r.indexOf("sakhir") !== -1) return "🇧🇭"
  if (c.indexOf("saudi") !== -1 || r.indexOf("jeddah") !== -1) return "🇸🇦"
  if (r.indexOf("miami") !== -1 || r.indexOf("las vegas") !== -1 || r.indexOf("united states") !== -1 || c.indexOf("united states") !== -1 || c.indexOf("usa") !== -1 || r.indexOf("austin") !== -1) return "🇺🇸"
  if (c.indexOf("italy") !== -1 || r.indexOf("emilia") !== -1 || r.indexOf("imola") !== -1 || r.indexOf("monza") !== -1 || r.indexOf("italian") !== -1) return "🇮🇹"
  if (c.indexOf("monaco") !== -1 || r.indexOf("monte carlo") !== -1) return "🇲🇨"
  if (c.indexOf("spain") !== -1 || r.indexOf("spanish") !== -1 || r.indexOf("catalunya") !== -1 || r.indexOf("madrid") !== -1) return "🇪🇸"
  if (c.indexOf("canada") !== -1 || r.indexOf("canadian") !== -1 || r.indexOf("montreal") !== -1) return "🇨🇦"
  if (c.indexOf("austria") !== -1 || r.indexOf("austrian") !== -1 || r.indexOf("spielberg") !== -1 || r.indexOf("red bull ring") !== -1) return "🇦🇹"
  if (c.indexOf("uk") !== -1 || c.indexOf("great britain") !== -1 || r.indexOf("british") !== -1 || r.indexOf("silverstone") !== -1) return "🇬🇧"
  if (c.indexOf("belgium") !== -1 || r.indexOf("belgian") !== -1 || r.indexOf("spa") !== -1) return "🇧🇪"
  if (c.indexOf("hungary") !== -1 || r.indexOf("hungarian") !== -1 || r.indexOf("hungaroring") !== -1) return "🇭🇺"
  if (c.indexOf("netherlands") !== -1 || r.indexOf("dutch") !== -1 || r.indexOf("zandvoort") !== -1) return "🇳🇱"
  if (c.indexOf("azerbaijan") !== -1 || r.indexOf("baku") !== -1) return "🇦🇿"
  if (c.indexOf("singapore") !== -1 || r.indexOf("marina bay") !== -1) return "🇸🇬"
  if (c.indexOf("mexico") !== -1 || r.indexOf("rodriguez") !== -1) return "🇲🇽"
  if (c.indexOf("brazil") !== -1 || r.indexOf("são paulo") !== -1 || r.indexOf("interlagos") !== -1) return "🇧🇷"
  if (c.indexOf("qatar") !== -1 || r.indexOf("lusail") !== -1) return "🇶🇦"
  if (c.indexOf("abu dhabi") !== -1 || c.indexOf("uae") !== -1 || c.indexOf("emirates") !== -1 || r.indexOf("yas marina") !== -1) return "🇦🇪"
  return "🏁"
}

function f1DriverFlag(driverIdOrNat) {
  var d = String(driverIdOrNat || "").toLowerCase()
  if (d.indexOf("british") !== -1 || d.indexOf("hamilton") !== -1 || d.indexOf("norris") !== -1 || d.indexOf("russell") !== -1 || d.indexOf("bearman") !== -1 || d.indexOf("lindblad") !== -1) return "🇬🇧"
  if (d.indexOf("verstappen") !== -1 || d.indexOf("dutch") !== -1) return "🇳🇱"
  if (d.indexOf("leclerc") !== -1 || d.indexOf("monegasque") !== -1) return "🇲🇨"
  if (d.indexOf("piastri") !== -1 || d.indexOf("australian") !== -1) return "🇦🇺"
  if (d.indexOf("alonso") !== -1 || d.indexOf("sainz") !== -1 || d.indexOf("spanish") !== -1) return "🇪🇸"
  if (d.indexOf("antonelli") !== -1 || d.indexOf("italian") !== -1) return "🇮🇹"
  if (d.indexOf("gasly") !== -1 || d.indexOf("ocon") !== -1 || d.indexOf("hadjar") !== -1 || d.indexOf("french") !== -1) return "🇫🇷"
  if (d.indexOf("hulkenberg") !== -1 || d.indexOf("german") !== -1) return "🇩🇪"
  if (d.indexOf("tsunoda") !== -1 || d.indexOf("japanese") !== -1) return "🇯🇵"
  if (d.indexOf("albon") !== -1 || d.indexOf("thai") !== -1) return "🇹🇭"
  if (d.indexOf("stroll") !== -1 || d.indexOf("canadian") !== -1) return "🇨🇦"
  if (d.indexOf("bortoleto") !== -1 || d.indexOf("brazilian") !== -1) return "🇧🇷"
  if (d.indexOf("lawson") !== -1 || d.indexOf("zealand") !== -1) return "🇳🇿"
  if (d.indexOf("colapinto") !== -1 || d.indexOf("argentin") !== -1) return "🇦🇷"
  if (d.indexOf("bottas") !== -1 || d.indexOf("finnish") !== -1) return "🇫🇮"
  if (d.indexOf("perez") !== -1 || d.indexOf("pérez") !== -1 || d.indexOf("mexican") !== -1) return "🇲🇽"
  return "🏎"
}

function parseF1SeasonWinners(raw) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return {} }
  if (!json || typeof json !== "object") return {}
  var races = (json.MRData && json.MRData.RaceTable && json.MRData.RaceTable.Races)
    ? Core.arrayFrom(json.MRData.RaceTable.Races)
    : []
  var map = {}
  for (var i = 0; i < races.length; i++) {
    var r = races[i]
    if (!r || !r.round) continue
    var results = r.Results ? Core.arrayFrom(r.Results) : []
    if (results.length === 0) continue
    var res = results[0]
    if (!res) continue
    var driver = res.Driver || {}
    var constructor = res.Constructor || {}
    var timeObj = res.Time || {}
    var fastestLap = res.FastestLap || {}
    map[String(r.round)] = {
      round: String(r.round),
      driverId: String(driver.driverId || ""),
      driverName: String((driver.givenName || "") + " " + (driver.familyName || "")).trim(),
      familyName: String(driver.familyName || ""),
      code: String(driver.code || driver.familyName || ""),
      nationality: String(driver.nationality || ""),
      constructorId: String(constructor.constructorId || ""),
      constructorName: String(constructor.name || ""),
      time: String(timeObj.time || ""),
      laps: String(res.laps || ""),
      grid: String(res.grid || ""),
      points: String(res.points || "25"),
      fastestLap: fastestLap.Time ? String(fastestLap.Time.time || "") : ""
    }
  }
  return map
}

function parseF1Calendar(raw, nowMs, winnersMap) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var races = (json.MRData && json.MRData.RaceTable && json.MRData.RaceTable.Races) ? Core.arrayFrom(json.MRData.RaceTable.Races) : []
  var now = Number(nowMs) || Date.now()
  var matches = []

  for (var i = 0; i < races.length; i++) {
    var r = races[i]
    if (!r) continue
    var raceIso = r.date + "T" + (r.time || "14:00:00Z")
    var raceMs = Date.parse(raceIso)
    var status = "upcoming"
    if (!isNaN(raceMs)) {
      if (now > raceMs + 3 * 3600 * 1000) status = "finished"
      else if (now >= raceMs) status = "live"
    }

    var roundKey = String(r.round || "")
    var winner = (winnersMap && typeof winnersMap === "object" && winnersMap[roundKey]) ? winnersMap[roundKey] : null
    if (winner) status = "finished"

    var raceName = String(r.raceName || "Grand Prix")
    var circuitName = (r.Circuit && r.Circuit.circuitName) || "Circuit"
    var locality = (r.Circuit && r.Circuit.Location && r.Circuit.Location.locality) || ""
    var country = (r.Circuit && r.Circuit.Location && r.Circuit.Location.country) || ""
    var flag = f1CountryFlag(country, raceName)

    var sessions = []
    if (r.FirstPractice) {
      sessions.push({
        name: "Practice 1",
        shortName: "FP1",
        time: r.FirstPractice.date + "T" + (r.FirstPractice.time || "10:00:00Z")
      })
    }
    if (r.SprintQualifying || r.SprintShootout) {
      var sq = r.SprintQualifying || r.SprintShootout
      sessions.push({
        name: "Sprint Qualifying",
        shortName: "SQ",
        time: sq.date + "T" + (sq.time || "14:00:00Z")
      })
    } else if (r.SecondPractice) {
      sessions.push({
        name: "Practice 2",
        shortName: "FP2",
        time: r.SecondPractice.date + "T" + (r.SecondPractice.time || "14:00:00Z")
      })
    }
    if (r.Sprint) {
      sessions.push({
        name: "Sprint Race",
        shortName: "Sprint",
        time: r.Sprint.date + "T" + (r.Sprint.time || "10:00:00Z")
      })
    } else if (r.ThirdPractice) {
      sessions.push({
        name: "Practice 3",
        shortName: "FP3",
        time: r.ThirdPractice.date + "T" + (r.ThirdPractice.time || "10:00:00Z")
      })
    }
    if (r.Qualifying) {
      sessions.push({
        name: "Qualifying",
        shortName: "Quali",
        time: r.Qualifying.date + "T" + (r.Qualifying.time || "14:00:00Z")
      })
    }
    sessions.push({
      name: "Grand Prix (Race)",
      shortName: "Race",
      time: raceIso
    })

    var matchObj = {
      id: "f1-2026-" + r.round,
      sport: "f1",
      leagueId: "f1",
      leagueName: "Formula 1",
      round: "Round " + r.round,
      raceName: raceName,
      circuitName: circuitName,
      locality: locality,
      country: country,
      countryFlag: flag,
      sessions: sessions,
      home: {
        id: "f1-gp-" + r.round,
        name: raceName,
        shortName: raceName.replace(" Grand Prix", " GP"),
        record: locality ? (locality + ", " + country) : country,
        logo: ""
      },
      away: {
        id: "f1-circuit-" + r.round,
        name: circuitName,
        shortName: country || circuitName,
        record: "",
        logo: ""
      },
      status: status,
      homeScore: 0,
      awayScore: 0,
      scoreText: winner
        ? ("🏆 " + (winner.code || winner.familyName))
        : (status === "finished" ? "Official" : (status === "live" ? "RACE DAY" : "Round " + r.round)),
      statusReason: status === "finished"
        ? (winner ? ("Winner: " + winner.driverName) : "Official")
        : (status === "live" ? "LIVE" : "Scheduled"),
      liveTime: status === "live" ? "RACE" : "",
      time: raceIso,
      pageUrl: r.url || "https://www.formula1.com"
    }
    if (winner) matchObj.winner = winner
    matches.push(matchObj)
  }
  return matches
}

function parseF1DriverStandings(raw) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var list = (json.MRData && json.MRData.StandingsTable && json.MRData.StandingsTable.StandingsLists && json.MRData.StandingsTable.StandingsLists[0] && json.MRData.StandingsTable.StandingsLists[0].DriverStandings) ? Core.arrayFrom(json.MRData.StandingsTable.StandingsLists[0].DriverStandings) : []
  var rows = []

  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    if (!d) continue
    var driver = d.Driver || {}
    var constructor = (d.Constructors && d.Constructors[0]) || {}
    var pos = parseInt(d.position, 10) || (i + 1)
    var conId = String(constructor.constructorId || constructor.name || "").toLowerCase()
    var driverFlag = f1DriverFlag(driver.driverId || driver.nationality)

    rows.push({
      pos: String(pos),
      id: String(driver.driverId || ""),
      name: (driver.givenName || "") + " " + (driver.familyName || ""),
      shortName: String(driver.code || driver.familyName || "Driver"),
      abbr: String(driver.code || driver.familyName || "DRV").slice(0, 3).toUpperCase(),
      flag: driverFlag,
      teamId: conId,
      teamName: String(constructor.name || ""),
      played: parseInt(d.wins, 10) || 0,
      wins: parseInt(d.wins, 10) || 0,
      draws: 0,
      losses: 0,
      gd: String(constructor.name || ""),
      pts: String(d.points || "0") + " PTS",
      zone: pos === 1 ? "europe" : (pos <= 3 ? "playin" : "")
    })
  }
  return rows
}

function parseF1ConstructorStandings(raw) {
  var json = null
  try { json = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var list = (json.MRData && json.MRData.StandingsTable && json.MRData.StandingsTable.StandingsLists && json.MRData.StandingsTable.StandingsLists[0] && json.MRData.StandingsTable.StandingsLists[0].ConstructorStandings) ? Core.arrayFrom(json.MRData.StandingsTable.StandingsLists[0].ConstructorStandings) : []
  var rows = []

  for (var i = 0; i < list.length; i++) {
    var c = list[i]
    if (!c) continue
    var constructor = c.Constructor || {}
    var pos = parseInt(c.position, 10) || (i + 1)
    var conId = String(constructor.constructorId || constructor.name || "").toLowerCase()

    rows.push({
      pos: String(pos),
      id: conId,
      name: String(constructor.name || "Constructor"),
      shortName: String(constructor.name || "Constructor"),
      abbr: String(constructor.name || "CON").slice(0, 2).toUpperCase(),
      teamId: conId,
      teamName: String(constructor.name || ""),
      played: parseInt(c.wins, 10) || 0,
      wins: parseInt(c.wins, 10) || 0,
      draws: 0,
      losses: 0,
      gd: String(constructor.nationality || ""),
      pts: String(c.points || "0") + " PTS",
      zone: pos === 1 ? "europe" : (pos <= 3 ? "playin" : "")
    })
  }
  return rows
}

function nextF1Session(match, nowMs) {
  if (!match || !match.sessions) return null
  var sessions = Core.arrayFrom(match.sessions)
  if (sessions.length === 0) return null
  var now = Number(nowMs) || Date.now()
  for (var i = 0; i < sessions.length; i++) {
    var s = sessions[i]
    if (!s || !s.time) continue
    var sMs = Date.parse(s.time)
    if (isNaN(sMs)) continue
    // If within 2.5 hours of session start, it's live / in-progress
    if (now >= sMs && now <= sMs + 2.5 * 3600 * 1000) {
      return {
        name: s.name,
        shortName: s.shortName,
        time: s.time,
        timeMs: sMs,
        isLive: true,
        formattedTime: Core.formatKickoff(s.time)
      }
    }
    if (sMs > now) {
      return {
        name: s.name,
        shortName: s.shortName,
        time: s.time,
        timeMs: sMs,
        isLive: false,
        formattedTime: Core.formatKickoff(s.time)
      }
    }
  }
  return null
}

function parseF1Podium(raw) {
  var json = null
  try { json = typeof raw === "string" ? JSON.parse(raw) : raw } catch (e) { return [] }
  if (!json || typeof json !== "object") return []
  var races = (json.MRData && json.MRData.RaceTable && Array.isArray(json.MRData.RaceTable.Races)) ? json.MRData.RaceTable.Races : []
  if (races.length === 0) return []
  var race = races[0]
  var results = Core.arrayFrom(race.Results)
  var podium = []
  for (var i = 0; i < Math.min(results.length, 3); i++) {
    var res = results[i]
    if (!res) continue
    var driver = res.Driver || {}
    var constructor = res.Constructor || {}
    var time = (res.Time && res.Time.time) || (res.status) || ""
    var pts = String(res.points || "0")
    podium.push({
      pos: i + 1,
      driverName: String(driver.givenName ? (driver.givenName + " " + driver.familyName) : (driver.familyName || "Driver")),
      code: String(driver.code || driver.familyName || "DRV"),
      constructorName: String(constructor.name || "Constructor"),
      time: String(time),
      points: pts
    })
  }
  return podium
}

function parseF1Pole(raw) {
  var json = null
  try { json = typeof raw === "string" ? JSON.parse(raw) : raw } catch (e) { return null }
  if (!json || typeof json !== "object") return null
  var races = (json.MRData && json.MRData.RaceTable && Array.isArray(json.MRData.RaceTable.Races)) ? json.MRData.RaceTable.Races : []
  if (races.length === 0) return null
  var race = races[0]
  var qualiResults = Core.arrayFrom(race.QualifyingResults)
  if (qualiResults.length === 0) return null
  var pole = qualiResults[0]
  if (!pole) return null
  var driver = pole.Driver || {}
  var constructor = pole.Constructor || {}
  var lapTime = pole.Q3 || pole.Q2 || pole.Q1 || ""
  return {
    driverName: String(driver.givenName ? (driver.givenName + " " + driver.familyName) : (driver.familyName || "Driver")),
    code: String(driver.code || driver.familyName || "DRV"),
    constructorName: String(constructor.name || "Constructor"),
    lapTime: String(lapTime)
  }
}
