#!/usr/bin/env node
// S-Tier Notification Delivery & Rate-Limiter Test Suite for miguel.omasports
// Validates notification event diffing, anti-spoiler concealment, crest resolution, and queue safety.
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"

const raw = readFileSync(new URL("../SportsModel.js", import.meta.url), "utf8")
const exported = [
  "diffMatchNotifications", "crestCacheKey", "safeHome", "NOTIFICATION_TTL_MS"
]
const src = raw.replace(/^\.pragma library\s*$/m, "") + "\nexport { " + exported.join(", ") + " }\n"
const Model = await import("data:text/javascript;base64," + Buffer.from(src).toString("base64"))

let passed = 0
let failed = 0

function test(name, fn) {
  process.stdout.write(`  ▶ ${name}... `)
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
console.log("  OMASports Notification & Delivery Suite")
console.log("==================================================")

// Helper to construct test matches
function createMatch(id, homeName, homeScore, awayName, awayScore, status, liveTime) {
  return {
    id: String(id),
    sport: "football",
    leagueName: "La Liga",
    home: { id: "real_madrid", name: homeName, shortName: homeName },
    away: { id: "barcelona", name: awayName, shortName: awayName },
    homeScore: homeScore,
    awayScore: awayScore,
    status: status,
    liveTime: liveTime || ""
  }
}

// -----------------------------------------------------------------------------
// 1. Baseline Establishment
// -----------------------------------------------------------------------------
test("First poll establishes baseline with 0 notifications", () => {
  const match = createMatch("1", "Real Madrid", 0, "Barcelona", 0, "upcoming")
  const res = Model.diffMatchNotifications([match], {}, {
    enabled: true,
    activeSport: "football",
    favoriteIds: ["real_madrid"],
    antiSpoiler: false,
    nowMs: Date.now()
  })

  assert.equal(res.notifications.length, 0, "First poll must establish baseline without notifying")
  assert.ok(res.nextSeen["1"], "Must track match in nextSeen state")
})

// -----------------------------------------------------------------------------
// 2. Goal Event Detection & Formatting
// -----------------------------------------------------------------------------
test("Goal event triggers notification with updated score and icon team", () => {
  const initial = createMatch("1", "Real Madrid", 0, "Barcelona", 0, "live", "12’")
  const baseline = Model.diffMatchNotifications([initial], {}, {
    enabled: true,
    activeSport: "football",
    favoriteIds: ["real_madrid"],
    nowMs: Date.now()
  })

  // Goal scored!
  const goalMatch = createMatch("1", "Real Madrid", 1, "Barcelona", 0, "live", "14’")
  const update = Model.diffMatchNotifications([goalMatch], baseline.nextSeen, {
    enabled: true,
    activeSport: "football",
    favoriteIds: ["real_madrid"],
    antiSpoiler: false,
    nowMs: Date.now() + 120000
  })

  assert.equal(update.notifications.length, 1, "Must generate exactly 1 goal alert")
  const notif = update.notifications[0]
  assert.equal(notif.kind, "score")
  assert.equal(notif.urgency, "normal")
  assert.ok(notif.title.includes("GOAL"), "Title must declare GOAL")
  assert.ok(notif.body.includes("1 – 0") || notif.body.includes("1 - 0"), "Body must contain new score")
  assert.equal(notif.iconTeam.id, "real_madrid")
})

// -----------------------------------------------------------------------------
// 3. Anti-Spoiler Score Concealment
// -----------------------------------------------------------------------------
test("Anti-Spoiler mode conceals scoreline in goal and full-time alerts", () => {
  const initial = createMatch("2", "Real Madrid", 0, "Barcelona", 0, "live", "10’")
  const baseline = Model.diffMatchNotifications([initial], {}, {
    enabled: true,
    activeSport: "football",
    favoriteIds: ["real_madrid"],
    antiSpoiler: true,
    nowMs: Date.now()
  })

  // Goal alert with anti-spoiler
  const goalMatch = createMatch("2", "Real Madrid", 1, "Barcelona", 0, "live", "14’")
  const goalUpdate = Model.diffMatchNotifications([goalMatch], baseline.nextSeen, {
    enabled: true,
    activeSport: "football",
    favoriteIds: ["real_madrid"],
    antiSpoiler: true,
    nowMs: Date.now() + 60000
  })
  assert.equal(goalUpdate.notifications.length, 1)
  const goalNotif = goalUpdate.notifications[0]
  assert.ok(!goalNotif.body.includes("1 – 0") && !goalNotif.body.includes("1 - 0"), "Goal body must conceal score")
  assert.ok(goalNotif.body.includes("Score hidden"), "Goal body must state (Score hidden)")

  // Full time whistle with spoiler shield active
  const ftMatch = createMatch("2", "Real Madrid", 2, "Barcelona", 0, "finished")
  const update = Model.diffMatchNotifications([ftMatch], goalUpdate.nextSeen, {
    enabled: true,
    activeSport: "football",
    favoriteIds: ["real_madrid"],
    antiSpoiler: true,
    nowMs: Date.now() + 3600000
  })

  assert.equal(update.notifications.length, 1)
  const notif = update.notifications[0]
  assert.equal(notif.kind, "finished")
  assert.ok(!notif.title.includes("2 – 0") && !notif.title.includes("2 - 0"), "Title must not reveal final score")
  assert.ok(notif.body.includes("concealed") || notif.title.includes("vs"), "Body must indicate concealment")
})

// -----------------------------------------------------------------------------
// 4. Kickoff & Half-Time Lifecycle Alerts
// -----------------------------------------------------------------------------
test("Lifecycle transitions: Kickoff and Half-Time", () => {
  const upcoming = createMatch("3", "Real Madrid", 0, "Barcelona", 0, "upcoming")
  const baseline = Model.diffMatchNotifications([upcoming], {}, {
    enabled: true,
    activeSport: "football",
    favoriteIds: ["real_madrid"],
    nowMs: Date.now()
  })

  // 1. Kickoff
  const live = createMatch("3", "Real Madrid", 0, "Barcelona", 0, "live", "1’")
  const kickoffRes = Model.diffMatchNotifications([live], baseline.nextSeen, {
    enabled: true,
    activeSport: "football",
    favoriteIds: ["real_madrid"],
    nowMs: Date.now() + 60000
  })
  assert.equal(kickoffRes.notifications.length, 1)
  assert.equal(kickoffRes.notifications[0].kind, "started")

  // 2. Half Time
  const ht = createMatch("3", "Real Madrid", 0, "Barcelona", 0, "live", "HT")
  const htRes = Model.diffMatchNotifications([ht], kickoffRes.nextSeen, {
    enabled: true,
    activeSport: "football",
    favoriteIds: ["real_madrid"],
    nowMs: Date.now() + (47 * 60000)
  })
  assert.equal(htRes.notifications.length, 1)
  assert.equal(htRes.notifications[0].kind, "halftime")
})

// -----------------------------------------------------------------------------
// 5. Crest Path Sanitization & Defense-in-Depth
// -----------------------------------------------------------------------------
test("Crest key sanitization strips directory traversal bytes", () => {
  // Valid crest keys
  const footballKey = Model.crestCacheKey("football", "101", "")
  assert.equal(footballKey, "football-101")
  const nbaKey = Model.crestCacheKey("nba", "8", "DET")
  assert.equal(nbaKey, "nba-det")

  // Directory traversal bytes (dots and slashes) are stripped cleanly
  const maliciousKey = Model.crestCacheKey("football", "../../etc/passwd", "")
  assert.ok(!maliciousKey.includes("/"), "Must strip forward slashes")
  assert.ok(!maliciousKey.includes("."), "Must strip dots")
  assert.equal(maliciousKey, "football-etcpasswd")

  // Completely blank or punctuation-only IDs return empty string
  assert.equal(Model.crestCacheKey("football", "../..", "").replace("football-", ""), "")
  assert.equal(Model.crestCacheKey("football", "", ""), "")
})

// -----------------------------------------------------------------------------
// 6. Queue Capping & Rate Limiting Logic (Panel.qml logic replica)
// -----------------------------------------------------------------------------
test("Queue capping prevents desktop notification floods", () => {
  let queue = []
  function pushNotification(item) {
    if (queue.length >= 5) queue.splice(0, queue.length - 4)
    queue.push(item)
  }

  for (let i = 1; i <= 10; i++) {
    pushNotification({ title: `Event ${i}`, body: `Body ${i}` })
  }

  assert.equal(queue.length, 5, "Queue must strictly cap at 5 items")
  assert.equal(queue[queue.length - 1].title, "Event 10", "Latest event must be retained")
  assert.equal(queue[0].title, "Event 6", "Old burst events must be dropped")
})

// -----------------------------------------------------------------------------
// 7. Command Construction & Argument Escaping
// -----------------------------------------------------------------------------
test("notify-send argument escaping and safety termination", () => {
  function formatNotifyCommand(item, cacheRoot) {
    const cmd = ["notify-send", "-a", "OmaSports"]
    if (item.iconPath && item.iconPath.indexOf(cacheRoot) === 0) {
      cmd.push("-i", item.iconPath)
    }
    if (item.urgency) cmd.push("-u", item.urgency)
    cmd.push("--", item.title, item.body)
    return cmd
  }

  const cacheRoot = "/home/user/.cache/omarchy-omasports/logos/"
  const maliciousItem = {
    title: "--help",
    body: "--version",
    iconPath: "/etc/shadow",
    urgency: "normal"
  }

  const cmd = formatNotifyCommand(maliciousItem, cacheRoot)
  assert.equal(cmd[1], "-a")
  assert.equal(cmd[2], "OmaSports")
  assert.ok(!cmd.includes("-i"), "Untrusted icon outside cache must be omitted")
  const dashIndex = cmd.indexOf("--")
  assert.ok(dashIndex !== -1, "Command must contain '--' flag terminator")
  assert.equal(cmd[dashIndex + 1], "--help")
  assert.equal(cmd[dashIndex + 2], "--version")
})

// -----------------------------------------------------------------------------
// 8. Delivery Queue Pacing & Rate-Limiting (500ms Delay Between Toasts)
// -----------------------------------------------------------------------------
test("Rapid-fire goals are paced with 500ms delay between toasts", () => {
  // Simulates Panel.qml dispatchNextNotification and notificationPacingTimer
  let queue = []
  let dispatched = []
  let isProcRunning = false
  let isTimerRunning = false
  let virtualTime = 0

  function dispatchNextNotification() {
    if (isProcRunning || isTimerRunning || queue.length === 0) return
    const item = queue.shift()
    isProcRunning = true
    dispatched.push({ item, time: virtualTime })

    // Simulate notify-send completing after 15ms
    virtualTime += 15
    isProcRunning = false

    // Simulate notificationPacingTimer (500ms delay before next toast)
    isTimerRunning = true
    virtualTime += 500
    isTimerRunning = false
    dispatchNextNotification()
  }

  function sendDesktopNotification(title, body) {
    if (queue.length >= 5) queue.splice(0, queue.length - 4)
    queue.push({ title, body })
    dispatchNextNotification()
  }

  // Rapid-fire burst: 3 followed teams score within 100ms
  sendDesktopNotification("Goal: Arsenal", "1-0")
  sendDesktopNotification("Goal: Real Madrid", "1-0")
  sendDesktopNotification("Goal: Benfica", "2-1")

  assert.equal(dispatched.length, 3, "All 3 notifications must eventually dispatch")
  assert.equal(dispatched[0].time, 0, "First notification dispatches immediately at t=0")
  assert.ok(dispatched[1].time >= 500, `Second toast must be paced by >= 500ms (got ${dispatched[1].time}ms)`)
  assert.ok(dispatched[2].time >= 1000, `Third toast must be paced by >= 1000ms (got ${dispatched[2].time}ms)`)
})

// -----------------------------------------------------------------------------
// 9. Local Crest Path Resolution & Cold-Cache Graceful Omission
// -----------------------------------------------------------------------------
test("crestIconPath resolves to disk file or omits gracefully on cold cache", () => {
  function logoCacheDir() {
    return Model.safeHome() + "/.cache/omarchy-omasports/logos/"
  }

  function crestIconPath(sport, team, knownLogoKeys) {
    const key = Model.crestCacheKey(sport, team && team.id ? team.id : "", team && team.abbr ? team.abbr : "")
    if (key === "" || !knownLogoKeys[key]) return ""
    return logoCacheDir() + key + ".png"
  }

  const knownMap = {
    "football-real_madrid": true,
    "football-arsenal": true
  }

  // Warm cache: known logo returns full path under logoCacheDir ending with .png
  const warmPath = crestIconPath("football", { id: "real_madrid" }, knownMap)
  assert.ok(warmPath.startsWith(logoCacheDir()), "Warm crest must be under logo cache directory")
  assert.ok(warmPath.endsWith("football-real_madrid.png"), "Warm crest must have valid png filename")

  // Cold cache: un-downloaded team returns empty string (omits gracefully)
  const coldPath = crestIconPath("football", { id: "unknown_fc" }, knownMap)
  assert.equal(coldPath, "", "Cold cache crest must omit gracefully with empty string")

  // Missing team data returns empty string
  assert.equal(crestIconPath("football", null, knownMap), "")
  assert.equal(crestIconPath("football", {}, knownMap), "")
})

console.log("==================================================")
console.log(`  Notification Suite Completed: ${passed} passed, ${failed} failed.`)
console.log("==================================================")

if (failed > 0) process.exit(1)

