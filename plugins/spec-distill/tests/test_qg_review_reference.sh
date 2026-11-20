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
L_alreadysent='보내기 전에 `ledger resources --roadmap <로드맵>` 에 `qg-<에픽>-merged-pr<번호>-` 로 시작하는 보관 폴더가 있거나 `## 쌓인 기록` 에 그 자리(`merged-pr<번호>`)의 줄이 있으면 이미 보낸 것이다 — 다시 보내지 않는다.'
L_failed='범위를 확인하지 못했거나 머지 커밋이 없어 보내지 못한 리뷰와, 담당자가 결과 파일을 옮기지 못해 「셀 수 없음」 으로 끝난 리뷰는 사용자에게 사유와 함께 보이고 `ledger add --section "쌓인 기록"` 으로 한 줄(자리 · 대상 · 사유)을 남긴다. 지휘자가 스스로 다시 보내지 않는다 — 사용자가 이름으로 청하면 그때 다시 시도한다.'
L_endmerge='보내기 전에 로드맵의 기록 브랜치에 기본 브랜치 끝을 합치고(`git merge --no-edit origin/HEAD`, 기록 브랜치 worktree 에서), 이 리뷰의 기록 파일 머리(frontmatter · 제목 · 「만든 것」 줄들)를 커밋한 뒤 보낸다. 범위는 합친 뒤의 갈라진 커밋(그때의 기본 브랜치 끝)부터 기록 브랜치 끝까지다.'
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
L_waiting='담당자가 질문을 돌려줬는데 바로 묻지 못하면 `ledger add --section "기다리는 질문"` 으로 한 줄(에픽 또는 로드맵 · 기대는 일 · 「의도 점검 질문 <k>개 — <보관 폴더 경로>」)을 적는다. spec 승인 앞이면 기대는 일은 「spec 리뷰 시작」 이다. 답을 받았거나 「답하지 않음」 으로 기록하면 그 줄을 지운다(`ledger drop`). 그 줄이 남아 있는 에픽의 spec 리뷰는 시작하지 않는다.'
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
assert_contains "$ASK" '「답하지 않음」 으로 남기고 다시 묻지 않는다' "AC13: 답하지 않은 질문은 「답하지 않음」 으로 남긴다"

# AC12 행선
once "$WRONG" "$L_wrongspec" "AC12: L(wrongspec) 한 번"
assert_contains "$WRONG" '/spec-distill:request-framing @<기록 파일의 레포 상대경로>' "AC12: 다음 세션 첫 줄"
assert_contains "$WRONG" '그 PR 이 머지된 뒤 친다' "AC12: 그 PR 이 머지된 뒤 친다"

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
SK="$ROOT/plugins/spec-distill/skills/epic-conductor/SKILL.md"
SKSEC() { awk -v h="$1" '/^```/{q=!q} !q&&$0==h{f=1;next} f&&!q&&/^## |^### /{exit} f' "$SK"; }
for lit in 'qg 담당자(spec 승인 앞 1 · 머지된 PR 마다 1)' '로드맵 끝 qg 담당자 1'; do
  assert_eq "$(cnt "$(SKSEC '### 4. 규모 공시')" "$lit")" "1" "SKILL.md 규모 공시: ${lit} 한 번"
done
assert_eq "$(cnt "$(SKSEC '## 보이기')" '의도 점검 질문')" "1" "SKILL.md 보이기: 의도 점검 질문 한 번"
assert_contains "$(SKSEC '## 보이기')" 'references/qg-review.md' "SKILL.md 보이기: qg-review.md 를 가리킨다"
assert_eq "$(grep -cF "$(printf 'skills/epic-conductor/references/qg-review.md\t비움\t**의도 점검 질문.**')" "$ROOT/shared/tests/fixtures/ask-sites.tsv")" "1" "ask-sites.tsv: 의도 점검 질문 행이 한 줄"

finish
