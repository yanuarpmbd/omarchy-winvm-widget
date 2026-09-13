import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "bol.winvm"

  readonly property bool autoHide: Boolean(setting("autoHide", false))
  readonly property int pollInterval: Number(setting("pollInterval", 4))
  readonly property string defaultLaunchMode: String(setting("defaultLaunchMode", "rdp"))
  readonly property string sharedFolderPath: String(setting("sharedFolderPath", "~/Windows"))

  WinVmService {
    id: winVm
    pollInterval: root.pollInterval
    sharedFolderPath: root.sharedFolderPath
  }

  // Panel coordination
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = winVm
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // CLI / Shell IPC interface
  IpcHandler {
    target: "bol.winvm"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function launch(mode: string): void { winVm.launchVm(mode || root.defaultLaunchMode) }
    function stop(): void { winVm.stopVm() }
    function status(): string { return winVm.vmState }
    function refresh(): void { winVm.poll() }
  }

  visible: autoHide ? (winVm.vmState !== "stopped") : true
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0
  width: implicitWidth
  height: implicitHeight

  function buildTooltip() {
    var s = "Windows VM: "
    if (winVm.vmState === "running") {
      s += "Running (" + winVm.formatUptime(winVm.uptimeSecs) + ")\n"
      s += "RDP (Port 3389): " + (winVm.port3389Open ? "Active" : "Inactive") + "\n"
      s += "Web (Port 8006): " + (winVm.port8006Open ? "Active" : "Inactive") + "\n"
      s += "Client: " + (winVm.rdpClientRunning ? "Connected" : "Disconnected") + "\n"
      s += "Left-click: Controls | Right-click: Controls"
    } else if (winVm.vmState === "starting") {
      s += "Starting up...\nWaiting for KVM / Docker ports"
    } else if (winVm.vmState === "stopping") {
      s += "Stopping container..."
    } else {
      s += "Stopped\nClick to launch or open controls"
    }
    return s
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    visible: root.visible
    hasVisualContent: root.visible
    keepSpace: false
    tooltipText: root.buildTooltip()

    fixedWidth: root.visible ? (root.vertical ? root.barSize : (contentRow.implicitWidth + scaledHorizontalMargin * 2)) : 0
    fixedHeight: root.visible ? (root.vertical ? (contentRow.implicitHeight + scaledVerticalPadding * 2) : root.barSize) : 0

    onPressed: function(b) {
      root.togglePanel()
    }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(5)
      visible: root.visible

      Text {
        id: winIcon
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍲"
        font.family: button.fontFamily
        font.pixelSize: Style.font.body
        color: {
          if (winVm.vmState === "running") return Color.accent
          if (winVm.vmState === "starting") return Color.accent
          if (winVm.vmState === "stopping") return (root.bar ? root.bar.urgent : Color.urgent)
          return Color.muted
        }

        SequentialAnimation on opacity {
          running: winVm.isTransitioning
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
          NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
        }
      }

      Text {
        id: winLabel
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.vertical
        text: {
          if (winVm.vmState === "running") {
            return winVm.rdpClientRunning ? "WIN (RDP)" : "WIN"
          }
          if (winVm.vmState === "starting") return "BOOT…"
          if (winVm.vmState === "stopping") return "STOP…"
          return "WIN"
        }
        color: winVm.vmState === "running" ? button.foreground : Color.muted
        font.family: button.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: winVm.vmState === "running"
        renderType: Text.NativeRendering
      }

      Rectangle {
        visible: winVm.vmState === "running"
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(4)
        height: Style.space(4)
        radius: Style.space(2)
        color: winVm.rdpClientRunning ? Color.accent : (root.bar ? root.bar.barForeground : Color.foreground)
      }
    }
  }
}
