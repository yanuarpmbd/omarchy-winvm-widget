#!/usr/bin/env bash
# ==============================================================================
# winvm-stats.sh - Fast unprivileged VM resource & allocation stats extractor
# Part of io.github.yanuarpmbd.winvm plugin
# ==============================================================================
set -euo pipefail

IMG_PATH="${HOME}/.windows/data.img"
SPECS_CACHE="${HOME}/.config/windows/vm-specs.json"

alloc_disk="128 GB"
host_disk="0 GB"

if [[ -f "$IMG_PATH" ]]; then
  bytes=$(stat -c "%s" "$IMG_PATH" 2>/dev/null || echo 0)
  if (( bytes > 0 )); then
    alloc_disk="$(( bytes / 1024 / 1024 / 1024 )) GB"
  fi
  host_disk=$(du -sh "$IMG_PATH" 2>/dev/null | cut -f1 || echo "0 GB")
fi

alloc_ram="8 GB"
alloc_cores=4

if [[ -f "$SPECS_CACHE" ]]; then
  r=$(grep -oP '"allocated_ram":\s*"\K[^"]+' "$SPECS_CACHE" 2>/dev/null || true)
  [[ -n "$r" ]] && alloc_ram="$r"
  c=$(grep -oP '"allocated_cores":\s*\K[0-9]+' "$SPECS_CACHE" 2>/dev/null || true)
  [[ -n "$c" ]] && alloc_cores="$c"
fi

if [[ "$alloc_ram" =~ ^([0-9]+)G$ ]]; then
  alloc_ram="${BASH_REMATCH[1]} GB"
fi

pid=$(pgrep -f "qemu-system-x86_64" | head -n1 || true)

if [[ -n "$pid" && -d "/proc/$pid" ]]; then
  cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
  
  ram_match=$(echo "$cmd" | grep -oP "(?<=-m )\S+" || true)
  if [[ -n "$ram_match" ]]; then
    if [[ "$ram_match" =~ ^([0-9]+)G$ ]]; then
      alloc_ram="${BASH_REMATCH[1]} GB"
    else
      alloc_ram="$ram_match"
    fi
  fi
  
  smp_match=$(echo "$cmd" | grep -oP "(?<=-smp )[0-9]+" || true)
  [[ -n "$smp_match" ]] && alloc_cores="$smp_match"

  mkdir -p "$(dirname "$SPECS_CACHE")"
  printf '{"allocated_ram": "%s", "allocated_cores": %s, "allocated_disk": "%s", "host_disk_usage": "%s"}\n' \
    "$alloc_ram" "$alloc_cores" "$alloc_disk" "$host_disk" > "$SPECS_CACHE" 2>/dev/null || true

  read -r cpu_pct mem_pct rss_kb < <(ps -p "$pid" -o %cpu,%mem,rss --no-headers 2>/dev/null || echo "0 0 0")
  mem_gb=$(awk "BEGIN {printf \"%.2f\", $rss_kb / 1024 / 1024}")
  
  printf '{"running":true,"cpuPct":%s,"memGb":%s,"memPct":%s,"allocRam":"%s","allocCores":%s,"allocDisk":"%s","hostDisk":"%s"}\n' \
    "$cpu_pct" "$mem_gb" "$mem_pct" "$alloc_ram" "$alloc_cores" "$alloc_disk" "$host_disk"
else
  printf '{"running":false,"cpuPct":0,"memGb":0,"memPct":0,"allocRam":"%s","allocCores":%s,"allocDisk":"%s","hostDisk":"%s"}\n' \
    "$alloc_ram" "$alloc_cores" "$alloc_disk" "$host_disk"
fi
