// Focused model tests: notification diffing, history, delivery.
// Run directly or through tests/sportsmodel.test.mjs (all modules).
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { Model, test } from "./harness.mjs"

test("mergeSeenMap drops stale entries and prefers the new snapshot", () => {
  const now = Date.parse("2026-08-22T19:30:00Z")
  const ttl = Model.NOTIFICATION_TTL_MS
  const stale = { old: { seenAt: now - 7 * 3600000, status: "finished" } }
  const fresh = { fresh: { seenAt: now - 60000, status: "live" } }
  const merged = Model.mergeSeenMap(stale, fresh, now, ttl)
  assert.ok(!merged.old)
  assert.deepEqual(merged.fresh, fresh.fresh)
  // Stale entries inside the TTL window are kept; outside they are dropped.
  const justOld = { old: { seenAt: now - 3600000, status: "finished" } }
  assert.ok(Model.mergeSeenMap(justOld, {}, now, ttl).old)
})
test("dictSet and dictDelete return a new object identity", () => {
  // QML bindings watch property identity. A function that mutates the
  // input map would silently leave the binding pointing at the stale
  // object; the audit caught this happening in three places. These
  // helpers must always allocate a fresh map.
  const base = { a: 1, b: 2 }
  const added = Model.dictSet(base, "c", 3)
  assert.notEqual(added, base, "dictSet must return a new map")
  assert.deepEqual(base, { a: 1, b: 2 }, "dictSet must not mutate the input")
  assert.deepEqual(added, { a: 1, b: 2, c: 3 })
  const removed = Model.dictDelete(base, "a")
  assert.notEqual(removed, base, "dictDelete must return a new map")
  assert.deepEqual(base, { a: 1, b: 2 }, "dictDelete must not mutate the input")
  assert.deepEqual(removed, { b: 2 })
})
test("dictSet rejects __proto__ and inherited keys", () => {
  // A user-edited state file could carry "__proto__" or other keys that
  // would otherwise slip into the deduplication map through prototype
  // chain lookups. Verify the explicit hasOwnProperty guard.
  const poisoned = Object.create({ injected: true })
  poisoned.a = 1
  const out = Model.dictSet(poisoned, "b", 2)
  assert.equal(out.injected, undefined, "inherited keys must not be copied")
  assert.deepEqual(out, { a: 1, b: 2 })
})
test("notification diff establishes a baseline without notifying", () => {
  const now = Date.parse("2026-08-22T19:30:00Z")
  const upcoming = { id: "notify-1", sport: "football", status: "upcoming", time: "2026-08-22T19:40:00Z", leagueName: "Primeira Liga", home: { id: "9772", name: "Benfica" }, away: { id: "9773", name: "FC Porto" } }
  const result = Model.diffMatchNotifications([upcoming], {}, { activeSport: "football", favoriteIds: ["9772"], nowMs: now })
  assert.equal(result.notifications.length, 0)
  assert.equal(result.nextSeen["notify-1"].notifiedUpcoming, false)
})
test("notification diff emits kickoff, score and spoiler-safe messages", () => {
  const now = Date.parse("2026-08-22T19:30:00Z")
  const previous = {
    "notify-2": { homeScore: 0, awayScore: 0, status: "upcoming", notifiedUpcoming: false, seenAt: now - 60000 }
  }
  const live = { id: "notify-2", sport: "football", status: "live", time: "2026-08-22T19:00:00Z", leagueName: "Primeira Liga", liveTime: "31'", homeScore: 1, awayScore: 0, scoreText: "1–0", home: { id: "9772", name: "Benfica" }, away: { id: "9773", name: "FC Porto" } }
  const result = Model.diffMatchNotifications([live], previous, { activeSport: "football", favoriteIds: ["9772"], antiSpoiler: true, nowMs: now })
  assert.deepEqual(result.notifications.map(n => n.kind), ["started", "score"])
  assert.match(result.notifications[1].body, /^Benfica scored/)
  assert.ok(!result.notifications[1].body.includes("1–0"))
  assert.equal(previous["notify-2"].status, "upcoming")
})
test("notification history stays frozen while disabled", () => {
  const previous = { game: { status: "upcoming", homeScore: 0, awayScore: 0, seenAt: 0 } }
  const result = Model.diffMatchNotifications([], previous, { enabled: false, nowMs: Date.now() })
  assert.strictEqual(result.nextSeen, previous)
})
test("notification diff emits one upcoming warning, handles F1, and prunes old history", () => {
  const now = Date.parse("2026-08-22T19:30:00Z")
  const oldId = "old"
  const previous = {
    old: { homeScore: 0, awayScore: 0, status: "finished", seenAt: now - 7 * 3600000 },
    "notify-3": { homeScore: 0, awayScore: 0, status: "upcoming", notifiedUpcoming: false, seenAt: now - 60000 },
    "notify-f1": { homeScore: 0, awayScore: 0, status: "upcoming", notifiedUpcoming: false, seenAt: now - 60000 }
  }
  const upcoming = { id: "notify-3", sport: "football", status: "upcoming", time: "2026-08-22T19:40:00Z", leagueName: "Premier League", home: { id: "9825", name: "Arsenal" }, away: { id: "9826", name: "Crystal Palace" } }
  const f1 = { id: "notify-f1", sport: "f1", status: "live", time: "2026-08-22T19:00:00Z", raceName: "Mock Grand Prix", locality: "Lisboa", home: { id: "f1-gp", name: "Mock Grand Prix" }, away: { id: "f1-circuit", name: "Circuit" } }
  const first = Model.diffMatchNotifications([upcoming, f1], previous, { activeSport: "f1", favoriteIds: [], nowMs: now })
  assert.equal(first.notifications.filter(n => n.kind === "upcoming").length, 1)
  assert.equal(first.notifications.filter(n => n.kind === "started").length, 1)
  assert.ok(!first.nextSeen[oldId])
  const second = Model.diffMatchNotifications([upcoming], first.nextSeen, { activeSport: "football", favoriteIds: ["9825"], nowMs: now + 60000 })
  assert.equal(second.notifications.length, 0)
  const stale = { stale: { status: "upcoming", homeScore: 0, awayScore: 0, notifiedUpcoming: false, seenAt: now - 7 * 3600000 } }
  const reappeared = { ...upcoming, id: "stale", time: "2026-08-22T19:40:00Z", home: { id: "9825", name: "Arsenal" }, away: { id: "9826", name: "Crystal Palace" } }
  const baseline = Model.diffMatchNotifications([reappeared], stale, { activeSport: "football", favoriteIds: ["9825"], nowMs: now })
  assert.equal(baseline.notifications.length, 0)
})

test("notification diff emits finished notifications for concluded matches", () => {
  const now = Date.parse("2026-08-22T21:00:00Z")
  const prevLive = {
    "game-fin": { homeScore: 2, awayScore: 1, status: "live", notifiedUpcoming: true, seenAt: now - 60000 }
  }
  const finished = {
    id: "game-fin", sport: "football", status: "finished", scoreText: "2–1", homeScore: 2, awayScore: 1,
    home: { id: "9772", name: "Benfica" }, away: { id: "9773", name: "FC Porto" }
  }
  // Anti-spoiler mode conceals final score
  const resSpoiler = Model.diffMatchNotifications([finished], prevLive, { activeSport: "football", favoriteIds: ["9772"], antiSpoiler: true, nowMs: now })
  assert.equal(resSpoiler.notifications.length, 1)
  assert.equal(resSpoiler.notifications[0].kind, "finished")
  assert.match(resSpoiler.notifications[0].title, /FULL TIME: Benfica vs FC Porto/)
  assert.match(resSpoiler.notifications[0].body, /score concealed/)

  // Normal mode shows final scoreline
  const resNormal = Model.diffMatchNotifications([finished], prevLive, { activeSport: "football", favoriteIds: ["9772"], antiSpoiler: false, nowMs: now })
  assert.equal(resNormal.notifications.length, 1)
  assert.equal(resNormal.notifications[0].kind, "finished")
  assert.match(resNormal.notifications[0].title, /FULL TIME: Benfica 2–1 FC Porto/)
  assert.match(resNormal.notifications[0].body, /2–1.*Final/)
})
test("notification diff emits half-time notifications and dedupes on subsequent polls", () => {
  const now = Date.parse("2026-08-22T19:48:00Z")
  const prevLive = {
    "game-ht": { homeScore: 1, awayScore: 0, status: "live", notifiedUpcoming: true, notifiedHalfTime: false, seenAt: now - 60000 }
  }
  const htMatch = {
    id: "game-ht", sport: "football", status: "live", liveTime: "HT", scoreText: "1–0", homeScore: 1, awayScore: 0,
    home: { id: "9772", name: "Benfica" }, away: { id: "9773", name: "FC Porto" }
  }

  // Normal mode
  const resNormal = Model.diffMatchNotifications([htMatch], prevLive, { activeSport: "football", favoriteIds: ["9772"], antiSpoiler: false, nowMs: now })
  assert.equal(resNormal.notifications.length, 1)
  assert.equal(resNormal.notifications[0].kind, "halftime")
  assert.match(resNormal.notifications[0].title, /HALF TIME: Benfica 1–0 FC Porto/)
  assert.match(resNormal.notifications[0].body, /1–0.*Half Time/)
  assert.equal(resNormal.nextSeen["game-ht"].notifiedHalfTime, true)

  // Subsequent poll while still at HT: must NOT emit another notification
  const resDedupe = Model.diffMatchNotifications([htMatch], resNormal.nextSeen, { activeSport: "football", favoriteIds: ["9772"], antiSpoiler: false, nowMs: now + 30000 })
  assert.equal(resDedupe.notifications.length, 0)
  assert.equal(resDedupe.nextSeen["game-ht"].notifiedHalfTime, true)

  // Anti-spoiler mode conceals half-time scoreline
  const resSpoiler = Model.diffMatchNotifications([htMatch], prevLive, { activeSport: "football", favoriteIds: ["9772"], antiSpoiler: true, nowMs: now })
  assert.equal(resSpoiler.notifications.length, 1)
  assert.equal(resSpoiler.notifications[0].kind, "halftime")
  assert.match(resSpoiler.notifications[0].title, /HALF TIME: Benfica vs FC Porto/)
  assert.match(resSpoiler.notifications[0].body, /score concealed/)
})
