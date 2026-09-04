import QtQuick
import qs.Commons

// Shared visual helpers for the OmaSports plugin.
//
// Two helpers centralize patterns that were duplicated across the row
// components and Panel.qml:
//   - mutedColor(c, a) — Qt.rgba with explicit alpha (Qt.darker() inverts
//     text hierarchy on light themes)
//   - subtleRadius(cap) — clamp a per-component cap against the theme's
//     own Style.cornerRadius so a row never gets more rounded than the
//     host shell.
//
// Imported as a plain QtObject (no `pragma Singleton`) so the plugin
// keeps its flat-file layout that Quickshell copies into the user's
// plugins directory. Each consumer instantiates `Theme { id: theme }`
// as a child of its single root Item (a sibling Theme/Item pair is a
// QML syntax error) and references `theme.mutedColor(...)`.
QtObject {
  function mutedColor(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  function subtleRadius(cap) {
    return Math.min(cap, Style.cornerRadius)
  }

  // Font builders so callers never have to spell out the family+pixelSize
  // pair (which is easy to drift between MatchRow and StandingsRow). The
  // bold flag is opt-in so a "subtitle" stays distinguishable from a "body".
  function captionFont() {
    return { family: Style.font.family, pixelSize: Style.font.caption }
  }

  function subtitleFont() {
    return { family: Style.font.family, pixelSize: Style.font.subtitle, bold: true }
  }

  function bodyFont() {
    return { family: Style.font.family, pixelSize: Style.font.body }
  }

  // Pick black or white based on perceived luminance (sRGB weights). Used to
  // pick a legible foreground for any background color (accent fills,
  // urgent badges, zone chips) without re-implementing the formula in every
  // component.
  function onAccent(c) {
    var l = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    return l > 0.6 ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1)
  }

  // Convenience alias: urgent pills (live badges, error chips) need the
  // same contrast picker but read better at the call site as onUrgent.
  function onUrgent(c) {
    return onAccent(c)
  }
}
