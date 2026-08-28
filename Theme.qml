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
// at the top of its root scope and references `theme.mutedColor(...)`.
QtObject {
  function mutedColor(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  function subtleRadius(cap) {
    return Math.min(cap, Style.cornerRadius)
  }
}
