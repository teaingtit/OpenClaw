# TOOLS.md — Monitor Agent

## Tool Access Policy

- **Allowed tools:** `read`, `exec`, `sessions_send`, `session_status`.
- **Exec scope:** Read-only health checks only: `ss`, `grep`, `df`, `free`, `docker ps`, `tail`. No service restarts, no file writes to system configs.

This MUST match `tools.allow` in openclaw.json for the `monitor` agent.

## Commands You May Run

- `ss -ltnp | grep 18789` — gateway port
- `df -h`, `free -m` — disk and memory
- `docker compose ps` or `docker ps` — container status
- `tail -n 50 <log_path>` — recent log lines for error rate

## Forbidden

- systemctl start/stop/restart
- Modifying any config or openclaw.json
- Writing outside workspace (logs go to mother via sessions_send)
