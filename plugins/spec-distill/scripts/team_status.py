#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_status.py — team 형식 로드맵의 읽기 쪽 모듈. 읽기만 한다.

git 은 받은 `roadmap_status.Git` 으로만 읽는다. `roadmap_status` 는 이 모듈에서 import 하지 않는다.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import branch_tip  # noqa: E402

UNPUSHED = "아직 안 올라옴"
SPLIT = "갈라짐"


def read_tip(git, branch: str) -> tuple:
    """(읽을 커밋 | None, 알림 줄 | None, 갈라짐 사유 | None).

    끝 고르기는 branch_tip.tip 하나가 한다. 고른 커밋이 로컬 끝이고 origin 끝과 다르면 올라오지 않은 것이다."""
    try:
        commit, _note = branch_tip.tip(git.cwd, branch)
    except branch_tip.TipError as exc:
        return None, None, "%s — %s" % (SPLIT, exc)
    if commit is None:
        return None, None, None
    local = git.commit("refs/heads/" + branch)
    remote = git.commit("refs/remotes/origin/" + branch)
    if commit == local and commit != remote:
        return commit, ("%s — %s 의 로컬 끝 %s 이 origin 에 없다(로컬을 읽었다)" % (UNPUSHED, branch, commit[:8])), None
    return commit, None, None
