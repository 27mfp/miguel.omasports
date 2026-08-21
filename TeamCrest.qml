import QtQuick
import qs.Commons

// High-performance team badge with async image caching & monogram fallback
Item {
  id: root

  property string source: ""
  property string teamId: ""
  property string teamName: ""
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

  // Computed CDN logo URL if source is empty
  readonly property string resolvedSource: {
    if (source && source.indexOf("http") === 0) return source
    if (sport === "football" && teamId !== "") {
      return "https://images.fotmob.com/image_resources/logo/teamlogo/" + teamId + ".png"
    }
    return ""
  }

  readonly property string monogramText: {
    var name = String(teamName || "").trim()
    if (!name) return "?"
    var parts = name.split(/\s+/)
    if (parts.length >= 2) {
      return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase()
    }
    return name.slice(0, 2).toUpperCase()
  }

  readonly property bool usable: resolvedSource !== "" && logoImg.status === Image.Ready

  // Circular Monogram Fallback
  Rectangle {
    id: fallbackMonogram
    anchors.fill: parent
    radius: width / 2
    visible: !root.usable
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
    border.width: 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)

    Text {
      anchors.centerIn: parent
      text: root.monogramText
      color: root.foreground
      font.family: Style.font.family
      font.pixelSize: Math.max(8, Math.round(root.crestSize * 0.42))
      font.bold: true
    }
  }

  // Downscaled Asynchronous Image
  Image {
    id: logoImg
    anchors.fill: parent
    source: root.resolvedSource
    sourceSize.width: Math.round(root.crestSize * 2)
    sourceSize.height: Math.round(root.crestSize * 2)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: true
    visible: root.usable
    opacity: root.usable ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  }
}
