#!/usr/bin/env bash
# walk_table.py next — 걸음 보기가 자취로 지금 걸음을 고르고 다음 걸음의 칸 · 막는 것을 낸다. AC2 · AC9 · AC17.
# 줄 묶음 A 는 레포 하나를 세워 차례로 걷고(앞 행의 상태 위에서 다음 행), 줄 묶음 B 는 새 레포에서 막지 않는 쪽과 그 양성 대조를 잰다. 줄 묶음 C 는 모두 머지된 블록의 끝 걸음을 잰다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_walk_next.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T0="$(mktemp -d)" || exit 1
[ -n "$T0" ] && [ -d "$T0" ] || exit 1
trap 'chmod -R u+rwX "$T0" 2>/dev/null; rm -rf "$T0"' EXIT
T="$T0"
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"

wn() { (cd "$W" && python3 "$S/walk_table.py" next --roadmap "$RM" "$@") > "$T/w.txt" 2> "$T/w.err"; echo $?; }
line() { sed -n "s/^$1: //p" "$T/w.txt"; }
starts() {  # starts <글> <앞머리> <메시지>
  case "$1" in "$2"*) ok "$3" ;; *) no "$3 — 받은 것: $1" ;; esac
}
empty_out() { assert_eq "$(wc -c < "$T/w.txt" | tr -d ' ')" "0" "$1 — 표준 출력이 비었다"; }
DESIGN="$(printf '# 설계\n\n본문 하나\n\n## Acceptance Criteria\n\n- AC1: 자리표시\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| 미룬 것 하나 | 이유 하나 | #12 |\n')"   # 결과 대조가 받는 설계 — 수용 기준 절과 미룸 표
no_conf() { KEEP_CONF="$CLAUDE_CONFIG_DIR" && mkdir -p "$T/claude-empty" && export CLAUDE_CONFIG_DIR="$T/claude-empty"; }   # 세션 기록이 없는 설정 폴더로 — back_conf 로 되돌린다
back_conf() { export CLAUDE_CONFIG_DIR="$KEEP_CONF"; }

# ── 줄 묶음 A — 설계 흐름(E1 · E3)과 설계 없는 흐름(E2) ──
repo_copy "$T0/a" new && ok "A: 팀 레포를 세웠다(${TM})" || { no "A: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
E1="$TM/jobs/E1"

assert_eq "$(wn --job E1)" "0" "w1: 브랜치가 없어도 0"
assert_eq "$(line 표)" "플러그인 기본 표" "w1: 표 출처"
assert_eq "$(line 흐름)" "설계 흐름 · 계획 1/2" "w1: 흐름 · 계획 1/2"
assert_eq "$(line '지금 걸음')" "방향 확인" "w1: 지금 걸음"
assert_eq "$(line '다음 걸음')" "설계 대화 — 누가 사람 · leader · 작업 방식 superpowers:brainstorming · 상한 — · 도구 —" "w1: 다음 걸음과 그 칸"
assert_eq "$(line '막는 것')" "없음" "w1: 막는 것 없음"
case "$(sed -n 1p "$T/w.txt")" in "알림:"*) no "w1: 첫 줄이 알림이 아니다" ;; "") no "w1: 첫 줄이 있다" ;; *) ok "w1: 첫 줄이 알림이 아니다" ;; esac

g checkout -q -b feature/tm-e1 main && g commit -q --allow-empty -m "E1 시작" && push_br feature/tm-e1
assert_eq "$(wn --job E1)" "0" "w2: 0"
assert_eq "$(line '지금 걸음')" "설계 대화" "w2: 브랜치만 있으면 설계 대화"

put "$E1/design.md" "$DESIGN"
g commit -qm "E1 설계" && push_br feature/tm-e1
assert_eq "$(wn --job E1)" "0" "w3: 0"
assert_eq "$(line '지금 걸음')" "설계 검토 · 설계 승인" "w3: 가를 수 없는 두 걸음을 묶는다"
starts "$(line '다음 걸음')" "계획 — 누가 worker" "w3: 다음 걸음은 계획"
assert_contains "$(line '막는 것')" '`spec 승인`' "w3: 막는 것은 spec 승인 줄"

approved "spec 승인" E1 && push_br feature/tm-e1
assert_eq "$(wn --job E1)" "0" "w4: 0"
assert_eq "$(line '지금 걸음')" "설계 승인 (끝남)" "w4: 관문을 지난 자리는 끝남"
starts "$(line '다음 걸음')" "계획 — 누가 worker · 작업 방식 superpowers:writing-plans" "w4: 담당자 걸음은 다음 걸음"
assert_eq "$(line '막는 것')" "없음" "w4: 막는 것 없음"

no_conf
assert_eq "$(wn --job E1)" "0" "w4b: 세션 기록이 없어도 0"
assert_eq "$(line '막는 것')" "없음" "w4b: 꼴 판정 — 세션 기록을 읽지 않는다"
back_conf

put "$E1/plan-1.md" "$(printf '# 계획\n\n### Task 1: 자리표시\n\nAC1 을 만든다.\n')"
g commit -qm "E1 계획 1" && push_br feature/tm-e1
assert_eq "$(wn --job E1)" "0" "w5: 0"
assert_eq "$(line '지금 걸음')" "계획 확인" "w5: 계획 파일이 있고 계획 검토 줄이 없으면 계획 확인"
starts "$(line '다음 걸음')" "구현 — 누가 worker" "w5: 다음 걸음은 구현"
assert_contains "$(line '막는 것')" '`계획 검토`' "w5: 막는 것은 계획 검토 줄"

approved "계획 검토" E1 1 && push_br feature/tm-e1
assert_eq "$(wn --job E1)" "0" "w6: 0"
assert_eq "$(line '지금 걸음')" "계획 확인 (끝남)" "w6: 관문을 지난 자리는 끝남"
starts "$(line '다음 걸음')" "구현 — 누가 worker · 작업 방식 superpowers:subagent-driven-development" "w6: 담당자 걸음은 다음 걸음"
assert_eq "$(line '막는 것')" "없음" "w6: 막는 것 없음"
no_conf
assert_eq "$(wn --job E1)" "0" "w6c: 세션 기록이 없어도 0"
assert_eq "$(line '지금 걸음')" "계획 확인 (끝남)" "w6c: 계획 검토 줄의 지남은 꼴 판정 — 세션 기록을 읽지 않는다"
back_conf

finish_attempt 1 "AC1: 구현됨 — 자리표시" && ok "w6b: 준비 — 시도 1 을 끝냈다(받음 줄 없음)" || no "w6b: 준비 — 시도 1"
assert_eq "$(wn --job E1)" "0" "w6b: 0"
assert_eq "$(line '지금 걸음')" "구현" "w6b: 구현 중"
assert_eq "$(line '다음 걸음')" "검수 — 누가 leader · 작업 방식 — · 상한 — · 도구 spec-distill:integration-reviewer · quality-gates:quality-pipeline" "w6b: 다음 걸음은 검수"

assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md)" "0" "w7: 준비 — 결과 대조가 통과한다 $(cat "$T/c.txt")"
RLINE="$(grep '^- 결과 받음 · ' "$T/c.txt")"
assert_eq "$(led record --spec "$E1/INTENT.md" --line "$RLINE")" "0" "w7: 준비 — 받음 줄을 적었다"
g add -- "$E1/INTENT.md" && g commit -qm "받음 줄 — 시도 1" && push_br feature/tm-e1
assert_eq "$(wn --job E1)" "0" "w7: 0"
assert_eq "$(line '지금 걸음')" "검수 · PR 전 확인" "w7: 구현 끝 · 열린 PR 없음"
starts "$(line '다음 걸음')" "머지 — 누가 사람" "w7: 다음 걸음은 머지"

TIP1="$(g rev-parse feature/tm-e1)"
assert_eq "$(led add --roadmap "$RM" --session "$SID" --section PR --cells "feature/tm-e1 · #1 · 열림 · 2026-11-20T00:00:00Z · ${TIP1} · 아니오 · main · - · ${SID}")" "0" \
  "w8: 준비 — PR 캐시에 열림 줄 $(cat "$T/led.txt")"
assert_eq "$(wn --job E1)" "0" "w8: 0"
assert_eq "$(line '지금 걸음')" "머지" "w8: PR 이 열렸으면 머지"
starts "$(line '다음 걸음')" "계획 (계획 2)" "w8: 다음 걸음은 다음 계획"
MACHINE="$(find "$W/.claude" -name machine.md 2>/dev/null | head -1)"
assert_eq "$([ -f "$MACHINE" ] && echo 있음)" "있음" "w8b: 준비 — 지휘 기계 상태 파일이 있다"
cp "$MACHINE" "$T/machine.keep" && printf 'broken\n' >> "$MACHINE"
assert_eq "$(wn --job E1)" "3" "w8b: PR 캐시를 읽지 못하면 3(K5 — 열리지 않은 것으로 보지 않는다)"
empty_out "w8b"
assert_contains "$(cat "$T/w.err")" "기계 상태를 읽지 못했다" "w8b: 사유는 상태 계산의 PR 캐시 사유"
cp "$T/machine.keep" "$MACHINE"
assert_eq "$(wn --job E1) · $(line '지금 걸음')" "0 · 머지" "w8b: 되돌리면 다시 머지(양성 대조)"

g checkout -q main && g merge -q --no-ff -m "E1 계획 1 합침" feature/tm-e1 && push_main
status "$T/s.json" > /dev/null
assert_eq "$(js "$T/s.json" "[b['stage'] for b in r['blocks'] if b['id'] == 'E1'][0]")" "일부 머지 1/2" "w9: 전제 — 상태 보고가 E1 을 일부 머지 1/2 로 센다"
assert_eq "$(wn --job E1)" "0" "w9: 0"
assert_eq "$(line 흐름)" "설계 흐름 · 계획 1/2" "w9: 계획 1/2"
assert_eq "$(line '지금 걸음')" "머지 (계획 1 — 끝남)" "w9: 계획 1 이 머지됐다"
starts "$(line '다음 걸음')" "계획 (계획 2) — 누가 worker" "w9: 다음 걸음은 계획 2 의 계획"

g checkout -q -b feature/tm-e1b main && g commit -q --allow-empty -m "E1 계획 2 시작" && push_br feature/tm-e1b
assert_eq "$(wn --job E1)" "0" "w9b: 0"
assert_eq "$(line 흐름)" "설계 흐름 · 계획 2/2" "w9b: 계획 2 의 브랜치에 끝이 생기면 계획 2/2"
assert_eq "$(line '지금 걸음')" "머지 (계획 1 — 끝남)" "w9b: 계획 2 파일이 없으면 지금 걸음은 앞 계획의 머지"
starts "$(line '다음 걸음')" "계획 (계획 2) — 누가 worker" "w9b: 다음 걸음은 계획 2 의 계획"
assert_eq "$(line '막는 것')" "없음" "w9b: 막는 것 없음"
g checkout -q main

assert_eq "$(wn --job E3)" "0" "w10: 0"
assert_eq "$(line '지금 걸음')" "방향 확인" "w10: 브랜치 없는 대기"
assert_contains "$(line '막는 것')" "의존 미완료" "w10: 막는 것은 의존 미완료"

assert_eq "$(wn --job E2)" "0" "w11: 0"
assert_eq "$(line 흐름)" "설계 없는 흐름" "w11: 설계 없는 흐름 · 계획 수 없음"
assert_eq "$(line '지금 걸음')" "방향 확인" "w11: 지금 걸음"
starts "$(line '다음 걸음')" "진행 — 누가 worker" "w11: 다음 걸음은 진행"
assert_contains "$(line '막는 것')" '`흐름 승인`' "w11: 막는 것은 흐름 승인 줄"

g checkout -q -b feature/tm-e2 main && push_br feature/tm-e2
approved "흐름 승인" E2 && push_br feature/tm-e2
assert_eq "$(wn --job E2)" "0" "w12: 0"
assert_eq "$(line '지금 걸음')" "방향 확인 (끝남)" "w12: 관문을 지난 자리는 끝남"
starts "$(line '다음 걸음')" "진행 — 누가 worker" "w12: 담당자 걸음은 다음 걸음"
assert_eq "$(line '막는 것')" "없음" "w12: 막는 것 없음"
no_conf
assert_eq "$(wn --job E2)" "0" "w12b: 세션 기록이 없어도 0"
assert_eq "$(line '지금 걸음')" "방향 확인 (끝남)" "w12b: 흐름 승인 줄의 지남은 꼴 판정 — 세션 기록을 읽지 않는다"
back_conf

g checkout -q main
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read(); old="- 브랜치: feature/tm-e2\n"; assert s.count(old) == 1; open(p, "w", encoding="utf-8", newline="").write(s.replace(old, "- 브랜치: feature/tm-e2, feature/tm-e2b\n"))' "$W/$RM" \
  && g add -- "$RM" && g commit -qm "E2 에 둘째 브랜치" && g merge -q --no-ff -m "E2 첫 브랜치 합침" feature/tm-e2 && push_main
status "$T/s.json" > /dev/null
assert_eq "$(js "$T/s.json" "[b['stage'] for b in r['blocks'] if b['id'] == 'E2'][0]")" "일부 머지 1/2" "w13: 전제 — 상태 보고가 E2 를 일부 머지 1/2 로 센다"
assert_eq "$(wn --job E2)" "3" "w13: 설계 없는 흐름의 일부 머지 · 다음 브랜치 없음은 3(가를 수 없다)"
empty_out "w13"

# ── 줄 묶음 B — 레포 표 · 꺼짐 · 갈라짐 · 사용법 · 로드맵 밖 과제 ──
repo_copy "$T0/b" new && ok "B: 팀 레포를 세웠다" || { no "B: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
E1="$TM/jobs/E1"
mkdir -p "$W/docs"
sed -e 's/| spec 승인 |/| — |/' -e 's/| 계획 검토 |/| — |/' -e 's/| 흐름 승인 |/| — |/' -e 's/^| 계획 | worker | plan |/| 계획 | worker | — |/' \
  "$ROOT/plugins/spec-distill/references/walk-table.md" \
  | awk '{ print } /^\| 설계 승인 \|/ { print "| 디자인 확인 | 사람 | — | — | — | — | — |" }' > "$W/docs/walk.md"
assert_eq "$(grep -c '^| 디자인 확인 |' "$W/docs/walk.md")" "1" "b1: 준비 — 레포 표에 설계 승인 뒤 기본 이름이 아닌 행 하나"
assert_eq "$(grep -c '| spec 승인 |\|| 계획 검토 |\|| 흐름 승인 |\|| plan |' "$W/docs/walk.md")" "0" "b1: 준비 — 레포 표의 관문 칸과 계획의 단계 칸이 비었다"
printf '%s\n' '---' 'walk_table: docs/walk.md' '---' > "$W/.devbrew.md"
g add -- .devbrew.md docs/walk.md && g commit -qm "레포 걸음표" && push_main
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "$DESIGN"
g commit -qm "E1 설계" && push_br feature/tm-e1
assert_eq "$(wn --job E1)" "0" "b1: 0"
starts "$(line 표)" "레포 설정 walk_table: docs/walk.md@" "b1: 레포 표를 읽었다"
assert_contains "$(line '막는 것')" '`spec 승인`' "b1: 막는 것은 표의 관문 · 단계 칸에서 읽지 않는다(AC9)"
assert_eq "$(line '지금 걸음')" "설계 검토 · 설계 승인 · 디자인 확인" "b1: 레포가 더한 행은 앞 닻의 묶음에 붙는다(K4)"
assert_eq "$(bundle --job E1 --stage plan --plan 1)" "1" "b2: 레포 표가 관문을 비워도 시작 묶음은 멈춘다(AC9)"
assert_eq "$(wc -c < "$T/b.txt" | tr -d ' ')" "0" "b2: 표준 출력이 비었다"
assert_eq "$( (cd "$W" && python3 "$S/walk_table.py" check) > "$T/k.txt" 2>&1; echo $?)" "0" "b3: 레포 표 검사는 0 $(cat "$T/k.txt")"

approved "spec 승인" E1 && push_br feature/tm-e1
assert_eq "$(wn --job E1)" "0" "b3b: 0"
assert_eq "$(line '지금 걸음')" "설계 승인 (끝남) · 디자인 확인" "b3b: 끝난 닻 뒤의 더한 행도 묶음에 붙는다(K4)"

g checkout -q main
grep -v '^| 설계 승인 |' "$W/docs/walk.md" > "$T/walk.md" && cp "$T/walk.md" "$W/docs/walk.md"
g add -- docs/walk.md && g commit -qm "설계 승인 행을 지운 걸음표" && push_main
assert_eq "$(wn --job E1)" "3" "b3c: 지금 걸음의 닻 이름이 레포 표에 없으면 3(K4)"
empty_out "b3c"
assert_contains "$(cat "$T/w.err")" "걸음표에 설계 승인 걸음이 없어 지금 걸음을 가를 수 없다" "b3c: 사유"

g checkout -q main
sed 's/^| 구현 | worker | implement |/| 구현 | worker | build |/' "$W/docs/walk.md" > "$T/walk.md" && cp "$T/walk.md" "$W/docs/walk.md"
g add -- docs/walk.md && g commit -qm "깨진 걸음표" && push_main
assert_eq "$(wn --job E1)" "3" "b4: 깨진 레포 표는 3"
empty_out "b4"
assert_contains "$(cat "$T/w.err")" "docs/walk.md:" "b4: 사유가 파일을 짚는다"
assert_contains "$(cat "$T/w.err")" "build" "b4: 사유가 틀린 값을 짚는다"

g rm -q -- docs/walk.md && g commit -qm "걸음표를 지운다" && push_main
assert_eq "$(wn --job E1)" "3" "b5: 표 파일이 기본 브랜치에 없으면 3"
assert_contains "$(cat "$T/w.err")" "기본 브랜치에 없다" "b5: 사유"

printf '%s\n' '---' 'human_gate: 끔' '---' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "관문 끔" && push_main
assert_eq "$(wn --job E1)" "0" "b6: 0"
assert_eq "$(sed -n 1p "$T/w.txt")" "알림: 사람 줄 대조가 꺼져 있다" "b6: 꺼짐 알림이 첫 줄"
assert_eq "$(line 표)" "플러그인 기본 표" "b6: 설정을 지우면 기본 표(양성 대조)"

g checkout -q feature/tm-e1 && put "$E1/note.md" "고침" && g commit -qm "올린 고침" && push_br feature/tm-e1
g commit -q --amend -m "갈라짐" && g checkout -q main
assert_eq "$(wn --job E1)" "3" "b7: 갈라진 브랜치는 3"
empty_out "b7"
assert_contains "$(cat "$T/w.err")" "갈라" "b7: 사유는 상태 계산의 갈라짐"

assert_eq "$(wn --job ZZ)" "2" "b8: 모르는 과제는 2"
empty_out "b8"
assert_eq "$(wn)" "2" "b8: --job 이 없으면 2"
empty_out "b8 인자 없음"

put "${RD}old/roadmap.md" "$(printf -- '---\ntype: roadmap\n---\n\n# 옛 로드맵\n')"
g commit -qm "옛 형식 로드맵" && push_main
assert_eq "$( (cd "$W" && python3 "$S/walk_table.py" next --roadmap "${RD}old/roadmap.md" --job A1) > "$T/w.txt" 2> "$T/w.err"; echo $?)" "2" "b9: 옛 형식 로드맵은 2"
empty_out "b9"
assert_contains "$(cat "$T/w.err")" "team 형식" "b9: 사유"

g checkout -q -b fix/typo main
printf '로드맵에 없는 일 하나 — fix-typo\n' > "$T/said.txt"
(cd "$W" && python3 "$RW" job new --roadmap "$RM" --name fix-typo --branch fix/typo --paths docs/a.md --goal "오타 고치기" < "$T/said.txt") > "$T/out.txt" 2>&1 \
  && g add -- "$TM/jobs/fix-typo" && g commit -qm "과제 폴더 fix-typo" && push_br fix/typo && ok "b10: 준비 — 로드맵 밖 과제" || no "b10: 준비 — $(cat "$T/out.txt")"
g checkout -q main
assert_eq "$(wn --job fix-typo)" "0" "b10: 로드맵 밖 과제는 0 $(cat "$T/w.err")"
assert_eq "$(line 흐름)" "설계 없는 흐름" "b10: 설계 없는 흐름"
assert_eq "$(line '지금 걸음')" "방향 확인" "b10: 흐름 승인 줄이 없으면 방향 확인"

# ── 줄 묶음 C — 모두 머지: 로드맵 결정 기록의 머지 줄이 블록을 머지됨으로 두면 브랜치 끝이 남아 있어도 끝 걸음이다 ──
repo_copy "$T0/c" new && ok "C: 팀 레포를 세웠다" || { no "C: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
for br in feature/tm-e3 feature/tm-e2; do
  g checkout -q -b "$br" main && g commit -q --allow-empty -m "$br 시작" && push_br "$br"
done
g checkout -q main
assert_eq "$(wn --job E3) · $(line '지금 걸음')" "0 · 설계 대화" "c1: 양성 대조 — 머지 줄이 없으면 남은 브랜치 끝으로 걷는다"
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read(); h="\n## 결정 기록\n"; assert s.count(h) == 1, "결정 기록 절이 하나가 아니다"; open(p, "w", encoding="utf-8", newline="").write(s.replace(h, h + "\n- E3 · 머지 · 2026-11-22 · 「squash 로 머지했다」\n- E2 · 머지 · 2026-11-22 · 「squash 로 머지했다」\n"))' "$W/$RM" \
  && g add -- "$RM" && g commit -qm "머지 줄 둘" && push_main && ok "c1: 준비 — 로드맵 결정 기록에 머지 줄 둘" || no "c1: 준비 — 머지 줄"
status "$T/s.json" > /dev/null
assert_eq "$(js "$T/s.json" "' · '.join(b['stage'] + ('/있음' if [s for s in b['branch_states'] if s.get('tip')] else '/없음') for b in r['blocks'] if b['id'] in ('E2', 'E3'))")" \
  "머지됨/있음 · 머지됨/있음" "c1: 전제 — 상태 보고가 E2 · E3 을 머지됨으로 세고 브랜치 끝은 남아 있다"
assert_eq "$(wn --job E3)" "0" "c1: 0"
assert_eq "$(line '지금 걸음') · $(line '다음 걸음')" "회고 · 없음" "c1: 설계 흐름의 모두 머지 — 회고 → 없음(남은 브랜치 끝을 세지 않는다)"
assert_eq "$(line '막는 것')" "없음" "c1: 막는 것 없음"
assert_eq "$(wn --job E2)" "0" "c2: 0"
assert_eq "$(line '지금 걸음') · $(line '다음 걸음')" "결과 확인 · 없음" "c2: 설계 없는 흐름의 모두 머지 — 결과 확인 → 없음"

finish
