#!/usr/bin/env bash
# test_setup_qg.sh — verify setup-qg.sh --ensure behavior against v1.32.1
# state schema. Replaces the v1.32.0-era assertions against removed schema
# keys (runtime_resolution_iter:, project_dir:) and removed stderr warnings.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/setup-qg.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# assert <label> <cmd> — eval 판정 래퍼. cmd 가 임의 셸 조건식이라 assert_eq 류로
# 환원되지 않는다(census "정본에 갈 자리가 없다" 처분과 동형, run_case 참고) —
# 판정만 정본(ok/no)에 위임한다.
assert() {
  local label="$1" cmd="$2"
  if eval "$cmd"; then ok "$label"
  else no "$label"; fi
}

# --- Case 1: fresh state creation ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-fresh-$$"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
STATE_FILE=".claude/quality-gates/$SID/result.md"
assert "fresh state file created" "test -f '$STATE_FILE'"
assert "state contains session_id" "grep -q 'session_id:' '$STATE_FILE'"
assert "state has no runtime_max_resolutions (해소 루프 제거)" "! grep -q 'runtime_max_resolutions' '$STATE_FILE'"
assert "v1.32.0 schema: no project_dir in state" "! grep -q '^project_dir:' '$STATE_FILE'"
assert "v1.32.0 schema: no gate2_iteration phantom" "! grep -q '^gate2_iteration:' '$STATE_FILE'"
# K-2 — setup 은 frontmatter(session_id · started_at)와 제목만 쓴다.
assert "K-2: session_id 가 이 SID 다" "grep -qx 'session_id: \"$SID\"' '$STATE_FILE'"
assert "K-2: started_at 이 있다" "grep -q '^started_at: \"' '$STATE_FILE'"
assert "K-2: 제목이 '# qg result' 다" "grep -qx '# qg result' '$STATE_FILE'"
assert "K-2: 옛 '## History' 절이 없다" "! grep -q '^## History' '$STATE_FILE'"
# K-1 「② 뒤」 — setup 이 옛 이름(pipeline.md)으로는 쓰지 않는다. 위 test -f 가 양의 짝이다.
assert "K-1: setup 이 pipeline.md 를 쓰지 않는다" "! test -e '.claude/quality-gates/$SID/pipeline.md'"
cd / && rm -rf "$TMPDIR"

# --- Case 2: --ensure idempotency (second call is no-op; same mtime) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-ensure-$$"
unset CLAUDE_CODE_SESSION_ID
CLAUDE_CODE_SESSION_ID="$SID" "$SCRIPT" --ensure >/dev/null 2>&1
STATE_FILE=".claude/quality-gates/$SID/result.md"
mtime1=$(stat -f %m "$STATE_FILE" 2>/dev/null || stat -c %Y "$STATE_FILE")
sleep 1
CLAUDE_CODE_SESSION_ID="$SID" "$SCRIPT" --ensure >/dev/null 2>&1
mtime2=$(stat -f %m "$STATE_FILE" 2>/dev/null || stat -c %Y "$STATE_FILE")
assert "--ensure idempotent (no rewrite)" "test '$mtime1' = '$mtime2'"
cd / && rm -rf "$TMPDIR"

# --- Case 3: DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS 는 더 읽히지 않는다 (대상 소멸) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-maxres-$$"
unset CLAUDE_CODE_SESSION_ID
DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS=99 "$SCRIPT" --session-id "$SID" >/dev/null 2>err
STATE_FILE=".claude/quality-gates/$SID/result.md"
assert "옛 해소 루프 스위치는 상태에 흔적이 없다" "! grep -q 'runtime_max_resolutions' '$STATE_FILE'"
assert "옛 해소 루프 스위치에 경고도 없다(읽는 자리가 없다)" "! grep -q 'RUNTIME_MAX_RESOLUTIONS' err"
cd / && rm -rf "$TMPDIR"

# --- Case 4: per-session folder isolation ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-isolation-$$"
unset CLAUDE_CODE_SESSION_ID
CLAUDE_CODE_SESSION_ID="$SID" "$SCRIPT" >/dev/null 2>&1
assert "session-isolated folder exists" "test -d '.claude/quality-gates/$SID'"
assert "no flat-layout state files" "! ls .claude/quality-gates*.md 2>/dev/null | grep -q ."
cd / && rm -rf "$TMPDIR"

# --- Case 5: missing both env and arg → hard fail ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" >/dev/null 2>err
RC=$?
assert "missing session-id hard-fails" "test '$RC' -ne 0"
assert "error message mentions session" "grep -qi 'session' err"
cd / && rm -rf "$TMPDIR"

# --- Case 6: 제거된 인자 넷 — 한 줄 공지 후 정상 진행 (AC1 · 설계 §6.5.2) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
for a in review runtime both --skip-runtime; do
  "$SCRIPT" "$a" --session-id "test-rm-${a#--}-$$" >out 2>err
  RC=$?
  assert "'$a' exits 0 (정상 진행)" "test '$RC' -eq 0"
  assert "'$a' 는 제거 공지를 정확히 한 줄 낸다" "test \"\$(grep -c '인자는 제거됐다' out)\" -eq 1"
  assert "'$a' 의 공지가 그 인자를 이름으로 댄다" "grep -qF -- '\`$a\`' out"
  assert "'$a' 는 Unknown argument 가 아니다" "! grep -qi 'Unknown argument' err out"
done
# 양의 짝 — 제거 인자가 없으면 공지도 없다(「언제나 공지」 변이를 막는다)
"$SCRIPT" --session-id "test-plain-$$" >out 2>err
assert "제거 인자가 없으면 공지가 없다" "! grep -q '인자는 제거됐다' out"
cd / && rm -rf "$TMPDIR"

# --- Case 7: 제거 인자 + 존치 인자 (Review Focus 2) · --paths · --gc (R-AE, 선재 결함) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" review --paths 'src/*' 'lib/*' --session-id "test-rp-$$" >out 2>err
RC=$?
assert "'review --paths …' exits 0" "test '$RC' -eq 0"
assert "'review --paths …' 의 공지는 review 하나뿐이다" "test \"\$(grep -c '인자는 제거됐다' out)\" -eq 1"
"$SCRIPT" --paths 'src/*' --session-id "test-p-$$" >/dev/null 2>err
RC=$?
assert "'--paths' 단독이 Unknown argument 로 죽지 않는다" "test '$RC' -eq 0 && ! grep -qi 'Unknown argument' err"
"$SCRIPT" --paths --session-id "test-pe-$$" >/dev/null 2>err
RC=$?
assert "'--paths' 뒤에 glob 이 없으면 exit 1 + 사유" "test '$RC' -eq 1 && grep -q 'requires at least one glob' err"
"$SCRIPT" --paths review --session-id "test-pkwonly-$$" >/dev/null 2>err
RC=$?
assert "'--paths review'(글롭 없이 키워드부터) 도 글롭 0개로 거부된다" "test '$RC' -eq 1 && grep -q 'requires at least one glob' err"
"$SCRIPT" --paths 'src/*' review --session-id "test-pkw-$$" >out 2>err
RC=$?
assert "'--paths glob review' 는 review 를 글롭으로 삼키지 않고 정확히 한 번 공지한다" "test '$RC' -eq 0 && test \"\$(grep -c '인자는 제거됐다' out)\" -eq 1 && grep -qF -- '\`review\`' out"
"$SCRIPT" --paths 'src/*' branch qg-fix1-branch-check --session-id "test-pbr-$$" >out 2>err
RC=$?
assert "'--paths glob branch <name>' 는 branch 를 글롭으로 삼키지 않고 branch <name> 안내로 끝난다" "test '$RC' -eq 2 && grep -qF -- '\`branch <name>\` 인자는 없어졌다' out"
"$SCRIPT" branch review --session-id "test-br-$$" >out 2>&1
RC=$?
assert "'branch review' 는 review 를 브랜치 이름으로 삼키지 않고 공지한다" "test '$RC' -eq 0 && grep -qF -- '\`review\` 인자는 제거됐다' out"
cd / && rm -rf "$TMPDIR"

# --- Case 8: v10 에서 없앤 인자 넷 — 안내 한 줄을 내고 실행하지 않는다 (AC25) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
i=0
for args in "branch feat-x" "--reset" "--gc" "--pr-url https://example.invalid/pull/1" "--paths src/* --gc"; do
  i=$((i+1)); sid="test-gone-$i-$$"
  # 인자 문자열을 일부러 단어로 쪼갠다 — "branch feat-x" 는 토큰 둘이다.
  # shellcheck disable=SC2086
  "$SCRIPT" $args --session-id "$sid" >out 2>err
  RC=$?
  assert "AC25: '$args' 는 exit 2" "test '$RC' -eq 2"
  assert "AC25: '$args' 는 안내를 정확히 한 줄 낸다" "test \"\$(grep -c '인자는 없어졌다' out)\" -eq 1"
  assert "AC25: '$args' 는 세션 폴더를 만들지 않는다(실행하지 않는다)" "test ! -e '.claude/quality-gates/$sid'"
  assert "AC25: '$args' 는 Unknown argument 가 아니다" "! grep -qi 'Unknown argument' err out"
done
"$SCRIPT" --reset --gc --session-id "test-gone-two-$$" >out 2>err
assert "AC25: 없앤 인자가 둘이면 안내도 두 줄" "test \"\$(grep -c '인자는 없어졌다' out)\" -eq 2"
# 양의 짝 — 남는 표면(맨 branch · --paths)은 그대로 돈다
"$SCRIPT" branch --session-id "test-bare-branch-$$" >out 2>err
RC=$?
assert "AC25: 맨 'branch' 는 exit 0 이고 안내가 없다" "test '$RC' -eq 0 && ! grep -q '인자는 없어졌다' out"
"$SCRIPT" branch --paths 'src/*' --session-id "test-branch-paths-$$" >out 2>err
RC=$?
assert "AC25: 'branch --paths glob' 는 exit 0 (--paths 를 브랜치 이름으로 읽지 않는다)" "test '$RC' -eq 0 && ! grep -q '인자는 없어졌다' out"
cd / && rm -rf "$TMPDIR"

# --- Case X4: setup 이 같은 세션에 남은 e2e 앱을 내린다(걷기 도중 끊긴 앞 실행) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-e2eleft-$$"
mkdir -p ".claude/quality-gates/$SID"
: > ".claude/quality-gates/$SID/result.md"
( python3 -c 'import os, sys
os.setsid()
open(sys.argv[2], "w").write(str(os.getpid()))
os.execvp("sleep", ["sleep", sys.argv[1]])' "301.$$" "$TMPDIR/lp" >/dev/null 2>&1 & )
i=0; while [ ! -s "$TMPDIR/lp" ] && [ "$i" -lt 20 ]; do sleep 0.1; i=$((i+1)); done
lp=$(cat "$TMPDIR/lp")
printf '%s %s\n' "$lp" "$(LC_ALL=C ps -o lstart= -p "$lp" | tr -s ' ' | sed 's/^ //; s/ $//')" > ".claude/quality-gates/$SID/e2e-app.pgid"
assert "X4: 대조 — 남은 앱이 떠 있다" "pgrep -f 'sleep 301.$$' >/dev/null"
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
sleep 0.5
assert "X4: setup 이 같은 세션의 남은 e2e 앱을 내린다" "! pgrep -f 'sleep 301.$$' >/dev/null"
pkill -f "sleep 301.$$" 2>/dev/null
cd / && rm -rf "$TMPDIR"

# --- Case X4b: 내리지 못하면 사유가 stderr 에 실린다 ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-e2ebad-$$"
mkdir -p ".claude/quality-gates/$SID"
: > ".claude/quality-gates/$SID/result.md"
printf '1 x\n' > ".claude/quality-gates/$SID/e2e-app.pgid"
"$SCRIPT" --session-id "$SID" >/dev/null 2>err
RC=$?
assert "X4b: stop 이 실패해도 setup 은 exit 0" "test '$RC' -eq 0"
assert "X4b: stderr 에 내리지 못한 사유가 실린다" "grep -q 'pgid 파일이 판독 불가' err"
cd / && rm -rf "$TMPDIR"

# --- AC21: range 인자 ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"; git init -q -b trunk; unset CLAUDE_CODE_SESSION_ID
out="$("$SCRIPT" --session-id "test-range-$$" range abc123 2>&1)"; rc=$?
assert "range <값>: rc 0" "[ $rc = 0 ]"
assert "range <값>: 모르는 인자로 읽지 않는다" "! printf '%s' \"\$out\" | grep -q '모르는 인자'"
out="$("$SCRIPT" --session-id "test-range-$$" range 2>&1)"; rc=$?
assert "range 값 없음: rc 1" "[ $rc = 1 ]"
assert "range 값 없음: 이유 한 줄" "printf '%s' \"\$out\" | grep -q 'range 뒤에 시작 커밋이 없다'"
out="$("$SCRIPT" --session-id "test-range-$$" range --gc 2>&1)"; rc=$?
assert "range 값이 - 로 시작: rc 1" "[ $rc = 1 ]"
assert "range 값이 - 로 시작: 이유" "printf '%s' \"\$out\" | grep -q 'range 의 값이 - 로 시작한다'"
for combo in "branch range x" "--paths a/* range x" "range x branch"; do
  out="$("$SCRIPT" --session-id "test-range-$$" $combo 2>&1)"; rc=$?
  assert "범위 인자 둘($combo): rc 1" "[ $rc = 1 ]"
  assert "범위 인자 둘($combo): 이유" "printf '%s' \"\$out\" | grep -q '범위 인자는 하나만'"
done
h="$("$SCRIPT" --help)"
assert "--help 가 range 를 안내한다" "printf '%s' \"\$h\" | grep -qF 'range <시작>[..<끝>]'"
assert "--help: --origin 줄 다음 줄이 roadmap: 과 로드맵 없음 을 담는다(AC17)" "printf '%s' \"\$h\" | grep -A1 -F -e '--origin <path>' | tail -1 | grep -qF 'roadmap:' && printf '%s' \"\$h\" | grep -A1 -F -e '--origin <path>' | tail -1 | grep -qF '로드맵 없음'"
assert "--help 가 critique 를 없어진 인자로 안내한다" "printf '%s' \"\$h\" | grep -qF 'critique (→ /quality-gates:artifact-critique)'"
out="$("$SCRIPT" --session-id "test-range-$$" range abc..def 2>&1)"; rc=$?
assert "range a..b: rc 0" "[ $rc = 0 ]"
assert "range a..b: 모르는 인자로 읽지 않는다" "! printf '%s' \"\$out\" | grep -q '모르는 인자'"
cd / && rm -rf "$TMPDIR"

# --- intent-critic --origin: 값 하나를 소비하고 범위 인자로 세지 않는다 ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
out="$("$SCRIPT" --session-id "test-origin-$$" --origin docs/brief.md 2>&1)"; rc=$?
assert "--origin <경로>: rc 0" "[ $rc = 0 ]"
assert "--origin <경로>: 모르는 인자로 읽지 않는다" "! printf '%s' \"\$out\" | grep -q '모르는 인자'"
assert "--origin <경로>: 실행이 진행해 세션 폴더를 만든다" "test -f '.claude/quality-gates/test-origin-$$/result.md'"
for combo in "range x --origin docs/a.md" "--paths a/* --origin docs/a.md" "--origin docs/a.md branch"; do
  out="$("$SCRIPT" --session-id "test-origin-$$" $combo 2>&1)"; rc=$?
  assert "범위 인자 하나 + --origin($combo): rc 0" "[ $rc = 0 ]"
  assert "범위 인자 하나 + --origin($combo): 범위 인자 둘로 세지 않는다" "! printf '%s' \"\$out\" | grep -q '범위 인자는 하나만'"
done
out="$("$SCRIPT" --session-id "test-origin-$$" range x --origin docs/a.md branch 2>&1)"; rc=$?
assert "--origin 사이의 range + branch 는 그대로 거부된다: rc 1" "[ $rc = 1 ]"
assert "--origin 사이의 range + branch 는 그대로 거부된다: 이유" "printf '%s' \"\$out\" | grep -q '범위 인자는 하나만'"
for rest in "" "--ensure" "-x"; do
  out="$("$SCRIPT" --session-id "test-origin-$$" --origin $rest 2>&1)"; rc=$?
  assert "--origin 값 없음(뒤: '$rest'): rc 1" "[ $rc = 1 ]"
  assert "--origin 값 없음(뒤: '$rest'): 이유 한 줄" "printf '%s' \"\$out\" | grep -qxF '❌ --origin 뒤에 원문 파일 경로가 없다.'"
done
h="$("$SCRIPT" --help)"
assert "--help 가 --origin 을 안내한다" "printf '%s' \"\$h\" | grep -qF -- \"--origin <path>      Caller's origin file for the intent critic (tracked file in this repo)\""
cd / && rm -rf "$TMPDIR"

# --- intent-critic --answered: --origin 과 같은 꼴 — 값 하나를 소비하고 범위 인자로 세지 않는다 ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
out="$("$SCRIPT" --session-id "test-answered-$$" --answered /tmp/x.yaml 2>&1)"; rc=$?
assert "--answered <경로>: rc 0" "[ $rc = 0 ]"
assert "--answered <경로>: 모르는 인자로 읽지 않는다" "! printf '%s' \"\$out\" | grep -q '모르는 인자'"
assert "--answered <경로>: 실행이 진행해 세션 폴더를 만든다" "test -f '.claude/quality-gates/test-answered-$$/result.md'"
for combo in "range x --answered /tmp/a.yaml" "--paths a/* --answered /tmp/a.yaml" "--answered /tmp/a.yaml branch" "range x --origin docs/a.md --answered /tmp/a.yaml"; do
  out="$("$SCRIPT" --session-id "test-answered-$$" $combo 2>&1)"; rc=$?
  assert "범위 인자 하나 + --answered($combo): rc 0" "[ $rc = 0 ]"
  assert "범위 인자 하나 + --answered($combo): 범위 인자 둘로 세지 않는다" "! printf '%s' \"\$out\" | grep -q '범위 인자는 하나만'"
done
for rest in "" "--ensure" "-x"; do
  out="$("$SCRIPT" --session-id "test-answered-$$" --answered $rest 2>&1)"; rc=$?
  assert "--answered 값 없음(뒤: '$rest'): rc 1" "[ $rc = 1 ]"
  assert "--answered 값 없음(뒤: '$rest'): 이유 한 줄" "printf '%s' \"\$out\" | grep -qxF '❌ --answered 뒤에 「이미 답한 것」 파일 경로가 없다.'"
done
h="$("$SCRIPT" --help)"
assert "--help 가 --answered 를 안내한다" "printf '%s' \"\$h\" | grep -qF -- \"--answered <path>    Conductor's already-answered file for the intent critic (absolute path)\""
cd / && rm -rf "$TMPDIR"

# --- --suite-lock (R7 §4 · AC11 · AC15): 값 검사 넷 · 잠금 자리 파일을 시작마다 지우고 인자가 있으면 다시 쓴다 ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
lpf() { printf '.claude/quality-gates/%s/suite-lock-path.txt' "$1"; }
folder_sig() { ( cd ".claude/quality-gates/$1" && ls -A && cksum result.md && stat -f %m result.md 2>/dev/null || stat -c %Y result.md ) 2>&1; }
# suite_lock_value_checks — 각각 rc 1 · 이유 한 줄 · 세션 폴더 그대로(잠금 자리 파일도 생기지 않는다)
SID="test-slcheck-$$"
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
mkdir -p "$TMPDIR/locks"
before="$(folder_sig "$SID")"
check_refused() {   # check_refused <이름> <기대 줄> <인자...>
  local name="$1" want="$2" out rc; shift 2
  out="$("$SCRIPT" --ensure --session-id "$SID" "$@" 2>&1)"; rc=$?
  assert "suite_lock_value_checks($name): rc 1" "[ $rc = 1 ]"
  assert "suite_lock_value_checks($name): 이유 한 줄" "printf '%s\n' \"\$out\" | grep -qxF -- \"\$want\""
  assert "suite_lock_value_checks($name): 세션 폴더가 그대로다" "[ \"\$(folder_sig \"$SID\")\" = \"\$before\" ]"
  assert "suite_lock_value_checks($name): 잠금 자리 파일이 생기지 않는다" "! test -e '$(lpf "$SID")'"
}
check_refused "값 없음" '❌ --suite-lock 뒤에 잠금 폴더 경로가 없다.' --suite-lock
check_refused "-x" '❌ --suite-lock 뒤에 잠금 폴더 경로가 없다.' --suite-lock -x
check_refused "--ensure 가 값 자리" '❌ --suite-lock 뒤에 잠금 폴더 경로가 없다.' --suite-lock --ensure
check_refused "상대경로" '❌ --suite-lock 은 절대경로여야 한다: locks/suite-lock' --suite-lock locks/suite-lock
check_refused "없는 부모" "❌ --suite-lock 의 부모 폴더가 없다: $TMPDIR/nope/deeper" --suite-lock "$TMPDIR/nope/deeper/suite-lock"
# suite_lock_written — 새로 만든 세션 폴더에 한 줄로 남는다
SID="test-slwrite-$$"; L="$TMPDIR/locks/suite-lock"
out="$("$SCRIPT" --session-id "$SID" --suite-lock "$L" 2>&1)"; rc=$?
assert "suite_lock_written: rc 0" "[ $rc = 0 ]"
assert "suite_lock_written: 잠금 자리 파일이 그 경로 한 줄이다" "[ \"\$(cat '$(lpf "$SID")')\" = '$L' ] && [ \"\$(wc -l < '$(lpf "$SID")' | tr -d ' ')\" = 1 ]"
assert "suite_lock_written: 잠금 폴더 자체는 만들지 않는다" "! test -e '$L'"
# ensure_rewrites — --ensure 가 폴더를 그대로 두는 갈래에서도 지우고 다시 쓴다
SID="test-slensure-$$"; A="$TMPDIR/locks/a"; B="$TMPDIR/locks/b"
"$SCRIPT" --ensure --session-id "$SID" --suite-lock "$A" >/dev/null 2>&1
assert "ensure_rewrites: 처음 --ensure --suite-lock A → A" "[ \"\$(cat '$(lpf "$SID")')\" = '$A' ]"
m1=$(stat -f %m ".claude/quality-gates/$SID/result.md" 2>/dev/null || stat -c %Y ".claude/quality-gates/$SID/result.md")
sleep 1
"$SCRIPT" --ensure --session-id "$SID" >/dev/null 2>&1
assert "ensure_rewrites: 같은 세션 --ensure 인자 없이 → 잠금 자리 파일 없음" "! test -e '$(lpf "$SID")'"
"$SCRIPT" --ensure --session-id "$SID" --suite-lock "$B" >/dev/null 2>&1
assert "ensure_rewrites: --ensure --suite-lock B → B 만" "[ \"\$(cat '$(lpf "$SID")')\" = '$B' ]"
m2=$(stat -f %m ".claude/quality-gates/$SID/result.md" 2>/dev/null || stat -c %Y ".claude/quality-gates/$SID/result.md")
assert "ensure_rewrites: --ensure 는 그동안 결과 파일을 다시 쓰지 않았다" "[ '$m1' = '$m2' ]"
"$SCRIPT" --session-id "$SID" --suite-lock "$A" >/dev/null 2>&1
assert "ensure_rewrites: --ensure 없이 다시 만든 폴더에도 새 경로가 남는다" "[ \"\$(cat '$(lpf "$SID")')\" = '$A' ]"
# no_arg_no_files — 인자가 없으면 잠금 자리 · 겹침 기록 파일이 없고 출력 글자가 그대로다
SID="test-slnoarg-$$"
base_out="$("$SCRIPT" --session-id "$SID" 2>&1)"
assert "no_arg_no_files: 잠금 자리 파일이 없다" "! test -e '$(lpf "$SID")'"
assert "no_arg_no_files: 겹침 기록 파일이 없다" "! test -e '.claude/quality-gates/$SID/suite-overlap.txt'"
assert "no_arg_no_files: 인자 없는 출력은 시작 줄 하나다" "[ \"\$base_out\" = '🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다.' ]"
arg_out="$("$SCRIPT" --session-id "$SID" --suite-lock "$L" 2>&1)"
assert "no_arg_no_files: 인자가 있어도 출력 글자가 같다" "[ \"\$arg_out\" = \"\$base_out\" ]"
# 범위 인자로 세지 않는다
out="$("$SCRIPT" --session-id "$SID" range x --suite-lock "$L" 2>&1)"; rc=$?
assert "range + --suite-lock: rc 0(범위 인자로 세지 않는다)" "[ $rc = 0 ]"
# lock_path_with_space — 공백 든 경로가 글자 그대로 남는다
SID="test-slspace-$$"; mkdir -p "$TMPDIR/with space"; LS="$TMPDIR/with space/suite lock"
"$SCRIPT" --session-id "$SID" --suite-lock "$LS" >/dev/null 2>&1; rc=$?
assert "lock_path_with_space: rc 0" "[ $rc = 0 ]"
assert "lock_path_with_space: 경로가 글자 그대로다" "[ \"\$(cat '$(lpf "$SID")')\" = \"\$LS\" ]"
h="$("$SCRIPT" --help)"
assert "--help 가 --suite-lock 을 안내한다" "printf '%s' \"\$h\" | grep -qF -- '--suite-lock <path>'"
cd / && rm -rf "$TMPDIR"

finish
