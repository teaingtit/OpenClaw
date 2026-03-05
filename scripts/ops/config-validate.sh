#!/usr/bin/env bash
# config-validate.sh — validate openclaw.json critical flags for OpenClaw
# Output: JSON {"valid":true|false,"warnings":[],"errors":[],"agent_count":N}
#
# Checks:
# 1. Valid JSON
# 2. gateway.mode exists
# 3. gateway.auth exists
# 4. agents.defaults.model.primary starts with openrouter/
# 5. tools.agentToAgent.enabled = true
# 6. tools.sessions.visibility = all
# 7. All agents have tools.allow (not "defaults" string)
# 8. No duplicate agent IDs
# 9. Agent count (optional: match ANTIGRAVITY.md active_agents)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
ANTIGRAVITY="$REPO_ROOT/ANTIGRAVITY.md"

python3 << PYEOF
import json
import sys
import re

config_path = "$CONFIG"
antigravity_path = "$ANTIGRAVITY"
errors = []
warnings = []
agent_count = 0

try:
    with open(config_path, "r", encoding="utf-8", errors="replace") as f:
        data = json.load(f)
except FileNotFoundError:
    errors.append("config_not_found")
    print(json.dumps({"valid": False, "warnings": warnings, "errors": errors, "agent_count": 0}))
    sys.exit(1)
except json.JSONDecodeError as e:
    errors.append(f"invalid_json: {e!s}")
    print(json.dumps({"valid": False, "warnings": warnings, "errors": errors, "agent_count": 0}))
    sys.exit(1)

# Critical keys
gateway = data.get("gateway", {})
agents_cfg = data.get("agents", {})
defaults = agents_cfg.get("defaults", {})
tools_cfg = data.get("tools", {})
sessions_cfg = tools_cfg.get("sessions", {})
agent_to_agent = tools_cfg.get("agentToAgent", {})

if not gateway.get("mode"):
    errors.append("gateway.mode missing")
if not gateway.get("auth"):
    warnings.append("gateway.auth missing")

model_primary = defaults.get("model") or {}
if isinstance(model_primary, dict):
    primary = model_primary.get("primary", "")
else:
    primary = str(model_primary)
if not primary.startswith("openrouter/"):
    warnings.append("agents.defaults.model.primary should start with openrouter/")

if not agent_to_agent.get("enabled"):
    errors.append("tools.agentToAgent.enabled must be true")
if sessions_cfg.get("visibility") != "all":
    errors.append("tools.sessions.visibility must be all")

# Agent list
lst = agents_cfg.get("list", [])
agent_count = len(lst)
seen = {}
for i, a in enumerate(lst):
    aid = a.get("id") or f"entry_{i}"
    if aid in seen:
        errors.append(f"duplicate_agent_id: {aid}")
    seen[aid] = True
    tools = a.get("tools") or {}
    allow = tools.get("allow")
    if allow == "defaults" or (isinstance(allow, str) and allow.lower() == "defaults"):
        warnings.append(f"agent {aid} has tools.allow=defaults (may be underprivileged)")

# Optional: compare to ANTIGRAVITY active_agents
try:
    with open(antigravity_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    m = re.search(r"active_agents.*?\[(.*?)\]", content, re.DOTALL)
    if m:
        ref = [x.strip().strip('"').strip("'") for x in m.group(1).split(",")]
        ref_count = len(ref)
        if agent_count != ref_count:
            warnings.append(f"agent_count {agent_count} != ANTIGRAVITY active_agents count {ref_count}")
except Exception:
    pass

valid = len(errors) == 0
out = {"valid": valid, "warnings": warnings, "errors": errors, "agent_count": agent_count}
print(json.dumps(out, ensure_ascii=False))
sys.exit(0 if valid else 1)
PYEOF
