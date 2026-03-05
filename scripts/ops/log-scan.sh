#!/usr/bin/env bash
# log-scan.sh — scan OpenClaw gateway log for errors/warnings
# Usage: log-scan.sh [--minutes 15] [--format json|text]
# Output: JSON {"period":"15m","errors":N,"warnings":N,"top_errors":[...],"status":"ok|warning|critical"}

set -euo pipefail

MINUTES=15
FORMAT="json"
LOG_PATH="/tmp/openclaw-gateway.log"

while [ $# -gt 0 ]; do
  case "$1" in
    --minutes) MINUTES="${2:-15}"; shift 2 || shift ;;
    --minutes=*) MINUTES="${1#--minutes=}"; shift ;;
    --format) FORMAT="${2:-json}"; shift 2 || shift ;;
    --format=*) FORMAT="${1#--format=}"; shift ;;
    *) shift ;;
  esac
done

errors=0
warnings=0

# Prefer journalctl if available (user unit)
if command -v journalctl >/dev/null 2>&1; then
  raw=$(journalctl --user -u openclaw-gateway.service --since "${MINUTES} min ago" --no-pager 2>/dev/null || true)
  if [ -n "$raw" ]; then
    errors=$(echo "$raw" | grep -cE "ERROR|\[error\]|error:|Error|timeout|ETIMEDOUT|ECONNREFUSED|crash|OOM" || true)
    warnings=$(echo "$raw" | grep -cE "WARN|\[warn\]|warning|Warning" || true)
  fi
fi

# Fallback: file log
if [ -f "$LOG_PATH" ]; then
  block=$(tail -n 2000 "$LOG_PATH" 2>/dev/null)
  e=$(echo "$block" | grep -cE "ERROR|error|Error|timeout|ETIMEDOUT|crash|OOM" || true)
  w=$(echo "$block" | grep -cE "WARN|warn|warning" || true)
  [ "$e" -gt "$errors" ] && errors=$e
  [ "$w" -gt "$warnings" ] && warnings=$w
fi

# Status
status="ok"
[ "$errors" -gt 10 ] && status="critical"
[ "$errors" -gt 0 ] && [ "$status" = "ok" ] && status="warning"
[ "$warnings" -gt 5 ] && [ "$status" = "ok" ] && status="warning"

# Build top_errors from log file (last 500 lines)
top_errors="[]"
if [ -f "$LOG_PATH" ]; then
  top_errors=$(tail -n 500 "$LOG_PATH" 2>/dev/null | grep -oE "ERROR[^\]\"]*|timeout|ETIMEDOUT|OOM|crash" | sort | uniq -c | sort -rn | head -5 | python3 -c "
import sys, json
out = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 1)
    if len(parts) >= 2:
        out.append(parts[1][:80])
    else:
        out.append(line[:80])
print(json.dumps(out[:5]))
" 2>/dev/null || echo "[]")
fi

if [ "$FORMAT" = "text" ]; then
  echo "Period: ${MINUTES}m | Errors: $errors | Warnings: $warnings | Status: $status"
  echo "Top: $top_errors"
else
  export LOG_SCAN_PERIOD="${MINUTES}m" LOG_SCAN_ERRORS=$errors LOG_SCAN_WARNINGS=$warnings LOG_SCAN_STATUS="$status" LOG_SCAN_TOP="$top_errors"
  python3 << 'PYEOF'
import json
import os
te = os.environ.get("LOG_SCAN_TOP", "[]")
try:
    te = json.loads(te) if isinstance(te, str) else te
except Exception:
    te = []
print(json.dumps({
    "period": os.environ.get("LOG_SCAN_PERIOD", "15m"),
    "errors": int(os.environ.get("LOG_SCAN_ERRORS", 0)),
    "warnings": int(os.environ.get("LOG_SCAN_WARNINGS", 0)),
    "top_errors": te if isinstance(te, list) else [],
    "status": os.environ.get("LOG_SCAN_STATUS", "ok"),
}))
PYEOF
fi

exit 0
