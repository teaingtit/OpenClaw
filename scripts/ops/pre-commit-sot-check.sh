#!/usr/bin/env bash
# pre-commit-sot-check.sh — block commits that change structural files without updating ANTIGRAVITY.md
# Install: ln -sf ../../scripts/ops/pre-commit-sot-check.sh .git/hooks/pre-commit
# Bypass (emergency only): SKIP_SOT_CHECK=1 git commit ...

set -euo pipefail

[ "${SKIP_SOT_CHECK:-0}" = "1" ] && exit 0

STRUCTURAL_PATTERNS=(
  "openclaw\\.json"
  "DetailHardware\\.md"
  "agents/workspace-.*/SOUL\\.md"
  "agents/workspace-.*/IDENTITY\\.md"
)
SOT_FILE="ANTIGRAVITY.md"

staged=$(git diff --cached --name-only 2>/dev/null || true)
[ -z "$staged" ] && exit 0

structural_hit=""
for pattern in "${STRUCTURAL_PATTERNS[@]}"; do
  match=$(echo "$staged" | grep -E "$pattern" || true)
  [ -n "$match" ] && structural_hit="${structural_hit} ${match}"
done
structural_hit="${structural_hit# }"
[ -z "$structural_hit" ] && exit 0

sot_staged=$(echo "$staged" | grep -Fx "$SOT_FILE" || true)
[ -n "$sot_staged" ] && exit 0

# Blocked — print actionable message
cat >&2 << MSG
[SOT CHECK] Structural files staged ใน commit นี้ แต่ ANTIGRAVITY.md ยังไม่ถูก stage

  Staged structural files:
$(echo "$structural_hit" | tr ' ' '\n' | sed 's/^/    - /')

  Section ที่ต้องอัปเดต:
    - openclaw.json       → §5 AGENT_DEFINITIONS, §7 ACTIVE_ENVIRONMENT_STATE
    - DetailHardware.md   → §3 HARDWARE_INFRASTRUCTURE
    - SOUL.md/IDENTITY.md → §5.N subsection ของ agent ที่เปลี่ยน

  จากนั้น stage ANTIGRAVITY.md:
    git add ANTIGRAVITY.md

  Bypass (เฉพาะฉุกเฉิน):
    SKIP_SOT_CHECK=1 git commit ...
MSG
exit 1
