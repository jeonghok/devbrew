#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/artifact-critique/SKILL.md plugins/quality-gates/references/e2e.md
#
# 쉬운 말 출력 설계 §4 · AC6 — /quality-gates:quality-pipeline 의 질문 · 완료 표 · 모델이 그대로 내는 문구가 한국어이고,
# 완료 보고와 비평 최종 보고가 첫 줄 상태 · 끝 할 일(기본 하나 — 여럿이거나 병렬이면 밝힘)을 지시받는다.
# 부재 단언마다 양성 짝이 있다 — 같은 자리에 두거나, 짝을 재는 다른 테스트를 그 절 머리에 밝힌다(부재 락은 통째로 지워도 통과한다).
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
E2R="$PLUGIN_ROOT/references/e2e.md"
# 산문은 줄바꿈을 지운 본문에서 잰다 — 다시 쓰일 때 문장이 줄을 넘을 수 있다.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
qlines() { grep -E '^[[:space:]]*question:' "$1"; }
SF="$(flat "$S")"

# ① 질문 — question 줄에서 잰다. 고치기 반복의 질문(반복 게이트 · 범위 모드 · 상한 · 분류 · 수정 실패)은 없다 —
# 한 실행은 한 번 지나고 묻지 않는다(그 부재는 test_one_pipeline_surface.sh 의 case_one_pass_flow 가 잰다).
assert_eq "$(qlines "$S" | grep -c .)" "1" "AC6: 이 SKILL 의 question 줄은 하나다(낮춘 지적 질문 — 고치기 반복의 질문이 빠졌다)"

# ② 선택지 라벨 · 머리글 — 옛 라벨 부재(새 라벨 「그대로 둔다」 · 머리글 「낮춘 지적」 양성은 test_lowered_gate_wiring.sh case_step45_gate 가 잰다)
assert_file_absent "$S" 'label: "(Retry|Accept and finish|Stop|Abort retry|Skip this file)"' "AC6: 영어 선택지 라벨이 없다"
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
assert_contains "$SF" 'with one Korean sentence' "§4: 완료 보고 첫 줄은 한국어 한 문장"
assert_contains "$SF" 'do not restate them' "규칙 블록: 개수를 다시 풀어 쓰지 않는다"
assert_contains "$SF" 'one by default; if there are several' "AC2: 완료 보고 끝 할 일 — 기본 하나 · 여럿이면 밝힘"
assert_not_contains "$SF" 'exactly one next action' "AC2: exactly one 없음"
assert_contains "$SF" "the intent-critic result line (or its skip notice) is the run's last script output, followed by the return block." "intent-critic 결과 줄(또는 건너뜀 줄)이 스크립트 출력의 마지막이다(할 일 줄과 충돌하지 않는다)"
assert_not_contains "$SF" "the publish result line is the run's last" "게시 결과 줄이 마지막 출력이라는 옛 문장이 없다(intent-critic 단계가 게시 뒤에 돈다)"

# ⑤ 모델이 그대로 내는 문구 — trivia 줄 · 범위 줄 · 범위 경고. 문구마다 옛 영어 부재와 한국어 낱말 하나를 짝으로 잰다.
assert_contains "$SF" '작은 수정이라 파이프라인을 건너뛰었다(trivia diff)' "AC6: trivia 줄이 한국어다"
assert_contains "$SF" '작은 수정이라 파이프라인을 건너뛰었다(trivia diff — <토픽 전체 | 범위 전체>)' "AC6 · AC28: 토픽 · 범위 전체 trivia 줄이 한국어다"
assert_file_absent "$S" 'Trivia diff — pipeline skipped' "AC6: 옛 trivia 줄이 없다"
assert_file_grep "$S" '리뷰 범위: 이번 세션' "AC6: session 범위 줄"
assert_file_grep "$S" '리뷰 범위: 토픽' "AC6: topic 범위 줄"
assert_file_absent "$S" 'Review scope: (session|topic)' "AC6: 옛 범위 줄이 SKILL 에 없다"
assert_file_grep "$S" '범위를 확인하지 못했다' "AC6: 범위 경고가 쉬운 말로 시작한다"
assert_file_grep "$S" '0개인지 보는 검사를 건너뛰었다' "AC6: 범위 경고가 건너뛴 검사를 말한다"
assert_file_absent "$S" 'empty-scope detection skipped' "AC6: 옛 영어 범위 경고 꼬리가 없다"

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
assert_contains "$CAF" '보고의 첫 줄은' "§4: 비평 최종 보고 첫 줄"
assert_contains "$CAF" '그것을 먼저 쓰고' "R7: 비평 보고가 plain 을 먼저 쓴다"
assert_contains "$CAF" '기본 하나, 여럿이거나' "AC2: 비평 최종 보고 끝 할 일 — 기본 하나 · 여럿이면 밝힘"
assert_not_contains "$CAF" '할 일 하나를 쓴다' "AC2: 비평 보고에 옛 「할 일 하나를 쓴다」 없음"

# ⑪ 게시 게이트가 완료 표의 바뀐 칸 이름을 부른다(OUTCOME 변수 이름과 값은 그대로)
PB="$(awk '/^## Publish$/{f=1;next} f&&/^## /{exit} f' "$S")"
assert_grep "$PB" '^OUTCOME="' "Publish 절을 잘랐다(양성 짝)"
assert_contains "$(printf '%s\n' "$PB" | tr '\n' ' ' | tr -s ' ')" '`OUTCOME` 에 `## Final verdict` 표의 결과 칸 값(Outcome)을' "AC6: 게시 게이트 OUTCOME 출처가 결과 칸을 부른다"
assert_grep "$PB" '^OUTCOME="<Final verdict 표의 결과 칸 값 그대로>"$' "AC6: 게시 펜스 OUTCOME 자리표시가 결과 칸을 부른다"
assert_not_grep "$PB" 'Outcome 값' "AC6: 게시 게이트에 옛 칸 이름(Outcome 값)이 없다"
finish
