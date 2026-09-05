import QtQuick
import qs.Commons
import "SportsModel.js" as Model

// Hero card highlighting the featured match of a followed team, or the next
// Grand Prix weekend when the active sport is F1. Injected by Panel.qml.
Item {
  id: root
  Theme { id: theme }

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
  property string broadcast: ""
  property var gameLeaders: []
  property var matchEvents: null
  property var matchForm: null
  property var matchStats: null
  property var f1Podium: []
  property var f1Pole: null
  property var kickoffTime: null // function(match)
  property var matchSubline: null // function(match)
  property var openMatch: null // function(match)
  property var revealMatch: null // function(matchId)
  property var toggleRevealScore: null // function(matchId)
  property bool rowFocused: false
  property double nowMs: 0
  property double fetchedAtMs: 0
  // False while the spotlight is hidden (off-screen tabs) — infinite animations
  // must not drive scene-graph updates for content the user cannot see.
  property bool listVisible: true

  width: parent.width
  implicitHeight: spotlightSurface.implicitHeight

  readonly property var match: featuredMatch || fallbackMatch
  readonly property bool isLive: match && match.status === "live"
  readonly property string syncedLiveTime: Model.cleanLiveTime(Model.interpolateLiveTime(root.match, root.nowMs, root.fetchedAtMs)) || "LIVE"
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
  readonly property string liveState: match ? Model.teamLiveState(match, root.favoriteMatchTeamId) : ""
  readonly property string ftReason: match && match.sport && match.sport !== "football"
    ? (match.statusReason ? match.statusReason.toUpperCase() : "FINAL")
    : (match && match.statusReason === "AET" ? "AET" : (match && match.statusReason === "PEN" ? "PEN" : "FT"))
  readonly property bool isScoreRevealed: Boolean(match && root.revealedMatchIds && root.revealedMatchIds[String(match.id)])
  readonly property bool scoreHidden: root.antiSpoiler && (isFinished || isLive) && !isScoreRevealed

  Rectangle {
    id: spotlightSurface
    width: parent.width
    implicitHeight: spotlightCol.implicitHeight + Style.space(20)
    radius: Style.cornerRadius
    color: spotlightMouse.containsMouse
      ? Style.hoverFillFor(root.fgColor, Color.accent)
      : theme.mutedColor(root.fgColor, 0.035)
    border.width: root.rowFocused ? 2 : 1
    border.color: spotlightMouse.containsMouse
      ? Color.accent
      : (root.rowFocused
         ? Color.accent
         : (root.liveState === "leading"
            ? Util.alpha("#22c55e", 0.4)
            : (root.liveState === "trailing"
               ? Util.alpha("#ef4444", 0.4)
               : (root.liveState === "tied"
                  ? Util.alpha("#f59e0b", 0.35)
                  : (root.isLive ? Util.alpha(Color.accent, 0.3) : theme.mutedColor(root.fgColor, 0.12))))))
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

    Rectangle {
      id: spotlightLeftStripe
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(3)
      width: Style.space(4)
      radius: width / 2
      visible: Boolean(root.match) && (root.isLive || (root.isFinished && (root.outcome !== "" || (root.isF1 && root.match && root.match.winner))))
      color: root.isLive
        ? (root.liveState === "leading" ? "#22c55e" : (root.liveState === "trailing" ? "#ef4444" : (root.liveState === "tied" ? "#f59e0b" : Color.accent)))
        : (root.isF1 && root.match && root.match.winner
           ? "#eab308"
           : (root.outcome === "win"
              ? "#22c55e"
              : (root.outcome === "loss"
                 ? "#ef4444"
                 : (root.outcome === "draw" ? "#f59e0b" : theme.mutedColor(root.fgColor, 0.2)))))
    }

    Column {
      id: spotlightCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(12)
      spacing: Style.space(10)

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
            radius: theme.subtleRadius(3)
            color: Util.alpha(Color.accent, 0.18)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: spotlightTagLabel
              anchors.centerIn: parent
              text: root.isF1 ? "GRAND PRIX" : (root.favoriteMatchTeamId !== "" ? "SPOTLIGHT" : "FEATURED MATCH")
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (root.match ? root.match.leagueName : "")
              + (root.match && root.match.round ? " · " + root.match.round : "")
              + (root.isLive && Model.formatKickoff(root.match && root.match.time) ? " · Started " + Model.formatKickoff(root.match.time) : "")
            color: theme.mutedColor(root.fgColor, 0.65)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Rectangle {
            visible: Boolean(root.broadcast) && (root.isUpcoming || root.isLive)
            implicitWidth: spotlightBcastRow.implicitWidth + Style.space(8)
            implicitHeight: spotlightBcastRow.implicitHeight + Style.space(4)
            radius: theme.subtleRadius(3)
            color: theme.mutedColor(root.fgColor, 0.06)
            border.width: 1
            border.color: theme.mutedColor(root.fgColor, 0.12)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: spotlightBcastRow
              anchors.centerIn: parent
              spacing: Style.space(3)
              Text { text: "📺"; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
              Text {
                text: String(root.broadcast).toUpperCase()
                color: root.fgColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }

        Rectangle {
          id: spotlightStatusPill
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: statusPillRow.implicitWidth + Style.space(10)
          implicitHeight: statusPillRow.implicitHeight + Style.space(4)
          radius: theme.subtleRadius(4)
          color: root.isLive
            ? Util.alpha(root.urgentColor, 0.14)
            : (root.match && root.match.status === "finished"
               ? (root.scoreHidden
                  ? theme.mutedColor(root.fgColor, 0.08)
                  : (root.isF1 && root.match.winner
                     ? Util.alpha("#eab308", 0.18)
                     : (root.outcome === "win"
                        ? Util.alpha("#22c55e", 0.18)
                        : (root.outcome === "loss"
                           ? Util.alpha("#ef4444", 0.18)
                           : (root.outcome === "draw"
                              ? Util.alpha("#f59e0b", 0.18)
                              : theme.mutedColor(root.fgColor, 0.08))))))
               : Util.alpha(Color.accent, 0.14))
          border.width: 1
          border.color: root.isLive
            ? Util.alpha(root.urgentColor, 0.3)
            : (root.match && root.match.status === "finished"
               ? (root.scoreHidden
                  ? theme.mutedColor(root.fgColor, 0.15)
                  : (root.isF1 && root.match.winner
                     ? Util.alpha("#eab308", 0.45)
                     : (root.outcome === "win"
                        ? Util.alpha("#22c55e", 0.45)
                        : (root.outcome === "loss"
                           ? Util.alpha("#ef4444", 0.45)
                           : (root.outcome === "draw"
                              ? Util.alpha("#f59e0b", 0.45)
                              : theme.mutedColor(root.fgColor, 0.15))))))
               : Util.alpha(Color.accent, 0.3))

          Row {
            id: statusPillRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Rectangle {
              visible: root.isLive
              width: Style.space(5)
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
                ? (root.syncedLiveTime === "LIVE" ? "LIVE" : ("LIVE · " + root.syncedLiveTime))
                : (root.match && root.match.status === "finished"
                   ? (root.isF1
                      ? (root.match.winner ? ("🏆 " + (root.match.winner.code || root.match.winner.familyName).toUpperCase() + " · WINNER") : "OFFICIAL")
                      : (root.scoreHidden
                          ? ((root.match.sport && root.match.sport !== "football") ? "FINAL · REVEAL 󰈈" : "FT · REVEAL 󰈈")
                          : (root.outcome === "win"
                             ? ("✓ VICTORY · " + root.ftReason)
                             : (root.outcome === "loss"
                                ? ("✕ DEFEAT · " + root.ftReason)
                                : (root.outcome === "draw"
                                   ? ("− DRAW · " + root.ftReason)
                                   : ("🏁 " + root.ftReason))))))
                   : (root.match
                      ? (root.isF1
                         ? Qt.formatDateTime(new Date(Date.parse(root.match.time || "")), "ddd d MMM · HH:mm")
                         : Qt.formatDateTime(new Date(Date.parse(root.match.time || "")), "ddd d MMM"))
                      : ""))
              color: root.isLive
                ? root.urgentColor
                : (root.match && root.match.status === "finished"
                   ? (root.scoreHidden
                      ? theme.mutedColor(root.fgColor, 0.75)
                      : (root.isF1 && root.match.winner
                         ? "#eab308"
                         : (root.outcome === "win"
                            ? "#22c55e"
                            : (root.outcome === "loss"
                               ? "#ef4444"
                               : (root.outcome === "draw"
                                  ? "#f59e0b"
                                  : theme.mutedColor(root.fgColor, 0.75))))))
                   : Color.accent)
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
          spacing: Style.space(6)

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
                text: root.match ? ("📍 " + (root.match.circuitName || "") + (root.match.locality ? " · " + root.match.locality : "") + (root.match.country ? ", " + root.match.country : "")) : ""
                color: theme.mutedColor(root.fgColor, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }

          // Winner Showcase (for finished Grand Prix)
          Rectangle {
            visible: root.isFinished && Boolean(root.match && root.match.winner)
            width: parent.width
            implicitHeight: winnerCol.implicitHeight + Style.space(12)
            radius: theme.subtleRadius(4)
            color: Util.alpha(Color.accent, 0.12)
            border.width: 1
            border.color: Util.alpha(Color.accent, 0.3)

            Column {
              id: winnerCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(8)
              spacing: Style.space(2)

              Row {
                width: parent.width
                spacing: Style.space(6)

                Text {
                  text: "🏆"
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: "RACE WINNER: " + (root.match && root.match.winner ? root.match.winner.driverName.toUpperCase() : "")
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  visible: Boolean(root.match && root.match.winner && root.match.winner.constructorName)
                  text: "· " + (root.match && root.match.winner ? root.match.winner.constructorName : "")
                  color: theme.mutedColor(root.fgColor, 0.75)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                visible: Boolean(root.match && root.match.winner && (root.match.winner.time || root.match.winner.laps))
                text: {
                  if (!root.match || !root.match.winner) return ""
                  var parts = []
                  if (root.match.winner.time) parts.push("⏱ " + root.match.winner.time)
                  if (root.match.winner.laps) parts.push(root.match.winner.laps + " Laps")
                  if (root.match.winner.grid) parts.push("Grid P" + root.match.winner.grid)
                  return parts.join(" · ")
                }
                color: theme.mutedColor(root.fgColor, 0.6)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          // F1 3-Step Podium Showcase & Pole Position
          Rectangle {
            id: podiumCard
            visible: root.isF1 && Boolean(root.f1Podium && root.f1Podium.length >= 3)
            width: parent.width
            implicitHeight: podiumCol.implicitHeight + Style.space(12)
            radius: theme.subtleRadius(4)
            color: theme.mutedColor(root.fgColor, 0.03)
            border.width: 1
            border.color: theme.mutedColor(root.fgColor, 0.08)

            Column {
              id: podiumCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Item {
                width: parent.width
                implicitHeight: podiumHeading.implicitHeight

                Text {
                  id: podiumHeading
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "🏆 RACE PODIUM & TOP 3"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 0.8
                }

                Text {
                  visible: Boolean(root.f1Pole)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.f1Pole ? ("⚡ POLE: " + root.f1Pole.code + (root.f1Pole.lapTime ? " (" + root.f1Pole.lapTime + ")" : "")) : ""
                  color: theme.mutedColor(root.fgColor, 0.65)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: root.f1Podium || []
                  delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: (podiumCol.width - Style.space(12)) / 3
                    implicitHeight: podItemCol.implicitHeight + Style.space(8)
                    radius: theme.subtleRadius(4)
                    color: index === 0 ? Util.alpha(Color.accent, 0.12) : theme.mutedColor(root.fgColor, 0.02)
                    border.width: 1
                    border.color: index === 0 ? Color.accent : theme.mutedColor(root.fgColor, 0.08)

                    Column {
                      id: podItemCol
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.margins: Style.space(6)
                      spacing: Style.space(2)

                      Row {
                        spacing: Style.space(4)
                        Text {
                          text: index === 0 ? "🥇" : (index === 1 ? "🥈" : "🥉")
                          font.pixelSize: Style.font.caption
                        }
                        Text {
                          text: modelData.code || modelData.driverName
                          color: index === 0 ? Color.accent : root.fgColor
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: true
                          elide: Text.ElideRight
                        }
                      }

                      Text {
                        width: parent.width
                        text: modelData.constructorName || ""
                        color: theme.mutedColor(root.fgColor, 0.5)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }

                      Text {
                        width: parent.width
                        text: modelData.time || (modelData.points + " pts")
                        color: theme.mutedColor(root.fgColor, 0.7)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }
          }

          // Next Session Countdown Banner (for upcoming Grand Prix)
          Rectangle {
            id: nextSesCard
            readonly property var nextSes: Model.nextF1Session(root.match, Date.now())
            visible: !root.isFinished && nextSes !== null
            width: parent.width
            implicitHeight: Style.space(26)
            radius: theme.subtleRadius(4)
            color: nextSes && nextSes.isLive ? Util.alpha(root.urgentColor, 0.15) : theme.mutedColor(root.fgColor, 0.05)
            border.width: 1
            border.color: nextSes && nextSes.isLive ? root.urgentColor : theme.mutedColor(root.fgColor, 0.12)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(8)

              Text {
                text: nextSesCard.nextSes && nextSesCard.nextSes.isLive ? "🔴" : "⏱"
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: parent.width - Style.space(32)
                text: nextSesCard.nextSes
                  ? ((nextSesCard.nextSes.isLive ? "LIVE NOW: " : "NEXT SESSION: ") + nextSesCard.nextSes.name + " · " + nextSesCard.nextSes.formattedTime)
                  : ""
                color: nextSesCard.nextSes && nextSesCard.nextSes.isLive ? root.urgentColor : root.fgColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
              }
            }
          }

          // Driver standing badge if driver followed
          Rectangle {
            visible: root.favoriteDriverStanding !== null
            implicitWidth: driverPillRow.implicitWidth + Style.space(14)
            implicitHeight: driverPillRow.implicitHeight + Style.space(6)
            radius: theme.subtleRadius(4)
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
              color: (root.favoriteMatchTeamId !== "" && String(root.match && root.match.home.id) === String(root.favoriteMatchTeamId)) ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.match && root.match.home.record ? root.match.home.record : ((root.favoriteMatchTeamId !== "" && String(root.match && root.match.home.id) === String(root.favoriteMatchTeamId)) ? "HOME · FAVORITE" : "HOME")
              color: theme.mutedColor(root.fgColor, 0.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }

            // 5-match recent form badges (Home)
            Row {
              anchors.right: parent.right
              spacing: Style.space(3)
              visible: Boolean(root.matchForm && root.matchForm.home && root.matchForm.home.length > 0)
              Repeater {
                model: root.matchForm && root.matchForm.home ? root.matchForm.home : []
                delegate: Rectangle {
                  required property string modelData
                  width: Style.space(12)
                  height: Style.space(12)
                  radius: Style.space(2)
                  color: modelData === "W" ? "#22c55e" : (modelData === "D" ? theme.mutedColor(root.fgColor, 0.25) : root.urgentColor)
                  Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 8
                    font.bold: true
                    color: "#ffffff"
                  }
                }
              }
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
            radius: theme.subtleRadius(5)
            color: root.isLive
              ? (root.liveState === "leading"
                 ? Util.alpha("#22c55e", 0.16)
                 : (root.liveState === "trailing"
                    ? Util.alpha("#ef4444", 0.16)
                    : (root.liveState === "tied" ? Util.alpha("#f59e0b", 0.16) : theme.mutedColor(root.fgColor, 0.06))))
              : (!root.scoreHidden && root.isFinished
                 ? (root.outcome === "win"
                    ? Util.alpha("#22c55e", 0.16)
                    : (root.outcome === "loss"
                       ? Util.alpha("#ef4444", 0.16)
                       : (root.outcome === "draw" ? Util.alpha("#f59e0b", 0.16) : theme.mutedColor(root.fgColor, 0.06))))
                 : theme.mutedColor(root.fgColor, 0.06))
            border.width: 1
            border.color: root.isLive
              ? (root.liveState === "leading"
                 ? "#22c55e"
                 : (root.liveState === "trailing"
                    ? "#ef4444"
                    : (root.liveState === "tied" ? "#f59e0b" : theme.mutedColor(root.fgColor, 0.14))))
              : (!root.scoreHidden && root.isFinished
                 ? (root.outcome === "win"
                    ? Util.alpha("#22c55e", 0.45)
                    : (root.outcome === "loss"
                       ? Util.alpha("#ef4444", 0.45)
                       : (root.outcome === "draw" ? Util.alpha("#f59e0b", 0.45) : theme.mutedColor(root.fgColor, 0.12))))
                 : theme.mutedColor(root.fgColor, 0.12))

            Text {
              anchors.centerIn: parent
              text: root.scoreHidden
                ? "••••"
                : (root.match && root.match.status !== "upcoming"
                   ? (root.match.scoreText || "–")
                   : (root.kickoffTime(root.match) || "VS"))
              color: root.isLive
                ? (root.liveState === "leading"
                   ? "#22c55e"
                   : (root.liveState === "trailing"
                      ? "#ef4444"
                      : (root.liveState === "tied" ? "#f59e0b" : root.fgColor)))
                : (root.isUpcoming
                   ? Color.accent
                   : (!root.scoreHidden && root.isFinished
                      ? (root.outcome === "win"
                         ? "#22c55e"
                         : (root.outcome === "loss"
                            ? "#ef4444"
                            : (root.outcome === "draw" ? "#f59e0b" : root.fgColor)))
                      : root.fgColor))
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onClicked: {
                if (root.toggleRevealScore && root.match) root.toggleRevealScore(root.match.id)
                else if (root.revealMatch && root.match) root.revealMatch(root.match.id)
              }
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
              color: (root.favoriteMatchTeamId !== "" && String(root.match && root.match.away.id) === String(root.favoriteMatchTeamId)) ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignLeft
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.match && root.match.away.record ? root.match.away.record : ((root.favoriteMatchTeamId !== "" && String(root.match && root.match.away.id) === String(root.favoriteMatchTeamId)) ? "AWAY · FAVORITE" : "AWAY")
              color: theme.mutedColor(root.fgColor, 0.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignLeft
              elide: Text.ElideRight
            }

            // 5-match recent form badges (Away)
            Row {
              anchors.left: parent.left
              spacing: Style.space(3)
              visible: Boolean(root.matchForm && root.matchForm.away && root.matchForm.away.length > 0)
              Repeater {
                model: root.matchForm && root.matchForm.away ? root.matchForm.away : []
                delegate: Rectangle {
                  required property string modelData
                  width: Style.space(12)
                  height: Style.space(12)
                  radius: Style.space(2)
                  color: modelData === "W" ? "#22c55e" : (modelData === "D" ? theme.mutedColor(root.fgColor, 0.25) : root.urgentColor)
                  Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 8
                    font.bold: true
                    color: "#ffffff"
                  }
                }
              }
            }
          }
        }
      }

      // Football Goal Scorers & Red Cards Timeline
      Rectangle {
        id: eventsCard
        visible: !root.isF1 && !root.scoreHidden
          && Boolean(root.matchEvents)
          && ((root.matchEvents.goals && root.matchEvents.goals.length > 0)
              || (root.matchEvents.redCards && root.matchEvents.redCards.length > 0))
        width: parent.width
        implicitHeight: eventsCol.implicitHeight + Style.space(12)
        radius: theme.subtleRadius(4)
        color: theme.mutedColor(root.fgColor, 0.025)
        border.width: 1
        border.color: theme.mutedColor(root.fgColor, 0.08)

        Column {
          id: eventsCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          Item {
            width: parent.width
            implicitHeight: Math.max(homeEvCol.implicitHeight, awayEvCol.implicitHeight)

            // Home Events
            Column {
              id: homeEvCol
              anchors.left: parent.left
              anchors.right: parent.horizontalCenter
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(2)

              Repeater {
                model: {
                  var list = []
                  if (root.matchEvents && root.matchEvents.goals) {
                    for (var i = 0; i < root.matchEvents.goals.length; i++) {
                      if (root.matchEvents.goals[i].isHome) list.push({ icon: "⚽", text: root.matchEvents.goals[i].player + " " + root.matchEvents.goals[i].minute })
                    }
                  }
                  if (root.matchEvents && root.matchEvents.redCards) {
                    for (var j = 0; j < root.matchEvents.redCards.length; j++) {
                      if (root.matchEvents.redCards[j].isHome) list.push({ icon: "🟥", text: root.matchEvents.redCards[j].player + " " + root.matchEvents.redCards[j].minute })
                    }
                  }
                  return list
                }

                delegate: Row {
                  required property var modelData
                  anchors.right: parent.right
                  spacing: Style.space(4)
                  Text {
                    text: modelData.text
                    color: theme.mutedColor(root.fgColor, 0.75)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                  Text {
                    text: modelData.icon
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            // Away Events
            Column {
              id: awayEvCol
              anchors.left: parent.horizontalCenter
              anchors.leftMargin: Style.space(8)
              anchors.right: parent.right
              spacing: Style.space(2)

              Repeater {
                model: {
                  var list2 = []
                  if (root.matchEvents && root.matchEvents.goals) {
                    for (var k = 0; k < root.matchEvents.goals.length; k++) {
                      if (!root.matchEvents.goals[k].isHome) list2.push({ icon: "⚽", text: root.matchEvents.goals[k].minute + " " + root.matchEvents.goals[k].player })
                    }
                  }
                  if (root.matchEvents && root.matchEvents.redCards) {
                    for (var l = 0; l < root.matchEvents.redCards.length; l++) {
                      if (!root.matchEvents.redCards[l].isHome) list2.push({ icon: "🟥", text: root.matchEvents.redCards[l].minute + " " + root.matchEvents.redCards[l].player })
                    }
                  }
                  return list2
                }

                delegate: Row {
                  required property var modelData
                  anchors.left: parent.left
                  spacing: Style.space(4)
                  Text {
                    text: modelData.icon
                    font.pixelSize: Style.font.caption
                  }
                  Text {
                    text: modelData.text
                    color: theme.mutedColor(root.fgColor, 0.75)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }
        }
      }

      // Key Stats Gauge (Possession & xG)
      Rectangle {
        id: statsCard
        visible: !root.isF1 && !root.scoreHidden && Boolean(root.matchStats) && Boolean(root.matchStats.possession)
        width: parent.width
        implicitHeight: statsCol.implicitHeight + Style.space(10)
        radius: theme.subtleRadius(4)
        color: theme.mutedColor(root.fgColor, 0.02)
        border.width: 1
        border.color: theme.mutedColor(root.fgColor, 0.06)

        Column {
          id: statsCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          Item {
            width: parent.width
            implicitHeight: possHomeLabel.implicitHeight

            Text {
              id: possHomeLabel
              anchors.left: parent.left
              text: (root.matchStats && root.matchStats.possession ? root.matchStats.possession[0] : "50") + "%"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              anchors.centerIn: parent
              text: {
                var parts = ["POSSESSION"]
                if (root.matchStats && root.matchStats.xG) {
                  parts.push("· xG " + root.matchStats.xG[0] + " – " + root.matchStats.xG[1])
                }
                return parts.join(" ")
              }
              color: theme.mutedColor(root.fgColor, 0.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              anchors.right: parent.right
              text: (root.matchStats && root.matchStats.possession ? root.matchStats.possession[1] : "50") + "%"
              color: theme.mutedColor(root.fgColor, 0.75)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          // Possession split bar
          Rectangle {
            width: parent.width
            height: Style.space(4)
            radius: Style.space(2)
            color: theme.mutedColor(root.fgColor, 0.12)
            clip: true

            Rectangle {
              height: parent.height
              width: parent.width * ((root.matchStats && root.matchStats.possession ? root.matchStats.possession[0] : 50) / 100.0)
              radius: Style.space(2)
              color: Color.accent
            }
          }
        }
      }

      // Game Top Performers / Leaders (US Sports)
      Rectangle {
        id: leadersCard
        visible: !root.isF1 && !root.scoreHidden && Boolean(root.gameLeaders && root.gameLeaders.length > 0)
        width: parent.width
        implicitHeight: leadersCol.implicitHeight + Style.space(10)
        radius: theme.subtleRadius(4)
        color: theme.mutedColor(root.fgColor, 0.025)
        border.width: 1
        border.color: theme.mutedColor(root.fgColor, 0.08)

        Column {
          id: leadersCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          Item {
            width: parent.width
            implicitHeight: leadersTitle.implicitHeight

            Text {
              id: leadersTitle
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "⭐ GAME LEADERS"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(12)

            Repeater {
              model: root.gameLeaders || []
              delegate: Column {
                required property var modelData
                spacing: Style.space(1)

                Text {
                  text: (modelData.category || "").toUpperCase()
                  color: theme.mutedColor(root.fgColor, 0.5)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Row {
                  spacing: Style.space(4)
                  Text {
                    text: modelData.player || ""
                    color: root.fgColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  Text {
                    text: modelData.displayValue || ""
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }
        }
      }

      // Linescore Box for US Sports (NBA/NFL quarters, NHL periods, MLB innings)
      Rectangle {
        id: spotlightLinescoreBox
        visible: !root.isF1 && !root.scoreHidden
          && Boolean(root.match && root.match.linescores)
          && Boolean(root.match.linescores.home && root.match.linescores.away)
          && (root.match.linescores.home.length > 0 || root.match.linescores.away.length > 0)
        width: parent.width
        implicitHeight: linescoreRow.implicitHeight + Style.space(10)
        radius: theme.subtleRadius(4)
        color: theme.mutedColor(root.fgColor, 0.025)
        border.width: 1
        border.color: theme.mutedColor(root.fgColor, 0.08)

        Row {
          id: linescoreRow
          anchors.centerIn: parent
          spacing: Style.space(12)

          Repeater {
            model: Math.max(
              (root.match && root.match.linescores && root.match.linescores.home ? root.match.linescores.home.length : 0),
              (root.match && root.match.linescores && root.match.linescores.away ? root.match.linescores.away.length : 0)
            )

            delegate: Column {
              required property int index
              spacing: Style.space(2)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                  var sport = root.match ? root.match.sport : ""
                  if (sport === "mlb") return String(index + 1)
                  if (sport === "nhl") return "P" + (index + 1)
                  if (index >= 4) return "OT" + (index > 4 ? String(index - 3) : "")
                  return "Q" + (index + 1)
                }
                color: theme.mutedColor(root.fgColor, 0.45)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(4)

                Text {
                  text: {
                    var hs = root.match && root.match.linescores && root.match.linescores.home
                    return (hs && hs[index] !== undefined && hs[index] !== null) ? String(hs[index]) : "–"
                  }
                  color: root.fgColor
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  text: "–"
                  color: theme.mutedColor(root.fgColor, 0.3)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: {
                    var as = root.match && root.match.linescores && root.match.linescores.away
                    return (as && as[index] !== undefined && as[index] !== null) ? String(as[index]) : "–"
                  }
                  color: theme.mutedColor(root.fgColor, 0.75)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
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
          text: root.isF1
            ? (root.match && root.match.winner
                ? ("🏆 Race Won by " + root.match.winner.driverName + " (" + root.match.winner.constructorName + ")")
                : (root.match && root.match.sessions && root.match.sessions.length > 0
                    ? ("🏁 Grand Prix Weekend · " + root.match.sessions.length + " Sessions")
                    : "🏁 FIA Formula 1 World Championship"))
            : ((root.matchSubline && root.matchSubline(root.match)) ? root.matchSubline(root.match) : (root.match && root.match.leagueName ? "🏆 " + root.match.leagueName : "Matchday Details"))
          color: theme.mutedColor(root.fgColor, 0.55)
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
