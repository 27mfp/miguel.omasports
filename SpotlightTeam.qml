import QtQuick
import qs.Commons

// Mirrored team presentation on either side of the spotlight score.
Item {
  id: root
  Theme { id: theme }

  property var team: null
  property string sport: "football"
  property bool homeSide: true
  property string favoriteTeamId: ""
  property color fgColor
  property color urgentColor
  property bool detailsExpanded: false
  property var recentForm: []
  readonly property bool favorite: favoriteTeamId !== "" && team !== null
    && String(team.id) === String(favoriteTeamId)

  implicitHeight: Math.max(crest.height, labels.implicitHeight)

  TeamCrest {
    id: crest
    anchors.left: root.homeSide ? undefined : parent.left
    anchors.right: root.homeSide ? parent.right : undefined
    anchors.verticalCenter: parent.verticalCenter
    sport: root.sport
    teamId: root.team ? root.team.id : ""
    teamName: root.team ? root.team.name : ""
    abbr: root.team && root.team.abbr ? root.team.abbr : ""
    source: root.team && root.team.logo ? root.team.logo : ""
    crestSize: Style.space(36)
  }

  Column {
    id: labels
    anchors.left: root.homeSide ? parent.left : crest.right
    anchors.right: root.homeSide ? crest.left : parent.right
    anchors.leftMargin: root.homeSide ? 0 : Style.space(8)
    anchors.rightMargin: root.homeSide ? Style.space(8) : 0
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: root.team ? root.team.name || root.team.shortName : ""
      color: root.favorite ? Color.accent : root.fgColor
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
      horizontalAlignment: root.homeSide ? Text.AlignRight : Text.AlignLeft
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: root.team && root.team.record ? root.team.record
        : (root.homeSide ? "HOME" : "AWAY") + (root.favorite ? " · FAVORITE" : "")
      color: theme.mutedColor(root.fgColor, 0.45)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: root.homeSide ? Text.AlignRight : Text.AlignLeft
      elide: Text.ElideRight
    }

    Row {
      anchors.left: root.homeSide ? undefined : parent.left
      anchors.right: root.homeSide ? parent.right : undefined
      spacing: Style.space(3)
      visible: root.detailsExpanded && root.recentForm.length > 0
      Repeater {
        model: root.recentForm
        delegate: Rectangle {
          required property string modelData
          width: Style.space(12)
          height: Style.space(12)
          radius: Style.space(2)
          color: modelData === "W" ? theme.positiveColor
            : (modelData === "D" ? theme.mutedColor(root.fgColor, 0.25) : root.urgentColor)
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
