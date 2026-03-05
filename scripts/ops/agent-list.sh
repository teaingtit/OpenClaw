#!/usr/bin/env bash
# agent-list.sh — list agents from openclaw.json
# Usage: agent-list.sh [--format json|table] [--check-health]
# Output: JSON array or table of id, model, tools, heartbeat; optionally workspace_ok

set -euo pipefail

CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
FORMAT="json"
CHECK_HEALTH="false"
while [ $# -gt 0 ]; do
  case "$1" in
    --format) FORMAT="${2:-json}"; shift 2 || shift ;;
    --format=*) FORMAT="${1#--format=}"; shift ;;
    --check-health) CHECK_HEALTH="true"; shift ;;
    *) shift ;;
  esac
done

export OPENCLAW_CONFIG="$CONFIG"
export AGENT_LIST_CHECK_HEALTH="$CHECK_HEALTH"
export AGENT_LIST_FORMAT="$FORMAT"
python3 << 'PYEOF'
import json
import os

config_path = os.environ.get("OPENCLAW_CONFIG", os.path.expanduser("~/.openclaw/openclaw.json"))
check_health = os.environ.get("AGENT_LIST_CHECK_HEALTH", "").lower() == "true"
fmt = os.environ.get("AGENT_LIST_FORMAT", "json")

try:
    with open(config_path, "r", encoding="utf-8", errors="replace") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    print("[]" if fmt == "json" else "No config")
    exit(0)

lst = data.get("agents", {}).get("list", [])
out = []
for a in lst:
    aid = a.get("id", "")
    model = a.get("model") or {}
    if isinstance(model, dict):
        primary = model.get("primary", "")
    else:
        primary = str(model)
    tools = a.get("tools") or {}
    allow = tools.get("allow")
    if isinstance(allow, list):
        tools_str = ",".join(allow[:5]) + ("..." if len(allow) > 5 else "")
    else:
        tools_str = str(allow) if allow else ""
    hb = a.get("heartbeat") or {}
    if isinstance(hb, dict):
        hb_str = hb.get("every", "") or hb.get("at", "") or ""
    else:
        hb_str = str(hb)
    workspace_ok = None
    if check_health:
        ws = a.get("workspace", "")
        if ws:
            import os as os_mod
            workspace_ok = os_mod.path.isdir(os_mod.path.expanduser(ws))
        else:
            workspace_ok = None
    rec = {"id": aid, "model": primary, "tools": tools_str, "heartbeat": hb_str}
    if check_health and workspace_ok is not None:
        rec["workspace_ok"] = workspace_ok
    out.append(rec)

if fmt == "table":
    print(f"{'ID':<18} | {'MODEL':<28} | {'TOOLS':<24} | HEARTBEAT")
    print("-" * 90)
    for r in out:
        tools_short = (r["tools"][:21] + "...") if len(r["tools"]) > 24 else r["tools"]
        print(f"{r['id']:<18} | {r['model']:<28} | {tools_short:<24} | {r['heartbeat']}")
else:
    print(json.dumps(out, ensure_ascii=False))
PYEOF
