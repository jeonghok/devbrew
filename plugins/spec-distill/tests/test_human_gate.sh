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
SPECL="spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」"

# ── 0 — 한 번 지어 복사하는 팀 레포(repo_copy): 사본은 원격을 따로 갖고 견본 경로를 품지 않는다 ──
repo_copy "$T0/c0a" new && repo_copy "$T0/c0b" new && ok "0: 견본에서 사본 둘을 떴다" || { no "0: 사본을 뜨지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
assert_eq "$(git -C "$T0/c0a/repo" remote get-url origin)" "$T0/c0a/origin.git" "0: 사본의 원격은 그 사본의 bare 레포다"
assert_eq "$(grep -rlF --exclude-dir=objects -- "$TEAM_TPL" "$T0/c0a/repo" "$T0/c0a/origin.git" "$T0/c0a/claude" 2>/dev/null)" "" "0: 사본의 레포 · 원격 · 세션 기록에 견본 경로가 남지 않는다"
use_repo "$T0/c0a" && g checkout -q -b c0/only-a main && g push -q origin c0/only-a
assert_eq "$(git -C "$T0/c0a/origin.git" for-each-ref --format='%(refname)' refs/heads/c0/only-a)" "refs/heads/c0/only-a" "0: 양성 대조 — 그 사본의 원격에는 올라갔다"
assert_eq "$(git -C "$T0/c0b/repo" ls-remote origin refs/heads/c0/only-a; echo "rc=$?")" "rc=0" "0: 한 사본의 push 가 다른 사본의 원격에 보이지 않는다"
assert_eq "$(git -C "$TEAM_TPL/new/repo" ls-remote origin refs/heads/c0/only-a; echo "rc=$?")" "rc=0" "0: 견본의 원격에도 보이지 않는다"
repo_copy "$T0/c0a" new 2>"$T0/c0-err.txt"; assert_eq "$?" "1" "0: 레포가 이미 선 폴더에는 뜨지 않는다"
assert_contains "$(cat "$T0/c0-err.txt")" "새 폴더에 레포가 이미 있다" "0: 까닭을 표준 오류에 낸다(이미 선 폴더)"
assert_eq "$(git -C "$T0/c0a/repo" symbolic-ref --short HEAD) $(git -C "$T0/c0a/repo" remote get-url origin)" "c0/only-a $T0/c0a/origin.git" "0: 이미 선 사본을 덮어쓰지 않는다(가지 · 원격 그대로)"
repo_copy "$T0/c0c" "$T0/no-such-template" 2>"$T0/c0-err.txt"; assert_eq "$?" "1" "0: 없는 견본은 1"
assert_contains "$(cat "$T0/c0-err.txt")" "견본에 팀 레포가 없다" "0: 까닭을 표준 오류에 낸다(없는 견본)"
assert_eq "$([ -e "$T0/c0c" ] && echo 있음 || echo 없음) ${T}" "없음 $T0/c0a" "0: 없는 견본이면 새 폴더를 만들지 않고 T 를 옮기지 않는다"

# ── 묶음 A — 설계 흐름(E1) ──
repo_copy "$T0/a" new && ok "A: 팀 레포를 세웠다(${TM})" || { no "A: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
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
assert_not_contains "$(err)" "가 아직 없다" "13: 계획 2 의 브랜치가 있으면 브랜치 없음 힌트를 붙이지 않는다(K20)"

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

g checkout -q main

# ── 묶음 B — 관문을 끄는 길(E3 는 이 레포에서 처음 브랜치를 갖는다) ──
repo_copy "$T0/b" new && ok "B: 팀 레포를 세웠다" || { no "B: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
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
repo_copy "$T0/c" new && ok "C: 팀 레포를 세웠다" || { no "C: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
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
# C3 — 브랜치가 없는 건 그대로인데 「확인 못 함」 이 다른 사유(세션 기록을 읽지 못함)로 난다 — 힌트는 설계를 못 읽은 사유일 때만이다(K20)
mkdir -p "$T/empty-config"
CLAUDE_CONFIG_DIR="$T/empty-config" check 1 "C3: 설계는 기준 커밋에 있고 다른 사유로 확인 못 함이면 멈춘다" --job E1 --stage plan --plan 2
assert_contains "$(err)" "확인 못 함" "C3: 사유는 확인 못 함이다"
assert_not_contains "$(err)" "가 아직 없다" "C3: 설계를 못 읽은 사유가 아니면 브랜치 없음 힌트를 붙이지 않는다(K20)"

# ── 묶음 D — 연속 실패 멈춤 · 머지된 계획(AC13 · AC14). 이 묶음의 E1 은 새 레포에서 설계 · 계획 · 승인을 갖춘다 ──
repo_copy "$T0/d" new && ok "D: 팀 레포를 세웠다" || { no "D: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
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
assert_eq "$(human "걸음 건너뜀" E1 - "다시 시도 plan 1 시도 3" 2026-11-22)" "0" "23b: 준비 — 다시 시도 줄을 적었다"
FORGED_INTENT="$W/$E1/INTENT.md"
sed -E '/다시 시도 plan 1 시도 3/ s/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}#1/00000000-0000-4000-8000-00000000dead#1/' "$FORGED_INTENT" > "$T/forged.md" && cp "$T/forged.md" "$FORGED_INTENT"
assert_contains "$(grep '다시 시도 plan 1 시도 3' "$FORGED_INTENT")" "00000000-0000-4000-8000-00000000dead#1" "23b: 준비 — 근거의 항목을 지어낸 것으로 바꿨다(꼴은 그대로)"
g add -- "$E1/INTENT.md" && g commit -qm "근거를 지어낸 다시 시도 줄" && push_br feature/tm-e1
check 1 "23b: 꼴만 맞고 근거를 지어낸 다시 시도 줄은 멈춤을 풀지 못한다(AC13 — 실제 확인이 있어야 푼다)" "${D_IMPL[@]}"
assert_contains "$(err)" "구현 시도 2번이 이어서 받아지지 않았다" "23b: 사유는 그대로 이어진 실패 둘"
assert_contains "$(err)" "다시 시도 plan 1 시도 3" "23b: 푸는 관문은 여전히 시도 3"
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
approved "걸음 건너뜀" E1 - "다시 시도 plan 1 시도 9" 2026-11-26 && push_br feature/tm-e1
check 0 "27f: 사람의 다시 시도 줄은 그 시도를 푼다(27d · 27e 의 양성 대조)" "${D_IMPL[@]}"
assert_eq "$(write_line)" "$E1/results/implement-plan-1-9.md" "27f: 쓸 것은 시도 9"

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
repo_copy "$T0/f" new && ok "F: 팀 레포를 세웠다" || { no "F: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
check 0 "31: 브랜치를 만든 적 없는 E3 의 design 은 나간다" --job E3 --stage design
assert_contains "$(grep '^알림: ' "$T/b.txt")" "과제 브랜치 feature/tm-e3 가 아직 없다" "31: 브랜치 없음 알림"
check 1 "31: 같은 E3 의 plan 은 승인 줄에서 멈춘다" --job E3 --stage plan --plan 1
assert_contains "$(err)" '`spec 승인` 줄이 없다' "31: 사유는 승인 줄 없음"
assert_not_contains "$(err)" "머지됐다" "31: 없는 브랜치를 머지로 읽지 않는다"
check 1 "34: 브랜치를 만든 적 없는 E2 는 흐름 승인에서 멈춘다" --job E2 --stage implement
assert_contains "$(err)" '`흐름 승인` 줄이 없다' "34: 사유는 흐름 승인 줄 없음"
assert_not_contains "$(err)" "머지됐다" "34: 없는 브랜치를 머지로 읽지 않는다(32 · 33 의 양성 대조)"

# ── 묶음 G — 설계 없는 흐름의 E2 가 머지된다 ──
repo_copy "$T0/g" new && ok "G: 팀 레포를 세웠다" || { no "G: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
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

# ── 결과 대조(job_results.py check)의 관문 — 과제 11. 묶음마다 새 레포 · 새 과제 ──
e1_state() {  # feature/tm-e1 에 설계 · 계획 1(두 판) · 구현 결과 1 을 끝까지 올린다. 사람 줄은 적지 않는다. PLAN_R1 은 계획의 첫 판
  g checkout -q -b feature/tm-e1 main
  put "$E1/design.md" "$(printf '# 설계\n\n본문 하나\n\n## Acceptance Criteria\n\n- AC1: 자리표시\n')"
  g commit -qm "E1 설계" && push_br feature/tm-e1
  put "$E1/plan-1.md" "$(printf '# 계획\n\n### Task 1: 자리표시\n\nAC1 을 만든다.\n')"
  g commit -qm "E1 계획 1 첫 판" && PLAN_R1="$(g rev-parse HEAD | cut -c1-8)"
  put "$E1/plan-1.md" "$(printf '# 계획\n\n### Task 1: 자리표시\n\nAC1 을 만든다. 둘째 판.\n')"
  g commit -qm "E1 계획 1 둘째 판" && push_br feature/tm-e1
  hand_result E1 implement 1 1 "AC1: 구현됨 — 자리표시"
}
line_of() { grep "^- $1 · " "$W/$E1/INTENT.md" | head -1; }
edit_intent() {  # edit_intent <바꿀 글> <새 글> — E1 INTENT.md 의 그 글을 한 번 바꾸고 커밋해 올린다
  python3 - "$W/$E1/INTENT.md" "$1" "$2" <<'PY'
import sys
p, old, new = sys.argv[1:4]
s = open(p, encoding="utf-8", newline="").read()
assert old in s, old
open(p, "w", encoding="utf-8", newline="").write(s.replace(old, new, 1))
PY
  g add -- "$E1/INTENT.md" && g commit -qm "INTENT 고침" && push_br feature/tm-e1
}

# 견본 T1–T3 — T1 = e1_state · T2 = T1 + spec 승인 · T3 = T2 + 계획 검토. 묶음 K · O 는 T1, H · L · P 는 T2, I · N 은 T3 에서 뜬다
{ repo_copy "$T0/t1" new && e1_state \
    && repo_copy "$T0/t2" "$T0/t1" && approved "spec 승인" E1 - - 2026-11-20 && push_br feature/tm-e1 \
    && repo_copy "$T0/t3" "$T0/t2" && approved "계획 검토" E1 1 - 2026-11-21 && push_br feature/tm-e1; } \
  && ok "견본 T1–T3 을 지었다" || { no "견본 T1–T3 을 짓지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }

# 묶음 H — E1(설계 흐름) · E2(설계 없는 흐름). 41 – 49
repo_copy "$T0/h" "$T0/t2" && ok "H: 팀 레포를 세웠다" || { no "H: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md)" "1" "41: 계획 검토 줄이 없으면 구현 결과를 받지 않는다(AC10)"
case "$(sed -n 1p "$T/c.txt")" in "결과 대조: 거절 "*) ok "41: 첫 줄이 거절" ;; *) no "41: 첫 줄이 거절 — $(sed -n 1p "$T/c.txt")" ;; esac
assert_contains "$(reasons)" '`계획 검토` 줄이 없다' "41: 거절 사유"
assert_eq "$(grep -c '^- 결과 받음' "$T/c.txt")" "0" "41: 받음 줄을 내지 않는다"
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md --branch feature/tm-e1)" "1" "42: --branch 를 주어도 같다"
assert_contains "$(reasons)" '`계획 검토` 줄이 없다' "42: 사유는 계획 검토다"
assert_not_contains "$(reasons)" '`흐름 승인`' "42: --branch 가 흐름을 바꾸지 않는다(J32)"
approved "계획 검토" E1 1 - 2026-11-21 && push_br feature/tm-e1
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md)" "0" "43: 계획 검토 줄이 있으면 받는다"
assert_eq "$(grep -c '^- 결과 받음 · 2026-11-30 · 「implement-plan-1-1.md · ' "$T/c.txt")" "1" "43: 받음 줄 한 줄(양성 대조)"
mv "$CLAUDE_CONFIG_DIR" "$T/claude.away"
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md)" "1" "44: 세션 기록이 없으면 받지 않는다(AC11)"
assert_contains "$(reasons)" "확인 못 함" "44: 확인 못 함"
assert_contains "$(reasons)" "다시 승인받는다" "44: 다시 승인받는 길"
mv "$T/claude.away" "$CLAUDE_CONFIG_DIR"
OLD_LINE="$(line_of "계획 검토")"
edit_intent "$(printf '%s' "$OLD_LINE" | sed 's/.*근거 [^:]*:\([0-9a-f-]\{36\}\)#.*/\1/')" "ffffffff-ffff-4fff-8fff-ffffffffffff"
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md)" "1" "45: 없는 uuid 를 가리키는 줄은 받지 않는다"
assert_contains "$(reasons)" "어긋남" "45: 어긋남"
g revert --no-edit HEAD >/dev/null && push_br feature/tm-e1
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md)" "0" "45b: 되돌리면 받는다(양성 대조)"
OLD_REV="$(printf '%s' "$OLD_LINE" | sed 's/.*plan-1.md@\([0-9a-f]\{8\}\).*/\1/')"
put "$E1/plan-1.md" "$(printf '# 계획\n\n### Task 1: 자리표시\n\nAC1 을 만든다. 셋째 판.\n')"
g commit -qm "E1 계획 1 셋째 판" && push_br feature/tm-e1
edit_intent "plan-1.md@${OLD_REV}" "plan-1.md@$(g rev-parse HEAD | cut -c1-8)"
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md)" "1" "46: 옛 답에 판만 새것인 줄은 받지 않는다(AC11)"
assert_contains "$(reasons)" "어긋남" "46: 어긋남"
python3 - "$W/$E1/INTENT.md" <<'PY'
import sys
p = sys.argv[1]
out = [l for l in open(p, encoding="utf-8", newline="").read().split("\n") if not l.startswith("- 계획 검토 · ")]
open(p, "w", encoding="utf-8", newline="").write("\n".join(out))
PY
g add -- "$E1/INTENT.md" && g commit -qm "계획 검토 줄 지움" && push_br feature/tm-e1
approved "걸음 건너뜀" E1 - "계획 검토 plan 1" 2026-11-22 && push_br feature/tm-e1
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md)" "0" "47: 건너뜀 줄이 계획 검토 관문을 푼다(AC12)"
g checkout -q -b feature/tm-e2 main
put "src/e2/x.md" "산출물" && g commit -qm "E2 산출물" && push_br feature/tm-e2
hand_result E2 implement - 1 "산출물: src/e2/x.md"
assert_eq "$(rcheck --job E2 --result implement-1.md)" "1" "48: 흐름 승인이 없으면 받지 않는다(AC10)"
assert_contains "$(reasons)" '`흐름 승인` 줄이 없다' "48: 사유"
approved "흐름 승인" E2 - - 2026-11-22 && push_br feature/tm-e2
assert_eq "$(rcheck --job E2 --result implement-1.md)" "0" "49: 흐름 승인 줄이 있으면 받는다"

# 묶음 J — E3(설계 흐름)의 plan · design 결과. 50 · 51
repo_copy "$T0/j" new && ok "J: 팀 레포를 세웠다" || { no "J: 팀 레포를 세우지 못했다"; finish; exit 1; }
g checkout -q -b feature/tm-e3 main
put "$E3/design.md" "$(printf '# 설계\n\n본문\n\n## Acceptance Criteria\n\n- AC1: 자리표시\n')"
g commit -qm "E3 설계" && push_br feature/tm-e3
hand_result E3 plan 1 1 "AC1: 구현됨 — 자리표시"
hand_result E3 design - 1
rcheck --job E3 --result plan-plan-1-1.md >/dev/null
assert_contains "$(reasons)" '`spec 승인` 줄이 없다' "50: plan 결과는 spec 승인을 본다(J31)"
assert_not_contains "$(reasons)" '`계획 검토`' "50: 계획 검토는 보지 않는다"
rcheck --job E3 --result design-1.md >/dev/null
assert_contains "$(sed -n 1p "$T/c.txt")" "결과 대조: " "50: design 결과도 대조 결과를 낸다(죽지 않았다)"
assert_not_contains "$(cat "$T/c.txt")" '` 줄이' "50: design 결과는 관문 사유가 붙지 않는다"
approved "spec 승인" E3 - - 2026-11-22 && push_br feature/tm-e3
rcheck --job E3 --result plan-plan-1-1.md >/dev/null
assert_not_contains "$(reasons)" 'spec 승인' "51: spec 승인 줄이 있으면 그 사유가 없다(양성 대조)"

# 묶음 K — 관문을 끈 새 과제 E1. 52
repo_copy "$T0/k" "$T0/t1" && ok "K: 팀 레포를 세웠다" || { no "K: 팀 레포를 세우지 못했다"; finish; exit 1; }
decide E1 "$SPECL" && decide E1 "계획 검토 · 2026-11-21 · 「계획대로 구현한다」" && grep -q '^- 계획 검토 · ' "$W/$E1/INTENT.md" && ok "52: 준비 — 손으로 적은 줄 둘" || no "52: 준비 — 손으로 적은 줄 둘"
g add -- "$E1/INTENT.md" && g commit -qm "손으로 적은 줄" && push_br feature/tm-e1
g checkout -q main
printf '%s\n' '---' 'human_gate: 끔' '---' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "관문 끔" && push_main
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md --branch feature/tm-e1)" "0" "52: human_gate 끔이면 손으로 적은 줄로 받는다"
assert_eq "$(sed -n 2p "$T/c.txt")" "알림: 사람 줄 대조가 꺼져 있다" "52: 둘째 줄이 꺼짐 알림이다(J10)"
g revert --no-edit HEAD >/dev/null && push_main
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md --branch feature/tm-e1)" "1" "52: 되돌리면 받지 않는다(양성 대조)"

# 묶음 I — human-check. 이 묶음의 E1 은 새 레포에서 설계 · 계획 · 결과 · 승인 둘을 갖춘다. 53 · 54 · 58
repo_copy "$T0/i" "$T0/t3" && ok "I: 팀 레포를 세웠다" || { no "I: 팀 레포를 세우지 못했다"; finish; exit 1; }
BEFORE="$(cksum < "$W/$E1/INTENT.md")|$(g status --short -- "$TM")"
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "53: 모든 줄이 지나면 0"
assert_eq "$(wc -l < "$T/led.txt" | tr -d ' ')" "2" "53: 줄 수는 사람 줄 수와 같다"
assert_eq "$(grep -c '^지남 — ' "$T/led.txt")" "2" "53: 모두 지남"
assert_eq "$(cksum < "$W/$E1/INTENT.md")|$(g status --short -- "$TM")" "$BEFORE" "53: 아무것도 쓰지 않는다(AC23)"
printf '%s\n' '---' 'human_gate: 끔' '---' > "$W/.devbrew.md"
g checkout -q main && g add -- .devbrew.md && g commit -qm "관문 끔" && push_main && g checkout -q feature/tm-e1
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "58: 관문을 끄고 불러도 줄이 있으면 0"
assert_eq "$(sed -n 1p "$T/led.txt")" "사람 줄 대조가 꺼져 있다" "58: 첫 줄이 꺼짐 안내다"
g checkout -q main && g revert --no-edit HEAD >/dev/null && push_main && g checkout -q feature/tm-e1
SPEC_LINE="$(line_of "spec 승인")"
PLAN_LINE="$(line_of "계획 검토")"
decide E1 "- spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」"
decide E1 "$(printf '%s' "$SPEC_LINE" | sed 's/:[0-9a-f-]\{36\}#/:ffffffff-ffff-4fff-8fff-ffffffffffff#/' | sed 's/- spec 승인 · 2026-11-20/- spec 승인 · 2026-11-21/')"
decide E1 "$(printf '%s' "$PLAN_LINE" | sed "s/plan-1.md@[0-9a-f]\{8\}/plan-1.md@${PLAN_R1}/" | sed 's/:[0-9a-f-]\{36\}#/:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa#/')"
decide E1 "$(printf '%s' "$SPEC_LINE" | sed 's/근거 [A-Za-z0-9_-]*:[0-9a-f-]\{36\}#/근거 deadbeef-0000-4000-8000-00000000dead:bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb#/' | sed 's/2026-11-20/2026-11-22/')"
g add -- "$E1/INTENT.md" && g commit -qm "나쁜 줄 넷" && push_br feature/tm-e1
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "1" "54: 지나지 못한 줄이 있으면 1"
for v in "근거 없음" "어긋남" "낡음" "확인 못 함"; do
  assert_eq "$(grep -c "^${v} — " "$T/led.txt")" "1" "54: ${v} 줄이 하나"
done
assert_eq "$(grep -c '^지남 — ' "$T/led.txt")" "2" "54: 진짜 줄 둘은 지남"
assert_eq "$(grep -c '^    사유: ' "$T/led.txt")" "4" "54: 지나지 못한 줄마다 사유가 아래에 붙는다"
assert_eq "$(awk 'prev !~ /^지남 — / && prev != "" && $0 ~ /^    사유: / {n++} {prev=$0} END{print n+0}' "$T/led.txt")" "4" "54: 사유 줄은 지나지 못한 줄 바로 아래다"
assert_eq "$(grep -c '^줄 없음' "$T/led.txt")" "0" "54: 줄이 있는 종류는 줄 없음에 다시 내지 않는다"

# 묶음 L — 승인 줄 없이 받음 줄만 손으로 적었다. 55
repo_copy "$T0/l" "$T0/t2" && ok "L: 팀 레포를 세웠다" || { no "L: 팀 레포를 세우지 못했다"; finish; exit 1; }
decide E1 "- 결과 받음 · 2026-11-24 · 「implement-plan-1-1.md · $(g rev-parse HEAD) · 결과 대조: 통과 — 자리표시」"
g add -- "$E1/INTENT.md" && g commit -qm "손으로 적은 받음 줄" && push_br feature/tm-e1
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "1" "55: 계획 검토 줄이 없으면 1"
assert_contains "$(cat "$T/led.txt")" '줄 없음 — `계획 검토` 줄(계획 1)' "55: 줄 없음"
assert_contains "$(cat "$T/led.txt")" "    사유: implement-plan-1-1.md 가 있다" "55: 자취"
assert_eq "$(grep -c '^지남 — - spec 승인' "$T/led.txt")" "1" "55: spec 승인 줄은 지남"
assert_not_contains "$(cat "$T/led.txt")" '줄 없음 — `spec 승인`' "55: spec 승인은 줄 없음이 아니다"

# 묶음 M — 자취만 있고 줄이 없다. 56 · 57
repo_copy "$T0/m" new && ok "M: 팀 레포를 세웠다" || { no "M: 팀 레포를 세우지 못했다"; finish; exit 1; }
g checkout -q -b feature/tm-e2 main
put "src/e2/x.md" "산출물" && g commit -qm "E2 산출물" && push_br feature/tm-e2
hand_result E2 implement - 1 "산출물: src/e2/x.md"
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "$(printf '# 설계\n\n본문\n')" && put "$E1/plan-1.md" "계획" && g commit -qm "E1 설계 · 계획" && push_br feature/tm-e1
g checkout -q main && g checkout -q -b feature/tm-e3 main && push_br feature/tm-e3
assert_eq "$(led human-check --roadmap "$RM" --job E2)" "1" "56: 결과 파일만 있고 흐름 승인 줄이 없으면 1"
assert_contains "$(cat "$T/led.txt")" '줄 없음 — `흐름 승인` 줄' "56: 흐름 승인 줄 없음"
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "1" "56: 계획 파일만 있고 사람 줄이 없으면 1"
assert_contains "$(cat "$T/led.txt")" '줄 없음 — `spec 승인` 줄' "56: spec 승인 줄 없음"
assert_eq "$(led human-check --roadmap "$RM" --job E3)" "0" "57: 자취도 줄도 없으면 0"
assert_eq "$(cat "$T/led.txt")" "사람 줄 없음" "57: 출력이 사람 줄 없음 하나다"
assert_eq "$(led human-check --roadmap "$RM" --job NOPE)" "2" "59: 없는 과제는 2"
mkdir -p "$W/docs/old" && printf '%s\n' '---' 'type: roadmap' '---' '' '# 옛 형식' > "$W/docs/old/roadmap.md"
assert_eq "$(led human-check --roadmap docs/old/roadmap.md --job E1)" "2" "59: 옛 형식 로드맵은 2"

# 묶음 N — 계획 번호 없는 implement 결과(설계 흐름). I1: 켜져 있으면 사유를 또렷이, 꺼졌으면 J9(줄의 유무)
repo_copy "$T0/n" "$T0/t3" && ok "N: 팀 레포를 세웠다" || { no "N: 팀 레포를 세우지 못했다"; finish; exit 1; }
hand_result E1 implement - 1 "AC1: 구현됨 — 자리표시"
assert_eq "$(rcheck --job E1 --result implement-1.md)" "1" "N1: 켜져 있으면 계획 번호 없는 implement 결과는 받지 않는다"
assert_contains "$(reasons)" "결과 파일 이름에 계획 번호가 없어 \`계획 검토\` 관문을 볼 수 없다" "N1: 사유가 또렷하다"
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md)" "0" "N1: 같은 과제의 계획 번호 있는 결과는 받는다(양성 대조)"
g checkout -q main
printf '%s\n' '---' 'human_gate: 끔' '---' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "관문 끔" && push_main
assert_eq "$(rcheck --job E1 --result implement-1.md --branch feature/tm-e1)" "0" "N2: 꺼졌으면 J9 — 날짜 있는 계획 검토 줄이 있어 받는다(스펙에 없는 거절을 더하지 않는다)"
assert_not_contains "$(cat "$T/c.txt")" "계획 번호가 없어" "N2: 꺼졌으면 그 사유가 없다"

# 묶음 O — 관문을 끈 채 날짜 칸이 틀린 손 줄. I2: human-check 와 결과 대조가 같은 줄의 유무를 본다
repo_copy "$T0/o" "$T0/t1" && ok "O: 팀 레포를 세웠다" || { no "O: 팀 레포를 세우지 못했다"; finish; exit 1; }
decide E1 "$SPECL" && decide E1 "계획 검토 · 2026-11-21 · 「계획대로 구현한다」"
g add -- "$E1/INTENT.md" && g commit -qm "손으로 적은 줄" && push_br feature/tm-e1
edit_intent "계획 검토 · 2026-11-21" "계획 검토 · 2026/11/21"   # 파일을 손으로 고쳐 날짜 칸을 깬다(decide 는 이 꼴을 받지 않는다)
g checkout -q main
printf '%s\n' '---' 'human_gate: 끔' '---' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "관문 끔" && push_main
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md --branch feature/tm-e1)" "1" "O1: 날짜 없는 계획 검토 줄로는 받지 않는다(J9)"
assert_contains "$(reasons)" '`계획 검토` 줄이 없다' "O1: 사유"
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "1" "O2: human-check 도 1 — 결과 대조와 같은 판단"
assert_eq "$(grep -c "^줄로 세지 않는다 — - 계획 검토" "$T/led.txt")" "1" "O2: 날짜 없는 줄은 지남이 아니다"
assert_contains "$(cat "$T/led.txt")" '줄 없음 — `계획 검토` 줄(계획 1)' "O2: 줄 없음을 낸다(꺼진 대조에서도 ② 가 선다)"
assert_eq "$(grep -c '^지남 — - spec 승인' "$T/led.txt")" "1" "O2: 날짜 있는 spec 승인 줄은 지남"
g checkout -q feature/tm-e1
python3 - "$W/$E1/INTENT.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8", newline="").read()
assert "2026/11/21" in s
open(p, "w", encoding="utf-8", newline="").write(s.replace("2026/11/21", "2026-11-21", 1))
PY
g add -- "$E1/INTENT.md" && g commit -qm "날짜 칸을 고친다" && push_br feature/tm-e1
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md --branch feature/tm-e1)" "0" "O3: 날짜를 고치면 받는다(양성 짝)"
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "O3: human-check 도 0"
assert_eq "$(grep -c '^지남 — ' "$T/led.txt")" "2" "O3: 두 줄 모두 지남"

# 묶음 P — 결과 파일은 없고 꼴 맞는 받음 줄만 있다. I3: 받음 줄 모으기가 끊기면 RED
repo_copy "$T0/p" "$T0/t2" && ok "P: 팀 레포를 세웠다" || { no "P: 팀 레포를 세우지 못했다"; finish; exit 1; }
decide E1 "- 결과 받음 · 2026-11-24 · 「implement-plan-1-1.md · $(g rev-parse HEAD) · 결과 대조: 통과 — 자리표시」"
g rm -q -- "$TM/jobs/E1/results/implement-plan-1-1.md" && g add -- "$E1/INTENT.md" && g commit -qm "결과 파일을 지우고 받음 줄만 둔다" && push_br feature/tm-e1
assert_eq "$(g ls-tree -r --name-only feature/tm-e1 | grep -c 'results/implement-plan-1-1.md')" "0" "P: 준비 — 결과 파일이 어느 끝에도 없다"
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "1" "P: 받음 줄만 있어도 계획 검토 줄이 없으면 1"
assert_contains "$(cat "$T/led.txt")" '줄 없음 — `계획 검토` 줄(계획 1)' "P: 줄 없음"
assert_contains "$(cat "$T/led.txt")" "    사유: implement-plan-1-1.md 의 받음 줄이 있다" "P: 자취는 받음 줄이다"

use_repo "$T0/a"
finish
