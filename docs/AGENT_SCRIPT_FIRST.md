# Agent ↔ Script-First Mapping

> ใช้สคริปต์ทำงาน routine แทน agent; **เรียก agent เฉพาะเมื่อ** ต้องใช้การตัดสินใจ/วิเคราะห์/เขียนด้วย LLM

## หลักการ

- **Script-first:** งานที่ผลลัพธ์ตายตัว (health check, config validation, git status, รัน test) ให้รันสคริปต์ก่อน
- **เรียก Agent เมื่อ:** (1) ผลจากสคริปต์ไม่ OK และต้องวิเคราะห์/ตัดสินใจ หรือ (2) งานต้องใช้ LLM โดยตรง (เขียนโค้ด, สรุป, review, สังเคราะห์)

---

## ตาราง: Agent ↔ สคริปต์ และเมื่อไหร่เรียก Agent

| Agent          | งานที่สคริปต์ทำแทนได้                                        | สคริปต์                                                                        | เรียก Agent เมื่อ                                                                                                                                                                                                                                |
| -------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Monitor**    | Health check (gateway, disk, mem, docker, errors)            | `health-check.sh --format json`                                                | `status != "ok"` — ต้องวิเคราะห์ anomaly และส่งแจ้ง Mother. **เมื่อใช้ openclaw-health.timer (OS-only server):** งาน server ทำโดยสคริปต์ระดับ OS — ปิดหรือลด Monitor heartbeat เป็น 24h ใน openclaw.json เพื่อลดโทเคน (ANTIGRAVITY §6b, §10.1d). |
| **Mother**     | ตรวจ config + จำนวน agent                                    | `config-validate.sh`, `agent-list.sh --format json --check-health`             | `valid == false` หรือมี errors — ต้องตัดสินใจแก้ไข/spawn                                                                                                                                                                                         |
| **Father**     | Disk, load, docker, systemd failed, security updates, worker | `system-report.sh`                                                             | มี anomaly ใน JSON — ต้องวินิจฉัยและลงมือ (SSH/exec)                                                                                                                                                                                             |
| **Sunday**     | Gateway status + log scan                                    | `health-check.sh`, `log-scan.sh --minutes 30`                                  | มี issues — ต้องสรุปให้ user หรือแจ้งผ่านช่องทาง                                                                                                                                                                                                 |
| **SOT-Keeper** | ตรวจว่าไฟล์ใน watch list เปลี่ยนหรือไม่                      | `git-preflight.sh --watch-list openclaw.json,ANTIGRAVITY.md,DetailHardware.md` | `watch_triggered` ไม่ว่าง หรือ index/overview ล้าสมัย — ต้องอัปเดต SYSTEM_INDEX/OVERVIEW และขอ git-ops commit                                                                                                                                    |
| **Notifier**   | ส่งข้อความที่จัดรูปแบบแล้วเข้า BACK_LOG Bot                  | `notify-backlog.sh` (หรือ `tg-notify.sh` โดยตรงถ้าข้อความพร้อม)                | ข้อความยังไม่พร้อม — ต้องให้ LLM สรุป/จัดรูปแบบจาก payload ดิบ                                                                                                                                                                                   |
| **QA-Tester**  | รัน test suite ได้ผล pass/fail                               | `scripts/ops/test-runner.sh` (optional) หรือ `pnpm test`                       | ต้องให้ agent ตีความผล (test ไหนล้ม ทำไม) หรือรันชุดย่อย                                                                                                                                                                                         |
| **Git-Ops**    | สถานะ repo, ไฟล์ที่เปลี่ยน                                   | `git-preflight.sh`                                                             | มีคำขอ commit/push จาก SOT-Keeper หรือ Mother — ต้องตัดสินใจและรัน git ตามนโยบาย                                                                                                                                                                 |
| **Deploy**     | Health check, gateway recovery                               | `health-check.sh`, `gateway-recovery.sh`                                       | Mother/user ขอ release — ต้องประสาน build, Father restart, ตรวจผล                                                                                                                                                                                |

---

## Agent ที่งานหลักต้องใช้ LLM (ไม่มีสคริปต์แทนทั้งก้อน)

| Agent              | เหตุผลที่ต้องเรียก Agent                                        |
| ------------------ | --------------------------------------------------------------- |
| **Architect**      | เขียน backlog, ตัดสินใจแก้ไขจาก escalation, จัดการ backlog      |
| **Dev**            | เขียน/แก้โค้ด, วิเคราะห์เทคนิค, spawn coder/qa-tester           |
| **Researcher**     | ค้นเว็บ, สรุปเอกสาร — ต้อง browser + LLM                        |
| **Log-Analyzer**   | สแกน log ก้อนใหญ่ หา pattern — ต้อง LLM วิเคราะห์               |
| **Coder**          | เขียน/แก้โค้ดตามที่ Dev ส่ง — ต้อง LLM                          |
| **Code-Analyst**   | อ่านโค้ด สรุป structure/pattern — ต้อง LLM                      |
| **Doc-Writer**     | เขียน docs/report จาก template — ต้อง LLM                       |
| **QA-Reviewer**    | ออกความเห็น APPROVED/REJECTED จาก diff — ต้อง LLM               |
| **Red-Team**       | วิเคราะห์ SOUL/config แบบ adversarial — ต้อง LLM                |
| **Agora-Host**     | จัดการฟอรัม multi-agent — ต้อง LLM orchestrate                  |
| **Mother-Relay**   | ส่งข้อความ batch ไปหลาย agent — logic ง่ายแต่ต้อง session tools |
| **Sain-Evaluator** | ให้คะแนน product จากข้อมูล — ต้อง LLM (n8n เรียกโดยตรง)         |
| **Intel**          | สังเคราะห์ข่าว/trend รายวัน — ต้อง browser + LLM สรุป           |

---

## Heartbeat แบบ Script-First (สรุป)

1. **Monitor:** รัน `health-check.sh --format json` → ถ้า status == "ok" ส่ง Mother แค่ "health OK" (ไม่ใช้ LLM). ถ้าไม่ ok เรียก LLM วิเคราะห์แล้วส่ง health_alert.
2. **Mother:** รัน `config-validate.sh` + `agent-list.sh --format json` → ถ้า valid และไม่มี errors ไม่ใช้ LLM. ถ้ามี errors ใช้ LLM ตัดสินใจแก้.
3. **Father:** รัน `system-report.sh` → ถ้าทุก metric ปกติ ส่ง Mother "system OK". ถ้ามี anomaly ใช้ LLM วินิจฉัยและลงมือ.
4. **Sunday:** รัน `health-check.sh` + `log-scan.sh --minutes 30` → ถ้า OK ไม่สรุปด้วย LLM. ถ้ามี issues สรุปให้ user.
5. **SOT-Keeper:** รัน `git-preflight.sh --watch-list ...` → ถ้า `watch_triggered` ว่าง และไม่ต้อง sync ไม่ใช้ LLM. ถ้ามี change ใช้ LLM อัปเดต index/overview แล้วขอ git-ops commit.

---

## อ้างอิง

- มาตรฐาน agent (workspace files, script-first, TOOLS sync): `docs/AGENT_STANDARD.md`
- สคริปต์ทั้งหมด: `SCRIPTS_REGISTRY.md`
- กฎการเขียน heartbeat: `.cursor/rules/script-first-pattern.mdc`, ANTIGRAVITY §6b
