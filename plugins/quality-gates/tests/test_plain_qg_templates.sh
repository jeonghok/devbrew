#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/artifact-critique/SKILL.md plugins/quality-gates/README.md plugins/quality-gates/references/e2e.md
#
# 쉬운 말 출력 설계 §4 · AC6 — /quality-gates:quality-pipeline 의 질문 셋 · 완료 표 · 모델이 그대로 내는 문구가 한국어이고,
# 완료 보고와 비평 최종 보고가 첫 줄 상태 · 끝 할 일(기본 하나 — 여럿이거나 병렬이면 밝힘)을 지시받는다. e2e 걷기 직후 게이트(④)가
# 부르는 Fix-loop 선택지도 같은 라벨이다.
# 부재 단언마다 같은 자리의 양성 짝이 있다(부재 락은 통째로 지워도 통과한다).
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
S="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
CA="$PLUGIN_ROOT/skills/artifact-critique/SKILL.md"
RM="$PLUGIN_ROOT/README.md"
E2R="$PLUGIN_ROOT/references/e2e.md"
# 산문은 줄바꿈을 지운 본문에서 잰다 — 다시 쓰일 때 문장이 줄을 넘을 수 있다.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
qlines() { grep -E '^[[:space:]]*question:' "$1"; }
SF="$(flat "$S")"

# ① 질문 — question 줄에서 잰다(새 문구 양성 · 옛 영어 부재 · 분류 질문은 그대로)
assert_contains "$(qlines "$S")" 'question: "qg 반복 N: <ask-line>\n전문: <$RV/synth.out 의 경로>\n어떻게 할까?",' "AC6 · AC10: Fix-loop 질문이 한국어이고 질문 줄과 전문 자리를 싣는다"
assert_contains "$(qlines "$S")" 'question: "qg 가 반복 상한(<CAP>번 — 기본 5번)에 닿았다. <ask-line>' "AC25 · AC10: 상한 질문이 기본 5 와 지금 상한을 말하고 질문 줄을 싣는다"
assert_contains "$(qlines "$S")" 'question: "qg 가 반복 상한(<CAP>번 — 기본 5번)에 닿았다. <ask-line>\n전문: <$RV/synth.out 의 경로>\n반복을 하나 더 열까, 지금 판정으로 끝낼까, 멈출까?",' "AC25: 상한 질문이 전문 자리와 세 길(하나 더 · 끝내기 · 멈추기)을 묻는다"
assert_not_grep "$(qlines "$S")" '<summary>' "AC10: 질문 줄에 개수 줄(<summary>)을 싣지 않는다(위 양성 짝 — <ask-line>)"
assert_eq "$(qlines "$S" | grep -cF '<ask-line>')" "3" "AC10: <ask-line> 을 싣는 질문은 셋이다(반복 게이트 · 범위 모드 · 상한)"
assert_eq "$(qlines "$S" | grep -cF '전문: <$RV/synth.out 의 경로>')" "4" "AC10: 전문 자리를 싣는 질문은 넷이다(셋 + 낮춘 지적)"
assert_contains "$(qlines "$S")" '\n표: <$RV/classification.md 의 경로>",' "AC10: 분류 질문이 분류표 파일 자리를 싣는다"
assert_contains "$(qlines "$S")" '\n<항목마다 한 줄 — #<번호> <지적 요약> · <적용|제외> · <제외 사유(제외일 때)>>\n' "AC10: 분류 질문이 항목마다 한 줄을 싣는다"
assert_contains "$SF" '질문에는 `<summary>` 대신 `<ask-line>` 을 싣는다 — `$RV/synth.out` 의 `질문 줄: ` 뒤 글자 그대로다.' "AC10: <ask-line> 의 정의가 합성기의 질문 줄이다"
assert_contains "$SF" '표를 출력할 때 같은 글을 Write 도구로 `$RV/classification.md` 에 쓴다' "AC10: Step 5 가 분류표 파일을 쓴다"
# 나뉜 질문의 답 — 범위 모드 · 분류. 부딪히면 한 번 다시 묻고, 끝내는 답 뒤는 건너뛴다(낮춘 지적 게이트와 같은 뼈대).
RNG="$(awk '/^\*\*범위 모드 갈래\.\*\*/{f=1} f&&/^그 밖의 실행은 이 질문을 띄운다:$/{exit} f' "$S" | tr '\n' ' ' | tr -s ' ')"
CLS="$(awk '/^둘째 질문\(분류\)에는 추천을 달지 않는다/{f=1} f&&/^Branch on answer:$/{exit} f' "$S" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$RNG" '- 나뉜 질문의 답이 모두 같으면 그 답이다.' "나뉜 범위 질문: 답이 모두 같으면 그 답(범위 모드 절 안)"
assert_contains "$RNG" '- 답이 서로 다르면 어느 쪽도 적용하지 않고 질문 하나로 다시 묻는다 — 선택지와 설명은 이 질문의 둘 그대로다.' "나뉜 범위 질문: 부딪히면 그 질문의 둘로 다시 묻는다"
assert_contains "$RNG" '- 한 호출의 답이 정해지면(이 질문의 두 답은 모두 실행을 끝낸다) 아직 띄우지 않은 호출은 건너뛴다.' "나뉜 범위 질문: 답이 정해지면 남은 호출을 건너뛴다"
assert_contains "$RNG" '다시 물은 답이 또 비면(답 없음 · 알 수 없는 글) 「멈추기」로 가고 한 줄로 알린다: `> [quality-gates] 다시 물은 답이 정해지지 않아 멈춘다 — 지금 판정을 받아들였다고 기록하지 않는다.`' "나뉜 범위 질문: 다시 물은 답이 비면 멈추기 · 한 줄 알림"
assert_contains "$CLS" '- 기타 칸에 적은 번호는 묶음마다 모아 함께 적용한다.' "나뉜 분류 질문: 기타 칸 번호를 모은다(분류 절 안)"
assert_contains "$CLS" '- 「SUGGESTION 도 전부 적용」은 어느 묶음에서 골라도 분류표 전체를 뜻한다.' "나뉜 분류 질문: SUGGESTION 도 전부 적용은 표 전체"
assert_contains "$CLS" '다른 묶음(같은 호출이든 앞 호출이든)에 「분류표 그대로」가 있으면 어느 쪽도 적용하지 않고 질문 하나로 다시 묻는다 — 선택지는 이 질문의 둘 그대로이고 추천을 달지 않는다. 기타 칸의 번호는 이 부딪힘과 상관없이 모은다.' "나뉜 분류 질문: 부딪히면 추천 없이 다시 묻고 번호는 모은다"
assert_contains "$CLS" '답이 실행을 끝내는 답(「지금 판정으로 끝내기」 · 「멈추기」)이면 아직 띄우지 않은 분류 질문 호출은 건너뛰고, 이미 받은 분류 답은 쓰지 않는다.' "나뉜 분류 질문: 끝내는 답 뒤의 분류 호출은 건너뛰고 받은 분류 답은 버린다"
assert_contains "$CLS" '「분류표 그대로」로 가고(모은 번호는 적용한다) 한 줄로 알린다: `> [quality-gates] 다시 물은 분류 답이 정해지지 않아 분류표 그대로 둔다 — 기타 칸의 번호는 적용했다.`' "나뉜 분류 질문: 다시 물은 답이 비면 분류표 그대로 · 한 줄 알림"
# 규칙 블록만(「… 답은 이렇게 읽는다.」 줄부터 불릿 뒤 빈 줄까지) — 창에는 원래 있던 추천 지시 문장이 든다.
SPLIT="$(awk '/답은 이렇게 읽는다\.$/{f=1; b=0; print; next} f&&/^- /{b=1; print; next} f&&b&&/^$/{f=0} f{print}' "$S")"
assert_eq "$(printf '%s\n' "$SPLIT" | grep -c '^- ')" "9" "나뉜 질문 규칙: 블록 둘의 불릿이 모두 잡혔다(범위 4 + 분류 5 — 아래 부재 단언의 전제)"
assert_not_contains "$SPLIT" '(권장)' "나뉜 질문 규칙: 새 문장에 추천 표시가 없다"
assert_not_grep "$(qlines "$S")" '최대 5번 반복했다' "AC25: 상한을 고정 5 로 말하는 옛 질문이 없다"
MX="$(awk '/^### Max-iter decision$/{f=1;next} f&&/^### /{exit} f' "$S")"
assert_contains "$MX" 'extra-iterations.md' "Max-iter 절이 승인 기록 파일을 부른다(분기 안의 기록은 ⑩ 의 분기 창 단언이 잰다)"
assert_contains "$MX" 'typed' "기타 칸 원문도 승인으로 받는다(출처 typed)"
assert_contains "$(printf '%s\n' "$MX" | tr '\n' ' ' | tr -s ' ')" '반복을 더 여는 뜻이면 「한 번 더 돌기」와 같은 경로로 가되 출처 `typed` 와 그 원문을 기록한다' "AC25 · 결정 9: 기타 칸 글이 여는 뜻이면 같은 경로 · 출처 typed 로 기록한다(분기 문장 — 펜스 자리표시의 typed 로는 채워지지 않는다)"
assert_contains "$MX" '한 번에 하나' "한 번 열면 반복 하나 — 그 끝에 다시 묻는다(상한은 남는다)"
MXR="$(printf '%s\n' "$MX" | awk '/^```bash$/{f=1;next} f&&/^```$/{exit} f')"
assert_grep "$MXR" "^{ printf -- '- iter %s 뒤 · 반복 하나 더 · %s · ' '<N>' '<label 또는 typed>'; tr -d '\\\\r' <<'QG_EXTRA_RAW_<8 hex>' \\| paste -s -d ' ' -; } >> \"\\\$F\"$" "AC25: 기록 펜스가 출처는 인자로, 원문은 실행마다 끝 줄 이름이 다른 따옴표 here-doc 으로 싣고 줄바꿈을 셸이 접는다"
assert_grep "$MXR" '^QG_EXTRA_RAW_<8 hex>$' "AC25: here-doc 끝 줄이 같은 실행별 이름이다"
assert_not_grep "$MXR" '^QG_EXTRA_RAW$' "AC25: 고정 끝 줄 이름(원문이 같아질 수 있다)이 없다"
assert_grep "$MXR" '^# 아래 두 QG_EXTRA_RAW_<8 hex> 의 <8 hex> 는 이 실행마다 새로 고른 16진수 8자' "AC25: 펜스 주석이 끝 줄 이름을 실행마다 새로 고르라고 한다"
assert_grep "$MXR" '^F="\$RD/extra-iterations\.md"; PAT=' "AC25: 기록 파일을 F 로 잡는다(양성 짝 — P2 도출이 이 쓰기를 본다)"
assert_not_grep "$MXR" "'<고른 선택지" "AC25: 원문을 작은따옴표 인자로 싣지 않는다(모델의 손 이스케이프에 셸 안전을 걸지 않는다)"
assert_grep "$MXR" "PAT='\\^- iter \\[0-9\\]\\* 뒤 · 반복 하나 더 · '" "AC25: 상한 계산은 기록 줄 꼴에 묶인 줄만 센다"
assert_grep "$MXR" '^\[ "\$AFTER" = "\$\(\(BEFORE \+ 1\)\)" \] \|\| \{ echo "\[quality-gates\] 추가 반복 기록이 한 줄 늘지 않았다' "AC25: 쓰기 뒤 기록이 정확히 한 줄 늘었는지 검사하고 아니면 멈춘다"
assert_not_contains "$(printf '%s\n' "$MX" | tr '\n' ' ' | tr -s ' ')" '앞에 공백 하나를 붙인다' "AC25: 원문을 손으로 고치라는 규칙이 없다(끝 줄 이름이 실행마다 다르다)"
assert_contains "$(printf '%s\n' "$MX" | tr '\n' ' ' | tr -s ' ')" '이 펜스를 돌릴 때마다 새로 고른 16진수 8자다(두 자리에 같은 값) — 원문이 끝 줄과 같아질 수 없게 하려는 것이고, 원문은 손대지 않는다.' "AC25: 산문이 실행별 끝 줄 이름과 원문 무수정을 말한다(위 부재 단언의 양성 짝)"
assert_grep "$(qlines "$S")" 'question: "<file> 수정에 실패했다: <reason>\. 이번 수정 반복을 멈출까, 이 파일만 건너뛰고 나머지를 계속할까\?"' "AC6: 수정 실패 질문이 한국어다"
assert_grep "$(qlines "$S")" 'question: "분류표의 적용/제외를 바꿀까요\?' "분류 질문은 그대로 있다(양성 짝)"
assert_not_grep "$(qlines "$S")" 'findings remain|What next|reached max|Retry failed at' "AC6: 영어 질문이 남지 않았다"
assert_contains "$(qlines "$S")" 'question: "qg 반복 N: <ask-line>\n<지적마다 한 줄 — <file>:<line> — <요약>>\n전문: <$RV/synth.out 의 경로>\n범위 모드는 이미 있는 커밋을 본다 — 고칠 것은 새 브랜치에서 고친다. 어떻게 끝낼까?",' "AC6 · AC10: 범위 모드 Fix-loop 질문이 한국어이고 지적 줄과 전문 자리를 싣는다(AC21)"
assert_contains "$(qlines "$S")" 'question: "재비판이 심각도를 낮춘 지적 <n>개 가운데 <이 묶음의 번호들 — 예: L1 · L2 · L3>. 되올릴 것을 고르세요 — 되올리면 원래 심각도로 판정에 들어간다.\n전문: <$RV/synth.out 의 경로>' "AC26 · AC10: 낮춘 지적 게이트 질문이 한국어이고 묶음 번호와 전문 자리를 싣는다"
assert_not_contains "$(qlines "$S")" '(위 「낮춘 지적」 절)' "AC10: 낮춘 지적 질문이 창 밖의 절을 가리키지 않는다(위 양성 짝)"
assert_eq "$(qlines "$S" | grep -c .)" "6" "AC6: 이 SKILL 의 question 줄은 여섯이다(넷 + 범위 모드 질문 + 낮춘 지적 질문 — 새로 생기거나 사라진 질문 없음)"

# ② 선택지 라벨 · 머리글 — 새 라벨 양성 · 옛 라벨 부재
for l in '고치고 다시 돌기' '지금 판정으로 끝내기' '멈추기' '이번 반복 멈추기' '이 파일만 건너뛰기' '분류표 그대로' '한 번 더 돌기'; do
  assert_file_grep "$S" "label: \"${l}\"" "AC6: 선택지 라벨 「${l}」"
done
assert_file_absent "$S" 'label: "(Retry|Accept and finish|Stop|Abort retry|Skip this file)"' "AC6: 영어 선택지 라벨이 없다"
for h in 'qg 반복 N' '수정 실패' 'qg 최대 반복' '분류'; do
  assert_file_grep "$S" "header: \"${h}\"" "AC6: 머리글 「${h}」"
done
assert_file_absent "$S" 'header: "(qg iter N|qg max-iter|Retry)"' "AC6: 영어 머리글이 없다"
assert_contains "$SF" 'preceded by `## qg 반복 N — <verdict>` (`not-certified` → `## qg 반복 N — not-certified (<reason>)`)' "T1: 판정 머리글이 Fix-loop 질문과 같은 낱말(반복)이다"
assert_file_absent "$S" '^.*`## qg iter N' "T1: 판정 머리글에 옛 영어 낱말(iter)이 없다"
assert_file_grep "$S" 'description: "표의 적용/제외대로 고친다\."' "AC6: 분류 선택지 설명이 새 라벨 이름 없이 동작을 말한다"
assert_file_absent "$S" '표의 적용/제외로 Retry 한다' "AC6: 분류 선택지 설명이 옛 라벨을 부르지 않는다"
assert_contains "$SF" '{label: "멈추기", description: "얻음: 여기서 멈추고 지적을 직접 고친 뒤 다시 돌린다 · 내줌: 이번 실행의 판정이 PR 코멘트로 남지 않는다"}' "규칙 블록: 멈추기 설명이 달라지는 것(게시 없음)을 말한다"

# ③ 분기 문장의 굵은 라벨이 새 라벨을 부른다(옛 라벨을 부르면 모델이 없는 선택지를 찾는다)
for l in '고치고 다시 돌기' '지금 판정으로 끝내기' '멈추기'; do
  assert_file_grep "$S" "^- \\*\\*${l}\\*\\* →" "AC6: Fix-loop 분기 불릿 「${l}」"
done
assert_file_absent "$S" '^- \*\*(Retry|Accept and finish|Stop)\*\* →' "AC6: 옛 Fix-loop 분기 불릿이 없다"
assert_contains "$MX" '- **지금 판정으로 끝내기** → Final verdict with Outcome `accepted with findings iter N` (N = CAP).' "AC6 · AC25: 최대 반복 끝내기 분기가 새 라벨을 부르고 반복 번호는 CAP 이다"
assert_contains "$MX" '- **멈추기** → Final verdict with Outcome `aborted iter N` (N = CAP).' "AC6 · AC25: 최대 반복 멈추기 분기가 새 라벨을 부른다"
assert_not_contains "$MX" 'iter 5`' "AC25: 최대 반복 분기가 반복 번호를 5 로 박지 않는다"
assert_not_contains "$SF" '**Accept and finish** →' "AC6: 옛 Accept 분기가 없다"
assert_contains "$SF" '**「고치고 다시 돌기」 옵션 문구 — 차등 테스트 기원' "AC6: 차등 기원 안내가 새 옵션 이름을 부른다"
assert_contains "$SF" '「고치고 다시 돌기」의 `description` 을 "얻음: 회귀가 난 테스트마다 쓴 계획대로 고치고 차등 테스트로 다시 확인한다 · 내줌: 계획이 틀렸으면 틀린 고침이 이미 파일에 들어가 있다" 로 바꿔 싣는다.' "AC10: 차등 기원 설명이 얻음 · 내줌 꼴이다"
assert_contains "$SF" 'Fix-loop (고치고 다시 돌기(Retry) / 지금 판정으로 끝내기 / 멈추기)' "흐름 그림이 새 라벨을 부르고 이 파일의 Retry 가 어느 선택지인지 묶는다"
assert_not_contains "$SF" 'Fix-loop (Retry / Accept and finish / Stop)' "흐름 그림에 옛 라벨 나열이 없다"

# ④ 완료 표 · 완료 보고
assert_file_grep "$S" 'render-terminal\.py" table --title "Quality Gates — 끝"' "AC6: 완료 표 제목이 한국어다"
assert_file_absent "$S" 'Quality Gates — Complete' "AC6: 옛 완료 표 제목이 없다"
assert_file_grep "$S" "^printf '판정\\\\t%s\\\\n반복\\\\t<N>번\\\\n결과\\\\t<finished \\| accepted with findings iter N \\| aborted iter N>\\\\n'" "AC6 · R15: 완료 표 칸 이름이 한국어이고 결과 칸은 게시 펜스가 읽는 토큰 그대로다"
assert_file_absent "$S" "^printf 'Verdict" "AC6: 옛 영어 칸 이름이 없다"
assert_file_grep "$S" 'finished\|"accepted with findings iter "\[0-9\]\*\|"aborted iter "\[0-9\]\*\)' "R15: 게시 펜스가 같은 세 결과 토큰을 받는다(양성 짝)"
assert_contains "$SF" 'The completion report opens — before the table — with one Korean sentence: how the run ended (the 결과 cell in plain words) and the verdict value as-is' "§4: 완료 보고 첫 줄은 끝난 방식과 판정값"
assert_contains "$SF" 'The counts stay in the verdict line — do not restate them.' "규칙 블록: 개수를 다시 풀어 쓰지 않는다"
assert_contains "$SF" "After the intent-critic result line and the return block, end with the user's next action — one by default; if there are several, or they can run together (in parallel), say so and list them together" "AC2: 완료 보고 끝 할 일 — 기본 하나 · 여럿이면 밝힘(intent-critic 결과 줄 · 돌려주는 꼴 뒤)"
assert_not_contains "$SF" 'exactly one next action' "AC2: exactly one 없음"
assert_contains "$SF" "the intent-critic result line (or its skip notice) is the run's last script output, followed by the return block." "intent-critic 결과 줄(또는 건너뜀 줄)이 스크립트 출력의 마지막이다(할 일 줄과 충돌하지 않는다)"
assert_not_contains "$SF" "the publish result line is the run's last" "게시 결과 줄이 마지막 출력이라는 옛 문장이 없다(intent-critic 단계가 게시 뒤에 돈다)"

# ⑤ 모델이 그대로 내는 문구 — trivia 줄 · 범위 줄 · 범위 경고
assert_contains "$SF" '설명되는 diff 면 `작은 수정이라 파이프라인을 건너뛰었다(trivia diff) — <한 문장 설명>.` 을 보이고' "AC6: trivia 줄이 한국어다"
assert_contains "$SF" '설명되면 `작은 수정이라 파이프라인을 건너뛰었다(trivia diff — <토픽 전체 | 범위 전체>) — <한 문장 설명>.` 을 보이고' "AC6 · AC28: 토픽 · 범위 전체 trivia 줄이 한국어다"
assert_file_absent "$S" 'Trivia diff — pipeline skipped' "AC6: 옛 trivia 줄이 없다"
assert_file_grep "$S" '> 리뷰 범위: 이번 세션에서 바뀐 파일 <COUNT>개\. 브랜치 전체를 보려면 /quality-gates:quality-pipeline branch\.' "AC6: session 범위 줄"
assert_file_grep "$S" '> 리뷰 범위: 토픽 <topic_key> — 바뀐 파일 <COUNT>개 · 구성원 <branches>\.' "AC6: topic 범위 줄"
assert_file_absent "$S" 'Review scope: (session|topic)' "AC6: 옛 범위 줄이 SKILL 에 없다"
assert_file_absent "$RM" 'Review scope: (session|topic)' "AC6: 옛 범위 줄이 README 에 없다"
assert_file_grep "$RM" '리뷰 범위: 이번 세션에서 바뀐 파일 N개\.' "AC6: README 가 새 session 범위 줄을 설명한다(양성 짝)"
assert_file_grep "$RM" '리뷰 범위: 토픽 <키> — 바뀐 파일 N개 · 구성원 <branches>\.' "AC6: README 가 새 topic 범위 줄을 설명한다(양성 짝)"
assert_file_grep "$S" '범위를 확인하지 못했다\(scope check degraded — detached HEAD' "AC6: 범위 경고가 쉬운 말로 시작하고 토큰을 괄호에 둔다"
assert_file_grep "$S" '바뀐 파일이 0개인지 보는 검사를 건너뛰었다\(fail-open\)' "AC6: 범위 경고가 건너뛴 검사를 말한다"
assert_file_absent "$S" 'empty-scope detection skipped' "AC6: 옛 영어 범위 경고 꼬리가 없다"

# ⑥ README 의 범위 절이 부르는 라벨
assert_eq "$(grep -cF '`고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기`' "$RM")" "1" "AC6: README 가 새 라벨을 한 자리에서 부른다"
assert_file_absent "$RM" '`Retry` / `Accept and finish` / `Stop`' "AC6: README 범위 절에 옛 라벨 나열이 없다"
assert_contains "$(flat "$RM")" '「고치고 다시 돌기」는 「적용」 항목만 고친다.' "AC6: README 가 고치는 범위를 새 라벨로 말한다"
assert_not_contains "$(flat "$RM")" 'Retry 는 「적용」 항목만 고친다' "AC6: README 에 옛 라벨 문장이 없다"

# ⑦ README 상태도가 같은 라벨을 부른다(질문 앵커 표지는 test_readme_state_diagram_complete.sh 가 잰다)
assert_file_grep "$RM" '분류표\(항목마다 적용 / 제외 \+ 사유\) · 고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기$' "AC6: README 상태도가 새 라벨을 부른다"
assert_file_absent "$RM" 'Retry / Accept and finish / Stop' "AC6: README 상태도에 옛 라벨 나열이 없다"

# ⑧ e2e 걷기 직후 게이트(④) — 선택지를 부르는 자리는 Fix-loop 와 같은 새 라벨이다.
# 반복 동작 이름으로서의 Retry(「고침은 Retry 로만」 등)는 지시문이라 그대로 둔다 — 여기서는 선택지 자리만 잰다.
E2S="$(awk '/^## e2e$/{f=1;next} f&&/^## /{exit} f' "$S")"
E2SF="$(printf '%s\n' "$E2S" | tr '\n' ' ' | tr -s ' ')"
assert_grep "$E2S" '^\*\*E4 — 걷기 직후 게이트\.\*\*' "e2e 절을 잘랐다(양성 짝 — 창이 비면 아래 부재 단언이 공허하다)"
for l in '고치고 다시 돌기' '지금 판정으로 끝내기' '멈추기'; do
  assert_grep "$E2S" "^- \\*\\*${l}\\*\\* \\(fail 행\\) — " "AC6: e2e 게이트 fail 행 불릿 「${l}」"
done
assert_not_grep "$E2S" '^- \*\*(Retry|Accept|Accept and finish|Stop)\*\* \(fail 행\)' "AC6: e2e 게이트에 옛 라벨 불릿이 없다"
assert_contains "$E2SF" '`## Fix-loop` 의 「고치고 다시 돌기」와 같다:' "AC6: e2e 「고치고 다시 돌기」가 Fix-loop 의 같은 선택지를 부른다"
assert_contains "$E2SF" '`## Fix-loop` 의 「멈추기」와 같다:' "AC6: e2e 「멈추기」가 Fix-loop 의 같은 선택지를 부른다"
assert_contains "$E2SF" '다시 돈 뒤, 「고치고 다시 돌기」와 같은 경로로 이 절에 돌아와' "AC6: 무효 행이 새 라벨의 경로를 부른다"
assert_contains "$E2SF" 'CAP 에 닿았으면 fail 행에 「고치고 다시 돌기」 대신, 무효 행에 「리뷰·테스트부터 다시」 대신 「한 번 더 돌기」를 넣고, 고르면 위와 같이 기록한다' "AC25: 상한의 e2e fail · 무효 행이 한 번 더 돌기를 내고 기록한다"
assert_contains "$E2SF" '무효 행은 한 번 더 돌기 / 산출물 확인 / 그대로 둠 이다.' "AC25: 상한의 e2e 무효 행 선택지에 한 번 더 돌기가 있다"
assert_contains "$E2SF" '무효 행이면 위 「리뷰·테스트부터 다시」와 같은 경로로 간다' "AC25: 무효 행의 한 번 더 돌기는 리뷰·테스트부터 다시 경로다"
assert_contains "$E2SF" '뒤집기 사유면 뒤집기이고 반복을 열지 않는다. 반복을 더 여는 뜻이 분명할 때만 출처 `typed` 와 그 원문으로 기록하고 연다. 어느 쪽인지 모르겠으면 아무것도 열지 않고 게이트를 한 번 더 띄운다.' "AC25: e2e 게이트의 기타 칸 글 — 뒤집기 사유와 여는 뜻을 가르고, 모르면 열지 않는다"
assert_contains "$E2SF" '그때 fail 행은 한 번 더 돌기 / 지금 판정으로 끝내기 / 멈추기 / pass 로 뒤집기,' "AC6 · AC25: 상한의 e2e 선택지가 새 라벨이다"
assert_not_contains "$E2SF" 'iteration 5 를 다 썼으면' "AC25: e2e 가 상한을 고정 5 로 말하지 않는다"
assert_contains "$E2SF" '리뷰·테스트 루프가 「멈추기」 없이 끝나면 최종 판정 전에 이 절을 한 번 돈다. 루프가 「멈추기」로 끝났으면(aborted)' "AC6: e2e 절 첫 문장이 새 라벨을 부른다"
assert_contains "$E2SF" '루프가 다시 「멈추기」 없이 끝나면 이 절로 돌아오고' "AC6: 재걷기 조건이 새 라벨을 부른다"
assert_contains "$E2SF" '(고치고 다시 돌기 · 리뷰·테스트부터 다시 · 다시 걷기 · 남은 시나리오가 있으면 위 E4 의 경로로)' "AC6: e2e 절 끝 문장이 새 라벨을 부른다"
assert_not_grep "$E2S" 'Accept|Stop|\*\*Retry\*\*|Retry 와 같|Retry ·' "AC6: e2e 절이 옛 선택지 이름(Accept · Stop · 선택지로서의 Retry)을 부르지 않는다"
assert_file_grep "$E2R" '^\| fail \| Fix-loop 게이트\(고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기\) \+ pass 로 뒤집기 \|$' "AC6: e2e 레퍼런스 게이트 표의 fail 행이 새 라벨이다"
assert_file_grep "$E2R" '^\| fail 에서 지금 판정으로 끝내기 \| `fail` \| 아니오 \|$' "AC6: e2e 결과 표 「지금 판정으로 끝내기」 행"
assert_file_grep "$E2R" '^\| fail 에서 멈추기 \| `fail` \| 아니오 \|$' "AC6: e2e 결과 표 「멈추기」 행"
assert_file_grep "$E2R" '^\| 루프가 「멈추기」\(aborted\)로 끝나 e2e 를 건너뜀 \|' "AC6: e2e 결과 표의 건너뜀 행이 새 라벨을 부른다"
E2RF="$(flat "$E2R")"
assert_contains "$E2RF" 'CAP 에 닿았으면 fail 행에 「고치고 다시 돌기」 대신 「한 번 더 돌기」를 넣고, 고르면' "AC6 · AC25: e2e 레퍼런스가 상한에서 바꿔 넣는 선택지를 새 라벨로 부른다"
assert_contains "$E2RF" '`리뷰·테스트부터 다시` 는 iteration 하나를 쓴다. CAP 에 닿았으면 그 자리에 「한 번 더 돌기」를 넣는다' "AC25: e2e 레퍼런스의 무효 행도 상한에서 한 번 더 돌기를 낸다"
assert_contains "$E2RF" '「기타」 칸 글이 뒤집기 사유면 뒤집기이고 반복을 열지 않는다' "AC25: e2e 레퍼런스가 기타 칸 글의 뒤집기 사유와 여는 뜻을 가른다"
assert_contains "$E2RF" '`extra-iterations.md`' "AC25: e2e 레퍼런스가 승인 기록 자리를 부른다"
assert_not_contains "$E2RF" '남은 iteration 이 없' "AC25: e2e 레퍼런스에 상한을 닫힌 끝으로 말하는 옛 문장이 없다"
assert_contains "$E2RF" 'fail 에서 「멈추기」를 고르면 실행은 aborted' "AC6: e2e 레퍼런스의 aborted 문장이 새 라벨을 부른다"
assert_contains "$E2RF" '증거표와 판정안을 보인 뒤 `AskUserQuestion` 하나를 띄운다. 질문 본문에는 판정안 한 줄, 충족하지 못한 기대 상태를 한 줄씩(없으면 「충족하지 못한 기대 상태 없음」), 「증거표: <세션 폴더의 `e2e-evidence.tsv` 경로>」 한 줄을 싣는다 — 질문 창만 보고 고를 수 있게.' "AC10: e2e 판정 질문의 본문이 판정안 · 못 채운 기대 상태 · 증거표 자리를 싣는다"
assert_contains "$E2RF" '- `fail` 행은 Fix-loop 게이트와 같은 질문이다. 질문 본문은 이 절의 것(판정안 · 충족하지 못한 기대 상태 · 증거표 자리)이고, 선택지와 분류 질문은 Fix-loop 게이트의 것이다. 분류 질문을 띄우기 전에 SKILL.md 의 Step 5 를 먼저 한다 — 표를 출력하고 같은 글을 마지막 iteration 의 `$RV/classification.md` 에 쓴다(분류 질문의 `표:` 줄이 그 경로다).' "AC10: e2e fail 행도 분류 질문 전에 Step 5(표 · classification.md)를 거친다"
assert_file_absent "$E2R" 'Accept|Stop|Retry /|Retry 를 넣지' "AC6: e2e 레퍼런스에 옛 선택지 이름이 없다"

# ⑨ 비평 최종 보고
CAF="$(flat "$CA")"
assert_contains "$CAF" '보고의 첫 줄은 끝났는지와 결과 한 문장이다' "§4: 비평 최종 보고 첫 줄"
assert_contains "$CAF" '잔여 `kept` 항목에 `plain:` 이 있으면 그것을 먼저 쓰고 원래 `summary` 는 뒤 괄호에 둔다' "R7: 비평 보고가 plain 을 먼저 쓴다"
assert_contains "$CAF" '맨 끝에 사용자가 할 일을 쓴다 — 기본 하나, 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다.' "AC2: 비평 최종 보고 끝 할 일 — 기본 하나 · 여럿이면 밝힘"
assert_not_contains "$CAF" '할 일 하나를 쓴다' "AC2: 비평 보고에 옛 「할 일 하나를 쓴다」 없음"

# ⑩ Max-iter 결정 — AskUserQuestion 의 라벨이 같은 절의 굵은 분기 글자와 같다(라벨만 바꾸면 분기가 없는 선택지를 부른다)
MX="$(awk '/^### Max-iter decision$/{f=1;next} f&&/^### /{exit} f' "$S")"
MXF="$(printf '%s\n' "$MX" | tr '\n' ' ' | tr -s ' ')"
assert_grep "$MX" '^After iteration CAP' "Max-iter 절을 잘랐다(양성 짝 — 창이 비면 아래 단언이 공허하다)"
MXL="$(printf '%s\n' "$MX" | grep -E '^[[:space:]]*\{label: "' | sed -e 's/^[^"]*"//' -e 's/".*$//')"
assert_eq "$(printf '%s\n' "$MXL" | tr '\n' '|')" "한 번 더 돌기|지금 판정으로 끝내기|멈추기|" "Max-iter: 선택지 라벨은 셋이고 이 순서다(분류 질문은 Fix-loop 의 것을 그대로 실어 여기 라벨이 없다)"
assert_contains "$MXF" "Branch on answer:" "Max-iter: 분기 문장이 있다"
assert_contains "$MXF" '{label: "멈추기", description: "얻음: 파이프라인을 멈추고 지적을 직접 고친 뒤 다시 돌린다 · 내줌: 이번 실행의 판정이 PR 코멘트로 남지 않는다"}' "M2: Max-iter 의 멈추기 설명이 PR 코멘트로 남지 않는다고 말한다(줄바꿈을 접은 본문)"
assert_contains "$MXF" '{label: "한 번 더 돌기", description: "얻음: 상한을 넘어 반복 하나를 열어 적용 지적을 고치고 다시 확인한다 · 내줌: 분류가 틀렸으면 틀린 고침이 이미 파일에 들어가 있다"}' "AC25: 한 번 더 돌기 설명이 반복 하나를 연다고 말한다"
assert_contains "$MXF" '그 반복이 또 막는 지적이나 차등 defect 로 끝나면 이 결정이 다시 뜬다(상한은 남는다).' "AC25: 연 반복 끝에 다시 묻는다(분기 문장 — 설명에서 빠진 「다시 묻기」의 자리)"
assert_contains "$MXF" '차등 테스트 기원(`blocking: 0`)이면 「한 번 더 돌기」의 `description` 을 "얻음: 상한을 넘어 반복 하나를 열어 회귀 테스트를 고치고 다시 확인한다 · 내줌: 계획이 틀렸으면 틀린 고침이 이미 파일에 들어가 있다" 로 바꿔 싣는다.' "AC10: 상한의 차등 기원 설명이 얻음 · 내줌 꼴로 적혀 있다"
printf '%s\n' "$MXL" > "${TMPDIR:-/tmp}/qg-plain-mxl.$$"
while IFS= read -r l; do
  [ -n "$l" ] || continue
  assert_contains "$MXF" "- **${l}** → " "Max-iter: 라벨 「${l}」가 같은 절의 굵은 분기 글자와 같다"
done < "${TMPDIR:-/tmp}/qg-plain-mxl.$$"
rm -f "${TMPDIR:-/tmp}/qg-plain-mxl.$$"
MXH="$(printf '%s\n' "$MXF" | sed -n 's/.*\(- \*\*한 번 더 돌기\*\* → .*\)- \*\*지금 판정으로 끝내기\*\* → .*/\1/p')"
assert_contains "$MXH" '「고치고 다시 돌기」와 같은 경로' "AC25: 한 번 더 돌기는 Fix-loop 의 고치고 다시 돌기와 같은 경로다(Final verdict 로 새지 않는다)"
assert_contains "$MXH" 'N += 1' "AC25: 한 번 더 돌기가 반복 하나를 쓴다"
assert_not_contains "$MXH" 'Final verdict' "AC25: 한 번 더 돌기 분기는 최종 판정으로 가지 않는다"
# 기록은 분기 불릿 «안»에서 잰다 — 절 전체의 extra-iterations.md(CAP 문장 · 펜스)로는 채워지지 않는다.
assert_contains "$MXH" '아래 펜스로 한 줄을 기록하고(출처 `label`' "AC25: 한 번 더 돌기 분기가 기록 펜스로 승인 출처를 남긴다"
assert_eq "$(awk -v s="$MXH" 'BEGIN{a=index(s,"펜스로 한 줄을 기록"); b=index(s,"같은 경로"); c=index(s,"N += 1"); print ((a>0 && b>a && c>a) ? 1 : 0)}')" "1" \
  "AC25: 한 번 더 돌기 분기는 기록이 먼저이고 그다음 같은 경로 · N += 1 이다"

# ⑪ 게시 게이트가 완료 표의 바뀐 칸 이름을 부른다(OUTCOME 변수 이름과 값은 그대로)
PB="$(awk '/^## Publish$/{f=1;next} f&&/^## /{exit} f' "$S")"
assert_grep "$PB" '^OUTCOME="' "Publish 절을 잘랐다(양성 짝)"
assert_contains "$(printf '%s\n' "$PB" | tr '\n' ' ' | tr -s ' ')" '`OUTCOME` 에 `## Final verdict` 표의 결과 칸 값(Outcome)을' "AC6: 게시 게이트 OUTCOME 출처가 결과 칸을 부른다"
assert_grep "$PB" '^OUTCOME="<Final verdict 표의 결과 칸 값 그대로>"$' "AC6: 게시 펜스 OUTCOME 자리표시가 결과 칸을 부른다"
assert_not_grep "$PB" 'Outcome 값' "AC6: 게시 게이트에 옛 칸 이름(Outcome 값)이 없다"
finish
