# SYSTEM_INDEX — OpenClaw Quick Reference

> AI: อ่านไฟล์นี้ก่อนเสมอ รายละเอียดเพิ่มเติมอ้างอิง pointer ด้านล่าง

## Agents (id | role | model | tools)

| id             | role               | model                 | tools                                                                                                                                                                                         |
| -------------- | ------------------ | --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| mother         | The Mother         | minimax-m2.5          | \*                                                                                                                                                                                            |
| sunday         | Sunday             | gemini-2.5-flash      | read, exec, write, browser, sessions_list, sessions_send, sessions_spawn, sessions_history, session_status, memory_search, memory_get, worker_tts, worker_image, worker_render, worker_ollama |
| dev            | Dev                | minimax-m2.5          | read, write, exec, github, sessions_list, sessions_send, sessions_spawn, sessions_history, session_status                                                                                     |
| father         | The Father         | glm-4.7-flash         | read, exec, write, sessions_list, sessions_send, sessions_spawn                                                                                                                               |
| researcher     | Researcher         | gemini-2.5-flash      | read, browser, sessions_list, sessions_send, session_status                                                                                                                                   |
| log-analyzer   | LogAnalyzer        | deepseek-v3.2         | read, exec, sessions_list, sessions_send, session_status                                                                                                                                      |
| qa-tester      | QATester           | glm-4.7-flash         | read, exec, sessions_list, sessions_send, session_status                                                                                                                                      |
| coder          | coder              | minimax-m2.5          | read, write, exec, sessions_send, session_status                                                                                                                                              |
| architect      | architect          | gpt-5.2               | read, write, exec, sessions_send, sessions_list, session_status                                                                                                                               |
| mother-relay   | mother-relay       | glm-4.7-flash         | sessions_send, sessions_list, session_status                                                                                                                                                  |
| sain-evaluator | sain-evaluator     | gemini-2.0-flash-lite | defaults                                                                                                                                                                                      |
| agora-host     | Forum Orchestrator | glm-4.7-flash         | read, write, sessions_list, sessions_send, sessions_spawn, session_status                                                                                                                     |
| code-analyst   | CodeAnalyst        | deepseek-v3.2         | read, exec, sessions_send, session_status                                                                                                                                                     |
| doc-writer     | DocWriter          | glm-4.7-flash         | read, write, sessions_send, session_status                                                                                                                                                    |
| qa-reviewer    | qa-reviewer        | kimi-k2.5             | read, write, sessions_send, session_status                                                                                                                                                    |
| red-team       | red-team           | kimi-k2.5             | read, write, sessions_send, session_status, memory_search, memory_get                                                                                                                         |
| git-ops        | git-ops            | gemini-2.0-flash-lite | read, write, exec                                                                                                                                                                             |
| sot-keeper     | SOT Keeper         | gemini-2.5-flash      | read, write, exec, sessions_send, session_status                                                                                                                                              |
| deploy         | Deploy Coordinator | gemini-2.5-flash      | read, write, exec, sessions_send, sessions_list, sessions_spawn, session_status                                                                                                               |
| notifier       | Notifier           | gemini-2.5-flash      | exec, sessions_send, session_status                                                                                                                                                           |
| intel          | Intel Unit         | gemini-2.5-flash      | read, write, browser, sessions_send, sessions_spawn, sessions_list, session_status, memory_set, memory_get                                                                                    |

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
