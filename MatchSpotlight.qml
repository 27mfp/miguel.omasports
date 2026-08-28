import QtQuick
import qs.Commons
import "SportsModel.js" as Model

// Hero card highlighting the featured match of a followed team, or the next
// Grand Prix weekend when the active sport is F1. Injected by Panel.qml.
Item {
  id: root

  property var featuredMatch: null
  property var fallbackMatch: null
  property bool isF1: false
  property string activeSport: "football"
  property color fgColor
  property color urgentColor
  property var selectedTeamIds: []
  property string selectedTeamName: ""
  property bool antiSpoiler: false
  property var revealedMatchIds: ({})
  property var favoriteDriverStanding: null
  property var kickoffTime: null // function(match)
  property var matchSubline: null // function(match)
  property var openMatch: null // function(match)
  property var revealMatch: null // function(matchId)
  property bool rowFocused: false

  width: parent.width
  implicitHeight: spotlightSurface.implicitHeight

  function mutedColor(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  readonly property var match: featuredMatch || fallbackMatch
  readonly property bool isLive: match && match.status === "live"
  readonly property bool isUpcoming: match && match.status === "upcoming"
  readonly property bool isFinished: match && match.status === "finished"
  readonly property string favoriteMatchTeamId: match
    ? Model.teamIdForMatch(match, root.selectedTeamIds)
    : ""
  readonly property string favoriteMatchTeamName: match && root.favoriteMatchTeamId !== ""
    ? (String(match.home && match.home.id) === String(root.favoriteMatchTeamId)
       ? String(match.home.name || match.home.shortName || root.selectedTeamName)
       : (String(match.away && match.away.id) === String(root.favoriteMatchTeamId)
          ? String(match.away.name || match.away.shortName || root.selectedTeamName)
          : root.selectedTeamName))
    : root.selectedTeamName
  readonly property string outcome: match ? Model.teamOutcome(match, root.favoriteMatchTeamId) : ""
  readonly property bool scoreHidden: root.antiSpoiler && isFinished && !(root.revealedMatchIds[match ? match.id : ""] === true)

  Rectangle {
    id: spotlightSurface
    width: parent.width
    implicitHeight: spotlightCol.implicitHeight + Style.space(24)
    radius: Style.cornerRadius
    color: spotlightMouse.containsMouse
      ? Style.hoverFillFor(root.fgColor, Color.accent)
      : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.035)
    border.width: root.rowFocused ? 2 : 1
    border.color: spotlightMouse.containsMouse
      ? Color.accent
      : (root.rowFocused
         ? root.urgentColor
         : (root.isLive ? root.urgentColor : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.12)))
    // When there's no match to announce, the surface is an empty card, not a
    // button — mirror that in accessibility so screen readers don't claim an
    // actionable item that the mouse handler already early-returns on.
    Accessible.role: root.match ? Accessible.Button : Accessible.StaticText
    Accessible.name: root.match
      ? (root.isF1
          ? (root.match.raceName || (root.match.home && root.match.home.name) || "Grand Prix")
             + ", " + (root.isLive ? "live" : (root.match.status || ""))
          : ((root.match.home && (root.match.home.name || root.match.home.shortName)) || "")
             + " versus "
             + ((root.match.away && (root.match.away.name || root.match.away.shortName)) || "")
             + (root.scoreHidden
                  ? ", result hidden"
                  : (root.match.scoreText ? ", " + root.match.scoreText : "")))
      : ""

    Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Column {
      id: spotlightCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(14)
      spacing: Style.space(12)

      // Top Row
      Item {
        id: spotlightTopRow
        width: parent.width
        implicitHeight: Math.max(spotlightTags.implicitHeight, spotlightStatusPill.implicitHeight)

        Row {
          id: spotlightTags
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Rectangle {
            implicitWidth: spotlightTagLabel.implicitWidth + Style.space(8)
            implicitHeight: spotlightTagLabel.implicitHeight + Style.space(4)
            radius: Math.min(3, Style.cornerRadius)
            color: Util.alpha(Color.accent, 0.18)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: spotlightTagLabel
              anchors.centerIn: parent
              text: root.isF1 ? "GRAND PRIX" : "SPOTLIGHT"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (root.match ? root.match.leagueName : "") + (root.match && root.match.round ? " · " + root.match.round : "")
            color: root.mutedColor(root.fgColor, 0.65)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Rectangle {
          id: spotlightStatusPill
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: statusPillRow.implicitWidth + Style.space(10)
          implicitHeight: statusPillRow.implicitHeight + Style.space(4)
          radius: Math.min(4, Style.cornerRadius)
          color: root.isLive
            ? root.urgentColor
            : (root.outcome === "win" && !root.scoreHidden
               ? Color.accent
               : (root.outcome === "loss" && !root.scoreHidden ? root.urgentColor : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.10)))

          Row {
            id: statusPillRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Rectangle {
              visible: root.isLive
              width: Style.space(5)
              height: width
              radius: width / 2
              color: "#ffffff"
              anchors.verticalCenter: parent.verticalCenter

              SequentialAnimation on opacity {
                running: root.isLive
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
              }
            }

            Text {
              text: root.isLive
                ? ("LIVE " + (root.match ? root.match.liveTime : ""))
                : (root.match && root.match.status === "finished"
                   ? (root.scoreHidden ? "FT · REVEAL 󰈈" : ("FT" + (root.outcome ? " · " + root.outcome.toUpperCase() : "")))
                   : (root.match ? Qt.formatDateTime(new Date(Date.parse(root.match.time || "")), "ddd d MMM · HH:mm") : ""))
              color: (root.isLive || (!root.scoreHidden && (root.outcome === "win" || root.outcome === "loss"))) ? "#ffffff" : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }
      }

      // F1 Specific Spotlight Layout
      Item {
        width: parent.width
        implicitHeight: f1HeroCol.implicitHeight
        visible: root.isF1

        Column {
          id: f1HeroCol
          width: parent.width
          spacing: Style.space(4)

          Row {
            width: parent.width
            spacing: Style.space(10)

            Text {
              text: (root.match && root.match.countryFlag) ? root.match.countryFlag : "🏎"
              font.pixelSize: Style.font.display
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              width: parent.width - Style.space(46)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: root.match ? (root.match.raceName || root.match.home.name) : "Grand Prix"
                color: root.fgColor
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.match ? ((root.match.circuitName || "") + (root.match.locality ? " · " + root.match.locality : "") + (root.match.country ? ", " + root.match.country : "")) : ""
                color: root.mutedColor(root.fgColor, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }

          // Driver standing badge if driver followed
          Rectangle {
            visible: root.favoriteDriverStanding !== null
            implicitWidth: driverPillRow.implicitWidth + Style.space(14)
            implicitHeight: driverPillRow.implicitHeight + Style.space(6)
            radius: Math.min(4, Style.cornerRadius)
            color: Util.alpha(Color.accent, 0.12)
            border.width: 1
            border.color: Color.accent

            Row {
              id: driverPillRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              TeamCrest {
                sport: "f1"
                teamId: root.favoriteDriverStanding ? root.favoriteDriverStanding.teamId : ""
                teamName: root.favoriteDriverStanding ? root.favoriteDriverStanding.teamName : ""
                crestSize: Style.space(16)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "★ " + root.favoriteMatchTeamName + " · " + (root.favoriteDriverStanding ? "P" + root.favoriteDriverStanding.pos + " (" + root.favoriteDriverStanding.pts + ") · " + root.favoriteDriverStanding.teamName : "")
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }

      // Standard Team vs Team Core Layout (Football, NBA, NFL, MLB, NHL)
      Item {
        width: parent.width
        implicitHeight: Math.max(homeBounding.implicitHeight, awayBounding.implicitHeight, centerScoreBadge.implicitHeight)
        visible: !root.isF1

        // Left Side (Home)
        Item {
          id: homeBounding
          anchors.left: parent.left
          anchors.right: centerScoreBadge.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          implicitHeight: Math.max(homeCrest.height, homeTextCol.implicitHeight)

          TeamCrest {
            id: homeCrest
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            sport: root.match ? root.match.sport : "football"
            teamId: root.match ? root.match.home.id : ""
            teamName: root.match ? root.match.home.name : ""
            abbr: root.match && root.match.home.abbr ? root.match.home.abbr : ""
            source: root.match && root.match.home.logo ? root.match.home.logo : ""
            crestSize: Style.space(32)
          }

          Column {
            id: homeTextCol
            anchors.left: parent.left
            anchors.right: homeCrest.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: root.match ? root.match.home.name || root.match.home.shortName : ""
              color: String(root.match && root.match.home.id) === String(root.favoriteMatchTeamId) ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.match && root.match.home.record ? root.match.home.record : (String(root.match && root.match.home.id) === String(root.favoriteMatchTeamId) ? "HOME · FAVORITE" : "HOME")
              color: root.mutedColor(root.fgColor, 0.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }
          }
        }

        // Center Score Box
        Item {
          id: centerScoreBadge
          anchors.centerIn: parent
          width: Style.space(80)
          height: Style.space(32)

          Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: Math.min(5, Style.cornerRadius)
            color: root.isLive
              ? Util.alpha(root.urgentColor, 0.15)
              : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.06)
            border.width: 1
            border.color: root.isLive
              ? root.urgentColor
              : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.12)

            Text {
              anchors.centerIn: parent
              text: root.scoreHidden
                ? "••••"
                : (root.match && root.match.status !== "upcoming"
                   ? (root.match.scoreText || "–")
                   : (root.kickoffTime(root.match) || "VS"))
              color: root.isLive ? root.urgentColor : (root.isUpcoming ? Color.accent : root.fgColor)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }
        }

        // Right Side (Away)
        Item {
          id: awayBounding
          anchors.left: centerScoreBadge.right
          anchors.leftMargin: Style.space(10)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          implicitHeight: Math.max(awayCrest.height, awayTextCol.implicitHeight)

          TeamCrest {
            id: awayCrest
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            sport: root.match ? root.match.sport : "football"
            teamId: root.match ? root.match.away.id : ""
            teamName: root.match ? root.match.away.name : ""
            abbr: root.match && root.match.away.abbr ? root.match.away.abbr : ""
            source: root.match && root.match.away.logo ? root.match.away.logo : ""
            crestSize: Style.space(32)
          }

          Column {
            id: awayTextCol
            anchors.left: awayCrest.right
            anchors.leftMargin: Style.space(8)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: root.match ? root.match.away.name || root.match.away.shortName : ""
              color: String(root.match && root.match.away.id) === String(root.favoriteMatchTeamId) ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignLeft
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.match && root.match.away.record ? root.match.away.record : (String(root.match && root.match.away.id) === String(root.favoriteMatchTeamId) ? "AWAY · FAVORITE" : "AWAY")
              color: root.mutedColor(root.fgColor, 0.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignLeft
              elide: Text.ElideRight
            }
          }
        }
      }

      // Bottom Details Line
      Item {
        width: parent.width
        implicitHeight: Math.max(metaTextSub.implicitHeight, fotmobTextLink.implicitHeight)

        Text {
          id: metaTextSub
          anchors.left: parent.left
          anchors.right: fotmobTextLink.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: root.matchSubline(root.match) || (root.match && root.match.leagueName ? root.match.leagueName + " Event" : "Matchday Details")
          color: root.mutedColor(root.fgColor, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Text {
          id: fotmobTextLink
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: (root.activeSport === "football" ? "FotMob" : "Official") + " 󰌹"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    MouseArea {
      id: spotlightMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (!root.match) return
        if (root.scoreHidden) {
          if (root.revealMatch) root.revealMatch(root.match.id)
        } else if (root.openMatch) {
          root.openMatch(root.match)
        }
      }
    }
  }
}
