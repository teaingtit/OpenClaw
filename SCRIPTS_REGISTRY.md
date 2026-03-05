# SCRIPTS_REGISTRY — Available Shell Scripts for Agents

> Agent: อ่านไฟล์นี้ก่อนเรียก LLM สำหรับงาน routine — ถ้ามีสคริปที่ทำได้ ให้ exec สคริปแล้วอ่านผลลัพธ์แทน

## Ops Scripts (scripts/ops/)

| Script             | แทนงานของ Agent       | วิธีเรียก                                                                                                          | Output        |
| ------------------ | --------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------- |
| health-check.sh    | monitor heartbeat     | `bash scripts/ops/health-check.sh` or `bash scripts/ops/health-check.sh --format json`                             | JSON          |
| config-validate.sh | mother config check   | `bash scripts/ops/config-validate.sh`                                                                              | JSON          |
| log-scan.sh        | sunday / log-analyzer | `bash scripts/ops/log-scan.sh --minutes 15`                                                                        | JSON          |
| system-report.sh   | father system check   | `bash scripts/ops/system-report.sh`                                                                                | JSON          |
| git-preflight.sh   | git-ops / sot-keeper  | `bash scripts/ops/git-preflight.sh --format json` or `--watch-list openclaw.json,ANTIGRAVITY.md,DetailHardware.md` | JSON          |
| agent-list.sh      | mother agent count    | `bash scripts/ops/agent-list.sh --format json` or `--check-health`                                                 | JSON or table |

Paths: จาก repo root คือ `scripts/ops/<name>`. บน host ที่รัน gateway ใช้ path เต็มได้ เช่น `/home/teaingtit/projects/openclaw/scripts/ops/health-check.sh`.

## Power Scripts (scripts/)

| Script            | วิธีเรียก                               |
| ----------------- | --------------------------------------- |
| wake-ai.sh        | `bash scripts/wake-ai.sh`               |
| sleep-ai.sh       | `bash scripts/sleep-ai.sh`              |
| jit-wrapper.sh    | `bash scripts/jit-wrapper.sh "command"` |
| pre-warm-ai.sh    | `bash scripts/pre-warm-ai.sh "reason"`  |
| idle-monitor.sh   | (รันผ่าน cron/timer)                    |
| check-gpu-load.sh | `bash scripts/check-gpu-load.sh`        |

## Notification

| Script       | วิธีเรียก                             |
| ------------ | ------------------------------------- |
| tg-notify.sh | `bash scripts/tg-notify.sh "message"` |

## Maintenance

| Script            | วิธีเรียก                                                                 |
| ----------------- | ------------------------------------------------------------------------- |
| safe-upgrade.sh   | `bash scripts/safe-upgrade.sh` or `bash scripts/safe-upgrade.sh 2026.3.5` |
| backup-config.sh  | (รันผ่าน systemd timer ทุก 6 ชม.)                                         |
| docker-rebuild.sh | `bash scripts/docker-rebuild.sh` or `--browser` or `--gh`                 |

## Script-First Heartbeat Pattern

Agent ที่มี heartbeat ควรรันสคริปก่อน แล้วใช้ LLM เฉพาะเมื่อผลไม่ OK:

- **monitor:** รัน `scripts/ops/health-check.sh --format json` → ถ้า status == "ok" ส่งแค่ "health OK" ไป mother; ถ้าไม่ ok ใช้ LLM วิเคราะห์แล้ว escalate
- **father:** รัน `scripts/ops/system-report.sh` → ถ้าทุกอย่างปกติ ส่ง "system OK"; ถ้ามี anomaly ใช้ LLM
- **mother:** รัน `config-validate.sh` + `agent-list.sh --format json` → ถ้า valid ไม่ต้องใช้ LLM
- **sunday:** รัน `health-check.sh` + `log-scan.sh --minutes 30` → ถ้า OK ไม่ต้องสรุปด้วย LLM
- **sot-keeper:** รัน `git-preflight.sh --watch-list openclaw.json,ANTIGRAVITY.md,DetailHardware.md` → ถ้า watch_triggered ว่าง ไม่ต้อง sync index

## Addendum: mother, father, sunday (SOUL.md)

ถ้า workspace อยู่ที่ `~/.openclaw/workspace-mother`, `workspace-father`, `workspace-sunday` ให้เพิ่มบล็อกด้านล่างใน SOUL.md ของแต่ละตัว:

**mother — Heartbeat Execution:**

1. exec: `bash <repo>/scripts/ops/config-validate.sh`
2. exec: `bash <repo>/scripts/ops/agent-list.sh --format json --check-health`
3. IF valid และไม่มี errors → done (ไม่ใช้ LLM)
4. IF มี errors → ใช้ LLM ตัดสินใจแก้ไข

**father — Heartbeat Execution:**

1. exec: `bash <repo>/scripts/ops/system-report.sh`
2. Parse JSON
3. IF ทุกอย่างปกติ → ส่ง mother แค่ "system OK" (หนึ่งบรรทัด)
4. IF มี anomaly → ใช้ LLM วินิจฉัยและแก้ไข

**sunday — Heartbeat Execution:**

1. exec: `bash <repo>/scripts/ops/health-check.sh --format json`
2. exec: `bash <repo>/scripts/ops/log-scan.sh --minutes 30 --format json`
3. IF ทั้งคู่ OK → ไม่ต้องใช้ LLM สรุป
4. IF มี issues → สรุปให้ user ผ่าน Telegram
