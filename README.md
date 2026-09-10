<div align="center">
  <img src="icon.png" alt="OmaSports icon" width="96" height="96">
  <h1>OmaSports</h1>
  <p><strong>Live scores, fixtures, and standings for Omarchy.</strong></p>
  <p>
    <a href="https://github.com/basecamp/omarchy">Omarchy</a> ·
    <a href="#install">Install</a> ·
    <a href="#configuration">Configure</a> ·
    <a href="#development">Development</a>
  </p>
  <p>
    <img src="https://img.shields.io/badge/version-1.4.0-38bdf8" alt="Version 1.4.0">
    <img src="https://img.shields.io/badge/platform-Linux-f59e0b" alt="Linux">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e" alt="MIT license"></a>
  </p>
</div>

![OmaSports football fixtures panel](preview.png)

<p align="center"><sub>Preview captured from the live FotMob feed. Fixture times and availability vary by season and timezone.</sub></p>

## Overview

OmaSports is a native Omarchy bar plugin for keeping up with the games you follow. Open the panel for a compact score center, or leave the live ticker enabled for a quick update beside the bar icon.

It supports football, basketball, Formula 1, American football, baseball, and ice hockey without accounts or API keys.

## Features

- **Live scores and fixtures** — Browse live games, recent results, upcoming matches, and league news.
- **Standings** — View football tables, NBA/NHL conferences, NFL and MLB divisions, and F1 driver or constructor championships.
- **Follow teams and drivers** — Combine multiple favorites into one schedule and spotlight the next important game.
- **Anti-spoiler mode** — Hide live and finished scores until you choose to reveal them.
- **Bar ticker** — Show a followed team’s live score beside the active sport icon.
- **Desktop notifications** — Receive kickoff, goal, half-time, and full-time alerts through `notify-send`.
- **Match detail cards** — See broadcast information, venues, leaders, form, events, possession, and period scores when the provider supplies them.
- **Keyboard and IPC control** — Navigate without a mouse or script the panel with `omarchy-shell`.
- **Resilient caching** — Team crests use a local cache with remote and monogram fallbacks.

## Supported sports

| Sport | Coverage | Provider |
| --- | --- | --- |
| ⚽ Football / soccer | 100+ leagues and cups, including Premier League, La Liga, Primeira Liga, Serie A, Bundesliga, Champions League, MLS, and Brasileirão | [FotMob](https://www.fotmob.com/) |
| 🏀 Basketball | NBA teams, fixtures, and Eastern/Western Conference standings | [ESPN](https://www.espn.com/) |
| 🏎 Formula 1 | Grand Prix calendar, sessions, driver standings, and constructor standings | [Jolpica](https://api.jolpi.ca/ergast/f1/) |
| 🏈 American football | NFL fixtures and AFC/NFC standings | [ESPN](https://www.espn.com/) |
| ⚾ Baseball | MLB fixtures and American/National League standings | [ESPN](https://www.espn.com/) |
| 🏒 Ice hockey | NHL fixtures and Eastern/Western Conference standings | [ESPN](https://www.espn.com/) |

Provider data is public and may change, be rate-limited, or be temporarily unavailable. OmaSports does not require credentials and does not send data to a separate OmaSports service.

## Install

### From GitHub

```bash
omarchy plugin add https://github.com/27mfp/miguel.omasports --enable
```

The plugin appears in the center section of the Omarchy bar. Open it from the bar icon, then select a sport and the teams or leagues you want to follow.

### From a local checkout

```bash
omarchy plugin validate .
install_dir="$HOME/.config/omarchy/plugins/miguel.omasports"
mkdir -p "$install_dir"
cp -- *.qml SportsModel.js manifest.json icon.svg icon.png "$install_dir/"
omarchy-shell shell rescanPlugins
omarchy plugin enable miguel.omasports --section center
```

To remove it:

```bash
omarchy plugin remove miguel.omasports
```

## Configuration

The panel’s settings screen controls notifications, background polling, anti-spoiler mode, refresh cadence, followed teams, the bar ticker, the spotlight card, and the league news wire.

The plugin also exposes these manifest settings:

| Setting | Default | Description |
| --- | --- | --- |
| `showBarTicker` | `true` | Show a followed team’s live score in the bar. |
| `backgroundUpdates` | `true` | Keep score data fresh while the panel is closed. |
| `panelPosition` | `auto` | Choose automatic, icon-anchored, or centered panel placement. |

Preferences are stored locally at:

```text
~/.config/omarchy/sports-favorites.json
```

Team crests are cached locally at:

```text
~/.cache/omarchy-omasports/logos/
```

## Keyboard and IPC

Inside the panel:

| Key | Action |
| --- | --- |
| `r` | Refresh scores |
| `s` | Toggle anti-spoiler mode |
| `←` / `→` | Move between tabs and controls |
| `Enter` | Activate the focused control or match |

Common shell commands:

```bash
omarchy-shell miguel.omasports toggle
omarchy-shell miguel.omasports route live
omarchy-shell miguel.omasports sport f1
omarchy-shell miguel.omasports refresh
omarchy-shell miguel.omasports toggleSpoiler
omarchy-shell miguel.omasports getActiveSport
```

The complete IPC contract, including safe headless-test controls, is documented in [AGENTS.md](AGENTS.md).

## Requirements

- Omarchy with its Quickshell-based desktop shell
- `curl` for provider requests
- `xdg-open` for opening provider match pages
- `notify-send` for desktop notifications (optional; scores still work without it)

No account, API key, background daemon, or separate service is required.

## Development

Validate the plugin and run the fast local quality gate:

```bash
omarchy plugin validate .
node tests/run-all.mjs --quick
```

The repository also includes:

```bash
node tests/interaction.mjs                 # headless IPC and lifecycle tests
node tests/visual.mjs --sport=all --tab=all # headless visual regression suite
node tests/offline.mjs                     # frozen provider payload regressions
node tests/live.mjs all                     # live provider acceptance tests; network required
```

Visual and interaction tests are headless-only. They create a temporary `HEADLESS-*` Wayland monitor, suppress keyboard focus, and restore the user’s shell state when finished. The visual suite uses the built-in deterministic mock mode so screenshots do not depend on changing match data.

For local UI work, launch the shell with mock data:

```bash
OMASPORTS_MOCK=1 omarchy-launch-shell
```

See [AGENTS.md](AGENTS.md) for the architecture map, provider polling floors, IPC details, and the full testing playbook.

## License

OmaSports is distributed under the [MIT License](LICENSE).
