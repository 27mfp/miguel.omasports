#!/usr/bin/env node
// Keep active agent-control files out of the installable marketplace payload.
import { readdirSync } from "node:fs"
import { join, relative } from "node:path"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"

const root = fileURLToPath(new URL("../", import.meta.url))
const blockedNames = new Set(["AGENTS.md"])
const found = []

function walk(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === ".git") continue
    const path = join(directory, entry.name)
    if (entry.isDirectory()) walk(path)
    else if (blockedNames.has(entry.name)) found.push(relative(root, path))
  }
}

walk(root)
assert.deepEqual(found, [], `agent-control files must not ship: ${found.join(", ")}`)

console.log("Release payload guard passed (no AGENTS.md files)")
