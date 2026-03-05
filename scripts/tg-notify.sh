#!/bin/bash
# tg-notify.sh
# สคริปต์สำหรับส่งแจ้งเตือนเข้า Telegram Bot โดยตรง (ไม่ผ่าน LLM/Sunday)
# วิธีใช้: ./tg-notify.sh "ข้อความที่ต้องการส่ง"

# ==========================================
# Bot Configuration (see ANTIGRAVITY.md §3b)
# TELEGRAM_BOT_TOKEN    = ZeeXa Bot  → พูดคุยและสั่งงานเท่านั้น (ห้ามใช้ส่งแจ้งเตือน)
# TG_BACKLOG_BOT_TOKEN  = BACK_LOG Bot → การแจ้งเตือนทั้งหมด (script นี้ใช้ token นี้เท่านั้น)
# ==========================================
BOT_TOKEN=$(grep "^TG_BACKLOG_BOT_TOKEN=" /home/teaingtit/.openclaw/.env 2>/dev/null | cut -d'=' -f2)
CHAT_ID="6845503187"

# เช็กข้อความ
MESSAGE="$1"
if [ -z "$MESSAGE" ]; then
    echo "Usage: $0 \"<message>\""
    exit 1
fi

# เช็ก Token — ตรวจทั้ง empty และ placeholder
if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" == "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]; then
    echo "⚠️ Warning: TG_BACKLOG_BOT_TOKEN is not configured in ~/.openclaw/.env. Notification skipped."
    exit 0
fi

# ส่ง request ไปยัง Telegram API (ใช้ MarkdownV2 แบบง่ายๆ หรือปิด parse_mode ไปเลยเพื่อกัน error อักขระพิเศษ)
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${MESSAGE}" \
    -d parse_mode="HTML" > /dev/null

exit 0
