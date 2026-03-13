#!/usr/bin/env bash
# disk-cleanup.sh — report disk usage and cleanup candidates (DRY-RUN by default)
# Exit code: 0 = disk<85%, 1 = 85-95%, 2 = >95%
#
# Usage: disk-cleanup.sh [--format json|verbose] [--execute] [--include-volumes]

set -euo pipefail

FORMAT="json"
EXECUTE=false
INCLUDE_VOLUMES=false

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --format) shift; [ -n "${1:-}" ] && FORMAT="$1" ;;
    --verbose) FORMAT="verbose" ;;
    --execute) EXECUTE=true ;;
    --include-volumes) INCLUDE_VOLUMES=true ;;
  esac
done

ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

# Current disk usage
disk_pct=0
disk_avail="0"
disk_mount="/"
while read -r _ _ _ avail pct mnt; do
  pct="${pct%\%}"
  if [[ "$pct" =~ ^[0-9]+$ ]] && [ "$pct" -gt "$disk_pct" ]; then
    disk_pct=$pct
    disk_avail="$avail"
    disk_mount="$mnt"
  fi
done < <(df -h 2>/dev/null | tail -n +2) || true

# Journal disk usage
journal_size="n/a"
if command -v journalctl >/dev/null 2>&1; then
  journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[KMGT]' | head -1 || echo "n/a")
fi

# Old logs in /tmp
tmp_log_size="0"
tmp_log_count=0
if [ -d /tmp ]; then
  tmp_log_count=$({ find /tmp -maxdepth 2 -name "*.log" -mtime +7 2>/dev/null || true; } | wc -l)
  if [ "$tmp_log_count" -gt 0 ]; then
    tmp_log_size=$(find /tmp -maxdepth 2 -name "*.log" -mtime +7 -exec du -ch {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
  fi
fi

# Docker system df
docker_reclaimable="n/a"
docker_total="n/a"
if command -v docker >/dev/null 2>&1; then
  docker_df=$(docker system df 2>/dev/null || true)
  if [ -n "$docker_df" ]; then
    docker_total=$(echo "$docker_df" | awk 'NR>1 {printf "%s(%s) ", $1, $2}' | sed 's/ $//')
    docker_reclaimable=$(echo "$docker_df" | awk 'NR>1 {printf "%s(%s) ", $1, $NF}' | sed 's/ $//')
  fi
fi

# APT cache size
apt_cache_size="n/a"
if command -v apt >/dev/null 2>&1 && [ -d /var/cache/apt/archives ]; then
  apt_cache_size=$({ du -sh /var/cache/apt/archives 2>/dev/null || true; } | awk '{print $1}')
  if [ -z "$apt_cache_size" ]; then apt_cache_size="n/a"; fi
fi

# Old backups (>30 days)
old_backup_count=0
old_backup_size="0"
backup_dir="${OPENCLAW_BACKUP_DIR:-$HOME/.openclaw/backup}"
if [ -d "$backup_dir" ]; then
  old_backup_count=$({ find "$backup_dir" -type f -mtime +30 2>/dev/null || true; } | wc -l)
  if [ "$old_backup_count" -gt 0 ]; then
    old_backup_size=$(find "$backup_dir" -type f -mtime +30 -exec du -ch {} + 2>/dev/null | tail -1 | awk '{print $1}')
    if [ -z "$old_backup_size" ]; then old_backup_size="0"; fi
  fi
fi

# --- Execute cleanup ---
cleaned=""
if [ "$EXECUTE" = true ]; then
  # Journal vacuum to 200M
  if command -v journalctl >/dev/null 2>&1; then
    sudo journalctl --vacuum-size=200M 2>/dev/null && cleaned="${cleaned}journal_vacuumed,"
  fi

  # Remove old /tmp logs
  if [ "$tmp_log_count" -gt 0 ]; then
    find /tmp -maxdepth 2 -name "*.log" -mtime +7 -delete 2>/dev/null && cleaned="${cleaned}tmp_logs_removed,"
  fi

  # Docker prune
  if command -v docker >/dev/null 2>&1; then
    prune_args="-f"
    docker system prune $prune_args 2>/dev/null && cleaned="${cleaned}docker_pruned,"
    if [ "$INCLUDE_VOLUMES" = true ]; then
      docker volume prune -f 2>/dev/null && cleaned="${cleaned}docker_volumes_pruned,"
    fi
  fi

  # APT cache clean
  if command -v apt >/dev/null 2>&1; then
    sudo apt clean 2>/dev/null && cleaned="${cleaned}apt_cache_cleaned,"
  fi

  # Old backups (>30 days)
  if [ "$old_backup_count" -gt 0 ]; then
    find "$backup_dir" -type f -mtime +30 -delete 2>/dev/null && cleaned="${cleaned}old_backups_removed,"
  fi

  cleaned=$(echo "$cleaned" | sed 's/,$//')
fi

mode="dry-run"
[ "$EXECUTE" = true ] && mode="executed"

# --- Status ---
status="ok"
exit_code=0

if [ "$disk_pct" -ge 85 ]; then
  status="warning"
  exit_code=1
fi

if [ "$disk_pct" -ge 95 ]; then
  status="critical"
  exit_code=2
fi

# --- Output ---
if [ "$FORMAT" = "verbose" ]; then
  echo "Disk Cleanup — $ts (mode: $mode)"
  echo "  Disk usage:         ${disk_pct}% ($disk_mount, ${disk_avail} avail)"
  echo "  Journal size:       $journal_size"
  echo "  Old /tmp logs:      $tmp_log_count files ($tmp_log_size)"
  echo "  Docker:             total=$docker_total reclaimable=$docker_reclaimable"
  echo "  APT cache:          $apt_cache_size"
  echo "  Old backups (>30d): $old_backup_count ($old_backup_size)"
  [ -n "$cleaned" ] && echo "  Cleaned:            $cleaned"
  echo "  Status:             $status"
else
  printf '{"ts":"%s","mode":"%s","disk_pct":%s,"disk_avail":"%s","disk_mount":"%s","journal_size":"%s","tmp_logs":%s,"tmp_log_size":"%s","docker_total":"%s","docker_reclaimable":"%s","apt_cache":"%s","old_backups":%s,"old_backup_size":"%s","cleaned":"%s","status":"%s"}\n' \
    "$ts" "$mode" "$disk_pct" "$disk_avail" "$disk_mount" "$journal_size" "$tmp_log_count" "$tmp_log_size" "$docker_total" "$docker_reclaimable" "$apt_cache_size" "$old_backup_count" "$old_backup_size" "$cleaned" "$status"
fi

exit "$exit_code"
