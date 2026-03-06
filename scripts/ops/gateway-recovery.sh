#!/usr/bin/env bash
# gateway-recovery.sh — restart OpenClaw gateway, run health-check, show recent log errors
# Use on the host where the gateway runs (e.g. exe.dev VM). Run from repo root or script dir.
#
# Usage: gateway-recovery.sh [--no-restart] [--notify]
#   --no-restart   only run health-check and show log (do not restart gateway)
#   --notify       allow health-check to send Telegram on critical (default: no, to avoid duplicate alert)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
LOG_PATH="${OPENCLAW_GATEWAY_LOG:-/tmp/openclaw-gateway.log}"
HEALTH_SCRIPT="$REPO_ROOT/scripts/ops/health-check.sh"
DO_RESTART=true
NOTIFY_ARG="--no-notify"

for arg in "$@"; do
  case "$arg" in
    --no-restart) DO_RESTART=false ;;
    --notify)     NOTIFY_ARG="" ;;
  esac
done

echo "=== Gateway recovery ==="

# --- Restart ---
if [ "$DO_RESTART" = true ]; then
  echo "Stopping any existing gateway (free port $GATEWAY_PORT)..."
  systemctl --user stop openclaw-gateway.service 2>/dev/null || true
  # Kill by port first (avoids relying on process name; run before openclaw gateway stop so CLI is not confused)
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "$GATEWAY_PORT/tcp" >/dev/null 2>&1 || true
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -ti ":$GATEWAY_PORT" 2>/dev/null | xargs -r kill -9 2>/dev/null || true
  fi
  # Fallback: parse PIDs from ss (Linux; no fuser/lsof needed)
  pids=$(ss -ltnp 2>/dev/null | grep ":$GATEWAY_PORT " | sed -n 's/.*pid=\([0-9]*\).*/\1/p' || true)
  for pid in $pids; do
    [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null || true
  done
  if command -v openclaw >/dev/null 2>&1; then
    openclaw gateway stop 2>/dev/null || true
  fi
  pkill -9 -f openclaw-gateway 2>/dev/null || true
  pkill -9 -f "openclaw gateway" 2>/dev/null || true
  sleep 2

  echo "Starting gateway..."
  if systemctl --user start openclaw-gateway.service 2>/dev/null; then
    echo "  Started via systemd (openclaw-gateway.service)."
  else
    if command -v openclaw >/dev/null 2>&1; then
      nohup openclaw gateway run --bind loopback --port "$GATEWAY_PORT" --force >> "$LOG_PATH" 2>&1 &
      echo "  Started via: openclaw gateway run (background)."
    else
      echo "  WARN: openclaw not in PATH; if using pnpm, run: cd $REPO_ROOT && nohup pnpm openclaw gateway run --bind loopback --port $GATEWAY_PORT --force >> $LOG_PATH 2>&1 &"
      exit 1
    fi
  fi
  echo "Waiting for gateway to bind on port $GATEWAY_PORT (up to 25s)..."
  sleep 8
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ss -ltnp 2>/dev/null | grep -q ":$GATEWAY_PORT "; then
      echo "  Port $GATEWAY_PORT is up."
      break
    fi
    sleep 2
  done
fi

# --- Health check (no Telegram on recovery run to avoid duplicate alert) ---
echo ""
if [ -x "$HEALTH_SCRIPT" ]; then
  "$HEALTH_SCRIPT" --format verbose $NOTIFY_ARG || true
else
  echo "Health script not found or not executable: $HEALTH_SCRIPT"
fi

# --- Recent log (errors) ---
echo ""
echo "=== Last 80 lines of gateway log (check errors) ==="
if [ -f "$LOG_PATH" ]; then
  tail -n 80 "$LOG_PATH"
else
  if command -v journalctl >/dev/null 2>&1 && journalctl --user -u openclaw-gateway.service -n 1 --no-pager >/dev/null 2>&1; then
    echo "(from journalctl — user unit openclaw-gateway.service)"
    journalctl --user -u openclaw-gateway.service -n 80 --no-pager
  else
    echo "Log file not found: $LOG_PATH (and no journalctl user unit openclaw-gateway.service)"
  fi
fi
