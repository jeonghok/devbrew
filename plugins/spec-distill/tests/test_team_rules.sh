#!/usr/bin/env bash
# team_rules.py — check · candidates 명령의 끝에서 끝(AC19 · AC20 · AC26).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_team_rules.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
TRP="$S/team_rules.py"
team_repo && ok "팀 레포를 세웠다(${TM})" || { no "팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }

GOOD='- [테스트] 고친 곳엔 테스트 먼저 · 조건: 역할=worker, 단계=implement · 출처: R3 결정 기록 2026-11-20 · 확인: 테스트 명령을 돌려 본다'
BAD='- [태그] 글 · 조건: 단계=deploy · 출처: a · 확인: b'
HB="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import team_layout as t; print(t.handbook(sys.argv[2]))' "$S" "$RD")"
run() { (cd "$W" && python3 "$TRP" "$@") > "$T/out.txt" 2> "$T/err.txt"; echo $?; }
reason() { python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import team_rules as t; print(t.BAD_VALUE % ("단계", "deploy"))' "$S"; }

assert_eq "$(run check --roadmap "$RM")" "0" "규칙: 빈 틀은 통과"
assert_eq "$(sed -n 1p "$T/out.txt")" "규칙 검사: 통과 — 규칙 줄 0개 · 공통 규칙 줄 0개" "규칙: 첫 줄에 상태"
printf '%s\n' "$BAD" >> "$W/$TM/RULES.md"                       # 커밋하지 않는다
assert_eq "$(run check --roadmap "$RM")" "1" "규칙: 작업 폴더의 파일을 읽어 어긋남(1)"
assert_eq "$(sed -n 2p "$T/out.txt")" "$TM/RULES.md:2: $(reason) — ${BAD}" "규칙: 그 줄을 경로 · 줄 번호 · 사유와 함께 낸다"
assert_eq "$(run check --roadmap "$RM" --ref origin/main)" "0" "규칙: --ref 는 그 커밋의 파일을 읽는다(작업 폴더의 고침을 보지 않는다)"
assert_eq "$(run check --roadmap "$RM" --ref no-such-ref)" "3" "규칙: 없는 ref 는 검사 불가(3)"
assert_eq "$(run check --roadmap "${RD}nope/roadmap.md")" "3" "규칙: 없는 팀은 검사 불가(3) — 통과로 내지 않는다"
g checkout -q HEAD -- "$TM/RULES.md"

# ① 공통 규칙 파일이 없으면 팀 규칙 파일의 상태 그대로 · 표준 오류에 알림 한 줄
cp "$W/$HB" "$T/handbook.keep" && rm "$W/$HB"
assert_eq "$(run check --roadmap "$RM")" "0" "규칙: 공통 규칙 파일이 없어도 팀 규칙 파일이 괜찮으면 통과"
assert_eq "$(wc -l < "$T/err.txt" | tr -d ' ')" "1" "규칙: 알림은 표준 오류에 한 줄"
assert_eq "$(grep -c -F "$HB" "$T/err.txt")" "1" "규칙: 알림에 그 경로가 있다"
cp "$T/handbook.keep" "$W/$HB"

# ② 팀 규칙 파일이 없으면 어긋남
rm "$W/$TM/RULES.md"
assert_eq "$(run check --roadmap "$RM")" "1" "규칙: 팀 규칙 파일이 없으면 어긋남(1)"
assert_eq "$(grep -c -F "$TM/RULES.md" "$T/out.txt")" "1" "규칙: 출력에 그 경로가 있다"
g checkout -q HEAD -- "$TM/RULES.md"

# ③ 레포 설정의 예산
printf '# RULES\n%s\n' "$GOOD" > "$W/$TM/RULES.md"
printf '%s\n' '---' 'rules_budget: 40' '---' > "$W/.devbrew.md"
g add -- .devbrew.md "$TM/RULES.md" && g commit -qm "예산 40" && g push -q origin main && g fetch -q origin
assert_eq "$(run check --roadmap "$RM")" "1" "규칙: 레포 설정의 예산을 넘으면 어긋남(1)"
assert_eq "$(grep -c -F "예산 초과" "$T/out.txt")" "1" "규칙: 예산 초과 줄이 있다"
assert_eq "$(grep -c -F "40바이트" "$T/out.txt")" "1" "규칙: 예산 40바이트가 적힌다"
g rm -q -- .devbrew.md && g commit -qm "예산 설정을 지운다" && g push -q origin main && g fetch -q origin
assert_eq "$(run check --roadmap "$RM")" "0" "규칙: 설정을 지우면 통과"
assert_eq "$(sed -n 1p "$T/out.txt")" "규칙 검사: 통과 — 규칙 줄 1개 · 공통 규칙 줄 0개" "규칙: 줄 수를 센다"

# ⑥ --ref 의 예산은 그 커밋의 파일 바이트로 잰다
python3 -c 'print("x" * 9000)' >> "$W/$TM/RULES.md"
assert_eq "$(run check --roadmap "$RM")" "1" "규칙: 작업 폴더의 파일이 예산을 넘으면 어긋남"
assert_eq "$(grep -c -F "예산 초과" "$T/out.txt")" "1" "규칙: 작업 폴더는 파일 바이트로 잰다"
assert_eq "$(run check --roadmap "$RM" --ref origin/main)" "0" "규칙: --ref 는 그 커밋의 바이트로 잰다"
g checkout -q HEAD -- "$TM/RULES.md"
# --ref 의 예산은 글자 수가 아니라 바이트 수다 — 한글 열두 자의 제목 줄은 15자 · 39바이트
printf '# 규칙규칙규칙규칙규칙규칙\n' > "$W/$TM/RULES.md"
printf '%s\n' '---' 'rules_budget: 20' '---' > "$W/.devbrew.md"
g add -- .devbrew.md "$TM/RULES.md" && g commit -qm "한글 예산" && g push -q origin main && g fetch -q origin
assert_eq "$(run check --roadmap "$RM" --ref origin/main)" "1" "규칙: --ref 의 예산은 바이트로 잰다(글자 수로는 넘지 않는 한글 줄)"
assert_eq "$(grep -c -F "39바이트" "$T/out.txt")" "1" "규칙: --ref 의 예산 줄에 그 커밋의 바이트 수"
g revert --no-edit HEAD > /dev/null && g push -q origin main && g fetch -q origin

# ④ team 형식이 아닌 로드맵
mkdir -p "$W/${RD}old"
printf '%s\n' '---' 'type: roadmap' '---' > "$W/${RD}old/roadmap.md"
assert_eq "$(run check --roadmap "${RD}old/roadmap.md")" "2" "규칙: layout 이 없는 로드맵은 사용법(2)"
rm -r "$W/${RD}old"

# ⑤ 승격 후보
printf '# RULES\n%s\n%s\n' "$GOOD" '- [문서] 바꾼 건 CHANGELOG에 · 출처: R1 결정 기록 | R4 결정 기록 · 확인: CHANGELOG 를 본다' > "$W/$TM/RULES.md"
assert_eq "$(run candidates --roadmap "$RM")" "0" "후보: 종료 코드 0"
assert_eq "$(cat "$T/out.txt")" '- [문서] 바꾼 건 CHANGELOG에 · 출처: R1 결정 기록 | R4 결정 기록 · 확인: CHANGELOG 를 본다' "후보: 출처가 둘인 줄만 글자 그대로"
printf '# RULES\n%s\n' "$GOOD" > "$W/$TM/RULES.md"
assert_eq "$(run candidates --roadmap "$RM")" "0" "후보: 없어도 0"
assert_eq "$(cat "$T/out.txt")" "승격 후보 없음" "후보: 없으면 승격 후보 없음"
assert_eq "$(run candidates --roadmap "$RM" --ref no-such-ref)" "3" "후보: 없는 ref 는 3"

finish
