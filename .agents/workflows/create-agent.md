---
description: How to create a new OpenClaw agent correctly (learned from audit errors)
---

# Creating a New OpenClaw Agent

// turbo-all

## Pre-Requisites

- Docker gateway must be running
- Access to `~/.openclaw/openclaw.json`
- Know the agent's role, model tier, and tool requirements

## Steps

### 1. Plan the Agent

Define these properties before starting:

- **Agent ID** (lowercase, short, e.g. `father`, `monitor`)
- **Display Name** and **Emoji**
- **Model Tier**: 8.1/8.2 (`openrouter/anthropic/claude-opus-4-6`) for agentic/reasoning, 8.3 (`openrouter/anthropic/claude-sonnet-4-6`) for conversational
- **Tools needed**: `read`, `exec`, `write`, `sessions_list`, `sessions_send`, etc.
- **Heartbeat interval**: e.g. `1h` (omit `activeHours` for 24/7; only add if restricting hours)
- **Channel binding**: direct (telegram) vs no binding (invoked via sessions_spawn only)

### 2. Use CLI to Create Agent (CRITICAL — DO NOT SKIP)

```bash
pnpm openclaw agents add <id>
```

This creates `~/.openclaw/agents/<id>/agent/` with auth files (`auth-profiles.json`, `auth.json`, `models.json`).
**Without this step, the agent CANNOT authenticate to OpenRouter and will fail to spawn.**

### 3. Set Identity via CLI

```bash
pnpm openclaw agents set-identity --agent <id> --name "<Display Name>" --emoji "<emoji>"
```

### 4. Create Workspace Directory

```bash
mkdir -p ~/.openclaw/workspace-<id>/memory/errors
```

### 5. Write Workspace Files

Write ALL 7 files. **Copy from an existing working agent first, then customize.**
Best reference agents: `dev` (for specialist agents) or `sunday` (for conversational agents).

#### SOUL.md

- Identity, communication style, core capabilities
- Rules, error handling & retry logic (max 2 retries)
- Guardrails (max 30 tool calls)
- Model routing awareness
- Negative examples (what NOT to do)

#### AGENTS.md (CRITICAL — must include boot order)

MUST contain this session boot sequence:

```
1. Read SOUL.md — identity, rules, guardrails
2. Read TOOLS.md — tool scope, exec scope, forbidden commands
3. Read memory/YYYY-MM-DD.md (today + yesterday) for recent context
```

**Never write AGENTS.md from scratch** — always reference `~/.openclaw/workspace-dev/AGENTS.md`.

#### TOOLS.md

- Must open with `## Tool Access Policy`
- Document sandbox mode, model, allowed tools
- Document exec scope (allowed + forbidden commands)
- Document write scope

#### USER.md (CRITICAL — must be domain-tailored)

Must contain baseline: name, timezone, language, tech level.
Additionally, include **domain-specific context**:

- Sysadmin agent → hostname, hardware, ports, Docker config, Tailscale URL, key paths
- Dev agent → project paths, coding conventions, architecture overview
- Secretary agent → communication preferences, known contacts

#### IDENTITY.md

```yaml
---
name: <Display Name>
emoji: <emoji>
theme: <one-line role description>
---
```

#### HEARTBEAT.md

At least 1 periodic health check task relevant to the agent's role.

#### CURRENT_STATE.md

Initial state with creation date, model info, known agents table.

### 6. Edit openclaw.json

Add agent entry to `agents.list[]`:

```json
{
  "id": "<id>",
  "workspace": "/home/teaingtit/.openclaw/workspace-<id>",
  "identity": { "name": "<name>", "emoji": "<emoji>" },
  "model": {
    "primary": "openrouter/anthropic/claude-opus-4-6",
    "fallbacks": ["openrouter/openai/gpt-5.2"]
  },
  "sandbox": { "mode": "off" },
  "tools": { "allow": ["read", "exec", "write"] },
  "heartbeat": { "every": "1h" }
}
```

**Rules:**

- `sandbox.mode` must be `"off"` (Docker = isolation boundary)
- Model strings MUST use `openrouter/` prefix
- Omit `activeHours` for 24/7 heartbeat (don't specify `00:00-23:59`)
- Add binding to `bindings[]` only if agent needs a direct channel

### 7. Validate JSON

```bash
python3 -c "import json,sys; json.load(open(sys.argv[1])); print('✅ JSON valid')" ~/.openclaw/openclaw.json
```

### 8. Update Sunday's CURRENT_STATE.md

Add the new agent to the Known Agents table in `~/.openclaw/workspace-sunday/CURRENT_STATE.md`.

### 9. Restart Gateway

```bash
docker compose -f ~/projects/openclaw/docker-compose.yml -f ~/projects/openclaw/docker-compose.override.yml restart openclaw-gateway
```

### 10. Verify

```bash
# Check agent is listed
pnpm openclaw agents list --bindings

# Spawn test
pnpm openclaw agent --agent <id> --message "Confirm online. State your agent ID, name, model, sandbox mode."
```

### 11. Post-Creation Checklist

Verify ALL of the following:

- [ ] `~/.openclaw/agents/<id>/agent/auth-profiles.json` exists
- [ ] `AGENTS.md` contains session boot order (SOUL → TOOLS → memory)
- [ ] `TOOLS.md` opens with "## Tool Access Policy"
- [ ] `USER.md` is populated with domain-relevant details
- [ ] `openclaw.json` passes JSON validation
- [ ] Heartbeat config has no redundant fields
- [ ] Agent spawns successfully
