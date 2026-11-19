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
case "$(sed -n 1p "$T/b.txt")" in "기준 커밋: "*) ok "5: 양성 대조 — 묶음 첫 줄" ;; *) no "5: 양성 대조 — 묶음 첫 줄" ;; esac

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
assert_eq "$(err | wc -l | tr -d ' ')" "1" "8: 닫힌 관문이 둘이어도 표준 오류는 한 줄이다(J18)"
assert_contains "$(err)" '`spec 승인`' "8: 첫 닫힌 관문(spec 승인)만 낸다(J18)"
assert_not_contains "$(err)" '`계획 검토`' "8: 둘째 관문의 사유는 싣지 않는다(J18)"
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
assert_contains "$(err)" "근거 없음" "18: 관문이 켜져 있어 손으로 적은 줄이 근거 없음으로 막힌다"
assert_not_contains "$(err)" "대조가 꺼져 있다" "18: 꺼짐 안내가 없다"
printf '%s\n' '---' 'human_gate: 켬' 'rules_budget: 40000' '---' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "관문 켬 · 다른 키" && push_main
check 1 "19: 다른 설정 키가 있어도 관문은 그대로 막는다" --job E3 --stage plan --plan 1
assert_contains "$(err)" '`spec 승인` 줄이' "19: 사유는 그 관문의 것이다"
g revert --no-edit HEAD >/dev/null && push_main
DEVBREW_SPEC_DISTILL_DISABLE=1 DEVBREW_SKIP_HOOKS=spec-distill:human-gate DEVBREW_SPEC_DISTILL_GATE=off DEVBREW_HUMAN_GATE=끔 human_gate=끔 check 1 "19: 환경 변수로는 관문이 꺼지지 않는다" --job E3 --stage plan --plan 1

# ── 묶음 C — 계획 n 의 브랜치가 아직 없다(team-files: 에픽의 첫 보내기는 늘 이 경우) ──
new_repo "$T0/c" && ok "C: 팀 레포를 세웠다" || { no "C: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "E1 설계 한 줄"
g commit -qm "E1 설계" && push_br feature/tm-e1
approved "spec 승인" E1 - - 2026-11-20 && push_br feature/tm-e1
check 1 "C1: 계획 1 이 머지되지 않았고 계획 2 의 브랜치가 없으면 멈춘다" --job E1 --stage plan --plan 2
assert_eq "$(err | wc -l | tr -d ' ')" "1" "C1: 표준 오류는 한 줄이다"
assert_contains "$(err)" "확인 못 함" "C1: 사유"
assert_contains "$(err)" "계획 2 의 브랜치 feature/tm-e1b 가 아직 없다: feature/tm-e1 의 끝에서 그 브랜치를 만들거나 앞 계획을 먼저 머지한 뒤 다시 부른다" "C1: 다음 할 일(브랜치 이름과 첫 브랜치)"
g checkout -q main && g merge -q --no-ff feature/tm-e1 -m "계획 1 머지" && push_main
check 0 "C2: 계획 1 이 머지돼 기준 커밋에 설계가 있으면 브랜치 없이도 묶음이 나간다" --job E1 --stage plan --plan 2
B="$(g rev-parse origin/main)"
assert_eq "$(sed -n 1p "$T/b.txt")" "기준 커밋: ${B} · 과제 브랜치 ${B}" "C2: 첫 줄은 기준 커밋 둘"
assert_eq "$(sed -n 2p "$T/b.txt")" "알림: 과제 브랜치 feature/tm-e1b 가 아직 없다 — 과제 폴더를 기준 커밋에서 읽었다" "C2: 둘째 브랜치 없음 알림"

# ── 묶음 D — 연속 실패 멈춤 · 머지된 계획(AC13 · AC14). 이 묶음의 E1 은 새 레포에서 설계 · 계획 · 승인을 갖춘다 ──
new_repo "$T0/d" && ok "D: 팀 레포를 세웠다" || { no "D: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "$(printf '# 설계\n\n본문 하나\n\n## Acceptance Criteria\n\n- AC1: 자리표시\n')"
g commit -qm "E1 설계" && push_br feature/tm-e1
approved "spec 승인" E1 - - 2026-11-20 && push_br feature/tm-e1
put "$E1/plan-1.md" "$(printf '# 계획\n\n### Task 1: 자리표시\n\nAC1 을 만든다.\n')"
g commit -qm "E1 계획 1" && push_br feature/tm-e1
approved "계획 검토" E1 1 - 2026-11-21 && push_br feature/tm-e1
D_IMPL=(--job E1 --stage implement --plan 1)

finish_attempt 1 && ok "20: 준비 — 시도 1 을 끝냈다(받음 줄 없음)" || no "20: 준비 — 시도 1"
check 0 "20: 실패 하나로는 멈추지 않는다" "${D_IMPL[@]}"
assert_eq "$(write_line)" "$E1/results/implement-plan-1-2.md" "20: 쓸 것은 시도 2"
put "$E1/results/BLOCKED.md" "$(printf -- '---\ntype: job-blocked\nhead: %s\n---\n\n## 무엇에 막혔나\n\n자리표시\n\n## 풀려면 무엇이 필요한가\n\n자리표시\n' "$(g rev-parse HEAD)")"
g commit -qm "막힘 파일" && push_br feature/tm-e1
check 0 "21: 실패 하나와 막힘 파일로는 멈추지 않는다(AC13 — 막힘을 세면 여기서 멈춘다)" "${D_IMPL[@]}"
assert_eq "$(write_line)" "$E1/results/implement-plan-1-2.md" "21: 쓸 것은 여전히 시도 2"
finish_attempt 2 && ok "22: 준비 — 시도 2 를 끝냈다(받음 줄 없음)" || no "22: 준비 — 시도 2"
check 1 "22: 이어진 실패 둘이면 멈춘다(AC13)" "${D_IMPL[@]}"
assert_contains "$(err)" "구현 시도 2번이 이어서 받아지지 않았다" "22: 이어진 수는 둘(막힘 파일을 세지 않는다)"
assert_not_contains "$(err)" "구현 시도 3번" "22: 막힘 파일이 수를 늘리지 않는다"
assert_contains "$(err)" "다시 시도 plan 1 시도 3" "22: 푸는 관문 이름은 시도 3"
check 0 "23: 계획 단계에는 이 멈춤이 없다" --job E1 --stage plan --plan 1
check 0 "23: 설계 단계에도 없다" --job E1 --stage design
approved "걸음 건너뜀" E1 - "다시 시도 plan 1 시도 3" 2026-11-23 && push_br feature/tm-e1
check 0 "24: 다시 시도 줄이 시도 3 을 푼다" "${D_IMPL[@]}"
assert_eq "$(write_line)" "$E1/results/implement-plan-1-3.md" "24: 쓸 것은 시도 3"
finish_attempt 3 && ok "25: 준비 — 시도 3 을 끝냈다(받음 줄 없음)" || no "25: 준비 — 시도 3"
check 1 "25: 그 줄은 시도 3 하나만 풀었다" "${D_IMPL[@]}"
assert_contains "$(err)" "다시 시도 plan 1 시도 4" "25: 다음 관문은 시도 4"
HEAD3="$(sed -n 's/^head: //p' "$W/$E1/results/implement-plan-1-3.md")"
decide E1 "- 결과 받음 · 2026-11-24 · 「implement-plan-1-3.md · ${HEAD3} · 결과 대조: 통과 — 자리표시」" && g add -- "$E1/INTENT.md" && g commit -qm "손으로 적은 받음 줄" && push_br feature/tm-e1
check 1 "26: 손으로 적은 받음 줄로는 멈춤이 풀리지 않는다(AC13 — 결과 파일이 대조를 지나지 못한다)" "${D_IMPL[@]}"
assert_contains "$(err)" "다시 시도 plan 1 시도 4" "26: 여전히 시도 4 의 관문"
approved "걸음 건너뜀" E1 - "다시 시도 plan 1 시도 4" 2026-11-24 && push_br feature/tm-e1
finish_attempt 4 "AC1: 구현됨 — 자리표시" && ok "27: 준비 — 시도 4 를 AC 줄과 함께 끝냈다" || no "27: 준비 — 시도 4"
(cd "$W" && python3 "$S/job_results.py" check --roadmap "$RM" --job E1 --result implement-plan-1-4.md --branch feature/tm-e1 --date 2026-11-25) > "$T/check.txt" 2>&1
assert_eq "$?" "0" "27: 시도 4 의 결과 대조가 통과한다"
RLINE="$(grep '^- 결과 받음 · ' "$T/check.txt")"
assert_eq "$(led record --spec "$E1/INTENT.md" --line "$RLINE")" "0" "27: 받음 줄을 record 로 적었다"
g add -- "$E1/INTENT.md" && g commit -qm "받음 줄 — 시도 4" && push_br feature/tm-e1
check 0 "27: 결과 대조를 지난 받음 줄이 이어짐을 끊는다(26 의 양성 대조)" "${D_IMPL[@]}"
assert_eq "$(write_line)" "$E1/results/implement-plan-1-5.md" "27: 쓸 것은 시도 5"
finish_attempt 5 && ok "27b: 준비 — 시도 5 를 AC 줄 없이 끝냈다" || no "27b: 준비 — 시도 5"
check 0 "27b: 시도 4 의 받음 줄은 더 새 시도 5 가 있어도 산 받음 줄이다 — 이어진 실패는 하나뿐이다" "${D_IMPL[@]}"
assert_eq "$(write_line)" "$E1/results/implement-plan-1-6.md" "27b: 쓸 것은 시도 6"
finish_attempt 6 && ok "27c: 준비 — 시도 6 을 AC 줄 없이 끝냈다" || no "27c: 준비 — 시도 6"
check 1 "27c: 시도 5 · 6 이 이어서 실패하면 다시 멈춘다" "${D_IMPL[@]}"
assert_contains "$(err)" "다시 시도 plan 1 시도 7" "27c: 푸는 관문은 시도 7"
hand_attempt() {  # hand_attempt <k> <덧붙일 줄> — 시도 6 의 결과 파일을 시도 k 로 베끼고 끝 줄 뒤에 그 줄을 덧붙여 올린다(모델이 손으로 쓴 파일)
  local k="$1" extra="$2" src="$W/$E1/results/implement-plan-1-6.md" dst="$W/$E1/results/implement-plan-1-$1.md"
  sed "s/^attempt: 6\$/attempt: ${k}/" "$src" > "$dst" && printf '%s\n' "$extra" >> "$dst" \
    && g add -- "$E1" && g commit -qm "손으로 쓴 시도 ${k}" && push_br feature/tm-e1
}
hand_attempt 7 "끝 — $(sed -n 's/^head: //p' "$W/$E1/results/implement-plan-1-6.md")" && ok "27d: 준비 — 끝 줄이 둘인 시도 7 을 손으로 썼다" || no "27d: 준비 — 시도 7"
check 1 "27d: 끝 줄이 둘인 끝난 시도는 실패로 센다 — 손으로 써도 멈춤이 풀리지 않는다(AC13)" "${D_IMPL[@]}"
assert_contains "$(err)" "다시 시도 plan 1 시도 8" "27d: 다음 관문은 시도 8"
hand_attempt 8 "AC1: 구현됨 — 끝 줄 뒤의 기계 줄" && ok "27e: 준비 — 끝 줄 뒤에 기계 줄이 있는 시도 8 을 손으로 썼다" || no "27e: 준비 — 시도 8"
check 1 "27e: 끝 줄 뒤의 기계 줄이 있는 시도도 실패로 센다(AC13)" "${D_IMPL[@]}"
assert_contains "$(err)" "다시 시도 plan 1 시도 9" "27e: 다음 관문은 시도 9"
sed -e 's/^attempt: 6$/attempt: 9/' -e '/^끝 — /d' "$W/$E1/results/implement-plan-1-6.md" > "$W/$E1/results/implement-plan-1-9.md" && printf '산출물:\n' >> "$W/$E1/results/implement-plan-1-9.md" \
  && g add -- "$E1" && g commit -qm "끝 줄을 지우고 빈 산출물 줄을 넣은 시도 9" && push_br feature/tm-e1 && ok "27e2: 준비 — 끝 줄을 지우고 빈 산출물 줄을 둔 시도 9 를 손으로 고쳤다" || no "27e2: 준비 — 시도 9"
check 1 "27e2: 끝 줄을 지우고 꼴 문제를 남겨도 멈춤이 풀리지 않는다(AC13 — 시작 묶음은 다음 번호를 낸다)" "${D_IMPL[@]}"
assert_contains "$(err)" "다시 시도 plan 1 시도 10" "27e2: 다음 관문은 시도 10"
approved "걸음 건너뜀" E1 - "다시 시도 plan 1 시도 10" 2026-11-26 && push_br feature/tm-e1
check 0 "27f: 사람의 다시 시도 줄은 그 시도를 푼다(27d · 27e · 27e2 의 양성 대조)" "${D_IMPL[@]}"
assert_eq "$(write_line)" "$E1/results/implement-plan-1-10.md" "27f: 쓸 것은 시도 10"

g checkout -q main && g merge -q --no-ff -m "E1 계획 1 합침" feature/tm-e1 && push_main
for stage in "implement --plan 1" "plan --plan 1" "review --plan 1" "design"; do
  # shellcheck disable=SC2086
  check 1 "28: 머지된 계획은 ${stage%% *} 단계도 멈춘다(AC14 · J30)" --job E1 --stage $stage
  assert_contains "$(err)" "이미 기본 브랜치에 머지됐다" "28: 사유(${stage%% *})"
  assert_not_contains "$(err)" "상태 보기는 이 브랜치를 머지로 세지 못한다" "28: 브랜치가 있으면 상태 보기의 머지 근거가 먼저다(${stage%% *})"
done
g branch -q -D feature/tm-e1 && g push -q origin --delete feature/tm-e1 && g fetch -q --prune origin
for stage in "implement --plan 1" "plan --plan 1" "review --plan 1" "design"; do
  # shellcheck disable=SC2086
  check 1 "29: 브랜치를 지워도 머지된 계획은 멈춘다(${stage%% *})" --job E1 --stage $stage
  assert_contains "$(err)" "이미 기본 브랜치에 머지됐다" "29: 사유(${stage%% *})"
  assert_contains "$(err)" "상태 보기는 이 브랜치를 머지로 세지 못한다" "29: 더한 갈래로 멈췄다(J11 — ${stage%% *})"
done
check 0 "30: 계획 2 는 머지되지 않았으니 묶음이 나간다(양성 대조)" --job E1 --stage plan --plan 2
assert_not_contains "$(err)" "머지됐다" "30: 계획 2 는 머지되지 않았다"

# ── 묶음 F — 한 번도 브랜치를 만들지 않은 E3 · E2(머지 검사의 양성 대조) ──
new_repo "$T0/f" && ok "F: 팀 레포를 세웠다" || { no "F: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
check 0 "31: 브랜치를 만든 적 없는 E3 의 design 은 나간다" --job E3 --stage design
assert_contains "$(grep '^알림: ' "$T/b.txt")" "과제 브랜치 feature/tm-e3 가 아직 없다" "31: 브랜치 없음 알림"
check 1 "31: 같은 E3 의 plan 은 승인 줄에서 멈춘다" --job E3 --stage plan --plan 1
assert_contains "$(err)" '`spec 승인` 줄이 없다' "31: 사유는 승인 줄 없음"
assert_not_contains "$(err)" "머지됐다" "31: 없는 브랜치를 머지로 읽지 않는다"
check 1 "34: 브랜치를 만든 적 없는 E2 는 흐름 승인에서 멈춘다" --job E2 --stage implement
assert_contains "$(err)" '`흐름 승인` 줄이 없다' "34: 사유는 흐름 승인 줄 없음"
assert_not_contains "$(err)" "머지됐다" "34: 없는 브랜치를 머지로 읽지 않는다(32 · 33 의 양성 대조)"

# ── 묶음 G — 설계 없는 흐름의 E2 가 머지된다 ──
new_repo "$T0/g" && ok "G: 팀 레포를 세웠다" || { no "G: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
g checkout -q -b feature/tm-e2 main
approved "흐름 승인" E2 - - 2026-11-22
put "$E2/results/implement-1.md" "$(printf -- '---\ntype: job-result\nstage: implement\nattempt: 1\nrole: worker\nhead: %s\n---\n\n산출물: src/e2/x.md\n끝 — %s\n' "$(g rev-parse HEAD)" "$(g rev-parse HEAD)")"
g commit -qm "E2 결과 1" && push_br feature/tm-e2
g checkout -q main && g merge -q --no-ff -m "E2 합침" feature/tm-e2 && push_main
check 1 "32: 머지된 설계 없는 흐름은 멈춘다(AC14)" --job E2 --stage implement
assert_contains "$(err)" "이미 기본 브랜치에 머지됐다" "32: 사유"
g branch -q -D feature/tm-e2 && g push -q origin --delete feature/tm-e2 && g fetch -q --prune origin
check 1 "33: 브랜치를 지워도 멈춘다" --job E2 --stage implement
assert_contains "$(err)" "implement-1.md" "33: 자취는 기본 브랜치의 implement 결과 파일이다"
assert_contains "$(err)" "머지됐다" "33: 머지됐다"

use_repo "$T0/a"
finish
