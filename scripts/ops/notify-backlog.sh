#!/usr/bin/env bash
# notify-backlog.sh — ส่งแจ้งเตือนเข้า BACK_LOG Bot ตาม template (แทนการ spawn Notifier เมื่อข้อความพร้อมแล้ว)
# ใช้เมื่อ caller (architect, intel, script) มี title/body พร้อมแล้ว ไม่ต้องให้ Notifier agent จัดรูปแบบ
#
# Usage: notify-backlog.sh --type escalation|intel_digest|alert --title "..." --body "..."
#   หรือส่งข้อความตรง: notify-backlog.sh --raw "ข้อความเต็ม"
# Env: OPENCLAW_REPO (path to repo for tg-notify.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${OPENCLAW_REPO:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
NOTIFY_SCRIPT="$REPO_ROOT/scripts/tg-notify.sh"

TYPE=""
TITLE=""
BODY=""
RAW=""

while [ $# -gt 0 ]; do
  case "$1" in
    --type)   TYPE="${2:-}"; shift 2 || shift ;;
    --title)  TITLE="${2:-}"; shift 2 || shift ;;
    --body)   BODY="${2:-}"; shift 2 || shift ;;
    --raw)    RAW="${2:-}"; shift 2 || shift ;;
    *) shift ;;
  esac
done

if [ -n "$RAW" ]; then
  msg="$RAW"
elif [ -n "$TYPE" ] && [ -n "$TITLE" ]; then
  case "$TYPE" in
    escalation)   msg="🆘 [BACKLOG] $TITLE${BODY:+$'\n'}$BODY" ;;
    intel_digest) msg="🧠 Daily Intel — $TITLE${BODY:+$'\n'}$BODY" ;;
    alert)        msg="⚠️ System Alert: $TITLE${BODY:+$'\n'}$BODY" ;;
    *)            msg="$TITLE${BODY:+ — }$BODY" ;;
  esac
else
  echo "Usage: notify-backlog.sh --type escalation|intel_digest|alert --title \"...\" --body \"...\""
  echo "   or: notify-backlog.sh --raw \"message\""
  exit 1
fi

[ ! -x "$NOTIFY_SCRIPT" ] && { echo "notify-backlog: $NOTIFY_SCRIPT not executable" >&2; exit 1; }
"$NOTIFY_SCRIPT" "$msg"
