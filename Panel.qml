import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "SportsModel.js" as Model

Panel {
  id: root
  moduleName: "miguel.omasports"
  ipcTarget: "miguel.omasports"
  manageIpc: false

  Theme { id: theme }

  property var anchorItem: null
  property bool openedFromHotkey: false
  property bool routedExplicitly: false

  // Long slates (a full MLB week, an F1 season) must scroll instead of
  // stretching the card to the whole screen: cap content at ~72% of the
  // usable height (floor guards tiny/unknown geometries)
  readonly property double maxPanelContentHeight: panel && panel.availableCardHeight > 0
    ? Math.max(Style.space(320), Math.round(panel.availableCardHeight * 0.72))
    : Infinity

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel, so popout coordination and switchPanelFrom must identify
  // the host widget (same contract as omarchy.weather).
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Theme colors
  readonly property color fgColor: root.bar && root.bar.barForeground ? root.bar.barForeground : Color.foreground
  readonly property color bgColor: Color.background
  readonly property color urgentColor: root.bar && root.bar.urgent ? root.bar.urgent : Color.urgent

  readonly property string userHome: {
    var h = ""
    try {
      if (typeof Quickshell !== "undefined" && Quickshell && typeof Quickshell.env === "function") {
        h = Quickshell.env("HOME") || ""
      }
    } catch (e) {}
    return h || Model.safeHome()
  }

  // Optional background polling (from user favorites state or widget settings)
  property bool backgroundUpdates: (savedState && savedState.backgroundUpdates !== undefined)
    ? (savedState.backgroundUpdates === true)
    : (setting("backgroundUpdates", true) === true)

  function toggleBackgroundUpdates() {
    backgroundUpdates = !backgroundUpdates
    persistState()
    scheduleNextPoll()
  }

  // Live score on bar and spotlight cards display preferences
  property bool showBarTicker: (savedState && savedState.showBarTicker !== undefined)
    ? (savedState.showBarTicker === true)
    : (setting("showBarTicker", true) === true)
  property bool showSpotlight: (savedState && savedState.showSpotlight !== undefined)
    ? (savedState.showSpotlight === true)
    : true

  function toggleBarTicker() {
    showBarTicker = !showBarTicker
    persistState()
  }

  function toggleSpotlight() {
    showSpotlight = !showSpotlight
    persistState()
  }

  // Bar positioning: "auto" (render under icon if placed on edges, center if near screen center),
  // "icon" (always anchor under the bar icon), or "center" (always center on screen)
  readonly property string panelPositionSetting: setting("panelPosition", "auto")
  readonly property bool shouldCenterOnBar: {
    if (panelPositionSetting === "center") return true
    if (panelPositionSetting === "icon" || panelPositionSetting === "anchor") return false
    if (!panel || panel.screenW <= 0 || !root.anchorItem) return true
    var iconCenterX = panel.anchorScreenPos.x + panel.anchorW / 2
    var screenCenterX = panel.screenW / 2
    return Math.abs(iconCenterX - screenCenterX) < (panel.screenW * 0.15)
  }

  // Mock mode: OMASPORTS_MOCK=1 runs the whole panel on a deterministic built-in
  // simulation (no network) — live matches evolve, a goal is scored mid-session,
  // and a kickoff happens 12 minutes in. For development and UI testing.
  readonly property bool mockMode: Quickshell.env("OMASPORTS_MOCK") === "1"

  // Testing & focus suppression for headless/autonomous runs
  property bool suppressFocus: false
  property string targetScreenName: ""
  property var targetScreen: {
    if (!targetScreenName) return null
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === targetScreenName) return screens[i]
    }
    return null
  }

  // ---- Active Sport & Saved State ---------------------------------------
  property string activeSport: "football"
  readonly property var activeSportMeta: Model.sportMeta(activeSport)
  readonly property string activeSportIcon: activeSportMeta.icon
  property string scheduleSubSection: "all"

  property var savedState: Model.defaultState()
  property bool stateLoaded: false
  // Snapshot of the last state we wrote ourselves, so our own FileView writes
  // can be distinguished from external edits (which trigger a fresh round)
  property string ignoredStateSignature: ""
  property var selectedLeagueIds: ["47"]
  property var selectedTeamIds: []
  property string standingsLeagueId: "47"
  property bool antiSpoiler: false
  property bool enableNotifications: true
  property var revealedMatchIds: ({})
  property var lastSeenMatches: ({})
  property var notificationQueue: []
  property bool notificationToolAvailable: true
  property bool notificationWarningShown: false
  property string persistenceError: ""

  // Match and standings storage
  property var allMatches: []
  property var teamMatchesRaw: []
  property bool loading: false
  property string errorMessage: ""
  property var failedLeagues: []
  property date lastUpdated: new Date(0)
  property bool loadedFromCache: false

  // Standings data
  property var lastPages: []
  property var multiSportStandings: ({})
  property var f1RaceWinners: ({})
  property string f1CalendarRaw: ""

  // Per-match enrichment for football
  property var matchDetails: ({})
  property var detailQueue: []

  // Multi-feature enrichment properties
  property var matchBroadcasts: ({})
  property var matchLeaders: ({})
  property var matchEvents: ({})
  property var matchForm: ({})
  property var matchStats: ({})
  property var f1Podium: []
  property var f1Pole: null
  property var leagueNews: []
  property bool showNewsWire: true

  function toggleNewsWire() {
    showNewsWire = !showNewsWire
    persistState()
  }

  // Crest disk-cache bookkeeping: keys already on disk are never re-downloaded
  property var knownLogoKeys: ({})
  property var pendingLogoKeys: []
  property bool logoScanDone: false

  readonly property bool hasData: allMatches.length > 0
  // A completed fetch with zero games (off-season, quiet window) must read as
  // "nothing scheduled", never as "you haven't configured anything yet"
  readonly property bool fetchedOnce: root.lastUpdated.getTime() > 0
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

  // Derived lists are plain properties refreshed through refreshDerivedLists()
  // instead of auto-re-evaluating bindings: provider refreshes build fresh
  // arrays even when nothing visible changed, and a new array identity makes
  // every Repeater destroy and recreate all of its delegates
  property var activeFixturesList: []
  property var matchGroups: []
  property var liveList: []
  property var teamMatches: []
  property double nextKickoffMs: -1
  property var nextKickoffMatch: null

  function refreshDerivedLists() {
    // Followed-team schedule (multi-competition). F1 uses the full calendar
    // once a driver/constructor is followed: every favourite contests every GP.
    var tm
    if (activeSport === "f1") tm = selectedTeamIds.length > 0 ? allMatches : []
    else if (teamMatchesRaw && teamMatchesRaw.length > 0) tm = teamMatchesRaw
    else if (selectedTeamIds.length > 0) tm = Model.matchesForTeam(allMatches, selectedTeamIds, activeSport)
    else tm = []
    if (!Model.sameMatches(teamMatches, tm)) teamMatches = tm

    // Fixtures under the current filter
    var fx
    if (activeSport === "f1") fx = allMatches
    else if (fixtureFilterId === "team" && selectedTeamIds.length > 0) fx = tm
    else if (fixtureFilterId.indexOf("fav_") === 0) fx = Model.matchesForTeam(allMatches, fixtureFilterId.slice(4), activeSport)
    else if (fixtureFilterId === "all") fx = allMatches
    else fx = Model.matchesForLeague(allMatches, fixtureFilterId)
    if (!Model.sameMatches(activeFixturesList, fx)) activeFixturesList = fx

    var groups = Model.groupMatches(fx)
    if (!Model.sameGroups(matchGroups, groups)) matchGroups = groups

    var live = Model.liveMatches(allMatches, matchDetails)
    if (!Model.sameMatches(liveList, live)) liveList = live

    // Standings table for the active selection
    var rows = computeStandingsRows()
    if (!Model.sameRows(standingsRows, rows)) standingsRows = rows

    // Nearest upcoming kickoff, resolved once per data change so the per-second
    // clock never rescans the whole fixture list
    var bestT = Infinity
    var bestM = null
    for (var i = 0; i < allMatches.length; i++) {
      var m = allMatches[i]
      if (!m || m.status !== "upcoming") continue
      var t = Date.parse(m.time || "")
      if (isNaN(t) || t >= bestT) continue
      bestT = t
      bestM = m
    }
    if (bestT !== root.nextKickoffMs) root.nextKickoffMs = bestT
    if (bestM !== root.nextKickoffMatch) root.nextKickoffMatch = bestM
  }

  // Recompute derived state whenever any input changes. Qt.callLater coalesces
  // bursts (e.g. 16 detail responses landing back-to-back) into one pass.
  onAllMatchesChanged: Qt.callLater(refreshDerivedLists)
  onTeamMatchesRawChanged: Qt.callLater(refreshDerivedLists)
  onSelectedTeamIdsChanged: Qt.callLater(refreshDerivedLists)
  onFixtureFilterIdChanged: Qt.callLater(refreshDerivedLists)
  onActiveSportChanged: Qt.callLater(refreshDerivedLists)
  onMatchDetailsChanged: Qt.callLater(refreshDerivedLists)
  onMultiSportStandingsChanged: Qt.callLater(refreshDerivedLists)
  onLastPagesChanged: Qt.callLater(refreshDerivedLists)
  onStandingsLeagueIdChanged: Qt.callLater(refreshDerivedLists)

  readonly property string activeFixtureHeader: {
    if (activeSport === "f1") return "FIA FORMULA 1 WORLD CHAMPIONSHIP · CALENDAR"
    if (fixtureFilterId === "team" && selectedTeamIds.length > 0) return "MATCH SCHEDULE"
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
  readonly property bool setupEditorVisible: setupExpanded
    || selectedTeamIds.length === 0
    || (activeSport === "football" && selectedLeagueIds.length === 0)

  // ---- Tabs ---------------------------------------------------------------
  property int tabIndex: 0
  property bool showingSettings: false
  function toggleSettingsTab() {
    showingSettings = !showingSettings
  }

  onTabIndexChanged: {
    focusSection = 0
    if (stateLoaded) persistState()
  }
  readonly property var tabOptions: [
    { value: "team", label: "Fixtures", icon: "★" },
    { value: "live", label: "Live" + (root.liveCount > 0 ? " (" + root.liveCount + ")" : ""), icon: "●" },
    { value: "table", label: "Standings", icon: "󰝘" }
  ]
  readonly property int liveCount: liveList.length

  // Live Adaptive Clock: 1s with live matches for smooth clock ticks,
  // 15s when open with no live games (saves 93% idle wakeups), 60s when closed
  property double nowMs: Date.now()
  Timer {
    id: clockTicker
    interval: root.opened ? (root.liveCount > 0 ? 1000 : 15000) : (root.favoriteTeamLive ? 10000 : 60000)
    running: true
    repeat: true
    onTriggered: { root.nowMs = Date.now() }
  }

  readonly property string nextKickoffText: {
    // Nearest kickoff resolved once per data change (see refreshDerivedLists);
    // this binding only re-formats the countdown as the clock ticks
    var best = root.nextKickoffMatch
    if (!best || !(root.nextKickoffMs > root.nowMs)) return ""
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

  property var standingsRows: []

  // The lighter accent swatch in the table legend only makes sense when the
  // current table actually carries play-in/podium seeds
  readonly property bool standingsHasPlayin: {
    for (var i = 0; i < standingsRows.length; i++)
      if (standingsRows[i] && standingsRows[i].zone === "playin") return true
    return false
  }

  function computeStandingsRows() {
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
    if (activeSport !== "f1" || selectedTeamIds.length === 0) return null
    var drivers = (multiSportStandings && multiSportStandings["Drivers"]) || []
    var ids = Model.arrayFrom(selectedTeamIds)
    for (var i = 0; i < drivers.length; i++) {
      var d = drivers[i] || {}
      for (var j = 0; j < ids.length; j++) {
        var fav = String(ids[j] || "").toLowerCase()
        if (String(d.id || "").toLowerCase() === fav
            || String(d.shortName || "").toLowerCase() === fav
            || String(d.name || "").toLowerCase() === fav
            || String(d.teamId || "").toLowerCase() === fav) return d
      }
    }
    return null
  }

  // ---- Fetch round bookkeeping -------------------------------------------
  property int requestSerial: 0
  property var roundQueue: []
  property int nextDispatch: 0
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

  // Football fast polling refreshes only leagues containing a live followed
  // match. Team pages are fetched sequentially so every selected favorite is
  // represented without creating an unbounded process fan-out.
  property bool scopedFootballRound: false
  property var teamFetchQueue: []
  property int teamFetchIndex: 0
  property var teamRetryCounts: ({})
  property int teamRetrySerial: 0
  property string teamRetryId: ""
  property bool teamFetchActive: false
  property bool teamFetchIsRound: false
  property bool teamFetchFailed: false

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

  // teamMatches is maintained by refreshDerivedLists() (stable identity). The
  // visibility gate in MatchSpotlight already requires favorites-or-F1, so a
  // bare `allMatches` fallback here would silently surface any league match.
  readonly property var featuredMatch: teamMatches.length > 0 ? Model.featuredMatchForTeam(teamMatches) : null
  readonly property string selectedTeamName: selectedTeamIds.length > 0 ? root.teamNameFor(selectedTeamIds[0]) : ""
  readonly property string selectedLeagueNames: selectedLeagueNameList()

  // Bar badge + summary — driven ONLY by followed teams. An unrelated league
  // game must never claim the bar slot (or trigger fast polling); with no
  // favorites selected the bar shows just the sport icon.
  readonly property bool favoriteTeamLive: {
    for (var i = 0; i < teamMatches.length; i++)
      if (teamMatches[i] && teamMatches[i].status === "live") return true
    return false
  }
  readonly property string favoriteLiveState: {
    if (!favoriteTeamLive) return ""
    for (var i = 0; i < teamMatches.length; i++) {
      var m = teamMatches[i]
      if (m && m.status === "live") {
        return Model.matchLiveStateForTeams(m, selectedTeamIds)
      }
    }
    return ""
  }
  readonly property string favoriteSummaryText: {
    if (selectedTeamIds.length === 0) return ""
    if (favoriteTeamLive) {
      for (var i = 0; i < teamMatches.length; i++) {
        var m = teamMatches[i]
        if (!m || m.status !== "live") continue
        var h = (m.home.shortName || m.home.name).slice(0, 3).toUpperCase()
        var a = (m.away.shortName || m.away.name).slice(0, 3).toUpperCase()
        // Anti-spoiler masks the bar ticker exactly like goal notifications:
        // the bar is as bystander-visible as a toast, so an opted-out user
        // gets the clock without the scoreline
        var score = root.antiSpoiler ? "••••" : (m.scoreText || "0–0")
        return h + " " + score + " " + a + " " + Model.interpolateLiveTime(m, root.nowMs, root.lastUpdated.getTime())
      }
    }
    if (teamMatches.length === 0) return ""
    var first = teamMatches[0]
    var status = Model.matchStatusText(first)
    var tLabel = first.home && Model.isFollowedTeam(first.home.id, selectedTeamIds) ? (first.home.shortName || first.home.name) : (first.away ? (first.away.shortName || first.away.name) : (selectedTeamName || (first.home ? first.home.name : "")))
    return tLabel + " · " + status + (first.scoreText && first.status !== "upcoming" ? " " + first.scoreText : "")
  }

  readonly property var refreshIntervalOptions: Model.refreshIntervalOptions()

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
    scheduleSubSection = "all"
    persistState()
    allMatches = []
    teamMatchesRaw = []
    multiSportStandings = {}
    f1RaceWinners = {}
    f1CalendarRaw = ""
    lastPages = []
    matchDetails = {}
    matchBroadcasts = {}
    matchLeaders = {}
    matchEvents = {}
    matchForm = {}
    matchStats = {}
    f1Podium = []
    f1Pole = null
    leagueNews = []
    lastSeenMatches = {}
    ensureStandingsSelection()
    forceRefresh()
  }

  function restoreSportSelections() {
    if (activeSport === "football") {
      var fb = savedState.football || {}
      selectedLeagueIds = Model.normalizeLeagueIds(fb.leagueIds)
      selectedTeamIds = Model.normalizeTeamIds(fb.teamIds || (fb.teamId ? [fb.teamId] : []))
      standingsLeagueId = String(fb.standingsLeagueId || selectedLeagueIds[0])
      if (fb.tab === "settings") root.tabIndex = 3
      else if (fb.tab === "standings") root.tabIndex = 2
      else if (fb.tab === "live") root.tabIndex = 1
      else root.tabIndex = 0
    } else if (activeSport === "f1") {
      var f1 = savedState.f1 || {}
      selectedTeamIds = Model.normalizeTeamIds(f1.teamIds || (f1.teamId ? [f1.teamId] : []))
      standingsLeagueId = String(f1.standingsGroup || "Drivers")
      if (f1.tab === "settings") root.tabIndex = 3
      else if (f1.tab === "standings") root.tabIndex = 2
      else if (f1.tab === "live") root.tabIndex = 1
      else root.tabIndex = 0
    } else {
      var sp = savedState[activeSport] || {}
      selectedTeamIds = Model.normalizeTeamIds(sp.teamIds || (sp.teamId ? [sp.teamId] : []))
      standingsLeagueId = String(sp.standingsGroup || (standingsOptions.length > 0 ? standingsOptions[0].value : ""))
      if (sp.tab === "settings") root.tabIndex = 3
      else if (sp.tab === "standings") root.tabIndex = 2
      else if (sp.tab === "live") root.tabIndex = 1
      else root.tabIndex = 0
    }
    // Re-derive the fixtures filter: a dropdown interaction breaks the
    // property's initial binding, so a later state reload (external edit,
    // re-open) would otherwise carry the previous sport's filter and render
    // an empty Fixtures list despite fresh data
    fixtureFilterId = activeSport === "f1" ? "all" : (selectedTeamIds.length > 0 ? "team" : "all")
  }

  function toggleSpoiler() {
    antiSpoiler = !antiSpoiler
    if (antiSpoiler) {
      // Re-masking must not leave per-match reveals from the previous session
      revealedMatchIds = {}
    }
    savedState.antiSpoiler = antiSpoiler
    persistState()
  }

  function revealMatch(matchId) {
    revealedMatchIds = Model.dictSet(revealedMatchIds, String(matchId), true)
  }

  // Which F1 weekend cards have their sessions timetable unfolded
  property var f1ExpandedIds: ({})

  function toggleF1Expand(matchId) {
    var key = String(matchId)
    var next = f1ExpandedIds[key] ? Model.dictDelete(f1ExpandedIds, key) : Model.dictSet(f1ExpandedIds, key, true)
    f1ExpandedIds = next
  }

  // ---- Navigation ---------------------------------------------------------
  // Focus sections are derived from what is actually visible: a collapsed
  // setup editor or a non-football sport must not own keyboard stops. Rows
  // (fixtures/live cards) trail the chrome sections and open with Enter.
  readonly property var focusSections: {
    if (root.showingSettings) return ["settings"]
    var s = ["tabs", "sports", "refresh", "settings"]
    if (root.selectedTeamIds.length > 0 || (root.activeSport === "football" && root.selectedLeagueIds.length > 0)) s.push("setup")
    if (root.activeSport === "football" && root.setupEditorVisible) s.push("leagues")
    if (root.setupEditorVisible) s.push("teams")
    if (root.setupEditorVisible && root.selectedTeamIds.length > 0) s.push("clear")
    if (root.tabIndex === 0
        && ((root.selectedTeamIds.length > 0 && root.featuredMatch !== null)
            || (root.activeSport === "f1" && root.allMatches.length > 0))) s.push("spotlight")
    if (root.tabIndex === 2 && root.standingsOptions.length > 1) s.push("standings")
    return s
  }

  readonly property int rowSectionCount: root.showingSettings
    ? 0
    : (root.tabIndex === 0 ? flatFixtureRows.length : (root.tabIndex === 1 ? liveList.length : 0))

  // Fixtures flattened in visual order so row focus indices map to matches
  readonly property var flatFixtureRows: {
    var out = []
    for (var g = 0; g < matchGroups.length; g++) {
      var ms = matchGroups[g].matches || []
      for (var i = 0; i < ms.length; i++) out.push(ms[i])
    }
    return out
  }

  function sectionIndex(name) {
    return root.focusSections.indexOf(name)
  }

  function focusableControlCount() {
    return root.focusSections.length + root.rowSectionCount
  }

  function moveFocus(delta) {
    var count = focusableControlCount()
    if (count <= 0) return
    focusSection = (focusSection + delta + count) % count
  }

  function moveWithin(dx) {
    if (anyPopupOpen()) {
      moveFocus(dx)
      return
    }
    if (focusSection === sectionIndex("sports")) {
      var sportsList = Model.sports()
      var current = 0
      for (var i = 0; i < sportsList.length; i++) {
        if (sportsList[i].value === activeSport) { current = i; break }
      }
      switchSport(sportsList[(current + dx + sportsList.length) % sportsList.length].value)
      return
    }
    if (focusSection === sectionIndex("tabs")) {
      var next = (tabIndex + dx + tabOptions.length) % tabOptions.length
      tabIndex = next
      return
    }
    moveFocus(dx)
  }

  function anyPopupOpen() {
    return (panelHeader && panelHeader.anyPopupOpen)
      || (fixturesTab && fixturesTab.anyPopupOpen)
      || (standingsTab && standingsTab.anyPopupOpen)
      || (settingsTab && settingsTab.anyPopupOpen)
  }

  function activateFocus() {
    var base = root.focusSections.length
    if (focusSection >= base) {
      // Row section: Enter activates the focused fixture/live card
      var r = focusSection - base
      var m = null
      if (root.tabIndex === 0) m = flatFixtureRows[r] || null
      else if (root.tabIndex === 1) m = liveList[r] || null
      root.activateRow(m)
      return
    }
    var name = root.focusSections[focusSection]
    if (name === "sports") {
      var sportsList = Model.sports()
      var current = 0
      for (var i = 0; i < sportsList.length; i++) {
        if (sportsList[i].value === root.activeSport) { current = i; break }
      }
      root.switchSport(sportsList[(current + 1) % sportsList.length].value)
    } else if (name === "tabs") root.tabIndex = (root.tabIndex + 1) % root.tabOptions.length
    else if (name === "refresh") root.refresh()
    else if (name === "settings") root.toggleSettingsTab()
    else if (name === "setup") root.setupExpanded = !root.setupExpanded
    else if (name === "spotlight") root.activateSpotlight()
    else if (name === "leagues" && fixturesTab) fixturesTab.toggleLeagues()
    else if (name === "teams" && fixturesTab) fixturesTab.toggleTeams()
    else if (name === "clear") root.clearSelectedTeam()
    else if (name === "standings" && standingsTab) standingsTab.toggleStandings()
  }

  function activateSpotlight() {
    var m = root.featuredMatch || (root.activeSport === "f1" ? Model.featuredMatchForTeam(root.allMatches) : null)
    if (!m) return
    var hidden = root.antiSpoiler && m.status === "finished"
      && !(root.revealedMatchIds[String(m.id)] === true)
    if (hidden) root.revealMatch(m.id)
    else root.openMatch(m)
  }

  // Keyboard activation must mirror the row's click behavior: F1 weekend
  // cards unfold their sessions instead of opening a browser
  function activateRow(m) {
    if (!m) return
    if (m.sport === "f1") {
      if (m.sessions && m.sessions.length > 0) root.toggleF1Expand(m.id)
      return
    }
    // Enter must mirror the pointer path: anti-spoiler results are revealed
    // first instead of unexpectedly launching an external browser.
    var scoreHidden = root.antiSpoiler && m.status === "finished"
      && !(root.revealedMatchIds[String(m.id)] === true)
    if (scoreHidden) root.revealMatch(m.id)
    else root.openMatch(m)
  }

  // ---- Lifecycle -----------------------------------------------------------
  onOpenedChanged: {
    if (root.opened) {
      setCenterHoverRevealSuppressed(true)
      if (!root.routedExplicitly && root.liveCount > 0 && root.tabIndex === 0) root.tabIndex = 1
      root.routedExplicitly = false
      scheduleNextPoll()
      if (root.stateLoaded && !root.loading && (needsAutoRefresh() || root.allMatches.length === 0)) root.refresh()
      else if (!root.loading && detailQueue.length > 0) Qt.callLater(root.nextDetail)
    } else {
      setCenterHoverRevealSuppressed(false)
      openedFromHotkey = false
      scheduleNextPoll()
    }
  }

  function open() { root.openFromHotkey() }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    stateFile.reload()
    Qt.callLater(function() {
      if (root.opened) scheduleNextPoll()
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    openedFromHotkey = false
    showingSettings = false
    root.controller.hide()
    scheduleNextPoll()
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

  function stateFilePath() {
    return root.userHome + "/.config/omarchy/sports-favorites.json"
  }

  function applyState(raw) {
    var str = String(raw || "")
    // A non-empty file that fails to parse is corruption (crash mid-write,
    // disk full, manual edit) — preserve it before any persist can overwrite
    // the user's leagues and teams with defaults
    if (str.trim() !== "") {
      try { JSON.parse(str) } catch (e) {
        console.warn("omasports: state file corrupt — backing up before continuing with defaults")
        stateBackupProc.command = ["cp", stateFilePath(), stateFilePath() + ".corrupt"]
        stateBackupProc.running = true
      }
    }
    var nextState = Model.parseState(str)
    var ownWrite = ignoredStateSignature !== ""
      && JSON.stringify(nextState) === ignoredStateSignature
    if (ownWrite) ignoredStateSignature = ""
    savedState = nextState
    activeSport = String(savedState.sport || "football")
    antiSpoiler = savedState.antiSpoiler === true
    enableNotifications = savedState.notifications !== false
    showNewsWire = savedState.showNewsWire !== false
    if (savedState.backgroundUpdates !== undefined) {
      backgroundUpdates = savedState.backgroundUpdates === true
    } else {
      backgroundUpdates = true
    }
    if (savedState.showBarTicker !== undefined) {
      showBarTicker = savedState.showBarTicker === true
    } else {
      showBarTicker = setting("showBarTicker", true) === true
    }
    showSpotlight = savedState.showSpotlight !== false
    restoreSportSelections()
    stateLoaded = true

    if (fixturesTab && fixturesTab.leaguePicker) fixturesTab.leaguePicker.values = selectedLeagueIds
    ensureStandingsSelection()
    if (!ownWrite && (root.opened || root.backgroundUpdates || root.enableNotifications)) {
      espnRetryCount = 0
      f1RetryCount = 0
      root.startRound()
    } else {
      root.scheduleNextPoll()
    }
  }

  function persistState() {
    if (!stateLoaded) return
    var tabName = tabIndex === 3 ? "settings" : (tabIndex === 2 ? "standings" : (tabIndex === 1 ? "live" : "fixtures"))
    savedState = Model.buildPersistedState(activeSport, savedState, {
      tabName: tabName,
      selectedLeagueIds: selectedLeagueIds,
      selectedTeamIds: selectedTeamIds,
      selectedTeamName: selectedTeamName,
      standingsLeagueId: standingsLeagueId,
      antiSpoiler: antiSpoiler,
      enableNotifications: enableNotifications,
      backgroundUpdates: backgroundUpdates,
      showBarTicker: showBarTicker,
      showSpotlight: showSpotlight
    })
    savedState.showNewsWire = showNewsWire
    savedState.backgroundUpdates = backgroundUpdates
    savedState.showBarTicker = showBarTicker
    savedState.showSpotlight = showSpotlight
    ignoredStateSignature = JSON.stringify(savedState)
    persistenceError = ""
    stateFile.setText(JSON.stringify(savedState, null, 2) + "\n")
  }

  function toggleNotifications() {
    if (!notificationToolAvailable) {
      // The probe ran once at startup; if the user installed libnotify-bin
      // later, re-probe before giving up. A second failed probe leaves the
      // button disabled and surfaces a one-time warning to the logs.
      if (notificationProbe.running) return
      notificationWarningShown = false
      notificationProbe.running = true
      return
    }
    enableNotifications = !enableNotifications
    savedState.notifications = enableNotifications
    persistState()
    if (enableNotifications) {
      sendDesktopNotification("OmaSports", "Goal and kickoff notifications enabled!", "", "normal")
    }
  }

  function sendDesktopNotification(title, body, iconPath, urgency) {
    if (!root.enableNotifications || !root.notificationToolAvailable) {
      if (root.enableNotifications && !root.notificationToolAvailable && !root.notificationWarningShown) {
        root.notificationWarningShown = true
        console.warn("omasports: notify-send is unavailable; desktop notifications are disabled")
      }
      return
    }
    var next = Model.arrayFrom(notificationQueue)
    if (next.length >= 5) next.splice(0, next.length - 4)
    next.push({ title: String(title || ""), body: String(body || ""), iconPath: String(iconPath || ""), urgency: String(urgency || "") })
    notificationQueue = next
    dispatchNextNotification()
  }

  function dispatchNextNotification() {
    if (notifierProc.running || notificationPacingTimer.running || notificationQueue.length === 0 || !notificationToolAvailable) return
    var next = Model.arrayFrom(notificationQueue)
    var item = next.shift()
    notificationQueue = next
    var cmd = ["notify-send", "-a", "OmaSports"]
    if (item.iconPath && item.iconPath.trim()) {
      var p = item.iconPath
      if (p.indexOf("file://") === 0) p = p.slice(7)
      // A path that does not live under the configured cache directory must
      // not be handed to notify-send as `-i`. Otherwise a crafted team id
      // that survives crestCacheKey() could point notify-send at an
      // arbitrary file under the user's home (defense in depth alongside
      // crestCacheKey's bytes whitelist).
      var cacheRoot = logoCacheDir()
      if (p.indexOf(cacheRoot) === 0) cmd.push("-i", p)
    }
    if (item.urgency) cmd.push("-u", item.urgency)
    // "--" ends option parsing: provider-derived strings must never be
    // mistaken for flags even when they start with a dash.
    cmd.push("--", item.title, item.body)
    notifierProc.command = cmd
    notifierProc.running = true
  }

  function logoCacheDir() {
    return root.userHome + "/.cache/omarchy-omasports/logos/"
  }

  function crestIconPath(sport, team) {
    var key = Model.crestCacheKey(sport, team && team.id ? team.id : "", team && team.abbr ? team.abbr : "")
    if (key === "" || !root.knownLogoKeys[key]) return ""
    return logoCacheDir() + key + ".png"
  }

  function checkScoreNotifications() {
    var result = Model.diffMatchNotifications(allMatches, lastSeenMatches, {
      enabled: root.enableNotifications,
      activeSport: root.activeSport,
      favoriteIds: root.selectedTeamIds,
      antiSpoiler: root.antiSpoiler,
      nowMs: root.nowMs
    })
    var events = Model.arrayFrom(result.notifications)
    for (var i = 0; i < events.length; i++) {
      var event = events[i]
      sendDesktopNotification(
        event.title,
        event.body,
        crestIconPath(event.sport || root.activeSport, event.iconTeam),
        event.urgency || "normal"
      )
    }
    lastSeenMatches = result.nextSeen
  }

  function normalizeFixtureFilter() {
    if (activeSport === "f1" || selectedTeamIds.length === 0) {
      fixtureFilterId = "all"
      return
    }
    if (fixtureFilterId.indexOf("fav_") === 0
        && !Model.isFollowedTeam(fixtureFilterId.slice(4), selectedTeamIds)) {
      fixtureFilterId = "team"
    }
  }

  function setSelectedLeagues(values) {
    var next = Model.normalizeLeagueIds(values)
    errorMessage = ""
    selectedLeagueIds = next
    if (fixturesTab && fixturesTab.leaguePicker) fixturesTab.leaguePicker.values = next
    ensureStandingsSelection()
    persistState()
    if (root.opened || root.backgroundUpdates || root.enableNotifications) root.forceRefresh()
  }

  function toggleSelectedTeam(value) {
    var id = String(value || "").trim()
    if (!id) return
    var arr = Model.arrayFrom(selectedTeamIds)
    var idx = arr.indexOf(id)
    if (idx !== -1) arr.splice(idx, 1)
    else arr.push(id)
    errorMessage = ""
    selectedTeamIds = arr
    teamMatchesRaw = []
    normalizeFixtureFilter()
    persistState()
    if (activeSport === "football" && arr.length > 0) root.fetchFootballTeamPage()
    else if (activeSport === "football") stopTeamPageFetch()
  }

  function removeSelectedTeam(value) {
    var id = String(value || "").trim()
    var arr = Model.arrayFrom(selectedTeamIds)
    var idx = arr.indexOf(id)
    if (idx !== -1) {
      arr.splice(idx, 1)
      errorMessage = ""
      selectedTeamIds = arr
      teamMatchesRaw = []
      normalizeFixtureFilter()
      persistState()
      if (activeSport === "football" && arr.length > 0) root.fetchFootballTeamPage()
      else if (activeSport === "football") stopTeamPageFetch()
    }
  }

  function setSelectedTeam(value) {
    root.toggleSelectedTeam(value)
  }

  function clearSelectedTeam() {
    errorMessage = ""
    selectedTeamIds = []
    teamMatchesRaw = []
    normalizeFixtureFilter()
    if (activeSport === "football") {
      if (root.loading) root.forceRefresh()
      else {
        requestSerial++
        stopNetworkWorkers()
      }
    }
    persistState()
  }

  function setRefreshMinutes(value) {
    var minutes = Model.clampRefreshMinutes(value)
    savedState.refreshMinutes = minutes
    persistState()
    scheduleNextPoll()
  }

  function setStandingsLeague(value) {
    standingsLeagueId = String(value || "")
    persistState()
    // First time a cached F1 table is requested, go get it
    if (activeSport === "f1") {
      f1EnsureStandings(standingsLeagueId === "Constructors" ? "Constructors" : "Drivers")
    }
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
    var minutes = Model.clampRefreshMinutes(savedState.refreshMinutes)
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
    // A round is already in flight — restarting workers mid-flight would
    // double-fetch and risk stale responses overwriting fresh data
    if (root.loading) return
    forceRefresh()
  }

  // Unconditional round start: sport switches and state reloads must cancel
  // whatever generation is in flight even if refresh() would normally defer
  function forceRefresh() {
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
    stopNetworkWorkers()

    if (root.mockMode) {
      finishMockRound()
      return
    }

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

  // Kill every in-flight request so a stale generation can never land after
  // a new round starts (switching sports, IPC refresh spam, state reloads).
  // handled=true suppresses late StdioCollector/exit callbacks; the serial
  // gates inside the resolve functions are the second line of defense.
  function stopNetworkWorkers() {
    retryDelay.stop()
    teamRetryDelay.stop()
    teamFetchActive = false
    teamFetchQueue = []
    teamRetryId = ""
    detailQueue = []
    // Background helpers must also be killed on sport switch / IPC refresh:
    // a stale curl writing PNGs after the round has been replaced pollutes the
    // disk cache, and an in-flight notify-send from the previous sport queues a
    // bogus goal alert for a match the user no longer follows.
    var procs = [workerScoreboard, workerStandings, workerF1Calendar, workerF1Drivers,
                 workerF1Constructors, workerF1Winners, workerF1Podium, workerF1Pole,
                 workerNews, workerTeam,
                 detailProcA, detailProcB, detailProcC,
                 workerA, workerB, workerC, workerD,
                 logoScanProc, logoEvictProc, logoCacheProc,
                 notificationProbe, notifierProc,
                 stateBackupProc, matchOpener]
    for (var i = 0; i < procs.length; i++) {
      var w = procs[i]
      // NetworkProcess owns `handled`; plain Process helpers (notify-send,
      // logo cache, xdg-open) do not — assigning it throws at runtime.
      if ("handled" in w) w.handled = true
      if (w.running) w.running = false
    }
  }

  // ---- Mock Round (OMASPORTS_MOCK=1) -----------------------------------------
  function finishMockRound() {
    var mock = Model.mockRound(activeSport, Date.now())
    allMatches = mock.matches
    if (mock.standings && Object.keys(mock.standings).length > 0) multiSportStandings = mock.standings

    leagueNews = [
      {
        headline: "Championship Race Tightens Ahead of Decisive Weekend Slate",
        description: "Tactical battles, lineup rotations, and key returns set up crucial matchups across the league.",
        published: new Date(Date.now() - 3600000 * 2).toISOString(),
        url: "https://www.espn.com"
      },
      {
        headline: "Transfer Buzz & Contract Talks Surface Before Trade Deadline",
        description: "Front offices evaluate mid-season moves and salary cap flexibility for playoff pushes.",
        published: new Date(Date.now() - 3600000 * 6).toISOString(),
        url: "https://www.espn.com"
      }
    ]

    var bcasts = {}
    var lds = {}
    var evs = {}
    var fms = {}
    var sts = {}
    for (var mi = 0; mi < allMatches.length; mi++) {
      var mm = allMatches[mi]
      if (!mm) continue
      var mid = String(mm.id)
      bcasts[mid] = (mi % 2 === 0) ? "NBC" : "ESPN"
      lds[mid] = [
        { category: "PTS", player: "L. Doncic", displayValue: "34 PTS" },
        { category: "REB", player: "D. Lively", displayValue: "12 REB" },
        { category: "AST", player: "K. Irving", displayValue: "8 AST" }
      ]
      evs[mid] = {
        goals: [
          { minute: "23'", player: "B. Saka", isHome: true },
          { minute: "68'", player: "K. Havertz", isHome: true }
        ],
        redCards: []
      }
      fms[mid] = { home: ["W", "W", "D", "W", "W"], away: ["W", "L", "W", "D", "L"] }
      sts[mid] = { possession: [62, 38], xG: ["2.14", "0.52"], shotsOnTarget: [7, 2] }
    }
    matchBroadcasts = bcasts
    matchLeaders = lds
    matchEvents = evs
    matchForm = fms
    matchStats = sts

    if (activeSport === "f1") {
      f1Podium = [
        { pos: 1, driverName: "Max Verstappen", code: "VER", constructorName: "Red Bull Racing", time: "1:28:45.123", points: "25" },
        { pos: 2, driverName: "Lando Norris", code: "NOR", constructorName: "McLaren", time: "+2.418s", points: "18" },
        { pos: 3, driverName: "Charles Leclerc", code: "LEC", constructorName: "Ferrari", time: "+8.910s", points: "15" }
      ]
      f1Pole = { driverName: "Lando Norris", code: "NOR", constructorName: "McLaren", lapTime: "1:26.741" }
    }

    lastUpdated = new Date()
    loadedFromCache = false
    ensureStandingsSelection()
    checkScoreNotifications()
    loading = false
    scheduleNextPoll()
  }

  // ---- Football Round (FotMob) ---------------------------------------------
  function startFootballRound() {
    var workers = [workerA, workerB, workerC, workerD]
    for (var i = 0; i < workers.length; i++) {
      if (workers[i].running) workers[i].running = false
      workers[i].handled = false
    }
    retryDelay.stop()
    teamRetryDelay.stop()
    pendingRetryIds = []
    nextDispatch = 0
    roundResults = {}
    retryCounts = {}
    scopedFootballRound = root.fastPolling && selectedTeamIds.length > 0
    fetchLeagueNews()

    if (scopedFootballRound) {
      // A live followed match identifies the only league pages that need to
      // be refreshed at 40-second cadence. Team pages below still cover live
      // fixtures in competitions outside the selected league list.
      var liveLeagueIds = []
      for (var l = 0; l < teamMatches.length; l++) {
        var liveMatch = teamMatches[l]
        var liveLeagueId = String(liveMatch && liveMatch.status === "live" ? liveMatch.leagueId || "" : "")
        if (liveLeagueId && liveLeagueIds.indexOf(liveLeagueId) === -1) liveLeagueIds.push(liveLeagueId)
      }
      roundQueue = liveLeagueIds.slice(0, 12)
    } else {
      roundQueue = Model.arrayFrom(selectedLeagueIds).slice(0, 12)
    }

    // An empty queue is valid for a scoped round when the live fixture is
    // outside the selected leagues; the followed-team page still runs.
    if (roundQueue.length === 0 && !scopedFootballRound && selectedTeamIds.length === 0) {
      loading = false
      errorMessage = "Select at least one league or favorite team to load matches."
      scheduleNextPoll()
      return
    }

    beginTeamPageFetch(selectedTeamIds, true)
    Qt.callLater(pumpFootball)
  }

  function stopTeamPageFetch() {
    teamRetryDelay.stop()
    teamFetchActive = false
    teamFetchQueue = []
    teamRetryId = ""
    workerTeam.handled = true
    if (workerTeam.running) workerTeam.running = false
  }

  function beginTeamPageFetch(ids, isRound) {
    if (workerTeam.running) workerTeam.running = false
    workerTeam.handled = true
    teamRetryDelay.stop()
    teamFetchQueue = Model.normalizeTeamIds(ids)
    teamFetchIndex = 0
    teamRetryCounts = {}
    teamRetryId = ""
    teamRetrySerial = root.requestSerial
    teamFetchIsRound = isRound === true
    teamFetchFailed = false
    teamFetchActive = teamFetchQueue.length > 0
    if (teamFetchActive) Qt.callLater(fetchNextFootballTeamPage)
    else if (teamFetchIsRound) Qt.callLater(root.pumpFootball)
  }

  // Kept as the public entry point used when a favorite changes. It now
  // refreshes every selected football team rather than only the first one.
  function fetchFootballTeamPage() {
    if (selectedTeamIds.length === 0) return
    // A selection change while a full round is in flight must invalidate the
    // old league/team generation together; otherwise its late callback can
    // repopulate the schedule with the previous favorite.
    if (root.loading) {
      root.forceRefresh()
      return
    }
    errorMessage = ""
    requestSerial++
    stopNetworkWorkers()
    beginTeamPageFetch(selectedTeamIds, false)
  }

  function fetchNextFootballTeamPage() {
    if (!teamFetchActive || workerTeam.running) return
    if (teamFetchIndex >= teamFetchQueue.length) {
      teamFetchActive = false
      teamRetryId = ""
      if (teamFetchIsRound) {
        Qt.callLater(root.pumpFootball)
      } else {
        if (teamFetchFailed) errorMessage = "Favorite team schedule could not be loaded."
        else if (errorMessage === "Favorite team schedule could not be loaded.") errorMessage = ""
        startDetailFetch()
        downloadMissingLogos()
        checkScoreNotifications()
        scheduleNextPoll()
      }
      return
    }

    var id = String(teamFetchQueue[teamFetchIndex] || "")
    if (!id) {
      teamFetchIndex++
      Qt.callLater(fetchNextFootballTeamPage)
      return
    }
    workerTeam.handled = false
    workerTeam.teamId = id
    workerTeam.serial = root.requestSerial
    workerTeam.command = [
      "curl", "-LfsS", "--compressed", "--max-time", "12",
      "-H", "Cache-Control: no-cache",
      "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
      "https://www.fotmob.com/teams/" + encodeURIComponent(id) + "?_=" + Date.now()
    ]
    workerTeam.running = true
  }

  function retryOrAdvanceTeamPage(id) {
    var tries = teamRetryCounts[id] || 0
    if (tries < Model.MAX_ROUND_RETRIES) {
      teamRetryCounts[id] = tries + 1
      teamRetryId = id
      teamRetrySerial = root.requestSerial
      teamRetryDelay.restart()
      return
    }
    teamFetchFailed = true
    teamFetchIndex++
    Qt.callLater(fetchNextFootballTeamPage)
  }

  function resolveTeamWorker(raw) {
    if (workerTeam.serial !== root.requestSerial || !teamFetchActive || workerTeam.handled) return
    workerTeam.handled = true
    var id = String(workerTeam.teamId || "")
    var payload = String(raw || "")
    var valid = payload.trim() !== "" && Model.isTeamPagePayload(payload, id)
    var parsed = []
    if (valid) {
      try { parsed = Model.parseTeamPage(payload, id) } catch (e) { valid = false }
    }
    if (!valid) {
      retryOrAdvanceTeamPage(id)
      return
    }

    if (parsed.length > 0) {
      teamMatchesRaw = Model.mergeMatchUpdates(teamMatchesRaw, parsed)
      allMatches = Model.mergeMatchUpdates(allMatches, parsed)
      lastUpdated = new Date()
    }
    teamRetryCounts[id] = 0
    teamFetchIndex++
    Qt.callLater(fetchNextFootballTeamPage)
  }

  function startFootballWorker(w, leagueId) {
    w.handled = false
    w.leagueId = String(leagueId)
    w.serial = root.requestSerial
    w.command = [
      "curl", "-LfsS", "--compressed", "--max-time", "12",
      "-H", "Cache-Control: no-cache",
      "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
      "https://www.fotmob.com/leagues/" + encodeURIComponent(w.leagueId) + "?_=" + Date.now()
    ]
    w.running = true
  }

  function pumpFootball() {
    if (!root.loading || activeSport !== "football") return
    var workers = [workerA, workerB, workerC, workerD]
    var anyBusy = teamFetchActive || workerTeam.running
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
    if (!anyBusy && nextDispatch >= roundQueue.length && pendingRetryIds.length === 0) finishFootballLoading()
  }

  function resolveFootballWorker(w, raw) {
    if (w.handled || w.serial !== root.requestSerial) return
    w.handled = true
    var id = w.leagueId
    var page = null
    if (String(raw || "").trim()) {
      try { page = Model.parseLeaguePage(raw, id) } catch (e) { page = null }
    }
    // A page that parses but yields no matches AND no standings is almost
    // always a bot-wall or schema drift — treat it like a failure so the
    // retry path runs instead of silently showing an empty league.
    if (page && (page.matches.length > 0 || page.standings.length > 0)) {
      roundResults[id] = page
    } else {
      var tries = retryCounts[id] || 0
      if (tries < Model.MAX_ROUND_RETRIES) {
        retryCounts[id] = tries + 1
        pendingRetryIds.push(id)
        retryDelay.restart()
      } else {
        failedLeagues.push(Model.leagueLabel(id))
      }
    }
    Qt.callLater(root.pumpFootball)
  }

  function finishFootballLoading() {
    loading = false
    var pages = []
    var pageIds = scopedFootballRound ? Model.arrayFrom(roundQueue) : Model.arrayFrom(selectedLeagueIds)
    var included = {}
    for (var i = 0; i < pageIds.length; i++) {
      var key = String(pageIds[i])
      included[key] = true
      if (roundResults[key]) pages.push(roundResults[key])
    }
    // A provider may resolve a league under a canonical id different from the
    // requested id; do not silently discard that page.
    for (var resultId in roundResults) {
      if (!included[resultId]) pages.push(roundResults[resultId])
    }

    var pageSnapshot
    if (scopedFootballRound) {
      pageSnapshot = Model.mergeLeaguePages(lastPages, pages)
    } else {
      // A failed league request must not erase its last good page, while a
      // deliberately deselected league must disappear on the next full round.
      pageSnapshot = Model.mergeLeaguePages([], pages)
      var selectedPages = {}
      var successfulPages = {}
      for (var p = 0; p < pages.length; p++) {
        if (pages[p] && pages[p].league) successfulPages[String(pages[p].league.id)] = true
      }
      var selectedIds = Model.arrayFrom(selectedLeagueIds)
      for (var s = 0; s < selectedIds.length; s++) selectedPages[String(selectedIds[s])] = true
      for (var old = 0; old < lastPages.length; old++) {
        var oldPage = lastPages[old]
        var oldId = String(oldPage && oldPage.league ? oldPage.league.id : "")
        if (selectedPages[oldId] && !successfulPages[oldId])
          pageSnapshot = Model.mergeLeaguePages(pageSnapshot, [oldPage])
      }
    }
    if (pageSnapshot.length > 0 || teamMatchesRaw.length > 0) {
      var mergedMatches = Model.mergePages(pageSnapshot)
      if (allMatches.length > 0) mergedMatches = Model.mergeMatchUpdates(allMatches, mergedMatches)
      if (teamMatchesRaw.length > 0) mergedMatches = Model.mergeMatchUpdates(mergedMatches, teamMatchesRaw)
      mergedMatches = Model.reconcileMatchDetails(mergedMatches, matchDetails)
      if (mergedMatches.length > 0 || pageSnapshot.length > 0) allMatches = mergedMatches
      lastUpdated = new Date()
      loadedFromCache = false
      if (pageSnapshot.length > 0) lastPages = pageSnapshot
    }
    ensureStandingsSelection()
    startDetailFetch()
    downloadMissingLogos()
    checkScoreNotifications()
    scheduleNextPoll()

    if (pages.length === 0 && !hasData && teamMatchesRaw.length === 0) {
      errorMessage = "Unable to load matches. Check your connection."
    } else if (failedLeagues.length > 0) {
      errorMessage = "Some leagues could not be loaded: " + failedLeagues.join(", ")
    } else if (teamFetchFailed) {
      errorMessage = "Favorite team schedule could not be loaded."
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
    workerScoreboard.gotData = false
    workerScoreboard.serial = root.requestSerial
    workerScoreboard.sportCode = sportCode
    workerScoreboard.defaultName = defaultName
    workerScoreboard.command = ["curl", "-LfsS", "--max-time", "10", "-H", "Cache-Control: no-cache", "https://site.api.espn.com/apis/site/v2/sports/" + espnPath + "/scoreboard?" + dates]
    workerScoreboard.running = true

    workerStandings.handled = false
    workerStandings.gotData = false
    workerStandings.serial = root.requestSerial
    workerStandings.sportCode = sportCode
    workerStandings.command = ["curl", "-LfsS", "--max-time", "10", "-H", "Cache-Control: no-cache", "https://site.api.espn.com/apis/v2/sports/" + espnPath + "/standings"]
    workerStandings.running = true
    fetchLeagueNews()
  }

  function resolveEspnScoreboard(raw, sportCode, defaultName) {
    var payload = String(raw || "")
    if (payload.trim()) {
      // A syntactically valid response counts as success even when the window
      // legitimately holds zero games (off-season, pre-season): gating on
      // non-empty output made every quiet day retry 3x and end in a bogus
      // "check connection" error despite healthy responses.
      var json = null
      try { json = JSON.parse(payload) } catch (e) { json = null }
      if (Model.isEspnScoreboardPayload(json)) {
        allMatches = Model.parseEspnScoreboard(payload, sportCode, defaultName)
        var events = Model.arrayFrom(json.events)
        var broadcasts = Object.assign({}, matchBroadcasts)
        var leaders = Object.assign({}, matchLeaders)
        for (var evI = 0; evI < events.length; evI++) {
          var evObj = events[evI]
          if (!evObj) continue
          var evComp = (evObj.competitions && evObj.competitions[0]) || {}
          var evId = String(evObj.id || "")
          if (evId) {
            var bCast = Model.parseEspnBroadcast(evComp)
            if (bCast) broadcasts[evId] = bCast
            var lds = Model.parseEspnGameLeaders(evComp)
            if (lds && lds.length > 0) leaders[evId] = lds
          }
        }
        matchBroadcasts = broadcasts
        matchLeaders = leaders
        lastUpdated = new Date()
        loadedFromCache = false
        workerScoreboard.gotData = true
      }
    }
    Qt.callLater(checkEspnDone)
  }

  function resolveEspnStandings(raw, sportCode) {
    var payload = String(raw || "")
    if (payload.trim()) {
      var json2 = null
      try { json2 = JSON.parse(payload) } catch (e) { json2 = null }
      if (Model.isEspnStandingsPayload(json2)) {
        var st = Model.parseEspnStandings(payload, sportCode)
        multiSportStandings = st
        workerStandings.gotData = true
      }
    }
    Qt.callLater(checkEspnDone)
  }

  function checkEspnDone() {
    if (workerScoreboard.running || workerStandings.running) return
    // Either endpoint missing data is retryable on its own; a partial outage
    // (scores ok, standings dead or vice versa) must not pass silently
    var sbOk = workerScoreboard.gotData
    var stOk = workerStandings.gotData
    if ((!sbOk || !stOk) && espnRetryCount < Model.MAX_ROUND_RETRIES) {
      espnRetryCount++
      espnRetrySerial = requestSerial
      espnRetryDelay.restart()
      return
    }
    loading = false
    ensureStandingsSelection()
    downloadMissingLogos()
    checkScoreNotifications()
    if (!sbOk && !stOk) {
      errorMessage = "Unable to load " + activeSportMeta.label + " data. Check connection."
    } else if (!stOk) {
      errorMessage = "Standings could not be loaded."
    } else if (!sbOk) {
      errorMessage = "Scores could not be loaded."
    }
    scheduleNextPoll()
  }

  // ---- Formula 1 Round (Jolpica / Ergast) ----------------------------------
  function startF1Round() {
    workerF1Calendar.handled = false
    workerF1Calendar.gotData = false
    workerF1Calendar.serial = root.requestSerial
    workerF1Calendar.command = ["curl", "-LfsS", "--max-time", "10", "https://api.jolpi.ca/ergast/f1/current.json"]
    workerF1Calendar.running = true

    // Jolpica documents strict rate limits — standings and race winners are fetched
    // once per session (they only change at race cadence) instead of on every
    // poll alongside the calendar
    f1EnsureStandings("Drivers")
    f1EnsureStandings("Constructors")
    f1EnsureWinners()
    f1EnsurePodium()
    f1EnsurePole()
    fetchLeagueNews()
  }

  function f1EnsurePodium() {
    if (f1Podium && f1Podium.length >= 3) {
      workerF1Podium.handled = true
      workerF1Podium.gotData = true
      return
    }
    if (workerF1Podium.running) return
    workerF1Podium.handled = false
    workerF1Podium.gotData = false
    workerF1Podium.serial = root.requestSerial
    workerF1Podium.command = ["curl", "-LfsS", "--max-time", "10", "https://api.jolpi.ca/ergast/f1/current/last/results.json"]
    workerF1Podium.running = true
  }

  function resolveF1Podium(raw) {
    var pod = Model.parseF1Podium(String(raw || ""))
    if (pod && pod.length > 0) {
      f1Podium = pod
      workerF1Podium.gotData = true
    }
  }

  function f1EnsurePole() {
    if (f1Pole) {
      workerF1Pole.handled = true
      workerF1Pole.gotData = true
      return
    }
    if (workerF1Pole.running) return
    workerF1Pole.handled = false
    workerF1Pole.gotData = false
    workerF1Pole.serial = root.requestSerial
    workerF1Pole.command = ["curl", "-LfsS", "--max-time", "10", "https://api.jolpi.ca/ergast/f1/current/last/qualifying.json"]
    workerF1Pole.running = true
  }

  function resolveF1Pole(raw) {
    var pole = Model.parseF1Pole(String(raw || ""))
    if (pole) {
      f1Pole = pole
      workerF1Pole.gotData = true
    }
  }

  function fetchLeagueNews() {
    if (!root.showNewsWire) return
    if (workerNews.running) return
    var url = ""
    if (activeSport === "football") url = "https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/news"
    else if (activeSport === "f1") url = "https://site.api.espn.com/apis/site/v2/sports/racing/f1/news"
    else if (activeSport === "nba") url = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/news"
    else if (activeSport === "nfl") url = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/news"
    else if (activeSport === "mlb") url = "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/news"
    else if (activeSport === "nhl") url = "https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/news"
    if (!url) return

    workerNews.handled = false
    workerNews.gotData = false
    workerNews.serial = root.requestSerial
    workerNews.command = ["curl", "-LfsS", "--max-time", "10", url]
    workerNews.running = true
  }

  function resolveNews(raw) {
    var news = Model.parseEspnNews(String(raw || ""))
    if (news && news.length > 0) {
      leagueNews = news
      workerNews.gotData = true
    }
  }

  function f1EnsureStandings(group) {
    var w = group === "Constructors" ? workerF1Constructors : workerF1Drivers
    if ((multiSportStandings[group] || []).length > 0) {
      w.handled = true
      w.gotData = true
      return
    }
    if (w.running) return
    w.handled = false
    w.gotData = false
    w.serial = root.requestSerial
    var path = group === "Constructors" ? "constructorStandings" : "driverStandings"
    w.command = ["curl", "-LfsS", "--max-time", "10", "https://api.jolpi.ca/ergast/f1/current/" + path + ".json"]
    w.running = true
  }

  function f1EnsureWinners() {
    if (f1RaceWinners && Object.keys(f1RaceWinners).length > 0) {
      workerF1Winners.handled = true
      workerF1Winners.gotData = true
      return
    }
    if (workerF1Winners.running) return
    workerF1Winners.handled = false
    workerF1Winners.gotData = false
    workerF1Winners.serial = root.requestSerial
    workerF1Winners.command = ["curl", "-LfsS", "--max-time", "10", "https://api.jolpi.ca/ergast/f1/current/results/1.json"]
    workerF1Winners.running = true
  }

  function resolveF1Winners(raw) {
    var winners = Model.parseF1SeasonWinners(String(raw || ""))
    if (winners && Object.keys(winners).length > 0) {
      f1RaceWinners = winners
      if (f1CalendarRaw) {
        allMatches = Model.parseF1Calendar(f1CalendarRaw, undefined, f1RaceWinners)
      }
      workerF1Winners.gotData = true
    }
    Qt.callLater(root.checkF1Done)
  }

  function resolveF1Calendar(raw) {
    var payload = String(raw || "")
    // Valid JSON is success even if the table holds no rounds yet — same
    // off-season contract as the ESPN resolvers above
    var json = null
    try { json = JSON.parse(payload) } catch (e) { json = null }
    if (Model.isF1CalendarPayload(json)) {
      f1CalendarRaw = payload
      var matches = Model.parseF1Calendar(payload, undefined, f1RaceWinners)
      allMatches = matches
      lastUpdated = new Date()
      workerF1Calendar.gotData = true
    }
    Qt.callLater(root.checkF1Done)
  }

  function resolveF1Drivers(raw) {
    var drivers = Model.parseF1DriverStandings(String(raw || ""))
    if (drivers && drivers.length > 0) {
      var cur = {}
      for (var k in multiSportStandings) cur[k] = multiSportStandings[k]
      cur["Drivers"] = drivers
      multiSportStandings = cur
      workerF1Drivers.gotData = true
    }
    Qt.callLater(root.checkF1Done)
  }

  function resolveF1Constructors(raw) {
    var con = Model.parseF1ConstructorStandings(String(raw || ""))
    if (con && con.length > 0) {
      var cur2 = {}
      for (var k2 in multiSportStandings) cur2[k2] = multiSportStandings[k2]
      cur2["Constructors"] = con
      multiSportStandings = cur2
      workerF1Constructors.gotData = true
    }
    Qt.callLater(root.checkF1Done)
  }

  function checkF1Done() {
    if (workerF1Calendar.running || workerF1Drivers.running || workerF1Constructors.running || workerF1Winners.running) return
    // The calendar is the critical payload; standings tables degrade gracefully
    var calOk = workerF1Calendar.gotData
    if (!calOk && f1RetryCount < Model.MAX_ROUND_RETRIES) {
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
    if (!calOk) {
      errorMessage = "Unable to load F1 race calendar. Check connection."
    } else if (!workerF1Drivers.gotData && !workerF1Constructors.gotData) {
      errorMessage = "F1 standings could not be loaded."
    }
  }

  // One-time directory listing so downloadMissingLogos can skip crests that
  // are already on disk — without this every round re-downloaded up to 64
  // unchanged PNGs, which is how scrapers get IP-banned
  function scanLogoCache() {
    logoScanProc.command = ["ls", "-1", logoCacheDir()]
    logoScanProc.running = true
  }

  // Crests outlive seasons; teams stop being relevant long before their PNG
  // does. Evict anything untouched for 90 days at startup.
  function evictStaleLogos() {
    logoEvictProc.command = ["find", logoCacheDir(), "-name", "*.png", "-mtime", "+90", "-delete"]
    logoEvictProc.running = true
  }

  Process {
    id: logoEvictProc
    onExited: function(exitCode) {
      // `find` returns non-zero when the cache directory is missing (fresh
      // install). Skip the warning in that one case but still log other
      // failures so a permission issue surfaces in the quickshell logs.
      if (exitCode !== 0 && exitCode !== 1) {
        console.warn("omasports: logo eviction exited with code", exitCode)
      }
      root.scanLogoCache()
    }
  }

  Process {
    id: logoScanProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var map = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var name = lines[i].trim()
          if (name.length > 4 && name.indexOf(".png") === name.length - 4) {
            map[name.slice(0, -4)] = true
          }
        }
        root.knownLogoKeys = map
        root.logoScanDone = true
        // The first data round usually finishes before this listing does;
        // replay the download pass now that the skip-set is authoritative
        Qt.callLater(root.downloadMissingLogos)
      }
    }
  }

  function downloadMissingLogos() {
    if (!root.logoScanDone || logoCacheProc.running) return
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
        if (k1 !== "" && !seen[k1] && Model.isTrustedCrestUrl(u1, sp)) {
          seen[k1] = true
          items.push({ url: u1, key: k1 })
        }
      }
      if (m.away && m.away.id) {
        var u2 = m.away.logo || (sp === "football" ? ("https://images.fotmob.com/image_resources/logo/teamlogo/" + m.away.id + ".png") : "")
        var k2 = Model.crestCacheKey(sp, m.away.id, m.away.abbr || "")
        if (k2 !== "" && !seen[k2] && Model.isTrustedCrestUrl(u2, sp)) {
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
        if (k3 !== "" && !seen[k3] && Model.isTrustedCrestUrl(u3, sp2)) {
          seen[k3] = true
          items.push({ url: u3, key: k3 })
        }
      }
    }

    if (items.length === 0) return

    // --fail keeps HTTP error bodies (404/rate-limit HTML) out of the cache —
    // without it a poisoned ".png" gets marked known and never retried
    var cmd = ["curl", "-sL", "--fail", "--parallel", "--parallel-max", "8", "--create-dirs", "--max-time", "30"]
    var count = 0
    var pending = []
    var cacheDir = logoCacheDir()
    for (var c = 0; c < items.length && count < 64; c++) {
      var it = items[c]
      // Skip crests already cached on disk (or fetched earlier this session)
      if (!it.url) continue
      if (root.knownLogoKeys[it.key]) continue
      cmd.push("-o", cacheDir + it.key + ".png", it.url)
      pending.push(it.key)
      count++
    }
    if (count > 0) {
      root.pendingLogoKeys = pending
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
      if (wanted.indexOf(lid) === -1) wanted.push(lid)
    }
    var source = teamMatchesRaw && teamMatchesRaw.length > 0 ? teamMatchesRaw : teamMatches
    for (var j = 0; j < source.length && wanted.length < 8; j++) {
      var tid = String(source[j].id)
      if (wanted.indexOf(tid) === -1 && (!matchDetails[tid] || (source[j] && source[j].status === "live"))) wanted.push(tid)
    }
    detailQueue = wanted.slice(0, 8)
    Qt.callLater(nextDetail)
  }

  function nextDetail() {
    if (!root.opened && !root.backgroundUpdates && !root.enableNotifications) return
    var procs = [detailProcA, detailProcB, detailProcC]
    for (var p = 0; p < procs.length; p++) {
      var proc = procs[p]
      if (proc.running || detailQueue.length === 0) continue

      var id = String(detailQueue[0])
      var match = null
      for (var m = 0; m < allMatches.length; m++) {
        if (String(allMatches[m].id) === id) {
          match = allMatches[m]
          break
        }
      }
      var url = Model.matchDetailUrl(match)
      if (url === "") {
        detailQueue.shift()
        continue
      }

      detailQueue.shift()
      proc.detailId = id
      proc.serial = requestSerial
      proc.handled = false
      var bustUrl = url + (url.indexOf("?") === -1 ? "?" : "&") + "_=" + Date.now()
      proc.command = [
        "curl", "-LfsS", "--compressed", "--max-time", "8",
        "-H", "Cache-Control: no-cache",
        "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
        bustUrl
      ]
      proc.running = true
    }
  }

  function consumeDetail(proc, raw) {
    // A result from an older round is worthless — drop it and stop the queue
    if (proc.serial !== root.requestSerial) {
      detailQueue = []
      return
    }
    var id = String(proc.detailId || "")
    if (id !== "" && String(raw || "").trim()) {
      try {
        var parsed = Model.parseDetails(raw)
        if (parsed) {
          var next = {}
          for (var key in matchDetails) next[key] = matchDetails[key]
          next[id] = parsed
          matchDetails = next

          var props = Model.extractPageProps(raw)
          if (props && props.content) {
            var evs = Model.parseFotmobEvents(props.content)
            if (evs && (evs.goals.length > 0 || evs.redCards.length > 0)) {
              var nextEvs = {}
              for (var k1 in matchEvents) nextEvs[k1] = matchEvents[k1]
              nextEvs[id] = evs
              matchEvents = nextEvs
            }
            if (props.content.overview && props.content.overview.teams) {
              var form = Model.parseFotmobForm(props.content.overview.teams)
              if (form && (form.home.length > 0 || form.away.length > 0)) {
                var nextForm = {}
                for (var k2 in matchForm) nextForm[k2] = matchForm[k2]
                nextForm[id] = form
                matchForm = nextForm
              }
            }
            if (props.content.stats) {
              var stats = Model.parseFotmobStats(props.content.stats)
              if (stats) {
                var nextStats = {}
                for (var k3 in matchStats) nextStats[k3] = matchStats[k3]
                nextStats[id] = stats
                matchStats = nextStats
              }
            }
          }

          // A Full-Time detail must close out the live card in both the global
          // fixture list and the followed-team schedule. Mutate the arrays in
          // place, then re-assign ONCE — a per-row in-place edit followed by
          // an immediate re-broadcast would tear the fixtures Repeater down
          // for every detail that lands during a busy Saturday afternoon.
          var isFT = parsed.finished === true || parsed.reason === "FT" || parsed.reason === "AET" || parsed.reason === "PEN" || (parsed.statusLong && /full|extra|penalt|finish|ended/i.test(parsed.statusLong))
          var allNext = Model.arrayFrom(allMatches)
          var allTouched = false
          for (var m = 0; m < allNext.length; m++) {
            if (String(allNext[m].id) === id) {
              var mObj = Object.assign({}, allNext[m])
              if (isFT && mObj.status === "live") {
                mObj.status = "finished"
                mObj.statusReason = parsed.reason || "FT"
                mObj.liveTime = ""
                allTouched = true
              }
              if (parsed.liveTime && mObj.status === "live") {
                mObj.liveTime = parsed.liveTime
                allTouched = true
              }
              if (parsed.liveScore && mObj.status === "live") {
                mObj.scoreText = parsed.liveScore
                allTouched = true
              }
              allNext[m] = mObj
            }
          }
          var teamNext = Model.arrayFrom(teamMatchesRaw)
          var teamTouched = false
          for (var t = 0; t < teamNext.length; t++) {
            if (String(teamNext[t].id) === id) {
              var tObj = Object.assign({}, teamNext[t])
              if (isFT && tObj.status === "live") {
                tObj.status = "finished"
                tObj.statusReason = parsed.reason || "FT"
                tObj.liveTime = ""
                teamTouched = true
              }
              if (parsed.liveTime && tObj.status === "live") {
                tObj.liveTime = parsed.liveTime
                teamTouched = true
              }
              if (parsed.liveScore && tObj.status === "live") {
                tObj.scoreText = parsed.liveScore
                teamTouched = true
              }
              teamNext[t] = tObj
              break
            }
          }
          if (allTouched) {
            allMatches = allNext
            checkScoreNotifications()
          }
          if (teamTouched) teamMatchesRaw = teamNext
        }
      } catch (e) { console.warn("omasports: detail parse failed for", id, e) }
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
    return theme.mutedColor(root.fgColor, 0.6)
  }

  function matchSubline(match) {
    if (!match) return ""
    if (match.sport === "f1") {
      return (match.circuitName || "Circuit") + (match.locality ? " · " + match.locality : "") + (match.country ? ", " + match.country : "")
    }
    var parts = []
    var d = matchDetails[String(match.id)]
    if (d && d.stadium) parts.push("📍 " + d.stadium + (d.city ? ", " + d.city : ""))
    else if (match.venue) parts.push("📍 " + match.venue)
    if (d && d.referee) parts.push("Ref. " + d.referee)
    if (d && d.attendance) parts.push("👥 " + Number(d.attendance).toLocaleString())
    return parts.join("  ·  ")
  }

  function openMatch(match) {
    if (!match) return
    var url = Model.matchExternalUrl(match)
    if (!url) return
    matchOpener.command = ["xdg-open", url]
    matchOpener.running = true
  }

  // Alpha-derived muted foreground: Qt.darker() inverts text hierarchy on
  // light themes (darkening an already-dark fg makes secondary text heavier)
  // Data older than two refresh cycles should look stale at a glance
  readonly property bool dataStale: {
    if (!root.hasData || root.loading) return false
    return (root.nowMs - root.lastUpdated.getTime()) > 2 * root.slowRefreshMs
  }

  function relativeAge() {
    var mins = Math.floor(Math.max(0, root.nowMs - root.lastUpdated.getTime()) / 60000)
    if (mins < 1) return "just now"
    if (mins < 60) return mins + " min ago"
    var h = Math.floor(mins / 60)
    return h + "h" + (mins % 60 > 0 ? (mins % 60) + "m" : "") + " ago"
  }

  function statusLine() {
    if (loading && !hasData) return "󰥔 Loading " + activeSportMeta.label + "…"
    if (loading) return "󰥔 Updating scores…"
    if (persistenceError !== "") return persistenceError
    if (errorMessage !== "") return errorMessage
    if (!hasData) {
      return fetchedOnce
        ? "No matches in the next days."
        : "Select options above to track " + activeSportMeta.label + "."
    }
    var age = relativeAge()
    // The "~40s auto-update" hint already lives right below — don't repeat it
    if (fastPolling) return "● LIVE · updated " + age
    if (loadedFromCache) return "Cached · updated " + age
    return "Updated " + age
  }

  readonly property string statusText: {
    var _ = root.nowMs
    return root.statusLine()
  }

  Component.onCompleted: {
    evictStaleLogos()
    notificationProbe.running = true
    stateFile.reload()
  }

  // Symmetric cleanup on teardown so a panel destroyed mid-session (plugin
  // disable, shell reload) does not leak curl workers, retries, or pending
  // notify-send commands queued from a sport the user no longer follows.
  // Without this, in-flight workers keep writing to the on-disk crest cache
  // and dispatching desktop notifications after the panel is gone.
  Component.onDestruction: {
    stopNetworkWorkers()
    refreshTimer.stop()
    clockTicker.stop()
    notificationQueue = []
  }

  FileView {
    id: stateFile
    path: root.stateFilePath()
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var str = ""
      try { str = typeof text === "function" ? text() : String(text || "") }
      catch (e) {
        // A read failure (permission, ENOENT for first run is normal — that
        // path goes through onLoadFailed instead) must surface to the user
        // instead of silently losing saved favorites.
        console.warn("omasports: state file read failed", e)
        root.persistenceError = "Could not read OmaSports settings — defaults applied."
        str = ""
      }
      root.applyState(str)
    }
    onLoadFailed: function(error) {
      // 2 is a missing file (first run / reset). Anything else is a real I/O problem.
      if (error !== 2) console.warn("omasports: state file load failed", error)
      root.applyState("")
    }
    onSaveFailed: function(error) {
      root.ignoredStateSignature = ""
      root.persistenceError = "Could not save OmaSports settings."
      console.warn("omasports: state save failed", error)
    }
    onSaved: root.persistenceError = ""
    onFileChanged: reload()
  }

  Process { id: matchOpener }
  Process {
    id: stateBackupProc
    onExited: function(code) {
      // `cp` failing silently would erase the user's corrupt backup before
      // the next persist overwrites the original. Surface non-zero exits so
      // a permission / ENOSPC issue is visible in the quickshell log.
      if (code !== 0) console.warn("omasports: state backup failed", code)
    }
  }
  Process {
    id: logoCacheProc
    // Only a fully successful batch marks keys as known. A partial parallel
    // failure triggers a rescan so files that did finish are retained.
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.pendingLogoKeys = []
        root.scanLogoCache()
        return
      }
      if (root.pendingLogoKeys.length === 0) return
      var map = {}
      for (var k in root.knownLogoKeys) map[k] = root.knownLogoKeys[k]
      for (var i = 0; i < root.pendingLogoKeys.length; i++) map[root.pendingLogoKeys[i]] = true
      root.knownLogoKeys = map
      root.pendingLogoKeys = []
    }
  }
  Timer {
    id: notificationPacingTimer
    interval: 500
    repeat: false
    onTriggered: root.dispatchNextNotification()
  }
  Process {
    id: notifierProc
    onExited: notificationPacingTimer.restart()
  }
  Process {
    id: notificationProbe
    command: ["notify-send", "--version"]
    onExited: function(exitCode) {
      root.notificationToolAvailable = exitCode === 0
      if (exitCode !== 0) root.notificationWarningShown = false
    }
  }

  // ---- Multi-sport Workers -------------------------------------------------
  NetworkProcess {
    id: workerScoreboard
    property bool gotData: false
    property string sportCode: ""
    property string defaultName: ""

    onOutput: function(payload) { root.resolveEspnScoreboard(payload, workerScoreboard.sportCode, workerScoreboard.defaultName) }
    onFailed: root.resolveEspnScoreboard("", workerScoreboard.sportCode, workerScoreboard.defaultName)
  }

  NetworkProcess {
    id: workerStandings
    property bool gotData: false
    property string sportCode: ""

    onOutput: function(payload) { root.resolveEspnStandings(payload, workerStandings.sportCode) }
    onFailed: root.resolveEspnStandings("", workerStandings.sportCode)
  }

  NetworkProcess {
    id: workerF1Calendar
    property bool gotData: false

    onOutput: function(payload) { root.resolveF1Calendar(payload) }
    onFailed: root.resolveF1Calendar("")
  }

  NetworkProcess {
    id: workerF1Drivers
    property bool gotData: false

    onOutput: function(payload) { root.resolveF1Drivers(payload) }
    onFailed: root.resolveF1Drivers("")
  }

  NetworkProcess {
    id: workerF1Constructors
    property bool gotData: false

    onOutput: function(payload) { root.resolveF1Constructors(payload) }
    onFailed: root.resolveF1Constructors("")
  }

  NetworkProcess {
    id: workerF1Winners
    property bool gotData: false

    onOutput: function(payload) { root.resolveF1Winners(payload) }
    onFailed: root.resolveF1Winners("")
  }

  NetworkProcess {
    id: workerF1Podium
    property bool gotData: false

    onOutput: function(payload) { root.resolveF1Podium(payload) }
    onFailed: root.resolveF1Podium("")
  }

  NetworkProcess {
    id: workerF1Pole
    property bool gotData: false

    onOutput: function(payload) { root.resolveF1Pole(payload) }
    onFailed: root.resolveF1Pole("")
  }

  NetworkProcess {
    id: workerNews
    property bool gotData: false

    onOutput: function(payload) { root.resolveNews(payload) }
    onFailed: root.resolveNews("")
  }

  // Football Workers
  NetworkProcess {
    id: workerTeam
    property string teamId: ""

    onOutput: function(payload) { root.resolveTeamWorker(payload) }
    onFailed: root.resolveTeamWorker("")
  }

  NetworkProcess {
    id: workerA
    property string leagueId: ""
    onOutput: function(payload) { root.resolveFootballWorker(workerA, payload) }
    onFailed: root.resolveFootballWorker(workerA, "")
  }

  NetworkProcess {
    id: workerB
    property string leagueId: ""
    onOutput: function(payload) { root.resolveFootballWorker(workerB, payload) }
    onFailed: root.resolveFootballWorker(workerB, "")
  }

  NetworkProcess {
    id: workerC
    property string leagueId: ""
    onOutput: function(payload) { root.resolveFootballWorker(workerC, payload) }
    onFailed: root.resolveFootballWorker(workerC, "")
  }

  NetworkProcess {
    id: workerD
    property string leagueId: ""
    onOutput: function(payload) { root.resolveFootballWorker(workerD, payload) }
    onFailed: root.resolveFootballWorker(workerD, "")
  }

  RetryTimer {
    id: retryDelay
    interval: Model.RETRY_DELAY_MS
    predicate: function() {
      return root.loading && pendingRetryIds.length > 0
    }
    callback: function() {
      roundQueue = roundQueue.concat(pendingRetryIds)
      pendingRetryIds = []
      root.pumpFootball()
    }
  }

  RetryTimer {
    id: teamRetryDelay
    interval: Model.RETRY_DELAY_MS
    predicate: function() {
      return root.teamFetchActive
        && root.teamRetrySerial === root.requestSerial
        && root.teamRetryId !== ""
    }
    callback: function() {
      root.teamRetryId = ""
      root.fetchNextFootballTeamPage()
    }
  }

  // Retry dead rounds for ESPN sports (same contract as the football retry)
  RetryTimer {
    id: espnRetryDelay
    interval: Model.RETRY_DELAY_MS
    predicate: function() {
      return root.loading
        && root.activeSport === root.espnSportCode
        && root.requestSerial === root.espnRetrySerial
    }
    callback: function() {
      root.startEspnRound(root.espnSportPath, root.espnSportCode, root.espnDefaultName)
    }
  }

  RetryTimer {
    id: f1RetryDelay
    interval: Model.RETRY_DELAY_MS
    predicate: function() {
      return root.loading
        && root.activeSport === "f1"
        && root.requestSerial === root.f1RetrySerial
    }
    callback: function() {
      root.startF1Round()
    }
  }

  // Detail enrichment runs on three parallel workers draining one shared queue
  // (~2 min worst-case serial chain before → ~40s now)
  NetworkProcess {
    id: detailProcA
    property string detailId: ""
    onOutput: function(payload) { root.consumeDetail(detailProcA, payload) }
    onFailed: root.consumeDetail(detailProcA, "")
  }

  NetworkProcess {
    id: detailProcB
    property string detailId: ""
    onOutput: function(payload) { root.consumeDetail(detailProcB, payload) }
    onFailed: root.consumeDetail(detailProcB, "")
  }

  NetworkProcess {
    id: detailProcC
    property string detailId: ""
    onOutput: function(payload) { root.consumeDetail(detailProcC, payload) }
    onFailed: root.consumeDetail(detailProcC, "")
  }

  // Adaptive polling: while a followed match is live we poll every 40s so the
  // clock and score track reality; otherwise we fall back to the user interval.
  // Clamp to [5,60] like every other writer: a malformed state file (or a v1
  // save with refreshMinutes outside the dropdown range) must not produce a
  // multi-hour poll interval with no UI affordance to reset it.
  readonly property int slowRefreshMs: Model.clampRefreshMinutes(root.savedState.refreshMinutes) * 60 * 1000
  property bool fastPolling: false

  function hasLiveFollowedMatch() {
    // Same contract as favoriteTeamLive: only followed-team games justify
    // the ~40s adaptive polling cadence
    for (var i = 0; i < teamMatches.length; i++)
      if (teamMatches[i] && teamMatches[i].status === "live") return true
    return false
  }

  function shouldFastPoll() {
    // Followed team is playing live
    if (hasLiveFollowedMatch()) return true
    // Panel is open or background monitoring active with live events
    if ((root.opened || root.backgroundUpdates || root.enableNotifications) && root.liveCount > 0) return true
    return false
  }

  function livePollIntervalMs() {
    if (activeSport === "nba" || activeSport === "nfl" || activeSport === "mlb" || activeSport === "nhl") {
      return 15000 // 15s for ESPN direct JSON API
    }
    return 20000   // 20s for FotMob & F1 (safe edge cache limit)
  }

  function scheduleNextPoll() {
    var wantRunning = root.opened
      || root.backgroundUpdates
      || root.enableNotifications
      || root.hasLiveFollowedMatch()
      || root.liveCount > 0
    fastPolling = wantRunning && (root.hasLiveFollowedMatch() || shouldFastPoll())
    if (!wantRunning) {
      refreshTimer.stop()
      return
    }
    var ms
    if (fastPolling) {
      ms = livePollIntervalMs()
    } else if (root.opened) {
      ms = Math.min(root.slowRefreshMs, 60000)
    } else {
      ms = root.slowRefreshMs
    }
    root.setRefreshTimerInterval(ms)
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

  // Mutating `interval` on a running Timer can fire once at the old cadence
  // before Qt honors the new value. stop()/start() is the documented way to
  // apply a fresh interval cleanly (used by scheduleNextPoll above).
  function setRefreshTimerInterval(ms) {
    var wantRunning = root.opened
      || root.backgroundUpdates
      || root.enableNotifications
      || root.hasLiveFollowedMatch()
      || root.liveCount > 0
    var intervalChanged = refreshTimer.interval !== ms
    if (intervalChanged) {
      refreshTimer.stop()
      refreshTimer.interval = ms
    }
    if (wantRunning && (!refreshTimer.running || intervalChanged)) {
      refreshTimer.start()
    }
  }

  // Cap shell IPC that would otherwise spawn a curl storm (`omarchy-shell
  // miguel.omasports refresh` in a tight loop). Open/close/route stay
  // ungated — they have no network side effects.
  property var lastIpcAt: 0
  function ipcThrottle() {
    var now = Date.now()
    if (now - lastIpcAt < 250) return false
    lastIpcAt = now
    return true
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { if (root.ipcThrottle()) root.refresh() }
    function toggleSpoiler(): void { if (root.ipcThrottle()) root.toggleSpoiler() }
    function toggleBarTicker(): void { if (root.ipcThrottle()) root.toggleBarTicker() }
    function toggleSpotlight(): void { if (root.ipcThrottle()) root.toggleSpotlight() }
    function sport(name: string): void { if (root.ipcThrottle()) root.switchSport(name) }
    function setSuppressFocus(suppress: bool): void { root.suppressFocus = suppress }
    function setTargetScreen(screenName: string): void { root.targetScreenName = screenName }
    function getActiveSport(): string { return root.activeSport }
    function testNotification(): void {
      root.sendDesktopNotification("OmaSports", "Goal and kickoff notifications are active!", "", "normal")
    }
    function getScheduleSection(): string { return root.scheduleSubSection }
    function scheduleSection(sub: string): void {
      var s = String(sub || "all").toLowerCase()
      if (s === "recent" || s === "results") root.scheduleSubSection = "recent"
      else if (s === "upcoming") root.scheduleSubSection = "upcoming"
      else if (s === "news") root.scheduleSubSection = "news"
      else root.scheduleSubSection = "all"
      root.tabIndex = 0
      root.showingSettings = false
      root.routedExplicitly = true
      if (!root.opened) root.openFromHotkey()
    }
    function route(tabName: string): void {
      var t = String(tabName || "").toLowerCase()
      if (t === "settings" || t === "preferences") {
        root.showingSettings = true
      } else {
        root.showingSettings = false
        if (t === "fixtures" || t === "team") {
          root.tabIndex = 0
          root.scheduleSubSection = "all"
        } else if (t === "results" || t === "recent") {
          root.tabIndex = 0
          root.scheduleSubSection = "recent"
        } else if (t === "news") {
          root.tabIndex = 0
          root.scheduleSubSection = "news"
        } else if (t === "upcoming") {
          root.tabIndex = 0
          root.scheduleSubSection = "upcoming"
        } else if (t === "live") {
          root.tabIndex = 1
        } else if (t === "standings" || t === "table") {
          root.tabIndex = 2
        }
      }
      root.routedExplicitly = true
      if (!root.opened) root.openFromHotkey()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    screen: root.targetScreen ? root.targetScreen : (panel.anchorWindow ? panel.anchorWindow.screen : null)
    centerOnBar: root.shouldCenterOnBar || Boolean(root.targetScreenName)
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(530))
    contentHeight: panel.fittedContentHeight(Math.min(sportsColumn.implicitHeight + Style.space(16), root.maxPanelContentHeight))
    WlrLayershell.keyboardFocus: (root.opened && !root.suppressFocus)
      ? (panel.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.anyPopupOpen()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveFocus(dy)
        else root.moveWithin(dx)
      }
      onActivateRequested: root.activateFocus()
      onCloseRequested: {
        if (root.showingSettings) root.showingSettings = false
        else root.close()
      }
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

            opacity: 1.0

            PanelHeader {
              id: panelHeader
              controller: root
            }

            FixturesTab {
              id: fixturesTab
              controller: root
              visible: !root.showingSettings && root.tabIndex === 0
            }

            LiveTab {
              id: liveTab
              controller: root
              visible: !root.showingSettings && root.tabIndex === 1
            }

            StandingsTab {
              id: standingsTab
              controller: root
              visible: !root.showingSettings && root.tabIndex === 2
            }

            SettingsTab {
              id: settingsTab
              controller: root
              visible: root.showingSettings
            }
          }
        }
      }
    }
  }
}
