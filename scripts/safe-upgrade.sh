#!/bin/bash
# safe-upgrade.sh — อัปเกรด OpenClaw Gateway อย่างปลอดภัย
# ขั้นตอน: backup → upgrade → validate → restart → notify
#
# ใช้งาน:
#   bash ~/projects/openclaw/scripts/safe-upgrade.sh           # อัปเกรดเป็น latest
#   bash ~/projects/openclaw/scripts/safe-upgrade.sh 2026.3.5  # อัปเกรดเป็น version เฉพาะ

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_SRC="/home/teaingtit/.openclaw/openclaw.json"
BACKUP_DIR="/home/teaingtit/.openclaw/backup"
LOG_DIR="/home/teaingtit/.openclaw/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/upgrade.log"
VERSION_TARGET="${1:-latest}"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"; }
notify() { "$SCRIPT_DIR/tg-notify.sh" "$1" 2>/dev/null || true; }

log "=== OpenClaw Safe Upgrade: $VERSION_TARGET ==="

# --- ขั้นตอนที่ 1: บันทึก version ปัจจุบัน ---
CURRENT_VER=$(/home/linuxbrew/.linuxbrew/bin/openclaw --version 2>/dev/null || echo "unknown")
log "Current version: $CURRENT_VER"

# --- ขั้นตอนที่ 2: Backup config ก่อน upgrade ---
log "Backing up openclaw.json..."
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/pre-upgrade-${CURRENT_VER}-${TIMESTAMP}.json"
cp "$CONFIG_SRC" "$BACKUP_FILE"
log "Backup saved: $BACKUP_FILE"

# สำรอง sessions ทั้งหมดด้วย
SESSION_BACKUP="$BACKUP_DIR/sessions-pre-upgrade-${TIMESTAMP}.tar.gz"
tar -czf "$SESSION_BACKUP" -C /home/teaingtit/.openclaw agents/*/sessions/ 2>/dev/null || true
log "Sessions backup: $SESSION_BACKUP"

# --- ขั้นตอนที่ 3: จดจำ critical config keys ---
log "Saving critical config snapshot..."
python3 - <<'PYEOF' >> "$LOG_FILE" 2>&1
import json, sys
d = json.load(open("/home/teaingtit/.openclaw/openclaw.json"))
keys = {
    "agents.defaults.model.primary": d.get("agents", {}).get("defaults", {}).get("model", {}).get("primary", "MISSING"),
    "tools.agentToAgent.enabled": d.get("tools", {}).get("agentToAgent", {}).get("enabled", "MISSING"),
    "tools.sessions.visibility": d.get("tools", {}).get("sessions", {}).get("visibility", "MISSING"),
    "channels.telegram.enabled": d.get("channels", {}).get("telegram", {}).get("enabled", "MISSING"),
    "channels.telegram.groupPolicy": d.get("channels", {}).get("telegram", {}).get("groupPolicy", "MISSING"),
    "gateway.mode": d.get("gateway", {}).get("mode", "MISSING"),
}
for k, v in keys.items():
    print(f"  {k} = {v}")
PYEOF

# --- ขั้นตอนที่ 4: รัน upgrade ---
log "Upgrading openclaw to $VERSION_TARGET..."
if [ "$VERSION_TARGET" == "latest" ]; then
    sudo /home/linuxbrew/.linuxbrew/bin/npm i -g openclaw@latest 2>&1 | tee -a "$LOG_FILE"
else
    sudo /home/linuxbrew/.linuxbrew/bin/npm i -g "openclaw@${VERSION_TARGET}" 2>&1 | tee -a "$LOG_FILE"
fi

NEW_VER=$(/home/linuxbrew/.linuxbrew/bin/openclaw --version 2>/dev/null || echo "unknown")
log "Upgraded: $CURRENT_VER → $NEW_VER"

# อัปเดต description ใน systemd service ด้วย
if [ "$NEW_VER" != "$CURRENT_VER" ]; then
    sed -i "s/Description=OpenClaw Gateway (v.*)/Description=OpenClaw Gateway (v${NEW_VER})/" \
        /home/teaingtit/.config/systemd/user/openclaw-gateway.service 2>/dev/null || true
    sed -i "s/OPENCLAW_SERVICE_VERSION=.*/OPENCLAW_SERVICE_VERSION=${NEW_VER}/" \
        /home/teaingtit/.config/systemd/user/openclaw-gateway.service 2>/dev/null || true
fi

# --- ขั้นตอนที่ 5: Validate config หลัง upgrade ---
log "Validating critical config keys..."
ERRORS=0
set +e
python3 - <<'PYEOF'
import json, sys
d = json.load(open("/home/teaingtit/.openclaw/openclaw.json"))
checks = [
    ("agents.defaults.model.primary", d.get("agents", {}).get("defaults", {}).get("model", {}).get("primary")),
    ("tools.agentToAgent.enabled", d.get("tools", {}).get("agentToAgent", {}).get("enabled")),
    ("tools.sessions.visibility", d.get("tools", {}).get("sessions", {}).get("visibility")),
    ("channels.telegram.enabled", d.get("channels", {}).get("telegram", {}).get("enabled")),
    ("gateway.mode", d.get("gateway", {}).get("mode")),
]
errors = 0
for k, v in checks:
    if v is None or v == "" or v == "MISSING":
        print(f"MISSING: {k}", file=sys.stderr)
        errors += 1
    else:
        print(f"OK: {k} = {v}")
sys.exit(errors)
PYEOF
ERRORS=$?
set -e

# --- ขั้นตอนที่ 6: Restart gateway ---
log "Restarting openclaw-gateway.service..."
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service
sleep 5

# ตรวจสอบว่า gateway ขึ้นมาได้
if systemctl --user is-active --quiet openclaw-gateway.service; then
    log "Gateway is running ✓"
    GATEWAY_STATUS="✅ Gateway ทำงานปกติ"
else
    log "ERROR: Gateway failed to start!"
    GATEWAY_STATUS="❌ Gateway ไม่สามารถเริ่มทำงานได้"
    ERRORS=$((ERRORS + 1))
fi

# --- ขั้นตอนที่ 7: รัน doctor check ---
log "Running openclaw doctor..."
DOCTOR_OUTPUT=$(/home/linuxbrew/.linuxbrew/bin/openclaw doctor 2>&1 | tail -20 || true)
log "Doctor output: $DOCTOR_OUTPUT"

# --- สรุปผลและแจ้งเตือน ---
if [ "$ERRORS" -eq 0 ]; then
    notify "✅ <b>OpenClaw Upgrade สำเร็จ</b>
เวอร์ชัน: <code>${CURRENT_VER}</code> → <code>${NEW_VER}</code>
${GATEWAY_STATUS}
Backup: <code>${BACKUP_FILE}</code>"
    log "Upgrade completed successfully."
else
    notify "⚠️ <b>OpenClaw Upgrade มีปัญหา</b>
เวอร์ชัน: <code>${CURRENT_VER}</code> → <code>${NEW_VER}</code>
${GATEWAY_STATUS}
พบ <b>${ERRORS} ปัญหา</b> — กรุณาตรวจสอบ:
<code>cat $LOG_FILE</code>
<code>openclaw doctor</code>
Backup อยู่ที่: <code>${BACKUP_FILE}</code>"
    log "Upgrade completed with $ERRORS issue(s). Check $LOG_FILE"
fi

exit "$ERRORS"
