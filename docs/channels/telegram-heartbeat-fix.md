# Telegram heartbeat delivery and agent unreachable (March 2026)

## Summary

If the agent stopped responding around **March 2, 2026**, likely causes and fixes are below.

## 1. Delivery queue stuck (heartbeat → invalid Telegram target)

**Symptom:** Logs show `Recovery time budget exceeded — 6 entries deferred to next restart` and `Delivery recovery complete: 0 recovered, 0 failed, 0 skipped (max retries)`.

**Cause:** Some delivery queue entries have `"to": "heartbeat"`. Telegram cannot resolve the literal string `"heartbeat"` (or `@heartbeat`) to a numeric chat ID, so the API returns `400: Bad Request: chat not found`. Recovery retries these on every gateway start, hits the 60s budget, and defers them again.

**Fix:**

1. **Move stuck entries to failed** (so recovery stops deferring every restart):

   ```bash
   QUEUE_DIR=~/.openclaw/delivery-queue
   for f in "$QUEUE_DIR"/*.json; do
     [ -f "$f" ] && mv "$f" "$QUEUE_DIR/failed/" 2>/dev/null || true
   done
   ```

   Or move only the heartbeat-related ones; check with:

   ```bash
   grep -l '"to": "heartbeat"' ~/.openclaw/delivery-queue/*.json 2>/dev/null
   ```

2. **Prevent new heartbeat deliveries to invalid target:**  
   In `openclaw.json`, either set `agents.defaults.heartbeat.target` to `"none"` or set each agent’s `heartbeat.to` to a **valid Telegram chat ID** (numeric or known username). Do not use the literal `"heartbeat"` as a delivery destination.

## 2. Gateway unreachable: "device signature invalid"

**Symptom:** `openclaw status` shows Gateway **unreachable** and RPC probe fails with `gateway closed (1008): device signature invalid`.

**Cause:** The client (CLI or Control UI) is connecting with a token/signature that the gateway rejects. Common after a config or token change.

**Fix:**

1. Ensure a single auth token is used:
   - Gateway: `openclaw.json` → `gateway.auth.token`
   - Control UI / CLI: same token (e.g. in browser storage or CLI config)
2. Restart the gateway after changing the token:  
   `systemctl --user restart openclaw-gateway.service`
3. If using Tailscale Serve, ensure the URL and token match what the client uses.

## 3. Telegram group messages dropped

**Symptom:** Bot receives messages in a group but never replies.

**Cause:** Doctor reports: `channels.telegram.groupPolicy is "allowlist"` but `groupAllowFrom` (and `allowFrom`) is **empty** — so all group messages are dropped.

**Fix:**

- **Option A:** Add your Telegram user/chat IDs to the allowlist:
  - `openclaw pairing list telegram` → approve the pairing for the account you use in the group.
  - Or set `channels.telegram.groupAllowFrom` (or `allowFrom`) in `openclaw.json` to the list of allowed sender IDs.
- **Option B (testing):** Set `channels.telegram.groupPolicy` to `"open"` so all group messages are accepted (then tighten with allowlist later).

## 4. Security: credentials directory

**Fix:**  
`chmod 700 ~/.openclaw/credentials`

## Quick checklist

- [ ] Clear or move stuck delivery-queue entries (heartbeat → failed).
- [ ] Fix or disable heartbeat delivery target (no `"heartbeat"` as Telegram `to`).
- [ ] Resolve gateway auth so RPC probe succeeds (token/signature match, restart gateway).
- [ ] Fix Telegram allowlist or groupPolicy so your group/DM is allowed.
- [ ] Apply credentials dir permission fix.

After changes, run:

```bash
openclaw doctor --fix   # apply safe fixes
systemctl --user restart openclaw-gateway.service
openclaw status
openclaw channels status --probe
```
