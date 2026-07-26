#!/usr/bin/env bash
# AC13/AC16 — README/plugin.json/CHANGELOG synced with v0.22.0 (coverage-driven interview).
# plugin.json version은 0.22.x로 assert(patch digit는 의도적으로 unpin) — devbrew의
# "플러그인 건드리는 모든 PR은 patch-bump" 규칙 때문에 리터럴 0.22.0 pin은 다음 doc-only
# bump마다 stale-red. minor(0.22)는 v0.22.0 feature가 여전히 shipped임을 뜻하는 invariant라 pin 유지.
# CHANGELOG [0.20.0]/[0.22.0] 엔트리는 append-only 기록이라 리터럴 pin이 correct.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
README="$REPO_ROOT/plugins/spec-distill/README.md"
PLUGIN_JSON="$REPO_ROOT/plugins/spec-distill/.claude-plugin/plugin.json"
CHANGELOG="$REPO_ROOT/plugins/spec-distill/CHANGELOG.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

grep -qE '"version": "0\.23\.[0-9]+"' "$PLUGIN_JSON" \
  && note PASS "T20: plugin.json version 0.23.x" \
  || note FAIL "T20: plugin.json이 0.23.x가 아님"
grep -qE '^## \[0\.23\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "T20: CHANGELOG [0.23.0] 엔트리 + ISO 날짜" \
  || note FAIL "T20: CHANGELOG [0.23.0] 누락/비-ISO"
grep -qE '^## \[0\.2[02]\.0\].*XX' "$CHANGELOG" \
  && note FAIL "T20: CHANGELOG 날짜에 XX placeholder" || note PASS "T20: XX placeholder 없음"
grep -qE '^## \[0\.22\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC11: CHANGELOG [0.22.0] 엔트리 보존 (append-only)" \
  || note FAIL "AC11: CHANGELOG [0.22.0] 엔트리가 사라졌다"

for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC' 'review_in_progress' 'interview-brief' 'steelman-builder' 'cancel-review' 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' 'model diversity' 'coverage-mapper' 'blind-spot-prober' 'probe_budget' 'user_sourced_items' 'audit_file' 'user_statements' 'bijection'; do
  grep -q "$kw" "$README" \
    && note PASS "AC16: README mentions $kw" || note FAIL "AC16: README missing $kw"
done

# AC14: README "Principles Instantiated"가 네 사실을 각각 명시하는지 (섹션 스코프 — 헤더-satisfiable 회피)
pi_block="$(awk '/^## Principles Instantiated/{f=1;print;next} /^## /{f=0} f' "$README")"
{ [[ -n "$pi_block" ]] && grep -qE '라운드별 잠금|라운드마다 결정' <<<"$pi_block"; } \
  && note PASS "AC14/1: 라운드별 잠금 제거 명시" || note FAIL "AC14/1: 라운드별 잠금 제거가 없다"
grep -qE '일괄 확인|사용자 확인' <<<"$pi_block" \
  && note PASS "AC14/2: 종료 시 사용자 일괄 확인 명시" || note FAIL "AC14/2: 사용자 일괄 확인이 없다"
grep -qE 'payload.*audit|2파일|두 파일' <<<"$pi_block" \
  && note PASS "AC14/3: payload/audit 분리 명시" || note FAIL "AC14/3: payload/audit 분리가 없다"
grep -q 'user_sourced_items' <<<"$pi_block" \
  && note PASS "AC14/4: user_sourced_items 계약 명시" || note FAIL "AC14/4: user_sourced_items 계약이 없다"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
