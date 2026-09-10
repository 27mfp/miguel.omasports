#!/usr/bin/env node
// S-Tier Chaos & Edge-Case Scenario Test Suite for miguel.omasports
// Validates resilience under unusual match states, provider outages, and extreme data.
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"

const raw = readFileSync(new URL("../SportsModel.js", import.meta.url), "utf8")
const exported = [
  "parseScore", "parseMatch", "parseDetails", "parseLeaguePage", "isEspnScoreboardPayload",
  "matchesForTeam", "featuredMatchForTeam", "teamOutcome", "matchStatusText",
  "mergePages", "mergeMatchUpdates", "groupMatches", "interpolateLiveTime",
  "RETRY_DELAY_ESPN_MS", "RETRY_DELAY_FOTMOB_F1_MS"
]
const src = raw.replace(/^\.pragma library\s*$/m, "") + "\nexport { " + exported.join(", ") + " }\n"
const Model = await import("data:text/javascript;base64," + Buffer.from(src).toString("base64"))

let passed = 0
let failed = 0

function test(name, fn) {
  process.stdout.write(`  ▶ Scenario: ${name}... `)
  try {
    fn()
    passed++
    console.log("✓ PASS")
  } catch (err) {
    failed++
    console.log(`✗ FAIL: ${err.message}`)
  }
}

console.log("==================================================")
console.log("  OMASports Chaos & Edge-Case Scenario Suite")
console.log("==================================================")

// -----------------------------------------------------------------------------
// 1. Penalty Shootout
// -----------------------------------------------------------------------------
test("Penalty Shootout (1 - 1, 5 - 4 pens)", () => {
  const fotmobMatch = {
    id: "9901",
    status: {
      started: true,
      finished: true,
      scoreStr: "1 - 1 (5 - 4 pens)",
      reason: { short: "Pen", long: "Penalties" }
    },
    home: { id: "101", name: "Arsenal" },
    away: { id: "102", name: "Chelsea" }
  }

  const league = { id: "42", name: "Champions League" }
  const parsed = Model.parseMatch(fotmobMatch, league)
  assert.equal(parsed.status, "finished")
  assert.equal(parsed.homeScore, 1)
  assert.equal(parsed.awayScore, 1)
  assert.equal(parsed.statusReason, "Pen")
})

// -----------------------------------------------------------------------------
// 2. Extra Time (AET)
// -----------------------------------------------------------------------------
test("Extra Time match (118' in progress & FT AET)", () => {
  const liveAet = {
    id: "9902",
    status: {
      started: true,
      finished: false,
      scoreStr: "2 - 2",
      liveTime: { short: "118'", long: "118" }
    },
    home: { id: "101", name: "Real Madrid" },
    away: { id: "102", name: "Man City" }
  }
  const league = { id: "42", name: "Champions League" }
  const parsedLive = Model.parseMatch(liveAet, league)
  assert.equal(parsedLive.status, "live")
  assert.equal(parsedLive.homeScore, 2)
  assert.equal(parsedLive.awayScore, 2)
  assert.equal(parsedLive.liveTime, "118'")

  const ftAet = {
    id: "9903",
    status: {
      started: true,
      finished: true,
      scoreStr: "3 - 2",
      reason: { short: "AET", long: "After Extra Time" }
    },
    home: { id: "101", name: "Real Madrid" },
    away: { id: "102", name: "Man City" }
  }
  const parsedFt = Model.parseMatch(ftAet, league)
  assert.equal(parsedFt.status, "finished")
  assert.equal(parsedFt.homeScore, 3)
  assert.equal(parsedFt.awayScore, 2)
  assert.equal(parsedFt.statusReason, "AET")
})

// -----------------------------------------------------------------------------
// 3. Match Facts with Red Card and Half-Time Scores
// -----------------------------------------------------------------------------
test("Match facts with Red Card events and Half-Time scores", () => {
  const pageProps = {
    content: {
      matchFacts: {
        events: {
          events: [
            { type: "Goal", time: 14, player: { name: "Rodrygo" }, isHome: true },
            { type: "Card", card: "RedCard", time: 38, player: { name: "Defender" }, isHome: false },
            { type: "Half", halfStrShort: "HT", time: 45, homeScore: 1, awayScore: 0 },
            { type: "Goal", time: 78, player: { name: "Vinicius Jr" }, isHome: true }
          ]
        },
        infoBox: {
          Stadium: { name: "Santiago Bernabéu", city: "Madrid" },
          Referee: { text: "Michael Oliver" },
          Attendance: 78500
        }
      }
    }
  }

  const rawHtml = `<script id="__NEXT_DATA__" type="application/json">${JSON.stringify({ props: { pageProps } })}</script>`
  const details = Model.parseDetails(rawHtml)
  assert.equal(details.stadium, "Santiago Bernabéu")
  assert.equal(details.city, "Madrid")
  assert.equal(details.referee, "Michael Oliver")
  assert.equal(details.attendance, 78500)
  assert.equal(details.halftimeScore, "1 – 0")
})

// -----------------------------------------------------------------------------
// 4. Provider 429 Rate-Limit & Bot-Wall Resilience (No Data Loss)
// -----------------------------------------------------------------------------
test("Resilience against HTTP 429 & Cloudflare HTML bot-walls (No Data Loss)", () => {
  const botWallHtml = `
    <!DOCTYPE html>
    <html><head><title>Attention Required! | Cloudflare</title></head>
    <body>Please complete the security check to access fotmob.com</body></html>
  `
  // Parser must cleanly reject without throwing
  const result = Model.parseLeaguePage(botWallHtml, "42", "Champions League")
  assert.equal(result, null, "Bot wall HTML must safely return null instead of throwing")

  // Cache preservation: merging existing cached matches with empty updates preserves data
  const cachedMatches = [
    { id: "1", homeScore: 2, awayScore: 1, home: { name: "Benfica" }, away: { name: "Porto" } }
  ]
  const merged = Model.mergeMatchUpdates(cachedMatches, [])
  assert.equal(merged.length, 1, "Must retain cached matches during provider failure")
  assert.equal(merged[0].id, "1")
  assert.equal(merged[0].homeScore, 2)
  assert.equal(Model.RETRY_DELAY_ESPN_MS, 15000, "ESPN retry floor must be at least 15 seconds")
  assert.equal(Model.RETRY_DELAY_FOTMOB_F1_MS, 20000, "FotMob/F1 retry floor must be at least 20 seconds")
})

// -----------------------------------------------------------------------------
// 5. Extreme Typography & High-Scoring Matches
// -----------------------------------------------------------------------------
test("Extreme typography and blowout scorelines", () => {
  const extremeMatch = {
    id: "9904",
    status: {
      started: true,
      finished: true,
      scoreStr: "148 - 142"
    },
    home: { id: "201", name: "Borussia Mönchengladbach II Amateure" },
    away: { id: "202", name: "Llanfairpwllgwyngyllgogerychwyrndrobwllllantysiliogogogoch" }
  }
  const league = { id: "1", name: "Tournament" }
  const parsed = Model.parseMatch(extremeMatch, league)
  assert.equal(parsed.homeScore, 148)
  assert.equal(parsed.awayScore, 142)
  assert.equal(parsed.status, "finished")

  const outcome = Model.teamOutcome(parsed, "201")
  assert.equal(outcome, "win")
  const awayOutcome = Model.teamOutcome(parsed, "202")
  assert.equal(awayOutcome, "loss")
})

// -----------------------------------------------------------------------------
// 6. Clock Interpolation at Max Stoppage Time
// -----------------------------------------------------------------------------
test("Clock interpolation caps stoppage time gracefully", () => {
  const now = Date.now()
  // Match with 90' clock, polled 10 minutes ago
  const matchAt90 = {
    sport: "football",
    status: "live",
    liveTime: "90’",
    time: new Date(now - 105 * 60000).toISOString()
  }
  const interpolated = Model.interpolateLiveTime(matchAt90, now, now - 10 * 60000)
  // Should interpolate into stoppage time (90+...)
  assert.ok(interpolated.indexOf("90") !== -1, `Expected stoppage clock with 90, got: ${interpolated}`)
})

console.log("==================================================")
console.log(`  Scenario Suite Completed: ${passed} passed, ${failed} failed.`)
console.log("==================================================")

if (failed > 0) process.exit(1)
