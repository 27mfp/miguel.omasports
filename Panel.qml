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
  property string ignoredStateSignature: ""

  // Anti-Spoiler Mode
  property bool antiSpoiler: false
  property var revealedMatchIds: ({})

  // Sport-specific selections
  property var selectedLeagueIds: ["61"]
  property string selectedTeamId: ""
  property string standingsLeagueId: "61"

  // ---- Match data --------------------------------------------------------
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

  // Combined team options ensuring saved favorite is always present and searchable
  readonly property var combinedTeamOptions: {
    var base = Model.arrayFrom(baseTeamOptions)
    var curId = String(selectedTeamId || "")
    var curName = ""
    if (activeSport === "football") curName = String((savedState.football && savedState.football.teamName) || "")
    else if (savedState[activeSport]) curName = String(savedState[activeSport].teamName || "")

    if (curId !== "" && curName !== "") {
      var found = false
      for (var i = 0; i < base.length; i++) {
        if (String(base[i].value) === curId) { found = true; break }
      }
      if (!found) {
        base.unshift({ value: curId, label: curName, description: "Saved favorite" })
      }
    }
    return base
  }

  // ---- Fixtures League / Matchday / Team Filter --------------------------
  property string fixtureFilterId: activeSport === "f1" ? "all" : (selectedTeamId !== "" ? "team" : "all")

  readonly property var fixtureFilterOptions: {
    var opts = []
    if (activeSport === "f1") {
      opts.push({ value: "all", label: "🏁 2026 Grand Prix Calendar" })
      if (selectedTeamId !== "") {
        opts.push({ value: "team", label: "★ " + (selectedTeamName || "My Favorite Driver") })
      }
      return opts
    }

    if (selectedTeamId !== "") {
      opts.push({ value: "team", label: "★ " + (selectedTeamName || "My Favorite") })
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
    if (fixtureFilterId === "team" && selectedTeamId !== "") {
      return teamMatches
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
    if (multiSportStandings && multiSportStandings[id]) {
      return Model.arrayFrom(multiSportStandings[id])
    }
    for (var k in multiSportStandings) {
      if (multiSportStandings[k] && multiSportStandings[k].length > 0)
        return multiSportStandings[k]
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
    return Model.matchesForTeam(allMatches, selectedTeamId, activeSport)
  }
  readonly property var featuredMatch: Model.featuredMatchForTeam(teamMatches)
  readonly property string selectedTeamName: selectedTeamLabel()
  readonly property string selectedLeagueNames: selectedLeagueNameList()

  // Bar badge + summary
  readonly property bool favoriteTeamLive: {
    var source = teamMatches
    for (var i = 0; i < source.length; i++)
      if (source[i].status === "live") return true
    return false
  }
  readonly property string favoriteSummaryText: {
    if (favoriteTeamLive) {
      for (var i = 0; i < teamMatches.length; i++) {
        var m = teamMatches[i]
        if (m.status === "live") {
          var h = (m.home.shortName || m.home.name).slice(0, 3).toUpperCase()
          var a = (m.away.shortName || m.away.name).slice(0, 3).toUpperCase()
          return h + " " + (m.scoreText || "0–0") + " " + a + (m.liveTime ? " " + m.liveTime : "")
        }
      }
    }
    if (selectedTeamId === "" || teamMatches.length === 0) return ""
    var first = teamMatches[0]
    var status = Model.matchStatusText(first)
    return selectedTeamName + " · " + status + (first.scoreText && first.status !== "upcoming" ? " " + first.scoreText : "")
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
    if (activeSport === sportValue) return
    activeSport = String(sportValue)
    savedState.sport = activeSport
    restoreSportSelections()
    fixtureFilterId = activeSport === "f1" ? "all" : (selectedTeamId !== "" ? "team" : "all")
    persistState()
    allMatches = []
    teamMatchesRaw = []
    multiSportStandings = {}
    lastPages = []
    matchDetails = {}
    refresh()
  }

  function restoreSportSelections() {
    if (activeSport === "football") {
      var fb = savedState.football || {}
      selectedLeagueIds = Model.normalizeLeagueIds(fb.leagueIds)
      if (selectedLeagueIds.length === 0) selectedLeagueIds = ["61"]
      selectedTeamId = String(fb.teamId || "")
      standingsLeagueId = String(fb.standingsLeagueId || selectedLeagueIds[0])
    } else {
      var sp = savedState[activeSport] || {}
      selectedTeamId = String(sp.teamId || "")
      standingsLeagueId = String(sp.standingsGroup || (standingsOptions.length > 0 ? standingsOptions[0].value : ""))
    }
  }

  function toggleSpoiler() {
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

  function isMatchRevealed(matchId) {
    return !antiSpoiler || revealedMatchIds[String(matchId)] === true
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
      if (root.stateLoaded && !root.loading && needsAutoRefresh()) root.refresh()
      else if (!root.loading && detailQueue.length > 0) Qt.callLater(root.nextDetail)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    openedFromHotkey = false
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
    restoreSportSelections()
    stateLoaded = true

    if (leaguePicker) leaguePicker.values = selectedLeagueIds
    ensureStandingsSelection()
    if (root.opened && !root.loading && !ownWrite && root.needsAutoRefresh()) Qt.callLater(root.refresh)
  }

  function persistState() {
    if (!stateLoaded) return
    var curSport = activeSport
    var sportSettings = {}
    if (curSport === "nba") {
      sportSettings.nba = { teamId: selectedTeamId, teamName: selectedTeamName, standingsGroup: standingsLeagueId }
    } else if (curSport === "f1") {
      sportSettings.f1 = { teamId: selectedTeamId, teamName: selectedTeamName, standingsGroup: standingsLeagueId }
    } else if (curSport === "nfl") {
      sportSettings.nfl = { teamId: selectedTeamId, teamName: selectedTeamName, standingsGroup: standingsLeagueId }
    } else if (curSport === "mlb") {
      sportSettings.mlb = { teamId: selectedTeamId, teamName: selectedTeamName, standingsGroup: standingsLeagueId }
    } else if (curSport === "nhl") {
      sportSettings.nhl = { teamId: selectedTeamId, teamName: selectedTeamName, standingsGroup: standingsLeagueId }
    }

    var fb = savedState.football || {}
    savedState = Model.statePayload(
      curSport,
      fb.leagueIds || selectedLeagueIds,
      curSport === "football" ? selectedTeamId : fb.teamId,
      curSport === "football" ? selectedTeamName : fb.teamName,
      savedState.refreshMinutes,
      curSport === "football" ? standingsLeagueId : fb.standingsLeagueId,
      sportSettings,
      antiSpoiler
    )
    ignoredStateSignature = JSON.stringify(savedState)
    stateFile.setText(JSON.stringify(savedState, null, 2) + "\n")
  }

  function setSelectedLeagues(values) {
    var next = Model.normalizeLeagueIds(values)
    selectedLeagueIds = next
    if (leaguePicker) leaguePicker.values = next
    ensureStandingsSelection()
    persistState()
    if (root.opened || root.backgroundUpdates) root.refresh()
  }

  function setSelectedTeam(value) {
    selectedTeamId = String(value || "")
    teamMatchesRaw = []
    if (teamPicker) teamPicker.value = selectedTeamId
    persistState()
    if (activeSport === "football" && selectedTeamId !== "") root.fetchFootballTeamPage()
  }

  function clearSelectedTeam() {
    root.setSelectedTeam("")
  }

  function setRefreshMinutes(value) {
    var minutes = Math.max(5, Math.min(60, parseInt(value, 10) || 15))
    savedState.refreshMinutes = minutes
    persistState()
    refreshTimer.restart()
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

    if (pages.length === 0 && !hasData) {
      errorMessage = "Unable to load matches. Check your connection."
    } else if (failedLeagues.length > 0) {
      errorMessage = "Some leagues could not be loaded: " + failedLeagues.join(", ")
    }
  }

  // ---- ESPN Scoreboard & Standings (NBA, NFL, MLB, NHL) ---------------------
  function startEspnRound(espnSportPath, sportCode, defaultName) {
    workerScoreboard.handled = false
    workerScoreboard.serial = root.requestSerial
    workerScoreboard.sportCode = sportCode
    workerScoreboard.defaultName = defaultName
    workerScoreboard.command = ["curl", "-LfsS", "--max-time", "10", "https://site.api.espn.com/apis/site/v2/sports/" + espnSportPath + "/scoreboard"]
    workerScoreboard.running = true

    workerStandings.handled = false
    workerStandings.serial = root.requestSerial
    workerStandings.sportCode = sportCode
    workerStandings.command = ["curl", "-LfsS", "--max-time", "10", "https://site.api.espn.com/apis/v2/sports/" + espnSportPath + "/standings"]
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
      loading = false
      ensureStandingsSelection()
      downloadMissingLogos()
      if (allMatches.length === 0 && Object.keys(multiSportStandings).length === 0) {
        errorMessage = "Unable to load " + activeSportMeta.label + " data. Check connection."
      }
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
      loading = false
      ensureStandingsSelection()
      downloadMissingLogos()
      if (allMatches.length === 0) {
        errorMessage = "Unable to load F1 race calendar. Check connection."
      }
    }
  }

  function downloadMissingLogos() {
    if (logoCacheProc.running) return
    var items = []
    var seen = {}

    // Collect all matches home/away
    var ms = Model.arrayFrom(allMatches)
    for (var i = 0; i < ms.length; i++) {
      var m = ms[i]
      if (!m) continue
      var sp = String(m.sport || root.activeSport || "football").toLowerCase()
      if (m.home && m.home.id && m.home.logo && m.home.logo.indexOf("http") === 0) {
        var k1 = sp + "-" + (m.home.abbr || m.home.id).toLowerCase().replace(/[^a-z0-9_-]/g, "")
        if (!seen[k1]) {
          seen[k1] = true
          items.push({ url: m.home.logo, key: k1 })
        }
      }
      if (m.away && m.away.id && m.away.logo && m.away.logo.indexOf("http") === 0) {
        var k2 = sp + "-" + (m.away.abbr || m.away.id).toLowerCase().replace(/[^a-z0-9_-]/g, "")
        if (!seen[k2]) {
          seen[k2] = true
          items.push({ url: m.away.logo, key: k2 })
        }
      }
    }

    // Collect all standings logos
    var st = Model.arrayFrom(standingsRows)
    for (var j = 0; j < st.length; j++) {
      var row = st[j]
      if (row && row.id && row.logo && row.logo.indexOf("http") === 0) {
        var sp2 = String(root.activeSport || "football").toLowerCase()
        var k3 = sp2 + "-" + (row.abbr || row.id).toLowerCase().replace(/[^a-z0-9_-]/g, "")
        if (!seen[k3]) {
          seen[k3] = true
          items.push({ url: row.logo, key: k3 })
        }
      }
    }

    if (items.length === 0) return

    var cmd = ["curl", "-sL", "--parallel", "--create-dirs"]
    var count = 0
    var cacheDir = Quickshell.env("HOME") + "/.cache/omarchy-matchday/logos/"
    for (var c = 0; c < items.length && count < 36; c++) {
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
    return "󰥔 Updated " + Qt.formatDateTime(lastUpdated, "HH:mm")
  }

  // ---- Self-heal ------------------------------------------------------------
  Timer {
    interval: 1500
    running: true
    onTriggered: {
      stateFile.reload()
      if (root.backgroundUpdates) root.refresh()
    }
  }

  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.config/omarchy/sports-favorites.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyState(text())
    onLoadFailed: root.applyState("")
    onFileChanged: reload()
  }

  Process { id: matchOpener }
  Process { id: logoCacheProc }

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
          var cur = multiSportStandings || {}
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
          var cur = multiSportStandings || {}
          cur["Constructors"] = con
          multiSportStandings = cur
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

  Timer {
    id: refreshTimer
    interval: Math.max(5, parseInt(root.savedState.refreshMinutes || 15, 10)) * 60 * 1000
    repeat: true
    running: root.opened || root.backgroundUpdates
    onTriggered: root.refresh()
  }

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
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.activeSportIcon
                  font.pixelSize: Style.font.display
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    text: root.activeSportMeta.label
                    color: root.fgColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.heading
                    font.bold: true
                  }

                  Text {
                    text: root.statusLine()
                    color: root.errorMessage !== "" ? root.urgentColor : Qt.darker(root.fgColor, 1.45)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              Row {
                id: headerControls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

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
                    hasCursor: root.focusSection === (root.selectedTeamId === "" ? 4 : 5)
                    foreground: root.fgColor
                    background: Color.popups.background
                    onChanged: function(value) { root.setRefreshMinutes(value) }
                  }
                }
              }
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
                        color: root.activeSport === modelData.value ? Color.accent : Qt.darker(root.fgColor, 1.2)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: root.activeSport === modelData.value
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
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
                    onClicked: root.tabIndex = index
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
                    text: (root.liveCount === 1 ? "1 LIVE" : root.liveCount + " LIVE")
                    color: root.urgentColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
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
            // TAB 0: FIXTURES & FAVORITES
            // ================================================================
            Column {
              id: teamTab
              width: parent.width
              spacing: Style.space(12)
              visible: root.tabIndex === 0

              // ---- Setup / Picker Card --------------------------------------
              Rectangle {
                id: setupCard
                width: parent.width
                implicitHeight: setupCol.implicitHeight + Style.space(20)
                radius: Style.cornerRadius
                color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.03)
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
                      text: (root.activeSport === "f1" ? "FAVORITE DRIVER & PREFERENCES" : ("FOLLOWED " + root.activeSportMeta.label.toUpperCase() + " & CLUB"))
                      foreground: root.fgColor
                    }

                    Button {
                      id: setupToggleBtn
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.setupExpanded ? "Done" : "Edit"
                      iconText: root.setupExpanded ? "󰅃" : "󰅀"
                      visible: root.selectedTeamId !== "" || (root.activeSport === "football" && root.selectedLeagueIds.length > 0)
                      foreground: root.fgColor
                      onClicked: root.setupExpanded = !root.setupExpanded
                    }
                  }

                  // Collapsed Summary Row
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: !root.setupExpanded && (root.selectedTeamId !== "" || (root.activeSport === "football" && root.selectedLeagueIds.length > 0))

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
                          text: "🏆 " + root.selectedLeagueIds.length + " Followed Leagues"
                          color: root.fgColor
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        Text {
                          visible: root.activeSport === "football" && root.selectedTeamId !== ""
                          text: "·"
                          color: Qt.darker(root.fgColor, 1.5)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                        }

                        Text {
                          visible: root.selectedTeamId !== ""
                          text: "★ " + root.selectedTeamName
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
                    visible: root.setupExpanded || (root.activeSport === "football" && root.selectedLeagueIds.length === 0) || root.selectedTeamId === ""

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
                        width: root.selectedTeamId !== "" ? parent.width - clearButton.width - Style.space(8) : parent.width
                        height: teamPicker.implicitHeight

                        SearchableDropdown {
                          id: teamPicker
                          anchors.fill: parent
                          label: root.activeSport === "f1" ? "Favorite Driver / Team" : "Favorite Club / Team"
                          value: root.selectedTeamId
                          options: root.combinedTeamOptions
                          placeholderText: root.activeSport === "f1" ? "Search driver or constructor…" : "Search team by name…"
                          triggerLabel: root.activeSport === "f1" ? "Choose favorite driver" : "Choose favorite team"
                          emptyText: "No results match search"
                          popupRowHeight: Style.space(48)
                          popupMinHeight: Style.space(200)
                          hasCursor: root.focusSection === 2
                          foreground: root.fgColor
                          background: Color.popups.background
                          onChanged: function(value) { root.setSelectedTeam(value) }
                        }
                      }

                      Button {
                        id: clearButton
                        visible: root.selectedTeamId !== ""
                        text: ""
                        iconText: "󰅖"
                        bordered: true
                        focusable: true
                        hasCursor: root.focusSection === 4 && root.selectedTeamId !== ""
                        foreground: root.fgColor
                        anchors.bottom: teamScope.bottom
                        onClicked: root.clearSelectedTeam()
                      }
                    }
                  }
                }
              }

              // ---- Spotlight Featured Card ----------------------------------
              Item {
                id: spotlightCard
                width: parent.width
                implicitHeight: spotlightSurface.implicitHeight
                visible: (root.selectedTeamId !== "" && root.featuredMatch !== null) || (root.activeSport === "f1" && root.allMatches.length > 0)

                readonly property var match: root.featuredMatch || (root.activeSport === "f1" && root.allMatches.length > 0 ? root.allMatches[0] : null)
                readonly property bool isF1: root.activeSport === "f1"
                readonly property bool isLive: match && match.status === "live"
                readonly property bool isUpcoming: match && match.status === "upcoming"
                readonly property bool isFinished: match && match.status === "finished"
                readonly property string outcome: match ? Model.teamOutcome(match, root.selectedTeamId) : ""
                readonly property bool scoreHidden: root.antiSpoiler && isFinished && !root.isMatchRevealed(match ? match.id : "")

                Rectangle {
                  id: spotlightSurface
                  width: parent.width
                  implicitHeight: spotlightCol.implicitHeight + Style.space(24)
                  radius: Style.cornerRadius
                  color: spotlightMouse.containsMouse
                    ? Style.hoverFillFor(root.fgColor, Color.accent)
                    : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.035)
                  border.width: 1
                  border.color: spotlightMouse.containsMouse
                    ? Color.accent
                    : (spotlightCard.isLive ? root.urgentColor : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.12))

                  Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                  Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

                  Column {
                    id: spotlightCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(14)
                    spacing: Style.space(12)

                    // Top Row
                    Item {
                      id: spotlightTopRow
                      width: parent.width
                      implicitHeight: Math.max(spotlightTags.implicitHeight, spotlightStatusPill.implicitHeight)

                      Row {
                        id: spotlightTags
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(8)

                        Rectangle {
                          implicitWidth: spotlightTagLabel.implicitWidth + Style.space(8)
                          implicitHeight: spotlightTagLabel.implicitHeight + Style.space(4)
                          radius: Math.min(3, Style.cornerRadius)
                          color: Util.alpha(Color.accent, 0.18)
                          anchors.verticalCenter: parent.verticalCenter

                          Text {
                            id: spotlightTagLabel
                            anchors.centerIn: parent
                            text: spotlightCard.isF1 ? "GRAND PRIX" : "SPOTLIGHT"
                            color: Color.accent
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 0.8
                          }
                        }

                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          text: (spotlightCard.match ? spotlightCard.match.leagueName : "") + (spotlightCard.match && spotlightCard.match.round ? " · " + spotlightCard.match.round : "")
                          color: Qt.darker(root.fgColor, 1.35)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }

                      Rectangle {
                        id: spotlightStatusPill
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: statusPillRow.implicitWidth + Style.space(10)
                        implicitHeight: statusPillRow.implicitHeight + Style.space(4)
                        radius: Math.min(4, Style.cornerRadius)
                        color: spotlightCard.isLive
                          ? root.urgentColor
                          : (spotlightCard.outcome === "win" && !spotlightCard.scoreHidden
                             ? Color.accent
                             : (spotlightCard.outcome === "loss" && !spotlightCard.scoreHidden ? root.urgentColor : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.10)))

                        Row {
                          id: statusPillRow
                          anchors.centerIn: parent
                          spacing: Style.space(4)

                          Rectangle {
                            visible: spotlightCard.isLive
                            width: Style.space(5)
                            height: width
                            radius: width / 2
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on opacity {
                              running: spotlightCard.isLive
                              loops: Animation.Infinite
                              NumberAnimation { to: 0.2; duration: 500 }
                              NumberAnimation { to: 1.0; duration: 500 }
                            }
                          }

                          Text {
                            text: spotlightCard.isLive
                              ? ("LIVE " + (spotlightCard.match ? spotlightCard.match.liveTime : ""))
                              : (spotlightCard.match && spotlightCard.match.status === "finished"
                                 ? (spotlightCard.scoreHidden ? "FT · REVEAL 󰈈" : ("FT" + (spotlightCard.outcome ? " · " + spotlightCard.outcome.toUpperCase() : "")))
                                 : (spotlightCard.match ? Qt.formatDateTime(new Date(Date.parse(spotlightCard.match.time || "")), "ddd d MMM · HH:mm") : ""))
                            color: (spotlightCard.isLive || (!spotlightCard.scoreHidden && (spotlightCard.outcome === "win" || spotlightCard.outcome === "loss"))) ? "#ffffff" : root.fgColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }
                        }
                      }
                    }

                    // F1 Specific Spotlight Layout
                    Item {
                      width: parent.width
                      implicitHeight: f1HeroCol.implicitHeight
                      visible: spotlightCard.isF1

                      Column {
                        id: f1HeroCol
                        width: parent.width
                        spacing: Style.space(4)

                        Row {
                          width: parent.width
                          spacing: Style.space(10)

                          Text {
                            text: (spotlightCard.match && spotlightCard.match.countryFlag) ? spotlightCard.match.countryFlag : "🏎"
                            font.pixelSize: Style.font.display
                            anchors.verticalCenter: parent.verticalCenter
                          }

                          Column {
                            width: parent.width - Style.space(46)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(2)

                            Text {
                              width: parent.width
                              text: spotlightCard.match ? (spotlightCard.match.raceName || spotlightCard.match.home.name) : "Grand Prix"
                              color: root.fgColor
                              font.family: Style.font.family
                              font.pixelSize: Style.font.title
                              font.bold: true
                              elide: Text.ElideRight
                            }

                            Text {
                              width: parent.width
                              text: spotlightCard.match ? ((spotlightCard.match.circuitName || "") + (spotlightCard.match.locality ? " · " + spotlightCard.match.locality : "") + (spotlightCard.match.country ? ", " + spotlightCard.match.country : "")) : ""
                              color: Qt.darker(root.fgColor, 1.45)
                              font.family: Style.font.family
                              font.pixelSize: Style.font.bodySmall
                              elide: Text.ElideRight
                            }
                          }
                        }

                        // Driver standing badge if driver followed
                        Rectangle {
                          visible: root.favoriteDriverStanding !== null
                          implicitWidth: driverPillRow.implicitWidth + Style.space(14)
                          implicitHeight: driverPillRow.implicitHeight + Style.space(6)
                          radius: Math.min(4, Style.cornerRadius)
                          color: Util.alpha(Color.accent, 0.12)
                          border.width: 1
                          border.color: Color.accent

                          Row {
                            id: driverPillRow
                            anchors.centerIn: parent
                            spacing: Style.space(6)

                            TeamCrest {
                              sport: "f1"
                              teamId: root.favoriteDriverStanding ? root.favoriteDriverStanding.teamId : ""
                              teamName: root.favoriteDriverStanding ? root.favoriteDriverStanding.teamName : ""
                              crestSize: Style.space(16)
                              anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                              text: "★ " + root.selectedTeamName + " · " + (root.favoriteDriverStanding ? "P" + root.favoriteDriverStanding.pos + " (" + root.favoriteDriverStanding.pts + ") · " + root.favoriteDriverStanding.teamName : "")
                              color: Color.accent
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                              font.bold: true
                              anchors.verticalCenter: parent.verticalCenter
                            }
                          }
                        }
                      }
                    }

                    // Standard Team vs Team Core Layout (Football, NBA, NFL, MLB, NHL)
                    Item {
                      width: parent.width
                      implicitHeight: Math.max(homeBounding.implicitHeight, awayBounding.implicitHeight, centerScoreBadge.implicitHeight)
                      visible: !spotlightCard.isF1

                      // Left Side (Home)
                      Item {
                        id: homeBounding
                        anchors.left: parent.left
                        anchors.right: centerScoreBadge.left
                        anchors.rightMargin: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: Math.max(homeCrest.height, homeTextCol.implicitHeight)

                        TeamCrest {
                          id: homeCrest
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          sport: spotlightCard.match ? spotlightCard.match.sport : "football"
                          teamId: spotlightCard.match ? spotlightCard.match.home.id : ""
                          teamName: spotlightCard.match ? spotlightCard.match.home.name : ""
                          abbr: spotlightCard.match && spotlightCard.match.home.abbr ? spotlightCard.match.home.abbr : ""
                          source: spotlightCard.match && spotlightCard.match.home.logo ? spotlightCard.match.home.logo : ""
                          crestSize: Style.space(32)
                        }

                        Column {
                          id: homeTextCol
                          anchors.left: parent.left
                          anchors.right: homeCrest.left
                          anchors.rightMargin: Style.space(8)
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: Style.space(2)

                          Text {
                            width: parent.width
                            text: spotlightCard.match ? spotlightCard.match.home.name || spotlightCard.match.home.shortName : ""
                            color: String(spotlightCard.match && spotlightCard.match.home.id) === String(root.selectedTeamId) ? Color.accent : root.fgColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.title
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                          }

                          Text {
                            width: parent.width
                            text: spotlightCard.match && spotlightCard.match.home.record ? spotlightCard.match.home.record : (String(spotlightCard.match && spotlightCard.match.home.id) === String(root.selectedTeamId) ? "HOME · FAVORITE" : "HOME")
                            color: Qt.darker(root.fgColor, 1.55)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                          }
                        }
                      }

                      // Center Score Box
                      Item {
                        id: centerScoreBadge
                        anchors.centerIn: parent
                        width: Style.space(80)
                        height: Style.space(32)

                        Rectangle {
                          anchors.centerIn: parent
                          width: parent.width
                          height: parent.height
                          radius: Math.min(5, Style.cornerRadius)
                          color: spotlightCard.isLive
                            ? Util.alpha(root.urgentColor, 0.15)
                            : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.06)
                          border.width: 1
                          border.color: spotlightCard.isLive
                            ? root.urgentColor
                            : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.12)

                          Text {
                            anchors.centerIn: parent
                            text: spotlightCard.scoreHidden
                              ? "••••"
                              : (spotlightCard.match && spotlightCard.match.status !== "upcoming"
                                 ? (spotlightCard.match.scoreText || "–")
                                 : (root.kickoffTime(spotlightCard.match) || "VS"))
                            color: spotlightCard.isLive ? root.urgentColor : (spotlightCard.isUpcoming ? Color.accent : root.fgColor)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            font.bold: true
                          }
                        }
                      }

                      // Right Side (Away)
                      Item {
                        id: awayBounding
                        anchors.left: centerScoreBadge.right
                        anchors.leftMargin: Style.space(10)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: Math.max(awayCrest.height, awayTextCol.implicitHeight)

                        TeamCrest {
                          id: awayCrest
                          anchors.left: parent.left
                          anchors.verticalCenter: parent.verticalCenter
                          sport: spotlightCard.match ? spotlightCard.match.sport : "football"
                          teamId: spotlightCard.match ? spotlightCard.match.away.id : ""
                          teamName: spotlightCard.match ? spotlightCard.match.away.name : ""
                          abbr: spotlightCard.match && spotlightCard.match.away.abbr ? spotlightCard.match.away.abbr : ""
                          source: spotlightCard.match && spotlightCard.match.away.logo ? spotlightCard.match.away.logo : ""
                          crestSize: Style.space(32)
                        }

                        Column {
                          id: awayTextCol
                          anchors.left: awayCrest.right
                          anchors.leftMargin: Style.space(8)
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: Style.space(2)

                          Text {
                            width: parent.width
                            text: spotlightCard.match ? spotlightCard.match.away.name || spotlightCard.match.away.shortName : ""
                            color: String(spotlightCard.match && spotlightCard.match.away.id) === String(root.selectedTeamId) ? Color.accent : root.fgColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.title
                            font.bold: true
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                          }

                          Text {
                            width: parent.width
                            text: spotlightCard.match && spotlightCard.match.away.record ? spotlightCard.match.away.record : (String(spotlightCard.match && spotlightCard.match.away.id) === String(root.selectedTeamId) ? "AWAY · FAVORITE" : "AWAY")
                            color: Qt.darker(root.fgColor, 1.55)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                          }
                        }
                      }
                    }

                    // Bottom Details Line
                    Item {
                      width: parent.width
                      implicitHeight: Math.max(metaTextSub.implicitHeight, fotmobTextLink.implicitHeight)

                      Text {
                        id: metaTextSub
                        anchors.left: parent.left
                        anchors.right: fotmobTextLink.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.matchSubline(spotlightCard.match) || (spotlightCard.match && spotlightCard.match.leagueName ? spotlightCard.match.leagueName + " Event" : "Matchday Details")
                        color: Qt.darker(root.fgColor, 1.45)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }

                      Text {
                        id: fotmobTextLink
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.activeSport === "football" ? "FotMob" : "Official") + " 󰌹"
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }
                  }

                  MouseArea {
                    id: spotlightMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (spotlightCard.scoreHidden) {
                        root.revealMatch(spotlightCard.match.id)
                      } else {
                        root.openMatch(spotlightCard.match)
                      }
                    }
                  }
                }
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
                        delegate: MatchRow {}
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
                  delegate: LiveRow {}
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
                      visible: root.activeSport === "f1" && root.standingsLeagueId === "Drivers"
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
                      visible: root.activeSport === "f1" && root.standingsLeagueId !== "Drivers"
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
                      delegate: StandingsRow {}
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

  // ==========================================================================
  // REUSABLE COMPONENTS
  // ==========================================================================

  // Match Row
  component MatchRow: Item {
    id: matchDelegate
    required property var modelData

    readonly property bool isF1: root.activeSport === "f1"
    readonly property bool isLive: modelData.status === "live"
    readonly property bool isUpcoming: modelData.status === "upcoming"
    readonly property bool isFinished: modelData.status === "finished"
    readonly property bool favIsHome: String(modelData.home.id) === String(root.selectedTeamId)
    readonly property bool favIsAway: String(modelData.away.id) === String(root.selectedTeamId)
    readonly property string dateBadge: Model.formatMatchDate(modelData.time)
    readonly property bool isScoreRevealed: root.isMatchRevealed(modelData.id)
    readonly property bool scoreHidden: root.antiSpoiler && isFinished && !isScoreRevealed

    width: parent.width
    implicitHeight: matchCard.implicitHeight

    Rectangle {
      id: matchCard
      width: parent.width
      implicitHeight: matchDelegate.isF1 ? (f1RowLayout.implicitHeight + Style.space(14)) : (matchRowLayout.implicitHeight + Style.space(14))
      radius: Math.min(6, Style.cornerRadius)
      color: matchMouse.containsMouse
        ? Style.hoverFillFor(root.fgColor, Color.accent)
        : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.02)
      border.width: 1
      border.color: matchMouse.containsMouse
        ? Color.accent
        : (matchDelegate.isLive ? root.urgentColor : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.06))

      Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
      Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(3)
        width: Style.space(3)
        radius: width / 2
        visible: matchDelegate.isLive
        color: root.urgentColor
      }

      // F1 Grand Prix Row Layout
      Row {
        id: f1RowLayout
        visible: matchDelegate.isF1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(10)

        Column {
          width: Style.space(84)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          Text {
            text: matchDelegate.dateBadge
            color: Qt.darker(root.fgColor, 1.35)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            text: modelData.round || "GP"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Row {
          width: parent.width - Style.space(190)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Text {
            text: modelData.countryFlag || "🏁"
            font.pixelSize: Style.font.heading
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - Style.space(28)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
              width: parent.width
              text: modelData.raceName || modelData.home.name
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: (modelData.circuitName || "") + (modelData.locality ? " · " + modelData.locality : "")
              color: Qt.darker(root.fgColor, 1.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: f1StatusText.implicitWidth + Style.space(12)
          implicitHeight: f1StatusText.implicitHeight + Style.space(4)
          radius: Math.min(4, Style.cornerRadius)
          color: matchDelegate.isLive
            ? root.urgentColor
            : (matchDelegate.isFinished ? Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.08) : Util.alpha(Color.accent, 0.15))

          Text {
            id: f1StatusText
            anchors.centerIn: parent
            text: matchDelegate.isFinished ? "Official" : (matchDelegate.isLive ? "RACE DAY" : root.kickoffTime(modelData))
            color: matchDelegate.isLive ? "#ffffff" : (matchDelegate.isFinished ? Qt.darker(root.fgColor, 1.3) : Color.accent)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      // Standard Team vs Team Match Row Layout
      Row {
        id: matchRowLayout
        visible: !matchDelegate.isF1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(6)

        Column {
          width: Style.space(88)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          Text {
            text: matchDelegate.dateBadge
            color: Qt.darker(root.fgColor, 1.35)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            text: Model.shortTournamentName(modelData.leagueName) || (modelData.round ? modelData.round : "")
            color: Qt.darker(root.fgColor, 1.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
          }
        }

        Item {
          width: parent.width - Style.space(94)
          height: Math.max(homeTeamLayout.implicitHeight, awayTeamLayout.implicitHeight, centerScoreHolder.implicitHeight)
          anchors.verticalCenter: parent.verticalCenter

          // Left Side (Home)
          Item {
            id: homeTeamLayout
            anchors.left: parent.left
            anchors.right: centerScoreHolder.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Math.max(homeRowCrest.height, homeTeamText.implicitHeight)

            TeamCrest {
              id: homeRowCrest
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              sport: modelData.sport || "football"
              teamId: modelData.home.id
              teamName: modelData.home.name
              abbr: modelData.home.abbr || ""
              source: modelData.home.logo || ""
              crestSize: Style.space(18)
            }

            Text {
              id: homeTeamText
              anchors.left: parent.left
              anchors.right: homeRowCrest.left
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              text: (matchDelegate.favIsHome ? "★ " : "") + (modelData.home.name || modelData.home.shortName)
              color: matchDelegate.favIsHome ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: matchDelegate.favIsHome || (modelData.homeScore > modelData.awayScore)
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }
          }

          // Center Score
          Item {
            id: centerScoreHolder
            anchors.centerIn: parent
            width: Style.space(56)
            height: parent.height

            Row {
              anchors.centerIn: parent
              spacing: Style.space(3)

              Rectangle {
                visible: matchDelegate.isLive
                width: Style.space(5)
                height: width
                radius: width / 2
                color: root.urgentColor
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                  running: matchDelegate.isLive
                  loops: Animation.Infinite
                  NumberAnimation { to: 0.25; duration: 500 }
                  NumberAnimation { to: 1.0; duration: 500 }
                }
              }

              Text {
                id: scoreText
                anchors.verticalCenter: parent.verticalCenter
                text: matchDelegate.scoreHidden
                  ? "••••"
                  : (matchDelegate.isUpcoming
                     ? root.kickoffTime(modelData)
                     : (modelData.scoreText || "–"))
                color: matchDelegate.isLive
                  ? root.urgentColor
                  : (matchDelegate.isUpcoming ? Qt.darker(root.fgColor, 1.2) : root.fgColor)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
            }
          }

          // Right Side (Away)
          Item {
            id: awayTeamLayout
            anchors.left: centerScoreHolder.right
            anchors.leftMargin: Style.space(8)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Math.max(awayRowCrest.height, awayTeamText.implicitHeight)

            TeamCrest {
              id: awayRowCrest
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              sport: modelData.sport || "football"
              teamId: modelData.away.id
              teamName: modelData.away.name
              abbr: modelData.away.abbr || ""
              source: modelData.away.logo || ""
              crestSize: Style.space(18)
            }

            Text {
              id: awayTeamText
              anchors.left: awayRowCrest.right
              anchors.leftMargin: Style.space(6)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: (modelData.away.name || modelData.away.shortName) + (matchDelegate.favIsAway ? " ★" : "")
              color: matchDelegate.favIsAway ? Color.accent : root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: matchDelegate.favIsAway || (modelData.awayScore > modelData.homeScore)
              horizontalAlignment: Text.AlignLeft
              elide: Text.ElideRight
            }
          }
        }
      }
    }

    MouseArea {
      id: matchMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (matchDelegate.scoreHidden) {
          root.revealMatch(modelData.id)
        } else {
          root.openMatch(modelData)
        }
      }
    }
  }

  // Live Match Row
  component LiveRow: Item {
    id: liveDelegate
    required property var modelData

    readonly property string leagueName: Model.leagueLabel(liveDelegate.modelData.leagueId).toUpperCase()
    readonly property var details: root.matchDetails[String(modelData.id)] || null

    width: parent.width
    implicitHeight: liveCard.implicitHeight

    Rectangle {
      id: liveCard
      width: parent.width
      implicitHeight: liveCol.implicitHeight + Style.space(22)
      radius: Math.min(8, Style.cornerRadius)
      color: liveMouse.containsMouse
        ? Style.hoverFillFor(root.fgColor, root.urgentColor)
        : Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.05)
      border.width: 1
      border.color: liveMouse.containsMouse
        ? root.urgentColor
        : Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.3)

      Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
      Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(4)
        width: Style.space(4)
        radius: width / 2
        color: root.urgentColor

        SequentialAnimation on opacity {
          running: true
          loops: Animation.Infinite
          NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
        }
      }

      Column {
        id: liveCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(16)
        anchors.rightMargin: Style.space(16)
        spacing: Style.space(8)

        Item {
          id: liveTopRow
          width: parent.width
          implicitHeight: Math.max(liveLeagueText.implicitHeight, liveTimePill.implicitHeight)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Text {
              text: root.activeSportIcon
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: liveLeagueText
              anchors.verticalCenter: parent.verticalCenter
              text: liveDelegate.leagueName
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.9
            }

            Text {
              visible: liveDelegate.modelData.round !== ""
              anchors.verticalCenter: parent.verticalCenter
              text: "· " + liveDelegate.modelData.round
              color: Qt.darker(root.fgColor, 1.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            id: liveTimePill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: liveTimeRow.implicitWidth + Style.space(12)
            implicitHeight: liveTimeRow.implicitHeight + Style.space(4)
            radius: Math.min(4, Style.cornerRadius)
            color: root.urgentColor

            Row {
              id: liveTimeRow
              anchors.centerIn: parent
              spacing: Style.space(4)

              Rectangle {
                width: Style.space(5)
                height: width
                radius: width / 2
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                  running: true
                  loops: Animation.Infinite
                  NumberAnimation { to: 0.2; duration: 500 }
                  NumberAnimation { to: 1.0; duration: 500 }
                }
              }

              Text {
                text: liveDelegate.modelData.liveTime || "LIVE"
                color: "#ffffff"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(liveHomeBounding.implicitHeight, liveAwayBounding.implicitHeight, liveScorePill.implicitHeight)

          // Home Side (Left)
          Item {
            id: liveHomeBounding
            anchors.left: parent.left
            anchors.right: liveScorePill.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Math.max(liveHomeCrest.height, liveHomeText.implicitHeight)

            TeamCrest {
              id: liveHomeCrest
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              sport: liveDelegate.modelData.sport || "football"
              teamId: liveDelegate.modelData.home.id
              teamName: liveDelegate.modelData.home.name
              abbr: liveDelegate.modelData.home.abbr || ""
              source: liveDelegate.modelData.home.logo || ""
              crestSize: Style.space(26)
            }

            Text {
              id: liveHomeText
              anchors.left: parent.left
              anchors.right: liveHomeCrest.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: liveDelegate.modelData.home.name || liveDelegate.modelData.home.shortName
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }
          }

          // Center Score
          Rectangle {
            id: liveScorePill
            anchors.centerIn: parent
            width: Style.space(88)
            height: Style.space(32)
            radius: Math.min(5, Style.cornerRadius)
            color: Util.alpha(root.urgentColor, 0.2)
            border.width: 1
            border.color: root.urgentColor

            Text {
              anchors.centerIn: parent
              text: liveDelegate.modelData.scoreText || "0–0"
              color: root.urgentColor
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
            }
          }

          // Away Side (Right)
          Item {
            id: liveAwayBounding
            anchors.left: liveScorePill.right
            anchors.leftMargin: Style.space(10)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Math.max(liveAwayCrest.height, liveAwayText.implicitHeight)

            TeamCrest {
              id: liveAwayCrest
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              sport: liveDelegate.modelData.sport || "football"
              teamId: liveDelegate.modelData.away.id
              teamName: liveDelegate.modelData.away.name
              abbr: liveDelegate.modelData.away.abbr || ""
              source: liveDelegate.modelData.away.logo || ""
              crestSize: Style.space(26)
            }

            Text {
              id: liveAwayText
              anchors.left: liveAwayCrest.right
              anchors.leftMargin: Style.space(8)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: liveDelegate.modelData.away.name || liveDelegate.modelData.away.shortName
              color: root.fgColor
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignLeft
              elide: Text.ElideRight
            }
          }
        }

        // Live Game Progression Bar
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(88)
          height: 3
          radius: 1.5
          color: Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.18)
          clip: true

          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: {
              var lt = String(liveDelegate.modelData.liveTime || "")
              var m = parseInt(lt, 10)
              if (!isNaN(m)) return Math.min(parent.width, Math.max(6, (m / 90) * parent.width))
              if (lt.indexOf("HT") !== -1) return parent.width * 0.50
              if (lt.indexOf("Q1") !== -1 || lt.indexOf("1st") !== -1) return parent.width * 0.25
              if (lt.indexOf("Q2") !== -1 || lt.indexOf("2nd") !== -1) return parent.width * 0.50
              if (lt.indexOf("Q3") !== -1 || lt.indexOf("3rd") !== -1) return parent.width * 0.75
              if (lt.indexOf("Q4") !== -1 || lt.indexOf("4th") !== -1) return parent.width * 0.95
              return parent.width * 0.60
            }
            radius: 1.5
            color: root.urgentColor
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)
          visible: liveDelegate.details && liveDelegate.details.halftimeScore && String(liveDelegate.details.halftimeScore) !== "undefined" && String(liveDelegate.details.halftimeScore).trim() !== ""

          Text {
            text: "HT " + (liveDelegate.details ? liveDelegate.details.halftimeScore : "")
            color: Qt.darker(root.fgColor, 1.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(liveVenueText.implicitHeight, liveLinkText.implicitHeight)

          Text {
            id: liveVenueText
            anchors.left: parent.left
            anchors.right: liveLinkText.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.matchSubline(liveDelegate.modelData) || "Live match in progress"
            color: Qt.darker(root.fgColor, 1.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            id: liveLinkText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (root.activeSport === "football" ? "FotMob" : "Official") + " 󰌹"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }
    }

    MouseArea {
      id: liveMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.openMatch(liveDelegate.modelData)
    }
  }

  // Standings Row
  component StandingsRow: Item {
    id: tableDelegate
    required property var modelData
    required property int index

    readonly property color rowFg: root.fgColor
    readonly property bool isFavorite: String(modelData.id) === String(root.selectedTeamId) || (modelData.shortName && String(modelData.shortName).toLowerCase() === String(root.selectedTeamName).toLowerCase())

    width: parent.width
    implicitHeight: Style.space(26)
    height: implicitHeight

    Rectangle {
      anchors.fill: parent
      radius: Math.min(4, Style.cornerRadius)
      color: tableMouse.containsMouse
        ? Style.hoverFillFor(tableDelegate.rowFg, Color.accent)
        : (tableDelegate.isFavorite
           ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
           : (tableDelegate.index % 2 === 1 ? Qt.rgba(tableDelegate.rowFg.r, tableDelegate.rowFg.g, tableDelegate.rowFg.b, 0.02) : "transparent"))

      Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    // Football Standings Row
    Row {
      visible: root.activeSport === "football"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)

      Item {
        width: Style.space(28)
        height: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.centerIn: parent
          width: Style.space(20)
          height: Style.space(18)
          radius: 3
          color: tableDelegate.modelData.zone === "europe"
            ? Util.alpha(Color.accent, 0.18)
            : (tableDelegate.modelData.zone === "relegation"
               ? Util.alpha(root.urgentColor, 0.18)
               : (tableDelegate.modelData.zone === "playin" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent"))

          Text {
            anchors.centerIn: parent
            text: tableDelegate.modelData.pos
            color: tableDelegate.modelData.zone === "europe"
              ? Color.accent
              : (tableDelegate.modelData.zone === "relegation" ? root.urgentColor : Qt.darker(tableDelegate.rowFg, 1.4))
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      Row {
        width: parent.width - Style.space(216)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        TeamCrest {
          sport: "football"
          teamId: tableDelegate.modelData.id
          teamName: tableDelegate.modelData.name
          source: tableDelegate.modelData.logo || ""
          crestSize: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - Style.space(22)
          anchors.verticalCenter: parent.verticalCenter
          text: (tableDelegate.isFavorite ? "★ " : "") + (tableDelegate.modelData.shortName || tableDelegate.modelData.name)
          color: tableDelegate.isFavorite ? Color.accent : tableDelegate.rowFg
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: tableDelegate.isFavorite
          elide: Text.ElideRight
        }
      }

      Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.played; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.wins; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.draws; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.losses; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text {
        width: Style.space(32)
        anchors.verticalCenter: parent.verticalCenter
        text: String(tableDelegate.modelData.gd || "-")
        color: String(modelData.gd || "").indexOf("+") === 0 ? Color.accent : (String(modelData.gd || "").indexOf("-") === 0 && String(modelData.gd) !== "-" ? root.urgentColor : Qt.darker(tableDelegate.rowFg, 1.4))
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
      }

      Text {
        width: Style.space(32)
        anchors.verticalCenter: parent.verticalCenter
        text: String(tableDelegate.modelData.pts || "0")
        color: tableDelegate.isFavorite ? Color.accent : tableDelegate.rowFg
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        horizontalAlignment: Text.AlignRight
      }
    }

    // NBA / NHL / MLB / NFL Standings Row
    Row {
      visible: root.activeSport === "nba" || root.activeSport === "nhl" || root.activeSport === "mlb" || root.activeSport === "nfl"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)

      Item {
        width: Style.space(28)
        height: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.centerIn: parent
          width: Style.space(20)
          height: Style.space(18)
          radius: 3
          color: tableDelegate.modelData.zone === "europe"
            ? Util.alpha(Color.accent, 0.18)
            : (tableDelegate.modelData.zone === "relegation"
               ? Util.alpha(root.urgentColor, 0.18)
               : (tableDelegate.modelData.zone === "playin" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent"))

          Text {
            anchors.centerIn: parent
            text: tableDelegate.modelData.pos
            color: tableDelegate.modelData.zone === "europe"
              ? Color.accent
              : (tableDelegate.modelData.zone === "relegation" ? root.urgentColor : Qt.darker(tableDelegate.rowFg, 1.4))
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      Row {
        width: parent.width - Style.space(190)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        TeamCrest {
          sport: root.activeSport
          teamId: tableDelegate.modelData.id
          teamName: tableDelegate.modelData.name
          abbr: tableDelegate.modelData.abbr || ""
          source: tableDelegate.modelData.logo || ""
          crestSize: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - Style.space(22)
          anchors.verticalCenter: parent.verticalCenter
          text: (tableDelegate.isFavorite ? "★ " : "") + (tableDelegate.modelData.shortName || tableDelegate.modelData.name)
          color: tableDelegate.isFavorite ? Color.accent : tableDelegate.rowFg
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: tableDelegate.isFavorite
          elide: Text.ElideRight
        }
      }

      Text { width: Style.space(28); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.wins; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text { width: Style.space(28); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.losses; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text {
        width: Style.space(36)
        anchors.verticalCenter: parent.verticalCenter
        text: tableDelegate.modelData.played > 0 ? (tableDelegate.modelData.wins / tableDelegate.modelData.played).toFixed(3).replace(/^0/, "") : ".000"
        color: Qt.darker(tableDelegate.rowFg, 1.35)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
      }
      Text {
        width: Style.space(34)
        anchors.verticalCenter: parent.verticalCenter
        text: String(tableDelegate.modelData.gd || "-")
        color: String(modelData.gd || "").indexOf("+") === 0 ? Color.accent : (String(modelData.gd || "").indexOf("-") === 0 && String(modelData.gd) !== "-" ? root.urgentColor : Qt.darker(tableDelegate.rowFg, 1.4))
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
      }
      Text {
        width: Style.space(36)
        anchors.verticalCenter: parent.verticalCenter
        text: String(tableDelegate.modelData.pts || "0")
        color: tableDelegate.isFavorite ? Color.accent : tableDelegate.rowFg
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        horizontalAlignment: Text.AlignRight
      }
    }

    // F1 Drivers Standings Row
    Row {
      visible: root.activeSport === "f1" && root.standingsLeagueId === "Drivers"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)

      Item {
        width: Style.space(28)
        height: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.centerIn: parent
          width: Style.space(20)
          height: Style.space(18)
          radius: 3
          color: tableDelegate.modelData.zone === "europe"
            ? Util.alpha(Color.accent, 0.18)
            : (tableDelegate.modelData.zone === "playin" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent")

          Text {
            anchors.centerIn: parent
            text: tableDelegate.modelData.pos
            color: tableDelegate.modelData.zone === "europe" ? Color.accent : Qt.darker(tableDelegate.rowFg, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      Row {
        width: Style.space(160)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        TeamCrest {
          sport: "f1"
          teamId: tableDelegate.modelData.teamId || ""
          teamName: tableDelegate.modelData.teamName || ""
          crestSize: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - Style.space(22)
          anchors.verticalCenter: parent.verticalCenter
          text: (tableDelegate.isFavorite ? "★ " : "") + (tableDelegate.modelData.flag ? tableDelegate.modelData.flag + " " : "") + tableDelegate.modelData.name
          color: tableDelegate.isFavorite ? Color.accent : tableDelegate.rowFg
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: tableDelegate.isFavorite
          elide: Text.ElideRight
        }
      }

      Text {
        width: parent.width - Style.space(290)
        anchors.verticalCenter: parent.verticalCenter
        text: tableDelegate.modelData.gd || tableDelegate.modelData.teamName || ""
        color: Qt.darker(tableDelegate.rowFg, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        width: Style.space(36)
        anchors.verticalCenter: parent.verticalCenter
        text: String(tableDelegate.modelData.wins)
        color: Qt.darker(tableDelegate.rowFg, 1.35)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
      }

      Text {
        width: Style.space(52)
        anchors.verticalCenter: parent.verticalCenter
        text: String(tableDelegate.modelData.pts || "0")
        color: tableDelegate.isFavorite ? Color.accent : tableDelegate.rowFg
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        horizontalAlignment: Text.AlignRight
      }
    }

    // F1 Constructors Standings Row
    Row {
      visible: root.activeSport === "f1" && root.standingsLeagueId !== "Drivers"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)

      Item {
        width: Style.space(28)
        height: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.centerIn: parent
          width: Style.space(20)
          height: Style.space(18)
          radius: 3
          color: tableDelegate.modelData.zone === "europe"
            ? Util.alpha(Color.accent, 0.18)
            : (tableDelegate.modelData.zone === "playin" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent")

          Text {
            anchors.centerIn: parent
            text: tableDelegate.modelData.pos
            color: tableDelegate.modelData.zone === "europe" ? Color.accent : Qt.darker(tableDelegate.rowFg, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      Row {
        width: Style.space(170)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        TeamCrest {
          sport: "f1"
          teamId: tableDelegate.modelData.id || ""
          teamName: tableDelegate.modelData.name || ""
          crestSize: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - Style.space(22)
          anchors.verticalCenter: parent.verticalCenter
          text: (tableDelegate.isFavorite ? "★ " : "") + tableDelegate.modelData.name
          color: tableDelegate.isFavorite ? Color.accent : tableDelegate.rowFg
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: tableDelegate.isFavorite
          elide: Text.ElideRight
        }
      }

      Text {
        width: parent.width - Style.space(300)
        anchors.verticalCenter: parent.verticalCenter
        text: tableDelegate.modelData.gd || ""
        color: Qt.darker(tableDelegate.rowFg, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        width: Style.space(36)
        anchors.verticalCenter: parent.verticalCenter
        text: String(tableDelegate.modelData.wins)
        color: Qt.darker(tableDelegate.rowFg, 1.35)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
      }

      Text {
        width: Style.space(52)
        anchors.verticalCenter: parent.verticalCenter
        text: String(tableDelegate.modelData.pts || "0")
        color: tableDelegate.isFavorite ? Color.accent : tableDelegate.rowFg
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        horizontalAlignment: Text.AlignRight
      }
    }

    MouseArea {
      id: tableMouse
      anchors.fill: parent
      hoverEnabled: true
    }
  }
}
