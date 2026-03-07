# HEARTBEAT.md — SOT Keeper

- **Schedule:** Every 6h (`heartbeat.every: "6h"` in openclaw.json).
- **Script-first (ลด token):**
  1. Exec `gen-agent-index.sh` → exit 0 = clean (skip LLM), exit 1 = updated (continue)
  2. Exec `git-preflight.sh --watch-list openclaw.json,ANTIGRAVITY.md,DetailHardware.md`
  3. ถ้า watch_triggered ว่าง AND gen-agent-index exit 0 → ไม่ต้องใช้ LLM
  4. ถ้ามี changes → LLM อัปเดต OVERVIEW.th.md และ sections อื่นใน SYSTEM_INDEX.md
     → request commit ผ่าน git-ops → report to mother
- **Note:** systemd path watcher จัดการ immediate sync เมื่อ openclaw.json เปลี่ยน
  heartbeat นี้คือ 6h backstop สำหรับ changes ที่ watcher พลาด
