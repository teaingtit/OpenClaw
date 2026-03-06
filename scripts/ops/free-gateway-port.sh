#!/usr/bin/env bash
# free-gateway-port.sh — free port 18789 (or OPENCLAW_GATEWAY_PORT) before gateway start
# Used by systemd ExecStartPre to prevent port-conflict restart loops (orphan process holding port).
# Safe to run: stops user gateway service, then kills any process still on the port.
#
# Usage: free-gateway-port.sh
# Env: OPENCLAW_GATEWAY_PORT (default 18789), OPENCLAW_SYSTEMD_UNIT (default openclaw-gateway.service)

set -euo pipefail

PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
UNIT="${OPENCLAW_SYSTEMD_UNIT:-openclaw-gateway.service}"

# Stop the user gateway service so the previous instance exits cleanly
systemctl --user stop "$UNIT" 2>/dev/null || true
sleep 2

# Force-kill any process still bound to the port (orphans)
if command -v fuser >/dev/null 2>&1; then
  fuser -k "${PORT}/tcp" 2>/dev/null || true
fi
if command -v lsof >/dev/null 2>&1; then
  lsof -ti ":$PORT" 2>/dev/null | xargs -r kill -9 2>/dev/null || true
fi
pids=$(ss -ltnp 2>/dev/null | grep ":$PORT " | sed -n 's/.*pid=\([0-9]*\).*/\1/p' || true)
for pid in $pids; do
  [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null || true
done
sleep 1
