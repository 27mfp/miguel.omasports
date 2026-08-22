import QtQuick
import qs.Commons
import "SportsModel.js" as Model

// Broadcast-style live match card with pulsing clock pill, scorecard layout
// and game progression bar. Theme/state inputs are injected by Panel.qml.
Item {
  id: root

  required property var modelData

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

  // Provider minute ticked forward between polls (capped stoppage buffer)
  readonly property string syncedLiveTime:
    Model.interpolateLiveTime(root.modelData, root.nowMs, root.fetchedAtMs) || "LIVE"

  readonly property string leagueName: Model.leagueLabel(root.modelData.leagueId).toUpperCase()
  readonly property var details: root.matchDetails[String(root.modelData.id)] || null

  width: parent.width
  implicitHeight: liveCard.implicitHeight

  function mutedColor(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  Rectangle {
    id: liveCard
    width: parent.width
    implicitHeight: liveCol.implicitHeight + Style.space(22)
    radius: Math.min(8, Style.cornerRadius)
    Accessible.role: Accessible.ListItem
    Accessible.name: {
      var h = (root.modelData.home && (root.modelData.home.name || root.modelData.home.shortName)) || ""
      var a = (root.modelData.away && (root.modelData.away.name || root.modelData.away.shortName)) || ""
      return h + " versus " + a + ", live, " + (root.modelData.scoreText || "") + ", " + root.syncedLiveTime
    }
    color: liveMouse.containsMouse
      ? Style.hoverFillFor(root.fgColor, root.urgentColor)
      : Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.05)
    Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

    border.width: root.rowFocused ? 2 : 1
    border.color: liveMouse.containsMouse
      ? root.urgentColor
      : (root.rowFocused ? root.urgentColor : Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.3))

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(4)
      width: Style.space(4)
      radius: width / 2
      color: root.urgentColor

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
      anchors.leftMargin: Style.space(16)
      anchors.rightMargin: Style.space(16)
      spacing: Style.space(8)

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
            visible: root.modelData.round !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: "· " + root.modelData.round
            color: root.mutedColor(root.fgColor, 0.45)
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
          radius: Math.min(4, Style.cornerRadius)
          color: root.urgentColor

          Row {
            id: liveTimeRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Rectangle {
              width: Style.space(5)
              height: width
              radius: width / 2
              color: "#ffffff"
              anchors.verticalCenter: parent.verticalCenter

              SequentialAnimation on opacity {
                running: root.listVisible
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
              }
            }

            Text {
              text: root.syncedLiveTime
              color: "#ffffff"
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
            text: root.modelData.home.name || root.modelData.home.shortName
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.title
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
          radius: Math.min(5, Style.cornerRadius)
          color: Util.alpha(root.urgentColor, 0.2)
          border.width: 1
          border.color: root.urgentColor

          Text {
            anchors.centerIn: parent
            text: root.modelData.scoreText || "0–0"
            color: root.urgentColor
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
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
            text: root.modelData.away.name || root.modelData.away.shortName
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.title
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
        color: Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.18)
        clip: true

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: {
            var lt = String(root.syncedLiveTime)
            var m = parseInt(lt, 10)
            if (!isNaN(m)) return Math.min(parent.width, Math.max(6, (m / 90) * parent.width))
            if (lt.indexOf("HT") !== -1) return parent.width * 0.50
            if (lt.indexOf("Q1") !== -1 || lt.indexOf("1st") !== -1) return parent.width * 0.25
            if (lt.indexOf("Q2") !== -1 || lt.indexOf("2nd") !== -1) return parent.width * 0.50
            if (lt.indexOf("Q3") !== -1 || lt.indexOf("3rd") !== -1) return parent.width * 0.75
            if (lt.indexOf("Q4") !== -1 || lt.indexOf("4th") !== -1) return parent.width * 0.95
            return parent.width * 0.60
          }
          radius: 1.5
          color: root.urgentColor
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)
        visible: root.details && root.details.halftimeScore && String(root.details.halftimeScore) !== "undefined" && String(root.details.halftimeScore).trim() !== ""

        Text {
          text: "HT " + (root.details ? root.details.halftimeScore : "")
          color: root.mutedColor(root.fgColor, 0.55)
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
          text: root.matchSubline(root.modelData) || "Live match in progress"
          color: root.mutedColor(root.fgColor, 0.55)
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
    onClicked: root.openMatch(root.modelData)
  }
}
