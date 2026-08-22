import QtQuick
import Quickshell
import qs.Commons
import "SportsModel.js" as Model

// High-performance team badge: instant local disk cache, remote fallback while
// the cache is cold, and a circular monogram when neither is available.
Item {
  id: root

  property string source: ""
  property string teamId: ""
  property string teamName: ""
  property string abbr: ""
  property string sport: "football"
  property color accent: Color.accent
  property color foreground: Color.foreground
  property real crestSize: Style.space(22)
  property bool dimmed: false

  implicitWidth: crestSize
  implicitHeight: crestSize
  width: crestSize
  height: crestSize
  opacity: dimmed ? 0.5 : 1.0

  Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

  // Cache keys are resolved by Model.crestCacheKey so the panel's background
  // downloader and this component always agree on the same file name.
  readonly property string cacheKey: Model.crestCacheKey(sport, teamId, abbr)
  readonly property string localCachePath: cacheKey !== ""
    ? "file://" + Quickshell.env("HOME") + "/.cache/omarchy-omasports/logos/" + cacheKey + ".png"
    : ""

  readonly property string monogramText: {
    if (abbr && String(abbr).trim()) {
      return String(abbr).slice(0, 3).toUpperCase()
    }
    var name = String(teamName || "").trim()
    if (!name) return "?"
    var parts = name.split(/\s+/)
    if (parts.length >= 2) {
      return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase()
    }
    return name.slice(0, 2).toUpperCase()
  }

  // Circular Monogram Fallback (visible until local or remote image is ready)
  Rectangle {
    id: fallbackMonogram
    anchors.fill: parent
    radius: width / 2
    visible: localImg.status !== Image.Ready && remoteImg.status !== Image.Ready
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
    border.width: 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)

    Text {
      anchors.centerIn: parent
      text: root.monogramText
      color: root.foreground
      font.family: Style.font.family
      font.pixelSize: Math.max(9, Math.round(root.crestSize * (root.monogramText.length > 2 ? 0.34 : 0.42)))
      font.bold: true
    }
  }

  // Instant local disk cached image (0ms latency, zero network flickering)
  Image {
    id: localImg
    anchors.fill: parent
    source: root.localCachePath
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: true
    // Decode at display resolution — provider PNGs are up to 500px wide and
    // rendering them at ~20px otherwise wastes ~20x memory per crest
    sourceSize: Qt.size(root.crestSize * 2, root.crestSize * 2)
    visible: status === Image.Ready
    opacity: status === Image.Ready ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }

  // Remote fallback for first runs before the disk cache is populated
  Image {
    id: remoteImg
    anchors.fill: parent
    source: String(root.source).indexOf("http") === 0 ? root.source : ""
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: true
    sourceSize: Qt.size(root.crestSize * 2, root.crestSize * 2)
    visible: localImg.status !== Image.Ready && status === Image.Ready
    opacity: visible ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }
}
