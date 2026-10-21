#!/usr/bin/env bash
# 링크를 따라가지 않는 공용 writer(nofollow_write.py)의 동작과 두 플러그인 링크를 잰다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

W="$ROOT/shared/docreview/scripts/nofollow_write.py"
T="$(mktemp -d)"
cleanup() { chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

fresh() {   # fresh — 폴더와 레포 밖 대상을 새로 만든다
  chmod -R u+rwx "$T" 2>/dev/null
  rm -rf "$T/out" "$T/outside.txt" "$T/other"
  mkdir "$T/out"
  printf 'KEEP' > "$T/outside.txt"
  P="$T/out/b"
}
nw() { python3 "$W" "$@"; }
content() { cat "$1" 2>/dev/null; }
is_regular() { [ -f "$1" ] && [ ! -L "$1" ]; }
nlink() { python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_nlink)' "$1"; }

note "== run_symlink_replaced"
fresh; ln -s "$T/outside.txt" "$P"
nw run --out "$P" -- printf 'NEW' 2>/dev/null; rc=$?
assert_eq "$rc" "0" "run 링크: rc 0"
assert_eq "$(content "$T/outside.txt")" "KEEP" "run 링크: 레포 밖 대상 그대로"
is_regular "$P" && ok "run 링크: P 는 일반 파일" || no "run 링크: P 는 일반 파일"
assert_eq "$(content "$P")" "NEW" "run 링크: P 내용 NEW"

note "== run_hardlink_replaced"
fresh; ln "$T/outside.txt" "$P"
assert_eq "$(nlink "$P")" "2" "하드 링크 픽스처: 링크 수 2"
nw run --out "$P" -- printf 'NEW' 2>/dev/null; rc=$?
assert_eq "$rc" "0" "run 하드 링크: rc 0"
assert_eq "$(content "$T/outside.txt")" "KEEP" "run 하드 링크: 대상 그대로"
is_regular "$P" && ok "run 하드 링크: P 는 일반 파일" || no "run 하드 링크: P 는 일반 파일"
assert_eq "$(content "$P")" "NEW" "run 하드 링크: P 내용 NEW"
assert_eq "$(nlink "$P")" "1" "run 하드 링크: P 링크 수 1"

note "== run_passes_rc_and_keeps_stdout"
fresh
nw run --out "$P" -- sh -c 'printf X; exit 3' 2>/dev/null; rc=$?
assert_eq "$rc" "3" "run rc 3 그대로"
assert_eq "$(content "$P")" "X" "run rc 3: stdout 은 놓는다"
fresh
nw run --out "$P" -- sh -c 'printf X; exit 5' 2>/dev/null; rc=$?
assert_eq "$rc" "5" "run rc 5 그대로"
assert_eq "$(content "$P")" "X" "run rc 5: stdout 은 놓는다"

note "== run_missing_command_127"
fresh
nw run --out "$P" -- /nonexistent/cmd-zzz 2>/dev/null; rc=$?
assert_eq "$rc" "127" "없는 명령: rc 127"
is_regular "$P" && ok "없는 명령: P 는 일반 파일" || no "없는 명령: P 는 일반 파일"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "없는 명령: P 는 비어 있다"

note "== run_stdin_inherited"
fresh
printf 'in' | nw run --out "$P" -- cat 2>/dev/null; rc=$?
assert_eq "$rc" "0" "stdin 물려받기: rc 0"
assert_eq "$(content "$P")" "in" "stdin 물려받기: P 내용 in"

note "== run_self_failure_73"
fresh
nw run --out "$T/nodir/b" -- printf 'x' 2>"$T/err"; rc=$?
assert_eq "$rc" "73" "폴더 없음: rc 73"
assert_grep "$(head -n 1 "$T/err")" '^\[nofollow_write\] ' "폴더 없음: stderr 첫 줄 접두"
[ ! -e "$T/nodir/b" ] && ok "폴더 없음: P 없음" || no "폴더 없음: P 없음"
fresh; printf 'OLD' > "$P"; chmod 555 "$T/out"
nw run --out "$P" -- printf 'NEW' 2>"$T/err"; rc=$?
assert_eq "$rc" "73" "폴더 쓰기 불가: rc 73"
assert_eq "$(content "$P")" "OLD" "폴더 쓰기 불가: P 그대로"
assert_grep "$(head -n 1 "$T/err")" '^\[nofollow_write\] ' "폴더 쓰기 불가: stderr 접두"
chmod 755 "$T/out"

note "== bad_args_73"
fresh
nw 2>/dev/null; assert_eq "$?" "73" "모드 없음: rc 73"
nw run -- printf x 2>/dev/null; assert_eq "$?" "73" "--out 없음: rc 73"
nw run --out "$P" printf x 2>/dev/null; assert_eq "$?" "73" "run 에 -- 없음: rc 73"
nw empty 2>/dev/null; assert_eq "$?" "73" "empty --out 없음: rc 73"
nw bogus --out "$P" 2>/dev/null; assert_eq "$?" "73" "모르는 모드: rc 73"

note "== empty_symlink_and_hardlink"
fresh; ln -s "$T/outside.txt" "$P"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "empty 링크: rc 0"
is_regular "$P" && ok "empty 링크: P 일반 파일" || no "empty 링크: P 일반 파일"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "empty 링크: P 비어 있다"
assert_eq "$(content "$T/outside.txt")" "KEEP" "empty 링크: 대상 그대로"
fresh; ln "$T/outside.txt" "$P"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "empty 하드 링크: rc 0"
is_regular "$P" && ok "empty 하드 링크: P 일반 파일" || no "empty 하드 링크: P 일반 파일"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "empty 하드 링크: P 비어 있다"
assert_eq "$(content "$T/outside.txt")" "KEEP" "empty 하드 링크: 대상 그대로"

note "== empty_truncate_branch"
fresh; printf 'OLD' > "$P"; chmod 555 "$T/out"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "자르기 갈래: rc 0"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "자르기 갈래: P 크기 0"
chmod 755 "$T/out"
fresh; ln -s "$T/outside.txt" "$P"; chmod 555 "$T/out"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "73" "자르기 갈래 링크: rc 73"
assert_eq "$(content "$T/outside.txt")" "KEEP" "자르기 갈래 링크: 대상 그대로"
chmod 755 "$T/out"
fresh; printf 'OLD' > "$T/outside.txt"; ln "$T/outside.txt" "$P"; chmod 555 "$T/out"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "73" "자르기 갈래 하드 링크: rc 73"
assert_eq "$(content "$T/outside.txt")" "OLD" "자르기 갈래 하드 링크: 한 이름 OLD"
assert_eq "$(content "$P")" "OLD" "자르기 갈래 하드 링크: 다른 이름 OLD"
chmod 755 "$T/out"

note "== append_creates_and_appends"
fresh
printf 'a' | nw append --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "append 만들기: rc 0"
printf 'b' | nw append --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "append 덧붙이기: rc 0"
assert_eq "$(content "$P")" "ab" "append 내용 ab"
fresh
nw append --out "$P" </dev/null 2>/dev/null; rc=$?
assert_eq "$rc" "0" "빈 stdin: rc 0"
is_regular "$P" && ok "빈 stdin: 파일 생성" || no "빈 stdin: 파일 생성"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "빈 stdin: 빈 파일"

note "== append_refuses_links"
fresh; ln -s "$T/outside.txt" "$P"
printf 'z' | nw append --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "73" "append 링크: rc 73"
assert_eq "$(content "$T/outside.txt")" "KEEP" "append 링크: 대상 그대로"
fresh; ln "$T/outside.txt" "$P"
printf 'z' | nw append --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "73" "append 하드 링크: rc 73"
assert_eq "$(content "$T/outside.txt")" "KEEP" "append 하드 링크: 대상 그대로"

note "== mode_matches_shell"
fresh
( umask 027
  nw run --out "$T/out/viaw" -- printf 'm' 2>/dev/null
  printf 'm' > "$T/out/viash" )
mw="$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$T/out/viaw")"
ms="$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$T/out/viash")"
assert_eq "$mw" "$ms" "run 이 만든 권한 = 셸 > 가 만든 권한"

note "== bash32_fence"
fresh; ln -s "$T/outside.txt" "$P"
out="$(/bin/bash -c 'python3 "$1" empty --out "$2" 2>/dev/null || echo fail' _ "$W" "$P")"
assert_eq "$out" "" "bash 3.2 펜스 empty 링크: fail 아님"
is_regular "$P" && ok "bash 3.2 펜스 empty: P 일반 파일" || no "bash 3.2 펜스 empty: P 일반 파일"
assert_eq "$(content "$T/outside.txt")" "KEEP" "bash 3.2 펜스 empty: 대상 그대로"
fresh; ln "$T/outside.txt" "$P"
out="$(printf 'q' | /bin/bash -c 'python3 "$1" append --out "$2" 2>/dev/null || echo fail' _ "$W" "$P")"
assert_eq "$out" "fail" "bash 3.2 펜스 append 하드 링크: 거부"
assert_eq "$(content "$T/outside.txt")" "KEEP" "bash 3.2 펜스 append: 대상 그대로"
fresh
/bin/bash -c 'python3 "$1" run --out "$2" -- printf R 2>/dev/null || echo fail' _ "$W" "$P" >/dev/null
assert_eq "$(content "$P")" "R" "bash 3.2 펜스 run: P 내용 R"

note "== links_derived"
carriers="$(git ls-files -s -- 'plugins/*/scripts/run_docreview_codex_reviewer.sh' | awk '{ sub(/^[^\t]*\t/, ""); print }' | awk -F/ '{ print $2 }')"
n=0
for p in $carriers; do
  n=$((n+1))
  L="plugins/$p/scripts/nofollow_write.py"
  mode="$(git ls-files -s -- "$L" | awk '{ print $1 }')"
  assert_eq "$mode" "120000" "$p: nofollow_write.py 는 인덱스에서 링크(120000)"
  if [ -L "$L" ]; then
    got="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$L")"
    want="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$W")"
    assert_eq "$got" "$want" "$p: 링크가 공용 writer 로 풀린다"
  else
    no "$p: 작업 트리에서 링크가 아니다"
  fi
done
[ "$n" -ge 2 ] && ok "공유 러너를 싣는 플러그인 $n 개(2 이상)" || no "공유 러너를 싣는 플러그인 수 $n (2 이상이어야 한다)"

finish
