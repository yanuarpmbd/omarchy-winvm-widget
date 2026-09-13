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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
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
        else if (t === "l" || t === "L") { if (root.service) { root.service.launchVm("rdp"); root.close() } }
        else if (t === "k" || t === "K") { if (root.service) { root.service.launchVm("rdp-keepalive"); root.close() } }
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

        // 3. Actions Section
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

          Button {
            width: parent.width
            text: "Launch FreeRDP [L]"
            iconText: "󰍲"
            tooltipText: "Start Windows VM & connect via FreeRDP (auto-stops on window close)"
            leftAlign: true
            bordered: true
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            onClicked: {
              if (root.service) root.service.launchVm("rdp")
              root.close()
            }
          }

          Button {
            width: parent.width
            text: "FreeRDP Keep-Alive [K]"
            iconText: "󱐋"
            tooltipText: "Launch FreeRDP and keep VM running in background when closed (-k)"
            leftAlign: true
            bordered: true
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
            onClicked: {
              if (root.service) root.service.launchVm("rdp-keepalive")
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
