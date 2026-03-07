# [SYSTEM_CONTEXT] ANTIGRAVITY / OpenClaw

> **AI Quick Start:** อ่าน `SYSTEM_INDEX.md` ก่อนสำหรับ overview และ pointers — ไฟล์นี้มีรายละเอียดเต็ม

> Single source of truth for AI Assistants to reduce hallucination and redundant searches.

> This document describes the **design, architecture, and current state** of the OpenClaw system.
> For **operational rules and guidelines** that AI agents must follow during tasks,
> refer to the `.antigravityrules` file and the modular rules in `.cursor/rules/` (e.g., `project-context.mdc`, `agents-config.mdc`).

## 0. HOW_TO_READ_THIS_DOCUMENT

<!-- Navigation guide — อ่านส่วนนี้ก่อนเสมอ เพื่อให้รู้ว่าต้องไปที่ section ไหน -->
<!-- ไฟล์นี้ยาว — ใช้ตารางนี้หา section ที่ต้องการแทนการอ่านทั้งหมดตามลำดับ -->

| หากต้องการ...                                         | Section                                 |
| ----------------------------------------------------- | --------------------------------------- |
| รู้ว่า agent ตัวไหนทำอะไร / model อะไร                | §5 AGENT_DEFINITIONS                    |
| เรียก agent / delegate งาน / spawn                    | §9 AGENT_INTERACTION_RULES              |
| เลือกโมเดลสำหรับ agent ใหม่                           | §8 ROUTING_MODELS                       |
| แก้ไข config / docker / restart                       | §2 + §7                                 |
| debug incident / escalate ปัญหา                       | §10 INCIDENT_ESCALATION_PROTOCOL        |
| ดู file paths สำคัญ                                   | §6 CRITICAL_FILE_MAP                    |
| สคริป routine / script-first ลดโทเคน                  | §6b SCRIPT_TOOLKIT, SCRIPTS_REGISTRY.md |
| มาตรฐาน agent (script-first, รูปแบบเดียวกัน, ลดโทเคน) | §6 + docs/AGENT_STANDARD.md             |
| config safety (ห้ามเขียน openclaw.json โดยตรง)        | .antigravityrules RULE_20, §2           |
| hardware / devices รายละเอียด                         | DetailHardware.md, §3                   |

**Related:** Operational rules → `.antigravityrules`. Full bookend reminder → §11.

**⚠️ 3 กฎที่ต้องจำก่อนทำอะไรก็ตาม:**

1.  **Model strings** ต้องขึ้นต้นด้วย `openrouter/` เสมอ — `anthropic/claude-...` หรือ `openai/gpt-...` ล้มเหลวทันที (ไม่มี direct API key)
2.  **Inter-agent config** ต้องมีใน `openclaw.json`: `tools.agentToAgent.enabled=true` + `tools.sessions.visibility=all` — ขาดอย่างใดอย่างหนึ่ง = delegation ทุกตัวล้มเหลวเงียบๆ
3.  **Non-persistent agents** (`dev`, `father`) ไม่ปรากฏใน `sessions_list` = ปกติ — ใช้ `sessions_spawn` + `agentId` เสมอ ห้าม fallback ไป generic sub-agent

---

## 1. PROJECT_METADATA

- **name:** OpenClaw
- **type:** Multi-Agent Gateway & Orchestration System
- **core_logic:**
  - Multi-agent routing
  - Tool sandboxing
  - Persistent session management

## 2. SYSTEM_ARCHITECTURE

- **gateway_master:** One of **systemd (primary)** or **Docker** — must run exactly one. Port `18789`; both systemd and Docker publish it, so only one process may run (see §7.0).
- **agents_workers:** Isolated directories (`~/.openclaw/workspace-*`)
- **channels:** Interfaces bridging reality and AI (e.g., `plugin-telegram@v1.4.1`)
- **sandbox_layer:** `tools.allow` per agent in `openclaw.json`; OS-level sandbox (`sandbox.mode`) is `off` for all agents — Docker container is the isolation boundary. `sandbox.mode: "all"` requires Docker-in-Docker (not configured).
- **model_provider:** Primary: OpenRouter. Model strings for cloud: `openrouter/<provider>/<model>`. Bare `anthropic/...` or `openai/...` tries direct API and fails — no direct API keys configured.
- **required_config_flags (CRITICAL):** The following root-level keys in `openclaw.json` are MANDATORY for inter-agent delegation to work. If either is missing, ALL agent-to-agent communication fails silently:
  ```json
  "tools": { "sessions": { "visibility": "all" }, "agentToAgent": { "enabled": true } }
  ```
  Mother validates and auto-fixes these on every heartbeat (HEARTBEAT.md task 0). Never remove them.

## 3. HARDWARE_INFRASTRUCTURE

| node_id          | role                      | hardware_specs                                             | operating_system               | tailscale_network |
| ---------------- | ------------------------- | ---------------------------------------------------------- | ------------------------------ | ----------------- |
| `master_gateway` | Gateway / Master (minipc) | Machenike Mini N TL24 (Intel N150, 16GB LPDDR5, 512GB SSD) | Ubuntu Server 26.04 LTS (24/7) | `100.96.9.50`     |

| `client` | Client | ASUS ExpertBook P3605CVA (i5-13420H, 16GB RAM, 1TB NVMe, Intel UHD) | Windows | `100.71.184.70` |

## 3b. TELEGRAM_BOT_REGISTRY

<!-- Single Source of Truth สำหรับ Telegram Bots ทั้งหมด — อัปเดตที่นี่ที่เดียว -->

> **กฎเหล็ก:** Token ทุกตัวต้องเก็บใน `~/.openclaw/.env` เท่านั้น **ห้าม hardcode ใน script ใดๆ**

| env_variable              | bot_name     | username   | purpose                                                                                   |
| ------------------------- | ------------ | ---------- | ----------------------------------------------------------------------------------------- |
| `TELEGRAM_BOT_TOKEN`      | ZeeXa Bot    | @ZeeXaBOT  | **พูดคุยและสั่งงานเท่านั้น** — รับ-ส่งข้อความกับ Sunday (คำสั่ง / สนทนา)                  |
| `TG_BACKLOG_BOT_TOKEN`    | BACK_LOG Bot | (BACK_LOG) | **การแจ้งเตือนทั้งหมด** — System Alerts, Power Events, Config Backup, BACKLOG, escalation |
| `TG_NOTIFICATION_CHAT_ID` | —            | —          | Chat ID ปลายทาง (เจ้าของระบบ) สำหรับทั้ง 2 bots                                           |

**เส้นทางแจ้งเตือน (ทุก Agent และ System Services):**

- **ZeeXa Bot (Command Center):** ใช้เฉพาะการพูดคุยและสั่งงาน (Human ↔ Sunday/OpenClaw). **ห้าม** ใช้สำหรับส่ง Log หรือแจ้งเตือนอัตโนมัติจากสคริปต์
- **BACK_LOG Bot (Security & Notification):** เป็นช่องทางหลักสำหรับการแจ้งเตือนทุกรูปแบบ (Health check, Auto-upgrade, Security alerts, Watchtower) ผ่านสคริปต์ `tg-notify.sh` หรือใช้ Token `TG_BACKLOG_BOT_TOKEN` โดยตรงในระบบอัตโนมัติ
- **มาตรฐาน:** ทุกระบบอัตโนมัติที่ต้องการส่ง "รายงานสถานะ" ต้องใช้ BACK_LOG Bot เพื่อไม่ให้รบกวนช่องทางการสั่งงานหลักของ ZeeXa Bot

## 4. TECH_STACK

- **environment:** Docker container (image: `openclaw:local`, built from source)
- **identity_auth:** Tailscale Serve (host) + Device Pairing + Token Auth

## 5. AGENT_DEFINITIONS

### 5.1 MOTHER: Supreme Controller

- **id:** `mother`
- **role:** Agent Creator / Master Controller
- **workspace:** `/home/teaingtit/.openclaw/workspace-mother`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/minimax/minimax-m2.5`
- **model_fallback:** `openrouter/anthropic/claude-sonnet-4.6`
- **model_routing_category:** `8.2 REASONING_AND_COMPLEX_TASKS`
- **tools_allowed:** `*` (All tools implicitly available)
- **heartbeat:** `every 6h` — tasks: [gateway_status, json_validation, agent_count_checks]
- **binding:** none (intentional — accessed via Control UI / Claude Code / inter-agent only)

### 5.2 SUNDAY: Personal Secretary

- **id:** `sunday`
- **role:** Project Advisor / Sole Point of Contact / Task Router
- **workspace:** `/home/teaingtit/.openclaw/workspace-sunday`
- **sandbox_mode:** `off` (Docker container is isolation boundary; tools.allow enforces tool scope)
- **model_primary:** `openrouter/google/gemini-2.5-flash`
- **model_fallback:** `openrouter/openai/gpt-5.2`
- **model_routing_category:** `8.3 GENERAL_USE_AND_VALUE`
- **permissions:** [`read`, `exec` (read-only queries), `write` (workspace-local), session_tools, memory_tools]
- **communication_out:** Thai (to humans) / English (to AIs)
- **heartbeat:** `every 30m` (08:00–23:00 Asia/Bangkok) — tasks: [gateway_status, error_log_scan, daily_memory_summary]
- **routing:** `channel:telegram` → `sunday`

### 5.3 DEV: Code Specialist

- **id:** `dev`
- **role:** Specialist coding and technical analysis agent
- **workspace:** `/home/teaingtit/.openclaw/workspace-dev`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/minimax/minimax-m2.5`
- **model_fallback:** `openrouter/openai/gpt-5.2`
- **model_routing_category:** `8.1 CODING_AND_DEVELOPMENT`
- **permissions:** default (no explicit tools.allow — full tool access within container boundary)
- **heartbeat:** none
- **binding:** none — spawned via `sessions_spawn` by Sunday or Mother only
- **lifecycle:** `non-persistent` — no always-on session; `sessions_list` shows nothing between invocations (NORMAL); ALWAYS invoke via `sessions_spawn` tool with `agentId: "dev"`

### 5.4 FATHER: System & Hardware Specialist

- **id:** `father`
- **role:** Sysadmin and hardware management; server operations via SSH
- **workspace:** `/home/teaingtit/.openclaw/workspace-father`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/z-ai/glm-4.7-flash`
- **model_fallback:** `openrouter/deepseek/deepseek-v3.2`
- **model_routing_category:** `8.3 GENERAL_USE_AND_VALUE`
- **permissions:** [`read`, `exec` (SSH-only sysadmin queries), session_tools]
- **heartbeat:** `every 4h` (24/7) — tasks: [disk_check, system_load, docker_health, systemd_failed, security_updates]
- **binding:** none — spawned via `sessions_spawn` by Sunday or Mother only
- **lifecycle:** `non-persistent` — no always-on session; `sessions_list` shows nothing between invocations (NORMAL); ALWAYS invoke via `sessions_spawn` tool with `agentId: "father"`
- **ssh_target:** `minipc` (Master Node) via `ssh_config` at workspace root

### 5.5 DISPOSABLE SPECIALIST AGENTS

- **Role:** Temporary sub-agents spawned to reduce token bloat for primary agents on large context tasks.
- **Lifecycle:** `stateless` — strictly spawned per task, terminated after outputting a summary.
- **sandbox_mode:** `off` (Docker container is isolation boundary).
- **binding:** none — spawned via `sessions_spawn` by Dev, Father, or Mother ONLY.
- **Researcher (`researcher`):**
  - **Tool:** `browser` and `read`
  - **Model:** `openrouter/google/gemini-2.5-flash` (tier: 8.3)
  - **Purpose:** Web search and long document summarization.
- **LogAnalyzer (`log-analyzer`):**
  - **Tool:** `read` and `exec` (read-only utilities: `cat`, `grep`, etc.)
  - **Model:** `openrouter/deepseek/deepseek-v3.2` (tier: 8.3)
  - **Purpose:** Scanning massive log files for anomalies.
- **Coder (`coder`):**
  - **Tool:** `read` and `write`
  - **Model:** `openrouter/minimax/minimax-m2.5` (tier: 8.1 / 8.3)
  - **Purpose:** Stateless execution of code writing and modifying tasks delegated by `dev`.
- **CodeAnalyst (`code-analyst`):**
  - **Tool:** `read`, `exec` (read-only: grep, find, wc), `sessions_send`, `session_status`
  - **Model:** `openrouter/deepseek/deepseek-v3.2` (tier: 8.3)
  - **Purpose:** Code reading and analysis; summarize structure and patterns; spawned by dev, architect, or red-team.
- **DocWriter (`doc-writer`):**
  - **Tool:** `read`, `write`, `sessions_send`, `session_status`
  - **Model:** `openrouter/z-ai/glm-4.7-flash` (tier: 8.3)
  - **Purpose:** Documentation and report writing from templates; spawned by architect, mother, or dev.

### 5.6 THE ARCHITECT (Escalation Handler + Lead Developer)

- **id:** `architect`
- **role:** Escalation Handler (primary when spawned by mother), Lead Developer & Backlog Manager
- **workspace:** `~/.openclaw/workspace-architect` (canonical in repo `agents/workspace-architect/`)
- **model_primary:** `openrouter/openai/gpt-5.2`
- **model_fallback:** `openrouter/anthropic/claude-sonnet-4.6`
- **permissions:** `read`, `write` (backlog + repo), `exec`, `sessions_send`, `sessions_list`, `session_status`
- **heartbeat:** none (on-demand: mother spawns for escalation; or manual for backlog work)
- **escalation_flow:** Mother sends escalation payload → architect writes entry to `DEVELOPMENT_BACKLOG.md` → architect `sessions_send` to notifier → architect replies to mother with status
- **purpose:** When any agent fails 3 retries, mother spawns architect; architect logs to backlog and notifies user via notifier. Also triages and fixes backlog issues as Lead Developer.

### 5.7 MOTHER-RELAY: Herald (Batch Message Relay)

- **id:** `mother-relay`
- **role:** Batch message delivery to multiple agents
- **workspace:** `/home/teaingtit/.openclaw/workspace-mother-relay`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/z-ai/glm-4.7-flash`
- **model_fallback:** `openrouter/google/gemini-2.5-flash`
- **model_routing_category:** `8.3 GENERAL_USE_AND_VALUE`
- **permissions:** [`sessions_list`, `sessions_send`, `sessions_history`, `write` (delivery logs), `read`]
- **heartbeat:** none
- **lifecycle:** `non-persistent` — spawned on-demand by Mother; no exec, no sessions_spawn
- **purpose:** Delivers batched messages to target agents; logs delivery results to `memory/relay-YYYY-MM-DD.md`.

### 5.8 SAIN-EVALUATOR: Product Scoring Agent

- **id:** `sain-evaluator`
- **role:** Thai Shopee affiliate product evaluator for SAIN n8n pipeline
- **workspace:** `/home/teaingtit/.openclaw/workspace-sain-evaluator`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/google/gemini-2.0-flash-lite`
- **model_fallback:** none
- **model_routing_category:** `8.3 GENERAL_USE_AND_VALUE`
- **permissions:** none (`allow: []` — stateless JSON-in/JSON-out only)
- **heartbeat:** none
- **lifecycle:** `stateless` — invoked by n8n workflow (`workflow-evaluation.json` Config node)
- **purpose:** Evaluates product data and returns `{"score": N, "reasoning": "...", "hook": "..."}` for TikTok/Facebook short-form video potential in Thai market.

### 5.9 QA-REVIEWER: Code Review Specialist

- **id:** `qa-reviewer`
- **role:** Code diff reviewer — APPROVED / REJECTED verdicts
- **workspace:** `/home/teaingtit/.openclaw/workspace-qa-reviewer`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/moonshot/kimi-k2.5`
- **model_fallback:** `openrouter/openai/gpt-5.2`
- **model_routing_category:** `8.1 CODING_AND_DEVELOPMENT`
- **permissions:** [`read`, `write` (memory log), `sessions_list`, `sessions_send`, `session_status`, `memory_search`, `memory_get`]
- **heartbeat:** none
- **lifecycle:** `non-persistent` — spawned by Dev or Mother for PR/diff review
- **purpose:** Reviews code changes and returns structured verdict; no exec access (analysis only).

### 5.10 AGORA-HOST: Forum Orchestrator

- **id:** `agora-host`
- **role:** Multi-agent discussion facilitator (forum host)
- **workspace:** `/home/teaingtit/.openclaw/workspace-agora`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/z-ai/glm-4.7-flash`
- **model_fallback:** `openrouter/google/gemini-2.5-flash`
- **model_routing_category:** `8.3 GENERAL_USE_AND_VALUE`
- **permissions:** [`read`, `write` (AGORA_BOARD.md, DEVELOPMENT_BACKLOG.md, agora-sessions.md), `sessions_list`, `sessions_send`, `sessions_spawn`, `session_status`]
- **heartbeat:** none
- **lifecycle:** `non-persistent` — spawned by Mother for structured multi-agent deliberation
- **purpose:** Opens/closes forum sessions, invites participant agents (father, dev, researcher, coder), writes session records to AGORA_BOARD.md.

### 5.11 QA-TESTER: Automated Testing Specialist

- **id:** `qa-tester`
- **role:** Automated Testing Specialist — runs test suites, reports pass/fail to calling agent
- **workspace:** `/home/teaingtit/.openclaw/workspace-qa-tester`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/z-ai/glm-4.7-flash`
- **model_fallback:** `openrouter/google/gemini-2.5-flash`
- **model_routing_category:** `8.3 GENERAL_USE_AND_VALUE`
- **permissions:** [`read`, `exec` (run test commands), `sessions_list`, `sessions_send`, `session_status`]
- **heartbeat:** none
- **lifecycle:** `non-persistent` — spawned by Dev to offload long test runs
- **purpose:** Prevents Dev/Mother context from being consumed waiting for test execution; returns structured pass/fail summary.

### 5.12 RED-TEAM: Security Analyst

- **id:** `red-team`
- **role:** Adversarial security analysis of agent configurations
- **workspace:** `/home/teaingtit/.openclaw/workspace-red-team`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/moonshot/kimi-k2.5`
- **model_fallback:** `openrouter/openai/gpt-5.2`
- **model_routing_category:** `8.1 CODING_AND_DEVELOPMENT`
- **permissions:** [`read` (SOUL.md files), `write` (red team reports), `sessions_send`, `session_status`, `memory_search`, `memory_get`]
- **heartbeat:** none
- **lifecycle:** `non-persistent` — spawned by Mother for periodic security reviews
- **purpose:** Reads agent SOUL.md files for reconnaissance; writes findings to `knowledge-base/red-team/`; strictly analysis-only — no exec, no sessions_spawn.

### 5.13 GIT-OPS: Git Operations (Fork-Only, No PR)

- **id:** `git-ops`
- **role:** Git operations specialist — status, fetch, commit, pull (rebase), push to fork only; no PR workflow
- **workspace:** `~/.openclaw/workspace-git-ops`
- **sandbox_mode:** `off` (Docker container is isolation boundary)
- **model_primary:** `openrouter/google/gemini-2.5-flash`
- **git_wrapper:** `~/bin/git` — smart wrapper that auto-redirects to `~/projects/openclaw` when cwd is not a git repo; allows agent to run plain `git` commands without `-C` flag
- **model_routing_category:** `8.3 GENERAL_USE_AND_VALUE`
- **permissions:** [`read`, `write`, `exec`] — no browser, no session tools by default
- **heartbeat:** none (on-demand only)
- **lifecycle:** persistent (session can be invoked via Control UI or `openclaw agent --agent git-ops --message "..."`)
- **push_policy:** Push only to remote `fork` branch `main`; never push to `origin`; refuse any `gh pr *` or PR-related requests
- **runbook:** See `docs/agents/git-ops-agent.md`; workspace files in repo `agents/workspace-git-ops/`

### 5.14 DEPLOY: Release Pipeline Coordinator

- **id:** `deploy`
- **role:** Release pipeline coordinator — prerequisites, Docker/npm build, restart via father, health check, rollback
- **workspace:** `~/.openclaw/workspace-deploy` (canonical in repo `agents/workspace-deploy/`)
- **model_primary:** `openrouter/google/gemini-2.5-flash`
- **permissions:** `read`, `write`, `exec`, `sessions_send`, `sessions_list`, `sessions_spawn`, `session_status`
- **heartbeat:** none (on-demand)
- **lifecycle:** non-persistent — spawned by mother or user for release tasks

### 5.16 NOTIFIER: Telegram Notification Dispatcher

- **id:** `notifier`
- **role:** Telegram notification dispatcher — receives payload from architect or intel, formats message, runs `tg-notify.sh`
- **workspace:** `~/.openclaw/workspace-notifier` (canonical in repo `agents/workspace-notifier/`)
- **model_primary:** `openrouter/google/gemini-2.5-flash`
- **permissions:** `exec` (tg-notify only), `sessions_send`, `session_status`
- **heartbeat:** none (on-demand when architect or intel sends notification request)

### 5.17 INTEL: Intelligence Gathering Coordinator

- **id:** `intel`
- **role:** Intelligence coordinator — daily sweep via researcher (OpenRouter, OpenClaw releases, AI news, HN, Reddit, GitHub trending); synthesize; report to mother; daily digest via notifier
- **workspace:** `~/.openclaw/workspace-intel` (canonical in repo `agents/workspace-intel/`)
- **model_primary:** `openrouter/google/gemini-2.5-flash`
- **permissions:** `read`, `write`, `browser`, `sessions_send`, `sessions_spawn`, `sessions_list`, `session_status`, `memory_set`, `memory_get`
- **heartbeat:** `every: "24h"` (design intent: daily 06:00 Asia/Bangkok; gateway v2026.3.2 does not support `at`/`timezone` — use cron or upgrade for fixed-time schedule)
- **output:** `~/.openclaw/knowledge-base/intel/YYYY-MM-DD.md`; actionable items to mother; digest to notifier
- **lifecycle:** persistent (heartbeat-driven). See §9.6 INTELLIGENCE_UNIT.

### 5.18 SOT-KEEPER: Source of Truth Keeper

- **id:** `sot-keeper`
- **role:** Keep SYSTEM_INDEX.md and OVERVIEW.th.md in sync with openclaw.json, ANTIGRAVITY.md, DetailHardware.md, and agents/workspace-\*; heartbeat checks diff, updates index/overview only; requests commit via git-ops; does not edit ANTIGRAVITY.md or openclaw.json
- **workspace:** `~/.openclaw/workspace-sot-keeper` (canonical in repo `agents/workspace-sot-keeper/`)
- **model_primary:** `openrouter/google/gemini-2.5-flash`
- **permissions:** `read`, `write` (SYSTEM_INDEX.md, OVERVIEW.th.md only), `exec`, `sessions_send`, `session_status`
- **heartbeat:** `every: "6h"`
- **lifecycle:** persistent (heartbeat-driven)

## 6. CRITICAL_FILE_MAP

<!-- Paths: repo-root-relative for repo files; ~/.openclaw for state/host -->

- `~/.openclaw/openclaw.json`: Global settings, agent list, gateway auth (never overwrite; use `openclaw config set` / `openclaw doctor --fix`)
- `.antigravityrules`: Critical operating standards for AI (rules 0–20 + bookend)
- `docs/AGENT_DESIGN_GUIDE.md`: Best practices for building AI agents
- `docs/AGENT_STANDARD.md`: Single agent standard (workspace files, script-first heartbeat, TOOLS sync, invocation format)
- `docs/agents/git-ops-agent.md`: Git-ops agent runbook and guardrails (fork-only push, no PR)
- `agents/workspace-git-ops/`: Canonical workspace files for `git-ops` (copy to `~/.openclaw/workspace-git-ops/` after `agents add`)
- `DetailHardware.md`: Hardware, nodes, network, SSH roles (device-specific or deployment advice)
- `SCRIPTS_REGISTRY.md`: Script registry — which scripts exist and how to invoke them (§6b, docs/AGENT_SCRIPT_FIRST.md)
- `docs/workflows/n8n/`: n8n workflow templates (Daily Health, SaaS automation)
- `docs/AGENT_SCRIPT_FIRST.md`: Agent ↔ script mapping; ใช้สคริปต์แทนงาน routine, เรียก agent เมื่อจำเป็น
- `docs/HEALTH_ESCALATION.md`: เมื่อสคริปต์แก้ไม่ได้ → เขียน health-escalation-pending.json; agent อ่านแล้วลองแก้, ส่ง Telegram เฉพาะเมื่อ agent แก้ได้หรือแก้ไม่ได้
- `agents/workspace-architect/`, `workspace-deploy/`, `workspace-notifier/`, `workspace-intel/`, `workspace-sot-keeper/`: Canonical workspace files for architect, deploy, notifier, intel, sot-keeper
- `~/.openclaw/knowledge-base/intel/`: Daily intel reports (YYYY-MM-DD.md)
- `~/.openclaw`: State directory (Credentials, sessions, agent storage) — volume-mounted into container
- `docker-compose.yml`: Docker service definition
- `docker-compose.override.yml`: Local overrides (--tailscale off, bridge port) — gitignored
- `.env`: Docker env vars (token, ports, image, config/workspace paths) — gitignored; at repo root when running from host
- `scripts/docker-rebuild.sh`: Rebuild image + recreate container in one command

## 6b. SCRIPT_TOOLKIT (Script-First Pattern)

- **Purpose:** ลดการใช้โทเคนโดยให้ agent เรียก shell script สำหรับงาน routine (health check, config validation, log scan, git preflight) แทนการให้ LLM ทำทุกครั้ง
- **Registry:** `SCRIPTS_REGISTRY.md` — agent อ่านไฟล์นี้เพื่อดูว่ามีสคริปอะไรบ้างและเรียกอย่างไร. **Agent ↔ สคริปต์ และเมื่อไหร่เรียก agent:** `docs/AGENT_SCRIPT_FIRST.md`
- **Ops scripts:** `scripts/ops/` — health-check.sh, gateway-recovery.sh (restart gateway + health-check + log tail), **health-check-fix-or-escalate.sh** (พบ error → รันสคริปต์แก้ → ถ้าหายเงียบ; ถ้าไม่หายเขียน `~/.openclaw/health-escalation-pending.json` ไม่ส่ง Telegram — agent อ่านแล้วลองแก้, ส่ง Telegram เฉพาะเมื่อ agent แก้ได้หรือ agent แก้ไม่ได้ ดู `docs/HEALTH_ESCALATION.md`), **post-reboot-diagnosis.sh** (หาสาเหตุ server ล่มหลัง manual reboot — อ่าน journalctl -b -1 หา OOM/panic), config-validate.sh, log-scan.sh, system-report.sh, git-preflight.sh, agent-list.sh (output JSON สำหรับ agent)
- **Pattern:** Big model วางแผน/สั่งงาน → small model หรือ script ทำ execution. Heartbeat ของ father, mother, sunday, sot-keeper ควรรันสคริปก่อน; ถ้าผล OK ไม่ต้องใช้ LLM
- **OS-level recovery (จำเป็นสำหรับกู้ gateway):** Agent รัน**ภายใน gateway** หรือต้องใช้ gateway เพื่อ spawn Father — เมื่อ **gateway เองล่มหรือ restart loop** agent จะรันไม่ได้ จึงกู้คืนเองไม่ได้. การกู้ต้องทำที่ **ระดับ OS**: ใช้ systemd timer รัน **health-check-fix-or-escalate.sh** ทุก 15 นาที. Script รัน health-check → ถ้าไม่ ok รัน gateway-recovery.sh → ตรวจซ้ำ → ถ้าหาย exit 0 เงียบ; ถ้ายังไม่หายเขียน `~/.openclaw/health-escalation-pending.json` (ไม่ส่ง Telegram). Agent อ่านไฟล์นี้แล้วลองแก้; **ส่ง Telegram เฉพาะเมื่อ agent แก้ได้หรือ agent แก้ไม่ได้** (ดู `docs/HEALTH_ESCALATION.md`). Timer: `scripts/systemd-user/openclaw-health.timer` + `.service`. Copy ไป `~/.config/systemd/user/` แล้ว `systemctl --user enable --now openclaw-health.timer`.
- **Server health แบบ OS-only (ลดโทเคนสูงสุด):** เมื่อ **openclaw-health.timer เปิดอยู่** งาน server (health check, CRITICAL → recovery, แจ้ง Telegram) ทำโดยสคริปต์ระดับ OS ทั้งหมด. งาน server ไม่ใช้โทเคนจาก agent อีก. ดู §10.1d.
- **SOT Enforcement System (3 layers):** ป้องกัน ANTIGRAVITY.md drift เมื่อ agent เปลี่ยน structural files:
  - **Layer 1 — pre-commit hook** (`scripts/ops/pre-commit-sot-check.sh`): บล็อก commit ที่แตะ `openclaw.json`, `DetailHardware.md`, `SOUL.md`, `IDENTITY.md` โดยไม่ stage `ANTIGRAVITY.md`. ลงทะเบียนไว้ใน `git-hooks/pre-commit` (repo's `core.hooksPath`). Bypass: `SKIP_SOT_CHECK=1 git commit ...` (ฉุกเฉินเท่านั้น).
  - **Layer 2 — gen-agent-index.sh** (`scripts/ops/gen-agent-index.sh`): re-generate ตาราง agent ใน `## Agents` section ของ `SYSTEM_INDEX.md` จาก `openclaw.json` อัตโนมัติ. Exit 0 = clean, exit 1 = drift fixed, exit 2 = error. sot-keeper รัน script นี้ก่อน LLM ทุก heartbeat.
  - **Layer 3 — systemd path watcher** (`openclaw-sot-sync.path` + `.service`): trigger Layer 2 real-time เมื่อ `openclaw.json` หรือ `DetailHardware.md` เปลี่ยน. ใช้ `PathChanged=` (รองรับ atomic write). Install: `cp scripts/systemd-user/openclaw-sot-sync.{path,service} ~/.config/systemd/user/ && systemctl --user enable --now openclaw-sot-sync.path`.
  - **หมายเหตุ:** Layer 1 flag เท่านั้น — ไม่ auto-overwrite prose ของ ANTIGRAVITY.md. Human/agent ต้องอัปเดต §5 (AGENT_DEFINITIONS), §3 (HARDWARE_INFRASTRUCTURE) ด้วยตนเอง.

## 7. ACTIVE_ENVIRONMENT_STATE

- **tailscale_url:** `https://home-server.taila0574b.ts.net`
- **gateway_port:** `18789` (host)
- **bridge_port:** `18791` (host) → `18790` (container)
- **ui_allowed_origins:** [`https://home-server.taila0574b.ts.net`]
- **active_agents:** [`mother`, `sunday`, `dev`, `father`, `researcher`, `log-analyzer`, `qa-tester`, `mother-relay`, `sain-evaluator`, `qa-reviewer`, `agora-host`, `red-team`, `coder`, `code-analyst`, `doc-writer`, `git-ops`, `architect`, `deploy`, `notifier`, `intel`, `sot-keeper`]
- **default_agent:** `sunday`
- **orchestration:** `enabled` (maxConcurrent: 10)
- **runtime:** systemd user service `openclaw-gateway.service` (primary)
- **systemd_service:** enabled — gateway runs via systemd; use `systemctl --user enable --now openclaw-gateway.service`
- **Docker gateway:** opt-in only — use profile `docker-gateway` to run gateway in Docker; do not start when systemd is primary (port 18789 conflict). See §7.0.
- **n8n:** Workflow automation on minipc — container `sain-n8n` port `5678` (PostgreSQL backend, Basic Auth). Image: `docker.n8n.io/n8nio/n8n:latest` (current 2.10.3). Access: `http://100.96.9.50:5678`. Workflow templates: `docs/workflows/n8n/`. **Update:** pull `docker.n8n.io/n8nio/n8n:latest`, stop/rm `sain-n8n`, recreate with same env/volumes/network. After Docker restart, reconnect network: `docker network connect sain_network sain-n8n` then `docker restart sain-n8n`.
- **Open WebUI:** Web UI for Ollama on minipc — container `open-webui` port `3000` (UI). Image: `ghcr.io/open-webui/open-webui:main`. Access: `http://100.96.9.50:3000`. Setup: `docs/workflows/open-webui/` (compose: `docker compose -f docs/workflows/open-webui/docker-compose.example.yml up -d`). First run: create admin user in UI.

## 7.0 GATEWAY_SINGLE_RUNTIME (systemd vs Docker)

- **Cause of conflict:** Both systemd (`openclaw-gateway.service`) and Docker (`openclaw-gateway` in docker-compose) bind host port **18789**. If both run, the second process cannot bind and may spin (high CPU) or fail.
- **Rule:** Run **exactly one** gateway runtime per host:
  - **Systemd (primary):** `systemctl --user enable --now openclaw-gateway.service`. Do **not** start the Docker gateway container (`docker compose` without profile, or stop `openclaw-gateway` / `openclaw-cli` if already running).
  - **Docker:** `docker compose --profile docker-gateway up -d`. Ensure systemd gateway is disabled: `systemctl --user disable --now openclaw-gateway.service`.
- **Long-term fix:** docker-compose gateway (and openclaw-cli) use profile `docker-gateway` so a plain `docker compose up -d` does not start them; use systemd as primary and only start Docker gateway when explicitly needed.
- **Scripts that start Docker gateway (do not run when systemd is primary):** `scripts/docker-rebuild.sh`, `docker-setup.sh`, `clawdock-start` (from `scripts/shell-helpers/clawdock-helpers.sh`). All now pass `--profile docker-gateway` so intent is explicit.
- **Audit when using systemd as primary:** (1) **Cron / systemd timer** — any job that runs `docker compose up -d` or `docker compose ... openclaw-gateway` from the project dir must use `--profile docker-gateway` only when Docker gateway is intended, or be removed/disabled so gateway is not started by cron/timer. (2) **Startup script / .bashrc / .profile** — if they source clawdock-helpers and call `clawdock-start`, or run `docker-setup.sh` / `docker-rebuild.sh` at login, either remove those calls or ensure they do not start the gateway (e.g. do not auto-run `clawdock-start` when systemd is primary).

## 7.1 DOCKER_SETUP

- **profile:** `docker-gateway` — start with `docker compose --profile docker-gateway up -d`. Do not use when systemd is primary (port 18789).
- **container:** `openclaw-openclaw-gateway-1`
- **image:** `openclaw:local` (built from repo root `Dockerfile`)
- **config_mount:** `~/.openclaw` → `/home/node/.openclaw`
- **workspace_mount:** `~/.openclaw/workspace` → `/home/node/.openclaw/workspace`
- **tailscale:** managed by host; container uses `--tailscale off` (override in `docker-compose.override.yml`)
- **healthcheck:** TCP probe to port 18789 every 30s, 3 retries, 20s start period
- **rebuild_script:** `bash scripts/docker-rebuild.sh` (from repo root; builds image + recreates container)
- **restart:** `docker compose -f docker-compose.yml -f docker-compose.override.yml restart openclaw-gateway`
- **logs:** `docker compose -f docker-compose.yml -f docker-compose.override.yml logs -f openclaw-gateway`
- **cli:** `docker compose -f docker-compose.yml run --rm openclaw-cli <command>`

## 7.2 MODEL_STRING_FORMAT

OpenClaw parses the prefix before the first `/` as the provider name.

- ✅ CORRECT: `openrouter/anthropic/claude-opus-4-6` → provider=`openrouter`, model=`anthropic/claude-opus-4-6`
- ✅ CORRECT: `openrouter/openai/gpt-5.2` → provider=`openrouter`, model=`openai/gpt-5.2`
- ❌ WRONG: `anthropic/claude-opus-4-6` → tries provider=`anthropic` directly → no API key → fails
- ❌ WRONG: `openai/gpt-5.2` → tries provider=`openai` directly → no API key → fails

**Rule:** Cloud models: prefix `openrouter/`. Bare `anthropic/` or `openai/` fail (no direct API keys).

## 7.3 SANDBOX_IN_DOCKER

- `sandbox.mode: "all"` requires Docker daemon access inside the container (Docker-in-Docker). Not configured.
- All agents use `sandbox.mode: "off"`. The Docker container itself is the OS-level isolation boundary.
- Per-agent tool restrictions still enforced via `tools.allow` in `openclaw.json` (sunday has explicit allowlist).
- **Exec Scope Reality:** Any agent with the `exec` tool can technically run any command within the container. Restrictions (like Sunday being read-only) are currently **doc-level enforced** via their `TOOLS.md` and `SOUL.md`. Mother must periodically audit gateway logs.
- If stricter OS-level sandboxing is needed in future: mount Docker socket (`/var/run/docker.sock`) into the gateway container and change sandbox mode per agent.

## 7.4 AGENT_ROUTING_DESIGN

- **mother (no channel binding):** Mother has no `bindings[]` entry by design. She is accessed directly via
  the Control UI, Claude Code sessions, or inter-agent calls — never via end-user channels (Telegram, etc.).
  This prevents accidental exposure of her unrestricted sandbox to user-facing surfaces.
- **sunday (explicit Telegram binding):** `channel:telegram → sunday` is set explicitly, not relying solely
  on `default: true`. This ensures routing is deterministic even if a second agent is later set as default.

## 8. ROUTING_MODELS (OpenRouter — February 2026 Benchmarks)

<!-- อัปเดต: กุมภาพันธ์ 2026 — อ้างอิงจาก SWE-bench Verified, HLE, GPQA Diamond, Terminal-Bench -->
<!-- ราคาจาก: openrouter.ai/models, pricepertoken.com, artificialanalysis.ai (Feb 2026) -->
<!-- ใช้หัวข้อนี้เพื่อเลือก model ที่เหมาะกับ tier ของ Agent — ห้ามเดาเอง -->

### 8.1 CODING_AND_DEVELOPMENT

<!-- tier นี้สำหรับงาน code-heavy, agentic, multi-step engineering — ดู SWE-bench เป็นตัวชี้วัดหลัก -->
<!-- SWE-bench Verified = วัดว่าโมเดลแก้ GitHub issue จริงได้กี่% (500 งาน, Python repo, isolated Docker) -->
<!-- Terminal-Bench = วัดประสิทธิภาพงาน agentic ผ่าน terminal/CLI workflows -->

| Model               | OpenRouter ID                          | Input/1M | Output/1M | Context | SWE-bench    | หมายเหตุ                                                          |
| ------------------- | -------------------------------------- | -------- | --------- | ------- | ------------ | ----------------------------------------------------------------- |
| **Claude Opus 4.5** | `openrouter/anthropic/claude-opus-4-5` | $5.00    | $25.00    | 200K    | **80.9%** 🥇 | อันดับ 1 Python repo tasks                                        |
| **Claude Opus 4.6** | `openrouter/anthropic/claude-opus-4-6` | $5.00    | $25.00    | 200K    | **80.8%** 🥈 | ไม่ได้ใช้งาน — แพงกว่า GPT-5.2 3x (SWE ใกล้เคียงกัน)              |
| **MiniMax M2.5**    | `openrouter/minimax/minimax-m2.5`      | $0.30    | $1.20     | 1M      | **80.2%** 🥉 | open-source อันดับ 1, 230B params; Lightning: $0.30/$2.40 200K    |
| **GPT-5.2**         | `openrouter/openai/gpt-5.2`            | $1.75    | $14.00    | 400K    | **80.0%**    | ✅ PRIMARY: mother, dev \| fallback: sunday; cached input: $0.175 |
| **GLM-5 (Z.ai)**    | `openrouter/z-ai/glm-5`                | $0.95    | $2.55     | 200K    | **77.8%**    | Chatbot Arena 1451 (#1 overall), MIT license, 744B MoE            |
| **Kimi K2.5**       | `openrouter/moonshot/kimi-k2.5`        | $0.60    | $3.00     | 256K    | **76.8%**    | HumanEval 99.0% (near-perfect), MATH-500 98.0%                    |
| **Gemini 3.1 Pro**  | `openrouter/google/gemini-3.1-pro`     | $2.00    | $12.00    | 1M      | **76.2%**    | >200K ctx: $4/$18; Batch API: 50% off; SWE-bench Pro 43.3%        |
| **GPT-5.3 Codex**   | `openrouter/openai/gpt-5.3-codex`      | $1.75    | $14.00    | 400K    | —            | Terminal-Bench 75.1%, SWE-bench Pro 56.8% — เด่นงาน agentic       |
| **Devstral 2**      | `openrouter/mistralai/devstral-2`      | —        | —         | —       | ~73%         | ราคายังไม่ประกาศ; cost-effective agentic coding                   |

<!-- ตัวอย่างต้นทุนจริง: งาน code review หนึ่งครั้ง (~100K input, 2K output) -->
<!-- Claude Opus 4.6: $0.50 + $0.05 = ~$0.55/ครั้ง -->
<!-- MiniMax M2.5: $0.03 + $0.002 = ~$0.032/ครั้ง (ถูกกว่า Opus ~17x) -->
<!-- GPT-5.2: $0.175 + $0.028 = ~$0.20/ครั้ง (ถ้าใช้ cached input) -->

### 8.2 REASONING_AND_COMPLEX_TASKS

<!-- tier นี้สำหรับงานที่ต้องคิดลึก, multi-hop reasoning, math, science — ดู HLE/GPQA เป็นหลัก -->
<!-- GPQA Diamond = ข้อสอบระดับ PhD ด้าน biology/chemistry/physics -->
<!-- HLE = Humanity's Last Exam: 2,500 คำถามยากสุดจาก Center for AI Safety ครอบทุกสาขา -->
<!-- ARC-AGI-2 = วัด general intelligence / pattern recognition ที่ยังท้าทาย AI -->

| Model               | Input/1M | Output/1M | Context | GPQA ◆   | HLE      | ARC-AGI-2 | หมายเหตุ                                                                   |
| ------------------- | -------- | --------- | ------- | -------- | -------- | --------- | -------------------------------------------------------------------------- |
| **GPT-5.2**         | $1.75    | $14.00    | 400K    | **93.2** | 50.0     | 54.2      | ✅ PRIMARY: mother \| ดีสุดด้าน doctoral-level science                     |
| **Claude Opus 4.6** | $5.00    | $25.00    | 200K    | 91.3     | **53.0** | **68.8**  | ดีสุดด้าน HLE + ARC-AGI; τ2-bench 91.9 (ไม่ได้ใช้งาน — แพงกว่า GPT-5.2 3x) |
| **Kimi K2.5**       | $0.60    | $3.00     | 256K    | 87.6     | —        | —         | AIME 2025 100%, MMLU 92.0% — ถูกกว่า Opus 8x                               |
| **GLM-5 (Z.ai)**    | $0.95    | $2.55     | 200K    | 86.0     | —        | —         | open-source, MIT; Chatbot Arena #1                                         |
| **GLM-4.7 (Z.ai)**  | $0.06    | $0.40     | 203K    | 85.7     | ~42.8%   | —         | ถูกมาก; AIME 95.7%, LiveCodeBench 84.9%; Flash variant                     |
| **Gemini 3.1 Pro**  | $2.00    | $12.00    | 1M      | —        | —        | **77.1%** | multimodal STEM; ARC-AGI-2 สูงสุดในกลุ่ม Google                            |

<!-- τ2-bench (tool-use + agentic): Claude Opus 4.6 = 91.9 (highest) -->
<!-- GLM-4.7 Flash: ถ้าต้องการ reasoning ราคาถูกที่สุด → $0.06/$0.40 คือ 83x ถูกกว่า Opus -->
<!-- GPT-5.2 Pro variant: $21/$168 — ห้ามใช้ใน production ถ้าไม่จำเป็น -->

### 8.3 GENERAL_USE_AND_VALUE

<!-- tier นี้สำหรับงานทั่วไป, conversation, delegation — เน้น cost-efficiency และ instruction-following -->

| Model                     | Input/1M | Output/1M | Context | SWE-bench | หมายเหตุ                                                                  |
| ------------------------- | -------- | --------- | ------- | --------- | ------------------------------------------------------------------------- |
| **Gemini 2.5 Flash**      | $0.30    | $2.50     | 1M      | —         | ✅ PRIMARY: sunday; low-latency chat, 90% cost reduction vs Sonnet        |
| **DeepSeek V3.2**         | $0.25    | $0.40     | 64K     | 73.0%     | ✅ PRIMARY: father; "Value King" — ~90% perf GPT-5.1 ที่ 1/50 ราคา        |
| **Gemini 2.0 Flash Lite** | $0.075   | $0.30     | 1M      | —         | ✅ PRIMARY: sain-evaluator; cost-effective, high-volume structured output |
| **GLM-4.7 Flash**         | $0.06    | $0.40     | 203K    | —         | ถูกที่สุดในกลุ่ม; เหมาะงาน delegation/routing                             |
| **Claude Sonnet 4.6**     | $3.00    | $15.00    | 1M      | 77.2%     | ✅ fallback: mother, dev; instruction-following ยอดเยี่ยม                 |
| **Gemini 3 Flash**        | $0.50    | $3.00     | 1M      | —         | near-Pro reasoning, latency ต่ำ, Batch API: 50% off                       |
| **Gemini 3.1 Pro**        | $2.00    | $12.00    | 1M      | 76.2%     | cost-effective pro; >200K: $4/$18                                         |
| **GPT-5.2**               | $1.75    | $14.00    | 400K    | 80.0%     | ✅ PRIMARY: mother, dev \| fallback: sunday                               |

<!-- เปรียบเทียบต้นทุนงาน Telegram chat session (~10K input, 500 output ต่อ turn) -->
<!-- DeepSeek V3.2:    $0.003 + $0.0002 = ~$0.003/turn -->
<!-- Gemini 2.5 Flash: $0.003 + $0.001  = ~$0.004/turn (✅ sunday) -->
<!-- Claude Sonnet:    $0.03  + $0.008  = ~$0.038/turn (fallback mother/dev; แพงกว่า DeepSeek ~13x) -->
<!-- Gemini 3 Flash:   $0.005 + $0.002  = ~$0.007/turn (ถูก + เร็ว — ดีสำหรับ high-volume) -->
<!-- Claude Opus 4.6:  $0.05  + $0.013  = ~$0.063/turn (แพงที่สุด — ไม่ได้ใช้งาน) -->

### 8.4 CURRENT_SYSTEM_ASSIGNMENT

<!-- ไม่เก็บ copy ที่นี่ — อ่านจาก openclaw.json โดยตรงเพื่อป้องกัน drift -->

**Live source:** `~/.openclaw/openclaw.json` → `agents.list[].model.{primary, fallbacks}`

```bash
# ดู assignment ทั้งหมดในครั้งเดียว
python3 -c "
import json
d = json.load(open('/home/teaingtit/.openclaw/openclaw.json'))
for a in d['agents']['list']:
    m = a.get('model', {})
    fb = m.get('fallbacks', ['NOT SET'])[0]
    print(f\"{a['id']:20} {m.get('primary','?'):50} {fb}\")
"
```

**เหตุผลการเลือก tier (คงไว้เพราะไม่อยู่ใน openclaw.json):**

- `dev` → MiniMax M2.5: SWE 80.2%, วางแผนและออกแบบ — ประหยัดกว่า GPT-5.2 ~6x; fallback GPT-5.2 สำหรับ complex reasoning
- `coder` → MiniMax M2.5: SWE 80.2%, ลงมือพิมพ์โค้ด — ประหยัดกว่า GPT-5.2 ~6x
- `mother` → MiniMax M2.5: 1M ctx, $0.30/$1.20 — ประหยัด heartbeat 6h/ครั้งได้มหาศาล
- `father` → GLM-4.7 Flash: $0.06/$0.40 — ถูกมาก เพียงพอสำหรับ sysadmin tasks
- `qa-reviewer` → Kimi K2.5: HumanEval 99%, GPQA 87.6% — cost-effective code review
- `red-team` → Kimi K2.5: security analysis รายเดือน — เหมาะกับ reasoning ดี ราคาถูก
- `architect` → GPT-5.2: GPQA 93.2% — architecture และ backlog; fallback Sonnet
- `code-analyst` → DeepSeek V3.2: อ่าน/วิเคราะห์โค้ด — worker ราคาถูก
- `doc-writer` → GLM-4.7 Flash: เขียน docs จาก template — worker ราคาถูกที่สุด
- `sain-evaluator` → Gemini 2.0 Flash Lite: $0.075/$0.30 — high-volume structured JSON output

### 8.5 MODEL_REVIEW_POLICY

<!-- นโยบายทบทวนโมเดลเพื่อป้องกัน cost drift — อัปเดตทุกสัปดาห์หรือเมื่อมี trigger -->

**Review cadence: รายสัปดาห์** (Mother heartbeat task #5 — เปลี่ยนจาก monthly เป็น weekly ตั้งแต่ 2026-02-26)

**Automation:** Mother ใช้ `model-optimizer.py` คำนวณ value score อัตโนมัติทุกสัปดาห์

- Script: `~/.openclaw/workspace-mother/scripts/model-optimizer.py`
- Benchmark DB: `~/.openclaw/workspace-mother/scripts/benchmark-scores.json` (Mother ดูแล)
- Price baseline: `~/.openclaw/workspace-mother/scripts/model-prices-baseline.json`

**Review triggers (ตรวจสอบเมื่อ):**

- รายสัปดาห์ — Mother heartbeat task #5 (`model-optimizer.py --check`) ตรวจแล้วพบ drift
- มีโมเดลใหม่ออก ที่ SWE-bench / GPQA ดีขึ้น > 3%
- ราคา OpenRouter ของโมเดลที่ใช้อยู่เปลี่ยน > 20%
- OpenRouter key ถึง limit (ต้อง audit ทันที)

**Review process:**

1. อัปเดต `benchmark-scores.json` ด้วยข้อมูลล่าสุดจาก artificialanalysis.ai (ถ้ามีการเปลี่ยนแปลง)
2. รัน `python3 model-price-tracker.py` เพื่ออัปเดตราคา baseline
3. รัน `python3 model-optimizer.py --check` เพื่อดู value score ranking
4. อัปเดต Section 8.1–8.3 tables ด้วยข้อมูลใหม่ (manual)
5. ถ้า assignment ควรเปลี่ยน → รอ approval จากเจ้านาย แล้วรัน `--apply`
   - Script จะอัปเดต `openclaw.json` + Section 8.4 อัตโนมัติ
   - Script print sed commands สำหรับ SOUL.md / TOOLS.md ของ agent ที่เปลี่ยน
6. Restart gateway หลัง `openclaw.json` เปลี่ยน

**Cost drift prevention rules:**

- ✅ Default เสมอ: เลือกโมเดลที่ถูกที่สุดในระดับ tier ที่ task นั้นต้องการ
- ✅ ทุกครั้งที่สร้าง agent ใหม่: Mother ต้องระบุ `tier` และ `ราคา approx/session` ใน plan ก่อน
- ❌ ห้ามใช้ tier 8.1/8.2 กับ agent ที่ทำแค่ delegation หรือ conversation — tier 8.3 เพียงพอ
- ❌ ห้าม assign โมเดลโดยไม่ดูราคาเปรียบเทียบใน Section 8 ก่อน

**OpenRouter budget protection:**

- ตั้ง monthly spending limit ที่ https://openrouter.ai/settings/keys
- แนะนำ: คำนวณจาก `(จำนวน agent × heartbeat/เดือน × ค่าเฉลี่ย/session) × 3x safety margin`
- ถ้า key ถึง limit → agents ทุกตัว fail ทันที (403) → ต้อง top-up หรือขึ้น limit

## 9. AGENT_INTERACTION_RULES

> กฎการเรียกใช้ Agent ระหว่างกัน — ห้ามเดาหรือสุ่ม

### 9.1 AGENT_LIFECYCLE_TYPES

| Agent    | Lifecycle          | Sessions                                                               |
| -------- | ------------------ | ---------------------------------------------------------------------- |
| `mother` | **persistent**     | always-on; `sessions_list` always shows an active session              |
| `sunday` | **persistent**     | always-on; `sessions_list` always shows an active session              |
| `dev`    | **non-persistent** | spawned on-demand; `sessions_list` shows nothing between runs — NORMAL |
| `father` | **non-persistent** | spawned on-demand; `sessions_list` shows nothing between runs — NORMAL |

### 9.2 NON_PERSISTENT_INVOCATION_RULE

> ⚠️ CRITICAL: If `sessions_list` shows no session for `dev` or `father`, that is NORMAL — NOT an error.

- **`sessions_spawn` is a JSON tool call** — NOT a CLI command. Use `agentId` parameter:
  ```json
  { "task": "...", "agentId": "father", "label": "server-health", "mode": "run" }
  ```
- **NEVER** call `sessions_spawn` without `agentId` for specialist tasks — that creates a generic unnamed sub-agent
- **NEVER** fall back to a generic unnamed sub-agent because a specialist doesn't appear in `sessions_list`
- **NEVER** use `sessions_send` to an agent that isn't currently running (it will fail silently)

### 9.3 DELEGATION_MATRIX

| Task Type                  | Delegate To         | Invocation                                  |
| -------------------------- | ------------------- | ------------------------------------------- |
| System/Hardware/SSH        | `father`            | `sessions_spawn` tool · `agentId: "father"` |
| Code Planning/Analysis     | `dev`               | `sessions_spawn` tool · `agentId: "dev"`    |
| Code Writing               | `coder` (via `dev`) | `sessions_spawn` tool · `agentId: "coder"`  |
| Agent create/delete/config | `mother`            | `sessions_send` (persistent)                |
| Report to human            | `sunday` (self)     | reply via Telegram                          |

### 9.4 SESSIONS_SPAWN_USAGE

`sessions_spawn` is a **JSON tool call** — NOT a CLI command. Never write `sessions_spawn --agent <id>`.
Correct format:

```json
{
  "task": "Objective: ...\nContext: ...\nConstraints: ...\nDeliverables: ...",
  "agentId": "father",
  "label": "server-health",
  "mode": "run"
}
```

### 9.5 TASK_HANDOFF_FORMAT

The `task` field must be a structured contract:

```
Objective: [Specific goal]
Context: [Background, paths, relevant state]
Constraints: [Scope, safety rules, tier limits]
Deliverables: [Expected output format]
```

### 9.6 INTELLIGENCE_UNIT (Self-Update Loop)

- **intel agent** runs daily at 06:00 Asia/Bangkok; spawns **researcher** to gather from: OpenRouter models/pricing, OpenClaw GitHub releases, AI news, Hacker News, Reddit (r/MachineLearning, r/LocalLLaMA), GitHub trending.
- **Synthesis:** intel writes `~/.openclaw/knowledge-base/intel/YYYY-MM-DD.md` and flags actionable items.
- **Approval chain:** intel does not execute changes; it sends findings to **mother**. Mother applies decision matrix (model upgrade → update openclaw.json; security advisory → architect + notifier; package update → spawn father; technique update → backlog LOW; routine digest → notifier).
- **Self-update boundary:** Model switch and SOUL.md changes require mother approval. Security patches: auto-forward to architect and notify user. No auto-update to production without qa-tester confirm when applicable.

## 10. INCIDENT_ESCALATION_PROTOCOL

Single source of truth for the 3-layer self-healing escalation system.

### 10.1 ESCALATION_CHAIN

```
Agent (self-resolve, 1 retry)
  → Write Incident Record to knowledge-base/incidents/
  → Send Incident Report to Mother (sessions_send agent:mother:main)
    → Mother: search KB lessons-learned → apply known fix OR attempt new fix
      → If resolved: update incident Status: resolved
      → If unresolved: escalate to The Architect via DEVELOPMENT_BACKLOG.md
        → Mother notifies human via Telegram ("Recorded in backlog")
        → Human commands The Architect (AI Code Assistant) to clear backlog
          → The Architect fixes code/config
            → Update incident Status: resolved | mark lessons-learned
```

### 10.1b SERVER_CRASH_AFTER_REBOOT (manual reboot)

หลังรีบูทเซิร์ฟเวอร์ด้วยมือ ให้รันบน host ที่ reboot เพื่อหาสาเหตุ (OOM, kernel panic, power/watchdog):

- `bash scripts/ops/post-reboot-diagnosis.sh` — แสดง log boot ก่อนหน้า + สรุปสาเหตุที่เป็นไปได้
- `journalctl -b -1 -n 500` — ดู log เต็มของ boot ก่อนหน้า
- `journalctl -b -1 -p err` — เฉพาะระดับ error ขึ้นไป

สคริปลงทะเบียนใน SCRIPTS_REGISTRY.md (§ Ops Scripts).

**สาเหตุที่พบบ่อย (จาก log):** ไม่ใช่ OOM/panic — **gateway port conflict + systemd restart loop**: process เดิม (เช่น pid ค้าง) ยึด port 18789 อยู่แล้ว แต่ systemd พยายาม start gateway ใหม่ → bind ไม่ได้ → exit 1 → systemd restart วนซ้ำ (restart counter พุ่ง). แก้: รัน `scripts/ops/gateway-recovery.sh` เพื่อ free port แล้ว start ใหม่. **ป้องกัน:** (1) Unit ที่ generate จาก `openclaw gateway install` มี **ExecStartPre** ที่ free port 18789 ก่อน start แล้ว (ใน `src/daemon/systemd-unit.ts`); ถ้าใช้ unit เก่า ให้ reinstall: `openclaw gateway install --force`. (2) สคริปต์ `scripts/ops/free-gateway-port.sh` ใช้รันเองหรือใส่ใน drop-in ได้. (3) ใช้ gateway runtime เดียวต่อ host (systemd **หรือ** Docker ไม่รันพร้อมกัน).

### 10.1c WHY_AGENTS_DID_NOT_RECOVER (และแก้อย่างไร)

- **การออกแบบที่ถูก:** ใช้ **systemd timer** (ไม่ขึ้นกับ gateway) รัน health-check ทุก 15 นาที; ถ้า CRITICAL ให้ **รัน gateway-recovery.sh อัตโนมัติ**. สคริปต์ `health-check-and-recover.sh` ทำหน้าที่นี้; service ของ timer ต้องชี้ไปที่ script นี้ และ **ต้อง enable timer** บน host ที่รัน gateway จึงจะมีการกู้อัตโนมัติ.
- **ตรวจสอบ:** `systemctl --user list-timers` ควรเห็น `openclaw-health.timer`; ถ้าไม่มี ให้ copy `scripts/systemd-user/openclaw-health.*` ไป `~/.config/systemd/user/` แล้ว `systemctl --user enable --now openclaw-health.timer`.

### 10.1d SERVER_OS_ONLY_MODE (ลดโทเคนเรื่อง server)

เมื่อ **openclaw-health.timer เปิดอยู่** งาน server (health check, กู้ gateway, แจ้ง Telegram เมื่อ CRITICAL) ทำโดยสคริปต์ระดับ OS ทั้งหมด. เพื่อลดการใช้โทเคนให้มากที่สุด:

1. เปิด timer ตาม §10.1c (ต้องทำอยู่แล้วถ้าต้องการ auto-recovery).
2. งาน server ไม่ใช้โทเคนจาก agent อีก. ดู §6b.

### 10.2 INCIDENT_RECORD_FORMAT

```markdown
# Incident: YYYY-MM-DD-HH-<random-3-char>

- **Agent:** <agent-id>
- **Time:** <ISO8601>
- **Valid Until:** <ISO8601 or "permanent"> (For tracking temporal validity of fixes/lessons)
- **Error:** <exact error message>
- **Attempted:** <what was tried, retry count>
- **Status:** unresolved | resolved | pending-architect
- **Escalated to:** mother | architect
- **Resolution:** <what fixed it>
```

**Location:** `~/.openclaw/knowledge-base/incidents/YYYY-MM-DD-HH-<id>.md`

### 10.3 HUMAN_ESCALATION_FORMAT (via Telegram)

```
🚨 [Incident ID] ต้องการการอนุมัติ
❌ ปัญหา: [1-line summary]
🤖 รายงานโดย: [agent] เมื่อ [time]
🔄 ลองแล้ว: [N ครั้ง — ล้มเหลว]
💡 ตัวเลือก:
  A. [action + expected outcome]
  B. [alternative safe option]
⏱ รอ 10 นาที — ถ้าไม่ตอบจะ mark status=pending-human
```

### 10.4 AGENT_ESCALATION_ROLES

| Agent       | บทบาทในระบบ Escalation                                                           |
| ----------- | -------------------------------------------------------------------------------- |
| `sunday`    | จุดรับปัญหาจากเจ้านาย → self-resolve → escalate Mother → escalate Architect      |
| `mother`    | Active Supervisor → รับ incident → ค้น KB → fix → escalate Architect ถ้าทำไม่ได้ |
| `father`    | Write incident → return error+ID ไปยัง calling agent                             |
| `dev`       | Write incident → return error+ID ไปยัง calling agent                             |
| `architect` | Lead Developer → รับเรื่องจาก Backlog → แก้ไขโค้ด/config → ปิด Issue             |

### 10.5 KNOWLEDGE_BASE_PATHS

| Path                                                | Purpose                                                                |
| --------------------------------------------------- | ---------------------------------------------------------------------- |
| `~/.openclaw/knowledge-base/DEVELOPMENT_BACKLOG.md` | Inbox for The Architect (AI Code Assistant) to fix unresolvable issues |
| `~/.openclaw/knowledge-base/incidents/`             | Active incident logs (shared)                                          |
| `~/.openclaw/knowledge-base/lessons-learned/`       | Resolved cases + fixes for future lookup                               |
| `~/.openclaw/knowledge-base/server/`                | Father's resolved server issues                                        |
| `~/.openclaw/knowledge-base/daily-summaries/`       | Daily agent activity summaries                                         |

---

## 11. CRITICAL_CONSTRAINTS_REMINDER (Bookend)

<!-- Bookend — ซ้ำกฎที่สำคัญที่สุดจาก Section 0 เพื่อป้องกัน Lost-in-Middle Effect -->
<!-- AI อ่านจุดเริ่มต้นและจุดสิ้นสุดของเอกสารดีที่สุด — ตรงกลางมีโอกาสถูกลืม ~30% -->
<!-- See also: .antigravityrules (RULE_0, RULE_20, BOOKEND) -->

- **execution_verification_checklist:**
  1. **model_strings:** "Prefix with `openrouter/` ONLY (e.g. `openrouter/anthropic/...`). Bare `anthropic/` fails."
  2. **inter_agent_config:** "Ensure `tools.agentToAgent.enabled=true` AND `tools.sessions.visibility=all` exist in `openclaw.json`."
  3. **lifecycle_awareness:** "Specialists (`dev`, `father`) are non-persistent. Always use `sessions_spawn` + `agentId`. `sessions_list` missing them is NORMAL."
  4. **sandbox_boundary:** "All agents use `sandbox.mode: off`. Docker container is the true isolation boundary."
  5. **priority_ranking:** `openclaw.json` (live) > `ANTIGRAVITY.md` (design) > `memory/` (history) > pre-trained (NEVER use).
  6. **hallucination_gate:** "If data missing in sources → reply 'ไม่พบข้อมูลใน [files checked]'. NEVER guess or assume."

---
