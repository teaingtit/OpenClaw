#!/usr/bin/env bash
# service-manager.sh — list service status, memory, failed count; optionally restart
# Exit code: 0 = no failed, 1 = some failed, 2 = gateway failed
#
# Usage: service-manager.sh [--format json|verbose] [--restart <name>]

set -euo pipefail

FORMAT="json"
RESTART_TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --format=*) FORMAT="${1#--format=}" ;;
    --format) shift; [ -n "${1:-}" ] && FORMAT="$1" ;;
    --verbose) FORMAT="verbose" ;;
    --restart=*) RESTART_TARGET="${1#--restart=}" ;;
    --restart) shift; [ -n "${1:-}" ] && RESTART_TARGET="$1" ;;
  esac
  shift
done

ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

# Handle restart request
restart_result="n/a"
if [ -n "$RESTART_TARGET" ]; then
  if systemctl --user restart "$RESTART_TARGET" 2>/dev/null; then
    restart_result="ok"
  else
    restart_result="failed"
  fi
fi

# User services
user_services=""
user_failed=0
if command -v systemctl >/dev/null 2>&1; then
  while IFS= read -r line; do
    unit=$(echo "$line" | awk '{print $1}')
    [ -z "$unit" ] && continue
    state=$(systemctl --user show "$unit" -p ActiveState --value 2>/dev/null || echo "unknown")
    sub=$(systemctl --user show "$unit" -p SubState --value 2>/dev/null || echo "unknown")
    mem=$(systemctl --user show "$unit" -p MemoryCurrent --value 2>/dev/null || echo "0")
    # Convert memory to MB
    if [[ "$mem" =~ ^[0-9]+$ ]] && [ "$mem" -gt 0 ]; then
      mem_mb=$(( mem / 1048576 ))
    else
      mem_mb=0
    fi
    user_services="${user_services}{\"unit\":\"$unit\",\"state\":\"$state\",\"sub\":\"$sub\",\"mem_mb\":$mem_mb},"
    [ "$state" = "failed" ] && user_failed=$((user_failed + 1))
  done < <(systemctl --user list-units --type=service --all --no-legend --no-pager 2>/dev/null | awk '{print $1}')
  user_services=$(echo "$user_services" | sed 's/,$//')
fi

# Important system services
SYSTEM_SERVICES="docker tailscaled ssh sshd"
system_services=""
system_failed=0
for svc in $SYSTEM_SERVICES; do
  if systemctl is-enabled "$svc" 2>/dev/null | grep -qE "enabled|static"; then
    state=$(systemctl show "$svc" -p ActiveState --value 2>/dev/null || echo "unknown")
    sub=$(systemctl show "$svc" -p SubState --value 2>/dev/null || echo "unknown")
    mem=$(systemctl show "$svc" -p MemoryCurrent --value 2>/dev/null || echo "0")
    if [[ "$mem" =~ ^[0-9]+$ ]] && [ "$mem" -gt 0 ]; then
      mem_mb=$(( mem / 1048576 ))
    else
      mem_mb=0
    fi
    system_services="${system_services}{\"unit\":\"$svc\",\"state\":\"$state\",\"sub\":\"$sub\",\"mem_mb\":$mem_mb},"
    [ "$state" = "failed" ] && system_failed=$((system_failed + 1))
  fi
done
system_services=$(echo "$system_services" | sed 's/,$//')

total_failed=$((user_failed + system_failed))

# Check gateway specifically
gateway_failed="false"
gw_state=$(systemctl --user show openclaw-gateway.service -p ActiveState --value 2>/dev/null || echo "unknown")
[ "$gw_state" = "failed" ] && gateway_failed="true"

# --- Status ---
status="ok"
exit_code=0

if [ "$total_failed" -gt 0 ]; then
  status="degraded"
  exit_code=1
fi

if [ "$gateway_failed" = "true" ]; then
  status="critical"
  exit_code=2
fi

# --- Output ---
if [ "$FORMAT" = "verbose" ]; then
  echo "Service Manager — $ts"
  echo "  User services failed:   $user_failed"
  echo "  System services failed: $system_failed"
  echo "  Gateway failed:         $gateway_failed"
  [ -n "$RESTART_TARGET" ] && echo "  Restart ($RESTART_TARGET): $restart_result"
  echo "  Status:                 $status"
  echo ""
  echo "User services:"
  systemctl --user list-units --type=service --all --no-pager 2>/dev/null || true
  echo ""
  echo "System services (key):"
  for svc in $SYSTEM_SERVICES; do
    systemctl is-enabled "$svc" 2>/dev/null | grep -qE "enabled|static" && \
      printf "  %-20s %s\n" "$svc" "$(systemctl show "$svc" -p ActiveState --value 2>/dev/null || echo unknown)"
  done
else
  printf '{"ts":"%s","user_failed":%s,"system_failed":%s,"total_failed":%s,"gateway_failed":%s,"restart_target":"%s","restart_result":"%s","user_services":[%s],"system_services":[%s],"status":"%s"}\n' \
    "$ts" "$user_failed" "$system_failed" "$total_failed" "$gateway_failed" "$RESTART_TARGET" "$restart_result" "$user_services" "$system_services" "$status"
fi

exit "$exit_code"
