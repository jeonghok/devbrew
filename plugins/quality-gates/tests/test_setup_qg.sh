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

finish
