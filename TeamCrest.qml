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

  implicitWidth: root.crestSize
  implicitHeight: root.crestSize
  width: root.crestSize
  height: root.crestSize
  opacity: dimmed ? 0.5 : 1.0

  Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

  readonly property string userHome: {
    var h = ""
    try {
      if (typeof Quickshell !== "undefined" && Quickshell && typeof Quickshell.env === "function") {
        h = Quickshell.env("HOME") || ""
      }
    } catch (e) {}
    return h || Model.safeHome()
  }

  // Cache keys are resolved by Model.crestCacheKey so the panel's background
  // downloader and this component always agree on the same file name.
  readonly property string cacheKey: Model.crestCacheKey(sport, teamId, abbr)
  readonly property string localCachePath: cacheKey !== ""
    ? "file://" + userHome + "/.cache/omarchy-omasports/logos/" + cacheKey + ".png"
    : ""

  readonly property string monogramText: Model.monogramText(root.abbr, root.teamName)

  // Circular Monogram Fallback (visible until local or remote image is ready)
  Rectangle {
    id: fallbackMonogram
    anchors.fill: parent
    radius: width / 2
    visible: localImg.status !== Image.Ready && remoteImg.status !== Image.Ready
    color: Util.alpha(root.accent, 0.16)
    border.width: 1
    border.color: Util.alpha(root.accent, 0.45)

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
    visible: localImg.status === Image.Ready
    opacity: localImg.status === Image.Ready ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }

  // Remote fallback for first runs before the disk cache is populated
  Image {
    id: remoteImg
    anchors.fill: parent
    // Keep a warm local cache from triggering a second CDN request. The
    // remote fallback starts only after the local file is absent or fails.
    source: (root.localCachePath === "" || localImg.status === Image.Error)
      && Model.isTrustedCrestUrl(root.source, root.sport) ? root.source : ""
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
