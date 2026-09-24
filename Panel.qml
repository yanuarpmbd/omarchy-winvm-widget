import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "bol.winvm"
  ipcTarget: "bol.winvm"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property color contentUrgent: bar ? bar.urgent : Color.urgent
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(contentForeground, 1.45)

  function open() {
    if (root.service) root.service.poll()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
      keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // Traverses the bar window scene graph to collect all active clickable targets (e.g.
  // Bluetooth, Wi-Fi, Audio buttons). This bridges the gap for third-party plugins where
  // PluginBarApi.clickTargets is scoped only to this plugin, allowing seamless 1-click switching.
  function getBarClickTargets() {
    var win = root.anchorItem ? (root.anchorItem.QsWindow ? root.anchorItem.QsWindow.window : null) : null
    if (!win || !win.contentItem) {
      return (root.bar && root.bar.clickTargets) ? root.bar.clickTargets : []
    }
    var targets = []
    function walk(item) {
      if (!item) return
      if (typeof item.triggerPress === "function" && item.visible !== false && item.opacity > 0) {
        targets.push(item)
      }
      var children = item.children
      if (children && children.length) {
        for (var i = 0; i < children.length; i++) {
          walk(children[i])
        }
      }
    }
    try {
      walk(win.contentItem)
    } catch (e) {
      // Ignore traversal error and fall back
    }
    return targets.length > 0 ? targets : ((root.bar && root.bar.clickTargets) ? root.bar.clickTargets : [])
  }

  QtObject {
    id: barProxy

    readonly property color foreground: root.bar ? root.bar.foreground : "transparent"
    readonly property color barForeground: root.bar ? root.bar.barForeground : "transparent"
    readonly property color background: root.bar ? root.bar.background : "transparent"
    readonly property color urgent: root.bar ? root.bar.urgent : "transparent"
    readonly property string fontFamily: root.bar ? root.bar.fontFamily : ""
    readonly property string position: root.bar ? root.bar.position : "top"
    readonly property bool vertical: root.bar ? root.bar.vertical : false
    readonly property int barSize: root.bar ? root.bar.barSize : 0
    readonly property var activePopout: root.bar ? root.bar.activePopout : null

    readonly property var clickTargets: {
      if (root.opened) {} // refresh whenever panel opens
      return root.getBarClickTargets()
    }

    function targetBelongsToWindow(target, window) {
      if (root.bar && typeof root.bar.targetBelongsToWindow === "function") {
        return root.bar.targetBelongsToWindow(target, window)
      }
      return !!target && !!window && target.QsWindow && target.QsWindow.window === window
    }

    function requestPopout(owner) {
      if (root.bar && typeof root.bar.requestPopout === "function") {
        root.bar.requestPopout(owner)
      }
    }

    function releasePopout(owner) {
      if (root.bar && typeof root.bar.releasePopout === "function") {
        root.bar.releasePopout(owner)
      }
    }

    function switchPanelFrom(owner, direction) {
      if (root.bar && typeof root.bar.switchPanelFrom === "function") {
        return root.bar.switchPanelFrom(owner, direction)
      }
      return false
    }

    function setCenterHoverRevealSuppressed(value) {
      if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function") {
        root.bar.setCenterHoverRevealSuppressed(value)
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: barProxy
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(16))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") { if (root.service) root.service.poll() }
        else if (t === "l" || t === "L") {
          if (root.service) {
            if (root.service.vmState === "running") {
              root.service.attachRdp()
            } else {
              root.service.launchVm("rdp-keepalive")
            }
            root.close()
          }
        }
        else if (t === "a" || t === "A") { if (root.service) { root.service.launchVm("rdp-autostop"); root.close() } }
        else if (t === "w" || t === "W") { if (root.service) { root.service.openWebConsole(); root.close() } }
        else if (t === "f" || t === "F") { if (root.service) { root.service.openSharedFolder(); root.close() } }
        else if (t === "s" || t === "S") { if (root.service) root.service.stopVm() }
      }

      Column {
        id: mainColumn
        width: parent.width
        spacing: Style.space(12)

        // 1. Header Card
        Row {
          width: parent.width
          spacing: Style.space(12)

          // Windows Icon
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍲"
            color: {
              if (!root.service) return root.dim
              if (root.service.vmState === "running") return Color.accent
              if (root.service.vmState === "starting") return Color.accent
              if (root.service.vmState === "stopping") return root.contentUrgent
              return root.dim
            }
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.display
          }

          // Title & Subtitle
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(140)
            spacing: Style.space(2)

            Text {
              text: "Windows VM"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: {
                if (!root.service) return "Stopped"
                if (root.service.vmState === "running") {
                  var up = root.service.uptimeSecs > 0 ? " • " + root.service.formatUptime(root.service.uptimeSecs) : ""
                  return (root.service.rdpClientRunning ? "RDP Attached" : "Running") + up
                }
                if (root.service.vmState === "starting") return "Starting container..."
                if (root.service.vmState === "stopping") return "Stopping container..."
                return "Stopped"
              }
              color: root.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          // Status Badge Pill
          BorderSurface {
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Style.space(26)
            implicitWidth: statusRow.implicitWidth + Style.space(16)
            color: "transparent"
            borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)
            radius: Style.cornerRadius

            Row {
              id: statusRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(8)
                height: Style.space(8)
                radius: Style.space(4)
                color: {
                  if (!root.service) return "#7f8c8d"
                  if (root.service.vmState === "running") return "#2ecc71"
                  if (root.service.vmState === "starting" || root.service.vmState === "stopping") return "#f39c12"
                  return "#7f8c8d"
                }

                SequentialAnimation on opacity {
                  running: root.service && root.service.isTransitioning
                  loops: Animation.Infinite
                  NumberAnimation { from: 1.0; to: 0.2; duration: 500 }
                  NumberAnimation { from: 0.2; to: 1.0; duration: 500 }
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  if (!root.service) return "OFF"
                  if (root.service.vmState === "running") return "RUNNING"
                  if (root.service.vmState === "starting") return "BOOTING"
                  if (root.service.vmState === "stopping") return "STOPPING"
                  return "STOPPED"
                }
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        // Status message notification banner if active
        BorderSurface {
          visible: root.service && root.service.statusMessage !== ""
          width: parent.width
          implicitHeight: Style.space(32)
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
          borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)
          radius: Style.cornerRadius

          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              text: "⠋"
              color: Color.accent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              visible: root.service && root.service.isTransitioning
              RotationAnimation on rotation {
                from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                running: root.service && root.service.isTransitioning
              }
            }

            Text {
              text: root.service ? root.service.statusMessage : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // 2. Connectivity / Endpoints Card
        BorderSurface {
          width: parent.width
          implicitHeight: endpointsColumn.implicitHeight + Style.space(16)
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
          borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)
          radius: Style.cornerRadius

          Column {
            id: endpointsColumn
            width: parent.width - Style.space(24)
            anchors.centerIn: parent
            spacing: Style.space(8)

            // RDP Port
            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍲"
                color: (root.service && root.service.port3389Open) ? Color.accent : root.dim
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "RDP Protocol (Port 3389)"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                width: parent.width - Style.space(18) - Style.space(8) - rdpStatusText.implicitWidth
              }

              Text {
                id: rdpStatusText
                anchors.verticalCenter: parent.verticalCenter
                text: (root.service && root.service.port3389Open) ? "● Active" : "○ Offline"
                color: (root.service && root.service.port3389Open) ? "#2ecc71" : root.dim
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            // Web Console
            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰖟"
                color: (root.service && root.service.port8006Open) ? Color.accent : root.dim
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Web Console (Port 8006)"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                width: parent.width - Style.space(18) - Style.space(8) - webStatusText.implicitWidth
              }

              Text {
                id: webStatusText
                anchors.verticalCenter: parent.verticalCenter
                text: (root.service && root.service.port8006Open) ? "● Active" : "○ Offline"
                color: (root.service && root.service.port8006Open) ? "#2ecc71" : root.dim
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            // Active Client Session
            Row {
              visible: root.service && root.service.rdpClientRunning
              width: parent.width
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰹑"
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "FreeRDP Client Attached"
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        // 3. System Resources & Allocation Card
        BorderSurface {
          width: parent.width
          implicitHeight: resourcesColumn.implicitHeight + Style.space(16)
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
          borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)
          radius: Style.cornerRadius

          Column {
            id: resourcesColumn
            width: parent.width - Style.space(24)
            anchors.centerIn: parent
            spacing: Style.space(8)

            // Section Header
            Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: (root.service && root.service.isRunning) ? "RESOURCE USAGE (LIVE)" : "RESOURCE ALLOCATION (STANDBY)"
                color: root.dim
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.8
              }
            }

            // Processor (CPU)
            Column {
              width: parent.width
              spacing: Style.space(3)

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰻠"
                  color: Color.accent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  width: Style.space(18)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: (root.service && root.service.isRunning)
                    ? ("Processor (" + (root.service.allocatedCores || 4) + " vCPU)")
                    : "CPU Cores Allocation"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  width: parent.width - Style.space(18) - Style.space(8) - cpuValueText.implicitWidth
                }

                Text {
                  id: cpuValueText
                  anchors.verticalCenter: parent.verticalCenter
                  text: (root.service && root.service.isRunning)
                    ? ((root.service.cpuUsagePct > 0 ? root.service.cpuUsagePct.toFixed(1) : "0.0") + "%")
                    : ((root.service ? root.service.allocatedCores : 4) + " Cores")
                  color: (root.service && root.service.isRunning) ? Color.accent : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              // Progress bar when running
              Rectangle {
                visible: root.service && root.service.isRunning
                width: parent.width
                height: Style.space(3)
                radius: Style.space(1.5)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)

                Rectangle {
                  width: parent.width * Math.min(1.0, Math.max(0.0, (root.service ? root.service.cpuUsagePct : 0) / 100))
                  height: parent.height
                  radius: parent.radius
                  color: (root.service && root.service.cpuUsagePct > 80) ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent
                }
              }
            }

            // Memory (RAM)
            Column {
              width: parent.width
              spacing: Style.space(3)

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰍛"
                  color: Color.accent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  width: Style.space(18)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: (root.service && root.service.isRunning)
                    ? ("Memory (" + (root.service.allocatedRam || "8 GB") + ")")
                    : "RAM Allocation"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  width: parent.width - Style.space(18) - Style.space(8) - memValueText.implicitWidth
                }

                Text {
                  id: memValueText
                  anchors.verticalCenter: parent.verticalCenter
                  text: (root.service && root.service.isRunning)
                    ? ((root.service.memUsageGb > 0 ? root.service.memUsageGb.toFixed(1) + " GB" : "0 GB") +
                       (root.service.memUsagePct > 0 ? (" (" + root.service.memUsagePct.toFixed(0) + "%)") : ""))
                    : ((root.service ? root.service.allocatedRam : "8 GB") + " RAM")
                  color: (root.service && root.service.isRunning) ? Color.accent : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              // Progress bar when running
              Rectangle {
                visible: root.service && root.service.isRunning
                width: parent.width
                height: Style.space(3)
                radius: Style.space(1.5)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)

                Rectangle {
                  width: parent.width * Math.min(1.0, Math.max(0.0, (root.service ? root.service.memUsagePct : 0) / 100))
                  height: parent.height
                  radius: parent.radius
                  color: (root.service && root.service.memUsagePct > 85) ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent
                }
              }
            }

            // Storage (Virtual Disk)
            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰋊"
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.service && root.service.isRunning)
                  ? ("Virtual Disk (" + (root.service.allocatedDisk || "128 GB") + ")")
                  : "Virtual Disk Allocation"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                width: parent.width - Style.space(18) - Style.space(8) - diskValueText.implicitWidth
              }

              Text {
                id: diskValueText
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  var host = root.service ? root.service.hostDiskUsage : "0 GB"
                  if (root.service && root.service.isRunning) {
                    return host + " on host"
                  } else {
                    var alloc = root.service ? root.service.allocatedDisk : "128 GB"
                    return alloc + (host !== "0 GB" ? (" (" + host + " host)") : "")
                  }
                }
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        // 4. Actions Section
        Text {
          text: "QUICK ACTIONS"
          color: root.dim
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.1
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          // When stopped: Launch Windows VM (Keep-Alive)
          Button {
            visible: root.service && root.service.vmState === "stopped"
            width: parent.width
            text: "Launch Windows VM [L]"
            iconText: "󰍲"
            tooltipText: "Start Windows VM and connect FreeRDP (stays running in background)"
            leftAlign: true
            bordered: true
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            onClicked: {
              if (root.service) root.service.launchVm("rdp-keepalive")
              root.close()
            }
          }

          // When running and RDP client not attached: Attach FreeRDP
          Button {
            visible: root.service && root.service.vmState === "running" && !root.service.rdpClientRunning
            width: parent.width
            text: "Attach FreeRDP [L]"
            iconText: "󰍲"
            tooltipText: "Connect FreeRDP window to the active Windows VM"
            leftAlign: true
            bordered: true
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            onClicked: {
              if (root.service) root.service.attachRdp()
              root.close()
            }
          }

          Button {
            width: parent.width
            text: "Open Web Console [W]"
            iconText: "󰖟"
            tooltipText: "Open http://127.0.0.1:8006 in default browser"
            leftAlign: true
            bordered: true
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            onClicked: {
              if (root.service) root.service.openWebConsole()
              root.close()
            }
          }

          Button {
            width: parent.width
            text: "Open Shared Folder [F]"
            iconText: "󰉋"
            tooltipText: "Open ~/Windows shared folder in file manager"
            leftAlign: true
            bordered: true
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            onClicked: {
              if (root.service) root.service.openSharedFolder()
              root.close()
            }
          }

          Button {
            visible: root.service && root.service.vmState === "stopped"
            width: parent.width
            text: "Launch (Auto-Stop on Close) [A]"
            iconText: "󱐋"
            tooltipText: "Start Windows VM and auto-terminate container when FreeRDP closes"
            leftAlign: true
            bordered: true
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            onClicked: {
              if (root.service) root.service.launchVm("rdp-autostop")
              root.close()
            }
          }

          Button {
            visible: root.service && (root.service.vmState === "running" || root.service.vmState === "starting")
            width: parent.width
            text: "Stop VM / Shut Down [S]"
            iconText: "󰐥"
            tooltipText: "Gracefully shut down Windows VM container"
            leftAlign: true
            bordered: true
            foreground: root.contentUrgent
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            onClicked: {
              if (root.service) root.service.stopVm()
            }
          }
        }
      }
    }
  }
}
