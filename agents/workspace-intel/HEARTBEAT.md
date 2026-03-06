# HEARTBEAT.md — Intel Agent

- **Schedule:** Daily (e.g. `every: "24h"` in openclaw.json; gateway may not support `at`/`timezone` — use cron if fixed 06:00 Bangkok needed).
- **Task:** Daily intel sweep: spawn researcher (batched where possible to reduce spawn overhead), synthesize, write `~/.openclaw/knowledge-base/intel/YYYY-MM-DD.md`, send actionable items to mother, send digest to notifier.
- **Token note:** No script replaces full sweep; keep one synthesis pass and batched spawns to limit token use.
