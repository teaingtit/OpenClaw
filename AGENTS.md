# Repository Guidelines

- Repo: https://github.com/openclaw/openclaw
- In chat replies, file references must be repo-root relative only (example: `extensions/bluebubbles/src/channel.ts:80`); never absolute paths or `~/...`.
- GitHub issues/comments/PR comments: use literal multiline strings or `-F - <<'EOF'` (or $'...') for real newlines; never embed "\\n".
- GitHub comment footgun: never use `gh issue/pr comment -b "..."` when body contains backticks or shell chars. Always use single-quoted heredoc (`-F - <<'EOF'`) so no command substitution/escaping corruption.
- GitHub linking footgun: don’t wrap issue/PR refs like `#24643` in backticks when you want auto-linking. Use plain `#24643` (optionally add full URL).
- PR landing comments: always make commit SHAs clickable with full commit links (both landed SHA + source SHA when present).
- PR review conversations: if a bot leaves review conversations on your PR, address them and resolve those conversations yourself once fixed. Leave a conversation unresolved only when reviewer or maintainer judgment is still needed; do not leave bot-conversation cleanup to maintainers.
- GitHub searching footgun: don't limit yourself to the first 500 issues or PRs when wanting to search all. Unless you're supposed to look at the most recent, keep going until you've reached the last page in the search
- Security advisory analysis: before triage/severity decisions, read `SECURITY.md` to align with OpenClaw's trust model and design boundaries.

## Auto-close labels (issues and PRs)

- If an issue/PR matches one of the reasons below, apply the label and let `.github/workflows/auto-response.yml` handle comment/close/lock.
- Do not manually close + manually comment for these reasons.
- Why: keeps wording consistent, preserves automation behavior (`state_reason`, locking), and keeps triage/reporting searchable by label.
- `r:*` labels can be used on both issues and PRs.

- `r: skill`: close with guidance to publish skills on Clawhub.
- `r: support`: close with redirect to Discord support + stuck FAQ.
- `r: no-ci-pr`: close test-fix-only PRs for failing `main` CI and post the standard explanation.
- `r: too-many-prs`: close when author exceeds active PR limit.
- `r: testflight`: close requests asking for TestFlight access/builds. OpenClaw does not provide TestFlight distribution yet, so use the standard response (“Not available, build from source.”) instead of ad-hoc replies.
- `r: third-party-extension`: close with guidance to ship as third-party plugin.
- `r: moltbook`: close + lock as off-topic (not affiliated).
- `r: spam`: close + lock as spam (`lock_reason: spam`).
- `invalid`: close invalid items (issues are closed as `not_planned`; PRs are closed).
- `dirty`: close PRs with too many unrelated/unexpected changes (PR-only label).

## PR truthfulness and bug-fix validation

- Never merge a bug-fix PR based only on issue text, PR text, or AI rationale.
- Before `/landpr`, run `/reviewpr` and require explicit evidence for bug-fix claims.
- Minimum merge gate for bug-fix PRs:
  1. symptom evidence (repro/log/failing test),
  2. verified root cause in code with file/line,
  3. fix touches the implicated code path,
  4. regression test (fail before/pass after) when feasible; if not feasible, include manual verification proof and why no test was added.
- If claim is unsubstantiated or likely hallucinated/BS: do not merge. Request evidence/changes, or close with `invalid` when appropriate.
- If linked issue appears wrong/outdated, correct triage first; do not merge speculative fixes.

## Project Structure & Module Organization

> โครงสร้างของโปรเจกต์และการจัดระเบียบโมดูล

- **source_code:** "`src/` (CLI wiring in `src/cli`, commands in `src/commands`, web provider in `src/provider-web.ts`, infra in `src/infra`, media pipeline in `src/media`)."
- **tests:** "Colocated `*.test.ts`."
- **docs:** "`docs/` (images, queue, Pi config). Built output lives in `dist/`."
- **plugins_extensions_location:** "Live under `extensions/*` (workspace packages)."
- **plugins_dependency_management:** "Keep plugin-only deps in the extension `package.json`; do NOT add them to the root `package.json` unless core uses them."
- **plugins_installation_runtime:** "Install runs `npm install --omit=dev` in plugin dir; runtime deps MUST live in `dependencies`."
- **plugins_workspace_rule:** "AVOID `workspace:*` in `dependencies` (npm install breaks); put `openclaw` in `devDependencies` or `peerDependencies` instead (runtime resolves `openclaw/plugin-sdk` via jiti alias)."
- **installers_served_from:** "`https://openclaw.ai/*`: live in the sibling repo `../openclaw.ai` (`public/install.sh`, `public/install-cli.sh`, `public/install.ps1`)."
- **messaging_channels_refactoring:** "ALWAYS consider ALL built-in + extension channels when refactoring shared logic (routing, allowlists, pairing, command gating, onboarding, docs)."
  - **core_channel_docs:** "`docs/channels/`"
  - **core_channel_code:** "`src/telegram`, `src/discord`, `src/slack`, `src/signal`, `src/imessage`, `src/web` (WhatsApp web), `src/channels`, `src/routing`"
  - **extensions_channel_plugins:** "`extensions/*` (e.g. `extensions/msteams`, `extensions/matrix`, `extensions/zalo`, `extensions/zalouser`, `extensions/voice-call`)"
- **labeling_requirements:** "When adding channels/extensions/apps/docs, update `.github/labeler.yml` and create matching GitHub labels (use existing channel/extension label colors)."

## Docs Linking (Mintlify)

- Docs are hosted on Mintlify (docs.openclaw.ai).
- Internal doc links in `docs/**/*.md`: root-relative, no `.md`/`.mdx` (example: `[Config](/configuration)`).
- When working with documentation, read the mintlify skill.
- For docs, UI copy, and picker lists, order services/providers alphabetically unless the section is explicitly describing runtime behavior (for example auto-detection or execution order).
- Section cross-references: use anchors on root-relative paths (example: `[Hooks](/configuration#hooks)`).
- Doc headings and anchors: avoid em dashes and apostrophes in headings because they break Mintlify anchor links.
- When Peter asks for links, reply with full `https://docs.openclaw.ai/...` URLs (not root-relative).
- When you touch docs, end the reply with the `https://docs.openclaw.ai/...` URLs you referenced.
- README (GitHub): keep absolute docs URLs (`https://docs.openclaw.ai/...`) so links work on GitHub.
- Docs content must be generic: no personal device names/hostnames/paths; use placeholders like `user@gateway-host` and “gateway host”.

## Docs i18n (zh-CN)

> เอกสารแปลภาษาจีน และ Pipeline ที่เกี่ยวข้อง

- **edit_policy:** "`docs/zh-CN/**` is generated; do NOT edit unless the user explicitly asks."
- **translation_pipeline:** "Update English docs → adjust glossary (`docs/.i18n/glossary.zh-CN.json`) → run `scripts/docs-i18n` → apply targeted fixes only if instructed."
- **translation_memory:** "`docs/.i18n/zh-CN.tm.jsonl` (generated)."
- **reference_doc:** "See `docs/.i18n/README.md`."
- **pipeline_performance_issue:** "The pipeline can be slow/inefficient; if it’s dragging, ping @jospalmbier on Discord instead of hacking around it."

## exe.dev VM ops (general)

> คำสั่งพื้นฐานสำหรับการดูแลระบบ VM

- **access_path:** "Stable path is `ssh exe.dev` then `ssh vm-name` (assume SSH key already set)."
- **ssh_flaky_fallback:** "Use exe.dev web terminal or Shelley (web agent); keep a tmux session for long ops."
- **global_update:** "`sudo npm i -g openclaw@latest` (global install needs root on `/usr/lib/node_modules`)."
- **gateway_config:** "Use `openclaw config set ...`; ensure `gateway.mode=local` is set."
- **discord_auth:** "Store raw token only (NO `DISCORD_BOT_TOKEN=` prefix)."
- **restart_gateway:** "Stop old gateway and run: `pkill -9 -f openclaw-gateway || true; nohup openclaw gateway run --bind loopback --port 18789 --force > /tmp/openclaw-gateway.log 2>&1 &`"
- **verify_status:** "`openclaw channels status --probe`, `ss -ltnp | rg 18789`, `tail -n 120 /tmp/openclaw-gateway.log`."

## Build, Test, and Development Commands

> คำสั่งสำหรับการ Build, Test และ Development

- **runtime_baseline:** "Node **22+** (keep Node + Bun paths working)."
- **install_dependencies:** "`pnpm install`"
- **missing_deps_healing:** "If deps are missing (e.g. `node_modules` missing, `vitest not found`), run the repo’s package-manager install command, then rerun the exact requested command once. Apply to all commands. If retry fails, report actionable error."
- **pre_commit_hooks:** "`prek install` (runs same checks as CI)"
- **bun_support:** "`bun install` is supported (keep `pnpm-lock.yaml` + Bun patching in sync when touching deps/patches)."
- **ts_execution_preference:** "PREFER Bun for TypeScript execution (scripts, dev, tests): `bun <file.ts>` / `bunx <tool>`."
- **run_cli_dev:** "`pnpm openclaw ...` (bun) or `pnpm dev`."
- **node_production_support:** "Node remains supported for running built output (`dist/*`) and production installs."
- **mac_packaging_dev:** "`scripts/package-mac-app.sh` defaults to current arch. Release checklist: `docs/platforms/m- Language: TypeScript (ESM). Prefer strict typing; avoid `any`.
- Formatting/linting via Oxlint and Oxfmt; run `pnpm check` before commits.
- Never add `@ts-nocheck` and do not disable `no-explicit-any`; fix root causes and update Oxlint/Oxfmt config only when required.
- Dynamic import guardrail: do not mix `await import("x")` and static `import ... from "x"` for the same module in production code paths. If you need lazy loading, create a dedicated `*.runtime.ts` boundary (that re-exports from `x`) and dynamically import that boundary from lazy callers only.
- Dynamic import verification: after refactors that touch lazy-loading/module boundaries, run `pnpm build` and check for `[INEFFECTIVE_DYNAMIC_IMPORT]` warnings before submitting.
- Never share class behavior via prototype mutation (`applyPrototypeMixins`, `Object.defineProperty` on `.prototype`, or exporting `Class.prototype` for merges). Use explicit inheritance/composition (`A extends B extends C`) or helper composition so TypeScript can typecheck.
- If this pattern is needed, stop and get explicit approval before shipping; default behavior is to split/refactor into an explicit class hierarchy and keep members strongly typed.
- In tests, prefer per-instance stubs over prototype mutation (`SomeClass.prototype.method = ...`) unless a test explicitly documents why prototype-level patching is required.
- Add brief code comments for tricky or non-obvious logic.
- Keep files concise; extract helpers instead of “V2” copies. Use existing patterns for CLI options and dependency injection via `createDefaultDeps`.
- Aim to keep files under ~700 LOC; guideline only (not a hard guardrail). Split/refactor when it improves clarity or testability.
- Naming: use **OpenClaw** for product/app/docs headings; use `openclaw` for CLI command, package/binary, paths, and config keys.
- Written English: use American spelling and grammar in code, comments, docs, and UI strings (e.g. "color" not "colour", "behavior" not "behaviour", "analyze" not "analyse").s`."
- **loc_guideline:** "Aim to keep files under ~700 LOC; guideline only (not a hard guardrail). Split/refactor when it improves clarity or testability."
- **naming_conventions:** "Use **OpenClaw** for product/app/docs headings; use `openclaw` for CLI command, package/binary, paths, and config keys."
>>>>>>> a99b73aba07 (docs: add ANTIGRAVITY, DetailHardware, agent design guide; update AGENTS.md)

## Release Channels (Naming)

> กฎการตั้งชื่อ Release Channels

- **channel_stable:** "Tagged releases only (e.g. `vYYYY.M.D`), npm dist-tag `latest`."
- **channel_beta:** "Prerelease tags `vYYYY.M.D-beta.N`, npm dist-tag `beta` (may ship without macOS app)."
- **beta_naming_rules:** "PREFER `-beta.N`; do NOT mint new `-1/-2` betas. Legacy `vYYYY.M.D-<patch>` and `vYYYY.M.D.beta.N` remain recognized."
- **channel_dev:** "Moving head on `main` (no tag; git checkout main)."

## Testing Guidelines

- Framework: Vitest with V8 coverage thresholds (70% lines/branches/functions/statements).
- Naming: match source names with `*.test.ts`; e2e in `*.e2e.test.ts`.
- Run `pnpm test` (or `pnpm test:coverage`) before pushing when you touch logic.
- Do not set test workers above 16; tried already.
- If local Vitest runs cause memory pressure (common on non-Mac-Studio hosts), use `OPENCLAW_TEST_PROFILE=low OPENCLAW_TEST_SERIAL_GATEWAY=1 pnpm test` for land/gate runs.
- Live tests (real keys): `CLAWDBOT_LIVE_TEST=1 pnpm test:live` (OpenClaw-only) or `LIVE=1 pnpm test:live` (includes provider live tests). Docker: `pnpm test:docker:live-models`, `pnpm test:docker:live-gateway`. Onboarding Docker E2E: `pnpm test:docker:onboard`.
- Full kit + what’s covered: `docs/testing.md`.
- Changelog: user-facing changes only; no internal/meta notes (version alignment, appcast reminders, release process).
- Changelog placement: in the active version block, append new entries to the end of the target section (`### Changes` or `### Fixes`); do not insert new entries at the top of a section.
- Changelog attribution: use at most one contributor mention per line; prefer `Thanks @author` and do not also add `by @author` on the same entry.
- Pure test additions/fixes generally do **not** need a changelog entry unless they alter user-facing behavior or the user asks for one.
- Mobile: before using a simulator, check for connected real devices (iOS + Android) and prefer them when available.

## Commit & Pull Request Guidelines

> กฎการ Commit โค้ดและการทำ Pull Request

- `/landpr` lives in the global Codex prompts (`~/.codex/prompts/landpr.md`); when landing or merging any PR, always follow that `/landpr` process.
- Create commits with `scripts/committer "<msg>" <file...>`; avoid manual `git add`/`git commit` so staging stays scoped.
- Follow concise, action-oriented commit messages (e.g., `CLI: add verbose flag to send`).
- Group related changes; avoid bundling unrelated refactors.
- PR submission template (canonical): `.github/pull_request_template.md`
- Issue submission templates (canonical): `.github/ISSUE_TEMPLATE/`
- **maintainer_workflow:** "If you want the repo's end-to-end maintainer workflow, see `.agents/skills/PR_WORKFLOW.md`. Default to PR_WORKFLOW if no specific workflow is requested."

## Shorthand Commands & Git Notes

> คำสั่งย่อและข้อควรระวังสำหรับ Git

- **sync_workflow:** "`sync`: if working tree is dirty, commit all changes (pick a sensible Conventional Commit message), then `git pull --rebase`; if rebase conflicts and cannot resolve, stop; otherwise `git push`."
- **branch_deletion_fallback:** "If `git branch -d/-D <branch>` is policy-blocked, delete the local ref directly: `git update-ref -d refs/heads/<branch>`."
- **bulk_pr_safety:** "If a close action would affect more than 5 PRs, FIRST ask for explicit user confirmation with the exact PR count and target scope/query."

## GitHub Search (`gh`)

> การใช้คำสั่ง gh เพื่อค้นหาข้อมูลบน Repository

- **search_prerequisite:** "Prefer targeted keyword search before proposing new work or duplicating fixes."
- **search_args:** "Use `--repo openclaw/openclaw` + `--match title,body` first; add `--match comments` when triaging follow-up threads."
- **pr_search_example:** "`gh search prs --repo openclaw/openclaw --match title,body --limit 50 -- 'auto-update'`"
- **issue_search_example:** "`gh search issues --repo openclaw/openclaw --match title,body --limit 50 -- 'auto-update'`"
- **structured_output_example:** "`gh search issues --repo openclaw/openclaw --match title,body --limit 50 --json number,title,state,url,updatedAt -- 'auto update' --jq '.[] | \"\\(.number) | \\(.state) | \\(.title) | \\(.url)\"'`"

## Security & Configuration Tips

> ทิปด้านความปลอดภัยและคอนฟิก

- **web_provider_creds:** "Stored at `~/.openclaw/credentials/`; rerun `openclaw login` if logged out."
- **sessions_location:** "Live under `~/.openclaw/sessions/` by default; the base directory is NOT configurable."
- **env_vars_location:** "See `~/.profile`."
- **privacy_guardrail:** "NEVER commit or publish real phone numbers, videos, or live configuration values. Use obviously fake placeholders in docs, tests, and examples."
- **release_flow_reading:** "ALWAYS read `docs/reference/RELEASING.md` and `docs/platforms/mac/release.md` before any release work; do NOT ask routine questions once those docs answer them."

## GHSA (Repo Advisory) Patch/Publish

> การจัดการและเผยแพร่ Security Advisories

- **prerequisite:** "Before reviewing security advisories, read `SECURITY.md`."
- **fetch_command:** "`gh api /repos/openclaw/openclaw/security-advisories/<GHSA>`"
- **latest_npm:** "`npm view openclaw version --userconfig '$(mktemp)'`"
- **private_fork_prs:** "Private fork PRs MUST be closed before publishing."
- **description_footgun:** "Write Markdown via heredoc to `/tmp/ghsa.desc.md` (NO `'\\n'` strings)."
- **patch_json_build:** "`jq -n --rawfile desc /tmp/ghsa.desc.md '{summary,severity,description:$desc,vulnerabilities:[...]}' > /tmp/ghsa.patch.json`"
- **ghsa_api_footgun:** "CANNOT set `severity` and `cvss_vector_string` in the same PATCH; do separate calls."
- **patch_publish:** "`gh api -X PATCH /repos/openclaw/openclaw/security-advisories/<GHSA> --input /tmp/ghsa.patch.json` (publish = include `\"state\":\"published\"`; no `/publish` endpoint)."
- **publish_failure_reasons:** "If publish fails (HTTP 422): missing `severity`/`description`/`vulnerabilities[]`, or private fork has open PRs."
- **verify_status:** "Re-fetch; ensure `state=published`, `published_at` set; `jq -r .description | rg '\\\\n'` returns nothing."

## Troubleshooting

> การแก้ไขปัญหาเบื้องต้น

- **legacy_issues:** "Rebrand/migration issues or legacy config/service warnings: run `openclaw doctor` (see `docs/gateway/doctor.md`)."

## Agent-Specific Notes

> ข้อมูลเฉพาะและหมายเหตุสำหรับ Agent

- **vocabulary:** "'makeup' = 'mac app'."
- **no_node_modules_edit:** "NEVER edit `node_modules` (global/Homebrew/npm/git installs too). Updates overwrite. Skill notes go in `tools.md` or `AGENTS.md`."
- **symlink_requirement:** "When adding a new `AGENTS.md` anywhere in the repo, ALSO add a `CLAUDE.md` symlink pointing to it (example: `ln -s AGENTS.md CLAUDE.md`)."
- **signal_fly_update:** "Signal: 'update fly' => `fly ssh console -a flawd-bot -C \"bash -lc 'cd /data/clawd/openclaw && git pull --rebase origin main'\"` then `fly machines restart e825232f34d058 -a flawd-bot`."
- **bsky_login_payload:** "`login` payload requires string identifier (NOT `username`); see `@atproto/api` docs for differences."
- **pi_docker_config:** "See `docs/pi.md` and `docker/docker-compose.yml`. Config is `~/.openclaw/config.json`."
- **docs_mint_json_sync:** "When writing files to `docs/` that need to be grouped, check `mint.json` first to see existing navigation groups. Add new pages to `mint.json` navigation array if they need to be visible on the site."
- **new_integration_requirements:** "Adding a new external integration/channel requires 3 docs: the integration guide in `docs/channels/`, a note in `docs/index.md` feature grid, and an update to `mint.json`."
- **onboarding_token_auth:** "`CLI` uses `openclaw login --token <t>`, UI handles standard `/login?token=<t>`. Be distinct when giving instructions for CLI vs Web."

## Multi-Agent Safety (OpenClaw -> Agentic Codebases)

> กฎความปลอดภัยสำหรับการเขียนโค้ดที่รันโดย Agent อื่น

- **tools_allow_rule:** "Do NOT remove `tools.allow` checks in routing just to 'make it work'; you MUST pass explicit allowlists."
- **absolute_model_string:** "If an API expects an absolute model string (e.g., `openrouter/anthropic/claude-...`), do NOT substring it down to the provider unless explicitly parsing the tier."
- **sandbox_mode_assumption:** "The default `sandbox.mode` is `\"off\"` in the host (Docker bounds). Do NOT write logic that assumes it is `\"all\"` or relies on arbitrary daemon connections unless running Father/Root tasks."
- **spawning_visibility:** "If you're building a feature that touches agents spawning other agents, ensure `tools.sessions.visibility=\"all\"` logic is preserved."

## Type Safety vs. "Just get it compiling"

> ความเข้มงวดของ Type (Strict Typing)

- **no_unknown_returns:** "If a method returns `unknown` or `any`, type it properly (e.g., using `zod` for validation or an explicit interface)."
- **axios_data_validation:** "Do NOT blindly pass `res.data` from Axios down the chain without an interface overlay (`const data = res.data as ExpectedInterface;`)."
- **event_bus_typing:** "When defining event bus payloads, keep them STRICTLY typed in `src/infra/events.ts` so all handlers know what they are getting."
- **macos_logs:** "Use `./scripts/clawlog.sh` to query unified logs for the OpenClaw subsystem; it supports follow/tail/category filters and expects passwordless sudo for `/usr/bin/log`."
- **shared_guardrails:** "If shared guardrails are available locally, review them; otherwise follow this repo's guidance."
- **swiftui_state_management:** "Prefer the `Observation` framework (`@Observable`, `@Bindable`) over `ObservableObject`/`@StateObject`; don’t introduce new `ObservableObject` unless required for compatibility, and migrate existing usages when touching related code."
- **connection_providers:** "When adding a new connection, update every UI surface and docs (macOS app, web UI, mobile if applicable, onboarding/overview docs) and add matching status + configuration forms so provider lists and settings stay in sync."
- **version_locations:** "`package.json` (CLI), `apps/android/app/build.gradle.kts` (versionName/versionCode), `apps/ios/Sources/Info.plist` + `apps/ios/Tests/Info.plist` (CFBundleShortVersionString/CFBundleVersion), `apps/macos/Sources/OpenClaw/Resources/Info.plist` (CFBundleShortVersionString/CFBundleVersion), `docs/install/updating.md` (pinned npm version), `docs/platforms/mac/release.md` (APP_VERSION/APP_BUILD examples), Peekaboo Xcode projects/Info.plists (MARKETING_VERSION/CURRENT_PROJECT_VERSION)."
- **bump_version_everywhere:** "All version locations above EXCEPT `appcast.xml` (only touch appcast when cutting a new macOS Sparkle release)."
- **restart_apps:** "'restart iOS/Android apps' means rebuild (recompile/install) and relaunch, not just kill/launch."
- **device_checks:** "Before testing, verify connected real devices (iOS/Android) before reaching for simulators/emulators."
- **ios_team_id_lookup:** "`security find-identity -p codesigning -v` → use Apple Development (…) TEAMID. Fallback: `defaults read com.apple.dt.Xcode IDEProvisioningTeamIdentifiers`."
- **a2ui_bundle_hash:** "`src/canvas-host/a2ui/.bundle.hash` is auto-generated; ignore unexpected changes, and only regenerate via `pnpm canvas:a2ui:bundle` (or `scripts/bundle-a2ui.sh`) when needed. Commit the hash as a separate commit."
- **release_signing_notary:** "Managed outside the repo; follow internal release docs."
- **notary_auth_env_vars:** "(`APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_API_KEY_P8`) are expected in your environment (per internal release docs)."
- **multi_agent_stash:** "Do NOT create/apply/drop `git stash` entries unless explicitly requested (this includes `git pull --rebase --autostash`). Assume other agents may be working; keep unrelated WIP untouched and avoid cross-cutting state changes."
- **multi_agent_pull_push:** "When the user says 'push', you may `git pull --rebase` to integrate latest changes (never discard other agents' work). When the user says 'commit', scope to your changes only. When the user says 'commit all', commit everything in grouped chunks."
- **multi_agent_worktree:** "Do NOT create/remove/modify `git worktree` checkouts (or edit `.worktrees/*`) unless explicitly requested."
- **multi_agent_branch:** "Do NOT switch branches / check out a different branch unless explicitly requested."
- **multi_agent_sessions:** "Running multiple agents is OK as long as each agent has its own session."
- **multi_agent_unrecognized:** "When you see unrecognized files, keep going; focus on your changes and commit only those."
- **lint_format_churn:**
  - **auto_resolve:** "If staged+unstaged diffs are formatting-only, auto-resolve without asking."
  - **commit_follow_ups:** "If commit/push already requested, auto-stage and include formatting-only follow-ups in the same commit (or a tiny follow-up commit if needed), no extra confirmation."
  - **semantic_ask_only:** "Only ask when changes are semantic (logic/data/behavior)."
- **lobster_seam:** "Use the shared CLI palette in `src/terminal/palette.ts` (no hardcoded colors); apply palette to onboarding/config prompts and other TTY UI output as needed."
- **multi_agent_reports:** "Focus reports on your edits; avoid guard-rail disclaimers unless truly blocked; when multiple agents touch the same file, continue if safe; end with a brief 'other files present' note only if relevant."
- **bug_investigations:** "Read source code of relevant npm dependencies and all related local code before concluding; aim for high-confidence root cause."
- **code_style_LOC:** "Add brief comments for tricky logic; keep files under ~500 LOC when feasible (split/refactor as needed)."
- **tool_schema_guardrails_1:** "(google-antigravity): avoid `Type.Union` in tool input schemas; no `anyOf`/`oneOf`/`allOf`. Use `stringEnum`/`optionalStringEnum` (Type.Unsafe enum) for string lists, and `Type.Optional(...)` instead of `... | null`. Keep top-level tool schema as `type: 'object'` with `properties`."
- **tool_schema_guardrails_2:** "Avoid raw `format` property names in tool schemas; some validators treat `format` as a reserved keyword and reject the schema."
- **session_file_opening:** "When asked to open a 'session' file, open the Pi session logs under `~/.openclaw/agents/<agentId>/sessions/*.jsonl` (use the `agent=<id>` value in the Runtime line of the system prompt; newest unless a specific ID is given), not the default `sessions.json`. If logs are needed from another machine, SSH via Tailscale and read the same path there."
- **macos_app_rebuild:** "Do NOT rebuild the macOS app over SSH; rebuilds must be run directly on the Mac."
- **messaging_reply_streams:** "NEVER send streaming/partial replies to external messaging surfaces (WhatsApp, Telegram); only final replies should be delivered there. Streaming/tool events may still go to internal UIs/control channel."
- **voice_wake_forwarding:**
  - **command_template:** "Should stay `openclaw-mac agent --message \"${text}\" --thinking low`; `VoiceWakeForwarder` already shell-escapes `${text}`. Don’t add extra quotes."
  - **launchd_path:** "Ensuring the app’s launch agent PATH includes standard system paths plus your pnpm bin (typically `$HOME/Library/pnpm`) so `pnpm`/`openclaw` binaries resolve when invoked via `openclaw-mac`."
- **manual_message_escaping:** "For manual `openclaw message send` messages that include `!`, use the heredoc pattern noted below to avoid the Bash tool’s escaping."
- **release_guardrails:** "Do NOT change version numbers without operator’s explicit consent; ALWAYS ask permission before running any npm publish/release step."
- **beta_release_guardrail:** "When using a beta Git tag (e.g. `vYYYY.M.D-beta.N`), publish npm with a matching beta version suffix (e.g. `YYYY.M.D-beta.N`) rather than a plain version on `--tag beta`; otherwise the plain version name gets consumed/blocked."

## NPM + 1Password (publish/verify)

- Use the 1password skill; all `op` commands must run inside a fresh tmux session.
- Correct 1Password path for npm release auth: `op://Private/Npmjs` (use that item; OTP stays `op://Private/Npmjs/one-time password?attribute=otp`).
- Sign in: `eval "$(op signin --account my.1password.com)"` (app unlocked + integration on).
- OTP: `op read 'op://Private/Npmjs/one-time password?attribute=otp'`.
- Publish: `npm publish --access public --otp="<otp>"` (run from the package dir).
- Verify without local npmrc side effects: `npm view <pkg> version --userconfig "$(mktemp)"`.
- Kill the tmux session after publish.

## Plugin Release Fast Path (no core `openclaw` publish)

> การเผยแพร่ Plugin (Fast Path)

- **release_scope:** "Release only already-on-npm plugins. Source list is in `docs/reference/RELEASING.md` under 'Current npm plugin list'."
- **tmux_requirement:** "Run all CLI `op` calls and `npm publish` inside tmux to avoid hangs/interruption:"
  - **session_creation:** "`tmux new -d -s release-plugins-$(date +%Y%m%d-%H%M%S)`"
  - **op_signin:** "`eval \"$(op signin --account my.1password.com)\"`"
- **onepassword_helpers:**
  - **password_retrieval:** "`op item get Npmjs --format=json | jq -r '.fields[] | select(.id==\"password\").value'`"
  - **otp_retrieval:** "`op read 'op://Private/Npmjs/one-time password?attribute=otp'`"
- **fast_publish_loop:** "Local helper script in `/tmp` is fine; keep repo clean:"
  - **version_diff:** "Compare local plugin `version` to `npm view <name> version`"
  - **publish_condition:** "Only run `npm publish --access public --otp=\"<otp>\"` when versions differ"
  - **skip_condition:** "Skip if package is missing on npm or version already matches."
- **core_protection:** "Keep `openclaw` untouched: NEVER run publish from repo root unless explicitly requested."
- **post_release_checks:**
  - **plugin_check:** "`npm view @openclaw/<name> version --userconfig \"$(mktemp)\"` should match freshly published version."
  - **core_guard:** "`npm view openclaw version --userconfig \"$(mktemp)\"` should stay at previous version unless explicitly requested."

## Changelog Release Notes

> การจัดการไฟล์บันทึกการเปลี่ยนแปลง (Changelog)

- **mac_beta_release:**
  - **git_tagging:** "Tag `vYYYY.M.D-beta.N` from the release commit (example: `v2026.2.15-beta.1`)."
  - **github_prerelease:** "Create prerelease with title `openclaw YYYY.M.D-beta.N`."
  - **notes_source:** "Use release notes from `CHANGELOG.md` version section (`Changes` + `Fixes`, no title duplicate)."
  - **attachments:** "Attach at least `OpenClaw-YYYY.M.D.zip` and `OpenClaw-YYYY.M.D.dSYM.zip`; include `.dmg` if available."
- **changelog_sorting:** "Keep top version entries in `CHANGELOG.md` sorted by impact:"
  - **category_changes:** "`### Changes` first."
  - **category_fixes:** "`### Fixes` deduped and ranked with user-facing fixes first."
- **pre_publish_checks:** "Before tagging/publishing, run:"
  - **release_check_script:** "`node --import tsx scripts/release-check.ts`"
  - **pnpm_release_check:** "`pnpm release:check`"
  - **smoke_tests:** "`pnpm test:install:smoke` or `OPENCLAW_INSTALL_SMOKE_SKIP_NONROOT=1 pnpm test:install:smoke` for non-root smoke path."
