import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "SportsModel.js" as Model

Panel {
  id: root
  moduleName: "miguel.omasports"
  ipcTarget: "miguel.omasports"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false

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

  // Optional background polling
  readonly property bool backgroundUpdates: setting("backgroundUpdates", false) === true

  // Mock mode: OMASPORTS_MOCK=1 runs the whole panel on a deterministic built-in
  // simulation (no network) — live matches evolve, a goal is scored mid-session,
  // and a kickoff happens 12 minutes in. For development and UI testing.
  readonly property bool mockMode: Quickshell.env("OMASPORTS_MOCK") === "1"

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

  // Per-match enrichment for football
  property var matchDetails: ({})
  property var detailQueue: []

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
    // Fixtures under the current filter
    var fx
    if (activeSport === "f1") fx = allMatches
    else if (fixtureFilterId === "team" && selectedTeamIds.length > 0) fx = teamMatches
    else if (fixtureFilterId.indexOf("fav_") === 0) fx = Model.matchesForTeam(allMatches, fixtureFilterId.slice(4), activeSport)
    else if (fixtureFilterId === "all") fx = allMatches
    else fx = Model.matchesForLeague(allMatches, fixtureFilterId)
    if (!Model.sameMatches(activeFixturesList, fx)) activeFixturesList = fx

    var groups = Model.groupMatches(fx)
    if (!Model.sameGroups(matchGroups, groups)) matchGroups = groups

    var live = Model.liveMatches(allMatches, matchDetails)
    if (!Model.sameMatches(liveList, live)) liveList = live

    // Followed-team schedule (multi-competition)
    var tm
    if (activeSport === "f1") tm = selectedTeamIds.length > 0 ? allMatches : []
    else if (teamMatchesRaw && teamMatchesRaw.length > 0) tm = teamMatchesRaw
    else if (selectedTeamIds.length > 0) tm = Model.matchesForTeam(allMatches, selectedTeamIds, activeSport)
    else if (selectedTeamId !== "") tm = Model.matchesForTeam(allMatches, selectedTeamId, activeSport)
    else tm = []
    if (!Model.sameMatches(teamMatches, tm)) teamMatches = tm

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
  onTabIndexChanged: {
    focusSection = 0
    if (stateLoaded) persistState()
  }
  readonly property var tabOptions: [
    { value: "team", label: "Fixtures", icon: "★" },
    { value: "live", label: "Live", icon: "●" },
    { value: "table", label: "Standings", icon: "󰝘" }
  ]
  readonly property int liveCount: liveList.length

  // Live 1-Second Adaptive Clock (60s while the panel is closed — enough to
  // keep the bar ticker honest without waking the shell every second)
  property double nowMs: Date.now()
  Timer {
    interval: root.opened ? 1000 : 60000
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
  readonly property string selectedTeamName: selectedTeamIds.length > 0 ? root.teamNameFor(selectedTeamIds[0]) : selectedTeamLabel()
  readonly property string selectedLeagueNames: selectedLeagueNameList()

  // Bar badge + summary — driven ONLY by followed teams. An unrelated league
  // game must never claim the bar slot (or trigger fast polling); with no
  // favorites selected the bar shows just the sport icon.
  readonly property bool favoriteTeamLive: {
    for (var i = 0; i < teamMatches.length; i++)
      if (teamMatches[i] && teamMatches[i].status === "live") return true
    return false
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
    persistState()
    allMatches = []
    teamMatchesRaw = []
    multiSportStandings = {}
    lastPages = []
    matchDetails = {}
    lastSeenMatches = {}
    ensureStandingsSelection()
    forceRefresh()
  }

  function restoreSportSelections() {
    if (activeSport === "football") {
      var fb = savedState.football || {}
      selectedLeagueIds = Model.normalizeLeagueIds(fb.leagueIds)
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
    var next = {}
    for (var k in revealedMatchIds) next[k] = revealedMatchIds[k]
    next[String(matchId)] = true
    revealedMatchIds = next
  }

  // Which F1 weekend cards have their sessions timetable unfolded
  property var f1ExpandedIds: ({})

  function toggleF1Expand(matchId) {
    var key = String(matchId)
    var next = {}
    for (var k in f1ExpandedIds) next[k] = f1ExpandedIds[k]
    if (next[key]) delete next[key]
    else next[key] = true
    f1ExpandedIds = next
  }

  // ---- Navigation ---------------------------------------------------------
  // Focus sections are derived from what is actually visible: a collapsed
  // setup editor or a non-football sport must not own keyboard stops. Rows
  // (fixtures/live cards) trail the chrome sections and open with Enter.
  readonly property var focusSections: {
    // Keep tabs as the initial stop so ←/→ retains the documented tab switch;
    // vertical navigation still exposes the sport selector immediately after.
    var s = ["tabs", "sports"]
    if (root.notificationToolAvailable) s.push("notifications")
    s.push("spoiler", "refresh")
    if (root.selectedTeamIds.length > 0 || (root.activeSport === "football" && root.selectedLeagueIds.length > 0)) s.push("setup")
    if (root.activeSport === "football" && root.setupEditorVisible) s.push("leagues")
    if (root.setupEditorVisible) s.push("teams")
    if (root.setupEditorVisible && root.selectedTeamIds.length > 0) s.push("clear")
    if (root.tabIndex === 0
        && ((root.selectedTeamIds.length > 0 && root.featuredMatch !== null)
            || (root.activeSport === "f1" && root.allMatches.length > 0))) s.push("spotlight")
    s.push("interval")
    if (root.tabIndex === 2 && root.standingsOptions.length > 1) s.push("standings")
    return s
  }

  readonly property int rowSectionCount: root.tabIndex === 0
    ? flatFixtureRows.length
    : (root.tabIndex === 1 ? liveList.length : 0)

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
    return (leaguePicker && leaguePicker.popupOpen) || (teamPicker && teamPicker.popupOpen) || intervalPicker.popupOpen
      || (standingsPicker && standingsPicker.popupOpen)
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
    else if (name === "notifications" && root.notificationToolAvailable) root.toggleNotifications()
    else if (name === "spoiler") root.toggleSpoiler()
    else if (name === "refresh") root.refresh()
    else if (name === "setup") root.setupExpanded = !root.setupExpanded
    else if (name === "spotlight") root.activateSpotlight()
    else if (name === "leagues" && leaguePicker) leaguePicker.toggle()
    else if (name === "teams" && teamPicker) teamPicker.toggle()
    else if (name === "clear") root.clearSelectedTeam()
    else if (name === "interval") intervalPicker.toggle()
    else if (name === "standings" && standingsPicker) standingsPicker.toggle()
  }

  function activateSpotlight() {
    var m = root.featuredMatch || (root.activeSport === "f1" ? root.allMatches[0] : null)
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

  function stateFilePath() {
    return Quickshell.env("HOME") + "/.config/omarchy/sports-favorites.json"
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
    restoreSportSelections()
    stateLoaded = true

    if (leaguePicker) leaguePicker.values = selectedLeagueIds
    ensureStandingsSelection()
    if (!ownWrite && (root.opened || root.backgroundUpdates)) {
      espnRetryCount = 0
      f1RetryCount = 0
      root.startRound()
    } else {
      root.scheduleNextPoll()
    }
  }

  function persistState() {
    if (!stateLoaded) return
    var tabName = tabIndex === 2 ? "standings" : (tabIndex === 1 ? "live" : "fixtures")
    savedState = Model.buildPersistedState(activeSport, savedState, {
      tabName: tabName,
      selectedLeagueIds: selectedLeagueIds,
      selectedTeamIds: selectedTeamIds,
      selectedTeamId: selectedTeamId,
      selectedTeamName: selectedTeamName,
      standingsLeagueId: standingsLeagueId,
      antiSpoiler: antiSpoiler,
      enableNotifications: enableNotifications
    })
    ignoredStateSignature = JSON.stringify(savedState)
    persistenceError = ""
    stateFile.setText(JSON.stringify(savedState, null, 2) + "\n")
  }

  function toggleNotifications() {
    if (!notificationToolAvailable) return
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
    next.push({ title: String(title || ""), body: String(body || ""), iconPath: String(iconPath || ""), urgency: String(urgency || "") })
    notificationQueue = next
    dispatchNextNotification()
  }

  function dispatchNextNotification() {
    if (notifierProc.running || notificationQueue.length === 0 || !notificationToolAvailable) return
    var next = Model.arrayFrom(notificationQueue)
    var item = next.shift()
    notificationQueue = next
    var cmd = ["notify-send", "-a", "OmaSports"]
    if (item.iconPath && item.iconPath.trim()) {
      var p = item.iconPath
      if (p.indexOf("file://") === 0) p = p.slice(7)
      cmd.push("-i", p)
    }
    if (item.urgency) cmd.push("-u", item.urgency)
    // "--" ends option parsing: provider-derived strings must never be
    // mistaken for flags even when they start with a dash.
    cmd.push("--", item.title, item.body)
    notifierProc.command = cmd
    notifierProc.running = true
  }

  function logoCacheDir() {
    return Quickshell.env("HOME") + "/.cache/omarchy-omasports/logos/"
  }

  function crestIconPath(sport, team) {
    var key = Model.crestCacheKey(sport, team && team.id ? team.id : "", team && team.abbr ? team.abbr : "")
    return key !== "" ? logoCacheDir() + key + ".png" : ""
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
    if (leaguePicker) leaguePicker.values = next
    ensureStandingsSelection()
    persistState()
    if (root.opened || root.backgroundUpdates) root.forceRefresh()
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
    selectedTeamId = arr.length > 0 ? arr[0] : ""
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
      selectedTeamId = arr.length > 0 ? arr[0] : ""
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
    selectedTeamId = ""
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
    var minutes = Math.max(5, Math.min(60, parseInt(value, 10) || 15))
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
                 workerF1Constructors, workerTeam,
                 detailProcA, detailProcB, detailProcC,
                 workerA, workerB, workerC, workerD,
                 logoScanProc, logoEvictProc, logoCacheProc,
                 notificationProbe, notifierProc,
                 stateBackupProc, matchOpener]
    for (var i = 0; i < procs.length; i++) {
      var w = procs[i]
      w.handled = true
      if (w.running) w.running = false
    }
  }

  // ---- Mock Round (OMASPORTS_MOCK=1) -----------------------------------------
  function finishMockRound() {
    var mock = Model.mockRound(activeSport, Date.now())
    allMatches = mock.matches
    if (mock.standings && Object.keys(mock.standings).length > 0) multiSportStandings = mock.standings
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
    beginTeamPageFetch(selectedTeamIds.length > 0 ? selectedTeamIds : [selectedTeamId], false)
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
      "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
      "https://www.fotmob.com/teams/" + encodeURIComponent(id)
    ]
    workerTeam.running = true
  }

  function retryOrAdvanceTeamPage(id) {
    var tries = teamRetryCounts[id] || 0
    if (tries < 2) {
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
      "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
      "https://www.fotmob.com/leagues/" + encodeURIComponent(w.leagueId)
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
      if (tries < 2) {
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
      if (teamMatchesRaw.length > 0) mergedMatches = Model.mergeMatchUpdates(mergedMatches, teamMatchesRaw)
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
    workerScoreboard.command = ["curl", "-LfsS", "--max-time", "10", "https://site.api.espn.com/apis/site/v2/sports/" + espnPath + "/scoreboard?" + dates]
    workerScoreboard.running = true

    workerStandings.handled = false
    workerStandings.gotData = false
    workerStandings.serial = root.requestSerial
    workerStandings.sportCode = sportCode
    workerStandings.command = ["curl", "-LfsS", "--max-time", "10", "https://site.api.espn.com/apis/v2/sports/" + espnPath + "/standings"]
    workerStandings.running = true
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
    if ((!sbOk || !stOk) && espnRetryCount < 2) {
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

    // Jolpica documents strict rate limits — each standings table is fetched
    // once per session (they only change at race cadence) instead of on every
    // poll alongside the calendar
    f1EnsureStandings("Drivers")
    f1EnsureStandings("Constructors")
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

  function resolveF1Calendar(raw) {
    var payload = String(raw || "")
    // Valid JSON is success even if the table holds no rounds yet — same
    // off-season contract as the ESPN resolvers above
    var json = null
    try { json = JSON.parse(payload) } catch (e) { json = null }
    if (Model.isF1CalendarPayload(json)) {
      var matches = Model.parseF1Calendar(payload)
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
    if (workerF1Calendar.running || workerF1Drivers.running || workerF1Constructors.running) return
    // The calendar is the critical payload; standings tables degrade gracefully
    var calOk = workerF1Calendar.gotData
    if (!calOk && f1RetryCount < 2) {
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
      if (!matchDetails[lid]) wanted.push(lid)
    }
    var source = teamMatchesRaw && teamMatchesRaw.length > 0 ? teamMatchesRaw : teamMatches
    for (var j = 0; j < source.length && wanted.length < 16; j++) {
      var tid = String(source[j].id)
      if (!matchDetails[tid] && wanted.indexOf(tid) === -1) wanted.push(tid)
    }
    detailQueue = wanted
    Qt.callLater(nextDetail)
  }

  function nextDetail() {
    if (!root.opened && !root.backgroundUpdates) return
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
      proc.command = [
        "curl", "-LfsS", "--compressed", "--max-time", "8",
        "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
        url
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

          // A Full-Time detail must close out the live card in both the global
          // fixture list and the followed-team schedule. Mutate the arrays in
          // place, then re-assign ONCE — a per-row in-place edit followed by
          // an immediate re-broadcast would tear the fixtures Repeater down
          // for every detail that lands during a busy Saturday afternoon.
          if (parsed.statusLong === "Full-Time" || parsed.reason === "FT" || parsed.finished) {
            var allNext = Model.arrayFrom(allMatches)
            var allTouched = false
            for (var m = 0; m < allNext.length; m++) {
              if (String(allNext[m].id) === id && allNext[m].status === "live") {
                allNext[m] = Object.assign({}, allNext[m], { status: "finished" })
                allTouched = true
              }
            }
            var teamNext = Model.arrayFrom(teamMatchesRaw)
            var teamTouched = false
            for (var t = 0; t < teamNext.length; t++) {
              if (String(teamNext[t].id) === id && teamNext[t].status === "live") {
                teamNext[t] = Object.assign({}, teamNext[t], { status: "finished" })
                teamTouched = true
                break
              }
            }
            if (allTouched) allMatches = allNext
            if (teamTouched) teamMatchesRaw = teamNext
          }
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
    return root.mutedColor(root.fgColor, 0.45)
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
  function mutedColor(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }

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

  Component.onCompleted: {
    evictStaleLogos()
    notificationProbe.running = true
    stateFile.reload()
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
      console.warn("omasports: state file load failed", error)
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
  Process { id: stateBackupProc }
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
  Process {
    id: notifierProc
    onExited: root.dispatchNextNotification()
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

  Timer {
    id: teamRetryDelay
    interval: 2500
    onTriggered: {
      if (!root.teamFetchActive || root.teamRetrySerial !== root.requestSerial || root.teamRetryId === "") return
      root.teamRetryId = ""
      root.fetchNextFootballTeamPage()
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
  readonly property int slowRefreshMs: Math.max(5, Math.min(60, parseInt(root.savedState.refreshMinutes || 15, 10))) * 60 * 1000
  property bool fastPolling: false

  function hasLiveFollowedMatch() {
    // Same contract as favoriteTeamLive: only followed-team games justify
    // the ~40s adaptive polling cadence
    for (var i = 0; i < teamMatches.length; i++)
      if (teamMatches[i] && teamMatches[i].status === "live") return true
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
    if (refreshTimer.interval === ms) return
    refreshTimer.stop()
    refreshTimer.interval = ms
    if (root.opened || root.backgroundUpdates) refreshTimer.start()
  }

  onBackgroundUpdatesChanged: {
    scheduleNextPoll()
    if (root.backgroundUpdates && root.stateLoaded && !root.loading) root.refresh()
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
    contentHeight: panel.fittedContentHeight(Math.min(sportsColumn.implicitHeight + Style.space(16), root.maxPanelContentHeight))

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
                    color: root.errorMessage !== "" || root.persistenceError !== "" || root.dataStale
                      ? root.urgentColor
                      : root.mutedColor(root.fgColor, 0.55)
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
                  focusable: root.notificationToolAvailable
                  enabled: root.notificationToolAvailable
                  hasCursor: root.focusSection === root.sectionIndex("notifications") && root.notificationToolAvailable
                  tooltipText: root.notificationToolAvailable
                    ? (root.enableNotifications ? "Disable score notifications" : "Enable score notifications")
                    : "Notifications unavailable (notify-send not found)"
                  Accessible.role: Accessible.Button
                  Accessible.name: notifyBtn.tooltipText
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
                  focusable: true
                  hasCursor: root.focusSection === root.sectionIndex("spoiler")
                  tooltipText: root.antiSpoiler ? "Show final scores" : "Hide final scores"
                  Accessible.role: Accessible.Button
                  Accessible.name: spoilerBtn.tooltipText
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
                  hasCursor: root.focusSection === root.sectionIndex("refresh")
                  tooltipText: root.loading ? "Updating scores" : "Refresh scores"
                  Accessible.role: Accessible.Button
                  Accessible.name: refreshButton.tooltipText
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
                    hasCursor: root.focusSection === root.sectionIndex("interval")
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

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label + (root.activeSport === modelData.value ? " (selected)" : "")
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
                        color: root.activeSport === modelData.value ? Color.accent : root.mutedColor(root.fgColor, 0.75)
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
                    hasCursor: root.focusSection === root.sectionIndex("tabs") && root.tabIndex === index && !root.anyPopupOpen()
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
                      running: root.opened && root.liveCount > 0 && root.tabIndex !== 1
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
                      text: (root.activeSport === "f1"
                        ? "FAVORITE DRIVER & PREFERENCES"
                        : ("FOLLOWED " + root.activeSportMeta.label.toUpperCase() + (root.activeSport === "football" ? " & CLUBS" : " TEAMS")))
                      foreground: root.fgColor
                    }

                    Button {
                      id: setupToggleBtn
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.setupExpanded ? "Done" : "Edit"
                      iconText: root.setupExpanded ? "󰅃" : "󰅀"
                      visible: root.selectedTeamIds.length > 0 || (root.activeSport === "football" && root.selectedLeagueIds.length > 0)
                      focusable: true
                      hasCursor: root.focusSection === root.sectionIndex("setup")
                      tooltipText: root.setupExpanded ? "Finish editing favorites" : "Edit favorites and leagues"
                      Accessible.role: Accessible.Button
                      Accessible.name: setupToggleBtn.tooltipText
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
                          color: root.mutedColor(root.fgColor, 0.45)
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
                    visible: root.setupEditorVisible

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
                        hasCursor: root.focusSection === root.sectionIndex("leagues")
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
                              id: leagueChipX
                              text: "✕"
                              color: chipMouse.containsMouse ? root.urgentColor : root.mutedColor(root.fgColor, 0.45)
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                              font.bold: true

                              // Only the glyph deletes — an accidental tap on
                              // the label must not unfollow a league
                              MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
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

                          MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
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
                          hasCursor: root.focusSection === root.sectionIndex("teams")
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
                        hasCursor: root.focusSection === root.sectionIndex("clear")
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
                              color: favChipMouse.containsMouse ? root.urgentColor : root.mutedColor(root.fgColor, 0.45)
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                              font.bold: true

                              MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeSelectedTeam(modelData)
                              }
                            }
                          }

                          MouseArea {
                            id: favChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
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
                selectedTeamIds: root.selectedTeamIds
                selectedTeamName: root.selectedTeamName
                antiSpoiler: root.antiSpoiler
                revealedMatchIds: root.revealedMatchIds
                favoriteDriverStanding: root.favoriteDriverStanding
                kickoffTime: root.kickoffTime
                matchSubline: root.matchSubline
                openMatch: root.openMatch
                revealMatch: root.revealMatch
                rowFocused: root.focusSection === root.sectionIndex("spotlight")
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
                  color: root.mutedColor(root.fgColor, 0.55)
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
                visible: root.activeFixturesList.length === 0 && !root.loading
                  && (root.hasData || root.fetchedOnce) && root.errorMessage === ""
                text: "No matches in the next days for this selection. Use the refresh button above or press R."
                color: root.mutedColor(root.fgColor, 0.65)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }

              // Inline error card: the only recovery affordance used to be
              // discovering the tiny refresh icon in the header
              Rectangle {
                width: parent.width
                implicitHeight: errorCol.implicitHeight + Style.space(16)
                visible: root.errorMessage !== "" && !root.loading
                radius: Math.min(6, Style.cornerRadius)
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
                    text: root.errorMessage
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
                      onClicked: root.forceRefresh()
                    }
                  }
                }
              }

              // First-load skeletons: an empty column on a slow network reads
              // as broken — placeholder cards say "working" instead
              Column {
                width: parent.width
                spacing: Style.space(8)
                visible: root.loading && !root.hasData

                Repeater {
                  model: 4
                  delegate: Rectangle {
                    width: parent.width
                    implicitHeight: Style.space(40)
                    radius: Math.min(6, Style.cornerRadius)
                    color: Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.05)

                    SequentialAnimation on opacity {
                      running: root.loading && !root.hasData
                      loops: Animation.Infinite
                      NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                      NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    }
                  }
                }
              }

              Column {
                width: parent.width
                spacing: Style.space(12)

                Repeater {
                  model: root.matchGroups

                  delegate: Column {
                    id: groupDelegate
                    required property var modelData
                    required property int index
                    // Offset of this group's first row in flatFixtureRows, so
                    // keyboard focus indices map onto the visible cards
                    readonly property int rowOffset: {
                      var s = 0
                      for (var g = 0; g < index; g++) {
                        s += (root.matchGroups[g].matches || []).length
                      }
                      return s
                    }
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
                        color: modelData.label === "Live Matches" ? root.urgentColor : root.mutedColor(root.fgColor, 0.55)
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
                          selectedTeamIds: root.selectedTeamIds
                          antiSpoiler: root.antiSpoiler
                          revealedMatchIds: root.revealedMatchIds
                          nowMs: root.nowMs
                          revealMatch: root.revealMatch
                          openMatch: root.openMatch
                          expandedIds: root.f1ExpandedIds
                          toggleExpand: root.toggleF1Expand
                          listVisible: root.opened && root.tabIndex === 0
                          rowFocused: root.focusSection - root.focusSections.length === groupDelegate.rowOffset + index
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
                    text: (root.hasData || root.fetchedOnce)
                      ? "No live events in progress right now for " + root.activeSportMeta.label + "."
                      : "Load " + root.activeSportMeta.label + " schedule to see live scores."
                    color: root.mutedColor(root.fgColor, 0.65)
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
                  model: root.liveList
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
                    listVisible: root.opened && root.tabIndex === 1
                    rowFocused: root.focusSection - root.focusSections.length === index
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
                  color: root.mutedColor(root.fgColor, 0.55)
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
                    hasCursor: root.focusSection === root.sectionIndex("standings")
                    foreground: root.fgColor
                    background: Color.popups.background
                    onChanged: function(value) { root.setStandingsLeague(value) }
                  }
                }
              }

              Text {
                width: parent.width
                visible: root.standingsRows.length === 0 && !root.loading
                text: root.hasData
                  ? "No standings available for this selection."
                  : "No standings yet — use the refresh button above or press R."
                color: root.mutedColor(root.fgColor, 0.65)
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
                        selectedTeamIds: root.selectedTeamIds
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
                    color: root.mutedColor(root.fgColor, 0.55)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Row {
                  visible: root.standingsHasPlayin
                  spacing: Style.space(5)
                  Rectangle {
                    width: Style.space(8)
                    height: Style.space(8)
                    radius: 2
                    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08)
                    border.width: 1
                    border.color: Util.alpha(Color.accent, 0.35)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: root.activeSport === "f1" ? "Podium places" : "Play-in"
                    color: root.mutedColor(root.fgColor, 0.55)
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
                    color: root.mutedColor(root.fgColor, 0.55)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                // Relegation/danger zones were previously encoded by red fill
                // alone — document the third zone so the encoding is readable
                Row {
                  visible: root.activeSport === "football"
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
                    color: root.mutedColor(root.fgColor, 0.55)
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
