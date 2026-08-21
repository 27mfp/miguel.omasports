import QtQuick
import qs.Commons

// High-performance team badge with async image caching & monogram fallback
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

  // Computed CDN logo URL if source is empty
  readonly property string resolvedSource: {
    if (source && (source.indexOf("http") === 0 || source.indexOf("https") === 0)) {
      return source
    }
    var id = String(teamId || "").toLowerCase().trim()
    var sp = String(sport || "football").toLowerCase()

    if (sp === "football" && id !== "") {
      return "https://images.fotmob.com/image_resources/logo/teamlogo/" + id + ".png"
    }

    if (sp === "f1") {
      if (id.indexOf("mercedes") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/mercedes-logo.png"
      if (id.indexOf("ferrari") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/ferrari-logo.png"
      if (id.indexOf("mclaren") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/mclaren-logo.png"
      if (id.indexOf("red_bull") !== -1 || id.indexOf("red bull") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/red-bull-racing-logo.png"
      if (id.indexOf("alpine") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/alpine-logo.png"
      if (id.indexOf("williams") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/williams-logo.png"
      if (id.indexOf("aston_martin") !== -1 || id.indexOf("aston martin") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/aston-martin-logo.png"
      if (id.indexOf("haas") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/haas-f1-team-logo.png"
      if (id.indexOf("rb") !== -1 || id.indexOf("racing") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/rb-logo.png"
      if (id.indexOf("sauber") !== -1 || id.indexOf("audi") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/kick-sauber-logo.png"
    }

    return ""
  }

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
      font.pixelSize: Math.max(7, Math.round(root.crestSize * (root.monogramText.length > 2 ? 0.34 : 0.42)))
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
