<div align="center">

# ⚽ OmaSports · Multi-Sport Hub

**The all-in-one live sports tracker and score center for [Omarchy](https://github.com/basecamp/omarchy).**

Track real-time scores, team schedules, and standings across **Football**, **NBA**, **Formula 1**, **NFL**, **MLB**, and **NHL** directly from your Linux desktop bar.

[![Omarchy Plugin](https://img.shields.io/badge/omarchy-plugin-blue.svg)](https://omarchy.org)
[![Version](https://img.shields.io/badge/version-1.4.0-emerald.svg)](manifest.json)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-orange.svg)]()

</div>

---

## 🌟 Highlights

- **🔔 Native Desktop Notifications (`notify-send`)**:
  - Instant notifications on **Goals** (`⚽ GOAL! <Team>`) for your **followed teams**, with club crests and updated match scorelines.
  - Alerts when a match **kicks off live** (`● LIVE`) and a **15-minute pre-match warning** for upcoming games and F1 Grand Prix sessions.
  - Quick-toggle bell icon `󰂚` / `󰂛` directly in the top header.

- **📅 Multi-Day Schedules (NBA, NFL, MLB, NHL)**:
  - ESPN fixtures cover yesterday's results plus the next three days, not just today's slate.
  - Automatic retry with backoff when a provider round fails, for every sport.

- **⭐ Multi-Team & Multi-Driver Following**:
  - Follow multiple clubs and drivers simultaneously per sport (e.g. *Benfica* + *Arsenal*, *Lakers* + *Warriors*, *Leclerc* + *Hamilton*).
  - Quick-remove badge chips (`★ Benfica ✕`) and dedicated combined schedule views (`★ All Followed Favorites`).

- **⚡ Zero-Latency Instant Team Search**:
  - Pre-populated database with over 90+ major global clubs (Primeira Liga, Premier League, La Liga, Serie A, Bundesliga, Ligue 1, Brasileirão, etc.) and all 2026 F1 constructors and drivers.
  - Search and filter teams in 0ms without waiting for network loads.

- **⚡ Live Bar Ticker & Dynamic Pill**:
  - Live score ticker directly on your status bar whenever your favorite team is playing (e.g. `⚽ BEN 2-1 SPO 74'` or `🏀 LAL 104-98 GSW Q4`).
  - Dynamic status bar icon matching active sport (`⚽`, `🏀`, `🏎`, `🏈`, `⚾`, `🏒`) with a pulsing notification badge during live events.

- **🛡️ Anti-Spoiler Mode**:
  - Keep final scores concealed (`••••`) until you are ready to see them.
  - One-click / hover reveal for individual matches, or toggle globally via the header button `󰈈` / `󰈉` or the `s` key.

- **🛡️ Team Crests & Monogram Fallbacks**:
  - Fast local disk caching (`~/.cache/omarchy-omasports/logos/`) with a single shared cache-key scheme, so every downloaded logo is guaranteed to render.
  - Remote fallback on first run (before the disk cache is warm) and beautiful circular monogram fallbacks (`SL`, `FC`, `LAL`, `BOS`) with zero visual holes.

- **★ Team & Driver Spotlight**:
  - Dedicated hero card highlighting your favorite club, franchise, or driver.
  - Multi-competition schedule: For football, tracks UEFA Champions League, domestic league, and cups; for F1, tracks the upcoming Grand Prix weekend.

- **● Live Broadcast Scorecard**:
  - Live game minute indicators with animated pulsing badges (`● 45' HT`, `● Q3 4:21`, `● Top 5th`, `● 3rd 12:10`, `● RACE DAY`).
  - Broadcast scorecard layout showing stadium venue, city, referee, attendance, and period scores.

- **⏱ Live Clock That Actually Tracks The Match**:
  - While any followed match is live, the plugin auto-polls every ~40 seconds (regardless of the slower background refresh interval).
  - Between polls, the minute is interpolated forward from the provider's last report with a stoppage-time cap, so the clock never sits frozen.
  - Opening the panel during a live match lands you directly on the **Live** tab.

- **󰝘 Standings & League Tables**:
  - ⚽ **Football**: Champions League, European qualification, Relegation zones.
  - 🏀 **NBA**: Eastern & Western Conference tables with Playoff (1–6) and Play-in (7–10) seeds.
  - 🏎 **Formula 1**: Drivers and Constructors World Championship standings.
  - 🏈 **NFL**: AFC & NFC standings.
  - ⚾ **MLB**: American League & National League tables.
  - 🏒 **NHL**: Eastern & Western Conference rankings.

- **⌨ Keyboard-First Navigation & Rich IPC**:
  - `r` or `R`: Refresh match data.
  - `s` or `S`: Toggle Anti-Spoiler mode.
  - `←` / `→`: Switch tabs (`★ Fixtures`, `● Live`, `󰝘 Standings`).
  - Full CLI control via `omarchy-shell miguel.omasports`:
    - `omarchy-shell miguel.omasports toggle`
    - `omarchy-shell miguel.omasports sport f1`
    - `omarchy-shell miguel.omasports route live`
    - `omarchy-shell miguel.omasports toggleSpoiler`

---

## Install

### From Git (Recommended)

```bash
omarchy plugin add https://github.com/27mfp/miguel.omasports --enable
```

### Manual Local Install

```bash
# 1. Validate the plugin manifest
omarchy plugin validate .

# 2. Copy files to your Omarchy plugins directory
mkdir -p "$HOME/.config/omarchy/plugins/miguel.omasports"
cp manifest.json BarWidget.qml Panel.qml MatchRow.qml LiveRow.qml StandingsRow.qml MatchSpotlight.qml TeamCrest.qml NetworkProcess.qml Theme.qml RetryTimer.qml SportsModel.js "$HOME/.config/omarchy/plugins/miguel.omasports/"

# 3. Rescan and enable
omarchy-shell shell rescanPlugins
omarchy plugin enable miguel.omasports --section center
```

### Remove

```sh
omarchy plugin remove miguel.omasports
```

---

## Configure

- **Sport Selector**: Switch active sport in one click (`⚽`, `🏀`, `🏎`, `🏈`, `⚾`, `🏒`).
- **Show Live Ticker on Bar**: Display live scores on the bar chip (`settings.showBarTicker`).
- **Anti-Spoiler Mode**: Conceal finished match scores until clicked (`settings.antiSpoiler`).
- **Followed Leagues**: Select up to 12 football leagues simultaneously.
- **Refresh Frequency**: Choose polling intervals from 5 to 60 minutes.

Configuration is automatically saved to `~/.config/omarchy/sports-favorites.json`.

---

## Supported Sports

| Sport | Icon | Leagues & Tournaments | Data Provider |
|---|:---:|---|---|
| **Football / Soccer** | ⚽ | Premier League, La Liga, Primeira Liga, Serie A, Bundesliga, Champions League, Europa League, MLS, Brasileirão, 100+ global leagues & cups | FotMob |
| **Basketball** | 🏀 | National Basketball Association (NBA) — All 30 franchises, Eastern & Western Conferences | ESPN |
| **Formula 1** | 🏎 | FIA F1 World Championship — 2026 Grand Prix Calendar, Driver & Constructor Championships | Jolpica / Ergast |
| **American Football** | 🏈 | National Football League (NFL) — All 32 teams, AFC & NFC | ESPN |
| **Baseball** | ⚾ | Major League Baseball (MLB) — All 30 teams, AL & NL | ESPN |
| **Ice Hockey** | 🏒 | National Hockey League (NHL) — All 32 teams, Eastern & Western Conferences | ESPN |

---

## Development

The data engine (`SportsModel.js`) is pure JavaScript with no QML dependencies, so the parsers are covered by a Node test suite:

```bash
node tests/sportsmodel.test.mjs
```

This covers state persistence/migration, the shared crest cache-key scheme, ESPN/FotMob/Jolpica parsers, zone cutoffs per sport, match filtering/grouping, mock mode, and catalog integrity (including the ESPN-verified NHL/MLB team ids).

### Offline regression suite (no network)

Real provider payloads are frozen in `tests/fixtures/` together with **golden snapshots** of what the parsers currently produce, so any parser drift (renamed fields, changed sorting, lost zones) fails fast without touching the network:

```bash
node tests/capture-fixtures.mjs   # refresh frozen payloads + goldens (needs network, run occasionally)
node tests/offline.mjs            # replay parsers vs fixtures + goldens (offline)
```

(`tests/live.mjs` and `tests/capture-fixtures.mjs` are not run in CI; they require network access and manual acceptance of new provider data — run them locally before releases.)

Run `offline.mjs` before every commit that touches `SportsModel.js`; re-run the capture script only when you want to accept new provider data.

### Runtime requirements

The widget uses the system `curl`, `xdg-open`, and `notify-send` commands. Scores
remain available without `notify-send`, but desktop alerts are disabled and the
panel reports that capability. `curl` is required for provider data; the
built-in mock mode remains available for offline UI development.

### Mock mode (`OMASPORTS_MOCK=1`)

A deterministic built-in simulation for UI development — no network at all:

```bash
OMASPORTS_MOCK=1 quickshell -c <config>   # or set OMASPORTS_MOCK=1 however you launch the panel
```

> `OMASPORTS_MOCK` is read once at panel construction — toggle the env then rescan the plugin.

Every sport gets a scripted timeline anchored to panel launch: a live match already in progress, a kickoff 12 minutes in (exercises pre-match notifications), a recent result, and future fixtures. The football match scores a scripted goal mid-session to exercise goal notifications, clocks tick through HT → 2nd half → FT, and F1 shows a race-day weekend with sessions. Standings render too.

There is also a **live end-to-end harness** that fetches real payloads from FotMob, ESPN, and Jolpica using the exact same `curl` invocations the plugin uses at runtime, then runs the actual parsers against them:

```bash
node tests/live.mjs all        # every sport
node tests/live.mjs football   # FotMob leagues, standings, team page, crest CDN, grouping, spotlight, live details
node tests/live.mjs nba        # ESPN scoreboard + standings
node tests/live.mjs nfl
node tests/live.mjs mlb
node tests/live.mjs nhl
node tests/live.mjs f1         # Jolpica calendar + driver/constructor standings
```

QML files can be syntax-checked with `qmllint` (from `qt6-declarative`):

```bash
qmllint *.qml
```

---

## License

Distributed under the [MIT License](LICENSE).
