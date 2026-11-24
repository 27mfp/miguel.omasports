// Focused model tests: ESPN scoreboards, standings, broadcast, leaders, news.
// Run directly or through tests/sportsmodel.test.mjs (all modules).
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { Model, test } from "./harness.mjs"

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
test("ESPN exceptional statuses never fabricate a completed result", () => {
  for (const name of ["STATUS_POSTPONED", "STATUS_CANCELED", "STATUS_DELAYED", "STATUS_SUSPENDED"]) {
    const board = JSON.parse(espnScoreboard)
    board.events[0].status = { type: { name, state: "post", shortDetail: name } }
    const match = Model.parseEspnScoreboard(JSON.stringify(board), "mlb", "MLB")[0]
    assert.notEqual(match.status, "finished", name)
    assert.equal(match.scoreText, "", name)
    assert.equal(match.statusReason, name)
  }
})
test("ESPN null competitors and malformed linescores cannot abort the slate", () => {
  const board = JSON.parse(espnScoreboard)
  board.events[0].competitions[0].competitors.push(null)
  board.events[0].competitions[0].competitors[0].linescores = [null, {}, { value: 0 }, { value: 2 }]
  const matches = Model.parseEspnScoreboard(JSON.stringify(board), "mlb", "MLB")
  assert.equal(matches.length, 2)
  assert.ok(Object.values(matches[0].linescores).some(lines => JSON.stringify(lines) === "[null,null,0,2]"))
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
test("ESPN standings separate games behind, total difference, and percentage", () => {
  const raw = JSON.stringify({ children: [{ name: "American League", standings: { entries: [{
    team: { id: "1", displayName: "Leader" },
    stats: [
      { name: "wins", displayValue: "98" }, { name: "losses", displayValue: "64" },
      { name: "points", displayValue: "17.0" },
      { name: "gamesBehind", value: 0, displayValue: "-" },
      { name: "differential", displayValue: "+0.5" },
      { name: "pointDifferential", displayValue: "+81" },
      { name: "winPercent", displayValue: ".605" },
      { name: "playoffSeed", displayValue: "1" }
    ]
  }] } }] })
  const [row] = Model.parseEspnStandings(raw, "mlb")["American League"]
  assert.equal(row.gb, "-")
  assert.equal(row.gd, "+81")
  assert.equal(row.pct, ".605")
})
test("ESPN seed order preserves division winners ahead of wild cards", () => {
  const data = JSON.parse(espnStandings([["National League", [4, 3]]]))
  data.children[0].standings.entries[0].stats[0].displayValue = "95"
  data.children[0].standings.entries[1].stats[0].displayValue = "91"
  const rows = Model.parseEspnStandings(JSON.stringify(data), "mlb")["National League"]
  assert.deepEqual(rows.map(row => row.pos), ["3", "4"])
  assert.deepEqual(rows.map(row => row.wins), [91, 95])
})
test("NFL fallback percentage counts ties as half a win", () => {
  const data = JSON.parse(espnStandings([["AFC", [1]]]))
  data.children[0].standings.entries[0].stats.push({ name: "ties", displayValue: "1" })
  const [row] = Model.parseEspnStandings(JSON.stringify(data), "nfl")["AFC"]
  assert.equal(row.pct, ".656")
  assert.equal(row.gb, "–", "missing games behind must not use points or wins")
})
test("standings equality notices percentage and games-behind updates", () => {
  const row = Model.parseEspnStandings(espnStandings([["AFC", [1]]]), "nfl")["AFC"][0]
  assert.equal(Model.sameRows([row], [{ ...row, gb: "2.0" }]), false)
  assert.equal(Model.sameRows([row], [{ ...row, pct: ".700" }]), false)
})


test("parseEspnBroadcast prefers national market and falls back gracefully", () => {
  const compNational = {
    broadcasts: [
      { market: "home", names: ["Bally Sports"] },
      { market: "national", names: ["NBC", "Peacock"] }
    ]
  }
  assert.equal(Model.parseEspnBroadcast(compNational), "NBC")

  const compLocal = {
    broadcasts: [
      { market: "home", names: ["YES Network"] }
    ]
  }
  assert.equal(Model.parseEspnBroadcast(compLocal), "YES Network")
  assert.equal(Model.parseEspnBroadcast({}), "")
  assert.equal(Model.parseEspnBroadcast(null), "")
})

test("parseEspnGameLeaders extracts category and top athlete values", () => {
  const comp = {
    leaders: [
      {
        shortDisplayName: "PASS",
        leaders: [
          {
            displayValue: "19/31, 181 YDS",
            athlete: { shortName: "S. Bennett IV", headshot: "https://example.com/sb.png" }
          }
        ]
      },
      {
        shortDisplayName: "RUSH",
        leaders: [
          {
            displayValue: "12 CAR, 68 YDS, 1 TD",
            athlete: { shortName: "J. Hunter", headshot: "https://example.com/jh.png" }
          }
        ]
      }
    ]
  }
  const leaders = Model.parseEspnGameLeaders(comp)
  assert.equal(leaders.length, 2)
  assert.equal(leaders[0].category, "PASS")
  assert.equal(leaders[0].player, "S. Bennett IV")
  assert.equal(leaders[0].displayValue, "19/31, 181 YDS")
  assert.equal(leaders[1].category, "RUSH")
  assert.equal(leaders[1].player, "J. Hunter")
  assert.deepEqual(Model.parseEspnGameLeaders(null), [])
})

test("parseEspnNews extracts top articles with headline and url", () => {
  const raw = {
    articles: [
      {
        headline: "Free Agency Buzz",
        description: "Latest trade rumors",
        published: "2026-09-04T12:00:00Z",
        links: { web: { href: "https://www.espn.com/nba/story/123" } },
        images: [{ url: "https://a.espncdn.com/photo/123.jpg" }]
      }
    ]
  }
  const news = Model.parseEspnNews(raw)
  assert.equal(news.length, 1)
  assert.equal(news[0].headline, "Free Agency Buzz")
  assert.equal(news[0].url, "https://www.espn.com/nba/story/123")
  const untrusted = Model.parseEspnNews({
    articles: [{ headline: "Untrusted", links: { web: { href: "https://evil.example/story" } } }]
  })
  assert.equal(untrusted[0].url, "")
  assert.deepEqual(Model.parseEspnNews("invalid json"), [])
})
