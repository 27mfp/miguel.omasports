#!/usr/bin/env node
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"
import { test } from "node:test"

const panel = readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
function load(names, state) {
  state.root = state
  vm.createContext(state)
  for (const name of names) {
    const match = panel.match(new RegExp(`^  function ${name}\\([^\\n]*\\) \\{[\\s\\S]*?^  \\}`, "m"))
    assert.ok(match, name)
    vm.runInContext(match[0], state)
  }
  return state
}
function notifications() {
  return load(["cancelPendingNotifications", "setNotificationPreference", "dispatchNextNotification", "toggleNotifications", "switchSport"], {
    enableNotifications: true, notificationToolAvailable: true,
    notificationQueue: [{ title: "Old score", body: "Pending", iconPath: "", urgency: "normal" }],
    notifierProc: { running: true, hardStop() { this.running = false } },
    notificationPacingTimer: { running: true, stop() { this.running = false } },
    Model: { resetMockClock() {}, arrayFrom: x => Array.from(x), sports: () => [{ value: "mlb" }, { value: "nba" }] },
    savedState: {}, selectedTeamIds: [], activeSport: "mlb",
    persistState() {}, scheduleNextPoll() {}, restoreSportSelections() {},
    ensureStandingsSelection() {}, forceRefresh() {},
    secureToolCommand: (tool, args) => [tool, ...args]
  })
}
test("UI notification disable stops the active send and queued pacing", () => {
  const state = notifications()
  state.toggleNotifications()
  assert.equal(state.enableNotifications, false)
  assert.equal(state.notificationQueue.length, 0)
  assert.equal(state.notifierProc.running, false)
  assert.equal(state.notificationPacingTimer.running, false)
})
test("IPC setter shares cancellation and dispatcher refuses disabled alerts", () => {
  assert.match(panel, /function setNotifications\(enabled: bool\): void \{\s*root\.setNotificationPreference\(enabled\)/)
  const state = notifications()
  state.setNotificationPreference(false)
  state.notificationQueue = [{ title: "Late callback", body: "", iconPath: "" }]
  state.dispatchNextNotification()
  assert.equal(state.notifierProc.running, false)
  assert.equal(state.notificationQueue.length, 0)
})
test("sport switch discards alerts before starting a new round", () => {
  const state = notifications()
  state.switchSport("nba")
  assert.equal(state.activeSport, "nba")
  assert.equal(state.notificationQueue.length, 0)
  assert.equal(state.notifierProc.running, false)
  assert.equal(state.notificationPacingTimer.running, false)
})
test("kickoff selection skips overdue events and rolls forward without a fetch", () => {
  const state = load(["refreshNextKickoff"], {
    nowMs: Date.parse("2026-10-08T12:00Z"), nextKickoffMs: -1, nextKickoffMatch: null,
    allMatches: [
      { id: "past", status: "upcoming", time: "2026-10-07T12:00Z" },
      { id: "first", status: "upcoming", time: "2026-10-08T13:00Z" },
      { id: "second", status: "upcoming", time: "2026-10-08T14:00Z" },
      { id: "invalid", status: "upcoming", time: "bad" }
    ]
  })
  state.refreshNextKickoff()
  assert.equal(state.nextKickoffMatch.id, "first")
  state.nowMs = Date.parse("2026-10-08T13:00Z")
  state.refreshNextKickoff()
  assert.equal(state.nextKickoffMatch.id, "second")
  state.nowMs = Date.parse("2026-10-08T15:00Z")
  state.refreshNextKickoff()
  assert.equal(state.nextKickoffMatch, null)
  assert.match(panel, /nextKickoffMs <= root\.nowMs\) root\.refreshNextKickoff\(\)/)
})
test("own state-write echo does not restore an obsolete active route", () => {
  const saved = { sport: "mlb" }
  const state = load(["applyState"], {
    Model: { parseState: () => saved }, ignoredStateSignature: JSON.stringify(saved),
    activeSport: "nba", tabIndex: 1
  })
  state.applyState("ignored")
  assert.equal(state.activeSport, "nba")
  assert.equal(state.tabIndex, 1)
  assert.equal(state.ignoredStateSignature, "")
})

test("opening an already loaded panel cannot restore an obsolete saved route", () => {
  let reads = 0
  const state = load(["openFromHotkey"], {
    stateLoaded: true, routedExplicitly: true, opened: true,
    controller: { show() {} }, loadStateSecure() { reads++ },
    Qt: { callLater(fn) { fn() } }, scheduleNextPoll() {}
  })
  state.openFromHotkey()
  assert.equal(reads, 0)
})
test("mock exit never resurrects a canceled loading flag or alert backlog", () => {
  const state = notifications()
  const original = { allMatches: [{ id: "old" }], loading: true, notificationQueue: [{ title: "old" }] }
  const snapshot = panel.match(/mockPreTestState = \{([\s\S]*?)\n      \}/)[1]
  for (const match of snapshot.matchAll(/^\s*(\w+):\s*(\w+),?$/gm)) state[match[2]] ??= null
  Object.assign(state, original, { mockModeOverride: null, mockPreTestState: null, requestSerial: 1,
    stopNetworkWorkers() { state.notifierProc.running = false }, forceRefresh() { state.refreshed = true } })
  load(["setMockModeForTesting"], state)
  state.setMockModeForTesting(true)
  assert.equal(state.notificationQueue.length, 0)
  state.setMockModeForTesting(false)
  assert.equal(state.loading, false)
  assert.equal(state.notificationQueue.length, 0)
  assert.equal(state.refreshed, true)
  assert.equal(state.allMatches, original.allMatches)
})
test("fixture keyboard indexing consumes the same visible groups as rendering", () => {
  const fixtures = readFileSync(new URL("../FixturesTab.qml", import.meta.url), "utf8")
  assert.match(panel, /var groups = fixturesTab \? fixturesTab\.visibleMatchGroups : \[\]/)
  assert.match(fixtures, /model: root\.visibleMatchGroups/)
  assert.match(fixtures, /root\.visibleMatchGroups\[g\]/)
  assert.match(fixtures, /Accessible\.role: Accessible\.PageTab/)
  assert.match(fixtures, /Accessible\.selected: isSelected/)
})

test("collapsed results and upcoming limits share a consistent visible-row model", () => {
  const fixtures = readFileSync(new URL("../FixturesTab.qml", import.meta.url), "utf8")
  const expression = fixtures.match(/readonly property var visibleMatchGroups: ([\s\S]*?\n  \})\)/)[1] + ")"
  const state = { filteredMatchGroups: [
    { key: "live", matches: [{ id: "live" }] },
    { key: "upcoming", matches: Array.from({ length: 8 }, (_, i) => ({ id: "u" + i })) },
    { key: "recent", matches: Array.from({ length: 10 }, (_, i) => ({ id: "r" + i })) }
  ], controller: { scheduleSubSection: "all" }, upcomingExpanded: false, recentExpanded: false }
  state.root = state
  vm.createContext(state)
  assert.deepEqual(Array.from(vm.runInContext(expression, state), group => group.matches.length), [1, 6, 3])
  state.upcomingExpanded = state.recentExpanded = true
  assert.deepEqual(Array.from(vm.runInContext(expression, state), group => group.matches.length), [1, 8, 10])
  assert.match(panel, /name === "recentExpand".*fixturesTab\.toggleRecent\(\)/)
  assert.match(panel, /name === "spotlightDetails".*fixturesTab\.toggleSpotlightDetails\(\)/)
})

test("stable live/spotlight delegates resolve fresh match data by identity", () => {
  const liveRow = readFileSync(new URL("../LiveRow.qml", import.meta.url), "utf8")
  const spotlight = readFileSync(new URL("../MatchSpotlight.qml", import.meta.url), "utf8")
  const old = { id: "a", linescores: { home: [1] } }
  const latest = { a: { id: "a", linescores: { home: [1, 0] } } }
  for (const [source, state] of [[liveRow, { modelData: old, latestMatchesById: latest }],
    [spotlight, { selectedMatch: old, latestMatchesById: latest }]]) {
    const binding = source.match(/readonly property var match: ([^\n]+)/)[1]
    vm.createContext(state)
    const result = vm.runInContext(binding, state)
    assert.equal(result, latest.a)
    assert.deepEqual(result.linescores.home, [1, 0])
  }
})
