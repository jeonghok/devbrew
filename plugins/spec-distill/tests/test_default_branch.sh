#!/usr/bin/env bash
# 기본 브랜치 — 전체 참조 이름에서 짧은 이름 · 못 찾으면 고치는 법 · 원격과 대조(R8 AC9 · AC10 · AC11).
# 픽스처는 임시 레포다: 원격은 로컬 bare, origin/HEAD 는 `remote set-head --auto`.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_default_branch.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset DEVBREW_SPEC_DISTILL_DISABLE DEVBREW_SKIP_HOOKS
REAL="$ROOT/plugins/spec-distill/scripts"
RD="$REAL/repo_defaults.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1

g() {  # g <레포> <git 인자…>
  local r="$1"; shift
  git -C "$r" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"
}
mkrepo() {  # mkrepo <이름> <기본 브랜치> — $T/<이름>/work + $T/<이름>/remote.git, origin/HEAD 있음
  local d="$T/$1"
  mkdir -p "$d" && git init -q --bare -b "$2" "$d/remote.git" && git init -q -b "$2" "$d/work" || return 1
  g "$d/work" commit -q --allow-empty -m init && g "$d/work" remote add origin "$d/remote.git" \
    && g "$d/work" push -q origin "$2" && g "$d/work" remote set-head origin --auto >/dev/null
}
run() {  # run <cwd> <인자…> → OUT · ERR · RC
  local c="$1"; shift
  OUT="$(cd "$c" && python3 "$RD" "$@" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"
}

echo "=== 짧은 이름은 전체 참조 이름에서(AC11) ==="
# ── trunk_repo ───────────────────────────────────────────────────────────────
mkrepo trunk trunk || { no "픽스처 trunk"; finish; exit 1; }
run "$T/trunk/work" default-branch
assert_eq "$RC:$OUT" "0:trunk" "trunk_repo: 기본 브랜치 trunk"

# ── local_branch_named_origin_main ───────────────────────────────────────────
mkrepo lom main || { no "픽스처 lom"; finish; exit 1; }
g "$T/lom/work" branch origin/main
run "$T/lom/work" default-branch
assert_eq "$RC:$OUT" "0:main" "local_branch_named_origin_main: 로컬 브랜치 origin/main 이 있어도 main"
[ "$(g "$T/lom/work" rev-parse --abbrev-ref refs/remotes/origin/HEAD)" != "main" ] \
  && ok "양성 대조: 이 레포에서 --abbrev-ref 는 main 이 아니다(벗기기 회귀 증인)" \
  || no "양성 대조: --abbrev-ref 가 main 이라 증인이 되지 못한다"

# ── slash_default ────────────────────────────────────────────────────────────
mkrepo slash feature/x || { no "픽스처 slash"; finish; exit 1; }
run "$T/slash/work" default-branch
assert_eq "$RC:$OUT" "0:feature/x" "slash_default: 이름에 / 가 든 기본 브랜치도 통째로"

echo "=== 못 찾으면 고치는 법(AC9) ==="
# ── no_origin ────────────────────────────────────────────────────────────────
mkdir -p "$T/noorigin" && git init -q -b main "$T/noorigin" && g "$T/noorigin" commit -q --allow-empty -m init
run "$T/noorigin" default-branch
assert_eq "$RC:$OUT" "3:" "no_origin: rc 3 · 표준 출력 비움"
assert_contains "$ERR" "git remote add origin" "no_origin: 원격을 더하라는 안내"
assert_contains "$ERR" "[spec-distill] " "no_origin: 표준 오류 머리"

# ── no_head ──────────────────────────────────────────────────────────────────
mkrepo nohead main || { no "픽스처 nohead"; finish; exit 1; }
g "$T/nohead/work" remote set-head origin -d
run "$T/nohead/work" default-branch
assert_eq "$RC:$OUT" "3:" "no_head: rc 3 · 표준 출력 비움"
assert_contains "$ERR" "git remote set-head origin --auto" "no_head: set-head 안내"
assert_not_contains "$ERR" "git remote add origin" "no_head: 원격이 있으면 더하라고 하지 않는다"

echo "=== 원격과 대조(AC10) ==="
run "$T/trunk/work" default-branch --check-remote
assert_eq "$RC:$OUT" "0:trunk" "양성 대조: 원격과 같으면 rc 0"
assert_not_contains "$ERR" "다르다" "양성 대조: 같으면 다르다는 줄이 없다"
assert_not_contains "$ERR" "대조하지 못했다" "양성 대조: 같으면 대조 못 함 줄도 없다"

# ── renamed_default ──────────────────────────────────────────────────────────
mkrepo ren main || { no "픽스처 ren"; finish; exit 1; }
REN="$T/ren/work"
g "$REN" push -q origin main:trunk && git -C "$T/ren/remote.git" symbolic-ref HEAD refs/heads/trunk
g "$REN" fetch -q origin
run "$REN" default-branch
assert_eq "$RC:$OUT" "0:main" "renamed_default: 대조 없이는 로컬 값 main(fetch 는 origin/HEAD 를 고치지 않는다)"
run "$REN" default-branch --check-remote
assert_eq "$RC:$OUT" "5:" "renamed_default: 원격과 다르면 rc 5 · 표준 출력 비움"
assert_contains "$ERR" "원격 기본 브랜치(trunk)가 로컬 기본 브랜치(main)와 다르다" "renamed_default: 두 이름을 함께"
assert_contains "$ERR" "git remote set-head origin --auto" "renamed_default: 맞추는 법"

# ── offline ──────────────────────────────────────────────────────────────────
mkrepo off main || { no "픽스처 off"; finish; exit 1; }
g "$T/off/work" remote set-url origin "$T/없는/remote.git"
run "$T/off/work" default-branch --check-remote
assert_eq "$RC:$OUT" "0:main" "offline: 대조하지 못해도 로컬 값으로 rc 0"
assert_contains "$ERR" "원격과 대조하지 못했다 — 로컬 기본 브랜치 main 을 썼다" "offline: 대조 못 함을 알린다"

# ── root_flag_other_repo ─────────────────────────────────────────────────────
run "$T/lom/work" default-branch --root "$T/trunk/work"
assert_eq "$RC:$OUT" "0:trunk" "root_flag_other_repo: --root 레포의 기본 브랜치(cwd 의 main 이 아니다)"
run "$T/off/work" default-branch --check-remote --root "$T/ren/work"
assert_eq "$RC" "5" "root_flag_other_repo: 대조도 --root 레포의 원격으로(cwd 는 오프라인)"

echo "=== 소비자: merge_check · 상태줄 ==="
# ── merge_check_stops_on_rename ──────────────────────────────────────────────
out="$(cd "$REN" && python3 "$REAL/merge_check.py" run --roadmap docs/superpowers/roadmaps/x/roadmap.md --branch feature/y 2>&1)"; rc=$?
assert_eq "$rc" "3" "merge_check_stops_on_rename: rc 3"
assert_contains "$out" "set-head" "merge_check_stops_on_rename: 맞추는 법"
assert_contains "$out" "원격 기본 브랜치(trunk)" "merge_check_stops_on_rename: 원격 이름"
assert_not_contains "$out" "로드맵을 읽지 못했다" "merge_check_stops_on_rename: 대조에서 멈췄다(로드맵 읽기까지 가지 않는다)"
out="$(cd "$T/off/work" && python3 "$REAL/merge_check.py" run --roadmap docs/superpowers/roadmaps/x/roadmap.md --branch feature/y 2>&1)"
assert_contains "$out" "원격과 대조하지 못했다 — 로컬 기본 브랜치 main 을 썼다" "merge_check 오프라인: 대조 못 함을 알리고 간다"
assert_contains "$out" "로드맵을 읽지 못했다" "merge_check 오프라인: 멈추지 않고 다음(로드맵 읽기)으로 갔다"
out="$(cd "$REN" && python3 "$REAL/merge_check.py" run --no-fetch --roadmap docs/superpowers/roadmaps/x/roadmap.md --branch feature/y 2>&1)"
assert_contains "$out" "원격과 대조하지 못했다 — 로컬 기본 브랜치 main 을 썼다" "merge_check --no-fetch: 대조를 건너뛰되 알린다"
assert_not_contains "$out" "set-head" "merge_check --no-fetch: 원격에 묻지 않는다"

# ── 사유를 그대로 보이는 소비자 — 상태 계산 · 지휘 원장 ──────────────────────
out="$(cd "$T/noorigin" && python3 "$REAL/roadmap_status.py" --json docs/superpowers/roadmaps/x/roadmap.md 2>&1)"
assert_contains "$out" "git remote add origin" "roadmap_status_no_origin: 상태 계산도 원격을 더하라고 한다"
out="$(cd "$T/nohead/work" && python3 "$REAL/roadmap_status.py" --json docs/superpowers/roadmaps/x/roadmap.md 2>&1)"
assert_contains "$out" "git remote set-head origin --auto" "양성 대조: 원격이 있으면 상태 계산은 set-head 를 안내"
out="$(cd "$T/noorigin" && python3 "$REAL/conductor_ledger.py" roadmaps 2>&1)"; rc=$?
assert_eq "$rc" "3" "conductor_ledger_no_origin: rc 3"
assert_contains "$out" "git remote add origin" "conductor_ledger_no_origin: 지휘 원장도 원격을 더하라고 한다"

# ── remote_timeout_is_10 ─────────────────────────────────────────────────────
got="$(python3 -I -c 'import inspect, sys; sys.path.insert(0, sys.argv[1]); import repo_defaults as r
print(r.REMOTE_TIMEOUT, inspect.signature(r.check_remote_head).parameters["timeout"].default)' "$REAL")"
assert_eq "$got" "10.0 10.0" "remote_timeout_is_10: 원격 대조의 시간 상한은 10초"
REALGIT="$(command -v git)"
mkwrap() {  # mkwrap <폴더> <걸리는 인자> <할 일> — 그 인자가 있으면 할 일을 하고, 아니면 진짜 git 으로 간다
  mkdir -p "$1" && printf '#!/bin/sh\nfor a in "$@"; do if [ "$a" = "%s" ]; then %s; break; fi; done\nexec "%s" "$@"\n' \
    "$2" "$3" "$REALGIT" > "$1/git" && chmod +x "$1/git"
}
mkwrap "$T/slow-remote" ls-remote "sleep 7"
t0="$(python3 -I -c 'import time; print(time.time())')"
out="$(cd "$REN" && PATH="$T/slow-remote:$PATH" python3 "$RD" default-branch --check-remote 2>&1)"; rc=$?
took="$(python3 -I -c 'import sys, time; print(int(time.time() - float(sys.argv[1])))' "$t0")"
assert_eq "$rc" "5" "slow_remote: 7초 걸리는 원격도 10초 상한 안이라 대조한다(다르다 → rc 5, 대조 못 함이 아니다)"
[ "$took" -ge 7 ] && ok "양성 대조: 느린 원격 대역이 실제로 7초 이상 걸렸다(${took}초)" || no "느린 원격 대역이 걸리지 않았다(${took}초)"

# ── config_failure_is_not_no_origin ──────────────────────────────────────────
mkwrap "$T/bad-config" remote.origin.url "exit 128"
out="$(cd "$T/nohead/work" && PATH="$T/bad-config:$PATH" python3 "$RD" default-branch 2>&1)"; rc=$?
assert_eq "$rc" "3" "config_failure: origin 설정을 못 읽으면 rc 3"
assert_contains "$out" "origin 원격 설정을 읽지 못했다(git config 종료 코드 128)" "config_failure: 못 읽었다고 말한다"
assert_not_contains "$out" "origin 원격이 없다" "config_failure: 「원격이 없다」로 읽지 않는다"

# ── statusline_stays_in_budget ───────────────────────────────────────────────
mkwrap "$T/slow-config" remote.origin.url "sleep 8"
t0="$(python3 -I -c 'import time; print(time.time())')"
line="$(cd "$T/nohead/work" && PATH="$T/slow-config:$PATH" python3 "$REAL/control_plane.py" statusline </dev/null 2>&1)"
took="$(python3 -I -c 'import sys, time; print(round(time.time() - float(sys.argv[1]), 1))' "$t0")"
python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 4.5 else 1)' "$took" \
  && ok "statusline_stays_in_budget: 기본 브랜치 판정의 느린 git 도 상태줄 시간 예산 안에서 끊는다(${took}초)" \
  || no "statusline_stays_in_budget: 상태줄이 시간 예산을 넘겼다(${took}초)"
assert_contains "$line" "시간 초과" "양성 대조: 느린 config 호출에 실제로 닿아 시간 초과로 끊겼다"

# ── statusline_names_default ─────────────────────────────────────────────────
S="$T/scripts"; mkdir -p "$S"
cp "$REAL/control_plane.py" "$REAL/kill_switch_active.py" "$REAL/conductor_state.py" "$REAL/repo_defaults.py" \
  "$REAL/ledger_marker.py" "$REAL/roadmap_model.py" "$REAL/section6.py" "$REAL/brief_body.py" "$REAL/suite_lock.py" \
  "$REAL/state_path.py" "$S/"
printf '%s\n' 'import json, sys' \
  'print(json.dumps({"roadmap": sys.argv[1], "source": "x", "fetched_at": None, "notice": "", "overlaps": [], "unassigned": [], "orphans": [], "unknown_ids": [], "format_errors": [], "unknown_reasons": [], "exit": 0, "blocks": [{"id": "R1", "title": "하나", "kind": "bundle", "stage": "설계 중", "reason": "r", "task_status": "in_progress", "deps": [], "warnings": [], "notes": []}]}, ensure_ascii=False))' \
  > "$S/roadmap_status.py"
TW="$T/trunk/work"
mkdir -p "$TW/docs/superpowers/roadmaps/rm" && printf 'x\n' > "$TW/docs/superpowers/roadmaps/rm/roadmap.md"
g "$TW" add -A && g "$TW" commit -qm rm && g "$TW" push -q origin trunk && g "$TW" fetch -q origin
line="$(cd "$TW" && python3 "$S/control_plane.py" statusline </dev/null)"
assert_contains "$line" "· 기본 브랜치 trunk · 받은 지 0분(어느 원격 · 브랜치든)" "statusline_names_default: 기본 브랜치 이름과 받은 시각의 범위"
assert_contains "$line" "rm · 설계 1" "양성 대조: 상태줄이 로드맵을 셌다"

finish
