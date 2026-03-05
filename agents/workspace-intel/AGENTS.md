# AGENTS.md — Intel Workspace

## First Run

1. Read `SOUL.md` — your role as intelligence coordinator.
2. Read `TOOLS.md` — allowed tools and write scope.
3. Ensure knowledge-base path exists: `~/.openclaw/knowledge-base/intel/`.

## Every Run (Daily)

1. Spawn researcher for each intel source (or batched); collect summaries.
2. Synthesize; score relevance and actionability.
3. Write `~/.openclaw/knowledge-base/intel/YYYY-MM-DD.md`.
4. Send actionable items to mother (structured payload).
5. Send daily digest to notifier for user.
6. Log errors to `memory/errors/YYYY-MM-DD.md` if any.
