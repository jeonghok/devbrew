#!/usr/bin/env bash
# R3 — 지휘자 경유 qg 리뷰 절차(skills/epic-conductor/references/qg-review.md)와 들어가는 문장. 정적 락이다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_qg_review_reference.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
QR="$ROOT/plugins/spec-distill/skills/epic-conductor/references/qg-review.md"
[ -f "$QR" ] && ok "qg-review.md 가 있다" || { no "qg-review.md 가 없다"; finish; exit $?; }
sec() { awk -v h="$1" '$0==h{f=1;next} f&&/^## /{exit} f' "$QR"; }   # 절 본문(머리 줄 제외)
once() { assert_eq "$(printf '%s\n' "$1" | grep -oF -- "$2" | wc -l | tr -d ' ')" "1" "$3"; }

ALL="$(cat "$QR")"
for h in '## 호출 줄' '## 자리' '## 담당자' '## 돌아왔을 때'; do
  assert_eq "$(grep -cxF -- "$h" "$QR")" "1" "절 머리가 정확히 하나: ${h}"
  [ -n "$(sec "$h")" ] && ok "절 본문을 읽었다: ${h}" || no "절 본문이 비었다 — 아래 단언이 공허하다: ${h}"
done
CALL="$(sec '## 호출 줄')"
SITE="$(sec '## 자리')"
DISP="$(sec '## 담당자')"
BACK="$(sec '## 돌아왔을 때')"

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

# 레포 전용 값
for lit in 'origin/main' 'feature/' 'docs/superpowers'; do
  assert_not_contains "$ALL" "$lit" "레포 전용 값이 없다: ${lit}"
done
assert_contains "$ALL" 'origin/HEAD' "레포 전용 값 양성 짝: 기본 브랜치는 origin/HEAD"

finish
