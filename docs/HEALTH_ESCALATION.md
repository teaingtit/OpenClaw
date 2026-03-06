# Health Escalation (สคริปต์แก้ไม่ได้ → Agent แก้ แล้วค่อยแจ้ง)

เมื่อ `health-check-fix-or-escalate.sh` รันแล้วสคริปต์แก้ (เช่น gateway-recovery.sh) ยังแก้ไม่ได้ สคริปต์จะ **ไม่ส่ง Telegram ทันที** แต่จะเขียนไฟล์รอให้ agent จัดการ:

- **ไฟล์:** `~/.openclaw/health-escalation-pending.json`
- **รูปแบบ:** `{ "since": "ISO8601", "status": "critical"|"warning", "gateway": "...", "gateway_svc": "...", "errors": N, "worker": "..." }`

## หน้าที่ของ Agent (Mother / Monitor)

เมื่อ agent รัน (heartbeat หรือถูก spawn) และ gateway ใช้ได้:

1. **ตรวจว่ามีไฟล์รอหรือไม่:** อ่าน `~/.openclaw/health-escalation-pending.json` (หรือ path จาก `OPENCLAW_STATE_DIR`).
2. **ถ้ามี:** ลองแก้ (เช่น spawn Father ให้ตรวจ/restart gateway, หรือ deploy ตาม context).
3. **หลังลองแก้:**
   - **ถ้าแก้ได้ (health-check กลับมา ok):** ส่ง Telegram ว่า **ปัญหาถูกแก้โดย agent แล้ว** (และลบไฟล์ `health-escalation-pending.json`).
   - **ถ้าแก้ไม่ได้:** ส่ง Telegram ว่า **agent แก้ปัญหาไม่ได้** (และลบหรืออัปเดตไฟล์เพื่อไม่ให้ลองซ้ำไม่สิ้นสุด).

ดังนั้น **Telegram จะถูกส่งเฉพาะเมื่อ** (1) agent แก้ได้ หรือ (2) agent แก้ไม่ได้ — ไม่ส่งทันทีเมื่อสคริปต์แก้ไม่ได้.

## การลบไฟล์เมื่อสถานะดี

เมื่อ `health-check-fix-or-escalate.sh` ตรวจแล้วได้ status ok มันจะลบ `health-escalation-pending.json` เอง (ทั้งตอนตรวจครั้งแรกและหลังรันสคริปต์แก้). ดังนั้นถ้า timer รันอีกครั้งและสถานะดี ไฟล์จะหายไปโดยอัตโนมัติ.

## อ้างอิง

- สคริปต์: `scripts/ops/health-check-fix-or-escalate.sh`
- ANTIGRAVITY §6b, §10.1c
