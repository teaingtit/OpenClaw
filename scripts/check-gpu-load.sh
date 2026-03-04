#!/bin/bash
# check-gpu-load.sh
# ตรวจสอบ GPU Load ของ ryzenpc ผ่าน SSH

# เชื่อมต่อด้วย Timeout 10 วิเผื่อเครื่องปิดอยู่
# เราใช้ ssh ของ teaingtit และใช้ batch mode เพื่อไม่ให้มันรอ prompt รหัสผ่านถัา key เสีย
LOAD=$(ssh -F /home/teaingtit/.openclaw/workspace-father/ssh_config -o BatchMode=yes -o ConnectTimeout=10 ryzenpc 'nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$LOAD" ]; then
    # ถ้า SSH ตอบสนองช้า หรือเครื่องปิดอยู่
    echo "OFFLINE"
    exit 1
fi

echo "$LOAD"
exit 0
