#!/usr/bin/env bash
# test_publish_pipeline_wiring.sh — 파이프라인 SKILL.md 의 `## Publish` 절(K-8)과 그 게시 펜스의 행동(defect 판정도 게시 · K-2 `## 게시` · K-3 판정 줄 전사 금지).
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
assert_eq "$(printf '%s\n' "$SEC" | grep -cxF '판정이 무엇이든(막는 지적이나 차등 결함으로 끝난 `defect` 도) 그 판정을 그대로 게시한다.')" "1" \
  "Review Focus 4: ## Publish 본문이 defect 판정도 그대로 게시한다고 줄 전체로 한 번 말한다"
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
printf 'progress\n'
[ -n "${SINK_PRE:-}" ] && printf '%s\n' "$SINK_PRE"
printf '%s\n' "$SINK_LAST"
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
gp() { git -C "$T/proj" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@t "$@"; }
fresh_proj() {  # 커밋 하나가 있는 깨끗한 git 리포 · 하위 디렉토리 · result.md · 이해글을 새로 깐다
  rm -rf "$T/proj"; mkdir -p "$T/proj/.claude/quality-gates/$SID" "$T/proj/sub"
  git init -q "$T/proj"
  echo app > "$T/proj/app.txt"; echo '{}' > "$T/proj/.claude/settings.json"
  echo keep > "$T/proj/.claude/quality-gates/tracked.md"
  gp add app.txt .claude/settings.json .claude/quality-gates/tracked.md; gp commit -q -m base
  TOP="$(git -C "$T/proj" rev-parse --show-toplevel)"   # macOS 의 /var → /private/var 를 git 이 푼 그대로
  R="$T/proj/.claude/quality-gates/$SID/result.md"
  cat > "$R" <<'EOF'
---
session_id: "testsession-0001"
---

# qg result

## 판정

verdict: defect
qg: defect · 막는 지적 2 · 선택 0 · 차등 새 실패 0 · aaaaaaa
verdict: clean
qg: clean · 막는 지적 0 · 선택 1 · 차등 새 실패 0 · e2e pass · bbbbbbb

## 지적

qg: decoy-이 줄은 판정 절 밖이다
EOF
  printf '## 한 줄 요약\n무엇이 바뀌나.\n' > "$T/proj/.claude/quality-gates/$SID/comment-head.md"
}
DIRTY="게시 안 함 — 커밋 안 된 변경이 있다(판정이 PR 의 커밋과 다르다 — 커밋·푸시 뒤 다시 /quality-gates:quality-pipeline)"
STATUS_FAIL="게시 안 함 — 작업 트리 상태를 읽지 못했다(git status 실패)"
HEAD_VLINE="게시 안 함 — 이해글에 판정 줄 모양이 있다"
NOTICE_CHECK="> [quality-gates] 이미 단 댓글을 확인하지 못했다(댓글 목록을 읽지 못했다) — 게시한다(같은 판정이 두 번 달릴 수 있다)."
NOTICE_AT="> [quality-gates] 게시 절 자리 기록이 결과 파일과 맞지 않는다 — 게시 단계는 그대로 했고(위 줄), 결과 파일의 게시 절은 고쳐 쓰지 않았다."
RANGE_LINE="게시 안 함 — 범위 모드라 PR 코멘트를 달지 않는다(범위에는 열린 PR 이 없다)"
# git status 만 실패시키는 shim — 나머지 git 호출은 진짜 git 으로 넘긴다.
mkdir -p "$T/gshim"
printf '#!/usr/bin/env bash\n[ "${1:-}" = "status" ] && { echo "fatal: shim" >&2; exit 128; }\nexec "%s" "$@"\n' "$(type -P git)" > "$T/gshim/git"
chmod +x "$T/gshim/git"

# case_defect_run_publishes <shell> — 막는 지적 · 차등 결함으로 끝난 실행도 묻지 않고 그 판정을 그대로 게시한다
# (Review Focus 4). OUTCOME 은 finished 하나이고, 열린 PR 의 가짜 sink 가 한 번 불려 defect 판정 줄을 싣는다.
case_defect_run_publishes() {
  local sh="$1" dline="qg: defect · 막는 지적 1 · 선택 0 · 차등 새 실패 2 · e2e 안 함 · ddddddd"
  fresh_proj
  printf -- '---\n---\n\n# qg result\n\n## 판정\n\nverdict: defect\n%s\n\n## 고칠 목록\n\n### 막는 지적\n\n- IMPORTANT a.py:1 — x · 고칠 방법: y\n' "$dline" > "$R"
  SINK_LAST="posted: https://github.com/o/r/pull/7#issuecomment-11" run_fence "$sh" "finished"
  assert_eq "$RC" "0" "defect 게시($sh): rc 0"
  assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' ')" "1" "defect 게시($sh): 막는 지적으로 끝난 실행도 sink 를 정확히 한 번 부른다"
  assert_eq "$(tail -n 1 "$SINK_BODY_COPY" 2>/dev/null)" "$dline" "defect 게시($sh): 코멘트 마지막 줄이 defect 판정 줄 원문이다"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-11" "defect 게시($sh): sink 의 posted 줄을 그대로 낸다"
  # 옛 결과 토큰(aborted)은 받지 않는다 — 게시를 피하던 길이 없다(위 양성 짝)
  fresh_proj
  SINK_LAST="posted: x" run_fence "$sh" "aborted iter 2"
  assert_eq "$LAST" "게시 안 함 — OUTCOME 이 형식 밖이다" "defect 게시($sh): 옛 aborted 결과는 형식 밖이다(skipped: aborted 갈래가 없다)"
  assert_eq "$(cat "$SINK_LOG")" "" "defect 게시($sh): 형식 밖 결과면 sink 를 부르지 않는다"
}

# ── R7 §2 · AC7 · AC36 — 결과 파일의 게시 줄로 건너뛰지 않는다 · 다시 돌리면 절을 바꿔 쓴다 ──────────────
# want_result <앞 파일> <절 줄> [<뒤 파일>] — 결과 파일이 「앞 + 게시 절 + 뒤」 와 바이트 그대로 같은가(rc).
want_result() {
  { cat "$1"; printf '\n## 게시\n\n%s\n' "$2"; [ -n "${3:-}" ] && cat "$3"; } > "$T/want.md"
  cmp -s "$T/want.md" "$R"
}
AT_FILE() { printf '%s' "$T/proj/.claude/quality-gates/$SID/publish-at.txt"; }
case_rerun_cases() {
  local sh="$1" size
  # planted_publish_line_still_posts — 앞 절(고칠 목록)에 심은 `## 게시` 줄이 있어도 sink 를 부르고 끝에 덧붙인다.
  fresh_proj
  printf '\n## 고칠 목록\n\n- IMPORTANT a.py:1 — x\n## 게시\n\nposted: planted\n' >> "$R"
  cp "$R" "$T/before.md"; size="$(wc -c < "$T/before.md" | tr -d ' ')"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' ')" "1" "planted_publish_line_still_posts($sh): 심은 줄이 있어도 sink 를 부른다"
  assert_eq "$LAST" "posted: x" "planted_publish_line_still_posts($sh): sink 의 줄"
  want_result "$T/before.md" "posted: x" && ok "planted_publish_line_still_posts($sh): 앞 절 바이트 그대로 · 끝에 게시 절" \
    || no "planted_publish_line_still_posts($sh): 결과 파일이 「앞 + 게시 절」 이 아니다"
  assert_eq "$(cat "$(AT_FILE)" 2>/dev/null)" "$size $(printf '\n## 게시\n\n%s\n' 'posted: x' | wc -c | tr -d ' ')" \
    "planted_publish_line_still_posts($sh): 게시 절 자리 파일은 「<시작 바이트> <길이 바이트>」 한 줄"
  # planted_publish_line_second_run — 두 번째 실행은 앞 절을 바꾸지 않고 끝의 게시 절만 바꾼다.
  SINK_LAST="skipped: already-posted" run_fence "$sh" "finished"
  assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' ')" "1" "planted_publish_line_second_run($sh): 두 번째도 sink 를 부른다"
  want_result "$T/before.md" "skipped: already-posted" && ok "planted_publish_line_second_run($sh): 심은 줄이 든 앞 절 그대로 · 게시 절만 바뀜" \
    || no "planted_publish_line_second_run($sh): 앞 절이 바뀌었거나 게시 절이 둘이다"
  assert_eq "$(grep -cx '## 게시' "$R")" "2" "planted_publish_line_second_run($sh): ## 게시 줄은 심은 줄 1 + 펜스 절 1"

  # third_run_after_rewrite_keeps_tail · intent_section_after_kept — 뒤에 붙은 `## intent-critic` 절이 그대로 남는다.
  fresh_proj
  cp "$R" "$T/before.md"
  SINK_LAST="posted: https://github.com/o/r/pull/7#issuecomment-1234567" run_fence "$sh" "finished"
  printf '\n## intent-critic\n\n의도 점검 줄 하나\n둘째 줄\n' > "$T/tail.md"
  cat "$T/tail.md" >> "$R"
  SINK_LAST="skipped: already-posted" run_fence "$sh" "finished"
  want_result "$T/before.md" "skipped: already-posted" "$T/tail.md" \
    && ok "intent_section_after_kept($sh): 게시 절은 제자리에서 바뀌고 ## intent-critic 절은 끝에 그대로" \
    || no "intent_section_after_kept($sh): 결과 파일이 「앞 + 게시 절 + intent-critic」 이 아니다"
  SINK_LAST="posted: z" run_fence "$sh" "finished"
  want_result "$T/before.md" "posted: z" "$T/tail.md" \
    && ok "third_run_after_rewrite_keeps_tail($sh): 줄 길이가 바뀐 뒤 세 번째 실행도 뒤 절을 자르지 않는다" \
    || no "third_run_after_rewrite_keeps_tail($sh): 세 번째 실행 뒤 결과 파일이 다르다 — $(tail -n 6 "$R" | tr '\n' '|')"
  assert_eq "$(grep -cx '## 게시' "$R")" "1" "third_run_after_rewrite_keeps_tail($sh): ## 게시 절은 하나"

  # position_mismatch_alerts — 자리 기록이 결과 파일과 맞지 않으면 절을 늘리지도 고치지도 않고 알림 · sink 는 부른다.
  local kind bad
  local at0 len0 hl0
  hl0="$(printf '\n## 게시\n' | wc -c | tr -d ' ')"
  for kind in outside not-head overrun garbage empty short-head head-only short-mid long-tail glued-tail; do
    fresh_proj
    SINK_LAST="posted: x" run_fence "$sh" "finished"
    # long-tail — 뒤에 `## intent-critic` 절이 붙은 결과 파일(길이를 늘려도 파일 안에 든다)
    [ "$kind" = long-tail ] && printf '\n## intent-critic\n\n의도 점검 줄 하나\n' >> "$R"
    # glued-tail — 빈 줄 없이 붙은 다음 절(절 끝 바로 뒤가 `## `)
    [ "$kind" = glued-tail ] && printf '## intent-critic\n\n의도 점검 줄 하나\n' >> "$R"
    size="$(wc -c < "$R" | tr -d ' ')"
    at0="$(sed 's/ .*//' "$(AT_FILE)")"; len0="$(sed 's/.* //' "$(AT_FILE)")"
    case "$kind" in
      outside)  bad="$((size + 5)) 10" ;;               # 시작이 파일 밖
      not-head) bad="0 10" ;;                            # 파일 안이지만 게시 절 머리가 아니다
      overrun)  bad="$at0 $((size * 2))" ;;              # 머리는 맞고 길이가 파일 밖
      garbage)  bad="x y" ;;
      empty)    bad="" ;;
      # 머리는 맞고 길이가 틀렸지만 파일 안 — 바꿔 쓰면 옛 줄이 절 밖에 남거나 뒤 절을 깎는다.
      short-head) bad="$at0 $((hl0 + 1))" ;;             # 끝 바이트는 줄바꿈 · 그 뒤가 파일 끝도 다음 절 머리도 아니다
      head-only)  bad="$at0 $hl0" ;;                     # 끝 바이트는 줄바꿈 · 그 뒤가 줄바꿈으로 시작하지만 「\n## 」 가 아니다
      short-mid)  bad="$at0 $((len0 - 1))" ;;            # 끝 바이트가 줄바꿈이 아니다
      long-tail)  bad="$at0 $((len0 + 1))" ;;            # 끝 바이트는 줄바꿈(다음 절 앞 빈 줄) · 그 뒤가 「\n## 」 가 아니다
      glued-tail) bad="$at0 $((len0 - 1))" ;;            # 그 뒤는 「\n## 」 지만 끝 바이트가 줄바꿈이 아니다
    esac
    printf '%s\n' "$bad" > "$(AT_FILE)"
    cp "$R" "$T/mm.md"
    SINK_LAST="posted: y" run_fence "$sh" "finished"
    assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' ')" "1" "position_mismatch_alerts($sh · 「${bad}」): sink 는 부른다"
    assert_eq "$OUT" "posted: y
$NOTICE_AT" "position_mismatch_alerts($sh · 「${bad}」): 결과 줄 다음에 알림 한 줄"
    cmp -s "$T/mm.md" "$R" && ok "position_mismatch_alerts($sh · 「${bad}」): 결과 파일이 그대로(앞 실행의 줄)" \
      || no "position_mismatch_alerts($sh · 「${bad}」): 결과 파일이 바뀌었다"
  done
  # 범위 · 게시 안 함 갈래도 같은 자리에서 쓴다 — 맞지 않는 자리 기록이면 같은 알림.
  fresh_proj
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  printf '0 10\n' > "$(AT_FILE)"; echo dirty >> "$T/proj/app.txt"; cp "$R" "$T/mm.md"
  SINK_LAST="posted: y" run_fence "$sh" "finished"
  assert_eq "$OUT" "$DIRTY
$NOTICE_AT" "position_mismatch_alerts($sh · 게시 안 함 갈래): 줄 다음에 알림"
  cmp -s "$T/mm.md" "$R" && ok "position_mismatch_alerts($sh · 게시 안 함 갈래): 결과 파일 그대로" || no "position_mismatch_alerts($sh · 게시 안 함 갈래): 결과 파일이 바뀌었다"

  # rerun_after_skipped_or_failed_retries — 첫 실행이 건너뛰었거나 실패했으면 두 번째가 다시 게시를 시도한다.
  local first
  for first in "failed: gh-unavailable" "skipped: no-pr"; do
    fresh_proj
    SINK_LAST="$first" run_fence "$sh" "finished"
    SINK_LAST="posted: y" run_fence "$sh" "finished"
    assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' '):$LAST" "1:posted: y" "rerun_after_skipped_or_failed_retries($sh · ${first}): 두 번째도 sink 를 부른다"
    assert_eq "$(grep -cx '## 게시' "$R"):$(tail -n 1 "$R")" "1:posted: y" "rerun_after_skipped_or_failed_retries($sh · ${first}): 절 하나 · 두 번째 줄"
  done

  # no_publish_rerun_same_line · no_publish_then_condition_changed
  fresh_proj
  echo dirty >> "$T/proj/app.txt"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$LAST:$(cat "$SINK_LOG")" "$DIRTY:" "no_publish_rerun_same_line($sh): 두 번째도 같은 「게시 안 함」 줄 · sink 0"
  assert_eq "$(grep -cx '## 게시' "$R"):$(tail -n 1 "$R")" "1:$DIRTY" "no_publish_rerun_same_line($sh): 절 하나"
  gp add app.txt; gp commit -q -m fix
  SINK_LAST="posted: y" run_fence "$sh" "finished"
  assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' '):$LAST" "1:posted: y" "no_publish_then_condition_changed($sh): 그 사이 커밋하면 두 번째는 sink 를 부른다"
  assert_eq "$(grep -cx '## 게시' "$R"):$(tail -n 1 "$R")" "1:posted: y" "no_publish_then_condition_changed($sh): 절 하나 · 새 줄"

  # notice_line_shown — sink 가 낸 확인 못함 줄을 결과 줄 앞에 보인다(sink 의 다른 줄은 보이지 않는다).
  fresh_proj
  SINK_PRE="$NOTICE_CHECK" SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$OUT" "$NOTICE_CHECK
posted: x" "notice_line_shown($sh): 확인 못함 줄 · 결과 줄(그 밖의 sink 줄 없음)"
  assert_eq "$(tail -n 1 "$R")" "posted: x" "notice_line_shown($sh): 결과 파일의 절은 결과 줄 하나"
  # notice_mid_line_not_shown — 같은 글이 sink 출력 줄 가운데 있으면 확인 못함 줄이 아니다(줄 머리에서만 읽는다).
  fresh_proj
  SINK_PRE="progress: $NOTICE_CHECK" SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$OUT" "posted: x" "notice_mid_line_not_shown($sh): 줄 가운데의 같은 글은 보이지 않는다(결과 줄 하나)"
}

# ── refusal_sentence_absent · 생명주기 2 문장 ──────────────────────────────────────
PUB_BODY="$(awk '/^## Publish$/{f=1;next} f&&/^## kill switch$/{exit} f' "$SKILL")"
assert_not_contains "$(cat "$SKILL")" "이 실행은 이미 게시 단계를 돌았다" "refusal_sentence_absent: SKILL 에 거절 줄이 없다"
assert_not_contains "$PUB_BODY" "한 번만 돈다" "refusal_sentence_absent: 게시 절에 「한 번만 돈다」 가 없다"
assert_not_contains "$PUB_BODY" "다시 돌리면 펜스가 거절한다" "refusal_sentence_absent: 게시 절에 「다시 돌리면 펜스가 거절한다」 가 없다"
assert_contains "$PUB_BODY" "다시 돌리면 펜스가 그 절을" "refusal_sentence_absent 양의 짝: 게시 절이 다시 돌리면 절을 바꿔 쓴다고 말한다"
assert_contains "$PUB_BODY" "already-posted" "게시 절: skipped: 사유 목록에 already-posted"
assert_contains "$PUB_BODY" "> [quality-gates] 이미 단 댓글을 확인하지 못했다(" "게시 절: 확인 못함 줄을 보인다고 말한다"
SFMT="$PLUGIN_ROOT/skills/quality-pipeline/references/state-file-format.md"
LC2="$(awk '/^2\. \*\*덧붙인다\*\*/{f=1} f&&/^3\. /{exit} f' "$SFMT" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$LC2" '`## 게시` 는 하나뿐이다 — 다시 돌리면 펜스가 그 절을 그 실행의 결과로 바꿔 쓴다' "생명주기 2: 설계 문장 그대로(「바꿔 쓴다」)"
assert_not_contains "$LC2" "이미 게시 단계를 돌았다" "생명주기 2: 옛 거절 줄이 없다"
assert_contains "$LC2" "publish-at.txt" "생명주기 2: 게시 절 자리 파일을 밝힌다"

# ── P2 산문 — 매 실행이 지우고 시작하는 파일의 산문 목록이 P2 의 `rm -f` 목록과 같은 이름을 모두 밝힌다 ──
# (게시 절 자리 파일 publish-at.txt 가 `rm -f` 에만 있고 산문에 빠졌던 자리 — 목록에서 이름을 도출해 잰다.)
P2RM="$(grep -m 1 '^rm -f "\$RD/differential.yaml"' "$SKILL")"
P2PROSE="$(awk '/^Every run then starts without /{f=1} f&&/^`e2e-app.pgid` is kept\./{exit} f' "$SKILL" | tr '\n' ' ')"
P2NAMES="$(printf '%s\n' "$P2RM" | grep -o '"\$RD/[^"]*"' | sed -e 's|^"\$RD/||' -e 's|"$||')"
[ "$(printf '%s\n' "$P2NAMES" | grep -c .)" -ge 10 ] && ok "P2 산문: rm -f 목록에서 이름을 도출했다($(printf '%s\n' "$P2NAMES" | grep -c .)개)" \
  || no "P2 산문: rm -f 목록 도출이 비었다 — 앵커가 죽었다"
printf '%s\n' "$P2NAMES" | grep -qx 'publish-at.txt' && ok "P2 산문: rm -f 목록에 publish-at.txt 가 있다(양성 증인)" \
  || no "P2 산문: rm -f 목록에 publish-at.txt 가 없다"
while IFS= read -r n; do
  [ -n "$n" ] || continue
  assert_contains "$P2PROSE" "\`$n\`" "P2 산문: 매 실행이 지우고 시작하는 파일 목록에 \`$n\` 이 있다"
done <<P2N
$P2NAMES
P2N

SHELLS="bash"
command -v zsh >/dev/null 2>&1 && SHELLS="bash zsh"
for sh in $SHELLS; do
  note "-- shell: $sh"
  case_defect_run_publishes "$sh"

  fresh_proj
  SINK_LAST="posted: https://github.com/o/r/pull/7#issuecomment-9" run_fence "$sh" "finished"
  assert_eq "$RC" "0" "정상($sh): rc 0"
  assert_eq "$LAST" "posted: https://github.com/o/r/pull/7#issuecomment-9" "정상($sh): sink 의 마지막 줄을 그대로 낸다"
  assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' ')" "1" "정상($sh): sink 를 정확히 한 번 부른다"
  assert_eq "$(cat "$SINK_LOG")" "--body-file $TOP/.claude/quality-gates/$SID/comment.md" "정상($sh): sink 인자는 --body-file <리포 루트>/.claude/quality-gates/<sid>/comment.md 하나(하위 디렉토리에서 돌아도)"
  assert_eq "$(cat "$T/sink.cwd")" "$TOP" "정상($sh): sink 는 리포 루트에서 돈다"
  assert_eq "$(tail -n 1 "$SINK_BODY_COPY")" "qg: clean · 막는 지적 0 · 선택 1 · 차등 새 실패 0 · e2e pass · bbbbbbb" \
    "K-3($sh): 코멘트 마지막 줄은 result.md ## 판정 의 마지막 판정 줄 원문(절 밖 decoy 아님)"
  assert_eq "$(tail -n 2 "$SINK_BODY_COPY" | head -n 1)" "---" "spec §5($sh): 판정 줄 앞에 구분선"
  assert_eq "$(tail -n 3 "$SINK_BODY_COPY" | head -n 1)" "" "M4($sh): 구분선 앞은 빈 줄"
  assert_eq "$(head -n 1 "$SINK_BODY_COPY")" "## 한 줄 요약" "spec §5($sh): 코멘트는 이해글로 시작한다"
  assert_eq "$(tail -n 1 "$R")" "posted: https://github.com/o/r/pull/7#issuecomment-9" "K-2($sh): sink 결과가 result.md ## 게시 에 남는다"
  assert_eq "$(grep -cx '## 게시' "$R")" "1" "K-2($sh): ## 게시 절이 하나"

  # ── 범위 모드(AC21) — 세션 폴더에 range-scope.txt 가 있으면 sink 를 부르지 않고 범위 공시 줄 ──
  # 짝: 바로 위 정상 경우(범위 파일 없음)는 sink 를 정확히 한 번 부른다.
  fresh_proj
  printf 'mode: range\nstatus: ok\n' > "$T/proj/.claude/quality-gates/$SID/range-scope.txt"
  SINK_LAST="posted: https://github.com/o/r/pull/7#issuecomment-9" run_fence "$sh" "finished"
  assert_eq "$RC" "0" "범위($sh): rc 0"
  assert_eq "$LAST" "$RANGE_LINE" "범위($sh): 범위 공시 줄"
  assert_eq "$(cat "$SINK_LOG")" "" "범위($sh): 범위 파일이 있으면 sink 를 부르지 않는다"
  assert_eq "$(grep -cx '## 게시' "$R")" "1" "범위($sh): ## 게시 절이 하나"
  assert_eq "$(tail -n 1 "$R")" "$RANGE_LINE" "범위($sh): 범위 공시 줄이 ## 게시 에 남는다"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$LAST" "$RANGE_LINE" "range_rerun_same_line($sh): 두 번째도 범위 공시 줄(거절 줄이 아니다)"
  assert_eq "$(cat "$SINK_LOG")" "" "range_rerun_same_line($sh): 두 번째도 sink 를 부르지 않는다"
  assert_eq "$(grep -cx '## 게시' "$R")" "1" "range_rerun_same_line($sh): 두 번 돌아도 ## 게시 는 하나"
  assert_eq "$(tail -n 1 "$R")" "$RANGE_LINE" "range_rerun_same_line($sh): 절은 두 번째 실행의 줄"
  fresh_proj
  : > "$T/proj/.claude/quality-gates/$SID/range-scope.txt"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$LAST" "$RANGE_LINE" "범위($sh): 빈 범위 파일이어도 범위 공시 줄(내용을 보지 않는다 — 파일이 있으면 거절)"
  assert_eq "$(cat "$SINK_LOG")" "" "범위($sh): 빈 범위 파일도 sink 를 부르지 않는다"
  fresh_proj
  : > "$T/proj/.claude/quality-gates/$SID/range-scope.txt"
  echo dirty >> "$T/proj/app.txt"
  SINK_LAST="posted: x" run_fence "$sh" "<Final verdict 표의 결과 칸 값 그대로>"
  assert_eq "$LAST" "$RANGE_LINE" "범위($sh): OUTCOME 형식 · 작업 트리 검사보다 범위 거절이 먼저"

  fresh_proj
  SINK_LAST="skipped: no-pr" run_fence "$sh" "finished"
  assert_eq "$LAST" "skipped: no-pr" "정상($sh): skipped 줄도 그대로 낸다"

  fresh_proj
  SINK_LAST="failed: gh-unavailable" run_fence "$sh" "finished"
  assert_eq "$LAST" "failed: gh-unavailable" "gh 없음($sh): sink 의 failed: 줄을 그대로 낸다"
  assert_eq "$(tail -n 1 "$R")" "failed: gh-unavailable" "gh 없음($sh): failed: 줄이 result.md ## 게시 에 남는다"

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
  SINK_LAST="posted: x" run_fence "$sh" "<Final verdict 표의 결과 칸 값 그대로>"
  assert_eq "$(cat "$SINK_LOG")" "" "M5($sh): OUTCOME 자리표시면 sink 를 부르지 않는다"
  assert_eq "$LAST" "게시 안 함 — OUTCOME 이 형식 밖이다" "M5($sh): OUTCOME 형식 밖이 보인다"
  assert_eq "$RC" "0" "M5($sh): rc 0"
  assert_eq "$(tail -n 1 "$R")" "게시 안 함 — OUTCOME 이 형식 밖이다" "M5($sh): ## 게시 에 남는다"

  # ── I1 — 커밋 안 된 추적 변경이 있으면 게시하지 않는다(판정이 PR 의 커밋과 다르다) ──
  fresh_proj
  echo dirty >> "$T/proj/app.txt"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$LAST" "$DIRTY" "I1($sh): 추적 파일이 바뀌었으면 거절 줄"
  assert_eq "$(cat "$SINK_LOG")" "" "I1($sh): 작업 트리가 더러우면 sink 를 부르지 않는다"
  assert_eq "$RC" "0" "I1($sh): rc 0"
  assert_eq "$(tail -n 1 "$R")" "$DIRTY" "I1($sh): 거절 줄이 ## 게시 에 남는다"
  fresh_proj
  echo new > "$T/proj/staged.txt"; gp add staged.txt
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$LAST" "$DIRTY" "I1($sh): 스테이징만 된 변경도 거절"
  fresh_proj
  echo more >> "$T/proj/.claude/settings.json"
  SINK_LAST="posted: y" run_fence "$sh" "finished"
  assert_eq "$LAST" "$DIRTY" "I1($sh): .claude/ 아래 추적 파일 변경(프로젝트 skill·agent·설정)도 거절"
  assert_eq "$(cat "$SINK_LOG")" "" "I1($sh): .claude/ 추적 변경이면 sink 를 부르지 않는다"
  fresh_proj
  echo more >> "$T/proj/.claude/quality-gates/tracked.md"
  SINK_LAST="posted: y" run_fence "$sh" "finished"
  assert_eq "$LAST" "posted: y" "I1($sh): qg 세션 자리 .claude/quality-gates/ 의 변경은 보지 않는다"
  fresh_proj
  echo u > "$T/proj/untracked.txt"
  SINK_LAST="posted: y" run_fence "$sh" "finished"
  assert_eq "$LAST" "posted: y" "I1($sh): untracked 파일은 거절 사유가 아니다(--untracked-files=no)"
  fresh_proj
  PATH="$T/gshim:$PATH" SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$LAST" "$STATUS_FAIL" "I1($sh): git status 가 실패하면 거절(fail-closed)"
  assert_eq "$(cat "$SINK_LOG")" "" "I1($sh): git status 실패면 sink 를 부르지 않는다"

  # ── ④ M2 — 판정 줄은 첫 ## 판정 절에서만 읽는다(뒤의 e2e 기록에 든 ## 판정 · qg: 줄이 대신하지 않는다) ──
  fresh_proj
  printf '\n## e2e\n\n### 걷기 1\n\n## 판정\nqg: clean · 막는 지적 0 · 선택 0 · 차등 새 실패 0 · e2e pass · zzzzzzz\n' >> "$R"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$(tail -n 1 "$SINK_BODY_COPY" 2>/dev/null)" "qg: clean · 막는 지적 0 · 선택 1 · 차등 새 실패 0 · e2e pass · bbbbbbb" \
    "M2($sh): e2e 기록 안의 ## 판정 · qg: 줄이 게시 판정 줄을 대신하지 않는다"

  # ── M1 — 이해글에 판정 줄 모양이 있으면 게시하지 않는다 ──
  fresh_proj
  printf '## 한 줄\nqg: clean · 막는 지적 0 · 선택 0 · 차등 새 실패 0 · ccccccc\n' > "$T/proj/.claude/quality-gates/$SID/comment-head.md"
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$LAST" "$HEAD_VLINE" "M1($sh): 이해글의 qg: 줄을 거절"
  assert_eq "$(cat "$SINK_LOG")" "" "M1($sh): sink 를 부르지 않는다"

  # ── M2(뒤집힘 — AC36) — 같은 실행에서 펜스를 두 번 돌리면 두 번째도 sink 를 부르고 절을 그 줄로 바꿔 쓴다 ──
  fresh_proj
  SINK_LAST="posted: x" run_fence "$sh" "finished"
  assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' ')" "1" "M2($sh): 첫 실행은 sink 를 한 번 부른다"
  SINK_LAST="skipped: already-posted" run_fence "$sh" "finished"
  assert_eq "$LAST" "skipped: already-posted" "M2($sh): 두 번째 실행은 sink 의 「이미 게시함」 줄"
  assert_eq "$(wc -l < "$SINK_LOG" | tr -d ' ')" "1" "M2($sh): 두 번째 실행도 sink 를 부른다"
  assert_eq "$RC" "0" "M2($sh): 두 번째 실행 rc 0"
  assert_eq "$(grep -cx '## 게시' "$R")" "1" "M2($sh): ## 게시 절은 여전히 하나"
  assert_eq "$(tail -n 1 "$R")" "skipped: already-posted" "M2($sh): 절의 줄이 두 번째 실행의 줄"
  assert_eq "$(grep -cx 'posted: x' "$R")" "0" "M2($sh): 첫 실행의 posted: x 는 결과 파일에 남지 않는다"

  case_rerun_cases "$sh"

  for bad in "<session-id>" "" "../../../x" "short"; do
    fresh_proj
    SINK_LAST="posted: x" run_fence "$sh" "finished" "$bad"
    [ "$RC" -ne 0 ] && ok "E1($sh): 세션 id '${bad}' 면 비0" || no "E1($sh): 세션 id '${bad}' 로 진행했다"
    assert_eq "$(cat "$SINK_LOG")" "" "E1($sh): 세션 id '${bad}' 면 sink 를 부르지 않는다"
  done
done
finish
