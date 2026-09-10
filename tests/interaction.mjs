#!/usr/bin/env node
// Safe headless interaction test suite for miguel.omasports.
// This suite is intentionally opt-in from run-all/pre-commit because it talks
// to the live shell. It refuses to run unless a virtual Hyprland monitor is
// provisioned and focus suppression is confirmed through IPC.
import { execFileSync } from "node:child_process"
import assert from "node:assert/strict"

function runCommand(command, args = []) {
  return execFileSync(command, args, { stdio: "pipe", encoding: "utf8" }).trim()
}

function hasCommand(command) {
  try {
    runCommand("which", [command])
    return true
  } catch {
    return false
  }
}

function ipc(method, ...args) {
  return runCommand("omarchy-shell", ["miguel.omasports", method, ...args])
}

function bool(value) {
  return String(value).trim().toLowerCase() === "true"
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function headlessMonitors() {
  if (!hasCommand("hyprctl")) return []
  const output = runCommand("hyprctl", ["monitors"])
  return [...output.matchAll(/Monitor (HEADLESS-\d+)/g)].map((match) => match[1])
}

function createHeadlessMonitor() {
  if (!hasCommand("hyprctl")) {
    throw new Error("hyprctl is required; refusing to run interaction tests on a physical screen")
  }
  const before = headlessMonitors()
  let created = null
  try {
    const output = runCommand("hyprctl", ["output", "create", "headless"])
    created = output.match(/HEADLESS-\d+/)?.[0] || null
    if (!created) {
      const after = headlessMonitors()
      created = after.find((name) => !before.includes(name)) || null
    }
    if (!created) throw new Error("Hyprland did not create a headless monitor")
    return created
  } catch (error) {
    // If Hyprland created an output but returned an unexpected response, remove
    // the newly discovered output here so the caller cannot lose its identity.
    try {
      const after = headlessMonitors()
      const leaked = created || after.find((name) => !before.includes(name))
      if (leaked) runCommand("hyprctl", ["output", "remove", leaked])
    } catch {}
    throw error
  }
}

function removeHeadlessMonitor(name) {
  if (!name) return
  try { runCommand("hyprctl", ["output", "remove", name]) } catch (error) {
    console.error(`  ⚠️ Failed to remove ${name}: ${error.message}`)
    throw error
  }
}

let passed = 0
let failed = 0

async function test(name, fn) {
  process.stdout.write(`  ▶ ${name}... `)
  try {
    await fn()
    passed++
    console.log("✓ PASS")
  } catch (error) {
    failed++
    console.log(`✗ FAIL: ${error.message}`)
  }
}

function restoreToggle(getter, toggle, expected) {
  if (bool(ipc(getter)) !== expected) ipc(toggle)
  assert.equal(bool(ipc(getter)), expected, `${getter} did not restore`)
}

async function run() {
  console.log("==================================================")
  console.log("  OMASports Safe Headless Interaction Test Suite")
  console.log("==================================================")

  // Snapshot every state value this suite can touch before creating a monitor.
  // Any failure here is a hard failure, never an on-screen fallback.
  const initial = {
    sport: ipc("getActiveSport") || "football",
    route: ipc("getRoute") || "fixtures",
    section: ipc("getScheduleSection") || "all",
    antiSpoiler: bool(ipc("getAntiSpoiler")),
    // Read these as part of the snapshot for diagnostics; this suite does not
    // mutate them, but keeping them visible makes future additions auditable.
    notifications: bool(ipc("getNotifications")),
    backgroundUpdates: bool(ipc("getBackgroundUpdates")),
    barTicker: bool(ipc("getBarTicker")),
    spotlight: bool(ipc("getSpotlight")),
    newsWire: bool(ipc("getNewsWire")),
    suppressFocus: bool(ipc("getSuppressFocus")),
    targetScreen: ipc("getTargetScreen") || "",
    opened: bool(ipc("getOpened"))
  }

  let headlessMonitor = null
  try {
    headlessMonitor = createHeadlessMonitor()
    ipc("setTargetScreen", headlessMonitor)
    assert.equal(ipc("getTargetScreen"), headlessMonitor, "panel was not routed to the headless monitor")

    ipc("setSuppressFocus", "true")
    assert.equal(bool(ipc("getSuppressFocus")), true, "focus suppression could not be confirmed")

    await test("Sport Switching IPC transitions", async () => {
      for (const sport of ["f1", "nba", "football"]) {
        ipc("sport", sport)
        await sleep(350)
        assert.equal(ipc("getActiveSport"), sport)
      }
    })

    await test("Anti-Spoiler Shield toggle round-trip", async () => {
      const before = bool(ipc("getAntiSpoiler"))
      ipc("toggleSpoiler")
      await sleep(300) // IPC toggle throttle is 250ms by design
      assert.equal(bool(ipc("getAntiSpoiler")), !before)
      ipc("toggleSpoiler")
      await sleep(300)
      assert.equal(bool(ipc("getAntiSpoiler")), before)
    })

    await test("Explicit route transitions", async () => {
      for (const route of ["fixtures", "live", "standings", "settings"]) {
        ipc("route", route)
        await sleep(100)
        assert.equal(ipc("getRoute"), route)
      }
    })

    await test("Panel open/close/toggle lifecycle", async () => {
      ipc("open")
      await sleep(400)
      assert.equal(bool(ipc("getOpened")), true)
      ipc("close")
      await sleep(400)
      assert.equal(bool(ipc("getOpened")), false)
      ipc("toggle")
      await sleep(400)
      assert.equal(bool(ipc("getOpened")), true)
      ipc("close")
      await sleep(400)
      assert.equal(bool(ipc("getOpened")), false)
    })

    await test("Schedule sub-section navigation", async () => {
      for (const section of ["recent", "news", "upcoming", "all"]) {
        ipc("scheduleSection", section)
        await sleep(100)
        assert.equal(ipc("getScheduleSection"), section)
      }
    })

    await test("Bar ticker and spotlight round-trips", async () => {
      const ticker = bool(ipc("getBarTicker"))
      const spotlight = bool(ipc("getSpotlight"))
      ipc("toggleBarTicker")
      await sleep(300)
      ipc("toggleSpotlight")
      await sleep(300)
      assert.equal(bool(ipc("getBarTicker")), !ticker)
      assert.equal(bool(ipc("getSpotlight")), !spotlight)
      ipc("toggleBarTicker")
      await sleep(300)
      ipc("toggleSpotlight")
      await sleep(300)
      assert.equal(bool(ipc("getBarTicker")), ticker)
      assert.equal(bool(ipc("getSpotlight")), spotlight)
    })
  } finally {
    const cleanupErrors = []
    const attempt = (label, fn) => {
      try { fn() } catch (error) {
        cleanupErrors.push(`${label}: ${error.message}`)
        console.error(`  ⚠️ Cleanup failed — ${label}: ${error.message}`)
      }
    }

    // Close before restoring routing so no test popup remains visible. The
    // original visibility is restored at the end of cleanup.
    attempt("close", () => ipc("close"))
    await sleep(400)
    attempt("anti-spoiler", () => restoreToggle("getAntiSpoiler", "toggleSpoiler", initial.antiSpoiler))
    attempt("bar ticker", () => restoreToggle("getBarTicker", "toggleBarTicker", initial.barTicker))
    attempt("spotlight", () => restoreToggle("getSpotlight", "toggleSpotlight", initial.spotlight))
    attempt("sport", () => ipc("sport", initial.sport))
    // scheduleSection routes to Fixtures, so restore it first and then apply
    // the original route to preserve both values for every starting view.
    attempt("schedule section", () => ipc("scheduleSection", initial.section))
    attempt("route", () => ipc("route", initial.route))
    attempt("close after route restore", () => ipc("close"))
    await sleep(400)
    attempt("target screen", () => {
      ipc("setTargetScreen", initial.targetScreen)
      assert.equal(ipc("getTargetScreen"), initial.targetScreen)
    })
    attempt("focus suppression", () => {
      ipc("setSuppressFocus", initial.suppressFocus ? "true" : "false")
      assert.equal(bool(ipc("getSuppressFocus")), initial.suppressFocus)
    })
    attempt("visibility", () => {
      if (initial.opened) ipc("open")
      else ipc("close")
    })
    await sleep(400)
    attempt("visibility verification", () => {
      assert.equal(bool(ipc("getOpened")), initial.opened, "panel visibility did not restore")
    })
    attempt("headless monitor removal", () => removeHeadlessMonitor(headlessMonitor))

    if (cleanupErrors.length > 0) {
      throw new Error(`desktop cleanup incomplete (${cleanupErrors.join("; ")})`)
    }
  }

  console.log("==================================================")
  console.log(`  Interaction Tests Completed: ${passed} passed, ${failed} failed.`)
  console.log("==================================================")
  if (failed > 0) process.exit(1)
}

run().catch((error) => {
  console.error(`\n❌ Interaction suite aborted safely: ${error.message}`)
  process.exit(1)
})
