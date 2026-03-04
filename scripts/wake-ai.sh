#!/bin/bash
# สคริปต์ปลุก Worker Node (ryzenpc) จาก Master Node (minipc)
MAC_ADDRESS="d8:43:ae:b6:26:d9"
echo "🛜 กำลังส่ง Magic Packet ไปปลุก ryzenpc (MAC: $MAC_ADDRESS)..."
wakeonlan $MAC_ADDRESS
