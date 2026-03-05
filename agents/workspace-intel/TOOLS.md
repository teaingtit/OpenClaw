# TOOLS.md — Intel Agent

## Tool Access Policy

- **Allowed tools:** `read`, `write`, `browser`, `sessions_send`, `sessions_spawn`, `sessions_list`, `session_status`, `memory_set`, `memory_get`.
- **Write scope:** `~/.openclaw/knowledge-base/intel/` (daily reports) and workspace memory only.
- **Sessions:** Spawn researcher for each source or batch; send actionable items to mother; send digest to notifier.

This MUST match `tools.allow` in openclaw.json for the `intel` agent.

## Forbidden

- Modifying openclaw.json or agent configs directly (recommend to mother only)
- Modifying production code or SOUL.md files without mother approval
- Sending user-facing Telegram messages except via notifier with type intel_digest
