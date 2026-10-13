#!/usr/bin/env node
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { copyFileSync, mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

// Stage current production components because Quickshell confines imports to
// its config root. Never attach to or restart the user's shell.
const directory = mkdtempSync(join(tmpdir(), "omasports-runtime-"))
try {
  for (const name of ["NetworkProcess.qml", "SecureProcess.qml"])
    copyFileSync(new URL(`../${name}`, import.meta.url), join(directory, name))
  copyFileSync(new URL("./runtime/shell.qml", import.meta.url), join(directory, "shell.qml"))
  const env = { ...process.env, QT_QPA_PLATFORM: "offscreen", QT_QUICK_BACKEND: "software" }
  delete env.WAYLAND_DISPLAY
  delete env.QS_CONFIG_PATH
  const result = spawnSync("quickshell", ["--no-color", "--path", directory], {
    encoding: "utf8", timeout: 10000, env
  })
  if (result.error?.code === "ENOENT") throw new Error("Quickshell is required for the opt-in runtime suite.")
  const output = (result.stdout || "") + (result.stderr || "")
  assert.equal(result.error, undefined, output)
  assert.equal(result.status, 0, output)
  assert.doesNotMatch(output, /RUNTIME_FAIL|Failed to load configuration|TypeError|ReferenceError/, output)
  assert.match(output, /RUNTIME_PASS/, output)
  console.log("Offscreen Quickshell process lifecycle passed")
} finally {
  rmSync(directory, { recursive: true, force: true })
}
