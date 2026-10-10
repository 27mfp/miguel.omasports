import QtQuick
import qs.Commons
import qs.Ui
import "SportsModel.js" as Model

Item {
  id: root
  required property var controller
  readonly property color fgColor: controller.fgColor
  readonly property color urgentColor: controller.urgentColor
  readonly property bool anyPopupOpen: sportPicker.popupOpen
  readonly property alias sportPicker: sportPicker
  function toggleSport() { sportPicker.toggle() }
  Theme { id: theme }
  width: parent.width
  implicitHeight: headerCol.implicitHeight

  Column {
    id: headerCol
    width: parent.width
    spacing: Style.space(14)

    Item {
      width: parent.width
      implicitHeight: Math.max(headerLabels.implicitHeight, headerControls.implicitHeight)

      Row {
        id: headerLabels
        anchors.left: parent.left
        anchors.right: headerControls.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(10)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: controller.showingSettings ? "󰒓" : controller.activeSportIcon
          color: Color.accent
          font.pixelSize: Style.font.heading
        }

        Column {
          width: Math.max(0, headerLabels.width - Style.space(34))
          spacing: Style.space(3)

          Text {
            width: parent.width
            text: controller.showingSettings ? "Preferences" : "OmaSports"
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: controller.showingSettings ? "Make it your score center" : controller.statusText
            color: controller.errorMessage !== "" || controller.persistenceError !== "" || controller.dataStale
              ? root.urgentColor : theme.mutedColor(root.fgColor, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }

      Row {
        id: headerControls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        SelectionDropdown {
          id: sportPicker
          visible: !controller.showingSettings
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(150)
          label: ""
          showLabel: false
          selectedValue: controller.activeSport
          options: Model.sports()
          hasCursor: controller.focusSection === controller.sectionIndex("sports")
          Accessible.name: "Choose sport"
          foreground: root.fgColor
          background: Color.popups.background
          onChanged: function(value) { controller.switchSport(String(value)) }
        }

        Button {
          id: refreshButton
          visible: !controller.showingSettings
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰑐"
          iconSpinning: controller.loading
          focusable: !controller.showingSettings
          hasCursor: controller.focusSection === controller.sectionIndex("refresh")
          tooltipText: (controller.loading ? "Updating scores" : "Refresh scores") + " (R)"
          Accessible.role: Accessible.Button
          Accessible.name: refreshButton.tooltipText
          foreground: root.fgColor
          onClicked: controller.refresh()
        }

        Button {
          id: settingsButton
          anchors.verticalCenter: parent.verticalCenter
          text: controller.showingSettings ? "Done" : ""
          iconText: controller.showingSettings ? "󰄬" : "󰒓"
          selected: controller.showingSettings
          focusable: true
          hasCursor: controller.focusSection === controller.sectionIndex("settings")
          tooltipText: controller.showingSettings ? "Return to matches" : "Preferences"
          Accessible.role: Accessible.Button
          Accessible.name: settingsButton.tooltipText
          accent: Color.accent
          foreground: root.fgColor
          onClicked: controller.toggleSettingsTab()
        }
      }
    }

    Item {
      visible: !controller.showingSettings
      width: parent.width
      implicitHeight: Style.space(36)

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: theme.mutedColor(root.fgColor, 0.12)
      }

      Row {
        id: tabsGroup
        anchors.fill: parent
        spacing: Style.space(4)

        Repeater {
          model: controller.tabOptions
          delegate: Rectangle {
            id: tab
            required property var modelData
            required property int index
            readonly property bool selected: controller.tabIndex === index
            readonly property bool cursor: controller.focusSection === controller.sectionIndex("tabs") && selected && !controller.anyPopupOpen()
            width: (tabsGroup.width - (controller.tabOptions.length - 1) * tabsGroup.spacing) / controller.tabOptions.length
            height: tabsGroup.height
            radius: theme.subtleRadius(4)
            color: tabMouse.containsMouse ? Style.hoverFillFor(root.fgColor, Color.accent) : "transparent"
            border.width: cursor || activeFocus ? 1 : 0
            border.color: Color.accent
            Accessible.role: Accessible.PageTab
            Accessible.name: modelData.label
            Accessible.selected: selected
            Accessible.onPressAction: tab.selectTab()
            activeFocusOnTab: true
            Keys.onReturnPressed: selectTab()
            Keys.onSpacePressed: selectTab()

            function selectTab() {
              controller.tabIndex = index
              if (index === 2) {
                controller.ensureStandingsSelection()
                if (controller.standingsRows.length === 0 && !controller.loading) controller.refresh()
              }
            }

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Text {
                text: modelData.icon
                color: tab.selected ? Color.accent : theme.mutedColor(root.fgColor, 0.6)
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: modelData.label
                color: tab.selected ? root.fgColor : theme.mutedColor(root.fgColor, 0.6)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: tab.selected
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: Style.space(2)
              visible: tab.selected
              color: Color.accent
            }

            MouseArea {
              id: tabMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: tab.selectTab()
            }
          }
        }
      }
    }
  }
}
