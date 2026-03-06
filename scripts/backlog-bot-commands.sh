#!/bin/bash
# backlog-bot-commands.sh — รับคำสั่งจาก Backlog Telegram Bot (polling)
# รองรับ: /wake_ryzenpc, /sleep_ryzenpc, /help
# วิธีใช้: cron ทุก 2 นาที
#   */2 * * * * /home/teaingtit/projects/openclaw/scripts/backlog-bot-commands.sh
#
# ENV vars (ใน ~/.openclaw/.env):
#   TG_BACKLOG_BOT_TOKEN   — Bot token (บังคับ)
#   TG_BACKLOG_CHAT_ID     — Chat ID ปลายทาง (optional fallback: 6845503187)
#   TG_BACKLOG_ALLOWED_UID — Telegram user ID ที่ได้รับอนุญาต (บังคับ — ถ้าไม่ตั้งจะปฏิเสธทุกคำสั่งสำคัญ)

# ──────────────────────────────────────────────
# 0. Lock — ป้องกัน cron ซ้อนทับ
# ──────────────────────────────────────────────
LOCK_FILE="/tmp/backlog-bot-commands.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  # instance ก่อนหน้ากำลังรันอยู่ — ออกเงียบๆ
  exit 0
fi

# ──────────────────────────────────────────────
# 1. โหลดค่า config
# ──────────────────────────────────────────────
OPENCLAW_ENV="${OPENCLAW_ENV:-$HOME/.openclaw/.env}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
OFFSET_FILE="$STATE_DIR/backlog-bot-offset"

if [ -r "$OPENCLAW_ENV" ]; then
  BOT_TOKEN=$(grep    "^TG_BACKLOG_BOT_TOKEN="   "$OPENCLAW_ENV" 2>/dev/null | cut -d'=' -f2-)
  BACKLOG_CHAT_ID=$(grep "^TG_BACKLOG_CHAT_ID="  "$OPENCLAW_ENV" 2>/dev/null | cut -d'=' -f2-)
  ALLOWED_UID=$(grep  "^TG_BACKLOG_ALLOWED_UID=" "$OPENCLAW_ENV" 2>/dev/null | cut -d'=' -f2-)
fi

[ -z "$BACKLOG_CHAT_ID" ] && BACKLOG_CHAT_ID="6845503187"

if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]; then
  echo "backlog-bot-commands: TG_BACKLOG_BOT_TOKEN not set in $OPENCLAW_ENV" >&2
  exit 0
fi

# ──────────────────────────────────────────────
# 2. ตรวจ webhook conflict ก่อน poll
# ──────────────────────────────────────────────
WEBHOOK_INFO=$(curl -s -m 10 "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo" 2>/dev/null || true)
WEBHOOK_URL=$(echo "$WEBHOOK_INFO" | jq -r '.result.url // ""' 2>/dev/null)
if [ -n "$WEBHOOK_URL" ]; then
  echo "backlog-bot-commands: bot มี webhook อยู่ที่ $WEBHOOK_URL — polling จะไม่ได้รับ updates" >&2
  echo "backlog-bot-commands: ถ้าต้องการใช้ polling ให้รัน: curl -s -X POST https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook" >&2
  exit 1
fi

# ──────────────────────────────────────────────
# 3. อ่าน offset ล่าสุด
# ──────────────────────────────────────────────
OFFSET=0
[ -r "$OFFSET_FILE" ] && OFFSET=$(cat "$OFFSET_FILE")

# Long poll 25 วินาที (cron interval 2 min ให้เวลาเพียงพอ)
RESPONSE=$(curl -s -m 30 \
  "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=25" \
  2>/dev/null || true)

if ! echo "$RESPONSE" | jq -e '.ok == true' >/dev/null 2>&1; then
  exit 0
fi

# ──────────────────────────────────────────────
# 4. Helper: ส่งข้อความกลับ Backlog chat
# ──────────────────────────────────────────────
send_reply() {
  local text="$1"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${BACKLOG_CHAT_ID}" \
    -d text="${text}" \
    -d parse_mode="HTML" >/dev/null
}

# ──────────────────────────────────────────────
# 5. ประมวลผลแต่ละ update
# ──────────────────────────────────────────────
process_command() {
  local chat_id="$1"
  local sender_id="$2"
  local text="$3"

  # (A) รับเฉพาะแชท Backlog
  if [ "$chat_id" != "$BACKLOG_CHAT_ID" ]; then
    return 0
  fi

  # (B) ตรวจสิทธิ์ user — อนุญาตเฉพาะ TG_BACKLOG_ALLOWED_UID
  if [ -z "$ALLOWED_UID" ]; then
    send_reply "⛔ ไม่สามารถรับคำสั่งได้: TG_BACKLOG_ALLOWED_UID ยังไม่ได้ตั้งค่า ใน ~/.openclaw/.env"
    return 0
  fi
  if [ "$sender_id" != "$ALLOWED_UID" ]; then
    send_reply "⛔ ไม่อนุญาต: user ID $sender_id ไม่อยู่ใน allowlist"
    return 0
  fi

  # ลบ @botname suffix ถ้ามี แล้วทำตัวพิมพ์เล็ก
  local cmd
  cmd="${text%%@*}"
  cmd=$(echo "$cmd" | tr '[:upper:]' '[:lower:]')

  case "$cmd" in
    /wake_ryzenpc)
      send_reply "🛜 กำลังปลุก Worker Node (ryzenpc)..."
      OUT=$("$SCRIPT_DIR/wake-ai.sh" 2>&1)
      RC=$?
      if [ $RC -eq 0 ]; then
        # wake-ai.sh ส่ง tg-notify เองแล้ว — ตอบสั้นๆ ยืนยัน
        send_reply "✅ <b>wake-ai.sh</b> รันสำเร็จ"
      else
        ERRMSG=$(echo "$OUT" | tail -3)
        send_reply "❌ <b>wake-ai.sh ล้มเหลว</b> (exit $RC)
<code>${ERRMSG}</code>"
      fi
      ;;

    /sleep_ryzenpc)
      send_reply "💤 กำลังปิด Worker Node (ryzenpc)..."
      OUT=$("$SCRIPT_DIR/sleep-ai.sh" 2>&1)
      RC=$?
      if [ $RC -eq 0 ]; then
        send_reply "✅ สั่งปิด ryzenpc สำเร็จ — เครื่องจะดับในไม่กี่วินาที"
      else
        ERRMSG=$(echo "$OUT" | tail -3)
        send_reply "❌ <b>sleep-ai.sh ล้มเหลว</b> (exit $RC)
<code>${ERRMSG}</code>"
      fi
      ;;

    /help|/start)
      send_reply "📋 <b>Backlog Bot — คำสั่ง Manual</b>

/wake_ryzenpc — ปลุก Worker Node (ryzenpc)
/sleep_ryzenpc — ปิด Worker Node (ryzenpc)
/help — แสดงคำสั่งนี้"
      ;;

    *)
      # ตอบเฉพาะข้อความที่ขึ้นต้นด้วย /
      [[ "$text" == /* ]] && send_reply "❓ ไม่รู้จักคำสั่ง: <code>$cmd</code> — ส่ง /help"
      ;;
  esac
}

# ──────────────────────────────────────────────
# 6. วนประมวลผลทุก update และอัปเดต offset
# ──────────────────────────────────────────────
LAST_OFFSET="$OFFSET"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  update_id=$(echo "$line" | jq -r '.update_id')
  chat_id=$(echo "$line"   | jq -r '.message.chat.id   // empty')
  sender_id=$(echo "$line" | jq -r '.message.from.id   // empty')
  text=$(echo "$line"      | jq -r '.message.text      // empty')
  [ -z "$text" ] && text=$(echo "$line" | jq -r '.message.caption // empty')

  NEXT=$((update_id + 1))
  [ "$NEXT" -gt "$LAST_OFFSET" ] && LAST_OFFSET="$NEXT"

  process_command "$chat_id" "$sender_id" "$text" || true
done < <(echo "$RESPONSE" | jq -c '.result[]? // empty' 2>/dev/null)

# บันทึก offset สำหรับรอบถัดไป
mkdir -p "$STATE_DIR"
echo "$LAST_OFFSET" > "$OFFSET_FILE"

exit 0
