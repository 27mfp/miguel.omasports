#!/usr/bin/env node
import assert from "node:assert/strict"
import { readFileSync, existsSync } from "node:fs"
import { spawnSync } from "node:child_process"

const helperSource = readFileSync(new URL("../secure_io.py", import.meta.url), "utf8")
const panelSource = readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")

const behavioral = spawnSync("/usr/bin/python3", ["-I", "-S", new URL("./security-helper.py", import.meta.url).pathname], {
  encoding: "utf8",
  env: { LANG: "C.UTF-8", LC_ALL: "C.UTF-8" }
})
assert.equal(behavioral.status, 0, behavioral.stderr || behavioral.stdout)

// Producer and cache limits are explicit and enforced while streaming, not
// inferred solely from Content-Length.
assert.match(helperSource, /FETCH_HARD_MAX_BYTES\s*=\s*8\s*\*\s*1024\s*\*\s*1024/)
assert.match(helperSource, /CREST_MAX_BYTES\s*=\s*512\s*\*\s*1024/)
assert.match(helperSource, /Content-Length.*exceeds byte limit/)
assert.match(helperSource, /response exceeded byte limit/)

// Writable roots come from the authenticated OS account, not HOME or another
// inherited environment variable.
assert.match(helperSource, /pwd\.getpwuid\(os\.geteuid\(\)\)/)
assert.doesNotMatch(helperSource, /os\.environ\[["']HOME["']\]|os\.environ\.get\(["']HOME["']/)

// Cached images are structurally validated, content-addressed in metadata,
// and atomically published descriptor-relative with no-follow opens.
assert.match(helperSource, /zlib\.crc32/)
assert.match(helperSource, /hashlib\.sha256/)
assert.match(helperSource, /os\.O_NOFOLLOW/)
assert.match(helperSource, /os\.replace\(temp, name, src_dir_fd=dir_fd, dst_dir_fd=dir_fd\)/)
assert.match(panelSource, /crest-batch/)

for (const fixture of [
  "tests/fixtures/fotmob-team-9825.html",
  "tests/fixtures/fotmob-league-47.html",
  "tests/fixtures/espn-nba-scoreboard.json"
]) {
  const bytes = readFileSync(new URL(`../${fixture}`, import.meta.url)).byteLength
  assert.ok(bytes < 4 * 1024 * 1024, `${fixture} exceeds the configured provider cap`)
}

assert.ok(existsSync(new URL("../SecureProcess.qml", import.meta.url)))
console.log("Security hardening suite passed (caps, canonical home, no-follow state/cache, atomic image validation)")
