#!/usr/bin/env bash
# system-report.sh — combined system report for father/monitor
# Output: JSON with disk, memory, load, docker, systemd failed, security updates, worker status

set -euo pipefail



# Disk: list mount and pct
disk_json=$(df -h 2>/dev/null | tail -n +2 | awk 'NR<=5 {gsub(/%/,"",$5); printf "{\"mount\":\"%s\",\"pct\":%s},",$6,$5}' | sed 's/,$//')
[ -z "$disk_json" ] && disk_json="[]" || disk_json="[$disk_json]"

# Memory
mem_pct=0
if command -v free >/dev/null 2>&1; then
  read -r _ mem_total mem_used _ _ _ < <(free -m 2>/dev/null | grep Mem) || true
  [ -n "${mem_total:-}" ] && [ "${mem_total:-0}" -gt 0 ] && mem_pct=$(( (mem_used * 100) / mem_total ))
fi

# Load
load="0"
if [ -f /proc/loadavg ]; then
  read -r load _ _ < /proc/loadavg 2>/dev/null || true
elif command -v uptime >/dev/null 2>&1; then
  load=$(uptime 2>/dev/null | sed -n 's/.*load average[s]*: \([0-9.,]*\).*/\1/p' | cut -d, -f1 | tr -d ' ') || load="0"
fi

# Docker
docker_status="n/a"
docker_healthy="n/a"
if command -v docker >/dev/null 2>&1; then
  running=$(docker ps -q 2>/dev/null | wc -l)
  total=$(docker ps -aq 2>/dev/null | wc -l)
  [ "$total" -eq 0 ] && docker_status="0/0" || docker_status="${running}/${total}"
  unhealthy=$(docker ps -a --filter health=unhealthy -q 2>/dev/null | wc -l)
  docker_healthy="false"
  [ "$unhealthy" -eq 0 ] && docker_healthy="true"
fi

# Failed systemd units (user + system)
failed_units=0
if command -v systemctl >/dev/null 2>&1; then
  failed_units=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
  fu_user=$(systemctl --user --failed --no-legend 2>/dev/null | wc -l)
  failed_units=$((failed_units + fu_user))
fi

# Security updates (apt)
security_updates=0
if command -v apt-get >/dev/null 2>&1; then
  security_updates=$(apt list --upgradable 2>/dev/null | grep -cE "security|Security" || true)
  [ -z "$security_updates" ] && security_updates=0
fi



export SYSREPORT_DISK="$disk_json" SYSREPORT_MEM=$mem_pct SYSREPORT_LOAD="$load" SYSREPORT_DOCKER="$docker_status" SYSREPORT_DOCKER_OK="$docker_healthy" SYSREPORT_FAILED=$failed_units SYSREPORT_SEC=$security_updates
python3 << 'PYEOF'
import json
import os
disk = os.environ.get("SYSREPORT_DISK", "[]")
try:
    disk = json.loads(disk) if isinstance(disk, str) else disk
except Exception:
    disk = []
docker_ok = os.environ.get("SYSREPORT_DOCKER_OK", "true").lower() == "true"
print(json.dumps({
    "disk": disk,
    "mem_pct": int(os.environ.get("SYSREPORT_MEM", 0)),
    "load": os.environ.get("SYSREPORT_LOAD", "0"),
    "docker": os.environ.get("SYSREPORT_DOCKER", "n/a"),
    "docker_healthy": docker_ok,
    "failed_units": int(os.environ.get("SYSREPORT_FAILED", 0)),
    "security_updates": int(os.environ.get("SYSREPORT_SEC", 0)),

}))
PYEOF
