#!/usr/bin/env bash
# process-monitor.sh — monitor processes, zombies, load, and node.js summary
# Exit code: 0 = healthy, 1 = zombies>0 or load_ratio>2, 2 = load_ratio>4 or zombies>5
#
# Usage: process-monitor.sh [--format json|verbose] [--top N]

set -euo pipefail

FORMAT="json"
TOP_N=10

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --format) shift; [ -n "${1:-}" ] && FORMAT="$1" ;;
    --verbose) FORMAT="verbose" ;;
    --top=*) TOP_N="${arg#--top=}" ;;
    --top) shift; [ -n "${1:-}" ] && TOP_N="$1" ;;
  esac
done

ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

# Zombie count
zombie_count=$(ps aux 2>/dev/null | awk '$8 ~ /^Z/ {c++} END {print c+0}')

# Load average and CPU count
read -r load1 load5 load15 _ < /proc/loadavg 2>/dev/null || { load1=0; load5=0; load15=0; }
cpu_count=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
load_ratio=$(awk "BEGIN {printf \"%.2f\", $load1 / $cpu_count}")

# Top N processes by CPU
top_cpu=$(ps aux --sort=-%cpu 2>/dev/null | head -n $((TOP_N + 1)) | tail -n "$TOP_N" | awk '{printf "{\"pid\":%s,\"cpu\":%s,\"mem\":%s,\"cmd\":\"%s\"},", $2, $3, $4, $11}' | sed 's/,$//')

# Top N processes by memory
top_mem=$(ps aux --sort=-%mem 2>/dev/null | head -n $((TOP_N + 1)) | tail -n "$TOP_N" | awk '{printf "{\"pid\":%s,\"cpu\":%s,\"mem\":%s,\"cmd\":\"%s\"},", $2, $3, $4, $11}' | sed 's/,$//')

# Long-running processes (>24h)
long_running=0
if command -v ps >/dev/null 2>&1; then
  long_running=$(ps -eo etimes= 2>/dev/null | awk '$1 > 86400 {c++} END {print c+0}')
fi

# Node.js process summary
node_count=$(pgrep -c -f 'node|bun' 2>/dev/null || echo 0)
node_mem_total=0
if [ "$node_count" -gt 0 ]; then
  node_mem_total=$(ps -C node,bun -o rss= 2>/dev/null | awk '{s+=$1} END {printf "%.0f", s/1024}' || echo 0)
fi

# Total processes
total_procs=$(ps aux 2>/dev/null | wc -l)
total_procs=$((total_procs - 1))

# --- Status ---
status="healthy"
exit_code=0

if [ "$zombie_count" -gt 0 ] || [ "$(awk "BEGIN {print ($load_ratio > 2)}")" -eq 1 ]; then
  status="warning"
  exit_code=1
fi

if [ "$zombie_count" -gt 5 ] || [ "$(awk "BEGIN {print ($load_ratio > 4)}")" -eq 1 ]; then
  status="critical"
  exit_code=2
fi

# --- Output ---
if [ "$FORMAT" = "verbose" ]; then
  echo "Process Monitor — $ts"
  echo "  Load average:       $load1 / $load5 / $load15 (ratio: $load_ratio, CPUs: $cpu_count)"
  echo "  Total processes:    $total_procs"
  echo "  Zombies:            $zombie_count"
  echo "  Long-running (>24h): $long_running"
  echo "  Node/Bun processes: $node_count (${node_mem_total}MB RSS)"
  echo "  Status:             $status"
  echo ""
  echo "Top $TOP_N by CPU:"
  ps aux --sort=-%cpu 2>/dev/null | head -n $((TOP_N + 1))
  echo ""
  echo "Top $TOP_N by Memory:"
  ps aux --sort=-%mem 2>/dev/null | head -n $((TOP_N + 1))
else
  printf '{"ts":"%s","load1":%s,"load5":%s,"load15":%s,"load_ratio":%s,"cpu_count":%s,"total_procs":%s,"zombies":%s,"long_running_24h":%s,"node_count":%s,"node_mem_mb":%s,"top_cpu":[%s],"top_mem":[%s],"status":"%s"}\n' \
    "$ts" "$load1" "$load5" "$load15" "$load_ratio" "$cpu_count" "$total_procs" "$zombie_count" "$long_running" "$node_count" "$node_mem_total" "$top_cpu" "$top_mem" "$status"
fi

exit "$exit_code"
