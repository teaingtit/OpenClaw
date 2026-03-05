# AGENTS.md — Notifier Workspace

## First Run

1. Read `SOUL.md` — your role as Telegram dispatcher.
2. Read `TOOLS.md` — exec limited to tg-notify script.

## Every Request

1. Parse payload (type, title, body, priority).
2. Format message per template.
3. Run tg-notify.sh with formatted message.
4. Confirm to caller via sessions_send.
