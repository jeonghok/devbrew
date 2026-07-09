#!/usr/bin/env bash
# AC16 — README/plugin.json/CHANGELOG synced with v0.19.0 (review-lock session-id bridge).
# plugin.json version은 0.19.x로 assert(patch digit는 의도적으로 unpin) — devbrew의
# "플러그인 건드리는 모든 PR은 patch-bump" 규칙 때문에 리터럴 0.19.0 pin은 다음 doc-only
# bump마다 stale-red. minor(0.19)는 v0.19.0 feature가 여전히 shipped임을 뜻하는 invariant라 pin 유지.
# CHANGELOG [0.19.0] 엔트리는 append-only 기록이라 리터럴 pin이 correct.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
README="$REPO_ROOT/plugins/spec-distill/README.md"
PLUGIN_JSON="$REPO_ROOT/plugins/spec-distill/.claude-plugin/plugin.json"
CHANGELOG="$REPO_ROOT/plugins/spec-distill/CHANGELOG.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

grep -qE '"version": "0\.19\.[0-9]+"' "$PLUGIN_JSON" \
  && note PASS "AC16: plugin.json version 0.19.x" || note FAIL "AC16: plugin.json not 0.19.x (reverted below 0.19.0 or wrong minor?)"
grep -qE '^## \[0\.19\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC16: CHANGELOG [0.19.0] entry with ISO date" || note FAIL "AC16: CHANGELOG [0.19.0] missing/!ISO"
grep -qE '^## \[0\.19\.0\].*XX' "$CHANGELOG" \
  && note FAIL "AC16: CHANGELOG date has XX placeholder" || note PASS "AC16: no XX placeholder in date"

for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC' 'review_in_progress' 'interview-brief' 'steelman-builder' 'cancel-review'; do
  grep -q "$kw" "$README" \
    && note PASS "AC16: README mentions $kw" || note FAIL "AC16: README missing $kw"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
