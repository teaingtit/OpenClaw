#!/usr/bin/env bash
# health-check-fix-or-escalate.sh — พบ error → รันสคริปต์แก้ → ถ้าหายเงียบ; ถ้าไม่หายเขียนไฟล์รอ agent (ไม่แจ้ง Telegram ทันที)
#
# Flow:
#   1. รัน health-check (ไม่แจ้ง)
#   2. ถ้า status เป็น ok → ลบไฟล์ escalation ถ้ามี, exit 0 เงียบ
#   3. ถ้า warning/critical → รันสคริปต์แก้ (default: gateway-recovery.sh)
#   4. รัน health-check อีกครั้ง
#   5. ถ้าหาย (ok) → exit 0 เงียบ
#   6. ถ้ายังไม่หาย → เขียน ~/.openclaw/health-escalation-pending.json (ไม่ส่ง Telegram)
#      Agent อ่านไฟล์นี้แล้วลองแก้; ส่ง Telegram เฉพาะเมื่อ agent แก้ได้หรือ agent แก้ไม่ได้ (ดู docs/HEALTH_ESCALATION.md)
#
# Usage: health-check-fix-or-escalate.sh [--no-fix] [--verbose]
#   --no-fix    ไม่รันสคริปต์แก้
#   --verbose   ส่ง output ของ health-check ไป stdout
#
# Env:
#   OPENCLAW_FIX_SCRIPT   สคริปต์แก้ (default: scripts/ops/gateway-recovery.sh)
#   OPENCLAW_FIX_ARGS    อาร์กิวเมนต์ให้สคริปต์แก้ (default: --no-notify)
#   OPENCLAW_POST_FIX_SLEEP  วินาทีหลังรันแก้ก่อนตรวจซ้ำ (default: 15)
#   OPENCLAW_STATE_DIR   โฟลเดอร์ state (default: ~/.openclaw)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HEALTH_SCRIPT="$REPO_ROOT/scripts/ops/health-check.sh"
FIX_SCRIPT="${OPENCLAW_FIX_SCRIPT:-$REPO_ROOT/scripts/ops/gateway-recovery.sh}"
FIX_ARGS="${OPENCLAW_FIX_ARGS:---no-notify}"
POST_FIX_SLEEP="${OPENCLAW_POST_FIX_SLEEP:-15}"
STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
PENDING_FILE="$STATE_DIR/health-escalation-pending.json"
RUN_FIX=true
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    --no-fix)   RUN_FIX=false ;;
    --verbose)  VERBOSE=true ;;
  esac
done

# ต้องได้ JSON จาก health-check เพื่อเอา .status
if ! command -v jq >/dev/null 2>&1; then
  echo "health-check-fix-or-escalate: jq is required to parse health-check JSON" >&2
  exit 2
fi

if [ ! -x "$HEALTH_SCRIPT" ]; then
  echo "health-check-fix-or-escalate: $HEALTH_SCRIPT not found or not executable" >&2
  exit 2
fi

# --- 1) ตรวจครั้งแรก (ไม่แจ้ง) ---
health_out="$("$HEALTH_SCRIPT" --format json --no-notify 2>/dev/null)" || true
status="$(echo "${health_out:-{\}}" | jq -r '.status // "unknown"')"

if [ "$VERBOSE" = true ]; then
  echo "Health (first check): $status"
  echo "$health_out" | jq -c . 2>/dev/null || echo "$health_out"
fi

# --- 2) ถ้า ok → ลบไฟล์ escalation ถ้ามี แล้วเงียบ ---
if [ "$status" = "ok" ]; then
  [ -f "$PENDING_FILE" ] && rm -f "$PENDING_FILE"
  exit 0
fi

# --- 3) ไม่ ok → รันสคริปต์แก้ (ถ้าเปิดอยู่) ---
if [ "$RUN_FIX" = true ] && [ -x "$FIX_SCRIPT" ]; then
  if [ "$VERBOSE" = true ]; then
    echo "Running fix script: $FIX_SCRIPT $FIX_ARGS"
  fi
  "$FIX_SCRIPT" $FIX_ARGS >/dev/null 2>&1 || true
  sleep "$POST_FIX_SLEEP"
fi

# --- 4) ตรวจซ้ำ ---
health_out2="$("$HEALTH_SCRIPT" --format json --no-notify 2>/dev/null)" || true
status2="$(echo "${health_out2:-{\}}" | jq -r '.status // "unknown"')"

if [ "$VERBOSE" = true ]; then
  echo "Health (after fix): $status2"
  echo "$health_out2" | jq -c . 2>/dev/null || echo "$health_out2"
fi

# --- 5) ถ้าหาย → เงียบ ---
if [ "$status2" = "ok" ]; then
  [ -f "$PENDING_FILE" ] && rm -f "$PENDING_FILE"
  exit 0
fi

# --- 6) ยังไม่หาย → เขียนไฟล์รอ agent (ไม่ส่ง Telegram; agent จะส่งเมื่อแก้ได้หรือแก้ไม่ได้) ---
mkdir -p "$STATE_DIR"
gateway="$(echo "${health_out2:-{\}}" | jq -r '.gateway // "?"')"
gateway_svc="$(echo "${health_out2:-{\}}" | jq -r '.gateway_svc // "?"')"
errors="$(echo "${health_out2:-{\}}" | jq -r '.errors // 0')"
worker="$(echo "${health_out2:-{\}}" | jq -r '.worker // "?"')"
ts_iso="$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)"
jq -n \
  --arg since "$ts_iso" \
  --arg status "$status2" \
  --arg gateway "$gateway" \
  --arg gateway_svc "$gateway_svc" \
  --argjson errors "$errors" \
  --arg worker "$worker" \
  '{ since: $since, status: $status, gateway: $gateway, gateway_svc: $gateway_svc, errors: $errors, worker: $worker }' \
  > "$PENDING_FILE" 2>/dev/null || true

if [ "$status2" = "critical" ]; then
  exit 2
fi
exit 1
