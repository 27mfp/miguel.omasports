import QtQuick
import qs.Commons
import "SportsModel.js" as Model

// Broadcast-style live match card with pulsing clock pill, scorecard layout
// and game progression bar. Theme/state inputs are injected by Panel.qml.
Item {
  id: root
  Theme { id: theme }

  required property var modelData
  required property int index

  property string activeSport: "football"
  property string activeSportIcon: "⚽"
  property color fgColor
  property color urgentColor
  property var matchDetails: ({})
  property var matchSubline: null // function(match)
  property var openMatch: null // function(match)
  property double nowMs: Date.now()      // ticking clock from Panel for interpolation
  property double fetchedAtMs: -1        // when the provider data was fetched
  // False while the Live tab is hidden — infinite animations must not drive
  // scene-graph updates for content the user cannot see
  property bool listVisible: true
  property bool rowFocused: false
  property bool antiSpoiler: false
  property var revealedMatchIds: ({})
  property var toggleRevealScore: null // function(matchId)
  property var selectedTeamIds: []
  readonly property bool isScoreRevealed: Boolean(root.revealedMatchIds && root.revealedMatchIds[String(root.modelData.id)])
  readonly property bool scoreHidden: root.antiSpoiler && !root.isScoreRevealed

  readonly property string favTeamId: Model.teamIdForMatch(root.modelData, root.selectedTeamIds)
  readonly property string favLiveState: Model.teamLiveState(root.modelData, root.favTeamId)
  readonly property int scoreHome: parseInt(root.modelData.homeScore, 10) || 0
  readonly property int scoreAway: parseInt(root.modelData.awayScore, 10) || 0
  readonly property bool homeLeading: !root.scoreHidden && scoreHome > scoreAway
  readonly property bool awayLeading: !root.scoreHidden && scoreAway > scoreHome
  readonly property bool isTied: !root.scoreHidden && scoreHome === scoreAway

  // Provider minute ticked forward between polls (capped stoppage buffer)
  readonly property string syncedLiveTime:
    Model.interpolateLiveTime(root.modelData, root.nowMs, root.fetchedAtMs) || "LIVE"

  readonly property string leagueName: Model.leagueLabel(root.modelData.leagueId).toUpperCase()
  readonly property var details: root.matchDetails[String(root.modelData.id)] || null
  readonly property string halfTimeText: {
    if (!root.details || !root.details.halftimeScore) return ""
    if (root.scoreHidden) return "••••"
    var s = String(root.details.halftimeScore).trim()
    if (!s || s === "undefined" || s === "null" || s.indexOf("undefined") !== -1 || !/\d/.test(s)) return ""
    return s
  }

  width: parent.width
  implicitHeight: liveCard.implicitHeight

  Rectangle {
    id: liveCard
    width: parent.width
    implicitHeight: liveCol.implicitHeight + Style.space(16)
    radius: theme.subtleRadius(8)
    Accessible.role: Accessible.Button
    Accessible.name: {
      var h = (root.modelData.home && (root.modelData.home.name || root.modelData.home.shortName)) || ""
      var a = (root.modelData.away && (root.modelData.away.name || root.modelData.away.shortName)) || ""
      return h + " versus " + a + ", live, " + (root.modelData.scoreText || "") + ", " + root.syncedLiveTime
    }
    color: liveMouse.containsMouse
      ? Style.hoverFillFor(root.fgColor, Color.accent)
      : (root.favLiveState === "leading"
         ? Util.alpha("#22c55e", 0.05)
         : (root.favLiveState === "trailing"
            ? Util.alpha("#ef4444", 0.05)
            : (root.favLiveState === "tied"
               ? Util.alpha("#f59e0b", 0.05)
               : theme.mutedColor(root.fgColor, 0.025))))
    Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

    border.width: (root.rowFocused || root.favLiveState !== "") ? 1.5 : 1
    border.color: liveMouse.containsMouse
      ? Color.accent
      : (root.rowFocused
         ? Color.accent
         : (root.favLiveState === "leading"
            ? Util.alpha("#22c55e", 0.35)
            : (root.favLiveState === "trailing"
               ? Util.alpha("#ef4444", 0.35)
               : (root.favLiveState === "tied"
                  ? Util.alpha("#f59e0b", 0.35)
                  : theme.mutedColor(root.fgColor, 0.08)))))

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(3)
      width: Style.space(3)
      radius: width / 2
      color: root.favLiveState === "leading"
        ? "#22c55e"
        : (root.favLiveState === "trailing"
           ? "#ef4444"
           : (root.favLiveState === "tied" ? "#f59e0b" : Color.accent))

      SequentialAnimation on opacity {
        running: root.listVisible
        loops: Animation.Infinite
        NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
      }
    }

    Column {
      id: liveCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(6)

      Item {
        id: liveTopRow
        width: parent.width
        implicitHeight: Math.max(liveLeagueText.implicitHeight, liveTimePill.implicitHeight)

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Text {
            text: root.activeSportIcon
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: liveLeagueText
            anchors.verticalCenter: parent.verticalCenter
            text: root.leagueName
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.9
          }

          Text {
            readonly property string roundStr: String(root.modelData && root.modelData.round || "").trim()
            visible: roundStr !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: /^\d+$/.test(roundStr) ? ("· Round " + roundStr) : ("· " + roundStr)
            color: theme.mutedColor(root.fgColor, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Text {
            readonly property string koTime: Model.formatKickoff(root.modelData && root.modelData.time)
            visible: koTime !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: "· Started " + koTime
            color: theme.mutedColor(root.fgColor, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Rectangle {
          id: liveTimePill
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: liveTimeRow.implicitWidth + Style.space(12)
          implicitHeight: liveTimeRow.implicitHeight + Style.space(4)
          radius: theme.subtleRadius(4)
          color: Util.alpha(root.urgentColor, 0.14)
          border.width: 1
          border.color: Util.alpha(root.urgentColor, 0.3)

          Row {
            id: liveTimeRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Rectangle {
              width: Style.space(5)
              height: width
              radius: width / 2
              color: root.urgentColor
              anchors.verticalCenter: parent.verticalCenter

              SequentialAnimation on opacity {
                running: root.listVisible
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
              }
            }

            Text {
              text: Model.cleanLiveTime(root.syncedLiveTime) || "LIVE"
              color: root.urgentColor
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }
      }

      Item {
        width: parent.width
        implicitHeight: Math.max(liveHomeBounding.implicitHeight, liveAwayBounding.implicitHeight, liveScorePill.implicitHeight)

        // Home Side (Left)
        Item {
          id: liveHomeBounding
          anchors.left: parent.left
          anchors.right: liveScorePill.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          implicitHeight: Math.max(liveHomeCrest.height, liveHomeText.implicitHeight)

          TeamCrest {
            id: liveHomeCrest
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            sport: root.modelData.sport || "football"
            teamId: root.modelData.home.id
            teamName: root.modelData.home.name
            abbr: root.modelData.home.abbr || ""
            source: root.modelData.home.logo || ""
            crestSize: Style.space(26)
          }

          Text {
            id: liveHomeText
            anchors.left: parent.left
            anchors.right: liveHomeCrest.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: {
              var n = (root.modelData.home && (root.modelData.home.name || root.modelData.home.shortName)) || ""
              var sn = (root.modelData.home && root.modelData.home.shortName) || ""
              return (n.length > 15 && sn) ? sn : n
            }
            color: root.favTeamId === String(root.modelData.home && root.modelData.home.id)
              ? Color.accent
              : (root.homeLeading ? root.fgColor : (root.awayLeading ? theme.mutedColor(root.fgColor, 0.6) : root.fgColor))
            font.family: Style.font.family
            font.pixelSize: text.length > 14 ? Style.font.body : Style.font.title
            font.bold: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
          }
        }

        // Center Score
        Rectangle {
          id: liveScorePill
          anchors.centerIn: parent
          width: Style.space(88)
          height: Style.space(32)
          radius: theme.subtleRadius(5)
          color: root.favLiveState === "leading"
            ? Util.alpha("#22c55e", 0.16)
            : (root.favLiveState === "trailing"
               ? Util.alpha("#ef4444", 0.16)
               : (root.favLiveState === "tied"
                  ? Util.alpha("#f59e0b", 0.16)
                  : theme.mutedColor(root.fgColor, 0.05)))
          border.width: root.favLiveState !== "" ? 1.5 : 1
          border.color: root.favLiveState === "leading"
            ? "#22c55e"
            : (root.favLiveState === "trailing"
               ? "#ef4444"
               : (root.favLiveState === "tied"
                  ? "#f59e0b"
                  : theme.mutedColor(root.fgColor, 0.14)))

          Text {
            anchors.centerIn: parent
            text: {
              if (root.scoreHidden) return "••••"
              var raw = String(root.modelData && root.modelData.scoreText || "")
              var m = raw.match(/^(\d+)\s*[-–:]\s*(\d+)$/)
              if (m) return m[1] + " – " + m[2]
              if (raw) return raw
              if (root.modelData && typeof root.modelData.homeScore === "number" && typeof root.modelData.awayScore === "number") {
                return root.modelData.homeScore + " – " + root.modelData.awayScore
              }
              return "0 – 0"
            }
            color: root.favLiveState === "leading"
              ? "#22c55e"
              : (root.favLiveState === "trailing"
                 ? "#ef4444"
                 : (root.favLiveState === "tied"
                    ? "#f59e0b"
                    : root.fgColor))
            font.family: Style.font.family
            font.pixelSize: root.scoreHidden ? Style.font.caption : Style.font.heading
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
              if (root.toggleRevealScore) root.toggleRevealScore(root.modelData.id)
            }
          }
        }

        // Away Side (Right)
        Item {
          id: liveAwayBounding
          anchors.left: liveScorePill.right
          anchors.leftMargin: Style.space(10)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          implicitHeight: Math.max(liveAwayCrest.height, liveAwayText.implicitHeight)

          TeamCrest {
            id: liveAwayCrest
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            sport: root.modelData.sport || "football"
            teamId: root.modelData.away.id
            teamName: root.modelData.away.name
            abbr: root.modelData.away.abbr || ""
            source: root.modelData.away.logo || ""
            crestSize: Style.space(26)
          }

          Text {
            id: liveAwayText
            anchors.left: liveAwayCrest.right
            anchors.leftMargin: Style.space(8)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: {
              var n = (root.modelData.away && (root.modelData.away.name || root.modelData.away.shortName)) || ""
              var sn = (root.modelData.away && root.modelData.away.shortName) || ""
              return (n.length > 15 && sn) ? sn : n
            }
            color: root.favTeamId === String(root.modelData.away && root.modelData.away.id)
              ? Color.accent
              : (root.awayLeading ? root.fgColor : (root.homeLeading ? theme.mutedColor(root.fgColor, 0.6) : root.fgColor))
            font.family: Style.font.family
            font.pixelSize: text.length > 14 ? Style.font.body : Style.font.title
            font.bold: true
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
          }
        }
      }

      // Live Game Progression Bar
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(88)
        height: 3
        radius: 1.5
        color: theme.mutedColor(root.fgColor, 0.08)
        clip: true

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: {
            // Strip the invisible LRM/RLM marks FotMob wraps its clocks in —
            // parseInt() rejects them, which used to pin football at the
            // generic 60% fallback forever
            var lt = String(root.syncedLiveTime).replace(/[\u200e\u200f\s]/g, "")
            var m = lt.match(/^(\d{1,3})(?:\+(\d{1,2}))?[\u2019\u2032']?$/)
            if (m) {
              var minute = parseInt(m[1], 10) + (m[2] ? parseInt(m[2], 10) : 0)
              return Math.min(parent.width, Math.max(6, (Math.min(minute, 90) / 90) * parent.width))
            }
            // Baseball innings: "Top 5th", "Bot 9th", "Middle 6th" → n/9
            var inn = lt.match(/(?:top|bot|middle|end)\D*?(\d)/i)
            if (inn) return Math.min(parent.width * 0.97, parent.width * (parseInt(inn[1], 10) / 9))
            if (lt.indexOf("HT") !== -1) return parent.width * 0.50
            if (lt.indexOf("Q1") !== -1 || lt.indexOf("1st") !== -1) return parent.width * 0.25
            if (lt.indexOf("Q2") !== -1 || lt.indexOf("2nd") !== -1) return parent.width * 0.50
            if (lt.indexOf("Q3") !== -1 || lt.indexOf("3rd") !== -1) return parent.width * 0.75
            if (lt.indexOf("Q4") !== -1 || lt.indexOf("4th") !== -1) return parent.width * 0.95
            if (lt.indexOf("OT") !== -1 || lt.indexOf("SO") !== -1 || lt.indexOf("EXTRA") !== -1) return parent.width * 0.98
            return parent.width * 0.60
          }
          radius: 1.5
          color: root.favLiveState === "leading"
            ? "#22c55e"
            : (root.favLiveState === "trailing"
               ? "#ef4444"
               : (root.favLiveState === "tied" ? "#f59e0b" : Color.accent))
        }
      }

      // Period-by-period lines (NBA/NFL quarters, NHL periods, MLB innings) —
      // already captured by the parser; hidden for sports without them
      Row {
        id: linescoreGrid
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)
        visible: root.activeSport !== "football"
          && Boolean(root.modelData.linescores)
          && Boolean(root.modelData.linescores.home)
          && Boolean(root.modelData.linescores.away)
          && (root.modelData.linescores.home.length > 0 || root.modelData.linescores.away.length > 0)

        readonly property var homeScores: (root.modelData.linescores && root.modelData.linescores.home) || []
        readonly property var awayScores: (root.modelData.linescores && root.modelData.linescores.away) || []
        readonly property int periodCount: Math.max(homeScores.length, awayScores.length)

        Repeater {
          model: linescoreGrid.periodCount

          delegate: Column {
            required property int index
            spacing: Style.space(2)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: {
                var s = linescoreGrid.homeScores[index]
                return (s === undefined || s === null) ? "–" : String(s)
              }
              color: theme.mutedColor(root.fgColor, 0.85)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: {
                var s = linescoreGrid.awayScores[index]
                return (s === undefined || s === null) ? "–" : String(s)
              }
              color: theme.mutedColor(root.fgColor, 0.70)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)
        visible: root.halfTimeText !== ""

        Text {
          text: "⏱ HT " + root.halfTimeText
          color: theme.mutedColor(root.fgColor, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Item {
        width: parent.width
        implicitHeight: Math.max(liveVenueText.implicitHeight, liveLinkText.implicitHeight)

        Text {
          id: liveVenueText
          anchors.left: parent.left
          anchors.right: liveLinkText.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: (root.matchSubline && root.matchSubline(root.modelData)) ? root.matchSubline(root.modelData) : "● Live in progress"
          color: theme.mutedColor(root.fgColor, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Text {
          id: liveLinkText
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
  }

  MouseArea {
    id: liveMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.openMatch) root.openMatch(root.modelData)
  }
}
