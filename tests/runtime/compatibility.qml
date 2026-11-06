import QtQuick
import Quickshell
import qs.Commons as Commons
import "sports" as Sports

ShellRoot {
  id: root
  property var race: ({
    id: "race", sport: "f1", status: "finished", time: "2026-11-01T14:00:00Z",
    raceName: "Test Grand Prix", circuitName: "Test Circuit", locality: "Test City",
    home: { id: "race", name: "Test Grand Prix", shortName: "Test GP" },
    away: { id: "", name: "", shortName: "" },
    winner: { code: "SEC", familyName: "Secret", driverName: "Secret Driver", constructorName: "Secret Team" },
    sessions: [{ shortName: "Race", name: "Race", time: "2026-11-01T14:00:00Z" }]
  })
  property bool revealed: false

  function check(ok, message) {
    if (!ok) throw new Error("COMPAT_FAIL: " + message)
  }
  function visit(item, fn) {
    fn(item)
    const children = item.children || []
    for (let i = 0; i < children.length; i++) visit(children[i], fn)
  }
  function visibleText(item) {
    if (item.visible === false) return ""
    let result = typeof item.text === "string" ? item.text + " " : ""
    const children = item.children || []
    for (let i = 0; i < children.length; i++) result += visibleText(children[i])
    return result
  }

  Item {
    width: 600
    height: 1200
    Sports.NewsCard {
      id: news
      articles: [{ headline: '<img src="https://example.invalid/tracker">', description: "<b>Literal</b>", published: "2026-11-06T12:00:00Z" }]
      forceExpanded: true
    }
    Sports.TeamCrest {
      id: crest
      source: "https://images.fotmob.com/image_resources/logo/teamlogo/9825.png"
      teamId: "9825"
      teamName: "Arsenal"
    }
    Sports.MatchRow {
      id: row
      index: 0
      modelData: root.race
      activeSport: "f1"
      antiSpoiler: true
      expandedIds: ({race: true})
      fgColor: Commons.Color.foreground
      urgentColor: Commons.Color.urgent
      listVisible: false
    }
    Sports.MatchSpotlight {
      id: spotlight
      featuredMatch: root.race
      activeSport: "f1"
      isF1: true
      antiSpoiler: true
      detailsExpanded: true
      f1Podium: [{code: "SEC", driverName: "Secret Driver"}, {code: "TWO"}, {code: "THR"}]
      f1Pole: ({code: "SEC"})
      fgColor: Commons.Color.foreground
      urgentColor: Commons.Color.urgent
      listVisible: false
    }
  }

  Timer {
    interval: 250
    running: true
    onTriggered: {
      try {
        root.check(news.fgColor.toString() === Commons.Color.foreground.toString(), "Omarchy palette was not resolved")
        let literalFound = false
        root.visit(news, function(item) {
          if (typeof item.text === "string" && item.text.indexOf("<img") !== -1) {
            literalFound = true
            root.check(item.textFormat === Text.PlainText, "headline interpreted as rich text")
          }
        })
        root.check(literalFound, "headline delegate did not load")
        root.visit(crest, function(item) {
          if (item.status !== undefined && item.source !== undefined)
            root.check(!/^https?:/.test(String(item.source)), "crest bypasses cache helper")
        })
        root.check(crest.localCachePath === "", "cold cache must use the monogram")
        crest.knownLogoKeys = ({"football-9825": true})
        root.check(crest.localCachePath.indexOf("football-9825.png") !== -1, "cache publication did not reach the crest")
        for (const item of [row, spotlight]) {
          const hidden = root.visibleText(item)
          root.check(hidden.indexOf("Secret") === -1 && hidden.indexOf("SEC") === -1, "hidden F1 result leaked: " + hidden)
          item.revealedMatchIds = ({race: true})
        }
        Qt.callLater(function() {
          try {
            for (const item of [row, spotlight])
              root.check(/SEC|Secret/.test(root.visibleText(item)), "explicit reveal did not show the winner")
            root.revealed = true
            cacheCheck.start()
          } catch (error) { console.error(String(error)) }
          if (!root.revealed) Qt.quit()
        })
      } catch (error) {
        console.error(String(error))
        Qt.quit()
      }
    }
  }
  Timer {
    id: cacheCheck
    interval: 200
    onTriggered: {
      try {
        let ready = false
        root.visit(crest, function(item) {
          if (item.status !== undefined && item.source !== undefined && item.status === Image.Ready) ready = true
        })
        root.check(ready, "published local crest did not load")
        console.log("COMPAT_PASS")
      } catch (error) { console.error(String(error)) }
      Qt.quit()
    }
  }
}
