#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_layout.py — team 형식(머리말 `layout: team`)의 이름과 경로가 나오는 한 곳.

표준 라이브러리만 import 한다 — 다른 모듈이 이 모듈을 import 하므로 거꾸로 import 하면 돈다.
경로는 상수를 `/` 로 이어 만든다. 읽기만 한다(파일을 쓰지 않는다).

명령줄: team_layout.py check --roadmap <로드맵 파일> [--base <ref>]
        종료 코드 0 통과 · 1 어긋남 · 2 사용법 · 3 검사 불가 — 검사는 team_check 가 한다.
"""
from __future__ import annotations

import re
import sys
from typing import NamedTuple, Optional

LAYOUT_KEY = "layout"
LAYOUT_TEAM = "team"
LAYOUTS = (LAYOUT_TEAM,)
ROLES = ("leader", "designer", "writer", "worker")

ROADMAP_FILE = "roadmap.md"
RULES_FILE = "RULES.md"
HANDBOOK_FILE = "HANDBOOK.md"
ROLE_DOC = "CLAUDE.md"
REVIEW_FILE = "REVIEW.md"
STATUS_FILE = "STATUS.md"
INBOX_DIR = "inbox"
INTENT_DIR = "intent"
ORIGINAL_FILE = "original.md"
JOBS_DIR = "jobs"
INTENT_FILE = "INTENT.md"
SOURCES_FILE = "sources.md"
DESIGN_FILE = "design.md"
RESULTS_DIR = "results"
KEEP_FILE = ".gitkeep"

STAGE_PENDING = "이 판은 team 형식의 단계를 계산하지 않는다 — 번호 대조까지만 했다"

_JOB_NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*")


class UnknownLayout(ValueError):
    """머리말 `layout` 의 값이 알려진 형식이 아니다 — `.value` 가 그 값이다."""

    def __init__(self, value: str):
        super().__init__("알 수 없는 layout 값: %r" % value)
        self.value = value


def _unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def layout_of(meta: dict) -> Optional[str]:
    """머리말의 형식. 키가 없으면 None, 알려진 값이면 그 값, 아니면(빈 값 포함) UnknownLayout."""
    if LAYOUT_KEY not in meta:
        return None
    value = _unquote(str(meta[LAYOUT_KEY]).strip())
    if value in LAYOUTS:
        return value
    raise UnknownLayout(value)


def team_name_problem(name: str) -> Optional[str]:
    """팀 폴더 이름으로 못 쓰는 사유 한 줄, 쓸 수 있으면 None."""
    if name in ROLES:
        return "역할 이름(%s)은 팀 이름으로 쓰지 않는다" % name
    return None


def job_name_problem(name: str) -> Optional[str]:
    """작업 이름으로 못 쓰는 사유 한 줄, 쓸 수 있으면 None."""
    if name in ROLES:
        return "역할 이름(%s)은 작업 이름으로 쓰지 않는다" % name
    if not _JOB_NAME_RE.fullmatch(name):
        return "작업 이름은 영문자 · 숫자로 시작하고 영문자 · 숫자 · _ · - 만 쓴다(%r)" % name
    return None


def job_rel(job: str, *names: str) -> str:
    return "/".join((JOBS_DIR, job) + names)


def sources_rel(job: str) -> str:
    return job_rel(job, SOURCES_FILE)


def intent_rel(job: str) -> str:
    return job_rel(job, INTENT_FILE)


def original_rel() -> str:
    return INTENT_DIR + "/" + ORIGINAL_FILE


def handbook(roadmaps_dir: str) -> str:
    return roadmaps_dir + HANDBOOK_FILE


def role_doc(roadmaps_dir: str, role: str) -> str:
    if role not in ROLES:
        raise ValueError("역할 이름이 아니다: %r" % role)
    return roadmaps_dir + role + "/" + ROLE_DOC


class Team(NamedTuple):
    roadmaps_dir: str
    name: str

    @property
    def dir(self) -> str:
        return self.roadmaps_dir + self.name

    def path(self, team_rel: str) -> str:
        return self.dir + "/" + team_rel

    @property
    def roadmap(self) -> str:
        return self.path(ROADMAP_FILE)

    @property
    def rules(self) -> str:
        return self.path(RULES_FILE)

    @property
    def original(self) -> str:
        return self.path(original_rel())

    @property
    def status(self) -> str:
        return self.path(STATUS_FILE)

    @property
    def inbox(self) -> str:
        return self.path(INBOX_DIR)

    def job(self, job: str, *names: str) -> str:
        return self.path(job_rel(job, *names))

    def intent(self, job: str) -> str:
        return self.path(intent_rel(job))

    def sources(self, job: str) -> str:
        return self.path(sources_rel(job))

    def results(self, job: str) -> str:
        return self.job(job, RESULTS_DIR)

    def keep(self, job: str) -> str:
        return self.job(job, RESULTS_DIR, KEEP_FILE)

    def design(self, job: str) -> str:
        return self.job(job, DESIGN_FILE)

    def plan(self, job: str, n: int) -> str:
        if n < 1:
            raise ValueError("계획 번호는 1 이상이다: %r" % n)
        return self.job(job, "plan-%d.md" % n)


def team_from_roadmap(roadmaps_dir: str, roadmap_rel: str) -> Team:
    """`<roadmaps_dir><팀>/roadmap.md` 꼴의 경로에서 Team. 꼴이 아니거나 팀 이름이 역할 이름이면 ValueError."""
    if not roadmap_rel.startswith(roadmaps_dir):
        raise ValueError("로드맵 폴더(%s) 밖이다: %s" % (roadmaps_dir, roadmap_rel))
    parts = roadmap_rel[len(roadmaps_dir):].split("/")
    if len(parts) != 2 or not parts[0] or parts[1] != ROADMAP_FILE:
        raise ValueError("<팀>/%s 꼴이 아니다: %s" % (ROADMAP_FILE, roadmap_rel))
    problem = team_name_problem(parts[0])
    if problem:
        raise ValueError(problem)
    return Team(roadmaps_dir, parts[0])


def main(argv=None) -> int:
    import team_check  # noqa: E402 — 함수 안에서 가져온다(team_check 가 이 모듈을 가져오므로 맨 위에서 하면 import 가 돈다)
    return team_check.run(argv)


if __name__ == "__main__":
    sys.exit(main())
