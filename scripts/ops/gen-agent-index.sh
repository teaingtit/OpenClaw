#!/usr/bin/env bash
# gen-agent-index.sh — regenerate agent table in SYSTEM_INDEX.md from openclaw.json
# Usage: gen-agent-index.sh [--commit]
# Exit: 0 = clean (no drift), 1 = drift detected and fixed, 2 = error
# Output: JSON {"status":"clean"|"updated"|"error","agents_count":N,"changes":N}
# Env: OPENCLAW_CONFIG (default ~/.openclaw/openclaw.json)
#      SYSTEM_INDEX_PATH (default <repo_root>/SYSTEM_INDEX.md)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
INDEX_FILE="${SYSTEM_INDEX_PATH:-$REPO_ROOT/SYSTEM_INDEX.md}"
ROLES_FILE="$SCRIPT_DIR/agent-roles.json"
COMMIT=0

for arg in "$@"; do
  case "$arg" in
    --commit) COMMIT=1 ;;
  esac
done

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
export GEN_ROLES="${ROLES_FILE}"

python_exit=0
python3 << 'PYEOF' || python_exit=$?
import json
import os
import sys
from collections import defaultdict

config_path = os.environ["GEN_CONFIG"]
index_path = os.environ["GEN_INDEX"]
roles_path = os.environ.get("GEN_ROLES", "")

try:
    with open(config_path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(json.dumps({"status": "error", "error": str(e), "agents_count": 0, "changes": 0}))
    sys.exit(2)

role_map = {}
if roles_path and os.path.isfile(roles_path):
    try:
        with open(roles_path, "r", encoding="utf-8") as f:
            role_map = json.load(f)
    except Exception:
        pass

agents = data.get("agents", {}).get("list", [])


def get_model_short(a):
    model = a.get("model") or {}
    primary = (model.get("primary", "") if isinstance(model, dict) else str(model)) or ""
    return primary.split("/")[-1] if "/" in primary else primary


def get_role(a):
    aid = a.get("id", "")
    if aid in role_map:
        return role_map[aid]
    identity = a.get("identity") or {}
    return (identity.get("name") if isinstance(identity, dict) else None) or aid


def compress_tools(allow):
    # Count tools per underscore-prefix
    prefix_count = defaultdict(int)
    for t in allow:
        if "_" in t:
            prefix_count[t[:t.index("_")]] += 1
    # Rebuild preserving order; collapse prefix groups with ≥2 tools into prefix_*
    result = []
    seen_wildcards = set()
    for t in allow:
        if "_" in t:
            prefix = t[:t.index("_")]
            if prefix_count[prefix] >= 2:
                if prefix not in seen_wildcards:
                    result.append(prefix + "_*")
                    seen_wildcards.add(prefix)
            else:
                result.append(t)
        else:
            result.append(t)
    return result


def get_tools(a):
    tools = a.get("tools") or {}
    allow = tools.get("allow")
    if allow is None:
        return "defaults"
    if len(allow) == 0:
        return "none"
    compressed = compress_tools(allow)
    return ", ".join(compressed)


def md_escape(s):
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

# --commit: stage and commit SYSTEM_INDEX.md when drift was fixed
if [ "$python_exit" = "1" ] && [ "$COMMIT" = "1" ]; then
  git -C "$REPO_ROOT" add -- "$INDEX_FILE" 2>/dev/null || true
  OPENCLAW_MACHINE_COMMIT=1 git -C "$REPO_ROOT" \
    -c user.name="sot-sync" \
    -c user.email="sot-sync@local" \
    commit -m "sot-sync: update agent table from openclaw.json" \
    2>/dev/null || true
fi

exit "$python_exit"
