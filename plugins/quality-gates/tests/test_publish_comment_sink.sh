#!/usr/bin/env bash
# test_publish_comment_sink.sh — 게시 sink `scripts/publish-comment.sh` 의 행동(spec §5 · P1~P7 · AC12~AC14).
#
# gh 는 PATH 앞에 둔 스텁이다. 스텁은 모든 호출을 GH_LOG 에 한 줄씩 남기고, 동작은 환경 변수로 정한다.
# 「네트워크 호출 0」은 「gh 호출 0」으로 잰다 — sink 가 쓰는 다른 명령(git · python3)은 로컬이다.
# (qg v10 ③ plan 이 쓴 테스트 코드다 — 리뷰는 이 파일도 검사 대상으로 본다.)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SINK="$PLUGIN_ROOT/scripts/publish-comment.sh"
unset DEVBREW_QUALITY_GATES_DISABLE_PUBLISH DEVBREW_QUALITY_GATES_DISABLE

T="$(mktemp -d "${TMPDIR:-/tmp}/qg-sink-test.XXXXXX")" || { echo "mktemp 실패"; exit 1; }
trap 'rm -rf "$T"' EXIT

# ── gh 스텁 ────────────────────────────────────────────────────────────────
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
case "$1 ${2:-}" in
  "auth status") exit "${GH_AUTH_RC:-0}" ;;
  "pr view")
    case "${GH_PR:-none}" in
      none) echo 'no pull requests found for branch "feat"' >&2; exit 1 ;;
      error) echo 'HTTP 502: Bad Gateway' >&2; exit 1 ;;
      *) printf '%b\n' "$GH_PR"; exit 0 ;;
    esac ;;
  "pr comment")
    while [ $# -gt 0 ]; do
      if [ "$1" = "--body-file" ]; then cp "$2" "$GH_BODY_COPY"; fi
      shift
    done
    [ "${GH_COMMENT_RC:-0}" = 0 ] || { echo 'HTTP 403' >&2; exit "$GH_COMMENT_RC"; }
    echo 'https://github.com/o/r/pull/7#issuecomment-1'; exit 0 ;;
esac
exit 0
EOF
chmod +x "$T/bin/gh"
export GH_LOG="$T/gh.log" GH_BODY_COPY="$T/body.sent"

# gh 가 없는 PATH — git · python3 만 링크로 둔다.
mkdir -p "$T/nogh"
ln -s "$(command -v git)" "$T/nogh/git"
ln -s "$(command -v python3)" "$T/nogh/python3"
NOGH_PATH="$T/nogh:/usr/bin:/bin"

OPEN_PR='7\tOPEN\thttps://github.com/o/r/pull/7\tmain'

# ── 픽스처 리포: main 위에 feat 브랜치 커밋 하나 ─────────────────────────────
REPO="$T/repo"
git init -q -b main "$REPO"
g() { git -C "$REPO" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@t "$@"; }
echo base > "$REPO/a.txt"; g add a.txt; g commit -q -m base
g checkout -q -b feat
echo change > "$REPO/b.txt"; g add b.txt; g commit -q -m 'feat: change'

BODY="$T/body.md"
printf '## 이 변경을 한 줄로\n무엇이 바뀌나.\n\n---\nqg: clean · 막는 지적 0 · 선택 0 · 차등 새 실패 0 · 제외 패치 0 · iter 1 · abc1234\n' > "$BODY"

# run_sink <PATH> [sink args…] — 결과는 RC · OUT · LAST · GHCALLS 에 둔다. 매번 로그를 비운다.
run_sink() {
  local p="$1"; shift
  : > "$GH_LOG"; rm -f "$GH_BODY_COPY"
  OUT="$(cd "${SINK_CWD:-$REPO}" && PATH="$p" bash "$SINK" "$@" 2>"$T/err" </dev/null)"; RC=$?
  LAST="$(printf '%s\n' "$OUT" | tail -n 1)"
  GHCALLS="$(cat "$GH_LOG")"
}
WITH_GH="$T/bin:$PATH"

# P6 — 결과 줄은 stdout 마지막 줄 하나뿐이다.
p6_single_result_line() {   # <case 이름>
  local n
  n="$(printf '%s\n' "$OUT" | grep -cE '^(posted|skipped): ')"
  assert_eq "$n" "1" "P6 $1: 결과 줄이 정확히 하나"
  assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "1" "P6 $1: stdout 이 통틀어 한 줄"
}
no_comment_call() {  # <case 이름>
  if printf '%s\n' "$GHCALLS" | grep -q '^pr comment'; then no "$1: gh pr comment 가 불렸다"; else ok "$1: gh pr comment 호출 0"; fi
}

# ── AC12 — 정상 실행은 새 코멘트 정확히 하나 ─────────────────────────────────
case_AC12_posts_one_new_comment() {
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$RC" "0" "AC12: rc 0"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-1" "AC12: 마지막 줄 posted: <url>"
  p6_single_result_line AC12
  assert_eq "$(printf '%s\n' "$GHCALLS" | grep -c '^pr comment')" "1" "AC12: gh pr comment 정확히 한 번"
  assert_eq "$(printf '%s\n' "$GHCALLS" | grep -cE '^api|--edit-last|^pr edit')" "0" "AC12: 기존 코멘트 수정 경로(api · --edit-last · pr edit) 0"
  if cmp -s "$BODY" "$GH_BODY_COPY"; then ok "P4: gh 가 받은 본문이 파일 바이트 그대로"; else no "P4: gh 가 받은 본문이 다르다"; fi
  printf '%s\n' "$GHCALLS" | grep -q '^pr comment 7 --body-file ' \
    && ok "P4: 본문은 --body-file 로만 넘긴다" || no "P4: --body-file 이 아닌 경로로 넘겼다 ($GHCALLS)"
}

# ── AC13 — 건너뛰는 여섯 경우 ────────────────────────────────────────────────
case_AC13_no_pr() {
  GH_PR=none run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "skipped: no-pr" "AC13 no-pr: 마지막 줄"; assert_eq "$RC" "0" "AC13 no-pr: rc 0"
  p6_single_result_line no-pr; no_comment_call "AC13 no-pr"
}
case_AC13_pr_closed() {
  local st
  for st in MERGED CLOSED; do
    GH_PR="7\t${st}\thttps://github.com/o/r/pull/7\tmain" run_sink "$WITH_GH" --body-file "$BODY"
    assert_eq "$LAST" "skipped: pr-closed" "AC13 pr-closed(${st}): 마지막 줄"
    p6_single_result_line "pr-closed(${st})"; no_comment_call "AC13 pr-closed(${st})"
  done
}
case_AC13_kill_switch_AC14_zero_network() {
  DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1 GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "skipped: kill-switch" "AC13 kill-switch: 마지막 줄"
  assert_eq "$GHCALLS" "" "AC14: DISABLE_PUBLISH=1 이면 gh 호출이 0"
  DEVBREW_QUALITY_GATES_DISABLE=1 GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "skipped: kill-switch" "AC13 kill-switch(전역): 마지막 줄"
  assert_eq "$GHCALLS" "" "AC14: 전역 DISABLE=1 이면 gh 호출이 0"
  # 전체 토큰 일치(E5) — 「1」 밖의 값은 스위치가 아니다.
  DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=10 GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-1" "E5: DISABLE_PUBLISH=10 은 스위치가 아니다"
  DEVBREW_QUALITY_GATES_DISABLE=10 GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-1" "E5: 전역 DISABLE=10 도 스위치가 아니다"
}
case_AC13_scan_failed() {
  local bad="$T/bad.md"
  printf 'key AKIAIOSFODNN7EXAMPLE\n' > "$bad"
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$bad"
  assert_eq "$LAST" "skipped: scan-failed" "AC13 scan-failed: 알려진 패턴"
  p6_single_result_line scan-failed; no_comment_call "AC13 scan-failed"
}
case_AC13_gh_unavailable() {
  if PATH="$NOGH_PATH" command -v gh >/dev/null 2>&1; then
    no "전제: gh 없는 PATH 를 만들지 못했다 ($(PATH="$NOGH_PATH" command -v gh))"
  else
    run_sink "$NOGH_PATH" --body-file "$BODY"
    assert_eq "$LAST" "skipped: gh-unavailable" "AC13 gh 없음: 마지막 줄"
    p6_single_result_line gh-absent
  fi
  GH_AUTH_RC=1 GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "skipped: gh-unavailable" "AC13 미인증: 마지막 줄"
  assert_eq "$GHCALLS" "auth status" "P5: 미인증이면 auth 확인 뒤 gh 호출이 없다"
  GH_PR=error run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "skipped: gh-unavailable" "AC13 gh pr view 오류(no-pr 아님): 마지막 줄"
  GH_PR="$OPEN_PR" GH_COMMENT_RC=1 run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "skipped: gh-unavailable" "AC13 코멘트 쓰기 실패: posted 로 위장하지 않는다"
  p6_single_result_line comment-failed
}
case_AC13_too_long() {
  local at="$T/at.md" over="$T/over.md"
  python3 -c 'import sys; open(sys.argv[1],"w",encoding="utf-8").write("가"*65536)' "$at"
  python3 -c 'import sys; open(sys.argv[1],"w",encoding="utf-8").write("가"*65537)' "$over"
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$over"
  assert_eq "$LAST" "skipped: too-long" "AC13 too-long: 65,537자"
  no_comment_call "AC13 too-long"
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$at"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-1" "AC13 경계: 65,536자(196,608바이트)는 게시 — 바이트가 아니라 글자로 잰다"
}

# ── P1 — 통과는 첫 줄 리터럴 `scan_ok: yes` 하나로만 ─────────────────────────
case_P1_literal_scan_gate() {
  local fake="$T/fakeplug" variant
  mkdir -p "$fake/scripts"
  cp "$SINK" "$fake/scripts/publish-comment.sh"
  for variant in 'trailing-space' 'second-line' 'empty' 'yes-but-rc1'; do
    case "$variant" in
      trailing-space) printf 'print("scan_ok: yes ")\n' > "$fake/scripts/secret-scan.py" ;;
      second-line)    printf 'print("note")\nprint("scan_ok: yes")\n' > "$fake/scripts/secret-scan.py" ;;
      empty)          printf 'pass\n' > "$fake/scripts/secret-scan.py" ;;
      yes-but-rc1)    printf 'import sys\nprint("scan_ok: yes")\nsys.exit(1)\n' > "$fake/scripts/secret-scan.py" ;;
    esac
    : > "$GH_LOG"
    OUT="$(cd "$REPO" && GH_PR="$OPEN_PR" PATH="$WITH_GH" bash "$fake/scripts/publish-comment.sh" --body-file "$BODY" 2>/dev/null)"
    LAST="$(printf '%s\n' "$OUT" | tail -n 1)"
    if [ "$variant" = "yes-but-rc1" ]; then
      assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-1" "P1 ${variant}: exit code 가 아니라 첫 줄 리터럴로 판정"
    else
      assert_eq "$LAST" "skipped: scan-failed" "P1 ${variant}: 리터럴이 아니면 막는다"
    fi
  done
}

# ── P2 — degraded corpus · corpus 가 실제로 변경 내용·커밋 메시지·untracked 를 담는다 ──
case_P2_degraded_and_corpus_content() {
  GH_PR='7\tOPEN\thttps://github.com/o/r/pull/7\tnosuchbranch' run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "skipped: scan-failed" "P2: merge-base 없음 → degraded corpus → fail-closed"
  local tok="Kj8xQvN2mZ4pR7wL9tB3cF6yD1sA5gH0uE" leak="$T/leak.md"
  printf 'value %s\n' "$tok" > "$leak"
  # 고엔트로피 값은 corpus 에 있을 때만 잡힌다 — 대조군: corpus 에 없으면 통과한다.
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-1" "P2 대조군: corpus 밖 고엔트로피 값은 통과(알려진 한계)"
  g commit -q --allow-empty -m "ci: rotate $tok"
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "P2: 커밋 메시지가 corpus 에 들어간다"
  g reset -q --hard HEAD~1
  printf 'secret=%s\n' "$tok" > "$REPO/untracked.env"
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "P2: 무시되지 않는 untracked 파일이 corpus 에 들어간다"
  rm -f "$REPO/untracked.env"
  # base 이후 안 바뀐 a.txt 에 둔다 — 브랜치가 이미 커밋한 b.txt 와 달리 「커밋 안 된 변경」만이 이 값을 나른다.
  printf 'secret=%s\n' "$tok" > "$REPO/a.txt"
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "P2: 커밋 안 된 추적 파일 변경이 corpus 에 들어간다"
  g checkout -q -- a.txt
}

# ── P5 — 부작용 전에 인증 ────────────────────────────────────────────────────
case_P5_auth_before_side_effects() {
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$BODY"
  local first_line
  first_line="$(printf '%s\n' "$GHCALLS" | head -n 1)"
  assert_eq "$first_line" "auth status" "P5: 첫 gh 호출은 auth status"
}

# ── P4 · P7 — 본문·커밋 메시지·파일 이름은 데이터다 ─────────────────────────────
case_P4_P7_untrusted_bytes() {
  # 명령은 상대 경로로만 쓴다 — sink 는 리포에서 돌므로 실행됐다면 $REPO 에 파일이 생긴다.
  # 임시 디렉토리 절대 경로를 넣지 않는 이유: macOS 의 TMPDIR 조각은 고엔트로피라 본문과 corpus(커밋
  # 메시지)에 함께 들어가면 secret-scan 이 정당하게 막는다.
  local evil="$T/evil.md"
  # shellcheck disable=SC2016
  printf '$(touch pwned1) `touch pwned2`\n' > "$evil"
  # shellcheck disable=SC2016
  g commit -q --allow-empty -m '$(touch pwned3) "; touch pwned4; "'
  : > "$REPO/\$(touch pwned5).txt"
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$evil"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-1" "P7: 주입 모양 입력에서도 정상 게시"
  local f hit=""
  for f in pwned1 pwned2 pwned3 pwned4 pwned5; do [ -e "$REPO/$f" ] && hit="$hit $f"; done
  assert_eq "$hit" "" "P4 · P7: 본문 · 커밋 메시지 · 파일 이름의 명령이 실행되지 않았다"
  if cmp -s "$evil" "$GH_BODY_COPY"; then ok "P4: 주입 모양 본문도 바이트 그대로"; else no "P4: 본문이 바뀌었다"; fi
  rm -f "$REPO/\$(touch pwned5).txt"
  g reset -q --hard HEAD~1
}

# ── I1 — 지운 줄 · 지운 파일 · 되돌린 값도 corpus 에 든다 ───────────────────────
case_I1_removed_content_in_corpus() {
  local tok="Zq4rT8vB2nM6xK1pL9wC3yH7dF5sG0jA" R2="$T/repo2" leak="$T/leak2.md"
  git init -q -b main "$R2"
  g2() { git -C "$R2" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@t "$@"; }
  printf 'line one\nkey=%s\nline three\n' "$tok" > "$R2/tok.txt"
  printf 'other=%s\n' "$tok" > "$R2/gone.txt"
  printf 'plain\n' > "$R2/keep.txt"
  g2 add tok.txt gone.txt keep.txt; g2 commit -q -m base
  g2 checkout -q -b feat
  printf 'value %s\n' "$tok" > "$leak"
  # 1) 브랜치가 그 줄을 지운 커밋
  printf 'line one\nline three\n' > "$R2/tok.txt"; g2 add tok.txt; g2 commit -q -m 'drop key'
  SINK_CWD="$R2" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "I1: 브랜치가 지운 줄의 값이 corpus 에 든다"
  # 2) 브랜치가 그 값을 담은 파일을 지운 커밋 (1 은 되돌려 둔다)
  g2 reset -q --hard HEAD~1
  g2 rm -q gone.txt; g2 commit -q -m 'drop file'
  SINK_CWD="$R2" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "I1: 지운 파일의 값이 corpus 에 든다"
  g2 reset -q --hard HEAD~1
  # 3) 범위 안에서 더했다 되돌린 값 — 순 diff 에는 없고 커밋 패치에만 있다
  printf 'added %s\n' "$tok" > "$R2/keep.txt"; g2 add keep.txt; g2 commit -q -m 'add'
  printf 'plain\n' > "$R2/keep.txt"; g2 add keep.txt; g2 commit -q -m 'revert'
  SINK_CWD="$R2" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "I1: 더했다 되돌린 값이 corpus 에 든다(커밋 패치)"
  g2 reset -q --hard HEAD~2
  # 4) 커밋 안 된 삭제 — 작업트리 diff 에만 있다
  printf 'line one\nline three\n' > "$R2/tok.txt"
  SINK_CWD="$R2" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "I1: 커밋 안 된 삭제의 값이 corpus 에 든다(작업트리 diff)"
  g2 checkout -q -- tok.txt
  # 대조군: 변경이 없으면 그 값은 corpus 밖이다
  SINK_CWD="$R2" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-1" "I1 대조군: 변경 없으면 base 의 값은 corpus 밖(통과)"
  # 정상 본문(판정 줄의 짧은 sha 포함)은 이 corpus 에서도 거짓 양성이 없다
  SINK_CWD="$R2" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$BODY"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-1" "I1: 정상 본문은 여전히 게시"
}

# ── I2 — 생산자 하나가 실패하면 부분 corpus 로 통과시키지 않는다 ────────────────
case_I2_producer_failure_fails_closed() {
  local real tok="Wm3nB7vC1xZ5qL9kR2tY6uH4jG8dS0pE" leak="$T/leak3.md" sub
  real="$(command -v git)"
  for sub in log diff; do
    mkdir -p "$T/shim-$sub"
    printf '#!/usr/bin/env bash\n[ "${1:-}" = "%s" ] && exit 1\nexec "%s" "$@"\n' "$sub" "$real" > "$T/shim-$sub/git"
    chmod +x "$T/shim-$sub/git"
  done
  printf 'value %s\n' "$tok" > "$leak"
  # log 생산자 — 값은 커밋 메시지에만 있다
  g commit -q --allow-empty -m "ci: rotate $tok"
  GH_PR="$OPEN_PR" run_sink "$T/shim-log:$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "I2: git log 실패 → degraded → fail-closed"
  g reset -q --hard HEAD~1
  # diff 생산자 — 값은 커밋 안 된 a.txt 변경에만 있다
  printf 'secret=%s\n' "$tok" > "$REPO/a.txt"
  GH_PR="$OPEN_PR" run_sink "$T/shim-diff:$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "I2: git diff 실패 → degraded → fail-closed"
  g checkout -q -- a.txt
}

# ── N1 — 옵션처럼 생긴 파일 이름도 데이터다 ─────────────────────────────────────
case_N1_option_shaped_file_names() {
  local tok="Ps5mK9bX3vC7zL1wQ4rT8yH2dF6sJ0gN" leak="$T/leak5.md" f
  printf 'value %s\n' "$tok" > "$leak"
  for f in -secret.env --number.env -n -; do
    printf 'secret=%s\n' "$tok" > "$REPO/$f"
    GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
    assert_eq "$LAST" "skipped: scan-failed" "N1: 옵션 모양 파일 이름($f)의 untracked 값이 corpus 에 든다"
    rm -f "$REPO/$f"
  done
}

# ── N2 — -diff 속성이 지운 줄을 가리지 못한다 ────────────────────────────────────
case_N2_binary_attribute_hides_nothing() {
  local tok="Ts8nB4vC2xZ6qL0kR9mY3uH7jG1dS5pE" R3="$T/repo3" leak="$T/leak6.md"
  git init -q -b main "$R3"
  g3() { git -C "$R3" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@t "$@"; }
  printf '*.lock -diff\n' > "$R3/.gitattributes"
  printf 'keep\nkey=%s\n' "$tok" > "$R3/x.lock"
  g3 add .gitattributes x.lock; g3 commit -q -m base
  g3 checkout -q -b feat
  printf 'keep\n' > "$R3/x.lock"; g3 add x.lock; g3 commit -q -m 'drop key'
  printf 'value %s\n' "$tok" > "$leak"
  SINK_CWD="$R3" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "N2: -diff 속성 파일에서 지운 값도 corpus 에 든다"
  # 더했다 되돌린 값 — 커밋 패치만 나른다
  g3 reset -q --hard HEAD~1
  printf 'added %s\n' "$tok" > "$R3/y.lock"; g3 add y.lock; g3 commit -q -m add
  g3 rm -q -f y.lock; g3 commit -q -m revert
  SINK_CWD="$R3" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "N2: -diff 속성 파일에 더했다 되돌린 값(커밋 패치)"
  g3 reset -q --hard HEAD~2
  # 커밋 안 된 삭제 — 작업트리 diff 만 나른다
  printf 'keep\n' > "$R3/x.lock"
  SINK_CWD="$R3" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "N2: -diff 속성 파일의 커밋 안 된 삭제(작업트리 diff)"
}

# ── textconv 가 평문을 내는 파일(git-crypt 꼴)에서 지운 값도 corpus 에 든다 ──────────
case_T1_textconv_plaintext_in_corpus() {
  local tok="Qc7nB3vC9xZ5qL1kR2mY6uH4jG8dS0pW" R4="$T/repo4" leak="$T/leak8.md"
  git init -q -b main "$R4"
  g4() { git -C "$R4" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@t "$@"; }
  git -C "$R4" config filter.rot.clean "tr A-Za-z N-ZA-Mn-za-m"
  git -C "$R4" config filter.rot.smudge "tr A-Za-z N-ZA-Mn-za-m"
  git -C "$R4" config diff.rot.textconv cat
  printf '*.sec filter=rot diff=rot\n' > "$R4/.gitattributes"
  printf 'keep\nkey=%s\n' "$tok" > "$R4/x.sec"
  g4 add .gitattributes x.sec; g4 commit -q -m base
  g4 checkout -q -b feat
  printf 'value %s\n' "$tok" > "$leak"
  printf 'keep\n' > "$R4/x.sec"; g4 add x.sec; g4 commit -q -m 'drop key'
  SINK_CWD="$R4" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "T1: filter+textconv 파일에서 지운 값(평문)이 corpus 에 든다"
  g4 reset -q --hard HEAD~1
  printf 'added %s\n' "$tok" > "$R4/y.sec"; g4 add y.sec; g4 commit -q -m add
  g4 rm -q -f y.sec; g4 commit -q -m revert
  SINK_CWD="$R4" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "T1: filter+textconv 파일에 더했다 되돌린 값(커밋 패치)"
  g4 reset -q --hard HEAD~2
  printf 'keep\n' > "$R4/x.sec"
  SINK_CWD="$R4" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "T1: filter+textconv 파일의 커밋 안 된 삭제(작업트리 diff)"
}

# ── 읽을 수 없는 변경 파일은 fail-closed ─────────────────────────────────────────
case_unreadable_changed_file_fails_closed() {
  local tok="Vk2nB6vC8xZ4qL0wR9mY3uH7jG1dS5pT" leak="$T/leak7.md"
  if [ "$(id -u)" = "0" ]; then note "root 로 돌아 chmod 000 이 막지 못한다 — 건너뜀"; return 0; fi
  printf 'value %s\n' "$tok" > "$leak"
  printf 'secret=%s\n' "$tok" > "$REPO/locked.env"; chmod 000 "$REPO/locked.env"
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "읽을 수 없는 untracked 파일 → corpus 를 못 만든 것으로 fail-closed"
  chmod 600 "$REPO/locked.env"; rm -f "$REPO/locked.env"
}

# ── 하위 디렉토리에서 불려도 리포 루트 기준이다 ──────────────────────────────────
case_subdir_runs_from_repo_root() {
  local tok="Hn6bV2mX8cQ4zL0wP7rT3yK9dF1sJ5gA" leak="$T/leak4.md"
  mkdir -p "$REPO/sub"
  printf 'value %s\n' "$tok" > "$leak"
  printf 'secret=%s\n' "$tok" > "$REPO/rootsecret.env"
  SINK_CWD="$REPO/sub" GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "하위 디렉토리 실행: 루트의 untracked 비밀값이 corpus 에 든다"
  rm -f "$REPO/rootsecret.env"; rmdir "$REPO/sub"
}

# ── 잘못된 호출은 exit 2, 결과 줄 없음, gh 호출 0 ─────────────────────────────
case_usage_errors() {
  run_sink "$WITH_GH"
  assert_eq "$RC" "2" "usage: 인자 없음 → rc 2"
  assert_eq "$OUT" "" "usage: 결과 줄을 내지 않는다"
  run_sink "$WITH_GH" --body-file "$BODY" --bogus
  assert_eq "$RC" "2" "usage: 모르는 인자 → rc 2"
  run_sink "$WITH_GH" --body-file "$T/none.md"
  assert_eq "$RC" "2" "usage: 본문 파일 없음 → rc 2"
  assert_eq "$GHCALLS" "" "usage: gh 호출 0"
  : > "$T/empty.md"
  run_sink "$WITH_GH" --body-file "$T/empty.md"
  assert_eq "$RC" "2" "usage: 빈 본문 파일 → rc 2"
  assert_eq "$OUT" "" "usage: 빈 본문 파일은 결과 줄을 내지 않는다"
  assert_eq "$GHCALLS" "" "usage: 빈 본문 파일은 gh 호출 0"
}

for c in case_AC12_posts_one_new_comment case_AC13_no_pr case_AC13_pr_closed \
         case_AC13_kill_switch_AC14_zero_network case_AC13_scan_failed case_AC13_gh_unavailable \
         case_AC13_too_long case_P1_literal_scan_gate case_P2_degraded_and_corpus_content \
         case_P5_auth_before_side_effects case_P4_P7_untrusted_bytes case_I1_removed_content_in_corpus \
         case_I2_producer_failure_fails_closed case_subdir_runs_from_repo_root \
         case_N1_option_shaped_file_names case_N2_binary_attribute_hides_nothing \
         case_T1_textconv_plaintext_in_corpus case_unreadable_changed_file_fails_closed case_usage_errors; do
  note "-- $c"
  "$c"
done
finish
