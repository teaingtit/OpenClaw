# สรุประบบ OpenClaw (สำหรับมนุษย์)

> เอกสารนี้สรุปโครงสร้างโปรเจกต์และหน้าที่ของ Agent ต่างๆ เป็นภาษาไทย สำหรับ AI ให้อ่าน [SYSTEM_INDEX.md](SYSTEM_INDEX.md) และ [ANTIGRAVITY.md](ANTIGRAVITY.md)

## โครงสร้างระบบโดยรวม

OpenClaw เป็นระบบ **Multi-Agent Gateway** — มี Gateway รันที่พอร์ต 18789 รับคำสั่งจาก Telegram หรือ Control UI แล้วกระจายงานให้ Agent ต่างๆ ทำงานเฉพาะทาง (เขียนโค้ด, ดูแลเซิร์ฟเวอร์, ตรวจสุขภาพระบบ, รวบรวมข่าวสาร ฯลฯ) โดยไม่ต้องมีมนุษย์มาคุมตลอด ยกเว้นเมื่อมีปัญหาที่แก้ไม่ได้จะส่งไปที่ Architect บันทึกลง Backlog และแจ้งเตือนผ่าน Telegram

- **Config หลัก:** `~/.openclaw/openclaw.json`
- **Repo โปรเจกต์:** `/home/teaingtit/projects/openclaw`
- **พอร์ต Gateway:** 18789

## ตาราง Agent — ชื่อ, หน้าที่, โมเดล, เมื่อใช้งาน

| Agent          | หน้าที่โดยย่อ                                       | โมเดล                 | เมื่อใช้งาน                                               |
| -------------- | --------------------------------------------------- | --------------------- | --------------------------------------------------------- |
| mother         | ควบคุมรวม / สร้าง agent / กระจายงาน                 | minimax-m2.5          | ผ่าน Control UI หรือ agent อื่นเรียก; heartbeat ทุก 6 ชม. |
| sunday         | เลขา Telegram / รับคำถามจากผู้ใช้ / ส่งงานต่อ       | gemini-2.5-flash      | ข้อความจาก Telegram → sunday; heartbeat ทุก 30 นาที       |
| dev            | เขียนโค้ด / วิเคราะห์เทคนิค                         | minimax-m2.5          | sunday หรือ mother สั่ง spawn                             |
| father         | ดูแลเซิร์ฟเวอร์ SSH / ฮาร์ดแวร์ / Docker            | glm-4.7-flash         | sunday หรือ mother สั่ง spawn; heartbeat ทุก 4 ชม.        |
| researcher     | ค้นเว็บ / สรุปเอกสารยาว                             | gemini-2.5-flash      | dev หรือ intel สั่ง spawn                                 |
| log-analyzer   | สแกน log หาความผิดปกติ                              | deepseek-v3.2         | spawn ตามต้องการ                                          |
| qa-tester      | รันเทสต์อัตโนมัติ                                   | glm-4.7-flash         | dev สั่ง spawn                                            |
| coder          | เขียน/แก้โค้ดแบบ stateless                          | minimax-m2.5          | dev สั่ง spawn                                            |
| architect      | รับ escalation / จัดการ Backlog / แจ้งเตือน         | gpt-5.2               | mother สั่งเมื่อมีปัญหา 3 ครั้งล้มเหลว                    |
| mother-relay   | ส่งข้อความแบบ batch ไปหลาย agent                    | glm-4.7-flash         | mother สั่ง spawn                                         |
| qa-reviewer    | รีวิว code diff (อนุมัติ/ไม่อนุมัติ)                | kimi-k2.5             | dev หรือ mother สั่ง spawn                                |
| red-team       | วิเคราะห์ความปลอดภัยของ agent                       | kimi-k2.5             | mother สั่ง spawn เป็นระยะ                                |
| git-ops        | ทำ Git — push ไป fork เท่านั้น (ไม่เปิด PR)         | gemini-2.0-flash-lite | สั่งเมื่อต้องการ commit/push                              |
| deploy         | ประสาน release — build, restart, health check       | gemini-2.5-flash      | สั่งเมื่อจะ deploy                                        |
| monitor        | ตรวจสุขภาพ Gateway / Docker / disk / memory         | gemini-2.5-flash      | heartbeat ทุก 15 นาที                                     |
| notifier       | ส่งแจ้งเตือนไป Telegram                             | gemini-2.5-flash      | architect หรือ intel ส่ง payload มา                       |
| intel          | รวบรวมข่าวสาร (โมเดลใหม่, OpenClaw อัปเดต, AI news) | gemini-2.5-flash      | heartbeat รายวัน; ส่ง digest ผ่าน notifier                |
| sain-evaluator | ให้คะแนนสินค้า SAIN สำหรับ n8n                      | gemini-2.0-flash-lite | เรียกจาก n8n workflow                                     |
| agora-host     | จัดการฟอรัมหลาย agent                               | glm-4.7-flash         | mother สั่ง spawn                                         |
| code-analyst   | อ่าน/วิเคราะห์โครงสร้างโค้ด                         | deepseek-v3.2         | dev / architect สั่ง spawn                                |
| doc-writer     | เขียนเอกสารจาก template                             | glm-4.7-flash         | architect / mother / dev สั่ง spawn                       |
| sot-keeper     | อัปเดต SYSTEM_INDEX + OVERVIEW ให้ตรงกับ config     | gemini-2.5-flash      | heartbeat ทุก 6 ชม.                                       |

## วิธีส่งงานให้ Agent (ตัวอย่างคำสั่ง)

- **ผ่าน CLI (บนเครื่องที่รัน Gateway):**
  ```bash
  openclaw agent --agent sunday --message "สรุปสถานะโปรเจกต์วันนี้"
  openclaw agent --agent git-ops --message "commit และ push ไป fork main"
  openclaw agent --agent dev --message "เพิ่ม unit test สำหรับฟังก์ชัน X"
  ```
- **ผ่าน Telegram:** ส่งข้อความไปที่ Bot ที่ผูกกับ sunday — sunday จะรับและ delegate ต่อให้ mother หรือ agent อื่น
- **ผ่าน Control UI:** เปิด UI ที่เชื่อมกับ Gateway แล้วเลือก agent และส่งข้อความ

## ฮาร์ดแวร์ (สรุป)

| โหนด            | บทบาท                    | ไอพี Tailscale |
| --------------- | ------------------------ | -------------- |
| minipc (Master) | Gateway / Control Center | 100.96.9.50    |
| Client (ASUS)   | เครื่องผู้ใช้            | 100.71.184.70  |

รายละเอียดเต็มใน [DetailHardware.md](DetailHardware.md)

## Flow การทำงานหลัก

1. **Dev pipeline:** ผู้ใช้/Telegram → sunday → mother → dev → (coder, qa-tester, qa-reviewer ฯลฯ) → git-ops (commit/push ไป fork)
2. **Ops pipeline:** monitor ตรวจสุขภาพทุก 15 นาที → ถ้าผิดปกติแจ้ง mother → mother อาจสั่ง father หรือ deploy
3. **Escalation:** Agent ใดก็ตามล้มเหลว 3 ครั้ง → ส่ง escalation ไป mother → mother spawn architect → architect บันทึกลง DEVELOPMENT_BACKLOG.md และส่ง notifier ไป Telegram
4. **Intel:** intel รันรายวัน → รวบรวมข่าวสาร → สรุปและส่ง digest ผ่าน notifier → ถ้ามีเรื่องเร่งด่วน (เช่น security) ส่งต่อ mother
