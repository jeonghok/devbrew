#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""branch_tip.py — 대조 · 리뷰할 브랜치 끝을 고른다. 스위트 대조(`merge_check.py`)와 통합 리뷰 묶음
(`conductor_ledger.py review-pack`)이 같은 커밋을 보게 하는 한 곳이다.

`tip(root, branch)` → (커밋 | None, 알릴 줄 | None):
  - `origin/<b>` 를 주면 그 원격 끝
  - 로컬과 origin 중 하나만 있거나 같으면 그것(알릴 줄 없음)
  - 둘이 다르면 앞선 쪽을 쓰고 알릴 줄을 낸다 — 갈라졌거나 조상 관계를 잴 수 없으면 TipError(부르는 쪽은 검사 불가 3)
"""
from __future__ import annotations

import shutil
import subprocess

GIT = shutil.which("git") or "git"


class TipError(Exception):
    pass


def _git(root, *args):
    p = subprocess.run([GIT, *args], cwd=str(root), capture_output=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def resolve(root, ref: str):
    rc, out, _e = _git(root, "rev-parse", "--verify", "--quiet", ref + "^{commit}")
    return out if rc == 0 else None


def _is_ancestor(root, a: str, b: str) -> bool:
    rc, _o, err = _git(root, "merge-base", "--is-ancestor", a, b)
    if rc in (0, 1):
        return rc == 0
    raise TipError("조상 관계를 잴 수 없다(%s · %s): %s" % (a[:8], b[:8], err[-200:]))


def tip(root, branch: str):
    if branch.startswith("origin/"):
        remote = resolve(root, "refs/remotes/" + branch)
        if remote:
            return remote, None
    local = resolve(root, "refs/heads/" + branch)
    remote = resolve(root, "refs/remotes/origin/" + branch)
    if local is None or remote is None or local == remote:
        return local or remote, None
    if _is_ancestor(root, local, remote):
        return remote, "[spec-distill] 로컬 브랜치 %s 가 origin 보다 뒤라 origin/%s(%s) 를 썼다" % (branch, branch, remote[:8])
    if _is_ancestor(root, remote, local):
        return local, ("[spec-distill] origin/%s 가 로컬보다 뒤라(push 하지 않았거나 받아 오지 않은 커밋) 로컬 %s(%s) 를 썼다"
                       % (branch, branch, local[:8]))
    raise TipError("로컬 브랜치 %s(%s) 와 origin/%s(%s) 가 갈라졌다 — 한쪽으로 맞춘 뒤 다시 돈다"
                   % (branch, local[:8], branch, remote[:8]))
