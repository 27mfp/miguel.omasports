// Run with: node tests/sportsmodel.test.mjs
// The former monolith is split by provider/concern under tests/model/. This
// entrypoint keeps the historical command and prints one aggregate summary.
import "./model/core.test.mjs"
import "./model/espn.test.mjs"
import "./model/f1.test.mjs"
import "./model/fotmob.test.mjs"
import "./model/matches.test.mjs"
import "./model/notifications.test.mjs"
import { summary } from "./model/harness.mjs"

summary()
