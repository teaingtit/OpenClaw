#!/bin/bash
# backlog-bot-commands.sh — รับคำสั่งจาก Backlog Telegram Bot (polling)
# รองรับ: /wake_ryzenpc, /sleep_ryzenpc, /help
# วิธีใช้: รันแบบ one-shot (cron ทุก 1–2 นาที) หรือรันต่อเนื่องด้วย timeout
#   */2 * * * * /home/teaingtit/projects/openclaw/scripts/backlog-bot-commands.sh

set -e

OPENCLAW_ENV="${OPENCLAW_ENV:-/home/teaingtit/.openclaw/.env}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
OFFSET_FILE="$STATE_DIR/backlog-bot-offset"

# โหลด token และ chat_id (ต้องตรงกับ tg-notify.sh)
if [ -r "$OPENCLAW_ENV" ]; then
  BOT_TOKEN=$(grep "^TG_BACKLOG_BOT_TOKEN=" "$OPENCLAW_ENV" 2>/dev/null | cut -d'=' -f2-)
  BACKLOG_CHAT_ID=$(grep "^TG_BACKLOG_CHAT_ID=" "$OPENCLAW_ENV" 2>/dev/null | cut -d'=' -f2-)
fi
[ -z "$BACKLOG_CHAT_ID" ] && BACKLOG_CHAT_ID="6845503187"

if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]; then
  echo "backlog-bot-commands: TG_BACKLOG_BOT_TOKEN not set in $OPENCLAW_ENV" >&2
  exit 0
fi

# อ่าน offset ล่าสุด
OFFSET=0
[ -r "$OFFSET_FILE" ] && OFFSET=$(cat "$OFFSET_FILE")

# Long poll (timeout 25 วินาที — cron จะรันรอบถัดไป)
RESPONSE=$(curl -s -m 30 "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=25" 2>/dev/null || true)

if ! echo "$RESPONSE" | jq -e '.ok == true' >/dev/null 2>&1; then
  exit 0
fi

send_reply() {
  local text="$1"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${BACKLOG_CHAT_ID}" \
    -d text="${text}" \
    -d parse_mode="HTML" >/dev/null
}

process_command() {
  local update_id="$1"
  local chat_id="$2"
  local text="$3"

  # รับเฉพาะจาก Backlog chat
  if [ "$chat_id" != "$BACKLOG_CHAT_ID" ]; then
    return 0
  fi

  # ลบ @botname ออก ถ้ามี
  local cmd="${text%%@*}"
  cmd=$(echo "$cmd" | tr '[:upper:]' '[:lower:]')

  case "$cmd" in
    /wake_ryzenpc)
      send_reply "🛜 กำลังปลุก Worker Node (ryzenpc)..."
      OUT=$("$SCRIPT_DIR/wake-ai.sh" 2>&1) || true
      send_reply "✅ ส่ง WoL แล้ว — ${OUT:-done}"
      ;;
    /sleep_ryzenpc)
      send_reply "💤 กำลังปิด Worker Node (ryzenpc)..."
      "$SCRIPT_DIR/sleep-ai.sh" 2>&1 || true
      send_reply "✅ สั่งปิด ryzenpc แล้ว (เครื่องจะดับในไม่กี่วินาที)"
      ;;
    /help|/start)
      send_reply "📋 <b>Backlog Bot — คำสั่ง Manual</b>

/wake_ryzenpc — ปลุก Worker Node (ryzenpc)
/sleep_ryzenpc — ปิด Worker Node (ryzenpc)
/help — แสดงคำสั่งนี้"
      ;;
    *)
      [ -n "$text" ] && [[ "$text" == /* ]] && send_reply "❓ ไม่รู้จักคำสั่ง: $cmd — ส่ง /help"
      ;;
  esac
}

# ประมวลผลทุก update
LAST_OFFSET="$OFFSET"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  update_id=$(echo "$line" | jq -r '.update_id')
  chat_id=$(echo "$line" | jq -r '.message.chat.id // empty')
  text=$(echo "$line" | jq -r '.message.text // empty')
  [ -z "$text" ] && text=$(echo "$line" | jq -r '.message.caption // empty')

  NEXT=$((update_id + 1))
  [ "$NEXT" -gt "$LAST_OFFSET" ] && LAST_OFFSET="$NEXT"

  process_command "$update_id" "$chat_id" "$text" || true
done < <(echo "$RESPONSE" | jq -c '.result[]? // empty' 2>/dev/null)

# บันทึก offset สำหรับรอบถัดไป
mkdir -p "$STATE_DIR"
echo "$LAST_OFFSET" > "$OFFSET_FILE"

exit 0
