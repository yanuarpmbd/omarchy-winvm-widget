#!/usr/bin/env bash
# ==============================================================================
# winvm-launcher.sh - Smart launcher wrapper for Omarchy Windows VM
# Part of bol.winvm plugin
# ==============================================================================
set -euo pipefail

MODE="${1:-rdp-keepalive}"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/winvm-freerdp.log"
mkdir -p "$(dirname "$LOG_FILE")"

# 1. Normalize directory permissions (strip setgid bit 2000 so assert_mounts_safe passes)
SHARED_DIR="${HOME}/Windows"
STORAGE_DIR="${HOME}/.windows"

mkdir -p "$SHARED_DIR" "$STORAGE_DIR"
chmod u=rwx,go= "$SHARED_DIR" "$STORAGE_DIR" 2>/dev/null || true

# Helper: check if port 3389 is accepting TCP connections
is_rdp_ready() {
  timeout 1 bash -c '</dev/tcp/127.0.0.1/3389' 2>/dev/null
}

# Helper: check if container/ports are active
is_container_running() {
  ss -Htln '( sport = :3389 or sport = :8006 )' 2>/dev/null | grep -qE ":3389|:8006"
}

# Helper: run FreeRDP client directly with full Omarchy parameters
run_freerdp() {
  local win_user="docker"
  local win_pass="admin"
  local creds_file="${HOME}/.config/windows/credentials"

  if [[ -f "$creds_file" ]]; then
    local u p
    u=$(grep -E '^USERNAME=' "$creds_file" | head -n1 | cut -d= -f2- | tr -d '\r\n')
    p=$(grep -E '^PASSWORD=' "$creds_file" | head -n1 | cut -d= -f2- | tr -d '\r\n')
    [[ -n "$u" ]] && win_user="$u"
    [[ -n "$p" ]] && win_pass="$p"
  fi

  local krb5_conf="${HOME}/.config/windows/krb5.conf"
  if [[ ! -f "$krb5_conf" ]]; then
    mkdir -p "$(dirname "$krb5_conf")"
    printf '[libdefaults]\n  dns_lookup_kdc = false\n  dns_lookup_realm = false\n' >"$krb5_conf"
  fi
  export KRB5_CONFIG="$krb5_conf"

  local rdp_scale=""
  local hypr_scale
  hypr_scale=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select (.focused == true) | .scale' 2>/dev/null || echo "1")
  local scale_percent
  scale_percent=$(echo "$hypr_scale" | awk '{print int($1 * 100)}')
  if ((scale_percent >= 170)); then
    rdp_scale="/scale:180"
  elif ((scale_percent >= 130)); then
    rdp_scale="/scale:140"
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching xfreerdp3 for user '$win_user'..." >> "$LOG_FILE"
  xfreerdp3 /u:"$win_user" /p:"$win_pass" /v:127.0.0.1:3389 \
    -grab-keyboard /sound /microphone /clipboard /cert:ignore \
    /title:"Windows VM - Omarchy" /dynamic-resolution /gfx:AVC444 \
    /floatbar:sticky:off,default:visible,show:fullscreen \
    $rdp_scale >> "$LOG_FILE" 2>&1
}

case "$MODE" in
  web)
    xdg-open "http://127.0.0.1:8006" &
    exit 0
    ;;

  attach)
    # Direct connect to an already running VM
    if ! is_container_running; then
      notify-send -u normal "Windows VM" "VM is not running. Starting..."
      exec "$0" rdp-keepalive
    fi

    # Wait briefly if port 3389 isn't ready yet
    for _ in {1..10}; do
      if is_rdp_ready; then
        break
      fi
      sleep 1
    done

    run_freerdp
    exit 0
    ;;

  rdp-autostop)
    # User explicitly wants VM to stop when RDP session ends
    omarchy-windows-vm launch >> "$LOG_FILE" 2>&1
    exit 0
    ;;

  rdp-keepalive|*)
    # Default recommended mode: Keep container running across disconnects
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Windows VM with keep-alive..." >> "$LOG_FILE"
    
    # Check if VM is already running
    if ! is_container_running; then
      # Start VM container via standard omarchy-windows-vm launch -k
      omarchy-windows-vm launch -k >> "$LOG_FILE" 2>&1 &
      launcher_pid=$!

      # Wait for RDP port readiness (up to 90 seconds for fresh boot)
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for RDP port 3389 readiness..." >> "$LOG_FILE"
      rdp_connected=false
      for i in $(seq 1 45); do
        # Check if FreeRDP client already successfully spawned
        if pgrep -f "xfreerdp" >/dev/null 2>&1; then
          rdp_connected=true
          break
        fi

        if is_rdp_ready; then
          # Port is responding to TCP! Launch FreeRDP if omarchy-windows-vm didn't or exited
          sleep 1
          if ! pgrep -f "xfreerdp" >/dev/null 2>&1; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Port 3389 ready, attaching FreeRDP..." >> "$LOG_FILE"
            run_freerdp &
            rdp_connected=true
            break
          fi
        fi
        sleep 2
      done

      if [[ "$rdp_connected" != "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Startup wait completed, attempting final FreeRDP connection..." >> "$LOG_FILE"
        run_freerdp || true
      fi

      wait "$launcher_pid" 2>/dev/null || true
    else
      # Container is already running, just connect FreeRDP
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container already running, connecting FreeRDP..." >> "$LOG_FILE"
      for _ in {1..5}; do
        if is_rdp_ready; then
          break
        fi
        sleep 1
      done
      run_freerdp
    fi
    ;;
esac
