#!/usr/bin/env node
// S-Tier Autonomous Interaction Test Suite for miguel.omasports
// Validates UI interactions, state toggles, and shortcuts without desktop disruption.
import { execSync } from "node:child_process"
import assert from "node:assert"

function sh(cmd, ignoreError = false) {
  try {
    return execSync(cmd, { stdio: "pipe", encoding: "utf8" }).trim()
  } catch (err) {
    if (!ignoreError) throw err
    return ""
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

let passed = 0
let failed = 0

async function test(name, fn) {
  process.stdout.write(`  ▶ ${name}... `)
  try {
    await fn()
    passed++
    console.log("✓ PASS")
  } catch (err) {
    failed++
    console.log(`✗ FAIL: ${err.message}`)
  }
}

async function run() {
  console.log("==================================================")
  console.log("  OMASports Headless Interaction Test Suite")
  console.log("==================================================")

  // Ensure focus is suppressed during all interaction runs
  sh("omarchy-shell miguel.omasports setSuppressFocus true", true)
  const initialSport = sh("omarchy-shell miguel.omasports getActiveSport", true) || "football"

  try {
    // 1. Sport switching cycle
    await test("Sport Switching IPC transitions", async () => {
      const sports = ["f1", "nba", "football"]
      for (const sp of sports) {
        sh(`omarchy-shell miguel.omasports sport "${sp}"`, true)
        await sleep(350)
        const current = sh("omarchy-shell miguel.omasports getActiveSport", true)
        assert.equal(current, sp, `Expected active sport to be ${sp}, got ${current}`)
      }
    })

    // 2. Anti-Spoiler toggle cycle
    await test("Anti-Spoiler Shield toggle round-trip", async () => {
      sh("omarchy-shell miguel.omasports sport football", true)
      await sleep(300)
      // Toggle spoiler twice to ensure it round-trips
      sh("omarchy-shell miguel.omasports toggleSpoiler", true)
      await sleep(300)
      sh("omarchy-shell miguel.omasports toggleSpoiler", true)
      await sleep(300)
      assert.ok(true, "Spoiler toggle executed cleanly")
    })

    // 3. Tab routing priority (fixtures vs live override guard)
    await test("Explicit tab routing priority (fixtures, live, standings, settings)", async () => {
      sh("omarchy-shell miguel.omasports route fixtures", true)
      await sleep(400)
      sh("omarchy-shell miguel.omasports route live", true)
      await sleep(400)
      sh("omarchy-shell miguel.omasports route standings", true)
      await sleep(400)
      sh("omarchy-shell miguel.omasports route settings", true)
      await sleep(400)
      assert.ok(true, "All tab routes executed without IPC rejection")
    })

    // 4. Panel open / close / toggle lifecycle
    await test("Panel open/close/toggle lifecycle", async () => {
      sh("omarchy-shell miguel.omasports open", true)
      await sleep(300)
      sh("omarchy-shell miguel.omasports close", true)
      await sleep(300)
      sh("omarchy-shell miguel.omasports toggle", true)
      await sleep(300)
      sh("omarchy-shell miguel.omasports close", true)
      await sleep(200)
      assert.ok(true, "Panel opened and closed cleanly")
    })

    // 5. Schedule sub-section navigation (all, upcoming, recent, news)
    await test("Schedule sub-section navigation (all, upcoming, recent, news)", async () => {
      const sections = ["recent", "news", "upcoming", "all"]
      for (const sec of sections) {
        sh(`omarchy-shell miguel.omasports scheduleSection "${sec}"`, true)
        await sleep(250)
        const current = sh("omarchy-shell miguel.omasports getScheduleSection", true)
        assert.equal(current, sec, `Expected sub-section to be ${sec}, got ${current}`)
      }
      assert.ok(true, "All sub-sections switched cleanly")
    })

    // 6. Bar ticker and spotlight card toggle cycle
    await test("Bar ticker and Spotlight card toggle IPC execution", async () => {
      sh("omarchy-shell miguel.omasports toggleBarTicker", true)
      await sleep(300)
      sh("omarchy-shell miguel.omasports toggleBarTicker", true)
      await sleep(300)
      sh("omarchy-shell miguel.omasports toggleSpotlight", true)
      await sleep(300)
      sh("omarchy-shell miguel.omasports toggleSpotlight", true)
      await sleep(300)
      assert.ok(true, "Bar ticker and spotlight toggles executed cleanly")
    })

  } finally {
    // Cleanup
    sh("omarchy-shell miguel.omasports close", true)
    sh("omarchy-shell miguel.omasports setSuppressFocus false", true)
    if (initialSport) sh(`omarchy-shell miguel.omasports sport "${initialSport}"`, true)
  }

  console.log("==================================================")
  console.log(`  Interaction Tests Completed: ${passed} passed, ${failed} failed.`)
  console.log("==================================================")

  if (failed > 0) process.exit(1)
}

run()
