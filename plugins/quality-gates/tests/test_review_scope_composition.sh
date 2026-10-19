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

# 1c 표 — 기본 scope 를 정하는 행은 펜스의 자리표시가 아니라 이 행들이다. 줄 전체로 잰다
# (session 행을 --mode branch 로 바꾸면 커밋 안 한 · 추적 안 된 파일이 조용히 빠진다 — A20).
for row in '   | session | `--mode session` |' \
           '   | branch | `--mode branch` |' \
           '   | paths | `--mode paths --globs <glob>...` (`--paths` 의 glob 그대로) |'; do
  assert_eq "$(printf '%s\n' "$S1" | grep -cxF -- "$row")" "1" "1c 표 행(줄 전체): $row"
done

# 1c 규칙 — 각 규칙은 그 규칙만의 줄에서 잰다(헤더 · 다른 줄이 대신 만족시키지 못하게).
DOCL="$(printf '%s\n' "$S1" | grep -F '매 iteration 공시 한 줄' | grep -F '`> [quality-gates] 문서 경로 <doc_paths>(출처: <기본 | 환경 변수 | 기본 — 이 변경이 설정을 바꿨다>) — 리뷰에서 뺀 경로 <excluded>개.`')"
assert_eq "$(printf '%s\n' "$DOCL" | grep -c .)" "1" "1c: 매 iteration 문서 경로 공시 줄(리터럴 그대로)"
assert_contains "$DOCL" '`default` 면 「기본」, `env` 면 「환경 변수」, `default-settings-changed` 면 「기본 — 이 변경이 설정을 바꿨다」' \
  "1c: 그 공시 줄의 출처 매핑 셋"
EMP="$(printf '%s\n' "$S1" | grep -F '`files:` 가 0 보다 크고 `filtered_files: 0` 이면 ')"
assert_eq "$(printf '%s\n' "$EMP" | grep -c .)" "1" "1c: 걸러진 diff 가 빈 갈래의 조건 줄이 하나"
assert_contains "$EMP" '`> [quality-gates] 리뷰할 diff 가 비었다 — 바뀐 파일 <files>개가 전부 문서 경로라 리뷰에서 뺐다. 이 실행은 clean 이 아니다.`' \
  "1c: 빈 diff 공시 줄(리터럴 그대로)"
assert_contains "$EMP" '를 내고 리뷰어 · 차등 테스트 · e2e 를 건너뛰어 [Final verdict](#final-verdict) 의 「걸러진 diff 가 빈 실행」 펜스로 간다.' \
  "1c: 빈 diff 면 리뷰어 · 차등 · e2e 를 건너뛰고 Final verdict 의 그 펜스로 간다(긍정형 목적지)"
DEG="$(printf '%s\n' "$S1" | grep -F '`degraded: yes` 면 기준선을 풀지 못해')"
assert_eq "$(printf '%s\n' "$DEG" | grep -c .)" "1" "1c: degraded 규칙 줄이 하나"
assert_grep "$DEG" '^[[:space:]]*- stdout 의 `degraded:` 를 먼저 읽는다\. ' "1c: degraded: 를 먼저 읽는다"
assert_contains "$DEG" '`self_state:` 의 `-` 를 0 으로 읽지 않고, Step 1b 의 「정할 수 없으면」 규칙대로 Step 4.5 의 degraded 갈래로 싣는다.' \
  "1c: degraded 면 - 를 0 으로 읽지 않고 degraded 갈래로"
assert_contains "$DEG" '이때는 아래 문서 경로 공시 · 상태 파일 공시와 빈 diff 갈래를 건너뛴다.' "1c: degraded 면 공시와 빈 diff 갈래를 건너뛴다"
assert_contains "$DEG" '차등 테스트의 D2 가 같은 기준선을 풀지 못해 exit 4 로 멈추므로 판정 입력이 error-axis 가 된다' \
  "1c: degraded 의 빈 diff 실행은 차등 테스트에서 error-axis — clean 이 아니다"

# Step 3.5 — 재비판 diff 사본을 못 만들면 펜스가 멈춘다(빈 사본으로 재비판하지 않는다).
S35="$(awk '/^### Step 3\.5/{f=1;next} f&&/^### Step 4/{exit} f' "$SKILL")"
assert_grep "$S35" '^[[:space:]]*cp "\$RD/review-i<N>\.diff" "\$RV/recritic\.diff" \|\| \{ echo "\[quality-gates\] [^"]+" >&2; exit 1; \}$' \
  "Step 3.5: 재비판 diff 사본 cp 가 실패하면 이유를 stderr 에 내고 exit 1"
S3X="$(awk '/^### Step 3 — reviewers$/{f=1;next} f&&/^### Step 3\.5/{exit} f' "$SKILL")"
[ -n "$S3X" ] && ok "Step 3 창(Step 3.5 앞까지)을 찾았다" || no "Step 3 창(Step 3.5 앞까지)이 없다"
assert_contains "$S3X" 'review-i<N>.diff' "Step 3: FILTERED_DIFF 와 codex diff 는 review-i<N>.diff"
FV="$(awk '/^## Final verdict$/{f=1;next} f&&/^## Publish$/{exit} f' "$SKILL")"
[ -n "$FV" ] && ok "Final verdict 창을 찾았다" || no "Final verdict 창이 없다"
assert_contains "$FV" '--reason scope-empty' "걸러진 diff 가 빈 실행은 scope-empty 판정 펜스로 끝난다"
assert_contains "$FV" '걸러진 diff 가 빈 실행(Step 1c 에서 `files:` 가 0 보다 크고 `filtered_files: 0`)' \
  "Final verdict 의 받는 자리가 1c 와 같은 이름 · 같은 조건이다"
assert_contains "$FV" '`--new-failures 0` 은 차등 테스트를 돌지 않았기 때문이다' "scope-empty 펜스의 차등 새 실패 0 은 차등을 돌지 않아서임을 밝힌다"
# 그 펜스를 실제로 돌린다 — 판정 줄이 not-certified (scope-empty) 이고 iteration 번호와
# 앞 iteration 들이 쌓은 제외 패치 수를 싣는다(N>1 이면 excluded.md 에 항목이 있을 수 있다).
SEF="$(printf '%s\n' "$FV" | awk '/^```bash$/{f=1;b="";next} f&&/^```$/{if(b ~ /--reason scope-empty/) printf "%s", b; f=0; next} f{b=b $0 "\n"}')"
if [ -z "$SEF" ]; then
  no "Final verdict 에 --reason scope-empty 를 부르는 bash 펜스가 없다"
else
  SET="$(mktemp -d)"
  git -C "$SET" init -q -b trunk \
    && git -C "$SET" -c commit.gpgsign=false -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  mkdir -p "$SET/.claude/quality-gates/scopeempty01"
  printf '%s\n' "$SEF" | sed 's/<session-id>/scopeempty01/g; s/<N>/2/g' > "$SET/run.sh"
  seo="$(cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/run.sh" 2>&1)"
  assert_contains "$seo" 'verdict rc=0' "scope-empty 펜스가 verdict.py 를 rc 0 으로 끝낸다(excluded.md 없음)"
  assert_grep "$(tail -n 1 "$SET/.claude/quality-gates/scopeempty01/verdict.out" 2>/dev/null)" \
    '^qg: not-certified \(scope-empty\) · .* · 차등 새 실패 0 · e2e 안 함 · 제외 패치 0 · iter 2 · [0-9a-f]+$' \
    "scope-empty 펜스의 판정 줄 — not-certified (scope-empty) · e2e 안 함 · 제외 0 · 그 iteration 번호"
  printf -- '- #1 a.py — 사유 x\n- #2 b.py — 사유 y\n' > "$SET/.claude/quality-gates/scopeempty01/excluded.md"
  seo="$(cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/run.sh" 2>&1)"
  assert_contains "$seo" 'verdict rc=0' "scope-empty 펜스가 excluded.md 가 있어도 rc 0"
  assert_grep "$(tail -n 1 "$SET/.claude/quality-gates/scopeempty01/verdict.out" 2>/dev/null)" \
    ' · 제외 패치 2 · iter 2 · ' "scope-empty 펜스가 앞 iteration 의 제외 패치 수를 excluded.md 에서 센다"
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
