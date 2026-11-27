#!/usr/bin/env bash
# roadmap_write.py job sync — 결과 파일 맞추기(Q15 · AC27)와 workflow_superpowers.py place(AC17).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_team_sync.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"
WSP="$S/workflow_superpowers.py"
team_repo && ok "팀 레포를 세웠다(${TM})" || { no "팀 레포를 세우지 못했다 — $(cat "$T/out.txt")"; finish; }

R="$TM/jobs/E1/results/implement-plan-1-1.md"
B="$(g rev-parse origin/main)"; J="$(g rev-parse HEAD)"
raw() {  # raw <--result 값> <인자…> — 그 경로 그대로 job sync 를 부르고 rc 를 echo 한다
  local p="$1"; shift
  (cd "$W" && python3 "$RW" job sync --result "$p" "$@") > "$T/out.txt" 2>&1
  echo $?
}

expect() {  # expect <실제 rc> <기대 rc> <사유 조각> <라벨> — rc 와 사유 문장을 함께 본다. 죽어서 나온 rc 1(내부 오류)은 거절로 치지 않는다
  assert_eq "$1" "$2" "$4: rc"
  assert_contains "$(cat "$T/out.txt")" "$3" "$4: 사유"
  assert_not_contains "$(cat "$T/out.txt")" "내부 오류" "$4: 죽은 것이 아니다"
}
rattr() {  # rattr <결과 파일> <Result 속성> — 결과 파일 읽기(parse_result)가 읽은 값을 한 줄로
  python3 - "$S" "$1" "$2" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import team_files
r = team_files.parse_result(open(sys.argv[2], encoding="utf-8", newline="").read())
print(getattr(r, sys.argv[3]))
PY
}
RES="$W/$TM/jobs/E1/results"
J0="$(g rev-parse HEAD~1)"

# 계획 · 원장 — 단계 셋, 둘째까지 끝, 판정 하나 (test_workflow_superpowers.py 의 글과 다르다)
printf '# 구현 계획\n\n## 공통\n\n### Task 1: 첫 걸음\n\n내용\n\n### Task 2: 둘째 걸음\n\n### Task 3: 셋째 걸음\n' > "$T/plan.md"
printf '# 구현 원장\n\n- Task 1: complete (commits 0a0a0a0..1b1b1b1 — 첫 걸음)\n- Ruling: Q-1 — 이름은 그대로 — 근거 하나\n- Task 2: complete (커밋 없음 — 읽기뿐)\n- Task 3: 진행 중\n' > "$T/ledger.md"

# ── 만들기 ───────────────────────────────────────────────────────────────────
rc="$(sync E1 implement-plan-1-1.md)"; expect "$rc" 1 "머리를 만들 값이 없다" "job sync: 파일도 머리 값도 없으면 거절"
[ ! -e "$W/$R" ] && ok "job sync: 거절하면 파일을 만들지 않는다" || no "job sync: 거절했는데 파일이 생겼다"
assert_eq "$(sync E1 implement-plan-1-1.md --role worker --bundle-at "$B" --job-at "$J")" "0" "job sync: 머리를 만든다"
assert_contains "$(cat "$T/out.txt")" "머리 만듦" "job sync: 한 일을 말한다"
assert_eq "$(cat "$W/$R")" "$(printf -- '---\ntype: job-result\nstage: implement\nplan: 1\nattempt: 1\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---' "$J" "$B" "$J")" "job sync: 머리 글과 키의 차례"
assert_eq "$(tail -c 2 "$W/$R" | od -An -c | tr -d ' ')" '\n\n' "job sync: 머리 뒤에 빈 줄 하나"
python3 -c 'import sys; data = open(sys.argv[1], "rb").read(); sys.exit(0 if data.endswith(b"---\n\n") and not data.endswith(b"---\n\n\n") else 1)' "$W/$R" && ok "job sync: 새 머리는 닫는 줄 뒤에 줄바꿈 하나와 빈 줄 하나로 끝난다" || no "job sync: 새 머리 뒤 빈 줄이 하나가 아니다"

# ── 원장 · 계획에서 줄 내기 (AC27) ───────────────────────────────────────────
assert_eq "$(sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "0" "job sync: 원장에서 줄을 낸다"
assert_contains "$(cat "$T/out.txt")" "Task 줄 +2 · Ruling 줄 +1" "job sync: 줄 수를 말한다"
assert_eq "$(grep -c '^Task ' "$W/$R"):$(grep -c '^Ruling: ' "$W/$R")" "2:1" "job sync: Task 줄 둘 · Ruling 줄 하나"
assert_eq "$(grep '^Task ' "$W/$R" | tr '\n' '|')" "Task 1/3: 끝 — 1b1b1b1|Task 2/3: 끝 — 없음|" "job sync: 줄 글과 차례"
printf 'AC1: 구현됨 — src/e1/a.txt\n\n손으로 쓴 메모\n' >> "$W/$R"; cp "$W/$R" "$T/before.md"
assert_eq "$(sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "0" "AC27: 같은 원장으로 두 번째"
cmp -s "$W/$R" "$T/before.md" && ok "AC27: 두 번 돌려도 같은 줄이 두 번 생기지 않는다(바이트 그대로)" || no "AC27: 두 번째 실행이 파일을 바꿨다"
assert_contains "$(cat "$T/out.txt")" "바뀐 것 없음" "job sync: 바뀐 것이 없다고 말한다"
printf -- '- Task 3: complete (commits 3333333..4444444, review clean)\n' >> "$T/ledger.md"
assert_eq "$(sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "0" "job sync: 원장이 늘면"
assert_eq "$(tail -n 1 "$W/$R")" "Task 3/3: 끝 — 4444444" "job sync: 늘어난 줄만 끝에 붙는다"
assert_contains "$(cat "$W/$R")" "손으로 쓴 메모" "job sync: 손으로 쓴 줄은 그대로"
assert_eq "$(grep -c '^AC1: 구현됨 — src/e1/a.txt$' "$W/$R")" "1" "job sync: 일꾼이 쓴 AC 줄은 그대로 한 번"

# ── 끝내기 ───────────────────────────────────────────────────────────────────
assert_eq "$(sync E1 implement-plan-1-1.md --end "$J")" "0" "job sync: 끝낸다"
assert_eq "$(tail -n 1 "$W/$R")" "끝 — $J" "job sync: 끝 줄이 마지막 줄"
assert_contains "$(cat "$T/out.txt")" "끝 줄" "job sync: 끝 줄을 달았다고 말한다"
assert_eq "$(sed -n '/^---$/,/^---$/p' "$W/$R" | grep -c "^head: $J$")" "1" "job sync: 머리의 head 가 끝 커밋이다"
assert_eq "$(grep -c '^끝 — ' "$W/$R")" "1" "job sync: 끝 줄은 하나"
cp "$W/$R" "$T/closed.md"
assert_eq "$(sync E1 implement-plan-1-1.md --end "$J")" "0" "job sync: 끝난 파일에 같은 끝 — 바뀐 것 없음"
assert_contains "$(cat "$T/out.txt")" "바뀐 것 없음" "job sync: 같은 끝은 바뀐 것 없음이라 말한다"
cmp -s "$W/$R" "$T/closed.md" && ok "job sync: 같은 끝을 다시 주면 바이트 그대로" || no "job sync: 같은 끝이 파일을 바꿨다"
printf -- '- Ruling: Q-9 — 끝난 뒤에 생긴 판정\n' >> "$T/ledger.md"
rc="$(sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")"; expect "$rc" 1 "끝난 결과 파일은 고치지 않는다" "job sync: 끝난 파일은 고치지 않는다"
cmp -s "$W/$R" "$T/closed.md" && ok "job sync: 거절하면 바이트 그대로" || no "job sync: 끝난 파일을 바꿨다"
rc="$(sync E1 implement-plan-1-1.md --end "$J0")"; expect "$rc" 1 "끝난 결과 파일은 고치지 않는다" "job sync: 끝난 파일에 다른 끝은 거절"
cmp -s "$W/$R" "$T/closed.md" && ok "job sync: 다른 끝을 거절해도 바이트 그대로" || no "job sync: 다른 끝이 끝난 파일을 바꿨다"
printf '# 넷\n\n### Task 1: 하나\n\n### Task 2: 둘\n\n### Task 3: 셋\n\n### Task 4: 넷\n' > "$T/plan4.md"
cp "$T/ledger.md" "$T/ledger4.md"; printf -- '- Task 4: complete (commits 5555555..6666666, review clean)\n' >> "$T/ledger4.md"
rc="$(sync E1 implement-plan-1-1.md --ledger "$T/ledger4.md" --plan-file "$T/plan4.md")"; expect "$rc" 1 "끝난 결과 파일은 고치지 않는다" "job sync: 끝난 파일에 새 Task 줄도 거절"
cmp -s "$W/$R" "$T/closed.md" && ok "job sync: 새 Task 줄을 거절해도 바이트 그대로" || no "job sync: 끝난 파일에 Task 줄을 덧붙였다"

printf '# 구현 원장\n\n- Task 1: complete (commits 0a0a0a0..1b1b1b1 — 첫 걸음)\n- Ruling: Q-1 — 이름은 그대로 — 근거 하나\n- Task 2: complete (커밋 없음 — 읽기뿐)\n- Task 3: 진행 중\n' > "$T/ledger0.md"   # 위 원장의 처음 꼴(뒤에서 더해지기 전)
# ── 끝은 머리의 head 도 바꾼다 · 만들면서 끝내기 · 있는 머리는 그대로 ────────────────
F6="$RES/implement-plan-1-6.md"
assert_eq "$(sync E1 implement-plan-1-6.md --role worker --bundle-at "$B" --job-at "$J0")" "0" "head: 머리 head 가 끝 커밋과 다른 파일을 만든다"
cp "$F6" "$T/h6.before"
assert_eq "$(sync E1 implement-plan-1-6.md --end "$J")" "0" "head: --end 로 끝낸다"
assert_eq "$(rattr "$F6" head):$(rattr "$F6" end):$(rattr "$F6" job_at)" "$J:$J:$J0" "head: 머리 head 가 끝 커밋이 되고 job_at 은 그대로"
assert_eq "$(sed '$d' "$F6" | sed 's/^head:.*//')" "$(sed 's/^head:.*//' "$T/h6.before")" "head: head 줄과 끝 줄 밖의 바이트는 그대로"
assert_eq "$(sync E1 implement-plan-1-7.md --role worker --bundle-at "$B" --job-at "$J0" --end "$J")" "0" "head: 없는 파일을 만들면서 끝낸다"
assert_contains "$(cat "$T/out.txt")" "머리 만듦 · 끝 줄" "head: 만들기와 끝 줄을 함께 말한다"
assert_eq "$(rattr "$RES/implement-plan-1-7.md" head):$(rattr "$RES/implement-plan-1-7.md" end):$(rattr "$RES/implement-plan-1-7.md" problems)" "$J:$J:[]" "head: 만들면서 끝낸 파일은 head 와 끝이 같고 읽힌다"
cp "$RES/implement-plan-1-7.md" "$T/h7.before"
F8="$RES/implement-plan-1-8.md"
assert_eq "$(sync E1 implement-plan-1-8.md --role worker --bundle-at "$B" --job-at "$J0")" "0" "머리 인자: 파일을 만든다"
cp "$F8" "$T/h8.before"
assert_eq "$(sync E1 implement-plan-1-8.md --role writer --bundle-at "$J0" --job-at "$J0")" "0" "머리 인자: 있는 파일에 다른 머리 값을 줘도 rc 0"
assert_contains "$(cat "$T/out.txt")" "묶은 커밋 고침" "머리 인자: 끝 줄 없는 파일은 묶은 커밋 둘을 고친다"
assert_eq "$(grep -c "^bundle_at: ${J0}\$" "$F8") $(grep -c "^job_at: ${J0}\$" "$F8") $(grep -c '^role: worker$' "$F8")" "1 1 1" "머리 인자: 두 커밋만 새 값이고 role 은 그대로다"
assert_eq "$(diff <(grep -v -e '^bundle_at:' -e '^job_at:' "$T/h8.before") <(grep -v -e '^bundle_at:' -e '^job_at:' "$F8") | wc -l | tr -d ' ')" "0" "머리 인자: 그 두 줄 밖은 바이트 그대로다"
assert_eq "$(sync E1 implement-plan-1-8.md --bundle-at "$B")" "2" "머리 인자: 둘 가운데 하나만 주면 사용법 오류"
assert_eq "$(sync E1 implement-plan-1-8.md --job-at "$B")" "2" "머리 인자: --job-at 만 줘도 사용법 오류"
assert_eq "$(sync E1 implement-plan-1-7.md --bundle-at "$J0" --job-at "$J0")" "0" "머리 인자: 끝 줄이 있는 파일은 다른 값을 줘도 rc 0"
assert_contains "$(cat "$T/out.txt")" "바뀐 것 없음" "머리 인자: 끝 줄이 있는 파일은 바뀐 것 없음"
cmp -s "$RES/implement-plan-1-7.md" "$T/h7.before" && ok "머리 인자: 끝 줄이 있는 파일은 바이트 그대로다" || no "머리 인자: 끝 줄이 있는 파일을 고쳤다"
# 두 커밋이 모두 새 값으로 바뀐다 — 앞 커밋 A 와 새 두 커밋 NB · NJ 가 서로 다르다(HEAD~2 · HEAD~1 · HEAD)
A20="$(g rev-parse HEAD~2)"; NB="$J0"; NJ="$J"
F20="$RES/implement-plan-1-20.md"
assert_eq "$([ -n "$A20" ] && [ "$A20" != "$NB" ] && [ "$A20" != "$NJ" ] && [ "$NB" != "$NJ" ] && echo distinct)" "distinct" "머리 인자: 세 커밋이 서로 다르다(양성 대조)"
assert_eq "$(sync E1 implement-plan-1-20.md --role worker --bundle-at "$A20" --job-at "$A20")" "0" "머리 인자: 이을 파일을 만든다"
cp "$F20" "$T/h20.before"
assert_eq "$(sync E1 implement-plan-1-20.md --bundle-at "$NB" --job-at "$NJ")" "0" "머리 인자: 이어 쓰며 두 커밋을 모두 새 값으로"
assert_eq "$(grep -c "^bundle_at: ${NB}\$" "$F20") $(grep -c "^job_at: ${NJ}\$" "$F20") $(grep -c "^role: worker\$" "$F20") $(grep -c "${A20}" "$F20")" "1 1 1 1" "머리 인자: bundle_at 은 NB · job_at 은 NJ 로 한 번씩, role 은 그대로, 앞 값은 head 줄에만 남는다"
assert_eq "$(diff <(grep -v -e '^bundle_at:' -e '^job_at:' "$T/h20.before") <(grep -v -e '^bundle_at:' -e '^job_at:' "$F20") | wc -l | tr -d ' ')" "0" "머리 인자: 두 커밋 줄 밖은 바이트 그대로다(둘째 파일)"

# ── rules_at (R3 AC15) — 상태 브랜치에서 규칙을 읽은 묶음의 맞추는 명령이 싣는다 ───────────────
# 「없이 만든 머리」 는 위 「머리 글과 키의 차례」 단언이 바이트 그대로 잰다(rules_at 줄이 없다)
RA="$A20"; RA2="$(printf 'd%.0s' $(seq 40))"   # job sync 는 커밋이 있는지 보지 않는다 — 꼴만 본다
assert_eq "$([ -n "$RA2" ] && [ "$RA2" != "$RA" ] && [ "$RA2" != "$NB" ] && [ "$RA2" != "$NJ" ] && echo distinct)" "distinct" "rules_at: 두 규칙 커밋이 다른 커밋들과 다르다(양성 대조)"
F21="$RES/implement-plan-1-21.md"
assert_eq "$(sync E1 implement-plan-1-21.md --role worker --bundle-at "$B" --job-at "$J" --rules-at "$RA")" "0" "rules_at: 새 머리를 만든다"
assert_eq "$(cat "$F21")" "$(printf -- '---\ntype: job-result\nstage: implement\nplan: 1\nattempt: 21\nrole: worker\nhead: %s\nbundle_at: %s\nrules_at: %s\njob_at: %s\n---' "$J" "$B" "$RA" "$J")" "rules_at: 새 머리에서 bundle_at 바로 뒤 · job_at 바로 앞"
assert_eq "$(rattr "$F21" rules_at):$(rattr "$F21" problems)" "${RA}:[]" "rules_at: 읽기가 그 값을 읽는다"
F22="$RES/implement-plan-1-22.md"
assert_eq "$(sync E1 implement-plan-1-22.md --role worker --bundle-at "$B" --job-at "$J0")" "0" "rules_at: 이을 파일(rules_at 없음)을 만든다"
printf '손으로 쓴 메모\n' >> "$F22"; cp "$F22" "$T/h22.before"
assert_eq "$(grep -c '^rules_at:' "$F22")" "0" "rules_at: 이을 파일에 rules_at 줄이 없다(양성 대조)"
assert_eq "$(sync E1 implement-plan-1-22.md --bundle-at "$NB" --job-at "$NJ" --rules-at "$RA")" "0" "rules_at: 이어 쓰며 셋을 함께 준다"
assert_eq "$(grep -c '^rules_at:' "$F22") $(grep -A1 '^bundle_at:' "$F22" | tail -n 1)" "1 rules_at: $RA" "rules_at: bundle_at 줄 바로 뒤에 한 줄"
assert_eq "$(grep -c "^bundle_at: ${NB}\$" "$F22") $(grep -c "^job_at: ${NJ}\$" "$F22")" "1 1" "rules_at: 묶은 커밋 둘도 새 값이다"
assert_eq "$(diff <(grep -v -e '^bundle_at:' -e '^job_at:' "$T/h22.before") <(grep -v -e '^bundle_at:' -e '^job_at:' -e '^rules_at:' "$F22") | wc -l | tr -d ' ')" "0" "rules_at: 세 줄 밖은 바이트 그대로"
assert_eq "$(rattr "$F22" rules_at):$(rattr "$F22" problems)" "${RA}:[]" "rules_at: 이어 쓴 파일이 읽힌다"
cp "$F22" "$T/h22.mid"
assert_eq "$(sync E1 implement-plan-1-22.md --bundle-at "$NB" --job-at "$NJ" --rules-at "$RA2")" "0" "rules_at: 있는 rules_at 을 새 값으로"
assert_eq "$(grep -c '^rules_at:' "$F22") $(grep -A1 '^bundle_at:' "$F22" | tail -n 1)" "1 rules_at: $RA2" "rules_at: 있는 줄을 그 자리에서 고치고 둘째 줄을 만들지 않는다"
assert_eq "$(diff <(grep -v '^rules_at:' "$T/h22.mid") <(grep -v '^rules_at:' "$F22") | wc -l | tr -d ' ')" "0" "rules_at: 고친 줄 밖은 바이트 그대로"
cp "$F22" "$T/h22.after"
rc="$(sync E1 implement-plan-1-22.md --rules-at "$RA")"; expect "$rc" 2 "--rules-at" "rules_at: 홀로 준 --rules-at 은 사용법 오류"
cmp -s "$F22" "$T/h22.after" && ok "rules_at: 홀로 준 --rules-at 은 파일을 바이트 그대로 둔다" || no "rules_at: 홀로 준 --rules-at 이 파일을 바꿨다"
rc="$(sync E1 implement-plan-1-23.md --role worker --rules-at "$RA")"; expect "$rc" 2 "--rules-at" "rules_at: 묶은 커밋 없이 새 파일에 준 --rules-at 도 사용법 오류"
[ ! -e "$RES/implement-plan-1-23.md" ] && ok "rules_at: 사용법 오류는 파일을 만들지 않는다" || no "rules_at: 사용법 오류인데 파일이 생겼다"
rc="$(sync E1 implement-plan-1-22.md --bundle-at "$NB" --job-at "$NJ" --rules-at abc1234)"; expect "$rc" 2 "--rules-at 는 커밋 번호 꼴" "rules_at: 짧은 --rules-at 은 사용법 오류"
cmp -s "$F22" "$T/h22.after" && ok "rules_at: 짧은 --rules-at 도 바이트 그대로" || no "rules_at: 짧은 --rules-at 이 파일을 바꿨다"
# 기본 브랜치에서 규칙을 읽은 묶음으로 이어 쓰면(인자 넷 — --rules-at 없음) 옛 rules_at 줄을 지운다(AC15 — 없으면 bundle_at)
F24="$RES/implement-plan-1-24.md"
assert_eq "$(sync E1 implement-plan-1-24.md --role worker --bundle-at "$B" --job-at "$J0" --rules-at "$RA")" "0" "rules_at 지움: rules_at 이 있는 이을 파일을 만든다"
printf '손으로 쓴 메모\n' >> "$F24"; cp "$F24" "$T/h24.before"
assert_eq "$(grep -c "^rules_at: ${RA}\$" "$F24")" "1" "rules_at 지움: 이을 파일에 rules_at 줄이 있다(양성 대조)"
assert_eq "$(sync E1 implement-plan-1-24.md --bundle-at "$NB" --job-at "$NJ")" "0" "rules_at 지움: 인자 넷으로 이어 쓴다"
assert_eq "$(grep -c '^rules_at:' "$F24") $(grep -A1 '^bundle_at:' "$F24" | tail -n 1)" "0 job_at: ${NJ}" "rules_at 지움: rules_at 줄이 없고 bundle_at 뒤는 job_at"
assert_eq "$(diff <(grep -v -e '^bundle_at:' -e '^job_at:' -e '^rules_at:' "$T/h24.before") <(grep -v -e '^bundle_at:' -e '^job_at:' "$F24") | wc -l | tr -d ' ')" "0" "rules_at 지움: 세 줄 밖은 바이트 그대로"
assert_eq "$(rattr "$F24" rules_at):$(rattr "$F24" problems)" "None:[]" "rules_at 지움: 읽기가 rules_at 없음으로 읽는다"
F25="$RES/implement-plan-1-25.md"
assert_eq "$(sync E1 implement-plan-1-25.md --role worker --bundle-at "$B" --job-at "$J0" --rules-at "$RA" --end "$J")" "0" "rules_at 지움: 끝 줄이 있는 파일(rules_at 있음)"
cp "$F25" "$T/h25.before"
assert_eq "$(sync E1 implement-plan-1-25.md --bundle-at "$NB" --job-at "$NJ")" "0" "rules_at 지움: 끝난 파일에 인자 넷"
cmp -s "$F25" "$T/h25.before" && ok "rules_at 지움: 끝난 파일의 rules_at 은 그대로(바이트 그대로)" || no "rules_at 지움: 끝난 파일을 고쳤다"

# ── 줄바꿈 꼴: 끝 줄바꿈이 없는 파일 · CRLF 파일 ───────────────────────────────
F9="$RES/implement-plan-1-9.md"
assert_eq "$(sync E1 implement-plan-1-9.md --role worker --bundle-at "$B" --job-at "$J0")" "0" "줄바꿈: 준비"
printf '%s' "$(cat "$F9")" > "$T/h9.tmp"; cp "$T/h9.tmp" "$F9"
assert_eq "$(tail -c 3 "$F9")" "---" "줄바꿈: 끝 줄바꿈이 없는 파일로 만들었다(양성 대조)"
assert_eq "$(sync E1 implement-plan-1-9.md --ledger "$T/ledger0.md" --plan-file "$T/plan.md")" "0" "줄바꿈: 끝 줄바꿈 없는 파일에 덧붙인다"
N9="$(grep -n '^Task 1/3' "$F9" | cut -d: -f1)"
assert_eq "$(sed -n "$((N9 - 1))p" "$F9")" "---" "줄바꿈: 머리 닫는 줄 바로 다음 줄에 붙는다(줄바꿈 하나만 보탠다)"
assert_eq "$(grep -c '^Task ' "$F9"):$(rattr "$F9" problems)" "2:[]" "줄바꿈: 줄은 한 번씩 붙고 읽힌다"
assert_eq "$(tail -c 1 "$F9" | od -An -c | tr -d ' ')" '\n' "줄바꿈: 덧붙인 글은 줄바꿈으로 끝난다"
F10="$RES/implement-plan-1-10.md"
assert_eq "$(sync E1 implement-plan-1-10.md --role worker --bundle-at "$B" --job-at "$J0")" "0" "CRLF: 준비"
sed 's/$/\r/' "$F10" > "$T/h10.tmp"; cp "$T/h10.tmp" "$F10"
assert_eq "$(sync E1 implement-plan-1-10.md --ledger "$T/ledger0.md" --plan-file "$T/plan.md")" "0" "CRLF: CRLF 파일에 덧붙인다"
assert_eq "$(grep -vc $'\r$' "$F10")" "0" "CRLF: 덧붙인 줄도 CRLF 라 LF 가 섞이지 않는다"
assert_eq "$(grep -c '^Task ' "$F10"):$(rattr "$F10" problems)" "2:[]" "CRLF: 줄은 한 번씩 붙고 읽힌다"
cp "$F10" "$T/h10.after"
assert_eq "$(sync E1 implement-plan-1-10.md --ledger "$T/ledger0.md" --plan-file "$T/plan.md")" "0" "CRLF: 두 번째"
cmp -s "$F10" "$T/h10.after" && ok "CRLF: 두 번 돌려도 바이트 그대로" || no "CRLF: 두 번째 실행이 바꿨다"

# ── 펜스 안에 인용한 기계 줄은 거름 집합에 들지 않는다 ─────────────────────────────
F11="$RES/implement-plan-1-11.md"
assert_eq "$(sync E1 implement-plan-1-11.md --role worker --bundle-at "$B" --job-at "$J0")" "0" "펜스: 준비"
printf '```\nTask 1/3: 끝 — 1b1b1b1\n```\n' >> "$F11"
assert_eq "$(sync E1 implement-plan-1-11.md --ledger "$T/ledger0.md" --plan-file "$T/plan.md")" "0" "펜스: 원장에서 줄을 낸다"
assert_eq "$(grep -cx 'Task 1/3: 끝 — 1b1b1b1' "$F11")" "2" "펜스: 인용 한 줄 + 진짜 한 줄"
assert_eq "$(rattr "$F11" tasks)" "[(1, 3, '끝', '1b1b1b1'), (2, 3, '끝', '없음')]" "펜스: 읽기는 펜스 밖의 두 줄만 센다"

# ── 계획과 원장이 어긋나면 진행 줄을 쓰지 않는다 ──────────────────────────────────
printf '# 계획 없음\n\n내용뿐\n' > "$T/plan0.md"
printf '# 한 단계\n\n### Task 1: 하나\n' > "$T/plan1.md"
F12="$RES/implement-plan-1-12.md"
assert_eq "$(sync E1 implement-plan-1-12.md --role worker --bundle-at "$B" --job-at "$J0")" "0" "어긋남: 준비"
cp "$F12" "$T/h12.before"
rc="$(sync E1 implement-plan-1-12.md --ledger "$T/ledger0.md" --plan-file "$T/plan0.md")"; expect "$rc" 1 "계획 파일 $T/plan0.md 에 task 절이 없다" "어긋남: task 절이 없는 계획"
cmp -s "$F12" "$T/h12.before" && ok "어긋남: 거절하면 바이트 그대로(task 절 없음)" || no "어긋남: 파일을 바꿨다(task 절 없음)"
rc="$(sync E1 implement-plan-1-12.md --ledger "$T/ledger0.md" --plan-file "$T/plan1.md")"; expect "$rc" 1 "원장은 Task 2 의 끝을 말하는데 계획 파일 $T/plan1.md 의 task 절은 1개다" "어긋남: 원장이 계획보다 많이 끝났다고 한다"
cmp -s "$F12" "$T/h12.before" && ok "어긋남: 거절하면 바이트 그대로(번호 초과)" || no "어긋남: 파일을 바꿨다(번호 초과)"
F13="$RES/implement-plan-1-13.md"
assert_eq "$(sync E1 implement-plan-1-13.md --role worker --bundle-at "$B" --job-at "$J0")" "0" "전체 수 변화: 준비"
assert_eq "$(sync E1 implement-plan-1-13.md --ledger "$T/ledger0.md" --plan-file "$T/plan.md")" "0" "전체 수 변화: 전체 셋으로 한 번"
assert_eq "$(sync E1 implement-plan-1-13.md --ledger "$T/ledger0.md" --plan-file "$T/plan4.md")" "0" "전체 수 변화: 전체 넷으로 다시"
assert_eq "$(grep -c '^Task 1/' "$F13")" "2" "전체 수 변화: 글자 그대로 거르므로 같은 번호의 줄이 새 전체로 다시 붙는다(알려진 모양)"

# ── 거절 · 사용법 ────────────────────────────────────────────────────────────
A="implement-plan-1-2.md"
assert_eq "$(sync E1 "$A" --role worker --bundle-at "$B" --job-at "$J")" "0" "거절 준비: 시도 2 의 결과 파일"
sed 's/^attempt: 2$/attempt: 1/' "$W/$TM/jobs/E1/results/$A" > "$T/skew.md"; cp "$T/skew.md" "$W/$TM/jobs/E1/results/$A"
rc="$(sync E1 "$A" --ledger "$T/ledger.md" --plan-file "$T/plan.md")"; expect "$rc" 1 "머리의 단계 · 계획 · 시도 ('implement', 1, 1) 가 이름 $A 와 다르다" "거절: 이름과 머리가 어긋난다"
cmp -s "$W/$TM/jobs/E1/results/$A" "$T/skew.md" && ok "거절: 어긋난 파일은 바이트 그대로" || no "거절: 어긋난 파일을 바꿨다"
rc="$(raw "$TM/jobs/E1/implement-plan-1-3.md" --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "결과 파일 이름이 아니다(results/<단계>-<시도>.md 꼴): $TM/jobs/E1/implement-plan-1-3.md" "거절: 결과 폴더 밖 경로"
[ ! -e "$W/$TM/jobs/E1/implement-plan-1-3.md" ] && ok "거절: 결과 폴더 밖에 파일을 만들지 않는다" || no "거절: 결과 폴더 밖에 파일이 생겼다"
rc="$(sync E1 BLOCKED.md --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "결과 파일 이름이 아니다(results/<단계>-<시도>.md 꼴): $TM/jobs/E1/results/BLOCKED.md" "거절: 결과 파일 이름 꼴이 아니다(BLOCKED.md)"
[ ! -e "$W/$TM/jobs/E1/results/BLOCKED.md" ] && ok "거절: 막힘 파일 자리에 만들지 않는다" || no "거절: 막힘 파일 자리에 파일이 생겼다"
rc="$(sync E1 design-plan-1-1.md --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "결과 파일 이름이 아니다(results/<단계>-<시도>.md 꼴): $TM/jobs/E1/results/design-plan-1-1.md" "거절: design 이름에 계획 번호"
mkdir -p "$W/${RD}old/jobs/E9/results"
printf -- '---\ntype: roadmap\n---\n\n# 옛 형식\n' > "$W/${RD}old/roadmap.md"
rc="$(raw "${RD}old/jobs/E9/results/implement-1.md" --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "team 형식 로드맵의 과제가 아니다 — ${RD}old/roadmap.md 가 없거나 머리말에" "거절: team 형식이 아닌 로드맵의 폴더"
[ ! -e "$W/${RD}old/jobs/E9/results/implement-1.md" ] && ok "거절: 옛 형식 폴더에 파일을 만들지 않는다" || no "거절: 옛 형식 폴더에 파일이 생겼다"
mkdir -p "$W/${RD}norm/jobs/E9/results"
rc="$(raw "${RD}norm/jobs/E9/results/implement-1.md" --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "team 형식 로드맵의 과제가 아니다 — ${RD}norm/roadmap.md 가 없거나 머리말에" "거절: 로드맵 파일이 없는 폴더"
rc="$(sync NOPE implement-1.md --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "과제 폴더가 없다: $TM/jobs/NOPE" "거절: 과제 폴더가 없다"
[ ! -e "$W/$TM/jobs/NOPE" ] && ok "거절: 없는 과제 폴더를 만들지 않는다" || no "거절: 없는 과제 폴더가 생겼다"
ln -s "$W/$TM/jobs/E1/results/$A" "$W/$TM/jobs/E1/results/implement-plan-1-4.md"
rc="$(sync E1 implement-plan-1-4.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")"; expect "$rc" 1 "심볼릭 링크로는 쓰지 않는다" "거절: 결과 파일이 심볼릭 링크"
cmp -s "$W/$TM/jobs/E1/results/$A" "$T/skew.md" && ok "거절: 링크 너머의 파일을 쓰지 않았다" || no "거절: 링크 너머의 파일을 썼다"
rm -rf "$W/$TM/jobs/E3/results"; ln -s ../E2/results "$W/$TM/jobs/E3/results"
rc="$(sync E3 implement-1.md --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "심볼릭 링크로는 쓰지 않는다: $TM/jobs/E3/results" "거절: 결과 폴더가 다른 과제 결과 폴더로의 링크"
[ ! -e "$W/$TM/jobs/E2/results/implement-1.md" ] && ok "거절: 링크 너머(E2)에 파일을 만들지 않는다" || no "거절: 링크 너머(E2)에 파일이 생겼다"
# 레포 밖의 링크로 같은 자리를 가리켜도(P3) · 결과 폴더가 다른 작업 트리로의 링크여도(P4) 따라가지 않는다
OUTSIDE="작업 트리 안의 경로로 이어지지 않는다"
ln -s "$W/$TM/jobs/E3/results" "$T/outer-link"
rc="$(raw "$T/outer-link/implement-1.md" --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "$OUTSIDE" "거절: 레포 밖의 링크로 준 --result(P3)"
[ ! -e "$W/$TM/jobs/E2/results/implement-1.md" ] && ok "거절: P3 — E2 에 파일을 만들지 않는다" || no "거절: P3 — E2 에 파일이 생겼다"
mkdir -p "$T/other/results"; git -C "$T/other" init -q
rm "$W/$TM/jobs/E3/results"; ln -s "$T/other/results" "$W/$TM/jobs/E3/results"
rc="$(sync E3 implement-1.md --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "$OUTSIDE" "거절: 결과 폴더가 다른 작업 트리로의 링크(P4)"
[ ! -e "$T/other/results/implement-1.md" ] && ok "거절: P4 — 다른 작업 트리에 파일을 만들지 않는다" || no "거절: P4 — 다른 작업 트리에 파일이 생겼다"
# 과제 폴더가 링크(jobs/E3 → E2) · jobs 폴더가 링크
rm "$W/$TM/jobs/E3/results"; rm -rf "$W/$TM/jobs/E3"; ln -s E2 "$W/$TM/jobs/E3"
rc="$(sync E3 implement-1.md --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "심볼릭 링크로는 쓰지 않는다: $TM/jobs/E3" "거절: 과제 폴더가 링크"
[ ! -e "$W/$TM/jobs/E2/results/implement-1.md" ] && ok "거절: 과제 폴더 링크 너머에 파일을 만들지 않는다" || no "거절: 과제 폴더 링크 너머에 파일이 생겼다"
rm "$W/$TM/jobs/E3"
mv "$W/$TM/jobs" "$W/$TM/jobs.real"; ln -s jobs.real "$W/$TM/jobs"
rc="$(sync E1 implement-plan-1-14.md --role worker --bundle-at "$B" --job-at "$J")"; expect "$rc" 1 "심볼릭 링크로는 쓰지 않는다: $TM/jobs" "거절: jobs 폴더가 링크"
[ ! -e "$W/$TM/jobs.real/E1/results/implement-plan-1-14.md" ] && ok "거절: jobs 링크 너머에 파일을 만들지 않는다" || no "거절: jobs 링크 너머에 파일이 생겼다"
rm "$W/$TM/jobs"; mv "$W/$TM/jobs.real" "$W/$TM/jobs"
mkdir -p "$W/$TM/jobs/E3/results"
printf '머리가 없는 글\n' > "$W/$TM/jobs/E1/results/implement-plan-1-5.md"
rc="$(sync E1 implement-plan-1-5.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")"; expect "$rc" 1 "결과 파일을 읽지 못했다: $TM/jobs/E1/results/implement-plan-1-5.md — 머리(첫 줄" "거절: 읽히지 않는 결과 파일"
assert_eq "$(cat "$W/$TM/jobs/E1/results/implement-plan-1-5.md")" "머리가 없는 글" "거절: 읽히지 않는 파일은 바이트 그대로"
rc="$(sync E1 implement-2.md --ledger "$T/ledger.md")"; expect "$rc" 2 "--ledger 와 --plan-file 은 함께만 준다" "사용법: --ledger 만 주면 2"
rc="$(sync E1 implement-2.md --plan-file "$T/plan.md")"; expect "$rc" 2 "--ledger 와 --plan-file 은 함께만 준다" "사용법: --plan-file 만 주면 2"
rc="$(sync E1 implement-2.md --role worker --bundle-at "$B" --job-at "$J" --end abc1234)"; expect "$rc" 2 "--end 는 커밋 번호 꼴" "사용법: 짧은 커밋 번호는 2"
rc="$(sync E1 implement-2.md --role reviewer --bundle-at "$B" --job-at "$J")"; expect "$rc" 2 "--role 은 leader · designer · writer · worker 가운데 하나다: 'reviewer'" "사용법: 역할 이름이 아니면 2"
rc="$(sync E1 implement-2.md --role worker --bundle-at abc1234 --job-at "$J")"; expect "$rc" 2 "--bundle-at 는 커밋 번호 꼴" "사용법: 짧은 --bundle-at 은 2"
[ ! -e "$W/$TM/jobs/E1/results/implement-2.md" ] && ok "사용법 오류는 파일을 만들지 않는다" || no "사용법 오류인데 파일이 생겼다"

# ── place 문장 (AC17) ────────────────────────────────────────────────────────
place() { (cd "$W" && python3 "$WSP" place --root "$W" "$@") > "$T/place.txt" 2>&1; echo $?; }
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage design)" "0" "place: design rc 0"
assert_eq "$(cat "$T/place.txt")" "설계문서는 기본 자리 대신 $TM/jobs/E1/design.md 에 쓴다." "place: 설계문서 문장"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage plan --plan 2)" "0" "place: plan rc 0"
assert_eq "$(cat "$T/place.txt")" "계획은 기본 자리 대신 $TM/jobs/E1/plan-2.md 에 쓴다." "place: 계획 문장"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage plan)" "2" "place: plan 단계에 --plan 이 없으면 2"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage plan --plan 0)" "2" "place: 계획 번호 0 은 2"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage implement)" "2" "place: 다른 단계는 2"
assert_eq "$(place --roadmap docs/not-a-roadmap.md --job E1 --stage design)" "2" "place: 로드맵 자리가 아니면 2"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job "../x" --stage design)" "2" "place: 과제 이름 꼴이 아니면 2"
assert_eq "$( (cd "$T" && python3 "$WSP" place --root "$T/no-such-dir" --roadmap "$TM/roadmap.md" --job E1 --stage design) >/dev/null 2>&1; echo $?)" "3" "place: 레포 설정을 못 읽으면 3"

finish
