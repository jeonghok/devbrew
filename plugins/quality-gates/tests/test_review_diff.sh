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
  assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 9 "stdout 9줄"
  assert_eq "$(sed 's/:.*//' <<< "$OUT" | tr '\n' ' ')" \
    "mode base head degraded files filtered_files excluded kept_model doc_paths_source " "키 순서"
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
  rd --mode session
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(field excluded "$OUT")" 1 "excluded: 1"
  assert_eq "$(field kept_model "$OUT")" 0 "kept_model: 0"
  assert_eq "$(field doc_paths_source "$OUT")" default "doc_paths_source: default"
  assert_eq "$(field files "$OUT")" 2 "files: 2"
  assert_eq "$(field filtered_files "$OUT")" 1 "filtered_files: 1"
  assert_file_absent "$D/review-i1.diff" 'README' "걸러진 diff 에 README 없음"
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
case_from_subdir
case_usage
finish
