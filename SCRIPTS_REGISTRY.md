# SCRIPTS_REGISTRY — Available Shell Scripts for Agents

> Agent: อ่านไฟล์นี้ก่อนเรียก LLM สำหรับงาน routine — ถ้ามีสคริปที่ทำได้ ให้ exec สคริปแล้วอ่านผลลัพธ์แทน  
> **แมป Agent ↔ สคริปต์ และเมื่อไหร่เรียก Agent:** ดู `docs/AGENT_SCRIPT_FIRST.md`. **มาตรฐาน agent (script-first, TOOLS sync):** ดู `docs/AGENT_STANDARD.md`

## Ops Scripts (scripts/ops/)

| Script                          | แทนงานของ Agent                                                                                                                                                                                                                                | วิธีเรียก                                                                                                                                                                                        | Output                                                  |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------- |
| health-check.sh                 | (Available)                                                                                                                                                                                                                                    | `bash scripts/ops/health-check.sh` or `bash scripts/ops/health-check.sh --format json`                                                                                                           | JSON                                                    |
| health-check-and-recover.sh     | timer: health-check แล้วถ้า CRITICAL รัน gateway-recovery อัตโนมัติ (**server แบบ OS-only**)                                                                                                                                                   | `bash scripts/ops/health-check-and-recover.sh --format json --notify-on-critical`. ใช้โดย openclaw-health.service                                                                                | เหมือน health-check                                     |
| health-check-fix-or-escalate.sh | **พบ error → รันสคริปต์แก้ → ถ้าหายเงียบ; ถ้าไม่หายเขียน `~/.openclaw/health-escalation-pending.json` (ไม่แจ้ง Telegram). Agent อ่านไฟล์แล้วลองแก้ — ส่ง Telegram เฉพาะเมื่อ agent แก้ได้หรือ agent แก้ไม่ได้** ดู `docs/HEALTH_ESCALATION.md` | `bash scripts/ops/health-check-fix-or-escalate.sh` (หรือ `--no-fix`, `--verbose`). Env: `OPENCLAW_FIX_SCRIPT`, `OPENCLAW_FIX_ARGS`, `OPENCLAW_POST_FIX_SLEEP`, `OPENCLAW_STATE_DIR`. ต้องมี `jq` | exit 0 เงียบ / เขียนไฟล์รอ agent                        |
| gateway-recovery.sh             | restart + health-check                                                                                                                                                                                                                         | `bash scripts/ops/gateway-recovery.sh` (on gateway host). Use `--no-restart` to only check + show log; `--notify` to allow Telegram on critical                                                  | Text                                                    |
| post-reboot-diagnosis.sh        | หาสาเหตุ server ล่มหลังรีบูท                                                                                                                                                                                                                   | `bash scripts/ops/post-reboot-diagnosis.sh` (on host ที่เพิ่ง reboot). ใช้ `--format json` สำหรับ agent; อ่าน journalctl -b -1 หา OOM/panic                                                      | Text / JSON                                             |
| free-gateway-port.sh            | คืน port 18789 ก่อน start gateway                                                                                                                                                                                                              | `bash scripts/ops/free-gateway-port.sh`. ใช้ใน ExecStartPre หรือรันก่อน start gateway เพื่อป้องกัน port conflict loop                                                                            | —                                                       |
| config-validate.sh              | mother config check                                                                                                                                                                                                                            | `bash scripts/ops/config-validate.sh`                                                                                                                                                            | JSON                                                    |
| log-scan.sh                     | sunday / log-analyzer                                                                                                                                                                                                                          | `bash scripts/ops/log-scan.sh --minutes 15`                                                                                                                                                      | JSON                                                    |
| system-report.sh                | father system check                                                                                                                                                                                                                            | `bash scripts/ops/system-report.sh`                                                                                                                                                              | JSON                                                    |
| git-preflight.sh                | git-ops / sot-keeper                                                                                                                                                                                                                           | `bash scripts/ops/git-preflight.sh --format json` or `--watch-list openclaw.json,ANTIGRAVITY.md,DetailHardware.md`                                                                               | JSON                                                    |
| agent-list.sh                   | mother agent count                                                                                                                                                                                                                             | `bash scripts/ops/agent-list.sh --format json` or `--check-health`                                                                                                                               | JSON or table                                           |
| audit-agents.py                 | mother / ops check                                                                                                                                                                                                                             | `python3 scripts/ops/audit-agents.py`                                                                                                                                                            | Text                                                    |
| fix-agents.py                   | mother / ops repair                                                                                                                                                                                                                            | `python3 scripts/ops/fix-agents.py` (แก้ tools.allow + เพิ่ม agents ที่ขาด ใน openclaw.json)                                                                                                     | Text                                                    |
| notify-backlog.sh               | notifier (เมื่อข้อความพร้อม)                                                                                                                                                                                                                   | `bash scripts/ops/notify-backlog.sh --type alert --title "..." --body "..."` หรือ `--raw "ข้อความ"`. ใช้แทนการ spawn Notifier เมื่อมี title/body แล้ว                                            | —                                                       |
| test-runner.sh                  | qa-tester (ผล pass/fail)                                                                                                                                                                                                                       | `bash scripts/ops/test-runner.sh --json` (รัน pnpm test, output JSON). เรียก QA-Tester เมื่อต้องตีความผลหรือรันชุดย่อย                                                                           | JSON                                                    |
| usage-by-agent.ts               | ดูว่า agent ไหนใช้ token มาก (หาสาเหตุติด limit)                                                                                                                                                                                               | `pnpm exec node --import tsx scripts/ops/usage-by-agent.ts --hours 24` or `--days 1`; `--json` สำหรับ machine-readable                                                                           | Text / JSON                                             |
| gen-agent-index.sh              | sot-keeper (agent table sync)                                                                                                                                                                                                                  | `bash scripts/ops/gen-agent-index.sh`                                                                                                                                                            | JSON `{"status":"clean"\|"updated","agents_count":N}`   |
| pre-commit-sot-check.sh         | (git hook)                                                                                                                                                                                                                                     | ติดตั้งเป็น `.git/hooks/pre-commit`                                                                                                                                                              | stderr + exit 1 เมื่อ drift                             |
| process-monitor.sh              | sunday: process/load/zombie monitoring                                                                                                                                                                                                         | `bash scripts/ops/process-monitor.sh --format json` or `--top 20`                                                                                                                                | JSON (exit 0=healthy, 1=zombies/high load, 2=critical)  |
| network-diagnostics.sh          | sunday: internet/DNS/Tailscale/ports check                                                                                                                                                                                                     | `bash scripts/ops/network-diagnostics.sh --format json`                                                                                                                                          | JSON (exit 0=ok, 1=DNS issue, 2=no internet)            |
| backup-status.sh                | sunday: backup freshness/validity/drift                                                                                                                                                                                                        | `bash scripts/ops/backup-status.sh --format json`                                                                                                                                                | JSON (exit 0=fresh, 1=>12h/drift, 2=>24h/invalid)       |
| security-audit.sh               | sunday: SSH/users/firewall/creds audit (report only)                                                                                                                                                                                           | `bash scripts/ops/security-audit.sh --format json --hours 24`                                                                                                                                    | JSON (exit 0=clean, 1=updates/>50 SSH, 2=creds exposed) |
| disk-cleanup.sh                 | sunday: disk usage + cleanup (DRY-RUN default)                                                                                                                                                                                                 | `bash scripts/ops/disk-cleanup.sh --format json` or `--execute`                                                                                                                                  | JSON (exit 0=<85%, 1=85-95%, 2=>95%)                    |
| update-status.sh                | sunday: apt/kernel/node/bun/openclaw version check                                                                                                                                                                                             | `bash scripts/ops/update-status.sh --format json` or `--skip-npm`                                                                                                                                | JSON (exit 0=current, 1=pending, 2=reboot needed)       |
| service-manager.sh              | sunday: service status/memory + optional restart                                                                                                                                                                                               | `bash scripts/ops/service-manager.sh --format json` or `--restart <name>`                                                                                                                        | JSON (exit 0=ok, 1=some failed, 2=gateway failed)       |

Paths: จาก repo root คือ `scripts/ops/<name>`. บน host ที่รัน gateway ใช้ path เต็มได้ เช่น `/home/teaingtit/projects/openclaw/scripts/ops/health-check.sh`. health-check.sh: กำหนด threshold ได้ด้วย env `OPENCLAW_HEALTH_ERROR_WARN` (default 10), `OPENCLAW_HEALTH_ERROR_CRITICAL` (default 60).

## Power Scripts (scripts/)

| Script          | วิธีเรียก                               |
| --------------- | --------------------------------------- |
| wake-ai.sh      | `bash scripts/wake-ai.sh`               |
| jit-wrapper.sh  | `bash scripts/jit-wrapper.sh "command"` |
| pre-warm-ai.sh  | `bash scripts/pre-warm-ai.sh "reason"`  |
| idle-monitor.sh | (รันผ่าน cron/timer)                    |

## Worker / Ollama (scripts/)

| Script | วิธีเรียก |
| ------ | --------- |

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

- **father:** รัน `scripts/ops/system-report.sh` → ถ้าทุกอย่างปกติ ส่ง "system OK"; ถ้ามี anomaly ใช้ LLM
- **mother:** รัน `config-validate.sh` + `agent-list.sh --format json` → ถ้า valid ไม่ต้องใช้ LLM
- **sunday:** phased heartbeat — Phase 1 (ทุกครั้ง): `health-check.sh`; Phase 2 (ทุก 6 ชม.): `process-monitor.sh` + `backup-status.sh` + `log-scan.sh --minutes 360`; Phase 3 (วันละครั้ง): `network-diagnostics.sh` + `security-audit.sh` + `update-status.sh` + `disk-cleanup.sh` (dry-run) + `service-manager.sh`. ถ้าทุก phase ที่รัน OK → `HEARTBEAT_OK`
- **sot-keeper:** รัน `gen-agent-index.sh` ก่อน → exit 0 ไม่ต้องใช้ LLM; exit 1 = updated (ต่อ step 2); จากนั้นรัน `git-preflight.sh --watch-list openclaw.json,ANTIGRAVITY.md,DetailHardware.md` → ถ้า watch_triggered ว่าง AND gen exit 0 ไม่ต้องใช้ LLM

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
