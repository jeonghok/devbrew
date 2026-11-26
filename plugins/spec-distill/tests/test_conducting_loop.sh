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
for lit in '한 번에 한 에픽씩' '다른 세션을 열라는 줄을 주지 않는다' '`AskUserQuestion` 으로 승인받는다' '같은 폴더 `epic-handoff.md` 의 에픽 넘김 줄' \
           'worktree-path --name <이름>' '하니스의 새 worktree 만들기를 쓸 수 없어서' '옮기기 전에 지금 자리의 쓰기(커밋 포함)를 끝낸다' \
           '진입 사전 검사 줄의 `root=` 가 그 worktree 인지 확인한 뒤 리뷰한다' '리뷰 원장이 라운드 · 상한을 잇는다' \
           'ledger record --spec <설계문서> --approval' '규모(몇 agent · 무엇)를 알린다' '「승인 — 계획 담당자에게 (권장)」' \
           '같은 턴에 아래 보내기대로 계획 agent 를 보낸다' '지휘 소식(상태 · 목록 · 다른 에픽 소식)은 그 메시지에 얹지 않는다' \
           '묶음의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다' '설계를 시작하는 에픽마다 `superpowers:brainstorming` 을 다시 부른다 — 같은 세션에서 앞 에픽 때 부른 것으로 갈음하지 않는다' '설계문서는 사용자가 접근을 고른 뒤에 쓴다 — 묶음의 확정 항목에 대한 되비춤만으로, 조사 결과에 대한 한마디 수락만으로 쓰지 않는다' \
           '답이 추천 수락으로만 이어지면 사용자만 답할 수 있는 물음(무엇을 왜)을 물었는지 다시 본다' '`isolation: "worktree"`' 'git switch --ignore-other-worktrees <에픽 브랜치>' \
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
           '`repo_defaults.py get review_model --roadmap <로드맵>`' '「이 PR 이 고침」 · 「뒤 에픽이 고침」' '`## 통합 리뷰 인계`' 'PR 하나에 두 번까지' '머지는 사용자가 한다' '3(검사 불가)이면 사유를 그대로 보이고 그 PR 의 머지 준비를 멈춘다'; do once 5 "$lit"; done
for lit in 'superpowers:systematic-debugging' 'superpowers:verification-before-completion' 'superpowers:receiving-code-review'; do
  assert_contains "$(step 5)" "$lit" "걸음 5: $lit"
done
for lit in '직접 merge 하지 않는다' '다음 task 경계에서 merge 하라고' '그 에픽만 멈추고 알린다' '`redecompose.md`' '브랜치는 지우지 않는다' 'ledger pending' '맡을 에픽을 제안하고' '이슈를 새로 만드는 것은 그때마다 묻는다'; do once 6 "$lit"; done
for lit in '끝에서 끝 확인' 'qg-review.md` 를 읽고 그 자리(「로드맵 끝」)' '`qg-review.md` 의 `## 호출 줄` 대로 한다' 'ledger release'; do once 7 "$lit"; done
for lit in 'qg-review.md` 를 읽고 그 자리(「머지 앞」)' '머지 앞 qg 리뷰와 되돌리기 → 관문(`gate`) → 스위트 대조'; do once 5 "$lit"; done
# 병렬 — 보내거나 거둘 때마다 동시 가능한 일을 훑어 바로 보낸다(사용자 「일단 더 병렬진행 안한 이유는 3개 진행중이어서인거야?」)
PAR='agent 를 보내거나 거둘 때마다 상태 계산의 동시 가능 목록과 승인된 설계의 남은 계획을 훑어, 의존 · 같은 파일 겹침 · 기다리는 답이 없는 일은 규모를 알리고 바로 보낸다 — 동시에 돌리는 큰 작업의 권장 수는 기본 3(레포 설정 파일이나 로드맵 머리말의 `parallel_default` 로 바꾼다)이고 상한이 아니다(사용자가 늘린다).'
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
assert_contains "$(step 4 | grep -F -- '- 기록:')" '「설계에 없던 결정」 을 가른 결과와 이유 → 설계문서 `## 지휘 기록`' "걸음 4: 가른 결과는 지휘 기록에(결정 기록 울타리 밖)"
assert_contains "$(step 4 | grep -F -- '- 기록:')" '리뷰가 열려 있는 문서의 `## 결정 기록` 에 손으로 쓴 줄은 다음 리뷰에서 「허가 없이 바뀜」 으로 돌아온다' "걸음 4: 손으로 쓴 줄이 돌아오는 것은 열린 리뷰다"
assert_not_contains "$(step 4)" '사용자 원문과 함께 `## 지휘 기록` 에 둔다' "걸음 4: 닫힌 리뷰의 결정 줄을 지휘 기록으로 보내던 옛 ③ 이 없다(양성 짝: 새 ③)"
assert_contains "$(step 4 | grep -F -- '- 기록:')" '사용자 결정 원문을 설계문서 `## 결정 기록` 에 남겨야 하면 갈래가 셋이다 — ① 그 문서의 리뷰가 열려 있으면 그 리뷰의 결정 줄 펜스(`decision-line` — 엔진 `log-decision`)로 쓴다 ② 리뷰 원장이 없으면(리뷰 전) 손으로 쓴다 — 첫 라운드가 기준선으로 받는다 ③ 리뷰가 닫혔으면 `## 결정 기록` 절 끝(마지막 계수 줄 아래)에 손으로 쓴다 — 다음 재리뷰가 그 줄을 기록으로 읽는다(재리뷰를 시작한 뒤에 쓴 줄은 다시 묻는다)' "걸음 4: 사용자 결정 원문의 세 갈래(열린 리뷰 · 원장 없음 · 닫힌 리뷰)"
assert_contains "$(step 4 | grep -F -- '- 기록:')" '(재리뷰를 시작한 뒤에 쓴 줄은 다시 묻는다). 끝맺음을 건너뛰어 계수 줄이 없거나 계수 줄에 표지가 없는 옛 원장이면 재리뷰가 그 줄을 한 번 묻는다 — 「고친 대로 둠」으로 닫는다.' "걸음 4: 닫힌 리뷰 갈래의 단서 — 끝맺음을 건너뛰었거나 옛 원장이면 한 번 묻는다"
# 작업 표의 단계 칸은 자유 글이다 — 끝난 일은 상태 보기가 끝으로 세는 낱말(conductor_state.WORK_DONE)로 적거나 줄을 지운다(통합 리뷰 지적)
DONE_RULE='끝난 일은 단계 칸에 「끝」 으로 적거나 그 줄을 지운다(`ledger drop`) — 상태 보기는 단계가 '
assert_contains "$(step 1)" "$DONE_RULE" "걸음 1: 끝난 작업 줄의 단계 낱말"
DONE_WORDS="$(PYTHONDONTWRITEBYTECODE=1 python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import conductor_state as cs
print("\n".join(cs.WORK_DONE))' "$ROOT/plugins/spec-distill/scripts")"
[ -n "$DONE_WORDS" ] && ok "conductor_state.WORK_DONE 를 읽었다" || no "conductor_state.WORK_DONE 이 없다"
DONE_LISTED="$(step 1 | PYTHONIOENCODING=utf-8 python3 -I -c 'import re, sys
t = sys.stdin.read()
s = t.find(sys.argv[1])
e = t.find(" 인 줄만 끝으로 세고", s)
seg = t[s + len(sys.argv[1]):e] if s >= 0 and e > s else ""
print("\n".join(sorted(re.findall("「([^」]+)」", seg))))' "$DONE_RULE")"
assert_eq "$DONE_LISTED" "$(printf '%s\n' "$DONE_WORDS" | LC_ALL=C sort | sed '/^$/d' | python3 -I -c 'import sys; print("\n".join(sorted(l.strip() for l in sys.stdin if l.strip())))')" "걸음 1: 끝으로 세는 낱말 목록이 conductor_state.WORK_DONE 과 같다(등호 — 더하거나 빼면 RED)"
once 1 '담당 agent 가 돌아오면(거두거나 내리면) 그 줄의 담당 칸을 「없음」 으로 바꾼다 — 상태 보기는 담당으로 돌고 있는 수를 센다'
for n in 1 3 4; do assert_contains "$(step "$n" | grep -F -- '- 기계 상태:')" '`## 작업`' "걸음 ${n}: 기계 상태 칸에 작업 표"; done
# 음의 락 — 동시에 돌리는 일의 개수를 수량 상한에 묶는 문장(지휘자 수리 1 리뷰 넘김 · 수리 2). 「권장(기본값) · 사용자가 늘림」 은 허용.
cap_hits() {  # cap_hits <글> — 상한 문장을 한 줄씩(명시 부정 「상한이 아니다」 류는 뺀 뒤 잰다)
  PYTHONIOENCODING=utf-8 python3 -I -c 'import re, sys
SUBJ = re.compile(r"동시|병렬|한꺼번에|한 번에|큰 작업|돌리는 (작업|일)|agent 수|agent 를 [^.]{0,12}개|concurren|parallel", re.I)
QUANT = re.compile(r"[0-9]|하나|둘|셋|넷|다섯|여섯|일곱|여덟|아홉|한 ?개|두 ?개|세 ?개|네 ?개")
LIMIT = re.compile(r"까지만|까지 만|이하|미만|초과|넘지|넘기지|넘으면|넘는|넘게|넘을|넘어|넘기면|최대|상한|한도|제한|"
                   r"(하나|[0-9]+|한|두|세|네|둘|셋|넷|다섯) ?개?만|이상[^.]{0,10}(금지|않)|at most|no more than|max|limit|cap\b", re.I)
NEG = re.compile(r"머지 명령 줄은 이 로드맵의 PR 가운데 한 번에 하나만 낸다|상한(이|은|을|도) ?(아니|없|두지 않)[가-힣]*|한도(가|는) ?(아니|없)[가-힣]*|is not a (cap|limit)|not a (cap|limit)", re.I)
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
for lit in "$PAR" '권장 수는 기본 3 이고 상한이 아니다 — 사용자가 늘린다.' '좁은 재리뷰는 PR 하나에 두 번까지다.' \
           '머지 명령 줄은 이 로드맵의 PR 가운데 한 번에 하나만 낸다 — 낸 PR 이 머지됨이 되면 다음 PR 을 낸다.'; do
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
once 1 '돌고 있는 담당자의 원천은 둘이다 — 하니스 agent 목록과 hc 의 내 자식(`hc ls` 에서 `parent` 가 내 주소인 것)'
once 1 '끝난 세션은 스스로 닫히지 않고 「살아 있음 · 끝남」 으로 남는다'
once 1 '내 자식인데 표에 없는 터미널은 무엇인지 보고 닫거나 표에 올린다'
once 3 'hc 가 있으면 계획 · 구현 담당자는 따로 띄운 세션으로 보낸다 — `conductor-dispatch.md` 의 `## 세션 담당자`'
once 4 '결과 파일을 읽는다 → 지금 걸음 4 의 처리(판정 · 수용 기준 보고 거두기)를 그 파일로 한다 → 사용자 말 파일을 읽고 아직 옮기지 않은 글을 결정 줄로 옮긴다 → 세션을 닫는다(`hc kill` → `hc rm`) → 표에서 그 줄을 뺀다 → 내가 띄운 살아 있는 터미널 가운데 표에 없는 것이 0 인지 본다'
once 4 '띄운 직후의 기다리기(`hc wait`)는 첫 턴이 시작되기 전에 `idle` 로 돌아올 수 있으니 끝으로 읽지 않는다'
once 4 '남의 세션은 건드리지 않는다 — `parent` 가 내 주소인 것만 닫는다'
once 4 'hc wait --children any --timeout <초>'
once 4 '질문 창에서 사용자 답을 받은 직후에도 한 번 본다'
once 4 '같은 걸음에서 담당자가 두 번 이어 막히면 세 번째로 보내지 않고 사용자에게 간다'
once 4 '「담당자 세션에서 들음 · <세션 이름>」'
once 4 '승인 줄로는 적지 않는다'
once 4 '리더는 담당자의 질문 창 · 권한 창에 답하지 않고 어느 세션이 무엇을 묻고 있는지 사용자에게 알린다'
once 4 '권한 물음으로 거듭 멈추면 사용자에게 알리고 그 일을 하위 agent 길로 돌릴지 묻는다'
once 4 '답과 방향 고침 · 받은 고침 확인 · 「중간」 알림은 `conductor-dispatch.md` 의 `### 리더 쪽` 을 따른다'
once 5 '머지 명령 줄을 내기 전에 그 에픽에서 받은 승인과 담당자 세션에서 들은 사용자 말을 모아 사용자에게 다시 보인다'
once 5 '「담당자 세션에서 들음」 표시를 붙여 둔 줄 전부'
once 5 '하신 적 없는 승인이나 말이 있으면 머지하지 말고 알려 달라'
once 5 '목록도 함께 싣는다 — 그 가운데 리더가 쓰지 않은 고침이 있으면 머지 명령 줄을 내지 않고 사용자에게 알린다'
once 5 'team 형식이면 표시 없는 `conductor_branch.py confirm` 이 낸 출력(「이 기계가 쓴 것으로 적힌 고침」 목록 줄과 「확인할 끝」 이 한 출력에 나온다)의 '
once 5 '사용자가 머지를 정하면 그 출력의 「확인할 끝」 으로 `conductor_branch.py confirm --confirmed <확인할 끝>` 을 불러 확인한 끝을 기록한다 — 1 로 끝나면 끝이 옮겨진 것이니 새로 낸 목록을 다시 보이고 묻는다. 그 전에는 `sync` 가 그 목록을 접지 않는다.'
assert_not_contains "$(step 5)" '`conductor_status.py show` 가 내는 「이 기계가 쓴 것으로 적힌 고침」 목록' "걸음 5: 접기 전에 싣는 목록은 끝을 찍지 않는 show 의 것이 아니다"
once 7 '표지를 풀기 전에 내가 띄운 살아 있는 터미널이 0 인지 본다'
# ── R9 Task 11 — 다시 들어오기 · 머지 관문 · team 형식이 리뷰 상태 스크립트를 부른다(설계 §3 · §4 · §5 · §9 · AC1 · AC6 · AC8 · AC9 · AC10 · AC20 · AC23)
QRS="$ROOT/plugins/spec-distill/skills/epic-conductor/references/qg-review.md"
TEAMS="$(awk '$0=="## team 형식 로드맵"{f=1;next} f&&/^## /{exit} f' "$CD")"
MANS="$(awk '$0=="## 손으로 따르는 절차"{f=1;next} f' "$CD")"
mstep() { printf '%s\n' "$MANS" | awk -v n="$1" 'index($0, n ". ")==1{f=1;print;next} f&&/^[1-9]\. /{exit} f'; }
tbul() { printf '%s\n' "$TEAMS" | awk -v h="$1" 'index($0, h)==1'; }
TQB="$(tbul '- **검수 걸음의 qg.**')"; TPR="$(tbul '- **PR 전 확인.**')"; M8B="$(mstep 8 | grep -F -- '- **머지 앞 qg 리뷰.**')"
[ -n "$TQB" ] && [ -n "$TPR" ] && [ -n "$M8B" ] && [ -n "$(mstep 1)" ] && ok "R9: team 절 · 손 절차의 불릿을 읽었다" || no "R9: team 절 · 손 절차의 불릿이 비었다 — 아래 단언이 공허하다"
onein() { assert_eq "$(printf '%s\n' "$2" | grep -oF -- "$3" | wc -l | tr -d ' ')" "1" "${1}: 「${3}」 정확히 한 번"; }
# 인용한 이름이 스크립트에 실재한다 — 명령 · 글 짓기 종류 · 답 적기 종류 · 표시 값 · 처리 머리(재도출: 스크립트에서 읽는다)
SNAMES="$(PYTHONDONTWRITEBYTECODE=1 python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import qg_review_state as S
print("cmd", "|".join(S.COMMANDS)); print("kind", "|".join(S.RENDER_KINDS)); print("item", "|".join(sorted(S.ITEM_FIELDS)))
print("mark", "|".join(sorted(S.F.MARK_FOR_REASON))); print("head", S.HANDLING_HEAD)' "$ROOT/plugins/spec-distill/scripts")"
[ -n "$SNAMES" ] && ok "R9: qg_review_state 의 이름들을 읽었다" || no "R9: qg_review_state 의 이름들을 읽지 못했다"
unknown_state_names() {  # unknown_state_names <글> — 스크립트에 없는 명령 · 종류를 한 줄씩
  PYTHONIOENCODING=utf-8 python3 -I -c 'import re, sys
names = dict(l.split(" ", 1) for l in sys.argv[2].splitlines() if " " in l)
cmds, kinds = names["cmd"].split("|"), names["kind"].split("|")
items, marks = names["item"].split("|"), names["mark"].split("|")
t = sys.argv[1]
seen = 0
for m in re.finditer(r"qg_review_state\.py`? ([a-z][a-z-]*)", t):
    seen += 1
    if m.group(1) not in cmds: print("cmd:" + m.group(1))
for m in re.finditer(r"render --kind ([a-z][a-z-]*)", t):
    if m.group(1) not in kinds: print("kind:" + m.group(1))
for m in re.finditer(r"`record` 의 `([a-z_]+)`", t):
    if m.group(1) not in items: print("item:" + m.group(1))
for m in re.finditer(r"`mark` 「([^」]+)」", t):
    if m.group(1) not in marks: print("mark:" + m.group(1))
if seen == 0: print("none")' "$1" "$SNAMES"
}
assert_eq "$(unknown_state_names "$WHOLE")" "" "R9: conducting.md 가 인용한 qg_review_state 명령 · 종류 · 표시는 스크립트에 있다"
assert_eq "$(unknown_state_names '`python3 "<SD>"/scripts/qg_review_state.py nosuch` 를 부른다')" "cmd:nosuch" "양성 대조: 없는 명령을 잡는다"
assert_eq "$(unknown_state_names 'qg_review_state.py render --kind nosuch-kind · `record` 의 `nosuch_item` · `mark` 「없는 표시」')" "$(printf 'kind:nosuch-kind\nitem:nosuch_item\nmark:없는 표시')" "양성 대조: 없는 종류 · 답 적기 · 표시를 잡는다"
assert_eq "$(unknown_state_names '스크립트 이름이 없는 글')" "none" "양성 대조: 인용이 하나도 없으면 공허하지 않게 none"
assert_eq "$(grep -cxF -- '## 머지 앞 리뷰 상태' "$QRS")" "1" "R9: 가리키는 qg-review.md 의 \`## 머지 앞 리뷰 상태\` 절이 실재한다"
# step1-calls-next — 다시 들어오면 머지 앞 리뷰가 있는 PR 마다 next 를 부르고, 살아 있는 이름은 걸음 1 의 원천으로 센다(AC8 · §4)
NEXT_CALL='`python3 "<SD>"/scripts/qg_review_state.py next` 를 부르고 그 할 일대로 한다'
NEXT_ALIVE='살아 있는 담당자(그 PR 의 qg 담당자와 돌려보낸 구현 담당자 가운데 아직 끝나지 않은 것)'
once 1 "$NEXT_CALL"
once 1 "${NEXT_ALIVE}는 위 「원천」 · 「세션 담당자의 원천」 으로 센다"
onein "손 절차 1" "$(mstep 1)" "$NEXT_CALL"
onein "손 절차 1" "$(mstep 1)" "${NEXT_ALIVE}는 지휘 순환 걸음 1 의 「원천」 · 「세션 담당자의 원천」 으로 센다"
s1_order="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
a, b, c = t.find("\n  - 원천:"), t.find("\n  - 세션 담당자의 원천:"), t.find(sys.argv[2])
print("yes" if 0 <= a < b < c else "no")' "$(step 1)" "$NEXT_CALL")"
assert_eq "$s1_order" "yes" "걸음 1: next 를 부르는 불릿은 「원천」 · 「세션 담당자의 원천」 불릿 뒤(「위」 가 가리키는 자리)"
assert_contains "$(step 1)" '`<SD>/skills/epic-conductor/references/qg-review.md` 의 `## 머지 앞 리뷰 상태`' "걸음 1: next 의 꼴과 표는 qg-review.md 의 머지 앞 리뷰 상태 절"
# step5-gate — 스위트 대조 앞에서 gate, rc 0 일 때만 머지 준비, 그 밖이면 next(AC6 · §3) — 옛 형식(걸음 5 · 손 절차 8) · team 형식(PR 전 확인)
GATE_GO='qg_review_state.py gate` 를 부르고 rc 0 일 때만 머지 준비로 간다 — 그 밖이면 `next` 를 부르고 걸린 까닭의 할 일을 한다'
once 5 "에픽 PR 이면 스위트 대조 앞에서 \`python3 \"<SD>\"/scripts/${GATE_GO}"
onein "손 절차 8 머지 앞 qg 리뷰" "$M8B" "$GATE_GO"
onein "team PR 전 확인" "$TPR" "$GATE_GO"
gate_rc1() {  # gate_rc1 <글> — 관문 문장 가운데 닫힘 하나(rc 1)만 적어 다른 rc 가 지나가게 하는 문장을 한 줄씩
  PYTHONIOENCODING=utf-8 python3 -I -c 'import re, sys
ONE = re.compile(r"(rc|종료 코드)\s*(가\s*|이\s*)?1\s*(\(|이면|일 때|이 나오면|로 끝나면)|관문(\(`gate`\))?이 닫히면|닫힘이면")
for sent in re.split(r"(?<=[.。])\s+|\n", sys.argv[1]):
    if ("`gate`" in sent or "qg_review_state.py gate" in sent) and ONE.search(sent):
        print(sent.strip()[:160])' "$1"
}
for w in "걸음 5:$(step 5)" "손 절차 8:$(mstep 8)" "team 절:$TEAMS"; do
  assert_eq "$(gate_rc1 "${w#*:}")" "" "${w%%:*}: 관문의 닫힘 하나만 적어 다른 rc 가 지나가는 문장이 없다(양성 짝: rc 0 일 때만)"
done
for lit in '`gate` 를 부르고 rc 1 이면 `next` 로 돌아간다.' '관문(`gate`)이 종료 코드 1(닫힘)이면 머지하지 않는다.' '관문(`gate`)이 닫히면 `next` 를 부른다.' '`gate` 가 rc 가 1 로 끝나면 멈춘다.'; do
  [ -n "$(gate_rc1 "$lit")" ] && ok "양성 대조: 「${lit}」 를 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done
assert_eq "$(gate_rc1 "$GATE_GO")" "" "양성 짝: rc 0 일 때만 문장은 허용"
assert_eq "$(gate_rc1 '종료 코드 1(새 실패)이면 고친다.')" "" "양성 짝: 관문이 아닌 문장의 종료 코드 1 은 보지 않는다"
for w in "걸음 5:$(step 5)" "손 절차 8:$(mstep 8)"; do
  assert_not_contains "${w#*:}" '고쳐졌거나 사용자가 남기기로 한 뒤에 스위트 대조로 간다' "${w%%:*}: 관문의 조건을 다시 적던 옛 문장이 없다(양성 짝: gate)"
done
# step5-approval — 승인 기록 다시 보이기의 qg 몫은 render --kind approval 의 글(AC10 · §5)
APPR="$(step 5 | awk 'index($0, "  - 승인 기록 다시 보이기:")==1{f=1;print;next} f&&index($0, "  - ")==1{exit} f')"
[ -n "$APPR" ] && ok "걸음 5: 승인 기록 다시 보이기 불릿을 읽었다" || no "걸음 5: 승인 기록 다시 보이기 불릿이 비었다 — 아래 단언이 공허하다"
onein "걸음 5 승인 기록 다시 보이기" "$APPR" '두 형식 모두 머지 앞 qg 몫은 `python3 "<SD>"/scripts/qg_review_state.py render --kind approval` 이 낸 글을 그대로 싣는다'
for old in '`- 답:`' '`## qg 리뷰` 의 사용자 답' '리뷰 기록 파일'; do
  assert_not_contains "$APPR" "$old" "걸음 5 승인 기록 다시 보이기: 「${old}」 에서 qg 답을 읽던 옛 문장이 없다(양성 짝: render --kind approval)"
done
assert_not_contains "$WHOLE" '`- 답:` 줄' "conducting.md: 기록 파일의 \`- 답:\` 줄을 읽으라는 문장이 없다(AC1)"
# lock-users-qg — 공유 스위트 잠금을 쓰는 쪽에 qg 를 더한다(R7 이 넘긴 한 줄 · D47 · D58)
once 1 '공유 스위트 잠금(지휘자의 스위트 대조 · 하위 agent 의 전체 스위트 · qg 가 같이 쓰는 잠금)'
assert_not_contains "$(step 1)" '지휘자의 스위트 대조와 하위 agent 의 전체 스위트가 같이 쓰는 잠금' "걸음 1: 쓰는 쪽을 둘로 적던 옛 잠금 문장이 없다(양성 짝: 셋)"
# team-review-qg — 검수 걸음의 qg 는 같은 스크립트 · 대상 <과제>-plan<n> · 펜스는 표시(AC1 · AC20 · AC23 · §9)
for lit in '같은 스크립트(`qg_review_state.py`)와 상태 파일을 쓴다 — 대상은 `<과제>-plan<n>`, 뺄 파일은 `--job-dir <과제 폴더>`' \
           '`open` 의 `--epic` 은 그 과제가 속한 에픽 번호' '자리 글자는 `premerge-<과제>-plan<n>` · `recheck-<과제>-plan<n>`' \
           '`render --kind team-fence` 가 지은 글(바깥 펜스까지)을 싣는다 — 그 펜스는 표시이고 리더는 거기서 읽지 않는다' \
           '「두 번까지」 는 옛 형식과 같고' '검수 반려로 다시 보낸 시도가 돌아온 때에는 걸음 4 의 기본 브랜치 합치기를 하지 않는다' \
           '다음 시도를 보낸 즉시 `record` 의 `return`' '시작 묶음과 과제 결정 기록에 싣는 글에는 리뷰 보관 폴더 · 상태 파일의 경로를 싣지 않는다'; do
  onein "team 검수 걸음의 qg" "$TQB" "$lit"
done
for old in '펜스 하나 안에 적고 거기서 센다' '거기서 센다' '펜스 안 줄은 결과 파일의 기계 줄로 읽히지 않는다'; do
  assert_not_contains "$TEAMS" "$old" "team 절: 펜스에 적고 거기서 세던 옛 문장 「${old}」 이 없다(양성 짝: 펜스는 표시)"
done
# team-handling-header — 결정 기록에 싣는 한 줄이 처리 머리(스크립트가 처리 파일을 알아보는 머리)를 쓴다(D74)
DLINE="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
k = "과제 결정 기록의 한 줄(「"
s = t.find(k)
e = t.find("」)", s)
print(t[s + len(k):e] if 0 <= s < e else "")' "$TQB")"
[ -n "$DLINE" ] && ok "team 검수 걸음의 qg: 결정 기록에 싣는 한 줄을 읽었다" || no "team 검수 걸음의 qg: 결정 기록에 싣는 한 줄(「…」)이 없다 — 아래 단언이 공허하다"
HEAD_T="$(printf '%s\n' "$SNAMES" | sed -n 's/^head //p')"
assert_eq "$HEAD_T" "## 지적마다의 처리" "R9: 스크립트의 처리 머리를 읽었다"
assert_contains "$DLINE" "구현 결과 파일의 \`${HEAD_T}\` 머리 아래에" "team-handling-header: 결정 기록 한 줄이 구현 결과 파일의 처리 머리(스크립트 값) 아래에 쓰라고 싣는다"
onein "team 검수 걸음의 qg" "$TQB" "다음 시도의 구현 결과 파일의 \`${HEAD_T}\` 머리 아래에 적게 한다"
for tok in '보관 폴더' '상태 파일' 'qg-' 'state' 'resource-dir'; do
  assert_not_contains "$DLINE" "$tok" "AC23: 결정 기록에 싣는 한 줄에 「${tok}」 가 없다(보관 폴더 · 상태 파일 경로를 싣지 않는다)"
done
# mark-timing-step3 — 설계 대화로 돌아간 에픽은 고친 설계의 구현이 돌아오면 mark 「다시 구현됨」(AC9)
once 3 '고친 설계의 구현 담당자가 돌아오면 `qg_review_state.py record` 의 `mark` 「다시 구현됨」 을 적고 `next` 를 부른다'
assert_not_contains "$(step 5)" '(team 형식은 검수 결과 파일의 펜스 안)' "걸음 5: qg 답 자리가 옛 형식 문장 안 괄호에만 있지 않다"
assert_contains "$(sed -n '/^- \*\*PR 전 확인.\*\*/p' "$CD")" '머지 앞 qg 의 사용자 답(`human-check` 은 사람 줄만 낸다)은 걸음 5 「승인 기록 다시 보이기」 의 두 형식 공통 문장대로 함께 보인다' "team PR 전 확인: qg 답을 걸음 5 공통 문장으로 가리킨다"
assert_not_contains "$(step 4)" 'hc keys' "걸음 4: 리더가 키를 넣는 길을 적지 않는다"
finish
