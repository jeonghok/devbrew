#!/usr/bin/env bash
# AC9/AC10 (v2.13.0) — README fan-out consent 게이트 주장 whole-file reconcile
# + §166 3-tier 정합 + prerequisites. negative(게이트 주장 부재) + positive(재계산
# max fan-out 존재 + 3-tier + optional deps).
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

echo "== AC9 positive: 재계산 max fan-out 선언 =="
present "phase-1 병렬 ≤ 8"      'Phase 1 병렬 ≤ 8'
present "총/iteration ≤ 10"      '총/iteration ≤ 10'
present "P22 transparency-기반 restate" 'transparency'

echo "== AC10: §166 3-tier + prerequisites =="
present "§166 3-tier 헤딩"       '3-tier'
present "Tier A floor"           'Tier A'
present "Tier B codex"           'Tier B'
present "Tier C 전문가"           'Tier C'
present "prerequisites pr-review-toolkit optional" 'pr-review-toolkit'
present "prerequisites feature-dev optional"       'feature-dev'

echo; echo "readme-scope-reconcile: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
