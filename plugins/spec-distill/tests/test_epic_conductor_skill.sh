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
for lit in 'conductor_ledger.py" roadmaps' '여럿이면 `AskUserQuestion`' '앞의 `@` 하나는 뗀다' \
           'cd "<root>" && git worktree list --porcelain' '그 경로를 품는 worktree(가장 깊은 것)' \
           '로드맵의 레포 상대경로는 어느 worktree 에서나 같다' '어느 worktree 안에도 없다'; do
  assert_contains "$(sec '### 2. 로드맵 정하기')" "$lit" "로드맵 정하기: $lit"
done
assert_not_contains "$(sec '### 2. 로드맵 정하기')" '절대경로면 `root=` 기준 상대경로로' "로드맵 정하기: root= 하나만 기준으로 삼던 옛 문장이 없다(다른 worktree 의 절대경로를 놓친다)"
CLAIM_LINE="$(sec '### 3. 자리 · 세션 · 표지' | grep -F 'claim --roadmap' || true)"
assert_contains "$CLAIM_LINE" 'then cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" claim' "자리 · 세션 · 표지: claim 줄도 cd 에 묶였다"
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
assert_contains "$(sec '### 7. 옮김 대조')" 'subagent_type: "spec-distill:relay-checker"' "옮김 대조 dispatch 자리(Ruling R37)"
assert_contains "$(sec '### 7. 옮김 대조')" '`review_model`' "옮김 대조: 모델 칸은 review_model"
assert_contains "$(grep -F '[devbrew-entry] disabled' "$SK")" 'spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼져' "꺼짐 행: 플러그인 전체가 꺼진다고 알린다(Ruling R35)"
assert_contains "$(grep -F '[devbrew-entry] disabled' "$SK")" '지휘자를 부르지 않은 채' "꺼짐 행: 손 절차는 지휘자를 부르지 않고 따른다"
RC="$ROOT/plugins/spec-distill/agents/relay-checker.md"
assert_eq "$(fm "$RC" | grep -E '^tools:' )" "tools: Read, Grep, Glob" "relay-checker tools 는 Read, Grep, Glob 뿐"
assert_eq "$(fm "$RC" | grep -cE '^(disallowedTools|allowed-tools|allowedTools):' || true)" "0" "relay-checker 에 거부 목록 · 오기 필드가 없다"
for lit in 'You are the relay checker' 'You are responsible for' 'You are NOT responsible for' '확인 못 함 — <이유>' '판정: 일치'; do
  assert_file_grep "$RC" "$lit" "relay-checker: $lit"
done
assert_eq "$(fm "$RC" | grep -c 'tag: relay_files$')" "1" "relay-checker 입력 칸 relay_files"
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
# 3~4절 펜스: sid 를 쓰는 펜스는 같은 펜스 안에서 sid 와 루트 가드를 정한다(Bash 호출마다 새 셸)
fence_check="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = open(sys.argv[1], encoding="utf-8").read()
a = t.index("### 3. ")
b = t.index("### 5. ")
parts = t[a:b].split("`" * 3)
n = 0
bad = 0
for i in range(1, len(parts), 2):
    f = parts[i]
    if "--session" in f:
        n += 1
        if "sid=\"$(" not in f or "CLAUDE_PLUGIN_ROOT" not in f:
            bad += 1
print("%d %d" % (n, bad))' "$SK")"
assert_eq "${fence_check#* }" "0" "3~4절: --session 을 쓰는 펜스가 같은 펜스에서 sid 와 루트 가드를 정한다"
[ "${fence_check%% *}" -ge 5 ] && ok "3~4절: 세션을 쓰는 펜스 5개 이상(claim · takeover · approval · approve · release)" || no "세션 펜스 수 부족: ${fence_check}"
# 3~4절 산문(펜스 밖)에는 셸 변수 sid · SD 가 없고, sid 를 쓰는 펜스는 빈 값이면 멈춘다
fence_lint='import sys
t = sys.stdin.read()
a = t.index("### 3. ")
b = t.index("### 5. ")
parts = t[a:b].split("`" * 3)
prose = 0
nostop = 0
for i, f in enumerate(parts):
    if i % 2 == 0:
        prose += sum(1 for ln in f.split("\n") if "$sid" in ln or "$SD" in ln)
    elif "$sid" in f and "[ -n \"$sid\" ] ||" not in f and "if [ -n \"$sid\" ]" not in f:
        nostop += 1
print("%d %d" % (prose, nostop))'
lint="$(python3 -I -c "$fence_lint" < "$SK")"
assert_eq "$lint" "0 0" "3~4절: 산문에 셸 변수가 없고 sid 펜스는 빈 값이면 멈춘다"
mutated="$(python3 -I -c 'import sys
t = sys.stdin.read()
print(t.replace("### 5. ", "`--session \"$sid\"` 를 산문에서 돌린다\n\n### 5. ", 1))' < "$SK")"
bad_lint="$(printf '%s\n' "$mutated" | python3 -I -c "$fence_lint")"
assert_eq "${bad_lint%% *}" "1" "양성 대조: 산문의 --session 줄을 락이 잡는다"
assert_contains "$(sec '### 3. 자리 · 세션 · 표지')" 'claim_rc=$?' "3절: claim 종료 코드를 낸다"
assert_contains "$(sec '### 3. 자리 · 세션 · 표지')" 'conductor_ledger.py" takeover' "3절: takeover 전체 명령"
assert_contains "$APP" 'conductor_ledger.py" release' "4절: release 전체 명령"
# 기본 브랜치 대조 — 표지를 잡은 뒤 돌므로, 멈출 때 잡은 표지를 풀고 멈춘다(다른 세션이 「지휘 중」으로 막히지 않게)
S3="$(sec '### 3. 자리 · 세션 · 표지')"
DEF_FENCE="$(printf '%s\n' "$S3" | awk '/^```bash/{f=1;n++;next} /^```/{f=0} f&&n==1')"
assert_contains "$DEF_FENCE" 'cd "<root>" && python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote; echo "default_rc=$?"' "3절 첫 펜스: 기본 브랜치 원격 대조 줄과 종료 코드"
DEF_BULLET="$(printf '%s\n' "$S3" | grep -F -- '- `default_rc=`' || true)"
assert_eq "$(printf '%s\n' "$DEF_BULLET" | grep -c .)" "1" "3절: default_rc 처리 줄이 하나다"
for lit in '0 이 아니면' '3 기본 브랜치 없음' '5 원격과 다름' '그 밖 모두' '`claim_rc=0` 이면' '`conductor_ledger.py" release`' '돌린 뒤 멈춘다' '「대조하지 못했다」 줄은 보이고 간다'; do
  assert_contains "$DEF_BULLET" "$lit" "3절 default_rc 줄: $lit"
done
assert_contains "$(cat "$AG")" '내는 형식은 아래 `## 내는 것`' "agent: 출력 형식은 내는 것 절"
CM="$ROOT/CLAUDE.md"
COST="$(grep -F '**모든 skill에 `cost_class` 선언**' "$CM")"
assert_contains "$COST" '지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke해야 함' "CLAUDE.md: 원래 승인 규칙 문장이 그대로"
for lit in '이름 붙인 예외 하나 — `epic-conductor`' '같은 세션에서 같은 규모로 다시 부르면' '규모가 바뀌거나 다른 세션이면 다시 묻는다'; do
  assert_contains "$COST" "$lit" "CLAUDE.md 예외: $lit"
done
assert_eq "$(grep -c '이름 붙인 예외' "$CM")" "1" "CLAUDE.md: 이름 붙인 예외는 하나"
others="$(grep -l '이름 붙인 예외' "$ROOT"/plugins/*/skills/*/SKILL.md | grep -v '/skills/epic-conductor/' || true)"
assert_eq "$others" "" "예외를 주장하는 다른 skill 이 없다"
# 지휘자 수리 2 — 보이기: 지휘자 질문과 brainstorming 대화의 모양을 나눈다 · 에픽 이름은 질문 문장 앞머리
SHOW="$(awk '$0=="## 보이기"{f=1;next} f&&/^## /{exit} f' "$SK")"
for lit in '질문 문장 앞머리에 에픽 이름을 쓴다' 'brainstorming 대화는 brainstorming 이 정한 메시지 모양(첫 메시지 · 열린 문장 질문 하나 · 되비춤)을 따른다' \
           '위 규칙의 순서(첫 줄 상태 · 끝 할 일)를 붙이지 않고 낱말 규칙만 지키며' '그 메시지에 얹지 않고 따로 된 메시지로 보인다' '「계획 담당자」 · 「구현 담당자」'; do
  assert_contains "$SHOW" "$lit" "보이기: $lit"
done
assert_contains "$SHOW" '같은 턴에 원천(하니스 agent 목록 · 상태 계산 · 실행 원장)을 다시 조회하고 「HH:MM 기준」 을 붙인다' "보이기: 진행 상황은 원천에서 다시 세고 기준 시각을 붙인다(지휘자 수리 2)"
assert_not_contains "$SHOW" '질문마다 첫 줄에 에픽 이름' "보이기: 에픽 이름을 따로 된 첫 줄로 쓰던 옛 문장이 없다(양성 짝: 질문 문장 앞머리)"
finish
