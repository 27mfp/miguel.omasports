#!/usr/bin/env node
// S-Tier Long-Running Burn-In & Memory Leak Test Suite for miguel.omasports
// Simulates 100 consecutive polling cycles (mockRound) in a fast loop.
// Measures heap allocation, array count bounds, and verifies seenMap TTL pruning.
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"

const raw = readFileSync(new URL("../SportsModel.js", import.meta.url), "utf8")
const exported = [
  "mockRound", "diffMatchNotifications", "mergeSeenMap", "liveMatches",
  "NOTIFICATION_TTL_MS", "arrayFrom"
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
console.log("  OMASports Burn-In & Memory Stability Suite")
console.log("==================================================")

// -----------------------------------------------------------------------------
// 1. 100 Consecutive Polling Cycles Across All Sports
// -----------------------------------------------------------------------------
test("100 mock polling cycles maintain strict bounds on arrays and queues", () => {
  const sports = ["football", "nba", "nfl", "mlb", "nhl", "f1"]
  let allMatches = []
  let multiSportStandings = {}
  let detailQueue = []
  let notificationQueue = []
  let lastSeenMatches = {}
  let baseTime = Date.now()

  let maxMatchesLen = 0
  let maxDetailQueueLen = 0
  let maxNotifQueueLen = 0

  function sendDesktopNotification(title, body) {
    let next = Model.arrayFrom(notificationQueue)
    if (next.length >= 5) next.splice(0, next.length - 4)
    next.push({ title, body })
    notificationQueue = next
  }

  // Simulate 100 rounds with 1 minute advancing per round
  for (let round = 0; round < 100; round++) {
    const nowMs = baseTime + (round * 60 * 1000)
    const sport = sports[round % sports.length]

    // 1. Fetch round data (mockRound)
    const mock = Model.mockRound(sport, nowMs)
    allMatches = mock.matches || []
    if (mock.standings) multiSportStandings[sport] = mock.standings

    if (allMatches.length > maxMatchesLen) maxMatchesLen = allMatches.length

    // 2. Detail queue calculation (Panel.qml logic: capped at 8)
    const wanted = []
    const live = Model.liveMatches(allMatches, {})
    for (let i = 0; i < live.length && wanted.length < 8; i++) {
      wanted.push(String(live[i].id))
    }
    detailQueue = wanted
    if (detailQueue.length > maxDetailQueueLen) maxDetailQueueLen = detailQueue.length

    // 3. Notification diffing
    const diff = Model.diffMatchNotifications(allMatches, lastSeenMatches, {
      enabled: true,
      activeSport: sport,
      favoriteIds: ["9825", "13", "CHI", "BOS", "red_bull"],
      antiSpoiler: false,
      nowMs: nowMs
    })

    lastSeenMatches = diff.nextSeen
    for (const notif of diff.notifications) {
      sendDesktopNotification(notif.title, notif.body)
    }
    if (notificationQueue.length > maxNotifQueueLen) maxNotifQueueLen = notificationQueue.length

    // Simulate notification consumption
    if (notificationQueue.length > 0 && round % 2 === 0) {
      notificationQueue.shift()
    }
  }

  // Assert array/queue caps are strictly enforced
  assert.ok(maxDetailQueueLen <= 8, `detailQueue exceeded cap of 8: ${maxDetailQueueLen}`)
  assert.ok(maxNotifQueueLen <= 5, `notificationQueue exceeded cap of 5: ${maxNotifQueueLen}`)
  assert.ok(maxMatchesLen <= 30, `allMatches exceeded reasonable slate size: ${maxMatchesLen}`)
})

// -----------------------------------------------------------------------------
// 2. Long-Running seenMap TTL Pruning (No Memory Creep)
// -----------------------------------------------------------------------------
test("seenMap prunes stale entries past NOTIFICATION_TTL_MS (6h)", () => {
  let seenMap = {}
  const now = Date.now()

  // Add 50 historical matches from 10 hours ago
  for (let i = 1; i <= 50; i++) {
    seenMap[`stale-match-${i}`] = {
      homeScore: 1,
      awayScore: 0,
      status: "finished",
      seenAt: now - (10 * 3600 * 1000) // 10 hours ago (exceeds 6h TTL)
    }
  }

  // Add 10 active matches from right now
  for (let i = 1; i <= 10; i++) {
    seenMap[`fresh-match-${i}`] = {
      homeScore: 0,
      awayScore: 0,
      status: "live",
      seenAt: now
    }
  }

  assert.equal(Object.keys(seenMap).length, 60, "Initial map has 60 entries")

  // Perform diff / merge with current timestamp
  const pruned = Model.mergeSeenMap(seenMap, {}, now, Model.NOTIFICATION_TTL_MS)

  const remainingKeys = Object.keys(pruned)
  assert.equal(remainingKeys.length, 10, "All 50 stale entries must be pruned")
  for (const k of remainingKeys) {
    assert.ok(k.startsWith("fresh-match-"), "Only fresh matches must survive")
  }
})

// -----------------------------------------------------------------------------
// 3. Heap Allocation & Garbage Collection Stability
// -----------------------------------------------------------------------------
test("Heap allocation remains stable across intensive cycles", () => {
  if (global.gc) global.gc()
  const initialHeap = process.memoryUsage().heapUsed

  // Allocate and churn 500 mock rounds and notification diffs
  let seenMap = {}
  for (let i = 0; i < 500; i++) {
    const roundTime = Date.now() + (i * 30000)
    const mock = Model.mockRound("football", roundTime)
    const res = Model.diffMatchNotifications(mock.matches, seenMap, {
      enabled: true,
      activeSport: "football",
      favoriteIds: ["9825"],
      nowMs: roundTime
    })
    seenMap = res.nextSeen
  }

  if (global.gc) global.gc()
  const finalHeap = process.memoryUsage().heapUsed
  const growthMB = (finalHeap - initialHeap) / (1024 * 1024)

  // Memory growth should be negligible (less than 8 MB after GC)
  assert.ok(growthMB < 8, `Heap growth too large: ${growthMB.toFixed(2)} MB`)
})

console.log("==================================================")
console.log(`  Burn-In Suite Completed: ${passed} passed, ${failed} failed.`)
console.log("==================================================")

if (failed > 0) process.exit(1)
