#!/usr/bin/env bash
# test_publish_pipeline_wiring.sh — 파이프라인 SKILL.md 의 `## Publish` 절(K-8)과 그 게시 펜스의 행동(AC13 aborted · K-2 `## 게시` · K-3 판정 줄 전사 금지).
#
# 게시 펜스는 `<!-- publish-fence:begin -->` · `<!-- publish-fence:end -->` 사이의 bash 펜스다. 그 펜스를 그대로
# 잘라, 플러그인 루트 토큰 · `OUTCOME=` 줄 · `<session-id>` 자리표시를 sed 로 채우고 bash 와 zsh(있으면) 양쪽에서 돌린다 —
# Bash 도구의 셸은 zsh 다. 펜스는 리포 루트에 묶인다(K-1) — 그래서 가짜 프로젝트는 git 리포이고 펜스는 그 하위 디렉토리에서 돈다.
# 가짜 루트의 sink 는 호출 인자를 기록하고 정해진 마지막 줄을 내는 스텁이다.
# (qg v10 ③ plan 이 쓴 테스트 코드다 — 리뷰는 이 파일도 검사 대상으로 본다.)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"

T="$(mktemp -d "${TMPDIR:-/tmp}/qg-pubwire.XXXXXX")" || { echo "mktemp 실패"; exit 1; }
trap 'rm -rf "$T"' EXIT

# ── 구조(K-8) — `## Publish` 는 하나이고 바로 앞 `##` 절이 `## Final verdict` 다 ─────────────
# 펜스 안의 줄은 제목으로 세지 않는다(heredoc 본문이 `## ` 로 시작할 수 있다).
HEADS="$(awk '/^```/{inf=!inf; next} !inf && /^## /{print}' "$SKILL")"
assert_eq "$(printf '%s\n' "$HEADS" | grep -cx '## Publish')" "1" "K-8: ## Publish 가 정확히 하나"
assert_eq "$(printf '%s\n' "$HEADS" | grep -B1 -x '## Publish' | head -n 1)" "## Final verdict" "K-8: ## Publish 바로 앞 절이 ## Final verdict"

SEC="$(awk '/^```/{inf=!inf} !inf && /^## /{f=($0=="## Publish")} f' "$SKILL")"
assert_eq "$(printf '%s\n' "$SEC" | grep -cx '<!-- publish-fence:begin -->')" "1" "게시 펜스 시작 표지가 ## Publish 안에 하나"
assert_eq "$(grep -cx '<!-- publish-fence:begin -->' "$SKILL")" "1" "게시 펜스 시작 표지가 파일 전체에 하나"
FENCE="$(awk '/^<!-- publish-fence:begin -->$/{f=1;next} /^<!-- publish-fence:end -->$/{f=0} f' "$SKILL" | sed -e '1{/^```bash$/d;}' -e '${/^```$/d;}')"
[ -n "$FENCE" ] && ok "게시 펜스 본문을 잘라냈다($(printf '%s\n' "$FENCE" | wc -l | tr -d ' ')줄)" || no "게시 펜스 본문이 비었다 — 표지가 죽었다"
printf '%s\n' "$FENCE" | grep -q 'scripts/publish-comment.sh' \
  && ok "게시 펜스가 sink 를 부른다(양성 증인)" || no "게시 펜스에 sink 호출이 없다"
printf '%s\n' "$FENCE" | grep -qE '(^|[^A-Za-z0-9_-])gh[[:space:]]' \
  && no "게시 펜스가 gh 를 직접 부른다(AC15)" || ok "게시 펜스는 gh 를 직접 부르지 않는다(AC15)"

# ── 행동 ────────────────────────────────────────────────────────────────────
FAKE="$T/plug"; mkdir -p "$FAKE/scripts"
cat > "$FAKE/scripts/publish-comment.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SINK_LOG"
pwd -P > "$T_SINK_CWD"
[ "$1" = "--body-file" ] && cat "$2" > "$SINK_BODY_COPY"
printf 'progress\n%s\n' "$SINK_LAST"
EOF
chmod +x "$FAKE/scripts/publish-comment.sh"
SID="testsession-0001"
export SINK_LOG="$T/sink.log" SINK_BODY_COPY="$T/sent.md" T_SINK_CWD="$T/sink.cwd"
unset CLAUDE_CODE_SESSION_ID   # 펜스는 환경 변수를 읽지 않는다 — 있으면 그 사실을 가린다

# run_fence <shell> <outcome> [<session-id 채울 값>] — cwd 는 가짜 프로젝트의 하위 디렉토리. 결과는 RC · OUT · LAST.
run_fence() {
  local sh="$1" outcome="$2" sid="${3-$SID}" f="$T/fence.sh"
  printf '%s\n' "$FENCE" \
    | sed -e "s|\${CLAUDE_PLUGIN_ROOT}|$FAKE|" \
          -e "s|^OUTCOME=\".*\"\$|OUTCOME=\"$outcome\"|" \
          -e "s|<session-id>|$sid|g" > "$f"
  : > "$SINK_LOG"; rm -f "$SINK_BODY_COPY"
  OUT="$(cd "$T/proj/sub" && "$sh" "$f" 2>"$T/fence.err")"; RC=$?
  LAST="$(printf '%s\n' "$OUT" | tail -n 1)"
}
fresh_proj() {  # git 리포 · 하위 디렉토리 · result.md · 이해글을 새로 깐다
  rm -rf "$T/proj"; mkdir -p "$T/proj/.claude/quality-gates/$SID" "$T/proj/sub"
  git init -q "$T/proj"
  TOP="$(git -C "$T/proj" rev-parse --show-toplevel)"   # macOS 의 /var → /private/var 를 git 이 푼 그대로
  R="$T/proj/.claude/quality-gates/$SID/result.md"
  cat > "$R" <<'EOF'
---
session_id: "testsession-0001"
---

# qg result

## 판정

verdict: defect
qg: defect · 막는 지적 2 · 선택 0 · 차등 새 실패 0 · 제외 패치 0 · iter 1 · aaaaaaa
verdict: clean
qg: clean · 막는 지적 0 · 선택 1 · 차등 새 실패 0 · 제외 패치 1 · iter 2 · bbbbbbb

## 지적

qg: decoy-이 줄은 판정 절 밖이다
EOF
  printf '## 한 줄 요약\n무엇이 바뀌나.\n' > "$T/proj/.claude/quality-gates/$SID/comment-head.md"
}

SHELLS="bash"
command -v zsh >/dev/null 2>&1 && SHELLS="bash zsh"
for sh in $SHELLS; do
  note "-- shell: $sh"
  fresh_proj
  SINK_LAST="posted: https://github.com/o/r/pull/7#issuecomment-9" run_fence "$sh" "aborted iter 2"
  assert_eq "$LAST" "skipped: aborted" "AC13($sh): aborted 는 skipped: aborted 한 줄"
  assert_eq "$(cat "$SINK_LOG")" "" "AC13($sh): aborted 면 sink 를 부르지 않는다"
  assert_eq "$(tail -n 1 "$R")" "skipped: aborted" "K-2($sh): aborted 줄이 result.md ## 게시 에 남는다"

  fresh_proj
  SINK_LAST="posted: https://github.com/o/r/pull/7#issuecomment-9" run_fence "$sh" "finished"
  assert_eq "$RC" "0" "정상($sh): rc 0"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-9" "정상($sh): sink 의 마지막 줄을 그대로 낸다"
  assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' ')" "1" "정상($sh): sink 를 정확히 한 번 부른다"
  assert_eq "$(cat "$SINK_LOG")" "--body-file $TOP/.claude/quality-gates/$SID/comment.md" "정상($sh): sink 인자는 --body-file <리포 루트>/.claude/quality-gates/<sid>/comment.md 하나(하위 디렉토리에서 돌아도)"
  assert_eq "$(cat "$T/sink.cwd")" "$TOP" "정상($sh): sink 는 리포 루트에서 돈다"
  assert_eq "$(tail -n 1 "$SINK_BODY_COPY")" "qg: clean · 막는 지적 0 · 선택 1 · 차등 새 실패 0 · 제외 패치 1 · iter 2 · bbbbbbb" \
    "K-3($sh): 코멘트 마지막 줄은 result.md ## 판정 의 마지막 판정 줄 원문(절 밖 decoy 아님)"
  assert_eq "$(tail -n 2 "$SINK_BODY_COPY" | head -n 1)" "---" "spec §5($sh): 판정 줄 앞에 구분선"
  assert_eq "$(tail -n 3 "$SINK_BODY_COPY" | head -n 1)" "" "M4($sh): 구분선 앞은 빈 줄"
  assert_eq "$(head -n 1 "$SINK_BODY_COPY")" "## 한 줄 요약" "spec §5($sh): 코멘트는 이해글로 시작한다"
  assert_eq "$(tail -n 1 "$R")" "posted: https://github.com/o/r/pull/7#issuecomment-9" "K-2($sh): sink 결과가 result.md ## 게시 에 남는다"
  assert_eq "$(grep -cx '## 게시' "$R")" "1" "K-2($sh): ## 게시 절이 하나"

  fresh_proj
  SINK_LAST="skipped: no-pr" run_fence "$sh" "accepted with findings iter 3"
  assert_eq "$LAST" "skipped: no-pr" "정상($sh): skipped 줄도 그대로 낸다"

  fresh_proj
  SINK_LAST="something else" run_fence "$sh" "finished"
  assert_eq "$LAST" "게시 결과 불명 — sink 출력 계약 위반(rc 0)" "P6($sh): sink 마지막 줄이 리터럴이 아니면 성공으로 읽지 않는다"

  fresh_proj
  printf -- '---\n---\n\n# qg result\n\n## 판정\n\nverdict: clean\n' > "$R"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$(cat "$SINK_LOG")" "" "K-3($sh): 판정 줄이 없으면 sink 를 부르지 않는다"
  assert_eq "$LAST" "게시 안 함 — result.md 의 판정 줄이나 이해글이 없다" "K-3($sh): 판정 줄 없음이 보인다"

  fresh_proj
  rm -f "$T/proj/.claude/quality-gates/$SID/comment-head.md"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$(cat "$SINK_LOG")" "" "I1($sh): 이해글이 없으면 sink 를 부르지 않는다"
  assert_eq "$LAST" "게시 안 함 — result.md 의 판정 줄이나 이해글이 없다" "I1($sh): 이해글 없음이 보인다"

  fresh_proj
  SINK_LAST="posted: x" run_fence "$sh" "<Final verdict 표의 Outcome 값 그대로>"
  assert_eq "$(cat "$SINK_LOG")" "" "M5($sh): OUTCOME 자리표시면 sink 를 부르지 않는다"
  assert_eq "$LAST" "게시 안 함 — OUTCOME 이 형식 밖이다" "M5($sh): OUTCOME 형식 밖이 보인다"
  assert_eq "$RC" "0" "M5($sh): rc 0"
  assert_eq "$(tail -n 1 "$R")" "게시 안 함 — OUTCOME 이 형식 밖이다" "M5($sh): ## 게시 에 남는다"

  for bad in "<session-id>" "" "../../../x" "short"; do
    fresh_proj
    SINK_LAST="posted: x" run_fence "$sh" "finished" "$bad"
    [ "$RC" -ne 0 ] && ok "E1($sh): 세션 id '${bad}' 면 비0" || no "E1($sh): 세션 id '${bad}' 로 진행했다"
    assert_eq "$(cat "$SINK_LOG")" "" "E1($sh): 세션 id '${bad}' 면 sink 를 부르지 않는다"
  done
done
finish
