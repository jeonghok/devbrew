#!/usr/bin/env bash
# start_bundle.py — 리더 묶음의 끝에서 끝(AC21 · AC22 · AC31). 걸음마다 main 을 바꿨으면 되돌려 올리고 B 를 다시 읽는다.
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

finish
