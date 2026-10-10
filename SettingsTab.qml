import QtQuick
import qs.Commons
import qs.Ui
import "SportsModel.js" as Model

Column {
  id: root

  required property var controller

  readonly property color fgColor: controller.fgColor
  readonly property color urgentColor: controller.urgentColor

  readonly property alias intervalPicker: settingsIntervalPicker
  readonly property bool anyPopupOpen: settingsIntervalPicker ? settingsIntervalPicker.popupOpen : false

  Theme { id: theme }

  width: parent.width
  spacing: Style.space(12)
  visible: controller.showingSettings

  component PreferenceToggle: Toggle {
    titleSize: Style.font.body
    borderSpec: activeFocus || hasCursor ? Border.controlSpec("focus", foreground, accent) : Border.none()
  }

  // ---- 1. Score & Match Notifications Card ------------------------
  Rectangle {
    width: parent.width
    implicitHeight: notifCardCol.implicitHeight + Style.space(24)
    radius: theme.subtleRadius(6)
    color: "transparent"
    border.width: 0

    Column {
      id: notifCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(8)
      spacing: Style.space(10)

      Text {
        text: "ALERTS & UPDATES"
        color: theme.mutedColor(root.fgColor, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }

      PreferenceToggle {
        width: parent.width
        label: "Desktop notifications"
        description: "Kickoff, goal, half-time and full-time alerts for teams you follow"
        checked: controller.enableNotifications
        enabled: controller.notificationToolAvailable
        accent: Color.accent
        foreground: root.fgColor
        onClicked: controller.toggleNotifications()
      }

      // Event Type Badges (active when notifications enabled)
      Row {
        spacing: Style.space(6)
        visible: controller.enableNotifications

        Repeater {
          model: [
            { icon: "⏰", label: "Kickoff (15m)" },
            { icon: "⚽", label: "Goals & Scores" },
            { icon: "⏱", label: "Half-time" },
            { icon: "🏁", label: "Full-time" }
          ]

          delegate: Rectangle {
            required property var modelData
            implicitWidth: eventBadgeRow.implicitWidth + Style.space(12)
            implicitHeight: Style.space(22)
            radius: theme.subtleRadius(4)
            color: Util.alpha(Color.accent, 0.12)
            border.width: 1
            border.color: Util.alpha(Color.accent, 0.3)

            Row {
              id: eventBadgeRow
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                text: modelData.icon
                font.pixelSize: Style.font.caption
              }
              Text {
                text: modelData.label
                color: root.fgColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }
      }

      // Notification tool unavailable warning
      Rectangle {
        visible: !controller.notificationToolAvailable
        width: parent.width
        implicitHeight: warnRow.implicitHeight + Style.space(10)
        radius: theme.subtleRadius(4)
        color: Util.alpha(root.urgentColor, 0.1)
        border.width: 1
        border.color: Util.alpha(root.urgentColor, 0.4)

        Row {
          id: warnRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(8)
          spacing: Style.space(6)

          Text {
            text: "⚠"
            color: root.urgentColor
            font.pixelSize: Style.font.caption
          }
          Text {
            width: parent.width - Style.space(24)
            text: "Install libnotify (notify-send) to receive desktop notifications."
            color: root.urgentColor
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }

      // Background Polling Toggle
      PreferenceToggle {
        width: parent.width
        label: "Update in the background"
        description: "Keep scores and alerts current while the panel is closed"
        checked: controller.backgroundUpdates
        accent: Color.accent
        foreground: root.fgColor
        onClicked: controller.toggleBackgroundUpdates()
      }
    }
  }

  // ---- 2. Anti-Spoiler Shield Card --------------------------------
  Rectangle {
    width: parent.width
    implicitHeight: spoilerCardCol.implicitHeight + Style.space(24)
    radius: theme.subtleRadius(6)
    color: "transparent"
    border.width: 0

    Column {
      id: spoilerCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: "SCORE PRIVACY"
        color: theme.mutedColor(root.fgColor, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }

      PreferenceToggle {
        width: parent.width
        label: "Hide scores"
        description: "Click a score to reveal it · press S to toggle"
        checked: controller.antiSpoiler
        accent: Color.accent
        foreground: root.fgColor
        onClicked: controller.toggleSpoiler()
      }
    }
  }

  // ---- 3. Bar & Display Options Card ------------------------------
  Rectangle {
    width: parent.width
    implicitHeight: barDisplayCol.implicitHeight + Style.space(24)
    radius: theme.subtleRadius(6)
    color: "transparent"
    border.width: 0

    Column {
      id: barDisplayCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(8)
      spacing: Style.space(10)

      Text {
        text: "DISPLAY"
        color: theme.mutedColor(root.fgColor, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }

      PreferenceToggle {
        width: parent.width
        label: "Bar ticker"
        description: "Show your followed team’s live score beside the bar icon"
        checked: controller.showBarTicker
        accent: Color.accent
        foreground: root.fgColor
        onClicked: controller.toggleBarTicker()
      }

      PreferenceToggle {
        width: parent.width
        label: "Match spotlight"
        description: "Highlight your next or live match above the schedule"
        checked: controller.showSpotlight
        accent: Color.accent
        foreground: root.fgColor
        onClicked: controller.toggleSpotlight()
      }
    }
  }

  // ---- 4. League Wire & Breaking News Card ------------------------
  Rectangle {
    width: parent.width
    implicitHeight: wireCardCol.implicitHeight + Style.space(24)
    radius: theme.subtleRadius(6)
    color: "transparent"
    border.width: 0

    Column {
      id: wireCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: "NEWS"
        color: theme.mutedColor(root.fgColor, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }

      PreferenceToggle {
        width: parent.width
        label: "League news"
        description: "Show top stories and breaking headlines for the current sport"
        checked: controller.showNewsWire
        accent: Color.accent
        foreground: root.fgColor
        onClicked: controller.toggleNewsWire()
      }
    }
  }

  // ---- 5. Live Updates & Polling Cadence Card ----------------------
  Rectangle {
    width: parent.width
    implicitHeight: cadenceCardCol.implicitHeight + Style.space(24)
    radius: theme.subtleRadius(6)
    color: "transparent"
    border.width: 0

    Column {
      id: cadenceCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(8)
      spacing: Style.space(12)

      // Header row
      Row {
        spacing: Style.space(10)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰑐"
          color: Color.accent
          font.pixelSize: Style.font.heading
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: "Update frequency"
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            text: "Live scores refresh within each provider’s rate limits"
            color: theme.mutedColor(root.fgColor, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      // Provider Rates Rows (Full-width, responsive, never cut off)
      Column {
        width: parent.width
        spacing: Style.space(6)

        // FotMob / F1 row
        Rectangle {
          width: parent.width
          implicitHeight: Style.space(34)
          radius: theme.subtleRadius(4)
          color: (controller.activeSport === "football" || controller.activeSport === "f1")
            ? Util.alpha(Color.accent, 0.15)
            : theme.mutedColor(root.fgColor, 0.03)
          border.width: 1
          border.color: (controller.activeSport === "football" || controller.activeSport === "f1")
            ? Color.accent
            : theme.mutedColor(root.fgColor, 0.08)

          Item {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)

            Row {
              anchors.left: parent.left
              anchors.right: fotmobSpeedLabel.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                text: "⚽ 🏎️"
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "FotMob & Jolpica"
                color: root.fgColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "· football, F1"
                color: theme.mutedColor(root.fgColor, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
              }
            }

            Text {
              id: fotmobSpeedLabel
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "every 20 s"
              color: (controller.activeSport === "football" || controller.activeSport === "f1") ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }

        // ESPN row
        Rectangle {
          width: parent.width
          implicitHeight: Style.space(34)
          radius: theme.subtleRadius(4)
          color: (controller.activeSport === "nba" || controller.activeSport === "nfl" || controller.activeSport === "mlb" || controller.activeSport === "nhl")
            ? Util.alpha(Color.accent, 0.15)
            : theme.mutedColor(root.fgColor, 0.03)
          border.width: 1
          border.color: (controller.activeSport === "nba" || controller.activeSport === "nfl" || controller.activeSport === "mlb" || controller.activeSport === "nhl")
            ? Color.accent
            : theme.mutedColor(root.fgColor, 0.08)

          Item {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)

            Row {
              anchors.left: parent.left
              anchors.right: espnSpeedLabel.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                text: "🏀 🏈 ⚾ 🏒"
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "ESPN"
                color: root.fgColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "· NBA, NFL, MLB, NHL"
                color: theme.mutedColor(root.fgColor, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
              }
            }

            Text {
              id: espnSpeedLabel
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "every 15 s"
              color: (controller.activeSport === "nba" || controller.activeSport === "nfl" || controller.activeSport === "mlb" || controller.activeSport === "nhl") ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: theme.mutedColor(root.fgColor, 0.06)
      }

      // Inactive Refresh Dropdown row
      Item {
        width: parent.width
        implicitHeight: Math.max(inactiveTextCol.implicitHeight, intervalPickerWrap.implicitHeight)

        Column {
          id: inactiveTextCol
          anchors.left: parent.left
          anchors.right: intervalPickerWrap.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: "Refresh when nothing is live"
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Text {
            width: parent.width
            text: "How often to check the schedule when no games are in progress"
            color: theme.mutedColor(root.fgColor, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        Item {
          id: intervalPickerWrap
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(96)
          height: Style.space(32)

          Dropdown {
            id: settingsIntervalPicker
            anchors.fill: parent
            showLabel: false
            value: controller.refreshIntervalLabel()
            options: controller.refreshIntervalOptions
            foreground: root.fgColor
            background: Color.popups.background
            onChanged: function(value) { controller.setRefreshMinutes(value) }
          }
        }
      }
    }
  }

  // ---- 6. Followed Teams & Leagues Card ----------------------------
  Rectangle {
    width: parent.width
    implicitHeight: favCardCol.implicitHeight + Style.space(24)
    radius: theme.subtleRadius(6)
    color: "transparent"
    border.width: 0

    Column {
      id: favCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(8)
      spacing: Style.space(8)

      Item {
        width: parent.width
        implicitHeight: Math.max(favRow.implicitHeight, manageFavBtn.implicitHeight)

        Row {
          id: favRow
          anchors.left: parent.left
          anchors.right: manageFavBtn.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "★"
            color: Color.accent
            font.pixelSize: Style.font.heading
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: favRow.width - Style.space(34)
            spacing: Style.space(2)

            Text {
              text: "Followed teams & leagues"
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              width: parent.width
              text: controller.selectedTeamIds.length > 0
                ? (controller.selectedTeamIds.length === 1
                    ? ("Following " + controller.teamNameFor(controller.selectedTeamIds[0]))
                    : ("Following " + controller.selectedTeamIds.length + " teams across sports"))
                : "No teams followed yet. Choose favorites to receive instant alerts."
              color: theme.mutedColor(root.fgColor, 0.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        Button {
          id: manageFavBtn
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "Edit"
          iconText: "󰒓"
          foreground: root.fgColor
          onClicked: {
            controller.showingSettings = false
            controller.tabIndex = 0
            controller.setupExpanded = true
          }
        }
      }
    }
  }

  // ---- 7. Resync & Maintenance Card --------------------------------
  Rectangle {
    width: parent.width
    implicitHeight: syncCardCol.implicitHeight + Style.space(24)
    radius: theme.subtleRadius(6)
    color: "transparent"
    border.width: 0

    Column {
      id: syncCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(8)
      spacing: Style.space(8)

      Item {
        width: parent.width
        implicitHeight: Math.max(syncRow.implicitHeight, forceSyncBtn.implicitHeight)

        Row {
          id: syncRow
          anchors.left: parent.left
          anchors.right: forceSyncBtn.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰝘"
            color: theme.mutedColor(root.fgColor, 0.6)
            font.pixelSize: Style.font.heading
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: syncRow.width - Style.space(34)
            spacing: Style.space(2)

            Text {
              text: "Data"
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              width: parent.width
              text: "Reload all matches and standings now (R)"
              color: theme.mutedColor(root.fgColor, 0.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        Button {
          id: forceSyncBtn
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "Refresh now"
          iconText: "󰑐"
          iconSpinning: controller.loading
          foreground: root.fgColor
          onClicked: controller.forceRefresh()
        }
      }
    }
  }
}
