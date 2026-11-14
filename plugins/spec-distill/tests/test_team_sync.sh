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

# 계획 · 원장 — 단계 셋, 둘째까지 끝, 판정 하나 (test_workflow_superpowers.py 의 글과 다르다)
printf '# 구현 계획\n\n## 공통\n\n### Task 1: 첫 걸음\n\n내용\n\n### Task 2: 둘째 걸음\n\n### Task 3: 셋째 걸음\n' > "$T/plan.md"
printf '# 구현 원장\n\n- Task 1: complete (commits 0a0a0a0..1b1b1b1 — 첫 걸음)\n- Ruling: Q-1 — 이름은 그대로 — 근거 하나\n- Task 2: complete (커밋 없음 — 읽기뿐)\n- Task 3: 진행 중\n' > "$T/ledger.md"

# ── 만들기 ───────────────────────────────────────────────────────────────────
assert_eq "$(sync E1 implement-plan-1-1.md)" "1" "job sync: 파일도 머리 값도 없으면 거절"
assert_contains "$(cat "$T/out.txt")" "머리를 만들 값이 없다" "job sync: 거절 사유"
[ ! -e "$W/$R" ] && ok "job sync: 거절하면 파일을 만들지 않는다" || no "job sync: 거절했는데 파일이 생겼다"
assert_eq "$(sync E1 implement-plan-1-1.md --role worker --bundle-at "$B" --job-at "$J")" "0" "job sync: 머리를 만든다"
assert_contains "$(cat "$T/out.txt")" "머리 만듦" "job sync: 한 일을 말한다"
assert_eq "$(cat "$W/$R")" "$(printf -- '---\ntype: job-result\nstage: implement\nplan: 1\nattempt: 1\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---' "$J" "$B" "$J")" "job sync: 머리 글과 키의 차례"
assert_eq "$(tail -c 2 "$W/$R" | od -An -c | tr -d ' ')" '\n\n' "job sync: 머리 뒤에 빈 줄 하나"

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
printf -- '- Task 4: complete (commits 5555555..6666666, review clean)\n' >> "$T/ledger.md"
assert_eq "$(sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "1" "job sync: 끝난 파일은 고치지 않는다"
assert_contains "$(cat "$T/out.txt")" "끝난 결과 파일은 고치지 않는다" "job sync: 끝난 파일 거절 사유"
cmp -s "$W/$R" "$T/closed.md" && ok "job sync: 거절하면 바이트 그대로" || no "job sync: 끝난 파일을 바꿨다"
assert_eq "$(sync E1 implement-plan-1-1.md --end "$(g rev-parse HEAD~1)")" "1" "job sync: 끝난 파일에 다른 끝은 거절"
cmp -s "$W/$R" "$T/closed.md" && ok "job sync: 다른 끝을 거절해도 바이트 그대로" || no "job sync: 다른 끝이 끝난 파일을 바꿨다"

# ── 거절 · 사용법 ────────────────────────────────────────────────────────────
A="implement-plan-1-2.md"
assert_eq "$(sync E1 "$A" --role worker --bundle-at "$B" --job-at "$J")" "0" "거절 준비: 시도 2 의 결과 파일"
sed 's/^attempt: 2$/attempt: 1/' "$W/$TM/jobs/E1/results/$A" > "$T/skew.md"; cp "$T/skew.md" "$W/$TM/jobs/E1/results/$A"
assert_eq "$(sync E1 "$A" --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "1" "거절: 이름과 머리가 어긋난다"
assert_contains "$(cat "$T/out.txt")" "이름" "거절: 어긋남 사유가 이름을 댄다"
cmp -s "$W/$TM/jobs/E1/results/$A" "$T/skew.md" && ok "거절: 어긋난 파일은 바이트 그대로" || no "거절: 어긋난 파일을 바꿨다"
assert_eq "$(raw "$TM/jobs/E1/implement-plan-1-3.md" --role worker --bundle-at "$B" --job-at "$J")" "1" "거절: 결과 폴더 밖 경로"
[ ! -e "$W/$TM/jobs/E1/implement-plan-1-3.md" ] && ok "거절: 결과 폴더 밖에 파일을 만들지 않는다" || no "거절: 결과 폴더 밖에 파일이 생겼다"
assert_eq "$(sync E1 BLOCKED.md --role worker --bundle-at "$B" --job-at "$J")" "1" "거절: 결과 파일 이름 꼴이 아니다(BLOCKED.md)"
[ ! -e "$W/$TM/jobs/E1/results/BLOCKED.md" ] && ok "거절: 막힘 파일 자리에 만들지 않는다" || no "거절: 막힘 파일 자리에 파일이 생겼다"
assert_eq "$(sync E1 design-plan-1-1.md --role worker --bundle-at "$B" --job-at "$J")" "1" "거절: design 이름에 계획 번호"
mkdir -p "$W/${RD}old/jobs/E9/results"
printf -- '---\ntype: roadmap\n---\n\n# 옛 형식\n' > "$W/${RD}old/roadmap.md"
assert_eq "$(raw "${RD}old/jobs/E9/results/implement-1.md" --role worker --bundle-at "$B" --job-at "$J")" "1" "거절: team 형식이 아닌 로드맵의 폴더"
[ ! -e "$W/${RD}old/jobs/E9/results/implement-1.md" ] && ok "거절: 옛 형식 폴더에 파일을 만들지 않는다" || no "거절: 옛 형식 폴더에 파일이 생겼다"
mkdir -p "$W/${RD}norm/jobs/E9/results"
assert_eq "$(raw "${RD}norm/jobs/E9/results/implement-1.md" --role worker --bundle-at "$B" --job-at "$J")" "1" "거절: 로드맵 파일이 없는 폴더"
assert_eq "$(sync NOPE implement-1.md --role worker --bundle-at "$B" --job-at "$J")" "1" "거절: 과제 폴더가 없다"
[ ! -e "$W/$TM/jobs/NOPE" ] && ok "거절: 없는 과제 폴더를 만들지 않는다" || no "거절: 없는 과제 폴더가 생겼다"
ln -s "$W/$TM/jobs/E1/results/$A" "$W/$TM/jobs/E1/results/implement-plan-1-4.md"
assert_eq "$(sync E1 implement-plan-1-4.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "1" "거절: 결과 파일이 심볼릭 링크"
printf '머리가 없는 글\n' > "$W/$TM/jobs/E1/results/implement-plan-1-5.md"
assert_eq "$(sync E1 implement-plan-1-5.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "1" "거절: 읽히지 않는 결과 파일"
assert_eq "$(cat "$W/$TM/jobs/E1/results/implement-plan-1-5.md")" "머리가 없는 글" "거절: 읽히지 않는 파일은 바이트 그대로"
assert_eq "$(sync E1 implement-2.md --ledger "$T/ledger.md")" "2" "사용법: --ledger 만 주면 2"
assert_eq "$(sync E1 implement-2.md --plan-file "$T/plan.md")" "2" "사용법: --plan-file 만 주면 2"
assert_eq "$(sync E1 implement-2.md --role worker --bundle-at "$B" --job-at "$J" --end abc1234)" "2" "사용법: 짧은 커밋 번호는 2"
assert_eq "$(sync E1 implement-2.md --role reviewer --bundle-at "$B" --job-at "$J")" "2" "사용법: 역할 이름이 아니면 2"
assert_eq "$(sync E1 implement-2.md --role worker --bundle-at abc1234 --job-at "$J")" "2" "사용법: 짧은 --bundle-at 은 2"
[ ! -e "$W/$TM/jobs/E1/results/implement-2.md" ] && ok "사용법 오류는 파일을 만들지 않는다" || no "사용법 오류인데 파일이 생겼다"

# ── place 문장 (AC17) ────────────────────────────────────────────────────────
place() { (cd "$W" && python3 "$WSP" place --root "$W" "$@") > "$T/place.txt" 2>&1; echo $?; }
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage design)" "0" "place: design rc 0"
assert_eq "$(cat "$T/place.txt")" "사용자 선호: 설계문서는 기본 자리 대신 $TM/jobs/E1/design.md 에 쓴다." "place: 설계문서 문장"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage plan --plan 2)" "0" "place: plan rc 0"
assert_eq "$(cat "$T/place.txt")" "사용자 선호: 계획은 기본 자리 대신 $TM/jobs/E1/plan-2.md 에 쓴다." "place: 계획 문장"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage plan)" "2" "place: plan 단계에 --plan 이 없으면 2"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage plan --plan 0)" "2" "place: 계획 번호 0 은 2"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job E1 --stage implement)" "2" "place: 다른 단계는 2"
assert_eq "$(place --roadmap docs/not-a-roadmap.md --job E1 --stage design)" "2" "place: 로드맵 자리가 아니면 2"
assert_eq "$(place --roadmap "$TM/roadmap.md" --job "../x" --stage design)" "2" "place: 과제 이름 꼴이 아니면 2"
assert_eq "$( (cd "$T" && python3 "$WSP" place --root "$T/no-such-dir" --roadmap "$TM/roadmap.md" --job E1 --stage design) >/dev/null 2>&1; echo $?)" "3" "place: 레포 설정을 못 읽으면 3"

finish
