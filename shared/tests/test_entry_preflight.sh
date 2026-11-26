#!/usr/bin/env bash
# guards: shared/entry/entry_preflight.py plugins/*/scripts/entry_preflight.py shared/killswitch/kill_switch_active.py plugins/*/switches.md
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
S="$ROOT/shared/entry/entry_preflight.py"
# 사전 검사 링크와 끄기 변수 표를 싣는 플러그인 — 아래 「깨끗한 환경」 과 절 1 이 이 목록으로 읽고, --emit-scanned 도 이 목록으로 낸다
PLUGINS="spec-distill quality-gates plugin-audit project-init"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' shared/entry/entry_preflight.py shared/killswitch/kill_switch_active.py
  for p in $PLUGINS; do
    printf '%s\n' "plugins/$p/scripts/entry_preflight.py" "plugins/$p/switches.md"
  done
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
PY="$(command -v python3)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/entrypre.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT
# TMPDIR 가 어느 git 작업 트리 안이어도(지휘자의 스위트 대조는 레포 안 폴더를 준다) 비-git 픽스처가
# 비-git 으로 남게, git 이 임시 폴더 위로 올라가 찾지 않게 한다 — 사전 검사의 git 호출이 이 환경을 물려받는다.
GIT_CEILING_DIRECTORIES="$(cd "$TMP" && pwd -P)" || exit 1
export GIT_CEILING_DIRECTORIES
L() { printf '%s' "$ROOT/plugins/$1/scripts/entry_preflight.py"; }

# 깨끗한 환경 — 네 표의 환경변수 이름 전부와 DEVBREW_SKIP_HOOKS 를 걷는다(개발자 셸에 남은 끄기 변수가 거짓 RED 를 내지 않게)
NAMES="$("$PY" -c 'import sys,importlib.util
s=importlib.util.spec_from_file_location("e",sys.argv[1])
m=importlib.util.module_from_spec(s)
s.loader.exec_module(m)
seen=[]
for p in sys.argv[3:]:
    for r in m.read_table(m.table_path(sys.argv[2]+"/plugins/"+p+"/scripts/entry_preflight.py"),p):
        for n in r["names"]:
            if "=" not in n and n not in seen: seen.append(n)
print(" ".join(seen))' "$S" "$ROOT" $PLUGINS)"
set -- $NAMES
NNAMES=$#
CLEAN="env -u DEVBREW_SKIP_HOOKS"
for n in $NAMES; do CLEAN="$CLEAN -u $n"; done
if [ "$NNAMES" -gt 0 ]; then ok "깨끗한 환경: 네 표에서 끄기 변수 $NNAMES 개를 도출했다"
else no "깨끗한 환경: 도출 수가 0 이다 — CLEAN 이 비었다"; fi

# 1. 리포 안 — 네 배포 지점이 정본 링크이고 ok 줄의 root 가 리포 루트다
for p in $PLUGINS; do
  link="$ROOT/plugins/$p/scripts/entry_preflight.py"
  tgt=""
  [ -L "$link" ] && tgt="$(cd "$(dirname "$link")" && cd "$(dirname "$(readlink "$link")")" && pwd -P)/$(basename "$(readlink "$link")")"
  assert_eq "$tgt" "$S" "$p: 배포 지점이 정본을 가리키는 심볼릭 링크다"
  out="$(cd "$ROOT" && $CLEAN "$PY" "$link" "$p" x-skill)"; rc=$?
  assert_eq "$rc" "0" "$p: rc 0"
  assert_eq "$out" "[devbrew-entry] ok plugin=$p skill=x-skill root=$ROOT" "$p: ok 감시줄 + 리포 루트"
done

# 2. 비-git 디렉토리 — cwd 로 떨어지되 ok
mkdir -p "$TMP/plain"
PLAIN="$(cd "$TMP/plain" && pwd -P)"
out="$(cd "$PLAIN" && $CLEAN "$PY" "$(L project-init)" project-init project-init)"; rc=$?
assert_eq "$rc" "0" "비-git: rc 0"
assert_eq "$out" "[devbrew-entry] ok plugin=project-init skill=project-init root=$PLAIN root_source=cwd" "비-git: root_source=cwd"

# 3. .git 안 — 작업 트리 밖이라 cwd 로
git init -q "$TMP/repo"
out="$(cd "$TMP/repo/.git" && $CLEAN "$PY" "$(L spec-distill)" spec-distill s)"; rc=$?
assert_eq "$rc" "0" ".git 안: rc 0"
assert_contains "$out" "root_source=cwd" ".git 안: root_source=cwd"

# 4. git 부재
REPO="$(cd "$TMP/repo" && pwd -P)"
out="$(cd "$REPO" && $CLEAN "$PY" "$(L spec-distill)" spec-distill s)"
assert_eq "$out" "[devbrew-entry] ok plugin=spec-distill skill=s root=$REPO" "git 있음(대조): 리포 루트"
out="$(cd "$REPO" && $CLEAN PATH=/nonexistent "$PY" "$(L spec-distill)" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "git 부재: rc 0"
assert_contains "$out" "root_source=cwd" "git 부재: cwd 로"

# 5. 삭제된 cwd — error 줄, rc 0
mkdir -p "$TMP/gone"
out="$(cd "$TMP/gone" && rmdir "$TMP/gone" && $CLEAN "$PY" "$(L spec-distill)" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "삭제된 cwd: rc 0"
assert_contains "$out" "[devbrew-entry] error plugin=spec-distill skill=s reason=" "삭제된 cwd: error 줄"

# 6. 사용법 — 인자 개수가 틀려도 rc 0 + error 줄
out="$($CLEAN "$PY" "$S")"; rc=$?
assert_eq "$rc" "0" "인자 없음: rc 0"
assert_contains "$out" "[devbrew-entry] error plugin=? skill=? reason=usage" "인자 없음: error 줄"

# 7. 통째 끄기 변수 — 은퇴했다. 켜도 감시줄은 ok 이고 「더 듣지 않는다」 줄이 둘째 줄에 붙는다(값이 정확히 "1" 일 때만)
for p in spec-distill quality-gates plugin-audit project-init; do
  var="DEVBREW_$(printf '%s' "$p" | tr 'a-z-' 'A-Z_')_DISABLE"
  out="$(cd "$PLAIN" && $CLEAN "$var=1" "$PY" "$(L "$p")" "$p" s)"
  case "$(printf '%s\n' "$out" | sed -n 1p)" in
    "[devbrew-entry] ok plugin=$p "*) ok "$p $var=1: 첫 줄이 ok 감시줄이다" ;;
    *) no "$p $var=1: 첫 줄이 ok 감시줄이다"; printf '      out: %s\n' "$out" ;;
  esac
  line2="$(printf '%s\n' "$out" | sed -n 2p)"
  case "$line2" in
    "[devbrew-switch] 더 듣지 않는다 — $p 전체"*) ok "$p $var=1: 둘째 줄이 은퇴 줄이다" ;;
    *) no "$p $var=1: 둘째 줄이 은퇴 줄이다"; printf '      line2: %s\n' "$line2" ;;
  esac
  assert_contains "$line2" "). 대신: Claude Code 의 플러그인 끄기" "$p $var=1: 은퇴 줄이 대신할 길을 보인다"
  assert_not_contains "$out" " disabled " "$p $var=1: 출력 어디에도 disabled 가 없다"
  assert_eq "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "2" "$p $var=1: 두 줄이다(양성 짝 — 값 1 은 줄을 낸다)"
  for v in true " 1" 0 ""; do
    out="$(cd "$PLAIN" && $CLEAN "$var=$v" "$PY" "$(L "$p")" "$p" s)"
    assert_eq "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "1" "$p $var='$v': 감시줄 한 줄뿐이다"
    assert_not_contains "$out" "[devbrew-switch]" "$p $var='$v': 은퇴 줄이 없다"
  done
done
out="$(cd "$PLAIN" && $CLEAN DEVBREW_SKIP_HOOKS=spec-distill:statusline "$PY" "$(L spec-distill)" spec-distill s)"
case "$(printf '%s\n' "$out" | sed -n 1p)" in
  "[devbrew-entry] ok plugin=spec-distill "*) ok "SKIP_HOOKS 토큰: 첫 줄이 ok 감시줄이다" ;;
  *) no "SKIP_HOOKS 토큰: 첫 줄이 ok 감시줄이다" ;;
esac
assert_contains "$(printf '%s\n' "$out" | sed -n 2p)" "[devbrew-switch] 더 듣지 않는다 — 상태줄과 로드맵 지도" "SKIP_HOOKS 토큰: 둘째 줄이 은퇴 줄이다"
out="$(cd "$PLAIN" && $CLEAN DEVBREW_SKIP_HOOKS="spec-distill:spec-review,spec-distill:_" "$PY" "$(L spec-distill)" spec-distill spec-review | head -n 1 | awk '{print $2}')"
assert_eq "$out" "ok" "DEVBREW_SKIP_HOOKS 는 진입에 걸리지 않는다(D1.1)"

# 8. 비-UTF-8 로캘 + 한글 cwd — 출력 인코딩 실패가 rc≠0 으로 새지 않는다
mkdir -p "$TMP/한글 경로"
NONUTF8="PYTHONCOERCECLOCALE=0 PYTHONUTF8=0 LC_ALL=C LANG=C"
enc="$($CLEAN -u PYTHONIOENCODING $NONUTF8 "$PY" -c 'import sys; print(sys.stdout.encoding)')"
assert_not_contains "$(printf '%s' "$enc" | tr 'A-Z' 'a-z')" "utf" "양성 대조: 이 환경의 stdout 은 UTF-8 이 아니다($enc)"
out="$(cd "$TMP/한글 경로" && $CLEAN -u PYTHONIOENCODING $NONUTF8 "$PY" "$(L spec-distill)" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "비-UTF-8 + 한글 cwd: rc 0"
assert_contains "$out" "[devbrew-entry] ok plugin=spec-distill skill=s root=" "비-UTF-8 + 한글 cwd: ok 줄"

# 8b. 한글 경로의 git 리포 — 비-UTF-8 로캘에서도 root 가 리포 최상위다(cwd 로 조용히 떨어지지 않는다)
git init -q "$TMP/한글 리포"
mkdir -p "$TMP/한글 리포/하위 폴더"
KREPO="$(cd "$TMP/한글 리포" && pwd -P)"
out="$(cd "$TMP/한글 리포/하위 폴더" && $CLEAN -u PYTHONIOENCODING $NONUTF8 "$PY" "$(L spec-distill)" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "한글 리포 + 비-UTF-8: rc 0"
assert_not_contains "$out" "root_source=cwd" "한글 리포 + 비-UTF-8: cwd 로 떨어지지 않는다"
assert_contains "$out" "skill=s root=" "한글 리포 + 비-UTF-8: ok 줄"
assert_eq "$(printf '%s' "$out" | LC_ALL=C sed 's/.*root=//' | LC_ALL=C tr -c '[:print:]' '?' | LC_ALL=C tr -d '\n')" "$(printf '%s' "$KREPO" | LC_ALL=C tr -c '[:print:]' '?')" "한글 리포 + 비-UTF-8: root = 리포 최상위(비ASCII 는 ? 로 접어 비교)"

# 9. 3.8 문법 바닥 — macOS 시스템 python3 에서도 파싱된다
"$PY" -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read(), feature_version=(3,8))' "$S"
assert_eq "$?" "0" "3.8 문법으로 파싱된다"

# 10. 형제 import 없음 — 링크로 실행되면 sys.path[0] 이 정본 디렉토리다
bad="$(grep -nE '^[[:space:]]*(from|import)[[:space:]]' "$S" | grep -vE '^[0-9]+:import (os|subprocess|sys)$' || true)"
assert_eq "$bad" "" "import 는 os · subprocess · sys 뿐이다"

# 11. 끊긴 파이프 — 읽는 쪽이 닫힌 stdout 에 써도 rc 0 (종료 flush 의 rc 120 금지)
bp_rc="$("$PY" -c 'import os,subprocess,sys
r,w=os.pipe(); os.close(r)
print(subprocess.run([sys.executable,sys.argv[1],"spec-distill","s"],stdout=w,stderr=subprocess.DEVNULL).returncode)' "$(L spec-distill)")"
assert_eq "$bp_rc" "0" "끊긴 파이프: rc 0"

# ── 끄기 변수 표 줄([devbrew-switch]) ─────────────────────────────────────────
# 설치본 꼴: $TMP/inst/<p>/scripts/entry_preflight.py(cp -L) + $TMP/inst/<p>/switches.md(fixture)
I="$TMP/inst/spec-distill"
mkdir -p "$I/scripts" "$TMP/fix"
cp -L "$S" "$I/scripts/entry_preflight.py"
IS="$I/scripts/entry_preflight.py"
printf '%s\n' '---' 'type: devbrew-switches' 'plugin: spec-distill' '---' '' '# fixture 끄기 변수' '' \
  '| 이름 | 끄는 것 | 상태 | 대신할 길 |' '|---|---|---|---|' > "$TMP/fix/head.txt"
printf '%s\n' \
  '| `DEVBREW_FIX_STAY` | 남는 것 | 남음 | — |' \
  '| `DEVBREW_FIX_SOON` | 곧 가는 것 | 은퇴 예정 | 대신 쓸 길 |' \
  '| `DEVBREW_FIX_GONE` | 간 것 | 은퇴 | 이미 없다 |' \
  '| `DEVBREW_FIX_ALIAS_A` · `DEVBREW_FIX_ALIAS_B` | 별칭 있는 것 | 남음 | — |' \
  '| `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` | 토큰 것 | 남음 | — |' \
  '| `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` | 픽스처 codex | 남음 | — |' > "$TMP/fix/rows.txt"
cat "$TMP/fix/head.txt" "$TMP/fix/rows.txt" > "$TMP/fix/good.md"
SENT="[devbrew-entry] ok plugin=spec-distill skill=s root=$PLAIN root_source=cwd"
UNR="[devbrew-switch] 끄기 변수 표를 읽지 못했다 — "
# run_inst <환경 NAME=값 ...> — 설치본 사본을 PLAIN 에서 부른다
run_inst() { (cd "$PLAIN" && $CLEAN "$@" "$PY" "$IS" spec-distill s); }
nlines() { printf '%s\n' "$1" | wc -l | tr -d ' '; }
tail_of() { printf '%s\n' "$1" | tail -n +2; }
reset_table() { cp "$TMP/fix/good.md" "$I/switches.md"; }
reset_table

# test_lines_by_state
L_STAY="[devbrew-switch] 꺼져 있다 — 남는 것(DEVBREW_FIX_STAY=1)"
L_SOON="[devbrew-switch] 꺼져 있다 — 곧 가는 것(DEVBREW_FIX_SOON=1). 곧 은퇴한다 — 대신: 대신 쓸 길"
L_GONE="[devbrew-switch] 더 듣지 않는다 — 간 것(DEVBREW_FIX_GONE=1). 대신: 이미 없다"
out="$(run_inst DEVBREW_FIX_STAY=1)"; rc=$?
assert_eq "$rc" "0" "남음: rc 0"
assert_eq "$out" "$(printf '%s\n%s' "$SENT" "$L_STAY")" "남음: 감시줄 + 남음 줄"
out="$(run_inst DEVBREW_FIX_SOON=1)"
assert_eq "$out" "$(printf '%s\n%s' "$SENT" "$L_SOON")" "은퇴 예정: 곧 은퇴한다 + 대신 줄"
out="$(run_inst DEVBREW_FIX_GONE=1)"
assert_eq "$out" "$(printf '%s\n%s' "$SENT" "$L_GONE")" "은퇴: 더 듣지 않는다 + 대신 줄"
out="$(run_inst DEVBREW_FIX_GONE=1 DEVBREW_FIX_STAY=1 DEVBREW_FIX_SOON=1)"
assert_eq "$out" "$(printf '%s\n%s\n%s\n%s' "$SENT" "$L_STAY" "$L_SOON" "$L_GONE")" "셋을 켜면 표의 행 순서로 세 줄"

# test_alias
out="$(run_inst DEVBREW_FIX_ALIAS_B=1)"
assert_eq "$(tail_of "$out")" "[devbrew-switch] 꺼져 있다 — 별칭 있는 것(DEVBREW_FIX_ALIAS_B=1)" "별칭 하나만 켜도 줄이 나오고 켠 이름이 보인다"
out="$(run_inst DEVBREW_FIX_ALIAS_A=1 DEVBREW_FIX_ALIAS_B=1)"
assert_eq "$(tail_of "$out")" "[devbrew-switch] 꺼져 있다 — 별칭 있는 것(DEVBREW_FIX_ALIAS_A=1 · DEVBREW_FIX_ALIAS_B=1)" "별칭 둘을 켜면 한 줄에 · 로 둘"

# test_value_not_one
for v in true " 1" 0 ""; do
  out="$(run_inst "DEVBREW_FIX_STAY=$v" "DEVBREW_FIX_SOON=$v" "DEVBREW_FIX_GONE=$v")"
  assert_eq "$out" "$SENT" "값이 '$v' 이면 줄이 없다(감시줄 한 줄)"
done

# test_not_in_table
out="$(run_inst DEVBREW_QUALITY_GATES_DISABLE_CODEX=1)"
assert_eq "$out" "$SENT" "표에 없는 끄기 변수는 줄이 없다"

# test_skip_hooks_tokens
L_TOK="[devbrew-switch] 꺼져 있다 — 토큰 것(DEVBREW_SKIP_HOOKS=spec-distill:review-entry)"
out="$(run_inst "DEVBREW_SKIP_HOOKS=x:y, spec-distill:review-entry ,foo")"
assert_eq "$(tail_of "$out")" "$L_TOK" "쉼표로 나눠 양끝 공백을 걷은 전체 토큰이면 그 행 한 줄"
for v in "spec-distill:review-entry-x" "review-entry" "quality-gates:review-entry" "xspec-distill:review-entry" ""; do
  out="$(run_inst "DEVBREW_SKIP_HOOKS=$v")"
  assert_eq "$out" "$SENT" "토큰 '$v' 는 줄이 없다"
done

# test_location_follows_invoked_path
out="$(cd "$PLAIN" && $CLEAN DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 "$PY" "$(L spec-distill)" spec-distill s)"
assert_eq "$(tail_of "$out")" "[devbrew-switch] 꺼져 있다 — codex 리뷰(DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1)" "리포 링크로 부르면 리포 표의 끄는 것"
out="$(run_inst DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1)"
assert_eq "$(tail_of "$out")" "[devbrew-switch] 꺼져 있다 — 픽스처 codex(DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1)" "설치본 사본으로 부르면 fixture 의 끄는 것(양성 대조)"
out="$(cd "$PLAIN" && $CLEAN DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 "$PY" "$S" spec-distill s)"
assert_eq "$(nlines "$out")" "2" "정본 경로로 부르면 줄이 둘이다(감시줄 + 읽지 못함)"
assert_contains "$(tail_of "$out")" "$UNR" "정본 경로로 부르면 표를 읽지 못했다는 줄"

# test_unreadable — 망가진 꼴마다 감시줄 그대로 + 읽지 못함 한 줄, rc 0
check_unreadable() { # <라벨>
  out="$(run_inst DEVBREW_FIX_STAY=1)"; rc=$?
  assert_eq "$rc" "0" "$1: rc 0"
  assert_eq "$(printf '%s\n' "$out" | head -n 1)" "$SENT" "$1: 첫 줄은 감시줄 그대로"
  assert_contains "$(tail_of "$out" | head -n 1)" "$UNR" "$1: 둘째 줄은 읽지 못함"
  assert_eq "$(nlines "$out")" "2" "$1: 줄은 둘뿐"
}
variant() { # <라벨> <sed 식>
  LC_ALL=C sed "$2" "$TMP/fix/good.md" > "$I/switches.md"
  check_unreadable "$1"
}
reset_table; rm -f "$I/switches.md"; check_unreadable "파일 없음"
variant "머리줄 다름" 's/| 끄는 것 |/| 하는 것 |/'
variant "구분줄 다름" 's/^|---|---|---|---|$/|---|---|---|/'
variant "칸 셋" 's/ | — |$/ |/'
variant "plugin 이 다른 플러그인" 's/^plugin: spec-distill$/plugin: quality-gates/'
variant "frontmatter type 다름" 's/^type: devbrew-switches$/type: other/'
variant "이름이 백틱 밖" 's/`DEVBREW_FIX_STAY`/DEVBREW_FIX_STAY/'
variant "이름 꼴 틀림" 's/DEVBREW_FIX_STAY/DEVBREW_x/'
variant "상태 남는다" 's/| 남음 |/| 남는다 |/'
reset_table; printf '%s\n' '| `DEVBREW_FIX_STAY` | 또 | 남음 | — |' >> "$I/switches.md"; check_unreadable "같은 이름 두 행"
reset_table; printf '\n' >> "$I/switches.md"; head -c 70000 /dev/zero | LC_ALL=C tr '\0' 'x' >> "$I/switches.md"; check_unreadable "64 KiB 넘음"
reset_table; printf '\n\377\376\n' >> "$I/switches.md"; check_unreadable "UTF-8 아님"
reset_table; printf '\n%s\n%s\n' '| 이름 | 끄는 것 | 상태 | 대신할 길 |' '|---|---|---|---|' >> "$I/switches.md"; check_unreadable "표가 둘"

# test_bom_crlf_empty
{ printf '\357\273\277'; cat "$TMP/fix/good.md"; } > "$I/switches.md"
out="$(run_inst DEVBREW_FIX_STAY=1)"
assert_eq "$(tail_of "$out")" "$L_STAY" "BOM 이 붙은 표는 정상으로 읽힌다"
awk '{printf "%s\r\n", $0}' "$TMP/fix/good.md" > "$I/switches.md"
out="$(run_inst DEVBREW_FIX_STAY=1)"
assert_eq "$(tail_of "$out")" "$L_STAY" "CRLF 줄끝 표는 정상으로 읽힌다"
cp "$TMP/fix/head.txt" "$I/switches.md"
out="$(run_inst DEVBREW_FIX_STAY=1)"
assert_eq "$out" "$SENT" "행이 없는 표는 줄 없이 감시줄 하나"
reset_table

# test_usage_error_no_switch_lines
out="$(cd "$PLAIN" && $CLEAN DEVBREW_FIX_STAY=1 "$PY" "$IS" spec-distill)"
assert_eq "$(nlines "$out")" "1" "인자 하나: error 줄 하나뿐"
assert_contains "$out" "[devbrew-entry] error plugin=? skill=? reason=usage" "인자 하나: usage error"
out="$(cd "$PLAIN" && $CLEAN "$PY" "$IS" spec-distill s extra)"
assert_eq "$(nlines "$out")" "1" "인자 셋: error 줄 하나뿐"
out="$(cd "$PLAIN" && $CLEAN "$PY" "$IS" spec-distill "")"
assert_eq "$(nlines "$out")" "1" "빈 인자: error 줄 하나뿐"

finish
