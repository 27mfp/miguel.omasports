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

  // Optional background polling so the bar live badge stays honest while the
  // panel is closed. Off by default; startup never touches the network until
  // this is enabled or the panel is opened once.
  readonly property bool backgroundUpdates: setting("backgroundUpdates", false) === true

  // ---- Saved selections -------------------------------------------------
  property var savedState: Model.defaultState()
  property bool stateLoaded: false
  property var selectedLeagueIds: ["61"]
  property string selectedTeamId: ""
  property string ignoredStateSignature: ""

  // ---- Match data --------------------------------------------------------
  // Last-good results are kept in place while a round runs so refreshing
  // never blanks the panel; finishLoading() swaps them atomically.
  property var allMatches: []
  property var teamMatchesRaw: []
  property var teamOptions: []
  property bool loading: false
  property string errorMessage: ""
  property var failedLeagues: []
  property date lastUpdated: new Date(0)
  property bool loadedFromCache: false

  // Parsed league pages from the last successful round (or cache), kept so
  // the Standings tab can show standings without extra requests.
  property var lastPages: []
  property string standingsLeagueId: ""

  // Per-match enrichment (stadium, referee, attendance) for live matches and
  // favorite-team matches, fetched sequentially after each round.
  property var matchDetails: ({})
  property var detailQueue: []

  readonly property bool hasData: allMatches.length > 0

  // Combined team options ensuring saved favorite is always present and searchable
  readonly property var combinedTeamOptions: {
    var list = Model.arrayFrom(teamOptions)
    var curId = String(selectedTeamId || savedState.teamId || "")
    var curName = String(savedState.teamName || "")
    if (curId !== "" && curName !== "") {
      var found = false
      for (var i = 0; i < list.length; i++) {
        if (String(list[i].value) === curId) { found = true; break }
      }
      if (!found) {
        list.unshift({ value: curId, label: curName, description: "Saved favorite" })
      }
    }
    return list
  }

  // ---- Fixtures League/Matchday Filter -------------------------------------
  property string fixtureFilterId: "team"

  readonly property var fixtureFilterOptions: {
    var opts = []
    if (selectedTeamId !== "") {
      opts.push({ value: "team", label: "★ " + (selectedTeamName || "My Club") })
    }
    opts.push({ value: "all", label: "🏆 All Followed" })
    var ids = Model.arrayFrom(selectedLeagueIds)
    for (var i = 0; i < ids.length; i++) {
      opts.push({ value: String(ids[i]), label: Model.leagueLabel(ids[i]) })
    }
    return opts
  }

  readonly property var activeFixturesList: {
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
    if (fixtureFilterId === "team" && selectedTeamId !== "") return "MATCH SCHEDULE"
    if (fixtureFilterId === "all") return "ALL FIXTURES"
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

  readonly property string nextKickoffText: {
    var best = null
    var bestTime = Infinity
    var now = Date.now()
    for (var i = 0; i < allMatches.length; i++) {
      var m = allMatches[i]
      if (!m || m.status !== "upcoming") continue
      var t = Date.parse(m.time || "")
      if (isNaN(t) || t <= now || t >= bestTime) continue
      bestTime = t
      best = m
    }
    if (!best) return ""
    return Model.matchLine(best) + " · " + Qt.formatDateTime(new Date(bestTime), "ddd d MMM HH:mm")
  }

  readonly property var standingsOptions: {
    var options = []
    var ids = Model.arrayFrom(selectedLeagueIds)
    for (var i = 0; i < ids.length; i++) {
      var id = String(ids[i])
      options.push({ value: id, label: Model.leagueLabel(id) })
    }
    return options
  }

  readonly property var standingsRows: {
    var id = String(standingsLeagueId || "")
    for (var i = 0; i < lastPages.length; i++) {
      var page = lastPages[i]
      if (page && page.league && String(page.league.id) === id)
        return Model.arrayFrom(page.standings)
    }
    return []
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

  // Multi-competition team fixtures (League, Champions League, Cups)
  readonly property var teamMatches: {
    if (teamMatchesRaw && teamMatchesRaw.length > 0) return teamMatchesRaw
    return Model.matchesForTeam(allMatches, selectedTeamId)
  }
  readonly property var featuredMatch: Model.featuredMatchForTeam(teamMatches)
  readonly property string selectedTeamName: selectedTeamLabel()
  readonly property string selectedLeagueNames: selectedLeagueNameList()

  // Bar badge + tooltip summary for the favorite club.
  readonly property bool favoriteTeamLive: {
    var source = teamMatches
    for (var i = 0; i < source.length; i++)
      if (source[i].status === "live") return true
    return false
  }
  readonly property string favoriteSummaryText: {
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

  function focusableControlCount() {
    return selectedTeamId === "" ? 6 : 7
  }

  function moveFocus(delta) {
    var count = focusableControlCount()
    if (count <= 0) return
    focusSection = (focusSection + delta + count) % count
  }

  // Left/right inside the tab row switches tabs; elsewhere it walks sections.
  function moveWithin(dx) {
    if (focusSection === 0 && !anyPopupOpen()) {
      var next = (tabIndex + dx + tabOptions.length) % tabOptions.length
      tabIndex = next
      return
    }
    moveFocus(dx)
  }

  function anyPopupOpen() {
    return leaguePicker.popupOpen || teamPicker.popupOpen || intervalPicker.popupOpen
      || standingsPicker.popupOpen
  }

  function activateFocus() {
    if (focusSection === 0) root.tabIndex = (root.tabIndex + 1) % root.tabOptions.length
    else if (focusSection === 1) leaguePicker.toggle()
    else if (focusSection === 2) teamPicker.toggle()
    else if (focusSection === 3) root.refresh()
    else if (focusSection === 4 && selectedTeamId !== "") root.clearSelectedTeam()
    else if (focusSection === 4) intervalPicker.toggle()
    else if (focusSection === 5) intervalPicker.toggle()
    else if (focusSection === 6 && root.standingsOptions.length > 1) standingsPicker.toggle()
  }

  // ---- Lifecycle -----------------------------------------------------------
  function open() {
    root.openFromHotkey()
  }

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
    var names = []
    var ids = Model.arrayFrom(selectedLeagueIds)
    for (var i = 0; i < ids.length; i++) names.push(Model.leagueLabel(ids[i]))
    return names.join(", ")
  }

  function selectedTeamLabel() {
    var id = String(selectedTeamId || "")
    if (!id) return ""
    for (var i = 0; i < combinedTeamOptions.length; i++) {
      if (String(combinedTeamOptions[i].value) === id) return String(combinedTeamOptions[i].label)
    }
    return String(savedState.teamName || "")
  }

  function applyState(raw) {
    var nextState = Model.parseState(raw)
    var ownWrite = ignoredStateSignature !== ""
      && JSON.stringify(nextState) === ignoredStateSignature
    if (ownWrite) ignoredStateSignature = ""
    savedState = nextState
    selectedLeagueIds = Model.normalizeLeagueIds(savedState.leagueIds)
    if (selectedLeagueIds.length === 0) selectedLeagueIds = ["61"]
    selectedTeamId = String(savedState.teamId || "")
    stateLoaded = true

    if (leaguePicker) leaguePicker.values = selectedLeagueIds
    ensureStandingsSelection()
    if (root.opened && !root.loading && !ownWrite && root.needsAutoRefresh()) Qt.callLater(root.refresh)
    else if (root.opened && !root.loading && detailQueue.length > 0) Qt.callLater(root.nextDetail)
  }

  function persistState() {
    if (!stateLoaded) return
    savedState = Model.statePayload(
      "football",
      selectedLeagueIds,
      selectedTeamId,
      selectedTeamName,
      savedState.refreshMinutes,
      standingsLeagueId || savedState.standingsLeagueId
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
    if (selectedTeamId !== "") root.fetchTeamPage()
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
    savedState.standingsLeagueId = standingsLeagueId
    if (standingsPicker) standingsPicker.value = standingsLeagueId
    persistState()
  }

  function ensureStandingsSelection() {
    var remembered = String(savedState.standingsLeagueId || "")
    var ids = Model.arrayFrom(selectedLeagueIds)
    var hasRows = function(id) {
      for (var i = 0; i < lastPages.length; i++) {
        var page = lastPages[i]
        if (page && page.league && String(page.league.id) === id)
          return Model.arrayFrom(page.standings).length > 0
      }
      return false
    }
    var selected = function(id) {
      for (var k = 0; k < ids.length; k++)
        if (String(ids[k]) === id) return true
      return false
    }
    if (remembered !== "" && selected(remembered) && (lastPages.length === 0 || hasRows(remembered))) {
      standingsLeagueId = remembered
      return
    }
    for (var j = 0; j < ids.length; j++) {
      if (hasRows(String(ids[j]))) {
        standingsLeagueId = String(ids[j])
        return
      }
    }
    standingsLeagueId = ids.length > 0 ? String(ids[0]) : ""
  }

  function refreshIntervalLabel() {
    var minutes = Math.max(5, parseInt(savedState.refreshMinutes || 15, 10))
    for (var i = 0; i < refreshIntervalOptions.length; i++)
      if (parseInt(refreshIntervalOptions[i].value, 10) === minutes) return refreshIntervalOptions[i].label
    return minutes + " min"
  }

  // ---- Fetch round ------------------------------------------------------------
  function refresh() {
    if (!stateLoaded) {
      stateFile.reload()
      return
    }
    startRound()
  }

  function fetchTeamPage() {
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

  function resolveTeamWorker(raw) {
    if (String(raw || "").trim()) {
      try {
        var parsed = Model.parseTeamPage(raw, selectedTeamId)
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

  function startRound() {
    requestSerial++
    var workers = [workerA, workerB, workerC, workerD]
    for (var i = 0; i < workers.length; i++) {
      if (workers[i].running) workers[i].running = false
      workers[i].handled = false
    }
    retryDelay.stop()
    // Support up to 12 concurrent followed leagues
    roundQueue = selectedLeagueIds.slice(0, 12)
    pendingRetryIds = []
    nextDispatch = 0
    outstanding = roundQueue.length
    roundResults = {}
    retryCounts = {}
    failedLeagues = []
    errorMessage = ""
    if (outstanding === 0) {
      loading = false
      errorMessage = "Select at least one league to load matches."
      return
    }
    loading = true
    if (selectedTeamId !== "") fetchTeamPage()
    Qt.callLater(pump)
  }

  function startWorker(w, leagueId) {
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

  function pump() {
    if (!root.loading) return
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
        startWorker(w, String(roundQueue[nextDispatch]))
        nextDispatch++
      }
    }
    if (!anyBusy && pendingRetryIds.length === 0) finishLoading()
  }

  function resolveWorker(w, raw) {
    if (w.handled || w.serial !== root.requestSerial) return
    w.handled = true

    var id = w.leagueId
    var page = null
    if (String(raw || "").trim()) {
      try {
        page = Model.parseLeaguePage(raw, id)
      } catch (error) {
        page = null
      }
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
    Qt.callLater(root.pump)
  }

  function restoreTeamSelection() {
    var restoredId = String(selectedTeamId || savedState.teamId || "")
    var restoredName = String(savedState.teamName || "")
    if (!restoredId && !restoredName) return

    var matchingTeam = ""
    for (var i = 0; i < teamOptions.length; i++) {
      if (String(teamOptions[i].value) === restoredId
          || (!restoredId && restoredName && String(teamOptions[i].label) === restoredName)) {
        matchingTeam = String(teamOptions[i].value)
        break
      }
    }

    if (matchingTeam !== "") {
      selectedTeamId = matchingTeam
      if (teamPicker) teamPicker.value = matchingTeam
    } else if (restoredId !== "") {
      // Preserve selection so it is never lost during network reload
      selectedTeamId = restoredId
      if (teamPicker) teamPicker.value = restoredId
    }
  }

  function finishLoading() {
    loading = false
    retryDelay.stop()

    var pages = []
    var ids = Model.arrayFrom(selectedLeagueIds)
    for (var i = 0; i < ids.length; i++) {
      var result = roundResults[String(ids[i])]
      if (result) pages.push(result)
    }

    if (pages.length > 0) {
      allMatches = Model.mergePages(pages)
      teamOptions = Model.teamOptions(allMatches)
      lastUpdated = new Date()
      loadedFromCache = false
      lastPages = pages
      cacheFile.setText(JSON.stringify(Model.cachePayload(pages, matchDetails)) + "\n")
    }

    var beforeId = String(selectedTeamId)
    ensureStandingsSelection()
    restoreTeamSelection()
    if (String(selectedTeamId) !== beforeId && selectedTeamId !== "") persistState()

    startDetailFetch()

    if (pages.length === 0 && !hasData) {
      errorMessage = "Unable to load matches. Check your connection and try again."
    } else if (failedLeagues.length > 0) {
      errorMessage = "Some leagues could not be loaded: " + failedLeagues.join(", ") + "."
    } else {
      errorMessage = ""
    }
  }

  // ---- Disk cache --------------------------------------------------------------
  function loadCache() {
    if (hasData || loading) return
    cacheFile.reload()
  }

  function applyCache(raw) {
    if (hasData || loading) return
    var cache = Model.parseCache(raw)
    if (!cache) return
    allMatches = cache.matches
    teamOptions = Model.teamOptions(cache.matches)
    lastUpdated = new Date(cache.savedAt)
    loadedFromCache = true
    matchDetails = cache.details

    var pages = []
    for (var key in cache.standings)
      pages.push({ league: { id: String(key), name: Model.leagueLabel(key), country: "" }, matches: [], standings: cache.standings[key] })
    lastPages = pages

    ensureStandingsSelection()
    restoreTeamSelection()
  }

  // ---- Match detail enrichment -------------------------------------------------
  function startDetailFetch() {
    var wanted = []
    // Prioritize ALL live matches first
    var live = Model.liveMatches(allMatches, matchDetails)
    for (var i = 0; i < live.length && wanted.length < 8; i++) {
      var lid = String(live[i].id)
      if (matchDetails[lid]) continue
      wanted.push(lid)
    }
    // Then favorite team matches
    var source = teamMatches
    for (var j = 0; j < source.length && wanted.length < 16; j++) {
      var tid = String(source[j].id)
      if (matchDetails[tid] || wanted.indexOf(tid) !== -1) continue
      wanted.push(tid)
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
          cacheFile.setText(JSON.stringify(Model.cachePayload(lastPages, matchDetails)) + "\n")

          // If detail reports Full-Time, update match status immediately
          if (parsed.statusLong === "Full-Time" || parsed.reason === "FT" || parsed.finished) {
            var updated = false
            for (var m = 0; m < allMatches.length; m++) {
              if (String(allMatches[m].id) === id && allMatches[m].status === "live") {
                allMatches[m].status = "finished"
                updated = true
              }
            }
            if (updated) {
              allMatches = Model.arrayFrom(allMatches)
            }
          }
        }
      } catch (error) {}
    }
    Qt.callLater(nextDetail)
  }

  // ---- Match actions -------------------------------------------------------------
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
    var parts = []
    if (match && match.round) parts.push("MD " + match.round)
    var d = match ? matchDetails[String(match.id)] : null
    if (d && d.stadium) {
      parts.push("📍 " + d.stadium + (d.city ? ", " + d.city : ""))
    }
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
    if (loading && !hasData) return "󰥔 Loading fixtures & scores…"
    if (loading) return "󰥔 Updating live data…"
    if (errorMessage !== "") return errorMessage
    if (!hasData) return "Choose leagues and a club to track fixtures."
    var stamp = (loadedFromCache ? "󰥔 Cached · " : "󰥔 Updated ") + Qt.formatDateTime(lastUpdated, "HH:mm")
    return stamp
  }

  // ---- Self-heal ------------------------------------------------------------------
  Timer {
    interval: 1500
    running: true
    onTriggered: {
      stateFile.reload()
      root.loadCache()
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

  FileView {
    id: cacheFile
    path: Quickshell.env("HOME") + "/.cache/miguel-sports.json"
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyCache(text())
  }

  Process {
    id: matchOpener
  }

  // ---- Multi-competition team worker -------------------------------------------
  Process {
    id: workerTeam
    property bool handled: false
    property string teamId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        workerTeam.handled = true
        root.resolveTeamWorker(String(text || ""))
      }
    }
    onExited: function(exitCode) {
      if (!workerTeam.handled && workerTeam.serial === root.requestSerial) {
        workerTeam.handled = true
        root.resolveTeamWorker("")
      }
    }
  }

  // ---- League workers (concurrent connection pool) -----------------------------
  Process {
    id: workerA
    property bool handled: false
    property string leagueId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.resolveWorker(workerA, String(text || ""))
    }
    onExited: function(exitCode) {
      if (!workerA.handled && workerA.serial === root.requestSerial) root.resolveWorker(workerA, "")
    }
  }

  Process {
    id: workerB
    property bool handled: false
    property string leagueId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.resolveWorker(workerB, String(text || ""))
    }
    onExited: function(exitCode) {
      if (!workerB.handled && workerB.serial === root.requestSerial) root.resolveWorker(workerB, "")
    }
  }

  Process {
    id: workerC
    property bool handled: false
    property string leagueId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.resolveWorker(workerC, String(text || ""))
    }
    onExited: function(exitCode) {
      if (!workerC.handled && workerC.serial === root.requestSerial) root.resolveWorker(workerC, "")
    }
  }

  Process {
    id: workerD
    property bool handled: false
    property string leagueId: ""
    property int serial: 0

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.resolveWorker(workerD, String(text || ""))
    }
    onExited: function(exitCode) {
      if (!workerD.handled && workerD.serial === root.requestSerial) root.resolveWorker(workerD, "")
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
      root.pump()
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
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
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
          spacing: Style.space(14)
          bottomPadding: Style.space(16)

          Column {
            id: panelBody
            width: parent.width
            spacing: Style.space(12)

            opacity: root.loading && root.hasData ? 0.65 : 1.0
            Behavior on opacity {
              NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

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
                  text: "⚽"
                  font.pixelSize: Style.font.display
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    text: "Matchday"
                    color: root.fgColor
                    font.family: Style.font.family
                    font.pixelSize: Style.font.heading
                    font.bold: true
                  }

                  Text {
                    text: root.statusLine()
                    color: root.errorMessage !== ""
                      ? root.urgentColor
                      : Qt.darker(root.fgColor, 1.45)
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

              // Live Match Pill (on right edge of tab row)
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
              spacing: Style.space(14)
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
                      text: "FOLLOWED LEAGUES & CLUB"
                      foreground: root.fgColor
                    }

                    Button {
                      id: setupToggleBtn
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.setupExpanded ? "Done" : "Edit"
                      iconText: root.setupExpanded ? "󰅃" : "󰅀"
                      visible: root.selectedLeagueIds.length > 0 && root.selectedTeamId !== ""
                      foreground: root.fgColor
                      onClicked: root.setupExpanded = !root.setupExpanded
                    }
                  }

                  // Collapsed Summary Row
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: !root.setupExpanded && root.selectedLeagueIds.length > 0 && root.selectedTeamId !== ""

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
                          text: "🏆 " + root.selectedLeagueIds.length + " Followed Leagues"
                          color: root.fgColor
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        Text {
                          text: "·"
                          color: Qt.darker(root.fgColor, 1.5)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                        }

                        Text {
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
                    visible: root.setupExpanded || root.selectedLeagueIds.length === 0 || root.selectedTeamId === ""

                    FocusScope {
                      id: leagueScope
                      width: parent.width
                      height: leaguePicker.implicitHeight

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

                    // Selected League Badges / Chips
                    Flow {
                      width: parent.width
                      spacing: Style.space(6)
                      visible: root.selectedLeagueIds.length > 0

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
                          label: "Favorite club"
                          value: root.selectedTeamId
                          options: root.combinedTeamOptions
                          placeholderText: "Search club by name or league…"
                          triggerLabel: root.combinedTeamOptions.length > 0 ? "Choose your favorite club" : "Load leagues first"
                          emptyText: "No clubs match your search"
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

              // ---- Spotlight Featured Card (if team is selected) ------------
              Item {
                id: spotlightCard
                width: parent.width
                implicitHeight: spotlightSurface.implicitHeight
                visible: root.selectedTeamId !== "" && root.featuredMatch !== null

                readonly property var match: root.featuredMatch
                readonly property bool isLive: match && match.status === "live"
                readonly property bool isUpcoming: match && match.status === "upcoming"
                readonly property string outcome: match ? Model.teamOutcome(match, root.selectedTeamId) : ""

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

                    // Top Bar: SPOTLIGHT badge · Competition · Status
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
                            text: "SPOTLIGHT"
                            color: Color.accent
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 0.8
                          }
                        }

                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          text: (spotlightCard.match ? spotlightCard.match.leagueName : "") + (spotlightCard.match && spotlightCard.match.round ? " · Matchday " + spotlightCard.match.round : "")
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
                          : (spotlightCard.outcome === "win"
                             ? Color.accent
                             : (spotlightCard.outcome === "loss" ? root.urgentColor : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.10)))

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
                                 ? ("FT" + (spotlightCard.outcome ? " · " + spotlightCard.outcome.toUpperCase() : ""))
                                 : (spotlightCard.match ? Qt.formatDateTime(new Date(Date.parse(spotlightCard.match.time || "")), "ddd d MMM · HH:mm") : ""))
                            color: spotlightCard.isLive || spotlightCard.outcome === "win" || spotlightCard.outcome === "loss" ? "#ffffff" : root.fgColor
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }
                        }
                      }
                    }

                    // Main Match Core (Teams & Center Scoreline)
                    Item {
                      width: parent.width
                      implicitHeight: Math.max(homeCol.implicitHeight, awayCol.implicitHeight, centerScoreBadge.implicitHeight)

                      // Home Team Column
                      Column {
                        id: homeCol
                        anchors.left: parent.left
                        anchors.right: centerScoreBadge.left
                        anchors.rightMargin: Style.space(12)
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
                          text: String(spotlightCard.match && spotlightCard.match.home.id) === String(root.selectedTeamId) ? "HOME · FAVORITE" : "HOME"
                          color: Qt.darker(root.fgColor, 1.55)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          horizontalAlignment: Text.AlignRight
                        }
                      }

                      // Center Score / Kickoff Badge
                      Item {
                        id: centerScoreBadge
                        anchors.centerIn: parent
                        width: Style.space(72)
                        height: homeCol.implicitHeight

                        Rectangle {
                          anchors.centerIn: parent
                          width: parent.width
                          height: Style.space(28)
                          radius: Math.min(4, Style.cornerRadius)
                          color: spotlightCard.isLive
                            ? Util.alpha(root.urgentColor, 0.15)
                            : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.06)
                          border.width: 1
                          border.color: spotlightCard.isLive
                            ? root.urgentColor
                            : Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.12)

                          Text {
                            anchors.centerIn: parent
                            text: spotlightCard.match && spotlightCard.match.status !== "upcoming"
                              ? (spotlightCard.match.scoreText || "–")
                              : (root.kickoffTime(spotlightCard.match) || "VS")
                            color: spotlightCard.isLive ? root.urgentColor : (spotlightCard.isUpcoming ? Color.accent : root.fgColor)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            font.bold: true
                          }
                        }
                      }

                      // Away Team Column
                      Column {
                        id: awayCol
                        anchors.left: centerScoreBadge.right
                        anchors.right: parent.right
                        anchors.leftMargin: Style.space(12)
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
                          text: String(spotlightCard.match && spotlightCard.match.away.id) === String(root.selectedTeamId) ? "AWAY · FAVORITE" : "AWAY"
                          color: Qt.darker(root.fgColor, 1.55)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          horizontalAlignment: Text.AlignLeft
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
                        text: root.matchSubline(spotlightCard.match)
                        color: Qt.darker(root.fgColor, 1.45)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }

                      Text {
                        id: fotmobTextLink
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FotMob 󰌹"
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
                    onClicked: root.openMatch(spotlightCard.match)
                  }
                }
              }

              // ---- Schedule Header with League / Matchday Filter -----------
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
                  width: Style.space(200)
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
                    onChanged: function(val) { root.fixtureFilterId = String(val || "team") }
                  }
                }
              }

              Text {
                width: parent.width
                visible: root.selectedTeamId === "" && !root.hasData
                text: root.teamOptions.length === 0
                  ? "Select a league above to discover its clubs."
                  : "Choose your favorite club to see its upcoming and recent matches across all competitions."
                color: Qt.darker(root.fgColor, 1.35)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
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
                        color: modelData.label === "Live Matches"
                          ? root.urgentColor
                          : Qt.darker(root.fgColor, 1.45)
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

              // Empty state when no live games
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
                      ? "No live matches right now in your followed leagues."
                      : "Pick leagues in the Fixtures tab to see live match scores."
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
                        text: "NEXT UPCOMING KICKOFF"
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
                  text: "LEAGUE STANDINGS"
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
                  width: Style.space(200)
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
                text: root.lastPages.length === 0
                  ? "Refresh to load league standings."
                  : (root.selectedLeagueIds.length === 0
                     ? "Pick a league in the Fixtures tab first."
                     : "No table available for this competition — cup tournaments do not have league standings.")
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

                  // Table Header (precisely aligned with StandingsRow columns)
                  Row {
                    width: parent.width
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(6)

                    Text { width: Style.space(28); text: "#"; color: root.tableHeaderColor(); font: root.tableFont(); horizontalAlignment: Text.AlignHCenter }
                    Text { width: parent.width - Style.space(216); text: "CLUB"; color: root.tableHeaderColor(); font: root.tableFont() }
                    Text { width: Style.space(26); text: "P"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                    Text { width: Style.space(26); text: "W"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                    Text { width: Style.space(26); text: "D"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                    Text { width: Style.space(26); text: "L"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                    Text { width: Style.space(32); text: "GD"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
                    Text { width: Style.space(32); text: "PTS"; horizontalAlignment: Text.AlignRight; color: root.tableHeaderColor(); font: root.tableFont() }
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
                    text: "Europe / Promotion"
                    color: Qt.darker(root.fgColor, 1.4)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Row {
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
                    text: "Favorite Club"
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

  // Match Row (Used in Fixtures tab)
  component MatchRow: Item {
    id: matchDelegate
    required property var modelData

    readonly property bool isLive: modelData.status === "live"
    readonly property bool isUpcoming: modelData.status === "upcoming"
    readonly property bool isFinished: modelData.status === "finished"
    readonly property bool favIsHome: String(modelData.home.id) === String(root.selectedTeamId)
    readonly property bool favIsAway: String(modelData.away.id) === String(root.selectedTeamId)
    readonly property string dateBadge: Model.formatMatchDate(modelData.time)

    width: parent.width
    implicitHeight: matchCard.implicitHeight

    Rectangle {
      id: matchCard
      width: parent.width
      implicitHeight: matchRowLayout.implicitHeight + Style.space(14)
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

      // Live pulsing left border
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

      Row {
        id: matchRowLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(6)

        // Date / Competition / Round tag on left
        Column {
          width: Style.space(92)
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
            text: Model.shortTournamentName(modelData.leagueName) || (modelData.round ? "MD " + modelData.round : "")
            color: Qt.darker(root.fgColor, 1.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
          }
        }

        // Teams vs Score layout
        Item {
          width: parent.width - Style.space(98)
          height: Math.max(homeTeamText.implicitHeight, awayTeamText.implicitHeight, scoreText.implicitHeight)
          anchors.verticalCenter: parent.verticalCenter

          // Home Team
          Text {
            id: homeTeamText
            anchors.left: parent.left
            anchors.right: centerScoreHolder.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: (matchDelegate.favIsHome ? "★ " : "") + (modelData.home.name || modelData.home.shortName)
            color: matchDelegate.favIsHome ? Color.accent : root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: matchDelegate.favIsHome || (modelData.homeScore > modelData.awayScore)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
          }

          // Center Score / Kickoff Time
          Item {
            id: centerScoreHolder
            anchors.centerIn: parent
            width: Style.space(52)
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
                text: matchDelegate.isUpcoming
                  ? root.kickoffTime(modelData)
                  : (modelData.scoreText || "–")
                color: matchDelegate.isLive
                  ? root.urgentColor
                  : (matchDelegate.isUpcoming ? Qt.darker(root.fgColor, 1.2) : root.fgColor)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
            }
          }

          // Away Team
          Text {
            id: awayTeamText
            anchors.left: centerScoreHolder.right
            anchors.right: parent.right
            anchors.leftMargin: Style.space(8)
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

    MouseArea {
      id: matchMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.openMatch(modelData)
    }
  }

  // Live Match Row (Used in Live tab)
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

      // Left glowing live red indicator strip
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

        // Top Row: League Name (left) & Live minute badge (right)
        Item {
          id: liveTopRow
          width: parent.width
          implicitHeight: Math.max(liveLeagueText.implicitHeight, liveTimePill.implicitHeight)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Text {
              text: "⚽"
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
              text: "· Matchday " + liveDelegate.modelData.round
              color: Qt.darker(root.fgColor, 1.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          // Live Pulse Badge
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

        // Main Teams & Score Display (Precision aligned)
        Item {
          width: parent.width
          height: Math.max(liveHomeText.implicitHeight, liveAwayText.implicitHeight, liveScorePill.implicitHeight)

          // Home Team
          Text {
            id: liveHomeText
            anchors.left: parent.left
            anchors.right: liveScorePill.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: liveDelegate.modelData.home.name || liveDelegate.modelData.home.shortName
            color: root.fgColor
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
          }

          // Center Score Pill
          Rectangle {
            id: liveScorePill
            anchors.centerIn: parent
            width: Style.space(80)
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

          // Away Team
          Text {
            id: liveAwayText
            anchors.left: liveScorePill.right
            anchors.right: parent.right
            anchors.leftMargin: Style.space(12)
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

        // Halftime note if valid
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

        // Bottom Footer Line: Venue, Referee, Attendance & Action hint
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
            text: "FotMob 󰌹"
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

  // Standings Row (Used in Standings tab)
  component StandingsRow: Item {
    id: tableDelegate
    required property var modelData
    required property int index

    readonly property color rowFg: root.fgColor
    readonly property bool isFavorite: String(modelData.id) === String(root.selectedTeamId)

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

    Row {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)

      // Position with Zone pill
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
               : "transparent")

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

      // Team / Club Name
      Text {
        width: parent.width - Style.space(216)
        anchors.verticalCenter: parent.verticalCenter
        text: (tableDelegate.isFavorite ? "★ " : "") + (tableDelegate.modelData.shortName || tableDelegate.modelData.name)
        color: tableDelegate.isFavorite ? Color.accent : tableDelegate.rowFg
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: tableDelegate.isFavorite
        elide: Text.ElideRight
      }

      // Played, Won, Drawn, Lost, Goal Diff
      Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.played; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.wins; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.draws; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text { width: Style.space(26); anchors.verticalCenter: parent.verticalCenter; text: tableDelegate.modelData.losses; color: Qt.darker(tableDelegate.rowFg, 1.35); font.family: Style.font.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight }
      Text {
        width: Style.space(32)
        anchors.verticalCenter: parent.verticalCenter
        text: tableDelegate.gdText()
        color: parseInt(modelData.gd, 10) > 0 ? Color.accent : (parseInt(modelData.gd, 10) < 0 ? root.urgentColor : Qt.darker(tableDelegate.rowFg, 1.4))
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
      }

      // Points (PTS)
      Text {
        width: Style.space(32)
        anchors.verticalCenter: parent.verticalCenter
        text: tableDelegate.modelData.pts
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

    function gdText() {
      var v = parseInt(modelData.gd, 10) || 0
      return v > 0 ? "+" + v : String(v)
    }
  }
}
