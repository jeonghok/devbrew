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
assert_contains "$S3" '선택: <리뷰어>(근거: <신호>)' "시작 줄의 선택 자리(옛 transparency 줄이 지키던 것 — 고른 리뷰어와 근거 공시)"
# AC24 — 리뷰어 상한 8 · 같은 리뷰어 재호출 금지 제거, 규모는 시작 · 끝 두 줄
assert_not_grep "$S3" 'at most 8|최대 8' "Step 3: 리뷰어 상한 8 이 없다(AC24 — 비용 장치 제거)"
assert_not_grep "$(cat "$SKILL")" 'Do not re-dispatch the same reviewer|같은 리뷰어를 다시 부르지' "같은 반복 재호출 금지가 없다(AC24)"
assert_contains "$S3" '시작 구성' "구성표는 시작 구성이다"
assert_contains "$S3" '> [quality-gates] iter N — 리뷰어 <계획한 수>명을 부른다(구성표 <a>명 · 근거를 적어 더한 <b>명)' "시작 줄 꼴"
assert_contains "$S3" '/ 더함: <리뷰어>(근거: <한 줄>)' "시작 줄의 더함 자리"
assert_contains "$S3" '> [quality-gates] iter N — 다시 부른 리뷰어 <r>명(일시 실패 재시도 <x> · 나눠 돌림 <y>)' "끝 줄 꼴"
start_ln=$(printf '%s\n' "$S3" | grep -n '리뷰어 <계획한 수>명을 부른다' | head -1 | cut -d: -f1)
end_ln=$(printf '%s\n' "$S3" | grep -n '다시 부른 리뷰어 <r>명' | head -1 | cut -d: -f1)
agent_ln=$(printf '%s\n' "$S3" | grep -n 'subagent_type: "quality-gates:security-reviewer"' | head -1 | cut -d: -f1)
[ -n "$start_ln" ] && [ -n "$agent_ln" ] && [ "$start_ln" -lt "$agent_ln" ] && ok "시작 줄은 첫 dispatch 앞에 있다(크게 쓰기 전에 규모를 알린다)" || no "시작 줄이 dispatch 뒤에 있거나 없다"
[ -n "$end_ln" ] && [ -n "$start_ln" ] && [ "$end_ln" -gt "$start_ln" ] && ok "끝 줄은 시작 줄 뒤에 있다(양성 짝 — 두 줄이 모두 있다)" || no "끝 줄이 없거나 시작 줄 앞이다"
assert_contains "$S3" '일시 실패' "일시 실패 1회 재시도 규칙"
assert_contains "$S3" '보안 리뷰어도 같다' "재시도는 보안 리뷰어에도 적용"
assert_contains "$S3" '나눠 돌림' "큰 diff 는 파일 묶음으로 나눠 같은 리뷰어를 나란히"
# final-review T7 — 보안 리뷰를 나눠 돌리면 묶음마다 fail-closed 다. 문단 줄 전체로 잰다(뒤에 예외를 붙이거나
# 「한 묶음이라도」를 약하게 바꾸면 줄이 달라진다). 시작 낱말로 그 줄이 하나뿐임을 따로 잰다(양성 짝).
assert_eq "$(printf '%s\n' "$S3" | grep -c '^\*\*fail-closed 의 뜻\*\* — ')" "1" "보안 fail-closed 문단 줄이 하나다(양성 짝)"
assert_eq "$(printf '%s\n' "$S3" | grep -cxF -- '**fail-closed 의 뜻** — 한 번 다시 부른(일시 실패 재시도) 두 번째 시도도 실패했거나 출력을 읽을 수 없으면 그 iteration 의 각도 파일에 `security: absent(source-failed)` 를 쓴다. 판정은 `not-certified (angle-absent)` 다. 다른 리뷰어의 finding 이 있다고 보안 각도가 채워진 것이 아니다. 보안 리뷰를 나눠 돌렸다면 묶음마다 따로 fail-closed 다 — 한 묶음이라도 두 번 실패하면 보안은 source-failed 다.')" "1" \
  "보안 리뷰를 나눠 돌리면 묶음마다 fail-closed — 한 묶음이라도 두 번 실패하면 source-failed (줄 전체)"
assert_not_grep "$(cat "$QG/README.md")" '최대 8|≤ 8|max fan-out' "README 에 리뷰어 상한 8 · 선언된 max fan-out 이 없다(AC24)"
assert_contains "$(cat "$QG/README.md")" '위 표는 시작 구성이다' "README 구성표는 시작 구성(양성 짝)"
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
# 그 펜스를 실제로 돌린다 — 판정 줄이 not-certified (scope-empty) 이고 iteration 번호와 제외 결과 줄의
# 제외 패치 수를 싣는다(N>1 이면 앞 반복의 제외 결과 줄이 있다). 판정 펜스는 excluded.md 를 다시 세지 않는다.
SEF="$(awk '$0 == "<!-- scope-empty-verdict:begin -->" {on=1; next} $0 == "<!-- scope-empty-verdict:end -->" {exit} on' "$SKILL")"
RMF="$(printf '%s\n' "$FV" | awk '/^```bash$/{f=1;b="";next} f&&/^```$/{if(b ~ /rm -f "\$RD\/differential\.yaml"/) printf "%s", b; f=0; next} f{b=b $0 "\n"}')"
if [ -z "$SEF" ] || ! printf '%s\n' "$SEF" | grep -q -- '--reason scope-empty'; then
  no "Final verdict 에 --reason scope-empty 를 부르는 표지 펜스가 없다"
else
  SET="$(mktemp -d)"
  git -C "$SET" init -q -b trunk \
    && git -C "$SET" -c commit.gpgsign=false -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  mkdir -p "$SET/.claude/quality-gates/scopeempty01"
  sef_fill() {   # sef_fill <출력> <제외 결과 줄>
    python3 -I "$QG/tests/lib/verdict_fence.py" "$SKILL" scope-empty-verdict "$1" "<session-id>=scopeempty01" "<N>=2" \
      "QG_ARGS_R=" "QG_ARGS_D=" "QG_ARGS_X=$2" "QG_ARGS_S=" "QG_ARGS_E="
  }
  sef_fill "$SET/run.sh" ""; sef_fill "$SET/run2.sh" "qg-verdict-args: --excluded 2"
  seo="$(cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/run.sh" 2>&1)"
  assert_contains "$seo" 'verdict rc=0' "scope-empty 펜스가 verdict.py 를 rc 0 으로 끝낸다(제외 결과 줄 없음)"
  assert_grep "$(tail -n 1 "$SET/.claude/quality-gates/scopeempty01/verdict.out" 2>/dev/null)" \
    '^qg: not-certified \(scope-empty\) · .* · 차등 새 실패 0 · e2e 안 함 · 제외 패치 0 · iter 2 · [0-9a-f]+$' \
    "scope-empty 펜스의 판정 줄 — not-certified (scope-empty) · e2e 안 함 · 제외 0 · 그 iteration 번호"
  printf -- '- #1 a.py — 사유 x\n- #2 b.py — 사유 y\n' > "$SET/.claude/quality-gates/scopeempty01/excluded.md"
  seo="$(cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/run.sh" 2>&1)"
  assert_grep "$(tail -n 1 "$SET/.claude/quality-gates/scopeempty01/verdict.out" 2>/dev/null)" \
    ' · 제외 패치 0 · iter 2 · ' "scope-empty 펜스는 excluded.md 를 다시 세지 않는다(제외 결과 줄이 없으면 0)"
  seo="$(cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/run2.sh" 2>&1)"
  assert_contains "$seo" 'verdict rc=0' "scope-empty 펜스가 제외 결과 줄이 있어도 rc 0"
  assert_grep "$(tail -n 1 "$SET/.claude/quality-gates/scopeempty01/verdict.out" 2>/dev/null)" \
    ' · 제외 패치 2 · iter 2 · ' "scope-empty 펜스가 앞 반복의 제외 결과 줄의 수를 싣는다"

  # final-review M3 — N>1 의 빈 diff 반복은 차등 테스트를 돌지 않는다. 앞 반복의 차등 사본이 남아
  # 이번 판정의 「## 차등 테스트」로 기록되지 않게 판정 펜스 앞의 펜스가 지운다. 기록 펜스까지 실제로 돌린다.
  SED="$SET/.claude/quality-gates/scopeempty01"
  printf 'new_failures: 3\nattribution_status: stale-from-iter-1\n' > "$SED/differential.yaml"
  printf -- '- tests/test_old.sh\n' > "$SED/differential-not-counted.md"
  if [ -z "$RMF" ]; then
    no "Final verdict 에 앞 반복의 차등 사본을 지우는 펜스가 없다"
  else
    printf '%s\n' "$RMF" | sed 's/<session-id>/scopeempty01/g' > "$SET/rm.sh"
    (cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/rm.sh" >/dev/null 2>&1)
  fi
  seo="$(cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/run.sh" 2>&1)"
  assert_contains "$seo" 'verdict rc=0' "scope-empty 펜스 rc 0 (앞 반복의 차등 사본을 지운 뒤)"
  [ ! -e "$SED/differential.yaml" ] && ok "지우기 펜스가 앞 반복의 differential.yaml 을 지운다" || no "앞 반복의 differential.yaml 이 남았다"
  [ ! -e "$SED/differential-not-counted.md" ] && ok "지우기 펜스가 앞 반복의 differential-not-counted.md 를 지운다" || no "앞 반복의 differential-not-counted.md 가 남았다"
  REC="$(printf '%s\n' "$FV" | awk '/^```bash$/{f=1;b="";next} f&&/^```$/{if(b ~ /printf .\\n## 판정/) printf "%s", b; f=0; next} f{b=b $0 "\n"}')"
  if [ -z "$REC" ]; then
    no "Final verdict 에 기록 펜스(## 판정)가 없다"
  else
    printf -- '---\nsession_id: "scopeempty01"\n---\n\n# qg result\n' > "$SED/result.md"
    # final-review M4 — 마지막 반복의 문서 경로 요약 줄을 result.md 에 남긴다(파일 목록은 싣지 않는다)
    printf 'doc_paths_source: env\ndoc_paths: README*,docs/human/**\nbad_patterns: [x\nexcluded: 2\nkept_model: 1\nexclude\tREADME.md\nexclude\tdocs/human/a.md\nkept\tdocs/human/SKILL.md\n' > "$SED/review-i2.doc-paths"
    printf '.claude/quality-gates/scopeempty01/a\n.claude/quality-gates/scopeempty01/b\n' > "$SED/review-i2.self-state"
    printf '%s\n' "$REC" | sed -e 's/<session-id>/scopeempty01/g' -e 's/<N>/2/g' -e 's|^SYN=.*$|SYN=""|' > "$SET/rec.sh"
    rco="$(cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/rec.sh" 2>&1)"; rcr=$?
    assert_eq "$rcr" "0" "기록 펜스 rc 0 (빈 diff 실행)"
    res="$(cat "$SED/result.md")"
    assert_contains "$(printf '%s\n' "$res" | sed -n '/^## 차등 테스트$/,/^## /p')" '(이번 실행에 차등 출력 없음)' "빈 diff 반복의 ## 차등 테스트 는 차등 출력 없음이다"
    assert_not_contains "$res" 'stale-from-iter-1' "앞 반복의 차등 사본이 result.md 에 들지 않는다"
    assert_not_contains "$res" 'tests/test_old.sh' "앞 반복의 커버리지 밖 목록이 result.md 에 들지 않는다"
    DPS="$(printf '%s\n' "$res" | awk '/^## 문서 경로$/{f=1;next} f&&/^## /{exit} f')"
    for l in 'doc_paths_source: env' 'doc_paths: README*,docs/human/**' 'bad_patterns: [x' 'excluded: 2' 'kept_model: 1' 'self_state: 2'; do
      assert_eq "$(printf '%s\n' "$DPS" | grep -cxF -- "$l")" "1" "## 문서 경로: 요약 줄 $l"
    done
    assert_not_grep "$DPS" '^(exclude|kept)'"$(printf '\t')" "## 문서 경로: 경로 목록 줄(exclude · kept)은 싣지 않는다"
    # 위조 방어 — 커밋된 파일 이름에 개행이 있으면 경로 줄 뒤에 요약처럼 보이는 줄이 생긴다. 머리 줄만 읽는다.
    printf -- '---\nsession_id: "scopeempty01"\n---\n\n# qg result\n' > "$SED/result.md"
    printf 'doc_paths_source: default\ndoc_paths: README*\nbad_patterns: -\nexcluded: 1\nkept_model: 0\nexclude\tREADME\nexcluded: 0\ndoc_paths_source: env\nkept_model: 9\n' > "$SED/review-i2.doc-paths"
    (cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/rec.sh" >/dev/null 2>&1)
    FDP="$(awk '/^## 문서 경로$/{f=1;next} f&&/^## /{exit} f' "$SED/result.md")"
    assert_eq "$(printf '%s\n' "$FDP" | grep -c '^excluded: ')" "1" "위조: ## 문서 경로 의 excluded 줄은 하나"
    assert_eq "$(printf '%s\n' "$FDP" | grep -cxF 'excluded: 1')" "1" "위조: excluded 는 진짜 값 1"
    assert_eq "$(printf '%s\n' "$FDP" | grep -c '^doc_paths_source: ')" "1" "위조: doc_paths_source 줄은 하나"
    assert_eq "$(printf '%s\n' "$FDP" | grep -cxF 'kept_model: 0')" "1" "위조: kept_model 은 진짜 값 0"
    # 양의 짝 — 평범한 파일은 요약 다섯 줄을 모두 낸다
    assert_eq "$(printf '%s\n' "$FDP" | grep -cE '^(doc_paths_source|doc_paths|bad_patterns|excluded|kept_model): ')" "5" "양의 짝: 평범한 파일은 요약 5줄"
    a=$(printf '%s\n' "$res" | grep -nx '## 판정' | head -1 | cut -d: -f1)
    b=$(printf '%s\n' "$res" | grep -nx '## 문서 경로' | head -1 | cut -d: -f1)
    c=$(printf '%s\n' "$res" | grep -nx '## 지적' | head -1 | cut -d: -f1)
    if [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ]; then
      ok "## 문서 경로 는 ## 판정 뒤 · ## 지적 앞이다 ($a < $b < $c)"
    else no "## 문서 경로 자리가 틀렸다 (판정 ${a:-0} · 문서 경로 ${b:-0} · 지적 ${c:-0})"; fi
    # 문서 경로 파일이 없는 실행(trivia 등)은 절을 쓰지 않는다(양의 짝: 기록은 돈다)
    rm -f "$SED/review-i2.doc-paths" "$SED/review-i2.self-state"
    printf -- '---\nsession_id: "scopeempty01"\n---\n\n# qg result\n' > "$SED/result.md"
    (cd "$SET" && CLAUDE_PLUGIN_ROOT="$QG" bash "$SET/rec.sh" >/dev/null 2>&1)
    assert_contains "$(cat "$SED/result.md")" '## 지적' "양의 짝: 문서 경로 파일이 없어도 기록은 돈다"
    assert_not_contains "$(cat "$SED/result.md")" '## 문서 경로' "문서 경로 파일이 없으면 ## 문서 경로 를 쓰지 않는다"
  fi
  rm -rf "$SET"
fi
SFF="$ROOT/plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md"
SFM="$(awk '/^```markdown$/{on=1;next} on&&/^```$/{exit} on{print}' "$SFF")"
a=$(printf '%s\n' "$SFM" | grep -nx '## 범위' | head -1 | cut -d: -f1)
b=$(printf '%s\n' "$SFM" | grep -nx '## 문서 경로' | head -1 | cut -d: -f1)
c=$(printf '%s\n' "$SFM" | grep -nx '## 지적' | head -1 | cut -d: -f1)
if [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ]; then
  ok "state-file-format: ## 문서 경로 는 ## 범위 뒤 · ## 지적 앞이다"
else no "state-file-format: ## 문서 경로 자리가 틀렸다 (범위 ${a:-0} · 문서 경로 ${b:-0} · 지적 ${c:-0})"; fi
assert_file_grep "$SFF" '`## 문서 경로` 는 마지막 반복의 `review-i<N>\.doc-paths` 가 비어 있지 않을 때만 쓴다' "state-file-format: 문서 경로 절의 생명주기"

# AC11 — 옛 구성의 부재(플러그인 표면 전체). 양의 짝은 위 표 행이다.
hits="$(grep -rlE 'scout\.py|feature-dev:code-architect' "$QG/skills" "$QG/commands" "$QG/agents" "$QG/scripts" "$QG/references" 2>/dev/null)"
assert_eq "$hits" "" "scout.py · feature-dev:code-architect 를 부르는 표면이 없다 (AC11)"
[ -e "$QG/scripts/scout.py" ] && no "scripts/scout.py 가 남아 있다" || ok "scripts/scout.py 부재"
assert_not_grep "$(cat "$SKILL")" 'depth|quick-depth|scout' "줄 수 depth 안내가 없다"
for tok in '0-100' '0–100' '/100' 'code-simplifier' 'security-auditor' 'secret-masking'; do
  assert_not_grep "$(cat "$SKILL")" "$tok" "non-goal 토큰 부재: $tok"
done
finish
