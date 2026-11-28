#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/artifact-critique/SKILL.md plugins/quality-gates/README.md plugins/quality-gates/references/e2e.md
#
# 쉬운 말 출력 설계 §4 · AC6 — /quality-gates:quality-pipeline 의 질문 · 완료 표 · 모델이 그대로 내는 문구가 한국어이고,
# 완료 보고와 비평 최종 보고가 첫 줄 상태 · 끝 할 일(기본 하나 — 여럿이거나 병렬이면 밝힘)을 지시받는다.
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

# ① 질문 — question 줄에서 잰다. 고치기 반복의 질문(반복 게이트 · 범위 모드 · 상한 · 분류 · 수정 실패)은 없다 —
# 한 실행은 한 번 지나고 묻지 않는다(그 부재는 test_one_pipeline_surface.sh 의 case_one_pass_flow 가 잰다).
assert_eq "$(qlines "$S" | grep -cF '전문: <$RV/synth.out 의 경로>')" "1" "AC10: 전문 자리를 싣는 질문은 낮춘 지적 질문 하나다"
assert_not_grep "$(qlines "$S")" 'findings remain|What next|reached max|Retry failed at' "AC6: 영어 질문이 남지 않았다"
assert_contains "$(qlines "$S")" 'question: "재비판이 심각도를 낮춘 지적 <n>개 가운데 <이 묶음의 번호들 — 예: L1 · L2 · L3>. 되올릴 것을 고르세요 — 되올리면 원래 심각도로 판정에 들어간다.\n전문: <$RV/synth.out 의 경로>' "AC26 · AC10: 낮춘 지적 게이트 질문이 한국어이고 묶음 번호와 전문 자리를 싣는다"
assert_not_contains "$(qlines "$S")" '(위 「낮춘 지적」 절)' "AC10: 낮춘 지적 질문이 창 밖의 절을 가리키지 않는다(위 양성 짝)"
assert_eq "$(qlines "$S" | grep -c .)" "1" "AC6: 이 SKILL 의 question 줄은 하나다(낮춘 지적 질문 — 고치기 반복의 질문이 빠졌다)"

# ② 선택지 라벨 · 머리글 — 새 라벨 양성 · 옛 라벨 부재
assert_file_grep "$S" 'label: "그대로 둔다"' "AC6: 선택지 라벨 「그대로 둔다」"
assert_file_absent "$S" 'label: "(Retry|Accept and finish|Stop|Abort retry|Skip this file)"' "AC6: 영어 선택지 라벨이 없다"
assert_file_grep "$S" 'header: "낮춘 지적"' "AC6: 머리글 「낮춘 지적」"
assert_file_absent "$S" 'header: "(qg iter N|qg max-iter|Retry)"' "AC6: 영어 머리글이 없다"
assert_contains "$SF" 'preceded by `## qg 판정 — <verdict>` (`not-certified` → `## qg 판정 — not-certified (<reason>)`)' "T1: 판정 머리글이 한 번 지난 실행의 판정을 부른다(반복 번호 없음)"
assert_file_absent "$S" '^.*`## qg iter N' "T1: 판정 머리글에 옛 영어 낱말(iter)이 없다"
assert_file_absent "$S" '`## qg 반복 N' "T1: 판정 머리글에 반복 번호가 없다(위 양성 짝)"

# ④ 완료 표 · 완료 보고
assert_file_grep "$S" 'render-terminal\.py" table --title "Quality Gates — 끝"' "AC6: 완료 표 제목이 한국어다"
assert_file_absent "$S" 'Quality Gates — Complete' "AC6: 옛 완료 표 제목이 없다"
assert_file_grep "$S" "^printf '판정\\\\t%s\\\\n결과\\\\tfinished\\\\n'" "AC6 · R15: 완료 표 칸 이름이 한국어이고 결과 칸은 게시 펜스가 읽는 토큰(finished) 그대로다"
assert_file_absent "$S" "^printf 'Verdict" "AC6: 옛 영어 칸 이름이 없다"
assert_file_grep "$S" '^  finished\) ;;$' "R15: 게시 펜스가 같은 결과 토큰 하나(finished)를 받는다(양성 짝)"
assert_contains "$SF" 'The completion report opens — before the table — with one Korean sentence: what the run looked at once and the verdict value as-is' "§4: 완료 보고 첫 줄은 한 번 본 것과 판정값"
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
assert_eq "$(grep -cF '`고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기`' "$RM")" "0" "AC6: README 에 고치기 라벨 나열이 없다(한 번 보고 끝난다)"
assert_contains "$(flat "$RM")" '막는 지적이 남아도 묻지 않고 고칠 목록을 result.md 에 남긴다' "AC6(양의 짝): README 가 묻지 않고 고칠 목록을 남긴다고 말한다"
assert_file_absent "$RM" '`Retry` / `Accept and finish` / `Stop`' "AC6: README 범위 절에 옛 라벨 나열이 없다"
assert_not_contains "$(flat "$RM")" '「고치고 다시 돌기」는 「적용」 항목만 고친다.' "AC6: README 에 고치기 라벨 문장이 없다"
assert_not_contains "$(flat "$RM")" 'Retry 는 「적용」 항목만 고친다' "AC6: README 에 옛 라벨 문장이 없다"

# ⑦ README 상태도가 같은 라벨을 부른다
assert_file_absent "$RM" '분류표\(항목마다 적용 / 제외' "AC6: README 상태도에 분류표 줄이 없다"
assert_file_grep "$RM" '막는 지적 · 차등 defect → 묻지 않는다 — `## 고칠 목록` 을 result.md 에 남기고 e2e 로 간다$' "AC6(양의 짝): README 상태도가 묻지 않고 고칠 목록을 남긴다"
assert_file_absent "$RM" 'Retry / Accept and finish / Stop' "AC6: README 상태도에 옛 라벨 나열이 없다"

# ⑧ e2e 걷기 직후 게이트 — 선택지 넷 · 6 절 칸 행의 글자는 test_e2e_docs.sh 의 case_gate_rows_one_pass 가 잰다.
# 여기서는 옛 영어 라벨이 e2e 절 · 레퍼런스에 없는지만 잰다(양성 짝: 게이트 불릿 · 표 행).
E2S="$(awk '/^## e2e$/{f=1;next} f&&/^## /{exit} f' "$S")"
assert_grep "$E2S" '^\*\*E4 — 걷기 직후 게이트\.\*\*' "e2e 절을 잘랐다(양성 짝 — 창이 비면 아래 부재 단언이 공허하다)"
assert_grep "$E2S" '^- \*\*fail 로 둔다\*\* \(fail 행\) — ' "AC4: e2e 게이트 fail 행 불릿 「fail 로 둔다」"
assert_not_grep "$E2S" '^- \*\*(Retry|Accept|Accept and finish|Stop)\*\*' "AC4: e2e 게이트에 옛 영어 라벨 불릿이 없다"
assert_file_grep "$E2R" '^\| fail \| fail 로 둔다 / pass 로 뒤집기 / 다시 걷기 \|$' "AC4: e2e 레퍼런스 게이트 표의 fail 행이 새 라벨이다(양성 짝)"
assert_file_absent "$E2R" 'Accept and finish|Retry|Abort retry' "AC4: e2e 레퍼런스에 옛 영어 라벨이 없다"
E2RF="$(flat "$E2R")"
assert_contains "$E2RF" '증거표와 판정안을 보인 뒤 `AskUserQuestion` 하나를 띄운다. 질문 본문에는 판정안 한 줄, 충족하지 못한 기대 상태를 한 줄씩(없으면 「충족하지 못한 기대 상태 없음」), 「증거표: <세션 폴더의 `e2e-evidence.tsv` 경로>」 한 줄을 싣는다 — 질문 창만 보고 고를 수 있게.' "AC10: e2e 판정 질문의 본문이 판정안 · 못 채운 기대 상태 · 증거표 자리를 싣는다"
assert_file_absent "$E2R" 'Accept|Stop|Retry /|Retry 를 넣지' "AC6: e2e 레퍼런스에 옛 선택지 이름이 없다"

# ⑨ 비평 최종 보고
CAF="$(flat "$CA")"
assert_contains "$CAF" '보고의 첫 줄은 끝났는지와 결과 한 문장이다' "§4: 비평 최종 보고 첫 줄"
assert_contains "$CAF" '잔여 `kept` 항목에 `plain:` 이 있으면 그것을 먼저 쓰고 원래 `summary` 는 뒤 괄호에 둔다' "R7: 비평 보고가 plain 을 먼저 쓴다"
assert_contains "$CAF" '맨 끝에 사용자가 할 일을 쓴다 — 기본 하나, 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다.' "AC2: 비평 최종 보고 끝 할 일 — 기본 하나 · 여럿이면 밝힘"
assert_not_contains "$CAF" '할 일 하나를 쓴다' "AC2: 비평 보고에 옛 「할 일 하나를 쓴다」 없음"

# ⑪ 게시 게이트가 완료 표의 바뀐 칸 이름을 부른다(OUTCOME 변수 이름과 값은 그대로)
PB="$(awk '/^## Publish$/{f=1;next} f&&/^## /{exit} f' "$S")"
assert_grep "$PB" '^OUTCOME="' "Publish 절을 잘랐다(양성 짝)"
assert_contains "$(printf '%s\n' "$PB" | tr '\n' ' ' | tr -s ' ')" '`OUTCOME` 에 `## Final verdict` 표의 결과 칸 값(Outcome)을' "AC6: 게시 게이트 OUTCOME 출처가 결과 칸을 부른다"
assert_grep "$PB" '^OUTCOME="<Final verdict 표의 결과 칸 값 그대로>"$' "AC6: 게시 펜스 OUTCOME 자리표시가 결과 칸을 부른다"
assert_not_grep "$PB" 'Outcome 값' "AC6: 게시 게이트에 옛 칸 이름(Outcome 값)이 없다"
finish
