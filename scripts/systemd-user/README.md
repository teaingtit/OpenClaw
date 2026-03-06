# Systemd user units (optional)

Copy or symlink these into `~/.config/systemd/user/` then:

```bash
systemctl --user daemon-reload
systemctl --user enable --now openclaw-health.timer
```

The service runs `scripts/ops/health-check-fix-or-escalate.sh`: every 15 minutes it runs health-check → if not OK runs gateway-recovery.sh → checks again. **If fixed: exit silent.** If still not OK: writes `~/.openclaw/health-escalation-pending.json` (no Telegram). Agent reads the file, tries to fix; **Telegram only when agent fixes or agent cannot fix.** See `docs/HEALTH_ESCALATION.md`, ANTIGRAVITY §6b.
