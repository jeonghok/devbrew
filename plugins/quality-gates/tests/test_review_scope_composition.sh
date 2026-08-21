#!/usr/bin/env bash
# AC3/AC4/AC6/AC8/AC11 (positive) + AC13/AC14 (negative) — v2.13.0
# Review gate 스코프-구동 구성 프로즈의 존재/부재 grep-lock.
# body-unique 문구를 요구(헤더-satisfiable 함정 회피). 선택 정확성은 게이트하지 않는다(lightness).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL_REAL="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
PASS=0; FAIL=0

# Task 31 fix round 1 (F1): 아래 absent() 검사(0-100/0–100//100/code-simplifier/
# security-auditor/secret-masking) 는 quality-pipeline 스킬 전체에 대한 비목표
# 불변식이지 Review gate 섹션에만 국한되지 않는다 — Runtime gate 절차가
# references/runtime-gate.md 로 옮겨진 뒤에도 "스킬 어디에도 없다"는 계약을
# 그대로 재려면 분할 전과 동일한 논리적 문서 위에서 돌아야 한다. AC6/AC14의
# awk 윈도우 검사(Tier A→Tier B, Reviewer composition 섹션)는 전부 Runtime gate
# (line 748)보다 앞선 섹션만 앵커하므로 재구성에 영향받지 않는다. 재구성 실패는
# 조용히 원본으로 폴백하지 않고 FAIL 한다.
. "$ROOT/plugins/quality-gates/tests/lib/reconstruct-skill.sh"
if ! SKILL="$(reconstruct_skill_md "$SKILL_REAL")"; then
  echo "FAIL: SKILL.md ↔ references/runtime-gate.md 재구성 실패 ($SKILL_REAL)"
  exit 1
fi
trap 'rm -f "$SKILL"' EXIT
has()  { if grep -qF "$2" "$SKILL"; then PASS=$((PASS+1)); echo "  ✓ $1"; else FAIL=$((FAIL+1)); echo "  ✗ FAIL(present): $1 — '$2'"; fi; }
hasE() { if grep -qE "$2" "$SKILL"; then PASS=$((PASS+1)); echo "  ✓ $1"; else FAIL=$((FAIL+1)); echo "  ✗ FAIL(present): $1"; fi; }
absent(){ if grep -qF "$2" "$SKILL"; then FAIL=$((FAIL+1)); echo "  ✗ FAIL(absent): $1 — '$2' 잔존"; else PASS=$((PASS+1)); echo "  ✓ $1"; fi; }

echo "== AC3: Tier C rubric — 6 전문가 embed =="
has "code-reviewer 강한 default"      'pr-review-toolkit:code-reviewer'
has "silent-failure-hunter"           'silent-failure-hunter'
has "type-design-analyzer"            'type-design-analyzer'
has "pr-test-analyzer"                'pr-test-analyzer'
has "comment-analyzer"                'comment-analyzer'
has "feature-dev:code-architect"      'feature-dev:code-architect'

echo "== AC4: scope-signal 팔레트 토큰 =="
for tok in '역직렬화' '인젝션' 'XSS' 'crypto' 'TLS' 'XXE' 'GHA' 'SRI' 'deps-manifest' 'migration' 'public-API' '삭제 파일'; do
  has "팔레트 토큰: $tok" "$tok"
done

echo "== AC6: code-reviewer는 Tier C 강한 default (floor 아님) =="
has "강한 default 문구" '강한 default'
# floor(Tier A) 윈도우 안에 code-reviewer가 없어야 한다. Tier A anchor → Tier B anchor.
a_start=$(awk '/Tier A — Floor \(스코프 무관, 항상 디스패치/{print NR; exit}' "$SKILL")
a_end=$(awk -v s="$a_start" 'NR>s && /Tier B — codex \(availability-floor/{print NR; exit}' "$SKILL")
if [[ -n "$a_start" && -n "$a_end" ]] && ! awk -v s="$a_start" -v e="$a_end" 'NR>s && NR<e' "$SKILL" | grep -qF 'code-reviewer'; then
  PASS=$((PASS+1)); echo "  ✓ AC6: Tier A floor 윈도우($a_start..$a_end)에 code-reviewer 부재"
else
  FAIL=$((FAIL+1)); echo "  ✗ FAIL AC6: Tier A 윈도우에 code-reviewer 존재 또는 anchor 없음 (s=$a_start e=$a_end)"
fi

echo "== AC8: transparency 라인 (loud 정의) =="
has "transparency prefix"  '> [quality-gates] Review iter N — 선택:'
has "transparency 제외 절"  '제외:'

echo "== AC11: graceful degradation loud log =="
has "degrade: specialist"      'specialist'
has "degrade: unavailable"     'unavailable (<plugin> 미설치)'
has "degrade: degraded coverage" 'degraded coverage'

echo "== AC13 (negative): 수치 0-100 스코어링 미도입 =="
absent "0-100 스코어링(하이픈)" '0-100'
absent "0–100 스코어링(엔대시)" '0–100'
absent "/100 스코어링"          '/100'

echo "== AC14 (negative): non-goal 가드 =="
absent "code-simplifier subagent_type 미등장" 'code-simplifier'
absent "security-auditor graft 미포함"        'security-auditor'
absent "secret-masking graft 미포함"          'secret-masking'
# Tier C 외부 dispatch에 model: override 부재 — 팔레트/rubric 섹션 윈도우 안에 'model:' 없어야.
c_start=$(awk '/## Reviewer composition \(scope-driven\)/{print NR; exit}' "$SKILL")
c_end=$(awk -v s="$c_start" 'NR>s && /^## /{print NR; exit}' "$SKILL")
if [[ -n "$c_start" && -n "$c_end" ]] && ! awk -v s="$c_start" -v e="$c_end" 'NR>s && NR<e' "$SKILL" | grep -qE '^[[:space:]]*model:'; then
  PASS=$((PASS+1)); echo "  ✓ AC14: composition 섹션에 model: override 부재"
else
  FAIL=$((FAIL+1)); echo "  ✗ FAIL AC14: composition 섹션에 model: override 존재 또는 섹션 없음 (s=$c_start e=$c_end)"
fi

echo; echo "review-scope-composition: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
