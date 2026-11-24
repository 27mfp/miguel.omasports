.pragma library

// Deterministic OMASPORTS_MOCK=1 simulation for every supported sport.

var mockAnchor = 0

function resetMockClock(nowMs) {
  mockAnchor = Number(nowMs) || 0
}

function mockMinuteClock(kickoffMs, nowMs) {
  // Football clock simulation: returns { state, liveTime, minute }
  var elapsed = Math.floor((nowMs - kickoffMs) / 60000)
  if (elapsed < 0) return { state: "upcoming", liveTime: "", minute: 0 }
  if (elapsed < 45) return { state: "live", liveTime: "\u200e" + Math.max(1, elapsed) + "\u2019\u200e", minute: elapsed }
  if (elapsed < 60) return { state: "live", liveTime: "HT", minute: 45 }
  if (elapsed < 108) return { state: "live", liveTime: "\u200e" + Math.min(90, elapsed - 15) + "\u2019\u200e", minute: elapsed - 15 }
  return { state: "finished", liveTime: "", minute: 90 }
}

function mockRound(sport, nowMs) {
  var now = Number(nowMs) || Date.now()
  if (!mockAnchor || mockAnchor > now) mockAnchor = now
  var anchor = mockAnchor
  var iso = function(msOffset) { return new Date(anchor + msOffset).toISOString() }
  var MIN = 60000, HOUR = 3600000, DAY = 86400000
  var s = String(sport || "football")

  function fbMatch(id, homeId, homeName, awayId, awayName, kickoffOffset, round) {
    var kickoff = anchor + kickoffOffset
    var clock = mockMinuteClock(kickoff, now)
    var homeScore = 0, awayScore = 0
    if (clock.state !== "upcoming") {
      // Scripted storyline: 0-0 → 1-0 at 18' → 1-1 at 32' (goal notification!) → 2-1 at 61'
      var elapsed = Math.floor((now - kickoff) / 60000)
      if (elapsed >= 18) homeScore = 1
      if (elapsed >= 32) awayScore = 1
      if (elapsed >= 61) homeScore = 2
    }
    return {
      id: id, sport: "football", leagueId: homeId === "9825" ? "47" : "61", leagueName: homeId === "9825" ? "Premier League" : "Liga Portugal",
      round: round || "",
      home: { id: homeId, name: homeName, shortName: homeName, logo: "https://images.fotmob.com/image_resources/logo/teamlogo/" + homeId + ".png" },
      away: { id: awayId, name: awayName, shortName: awayName, logo: "https://images.fotmob.com/image_resources/logo/teamlogo/" + awayId + ".png" },
      status: clock.state,
      homeScore: homeScore, awayScore: awayScore,
      scoreText: clock.state === "upcoming" ? "" : homeScore + "\u2013" + awayScore,
      statusReason: clock.state === "finished" ? "FT" : "",
      liveTime: clock.liveTime,
      time: iso(kickoffOffset),
      pageUrl: "/matches/mock/" + id
    }
  }

  function espnMatch(id, sportName, leagueName, homeId, homeAbbr, homeName, awayId, awayAbbr, awayName, kickoffOffset, state, score, clock) {
    var cdn = "https://a.espncdn.com/i/teamlogos/" + sportName + "/500/"
    return {
      id: id, sport: sportName, leagueId: sportName, leagueName: leagueName,
      round: "",
      home: { id: homeId, name: homeName, shortName: homeAbbr, abbr: homeAbbr, record: "10-4", logo: cdn + homeAbbr + ".png" },
      away: { id: awayId, name: awayName, shortName: awayAbbr, abbr: awayAbbr, record: "9-5", logo: cdn + awayAbbr + ".png" },
      status: state,
      linescores: state === "upcoming" ? { home: [], away: [] } : (sportName === "mlb"
        ? { home: [1, 0, 0, 2, 0, 1, 0], away: [0, 1, 0, 0, 2, 1, 0] }
        : (sportName === "nba" ? { home: [32, 34, 32], away: [30, 33, 32] }
          : (sportName === "nfl" ? { home: [7, 10], away: [3, 7] } : { home: [1, 1], away: [0, 2] }))),
      homeScore: state === "upcoming" ? 0 : score[0],
      awayScore: state === "upcoming" ? 0 : score[1],
      scoreText: state === "upcoming" ? "" : score[0] + "\u2013" + score[1],
      statusReason: state === "finished" ? "Final" : (clock || ""),
      liveTime: state === "live" ? (clock || "LIVE") : "",
      time: iso(kickoffOffset),
      pageUrl: "https://www.espn.com/" + sportName
    }
  }

  var matches = []
  var standings = {}

  if (s === "football") {
    matches = [
      // LIVE at launch (kicked off 25 min before the panel session started)
      fbMatch("mock-fb-1", "9825", "Arsenal", "9826", "Crystal Palace", -25 * MIN, "Matchday 1"),
      // Kicks off 12 minutes in → pre-match notification + countdown
      fbMatch("mock-fb-2", "9772", "Benfica", "9773", "FC Porto", 12 * MIN, "Matchday 1"),
      // Recent result
      fbMatch("mock-fb-3", "9767", "Famalic\u00e3o", "9769", "Estoril Praia", -26 * HOUR),
      // Tomorrow
      fbMatch("mock-fb-4", "9775", "Vit\u00f3ria SC", "9771", "SC Braga", 26 * HOUR)
    ]
    standings = { "Premier League": mockFootballTable() }
  } else if (s === "nba") {
    matches = [
      espnMatch("mock-nba-1", "nba", "NBA", "13", "LAL", "Los Angeles Lakers", "2", "BOS", "Boston Celtics", -75 * MIN, "live", [98, 95], "Q3 8:44"),
      espnMatch("mock-nba-2", "nba", "NBA", "9", "GSW", "Golden State Warriors", "4", "CHI", "Chicago Bulls", 5 * HOUR, "upcoming", [0, 0], "")
    ]
    standings = {
      "Eastern Conference": mockEspnTable("nba", [["2", "BOS", "Boston Celtics"], ["4", "CHI", "Chicago Bulls"]]),
      "Western Conference": mockEspnTable("nba", [["13", "LAL", "Los Angeles Lakers"], ["9", "GSW", "Golden State Warriors"]])
    }
  } else if (s === "f1") {
    // Race happening right now (live for a 3h window, like the real parser)
    // plus the next one in 3 days — mirrors parseF1Calendar's output shape.
    function f1Race(id, round, name, circuit, locality, country, flag, raceOffset, statusOverride, winner) {
      var raceMs = anchor + raceOffset
      var status = statusOverride
      if (!status) {
        if (now > raceMs + 3 * HOUR) status = "finished"
        else if (now >= raceMs) status = "live"
        else status = "upcoming"
      }
      var rObj = {
        id: id, sport: "f1", leagueId: "f1", leagueName: "Formula 1",
        round: round, raceName: name, circuitName: circuit,
        locality: locality, country: country, countryFlag: flag,
        status: status,
        sessions: [
          { name: "Practice 1", shortName: "FP1", time: new Date(raceMs - 2 * DAY).toISOString() },
          { name: "Qualifying", shortName: "Quali", time: new Date(raceMs - DAY).toISOString() },
          { name: "Grand Prix (Race)", shortName: "Race", time: new Date(raceMs).toISOString() }
        ],
        home: { id: "f1-gp-mock", name: name, shortName: name.replace(" Grand Prix", " GP"), record: locality + ", " + country, logo: "" },
        away: { id: "f1-circuit-mock", name: circuit, shortName: country, record: "", logo: "" },
        homeScore: 0, awayScore: 0,
        scoreText: winner ? ("🏆 " + (winner.code || winner.familyName)) : (status === "finished" ? "Official" : (status === "live" ? "RACE DAY" : round)),
        statusReason: status === "finished" ? (winner ? ("Winner: " + winner.driverName) : "Official") : (status === "live" ? "LIVE" : "Scheduled"),
        liveTime: status === "live" ? "RACE" : "",
        time: new Date(raceMs).toISOString(), pageUrl: "https://www.formula1.com"
      }
      if (winner) rObj.winner = winner
      return rObj
    }
    matches = [
      f1Race("mock-f1-0", "Round 10", "Portuguese Grand Prix", "Autódromo", "Portimão", "Portugal", "\ud83c\uddf5\ud83c\uddf9", -5 * DAY, "finished", {
        round: "10", driverId: "norris", driverName: "Lando Norris", familyName: "Norris", code: "NOR",
        constructorName: "McLaren", time: "1:30:12.456", laps: "66", grid: "1", points: "25"
      }),
      f1Race("mock-f1-1", "Round 11", "Mock Grand Prix", "Circuito da Mocka", "Lisboa", "Portugal", "\ud83c\uddf5\ud83c\uddf9", -45 * MIN),
      f1Race("mock-f1-2", "Round 12", "Sprint Mock Grand Prix", "Mock Ring", "Spielberg", "Austria", "\ud83c\udde6\ud83c\uddf9", 3 * DAY)
    ]
    standings = {
      "Drivers": mockF1Drivers(),
      "Constructors": mockF1Constructors()
    }
  } else if (s === "nfl") {
    matches = [
      espnMatch("mock-nfl-0", "nfl", "NFL", "3", "CHI", "Chicago Bears", "1", "ATL", "Atlanta Falcons", -70 * MIN, "live", [17, 10], "Q2 5:32"),
      espnMatch("mock-nfl-1", "nfl", "NFL", "2", "BUF", "Buffalo Bills", "3", "CHI", "Chicago Bears", -20 * HOUR, "finished", [27, 24], "Final"),
      espnMatch("mock-nfl-2", "nfl", "NFL", "1", "ATL", "Atlanta Falcons", "2", "BUF", "Buffalo Bills", 6 * HOUR, "upcoming", [0, 0], "")
    ]
    standings = { "American Football Conference": mockEspnTable("nfl", [["2", "BUF", "Buffalo Bills"]]), "National Football Conference": mockEspnTable("nfl", [["3", "CHI", "Chicago Bears"], ["1", "ATL", "Atlanta Falcons"]]) }
  } else if (s === "mlb") {
    matches = [
      espnMatch("mock-mlb-0", "mlb", "MLB", "2", "BOS", "Boston Red Sox", "10", "NYY", "New York Yankees", -90 * MIN, "live", [4, 4], "7th"),
      espnMatch("mock-mlb-1", "mlb", "MLB", "10", "NYY", "New York Yankees", "2", "BOS", "Boston Red Sox", -3 * HOUR, "finished", [5, 3], "Final"),
      espnMatch("mock-mlb-2", "mlb", "MLB", "1", "BAL", "Baltimore Orioles", "10", "NYY", "New York Yankees", 4 * HOUR, "upcoming", [0, 0], "")
    ]
    standings = { "American League": mockEspnTable("mlb", [["10", "NYY", "New York Yankees"], ["2", "BOS", "Boston Red Sox"], ["1", "BAL", "Baltimore Orioles"]]), "National League": mockEspnTable("mlb", [["19", "LAD", "Los Angeles Dodgers"], ["21", "NYM", "New York Mets"]]) }
  } else if (s === "nhl") {
    matches = [
      espnMatch("mock-nhl-1", "nhl", "NHL", "1", "BOS", "Boston Bruins", "5", "DET", "Detroit Red Wings", -2 * HOUR, "live", [2, 2], "2nd 12:00"),
      espnMatch("mock-nhl-2", "nhl", "NHL", "2", "BUF", "Buffalo Sabres", "1", "BOS", "Boston Bruins", 7 * HOUR, "upcoming", [0, 0], "")
    ]
    standings = { "Eastern Conference": mockEspnTable("nhl", [["1", "BOS", "Boston Bruins"], ["2", "BUF", "Buffalo Sabres"], ["5", "DET", "Detroit Red Wings"]]), "Western Conference": mockEspnTable("nhl", [["24", "ANA", "Anaheim Ducks"], ["25", "DAL", "Dallas Stars"]]) }
  }

  return { matches: matches, standings: standings }
}

function mockFootballTable() {
  var teams = [
    ["9825", "Arsenal", 1], ["9772", "Benfica", 1], ["9773", "FC Porto", 0],
    ["9826", "Crystal Palace", 0], ["9771", "SC Braga", 0], ["9767", "Famalic\u00e3o", 0],
    ["9769", "Estoril Praia", 0], ["9775", "Vit\u00f3ria SC", -1]
  ]
  var rows = []
  for (var i = 0; i < teams.length; i++) {
    var t = teams[i]
    var zone = i < 3 ? "europe" : (i === teams.length - 1 ? "relegation" : "")
    rows.push({
      pos: String(i + 1), id: t[0], name: t[1], shortName: t[1],
      logo: "https://images.fotmob.com/image_resources/logo/teamlogo/" + t[0] + ".png",
      played: 10 + i, wins: 6, draws: 2, losses: 2,
      gd: t[2] * 5, pts: 20 - i, zone: zone
    })
  }
  return rows
}

function mockEspnTable(sport, teams) {
  var rows = []
  for (var i = 0; i < teams.length; i++) {
    var t = teams[i]
    var zone = ""
    if (sport === "nba") zone = i < 3 ? "europe" : "playin"
    else if (sport === "nhl") zone = i < 1 ? "europe" : ""
    else if (sport === "nfl") zone = i < 1 ? "europe" : ""
    else if (sport === "mlb") zone = i < 1 ? "europe" : ""
    rows.push({
      pos: String(i + 1), id: t[0], name: t[2], shortName: t[2], abbr: t[1],
      logo: "https://a.espncdn.com/i/teamlogos/" + sport + "/500/" + t[1] + ".png",
      played: 12, wins: 8, draws: 0, losses: 4,
      gd: "+6", pct: ".667", gb: i === 0 ? "–" : String(i), pts: sport === "nhl" ? "16" : String(8 - i) + "W", zone: zone
    })
  }
  return rows
}

function mockF1Drivers() {
  var data = [
    ["1", "norris", "Lando Norris", "NOR", "\ud83c\uddec\ud83c\udde7", "mclaren", "McLaren", "234 PTS"],
    ["2", "piastri", "Oscar Piastri", "PIA", "\ud83c\udde6\ud83c\uddfa", "mclaren", "McLaren", "226 PTS"],
    ["3", "verstappen", "Max Verstappen", "VER", "\ud83c\uddf3\ud83c\uddf1", "red_bull", "Red Bull Racing", "210 PTS"],
    ["4", "hamilton", "Lewis Hamilton", "HAM", "\ud83c\uddec\ud83c\udde7", "ferrari", "Ferrari", "152 PTS"],
    ["5", "leclerc", "Charles Leclerc", "LEC", "\ud83c\uddf2\ud83c\udde8", "ferrari", "Ferrari", "148 PTS"]
  ]
  var rows = []
  for (var i = 0; i < data.length; i++) {
    var d = data[i]
    rows.push({
      pos: d[0], id: d[1], name: d[2], shortName: d[3], abbr: d[3],
      flag: d[4], teamId: d[5], teamName: d[6],
      played: 11, wins: i === 0 ? 5 : 1, draws: 0, losses: 0,
      gd: d[6], pts: d[7], zone: i === 0 ? "europe" : (i < 3 ? "playin" : "")
    })
  }
  return rows
}

function mockF1Constructors() {
  var data = [
    ["1", "mclaren", "McLaren", "460 PTS"],
    ["2", "red_bull", "Red Bull Racing", "341 PTS"],
    ["3", "ferrari", "Ferrari", "300 PTS"]
  ]
  var rows = []
  for (var i = 0; i < data.length; i++) {
    rows.push({
      pos: data[i][0], id: data[i][1], name: data[i][2], shortName: data[i][2],
      abbr: data[i][1], logo: "", played: 11, wins: 0, draws: 0, losses: 0,
      gd: data[i][2], pts: data[i][3], zone: i === 0 ? "europe" : ""
    })
  }
  return rows
}
