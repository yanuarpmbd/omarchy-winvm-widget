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

  readonly property real openPanelIndicatorWidth: button.slotSize
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
      s += "Click: Windows VM Controls"
    } else if (winVm.vmState === "starting") {
      s += "Starting up...\nWaiting for KVM / Docker ports"
    } else if (winVm.vmState === "stopping") {
      s += "Stopping container..."
    } else {
      s += "Stopped\nClick to open controls or launch"
    }
    return s
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.buildTooltip()

    onPressed: function(b) {
      root.togglePanel()
    }

    iconComponent: Component {
      Item {
        anchors.fill: parent

        Text {
          id: winIcon
          anchors.centerIn: parent
          text: "󰍲"
          font.family: button.fontFamily
          font.pixelSize: button.fontSize
          renderType: Text.NativeRendering
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
      }
    }
  }
}
