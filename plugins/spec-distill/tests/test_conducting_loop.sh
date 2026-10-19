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
for lit in '「지금 답할 수 있나」' '배경과 함께 하나씩' '질문 문장 앞머리에 에픽 이름' '그 답에 기대는 일' '무관하다고 본 이유를 적는다' \
           '그 리뷰 게이트의 질문 호출에 섞지 않고' 'ledger audit' 'brainstorming 을 거친다' \
           'brainstorming 대화의 질문은 brainstorming 이 정한 모양 그대로다' '그 대화의 메시지와' '따로 된 메시지로' \
           'brainstorming 의 첫 메시지부터 spec 리뷰의 승인 게이트까지' '선택지는 막혔을 때만'; do once 2 "$lit"; done
assert_not_contains "$(step 2)" '첫 줄에 에픽 이름' "걸음 2: 에픽 이름을 따로 된 첫 줄로 쓰던 옛 문장이 없다(양성 짝: 질문 문장 앞머리)"
for lit in '한 번에 한 에픽씩' '다른 세션을 열라는 줄을 주지 않는다' '`AskUserQuestion` 으로 승인받는다' '`epic-handoff.md`' \
           'worktree-path --name <이름>' '하니스의 새 worktree 만들기를 쓸 수 없어서' '옮기기 전에 지금 자리의 쓰기(커밋 포함)를 끝낸다' \
           '진입 사전 검사 줄의 `root=` 가 그 worktree 인지 확인한 뒤 리뷰한다' '리뷰 원장이 라운드 · 상한을 잇는다' \
           'ledger record --spec <설계문서> --approval' '규모(몇 agent · 무엇)를 알린다' '「승인 — 계획 담당자에게」' \
           '같은 턴에 아래 보내기대로 계획 agent 를 보낸다' '지휘 소식(상태 · 목록 · 다른 에픽 소식)은 그 메시지에 얹지 않는다' \
           '묶음의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다' '`isolation: "worktree"`' 'git switch --ignore-other-worktrees <에픽 브랜치>' \
           '그 agent 가 돌아올 때까지 그 worktree 를 떠나지 않는다' '임시 파일에 쓴 뒤 `cp` 로 옮긴다' '세션이 옮기면 격리 없이 띄운 하위 agent 도 따라 옮긴다' \
           '`git -C <에픽 worktree> switch --detach` 로 그 브랜치를 놓는다' '깨끗하지 않으면 보내지 않고 보인다' \
           'agent 가 쓴 worktree 를 `## 자원` 의 그 에픽 worktree 로 바꿔 적고' '그 브랜치를 체크아웃한 worktree 가 둘 이상이면 쓰지 않고 멈춰 보인다' \
           '놓은 옛 worktree 에서는 커밋하지 않는다' '`ledger add --section "쌓인 기록"` 으로 쌓았다가 돌아온 뒤 `ledger flush` 로 옮기고'; do once 3 "$lit"; done
for old in '절별 승인' '이 턴에는 계획 agent 를 띄우지 않는다' '턴을 끝낸다' '「여기서 계속」'; do
  assert_not_contains "$(step 3)" "$old" "걸음 3: 옛 문장 「${old}」 이 없다(양성 짝: 승인 질문 하나 · 같은 턴 계획 agent)"
done
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
# 병렬 — 보내거나 거둘 때마다 동시 가능한 일을 훑어 바로 보낸다(사용자 「일단 더 병렬진행 안한 이유는 3개 진행중이어서인거야?」)
PAR='agent 를 보내거나 거둘 때마다 상태 계산의 동시 가능 목록과 승인된 설계의 남은 계획을 훑어, 의존 · 같은 파일 겹침 · 기다리는 답이 없는 일은 규모를 알리고 바로 보낸다 — 동시에 돌리는 큰 작업의 권장 수는 기본 3(로드맵 머리말 `parallel_default` 로 바꾼다)이고 상한이 아니다(사용자가 늘린다).'
once 1 "$PAR"
once 4 "$PAR"
# 지휘자 수리 2 — 원천에서 다시 세기 · 맞추기 순서 · 완료 표시는 끝이 아님 · 잠금 대기는 줄 · 권장 수 · 채우기 · 로드맵 밖 일
for lit in '맞추기 순서(보낼 때 · 돌아올 때 · 진행 상황을 말할 때마다 같은 턴에)' '하니스 agent 목록(`ListAgents`)' '「HH:MM 기준」' \
           '조회하지 않은 숫자는 말하지 않는다' '이름 없는 agent(하위 agent 가 띄운 agent)는 세지 않는다' 'ledger progress --roadmap <로드맵>' \
           'completed 만으로 멈춤을 단정하지 않는다' '「waiting on its own background work」' '판단이 모호하면 그 agent 에 한 줄 묻는다' \
           '잠금 대기는 멈춤이 아니라 줄이다' 'ledger suite-lock --roadmap <로드맵>' '짧은 리뷰어와 하위 agent 가 띄운 agent 는 세지 않는다' \
           '권장 수는 기본값이지 상한이 아니다 — 사용자가 늘리고' '지휘자가 이유와 함께 늘리자고 제안한다' '모자라면 채우기:' \
           '에픽 또는 「로드맵 밖」' '--section "작업"' '표에만 있고 원천에 없는 줄은 지우고'; do once 1 "$lit"; done
recon_order() {  # recon_order <글> — 맞추기 순서 문장 안에서 agent 목록 → 상태 계산 → 권장 수 → 채우기 → 기준 시각이면 yes
  PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
s = t.find("맞추기 순서(")
e = t.find("\n", s)
seg = (t[s:e] if e >= 0 else t[s:]) if s >= 0 else ""
ks = ["agent 목록", "상태 계산", "권장 수", "채우기", "기준"]
ix = [seg.find(k) for k in ks]
print("yes" if s >= 0 and min(ix) >= 0 and ix == sorted(ix) else "no")' "$1"
}
assert_eq "$(recon_order "$(step 1)")" "yes" "걸음 1: 맞추기 순서는 agent 목록 → 상태 계산 → 권장 수 → 채우기 → 기준 시각"
assert_eq "$(recon_order '맞추기 순서(x): ① 상태 계산 ② agent 목록 ③ 권장 수 ④ 채우기 ⑤ 기준')" "no" "양성 대조: 상태 계산이 agent 목록보다 앞이면 no"
assert_eq "$(recon_order '맞추기 순서(x): ① agent 목록 ② 상태 계산 ③ 권장 수 ④ 채우기')" "no" "양성 대조: 기준 시각이 빠지면 no"
assert_eq "$(recon_order '맞추기 순서(x): ① agent 목록 ② 상태 계산 ③ 권장 수 ④ 채우기 ⑤ 기준')" "yes" "양성 짝: 규칙대로면 yes"
assert_contains "$(step 4)" '맞추기 순서(① agent 목록 → ② 상태 계산 → ③ 돌고 있는 수 대 권장 수 → ④ 채우기 → ⑤ 기준 시각 붙여 보고)' "걸음 4: 돌아오면 맞추기 순서로 다시 센다"
once 3 '하위에게 보내는 글에는 `ledger suite-lock --roadmap <로드맵>` 의 첫 줄(공유 스위트 잠금 경로)을 싣는다'
assert_contains "$(step 5)" '하위 agent 의 전체 스위트와 같은 잠금이다' "걸음 5: 스위트 대조는 담당자와 같은 공유 잠금"
for n in 1 3 4; do assert_contains "$(step "$n" | grep -F -- '- 기계 상태:')" '`## 작업`' "걸음 ${n}: 기계 상태 칸에 작업 표"; done
# 음의 락 — 동시에 돌리는 일의 개수를 수량 상한에 묶는 문장(지휘자 수리 1 리뷰 넘김 · 수리 2). 「권장(기본값) · 사용자가 늘림」 은 허용.
cap_hits() {  # cap_hits <글> — 상한 문장을 한 줄씩(명시 부정 「상한이 아니다」 류는 뺀 뒤 잰다)
  PYTHONIOENCODING=utf-8 python3 -I -c 'import re, sys
SUBJ = re.compile(r"동시|병렬|한꺼번에|한 번에|큰 작업|돌리는 (작업|일)|agent 수|agent 를 [^.]{0,12}개|concurren|parallel", re.I)
QUANT = re.compile(r"[0-9]|하나|둘|셋|넷|다섯|여섯|일곱|여덟|아홉|한 ?개|두 ?개|세 ?개|네 ?개")
LIMIT = re.compile(r"까지만|까지 만|이하|미만|초과|넘지|넘기지|넘으면|넘는|넘게|넘을|넘어|넘기면|최대|상한|한도|제한|"
                   r"(하나|[0-9]+|한|두|세|네|둘|셋|넷|다섯) ?개?만|이상[^.]{0,10}(금지|않)|at most|no more than|max|limit|cap\b", re.I)
NEG = re.compile(r"상한(이|은|을|도) ?(아니|없|두지 않)[가-힣]*|한도(가|는) ?(아니|없)[가-힣]*|is not a (cap|limit)|not a (cap|limit)", re.I)
W = 40  # 주어 앞뒤 이 글자 안에서만 수량 · 상한을 본다(같은 문장의 다른 상한 — 예: 리뷰 라운드 상한 — 과 엮지 않게)
for sent in re.split(r"(?<=[.。!?])\s+|\n", sys.argv[1]):
    probe = NEG.sub("", sent)
    for m in SUBJ.finditer(probe):
        win = probe[max(0, m.start() - W):m.end() + W]
        if QUANT.search(win) and LIMIT.search(win):
            print(sent.strip()[:160])
            break' "$1"
}
SKILL_MD="$ROOT/plugins/spec-distill/skills/epic-conductor/SKILL.md"
for f in "$CD" "$ROOT/plugins/spec-distill/references/conductor-dispatch.md" "$SKILL_MD"; do
  assert_eq "$(cap_hits "$(cat "$f")")" "" "$(basename "$f"): 동시 개수를 수량 상한에 묶는 문장이 없다"
done
for lit in '동시에 셋까지만 돌린다.' '병렬 agent 는 최대 3개다.' '큰 작업을 3개 넘게 돌리지 않는다.' '동시 개수 상한은 3 이다.' \
           'Run at most 3 parallel agents.' '돌리는 큰 작업은 네 개 이하로 둔다.' '병렬 agent 는 3개로 제한한다.' \
           '동시에 셋만 돌린다.' '큰 작업이 3개를 넘기면 안 된다.' '동시에 넷 이상은 금지다.' '동시에 두 개만 돌린다.' '한 번에 하나만 보낸다.'; do
  [ -n "$(cap_hits "$lit")" ] && ok "양성 대조: 「${lit}」 를 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done
for lit in "$PAR" '권장 수는 기본 3 이고 상한이 아니다 — 사용자가 늘린다.' '좁은 재리뷰는 PR 하나에 두 번까지다.'; do
  assert_eq "$(cap_hits "$lit")" "" "양성 짝: 권장(기본값) · 사용자가 늘림 문장은 허용 — 「${lit:0:40}…」"
done
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
# 순서(지휘자 수리 1 — R34 재결정): 승인이면 미커밋 확인 → 승인 줄 기록 · 커밋 → 기계 상태 저장 → 같은 턴에 계획 agent.
# 그 문장(「승인이면 이 세션은」 부터 「계획 agent 를 보낸다」 까지) 안에서 턴을 끝내거나 두 줄을 주지 않는다.
approve_order() {  # approve_order <글> — 규칙대로면 yes
  PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
s = t.find("승인이면 이 세션은 writing-plans 를 따르지 않고")
e = t.find("계획 agent 를 보낸다", s)
if s < 0 or e < 0:
    print("no"); sys.exit()
seg = t[s:e]
ks = ["미커밋 확인", "ledger record --spec <설계문서> --approval", "worktree 에서 커밋", "기계 상태 저장", "같은 턴에"]
ix = [seg.find(k) for k in ks]
stop = "턴을 끝" in seg or "`/compact` 와" in seg
print("yes" if min(ix) >= 0 and ix == sorted(ix) and not stop else "no")' "$1"
}
seat_order() {  # seat_order <글> — 「하위 agent 의 자리」 안에서 놓기 → 돌아오면 바꿔 적기 순서면 yes
  PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
s = t.find("하위 agent 의 자리(")
a, b = t.find("switch --detach", s), t.find("돌아오면 agent 가 쓴 worktree", s)
print("yes" if 0 <= s < a < b else "no")' "$1"
}
assert_eq "$(seat_order "$(step 3)")" "yes" "걸음 3: 격리 agent 를 보내기 전에 에픽 worktree 가 브랜치를 놓고, 돌아오면 자원을 바꿔 적는다"
assert_eq "$(seat_order '하위 agent 의 자리(x): 돌아오면 agent 가 쓴 worktree 로. 그다음 switch --detach.')" "no" "양성 대조: 놓기가 돌아온 뒤면 no"
assert_eq "$(approve_order "$(step 3)")" "yes" "걸음 3: 승인이면 기록 · 커밋 · 저장 뒤 같은 턴에 계획 agent 를 보낸다"
OLD_STOP='승인이면 이 세션은 writing-plans 를 따르지 않고 — 미커밋 확인 → ledger record --spec <설계문서> --approval → worktree 에서 커밋 → 기계 상태 저장 → 두 줄(`/compact` 와 `/spec-distill:epic-conductor <로드맵>`) → 거기서 턴을 끝내고 다음에 같은 턴에 계획 agent 를 보낸다.'
assert_eq "$(approve_order "$OLD_STOP")" "no" "양성 대조: 승인 문장 안에서 두 줄을 주고 턴을 끝내면 no"
NO_SAVE='승인이면 이 세션은 writing-plans 를 따르지 않고 — 미커밋 확인 → ledger record --spec <설계문서> --approval → worktree 에서 커밋 → 같은 턴에 계획 agent 를 보낸다.'
assert_eq "$(approve_order "$NO_SAVE")" "no" "양성 대조: 기계 상태 저장이 빠지면 no"
EARLY='승인이면 이 세션은 writing-plans 를 따르지 않고 — 같은 턴에 → 미커밋 확인 → ledger record --spec <설계문서> --approval → worktree 에서 커밋 → 기계 상태 저장 → 계획 agent 를 보낸다.'
assert_eq "$(approve_order "$EARLY")" "no" "양성 대조: 기록 전에 보내면 no"
GOOD='승인이면 이 세션은 writing-plans 를 따르지 않고 — 미커밋 확인 → ledger record --spec <설계문서> --approval → worktree 에서 커밋 → 기계 상태 저장 → 같은 턴에 계획 agent 를 보낸다.'
assert_eq "$(approve_order "$GOOD")" "yes" "양성 짝: 규칙대로 쓴 문장은 yes"
assert_not_contains "$(step 3)" '계획 agent 를 보내고 기록을 커밋하고' "걸음 3: 계획 agent 를 먼저 보내던 옛 문장이 없다"
# Ruling R42: 계획 agent 는 같은 에픽 · 일로 살아 있는 agent 가 없을 때만 보낸다(두 writer 금지)
GUARD_RE='live-agent --roadmap <로드맵> --epic <에픽> --work 계획` 이 1'
assert_contains "$(step 1)" "$GUARD_RE" "걸음 1: 계획 agent 보내기 앞에 live-agent 확인"
assert_contains "$(step 3)" "$GUARD_RE" "걸음 3: 보내기 앞에 live-agent 확인"
HAND="$(awk '$0=="## 손으로 따르는 절차"{f=1;next} f' "$CD" | grep -E '^3\. \*\*흐름과 설계')"
assert_contains "$HAND" "$GUARD_RE" "손 절차 3: 보내기 앞에 live-agent 확인"
assert_contains "$HAND" '--section "살아 있는 agent"' "손 절차 3: 보낸 뒤 살아 있는 agent 에 적는다"
assert_contains "$(step 3)" '--section "살아 있는 agent"' "걸음 3: 보낸 뒤 살아 있는 agent 에 적는다"
assert_contains "$(step 1)" '「spec 승인됨(…) · 계획 없음」' "걸음 1: 승인됐고 계획이 없는 에픽에 계획 agent 를 보낸다"
assert_contains "$(step 3)" '보낸 뒤는 끊기 좋은 자리다 — 맥락이 무거우면 `/compact 시점` 대로 압축을 권하고' "걸음 3: 보낸 뒤 압축은 지휘자 판단(R5 범위)"
once 5 '바탕 브랜치를 지우면 위 PR 이 닫히고 다시 열 수 없다'
assert_contains "$(step 5)" '걸음 6 의 충돌 처리' "걸음 5: 충돌 처리는 걸음 6 을 가리킨다"
assert_contains "$(step 6)" '--section "쌓인 기록" --where' "걸음 6: PR 본문에 실은 쌓인 기록을 뺀다"
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
DISP="$(cat "$ROOT/plugins/spec-distill/references/conductor-dispatch.md")"
assert_eq "$(unknown_ledger_cmds "$DISP")" "" "conductor-dispatch.md 의 ledger 명령 이름도 모두 COMMANDS 의 키다"
for t in "$WHOLE" "$DISP"; do
  assert_contains "$(printf '%s\n' "$t" | grep -oE '(conductor_)?ledger(\.py)? [a-z][a-z_-]*' | sort -u)" "resource-dir" "추출이 resource-dir 줄을 본다"
done
assert_contains "$LEDGER_KEYS" "resource-dir" "COMMANDS 에 resource-dir 이 있다"
assert_contains "$(printf '%s\n' "$WHOLE" | grep -oE '(conductor_)?ledger(\.py)? [a-z][a-z_-]*' | sort -u)" "conductor_ledger.py worktree-path" "추출이 worktree-path 줄을 본다"
mutated="$(printf '%s\n' "$WHOLE" | sed 's/conductor_ledger.py worktree-path/conductor_ledger.py nosuch-cmd/')"
assert_eq "$(unknown_ledger_cmds "$mutated")" "nosuch-cmd" "변이: worktree-path 이름을 바꾸면 잡는다"
assert_contains "$LEDGER_KEYS" "claim" "COMMANDS 키를 읽었다"
assert_eq "$(unknown_ledger_cmds 'ledger nosuchcmd')" "nosuchcmd" "양성 대조: 없는 ledger 명령을 잡는다"
finish
