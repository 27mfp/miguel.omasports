// Focused model tests: helpers, state, catalogs, mock mode.
// Run directly or through tests/sportsmodel.test.mjs (all modules).
import assert from "node:assert/strict"
import { readFixture } from "../fixture-io.mjs"
import { Model, test } from "./harness.mjs"
const sampleMatches = [
  { id: "a", leagueId: "61", status: "upcoming", time: "2100-01-03T10:00:00Z", home: { id: "x1", name: "Alpha", shortName: "Alpha" }, away: { id: "y1", name: "Beta", shortName: "Beta" } },
  { id: "b", leagueId: "47", status: "live", time: "2100-01-01T10:00:00Z", home: { id: "9772", name: "Benfica", shortName: "Benfica" }, away: { id: "z1", name: "Gamma", shortName: "Gamma" } },
  { id: "c", leagueId: "47", status: "finished", time: "2026-01-01T10:00:00Z", homeScore: 0, awayScore: 2, home: { id: "w1", name: "Delta", shortName: "Delta" }, away: { id: "9772", name: "Benfica", shortName: "Benfica" } }
]
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
test("polling constants and clampRefreshMinutes", () => {
  assert.equal(Model.MAX_ROUND_RETRIES, 2)
  assert.equal(Model.RETRY_DELAY_ESPN_MS, 15000)
  assert.equal(Model.RETRY_DELAY_FOTMOB_F1_MS, 20000)
  assert.equal(Model.RETRY_DELAY_MS, Model.RETRY_DELAY_ESPN_MS)
  assert.equal(Model.F1_RESULTS_REFRESH_MS, 300000)
  assert.equal(Model.MIN_REFRESH_MINUTES, 5)
  assert.equal(Model.MAX_REFRESH_MINUTES, 60)
  assert.deepEqual(Model.REFRESH_OPTIONS, [5, 10, 15, 30, 45, 60])
  assert.equal(Model.clampRefreshMinutes(999), 60)
  assert.equal(Model.clampRefreshMinutes(1), 5)
  assert.equal(Model.clampRefreshMinutes("15"), 15)
  assert.equal(Model.clampRefreshMinutes("nope"), 15)
})
test("safeHome falls back when HOME is unset", () => {
  const home = Model.safeHome()
  assert.equal(home, process.env.HOME || "/var/tmp")
  assert.ok(home.length > 0)
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

// ---------------------------------------------------------------- monogram text
console.log("monogramText")
test("prefers abbreviation up to 3 chars uppercase", () => {
  assert.equal(Model.monogramText("LAL", "Los Angeles Lakers"), "LAL")
  assert.equal(Model.monogramText("gsw", "Golden State Warriors"), "GSW")
  assert.equal(Model.monogramText("ARSENAL", "Arsenal"), "ARS")
})
test("falls back to initials for multi-word club names", () => {
  assert.equal(Model.monogramText("", "Real Madrid"), "RM")
  assert.equal(Model.monogramText("", "FC Porto"), "FP")
  assert.equal(Model.monogramText("", "Sporting CP"), "SC")
})
test("falls back to first 2 letters for single-word names or question mark if empty", () => {
  assert.equal(Model.monogramText("", "Benfica"), "BE")
  assert.equal(Model.monogramText("", "Arsenal"), "AR")
  assert.equal(Model.monogramText("", ""), "?")
  assert.equal(Model.monogramText(null, undefined), "?")
})

// ---------------------------------------------------------------- espn dates
console.log("espnDateList / mergeEspnScoreboardPayloads / formatKickoff")
test("espnDateList yields consecutive single YYYYMMDD days (ESPN rejects ranges)", () => {
  const days = Model.espnDateList(1, 3)
  assert.equal(days.length, 5)
  for (const d of days) assert.match(d, /^\d{8}$/)
  const ms = days.map(d => Date.UTC(+d.slice(0, 4), +d.slice(4, 6) - 1, +d.slice(6, 8)))
  for (let i = 1; i < ms.length; i++) assert.equal(ms[i] - ms[i - 1], 86400000)
})
test("espnDateList crosses month, year and DST boundaries without gaps", () => {
  assert.deepEqual(Model.espnDateList(1, 3, new Date(2026, 8, 29, 23, 30).getTime()),
    ["20260928", "20260929", "20260930", "20261001", "20261002"])
  assert.deepEqual(Model.espnDateList(1, 1, new Date(2026, 11, 31, 0, 5).getTime()),
    ["20261230", "20261231", "20270101"])
  // Around both DST switches each local day appears exactly once
  for (const at of [new Date(2026, 2, 8, 1).getTime(), new Date(2026, 10, 1, 1).getTime(), new Date(2026, 2, 29, 1).getTime()]) {
    const days = Model.espnDateList(2, 2, at)
    assert.equal(new Set(days).size, 5)
  }
})
test("mergeEspnScoreboardPayloads de-dupes by id, prefers later payload, sorts by date", () => {
  const ev = (id, date, state) => ({ id, date, status: { type: { state } } })
  const merged = Model.mergeEspnScoreboardPayloads([
    { leagues: [{ name: "Major League Baseball" }], events: [ev("2", "2026-09-30T18:00Z", "pre"), ev("1", "2026-09-29T23:00Z", "in")] },
    { code: 400, message: "Failed to get events endpoint." },
    { leagues: [{ name: "other" }], events: [ev("1", "2026-09-29T23:00Z", "post"), ev("3", "2026-10-01T18:00Z", "pre")] }
  ])
  assert.deepEqual(merged.events.map(e => e.id), ["1", "2", "3"])
  assert.equal(merged.events[0].status.type.state, "post")
  assert.equal(merged.leagues[0].name, "Major League Baseball")
  assert.ok(Model.isEspnScoreboardPayload(merged))
  assert.deepEqual(Model.mergeEspnScoreboardPayloads([]).events, [])
})
test("merged per-day payloads parse the same games as the captured window", () => {
  const board = JSON.parse(readFixture("espn-mlb-scoreboard.json"))
  const half = Math.floor(board.events.length / 2)
  // Overlapping split: the boundary event appears in both "days"
  const merged = Model.mergeEspnScoreboardPayloads([
    { leagues: board.leagues, events: board.events.slice(0, half + 1) },
    { leagues: board.leagues, events: board.events.slice(half) }
  ])
  const ids = m => m.map(x => x.id).sort()
  assert.deepEqual(ids(Model.parseEspnScoreboard(JSON.stringify(merged), "mlb", "MLB")),
                   ids(Model.parseEspnScoreboard(JSON.stringify(board), "mlb", "MLB")))
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
    selectedTeamIds: ["9772"], selectedTeamName: "Benfica",
    standingsLeagueId: "61", tabName: "live" })
  assert.equal(JSON.stringify(Model.parseState(JSON.stringify(saved2))), JSON.stringify(saved2))
  assert.equal(saved2.football.tab, "live")
  assert.deepEqual(saved2.football.leagueIds, ["61"])
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


test("normalizeTab handles settings and preferences", () => {
  assert.equal(Model.normalizeTab("settings"), "settings")
  assert.equal(Model.normalizeTab("preferences"), "settings")
  assert.equal(Model.normalizeTab("SETTINGS"), "settings")
  assert.equal(Model.normalizeTab("fixtures"), "fixtures")
  assert.equal(Model.normalizeTab("live"), "live")
  assert.equal(Model.normalizeTab("standings"), "standings")
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
