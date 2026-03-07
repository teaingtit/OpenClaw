# Systemd user units — OS-level gateway auto-recovery

เมื่อ gateway ล่มหรือ restart loop, agent (Monitor/Mother) รันไม่ได้เพราะอยู่ภายใน gateway. การกู้ต้องทำที่ **ระดับ OS** ด้วย timer ที่รันสคริปต์ health-check แล้วถ้าไม่ OK จะรัน gateway-recovery ให้อัตโนมัติ.

## Flow

- **Timer** ทุก 15 นาที รัน **service**
- **Service** รัน `health-check-fix-or-escalate.sh`:
  1. รัน health-check (ไม่แจ้ง Telegram)
  2. ถ้า status เป็น ok → ลบไฟล์ escalation ถ้ามี, exit เงียบ
  3. ถ้า warning/critical → รัน `gateway-recovery.sh` (free port + restart gateway)
  4. รัน health-check อีกครั้ง
  5. ถ้าหาย (ok) → exit เงียบ
  6. ถ้ายังไม่หาย → เขียน `~/.openclaw/health-escalation-pending.json` (ไม่ส่ง Telegram ทันที; agent อ่านแล้วลองแก้ แล้วค่อยแจ้งเมื่อแก้ได้หรือแก้ไม่ได้)

อ้างอิง: `docs/HEALTH_ESCALATION.md`, ANTIGRAVITY §6b, §10.1c.

## ขั้นตอนติดตั้ง (บน host ที่รัน gateway)

### 1. ตรวจสอบความต้องการ

- **jq** ต้องติดตั้งไว้ (สคริปต์ใช้ parse JSON จาก health-check)
  ```bash
  jq --version || sudo apt install -y jq   # หรือตาม distro
  ```
- โคลน openclaw อยู่ที่ path ที่รู้ (เช่น `/home/you/projects/openclaw`)

### 2. คัดลอก unit ไปที่ config ของ user

```bash
mkdir -p ~/.config/systemd/user
cp scripts/systemd-user/openclaw-health.service ~/.config/systemd/user/
cp scripts/systemd-user/openclaw-health.timer   ~/.config/systemd/user/
```

(รันจาก repo root ของ openclaw)

### 3. แก้ path ใน service

แก้ไฟล์ `~/.config/systemd/user/openclaw-health.service` ให้ทั้ง `WorkingDirectory` และ `ExecStart` ชี้ไปที่ **repo root** ของคุณ (systemd ต้องการ absolute path ใน ExecStart):

```ini
WorkingDirectory=/home/you/projects/openclaw
ExecStart=/home/you/projects/openclaw/scripts/ops/health-check-fix-or-escalate.sh
```

(แทนที่ `/home/you/projects/openclaw` ด้วย path จริง)

### 4. โหลดและเปิดใช้ timer

```bash
systemctl --user daemon-reload
systemctl --user enable --now openclaw-health.timer
```

### 5. ตรวจสอบว่า timer ทำงาน

```bash
systemctl --user list-timers openclaw-health.timer
```

ควรเห็น `openclaw-health.timer` อยู่ในรายการ และมี next run ประมาณ 2 นาทีหลัง boot หรือ 15 นาทีหลัง run ล่าสุด.

รัน service ด้วยมือ (ทดสอบ):

```bash
systemctl --user start openclaw-health.service
journalctl --user -u openclaw-health.service -n 30
```

## ปิดการทำงาน

```bash
systemctl --user disable --now openclaw-health.timer
```

## หมายเหตุ

- ใช้ได้กับ **user session** (systemd --user). ถ้า gateway รันเป็น user service (`openclaw-gateway.service` ของ user) ใช้ timer นี้ร่วมกันได้.
- ถ้าเปิด timer นี้แล้ว สามารถลด Monitor heartbeat เป็น 24h หรือปิดได้ เพื่อลดโทเคน (ANTIGRAVITY §10.1d).

## openclaw-sot-sync

Path watcher ที่ trigger `gen-agent-index.sh` อัตโนมัติเมื่อ `openclaw.json` หรือ `DetailHardware.md` เปลี่ยน — รับมือ atomic write (write-to-temp + mv) โดยใช้ `PathChanged=` แทน `PathModified=`.

**Flow:**

- `openclaw-sot-sync.path` watches `~/.openclaw/openclaw.json` + `projects/openclaw/DetailHardware.md`
- เมื่อไฟล์เปลี่ยน → trigger `openclaw-sot-sync.service`
- Service รัน `gen-agent-index.sh` → regenerate agent table ใน `SYSTEM_INDEX.md`
- `SuccessExitStatus=0 1` — exit 1 (drift fixed) ไม่นับเป็น failure

**ขั้นตอนติดตั้ง:**

```bash
mkdir -p ~/.config/systemd/user
cp scripts/systemd-user/openclaw-sot-sync.path ~/.config/systemd/user/
cp scripts/systemd-user/openclaw-sot-sync.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now openclaw-sot-sync.path
```

**ตรวจสอบ:**

```bash
systemctl --user status openclaw-sot-sync.path
# ควรเห็น: active (waiting)

# ทดสอบ trigger:
touch ~/.openclaw/openclaw.json
sleep 2
journalctl --user -u openclaw-sot-sync.service -n 5
```

**ปิดการทำงาน:**

```bash
systemctl --user disable --now openclaw-sot-sync.path
```
