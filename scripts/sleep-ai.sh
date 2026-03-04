#!/bin/bash
# สคริปต์ปิด Worker Node (ryzenpc)
echo "💤 กำลังสั่งปิด ryzenpc..."
ssh teaingtit@192.168.1.27 "sudo shutdown -h now"
