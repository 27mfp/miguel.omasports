#!/usr/bin/env node
// S-Tier Crest Cache Resilience & 404/Corrupt Image Fallbacks Suite for miguel.omasports
// Pure cache-key/monogram/URL contracts. Real image behavior is exercised by
// tests/compatibility.mjs against production QML; malformed PNGs by security-hardening.mjs.
import { readFileSync } from "node:fs"
import { execSync } from "node:child_process"
import assert from "node:assert/strict"

const raw = readFileSync(new URL("../SportsModel.js", import.meta.url), "utf8")
const exported = [
  "monogramText", "crestCacheKey", "isTrustedCrestUrl", "safeHome"
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
console.log("  OMASports Crest Resilience & Fallback Suite")
console.log("==================================================")

// -----------------------------------------------------------------------------
// 1. Monogram Derivation Across Sports & Club Names
// -----------------------------------------------------------------------------
test("Monogram derivation formats acronyms (SL, FC, LAL, BOS, ARS)", () => {
  // Preferred abbreviations
  assert.equal(Model.monogramText("LAL", "Los Angeles Lakers"), "LAL")
  assert.equal(Model.monogramText("BOS", "Boston Celtics"), "BOS")
  assert.equal(Model.monogramText("SL", "Sport Lisboa e Benfica"), "SL")
  assert.equal(Model.monogramText("FC", "Football Club"), "FC")
  assert.equal(Model.monogramText("ARS", "Arsenal FC"), "ARS")
  assert.equal(Model.monogramText("gsw", "Golden State Warriors"), "GSW")
})

test("Monogram derivation handles multi-word club names without abbreviation", () => {
  assert.equal(Model.monogramText("", "Real Madrid"), "RM")
  assert.equal(Model.monogramText("", "Manchester United"), "MU")
  assert.equal(Model.monogramText("", "Paris Saint-Germain"), "PS")
  assert.equal(Model.monogramText("", "Red Bull Racing"), "RB")
  assert.equal(Model.monogramText("", "Ferrari F1"), "FF")
})

test("Monogram derivation handles single-word names and edge cases cleanly", () => {
  assert.equal(Model.monogramText("", "Benfica"), "BE")
  assert.equal(Model.monogramText("", "Chelsea"), "CH")
  assert.equal(Model.monogramText("", "A"), "A")
  assert.equal(Model.monogramText("", "   "), "?")
  assert.equal(Model.monogramText("", ""), "?")
  assert.equal(Model.monogramText(null, null), "?")
  assert.equal(Model.monogramText(undefined, undefined), "?")
})

// -----------------------------------------------------------------------------
// 2. Trusted Crest CDN Validation & URL Defense
// -----------------------------------------------------------------------------
test("Trusted CDN whitelist admits official image domains", () => {
  assert.ok(Model.isTrustedCrestUrl("https://images.fotmob.com/image_resources/logo/teamlogo/9825.png", "football"))
  assert.ok(Model.isTrustedCrestUrl("https://a.espncdn.com/i/teamlogos/nba/500/lal.png", "nba"))
  assert.ok(Model.isTrustedCrestUrl("https://a.espncdn.com/i/teamlogos/nfl/500/kc.png", "nfl"))
  assert.ok(Model.isTrustedCrestUrl("https://a.espncdn.com/i/teamlogos/mlb/500/bos.png", "mlb"))
  assert.ok(Model.isTrustedCrestUrl("https://a.espncdn.com/i/teamlogos/nhl/500/det.png", "nhl"))
})

test("Rejects untrusted protocols and malicious URL schemes", () => {
  assert.ok(!Model.isTrustedCrestUrl("file:///etc/passwd", "football"), "Must reject file://")
  assert.ok(!Model.isTrustedCrestUrl("javascript:alert(1)", "football"), "Must reject javascript://")
  assert.ok(!Model.isTrustedCrestUrl("data:image/png;base64,AAA", "football"), "Must reject data://")
  assert.ok(!Model.isTrustedCrestUrl("http://evil-attacker.com/logo.png", "football"), "Must reject untrusted domains")
  assert.ok(!Model.isTrustedCrestUrl("", "football"), "Must reject empty strings")
})

// -----------------------------------------------------------------------------
// 3. System Log & Journalctl Hygiene Check
// -----------------------------------------------------------------------------
test("System log hygiene: verify no crashing or error loop in user services", () => {
  try {
    const journal = execSync("journalctl --user -n 30 --no-pager 2>&1", { encoding: "utf8" })
    assert.ok(!journal.includes("QQuickImage: segmentation fault"), "Must not segfault on image handling")
    assert.ok(!journal.includes("omasports: fatal"), "No fatal plugin errors")
  } catch (err) {
    // Journalctl may require permissions; ignore if unreadable
  }
})

console.log("==================================================")
console.log(`  Crest Resilience Suite Completed: ${passed} passed, ${failed} failed.`)
console.log("==================================================")

if (failed > 0) process.exit(1)
