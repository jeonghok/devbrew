#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gh_repo.py — spec-distill 의 gh 호출을 모은 한 곳.

모든 호출은 `-R <host>/<owner>/<repo>`(origin URL 에서 호스트까지 도출)를 붙인다 — `-R` 을 받지 않는
`repo view` 만 같은 값을 인자로 준다. 멈춤은 `GhStop` 하나로 내고, 그 메시지가 사람에게 보일 한 줄이다:
  - gh 없음 → 설치 주소
  - origin 이 없거나 URL 을 못 읽음 → `git remote get-url origin` 확인
  - 인증 실패 → `gh auth login --hostname <host>`
  - 레포를 못 찾음(could not resolve to a repository) · GitHub 이 아닌 GraphQL(no such type pullrequest)
    → origin 이 GitHub 인 레포만 지원 · 비공개면 접근 권한
  - 그 밖 → rc 와 stderr 첫 줄

PR 번호 하나 묻기(`pr_view`)와 사람이 준 PR 참조(URL · `#N` · `N`) 읽기(`parse_pr_ref`)도 여기 있다.

CLI (모두 `--root <레포 경로>` 를 받는다 — 없으면 지금 폴더. 멈춤은 rc 3 + 사유(stderr)):
  - `slug` — stdout `<host>/<owner>/<repo>`
  - `pr-number <PR 주소>` — 주소의 레포가 origin 일 때만 stdout 번호
  - `pr-open --head <브랜치> --base <브랜치>` — 그 레포 안 브랜치의 열린 PR 주소(없으면 빈 줄)
  - `pr-create --head <브랜치> --base <브랜치> --title <제목> --body-file <파일>` — stdout 새 PR 주소
  - `pr-identity <번호>` — stdout `<state> <base> <head> <true|false(다른 레포의 브랜치인가)>`
  - `merge-ways` — stdout 레포가 허용하는 머지 방식(`--merge` · `--squash` · `--rebase` 가운데, 공백으로)
  - `pr-checks <번호> [--watch] [--interval <초>]` · `pr-merge <번호> --merge|--squash|--rebase` — gh 로
    갈아탄다: 출력과 종료 코드가 gh 의 것 그대로다
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys

STOP_SLUG = "origin URL 에서 호스트 · owner · repo 를 뽑지 못했다 — git remote get-url origin 을 확인한다"
STOP_NO_GH = "gh 가 없다 — devbrew 는 gh 를 필수로 쓴다. https://cli.github.com 에서 설치한다"
ENV_NAMES = ("GH_REPO", "GH_HOST")
AUTH_MARKS = ("auth login", "not logged", "authentication", "bad credentials", "http 401")
UNKNOWN_MARKS = ("could not resolve to a repository", "no such type pullrequest")
_PR_NUM_RE = re.compile(r"#?([0-9]+)")
_PR_URL_RE = re.compile(r"https?://([^/\s]+)/([^/\s]+)/([^/\s]+)/pull/([0-9]+)/?")
PR_FIELDS = ("number", "state", "headRefName", "headRefOid", "isCrossRepository", "baseRefName", "mergeCommit")
MERGE_WAYS = (("mergeCommitAllowed", "--merge"), ("squashMergeAllowed", "--squash"),
              ("rebaseMergeAllowed", "--rebase"))


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
        p = subprocess.run(["git", "-C", str(cwd), "remote", "get-url", "origin"],
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
        return ("gh 가 origin(%s)을 다루지 못한다 — devbrew 는 origin 이 GitHub 인 레포만 지원한다"
                "(비공개 레포면 접근 권한도 확인한다)" % slug)
    first = next((ln.strip() for ln in (stderr or "").splitlines() if ln.strip()), "")
    return "gh 실패(rc %d): %s" % (rc, first)


def gh_env() -> dict:
    return dict(os.environ, GH_PROMPT_DISABLED="1", NO_COLOR="1", GH_NO_UPDATE_NOTIFIER="1")


def gh_out(cwd: str, args: list, timeout: float = 15.0, repo_arg: bool = False):
    """(`gh <args> -R <host>/<owner>/<repo>` 의 stdout, slug). `repo_arg` 면 `-R` 대신 slug 를 끝 인자로 준다.
    실패는 GhStop."""
    exe = gh_exe()
    host, owner, repo = origin_slug(cwd)
    slug = "%s/%s/%s" % (host, owner, repo)
    tail = [slug] if repo_arg else ["-R", slug]
    try:
        p = subprocess.run([exe, *args, *tail], cwd=str(cwd), capture_output=True, encoding="utf-8",
                           errors="replace", env=gh_env(), timeout=timeout)
    except subprocess.TimeoutExpired:
        raise GhStop("gh 가 %g초 안에 끝나지 않았다(%s) — 네트워크를 확인하고 다시 돈다" % (timeout, slug))
    except OSError as exc:
        raise GhStop("gh 를 실행하지 못했다(%s) — gh 설치를 확인한다" % exc)
    if p.returncode != 0:
        raise GhStop(stop_for(p.returncode, p.stderr, host, slug))
    return p.stdout, slug


def gh_json(cwd: str, args: list, timeout: float = 15.0, repo_arg: bool = False):
    """`gh <args> -R <host>/<owner>/<repo>` 의 JSON 출력. 실패는 GhStop."""
    out, slug = gh_out(cwd, args, timeout, repo_arg)
    try:
        return json.loads(out)
    except ValueError:
        first = next((ln.strip() for ln in out.splitlines() if ln.strip()), "")
        raise GhStop("gh 출력이 JSON 이 아니다(%s): %s" % (slug, first[:160]))


def gh_exec(cwd: str, args: list):
    """`gh <args> -R <host>/<owner>/<repo>` 로 갈아탄다(exec) — 출력과 종료 코드가 gh 의 것 그대로이고 돌아오지 않는다.
    갈아타지 못하면 GhStop."""
    exe = gh_exe()
    slug = "/".join(origin_slug(cwd))
    sys.stdout.flush()
    sys.stderr.flush()
    try:
        os.chdir(str(cwd))
        os.execve(exe, [exe, *args, "-R", slug], gh_env())
    except OSError as exc:
        raise GhStop("gh 를 실행하지 못했다(%s) — gh 설치를 확인한다" % exc)


def pr_list(cwd: str, branch: str, limit: int = 100):
    """(PR 목록, 한도에 닿았는가). 모양이 다르면 GhStop."""
    items = gh_json(cwd, ["pr", "list", "--state", "all", "--head", branch, "--json", ",".join(PR_FIELDS),
                          "--limit", str(limit)])
    if not isinstance(items, list) or not all(isinstance(it, dict) and all(k in it for k in PR_FIELDS)
                                              for it in items):
        raise GhStop("gh pr list 출력 모양이 다르다(브랜치 %s) — gh 판을 확인한다" % branch)
    return items, len(items) >= limit


def pr_view(cwd: str, number: int) -> dict:
    """번호 하나의 PR. 모양이 다르면 GhStop."""
    got = gh_json(cwd, ["pr", "view", str(number), "--json", ",".join(PR_FIELDS)])
    if not isinstance(got, dict) or not all(k in got for k in PR_FIELDS):
        raise GhStop("gh pr view 출력 모양이 다르다(PR #%d) — gh 판을 확인한다" % number)
    return got


def parse_pr_ref(text: str):
    """`(번호, (host 소문자, owner, repo) | None)` 또는 None. `N` · `#N` · PR URL 만 읽는다."""
    t = (text or "").strip()
    m = _PR_NUM_RE.fullmatch(t)
    if m:
        ref, number = None, int(m.group(1))
    else:
        m = _PR_URL_RE.fullmatch(t)
        if not m:
            return None
        ref, number = (m.group(1).lower(), m.group(2), m.group(3)), int(m.group(4))
    return (number, ref) if number >= 1 else None


def same_repo(a, b) -> bool:
    """(host, owner, repo) 둘이 같은 레포인가 — 호스트 · owner · repo 는 대소문자를 가리지 않는다."""
    return (a[0].lower(), a[1].casefold(), a[2].casefold()) == (b[0].lower(), b[1].casefold(), b[2].casefold())


def origin_pr_number(cwd: str, text: str) -> int:
    """PR 주소의 번호 — 주소의 레포가 origin 일 때만. 주소가 아니거나 다른 레포면 GhStop."""
    ref = parse_pr_ref(text)
    if ref is None or ref[1] is None:
        raise GhStop("PR 주소를 읽지 못했다: %r — https://<호스트>/<owner>/<repo>/pull/<번호> 꼴을 준다" % text)
    origin = origin_slug(cwd)
    if not same_repo(ref[1], origin):
        raise GhStop("PR 주소의 레포(%s)가 origin(%s)이 아니다" % ("/".join(ref[1]), "/".join(origin)))
    return ref[0]


def pr_open_url(cwd: str, head: str, base: str) -> str:
    """head → base 로 가는, 이 레포 안 브랜치의 열린 PR 주소. 없으면 빈 문자열. 모양이 다르면 GhStop."""
    items = gh_json(cwd, ["pr", "list", "--state", "open", "--head", head, "--base", base,
                          "--json", "url,isCrossRepository", "--limit", "20"])
    if not isinstance(items, list) or not all(
            isinstance(it, dict) and isinstance(it.get("url"), str) and isinstance(it.get("isCrossRepository"), bool)
            for it in items):
        raise GhStop("gh pr list 출력 모양이 다르다(브랜치 %s) — gh 판을 확인한다" % head)
    return next((it["url"] for it in items if not it["isCrossRepository"] and it["url"]), "")


def pr_create(cwd: str, head: str, base: str, title: str, body_file: str) -> str:
    """새 PR 의 주소. gh 가 주소를 내지 않으면 GhStop."""
    out, slug = gh_out(cwd, ["pr", "create", "--base", base, "--head", head, "--title", title,
                             "--body-file", body_file], timeout=60.0)
    last = next((ln.strip() for ln in reversed(out.splitlines()) if ln.strip()), "")
    ref = parse_pr_ref(last)
    if ref is None or ref[1] is None:
        raise GhStop("gh pr create 가 PR 주소를 내지 않았다(%s): %s" % (slug, last[:160]))
    return last


def pr_identity(cwd: str, number: int) -> str:
    """`<state> <base> <head> <true|false>` 한 줄 — 끝 칸은 다른 레포의 브랜치에서 온 PR 인가."""
    it = pr_view(cwd, number)
    cells = [it["state"], it["baseRefName"], it["headRefName"]]
    if not all(isinstance(c, str) and c and not any(ch.isspace() for ch in c) for c in cells) \
            or not isinstance(it["isCrossRepository"], bool):
        raise GhStop("gh pr view 출력 모양이 다르다(PR #%d) — gh 판을 확인한다" % number)
    return " ".join(cells + ["true" if it["isCrossRepository"] else "false"])


def merge_ways(cwd: str) -> list:
    """레포가 허용하는 머지 방식의 gh 플래그 — merge commit · squash · rebase 순서. 모양이 다르면 GhStop."""
    got = gh_json(cwd, ["repo", "view", "--json", ",".join(key for key, _flag in MERGE_WAYS)], repo_arg=True)
    if not isinstance(got, dict) or not all(isinstance(got.get(key), bool) for key, _flag in MERGE_WAYS):
        raise GhStop("gh repo view 출력 모양이 다르다 — gh 판을 확인한다")
    return [flag for key, flag in MERGE_WAYS if got[key]]


def _pr_number(text: str) -> int:
    if not text.isdigit() or int(text) < 1:
        raise argparse.ArgumentTypeError("PR 번호는 1 이상의 숫자다: %r" % text)
    return int(text)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="gh_repo.py")
    sub = ap.add_subparsers(dest="cmd", required=True)

    def cmd(name, text):
        p = sub.add_parser(name, help=text)
        p.add_argument("--root", default=None, help="레포 경로(없으면 지금 폴더)")
        return p

    cmd("slug", "origin 의 <host>/<owner>/<repo>")
    cmd("pr-number", "PR 주소의 번호 — 주소의 레포가 origin 일 때만").add_argument("url")
    p = cmd("pr-open", "head → base 로 가는 이 레포 안 브랜치의 열린 PR 주소(없으면 빈 줄)")
    p.add_argument("--head", required=True)
    p.add_argument("--base", required=True)
    p = cmd("pr-create", "새 PR 을 열고 그 주소를 낸다")
    p.add_argument("--head", required=True)
    p.add_argument("--base", required=True)
    p.add_argument("--title", required=True)
    p.add_argument("--body-file", required=True)
    cmd("pr-identity", "<state> <base> <head> <true|false>").add_argument("number", type=_pr_number)
    p = cmd("pr-checks", "gh pr checks 그대로(출력 · 종료 코드)")
    p.add_argument("number", type=_pr_number)
    p.add_argument("--watch", action="store_true")
    p.add_argument("--interval", type=_pr_number, default=None)
    cmd("merge-ways", "레포가 허용하는 머지 방식")
    p = cmd("pr-merge", "gh pr merge 그대로(출력 · 종료 코드)")
    p.add_argument("number", type=_pr_number)
    how = p.add_mutually_exclusive_group(required=True)
    for _key, flag in MERGE_WAYS:
        how.add_argument(flag, dest="how", action="store_const", const=flag)
    a = ap.parse_args(argv)
    root = a.root or os.getcwd()
    for line in env_notices():
        print("[spec-distill] " + line, file=sys.stderr)
    try:
        if a.cmd == "slug":
            print("/".join(origin_slug(root)))
        elif a.cmd == "pr-number":
            print(origin_pr_number(root, a.url))
        elif a.cmd == "pr-open":
            print(pr_open_url(root, a.head, a.base))
        elif a.cmd == "pr-create":
            print(pr_create(root, a.head, a.base, a.title, a.body_file))
        elif a.cmd == "pr-identity":
            print(pr_identity(root, a.number))
        elif a.cmd == "merge-ways":
            print(" ".join(merge_ways(root)))
        elif a.cmd == "pr-checks":
            extra = (["--watch"] if a.watch else []) + (["--interval", str(a.interval)] if a.interval else [])
            gh_exec(root, ["pr", "checks", str(a.number)] + extra)
        else:
            gh_exec(root, ["pr", "merge", str(a.number), a.how])
    except GhStop as exc:
        print("[spec-distill] " + str(exc), file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
