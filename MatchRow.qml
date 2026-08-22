import QtQuick
import qs.Commons
import "SportsModel.js" as Model

// One fixture/result row: a team-vs-team card, or an expandable F1 Grand Prix
// weekend entry with its sessions timetable. Theme/state inputs are injected
// by Panel.qml.
Item {
  id: root

  required property var modelData

  property string activeSport: "football"
  property color fgColor
  property color urgentColor
  property string selectedTeamId: ""
  property bool antiSpoiler: false
  property var revealedMatchIds: ({})
  property double nowMs: 0
  property var revealMatch: null // function(matchId)
  property var openMatch: null // function(match)

  readonly property bool isF1: root.activeSport === "f1"
  readonly property bool isLive: modelData.status === "live"
  readonly property bool isUpcoming: modelData.status === "upcoming"
  readonly property bool isFinished: modelData.status === "finished"
  readonly property bool favIsHome: String(modelData.home.id) === String(root.selectedTeamId)
  readonly property bool favIsAway: String(modelData.away.id) === String(root.selectedTeamId)
  readonly property string dateBadge: Model.formatMatchDate(modelData.time)
  readonly property bool isScoreRevealed: root.revealedMatchIds[String(modelData.id)] === true
  readonly property bool scoreHidden: root.antiSpoiler && isFinished && !isScoreRevealed
  property bool expanded: false

  width: parent.width
  implicitHeight: matchCard.implicitHeight

  Rectangle {
    id: matchCard
    width: parent.width
    implicitHeight: root.isF1 ? (f1ContainerCol.implicitHeight + Style.space(14)) : (matchRowLayout.implicitHeight + Style.space(14))
    radius: Math.min(6, Style.cornerRadius)
    color: matchMouse.containsMouse
      ? Style.hoverFillFor(root.fgColor, Color.accent)
      : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.02)
    border.width: 1
    border.color: matchMouse.containsMouse
      ? Color.accent
      : (root.isLive ? root.urgentColor : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.06))

    Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(3)
      width: Style.space(3)
      radius: width / 2
      visible: root.isLive
      color: root.urgentColor
    }

    // F1 Grand Prix Container Layout (with sessions dropdown)
    Column {
      id: f1ContainerCol
      visible: root.isF1
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(8)

      Row {
        id: f1RowLayout
        width: parent.width
        spacing: Style.space(10)

        Column {
          width: Style.space(84)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          Text {
            text: root.dateBadge
            color: Qt.darker(root.fgColor, 1.35)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            text: modelData.round || "GP"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Row {
          width: parent.width - Style.space(210)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Text {
            text: modelData.countryFlag || "🏁"
            font.pixelSize: Style.font.heading
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - Style.space(28)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
              width: parent.width
              text: modelData.raceName || modelData.home.name
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: (modelData.circuitName || "") + (modelData.locality ? " · " + modelData.locality : "")
              color: Qt.darker(root.fgColor, 1.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }

        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Rectangle {
            implicitWidth: f1StatusText.implicitWidth + Style.space(10)
            implicitHeight: f1StatusText.implicitHeight + Style.space(4)
            radius: Math.min(4, Style.cornerRadius)
            color: root.isLive
              ? root.urgentColor
              : (root.isFinished ? Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08) : Util.alpha(Color.accent, 0.15))

            Text {
              id: f1StatusText
              anchors.centerIn: parent
              text: root.isFinished ? "Official" : (root.isLive ? "RACE DAY" : Model.formatKickoff(modelData.time))
              color: root.isLive ? "#ffffff" : (root.isFinished ? Qt.darker(root.fgColor, 1.3) : Color.accent)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Text {
            visible: root.isF1 && Boolean(modelData && modelData.sessions && modelData.sessions.length > 0)
            text: root.expanded ? "󰅃" : "󰅀"
            color: Qt.darker(root.fgColor, 1.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // Expandable Grand Prix Weekend Sessions Box
      Column {
        id: f1SessionsDropdown
        visible: root.isF1 && root.expanded && Boolean(modelData && modelData.sessions && modelData.sessions.length > 0)
        width: parent.width
        spacing: Style.space(4)
        topPadding: Style.space(4)
        bottomPadding: Style.space(4)

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08)
        }

        Repeater {
          model: modelData.sessions

          delegate: Rectangle {
            required property var modelData
            required property int index

            width: f1SessionsDropdown.width
            implicitHeight: Style.space(22)
            radius: 3
            color: index % 2 === 1 ? Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.025) : "transparent"

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(6)

              Text {
                width: Style.space(140)
                text: (modelData.shortName === "Race" ? "🏁 " : (modelData.shortName === "Quali" ? "⏱ " : (modelData.shortName === "SQ" ? "⚡ " : "🏎 "))) + modelData.name
                color: modelData.shortName === "Race" ? Color.accent : root.fgColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: modelData.shortName === "Race" || modelData.shortName === "Quali"
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: parent.width - Style.space(240)
                text: Qt.formatDateTime(new Date(Date.parse(modelData.time)), "ddd d MMM · HH:mm")
                color: Qt.darker(root.fgColor, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: Style.space(84)
                text: {
                  var ms = Date.parse(modelData.time)
                  var now = root.nowMs
                  if (isNaN(ms)) return ""
                  if (now > ms + 2.5 * 3600 * 1000) return "Finished"
                  if (now >= ms) return "LIVE"
                  var diff = ms - now
                  var hrs = Math.floor(diff / 3600000)
                  var days = Math.floor(hrs / 24)
                  if (days > 0) return "in " + days + "d " + (hrs % 24) + "h"
                  var mins = Math.floor((diff % 3600000) / 60000)
                  return "in " + hrs + "h " + mins + "m"
                }
                color: {
                  var ms2 = Date.parse(modelData.time)
                  if (root.nowMs >= ms2 && root.nowMs <= ms2 + 2.5 * 3600 * 1000) return root.urgentColor
                  return Qt.darker(root.fgColor, 1.5)
                }
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }
    }

    // Standard Team vs Team Match Row Layout
    Row {
      id: matchRowLayout
      visible: !root.isF1
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(6)

      Column {
        width: Style.space(88)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
          text: root.dateBadge
          color: Qt.darker(root.fgColor, 1.35)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Text {
          text: Model.shortTournamentName(modelData.leagueName) || (modelData.round ? modelData.round : "")
          color: Qt.darker(root.fgColor, 1.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: parent.width
        }
      }

      Item {
        width: parent.width - Style.space(94)
        height: Math.max(homeTeamLayout.implicitHeight, awayTeamLayout.implicitHeight, centerScoreHolder.implicitHeight)
        anchors.verticalCenter: parent.verticalCenter

        // Left Side (Home)
        Item {
          id: homeTeamLayout
          anchors.left: parent.left
          anchors.right: centerScoreHolder.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          implicitHeight: Math.max(homeRowCrest.height, homeTeamText.implicitHeight)

          TeamCrest {
            id: homeRowCrest
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            sport: modelData.sport || "football"
            teamId: modelData.home.id
            teamName: modelData.home.name
            abbr: modelData.home.abbr || ""
            source: modelData.home.logo || ""
            crestSize: Style.space(18)
          }

          Text {
            id: homeTeamText
            anchors.left: parent.left
            anchors.right: homeRowCrest.left
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            text: (root.favIsHome ? "★ " : "") + (modelData.home.name || modelData.home.shortName)
            color: root.favIsHome ? Color.accent : root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: root.favIsHome || (modelData.homeScore > modelData.awayScore)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
          }
        }

        // Center Score
        Item {
          id: centerScoreHolder
          anchors.centerIn: parent
          width: Style.space(56)
          height: parent.height

          Row {
            anchors.centerIn: parent
            spacing: Style.space(3)

            Rectangle {
              visible: root.isLive
              width: Style.space(5)
              height: width
              radius: width / 2
              color: root.urgentColor
              anchors.verticalCenter: parent.verticalCenter

              SequentialAnimation on opacity {
                running: root.isLive
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
              }
            }

            Text {
              id: scoreText
              anchors.verticalCenter: parent.verticalCenter
              text: root.scoreHidden
                ? "••••"
                : (root.isUpcoming
                   ? Model.formatKickoff(modelData.time)
                   : (modelData.scoreText || "–"))
              color: root.isLive
                ? root.urgentColor
                : (root.isUpcoming ? Qt.darker(root.fgColor, 1.2) : root.fgColor)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }

        // Right Side (Away)
        Item {
          id: awayTeamLayout
          anchors.left: centerScoreHolder.right
          anchors.leftMargin: Style.space(8)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          implicitHeight: Math.max(awayRowCrest.height, awayTeamText.implicitHeight)

          TeamCrest {
            id: awayRowCrest
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            sport: modelData.sport || "football"
            teamId: modelData.away.id
            teamName: modelData.away.name
            abbr: modelData.away.abbr || ""
            source: modelData.away.logo || ""
            crestSize: Style.space(18)
          }

          Text {
            id: awayTeamText
            anchors.left: awayRowCrest.right
            anchors.leftMargin: Style.space(6)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (modelData.away.name || modelData.away.shortName) + (root.favIsAway ? " ★" : "")
            color: root.favIsAway ? Color.accent : root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: root.favIsAway || (modelData.awayScore > modelData.homeScore)
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  MouseArea {
    id: matchMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (root.isF1) {
        root.expanded = !root.expanded
      } else if (root.scoreHidden) {
        root.revealMatch(modelData.id)
      } else {
        root.openMatch(modelData)
      }
    }
  }
}
