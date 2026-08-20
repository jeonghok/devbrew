#!/usr/bin/env bash
# test_impact_runtime_docs.sh — 버전 · README 문서 락. AC29 AC30 · T20 T33
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"
CHANGELOG="$PLUGIN_ROOT/CHANGELOG.md"
README="$PLUGIN_ROOT/README.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

NEW_SCRIPTS=(resolve-baseline.sh run-test-selection.sh baseline-cache.sh
             diff-test-results.py check_qa_ledger.py)

# T20 + AC29: major digit 만 핀한다 — **floor**로. `"version": "3.0.0"` 리터럴을
# 핀하면 doc-only patch bump 마다 stale-red 가 되고, `== "3"` 로 정확히 고정하면
# 다음 major bump(예: 4.0.0)에서 이 락이 그 자체로 stale-red 가 된다(devbrew
# weight-reduction Task 25 fix round 1 실측). 이 락이 실제로 잡아야 하는 것은
# "impact-driven runtime이 major 3에서 출시됐고 그 이후 roll back 되지 않았다"는
# 불변식이지 "major가 정확히 3이다"가 아니다 — `-ge 3`로 floor를 검사한다.
case_major_bump() {
  local v major
  v=$(python3 -c "
import json
with open('$MANIFEST', encoding='utf-8') as f:
    print(json.load(f)['version'])
")
  major="${v%%.*}"
  [[ "$major" -ge 3 ]] && ok "plugin.json major digit >= 3 (floor, v$v)" \
                       || no "major digit $major (기대 floor >= 3, v$v)"
}

# AC29: CHANGELOG 에 3.0.0 항목이 있고 날짜가 리터럴 placeholder 가 아니다
case_changelog_entry() {
  if grep -qE '^## \[3\.0\.0\] — [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$CHANGELOG"; then
    ok "CHANGELOG [3.0.0] 항목 + 실제 날짜"
  else
    no "CHANGELOG [3.0.0] 항목 부재 또는 날짜 형식 위반 (placeholder 금지)"
  fi
  local sec ok=1
  for sec in Added Changed Removed; do
    awk '/^## \[3\.0\.0\]/{i=1;next} i && /^## \[/{exit} i' "$CHANGELOG" \
      | grep -q "^### $sec" || { echo "    누락 섹션: $sec"; ok=0; }
  done
  [[ $ok -eq 1 ]] && ok "CHANGELOG 3.0.0 에 Added/Changed/Removed" || no "CHANGELOG 섹션 누락"
}

# T33 + AC30: README ## 구조 트리에 신규 5종이 전부 등재. 전체 파일에 걸린 grep은
# 무관한 산문에 이름이 언급되는 것만으로 통과하고 트리 부재를 못 잡는다 — "## 구조"
# 섹션 윈도우(다음 "## " 헤딩에서 종료)로 스코프한다.
case_readme_component_tree() {
  local tree s missing=0
  tree=$(awk '/^## 구조/{i=1;next} i && /^## /{exit} i' "$README")
  for s in "${NEW_SCRIPTS[@]}"; do
    printf '%s\n' "$tree" | grep -qF "$s" || { echo "    README ## 구조 트리 미등재: $s"; missing=1; }
  done
  [[ $missing -eq 0 ]] && ok "README ## 구조 트리에 신규 스크립트 5종 등재" || no "README 컴포넌트 트리 누락"
}

# T33 + AC30: 인스턴스화한 원칙에 LD3/LD5/LD7 줄
case_readme_principles() {
  local w ok=1 tok
  w=$(awk '/^## 인스턴스화한 원칙/{i=1;next} i && /^## /{exit} i' "$README")
  for tok in 'LD3' 'LD5' 'LD7'; do
    printf '%s\n' "$w" | grep -qF "$tok" || { echo "    누락: $tok"; ok=0; }
  done
  [[ $ok -eq 1 ]] && ok "인스턴스화한 원칙에 LD3/LD5/LD7" || no "원칙 줄 누락"
}

# 신규 스크립트 5종이 실제로 존재하고 실행 가능. 이 5개 이름만 확인한다 — scripts/를
# 전수 열거하거나 개수를 세지 않으므로 6번째(스트레이/중복) 스크립트의 존재 여부는
# 이 케이스로 잡히지 않는다.
case_exactly_five_new_scripts() {
  local s ok=1
  for s in "${NEW_SCRIPTS[@]}"; do
    [[ -x "$PLUGIN_ROOT/scripts/$s" ]] || { echo "    부재/비실행: $s"; ok=0; }
  done
  [[ $ok -eq 1 ]] && ok "신규 스크립트 5종 존재 + 실행 가능" || no "신규 스크립트 문제"
}

for c in case_major_bump case_changelog_entry case_readme_component_tree \
         case_readme_principles case_exactly_five_new_scripts; do
  echo "== $c"; $c
done
finish
