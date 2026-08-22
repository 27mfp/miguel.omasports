// Offline regression suite: runs the real parsers against frozen provider
// payloads in tests/fixtures/ and deep-compares output against golden
// snapshots. No network needed — fast and deterministic.
// Refresh fixtures + goldens with: node tests/capture-fixtures.mjs
// Usage: node tests/offline.mjs
import { readFileSync, existsSync } from "node:fs"
import assert from "node:assert/strict"

const raw = readFileSync(new URL("../SportsModel.js", import.meta.url), "utf8")
const exported = [
  "parseEspnScoreboard", "parseEspnStandings", "parseF1Calendar",
  "parseF1DriverStandings", "parseF1ConstructorStandings",
  "parseLeaguePage", "parseTeamPage", "groupMatches", "liveMatches",
  "parseDetails"
]
const src = raw.replace(/^\.pragma library\s*$/m, "") + "\nexport { " + exported.join(", ") + " }\n"
const Model = await import("data:text/javascript;base64," + Buffer.from(src).toString("base64"))
const fx = (name) => readFileSync(new URL("./fixtures/" + name, import.meta.url), "utf8")
const have = (name) => existsSync(new URL("./fixtures/" + name, import.meta.url))

let passed = 0, failed = 0
const failures = []
async function test(name, fn) {
  try {
    await fn()
    passed++
    console.log("  ✓ " + name)
  } catch (e) {
    failed++
    failures.push(name)
    console.log("  ✗ " + name + "\n    " + String(e.message || e).split("\n").slice(0, 4).join("\n    "))
  }
}

// First-difference reporter: tells you exactly which field drifted and how.
function firstDiff(a, b, path = "") {
  if (a === b) return null
  const ta = a === null ? "null" : typeof a
  const tb = b === null ? "null" : typeof b
  if (ta !== tb || ta !== "object") return `${path || "<root>"}: ${JSON.stringify(a)} → ${JSON.stringify(b)}`
  if (Array.isArray(a) !== Array.isArray(b)) return `${path || "<root>"}: array↔object`
  const ka = Object.keys(a), kb = Object.keys(b)
  for (const k of ka) if (!(k in b)) return `${path}.${k}: ${JSON.stringify(a[k])} → <removed>`
  for (const k of kb) if (!(k in a)) return `${path}.${k}: <missing> → ${JSON.stringify(b[k])}`
  for (const k of ka) {
    const d = firstDiff(a[k], b[k], path ? path + "." + k : k)
    if (d) return d
  }
  return null
}

function expectGolden(goldens, name, produce) {
  assert.ok(name in goldens.goldens, `no golden snapshot for ${name} — re-run capture-fixtures.mjs`)
  const actual = produce()
  const diff = firstDiff(goldens.goldens[name], actual)
  assert.ok(!diff, `parser drift vs frozen output\n    at ${diff}`)
}

console.log("OFFLINE — parsers vs frozen fixtures + goldens")

if (!have("fotmob-league-47.html")) {
  console.log("\nNo fixtures found. Run first: node tests/capture-fixtures.mjs")
  process.exit(1)
}
let goldens = { goldens: {} }
if (have("goldens.json")) goldens = JSON.parse(fx("goldens.json"))
else console.log("  (no goldens.json — structural checks only; re-run capture-fixtures.mjs)")

await test("fotmob league pages still parse identically", () => {
  for (const id of ["47", "61"]) {
    const page = Model.parseLeaguePage(fx(`fotmob-league-${id}.html`), id)
    assert.ok(page.matches.length > 50, `league ${id}: too few matches`)
    assert.ok(page.standings.length >= 10, `league ${id}: standings missing`)
    expectGolden(goldens, `fotmob-league-${id}.golden.json`, () => page)
  }
})
await test("fotmob team page still parses identically", () => {
  const matches = Model.parseTeamPage(fx("fotmob-team-9825.html"), "9825")
  assert.ok(matches.length > 20, "team fixtures missing")
  expectGolden(goldens, "fotmob-team-9825.golden.json", () => matches)
})
if (have("fotmob-match.html")) {
  await test("fotmob match details parse identically (stadium/FT correction)", () => {
    const details = Model.parseDetails(fx("fotmob-match.html"))
    assert.ok(details !== null && typeof details === "object", "parseDetails returned nothing")
    // The panel uses these fields for the venue subline and the FT flip
    assert.ok(details.stadium || details.round || details.statusLong || details.finished,
      "details carried no usable fields")
    expectGolden(goldens, "fotmob-match.golden.json", () => details)
  })
} else {
  console.log("  (fotmob-match.html missing — run capture-fixtures.mjs to protect parseDetails)")
}
for (const sport of ["nba", "nfl", "mlb", "nhl"]) {
  await test(`espn ${sport} scoreboard fixture parses identically`, () => {
    const matches = Model.parseEspnScoreboard(fx(`espn-${sport}-scoreboard.json`), sport, sport.toUpperCase())
    assert.ok(Array.isArray(matches))
    for (const m of matches) assert.ok(m.home.name && m.away.name, "event malformed")
    expectGolden(goldens, `espn-${sport}-scoreboard.golden.json`, () => matches)
  })
  await test(`espn ${sport} standings fixture parses identically`, () => {
    const groups = Model.parseEspnStandings(fx(`espn-${sport}-standings.json`), sport)
    const rows = Object.values(groups).flat()
    assert.ok(rows.length > 0, "no rows")
    for (const r of rows.slice(0, 5)) assert.ok(r.name && r.id, "row malformed")
    expectGolden(goldens, `espn-${sport}-standings.golden.json`, () => groups)
  })
}
await test("f1 fixtures parse identically (calendar, drivers, constructors)", () => {
  const races = Model.parseF1Calendar(fx("f1-calendar.json"), goldens.capturedAt)
  assert.ok(races.length >= 14, "races: " + races.length)
  expectGolden(goldens, "f1-calendar.golden.json", () => races)
  const drivers = Model.parseF1DriverStandings(fx("f1-drivers.json"))
  assert.ok(drivers.length >= 20, "drivers: " + drivers.length)
  expectGolden(goldens, "f1-drivers.golden.json", () => drivers)
  const ctors = Model.parseF1ConstructorStandings(fx("f1-constructors.json"))
  assert.ok(ctors.length >= 10, "constructors: " + ctors.length)
  expectGolden(goldens, "f1-constructors.golden.json", () => ctors)
})

await test("frozen payloads still group and filter like production", () => {
  const page = Model.parseLeaguePage(fx("fotmob-league-47.html"), "47")
  const groups = Model.groupMatches(page.matches)
  const byKey = Object.fromEntries(groups.map(g => [g.key, g.matches]))
  assert.ok((byKey.upcoming || []).length > 0 && (byKey.recent || []).length > 0, "grouping lost buckets")
  const live = Model.liveMatches(page.matches.concat(Model.parseEspnScoreboard(fx("espn-nba-scoreboard.json"), "nba", "NBA")))
  for (const m of live) assert.equal(m.status, "live", "liveMatches leaked non-live match")
})

console.log(`\n${passed} passed, ${failed} failed`)
if (failures.length) { console.log("Failed: " + failures.join(", ")); process.exit(1) }
