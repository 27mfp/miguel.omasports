<div align="center">

# ⚽ Matchday

**The live football tracker and score center for [Omarchy](https://github.com/basecamp/omarchy).**

Track real-time scores, club fixtures, and league standings directly from your Linux desktop bar.

[![Omarchy Plugin](https://img.shields.io/badge/omarchy-plugin-blue.svg)](https://omarchy.org)
[![Version](https://img.shields.io/badge/version-1.0.0-emerald.svg)](manifest.json)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-orange.svg)]()

</div>

---

## 🌟 Highlights

- **⚡ Glancibility & Live Bar Badge**:
  - Unobtrusive football icon on your status bar.
  - Reactive pulsing notification dot whenever your favorite club or any followed match is playing live.

- **★ Multi-Competition Club Spotlight & Fixtures**:
  - Highlights your favorite team with dedicated hero spotlight cards.
  - Automatically fetches and displays matches across **all competitions** (League, UEFA Champions League, Europa League, Domestic Cups, and Friendlies).
  - Filter schedule by **Favorite Club**, **All Followed Competitions**, or specific **League / Matchdays**.

- **● Live Broadcast Scorecard**:
  - Live game minute indicators with animated pulsing badges (`● 45' HT`, `● 93'`).
  - Broadcast scorecard layout showing venue, city, referee, attendance, and halftime scores.
  - Instant transition from live to finished the moment full time is blown.

- **󰝘 League Tables & Standings**:
  - Complete league tables with European qualification, promotion, and relegation zone indicators.
  - Multi-league switcher to view standings across all your followed competitions.

- **🎯 Smart League & Team Selection**:
  - Follow up to 12 concurrent leagues with selected leagues pinned to the top of the search picker.
  - Removable tag chips for fast one-click removal.
  - Collapsible settings card to keep the panel focused on fixtures and scores.

- **⌨ Keyboard-First Navigation**:
  - Press `r` or `R` to refresh scores on demand.
  - Left / Right arrows to switch tabs (`★ Fixtures`, `● Live`, `󰝘 Standings`).
  - Arrow keys and `Tab` to navigate interactive menus and searchable dropdowns.

- **🚀 Ultra-Lightweight Native Performance**:
  - Built natively with QtQuick / QML for Quickshell.
  - No background daemons or Electron overhead.
  - Resilient network fetching with concurrent worker pool, automatic retries, and instant local disk cache.

---

## 📦 Installation

### From Git (Recommended)

```bash
omarchy plugin add https://github.com/27mfp/omarchy-matchday --enable
```

### Manual Local Install

If you cloned or downloaded this repository locally:

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

- **Followed Leagues**: Select up to 12 leagues concurrently (e.g., Premier League, La Liga, Primeira Liga, Serie A, Bundesliga, Champions League, etc.).
- **Favorite Club**: Search and pin your favorite team to receive live score alerts and all-competition fixture timelines.
- **Refresh Frequency**: Choose polling intervals from 5 to 60 minutes.
- **Background Updates**: Optional toggle to keep fetching live scores in the background while the panel is closed.

Configuration is automatically saved to `~/.config/omarchy/sports-favorites.json`.

---

## 🌍 Supported Leagues & Tournaments

Matchday supports top domestic and continental competitions worldwide:
- 🏴󠁧󠁢󠁥󠁮󠁧󠁿 **Premier League & Championship**
- 🇪🇸 **La Liga**
- 🇵🇹 **Primeira Liga & Taça de Portugal**
- 🇮🇹 **Serie A**
- 🇩🇪 **Bundesliga**
- 🇫🇷 **Ligue 1**
- 🇪🇺 **UEFA Champions League, Europa League & Conference League**
- 🇧🇷 **Brasileirão Série A**
- 🇺🇸 **Major League Soccer (MLS)**
- 🇳🇱 **Eredivisie**, 🇸🇦 **Saudi Pro League**, and more.

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
| `Click Match Card` | Open match details on FotMob in your browser |
| `Esc` | Close panel |

---

## 📄 License

Distributed under the [MIT License](LICENSE).
