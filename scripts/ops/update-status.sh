#!/usr/bin/env bash
# update-status.sh — check system and application update status
# Exit code: 0 = up-to-date, 1 = pending security or outdated openclaw, 2 = reboot required or apt >7d stale
#
# Usage: update-status.sh [--format json|verbose] [--skip-npm]

set -euo pipefail

FORMAT="json"
SKIP_NPM=false

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --format) shift; [ -n "${1:-}" ] && FORMAT="$1" ;;
    --verbose) FORMAT="verbose" ;;
    --skip-npm) SKIP_NPM=true ;;
  esac
done

ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

# APT upgradable
total_upgradable=0
security_updates=0
if command -v apt >/dev/null 2>&1; then
  total_upgradable=$(apt list --upgradable 2>/dev/null | { grep -c "upgradable" || true; })
  security_updates=$(apt list --upgradable 2>/dev/null | { grep -ci "security" || true; })
fi

# Reboot required
reboot_required="no"
[ -f /var/run/reboot-required ] && reboot_required="yes"

# Kernel version
kernel_version=$(uname -r 2>/dev/null || echo "unknown")

# Node version
node_version="not_found"
node_ok="false"
if command -v node >/dev/null 2>&1; then
  node_version=$(node --version 2>/dev/null || echo "unknown")
  node_major=$(echo "$node_version" | grep -oP '\d+' | head -1 || echo 0)
  [ "$node_major" -ge 22 ] && node_ok="true"
fi

# Bun version
bun_version="not_found"
if command -v bun >/dev/null 2>&1; then
  bun_version=$(bun --version 2>/dev/null || echo "unknown")
fi

# OpenClaw local version
openclaw_local="not_found"
if command -v openclaw >/dev/null 2>&1; then
  openclaw_local=$(openclaw --version 2>/dev/null | head -1 || echo "unknown")
fi

# OpenClaw npm latest
openclaw_npm="skipped"
if [ "$SKIP_NPM" = false ]; then
  if command -v npm >/dev/null 2>&1; then
    openclaw_npm=$(npm view openclaw version --userconfig "$(mktemp)" 2>/dev/null || echo "error")
  fi
fi

# Last apt update time
last_apt_update="unknown"
apt_stale_days=0
if [ -f /var/lib/apt/periodic/update-stamp ]; then
  last_epoch=$(stat -c %Y /var/lib/apt/periodic/update-stamp 2>/dev/null || echo 0)
  last_apt_update=$(date -d "@$last_epoch" -Iseconds 2>/dev/null || echo "unknown")
  now_epoch=$(date +%s)
  apt_stale_days=$(( (now_epoch - last_epoch) / 86400 ))
elif [ -f /var/cache/apt/pkgcache.bin ]; then
  last_epoch=$(stat -c %Y /var/cache/apt/pkgcache.bin 2>/dev/null || echo 0)
  last_apt_update=$(date -d "@$last_epoch" -Iseconds 2>/dev/null || echo "unknown")
  now_epoch=$(date +%s)
  apt_stale_days=$(( (now_epoch - last_epoch) / 86400 ))
fi

# --- Status ---
status="up-to-date"
exit_code=0

if [ "$security_updates" -gt 0 ]; then
  status="pending"
  exit_code=1
fi

if [ "$openclaw_npm" != "skipped" ] && [ "$openclaw_npm" != "error" ] && [ -n "$openclaw_local" ] && [ "$openclaw_local" != "not_found" ]; then
  # Simple version mismatch check
  if [ "$openclaw_local" != "$openclaw_npm" ]; then
    [ "$exit_code" -lt 1 ] && { status="pending"; exit_code=1; }
  fi
fi

if [ "$reboot_required" = "yes" ] || [ "$apt_stale_days" -gt 7 ]; then
  status="critical"
  exit_code=2
fi

# --- Output ---
if [ "$FORMAT" = "verbose" ]; then
  echo "Update Status — $ts"
  echo "  APT upgradable:     $total_upgradable (security: $security_updates)"
  echo "  Reboot required:    $reboot_required"
  echo "  Kernel:             $kernel_version"
  echo "  Node:               $node_version (>=22: $node_ok)"
  echo "  Bun:                $bun_version"
  echo "  OpenClaw local:     $openclaw_local"
  echo "  OpenClaw npm:       $openclaw_npm"
  echo "  Last apt update:    $last_apt_update (${apt_stale_days}d ago)"
  echo "  Status:             $status"
else
  printf '{"ts":"%s","total_upgradable":%s,"security_updates":%s,"reboot_required":"%s","kernel":"%s","node_version":"%s","node_ok":%s,"bun_version":"%s","openclaw_local":"%s","openclaw_npm":"%s","last_apt_update":"%s","apt_stale_days":%s,"status":"%s"}\n' \
    "$ts" "$total_upgradable" "$security_updates" "$reboot_required" "$kernel_version" "$node_version" "$node_ok" "$bun_version" "$openclaw_local" "$openclaw_npm" "$last_apt_update" "$apt_stale_days" "$status"
fi

exit "$exit_code"
