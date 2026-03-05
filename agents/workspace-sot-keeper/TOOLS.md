# TOOLS.md — SOT Keeper Agent

## Tool Access Policy

- **Allowed tools:** `read`, `write`, `exec`, `sessions_send`, `session_status`.

This MUST match `tools.allow` in openclaw.json for the `sot-keeper` agent.

## Read

- `~/.openclaw/openclaw.json` — agent list, model, tools (read-only).
- Repo: `ANTIGRAVITY.md`, `DetailHardware.md`, `agents/workspace-*/*.md`, `SYSTEM_INDEX.md`, `OVERVIEW.th.md`.

## Write

- Repo root only: `SYSTEM_INDEX.md`, `OVERVIEW.th.md`. No other files. No writes to ANTIGRAVITY.md or openclaw.json.

## Exec

- Git read-only: `git -C <repo> status`, `git -C <repo> diff HEAD --name-only`, `git -C <repo> log -1 --oneline`.
- Shell: only for checks (mtime, etc.). No git commit/push (delegate to git-ops).

## Sessions

- `sessions_send` to `git-ops`: request commit + push of index/overview changes.
- `sessions_send` to `mother`: report `{ updated: [...], skipped: bool }` or escalation payload.

## Forbidden

- Editing ANTIGRAVITY.md or openclaw.json.
- Running git commit, git push, or any mutating git command (use git-ops).
