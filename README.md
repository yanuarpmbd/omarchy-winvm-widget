# Omarchy Windows VM Widget (`bol.winvm`)

A native Quickshell status bar widget and popover control panel for managing, launching, and monitoring containerized Windows VMs on **Omarchy Linux** (`omarchy-shell`).

---

## Features

- 󰍲 **Minimalist Bar Indicator**: Renders a clean Windows icon (`󰍲`) that seamlessly matches Omarchy's icon design:
  - **Stopped**: Subtle muted icon.
  - **Starting / Transitioning**: Pulsing theme accent animation during boot and service discovery.
  - **Running**: Solid theme accent icon.
  - **Stopping**: Urgent amber pulsing feedback during container shutdown.
- 💬 **Live Status Tooltip**: Hovering over the bar icon reveals:
  - VM state and uptime (hours, minutes, seconds).
  - RDP port (`3389`) status.
  - Web console port (`8006`) status.
  - Active FreeRDP client connection status.
- ⚡ **Zero-Privilege Probing**: Uses lightweight local socket and port querying (`ss -Htln`) to detect VM state without recurring polkit password prompts.
- 🛡️ **Smart Launcher & Keep-Alive Reliability (`winvm-launcher.sh`)**:
  - Automatically fixes directory permissions (`chmod 0700` and strips setgid bit `chmod a-s,u=rwx,go=` on `~/Windows` and `~/.windows`) to satisfy Omarchy mount security assertions.
  - FreeRDP connection retry loop (up to 12 attempts every 3 seconds) that waits for Windows TLS/NLA and TermService initialization without dropping the session.
  - Keep-alive mode (`-k`) ensures closing the FreeRDP window does not terminate the background container.
- 🖥️ **Instant Launch Modes**:
  - **FreeRDP Standard**: Launches fullscreen RDP session and automatically stops the VM container when the session window is closed.
  - **FreeRDP Keep-Alive (`-k`)**: Leaves the VM running in the background when RDP disconnects.
  - **Web Console**: Direct 1-click access to the browser console (`http://127.0.0.1:8006`).
- 📁 **Shared Folder Shortcut**: Quick access to open the host shared directory (`~/Windows`) in your default file manager.
- ⌨️ **Keyboard Friendly**: Fast navigation with single-key shortcuts when the panel is focused (`L`, `K`, `W`, `F`, `S`, `R`, `Esc`).
- 📡 **Quickshell IPC Integration**: Fully scriptable via `quickshell ipc` for external keybindings and automation.

---

## Prerequisites

Before using this widget, make sure the following are installed and configured on your Omarchy system:
- **Omarchy Shell** (`omarchy-shell` / Quickshell desktop)
- **Omarchy Windows VM** (`omarchy-windows-vm` backed by `dockurr/windows`)
- **FreeRDP** (`xfreerdp`)

---

## Installation

### Via Omarchy CLI (Remote Git Repository)
```bash
omarchy plugin add https://github.com/yanuarpmbd/omarchy-winvm-widget.git --enable
omarchy bar move bol.winvm --section right
```

### Local Development / Manual Install
Clone or open this repository, then run the installation script:
```bash
./install.sh
```

This will:
1. Validate the plugin against the Omarchy plugin manifest schema (`omarchy plugin validate`).
2. Verify all QML files with `qmllint`.
3. Install files to `~/.config/omarchy/plugins/bol.winvm/`.
4. Enable the widget in the right section of your top bar.
5. Restart the Omarchy shell to activate the widget immediately.

---

## Uninstallation

### Via Omarchy CLI
```bash
omarchy plugin remove bol.winvm
```

### Via Local Script
```bash
./uninstall.sh
```

---

## Panel Keyboard Shortcuts

When the Windows VM panel popover is open, you can use the following keys:

| Key | Action |
|---|---|
| <kbd>L</kbd> | Launch FreeRDP (auto-stop on window close) |
| <kbd>K</kbd> | FreeRDP Keep-Alive (keeps VM running in background) |
| <kbd>W</kbd> | Open Web Console in default browser |
| <kbd>F</kbd> | Open Shared Folder (`~/Windows`) |
| <kbd>S</kbd> | Stop / Gracefully shut down VM container |
| <kbd>R</kbd> | Force status & port refresh |
| <kbd>Esc</kbd> | Close panel popover |

---

## IPC Command Interface

You can control and query the widget from bash scripts, terminal commands, or Hyprland keybindings via Quickshell IPC:

```bash
# Toggle control panel
quickshell ipc -p /usr/share/omarchy/shell/shell.qml call bol.winvm toggle

# Open / close control panel
quickshell ipc -p /usr/share/omarchy/shell/shell.qml call bol.winvm open
quickshell ipc -p /usr/share/omarchy/shell/shell.qml call bol.winvm close

# Query current VM state (outputs: stopped, starting, running, stopping)
quickshell ipc -p /usr/share/omarchy/shell/shell.qml call bol.winvm status

# Launch VM with default or specified mode (rdp-keepalive, rdp, or web)
quickshell ipc -p /usr/share/omarchy/shell/shell.qml call bol.winvm launch rdp-keepalive

# Stop VM container gracefully
quickshell ipc -p /usr/share/omarchy/shell/shell.qml call bol.winvm stop

# Force refresh status
quickshell ipc -p /usr/share/omarchy/shell/shell.qml call bol.winvm refresh
```

---

## Configuration

Settings can be customized in your Omarchy shell configuration (`~/.config/omarchy/shell.json`) or via the plugin settings UI:

| Setting | Type | Default | Description |
|---|---|---|---|
| `autoHide` | boolean | `false` | Hide widget from the bar when VM is stopped |
| `pollInterval` | number | `4` | Status check interval in seconds |
| `defaultLaunchMode` | string | `"rdp-keepalive"` | Default launch mode (`"rdp-keepalive"`, `"rdp"`, or `"web"`) |
| `sharedFolderPath` | string | `"~/Windows"` | Host folder path mounted into Windows VM |

---

## Optional: Hyprland Window Rules

To optimize your FreeRDP experience with Hyprland on Omarchy, you can add window rules to `~/.config/hypr/hyprland.conf`:

```ini
windowrulev2 = workspace 9, class:^(xfreerdp)$, title:^(Windows VM - Omarchy)$
windowrulev2 = fullscreen, class:^(xfreerdp)$, title:^(Windows VM - Omarchy)$
```

---

## License

MIT License
