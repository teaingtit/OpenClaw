# HEARTBEAT.md — SOT Keeper

- **Schedule:** Every 6h (`heartbeat.every: "6h"` in openclaw.json).
- **Script-first (token reduction):**
  1. Exec `git-preflight.sh --watch-list openclaw.json,ANTIGRAVITY.md,DetailHardware.md` (or repo equivalent).
  2. If `watch_triggered` is empty and index/overview are in sync → no LLM; optional one-line "sync OK" to mother.
  3. If changes detected or index/overview outdated → use LLM to update SYSTEM_INDEX.md and OVERVIEW.th.md; request commit via git-ops; report to mother.
