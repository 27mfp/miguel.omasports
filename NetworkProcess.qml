import QtQuick
import Quickshell.Io

// Shared argv-based process wrapper for provider requests. It converts the
// Process/StdioCollector lifecycle into one output signal and one failure
// signal, preventing stale or duplicate callbacks when a process is stopped.
Process {
  id: root

  property bool handled: false
  property bool started: false
  property int processGeneration: 0
  property int serial: 0
  property string pendingOutput: ""
  property bool outputReady: false

  signal output(string text)
  signal failed()

  property Timer completionTimer: Timer {
    // Leave a short grace window for the stdout parser to publish its final
    // buffer after QProcess reports that it stopped.
    interval: 50
    repeat: false
    property int expectedGeneration: -1

    onTriggered: {
      if (expectedGeneration !== root.processGeneration || root.handled || root.running) return
      if (root.outputReady && root.pendingOutput.trim()) {
        var payload = root.pendingOutput
        root.pendingOutput = ""
        root.outputReady = false
        // Emit before marking handled so existing resolvers can atomically gate
        // and update their per-request state in the callback.
        root.output(payload)
        root.handled = true
        return
      }
      root.pendingOutput = ""
      root.outputReady = false
      root.failed()
      root.handled = true
    }
  }

  stdout: StdioCollector {
    waitForEnd: true
    onStreamFinished: {
      if (root.handled) return
      root.pendingOutput = String(text || "")
      root.outputReady = true
      // Normally runningChanged(false) schedules this. The extra restart also
      // covers the event ordering where stdout closes after Process.running.
      if (!root.running) root.completionTimer.restart()
    }
  }

  onRunningChanged: {
    if (root.running) {
      root.completionTimer.stop()
      root.pendingOutput = ""
      root.outputReady = false
      root.started = true
      root.processGeneration++
      return
    }
    if (!root.started) return
    root.started = false
    // stdout may close just before or just after Process.running changes
    // depending on the provider and Qt event ordering. Defer completion one
    // turn so a complete stdout payload always wins over empty-output fallback.
    root.completionTimer.expectedGeneration = root.processGeneration
    root.completionTimer.restart()
  }
}
