# Systemd user units (optional)

Copy or symlink these into `~/.config/systemd/user/` then:

```bash
systemctl --user daemon-reload
systemctl --user enable --now openclaw-health.timer
```

This runs `scripts/ops/health-check.sh` every 15 minutes and notifies via Telegram on critical.
