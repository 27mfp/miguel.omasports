#!/usr/bin/env node
// Focused tests for the pure controllers extracted from Panel.qml.
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"
import { test } from "node:test"

function load(file) {
  const context = vm.createContext({})
  const source = readFileSync(new URL(`../${file}`, import.meta.url), "utf8")
    .replace(/^\.pragma library\s*$/gm, "")
  const names = [...source.matchAll(/^function ([A-Za-z_$][\w$]*)\s*\(/gm)].map(match => match[1])
  vm.runInContext(source, context)
  return vm.runInContext(`({ ${names.join(", ")} })`, context)
}

const Policy = load("controllers/PanelPolicy.js")
const Diagnostics = load("controllers/PanelDiagnostics.js")
const State = load("controllers/PanelState.js")
const Details = load("controllers/PanelDetails.js")

test("relativeAge uses compact minute/hour buckets", () => {
  const base = Date.parse("2026-11-24T12:00:00Z")
  assert.equal(Policy.relativeAge(base + 30_000, base), "just now")
  assert.equal(Policy.relativeAge(base + 5 * 60_000, base), "5 min ago")
  assert.equal(Policy.relativeAge(base + 65 * 60_000, base), "1h5m ago")
  assert.equal(Policy.relativeAge(base - 60_000, base), "just now")
})

test("statusLine covers loading, error, empty and live states", () => {
  const base = { hasData: true, fetchedOnce: true, nowMs: 10 * 60_000, lastUpdatedMs: 5 * 60_000, activeSportLabel: "NBA" }
  assert.equal(Policy.statusLine({ ...base, loading: true, hasData: false, lastUpdatedMs: 0 }), "󰥔 Loading NBA…")
  assert.equal(Policy.statusLine({ ...base, loading: true }), "󰥔 Updating scores…")
  assert.equal(Policy.statusLine({ ...base, errorMessage: "Scores could not be loaded." }), "Scores could not be loaded.")
  assert.equal(Policy.statusLine({ ...base, hasData: false, fetchedOnce: false }), "Follow teams or leagues to track NBA.")
  assert.equal(Policy.statusLine({ ...base, fastPolling: true }), "● LIVE · updated 5 min ago")
  assert.equal(Policy.statusLine({ ...base, loadedFromCache: true }), "Cached · updated 5 min ago")
  assert.equal(Policy.statusLine(base), "Updated 5 min ago")
})

test("polling floors and background preference are enforced", () => {
  assert.equal(Policy.livePollIntervalMs("nba"), 15000)
  assert.equal(Policy.livePollIntervalMs("mlb"), 15000)
  assert.equal(Policy.livePollIntervalMs("football"), 20000)
  assert.equal(Policy.livePollIntervalMs("f1"), 20000)
  assert.equal(Policy.nextPollDelay(false, true, 300000, true, "nba"), 0)
  assert.equal(Policy.nextPollDelay(true, true, 300000, true, "nba"), 15000)
  assert.equal(Policy.nextPollDelay(true, true, 300000, false, "football"), 60000)
  assert.equal(Policy.nextPollDelay(true, false, 300000, false, "football"), 300000)
  assert.equal(Policy.shouldFastPoll(false, 4, false), false)
  assert.equal(Policy.shouldFastPoll(true, 0, true), true)
  assert.equal(Policy.shouldFastPoll(true, 1, false), true)
  assert.equal(Policy.hasLiveFollowedMatch([{ status: "finished" }, { status: "live" }]), true)
})

test("IPC throttle is a pure time-gate", () => {
  assert.equal(Policy.ipcAllowed(1000, 1100, 250), false)
  assert.equal(Policy.ipcAllowed(1000, 1250, 250), true)
  assert.equal(Policy.ipcAllowed(0, 249, 250), false)
  assert.equal(Policy.ipcAllowed(0, 250, 250), true)
})

test("diagnostics are sanitized and stable-coded", () => {
  const text = Diagnostics.build({
    pluginVersion: "1.5.1", sport: "football", provider: "FotMob",
    opened: true, mock: false, qtVersion: "6.12.0", platform: "linux",
    loading: false, hasData: true, fetchedOnce: true, loadedFromCache: false,
    persistenceError: "", errorMessage: "Some leagues could not be loaded: 47, 61",
    lastUpdatedMs: Date.parse("2026-11-24T12:00:00Z"),
    failedSources: 2, knownCrests: 12, pendingCrests: 1,
    backgroundUpdates: true, showBarTicker: false, showSpotlight: true,
    showNewsWire: true, antiSpoiler: true, enableNotifications: false
  })
  assert.match(text, /^OmaSports diagnostics/)
  assert.match(text, /plugin: miguel\.omasports 1\.5\.1/)
  assert.match(text, /sport: football \(FotMob\)/)
  assert.match(text, /last-error: provider-partial/)
  assert.match(text, /cache: 12 crests, 1 pending/)
  assert.match(text, /anti-spoiler=on notifications=off/)
  assert.doesNotMatch(text, /\/home\/|\.config|selectedTeamIds|token|apiKey/i)
  assert.equal(Diagnostics.errorCode("", ""), "none")
  assert.equal(Diagnostics.errorCode("Could not save OmaSports settings.", ""), "state-write")
  assert.equal(Diagnostics.errorCode("Could not read OmaSports settings", ""), "state-read")
  assert.equal(Diagnostics.dataState({ loading: true }), "loading")
  assert.equal(Diagnostics.dataState({ hasData: false, fetchedOnce: true }), "empty-window")
  assert.equal(Diagnostics.dataState({ hasData: false, fetchedOnce: false }), "unconfigured")
  assert.equal(Diagnostics.dataState({ hasData: true, loadedFromCache: true }), "cached")
  assert.equal(Diagnostics.dataState({ hasData: true }), "ready")
})

test("panel state parsing, migration fallbacks and serialization", () => {
  const parsed = { sport: "nba", notifications: false, backgroundUpdates: false }
  const signature = JSON.stringify(parsed)
  const own = State.loadedState("ignored", signature, () => parsed)
  assert.equal(own.ownWrite, true)
  assert.equal(own.signature, signature)
  const fresh = State.loadedState("{}", "", () => parsed)
  assert.equal(fresh.ownWrite, false)
  assert.equal(State.tabName(0), "fixtures")
  assert.equal(State.tabName(1), "live")
  assert.equal(State.tabName(2), "standings")
  assert.equal(State.tabName(3), "settings")
  assert.equal(State.stateFilePath("/home/test"), "/home/test/.config/omarchy/sports-favorites.json")
  assert.equal(State.stateFilePath(""), "/.config/omarchy/sports-favorites.json")
  assert.deepEqual(
    JSON.parse(JSON.stringify(State.settings({ sport: "f1", antiSpoiler: true },
      { backgroundUpdates: true, showBarTicker: false }))),
    { activeSport: "f1", antiSpoiler: true, enableNotifications: true, showNewsWire: true,
      backgroundUpdates: true, showBarTicker: false, showSpotlight: true })
  assert.equal(State.selectedLeagueNameList("nba", "NBA", [], () => "x", x => x), "NBA")
  assert.equal(State.selectedLeagueNameList("football", "", ["47", "61"], id => "L" + id, x => x), "L47, L61")
  const serialized = State.serialize({ sport: "nba" })
  assert.match(serialized, /\n$/)
  assert.equal(JSON.parse(serialized).sport, "nba")
})

test("panel detail selection and reconciliation are pure", () => {
  const api = {
    liveMatches: () => [{ id: "live-1" }],
    arrayFrom: value => Array.from(value || []),
    parseDetails: () => ({ finished: true, reason: "FT", liveTime: "", liveScore: "" }),
    extractPageProps: () => ({ content: {} }),
    parseFotmobEvents: () => ({ goals: [], redCards: [] }),
    parseFotmobForm: () => ({ home: [], away: [] }),
    parseFotmobStats: () => null
  }
  const wanted = Details.wantedDetails(
    true, "football", [], {}, [{ id: "team-1", status: "upcoming" }], [], 0, api)
  assert.deepEqual(Array.from(wanted), ["live-1", "team-1"])
  assert.equal(Details.wantedDetails(false, "football", [], {}, [], [], 0, api).length, 0)
  assert.equal(Details.wantedDetails(true, "nba", [], {}, [], [], 0, api).length, 0)

  const enriched = Details.enrich("<html></html>", "live-1", {}, {}, {}, {}, api)
  assert.equal(enriched.details["live-1"].finished, true)
  assert.equal(enriched.events, null)
  const existing = [
    { id: "live-1", status: "live", statusReason: "", liveTime: "78’", scoreText: "1–0" },
    { id: "other", status: "live", liveTime: "10’", scoreText: "0–0" }
  ]
  const reconciled = Details.reconcile(enriched.parsed, "live-1", existing, [existing[0]], api)
  assert.equal(reconciled.allTouched, true)
  assert.equal(reconciled.allMatches[0].status, "finished")
  assert.equal(reconciled.allMatches[0].statusReason, "FT")
  assert.equal(reconciled.allMatches[1].status, "live")
  assert.equal(reconciled.teamTouched, true)
  assert.equal(reconciled.teamMatchesRaw[0].status, "finished")
})
