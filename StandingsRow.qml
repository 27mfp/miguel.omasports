import QtQuick
import qs.Commons
import "SportsModel.js" as Model

// One league table row; the layout adapts per sport (football, US sports,
// F1 drivers/constructors). Theme/state inputs are injected by Panel.qml.
Item {
  id: root

  required property var modelData
  required property int index

  property string activeSport: "football"
  property string standingsLeagueId: ""
  property string selectedTeamId: ""
  property var selectedTeamIds: []
  property string selectedTeamName: ""
  property color fgColor
  property color urgentColor

  readonly property color rowFg: root.fgColor
  readonly property bool isFavorite: Model.isStandingsRowFavorite(root.modelData, root.selectedTeamIds.length > 0 ? root.selectedTeamIds : [root.selectedTeamId], root.selectedTeamName)

  width: parent.width
  implicitHeight: Style.space(26)

  function mutedColor(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }
  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    radius: Math.min(4, Style.cornerRadius)
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
         ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
         : (root.index % 2 === 1 ? Qt.rgba(root.rowFg.r, root.rowFg.g, root.rowFg.b, 0.02) : "transparent"))

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
        color: root.modelData.zone === "europe"
          ? Util.alpha(Color.accent, 0.18)
          : (root.modelData.zone === "relegation"
             ? Util.alpha(root.urgentColor, 0.18)
             : (root.modelData.zone === "playin" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent"))

        Text {
          anchors.centerIn: parent
          text: root.modelData.pos
          color: root.modelData.zone === "europe"
            ? Color.accent
            : (root.modelData.zone === "relegation" ? root.urgentColor : root.mutedColor(root.rowFg, 0.55))
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

    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.played; color: root.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.wins; color: root.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.draws; color: root.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.losses; color: root.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text {
      width: Style.space(32)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.gd || "-")
      color: String(root.modelData.gd || "").indexOf("+") === 0 ? Color.accent : (String(root.modelData.gd || "").indexOf("-") === 0 && String(root.modelData.gd) !== "-" ? root.urgentColor : root.mutedColor(root.rowFg, 0.55))
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

  // NBA / NHL / MLB / NFL Standings Row
  Row {
    visible: root.activeSport === "nba" || root.activeSport === "nhl" || root.activeSport === "mlb" || root.activeSport === "nfl"
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
        color: root.modelData.zone === "europe"
          ? Util.alpha(Color.accent, 0.18)
          : (root.modelData.zone === "relegation"
             ? Util.alpha(root.urgentColor, 0.18)
             : (root.modelData.zone === "playin" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent"))

        Text {
          anchors.centerIn: parent
          text: root.modelData.pos
          color: root.modelData.zone === "europe"
            ? Color.accent
            : (root.modelData.zone === "relegation" ? root.urgentColor : root.mutedColor(root.rowFg, 0.55))
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

    Text { width: Style.space(28); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.wins; color: root.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text { width: Style.space(28); anchors.verticalCenter: parent.verticalCenter; text: root.modelData.losses; color: root.mutedColor(root.rowFg, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
    Text {
      width: Style.space(36)
      anchors.verticalCenter: parent.verticalCenter
      text: root.modelData.played > 0 ? (root.modelData.wins / root.modelData.played).toFixed(3).replace(/^0/, "") : ".000"
      color: root.mutedColor(root.rowFg, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }
    Text {
      width: Style.space(34)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.gd || "-")
      color: String(root.modelData.gd || "").indexOf("+") === 0 ? Color.accent : (String(root.modelData.gd || "").indexOf("-") === 0 && String(root.modelData.gd) !== "-" ? root.urgentColor : root.mutedColor(root.rowFg, 0.55))
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
        color: root.modelData.zone === "europe"
          ? Util.alpha(Color.accent, 0.18)
          : (root.modelData.zone === "playin" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent")

        Text {
          anchors.centerIn: parent
          text: root.modelData.pos
          color: root.modelData.zone === "europe" ? Color.accent : root.mutedColor(root.rowFg, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Row {
      width: Style.space(160)
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

    Text {
      width: parent.width - Style.space(290)
      anchors.verticalCenter: parent.verticalCenter
      text: root.modelData.gd || root.modelData.teamName || ""
      color: root.mutedColor(root.rowFg, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Text {
      width: Style.space(36)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.wins)
      color: root.mutedColor(root.rowFg, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }

    Text {
      width: Style.space(52)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.pts || "0")
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
        color: root.modelData.zone === "europe"
          ? Util.alpha(Color.accent, 0.18)
          : (root.modelData.zone === "playin" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent")

        Text {
          anchors.centerIn: parent
          text: root.modelData.pos
          color: root.modelData.zone === "europe" ? Color.accent : root.mutedColor(root.rowFg, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Row {
      width: Style.space(170)
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

    Text {
      width: parent.width - Style.space(300)
      anchors.verticalCenter: parent.verticalCenter
      text: root.modelData.gd || ""
      color: root.mutedColor(root.rowFg, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Text {
      width: Style.space(36)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.wins)
      color: root.mutedColor(root.rowFg, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }

    Text {
      width: Style.space(52)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.modelData.pts || "0")
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
