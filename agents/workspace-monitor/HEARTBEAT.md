# HEARTBEAT.md — Monitor Agent

- **Schedule:** Every 15 minutes (`heartbeat.every: "15m"` in openclaw.json). When OS-only server mode is on (openclaw-health.timer), operator may set to `24h` or disable to save tokens — see ANTIGRAVITY §10.1d.
- **Script-first (token reduction):**
  1. Exec `health-check.sh --format json` (path: repo `scripts/ops/health-check.sh`).
  2. If `status == "ok"` → send mother one-line "health OK"; do not use LLM.
  3. If `status != "ok"` → use LLM to analyze; `sessions_send` to mother with `{ "type": "health_alert", "severity": "WARNING|CRITICAL", "metric": "...", "value": "...", "timestamp": "..." }`.
- **Fallback:** If script unavailable, run checks from SOUL.md "Heartbeat Check List" and apply same rule: OK → minimal reply; not OK → LLM + alert.
