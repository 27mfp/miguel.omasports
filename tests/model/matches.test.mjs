// Focused model tests: match selection, grouping, merging, live clock.
// Run directly or through tests/sportsmodel.test.mjs (all modules).
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { Model, test } from "./harness.mjs"

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
  assert.equal(Model.matchesForTeam(sampleMatches, [], "football").length, 0)
  assert.equal(Model.matchesForTeam(sampleMatches, [], "f1").length, 0)
  assert.equal(Model.matchesForTeam(sampleMatches, "whatever", "f1").length, 0)
})
test("matchesForTeam filters F1 races by driver or constructor id", () => {
  const races = [
    { id: "r1", sport: "f1", driverId: "leclerc", constructorId: "ferrari", home: { id: "gp1", name: "Monaco GP" }, away: { id: "c1", name: "Monaco" } },
    { id: "r2", sport: "f1", driverId: "norris", constructorId: "mclaren", home: { id: "gp2", name: "British GP" }, away: { id: "c2", name: "Silverstone" } }
  ]
  assert.equal(Model.matchesForTeam(races, "leclerc", "f1").length, 1)
  assert.equal(Model.matchesForTeam(races, "ferrari", "f1")[0].id, "r1")
  assert.equal(Model.matchesForTeam(races, "unknown", "f1").length, 0)
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
  assert.equal(Model.matchOutcomeForTeams(sampleMatches[2], ["9772"]), "win")
})
test("generalMatchOutcome derives decisive winner or draw", () => {
  assert.equal(Model.generalMatchOutcome(sampleMatches[2]), "away")
  const homeWin = { ...sampleMatches[2], homeScore: "3", awayScore: "1" }
  assert.equal(Model.generalMatchOutcome(homeWin), "home")
  const drawn = { ...sampleMatches[2], homeScore: "2", awayScore: "2" }
  assert.equal(Model.generalMatchOutcome(drawn), "draw")
  assert.equal(Model.generalMatchOutcome(sampleMatches[0]), "")
})
test("teamLiveState computes leading/tied/trailing for live matches", () => {
  const liveMatch = { ...sampleMatches[1], status: "live", homeScore: 2, awayScore: 1 }
  assert.equal(Model.teamLiveState(liveMatch, "9772"), "leading")
  assert.equal(Model.teamLiveState(liveMatch, "z1"), "trailing")
  assert.equal(Model.matchLiveStateForTeams(liveMatch, ["9772"]), "leading")
  assert.equal(Model.matchLiveStateForTeams(liveMatch, ["z1"]), "trailing")

  const liveTied = { ...liveMatch, homeScore: 1, awayScore: 1 }
  assert.equal(Model.teamLiveState(liveTied, "9772"), "tied")
  assert.equal(Model.matchLiveStateForTeams(liveTied, ["9772"]), "tied")
  assert.equal(Model.matchLiveStateForTeams(sampleMatches[0], ["9772"]), "")
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
test("liveMatches uses the supplied clock for deterministic football previews", () => {
  const now = Date.parse("2026-10-08T18:00:00Z")
  const match = { id: "mock-live", sport: "football", status: "live", time: new Date(now - 25 * 60000).toISOString() }
  assert.equal(Model.liveMatches([match], {}, now).length, 1)
  assert.equal(Model.liveMatches([match], {}, now + 3 * 3600000).length, 0)
  assert.equal(Model.liveMatches([match], { "mock-live": { finished: true } }, now).length, 0)
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

  // Live match clock monotonicity: a stale team page SSR cache with 1'
  // must never overwrite an already advanced live match clock (e.g. 47' or HT)
  const advancedMatch = { id: "live1", status: "live", liveTime: "47’", homeScore: 0, awayScore: 2, scoreText: "0–2" }
  const staleSsrMatch = { id: "live1", status: "live", liveTime: "1’", homeScore: 0, awayScore: 0, scoreText: "0–0" }
  const mergedLive = Model.mergeMatchUpdates([advancedMatch], [staleSsrMatch])
  assert.equal(mergedLive[0].liveTime, "47’", "stale 1' SSR clock regressed live time")
  assert.equal(mergedLive[0].scoreText, "0–2", "stale score regressed live score")

  // Finished match preservation: once a match finishes, an incoming stale poll
  // reporting it as live or upcoming must NEVER revert it back to live
  const finishedMatch = { id: "ft1", status: "finished", statusReason: "FT", scoreText: "2–1", homeScore: 2, awayScore: 1, liveTime: "" }
  const staleLiveMatch = { id: "ft1", status: "live", liveTime: "75’", scoreText: "1–1", homeScore: 1, awayScore: 1 }
  const mergedFinished = Model.mergeMatchUpdates([finishedMatch], [staleLiveMatch])
  assert.equal(mergedFinished[0].status, "finished", "finished match reverted to live")
  assert.equal(mergedFinished[0].statusReason, "FT", "statusReason lost")
  assert.equal(mergedFinished[0].liveTime, "", "liveTime restored on finished match")
  assert.equal(mergedFinished[0].scoreText, "2–1", "score regressed on finished match")

  const oldPage = { league: { id: "47" }, matches: [sampleMatches[1]], standings: [] }
  const newPage = { league: { id: "47" }, matches: [updated], standings: [{ pos: "1" }] }
  const pages = Model.mergeLeaguePages([oldPage], [newPage])
  assert.equal(pages.length, 1)
  assert.equal(pages[0].matches[0].homeScore, 4)
  assert.equal(pages[0].standings.length, 1)
})
test("reconcileMatchDetails transitions FT, AET, PEN and enforces wall-clock cutoff", () => {
  const liveMatch = { id: "m1", status: "live", liveTime: "75’", scoreText: "2–2", sport: "football" }
  const detailsFT = { m1: { finished: true, reason: "FT", statusLong: "Full-Time" } }
  const rec1 = Model.reconcileMatchDetails([liveMatch], detailsFT)
  assert.equal(rec1[0].status, "finished")
  assert.equal(rec1[0].statusReason, "FT")
  assert.equal(rec1[0].liveTime, "")

  // Extra time / penalties
  const liveCup = { id: "m2", status: "live", liveTime: "120’", scoreText: "1–1", sport: "football" }
  const detailsPEN = { m2: { finished: true, reason: "PEN", statusLong: "Penalties" } }
  const rec2 = Model.reconcileMatchDetails([liveCup], detailsPEN)
  assert.equal(rec2[0].status, "finished")
  assert.equal(rec2[0].statusReason, "PEN")

  // Wall-clock cutoff: match kicked off 180 minutes ago
  const oldKickoff = new Date(Date.now() - 180 * 60 * 1000).toISOString()
  const ancientLive = { id: "m3", status: "live", liveTime: "80’", scoreText: "0–0", sport: "football", time: oldKickoff }
  const rec3 = Model.reconcileMatchDetails([ancientLive], {})
  assert.equal(rec3[0].status, "finished")
  assert.equal(rec3[0].statusReason, "FT")
  assert.equal(rec3[0].liveTime, "")
})
test("liveMatches excludes matches past wall-clock cutoff and respects AET/PEN", () => {
  const now = Date.now()
  const oldKickoff = new Date(now - 180 * 60 * 1000).toISOString()
  const freshKickoff = new Date(now - 30 * 60 * 1000).toISOString()
  const stale = { id: "s1", status: "live", time: oldKickoff, sport: "football" }
  const active = { id: "a1", status: "live", time: freshKickoff, sport: "football" }
  const pen = { id: "p1", status: "live", time: freshKickoff, sport: "football" }

  const details = { p1: { reason: "PEN", finished: true } }
  const live = Model.liveMatches([stale, active, pen], details)
  assert.equal(live.length, 1)
  assert.equal(live[0].id, "a1")
})
test("extractPageProps supports both HTML Next.js scripts and direct JSON", () => {
  const html = '<script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{"details":{"name":"EPL"}}}}</script>'
  assert.equal(Model.extractPageProps(html).details.name, "EPL")

  const jsonStr = JSON.stringify({ details: { name: "La Liga" } })
  assert.equal(Model.extractPageProps(jsonStr).details.name, "La Liga")

  const jsonObj = { details: { name: "Serie A" } }
  assert.equal(Model.extractPageProps(jsonObj).details.name, "Serie A")
})
test("matchStatusText and shortTournamentName", () => {
  assert.equal(Model.matchStatusText({ status: "finished" }), "FT")
  assert.equal(Model.matchStatusText({ status: "cancelled" }), "Cancelled")
  assert.equal(Model.matchStatusText({ status: "cancelled", statusReason: "Postponed" }), "Postponed")
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
  // very stale → capped at +8 (long stoppage windows used to be capped at +4,
  // which let the broadcast clock visibly stall on injuries/VAR/goal scrambles
  // even when the provider clock was simply late).
  // stoppage boundary caps: 43' + 4m drift caps at 45', 88' + 5m drift caps at 90'
  assert.equal(Model.interpolateLiveTime({ status: "live", liveTime: "43’", sport: "football" }, now, now - 4 * 60000), tick(45))
  assert.equal(Model.interpolateLiveTime({ status: "live", liveTime: "88’", sport: "football" }, now, now - 5 * 60000), tick(90))
  // non-numeric clocks (HT, stoppage, quarters) are never guessed
  for (const t of ["HT", "45+2’", "8:44", "Q4 - 8:44", "Pen", "LIVE"]) {
    assert.equal(Model.interpolateLiveTime({ status: "live", liveTime: t, sport: "football" }, now, now - 30 * 60000), t)
  }
  // non-football sports are provider-true only
  const nba = { status: "live", liveTime: "8:44", sport: "nba" }
  assert.equal(Model.interpolateLiveTime(nba, now, now - 30 * 60000), "8:44")
  // kickoff wall-clock sanity guard: when provider serves frozen 1' for a match that started 80m ago
  const staleLiveMatch = { status: "live", liveTime: "1’", sport: "football", time: new Date(now - 80 * 60000).toISOString() }
  assert.equal(Model.interpolateLiveTime(staleLiveMatch, now, now), tick(65), "stale 1' SSR clock was not corrected from kickoff")
  const halftimeMatch = { status: "live", liveTime: "1’", sport: "football", time: new Date(now - 50 * 60000).toISOString() }
  assert.equal(Model.interpolateLiveTime(halftimeMatch, now, now), "HT", "halftime match was not corrected to HT")
  const genericLive = { status: "live", liveTime: "LIVE", sport: "football", time: new Date(now - 30 * 60000).toISOString() }
  assert.equal(Model.interpolateLiveTime(genericLive, now, now), tick(30), "generic LIVE was not given elapsed minute")

  // non-live matches pass through untouched
  assert.equal(Model.interpolateLiveTime({ status: "finished", sport: "football" }, now, now - 60000), "")
})

test("interpolateLiveTime strictly enforces monotonic non-decreasing time across polls", () => {
  Model.resetLiveClockCache()
  const baseNow = Date.parse("2026-09-05T16:00:00Z")
  const match = { id: "live-monotonic-1", status: "live", liveTime: "78’", sport: "football" }

  // Initial poll: returns 78'
  assert.equal(Model.cleanLiveTime(Model.interpolateLiveTime(match, baseNow, baseNow)), "78’")

  // 65 seconds pass: drifts to 79'
  assert.equal(Model.cleanLiveTime(Model.interpolateLiveTime(match, baseNow + 65000, baseNow)), "79’")

  // A fresh background poll completes at +70s, but provider edge cache still served 78'
  // Crucial test: displayed minute must NEVER regress back to 78'
  assert.equal(Model.cleanLiveTime(Model.interpolateLiveTime(match, baseNow + 70000, baseNow + 70000)), "79’")

  // Later poll at +130s returns 80' from provider: advances cleanly to 80'
  const match80 = { id: "live-monotonic-1", status: "live", liveTime: "80’", sport: "football" }
  assert.equal(Model.cleanLiveTime(Model.interpolateLiveTime(match80, baseNow + 130000, baseNow + 130000)), "80’")

  // Match finishes: cache entry is pruned and live clock returns finished time
  const finished = { id: "live-monotonic-1", status: "finished", liveTime: "FT", sport: "football" }
  assert.equal(Model.interpolateLiveTime(finished, baseNow + 200000, baseNow + 200000), "FT")
})

test("formatLiveClock provides rich match phase and kickoff context", () => {
  Model.resetLiveClockCache()
  const now = Date.parse("2026-09-05T16:34:00Z")
  const liveMatch = {
    id: "live-phase-1",
    status: "live",
    liveTime: "34’",
    sport: "football",
    time: "2026-09-05T16:00:00Z"
  }
  const clock = Model.formatLiveClock(liveMatch, now, now)
  assert.equal(clock.minuteText, "34’")
  assert.equal(clock.phase, "1st Half")
  assert.equal(clock.fullLabel, "1st Half · 34’")
  assert.match(clock.kickoffText, /^Started \d{2}:\d{2}$/)

  // Half time match
  const htMatch = {
    id: "live-phase-2",
    status: "live",
    liveTime: "HT",
    sport: "football",
    time: "2026-09-05T15:00:00Z"
  }
  const htClock = Model.formatLiveClock(htMatch, now, now)
  assert.equal(htClock.minuteText, "HT")
  assert.equal(htClock.phase, "Half Time")
  assert.equal(htClock.fullLabel, "Half Time · HT")

  // US sports phases
  const nbaMatch = { status: "live", liveTime: "8:44 - Q2", sport: "nba" }
  const nbaClock = Model.formatLiveClock(nbaMatch, now, now)
  assert.equal(nbaClock.minuteText, "8:44 - Q2")
  assert.equal(nbaClock.phase, "2nd Quarter")
})
