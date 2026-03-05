#!/bin/bash
# set-backlog-bot-commands.sh — ลงทะเบียนคำสั่ง (menu) ให้ Backlog Telegram Bot
# รันครั้งเดียว (หรือเมื่อเพิ่มคำสั่งใหม่) เพื่อให้ปุ่มเมนูแสดง /wake_ryzenpc, /sleep_ryzenpc

OPENCLAW_ENV="${OPENCLAW_ENV:-/home/teaingtit/.openclaw/.env}"
if [ -r "$OPENCLAW_ENV" ]; then
  BOT_TOKEN=$(grep "^TG_BACKLOG_BOT_TOKEN=" "$OPENCLAW_ENV" 2>/dev/null | cut -d'=' -f2-)
fi

if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]; then
  echo "TG_BACKLOG_BOT_TOKEN not set in $OPENCLAW_ENV" >&2
  exit 1
fi

# Telegram setMyCommands — ใช้ได้กับ BotFather / เมนูคำสั่ง
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setMyCommands" \
  -H "Content-Type: application/json" \
  -d '{
    "commands": [
      {"command": "wake_ryzenpc", "description": "ปลุก Worker Node (ryzenpc)"},
      {"command": "sleep_ryzenpc", "description": "ปิด Worker Node (ryzenpc)"},
      {"command": "help", "description": "แสดงคำสั่ง"}
    ]
  }' | jq .

echo "ถ้า ok=true แสดงว่าตั้งค่าเมนู Backlog bot เรียบร้อยแล้ว"
