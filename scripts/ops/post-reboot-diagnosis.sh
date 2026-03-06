#!/usr/bin/env bash
# post-reboot-diagnosis.sh — หาสาเหตุ server ล่ม/รีบูท (รันบน host ที่เพิ่ง reboot)
# ดู kernel log ของ boot ก่อนหน้า (journalctl -b -1) หา OOM, panic, killed process
#
# Usage: post-reboot-diagnosis.sh [--lines 200] [--format text|json]
#   --lines N   จำนวนบรรทัดสุดท้ายของ boot ก่อนที่จะแสดง (default 200)
#   --format    text = อ่านง่าย, json = one-liner สำหรับ agent

set -euo pipefail

LINES=200
FORMAT="text"

while [ $# -gt 0 ]; do
  case "$1" in
    --lines)   LINES="${2:-200}"; shift 2 || shift ;;
    --lines=*) LINES="${1#--lines=}"; shift ;;
    --format)  FORMAT="${2:-text}"; shift 2 || shift ;;
    --format=*) FORMAT="${1#--format=}"; shift ;;
    *) shift ;;
  esac
done

ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cause="unknown"
oom=0
panic=0
killed=0
segfault=0
power=0
summary_lines=""

# ต้องมี journalctl (systemd)
if ! command -v journalctl >/dev/null 2>&1; then
  if [ "$FORMAT" = "json" ]; then
    echo "{\"ts\":\"$ts\",\"error\":\"journalctl not available\",\"cause\":\"unknown\"}"
  else
    echo "post-reboot-diagnosis: journalctl not available (no systemd?). Check /var/log/syslog or dmesg."
  fi
  exit 1
fi

# อ่าน log ของ boot ก่อนหน้า (-b -1)
prev_log=""
if journalctl -b -1 -n 1 --no-pager >/dev/null 2>&1; then
  prev_log=$(journalctl -b -1 -n "$LINES" --no-pager 2>/dev/null || true)
else
  # บางระบบเก็บแค่ boot ปัจจุบัน
  prev_log=$(journalctl -n "$LINES" --no-pager 2>/dev/null || true)
fi

if [ -z "$prev_log" ]; then
  if [ "$FORMAT" = "json" ]; then
    echo "{\"ts\":\"$ts\",\"error\":\"no previous boot log\",\"cause\":\"unknown\"}"
  else
    echo "No previous-boot log (journalctl -b -1 empty). Try: journalctl -b -1 -n 300"
  fi
  exit 0
fi

# สแกนหาสาเหตุที่พบบ่อย
echo "$prev_log" | grep -iE "out of memory|oom-kill|oom_kill|killed process|invoked oom-killer" >/dev/null 2>&1 && { oom=1; killed=1; cause="oom"; }
echo "$prev_log" | grep -iE "kernel panic|panic\[|BUG:|Oops" >/dev/null 2>&1 && { panic=1; cause="kernel_panic"; }
echo "$prev_log" | grep -iE "segfault|segmentation fault|core dumped" >/dev/null 2>&1 && { segfault=1; [ "$cause" = "unknown" ] && cause="segfault"; }
echo "$prev_log" | grep -iE "power down|shutdown|watchdog.*reset|hard reset" >/dev/null 2>&1 && { power=1; [ "$cause" = "unknown" ] && cause="power_or_watchdog"; }

# บรรทัดที่เกี่ยวกับ OOM/killed (สำหรับสรุป)
if [ "$oom" -eq 1 ]; then
  summary_lines=$(echo "$prev_log" | grep -iE "oom-kill|killed process|out of memory" | tail -5 || true)
fi

if [ "$FORMAT" = "json" ]; then
  printf '{"ts":"%s","cause":"%s","oom":%s,"panic":%s,"killed":%s,"segfault":%s,"power_or_watchdog":%s}\n' \
    "$ts" "$cause" "$oom" "$panic" "$killed" "$segfault" "$power"
  exit 0
fi

# --- Text output (human + agent) ---
echo "=== Post-reboot diagnosis ($ts) ==="
echo "Previous boot log: last $LINES lines (journalctl -b -1)."
echo ""

if [ "$cause" != "unknown" ]; then
  echo "Likely cause: $cause"
  [ "$oom" -eq 1 ] && echo "  → OOM (Out of Memory): ระบบขาด RAM จึงมีการ kill process."
  [ "$panic" -eq 1 ] && echo "  → Kernel panic:  kernel  crash."
  [ "$segfault" -eq 1 ] && echo "  → Segfault: process crash (อาจเป็นแอปหรือ driver)."
  [ "$power" -eq 1 ] && echo "  → Power/watchdog: ดับไฟ หรือ watchdog reboot."
else
  echo "No obvious OOM/panic/segfault in last $LINES lines. Review full log below."
fi

if [ -n "$summary_lines" ]; then
  echo ""
  echo "--- OOM/killed summary ---"
  echo "$summary_lines"
fi

echo ""
echo "--- Last 80 lines of previous boot (tail) ---"
echo "$prev_log" | tail -n 80

echo ""
echo "--- Suggestions ---"
if [ "$oom" -eq 1 ]; then
  echo "- ลด workload หรือเพิ่ม RAM; ตรวจสอบ process ที่ใช้ memory สูง (node/docker)."
  echo "- Gateway + Docker บน minipc 16GB: จำกัด container memory หรือปิด service ที่ไม่จำเป็น."
fi
if [ "$cause" = "unknown" ]; then
  echo "- Run: journalctl -b -1 -n 500   เพื่อดู log เต็มของ boot ก่อนหน้า"
  echo "- Run: journalctl -b -1 -p err  เพื่อดูเฉพาะระดับ error ขึ้นไป"
fi
