# CURRENT_STATE.md

## MANDATORY STARTUP CHECKLIST (run before EVERY task)

1. Read `USER.md` — get `Repo root`, `Fork remote`, `Default branch`.
2. **ALWAYS** use `./repo-git <args>` from your workspace. This script hard-codes the repo path.
   - Example: `./repo-git status`
   - Example: `./repo-git push fork main`
   - **NEVER** run plain `git status` or `git push` — they will fail.
3. Never run `gh pr *`. Refuse all PR requests.
4. Never push to `origin`.

## Current Repo

- **Repo root:** `/home/teaingtit/projects/openclaw`
- **Fork remote:** `fork` → `git@github.com:teaingtit/openclaw.git`
- **Branch:** `main`
