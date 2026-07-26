#!/usr/bin/env bash
# T20/AC14 — README/plugin.json/CHANGELOG synced with v0.23.0
# (interview brief handoff 재설계: payload/audit 분리 + user_statements + 4옵션 게이트).
# 이 스위트는 세 층을 검사한다: (1) T20/AC14 — 이 spec(2026-07-25-...-design.md §8 AC14/
# T20)이 정의하는 진짜 acceptance criteria. (2) CHANGELOG append-only 보존 체크 — AC 번호가
# 아니다. 어느 spec의 AC도 아닌 devbrew repo 컨벤션("플러그인 건드리는 PR마다 version bump
# + CHANGELOG entry")을 집행하는 순수 회귀 락이라 AC 라벨을 붙이지 않는다(붙이면 다른 spec의
# 같은 번호 AC와 충돌 — 아래 참고). (3) README-sync 키워드 스윕도 같은 이유로 AC 라벨 없음.
# plugin.json version은 0.23.x로 assert(patch digit는 의도적으로 unpin) — devbrew의
# "플러그인 건드리는 모든 PR은 patch-bump" 규칙 때문에 리터럴 0.23.0 pin은 다음 doc-only
# bump마다 stale-red. minor(0.23)는 v0.23.0 feature가 여전히 shipped임을 뜻하는 invariant라 pin 유지.
# CHANGELOG [0.20.0]/[0.22.0]/[0.23.0] 엔트리는 append-only 기록이라 리터럴 pin이 correct —
# 버전 bump마다 최신 엔트리 pin을 **추가**하고 과거 pin은 절대 빼지 않는다(누산). 뺀 순간
# 그 히스토리 엔트리가 삭제돼도 이 스위트가 조용히 통과해 append-only 보장이 깨진다.
# AC14는 README "## Principles Instantiated" 섹션(awk 윈도우, 다음 "^## "까지)에 국한된
# 네 사실(라운드별 잠금 제거/종료 시 사용자 일괄 확인/payload-audit 분리/user_sourced_items)
# 어서션 — 내용의 정확성은 검증하지 않는다(누락만 잡음, 정확성은 V6 수동 리뷰 몫).
# 라벨 위생: 이 파일은 과거 여러 design doc의 AC 번호를 그대로 이어받아 쓴 이력이 있다
# (예전 CHANGELOG-보존 체크는 v0.20.0 시절 AC13으로, kw 스윕은 v0.12.0 시절 AC12/AC16으로
# 붙었었다). 그 번호들은 *당시* spec 기준으로는 맞았지만 spec이 갈릴 때마다 같이 갱신되지
# 않아 지금 spec의 AC13(6-리터럴 락)·AC11(bijection A + R4 보존)·AC16(탐색 폭 회귀, advisory)
# 과 충돌했다 — "AC↔T/V 편도 참조"(design doc Rejected Alternatives 명명). T20과 AC14만
# 지금 spec의 T20/AC14 정의와 실제로 일치해 라벨을 유지, 나머지 셋은 라벨을 뗐다.
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
grep -qE '^## \[0\.20\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "CHANGELOG append-only: [0.20.0] 엔트리 보존" \
  || note FAIL "CHANGELOG append-only: [0.20.0] 엔트리가 사라졌다"
grep -qE '^## \[0\.22\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "CHANGELOG append-only: [0.22.0] 엔트리 보존" \
  || note FAIL "CHANGELOG append-only: [0.22.0] 엔트리가 사라졌다"

for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC' 'review_in_progress' 'interview-brief' 'steelman-builder' 'cancel-review' 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' 'model diversity' 'coverage-mapper' 'blind-spot-prober' 'probe_budget' 'user_sourced_items' 'audit_file' 'user_statements' 'bijection'; do
  grep -q "$kw" "$README" \
    && note PASS "README-sync: mentions $kw" || note FAIL "README-sync: missing $kw"
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
