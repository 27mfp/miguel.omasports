// Run with: node tests/sportsmodel.test.mjs
// SportsModel.js is a QML JS library (.pragma library); the loader strips the
// pragma and exports the functions so plain Node can exercise the parsers.
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"

const raw = readFileSync(new URL("../SportsModel.js", import.meta.url), "utf8")
const exported = [
  "supportedSports", "supportedLeagues", "nbaTeams", "nhlTeams", "mlbTeams",
  "nflTeams", "f1Drivers", "popularFootballClubs",
  "defaultState", "formatCountdown", "arrayFrom", "normalizeLeagueIds",
  "normalizeTeamIds", "crestCacheKey", "espnDateRange", "formatKickoff",
  "normalizeTab", "isEspnScoreboardPayload", "isEspnStandingsPayload", "isF1CalendarPayload",
  "parseState", "statePayload", "parseEspnScoreboard", "parseEspnStandings",
  "f1CountryFlag", "f1DriverFlag", "parseF1Calendar", "parseF1DriverStandings",
  "parseF1ConstructorStandings", "parseScore", "parseMatch", "parseDetails",
  "parseStandings", "zoneFromLegend", "mergePages", "mergeMatchUpdates", "mergeLeaguePages", "isTeamPagePayload", "teamOptionsForSport",
  "matchesForTeam", "matchesForLeague", "featuredMatchForTeam", "teamIdForMatch", "teamOutcome", "teamOutcomeForTeams", "isFollowedTeam", "isStandingsRowFavorite",
  "groupMatches", "formatMatchDate", "matchStatusText", "leagueLabel", "isTrustedCrestUrl", "matchExternalUrl", "matchDetailUrl",
  "sportMeta", "shortTournamentName", "liveMatches", "matchLine", "interpolateLiveTime",
  "sameMatches", "sameRows", "sameGroups", "diffMatchNotifications", "buildPersistedState", "parseLeaguePage", "parseTeamPage",
  "mockRound", "parseMatchTimeMs", "refreshIntervalOptions", "mergeSeenMap", "NOTIFICATION_TTL_MS", "dictSet", "dictDelete"
]
const src = raw.replace(/^\.pragma library\s*$/m, "") + "\nexport { " + exported.join(", ") + " }\n"
const Model = await import("data:text/javascript;base64," + Buffer.from(src).toString("base64"))

// Catch a renamed or removed export at module-load time, before downstream
// tests fail with confusing "Model.foo is not a function" errors.
for (const name of exported) {
  assert.ok(name in Model, "missing export from SportsModel.js: " + name)
}

let passed = 0
function test(name, fn) {
  fn()
  passed++
  console.log("  ✓ " + name)
}

// ---------------------------------------------------------------- helpers
console.log("helpers")
test("formatCountdown formats days/hours/minutes", () => {
  const now = Date.now()
  assert.equal(Model.formatCountdown(new Date(now + 90 * 60000).toISOString(), now), "1h 30m")
  assert.equal(Model.formatCountdown(new Date(now + 5 * 60000).toISOString(), now), "5m")
  assert.equal(Model.formatCountdown(new Date(now + 3 * 86400000 + 2 * 3600000).toISOString(), now), "3d 2h")
  assert.equal(Model.formatCountdown(new Date(now - 60000).toISOString(), now), "Starting soon")
  assert.equal(Model.formatCountdown("not-a-date", now), "")
})
test("arrayFrom rejects strings and nulls, copies arrays", () => {
  assert.deepEqual(Model.arrayFrom("abc"), [])
  assert.deepEqual(Model.arrayFrom(null), [])
  assert.deepEqual(Model.arrayFrom([1, 2]), [1, 2])
})
test("normalizeLeagueIds caps at 12 and dedupes", () => {
  const ids = ["1", "1", "2", ...Array.from({ length: 20 }, (_, i) => String(100 + i))]
  const out = Model.normalizeLeagueIds(ids)
  assert.equal(out.length, 12)
  assert.equal(new Set(out).size, 12)
})
test("normalizeTeamIds caps at 24", () => {
  const ids = Array.from({ length: 40 }, (_, i) => String(i))
  assert.equal(Model.normalizeTeamIds(ids).length, 24)
  assert.deepEqual(Model.normalizeTeamIds([" ", "", undefined]), [])
})

// ---------------------------------------------------------------- cache keys
console.log("crestCacheKey")
test("football and f1 key by provider id", () => {
  assert.equal(Model.crestCacheKey("football", "9772", ""), "football-9772")
  assert.equal(Model.crestCacheKey("f1", "red_bull", ""), "f1-red_bull")
})
test("us sports key by abbreviation, falling back to id", () => {
  assert.equal(Model.crestCacheKey("nba", "9", "GS"), "nba-gs")
  assert.equal(Model.crestCacheKey("nhl", "129764", "UTAH"), "nhl-utah")
  assert.equal(Model.crestCacheKey("mlb", "10", ""), "mlb-10")
})
test("sanitizes unsafe characters and returns empty without identity", () => {
  assert.equal(Model.crestCacheKey("nba", "12", "LAC/evil"), "nba-lacevil")
  assert.equal(Model.crestCacheKey("football", "", ""), "")
})

// ---------------------------------------------------------------- espn dates
console.log("espnDateRange / formatKickoff")
test("espnDateRange produces a YYYYMMDD-YYYYMMDD window", () => {
  const range = Model.espnDateRange(1, 3)
  const [from, to] = range.split("-")
  assert.match(from, /^\d{8}$/)
  assert.match(to, /^\d{8}$/)
  const days = (Date.parse(`${to.slice(0,4)}-${to.slice(4,6)}-${to.slice(6,8)}`) -
                Date.parse(`${from.slice(0,4)}-${from.slice(4,6)}-${from.slice(6,8)}`)) / 86400000
  assert.equal(days, 4)
})
test("formatKickoff renders local HH:mm or empty", () => {
  assert.match(Model.formatKickoff("2026-08-22T19:45:00Z"), /^\d{2}:\d{2}$/)
  assert.equal(Model.formatKickoff("nope"), "")
})

// ---------------------------------------------------------------- state
console.log("state")
test("parseState falls back to defaults on garbage", () => {
  for (const bad of ["", "not json", "42", "null"]) {
    const st = Model.parseState(bad)
    assert.equal(st.sport, "football")
    assert.deepEqual(st.football.leagueIds, ["47"])
    assert.equal(st.football.tab, "fixtures")
  }
})
test("parseState clamps refreshMinutes and validates sport", () => {
  const st = Model.parseState(JSON.stringify({ sport: "boxing", refreshMinutes: 999 }))
  assert.equal(st.sport, "football")
  assert.equal(st.refreshMinutes, 60)
  assert.equal(Model.parseState(JSON.stringify({ refreshMinutes: 1 })).refreshMinutes, 5)
})
test("parseState normalizes invalid tab names and rejects JSON arrays", () => {
  const st = Model.parseState(JSON.stringify({
    football: { leagueIds: ["47"], tab: "unknown" },
    nba: { tab: "table" }
  }))
  assert.equal(st.football.tab, "fixtures")
  assert.equal(st.nba.tab, "standings")
  assert.equal(Model.parseState("[]").football.leagueIds[0], "47")
})
test("parseState preserves per-sport tab and migrates v1 favorites", () => {
  const st = Model.parseState(JSON.stringify({
    leagueIds: ["47", "61"],
    teamId: "9772",
    f1: { teamId: "max_verstappen", tab: "standings" }
  }))
  assert.deepEqual(st.football.leagueIds, ["47", "61"])
  assert.deepEqual(st.football.teamIds, ["9772"])
  assert.equal(st.f1.teamId, "max_verstappen")
  assert.equal(st.f1.tab, "standings")
  assert.equal(st.football.tab, "fixtures")
})
test("statePayload round-trips through parseState", () => {
  const payload = Model.statePayload("nba", ["61"], [], "", 15, "61", {}, true, false)
  const st = Model.parseState(JSON.stringify(payload))
  assert.equal(st.sport, "nba")
  assert.equal(st.antiSpoiler, true)
  assert.equal(st.notifications, false)
  assert.equal(st.nba.tab, "fixtures")
})
test("persistState shape round-trips exactly (applyState signature check)", () => {
  // Exercises the REAL writer (Model.buildPersistedState, used by Panel.qml):
  // the written JSON must re-parse to an identical object, otherwise
  // ignoredStateSignature never matches and every own write would trigger a
  // spurious network round.
  const base = Model.parseState(JSON.stringify({
    sport: "nba",
    football: { leagueIds: ["61", "47"], teamIds: ["9772"], teamId: "9772", teamName: "Benfica", standingsLeagueId: "61", tab: "live" },
    nba: { teamIds: ["13"], teamId: "13", teamName: "Los Angeles Lakers", standingsGroup: "Western Conference", tab: "fixtures" },
    refreshMinutes: 15, notifications: true
  }))
  const ui = {
    tabName: "standings",
    selectedLeagueIds: ["61"],
    selectedTeamIds: ["13"],
    selectedTeamId: "13",
    selectedTeamName: "Los Angeles Lakers",
    standingsLeagueId: "Western Conference",
    antiSpoiler: false,
    enableNotifications: true
  }
  const saved = Model.buildPersistedState("nba", base, ui)
  const written = JSON.stringify(saved, null, 2) + "\n"
  const reparsed = Model.parseState(written)
  assert.equal(JSON.stringify(reparsed), JSON.stringify(saved))
  assert.equal(reparsed.nba.tab, "standings")
  assert.equal(reparsed.football.tab, "live")
  // and the same holds when football is the active sport
  const saved2 = Model.buildPersistedState("football", base, { ...ui,
    selectedTeamIds: ["9772"], selectedTeamId: "9772", selectedTeamName: "Benfica",
    standingsLeagueId: "61", tabName: "live" })
  assert.equal(JSON.stringify(Model.parseState(JSON.stringify(saved2))), JSON.stringify(saved2))
  assert.equal(saved2.football.tab, "live")
})

test("parseLeaguePage returns null for bot-wall / consent HTML", () => {
  // Cloudflare challenges and rate-limit pages have no __NEXT_DATA__ payload —
  // these must be treated as fetch failures (retryable), not empty leagues
  assert.equal(Model.parseLeaguePage("<html><body>Just a moment...</body></html>", "47"), null)
  assert.equal(Model.parseLeaguePage("", "47"), null)
})
test("provider payload validators reject syntactically valid error objects", () => {
  assert.ok(Model.isEspnScoreboardPayload({ events: [], leagues: [] }))
  assert.ok(!Model.isEspnScoreboardPayload({ code: 500, message: "upstream error" }))
  assert.ok(!Model.isEspnScoreboardPayload({ code: 500, events: [] }))
  assert.ok(Model.isEspnStandingsPayload({ children: [] }))
  assert.ok(!Model.isEspnStandingsPayload({ code: 500 }))
  assert.ok(Model.isF1CalendarPayload({ MRData: { RaceTable: { Races: [] } } }))
  assert.ok(!Model.isF1CalendarPayload({ error: "rate limited" }))
  assert.ok(!Model.isF1CalendarPayload({ errors: [], MRData: { RaceTable: { Races: [] } } }))
})
test("sameMatches / sameGroups detect real changes only", () => {
  const a = [{ id: "1", status: "live", homeScore: 1, awayScore: 0, liveTime: "34" }]
  assert.ok(Model.sameMatches(a, a))
  assert.ok(Model.sameMatches(a, [{ id: "1", status: "live", homeScore: 1, awayScore: 0, liveTime: "34" }]))
  assert.ok(!Model.sameMatches(a, [{ id: "1", status: "live", homeScore: 2, awayScore: 0, liveTime: "34" }]))
  assert.ok(!Model.sameMatches(a, [{ id: "2", status: "live", homeScore: 1, awayScore: 0, liveTime: "34" }]))
  const g = [{ key: "live", label: "Live Matches", matches: a }]
  assert.ok(Model.sameGroups(g, [{ key: "live", label: "Live Matches", matches: [...a] }]))
  assert.ok(!Model.sameGroups(g, [{ key: "live", label: "Live Matches", matches: [] }]))
})
test("identity comparisons notice presentation changes, not only scores", () => {
  const row = [{ id: "1", name: "Old", pos: "1", pts: "3", gd: "1" }]
  assert.ok(Model.sameRows(row, [{ ...row[0] }]))
  assert.ok(!Model.sameRows(row, [{ ...row[0], name: "Renamed" }]))
  const match = [{ id: "1", status: "upcoming", homeScore: 0, awayScore: 0, scoreText: "", time: "2026-01-01T00:00:00Z", home: { id: "1", name: "Old" }, away: { id: "2", name: "Away" } }]
  assert.ok(!Model.sameMatches(match, [{ ...match[0], home: { id: "1", name: "Renamed" }, away: match[0].away }]))
})
test("team page payload detection distinguishes bot walls from valid empty pages", () => {
  const json = { props: { pageProps: { fallback: { "team-1": { fixtures: { allFixtures: { fixtures: [] } } } } } } }
  const html = '<script id="__NEXT_DATA__" type="application/json">' + JSON.stringify(json) + "</script>"
  assert.ok(Model.isTeamPagePayload(html, "1"))
  assert.deepEqual(Model.parseTeamPage(html, "1"), [])
  assert.ok(!Model.isTeamPagePayload("<html>blocked</html>", "1"))
  const wrongTeam = '<script id="__NEXT_DATA__" type="application/json">' + JSON.stringify({ props: { pageProps: { fallback: { "team-2": json.props.pageProps.fallback["team-1"] } } } }) + "</script>"
  assert.ok(!Model.isTeamPagePayload(wrongTeam, "1"))
})

// ---------------------------------------------------------------- ESPN parsers
console.log("ESPN parsers")
const espnScoreboard = JSON.stringify({
  leagues: [{ name: "National Basketball Association" }],
  events: [
    {
      id: "401777665",
      date: "2026-08-21T23:30Z",
      status: { type: { state: "in", shortDetail: "Q3 4:21", displayClock: "4:21" } },
      competitions: [{
        competitors: [
          { homeAway: "home", score: "104", team: { id: "13", displayName: "Los Angeles Lakers", shortDisplayName: "Lakers", abbreviation: "LAL", logo: "https://a.espncdn.com/i/teamlogos/nba/500/lal.png" } },
          { homeAway: "away", score: "98", team: { id: "9", displayName: "Golden State Warriors", shortDisplayName: "Warriors", abbreviation: "GS" } }
        ]
      }]
    },
    {
      id: "401777666",
      date: "2026-08-22T01:00Z",
      status: { type: { state: "post", shortDetail: "Final" } },
      competitions: [{
        competitors: [
          { homeAway: "home", score: "3", team: { id: "12", displayName: "Kansas City Chiefs", abbreviation: "KC" } },
          { homeAway: "away", score: "7", team: { id: "10", displayName: "Tennessee Titans", abbreviation: "TEN" } }
        ]
      }]
    }
  ]
})
test("parseEspnScoreboard maps live/finished events with scores", () => {
  const matches = Model.parseEspnScoreboard(espnScoreboard, "nfl", "NFL")
  assert.equal(matches.length, 2)
  const [live, done] = matches
  assert.equal(live.status, "live")
  assert.equal(live.homeScore, 104)
  assert.equal(live.awayScore, 98)
  assert.equal(live.scoreText, "104–98")
  assert.equal(live.liveTime, "Q3 4:21")
  assert.equal(live.home.abbr, "LAL")
  assert.equal(done.status, "finished")
  assert.equal(done.sport, "nfl")
})
test("parseEspnScoreboard tolerates empty payloads", () => {
  assert.deepEqual(Model.parseEspnScoreboard("", "nba", "NBA"), [])
  assert.deepEqual(Model.parseEspnScoreboard("{}", "nba", "NBA"), [])
})

const espnStandings = (groups) => JSON.stringify({
  children: groups.map(([name, seeds]) => ({
    name,
    standings: {
      entries: seeds.map((seed, i) => ({
        team: { id: String(seed), displayName: "Team " + seed, abbreviation: "T" + seed },
        stats: [
          { name: "wins", displayValue: "10" },
          { name: "losses", displayValue: "5" },
          { name: "playoffSeed", displayValue: String(seed) }
        ]
      }))
    }
  }))
})
test("parseEspnStandings marks NBA play-in seeds 7-10", () => {
  const table = Model.parseEspnStandings(espnStandings([["Eastern Conference", [1, 6, 7, 10, 11]]]), "nba")
  const rows = table["Eastern Conference"]
  assert.equal(rows[0].zone, "europe")
  assert.equal(rows[1].zone, "europe")
  assert.equal(rows[2].zone, "playin")
  assert.equal(rows[3].zone, "playin")
  assert.equal(rows[4].zone, "")
  assert.equal(rows[0].played, 15)
})
test("parseEspnStandings uses sport-specific playoff cutoffs", () => {
  const nfl = Model.parseEspnStandings(espnStandings([["AFC", [1, 7, 8]]]), "nfl")["AFC"]
  assert.equal(nfl[1].zone, "europe")
  assert.equal(nfl[2].zone, "")
  const nhl = Model.parseEspnStandings(espnStandings([["Eastern Conference", [1, 8, 9]]]), "nhl")["Eastern Conference"]
  assert.equal(nhl[1].zone, "europe")
  assert.equal(nhl[2].zone, "")
})

// ---------------------------------------------------------------- F1
console.log("Formula 1")
const f1Calendar = JSON.stringify({
  MRData: { RaceTable: { Races: [
    {
      round: "1", raceName: "Australian Grand Prix", date: "2026-03-08", time: "05:00:00Z", url: "https://wikipedia.org/x",
      Circuit: { circuitName: "Albert Park Circuit", Location: { locality: "Melbourne", country: "Australia" } },
      FirstPractice: { date: "2026-03-06", time: "01:30:00Z" },
      SecondPractice: { date: "2026-03-06", time: "05:00:00Z" },
      ThirdPractice: { date: "2026-03-07", time: "02:30:00Z" },
      Qualifying: { date: "2026-03-07", time: "06:00:00Z" }
    },
    {
      round: "2", raceName: "Saudi Arabian Grand Prix", date: "2100-01-01", time: "14:00:00Z",
      Circuit: { circuitName: "Jeddah Corniche Circuit", Location: { locality: "Jeddah", country: "Saudi Arabia" } },
      FirstPractice: { date: "2100-01-01", time: "10:00:00Z" },
      SprintQualifying: { date: "2100-01-01", time: "11:00:00Z" },
      Sprint: { date: "2100-01-01", time: "12:00:00Z" },
      Qualifying: { date: "2100-01-01", time: "13:00:00Z" }
    }
  ] } }
})
test("parseF1Calendar builds weekend sessions and statuses", () => {
  const races = Model.parseF1Calendar(f1Calendar)
  assert.equal(races.length, 2)
  const [past, future] = races
  assert.equal(past.status, "finished")
  assert.equal(past.countryFlag, "🇦🇺")
  assert.deepEqual(past.sessions.map(s => s.shortName), ["FP1", "FP2", "FP3", "Quali", "Race"])
  assert.equal(future.status, "upcoming")
  assert.deepEqual(future.sessions.map(s => s.shortName), ["FP1", "SQ", "Sprint", "Quali", "Race"])
})
const f1DriversJson = JSON.stringify({
  MRData: { StandingsTable: { StandingsLists: [{
    DriverStandings: [
      {
        position: "1", points: "257", wins: "6",
        Driver: { driverId: "max_verstappen", givenName: "Max", familyName: "Verstappen", code: "VER", nationality: "Dutch" },
        Constructors: [{ constructorId: "red_bull", name: "Red Bull Racing" }]
      },
      {
        position: "22", points: "4", wins: "0",
        Driver: { driverId: "perez", givenName: "Sergio", familyName: "Pérez", code: "PER", nationality: "Mexican" },
        Constructors: [{ constructorId: "cadillac", name: "Cadillac" }]
      }
    ]
  }] } }
})
test("parseF1DriverStandings maps rows with flags and points", () => {
  const rows = Model.parseF1DriverStandings(f1DriversJson)
  assert.equal(rows.length, 2)
  assert.equal(rows[0].pts, "257 PTS")
  assert.equal(rows[0].flag, "🇳🇱")
  assert.equal(rows[0].zone, "europe")
  assert.equal(rows[1].flag, "🇲🇽")
  assert.equal(rows[1].teamName, "Cadillac")
})
test("f1DriverFlag covers the 2026 grid", () => {
  assert.equal(Model.f1DriverFlag("max_verstappen"), "🇳🇱")
  assert.equal(Model.f1DriverFlag("arvid_lindblad"), "🇬🇧")
  assert.equal(Model.f1DriverFlag("colapinto"), "🇦🇷")
  assert.equal(Model.f1DriverFlag("bottas"), "🇫🇮")
  assert.equal(Model.f1DriverFlag("lawson"), "🇳🇿")
  assert.equal(Model.f1DriverFlag("hulkenberg"), "🇩🇪")
  assert.equal(Model.f1DriverFlag("unknown"), "🏎")
})
test("f1CountryFlag resolves hosts and circuits", () => {
  assert.equal(Model.f1CountryFlag("", "São Paulo Grand Prix"), "🇧🇷")
  assert.equal(Model.f1CountryFlag("United States", ""), "🇺🇸")
  assert.equal(Model.f1CountryFlag("Saudi Arabia", ""), "🇸🇦")
})

// ---------------------------------------------------------------- FotMob
console.log("FotMob parsers")
test("parseScore reads scoreStr", () => {
  assert.deepEqual(Model.parseScore({ scoreStr: "2-1" }), { home: 2, away: 1, text: "2–1" })
  assert.deepEqual(Model.parseScore({ aggregateStr: "3-3" }), { home: 0, away: 0, text: "3-3" })
  assert.deepEqual(Model.parseScore(null), { home: 0, away: 0, text: "" })
})
test("parseMatch derives status and fotmob logos", () => {
  const m = Model.parseMatch({
    id: "42", round: "Round 3", pageUrl: "/match/42",
    home: { id: "9772", name: "Benfica", shortName: "Benfica" },
    away: { id: "9768", name: "Sporting CP", shortName: "Sporting" },
    status: { ongoing: true, started: true, utcTime: "2026-08-22T19:45:00Z", reason: { short: "73'", long: "73'" }, scoreStr: "1-0", liveTime: { short: "73'" } }
  }, { id: "61", name: "Primeira Liga" })
  assert.equal(m.status, "live")
  assert.equal(m.homeScore, 1)
  assert.equal(m.home.logo, "https://images.fotmob.com/image_resources/logo/teamlogo/9772.png")
  assert.equal(m.pageUrl, "/match/42")
  assert.equal(m.liveTime, "73'")
})
test("zoneFromLegend maps champions and relegation zones", () => {
  const legend = [
    { title: "Champions League", indices: [0, 1, 2] },
    { title: "Relegation", indices: [17] }
  ]
  assert.equal(Model.zoneFromLegend(legend, 1), "europe")
  assert.equal(Model.zoneFromLegend(legend, 17), "relegation")
  assert.equal(Model.zoneFromLegend(legend, 10), "")
  assert.equal(Model.zoneFromLegend([{ title: "Relegation", indices: ["17"] }], 17), "relegation")
})
test("parseStandings preserves legends for object-shaped table payloads", () => {
  const props = {
    table: {
      data: {
        table: { all: [{ id: "1", name: "Leader", shortName: "Leader", idx: 1, played: 1, wins: 1, pts: 3 }] },
        legend: [{ title: "Champions League", indices: [0] }]
      }
    }
  }
  assert.equal(Model.parseStandings(props)[0].zone, "europe")
})

// ---------------------------------------------------------------- matching
console.log("match selection")
const sampleMatches = [
  { id: "a", leagueId: "61", status: "upcoming", time: "2100-01-03T10:00:00Z", home: { id: "x1", name: "Alpha", shortName: "Alpha" }, away: { id: "y1", name: "Beta", shortName: "Beta" } },
  { id: "b", leagueId: "47", status: "live", time: "2100-01-01T10:00:00Z", home: { id: "9772", name: "Benfica", shortName: "Benfica" }, away: { id: "z1", name: "Gamma", shortName: "Gamma" } },
  { id: "c", leagueId: "47", status: "finished", time: "2026-01-01T10:00:00Z", homeScore: 0, awayScore: 2, home: { id: "w1", name: "Delta", shortName: "Delta" }, away: { id: "9772", name: "Benfica", shortName: "Benfica" } }
]
test("matchesForTeam finds fixtures by team id and ignores other ids", () => {
  const forBenfica = Model.matchesForTeam(sampleMatches, "9772", "football")
  assert.equal(forBenfica.length, 2)
  assert.equal(Model.matchesForTeam(sampleMatches, "unknown", "football").length, 0)
  assert.equal(Model.matchesForTeam(sampleMatches, "whatever", "f1").length, 3) // f1 returns all
})
test("matchesForTeam does not substring-match numeric ids in team names", () => {
  const sixers = {
    id: "sixers-game",
    status: "finished",
    time: "2026-01-02T10:00:00Z",
    home: { id: "76", name: "Philadelphia 76ers", shortName: "76ers" },
    away: { id: "99", name: "Boston Celtics", shortName: "Celtics" }
  }
  assert.equal(Model.matchesForTeam([sixers], "7", "nba").length, 0)
  assert.equal(Model.matchesForTeam([sixers], "76", "nba").length, 1)
  assert.equal(Model.matchesForTeam([sixers], "76ers", "nba").length, 1)
})
test("favorite helpers support multiple followed teams", () => {
  assert.ok(Model.isFollowedTeam("9772", ["9773", "9772"]))
  assert.ok(Model.isFollowedTeam("9772", "9772"))
  assert.equal(Model.teamIdForMatch(sampleMatches[2], ["9773", "9772"]), "9772")
  assert.equal(Model.teamOutcomeForTeams(sampleMatches[2], ["9773", "9772"]), "win")
  assert.ok(Model.isStandingsRowFavorite({ id: "ctor", teamId: "mclaren", name: "Lando Norris" }, ["mclaren"], ""))
})
test("matchesForLeague filters and sorts chronologically", () => {
  const pl = Model.matchesForLeague(sampleMatches, "47")
  assert.equal(pl.length, 2)
  assert.equal(pl[0].id, "c") // 2026 kickoff sorts before the 2100 one
  assert.equal(pl[1].id, "b")
})
test("featuredMatchForTeam prefers live, then next upcoming", () => {
  assert.equal(Model.featuredMatchForTeam(sampleMatches).id, "b")
  const noLive = [sampleMatches[0], sampleMatches[2]]
  assert.equal(Model.featuredMatchForTeam(noLive).id, "a")
})
test("teamOutcome computes win/draw/loss for a team", () => {
  assert.equal(Model.teamOutcome(sampleMatches[2], "9772"), "win")
  assert.equal(Model.teamOutcome(sampleMatches[2], "w1"), "loss")
  assert.equal(Model.teamOutcome(sampleMatches[0], "x1"), "")
})
test("groupMatches buckets live/upcoming/recent and caps recent at 10", () => {
  const many = Array.from({ length: 15 }, (_, i) => ({ ...sampleMatches[2], id: "r" + i, time: new Date(Date.parse("2026-01-01T10:00:00Z") + i * 3600000).toISOString() }))
  const groups = Model.groupMatches([...sampleMatches.slice(0, 2), ...many])
  assert.deepEqual(groups.map(g => g.key), ["live", "upcoming", "recent"])
  assert.equal(groups[2].matches.length, 10)
  assert.equal(groups[2].matches[0].id, "r14") // most recent first
})
test("liveMatches filters out full-time details and sorts by time", () => {
  const live = Model.liveMatches(sampleMatches, { b: { statusLong: "Full-Time" } })
  assert.equal(live.length, 0)
  assert.equal(Model.liveMatches(sampleMatches, {}).length, 1)
})
test("liveMatches places invalid timestamps after valid ones", () => {
  const valid = { ...sampleMatches[1], id: "valid" }
  const invalid = { ...sampleMatches[1], id: "invalid", time: "not-a-date" }
  assert.deepEqual(Model.liveMatches([invalid, valid], {} ).map(m => m.id), ["valid", "invalid"])
})
test("mergePages dedupes by match id", () => {
  const merged = Model.mergePages([{ matches: sampleMatches }, { matches: [sampleMatches[0]] }])
  assert.equal(merged.length, 3)
})
test("merge helpers replace stale matches and league pages", () => {
  const updated = { ...sampleMatches[1], homeScore: 4, scoreText: "4–0" }
  const matches = Model.mergeMatchUpdates(sampleMatches, [updated])
  assert.equal(matches.length, 3)
  assert.equal(matches.find(m => m.id === "b").homeScore, 4)
  const oldPage = { league: { id: "47" }, matches: [sampleMatches[1]], standings: [] }
  const newPage = { league: { id: "47" }, matches: [updated], standings: [{ pos: "1" }] }
  const pages = Model.mergeLeaguePages([oldPage], [newPage])
  assert.equal(pages.length, 1)
  assert.equal(pages[0].matches[0].homeScore, 4)
  assert.equal(pages[0].standings.length, 1)
})
test("matchStatusText and shortTournamentName", () => {
  assert.equal(Model.matchStatusText({ status: "finished" }), "FT")
  assert.equal(Model.matchStatusText({ status: "cancelled" }), "Postponed")
  assert.equal(Model.matchStatusText({ status: "live", liveTime: "45'" }), "45'")
  assert.equal(Model.shortTournamentName("UEFA Champions League"), "Champions Lg")
  assert.equal(Model.shortTournamentName("Primeira Liga"), "Liga Portugal")
})
test("external and detail URLs reject untrusted schemes and hosts", () => {
  const football = { sport: "football", pageUrl: "/matches/benfica/1" }
  assert.equal(Model.matchExternalUrl(football), "https://www.fotmob.com/matches/benfica/1")
  assert.equal(Model.matchDetailUrl(football), "https://www.fotmob.com/matches/benfica/1")
  assert.equal(Model.matchExternalUrl({ sport: "football", pageUrl: "https://evil.example/x" }), "https://www.fotmob.com")
  assert.equal(Model.matchDetailUrl({ sport: "football", pageUrl: "https://evil.example/x" }), "")
  assert.equal(Model.matchExternalUrl({ sport: "football", pageUrl: "javascript:alert(1)" }), "https://www.fotmob.com")
  assert.equal(Model.matchDetailUrl({ sport: "football", pageUrl: "https://user@www.fotmob.com/x" }), "")
  assert.equal(Model.matchExternalUrl({ sport: "nba", pageUrl: "http://www.espn.com/nba" }), "https://www.espn.com/nba")
  assert.equal(Model.matchExternalUrl({ sport: "nba", pageUrl: "https://www.espn.com/nba" }), "https://www.espn.com/nba")
  // ESPN relative paths must resolve against the sport-scoped base; F1 falls
  // back to its known hosts only because there is no fixed F1 base.
  assert.equal(Model.matchExternalUrl({ sport: "nba", pageUrl: "/nba/team/_/id/13/lakers" }), "https://www.espn.com/nba/nba/team/_/id/13/lakers")
  assert.equal(Model.matchExternalUrl({ sport: "nfl", pageUrl: "/nfl/team/_/id/2/bills" }), "https://www.espn.com/nfl/nfl/team/_/id/2/bills")
  assert.equal(Model.matchExternalUrl({ sport: "f1", pageUrl: "/article/foo" }), "https://www.formula1.com")
  assert.equal(Model.matchExternalUrl({ sport: "f1", pageUrl: "https://en.wikipedia.org/wiki/Race" }), "https://en.wikipedia.org/wiki/Race")
  assert.ok(Model.isTrustedCrestUrl("https://images.fotmob.com/image_resources/logo/teamlogo/9772.png", "football"))
  assert.ok(Model.isTrustedCrestUrl("https://a.espncdn.com/i/teamlogos/nba/500/lal.png", "nba"))
  assert.ok(!Model.isTrustedCrestUrl("https://evil.example/logo.png", "nba"))
})
test("parseMatchTimeMs centralizes invalid-timestamp handling", () => {
  assert.equal(Model.parseMatchTimeMs({ time: "2026-08-22T19:00:00Z" }), Date.parse("2026-08-22T19:00:00Z"))
  assert.ok(isNaN(Model.parseMatchTimeMs({ time: "not-a-date" })))
  assert.ok(isNaN(Model.parseMatchTimeMs({})))
  assert.ok(isNaN(Model.parseMatchTimeMs(null)))
})
test("refreshIntervalOptions is the single source of truth", () => {
  const opts = Model.refreshIntervalOptions()
  assert.equal(opts.length, 6)
  for (const o of opts) {
    const n = parseInt(o.value, 10)
    assert.ok(n >= 5 && n <= 60, "refresh interval out of [5,60]: " + o.value)
  }
})
test("mergeSeenMap drops stale entries and prefers the new snapshot", () => {
  const now = Date.parse("2026-08-22T19:30:00Z")
  const ttl = Model.NOTIFICATION_TTL_MS
  const stale = { old: { seenAt: now - 7 * 3600000, status: "finished" } }
  const fresh = { fresh: { seenAt: now - 60000, status: "live" } }
  const merged = Model.mergeSeenMap(stale, fresh, now, ttl)
  assert.ok(!merged.old)
  assert.deepEqual(merged.fresh, fresh.fresh)
  // Stale entries inside the TTL window are kept; outside they are dropped.
  const justOld = { old: { seenAt: now - 3600000, status: "finished" } }
  assert.ok(Model.mergeSeenMap(justOld, {}, now, ttl).old)
})
test("dictSet and dictDelete return a new object identity", () => {
  // QML bindings watch property identity. A function that mutates the
  // input map would silently leave the binding pointing at the stale
  // object; the audit caught this happening in three places. These
  // helpers must always allocate a fresh map.
  const base = { a: 1, b: 2 }
  const added = Model.dictSet(base, "c", 3)
  assert.notEqual(added, base, "dictSet must return a new map")
  assert.deepEqual(base, { a: 1, b: 2 }, "dictSet must not mutate the input")
  assert.deepEqual(added, { a: 1, b: 2, c: 3 })
  const removed = Model.dictDelete(base, "a")
  assert.notEqual(removed, base, "dictDelete must return a new map")
  assert.deepEqual(base, { a: 1, b: 2 }, "dictDelete must not mutate the input")
  assert.deepEqual(removed, { b: 2 })
})
test("dictSet rejects __proto__ and inherited keys", () => {
  // A user-edited state file could carry "__proto__" or other keys that
  // would otherwise slip into the deduplication map through prototype
  // chain lookups. Verify the explicit hasOwnProperty guard.
  const poisoned = Object.create({ injected: true })
  poisoned.a = 1
  const out = Model.dictSet(poisoned, "b", 2)
  assert.equal(out.injected, undefined, "inherited keys must not be copied")
  assert.deepEqual(out, { a: 1, b: 2 })
})
test("notification diff establishes a baseline without notifying", () => {
  const now = Date.parse("2026-08-22T19:30:00Z")
  const upcoming = { id: "notify-1", sport: "football", status: "upcoming", time: "2026-08-22T19:40:00Z", leagueName: "Primeira Liga", home: { id: "9772", name: "Benfica" }, away: { id: "9773", name: "FC Porto" } }
  const result = Model.diffMatchNotifications([upcoming], {}, { activeSport: "football", favoriteIds: ["9772"], nowMs: now })
  assert.equal(result.notifications.length, 0)
  assert.equal(result.nextSeen["notify-1"].notifiedUpcoming, false)
})
test("notification diff emits kickoff, score and spoiler-safe messages", () => {
  const now = Date.parse("2026-08-22T19:30:00Z")
  const previous = {
    "notify-2": { homeScore: 0, awayScore: 0, status: "upcoming", notifiedUpcoming: false, seenAt: now - 60000 }
  }
  const live = { id: "notify-2", sport: "football", status: "live", time: "2026-08-22T19:00:00Z", leagueName: "Primeira Liga", liveTime: "31'", homeScore: 1, awayScore: 0, scoreText: "1–0", home: { id: "9772", name: "Benfica" }, away: { id: "9773", name: "FC Porto" } }
  const result = Model.diffMatchNotifications([live], previous, { activeSport: "football", favoriteIds: ["9772"], antiSpoiler: true, nowMs: now })
  assert.deepEqual(result.notifications.map(n => n.kind), ["started", "score"])
  assert.match(result.notifications[1].body, /^Benfica scored/)
  assert.ok(!result.notifications[1].body.includes("1–0"))
  assert.equal(previous["notify-2"].status, "upcoming")
})
test("notification history stays frozen while disabled", () => {
  const previous = { game: { status: "upcoming", homeScore: 0, awayScore: 0, seenAt: 0 } }
  const result = Model.diffMatchNotifications([], previous, { enabled: false, nowMs: Date.now() })
  assert.strictEqual(result.nextSeen, previous)
})
test("notification diff emits one upcoming warning, handles F1, and prunes old history", () => {
  const now = Date.parse("2026-08-22T19:30:00Z")
  const oldId = "old"
  const previous = {
    old: { homeScore: 0, awayScore: 0, status: "finished", seenAt: now - 7 * 3600000 },
    "notify-3": { homeScore: 0, awayScore: 0, status: "upcoming", notifiedUpcoming: false, seenAt: now - 60000 },
    "notify-f1": { homeScore: 0, awayScore: 0, status: "upcoming", notifiedUpcoming: false, seenAt: now - 60000 }
  }
  const upcoming = { id: "notify-3", sport: "football", status: "upcoming", time: "2026-08-22T19:40:00Z", leagueName: "Premier League", home: { id: "9825", name: "Arsenal" }, away: { id: "9826", name: "Crystal Palace" } }
  const f1 = { id: "notify-f1", sport: "f1", status: "live", time: "2026-08-22T19:00:00Z", raceName: "Mock Grand Prix", locality: "Lisboa", home: { id: "f1-gp", name: "Mock Grand Prix" }, away: { id: "f1-circuit", name: "Circuit" } }
  const first = Model.diffMatchNotifications([upcoming, f1], previous, { activeSport: "f1", favoriteIds: [], nowMs: now })
  assert.equal(first.notifications.filter(n => n.kind === "upcoming").length, 1)
  assert.equal(first.notifications.filter(n => n.kind === "started").length, 1)
  assert.ok(!first.nextSeen[oldId])
  const second = Model.diffMatchNotifications([upcoming], first.nextSeen, { activeSport: "football", favoriteIds: ["9825"], nowMs: now + 60000 })
  assert.equal(second.notifications.length, 0)
  const stale = { stale: { status: "upcoming", homeScore: 0, awayScore: 0, notifiedUpcoming: false, seenAt: now - 7 * 3600000 } }
  const reappeared = { ...upcoming, id: "stale", time: "2026-08-22T19:40:00Z", home: { id: "9825", name: "Arsenal" }, away: { id: "9826", name: "Crystal Palace" } }
  const baseline = Model.diffMatchNotifications([reappeared], stale, { activeSport: "football", favoriteIds: ["9825"], nowMs: now })
  assert.equal(baseline.notifications.length, 0)
})
test("interpolateLiveTime ticks the clock forward with a stoppage cap", () => {
  const now = Date.now()
  const m = { status: "live", liveTime: "13’", sport: "football" }
  // fresh data → untouched
  assert.equal(Model.interpolateLiveTime(m, now, now - 20000), "13’")
  // 2 min stale → ticks to 15 (FotMob wraps clocks in invisible bi-di marks)
  const lrm = "\u200e"
  const tick = (n) => lrm + n + "\u2019" + lrm
  const fotmob = { status: "live", liveTime: tick(13), sport: "football" }
  assert.equal(Model.interpolateLiveTime(fotmob, now, now - 2.5 * 60000), tick(15))
  assert.equal(Model.interpolateLiveTime(m, now, now - 2.5 * 60000), tick(15))
  // very stale → capped at +4
  assert.equal(Model.interpolateLiveTime(m, now, now - 40 * 60000), tick(17))
  // non-numeric clocks (HT, stoppage, quarters) are never guessed
  for (const t of ["HT", "45+2’", "8:44", "Q4 - 8:44", "Pen", "LIVE"]) {
    assert.equal(Model.interpolateLiveTime({ status: "live", liveTime: t, sport: "football" }, now, now - 30 * 60000), t)
  }
  // non-football sports are provider-true only
  const nba = { status: "live", liveTime: "8:44", sport: "nba" }
  assert.equal(Model.interpolateLiveTime(nba, now, now - 30 * 60000), "8:44")
  // non-live matches pass through untouched
  assert.equal(Model.interpolateLiveTime({ status: "finished", sport: "football" }, now, now - 60000), "")
})

// ---------------------------------------------------------------- mock mode
test("mockRound football simulates a full lifecycle", () => {
  const t0 = Date.now()
  const MIN = 60000
  const { matches } = Model.mockRound("football", t0)
  const byId = Object.fromEntries(matches.map(m => [m.id, m]))
  // one match live at launch, one kicking off in ~12 min, one finished, one tomorrow
  assert.equal(byId["mock-fb-1"].status, "live")
  assert.match(byId["mock-fb-1"].liveTime, /^\u200e\d{1,2}\u2019\u200e$/)
  assert.equal(byId["mock-fb-2"].status, "upcoming")
  assert.ok(Date.parse(byId["mock-fb-2"].time) - t0 > 10 * MIN && Date.parse(byId["mock-fb-2"].time) - t0 < 15 * MIN,
    "upcoming kickoff should sit inside the 15-min pre-match notification window")
  assert.equal(byId["mock-fb-3"].status, "finished")
  assert.equal(byId["mock-fb-4"].status, "upcoming")
  // evolution: 40 min later the live match has progressed and match #2 is LIVE with a scripted goal
  const later = Model.mockRound("football", t0 + 40 * MIN)
  const laterById = Object.fromEntries(later.matches.map(m => [m.id, m]))
  assert.ok(["live", "finished"].includes(laterById["mock-fb-1"].status), "first match should progress")
  assert.equal(laterById["mock-fb-2"].status, "live")
  assert.ok(laterById["mock-fb-2"].homeScore + laterById["mock-fb-2"].awayScore > 0, "scripted goal should have landed")
})
test("mockRound covers every sport with sane shapes", () => {
  for (const sport of ["football", "nba", "f1", "nfl", "mlb", "nhl"]) {
    const { matches, standings } = Model.mockRound(sport)
    assert.ok(matches.length > 0, sport + " has no matches")
    assert.ok(matches.some(m => m.status === "live"), sport + " should always have something live")
    assert.ok(Object.keys(standings).length > 0, sport + " should have standings")
    for (const m of matches) {
      assert.ok(m.id && m.home.name && m.away.name && m.time, sport + " match malformed")
      assert.equal(m.sport, sport)
    }
  }
})

// ---------------------------------------------------------------- catalogs
console.log("catalogs")
test("US sport catalogs have unique ids and full team counts", () => {
  for (const [list, count] of [[Model.nbaTeams, 30], [Model.nflTeams, 32], [Model.mlbTeams, 30], [Model.nhlTeams, 32]]) {
    assert.equal(list.length, count, list === Model.nbaTeams ? "nba" : list === Model.nflTeams ? "nfl" : list === Model.mlbTeams ? "mlb" : "nhl")
    assert.equal(new Set(list.map(t => t.value)).size, count)
  }
})
test("NHL catalog uses verified ESPN ids", () => {
  const byLabel = Object.fromEntries(Model.nhlTeams.map(t => [t.label, t.value]))
  assert.equal(byLabel["Toronto Maple Leafs"], "21")
  assert.equal(byLabel["Minnesota Wild"], "30")
  assert.equal(byLabel["Utah Mammoth"], "129764")
  assert.equal(byLabel["Seattle Kraken"], "124292")
  assert.equal(byLabel["Vegas Golden Knights"], "37")
})
test("MLB catalog uses verified ESPN ids", () => {
  const byLabel = Object.fromEntries(Model.mlbTeams.map(t => [t.label, t.value]))
  assert.equal(byLabel["New York Yankees"], "10")
  assert.equal(byLabel["Toronto Blue Jays"], "14")
  assert.equal(byLabel["Athletics"], "11")
})
test("F1 catalog matches Jolpica driverIds and has 11 constructors", () => {
  const values = Model.f1Drivers.map(d => d.value)
  assert.ok(values.includes("max_verstappen"))
  assert.ok(!values.includes("verstappen"))
  assert.ok(!values.includes("doohan"))
  for (const id of ["cadillac", "audi", "arvid_lindblad", "colapinto", "bottas", "perez"]) {
    assert.ok(values.includes(id), "missing " + id)
  }
  assert.equal(Model.f1Drivers.filter(d => d.description.startsWith("Constructor")).length, 11)
})
test("teamOptionsForSport returns instant catalogs per sport", () => {
  assert.equal(Model.teamOptionsForSport("nba", []).length, 30)
  assert.equal(Model.teamOptionsForSport("f1", []).length, Model.f1Drivers.length)
  assert.ok(Model.teamOptionsForSport("football", sampleMatches).length >= 3)
})

console.log(`\n${passed} tests passed ✓`)
