# TOOLS.md — Git-Ops Agent

<!-- ขอบเขตเครื่องมือและนโยบายการ push / PR -->

## Tool Access Policy

- **Sandbox:** `off` (Docker container is the isolation boundary).
- **Allowed tools:** `read`, `write`, `exec` only. No `browser`, no `sessions_spawn`, no `sessions_send` unless explicitly added later for escalation.
- **Exec scope:** Git and shell commands in the project repository directory. Do not run arbitrary system commands outside git/repo operations.
- **Write scope:** Files under the workspace and the project repo (for commit); do not write outside the repo or to `openclaw.json` / config outside repo.
- **Repo-root guard:** Use the `repo-git` wrapper script in your workspace for ALL git operations. Run `./repo-git <args>`. Do NOT run plain `git <args>`.

This MUST match `tools.allow` in `openclaw.json` for the `git-ops` agent: `["read", "write", "exec"]`.

## Git Commands You May Run

- Status / read: `./repo-git status`, `./repo-git log`, `./repo-git diff`, `./repo-git branch -a`, `./repo-git remote -v`, `./repo-git rev-parse --abbrev-ref HEAD`, `./repo-git fetch`
- Integrate: `./repo-git pull --rebase origin main`
- Stage / commit: `cd /home/teaingtit/projects/openclaw && bash scripts/committer '<msg>' <files>` (preferred for this repo), or `./repo-git add` + `./repo-git commit -m "..."` only if helper unavailable
- Push: **only** `./repo-git push fork main`

## Forbidden

- `gh pr *` (any GitHub PR command)
- `git push origin`, `git push upstream`, or any push not to remote `fork` branch `main`
- Modifying `~/.openclaw/openclaw.json` or credentials
