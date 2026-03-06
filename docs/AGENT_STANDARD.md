# OpenClaw Agent Standard

> มาตรฐานเดียวสำหรับการออกแบบและรัน agent ใน OpenClaw — ลดความซับซ้อนและโทเคน โดยใช้ script-first และรูปแบบเดียวกันทุกตัว

## 1. Scope

- ทุก agent ที่ลงทะเบียนใน `openclaw.json` ควรปฏิบัติตามมาตรฐานนี้
- Workspace ใน repo: `agents/workspace-<id>/` ต้องมีไฟล์ครบและเนื้อหาตรงกับข้อกำหนดด้านล่าง

## 2. Mandatory Workspace Files

| File               | Purpose                                                      |
| ------------------ | ------------------------------------------------------------ |
| `SOUL.md`          | Role, rules, step-by-step logic, bookend constraints         |
| `IDENTITY.md`      | Metadata, theme, display name                                |
| `AGENTS.md`        | Protocol, first-run and every-run steps                      |
| `TOOLS.md`         | Tool Access Policy; must match `openclaw.json` `tools.allow` |
| `USER.md`          | User context (if any)                                        |
| `HEARTBEAT.md`     | Schedule and task list; for on-demand agents: "none"         |
| `CURRENT_STATE.md` | Optional; init state for session                             |
| `memory/`          | Directory exists; `memory/errors/` for error log             |

## 3. SOUL.md Requirements

- **Sections:** Use `##` headers only; no wall of text
- **Bookend:** Place critical non-negotiable rules at both **top** (after Role) and **bottom** (e.g. `## Core Constraints (Reminder)`)
- **Language:** Keys and structure in English; Thai in comments only (`#`, `<!-- -->`)
- **Steps:** Use numbered steps `1. 2. 3.` for mandatory sequences; bullets for lists
- **Invocation:** All tool examples in **JSON** form — never CLI style (e.g. `{"agentId": "father", "task": "...", "mode": "run"}` not `sessions_spawn --agent father`)
- **Grounding:** "Use tools to read/verify; do not guess or fabricate"; "If data not in ANTIGRAVITY.md / openclaw.json / memory → reply ไม่พบข้อมูลใน [sources checked]"
- **Failure:** Max 3 retries per step; then stop, write incident, escalate (see ANTIGRAVITY §10.1)

## 4. TOOLS.md ↔ openclaw.json Sync

- `TOOLS.md` must have `## Tool Access Policy` with **Allowed tools** exactly matching `tools.allow` in `openclaw.json` for that agent
- After any change to `openclaw.json` for an agent, update that agent's `TOOLS.md` immediately
- Mismatch causes the agent to hallucinate capabilities (e.g. think it has no `browser` when it does)

## 5. Heartbeat: Script-First (Token Reduction)

For agents with a heartbeat (monitor, mother, father, sunday, sot-keeper, intel):

1. **Step 1:** Run the designated script first (see `SCRIPTS_REGISTRY.md` and `docs/AGENT_SCRIPT_FIRST.md`)
2. **Step 2:** If script output indicates **OK** (e.g. `status == "ok"`, `valid == true`, no anomalies) → send minimal reply **without** invoking LLM reasoning (e.g. one-line "health OK" or skip reply)
3. **Step 3:** If script output indicates **not OK** → use LLM to analyze, decide, and escalate/report as needed

This reduces token use by avoiding LLM runs when the system is healthy.

## 6. Invocation Format (Delegation)

- **sessions_spawn:** Always JSON; always include `agentId` for specialist agents. Example:
  `{"task": "Objective: ...\nContext: ...\nConstraints: ...\nDeliverables: ...", "agentId": "father", "label": "server-health", "mode": "run"}`
- **sessions_send:** JSON with `sessionKey` and `message` (or equivalent). Never assume a non-persistent agent has an existing session — use spawn for dev/father/coder/etc.

## 7. Lifecycle and Sessions

- **Persistent:** mother, sunday — always have a session; use `sessions_send`
- **Non-persistent:** dev, father, coder, qa-tester, architect, … — no session between runs; always use `sessions_spawn` with `agentId`; never fall back to a generic unnamed sub-agent

## 8. References

- Full design guide: `docs/AGENT_DESIGN_GUIDE.md`
- Script-first mapping: `docs/AGENT_SCRIPT_FIRST.md`
- Script registry: `SCRIPTS_REGISTRY.md`
- Validation checklist: `.antigravityrules` RULE_AGENT_VALIDATION_CHECKLIST
- Agent definitions and routing: `ANTIGRAVITY.md` §5, §9
