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

  // ESPN abbreviation mapping tables for 100% complete logo coverage
  readonly property var nflAbbrs: ({
    "1": "atl", "2": "buf", "3": "chi", "4": "cin", "5": "cle", "6": "dal", "7": "den", "8": "det",
    "9": "gb", "10": "ten", "11": "ind", "12": "kc", "13": "lv", "14": "lar", "15": "mia", "16": "min",
    "17": "ne", "18": "no", "19": "nyg", "20": "nyj", "21": "phi", "22": "ari", "23": "pit", "24": "lac",
    "25": "sf", "26": "sea", "27": "tb", "28": "wsh", "29": "car", "30": "jax", "33": "bal", "34": "hou"
  })

  readonly property var nbaAbbrs: ({
    "1": "atl", "2": "bos", "3": "no", "4": "chi", "5": "cle", "6": "dal", "7": "den", "8": "det",
    "9": "gs", "10": "hou", "11": "ind", "12": "lac", "13": "lal", "14": "mia", "15": "mil", "16": "min",
    "17": "bkn", "18": "ny", "19": "orl", "20": "phi", "21": "phx", "22": "por", "23": "sac", "24": "sa",
    "25": "okc", "26": "uta", "27": "wsh", "28": "tor", "29": "mem", "30": "cha"
  })

  readonly property var mlbAbbrs: ({
    "1": "bal", "2": "bos", "3": "cws", "4": "cin", "5": "cle", "6": "col", "7": "det", "8": "kc",
    "9": "laa", "10": "mia", "11": "mil", "12": "min", "13": "oak", "14": "nyy", "15": "atl", "16": "chc",
    "17": "pit", "18": "hou", "19": "lad", "20": "wsh", "21": "nym", "22": "phi", "23": "sea", "24": "stl",
    "25": "sd", "26": "sf", "27": "tb", "28": "tex", "29": "ari", "30": "tor"
  })

  readonly property var nhlAbbrs: ({
    "1": "nj", "2": "nyi", "3": "nyr", "4": "phi", "5": "pit", "6": "bos", "7": "buf", "8": "mtl",
    "9": "ott", "10": "tor", "11": "car", "12": "fla", "13": "tb", "14": "wsh", "15": "chi", "16": "det",
    "17": "nsh", "18": "stl", "19": "cgy", "20": "col", "21": "edm", "22": "van", "23": "ana", "24": "dal",
    "25": "la", "26": "sj", "27": "cbj", "28": "min", "29": "wpg", "30": "ari", "37": "sea", "54": "vgk", "129754": "uta"
  })

  // Computed CDN logo URL if source is empty
  readonly property string resolvedSource: {
    if (source && (source.indexOf("http://") === 0 || source.indexOf("https://") === 0)) {
      return source
    }
    var id = String(teamId || "").trim()
    var sp = String(sport || "football").toLowerCase()
    var a = String(abbr || "").toLowerCase().trim()

    // ⚽ Football (FotMob)
    if (sp === "football" && id !== "") {
      return "https://images.fotmob.com/image_resources/logo/teamlogo/" + id + ".png"
    }

    // 🏎 Formula 1 (Formula 1 CDN)
    if (sp === "f1") {
      var fid = id.toLowerCase()
      if (fid.indexOf("mercedes") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/mercedes-logo.png"
      if (fid.indexOf("ferrari") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/ferrari-logo.png"
      if (fid.indexOf("mclaren") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/mclaren-logo.png"
      if (fid.indexOf("red_bull") !== -1 || fid.indexOf("red bull") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/red-bull-racing-logo.png"
      if (fid.indexOf("alpine") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/alpine-logo.png"
      if (fid.indexOf("williams") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/williams-logo.png"
      if (fid.indexOf("aston_martin") !== -1 || fid.indexOf("aston martin") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/aston-martin-logo.png"
      if (fid.indexOf("haas") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/haas-f1-team-logo.png"
      if (fid.indexOf("rb") !== -1 || fid.indexOf("racing") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/rb-logo.png"
      if (fid.indexOf("sauber") !== -1 || fid.indexOf("audi") !== -1) return "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/kick-sauber-logo.png"
    }

    // 🏈 NFL (ESPN CDN)
    if (sp === "nfl") {
      var nflCode = a || nflAbbrs[id] || ""
      if (nflCode) return "https://a.espncdn.com/i/teamlogos/nfl/500/" + nflCode + ".png"
    }

    // 🏀 NBA (ESPN CDN)
    if (sp === "nba") {
      var nbaCode = a || nbaAbbrs[id] || ""
      if (nbaCode) return "https://a.espncdn.com/i/teamlogos/nba/500/" + nbaCode + ".png"
    }

    // ⚾ MLB (ESPN CDN)
    if (sp === "mlb") {
      var mlbCode = a || mlbAbbrs[id] || ""
      if (mlbCode) return "https://a.espncdn.com/i/teamlogos/mlb/500/" + mlbCode + ".png"
    }

    // 🏒 NHL (ESPN CDN)
    if (sp === "nhl") {
      var nhlCode = a || nhlAbbrs[id] || ""
      if (nhlCode) return "https://a.espncdn.com/i/teamlogos/nhl/500/" + nhlCode + ".png"
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
