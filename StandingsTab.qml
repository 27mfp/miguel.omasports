import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root

  required property var controller

  readonly property color fgColor: controller.fgColor
  readonly property color urgentColor: controller.urgentColor

  readonly property alias standingsPicker: standingsPicker
  readonly property bool anyPopupOpen: standingsPicker ? standingsPicker.popupOpen : false
  function toggleStandings() { if (standingsPicker) standingsPicker.toggle() }

  Theme { id: theme }

  function tableHeaderColor() {
    return theme.mutedColor(root.fgColor, 0.6)
  }

  function tableFont() {
    return Qt.font({
      family: Style.font.family,
      pixelSize: Style.font.caption,
      letterSpacing: 0.8,
      bold: true
    })
  }

  width: parent.width
  spacing: Style.space(10)
  visible: controller.tabIndex === 2

  Item {
    width: parent.width
    implicitHeight: Math.max(tableTitle.implicitHeight, standingsScope.implicitHeight)

    Text {
      id: tableTitle
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: controller.activeSportMeta.label.toUpperCase() + " STANDINGS"
      color: theme.mutedColor(root.fgColor, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    FocusScope {
      id: standingsScope
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(230)
      height: standingsPicker.implicitHeight
      visible: controller.standingsOptions.length > 1

      Dropdown {
        id: standingsPicker
        anchors.fill: parent
        label: ""
        showLabel: false
        value: controller.standingsLeagueId
        options: controller.standingsOptions
        hasCursor: controller.focusSection === controller.sectionIndex("standings")
        foreground: root.fgColor
        background: Color.popups.background
        onChanged: function(value) { controller.setStandingsLeague(value) }
      }
    }
  }

  // Empty state card
  Rectangle {
    width: parent.width
    implicitHeight: noStandingsCol.implicitHeight + Style.space(24)
    visible: controller.standingsRows.length === 0 && !controller.loading
    radius: Style.cornerRadius
    color: theme.mutedColor(root.fgColor, 0.03)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: noStandingsCol
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
            text: "📊"
            font.pixelSize: Style.font.heading
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: controller.hasData
          ? "No standings available for " + controller.activeSportMeta.label + "."
          : "No standings loaded yet — press R or click Refresh."
        color: theme.mutedColor(root.fgColor, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width
      }
    }
  }

  // Table Card Container
  Rectangle {
    width: parent.width
    implicitHeight: tableCardCol.implicitHeight + Style.space(16)
    visible: controller.standingsRows.length > 0
    radius: Style.cornerRadius
    color: theme.mutedColor(root.fgColor, 0.02)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: tableCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(8)
      spacing: Style.space(2)

      // Table Header adapted by Sport
      Item {
        width: parent.width
        implicitHeight: Style.space(20)

        // Football Header
        Row {
          visible: controller.activeSport === "football"
          width: parent.width
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: parent.width - Style.space(216); text: "CLUB"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "P"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "W"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "D"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "L"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(32); text: "DIFF"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(32); text: "PTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }

        // NBA / MLB Header (W, L, PCT, DIFF, GB)
        Row {
          visible: controller.activeSport === "nba" || controller.activeSport === "mlb"
          width: parent.width
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: parent.width - Style.space(190); text: "TEAM"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(28); text: "W"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(28); text: "L"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(36); text: "PCT"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(34); text: "DIFF"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(36); text: "GB"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }

        // NHL Header (W, L, OTL, DIFF, PTS)
        Row {
          visible: controller.activeSport === "nhl"
          width: parent.width
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: parent.width - Style.space(190); text: "TEAM"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(28); text: "W"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(28); text: "L"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(36); text: "OTL"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(34); text: "DIFF"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(36); text: "PTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }

        // NFL Header (W, L, T, PCT, DIFF)
        Row {
          visible: controller.activeSport === "nfl"
          width: parent.width
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: parent.width - Style.space(182); text: "TEAM"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "W"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "L"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "T"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(38); text: "PCT"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(38); text: "DIFF"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }

        // F1 Drivers Header
        Row {
          visible: controller.activeSport === "f1" && (controller.standingsLeagueId === "Drivers" || controller.standingsLeagueId === "" || controller.standingsLeagueId.indexOf("Construct") === -1)
          width: parent.width
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: Style.space(190); text: "DRIVER"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: parent.width - Style.space(330); text: "CONSTRUCTOR"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(42); text: "WINS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(65); text: "PTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }

        // F1 Constructors Header
        Row {
          visible: controller.activeSport === "f1" && (controller.standingsLeagueId === "Constructors" || controller.standingsLeagueId.indexOf("Construct") !== -1)
          width: parent.width
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: Style.space(180); text: "CONSTRUCTOR"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: parent.width - Style.space(320); text: "COUNTRY"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(42); text: "WINS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(65); text: "PTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: theme.mutedColor(root.fgColor, 0.08)
      }

      // Table Rows
      Column {
        width: parent.width
        spacing: 0

        Repeater {
          model: controller.standingsRows
          delegate: StandingsRow {
            activeSport: controller.activeSport
            standingsLeagueId: controller.standingsLeagueId
            selectedTeamIds: controller.selectedTeamIds
            selectedTeamName: controller.selectedTeamName
            fgColor: root.fgColor
            urgentColor: root.urgentColor
          }
        }
      }
    }
  }

  // Legend
  Row {
    visible: controller.standingsRows.length > 0
    spacing: Style.space(16)
    anchors.left: parent.left
    anchors.leftMargin: Style.space(4)

    Row {
      spacing: Style.space(5)
      Rectangle {
        width: Style.space(8)
        height: Style.space(8)
        radius: 2
        color: Color.accent
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: controller.activeSport === "f1" ? "Podium / P1" : "Playoffs / Europe"
        color: theme.mutedColor(root.fgColor, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Row {
      visible: controller.standingsHasPlayin
      spacing: Style.space(5)
      Rectangle {
        width: Style.space(8)
        height: Style.space(8)
        radius: 2
        color: Util.alpha(Color.accent, 0.08)
        border.width: 1
        border.color: Util.alpha(Color.accent, 0.35)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: controller.activeSport === "f1" ? "Podium places" : "Play-in"
        color: theme.mutedColor(root.fgColor, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Row {
      spacing: Style.space(5)
      Text {
        text: "★"
        color: Color.accent
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "Favorite"
        color: theme.mutedColor(root.fgColor, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Relegation/danger zones were previously encoded by red fill
    // alone — document the third zone so the encoding is readable
    Row {
      visible: controller.activeSport === "football"
      spacing: Style.space(5)
      Rectangle {
        width: Style.space(8)
        height: Style.space(8)
        radius: 2
        color: root.urgentColor
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "Relegation"
        color: theme.mutedColor(root.fgColor, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
