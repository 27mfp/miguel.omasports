#!/usr/bin/env node
// Autonomous non-interruptive visual testing & perceptual diff suite for miguel.omasports
// Captures UI snapshots and runs pixel-level visual regression comparisons against goldens.
// Run with: node tests/visual.mjs [--tab=<name>] [--sport=<name>] [--delay=<ms>] [--update-goldens] [--tolerance=<percent>]
import { execSync, execFileSync } from "node:child_process"
import { existsSync, mkdirSync, writeFileSync, copyFileSync, statSync, unlinkSync } from "node:fs"
import { join } from "node:path"

const ARGS = process.argv.slice(2)
function getArg(name, def = null) {
  const prefix = `--${name}=`
  for (const a of ARGS) {
    if (a.startsWith(prefix)) return a.slice(prefix.length)
    if (a === `--${name}`) return true
  }
  return def
}

const TARGET_TAB = getArg("tab", null)
const TARGET_SPORT = getArg("sport", null)
const DELAY_MS = parseInt(getArg("delay", "1000"), 10)
const ON_SCREEN = Boolean(getArg("on-screen", false))
const UPDATE_GOLDENS = Boolean(getArg("update-goldens", false))
const TOLERANCE = parseFloat(getArg("tolerance", "0.5"))
const TARGET_SCALE = parseFloat(getArg("scale", "1.25"))
const VALID_TABS = new Set(["live", "fixtures", "standings", "settings", "news", "results"])
const VALID_SPORTS = new Set(["football", "f1", "nba", "nfl", "mlb", "nhl"])

if (ON_SCREEN) {
  console.error("Error: on-screen visual testing is disabled; use a headless Hyprland monitor.")
  process.exit(1)
}
if (TARGET_TAB && TARGET_TAB !== "all" && !VALID_TABS.has(String(TARGET_TAB))) {
  console.error(`Error: unsupported tab '${TARGET_TAB}'.`)
  process.exit(1)
}
if (TARGET_SPORT && TARGET_SPORT !== "all" && !VALID_SPORTS.has(String(TARGET_SPORT))) {
  console.error(`Error: unsupported sport '${TARGET_SPORT}'.`)
  process.exit(1)
}
if (!Number.isFinite(TOLERANCE) || TOLERANCE < 0) {
  console.error("Error: tolerance must be a non-negative number.")
  process.exit(1)
}
if (!Number.isFinite(TARGET_SCALE) || TARGET_SCALE <= 0) {
  console.error("Error: scale must be a positive number.")
  process.exit(1)
}
if (!Number.isFinite(DELAY_MS) || DELAY_MS < 0) {
  console.error("Error: delay must be a non-negative number.")
  process.exit(1)
}

const ARTIFACTS_DIR = join(process.cwd(), "test-artifacts")
const GOLDENS_DIR = join(process.cwd(), "tests", "fixtures", "visual-goldens")
const CROP_SCRIPT = join(process.cwd(), "tests", "crop.py")
const DIFF_SCRIPT = join(process.cwd(), "tests", "diff.py")

if (!existsSync(ARTIFACTS_DIR)) mkdirSync(ARTIFACTS_DIR, { recursive: true })
if (!existsSync(GOLDENS_DIR)) mkdirSync(GOLDENS_DIR, { recursive: true })

function sh(cmd, ignoreError = false) {
  try {
    return execSync(cmd, { stdio: "pipe", encoding: "utf8" }).trim()
  } catch (err) {
    if (!ignoreError) throw err
    return (err.stdout ? err.stdout.toString() : "").trim()
  }
}

function ipc(method, ...args) {
  return execFileSync("omarchy-shell", ["miguel.omasports", method, ...args], {
    stdio: "pipe",
    encoding: "utf8"
  }).trim()
}

function commandSucceeds(command) {
  try {
    execSync(command, { stdio: "ignore" })
    return true
  } catch {
    return false
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function ensureToggle(getter, toggle, expected) {
  if (String(ipc(getter)).trim().toLowerCase() === String(expected)) return
  ipc(toggle)
  await sleep(300) // Panel IPC mutation throttle is 250ms by design.
  if (String(ipc(getter)).trim().toLowerCase() !== String(expected)) {
    throw new Error(`${getter} could not be set to ${expected}`)
  }
}

async function setBoolean(method, getter, expected) {
  ipc(method, String(expected))
  await sleep(100)
  if (String(ipc(getter)).trim().toLowerCase() !== String(expected)) {
    throw new Error(`${getter} could not be set to ${expected}`)
  }
}

const hasGrim = Boolean(sh("which grim", true))
const hasHyprctl = Boolean(sh("which hyprctl", true))
const hasMagick = Boolean(sh("which magick", true) || sh("which convert", true))
const hasPython3 = Boolean(sh("which python3", true))
const hasPillow = hasPython3 && commandSucceeds("python3 -c \"import PIL\"")

if (!hasGrim) {
  console.error("Error: 'grim' is required for autonomous visual testing on Wayland.")
  process.exit(1)
}
if (!hasPillow && !hasMagick) {
  console.error("Error: Python Pillow or ImageMagick is required to measure visual baselines.")
  process.exit(1)
}

let headlessMonitor = null

function headlessMonitors() {
  const output = sh("hyprctl monitors")
  return [...output.matchAll(/Monitor (HEADLESS-\d+)/g)].map((match) => match[1])
}

function setupHeadlessMonitor() {
  if (!hasHyprctl) {
    throw new Error("hyprctl is required; refusing to run visual tests on a physical screen")
  }
  let mon = null
  let before = []
  try {
    before = headlessMonitors()
    const out = sh("hyprctl output create headless")
    const match = out.match(/HEADLESS-\d+/)
    if (match) {
      mon = match[0]
    } else {
      const after = headlessMonitors()
      mon = after.find((name) => !before.includes(name)) || null
    }
    if (!mon) throw new Error("Hyprland did not report a headless monitor")
    if (TARGET_SCALE) {
      try {
        sh(`hyprctl eval "hl.monitor({ output = '${mon}', mode = '1920x1080@60', position = 'auto', scale = ${TARGET_SCALE} })"`)
      } catch {
        sh(`hyprctl keyword monitor "${mon},1920x1080@60,auto,${TARGET_SCALE}"`)
      }
    }
    console.log(`  🕶️  Running in headless mode on virtual monitor: [${mon}] (scale: ${TARGET_SCALE}, zero screen popups, zero focus disruption)`)
    return mon
  } catch (err) {
    try {
      const after = headlessMonitors()
      const leaked = mon || after.find((name) => !before.includes(name))
      if (leaked) sh(`hyprctl output remove "${leaked}"`)
    } catch {}
    throw new Error(`failed to provision headless output: ${err.message}`)
  }
}

function removeHeadlessMonitor(mon) {
  if (!mon) return
  sh(`hyprctl output remove "${mon}"`)
  console.log(`  🧹 Virtual monitor [${mon}] destroyed cleanly.`)
}

async function captureTab(tabName, sport = null, isSportSwitch = false) {
  console.log(`\n  📸 Testing view: [${tabName.toUpperCase()}]${sport ? ` (sport: ${sport})` : ""}`)

  if (sport && isSportSwitch) {
    ipc("sport", sport)
    await sleep(2500)
  }

  if (tabName === "results") {
    ipc("route", "fixtures")
    ipc("scheduleSection", "results")
  } else if (tabName === "news") {
    ipc("route", "fixtures")
    ipc("scheduleSection", "news")
  } else {
    ipc("route", tabName)
  }
  await sleep(DELAY_MS)

  const filename = `tab-${sport ? `${sport}-` : ""}${tabName}.png`
  const filepath = join(ARTIFACTS_DIR, filename)
  const goldenPath = join(GOLDENS_DIR, filename)
  const diffFilename = `diff-${filename}`
  const diffPath = join(ARTIFACTS_DIR, diffFilename)

  if (!headlessMonitor) throw new Error("no headless monitor is active")
  {
    const rawPath = join(ARTIFACTS_DIR, `raw-${filename}`)
    sh(`grim -o "${headlessMonitor}" "${rawPath}"`)
    
    if (hasPillow && existsSync(CROP_SCRIPT)) {
      sh(`python3 "${CROP_SCRIPT}" "${rawPath}" "${filepath}"`, true)
    } else if (hasMagick) {
      const magickCmd = sh("which magick", true) ? "magick" : "convert"
      sh(`${magickCmd} "${rawPath}" -crop 665x500+628+38 +repage "${filepath}"`, true)
    } else {
      sh(`mv "${rawPath}" "${filepath}"`)
    }

    if (existsSync(rawPath) && existsSync(filepath) && rawPath !== filepath) {
      try { unlinkSync(rawPath) } catch {}
    }
  }

  // Verification 1: File size
  const stat = statSync(filepath)
  if (stat.size < 10000) {
    throw new Error(`Screenshot ${filename} is unexpectedly small (${stat.size} bytes), likely empty or blank.`)
  }

  // Verification 2: Color standard deviation
  let stdDev = null
  if (hasMagick) {
    const magickCmd = sh("which magick", true) ? "magick" : "convert"
    const out = sh(`${magickCmd} "${filepath}" -format "%[standard_deviation]" info:`, true)
    stdDev = parseFloat(out)
    if (!isNaN(stdDev) && stdDev < 80) {
      throw new Error(`Screenshot ${filename} appears blank or uniform (stdDev: ${stdDev}).`)
    }
  }

  // Verification 3: Responsive Viewport Constraint (max 72% screen height)
  let cardDimensions = null
  try {
    const magickCmd = sh("which magick", true) ? "magick" : "convert"
    const dimRaw = hasPillow
      ? sh(`python3 -c "from PIL import Image; im = Image.open('${filepath}'); print(f'{im.width}x{im.height}')"`)
      : sh(`${magickCmd} "${filepath}" -format "%wx%h" info:`)
    if (!dimRaw.includes("x")) throw new Error("could not measure captured image")
    const [w, h] = dimRaw.split("x").map(Number)
    cardDimensions = { width: w, height: h }
    if (h > 850) {
      throw new Error(`cropped card height (${h}px) exceeds 72% viewport budget`)
    }
    console.log(`    📏 Card size: ${w}x${h}px (within 72% viewport limit) ✓`)
  } catch (error) {
    throw error
  }

  // Perceptual Diffing vs Golden
  let diffResult = null
  let passed = true
  if (UPDATE_GOLDENS) {
    copyFileSync(filepath, goldenPath)
    console.log(`    🌟 Updated baseline golden: tests/fixtures/visual-goldens/${filename}`)
  } else if (existsSync(goldenPath)) {
    if (hasPillow && existsSync(DIFF_SCRIPT)) {
      const diffRaw = sh(`python3 "${DIFF_SCRIPT}" "${goldenPath}" "${filepath}" "${diffPath}" ${TOLERANCE}`, true)
      try {
        diffResult = JSON.parse(diffRaw)
        if (diffResult.status === "PASS") {
          console.log(`    🎯 Perceptual Diff: ${diffResult.diffPercent}% (within ${TOLERANCE}% tolerance) ✓`)
          passed = true
        } else {
          console.log(`    ⚠️ Perceptual Diff: ${diffResult.diffPercent}% (exceeds ${TOLERANCE}% tolerance) ✗`)
          passed = false
        }
      } catch (err) {
        console.error(`    ⚠️ Failed to parse diff result: ${diffRaw || err.message}`)
        passed = false
      }
    } else {
      console.warn("    ⚠️ Pillow and diff.py are required to compare against a baseline golden.")
      passed = false
    }
  } else {
    console.error(`    ✗ Missing visual golden for ${filename}`)
    passed = false
  }

  if (passed) {
    console.log(`    ✓ Captured ${filename} (${Math.round(stat.size / 1024)} KB${stdDev ? `, stdDev: ${Math.round(stdDev)}` : ""})`)
  } else {
    console.error(`    ✗ Visual regression detected in ${filename}!`)
  }
  return {
    tab: tabName,
    sport: sport || "football",
    filename,
    filepath,
    goldenPath: existsSync(goldenPath) ? goldenPath : null,
    goldenFilename: existsSync(goldenPath) ? `../tests/fixtures/visual-goldens/${filename}` : null,
    diffFilename: diffResult ? diffFilename : null,
    diffPercent: diffResult ? diffResult.diffPercent : null,
    mismatchedPixels: diffResult ? diffResult.mismatchedPixels : null,
    sizeKb: Math.round(stat.size / 1024),
    stdDev: stdDev ? Math.round(stdDev) : null,
    status: passed ? "PASS" : "FAIL"
  }
}

async function run() {
  console.log("==================================================")
  console.log("  OMASports Autonomous Visual & Perceptual Diff Runner")
  console.log("==================================================")

  const initialSport = ipc("getActiveSport") || "football"
  const initialRoute = ipc("getRoute") || "fixtures"
  const initialSection = ipc("getScheduleSection") || "all"
  const initialTargetScreen = ipc("getTargetScreen") || ""
  const initialSuppressFocus = ipc("getSuppressFocus")
  const initialOpened = String(ipc("getOpened")).trim().toLowerCase() === "true"
  const initialAntiSpoiler = String(ipc("getAntiSpoiler")).trim().toLowerCase() === "true"
  const initialBackgroundUpdates = String(ipc("getBackgroundUpdates")).trim().toLowerCase() === "true"
  const initialBarTicker = String(ipc("getBarTicker")).trim().toLowerCase() === "true"
  const initialSpotlight = String(ipc("getSpotlight")).trim().toLowerCase() === "true"
  const initialNewsWire = String(ipc("getNewsWire")).trim().toLowerCase() === "true"
  const initialNotifications = String(ipc("getNotifications")).trim().toLowerCase() === "true"
  const initialMockMode = String(ipc("getMockMode")).trim().toLowerCase() === "true"
  console.log(`  📌 Initial active sport: ${initialSport}`)
  if (UPDATE_GOLDENS) console.log("  🌟 MODE: Updating baseline visual goldens")

  const results = []
  let anyFailed = false
  let cleanupErrors = []

  try {
    const sportsToTest = TARGET_SPORT === "all"
      ? ["football", "f1", "nba", "nfl", "mlb", "nhl"]
      : [TARGET_SPORT || initialSport]
    const tabsToTest = TARGET_TAB === "all" || !TARGET_TAB
      ? ["live", "fixtures", "standings", "settings"]
      : [TARGET_TAB]

    if (!UPDATE_GOLDENS) {
      const missing = []
      for (const sport of sportsToTest) {
        for (const tab of tabsToTest) {
          const filename = `tab-${sport ? `${sport}-` : ""}${tab}.png`
          if (!existsSync(join(GOLDENS_DIR, filename))) missing.push(filename)
        }
      }
      if (missing.length > 0) {
        throw new Error(`Missing visual golden(s): ${missing.join(", ")}`)
      }
    }

    // Screenshots must not depend on the user's persisted display toggles.
    // Normalize them temporarily, then restore every value in finally.
    if (!initialMockMode) {
      ipc("setMockMode", "true")
      await sleep(300)
      if (String(ipc("getMockMode")).trim().toLowerCase() !== "true") {
        throw new Error("deterministic mock mode could not be enabled")
      }
    }
    await ensureToggle("getAntiSpoiler", "toggleSpoiler", false)
    await ensureToggle("getBackgroundUpdates", "toggleBackgroundUpdates", true)
    await ensureToggle("getBarTicker", "toggleBarTicker", true)
    await ensureToggle("getSpotlight", "toggleSpotlight", true)
    await ensureToggle("getNewsWire", "toggleNewsWire", true)
    // Toasts are external to the panel and make screenshots nondeterministic.
    await setBoolean("setNotifications", "getNotifications", false)
    // Let any notification already emitted before the test expire before the
    // first capture. This avoids including another process's toast in a panel
    // golden while still restoring the user's notification setting afterward.
    await sleep(6000)

    headlessMonitor = setupHeadlessMonitor()
    await sleep(400)
    ipc("setTargetScreen", headlessMonitor)
    if (ipc("getTargetScreen") !== headlessMonitor) {
      throw new Error("panel did not accept the headless target screen")
    }

    ipc("setSuppressFocus", "true")
    if (ipc("getSuppressFocus").toLowerCase() !== "true") {
      throw new Error("focus suppression could not be confirmed")
    }

    for (const sport of sportsToTest) {
      let isFirstTab = true
      for (const tab of tabsToTest) {
        try {
          const res = await captureTab(tab, sport, isFirstTab)
          if (res.status === "FAIL") anyFailed = true
          results.push(res)
        } catch (err) {
          anyFailed = true
          console.error(`    ✗ Failed: ${err.message}`)
          results.push({
            tab,
            sport,
            filename: `tab-${sport}-${tab}.png`,
            error: err.message,
            status: "FAIL"
          })
        }
        isFirstTab = false
      }
    }
  } catch (error) {
    anyFailed = true
    console.error(`  ✗ Visual suite aborted safely: ${error.message}`)
  } finally {
    console.log("\n  🧹 Restoring session state...")
    const cleanup = (label, fn) => {
      try { fn() } catch (error) {
        cleanupErrors.push(`${label}: ${error.message}`)
        console.error(`  ⚠️ Cleanup failed — ${label}: ${error.message}`)
      }
    }
    const cleanupAsync = async (label, fn) => {
      try { await fn() } catch (error) {
        cleanupErrors.push(`${label}: ${error.message}`)
        console.error(`  ⚠️ Cleanup failed — ${label}: ${error.message}`)
      }
    }
    cleanup("close", () => ipc("close"))
    await sleep(400)
    await cleanupAsync("anti-spoiler", () => ensureToggle("getAntiSpoiler", "toggleSpoiler", initialAntiSpoiler))
    await cleanupAsync("background updates", () => ensureToggle("getBackgroundUpdates", "toggleBackgroundUpdates", initialBackgroundUpdates))
    await cleanupAsync("bar ticker", () => ensureToggle("getBarTicker", "toggleBarTicker", initialBarTicker))
    await cleanupAsync("spotlight", () => ensureToggle("getSpotlight", "toggleSpotlight", initialSpotlight))
    await cleanupAsync("news wire", () => ensureToggle("getNewsWire", "toggleNewsWire", initialNewsWire))
    await cleanupAsync("notifications", () => setBoolean("setNotifications", "getNotifications", initialNotifications))
    cleanup("sport", () => ipc("sport", initialSport))
    cleanup("route", () => {
      if (initialRoute === "fixtures") ipc("scheduleSection", initialSection)
      else ipc("route", initialRoute)
    })
    cleanup("close after route restore", () => ipc("close"))
    await sleep(400)
    cleanup("target screen", () => {
      ipc("setTargetScreen", initialTargetScreen)
      if (ipc("getTargetScreen") !== initialTargetScreen) throw new Error("target screen did not restore")
    })
    cleanup("focus suppression", () => {
      ipc("setSuppressFocus", initialSuppressFocus)
      if (ipc("getSuppressFocus") !== initialSuppressFocus) throw new Error("focus state did not restore")
    })
    cleanup("visibility", () => {
      if (initialOpened) ipc("open")
      else ipc("close")
    })
    await sleep(400)
    cleanup("visibility verification", () => {
      if ((String(ipc("getOpened")).trim().toLowerCase() === "true") !== initialOpened) {
        throw new Error("panel visibility did not restore")
      }
    })
    cleanup("headless monitor removal", () => removeHeadlessMonitor(headlessMonitor))
    if (!initialMockMode) {
      cleanup("mock mode", () => ipc("setMockMode", "false"))
      await sleep(300)
    }
    if (cleanupErrors.length > 0) anyFailed = true
    else console.log("  ✓ Session state restored. User workspace untouched.")
  }

  generateHtmlReport(results)

  console.log("==================================================")
  const passCount = results.filter(r => r.status === "PASS").length
  console.log(`  Visual Testing Completed: ${passCount}/${results.length} views verified.`)
  console.log(`  Report generated: test-artifacts/visual-report.html`)
  console.log("==================================================")

  if (anyFailed) process.exit(1)
}

function generateHtmlReport(results) {
  const timestamp = new Date().toLocaleString()
  const cards = results.map(r => {
    const hasDiff = Boolean(r.diffFilename && r.goldenFilename)
    return `
    <div class="card ${r.status === 'PASS' ? 'pass' : 'fail'}">
      <div class="card-header">
        <div class="card-title">
          <span class="badge ${r.status === 'PASS' ? 'badge-pass' : 'badge-fail'}">${r.status}</span>
          <strong>${r.tab.toUpperCase()}</strong>
          <span class="sport">(${r.sport})</span>
        </div>
        <div class="meta-row">
          ${r.diffPercent !== null ? `<span class="diff-badge ${r.diffPercent <= TOLERANCE ? 'diff-pass' : 'diff-fail'}">Δ ${r.diffPercent}%</span>` : ''}
          <span class="meta">${r.sizeKb ? `${r.sizeKb} KB` : 'No Image'}</span>
        </div>
      </div>
      ${r.error ? `<div class="error-msg">${r.error}</div>` : `
        <div class="views-grid ${hasDiff ? 'views-diff-3' : 'views-single'}">
          ${hasDiff ? `
            <div class="view-panel">
              <span class="view-label">Approved Baseline</span>
              <a href="${r.goldenFilename}" target="_blank">
                <img src="${r.goldenFilename}" alt="Baseline" />
              </a>
            </div>
            <div class="view-panel">
              <span class="view-label">Current Candidate</span>
              <a href="${r.filename}" target="_blank">
                <img src="${r.filename}" alt="Candidate" />
              </a>
            </div>
            <div class="view-panel">
              <span class="view-label">Perceptual Diff Heatmap</span>
              <a href="${r.diffFilename}" target="_blank">
                <img src="${r.diffFilename}" alt="Diff Heatmap" />
              </a>
            </div>
          ` : `
            <div class="view-panel">
              <a href="${r.filename}" target="_blank">
                <img src="${r.filename}" alt="${r.tab} screenshot" />
              </a>
            </div>
          `}
        </div>
      `}
    </div>
  `}).join("")

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>OMASports S-Tier Visual Regression Report</title>
  <style>
    :root {
      --bg: #0b0f17;
      --card-bg: #141b26;
      --card-border: #1f2937;
      --fg: #f1f5f9;
      --muted: #94a3b8;
      --accent: #38bdf8;
      --pass: #34d399;
      --fail: #f87171;
    }
    body {
      background: var(--bg);
      color: var(--fg);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, monospace;
      margin: 0;
      padding: 24px;
    }
    h1 {
      font-size: 22px;
      margin-bottom: 4px;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .subtitle {
      color: var(--muted);
      font-size: 13px;
      margin-bottom: 24px;
    }
    .grid {
      display: flex;
      flex-direction: column;
      gap: 24px;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 10px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }
    .card.fail {
      border-color: var(--fail);
    }
    .card-header {
      padding: 12px 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid var(--card-border);
      background: rgba(255, 255, 255, 0.02);
    }
    .card-title {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .meta-row {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .badge {
      font-size: 11px;
      font-weight: bold;
      padding: 3px 8px;
      border-radius: 4px;
    }
    .badge-pass {
      background: rgba(52, 211, 153, 0.2);
      color: var(--pass);
      border: 1px solid var(--pass);
    }
    .badge-fail {
      background: rgba(248, 113, 113, 0.2);
      color: var(--fail);
      border: 1px solid var(--fail);
    }
    .diff-badge {
      font-size: 11px;
      font-weight: bold;
      padding: 2px 6px;
      border-radius: 4px;
    }
    .diff-pass {
      background: rgba(56, 189, 248, 0.15);
      color: var(--accent);
      border: 1px solid var(--accent);
    }
    .diff-fail {
      background: rgba(248, 113, 113, 0.2);
      color: var(--fail);
      border: 1px solid var(--fail);
    }
    .sport {
      color: var(--muted);
      font-size: 13px;
    }
    .meta {
      font-size: 12px;
      color: var(--muted);
    }
    .views-grid {
      padding: 16px;
      background: #070a0e;
      display: grid;
      gap: 16px;
    }
    .views-diff-3 {
      grid-template-columns: repeat(3, 1fr);
    }
    .views-single {
      display: flex;
      justify-content: center;
    }
    .view-panel {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
    }
    .view-label {
      font-size: 11px;
      font-weight: 600;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .view-panel img {
      max-width: 100%;
      height: auto;
      border-radius: 6px;
      border: 1px solid rgba(255, 255, 255, 0.08);
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.6);
    }
    .error-msg {
      padding: 16px;
      color: var(--fail);
      font-size: 13px;
    }
  </style>
</head>
<body>
  <h1>⚽ OMASports S-Tier Visual Regression Report</h1>
  <div class="subtitle">Generated automatically at ${timestamp} — Non-interruptive Headless Comparative Suite</div>
  <div class="grid">
    ${cards}
  </div>
</body>
</html>`

  writeFileSync(join(ARTIFACTS_DIR, "visual-report.html"), html, "utf8")
}

run()
