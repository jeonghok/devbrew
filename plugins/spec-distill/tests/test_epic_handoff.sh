#!/usr/bin/env bash
# guards: plugins/spec-distill/references/epic-handoff.md
#
# R3 AC2 · AC10 — 에픽 넘김 줄(`references/epic-handoff.md`)이 묶음을 첨부하고 로드맵 속 위치를 밝히며,
# brief 다음 세션 줄과 같은 지시(번호째 읽기 · 번호 대조 · source_interview · --bundle · --plan · --impl)를 싣는가.
# 정적 락이다 — 지휘 세션이 이 줄을 실제로 치환해 쓰는지는 재지 못한다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
EH="$ROOT/plugins/spec-distill/references/epic-handoff.md"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/epic-handoff.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
MARK='**에픽 넘김 줄**'
[ -f "$EH" ] && ok "epic-handoff.md 가 있다" || { no "epic-handoff.md 가 없다"; finish; exit $?; }
assert_eq "$(grep -cxF "$MARK" "$EH" || true)" "1" "AC2: 표지 줄이 정확히 하나"
LINE="$(awk -v m="$MARK" '$0==m{f=1;next} f&&NF{print;exit}' "$EH")"
case "$LINE" in
  '> `'*'`') ok "AC2: 표지 아래 첫 줄이 인용 줄이다" ;;
  *) no "AC2: 표지 아래 첫 줄이 인용 줄이 아니다: $LINE" ;;
esac
ONE="$(printf '%s' "$LINE" | sed -e 's/^> `//' -e 's/`$//')"
case "$ONE" in
  "@<bundle-abs> 이 에픽 묶음으로 Skill superpowers:brainstorming 을 시작하라."*) ok "AC2: 줄이 @<bundle-abs> 첨부로 시작해 brainstorming 을 부른다" ;;
  *) no "AC2: 줄의 머리가 다르다: $ONE" ;;
esac
for n in '승인된 로드맵 <roadmap-rel> 의 에픽 <epic-id> 다' '번호째' '## 번호 대조 표' 'source_interview 에 <bundle-rel>' \
         '--bundle <bundle-rel>' 'check_bundle_coverage.py --plan' '## Acceptance Criteria 의 AC 목록' \
         'AC1 · AC2 … 처럼 번호를 단다' '구현됨 · 미룸 · 빠짐' 'git 이 추적하지 않는 파일' '## 미룸 표' 'check_bundle_coverage.py --impl' \
         '게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다'; do
  assert_contains "$ONE" "$n" "AC2 · AC10: 에픽 넘김 줄에 「${n}」"
done
assert_not_contains "$ONE" "보다 이 순서가 우선한다" "에픽 넘김 줄도 외부 지시를 덮어쓰지 않는다"
pos() { WIN="$ONE" A="$1" python3 -I -c 'import os; print(os.environ["WIN"].find(os.environ["A"]))'; }
a="$(pos 'Skill superpowers:brainstorming')"; b="$(pos 'spec-distill:spec-review')"; c="$(pos 'writing-plans')"
[ "$a" -ge 0 ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && ok "순서: brainstorming → spec-review → writing-plans" || no "순서가 다르다(${a} · ${b} · ${c})"
names_ok() { LINE="$1" python3 -I -c '
import os, re
bad = [x for x in re.findall(r"<([^<>]+)>", os.environ["LINE"])
       if x not in ("bundle-abs", "bundle-rel", "roadmap-rel", "epic-id")]
print("ok" if not bad else "no " + " ".join(bad))'; }
assert_eq "$(names_ok "$ONE")" "ok" "AC2: 자리표는 넷(bundle-abs · bundle-rel · roadmap-rel · epic-id)뿐"
assert_eq "$(names_ok "$ONE <spec>")" "no spec" "양성 대조: 모르는 자리표를 잡는다"
assert_file_grep "$EH" '치환되지 않은 자리표가 남거나 경로에 공백이 있으면 쓰지 않는다' "AC2: 자리표 규칙"
assert_file_grep "$EH" '\$\{CLAUDE_PLUGIN_ROOT\}' "줄의 스크립트 경로는 플러그인 루트 기준이고 치환 대상이다"
assert_eq "$(grep -c '^> `@<' "$EH" || true)" "1" "인용 줄이 하나뿐이다(표지 밖에 둘째 정의가 없다)"
# R5 계획 2 AC31 — 흐름을 고정하지 않는다 · 재분해 보고 · 고른 실행 방식 · 있는 것 검토 · 연계 · 레포 전용 값
for n in '흐름: 칸이 있으면 brainstorming 대신 그 칸의 흐름' '설계문서 대신 산출물: 칸의 파일을 낸다' \
         '묶음을 다시 나눌 근거가 보이면' '${CLAUDE_PLUGIN_ROOT}/references/redecompose.md' \
         '고른 실행 방식의 마지막 전체 리뷰(조사 에픽은 산출물의 AC 대조)' \
         '## 있는 것 검토 절' '사용자가 승인한 뒤에만' '## 상류 · 하류 연계 절' '레포 전용 값은 박지 말고'; do
  assert_contains "$ONE" "$n" "AC31: 에픽 넘김 줄에 「${n}」"
done
assert_not_contains "$ONE" 'SDD 의 마지막 전체 리뷰' "AC31: 실행 방식을 SDD 로 고정하지 않는다(양성 짝: 고른 실행 방식)"
assert_not_contains "$ONE" '묶음을 다시 나누지 않는다' "AC31: 나누지 말라는 금지 대신 재분해 보고(양성 짝: 근거가 보이면)"
assert_contains "$ONE" '모델이 판단해 맞추거나 건너뛰고 그 이유를 보고한다' "AC31: 흐름에 없는 단계는 모델이 판단하고 이유를 보고한다"
assert_not_contains "$ONE" '그 흐름이 정한 대로 한다' "AC31: 순환 문구가 없다(양성 짝: 위 줄)"
finish
