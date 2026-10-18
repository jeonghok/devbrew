#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py shared/docreview/references/reviewing-document.md
# AC41 — 기호 없는 요약을 가진 픽스처로 돌린 게이트 렌더의 모든 줄에 괄호 밖 내부 기호(지적 id · AC 번호 · §)가 없다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_state.py"; echo "shared/docreview/references/reviewing-document.md"; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"

# 괄호 밖 글자만 남긴다 — 짝이 맞는 ( … ) 와 「…」 안은 지운다(선택지 이름 인용은 사람 말이다).
outside_parens() { python3 -I -c '
import re, sys
for line in sys.stdin.read().split("\n"):
    prev = None
    while prev != line:
        prev = line
        line = re.sub(r"\([^()]*\)", "", line)
    print(line)
'; }
SYM_RE='[0-9a-f]{8}#r[0-9]+\.[0-9]+|(^|[^A-Za-z])AC[0-9]+|§'

render_all_rows() {   # 모든 렌더러 행이 한 번씩 서는 원장을 만든다(정할 것 · 막힌 질문 · 미적용 fix · 만료 · 상한)
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || return 1
  seed_findings "$d" "[$F_DEC,$F_FIX,$F_ASK]"
  local s="$d/s.json"; snap "$FX/design-sample.md" "$s"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null
  echo "$d"
}
d="$(render_all_rows)" || { no "AC41: 원장을 만들지 못했다"; finish; }
out="$(py docreview_state.py gate --state-dir "$d" --render)"
leak="$(printf '%s\n' "$out" | outside_parens | grep -nE "$SYM_RE" || true)"
assert_eq "$leak" "" "AC41: 게이트 렌더의 괄호 밖에 지적 id · AC 번호 · § 가 없다"
# 양성 대조 — 렌더 안에 지적 id 가 «있기는» 하다(괄호 안). 없으면 이 락은 공허하다.
assert_contains "$out" "aaaa0001#r1.1" "AC41 양성 짝: 지적 id 는 괄호 안에 있다"
# 계측기 양성 대조 — 괄호 밖 id 한 줄을 넣으면 잡는다.
probe="$(printf '%s\n' "- 이 답을 기다리는 수정: bbbb0001#r1.1" | outside_parens | grep -cE "$SYM_RE")"
assert_eq "$probe" "1" "AC41 계측기: 괄호 밖 id 는 잡힌다"
rm -rf "$d"

REF="$REPO_ROOT/shared/docreview/references/reviewing-document.md"
body="$(grep -vE '^#' "$REF")"
assert_contains "$body" "질문 · 선택지 이름에 AC 번호 · 지적 id · § 를 쓰지 않고 설명 괄호에만 쓴다" "AC41: 게이트 절 규칙 문장이 절차서 본문에 있다"
assert_contains "$body" "--extra-approval-source" "AC40: 절차서가 출처 플래그를 가르친다"
assert_not_contains "$body" "사용자 자신의 문구" "AC40: 옛 승인 문면이 절차서에 없다"
finish
