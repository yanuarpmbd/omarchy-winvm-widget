import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property int pollInterval: 4
  property string sharedFolderPath: "~/Windows"

  // Machine states: "stopped" | "starting" | "running" | "stopping"
  property string vmState: "stopped"
  property bool port3389Open: false
  property bool port8006Open: false
  property bool rdpClientRunning: false
  property int uptimeSecs: 0
  property int startingElapsedSecs: 0
  property string statusMessage: ""
  property string lastError: ""

  readonly property bool isRunning: vmState === "running"
  readonly property bool isTransitioning: vmState === "starting" || vmState === "stopping"

  function formatUptime(secs) {
    var s = secs % 60
    var m = Math.floor(secs / 60) % 60
    var h = Math.floor(secs / 3600)
    if (h > 0) return h + "h " + m + "m"
    if (m > 0) return m + "m " + s + "s"
    return s + "s"
  }

  function resolvePath(path) {
    var p = String(path || "").trim()
    if (p === "") p = "~/Windows"
    var home = Quickshell.env("HOME") || "/home/bol"
    if (p.startsWith("~/")) {
      return home + "/" + p.substring(2)
    }
    return p
  }

  function poll() {
    if (!probeProcess.running) {
      probeProcess.running = true
    }
    if (!rdpCheckProcess.running) {
      rdpCheckProcess.running = true
    }
  }

  function launcherScriptPath() {
    var url = String(Qt.resolvedUrl("winvm-launcher.sh"))
    return url.replace(/^file:\/\//, "")
  }

  function launchVm(mode) {
    lastError = ""
    var launchMode = mode || "rdp-keepalive"
    if (launchMode === "web") {
      openWebConsole()
      return
    }

    if (launchMode !== "attach") {
      root.vmState = "starting"
      root.startingElapsedSecs = 0
      root.statusMessage = "Starting Windows VM..."
    } else {
      root.statusMessage = "Attaching FreeRDP..."
    }

    var sharedFolder = resolvePath(root.sharedFolderPath)
    var storageFolder = resolvePath("~/.windows")
    Quickshell.execDetached(["chmod", "u=rwx,go=", sharedFolder, storageFolder])

    Quickshell.execDetached(["uwsm", "app", "--", launcherScriptPath(), launchMode])
    poll()
  }

  function attachRdp() {
    launchVm("attach")
  }

  function stopVm() {
    lastError = ""
    root.vmState = "stopping"
    root.statusMessage = "Stopping Windows VM..."
    Quickshell.execDetached(["omarchy-windows-vm", "stop"])
    poll()
  }

  function openWebConsole() {
    Quickshell.execDetached(["xdg-open", "http://127.0.0.1:8006"])
  }

  function openSharedFolder() {
    var fullPath = resolvePath(root.sharedFolderPath)
    Quickshell.execDetached(["chmod", "u=rwx,go=", fullPath])
    Quickshell.execDetached(["xdg-open", fullPath])
  }

  function handleProbeOutput(output) {
    var out = String(output || "")
    var has3389 = out.indexOf(":3389") !== -1
    var has8006 = out.indexOf(":8006") !== -1

    root.port3389Open = has3389
    root.port8006Open = has8006
    var isListening = has3389 || has8006

    if (isListening) {
      if (root.vmState === "starting") {
        if (root.startingElapsedSecs > 40 || root.rdpClientRunning) {
          root.vmState = "running"
          root.statusMessage = ""
        } else {
          root.statusMessage = "Booting Windows (" + root.startingElapsedSecs + "s)..."
        }
      } else {
        root.vmState = "running"
        if (root.statusMessage.indexOf("Booting") !== -1 || root.statusMessage.indexOf("Starting") !== -1) {
          root.statusMessage = ""
        }
      }
    } else {
      if (root.vmState === "starting") {
        if (root.startingElapsedSecs > 180) {
          root.vmState = "stopped"
          root.statusMessage = "Startup timed out"
        }
      } else if (root.vmState === "stopping") {
        root.vmState = "stopped"
        root.statusMessage = ""
      } else {
        root.vmState = "stopped"
        root.statusMessage = ""
      }
    }
  }

  // Fast port probing via ss
  Process {
    id: probeProcess
    command: ["ss", "-Htln", "( sport = :3389 or sport = :8006 )"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.handleProbeOutput(String(text || ""))
      }
    }
  }

  // Process probe for FreeRDP client
  Process {
    id: rdpCheckProcess
    command: ["pgrep", "-f", "xfreerdp"]
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      root.rdpClientRunning = (code === 0)
    }
  }

  // Dynamic poll timer (1s during transitions, normal interval otherwise)
  Timer {
    id: pollTimer
    interval: root.isTransitioning ? 1000 : Math.max(1000, root.pollInterval * 1000)
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.vmState === "starting") {
        root.startingElapsedSecs += Math.round(interval / 1000)
      }
      root.poll()
    }
  }

  // Uptime tracker when running
  Timer {
    id: uptimeTimer
    interval: 1000
    running: root.vmState === "running"
    repeat: true
    onTriggered: {
      root.uptimeSecs += 1
    }
  }

  onVmStateChanged: {
    if (vmState !== "running") {
      uptimeSecs = 0
    }
  }

  Component.onCompleted: {
    poll()
  }
}
