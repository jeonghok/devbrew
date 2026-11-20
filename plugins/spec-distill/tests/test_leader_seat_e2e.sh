#!/usr/bin/env bash
# 리더 자리의 끝에서 끝 — 상태 브랜치의 규칙 사본 → 시작 묶음의 규칙 · 맞추는 명령의 --rules-at → job sync 의 rules_at →
# 상태 계산의 「묶음 낡음」(R3 AC15) · 남의 고침은 묶음 알림으로 닫는다(AC21) · sync 가 같아진 사본을 지우고 갈라짐을 알린다(AC17).
# 대기 줄 — 상태 브랜치의 pending.md 에 쌓고 flush 가 확인된 줄만 옮긴다 · 사람 줄은 건너뛰어 센다(AC16 · AC21 · M15 · M16).
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

note "# 12 — 새 레포: sync 가 같아진 사본을 지운다 · 올릴 것은 남긴다 · 갈라짐을 알린다 · 남의 고침이면 지우지 않는다(AC17)"
new_repo "$T0/b" && ok "둘째 팀 레포를 세우고 지휘 표지를 쥐었다" || { no "둘째 팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }
for k in "user.name t" "user.email t@example.invalid" "commit.gpgsign false"; do git -C "$W" config $k; done
printf '.claude/\n' >> "$W/.git/info/exclude"
csync() { (cd "$W" && python3 "$S/conductor_status.py" --root "$W" sync --roadmap "$RM" --session "$SID") > "$T/cs.txt" 2>&1; echo $?; }
stip() { g rev-parse "refs/heads/$STATE"; }
on_tip() { if g cat-file -e "$(stip):$1" 2>/dev/null; then echo 있다; else echo 없다; fi; }   # on_tip <경로> — 상태 브랜치 끝에 그 파일이 있는가
gap() { g show "$(stip):$TM/STATUS.md" | grep -A1 '^## 안 올린 규칙 고침$' | tail -n 1; }
merge_rules() {  # merge_rules — 상태 브랜치의 사본 글을 그대로 기본 브랜치에 커밋해 올린다(규칙 PR 머지 흉내)
  g show "$(stip):$RULES" > "$W/$RULES" && g add -- "$RULES" && g commit -qm "규칙 고침 머지 흉내" && push_main
}
assert_eq "$(cb ensure --roadmap "$RM" --session "$SID")" "0" "12 ensure rc 0 — $(cat "$T/cb.txt")"
STATE="$(g for-each-ref --format='%(refname:short)' refs/heads/conductor/)"
assert_eq "$(csync)" "0" "12 첫 sync rc 0 — $(cat "$T/cs.txt")"
assert_eq "$(gap)" "- 0줄" "12 사본이 없으면 0줄"

note "# 13 — 올릴 것이면 남긴다"
assert_eq "$(cb rules-add --roadmap "$RM" --session "$SID" --line "$NEW1")" "0" "13 rules-add rc 0 — $(cat "$T/cb.txt")"
assert_eq "$(csync)" "0" "13 sync rc 0 — $(cat "$T/cs.txt")"
assert_not_contains "$(cat "$T/cs.txt")" "다른 곳에서 이 브랜치에 썼다" "13 남이 쓰지 않았으면 알리지 않는다(아래 17 의 짝)"
assert_eq "$(on_tip "$RULES") $(on_tip "$TM/rules-base.md")" "있다 있다" "13 올릴 사본은 남는다"
assert_eq "$(gap)" "- 1줄" "13 STATUS 가 1줄"

note "# 14 — 같아지면 지운다"
merge_rules && ok "14 사본 글을 기본 브랜치에 머지했다(흉내)" || no "14 머지 흉내 실패"
assert_eq "$(csync)" "0" "14 sync rc 0 — $(cat "$T/cs.txt")"
assert_eq "$(on_tip "$RULES") $(on_tip "$TM/rules-base.md")" "없다 없다" "14 같아진 사본과 rules-base.md 를 지웠다"
assert_eq "$(gap)" "- 0줄" "14 STATUS 가 0줄"

note "# 15 — STATUS 가 같아도 지운다(S5)"
assert_eq "$(csync)" "0" "15 한 번 더 sync rc 0 — $(cat "$T/cs.txt")"
assert_contains "$(cat "$T/cs.txt")" "달라진 것이 없다" "15 같은 STATUS 면 조기 반환한다(양성 대조)"
assert_eq "$(cb rules-add --roadmap "$RM" --session "$SID" --line "$NEW2")" "0" "15 rules-add rc 0 — $(cat "$T/cb.txt")"
merge_rules && ok "15 사본 글을 기본 브랜치에 머지했다(흉내)" || no "15 머지 흉내 실패"
assert_eq "$(gap) $(on_tip "$RULES")" "- 0줄 있다" "15 STATUS 는 이미 0줄이고 사본은 있다(양성 대조)"
assert_eq "$(csync)" "0" "15 sync rc 0 — $(cat "$T/cs.txt")"
assert_eq "$(on_tip "$RULES") $(on_tip "$TM/rules-base.md")" "없다 없다" "15 STATUS 가 같아도 사본을 지웠다"
assert_not_contains "$(cat "$T/cs.txt")" "달라진 것이 없다" "15 조기 반환을 타지 않았다"

note "# 16 — 갈라지면 알린다"
NEW3="- [사본] 둘째 레포에서 더한 줄 · 조건: 역할=worker · 출처: a · 확인: b"
NEW4="- [다른] 다른 손이 기본 브랜치에 더한 줄 · 조건: 역할=worker · 출처: a · 확인: b"
assert_eq "$(cb rules-add --roadmap "$RM" --session "$SID" --line "$NEW3")" "0" "16 rules-add rc 0 — $(cat "$T/cb.txt")"
printf '%s\n' "$NEW4" >> "$W/$RULES" && g add -- "$RULES" && g commit -qm "다른 손의 규칙 고침" && push_main
assert_eq "$(csync)" "0" "16 sync rc 0 — $(cat "$T/cs.txt")"
assert_eq "$(grep -c '^\[spec-distill\] 규칙 사본이 기본 브랜치와 갈라졌다' "$T/cs.txt")" "1" "16 갈라짐을 알리는 줄 — $(cat "$T/cs.txt")"
assert_eq "$(on_tip "$RULES")" "있다" "16 갈라진 사본은 남는다"
assert_eq "$(cb rules-branch --roadmap "$RM" --session "$SID" --branch chore/tm-rules)" "1" "16 rules-branch 는 만들지 않는다(1)"
assert_contains "$(cat "$T/cb.txt")" "│ -${NEW4}" "16 rules-branch 가 차이를 낸다"
assert_eq "$(g for-each-ref --format=x refs/heads/chore/tm-rules)" "" "16 브랜치가 없다"

note "# 17 — 남의 고침이면 지우지 않는다(S6)"
O3="$T/other"
git clone -q "$T/origin.git" "$O3" 2>/dev/null
for k in "user.name other" "user.email other@example.invalid" "commit.gpgsign false"; do git -C "$O3" config $k; done
printf '.claude/\n' >> "$O3/.git/info/exclude"
git -C "$O3" update-ref "refs/heads/$STATE" "refs/remotes/origin/$STATE"
assert_eq "$( (cd "$O3" && python3 "$CL" claim --roadmap "$RM" --session "$SID2") >/dev/null 2>&1; echo $?)" "0" "17 다른 클론이 자기 표지를 쥔다"
MAIN_RULES="$(g show "origin/main:$RULES")"
FOREIGN_TIP="$(copy "$O3" "$SID2" "${MAIN_RULES}"$'\n')"   # 끝 줄바꿈은 $( ) 밖에서 붙인다 — 안에서 붙이면 깎인다
g fetch -q origin
assert_eq "$(g rev-parse "refs/remotes/origin/$STATE")" "$FOREIGN_TIP" "17 남이 사본을 기본 브랜치 글과 같게 고친 끝을 받아 왔다(양성 대조)"
assert_eq "$(csync)" "0" "17 sync rc 0 — $(cat "$T/cs.txt")"
assert_contains "$(cat "$T/cs.txt")" "[spec-distill] 다른 곳에서 이 브랜치에 썼다 — ${FOREIGN_TIP:0:8} · " "17 받아 온 남의 끝 위로 앞당겼으면 알린다(AC3)"
assert_eq "$(g merge-base --is-ancestor "$FOREIGN_TIP" "$(stip)" && echo 위)" "위" "17 sync 가 남의 끝 위에 썼다(양성 대조)"
assert_eq "$(g rev-parse "$(stip):$RULES")" "$(g rev-parse "origin/main:$RULES")" "17 사본은 기본 브랜치 글과 바이트까지 같다(양성 대조 — 남의 고침만이 지우지 않는 까닭)"
assert_eq "$(on_tip "$RULES") $(on_tip "$TM/rules-base.md")" "있다 있다" "17 확인되지 않은 남의 고침이면 지우지 않는다"
assert_eq "$(grep -c '^\[spec-distill\] 확인되지 않은 남의 고침 1 — conductor_branch.py confirm' "$T/cs.txt")" "1" "17 sync 가 확인되지 않은 남의 고침을 알린다(AC21) — $(cat "$T/cs.txt")"

note "# 18 — confirm 으로 확인하면 알림이 사라지고 그 끝의 내용을 쓴다(AC21)"
assert_eq "$(cb confirm --roadmap "$RM" --session "$SID")" "1" "18 확인 표시 없는 confirm 은 보고하고 1 — $(cat "$T/cb.txt")"
assert_contains "$(cat "$T/cb.txt")" "${FOREIGN_TIP:0:8} · " "18 보고에 남의 커밋이 있다"
CTIP="$(sed -n '$s/^확인할 끝: //p' "$T/cb.txt")"
assert_eq "$CTIP" "$(stip)" "18 마지막 줄이 확인할 끝(40자)"
assert_eq "$(cb confirm --roadmap "$RM" --session "$SID" --confirmed "${CTIP:0:8}")" "2" "18 앞 8자는 받지 않는다(I4)"
assert_eq "$(cb confirm --roadmap "$RM" --session "$SID" --confirmed "$CTIP")" "0" "18 그 끝으로 확인 rc 0 — $(cat "$T/cb.txt")"
assert_eq "$(csync)" "0" "18 sync rc 0 — $(cat "$T/cs.txt")"
assert_not_contains "$(cat "$T/cs.txt")" "확인되지 않은 남의 고침" "18 확인한 뒤에는 알리지 않는다"
assert_eq "$(on_tip "$RULES") $(on_tip "$TM/rules-base.md")" "없다 없다" "18 확인한 뒤에는 같아진 사본을 지운다"

note "# 19 — 대기 줄: 상태 브랜치 자리의 같은 줄 둘 → flush 가 결정 기록에 하나 · pending.md 에서 둘 다 뺀다(AC16 · 다중집합)"
new_repo "$T0/c" && ok "셋째 팀 레포를 세우고 지휘 표지를 쥐었다" || { no "셋째 팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }
for k in "user.name t" "user.email t@example.invalid" "commit.gpgsign false"; do git -C "$W" config $k; done
printf '.claude/\n' >> "$W/.git/info/exclude"
PEND="$TM/pending.md"; INTENT="$TM/jobs/E1/INTENT.md"
pend() { led add --roadmap "$RM" --session "$SID" --section "쌓인 기록" --cells "E1 · 지휘 기록 · $1"; }   # pend <글> — rc 를 echo, 출력은 $T/led.txt
flush() { led flush --roadmap "$RM" --session "$SID" --epic E1 --spec "$W/$TM/jobs/E1/design.md"; }   # 과제 폴더 안 경로 — 지금 레포의 것
seen_pend() {  # seen_pend — 읽을 끝(로컬과 원격 추적 가운데 앞선 쪽)의 pending.md
  local tip
  tip="$(python3 - "$S" "$W" "$(basename "$TM")" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import conductor_branch as CB
print(CB.seen_tip(sys.argv[2], sys.argv[3])[0])
PY
)"
  g show "${tip}:${PEND}" 2>/dev/null
}
decided() { grep -c -F -x -- "- $1" "$W/$INTENT"; }   # decided <글> — INTENT.md 에 그 줄이 몇 번
assert_eq "$([ -f "$W/$INTENT" ] && echo yes)" "yes" "19 준비: 과제 E1 의 INTENT.md 가 있다"
assert_eq "$(cb ensure --roadmap "$RM" --session "$SID")" "0" "19 ensure rc 0 — $(cat "$T/cb.txt")"
assert_eq "$(pend "결정 · 2026-11-20 · 같은 결정")" "0" "19 첫 add rc 0 — $(cat "$T/led.txt")"
assert_eq "$(pend "결정 · 2026-11-20 · 같은 결정")" "0" "19 같은 줄 둘째 add rc 0 — $(cat "$T/led.txt")"
assert_eq "$(seen_pend | grep -c -F -x -- "- E1 · 지휘 기록 · 결정 · 2026-11-20 · 같은 결정")" "2" "19 pending.md 에 같은 줄 둘(양성 대조)"
assert_eq "$(flush)" "0" "19 flush rc 0 — $(cat "$T/led.txt")"
assert_eq "$(decided "결정 · 2026-11-20 · 같은 결정")" "1" "19 결정 기록에 그 줄이 하나"
assert_eq "$(seen_pend | grep -c '^- E1 · 지휘 기록 · ')" "0" "19 pending.md 의 E1 지휘 기록 줄이 모두 빠졌다"

note "# 20 — 브랜치 전 기계 상태의 사람 줄 · 보통 줄 + 남이 심은 사람 줄 · 보통 줄 → flush 는 보통 줄(기계 상태)만 옮긴다(M15 · M16 · I6)"
new_repo "$T0/d" && ok "넷째 팀 레포를 세우고 지휘 표지를 쥐었다" || { no "넷째 팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }
for k in "user.name t" "user.email t@example.invalid" "commit.gpgsign false"; do git -C "$W" config $k; done
printf '.claude/\n' >> "$W/.git/info/exclude"
assert_eq "$(pend "spec 승인 · 2026-11-20 · 기계 사람 줄")" "0" "20 브랜치 전 사람 줄은 기계 상태로 rc 0 — $(cat "$T/led.txt")"
assert_contains "$(cat "$T/led.txt")" "[spec-distill] 상태 브랜치가 없어 기계 상태에 쌓았다 — ensure 뒤의 줄부터 상태 브랜치에 쌓는다" "20 브랜치가 없다고 알린다"
assert_eq "$(pend "결정 · 2026-11-20 · 기계 보통 줄")" "0" "20 브랜치 전 보통 줄 rc 0 — $(cat "$T/led.txt")"
assert_eq "$(cb ensure --roadmap "$RM" --session "$SID")" "0" "20 ensure rc 0 — $(cat "$T/cb.txt")"
STATE="$(g for-each-ref --format='%(refname:short)' refs/heads/conductor/)"
O4="$T/other"
git clone -q "$T/origin.git" "$O4" 2>/dev/null
for k in "user.name other" "user.email other@example.invalid" "commit.gpgsign false"; do git -C "$O4" config $k; done
printf '.claude/\n' >> "$O4/.git/info/exclude"
git -C "$O4" update-ref "refs/heads/$STATE" "refs/remotes/origin/$STATE"
assert_eq "$( (cd "$O4" && python3 "$CL" claim --roadmap "$RM" --session "$SID2") >/dev/null 2>&1; echo $?)" "0" "20 다른 클론이 자기 표지를 쥔다"
PLANTED="$(python3 - "$S" "$O4" "$RM" "$SID2" "$PEND" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import conductor_branch as CB
root, roadmap, session, path = sys.argv[2:6]
lines = "- E1 · 지휘 기록 · spec 승인 · 2026-11-20 · 남의 사람 줄\n- E1 · 지휘 기록 · 결정 · 2026-11-20 · 남의 보통 줄\n"
print(CB.write(root, roadmap, session, lambda base: {path: (base.read(path) or "") + lines}, "남의 대기 줄").commit)
PY
)"
g fetch -q origin
assert_eq "$(g rev-parse "refs/remotes/origin/$STATE")" "$PLANTED" "20 남이 심은 대기 줄을 받아 왔다(양성 대조)"
assert_eq "$(led pending --roadmap "$RM" --epic E1)" "0" "20 pending rc 0"
assert_eq "$(cat "$T/led.txt")" "$(printf '%s\n' "- spec 승인 · 2026-11-20 · 기계 사람 줄" "- 결정 · 2026-11-20 · 기계 보통 줄" "- spec 승인 · 2026-11-20 · 남의 사람 줄   (확인되지 않은 남의 고침)" "- 결정 · 2026-11-20 · 남의 보통 줄   (확인되지 않은 남의 고침)")" "20 두 자리를 기계 상태 먼저 · 남의 줄에 표시"
assert_eq "$(flush)" "0" "20 flush rc 0 — $(cat "$T/led.txt")"
assert_contains "$(cat "$T/led.txt")" "[spec-distill] 사람 줄이라 옮기지 않은 대기 줄 2 — record --human 으로 적고 drop 으로 지운다" "20 사람 줄 둘을 건너뛰어 센다"
assert_contains "$(cat "$T/led.txt")" "[spec-distill] 확인되지 않은 남의 고침이 더한 대기 줄 1 — 옮기지 않았다" "20 남의 보통 줄 하나를 세고 옮기지 않는다"
assert_eq "$(decided "결정 · 2026-11-20 · 기계 보통 줄"):$(decided "결정 · 2026-11-20 · 남의 보통 줄"):$(grep -c '사람 줄' "$W/$INTENT")" "1:0:0" "20 결정 기록에 기계 상태의 보통 줄만"
assert_eq "$(led pending --roadmap "$RM" --epic E1)" "0" "20 flush 뒤 pending rc 0"
assert_eq "$(cat "$T/led.txt")" "$(printf '%s\n' "- spec 승인 · 2026-11-20 · 기계 사람 줄" "- spec 승인 · 2026-11-20 · 남의 사람 줄   (확인되지 않은 남의 고침)" "- 결정 · 2026-11-20 · 남의 보통 줄   (확인되지 않은 남의 고침)")" "20 기계 상태의 사람 줄은 남고(I6) 보통 줄만 빠졌다 · pending.md 의 사람 줄 · 남의 보통 줄이 남았다"
assert_eq "$(cb confirm --roadmap "$RM" --session "$SID")" "1" "20 확인 표시 없는 confirm 은 보고하고 1 — $(cat "$T/cb.txt")"
CTIP="$(sed -n '$s/^확인할 끝: //p' "$T/cb.txt")"
assert_eq "$(cb confirm --roadmap "$RM" --session "$SID" --confirmed "$CTIP")" "0" "20 그 끝으로 확인 rc 0 — $(cat "$T/cb.txt")"
assert_eq "$(flush)" "0" "20 confirm 뒤 flush rc 0 — $(cat "$T/led.txt")"
assert_contains "$(cat "$T/led.txt")" "쌓인 기록 1줄을 옮겼고 0줄은 이미 있어 건너뛰었다(커밋은 리더가)" "20 확인한 남의 보통 줄을 옮겼다"
assert_not_contains "$(cat "$T/led.txt")" "확인되지 않은 남의 고침이 더한 대기 줄" "20 확인한 뒤에는 남의 줄로 세지 않는다"
assert_eq "$(decided "결정 · 2026-11-20 · 남의 보통 줄")" "1" "20 결정 기록에 남의 보통 줄이 하나"
assert_eq "$(seen_pend)" "- E1 · 지휘 기록 · spec 승인 · 2026-11-20 · 남의 사람 줄" "20 pending.md 에는 남의 사람 줄만 남았다"

note "# 21 — 꺼진 설정: 같은 걸음은 R1 의 출력 그대로(사람 줄이 섞이면 2 로 멈춘다 · AC20)"
printf -- '---\nstate_branch: 끔\n---\n' > "$W/.devbrew.md" && g add -- .devbrew.md && g commit -qm "상태 브랜치 끔" && push_main
assert_eq "$(pend "결정 · 2026-11-20 · 꺼진 뒤 줄")" "0" "21 꺼진 설정의 add rc 0 — $(cat "$T/led.txt")"
assert_eq "$(cat "$T/led.txt")" "적었다 — 쌓인 기록: E1 · 지휘 기록 · 결정 · 2026-11-20 · 꺼진 뒤 줄" "21 add 의 출력은 R1 의 글 그대로(알림 없음)"
BEFORE="$(cksum < "$W/$INTENT")"
assert_eq "$(flush)" "2" "21 사람 줄이 섞인 flush 는 2 — $(cat "$T/led.txt")"
assert_eq "$(cat "$T/led.txt")" "[spec-distill] 사람 줄(spec 승인)은 record --human 으로만 적는다 — 고른 글을 인자로 받지 않는다" "21 R1 의 멈춤 글 그대로"
assert_eq "$(cksum < "$W/$INTENT")" "$BEFORE" "21 결정 기록은 그대로"

finish
