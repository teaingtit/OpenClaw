#!/usr/bin/env bash
# test-runner.sh — รัน test suite แล้ว output JSON (แทนการ spawn QA-Tester เมื่อแค่ต้องการผล pass/fail)
# เรียก QA-Tester agent เมื่อต้องให้ตีความผล (test ไหนล้ม ทำไม) หรือรันชุดย่อย
#
# Usage: test-runner.sh [--json] [vitest args...]
# Output: JSON {"ok":bool,"exit_code":N,"summary":""} or plain stdout when no --json

set -euo pipefail

REPO="${OPENCLAW_REPO:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
cd "$REPO"

FORMAT="text"
for arg in "$@"; do
  case "$arg" in
    --json) FORMAT="json"; shift; break ;;
    *) break ;;
  esac
done

out=$(mktemp)
pnpm test "$@" 2>&1 | tee "$out"
exit_code=${PIPESTATUS[0]:-0}

if [ "$FORMAT" = "json" ]; then
  summary=$(tail -20 "$out" | grep -oE "[0-9]+ passed|[0-9]+ failed|Test Files.*passed" | tr '\n' ' ' | sed 's/"/\\"/g')
  echo "{\"ok\":$([ $exit_code -eq 0 ] && echo true || echo false),\"exit_code\":$exit_code,\"summary\":\"$summary\"}"
fi
rm -f "$out"
exit $exit_code
