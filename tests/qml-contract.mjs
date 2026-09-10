#!/usr/bin/env node
// Static cross-file contract checks for the QML seams that cannot be exercised
// by the pure Node model tests. Runtime visual/interaction tests remain the
// authoritative UI check when a Quickshell host is available.
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"

const read = (file) => readFileSync(new URL(`../${file}`, import.meta.url), "utf8")
const panel = read("Panel.qml")
const liveTab = read("LiveTab.qml")
const liveRow = read("LiveRow.qml")
const matchRow = read("MatchRow.qml")
const spotlight = read("MatchSpotlight.qml")
const visual = read("tests/visual.mjs")
const interaction = read("tests/interaction.mjs")

assert.match(panel, /function toggleRevealScore\(matchId\)/, "Panel must expose score reveal callback")
assert.match(liveTab, /toggleRevealScore:\s*controller\.toggleRevealScore/, "LiveTab must wire score reveal callback")
assert.match(liveRow, /if \(root\.toggleRevealScore\) root\.toggleRevealScore\(/, "LiveRow must invoke score reveal callback")
assert.match(matchRow, /antiSpoiler\s*&&\s*\(isFinished\s*\|\|\s*isLive\)/, "MatchRow must conceal live and finished scores")
assert.match(spotlight, /property var toggleRevealScore/, "MatchSpotlight must support score reveal callback")
assert.match(spotlight, /if \(root\.toggleRevealScore && root\.match\) root\.toggleRevealScore\(/, "MatchSpotlight must invoke score reveal callback")
assert.match(panel, /RETRY_DELAY_FOTMOB_F1_MS/, "Panel must use the FotMob/F1 retry floor")
assert.match(panel, /RETRY_DELAY_ESPN_MS/, "Panel must use the ESPN retry floor")
assert.match(panel, /current\/results\.json\?limit=100/, "F1 winners must use the complete-season results endpoint")
assert.doesNotMatch(panel, /current\/results\/1\.json/, "F1 winners must not be limited to round one")
assert.doesNotMatch(panel, /www\.fotmob\.com[^\n]*\?_=/, "FotMob requests must not bypass edge caching")
assert.match(visual, /refusing to run visual tests on a physical screen/, "visual tests must fail closed without headless support")
assert.match(visual, /Missing visual golden/, "visual tests must fail on missing baselines")
assert.doesNotMatch(visual, /grim -g/, "visual tests must not capture the physical screen")
assert.doesNotMatch(visual, /Falling back to on-screen/, "visual tests must not silently fall back")
assert.match(interaction, /createHeadlessMonitor\(\)/, "interaction tests must provision a headless monitor")
assert.match(interaction, /getSuppressFocus/, "interaction tests must verify focus suppression")
assert.match(interaction, /getNewsWire/, "visual/interaction state snapshots must cover news wire")
assert.match(panel, /function setNotifications\(enabled: bool\)/, "visual tests need a deterministic notification state setter")
assert.match(panel, /function setMockMode\(enabled: bool\)/, "visual tests need a runtime-only mock mode switch")

console.log("QML cross-file contract passed (score reveal, anti-spoiler, rate floors, safe test harness)")
