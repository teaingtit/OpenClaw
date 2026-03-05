#!/usr/bin/env bash
# git-preflight.sh — git status + diff for agent pre-flight (e.g. sot-keeper)
# Usage: git-preflight.sh [--watch-list file1,file2,...] [--format json]
# Output: {"branch":"main","clean":bool,"ahead":N,"behind":N,"modified":[],"untracked":N,"watch_triggered":[]}
# Exit: 0 = clean, 1 = dirty, 2 = watch list triggered

set -euo pipefail

REPO="${OPENCLAW_REPO:-}"
[ -z "$REPO" ] && REPO=$(git rev-parse --show-toplevel 2>/dev/null) || true
[ -z "$REPO" ] && REPO="."
cd "$REPO"

WATCH_LIST=""
FORMAT="json"
while [ $# -gt 0 ]; do
  case "$1" in
    --watch-list) WATCH_LIST="${2:-}"; shift 2 || shift ;;
    --watch-list=*) WATCH_LIST="${1#--watch-list=}"; shift ;;
    --format) FORMAT="${2:-json}"; shift 2 || shift ;;
    --format=*) FORMAT="${1#--format=}"; shift ;;
    *) shift ;;
  esac
done

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
ahead=0
behind=0
git rev-parse -q --verify HEAD >/dev/null 2>&1 && ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null) || true
git rev-parse -q --verify HEAD >/dev/null 2>&1 && behind=$(git rev-list --count HEAD..@{u} 2>/dev/null) || true

modified_str=$(git status --porcelain 2>/dev/null | awk '{print $2}' | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" 2>/dev/null || echo "[]")
untracked=$(git status --porcelain 2>/dev/null | grep -c '^??' || true)
clean=1
[ "$modified_str" != "[]" ] && [ -n "$(git status --porcelain 2>/dev/null)" ] && clean=0

# Watch list: files that changed (in diff or status)
changed_names=$(git diff HEAD --name-only 2>/dev/null; git status -u --porcelain 2>/dev/null | awk '{print $2}')
export GP_WATCH_LIST="$WATCH_LIST"
export GP_BRANCH="$branch" GP_CLEAN=$clean GP_AHEAD=$ahead GP_BEHIND=$behind GP_MODIFIED="$modified_str" GP_UNTRACKED=$untracked GP_CHANGED="$changed_names"
python3 << 'PYEOF'
import json
import os
watch_list = os.environ.get("GP_WATCH_LIST", "")
watch_arr = [x.strip() for x in watch_list.split(",") if x.strip()]
changed = os.environ.get("GP_CHANGED", "")
changed_lines = [x for x in changed.split("\n") if x.strip()]
watch_triggered = []
for w in watch_arr:
    for c in changed_lines:
        if c == w or c.startswith(w + "/") or c.endswith("/" + w):
            watch_triggered.append(w)
            break
watch_triggered = list(dict.fromkeys(watch_triggered))
modified = json.loads(os.environ.get("GP_MODIFIED", "[]"))
out = {
    "branch": os.environ.get("GP_BRANCH", "main"),
    "clean": os.environ.get("GP_CLEAN", "1") == "1",
    "ahead": int(os.environ.get("GP_AHEAD", 0)),
    "behind": int(os.environ.get("GP_BEHIND", 0)),
    "modified": modified,
    "untracked": int(os.environ.get("GP_UNTRACKED", 0)),
    "watch_triggered": watch_triggered,
}
print(json.dumps(out))
PYEOF

exit_code=0
[ $clean -eq 0 ] && exit_code=1
# Recompute watch_triggered for exit code (avoid second Python)
if [ -n "$WATCH_LIST" ]; then
  for w in $(echo "$WATCH_LIST" | tr ',' ' '); do
    w=$(echo "$w" | tr -d ' ')
    echo "$changed_names" | grep -qE "^$w$|^$w/|/$w$" && { exit_code=2; break; }
  done
fi
exit $exit_code
