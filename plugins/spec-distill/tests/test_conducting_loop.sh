#!/usr/bin/env bash
# R5 계획 3 — 지휘 순환(`references/conducting.md` 의 `## 지휘 순환`): 걸음 1~7 · 다섯 칸 · 걸음별 장치 · 끝 절은 손 절차(AC16).
# 정적 락이다 — 지휘 세션이 실제로 따르는지는 재지 못한다(그것은 계획 끝의 관측표).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conducting_loop.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
CD="$ROOT/plugins/spec-distill/references/conducting.md"
LOOP="$(awk '$0=="## 지휘 순환"{f=1;next} f&&/^## /{exit} f' "$CD")"
[ -n "$LOOP" ] && ok "지휘 순환 절을 읽었다" || { no "지휘 순환 절이 없다"; finish; exit $?; }
assert_eq "$(grep -E '^## ' "$CD" | tail -1)" "## 손으로 따르는 절차" "끝 절은 손으로 따르는 절차다(AC16)"
assert_eq "$(printf '%s\n' "$LOOP" | grep -E '^### [1-7]\. ' | sed 's/^### \([1-7]\)\..*/\1/' | tr '\n' ' ')" "1 2 3 4 5 6 7 " "걸음 1~7 이 차례로 있다"
step() { printf '%s\n' "$LOOP" | awk -v n="$1" 'index($0, "### " n ". ")==1{f=1;next} f&&/^### /{exit} f'; }
for n in 1 2 3 4 5 6 7; do
  for cell in '- 기본값:' '- 판단:' '- 부를 skill:' '- 기록:' '- 기계 상태:'; do
    assert_eq "$(step "$n" | grep -cF -- "$cell" || true)" "1" "걸음 ${n}: 「${cell}」 칸이 하나"
  done
done
once() { assert_eq "$(step "$1" | grep -oF -- "$2" | wc -l | tr -d ' ')" "1" "걸음 ${1}: 「${2}」 정확히 한 번"; }
for lit in 'control_plane.py show --tasks <로드맵>' 'ledger claim --roadmap <로드맵> --session <세션>' '읽기 전용으로 보이며' \
           '덮어쓰지 않는다' '주인을 믿고 캐시를 고친 뒤 알린다' '놀고 있는 agent 는 내린다' '기억에 기대지 않는다' \
           'ledger orphans' 'ledger version'; do once 1 "$lit"; done
for lit in '「지금 답할 수 있나」' '배경과 함께 하나씩' '첫 줄에 에픽 이름' '그 답에 기대는 일' '무관하다고 본 이유를 적는다' \
           '그 리뷰 게이트의 질문 호출에 섞지 않고' 'ledger audit' 'brainstorming 을 거친다'; do once 2 "$lit"; done
for lit in '한 번에 한 에픽씩' '다른 세션을 열라는 줄을 주지 않는다' '`AskUserQuestion` 으로 승인받는다' '`epic-handoff.md`' \
           'worktree-path --name <이름>' '하니스의 새 worktree 만들기를 쓸 수 없어서' '옮기기 전에 지금 자리의 쓰기(커밋 포함)를 끝낸다' \
           '진입 사전 검사 줄의 `root=` 가 그 worktree 인지 확인한 뒤 리뷰한다' '리뷰 원장이 라운드 · 상한을 잇는다' \
           'ledger record --spec <설계문서> --approval' '규모(몇 agent · 무엇)를 알린다'; do once 3 "$lit"; done
for lit in '실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.' \
           '계획을 쓴 agent 가 스스로 가르지 않는다' '답 전에는 그 에픽의 구현을 보내지 않는다' '그 에픽만 멈추고' '다른 에픽은 계속한다' \
           'ledger rulings' '판정 줄 — 셀 수 없음' 'check_bundle_coverage.py --impl' 'ledger write-sections' 'ledger flush' '같은 worktree 에 두 writer 를 두지 않는다'; do once 4 "$lit"; done
for lit in 'merge_check.py run --roadmap <로드맵> --branch <브랜치> --keep-merged' 'ledger review-pack' \
           '`review_model`' '「이 PR 이 고침」 · 「뒤 에픽이 고침」' '`## 통합 리뷰 인계`' 'PR 하나에 두 번까지' '머지는 사용자가 한다' '3(검사 불가)이면 사유를 그대로 보이고 그 PR 의 머지 준비를 멈춘다'; do once 5 "$lit"; done
for lit in 'superpowers:systematic-debugging' 'superpowers:verification-before-completion' 'superpowers:receiving-code-review'; do
  assert_contains "$(step 5)" "$lit" "걸음 5: $lit"
done
for lit in '직접 merge 하지 않는다' '다음 task 경계에서 merge 하라고' '그 에픽만 멈추고 알린다' '`redecompose.md`' '브랜치는 지우지 않는다' 'ledger pending' '맡을 에픽을 제안하고' '이슈를 새로 만드는 것은 그때마다 묻는다'; do once 6 "$lit"; done
for lit in '끝에서 끝 확인' '로드맵 시작 커밋부터' '그 사실을 알린다' 'ledger release'; do once 7 "$lit"; done
COMPACT="$(printf '%s\n' "$LOOP" | awk '$0=="### /compact 시점"{f=1;next} f&&/^### /{exit} f')"
assert_contains "$COMPACT" '`/compact` 와 `/spec-distill:epic-conductor <로드맵>`' "/compact: 두 줄"
assert_contains "$COMPACT" '커밋하고 기계 상태를 저장한 뒤' "/compact: 저장이 먼저"
ALERT="$(printf '%s\n' "$LOOP" | awk '$0=="### 알림"{f=1;next} f&&/^### /{exit} f')"
assert_contains "$ALERT" '멈췄을 때와 모두 끝났거나 더 갈 일이 없을 때만' "알림: 두 경우만"
# 순서: 옮겨 간 뒤 root= 확인이 spec-review 부르기보다 먼저(같은 문장 안)
order="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
a, b = t.find("`pwd` 와 `git rev-parse --show-toplevel` 이 그 worktree 인지 보고"), t.find("확인한 뒤 리뷰한다")
print("yes" if 0 <= a < b else "no")' "$(step 3)")"
assert_eq "$order" "yes" "걸음 3: 위치 확인 → root= 확인 → 리뷰 순서"
# 순서: ① · ② 면 계획 agent 를 보낸 뒤에야 턴을 끝낸다(다음 에픽으로 같은 턴에 가지 않는다)
order2="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
a, b = t.find("계획 agent 를 보내고 기록을 커밋하고 기계 상태를 저장한 뒤"), t.find("턴을 끝낸다")
print("yes" if 0 <= a < b and t.count("턴을 끝낸다") == 1 else "no")' "$(step 3)")"
assert_eq "$order2" "yes" "걸음 3: 계획 agent 보내기 → 턴을 끝낸다 순서"
assert_eq "$(printf '%s\n' "$LOOP" | grep -oF -- '설계문서 없이 산출물만 내는 에픽이면 같은 절(지휘 기록 · 판정 · 구현 대조)을 그 산출물 파일에 둔다' | wc -l | tr -d ' ')" "1" "지휘 순환: 설계문서 없는 에픽의 기록 자리"
assert_eq "$(step 3 | grep -oF -- '브랜치나 worktree 가 이미 있으면(압축 뒤 다시 부른 경우 등) 새로 만들지 않고 그것을 쓴다' | wc -l | tr -d ' ')" "1" "걸음 3: 이미 있는 worktree 는 다시 만들지 않는다"
assert_eq "$(step 7 | grep -cF -- '끝에서 끝으로 걸어 본 결과' || true)" "1" "걸음 7: 기록 칸의 결과 문구"
assert_not_contains "$ALERT" '보고 있' "알림: 사용자가 보고 있을 때의 동작을 단정하지 않는다(실측 없음)"
[ -n "$(printf '%s\n' '사용자가 보고 있으면 보내지 않는다' | grep -F '보고 있' || true)" ] && ok "양성 대조: 「보고 있」 를 잡는다" || no "양성 대조: 「보고 있」 를 못 잡는다"
# 부재 — 다른 세션을 열게 하는 말 · 옛 미리 받은 답 · 플러그인 루트 토큰
forbid() { local t="${1//다른 세션을 열라는 줄을 주지 않는다/}"; t="${t//세션을 새로 열지 않고/}"; printf '%s\n' "$t" | grep -nE '세션을 (새로 )?열어|/new 로|새 세션에서|Push 후 PR|계획 검토는 기다리지 않' || true; }
assert_eq "$(forbid "$LOOP")" "" "지휘 순환: 세션을 새로 열게 하는 말 · 옛 미리 받은 답이 없다"
for lit in '새 세션에서 이어 간다' '에픽마다 세션을 새로 열어' 'Push 후 PR 을 고른다'; do
  [ -n "$(forbid "$lit")" ] && ok "양성 대조: 「${lit}」 를 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done
assert_not_contains "$LOOP" 'CLAUDE_PLUGIN_ROOT' "지휘 순환: 플러그인 루트 토큰 없음(<SD>)"
# 지휘 순환이 부르는 `ledger <명령>` 이름은 모두 conductor_ledger.COMMANDS 의 키다(Ruling R15)
LEDGER_KEYS="$(PYTHONDONTWRITEBYTECODE=1 python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import conductor_ledger
print("\n".join(sorted(conductor_ledger.COMMANDS)))' "$ROOT/plugins/spec-distill/scripts")"
unknown_ledger_cmds() {  # unknown_ledger_cmds <본문> — COMMANDS 에 없는 `ledger <명령>` 을 한 줄씩
  printf '%s\n' "$1" | grep -oE '(conductor_)?ledger(\.py)? [a-z][a-z_-]*' | sed -E 's/^(conductor_)?ledger(\.py)? //' | sort -u \
    | while IFS= read -r c; do printf '%s\n' "$LEDGER_KEYS" | grep -qxF -- "$c" || printf '%s\n' "$c"; done
}
WHOLE="$(cat "$CD")"
assert_eq "$(unknown_ledger_cmds "$WHOLE")" "" "conducting.md 전체의 ledger 명령 이름은 모두 COMMANDS 의 키다"
assert_contains "$(printf '%s\n' "$WHOLE" | grep -oE '(conductor_)?ledger(\.py)? [a-z][a-z_-]*' | sort -u)" "conductor_ledger.py worktree-path" "추출이 worktree-path 줄을 본다"
mutated="$(printf '%s\n' "$WHOLE" | sed 's/conductor_ledger.py worktree-path/conductor_ledger.py nosuch-cmd/')"
assert_eq "$(unknown_ledger_cmds "$mutated")" "nosuch-cmd" "변이: worktree-path 이름을 바꾸면 잡는다"
assert_contains "$LEDGER_KEYS" "claim" "COMMANDS 키를 읽었다"
assert_eq "$(unknown_ledger_cmds 'ledger nosuchcmd')" "nosuchcmd" "양성 대조: 없는 ledger 명령을 잡는다"
finish
