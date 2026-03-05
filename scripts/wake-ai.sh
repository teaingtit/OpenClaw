#!/bin/bash
# สคริปต์ปลุก Worker Node (ryzenpc) จาก Master Node (minipc)
# หลังส่ง WoL จะรอตรวจว่า SSH พร้อม แล้วแจ้ง Backlog Telegram
set -e

MAC_ADDRESS="d8:43:ae:b6:26:d9"
SSH_CONFIG="${OPENCLAW_FATHER_SSH_CONFIG:-$HOME/.openclaw/workspace-father/ssh_config}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MAX_WAIT_SECONDS="${WAKE_AI_TIMEOUT:-90}"

echo "🛜 กำลังส่ง Magic Packet ไปปลุก ryzenpc (MAC: $MAC_ADDRESS)..."
wakeonlan "$MAC_ADDRESS"

echo "⏳ รอตรวจว่า ryzenpc ตื่น (timeout: ${MAX_WAIT_SECONDS}s)..."
START_TIME=$(date +%s)

while true; do
    if ssh -F "$SSH_CONFIG" -o ConnectTimeout=2 -o BatchMode=yes ryzenpc "echo OK" >/dev/null 2>&1; then
        echo "✅ ryzenpc ตื่นแล้ว — SSH พร้อม"
        "$SCRIPT_DIR/tg-notify.sh" "✅ <b>Worker Node (ryzenpc)</b> ตื่นแล้ว — SSH พร้อมใช้งาน ($(date +%H:%M))"
        exit 0
    fi
    CURRENT=$(date +%s)
    ELAPSED=$((CURRENT - START_TIME))
    if [ "$ELAPSED" -ge "$MAX_WAIT_SECONDS" ]; then
        echo "⚠️ Timeout: ryzenpc ยังไม่ตอบสนองหลัง ${MAX_WAIT_SECONDS}s"
        "$SCRIPT_DIR/tg-notify.sh" "⚠️ <b>Worker Node (ryzenpc)</b> ส่ง WoL แล้วแต่ยังไม่ตอบสนอง (timeout ${MAX_WAIT_SECONDS}s)"
        exit 1
    fi
    sleep 5
done
