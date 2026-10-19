#!/usr/bin/env bash
# resolve-range.sh — 범위(range <시작>[..<끝>])를 시작 · 끝 커밋 둘로 얼린다(AC21).
# qg-worktree.sh create-head --range — 얼린 끝 커밋에만 HEAD 축 트리를 만든다.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RR="$PLUGIN_DIR/scripts/resolve-range.sh"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

g() {   # g <repo> <git args…> — 전역 설정에 기대지 않는 커밋
  local r="$1"; shift
  git -C "$r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"
}

# 픽스처: 레포 A(trunk: c0 → c1(코드) → c2 → c3) · 곁가지 side(s1, c0 에서 갈라짐) · 클론 R.
# 전역 변수 A R C0 C1 C2 C3 S1 F 를 채운다.
mkfix() {
  local d; d=$(mktemp -d "$ROOT/fix.XXXXXX")
  A="$d/A"; R="$d/R"; F="$d/out/range-scope.md"
  mkdir -p "$A" "$d/out"
  git init -q -b trunk "$A"
  echo "# a" > "$A/README.md"; g "$A" add README.md; g "$A" commit -q -m c0
  C0=$(git -C "$A" rev-parse HEAD)
  mkdir -p "$A/src"; echo 'echo 1' > "$A/src/app.sh"; g "$A" add src/app.sh; g "$A" commit -q -m c1
  C1=$(git -C "$A" rev-parse HEAD)
  echo 'echo 2' > "$A/src/app.sh"; g "$A" commit -q -am c2
  C2=$(git -C "$A" rev-parse HEAD)
  mkdir -p "$A/docs"; echo x > "$A/docs/x.md"; g "$A" add docs/x.md; g "$A" commit -q -m c3
  C3=$(git -C "$A" rev-parse HEAD)
  g "$A" checkout -q -b side "$C0"
  echo s > "$A/side.txt"; g "$A" add side.txt; g "$A" commit -q -m s1
  S1=$(git -C "$A" rev-parse HEAD)
  g "$A" checkout -q trunk
  git clone -q "$A" "$R"
  git -C "$R" fetch -q origin
}

rr() {   # rr <words…> — R 안에서 resolve-range 를 돌린다. OUT · RC 를 채운다.
  OUT=$(cd "$R" && bash "$RR" --out "$F" -- "$@" 2>"$ROOT/err"); RC=$?
}

rfield() {   # rfield <key> [file] — 그 키의 값만(파일 기본값 $F)
  sed -n "s/^$1: //p" "${2:-$F}"
}

case_none() {
  echo "[none]"
  mkfix
  echo stale > "$F"
  rr branch
  assert_eq "$RC" 0 "range 가 없으면 rc 0"
  assert_eq "$OUT" "range: none" "stdout 은 'range: none'"
  [ ! -e "$F" ] && ok "미리 있던 출력 파일이 지워진다" || no "출력 파일이 남았다"
}

case_start_only_uses_origin_head() {
  echo "[start only — origin/HEAD]"
  mkfix
  rr range "$C1"
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(rfield status)" ok "status ok"
  assert_eq "$(rfield mode)" range "mode range"
  assert_eq "$(rfield spec)" "$C1" "spec 은 받은 값 그대로"
  assert_eq "$(rfield start)" "$C1" "start = c1 전체 id"
  assert_eq "$(rfield end)" "$C3" "end = c3"
  assert_eq "$(rfield end_from)" "origin/HEAD" "end_from = origin/HEAD"
  assert_eq "$(rfield end_ref)" "refs/remotes/origin/trunk" "end_ref = refs/remotes/origin/trunk"
  assert_eq "$(rfield commits)" 2 "commits = 2"
  local nf; nf=$(git -C "$R" diff --name-only "$C1" "$C3" | wc -l | tr -d ' ')
  assert_eq "$(rfield files)" "$nf" "files = c1..c3 바뀐 파일 수"
  assert_eq "$(rfield reason)" "-" "reason = -"
  assert_eq "$(wc -l < "$F" | tr -d ' ')" 11 "파일은 11줄"
  assert_eq "$(sed 's/:.*//' "$F" | tr '\n' ' ')" \
    "mode status reason spec start end end_from end_ref commits files head_is_end " "필드 순서"
  assert_eq "$OUT" "$(cat "$F")" "stdout 과 파일 내용이 같다"
}

case_start_end_given() {
  echo "[start..end given]"
  mkfix
  rr range "$C1..$C2"
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(rfield status)" ok "status ok"
  assert_eq "$(rfield end)" "$C2" "end = c2"
  assert_eq "$(rfield end_from)" given "end_from = given"
  assert_eq "$(rfield end_ref)" "-" "end_ref = -"
  assert_eq "$(rfield commits)" 1 "commits = 1"
}

case_short_and_ref_names() {
  echo "[short id · ref name]"
  mkfix
  rr range "$(printf '%s' "$C1" | cut -c1-7)..origin/trunk"
  assert_eq "$RC" 0 "rc 0"
  assert_eq "$(rfield status)" ok "status ok"
  assert_eq "$(rfield start)" "$C1" "짧은 id 가 전체 id 로 풀린다"
  assert_eq "$(rfield end)" "$C3" "end = c3"
}

case_bad_spec() {
  echo "[bad spec]"
  mkfix
  local v
  for v in '-x' "$C1...$C3" "..$C3" "$C1.." "$C1..-x"; do
    rr range "$v"
    assert_eq "$RC" 3 "'$v' → rc 3"
    assert_eq "$(rfield status)" bad-spec "'$v' → status bad-spec"
    assert_eq "$(rfield spec)" "$v" "'$v' → spec 은 받은 값 그대로"
  done
}

case_unresolved_start() {
  echo "[start unresolved]"
  mkfix
  rr range 0123456789abcdef0123
  assert_eq "$RC" 3 "rc 3"
  assert_eq "$(rfield status)" start-unresolved "status start-unresolved"
  assert_eq "$(rfield start)" "-" "start = -"
}

case_no_origin_head() {
  echo "[no origin/HEAD]"
  mkfix
  # 흔한 기본 브랜치 이름(main · master)을 원격에 둔다 — 그 이름으로 대신하면(origin/main 등) 끝이 풀려 이 경우가 실패한다.
  g "$A" branch main "$C3"; g "$A" branch master "$C3"
  git -C "$R" fetch -q origin
  git -C "$R" branch -q main origin/main
  git -C "$R" remote set-head origin -d
  git -C "$R" rev-parse --verify -q refs/remotes/origin/main >/dev/null && ok "전제: origin/main 이 있다" || no "전제: origin/main 이 없다 — 대체 이름 검사가 공허하다"
  git -C "$R" rev-parse --verify -q refs/remotes/origin/master >/dev/null && ok "전제: origin/master 가 있다" || no "전제: origin/master 가 없다"
  rr range "$C1"
  assert_eq "$RC" 3 "rc 3"
  assert_eq "$(rfield status)" end-unresolved "status end-unresolved"
  assert_contains "$(rfield reason)" "git remote set-head origin --auto" "reason 이 고치는 길을 알린다"
  assert_eq "$(rfield end)" "-" "end = -"
  assert_eq "$(rfield start)" "$C1" "start 는 풀린 값"
}

case_not_ancestor() {
  echo "[not ancestor]"
  mkfix
  rr range "$S1"
  assert_eq "$RC" 3 "rc 3"
  assert_eq "$(rfield status)" not-ancestor "status not-ancestor"
}

case_empty() {
  echo "[empty]"
  mkfix
  rr range "$C3"
  assert_eq "$RC" 3 "rc 3"
  assert_eq "$(rfield status)" empty "status empty (start = end)"
}

case_head_is_end() {
  echo "[head_is_end]"
  mkfix
  git -C "$R" checkout -q --detach "$C1"
  rr range "$C1..$C3"
  assert_eq "$(rfield head_is_end)" no "HEAD = c1 → head_is_end no"
  git -C "$R" checkout -q --detach "$C3"
  rr range "$C1..$C3"
  assert_eq "$(rfield head_is_end)" yes "HEAD = c3 → head_is_end yes"
}

case_usage() {
  echo "[usage]"
  mkfix
  (cd "$R" && bash "$RR" -- range "$C1" >/dev/null 2>&1); assert_eq "$?" 2 "--out 없음 → rc 2"
  (cd "$R" && bash "$RR" --out "$F" -- range >/dev/null 2>&1); assert_eq "$?" 2 "range 뒤 값 없음 → rc 2"
}

case_frozen_end_survives_fetch() {
  echo "[frozen end survives fetch]"
  mkfix
  rr range "$C1"
  assert_eq "$(rfield end)" "$C3" "얼린 끝 = c3"
  echo 'echo 4' > "$A/src/app.sh"; g "$A" commit -q -am c4
  local c4; c4=$(git -C "$A" rev-parse HEAD)
  git -C "$R" fetch -q origin
  assert_eq "$(git -C "$R" rev-parse origin/trunk)" "$c4" "fetch 뒤 origin/trunk 는 c4"
  assert_eq "$(rfield end)" "$C3" "파일의 end 는 여전히 c3"

  local out rc err wtp
  out=$(cd "$R" && bash "$WT" create-head "$C3" sid12345 --range "$F" 2>"$ROOT/err"); rc=$?
  assert_eq "$rc" 0 "create-head <c3> --range → rc 0"
  wtp=$(printf '%s\n' "$out" | tail -1)
  assert_eq "$(git -C "$wtp" rev-parse HEAD 2>/dev/null)" "$C3" "그 트리의 HEAD = c3"

  out=$(cd "$R" && bash "$WT" create-head "$c4" sid12345 --range "$F" 2>"$ROOT/err"); rc=$?
  err=$(cat "$ROOT/err")
  assert_eq "$rc" 2 "create-head <c4> --range → rc 2"
  assert_contains "$err" "range end mismatch" "stderr 'range end mismatch'"

  out=$(cd "$R" && bash "$WT" create-head "$C1" sid12345 --range "$F" 2>"$ROOT/err"); rc=$?
  assert_eq "$rc" 2 "create-head <c1(=start)> --range → rc 2"

  local f2; f2="$(dirname "$F")/range-scope-empty.md"
  sed 's/^status: .*/status: empty/' "$F" > "$f2"
  out=$(cd "$R" && bash "$WT" create-head "$C3" sid12345 --range "$f2" 2>"$ROOT/err"); rc=$?
  err=$(cat "$ROOT/err")
  assert_eq "$rc" 2 "status empty 인 파일 → rc 2"
  assert_contains "$err" "range scope not ok" "stderr 'range scope not ok'"

  out=$(cd "$R" && bash "$WT" create-head "$C3" sid12345 --range "$(dirname "$F")/nope.md" 2>"$ROOT/err"); rc=$?
  err=$(cat "$ROOT/err")
  assert_eq "$rc" 2 "없는 파일 → rc 2"
  assert_contains "$err" "range scope not ok" "없는 파일도 'range scope not ok'"
}

case_no_default_branch_literal() {
  echo "[no default-branch literal]"
  local n; n=$(grep -nwE 'main|master' "$RR" | wc -l | tr -d ' ')
  assert_eq "$n" 0 "resolve-range.sh 에 기본 브랜치 이름 리터럴이 없다"
  assert_file_grep "$RR" 'origin/HEAD' "양성 짝 — origin/HEAD 는 있다"
}

case_none
case_start_only_uses_origin_head
case_start_end_given
case_short_and_ref_names
case_bad_spec
case_unresolved_start
case_no_origin_head
case_not_ancestor
case_empty
case_head_is_end
case_usage
case_frozen_end_survives_fetch
case_no_default_branch_literal
finish
