// Capture real provider payloads into tests/fixtures/ for offline regression
// testing. Alongside each raw payload we freeze a "golden" snapshot of what the
// current parsers produce, so offline.mjs can catch semantic drift (renamed
// fields, changed sorting, lost zones), not just crashes.
// Run occasionally (or before releases) to refresh the frozen data.
// Usage: node tests/capture-fixtures.mjs
import { execFileSync } from "node:child_process"
import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"

// Load the real parser module (same trick as tests/offline.mjs)
const modelSrc = readFileSync(fileURLToPath(new URL("../SportsModel.js", import.meta.url)), "utf8")
const exported = [
  "parseEspnScoreboard", "parseEspnStandings", "parseF1Calendar",
  "parseF1DriverStandings", "parseF1ConstructorStandings",
  "parseLeaguePage", "parseTeamPage", "espnDateRange", "parseDetails"
]
const src = modelSrc.replace(/^\.pragma library\s*$/m, "") + "\nexport { " + exported.join(", ") + " }\n"
const Model = await import("data:text/javascript;base64," + Buffer.from(src).toString("base64"))

const dir = fileURLToPath(new URL("./fixtures/", import.meta.url))
mkdirSync(dir, { recursive: true })

const UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36"
function curl(url, { compressed = false, ua = null } = {}) {
  const args = ["-LfsS", "--max-time", "20"]
  if (compressed) args.push("--compressed")
  if (ua) args.push("-A", ua)
  args.push(url)
  return execFileSync("curl", args, { maxBuffer: 64 * 1024 * 1024 }).toString()
}

// capturedAt freezes wall-clock time so time-dependent parsers (F1 statuses)
// produce stable golden output; offline.mjs replays it.
const capturedAt = Date.now()
const goldens = []

function save(name, data) {
  writeFileSync(dir + name, data)
  console.log("  saved " + name + " (" + Math.round(data.length / 1024) + " KB)")
}

function golden(name, data) {
  goldens.push({ name: name.replace(/\.golden$/, "") + ".golden.json", payload: name, data })
}

console.log("capturing fixtures → " + dir)

for (const id of ["47", "61"]) {
  const html = curl(`https://www.fotmob.com/leagues/${id}`, { compressed: true, ua: UA })
  save(`fotmob-league-${id}.html`, html)
  golden(`fotmob-league-${id}`, Model.parseLeaguePage(html, id))
}
const teamHtml = curl("https://www.fotmob.com/teams/9825", { compressed: true, ua: UA })
save("fotmob-team-9825.html", teamHtml)
golden("fotmob-team-9825", Model.parseTeamPage(teamHtml, "9825"))

// Match detail page (stadium/referee/FT correction feed). Picked dynamically
// from the league page just captured so there is always a current id.
try {
  const league47 = Model.parseLeaguePage(readFileSync(dir + "fotmob-league-47.html", "utf8"), "47")
  const candidate = (league47.matches || []).find(m => m.pageUrl) || null
  if (candidate) {
    const matchUrl = String(candidate.pageUrl).indexOf("http") === 0
      ? String(candidate.pageUrl)
      : "https://www.fotmob.com" + candidate.pageUrl
    const matchHtml = curl(matchUrl, { compressed: true, ua: UA })
    save("fotmob-match.html", matchHtml)
    golden("fotmob-match", Model.parseDetails(matchHtml))
  } else {
    console.log("  (no match with pageUrl found — skipping fotmob-match fixture)")
  }
} catch (e) {
  console.log("  (match fixture capture failed: " + e.message + ")")
}

for (const [sport, espnPath] of [["nba", "basketball/nba"], ["nfl", "football/nfl"], ["mlb", "baseball/mlb"], ["nhl", "hockey/nhl"]]) {
  // Mirror the production query — Panel requests the same multi-day window,
  // so goldens must protect the payload shape the app actually receives
  const dates = Model.espnDateRange(1, 3)
  const board = curl(`https://site.api.espn.com/apis/site/v2/sports/${espnPath}/scoreboard?dates=${dates}`)
  save(`espn-${sport}-scoreboard.json`, board)
  golden(`espn-${sport}-scoreboard`, Model.parseEspnScoreboard(board, sport, sport.toUpperCase()))
  const table = curl(`https://site.api.espn.com/apis/v2/sports/${espnPath}/standings`)
  save(`espn-${sport}-standings.json`, table)
  golden(`espn-${sport}-standings`, Model.parseEspnStandings(table, sport))
}

const f1Cal = curl("https://api.jolpi.ca/ergast/f1/current.json")
save("f1-calendar.json", f1Cal)
golden("f1-calendar", Model.parseF1Calendar(f1Cal, capturedAt))
const f1Drv = curl("https://api.jolpi.ca/ergast/f1/current/driverStandings.json")
save("f1-drivers.json", f1Drv)
golden("f1-drivers", Model.parseF1DriverStandings(f1Drv))
const f1Ctor = curl("https://api.jolpi.ca/ergast/f1/current/constructorStandings.json")
save("f1-constructors.json", f1Ctor)
golden("f1-constructors", Model.parseF1ConstructorStandings(f1Ctor))

writeFileSync(
  dir + "goldens.json",
  JSON.stringify({ capturedAt, goldens: Object.fromEntries(goldens.map(g => [g.name, g.data])) }, null, 1)
)
console.log("  saved goldens.json (" + goldens.length + " snapshots)")

console.log("done")
