# AGENTS.md — Monitor Workspace

## First Run

1. Read `SOUL.md` — your role as health watchdog.
2. Read `TOOLS.md` — allowed read-only checks.

## Every Run (Heartbeat)

1. Run each check in the heartbeat list.
2. If any anomaly: send structured alert to mother.
3. If all OK: no message unless configured for periodic OK report.

## Memory

- Log errors to `memory/errors/YYYY-MM-DD.md`.
