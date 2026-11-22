#!/usr/bin/env bash
# 사람 줄과 관문의 끝에서 끝 — ask-head → 질문 창 답 → record --human → 시작 묶음 → 결과 대조 → 상태 계산 → human-check 를 한 레포에서 한 번 돌고,
# 지어낸 줄을 세 자리(시작 묶음 · 결과 대조 · human-check)에서 막고, 옛 형식의 명령 · 출력이 그대로임을 잰다. AC5 – AC14 의 이음매 · AC21.
# 손으로 적은 줄은 지어낸 줄뿐이다 — 진짜 줄은 도우미(human · approved)가 ask-head · 가짜 세션 기록 · record --human 으로 만든다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_human_gate_e2e.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T0="$(mktemp -d)" || exit 1
[ -n "$T0" ] && [ -d "$T0" ] || exit 1
trap 'chmod -R u+rwX "$T0" 2>/dev/null; rm -rf "$T0"' EXIT
T="$T0"
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"

PASSL="승인 — 계획 담당자에게"
SIDX="00000000-0000-4000-8000-00000000c0e0"   # 사람 없이 답하는 다른 세션
err() { cat "$T/b.err"; }
stage_of() { js "$T/s.json" "[b['stage'] for b in r['blocks'] if b['id']=='$1'][0]"; }

# ══ 1. 끝에서 끝 — 손으로 적는 줄 없이 E1 을 설계 끝까지 ══
new_repo "$T0/a" && ok "1: 팀 레포를 세웠다(${TM})" || { no "1: 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
E1="$TM/jobs/E1"; E2="$TM/jobs/E2"; E3="$TM/jobs/E3"
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "$(printf -- '---\ntype: design\njob: E1\n---\n\n# 설계\n\n### §1 읽는 자리\n\n본문 하나\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 · S1 | 반영 | §1 |\n\n## Acceptance Criteria\n\n- AC1: 자리표시\n\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| 미룬 것 하나 | 이유 하나 | #12 |\n')"
g commit -qm "E1 설계" && push_br feature/tm-e1

check 0 "2: design 묶음이 나간다" --job E1 --stage design
LEAD1="$(g show "origin/main:${RD}leader/CLAUDE.md")"
WORK1="$(g show "origin/main:${RD}worker/CLAUDE.md")"
assert_eq "$(sed -n '/^역할 문서 (/,/^규칙 (/p' "$T/b.txt" | sed '1d;$d')" "$LEAD1" "2: 역할 문서는 leader 의 것이다"
assert_eq "$([ "$LEAD1" != "$WORK1" ] && echo 다름)" "다름" "2: 준비 — leader 와 worker 문서가 달라 위 단언이 가른다"
check 1 "3: 승인이 없으면 plan 묶음이 멈춘다" --job E1 --stage plan --plan 1
assert_contains "$(err)" '`spec 승인` 줄이 없다' "3: 사유"

assert_eq "$(led ask-head --human "spec 승인" --roadmap "$RM" --job E1)" "0" "4: ask-head 가 머리를 낸다"
assert_eq "$(printf '%s' "$(cat "$T/led.txt")" | sed 's/[0-9a-f]\{8\}$/<판>/')" "E1 @<판>" "4: 머리 꼴 <과제> @<판>"
assert_eq "$(human "spec 승인" E1 - - 2026-03-05)" "0" "4: 그 머리로 답한 기록에서 record --human 이 줄을 적는다(날짜 인자 없이)"
assert_contains "$(grep '^- spec 승인 · ' "$W/$E1/INTENT.md")" "- spec 승인 · 2026-03-05 · 「${PASSL}」 · design.md@" "4: 줄의 날짜는 그 답의 시각에서 온 것이다"
g add -- "$E1/INTENT.md" && g commit -qm "spec 승인 — E1" && push_br feature/tm-e1

check 0 "5: 승인 뒤 plan 묶음이 나간다" --job E1 --stage plan --plan 1
CMD="$(grep '^맞추는 명령: ' "$T/b.txt")"
assert_contains "$CMD" "--role worker" "5: 계획 단계의 맞추는 명령은 worker 다"
(cd "$W" && bash -c "${CMD#맞추는 명령: }") > "$T/out.txt" 2>&1 && ok "5: 맞추는 명령을 그대로 돌렸다" || no "5: 맞추는 명령 — $(cat "$T/out.txt")"
assert_contains "$(sed -n 1,3p "$W/$E1/results/plan-plan-1-1.md")" "type: job-result" "5: plan-plan-1-1.md 의 머리가 섰다"
put "$E1/plan-1.md" "$(printf '# 계획\n\n### Task 1: 자리표시\n\nAC1 을 만든다.\n')"
g add -- "$E1/results" && g commit -qm "E1 계획 1" && push_br feature/tm-e1
check 1 "6: 계획 확인이 없으면 implement 가 멈춘다" --job E1 --stage implement --plan 1
assert_contains "$(err)" '`계획 검토` 줄' "6: 사유"

assert_eq "$(human "계획 검토" E1 1 - 2026-03-06)" "0" "7: 머리가 E1 plan 1 @<판> 인 질문의 답으로 계획 검토 줄을 적었다"
assert_contains "$(grep '^- 계획 검토 · ' "$W/$E1/INTENT.md")" " · plan-1.md@" "7: 줄이 plan-1.md 의 판을 가리킨다"
g add -- "$E1/INTENT.md" && g commit -qm "계획 검토 — E1" && push_br feature/tm-e1
check 0 "7: 계획 검토 뒤 implement 묶음이 나간다" --job E1 --stage implement --plan 1
assert_contains "$(grep '^맞추는 명령: ' "$T/b.txt")" "--role worker" "7: 구현 단계의 맞추는 명령도 worker 다"

finish_attempt 1 "AC1: 구현됨 — src/e1/a1.txt" && ok "8: 맞추는 명령을 돌려 예약 경로 코드와 AC · 끝 줄이 있는 결과를 올렸다" || no "8: 시도 1"
assert_eq "$(rcheck --job E1 --result implement-plan-1-1.md --branch feature/tm-e1)" "0" "9: 결과 대조를 지난다"
RLINE="$(grep '^- 결과 받음 · ' "$T/c.txt")"
assert_contains "$RLINE" "- 결과 받음 · 2026-11-30 · 「implement-plan-1-1.md · " "9: 받음 줄이 난다"
assert_eq "$(led record --spec "$E1/INTENT.md" --line "$RLINE")" "0" "9: 받음 줄을 record 로 적었다"
g add -- "$E1/INTENT.md" && g commit -qm "받음 줄 — 시도 1" && push_br feature/tm-e1
assert_eq "$(status "$T/s.json")" "0" "10: 상태 계산 종료 코드 0"
assert_eq "$(stage_of E1)" "구현 끝" "10: E1 은 구현 끝이다"
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "11: human-check 0"
assert_eq "$(grep -c '^지남 — ' "$T/led.txt")" "2" "11: 두 줄 모두 지남"
assert_eq "$(grep -c '^줄 없음' "$T/led.txt")" "0" "11: 줄 없음이 없다"

g checkout -q -b feature/tm-e1b feature/tm-e1 && put src/e1/zz.txt zz && g commit -qm "e1b 코드" && push_br feature/tm-e1b
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "12: 같은 줄이 두 브랜치 끝에 있어도 0"
assert_eq "$(grep -c '^지남 — - spec 승인' "$T/led.txt")" "1" "12: spec 승인 줄은 한 번만 낸다"
assert_eq "$(grep -c '^지남 — - 계획 검토' "$T/led.txt")" "1" "12: 계획 검토 줄도 한 번만 낸다"
assert_eq "$(wc -l < "$T/led.txt" | tr -d ' ')" "2" "12: 출력은 두 줄이다"
g checkout -q feature/tm-e1 && g branch -q -D feature/tm-e1b && g push -q origin --delete feature/tm-e1b && g fetch -q --prune origin

# ── Verification Plan — 같은 흐름 위에서 ──
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read(); assert "본문 하나" in s; open(p, "w", encoding="utf-8", newline="").write(s.replace("본문 하나", "본문 둘", 1))' "$W/$E1/design.md"
g add -- "$E1/design.md" && g commit -qm "E1 설계 본문 고침" && push_br feature/tm-e1
check 1 "13: 승인 뒤 설계 본문을 고치면 구현 묶음이 멈춘다" --job E1 --stage implement --plan 1
assert_contains "$(err)" "낡음" "13: 사유에 낡음"
assert_eq "$(status "$T/s.json")" "0" "13: 상태 계산 종료 코드 0"
assert_eq "$(stage_of E1)" "설계 중" "13: 상태는 설계 중으로 돌아간다"
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "1" "13: human-check 1"
assert_eq "$(grep -c '^낡음 — - spec 승인' "$T/led.txt")" "1" "13: spec 승인 줄이 낡음이다"
assert_contains "$(js "$T/s.json" "[b['notes'] for b in r['blocks'] if b['id']=='E1']")" "받은 뒤 바뀜: implement-plan-1-1.md — $E1/design.md" "13: 본문을 실제로 고치면 받은 뒤 바뀜이고 design.md 를 짚는다(K13 의 낡음 쪽)"
g revert --no-edit HEAD >/dev/null && push_br feature/tm-e1
check 0 "13: 되돌리면 구현 묶음이 다시 나간다(양성 대조)" --job E1 --stage implement --plan 1
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "13: 되돌리면 human-check 0"
assert_eq "$(status "$T/s.json") $(stage_of E1)" "0 구현 끝" "13: 되돌리면 본문이 받은 head 와 같아 받음 줄이 그대로 서서 상태는 구현 끝이다(K13 — 받은 뒤 design.md 를 건드린 커밋이 있어도 본문이 같으면 낡음이 아니다)"
assert_eq "$(js "$T/s.json" "[n for b in r['blocks'] if b['id']=='E1' for n in b['notes'] if '받은 뒤 바뀜' in n]")" "[]" "13: 본문이 같으면 「받은 뒤 바뀜」 알림이 없다(K13)"

python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read(); assert "미룬 것 하나" in s; open(p, "w", encoding="utf-8", newline="").write(s.replace("미룬 것 하나", "미룬 것 둘", 1))' "$W/$E1/design.md"
g add -- "$E1/design.md" && g commit -qm "E1 설계 미룸 고침" && push_br feature/tm-e1
check 0 "14: 승인 뒤 미룸 절만 고친 것은 그대로 나간다" --job E1 --stage implement --plan 1
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "14: human-check 도 0"
assert_eq "$(grep -c '^낡음' "$T/led.txt")" "0" "14: 낡음이 없다"
g revert --no-edit HEAD >/dev/null && push_br feature/tm-e1

g checkout -q -b feature/tm-e2 main && push_br feature/tm-e2
check 1 "15: 설계 없는 흐름은 흐름 승인 없이 묶음이 멈춘다" --job E2 --stage implement
assert_contains "$(err)" '`흐름 승인` 줄이 없다' "15: 사유"
put src/e2/x.md "산출물" && g commit -qm "E2 산출물" && hand_result E2 implement - 1 "산출물: src/e2/x.md"
assert_eq "$(rcheck --job E2 --result implement-1.md)" "1" "15: 흐름 승인 없이는 결과도 받지 않는다"
assert_contains "$(reasons)" '`흐름 승인` 줄이 없다' "15: 결과 사유"
approved "흐름 승인" E2 - - 2026-03-07 && push_br feature/tm-e2
check 0 "16: 흐름 승인이 있으면 묶음이 나간다" --job E2 --stage implement
assert_eq "$(rcheck --job E2 --result implement-1.md)" "0" "16: 결과도 받는다"

# ══ 2. 지어낸 줄 × 세 자리(E3) ══
mk_e3() {  # 새 E3 과제 브랜치 — 설계 · plan-1.md · 끝까지 쓴 implement-plan-1-1.md. 앞의 같은 이름 브랜치는 지운다
  g checkout -q main
  if g rev-parse -q --verify feature/tm-e3 >/dev/null; then g branch -q -D feature/tm-e3; g push -q origin --delete feature/tm-e3; g fetch -q --prune origin; fi
  g checkout -q -b feature/tm-e3 main
  put "$E3/design.md" "$(printf '# 설계\n\n본문 하나\n\n## Acceptance Criteria\n\n- AC1: 자리표시\n')"
  put "$E3/plan-1.md" "$(printf '# 계획\n\n### Task 1: 자리표시\n\nAC1 을 만든다.\n')"
  g commit -qm "E3 설계 · 계획" && hand_result E3 implement 1 1 "AC1: 구현됨 — 자리표시"
}
hd() {  # hd <종류> [계획] — 지금 커밋된 본문의 질문 머리(ask-head 의 표준 출력)
  local a=(--human "$1" --roadmap "$RM" --job E3)
  [ -z "${2:-}" ] || a+=(--plan "$2")
  (cd "$W" && python3 "$CL" ask-head "${a[@]}" 2>/dev/null)
}
rend() {  # rend <종류> <날짜> <라벨> <파일> <판> <세션> <키> — human_lines.render 의 꼴로 줄을 짓는다
  python3 - "$S" "$@" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import human_lines as H
a = sys.argv[2:]
print(H.render(a[0], a[1], a[2], a[3], a[4], a[5], a[6]))
PY
}
rev_of() { printf '%s' "${1##*@}"; }
key_now() { printf '%s#1' "$(cat "$T/entry.txt")"; }
plant() {  # plant <줄…> — E3 INTENT.md 에 손으로 줄을 적어 커밋해 올린다
  local l
  for l in "$@"; do decide E3 "$l" || return 1; done
  g add -- "$E3/INTENT.md" && g commit -qm "지어낸 줄" && push_br feature/tm-e3
}
unplant() { g revert --no-edit "$1..HEAD" >/dev/null && push_br feature/tm-e3; }   # unplant <표지 커밋> — 그 뒤 커밋을 모두 되돌린다
trio() {  # trio <이름> <spec|plan> <판정> <사유 조각> <줄 수> — 세 자리가 모두 지나지 못하고, 사유가 그 줄 하나 탓이다
  local name="$1" which="$2" verdict="$3" frag="$4" n="$5" cause="${6:-}" kind other stage
  if [ "$which" = "spec" ]; then kind="spec 승인"; other="계획 검토"; stage="plan"; else kind="계획 검토"; other="spec 승인"; stage="implement"; fi
  check 1 "${name}: 시작 묶음(${stage})이 멈춘다" --job E3 --stage "$stage" --plan 1
  assert_contains "$(err)" "\`${kind}\` 줄이 지나지 못했다" "${name}: 묶음 사유가 지어낸 종류(${kind})를 짚는다"
  assert_contains "$(err)" "$verdict" "${name}: 묶음 사유에 ${verdict}"
  assert_eq "$(rcheck --job E3 --result implement-plan-1-1.md)" "1" "${name}: 결과 대조가 거절한다"
  assert_eq "$(grep -c '^- 결과 받음' "$T/c.txt")" "0" "${name}: 받음 줄이 없다"
  assert_contains "$(reasons)" "\`${kind}\` 줄이 지나지 못했다" "${name}: 결과 대조 사유가 지어낸 종류(${kind})를 짚는다"
  assert_contains "$(reasons)" "$verdict" "${name}: 결과 대조 사유에 ${verdict}"
  assert_eq "$(led human-check --roadmap "$RM" --job E3)" "1" "${name}: human-check 가 1"
  assert_eq "$(grep -c "^${verdict} — - ${kind} · " "$T/led.txt")" "$n" "${name}: 지어낸 줄이 표의 판정(${verdict})으로 시작한다"
  assert_eq "$(grep -c "^지남 — - ${kind} · " "$T/led.txt")" "0" "${name}: 그 종류의 줄이 지남으로 나오지 않는다"
  assert_eq "$(grep -c "^지남 — - ${other} · " "$T/led.txt")" "1" "${name}: 먼저 둔 다른 관문(${other})의 진짜 줄은 지남이다"
  assert_contains "$(cat "$T/led.txt")" "$frag" "${name}: human-check 사유 글"
  [ -z "$cause" ] || assert_contains "$(cat "$T/led.txt")" "$cause" "${name}: 사유가 이 원인(${cause})을 가린다"
}
passes() {  # passes <이름> — 같은 준비에서 진짜 줄이 둘 다 있으면 세 자리가 모두 0(양성 대조)
  local name="$1"
  check 0 "${name}: 시작 묶음(plan)이 나간다" --job E3 --stage plan --plan 1
  check 0 "${name}: 시작 묶음(implement)이 나간다" --job E3 --stage implement --plan 1
  assert_eq "$(rcheck --job E3 --result implement-plan-1-1.md)" "0" "${name}: 결과 대조를 지난다"
  assert_eq "$(grep -c '^- 결과 받음' "$T/c.txt")" "1" "${name}: 받음 줄이 하나 난다"
  assert_eq "$(led human-check --roadmap "$RM" --job E3)" "0" "${name}: human-check 0"
  assert_eq "$(grep -c '^지남 — ' "$T/led.txt")" "2" "${name}: 두 줄 모두 지남"
  assert_eq "$(grep -c '^줄 없음' "$T/led.txt")" "0" "${name}: 줄 없음이 없다"
}

# ── 2a. spec 승인 줄을 지어낸다. 다른 관문의 진짜 줄(계획 검토)을 먼저 둔다 ──
mk_e3 && approved "계획 검토" E3 1 - 2026-03-11 && push_br feature/tm-e3 && ok "S: 준비 — E3 에 진짜 계획 검토 줄만 있다" || no "S: 준비"
check 1 "S0: 준비의 음성 — spec 승인 줄이 없으면 plan 묶음이 멈춘다" --job E3 --stage plan --plan 1
assert_contains "$(err)" '`spec 승인` 줄이 없다' "S0: 사유는 spec 승인 줄 없음"
assert_eq "$(led human-check --roadmap "$RM" --job E3)" "1" "S0: human-check 도 1 — 자취가 있는데 spec 승인 줄이 없다"
assert_contains "$(cat "$T/led.txt")" '줄 없음 — `spec 승인` 줄' "S0: spec 승인 줄 없음"
assert_eq "$(grep -c '^지남 — - 계획 검토' "$T/led.txt")" "1" "S0: 진짜 계획 검토 줄은 지남이다"

SPECKIND="spec 승인"
M="$(g rev-parse HEAD)"
plant "- ${SPECKIND} · 2026-03-12 · 「${PASSL}」"
trio "S1 손으로 쓴 줄" spec "근거 없음" "근거 칸이 없거나 줄 꼴이 아니다" 1
unplant "$M"

M="$(g rev-parse HEAD)"; H="$(hd "$SPECKIND")"
plant "$(rend "$SPECKIND" 2026-03-12 "$PASSL" design.md "$(rev_of "$H")" "$SID" "ffffffff-ffff-4fff-8fff-ffffffffffff#1")"
trio "S2 없는 항목" spec "어긋남" "세션 기록에 없다" 1
unplant "$M"

M="$(g rev-parse HEAD)"; H="$(hd "$SPECKIND")"
answer "E1 @$(rev_of "$H") — 다른 과제의 질문" "$PASSL"
plant "$(rend "$SPECKIND" 2026-03-12 "$PASSL" design.md "$(rev_of "$H")" "$SID" "$(key_now)")"
trio "S3 다른 과제의 답" spec "어긋남" "시작하지 않는다" 1
unplant "$M"

M="$(g rev-parse HEAD)"; H="$(hd "$SPECKIND")"
answer "${H} — 설계를 승인할까요" "수정 필요"
plant "$(rend "$SPECKIND" 2026-03-12 "$PASSL" design.md "$(rev_of "$H")" "$SID" "$(key_now)")"
trio "S4 라벨만 바꾼 줄" spec "어긋남" "사람이 고른 라벨은 「수정 필요」" 1
unplant "$M"

M="$(g rev-parse HEAD)"; H="$(hd "$SPECKIND")"
answer "${H} — 설계를 승인할까요" "수정 필요" --question "다음 에픽도 함께 시작할까요" --label "$PASSL"
plant "$(rend "$SPECKIND" 2026-03-12 "$PASSL" design.md "$(rev_of "$H")" "$SID" "$(cat "$T/entry.txt")#2")"
trio "S5 같은 호출의 다른 질문에서 고른 라벨" spec "어긋남" "시작하지 않는다" 1
unplant "$M"

M="$(g rev-parse HEAD)"; H="$(hd "$SPECKIND")"
answer "${H} — 설계를 승인할까요" "$PASSL"
plant "$(rend "$SPECKIND" 2026-03-12 "$PASSL" design.md "$(rev_of "$H")" "$SID" "$(key_now)")" \
      "$(rend "$SPECKIND" 2026-03-13 "$PASSL" design.md "$(rev_of "$H")" "$SID" "$(key_now)")"
trio "S6 같은 근거를 두 번 쓴 줄" spec "어긋남" "같은 답을 근거로 쓴 줄이 또 있다" 2
unplant "$M"

M="$(g rev-parse HEAD)"; H="$(hd "$SPECKIND")"
answer "${H} — 설계를 승인할까요" "$PASSL"
KEY7="$(key_now)"
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8", newline="").read(); assert "본문 하나" in s; open(p, "w", encoding="utf-8", newline="").write(s.replace("본문 하나", "본문 둘", 1))' "$W/$E3/design.md"
g add -- "$E3/design.md" && g commit -qm "E3 설계 본문 고침" && push_br feature/tm-e3
plant "$(rend "$SPECKIND" 2026-03-12 "$PASSL" design.md "$(g rev-parse HEAD | cut -c1-8)" "$SID" "$KEY7")"
trio "S7 진짜 옛 답 · 판만 새 커밋" spec "어긋남" "시작하지 않는다" 1
unplant "$M"

M="$(g rev-parse HEAD)"; H="$(hd "$SPECKIND")"
(python3 "$SFX" answer --config "$CLAUDE_CONFIG_DIR" --session "$SIDX" --entrypoint sdk-cli --question "${H} — 설계를 승인할까요" --label "$PASSL" > "$T/entry.txt")
plant "$(rend "$SPECKIND" 2026-03-12 "$PASSL" design.md "$(rev_of "$H")" "$SIDX" "$(key_now)")"
trio "S8 프로그램이 대신 답한 세션의 답(sdk-cli)" spec "어긋남" "사람이" 1 "sdk-cli"
unplant "$M"

for how in "--who hook" "--empty"; do
  M="$(g rev-parse HEAD)"; H="$(hd "$SPECKIND")"
  # shellcheck disable=SC2086
  answer "${H} — 설계를 승인할까요" "$PASSL" $how
  plant "$(rend "$SPECKIND" 2026-03-12 "$PASSL" design.md "$(rev_of "$H")" "$SID" "$(key_now)")"
  case "$how" in
    "--empty") trio "S9 고른 답이 빈 결과(${how})" spec "어긋남" "세션 기록에 없다" 1 ;;
    *) trio "S9 훅이 채운 답(${how})" spec "어긋남" "사람이" 1 "hook" ;;
  esac
  unplant "$M"
done

for how in "--who other" "--entrypoint fixture_other" "--drop entrypoint"; do
  M="$(g rev-parse HEAD)"; H="$(hd "$SPECKIND")"
  # shellcheck disable=SC2086
  answer "${H} — 설계를 승인할까요" "$PASSL" $how
  plant "$(rend "$SPECKIND" 2026-03-12 "$PASSL" design.md "$(rev_of "$H")" "$SID" "$(key_now)")"
  case "$how" in
    "--who other") cause="fixture_other" ;;
    "--entrypoint fixture_other") cause="fixture_other" ;;
    *) cause="entrypoint" ;;
  esac
  trio "S10 모르는 출처(${how})" spec "확인 못 함" "질문 창으로 다시 승인받는다" 1 "$cause"
  unplant "$M"
done

# 양성 대조 — 같은 준비(진짜 계획 검토 줄)에서 진짜 spec 승인 줄을 적으면 세 자리가 0
approved "$SPECKIND" E3 - - 2026-03-12 && push_br feature/tm-e3
passes "S+"

# ── 2b. 계획 검토 줄을 지어낸다. 다른 관문의 진짜 줄(spec 승인)을 먼저 둔다 ──
mk_e3 && approved "$SPECKIND" E3 - - 2026-03-12 && push_br feature/tm-e3 && ok "P: 준비 — E3 에 진짜 spec 승인 줄만 있다" || no "P: 준비"
PLANKIND="계획 검토"
check 1 "P0: 준비의 음성 — 계획 검토 줄이 없으면 implement 묶음이 멈춘다" --job E3 --stage implement --plan 1
assert_contains "$(err)" '`계획 검토` 줄' "P0: 사유는 계획 검토 줄 없음"
check 0 "P0: 같은 준비에서 plan 묶음은 나간다" --job E3 --stage plan --plan 1

M="$(g rev-parse HEAD)"
plant "- ${PLANKIND} · 2026-03-13 · 「계획대로 구현한다」"
trio "P1 손으로 쓴 줄" plan "근거 없음" "근거 칸이 없거나 줄 꼴이 아니다" 1
unplant "$M"

M="$(g rev-parse HEAD)"; H="$(hd "$PLANKIND" 1)"
answer "${H} — 계획대로 구현할까요" "수정 필요"
plant "$(rend "$PLANKIND" 2026-03-13 "계획대로 구현한다" plan-1.md "$(rev_of "$H")" "$SID" "$(key_now)")"
trio "P2 라벨만 바꾼 줄" plan "어긋남" "사람이 고른 라벨은 「수정 필요」" 1
unplant "$M"

M="$(g rev-parse HEAD)"
put "$E3/plan-1.md" "$(printf '# 계획\n\n### Task 1: 자리표시\n\nAC1 을 만든다. 고침.\n')"
put "$E3/plan-2.md" "$(printf '# 계획 둘\n\n### Task 1: 둘째\n\nAC1 도 부른다.\n')"
g commit -qm "E3 계획 1 고침 · 계획 2" && push_br feature/tm-e3
H="$(hd "$PLANKIND" 1)"; H="${H/ plan 1 @/ plan 2 @}"   # 계획 2 의 브랜치가 없어 ask-head 로는 못 받는다 — 머리 꼴만 바꾼다
case "$H" in "E3 plan 2 @"????????) ok "P3: 준비 — 머리가 계획 2 의 꼴이다" ;; *) no "P3: 준비 — 머리가 계획 2 의 꼴이 아니다: ${H}" ;; esac
answer "${H} — 계획대로 구현할까요" "계획대로 구현한다"
plant "$(rend "$PLANKIND" 2026-03-13 "계획대로 구현한다" plan-1.md "$(rev_of "$H")" "$SID" "$(key_now)")"
trio "P3 다른 계획의 답" plan "어긋남" "시작하지 않는다" 1
unplant "$M"

# 깨진 human_gate 값은 관문을 열지 않는다 — 설정을 읽지 못한 것은 검사 불가(3)이고 묶음 · 받음 줄은 나오지 않는다
g checkout -q main && printf -- '---\nhuman_gate: 아무거나\n---\n' > "$W/.devbrew.md" && g add -- .devbrew.md && g commit -qm "깨진 human_gate" && push_main && g checkout -q feature/tm-e3
check 3 "P4: 깨진 human_gate 값이면 시작 묶음이 검사 불가(3)로 멈춘다" --job E3 --stage implement --plan 1
assert_contains "$(err)" "human_gate" "P4: 사유가 그 설정을 짚는다"
assert_eq "$(rcheck --job E3 --result implement-plan-1-1.md)" "3" "P4: 결과 대조도 3"
assert_eq "$(grep -c '^- 결과 받음' "$T/c.txt")" "0" "P4: 받음 줄이 없다"
assert_not_contains "$(cat "$T/b.err" "$T/c.txt")" "대조가 꺼져 있다" "P4: 깨진 값이 관문을 끄지 않는다"
g checkout -q main && g revert --no-edit HEAD >/dev/null && push_main && g checkout -q feature/tm-e3
check 0 "P4: 설정을 되돌리면 같은 묶음이 나간다(양성 대조)" --job E3 --stage plan --plan 1

approved "$PLANKIND" E3 1 - 2026-03-13 && push_br feature/tm-e3
passes "P+"

use_repo "$T0/a"

# ══ 3. 옛 형식이 그대로다(AC21) ══
use_repo "$T0/old"
mkdir -p "$W/docs" && cp -R "$T0/a/repo/docs/tv" "$W/docs/tv"
git init -q --bare -b main "$T/origin.git" && git init -q -b main "$W" && g remote add origin "$T/origin.git"
g add -- docs && g commit -qm "brief" && g push -q origin main && g fetch -q origin && g remote set-head origin main
{ printf '# 옛 표\n\n## 분해안\n\n| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |\n|---|---|---|---|---|---|---|---|---|---|---|\n'
  printf '%s\n' \
    '| P1 | 읽는 법 정하기 | 결정 | 읽는 법을 정한다 | 한다 정함 / 안 한다 구현 | 없음 | 없음 | 없음 | S3 · OQ1 | 없음 | 없음 |' \
    '| A1 | 옛 에픽 | 묶음 | 옛 의도 | 한다 가 / 안 한다 나 | 없음 | feature/old-a1 | src/old/ | C1 · D2 · C3 · S1 · S2 · S4 | 없음 | 없음 |'
} > "$T/old-table.md"
ORM="docs/rmold/roadmap.md"
(cd "$W" && python3 "$RW" create --brief docs/tv/brief.md --audit docs/tv/brief.audit.md --plan-table "$T/old-table.md" --out docs/rmold \
   --title "옛 형식" --date 2026-11-14 --approval "이대로 승인") > "$T/out.txt" 2>&1 && ok "o0: 옛 형식 로드맵을 세웠다" || { no "o0: 옛 형식 로드맵 — $(cat "$T/out.txt")"; finish; exit 1; }
assert_not_contains "$(sed -n 1,8p "$W/$ORM")" "layout:" "o0: 머리말에 layout 이 없다"
g add -- docs && g commit -qm "옛 로드맵" && push_main
g checkout -q -b feature/old-a1 main
OSPEC="docs/superpowers/specs/old-a1-design.md"
put "$OSPEC" "$(printf -- '---\nsource_interview: docs/rmold/A1.md\n---\n\n# 설계\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| C1 | 반영 | §1 |\n\n## Acceptance Criteria\n\n- AC1 가\n\n## 지휘 기록\n')"
g commit -qm "옛 설계" && push_br feature/old-a1
cp "$W/$OSPEC" "$T/spec-orig.md"
ostat() { (cd "$W" && python3 "$RS" "$ORM" --json) > "$T/o.json" 2>/dev/null; js "$T/o.json" "[b['reason'] for b in r['blocks'] if b['id']=='A1'][0]"; }
OLDLINE="- spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」"

assert_eq "$(led record --spec "$W/$OSPEC" --approval --date 2026-11-20 --choice "승인 — 계획 담당자에게")" "0" "o1: 옛 인자로 승인 줄을 적는다"
assert_eq "$(tail -n 1 "$W/$OSPEC")" "$OLDLINE" "o1: 마지막 줄이 판 · 근거 칸 없는 옛 꼴 그대로다"
assert_eq "$(led record --spec "$W/$OSPEC" --line "계획 검토 · 2026-11-20 · 「글」")" "0" "o2: --line 으로 계획 검토 줄을 적는다"
assert_eq "$(tail -n 1 "$W/$OSPEC")" "- 계획 검토 · 2026-11-20 · 「글」" "o2: 그 줄이 적혔다"
g add -- "$OSPEC" && g commit -qm "옛 승인 줄" && push_br feature/old-a1

claim_old() { [ "$(led claim --roadmap "$ORM" --session "$SID")" = "0" ]; }
assert_eq "$(led record --human "spec 승인" --roadmap "$ORM" --job A1)" "2" "o3: record --human 은 2"
assert_contains "$(cat "$T/led.txt")" "team 형식" "o3: record --human 출력에 team 형식"
assert_eq "$(led ask-head --human "spec 승인" --roadmap "$ORM" --job A1)" "2" "o3: ask-head 는 2"
assert_contains "$(cat "$T/led.txt")" "team 형식" "o3: ask-head 출력에 team 형식"
assert_eq "$(led human-check --roadmap "$ORM" --job A1)" "2" "o3: human-check 는 2"
assert_contains "$(cat "$T/led.txt")" "team 형식" "o3: human-check 출력에 team 형식"

WANT4="spec 승인됨(2026-11-20) · 계획 없음"
assert_contains "$(ostat)" "$WANT4" "o4: 근거 칸 없는 줄이 옛 형식에서는 지금처럼 승인으로 세어진다"
OBASE="$(ostat)"
for v in 끔 켬 끔; do
  g checkout -q main && printf -- '---\nhuman_gate: %s\n---\n' "$v" > "$W/.devbrew.md" && g add -- .devbrew.md && g commit -qm "human_gate ${v}" && push_main && g checkout -q feature/old-a1
  cp "$T/spec-orig.md" "$T/spec-${v}.md"
  assert_eq "$(led record --spec "$T/spec-${v}.md" --approval --date 2026-11-20 --choice "승인 — 계획 담당자에게")" "0" "o5: human_gate ${v} — o1 이 0"
  assert_eq "$(tail -n 1 "$T/spec-${v}.md")" "$OLDLINE" "o5: human_gate ${v} — 적힌 줄이 같다"
  assert_eq "$(ostat)" "$OBASE" "o5: human_gate ${v} — o4 의 근거가 같다"
  assert_eq "$(led record --human "spec 승인" --roadmap "$ORM" --job A1)" "2" "o5: human_gate ${v} — 옛 형식의 record --human 은 여전히 2"
done

claim_old && ok "o6: 준비 — 옛 로드맵의 지휘 표지" || no "o6: 지휘 표지 — $(cat "$T/led.txt")"
assert_eq "$(led add --roadmap "$ORM" --session "$SID" --section "쌓인 기록" --cells "A1 · 지휘 기록 · spec 승인 · 2026-11-20 · 「승인」")" "0" "o6: 쌓인 기록 1 — $(cat "$T/led.txt")"
assert_eq "$(led add --roadmap "$ORM" --session "$SID" --section "쌓인 기록" --cells "A1 · 지휘 기록 · 계획 검토 · 2026-11-20 · 「글」")" "0" "o6: 쌓인 기록 2"
cp "$T/spec-orig.md" "$T/spec-flush.md"
assert_eq "$(led pending --roadmap "$ORM")" "0" "o6: flush 전 pending 종료 코드"
assert_contains "$(cat "$T/led.txt")" "spec 승인 · 2026-11-20 · 「승인」" "o6: flush 전에는 쌓인 기록에 두 줄이 있다(비었다는 단언의 양성 짝)"
assert_contains "$(cat "$T/led.txt")" "계획 검토 · 2026-11-20 · 「글」" "o6: flush 전 둘째 줄"
assert_eq "$(led flush --roadmap "$ORM" --session "$SID" --epic A1 --spec "$T/spec-flush.md")" "0" "o6: 옛 형식의 flush 는 0"
assert_contains "$(cat "$T/spec-flush.md")" "- spec 승인 · 2026-11-20 · 「승인」" "o6: spec 승인 줄이 옮겨졌다"
assert_contains "$(cat "$T/spec-flush.md")" "- 계획 검토 · 2026-11-20 · 「글」" "o6: 계획 검토 줄이 옮겨졌다"
assert_eq "$(led pending --roadmap "$ORM")" "0" "o6: pending 종료 코드"
assert_not_contains "$(cat "$T/led.txt")" "spec 승인" "o6: 쌓인 기록이 비었다"

use_repo "$T0/a"
finish
