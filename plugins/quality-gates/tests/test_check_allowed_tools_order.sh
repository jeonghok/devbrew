#!/usr/bin/env bash
# v1.32.3 I-D: check-allowed-tools-order.sh 4-scenario unit test.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINTER="$ROOT/quality-gates/scripts/check-allowed-tools-order.sh"
SKILL="$ROOT/quality-gates/skills/quality-pipeline/SKILL.md"

TMP="$(mktemp -d)"
SKILL_BACKUP="$TMP/SKILL.md.backup"
cp "$SKILL" "$SKILL_BACKUP"
restore() { cp -f "$SKILL_BACKUP" "$SKILL"; }
trap 'restore; rm -rf "$TMP"' EXIT

fail=0

# Scenario A: T-LA-canonical (현재 SKILL.md → PASS)
echo "--- T-LA-canonical ---"
if bash "$LINTER" >/dev/null 2>&1; then
  echo "  PASS T-LA-canonical"
else
  echo "  FAIL T-LA-canonical (canonical should PASS)"; fail=$((fail + 1))
fi

# Scenario B: T-LA-within-group-swap (Group 5: Read와 Glob 위치 교환)
echo "--- T-LA-within-group-swap ---"
sed -E 's/^(  - Read)$/  - __XX__/; s/^(  - Glob)$/  - Read/; s/^  - __XX__$/  - Glob/' \
  "$SKILL_BACKUP" > "$SKILL"
if bash "$LINTER" >/dev/null 2>&1; then
  echo "  FAIL T-LA-within-group-swap (should FAIL)"; fail=$((fail + 1))
else
  echo "  PASS T-LA-within-group-swap (linter rejected swap)"
fi
restore

# Scenario C: T-LA-cross-group-move (AskUserQuestion 삭제 + 맨 끝에 재추가)
echo "--- T-LA-cross-group-move ---"
awk '
  /^  - AskUserQuestion$/ { next }
  /^---$/ { d++ }
  d == 1 && /^cost_class:/ {
    # nothing — skip
  }
  /^---$/ && d == 2 && !inserted {
    print "  - AskUserQuestion"
    inserted = 1
  }
  { print }
' "$SKILL_BACKUP" > "$SKILL"
if bash "$LINTER" >/dev/null 2>&1; then
  echo "  FAIL T-LA-cross-group-move (should FAIL)"; fail=$((fail + 1))
else
  echo "  PASS T-LA-cross-group-move (linter rejected reorder)"
fi
restore

# Scenario D: T-LA-unknown-tool (Group 5 마지막에 Notify 추가)
echo "--- T-LA-unknown-tool ---"
awk '
  /^  - Write$/ { print; print "  - Notify"; next }
  { print }
' "$SKILL_BACKUP" > "$SKILL"
if bash "$LINTER" >/dev/null 2>&1; then
  echo "  FAIL T-LA-unknown-tool (should FAIL)"; fail=$((fail + 1))
else
  echo "  PASS T-LA-unknown-tool (linter rejected unknown tool)"
fi
restore

if [[ "$fail" -eq 0 ]]; then
  echo "All tests pass."
  exit 0
else
  echo "$fail test(s) failed."
  exit 1
fi
