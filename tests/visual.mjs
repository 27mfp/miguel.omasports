#!/usr/bin/env node
// Autonomous non-interruptive visual testing & perceptual diff suite for miguel.omasports
// Captures UI snapshots and runs pixel-level visual regression comparisons against goldens.
// Run with: node tests/visual.mjs [--tab=<name>] [--sport=<name>] [--delay=<ms>] [--update-goldens] [--tolerance=<percent>]
import { execSync } from "node:child_process"
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

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

const hasGrim = Boolean(sh("which grim", true))
const hasHyprctl = Boolean(sh("which hyprctl", true))
const hasMagick = Boolean(sh("which magick", true) || sh("which convert", true))
const hasPython3 = Boolean(sh("which python3", true))

if (!hasGrim) {
  console.error("Error: 'grim' is required for autonomous visual testing on Wayland.")
  process.exit(1)
}

let headlessMonitor = null

function setupHeadlessMonitor() {
  if (ON_SCREEN || !hasHyprctl) {
    console.log("  🖥️  Running in on-screen mode (focus suppression enabled).")
    return null
  }
  try {
    const out = sh("hyprctl output create headless", true)
    let mon = null
    const match = out.match(/HEADLESS-\d+/)
    if (match) {
      mon = match[0]
    } else {
      const monitors = sh("hyprctl monitors", true)
      const matches = [...monitors.matchAll(/Monitor (HEADLESS-\d+)/g)]
      if (matches.length > 0) {
        mon = matches[matches.length - 1][1]
      }
    }
    if (mon) {
      if (TARGET_SCALE) {
        try {
          sh(`hyprctl eval "hl.monitor({ output = '${mon}', mode = '1920x1080@60', position = 'auto', scale = ${TARGET_SCALE} })"`, true)
        } catch {
          sh(`hyprctl keyword monitor "${mon},1920x1080@60,auto,${TARGET_SCALE}"`, true)
        }
      }
      console.log(`  🕶️  Running in headless mode on virtual monitor: [${mon}] (scale: ${TARGET_SCALE}, zero screen popups, zero focus disruption)`)
      return mon
    }
  } catch (err) {
    console.warn(`    ⚠️ Failed to create headless output: ${err.message}. Falling back to on-screen.`)
  }
  return null
}

function removeHeadlessMonitor(mon) {
  if (!mon || !hasHyprctl) return
  try {
    sh(`hyprctl output remove "${mon}"`, true)
    console.log(`  🧹 Virtual monitor [${mon}] destroyed cleanly.`)
  } catch {}
}

const DEFAULT_ON_SCREEN_GEOMETRY = "1024,20 512x672"

async function captureTab(tabName, sport = null, isSportSwitch = false) {
  console.log(`\n  📸 Testing view: [${tabName.toUpperCase()}]${sport ? ` (sport: ${sport})` : ""}`)

  if (sport && isSportSwitch) {
    sh(`omarchy-shell miguel.omasports sport "${sport}"`, true)
    await sleep(2500)
  }

  if (tabName === "results") {
    sh(`omarchy-shell miguel.omasports route "fixtures"`, true)
    sh(`omarchy-shell miguel.omasports scheduleSection "results"`, true)
  } else if (tabName === "news") {
    sh(`omarchy-shell miguel.omasports route "fixtures"`, true)
    sh(`omarchy-shell miguel.omasports scheduleSection "news"`, true)
  } else {
    sh(`omarchy-shell miguel.omasports route "${tabName}"`, true)
  }
  await sleep(DELAY_MS)

  const filename = `tab-${sport ? `${sport}-` : ""}${tabName}.png`
  const filepath = join(ARTIFACTS_DIR, filename)
  const goldenPath = join(GOLDENS_DIR, filename)
  const diffFilename = `diff-${filename}`
  const diffPath = join(ARTIFACTS_DIR, diffFilename)

  if (headlessMonitor) {
    const rawPath = join(ARTIFACTS_DIR, `raw-${filename}`)
    sh(`grim -o "${headlessMonitor}" "${rawPath}"`)
    
    if (hasPython3 && existsSync(CROP_SCRIPT)) {
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
  } else {
    sh(`grim -g "${DEFAULT_ON_SCREEN_GEOMETRY}" "${filepath}"`)
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
  if (hasPython3) {
    try {
      const dimRaw = sh(`python3 -c "from PIL import Image; im = Image.open('${filepath}'); print(f'{im.width}x{im.height}')"`, true)
      if (dimRaw.includes("x")) {
        const [w, h] = dimRaw.split("x").map(Number)
        cardDimensions = { width: w, height: h }
        if (h > 850) {
          console.warn(`    ⚠️ Warning: Cropped card height (${h}px) exceeds 72% viewport budget.`)
        } else {
          console.log(`    📏 Card size: ${w}x${h}px (within 72% viewport limit) ✓`)
        }
      }
    } catch {}
  }

  // Perceptual Diffing vs Golden
  let diffResult = null
  let passed = true
  if (UPDATE_GOLDENS) {
    copyFileSync(filepath, goldenPath)
    console.log(`    🌟 Updated baseline golden: tests/fixtures/visual-goldens/${filename}`)
  } else if (existsSync(goldenPath)) {
    if (hasPython3 && existsSync(DIFF_SCRIPT)) {
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
      console.warn("    ⚠️ diff.py or python3 missing; cannot compare against baseline golden.")
      passed = false
    }
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

  const initialSport = sh("omarchy-shell miguel.omasports getActiveSport", true) || "football"
  console.log(`  📌 Initial active sport: ${initialSport}`)
  if (UPDATE_GOLDENS) console.log("  🌟 MODE: Updating baseline visual goldens")

  headlessMonitor = setupHeadlessMonitor()
  if (headlessMonitor) {
    await sleep(400)
    sh(`omarchy-shell miguel.omasports setTargetScreen "${headlessMonitor}"`, true)
  }

  sh("omarchy-shell miguel.omasports setSuppressFocus true", true)

  const sportsToTest = TARGET_SPORT === "all"
    ? ["football", "f1", "nba", "nfl", "mlb", "nhl"]
    : [TARGET_SPORT || initialSport]

  const tabsToTest = TARGET_TAB === "all" || !TARGET_TAB
    ? ["live", "fixtures", "standings", "settings"]
    : [TARGET_TAB]

  const results = []
  let anyFailed = false

  try {
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
  } finally {
    console.log("\n  🧹 Restoring session state...")
    sh("omarchy-shell miguel.omasports close", true)
    sh("omarchy-shell miguel.omasports setTargetScreen \"\"", true)
    sh("omarchy-shell miguel.omasports setSuppressFocus false", true)
    if (initialSport) {
      sh(`omarchy-shell miguel.omasports sport "${initialSport}"`, true)
    }
    if (headlessMonitor) {
      removeHeadlessMonitor(headlessMonitor)
    }
    console.log("  ✓ Session state restored. User workspace untouched.")
  }

  generateHtmlReport(results)

  console.log("==================================================")
  const passCount = results.filter(r => r.status === "PASS").length
  console.log(`  Visual Testing Completed: ${passCount}/${results.length} views verified.`)
  console.log(`  Report generated: test-artifacts/visual-report.html`)
  console.log("==================================================")

  if (anyFailed) {
    process.exit(1)
  }
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
