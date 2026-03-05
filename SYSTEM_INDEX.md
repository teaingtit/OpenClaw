# SYSTEM_INDEX — OpenClaw Quick Reference

> AI: อ่านไฟล์นี้ก่อนเสมอ รายละเอียดเพิ่มเติมอ้างอิง pointer ด้านล่าง

## Agents (id | role | model | tools)

| id             | role                                      | model                 | tools                                            |
| -------------- | ----------------------------------------- | --------------------- | ------------------------------------------------ |
| mother         | master coordinator                        | minimax-m2.5          | \*                                               |
| sunday         | Telegram secretary / task router          | gemini-2.5-flash      | read, exec, write, browser, sessions\_\*         |
| dev            | code specialist                           | minimax-m2.5          | read, write, exec, github, sessions\_\*          |
| father         | sysadmin / SSH / hardware                 | glm-4.7-flash         | read, exec, write, sessions\_\*                  |
| researcher     | web search / summarization                | gemini-2.5-flash      | read, browser, sessions\_\*                      |
| log-analyzer   | log scan / anomalies                      | deepseek-v3.2         | read, exec, sessions\_\*                         |
| qa-tester      | test runner                               | glm-4.7-flash         | read, exec, sessions\_\*                         |
| coder          | stateless code writer                     | minimax-m2.5          | read, write, exec, sessions_send, session_status |
| architect      | escalation handler / backlog              | gpt-5.2               | read, write, exec, sessions\_\*                  |
| mother-relay   | batch message relay                       | glm-4.7-flash         | sessions_send, sessions_list, session_status     |
| sain-evaluator | SAIN n8n product scorer                   | gemini-2.0-flash-lite | defaults                                         |
| agora-host     | forum orchestrator                        | glm-4.7-flash         | read, write, sessions\_\*                        |
| code-analyst   | code analysis                             | deepseek-v3.2         | read, exec, sessions_send, session_status        |
| doc-writer     | documentation writer                      | glm-4.7-flash         | read, write, sessions_send, session_status       |
| qa-reviewer    | code diff reviewer                        | kimi-k2.5             | read, write, sessions_send, session_status       |
| red-team       | security analyst                          | kimi-k2.5             | read, write, sessions*\*, memory*\*              |
| git-ops        | Git fork push only, no PR                 | gemini-2.5-flash      | read, write, exec                                |
| deploy         | release pipeline coordinator              | gemini-2.5-flash      | read, write, exec, sessions\_\*                  |
| monitor        | health watchdog                           | gemini-2.5-flash      | read, exec, sessions_send, session_status        |
| notifier       | Telegram dispatcher                       | gemini-2.5-flash      | exec, sessions_send, session_status              |
| intel          | intelligence coordinator                  | gemini-2.5-flash      | read, write, browser, sessions*\*, memory*\*     |
| sot-keeper     | sync SYSTEM_INDEX + OVERVIEW from sources | gemini-2.5-flash      | read, write, exec, sessions_send, session_status |

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
