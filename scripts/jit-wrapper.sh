#!/bin/bash
# jit-wrapper.sh
# Wrapper สำหรับปลุก Worker Node (ryzenpc) อัตโนมัติเมื่อมีการเรียกใช้งาน
# วิธีใช้: ./jit-wrapper.sh "คำสั่งที่ต้องการรันบน ryzenpc"
# ตัวอย่าง: ./jit-wrapper.sh "ollama run llama3"

TARGET_IP="192.168.1.27"
TARGET_HOST="ryzenpc"
MAX_WAIT_SECONDS=90
LOG_FILE="/var/log/ai-power.log"

# តรวจสอบอาร์กิวเมนต์
if [ -z "$1" ]; then
    echo "Usage: $0 \"<command_to_run>\""
    exit 1
fi
PAYLOAD="$1"

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# 1. เช็กว่าเครื่องเปิดอยู่ไหมด้วย Ping
if ping -c 1 -W 1 "$TARGET_IP" >/dev/null 2>&1; then
    # เครื่องเปิดอยู่แล้ว รันคำสั่งได้เลย
    ssh -F /home/teaingtit/.openclaw/workspace-father/ssh_config "$TARGET_HOST" "$PAYLOAD"
    exit $?
fi

# 2. เครื่องปิดอยู่ -> สั่งปลุก
echo "⚠️ Worker Node (ryzenpc) was sleeping. Waking it up..."
TIMESTAMP=$(date -Iseconds)
if touch "$LOG_FILE" 2>/dev/null; then
    echo "[$TIMESTAMP] ACTION: wake-up | reason: jit_inference_request" >> "$LOG_FILE"
fi

"$SCRIPT_DIR/tg-notify.sh" "⚡ <b>[JIT Inference] Waking up Worker Node</b>
ระบบได้รับ Request แต่ ryzenpc ปิดอยู่ กำลังทำการ Wake-on-LAN และรอการเชื่อมต่อ (ETA: 40s)
<b>คำสั่ง:</b> <code>${PAYLOAD}</code>"

"$SCRIPT_DIR/wake-ai.sh"

# 3. Healthcheck Loop -> รอให้ SSH พร้อมใช้งาน
echo "🔄 Waiting for SSH to become available (timeout: ${MAX_WAIT_SECONDS}s)..."
START_TIME=$(date +%s)

while true; do
    # ลอง SSH แบบเร็วๆ (timeout 2 วิ)
    if ssh -F /home/teaingtit/.openclaw/workspace-father/ssh_config -o ConnectTimeout=2 -o BatchMode=yes "$TARGET_HOST" "echo OK" >/dev/null 2>&1; then
        echo "✅ Worker Node is ready!"
        break
    fi
    
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ "$ELAPSED" -ge "$MAX_WAIT_SECONDS" ]; then
        echo "❌ ERROR: Worker Node did not respond within $MAX_WAIT_SECONDS seconds."
        exit 1
    fi
    
    sleep 5
done

# 4. เมื่อเครื่องพร้อมแล้ว ค่อยรันคำสั่งที่ขอมาตอนแรก
echo "🚀 Executing requested payload..."
ssh -F /home/teaingtit/.openclaw/workspace-father/ssh_config "$TARGET_HOST" "$PAYLOAD"
exit $?
