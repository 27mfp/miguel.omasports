import QtQuick
import qs.Commons
import qs.Ui
import "SportsModel.js" as Model

Item {
  id: root

  required property var controller

  readonly property color fgColor: controller.fgColor
  readonly property color urgentColor: controller.urgentColor

  readonly property bool anyPopupOpen: false
  function toggleInterval() {}

  Theme { id: theme }

  width: parent.width
  implicitHeight: headerCol.implicitHeight

  Column {
    id: headerCol
    width: parent.width
    spacing: Style.space(8)

    // ---- Top Header Row ---------------------------------------------
    Item {
      id: headerRow
      width: parent.width
      implicitHeight: Math.max(
        controller.showingSettings ? settingsHeaderLeft.implicitHeight : headerLeft.implicitHeight,
        headerControls.implicitHeight
      )

      // Matches Mode Header Title
      Row {
        id: headerLeft
        visible: !controller.showingSettings
        anchors.left: parent.left
        anchors.right: headerControls.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: controller.activeSportIcon
          font.pixelSize: Style.font.heading
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, headerLeft.width - Style.space(32))
          spacing: Style.space(1)

          Row {
            spacing: Style.space(6)

            Text {
              text: controller.activeSportMeta.label
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            // Inline live count indicator badge
            Rectangle {
              visible: controller.liveCount > 0
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: inlineLiveRow.implicitWidth + Style.space(10)
              implicitHeight: inlineLiveRow.implicitHeight + Style.space(3)
              radius: theme.subtleRadius(4)
              color: Util.alpha(root.urgentColor, 0.15)
              border.width: 1
              border.color: Util.alpha(root.urgentColor, 0.5)

              Row {
                id: inlineLiveRow
                anchors.centerIn: parent
                spacing: Style.space(4)

                Rectangle {
                  width: Style.space(5)
                  height: width
                  radius: width / 2
                  color: root.urgentColor
                  anchors.verticalCenter: parent.verticalCenter

                  SequentialAnimation on opacity {
                    running: controller.opened && controller.liveCount > 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                  }
                }

                Text {
                  text: controller.liveCount + " LIVE"
                  color: root.urgentColor
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.tabIndex = 1
              }
            }
          }

          Text {
            width: parent.width
            text: controller.statusText
            color: controller.errorMessage !== "" || controller.persistenceError !== "" || controller.dataStale
              ? root.urgentColor
              : theme.mutedColor(root.fgColor, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }

      // Settings Mode Header Title
      Row {
        id: settingsHeaderLeft
        visible: controller.showingSettings
        anchors.left: parent.left
        anchors.right: headerControls.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰒓"
          color: Color.accent
          font.pixelSize: Style.font.heading
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, settingsHeaderLeft.width - Style.space(32))
          spacing: Style.space(1)

          Text {
            text: "Preferences & Settings"
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: "Alerts, update speed, and display options"
            color: theme.mutedColor(root.fgColor, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }

      // Header Controls (Refresh & Settings)
      Row {
        id: headerControls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        // Refresh Button (hidden in settings mode)
        Button {
          id: refreshButton
          visible: !controller.showingSettings
          text: ""
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

        // Settings / Done Toggle Button
        Button {
          id: settingsButton
          text: controller.showingSettings ? "Done" : ""
          iconText: controller.showingSettings ? "󰄬" : "󰒓"
          selected: controller.showingSettings
          focusable: true
          hasCursor: controller.focusSection === controller.sectionIndex("settings")
          tooltipText: controller.showingSettings ? "Done (Return to matches)" : "Preferences & Settings"
          Accessible.role: Accessible.Button
          Accessible.name: settingsButton.tooltipText
          accent: Color.accent
          foreground: root.fgColor
          onClicked: controller.toggleSettingsTab()
        }
      }
    }

    // ---- Sport Selector Segmented Row (Hidden in Settings) ---------
    Rectangle {
      visible: !controller.showingSettings
      width: parent.width
      implicitHeight: Style.space(32)
      radius: theme.subtleRadius(6)
      color: theme.mutedColor(root.fgColor, 0.035)
      border.width: 1
      border.color: theme.mutedColor(root.fgColor, 0.08)

      Row {
        id: sportSelectorRow
        anchors.fill: parent
        anchors.margins: Style.space(3)
        spacing: Style.space(3)

        Repeater {
          model: Model.sports()

          delegate: Rectangle {
            required property var modelData
            required property int index

            Accessible.role: Accessible.Button
            Accessible.name: modelData.label + (controller.activeSport === modelData.value ? " (selected)" : "")
            width: (sportSelectorRow.width - (Model.sports().length - 1) * Style.space(3)) / Model.sports().length
            height: parent.height
            radius: theme.subtleRadius(4)
            color: controller.activeSport === modelData.value
              ? Util.alpha(Color.accent, 0.20)
              : (sportMouse.containsMouse ? theme.mutedColor(root.fgColor, 0.06) : "transparent")
            border.width: 1
            border.color: controller.activeSport === modelData.value
              ? Color.accent
              : (sportMouse.containsMouse ? theme.mutedColor(root.fgColor, 0.10) : "transparent")

            Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Text {
              anchors.centerIn: parent
              text: modelData.icon
              font.pixelSize: Style.font.title
            }

            MouseArea {
              id: sportMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: controller.switchSport(modelData.value)
            }
          }
        }
      }
    }

    // ---- Tab Navigation Row (Hidden in Settings) --------------------
    Item {
      id: tabsContainer
      visible: !controller.showingSettings
      width: parent.width
      implicitHeight: tabsGroup.implicitHeight

      Row {
        id: tabsGroup
        anchors.left: parent.left
        spacing: Style.space(6)

        Repeater {
          model: controller.tabOptions

          delegate: Button {
            required property var modelData
            required property int index

            text: modelData.label
            iconText: modelData.icon
            selected: controller.tabIndex === index
            hasCursor: controller.focusSection === controller.sectionIndex("tabs") && controller.tabIndex === index && !controller.anyPopupOpen()
            foreground: root.fgColor
            accent: Color.accent
            onClicked: {
              controller.tabIndex = index
              if (index === 2) {
                controller.ensureStandingsSelection()
                if (controller.standingsRows.length === 0 && !controller.loading) controller.refresh()
              }
            }
          }
        }
      }
    }

    PanelSeparator { foreground: root.fgColor }
  }
}
