#!/bin/bash
# backup-config.sh
# สำรอง openclaw.json อัตโนมัติ พร้อม Rotate ไม่ให้ disk เต็ม
# รันทุก 6 ชั่วโมงผ่าน systemd timer

CONFIG_SRC="/home/teaingtit/.openclaw/openclaw.json"
BACKUP_DIR="/home/teaingtit/.openclaw/backup"
KEEP_DAYS=7   # เก็บ backup ไว้ 7 วัน
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

mkdir -p "$BACKUP_DIR"

# ตรวจสอบว่า config ปัจจุบัน valid JSON ไหม
if ! python3 -c "import json; json.load(open('$CONFIG_SRC'))" 2>/dev/null; then
    "$SCRIPT_DIR/tg-notify.sh" "⚠️ <b>[Config Backup] WARNING</b>
openclaw.json ไม่ใช่ JSON ที่ถูกต้อง! ไม่สำรองไฟล์นี้
กรุณาตรวจสอบ: <code>$CONFIG_SRC</code>"
    exit 1
fi

# ตรวจสอบ critical config keys ทั้งหมด (lesson learned จากเหตุการณ์ 2026-03-02)
GATEWAY_MODE=$(python3 -c "import json; d=json.load(open('$CONFIG_SRC')); print(d.get('gateway',{}).get('mode','MISSING'))" 2>/dev/null)
GATEWAY_AUTH=$(python3 -c "import json; d=json.load(open('$CONFIG_SRC')); print('OK' if d.get('gateway',{}).get('auth') else 'MISSING')" 2>/dev/null)
AGENT_DEFAULT_MODEL=$(python3 -c "import json; d=json.load(open('$CONFIG_SRC')); print(d.get('agents',{}).get('defaults',{}).get('model',{}).get('primary','MISSING'))" 2>/dev/null)
INTER_AGENT=$(python3 -c "import json; d=json.load(open('$CONFIG_SRC')); print('OK' if d.get('tools',{}).get('agentToAgent',{}).get('enabled') and d.get('tools',{}).get('sessions',{}).get('visibility')=='all' else 'MISSING')" 2>/dev/null)
MODEL_PREFIX_OK=$(python3 -c "
import json; d=json.load(open('$CONFIG_SRC'))
agents = d.get('agents',{}).get('list',[])
bad = [a['id'] for a in agents if a.get('model',{}).get('primary','').startswith('openrouter/') is False and a.get('model',{}).get('primary','') != '']
bad += ['agents.defaults' ] if not d.get('agents',{}).get('defaults',{}).get('model',{}).get('primary','').startswith('openrouter/') else []
print('BAD:' + ','.join(bad) if bad else 'OK')
" 2>/dev/null)

WARNINGS=""
[ "$GATEWAY_MODE" == "MISSING" ] && WARNINGS+="gateway.mode MISSING\n"
[ "$GATEWAY_AUTH" == "MISSING" ] && WARNINGS+="gateway.auth MISSING\n"
[ "$AGENT_DEFAULT_MODEL" == "MISSING" ] && WARNINGS+="agents.defaults.model.primary MISSING — gateway fallback ไป anthropic direct\n"
[ "$INTER_AGENT" == "MISSING" ] && WARNINGS+="tools.agentToAgent หรือ tools.sessions.visibility ไม่ครบ — delegation ล้มเหลว\n"
[[ "$MODEL_PREFIX_OK" == BAD:* ]] && WARNINGS+="Model prefix ผิด (ไม่มี openrouter/): ${MODEL_PREFIX_OK#BAD:}\n"

if [ -n "$WARNINGS" ]; then
    "$SCRIPT_DIR/tg-notify.sh" "⚠️ <b>[Config Backup] CRITICAL WARNING</b>
ตรวจพบ config ไม่ครบถ้วน:
<pre>${WARNINGS}</pre>
กรุณารัน: <code>openclaw doctor</code>"
    # ยังสำรองไว้เพื่อมีหลักฐาน
fi

# บันทึก backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/openclaw.${TIMESTAMP}.json"
cp "$CONFIG_SRC" "$BACKUP_FILE"
echo "[$( date -Iseconds)] Backed up to $BACKUP_FILE (gateway.mode=$GATEWAY_MODE)" >> /tmp/backup-config.log

# Rotate เก็บไว้แค่ 7 วัน
find "$BACKUP_DIR" -name "openclaw.*.json" -mtime +$KEEP_DAYS -delete

exit 0
