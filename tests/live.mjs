// Live end-to-end harness: fetches real provider payloads with the exact same
// curl invocations the plugin uses, then runs the actual SportsModel parsers.
// Usage: node tests/live.mjs [football|nba|nfl|mlb|nhl|f1|all]
import { readFileSync } from "node:fs"
import { execFileSync } from "node:child_process"
import assert from "node:assert/strict"

const raw = readFileSync(new URL("../SportsModel.js", import.meta.url), "utf8")
const exported = [
  "supportedLeagues", "espnDateRange", "parseEspnScoreboard", "parseEspnStandings",
  "parseF1Calendar", "parseF1DriverStandings", "parseF1ConstructorStandings",
  "parseLeaguePage", "parseTeamPage", "liveMatches", "matchLine",
  "groupMatches", "featuredMatchForTeam", "matchesForTeam", "parseDetails"
]
const src = raw.replace(/^\.pragma library\s*$/m, "") + "\nexport { " + exported.join(", ") + " }\n"
const Model = await import("data:text/javascript;base64," + Buffer.from(src).toString("base64"))

const UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36"
function curl(url, { compressed = false, ua = null } = {}) {
  const args = ["-LfsS", "--max-time", "15"]
  if (compressed) args.push("--compressed")
  if (ua) args.push("-A", ua)
  args.push(url)
  return execFileSync("curl", args, { maxBuffer: 64 * 1024 * 1024 }).toString()
}

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
    console.log("  ✗ " + name + "\n    " + String(e.message || e).split("\n")[0])
  }
}

const which = process.argv[2] || "football"

// ------------------------------------------------------------------ football
if (which === "football" || which === "all") {
  console.log("\nFOOTBALL (FotMob live)")
  // Default league id from plugin state is "61" (Ligue 1); also try a big one.
  for (const id of ["61", "47"]) {
    await test(`league ${id}: FotMob page parses with matches`, () => {
      const html = curl(`https://www.fotmob.com/leagues/${id}`, { compressed: true, ua: UA })
      assert.ok(html.includes("__NEXT_DATA__"), "no __NEXT_DATA__ in HTML — FotMob changed their page format")
      const page = Model.parseLeaguePage(html, id)
      assert.ok(page.league.name && page.league.name !== `League ${id}`, `league name missing: ${page.league.name}`)
      assert.ok(page.matches.length > 0, "no matches parsed")
      const m = page.matches[0]
      assert.ok(m.home.name && m.away.name, "match teams missing names")
      assert.ok(m.id, "match has no id")
    })
  }
  await test("league 61: standings parse to rows with points", async () => {
    const html = curl("https://www.fotmob.com/leagues/61", { compressed: true, ua: UA })
    const page = Model.parseLeaguePage(html, "61")
    assert.ok(page.standings.length >= 10, "standings rows < 10: " + page.standings.length)
    const first = page.standings[0]
    assert.ok(first.name && Number.isFinite(first.pts) && first.pts >= 0, "leader row invalid")
  })
  await test("team page (Arsenal 9825) parses fixtures", () => {
    const html = curl("https://www.fotmob.com/teams/9825", { compressed: true, ua: UA })
    assert.ok(html.includes("__NEXT_DATA__"), "no __NEXT_DATA__ in team page")
    const matches = Model.parseTeamPage(html, "9825")
    assert.ok(matches.length > 0, "no fixtures parsed from team page")
    for (const m of matches) assert.ok(m.home.name && m.away.name && m.leagueName, "fixture malformed")
    console.log(`    (${matches.length} fixtures)`)
  })
  await test("crest CDN serves team logos", () => {
    const png = curl("https://images.fotmob.com/image_resources/logo/teamlogo/9825.png")
    assert.ok(png.length > 500 && png.includes("PNG"), "crest image not served")
  })
  await test("grouping buckets real league matches (live/upcoming/recent)", () => {
    const html = curl("https://www.fotmob.com/leagues/47", { compressed: true, ua: UA })
    const page = Model.parseLeaguePage(html, "47")
    const groups = Model.groupMatches(page.matches)
    const total = groups.reduce((n, g) => n + g.matches.length, 0)
    assert.ok(total <= page.matches.length, "grouping created extra matches")
    assert.ok(total > 0, "grouping produced zero matches")
    assert.ok(groups.some(g => g.key === "upcoming"), "no upcoming group in-season")
    assert.ok(groups.some(g => g.key === "recent"), "no recent group in-season")
    const recent = groups.find(g => g.key === "recent")
    assert.ok(recent.matches.length <= 10, "recent group exceeds cap")
    const statusByKey = { live: "live", upcoming: "upcoming", recent: "finished" }
    for (const g of groups) for (const m of g.matches) assert.equal(m.status, statusByKey[g.key], `match in wrong bucket (${g.key})`)
  })
  await test("spotlight: featured match + team schedule for Arsenal", () => {
    const html = curl("https://www.fotmob.com/teams/9825", { compressed: true, ua: UA })
    const mine = Model.parseTeamPage(html, "9825")
    const featured = Model.featuredMatchForTeam(mine, "9825")
    assert.ok(featured, "no featured match")
    assert.ok(featured.home.id === "9825" || featured.away.id === "9825", "featured match does not involve followed team")
    const line = Model.matchLine(mine.find(m => m.status === "finished") || mine[0])
    assert.ok(line && line.length > 0, "matchLine empty")
  })
  await test("live match details parse (stadium/referee)", () => {
    // Scan in-season leagues for any live match, then fetch its detail page.
    let checked = false
    for (const id of ["47", "61", "87", "135"]) {
      const page = Model.parseLeaguePage(curl(`https://www.fotmob.com/leagues/${id}`, { compressed: true, ua: UA }), String(id))
      const live = page.matches.filter(m => m.status === "live")
      if (live.length === 0) continue
      const m = live[0]
      const d = Model.parseDetails(curl("https://www.fotmob.com" + (m.pageUrl || ""), { compressed: true, ua: UA }))
      assert.ok(d, "details parser returned null for live match")
      checked = true
      console.log(`    (live: ${m.home.name} v ${m.away.name} — ${d.stadium || "?"})`)
      break
    }
    if (!checked) console.log("    (no live matches right now — skipped live-detail assertion)")
  })
}

// --------------------------------------------------------------- espn sports
for (const [sport, espnPath] of [["nba", "basketball/nba"], ["nfl", "football/nfl"], ["mlb", "baseball/mlb"], ["nhl", "hockey/nhl"]]) {
  if (which !== sport && which !== "all") continue
  console.log(`\n${sport.toUpperCase()} (ESPN live)`)
  await test(`${sport}: scoreboard parses events`, () => {    const dates = Model.espnDateRange(1, 3)
    const raw = curl(`https://site.api.espn.com/apis/site/v2/sports/${espnPath}/scoreboard?${dates}`)
    const parsed = Model.parseEspnScoreboard(raw, sport, sport.toUpperCase())
    assert.ok(Array.isArray(parsed), "scoreboard parser did not return an array")
    for (const m of parsed) {
      assert.ok(m.home.name && m.away.name, "event missing team names")
      assert.ok(m.home.logo || m.away.logo, "no logos")
    }
    console.log(`    (${parsed.length} games in window)`)
  })
  await test(`${sport}: standings parse`, () => {
    const raw = curl(`https://site.api.espn.com/apis/v2/sports/${espnPath}/standings`)
    const groups = Model.parseEspnStandings(raw, sport)
    assert.ok(groups && typeof groups === "object", "standings parser returned nothing")
    const rows = Object.values(groups).flat()
    assert.ok(rows.length > 0, "no standings rows")
    for (const r of rows.slice(0, 5)) {
      assert.ok(r.name && r.id, "row missing identity")
      assert.ok(r.wins >= 0 && r.losses >= 0, "row W/L invalid")
    }
    console.log(`    (${rows.length} rows in ${Object.keys(groups).length} groups)`)
  })
}

// ------------------------------------------------------------------------ f1
if (which === "f1" || which === "all") {
  console.log("\nFORMULA 1 (Jolpica/Ergast live)")
  await test("calendar parses races with sessions", () => {
    const raw = curl("https://api.jolpi.ca/ergast/f1/current.json")
    const races = Model.parseF1Calendar(raw)
    assert.ok(races.length >= 14, "too few races: " + races.length)
    for (const r of races.slice(0, 3)) {
      assert.ok(r.raceName && r.sessions && r.sessions.length > 0 && r.countryFlag, "race malformed")
      assert.ok(r.id.startsWith("f1-"), "race id malformed")
    }
  })
  await test("driver standings parse with flags and points", () => {
    const raw = curl("https://api.jolpi.ca/ergast/f1/current/driverStandings.json")
    const drivers = Model.parseF1DriverStandings(raw)
    assert.ok(drivers.length >= 20, "driver count low: " + drivers.length)
    for (const d of drivers.slice(0, 5)) {
      assert.ok(d.name && d.abbr && d.teamName, "driver missing identity")
      assert.ok(/^[\d.]+ PTS$/.test(String(d.pts)), "pts not formatted like 'NNN PTS': " + d.pts)
      assert.ok(d.flag && /\uD83C[\uDDE6-\uDDFF]/.test(d.flag), "missing driver flag")
    }
  })
  await test("constructor standings parse", () => {
    const raw = curl("https://api.jolpi.ca/ergast/f1/current/constructorStandings.json")
    const ctors = Model.parseF1ConstructorStandings(raw)
    assert.ok(ctors.length === 10 || ctors.length === 11, "unexpected constructor count: " + ctors.length)
  })
}

console.log(`\n${passed} passed, ${failed} failed`)
if (failures.length) {
  console.log("Failed: " + failures.join(", "))
  process.exit(1)
}
