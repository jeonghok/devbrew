#!/usr/bin/env bash
# R3 — 지휘자 경유 qg 리뷰 절차(skills/epic-conductor/references/qg-review.md)와 들어가는 문장. 정적 락이다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_qg_review_reference.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
QR="$ROOT/plugins/spec-distill/skills/epic-conductor/references/qg-review.md"
[ -f "$QR" ] && ok "qg-review.md 가 있다" || { no "qg-review.md 가 없다"; finish; exit $?; }
sec() { awk -v h="$1" '/^```/{q=!q} !q&&$0==h{f=1;next} f&&!q&&/^## /{exit} f' "$QR"; }   # 절 본문(머리 줄 제외) — 펜스 안의 `## ` 줄은 절 머리가 아니다
once() { assert_eq "$(printf '%s\n' "$1" | grep -oF -- "$2" | wc -l | tr -d ' ')" "1" "$3"; }

ALL="$(cat "$QR")"
for h in '## 호출 줄' '## 자리' '## 담당자' '## 돌아왔을 때' '## 보관과 기록 파일' '## 묻기' '## 「잘못 골랐다」 의 행선'; do
  assert_eq "$(grep -cxF -- "$h" "$QR")" "1" "절 머리가 정확히 하나: ${h}"
  [ -n "$(sec "$h")" ] && ok "절 본문을 읽었다: ${h}" || no "절 본문이 비었다 — 아래 단언이 공허하다: ${h}"
done
CALL="$(sec '## 호출 줄')"
SITE="$(sec '## 자리')"
DISP="$(sec '## 담당자')"
BACK="$(sec '## 돌아왔을 때')"
KEEP="$(sec '## 보관과 기록 파일')"
ASK="$(sec '## 묻기')"
WRONG="$(sec '## 「잘못 골랐다」 의 행선')"
# 펜스 가운데 표지 글자가 든 첫 펜스의 본문(펜스 줄 제외)
fence_with() { printf '%s\n' "$1" | awk -v m="$2" '/^```/{ if (f) { if (index(b, m)) { printf "%s", b; exit } f=0; b="" } else { f=1; b="" } next } f { b = b $0 "\n" }'; }
# 줄 첫머리가 글자 p 인 줄의 수
starts() { printf '%s\n' "$1" | awk -v p="$2" 'index($0, p)==1' | wc -l | tr -d ' '; }
TPL="$(fence_with "$KEEP" 'type: roadmap-review')"
QF="$(fence_with "$ASK" 'header: "의도 점검')"
[ -n "$TPL" ] && ok "기록 틀 펜스를 읽었다" || no "기록 틀 펜스가 없다 — 아래 AC10 단언이 공허하다"
[ -n "$QF" ] && ok "질문 틀 펜스를 읽었다" || no "질문 틀 펜스가 없다 — 아래 AC8 단언이 공허하다"

# L(x) — 글자가 정해진 문장
L_nodirect='지휘 세션은 qg skill 을 직접 부르지 않는다 — 자리마다 담당자 하나를 백그라운드로 보내 이 줄을 부르게 한다.'
L_resend='다시 보내는 때는 둘이다 — 의도 점검의 「잘못 골랐다」 로 설계 대화에 돌아가 고친 뒤, 그리고 spec 리뷰의 「수정 필요」 에서 「이 에픽 다시 설계」 로 설계 대화에 돌아가 고친 뒤. 둘 다 고친 설계문서를 커밋한 뒤, spec 리뷰를 부르기 전에 위 순서로 보내고 질문을 띄운다.'
L_norange='rc 가 3 이면 보내지 않고 「범위를 확인하지 못해 리뷰하지 못했다」 와 스크립트가 낸 사유를 보인다 — 범위를 추측해 맞추지 않는다. rc 가 4 면 보내지 않고 머지 커밋이 PR 캐시에 없다는 사실을 알린다.'
L_alreadysent='보내기 전에 위 `### 이미 보낸 것` 의 확인을 한다 — 이름으로 먼저 청한 리뷰와 범위가 같은지는 범위를 얻은 뒤 본다.'
L_failed='범위를 확인하지 못했거나 머지 커밋이 없어 보내지 못한 리뷰와, 담당자가 결과 파일을 옮기지 못해 「셀 수 없음」 으로 끝난 리뷰는 사용자에게 사유와 함께 보이고 `ledger add --section "쌓인 기록"` 으로 한 줄(자리 · 대상 · 사유)을 남긴다. 지휘자가 스스로 다시 보내지 않는다 — 사용자가 이름으로 청하면 그때 다시 시도한다.'
L_endmerge='보내기 전에 `git fetch origin` 뒤 로드맵의 기록 브랜치에 기본 브랜치 끝을 합치고(`git merge --no-edit origin/HEAD`, 기록 브랜치 worktree 에서), 이 리뷰의 기록 파일 머리(frontmatter · 제목 · 「만든 것」 줄들)를 커밋한 뒤 보낸다. 범위는 합친 뒤의 갈라진 커밋(그때의 기본 브랜치 끝)부터 기록 브랜치 끝까지다.'
L_suitewait='스위트 잠금이 잡혀 있으면 qg 담당자를 보내지 않고 풀릴 때까지 기다린다. qg 담당자가 도는 동안 스위트 대조를 시작하지 않는다.'
L_raise='사용자가 되올릴 지적을 말하면 qg 를 다시 돌리지 않는다 — 그 지적을 「사용자가 되올림」 표시와 원래 심각도로 지휘 기록과, 머지 뒤 자리면 후속 PR 의 고칠 목록에 올린다.'
L_premerge='머지 전 자리(spec 승인 앞 · 이름으로 청한 머지 전 에픽)의 판정 줄과 코드 리뷰 지적은 보이기만 하고 spec 리뷰와 승인을 막지 않으며, 그 에픽 설계문서의 `## 지휘 기록` 에 적어 설계 수정이나 구현의 입력으로 둔다.'
L_p5='담당자가 돌아와 그 결과를 보인 뒤에 spec 리뷰를 시작한다 — 질문이 있으면 띄워 답을 받았거나 「답하지 않음」 으로 기록한 뒤, 질문이 없거나(`outcome` 이 `questions` 가 아님) 리뷰가 돌지 않았거나(`status` 가 `ran` 이 아님) 결과를 가져오지 못했으면 그 사실을 보이고 기록한 뒤 간다. 「잘못 골랐다」 가 있으면 가지 않는다(「잘못 골랐다」 의 행선).'

# AC1 호출 줄 · 자리 표
once "$CALL" '/quality-gates:quality-pipeline range <시작 커밋>..<끝 커밋> --origin <원문 파일의 레포 상대경로>' "AC1: 호출 줄이 호출 줄 절에 한 번"
assert_eq "$(printf '%s\n' "$ALL" | grep -oF 'quality-pipeline range' | wc -l | tr -d ' ')" "1" "AC1: quality-pipeline 을 부르는 꼴이 파일 전체에서 한 줄뿐"
assert_eq "$(printf '%s\n' "$ALL" | grep -oF '/quality-gates:quality-pipeline' | wc -l | tr -d ' ')" "1" "AC1: /quality-gates:quality-pipeline 호출이 파일 전체에서 한 번뿐(다른 꼴 --pr · 맨 호출 없음)"
once "$SITE" '| 자리 | 언제 | 시작 | 끝 | 원문 | 「잘못 골랐다」 | 기록이 실리는 곳 |' "AC1: 자리 표 머리 줄이 한 번"
rows="$(printf '%s\n' "$SITE" | awk -F'|' '/^\|/{c=$2; gsub(/^ +| +$/,"",c); if (c!="자리" && c !~ /^-+$/) print c}' | tr '\n' ',')"
assert_eq "$rows" "spec 승인 앞,에픽 머지 뒤,로드맵 끝,이름으로 청함," "AC1: 자리 표의 첫 칸이 차례로 자리 넷"

# AC3 직접 부르지 않음 · 보내는 글 · 처분 · 되올림
once "$CALL" "$L_nodirect" "AC3: L(nodirect) 한 번"
assert_contains "$DISP" 'isolation: "worktree"' "AC3 양성 짝: 담당자를 격리 worktree 로 보낸다"
for lit in '한 번만 부른다' '「지금 판정으로 끝내기」' '모든 묶음에 「그대로 둔다」' 'intent-return.md' 'other_teams' 'result.md' '낮춘 지적 표 전부(위치 · 원래 심각도 · 내용 · 낮춘 이유)'; do
  assert_contains "$DISP" "$lit" "AC3 보내는 글: ${lit}"
done
DLINE='**처분** — consumer=orchestrator · fail-closed · disclosure=담당자가 돌려준 판정 줄 · 지적 목록 · 낮춘 지적 표 · intent-critic 결과 줄 · 질문 전부를 그 자리 이름과 함께 사용자에게 보인다'
once "$DISP" "$DLINE" "AC3 처분: 처분 줄이 글자 그대로 한 번"
a_n="$(printf '%s\n' "$DISP" | grep -nF 'Agent(' | head -1 | cut -d: -f1)"
d_n="$(printf '%s\n' "$DISP" | grep -nF -- "$DLINE" | head -1 | cut -d: -f1)"
if [ -n "$a_n" ] && [ -n "$d_n" ] && [ "$d_n" -gt "$a_n" ] && [ $((d_n - a_n)) -le 40 ]; then
  ok "AC3 처분: 처분 줄이 Agent( 줄 아래 40줄 안"
else
  no "AC3 처분: 처분 줄이 Agent( 줄 아래 40줄 안에 없다(Agent=${a_n:-없음} · 처분=${d_n:-없음})"
fi
DISC="${DLINE#*disclosure=}"
assert_contains "$(printf '%s\n' "$DISP" | grep -vF -- "$DLINE")" "$DISC" "AC3 처분: disclosure 글이 처분 줄 밖 본문에도 있다(보이는 일이 절차에 있다)"
once "$DISP" "$L_raise" "AC3 되올림: L(raise) 한 번"
assert_contains "$DISP" 'qg 를 다시 돌리지 않는다' "AC3 되올림: qg 를 다시 돌리지 않는다"

# AC4 지휘자 쪽
assert_contains "$SITE" 'merged_pr_range.py --roadmap <로드맵> --pr <번호>' "AC4: 범위 확인 스크립트를 부른다"
once "$SITE" "$L_norange" "AC4: L(norange) 한 번"
assert_contains "$SITE" '바뀐 파일 수가 같다는 것은 근거로 쓰지 않는다' "AC4: 바뀐 파일 수는 근거가 아니다"
assert_not_contains "$ALL" '근거로 쓴다' "AC4 음성: 「근거로 쓴다」 가 없다"

# AC5
once "$SITE" "$L_endmerge" "AC5: L(endmerge) 한 번"
assert_contains "$SITE" '만든 것: <에픽 번호> · <설계문서의 레포 상대경로> · PR #<번호> · <머지 커밋>' "AC5: 「만든 것」 줄의 꼴"

# AC6 앞 · AC7
assert_contains "$BACK" '질문을 가져오지 못했다 — <담당자가 적은 이유>' "AC6: 옮긴 파일이 없을 때 보이는 글"
assert_contains "$BACK" '「셀 수 없음」' "AC6: 「셀 수 없음」 으로 기록"
assert_contains "$BACK" '결과 파일의 판(<값>)을 읽지 못한다' "AC7: contract 가 2 가 아닐 때"
assert_contains "$BACK" '`status` 가 `ran` 이 아니면 `reason_text` 를 ' "AC7: status 가 ran 이 아닐 때"
assert_contains "$BACK" '`outcome` 이 `questions` 가 아니면 `result_line` 을 그대로 ' "AC7: outcome 이 questions 가 아닐 때"

# AC14
once "$SITE" "$L_resend" "AC14: L(resend) 한 번"
assert_contains "$SITE" '같은 spec 리뷰 안의 수정(「지적대로 고치기」 · 「직접 편집」 · 리뷰 라운드의 수정)으로는 다시 보내지 않는다' "AC14: 같은 spec 리뷰 안의 수정으로는 다시 보내지 않는다"

# P5 (고치면)
once "$SITE" "$L_p5" "P5: spec 리뷰로 넘어가는 조건 한 번"
assert_contains "$SITE" '결과를 가져오지 못했으면 그 사실을 보이고 기록한 뒤 간다' "P5: 결과를 가져오지 못했어도 보이고 기록한 뒤 간다"
assert_not_contains "$ALL" '질문을 한 번 띄우기 전에는 spec 리뷰를 시작하지 않는다' "P5 음성: 「그대로 두면」 쪽 문장이 없다"

# AC15
assert_contains "$CALL" '품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다' "AC15: qg 가 없을 때 알리는 글"
assert_contains "$(printf '%s\n' "$CALL" | grep -F '품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다')" '건너뛴다' "AC15: 그 줄에 건너뛴다"

# AC16
assert_contains "$SITE" 'ledger suite-lock --roadmap <로드맵>' "AC16: 스위트 잠금을 본다"
once "$SITE" "$L_suitewait" "AC16: L(suitewait) 한 번"
assert_contains "$SITE" '규모를 한 줄로 알리고 바로 보낸다' "AC16: 보내기 전에 규모를 한 줄로"

# AC22 — 다섯 상태는 불릿 머리
for head in '로드맵 —' '머지된 에픽 —' '설계문서가 브랜치에 있고 spec 승인 전인 에픽 —' 'spec 승인 뒤 · 머지 전인 에픽' '설계문서가 아직 없는 에픽 —'; do
  assert_eq "$(printf '%s\n' "$SITE" | grep -cF -- "- ${head}" | tr -d ' ')" "1" "AC22: 상태 불릿 머리 ${head}"
  assert_eq "$(printf '%s\n' "$SITE" | awk -v p="- ${head}" 'index($0, p)==1' | wc -l | tr -d ' ')" "1" "AC22: 줄 첫머리에 ${head}"
done
assert_contains "$SITE" 'PR 마다 한 번씩 보낸다' "AC22: 머지된 PR 이 여럿이면 PR 마다 한 번"

# AC23
once "$SITE" "$L_failed" "AC23: L(failed) 한 번"
assert_contains "$SITE" '지휘자가 스스로 다시 보내지 않는다' "AC23 양성: 지휘자가 스스로 다시 보내지 않는다"
assert_not_contains "$ALL" '스스로 다시 보낸다' "AC23 음성: 「스스로 다시 보낸다」 가 없다"
once "$SITE" '그 줄의 자리 칸은 기록 파일 이름과 같은 자리 글자(`spec` · `merged-pr<번호>` · `end` · `asked`)로 적는다' "AC23: 보내지 못한 리뷰의 쌓인 기록 줄이 이미 보낸 것 확인과 같은 자리 글자를 쓴다"

# AC24
once "$DISP" "$L_premerge" "AC24: L(premerge) 한 번"

# Review Focus 3 · 5
once "$SITE" "$L_alreadysent" "already-sent: L(alreadysent) 한 번"
assert_grep "$SITE" '리뷰할 diff 없음[^.]*그 사유를 그대로 보인다' "doc-path-skip: 「리뷰할 diff 없음」 과 「그 사유를 그대로 보인다」 가 한 문장에"

# Task 6 — 보관 · 기록 파일 · 묻기 · 행선
L_noquestions='질문이 하나도 없는 리뷰는 파일을 만들지 않고 `ledger add --section "쌓인 기록"` 으로 한 줄(자리 · 범위 · 결과 줄)만 남긴다 — 로드맵 끝과 이름으로 청한 로드맵은 예외로 늘 파일이 있다.'
L_branchspec='spec 승인 앞의 기록은 에픽 worktree 에서 에픽 브랜치에 커밋한다 — 에픽 PR 과 함께 머지된다. 그 밖(에픽 머지 뒤 · 로드맵 끝 · 이름으로 청함 — spec 승인 전 에픽 제외)의 기록은 로드맵마다 하나인 기록 브랜치에 쓴다.'
L_remade='기록 브랜치가 이미 머지됐으면 기본 브랜치에서 다시 만든다.'
L_pushnow='기록 브랜치에 쓴 기록은 답을 받은 직후 커밋하고 push 한다 — 다음 PR 을 기다리지 않는다.'
L_openpr='기록 브랜치의 PR 을 여는 때는 셋이다 — 「잘못 골랐다」 가 하나라도 있으면 바로, 로드맵을 닫을 때(그 PR 이 로드맵을 닫는 PR 이다), 로드맵이 이미 닫힌 뒤 이름으로 청한 리뷰면 답을 받은 직후. 그 밖에는 push 만 해 두고 로드맵을 닫을 때 함께 연다.'
L_prior='묻기 전에 이 로드맵의 기록 파일 전부(기본 브랜치의 `reviews/` · 에픽 브랜치의 것 · 기록 브랜치의 것)에서 정체(`id`)가 글자로 같은 질문을 찾아, 있으면 가장 최근 것의 질문 글과 답을 함께 적는다 — 「같은 질문」 이라 부르지 않고 그때의 질문 글을 보여 사용자가 판단하게 한다.'
L_waiting='담당자가 질문을 돌려주면 묻기 전에 — 바로 묻더라도 — `ledger add --section "기다리는 질문"` 으로 한 줄(에픽 번호 또는 `로드맵 밖` · 기대는 일 · 「의도 점검 질문 <k>개 — <보관 폴더 경로>」)을 적는다. 기대는 일은 spec 승인 앞이면 「spec 리뷰 시작」, 로드맵 끝이면 「로드맵을 닫는 PR」, 그 밖이면 「기록 파일 쓰기」 다. 답을 받았거나 「답하지 않음」 으로 기록 파일에 적은 뒤 그 줄을 지운다(`ledger drop`) — 질문을 띄운 뒤 기록 전에 끊겨도 그 줄이 남는다. 그 줄이 남아 있는 에픽의 spec 리뷰는 시작하지 않는다.'
L_wrongspec='spec 승인 앞에서 하나라도 있으면 spec 리뷰를 시작하지 않는다 — 그 에픽의 설계 대화로 돌아가 그 질문과 답을 입력으로 설계를 고치고, 고친 설계문서 커밋에 qg 를 다시 보낸다.'
FIXED='intent-critic 은 의도대로 만들었는지가 아니라 의도 자체(사용자가 고른 방향 · 기능 · 동작)가 맞는지를 점검한다. 아래 질문의 답은 판정을 바꾸지 않는다.'
P4_BRANCH='| spec 승인 뒤 · 머지 전 에픽: 재분해 신호로 보인다 — 설계 대화로 돌아가지 않는다.'

# AC6 보관
assert_contains "$KEEP" 'ledger resource-dir --roadmap <로드맵> --kind report --name qg-<대상>-<자리>-<날짜>' "AC6: 보관 폴더를 resource-dir 로 만든다"
assert_contains "$KEEP" '끝에 -2, -3 … 을 붙여 앞 사본을 덮지 않는다' "AC6: 같은 이름이면 -2, -3 을 붙여 덮지 않는다"
assert_contains "$KEEP" '`spec` · `merged-pr<번호>` · `end` · `asked`' "AC6: 보관 폴더의 자리 글자가 기록 파일 · 쌓인 기록 줄과 같다"

# AC10 기록 틀
for k in 'type: roadmap-review' 'roadmap:' 'epic:' 'site:' 'reviewed_base:' 'reviewed_head:' 'contract: 2' \
         '- 정체: <id>' '- 질문: <question>' '- 관찰:' '- qg 가 돌려준 상태: <state>' '- 같은 대상에 전에 물은 것:' '- 답 원문: <직접 쓴 글 그대로 | ->'; do
  assert_eq "$(starts "$TPL" "$k")" "1" "AC10 틀: 줄 첫머리 ${k} 가 한 번"
done
assert_contains "$KEEP" '<로드맵 폴더>/reviews/<YYYY-MM-DD>-<대상>-<자리>.md' "AC10: 기록 파일 이름 규칙"
once "$KEEP" "$L_noquestions" "AC10: L(noquestions) 한 번"
# AC10 계약 칸 이름 — 틀의 칸이 계약 2판 질문 칸 이름과 같다
SFF="$ROOT/plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md"
QCOLS="$(grep -F -- '- 질문 칸(차례대로):' "$SFF")"
[ -n "$QCOLS" ] && ok "계약 2판 질문 칸 줄을 읽었다" || no "계약 2판 질문 칸 줄이 없다 — 아래 칸 이름 단언이 공허하다"
for nm in '<id>' '<question>' '<observation 의 줄 전부>' '<state>' '<target_source>' '<target_id>' '<label>' '<quote>' '<evidence>'; do
  assert_contains "$TPL" "$nm" "AC10 계약 칸: 틀에 ${nm}"
  f="${nm#<}"; f="${f%>}"; f="${f% 의 줄 전부}"
  assert_contains "$QCOLS" "\`${f}\`" "AC10 계약 칸: ${f} 가 계약 2판 질문 칸에 있다"
done

# P2 (고치면)
assert_not_contains "$TPL" 'source_brief:' "P2: 기록 틀에 source_brief: 줄이 없다"
assert_not_contains "$ALL" '`source_brief:` 줄은 로드맵을 보는 리뷰' "P2 음성: 「그대로 두면」 쪽 L(sourcebrief) 가 없다"

# AC11 기록 브랜치
once "$KEEP" "$L_branchspec" "AC11: L(branchspec) 한 번"
once "$KEEP" "$L_pushnow" "AC11: L(pushnow) 한 번"
once "$KEEP" "$L_openpr" "AC11: L(openpr) 한 번"
once "$KEEP" "$L_remade" "record-branch-remade: L(remade) 한 번"

# P3 (고치면)
assert_contains "$KEEP" '<접두>roadmap-<로드맵 폴더 이름>-reviews' "P3: 기록 브랜치 이름이 레포 접두 뒤에 roadmap-<로드맵 폴더 이름>-reviews"
assert_contains "$(fence_with "$KEEP" 'branch_prefix')" 'repo_defaults.py" get branch_prefix)" || BP=""' "P3: 접두를 repo_defaults.py 로 얻는 펜스"
assert_not_contains "$ALL" 'docs/roadmap-' "P3 음성: 「그대로 두면」 쪽 docs/ 접두 이름이 없다"

# AC9 같은 대상에 전에 물은 것
once "$KEEP" "$L_prior" "AC9: L(prior) 한 번"
assert_contains "$KEEP" '글자가 같지 않으면 짝짓지 않는다' "AC9: 글자가 같지 않으면 짝짓지 않는다"
assert_contains "$ASK" '같은 대상에 전에 물은 것이 있어도 질문은 띄운다' "AC9 양성 짝: 전에 물은 것이 있어도 질문은 띄운다"
# AC9 찾는 명령 — 돌아가는 꼴(git grep 에는 -x 가 없다)과 찾는 자리(에픽 브랜치는 로컬 ref)
assert_contains "$KEEP" '`git grep -l -F -e "- 정체: <id>" <ref> -- "<로드맵 폴더>/reviews/"`' "AC9 찾기: 후보 파일을 git grep -l -F -e 로"
assert_contains "$KEEP" '`git show "<ref>:<경로>" | grep -n -x -F -e "- 정체: <id>"`' "AC9 찾기: 줄 전체 일치는 git show | grep -x 로"
assert_not_grep "$ALL" 'git grep[^`]* -[A-Za-wyz]*x' "AC9 찾기 음성: git grep 에 -x 를 넘기지 않는다(git grep 은 unknown switch 로 끝난다)"
assert_contains "$KEEP" '열린 에픽 브랜치마다 로컬 `<에픽 브랜치>`' "AC9 찾기: 에픽 브랜치는 로컬 ref 로 찾는다"
assert_not_contains "$ALL" 'origin/<에픽 브랜치>' "AC9 찾기 음성: push 되지 않은 에픽 브랜치 기록을 origin 으로 찾지 않는다"
for ref in '`origin/HEAD`(기본 브랜치)' '`origin/<기록 브랜치>`'; do
  assert_contains "$KEEP" "$ref" "AC9 찾기: 찾는 자리 ${ref}"
done

# AC8 질문 꼴
assert_contains "$QF" 'header: "의도 점검 <n>"' "AC8: 머리 의도 점검 <n>"
n1="$(printf '%s\n' "$QF" | grep -nF '{label: "의도다",' | head -1 | cut -d: -f1)"
n2="$(printf '%s\n' "$QF" | grep -nF '{label: "잘못 골랐다",' | head -1 | cut -d: -f1)"
n3="$(printf '%s\n' "$QF" | grep -nF '{label: "지금은 모르겠다",' | head -1 | cut -d: -f1)"
if [ -n "$n1" ] && [ -n "$n2" ] && [ -n "$n3" ] && [ "$n1" -lt "$n2" ] && [ "$n2" -lt "$n3" ]; then
  ok "AC8: 라벨 셋이 의도다 → 잘못 골랐다 → 지금은 모르겠다 차례"
else
  no "AC8: 라벨 셋의 차례가 qg 와 다르다(의도다=${n1:-없음} · 잘못 골랐다=${n2:-없음} · 지금은 모르겠다=${n3:-없음})"
fi
assert_not_contains "$QF" '(권장)' "AC8: 질문 틀에 추천 표시가 없다"
once "$ALL" "$FIXED" "AC8: qg 의 고정 문장이 파일에 한 번"
assert_contains "$ASK" "$FIXED" "AC8: 고정 문장이 묻기 절에"
assert_contains "$ASK" '한 호출에 많아야 셋' "AC8: 한 호출에 많아야 셋"
assert_contains "$ASK" '`state` 가 `묻지 않음` 인 질문' "AC8: 묻지 않음 인 질문만 묻는다"
assert_not_contains "$ALL" '같은 질문을 다시 묻지 않는다' "AC8 음성: qg 설명의 「같은 질문을 다시 묻지 않는다」 가 없다"
assert_not_contains "$ALL" '다음에 다시 물을 수 있다' "AC8 음성: qg 설명의 「다음에 다시 물을 수 있다」 가 없다"
# 질문 자리 목록(ask-sites) 행이 쓰는 앵커 · 끝 글자 — 앵커는 파일에서 한 번, 범위 안에 질문 하나와 비움 문구
ANCHOR='**의도 점검 질문.**'
QEND='라벨 셋의 글자와 순서는 qg 와 같다.'
assert_eq "$(printf '%s\n' "$ALL" | grep -oF -- "$ANCHOR" | wc -l | tr -d ' ')" "1" "AC8 질문 자리: 앵커가 파일에서 한 번"
assert_eq "$(starts "$ASK" "$ANCHOR")" "1" "AC8 질문 자리: 앵커가 줄 첫머리"
QRANGE="$(printf '%s\n' "$ALL" | awk -v a="$ANCHOR" -v e="$QEND" 'index($0, a){f=1} f{print} f&&index($0, e){exit}')"
assert_contains "$QRANGE" "$QEND" "AC8 질문 자리: 앵커 뒤에 끝 글자가 있다"
assert_contains "$QRANGE" '추천을 달지 않는다 — ' "AC8 질문 자리: 범위에 비움 문구"
assert_eq "$(printf '%s\n' "$QRANGE" | grep -oF 'AskUserQuestion' | wc -l | tr -d ' ')" "1" "AC8 질문 자리: 범위에 질문 호출 하나"
assert_eq "$(printf '%s\n' "$ALL" | grep -oF 'AskUserQuestion' | wc -l | tr -d ' ')" "1" "AC8 질문 자리: 파일 전체에 질문 호출 하나"

# P4 (고치면)
assert_contains "$QF" "$P4_BRANCH" "P4: 「잘못 골랐다」 설명에 spec 승인 뒤 · 머지 전 에픽 갈래"
assert_eq "$(starts "$WRONG" '- **spec 승인 뒤 · 머지 전 에픽.**')" "1" "P4: 행선 절에 spec 승인 뒤 · 머지 전 에픽 불릿"

# AC13 아직 묻지 못한 질문 · 다른 호출
assert_eq "$(starts "$ASK" '**아직 묻지 못한 질문.**')" "1" "AC13: 「아직 묻지 못한 질문」 굵은 머리가 줄 첫머리에 한 번"
WPARA="$(printf '%s\n' "$ASK" | awk 'index($0, "**아직 묻지 못한 질문.**")==1{f=1} f&&/^$/{exit} f')"
once "$WPARA" "$L_waiting" "AC13: L(waiting) 가 「아직 묻지 못한 질문」 문단에 한 번"
assert_contains "$ASK" '설계문서 점검의 질문과도 다른 메시지 · 다른 질문 호출' "AC13: 설계문서 점검의 질문과 다른 호출"
assert_contains "$ASK" '「답하지 않음」 으로 남기고 그 질문을 다시 띄우지 않는다' "AC13: 답하지 않은 질문은 「답하지 않음」 으로 남긴다"

# AC12 행선
once "$WRONG" "$L_wrongspec" "AC12: L(wrongspec) 한 번"
assert_contains "$WRONG" '/spec-distill:request-framing @<기록 파일의 레포 상대경로>' "AC12: 다음 세션 첫 줄"
assert_contains "$WRONG" '그 PR 이 머지된 뒤 친다' "AC12: 그 PR 이 머지된 뒤 친다"

# 최종 리뷰 수정 — 로드맵 끝 차례(I1) · waiting clear 의 종류(M1) · 돌아왔을 때 차례(M2) · rc 2 · rc 4(M3) · 쌓인 기록 칸(M5) · 보내는 글(측정)
L_endorder='걸음 7 의 마무리(상태 브랜치 지우기 · 자원 정리 · 표지 풀기)는 이 리뷰의 담당자가 돌아오고, 그 질문을 묻고 기록하고(답하지 않은 질문은 「답하지 않음」 으로, 결과를 가져오지 못한 리뷰는 「셀 수 없음」 으로 기록하고), 기록 브랜치를 push 하고 그 PR(로드맵을 닫는 PR)을 열고, 그 PR 의 걸음 5 스위트 대조가 끝난 뒤에 한다.'
L_rc2='rc 가 2 면 지휘자가 부른 꼴이 틀린 것이다 — 그 결과로는 보내지 않고 스크립트가 낸 stderr 줄을 보인 뒤, 부른 꼴을 고쳐 다시 부른다(`--pr` 은 `#` 없이 숫자만 쓴다).'
L_rc4='rc 가 4 면 먼저 `ledger pr-refresh --roadmap <로드맵> --session <세션> --epic <에픽>` 을 돌린 뒤 스크립트를 한 번 더 부른다 — 그래도 4 면 아래 줄대로 보내지 않고 스크립트가 낸 줄을 보인다.'
L_cells='`ledger add --roadmap <로드맵> --session <세션> --section "쌓인 기록" --cells "<에픽 번호 | 로드맵 밖> · qg 리뷰 · <자리 글자> · <대상> · <사유>"` 로 쓴다 — 에픽 칸에는 에픽 번호(로드맵 리뷰는 `로드맵 밖`), 절 칸에는 `qg 리뷰`, 글 칸에는 자리 글자를 맨 앞에 두고 대상 · 사유를 잇는다.'
L_cellsnq='칸 대응은 위 `### 보내지 못했거나 셀 수 없이 끝난 리뷰` 와 같다 — 에픽 칸 · 절 칸은 그대로이고 글 칸은 `<자리 글자> · <범위> · <결과 줄> · <보관 폴더 경로>` 이다.'
L_skilltool='부르는 길은 Skill 도구다 — skill 은 `quality-gates:quality-pipeline`, args 는 위 호출 줄에서 skill 이름 뒤의 글 전부(`range` 부터 끝까지)다.'
once "$SITE" "$L_endorder" "I1: 로드맵 끝 리뷰가 끝난 뒤에 걸음 7 의 마무리를 한다"
once "$ASK" '`waiting clear --roadmap <로드맵> --session <세션> --epic "<에픽 | 로드맵 밖>" --kind "옮긴 질문"`' "M1: waiting clear 가 옮긴 질문 종류만 내린다"
b_nofile="$(printf '%s\n' "$BACK" | grep -nF '1. 옮겨진 파일이 없으면 ' | head -1 | cut -d: -f1)"
b_contract="$(printf '%s\n' "$BACK" | grep -nF '`contract` 가 `2` 가 아니면' | head -1 | cut -d: -f1)"
if [ -n "$b_nofile" ] && [ -n "$b_contract" ] && [ "$b_nofile" -lt "$b_contract" ]; then
  ok "M2: 돌아왔을 때 — 옮겨진 파일이 없는 경우를 첫째로 본다"
else
  no "M2: 돌아왔을 때 — 옮겨진 파일이 없는 경우가 첫째가 아니다(없음=${b_nofile:-없음} · contract=${b_contract:-없음})"
fi
once "$SITE" "$L_rc2" "M3: 범위 스크립트 rc 2 — 부른 꼴을 고친다"
once "$SITE" "$L_rc4" "M3: 범위 스크립트 rc 4 — pr-refresh 뒤 한 번 더 부른다"
once "$SITE" "$L_cells" "M5: 보내지 못한 리뷰의 쌓인 기록 줄 칸 대응"
once "$KEEP" "$L_cellsnq" "M5: 질문 없는 리뷰의 쌓인 기록 줄 칸 대응"
once "$DISP" "$L_skilltool" "측정: 담당자는 Skill 도구로 부른다"
assert_contains "$(printf '%s\n' "$DISP" | awk 'index($0, "마지막 보고:")==1')" '절차에서 벗어난 것' "측정: 마지막 보고에 절차에서 벗어난 것"
assert_eq "$(printf '%s\n' "$DISP" | grep -cF 'suite_lock.py run' | tr -d ' ')" "0" "M4: 보내는 글 틀이 늘 싣는 것의 스위트 잠금 줄을 다시 싣지 않는다"
assert_contains "$DISP" '「늘 싣는 것」 가운데 자리 · 임시 폴더 · 금지 · 스위트 잠금 줄을 그대로 싣고' "M4 양성 짝: 늘 싣는 것의 줄은 그대로 싣는다"

# 통합 리뷰 뒤 반영 — 이미 보낸 것 · 로드맵 끝 PR 하나 · 스위트 잠금 · 돌아왔을 때 · 묻기 · qg 글자 결합
ssec() { awk -v h="$1" '/^```/{q=!q} !q&&$0==h{f=1;next} f&&!q&&/^##+ /{exit} f' "$QR"; }   # ### 절 본문(다음 ## · ### 머리 앞까지)
HEAD_="$(awk '/^## /{exit} 1' "$QR")"
SENT="$(ssec '### 이미 보낸 것')"
MERGED="$(ssec '### 에픽 머지 뒤 — 범위')"
FAILED="$(ssec '### 보내지 못했거나 셀 수 없이 끝난 리뷰')"
END_="$(ssec '### 로드맵 끝')"
LOCK="$(ssec '### 스위트 잠금')"
STORE="$(ssec '### 보관')"
RECF="$(ssec '### 기록 파일')"
RBR="$(ssec '### 기록 브랜치')"
BEAT="$(ssec '### 한 박자')"
for v in "$SENT" "$MERGED" "$FAILED" "$END_" "$LOCK" "$STORE" "$RECF" "$RBR" "$BEAT" "$HEAD_"; do
  [ -n "$v" ] && ok "### 절 본문을 읽었다(${#v}자)" || no "### 절 본문이 비었다 — 아래 단언이 공허하다"
done
L_stepmap='이 파일의 「걸음 N」 은 `conducting.md` 지휘 순환의 걸음이다 — 손으로 따르는 절차로 들어왔으면 걸음 5 는 손 절차 8(머지 전 확인), 걸음 7 은 손 절차 9(끝)로 읽고, 걸음 1 · 2 · 3 · 6 은 번호가 같다.'
L_order='보내는 차례는 아래 `### 이미 보낸 것` 의 확인 → 규모 줄 → `### 스위트 잠금` 의 확인 → 보관 폴더 만들기와 `## 자원` 에 적기(`## 보관과 기록 파일` 의 `### 보관`) → 보내기 → 살아 있는 agent 줄 적기다.'
L_liverow='`ledger add --roadmap <로드맵> --session <세션> --section "살아 있는 agent" --cells "<하니스가 준 agent 이름> · <에픽 번호 | 로드맵 밖> · qg 리뷰 · <worktree> · <때>"`'
L_livename='이름 칸 · 담당 칸은 다른 담당자처럼 하니스가 준 agent 이름이고, 그 담당자가 어느 자리의 것인지는 작업 표 줄의 근거 칸(보관 폴더 경로)으로 가린다. 에픽 칸의 글자는 쌓인 기록 · 기다리는 질문과 같다 — 로드맵 리뷰는 `로드맵 밖` 이다.'
L_sent0='자동으로 보내는 자리 셋(spec 승인 앞 · 에픽 머지 뒤 · 로드맵 끝)은 보내기 전에 그 자리를 이미 보냈는지 본다 — 압축이나 새 세션 뒤 들어가는 문장이 다시 불려도 한 번 더 보내지 않는다.'
L_sent1='먼저 그 자리의 보관 폴더(`ledger resources --roadmap <로드맵>` 의 경로 칸)마다 아래를 차례로 보고 처음 맞는 줄대로 한다 — 끝난 리뷰는 다시 잇지 않는다.'
L_sent2='1. 끝난 리뷰 — 그 폴더 경로를 글 칸에 담은 쌓인 기록 `qg 리뷰` 줄이 있거나, 그 폴더를 「보관 사본:」 으로 가리키는 기록 파일(아래 `### 같은 대상에 전에 물은 것` 의 찾는 자리 셋)이 있으면 아무것도 하지 않는다.'
L_sent3='2. 도는 중 — `ledger live-agent --roadmap <로드맵> --epic <에픽 번호 | 로드맵 밖> --work "qg 리뷰"` 가 낸 이름 가운데 근거 칸이 그 폴더인 `## 작업` 줄의 담당이 있으면 보내지 않고 그 담당자를 기다린다.'
L_sent4='3. 묻는 중 — `## 기다리는 질문` 에 그 폴더를 가리키는 줄이 있으면 `## 묻기` 대로 묻는다.'
L_sentempty='4. 결과가 왔다 — 그 폴더 안에 `intent-return.md` 가 있으면 그 파일로 `## 돌아왔을 때` 를 잇는다.'
L_sentasked='범위를 얻은 뒤에는 `qg-<에픽>-asked-` 로 시작하는 보관 폴더도 본다 — 그 안 `intent-return.md` 의 `reviewed_base` · `reviewed_head` 가 이 PR 의 `start:` · `end:` 와 같으면 사용자가 이름으로 먼저 청해 같은 범위를 이미 본 것이라 다시 보내지 않는다.'
L_sentspec='- spec 승인 앞 — 자리 글자는 `spec` 이다. 보낸 횟수(`qg-<에픽>-spec-` 로 시작하는 보관 폴더 수)가 보내도 되는 횟수(1 + 글 칸이 `spec-resend` 로 시작하는 그 에픽의 쌓인 기록 줄 수)보다 적을 때만 보낸다. 줄의 차례나 커밋 해시로 가리지 않는다.'
L_sentend='- 로드맵 끝 — 자리 글자는 `end` 다. 로드맵마다 한 번이라 `qg-roadmap-end-` 로 시작하는 보관 폴더도, 글 칸이 `end` 로 시작하는 쌓인 기록 줄도 없을 때만 보낸다. 기록 파일 머리만 기록 브랜치에 커밋돼 있고 보관 폴더가 없으면 머리를 다시 커밋하지 않고 그 머리로 보낸다.'
L_sentasks='이름으로 청한 리뷰에는 이 확인을 쓰지 않는다 — 사용자가 청했으므로 이미 보낸 리뷰가 있어도 보낸다.'
L_fetchrange='범위 스크립트를 부르기 전에 `git fetch origin` 을 돌린다 — 걸음 1 의 받아오기 뒤에 머지된 PR 이면 머지 커밋이 아직 이 레포에 없다.'
L_specline='보관 폴더가 있는 리뷰의 줄은 글 칸 끝에 그 폴더 경로를 덧붙인다 — 위 `### 이미 보낸 것` 이 그 폴더를 끝난 리뷰로 보고 돌 때마다 다시 기록하지 않는다.'
L_qgdrop='절이 `qg 리뷰` 인 쌓인 기록 줄은 로드맵을 닫는 PR(기록 브랜치의 PR 이 없으면 걸음 7 의 기록만 담은 로드맵 수정 PR)만 본문에 싣고 뺀다 — 걸음 6 의 로드맵 수정 PR 과 로드맵 중간의 기록 브랜치 PR 은 이 줄을 싣지도 빼지도 않는다.'
L_qgpending='`ledger pending` 은 절 칸을 보이지 않으니 글 칸 첫머리의 자리 글자로 가린다.'
L_endheads='머리를 커밋할 때 `reviewed_base` · `reviewed_head` 는 `"-"` 로 두고, 담당자가 돌아오면 결과 파일의 값으로 채워 질문과 함께 커밋한다 — 보내기 전에는 결과 파일이 없다.'
L_endpath='보낼 때 사용자에게 알린다 — 「모든 에픽이 머지돼 경로 없이 지휘자를 부르면 『끝나지 않은 로드맵이 없다』 로 멈춘다. 로드맵을 닫을 때까지 다시 부를 때는 `/spec-distill:epic-conductor <로드맵>` 처럼 로드맵 경로를 붙인다.」'
L_onepr='걸음 7 이 로드맵 수정 PR 본문 `## 지휘 기록` 에 싣는 것(쌓인 기록 · 끝에서 끝으로 걸어 본 결과)은 그 PR(로드맵을 닫는 PR) 본문에 싣는다 — 기록만 담은 로드맵 수정 PR 을 따로 열지 않는다.'
L_onefile='지휘 기록은 PR 본문에만 싣고 기록 브랜치에 파일로 커밋하지 않는다.'
L_onepending='본문에 실을 `ledger pending --roadmap <로드맵>` 은 이 리뷰 자신의 쌓인 기록 줄을 적은 뒤에 읽고, 실은 줄은 걸음 6 처럼 `ledger drop` 으로 뺀다.'
L_onenopr='기록 브랜치의 PR 이 없으면(quality-gates 가 설치돼 있지 않거나 기록 브랜치를 만들지 못했으면) 걸음 7 대로 기록만 담은 로드맵 수정 PR 에 싣는다.'
L_lockfree='그 줄이 `스위트 잠금: 비어 있음` 이거나, `스위트 잠금:` 뒤의 까닭이 `주인 프로세스가 끝났다(남은 잠금)` · `주인 기록 없는 잠금` 이면 잡혀 있지 않은 것으로 보고 보낸다 — 남은 잠금은 다음에 잠금을 잡는 쪽이 치운다.'
L_lockorder='걸음 6 에서 다음 PR 의 스위트 대조와 qg 담당자 보내기가 겹치면 기본은 스위트 대조를 먼저 하고 그 대조가 끝난 뒤 보내는 것이다 — 머지 명령 줄이 사용자의 다음 머지를 막고, qg 리뷰는 조언이다. 일의 모양이 다르면 판단하고 그 이유를 지휘 기록에 적는다.'
L_filtered='result.md 의 `## intent-critic` 에 `이미 답한 질문이라 거른 질문:` · `이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록이 있으면 그 목록을 글자 그대로'
L_innertests='전체 스위트를 따로 돌리지 않는다 — qg 안의 테스트 실행은 그대로 둔다.'
L_shownotice='담당자가 보고한 qg 공시 줄(「원문 없음」 · 「로드맵 없음」 · 거른 수 등)과 거른 질문 목록도 그 자리 이름과 함께 보인다.'
L_relay='담당자가 미리 받은 답 밖의 질문에서 멈춰 (a) 쉬운 요약 (b) 질문 원문을 돌려보냈으면 아래 차례를 보지 않는다 — 먼저 그 담당자의 worktree 가 아직 있는지 본다 — 지워졌으면 이어 부를 수 없으니 사용자에게 옮기지 않고 아래 1 로 간다.'
L_relayname='있으면 `<SD>/references/conductor-dispatch.md` 의 `## 사람 자리` 대로 사용자에게 옮기고, 답을 같은 담당자에게 이어 불러(`SendMessage`) 돌려준다. 「셀 수 없음」 으로 닫지 않는다. 그 relay 파일의 폴더는 `ledger resource-dir --roadmap <로드맵> --kind relay --name <에픽>` 이고, 로드맵 리뷰의 담당자면 `--name roadmap` 이다.'
L_contractrec='「결과 파일의 판(<값>)을 읽지 못한다」 를 보이고, 그 자리의 리뷰를 1 과 같이 「셀 수 없음」 으로 기록한다.'
L_dashline='`status` 가 `ran` 이 아니면 `reason_text` 를 보이고 끝낸다 — `reason_text` 가 `-` 면 `result_line` 을 함께 보인다.'
L_samerange='4. `status` 가 `ran` 이면 `reviewed_base` · `reviewed_head` 가 호출 줄에 쓴 시작 · 끝 커밋과 같은지 앞 8자로 견준다. 다르면(`-` 포함) 질문을 옮기지 않고 「결과 파일이 보낸 범위의 것이 아니다(<reviewed_base 앞 8자>..<reviewed_head 앞 8자>)」 를 보이고, 그 자리의 리뷰를 1 과 같이 「셀 수 없음」 으로 기록한다.'
L_storewhen='폴더는 스위트 잠금을 확인한 뒤 보내기 바로 전에 만들고, 만들면 바로 `ledger add --roadmap <로드맵> --session <세션> --section "자원"` 으로 `## 자원` 에 적는다'
L_range8='범위는 `<시작 8자>..<끝 8자>` 로 적는다.'
L_rbrsuite='- 지휘자가 여는 이 PR 들도 머지 전에 걸음 5 의 스위트 대조를 거친다 — 걸음 6 의 로드맵 수정 PR 과 같다.'
L_rbrmid='- 「잘못 골랐다」 로 로드맵 중간에 여는 기록 브랜치 PR 은 쌓인 기록을 싣지도 빼지도 않는다.'
L_waitread='그 줄은 에픽마다 `python3 "<SD>"/scripts/control_plane.py show <로드맵> <에픽>` 의 `기다리는 질문:` 칸으로 읽는다. 에픽 칸이 `로드맵 밖` 인 줄을 내는 명령은 없다 — 기계 상태 파일(`ledger suite-lock --roadmap <로드맵>` 첫 줄의 두 단계 위 폴더에 있는 `machine.md`)의 `## 기다리는 질문` 절을 읽는다.'
L_nogain='- 이 질문의 선택지 설명은 얻음 · 내줌 꼴을 쓰지 않는다 — qg 의 꼴을 따른다.'
L_fill='- `target_source` 가 `diff` 면 의심하는 것의 앞부분을 「바뀐 파일 `target_id`」 로 쓴다. `evidence` 가 `-` 면 「(<근거의 종류>)」 괄호를 빼고 「근거로 본 것: <관찰 첫 줄>」 로 잇는다.'
once "$HEAD_" "$L_stepmap" "나 G: 걸음 번호는 지휘 순환의 것 — 파일 머리에 한 번"
once "$BEAT" "$L_order" "가 · 나: 보내는 차례(이미 보낸 것 → 규모 → 잠금 → 폴더와 자원 → 보내기 → agent 줄)가 한 박자에 한 번"
once "$BEAT" "$L_liverow" "재리뷰 지적 4: 살아 있는 agent 줄의 칸 — 이름 칸은 하니스가 준 이름 · 에픽 칸은 로드맵 밖"
once "$BEAT" "$L_livename" "나 A: 이름 칸 · 에픽 칸의 글자"
assert_not_contains "$ALL" '<이름> · <대상> · qg 리뷰' "나 A 음성: 살아 있는 agent 줄의 에픽 칸에 <대상>(roadmap) 이 없다(양성 짝: L(liverow))"
for v in L_sent0 L_sent1 L_sent2 L_sent3 L_sent4 L_sentempty L_sentasked L_sentspec L_sentend L_sentasks; do
  once "$SENT" "${!v}" "M8 · 나 C · 나 4(가): 이미 보낸 것 — ${v}"
done
assert_not_contains "$ALL" '로 시작하는 보관 폴더가 있거나 `## 쌓인 기록`' "M8 음성: 보관 폴더가 있다는 것만으로 이미 보낸 것으로 치던 옛 문장이 없다(양성 짝: L(sent2) · L(sentempty))"
assert_not_contains "$ALL" '이미 보냈는지 보는 확인은 걸음 6 의 자리에만 쓴다' "나 C 음성: 이미 보낸 것 확인을 걸음 6 에만 두던 옛 문장이 없다(양성 짝: L(sent0))"
once "$SITE" '(위 `### 이미 보낸 것` 의 확인은 자동으로 보내는 자리에만 쓴다)' "나 C: 이름으로 청한 머지된 에픽은 확인을 쓰지 않는다"
once "$MERGED" "$L_fetchrange" "나 D: 범위 스크립트 앞에 fetch"
f_n="$(printf '%s\n' "$MERGED" | grep -nF -- "$L_fetchrange" | head -1 | cut -d: -f1)"
r_n="$(printf '%s\n' "$MERGED" | grep -nF -- '- 범위는 `python3 "<SD>"/scripts/merged_pr_range.py' | head -1 | cut -d: -f1)"
if [ -n "$f_n" ] && [ -n "$r_n" ] && [ "$f_n" -lt "$r_n" ]; then ok "나 D: fetch 줄이 범위 스크립트 줄보다 앞"; else no "나 D: fetch 줄이 범위 스크립트 줄보다 앞이 아니다(fetch=${f_n:-없음} · 스크립트=${r_n:-없음})"; fi
once "$FAILED" "$L_specline" "재리뷰 지적 3: 보관 폴더가 있는 리뷰의 쌓인 기록 줄은 폴더 경로를 싣는다"
once "$FAILED" "$L_qgdrop" "나 B · M6: qg 리뷰 줄은 로드맵을 닫는 PR 에서만 뺀다"
once "$FAILED" "$L_qgpending" "나 B: pending 출력에서 qg 리뷰 줄을 가리는 길"
once "$END_" "$L_endheads" "가 범위 밖: 로드맵 끝 기록 머리의 reviewed_base · reviewed_head"
once "$END_" "$L_endpath" "나 N: 로드맵 끝에서 보낼 때 경로를 붙여 다시 부르라고 알린다"
for v in L_onepr L_onefile L_onepending L_onenopr; do once "$END_" "${!v}" "M6(사용자 결정 하나로 묶는다): ${v}"; done
once "$LOCK" "$L_lockfree" "나 H(1): 비었거나 주인이 끝난 잠금이면 보낸다"
SL="$(cat "$ROOT/plugins/spec-distill/scripts/suite_lock.py")"
assert_contains "$SL" '"스위트 잠금: 비어 있음"' "나 H(1) 결합: 비어 있음 글자가 suite_lock.py 에 있다"
assert_contains "$SL" '"주인 프로세스가 끝났다(남은 잠금)"' "나 H(1) 결합: 주인이 끝난 잠금 글자가 suite_lock.py 에 있다"
assert_contains "$SL" '"주인 기록 없는 잠금"' "나 H(1) 결합: 주인 기록 없는 잠금 글자가 suite_lock.py 에 있다"
assert_contains "$SL" '"스위트 잠금: %s — 주인 %s · 잡은 시각 %s"' "나 H(1) 결합: 잡힌 잠금 줄이 「스위트 잠금: <까닭> — 주인 …」 꼴이다"
once "$LOCK" "$L_lockorder" "나 H(2): 다음 PR 의 스위트 대조가 먼저(기본값과 판단)"
once "$DISP" "$L_filtered" "나 J: 마지막 보고에 거른 질문 목록 둘"
once "$DISP" "$L_innertests" "나 H(3): qg 안의 테스트 실행은 그대로 둔다"
once "$DISP" "$L_shownotice" "나 J: 지휘자가 보일 목록에 qg 공시 줄 · 거른 질문 목록"
once "$BACK" "$L_relay" "나 E · 재리뷰: 옮기기 전에 담당자 worktree 가 있는지 본다"
once "$BACK" "$L_relayname" "나 E: 사람 자리대로 옮기고 이어 부른다 · 로드맵 리뷰 담당자의 relay 폴더 이름"
b_first="$(printf '%s\n' "$BACK" | grep -v '^$' | head -1)"
assert_eq "$(starts "$b_first" "$L_relay")" "1" "나 E: 사람 자리 갈래가 돌아왔을 때 절의 맨 앞(첫 비지 않은 줄)"
once "$BACK" "$L_contractrec" "가 넷째: contract 가 2 가 아니어도 셀 수 없음으로 기록"
once "$BACK" "$L_dashline" "가 계약 2판 독자: reason_text 가 - 면 result_line 을 함께"
once "$BACK" "$L_samerange" "가 둘째: 결과 파일이 보낸 범위의 것인지"
once "$STORE" "$L_storewhen" "M8 · 나: 보관 폴더는 잠금 확인 뒤 보내기 직전에 만들고 바로 자원에 적는다"
once "$RECF" "$L_range8" "나 C: 쌓인 기록 줄의 범위 꼴"
once "$RBR" "$L_rbrsuite" "나 F: 지휘자가 여는 PR 의 걸음 5 확인은 스위트 대조(걸음 6 과 같음)"
assert_not_contains "$ALL" '걸음 5 의 확인을 거친다' "나 F 음성: 에픽 없는 PR 에 「걸음 5 의 확인」 을 쓰던 옛 문장이 없다(양성 짝: L(rbrsuite))"
once "$RBR" "$L_rbrmid" "M6: 로드맵 중간의 기록 PR 은 쌓인 기록을 싣지도 빼지도 않는다"
once "$WPARA" "$L_waitread" "나 A: 기다리는 질문 절을 읽는 길이 「아직 묻지 못한 질문」 문단에"
assert_not_contains "$ALL" '돌려줬는데 바로 묻지 못하면' "나 C 음성: 바로 묻지 못할 때만 기다리는 질문 줄을 적던 옛 문장이 없다(양성 짝: L(waiting))"
once "$ASK" "$L_nogain" "나 O: 질문 설명의 꼴 예외"
once "$ASK" "$L_fill" "가 계약 2판 독자: diff 표기 · evidence - 괄호 빼기"
# 좁은 재리뷰 1차 뒤 — 끝난 리뷰 · 차례 · spec 다시 보내기 표지 · 작업 줄 · 없음 표지 YAML
L_sentlost='5. 돌아오지 못한 리뷰 — 그 밖(빈 폴더 — 세션이 끊긴 경우 등)이면 「질문을 가져오지 못했다 — 담당자가 돌아오지 않았다」 를 보이고 그 자리의 리뷰를 「셀 수 없음」 으로 기록한다'
L_sentmerged='`qg-<에픽>-merged-pr<번호>-` 로 시작하는 보관 폴더도, 글 칸이 `merged-pr<번호>` 로 시작하는 쌓인 기록 줄도 없을 때만 보낸다.'
L_workrow='`## 작업` 표에 `ledger add --roadmap <로드맵> --session <세션> --section "작업" --cells "qg 리뷰 · <자리 글자> · <에픽 번호 | 로드맵 밖> · 리뷰 중 · <같은 agent 이름> · <보관 폴더 경로>"` 로 한 줄을 적는다.'
L_resendmark='- 그 두 사건으로 설계 대화에 돌아갈 때 `ledger add --roadmap <로드맵> --session <세션> --section "쌓인 기록" --cells "<에픽> · qg 리뷰 · spec-resend · <사건>"` 로 표지 한 줄을 적는다 — 위 `### 이미 보낸 것` 이 이 줄로 다시 보내도 되는 횟수를 센다.'
L_none='- 머리 칸의 없음 표지는 따옴표에 싸서 `"-"` 로 적는다 — 따옴표 없는 `-` 가 하나라도 있으면 qg 가 머리 전체를 YAML 로 읽지 못해 이 파일의 `roadmap:` 을 따라가지 못한다. 결과 파일의 값이 `-` 여도 같다.'
once "$SENT" "$L_sentlost" "재리뷰 지적 3: 근거 다섯째 — 돌아오지 못한 리뷰"
once "$SENT" "$L_sentmerged" "재리뷰 지적 3: 에픽 머지 뒤는 폴더도 쌓인 기록 줄도 없을 때만 보낸다"
once "$BEAT" "$L_workrow" "재리뷰 지적 4: 작업 표 줄 — 담당은 같은 agent 이름 · 근거는 보관 폴더"
SPECSEC="$(ssec '### spec 승인 앞')"
once "$SPECSEC" "$L_resendmark" "재리뷰 지적 2: 설계 대화로 돌아갈 때 spec-resend 표지를 적는다"
once "$RECF" "$L_none" "재리뷰 지적 1: 머리 칸의 없음 표지는 따옴표에 싼다"
ev="$(printf '%s\n' "$SENT" | grep -oE '^[1-9]\. (끝난 리뷰|도는 중|묻는 중|결과가 왔다|돌아오지 못한 리뷰) —' | tr '\n' ',')"
assert_eq "$ev" "1. 끝난 리뷰 —,2. 도는 중 —,3. 묻는 중 —,4. 결과가 왔다 —,5. 돌아오지 못한 리뷰 —," "재리뷰 지적 3: 근거 다섯의 차례(끝난 리뷰가 먼저)"
assert_not_contains "$ALL" '지금 보낼 끝 커밋' "재리뷰 지적 2 음성: spec 승인 앞을 끝 커밋으로 가르던 문장이 없다(양성 짝: L(sentspec))"
assert_not_contains "$ALL" '보관 폴더 이름(`qg-<대상>-<자리>-<날짜>`)을 써서' "재리뷰 지적 4 음성: 이름 칸을 보관 폴더 이름으로 쓰던 문장이 없다(양성 짝: L(livename))"
for k in 'epic: <에픽 번호 | "-">' 'reviewed_base: <결과 파일의 값 | "-">' 'reviewed_head: <결과 파일의 값 | "-">'; do
  assert_eq "$(starts "$TPL" "$k")" "1" "재리뷰 지적 1: 기록 틀 머리 ${k}"
done
# 틀 머리의 자리표를 채운 글(첫 갈래 · 없음 표지 갈래)이 YAML 로 읽히고 roadmap 키가 남는지 — PyYAML 이 없으면 실패로 드러낸다
YT="$(mktemp -d)" || YT=""
[ -n "$YT" ] && [ -d "$YT" ] || { no "재리뷰 지적 1: 임시 폴더를 만들지 못했다"; finish; exit 1; }
trap 'rm -rf "$YT"' EXIT
cat > "$YT/tpl_yaml.py" <<'QG_TPL_YAML'
import re, sys
try:
    import yaml
except ImportError:
    print("PYYAML_MISSING"); sys.exit(0)
lines = sys.stdin.read().split("\n")
i = lines.index("---"); j = lines.index("---", i + 1)
head = lines[i + 1:j]
PH = re.compile(r"<([^<>]*)>")
def fill(none):
    out, keys = [], []
    for ln in head:
        def sub(m):
            alts = [a.strip() for a in m.group(1).split(" | ")]
            nn = [a for a in alts if a in ("-", '"-"')]
            if none and nn:
                keys.append(ln.split(":", 1)[0])
                return nn[0]
            return alts[0]
        out.append(PH.sub(sub, ln))
    return "\n".join(out) + "\n", keys
for none in (False, True):
    text, keys = fill(none)
    try:
        d = yaml.safe_load(text)
    except Exception as e:
        print("YAML_FAIL %s %s" % (none, type(e).__name__)); continue
    if not isinstance(d, dict) or "roadmap" not in d:
        print("NO_ROADMAP %s" % none); continue
    bad = [k for k in keys if d.get(k) != "-"]
    print("OK %s %d %s" % (none, len(keys), ",".join(bad) or "-"))
QG_TPL_YAML
yaml_out="$(printf '%s\n' "$TPL" | PYTHONDONTWRITEBYTECODE=1 python3 "$YT/tpl_yaml.py")"
assert_not_contains "$yaml_out" 'PYYAML_MISSING' "재리뷰 지적 1: PyYAML 이 있어 틀 머리를 YAML 로 읽어 본다(없으면 이 락이 재지 못한다)"
assert_contains "$yaml_out" 'OK False 0 -' "재리뷰 지적 1: 첫 갈래로 채운 틀 머리가 YAML 로 읽히고 roadmap 키가 남는다"
assert_contains "$yaml_out" 'OK True 3 -' "재리뷰 지적 1: 없음 표지 갈래(셋)로 채운 틀 머리가 YAML 로 읽히고 그 칸들이 - 로 읽힌다"

# 가 다섯째 · 나 K — qg 글자를 qg 파일에서 읽어 견준다(R4 가 바꾸면 빨개진다)
SKQ="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
ENDLBL="$(awk 'index($0, "범위 모드는 이미 있는 커밋을 본다"){f=1} f&&index($0, "{label: \""){sub(/^[^{]*\{label: "/, ""); sub(/".*/, ""); print; exit}' "$SKQ")"
LOWLBL="$(awk 'index($0, "header: \"낮춘 지적\""){f=1;next} f&&index($0, "+ {label: \""){sub(/^.*\+ \{label: "/, ""); sub(/".*/, ""); print; exit}' "$SKQ")"
[ -n "$ENDLBL" ] && ok "qg 결합: 범위 모드 끝내기 질문의 첫 라벨을 읽었다(${ENDLBL})" || no "qg 결합: 범위 모드 끝내기 질문의 라벨을 qg SKILL.md 에서 읽지 못했다 — 아래 단언이 공허하다"
[ -n "$LOWLBL" ] && ok "qg 결합: 낮춘 지적 질문의 그대로 두기 라벨을 읽었다(${LOWLBL})" || no "qg 결합: 낮춘 지적 질문의 라벨을 qg SKILL.md 에서 읽지 못했다 — 아래 단언이 공허하다"
assert_contains "$DISP" "끝내기 질문에는 「${ENDLBL}」" "qg 결합: 미리 받은 답 — 끝내기 질문의 라벨이 qg SKILL.md 와 같다"
assert_contains "$DISP" "모든 묶음에 「${LOWLBL}」" "qg 결합: 미리 받은 답 — 낮춘 지적 질문의 라벨이 qg SKILL.md 와 같다"
CV="$(grep -F -- '- `contract` — 꼴의 판(' "$SFF" | sed -n 's/.*꼴의 판(`\([0-9][0-9]*\)`).*/\1/p' | head -1)"
[ -n "$CV" ] && ok "qg 결합: 계약 판을 읽었다(${CV})" || no "qg 결합: 계약 판을 state-file-format.md 에서 읽지 못했다 — 아래 단언이 공허하다"
assert_eq "$(starts "$TPL" "contract: ${CV}")" "1" "qg 결합: 기록 틀의 contract 가 qg 계약 판과 같다"
assert_contains "$BACK" "\`contract\` 가 \`${CV}\` 가 아니면" "qg 결합: 돌아왔을 때의 판 검사가 qg 계약 판과 같다"
HCOLS="$(grep -F -- '- 머리 칸(차례대로):' "$SFF")"
[ -n "$HCOLS" ] && ok "qg 결합: 계약 머리 칸 줄을 읽었다" || no "qg 결합: 계약 머리 칸 줄이 없다 — 아래 칸 이름 단언이 공허하다"
for nm in contract status reason_text outcome result_line reviewed_base reviewed_head other_teams; do
  assert_contains "$ALL" "$nm" "qg 결합: qg-review.md 가 머리 칸 ${nm} 를 쓴다"
  assert_contains "$HCOLS" "\`${nm}\`" "qg 결합: 머리 칸 ${nm} 가 계약 2판 머리 칸에 있다"
done
FL="$(grep -oE '`이미 [^`]*거른 질문:`' "$SFF" | tr -d '`' | sort -u)"
assert_eq "$(printf '%s\n' "$FL" | grep -c . | tr -d ' ')" "2" "qg 결합: 거른 질문 목록 머리 둘을 state-file-format.md 에서 읽었다"
while IFS= read -r h; do
  [ -n "$h" ] && assert_contains "$DISP" "\`${h}\`" "qg 결합: 보내는 글의 거른 질문 목록 머리 「${h}」 가 qg 계약과 같다"
done <<EOF
$FL
EOF
# 레포 전용 값
for lit in 'origin/main' 'feature/' 'docs/superpowers'; do
  assert_not_contains "$ALL" "$lit" "레포 전용 값이 없다: ${lit}"
done
assert_contains "$ALL" 'origin/HEAD' "레포 전용 값 양성 짝: 기본 브랜치는 origin/HEAD"

# ── conducting.md 의 들어가는 문장(AC2 · AC13) — 절차는 qg-review.md 에만 있다
CD="$ROOT/plugins/spec-distill/references/conducting.md"
QE='`<SD>/skills/epic-conductor/references/qg-review.md` 를 읽고 그 자리('
LOOP="$(awk '$0=="## 지휘 순환"{f=1;next} f&&/^## /{exit} f' "$CD")"
MAN="$(awk '$0=="## 손으로 따르는 절차"{f=1;next} f&&/^## /{exit} f' "$CD")"
lstep() { printf '%s\n' "$LOOP" | awk -v n="$1" 'index($0, "### " n ". ")==1{f=1;next} f&&/^### /{exit} f'; }
mstep() { printf '%s\n' "$MAN" | awk -v n="$1" 'index($0, n ". ")==1{f=1;print;next} f&&/^[1-9]\. /{exit} f'; }
lhead() { printf '%s\n' "$LOOP" | awk 'index($0, "### 1. ")==1{exit} 1'; }
mhead() { printf '%s\n' "$MAN" | awk 'index($0, "1. ")==1{exit} 1'; }
cnt() { printf '%s\n' "$1" | grep -oF -- "$2" | wc -l | tr -d ' '; }
[ -n "$LOOP" ] && [ -n "$MAN" ] && ok "conducting.md 의 두 절을 읽었다" || no "conducting.md 의 두 절이 비었다 — 아래 단언이 공허하다"
for pair in "3:spec 승인 앞" "6:에픽 머지 뒤" "7:로드맵 끝"; do
  n="${pair%%:*}"; name="${pair#*:}"
  assert_eq "$(cnt "$(lstep "$n")" "$QE")" "1" "지휘 순환 걸음 ${n}: 들어가는 문장 한 번"
  assert_contains "$(lstep "$n")" "${QE}「${name}」)" "지휘 순환 걸음 ${n}: 자리 이름 ${name}"
done
for pair in "3:spec 승인 앞" "6:에픽 머지 뒤" "9:로드맵 끝"; do
  n="${pair%%:*}"; name="${pair#*:}"
  assert_eq "$(cnt "$(mstep "$n")" "$QE")" "1" "손 절차 ${n}: 들어가는 문장 한 번"
  assert_contains "$(mstep "$n")" "${QE}「${name}」)" "손 절차 ${n}: 자리 이름 ${name}"
done
for w in "지휘 순환:$(lhead)" "손 절차:$(mhead)"; do
  t="${w%%:*}"; b="${w#*:}"
  assert_eq "$(cnt "$b" "${QE}「이름으로 청함」)")" "1" "${t} 머리: 이름으로 청함 한 번"
  assert_eq "$(cnt "$b" "$QE")" "1" "${t} 머리: 들어가는 문장은 그 한 번뿐"
done
assert_eq "$(cnt "$(lstep 1)" "${QE}「아직 묻지 못한 질문」")" "1" "지휘 순환 걸음 1: 아직 묻지 못한 질문 한 번"
assert_eq "$(cnt "$(mstep 1)" "${QE}「아직 묻지 못한 질문」")" "1" "손 절차 1: 아직 묻지 못한 질문 한 번"
# AC2 음성 + 양성 짝 — 절차가 새지 않았다
CDALL="$(cat "$CD")"
assert_not_contains "$CDALL" '로드맵 시작 커밋부터' "AC2: 범위 절차(로드맵 시작 커밋부터)가 conducting.md 에 없다"
assert_contains "$(lstep 7)" "$QE" "AC2 양성 짝: 걸음 7 은 들어가는 문장을 가진다"
for lit in 'intent-return.md' 'merged_pr_range.py' '의도 점검 <n>' 'reviews/<YYYY-MM-DD>' 'qg-<대상>-<자리>'; do
  assert_not_contains "$CDALL" "$lit" "절차가 새지 않았다: conducting.md 에 ${lit} 없음"
  assert_contains "$ALL" "$lit" "양성 짝: qg-review.md 에는 ${lit} 가 있다"
done
assert_contains "$(lstep 7)" '품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다' "걸음 7: 설치 안 됨 공시 문장이 남아 있다"
# conducting.md 걸음 6 · 7 — 한 구절씩
L_cd6='아직 설계문서로 옮길(`ledger flush`) 줄은 두고, 절이 `qg 리뷰` 인 줄은 싣지 않고 둔다(로드맵을 닫는 PR 이 싣고 뺀다).'
L_cd7='기록만 담은 로드맵 수정 PR(로드맵을 닫는 기록 브랜치 PR 이 있으면 그 PR)로 싣고'
assert_eq "$(cnt "$(lstep 6)" "$L_cd6")" "1" "재리뷰 지적 6: conducting.md 걸음 6 기록 칸 — qg 리뷰 줄은 싣지 않고 둔다"
assert_eq "$(cnt "$(lstep 7)" "$L_cd7")" "1" "재리뷰 지적 5: conducting.md 걸음 7 — 닫는 기록 브랜치 PR 이 있으면 그 PR"
assert_not_contains "$(lstep 6)" '아직 설계문서로 옮길(`ledger flush`) 줄은 두고.' "나 B 음성: 걸음 6 의 옛 구절이 없다(양성 짝: L(cd6))"

SK="$ROOT/plugins/spec-distill/skills/epic-conductor/SKILL.md"
SKSEC() { awk -v h="$1" '/^```/{q=!q} !q&&$0==h{f=1;next} f&&!q&&/^## |^### /{exit} f' "$SK"; }
for lit in 'qg 담당자(spec 승인 앞 1 · 머지된 PR 마다 1)' '로드맵 끝 qg 담당자 1'; do
  assert_eq "$(cnt "$(SKSEC '### 4. 규모 공시')" "$lit")" "1" "SKILL.md 규모 공시: ${lit} 한 번"
done
assert_eq "$(cnt "$(SKSEC '## 보이기')" '의도 점검 질문')" "1" "SKILL.md 보이기: 의도 점검 질문 한 번"
assert_contains "$(SKSEC '## 보이기')" 'references/qg-review.md' "SKILL.md 보이기: qg-review.md 를 가리킨다"
assert_eq "$(grep -cF "$(printf 'skills/epic-conductor/references/qg-review.md\t비움\t**의도 점검 질문.**')" "$ROOT/shared/tests/fixtures/ask-sites.tsv")" "1" "ask-sites.tsv: 의도 점검 질문 행이 한 줄"

# AC18 — README Prerequisites 의 quality-gates 줄(절 본문에서 읽는다) · dependencies.md 의 없을 때 칸
RDME="$ROOT/plugins/spec-distill/README.md"
DEPS="$ROOT/plugins/spec-distill/dependencies.md"
PREQ="$(awk '$0=="## Prerequisites"{f=1;next} f&&/^## /{exit} f' "$RDME")"
QGL="$(printf '%s\n' "$PREQ" | awk 'index($0, "- **quality-gates**")==1')"
[ -n "$QGL" ] && ok "README Prerequisites 절 본문의 quality-gates 줄을 읽었다" || no "README Prerequisites 절 본문에 quality-gates 줄이 없다 — 아래 AC18 단언이 공허하다"
for lit in 'spec 승인 앞 · 에픽 머지 뒤 · 로드맵 끝 · 이름으로 청한 리뷰' '품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다' '리뷰할 diff 없음'; do
  assert_contains "$QGL" "$lit" "AC18 README: quality-gates 줄에 ${lit}"
done
assert_not_contains "$QGL" '걸음 7 이 범위 입력을 받으면' "AC18 음성 짝: quality-gates 줄에 걸음 7 범위 입력 문구가 없다"
assert_contains "$(awk 'index($0, "| quality-gates |")==1' "$DEPS")" '자리 넷' "AC18 dependencies.md: quality-gates 행 「없을 때」 칸에 자리 넷"

finish
