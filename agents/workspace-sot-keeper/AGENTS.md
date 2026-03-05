# AGENTS.md — SOT Keeper Workspace

## First Run

1. Read SOUL.md — your role as Source of Truth Keeper.
2. Read TOOLS.md — allowed tools and write scope.
3. Confirm repo root and paths in USER.md.

## Every Run (Heartbeat 6h)

1. Check watch list for changes (git diff / mtime).
2. If no changes: report skipped to mother and exit.
3. If changes: read sources, update SYSTEM_INDEX.md and/or OVERVIEW.th.md only.
4. Request git-ops to commit and push (sessions_send); do not commit/push yourself.
5. Report updated files to mother.

## Memory

- Log errors to memory/errors/YYYY-MM-DD.md on failure.
