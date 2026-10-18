#!/usr/bin/env bash
# R5 계획 3 — 진입 skill epic-conductor(AC15 · AC44)와 통합 리뷰어 agent(결정 D)의 정적 락.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_epic_conductor_skill.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SK="$ROOT/plugins/spec-distill/skills/epic-conductor/SKILL.md"
AG="$ROOT/plugins/spec-distill/agents/integration-reviewer.md"
[ -f "$SK" ] && ok "SKILL.md 가 있다" || { no "SKILL.md 가 없다"; finish; exit $?; }
[ -f "$AG" ] && ok "integration-reviewer.md 가 있다" || no "integration-reviewer.md 가 없다"
HEAD="$(python3 "$ROOT/shared/entry/check_invocation_surface.py" --print-head spec-distill epic-conductor)"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  grep -qxF -- "$line" "$SK" && ok "머리 줄: $line" || no "머리 줄이 없다: $line"
done <<< "$HEAD"
assert_file_grep "$SK" '^cost_class: high$' "cost_class: high"
fm() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }
assert_eq "$(fm "$SK" | grep -c '^name: epic-conductor$')" "1" "name 이 디렉토리 이름과 같다"
BODY="$(cat "$SK")"
sec() { awk -v h="$1" '$0==h{f=1;next} f&&/^##/{exit} f' "$SK"; }
for lit in 'conductor_ledger.py" roadmaps' '여럿이면 `AskUserQuestion`'; do
  assert_contains "$(sec '### 2. 로드맵 정하기')" "$lit" "로드맵 정하기: $lit"
done
for lit in 'worktree 안에서 시작했다' '여기서도 지휘한다' 'state_path.py" session-id' 'conductor_ledger.py" claim' '읽기 전용'; do
  assert_contains "$(sec '### 3. 자리 · 세션 · 표지')" "$lit" "자리 · 세션 · 표지: $lit"
done
APP="$(sec '### 4. 시작 승인')"
for lit in '남은 에픽' 'agent 약' '라운드마다 부르는 리뷰어 agent' 'conductor_ledger.py" approval' '`AskUserQuestion`' 'conductor_ledger.py" approve' \
           '승인 전에는 agent 를 보내지 않는다' '이름 붙인 예외' '규모 줄이 글자 그대로 같을 때만' \
           '종료 코드 0 이 아니면' '3 기계 상태 읽기 불가'; do
  assert_contains "$APP" "$lit" "시작 승인: $lit"
done
# 시작 승인 순서: 규모 공시 → approval → (rc 1 이면) AskUserQuestion → approve
order="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
ks = ["규모 줄", "conductor_ledger.py\" approval", "`AskUserQuestion`", "conductor_ledger.py\" approve "]
ix = [t.find(k) for k in ks]
print("yes" if min(ix) >= 0 and ix == sorted(ix) else "no")' "$APP")"
assert_eq "$order" "yes" "시작 승인: 규모 → approval → 질문 → approve 순서"
assert_contains "$BODY" 'Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md' "conducting.md 를 읽는다"
assert_contains "$BODY" 'Read ${CLAUDE_PLUGIN_ROOT}/references/conductor-dispatch.md' "conductor-dispatch.md 를 읽는다"
assert_contains "$BODY" '손으로 따르는 절차' "꺼짐: 손 절차를 가리킨다"
assert_file_grep "$SK" '^\| `\[devbrew-entry\] disabled …` \| .*손으로 따르는 절차.*멈춘다 \|$' "감시줄 표의 꺼짐 행이 손 절차를 가리키고 멈춘다"
assert_contains "$BODY" 'subagent_type: "spec-distill:integration-reviewer"' "통합 리뷰어 dispatch 자리"
assert_not_contains "$BODY" '다른 세션을 열어' "다른 세션을 열라는 말이 없다"
# agent — 쓰기 도구 없음(Law 2) · 역할 문장 · 입력 칸
assert_eq "$(fm "$AG" | grep -E '^tools:' )" "tools: Read, Grep, Glob" "agent tools 는 Read, Grep, Glob 뿐"
assert_eq "$(fm "$AG" | grep -cE '^(disallowedTools|allowed-tools|allowedTools):' || true)" "0" "agent 에 거부 목록 · 오기 필드가 없다"
for lit in 'You are the integration reviewer' 'You are responsible for' 'You are NOT responsible for'; do
  assert_file_grep "$AG" "$lit" "agent 역할: $lit"
done
for t in review_request merged_copy pr_diff open_diffs handoffs; do
  assert_eq "$(fm "$AG" | grep -c "tag: $t$")" "1" "agent 입력 칸 $t"
done
for f in test_invocation_surface.sh test_dispatch_disposition.sh test_agent_input_slots.sh test_plain_language_block.sh \
         test_skill_reference_pointers.sh test_plugin_root_no_cwd_fallback.sh test_skill_body_no_positional_tokens.sh test_inline_python_isolated.sh; do
  out="$(bash "$ROOT/shared/tests/$f" 2>&1)"; rc=$?
  assert_eq "$rc" "0" "공유 락 $f 가 통과한다"
  [ "$rc" -eq 0 ] || printf '%s\n' "$out" | grep -E '✗|RED|FAIL' | head -5
done
CM="$ROOT/CLAUDE.md"
COST="$(grep -F '**모든 skill에 `cost_class` 선언**' "$CM")"
assert_contains "$COST" '지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke해야 함' "CLAUDE.md: 원래 승인 규칙 문장이 그대로"
for lit in '이름 붙인 예외 하나 — `epic-conductor`' '같은 세션에서 같은 규모로 다시 부르면' '규모가 바뀌거나 다른 세션이면 다시 묻는다'; do
  assert_contains "$COST" "$lit" "CLAUDE.md 예외: $lit"
done
assert_eq "$(grep -c '이름 붙인 예외' "$CM")" "1" "CLAUDE.md: 이름 붙인 예외는 하나"
others="$(grep -l '이름 붙인 예외' "$ROOT"/plugins/*/skills/*/SKILL.md | grep -v '/skills/epic-conductor/' || true)"
assert_eq "$others" "" "예외를 주장하는 다른 skill 이 없다"
finish
