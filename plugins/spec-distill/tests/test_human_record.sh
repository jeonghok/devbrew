#!/usr/bin/env bash
# conductor_ledger.py ask-head · record --human — 사람 줄은 지휘 세션 기록의 질문 창 답에서만 적고(AC5 · AC7), 머리는 커밋된 본문의
# 판으로 내며(AC4), 세션 기록을 가를 수 없으면 3 과 끄는 길을 낸다(AC6). 옛 인자(--approval · --line · flush)로는 사람 줄을 적지 못한다(AC3).
# 기록은 뒤에서부터 읽으므로 아래 차례에 뜻이 있다 — 뒤에 덧붙인 답이 앞의 답을 가린다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_human_record.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'chmod -R u+rwX "$T" 2>/dev/null; rm -rf "$T"' EXIT
. "$ROOT/plugins/spec-distill/tests/fixtures/team_repo.sh"

repo_copy "$T" team && claim && ok "팀 레포와 지휘 표지" || { no "준비 실패 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
E1="$TM/jobs/E1"
E2="$TM/jobs/E2"
intent_tail() { tail -n 1 "$W/$E1/INTENT.md"; }
intent_lines() { wc -l < "$W/$E1/INTENT.md" | tr -d ' '; }
snap() { cksum < "$W/$E1/INTENT.md"; }
out() { cat "$T/led.txt"; }
rec() { led record --human "spec 승인" --roadmap "$RM" --job E1; }
short() { printf '%s' "$1" | cut -c1-8; }
push_main() { g push -q origin main && g fetch -q origin; }
unreadable_call() {  # unreadable_call <세션> <질문 목록 자리의 글> — 질문 목록이 JSON 이 아닌 글인 질문 창 호출과 그 결과를 덧붙인다
  python3 - "$SFX" "$CLAUDE_CONFIG_DIR" "$1" "$2" <<'PY'
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]).parent))
import session_fixture as F
config, session, text = sys.argv[2], sys.argv[3], sys.argv[4]
F.add_answer(config, session, [("자리표시", "자리표시")])
path = F.record_path(config, session)
rows = [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l]
rows[-2]["message"]["content"][0]["input"]["questions"] = text
path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
PY
}
PASSL="승인 — 계획 담당자에게"
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "$(printf '# 설계\n\n본문 하나\n\n## 지휘 기록\n')" && g commit -qm "E1 설계"; C1="$(g rev-parse HEAD)"
HEAD1="E1 @$(short "$C1")"
answer "준비 — 머리 없는 질문" "아무 글"   # 지휘 세션의 기록 파일이 있게 한다(없으면 3 — 「확인 못 함」)

# 1 — 머리
assert_eq "$(led ask-head --human "spec 승인" --roadmap "$RM" --job E1)" "0" "AC4: ask-head 종료 코드 0"
assert_eq "$(out)" "$HEAD1" "AC4: 출력이 정확히 머리 한 줄 <과제> @<판>"

# 2 — 답이 없다
S0="$(snap)"
assert_eq "$(rec)" "1" "AC5: 머리로 시작하는 답이 없으면 1"
assert_contains "$(out)" "$HEAD1" "AC5: 사유가 기다린 머리를 보인다"
assert_eq "$(g status --short -- "$TM")" "" "AC5: 답이 없으면 INTENT.md 가 그대로다"

# 3 — 머리 앞에 글자가 붙은 질문
answer " $HEAD1 — 질문" "$PASSL"
answer "**$HEAD1** 질문" "$PASSL"
assert_eq "$(rec)" "1" "AC5: 머리 앞에 공백 · 굵게 표시가 붙은 질문의 답으로는 쓰지 않는다"
assert_contains "$(out)" "$HEAD1" "AC5: 그때도 기다린 머리를 그대로 보인다"
assert_eq "$(snap)" "$S0" "AC5: 머리 앞 글자 — 그대로"

# 4 — 다른 세션이 보낸 글 · 알림 · 사람이 친 말
for name in peer notification typed; do
  python3 "$SFX" text --config "$CLAUDE_CONFIG_DIR" --session "$SID" --name "$name" --text "$HEAD1 — 질문 「${PASSL}」"
done
assert_eq "$(rec)" "1" "AC5: 글 · 알림 · 친 말에 머리와 라벨 글자가 있어도 답이 아니다"
assert_contains "$(out)" "$HEAD1" "AC5: 글 · 알림 · 친 말 — 기다린 머리"

# 5 — 하위 agent 의 기록 · 곁가지
answer "$HEAD1 — 질문" "$PASSL" --subagent
answer "$HEAD1 — 질문" "$PASSL" --sidechain
assert_eq "$(rec)" "1" "AC5: 하위 agent 의 기록 · 곁가지 항목의 답으로는 쓰지 않는다"
assert_contains "$(out)" "$HEAD1" "AC5: 하위 agent · 곁가지 — 기다린 머리"

# 6 — 다른 과제 번호 · 번호는 같고 판이 다른 머리
answer "E3 @$(short "$C1") — 질문" "$PASSL"
answer "E1 @0123abcd — 질문" "$PASSL"
assert_eq "$(rec)" "1" "AC5: 다른 과제 · 다른 판(번호가 같은 다른 과제의 파일)의 답으로는 쓰지 않는다"
assert_contains "$(out)" "$HEAD1" "AC5: 다른 과제 · 다른 판 — 기다린 머리"

# 6b — 한 호출에 글이 같은 질문 둘(J33)
answer "E3 @$(short "$C1") — 질문" "$PASSL" --question "E3 @$(short "$C1") — 질문" --label "$PASSL"
assert_eq "$(rec)" "1" "AC5: 다른 머리의 같은 글 질문 둘 — 1"
assert_not_contains "$(out)" "같은 글의 질문이 둘인 호출" "AC5: 다른 머리의 호출 때문에는 같은 글 알림을 붙이지 않는다"
answer "$HEAD1 — 질문" "$PASSL" --question "$HEAD1 — 질문" --label "$PASSL"
assert_eq "$(rec)" "1" "AC5: 그 머리의 같은 글 질문 둘 — 1"
assert_contains "$(out)" "같은 글의 질문이 둘인 호출이 있어 쓰지 않았다" "AC5: 그 머리의 같은 글 질문 둘은 조용히 넘기지 않는다(J33)"

# 7 — 같은 호출의 다른 질문에서 고른 라벨
answer "$HEAD1 — 설계를 승인할까요" "수정 필요" --question "다음 에픽도 함께 시작할까요" --label "$PASSL"
assert_eq "$(rec)" "1" "AC5: 같은 호출의 다른 질문에서 고른 라벨로는 쓰지 않는다"
assert_contains "$(out)" "사람이 고른 라벨: 「수정 필요」" "AC5: 머리가 있는 질문의 고른 라벨을 보인다"
assert_eq "$(snap)" "$S0" "AC5: 통과 라벨이 아니면 그대로"

# 8 — 사람이 아니라고 잰 답은 지나간다(7 의 답이 고른 답이다)
for how in "--who denied" "--who hook" "--entrypoint sdk-cli" "--empty"; do
  # shellcheck disable=SC2086
  answer "$HEAD1 — 질문" "$PASSL" $how
  assert_eq "$(rec)" "1" "AC5: 사람이 아닌 답(${how}) — 1"
  assert_contains "$(out)" "「수정 필요」" "AC5: 사람이 아닌 답(${how})은 지나가고 앞의 답을 고른다"
done
assert_eq "$(snap)" "$S0" "AC5: 사람이 아닌 답 — 그대로"

# 9 — 가를 수 없는 답은 3(AC6 — 조용히 1 이 되지 않는다)
for how in "--who unknown" "--who other" "--entrypoint fixture_other" "--drop entrypoint" "--drop answers" \
           "--drop sourceToolAssistantUUID" "--drop isSidechain"; do
  # shellcheck disable=SC2086
  answer "$HEAD1 — 질문" "$PASSL" $how
  assert_eq "$(rec)" "3" "AC6: 가를 수 없는 답(${how}) — 3"
  assert_contains "$(out)" "확인 못 함" "AC6: 가를 수 없는 답(${how}) — 확인 못 함"
  assert_contains "$(out)" "human_gate: 끔" "AC6: 가를 수 없는 답(${how}) — 끄는 길"
done
assert_eq "$(snap)" "$S0" "AC6: 가를 수 없는 답 — 그대로"

# 10 — 기록을 읽지 못한다
REC="$CLAUDE_CONFIG_DIR/projects/fixture/${SID}.jsonl"
chmod 000 "$REC"
if [ -r "$REC" ]; then
  ok "AC6: 읽지 못하는 기록 — 이 사용자는 권한 없이도 읽어 건너뛴다(root)"
else
  assert_eq "$(rec)" "3" "AC6: 기록 파일을 읽지 못하면 3"
  assert_contains "$(out)" "확인 못 함" "AC6: 읽지 못함 — 확인 못 함"
fi
chmod 644 "$REC"

# 11 — 쓴다. 날짜는 답한 시각에서(J28)
answer "$HEAD1 — 질문" "${PASSL} (권장)" --when 2026-11-20T12:00:00.000Z; U1="$(cat "$T/entry.txt")"
assert_eq "$(rec)" "0" "AC5: 통과 라벨(「(권장)」 꼬리)인 사람 답이면 0"
assert_eq "$(intent_tail)" "- spec 승인 · 2026-11-20 · 「${PASSL}」 · design.md@$(short "$C1") · 근거 ${SID}:${U1}#1" \
  "AC7: 줄의 꼴 · 날짜는 답한 시각 · 판 · 근거"
assert_contains "$(out)" "적었다(커밋은 리더가)" "AC7: 쓴 자리를 알리고 커밋은 하지 않는다"
assert_contains "$(g status --short -- "$TM")" "$E1/INTENT.md" "AC7: 커밋되지 않았다(리더가 커밋한다)"
N11="$(intent_lines)"

# 12 — 같은 답으로 다시
assert_eq "$(rec)" "0" "AC5: 같은 줄이 이미 있으면 0"
assert_contains "$(out)" "이미 있어 쓰지 않았다" "AC5: 이미 있어 쓰지 않았다"
assert_eq "$(intent_lines)" "$N11" "AC5: 같은 줄을 두 번 쓰지 않는다"

# 13 — 날짜 인자는 없다
S11="$(snap)"
assert_eq "$(led record --human "spec 승인" --roadmap "$RM" --job E1 --date 2026-11-25)" "2" "AC5: --date 는 사용법 어긋남(J28)"
assert_eq "$(snap)" "$S11" "AC5: --date — 그대로"

# 14 — 이어받은 세션에 복사된 같은 답은 한 번만 근거가 된다(J3)
g add -- "$E1/INTENT.md" && g commit -qm "spec 승인 줄"
led takeover --roadmap "$RM" --session "$SID2" > /dev/null
python3 "$SFX" answer --config "$CLAUDE_CONFIG_DIR" --session "$SID2" --question "$HEAD1 — 질문" --label "$PASSL" \
  --entry "$U1" --when 2026-11-20T12:00:00.000Z > /dev/null
assert_eq "$(rec)" "1" "AC5: 이미 다른 줄의 근거인 답(세션이 달라도) — 1"
assert_eq "$(intent_lines)" "$N11" "AC5: 이미 근거인 답 — 그대로"

# 14b — 11 에서 적은 줄의 머리로 다시 물어 「수정 필요」 를 고르면 그 줄이 막힌다(K9 · AC11 미룸). 답은 SID 에 쓴다
led takeover --roadmap "$RM" --session "$SID" > /dev/null
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "AC11: 뒤에 고른 답이 없으면 human-check 0(양성 대조)"
answer "$HEAD1 — 다시 묻는 자리표시 질문" "수정 필요"
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "1" "AC11: 승인 뒤 같은 머리로 다른 라벨을 고르면 human-check 1"
assert_contains "$(out)" "어긋남" "AC11: 물러선 승인 — 어긋남"
assert_contains "$(out)" "그 머리로 더 뒤에 고른 답이 있다" "AC11: 물러선 승인 — 사유"
assert_eq "$(rec)" "1" "AC11: 그 뒤 다시 적으려 하면 1"
assert_contains "$(out)" "사람이 고른 라벨: 「수정 필요」" "AC11: record --human 은 가장 뒤 답을 고른다"
assert_eq "$(intent_lines)" "$N11" "AC11: 물러선 승인 — 그대로"
led takeover --roadmap "$RM" --session "$SID2" > /dev/null

# 15 — 본문에 커밋되지 않은 변경
printf '# 설계\n\n본문 고침\n\n## 지휘 기록\n' > "$W/$E1/design.md"
assert_eq "$(led ask-head --human "spec 승인" --roadmap "$RM" --job E1)" "1" "AC4: 본문이 커밋되지 않았으면 ask-head 1"
assert_contains "$(out)" "커밋되지 않은 변경" "AC4: ask-head — 커밋되지 않은 변경"
assert_eq "$(rec)" "1" "AC4: 본문이 커밋되지 않았으면 record 1"
assert_contains "$(out)" "커밋되지 않은 변경" "AC4: record — 커밋되지 않은 변경"
g checkout -q -- "$E1/design.md"

# 16 — 기록 절만 바뀐 것은 지난다
printf -- '- 결정 · 2026-11-20 · 기록 절에만 더한 줄\n' >> "$W/$E1/design.md"
assert_eq "$(led ask-head --human "spec 승인" --roadmap "$RM" --job E1)" "0" "AC4: 기록 절만 바뀌었으면 ask-head 0"
assert_eq "$(out)" "$HEAD1" "AC4: 본문만 견준다 — 머리 그대로"
g checkout -q -- "$E1/design.md"

# 17 · 18 — 쓸 브랜치가 아닌 worktree
g checkout -q main
assert_eq "$(led ask-head --human "spec 승인" --roadmap "$RM" --job E1)" "1" "AC7: 다른 브랜치에서 부르면 1"
assert_contains "$(out)" "feature/tm-e1" "AC7: 다른 브랜치 — 가야 할 브랜치 이름"
g checkout -q --detach feature/tm-e1
assert_eq "$(led ask-head --human "spec 승인" --roadmap "$RM" --job E1)" "1" "AC7: 브랜치 없는 HEAD 에서 부르면 1"
assert_contains "$(out)" "feature/tm-e1" "AC7: 브랜치 없는 HEAD — 가야 할 브랜치 이름"
assert_contains "$(out)" "브랜치 없는 HEAD" "AC7: 브랜치 없는 HEAD 라고 말한다"
g checkout -q feature/tm-e1

# 19 — 계획 검토 머리
put "$E1/plan-1.md" "# 계획 1" && put "$E1/plan-2.md" "# 계획 2" && g commit -qm "계획 둘"; C2="$(g rev-parse HEAD)"
assert_eq "$(led ask-head --human "계획 검토" --roadmap "$RM" --job E1 --plan 1)" "0" "AC4: 계획 검토 ask-head 0"
assert_eq "$(out)" "E1 plan 1 @$(short "$C2")" "AC4: 계획 검토 머리는 <과제> plan <n> @<판>"

# 20 · 21 — 이어받기 전 세션에만 있는 답은 다시 묻는다, 복사돼 있으면 적는다(J3)
answer "E1 plan 1 @$(short "$C2") — 질문" "계획대로 구현한다" --when 2026-11-21T12:00:00.000Z; U2="$(cat "$T/entry.txt")"
assert_eq "$(led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 1)" "1" "AC5: 표지의 세션 기록에 없는 답 — 1"
# 20b — 질문을 읽지 못한 호출: 그 머리의 것일 수 있으면 3(J33), 다른 글이면 그대로 1
unreadable_call "$SID2" "다른 글의 질문"
assert_eq "$(led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 1)" "1" "AC6: 다른 글로 시작하는 읽지 못한 호출 — 그대로 1"
unreadable_call "$SID2" "E1 plan 1 @$(short "$C2") — 질문"
assert_eq "$(led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 1)" "3" "AC6: 머리로 시작하는 읽지 못한 호출 — 3"
assert_contains "$(out)" "확인 못 함" "AC6: 읽지 못한 호출 — 확인 못 함"
assert_contains "$(out)" "human_gate: 끔" "AC6: 읽지 못한 호출 — 끄는 길"
python3 "$SFX" answer --config "$CLAUDE_CONFIG_DIR" --session "$SID2" --question "E1 plan 1 @$(short "$C2") — 질문" \
  --label "계획대로 구현한다" --entry "$U2" --when 2026-11-21T12:00:00.000Z > /dev/null
assert_eq "$(led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 1)" "0" "AC5: 이어받은 세션에 복사된 답 — 0"
assert_eq "$(intent_tail)" "- 계획 검토 · 2026-11-21 · 「계획대로 구현한다」 · plan-1.md@$(short "$C2") · 근거 ${SID2}:${U2}#1" \
  "AC7: 계획 검토 줄 — 이어받은 세션이 근거"
g add -- "$E1/INTENT.md" && g commit -qm "계획 검토 줄"

# 22 — 판이 같아도 계획 1 의 답으로 계획 2 줄을 쓰지 못한다
g checkout -q -b feature/tm-e1b
assert_eq "$(led ask-head --human "계획 검토" --roadmap "$RM" --job E1 --plan 2)" "0" "AC4: 계획 2 의 머리는 계획 2 의 브랜치에서"
assert_eq "$(out)" "E1 plan 2 @$(short "$C2")" "AC4: 계획 2 의 머리 — 판은 같고 계획 번호가 다르다"
assert_eq "$(led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 2)" "1" "AC5: 다른 계획을 두고 한 답 — 1"
# 22b — 이미 다른 줄의 근거인 답은 건너뛰고 더 앞의 답을 고른다
P2Q="E1 plan 2 @$(short "$C2") — 질문"
python3 "$SFX" answer --config "$CLAUDE_CONFIG_DIR" --session "$SID2" --question "$P2Q" --label "계획대로 구현한다" \
  --when 2026-11-21T12:00:00.000Z > "$T/entry.txt"; UOLD="$(cat "$T/entry.txt")"
led takeover --roadmap "$RM" --session "$SID" > /dev/null
answer "$P2Q" "계획대로 구현한다" --when 2026-11-21T13:00:00.000Z; UNEW="$(cat "$T/entry.txt")"
assert_eq "$(led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 2)" "0" "AC5: 계획 2 의 답 — SID 로 적는다"
python3 "$SFX" answer --config "$CLAUDE_CONFIG_DIR" --session "$SID2" --question "$P2Q" --label "계획대로 구현한다" \
  --entry "$UNEW" --when 2026-11-21T13:00:00.000Z > /dev/null
led takeover --roadmap "$RM" --session "$SID2" > /dev/null
assert_eq "$(led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 2)" "0" "AC5: 맨 뒤 답이 이미 근거면 더 앞의 답으로 0"
assert_contains "$(out)" "근거 ${SID2}:${UOLD}#1" "AC5: 더 앞의 답(이어받은 세션의 것)을 골랐다"
g checkout -q -- "$E1/INTENT.md"
g checkout -q feature/tm-e1

# 23 — 걸음 건너뜀(답은 SID 에 쓴다)
led takeover --roadmap "$RM" --session "$SID" > /dev/null
assert_eq "$(led ask-head --human "걸음 건너뜀" --roadmap "$RM" --job E1 --plan 1)" "0" "AC4: 건너뜀 머리"
SKIPH="$(out)"
case "$SKIPH" in "E1 @"????????) ok "AC4: 건너뜀 머리는 <과제> @<판>(계획 번호 없음)" ;; *) no "AC4: 건너뜀 머리 꼴 — ${SKIPH}" ;; esac
assert_eq "$(human "걸음 건너뜀" E1 - "계획 검토 plan 1" 2026-11-22)" "0" "AC5: 건너뜀 줄 — 0"
U23="$(cat "$T/entry.txt")"
assert_eq "$(intent_tail)" "- 걸음 건너뜀 · 2026-11-22 · 「건너뛴다」 · 계획 검토 plan 1 · INTENT.md@${SKIPH#E1 @} · 근거 ${SID}:${U23}#1" \
  "AC7: 건너뜀 줄은 관문 이름을 적는다"
N23="$(intent_lines)"

# 24 — 관문 이름을 부분 글자로 찾지 않는다
answer "${SKIPH} — 건너뛸까요" "건너뛴다"
answer "${SKIPH} — 계획 검토 plan 12 를 건너뛸까요" "건너뛴다"
assert_eq "$(led record --human "걸음 건너뜀" --roadmap "$RM" --job E1 --gate "spec 승인")" "1" "AC5: 관문 이름이 없는 질문의 답 — 1"
assert_eq "$(intent_lines)" "$N23" "AC5: 관문 이름 없음 — 그대로"
assert_eq "$(led record --human "걸음 건너뜀" --roadmap "$RM" --job E1 --gate "계획 검토 plan 1")" "0" \
  "AC5: plan 12 를 이름 붙인 답은 plan 1 의 답이 아니다 — 23 의 답을 다시 골라 0(J23)"
assert_contains "$(out)" "이미 있어 쓰지 않았다" "AC5: plan 12 — 23 의 줄이 이미 있다"
assert_contains "$(out)" "${SID}:${U23}#1" "AC5: plan 12 — 고른 답은 23 의 답이다"
assert_eq "$(intent_lines)" "$N23" "AC5: plan 12 — 그대로"

# 24b — 관문 이름이 둘 이상 든 질문(AC5 · 13796c12)
answer "${SKIPH} — spec 승인 과 계획 검토 plan 2 를 건너뛸까요" "건너뛴다"
assert_eq "$(led record --human "걸음 건너뜀" --roadmap "$RM" --job E1 --gate "spec 승인")" "1" "AC5: 관문 이름이 둘 이상인 질문의 답 — 1"
assert_contains "$(out)" "그 질문에 관문 이름이 둘 이상 있다(spec 승인 · 계획 검토 plan 2) — 관문마다 따로 묻는다" "AC5: 관문 이름 둘 — 사유"
assert_eq "$(intent_lines)" "$N23" "AC5: 관문 이름 둘 — 그대로"

# 25 — 관문과 짝이 아닌 라벨
answer "${SKIPH} — 다시 시도 plan 1 시도 3 할까요" "건너뛴다"
assert_eq "$(led record --human "걸음 건너뜀" --roadmap "$RM" --job E1 --gate "다시 시도 plan 1 시도 3")" "1" "AC5: 다시 시도 관문에 「건너뛴다」 — 1"
assert_contains "$(out)" "사람이 고른 라벨: 「건너뛴다」" "AC5: 짝이 아닌 라벨을 보인다"
g add -- "$E1/INTENT.md" && g commit -qm "건너뜀 줄"

# 26 — 설계 없는 흐름의 흐름 승인
g checkout -q -b feature/tm-e2 main
assert_eq "$(human "흐름 승인" E2 - - 2026-11-22)" "0" "AC5: 흐름 승인 줄 — 0"
assert_contains "$(tail -n 1 "$W/$E2/INTENT.md")" "- 흐름 승인 · 2026-11-22 · 「설계 없이 진행」 · INTENT.md@" "AC7: 흐름 승인 줄은 INTENT.md 에 묶인다"
g add -- "$E2/INTENT.md" && g commit -qm "흐름 승인 줄"

# 27 — 사용법
S27="$(snap)"; E27="$(cksum < "$W/$E2/INTENT.md")"
H="--roadmap $RM --job E1"
for args in "--human|spec 승인|--choice|x" "--human|spec 승인|--line|x" "--human|spec 승인|--approval" "--human|spec 승인|--spec|x" \
            "--human|결정" "--human|계획 검토" "--human|spec 승인|--plan|1" "--human|걸음 건너뜀" \
            "--human|걸음 건너뜀|--gate|아무 관문" "--human|걸음 건너뜀|--gate|다시 시도 시도 3" \
            "--human|걸음 건너뜀|--gate|계획 검토 plan 1|--plan|2" "--human|계획 검토|--plan|0"; do
  IFS='|' read -r -a parts <<< "$args"
  # shellcheck disable=SC2086
  assert_eq "$(led record "${parts[@]}" $H)" "2" "AC3: 사용법 — record ${args}"
done
assert_eq "$(led record)" "2" "AC3: 사용법 — record 에 --spec 도 --human 도 없다"
assert_eq "$(led ask-head --human "spec 승인" --roadmap "$RM" --job E1 --plan 1)" "2" "AC3: 사용법 — ask-head spec 승인 --plan"
assert_eq "$(led ask-head --human "계획 검토" --roadmap "$RM" --job E1)" "2" "AC3: 사용법 — ask-head 계획 검토에 --plan 없음"
assert_eq "$(snap) $(cksum < "$W/$E2/INTENT.md")" "$S27 $E27" "AC3: 사용법 — INTENT.md 그대로"

# 28 · 29 — 옛 인자로는 사람 줄을 적지 못한다
g checkout -q feature/tm-e1
S28="$(snap)"
assert_eq "$(led record --spec "$W/$E1/design.md" --approval --date 2026-11-23 --choice "이대로")" "2" "AC3: --approval 로 spec 승인 줄 — 2"
assert_contains "$(out)" "record --human" "AC3: --approval — record --human 으로 보낸다"
assert_eq "$(led record --spec "$W/$E1/design.md" --line "계획 검토 · 2026-11-23 · 「글」")" "2" "AC3: --line 으로 사람 줄 — 2"
assert_contains "$(out)" "record --human" "AC3: --line — record --human 으로 보낸다"
assert_eq "$(snap)" "$S28" "AC3: 옛 인자 — 그대로"
assert_eq "$(led record --spec "$W/$E1/design.md" --line "결정 · 2026-11-23 · 「글」")" "0" "AC3: 사람 줄이 아닌 줄은 지금처럼 0"

# 30 · 31 — flush 도 사람 줄을 옮기지 못한다
pend() { led add --roadmap "$RM" --session "$SID" --section "쌓인 기록" --cells "E1 · 지휘 기록 · $1"; }
flush() { led flush --roadmap "$RM" --session "$SID" --epic E1 --spec "$W/$E1/design.md"; }
pend "- 흐름 승인 · 2026-11-23 · 「글」" > /dev/null
pend "- 결정 · 2026-11-23 · 「쌓인 결정」" > /dev/null
S30="$(snap)"
assert_eq "$(flush)" "2" "AC3: 쌓인 사람 줄을 flush — 2"
assert_contains "$(out)" "record --human" "AC3: flush — record --human 으로 보낸다"
assert_eq "$(snap)" "$S30" "AC3: flush — 그대로"
led pending --roadmap "$RM" --epic E1 > /dev/null
assert_contains "$(out)" "- 흐름 승인 · 2026-11-23 · 「글」" "AC7: 쌓인 사람 줄이 남는다"
assert_contains "$(out)" "- 결정 · 2026-11-23 · 「쌓인 결정」" "AC7: 같이 쌓인 줄도 남는다"
assert_eq "$(led drop --roadmap "$RM" --session "$SID" --section "쌓인 기록" --where "글=- 흐름 승인 · 2026-11-23 · 「글」")" "0" "쌓인 사람 줄을 지운다"
assert_eq "$(flush)" "0" "AC3: 사람 줄이 없으면 flush 0(양성 대조)"
assert_contains "$(cat "$W/$E1/INTENT.md")" "- 결정 · 2026-11-23 · 「쌓인 결정」" "AC3: 쌓인 결정 줄이 옮겨졌다"

# 32 · 33 — 표지 없음 · 기록 없음
led release --roadmap "$RM" --session "$SID" > /dev/null
assert_eq "$(led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 1)" "3" "AC6: 지휘 표지가 없으면 3"
assert_contains "$(out)" "확인 못 함" "AC6: 표지 없음 — 확인 못 함"
assert_contains "$(out)" "지휘 표지가 없다(먼저 claim)" "AC6: 표지 없음 — 사유는 표지가 없다는 것"
claim || no "표지를 다시 쥐지 못했다"
mkdir -p "$T/none"
assert_eq "$(export CLAUDE_CONFIG_DIR="$T/none"; led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 1)" "3" "AC6: 세션 기록 파일을 찾지 못하면 3"
assert_contains "$(out)" "확인 못 함" "AC6: 기록 없음 — 확인 못 함"
assert_contains "$(out)" "human_gate: 끔" "AC6: 기록 없음 — 끄는 길"
case "$(out)" in "[spec-distill] 확인 못 함 — "*"human_gate: 끔 으로 연다") ok "AC6: 기록 없음 — 글이 확인 못 함으로 시작해 끄는 길로 끝난다(K22)" ;; *) no "AC6: 기록 없음 — 글의 처음과 끝이 어긋난다 — $(out)" ;; esac

# 34 — human_gate: 끔 이면 글로 적는다(AC20). 되돌리면 다시 막는다(양성 대조)
g add -- "$E1/INTENT.md" && g commit -qm "결정 줄"
g checkout -q main
printf '%s\n' '---' 'human_gate: 끔' '---' > "$W/.devbrew.md"
g add -- .devbrew.md && g commit -qm "관문 끔" && push_main
g checkout -q feature/tm-e1
assert_eq "$(led record --spec "$W/$E1/design.md" --approval --date 2026-11-23 --choice "이대로")" "0" "AC3: 꺼져 있으면 --approval 0"
assert_eq "$(led record --spec "$W/$E1/design.md" --line "계획 검토 · 2026-11-23 · 「글」")" "0" "AC3: 꺼져 있으면 --line 0"
pend "- 흐름 승인 · 2026-11-23 · 「글」" > /dev/null
assert_eq "$(flush)" "0" "AC3: 꺼져 있으면 flush 0"
BODY="$(cat "$W/$E1/INTENT.md")"
assert_contains "$BODY" "- spec 승인 · 2026-11-23 · 「이대로」" "AC3: 꺼져 있으면 spec 승인 줄이 적혔다"
assert_contains "$BODY" "- 계획 검토 · 2026-11-23 · 「글」" "AC3: 꺼져 있으면 계획 검토 줄이 적혔다"
assert_contains "$BODY" "- 흐름 승인 · 2026-11-23 · 「글」" "AC3: 꺼져 있으면 쌓인 흐름 승인 줄이 옮겨졌다"
g add -- "$E1/INTENT.md" && g commit -qm "끔 줄"
g checkout -q main
g revert --no-edit HEAD > /dev/null && push_main
g checkout -q feature/tm-e1
assert_eq "$(led record --spec "$W/$E1/design.md" --approval --date 2026-11-23 --choice "이대로")" "2" "AC3: 설정을 되돌리면 다시 2(양성 대조)"
assert_contains "$(out)" "record --human" "AC3: 되돌린 뒤 — record --human 으로 보낸다"

# 35 — ask-head 의 3 도 record --human 처럼 「확인 못 함」 으로 시작하고 끄는 길로 끝난다(AC6). 되돌리면 다시 0(양성 대조)
g checkout -q main && printf -- '---\nhuman_gate: 아무거나\n---\n' > "$W/.devbrew.md" && g add -- .devbrew.md && g commit -qm "깨진 human_gate" && push_main && g checkout -q feature/tm-e1
assert_eq "$(led ask-head --human "spec 승인" --roadmap "$RM" --job E1)" "3" "AC6: 설정을 읽지 못하면 ask-head 3"
assert_contains "$(out)" "확인 못 함" "AC6: ask-head 3 — 확인 못 함으로 시작한다"
assert_contains "$(out)" "human_gate: 끔 으로 연다" "AC6: ask-head 3 — record --human 과 같은 끄는 길 꼬리"
case "$(out)" in *"human_gate: 끔 으로 연다") ok "AC6: ask-head 3 — 글이 끄는 길로 끝난다" ;; *) no "AC6: ask-head 3 — 글이 끄는 길로 끝나지 않는다" ;; esac
g checkout -q main && g revert --no-edit HEAD > /dev/null && push_main && g checkout -q feature/tm-e1
assert_eq "$(led ask-head --human "spec 승인" --roadmap "$RM" --job E1)" "0" "AC6: 설정을 되돌리면 ask-head 0(양성 대조)"

# h1–h3 — 계획 번호 없는 사람 줄은 머지되지 않은 브랜치 끝 모두에서 판정한다(K12 · AC23 미룸). 14b 의 답이 새지 않게 새 레포에서
T0="$T"
repo_copy "$T0/h" new && ok "h: 새 팀 레포를 세웠다" || { no "h: 새 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; use_repo "$T0"; finish; exit 1; }
hdesign() { put "$E1/design.md" "$(printf '# 설계\n\n## Goals\n\n%s\n\n## 미룸\n\n- %s\n' "$1" "$2")"; }
stale_why() { sed -n '/^낡음 — - spec 승인/{n;p;}' "$T/led.txt"; }
g checkout -q -b feature/tm-e1 main
hdesign "본문 하나" "미룬 것 하나" && g commit -qm "E1 설계" && push_br feature/tm-e1
approved "spec 승인" E1 && push_br feature/tm-e1 || no "h1: 준비 — spec 승인 줄을 적지 못했다"
g checkout -q -b feature/tm-e1b feature/tm-e1 && push_br feature/tm-e1b
# h1 — 두 브랜치 끝이 같다
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "K12: 두 브랜치 끝이 같고 본문 그대로면 human-check 0(양성 대조)"
assert_eq "$(grep -c '^지남 — - spec 승인' "$T/led.txt")" "1" "K12: 끝이 같은 브랜치는 한 번만 판정한다 — 지남 줄이 정확히 한 번"
# h2 — 둘째 브랜치에서 승인 뒤 본문을 고쳤다
hdesign "본문 고침" "미룬 것 하나" && g commit -qm "E1 설계 본문 고침(둘째 브랜치)" && push_br feature/tm-e1b
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "1" "K12: 둘째 브랜치 끝에서 본문이 바뀌면 human-check 1"
assert_contains "$(out)" "낡음 — - spec 승인" "K12: 둘째 브랜치 끝의 본문 고침 — 낡음"
case "$(stale_why)" in "    사유: feature/tm-e1b 끝에서: "*) ok "K12: 사유 앞에 그 브랜치 끝 이름" ;; *) no "K12: 사유 앞에 그 브랜치 끝 이름이 없다 — $(stale_why)" ;; esac
# h3 — 되돌리고 미룸 절만 고쳤다
g revert --no-edit HEAD > /dev/null && push_br feature/tm-e1b
hdesign "본문 하나" "미룬 것 둘" && g commit -qm "E1 설계 미룸 고침(둘째 브랜치)" && push_br feature/tm-e1b
assert_eq "$(led human-check --roadmap "$RM" --job E1)" "0" "K12: 둘째 브랜치 끝에서 미룸 절만 고치면 human-check 0"
use_repo "$T0"

# d1 · d2 — 새 레포에서(14b 의 「수정 필요」 답이 이 레포의 E1 머리에 닿지 않게). 지역 날짜 · 갈라진 형제 브랜치(K9 · K12 미룸)
repo_copy "$T0/d" new && ok "d: 새 팀 레포를 세웠다" || { no "d: 새 팀 레포를 세우지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; use_repo "$T0"; finish; exit 1; }
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "$(printf '# 설계\n\n본문 하나\n\n## 지휘 기록\n')" && g commit -qm "E1 설계" && push_br feature/tm-e1
DH="E1 @$(short "$(g rev-parse HEAD)")"
# d1 — 답한 시각 2026-11-20 23:30 UTC 는 Asia/Seoul 에서 11-21 이다 — 줄의 날짜는 지역 날짜다
answer "$DH — 질문" "$PASSL" --when 2026-11-20T23:30:00.000Z
assert_eq "$(export TZ=Asia/Seoul; rec)" "0" "J28: Asia/Seoul 에서 답한 시각이 UTC 로는 전날이어도 0"
case "$(intent_tail)" in "- spec 승인 · 2026-11-21 · "*) ok "J28: 줄의 날짜는 지역 날짜(Asia/Seoul)다" ;; *) no "J28: 줄의 날짜가 지역 날짜가 아니다 — $(intent_tail)" ;; esac
g add -- "$E1/INTENT.md" && g commit -qm "spec 승인 줄" && push_br feature/tm-e1
# d2 — d1 의 답은 지역 날짜 줄의 근거라 같은 TZ 로 다시 부른다(다른 TZ 면 다른 줄이라 그 답이 쓰인 것으로 센다). 둘째 브랜치가 로컬과 원격으로 갈라졌다(tests/test_start_bundle.sh 의 갈라진 과제 브랜치와 같은 준비 — origin 을 조상으로 옮기면 로컬을 쓴다)
g checkout -q -b feature/tm-e1b feature/tm-e1 && put "$E1/side.md" "둘째 브랜치 글" && g commit -qm "둘째 브랜치" && push_br feature/tm-e1b
g commit --amend -qm "갈라짐" && g checkout -q feature/tm-e1
assert_eq "$(export TZ=Asia/Seoul; rec)" "0" "K12: 형제 브랜치가 갈라져 있어도 첫째 브랜치의 record --human 은 0"
assert_contains "$(out)" "알림: feature/tm-e1b 의 줄을 읽지 않았다" "K12: 갈라진 형제 브랜치의 줄을 읽지 않았다고 알린다"
use_repo "$T0"

finish
