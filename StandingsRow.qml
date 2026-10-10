import QtQuick
import qs.Commons
import "SportsModel.js" as Model

// One league table row; the layout adapts per sport (football, US sports,
// F1 drivers/constructors). Theme/state inputs are injected by Panel.qml.
Item {
  id: root
  Theme { id: theme }

  required property var modelData
  required property int index

  property string activeSport: "football"
  property string standingsLeagueId: ""
  property var selectedTeamIds: []
  property string selectedTeamName: ""
  property color fgColor
  property color urgentColor

  readonly property color rowFg: root.fgColor
  readonly property bool isFavorite: Model.isStandingsRowFavorite(root.modelData, root.selectedTeamIds, root.selectedTeamName)

  function formatPosition(pos) {
    var p = Number(pos)
    return String(pos || "")
  }

  function zoneFillColor(zone) {
    if (zone === "europe") return Util.alpha(theme.zoneColor, 0.18)
    if (zone === "playin") return Util.alpha(theme.warningColor, 0.18)
    if (zone === "relegation") return Util.alpha(theme.negativeColor, 0.18)
    return "transparent"
  }

  function zoneTextColor(zone) {
    if (zone === "europe") return theme.zoneColor
    if (zone === "playin") return theme.warningColor
    if (zone === "relegation") return theme.negativeColor
    return theme.mutedColor(root.rowFg, 0.7)
  }

  // Positive differences carry an explicit sign in every sport's table.
  function formatDiff(gd) {
    if (gd === undefined || gd === null || gd === "") return "-"
    var s = String(gd).trim()
    var n = Number(s)
    return !isNaN(n) && n > 0 && s.charAt(0) !== "+" ? "+" + s : s
  }

  function gdTextColor(gd) {
    var s = String(gd || "").trim()
    if (!s || s === "-") return theme.mutedColor(root.rowFg, 0.7)
    var n = Number(s)
    if (!isNaN(n)) {
      if (n > 0) return theme.positiveColor
      if (n < 0) return theme.negativeColor
      return theme.mutedColor(root.rowFg, 0.7)
    }
    if (s.indexOf("+") === 0) return theme.positiveColor
    if (s.indexOf("-") === 0) return theme.negativeColor
    return theme.mutedColor(root.rowFg, 0.7)
  }

  width: parent.width
  implicitHeight: Style.space(30)

  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    radius: theme.subtleRadius(4)
    Accessible.role: Accessible.ListItem
    Accessible.name: {
      var pos = String(root.modelData.pos || "")
      var nm = String(root.modelData.shortName || root.modelData.name || "")
      var parts = []
      if (root.activeSport === "f1") {
        parts.push("P" + pos)
        parts.push(nm)
        if (root.modelData.teamName) parts.push(root.modelData.teamName)
        parts.push(String(root.modelData.pts || "0") + " points")
        if (Number(root.modelData.wins || 0) > 0) parts.push(root.modelData.wins + " wins")
      } else if (root.activeSport !== "football") {
        parts.push("Seed " + pos)
        parts.push(nm)
        parts.push(String(root.modelData.wins || 0) + " wins")
        parts.push(String(root.modelData.losses || 0) + " losses")
        if (root.activeSport === "nhl") {
          parts.push(String(root.modelData.draws || 0) + " overtime losses")
          parts.push(String(root.modelData.pts || 0) + " points")
        } else {
          if (root.activeSport === "nfl") parts.push(String(root.modelData.draws || 0) + " ties")
          parts.push(String(root.modelData.pct || ".000") + " win percentage")
          if ((root.activeSport === "nba" || root.activeSport === "mlb") && root.modelData.gb)
            parts.push(String(root.modelData.gb) + " games behind")
        }
        if (root.modelData.gd) parts.push(root.modelData.gd + " " + (root.activeSport === "mlb" ? "run" : (root.activeSport === "nhl" ? "goal" : "point")) + " difference")
      } else {
        if (pos) parts.push(pos + ".")
        parts.push(nm)
        if (root.modelData.played) parts.push(root.modelData.played + " played")
        if (root.modelData.wins) parts.push(root.modelData.wins + " wins")
        if (root.modelData.draws) parts.push(root.modelData.draws + " draws")
        if (root.modelData.losses) parts.push(root.modelData.losses + " losses")
        if (root.modelData.gd !== undefined && root.modelData.gd !== "") parts.push(String(root.modelData.gd) + " goal difference")
        parts.push(String(root.modelData.pts || "0") + " points")
      }
      if (root.isFavorite) parts.push("favorite")
      return parts.join(", ")
    }
    color: tableMouse.containsMouse
      ? Style.hoverFillFor(root.rowFg, Color.accent)
      : (root.isFavorite
         ? Util.alpha(Color.accent, 0.12)
         : (root.index % 2 === 1 ? theme.mutedColor(root.rowFg, 0.02) : "transparent"))

    Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
  }

  // Football Standings Row
  Row {
    visible: root.activeSport === "football"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)
    spacing: Style.space(8)

    Item {
      width: Style.space(36)
      height: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.centerIn: parent
        width: Style.space(20)
        height: Style.space(18)
        radius: 3
        color: root.zoneFillColor(root.modelData.zone)

        Text {
          anchors.centerIn: parent
          text: root.formatPosition(root.modelData.pos)
          color: root.zoneTextColor(root.modelData.zone)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Row {
      width: parent.width - Style.space(260)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      TeamCrest {
        sport: "football"
        teamId: root.modelData.id
        teamName: root.modelData.name
        source: root.modelData.logo || ""
        crestSize: Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        width: parent.width - Style.space(22)
        anchors.verticalCenter: parent.verticalCenter
        text: (root.isFavorite ? "★ " : "") + (root.modelData.shortName || root.modelData.name)
        color: root.isFavorite ? Color.accent : root.rowFg
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: root.isFavorite
        elide: Text.ElideRight
      }
    }

    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.played; color: theme.mutedColor(root.rowFg, 0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.wins; color: theme.mutedColor(root.rowFg, 0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.draws; color: theme.mutedColor(root.rowFg, 0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.losses; color: theme.mutedColor(root.rowFg, 0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text {
      width: Style.space(32)
      anchors.verticalCenter: parent.verticalCenter
      text: root.formatDiff(root.modelData.gd)
      color: root.gdTextColor(root.modelData.gd)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }

    Text {
      width: Style.space(32)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.pts || "0")
      color: root.isFavorite ? Color.accent : root.rowFg
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }
  }

  // NBA / NHL / MLB Standings Row
  Row {
    visible: root.activeSport === "nba" || root.activeSport === "nhl" || root.activeSport === "mlb"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)
    spacing: Style.space(8)

    Item {
      width: Style.space(36)
      height: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.centerIn: parent
        width: Style.space(20)
        height: Style.space(18)
        radius: 3
        color: root.zoneFillColor(root.modelData.zone)

        Text {
          anchors.centerIn: parent
          text: root.formatPosition(root.modelData.pos)
          color: root.zoneTextColor(root.modelData.zone)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Row {
      width: parent.width - Style.space(274)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      TeamCrest {
        sport: root.activeSport
        teamId: root.modelData.id
        teamName: root.modelData.name
        abbr: root.modelData.abbr || ""
        source: root.modelData.logo || ""
        crestSize: Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        width: parent.width - Style.space(22)
        anchors.verticalCenter: parent.verticalCenter
        text: (root.isFavorite ? "★ " : "") + (root.modelData.shortName || root.modelData.name)
        color: root.isFavorite ? Color.accent : root.rowFg
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: root.isFavorite
        elide: Text.ElideRight
      }
    }

    Text { width: Style.space(28); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.wins; color: theme.mutedColor(root.rowFg, 0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(28); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.losses; color: theme.mutedColor(root.rowFg, 0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text {
      width: Style.space(44)
      anchors.verticalCenter: parent.verticalCenter
      text: root.activeSport === "nhl"
        ? String(root.modelData.draws !== undefined ? root.modelData.draws : "0")
        : (root.modelData.pct || ".000")
      color: theme.mutedColor(root.rowFg, 0.8)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }
    Text {
      width: Style.space(50)
      anchors.verticalCenter: parent.verticalCenter
      text: root.formatDiff(root.modelData.gd)
      color: root.gdTextColor(root.modelData.gd)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }
    Text {
      width: Style.space(40)
      anchors.verticalCenter: parent.verticalCenter
      text: root.activeSport === "nhl" ? String(root.modelData.pts || "0") : String(root.modelData.gb || "–")
      color: root.isFavorite ? Color.accent : root.rowFg
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }
  }

  // NFL Standings Row (W, L, T, PCT, DIFF)
  Row {
    visible: root.activeSport === "nfl"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)
    spacing: Style.space(8)

    Item {
      width: Style.space(36)
      height: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.centerIn: parent
        width: Style.space(20)
        height: Style.space(18)
        radius: 3
        color: root.zoneFillColor(root.modelData.zone)

        Text {
          anchors.centerIn: parent
          text: root.formatPosition(root.modelData.pos)
          color: root.zoneTextColor(root.modelData.zone)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Row {
      width: parent.width - Style.space(256)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      TeamCrest {
        sport: "nfl"
        teamId: root.modelData.id
        teamName: root.modelData.name
        abbr: root.modelData.abbr || ""
        source: root.modelData.logo || ""
        crestSize: Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        width: parent.width - Style.space(22)
        anchors.verticalCenter: parent.verticalCenter
        text: (root.isFavorite ? "★ " : "") + (root.modelData.shortName || root.modelData.name)
        color: root.isFavorite ? Color.accent : root.rowFg
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: root.isFavorite
        elide: Text.ElideRight
      }
    }

    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.wins; color: theme.mutedColor(root.rowFg, 0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.losses; color: theme.mutedColor(root.rowFg, 0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.draws || 0; color: theme.mutedColor(root.rowFg, 0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text {
      width: Style.space(44)
      anchors.verticalCenter: parent.verticalCenter
      text: root.modelData.pct || ".000"
      color: theme.mutedColor(root.rowFg, 0.8)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }
    Text {
      width: Style.space(50)
      anchors.verticalCenter: parent.verticalCenter
      text: root.formatDiff(root.modelData.gd)
      color: root.gdTextColor(root.modelData.gd)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }
  }

  // F1 Drivers Standings Row
  Row {
    visible: root.activeSport === "f1" && (root.standingsLeagueId === "Drivers" || root.standingsLeagueId === "" || root.standingsLeagueId.indexOf("Construct") === -1)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)
    spacing: Style.space(8)

    Item {
      width: Style.space(36)
      height: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.centerIn: parent
        width: Style.space(20)
        height: Style.space(18)
        radius: 3
        color: root.zoneFillColor(root.modelData.zone)

        Text {
          anchors.centerIn: parent
          text: root.formatPosition(root.modelData.pos)
          color: root.zoneTextColor(root.modelData.zone)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Item {
      width: Style.space(180)
      height: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter

      Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        TeamCrest {
          sport: "f1"
          teamId: root.modelData.teamId || ""
          teamName: root.modelData.teamName || ""
          crestSize: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - Style.space(22)
          anchors.verticalCenter: parent.verticalCenter
          text: (root.isFavorite ? "★ " : "") + (root.modelData.flag ? root.modelData.flag + " " : "") + root.modelData.name
          color: root.isFavorite ? Color.accent : root.rowFg
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: root.isFavorite
          elide: Text.ElideRight
        }
      }
    }

    Text {
      width: parent.width - Style.space(338)
      anchors.verticalCenter: parent.verticalCenter
      text: root.modelData.gd || root.modelData.teamName || ""
      color: theme.mutedColor(root.rowFg, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Text {
      width: Style.space(40)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.wins)
      color: theme.mutedColor(root.rowFg, 0.8)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }

    Text {
      width: Style.space(50)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.pts || "0").replace(/\s*PTS$/i, "")
      color: root.isFavorite ? Color.accent : root.rowFg
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }
  }

  // F1 Constructors Standings Row
  Row {
    visible: root.activeSport === "f1" && (root.standingsLeagueId === "Constructors" || root.standingsLeagueId.indexOf("Construct") !== -1)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)
    spacing: Style.space(8)

    Item {
      width: Style.space(36)
      height: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.centerIn: parent
        width: Style.space(20)
        height: Style.space(18)
        radius: 3
        color: root.zoneFillColor(root.modelData.zone)

        Text {
          anchors.centerIn: parent
          text: root.formatPosition(root.modelData.pos)
          color: root.zoneTextColor(root.modelData.zone)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Item {
      width: Style.space(180)
      height: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter

      Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        TeamCrest {
          sport: "f1"
          teamId: root.modelData.id || ""
          teamName: root.modelData.name || ""
          crestSize: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - Style.space(22)
          anchors.verticalCenter: parent.verticalCenter
          text: (root.isFavorite ? "★ " : "") + root.modelData.name
          color: root.isFavorite ? Color.accent : root.rowFg
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: root.isFavorite
          elide: Text.ElideRight
        }
      }
    }

    Text {
      width: parent.width - Style.space(355)
      anchors.verticalCenter: parent.verticalCenter
      text: root.modelData.gd || ""
      color: theme.mutedColor(root.rowFg, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Text {
      width: Style.space(42)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.wins)
      color: theme.mutedColor(root.rowFg, 0.8)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }

    Text {
      width: Style.space(65)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.pts || "0").replace(/\s*PTS$/i, "")
      color: root.isFavorite ? Color.accent : root.rowFg
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }
  }

  MouseArea {
    id: tableMouse
    anchors.fill: parent
    hoverEnabled: true
  }
}
