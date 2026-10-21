#!/usr/bin/env bash
# R5 계획 2 — 손으로 따르는 지휘 절차(`references/conducting.md`)의 걸음 · 레포 전용 값 없음 · 가리킴.
# 정적 락이다 — 지휘 세션이 이 절차를 실제로 따르는지는 재지 못한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conducting_reference.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
CD="$SD/references/conducting.md"
RED="$SD/references/redecompose.md"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

[ -f "$CD" ] && ok "conducting.md 가 있다" || { no "conducting.md 가 없다"; finish; exit $?; }
assert_eq "$(grep -cxF '## 손으로 따르는 절차' "$CD" || true)" "1" "손 절차 절 머리가 정확히 하나"
man_of() {  # man_of <파일> — 그 파일의 손 절차 절
  awk '$0=="## 손으로 따르는 절차"{f=1;next} f&&/^## /{exit} f' "$1"
}
MAN="$(man_of "$CD")"
[ -n "$MAN" ] && ok "손 절차 절을 읽었다" || no "손 절차 절이 비었다 — 아래 단언이 공허하다"
assert_eq "$(printf '%s\n' "$MAN" | grep -oE '^[1-9]\. ' | tr -d '. ' | tr '\n' ' ')" "1 2 3 4 5 6 7 8 9 " "걸음 1~9 가 차례로 있다"
step() {  # step <n> [파일] — 손 절차 걸음 n 의 글(다음 번호 걸음 앞까지). 파일이 없으면 conducting.md
  local m="$MAN"
  [ $# -ge 2 ] && m="$(man_of "$2")"
  printf '%s\n' "$m" | awk -v n="$1" 'index($0, n ". ")==1{f=1; print; next} f && /^[1-9]\. /{exit} f'
}
for n in 1 2 3 4 5 6 7 8 9; do
  [ -n "$(step "$n")" ] && ok "걸음 $n 을 읽었다" || no "걸음 $n 이 비었다"
done
for lit in 'control_plane.py show --tasks <로드맵>' '종료 코드 4' 'roadmap_status.py --roadmap-file <로드맵>' '기억에 기대지 않는다'; do
  assert_contains "$(step 1)" "$lit" "걸음 1(맞추기): $lit"
done
for lit in '`브랜치:` 가 여럿이면' '앞 계획이 머지됐으면 기본 브랜치에서' '한 번에 한 에픽씩'; do
  assert_contains "$(step 2)" "$lit" "걸음 2(에픽과 브랜치): $lit"
done
for lit in 'AskUserQuestion' '거절되면 설계 흐름으로 간다' '`epic-handoff.md` 의 에픽 넘김 줄' '다른 세션을 열라고 하지 않는다' '`--bundle <묶음 절대경로>`'; do
  assert_contains "$(step 3)" "$lit" "걸음 3(흐름과 설계): $lit"
done
for lit in 'writing-plans 가 권하는 방식' '설계에 없던 결정' '답 전에는 그 에픽의 구현을 보내지 않으며' '「브랜치 그대로 두기」'; do
  assert_contains "$(step 4)" "$lit" "걸음 4(설계가 정한 뜻): $lit"
done
assert_not_contains "$(step 4)" 'Push 후 PR' "걸음 4: 옛 미리 받은 답(Push 후 PR)이 없다(양성 짝: 「브랜치 그대로 두기」)"
assert_not_contains "$(step 4)" '기다리지 않고' "걸음 4: 계획 검토를 늘 안 기다리는 옛 문면이 없다(양성 짝: 설계에 없던 결정)"
for lit in 'check_bundle_coverage.py --plan' '--acs' '그 에픽만 멈추고' 'check_bundle_coverage.py --impl' '`### <계획 경로>`'; do
  assert_contains "$(step 5)" "$lit" "걸음 5(계획 · 구현): $lit"
done
assert_contains "$(step 6)" '`redecompose.md`' "걸음 6(머지 뒤): 재분해 절차를 가리킨다"
assert_contains "$(step 7)" 'Spec: <에픽 설계문서 레포 상대경로>' "걸음 7: Spec 트레일러"
for lit in '실패 «이름»' '`test_command`' '`repo_defaults.py get review_model --roadmap <로드맵>`' '같은 시각에 돌리지 않는다' '`## 통합 리뷰 인계`' '**리뷰 뒤 반영.**' '머지 직전' '스위트 대조 없음'; do
  assert_contains "$(step 8)" "$lit" "걸음 8(머지 전 확인): $lit"
done
for lit in '끝에서 끝' '브랜치는 지우지 않는다'; do
  assert_contains "$(step 9)" "$lit" "걸음 9(끝): $lit"
done
# spec 리뷰는 지휘 세션이 직접(걸음 3) · 경유 자리는 두 부분 반환(걸음 4) · 메인 체크아웃 · 경유 질문 보호(걸음 2).
# 2026-10-18 재결정 — 한 번뿐인 문장으로 잰다.
once() {  # once <걸음> <문장> — 그 걸음 글에 문장이 정확히 한 번
  assert_eq "$(printf '%s\n' "$(step "$1")" | grep -oF -- "$2" | wc -l | tr -d ' ')" "1" "걸음 $1: 「${2}」 는 정확히 한 번이다"
}
for lit in 'spec-review 도 지휘 세션이 직접 돌린다' '`--bundle` 값이 설계문서 frontmatter `source_interview` 와 다르거나 읽을 수 없으면 리뷰하지 않고 끝나고' '`root=` 가 그 worktree 가 아니면 멈춘다' '다음 세션 줄의 writing-plans 를 직접 따르지 않고' '`## 지휘 기록` 에 한 줄로 커밋한다' '리뷰 원장이 라운드 · 상한을 잇는다' \
           '그다음 메인 체크아웃으로 돌아온다' '「승인 — 계획 담당자에게」' '그리고 같은 턴에 계획 agent 를 보낸다' \
           '승인 줄은 있고 계획은 없는 에픽' '`<SD>`(이 세션이 쓰는 spec-distill 플러그인 폴더의 절대경로)로' \
           'git switch --ignore-other-worktrees <에픽 브랜치>' '지휘 세션이 그 에픽 worktree 에 머문 채 격리 없이 보내고 agent 가 돌아올 때까지 떠나지 않는' \
           '지휘 소식은 brainstorming 메시지에 얹지 않는다'; do
  once 3 "$lit"
done
for old in '턴을 끝낸다' '「여기서 계속」' '붙여 넣지 않아도 된다' '이 턴에는 계획 agent 를 띄우지 않는다'; do
  assert_not_contains "$(step 3)" "$old" "걸음 3: 옛 ①/② 문장 「${old}」 이 없다(양성 짝: 승인 질문 하나 · 같은 턴 계획 agent)"
done
assert_not_contains "$MAN" '절별 승인' "손 절차: superpowers 7.0.0 에 없는 「절별 승인」 이 없다(양성 짝: 설계문서 점검의 질문)"
assert_contains "$(step 2)" '설계문서 점검의 질문' "걸음 2: 사람에게 묻는 단계에 설계문서 점검의 질문"
once 5 '`### <앞 계획 경로>` 아래로 옮긴다'
once 8 '바탕 브랜치를 지우기 전에 위 PR 의 바탕을 기본 브랜치로 바꾼다'
once 1 'agent 를 보내거나 거둘 때마다 상태 계산의 동시 가능 목록과 승인된 설계의 남은 계획을 훑어, 의존 · 같은 파일 겹침 · 기다리는 답이 없는 일은 규모를 알리고 바로 보낸다 — 동시에 돌리는 큰 작업의 권장 수는 기본 3(레포 설정 파일이나 로드맵 머리말의 `parallel_default` 로 바꾼다)이고 상한이 아니다(사용자가 늘린다).'
once 2 '그 브랜치를 체크아웃한 worktree 가 둘 이상이면 쓰지 않고 멈춰 보인다'
once 3 '레포 전용 값 · 계층 · 온톨로지 · 크기 선호'
# 지휘자가 가른 결과 · 판정은 리뷰 엔진의 얼림 울타리 밖(`## 지휘 기록`)에 — 열린 리뷰의 `## 결정 기록` 에 손으로 쓰면 「허가 없이 바뀜」 으로 돌아온다(R2a 계획 2 통합 재리뷰 · R12 §4)
once 4 '가른 결과와 이유는 그 에픽 설계문서 `## 지휘 기록` 에 적는다'
once 4 '사용자 결정 원문을 설계문서 `## 결정 기록` 에 남겨야 하면 갈래가 셋이다 — ① 그 문서의 리뷰가 열려 있으면 그 리뷰의 결정 줄 펜스(`decision-line` — 엔진 `log-decision`)로 쓴다 ② 리뷰 원장이 없으면(리뷰 전) 손으로 쓴다 — 첫 라운드가 기준선으로 받는다 ③ 리뷰가 닫혔으면 `## 결정 기록` 절 끝(마지막 계수 줄 아래)에 손으로 쓴다 — 다음 재리뷰가 그 줄을 기록으로 읽는다(재리뷰를 시작한 뒤에 쓴 줄은 다시 묻는다)'
once 4 '(재리뷰를 시작한 뒤에 쓴 줄은 다시 묻는다). 끝맺음을 건너뛰어 계수 줄이 없거나 계수 줄에 표지가 없는 옛 원장이면 재리뷰가 그 줄을 한 번 묻는다 — 「고친 대로 둠」으로 닫는다.'
assert_contains "$(cat "$RED")" '(재리뷰를 시작한 뒤에 쓴 줄은 다시 묻는다). 끝맺음을 건너뛰어 계수 줄이 없거나 계수 줄에 표지가 없는 옛 원장이면 재리뷰가 그 줄을 한 번 묻는다 — 「고친 대로 둠」으로 닫는다.' "redecompose.md: 닫힌 리뷰 갈래의 같은 단서"
once 4 '리뷰가 열려 있는 문서의 `## 결정 기록` 에는 손으로 쓰지 않는다'
assert_not_contains "$(step 4)" '사용자 원문과 함께 `## 지휘 기록` 에 둔다' "걸음 4: 닫힌 리뷰의 결정 줄을 지휘 기록으로 보내던 옛 ③ 이 없다(양성 짝: 새 ③)"
assert_not_contains "$(step 4)" '`## 결정 기록` 에는 손으로 쓰지 않는다 —' "걸음 4: 범위 없는 절대 금지문이 없다(엔진 · redecompose.md 의 「원장이 없으면 손으로 쓴다」 와 맞춤 — 양성 짝: 세 갈래)"
unsectioned() {  # unsectioned <글> — 절 이름 없이 「설계문서에 적」 는 지시(판정 · 구현 대조처럼 절 머리를 바로 붙인 꼴은 뺀다)
  PYTHONIOENCODING=utf-8 python3 -I -c 'import re, sys
for m in re.finditer(r"설계문서에(\(|\s)(?!`## )", sys.argv[1]):
    print(sys.argv[1][max(0, m.start() - 30):m.end() + 20].replace(chr(10), " "))' "$1"
}
assert_eq "$(unsectioned "$(cat "$CD")")" "" "conducting.md: 설계문서에 적는 지시는 절 이름을 붙인다(지휘 기록 · 판정 — 결정 기록에 손으로 쓰지 않게)"
[ -n "$(unsectioned '가른 결과와 이유는 그 에픽 설계문서에 적는다.')" ] && ok "양성 대조: 절 없는 「설계문서에 적는다」 를 잡는다" || no "양성 대조: 절 없는 「설계문서에 적는다」 를 못 잡는다"
assert_eq "$(unsectioned '그다음 설계문서에 `## 판정` 절을 둔다.')" "" "양성 짝: 절 머리를 바로 붙이면 허용"
once 1 '목록의 완료 표시는 일이 끝났다는 뜻이 아니다'
once 1 '「HH:MM 기준」 을 붙인다 — 조회하지 않은 숫자는 말하지 않는다'
once 1 '돌고 있는 큰 작업이 권장 수보다 적으면 남은 계획 · 정리 일 · 미룸 행 가운데 기다리는 답이 없는 일을 찾아 보내거나 제안한다'
once 8 '백그라운드 agent 의 전체 스위트와 같은 잠금 하나'
once 3 '다른 길로 그 에픽 worktree 에 머문 채 보낼 때는 돌아오지 않는다'
once 3 '보내기 전에 에픽 worktree 는 그 브랜치를 놓는다'
# 승인 뒤 차례: 승인 줄 커밋 → 메인 체크아웃으로 → 같은 턴에 계획 agent(지휘자 수리 1). 첫 출현 위치로 잰다.
approval_order() {  # approval_order <글> — 셋이 이 순서로 있으면 yes
  PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
ks = ["`## 지휘 기록` 에 한 줄로 커밋한다", "그다음 메인 체크아웃으로 돌아온다", "그리고 같은 턴에 계획 agent 를 보낸다"]
ix = [t.find(k) for k in ks]
print("yes" if min(ix) >= 0 and ix == sorted(ix) else "no")' "$1"
}
assert_eq "$(approval_order "$(step 3)")" "yes" "걸음 3: 승인 줄 커밋 → 메인 체크아웃으로 → 같은 턴 계획 agent 순서"
assert_eq "$(approval_order '그다음 메인 체크아웃으로 돌아온다. `## 지휘 기록` 에 한 줄로 커밋한다. 그리고 같은 턴에 계획 agent 를 보낸다.')" "no" "양성 대조: 메인으로 먼저 돌아오면 no"
assert_eq "$(approval_order '그리고 같은 턴에 계획 agent 를 보낸다. `## 지휘 기록` 에 한 줄로 커밋한다. 그다음 메인 체크아웃으로 돌아온다.')" "no" "양성 대조: 기록 전에 계획 agent 를 보내면 no"
assert_eq "$(approval_order '`## 지휘 기록` 에 한 줄로 커밋한다. 그다음 메인 체크아웃으로 돌아온다. 그리고 같은 턴에 계획 agent 를 보낸다.')" "yes" "양성 짝: 커밋 → 메인 → 계획 agent 면 yes"
assert_not_contains "$(step 3)" '끝나면 메인 체크아웃으로 돌아온다' "걸음 3: 승인 줄 커밋 전에 메인으로 돌아오는 옛 문장이 없다(양성 짝: 위 순서)"
COMPACT="$(grep '^\*\*/compact\.\*\*' "$CD" || true)"
for lit in '이 절차 파일(conducting.md)을 다시 읽고' '지휘를 걸음 1 부터 잇는다' '압축 뒤 이 세션에 칠'; do
  assert_contains "$COMPACT" "$lit" "/compact 줄: 이어 갈 줄 — $lit"
done
for lit in '(a) 사람에게 보일 쉬운 요약' '내부 기호는 괄호에만' 'writing-plans 가 끝에 묻는 계획 검토' '선택지의 수 · 순서 · 라벨(돌려줄 값) · skill 자신의 「(권장)」 표시와 사용자 답은 글자 그대로' '「고르면 무엇이 달라지나」(그대로 두면 · 고치면)' '「지휘자 의견:」 한 줄' '원문은 늘 붙인다' '사용자 답은 글자 그대로 같은 agent 에 돌려보내 이어 가게 한다' '이유를 설계문서 `## 지휘 기록` 에 적는다'; do
  once 4 "$lit"
done
for lit in '그 리뷰 게이트 질문에 섞지 않고' '질문 문장 앞머리에 에픽 이름' '따로 된 메시지로' 'worktree 를 떠날 수 있는지' '다른 에픽의 spec 리뷰는 그 에픽 담당 agent 를 거쳐' '하니스의 worktree 들어가기(경로 지정)'; do
  once 2 "$lit"
done
assert_contains "$(step 2)" '메인 체크아웃' "걸음 2: 메인 체크아웃에 머문다"
assert_file_grep "$CD" '^\*\*/compact\.\*\* 에픽 하나의 spec 리뷰가 끝나 계획 agent 를 보낸 직후처럼' "/compact 줄: 끊기 좋은 자리는 spec 리뷰가 끝나 계획 agent 를 보낸 직후"
assert_contains "$(step 5)" '다른 에픽은 계속' "걸음 5: 한 에픽이 멈춰도 다른 에픽은 계속"

# 부재 락 — 부정된 개념으로 잰다. 판정은 함수라 변이 대조가 같은 함수를 부른다.
hit() {  # hit <정규식> — 표준입력에서 맞은 글을 줄마다 낸다
  PYTHONIOENCODING=utf-8 python3 -I -c 'import re,sys
t = sys.stdin.read()
for m in re.finditer(sys.argv[1], t):
    print(m.group(0))' "$1"
}
forbid_23() {  # 걸음 2~3 글: 세션을 새로 열게 하는 말(명시 부정문 제외)
  local t="${1//다른 세션을 열라고 하지 않는다/}"
  printf '%s\n' "$t" | hit '세션[^\n]{0,6}[열연]|다음 세션에서|/new|새 세션|세션을 따로'
}
forbid_4() {  # 걸음 4 글: 계획 검토 무대기 · Push/PR 의 다른 주체 · 실행 방식 고정
  local t="${1//Push 와 PR 은 지휘 세션이 구현 대조(5) 뒤에 한다/}"
  printf '%s\n' "$t" | hit '기다리지 않|Push|푸시|subagent-driven|executing-plans'
}
forbid_always_method() {  # 줄에 «언제나/항상» 과 실행 방식 이름이 함께
  printf '%s\n' "$1" | grep -E '언제나|항상' | grep -E 'subagent|executing-plans|인라인|inline' || true
}
forbid_5() {  # 걸음 5 글: 한 에픽이 막히면 다른 에픽도 멈춘다
  printf '%s\n' "$1" | hit '다른 에픽[^\n]{0,8}멈춘'
}
# 걸음 4 에서 문면을 돌려보내도 되는 문장은 이 하나뿐이다(두 부분 반환) — 문장째 허용한다.
ALLOW_B='적어 준 답이 없는 자리(writing-plans 가 끝에 묻는 계획 검토 등)에서 agent 는 멈추고 (a) 사람에게 보일 쉬운 요약(무엇을 정하나 · 고르면 무엇이 달라지나 · 배경, 내부 기호는 괄호에만)과 (b) skill 이 낸 문면 · 선택지 원문을 함께 돌려보낸다.'
forbid_relay() {  # 걸음 3 · 4 글: 게이트 문면을 돌려보내는 중계(옛 결정). 허용 문장 하나는 문장째 뺀다
  local t="${1//$'\n'/ }"
  t="${t//"$ALLOW_B"/}"
  printf '%s\n' "$t" | hit '문면[^\n]{0,20}돌려보[내낸]'  # 「돌려보낸다」의 낸 은 내 와 다른 글자다
}
forbid_agent_review() {  # 걸음 3 글: agent 가 spec-review 를 맡는 문장(어순 무관) · 게이트 문면 중계(옛 결정)
  local t="${1//$'\n'/ }"
  printf '%s\n' "$t" | sed 's/\. /.\
/g' | grep -E '(agent|에이전트).*spec-review|spec-review.*(agent|에이전트)' || true
  forbid_relay "$t"
}
forbid_2_main() {  # 걸음 2 글: 메인 체크아웃에서 부르기를 권하는 옛 문장(양성 짝: 「worktree 를 떠날 수 있는지」 정확히 한 번)
  printf '%s\n' "$1" | hit '메인 체크아웃[^.]{0,20}권'
}
S23="$(step 2; step 3)"
assert_eq "$(forbid_23 "$S23")" "" "걸음 2~3: 세션을 새로 열게 하는 말이 없다"
assert_eq "$(forbid_4 "$(step 4)")" "" "걸음 4: 계획 검토 무대기 · 허용 문장 밖 Push · 실행 방식 고정이 없다"
assert_eq "$(forbid_always_method "$MAN")" "" "손 절차: 「언제나/항상」+실행 방식 고정이 없다"
assert_eq "$(forbid_5 "$(step 5)")" "" "걸음 5: 다른 에픽까지 멈추는 말이 없다"
assert_eq "$(forbid_agent_review "$(step 3)")" "" "걸음 3: agent 가 spec-review 를 맡거나 게이트 문면을 그대로 중계하는 말이 없다(음성 대조)"
assert_eq "$(forbid_relay "$(step 4)")" "" "걸음 4: 허용 문장 밖에서 게이트 문면을 돌려보내는 중계가 없다(음성 대조)"
assert_eq "$(printf '%s\n' "$(step 4)" | grep -oF -- "$ALLOW_B" | wc -l | tr -d ' ')" "1" "걸음 4: 허용 문장(두 부분 반환)이 정확히 한 번 있다 — 허용 목록이 낡지 않았다"
assert_eq "$(forbid_2_main "$(step 2)")" "" "걸음 2: 메인 체크아웃에서 부르기를 권하는 옛 문장이 없다"
for lit in '/new 로 에픽 worktree 세션을 연다' '에픽마다 세션을 따로 열어' '새 세션에서 이어 간다' '사용자가 다른 세션을 열어 진행' '다음 세션에서 이어 간다' '에픽마다 세션을 연다'; do
  [ -n "$(forbid_23 "$S23 $lit")" ] && ok "양성 대조(2~3): 「${lit}」 를 잡는다" || no "양성 대조(2~3): 「${lit}」 를 못 잡는다"
done
for lit in '계획 검토는 기다리지 않는다' 'Push 하고 PR 만들기' '푸시 후 PR' 'Push 와 PR 은 지휘 세션이 아니라 담당 agent 가 한다' '실행 방식은 subagent-driven 이다' '실행 방식은 executing-plans 다'; do
  [ -n "$(forbid_4 "$(step 4) $lit")" ] && ok "양성 대조(4): 「${lit}」 를 잡는다" || no "양성 대조(4): 「${lit}」 를 못 잡는다"
done
for lit in '실행 방식은 언제나 subagent-driven 이다' '항상 인라인으로 실행한다'; do
  [ -n "$(forbid_always_method "$MAN"$'\n'"$lit")" ] && ok "양성 대조(방식): 「${lit}」 를 잡는다" || no "양성 대조(방식): 「${lit}」 를 못 잡는다"
done
for lit in '다른 에픽도 모두 멈춘다' '다른 에픽도 전부 멈춘다' '다른 에픽도 멈춘다'; do
  [ -n "$(forbid_5 "$(step 5) $lit")" ] && ok "양성 대조(5): 「${lit}」 를 잡는다" || no "양성 대조(5): 「${lit}」 를 못 잡는다"
done
for lit in 'spec-review 부터는 담당 agent 가 맡는다.' '담당 agent 가 게이트 문면을 그대로 돌려보내고 멈춘다.' 'agent 가 /spec-distill:spec-review 를 돌린다.' '담당 에이전트가 spec-review 를 돌린다.' 'spec-review 는 하위 에이전트에게 맡긴다.' '게이트 문면과 선택지를 돌려보내고 멈춘다.'; do
  [ -n "$(forbid_agent_review "$(step 3) $lit")" ] && ok "양성 대조(3): 「${lit}」 를 잡는다" || no "양성 대조(3): 「${lit}」 를 못 잡는다"
done
for lit in '담당 agent 는 게이트 문면과 선택지를 그대로 돌려보내고 멈춘다.' '(b) skill 이 낸 문면을 돌려보낸다.'; do
  [ -n "$(forbid_relay "$(step 4) $lit")" ] && ok "양성 대조(4 중계): 「${lit}」 를 잡는다" || no "양성 대조(4 중계): 「${lit}」 를 못 잡는다"
done
for lit in '메인 체크아웃에서 부르기를 권한다.' '메인 체크아웃으로 옮기기를 권한다.'; do
  [ -n "$(forbid_2_main "$(step 2) $lit")" ] && ok "양성 대조(2 메인): 「${lit}」 를 잡는다" || no "양성 대조(2 메인): 「${lit}」 를 못 잡는다"
done
# 대조 변이(실파일 사본): 지휘 세션 문장을 옛 담당 agent 문장으로 되돌린 걸음 3
sed 's/spec-review 도 지휘 세션이 직접 돌린다/spec-review 부터는 그 에픽의 담당 agent 가 그 에픽 worktree 에서 맡는다/' "$CD" > "$T/m3.md"
cmp -s "$CD" "$T/m3.md" && no "변이 사본(3)이 원문과 같다 — 아래 대조가 공허하다" || ok "변이 사본(3)이 원문과 달라졌다"
M3="$(step 3 "$T/m3.md")"
[ -n "$M3" ] && ok "변이 사본(3)의 걸음 3 을 읽었다" || no "변이 사본(3)의 걸음 3 이 비었다 — 아래 대조가 공허하다"
[ -n "$(forbid_agent_review "$M3")" ] && ok "변이(3): 옛 담당 agent 문장으로 되돌리면 부재 락이 잡는다" || no "변이(3): 되돌려도 부재 락이 못 잡는다"
assert_eq "$(printf '%s\n' "$M3" | grep -oF -- 'spec-review 도 지휘 세션이 직접 돌린다' | wc -l | tr -d ' ')" "0" "변이(3): 되돌리면 지휘 세션 문장이 사라진다(위 정확히 한 번 단언이 잡는다)"

# 판정 절 잇기: `### <계획 경로>` 가 쓰라는 말이어야 한다 — 같은 문장에 부정이 없다.
assert_eq "$(step 5 | hit '### <계획 경로>`(?:(?!\. )[^\n])*(않|쓰지|말고|금지|안 )')" "" "걸음 5: ### <계획 경로> 로 잇는 문장에 부정이 없다"
[ -n "$(printf '%s\n' '그 아래 `### <계획 경로>` 는 쓰지 않는다. 다음' | hit '### <계획 경로>`(?:(?!\. )[^\n])*(않|쓰지|말고|금지|안 )')" ] && ok "양성 대조: ### <계획 경로> 뒤 부정을 잡는다" || no "양성 대조: ### <계획 경로> 뒤 부정을 못 잡는다"

# `--acs` 는 «--plan 문장» 안에 있어야 한다(--impl 문장의 것으로 갈음 못 한다).
acs_in_plan() {
  local s="${1#*check_bundle_coverage.py --plan}"
  s="${s%%. *}"
  case "$s" in *'--acs'*) printf 'yes\n';; *) printf 'no\n';; esac
}
assert_eq "$(acs_in_plan "$(step 5)")" "yes" "걸음 5: --plan 문장 안에 --acs"
# 대조는 걸음 5 글과 무관한 합성 입력으로 한다 — 지운 절이 없어도 이 대조만 공허해지지 않는다.
SYN_NO='x check_bundle_coverage.py --plan <설계문서> <계획> 을 돌려 더한다. 다음 check_bundle_coverage.py --impl <설계문서> <보고> 같은 `--acs` 를 준다.'
SYN_OK='x check_bundle_coverage.py --plan <설계문서> <계획> 을 돌려 더한다 — `--acs` 를 준다. 다음 check_bundle_coverage.py --impl <설계문서> <보고> 를 돌린다.'
assert_eq "$(acs_in_plan "$SYN_NO")" "no" "양성 대조: --plan 문장에 --acs 가 없고 --impl 문장에만 있으면 no"
assert_eq "$(acs_in_plan "$SYN_OK")" "yes" "양성 짝: --plan 문장에 --acs 가 있으면 yes"

# 레포 전용 값 · 루트 토큰 · references/ 꼴 가리킴 — 줄마다 낸다.
banned() {
  python3 -I - "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
pats = [r"origin/main", r"(?<![A-Za-z])main(?![A-Za-z])", r"(?<![A-Za-z])opus(?![A-Za-z])",
        r"(?<![A-Za-z])fable(?![A-Za-z])", r"plugins/spec-distill", r"docs/superpowers", r"feature/",
        r"(?<![A-Za-z])master(?![A-Za-z])", r"(?<![A-Za-z])sonnet(?![A-Za-z])", r"(?<![A-Za-z])haiku(?![A-Za-z])",
        r"plugins/", r"shared/tests", r"\.superpowers/", r"DEVBREW_", r"\$\{CLAUDE_PLUGIN_ROOT\}", r"references/[A-Za-z0-9_.-]+\.md",
        r"worktree 의 spec-distill"]
for i, line in enumerate(text.splitlines(), 1):
    for p in pats:
        if re.search(p, line):
            print("%d: %s — %s" % (i, p, line.strip()[:80]))
PY
}
assert_eq "$(banned "$CD")" "" "레포 전용 값 · 루트 토큰 · references/ 꼴 가리킴이 없다"
for lit in 'origin/main' 'review_model: opus' 'python3 plugins/spec-distill/scripts/x.py' '${CLAUDE_PLUGIN_ROOT}/scripts' \
           'references/epic-handoff.md' 'feature/roadmap-x' 'main 에서 만든다' '.superpowers/sdd/x' \
           'origin/master' 'review_model: sonnet' 'haiku 로 부른다' 'plugins/other/x.py' 'shared/tests/x.sh' \
           '줄 안의 플러그인 루트 변수는 그 에픽 worktree 의 spec-distill 플러그인 폴더로'; do
  { cat "$CD"; printf '%s\n' "$lit"; } > "$T/mut.md"
  [ -n "$(banned "$T/mut.md")" ] && ok "양성 대조: 「${lit}」 를 넣으면 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done

# 가리키는 skill 은 실재한다(아직 없는 skill 을 가리키는 릴리스 금지 — 설계 §11).
n=0
for s in $(grep -ohE 'spec-distill:[a-z][a-z-]*' "$CD" "$SD/references/epic-handoff.md" "$RED" "$SD/references/proceed-gate.md" | sed 's/^spec-distill://' | LC_ALL=C sort -u); do
  n=$((n+1))
  [ -f "$SD/skills/$s/SKILL.md" ] && ok "가리키는 skill 이 있다: $s" || no "없는 skill 을 가리킨다: $s"
done
[ "$n" -ge 1 ] && ok "skill 이름을 ${n}개 읽었다" || no "skill 이름을 하나도 못 읽었다 — 위 검사가 공허하다"

# 고아 방지 — 재분해 6 이 손 절차를 가리킨다.
assert_file_grep "$RED" '\$\{CLAUDE_PLUGIN_ROOT\}/references/conducting\.md' "재분해 6 이 손 절차를 가리킨다"
finish
