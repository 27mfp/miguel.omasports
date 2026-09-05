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

  // ---- 1. Score & Match Notifications Card ------------------------
  Rectangle {
    width: parent.width
    implicitHeight: notifCardCol.implicitHeight + Style.space(24)
    radius: theme.subtleRadius(6)
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: notifCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(14)
      spacing: Style.space(10)

      Toggle {
        width: parent.width
        label: "Desktop Notifications"
        description: "Alerts for kickoff, goals, half-time, and final scores for followed teams"
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
            { icon: "⏱", label: "Half Time" },
            { icon: "🏁", label: "Full Time" }
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
            text: "libnotify (notify-send) is not installed. Desktop notifications are inactive."
            color: root.urgentColor
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: theme.mutedColor(root.fgColor, 0.06)
      }

      // Background Polling Toggle
      Toggle {
        width: parent.width
        label: "Background Polling"
        description: "Keep updating live scores and delivering goal notifications even when the panel is closed"
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
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: spoilerCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(14)
      spacing: Style.space(8)

      Toggle {
        width: parent.width
        label: "Anti-Spoiler Shield"
        description: "Conceal live and final scores until clicked or uncovered (Shortcut: S)"
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
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: barDisplayCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(14)
      spacing: Style.space(10)

      Toggle {
        width: parent.width
        label: "Live Score on Status Bar"
        description: "Display live match score ticker next to the icon on the Omarchy bar (e.g. ⚽ BEN 2-1 SPO 74')"
        checked: controller.showBarTicker
        accent: Color.accent
        foreground: root.fgColor
        onClicked: controller.toggleBarTicker()
      }

      Rectangle {
        width: parent.width
        height: 1
        color: theme.mutedColor(root.fgColor, 0.06)
      }

      Toggle {
        width: parent.width
        label: "Featured Match Spotlight Card"
        description: "Display the large featured match hero card at the top of the schedule tab"
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
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: wireCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(14)
      spacing: Style.space(8)

      Toggle {
        width: parent.width
        label: "League Wire & Breaking News"
        description: "Display top stories, paddock updates, and breaking headlines"
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
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: cadenceCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(14)
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
            text: "Live Refresh Cadence & Speed"
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            text: "Fastest safe delays tuned per provider to strictly avoid rate limits"
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
                text: "FotMob & F1"
                color: root.fgColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "· Cloudflare edge-safe"
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
              text: "20s delay"
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
                text: "ESPN (NBA, NFL, MLB, NHL)"
                color: root.fgColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "· Direct API"
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
              text: "15s delay"
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
            text: "Inactive Schedule Refresh"
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Text {
            width: parent.width
            text: "How often to check for schedule updates when no games are live"
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
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: favCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(14)
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
              text: "Followed Teams & Leagues"
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
          text: "Configure"
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
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: syncCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(14)
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
              text: "Maintenance & Diagnostics"
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              width: parent.width
              text: "Force a complete resync of all matches and standings data (Shortcut: R)"
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
          text: "Force Sync"
          iconText: "󰑐"
          iconSpinning: controller.loading
          foreground: root.fgColor
          onClicked: controller.forceRefresh()
        }
      }
    }
  }
}
