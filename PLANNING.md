# Architectural Plan & Specification: Omarchy Windows VM Widget (`bol.winvm`)

A native Quickshell bar widget and control panel for managing, launching, and monitoring the Windows VM on **Omarchy Quattro** (`omarchy-shell`).

---

## 1. Overview & Objectives

Omarchy comes with a built-in containerized KVM Windows solution managed by `/usr/bin/omarchy-windows-vm`. While robust in the terminal, it currently lacks a real-time status indicator and quick GUI launcher on the top bar.

**Goal:** Create a first-class Omarchy Quickshell plugin (`bol.winvm`) that:
1. Displays real-time VM state on the top bar (Stopped, Booting, Running, Stopping).
2. Provides instant 1-click launch / connect via FreeRDP 3 (`xfreerdp3`) or Web Viewer (`:8006`).
3. Offers a rich Quickshell popup panel for power controls, port status, and quick access to shared folders.
4. Operates with zero privilege friction (fast unprivileged port/socket probing for status checks so polkit prompts only appear on actual VM start/stop if needed).

---

## 2. Directory & File Structure

```
~/Projects/omarchy-winvm-widget/
├── manifest.json            # Omarchy plugin manifest (v1 schema, bar-widget)
├── BarWidget.qml            # Status bar pill & icon indicator
├── Panel.qml                # Popover drawer / control card (anchored to bar)
├── WinVmService.qml         # Asynchronous state engine & Process execution
├── install.sh               # Automated validation, file sync, & shell reload
├── uninstall.sh             # Clean uninstallation & shell cleanup
├── README.md                # Documentation & configuration guide
└── PLANNING.md              # This blueprint document
```

---

## 3. Component Architecture & Blueprint

### A. Manifest (`manifest.json`)
* **ID:** `bol.winvm`
* **Name:** `Windows VM Manager`
* **Kinds:** `["bar-widget"]`
* **Default Section:** `right`
* **Configurable Settings Schema:**
  - `autoHide`: Boolean (default `false`) - hide from bar when VM is stopped.
  - `pollInterval`: Number (default `4`) - status check interval in seconds.
  - `defaultLaunchMode`: String (default `"rdp"`) - `"rdp"` (fullscreen, auto-stop on exit), `"rdp-keepalive"` (`-k`), or `"web"` (browser viewer).
  - `sharedFolderPath`: String (default `"~/Windows"`) - path opened by "Open Shared Folder".

---

### B. State Engine (`WinVmService.qml`)

#### Zero-Privilege Status Detection:
`omarchy-windows-vm` delegates to `dockurr/windows` via Docker. To prevent repeated polkit prompts during background polling:
1. **Primary Probe (Fast & Unprivileged):**
   - Probe open local ports using `ss -Htl '( sport = :3389 or sport = :8006 )'`.
   - If port 3389 or 8006 is listening, state is **`running`**.
2. **Process Probe:**
   - Detect running `xfreerdp` client to know if an active GUI session is attached.
3. **Transition Management:**
   - When user clicks **Start**: state immediately transitions to `starting` (spins animation, polls every 1s until ports open).
   - When user clicks **Stop**: state transitions to `stopping`.
   - Actions execute `omarchy-windows-vm launch [args]` or `omarchy-windows-vm stop` via `Quickshell.Io.Process`.

#### State Machine:
* `stopped` (gray / muted Windows icon)
* `starting` (accent pulsating / braille spinner)
* `running` (vibrant Windows blue / theme accent, RDP indicator)
* `stopping` (amber spinner)

---

### C. Bar Component (`BarWidget.qml`)

* **Visual Elements:**
  - Status Icon: Windows logo (`󰍲` / `󰘚`).
  - Optional Compact Label: `"WIN"` or `"OFF"` / `"RUN"`.
  - Accent Indicator: Omarchy theme accent line when running.
* **Interactivity:**
  - **Left-Click:**
    - If `stopped`: Toggle panel OR directly launch (configurable).
    - If `running`: Toggle `Panel.qml` popover.
  - **Right-Click:** Always toggle `Panel.qml` popover.
  - **Tooltip:** Real-time state summary, RDP status, and click hints.
* **Popout Coordination:**
  - Uses `panelLoader` pattern (identical to `hijri-calendar`) to cleanly anchor the panel to the bar slot.

---

### D. Popover Panel (`Panel.qml`)

Follows standard `qs.Ui.Panel` guidelines:
1. **Header Card:**
   - Title: `Windows VM` with version tag.
   - Status Badge with colored dot: `Running (Uptime)` or `Stopped`.
2. **Connectivity / Endpoints Info:**
   - `RDP Port: 3389` (Active / Inactive indicator)
   - `Web Console: http://127.0.0.1:8006`
3. **Action Grid / List:**
   - **🖥️ Launch FreeRDP:** Runs `omarchy-windows-vm launch` (auto-stops on window close).
   - **⚡ FreeRDP (Keep-Alive):** Runs `omarchy-windows-vm launch -k` (keeps VM running in background).
   - **🌐 Open Web Console:** Opens default browser to `http://127.0.0.1:8006`.
   - **📁 Open Shared Folder:** Invokes `xdg-open "$HOME/Windows"`.
   - **⏹️ Stop VM / Shut Down:** Invokes `omarchy-windows-vm stop`.

---

### E. Installer & Lifecyle Scripts (`install.sh`, `uninstall.sh`)

* **`install.sh`**:
  1. Validates plugin with `omarchy plugin validate .`.
  2. Creates directory `~/.config/omarchy/plugins/bol.winvm/`.
  3. Copies manifest, QML files, and assets.
  4. Triggers `omarchy-shell shell rescanPlugins`.
  5. Enables plugin via `omarchy plugin enable bol.winvm --section right`.
  6. Restarts shell via `omarchy restart shell`.
* **`uninstall.sh`**:
  1. Disables plugin with `omarchy plugin remove bol.winvm --yes`.
  2. Deletes `~/.config/omarchy/plugins/bol.winvm`.
  3. Restarts shell cleanly.

---

## 4. Hyprland Window Rules (Optional Workflow Enhancement)

To make FreeRDP feel like a seamless subsystem:
```ini
# Add to ~/.config/hypr/hyprland.conf or omarchy user rules:
# Window rule to float or assign Windows VM RDP to Workspace 9
windowrulev2 = workspace 9, class:^(xfreerdp)$, title:^(Windows VM - Omarchy)$
windowrulev2 = fullscreen, class:^(xfreerdp)$, title:^(Windows VM - Omarchy)$
```

---

## 5. Execution Steps Checklist

- [ ] **Step 1: Manifest Definition** - Write `manifest.json` with schema options.
- [ ] **Step 2: Service Engine** - Implement `WinVmService.qml` with unprivileged port probe and process runners.
- [ ] **Step 3: Bar Indicator** - Implement `BarWidget.qml` with dynamic styling, tooltips, and loader.
- [ ] **Step 4: Popover Panel** - Implement `Panel.qml` with status pills, action buttons, and Omarchy design tokens (`Style`, `Color`).
- [ ] **Step 5: Shell Scripts** - Create executable `install.sh` and `uninstall.sh`.
- [ ] **Step 6: Documentation** - Write `README.md` with usage instructions and screenshot placeholders.
- [ ] **Step 7: Testing** - Run `./install.sh`, test start/stop lifecycle, verify RDP connection and panel auto-dismissal.
