#!/usr/bin/env bash
# start_bundle.py — 리더 묶음(AC21 · AC22 · AC31)과 과제 묶음(AC21 · AC24)의 끝에서 끝. 걸음마다 main 을 바꿨으면 되돌려 올리고 B 를 다시 읽는다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_start_bundle.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
SBP="$S/start_bundle.py"
team_repo && ok "팀 레포를 세웠다(${TM})" || { no "팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }

lead() { (cd "$W" && python3 "$SBP" --roadmap "$RM" --role leader) > "$T/lead.txt" 2> "$T/lead.err"; echo $?; }
show() { g show "$B:$1"; }
publish() { g push -q origin main && g fetch -q origin; B="$(g rev-parse origin/main)"; }   # main 의 지금을 올리고 B 를 다시 읽는다

# 준비: 공통 문서를 올리고 팀 규칙 파일에 조건이 서로 다른 규칙 줄 셋을 더한다
{
  printf '# RULES\n'
  printf '%s\n' '- [하나] 역할 한정 · 조건: 역할=writer · 출처: a · 확인: b' \
    '- [둘] 단계 한정 · 조건: 단계=review · 출처: a · 확인: b' \
    '- [셋] 경로 한정 · 조건: 경로=nowhere/** · 출처: a · 확인: b'
} > "$W/$TM/RULES.md"
g add -- "${RD}leader" "${RD}designer" "${RD}writer" "${RD}worker" "${RD}HANDBOOK.md" "$TM/RULES.md" && g commit -qm "공통 문서 · 규칙" && publish

assert_eq "$(lead)" "0" "리더: 종료 코드 0"
printf '기준 커밋: %s\n역할 문서 (%s):\n%s\n규칙 (%s):\n%s\n%s\n' "$B" "$B" "$(show "${RD}leader/CLAUDE.md")" "$B" \
  "$(show "$TM/RULES.md")" "$(show "${RD}HANDBOOK.md")" > "$T/lead.want"
cmp -s "$T/lead.txt" "$T/lead.want" && ok "리더: 기준 커밋 · 리더 역할 문서 · 규칙뿐이고 글은 기준 커밋의 것이다" || no "리더: 묶음이 기대와 다르다"
assert_eq "$(grep -c '^- \[' "$T/lead.txt")" "3" "AC22: 조건이 맞지 않는 줄도 전부 실린다"
cp "$T/lead.txt" "$T/lead.first"
printf '\n- 작업 폴더에서만 고친 줄\n' >> "$W/${RD}leader/CLAUDE.md"; printf 'x\n' >> "$W/$TM/RULES.md"; printf 'x\n' >> "$W/${RD}HANDBOOK.md"
lead > /dev/null; cmp -s "$T/lead.txt" "$T/lead.first" && ok "AC21: 작업 폴더의 사본을 고쳐도 출력이 같다" || no "AC21: 작업 폴더의 사본이 묶음에 샜다"
g checkout -q -- "$RD"

# ① 예산 — 알림 한 줄이 더해지고 종료 코드는 0 이다
OLDB="$B"
printf '%s\n' '---' 'rules_budget: 40' '---' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "예산 40" && publish
assert_eq "$(lead)" "0" "예산: 넘어도 종료 코드 0"
assert_eq "$(sed -n 2p "$T/lead.txt" | cut -c1-4)" "알림: " "예산: 둘째 줄이 알림이다"
assert_contains "$(sed -n 2p "$T/lead.txt")" "예산 초과" "예산: 알림에 예산 초과"
assert_contains "$(sed -n 2p "$T/lead.txt")" "$TM/RULES.md" "예산: 알림에 팀 규칙 파일 경로"
sed "s/$OLDB/$B/g" "$T/lead.first" > "$T/lead.rebased"
sed 2d "$T/lead.txt" > "$T/lead.rest"
cmp -s "$T/lead.rest" "$T/lead.rebased" && ok "예산: 알림 한 줄을 뺀 나머지는 같다(기준 커밋 글자만 새것)" || no "예산: 알림 밖이 달라졌다"
g revert --no-edit HEAD >/dev/null && publish
assert_eq "$(lead)" "0" "예산: 되돌린 뒤 0"
assert_eq "$(grep -c '^알림: ' "$T/lead.txt")" "0" "예산: 되돌린 뒤 알림 없음"

# ② 팀 규칙 파일이 main 에 없다 — 멈추지 않고 알림
g rm -q -- "$TM/RULES.md" && g commit -qm "규칙 파일 삭제" && publish
assert_eq "$(lead)" "0" "규칙 없음: 종료 코드 0"
assert_contains "$(grep '^알림: ' "$T/lead.txt")" "$TM/RULES.md 가 기준 커밋에 없다" "규칙 없음: 알림에 경로와 사유"
g revert --no-edit HEAD >/dev/null && publish

# ③ 리더 역할 문서가 main 에 없다 — 멈춘다
g rm -q -- "${RD}leader/CLAUDE.md" && g commit -qm "역할 문서 삭제" && publish
assert_eq "$(lead)" "1" "역할 문서 없음: 종료 코드 1"
assert_eq "$(wc -c < "$T/lead.txt" | tr -d ' ')" "0" "역할 문서 없음: 표준 출력이 비었다"
assert_contains "$(cat "$T/lead.err")" "${RD}leader/CLAUDE.md" "역할 문서 없음: 표준 오류에 경로"
g revert --no-edit HEAD >/dev/null && publish

# ④ 기본 브랜치를 모른다
g remote set-head origin -d
assert_eq "$(lead)" "3" "기본 브랜치 모름: 검사 불가 3"
assert_eq "$(wc -c < "$T/lead.txt" | tr -d ' ')" "0" "기본 브랜치 모름: 표준 출력이 비었다"
assert_contains "$(cat "$T/lead.err")" "origin/HEAD 가 없다" "기본 브랜치 모름: 사유는 기본 브랜치를 모른다는 것(뒤의 다른 지킴이 낸 3 이 아니다)"
g remote set-head origin main
assert_eq "$(lead)" "0" "기본 브랜치 되돌림: 0"

# ⑤ 끝 줄바꿈 없는 역할 문서
printf '%s' '- 끝 줄바꿈 없는 마지막 줄' > "$W/${RD}leader/CLAUDE.md"
g add -- "${RD}leader/CLAUDE.md" && g commit -qm "끝 줄바꿈 없는 역할 문서" && publish
assert_eq "$(lead)" "0" "끝 줄바꿈: 종료 코드 0"
assert_eq "$(grep -A1 -F -- '- 끝 줄바꿈 없는 마지막 줄' "$T/lead.txt" | sed -n 2p | cut -c1-4)" "규칙 (" "끝 줄바꿈: 다음 줄이 규칙 머리다"
g revert --no-edit HEAD >/dev/null && publish

# ⑥ 사용법
run() { (cd "$W" && python3 "$SBP" "$@") > "$T/out.txt" 2> "$T/err.txt"; echo $?; }
assert_eq "$(run --roadmap "$RM" --role worker)" "2" "사용법: --role worker 만 주면 2"
assert_eq "$(run --roadmap "$RM" --role boss)" "2" "사용법: 없는 역할은 2"
assert_eq "$(run --roadmap "/$RM" --role leader)" "2" "사용법: 절대 경로 --roadmap 은 2"
assert_eq "$(wc -c < "$T/out.txt" | tr -d ' ')" "0" "사용법: 표준 출력이 비었다"

# ⑧ 로컬 main 의 올리지 않은 커밋은 묶음에 없다
echo "로컬만의 규칙 고침 LOCALMARK" >> "$W/$TM/RULES.md"
g add -- "$TM/RULES.md" && g commit -qm "올리지 않은 고침"
assert_eq "$(lead)" "0" "로컬 앞섬: 종료 코드 0"
assert_eq "$(sed -n 1p "$T/lead.txt")" "기준 커밋: $B" "로컬 앞섬: 첫 줄은 origin/main 의 커밋"
assert_eq "$(grep -c LOCALMARK "$T/lead.txt")" "0" "로컬 앞섬: 묶음에 그 고침이 없다"
g revert --no-edit HEAD >/dev/null

# ⑦ AC31 — 팀 규칙 파일만 leader_ref 의 커밋에서 읽는다
g checkout -q -b leader-state "$B"
printf 'LSMARK\n' >> "$W/$TM/RULES.md"; printf 'LSMARK\n' >> "$W/${RD}HANDBOOK.md"; printf 'LSMARK\n' >> "$W/${RD}leader/CLAUDE.md"
g add -- "$TM/RULES.md" "${RD}HANDBOOK.md" "${RD}leader/CLAUDE.md" && g commit -qm "leader-state"
LS="$(g rev-parse leader-state)"
g checkout -q main
assert_eq "$(lead)" "0" "ref 함수: 바꾸지 않고 부른다"
assert_eq "$(grep -c LSMARK "$T/lead.txt")" "0" "ref 함수: 바꾸지 않은 묶음에는 leader-state 의 글이 없다"
PRC=0
(cd "$W" && python3 - "$S" "$RM" > "$T/patched.txt" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import team_layout
team_layout.leader_ref = lambda ref: "refs/heads/leader-state"
import start_bundle
sys.exit(start_bundle.main(["--roadmap", sys.argv[2], "--role", "leader"]))
PY
) || PRC=$?
assert_eq "$PRC" "0" "ref 함수: 바꾼 부름 종료 코드 0"
assert_eq "$(grep -F "규칙 (" "$T/patched.txt")" "규칙 (${B} · 팀 규칙은 ${LS}):" "U18: 두 커밋이 다르면 머리 줄에 둘 다"
g show "$LS:$TM/RULES.md" > "$T/ls.rules"
printf '기준 커밋: %s\n역할 문서 (%s):\n%s\n규칙 (%s · 팀 규칙은 %s):\n%s\n%s\n' "$B" "$B" "$(show "${RD}leader/CLAUDE.md")" "$B" "$LS" \
  "$(cat "$T/ls.rules")" "$(show "${RD}HANDBOOK.md")" > "$T/patched.want"
cmp -s "$T/patched.txt" "$T/patched.want" && ok "AC31: 팀 규칙은 leader-state 의 글, 공통 규칙 · 역할 문서는 기준 커밋의 글" || no "AC31: 읽은 커밋이 기대와 다르다"
assert_eq "$(grep -c LSMARK "$T/patched.txt")" "1" "AC31: leader-state 의 글은 팀 규칙 파일의 한 줄뿐"
# I2 — start_bundle 을 먼저 import 한 뒤에 바꿔 끼워도 그 값이 닿는다(부를 때마다 모듈에서 찾는다)
PRC=0
(cd "$W" && python3 - "$S" "$RM" > "$T/patched2.txt" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import start_bundle
import team_layout
team_layout.leader_ref = lambda ref: "refs/heads/leader-state"
sys.exit(start_bundle.main(["--roadmap", sys.argv[2], "--role", "leader"]))
PY
) || PRC=$?
assert_eq "$PRC" "0" "I2: import 뒤에 바꾼 부름 종료 코드 0"
cmp -s "$T/patched2.txt" "$T/patched.want" && ok "I2: import 뒤에 바꿔 끼워도 팀 규칙은 leader-state 의 글" || no "I2: import 뒤에 바꾼 ref 함수가 묶음에 닿지 않았다"

# ── 과제 묶음(AC21 · AC24) ── main 을 바꾼 걸음은 되돌려 올리고, 과제 브랜치는 jpush 로 올려 J 를 다시 읽는다
publish   # ⑧ 의 고침과 되돌림(합치면 바뀐 것 없음)을 올려 로컬 main 과 origin/main 을 맞춘다
job() { (cd "$W" && python3 "$SBP" --roadmap "$RM" "$@") > "$T/job.txt" 2> "$T/job.err"; echo $?; }
line() { sed -n "${1}p" "$T/job.txt"; }
jpush() { g push -q origin feature/tm-e1 && g fetch -q origin; J="$(g rev-parse feature/tm-e1)"; }
doc_lines() { g show "$B:${RD}$1/CLAUDE.md" | wc -l | tr -d ' '; }
E1="$TM/jobs/E1"
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "E1 설계 한 줄"
put "$E1/plan-1.md" "E1 계획 한 줄"
g commit -qm "E1 설계 · 계획" && jpush
g checkout -q main

assert_eq "$(job --job E1 --stage implement --plan 1)" "0" "과제: implement 묶음"
assert_eq "$(line 1)" "기준 커밋: ${B} · 과제 브랜치 ${J}" "과제: 첫 줄의 두 커밋"
assert_eq "$(line 2)" "과제: ${E1}/INTENT.md" "과제: INTENT.md 경로"
assert_eq "$(line 3)" "원자료: ${B}:${TM}/intent/original.md 2–4행" "과제: 원자료는 커밋 · 경로 · 줄 범위"
assert_eq "$(line 4)" "읽을 것: ${E1}/INTENT.md · ${E1}/design.md · ${E1}/plan-1.md" "과제: 읽을 것"
assert_eq "$(line 5)" "쓸 것: ${E1}/results/implement-plan-1-1.md" "과제: 쓸 것은 시도 1"
assert_eq "$(line 6)" "맞추는 명령: roadmap_write.py job sync --result ${E1}/results/implement-plan-1-1.md --role worker --bundle-at ${B} --job-at ${J}" "과제: 맞추는 명령(U8)"
assert_eq "$(line 7)" "역할 문서 (${B}):" "과제: implement 의 기본 역할은 worker"
assert_eq "$(sed -n '8,$p' "$T/job.txt" | head -n "$(g show "$B:${RD}worker/CLAUDE.md" | wc -l | tr -d ' ')")" "$(g show "$B:${RD}worker/CLAUDE.md")" "과제: 역할 문서의 글"
assert_eq "$(grep -c "^규칙 (${B}):$" "$T/job.txt")" "1" "과제: 규칙 머리"
assert_eq "$(grep -c 'sources.md' "$T/job.txt")" "0" "AC21: design 밖의 단계에는 번호 파일이 없다"
assert_eq "$(grep -c '^쓸 자리: ' "$T/job.txt")" "0" "과제: implement 에는 쓸 자리 줄이 없다"
cp "$T/job.txt" "$T/job.first"; (cd "$W/docs" && python3 "$SBP" --roadmap "$RM" --job E1 --stage implement --plan 1) > "$T/job.second"
cmp -s "$T/job.first" "$T/job.second" && ok "AC24: 두 번 실행의 바이트가 같다(선 폴더가 달라도)" || no "AC24: 두 번 실행이 다르다"
assert_eq "$(job --job E1 --stage implement --plan 1 --role writer)" "0" "과제: --role writer"
assert_contains "$(cat "$T/job.txt")" "- 고친 문서의 목차와 앵커를 맞춘다." "과제: writer 의 역할 문서"
assert_eq "$(grep -c '^- 실서비스 배포$' "$T/job.txt")" "0" "과제: worker 의 줄은 없다"
assert_contains "$(line 6)" "--role writer --bundle-at" "과제: 맞추는 명령의 역할은 준 역할"

# plan — 쓸 자리 문장 · designer
assert_eq "$(job --job E1 --stage plan --plan 1)" "0" "과제: plan 묶음"
assert_eq "$(line 3)" "원자료: ${B}:${TM}/intent/original.md 2–4행" "과제: plan 의 원자료에 범위가 있다"
assert_eq "$(line 5)" "쓸 것: ${E1}/results/plan-plan-1-1.md" "과제: plan 의 쓸 것"
assert_eq "$(line 6)" "맞추는 명령: roadmap_write.py job sync --result ${E1}/results/plan-plan-1-1.md --role designer --bundle-at ${B} --job-at ${J}" "과제: plan 의 기본 역할은 designer"
assert_eq "$(line 7)" "쓸 자리: 사용자 선호: 계획은 기본 자리 대신 ${E1}/plan-1.md 에 쓴다." "과제: plan 의 쓸 자리"
assert_eq "$(line 8)" "역할 문서 (${B}):" "과제: plan 의 역할 문서 머리"
assert_eq "$(sed -n '9,$p' "$T/job.txt" | head -n "$(doc_lines designer)")" "$(g show "$B:${RD}designer/CLAUDE.md")" "과제: plan 의 역할 문서는 designer 의 것"
assert_eq "$(job --job E1 --stage plan --plan 2)" "0" "과제: 계획 2 의 plan 묶음(I12 — 블록 브랜치의 둘째)"
assert_eq "$(line 2)" "알림: 과제 브랜치 feature/tm-e1b 가 아직 없다 — 과제 폴더를 기준 커밋에서 읽었다" "과제: 계획 2 는 둘째 브랜치를 본다"
assert_eq "$(grep '^쓸 것: ' "$T/job.txt")" "쓸 것: ${E1}/results/plan-plan-2-1.md" "과제: 계획 2 의 쓸 것"
assert_eq "$(grep '^쓸 자리: ' "$T/job.txt")" "쓸 자리: 사용자 선호: 계획은 기본 자리 대신 ${E1}/plan-2.md 에 쓴다." "과제: 쓸 자리 문장의 번호는 --plan"

# design — 과제 브랜치가 아직 없다(U4) · 원자료 전체 · 번호 파일(I5)
E3="$TM/jobs/E3"
assert_eq "$(job --job E3 --stage design)" "0" "과제: 브랜치 없는 design 묶음(U4)"
assert_eq "$(line 1)" "기준 커밋: ${B} · 과제 브랜치 ${B}" "과제: 브랜치가 없으면 둘째 커밋은 기준 커밋"
assert_eq "$(line 2)" "알림: 과제 브랜치 feature/tm-e3 가 아직 없다 — 과제 폴더를 기준 커밋에서 읽었다" "과제: 브랜치 없음 알림"
assert_eq "$(line 3)" "과제: ${E3}/INTENT.md" "과제: E3 의 INTENT.md"
assert_eq "$(line 4)" "원자료: ${B}:${TM}/intent/original.md" "과제: design 의 원자료는 범위 없이 전체"
assert_eq "$(line 5)" "읽을 것: ${B}:${E3}/sources.md · ${E3}/INTENT.md" "AC21: design 은 번호 파일을 기준 커밋으로 맨 앞에"
assert_eq "$(line 6)" "쓸 것: ${E3}/results/design-1.md" "과제: design 의 쓸 것"
assert_eq "$(line 7)" "맞추는 명령: roadmap_write.py job sync --result ${E3}/results/design-1.md --role designer --bundle-at ${B} --job-at ${B}" "과제: design 의 맞추는 명령"
assert_eq "$(line 8)" "쓸 자리: 사용자 선호: 설계문서는 기본 자리 대신 ${E3}/design.md 에 쓴다." "과제: design 의 쓸 자리"
assert_eq "$(line 9)" "역할 문서 (${B}):" "과제: design 의 역할 문서 머리"

# review — 역할 문서 · 쓸 것 · 맞추는 명령이 없고 검수 기준이 끝에 온다
assert_eq "$(job --job E1 --stage review --plan 1)" "0" "과제: review 묶음"
assert_eq "$(grep -c '^역할 문서 (' "$T/job.txt")" "0" "과제: review 에는 역할 문서가 없다"
assert_eq "$(grep -c '^쓸 것: ' "$T/job.txt")" "0" "과제: review 에는 쓸 것이 없다"
assert_eq "$(grep -c '^맞추는 명령: ' "$T/job.txt")" "0" "과제: review 에는 맞추는 명령이 없다"
assert_eq "$(grep -c "^규칙 (${B}):$" "$T/job.txt")" "1" "과제: review 에도 규칙"
assert_eq "$(tail -n 1 "$T/job.txt")" "검수 기준: 없음 — REVIEW.md 가 없다" "과제: 검수 기준 파일이 없으면 한 줄"
printf '%s\n' '- 반려 하나' '- 반려 둘' > "$W/REVIEW.md"
g add -- REVIEW.md && g commit -qm "검수 기준" && publish
assert_eq "$(job --job E1 --stage review --plan 1)" "0" "과제: 검수 기준이 있는 review 묶음"
assert_eq "$(tail -n 3 "$T/job.txt")" "$(printf '검수 기준 (%s):\n- 반려 하나\n- 반려 둘' "$B")" "과제: 검수 기준의 글이 끝에 온다"
g revert --no-edit HEAD >/dev/null && publish

# E2 — 산출물 칸이 있는 블록(설계 없는 흐름, U1)
g branch -q feature/tm-e2 main && g push -q origin feature/tm-e2 && g fetch -q origin
assert_eq "$(job --job E2 --stage implement)" "0" "과제: 설계 없는 흐름의 implement"
assert_eq "$(line 1)" "기준 커밋: ${B} · 과제 브랜치 $(g rev-parse feature/tm-e2)" "과제: E2 의 둘째 커밋은 그 브랜치 끝"
assert_eq "$(line 3)" "원자료: ${B}:${TM}/intent/original.md 5–7행" "과제: 설계 없는 흐름의 블록도 원자료 범위가 있다"
assert_eq "$(line 5)" "쓸 것: ${TM}/jobs/E2/results/implement-1.md" "과제: 설계 없는 흐름은 번호 없는 이름(U1)"
assert_eq "$(job --job E2 --stage implement --plan 1)" "2" "사용법: 설계 없는 흐름의 implement 에 --plan"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "사용법: 설계 없는 흐름의 --plan — 표준 출력이 비었다"
assert_contains "$(cat "$T/job.err")" "설계 없는 흐름의 결과 파일에는 계획 번호가 붙지 않는다" "사용법: 설계 없는 흐름의 --plan 사유"
assert_eq "$(job --job E2 --stage plan --plan 2)" "1" "과제: 설계 없는 흐름의 plan 도 블록 브랜치의 그 번째를 쓴다(브랜치 하나)"
assert_eq "$(job --job E2 --stage plan --plan 1)" "0" "과제: 설계 없는 흐름의 plan 은 --plan 을 받는다"
assert_eq "$(grep '^쓸 것: ' "$T/job.txt")" "쓸 것: ${TM}/jobs/E2/results/plan-1.md" "과제: 설계 없는 흐름의 plan 결과 이름에는 번호가 없다"
assert_eq "$(grep '^쓸 자리: ' "$T/job.txt")" "쓸 자리: 사용자 선호: 계획은 기본 자리 대신 ${TM}/jobs/E2/plan-1.md 에 쓴다." "과제: 쓸 자리 문장의 번호는 --plan"

# 단순 작업(I8 · U5)
g checkout -q -b chore/tm-fix main
printf '오타를 고친다\n' | (cd "$W" && python3 "$RW" job new --roadmap "$RM" --name fix-typo --branch chore/tm-fix --paths docs/tv/ --goal "오타 고치기") > "$T/out.txt" 2>&1
g add -- "$TM/jobs/fix-typo" && g commit -qm "단순 작업" && g push -q origin chore/tm-fix && g fetch -q origin
FIX="$(g rev-parse chore/tm-fix)"
g checkout -q main
assert_eq "$(job --job fix-typo --stage implement)" "0" "과제: 단순 작업 묶음"
assert_eq "$(line 1)" "기준 커밋: ${B} · 과제 브랜치 ${FIX}" "과제: 단순 작업의 둘째 커밋은 머리 branch 의 끝"
assert_eq "$(line 2)" "과제: ${TM}/jobs/fix-typo/INTENT.md" "과제: 단순 작업의 INTENT.md"
assert_eq "$(grep -c '^원자료:' "$T/job.txt")" "0" "과제: 단순 작업에는 원자료 줄이 없다(U5)"
assert_eq "$(grep '^쓸 것: ' "$T/job.txt")" "쓸 것: ${TM}/jobs/fix-typo/results/implement-1.md" "과제: 단순 작업의 쓸 것"
assert_eq "$(job --job no-such --stage implement)" "1" "과제: 블록도 로드맵 밖 과제도 아닌 이름은 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "과제: 없는 과제 — 표준 출력이 비었다"

# 쓸 것: — 시도 번호(U2 · U3 · C6)
attempt() { g checkout -q feature/tm-e1 && "$@" && g add -- "$E1/results" && g commit -qm "결과 파일" && jpush; g checkout -q main; }
head_of() {  # head_of <attempt> <bundle_at> — implement · 계획 1 결과 파일의 머리 글(끝 줄 없음)
  printf -- '---\ntype: job-result\nstage: implement\nplan: 1\nattempt: %s\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---\n\n' "$1" "$J" "$2" "$J"
}
attempt sync E1 implement-plan-1-1.md --role worker --bundle-at "$B" --job-at "$J" > "$T/rc.txt"; assert_eq "$(cat "$T/rc.txt")" "0" "준비: 시도 1 의 머리를 만든다(job sync 0)"
assert_eq "$(job --job E1 --stage implement --plan 1)" "0" "쓸 것: 끝 줄 없는 시도"
assert_eq "$(line 5)" "쓸 것: ${E1}/results/implement-plan-1-1.md" "쓸 것: 끝 줄 없는 가장 새 시도는 잇는다(U2)"
assert_eq "$(line 4)" "읽을 것: ${E1}/INTENT.md · ${E1}/design.md · ${E1}/plan-1.md" "쓸 것: 잇는 시도 1 에는 앞 시도가 없다"
attempt sync E1 implement-plan-1-1.md --end "$J" > "$T/rc.txt"; assert_eq "$(cat "$T/rc.txt")" "0" "준비: 시도 1 에 끝 줄(job sync 0)"
assert_eq "$(job --job E1 --stage implement --plan 1)" "0" "쓸 것: 끝난 시도"
assert_eq "$(line 5)" "쓸 것: ${E1}/results/implement-plan-1-2.md" "쓸 것: 끝 줄이 있으면 다음 번호"
assert_eq "$(line 4)" "읽을 것: ${E1}/INTENT.md · ${E1}/design.md · ${E1}/plan-1.md · ${E1}/results/implement-plan-1-1.md" "쓸 것: 앞 시도가 읽을 것 끝에(U3)"
attempt sync E1 review-plan-1-1.md --role leader --bundle-at "$B" --job-at "$J" > "$T/rc.txt"; assert_eq "$(cat "$T/rc.txt")" "0" "준비: 검수 결과 파일(job sync 0)"
job --job E1 --stage implement --plan 1 > /dev/null
assert_eq "$(line 4)" "읽을 것: ${E1}/INTENT.md · ${E1}/design.md · ${E1}/plan-1.md · ${E1}/results/implement-plan-1-1.md · ${E1}/results/review-plan-1-1.md" "쓸 것: 가장 새 검수 결과도 읽을 것 끝에(U3)"
attempt put "$E1/results/plan-plan-1-1.md" "x"
attempt put "$E1/results/implement-plan-2-4.md" "x"
job --job E1 --stage implement --plan 1 > /dev/null
assert_eq "$(line 5)" "쓸 것: ${E1}/results/implement-plan-1-2.md" "쓸 것: 다른 단계 · 다른 계획의 파일은 시도 번호를 바꾸지 않는다"
attempt put "$E1/results/implement-plan-1-2.md" "$(head_of 2 "$B")"
job --job E1 --stage implement --plan 1 > /dev/null
assert_eq "$(line 5)" "쓸 것: ${E1}/results/implement-plan-1-2.md" "쓸 것: 머리가 온전하고 끝 줄 없는 시도 2 는 잇는다(양성 대조)"
assert_contains "$(line 4)" "plan-1.md · ${E1}/results/implement-plan-1-1.md · " "쓸 것: 시도 2 를 이으면 앞 시도는 시도 1"
attempt put "$E1/results/implement-plan-1-2.md" "$(head_of 2 nothere)"
job --job E1 --stage implement --plan 1 > /dev/null
assert_eq "$(line 5)" "쓸 것: ${E1}/results/implement-plan-1-3.md" "쓸 것: bundle_at 이 커밋 꼴이 아닌 시도는 읽지 못함 — 다음 번호(C6)"
attempt put "$E1/results/implement-plan-1-2.md" "$(printf -- '---\ntype: job-result\nstage: implement')"
job --job E1 --stage implement --plan 1 > /dev/null
assert_eq "$(line 5)" "쓸 것: ${E1}/results/implement-plan-1-3.md" "쓸 것: 머리가 깨진 시도 다음 번호"

# 사용법:
usage() { assert_eq "$(job "$@")" "2" "사용법: $*"; assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "사용법: $* — 표준 출력이 비었다"; }
usage --job E1
usage --stage implement
usage --job E1 --stage implement --role leader
usage --job E1 --stage design --plan 1
usage --job E1 --stage implement
usage --job E1 --stage review --plan 1 --role worker
usage --job ../x --stage design
usage --job worker --stage design
usage --role leader --plan 1
assert_eq "$(run --roadmap "/${RM}" --role leader)" "2" "사용법: 절대 경로 --roadmap(리더)"
assert_eq "$(run --roadmap "/${RM}" --job E1 --stage design)" "2" "사용법: 절대 경로 --roadmap(과제)"
assert_eq "$(wc -c < "$T/out.txt" | tr -d ' ')" "0" "사용법: 절대 경로 --roadmap — 표준 출력이 비었다"
assert_eq "$(job --job E1 --stage implement --plan 3)" "1" "과제: 블록 브랜치 칸에 그 계획 번째가 없으면 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "과제: 그 계획의 브랜치 없음 — 표준 출력이 비었다"

# 과제 브랜치의 INTENT.md 머리 job 이 인자와 다르다 — 거절(1), 되돌려 올려 뒤 걸음에 흘리지 않는다
g checkout -q feature/tm-e1
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read(); assert "\njob: E1\n" in s; open(p, "w", encoding="utf-8", newline="").write(s.replace("\njob: E1\n", "\njob: E9\n", 1))' "$W/$E1/INTENT.md"
g add -- "$E1/INTENT.md" && g commit -qm "머리 job 을 바꿈" && jpush
g checkout -q main
assert_eq "$(job --job E1 --stage implement --plan 1)" "1" "과제: 브랜치 INTENT.md 머리의 job 이 다른 이름이면 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "과제: 머리 job 이 다름 — 표준 출력이 비었다"
g checkout -q feature/tm-e1 && g revert --no-edit HEAD >/dev/null && jpush
g checkout -q main
assert_eq "$(job --job E1 --stage implement --plan 1)" "0" "과제: 머리 job 을 되돌리면 다시 0(양성 대조)"

# 로컬이 앞선 과제 브랜치 · 갈라진 과제 브랜치
g checkout -q feature/tm-e1 && put "$E1/local.md" "올리지 않은 고침" && g commit -qm "올리지 않음"
LOCAL="$(g rev-parse feature/tm-e1)"
g checkout -q main
assert_eq "$(job --job E1 --stage implement --plan 1)" "0" "과제: 로컬이 앞선 과제 브랜치"
assert_eq "$(line 1)" "기준 커밋: ${B} · 과제 브랜치 ${LOCAL}" "과제: 로컬이 앞서면 둘째 커밋은 로컬 끝"
assert_eq "$(grep -c '^알림: 아직 안 올라옴' "$T/job.txt")" "1" "과제: 올리지 않은 커밋 알림"
g checkout -q feature/tm-e1 && g push -q origin feature/tm-e1 && g commit --amend -qm "갈라짐" && g checkout -q main
assert_eq "$(job --job E1 --stage implement --plan 1)" "3" "과제: 갈라진 과제 브랜치는 검사 불가 3"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "과제: 갈라짐 — 표준 출력이 비었다"

# 이미 기본 브랜치에 머지된 단순 작업 — 묶음을 내지 않고 1(브랜치를 지웠든 남겼든 같다)
merged_task() {   # merged_task <이름> <브랜치> <머지 뒤 브랜치를 지우는가: yes|no>
  g checkout -q -b "$2" main
  printf '머지될 일\n' | (cd "$W" && python3 "$RW" job new --roadmap "$RM" --name "$1" --branch "$2" --paths docs/tv/ --goal "머지된 작업") > "$T/out.txt" 2>&1
  assert_eq "$?" "0" "과제: 머지될 단순 작업($1)을 만들었다"
  g add -- "$TM/jobs/$1" && g commit -qm "단순 작업 $1"
  g checkout -q main && g merge -q --no-ff "$2" -m "머지 $1" && publish
  if [ "$3" = yes ]; then g branch -q -D "$2"; fi
}
merged_task gone-task chore/tm-gone yes
assert_eq "$(job --job gone-task --stage implement)" "1" "과제: 머지 뒤 브랜치를 지운 단순 작업은 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "과제: 머지된 단순 작업(브랜치 없음) — 표준 출력이 비었다"
assert_contains "$(cat "$T/job.err")" "gone-task 는 이미 기본 브랜치에 머지됐다" "과제: 머지된 단순 작업(브랜치 없음) — 사유"
merged_task kept-task chore/tm-kept no
assert_eq "$(job --job kept-task --stage implement)" "1" "과제: 머지만 하고 브랜치를 남긴 단순 작업도 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "과제: 머지된 단순 작업(브랜치 남음) — 표준 출력이 비었다"
assert_contains "$(cat "$T/job.err")" "kept-task 는 이미 기본 브랜치에 머지됐다" "과제: 머지된 단순 작업(브랜치 남음) — 사유"
assert_eq "$(job --job fix-typo --stage implement)" "0" "과제: 머지되지 않은 단순 작업은 그대로 0(양성 대조)"

# 설계 흐름 블록의 브랜치 칸이 비었다 — 멈춘다(1) · 표준 출력은 비고 사유가 블록 번호와 함께 표준 오류로 간다
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read(); old="- 브랜치: feature/tm-e3\n"; assert s.count(old) == 1; open(p, "w", encoding="utf-8", newline="").write(s.replace(old, "- 브랜치:\n"))' "$W/$TM/roadmap.md"
g add -- "$TM/roadmap.md" && g commit -qm "E3 브랜치 칸 비움" && publish
assert_eq "$(job --job E3 --stage design)" "1" "과제: 블록의 브랜치 칸이 비면 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "과제: 브랜치 칸 빔 — 표준 출력이 비었다"
assert_contains "$(cat "$T/job.err")" "블록 E3 의 브랜치 칸에 브랜치가 없다" "과제: 브랜치 칸 빔 — 사유에 블록 번호"
g revert --no-edit HEAD >/dev/null && publish
assert_eq "$(job --job E3 --stage design)" "0" "과제: 칸을 되돌리면 다시 0(양성 대조)"

# 멈춤 다섯과 그 짝(검사 불가) — 종료 코드와 표준 오류의 사유 글. 로드맵 밖 과제는 team_status 의 알림 글로 1 과 3 을 가른다
e2push() { g push -q origin feature/tm-e2 && g fetch -q origin; }
# ⓐ 읽을 커밋에 INTENT.md 가 없다
g checkout -q feature/tm-e2 && g rm -q -- "$TM/jobs/E2/INTENT.md" && g commit -qm "E2 INTENT.md 지움" && e2push
E2T="$(g rev-parse feature/tm-e2)"; g checkout -q main
assert_eq "$(job --job E2 --stage implement)" "1" "멈춤: 과제 브랜치에 INTENT.md 가 없으면 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "멈춤: INTENT.md 없음 — 표준 출력이 비었다"
assert_eq "$(cat "$T/job.err")" "[spec-distill] 멈춤 — $TM/jobs/E2/INTENT.md 가 ${E2T} 에 없다" "멈춤: INTENT.md 없음 — 사유는 경로와 읽은 커밋"
g checkout -q feature/tm-e2 && g revert --no-edit HEAD > /dev/null && e2push && g checkout -q main
assert_eq "$(job --job E2 --stage implement)" "0" "멈춤: INTENT.md 를 되돌리면 다시 0(양성 대조)"
# ⓑ 에픽 INTENT.md 의 지시 원문에 줄 범위가 없다(implement)
g checkout -q feature/tm-e2
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read().split("\n"); k=[l for l in s if not l.startswith("- 범위: intent/original.md ")]; assert len(k) == len(s) - 1; open(p, "w", encoding="utf-8", newline="").write("\n".join(k))' "$W/$TM/jobs/E2/INTENT.md"
g add -- "$TM/jobs/E2/INTENT.md" && g commit -qm "E2 범위 줄 지움" && e2push && g checkout -q main
assert_eq "$(job --job E2 --stage implement)" "1" "멈춤: 에픽 INTENT.md 에 줄 범위가 없으면 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "멈춤: 범위 없음 — 표준 출력이 비었다"
assert_eq "$(cat "$T/job.err")" "[spec-distill] 멈춤 — $TM/jobs/E2/INTENT.md 의 지시 원문에 $TM/intent/original.md 의 줄 범위가 없다" "멈춤: 범위 없음 — 사유"
g checkout -q feature/tm-e2 && g revert --no-edit HEAD > /dev/null && e2push && g checkout -q main
assert_eq "$(job --job E2 --stage implement)" "0" "멈춤: 범위 줄을 되돌리면 다시 0(양성 대조)"
# ⓒ 결정 블록은 과제가 아니다
assert_eq "$(job --job P1 --stage implement)" "1" "멈춤: 결정 블록 이름은 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "멈춤: 결정 블록 — 표준 출력이 비었다"
assert_eq "$(cat "$T/job.err")" "[spec-distill] 멈춤 — P1 는 로드맵의 과제 블록도 로드맵 밖 과제도 아니다" "멈춤: 결정 블록 — 사유(조사 앞 빈칸 없음)"
# 로드맵 밖 과제의 브랜치를 세우고 올린다 — task_branch <브랜치> <이름> <머리 branch>
task_branch() {
  g checkout -q -b "$1" main
  printf '로드맵 밖 일\n' | (cd "$W" && python3 "$RW" job new --roadmap "$RM" --name "$2" --branch "$3" --paths docs/tv/ --goal "로드맵 밖 일") > "$T/out.txt" 2>&1
  assert_eq "$?" "0" "준비: 로드맵 밖 과제 $2 ($1)"
  g add -- "$TM/jobs/$2" && g commit -qm "과제 $2" && g push -q origin "$1" && g fetch -q origin
  g checkout -q main
}
drop_branches() { g push -q origin --delete "$@" && g branch -q -D "$@" && g fetch -q --prune origin; }
# ⓓ 같은 이름의 로드맵 밖 과제 둘
task_branch chore/tm-dup-a dup chore/tm-dup-a
task_branch chore/tm-dup-b dup chore/tm-dup-b
assert_eq "$(job --job dup --stage implement)" "1" "멈춤: 같은 이름의 로드맵 밖 과제 둘은 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "멈춤: 같은 이름 둘 — 표준 출력이 비었다"
assert_eq "$(cat "$T/job.err")" "[spec-distill] 멈춤 — 같은 이름의 로드맵 밖 과제가 둘이다: dup — chore/tm-dup-a · chore/tm-dup-b" "멈춤: 같은 이름 둘 — 사유에 두 브랜치(조사 앞 빈칸 없음)"
drop_branches chore/tm-dup-a chore/tm-dup-b
# ⓔ 머리 branch 가 그 폴더가 있는 브랜치가 아니다 — team_status 가 「세지 않았다」 로 알린 것은 멈춤(1)
task_branch chore/tm-wb wrongbr chore/tm-elsewhere
assert_eq "$(job --job wrongbr --stage implement)" "1" "멈춤: 머리 branch 가 다른 과제는 1"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "멈춤: 머리 branch 다름 — 표준 출력이 비었다"
assert_eq "$(cat "$T/job.err")" "[spec-distill] 멈춤 — 로드맵 밖 과제 wrongbr 을 세지 않았다 — 머리의 branch(chore/tm-elsewhere) 와 이름이 맞는 브랜치에 이 과제 폴더가 없다" "멈춤: 머리 branch 다름 — 사유는 team_status 의 알림 글 그대로"
drop_branches chore/tm-wb
# ⓔ 의 짝 — team_status 가 「세지 못했다」 로 알린 것(머리가 깨진 INTENT.md)은 검사 불가(3)
g checkout -q -b chore/tm-hb main
put "$TM/jobs/hb/INTENT.md" "$(printf -- '---\ntype: job\nkind: task')"
g commit -qm "깨진 머리" && g push -q origin chore/tm-hb && g fetch -q origin && g checkout -q main
assert_eq "$(job --job hb --stage implement)" "3" "검사 불가: 머리가 깨진 로드맵 밖 과제는 3"
assert_eq "$(wc -c < "$T/job.txt" | tr -d ' ')" "0" "검사 불가: 깨진 머리 — 표준 출력이 비었다"
assert_eq "$(cat "$T/job.err")" "[spec-distill] 검사 불가 — 로드맵 밖 과제 hb 을 세지 못했다 — $TM/jobs/hb/INTENT.md 머리를 읽지 못했다 — INTENT 머리말이 닫히지 않았다" "검사 불가: 깨진 머리 — 사유는 team_status 의 알림 글 그대로"
drop_branches chore/tm-hb
assert_eq "$(job --job fix-typo --stage implement)" "0" "멈춤 픽스처를 치운 뒤 단순 작업은 그대로 0(양성 대조)"

# ── 끝에서 끝 — 새 레포: create --layout team → 공통 문서 → job new → 시작 묶음 → 맞추는 명령 → 끝 줄 → 결과 대조 → 받음 줄 → 결과 받음.
#    걸음마다 앞 걸음의 출력을 다음 걸음이 받는다 ──
T1="$T"; T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T1" "$T"' EXIT
W="$T/repo"
team_repo && ok "끝에서 끝: 새 팀 레포를 세웠다(${TM})" || { no "끝에서 끝: 새 팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }
g add -- "${RD}leader" "${RD}designer" "${RD}writer" "${RD}worker" "${RD}HANDBOOK.md" && g commit -qm "공통 문서" && publish
assert_eq "$?" "0" "끝에서 끝: 공통 문서를 기본 브랜치에 올렸다"
EJ="$TM/jobs/e2e"
g checkout -q -b chore/e2e main
NEW_RC=0; printf '문서 하나를 고친다\n' > "$T/said.txt"
(cd "$W" && python3 "$RW" job new --roadmap "$RM" --name e2e --branch chore/e2e --paths docs/tv/ --goal "문서 하나 고치기" < "$T/said.txt") > "$T/out.txt" 2>&1 || NEW_RC=$?
assert_eq "$NEW_RC" "0" "끝에서 끝: job new 0"
g add -- "$EJ" && g commit -qm "과제 폴더 e2e" && g push -q origin chore/e2e && g fetch -q origin
assert_eq "$?" "0" "끝에서 끝: 과제 폴더를 커밋해 올렸다"
EJT="$(g rev-parse chore/e2e)"
E_RC=0; (cd "$W" && python3 "$SBP" --roadmap "$RM" --job e2e --stage implement) > "$T/e2e.txt" 2> "$T/e2e.err" || E_RC=$?
assert_eq "$E_RC" "0" "끝에서 끝: 시작 묶음 0"
assert_eq "$(sed -n 1p "$T/e2e.txt")" "기준 커밋: ${B} · 과제 브랜치 ${EJT}" "끝에서 끝: 묶음 첫 줄은 기준 커밋과 과제 브랜치 끝"
CMD="$(grep '^맞추는 명령: ' "$T/e2e.txt")"
assert_eq "$(printf '%s' "$CMD" | cut -d' ' -f1-5)" "맞추는 명령: roadmap_write.py job sync" "끝에서 끝: 맞추는 명령 줄이 있다"
read -r -a SYNC_ARGS <<< "${CMD#*roadmap_write.py }"
S_RC=0; (cd "$W" && python3 "$RW" "${SYNC_ARGS[@]}") > "$T/out.txt" 2>&1 || S_RC=$?
assert_eq "${S_RC} · $(cat "$T/out.txt")" "0 · [spec-distill] 결과 파일을 맞췄다: ${EJ}/results/implement-1.md — 머리 만듦" "끝에서 끝: 맞추는 명령을 그대로 돌리면 결과 파일의 머리를 만든다"
ER="$W/$EJ/results/implement-1.md"
assert_eq "$(grep '^bundle_at: ' "$ER") · $(grep '^job_at: ' "$ER")" "bundle_at: ${B} · job_at: ${EJT}" "끝에서 끝: 결과 파일 머리의 bundle_at · job_at 이 묶음 첫 줄의 두 커밋"
put docs/tv/fixed.md "끝에서 끝으로 고친 문서" && g commit -qm "고친 문서" && ECODE="$(g rev-parse HEAD)"
printf '산출물: docs/tv/fixed.md\n' >> "$ER"
assert_eq "$(sync e2e implement-1.md --end "$ECODE")" "0" "끝에서 끝: job sync --end 0"
g add -- "$EJ" && g commit -qm "결과 파일" && g push -q origin chore/e2e && g fetch -q origin
assert_eq "$?" "0" "끝에서 끝: 결과 파일을 커밋해 올렸다"
echeck() { local rc=0; (cd "$W" && python3 "$S/job_results.py" check --roadmap "$RM" --job e2e --result implement-1.md --branch chore/e2e --date 2026-11-30) > "$T/check.txt" 2>&1 || rc=$?; echo "$rc"; }
assert_eq "$(echeck)" "0" "끝에서 끝: 결과 대조 0"
ELINE="$(grep '^- 결과 받음 · ' "$T/check.txt")"
assert_eq "$ELINE" "- 결과 받음 · 2026-11-30 · 「implement-1.md · ${ECODE} · $(head -n 1 "$T/check.txt")」" "끝에서 끝: 결과 대조가 받음 줄을 낸다"
decide e2e "$ELINE" && g add -- "$EJ" && g commit -qm "받음 줄" && g push -q origin chore/e2e && g fetch -q origin
assert_eq "$?" "0" "끝에서 끝: 받음 줄을 INTENT.md 에 적어 올렸다"
assert_eq "$(status "$T/s.json")" "0" "끝에서 끝: 단계 계산 0"
assert_eq "$(js "$T/s.json" "[j['stage'] for j in r['jobs'] if j['id']=='e2e']")" "['결과 받음']" "끝에서 끝: 그 과제가 결과 받음"
# AC24 — bundle_at 을 이 레포에 없는 커밋으로 바꿔 올리면 결과 대조가 거절(1)하고 사유에 bundle_at
python3 -c 'import sys; p, old, new = sys.argv[1:4]; s=open(p, encoding="utf-8", newline="").read(); assert s.count(old) == 1; open(p, "w", encoding="utf-8", newline="").write(s.replace(old, new))' \
  "$ER" "bundle_at: ${B}" "bundle_at: 0123456789abcdef0123456789abcdef01234567"
g add -- "$EJ" && g commit -qm "bundle_at 을 없는 커밋으로" && g push -q origin chore/e2e && g fetch -q origin
assert_eq "$(echeck)" "1" "끝에서 끝: AC24 — bundle_at 이 없는 커밋이면 거절 1"
assert_contains "$(grep '^거절 사유: ' "$T/check.txt")" "bundle_at" "끝에서 끝: AC24 — 거절 사유에 bundle_at"

finish
