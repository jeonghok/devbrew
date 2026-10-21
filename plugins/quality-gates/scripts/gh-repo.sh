#!/usr/bin/env bash
# gh-repo.sh — qg 가 gh 를 부르기 전에 gh 를 찾고 `-R` 에 넣을 origin 을 정하는 한 곳.
#
# stdout `<host>/<owner>/<repo>` 한 줄 · exit 0. origin URL(`git remote get-url origin`)을 읽는다:
#   https://[user@]host[:port]/owner/repo[.git][/] · ssh://[user@]host[:port]/owner/repo[.git] · [user@]host:owner/repo[.git]
# 호스트는 포트를 떼고 소문자로. upstream 같은 다른 원격은 보지 않는다.
#
# 멈춤(stdout 비움, 사유는 stderr 마지막 줄):
#   exit 4 — gh 가 없다(origin 보다 먼저 본다)
#   exit 3 — origin 이 없거나 URL 에서 호스트 · owner · repo 를 뽑지 못했다
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

case "$url" in
  *://*)
    scheme="$(printf '%s' "${url%%://*}" | LC_ALL=C tr 'A-Z' 'a-z')"
    case "$scheme" in https|http|ssh) ;; *) stop_slug ;; esac
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
