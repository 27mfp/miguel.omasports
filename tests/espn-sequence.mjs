#!/usr/bin/env node
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"
import { test } from "node:test"

const panel = readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
const modelSource = readFileSync(new URL("../SportsModel.js", import.meta.url), "utf8")
const Model = vm.createContext({})
vm.runInContext(modelSource.replace(/^\.pragma library\s*$/m, ""), Model)

// Execute the production Panel functions, with QML services supplied below.
// Panel's top-level functions end at a two-space closing brace.
const names = [
  "startEspnRound", "fetchNextEspnDay", "resolveEspnScoreboard",
  "resolveEspnStandings", "checkEspnDone", "stopNetworkWorkers"
]
const functions = names.map(name => {
  const match = panel.match(new RegExp(`^  function ${name}\\([^\\n]*\\) \\{[\\s\\S]*?^  \\}`, "m"))
  assert.ok(match, `Missing production function ${name}`)
  return match[0]
}).join("\n")

function harness() {
  const deferred = []
  const requests = []
  const dayList = ["20261007", "20261008", "20261009", "20261010", "20261011"]
  const state = {
    Model, requestSerial: 1, espnDayQueue: [], espnDayPayloads: [],
    espnDayFailures: 0, espnRetryCount: 0, espnRetrySerial: 0,
    loading: true, errorMessage: "", activeSportMeta: { label: "MLB" },
    allMatches: [], matchBroadcasts: {}, matchLeaders: {},
    workerScoreboard: { running: false, handled: false },
    workerStandings: { running: false, handled: false },
    retryDelay: { stop() {} }, teamRetryDelay: { stop() {} },
    retries: 0, completions: 0,
    espnRetryDelay: { restart() { state.retries++ } },
    Qt: { callLater(fn) { deferred.push(fn) } },
    secureFetchCommand(url) { requests.push(url); return url },
    fetchLeagueNews() {}, ensureStandingsSelection() {},
    downloadMissingLogos() {}, checkScoreNotifications() {},
    scheduleNextPoll() { state.completions++ }
  }
  // Keep dates deterministic while using the real parser/merge helpers.
  state.Model = Object.create(Model)
  state.Model.espnDateList = () => dayList.slice()
  const workers = panel.match(/var procs = \[([\s\S]*?)\]/)[1].match(/\b\w+\b/g)
  for (const name of workers) {
    state[name] ??= { running: false, handled: false }
    state[name].hardStop = function() { this.running = false }
  }
  state.root = state
  vm.createContext(state)
  vm.runInContext(functions, state)

  function drain() {
    let count = 0
    while (deferred.length) {
      assert.ok(++count < 100, "Deferred callbacks did not settle")
      deferred.shift()()
    }
  }
  function deliver(raw = '{"events":[]}', flush = true) {
    const worker = state.workerScoreboard
    assert.equal(worker.running, true)
    worker.running = false
    state.resolveEspnScoreboard(raw, "mlb", "MLB")
    // NetworkProcess emits its output/failed signal before setting handled.
    worker.handled = true
    if (flush) drain()
  }
  function standings() {
    state.workerStandings.running = false
    state.workerStandings.gotData = true
    state.checkEspnDone()
  }
  state.startEspnRound("baseball/mlb", "mlb", "MLB")
  return { state, requests, dayList, deferred, deliver, drain, standings }
}

const captured = JSON.parse(readFileSync(
  new URL("./fixtures/espn-mlb-scoreboard.json", import.meta.url), "utf8"
))
assert.ok(captured.events.length > 0, "MLB fixture must contain a game")
const gameDay = JSON.stringify({ leagues: captured.leagues, events: [captured.events[0]] })

test("next day starts after handled is set; standings cannot finish between days", () => {
  const h = harness()
  h.deliver('{"events":[]}', false)
  assert.equal(h.state.workerScoreboard.running, false)
  assert.equal(h.requests.length, 2) // scoreboard and standings
  h.standings()
  assert.equal(h.state.completions, 0)
  h.drain()
  assert.equal(h.state.workerScoreboard.running, true)
  assert.equal(h.state.workerScoreboard.handled, false)
  for (let i = 1; i < 5; i++) h.deliver()
  assert.equal(h.state.workerScoreboard.gotData, true)
  assert.equal(h.state.retries, 0)
  assert.equal(h.state.completions, 1)
  assert.equal(h.state.loading, false)
  assert.deepEqual(h.requests.filter(url => url.includes("/scoreboard?")).map(url =>
    url.split("dates=")[1]), h.dayList)
})

test("scoreboard waits for standings when it finishes first", () => {
  const h = harness()
  for (let i = 0; i < 5; i++) h.deliver()
  assert.equal(h.state.completions, 0)
  h.standings()
  assert.equal(h.state.completions, 1)
})

test("valid empty days count as success and duplicate games merge once", () => {
  const h = harness()
  h.standings()
  for (const raw of [gameDay, '{"events":[]}', gameDay, '{"events":[]}', '{"events":[]}'])
    h.deliver(raw)
  assert.equal(h.state.espnDayFailures, 0)
  assert.equal(h.state.allMatches.length, 1)
  assert.equal(h.state.workerScoreboard.gotData, true)
  assert.equal(h.state.retries, 0)
})

test("failed middle day preserves partial results and retries a fresh window", () => {
  const h = harness()
  h.standings()
  for (const raw of [gameDay, "", '{"events":[]}', '{"events":[]}', '{"events":[]}'])
    h.deliver(raw)
  assert.equal(h.state.espnDayFailures, 1)
  assert.equal(h.state.allMatches.length, 1)
  assert.equal(h.state.workerScoreboard.gotData, false)
  assert.equal(h.state.retries, 1)
  assert.equal(h.state.completions, 0)
  h.state.startEspnRound("baseball/mlb", "mlb", "MLB")
  assert.equal(h.state.espnDayFailures, 0)
  assert.equal(h.state.espnDayPayloads.length, 0)
  h.standings()
  for (let i = 0; i < 5; i++) h.deliver()
  assert.equal(h.state.workerScoreboard.gotData, true)
  assert.equal(h.state.completions, 1)
  assert.equal(h.requests.filter(url => url.includes("/scoreboard?")).length, 10)
})

test("malformed and provider-error responses fail and stop at the retry limit", () => {
  const h = harness()
  h.state.espnRetryCount = Model.MAX_ROUND_RETRIES
  h.standings()
  for (const raw of ["{", '{"code":400,"message":"error"}', "", "{", ""])
    h.deliver(raw)
  assert.equal(h.state.espnDayFailures, 5)
  assert.equal(h.state.retries, 0)
  assert.equal(h.state.loading, false)
  assert.equal(h.state.errorMessage, "Scores could not be loaded.")
})

test("sport switch cancels a deferred next day and ignores late old output", () => {
  const h = harness()
  h.deliver(gameDay, false)
  const oldSerial = h.state.workerScoreboard.serial
  h.state.requestSerial++
  h.state.stopNetworkWorkers()
  const before = h.requests.length
  h.state.workerScoreboard.handled = false // also exercise the serial guard
  h.state.workerScoreboard.serial = oldSerial
  h.state.resolveEspnScoreboard(gameDay, "mlb", "MLB")
  h.drain()
  assert.equal(h.requests.length, before)
  assert.equal(h.state.espnDayQueue.length, 0)
  assert.equal(h.state.completions, 0)
  assert.equal(h.state.retries, 0)
  assert.equal(h.state.allMatches.length, 0)
})

test("handled guard suppresses duplicate completion signals for a day", () => {
  const h = harness()
  h.deliver(gameDay, false)
  const pending = h.deferred.length
  h.state.resolveEspnScoreboard("", "mlb", "MLB")
  assert.equal(h.state.espnDayPayloads.length, 1)
  assert.equal(h.state.espnDayFailures, 0)
  assert.equal(h.deferred.length, pending)
  h.drain()
})
