#!/usr/bin/env bash
# health-check-and-recover.sh — run health-check; on CRITICAL run gateway-recovery (OS-level auto-recovery)
# For use by systemd timer so server can recover when gateway is down/looping without relying on agents
# (agents need the gateway to run, so they cannot recover when the gateway itself has failed).
#
# Usage: health-check-and-recover.sh [same args as health-check.sh]
# Example (timer): ExecStart=.../health-check-and-recover.sh --format json --notify-on-critical

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HEALTH_SCRIPT="$REPO_ROOT/scripts/ops/health-check.sh"
RECOVERY_SCRIPT="$REPO_ROOT/scripts/ops/gateway-recovery.sh"

if [ ! -x "$HEALTH_SCRIPT" ]; then
  echo "health-check-and-recover: $HEALTH_SCRIPT not found or not executable" >&2
  exit 2
fi

exit_code=0
"$HEALTH_SCRIPT" "$@" || exit_code=$?

if [ "$exit_code" -eq 2 ]; then
  if [ -x "$RECOVERY_SCRIPT" ]; then
    echo "health-check-and-recover: CRITICAL detected, running gateway-recovery.sh"
    "$RECOVERY_SCRIPT" --notify
  else
    echo "health-check-and-recover: CRITICAL but $RECOVERY_SCRIPT not executable" >&2
  fi
fi

exit "$exit_code"
