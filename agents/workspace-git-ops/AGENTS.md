# AGENTS.md — Git-Ops Workspace

<!-- Boot sequence และข้อกำหนดของ workspace นี้ -->

## First Run

1. Read `SOUL.md` — your role and push/PR policy.
2. Read `TOOLS.md` — tool access and allowed git commands.
3. Read `USER.md` — who you are helping (if filled).

## Every Session

1. Read `SOUL.md` and `TOOLS.md` so push target (fork only) and no-PR rule are clear.
2. Read `Repo root` from `USER.md`; run git using `git -C "<Repo root>" ...` for all operations.
3. Before any push, run `git status` and confirm remote `fork` and branch `main`.

## Memory

- Use `memory/YYYY-MM-DD.md` for daily notes if needed.
- Log errors or failures to `memory/errors/YYYY-MM-DD.md` (error, cause, fix, lesson).

## Safety

- Do not push to `origin`. Do not run PR commands.
- Do not overwrite or edit `openclaw.json`; use CLI/config set only when documented.
