#!/usr/bin/env bash
# gh-repo.sh — gh 찾기와 `-R` 에 넣을 origin(<host>/<owner>/<repo>)을 정하는 한 곳(R8 AC16 · AC20 · AC29 fork).
# URL 꼴(일곱 꼴 · 못 뽑는 꼴)은 spec-distill gh_repo.py 와 같다. SSH 별칭 풀기 · 호스트 글자 검사는 이 스크립트만 한다.
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
# 가짜 ssh: `ssh -G -- <호스트>` 에 ssh 설정을 푼 결과를 낸다(사용자의 ~/.ssh/config 와 무관하게).
cat > "$T/bin/ssh" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >> "$FAKE_SSH_ARGS"
for a in "$@"; do h="$a"; done
case "$h" in
  github-work|github_work) printf 'user git\nhostname github.com\nport 22\n' ;;
  muser) case "$*" in *'-l git '*) printf 'user git\nhostname github.com\nport 22\n' ;; *) printf 'user x\nhostname muser\nport 22\n' ;; esac ;;
  github.com) printf 'user git\nhostname ssh-proxy.corp\nport 22\n' ;;
  gh443) printf 'user git\nhostname ssh.github.com\nport 443\n' ;;
  ghe.corp) printf 'user git\nhostname 10.0.0.5\nport 22\n' ;;
  noresolve) echo "ssh: Could not resolve" >&2; exit 255 ;;
  *) printf 'user git\nhostname %s\nport 22\n' "$h" ;;
esac
FAKE
chmod +x "$T/bin/ssh" || exit 1
for c in git tr; do ln -s "$(command -v "$c")" "$T/nogh/$c" || exit 1; done
mkdir -p "$T/nossh" || exit 1
for c in git tr; do ln -s "$(command -v "$c")" "$T/nossh/$c" || exit 1; done
ln -s "$T/bin/gh" "$T/nossh/gh" || exit 1
export FAKE_GH_ARGS="$T/args" FAKE_SSH_ARGS="$T/sshargs"
# gh 설정은 빈 폴더 — 사용자의 hosts.yml 과 무관하게(아는 호스트 경우는 아래에서 이 폴더에 쓴다).
export GH_CONFIG_DIR="$T/ghcfg"
mkdir -p "$GH_CONFIG_DIR" || exit 1
: > "$FAKE_GH_ARGS"
: > "$FAKE_SSH_ARGS"
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

# ── SSH 설정의 별칭 호스트는 ssh -G 의 hostname 으로 푼다 ────────────────────
for url in "git@github-work:o/r.git" "ssh://git@github-work/o/r.git" "ssh://git@github-work:22/o/r.git"; do
  mkrepo sa "$url" || { no "픽스처 $url"; finish; exit 1; }
  : > "$FAKE_SSH_ARGS"
  slug sa "$FAKEPATH"
  assert_eq "$RC:$OUT" "0:github.com/o/r" "SSH 별칭 ${url} → 실제 호스트 github.com/o/r"
  assert_eq "$(cat "$FAKE_SSH_ARGS")" "-G -l git -- github-work" "SSH 별칭 ${url} → ssh -G -l <사용자> -- <별칭> 으로 푼다"
done
mkrepo sus "git@github_work:o/r.git" || { no "픽스처 밑줄 별칭"; finish; exit 1; }
: > "$FAKE_SSH_ARGS"
slug sus "$FAKEPATH"
assert_eq "$RC:$OUT:$(cat "$FAKE_SSH_ARGS")" "0:github.com/o/r:-G -l git -- github_work" "밑줄이 든 SSH 별칭도 ssh -G 로 푼다"
mkrepo spx "git@github.com:o/r.git" || { no "픽스처 github.com 프록시"; finish; exit 1; }
: > "$FAKE_SSH_ARGS"
slug spx "$FAKEPATH"
assert_eq "$RC:$OUT:$(cat "$FAKE_SSH_ARGS")" "0:github.com/o/r:" "github.com 은 풀지 않는다 — ssh 설정의 프록시 HostName 이 gh 호스트가 되지 않는다"
for url in "git@muser:o/r.git" "ssh://git@muser/o/r.git"; do
  mkrepo smu "$url" || { no "픽스처 $url"; finish; exit 1; }
  : > "$FAKE_SSH_ARGS"
  slug smu "$FAKEPATH"
  assert_eq "$RC:$OUT:$(cat "$FAKE_SSH_ARGS")" "0:github.com/o/r:-G -l git -- muser" "${url}: origin 의 사용자 이름을 ssh -G -l 로 넘긴다(Match user 규칙)"
done
mkrepo sun "muser:o/r.git" || { no "픽스처 사용자 없는 별칭"; finish; exit 1; }
: > "$FAKE_SSH_ARGS"
slug sun "$FAKEPATH"
assert_eq "$(cat "$FAKE_SSH_ARGS")" "-G -- muser" "사용자 이름이 없으면 -l 을 넘기지 않는다(양성 짝)"
mkrepo sbu "ssh://-oProxyCommand=x@muser/o/r.git" || { no "픽스처 나쁜 사용자"; finish; exit 1; }
: > "$FAKE_SSH_ARGS"
slug sbu "$FAKEPATH"
assert_eq "$RC:$OUT:$(cat "$FAKE_SSH_ARGS")" "3::" "'-' 로 시작하는 사용자 이름은 ssh 에 넘기지 않는다"
mkrepo htok "https://x-access-token:abc@github.com/o/r.git" || { no "픽스처 https 자격"; finish; exit 1; }
slug htok "$FAKEPATH"
assert_eq "$RC:$OUT" "0:github.com/o/r" "https 꼴의 사용자 칸(토큰)은 검사하지 않는다"
# gh 가 아는 호스트(hosts.yml 최상위 키)는 ssh 설정이 HostName 을 IP 로 돌려도 그대로 — gh 의 호스트는 그것이다.
mkrepo ghe "git@ghe.corp:o/r.git" || { no "픽스처 ghe.corp"; finish; exit 1; }
: > "$FAKE_SSH_ARGS"
slug ghe "$FAKEPATH"
assert_eq "$RC:$OUT" "0:10.0.0.5/o/r" "gh 가 모르는 SSH 호스트는 ssh 설정으로 푼다(양성 짝)"
assert_contains "$ERR" "origin 의 SSH 호스트 ghe.corp 를 ssh 설정(ssh -G)으로 10.0.0.5 로 풀었다" "호스트를 바꾸면 stderr 에 알린다"
printf 'github.com:\n    user: me\n"ghe.corp":\n    git_protocol: ssh\n' > "$GH_CONFIG_DIR/hosts.yml"
: > "$FAKE_SSH_ARGS"
slug ghe "$FAKEPATH"
assert_eq "$RC:$OUT:$(cat "$FAKE_SSH_ARGS")" "0:ghe.corp/o/r:" "gh 가 아는 호스트(hosts.yml)는 ssh 설정으로 바꾸지 않는다(ssh 호출 0)"
assert_eq "$ERR" "" "gh 가 아는 호스트면 바꿈 알림이 없다"
mkrepo ghw "git@github-work:o/r.git" || { no "픽스처 github-work"; finish; exit 1; }
slug ghw "$FAKEPATH"
assert_eq "$RC:$OUT" "0:github.com/o/r" "hosts.yml 에 없는 별칭은 그대로 푼다"
rm -f "$GH_CONFIG_DIR/hosts.yml"
mkrepo s443 "git@gh443:o/r.git" || { no "픽스처 gh443"; finish; exit 1; }
slug s443 "$FAKEPATH"
assert_eq "$RC:$OUT" "0:github.com/o/r" "ssh.github.com(443 우회)은 gh 처럼 github.com 으로"
mkrepo snr "git@noresolve:o/r.git" || { no "픽스처 noresolve"; finish; exit 1; }
slug snr "$FAKEPATH"
assert_eq "$RC:$OUT" "3:" "ssh -G 가 실패하면 rc 3 · stdout 비움"
assert_contains "$(printf '%s\n' "$ERR" | tail -n 1)" "ssh -G -- noresolve" "푸지 못한 별칭과 확인할 명령을 알린다"
slug sa "$T/nossh"
assert_eq "$RC:$OUT" "3:" "ssh 가 없으면 SSH 꼴 origin 은 rc 3 · stdout 비움"
assert_contains "$(printf '%s\n' "$ERR" | tail -n 1)" "ssh 가 없어" "ssh 없음을 알린다"
mkrepo hs "https://github-work/o/r" || { no "픽스처 https 별칭"; finish; exit 1; }
: > "$FAKE_SSH_ARGS"
slug hs "$FAKEPATH"
assert_eq "$RC:$OUT:$(cat "$FAKE_SSH_ARGS")" "0:github-work/o/r:" "https 꼴은 ssh 설정을 보지 않는다"
# 옵션 주입: '-' 로 시작하거나 호스트 글자가 아닌 것은 ssh 에 넘기지 않는다
for url in "-oProxyCommand=touch:o/r" "git@-oProxyCommand=x:o/r" "ssh://git@-oProxyCommand=x/o/r" "git@a%b:o/r" "git@-oproxycommand:o/r" "ssh://-oproxycommand/o/r"; do
  mkrepo inj - || { no "픽스처 inj"; finish; exit 1; }
  git -C "$T/inj" config remote.origin.url "$url" || { no "픽스처 $url"; finish; exit 1; }
  : > "$FAKE_SSH_ARGS"
  slug inj "$FAKEPATH"
  assert_eq "$RC:$OUT:$(cat "$FAKE_SSH_ARGS")" "3::" "호스트 글자가 아닌 ${url} → rc 3 · ssh 를 부르지 않는다"
done

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
