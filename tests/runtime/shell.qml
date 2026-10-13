import QtQuick
import Quickshell
import "." as Plugin

// No windows, host IPC, state files, notifications, or network requests.
ShellRoot {
  id: root
  property int stage: 0
  function fail(message) {
    console.error("RUNTIME_FAIL: " + message)
    Qt.quit()
  }
  Plugin.NetworkProcess {
    id: worker
    maxOutputBytes: 1024
    onOutput: function(text) {
      if (handled) { root.fail("output emitted after handled"); return }
      if (root.stage === 0) {
        if (text.trim() !== "first") { root.fail("first payload mismatch"); return }
        root.stage = 1
        Qt.callLater(function() {
          if (!worker.handled) { root.fail("completion did not set handled"); return }
          worker.handled = false
          worker.command = ["/usr/bin/printf", "second"]
          worker.running = true
        })
      } else if (root.stage === 1) {
        if (text.trim() !== "second") { root.fail("restart payload mismatch"); return }
        root.stage = 2
        Qt.callLater(function() {
          worker.handled = false
          worker.command = ["/usr/bin/true"]
          worker.running = true
        })
      } else root.fail("unexpected duplicate output")
    }
    onFailed: {
      if (root.stage !== 2 || handled) { root.fail("unexpected failed signal"); return }
      root.stage = 3
      Qt.callLater(function() {
        if (!worker.handled) { root.fail("failure did not set handled"); return }
        console.log("RUNTIME_PASS: output, deferred restart, empty-output failure")
        Qt.quit()
      })
    }
  }
  Timer {
    interval: 5000
    running: true
    onTriggered: root.fail("timeout")
  }
  Component.onCompleted: {
    worker.handled = false
    worker.command = ["/usr/bin/printf", "first"]
    worker.running = true
  }
}
