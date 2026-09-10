#!/usr/bin/env node
// Repository-local manifest/package contract check. This complements
// `omarchy plugin validate .`, which is only available on an Omarchy host.
import { existsSync, readdirSync, readFileSync } from "node:fs"
import assert from "node:assert/strict"

const root = new URL("../", import.meta.url)
const manifest = JSON.parse(readFileSync(new URL("manifest.json", root), "utf8"))

assert.equal(manifest.schemaVersion, 1, "manifest schemaVersion must be 1")
assert.match(String(manifest.id), /^[a-z0-9]+(?:\.[a-z0-9-]+)+$/, "manifest id is invalid")
assert.ok(String(manifest.name).trim(), "manifest name is required")
assert.match(String(manifest.version), /^\d+\.\d+\.\d+(?:[-+].*)?$/, "manifest version is invalid")
assert.ok(Array.isArray(manifest.kinds) && manifest.kinds.includes("bar-widget"), "bar-widget kind is required")
assert.equal(manifest.entryPoints?.barWidget, "BarWidget.qml", "bar widget entry point drifted")
assert.ok(existsSync(new URL(manifest.entryPoints.barWidget, root)), "bar widget entry point is missing")

const schema = manifest.barWidget?.schema
assert.ok(Array.isArray(schema), "bar widget settings schema is required")
const keys = schema.map((setting) => {
  assert.match(String(setting.key), /^[a-z][A-Za-z0-9]*$/, `invalid setting key: ${setting.key}`)
  assert.ok(["boolean", "string", "number", "enum"].includes(setting.type), `invalid setting type: ${setting.type}`)
  assert.ok(String(setting.label).trim(), `missing label for ${setting.key}`)
  if (setting.type === "enum") {
    assert.ok(Array.isArray(setting.options) && setting.options.length > 0, `enum ${setting.key} needs options`)
  }
  return setting.key
})
assert.equal(new Set(keys).size, keys.length, "manifest setting keys must be unique")

for (const file of ["Panel.qml", "NetworkProcess.qml", "RetryTimer.qml", "SportsModel.js"]) {
  assert.ok(existsSync(new URL(file, root)), `required runtime file is missing: ${file}`)
}

const qmlFiles = readdirSync(new URL("../", import.meta.url)).filter((file) => file.endsWith(".qml"))
assert.ok(qmlFiles.length >= 10, "unexpectedly incomplete QML package")

console.log(`Manifest contract passed (${manifest.id} ${manifest.version}; ${keys.length} settings; ${qmlFiles.length} QML files)`)
