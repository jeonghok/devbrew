#!/usr/bin/env bash
# gh_repo.py 의 gh 몫 — 모든 gh 호출이 origin 에서 도출한 -R <host>/<owner>/<repo> 를 쓰고,
# gh 없음 · 인증 · 비 GitHub · origin 없음에서 멈춘다(R8 AC16 · AC20 · AC23a · AC29 fork).
# 픽스처는 임시 레포 + PATH 앞의 가짜 gh(받은 인자를 파일에 적는다). 실제 gh 로 나가지 않는다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_gh_repo.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SCRIPTS="$ROOT/plugins/spec-distill/scripts"
GR="$SCRIPTS/gh_repo.py"
PY="$(python3 -I -c 'import sys; print(sys.executable)')" || exit 1
[ -n "$PY" ] && [ -x "$PY" ] || exit 1
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
T="$(cd "$T" && pwd -P)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GH_REPO GH_HOST

mkdir -p "$T/bin" "$T/nogh" || exit 1
cat > "$T/bin/gh" <<'FAKE'
#!/bin/sh
: > "$FAKE_GH_ARGS"
for a in "$@"; do printf '%s\n' "$a" >> "$FAKE_GH_ARGS"; done
printf 'env:%s:%s:%s\n' "${GH_PROMPT_DISABLED:-}" "${NO_COLOR:-}" "${GH_NO_UPDATE_NOTIFIER:-}" >> "$FAKE_GH_ARGS"
case "${FAKE_GH_MODE:-ok}" in
  ok) printf '[]\n' ;;
  auth) printf 'To get started with GitHub CLI, please run:  gh auth login\n' >&2; exit 4 ;;
  unresolved) printf 'could not resolve host gitlab.com\n' >&2; exit 1 ;;
esac
FAKE
chmod +x "$T/bin/gh" || exit 1
export FAKE_GH_ARGS="$T/args"
FAKEPATH="$T/bin:$PATH"

mkrepo() {  # mkrepo <이름> <origin URL|-> [<upstream URL>]
  local d="$T/$1"
  git init -q "$d" || return 1
  [ "$2" = "-" ] || git -C "$d" remote add origin "$2" || return 1
  [ -z "${3:-}" ] || git -C "$d" remote add upstream "$3" || return 1
}
call() {  # call <cwd> <PATH> — gh_json(cwd, ["pr","list"]) → OUT · ERR · RC · ARGS
  : > "$FAKE_GH_ARGS"
  OUT="$(PATH="$2" "$PY" -I -c '
import sys
sys.path.insert(0, sys.argv[1])
import gh_repo
for n in gh_repo.env_notices():
    print("NOTICE:" + n, file=sys.stderr)
try:
    print(gh_repo.gh_json(sys.argv[2], ["pr", "list"]))
except gh_repo.GhStop as exc:
    print("STOP:" + str(exc), file=sys.stderr)
    sys.exit(5)
' "$SCRIPTS" "$1" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"
  ARGS="$(tr '\n' ' ' < "$FAKE_GH_ARGS")"
}

# ── fork_with_upstream ───────────────────────────────────────────────────────
mkrepo fork https://github.com/me/r https://github.com/up/r || { no "픽스처 fork"; finish; exit 1; }
call "$T/fork" "$FAKEPATH"
assert_eq "$RC:$OUT" "0:[]" "fork: gh_json 이 가짜 gh 의 JSON 을 돌려준다"
assert_contains "$ARGS" "pr list -R github.com/me/r " "fork: upstream 이 있어도 -R 이 origin(github.com/me/r)이다"
assert_not_contains "$ARGS" "up/r" "fork: upstream 레포를 넘기지 않는다"
assert_contains "$ARGS" "env:1:1:1" "gh 를 프롬프트 · 색 · 업데이트 알림 없이 부른다"
assert_not_contains "$ERR" "NOTICE:" "GH_REPO · GH_HOST 가 없으면 알림이 없다"

# ── ghe_host ─────────────────────────────────────────────────────────────────
mkrepo ghe git@ghe.example.com:o/r.git || { no "픽스처 ghe"; finish; exit 1; }
call "$T/ghe" "$FAKEPATH"
assert_eq "$RC" "0" "ghe: 성공"
assert_contains "$ARGS" "-R ghe.example.com/o/r " "ghe: -R 이 호스트를 보존한다"

# ── gh_repo_env ──────────────────────────────────────────────────────────────
GH_REPO=up/r call "$T/fork" "$FAKEPATH"
assert_contains "$ERR" "NOTICE:GH_REPO 이 설정돼 있다(up/r) — devbrew 는 -R 로 origin 을 명시해 쓴다" \
  "GH_REPO 가 설정돼 있으면 알린다"
assert_contains "$ARGS" "-R github.com/me/r " "GH_REPO 가 있어도 -R 은 origin 이다"

# ── no_gh ────────────────────────────────────────────────────────────────────
call "$T/fork" "$T/nogh"
assert_eq "$RC" "5" "gh 가 없으면 멈춘다"
assert_contains "$ERR" "STOP:gh 가 없다 — devbrew 는 gh 를 필수로 쓴다. https://cli.github.com 에서 설치한다" \
  "gh 없음 문장에 설치 주소(cli.github.com)"
mkrepo bare - || { no "픽스처 bare"; finish; exit 1; }
call "$T/bare" "$T/nogh"
assert_contains "$ERR" "STOP:gh 가 없다" "gh 가 없으면 origin 이 없어도 「gh 가 없다」를 먼저 낸다"

# ── auth_fail ────────────────────────────────────────────────────────────────
FAKE_GH_MODE=auth call "$T/fork" "$FAKEPATH"
assert_eq "$RC" "5" "인증 실패에서 멈춘다"
assert_contains "$ERR" "STOP:gh 인증이 안 됐다 — gh auth login --hostname github.com 를 돈다" \
  "인증 실패 문장에 gh auth login --hostname github.com"

# ── non_github ───────────────────────────────────────────────────────────────
mkrepo lab https://gitlab.com/o/r || { no "픽스처 lab"; finish; exit 1; }
FAKE_GH_MODE=unresolved call "$T/lab" "$FAKEPATH"
assert_eq "$RC" "5" "비 GitHub 에서 멈춘다"
assert_contains "$ARGS" "-R gitlab.com/o/r " "비 GitHub: -R 은 origin 그대로"
assert_contains "$ERR" "STOP:gh 가 origin(gitlab.com/o/r)을 다루지 못한다 — devbrew 는 origin 이 GitHub 인 레포만 지원한다" \
  "비 GitHub: 「GitHub 인 레포만」"

# ── no_origin · slug CLI ─────────────────────────────────────────────────────
OUT="$(cd "$T/bare" && "$PY" "$GR" slug 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
assert_eq "$RC:$OUT" "3:" "origin 이 없으면 slug 가 rc 3 · stdout 비움"
assert_contains "$ERR" "origin URL 에서 호스트 · owner · repo 를 뽑지 못했다" "slug rc 3 의 사유"
call "$T/bare" "$FAKEPATH"
assert_eq "$RC" "5" "origin 이 없으면 gh_json 도 멈춘다"
assert_eq "$ARGS" "" "origin 이 없으면 gh 를 부르지 않는다"
OUT="$(cd "$T/fork" && "$PY" "$GR" slug 2>"$T/err")"; RC=$?
assert_eq "$RC:$OUT" "0:github.com/me/r" "양성 대조: fork 에서 slug 는 origin 이다"
OUT="$(cd "$T/ghe" && GH_HOST=other.example "$PY" "$GR" slug 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
assert_eq "$RC:$OUT" "0:ghe.example.com/o/r" "양성 대조: ghe 에서 slug 는 호스트를 보존한다"
assert_contains "$ERR" "GH_HOST 이 설정돼 있다(other.example)" "slug 도 GH_HOST 를 알린다"

finish
