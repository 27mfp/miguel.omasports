import QtQuick
import qs.Commons
import qs.Ui
import "SportsModel.js" as Model

Column {
  id: root

  required property var controller

  readonly property color fgColor: controller.fgColor
  readonly property color urgentColor: controller.urgentColor

  readonly property alias leaguePicker: leaguePicker
  readonly property alias teamPicker: teamPicker
  readonly property bool anyPopupOpen: (leaguePicker && leaguePicker.popupOpen) || (teamPicker && teamPicker.popupOpen)
  function toggleLeagues() { if (leaguePicker) leaguePicker.toggle() }
  function toggleTeams() { if (teamPicker) teamPicker.toggle() }

  Theme { id: theme }

  property bool upcomingExpanded: false
  property bool recentExpanded: false
  property bool spotlightExpanded: false
  readonly property bool spotlightVisible: spotlightCard.visible

  function toggleRecent() { recentExpanded = !recentExpanded }
  function toggleSpotlightDetails() { spotlightExpanded = !spotlightExpanded }

  readonly property var liveGroup: {
    var groups = controller.matchGroups || []
    for (var i = 0; i < groups.length; i++) {
      if (groups[i].key === "live") return groups[i]
    }
    return null
  }
  readonly property var upcomingGroup: {
    var groups = controller.matchGroups || []
    for (var i = 0; i < groups.length; i++) {
      if (groups[i].key === "upcoming") return groups[i]
    }
    return null
  }
  readonly property var recentGroup: {
    var groups = controller.matchGroups || []
    for (var i = 0; i < groups.length; i++) {
      if (groups[i].key === "recent") return groups[i]
    }
    return null
  }

  readonly property int liveMatchesCount: liveGroup ? (liveGroup.matches || []).length : 0
  readonly property int upcomingMatchesCount: upcomingGroup ? (upcomingGroup.matches || []).length : 0
  readonly property int recentMatchesCount: recentGroup ? (recentGroup.matches || []).length : 0
  readonly property int newsArticlesCount: (controller.leagueNews && controller.showNewsWire) ? controller.leagueNews.length : 0
  readonly property int totalMatchesCount: upcomingMatchesCount + recentMatchesCount + liveMatchesCount

  readonly property var subSectionOptions: {
    var opts = [
      { key: "all", label: "All", count: totalMatchesCount, icon: "󰕘" },
      { key: "upcoming", label: "Upcoming", count: upcomingMatchesCount, icon: "󰸗" },
      { key: "recent", label: "Results", count: recentMatchesCount, icon: "󰈸" }
    ]
    if (controller.showNewsWire && newsArticlesCount > 0) {
      opts.push({ key: "news", label: "News", count: newsArticlesCount, icon: "󰋽" })
    }
    return opts
  }

  readonly property var filteredMatchGroups: {
    var sub = controller.scheduleSubSection || "all"
    if (sub === "news") return []
    if (sub === "recent") {
      return recentGroup ? [recentGroup] : []
    }
    if (sub === "upcoming") {
      var res = []
      if (liveGroup) res.push(liveGroup)
      if (upcomingGroup) res.push(upcomingGroup)
      return res
    }
    // "all"
    return controller.matchGroups || []
  }

  function moveSubSection(delta) {
    var options = root.subSectionOptions
    var current = 0
    for (var i = 0; i < options.length; i++) {
      if (options[i].key === controller.scheduleSubSection) current = i
    }
    controller.scheduleSubSection = options[(current + delta + options.length) % options.length].key
  }

  readonly property var visibleMatchGroups: filteredMatchGroups.map(function(group) {
    var matches = group.matches || []
    if (group.key === "upcoming" && controller.scheduleSubSection === "all" && !root.upcomingExpanded) matches = matches.slice(0, 6)
    if (group.key === "recent" && !root.recentExpanded) matches = matches.slice(0, 3)
    return { key: group.key, label: group.label, matches: matches }
  })

  width: parent.width
  spacing: Style.space(12)
  visible: controller.tabIndex === 0

  // ---- Streamlined Followed / Filter Quick Bar & Drawer ---------
  Item {
    id: setupSection
    width: parent.width
    implicitHeight: controller.setupExpanded ? setupDrawer.implicitHeight : compactChipBar.implicitHeight

    // A single summary leaves the emphasis on matches, with setup one click away.
    Item {
      id: compactChipBar
      width: parent.width
      implicitHeight: setupEditBtn.implicitHeight
      visible: !controller.setupExpanded

      Text {
        anchors.left: parent.left
        anchors.right: setupEditBtn.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        text: {
          var teams = controller.selectedTeamIds.length
          var leagues = controller.activeSport === "football" ? controller.selectedLeagueIds.length : 0
          if (teams === 0 && leagues === 0) return "Follow teams to personalise your schedule"
          var summary = teams === 1 ? controller.teamNameFor(controller.selectedTeamIds[0]) : teams + " followed"
          if (teams === 0) summary = "Following"
          if (leagues > 0) summary += " · " + leagues + (leagues === 1 ? " league" : " leagues")
          return "★ " + summary
        }
        color: theme.mutedColor(root.fgColor, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Button {
        id: setupEditBtn
        anchors.right: parent.right
        text: "Following"
        iconText: "󰒓"
        fontSize: Style.font.caption
        focusable: true
        hasCursor: controller.focusSection === controller.sectionIndex("setup")
        tooltipText: "Edit followed teams and leagues"
        Accessible.role: Accessible.Button
        Accessible.name: setupEditBtn.tooltipText
        foreground: root.fgColor
        accent: Color.accent
        onClicked: controller.setupExpanded = true
      }
    }

    // Expandable Full Setup Drawer
    Rectangle {
      id: setupDrawer
      width: parent.width
      implicitHeight: setupDrawerCol.implicitHeight + Style.space(16)
      visible: controller.setupExpanded
      radius: Style.cornerRadius
      color: theme.mutedColor(root.fgColor, 0.03)
      border.width: 1
      border.color: theme.mutedColor(root.fgColor, 0.12)

      Column {
        id: setupDrawerCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Style.space(12)
        spacing: Style.space(10)

        Item {
          width: parent.width
          implicitHeight: Math.max(drawerSecHeader.implicitHeight, drawerDoneBtn.implicitHeight)

          PanelSectionHeader {
            id: drawerSecHeader
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: (controller.activeSport === "f1"
              ? "FAVORITE DRIVER & PREFERENCES"
              : ("FOLLOWED " + controller.activeSportMeta.label.toUpperCase() + (controller.activeSport === "football" ? " & CLUBS" : " TEAMS")))
            foreground: root.fgColor
          }

          Button {
            id: drawerDoneBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Done"
            iconText: "󰅃"
            focusable: true
            hasCursor: controller.focusSection === controller.sectionIndex("setup")
            tooltipText: "Finish editing favorites"
            Accessible.role: Accessible.Button
            Accessible.name: drawerDoneBtn.tooltipText
            foreground: root.fgColor
            accent: Color.accent
            onClicked: controller.setupExpanded = false
          }
        }

        // League Picker (Football only)
        FocusScope {
          id: leagueScope
          width: parent.width
          height: leaguePicker.implicitHeight
          visible: controller.activeSport === "football"

          MultiSelect {
            id: leaguePicker
            anchors.fill: parent
            label: "Followed leagues (up to 12)"
            values: controller.selectedLeagueIds
            options: controller.sortedLeagueOptions
            placeholderText: "Search leagues (e.g. Premier, La Liga, Primeira)…"
            emptyText: "No leagues match"
            noSelectionText: "Select up to 12 followed leagues"
            popupRowHeight: Style.space(48)
            popupMinHeight: Style.space(180)
            hasCursor: controller.focusSection === controller.sectionIndex("leagues")
            foreground: root.fgColor
            background: Color.popups.background
            onChanged: function(values) { controller.setSelectedLeagues(values) }
          }
        }

        // Selected League Badges (Football only)
        Flow {
          width: parent.width
          spacing: Style.space(6)
          visible: controller.activeSport === "football" && controller.selectedLeagueIds.length > 0

          Repeater {
            model: controller.selectedLeagueIds

            delegate: Rectangle {
              required property var modelData
              required property int index

              implicitWidth: chipRow.implicitWidth + Style.space(14)
              implicitHeight: chipRow.implicitHeight + Style.space(6)
              radius: theme.subtleRadius(4)
              color: chipMouse.containsMouse
                ? Style.hoverFillFor(root.fgColor, root.urgentColor)
                : theme.mutedColor(root.fgColor, 0.06)
              border.width: 1
              border.color: chipMouse.containsMouse
                ? root.urgentColor
                : theme.mutedColor(root.fgColor, 0.14)

              Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Style.space(6)

                Text {
                  text: Model.leagueLabel(modelData)
                  color: root.fgColor
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  id: leagueChipX
                  text: "✕"
                  color: chipMouse.containsMouse ? root.urgentColor : theme.mutedColor(root.fgColor, 0.45)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: "Remove " + Model.leagueLabel(modelData)
                onClicked: {
                  var arr = Model.arrayFrom(controller.selectedLeagueIds)
                  var idx = arr.indexOf(String(modelData))
                  if (idx !== -1) {
                    arr.splice(idx, 1)
                    controller.setSelectedLeagues(arr)
                  }
                }
              }
            }
          }
        }

        // Team / Driver Picker
        Row {
          width: parent.width
          spacing: Style.space(8)

          FocusScope {
            id: teamScope
            width: controller.selectedTeamIds.length > 0 ? parent.width - clearButton.width - Style.space(8) : parent.width
            height: teamPicker.implicitHeight

            SearchableDropdown {
              id: teamPicker
              anchors.fill: parent
              label: controller.activeSport === "f1" ? "Follow Favorite Drivers / Teams" : "Follow Favorite Clubs / Teams"
              value: ""
              options: controller.combinedTeamOptions
              placeholderText: controller.activeSport === "f1" ? "Search driver or constructor to follow…" : "Search team to follow…"
              triggerLabel: controller.activeSport === "f1" ? "Add / select favorite driver" : "Add / select favorite team"
              emptyText: "No results match search"
              popupRowHeight: Style.space(48)
              popupMinHeight: Style.space(200)
              hasCursor: controller.focusSection === controller.sectionIndex("teams")
              foreground: root.fgColor
              background: Color.popups.background
              onChanged: function(value) { controller.toggleSelectedTeam(value) }
            }
          }

          Button {
            id: clearButton
            visible: controller.selectedTeamIds.length > 0
            text: ""
            iconText: "󰅖"
            bordered: true
            focusable: true
            hasCursor: controller.focusSection === controller.sectionIndex("clear")
            foreground: root.fgColor
            anchors.bottom: teamScope.bottom
            onClicked: controller.clearSelectedTeam()
          }
        }

        // Followed Favorite Team Badges
        Flow {
          width: parent.width
          spacing: Style.space(6)
          visible: controller.selectedTeamIds.length > 0

          Repeater {
            model: controller.selectedTeamIds

            delegate: Rectangle {
              required property var modelData
              required property int index

              implicitWidth: favTeamChipRow.implicitWidth + Style.space(14)
              implicitHeight: favTeamChipRow.implicitHeight + Style.space(6)
              radius: theme.subtleRadius(4)
              color: favChipMouse.containsMouse
                ? Style.hoverFillFor(root.fgColor, root.urgentColor)
                : Util.alpha(Color.accent, 0.12)
              border.width: 1
              border.color: favChipMouse.containsMouse
                ? root.urgentColor
                : Color.accent

              Row {
                id: favTeamChipRow
                anchors.centerIn: parent
                spacing: Style.space(6)

                Text {
                  text: "★ " + controller.teamNameFor(modelData)
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  text: "✕"
                  color: favChipMouse.containsMouse ? root.urgentColor : theme.mutedColor(root.fgColor, 0.45)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              MouseArea {
                id: favChipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: "Remove " + controller.teamNameFor(modelData)
                onClicked: controller.removeSelectedTeam(modelData)
              }
            }
          }
        }
      }
    }
  }

  // ---- Spotlight Featured Card ----------------------------------
  MatchSpotlight {
    id: spotlightCard
    detailsExpanded: root.spotlightExpanded
    detailsFocused: controller.focusSection === controller.sectionIndex("spotlightDetails")
    onToggleDetails: root.toggleSpotlightDetails()
    visible: controller.showSpotlight
      && (controller.scheduleSubSection === "all" || controller.scheduleSubSection === "upcoming" || !controller.scheduleSubSection)
      && controller.allMatches.length > 0 && (controller.featuredMatch !== null || fallbackMatch !== null)
    latestMatchesById: controller.latestMatchesById
    featuredMatch: controller.featuredMatch
    fallbackMatch: controller.allMatches.length > 0 ? Model.featuredMatchForTeam(controller.allMatches) : null
    isF1: controller.activeSport === "f1"
    activeSport: controller.activeSport
    fgColor: root.fgColor
    urgentColor: root.urgentColor
    selectedTeamIds: controller.selectedTeamIds
    selectedTeamName: controller.selectedTeamName
    antiSpoiler: controller.antiSpoiler
    revealedMatchIds: controller.revealedMatchIds
    favoriteDriverStanding: controller.favoriteDriverStanding
    broadcast: (controller.matchBroadcasts && (controller.featuredMatch || fallbackMatch)) ? controller.matchBroadcasts[String((controller.featuredMatch || fallbackMatch).id)] || "" : ""
    gameLeaders: (controller.matchLeaders && (controller.featuredMatch || fallbackMatch)) ? controller.matchLeaders[String((controller.featuredMatch || fallbackMatch).id)] || [] : []
    matchEvents: (controller.matchEvents && (controller.featuredMatch || fallbackMatch)) ? controller.matchEvents[String((controller.featuredMatch || fallbackMatch).id)] || null : null
    matchForm: (controller.matchForm && (controller.featuredMatch || fallbackMatch)) ? controller.matchForm[String((controller.featuredMatch || fallbackMatch).id)] || null : null
    matchStats: (controller.matchStats && (controller.featuredMatch || fallbackMatch)) ? controller.matchStats[String((controller.featuredMatch || fallbackMatch).id)] || null : null
    f1Podium: controller.f1Podium || []
    f1Pole: controller.f1Pole || null
    kickoffTime: controller.kickoffTime
    matchSubline: controller.matchSubline
    nowMs: controller.nowMs
    fetchedAtMs: controller.lastUpdated ? controller.lastUpdated.getTime() : Date.now()
    openMatch: controller.openMatch
    revealMatch: controller.revealMatch
    toggleRevealScore: controller.toggleRevealScore
    listVisible: controller.opened && controller.tabIndex === 0
    rowFocused: controller.focusSection === controller.sectionIndex("spotlight")
  }

  // ---- Schedule Header with Filter -----------------------------
  Item {
    width: parent.width
    implicitHeight: Math.max(schedTitle.implicitHeight, fixtureFilterScope.implicitHeight)
    visible: controller.hasData

    Text {
      id: schedTitle
      anchors.left: parent.left
      anchors.right: fixtureFilterScope.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      text: controller.activeFixtureHeader
      color: theme.mutedColor(root.fgColor, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    FocusScope {
      id: fixtureFilterScope
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(Style.space(250), parent.width * 0.62)
      height: fixtureFilterDropdown.implicitHeight
      visible: controller.fixtureFilterOptions.length > 1

      Dropdown {
        id: fixtureFilterDropdown
        anchors.fill: parent
        label: ""
        showLabel: false
        value: controller.fixtureFilterId
        options: controller.fixtureFilterOptions
        foreground: root.fgColor
        background: Color.popups.background
        onChanged: function(val) { controller.fixtureFilterId = String(val || "all") }
      }
    }
  }

  // ---- Sub-Section Navigation Bar (All / Upcoming / Results / News) ----
  Rectangle {
    id: subSectionBar
    width: parent.width
    implicitHeight: subSectionRow.implicitHeight + Style.space(8)
    visible: controller.hasData && (totalMatchesCount > 0 || newsArticlesCount > 0)
    radius: theme.subtleRadius(6)
    color: "transparent"
    border.width: 0

    Row {
      id: subSectionRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(4)
      spacing: Style.space(4)

      Repeater {
        model: root.subSectionOptions

        delegate: Rectangle {
          id: pillRect
          required property var modelData
          required property int index

          readonly property bool isSelected: (controller.scheduleSubSection || "all") === modelData.key
          readonly property bool keyboardFocused: isSelected && controller.focusSection === controller.sectionIndex("sections")
          Accessible.role: Accessible.PageTab
          Accessible.name: modelData.label + ", " + modelData.count
          Accessible.selected: isSelected
          Accessible.onPressAction: controller.scheduleSubSection = modelData.key
          activeFocusOnTab: true
          Keys.onReturnPressed: controller.scheduleSubSection = modelData.key
          Keys.onSpacePressed: controller.scheduleSubSection = modelData.key
          Keys.onLeftPressed: root.moveSubSection(-1)
          Keys.onRightPressed: root.moveSubSection(1)
          width: (subSectionRow.width - (root.subSectionOptions.length - 1) * Style.space(4)) / root.subSectionOptions.length
          implicitHeight: Style.space(30)
          radius: theme.subtleRadius(4)
          color: isSelected
            ? Util.alpha(Color.accent, 0.20)
            : (pillMouse.containsMouse ? theme.mutedColor(root.fgColor, 0.06) : "transparent")
          border.width: keyboardFocused || activeFocus ? 2 : 1
          border.color: keyboardFocused || activeFocus ? Color.accent : "transparent"

          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }

          Row {
            anchors.centerIn: parent
            spacing: Style.space(4)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.icon
              color: pillRect.isSelected ? Color.accent : theme.mutedColor(root.fgColor, 0.7)
              font.pixelSize: Style.font.caption
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: pillRect.isSelected ? Color.accent : theme.mutedColor(root.fgColor, 0.75)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: pillRect.isSelected
            }

            Rectangle {
              visible: modelData.count > 0
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: sectionCount.implicitWidth + Style.space(8)
              implicitHeight: sectionCount.implicitHeight + Style.space(2)
              radius: theme.subtleRadius(3)
              color: pillRect.isSelected ? Util.alpha(Color.accent, 0.15) : theme.mutedColor(root.fgColor, 0.07)

              Text {
                id: sectionCount
                anchors.centerIn: parent
                text: modelData.count
                color: pillRect.isSelected ? Color.accent : theme.mutedColor(root.fgColor, 0.65)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: controller.scheduleSubSection = modelData.key
          }
        }
      }
    }
  }

  // Dedicated News View (expanded directly under switcher)
  NewsCard {
    visible: controller.scheduleSubSection === "news" && Boolean(controller.leagueNews && controller.leagueNews.length > 0)
    fgColor: root.fgColor
    urgentColor: root.urgentColor
    activeSport: controller.activeSport
    articles: controller.leagueNews || []
    forceExpanded: true
  }

  // Empty State for News
  Rectangle {
    width: parent.width
    implicitHeight: noNewsCol.implicitHeight + Style.space(24)
    visible: controller.scheduleSubSection === "news" && root.newsArticlesCount === 0 && !controller.loading
    radius: Style.cornerRadius
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: noNewsCol
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No breaking headlines"
        color: root.fgColor
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No wire stories available right now for " + controller.activeSportMeta.label + "."
        color: theme.mutedColor(root.fgColor, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  // Empty State for Results
  Rectangle {
    width: parent.width
    implicitHeight: noResultsCol.implicitHeight + Style.space(24)
    visible: controller.scheduleSubSection === "recent" && root.recentMatchesCount === 0 && !controller.loading
    radius: Style.cornerRadius
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: noResultsCol
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No recent match results available"
        color: root.fgColor
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No completed matches recorded in the current filter window for " + controller.activeSportMeta.label + "."
        color: theme.mutedColor(root.fgColor, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  // Styled Empty State Card
  Rectangle {
    width: parent.width
    implicitHeight: emptyCardCol.implicitHeight + Style.space(32)
    visible: (controller.scheduleSubSection === "all" || controller.scheduleSubSection === "upcoming" || !controller.scheduleSubSection)
      && controller.activeFixturesList.length === 0 && !controller.loading
      && (controller.hasData || controller.fetchedOnce) && controller.errorMessage === ""
    radius: Style.cornerRadius
    color: theme.mutedColor(root.fgColor, 0.035)
    border.width: 1
    border.color: theme.mutedColor(root.fgColor, 0.08)

    Column {
      id: emptyCardCol
      anchors.centerIn: parent
      width: parent.width - Style.space(32)
      spacing: Style.space(8)

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(40)
        height: Style.space(40)
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

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No upcoming fixtures scheduled"
        color: root.fgColor
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No matches in the next days for " + controller.activeSportMeta.label + ". Use refresh (R) or switch selections."
        color: theme.mutedColor(root.fgColor, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width
      }
    }
  }

  // Inline error card
  Rectangle {
    width: parent.width
    implicitHeight: errorCol.implicitHeight + Style.space(16)
    visible: controller.errorMessage !== "" && !controller.loading
    radius: theme.subtleRadius(6)
    color: Util.alpha(root.urgentColor, 0.08)
    border.width: 1
    border.color: Util.alpha(root.urgentColor, 0.4)

    Column {
      id: errorCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(8)
      spacing: Style.space(8)

      Text {
        width: parent.width
        text: controller.errorMessage
        color: root.fgColor
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Row {
        spacing: Style.space(6)

        Button {
          text: "Retry"
          iconText: "󰑐"
          bordered: true
          foreground: root.fgColor
          onClicked: controller.forceRefresh()
        }
      }
    }
  }

  // First-load skeletons
  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: controller.loading && !controller.hasData

    Repeater {
      model: 4
      delegate: Rectangle {
        width: parent.width
        implicitHeight: Style.space(40)
        radius: theme.subtleRadius(6)
        color: theme.mutedColor(root.fgColor, 0.05)

        SequentialAnimation on opacity {
          running: controller.loading && !controller.hasData
          loops: Animation.Infinite
          NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
        }
      }
    }
  }

  // Match Groups Repeater
  Column {
    width: parent.width
    spacing: Style.space(12)
    visible: controller.scheduleSubSection !== "news"

    Repeater {
      model: root.visibleMatchGroups

      delegate: Column {
        id: groupDelegate
        required property var modelData
        required property int index

        readonly property int rowOffset: {
          var s = 0
          for (var g = 0; g < index; g++) {
            s += (root.visibleMatchGroups[g].matches || []).length
          }
          return s
        }
        width: parent.width
        spacing: Style.space(6)

        Item {
          width: parent.width
          visible: root.filteredMatchGroups.length > 1 || modelData.label !== "Upcoming Fixtures"
          implicitHeight: visible ? (groupLabel.implicitHeight + Style.space(4)) : 0

          Text {
            id: groupLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label.toUpperCase()
            color: modelData.label === "Live Matches" ? root.urgentColor : theme.mutedColor(root.fgColor, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.1
          }

          Rectangle {
            anchors.left: groupLabel.right
            anchors.leftMargin: Style.space(8)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: theme.mutedColor(root.fgColor, 0.08)
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: modelData.matches || []
            delegate: MatchRow {
              activeSport: controller.activeSport
              fgColor: root.fgColor
              urgentColor: root.urgentColor
              selectedTeamIds: controller.selectedTeamIds
              antiSpoiler: controller.antiSpoiler
              revealedMatchIds: controller.revealedMatchIds
              nowMs: controller.nowMs
              fetchedAtMs: controller.lastUpdated ? controller.lastUpdated.getTime() : Date.now()
              revealMatch: controller.revealMatch
              openMatch: controller.openMatch
              expandedIds: controller.f1ExpandedIds
              toggleExpand: controller.toggleF1Expand
              broadcast: (controller.matchBroadcasts && modelData) ? controller.matchBroadcasts[String(modelData.id)] || "" : ""
              matchEvents: (controller.matchEvents && modelData) ? controller.matchEvents[String(modelData.id)] || null : null
              listVisible: controller.opened && controller.tabIndex === 0
              rowFocused: controller.focusSection - controller.focusSections.length === groupDelegate.rowOffset + index
            }
          }

          Rectangle {
            visible: modelData.key === "recent" && root.recentMatchesCount > 3
            width: parent.width
            implicitHeight: Style.space(30)
            radius: theme.subtleRadius(4)
            color: recentMouse.containsMouse ? Style.hoverFillFor(root.fgColor, Color.accent) : theme.mutedColor(root.fgColor, 0.035)
            border.width: 1
            border.color: activeFocus || controller.focusSection === controller.sectionIndex("recentExpand") ? Color.accent : theme.mutedColor(root.fgColor, 0.12)
            Accessible.role: Accessible.Button
            Accessible.name: root.recentExpanded ? "Show fewer results" : "Show all loaded results"
            Accessible.onPressAction: root.toggleRecent()
            activeFocusOnTab: true
            Keys.onReturnPressed: root.toggleRecent()
            Keys.onSpacePressed: root.toggleRecent()
            Text {
              anchors.centerIn: parent
              text: root.recentExpanded ? "Show fewer results ▴" : "Show " + (root.recentMatchesCount - 3) + " more results ▾"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            MouseArea { id: recentMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleRecent() }
          }

          // "Show more upcoming fixtures" Accordion Expander
          Rectangle {
            Accessible.role: Accessible.Button
            Accessible.name: root.upcomingExpanded ? "Show fewer upcoming fixtures" : "Show all upcoming fixtures"
            Accessible.onPressAction: root.upcomingExpanded = !root.upcomingExpanded
            activeFocusOnTab: true
            Keys.onReturnPressed: root.upcomingExpanded = !root.upcomingExpanded
            Keys.onSpacePressed: root.upcomingExpanded = !root.upcomingExpanded
            visible: (controller.scheduleSubSection === "all" || !controller.scheduleSubSection)
              && modelData.key === "upcoming" && root.upcomingMatchesCount > 6
            width: parent.width
            implicitHeight: expandUpcomingRow.implicitHeight + Style.space(12)
            radius: theme.subtleRadius(4)
            color: expandUpcomingMouse.containsMouse
              ? Style.hoverFillFor(root.fgColor, Color.accent)
              : theme.mutedColor(root.fgColor, 0.035)
            border.width: 1
            border.color: expandUpcomingMouse.containsMouse || activeFocus || controller.focusSection === controller.sectionIndex("expand")
              ? Color.accent
              : theme.mutedColor(root.fgColor, 0.08)

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Row {
              id: expandUpcomingRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.upcomingExpanded ? "󰅃" : "󰅀"
                color: Color.accent
                font.pixelSize: Style.font.caption
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.upcomingExpanded
                  ? "Show fewer upcoming fixtures"
                  : ("Show " + (root.upcomingMatchesCount - 6) + " more upcoming fixtures")
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            MouseArea {
              id: expandUpcomingMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.upcomingExpanded = !root.upcomingExpanded
            }
          }
        }
      }
    }
  }

  // League Wire / Breaking News Card (shown at bottom in All mode)
  NewsCard {
    visible: (controller.scheduleSubSection === "all" || !controller.scheduleSubSection)
      && controller.showNewsWire && Boolean(controller.leagueNews && controller.leagueNews.length > 0)
    fgColor: root.fgColor
    urgentColor: root.urgentColor
    activeSport: controller.activeSport
    articles: controller.leagueNews || []
    forceExpanded: false
  }

  // Keep shortcuts after the content so fixtures remain the primary focus.
  Text {
    width: parent.width
    visible: controller.hasData
    text: controller.focusSection === controller.sectionIndex("sections")
      ? "← → change section · Enter next section"
      : "↑ ↓ navigate · Enter activate · R refresh · S spoiler shield"
    wrapMode: Text.WordWrap
    color: theme.mutedColor(root.fgColor, 0.65)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }

}
