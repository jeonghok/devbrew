#!/usr/bin/env bash
# test_review_scope_composition.sh — AC11 · spec §2: v10 리뷰어 구성.
#
# 기본 셋(code-reviewer · security-reviewer · codex) + 조건부 넷(pr-test-analyzer ·
# silent-failure-hunter · type-design-analyzer · comment-analyzer) + 재비판(code-recritic).
# `scout.py` · `feature-dev:code-architect` 는 qg 어디에서도 dispatch 되지 않는다(AC11).
# body-unique 문구를 요구한다(헤더-satisfiable 함정 회피). 선택 정확성은 게이트하지 않는다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
QG="$ROOT/plugins/quality-gates"
. "$ROOT/shared/tests/assert.sh"

# Step 3 창 — 구성 표와 dispatch 가 사는 자리
S3="$(awk '/^### Step 3 — reviewers/{f=1;next} f&&/^### /{exit} f' "$SKILL")"
[ -n "$S3" ] && ok "Step 3 창을 찾았다" || { no "Step 3 창이 없다 — 아래가 공허하다"; finish; exit; }

for row in '| 정확성 | `pr-review-toolkit:code-reviewer` | 항상 |' \
           '| 보안 | `quality-gates:security-reviewer` | 항상 |' \
           '| 다른 모델 계열 | codex 러너 | 항상 시도 |' \
           '| 재비판 | `quality-gates:code-recritic` | 항상(탐지 0건이어도) — Step 3.5 |'; do
  assert_contains "$S3" "$row" "구성 표 행: $row"
done
for a in pr-test-analyzer silent-failure-hunter type-design-analyzer comment-analyzer; do
  assert_grep "$S3" "^\| [^|]+ \| \`pr-review-toolkit:$a\` \| [^|]{12,} \|$" "조건부 행 — $a 가 신호 규칙을 갖는다"
done
assert_contains "$S3" '> [quality-gates] iter N — 선택:' "transparency 줄"
assert_contains "$S3" 'unavailable (<plugin> 미설치) — degraded coverage' "미설치 degrade 는 loud"
assert_not_grep "$S3" '^[[:space:]]*model:' "외부 dispatch 에 model: override 가 없다"

# AC23 — 리뷰 diff 는 Step 1 의 review-diff.sh 한 펜스가 만들고, 모든 리뷰어가 같은 파일을 받는다.
S1="$(awk '/^### Step 1 — scope$/{f=1;next} f&&/^### Step 1b/{exit} f' "$SKILL")"
[ -n "$S1" ] && ok "Step 1 창을 찾았다" || no "Step 1 창이 없다 — 아래 Step 1 단언이 공허하다"
assert_grep "$S1" 'review-diff\.sh" --dir "\$RD" --iter' "Step 1: 리뷰 diff 는 review-diff.sh 한 펜스가 만든다(AC23)"
assert_not_grep "$S1" 'exclude-standard    # \(c\)' "Step 1: 모델이 세 집합을 손으로 합치던 펜스가 없다"
assert_contains "$S1" '`files:`' "Step 1: \$resolved_scope_file_count 는 review-diff 의 files: 값"
assert_contains "$S1" '문서 경로' "Step 1: 문서 경로 공시 줄을 정한다(양성 짝)"
assert_contains "$S1" '`self_state:`' "Step 1c: review-diff 의 self_state: 를 읽는다"
assert_grep "$S1" '`> \[quality-gates\] qg 상태 파일이라 리뷰에서 건너뛴 추적 안 되는 경로 <[^>]+>개: <review-i<N>\.self-state 의 경로들>`' \
  "Step 1c: 건너뛴 qg 상태 경로를 공시한다(조용히 넘기지 않는다)"
assert_eq "$(grep -c 'README\*' "$SKILL")" "0" "SKILL 에 문서 경로 패턴을 다시 적지 않는다 — 규칙은 doc_paths.py 하나"
S3X="$(awk '/^### Step 3 — reviewers$/{f=1;next} f&&/^### Step 3\.5/{exit} f' "$SKILL")"
[ -n "$S3X" ] && ok "Step 3 창(Step 3.5 앞까지)을 찾았다" || no "Step 3 창(Step 3.5 앞까지)이 없다"
assert_contains "$S3X" 'review-i<N>.diff' "Step 3: FILTERED_DIFF 와 codex diff 는 review-i<N>.diff"
FV="$(awk '/^## Final verdict$/{f=1;next} f&&/^## Publish$/{exit} f' "$SKILL")"
[ -n "$FV" ] && ok "Final verdict 창을 찾았다" || no "Final verdict 창이 없다"
assert_contains "$FV" '--reason scope-empty' "걸러진 diff 가 빈 실행은 scope-empty 판정 펜스로 끝난다"
# 그 펜스를 실제로 돌린다 — 판정 줄이 not-certified (scope-empty) 이고 iteration 번호를 싣는다.
SEF="$(printf '%s\n' "$FV" | awk '/^```bash$/{f=1;b="";next} f&&/^```$/{if(b ~ /--reason scope-empty/) printf "%s", b; f=0; next} f{b=b $0 "\n"}')"
if [ -z "$SEF" ]; then
  no "Final verdict 에 --reason scope-empty 를 부르는 bash 펜스가 없다"
else
  SET="$(mktemp -d)"
  git -C "$SET" init -q && git -C "$SET" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  mkdir -p "$SET/.claude/quality-gates/scopeempty01"
  printf '%s\n' "$SEF" | sed 's/<session-id>/scopeempty01/g; s/<N>/2/g' > "$SET/run.sh"
  seo="$(cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/run.sh" 2>&1)"
  assert_contains "$seo" 'verdict rc=0' "scope-empty 펜스가 verdict.py 를 rc 0 으로 끝낸다"
  assert_grep "$(tail -n 1 "$SET/.claude/quality-gates/scopeempty01/verdict.out" 2>/dev/null)" \
    '^qg: not-certified \(scope-empty\) · .* · e2e 안 함 · .* · iter 2 · [0-9a-f]+$' \
    "scope-empty 펜스의 판정 줄 — not-certified (scope-empty) · e2e 안 함 · 그 iteration 번호"
  rm -rf "$SET"
fi

# AC11 — 옛 구성의 부재(플러그인 표면 전체). 양의 짝은 위 표 행이다.
hits="$(grep -rlE 'scout\.py|feature-dev:code-architect' "$QG/skills" "$QG/commands" "$QG/agents" "$QG/scripts" "$QG/references" 2>/dev/null)"
assert_eq "$hits" "" "scout.py · feature-dev:code-architect 를 부르는 표면이 없다 (AC11)"
[ -e "$QG/scripts/scout.py" ] && no "scripts/scout.py 가 남아 있다" || ok "scripts/scout.py 부재"
assert_not_grep "$(cat "$SKILL")" 'depth|quick-depth|scout' "줄 수 depth 안내가 없다"
for tok in '0-100' '0–100' '/100' 'code-simplifier' 'security-auditor' 'secret-masking'; do
  assert_not_grep "$(cat "$SKILL")" "$tok" "non-goal 토큰 부재: $tok"
done
finish
