#!/usr/bin/env bash
# 병렬 권장 에픽(설계 2026-10-25-epic-parallel-recommend) — 문서 락 모음.
# 과제별로 아래에 단언을 덧붙인다. 도우미: loop_of · cyc <걸음> · man <손 절차 번호> · count · once_in.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_parallel_recommend_docs.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
CD="$SD/references/conducting.md"
PG="$SD/references/proceed-gate.md"
SRS="$SD/skills/spec-review/SKILL.md"
AG="$SD/agents/integration-reviewer.md"
SK="$SD/skills/epic-conductor/SKILL.md"
EH="$SD/references/epic-handoff.md"
DP="$SD/references/docreview-profiles/design-doc.md"

loop_of() { awk '$0=="## 지휘 순환"{f=1;next} f&&/^## /{exit} f' "$CD"; }
cyc() { loop_of | awk -v n="$1" 'index($0, "### " n ". ")==1{f=1;next} f&&/^### /{exit} f'; }
man() { awk '$0=="## 손으로 따르는 절차"{f=1;next} f&&/^## /{exit} f' "$CD" | awk -v n="$1" 'index($0, n ". ")==1{f=1;print;next} f&&/^[0-9]+\. /{exit} f'; }
count() { printf '%s\n' "$1" | grep -oF -- "$2" | wc -l | tr -d ' '; }
once_in() { assert_eq "$(count "$2" "$3")" "1" "$1: 「$3」 정확히 한 번"; }

# --- 도우미 양성 대조 ---
assert_contains "$(man 8)" "머지 전 확인" "man 8 은 머지 전 확인 걸음이다"
assert_not_contains "$(man 8)" "9. **끝.**" "man 8 은 9번 걸음을 담지 않는다"
if [ -n "$(cyc 5)" ]; then ok "cyc 5 가 비지 않았다"; else no "cyc 5 가 비었다"; fi

# --- AC11: 통합 리뷰어 일곱째 이음매 ---
PROF="$(cat "$AG")"
assert_contains "$PROF" "- tag: intents" "프로필: intents 입력 칸"
assert_contains "$PROF" "var: INTENTS" "프로필: INTENTS 변수"
assert_contains "$PROF" '- `<intents>` — 이 PR 과 함께 진행된 다른 에픽들의 설계문서 전문을 모은 파일 경로(`intents.md`). 에픽마다 `### <에픽> <설계문서 경로>(머지됨 | 열림)` 아래 전문이다.' "프로필: 입력 줄"
assert_contains "$PROF" '7. 함께 진행된 에픽의 설계 의도 — `intents` 의 Goals · Non-goals · 결정 기록 · 판정과 이 PR 이 어긋나거나, 이 PR 이 그 의도가 기대는 동작 · 문구 · 규약을 무너뜨리는가. 경로가 겹치지 않아도 본다. 이 PR 이 앞 에픽의 의도를 망가뜨렸으면 고칠 곳은 「이 PR 이 고침」 이다.' "프로필: 이음매 7"
assert_contains "$PROF" '<위 1~7 의 이름>' "프로필: 내는 것 1~7"
assert_not_contains "$PROF" '<위 1~6 의 이름>' "프로필: 옛 1~6 없음"
assert_contains "$PROF" '1. 옮겨지거나 이름이 바뀐 것의 import · 호출 — 다른 에픽의 diff 가 옛 이름을 쓰는가.' "이음매 1 유지"
assert_contains "$PROF" '2. 같은 파일을 고친 에픽들의 순서와 문구 — 머지 순서에 따라 한쪽 문구가 되살아나거나 사라지는가.' "이음매 2 유지"
assert_contains "$PROF" '3. 상태 · 경로 규약 — 한 에픽이 바꾼 경로 · 형식을 다른 에픽이 옛 꼴로 읽는가.' "이음매 3 유지"
assert_contains "$PROF" '4. 합계 제약 — 줄 상한 · 버전 · 개수처럼 따로는 맞고 합치면 넘는 것.' "이음매 4 유지"
assert_contains "$PROF" '5. 테스트가 못 잡는 되살아난 옛 문구, 리뷰어 프로필의 규칙 제거 · 기준 완화(사용자 결정이 앞선 인계에 있는가).' "이음매 5 유지"
assert_contains "$PROF" '6. 앞선 인계의 「뒤 에픽이 고침」 항목이 이 PR 에서 실제로 고쳐졌는가.' "이음매 6 유지"
SKT="$(cat "$SK")"
assert_contains "$SKT" '<intents>${INTENTS}</intents>' "SKILL: intents dispatch 칸"
assert_contains "$SKT" '나머지 넷은' "SKILL: 나머지 넷은"
assert_not_contains "$SKT" '나머지 셋은' "SKILL: 옛 나머지 셋은 없음"
C5="$(cyc 5)"
once_in "cyc 5" "$C5" '함께 진행된 에픽의 설계문서 전문(`intents.md`)'
once_in "cyc 5" "$C5" '일곱째 이음매로'
M8="$(man 8)"
assert_contains "$M8" '`python3 "<SD>"/scripts/conductor_ledger.py review-pack` 의 `intents.md`' "man 8: review-pack intents.md"
assert_contains "$M8" '함께 진행된 에픽의 설계 의도(Goals · Non-goals · 결정 기록 · 판정)와 이 PR 의 어긋남' "man 8: 설계 의도 어긋남"

finish
