#!/usr/bin/env bash
# guards: shared/entry/entry_preflight.py plugins/*/scripts/entry_preflight.py shared/killswitch/kill_switch_active.py
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
S="$ROOT/shared/entry/entry_preflight.py"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' shared/entry/entry_preflight.py shared/killswitch/kill_switch_active.py \
    plugins/spec-distill/scripts/entry_preflight.py plugins/plugin-audit/scripts/entry_preflight.py \
    plugins/project-init/scripts/entry_preflight.py
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
PY="$(command -v python3)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/entrypre.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT
CLEAN="env -u DEVBREW_SPEC_DISTILL_DISABLE -u DEVBREW_PLUGIN_AUDIT_DISABLE -u DEVBREW_PROJECT_INIT_DISABLE -u DEVBREW_SKIP_HOOKS"

# 1. 리포 안 — 세 배포 지점이 정본 링크이고 ok 줄의 root 가 리포 루트다
for p in spec-distill plugin-audit project-init; do
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
out="$(cd "$PLAIN" && $CLEAN "$PY" "$S" project-init project-init)"; rc=$?
assert_eq "$rc" "0" "비-git: rc 0"
assert_eq "$out" "[devbrew-entry] ok plugin=project-init skill=project-init root=$PLAIN root_source=cwd" "비-git: root_source=cwd"

# 3. .git 안 — 작업 트리 밖이라 cwd 로
git init -q "$TMP/repo"
out="$(cd "$TMP/repo/.git" && $CLEAN "$PY" "$S" spec-distill s)"; rc=$?
assert_eq "$rc" "0" ".git 안: rc 0"
assert_contains "$out" "root_source=cwd" ".git 안: root_source=cwd"

# 4. git 부재
REPO="$(cd "$TMP/repo" && pwd -P)"
out="$(cd "$REPO" && $CLEAN "$PY" "$S" spec-distill s)"
assert_eq "$out" "[devbrew-entry] ok plugin=spec-distill skill=s root=$REPO" "git 있음(대조): 리포 루트"
out="$(cd "$REPO" && $CLEAN PATH=/nonexistent "$PY" "$S" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "git 부재: rc 0"
assert_contains "$out" "root_source=cwd" "git 부재: cwd 로"

# 5. 삭제된 cwd — error 줄, rc 0
mkdir -p "$TMP/gone"
out="$(cd "$TMP/gone" && rmdir "$TMP/gone" && $CLEAN "$PY" "$S" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "삭제된 cwd: rc 0"
assert_contains "$out" "[devbrew-entry] error plugin=spec-distill skill=s reason=" "삭제된 cwd: error 줄"

# 6. 사용법 — 인자 개수가 틀려도 rc 0 + error 줄
out="$($CLEAN "$PY" "$S")"; rc=$?
assert_eq "$rc" "0" "인자 없음: rc 0"
assert_contains "$out" "[devbrew-entry] error plugin=? skill=? reason=usage" "인자 없음: error 줄"

# 7. kill switch — 값이 정확히 "1" 일 때만. 도출은 정본 kill_switch_active 의 DISABLE 판정과 같다
for p in spec-distill plugin-audit project-init; do
  var="DEVBREW_$(printf '%s' "$p" | tr 'a-z-' 'A-Z_')_DISABLE"
  for v in 1 true " 1" 0 ""; do
    got="$(cd "$PLAIN" && $CLEAN "$var=$v" "$PY" "$S" "$p" s | awk '{print $2}')"
    want="$($CLEAN "$var=$v" "$PY" -c 'import sys; sys.path.insert(0, sys.argv[1]); from kill_switch_active import kill_switch_active as k; print("disabled" if k(sys.argv[2], "_") else "ok")' "$ROOT/shared/killswitch" "$p")"
    assert_eq "$got" "$want" "$p $var='$v': 진입 판정 = 정본 DISABLE 판정"
  done
done
out="$(cd "$PLAIN" && $CLEAN DEVBREW_PROJECT_INIT_DISABLE=1 "$PY" "$S" project-init project-init)"
assert_eq "$out" "[devbrew-entry] disabled plugin=project-init skill=project-init switch=DEVBREW_PROJECT_INIT_DISABLE=1" "disabled 줄 모양"
out="$(cd "$PLAIN" && $CLEAN DEVBREW_SKIP_HOOKS="spec-distill:spec-review,spec-distill:_" "$PY" "$S" spec-distill spec-review | awk '{print $2}')"
assert_eq "$out" "ok" "DEVBREW_SKIP_HOOKS 는 진입에 걸리지 않는다(D1.1)"

# 8. 비-UTF-8 로캘 + 한글 cwd — 출력 인코딩 실패가 rc≠0 으로 새지 않는다
mkdir -p "$TMP/한글 경로"
NONUTF8="PYTHONCOERCECLOCALE=0 PYTHONUTF8=0 LC_ALL=C LANG=C"
enc="$($CLEAN -u PYTHONIOENCODING $NONUTF8 "$PY" -c 'import sys; print(sys.stdout.encoding)')"
assert_not_contains "$(printf '%s' "$enc" | tr 'A-Z' 'a-z')" "utf" "양성 대조: 이 환경의 stdout 은 UTF-8 이 아니다($enc)"
out="$(cd "$TMP/한글 경로" && $CLEAN -u PYTHONIOENCODING $NONUTF8 "$PY" "$S" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "비-UTF-8 + 한글 cwd: rc 0"
assert_contains "$out" "[devbrew-entry] ok plugin=spec-distill skill=s root=" "비-UTF-8 + 한글 cwd: ok 줄"

# 8b. 한글 경로의 git 리포 — 비-UTF-8 로캘에서도 root 가 리포 최상위다(cwd 로 조용히 떨어지지 않는다)
git init -q "$TMP/한글 리포"
mkdir -p "$TMP/한글 리포/하위 폴더"
KREPO="$(cd "$TMP/한글 리포" && pwd -P)"
out="$(cd "$TMP/한글 리포/하위 폴더" && $CLEAN -u PYTHONIOENCODING $NONUTF8 "$PY" "$S" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "한글 리포 + 비-UTF-8: rc 0"
assert_not_contains "$out" "root_source=cwd" "한글 리포 + 비-UTF-8: cwd 로 떨어지지 않는다"
assert_contains "$out" "skill=s root=" "한글 리포 + 비-UTF-8: ok 줄"
assert_eq "$(printf '%s' "$out" | LC_ALL=C sed 's/.*root=//' | LC_ALL=C tr -c '[:print:]' '?' | LC_ALL=C tr -d '\n')" "$(printf '%s' "$KREPO" | LC_ALL=C tr -c '[:print:]' '?')" "한글 리포 + 비-UTF-8: root = 리포 최상위(비ASCII 는 ? 로 접어 비교)"

# 9. 3.8 문법 바닥 — macOS 시스템 python3 에서도 파싱된다
"$PY" -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read(), feature_version=(3,8))' "$S"
assert_eq "$?" "0" "3.8 문법으로 파싱된다"

# 10. 형제 import 없음 — 링크로 실행되면 sys.path[0] 이 정본 디렉토리다
bad="$(grep -nE '^[[:space:]]*(from|import)[[:space:]]' "$S" | grep -vE '^[0-9]+:(import (os|subprocess|sys)|from __future__ import annotations)$' || true)"
assert_eq "$bad" "" "import 는 os · subprocess · sys(+ __future__) 뿐이다"

finish
