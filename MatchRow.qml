import QtQuick
import qs.Commons
import "SportsModel.js" as Model

// One fixture/result row: a team-vs-team card, or an expandable F1 Grand Prix
// weekend entry with its sessions timetable. Theme/state inputs are injected
// by Panel.qml.
Item {
  id: root
  Theme { id: theme }

  required property var modelData
  required property int index

  property string activeSport: "football"
  property color fgColor
  property color urgentColor
  property var selectedTeamIds: []
  property bool antiSpoiler: false
  property var revealedMatchIds: ({})
  property double nowMs: 0
  property double fetchedAtMs: 0
  property var revealMatch: null // function(matchId)
  property var openMatch: null // function(match)
  property string broadcast: ""
  property var matchEvents: null
  property bool listVisible: true
  property bool rowFocused: false

  readonly property bool isF1: root.activeSport === "f1"
  readonly property bool isLive: modelData.status === "live"
  readonly property bool isUpcoming: modelData.status === "upcoming"
  readonly property bool isFinished: modelData.status === "finished"
  readonly property bool favIsHome: Model.isFollowedTeam(modelData.home && modelData.home.id, root.selectedTeamIds)
  readonly property bool favIsAway: Model.isFollowedTeam(modelData.away && modelData.away.id, root.selectedTeamIds)
  readonly property string dateBadge: Model.formatMatchDate(modelData.time)
  readonly property string syncedLiveTime: Model.cleanLiveTime(Model.interpolateLiveTime(modelData, root.nowMs, root.fetchedAtMs)) || "LIVE"
  readonly property bool isScoreRevealed: root.revealedMatchIds[String(modelData.id)] === true
  readonly property bool scoreHidden: root.antiSpoiler && (isFinished || isLive) && !isScoreRevealed
  readonly property string scoreLabel: root.scoreHidden
    ? "••••"
    : (root.isUpcoming
       ? Model.formatKickoff(modelData.time)
       : (modelData.scoreText || "–"))
  // Expansion state lives in the panel's id-keyed map so keyboard activation
  // (Enter) can toggle it exactly like the mouse click does
  property var expandedIds: ({})
  property var toggleExpand: null // function(matchId)
  readonly property bool expanded: root.expandedIds[String(modelData.id)] === true

  readonly property string favTeamId: Model.teamIdForMatch(modelData, root.selectedTeamIds)
  readonly property string favOutcome: Model.teamOutcome(modelData, favTeamId)
  readonly property string favLiveState: Model.teamLiveState(modelData, favTeamId)
  readonly property string generalOutcome: Model.generalMatchOutcome(modelData)
  readonly property string ftReason: modelData.sport && modelData.sport !== "football"
    ? (modelData.statusReason ? modelData.statusReason.toUpperCase() : "FINAL")
    : (modelData.statusReason === "AET" ? "AET" : (modelData.statusReason === "PEN" ? "PEN" : "FT"))

  width: parent.width
  implicitHeight: matchCard.implicitHeight

  Rectangle {
    id: matchCard
    width: parent.width
    implicitHeight: root.isF1 ? (f1ContainerCol.implicitHeight + Style.space(14)) : (matchRowLayout.implicitHeight + Style.space(14))
    radius: theme.subtleRadius(6)
    Accessible.role: Accessible.Button
    Accessible.name: {
      var h = (modelData.home && (modelData.home.name || modelData.home.shortName)) || ""
      var a = (modelData.away && (modelData.away.name || modelData.away.shortName)) || ""
      var s = h + " versus " + a
      if (root.scoreHidden) return s + ", result hidden"
      if (root.isLive) return s + ", live, " + root.scoreLabel
      if (root.isUpcoming) return s + ", upcoming"
      return s + ", finished" + (root.scoreLabel ? ", " + root.scoreLabel : "")
    }
    color: matchMouse.containsMouse
      ? Style.hoverFillFor(root.fgColor, Color.accent)
      : theme.mutedColor(root.fgColor, 0.02)
    border.width: (root.rowFocused || root.favLiveState !== "") ? 1.5 : 1
    border.color: matchMouse.containsMouse
      ? Color.accent
      : (root.rowFocused
         ? Color.accent
         : (root.favLiveState === "leading"
            ? Util.alpha("#22c55e", 0.35)
            : (root.favLiveState === "trailing"
               ? Util.alpha("#ef4444", 0.35)
               : (root.favLiveState === "tied"
                  ? Util.alpha("#f59e0b", 0.35)
                  : (root.isLive ? Util.alpha(Color.accent, 0.25) : theme.mutedColor(root.fgColor, 0.06))))))

    Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(3)
      width: Style.space(3)
      radius: width / 2
      visible: root.isLive || (root.isFinished && (root.favOutcome !== "" || (root.isF1 && Boolean(modelData.winner))))
      color: root.isLive
        ? (root.favLiveState === "leading" ? "#22c55e" : (root.favLiveState === "trailing" ? "#ef4444" : (root.favLiveState === "tied" ? "#f59e0b" : Color.accent)))
        : (root.favOutcome === "win"
           ? "#22c55e"
           : (root.favOutcome === "loss"
              ? "#ef4444"
              : (root.favOutcome === "draw" ? "#f59e0b" : (root.isF1 && modelData.winner ? "#eab308" : theme.mutedColor(root.fgColor, 0.2)))))
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
            color: theme.mutedColor(root.fgColor, 0.65)
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
          width: parent.width - Style.space(175)
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
              color: theme.mutedColor(root.fgColor, 0.45)
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
            radius: theme.subtleRadius(4)
            color: root.isLive
              ? Util.alpha(root.urgentColor, 0.14)
              : (root.isFinished
                 ? (modelData.winner ? Util.alpha("#eab308", 0.18) : theme.mutedColor(root.fgColor, 0.08))
                 : Util.alpha(Color.accent, 0.15))
            border.width: 1
            border.color: root.isLive
              ? Util.alpha(root.urgentColor, 0.3)
              : (root.isFinished
                 ? (modelData.winner ? Util.alpha("#eab308", 0.45) : theme.mutedColor(root.fgColor, 0.12))
                 : Util.alpha(Color.accent, 0.3))

            Text {
              id: f1StatusText
              anchors.centerIn: parent
              text: root.isFinished
                ? (modelData.winner ? ("🏆 " + (modelData.winner.code || modelData.winner.familyName)) : "Official")
                : (root.isLive ? "RACE DAY" : Model.formatKickoff(modelData.time))
              color: root.isLive
                ? theme.onUrgent(root.urgentColor)
                : (root.isFinished
                   ? (modelData.winner ? "#eab308" : theme.mutedColor(root.fgColor, 0.65))
                   : Color.accent)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Text {
            visible: root.isF1 && Boolean(modelData && modelData.sessions && modelData.sessions.length > 0)
            text: root.expanded ? "󰅃" : "󰅀"
            color: theme.mutedColor(root.fgColor, 0.45)
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
          color: theme.mutedColor(root.fgColor, 0.08)
        }

        Repeater {
          model: modelData.sessions

          delegate: Rectangle {
            required property var modelData
            required property int index

            width: f1SessionsDropdown.width
            implicitHeight: Style.space(22)
            radius: 3
            color: index % 2 === 1 ? theme.mutedColor(root.fgColor, 0.025) : "transparent"

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
                color: theme.mutedColor(root.fgColor, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: Style.space(84)
                text: {
                  if (modelData.shortName === "Race" && root.modelData.winner) {
                    return "🏆 " + (root.modelData.winner.code || root.modelData.winner.familyName)
                  }
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
                  if (modelData.shortName === "Race" && root.modelData.winner) return Color.accent
                  var ms2 = Date.parse(modelData.time)
                  if (root.nowMs >= ms2 && root.nowMs <= ms2 + 2.5 * 3600 * 1000) return root.urgentColor
                  return theme.mutedColor(root.fgColor, 0.45)
                }
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: (modelData.shortName === "Race" && Boolean(root.modelData.winner)) || (root.nowMs >= Date.parse(modelData.time) && root.nowMs <= Date.parse(modelData.time) + 2.5 * 3600 * 1000)
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }
    }

    // Modern Stacked Broadcast Match Card (Football, NBA, NFL, MLB, NHL)
    Column {
      id: matchRowLayout
      visible: !root.isF1
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(5)

      // Top Header Line: Competition name & Kickoff / Status Pill
      Item {
        width: parent.width
        implicitHeight: Math.max(matchCompLabel.implicitHeight, matchStatusBadge.implicitHeight)

        Row {
          id: matchCompLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Text {
            text: root.isLive && Model.formatKickoff(modelData.time)
              ? (root.dateBadge + " · Started " + Model.formatKickoff(modelData.time))
              : root.dateBadge
            color: theme.mutedColor(root.fgColor, 0.65)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            text: "·"
            color: theme.mutedColor(root.fgColor, 0.35)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Text {
            text: "🏆 " + (Model.shortTournamentName(modelData.leagueName) || (modelData.round ? modelData.round : ""))
            color: theme.mutedColor(root.fgColor, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: Math.min(implicitWidth, matchRowLayout.width - Style.space(160))
          }

          // Broadcaster Pill
          Rectangle {
            visible: Boolean(root.broadcast) && (root.isUpcoming || root.isLive)
            implicitWidth: rowBcastText.implicitWidth + Style.space(6)
            implicitHeight: rowBcastText.implicitHeight + Style.space(2)
            radius: theme.subtleRadius(3)
            color: theme.mutedColor(root.fgColor, 0.05)
            border.width: 1
            border.color: theme.mutedColor(root.fgColor, 0.1)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: rowBcastText
              anchors.centerIn: parent
              text: "📺 " + String(root.broadcast).toUpperCase()
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        // Right Status Pill (Live minute, FT, or Kickoff)
        Rectangle {
          id: matchStatusBadge
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: statusRow.implicitWidth + Style.space(10)
          implicitHeight: statusRow.implicitHeight + Style.space(3)
          radius: theme.subtleRadius(4)
          color: root.isLive
            ? Util.alpha(root.urgentColor, 0.14)
            : (root.isFinished
               ? (root.scoreHidden
                  ? theme.mutedColor(root.fgColor, 0.08)
                  : (root.favOutcome === "win"
                     ? Util.alpha("#22c55e", 0.16)
                     : (root.favOutcome === "loss"
                        ? Util.alpha("#ef4444", 0.16)
                        : (root.favOutcome === "draw" || root.generalOutcome === "draw"
                           ? Util.alpha("#f59e0b", 0.16)
                           : theme.mutedColor(root.fgColor, 0.08)))))
               : Util.alpha(Color.accent, 0.14))
          border.width: 1
          border.color: root.isLive
            ? Util.alpha(root.urgentColor, 0.3)
            : (root.isFinished
               ? (root.scoreHidden
                  ? theme.mutedColor(root.fgColor, 0.15)
                  : (root.favOutcome === "win"
                     ? Util.alpha("#22c55e", 0.45)
                     : (root.favOutcome === "loss"
                        ? Util.alpha("#ef4444", 0.45)
                        : (root.favOutcome === "draw" || root.generalOutcome === "draw"
                           ? Util.alpha("#f59e0b", 0.45)
                           : theme.mutedColor(root.fgColor, 0.15)))))
               : Util.alpha(Color.accent, 0.3))

          Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Rectangle {
              visible: root.isLive
              width: Style.space(4)
              height: width
              radius: width / 2
              color: root.urgentColor
              anchors.verticalCenter: parent.verticalCenter

              SequentialAnimation on opacity {
                running: root.listVisible && root.isLive
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
              }
            }

            Text {
              text: root.isLive
                ? root.syncedLiveTime
                : (root.isFinished
                    ? (root.scoreHidden
                        ? "•••• 󰈈"
                        : (root.favOutcome === "win"
                           ? ("✓ WIN · " + root.ftReason)
                           : (root.favOutcome === "loss"
                              ? ("✕ LOSS · " + root.ftReason)
                              : (root.favOutcome === "draw"
                                 ? ("− DRAW · " + root.ftReason)
                                 : (root.generalOutcome === "draw"
                                    ? ("DRAW · " + root.ftReason)
                                    : ("🏁 " + root.ftReason))))))
                    : ("⏱ " + Model.formatKickoff(modelData.time)))
              color: root.isLive
                ? root.urgentColor
                : (root.isFinished
                   ? (root.scoreHidden
                      ? theme.mutedColor(root.fgColor, 0.75)
                      : (root.favOutcome === "win"
                         ? "#22c55e"
                         : (root.favOutcome === "loss"
                            ? "#ef4444"
                            : (root.favOutcome === "draw" || root.generalOutcome === "draw"
                               ? "#f59e0b"
                               : theme.mutedColor(root.fgColor, 0.75)))))
                   : Color.accent)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }
      }

      // Middle Stacked Teams Grid
      Column {
        width: parent.width
        spacing: Style.space(3)

        // Home Team Row
        Item {
          width: parent.width
          implicitHeight: Math.max(homeCrest.height, homeTeamName.implicitHeight)

          Row {
            anchors.left: parent.left
            anchors.right: homeScoreText.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            TeamCrest {
              id: homeCrest
              sport: modelData.sport || "football"
              teamId: modelData.home.id
              teamName: modelData.home.name
              abbr: modelData.home.abbr || ""
              source: modelData.home.logo || ""
              crestSize: Style.space(18)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: homeTeamName
              text: (root.favIsHome ? "★ " : "") + (modelData.home.name || modelData.home.shortName)
              color: root.favIsHome ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: root.favIsHome || (!root.scoreHidden && Number(modelData.homeScore) > Number(modelData.awayScore))
              elide: Text.ElideRight
              width: Math.min(implicitWidth, parent.width - homeCrest.width - Style.space(6) - (homeRecordText.visible ? homeRecordText.implicitWidth + Style.space(4) : 0))
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: homeRecordText
              visible: Boolean(modelData.home && modelData.home.record)
              text: modelData.home && modelData.home.record ? ("(" + modelData.home.record + ")") : ""
              color: theme.mutedColor(root.fgColor, 0.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            id: homeScoreText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.isUpcoming || root.scoreHidden
            text: root.scoreHidden
              ? "••••"
              : (root.isUpcoming ? "" : String(modelData.homeScore !== undefined ? modelData.homeScore : "–"))
            color: root.scoreHidden
              ? theme.mutedColor(root.fgColor, 0.5)
              : (root.isLive
                 ? (root.favLiveState === "leading" && root.favIsHome
                    ? "#22c55e"
                    : (root.favLiveState === "trailing" && root.favIsHome
                       ? "#ef4444"
                       : (Number(modelData.homeScore) > Number(modelData.awayScore)
                          ? "#22c55e"
                          : (Number(modelData.homeScore) < Number(modelData.awayScore) ? theme.mutedColor(root.fgColor, 0.55) : root.fgColor))))
                 : (root.isFinished
                    ? (Number(modelData.homeScore) > Number(modelData.awayScore)
                       ? "#22c55e"
                       : (Number(modelData.homeScore) === Number(modelData.awayScore)
                          ? "#f59e0b"
                          : theme.mutedColor(root.fgColor, 0.45)))
                    : root.fgColor))
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
        }

        // Away Team Row
        Item {
          width: parent.width
          implicitHeight: Math.max(awayCrest.height, awayTeamName.implicitHeight)

          Row {
            anchors.left: parent.left
            anchors.right: awayScoreText.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            TeamCrest {
              id: awayCrest
              sport: modelData.sport || "football"
              teamId: modelData.away.id
              teamName: modelData.away.name
              abbr: modelData.away.abbr || ""
              source: modelData.away.logo || ""
              crestSize: Style.space(18)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: awayTeamName
              text: (root.favIsAway ? "★ " : "") + (modelData.away.name || modelData.away.shortName)
              color: root.favIsAway ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: root.favIsAway || (!root.scoreHidden && Number(modelData.awayScore) > Number(modelData.homeScore))
              elide: Text.ElideRight
              width: Math.min(implicitWidth, parent.width - awayCrest.width - Style.space(6) - (awayRecordText.visible ? awayRecordText.implicitWidth + Style.space(4) : 0))
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: awayRecordText
              visible: Boolean(modelData.away && modelData.away.record)
              text: modelData.away && modelData.away.record ? ("(" + modelData.away.record + ")") : ""
              color: theme.mutedColor(root.fgColor, 0.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            id: awayScoreText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.isUpcoming || root.scoreHidden
            text: root.scoreHidden
              ? "••••"
              : (root.isUpcoming ? "" : String(modelData.awayScore !== undefined ? modelData.awayScore : "–"))
            color: root.scoreHidden
              ? theme.mutedColor(root.fgColor, 0.5)
              : (root.isLive
                 ? (root.favLiveState === "leading" && root.favIsAway
                    ? "#22c55e"
                    : (root.favLiveState === "trailing" && root.favIsAway
                       ? "#ef4444"
                       : (Number(modelData.awayScore) > Number(modelData.homeScore)
                          ? "#22c55e"
                          : (Number(modelData.awayScore) < Number(modelData.homeScore) ? theme.mutedColor(root.fgColor, 0.55) : root.fgColor))))
                 : (root.isFinished
                    ? (Number(modelData.awayScore) > Number(modelData.homeScore)
                       ? "#22c55e"
                       : (Number(modelData.awayScore) === Number(modelData.homeScore)
                          ? "#f59e0b"
                          : theme.mutedColor(root.fgColor, 0.45)))
                    : root.fgColor))
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
        }

        // Goal scorers summary for football
        Item {
          width: parent.width
          visible: root.activeSport === "football" && !root.scoreHidden && Boolean(root.matchEvents && root.matchEvents.goals && root.matchEvents.goals.length > 0)
          implicitHeight: visible ? (goalScorersRow.implicitHeight + Style.space(2)) : 0

          Row {
            id: goalScorersRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.space(4)

            Text {
              text: "⚽"
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              width: parent.width - Style.space(20)
              text: {
                if (!root.matchEvents || !root.matchEvents.goals) return ""
                var gList = []
                for (var g = 0; g < Math.min(root.matchEvents.goals.length, 3); g++) {
                  var gObj = root.matchEvents.goals[g]
                  gList.push(gObj.player + " " + gObj.minute)
                }
                if (root.matchEvents.goals.length > 3) gList.push("+" + (root.matchEvents.goals.length - 3) + " more")
                return gList.join(", ")
              }
              color: theme.mutedColor(root.fgColor, 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              anchors.verticalCenter: parent.verticalCenter
            }
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
        if (root.toggleExpand) root.toggleExpand(modelData.id)
      } else if (root.scoreHidden) {
        if (root.revealMatch) root.revealMatch(modelData.id)
      } else if (root.openMatch) {
        root.openMatch(modelData)
      }
    }
  }
}
