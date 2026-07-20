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
present "prereq: Tier C optional decl (body-unique)" 'Tier C optional dependencies'
present "prereq: pr-review-toolkit named (body-unique)" 'pr-review-toolkit`(code-reviewer'
present "prereq: feature-dev named (body-unique)"       'feature-dev`(code-architect)'

echo "== C5 regression lock: codex-depth reconcile (availability-floor vs standard/deep-only) =="
# §166 documents codex as a Tier B *availability-floor* (runs on ALL non-trivia
# depths when detected). This section locks the Cost prose against re-introducing
# the superseded "standard/deep-only" codex-cost claim — the exact scope-blind
# drift a fan-out-only reconcile missed (self-dogfood C5, v2.13.0: §166 was
# rewritten to availability-floor while the Cost section still said standard/deep).
# Teeth boundary (cf. AC11): the negatives pin the known old phrasings; a fresh
# paraphrase that re-contradicts would slip the grep — the dynamic codex review
# is the backstop for that residue.
presentE "codex cost = availability-floor, all depths (body-unique)" 'every non-trivia Review gate dispatch when detected'
goneE    "old 'standard/deep-only' codex-cost claim 제거"            'on each .standard./.deep. Review gate dispatch'
goneE    "Deep 비용행 codex depth-귀속 제거"                          'Tier C 전문가 다수 \+ codex'

echo; echo "readme-scope-reconcile: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
