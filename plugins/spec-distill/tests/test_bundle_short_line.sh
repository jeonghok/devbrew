#!/usr/bin/env bash
# 번호 대조의 질문용 짧은 줄 — check_bundle_coverage.short_line 과 spec_review_bundle.py entry 의 `질문 줄:`.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_bundle_short_line.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SD="$ROOT/plugins/spec-distill"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

sl() { PYTHONPATH="$SD/scripts" python3 -c 'import sys, json, check_bundle_coverage as c; print(c.short_line(json.loads(sys.argv[1])))' "$1"; }
assert_eq "$(sl '{"status":0,"missing":[],"shallow":[],"unserved":[],"unknown":[]}')" "" "짧은 줄: 경고가 없으면 빈 글"
assert_eq "$(sl '{"status":1,"missing":["D3","K9"],"shallow":[{"id":"S2","reason":"x"}],"unserved":[],"unknown":[]}')" \
  "번호 대조 경고 3개: 빠진 번호 2 · 얕은 답 1" "짧은 줄: 0 이 아닌 종류만, 개수는 warning_count 와 같다"
assert_eq "$(sl '{"status":1,"missing":[],"shallow":[],"unserved":["S4"],"unknown":["a","b"]}')" \
  "번호 대조 경고 3개: 받드는 에픽 없는 발화 1 · 셀 수 없음 2" "짧은 줄: 나머지 두 종류도 이 순서로"
assert_eq "$(sl '{"status":3,"reason":"x"}')" "번호 대조 경고 1개: 검사 불가" "짧은 줄: 검사 불가는 1개"

# entry 출력 — 경고가 있는 결과와 없는 결과(번호 대조 결과만 바꿔 끼운다)
mkdir -p "$T/docs"
printf -- '---\ntype: interview-brief\n---\n\n# brief\n' > "$T/docs/brief.md"
printf -- '---\nsource_interview: docs/brief.md\n---\n\n# 설계\n' > "$T/docs/d-design.md"
entry_out() {  # entry_out <번호 대조가 낼 결과 JSON>
  PYTHONPATH="$SD/scripts" python3 -c '
import sys, json
import check_bundle_coverage as c, spec_review_bundle as s
r = json.loads(sys.argv[1])
c.coverage = lambda *_: r
print("\n".join(s.entry(sys.argv[2], "docs/brief.md", sys.argv[3])))
' "$1" "$T/docs/d-design.md" "$T"
}
out="$(entry_out '{"status":1,"mode":"brief","missing":["C1"],"shallow":[],"unserved":[],"unknown":[],"extra":[],"bundle_count":2,"table_count":1}')"
assert_grep "$out" '^질문 줄: 번호 대조 경고 [0-9]+개: ' "entry: 경고가 있으면 질문 줄을 낸다"
assert_eq "$(printf '%s\n' "$out" | grep -c '^번호 대조 경고 [0-9]*개$')" "1" "entry: 기존 개수 줄은 그대로다"
assert_eq "$(printf '%s\n' "$out" | tail -n 3 | head -n 1)" "질문 줄: 번호 대조 경고 1개: 빠진 번호 1" "entry: 질문 줄은 개수 줄 바로 앞이다"
assert_eq "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" "번호 대조 경고 1개" "entry: 개수 줄은 끝에서 둘째다"
out_clean="$(entry_out '{"status":0,"mode":"brief","missing":[],"shallow":[],"unserved":[],"unknown":[],"extra":[],"bundle_count":2,"table_count":2}')"
assert_not_contains "$out_clean" "질문 줄:" "entry: 경고가 없으면 질문 줄이 없다"
assert_eq "$(printf '%s\n' "$out_clean" | tail -n 2 | head -n 1)" "번호 대조 경고 0개" "entry: 경고가 없어도 개수 줄은 그대로다"
finish
