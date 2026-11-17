#!/usr/bin/env bash
# team_status.Reader.stale — 도는 일꾼의 묶음이 낡았는지 현황에 알린다(AC23 · AC31 · U9 · I4). 알림은 종료 코드를 바꾸지 않는다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_team_stale.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
team_repo && ok "팀 레포를 세웠다(${TM})" || { no "팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }

notes() { js "$T/s.json" "[n for b in r['blocks'] if b['id']=='$1' for n in b['notes'] if n.startswith('묶음 낡음')]"; }
count() { js "$T/s.json" "sum(1 for b in r['blocks'] for n in b['notes'] if n.startswith('묶음 낡음'))"; }
bump() { printf '%s\n' "$2" >> "$W/$1"; g add -- "$1"; g commit -qm "고침 $1"; g push -q origin main; g fetch -q origin; BUMPED="$(g rev-parse HEAD)"; }
unbump() { g revert --no-edit "${1:-HEAD}" > /dev/null && g push -q origin main && g fetch -q origin; }
RULES="$TM/RULES.md"; COMMON="${RD}HANDBOOK.md"; WORKER="${RD}worker/CLAUDE.md"; DESIGNER="${RD}designer/CLAUDE.md"

# 준비: 공통 문서 · 팀 규칙 파일을 main 에 올리고 B 를 읽는다
printf '# RULES\n- [문서] 처음 줄 · 출처: a · 확인: b\n' > "$W/$RULES"
g add -- "${RD}leader" "${RD}designer" "${RD}writer" "${RD}worker" "$COMMON" "$RULES" && g commit -qm "공통 문서 · 규칙" && g push -q origin main && g fetch -q origin
B="$(g rev-parse origin/main)"
E1="$TM/jobs/E1"
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "E1 설계 한 줄"
g commit -qm "E1 설계"
assert_eq "$(sync E1 implement-plan-1-1.md --role worker --bundle-at "$B" --job-at "$(g rev-parse HEAD)")" "0" "준비: 끝 줄 없는 결과 파일"
g add -- "$E1/results" && g commit -qm "E1 결과" && g push -q origin feature/tm-e1 && g checkout -q main

RC0="$(status "$T/s.json")"
UNK0="$(js "$T/s.json" "r['unknown_reasons']")"
assert_eq "$(notes E1)" "[]" "낡음: 바뀐 것이 없으면 나오지 않는다"
bump "$RULES" '- [문서] 바꾼 건 CHANGELOG에 · 출처: a · 확인: b'
assert_eq "$(status "$T/s.json")" "$RC0" "AC23: 종료 코드는 그대로다"
assert_eq "$(js "$T/s.json" "r['unknown_reasons']")" "$UNK0" "AC23: 검사 불가 사유도 그대로다(바탕 종료 코드가 이미 3 이라 종료 코드만으로는 못 가른다)"
assert_eq "$(notes E1)" "['묶음 낡음: implement-plan-1-1.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${RULES}']" "AC23: 팀 규칙이 바뀌면 나온다"
assert_contains "$(cd "$W" && python3 "$S/control_plane.py" show "$RM")" "정보: 묶음 낡음: implement-plan-1-1.md" "AC23: 현황의 그 과제 줄 아래에 보인다"
unbump; status "$T/s.json" > /dev/null
assert_eq "$(notes E1)" "[]" "I4: 글을 되돌리면 알림이 사라진다"

# ② 공통 규칙 파일
bump "$COMMON" '- 공통 한 줄'; status "$T/s.json" > /dev/null
assert_eq "$(notes E1)" "['묶음 낡음: implement-plan-1-1.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${COMMON}']" "공통 규칙 파일이 바뀌면 그 경로가 든다"
unbump
# ③ 역할 문서 — 결과 파일의 role 은 worker 다
bump "$DESIGNER" '- 설계자 한 줄'; status "$T/s.json" > /dev/null
assert_eq "$(notes E1)" "[]" "U9: 다른 역할의 문서만 바뀌면 나오지 않는다"
unbump
bump "$WORKER" '- 일꾼 한 줄'; W1="$BUMPED"; status "$T/s.json" > /dev/null
assert_eq "$(notes E1)" "['묶음 낡음: implement-plan-1-1.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${WORKER}']" "그 역할의 문서가 바뀌면 그 경로가 든다"
# ④ 둘이 함께
bump "$RULES" '- 둘이 함께'; R1="$BUMPED"; status "$T/s.json" > /dev/null
assert_eq "$(notes E1)" "['묶음 낡음: implement-plan-1-1.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${RULES} · ${WORKER}']" "둘이 함께 바뀌면 한 줄에 ' · ' 로 이어진다"
unbump "$R1"; unbump "$W1"
# ⑤ 끝 줄을 달면 도는 일꾼이 아니다
bump "$RULES" '- 다시 낡게'
g checkout -q feature/tm-e1
assert_eq "$(sync E1 implement-plan-1-1.md --end "$(g rev-parse HEAD)")" "0" "준비: 끝 줄"
g add -- "$E1/results" && g commit -qm "E1 끝" && g push -q origin feature/tm-e1 && g checkout -q main
status "$T/s.json" > /dev/null
assert_eq "$(notes E1)" "[]" "U9: 끝 줄이 있으면 알리지 않는다(끝난 일꾼은 도는 일꾼이 아니다)"
unbump
# ⑥ bundle_at 이 이 레포에 없는 커밋 — 재지 못했다
GHOST="$(printf '1%.0s' $(seq 40))"
g checkout -q feature/tm-e1
assert_eq "$(sync E1 implement-plan-1-2.md --role worker --bundle-at "$GHOST" --job-at "$(g rev-parse HEAD)")" "0" "준비: 없는 커밋의 bundle_at"
g add -- "$E1/results" && g commit -qm "E1 결과 2" && g push -q origin feature/tm-e1 && g checkout -q main
assert_eq "$(status "$T/s.json")" "$RC0" "없는 커밋: 종료 코드는 그대로다"
assert_eq "$(js "$T/s.json" "r['unknown_reasons']")" "$UNK0" "없는 커밋: 검사 불가 사유도 그대로다"
assert_eq "$(notes E1)" "['묶음 낡음을 재지 못했다: implement-plan-1-2.md — 묶은 커밋 ${GHOST:0:8} 가 이 레포에 없다']" "없는 커밋: 재지 못했다 한 줄뿐이다"
assert_eq "$(js "$T/s.json" "[n for b in r['blocks'] if b['id']=='E1' for n in b['notes'] if n.startswith('묶음 낡음: ')]")" "[]" "없는 커밋: 「바뀜」 을 지어내지 않는다"
# ⑦ 설계 단계의 결과 파일
E3="$TM/jobs/E3"
g checkout -q -b feature/tm-e3 main
put "$E3/design.md" "E3 설계 한 줄"
g commit -qm "E3 설계"
assert_eq "$(sync E3 design-1.md --role designer --bundle-at "$B" --job-at "$(g rev-parse HEAD)")" "0" "준비: 설계 결과 파일"
g add -- "$E3/results" && g commit -qm "E3 결과" && g push -q origin feature/tm-e3 && g checkout -q main
status "$T/s.json" > /dev/null
assert_eq "$(notes E3)" "[]" "설계: 바뀐 것이 없으면 나오지 않는다"
bump "$DESIGNER" '- 설계자 한 줄 둘'; D1="$BUMPED"; status "$T/s.json" > /dev/null
assert_eq "$(notes E3)" "['묶음 낡음: design-1.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${DESIGNER}']" "U9: 설계 단계의 결과 파일도 알린다"
# ⑧ 검수 기준 파일은 보지 않는다
before="$(count)"
bump REVIEW.md '- 검수 기준'; V1="$BUMPED"; status "$T/s.json" > /dev/null
assert_eq "$(count)" "$before" "U9: 검수 기준 파일이 바뀌어도 알림이 늘지 않는다"
assert_not_contains "$(js "$T/s.json" "[n for b in r['blocks'] for n in b['notes']]")" "REVIEW.md" "U9: 알림에 검수 기준 파일 경로가 없다"
unbump "$V1"; unbump "$D1"
# C6: 머리 bundle_at 꼴이 깨진 결과 파일 — 죽지 않고 지어내지도 않는다
g checkout -q feature/tm-e3
assert_eq "$(sync E3 plan-plan-1-1.md --role designer --bundle-at "$B" --job-at "$(g rev-parse HEAD)")" "0" "준비: 계획 단계 결과 파일"
sed -i.bak "s/^bundle_at: .*/bundle_at: zz/" "$W/$E3/results/plan-plan-1-1.md" && rm -f "$W/$E3/results/plan-plan-1-1.md.bak"
g add -- "$E3/results" && g commit -qm "E3 깨진 머리" && g push -q origin feature/tm-e3 && g checkout -q main
assert_eq "$(status "$T/s.json")" "$RC0" "C6: 머리 꼴이 깨진 결과 파일 — 죽지 않는다"
assert_eq "$(js "$T/s.json" "[n for b in r['blocks'] if b['id']=='E3' for n in b['notes'] if n.startswith('묶음 낡음: plan-plan')]")" "[]" "C6: 읽지 못한 결과 파일에 「바뀜」 을 지어내지 않는다"
assert_eq "$(js "$T/s.json" "[n.split(' — ')[0] for b in r['blocks'] if b['id']=='E3' for n in b['notes'] if n.startswith('묶음 낡음을 재지 못했다')]")" "['묶음 낡음을 재지 못했다: plan-plan-1-1.md']" "C6: 깨진 결과 파일은 재지 못했다로 알린다"
assert_contains "$(js "$T/s.json" "[n for b in r['blocks'] if b['id']=='E3' for n in b['notes'] if n.startswith('묶음 낡음을 재지 못했다: plan-plan-1-1.md')]")" "머리 bundle_at 가 커밋 번호 꼴이 아니다: 'zz'" "C6: 재지 못한 사유는 그 머리 값의 문제다"
# C6: 머리에 bundle_at 줄이 아예 없는 결과 파일도 재지 못했다로 알린다
g checkout -q feature/tm-e3
assert_eq "$(sync E3 plan-plan-2-1.md --role designer --bundle-at "$B" --job-at "$(g rev-parse HEAD)")" "0" "준비: 계획 2 결과 파일"
sed -i.bak "/^bundle_at: /d" "$W/$E3/results/plan-plan-2-1.md" && rm -f "$W/$E3/results/plan-plan-2-1.md.bak"
g add -- "$E3/results" && g commit -qm "E3 bundle_at 없는 머리" && g push -q origin feature/tm-e3 && g checkout -q main
assert_eq "$(status "$T/s.json")" "$RC0" "C6: bundle_at 줄이 없는 결과 파일 — 죽지 않는다"
assert_contains "$(js "$T/s.json" "[n for b in r['blocks'] if b['id']=='E3' for n in b['notes'] if n.startswith('묶음 낡음을 재지 못했다: plan-plan-2-1.md')]")" "머리 bundle_at 가 커밋 번호 꼴이 아니다: None" "C6: bundle_at 줄이 없으면 재지 못했다로 알린다"
# ⑨ 로드맵 밖 과제
g checkout -q -b chore/tm-fix main
printf '로드맵에 없는 일 하나\n' > "$T/said.txt"
(cd "$W" && python3 "$RW" job new --roadmap "$RM" --name fix-typo --branch chore/tm-fix --paths docs/a.md --goal "오타 고치기" < "$T/said.txt") > "$T/out.txt" 2>&1 || cat "$T/out.txt"
g add -- "$TM/jobs/fix-typo" && g commit -qm "과제 폴더 fix-typo"
assert_eq "$(sync fix-typo implement-1.md --role worker --bundle-at "$B" --job-at "$(g rev-parse HEAD)")" "0" "준비: 로드맵 밖 과제의 결과 파일"
g add -- "$TM/jobs/fix-typo/results" && g commit -qm "fix-typo 결과" && g push -q origin chore/tm-fix && g checkout -q main
bump "$WORKER" '- 일꾼 한 줄 셋'; status "$T/s.json" > /dev/null
assert_contains "$(js "$T/s.json" "[n for j in r['jobs'] for n in j['notes'] if n.startswith('묶음 낡음')]")" "묶음 낡음: implement-1.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${WORKER}" "로드맵 밖 과제도 알린다"
unbump

# ⑩ AC31 — 팀 규칙 파일만 leader_ref 의 커밋에서 읽는다(이름 댄 결과 파일 하나로 좁힌다)
B2="$(g rev-parse origin/main)"
E2="$TM/jobs/E2"
g checkout -q -b feature/tm-e2 main
put "$E2/survey.md" "E2 조사 한 줄"
g commit -qm "E2 조사"
assert_eq "$(sync E2 implement-1.md --role worker --bundle-at "$B2" --job-at "$(g rev-parse HEAD)")" "0" "준비: E2 결과 파일"
g add -- "$E2/results" && g commit -qm "E2 결과" && g push -q origin feature/tm-e2
g checkout -q -b leader-state "$B2"
printf 'LSMARK\n' >> "$W/$RULES"; printf 'LSMARK\n' >> "$W/$COMMON"
g add -- "$RULES" "$COMMON" && g commit -qm "leader-state" && g checkout -q main
patched() {
  (cd "$W" && python3 - "$S" "$RM" "$1" > "$T/p.json" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import team_layout
if sys.argv[3] == "swap":
    team_layout.leader_ref = lambda ref: "refs/heads/leader-state"
import roadmap_status
sys.exit(roadmap_status.main([sys.argv[2], "--json"]))
PY
  ) 2> /dev/null
}
e2() { js "$T/p.json" "[n for b in r['blocks'] if b['id']=='E2' for n in b['notes'] if n.startswith('묶음 낡음')]"; }
patched same
assert_eq "$(e2)" "[]" "AC31: 바꾸지 않은 보고에는 그 결과 파일의 알림이 없다"
patched swap
assert_eq "$(e2)" "['묶음 낡음: implement-1.md — 묶은 커밋 ${B2:0:8} 뒤에 바뀜: ${RULES}']" "AC31: 바꾼 보고에는 팀 규칙 파일 경로만 든다(공통 규칙 파일은 기본 브랜치에서 읽는다)"
# I2 — roadmap_status(그리고 team_status)를 먼저 import 한 뒤에 바꿔 끼워도 그 값이 닿는다(부를 때마다 모듈에서 찾는다)
(cd "$W" && python3 - "$S" "$RM" > "$T/p.json" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import roadmap_status
import team_layout
team_layout.leader_ref = lambda ref: "refs/heads/leader-state"
sys.exit(roadmap_status.main([sys.argv[2], "--json"]))
PY
) 2> /dev/null
assert_eq "$(e2)" "['묶음 낡음: implement-1.md — 묶은 커밋 ${B2:0:8} 뒤에 바뀜: ${RULES}']" "I2: import 뒤에 바꿔 끼워도 팀 규칙 파일 경로가 든다"

finish
