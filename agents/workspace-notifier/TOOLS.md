# TOOLS.md — Notifier Agent

## Tool Access Policy

- **Allowed tools:** `exec`, `sessions_send`, `session_status`.
- **Exec scope:** Only the notification script: e.g. `bash /home/teaingtit/projects/openclaw/scripts/tg-notify.sh "<message>"`. No other shell commands.

This MUST match `tools.allow` in openclaw.json for the `notifier` agent.

## Forbidden

- read/write of config or credentials
- Any exec other than the tg-notify (or equivalent) script
