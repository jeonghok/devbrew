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
LEADER_ROLE = ROLES[0]

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
BLOCKED_FILE = "BLOCKED.md"

STAGES = ("design", "plan", "implement", "review")
PLANNED_STAGES = ("plan", "implement", "review")
PLAIN_FLOW_STAGES = ("진행 중", "결과 받음")   # 설계 없는 흐름의 단계 글자(설계 §10) — 브랜치 있음 · 받음 줄 있음

# 단계의 기본 역할 — STAGES 의 차례와 같다. review 는 None(역할 문서를 주지 않는다, 설계 §6).
_DEFAULT_ROLES = dict(zip(STAGES, (ROLES[1], ROLES[1], ROLES[3], None)))

_JOB_NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*")
_PLAN_FILE_RE = re.compile(r"plan-([1-9][0-9]*)\.md")
_PLAN_SHAPE_RE = re.compile(r"plan-([0-9]+)\.md")
_RESULT_RE = re.compile(r"(%s)(?:-plan-([1-9][0-9]*))?-([1-9][0-9]*)\.md" % "|".join(STAGES))


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


def plan_name(n: int) -> str:
    if n < 1:
        raise ValueError("계획 번호는 1 이상이다: %r" % n)
    return "plan-%d.md" % n


def plan_number(name: str) -> Optional[int]:
    """`plan-<n>.md` 의 n(0 으로 시작하지 않는 1 이상의 수). 그 꼴이 아니면 None."""
    m = _PLAN_FILE_RE.fullmatch(name)
    return int(m.group(1)) if m else None


def plan_shape_digits(name: str) -> Optional[str]:
    """`plan-<숫자>.md` 모양이면 그 숫자 글자(0 · 앞의 0 포함), 아니면 None — 올바른 이름은 `plan_number` 가 가린다."""
    m = _PLAN_SHAPE_RE.fullmatch(name)
    return m.group(1) if m else None


def result_name(stage: str, attempt: int, plan: Optional[int] = None) -> str:
    if stage not in STAGES:
        raise ValueError("단계 이름이 아니다: %r" % stage)
    if attempt < 1:
        raise ValueError("시도 번호는 1 이상이다: %r" % attempt)
    if plan is None:
        return "%s-%d.md" % (stage, attempt)
    if stage == STAGES[0]:
        raise ValueError("%s 결과에는 계획 번호가 붙지 않는다" % stage)
    if plan < 1:
        raise ValueError("계획 번호는 1 이상이다: %r" % plan)
    return "%s-plan-%d-%d.md" % (stage, plan, attempt)


def parse_result_name(name: str) -> Optional[tuple]:
    """결과 파일 이름 → (단계, 계획 | None, 시도). 꼴이 아니면 None."""
    m = _RESULT_RE.fullmatch(name)
    if not m or (m.group(2) and m.group(1) == STAGES[0]):
        return None
    return (m.group(1), int(m.group(2)) if m.group(2) else None, int(m.group(3)))


def job_of_path(roadmaps_dir: str, rel: str) -> Optional[tuple]:
    """`<roadmaps_dir><팀>/jobs/<과제>/<나머지>` 꼴이면 (Team, 과제, 나머지), 아니면 None."""
    if not rel.startswith(roadmaps_dir):
        return None
    parts = rel[len(roadmaps_dir):].split("/")
    if len(parts) < 4 or parts[1] != JOBS_DIR or not parts[0] or not parts[3]:
        return None
    if team_name_problem(parts[0]) or job_name_problem(parts[2]):
        return None
    return Team(roadmaps_dir, parts[0]), parts[2], "/".join(parts[3:])


def handbook(roadmaps_dir: str) -> str:
    return roadmaps_dir + HANDBOOK_FILE


def role_doc(roadmaps_dir: str, role: str) -> str:
    if role not in ROLES:
        raise ValueError("역할 이름이 아니다: %r" % role)
    return roadmaps_dir + role + "/" + ROLE_DOC


def default_role(stage: str) -> Optional[str]:
    """단계의 기본 역할. review 는 None(역할 문서를 주지 않는다). STAGES 밖이면 ValueError."""
    if stage not in _DEFAULT_ROLES:
        raise ValueError("단계 이름이 아니다: %r" % stage)
    return _DEFAULT_ROLES[stage]


def leader_ref(default_ref: str) -> str:
    """리더가 쓰는 파일(팀 규칙 파일)을 읽을 ref. 받은 값을 그대로 돌려준다(I2).
    R3 가 이 함수의 값을 바꿀 때 결과 파일 머리의 규칙 커밋 칸과 `job sync` 의 인자도 함께 바뀐다 —
    「묶음 낡음」 은 팀 규칙의 그때 글을 머리 bundle_at 의 커밋에서 읽으므로, 값만 바꾸면 거짓 「묶음 낡음」 이 뜬다."""
    return default_ref


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

    @property
    def jobs(self) -> str:
        return self.path(JOBS_DIR)

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
        return self.job(job, plan_name(n))

    def result(self, job: str, stage: str, attempt: int, plan: Optional[int] = None) -> str:
        return self.job(job, RESULTS_DIR, result_name(stage, attempt, plan))

    def blocked(self, job: str) -> str:
        return self.job(job, RESULTS_DIR, BLOCKED_FILE)


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
