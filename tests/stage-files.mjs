// Enumerate the files Quickshell needs when the plugin is staged into a
// temporary config root. Includes nested model/ and controllers/ modules.
import { execFileSync } from "node:child_process"
import { readdirSync } from "node:fs"
import { join } from "node:path"

const SKIP_DIRS = new Set([".git", "tests", "docs", ".github", "test-artifacts", "node_modules", "__pycache__", ".cache"])
const RUNTIME_RE = /\.(qml|js|py)$/

export function listRuntimeFiles(root) {
  const files = []
  function walk(directory, prefix) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (entry.name.startsWith(".") && entry.isDirectory()) continue
      if (entry.isDirectory()) {
        if (SKIP_DIRS.has(entry.name)) continue
        walk(join(directory, entry.name), prefix ? `${prefix}/${entry.name}` : entry.name)
      } else if (RUNTIME_RE.test(entry.name)) {
        files.push(prefix ? `${prefix}/${entry.name}` : entry.name)
      }
    }
  }
  walk(root, "")
  return files.sort()
}

export function listRuntimeFilesAtRef(ref, cwd) {
  // Use git's recursive listing so nested modules from an older revision are
  // staged exactly as they were committed.
  const output = execFileSync("git", ["ls-tree", "-r", "--name-only", ref], { cwd, encoding: "utf8" })
  return output.trim().split("\n").filter(Boolean)
    .filter(name => RUNTIME_RE.test(name) && !name.startsWith("tests/") && !name.startsWith("docs/") && !name.startsWith(".github/"))
    .sort()
}
