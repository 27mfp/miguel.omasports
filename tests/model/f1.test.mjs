// Focused model tests: Formula 1 calendar, standings, winners, sessions, podium/pole.
// Run directly or through tests/sportsmodel.test.mjs (all modules).
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { Model, test } from "./harness.mjs"

// ---------------------------------------------------------------- F1
console.log("Formula 1")
const f1Calendar = JSON.stringify({
  MRData: { RaceTable: { Races: [
    {
      round: "1", raceName: "Australian Grand Prix", date: "2026-03-08", time: "05:00:00Z", url: "https://wikipedia.org/x",
      Circuit: { circuitName: "Albert Park Circuit", Location: { locality: "Melbourne", country: "Australia" } },
      FirstPractice: { date: "2026-03-06", time: "01:30:00Z" },
      SecondPractice: { date: "2026-03-06", time: "05:00:00Z" },
      ThirdPractice: { date: "2026-03-07", time: "02:30:00Z" },
      Qualifying: { date: "2026-03-07", time: "06:00:00Z" }
    },
    {
      round: "2", raceName: "Saudi Arabian Grand Prix", date: "2100-01-01", time: "14:00:00Z",
      Circuit: { circuitName: "Jeddah Corniche Circuit", Location: { locality: "Jeddah", country: "Saudi Arabia" } },
      FirstPractice: { date: "2100-01-01", time: "10:00:00Z" },
      SprintQualifying: { date: "2100-01-01", time: "11:00:00Z" },
      Sprint: { date: "2100-01-01", time: "12:00:00Z" },
      Qualifying: { date: "2100-01-01", time: "13:00:00Z" }
    }
  ] } }
})
test("parseF1Calendar builds weekend sessions and statuses", () => {
  const races = Model.parseF1Calendar(f1Calendar)
  assert.equal(races.length, 2)
  const [past, future] = races
  assert.equal(past.status, "finished")
  assert.equal(past.countryFlag, "🇦🇺")
  assert.deepEqual(past.sessions.map(s => s.shortName), ["FP1", "FP2", "FP3", "Quali", "Race"])
  assert.equal(future.status, "upcoming")
  assert.deepEqual(future.sessions.map(s => s.shortName), ["FP1", "SQ", "Sprint", "Quali", "Race"])
})
const f1DriversJson = JSON.stringify({
  MRData: { StandingsTable: { StandingsLists: [{
    DriverStandings: [
      {
        position: "1", points: "257", wins: "6",
        Driver: { driverId: "max_verstappen", givenName: "Max", familyName: "Verstappen", code: "VER", nationality: "Dutch" },
        Constructors: [{ constructorId: "red_bull", name: "Red Bull Racing" }]
      },
      {
        position: "22", points: "4", wins: "0",
        Driver: { driverId: "perez", givenName: "Sergio", familyName: "Pérez", code: "PER", nationality: "Mexican" },
        Constructors: [{ constructorId: "cadillac", name: "Cadillac" }]
      }
    ]
  }] } }
})
test("parseF1DriverStandings maps rows with flags and points", () => {
  const rows = Model.parseF1DriverStandings(f1DriversJson)
  assert.equal(rows.length, 2)
  assert.equal(rows[0].pts, "257 PTS")
  assert.equal(rows[0].flag, "🇳🇱")
  assert.equal(rows[0].zone, "europe")
  assert.equal(rows[1].flag, "🇲🇽")
  assert.equal(rows[1].teamName, "Cadillac")
})
test("f1DriverFlag covers the 2026 grid", () => {
  assert.equal(Model.f1DriverFlag("max_verstappen"), "🇳🇱")
  assert.equal(Model.f1DriverFlag("arvid_lindblad"), "🇬🇧")
  assert.equal(Model.f1DriverFlag("colapinto"), "🇦🇷")
  assert.equal(Model.f1DriverFlag("bottas"), "🇫🇮")
  assert.equal(Model.f1DriverFlag("lawson"), "🇳🇿")
  assert.equal(Model.f1DriverFlag("hulkenberg"), "🇩🇪")
  assert.equal(Model.f1DriverFlag("unknown"), "🏎")
})
test("f1CountryFlag resolves hosts and circuits", () => {
  assert.equal(Model.f1CountryFlag("", "São Paulo Grand Prix"), "🇧🇷")
  assert.equal(Model.f1CountryFlag("United States", ""), "🇺🇸")
  assert.equal(Model.f1CountryFlag("Saudi Arabia", ""), "🇸🇦")
})


// ---------------------------------------------------------------- f1 winners & sessions
console.log("f1 winners & sessions")
test("parseF1SeasonWinners parses Jolpica race results into round-keyed map", () => {
  const sample = JSON.stringify({
    MRData: {
      RaceTable: {
        Races: [
          {
            season: "2026",
            round: "1",
            raceName: "Australian Grand Prix",
            Results: [
              {
                position: "1",
                points: "25",
                Driver: { driverId: "russell", code: "RUS", givenName: "George", familyName: "Russell" },
                Constructor: { constructorId: "mercedes", name: "Mercedes" },
                Time: { time: "1:26:37.979" },
                laps: "71",
                grid: "1"
              }
            ]
          },
          {
            season: "2026",
            round: "2",
            raceName: "Chinese Grand Prix",
            Results: [
              {
                position: "1",
                points: "25",
                Driver: { driverId: "norris", code: "NOR", givenName: "Lando", familyName: "Norris" },
                Constructor: { constructorId: "mclaren", name: "McLaren" },
                Time: { time: "1:32:15.111" },
                laps: "56",
                grid: "2"
              }
            ]
          }
        ]
      }
    }
  })

  const winners = Model.parseF1SeasonWinners(sample)
  assert.equal(Object.keys(winners).length, 2)
  assert.equal(winners["1"].driverId, "russell")
  assert.equal(winners["1"].driverName, "George Russell")
  assert.equal(winners["1"].code, "RUS")
  assert.equal(winners["1"].constructorName, "Mercedes")
  assert.equal(winners["1"].time, "1:26:37.979")
  assert.equal(winners["2"].driverId, "norris")
  assert.equal(winners["2"].driverName, "Lando Norris")
  assert.equal(winners["2"].code, "NOR")
  assert.equal(winners["2"].constructorName, "McLaren")
})

test("parseF1SeasonWinners handles null/empty/corrupt inputs safely", () => {
  assert.deepEqual(Model.parseF1SeasonWinners(null), {})
  assert.deepEqual(Model.parseF1SeasonWinners(""), {})
  assert.deepEqual(Model.parseF1SeasonWinners("{ invalid json"), {})
  assert.deepEqual(Model.parseF1SeasonWinners(JSON.stringify({ MRData: {} })), {})
})

test("parseF1Calendar attaches winner and sets scoreText when winnersMap is supplied", () => {
  const calendarPayload = JSON.stringify({
    MRData: {
      RaceTable: {
        Races: [
          {
            round: "1",
            raceName: "Australian Grand Prix",
            Circuit: { circuitName: "Albert Park Circuit", Location: { locality: "Melbourne", country: "Australia" } },
            date: "2026-03-15",
            time: "04:00:00Z"
          },
          {
            round: "2",
            raceName: "Chinese Grand Prix",
            Circuit: { circuitName: "Shanghai International Circuit", Location: { locality: "Shanghai", country: "China" } },
            date: "2026-03-22",
            time: "07:00:00Z"
          }
        ]
      }
    }
  })

  const winners = {
    "1": {
      round: "1",
      driverId: "russell",
      driverName: "George Russell",
      familyName: "Russell",
      code: "RUS",
      constructorName: "Mercedes",
      time: "1:26:37.979"
    }
  }

  // With winners map: Round 1 has winner attached and finished status
  const enriched = Model.parseF1Calendar(calendarPayload, 0, winners)
  assert.equal(enriched.length, 2)
  assert.equal(enriched[0].status, "finished")
  assert.ok(enriched[0].winner)
  assert.equal(enriched[0].winner.code, "RUS")
  assert.equal(enriched[0].scoreText, "🏆 RUS")
  assert.equal(enriched[0].statusReason, "Winner: George Russell")

  // Round 2 has no winner yet: standard behavior
  assert.equal(enriched[1].winner, undefined)

  // Without winners map: backwards compatible (no winner field, scoreText Official)
  const legacy = Model.parseF1Calendar(calendarPayload, Date.parse("2026-03-16T00:00:00Z"))
  assert.equal(legacy[0].winner, undefined)
  assert.equal(legacy[0].scoreText, "Official")
})

test("nextF1Session finds live or next upcoming session", () => {
  const match = {
    sessions: [
      { name: "Practice 1", shortName: "FP1", time: "2026-06-05T11:30:00Z" },
      { name: "Practice 2", shortName: "FP2", time: "2026-06-05T15:00:00Z" },
      { name: "Qualifying", shortName: "Quali", time: "2026-06-06T14:00:00Z" },
      { name: "Grand Prix (Race)", shortName: "Race", time: "2026-06-07T13:00:00Z" }
    ]
  }

  // Friday morning before FP1
  const beforeFP1 = Model.nextF1Session(match, Date.parse("2026-06-05T10:00:00Z"))
  assert.ok(beforeFP1)
  assert.equal(beforeFP1.shortName, "FP1")
  assert.equal(beforeFP1.isLive, false)

  // Friday during FP1 (30m after start)
  const duringFP1 = Model.nextF1Session(match, Date.parse("2026-06-05T12:00:00Z"))
  assert.ok(duringFP1)
  assert.equal(duringFP1.shortName, "FP1")
  assert.equal(duringFP1.isLive, true)

  // Saturday morning before Quali
  const beforeQuali = Model.nextF1Session(match, Date.parse("2026-06-06T09:00:00Z"))
  assert.ok(beforeQuali)
  assert.equal(beforeQuali.shortName, "Quali")
  assert.equal(beforeQuali.isLive, false)

  // Sunday evening after Race (finished)
  const afterRace = Model.nextF1Session(match, Date.parse("2026-06-07T17:00:00Z"))
  assert.equal(afterRace, null)
})

test("featuredMatchForTeam prioritizes live, then nearest upcoming, then latest finished", () => {
  const mFinishedOld = { id: "1", status: "finished", time: "2026-08-20T18:00:00Z" }
  const mFinishedRecent = { id: "2", status: "finished", time: "2026-08-21T18:00:00Z" }
  const mLive = { id: "3", status: "live", time: "2026-08-22T19:00:00Z" }
  const mUpcomingSoon = { id: "4", status: "upcoming", time: new Date(Date.now() + 3600000).toISOString() }
  const mUpcomingLater = { id: "5", status: "upcoming", time: new Date(Date.now() + 86400000).toISOString() }

  // 1. Live takes absolute priority
  assert.equal(Model.featuredMatchForTeam([mFinishedRecent, mLive, mUpcomingSoon]).id, "3")

  // 2. Nearest upcoming when no live match exists
  assert.equal(Model.featuredMatchForTeam([mFinishedRecent, mUpcomingLater, mUpcomingSoon]).id, "4")

  // 3. Most recent finished when no live or upcoming exists
  assert.equal(Model.featuredMatchForTeam([mFinishedOld, mFinishedRecent]).id, "2")

  // 4. Empty array returns null
  assert.equal(Model.featuredMatchForTeam([]), null)
})


test("parseF1Podium extracts top 3 finishers with points", () => {
  const raw = {
    MRData: {
      RaceTable: {
        Races: [
          {
            Results: [
              { Driver: { code: "NOR", givenName: "Lando", familyName: "Norris" }, Constructor: { name: "McLaren" }, Time: { time: "1:28:44.859" }, points: "25" },
              { Driver: { code: "ANT", givenName: "Kimi", familyName: "Antonelli" }, Constructor: { name: "Mercedes" }, Time: { time: "+11.536" }, points: "18" },
              { Driver: { code: "RUS", givenName: "George", familyName: "Russell" }, Constructor: { name: "Mercedes" }, Time: { time: "+15.906" }, points: "15" },
              { Driver: { code: "VER", familyName: "Verstappen" }, Constructor: { name: "Red Bull" }, points: "12" }
            ]
          }
        ]
      }
    }
  }
  const podium = Model.parseF1Podium(raw)
  assert.equal(podium.length, 3)
  assert.equal(podium[0].code, "NOR")
  assert.equal(podium[0].points, "25")
  assert.equal(podium[1].code, "ANT")
  assert.equal(podium[1].points, "18")
  assert.equal(podium[2].code, "RUS")
  assert.equal(podium[2].points, "15")
  assert.deepEqual(Model.parseF1Podium(null), [])
})

test("parseF1Pole extracts pole position and Q3 time", () => {
  const raw = {
    MRData: {
      RaceTable: {
        Races: [
          {
            QualifyingResults: [
              { Driver: { code: "NOR", givenName: "Lando", familyName: "Norris" }, Constructor: { name: "McLaren" }, Q3: "1:11.163" }
            ]
          }
        ]
      }
    }
  }
  const pole = Model.parseF1Pole(raw)
  assert.ok(pole)
  assert.equal(pole.code, "NOR")
  assert.equal(pole.lapTime, "1:11.163")
  assert.equal(Model.parseF1Pole(null), null)
})
