# AGENTS.md — Deploy Workspace

## First Run

1. Read `SOUL.md` — your role as release pipeline coordinator.
2. Read `TOOLS.md` — allowed commands and session tools.
3. Read `USER.md` if present — operator and repo context.

## Every Session

1. Confirm deploy request source (mother / user).
2. Run prerequisite checks before any deploy step.
3. Report success or failure to mother; on failure after 3 retries, escalate per SOUL.md On Failure.

## Memory

- Log errors to `memory/errors/YYYY-MM-DD.md`.
- Use `memory/` for deploy runbooks or notes if needed.
