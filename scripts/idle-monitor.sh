#!/bin/bash
# idle-monitor.sh
# รันเป็น daemon ตรวจสอบการทำงานของ Worker Node
# ถ้า GPU Load 0% ต่อเนื่อง 60 นาที จะสั่งปิดเครื่อง

IDLE_THRESHOLD_MINUTES=60
COUNTER_FILE="/tmp/ai_idle_counter.txt"
LOG_FILE="/var/log/ai-power.log"

# ตรวจสอบสิทธิ์ว่าสร้าง log ได้ไหม ถ้าไม่ได้ให้เซฟที่ tmp
if ! touch "$LOG_FILE" 2>/dev/null; then
  LOG_FILE="/tmp/ai-power.log"
fi

# อ่านค่า counter ปัจจุบัน
if [ -f "$COUNTER_FILE" ]; then
    IDLE_MINUTES=$(cat "$COUNTER_FILE")
else
    IDLE_MINUTES=0
fi

# เรียกสคริปต์เช็ก GPU Load
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
GPU_LOAD=$("$SCRIPT_DIR/check-gpu-load.sh")

if [ "$GPU_LOAD" == "OFFLINE" ]; then
    # เครื่องปิดอยู่ ไม่ต้องทำอะไร และรีเซ็ต counter
    echo 0 > "$COUNTER_FILE"
    exit 0
fi

if [[ "$GPU_LOAD" =~ ^[0-9]+$ ]] && [ "$GPU_LOAD" -le 0 ]; then
    # ว่างงาน
    ((IDLE_MINUTES++))
    echo "$IDLE_MINUTES" > "$COUNTER_FILE"
else
    # กำลังทำงาน รีเซ็ต
    echo 0 > "$COUNTER_FILE"
    exit 0
fi

# ถ้าว่างเกินขีดจำกัด
if [ "$IDLE_MINUTES" -ge "$IDLE_THRESHOLD_MINUTES" ]; then
    # บันทึก log
    TIMESTAMP=$(date -Iseconds)
    echo "[$TIMESTAMP] ACTION: shutdown | reason: idle ${IDLE_THRESHOLD_MINUTES}m | gpu_load: 0%" >> "$LOG_FILE"
    
    # สั่ง sleep
    "$SCRIPT_DIR/sleep-ai.sh"
    
    # แจ้งเตือนเข้า Telegram
    "$SCRIPT_DIR/tg-notify.sh" "💤 <b>[Auto-Idle] Worker Node Shutdown</b>
ryzenpc ไม่มี GPU Load ต่อเนื่องเป็นเวลา ${IDLE_THRESHOLD_MINUTES} นาที ทำการสั่งปิดเครื่องอัตโนมัติ"
    
    # รีเซ็ต counter หลังจากสั่งปิดไปแล้ว
    echo 0 > "$COUNTER_FILE"
fi

exit 0
