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
    return theme.mutedColor(root.fgColor, 0.75)
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
    // FocusScope has no implicit size; measure the dropdown it actually shows.
    implicitHeight: Math.max(tableTitle.implicitHeight, standingsScope.visible ? standingsScope.height : 0)

    Text {
      id: tableTitle
      anchors.left: parent.left
      anchors.right: standingsScope.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      text: controller.activeSport === "football" ? "LEAGUE TABLE"
        : (controller.activeSport === "f1" ? "CHAMPIONSHIP" : "PLAYOFF SEEDING")
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
      width: Math.min(Style.space(230), parent.width * 0.58)
      height: standingsPicker.implicitHeight
      visible: controller.standingsOptions.length > 1

      SelectionDropdown {
        id: standingsPicker
        anchors.fill: parent
        label: ""
        showLabel: false
        selectedValue: controller.standingsLeagueId
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
    color: "transparent"
    border.width: 0

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
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(8)
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(36); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: parent.width - Style.space(260); text: "CLUB"; color: root.tableHeaderColor(); font: root.tableFont() }
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
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(8)
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(36); text: "SEED"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: parent.width - Style.space(274); text: "TEAM"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(28); text: "W"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(28); text: "L"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(44); text: "PCT"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(50); text: "DIFF"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(40); text: "GB"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }

        // NHL Header (W, L, OTL, DIFF, PTS)
        Row {
          visible: controller.activeSport === "nhl"
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(8)
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(36); text: "SEED"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: parent.width - Style.space(274); text: "TEAM"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(28); text: "W"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(28); text: "L"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(44); text: "OTL"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(50); text: "DIFF"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(40); text: "PTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }

        // NFL Header (W, L, T, PCT, DIFF)
        Row {
          visible: controller.activeSport === "nfl"
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(8)
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(36); text: "SEED"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: parent.width - Style.space(256); text: "TEAM"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "W"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "L"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(26); text: "T"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(44); text: "PCT"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(50); text: "DIFF"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }

        // F1 Drivers Header
        Row {
          visible: controller.activeSport === "f1" && (controller.standingsLeagueId === "Drivers" || controller.standingsLeagueId === "" || controller.standingsLeagueId.indexOf("Construct") === -1)
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(8)
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(36); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: Style.space(180); text: "DRIVER"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: parent.width - Style.space(338); text: "CONSTRUCTOR"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(40); text: "WINS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: Style.space(50); text: "PTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
        }

        // F1 Constructors Header
        Row {
          visible: controller.activeSport === "f1" && (controller.standingsLeagueId === "Constructors" || controller.standingsLeagueId.indexOf("Construct") !== -1)
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(8)
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(6)

          Text { width: Style.space(36); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
          Text { width: Style.space(180); text: "CONSTRUCTOR"; color: root.tableHeaderColor(); font: root.tableFont() }
          Text { width: parent.width - Style.space(355); text: "COUNTRY"; color: root.tableHeaderColor(); font: root.tableFont() }
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

  // Only explain zones present in this table, using the same semantic colours.
  Flow {
    width: parent.width
    spacing: Style.space(16)
    visible: controller.standingsRows.length > 0

    Repeater {
      model: {
        var zones = {}
        for (var i = 0; i < controller.standingsRows.length; i++)
          zones[controller.standingsRows[i].zone] = true
        var items = []
        if (zones.europe) items.push({ label: controller.activeSport === "f1" ? "Championship leader"
          : (controller.activeSport === "football" ? "European places" : "Playoff places"), color: theme.zoneColor })
        if (zones.playin) items.push({ label: controller.activeSport === "f1" ? "2nd–3rd"
          : "Play-in", color: theme.warningColor })
        if (zones.relegation) items.push({ label: "Relegation", color: theme.negativeColor })
        return items
      }
      delegate: Row {
        required property var modelData
        spacing: Style.space(5)
        Rectangle {
          width: Style.space(8)
          height: width
          radius: 2
          color: modelData.color
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: modelData.label
          color: theme.mutedColor(root.fgColor, 0.75)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }

    Text {
      text: "★ Favorite"
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
}
