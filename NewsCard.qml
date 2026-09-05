import QtQuick
import qs.Commons
import qs.Ui

// Collapsible League Wire / Breaking News card displaying top stories
// from official sport feeds (ESPN/FotMob).
Rectangle {
  id: root

  Theme { id: theme }

  property color fgColor: Color.foreground
  property color urgentColor: Color.urgent
  property string activeSport: "football"
  property var articles: []
  property bool expanded: false
  property bool forceExpanded: false
  readonly property bool isExpanded: forceExpanded || expanded

  width: parent.width
  implicitHeight: contentCol.implicitHeight + Style.space(20)
  radius: Style.cornerRadius
  color: theme.mutedColor(root.fgColor, 0.035)
  border.width: 1
  border.color: theme.mutedColor(root.fgColor, 0.08)

  function formatTimeAgo(iso) {
    if (!iso) return ""
    var ms = Date.parse(iso)
    if (isNaN(ms)) return ""
    var diffSec = Math.floor((Date.now() - ms) / 1000)
    if (diffSec < 60) return "just now"
    var diffMin = Math.floor(diffSec / 60)
    if (diffMin < 60) return diffMin + "m ago"
    var diffHr = Math.floor(diffMin / 60)
    if (diffHr < 24) return diffHr + "h ago"
    var diffDays = Math.floor(diffHr / 24)
    return diffDays + "d ago"
  }

  Column {
    id: contentCol
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: Style.space(12)
    spacing: Style.space(10)

    // Header Row
    Item {
      width: parent.width
      implicitHeight: Math.max(headerLeft.implicitHeight, headerRight.implicitHeight)

      Row {
        id: headerLeft
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Rectangle {
          implicitWidth: wireTag.implicitWidth + Style.space(8)
          implicitHeight: wireTag.implicitHeight + Style.space(4)
          radius: theme.subtleRadius(3)
          color: Util.alpha(Color.accent, 0.18)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: wireTag
            anchors.centerIn: parent
            text: "LEAGUE WIRE"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.8
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: {
            if (root.activeSport === "football") return "Top Football Headlines"
            if (root.activeSport === "f1") return "Formula 1 Paddock News"
            if (root.activeSport === "nba") return "NBA Buzz & Coverage"
            if (root.activeSport === "nfl") return "NFL News & Updates"
            if (root.activeSport === "mlb") return "MLB Diamond Wire"
            if (root.activeSport === "nhl") return "NHL Puck Headlines"
            return "Headlines & News"
          }
          color: theme.mutedColor(root.fgColor, 0.65)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Row {
        id: headerRight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Rectangle {
          implicitWidth: countText.implicitWidth + Style.space(10)
          implicitHeight: countText.implicitHeight + Style.space(4)
          radius: theme.subtleRadius(4)
          color: theme.mutedColor(root.fgColor, 0.08)

          Text {
            id: countText
            anchors.centerIn: parent
            text: root.articles ? (root.articles.length + " Stories") : "0 Stories"
            color: theme.mutedColor(root.fgColor, 0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }
    }

    // Article List
    Column {
      width: parent.width
      spacing: Style.space(8)

      Repeater {
        model: root.articles ? (root.isExpanded ? root.articles : root.articles.slice(0, 2)) : []

        delegate: Rectangle {
          id: articleRow
          required property var modelData
          required property int index

          width: parent.width
          implicitHeight: articleCol.implicitHeight + Style.space(12)
          radius: theme.subtleRadius(4)
          color: articleMouse.containsMouse
            ? Style.hoverFillFor(root.fgColor, Color.accent)
            : theme.mutedColor(root.fgColor, 0.02)
          border.width: 1
          border.color: articleMouse.containsMouse
            ? Color.accent
            : theme.mutedColor(root.fgColor, 0.06)

          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }

          Column {
            id: articleCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(8)
            spacing: Style.space(3)

            Text {
              width: parent.width
              text: articleRow.modelData.headline || ""
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                visible: Boolean(articleRow.modelData.published)
                text: "⏱ " + root.formatTimeAgo(articleRow.modelData.published)
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                visible: Boolean(articleRow.modelData.description)
                width: parent.width - (parent.children[0].visible ? (parent.children[0].width + Style.space(6)) : 0) - Style.space(16)
                text: articleRow.modelData.description || ""
                color: theme.mutedColor(root.fgColor, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          MouseArea {
            id: articleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (articleRow.modelData.url) {
                Qt.openUrlExternally(articleRow.modelData.url)
              }
            }
          }
        }
      }
    }

    // Expand / Collapse Footer
    Item {
      visible: !root.forceExpanded && Boolean(root.articles && root.articles.length > 2)
      width: parent.width
      implicitHeight: expandBtn.implicitHeight

      Rectangle {
        id: expandBtn
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: expandRow.implicitWidth + Style.space(14)
        implicitHeight: expandRow.implicitHeight + Style.space(6)
        radius: theme.subtleRadius(4)
        color: expandMouse.containsMouse
          ? Util.alpha(Color.accent, 0.15)
          : theme.mutedColor(root.fgColor, 0.04)
        border.width: 1
        border.color: expandMouse.containsMouse
          ? Color.accent
          : theme.mutedColor(root.fgColor, 0.1)

        Row {
          id: expandRow
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: root.expanded ? "Show fewer stories 󰅃" : ("Show all " + root.articles.length + " stories 󰅀")
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        MouseArea {
          id: expandMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.expanded = !root.expanded
        }
      }
    }
  }
}
