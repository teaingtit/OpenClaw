#!/bin/bash
# tg-notify.sh
# สคริปต์สำหรับส่งแจ้งเตือนเข้า Telegram Bot โดยตรง (ไม่ผ่าน LLM/Sunday)
# วิธีใช้: ./tg-notify.sh "ข้อความที่ต้องการส่ง"

# ==========================================
# Bot Configuration
# TELEGRAM_BOT_TOKEN    = @ZeeXaBOT       → ใช้สำหรับ Sunday AI Agent เท่านั้น
# TG_BACKLOG_BOT_TOKEN  = BACK_LOG Bot    → ใช้สำหรับ System Alert / Power Events
# ==========================================
BOT_TOKEN=$(grep "^TG_BACKLOG_BOT_TOKEN=" /home/teaingtit/.openclaw/.env 2>/dev/null | cut -d'=' -f2)
CHAT_ID="6845503187"

# เช็กข้อความ
MESSAGE="$1"
if [ -z "$MESSAGE" ]; then
    echo "Usage: $0 \"<message>\""
    exit 1
fi

# เช็ก Token
if [ "$BOT_TOKEN" == "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]; then
    echo "⚠️ Warning: Telegram BOT_TOKEN is not configured in $0. Notification skipped."
    exit 0
fi

# ส่ง request ไปยัง Telegram API (ใช้ MarkdownV2 แบบง่ายๆ หรือปิด parse_mode ไปเลยเพื่อกัน error อักขระพิเศษ)
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${MESSAGE}" \
    -d parse_mode="HTML" > /dev/null

exit 0
