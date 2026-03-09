# SYSTEM_INDEX — OpenClaw Quick Reference

> AI: อ่านไฟล์นี้ก่อนเสมอ รายละเอียดเพิ่มเติมอ้างอิง pointer ด้านล่าง

## Agents (id | role | model | tools)

| id     | role                             | model            | tools                                                                         |
| ------ | -------------------------------- | ---------------- | ----------------------------------------------------------------------------- |
| sunday | Telegram secretary / task router | gemini-2.5-flash | read, exec, write, browser, sessions_\*, session_status, memory_\*, worker_\* |

## Find Information Here

| ต้องการ                                   | ไปที่                                        |
| ----------------------------------------- | -------------------------------------------- |
| agent role / model / tools รายละเอียด     | ANTIGRAVITY.md §5                            |
| hardware / network / nodes                | DetailHardware.md                            |
| config rules / dos and don'ts             | .antigravityrules                            |
| Thai human overview                       | OVERVIEW.th.md                               |
| agent behavior detail                     | ~/.openclaw/workspace-_ / agents/workspace-_ |
| scripts for routine / heartbeat (ลดโทเคน) | SCRIPTS_REGISTRY.md                          |

## Critical Paths

- **Gateway port:** 18789
- **Config:** ~/.openclaw/openclaw.json
- **Repo:** /home/teaingtit/projects/openclaw
- **Fork remote:** fork → git@github.com:teaingtit/openclaw.git (push ไป fork เท่านั้น ห้าม origin)

## Critical Config Flags

- `tools.sessions.visibility`: `all` (required for delegation)
- `tools.agentToAgent.enabled`: `true` (required for sessions_spawn / send)
