#!/usr/bin/env bash
# health-check.sh — comprehensive system health check for OpenClaw
# Output: JSON one-liner for agent consumption, or human-readable with --verbose
# Exit code: 0 = all OK, 1 = warning, 2 = critical
#
# Usage: health-check.sh [--format json|verbose] [--notify-on-critical]
# When critical and --notify-on-critical (or default when run from timer), calls tg-notify.sh

set -euo pipefail

GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
DISK_WARN_PCT=85
MEM_WARN_PCT=90
LOG_MINUTES=15
WORKER_IP="${OPENCLAW_WORKER_IP:-192.168.1.27}"
SSH_CONFIG="${OPENCLAW_FATHER_SSH_CONFIG:-$HOME/.openclaw/workspace-father/ssh_config}"
WORKER_HOST="${OPENCLAW_WORKER_HOST:-ryzenpc}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NOTIFY_SCRIPT="$REPO_ROOT/scripts/tg-notify.sh"
FORMAT="json"
NOTIFY_ON_CRITICAL=true

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --format) shift; [ -n "${1:-}" ] && FORMAT="$1" ;;
    --verbose) FORMAT="verbose" ;;
    --notify-on-critical) NOTIFY_ON_CRITICAL=true ;;
    --no-notify) NOTIFY_ON_CRITICAL=false ;;
  esac
done

# --- Collectors ---
ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

# Gateway port
gateway_port="down"
if ss -ltnp 2>/dev/null | grep -q ":$GATEWAY_PORT "; then
  gateway_port="up"
fi

# Gateway systemd service (user)
gateway_svc="unknown"
if systemctl --user is-active --quiet openclaw-gateway.service 2>/dev/null; then
  gateway_svc="active"
elif systemctl --user is-active openclaw-gateway.service 2>/dev/null | grep -q inactive; then
  gateway_svc="inactive"
fi

# Docker: count running vs total (optional)
docker_status="n/a"
if command -v docker >/dev/null 2>&1; then
  running=$(docker ps -q 2>/dev/null | wc -l)
  total=$(docker ps -aq 2>/dev/null | wc -l)
  [ "$total" -eq 0 ] && docker_status="0/0" || docker_status="${running}/${total}"
fi

# Disk: use root mount or first with space
disk_pct=0
disk_mount="/"
while read -r _ _ _ pct _ mnt; do
  pct="${pct%\%}"
  if [[ "$pct" =~ ^[0-9]+$ ]] && [ "$pct" -gt "$disk_pct" ]; then
    disk_pct=$pct
    disk_mount="$mnt"
  fi
done < <(df -h 2>/dev/null | tail -n +2) || true

# Memory: used% (used/(used+available) or similar)
mem_pct=0
if command -v free >/dev/null 2>&1; then
  read -r _ mem_total mem_used _ mem_avail _ < <(free -m 2>/dev/null | grep Mem) || true
  if [ -n "${mem_total:-}" ] && [ "${mem_total:-0}" -gt 0 ]; then
    mem_pct=$(( (mem_used * 100) / mem_total ))
  fi
fi

# Gateway log errors (last N minutes) — tail last 500 lines then grep
errors=0
warnings=0
log_path="/tmp/openclaw-gateway.log"
if [ -f "$log_path" ]; then
  errors=$(tail -n 500 "$log_path" 2>/dev/null | grep -cE "ERROR|\[error\]|error:|Error" || true)
  warnings=$(tail -n 500 "$log_path" 2>/dev/null | grep -cE "WARN|\[warn\]|warning" || true)
fi
# Fallback: journalctl
if command -v journalctl >/dev/null 2>&1; then
  j_errors=$(journalctl --user -u openclaw-gateway.service --since "${LOG_MINUTES} min ago" --no-pager 2>/dev/null | grep -cE "ERROR|error|Error" || true)
  j_warnings=$(journalctl --user -u openclaw-gateway.service --since "${LOG_MINUTES} min ago" --no-pager 2>/dev/null | grep -cE "WARN|warn|warning" || true)
  [ "${j_errors:-0}" -gt "$errors" ] && errors=$j_errors
  [ "${j_warnings:-0}" -gt "$warnings" ] && warnings=$j_warnings
fi

# Worker node
worker="offline"
if ping -c 1 -W 2 "$WORKER_IP" >/dev/null 2>&1; then
  worker="online"
elif [ -f "$SSH_CONFIG" ] && ssh -F "$SSH_CONFIG" -o ConnectTimeout=3 -o BatchMode=yes "$WORKER_HOST" "echo ok" >/dev/null 2>&1; then
  worker="online"
fi

# --- Status ---
status="ok"
exit_code=0
if [ "$gateway_port" != "up" ] || [ "$gateway_svc" = "inactive" ]; then
  status="critical"
  exit_code=2
elif [ "$disk_pct" -ge "$DISK_WARN_PCT" ] || [ "$mem_pct" -ge "$MEM_WARN_PCT" ]; then
  [ "$exit_code" -lt 2 ] && { status="warning"; exit_code=1; }
fi
if [ "$errors" -gt 5 ]; then
  [ "$exit_code" -lt 2 ] && { status="warning"; exit_code=1; }
fi
if [ "$errors" -gt 20 ]; then
  status="critical"
  exit_code=2
fi

# --- Output ---
json=$(printf '{"ts":"%s","gateway":"%s","gateway_svc":"%s","docker":"%s","disk_pct":%s,"disk_mount":"%s","mem_pct":%s,"errors":%s,"warnings":%s,"worker":"%s","status":"%s"}' \
  "$ts" "$gateway_port" "$gateway_svc" "$docker_status" "$disk_pct" "$disk_mount" "$mem_pct" "$errors" "$warnings" "$worker" "$status")

if [ "$FORMAT" = "verbose" ]; then
  echo "Health Check — $ts"
  echo "  Gateway port ($GATEWAY_PORT): $gateway_port"
  echo "  Gateway service:    $gateway_svc"
  echo "  Docker:             $docker_status"
  echo "  Disk ($disk_mount): ${disk_pct}%"
  echo "  Memory:             ${mem_pct}%"
  echo "  Log errors (${LOG_MINUTES}m): $errors"
  echo "  Log warnings:       $warnings"
  echo "  Worker:             $worker"
  echo "  Status:             $status"
else
  echo "$json"
fi

# --- Notify on critical ---
if [ "$exit_code" -eq 2 ] && [ "$NOTIFY_ON_CRITICAL" = true ] && [ -x "$NOTIFY_SCRIPT" ]; then
  msg="⚠️ <b>[Health Check] CRITICAL</b>
Gateway: $gateway_port | Service: $gateway_svc | Disk: ${disk_pct}% | Mem: ${mem_pct}% | Errors: $errors | Worker: $worker"
  "$NOTIFY_SCRIPT" "$msg" 2>/dev/null || true
fi

exit "$exit_code"
