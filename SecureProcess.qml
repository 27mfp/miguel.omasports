import QtQuick
import Quickshell
import Quickshell.Io

// Every external command is launched with an explicit environment and is
// expected to become its own process-group leader (secure_io.py calls setsid).
// hardStop() therefore has a real process-group kill boundary, while signal(9)
// remains a race-safe fallback if the helper has not reached setsid yet.
Process {
  id: root

  property bool allowSessionEnvironment: false

  clearEnvironment: true
  environment: root.allowSessionEnvironment ? ({
    "HOME": String(Quickshell.env("HOME") || ""),
    "LANG": "C.UTF-8",
    "LC_ALL": "C.UTF-8",
    "XDG_RUNTIME_DIR": String(Quickshell.env("XDG_RUNTIME_DIR") || ""),
    "DBUS_SESSION_BUS_ADDRESS": String(Quickshell.env("DBUS_SESSION_BUS_ADDRESS") || ""),
    "DISPLAY": String(Quickshell.env("DISPLAY") || ""),
    "WAYLAND_DISPLAY": String(Quickshell.env("WAYLAND_DISPLAY") || "")
  }) : ({
    "LANG": "C.UTF-8",
    "LC_ALL": "C.UTF-8"
  })

  property Process groupKiller: Process {
    clearEnvironment: true
    environment: ({ "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8" })
  }

  function hardStop() {
    if (!root.running) return
    var pid = Number(root.processId || 0)
    if (pid > 1) {
      // secure_io.py calls setsid() before doing any work or exec'ing an
      // allowlisted desktop tool, so its pid is also its process-group id.
      root.groupKiller.command = ["/usr/bin/kill", "-KILL", "--", "-" + String(pid)]
      root.groupKiller.running = true
    }
    // If cancellation races the helper before setsid(), kill the leader too.
    root.signal(9)
  }
}
