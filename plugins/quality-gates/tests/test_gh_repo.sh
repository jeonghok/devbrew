#!/usr/bin/env bash
# gh-repo.sh — gh 찾기와 `-R` 에 넣을 origin(<host>/<owner>/<repo>)을 정하는 한 곳(R8 AC16 · AC20 · AC29 fork).
# URL 판독은 spec-distill gh_repo.py 와 같은 규칙이다 — 같은 일곱 꼴 · 같은 못 뽑는 꼴.
# 픽스처는 임시 레포 + PATH 앞의 가짜 gh(불리면 인자를 파일에 적는다 — gh-repo.sh 는 gh 를 부르지 않는다).
# Run (리포 루트에서): bash plugins/quality-gates/tests/test_gh_repo.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
GR="$ROOT/plugins/quality-gates/scripts/gh-repo.sh"
BASH_BIN="$(command -v bash)" || exit 1
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
printf '%s\n' "$*" >> "$FAKE_GH_ARGS"
FAKE
chmod +x "$T/bin/gh" || exit 1
for c in git tr; do ln -s "$(command -v "$c")" "$T/nogh/$c" || exit 1; done
export FAKE_GH_ARGS="$T/args"
: > "$FAKE_GH_ARGS"
FAKEPATH="$T/bin:$PATH"

mkrepo() {  # mkrepo <이름> <origin URL|-> [<upstream URL>]
  local d="$T/$1"
  rm -rf "$d"
  git init -q "$d" || return 1
  [ "$2" = "-" ] || git -C "$d" remote add origin "$2" || return 1
  [ -z "${3:-}" ] || git -C "$d" remote add upstream "$3" || return 1
}
slug() {  # slug <레포> <PATH> → OUT · ERR · RC
  OUT="$(cd "$T/$1" && PATH="$2" "$BASH_BIN" "$GR" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"
}

STOP="origin URL 에서 호스트 · owner · repo 를 뽑지 못했다 — git remote get-url origin 을 확인한다"

# ── 같은 일곱 꼴 → github.com/me/r ──────────────────────────────────────────
for url in "https://github.com/me/r.git" "https://user@github.com/me/r.git" "https://github.com:443/me/r.git" \
           "https://github.com/me/r" "ssh://git@github.com/me/r.git" "git@github.com:me/r.git" "https://github.com/me/r/"; do
  mkrepo u "$url" || { no "픽스처 $url"; finish; exit 1; }
  slug u "$FAKEPATH"
  assert_eq "$RC:$OUT" "0:github.com/me/r" "URL ${url} → github.com/me/r"
done

# ── 호스트 · 포트 · 대소문자 ─────────────────────────────────────────────────
mkrepo u "ssh://git@GHE.Example.com:2222/o/r.git" || { no "픽스처 ssh 포트"; finish; exit 1; }
slug u "$FAKEPATH"
assert_eq "$RC:$OUT" "0:ghe.example.com/o/r" "ssh 포트는 떼고 호스트는 소문자"
mkrepo ghe "git@ghe.example.com:o/r.git" || { no "픽스처 ghe"; finish; exit 1; }
slug ghe "$FAKEPATH"
assert_eq "$RC:$OUT" "0:ghe.example.com/o/r" "scp 꼴 GHE 호스트를 보존한다"
mkrepo up "https://github.com/up/r" || { no "픽스처 up"; finish; exit 1; }
slug up "$FAKEPATH"
assert_eq "$RC:$OUT" "0:github.com/up/r" "양성 대조: 다른 owner 는 다른 값"

# ── fork 의 upstream 은 무시한다 ─────────────────────────────────────────────
mkrepo fork https://github.com/me/r https://github.com/up/r || { no "픽스처 fork"; finish; exit 1; }
slug fork "$FAKEPATH"
assert_eq "$RC:$OUT" "0:github.com/me/r" "upstream 원격이 있어도 origin(github.com/me/r)이다"
assert_eq "$ERR" "" "알릴 것이 없으면 stderr 가 비었다"
assert_eq "$(cat "$FAKE_GH_ARGS")" "" "gh-repo.sh 는 gh 를 찾기만 하고 부르지 않는다"

# ── GH_REPO · GH_HOST 알림 ───────────────────────────────────────────────────
OUT="$(cd "$T/fork" && GH_REPO=up/r GH_HOST=other.example PATH="$FAKEPATH" "$BASH_BIN" "$GR" 2>"$T/err")"; RC=$?
ERR="$(cat "$T/err")"
assert_eq "$RC:$OUT" "0:github.com/me/r" "GH_REPO 가 있어도 결과는 origin 이다"
assert_contains "$ERR" "GH_REPO 이 설정돼 있다(up/r) — devbrew 는 -R 로 origin 을 명시해 쓴다" "GH_REPO 를 알린다"
assert_contains "$ERR" "GH_HOST 이 설정돼 있다(other.example) — devbrew 는 -R 로 origin 을 명시해 쓴다" "GH_HOST 를 알린다"

# ── insteadOf 로 바뀐 URL 을 읽는다 ──────────────────────────────────────────
mkrepo alias gh:me/r || { no "픽스처 alias"; finish; exit 1; }
git -C "$T/alias" config url.git@github.com:.insteadOf gh: || { no "픽스처 alias insteadOf"; finish; exit 1; }
slug alias "$FAKEPATH"
assert_eq "$RC:$OUT" "0:github.com/me/r" "insteadOf 로 바뀐 origin URL 을 읽는다"

# ── 못 뽑는 URL · origin 없음 → rc 3 ─────────────────────────────────────────
for url in "file:///x" "/srv/git/r.git" "https://github.com/r" "../r.git" "https://github.com/a/b/c" \
           "https:///me/r" "file://host/o/r" "git://github.com/me/r" "https://github.com/me//r"; do
  mkrepo bad "$url" || { no "픽스처 $url"; finish; exit 1; }
  slug bad "$FAKEPATH"
  assert_eq "$RC:$OUT" "3:" "못 뽑는 URL ${url} → rc 3 · stdout 비움"
  assert_eq "$(printf '%s\n' "$ERR" | tail -n 1)" "$STOP" "못 뽑는 URL ${url} → 사유"
done
mkrepo bare - || { no "픽스처 bare"; finish; exit 1; }
slug bare "$FAKEPATH"
assert_eq "$RC:$OUT" "3:" "origin 이 없으면 rc 3 · stdout 비움"
assert_eq "$ERR" "$STOP" "origin 이 없을 때의 사유"

# ── gh 없음 → rc 4(origin 보다 먼저) ──────────────────────────────────────────
if PATH="$T/nogh" command -v gh >/dev/null 2>&1; then
  no "전제: gh 없는 PATH 를 만들지 못했다"
else
  slug fork "$T/nogh"
  assert_eq "$RC:$OUT" "4:" "gh 가 없으면 rc 4 · stdout 비움"
  assert_eq "$ERR" "gh 가 없다 — https://cli.github.com 에서 설치한다" "gh 없음 사유에 설치 주소"
  slug bare "$T/nogh"
  assert_eq "$RC" "4" "gh 가 없으면 origin 이 없어도 rc 4 를 먼저 낸다"
fi

finish
