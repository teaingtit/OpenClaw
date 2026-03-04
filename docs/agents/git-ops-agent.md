# Git-Ops Agent (Fork-Only, No PR)

> Runbook and guardrails for the `git-ops` agent. Use this for setup and verification.

## 1. Review Summary vs Original Plan

The original `implementation_plan.md.resolved` had these gaps, now addressed:

| Original plan                                                   | Issue                                                                  | New guardrail                                                                                     |
| --------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Edit `openclaw.json` directly to add agent and tools            | Config drift; violates project rule (no direct overwrite)              | Register via `openclaw agents add`; set tools via config set or doctor where supported            |
| Include `gh pr list` in TOOLS                                   | User requirement: no PR workflow                                       | PR-related commands are **forbidden**; agent must refuse any PR creation/update/list              |
| Heartbeat every 6h                                              | Git ops are on-demand; auto-run adds risk                              | No heartbeat by default; optional report-only heartbeat later (status/fetch only, no commit/push) |
| Session tools (`sessions_send`, `sessions_list`) in tools.allow | Git-ops does not need to spawn or message other agents for core duties | Omitted from default allowlist; add only if escalation to Mother is required                      |

**Confirmed guardrails:**

- **Fork-only push:** Default and only allowed push target is remote `fork`; branch `main`. Push to `origin` is **forbidden** unless operator explicitly changes policy.
- **No PR workflow:** Do not run `gh pr *` or any Pull Request create/update/list/merge. Refuse such requests with a short explanation.

## 2. Agent Contract (SOUL / TOOLS)

- **Allowed:** `git status`, `git fetch`, `git add`, `git commit`, `git pull --rebase`, `git push fork main` (and safe variants, e.g. `git push fork main` only).
- **Forbidden:** `gh pr *`, push to `origin`, force-push, delete branches, or any PR-related workflow.
- **Preflight:** Before any push, confirm working tree is clean or committed, and remote is `fork` and branch is `main`.
- **Path safety:** Run git with `git -C "<Repo root from USER.md>" ...` so agent does not accidentally execute in its workspace folder.

## 3. Registration and Setup (CLI-Only)

Prefer CLI/config helpers. If your current CLI cannot set nested per-agent `tools.allow`, apply a targeted JSON edit for that key only (never overwrite the whole file).

1. **Add agent (non-interactive):**

   ```bash
   openclaw agents add git-ops --workspace ~/.openclaw/workspace-git-ops --model openrouter/google/gemini-2.0-flash-lite-001 --non-interactive
   ```

   From the project repo root so workspace paths resolve. This creates the agent entry and bootstraps `~/.openclaw/workspace-git-ops/` with default templates.

2. **Overwrite with git-ops workspace files:** Copy from repo `agents/workspace-git-ops/` to `~/.openclaw/workspace-git-ops/` (overwrite SOUL.md, TOOLS.md, AGENTS.md, IDENTITY.md, USER.md, HEARTBEAT.md, CURRENT_STATE.md). Create `memory/` and `memory/errors/` if missing.

   ```bash
   cp -r agents/workspace-git-ops/* ~/.openclaw/workspace-git-ops/
   mkdir -p ~/.openclaw/workspace-git-ops/memory/errors
   ```

   Then set the repo target in `~/.openclaw/workspace-git-ops/USER.md`:
   - `Repo root` = your local OpenClaw checkout path
   - `Fork remote` = `fork`
   - `Default branch` = `main`

3. **Set tool allowlist:** The `agents add` command may not set `tools.allow`. Ensure the `git-ops` entry has `tools: { "allow": ["read", "write", "exec"] }`. If your OpenClaw supports per-agent config set (e.g. gateway or CLI path like `agents.list[N].tools.allow`), use it. Otherwise perform a targeted edit for this key only — never replace the entire config file.

4. **Set identity (optional):**

   ```bash
   openclaw agents set-identity --agent git-ops --name "Git-Ops" --workspace ~/.openclaw/workspace-git-ops
   ```

5. **Restart gateway** so the new agent and tools are loaded.

## 4. Verification and Test Cases

- **Agent visible:** `openclaw agents list` (or Control UI) shows `git-ops`.
- **Read-only:** Ask agent: "Check git status" / "Run git fetch" — should run and report.
- **Repo-root guard:** Ask agent to run `git -C "<Repo root>" rev-parse --show-toplevel` before any git task — path must match `USER.md` repo root.
- **Commit:** Ask agent: "Commit current changes with message 'chore: test git-ops'" — should only proceed if working tree has changes and user intent is clear.
- **Push policy:** Ask agent: "Push to fork main" — should run `git push fork main`. Ask "Open a PR" or "Push to origin" — must **refuse** (no PR, no push to origin).
- **No PR:** Ask "List open PRs" or "Create a PR" — must refuse and state policy (fork-only, no PR).

## 5. ANTIGRAVITY.md Sync

After adding `git-ops`, update ANTIGRAVITY.md:

- In **§5 AGENT_DEFINITIONS**, add a subsection for `git-ops` (id, role, workspace, model, tools_allowed, lifecycle, no heartbeat, push policy).
- In **§7 ACTIVE_ENVIRONMENT_STATE** `active_agents`, append `git-ops`.
