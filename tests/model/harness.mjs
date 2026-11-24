// Shared model-test harness. The public export list is the contract QML and
// Node consumers rely on; it also catches a renamed/removed export at load time.
import { loadModel } from "../model-loader.mjs"

export const exported = [
  "supportedSports", "supportedLeagues", "nbaTeams", "nhlTeams", "mlbTeams",
  "nflTeams", "f1Drivers", "popularFootballClubs",
  "defaultState", "formatCountdown", "arrayFrom", "normalizeLeagueIds",
  "normalizeTeamIds", "crestCacheKey", "espnDateList", "mergeEspnScoreboardPayloads", "formatKickoff",
  "normalizeTab", "isEspnScoreboardPayload", "isEspnStandingsPayload", "isF1CalendarPayload",
  "parseState", "statePayload", "parseEspnScoreboard", "parseEspnStandings",
  "f1CountryFlag", "f1DriverFlag", "parseF1Calendar", "parseF1DriverStandings",
  "parseF1ConstructorStandings", "parseScore", "parseMatch", "parseDetails",
  "parseStandings", "zoneFromLegend", "mergePages", "mergeMatchUpdates", "mergeLeaguePages",
  "isTeamPagePayload", "teamOptionsForSport",
  "matchesForTeam", "matchesForLeague", "featuredMatchForTeam", "teamIdForMatch", "teamOutcome",
  "teamOutcomeForTeams", "matchOutcomeForTeams", "teamLiveState", "teamLiveStateForTeams",
  "matchLiveStateForTeams", "generalMatchOutcome", "isFollowedTeam", "isStandingsRowFavorite",
  "groupMatches", "formatMatchDate", "matchStatusText", "leagueLabel", "isTrustedCrestUrl",
  "matchExternalUrl", "matchDetailUrl",
  "sportMeta", "shortTournamentName", "liveMatches", "matchLine", "interpolateLiveTime",
  "sameMatches", "sameRows", "sameGroups", "diffMatchNotifications", "buildPersistedState",
  "parseLeaguePage", "parseTeamPage",
  "mockRound", "parseMatchTimeMs", "refreshIntervalOptions", "mergeSeenMap", "NOTIFICATION_TTL_MS",
  "dictSet", "dictDelete",
  "safeHome", "clampRefreshMinutes", "MAX_ROUND_RETRIES", "RETRY_DELAY_MS", "RETRY_DELAY_ESPN_MS",
  "RETRY_DELAY_FOTMOB_F1_MS", "F1_RESULTS_REFRESH_MS", "MIN_REFRESH_MINUTES", "MAX_REFRESH_MINUTES",
  "REFRESH_OPTIONS",
  "monogramText", "parseF1SeasonWinners", "nextF1Session",
  "parseEspnBroadcast", "parseEspnGameLeaders", "parseEspnNews",
  "parseFotmobEvents", "parseFotmobForm", "parseFotmobStats",
  "parseF1Podium", "parseF1Pole", "formatLiveClock", "cleanLiveTime", "resetLiveClockCache",
  "reconcileMatchDetails", "extractPageProps"
]

export const Model = await loadModel(exported)
for (const name of exported) {
  if (!(name in Model)) throw new Error("missing export from SportsModel.js: " + name)
}

let passed = 0
const failures = []

export function test(name, fn) {
  try {
    fn()
    passed++
    console.log("  ✓ " + name)
  } catch (error) {
    failures.push(name)
    console.log("  ✗ " + name + "\n    " + String(error.message || error).split("\n").slice(0, 6).join("\n    "))
  }
}

export function summary() {
  if (failures.length) {
    console.error(`\n${passed} passed, ${failures.length} failed: ${failures.join(", ")}`)
    process.exitCode = 1
    return
  }
  console.log(`\n${passed} tests passed ✓`)
}
