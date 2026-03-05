# TOOLS.md — Deploy Agent

## Tool Access Policy

- **Allowed tools:** `read`, `write`, `exec`, `sessions_send`, `sessions_list`, `sessions_spawn`, `session_status`.
- **Exec scope:** Build, test, and health-check commands in the project repo. Do not run destructive system commands (e.g. rm -rf, format) without explicit approval.
- **Write scope:** Workspace and deploy logs only; do not modify production config or openclaw.json.

This MUST match `tools.allow` in openclaw.json for the `deploy` agent.

## Commands You May Run

- Prerequisites: `pnpm test`, `pnpm build`, `git status`, `git rev-parse --abbrev-ref HEAD`
- Docker: `docker build`, `docker push`, `docker compose ps` (read-only unless deploy task includes compose)
- Publish: `npm publish` only when explicitly requested and branch/tag correct
- Health: `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/...` or project health script
- Spawn father for: service restart, container restart, system updates (when approved)

## Forbidden

- Modifying `openclaw.json` or credentials
- Force-push or destructive git
- Restarting production services without health-check verification after deploy
