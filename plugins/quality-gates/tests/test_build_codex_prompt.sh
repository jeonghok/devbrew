#!/usr/bin/env bash
# test_build_codex_prompt.sh — regression guard for the optional spec-AC
# contract (v2.1.0). run_codex_reviewer.sh resolves the spec script-internally
# and passes its extracted Acceptance Criteria section; when no spec exists it
# passes /dev/null. build_codex_prompt.py MUST treat a non-regular-file spec-AC
# argument (/dev/null, missing) as empty <spec_context>, not error — otherwise
# codex review fails with prompt_build_failed (the v2.0.0 silent-break this
# guard was created for, now re-aimed from plan summary to spec AC).

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$SCRIPT_DIR/../scripts/build_codex_prompt.py"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "  PASS: $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

DIFF="$(mktemp)"; printf 'diff --git a b\n+added line\n' > "$DIFF"
SPEC="$(mktemp)"; printf '## Acceptance Criteria\n1. feature X works\n' > "$SPEC"
trap 'rm -f "$DIFF" "$SPEC"' EXIT

# Case 1: /dev/null spec AC (no spec found) → exit 0, empty <spec_context>.
out="$(python3 "$BUILD" "$DIFF" /dev/null 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && ok "no-spec (/dev/null) → exit 0" || bad "no-spec (/dev/null) → exit $rc (expected 0)"
echo "$out" | grep -q '+added line' && ok "no-spec: diff content present" || bad "no-spec: diff content missing"
# <spec_context> must exist but contain no spec text.
echo "$out" | grep -q '<spec_context>' && ok "no-spec: spec_context block present" || bad "no-spec: spec_context block missing"
echo "$out" | grep -q 'feature X works' && bad "no-spec: leaked spec text" || ok "no-spec: empty spec context"

# Case 2: real spec AC file → content included, exit 0.
out2="$(python3 "$BUILD" "$DIFF" "$SPEC" 2>/dev/null)"; rc2=$?
[ "$rc2" -eq 0 ] && ok "real spec AC → exit 0" || bad "real spec AC → exit $rc2 (expected 0)"
echo "$out2" | grep -q 'feature X works' && ok "real spec AC: content included" || bad "real spec AC: content missing"

# Case 3: missing diff file → exit 2 (diff is still required).
python3 "$BUILD" /nonexistent-qg-diff-xyz "$SPEC" >/dev/null 2>&1
[ "$?" -eq 2 ] && ok "missing diff → exit 2" || bad "missing diff → wrong exit"

echo ""
echo "Total: $((PASS + FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
