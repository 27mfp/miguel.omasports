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
    if (p === 1) return "🥇"
    if (p === 2) return "🥈"
    if (p === 3) return "🥉"
    return String(pos || "")
  }

  function zoneFillColor(zone) {
    if (zone === "europe") return Util.alpha("#10b981", 0.18)
    if (zone === "playin") return Util.alpha("#f59e0b", 0.18)
    if (zone === "relegation") return Util.alpha("#ef4444", 0.18)
    return "transparent"
  }

  function zoneTextColor(zone) {
    if (zone === "europe") return "#10b981"
    if (zone === "playin") return "#f59e0b"
    if (zone === "relegation") return "#ef4444"
    return theme.mutedColor(root.rowFg, 0.55)
  }

  function gdTextColor(gd) {
    var s = String(gd || "").trim()
    if (!s || s === "-") return theme.mutedColor(root.rowFg, 0.55)
    var n = Number(s)
    if (!isNaN(n)) {
      if (n > 0) return "#22c55e"
      if (n < 0) return "#ef4444"
      return theme.mutedColor(root.rowFg, 0.55)
    }
    if (s.indexOf("+") === 0) return "#22c55e"
    if (s.indexOf("-") === 0) return "#ef4444"
    return theme.mutedColor(root.rowFg, 0.55)
  }

  width: parent.width
  implicitHeight: Style.space(26)

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

    Item {
      width: Style.space(28)
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
      width: parent.width - Style.space(216)
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

    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.played; color: theme.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.wins; color: theme.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.draws; color: theme.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.losses; color: theme.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text {
      width: Style.space(32)
      anchors.verticalCenter: parent.verticalCenter
      text: (root.modelData.gd !== undefined && root.modelData.gd !== null && root.modelData.gd !== "") ? String(root.modelData.gd) : "-"
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

    Item {
      width: Style.space(28)
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
      width: parent.width - Style.space(190)
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

    Text { width: Style.space(28); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.wins; color: theme.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(28); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.losses; color: theme.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text {
      width: Style.space(36)
      anchors.verticalCenter: parent.verticalCenter
      text: root.activeSport === "nhl"
        ? String(root.modelData.draws !== undefined ? root.modelData.draws : "0")
        : (root.modelData.played > 0 ? (root.modelData.wins / root.modelData.played).toFixed(3).replace(/^0/, "") : ".000")
      color: theme.mutedColor(root.rowFg, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }
    Text {
      width: Style.space(34)
      anchors.verticalCenter: parent.verticalCenter
      text: (root.modelData.gd !== undefined && root.modelData.gd !== null && root.modelData.gd !== "") ? String(root.modelData.gd) : "-"
      color: root.gdTextColor(root.modelData.gd)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }
    Text {
      width: Style.space(36)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.pts || "0")
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

    Item {
      width: Style.space(28)
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
      width: parent.width - Style.space(182)
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

    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.wins; color: theme.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.losses; color: theme.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.draws || 0; color: theme.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text {
      width: Style.space(38)
      anchors.verticalCenter: parent.verticalCenter
      text: root.modelData.played > 0 ? (root.modelData.wins / root.modelData.played).toFixed(3).replace(/^0/, "") : ".000"
      color: theme.mutedColor(root.rowFg, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }
    Text {
      width: Style.space(38)
      anchors.verticalCenter: parent.verticalCenter
      text: (root.modelData.gd !== undefined && root.modelData.gd !== null && root.modelData.gd !== "") ? String(root.modelData.gd) : "-"
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

    Item {
      width: Style.space(28)
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
      width: Style.space(190)
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
      width: parent.width - Style.space(330)
      anchors.verticalCenter: parent.verticalCenter
      text: root.modelData.gd || root.modelData.teamName || ""
      color: theme.mutedColor(root.rowFg, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Text {
      width: Style.space(42)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.wins)
      color: theme.mutedColor(root.rowFg, 0.65)
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

  // F1 Constructors Standings Row
  Row {
    visible: root.activeSport === "f1" && (root.standingsLeagueId === "Constructors" || root.standingsLeagueId.indexOf("Construct") !== -1)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(6)

    Item {
      width: Style.space(28)
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
      width: parent.width - Style.space(320)
      anchors.verticalCenter: parent.verticalCenter
      text: root.modelData.gd || ""
      color: theme.mutedColor(root.rowFg, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Text {
      width: Style.space(42)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.wins)
      color: theme.mutedColor(root.rowFg, 0.65)
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
