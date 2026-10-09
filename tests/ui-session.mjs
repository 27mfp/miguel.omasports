#!/usr/bin/env node
// Run the real panel in a private Quickshell host on the current compositor.
// Existing visual/interaction runners create and remove their own HEADLESS
// outputs. The desktop shell, bar layout and user preferences are untouched.
import { spawn, spawnSync } from "node:child_process"
import { copyFileSync, cpSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const directory = mkdtempSync(join(tmpdir(), "omasports-ui-session-"))
const shell = join(directory, "shell")
const home = join(directory, "private-home")
const args = process.argv.slice(2)
const palette = args.find(arg => arg.startsWith("--palette="))?.slice(10)
if (palette && !["light", "dark"].includes(palette)) throw new Error("Palette must be light or dark")
const ref = args.find(arg => arg.startsWith("--source-ref="))?.slice(13)
const separator = args.indexOf("--")
const command = separator >= 0 ? args.slice(separator + 1) : ["node", "tests/visual.mjs", "--sport=all", "--tab=all"]
if (!command.length) throw new Error("A command must follow --")
let host
let log = ""
let status = 1
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
try {
  mkdirSync(join(shell, "sports"), { recursive: true })
  mkdirSync(join(home, ".config", "omarchy"), { recursive: true })
  const preferences = args.includes("--empty") ? { sport: "football", notifications: false } : {
    sport: "football", notifications: false,
    football: { leagueIds: ["47", "61"], teamIds: ["9825", "9772", "9767", "9775"], teamName: "Arsenal", standingsLeagueId: "47" },
    nba: { teamIds: ["13", "9"], teamName: "Los Angeles Lakers", standingsGroup: "Western Conference" },
    f1: { teamIds: ["verstappen"], teamName: "Max Verstappen", standingsGroup: "Drivers" },
    nfl: { teamIds: ["3", "2", "1"], teamName: "Chicago Bears", standingsGroup: "American Football Conference" },
    mlb: { teamIds: ["2", "10", "1"], teamName: "Boston Red Sox", standingsGroup: "American League" },
    nhl: { teamIds: ["1", "2"], teamName: "Boston Bruins", standingsGroup: "Eastern Conference" }
  }
  writeFileSync(join(home, ".config", "omarchy", "sports-favorites.json"), JSON.stringify(preferences))
  const systemShell = join(process.env.OMARCHY_PATH || "/usr/share/omarchy", "shell")
  for (const name of ["Commons", "Ui"]) cpSync(join(systemShell, name), join(shell, name), { recursive: true })
  // The host's cross-output dismiss windows would intercept real desktop
  // clicks during headless tests. Disable them only in this private host.
  const keyboardPanel = join(shell, "Ui", "KeyboardPanel.qml")
  const keyboardSource = readFileSync(keyboardPanel, "utf8")
  const dismissModel = "model: root.open ? Quickshell.screens : []"
  if (!keyboardSource.includes(dismissModel)) throw new Error("Headless dismissal isolation contract changed")
  writeFileSync(keyboardPanel, keyboardSource.replace(dismissModel, "model: []"))
  let runtimeFiles = readdirSync(repository)
  if (ref) {
    const listing = spawnSync("git", ["ls-tree", "--name-only", ref], { cwd: repository, encoding: "utf8" })
    if (listing.status !== 0) throw new Error(listing.stderr)
    runtimeFiles = listing.stdout.trim().split("\n")
  }
  for (const name of runtimeFiles.filter(name => /\.(qml|js|py)$/.test(name))) {
    const target = join(shell, "sports", name)
    if (ref) {
      const result = spawnSync("git", ["show", `${ref}:${name}`], { cwd: repository, encoding: "utf8" })
      if (result.status !== 0) throw new Error(result.stderr)
      writeFileSync(target, result.stdout)
    } else copyFileSync(join(repository, name), target)
  }
  // Old revisions can also be captured precisely for before/after review.
  const panelFile = join(shell, "sports", "Panel.qml")
  let panelSource = readFileSync(panelFile, "utf8")
  if (!panelSource.includes("function getPanelGeometry")) panelSource = panelSource.replace("    function getUiRevision", '    function getPanelGeometry(): string {\n      return JSON.stringify({ x: panel.cardOrigin.x, y: panel.cardOrigin.y, width: panel.contentWidth, height: panel.contentHeight })\n    }\n' + "    function getUiRevision")
  panelSource = panelSource.replace(/(?:audit-ui-20261008-v2|native-ui-20261008-v3)/g, "native-ui-20261008-v4")
  panelSource = panelSource.replace("    function getUiRevision", `    function testFocusLastRow(): void { root.focusSection = root.focusableControlCount() - 1 }
    function testScrollState(): string { return JSON.stringify({ y: scroll.contentY, headerY: panelHeader.y, height: scroll.height }) }
    function testChooseSport(value: string): void { panelHeader.sportPicker.value = value; panelHeader.sportPicker.changed(value) }
    function testSportPickerValue(): string { return panelHeader.sportPicker.value }
    function testChooseStandings(value: string): void { standingsTab.standingsPicker.value = value; standingsTab.standingsPicker.changed(value) }
    function testStandingsPickerValue(): string { return standingsTab.standingsPicker.value }
    function testToggleSportPicker(): void { root.focusSection = root.sectionIndex("sports"); root.activateFocus() }
    function testSportPickerOpen(): bool { return root.anyPopupOpen() }
    function getUiRevision`)
  writeFileSync(panelFile, panelSource)
  // Only the staged helper gets a private home. Never weaken the production
  // helper's passwd-based home resolution or point tests at real preferences.
  const helper = join(shell, "sports", "secure_io.py")
  const source = readFileSync(helper, "utf8")
  const original = "    entry = pwd.getpwuid(os.geteuid())\n    path = os.path.abspath(entry.pw_dir)"
  if (!source.includes(original)) throw new Error("Private-home staging contract changed")
  writeFileSync(helper, source.replace(original, `    path = ${JSON.stringify(home)}`))
  writeFileSync(join(shell, "shell.qml"), `import QtQuick\nimport Quickshell\nimport qs.Commons\nimport "sports" as Sports\nShellRoot {\n  Sports.Panel {\n    id: sports\n    suppressFocus: true\n    Timer { interval: 700; running: true; onTriggered: { ${palette ? `Color.foreground = "${palette === "light" ? "#242a32" : "#c7d0dd"}"; Color.background = "${palette === "light" ? "#f4f2ee" : "#252a33"}"; Color.accent = "${palette === "light" ? "#245f93" : "#64b8ef"}"; Color.urgent = "${palette === "light" ? "#bb3944" : "#ef777e"}"; Color.shellValues = Object.assign({}, Color.shellValues, {"popups.background": Color.background.toString(), "popups.text": Color.foreground.toString(), "popups.border": Color.accent.toString()});` : ""} sports.setMockModeForTesting(true); sports.startRound(); } }\n  }\n}\n`)
  const env = { ...process.env, OMARCHY_PATH: directory, OMASPORTS_MOCK: "1", OMASPORTS_PRIVATE_UI_TEST: "1" }
  host = spawn("quickshell", ["--no-color", "--path", shell], { env, stdio: ["ignore", "pipe", "pipe"] })
  host.stdout.on("data", data => { log += data })
  host.stderr.on("data", data => { log += data })
  let ready = false
  for (let attempt = 0; attempt < 50; attempt++) {
    await sleep(100)
    const check = spawnSync("omarchy-shell", ["miguel.omasports", "getSuppressFocus"], { env, encoding: "utf8" })
    if (check.status === 0 && check.stdout.trim() === "true") { ready = true; break }
    if (host.exitCode !== null) break
  }
  if (!ready) throw new Error(`Private UI host failed to start:\n${log}`)
  await sleep(900)
  console.log("Private Quickshell host ready; user shell and preferences untouched.")
  const result = await new Promise((resolve, reject) => {
    // Headless output creation/removal is shared compositor state. Keep
    // concurrent sessions from racing output discovery and screenshots.
    const lock = join(process.env.XDG_RUNTIME_DIR || tmpdir(), `omasports-ui-session-${process.getuid()}.lock`)
    const child = spawn("flock", ["--exclusive", lock, command[0], ...command.slice(1)], { env, cwd: repository, stdio: "inherit" })
    child.on("error", reject)
    child.on("exit", code => resolve(code ?? 1))
  })
  status = result
} catch (error) {
  console.error(error.message)
} finally {
  if (host && host.exitCode === null) {
    const stopped = new Promise(resolve => host.once("exit", resolve))
    host.kill("SIGTERM")
    await stopped
  }
  mkdirSync(join(repository, "test-artifacts"), { recursive: true })
  writeFileSync(join(repository, "test-artifacts", "ui-session.log"), log)
  if (/TypeError|ReferenceError|Failed to load configuration/.test(log)) {
    console.error("UI runtime errors found; see test-artifacts/ui-session.log")
    status = 1
  }
  rmSync(directory, { recursive: true, force: true })
}
process.exitCode = status
