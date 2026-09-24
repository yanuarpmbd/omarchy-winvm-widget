#!/usr/bin/env bash
# ==============================================================================
# winvm-launcher.sh - Smart launcher wrapper for Omarchy Windows VM
# Part of io.github.yanuarpmbd.winvm plugin
# ==============================================================================
set -euo pipefail

MODE="${1:-rdp-keepalive}"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/winvm-freerdp.log"
mkdir -p "$(dirname "$LOG_FILE")"

# 1. Normalize directory permissions (ensure 700 and strip setgid bit a-s)
SHARED_DIR="${HOME}/Windows"
STORAGE_DIR="${HOME}/.windows"

mkdir -p "$SHARED_DIR" "$STORAGE_DIR"
chmod 00700 "$SHARED_DIR" "$STORAGE_DIR" 2>/dev/null || true
chmod a-s,u=rwx,go= "$SHARED_DIR" "$STORAGE_DIR" 2>/dev/null || true

# Helper: check if container is listening on ports
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

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing xfreerdp3 (user: $win_user)..." >> "$LOG_FILE"
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
    if ! is_container_running; then
      notify-send -u normal "Windows VM" "Starting Windows VM..."
      exec "$0" rdp-keepalive
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attaching FreeRDP to running VM..." >> "$LOG_FILE"
    run_freerdp
    exit 0
    ;;

  rdp-autostop)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Windows VM (auto-stop mode)..." >> "$LOG_FILE"
    if ! is_container_running; then
      omarchy-windows-vm launch -k >> "$LOG_FILE" 2>&1 || true
    fi

    if ! pgrep -f "xfreerdp" >/dev/null 2>&1; then
      for attempt in {1..10}; do
        if ! is_container_running; then break; fi
        if run_freerdp; then break; fi
        sleep 3
      done
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FreeRDP finished in auto-stop mode, stopping VM..." >> "$LOG_FILE"
    omarchy-windows-vm stop >> "$LOG_FILE" 2>&1 || true
    exit 0
    ;;

  rdp-keepalive|*)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Windows VM (keep-alive mode)..." >> "$LOG_FILE"
    
    # 1. Bring up container if not already running
    if ! is_container_running; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bringing up container via omarchy-windows-vm launch -k..." >> "$LOG_FILE"
      omarchy-windows-vm launch -k >> "$LOG_FILE" 2>&1 || true
    fi

    # 2. Check if FreeRDP was launched and is already running
    if pgrep -f "xfreerdp" >/dev/null 2>&1; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] FreeRDP client is currently active." >> "$LOG_FILE"
      exit 0
    fi

    # 3. If FreeRDP failed initial boot handshake, retry until Windows accepts connection
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FreeRDP not running. Starting retry connection loop..." >> "$LOG_FILE"
    for attempt in {1..12}; do
      if ! is_container_running; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container is stopped, aborting." >> "$LOG_FILE"
        break
      fi

      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Connection attempt $attempt of 12..." >> "$LOG_FILE"
      if run_freerdp; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] FreeRDP session ended normally." >> "$LOG_FILE"
        break
      fi

      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $attempt failed, waiting 3s before retry..." >> "$LOG_FILE"
      sleep 3
    done
    ;;
esac
