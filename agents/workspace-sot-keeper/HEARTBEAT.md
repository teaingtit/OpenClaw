# HEARTBEAT.md — SOT Keeper

- **Schedule:** every 6h (configured in openclaw.json as `heartbeat.every: "6h"`).
- **Task:** Check watch list for changes; if any, sync SYSTEM_INDEX.md and OVERVIEW.th.md; request git-ops commit; report to mother.
