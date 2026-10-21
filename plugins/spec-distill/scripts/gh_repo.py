#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gh_repo.py — spec-distill 의 gh 호출을 모은 한 곳.

모든 호출은 `-R <host>/<owner>/<repo>`(origin URL 에서 호스트까지 도출)를 붙인다. 멈춤은 `GhStop`
하나로 내고, 그 메시지가 사람에게 보일 한 줄이다:
  - gh 없음 → 설치 주소
  - origin 이 없거나 URL 을 못 읽음 → `git remote get-url origin` 확인
  - 인증 실패 → `gh auth login --hostname <host>`
  - 레포를 못 찾음 · 호스트를 모름 → origin 이 GitHub 인 레포만 지원
  - 그 밖 → rc 와 stderr 첫 줄

CLI: `gh_repo.py slug` — stdout `<host>/<owner>/<repo>` · rc 0. 못 뽑으면 rc 3 + 사유(stderr).
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys

STOP_SLUG = "origin URL 에서 호스트 · owner · repo 를 뽑지 못했다 — git remote get-url origin 을 확인한다"
STOP_NO_GH = "gh 가 없다 — devbrew 는 gh 를 필수로 쓴다. https://cli.github.com 에서 설치한다"
ENV_NAMES = ("GH_REPO", "GH_HOST")
AUTH_MARKS = ("auth login", "not logged", "authentication", "bad credentials", "http 401")
UNKNOWN_MARKS = ("could not resolve", "not found", "http 404", "no such host", "known github host",
                 "unknown host")
PR_FIELDS = ("number", "state", "headRefName", "headRefOid", "isCrossRepository", "baseRefName", "mergeCommit")


class GhStop(RuntimeError):
    """사람에게 보일 한 줄을 메시지로 갖는 멈춤."""


def _split_git(path: str):
    path = path.strip("/")
    if path.endswith(".git"):
        path = path[:-4]
    parts = path.split("/")
    if len(parts) != 2 or not all(parts):
        return None
    return parts[0], parts[1]


def parse_origin_url(url: str):
    """(host, owner, repo) 또는 None. https · ssh:// · scp 꼴(`[user@]host:owner/repo`)만 읽는다."""
    u = (url or "").strip()
    if "://" in u:
        scheme, rest = u.split("://", 1)
        if scheme.lower() not in ("https", "http", "ssh"):
            return None
        hostport, sep, path = rest.partition("/")
        if not sep:
            return None
        host = hostport.rpartition("@")[2].partition(":")[0]
    else:
        hostport, sep, path = u.partition(":")
        if not sep or "/" in hostport or "\\" in hostport:
            return None
        host = hostport.rpartition("@")[2]
    host = host.lower()
    names = _split_git(path)
    if not host or names is None:
        return None
    return host, names[0], names[1]


def slug_from_url(url: str) -> str:
    got = parse_origin_url(url)
    if got is None:
        raise GhStop(STOP_SLUG)
    return "/".join(got)


def origin_slug(cwd: str):
    """(host, owner, repo). origin 이 없거나 URL 을 못 읽으면 GhStop."""
    try:
        p = subprocess.run(["git", "-C", str(cwd), "config", "--get", "remote.origin.url"],
                           capture_output=True, encoding="utf-8", errors="replace", timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        raise GhStop(STOP_SLUG)
    got = parse_origin_url(p.stdout) if p.returncode == 0 else None
    if got is None:
        raise GhStop(STOP_SLUG)
    return got


def gh_exe() -> str:
    exe = shutil.which("gh")
    if not exe:
        raise GhStop(STOP_NO_GH)
    return exe


def env_notices(env=None) -> list:
    env = os.environ if env is None else env
    return ["%s 이 설정돼 있다(%s) — devbrew 는 -R 로 origin 을 명시해 쓴다" % (name, env[name])
            for name in ENV_NAMES if env.get(name)]


def stop_for(rc: int, stderr: str, host: str, slug: str) -> str:
    """gh 가 rc≠0 으로 끝났을 때 사람에게 보일 한 줄."""
    low = (stderr or "").lower()
    if any(m in low for m in AUTH_MARKS):
        return "gh 인증이 안 됐다 — gh auth login --hostname %s 를 돈다" % host
    if any(m in low for m in UNKNOWN_MARKS):
        return "gh 가 origin(%s)을 다루지 못한다 — devbrew 는 origin 이 GitHub 인 레포만 지원한다" % slug
    first = next((ln.strip() for ln in (stderr or "").splitlines() if ln.strip()), "")
    return "gh 실패(rc %d): %s" % (rc, first)


def gh_json(cwd: str, args: list, timeout: float = 15.0):
    """`gh <args> -R <host>/<owner>/<repo>` 의 JSON 출력. 실패는 GhStop."""
    exe = gh_exe()
    host, owner, repo = origin_slug(cwd)
    slug = "%s/%s/%s" % (host, owner, repo)
    env = dict(os.environ, GH_PROMPT_DISABLED="1", NO_COLOR="1", GH_NO_UPDATE_NOTIFIER="1")
    try:
        p = subprocess.run([exe, *args, "-R", slug], cwd=str(cwd), capture_output=True, encoding="utf-8",
                           errors="replace", env=env, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise GhStop("gh 가 %g초 안에 끝나지 않았다(%s) — 네트워크를 확인하고 다시 돈다" % (timeout, slug))
    except OSError as exc:
        raise GhStop("gh 를 실행하지 못했다(%s) — gh 설치를 확인한다" % exc)
    if p.returncode != 0:
        raise GhStop(stop_for(p.returncode, p.stderr, host, slug))
    try:
        return json.loads(p.stdout)
    except ValueError:
        first = next((ln.strip() for ln in p.stdout.splitlines() if ln.strip()), "")
        raise GhStop("gh 출력이 JSON 이 아니다(%s): %s" % (slug, first[:160]))


def pr_list(cwd: str, branch: str, limit: int = 100):
    """(PR 목록, 한도에 닿았는가). 모양이 다르면 GhStop."""
    items = gh_json(cwd, ["pr", "list", "--state", "all", "--head", branch, "--json", ",".join(PR_FIELDS),
                          "--limit", str(limit)])
    if not isinstance(items, list) or not all(isinstance(it, dict) and all(k in it for k in PR_FIELDS)
                                              for it in items):
        raise GhStop("gh pr list 출력 모양이 다르다(브랜치 %s) — gh 판을 확인한다" % branch)
    return items, len(items) >= limit


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="gh_repo.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("slug", help="origin 의 <host>/<owner>/<repo>")
    ap.parse_args(argv)
    for line in env_notices():
        print("[spec-distill] " + line, file=sys.stderr)
    try:
        host, owner, repo = origin_slug(os.getcwd())
    except GhStop as exc:
        print("[spec-distill] " + str(exc), file=sys.stderr)
        return 3
    print("%s/%s/%s" % (host, owner, repo))
    return 0


if __name__ == "__main__":
    sys.exit(main())
