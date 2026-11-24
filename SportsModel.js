.pragma library
.import "model/core.js" as Core
.import "model/urls.js" as Urls
.import "model/matches.js" as Matches
.import "model/mock.js" as Mock
.import "model/notifications.js" as Notifications
.import "model/providers/f1.js" as F1
.import "model/providers/espn.js" as Espn
.import "model/providers/fotmob.js" as Fotmob

// Public facade. QML imports this file as `Model`; Node tests load it
// through tests/model-loader.mjs, which expands the QML .import graph.
// Keeping every public name here preserves the original API surface.

var NOTIFICATION_TTL_MS = Core.NOTIFICATION_TTL_MS
var MAX_ROUND_RETRIES = Core.MAX_ROUND_RETRIES
var RETRY_DELAY_ESPN_MS = Core.RETRY_DELAY_ESPN_MS
var RETRY_DELAY_FOTMOB_F1_MS = Core.RETRY_DELAY_FOTMOB_F1_MS
var RETRY_DELAY_MS = Core.RETRY_DELAY_MS
var F1_RESULTS_REFRESH_MS = Core.F1_RESULTS_REFRESH_MS
var MIN_REFRESH_MINUTES = Core.MIN_REFRESH_MINUTES
var MAX_REFRESH_MINUTES = Core.MAX_REFRESH_MINUTES
var REFRESH_OPTIONS = Core.REFRESH_OPTIONS
var supportedSports = Core.supportedSports
var supportedLeagues = Core.supportedLeagues
var nbaTeams = Core.nbaTeams
var popularFootballClubs = Core.popularFootballClubs
var f1Drivers = Core.f1Drivers
var nflTeams = Core.nflTeams
var mlbTeams = Core.mlbTeams
var nhlTeams = Core.nhlTeams
var _liveClockCache = Matches._liveClockCache
var mockAnchor = Mock.mockAnchor

function safeHome() { return Core.safeHome.apply(null, arguments) }
function clampRefreshMinutes() { return Core.clampRefreshMinutes.apply(null, arguments) }
function refreshIntervalOptions() { return Core.refreshIntervalOptions.apply(null, arguments) }
function parseMatchTimeMs() { return Core.parseMatchTimeMs.apply(null, arguments) }
function dictSet() { return Core.dictSet.apply(null, arguments) }
function dictDelete() { return Core.dictDelete.apply(null, arguments) }
function defaultState() { return Core.defaultState.apply(null, arguments) }
function formatCountdown() { return Core.formatCountdown.apply(null, arguments) }
function arrayFrom() { return Core.arrayFrom.apply(null, arguments) }
function normalizeLeagueIds() { return Core.normalizeLeagueIds.apply(null, arguments) }
function normalizeTeamIds() { return Core.normalizeTeamIds.apply(null, arguments) }
function normalizeTab() { return Core.normalizeTab.apply(null, arguments) }
function crestCacheKey() { return Core.crestCacheKey.apply(null, arguments) }
function espnDateList() { return Core.espnDateList.apply(null, arguments) }
function mergeEspnScoreboardPayloads() { return Core.mergeEspnScoreboardPayloads.apply(null, arguments) }
function formatKickoff() { return Core.formatKickoff.apply(null, arguments) }
function parseState() { return Core.parseState.apply(null, arguments) }
function statePayload() { return Core.statePayload.apply(null, arguments) }
function isEspnScoreboardPayload() { return Core.isEspnScoreboardPayload.apply(null, arguments) }
function isEspnStandingsPayload() { return Core.isEspnStandingsPayload.apply(null, arguments) }
function isF1CalendarPayload() { return Core.isF1CalendarPayload.apply(null, arguments) }
function monogramText() { return Core.monogramText.apply(null, arguments) }
function cleanPageUrl() { return Urls.cleanPageUrl.apply(null, arguments) }
function trustedHost() { return Urls.trustedHost.apply(null, arguments) }
function trustedHttpsUrl() { return Urls.trustedHttpsUrl.apply(null, arguments) }
function isTrustedCrestUrl() { return Urls.isTrustedCrestUrl.apply(null, arguments) }
function matchExternalUrl() { return Urls.matchExternalUrl.apply(null, arguments) }
function matchDetailUrl() { return Urls.matchDetailUrl.apply(null, arguments) }
function mergePages() { return Matches.mergePages.apply(null, arguments) }
function parseClockMinute() { return Matches.parseClockMinute.apply(null, arguments) }
function mergeMatchUpdates() { return Matches.mergeMatchUpdates.apply(null, arguments) }
function mergeLeaguePages() { return Matches.mergeLeaguePages.apply(null, arguments) }
function teamOptionsForSport() { return Matches.teamOptionsForSport.apply(null, arguments) }
function isFollowedTeam() { return Matches.isFollowedTeam.apply(null, arguments) }
function isNumericIdentifier() { return Matches.isNumericIdentifier.apply(null, arguments) }
function compareMatchTimes() { return Matches.compareMatchTimes.apply(null, arguments) }
function matchesForTeam() { return Matches.matchesForTeam.apply(null, arguments) }
function matchesForLeague() { return Matches.matchesForLeague.apply(null, arguments) }
function featuredMatchForTeam() { return Matches.featuredMatchForTeam.apply(null, arguments) }
function teamIdForMatch() { return Matches.teamIdForMatch.apply(null, arguments) }
function teamOutcomeForTeams() { return Matches.teamOutcomeForTeams.apply(null, arguments) }
function isStandingsRowFavorite() { return Matches.isStandingsRowFavorite.apply(null, arguments) }
function teamOutcome() { return Matches.teamOutcome.apply(null, arguments) }
function matchOutcomeForTeams() { return Matches.matchOutcomeForTeams.apply(null, arguments) }
function teamLiveState() { return Matches.teamLiveState.apply(null, arguments) }
function teamLiveStateForTeams() { return Matches.teamLiveStateForTeams.apply(null, arguments) }
function matchLiveStateForTeams() { return Matches.matchLiveStateForTeams.apply(null, arguments) }
function generalMatchOutcome() { return Matches.generalMatchOutcome.apply(null, arguments) }
function groupMatches() { return Matches.groupMatches.apply(null, arguments) }
function formatMatchDate() { return Matches.formatMatchDate.apply(null, arguments) }
function matchStatusText() { return Matches.matchStatusText.apply(null, arguments) }
function resetLiveClockCache() { return Matches.resetLiveClockCache.apply(null, arguments) }
function cleanLiveTime() { return Matches.cleanLiveTime.apply(null, arguments) }
function interpolateLiveTime() { return Matches.interpolateLiveTime.apply(null, arguments) }
function formatLiveClock() { return Matches.formatLiveClock.apply(null, arguments) }
function leagueLabel() { return Matches.leagueLabel.apply(null, arguments) }
function sportMeta() { return Matches.sportMeta.apply(null, arguments) }
function shortTournamentName() { return Matches.shortTournamentName.apply(null, arguments) }
function reconcileMatchDetails() { return Matches.reconcileMatchDetails.apply(null, arguments) }
function liveMatches() { return Matches.liveMatches.apply(null, arguments) }
function matchLine() { return Matches.matchLine.apply(null, arguments) }
function leagues() { return Matches.leagues.apply(null, arguments) }
function sports() { return Matches.sports.apply(null, arguments) }
function buildPersistedState() { return Matches.buildPersistedState.apply(null, arguments) }
function sameTeamData() { return Matches.sameTeamData.apply(null, arguments) }
function sameSessions() { return Matches.sameSessions.apply(null, arguments) }
function sameMatches() { return Matches.sameMatches.apply(null, arguments) }
function sameRows() { return Matches.sameRows.apply(null, arguments) }
function sameGroups() { return Matches.sameGroups.apply(null, arguments) }
function resetMockClock() { return Mock.resetMockClock.apply(null, arguments) }
function mockMinuteClock() { return Mock.mockMinuteClock.apply(null, arguments) }
function mockRound() { return Mock.mockRound.apply(null, arguments) }
function mockFootballTable() { return Mock.mockFootballTable.apply(null, arguments) }
function mockEspnTable() { return Mock.mockEspnTable.apply(null, arguments) }
function mockF1Drivers() { return Mock.mockF1Drivers.apply(null, arguments) }
function mockF1Constructors() { return Mock.mockF1Constructors.apply(null, arguments) }
function notificationClock() { return Notifications.notificationClock.apply(null, arguments) }
function mergeSeenMap() { return Notifications.mergeSeenMap.apply(null, arguments) }
function notificationTeamName() { return Notifications.notificationTeamName.apply(null, arguments) }
function diffMatchNotifications() { return Notifications.diffMatchNotifications.apply(null, arguments) }
function escapeNotificationMarkup() { return Notifications.escapeNotificationMarkup.apply(null, arguments) }
function f1CountryFlag() { return F1.f1CountryFlag.apply(null, arguments) }
function f1DriverFlag() { return F1.f1DriverFlag.apply(null, arguments) }
function parseF1SeasonWinners() { return F1.parseF1SeasonWinners.apply(null, arguments) }
function parseF1Calendar() { return F1.parseF1Calendar.apply(null, arguments) }
function parseF1DriverStandings() { return F1.parseF1DriverStandings.apply(null, arguments) }
function parseF1ConstructorStandings() { return F1.parseF1ConstructorStandings.apply(null, arguments) }
function nextF1Session() { return F1.nextF1Session.apply(null, arguments) }
function parseF1Podium() { return F1.parseF1Podium.apply(null, arguments) }
function parseF1Pole() { return F1.parseF1Pole.apply(null, arguments) }
function parseEspnScoreboard() { return Espn.parseEspnScoreboard.apply(null, arguments) }
function parseEspnStandings() { return Espn.parseEspnStandings.apply(null, arguments) }
function parseEspnBroadcast() { return Espn.parseEspnBroadcast.apply(null, arguments) }
function parseEspnGameLeaders() { return Espn.parseEspnGameLeaders.apply(null, arguments) }
function parseEspnNews() { return Espn.parseEspnNews.apply(null, arguments) }
function extractPageProps() { return Fotmob.extractPageProps.apply(null, arguments) }
function parseScore() { return Fotmob.parseScore.apply(null, arguments) }
function parseMatch() { return Fotmob.parseMatch.apply(null, arguments) }
function parseDetails() { return Fotmob.parseDetails.apply(null, arguments) }
function parseStandings() { return Fotmob.parseStandings.apply(null, arguments) }
function zoneFromLegend() { return Fotmob.zoneFromLegend.apply(null, arguments) }
function parseLeaguePage() { return Fotmob.parseLeaguePage.apply(null, arguments) }
function findTeamPageData() { return Fotmob.findTeamPageData.apply(null, arguments) }
function isTeamPagePayload() { return Fotmob.isTeamPagePayload.apply(null, arguments) }
function parseTeamPage() { return Fotmob.parseTeamPage.apply(null, arguments) }
function parseFotmobEvents() { return Fotmob.parseFotmobEvents.apply(null, arguments) }
function parseFotmobForm() { return Fotmob.parseFotmobForm.apply(null, arguments) }
function parseFotmobStats() { return Fotmob.parseFotmobStats.apply(null, arguments) }
