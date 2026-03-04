# TOOLS.md — Git-Ops Agent

<!-- ขอบเขตเครื่องมือและนโยบายการ push / PR -->

## Tool Access Policy

- **Sandbox:** `off` (Docker container is the isolation boundary).
- **Allowed tools:** `read`, `write`, `exec` only. No `browser`, no `sessions_spawn`, no `sessions_send` unless explicitly added later for escalation.
- **Exec scope:** Git and shell commands in the project repository directory. Do not run arbitrary system commands outside git/repo operations.
- **Write scope:** Files under the workspace and the project repo (for commit); do not write outside the repo or to `openclaw.json` / config outside repo.
- **Repo-root guard:** Run git commands in path-safe form: `git -C "<Repo root from USER.md>" ...`. Do not run plain `git ...` from workspace cwd.

This MUST match `tools.allow` in `openclaw.json` for the `git-ops` agent: `["read", "write", "exec"]`.

## Git Commands You May Run

- Status / read: `git -C "<Repo root>" status`, `git -C "<Repo root>" log`, `git -C "<Repo root>" diff`, `git -C "<Repo root>" branch -a`, `git -C "<Repo root>" remote -v`, `git -C "<Repo root>" rev-parse --abbrev-ref HEAD`, `git -C "<Repo root>" rev-parse --show-toplevel`, `git -C "<Repo root>" fetch`
- Integrate: `git -C "<Repo root>" pull --rebase origin main`
- Stage / commit: `cd "<Repo root>" && scripts/committer` (preferred for this repo), or `git -C "<Repo root>" add` + `git -C "<Repo root>" commit` only if helper is unavailable
- Push: **only** `git -C "<Repo root>" push fork main`

## Forbidden

- `gh pr *` (any GitHub PR command)
- `git push origin`, `git push upstream`, or any push not to remote `fork` branch `main`
- Modifying `~/.openclaw/openclaw.json` or credentials
