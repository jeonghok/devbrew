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
  OUT="$(cd "$REPO" && PATH="$p" bash "$SINK" "$@" 2>"$T/err")"; RC=$?
  LAST="$(printf '%s\n' "$OUT" | tail -n 1)"
  GHCALLS="$(cat "$GH_LOG")"
}
WITH_GH="$T/bin:$PATH"

# P6 — 결과 줄은 stdout 마지막 줄 하나뿐이다.
p6_single_result_line() {   # <case 이름>
  local n
  n="$(printf '%s\n' "$OUT" | grep -cE '^(posted|skipped): ')"
  assert_eq "$n" "1" "P6 $1: 결과 줄이 정확히 하나"
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
  printf 'secret=%s\n' "$tok" > "$REPO/b.txt"
  GH_PR="$OPEN_PR" run_sink "$WITH_GH" --body-file "$leak"
  assert_eq "$LAST" "skipped: scan-failed" "P2: 커밋 안 된 추적 파일 변경이 corpus 에 들어간다"
  g checkout -q -- b.txt
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
}

for c in case_AC12_posts_one_new_comment case_AC13_no_pr case_AC13_pr_closed \
         case_AC13_kill_switch_AC14_zero_network case_AC13_scan_failed case_AC13_gh_unavailable \
         case_AC13_too_long case_P1_literal_scan_gate case_P2_degraded_and_corpus_content \
         case_P5_auth_before_side_effects case_P4_P7_untrusted_bytes case_usage_errors; do
  note "-- $c"
  "$c"
done
finish
