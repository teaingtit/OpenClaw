#!/bin/bash
# สคริปต์ปิด Worker Node (ryzenpc)
# ใช้ ssh_config เดียวกับ father/pull-worker/jit-wrapper (Host: ryzenpc)
SSH_CONFIG="${OPENCLAW_FATHER_SSH_CONFIG:-$HOME/.openclaw/workspace-father/ssh_config}"
echo "💤 กำลังสั่งปิด ryzenpc..."
ssh -F "$SSH_CONFIG" ryzenpc "sudo shutdown -h now"
