#!/usr/bin/env bash
# guards: plugins/spec-distill/references/docreview-profiles/design-doc.md
#
# R3 AC13 — design-doc 프로필이 정답 출처를 설계문서 `source_interview` 파일의 종류로 정한다(묶음 · brief · 기존 §2).
# 정답 출처를 말하는 세 자리(ground_truth · 층 1 첫 문장 · 층 1 판정 관계 줄)가 같은 모드 문장이고, 깊이 판정이
# scope 축 설명에 붙는다. layer_rubric 은 그대로다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
P="$ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/docreview-profiles/design-doc.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
GT="$(grep -E '^ground_truth: ' "$P" || true)"
for n in 'source_interview' '`epic-bundle` 이면 묶음 모드' '`interview-brief` 면 brief 모드' '§3 열린 질문 · §4 조사 · §5 위험' '그 밖의 종류면 brief §2 확정 항목'; do
  assert_contains "$GT" "$n" "AC13: ground_truth 에 「${n}」"
done
L1="$(awk '/^## 층 1 — /{f=1;next} f&&NF{print;exit}' "$P")"
for n in 'source_interview' 'epic-bundle' 'interview-brief'; do
  assert_contains "$L1" "$n" "AC13: 층 1 첫 문장이 모드 문장이다 — 「${n}」"
done
REL="$(grep -F '**층 1 판정 관계** —' "$P" || true)"
assert_contains "$REL" "같은 정답 출처 파일의 §1 Goal" "AC13: 판정 관계 줄의 과설계 기준이 정답 출처 파일의 §1 Goal"
assert_not_contains "$REL" "브리프 §2 확정 항목" "AC13: 판정 관계 줄이 정답 출처를 brief §2 하나로 적지 않는다"
assert_file_absent "$P" '정답의 출처는 인터뷰 브리프 §2 의 확정 항목이다' "AC13: 옛 층 1 첫 문장이 없다(한 프로필에 정답 출처 두 가지 금지)"
assert_file_grep "$P" '^- `scope` — .*번호 대조 표의 반영 칸이 가리킨 자리가 그 번호에 실제로 답하는가' "AC13: 깊이 판정이 scope 축 설명에 붙는다"
assert_file_grep "$P" '^  layer1: \[goal_fit, problem_definition, scope, architecture, component_relations, data_flow, tradeoffs, feasibility, overdesign\]$' "layer_rubric layer1 은 그대로"
finish
