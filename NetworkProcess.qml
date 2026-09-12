import QtQuick
import Quickshell.Io

// Shared argv-based process wrapper for provider requests. It converts the
// streamed Process lifecycle into one output signal and one failure
// signal, preventing stale or duplicate callbacks when a process is stopped.
SecureProcess {
  id: root

  property bool handled: false
  property bool started: false
  property int processGeneration: 0
  property int serial: 0
  property string pendingOutput: ""
  property bool outputReady: false
  property int maxOutputBytes: 4 * 1024 * 1024
  property int outputBytes: 0
  property bool outputOverflow: false

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

  stdout: SplitParser {
    // Empty split marker exposes bounded chunks from the underlying pipe. This
    // avoids an unbounded whole-response buffer.
    splitMarker: ""
    onRead: function(data) {
      if (root.handled || root.outputOverflow) return
      var chunk = String(data || "")
      // UTF-16 length is a conservative upper bound for the UTF-8 payloads the
      // providers return; the producer enforces the exact byte ceiling too.
      var nextBytes = root.outputBytes + chunk.length * 2
      if (nextBytes > root.maxOutputBytes * 2) {
        root.outputOverflow = true
        root.pendingOutput = ""
        root.outputReady = false
        root.hardStop()
        return
      }
      root.outputBytes = nextBytes
      root.pendingOutput += chunk
      root.outputReady = true
    }
  }

  onRunningChanged: {
    if (root.running) {
      root.completionTimer.stop()
      root.pendingOutput = ""
      root.outputReady = false
      root.outputBytes = 0
      root.outputOverflow = false
      root.started = true
      root.processGeneration++
      return
    }
    if (!root.started) return
    root.started = false
    if (root.outputOverflow) {
      root.pendingOutput = ""
      root.outputReady = false
    }
    // stdout may close just before or just after Process.running changes
    // depending on the provider and Qt event ordering. Defer completion one
    // turn so a complete stdout payload always wins over empty-output fallback.
    root.completionTimer.expectedGeneration = root.processGeneration
    root.completionTimer.restart()
  }
}
