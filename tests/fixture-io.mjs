// Transparent fixture reader: large captured provider payloads are stored as
// `.gz` to keep the repository checkout small; small fixtures stay readable.
import { existsSync, readFileSync } from "node:fs"
import { gunzipSync } from "node:zlib"

const FIXTURES = new URL("./fixtures/", import.meta.url)

export function fixtureUrl(name) {
  const plain = new URL(name, FIXTURES)
  if (existsSync(plain)) return plain
  const compressed = new URL(name + ".gz", FIXTURES)
  if (existsSync(compressed)) return compressed
  return null
}

export function haveFixture(name) {
  return fixtureUrl(name) !== null
}

export function readFixture(name) {
  const url = fixtureUrl(name)
  if (!url) throw new Error(`missing fixture: tests/fixtures/${name}`)
  const raw = readFileSync(url)
  const bytes = url.pathname.endsWith(".gz") ? gunzipSync(raw) : raw
  return bytes.toString("utf8")
}

export function fixtureBytes(name) {
  const url = fixtureUrl(name)
  if (!url) throw new Error(`missing fixture: tests/fixtures/${name}`)
  const raw = readFileSync(url)
  return url.pathname.endsWith(".gz") ? gunzipSync(raw) : raw
}
