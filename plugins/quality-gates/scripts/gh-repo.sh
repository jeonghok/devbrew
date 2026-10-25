#!/usr/bin/env bash
# gh-repo.sh — qg 가 gh 를 부르기 전에 gh 를 찾고 `-R` 에 넣을 origin 을 정하는 한 곳.
#
# stdout `<host>/<owner>/<repo>` 한 줄 · exit 0. origin URL(`git remote get-url origin`)을 읽는다:
#   https://[user@]host[:port]/owner/repo[.git][/] · ssh://[user@]host[:port]/owner/repo[.git] · [user@]host:owner/repo[.git]
# 호스트는 포트를 떼고 소문자로. upstream 같은 다른 원격은 보지 않는다.
#
# 멈춤(stdout 비움, 사유는 stderr 마지막 줄):
#   exit 4 — gh 가 없다(origin 보다 먼저 본다)
#   exit 3 — origin 이 없거나 URL 에서 호스트 · owner · repo 를 뽑지 못했다 · SSH 꼴 호스트를 `ssh -G` 로 풀지 못했다
# SSH 꼴(ssh:// · scp 꼴)의 호스트는 ~/.ssh/config 별칭일 수 있어 `ssh -G` 의 hostname 으로 바꾼다(*.github.com → github.com).
# GH_REPO · GH_HOST 가 설정돼 있으면 stderr 에 알림 한 줄씩(그래도 결과는 origin 이다).
#
# 사용 (리포 안에서): gh-repo.sh
set -u

notice() {  # notice <이름> <값>
  [ -z "$2" ] || printf '%s\n' "${1} 이 설정돼 있다(${2}) — devbrew 는 -R 로 origin 을 명시해 쓴다" >&2
}
notice GH_REPO "${GH_REPO:-}"
notice GH_HOST "${GH_HOST:-}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh 가 없다 — https://cli.github.com 에서 설치한다" >&2
  exit 4
fi

stop_slug() {
  echo "origin URL 에서 호스트 · owner · repo 를 뽑지 못했다 — git remote get-url origin 을 확인한다" >&2
  exit 3
}

url="$(git remote get-url origin 2>/dev/null)" || stop_slug
# 앞뒤 공백을 뗀다.
url="${url#"${url%%[![:space:]]*}"}"
url="${url%"${url##*[![:space:]]}"}"

is_ssh=1
case "$url" in
  *://*)
    scheme="$(printf '%s' "${url%%://*}" | LC_ALL=C tr 'A-Z' 'a-z')"
    case "$scheme" in https|http) is_ssh=0 ;; ssh) ;; *) stop_slug ;; esac
    rest="${url#*://}"
    case "$rest" in */*) ;; *) stop_slug ;; esac
    hostport="${rest%%/*}"
    path="${rest#*/}"
    host="${hostport##*@}"
    host="${host%%:*}"
    ;;
  *:*)
    hostport="${url%%:*}"
    path="${url#*:}"
    case "$hostport" in */*|*\\*) stop_slug ;; esac
    host="${hostport##*@}"
    ;;
  *) stop_slug ;;
esac

host="$(printf '%s' "$host" | LC_ALL=C tr 'A-Z' 'a-z')"
# 호스트 글자(영숫자 · '.' · '-')만, '-' 로 시작하지 않게 — ssh 인자로 넘어가도 옵션이 되지 못한다.
case "$host" in ''|-*|*[!a-z0-9.-]*) stop_slug ;; esac

# SSH 꼴(ssh:// · scp 꼴)은 ~/.ssh/config 의 별칭일 수 있다 — gh 는 -R 에 ssh 설정을 쓰지 않으므로
# `ssh -G` 의 hostname 으로 푼다. *.github.com(ssh.github.com 443 우회 등)은 gh 처럼 github.com.
if [ "$is_ssh" = 1 ]; then
  if ! command -v ssh >/dev/null 2>&1; then
    echo "origin 이 SSH 꼴(${host})인데 ssh 가 없어 실제 호스트로 풀지 못했다 — origin 을 https 꼴로 바꾸거나 ssh 를 설치한다" >&2
    exit 3
  fi
  resolved=""
  if sshcfg="$(ssh -G -- "$host" </dev/null 2>/dev/null)"; then
    while read -r k v _; do
      [ "$k" = hostname ] && { resolved="$v"; break; }
    done <<EOF
$sshcfg
EOF
  fi
  resolved="$(printf '%s' "$resolved" | LC_ALL=C tr 'A-Z' 'a-z')"
  case "$resolved" in
    ''|-*|*[!a-z0-9.-]*)
      echo "origin 의 SSH 호스트 ${host} 를 실제 호스트로 풀지 못했다 — ssh -G -- ${host} 의 hostname 을 확인한다" >&2
      exit 3 ;;
  esac
  case "$resolved" in *.github.com) resolved=github.com ;; esac
  host="$resolved"
fi
while :; do case "$path" in /*) path="${path#/}" ;; *) break ;; esac; done
while :; do case "$path" in */) path="${path%/}" ;; *) break ;; esac; done
case "$path" in *.git) path="${path%.git}" ;; esac
case "$path" in
  */*/*|/*|*/) stop_slug ;;
  ?*/?*) owner="${path%%/*}"; repo="${path#*/}" ;;
  *) stop_slug ;;
esac
[ -n "$host" ] && [ -n "$owner" ] && [ -n "$repo" ] || stop_slug
printf '%s/%s/%s\n' "$host" "$owner" "$repo"
