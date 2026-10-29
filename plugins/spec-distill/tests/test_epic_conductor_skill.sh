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
assert_contains "$(sec '### 2. 로드맵 정하기')" '둘째 칸이 `검사 불가 — <사유>` 인 줄은 셀 수 없었던 로드맵이니 그 사유를 함께 보인다' "로드맵 정하기: ledger roadmaps 줄의 검사 불가 칸을 읽는 법"
assert_not_contains "$(sec '### 2. 로드맵 정하기')" '줄마다 `<경로><탭><끝나지 않은 에픽 수>` 다. 하나면' "로드맵 정하기: 검사 불가 칸 없이 하나면으로 잇던 옛 문장이 없다"
CLAIM_LINE="$(sec '### 3. 자리 · 세션 · 표지' | grep -F 'claim --roadmap' || true)"
assert_contains "$CLAIM_LINE" 'then cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" claim' "자리 · 세션 · 표지: claim 줄도 cd 에 묶였다"
for lit in 'worktree 안에서 시작했다' '여기서도 지휘한다' 'state_path.py" session-id' 'conductor_ledger.py" claim' '읽기 전용'; do
  assert_contains "$(sec '### 3. 자리 · 세션 · 표지')" "$lit" "자리 · 세션 · 표지: $lit"
done
APP="$(sec '### 4. 규모 공시')"
for lit in '남은 에픽' 'agent 약' '라운드마다 부르는 리뷰어 agent' \
           'spec 리뷰는 라운드마다 리뷰어 agent 둘 이상, 엔진의 재리뷰 상한까지(사용자가 더 열 수 있다)' \
           '구현 안 agent 수는 task 수에 따라 — 상한 없음' \
           '규모 줄을 보이고 5 로 간다 — 지출 승인을 묻지 않는다.'; do
  assert_contains "$APP" "$lit" "규모 공시: $lit"
done
for lit in 'conductor_ledger.py" approval' 'conductor_ledger.py" approve' '`AskUserQuestion`' 'conductor_ledger.py" release' \
           '승인 전에는 agent 를 보내지 않는다' '이름 붙인 예외'; do
  assert_not_contains "$APP" "$lit" "규모 공시: 지출 승인 흔적이 없다 — $lit"
done
# 규모 공시 순서: 규모 줄을 만들고 → 보이고 5 로 간다
order="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
ks = ["규모 줄 하나를 만든다", "규모 줄을 보이고 5 로 간다"]
ix = [t.find(k) for k in ks]
print("yes" if min(ix) >= 0 and ix == sorted(ix) else "no")' "$APP")"
assert_eq "$order" "yes" "규모 공시: 규모 줄을 만든 뒤 보이고 5 로 간다 순서"
assert_contains "$BODY" 'Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md' "conducting.md 를 읽는다"
assert_contains "$BODY" 'Read ${CLAUDE_PLUGIN_ROOT}/references/conductor-dispatch.md' "conductor-dispatch.md 를 읽는다"
assert_contains "$BODY" '손으로 따르는 절차' "꺼짐: 손 절차를 가리킨다"
assert_file_grep "$SK" '^\| `\[devbrew-entry\] disabled …` \| .*손으로 따르는 절차.*멈춘다 \|$' "감시줄 표의 꺼짐 행이 손 절차를 가리키고 멈춘다"
assert_contains "$BODY" 'subagent_type: "spec-distill:integration-reviewer"' "통합 리뷰어 dispatch 자리"
assert_contains "$(sec '### 7. 옮김 대조')" 'subagent_type: "spec-distill:relay-checker"' "옮김 대조 dispatch 자리(Ruling R37)"
for s in '### 6. 통합 리뷰어' '### 7. 옮김 대조'; do
  assert_contains "$(sec "$s")" '`repo_defaults.py get review_model --roadmap <로드맵>`' "$s: 모델 칸은 해결자 get review_model 의 값"
  assert_contains "$(sec "$s")" '3(설정을 읽지 못함)이면 그 사유 줄을 보이고' "$s: 해결자 rc 3 이면 사유 줄을 보인다"
done
assert_not_contains "$BODY$(cat "$ROOT/plugins/spec-distill/references/conducting.md")" '로드맵 frontmatter `review_model`' "리뷰 모델을 로드맵 머리말에서만 읽는 옛 문구가 없다"
assert_contains "$(grep -F '[devbrew-entry] disabled' "$SK")" 'spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼져' "꺼짐 행: 플러그인 전체가 꺼진다고 알린다(Ruling R35)"
assert_contains "$(grep -F '[devbrew-entry] disabled' "$SK")" '지휘자를 부르지 않은 채' "꺼짐 행: 손 절차는 지휘자를 부르지 않고 따른다"
RC="$ROOT/plugins/spec-distill/agents/relay-checker.md"
assert_eq "$(fm "$RC" | grep -E '^tools:' )" "tools: Read, Grep, Glob" "relay-checker tools 는 Read, Grep, Glob 뿐"
assert_eq "$(fm "$RC" | grep -cE '^(disallowedTools|allowed-tools|allowedTools):' || true)" "0" "relay-checker 에 거부 목록 · 오기 필드가 없다"
for lit in 'You are the relay checker' 'You are responsible for' 'You are NOT responsible for' '확인 못 함 — <이유>' '판정: 일치'; do
  assert_file_grep "$RC" "$lit" "relay-checker: $lit"
done
assert_eq "$(fm "$RC" | grep -c 'tag: relay_files$')" "1" "relay-checker 입력 칸 relay_files"
for lit in '「문장 권장이 라벨 꼬리로 옮겨짐」' '「지휘자가 만든 질문의 라벨에 (권장)」' '라벨이 아니라 문장으로 냈는데 띄운 질문의 라벨에 「(권장)」 꼬리가 붙었으면 어긋남이다' \
           '선택지(라벨이든 설명이든)에 「(권장)」 이 있으면 어긋남이다' 'skill 이 붙인 자리에만, 그 자리에 그대로 있는가' '지휘자 권장은 선택지 밖 의견 줄에만 쓴다' \
           '돌려줄 값이 글자 그대로 같은가' '하위에게 돌려보낸 글에 글자 그대로 있는가'; do
  assert_not_contains "$(cat "$RC")" "$lit" "옮김 대조: 옛 문장 없음 — $lit"
done
for lit in '3. 라벨 — 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 라벨(돌려줄 값)이 글자 그대로 같은가.' \
           '원문이 붙인 꼬리가 띄운 질문에 그대로 있는가 — 빠졌으면 어긋남이다(「원문 꼬리 빠짐」)' \
           '원문에 없던 꼬리는 둘 중 하나일 때만 일치다: 원문이 문장으로 낸 권장이 가리킨 선택지이거나, 「지휘자 의견:」 줄이 그 선택지를 지휘자 권장으로 밝히고 이유를 단 경우.' \
           '그 밖의 꼬리는 어긋남이다 — 「출처 없는 꼬리」 라고 적는다.' \
           '지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다(「지휘자 의견:」 은 선택지 밖 한 줄이다).' \
           '5. 사용자 답 — 하위에게 돌려보낸 글에 꼬리를 뗀 원문 라벨 글자 그대로 있는가.' \
           '그 질문은 정본 규칙을 따르므로 라벨의 「(권장)」 꼬리는 일치이고, 지휘자 의견이 선택지 설명 안에 들어간 것만 어긋남이다.' \
           '표시 없이 원문에 없는 선택지가 띄운 질문에 있어도 어긋남이다(원문에 없는 꼬리는 4 대로 본다)' \
           'compares choices (count · order · labels with the 「(권장)」 tail stripped · where each 「(권장)」 tail came from)' \
           '2. 순서 — 같은 차례인가.' '1. 선택지 수 — skill 원문과 띄운 질문의 선택지 수가 같은가.' \
           '근거 없는 「지휘자가 만든 질문」 표시'; do
  assert_contains "$(cat "$RC")" "$lit" "옮김 대조(양): $lit"
done
assert_not_contains "$(cat "$RC")" '지휘자 것이라고 밝혀 두었는지' "AC9: 옛 문장 없음"
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
[ "${fence_check%% *}" -ge 4 ] && ok "3~4절: 세션을 쓰는 펜스 4개 이상(claim · takeover · 다시 채우기 · release)" || no "세션 펜스 수 부족: ${fence_check}"
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
REL_CNT="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = open(sys.argv[1], encoding="utf-8").read()
a = t.index("### 3. ")
b = t.index("### 4. ")
parts = t[a:b].split("`" * 3)
n = 0
stop = 0
for i in range(1, len(parts), 2):
    f = parts[i]
    if "pr-refresh" in f:
        continue
    if "python3 \"$SD/scripts/conductor_ledger.py\" release --roadmap \"<로드맵>\" --session \"$sid\"" in f:
        n += 1
        if "[ -n \"$sid\" ] ||" in f:
            stop += 1
print("%d %d" % (n, stop))' "$SK")"
assert_eq "$REL_CNT" "1 1" "3절: 표지 풀기 펜스(release)가 pr-refresh 없는 펜스로 정확히 하나이고 세션 id 멈춤을 가진다"
# 기본 브랜치 대조 — 표지를 잡은 뒤 돌므로, 멈출 때 잡은 표지를 풀고 멈춘다(다른 세션이 「지휘 중」으로 막히지 않게)
S3="$(sec '### 3. 자리 · 세션 · 표지')"
DEF_FENCE="$(printf '%s\n' "$S3" | awk '/^```bash/{f=1;n++;next} /^```/{f=0} f&&n==1')"
assert_contains "$DEF_FENCE" 'cd "<root>" && python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote; echo "default_rc=$?"' "3절 첫 펜스: 기본 브랜치 원격 대조 줄과 종료 코드"
DEF_BULLET="$(printf '%s\n' "$S3" | grep -F -- '- `default_rc=`' || true)"
assert_eq "$(printf '%s\n' "$DEF_BULLET" | grep -c .)" "1" "3절: default_rc 처리 줄이 하나다"
for lit in '0 이 아니면' '3 기본 브랜치 없음' '5 원격과 다름' '그 밖 모두' '`claim_rc=0` 이면' '`conductor_ledger.py" release`' '돌린 뒤 멈춘다' '「대조하지 못했다」 줄은 보이고 간다'; do
  assert_contains "$DEF_BULLET" "$lit" "3절 default_rc 줄: $lit"
done
assert_not_contains "$DEF_BULLET" '4 끝의' "3절 default_rc 줄: 4절 끝을 가리키는 옛 문구가 없다"
assert_not_contains "$S3" '옛 시작 승인' "3절: 옛 시작 승인 언급이 없다"
# 옛 PR 캐시 다시 채우기 — claim rc 3 + 옛 줄 문구면 멈추지 않고 reset → release → claim(R8 계획 2 최종 리뷰 I-2).
# 문구는 conductor_state 가 실제로 내는 OldPrRows 메시지의 부분 문자열이어야 한다.
OLD_MSG="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import conductor_state as cs
try:
    cs.parse_machine("---\ntype: conductor-machine\nroadmap: r.md\n---\n\n## PR\n\n- feature/a · #3 · 열림 · 2026-10-17 10:00\n", "r.md")
except cs.OldPrRows as exc:
    print(exc)' "$ROOT/plugins/spec-distill/scripts")"
reset_branch_check='import re, sys
t, msg = sys.stdin.read(), sys.argv[1]
a = t.index("### 3. "); b = t.index("### 4. ")
s3 = t[a:b]
bad = []
bullet = next((l for l in s3.splitlines() if l.startswith("- `claim_rc=` 가 0 이면")), "")
m = re.search(r"`claim_rc=3` 이고 출력에 `([^`]+)` 이 있으면 멈추지 않고 아래 「옛 PR 캐시 다시 채우기」 로 간다", bullet)
if not m:
    bad.append("claim 줄에 rc 3 + 옛 줄 갈래가 없다")
elif not msg or m.group(1) not in msg:
    bad.append("갈래의 문구가 OldPrRows 메시지에 없다: %r" % m.group(1))
if "takeover 펜스의 출력에 그 문구가 있어도 같다" not in bullet:
    bad.append("takeover 출력 갈래가 없다")
parts = s3.split("`" * 3)
fence = next((parts[i] for i in range(1, len(parts), 2) if "pr-refresh" in parts[i]), "")
rs = "python3 \"$SD/scripts/conductor_ledger.py\" pr-refresh --roadmap \"<로드맵>\" --session \"$sid\" --reset; reset_rc=$?"
rel = "python3 \"$SD/scripts/conductor_ledger.py\" release --roadmap \"<로드맵>\" --session \"$sid\" && "
cl = "python3 \"$SD/scripts/conductor_ledger.py\" claim --roadmap \"<로드맵>\" --session \"$sid\"; claim_rc=$?"
ix = [fence.find(k) for k in (rs, "if [ \"$reset_rc\" = 0 ]; then cd \"<root>\" && " + rel + cl, "echo \"claim_rc=")]
if min(ix) < 0 or ix != sorted(ix):
    bad.append("다시 채우기 펜스가 reset → (0 이면) release → claim 순서가 아니다: %r" % ix)
if "[ -n \"$sid\" ] ||" not in fence:
    bad.append("다시 채우기 펜스에 세션 id 멈춤이 없다")
tail = parts[parts.index(fence) + 1] if fence in parts else ""
for lit in ("- `reset_rc=` 가 0 이 아니면 그 사유", "멈춘다", "- `claim_rc=` 가 0 이면 4 로 간다", "위 5 와 같이 한다"):
    if lit not in tail:
        bad.append("펜스 뒤 처리 줄이 없다: %s" % lit)
print(" | ".join(bad) or "ok")'
assert_contains "$OLD_MSG" "--reset" "OldPrRows 메시지를 실제로 얻었다(--reset 명령을 담는다)"
assert_eq "$(python3 -I -c "$reset_branch_check" "$OLD_MSG" < "$SK")" "ok" "3절: claim rc 3 + 옛 PR 캐시 줄 → reset → release → claim 갈래"
for mut in '단 `claim_rc=3` 이고|단 claim 이 3 이고' '`옛 판이 쓴 PR 캐시 줄` 이 있으면 멈추지 않고|`옛 판 PR 줄` 이 있으면 멈추지 않고' \
           'release --roadmap "<로드맵>" --session "$sid" && |' '- `reset_rc=` 가 0 이 아니면|- reset 이 실패하면'; do
  from="${mut%%|*}"; to="${mut#*|}"
  applied="$(grep -cF -- "$from" "$SK")"
  got="$(python3 -I -c 'import sys
t = sys.stdin.read()
print(t.replace(sys.argv[1], sys.argv[2], 1))' "$from" "$to" < "$SK" | python3 -I -c "$reset_branch_check" "$OLD_MSG")"
  [ "$applied" = "1" ] && [ -n "$got" ] && [ "$got" != "ok" ] && ok "양성 대조: 「${from}」 를 바꾸면 갈래 락이 잡는다" || no "양성 대조: 「${from}」 를 바꿔도 갈래 락이 통과한다"
done
assert_not_contains "$(cat "$ROOT/plugins/spec-distill/references/conducting.md")" '옛 시작 승인이 지워진다' "conducting: 옛 시작 승인 괄호가 없다"
assert_contains "$(cat "$ROOT/plugins/spec-distill/references/conducting.md")" '다시 채운 뒤 `ledger release` → `ledger claim` 으로 표지를 다시 잡는다' "conducting 걸음 1: 다시 채운 뒤 표지를 풀었다 다시 잡는다"
assert_contains "$(cat "$AG")" '내는 형식은 아래 `## 내는 것`' "agent: 출력 형식은 내는 것 절"
CM="$ROOT/CLAUDE.md"
COST="$(grep -F '**모든 skill에 `cost_class` 선언**' "$CM")"
assert_contains "$COST" '어느 클래스의 skill 도 지출 승인을 묻지 않는다' "CLAUDE.md: cost 줄이 지출 승인을 묻지 않는다(양)"
assert_eq "$(grep -c '이름 붙인 예외' "$CM")" "0" "CLAUDE.md: 이름 붙인 예외가 없다 — 물을 게이트가 없어 예외가 할 일이 없다"
others="$(grep -l '이름 붙인 예외' "$ROOT"/plugins/*/skills/*/SKILL.md || true)"
assert_eq "$others" "" "예외를 주장하는 skill 이 없다(epic-conductor 포함)"
# 지휘자 수리 2 — 보이기: 지휘자 질문과 brainstorming 대화의 모양을 나눈다 · 에픽 이름은 질문 문장 앞머리
SHOW="$(awk '$0=="## 보이기"{f=1;next} f&&/^## /{exit} f' "$SK")"
for lit in '질문 문장 앞머리에 에픽 이름을 쓴다' 'brainstorming 대화는 brainstorming 이 정한 메시지 모양(첫 메시지 · 열린 문장 질문 하나 · 되비춤)을 따른다' \
           '위 규칙의 순서(첫 줄 상태 · 끝 할 일)를 붙이지 않고 낱말 규칙만 지키며' '그 메시지에 얹지 않고 따로 된 메시지로 보인다' '「계획 담당자」 · 「구현 담당자」'; do
  assert_contains "$SHOW" "$lit" "보이기: $lit"
done
assert_contains "$SHOW" '같은 턴에 원천(하니스 agent 목록 · 상태 계산 · 실행 원장)을 다시 조회하고 「HH:MM 기준」 을 붙인다' "보이기: 진행 상황은 원천에서 다시 세고 기준 시각을 붙인다(지휘자 수리 2)"
assert_not_contains "$SHOW" '질문마다 첫 줄에 에픽 이름' "보이기: 에픽 이름을 따로 된 첫 줄로 쓰던 옛 문장이 없다(양성 짝: 질문 문장 앞머리)"
finish
