<div align="center">

# ⚽ Matchday · Multi-Sport Hub

**The all-in-one live sports tracker and score center for [Omarchy](https://github.com/basecamp/omarchy).**

Track real-time scores, team schedules, and standings across **Football**, **NBA**, **Formula 1**, **NFL**, **MLB**, and **NHL** directly from your Linux desktop bar.

[![Omarchy Plugin](https://img.shields.io/badge/omarchy-plugin-blue.svg)](https://omarchy.org)
[![Version](https://img.shields.io/badge/version-1.1.0-emerald.svg)](manifest.json)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-orange.svg)]()

</div>

---

## 🌟 Highlights

- **⚡ Unified All-in-One Multi-Sport Hub**:
  - Switch instantly between **⚽ Football**, **🏀 NBA**, **🏎 Formula 1**, **🏈 NFL**, **⚾ MLB**, and **🏒 NHL**.
  - Dynamic status bar icon automatically updates to match your active sport (`⚽`, `🏀`, `🏎`, `🏈`, `⚾`, `🏒`).
  - Persistent per-sport preferences — your favorite club and followed leagues are remembered independently for every sport.

- **★ Team & Driver Hero Spotlight**:
  - Highlights your favorite team or driver with dedicated match cards.
  - Multi-competition tracking: For football, tracks UEFA Champions League, domestic league, and cups; for F1, tracks the upcoming Grand Prix weekend.

- **● Live Broadcast Scorecard**:
  - Live game minute indicators with animated pulsing badges (`● 45' HT`, `● Q3 4:21`, `● Top 5th`, `● 3rd 12:10`, `● RACE DAY`).
  - Broadcast scorecard layout showing stadium venue, city, referee, attendance, and period scores.
  - Instant transition from live to finished the moment the game concludes.

- **󰝘 League Tables & Standings**:
  - Complete tables with qualification, playoff seeds, promotion, and relegation zone indicators:
    - ⚽ **Football**: Champions League, European spots, Relegation.
    - 🏀 **NBA**: Eastern & Western Conference standings with Playoff (Top 6) and Play-in (7–10) seeds.
    - 🏎 **Formula 1**: Drivers and Constructors World Championship standings.
    - 🏈 **NFL**: AFC and NFC conference & division tables.
    - ⚾ **MLB**: American League and National League standings.
    - 🏒 **NHL**: Eastern and Western conference rankings.

- **🎯 Smart Search & Autocomplete**:
  - Pre-populated catalogues for all 30 NBA teams, 32 NFL teams, 30 MLB teams, 32 NHL teams, F1 drivers, and 100+ football competitions.
  - Follow up to 12 concurrent football leagues with selected leagues pinned to the top of the search picker.

- **⌨ Keyboard-First Navigation**:
  - Press `r` or `R` to refresh scores on demand.
  - Left / Right arrows to switch tabs (`★ Fixtures`, `● Live`, `󰝘 Standings`).
  - Arrow keys and `Tab` to navigate interactive menus and searchable dropdowns.

- **🚀 Ultra-Lightweight Native Performance**:
  - Built natively with QtQuick / QML for Quickshell.
  - Zero background daemons or Electron overhead.
  - Resilient network fetching with concurrent worker pool, automatic retries, and instant local disk cache.

---

## 📦 Installation

### From Git (Recommended)

```bash
omarchy plugin add https://github.com/27mfp/omarchy-matchday --enable
```

### Manual Local Install

```bash
# 1. Validate the plugin manifest
omarchy plugin validate .

# 2. Copy files to your Omarchy plugins directory
mkdir -p "$HOME/.config/omarchy/plugins/miguel.matchday"
cp manifest.json BarWidget.qml Panel.qml SportsModel.js "$HOME/.config/omarchy/plugins/miguel.matchday/"

# 3. Rescan and enable
omarchy-shell shell rescanPlugins
omarchy plugin enable miguel.matchday --section center
```

---

## ⚙ Configuration & Customization

All settings can be configured inside the interactive popout panel or through your Omarchy settings:

- **Sport Selector**: Click any sport pill (`⚽`, `🏀`, `🏎`, `🏈`, `⚾`, `🏒`) in the header to switch active sport.
- **Followed Leagues (Football)**: Select up to 12 leagues concurrently.
- **Favorite Team / Driver**: Search and pin your favorite team/driver in each sport.
- **Refresh Frequency**: Choose polling intervals from 5 to 60 minutes.
- **Background Updates**: Optional toggle to keep fetching live scores in the background while the panel is closed.

Configuration is automatically saved to `~/.config/omarchy/sports-favorites.json`.

---

## 🌍 Supported Sports & Competitions

| Sport | Icon | Leagues & Tournaments | Data Provider |
|---|:---:|---|---|
| **Football / Soccer** | ⚽ | Premier League, La Liga, Primeira Liga, Serie A, Bundesliga, Champions League, Europa League, MLS, Brasileirão, 100+ global leagues & cups | FotMob |
| **Basketball** | 🏀 | National Basketball Association (NBA) — All 30 teams, Eastern & Western Conferences | ESPN |
| **Formula 1** | 🏎 | FIA F1 World Championship — Full Grand Prix Calendar, Driver & Constructor Standings | Jolpica / Ergast |
| **American Football** | 🏈 | National Football League (NFL) — All 32 teams, AFC & NFC | ESPN |
| **Baseball** | ⚾ | Major League Baseball (MLB) — All 30 teams, AL & NL | ESPN |
| **Ice Hockey** | 🏒 | National Hockey League (NHL) — All 32 teams, Eastern & Western Conferences | ESPN |

---

## ⌨ Keybindings & Controls

| Shortcut | Description |
|---|---|
| **Click Bar Icon** | Toggle Matchday panel |
| **Middle-Click Bar Icon** | Force immediate score refresh |
| `r` or `R` | Refresh match data |
| `←` / `→` | Switch between Fixtures, Live, and Standings tabs |
| `↑` / `↓` | Navigate interactive controls |
| `Enter` / `Space` | Activate selected dropdown or button |
| `Click Match Card` | Open match details in your browser |
| `Esc` | Close panel |

---

## 📄 License

Distributed under the [MIT License](LICENSE).
