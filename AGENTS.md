# 🤖 Agent Guide & Engineering Playbook: OmaSports (`miguel.omasports`)

This document serves as the authoritative operational manual for AI agents and developers working on the `miguel.omasports` Omarchy plugin. Follow these instructions, conventions, and architectural contracts to prevent regressions and maintain desktop harmony.

---

## 1. Prime Directive: Zero Desktop Interruption

When developing or executing tests on the user's live system:
- **NEVER steal keyboard focus**: Layer-shell popups in Wayland (`KeyboardPanel`) acquire exclusive keyboard focus by default. Any automated test or background script **must** set `setSuppressFocus(true)` via IPC.
- **NEVER popup windows on the active screen**: Always run visual tests using the non-interruptive headless test harness (`node tests/visual.mjs`), which provisions a virtual headless Wayland monitor (`HEADLESS-N`) and routes the panel there.
- **Clean up after yourself**: If a test or script creates a headless monitor or changes settings, always guarantee restoration in a `finally` block.

---

## 2. Architecture & Codebase Map

The plugin uses a clean decoupled architecture: **pure JavaScript data engine** + **modular QML views**.

```
miguel.omasports/
├── SportsModel.js         # Core data engine: parsers, caching, catalogs, state management (pure JS, 0 QML deps)
├── Panel.qml              # Main panel coordinator, IPC target "miguel.omasports", layout & focus management
├── PanelHeader.qml        # Header bar: sport selector (⚽, 🏀, 🏎, 🏈, ⚾, 🏒), live indicators, settings toggle
├── FixturesTab.qml        # Schedule tab: multi-competition fixtures, team filters, match spotlight card
├── LiveTab.qml            # Dedicated live score feed, live count badge, idle fallback card
├── StandingsTab.qml       # League tables: Football, US sports (NBA/NFL/MLB/NHL), F1 (Drivers & Constructors)
├── SettingsTab.qml        # Preferences: desktop notifications, anti-spoiler shield, refresh cadence, team follow
├── NewsCard.qml            # Collapsible league wire & breaking news headlines card
├── MatchSpotlight.qml     # Hero card showcasing followed team's live/upcoming match
├── MatchRow.qml           # Fixture list row with kickoff time, stadium info, and score pills
├── LiveRow.qml            # Real-time match row with progress bar, minute counter, HT score, and click-to-reveal
├── StandingsRow.qml       # Table row with rank badges (🥇, 🥈, 🥉), crests, and sport-specific statistics
├── TeamCrest.qml          # Crest loader: local disk cache → remote URL fallback → monogram canvas fallback
├── BarWidget.qml          # Omarchy top bar widget: live score ticker, sport icon, and live pulsing dot
├── manifest.json          # Omarchy plugin manifest
└── tests/
    ├── run-all.mjs        # Unified S-Tier master test orchestrator
    ├── visual.mjs         # Headless visual test runner with perceptual diff comparisons
    ├── diff.py            # Perceptual diffing engine (pixel mismatch % & neon magenta heatmaps)
    ├── crop.py            # Automated popup card bounding-box auto-crop tool
    ├── interaction.mjs    # Safe opt-in headless interaction tests (routing, toggles, lifecycle)
    ├── scenarios.mjs      # Chaos & edge-case scenario tests (429 rate limit, shootouts, red cards)
    ├── notifications.mjs  # 9 notification delivery, 500ms pacing & security tests
    ├── crest-resilience.mjs # 8 crest cache resilience & 404/corrupt fallback tests
    ├── burnin.mjs         # 3 burn-in & memory stability tests (100 mock cycles, TTL pruning)
    ├── sportsmodel.test.mjs # 91 unit tests covering all pure JS functions
    ├── offline.mjs        # 13 offline golden tests against frozen provider payloads
    ├── live.mjs           # Live E2E integration tests against real provider APIs
    ├── manifest.mjs       # Manifest/package structure contract checks
    ├── qml-contract.mjs   # Static cross-file QML wiring and harness contracts
    ├── capture-fixtures.mjs # Captures new real-world payloads for offline testing (network required)
    └── fixtures/
        ├── goldens.json   # Frozen JSON payloads and parser golden results
        └── visual-goldens/# Approved baseline visual PNG snapshots
```

---

## 3. Quickshell IPC Protocol

All IPC commands are sent via the running Omarchy shell:
`omarchy-shell miguel.omasports <method> [args...]`

| Method | Arguments | Description |
| :--- | :--- | :--- |
| `route` | `tabName: string` (`"fixtures"`, `"live"`, `"standings"`, `"settings"`) | Opens the panel and routes directly to the requested tab. |
| `sport` | `sportName: string` (`"football"`, `"f1"`, `"nba"`, `"nfl"`, `"mlb"`, `"nhl"`) | Switches active sport and triggers background fetch. |
| `getActiveSport` | *none* | Returns the currently active sport string (e.g. `"football"`). |
| `getRoute` / `getOpened` | *none* | Returns current panel route / visibility for safe test orchestration. |
| `getAntiSpoiler` / `getNotifications` | *none* | Returns notification privacy settings. |
| `getBackgroundUpdates` / `getBarTicker` / `getSpotlight` | *none* | Returns display and polling settings. |
| `getSuppressFocus` / `getTargetScreen` | *none* | Returns test-isolation state for verification and restoration. |
| `toggleSpoiler` | *none* | Toggles Anti-Spoiler Shield globally. |
| `refresh` | *none* | Force-refreshes data for the current sport. |
| `open` | *none* | Opens the panel window. |
| `close` | *none* | Closes the panel window. |
| `toggle` | *none* | Toggles panel visibility. |
| `setSuppressFocus` | `suppress: bool` | Enables/disables layer-shell keyboard focus acquisition (critical for automated testing). |
| `setTargetScreen` | `screenName: string` | Directs the panel to render on a specific monitor (e.g. `"HEADLESS-1"`). Empty string resets to default. |

---

## 4. Testing Playbook

### A. Unified S-Tier Master Runner (Run Everything)
Executes the local quality gates across pure JS logic, goldens, manifest/package integrity, scenarios, notifications, crest resilience, burn-in memory stability, plugin validation, live E2E integration, and perceptual visual diffs. Desktop interaction testing is opt-in:
```bash
node tests/run-all.mjs           # standard full verification (includes live E2E and visual diff)
node tests/run-all.mjs --quick   # non-desktop logic gates
node tests/run-all.mjs --quick --interactive # opt-in safe headless interaction gate
node tests/run-all.mjs --full    # exhaustive run across all 6 sports and tabs
```

### B. Unit Tests (Pure Model Engine)
Always run before committing changes to `SportsModel.js`:
```bash
node tests/sportsmodel.test.mjs
```
*Current status: 91 tests passing (100%).*

### C. Offline Golden Regression Tests
Verifies parser output against frozen real-world provider payloads without touching the network:
```bash
node tests/offline.mjs
```
*Current status: 13 tests passing (100%).*
> **Note**: Only update goldens via `node tests/capture-fixtures.mjs` if you are intentionally updating data schemas.

### D. QML Cross-File Contract Suite
Checks score-reveal/anti-spoiler wiring, provider retry floors, and fail-closed desktop test harness contracts without starting Quickshell:
```bash
node tests/qml-contract.mjs
```

### E. Chaos & Edge-Case Scenario Suite
Verifies resilience against penalty shootouts, extra time (`AET`), red cards, HTTP 429 rate limits, HTML bot-walls, and extreme team names:
```bash
node tests/scenarios.mjs
```
*Current status: 6 tests passing (100%).*

### F. Safe Headless Interaction Suite
Tests real-time UI state toggling only on a dedicated virtual monitor with confirmed focus suppression:
```bash
node tests/interaction.mjs
```
*Current status: 6 tests passing (100%) when run on a dedicated headless monitor.*

### G. Notification & Delivery Suite
Validates desktop notification diffing, goal alerts, anti-spoiler concealment, lifecycle transitions, crest key sanitization, queue capping, 500ms toast pacing, and `notify-send` argument escaping:
```bash
node tests/notifications.mjs
```
*Current status: 9 tests passing (100%).*

### H. Crest Cache Resilience & Fallback Suite
Validates monogram derivation, cold cache resilience, broken CDN recovery (404/500/corrupt bytes), and system log hygiene:
```bash
node tests/crest-resilience.mjs
```
*Current status: 8 tests passing (100%).*

### I. Burn-In & Memory Stability Suite
Simulates 100 consecutive mock polling cycles, verifies array and queue bounds (`detailQueue ≤ 8`, `notificationQueue ≤ 5`), tests `seenMap` TTL pruning (6h), and measures heap stability:
```bash
node tests/burnin.mjs
```
*Current status: 3 tests passing (100%).*

### J. Omarchy Plugin Validation
Validates QML syntax, plugin structure, and manifest integrity:
```bash
omarchy plugin validate .
```
*Must always exit with return code 0.*

### K. Live Provider E2E Integration
Hits real provider APIs (FotMob, ESPN, Jolpica) to verify parsers work against live data. Requires network access; only runs in standard and `--full` modes:
```bash
node tests/live.mjs football   # football only (default in standard mode)
node tests/live.mjs all        # all 6 sports (used in --full mode)
```
*Current status: 8 tests passing (football). ~20 tests across all sports.*
> **Note**: Excluded from `--quick` / pre-commit to avoid blocking commits on third-party network issues.

### L. Autonomous Perceptual Visual Diffing
Runs pixel-level visual regression testing **headlessly in the background** against deterministic runtime mock data, supporting HiDPI scaling and viewport height constraints (≤ 72% screen height). It temporarily enables and restores the runtime-only mock override:
```bash
# Compare against approved visual baselines
node tests/visual.mjs --sport=f1 --tab=standings
node tests/visual.mjs --sport=football --tab=all

# Test with HiDPI and responsive scales
node tests/visual.mjs --sport=f1 --tab=standings --scale=1.0
node tests/visual.mjs --sport=f1 --tab=standings --scale=2.0

# Update visual golden baselines when design changes are intentional (headless only)
node tests/visual.mjs --sport=f1 --tab=standings --update-goldens

# Inspect the generated 3-way comparative visual report
xdg-open test-artifacts/visual-report.html
```
The visual runner fails closed for missing or unmeasurable baselines; only approve
new goldens after reviewing the headless capture. Full `--sport=all --tab=all`
coverage requires a committed golden for every requested sport/view.

### M. Automated Git Pre-Commit Quality Gate
A git pre-commit hook runs the `--quick` suite (~6.5s) before every commit. If any test fails, the commit is rejected:
```bash
# The hook lives at .git/hooks/pre-commit and runs automatically.
# To test it manually:
.git/hooks/pre-commit
```

### N. Reloading Omarchy Shell
To apply QML changes to the live desktop environment without restarting the user session:
```bash
omarchy-restart-shell
```

---

## 5. Critical Engineering Rules & Gotchas

1. **Explicit Routing vs. Live Auto-Switching (`routedExplicitly`)**:
   - `Panel.qml` has a convenience feature where opening the panel while a match is live switches to the `Live` tab (`tabIndex = 1`).
   - To prevent this from hijacking explicit user or IPC navigation to `Fixtures` or `Standings`, `route(tabName)` sets `root.routedExplicitly = true`.
   - Any new tab routing logic must respect `!root.routedExplicitly`.

2. **F1 Standings Column Spacing**:
   - In `StandingsTab.qml` and `StandingsRow.qml`, Driver and Constructor columns share horizontal space.
   - The driver column must be set to at least `Style.space(170)` with a right margin to prevent collisions between long names (e.g. `Andrea Kimi Antonelli`) and constructor labels (e.g. `Mercedes`).

3. **Live Half-Time Scoring (`⏱ HT`)**:
   - FotMob live payloads do not always supply a top-level `halfTimeScore` field.
   - `SportsModel.js` aggregates half-time scores by scanning `matchFacts.events` for `isHalfTime: true` or calculating period scores.
   - `LiveRow.qml` checks `halfTimeText !== ""` before displaying the half-time scoreline.

4. **Anti-Spoiler Concealment**:
   - When `antiSpoiler` is enabled, scores must be hidden behind `"••••"` across `LiveRow`, `MatchSpotlight`, and `MatchRow`.
   - Every score badge must support click-to-reveal via `controller.toggleRevealScore(matchId)` or `controller.revealMatch(matchId)`.

5. **API Rate Limits**:
   - **FotMob & F1 (Jolpica)**: Route through Cloudflare edge caching. Minimum polling cadence: **20 seconds**. Never poll faster to avoid IP bans.
   - **ESPN (NBA, NFL, MLB, NHL)**: Direct public API. Minimum polling cadence: **15 seconds**.
