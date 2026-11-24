.pragma library
.import "core.js" as Core
.import "matches.js" as Matches

// Notification diffing and markup-safe delivery helpers.

function notificationClock(timeMs) {
  var date = new Date(timeMs)
  return ("0" + date.getHours()).slice(-2) + ":" + ("0" + date.getMinutes()).slice(-2)
}

function mergeSeenMap(prev, next, now, ttl) {
  var merged = {}
  for (var prevId in next) {
    if (Object.prototype.hasOwnProperty.call(next, prevId)) merged[prevId] = next[prevId]
  }
  for (var oldId in prev) {
    if (Object.prototype.hasOwnProperty.call(prev, oldId) && !Object.prototype.hasOwnProperty.call(merged, oldId)) {
      var oldEntry = prev[oldId]
      if (oldEntry && now - Number(oldEntry.seenAt || 0) < ttl) merged[oldId] = oldEntry
    }
  }
  return merged
}

function notificationTeamName(team) {
  return String(team && (team.name || team.shortName) || "Team")
}

function diffMatchNotifications(matches, previous, options) {
  var opts = options || {}
  var oldSeen = previous && typeof previous === "object" ? previous : {}
  var source = Core.arrayFrom(matches)
  var now = Number(opts.nowMs)
  if (!isFinite(now)) now = Date.now()
  if (opts.enabled === false) return { notifications: [], nextSeen: oldSeen }
  if (source.length === 0) {
    return { notifications: [], nextSeen: mergeSeenMap(oldSeen, {}, now, Core.NOTIFICATION_TTL_MS) }
  }

  var activeSport = String(opts.activeSport || "").toLowerCase()
  var favoriteIds = Core.arrayFrom(opts.favoriteIds)
  var nextSeen = {}
  var notifications = []

  for (var i = 0; i < source.length; i++) {
    var m = source[i]
    if (!m || !m.id) continue
    var id = String(m.id)
    var hasPrevious = Object.prototype.hasOwnProperty.call(oldSeen, id)
    var candidate = hasPrevious && oldSeen[id] && typeof oldSeen[id] === "object" ? oldSeen[id] : null
    var prev = candidate && now - Number(candidate.seenAt || 0) < Core.NOTIFICATION_TTL_MS ? candidate : null
    var homeId = String(m.home && m.home.id || "").toLowerCase()
    var awayId = String(m.away && m.away.id || "").toLowerCase()
    var isFavorite = activeSport === "f1"
      || Matches.isFollowedTeam(homeId, favoriteIds)
      || Matches.isFollowedTeam(awayId, favoriteIds)
    var homeName = notificationTeamName(m.home)
    var awayName = notificationTeamName(m.away)
    var sport = String(m.sport || activeSport || "football").toLowerCase()
    var icon = Matches.sportMeta(sport).icon
    var previousHomeScore = Number(prev && prev.homeScore || 0)
    var previousAwayScore = Number(prev && prev.awayScore || 0)
    var homeScore = Number(m.homeScore || 0)
    var awayScore = Number(m.awayScore || 0)
    var upcomingNotified = !!(prev && prev.notifiedUpcoming)
    var halfTimeNotified = !!(prev && prev.notifiedHalfTime)

    // Never notify on first sight: the first poll establishes a baseline.
    if (prev && isFavorite) {
      if (m.status === "live" && prev.status === "upcoming") {
        notifications.push({
          kind: "started",
          matchId: id,
          sport: sport,
          iconTeam: m.home || {},
          title: sport === "f1" ? ("🏁 F1: " + (m.raceName || homeName || "Grand Prix")) : ("● LIVE: " + homeName + " vs " + awayName),
          body: sport === "f1"
            ? ("The session is underway in " + (m.locality || m.country || "live") + "!")
            : ("The match has kicked off!" + (m.leagueName ? " · " + m.leagueName : "")),
          urgency: "normal"
        })
      }

      if (m.status === "finished" && prev.status === "live") {
        notifications.push({
          kind: "finished",
          matchId: id,
          sport: sport,
          iconTeam: m.home || {},
          title: sport === "f1"
            ? ("🏁 Finished: " + (m.raceName || homeName || "Grand Prix"))
            : ("🏁 FULL TIME: " + homeName + (opts.antiSpoiler ? " vs " : (" " + (m.scoreText || (homeScore + " – " + awayScore)) + " ")) + awayName),
          body: opts.antiSpoiler
            ? (sport === "football" ? "Match has finished (score concealed)" : "Event finished (result concealed)")
            : (sport === "f1" ? "The session has concluded!" : (homeName + " " + (m.scoreText || (homeScore + " – " + awayScore)) + " " + awayName + " · Final")),
          urgency: "normal"
        })
      }

      if (m.status === "live") {
        var isHalfTime = (
          Matches.parseClockMinute(m.liveTime) === 45.5 ||
          String(m.liveTime || "").replace(/[\u200e\u200f\s]/g, "").toUpperCase() === "HT" ||
          String(m.liveTime || "").toLowerCase().indexOf("half") !== -1
        )
        if (isHalfTime && !halfTimeNotified) {
          notifications.push({
            kind: "halftime",
            matchId: id,
            sport: sport,
            iconTeam: m.home || {},
            title: "⏱ HALF TIME: " + homeName + (opts.antiSpoiler ? " vs " : (" " + (m.scoreText || (homeScore + " – " + awayScore)) + " ")) + awayName,
            body: opts.antiSpoiler
              ? (homeName + " vs " + awayName + " · Half time (score concealed)")
              : (homeName + " " + (m.scoreText || (homeScore + " – " + awayScore)) + " " + awayName + " · Half Time"),
            urgency: "normal"
          })
          halfTimeNotified = true
        }

        var homeDelta = homeScore - previousHomeScore
        var awayDelta = awayScore - previousAwayScore
        if (homeDelta > 0) {
          notifications.push({
            kind: "score",
            matchId: id,
            sport: sport,
            side: "home",
            delta: homeDelta,
            iconTeam: m.home || {},
            title: sport === "football" ? ("⚽ GOAL! " + homeName) : (icon + " " + homeName + " (+" + homeDelta + ")"),
            body: opts.antiSpoiler
              ? (homeName + " scored" + (m.liveTime ? " (" + m.liveTime + ")" : "") + " · (Score hidden)")
              : (homeName + " " + (m.scoreText || (homeScore + " – " + awayScore)) + " " + awayName + (m.liveTime ? " (" + m.liveTime + ")" : "")),
            urgency: "normal"
          })
        }
        if (awayDelta > 0) {
          notifications.push({
            kind: "score",
            matchId: id,
            sport: sport,
            side: "away",
            delta: awayDelta,
            iconTeam: m.away || {},
            title: sport === "football" ? ("⚽ GOAL! " + awayName) : (icon + " " + awayName + " (+" + awayDelta + ")"),
            body: opts.antiSpoiler
              ? (awayName + " scored" + (m.liveTime ? " (" + m.liveTime + ")" : "") + " · (Score hidden)")
              : (homeName + " " + (m.scoreText || (homeScore + " – " + awayScore)) + " " + awayName + (m.liveTime ? " (" + m.liveTime + ")" : "")),
            urgency: "normal"
          })
        }
      }

      if (m.status === "upcoming" && !upcomingNotified) {
        var kickoffMs = Core.parseMatchTimeMs(m)
        if (!isNaN(kickoffMs)) {
          var diffMins = Math.floor((kickoffMs - now) / 60000)
          if (diffMins > 0 && diffMins <= 15) {
            notifications.push({
              kind: "upcoming",
              matchId: id,
              sport: sport,
              minutes: diffMins,
              iconTeam: m.home || {},
              title: sport === "f1"
                ? ("🏎️ F1 starting soon: " + (m.raceName || homeName || "Grand Prix"))
                : ("⏰ Starting in " + diffMins + "m: " + homeName + " vs " + awayName),
              body: (m.leagueName ? m.leagueName + " · " : "") + "Scheduled start at " + notificationClock(kickoffMs),
              urgency: "normal"
            })
            upcomingNotified = true
          }
        }
      }
    }

    nextSeen[id] = {
      homeScore: homeScore,
      awayScore: awayScore,
      status: String(m.status || "upcoming"),
      notifiedUpcoming: upcomingNotified,
      notifiedHalfTime: halfTimeNotified,
      seenAt: now
    }
  }

  // Keep history through transient provider omissions, but do not retain
  // unbounded match ids forever.
  return { notifications: notifications, nextSeen: mergeSeenMap(oldSeen, nextSeen, now, Core.NOTIFICATION_TTL_MS) }
}

function escapeNotificationMarkup(value) {
  return String(value || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}
