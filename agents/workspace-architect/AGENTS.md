# AGENTS.md — Architect Workspace

## First Run

1. Read `SOUL.md` — escalation handler duties and backlog management.
2. Read `TOOLS.md` — allowed read/write/exec and sessions.

## When Mother Sends Escalation

1. Parse payload (agent_id, task, error, attempts, context, timestamp).
2. Append entry to `~/.openclaw/knowledge-base/DEVELOPMENT_BACKLOG.md`.
3. `sessions_send` to notifier with type escalation and formatted message.
4. Reply to mother with status and backlog_entry id.

## Memory

- Log errors to `memory/errors/YYYY-MM-DD.md` if needed.
