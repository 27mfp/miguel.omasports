import QtQuick

// Coalesced retry Timer shared by the football round dispatcher, the team
// page fetcher, the ESPN scoreboard/standings pair, and the F1 calendar.
//
// Without this, each retry slot was a copy-pasted `Timer { interval: 2500;
// onTriggered: { if (... guards ...) callback() } }`. New retry slots
// routinely forgot one of the guards; centralizing the gating here makes
// it impossible to forget the requestSerial check (which keeps late
// callbacks from a previous round from re-dispatching a new one).
Timer {
  id: root

  // Function returning true when the retry should fire. Receives no
  // arguments; the host panel keeps its own predicate variables.
  property var predicate
  // Function called when predicate() returns true. Runs no args.
  property var callback
  interval: 2500
  repeat: false
  onTriggered: {
    if (!predicate || predicate() === true) {
      if (callback) callback()
    } else {
      // Guards failed: caller invalidated this retry. Stop so a stale
      // trigger can't re-arm and dispatch a request against the wrong
      // generation. The host's next round starts a fresh RetryTimer.
      stop()
    }
  }
}
