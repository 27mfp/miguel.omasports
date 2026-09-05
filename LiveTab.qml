import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root

  required property var controller

  readonly property color fgColor: controller.fgColor
  readonly property color urgentColor: controller.urgentColor

  Theme { id: theme }

  width: parent.width
  spacing: Style.space(10)
  visible: controller.tabIndex === 1

  PanelSectionHeader {
    text: controller.liveCount > 0 ? "LIVE NOW · " + (controller.liveCount === 1 ? "1 MATCH" : controller.liveCount + " MATCHES") : "LIVE MATCHES"
    foreground: root.fgColor
  }

  // Empty state
  Rectangle {
    width: parent.width
    implicitHeight: noLiveCol.implicitHeight + Style.space(24)
    visible: controller.liveCount === 0
    radius: Style.cornerRadius
    color: theme.mutedColor(root.fgColor, 0.03)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: noLiveCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(16)
      spacing: Style.space(8)

      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(42)
        height: Style.space(42)

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: Util.alpha(Color.accent, 0.12)
          border.width: 1
          border.color: Util.alpha(Color.accent, 0.25)

          Text {
            anchors.centerIn: parent
            text: controller.activeSportIcon
            font.pixelSize: Style.font.heading
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: (controller.hasData || controller.fetchedOnce)
          ? "No live events in progress right now for " + controller.activeSportMeta.label + "."
          : "Load " + controller.activeSportMeta.label + " schedule to see live scores."
        color: theme.mutedColor(root.fgColor, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width
      }

      Rectangle {
        visible: controller.nextKickoffText !== ""
        width: parent.width
        implicitHeight: nextCol.implicitHeight + Style.space(12)
        radius: theme.subtleRadius(4)
        color: Util.alpha(Color.accent, 0.08)
        border.width: 1
        border.color: Util.alpha(Color.accent, 0.25)

        Column {
          id: nextCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(8)
          spacing: Style.space(2)

          Text {
            text: "NEXT UPCOMING EVENT"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            width: parent.width
            text: controller.nextKickoffText
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  // Live Match Cards
  Column {
    width: parent.width
    spacing: Style.space(10)

    Repeater {
      model: controller.liveList
      delegate: LiveRow {
        activeSport: controller.activeSport
        activeSportIcon: controller.activeSportIcon
        fgColor: root.fgColor
        urgentColor: root.urgentColor
        selectedTeamIds: controller.selectedTeamIds
        matchDetails: controller.matchDetails
        matchSubline: controller.matchSubline
        openMatch: controller.openMatch
        nowMs: controller.nowMs
        fetchedAtMs: controller.lastUpdated.getTime()
        listVisible: controller.opened && controller.tabIndex === 1
        rowFocused: controller.focusSection - controller.focusSections.length === index
        antiSpoiler: controller.antiSpoiler
        revealedMatchIds: controller.revealedMatchIds
        toggleRevealScore: controller.toggleRevealScore
      }
    }
  }
}
