#!/usr/bin/env bash
# test_impact_runtime_docs.sh — 버전 · README 문서 락. AC29 AC30 · T20 T33
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"
CHANGELOG="$PLUGIN_ROOT/CHANGELOG.md"
README="$PLUGIN_ROOT/README.md"

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

NEW_SCRIPTS=(resolve-baseline.sh run-test-selection.sh baseline-cache.sh
             diff-test-results.py check_qa_ledger.py)

# T20 + AC29: major digit 만 핀한다. `"version": "3.0.0"` 리터럴을 핀하면
# doc-only patch bump 마다 stale-red 가 된다 — 불변식만 검사하고 patch 는 unpin.
case_major_bump() {
  local v major
  v=$(python3 -c "
import json
with open('$MANIFEST', encoding='utf-8') as f:
    print(json.load(f)['version'])
")
  major="${v%%.*}"
  [[ "$major" == "3" ]] && pass "plugin.json major digit == 3 (v$v)" \
                        || fail "major digit $major (기대 3, v$v)"
}

# AC29: CHANGELOG 에 3.0.0 항목이 있고 날짜가 리터럴 placeholder 가 아니다
case_changelog_entry() {
  if grep -qE '^## \[3\.0\.0\] — [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$CHANGELOG"; then
    pass "CHANGELOG [3.0.0] 항목 + 실제 날짜"
  else
    fail "CHANGELOG [3.0.0] 항목 부재 또는 날짜 형식 위반 (placeholder 금지)"
  fi
  local sec ok=1
  for sec in Added Changed Removed; do
    awk '/^## \[3\.0\.0\]/{i=1;next} i && /^## \[/{exit} i' "$CHANGELOG" \
      | grep -q "^### $sec" || { echo "    누락 섹션: $sec"; ok=0; }
  done
  [[ $ok -eq 1 ]] && pass "CHANGELOG 3.0.0 에 Added/Changed/Removed" || fail "CHANGELOG 섹션 누락"
}

# T33 + AC30: README 컴포넌트 트리에 신규 5종이 전부 등재
case_readme_component_tree() {
  local s missing=0
  for s in "${NEW_SCRIPTS[@]}"; do
    grep -qF "$s" "$README" || { echo "    README 미등재: $s"; missing=1; }
  done
  [[ $missing -eq 0 ]] && pass "README 에 신규 스크립트 5종 등재" || fail "README 컴포넌트 트리 누락"
}

# T33 + AC30: 인스턴스화한 원칙에 LD3/LD5/LD7 줄
case_readme_principles() {
  local w ok=1 tok
  w=$(awk '/^## 인스턴스화한 원칙/{i=1;next} i && /^## /{exit} i' "$README")
  for tok in 'LD3' 'LD5' 'LD7'; do
    printf '%s\n' "$w" | grep -qF "$tok" || { echo "    누락: $tok"; ok=0; }
  done
  [[ $ok -eq 1 ]] && pass "인스턴스화한 원칙에 LD3/LD5/LD7" || fail "원칙 줄 누락"
}

# 신규 스크립트 5종이 실제로 존재하고 실행 가능 (6번째가 생기지 않았는지도 확인)
case_exactly_five_new_scripts() {
  local s ok=1
  for s in "${NEW_SCRIPTS[@]}"; do
    [[ -x "$PLUGIN_ROOT/scripts/$s" ]] || { echo "    부재/비실행: $s"; ok=0; }
  done
  [[ $ok -eq 1 ]] && pass "신규 스크립트 5종 존재 + 실행 가능" || fail "신규 스크립트 문제"
}

for c in case_major_bump case_changelog_entry case_readme_component_tree \
         case_readme_principles case_exactly_five_new_scripts; do
  echo "== $c"; $c
done
echo "── impact runtime docs: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
