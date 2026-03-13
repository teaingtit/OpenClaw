#!/usr/bin/env bash
# backup-status.sh — check backup freshness, validity, config drift, and timer status
# Exit code: 0 = fresh+valid, 1 = >12h or drift, 2 = >24h or invalid
#
# Usage: backup-status.sh [--format json|verbose]

set -euo pipefail

FORMAT="json"
BACKUP_DIR="${OPENCLAW_BACKUP_DIR:-$HOME/.openclaw/backup}"
CONFIG_FILE="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --format) shift; [ -n "${1:-}" ] && FORMAT="$1" ;;
    --verbose) FORMAT="verbose" ;;
  esac
done

ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
now_epoch=$(date +%s)

# Backup directory existence
backup_exists="false"
file_count=0
total_size="0"
last_backup_ts="never"
hours_since=-1

if [ -d "$BACKUP_DIR" ]; then
  backup_exists="true"
  file_count=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
  total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}' || echo "0")

  # Find newest file
  newest=$(find "$BACKUP_DIR" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1)
  if [ -n "$newest" ]; then
    newest_epoch=$(echo "$newest" | awk '{printf "%.0f", $1}')
    newest_path=$(echo "$newest" | awk '{print $2}')
    last_backup_ts=$(date -d "@$newest_epoch" -Iseconds 2>/dev/null || echo "unknown")
    hours_since=$(( (now_epoch - newest_epoch) / 3600 ))
  fi
fi

# Validate newest JSON backup
json_valid="n/a"
if [ -n "${newest_path:-}" ] && [[ "$newest_path" == *.json ]]; then
  if command -v jq >/dev/null 2>&1; then
    jq empty "$newest_path" 2>/dev/null && json_valid="valid" || json_valid="invalid"
  else
    python3 -c "import json; json.load(open('$newest_path'))" 2>/dev/null && json_valid="valid" || json_valid="invalid"
  fi
fi

# Config drift check: compare live config with newest backup
config_drift="n/a"
if [ -f "$CONFIG_FILE" ] && [ -n "${newest_path:-}" ] && [ -f "$newest_path" ] && [[ "$newest_path" == *.json ]]; then
  if command -v diff >/dev/null 2>&1; then
    diff -q "$CONFIG_FILE" "$newest_path" >/dev/null 2>&1 && config_drift="no" || config_drift="yes"
  fi
fi

# systemd timer status
timer_status="not_found"
timer_next="n/a"
if command -v systemctl >/dev/null 2>&1; then
  raw_state=$(systemctl --user show openclaw-backup.timer -p ActiveState --value 2>/dev/null || true)
  if [ -n "$raw_state" ] && [ "$raw_state" != "" ]; then
    timer_status="$raw_state"
    timer_next=$(systemctl --user show openclaw-backup.timer -p NextElapseUSecRealtime --value 2>/dev/null || echo "n/a")
  fi
fi

# --- Status ---
status="ok"
exit_code=0

if [ "$backup_exists" = "false" ]; then
  status="critical"
  exit_code=2
elif [ "$hours_since" -gt 12 ] || [ "$config_drift" = "yes" ]; then
  status="warning"
  exit_code=1
fi

if [ "$hours_since" -gt 24 ] || [ "$json_valid" = "invalid" ]; then
  status="critical"
  exit_code=2
fi

# --- Output ---
if [ "$FORMAT" = "verbose" ]; then
  echo "Backup Status — $ts"
  echo "  Backup dir:         $BACKUP_DIR (exists: $backup_exists)"
  echo "  File count:         $file_count"
  echo "  Total size:         $total_size"
  echo "  Last backup:        $last_backup_ts (${hours_since}h ago)"
  echo "  JSON valid:         $json_valid"
  echo "  Config drift:       $config_drift"
  echo "  Timer status:       $timer_status"
  echo "  Timer next:         $timer_next"
  echo "  Status:             $status"
else
  printf '{"ts":"%s","backup_dir":"%s","backup_exists":%s,"file_count":%s,"total_size":"%s","last_backup":"%s","hours_since":%s,"json_valid":"%s","config_drift":"%s","timer_status":"%s","timer_next":"%s","status":"%s"}\n' \
    "$ts" "$BACKUP_DIR" "$backup_exists" "$file_count" "$total_size" "$last_backup_ts" "$hours_since" "$json_valid" "$config_drift" "$timer_status" "$timer_next" "$status"
fi

exit "$exit_code"
