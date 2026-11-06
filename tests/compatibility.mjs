#!/usr/bin/env node
// Real Qt/Omarchy imports without OmarchyLoadPatch, windows or live data.
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { copyFileSync, cpSync, mkdirSync, mkdtempSync, readdirSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const directory = mkdtempSync(join(tmpdir(), "omasports-compatibility-"))
try {
  mkdirSync(join(directory, "sports"))
  const cache = join(directory, ".cache", "omarchy-omasports", "logos")
  mkdirSync(cache, { recursive: true })
  copyFileSync(new URL("../icon.png", import.meta.url), join(cache, "football-9825.png"))
  for (const name of ["Commons", "Ui"])
    cpSync(join(process.env.OMARCHY_PATH || "/usr/share/omarchy", "shell", name), join(directory, name), { recursive: true })
  for (const name of readdirSync(new URL("../", import.meta.url)).filter(name => /\.(qml|js)$/.test(name)))
    copyFileSync(new URL(`../${name}`, import.meta.url), join(directory, "sports", name))
  copyFileSync(new URL("runtime/compatibility.qml", import.meta.url), join(directory, "shell.qml"))
  const env = { ...process.env, HOME: directory, QT_QPA_PLATFORM: "offscreen", QT_QUICK_BACKEND: "software" }
  delete env.WAYLAND_DISPLAY
  delete env.QS_CONFIG_PATH
  const result = spawnSync("quickshell", ["--no-color", "--path", directory], { encoding: "utf8", timeout: 10000, env })
  const output = (result.stdout || "") + (result.stderr || "")
  assert.equal(result.error, undefined, output)
  assert.equal(result.status, 0, output)
  assert.doesNotMatch(output, /COMPAT_FAIL|Failed to load configuration|TypeError|ReferenceError|Unable to assign|Invalid property assignment/, output)
  assert.match(output, /COMPAT_PASS/, output)
  console.log("Native UI compatibility passed: palette, literal markup, F1 conceal/reveal, local-only crests")
} finally {
  rmSync(directory, { recursive: true, force: true })
}
