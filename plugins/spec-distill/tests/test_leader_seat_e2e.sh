#!/usr/bin/env bash
# 리더 자리의 끝에서 끝 — 상태 브랜치의 규칙 사본 → 시작 묶음의 규칙 · 맞추는 명령의 --rules-at → job sync 의 rules_at →
# 상태 계산의 「묶음 낡음」(R3 AC15) · 남의 고침은 묶음 알림으로 닫는다(AC21).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_leader_seat_e2e.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
T0="$T"
trap 'rm -rf "$T0"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
new_repo "$T0/a" && ok "팀 레포를 세우고 지휘 표지를 쥐었다(${TM})" || { no "팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }

for k in "user.name t" "user.email t@example.invalid" "commit.gpgsign false"; do git -C "$W" config $k; done   # 상태 브랜치 쓰기는 스크립트가 커밋한다
printf '.claude/\n' >> "$W/.git/info/exclude"
cb() { (cd "$W" && python3 "$S/conductor_branch.py" --root "$W" "$@") > "$T/cb.txt" 2>&1; echo $?; }
copy() {  # copy <레포> <세션> <규칙 사본 글> — 상태 브랜치에 규칙 사본 글을 통째로 쓰고 그 커밋을 낸다(걸음 6 · 10 — 10 은 다른 클론의 남의 고침이라 rules-add 가 거절한다)
  python3 - "$S" "$1" "$RM" "$2" "$RULES" "$3" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import conductor_branch as CB
root, roadmap, session, path, text = sys.argv[2:7]
print(CB.write(root, roadmap, session, lambda base: {path: text}, "규칙 사본").commit)
PY
}
stale_notes() {  # stale_notes — 마지막 상태 계산($T/s.json)의 E1 알림 가운데 「묶음 낡음」 으로 시작하는 것들
  js "$T/s.json" "[n for b in r['blocks'] if b['id']=='E1' for n in b['notes'] if n.startswith('묶음 낡음')]"
}
sync_cmd() { grep '^맞추는 명령: ' "$T/b.txt"; }
run_sync() {  # run_sync — 마지막 묶음의 맞추는 명령 줄 그대로 돌린다. rc 를 echo
  local cmd rc=0
  cmd="$(sync_cmd)"
  (cd "$W" && bash -c "${cmd#맞추는 명령: }") > "$T/out.txt" 2>&1 || rc=$?
  echo "$rc"
}
up() { g add -- "$TM/jobs/E1" && g commit -qm "$1" && push_br feature/tm-e1; }

RULES="$TM/RULES.md"; E1="$TM/jobs/E1"
B="$(g rev-parse origin/main)"
BASE_RULES="$(g show "$B:$RULES" 2>/dev/null)"
assert_eq "$([ -n "$BASE_RULES" ] && echo yes)" "yes" "준비: 기본 브랜치에 팀 규칙 파일이 있다"
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "E1 설계 한 줄" && put "$E1/plan-1.md" "E1 계획 한 줄" && g commit -qm "E1 설계 · 계획" && push_br feature/tm-e1
approved "spec 승인" E1 - - 2026-11-20 && approved "계획 검토" E1 1 - 2026-11-21 && push_br feature/tm-e1
assert_eq "$?" "0" "준비: 과제 브랜치에 설계 · 계획 · 관문 줄을 올렸다"

note "# 1 — ensure"
assert_eq "$(cb ensure --roadmap "$RM" --session "$SID")" "0" "1 ensure rc 0 — $(cat "$T/cb.txt")"
STATE="$(g for-each-ref --format='%(refname:short)' refs/heads/conductor/)"
assert_eq "$([ -n "$STATE" ] && echo yes)" "yes" "1 상태 브랜치가 섰다(${STATE})"

note "# 2 — 사본이 없으면 규칙은 기본 브랜치 · 맞추는 명령에 --rules-at 이 없다(H1 (가))"
assert_eq "$(bundle --job E1 --stage implement --plan 1)" "0" "2 묶음 rc 0 — $(cat "$T/b.err")"
assert_eq "$(grep -c "^규칙 (${B}):\$" "$T/b.txt")" "1" "2 규칙 머리는 기준 커밋 하나"
assert_not_contains "$(sync_cmd)" "--rules-at" "2 맞추는 명령에 --rules-at 이 없다"
assert_eq "$(sync_cmd | awk '{print $NF}')" "$(g rev-parse feature/tm-e1)" "2 맞추는 명령의 끝 낱말은 --job-at 의 커밋(양성 대조 — 줄을 읽었다)"

note "# 3 — 상태 브랜치에 규칙 사본"
NEW1="- [사본] 사본에서 더한 첫 줄 · 조건: 역할=worker · 출처: a · 확인: b"
assert_eq "$(cb rules-add --roadmap "$RM" --session "$SID" --line "$NEW1")" "0" "3 rules-add rc 0 — $(cat "$T/cb.txt")"
TIP1="$(g rev-parse "$STATE")"
assert_eq "$(g show "$TIP1:$RULES")" "$(printf '%s\n%s' "$BASE_RULES" "$NEW1")" "3 사본은 기본 브랜치의 규칙 글 뒤에 새 줄"
assert_eq "$(g show "$TIP1:$TM/rules-base.md")" "기본 브랜치 커밋: ${B}" "3 사본이 출발한 기본 브랜치 커밋을 적었다"

note "# 4 — 다시 묶음: 규칙은 사본의 끝 · 맞추는 명령 끝에 --rules-at <상태 끝>"
assert_eq "$(bundle --job E1 --stage implement --plan 1)" "0" "4 묶음 rc 0 — $(cat "$T/b.err")"
assert_eq "$(grep -c "^규칙 (${B} · 팀 규칙은 ${TIP1}):\$" "$T/b.txt")" "1" "4 규칙 머리에 상태 끝"
assert_contains "$(cat "$T/b.txt")" "$NEW1" "4 사본의 새 줄이 실린다"
assert_eq "$(sync_cmd | awk '{print $(NF-1), $NF}')" "--rules-at ${TIP1}" "4 맞추는 명령 끝이 --rules-at <상태 끝>"
assert_not_contains "$(grep '^알림: ' "$T/b.txt")" "남의 고침" "4 남의 고침 알림이 없다"

note "# 5 — 그 줄 그대로 job sync → 결과 파일 머리에 rules_at"
R1="$W/$E1/results/implement-plan-1-1.md"
assert_eq "$(run_sync)" "0" "5 맞추는 명령 rc 0 — $(cat "$T/out.txt")"
assert_eq "$(grep -c "^rules_at: ${TIP1}\$" "$R1") $(grep -A1 '^bundle_at:' "$R1" | tail -n 1)" "1 rules_at: ${TIP1}" "5 머리의 bundle_at 바로 뒤에 rules_at"
up "E1 결과 1"
g checkout -q main
assert_eq "$(status "$T/s.json" >/dev/null; stale_notes)" "[]" "5 규칙 사본 그대로면 묶음 낡음이 없다"

note "# 6 — 사본에 줄을 더하면 묶음 낡음(양성 대조)"
NEW2="- [사본] 사본에서 더한 둘째 줄 · 조건: 역할=worker · 출처: a · 확인: b"
TIP2="$(copy "$W" "$SID" "$(printf '%s\n%s\n%s\n' "$BASE_RULES" "$NEW1" "$NEW2")")"
assert_eq "$([ -n "$TIP2" ] && [ "$TIP2" != "$TIP1" ] && echo moved)" "moved" "6 상태 끝이 옮겨 갔다"
status "$T/s.json" >/dev/null
assert_eq "$(stale_notes)" "['묶음 낡음: implement-plan-1-1.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${RULES}']" "6 규칙 고침 뒤의 결과 파일은 묶음 낡음"

note "# 7 — 고친 뒤에 받은 묶음의 결과에는 묶음 낡음이 없다(AC15 끝 문장)"
g checkout -q feature/tm-e1
assert_eq "$(bundle --job E1 --stage implement --plan 1)" "0" "7 이어 쓰는 묶음 rc 0 — $(cat "$T/b.err")"
assert_eq "$(grep '^쓸 것: ' "$T/b.txt")" "쓸 것: ${E1}/results/implement-plan-1-1.md" "7 끝 줄이 없는 시도 1 을 잇는다"
assert_eq "$(sync_cmd | awk '{print $(NF-1), $NF}')" "--rules-at ${TIP2}" "7 맞추는 명령의 --rules-at 이 새 끝"
assert_eq "$(run_sync)" "0" "7 이어 쓰는 맞추는 명령 rc 0 — $(cat "$T/out.txt")"
assert_eq "$(grep -c '^rules_at:' "$R1") $(grep -A1 '^bundle_at:' "$R1" | tail -n 1)" "1 rules_at: ${TIP2}" "7 이어 쓰는 파일의 rules_at 이 그 자리에서 새 끝"
up "E1 결과 1 이어 씀"
g checkout -q main
assert_eq "$(status "$T/s.json" >/dev/null; stale_notes)" "[]" "7 이어 쓴 묶음의 결과에는 묶음 낡음이 없다"
g checkout -q feature/tm-e1
assert_eq "$(sync E1 implement-plan-1-1.md --end "$(g rev-parse HEAD)")" "0" "7 시도 1 에 끝 줄"
up "E1 결과 1 끝"
assert_eq "$(bundle --job E1 --stage implement --plan 1)" "0" "7 새 시도 묶음 rc 0 — $(cat "$T/b.err")"
assert_eq "$(grep '^쓸 것: ' "$T/b.txt")" "쓸 것: ${E1}/results/implement-plan-1-2.md" "7 끝난 시도 뒤의 묶음은 시도 2"
assert_eq "$(sync_cmd | awk '{print $(NF-1), $NF}')" "--rules-at ${TIP2}" "7 새 시도의 --rules-at 도 새 끝"
assert_eq "$(run_sync)" "0" "7 새 결과 파일을 만든다 — $(cat "$T/out.txt")"
assert_eq "$(grep -c "^rules_at: ${TIP2}\$" "$W/$E1/results/implement-plan-1-2.md")" "1" "7 새 결과 파일 머리에 새 끝"
up "E1 결과 2"
g checkout -q main
status "$T/s.json" >/dev/null
assert_eq "$(stale_notes)" "[]" "7 새 시도의 결과에는 묶음 낡음이 없다"

note "# 8 — rules_at 없는 결과 파일(끝 줄 없음)은 bundle_at 에서 견준다"
g checkout -q feature/tm-e1
assert_eq "$(sync E1 plan-plan-1-1.md --role worker --bundle-at "$B" --job-at "$(g rev-parse HEAD)")" "0" "8 인자 넷의 맞추는 명령으로 만든 결과 파일"
assert_eq "$(grep -c '^rules_at:' "$W/$E1/results/plan-plan-1-1.md"):$(grep -c '^끝 — ' "$W/$E1/results/plan-plan-1-1.md")" "0:0" "8 rules_at 도 끝 줄도 없다(양성 대조)"
up "E1 계획 결과 1"
g checkout -q main
status "$T/s.json" >/dev/null
assert_eq "$(stale_notes)" "['묶음 낡음: plan-plan-1-1.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${RULES}']" "8 사본이 있는 동안 bundle_at 의 규칙과 견줘 묶음 낡음"

note "# 9 — 이 클론에 없는 rules_at 은 재지 못했다"
GHOST="0123456789abcdef0123456789abcdef01234567"
g checkout -q feature/tm-e1
assert_eq "$(sync E1 design-1.md --role designer --bundle-at "$B" --job-at "$(g rev-parse HEAD)" --rules-at "$GHOST")" "0" "9 다른 클론이 쓴 rules_at 의 결과 파일(끝 줄 없음)"
up "E1 설계 결과 1"
g checkout -q main
status "$T/s.json" >/dev/null
assert_contains "$(stale_notes)" "묶음 낡음을 재지 못했다: design-1.md — 규칙을 읽은 커밋 ${GHOST:0:8} 가 이 레포에 없다" "9 재지 못했다고 알린다"
assert_not_contains "$(stale_notes)" "묶음 낡음: design-1.md" "9 「바뀜」 을 지어내지 않는다"

note "# 10 — 남의 고침이 있으면 묶음은 알림을 싣고 규칙은 기본 브랜치 · --rules-at 이 없다"
O2="$T/other"
git clone -q "$T/origin.git" "$O2" 2>/dev/null
for k in "user.name other" "user.email other@example.invalid" "commit.gpgsign false"; do git -C "$O2" config $k; done
printf '.claude/\n' >> "$O2/.git/info/exclude"
git -C "$O2" update-ref "refs/heads/$STATE" "refs/remotes/origin/$STATE"
assert_eq "$( (cd "$O2" && python3 "$CL" claim --roadmap "$RM" --session "$SID2") >/dev/null 2>&1; echo $?)" "0" "10 다른 클론이 자기 표지를 쥔다"
NEW3="- [남] 다른 클론이 더한 줄 · 조건: 역할=worker · 출처: a · 확인: b"
FOREIGN_TIP="$(copy "$O2" "$SID2" "$(printf '%s\n%s\n%s\n%s\n' "$BASE_RULES" "$NEW1" "$NEW2" "$NEW3")")"
g fetch -q origin
assert_eq "$(g rev-parse "refs/remotes/origin/$STATE")" "$FOREIGN_TIP" "10 남의 고침을 받아 왔다(양성 대조)"
g checkout -q feature/tm-e1
assert_eq "$(bundle --job E1 --stage implement --plan 1)" "0" "10 묶음 rc 0 — $(cat "$T/b.err")"
assert_contains "$(grep '^알림: ' "$T/b.txt")" "알림: 확인되지 않은 남의 고침 1 — 규칙은 기본 브랜치의 글을 읽는다" "10 남의 고침 알림이 묶음에 실린다"
assert_eq "$(grep -c "^규칙 (${B}):\$" "$T/b.txt")" "1" "10 규칙 머리는 기준 커밋 하나"
assert_not_contains "$(cat "$T/b.txt")" "$NEW3" "10 남이 더한 줄을 싣지 않는다"
assert_not_contains "$(cat "$T/b.txt")" "$NEW1" "10 사본의 줄도 싣지 않는다 — 기본 브랜치의 글"
assert_not_contains "$(sync_cmd)" "--rules-at" "10 맞추는 명령에 --rules-at 이 없다"
g checkout -q main

note "# 11 — 남의 고침 동안 기본 브랜치 규칙으로 이어 쓰면 옛 rules_at 을 지우고 bundle_at 에서 견준다"
R2="$W/$E1/results/implement-plan-1-2.md"
status "$T/s.json" >/dev/null
assert_contains "$(stale_notes)" "묶음 낡음: implement-plan-1-2.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${RULES}" "11 이어 쓰기 전에는 옛 rules_at(TIP2)과 기본 브랜치를 견줘 낡음(양성 대조)"
g checkout -q feature/tm-e1
assert_eq "$(bundle --job E1 --stage implement --plan 1)" "0" "11 이어 쓰는 묶음 rc 0 — $(cat "$T/b.err")"
assert_eq "$(grep '^쓸 것: ' "$T/b.txt")" "쓸 것: ${E1}/results/implement-plan-1-2.md" "11 끝 줄이 없는 시도 2 를 잇는다"
assert_not_contains "$(sync_cmd)" "--rules-at" "11 맞추는 명령에 --rules-at 이 없다"
assert_eq "$(run_sync)" "0" "11 이어 쓰는 맞추는 명령 rc 0 — $(cat "$T/out.txt")"
assert_eq "$(grep -c '^rules_at:' "$R2")" "0" "11 옛 rules_at 줄이 지워졌다"
up "E1 결과 2 이어 씀"
g checkout -q main
status "$T/s.json" >/dev/null
assert_not_contains "$(stale_notes)" "implement-plan-1-2.md" "11 이어 쓴 결과에는 묶음 낡음이 없다"

finish
