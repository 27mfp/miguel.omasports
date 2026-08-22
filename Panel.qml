import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "SportsModel.js" as Model

Panel {
  id: root
  moduleName: "miguel.matchday"
  ipcTarget: "miguel.matchday"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel, so popout coordination and switchPanelFrom must identify
  // the host widget (same contract as omarchy.weather).
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Theme colors
  readonly property color fgColor: root.bar && root.bar.barForeground ? root.bar.barForeground : Color.foreground
  readonly property color bgColor: Color.background
  readonly property color urgentColor: root.bar && root.bar.urgent ? root.bar.urgent : Color.urgent

  // Optional background polling
  readonly property bool backgroundUpdates: setting("backgroundUpdates", false) === true

  // ---- Active Sport & Saved State ---------------------------------------
  property string activeSport: "football"
  readonly property var activeSportMeta: Model.sportMeta(activeSport)
  readonly property string activeSportIcon: activeSportMeta.icon

  property var savedState: Model.defaultState()
  property bool stateLoaded: false
  // Snapshot of the last state we wrote ourselves, so our own FileView writes
  // can be distinguished from external edits (which trigger a fresh round)
  property string ignoredStateSignature: ""
  property var selectedLeagueIds: ["47"]
  property var selectedTeamIds: []
  property string selectedTeamId: ""
  property string standingsLeagueId: "47"
  property bool antiSpoiler: false
  property bool enableNotifications: true
  property var revealedMatchIds: ({})
  property var lastSeenMatches: ({})

  // Match and standings storage
  property var allMatches: []
  property var teamMatchesRaw: []
  property var teamOptions: []
  property bool loading: false
  property string errorMessage: ""
  property var failedLeagues: []
  property date lastUpdated: new Date(0)
  property bool loadedFromCache: false

  // Standings data
  property var lastPages: []
  property var multiSportStandings: ({})

  // Per-match enrichment for football
  property var matchDetails: ({})
  property var detailQueue: []

  readonly property bool hasData: allMatches.length > 0
  readonly property var baseTeamOptions: Model.teamOptionsForSport(activeSport, allMatches)

  function teamNameFor(id) {
    var str = String(id || "").toLowerCase()
    if (!str) return ""
    for (var i = 0; i < baseTeamOptions.length; i++) {
      if (String(baseTeamOptions[i].value).toLowerCase() === str) return baseTeamOptions[i].label
    }
    for (var j = 0; j < allMatches.length; j++) {
      var m = allMatches[j]
      if (m && m.home && String(m.home.id).toLowerCase() === str) return m.home.name
      if (m && m.away && String(m.away.id).toLowerCase() === str) return m.away.name
    }
    return String(id)
  }

  // Combined team options ensuring saved favorites are always present and searchable
  readonly property var combinedTeamOptions: {
    var base = Model.arrayFrom(baseTeamOptions)
    var ids = Model.arrayFrom(selectedTeamIds)
    var seen = {}
    for (var b = 0; b < base.length; b++) seen[String(base[b].value).toLowerCase()] = true

    for (var k = 0; k < ids.length; k++) {
      var curId = String(ids[k]).toLowerCase()
      if (!seen[curId]) {
        seen[curId] = true
        base.unshift({ value: ids[k], label: root.teamNameFor(ids[k]), description: "Saved favorite" })
      }
    }
    return base
  }

  // ---- Fixtures League / Matchday / Team Filter --------------------------
  property string fixtureFilterId: activeSport === "f1" ? "all" : (selectedTeamIds.length > 0 ? "team" : "all")

  readonly property var fixtureFilterOptions: {
    var opts = []
    if (activeSport === "f1") {
      opts.push({ value: "all", label: "🏁 2026 Grand Prix Calendar" })
      if (selectedTeamIds.length > 0) {
        opts.push({ value: "team", label: "★ " + (root.teamNameFor(selectedTeamIds[0]) || "My Favorite Driver") })
      }
      return opts
    }

    if (selectedTeamIds.length > 0) {
      if (selectedTeamIds.length === 1) {
        opts.push({ value: "team", label: "★ " + root.teamNameFor(selectedTeamIds[0]) })
      } else {
        opts.push({ value: "team", label: "★ All Followed Favorites (" + selectedTeamIds.length + ")" })
        for (var f = 0; f < selectedTeamIds.length; f++) {
          opts.push({ value: "fav_" + selectedTeamIds[f], label: "★ " + root.teamNameFor(selectedTeamIds[f]) })
        }
      }
    }
    opts.push({ value: "all", label: "🏆 All " + activeSportMeta.label })
    if (activeSport === "football") {
      var ids = Model.arrayFrom(selectedLeagueIds)
      for (var i = 0; i < ids.length; i++) {
        opts.push({ value: String(ids[i]), label: Model.leagueLabel(ids[i]) })
      }
    }
    return opts
  }

  readonly property var activeFixturesList: {
    if (activeSport === "f1") return allMatches
    if (fixtureFilterId === "team" && selectedTeamIds.length > 0) {
      return teamMatches
    }
    if (fixtureFilterId.indexOf("fav_") === 0) {
      return Model.matchesForTeam(allMatches, fixtureFilterId.slice(4), activeSport)
    }
    if (fixtureFilterId === "all") {
      return allMatches
    }
    return Model.matchesForLeague(allMatches, fixtureFilterId)
  }

  readonly property var matchGroups: Model.groupMatches(activeFixturesList, new Date(), function(d) { return Qt.formatDate(d, "ddd d MMM") })

  readonly property string activeFixtureHeader: {
    if (activeSport === "f1") return "FIA FORMULA 1 WORLD CHAMPIONSHIP · CALENDAR"
    if (fixtureFilterId === "team" && selectedTeamId !== "") return "MATCH SCHEDULE"
    if (fixtureFilterId === "all") return "ALL " + activeSportMeta.label.toUpperCase() + " FIXTURES"
    var lName = Model.leagueLabel(fixtureFilterId).toUpperCase()
    var list = Model.matchesForLeague(allMatches, fixtureFilterId)
    var nextRound = ""
    for (var i = 0; i < list.length; i++) {
      if (list[i].status === "upcoming" && list[i].round) {
        nextRound = list[i].round
        break
      }
    }
    if (nextRound) return lName + " · MATCHDAY " + nextRound
    return lName + " FIXTURES"
  }

  property bool setupExpanded: false

  // ---- Tabs ---------------------------------------------------------------
  property int tabIndex: 0
  onTabIndexChanged: focusSection = 0
  readonly property var tabOptions: [
    { value: "team", label: "Fixtures", icon: "★" },
    { value: "live", label: "Live", icon: "●" },
    { value: "table", label: "Standings", icon: "󰝘" }
  ]
  readonly property int liveCount: Model.liveMatches(allMatches, matchDetails).length

  // Live 1-Second Adaptive Clock
  property double nowMs: Date.now()
  Timer {
    interval: root.opened ? 1000 : 30000
    running: true
    repeat: true
    onTriggered: { root.nowMs = Date.now() }
  }

  readonly property string nextKickoffText: {
    var best = null
    var bestTime = Infinity
    var now = root.nowMs
    for (var i = 0; i < allMatches.length; i++) {
      var m = allMatches[i]
      if (!m || m.status !== "upcoming") continue
      var t = Date.parse(m.time || "")
      if (isNaN(t) || t <= now || t >= bestTime) continue
      bestTime = t
      best = m
    }
    if (!best) return ""
    var countdown = Model.formatCountdown(best.time, root.nowMs)
    return Model.matchLine(best) + (countdown ? " (in " + countdown + ")" : "")
  }

  readonly property var standingsOptions: {
    var opts = []
    if (activeSport === "football") {
      var ids = Model.arrayFrom(selectedLeagueIds)
      for (var i = 0; i < ids.length; i++) {
        var id = String(ids[i])
        opts.push({ value: id, label: Model.leagueLabel(id) })
      }
    } else if (activeSport === "nba" || activeSport === "nhl") {
      opts.push({ value: "Eastern Conference", label: "Eastern Conference" })
      opts.push({ value: "Western Conference", label: "Western Conference" })
    } else if (activeSport === "f1") {
      opts.push({ value: "Drivers", label: "Drivers Championship" })
      opts.push({ value: "Constructors", label: "Constructors Championship" })
    } else if (activeSport === "nfl") {
      opts.push({ value: "American Football Conference", label: "AFC" })
      opts.push({ value: "National Football Conference", label: "NFC" })
    } else if (activeSport === "mlb") {
      opts.push({ value: "American League", label: "American League" })
      opts.push({ value: "National League", label: "National League" })
    }
    return opts
  }

  readonly property var standingsRows: {
    var id = String(standingsLeagueId || "")
    if (activeSport === "football") {
      for (var i = 0; i < lastPages.length; i++) {
        var page = lastPages[i]
        if (page && page.league && String(page.league.id) === id)
          return Model.arrayFrom(page.standings)
      }
      return []
    }
    if (activeSport === "f1") {
      var f1Key = (id === "Constructors" || id.indexOf("Construct") !== -1) ? "Constructors" : "Drivers"
      if (multiSportStandings && multiSportStandings[f1Key] && multiSportStandings[f1Key].length > 0) {
        return Model.arrayFrom(multiSportStandings[f1Key])
      }
      for (var f in multiSportStandings) {
        if (multiSportStandings[f] && multiSportStandings[f].length > 0)
          return Model.arrayFrom(multiSportStandings[f])
      }
      return []
    }
    if (multiSportStandings && multiSportStandings[id]) {
      return Model.arrayFrom(multiSportStandings[id])
    }
    for (var k in multiSportStandings) {
      if (multiSportStandings[k] && multiSportStandings[k].length > 0)
        return Model.arrayFrom(multiSportStandings[k])
    }
    return []
  }

  // Driver standings summary for F1 spotlight
  readonly property var favoriteDriverStanding: {
    if (activeSport !== "f1" || selectedTeamId === "") return null
    var drivers = (multiSportStandings && multiSportStandings["Drivers"]) || []
    var fav = String(selectedTeamId).toLowerCase()
    for (var i = 0; i < drivers.length; i++) {
      var d = drivers[i]
      if (d.id === fav || d.shortName.toLowerCase() === fav || d.name.toLowerCase().indexOf(fav) !== -1)
        return d
    }
    return null
  }

  // ---- Fetch round bookkeeping -------------------------------------------
  property int requestSerial: 0
  property var roundQueue: []
  property int nextDispatch: 0
  property int outstanding: 0
  property var roundResults: ({})
  property var retryCounts: ({})
  property var pendingRetryIds: []
  property int espnRetryCount: 0
  property int espnRetrySerial: 0
  property string espnSportPath: ""
  property string espnSportCode: ""
  property string espnDefaultName: ""
  property int f1RetryCount: 0
  property int f1RetrySerial: 0

  // ---- Focus navigation ---------------------------------------------------
  property int focusSection: 0

  readonly property var sortedLeagueOptions: {
    var raw = Model.leagues()
    var selected = Model.arrayFrom(selectedLeagueIds)
    var selectedSet = {}
    for (var s = 0; s < selected.length; s++) {
      selectedSet[String(selected[s])] = true
    }

    var selectedList = []
    var unselectedList = []

    for (var i = 0; i < raw.length; i++) {
      var item = raw[i]
      var val = String(item.value)
      if (selectedSet[val]) {
        selectedList.push({
          value: item.value,
          label: item.label,
          description: (item.description ? item.description + " · " : "") + "Selected",
          region: item.region
        })
      } else {
        unselectedList.push(item)
      }
    }

    return selectedList.concat(unselectedList)
  }

  // Multi-competition team fixtures
  readonly property var teamMatches: {
    if (activeSport === "f1") return allMatches
    if (teamMatchesRaw && teamMatchesRaw.length > 0) return teamMatchesRaw
    if (selectedTeamIds.length > 0) return Model.matchesForTeam(allMatches, selectedTeamIds, activeSport)
    if (selectedTeamId !== "") return Model.matchesForTeam(allMatches, selectedTeamId, activeSport)
    return []
  }
  readonly property var featuredMatch: Model.featuredMatchForTeam(teamMatches.length > 0 ? teamMatches : allMatches)
  readonly property string selectedTeamName: selectedTeamIds.length > 0 ? root.teamNameFor(selectedTeamIds[0]) : selectedTeamLabel()
  readonly property string selectedLeagueNames: selectedLeagueNameList()

  // Bar badge + summary
  readonly property bool favoriteTeamLive: {
    var source = teamMatches.length > 0 ? teamMatches : allMatches
    for (var i = 0; i < source.length; i++)
      if (source[i].status === "live") return true
    return false
  }
  readonly property string favoriteSummaryText: {
    if (favoriteTeamLive) {
      var source = teamMatches.length > 0 ? teamMatches : allMatches
      for (var i = 0; i < source.length; i++) {
        var m = source[i]
        if (m.status === "live") {
          var h = (m.home.shortName || m.home.name).slice(0, 3).toUpperCase()
          var a = (m.away.shortName || m.away.name).slice(0, 3).toUpperCase()
          return h + " " + (m.scoreText || "0–0") + " " + a + " " + Model.interpolateLiveTime(m, root.nowMs, root.lastUpdated.getTime())
        }
      }
    }
    if (teamMatches.length === 0 && allMatches.length === 0) return ""
    var first = teamMatches.length > 0 ? teamMatches[0] : allMatches[0]
    var status = Model.matchStatusText(first)
    var tLabel = first.home && (selectedTeamIds.indexOf(String(first.home.id)) !== -1) ? (first.home.shortName || first.home.name) : (first.away ? (first.away.shortName || first.away.name) : (selectedTeamName || (first.home ? first.home.name : "")))
    return tLabel + " · " + status + (first.scoreText && first.status !== "upcoming" ? " " + first.scoreText : "")
  }

  readonly property var refreshIntervalOptions: [
    { value: "5", label: "5 min" },
    { value: "10", label: "10 min" },
    { value: "15", label: "15 min" },
    { value: "30", label: "30 min" },
    { value: "45", label: "45 min" },
    { value: "60", label: "60 min" }
  ]

  function switchSport(sportValue) {
    var next = String(sportValue || "").toLowerCase()
    var valid = false
    var sportsList = Model.sports()
    for (var i = 0; i < sportsList.length; i++) {
      if (sportsList[i].value === next) { valid = true; break }
    }
    // Ignore unknown values (e.g. bad IPC input) — they would otherwise leave
    // the round dispatcher with no worker and the spinner stuck forever
    if (!valid || activeSport === next) return
    activeSport = next
    savedState.sport = activeSport
    restoreSportSelections()
    fixtureFilterId = activeSport === "f1" ? "all" : (selectedTeamIds.length > 0 ? "team" : "all")
    persistState()
    allMatches = []
    teamMatchesRaw = []
    multiSportStandings = {}
    lastPages = []
    matchDetails = {}
    ensureStandingsSelection()
    refresh()
  }

  function restoreSportSelections() {
    if (activeSport === "football") {
      var fb = savedState.football || {}
      selectedLeagueIds = Model.normalizeLeagueIds(fb.leagueIds)
      if (selectedLeagueIds.length === 0) selectedLeagueIds = ["61"]
      selectedTeamIds = Model.normalizeTeamIds(fb.teamIds || (fb.teamId ? [fb.teamId] : []))
      selectedTeamId = String(selectedTeamIds.length > 0 ? selectedTeamIds[0] : (fb.teamId || ""))
      standingsLeagueId = String(fb.standingsLeagueId || selectedLeagueIds[0])
      if (fb.tab === "standings") root.tabIndex = 2
      else if (fb.tab === "live") root.tabIndex = 1
      else root.tabIndex = 0
    } else if (activeSport === "f1") {
      var f1 = savedState.f1 || {}
      selectedTeamIds = Model.normalizeTeamIds(f1.teamIds || (f1.teamId ? [f1.teamId] : []))
      selectedTeamId = String(selectedTeamIds.length > 0 ? selectedTeamIds[0] : (f1.teamId || ""))
      standingsLeagueId = String(f1.standingsGroup || "Drivers")
      if (f1.tab === "standings") root.tabIndex = 2
      else if (f1.tab === "live") root.tabIndex = 1
      else root.tabIndex = 0
    } else {
      var sp = savedState[activeSport] || {}
      selectedTeamIds = Model.normalizeTeamIds(sp.teamIds || (sp.teamId ? [sp.teamId] : []))
      selectedTeamId = String(selectedTeamIds.length > 0 ? selectedTeamIds[0] : (sp.teamId || ""))
      standingsLeagueId = String(sp.standingsGroup || (standingsOptions.length > 0 ? standingsOptions[0].value : ""))
      if (sp.tab === "standings") root.tabIndex = 2
      else if (sp.tab === "live") root.tabIndex = 1
      else root.tabIndex = 0
    }
  }

  function toggleSpoiler() {
    console.log("matchday: toggleSpoiler called, stateLoaded=" + stateLoaded)
    antiSpoiler = !antiSpoiler
    savedState.antiSpoiler = antiSpoiler
    persistState()
  }

  function revealMatch(matchId) {
    var next = {}
    for (var k in revealedMatchIds) next[k] = revealedMatchIds[k]
    next[String(matchId)] = true
    revealedMatchIds = next
  }

  // ---- Navigation ---------------------------------------------------------
  function focusableControlCount() {
    return selectedTeamId === "" ? 6 : 7
  }

  function moveFocus(delta) {
    var count = focusableControlCount()
    if (count <= 0) return
    focusSection = (focusSection + delta + count) % count
  }

  function moveWithin(dx) {
    if (focusSection === 0 && !anyPopupOpen()) {
      var next = (tabIndex + dx + tabOptions.length) % tabOptions.length
      tabIndex = next
      return
    }
    moveFocus(dx)
  }

  function anyPopupOpen() {
    return (leaguePicker && leaguePicker.popupOpen) || (teamPicker && teamPicker.popupOpen) || intervalPicker.popupOpen
      || (standingsPicker && standingsPicker.popupOpen)
  }

  function activateFocus() {
    if (focusSection === 0) root.tabIndex = (root.tabIndex + 1) % root.tabOptions.length
    else if (focusSection === 1 && leaguePicker) leaguePicker.toggle()
    else if (focusSection === 2 && teamPicker) teamPicker.toggle()
    else if (focusSection === 3) root.refresh()
    else if (focusSection === 4 && selectedTeamId !== "") root.clearSelectedTeam()
    else if (focusSection === 4) intervalPicker.toggle()
    else if (focusSection === 5) intervalPicker.toggle()
    else if (focusSection === 6 && root.standingsOptions.length > 1 && standingsPicker) standingsPicker.toggle()
  }

  // ---- Lifecycle -----------------------------------------------------------
  function open() { root.openFromHotkey() }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    stateFile.reload()
    Qt.callLater(function() {
      if (!root.opened) return
      setCenterHoverRevealSuppressed(true)
      // Surface live action immediately when the panel opens
      if (root.liveCount > 0 && root.tabIndex === 0) root.tabIndex = 1
      root.scheduleNextPoll()
      if (root.stateLoaded && !root.loading && (needsAutoRefresh() || root.allMatches.length === 0)) root.refresh()
      else if (!root.loading && detailQueue.length > 0) Qt.callLater(root.nextDetail)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    openedFromHotkey = false
    scheduleNextPoll()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function closeForPopoutSwitch() {
    root.popoutSwitchClosing = true
    root.close()
    Qt.callLater(function() { root.popoutSwitchClosing = false })
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function needsAutoRefresh() {
    if (allMatches.length === 0) return true
    if (lastUpdated.getTime() <= 0) return true
    return (new Date()).getTime() - lastUpdated.getTime() > 60000
  }

  // ---- State persistence ----------------------------------------------------
  function selectedLeagueNameList() {
    if (activeSport !== "football") return activeSportMeta.label
    var names = []
    var ids = Model.arrayFrom(selectedLeagueIds)
    for (var i = 0; i < ids.length; i++) names.push(Model.leagueLabel(ids[i]))
    return names.join(", ")
  }

  function selectedTeamLabel() {
    var id = String(selectedTeamId || "")
    if (!id) return ""
    var opts = baseTeamOptions
    for (var i = 0; i < opts.length; i++) {
      if (String(opts[i].value) === id) return String(opts[i].label)
    }
    if (activeSport === "football") return String((savedState.football && savedState.football.teamName) || "")
    if (savedState[activeSport]) return String(savedState[activeSport].teamName || "")
    return ""
  }

  function applyState(raw) {
    var nextState = Model.parseState(raw)
    var ownWrite = ignoredStateSignature !== ""
      && JSON.stringify(nextState) === ignoredStateSignature
    if (ownWrite) ignoredStateSignature = ""
    savedState = nextState
    activeSport = String(savedState.sport || "football")
    antiSpoiler = savedState.antiSpoiler === true
    enableNotifications = savedState.notifications !== false
    restoreSportSelections()
    stateLoaded = true
    console.log("matchday: state applied, sport=" + activeSport + " fbTeams=" + savedState.football.teamIds.length)

    if (leaguePicker) leaguePicker.values = selectedLeagueIds
    ensureStandingsSelection()
    if (!ownWrite) {
      espnRetryCount = 0
      f1RetryCount = 0
      root.startRound()
    }
  }

  function persistState() {
    if (!stateLoaded) return
    var curSport = activeSport
    var tabName = tabIndex === 2 ? "standings" : (tabIndex === 1 ? "live" : "fixtures")
    var sportSettings = {}
    var sportsList = ["nba", "f1", "nfl", "mlb", "nhl"]
    for (var s = 0; s < sportsList.length; s++) {
      var spk = sportsList[s]
      var prevSp = savedState[spk] || {}
      if (curSport === spk) {
        sportSettings[spk] = {
          teamIds: selectedTeamIds,
          teamId: selectedTeamId,
          teamName: selectedTeamName,
          standingsGroup: standingsLeagueId,
          tab: tabName
        }
      } else {
        sportSettings[spk] = prevSp
      }
    }

    var fb = savedState.football || {}
    var fbTeamIds = curSport === "football" ? selectedTeamIds : (fb.teamIds || (fb.teamId ? [fb.teamId] : []))
    savedState = Model.statePayload(
      curSport,
      fb.leagueIds || selectedLeagueIds,
      fbTeamIds,
      curSport === "football" ? selectedTeamName : fb.teamName,
      savedState.refreshMinutes,
      curSport === "football" ? standingsLeagueId : fb.standingsLeagueId,
      sportSettings,
      antiSpoiler,
      enableNotifications
    )
    // statePayload rebuilds football without a tab; restore it so the written
    // shape round-trips exactly through parseState (signature check in applyState)
    savedState.football.tab = curSport === "football" ? tabName : String(fb.tab || "fixtures")
    ignoredStateSignature = JSON.stringify(savedState)
    stateFile.setText(JSON.stringify(savedState, null, 2) + "\n")
  }

  function toggleNotifications() {
    enableNotifications = !enableNotifications
    savedState.notifications = enableNotifications
    persistState()
    if (enableNotifications) {
      sendDesktopNotification("Omarchy Matchday", "Goal and kickoff notifications enabled!", "", "normal")
    }
  }

  function sendDesktopNotification(title, body, iconPath, urgency) {
    if (!root.enableNotifications) return
    var cmd = ["notify-send", "-a", "Omarchy Matchday"]
    if (iconPath && String(iconPath).trim()) {
      var p = String(iconPath)
      if (p.indexOf("file://") === 0) p = p.slice(7)
      cmd.push("-i", p)
    }
    if (urgency) cmd.push("-u", urgency)
    cmd.push(title, body)
    notifierProc.command = cmd
    notifierProc.running = true
  }

  function logoCacheDir() {
    return Quickshell.env("HOME") + "/.cache/omarchy-matchday/logos/"
  }

  function crestIconPath(sport, team) {
    var key = Model.crestCacheKey(sport, team && team.id ? team.id : "", team && team.abbr ? team.abbr : "")
    return key !== "" ? logoCacheDir() + key + ".png" : ""
  }

  function checkScoreNotifications() {
    if (!root.enableNotifications || allMatches.length === 0) return

    var ms = Model.arrayFrom(allMatches)
    var favIds = Model.arrayFrom(root.selectedTeamIds)
    var favSet = {}
    for (var f = 0; f < favIds.length; f++) favSet[String(favIds[f]).toLowerCase()] = true

    var now = root.nowMs
    var nextSeen = {}

    for (var i = 0; i < ms.length; i++) {
      var m = ms[i]
      if (!m || !m.id) continue

      var hId = String(m.home && m.home.id || "").toLowerCase()
      var aId = String(m.away && m.away.id || "").toLowerCase()
      // Only followed teams notify (all events still notify on F1 weekends)
      var isFav = favSet[hId] || favSet[aId] || root.activeSport === "f1"

      var prev = lastSeenMatches[m.id]

      if (prev && isFav) {
        // 1. Kickoff / Started Live
        if (m.status === "live" && prev.status === "upcoming") {
          var startTitle = m.sport === "f1" ? ("🏁 F1: " + (m.raceName || (m.home && m.home.name) || "Grand Prix")) : ("● LIVE: " + m.home.name + " vs " + m.away.name)
          var startBody = m.sport === "f1" ? ("The session is underway in " + (m.locality || m.country || "live") + "!") : ("The match has kicked off! " + (m.leagueName ? "· " + m.leagueName : ""))
          sendDesktopNotification(startTitle, startBody, crestIconPath(m.sport || root.activeSport, m.home), "normal")
        }

        // 2. Goal / Score change
        if (m.status === "live") {
          var hDiff = (m.homeScore || 0) - (prev.homeScore || 0)
          var aDiff = (m.awayScore || 0) - (prev.awayScore || 0)

          if (hDiff > 0) {
            var gTitle1 = m.sport === "football" ? ("⚽ GOAL! " + m.home.name) : (Model.sportMeta(m.sport).icon + " " + m.home.name + " (+" + hDiff + ")")
            var gBody1 = m.home.name + " " + (m.scoreText || (m.homeScore + " – " + m.awayScore)) + " " + m.away.name + (m.liveTime ? " (" + m.liveTime + ")" : "")
            sendDesktopNotification(gTitle1, gBody1, crestIconPath(m.sport || root.activeSport, m.home), "critical")
          }

          if (aDiff > 0) {
            var gTitle2 = m.sport === "football" ? ("⚽ GOAL! " + m.away.name) : (Model.sportMeta(m.sport).icon + " " + m.away.name + " (+" + aDiff + ")")
            var gBody2 = m.home.name + " " + (m.scoreText || (m.homeScore + " – " + m.awayScore)) + " " + m.away.name + (m.liveTime ? " (" + m.liveTime + ")" : "")
            sendDesktopNotification(gTitle2, gBody2, crestIconPath(m.sport || root.activeSport, m.away), "critical")
          }
        }

        // 3. Match Imminent (15 min before kickoff)
        if (m.status === "upcoming" && !prev.notifiedUpcoming) {
          var msTime = Date.parse(m.time)
          if (!isNaN(msTime)) {
            var diffMins = Math.floor((msTime - now) / 60000)
            if (diffMins > 0 && diffMins <= 15) {
              var uTitle = m.sport === "f1" ? ("🏎️ F1 starting soon: " + (m.raceName || (m.home && m.home.name) || "Grand Prix")) : ("⏰ Starting in " + diffMins + "m: " + m.home.name + " vs " + m.away.name)
              var uBody = (m.leagueName ? m.leagueName + " · " : "") + "Scheduled start at " + Qt.formatDateTime(new Date(msTime), "HH:mm")
              sendDesktopNotification(uTitle, uBody, crestIconPath(m.sport || root.activeSport, m.home), "normal")
              prev.notifiedUpcoming = true
            }
          }
        }
      }

      nextSeen[m.id] = {
        homeScore: m.homeScore || 0,
        awayScore: m.awayScore || 0,
        status: m.status || "upcoming",
        notifiedUpcoming: prev ? (prev.notifiedUpcoming || false) : false
      }
    }

    lastSeenMatches = nextSeen
  }

  function setSelectedLeagues(values) {
    var next = Model.normalizeLeagueIds(values)
    selectedLeagueIds = next
    if (leaguePicker) leaguePicker.values = next
    ensureStandingsSelection()
    persistState()
    if (root.opened || root.backgroundUpdates) root.refresh()
  }

  function toggleSelectedTeam(value) {
    var id = String(value || "").trim()
    if (!id) return
    var arr = Model.arrayFrom(selectedTeamIds)
    var idx = arr.indexOf(id)
    if (idx !== -1) {
      arr.splice(idx, 1)
    } else {
      arr.push(id)
    }
    selectedTeamIds = arr
    selectedTeamId = arr.length > 0 ? arr[0] : ""
    teamMatchesRaw = []
    persistState()
    if (activeSport === "football" && arr.length > 0) root.fetchFootballTeamPage()
  }

  function removeSelectedTeam(value) {
    var id = String(value || "").trim()
    var arr = Model.arrayFrom(selectedTeamIds)
    var idx = arr.indexOf(id)
    if (idx !== -1) {
      arr.splice(idx, 1)
      selectedTeamIds = arr
      selectedTeamId = arr.length > 0 ? arr[0] : ""
      teamMatchesRaw = []
      persistState()
    }
  }

  function setSelectedTeam(value) {
    root.toggleSelectedTeam(value)
  }

  function clearSelectedTeam() {
    selectedTeamIds = []
    selectedTeamId = ""
    teamMatchesRaw = []
    persistState()
  }

  function setRefreshMinutes(value) {
    var minutes = Math.max(5, Math.min(60, parseInt(value, 10) || 15))
    savedState.refreshMinutes = minutes
    persistState()
    scheduleNextPoll()
  }

  function setStandingsLeague(value) {
    standingsLeagueId = String(value || "")
    persistState()
  }

  function ensureStandingsSelection() {
    if (standingsOptions.length === 0) {
      standingsLeagueId = ""
      return
    }
    for (var i = 0; i < standingsOptions.length; i++) {
      if (standingsOptions[i].value === standingsLeagueId) return
    }
    standingsLeagueId = standingsOptions[0].value
  }

  function refreshIntervalLabel() {
    var minutes = Math.max(5, parseInt(savedState.refreshMinutes || 15, 10))
    for (var i = 0; i < refreshIntervalOptions.length; i++)
      if (parseInt(refreshIntervalOptions[i].value, 10) === minutes) return refreshIntervalOptions[i].label
    return minutes + " min"
  }

  // ---- Multi-Sport Fetch Dispatch ------------------------------------------
  function refresh() {
    if (!stateLoaded) {
      stateFile.reload()
      return
    }
    espnRetryCount = 0
    f1RetryCount = 0
    startRound()
  }

  function startRound() {
    requestSerial++
    loading = true
    errorMessage = ""
    failedLeagues = []

    if (activeSport === "football") {
      startFootballRound()
    } else if (activeSport === "nba") {
      startEspnRound("basketball/nba", "nba", "NBA")
    } else if (activeSport === "nfl") {
      startEspnRound("football/nfl", "nfl", "NFL")
    } else if (activeSport === "mlb") {
      startEspnRound("baseball/mlb", "mlb", "MLB")
    } else if (activeSport === "nhl") {
      startEspnRound("hockey/nhl", "nhl", "NHL")
    } else if (activeSport === "f1") {
      startF1Round()
    }
  }

  // ---- Football Round (FotMob) ---------------------------------------------
  function startFootballRound() {
    var workers = [workerA, workerB, workerC, workerD]
    for (var i = 0; i < workers.length; i++) {
      if (workers[i].running) workers[i].running = false
      workers[i].handled = false
    }
    retryDelay.stop()
    roundQueue = selectedLeagueIds.slice(0, 12)
    pendingRetryIds = []
    nextDispatch = 0
    outstanding = roundQueue.length
    roundResults = {}
    retryCounts = {}

    if (outstanding === 0) {
      loading = false
      errorMessage = "Select at least one league to load matches."
      return
    }
    if (selectedTeamId !== "") fetchFootballTeamPage()
    Qt.callLater(pumpFootball)
  }

  function fetchFootballTeamPage() {
    if (!selectedTeamId) return
    workerTeam.handled = false
    workerTeam.teamId = String(selectedTeamId)
    workerTeam.serial = root.requestSerial
    workerTeam.command = [
      "curl", "-LfsS", "--compressed", "--max-time", "12",
      "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
      "https://www.fotmob.com/teams/" + encodeURIComponent(selectedTeamId)
    ]
    workerTeam.running = true
  }

  function startFootballWorker(w, leagueId) {
    w.handled = false
    w.leagueId = String(leagueId)
    w.serial = root.requestSerial
    w.command = [
      "curl", "-LfsS", "--compressed", "--max-time", "12",
      "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
      "https://www.fotmob.com/leagues/" + encodeURIComponent(w.leagueId)
    ]
    w.running = true
  }

  function pumpFootball() {
    if (!root.loading || activeSport !== "football") return
    var workers = [workerA, workerB, workerC, workerD]
    var anyBusy = false
    for (var i = 0; i < workers.length; i++) {
      var w = workers[i]
      if (w.running) {
        anyBusy = true
        continue
      }
      if (nextDispatch < roundQueue.length) {
        anyBusy = true
        startFootballWorker(w, String(roundQueue[nextDispatch]))
        nextDispatch++
      }
    }
    if (!anyBusy && pendingRetryIds.length === 0) finishFootballLoading()
  }

  function resolveFootballWorker(w, raw) {
    if (w.handled || w.serial !== root.requestSerial) return
    w.handled = true
    var id = w.leagueId
    var page = null
    if (String(raw || "").trim()) {
      try { page = Model.parseLeaguePage(raw, id) } catch (e) { page = null }
    }
    if (page) {
      roundResults[id] = page
      outstanding--
    } else {
      var tries = retryCounts[id] || 0
      if (tries < 2) {
        retryCounts[id] = tries + 1
        pendingRetryIds.push(id)
        retryDelay.restart()
      } else {
        failedLeagues.push(Model.leagueLabel(id))
        outstanding--
      }
    }
    Qt.callLater(root.pumpFootball)
  }

  function finishFootballLoading() {
    loading = false
    var pages = []
    var ids = Model.arrayFrom(selectedLeagueIds)
    for (var i = 0; i < ids.length; i++) {
      var res = roundResults[String(ids[i])]
      if (res) pages.push(res)
    }

    if (pages.length > 0) {
      allMatches = Model.mergePages(pages)
      teamOptions = Model.teamOptionsForSport("football", allMatches)
      lastUpdated = new Date()
      loadedFromCache = false
      lastPages = pages
    }
    ensureStandingsSelection()
    startDetailFetch()
    downloadMissingLogos()
    checkScoreNotifications()
    scheduleNextPoll()

    if (pages.length === 0 && !hasData) {
      errorMessage = "Unable to load matches. Check your connection."
    } else if (failedLeagues.length > 0) {
      errorMessage = "Some leagues could not be loaded: " + failedLeagues.join(", ")
    }
  }

  // ---- ESPN Scoreboard & Standings (NBA, NFL, MLB, NHL) ---------------------
  function startEspnRound(espnPath, sportCode, defaultName) {
    espnSportPath = String(espnPath)
    espnSportCode = String(sportCode)
    espnDefaultName = String(defaultName)
    // Multi-day window so Fixtures shows recent results and upcoming games,
    // not just today's slate
    var dates = "dates=" + Model.espnDateRange(1, 3)

    workerScoreboard.handled = false
    workerScoreboard.serial = root.requestSerial
    workerScoreboard.sportCode = sportCode
    workerScoreboard.defaultName = defaultName
    workerScoreboard.command = ["curl", "-LfsS", "--max-time", "10", "https://site.api.espn.com/apis/site/v2/sports/" + espnPath + "/scoreboard?" + dates]
    workerScoreboard.running = true

    workerStandings.handled = false
    workerStandings.serial = root.requestSerial
    workerStandings.sportCode = sportCode
    workerStandings.command = ["curl", "-LfsS", "--max-time", "10", "https://site.api.espn.com/apis/v2/sports/" + espnPath + "/standings"]
    workerStandings.running = true
  }

  function resolveEspnScoreboard(raw, sportCode, defaultName) {
    if (String(raw || "").trim()) {
      var matches = Model.parseEspnScoreboard(raw, sportCode, defaultName)
      if (matches && matches.length > 0) {
        allMatches = matches
        lastUpdated = new Date()
        loadedFromCache = false
      }
    }
    checkEspnDone()
  }

  function resolveEspnStandings(raw, sportCode) {
    if (String(raw || "").trim()) {
      var st = Model.parseEspnStandings(raw, sportCode)
      if (st && Object.keys(st).length > 0) {
        multiSportStandings = st
      }
    }
    checkEspnDone()
  }

  function checkEspnDone() {
    if (!workerScoreboard.running && !workerStandings.running) {
      if (allMatches.length === 0 && Object.keys(multiSportStandings).length === 0 && espnRetryCount < 2) {
        espnRetryCount++
        espnRetrySerial = requestSerial
        espnRetryDelay.restart()
        return
      }
      loading = false
      ensureStandingsSelection()
      downloadMissingLogos()
      checkScoreNotifications()
      if (allMatches.length === 0 && Object.keys(multiSportStandings).length === 0) {
        errorMessage = "Unable to load " + activeSportMeta.label + " data. Check connection."
      }
      scheduleNextPoll()
    }
  }

  // ---- Formula 1 Round (Jolpica / Ergast) ----------------------------------
  function startF1Round() {
    workerF1Calendar.handled = false
    workerF1Calendar.serial = root.requestSerial
    workerF1Calendar.command = ["curl", "-LfsS", "--max-time", "10", "https://api.jolpi.ca/ergast/f1/current.json"]
    workerF1Calendar.running = true

    workerF1Drivers.handled = false
    workerF1Drivers.serial = root.requestSerial
    workerF1Drivers.command = ["curl", "-LfsS", "--max-time", "10", "https://api.jolpi.ca/ergast/f1/current/driverStandings.json"]
    workerF1Drivers.running = true

    workerF1Constructors.handled = false
    workerF1Constructors.serial = root.requestSerial
    workerF1Constructors.command = ["curl", "-LfsS", "--max-time", "10", "https://api.jolpi.ca/ergast/f1/current/constructorStandings.json"]
    workerF1Constructors.running = true
  }

  function checkF1Done() {
    if (!workerF1Calendar.running && !workerF1Drivers.running && !workerF1Constructors.running) {
      if (allMatches.length === 0 && f1RetryCount < 2) {
        f1RetryCount++
        f1RetrySerial = requestSerial
        f1RetryDelay.restart()
        return
      }
      loading = false
      ensureStandingsSelection()
      downloadMissingLogos()
      checkScoreNotifications()
      scheduleNextPoll()
      if (allMatches.length === 0) {
        errorMessage = "Unable to load F1 race calendar. Check connection."
      }
    }
  }

  function downloadMissingLogos() {
    if (logoCacheProc.running) return
    var items = []
    var seen = {}

    // Collect all matches home/away (keys must match Model.crestCacheKey so
    // TeamCrest.qml finds the files the downloader saves)
    var ms = Model.arrayFrom(allMatches)
    for (var i = 0; i < ms.length; i++) {
      var m = ms[i]
      if (!m) continue
      var sp = String(m.sport || root.activeSport || "football").toLowerCase()
      if (m.home && m.home.id) {
        var u1 = m.home.logo || (sp === "football" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + m.home.id + ".png") : "")
        var k1 = Model.crestCacheKey(sp, m.home.id, m.home.abbr || "")
        if (k1 !== "" && !seen[k1] && u1.indexOf("http") === 0) {
          seen[k1] = true
          items.push({ url: u1, key: k1 })
        }
      }
      if (m.away && m.away.id) {
        var u2 = m.away.logo || (sp === "football" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + m.away.id + ".png") : "")
        var k2 = Model.crestCacheKey(sp, m.away.id, m.away.abbr || "")
        if (k2 !== "" && !seen[k2] && u2.indexOf("http") === 0) {
          seen[k2] = true
          items.push({ url: u2, key: k2 })
        }
      }
    }

    // Collect all standings logos
    var st = Model.arrayFrom(standingsRows)
    for (var j = 0; j < st.length; j++) {
      var row = st[j]
      if (row && row.id) {
        var sp2 = String(root.activeSport || "football").toLowerCase()
        var u3 = row.logo || (sp2 === "football" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + row.id + ".png") : "")
        var k3 = Model.crestCacheKey(sp2, row.id, row.abbr || "")
        if (k3 !== "" && !seen[k3] && u3.indexOf("http") === 0) {
          seen[k3] = true
          items.push({ url: u3, key: k3 })
        }
      }
    }

    if (items.length === 0) return

    var cmd = ["curl", "-sL", "--parallel", "--create-dirs"]
    var count = 0
    var cacheDir = Quickshell.env("HOME") + "/.cache/omarchy-matchday/logos/"
    for (var c = 0; c < items.length && count < 64; c++) {
      var it = items[c]
      if (it.url && it.url.indexOf("http") === 0) {
        cmd.push("-o", cacheDir + it.key + ".png", it.url)
        count++
      }
    }
    if (count > 0) {
      logoCacheProc.command = cmd
      logoCacheProc.running = true
    }
  }

  // ---- Football Detail Enrichment ------------------------------------------
  function startDetailFetch() {
    if (activeSport !== "football") return
    var wanted = []
    var live = Model.liveMatches(allMatches, matchDetails)
    for (var i = 0; i < live.length && wanted.length < 8; i++) {
      var lid = String(live[i].id)
      if (!matchDetails[lid]) wanted.push(lid)
    }
    var source = teamMatches
    for (var j = 0; j < source.length && wanted.length < 16; j++) {
      var tid = String(source[j].id)
      if (!matchDetails[tid] && wanted.indexOf(tid) === -1) wanted.push(tid)
    }
    detailQueue = wanted
    Qt.callLater(nextDetail)
  }

  function nextDetail() {
    if (!root.opened && !root.backgroundUpdates) return
    if (detailQueue.length === 0 || detailProc.running) return

    var id = String(detailQueue[0])
    var url = ""
    for (var i = 0; i < allMatches.length; i++) {
      if (String(allMatches[i].id) === id) {
        url = String(allMatches[i].pageUrl || "")
        break
      }
    }
    if (url === "") {
      detailQueue.shift()
      Qt.callLater(nextDetail)
      return
    }
    if (url.indexOf("http") !== 0) url = "https://www.fotmob.com" + url

    detailProc.serial = requestSerial
    detailProc.handled = false
    detailProc.command = [
      "curl", "-LfsS", "--compressed", "--max-time", "8",
      "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
      url
    ]
    detailProc.running = true
  }

  function consumeDetail(raw) {
    var id = detailQueue.length > 0 ? String(detailQueue.shift()) : ""
    if (id !== "" && String(raw || "").trim()) {
      try {
        var parsed = Model.parseDetails(raw)
        if (parsed) {
          var next = {}
          for (var key in matchDetails) next[key] = matchDetails[key]
          next[id] = parsed
          matchDetails = next

          if (parsed.statusLong === "Full-Time" || parsed.reason === "FT" || parsed.finished) {
            var updated = false
            for (var m = 0; m < allMatches.length; m++) {
              if (String(allMatches[m].id) === id && allMatches[m].status === "live") {
                allMatches[m].status = "finished"
                updated = true
              }
            }
            if (updated) allMatches = Model.arrayFrom(allMatches)
          }
        }
      } catch (e) {}
    }
    Qt.callLater(nextDetail)
  }

  // ---- Match actions -------------------------------------------------------
  function kickoffTime(match) {
    var value = Date.parse(match && match.time ? match.time : "")
    if (isNaN(value)) return ""
    return Qt.formatDateTime(new Date(value), "HH:mm")
  }

  function tableFont() {
    return Qt.font({
      family: Style.font.family,
      pixelSize: Style.font.caption,
      letterSpacing: 0.8,
      bold: true
    })
  }

  function tableHeaderColor() {
    return Qt.darker(root.fgColor, 1.5)
  }

  function matchSubline(match) {
    if (!match) return ""
    if (match.sport === "f1") {
      return (match.circuitName || "Circuit") + (match.locality ? " · " + match.locality : "") + (match.country ? ", " + match.country : "")
    }
    var parts = []
    if (match.round) parts.push(match.round)
    var d = matchDetails[String(match.id)]
    if (d && d.stadium) parts.push("📍 " + d.stadium + (d.city ? ", " + d.city : ""))
    if (d && d.referee) parts.push("Ref. " + d.referee)
    if (d && d.attendance) parts.push("👥 " + Number(d.attendance).toLocaleString())
    return parts.join("  ·  ")
  }

  function openMatch(match) {
    if (!match || !match.pageUrl) return
    var url = String(match.pageUrl)
    if (url.indexOf("http") !== 0) url = "https://www.fotmob.com" + url
    matchOpener.command = ["xdg-open", url]
    matchOpener.running = true
  }

  function statusLine() {
    if (loading && !hasData) return "󰥔 Loading " + activeSportMeta.label + "…"
    if (loading) return "󰥔 Updating scores…"
    if (errorMessage !== "") return errorMessage
    if (!hasData) return "Select options above to track " + activeSportMeta.label + "."
    if (fastPolling) return "● LIVE · auto-updating · 󰥔 " + Qt.formatDateTime(lastUpdated, "HH:mm")
    return "󰥔 Updated " + Qt.formatDateTime(lastUpdated, "HH:mm")
  }

  Component.onCompleted: {
    console.log("matchday: panel instantiated")
    stateFile.reload()
  }

  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.config/omarchy/sports-favorites.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var str = ""
      try { str = typeof text === "function" ? text() : String(text || "") } catch (e) { str = "" }
      root.applyState(str)
    }
    onLoadFailed: root.applyState("")
    onFileChanged: reload()
  }

  Process { id: matchOpener }
  Process { id: logoCacheProc }
  Process { id: notifierProc }

  // ---- Multi-sport Workers -------------------------------------------------
  Process {
    id: workerScoreboard
    property bool handled: false
    property string sportCode: ""
    property string defaultName: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        workerScoreboard.handled = true
        root.resolveEspnScoreboard(String(text || ""), workerScoreboard.sportCode, workerScoreboard.defaultName)
      }
    }
    onExited: function(exitCode) {
      if (!workerScoreboard.handled && workerScoreboard.serial === root.requestSerial) {
        workerScoreboard.handled = true
        root.resolveEspnScoreboard("", workerScoreboard.sportCode, workerScoreboard.defaultName)
      }
    }
  }

  Process {
    id: workerStandings
    property bool handled: false
    property string sportCode: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        workerStandings.handled = true
        root.resolveEspnStandings(String(text || ""), workerStandings.sportCode)
      }
    }
    onExited: function(exitCode) {
      if (!workerStandings.handled && workerStandings.serial === root.requestSerial) {
        workerStandings.handled = true
        root.resolveEspnStandings("", workerStandings.sportCode)
      }
    }
  }

  Process {
    id: workerF1Calendar
    property bool handled: false
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        workerF1Calendar.handled = true
        var matches = Model.parseF1Calendar(String(text || ""))
        if (matches && matches.length > 0) {
          allMatches = matches
          lastUpdated = new Date()
        }
        root.checkF1Done()
      }
    }
    onExited: function(exitCode) {
      if (!workerF1Calendar.handled) {
        workerF1Calendar.handled = true
        root.checkF1Done()
      }
    }
  }

  Process {
    id: workerF1Drivers
    property bool handled: false
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        workerF1Drivers.handled = true
        var drivers = Model.parseF1DriverStandings(String(text || ""))
        if (drivers && drivers.length > 0) {
          var cur = {}
          for (var k in multiSportStandings) cur[k] = multiSportStandings[k]
          cur["Drivers"] = drivers
          multiSportStandings = cur
        }
        root.checkF1Done()
      }
    }
    onExited: function(exitCode) {
      if (!workerF1Drivers.handled) {
        workerF1Drivers.handled = true
        root.checkF1Done()
      }
    }
  }

  Process {
    id: workerF1Constructors
    property bool handled: false
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        workerF1Constructors.handled = true
        var con = Model.parseF1ConstructorStandings(String(text || ""))
        if (con && con.length > 0) {
          var cur2 = {}
          for (var k2 in multiSportStandings) cur2[k2] = multiSportStandings[k2]
          cur2["Constructors"] = con
          multiSportStandings = cur2
        }
        root.checkF1Done()
      }
    }
    onExited: function(exitCode) {
      if (!workerF1Constructors.handled) {
        workerF1Constructors.handled = true
        root.checkF1Done()
      }
    }
  }

  // Football Workers
  Process {
    id: workerTeam
    property bool handled: false
    property string teamId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        workerTeam.handled = true
        if (String(text || "").trim()) {
          try {
            var parsed = Model.parseTeamPage(text, selectedTeamId)
            if (parsed && parsed.length > 0) {
              teamMatchesRaw = parsed
              var merged = Model.arrayFrom(allMatches)
              var seen = {}
              for (var i = 0; i < merged.length; i++) seen[merged[i].id] = true
              for (var j = 0; j < parsed.length; j++) {
                if (!seen[parsed[j].id]) {
                  seen[parsed[j].id] = true
                  merged.push(parsed[j])
                }
              }
              allMatches = merged
            }
          } catch (e) {}
        }
      }
    }
    onExited: function(exitCode) {
      if (!workerTeam.handled) workerTeam.handled = true
    }
  }

  Process {
    id: workerA
    property bool handled: false
    property string leagueId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.resolveFootballWorker(workerA, String(text || ""))
    }
    onExited: function(exitCode) {
      if (!workerA.handled && workerA.serial === root.requestSerial) root.resolveFootballWorker(workerA, "")
    }
  }

  Process {
    id: workerB
    property bool handled: false
    property string leagueId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.resolveFootballWorker(workerB, String(text || ""))
    }
    onExited: function(exitCode) {
      if (!workerB.handled && workerB.serial === root.requestSerial) root.resolveFootballWorker(workerB, "")
    }
  }

  Process {
    id: workerC
    property bool handled: false
    property string leagueId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.resolveFootballWorker(workerC, String(text || ""))
    }
    onExited: function(exitCode) {
      if (!workerC.handled && workerC.serial === root.requestSerial) root.resolveFootballWorker(workerC, "")
    }
  }

  Process {
    id: workerD
    property bool handled: false
    property string leagueId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.resolveFootballWorker(workerD, String(text || ""))
    }
    onExited: function(exitCode) {
      if (!workerD.handled && workerD.serial === root.requestSerial) root.resolveFootballWorker(workerD, "")
    }
  }

  Timer {
    id: retryDelay
    interval: 2500
    onTriggered: {
      if (!root.loading || pendingRetryIds.length === 0) {
        pendingRetryIds = []
        return
      }
      roundQueue = roundQueue.concat(pendingRetryIds)
      pendingRetryIds = []
      root.pumpFootball()
    }
  }

  // Retry dead rounds for ESPN sports (same contract as the football retry)
  Timer {
    id: espnRetryDelay
    interval: 2500
    onTriggered: {
      if (root.loading && root.activeSport === root.espnSportCode && root.requestSerial === root.espnRetrySerial)
        root.startEspnRound(root.espnSportPath, root.espnSportCode, root.espnDefaultName)
    }
  }

  Timer {
    id: f1RetryDelay
    interval: 2500
    onTriggered: {
      if (root.loading && root.activeSport === "f1" && root.requestSerial === root.f1RetrySerial)
        root.startF1Round()
    }
  }

  Process {
    id: detailProc
    property int serial: 0
    property bool handled: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        detailProc.handled = true
        root.consumeDetail(String(text || ""))
      }
    }
    onExited: function(exitCode) {
      if (!detailProc.handled) {
        detailProc.handled = true
        root.consumeDetail("")
      }
    }
  }

  // Adaptive polling: while a followed match is live we poll every 40s so the
  // clock and score track reality; otherwise we fall back to the user interval.
  readonly property int slowRefreshMs: Math.max(5, parseInt(root.savedState.refreshMinutes || 15, 10)) * 60 * 1000
  property bool fastPolling: false

  function hasLiveFollowedMatch() {
    var source = teamMatches.length > 0 ? teamMatches : allMatches
    for (var i = 0; i < source.length; i++)
      if (source[i] && source[i].status === "live") return true
    return false
  }

  function scheduleNextPoll() {
    var wantRunning = root.opened || root.backgroundUpdates
    fastPolling = wantRunning && hasLiveFollowedMatch()
    if (!wantRunning) {
      refreshTimer.running = false
      return
    }
    var ms = fastPolling ? 40000 : root.slowRefreshMs
    if (refreshTimer.interval !== ms) refreshTimer.interval = ms
    refreshTimer.restart()
  }

  Timer {
    id: refreshTimer
    interval: 60000
    repeat: true
    running: false
    onTriggered: {
      if (!root.loading) root.refresh()
      else scheduleNextPoll()
    }
  }

  onBackgroundUpdatesChanged: scheduleNextPoll()

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
    function toggleSpoiler(): void { root.toggleSpoiler() }
    function sport(name: string): void { root.switchSport(name) }
    function route(tabName: string): void {
      if (tabName === "fixtures" || tabName === "team") root.tabIndex = 0
      else if (tabName === "live") root.tabIndex = 1
      else if (tabName === "standings" || tabName === "table") root.tabIndex = 2
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(530))
    contentHeight: panel.fittedContentHeight(sportsColumn.implicitHeight + Style.space(16))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.anyPopupOpen()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveFocus(dy)
        else root.moveWithin(dx)
      }
      onActivateRequested: root.activateFocus()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        else if (text === "s" || text === "S") root.toggleSpoiler()
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: sportsColumn.implicitHeight + Style.space(16)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: sportsColumn
          x: Style.space(16)
          width: scroll.width - Style.space(32)
          spacing: Style.space(12)
          bottomPadding: Style.space(16)

          Column {
            id: panelBody
            width: parent.width
            spacing: Style.space(10)

            opacity: root.loading && root.hasData ? 0.65 : 1.0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // ---- Header Row ------------------------------------------------
            Item {
              id: headerRow
              width: parent.width
              implicitHeight: Math.max(headerLeft.implicitHeight, headerControls.implicitHeight)

              Row {
                id: headerLeft
                anchors.left: parent.left
                anchors.right: headerControls.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.activeSportIcon
                  font.pixelSize: Style.font.display
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.max(0, headerLeft.width - Style.space(36))
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    text: root.activeSportMeta.label
                    color: root.fgColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: root.statusLine()
                    color: root.errorMessage !== "" ? root.urgentColor : Qt.darker(root.fgColor, 1.45)
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
                spacing: Style.space(6)

                // Notifications Toggle Button
                Button {
                  id: notifyBtn
                  text: ""
                  iconText: root.enableNotifications ? "󰂚" : "󰂛"
                  selected: root.enableNotifications
                  accent: Color.accent
                  foreground: root.fgColor
                  onClicked: root.toggleNotifications()
                }

                // Anti-Spoiler Toggle Button
                Button {
                  id: spoilerBtn
                  text: ""
                  iconText: root.antiSpoiler ? "󰈉" : "󰈈"
                  selected: root.antiSpoiler
                  accent: Color.accent
                  foreground: root.fgColor
                  onClicked: root.toggleSpoiler()
                }

                Button {
                  id: refreshButton
                  text: ""
                  iconText: "󰑐"
                  iconSpinning: root.loading
                  focusable: true
                  hasCursor: root.focusSection === 3
                  foreground: root.fgColor
                  onClicked: root.refresh()
                }

                Item {
                  width: Style.space(96)
                  height: refreshButton.height

                  Dropdown {
                    id: intervalPicker
                    anchors.fill: parent
                    showLabel: false
                    value: root.refreshIntervalLabel()
                    options: root.refreshIntervalOptions
                    hasCursor: root.focusSection === (root.selectedTeamIds.length === 0 ? 4 : 5)
                    foreground: root.fgColor
                    background: Color.popups.background
                    onChanged: function(value) { root.setRefreshMinutes(value) }
                  }
                }
              }
            }

            // Live auto-refresh hint so the interval picker's scope is clear
            Text {
              width: parent.width
              visible: root.liveCount > 0
              text: "● " + root.liveCount + " live — scores update automatically every ~40s"
              color: root.urgentColor
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            // ---- Sport Selector Segmented Row -------------------------------
            Rectangle {
              width: parent.width
              implicitHeight: sportSelectorRow.implicitHeight + Style.space(6)
              radius: Math.min(6, Style.cornerRadius)
              color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.035)
              border.width: 1
              border.color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08)

              Row {
                id: sportSelectorRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(3)
                spacing: Style.space(3)

                Repeater {
                  model: Model.sports()

                  delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: (sportSelectorRow.width - (Model.sports().length - 1) * Style.space(3)) / Model.sports().length
                    implicitHeight: Style.space(26)
                    radius: Math.min(4, Style.cornerRadius)
                    color: root.activeSport === modelData.value
                      ? Util.alpha(Color.accent, 0.20)
                      : (sportMouse.containsMouse ? Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.06) : "transparent")
                    border.width: 1
                    border.color: root.activeSport === modelData.value
                      ? Color.accent
                      : (sportMouse.containsMouse ? Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.10) : "transparent")

                    Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Row {
                      anchors.centerIn: parent
                      spacing: Style.space(4)

                      Text {
                        text: modelData.icon
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        text: modelData.label
                        color: root.activeSport === modelData.value ? Color.accent : Qt.darker(root.fgColor, 1.25)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: root.activeSport === modelData.value
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    MouseArea {
                      id: sportMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.switchSport(modelData.value)
                    }
                  }
                }
              }
            }

            // ---- Tab Navigation Row -----------------------------------------
            Item {
              id: tabsContainer
              width: parent.width
              implicitHeight: tabsGroup.implicitHeight

              Row {
                id: tabsGroup
                anchors.left: parent.left
                spacing: Style.space(6)

                Repeater {
                  model: root.tabOptions

                  delegate: Button {
                    required property var modelData
                    required property int index

                    text: modelData.label
                    iconText: modelData.icon
                    selected: root.tabIndex === index
                    hasCursor: root.focusSection === 0 && root.tabIndex === index && !root.anyPopupOpen()
                    foreground: root.fgColor
                    accent: Color.accent
                    onClicked: {
                      root.tabIndex = index
                      if (index === 2) {
                        root.ensureStandingsSelection()
                        if (root.standingsRows.length === 0 && !root.loading) root.refresh()
                      }
                    }
                  }
                }
              }

              // Live Match Pill
              Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.liveCount > 0 && root.tabIndex !== 1
                implicitWidth: liveRowBadge.implicitWidth + Style.space(12)
                implicitHeight: liveRowBadge.implicitHeight + Style.space(4)
                radius: Math.min(4, Style.cornerRadius)
                color: Util.alpha(root.urgentColor, 0.15)
                border.width: 1
                border.color: root.urgentColor

                Row {
                  id: liveRowBadge
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Rectangle {
                    width: Style.space(5)
                    height: width
                    radius: width / 2
                    color: root.urgentColor
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                      running: root.liveCount > 0
                      loops: Animation.Infinite
                      NumberAnimation { to: 0.25; duration: 500 }
                      NumberAnimation { to: 1.0; duration: 500 }
                    }
                  }

                  Text {
                    text: root.liveCount + " LIVE"
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
                  onClicked: root.tabIndex = 1
                }
              }
            }

            PanelSeparator { foreground: root.fgColor }

            // ================================================================
            // TAB 0: FIXTURES / CALENDAR (Default View)
            // ================================================================
            Column {
              id: fixturesTab
              width: parent.width
              spacing: Style.space(12)
              visible: root.tabIndex === 0

              // ---- Collapsible Setup Section ---------------------------------
              Rectangle {
                id: setupSection
                width: parent.width
                implicitHeight: setupCol.implicitHeight + Style.space(16)
                radius: Style.cornerRadius
                color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.02)
                border.width: 1
                border.color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08)

                Column {
                  id: setupCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(12)
                  spacing: Style.space(10)

                  Item {
                    width: parent.width
                    implicitHeight: Math.max(setupSecHeader.implicitHeight, setupToggleBtn.implicitHeight)

                    PanelSectionHeader {
                      id: setupSecHeader
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      text: (root.activeSport === "f1" ? "FAVORITE DRIVER & PREFERENCES" : ("FOLLOWED " + root.activeSportMeta.label.toUpperCase() + " & CLUBS"))
                      foreground: root.fgColor
                    }

                    Button {
                      id: setupToggleBtn
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.setupExpanded ? "Done" : "Edit"
                      iconText: root.setupExpanded ? "󰅃" : "󰅀"
                      visible: root.selectedTeamIds.length > 0 || (root.activeSport === "football" && root.selectedLeagueIds.length > 0)
                      foreground: root.fgColor
                      onClicked: root.setupExpanded = !root.setupExpanded
                    }
                  }

                  // Collapsed Summary Row
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: !root.setupExpanded && (root.selectedTeamIds.length > 0 || (root.activeSport === "football" && root.selectedLeagueIds.length > 0))

                    Rectangle {
                      implicitWidth: summaryPillRow.implicitWidth + Style.space(14)
                      implicitHeight: summaryPillRow.implicitHeight + Style.space(6)
                      radius: Math.min(4, Style.cornerRadius)
                      color: summaryMouse.containsMouse
                        ? Style.hoverFillFor(root.fgColor, Color.accent)
                        : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.05)
                      border.width: 1
                      border.color: summaryMouse.containsMouse
                        ? Color.accent
                        : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.10)

                      Row {
                        id: summaryPillRow
                        anchors.centerIn: parent
                        spacing: Style.space(6)

                        Text {
                          visible: root.activeSport === "football"
                          text: "🏆 " + root.selectedLeagueIds.length + " Leagues"
                          color: root.fgColor
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        Text {
                          visible: root.activeSport === "football" && root.selectedTeamIds.length > 0
                          text: "·"
                          color: Qt.darker(root.fgColor, 1.5)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                        }

                        Text {
                          visible: root.selectedTeamIds.length > 0
                          text: root.selectedTeamIds.length === 1 ? ("★ " + root.teamNameFor(root.selectedTeamIds[0])) : ("★ " + root.selectedTeamIds.length + " Followed Favorites")
                          color: Color.accent
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }

                      MouseArea {
                        id: summaryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setupExpanded = true
                      }
                    }
                  }

                  // Full Editor
                  Column {
                    width: parent.width
                    spacing: Style.space(10)
                    visible: root.setupExpanded || (root.activeSport === "football" && root.selectedLeagueIds.length === 0) || root.selectedTeamIds.length === 0

                    // League Picker (Football only)
                    FocusScope {
                      id: leagueScope
                      width: parent.width
                      height: leaguePicker.implicitHeight
                      visible: root.activeSport === "football"

                      MultiSelect {
                        id: leaguePicker
                        anchors.fill: parent
                        label: "Followed leagues (up to 12)"
                        values: root.selectedLeagueIds
                        options: root.sortedLeagueOptions
                        placeholderText: "Search leagues (e.g. Premier, La Liga, Primeira)…"
                        emptyText: "No leagues match"
                        noSelectionText: "Select up to 12 followed leagues"
                        popupRowHeight: Style.space(48)
                        popupMinHeight: Style.space(180)
                        hasCursor: root.focusSection === 1
                        foreground: root.fgColor
                        background: Color.popups.background
                        onChanged: function(values) { root.setSelectedLeagues(values) }
                      }
                    }

                    // Selected League Badges (Football only)
                    Flow {
                      width: parent.width
                      spacing: Style.space(6)
                      visible: root.activeSport === "football" && root.selectedLeagueIds.length > 0

                      Repeater {
                        model: root.selectedLeagueIds

                        delegate: Rectangle {
                          required property var modelData
                          required property int index

                          implicitWidth: chipRow.implicitWidth + Style.space(14)
                          implicitHeight: chipRow.implicitHeight + Style.space(6)
                          radius: Math.min(4, Style.cornerRadius)
                          color: chipMouse.containsMouse
                            ? Style.hoverFillFor(root.fgColor, root.urgentColor)
                            : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.06)
                          border.width: 1
                          border.color: chipMouse.containsMouse
                            ? root.urgentColor
                            : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.14)

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
                              text: "✕"
                              color: chipMouse.containsMouse ? root.urgentColor : Qt.darker(root.fgColor, 1.5)
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
                            onClicked: {
                              var arr = Model.arrayFrom(root.selectedLeagueIds)
                              var idx = arr.indexOf(String(modelData))
                              if (idx !== -1) {
                                arr.splice(idx, 1)
                                root.setSelectedLeagues(arr)
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
                        width: root.selectedTeamIds.length > 0 ? parent.width - clearButton.width - Style.space(8) : parent.width
                        height: teamPicker.implicitHeight

                        SearchableDropdown {
                          id: teamPicker
                          anchors.fill: parent
                          label: root.activeSport === "f1" ? "Follow Favorite Drivers / Teams" : "Follow Favorite Clubs / Teams"
                          value: ""
                          options: root.combinedTeamOptions
                          placeholderText: root.activeSport === "f1" ? "Search driver or constructor to follow…" : "Search team to follow…"
                          triggerLabel: root.activeSport === "f1" ? "Add / select favorite driver" : "Add / select favorite team"
                          emptyText: "No results match search"
                          popupRowHeight: Style.space(48)
                          popupMinHeight: Style.space(200)
                          hasCursor: root.focusSection === 2
                          foreground: root.fgColor
                          background: Color.popups.background
                          onChanged: function(value) { root.toggleSelectedTeam(value) }
                        }
                      }

                      Button {
                        id: clearButton
                        visible: root.selectedTeamIds.length > 0
                        text: ""
                        iconText: "󰅖"
                        bordered: true
                        focusable: true
                        hasCursor: root.focusSection === 4 && root.selectedTeamIds.length > 0
                        foreground: root.fgColor
                        anchors.bottom: teamScope.bottom
                        onClicked: root.clearSelectedTeam()
                      }
                    }

                    // Followed Favorite Team Badges
                    Flow {
                      width: parent.width
                      spacing: Style.space(6)
                      visible: root.selectedTeamIds.length > 0

                      Repeater {
                        model: root.selectedTeamIds

                        delegate: Rectangle {
                          required property var modelData
                          required property int index

                          implicitWidth: favTeamChipRow.implicitWidth + Style.space(14)
                          implicitHeight: favTeamChipRow.implicitHeight + Style.space(6)
                          radius: Math.min(4, Style.cornerRadius)
                          color: favChipMouse.containsMouse
                            ? Style.hoverFillFor(root.fgColor, root.urgentColor)
                            : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
                          border.width: 1
                          border.color: favChipMouse.containsMouse
                            ? root.urgentColor
                            : Color.accent

                          Row {
                            id: favTeamChipRow
                            anchors.centerIn: parent
                            spacing: Style.space(6)

                            Text {
                              text: "★ " + root.teamNameFor(modelData)
                              color: Color.accent
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                              font.bold: true
                            }

                            Text {
                              text: "✕"
                              color: favChipMouse.containsMouse ? root.urgentColor : Qt.darker(root.fgColor, 1.5)
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
                            onClicked: root.removeSelectedTeam(modelData)
                          }
                        }
                      }
                    }
                  }
                }
              }

              // ---- Spotlight Featured Card ----------------------------------
              MatchSpotlight {
                visible: (root.selectedTeamIds.length > 0 && root.featuredMatch !== null) || (root.activeSport === "f1" && root.allMatches.length > 0)
                featuredMatch: root.featuredMatch
                fallbackMatch: root.activeSport === "f1" && root.allMatches.length > 0 ? root.allMatches[0] : null
                isF1: root.activeSport === "f1"
                activeSport: root.activeSport
                fgColor: root.fgColor
                urgentColor: root.urgentColor
                selectedTeamId: root.selectedTeamId
                selectedTeamIds: root.selectedTeamIds
                selectedTeamName: root.selectedTeamName
                antiSpoiler: root.antiSpoiler
                revealedMatchIds: root.revealedMatchIds
                favoriteDriverStanding: root.favoriteDriverStanding
                kickoffTime: root.kickoffTime
                matchSubline: root.matchSubline
                openMatch: root.openMatch
                revealMatch: root.revealMatch
              }

              // ---- Schedule Header with Filter -----------------------------
              Item {
                width: parent.width
                implicitHeight: Math.max(schedTitle.implicitHeight, fixtureFilterScope.implicitHeight)
                visible: root.hasData

                Text {
                  id: schedTitle
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.activeFixtureHeader
                  color: Qt.darker(root.fgColor, 1.4)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                FocusScope {
                  id: fixtureFilterScope
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(220)
                  height: fixtureFilterDropdown.implicitHeight
                  visible: root.fixtureFilterOptions.length > 1

                  Dropdown {
                    id: fixtureFilterDropdown
                    anchors.fill: parent
                    label: ""
                    showLabel: false
                    value: root.fixtureFilterId
                    options: root.fixtureFilterOptions
                    foreground: root.fgColor
                    background: Color.popups.background
                    onChanged: function(val) { root.fixtureFilterId = String(val || "all") }
                  }
                }
              }

              Text {
                width: parent.width
                visible: root.activeFixturesList.length === 0 && !root.loading && root.hasData
                text: "No matches found for this selection — press R to reload."
                color: Qt.darker(root.fgColor, 1.35)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }

              Column {
                width: parent.width
                spacing: Style.space(12)

                Repeater {
                  model: root.matchGroups

                  delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: Style.space(6)

                    Item {
                      width: parent.width
                      implicitHeight: groupLabel.implicitHeight + Style.space(4)

                      Text {
                        id: groupLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label.toUpperCase()
                        color: modelData.label === "Live Matches" ? root.urgentColor : Qt.darker(root.fgColor, 1.45)
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
                        color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08)
                      }
                    }

                    Column {
                      width: parent.width
                      spacing: Style.space(6)

                      Repeater {
                        model: modelData.matches
                        delegate: MatchRow {
                          activeSport: root.activeSport
                          fgColor: root.fgColor
                          urgentColor: root.urgentColor
                          selectedTeamId: root.selectedTeamId
                          antiSpoiler: root.antiSpoiler
                          revealedMatchIds: root.revealedMatchIds
                          nowMs: root.nowMs
                          revealMatch: root.revealMatch
                          openMatch: root.openMatch
                        }
                      }
                    }
                  }
                }
              }
            }

            // ================================================================
            // TAB 1: LIVE MATCHES
            // ================================================================
            Column {
              id: liveTab
              width: parent.width
              spacing: Style.space(10)
              visible: root.tabIndex === 1

              PanelSectionHeader {
                text: root.liveCount > 0 ? "LIVE NOW · " + (root.liveCount === 1 ? "1 MATCH" : root.liveCount + " MATCHES") : "LIVE MATCHES"
                foreground: root.fgColor
              }

              // Empty state
              Rectangle {
                width: parent.width
                implicitHeight: noLiveCol.implicitHeight + Style.space(24)
                visible: root.liveCount === 0
                radius: Style.cornerRadius
                color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.03)
                border.width: 1
                border.color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08)

                Column {
                  id: noLiveCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(16)
                  spacing: Style.space(8)

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "●"
                    color: root.urgentColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.display
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.hasData
                      ? "No live events in progress right now for " + root.activeSportMeta.label + "."
                      : "Load " + root.activeSportMeta.label + " schedule to see live scores."
                    color: Qt.darker(root.fgColor, 1.35)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    width: parent.width
                  }

                  Rectangle {
                    visible: root.nextKickoffText !== ""
                    width: parent.width
                    implicitHeight: nextCol.implicitHeight + Style.space(12)
                    radius: Math.min(4, Style.cornerRadius)
                    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08)
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
                        text: root.nextKickoffText
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
                  model: Model.liveMatches(root.allMatches, root.matchDetails)
                  delegate: LiveRow {
                    activeSport: root.activeSport
                    activeSportIcon: root.activeSportIcon
                    fgColor: root.fgColor
                    urgentColor: root.urgentColor
                    matchDetails: root.matchDetails
                    matchSubline: root.matchSubline
                    openMatch: root.openMatch
                    nowMs: root.nowMs
                    fetchedAtMs: root.lastUpdated.getTime()
                  }
                }
              }
            }

            // ================================================================
            // TAB 2: STANDINGS TABLE
            // ================================================================
            Column {
              id: tableTab
              width: parent.width
              spacing: Style.space(10)
              visible: root.tabIndex === 2

              Item {
                width: parent.width
                implicitHeight: Math.max(tableTitle.implicitHeight, standingsScope.implicitHeight)

                Text {
                  id: tableTitle
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.activeSportMeta.label.toUpperCase() + " STANDINGS"
                  color: Qt.darker(root.fgColor, 1.4)
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
                  visible: root.standingsOptions.length > 1

                  Dropdown {
                    id: standingsPicker
                    anchors.fill: parent
                    label: ""
                    showLabel: false
                    value: root.standingsLeagueId
                    options: root.standingsOptions
                    hasCursor: root.focusSection === 6
                    foreground: root.fgColor
                    background: Color.popups.background
                    onChanged: function(value) { root.setStandingsLeague(value) }
                  }
                }
              }

              Text {
                width: parent.width
                visible: root.standingsRows.length === 0
                text: "Refresh (R) to load standings."
                color: Qt.darker(root.fgColor, 1.35)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }

              // Table Card Container
              Rectangle {
                width: parent.width
                implicitHeight: tableCardCol.implicitHeight + Style.space(16)
                visible: root.standingsRows.length > 0
                radius: Style.cornerRadius
                color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.02)
                border.width: 1
                border.color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08)

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
                      visible: root.activeSport === "football"
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

                    // NBA / NHL / MLB / NFL Header
                    Row {
                      visible: root.activeSport === "nba" || root.activeSport === "nhl" || root.activeSport === "mlb" || root.activeSport === "nfl"
                      width: parent.width
                      anchors.leftMargin: Style.space(6)
                      anchors.rightMargin: Style.space(6)

                      Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
                      Text { width: parent.width - Style.space(190); text: "TEAM"; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: Style.space(28); text: "W"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: Style.space(28); text: "L"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: Style.space(36); text: "PCT"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: Style.space(34); text: root.activeSport === "mlb" ? "GB" : "DIFF"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: Style.space(36); text: "PTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                    }

                    // F1 Drivers Header
                    Row {
                      visible: root.activeSport === "f1" && (root.standingsLeagueId === "Drivers" || root.standingsLeagueId === "" || root.standingsLeagueId.indexOf("Construct") === -1)
                      width: parent.width
                      anchors.leftMargin: Style.space(6)
                      anchors.rightMargin: Style.space(6)

                      Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
                      Text { width: Style.space(160); text: "DRIVER"; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: parent.width - Style.space(290); text: "CONSTRUCTOR"; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: Style.space(36); text: "WINS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: Style.space(52); text: "POINTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                    }

                    // F1 Constructors Header
                    Row {
                      visible: root.activeSport === "f1" && (root.standingsLeagueId === "Constructors" || root.standingsLeagueId.indexOf("Construct") !== -1)
                      width: parent.width
                      anchors.leftMargin: Style.space(6)
                      anchors.rightMargin: Style.space(6)

                      Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
                      Text { width: Style.space(170); text: "CONSTRUCTOR"; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: parent.width - Style.space(300); text: "COUNTRY"; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: Style.space(36); text: "WINS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                      Text { width: Style.space(52); text: "POINTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                    }
                  }

                  Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08)
                  }

                  // Table Rows
                  Column {
                    width: parent.width
                    spacing: 0

                    Repeater {
                      model: root.standingsRows
                      delegate: StandingsRow {
                        activeSport: root.activeSport
                        standingsLeagueId: root.standingsLeagueId
                        selectedTeamId: root.selectedTeamId
                        selectedTeamName: root.selectedTeamName
                        fgColor: root.fgColor
                        urgentColor: root.urgentColor
                      }
                    }
                  }
                }
              }

              // Legend
              Row {
                visible: root.standingsRows.length > 0
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
                    text: root.activeSport === "f1" ? "Podium / P1" : "Playoffs / Europe"
                    color: Qt.darker(root.fgColor, 1.4)
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
                    color: Qt.darker(root.fgColor, 1.4)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
