#!/usr/bin/env bash
# AC9/AC10 (v2.13.0) — README fan-out consent 게이트 주장 whole-file reconcile
# + prerequisites. negative(게이트 주장 부재) + positive(두 공시 줄 · optional deps).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RM="$ROOT/plugins/quality-gates/README.md"
PASS=0; FAIL=0
present(){ if grep -qF "$2" "$RM"; then PASS=$((PASS+1)); echo "  ✓ $1"; else FAIL=$((FAIL+1)); echo "  ✗ FAIL(present): $1 — '$2'"; fi; }
presentE(){ if grep -qE "$2" "$RM"; then PASS=$((PASS+1)); echo "  ✓ $1"; else FAIL=$((FAIL+1)); echo "  ✗ FAIL(present): $1"; fi; }
gone(){ if grep -qF "$2" "$RM"; then FAIL=$((FAIL+1)); echo "  ✗ FAIL(absent): $1 — '$2' 잔존"; else PASS=$((PASS+1)); echo "  ✓ $1"; fi; }
goneE(){ if grep -qE "$2" "$RM"; then FAIL=$((FAIL+1)); echo "  ✗ FAIL(absent): $1"; else PASS=$((PASS+1)); echo "  ✓ $1"; fi; }

echo "== AC9 negative: fan-out consent 게이트 주장 전 위치 reconcile =="
gone  "len(phase1) 공식 제거"                'len(phase1)'
gone  "= 12 옛 max fan-out 라인 제거"        '= 12'
goneE "≥4/>=4 fan-out AskUserQuestion 게이트 주장 제거" '(≥ *4|>= *4).*AskUserQuestion'
gone  "subagent fan-out gate 문구 제거(190/240)" 'subagent fan-out gate'
gone  "gates subagent fan-out 문구 제거(37-40)"  'gates subagent fan-out'

echo "== AC9 positive: 상한 없는 두 줄 공시 =="
present "리뷰어 상한 없이 두 공시 줄"  '리뷰어 상한 없이'
present "끝 줄(다시 부른 수)"      'dispatch 가 모두 돌아온 뒤의 끝 줄'
present "P22 transparency-기반 restate" 'transparency'

echo "== AC10: prerequisites (AC11) =="
present "prereq: optional decl (body-unique)" 'Prerequisites (optional dependency)'
present "prereq: pr-review-toolkit named (body-unique)" 'pr-review-toolkit`(code-reviewer'
gone    "prereq: feature-dev 없음 (AC11 — code-architect 를 부르지 않는다)" 'feature-dev'

echo; echo "readme-scope-reconcile: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
