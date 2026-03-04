#!/bin/bash
# pre-warm-ai.sh
# สคริปต์ตั้งเวลาปลุก Worker Node (ryzenpc) ล่วงหน้าสำหรับงาน Routine
# การใช้งาน: ./pre-warm-ai.sh "เหตุผลการปลุก"
# ตัวอย่างใน Crontab (ปลุก 07:55 น.):
# 55 07 * * * /home/teaingtit/projects/openclaw/scripts/pre-warm-ai.sh "Daily News Summary / Batch Report"

REASON=${1:-"Scheduled Routine Task"}

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_FILE="/var/log/ai-power.log"

echo "⏰ [Pre-warming] Waking up ryzenpc for: $REASON"

# 1. บันทึก Log
TIMESTAMP=$(date -Iseconds)
if touch "$LOG_FILE" 2>/dev/null; then
    echo "[$TIMESTAMP] ACTION: wake-up | reason: pre_warm ($REASON)" >> "$LOG_FILE"
fi

# 2. ปลุกเครื่อง
"$SCRIPT_DIR/wake-ai.sh"

# 3. แจ้งเตือนเข้า Telegram โดยตรง (ประหยัด Token)
"$SCRIPT_DIR/tg-notify.sh" "⏰ <b>การแจ้งเตือนจาก Master Node</b>
เพิ่งทำการปลุก Worker Node (ryzenpc) ล่วงหน้า
<b>เหตุผล:</b> ${REASON}
โปรดเตรียมพร้อมรับการประมวลผลในอีก 30 วินาที"

echo "✅ Pre-warming complete. Node should be ready in ~30 seconds."
exit 0
