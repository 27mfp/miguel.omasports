// Shared loader for SportsModel.js in plain Node.
//
// SportsModel.js is a QML JavaScript library (`.pragma library`) that uses
// QML's `.import "file.js" as Namespace` syntax. Node cannot parse those lines,
// so this loader expands every imported module into a scoped IIFE and exposes
// its top-level functions/vars under the requested namespace. The facade's
// public API then stays identical for both QML and Node.
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const ENTRY = resolve(ROOT, "SportsModel.js")

const IMPORT_RE = /^\.import\s+"([^"]+)"\s+as\s+([A-Za-z_$][\w$]*)\s*$/gm
const PRAGMA_RE = /^\.pragma\s+library\s*$/gm
const EXPORT_RE = /^(?:function\s+([A-Za-z_$][\w$]*)\s*\(|(?:var|const|let)\s+([A-Za-z_$][\w$]*)\s*=)/gm

function moduleExports(source) {
  const names = []
  for (const match of source.matchAll(EXPORT_RE)) {
    names.push(match[1] || match[2])
  }
  return [...new Set(names)]
}

function expandModule(file, stack = new Set()) {
  if (stack.has(file)) throw new Error(`circular SportsModel import: ${file}`)
  stack.add(file)
  let source = readFileSync(file, "utf8").replace(PRAGMA_RE, "")
  const imports = []
  for (const match of source.matchAll(IMPORT_RE)) {
    const target = resolve(dirname(file), match[1])
    imports.push({ declaration: match[0], namespace: match[2], file: target })
  }
  source = source.replace(IMPORT_RE, "")
  let prefix = ""
  for (const entry of imports) {
    prefix += `var ${entry.namespace} = (function() {\n${expandModule(entry.file, stack)}\n})();\n`
  }
  const names = moduleExports(source)
  const body = `${prefix}${source}\nreturn { ${names.map(name => `${name}: ${name}`).join(", ")} };`
  stack.delete(file)
  return body
}

function expandEntry() {
  let source = readFileSync(ENTRY, "utf8").replace(PRAGMA_RE, "")
  const imports = []
  for (const match of source.matchAll(IMPORT_RE)) {
    imports.push({
      declaration: match[0],
      namespace: match[2],
      file: resolve(dirname(ENTRY), match[1])
    })
  }
  source = source.replace(IMPORT_RE, "")
  let prefix = ""
  for (const entry of imports) {
    prefix += `var ${entry.namespace} = (function() {\n${expandModule(entry.file)}\n})();\n`
  }
  return prefix + source
}

/** Transformed classic script (no ESM exports) for vm.runInContext. */
export function modelScript() {
  return expandEntry()
}

/** Transformed ESM source with the requested public exports. */
export function modelSource(exported) {
  return expandEntry() + "\nexport { " + exported.join(", ") + " }\n"
}

/** Load SportsModel.js as a Node ES module exposing `exported`. */
export async function loadModel(exported) {
  const source = modelSource(exported)
  return import("data:text/javascript;base64," + Buffer.from(source).toString("base64"))
}

export const MODEL_ROOT = ROOT
