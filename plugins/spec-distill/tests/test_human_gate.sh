#!/usr/bin/env bash
# start_bundle.py 의 관문 — 관문 표가 정한 사람 줄이 대조 판정을 지나지 못하면 묶음을 내지 않는다(종료 코드 1 · 표준 출력 빔). AC9 · AC12 · AC20.
# 줄 묶음마다 자기 레포를 세운다 — 앞 묶음의 브랜치 · 설정이 뒤 묶음으로 새지 않는다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_human_gate.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T0="$(mktemp -d)" || exit 1
[ -n "$T0" ] && [ -d "$T0" ] || exit 1
trap 'chmod -R u+rwX "$T0" 2>/dev/null; rm -rf "$T0"' EXIT
T="$T0"
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"

err() { cat "$T/b.err"; }
push_main() { g push -q origin main && g fetch -q origin; }
push_br() { g push -q origin "$1" && g fetch -q origin; }
short() { printf '%s' "$1" | cut -c1-8; }
SPECL="spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」"

# ── 묶음 A — 설계 흐름(E1)과 설계 없는 흐름(E2) ──
new_repo "$T0/a" && ok "A: 팀 레포를 세웠다(${TM})" || { no "A: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
E1="$TM/jobs/E1"
E2="$TM/jobs/E2"
E3="$TM/jobs/E3"
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "$(printf '# 설계\n\n본문 하나\n\n## 미룸\n\n- 미룬 것 하나\n')"
g commit -qm "E1 설계" && push_br feature/tm-e1
PRE="$(g rev-parse HEAD)"

check 0 "1: design 단계는 관문이 없다" --job E1 --stage design
check 1 "2: 승인 줄이 없으면 plan 묶음이 멈춘다" --job E1 --stage plan --plan 1
assert_eq "$(err | wc -l | tr -d ' ')" "1" "2: 표준 오류는 한 줄이다"
assert_contains "$(err)" "멈춤 — " "2: 멈춤 머리"
assert_contains "$(err)" '`spec 승인` 줄이 없다' "2: 어느 줄이 없는지"
assert_contains "$(err)" "record --human" "2: 적는 길"

decide E1 "$SPECL" && g add -- "$E1/INTENT.md" && g commit -qm "손으로 적은 spec 승인" && push_br feature/tm-e1
check 1 "3: 손으로 적은 줄은 근거 없음" --job E1 --stage plan --plan 1
assert_contains "$(err)" "근거 없음" "3: 사유에 근거 없음"

assert_eq "$(human "spec 승인" E1 - - 2026-11-20)" "0" "4: 준비 — 줄을 작업 폴더에만 적었다"
check 1 "4: 커밋하지 않은 줄은 관문이 읽지 않는다" --job E1 --stage plan --plan 1

g add -- "$E1/INTENT.md" && g commit -qm "spec 승인 — E1" && push_br feature/tm-e1
check 0 "5: 커밋해 올리면 plan 묶음이 나간다" --job E1 --stage plan --plan 1
assert_eq "$(sed -n 1p "$T/b.txt" | cut -c1-7)" "기준 커밋: " "5: 양성 대조 — 묶음 첫 줄"

put "$E1/plan-1.md" "E1 계획 한 줄" && g commit -qm "E1 계획 1" && push_br feature/tm-e1
check 1 "6: 계획 검토 줄이 없으면 implement 가 멈춘다" --job E1 --stage implement --plan 1
assert_contains "$(err)" '`계획 검토` 줄' "6: 어느 줄이 없는지"
assert_contains "$(err)" "계획 1" "6: 어느 계획인지"

approved "계획 검토" E1 1 - 2026-11-21 && push_br feature/tm-e1
check 0 "7: 계획 검토 줄이 있으면 implement 가 나간다" --job E1 --stage implement --plan 1
check 0 "7: review 도 나간다" --job E1 --stage review --plan 1

mv "$CLAUDE_CONFIG_DIR" "$T/claude.away"
check 1 "8: 세션 기록이 없으면 확인 못 함으로 멈춘다" --job E1 --stage implement --plan 1
assert_contains "$(err)" "확인 못 함" "8: 사유에 확인 못 함"
assert_contains "$(err)" "다시 승인받는다" "8: 다시 승인받는 길"
mv "$T/claude.away" "$CLAUDE_CONFIG_DIR"
check 0 "8: 기록을 되돌리면 다시 나간다(양성 대조)" --job E1 --stage implement --plan 1

python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read(); assert "본문 하나" in s; open(p, "w", encoding="utf-8", newline="").write(s.replace("본문 하나", "본문 둘", 1))' "$W/$E1/design.md"
g add -- "$E1/design.md" && g commit -qm "E1 설계 본문 고침" && push_br feature/tm-e1
check 1 "9: 승인 뒤 설계 본문이 바뀌면 낡음" --job E1 --stage implement --plan 1
assert_contains "$(err)" "낡음" "9: 사유에 낡음"

g revert --no-edit HEAD >/dev/null && push_br feature/tm-e1
check 0 "10: 본문이 승인한 판과 같아지면 다시 나간다" --job E1 --stage implement --plan 1

python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read(); assert "미룬 것 하나" in s; open(p, "w", encoding="utf-8", newline="").write(s.replace("미룬 것 하나", "미룬 것 둘", 1))' "$W/$E1/design.md"
g add -- "$E1/design.md" && g commit -qm "E1 설계 미룸 고침" && push_br feature/tm-e1
check 0 "11: 미룸 절만 바뀌면 낡지 않는다" --job E1 --stage implement --plan 1

g checkout -q -b feature/tm-e1b "$PRE"
put "$E1/plan-2.md" "E1 계획 둘" && g commit -qm "E1 계획 2" && push_br feature/tm-e1b
check 0 "12: 승인 줄이 다른 브랜치 끝에만 있어도 모아 읽는다(AC9)" --job E1 --stage plan --plan 2
check 1 "13: 계획 1 의 확인 줄은 계획 2 를 열지 않는다" --job E1 --stage implement --plan 2
assert_contains "$(err)" "계획 2" "13: 어느 계획인지"

approved "걸음 건너뜀" E1 - "계획 검토 plan 2" 2026-11-22 && push_br feature/tm-e1b
check 0 "14: 계획 2 의 건너뜀 줄이 그 관문을 푼다(AC12)" --job E1 --stage implement --plan 2
check 0 "14: 계획 1 은 그대로 나간다" --job E1 --stage implement --plan 1

if ! g merge -q --no-edit feature/tm-e1 >/dev/null 2>&1; then   # 두 끝이 결정 기록 끝에 서로 다른 줄을 더해 겹친다 — 두 줄을 다 남긴다
  python3 - "$W/$E1/INTENT.md" <<'PY'
import sys
p = sys.argv[1]
out = [l for l in open(p, encoding="utf-8", newline="").read().split("\n") if not l.startswith(("<<<<<<<", "=======", ">>>>>>>"))]
open(p, "w", encoding="utf-8", newline="").write("\n".join(out))
PY
  g add -- "$E1/INTENT.md" && g commit -qm "합침" -q
fi
push_br feature/tm-e1b
assert_eq "$(g grep -c '^- spec 승인 · ' feature/tm-e1b -- "$E1/INTENT.md" | sed 's/.*://')" "2" "14b: 준비 — 합친 끝에 spec 승인 줄이 둘(손 · 기록)이다"
check 0 "14b: 같은 줄이 여러 끝에 있어도 plan 2 가 나간다" --job E1 --stage plan --plan 2
check 0 "14b: implement 2 가 나간다" --job E1 --stage implement --plan 2
check 0 "14b: implement 1 이 나간다" --job E1 --stage implement --plan 1

g checkout -q -b feature/tm-e2 main && push_br feature/tm-e2
check 1 "15: 설계 없는 흐름은 흐름 승인이 없으면 멈춘다" --job E2 --stage implement
assert_contains "$(err)" '`흐름 승인` 줄이 없다' "15: 사유"
approved "흐름 승인" E2 - - 2026-11-22 && push_br feature/tm-e2
check 0 "16: 흐름 승인 줄이 있으면 나간다" --job E2 --stage implement
g checkout -q main

# ── 묶음 B — 관문을 끄는 길(E3 는 이 레포에서 처음 브랜치를 갖는다) ──
new_repo "$T0/b" && ok "B: 팀 레포를 세웠다" || { no "B: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
g checkout -q -b feature/tm-e3 main
put "$E3/design.md" "E3 설계 한 줄"
decide E3 "$SPECL"
g add -- "$E3/INTENT.md" && g commit -qm "E3 설계 · 손으로 적은 줄" && push_br feature/tm-e3
g checkout -q main
printf '%s\n' '---' 'human_gate: 끔' '---' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "관문 끔" && push_main
check 0 "17: human_gate 끔이면 손으로 적은 줄로 나간다" --job E3 --stage plan --plan 1
assert_eq "$(sed -n 2p "$T/b.txt")" "알림: 사람 줄 대조가 꺼져 있다" "17: 묶음 둘째 줄이 꺼짐 알림이다(AC20)"
g revert --no-edit HEAD >/dev/null && push_main
check 1 "18: 설정을 되돌리면 같은 묶음이 멈춘다(양성 대조)" --job E3 --stage plan --plan 1
assert_not_contains "$(sed -n 1,3p "$T/b.txt")" "알림: 사람 줄 대조가 꺼져 있다" "18: 꺼짐 알림도 없다"
printf '%s\n' '---' 'human_gate: 켬' 'rules_budget: 40000' '---' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "관문 켬 · 다른 키" && push_main
check 1 "19: 다른 설정 키가 있어도 관문은 그대로 막는다" --job E3 --stage plan --plan 1
assert_contains "$(err)" '`spec 승인` 줄이' "19: 사유는 그 관문의 것이다"
g revert --no-edit HEAD >/dev/null && push_main
DEVBREW_SPEC_DISTILL_GATE=off DEVBREW_HUMAN_GATE=끔 human_gate=끔 check 1 "19: 환경 변수로는 관문이 꺼지지 않는다" --job E3 --stage plan --plan 1

use_repo "$T0/a"
finish
