<div align="center">

# ⚽ Matchday · Multi-Sport Hub

**The all-in-one live sports tracker and score center for [Omarchy](https://github.com/basecamp/omarchy).**

Track real-time scores, team schedules, and standings across **Football**, **NBA**, **Formula 1**, **NFL**, **MLB**, and **NHL** directly from your Linux desktop bar.

[![Omarchy Plugin](https://img.shields.io/badge/omarchy-plugin-blue.svg)](https://omarchy.org)
[![Version](https://img.shields.io/badge/version-1.2.0-emerald.svg)](manifest.json)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-orange.svg)]()

</div>

---

## 🌟 Highlights

- **⚡ Live Bar Ticker & Dynamic Pill**:
  - Live score ticker directly on your status bar whenever your favorite team is playing (e.g. `⚽ BEN 2-1 SPO 74'` or `🏀 LAL 104-98 GSW Q4`).
  - Dynamic status bar icon matching active sport (`⚽`, `🏀`, `🏎`, `🏈`, `⚾`, `🏒`) with a pulsing notification badge during live events.

- **🛡️ Anti-Spoiler Mode**:
  - Keep final scores concealed (`••••`) until you are ready to see them.
  - One-click / hover reveal for individual matches, or toggle globally via the header button `󰈈` / `󰈉` or the `s` key.

- **🛡️ Team Crests & Monogram Fallbacks**:
  - Asynchronous club badges and logos for football teams, NBA franchises, MLB, NFL, and NHL teams.
  - Beautiful circular monogram fallbacks (`SL`, `FC`, `LAL`, `BOS`) ensure a pristine, polished UI with zero visual holes.

- **★ Team & Driver Spotlight**:
  - Dedicated hero card highlighting your favorite club, franchise, or driver.
  - Multi-competition schedule: For football, tracks UEFA Champions League, domestic league, and cups; for F1, tracks the upcoming Grand Prix weekend.

- **● Live Broadcast Scorecard**:
  - Live game minute indicators with animated pulsing badges (`● 45' HT`, `● Q3 4:21`, `● Top 5th`, `● 3rd 12:10`, `● RACE DAY`).
  - Broadcast scorecard layout showing stadium venue, city, referee, attendance, and period scores.

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
  - Full CLI control via `omarchy-shell miguel.matchday`:
    - `omarchy-shell miguel.matchday toggle`
    - `omarchy-shell miguel.matchday sport f1`
    - `omarchy-shell miguel.matchday route live`
    - `omarchy-shell miguel.matchday toggleSpoiler`

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
cp manifest.json BarWidget.qml Panel.qml TeamCrest.qml SportsModel.js "$HOME/.config/omarchy/plugins/miguel.matchday/"

# 3. Rescan and enable
omarchy-shell shell rescanPlugins
omarchy plugin enable miguel.matchday --section center
```

---

## ⚙ Configuration & Customization

- **Sport Selector**: Switch active sport in one click (`⚽`, `🏀`, `🏎`, `🏈`, `⚾`, `🏒`).
- **Show Live Ticker on Bar**: Display live scores on the bar chip (`settings.showBarTicker`).
- **Anti-Spoiler Mode**: Conceal finished match scores until clicked (`settings.antiSpoiler`).
- **Followed Leagues**: Select up to 12 football leagues simultaneously.
- **Refresh Frequency**: Choose polling intervals from 5 to 60 minutes.

Configuration is automatically saved to `~/.config/omarchy/sports-favorites.json`.

---

## 🌍 Supported Sports & Competitions

| Sport | Icon | Leagues & Tournaments | Data Provider |
|---|:---:|---|---|
| **Football / Soccer** | ⚽ | Premier League, La Liga, Primeira Liga, Serie A, Bundesliga, Champions League, Europa League, MLS, Brasileirão, 100+ global leagues & cups | FotMob |
| **Basketball** | 🏀 | National Basketball Association (NBA) — All 30 franchises, Eastern & Western Conferences | ESPN |
| **Formula 1** | 🏎 | FIA F1 World Championship — 2026 Grand Prix Calendar, Driver & Constructor Championships | Jolpica / Ergast |
| **American Football** | 🏈 | National Football League (NFL) — All 32 teams, AFC & NFC | ESPN |
| **Baseball** | ⚾ | Major League Baseball (MLB) — All 30 teams, AL & NL | ESPN |
| **Ice Hockey** | 🏒 | National Hockey League (NHL) — All 32 teams, Eastern & Western Conferences | ESPN |

---

## 📄 License

Distributed under the [MIT License](LICENSE).
