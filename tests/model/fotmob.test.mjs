// Focused model tests: FotMob match, standings, events, form, stats.
// Run directly or through tests/sportsmodel.test.mjs (all modules).
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { Model, test } from "./harness.mjs"

// ---------------------------------------------------------------- FotMob
console.log("FotMob parsers")
test("parseLeaguePage accepts the crossorigin attribute on the Next.js payload", () => {
  const data = { props: { pageProps: { details: { id: 47, name: "Premier League" } } } }
  const html = `<script id="__NEXT_DATA__" type="application/json" crossorigin="anonymous">${JSON.stringify(data)}</script>`
  assert.equal(Model.parseLeaguePage(html, "47")?.league.name, "Premier League")
})

test("Next.js payload lookup uses actual script attributes regardless of order", () => {
  const decoy = `<script type="application/json" data-note=' id="__NEXT_DATA__" '>{}</script>`
  const data = { props: { pageProps: { header: { status: { reason: { short: "FT" } } } } } }
  const script = `<script type='application/json' data-note="a > b" id='__NEXT_DATA__'>${JSON.stringify(data)}</script>`
  assert.equal(Model.parseDetails(decoy + script)?.reason, "FT")
})

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


test("parseFotmobEvents extracts goals with assists and red cards", () => {
  const rawEvents = [
    {
      type: "Goal",
      time: 15,
      nameStr: "Kai Havertz",
      isHome: true,
      assistInput: "Riccardo Calafiori"
    },
    {
      type: "Goal",
      time: 82,
      nameStr: "Lewis Dunk",
      isHome: false,
      ownGoal: true
    },
    {
      type: "Card",
      time: 68,
      card: "Red",
      nameStr: "Lewis Dunk",
      isHome: false
    },
    {
      type: "Card",
      time: 34,
      card: "Yellow",
      nameStr: "Gabriel",
      isHome: true
    }
  ]
  const parsed = Model.parseFotmobEvents(rawEvents)
  assert.equal(parsed.goals.length, 2)
  assert.equal(parsed.goals[0].player, "Kai Havertz")
  assert.equal(parsed.goals[0].minute, "15'")
  assert.equal(parsed.goals[0].assist, "Riccardo Calafiori")
  assert.equal(parsed.goals[0].isHome, true)
  assert.equal(parsed.goals[1].player, "Lewis Dunk (OG)")
  assert.equal(parsed.goals[1].isHome, false)
  assert.equal(parsed.redCards.length, 1)
  assert.equal(parsed.redCards[0].player, "Lewis Dunk")
  assert.equal(parsed.redCards[0].minute, "68'")
})

test("parseFotmobForm extracts 5-match form letters", () => {
  const rawForm = [
    [{ resultString: "W" }, { resultString: "W" }, { resultString: "D" }, { resultString: "L" }, { resultString: "W" }],
    [{ resultString: "L" }, { resultString: "D" }, { resultString: "W" }]
  ]
  const form = Model.parseFotmobForm(rawForm)
  assert.deepEqual(form.home, ["W", "W", "D", "L", "W"])
  assert.deepEqual(form.away, ["L", "D", "W"])
  assert.deepEqual(Model.parseFotmobForm(null), { home: [], away: [] })
})

test("parseFotmobStats extracts possession and xG", () => {
  const rawStats = {
    Periods: {
      All: {
        stats: [
          {
            title: "Top stats",
            stats: [
              { key: "BallPossesion", stats: [64, 36] },
              { key: "expected_goals", stats: ["1.88", "0.20"] },
              { key: "ShotsOnTarget", stats: [6, 1] }
            ]
          }
        ]
      }
    }
  }
  const stats = Model.parseFotmobStats(rawStats)
  assert.ok(stats)
  assert.deepEqual(stats.possession, [64, 36])
  assert.deepEqual(stats.xG, ["1.88", "0.20"])
  assert.deepEqual(stats.shotsOnTarget, [6, 1])
  assert.equal(Model.parseFotmobStats({}), null)
})
