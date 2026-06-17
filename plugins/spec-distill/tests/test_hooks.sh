#!/usr/bin/env bash
# spec-distill — SessionStart anchor 제거 회귀 락 (v0.16.0).
# Run: bash plugins/spec-distill/tests/test_hooks.sh
# session-anchor.sh 훅이 실수로 되살아나지 않음을 보장. Exits 0 on pass, 1 on fail.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/spec-distill"
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
ANCHOR="$PLUGIN_ROOT/hooks/session-anchor.sh"

pass=0
fail=0

note() {
  if [[ "$1" == "PASS" ]]; then
    pass=$((pass+1))
    echo "  ✓ $2"
  else
    fail=$((fail+1))
    echo "  ✗ $2"
  fi
}

echo "=== SessionStart anchor removal regression lock ==="

# 1. hooks.json must NOT register a SessionStart hook (and must stay valid JSON).
if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(1 if "SessionStart" in d.get("hooks", {}) else 0)' "$HOOKS_JSON"; then
  note PASS "hooks.json has no SessionStart key"
else
  note FAIL "hooks.json still registers a SessionStart hook (or is invalid JSON)"
fi

# 2. The session-anchor.sh hook file must NOT exist.
if [[ ! -e "$ANCHOR" ]]; then
  note PASS "hooks/session-anchor.sh does not exist"
else
  note FAIL "hooks/session-anchor.sh still exists"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
