#!/usr/bin/env bash
# gen-agent-index.sh — regenerate agent table in SYSTEM_INDEX.md from openclaw.json
# Usage: gen-agent-index.sh
# Exit: 0 = clean (no drift), 1 = drift detected and fixed, 2 = error
# Output: JSON {"status":"clean"|"updated"|"error","agents_count":N,"changes":N}
# Env: OPENCLAW_CONFIG (default ~/.openclaw/openclaw.json)
#      SYSTEM_INDEX_PATH (default <repo_root>/SYSTEM_INDEX.md)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
INDEX_FILE="${SYSTEM_INDEX_PATH:-$REPO_ROOT/SYSTEM_INDEX.md}"

if [ ! -f "$CONFIG" ]; then
  printf '{"status":"error","error":"config not found","agents_count":0,"changes":0}\n'
  exit 2
fi

if [ ! -f "$INDEX_FILE" ]; then
  printf '{"status":"error","error":"SYSTEM_INDEX.md not found","agents_count":0,"changes":0}\n'
  exit 2
fi

export GEN_CONFIG="$CONFIG"
export GEN_INDEX="$INDEX_FILE"

python3 << 'PYEOF'
import json
import os
import sys

config_path = os.environ["GEN_CONFIG"]
index_path = os.environ["GEN_INDEX"]

try:
    with open(config_path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(json.dumps({"status": "error", "error": str(e), "agents_count": 0, "changes": 0}))
    sys.exit(2)

agents = data.get("agents", {}).get("list", [])


def get_model_short(a):
    model = a.get("model") or {}
    primary = (model.get("primary", "") if isinstance(model, dict) else str(model)) or ""
    return primary.split("/")[-1] if "/" in primary else primary


def get_role(a):
    identity = a.get("identity") or {}
    return (identity.get("name") if isinstance(identity, dict) else None) or a.get("id", "")


def get_tools(a):
    tools = a.get("tools") or {}
    allow = tools.get("allow")
    if allow is None:
        return "defaults"
    if len(allow) == 0:
        return "none"
    return ", ".join(allow)


def md_escape(s):
    # Escape * so Markdown tables render it as literal asterisk
    return s.replace("*", r"\*")


rows_data = [
    [a.get("id", ""), get_role(a), get_model_short(a), md_escape(get_tools(a))]
    for a in agents
]

headers = ["id", "role", "model", "tools"]
col_widths = [
    max(len(headers[i]), max((len(r[i]) for r in rows_data), default=0))
    for i in range(4)
]


def fmt_row(cells):
    padded = [cells[i].ljust(col_widths[i]) for i in range(4)]
    return "| " + " | ".join(padded) + " |"


def fmt_sep():
    return "| " + " | ".join("-" * w for w in col_widths) + " |"


new_section = (
    ["\n", fmt_row(headers) + "\n", fmt_sep() + "\n"]
    + [fmt_row(r) + "\n" for r in rows_data]
    + ["\n"]
)

with open(index_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

start_idx = None
end_idx = None
for i, line in enumerate(lines):
    s = line.rstrip()
    if s.startswith("## Agents"):
        start_idx = i
    elif start_idx is not None and s.startswith("## ") and i > start_idx:
        end_idx = i
        break

if start_idx is None:
    print(json.dumps({"status": "error", "error": "## Agents section not found", "agents_count": len(agents), "changes": 0}))
    sys.exit(2)


def normalize_table(section_lines):
    result = []
    for line in section_lines:
        s = line.strip()
        if s.startswith("|"):
            cells = [c.strip() for c in s.split("|")]
            result.append("|".join(cells))
        elif s:
            result.append(s)
    return result


current_section = lines[start_idx + 1:end_idx] if end_idx is not None else lines[start_idx + 1:]

if normalize_table(current_section) == normalize_table(new_section):
    print(json.dumps({"status": "clean", "agents_count": len(agents), "changes": 0}))
    sys.exit(0)

# Rebuild file atomically
if end_idx is not None:
    new_lines = lines[:start_idx + 1] + new_section + lines[end_idx:]
else:
    new_lines = lines[:start_idx + 1] + new_section

tmp_path = index_path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)
os.replace(tmp_path, index_path)

print(json.dumps({"status": "updated", "agents_count": len(agents), "changes": 1}))
sys.exit(1)
PYEOF
