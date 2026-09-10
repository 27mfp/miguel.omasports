#!/usr/bin/env node
// OmaSports Unified S-Tier Master Test Runner
// Orchestrates Unit, Offline Golden, Scenario, Interaction, Validation, and Visual Diff tests.
// Run with: node tests/run-all.mjs [--quick] [--full]
import { execSync } from "node:child_process"

const ARGS = process.argv.slice(2)
const QUICK = ARGS.includes("--quick")
const FULL = ARGS.includes("--full")
const INTERACTIVE = ARGS.includes("--interactive")

function sh(cmd) {
  return execSync(cmd, { stdio: "pipe", encoding: "utf8" }).trim()
}

const steps = [
  {
    name: "Pure JS Unit Tests",
    file: "tests/sportsmodel.test.mjs",
    cmd: "node tests/sportsmodel.test.mjs"
  },
  {
    name: "Offline Provider Goldens",
    file: "tests/offline.mjs",
    cmd: "node tests/offline.mjs"
  },
  {
    name: "Manifest & Package Contract",
    file: "tests/manifest.mjs",
    cmd: "node tests/manifest.mjs"
  },
  {
    name: "QML Cross-File Contracts",
    file: "tests/qml-contract.mjs",
    cmd: "node tests/qml-contract.mjs"
  },
  {
    name: "Chaos & Edge-Case Scenarios",
    file: "tests/scenarios.mjs",
    cmd: "node tests/scenarios.mjs"
  },
  {
    name: "Notification & Delivery Suite",
    file: "tests/notifications.mjs",
    cmd: "node tests/notifications.mjs"
  },
  {
    name: "Crest Resilience & Fallbacks",
    file: "tests/crest-resilience.mjs",
    cmd: "node tests/crest-resilience.mjs"
  },
  {
    name: "Burn-In & Memory Stability",
    file: "tests/burnin.mjs",
    cmd: "node tests/burnin.mjs"
  },
  {
    name: "Omarchy Plugin Validation",
    file: "manifest.json",
    cmd: "omarchy plugin validate ."
  }
]

if (!QUICK) {
  steps.push({
    name: "Live Provider E2E Integration",
    file: "tests/live.mjs",
    cmd: FULL
      ? "node tests/live.mjs all"
      : "node tests/live.mjs football"
  })
  steps.push({
    name: "Perceptual Visual Regression",
    file: "tests/visual.mjs",
    cmd: FULL
      ? "node tests/visual.mjs --sport=all --tab=all"
      : "node tests/visual.mjs --sport=f1 --tab=standings"
  })
}

console.log("======================================================================")
console.log("  🏆 OMASports S-Tier Master Test Orchestrator")
if (INTERACTIVE) {
  steps.splice(3, 0, {
    name: "Safe Headless Interaction Suite",
    file: "tests/interaction.mjs",
    cmd: "node tests/interaction.mjs"
  })
}

console.log(`  Mode: ${FULL ? "FULL (All sports & views)" : (QUICK ? (INTERACTIVE ? "QUICK + HEADLESS INTERACTION" : "QUICK (Logic only)") : "STANDARD (Comprehensive with visual verification)")}`)
console.log("======================================================================")

const startTime = Date.now()
const results = []
let anyFailed = false

for (let i = 0; i < steps.length; i++) {
  const step = steps[i]
  const stepStart = Date.now()
  process.stdout.write(`\n[${i + 1}/${steps.length}] Running: ${step.name}...\n`)

  try {
    const out = sh(step.cmd)
    const elapsed = ((Date.now() - stepStart) / 1000).toFixed(2)
    // Extract last meaningful line for summary
    const lines = out.split("\n").filter(l => l.trim().length > 0)
    const lastLine = lines[lines.length - 1] || "Passed"
    console.log(`    ✓ PASSED (${elapsed}s) — ${lastLine}`)
    results.push({ name: step.name, status: "PASS", elapsed, detail: lastLine })
  } catch (err) {
    anyFailed = true
    const elapsed = ((Date.now() - stepStart) / 1000).toFixed(2)
    const errorMsg = (err.stderr || err.stdout || err.message).trim().split("\n")[0]
    console.error(`    ✗ FAILED (${elapsed}s) — ${errorMsg}`)
    results.push({ name: step.name, status: "FAIL", elapsed, detail: errorMsg })
  }
}

const totalElapsed = ((Date.now() - startTime) / 1000).toFixed(2)

console.log("\n======================================================================")
console.log("  📊 S-TIER TEST EXECUTION SUMMARY")
console.log("======================================================================")
console.log("  SUITE                                STATUS   TIME    DETAIL")
console.log("  --------------------------------------------------------------------")
for (const r of results) {
  const paddedName = r.name.padEnd(36)
  const statusStr = r.status === "PASS" ? "\x1b[32mPASS\x1b[0m  " : "\x1b[31mFAIL\x1b[0m  "
  const timeStr = `${r.elapsed}s`.padEnd(7)
  console.log(`  ${paddedName} ${statusStr} ${timeStr} ${r.detail.slice(0, 24)}`)
}
console.log("  --------------------------------------------------------------------")
console.log(`  Total Duration: ${totalElapsed}s | Passed: ${results.filter(r => r.status === "PASS").length}/${results.length}`)
console.log("======================================================================")

if (anyFailed) {
  console.error("\n❌ Test suite failed. Regressions detected.")
  process.exit(1)
} else {
  console.log("\n✅ ALL S-TIER QUALITY GATES PASSED. System is rock-solid.")
  process.exit(0)
}
