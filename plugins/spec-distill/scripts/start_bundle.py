#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""start_bundle.py — 일꾼이 시작할 때 받는 묶음. 읽기만 하고 표준 출력으로만 낸다.

모든 글은 기본 브랜치의 커밋에서 읽는다(작업 폴더의 사본은 읽지 않는다). 팀 규칙 파일만
`team_layout.leader_ref` 가 말하는 커밋에서 읽는다(리더가 쓰는 파일).

명령줄: start_bundle.py --roadmap <로드맵 레포 상대경로> --role leader
        종료 코드 0 묶음을 냈다 · 1 멈춤 · 2 사용법 · 3 검사 불가. 0 이 아니면 표준 출력은 비어 있다.
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import NamedTuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
import repo_defaults  # noqa: E402
import roadmap_status  # noqa: E402
import team_layout  # noqa: E402
import team_rules  # noqa: E402
from roadmap_model import DEFAULT_REF  # noqa: E402

PREFIX = "[spec-distill] "
Usage = team_rules.Usage
Unchecked = team_rules.Unchecked


class Refused(Exception):
    """묶음을 낼 수 없어 멈춘다(종료 코드 1)."""


class Base(NamedTuple):
    commit: str
    rules_commit: str
    roadmaps_dir: str
    team: object
    settings: dict


def _opened(base: Base, rev: str, git) -> team_rules.Opened:
    return team_rules.Opened(git, "", base.settings, base.team, rev, rev)


def open_base(git, roadmap_rel: str) -> Base:
    """레포 · 설정 · 기본 브랜치 · 로드맵(team 형식)을 확인하고 읽을 커밋을 정한다."""
    opened = team_rules.open_team(roadmap_rel, default_branch=True)
    rules_commit = git.commit(team_layout.leader_ref(DEFAULT_REF))
    if rules_commit is None:
        raise Unchecked("리더가 쓰는 파일을 읽을 커밋을 풀지 못했다")
    return Base(opened.rev, rules_commit, opened.values["roadmaps_dir"], opened.team, opened.values)


def role_block(git, base: Base, role: str) -> list:
    """`역할 문서 (<기준 커밋>):` 줄과 그 글. 기준 커밋에 없으면 Refused."""
    path = team_layout.role_doc(base.roadmaps_dir, role)
    loaded = team_rules.read_loaded(_opened(base, base.commit, git), path)
    if loaded is None:
        raise Refused("역할 문서: 없음 — %s 가 기준 커밋에 없다" % path)
    return ["역할 문서 (%s):" % base.commit, loaded.text]


def rules_block(git, base: Base) -> tuple:
    """(줄들, 알림들) — 팀 규칙 파일 · 공통 규칙 파일의 글을 통째로 싣는다. 예산을 넘은 파일마다 알림 한 줄."""
    head = "규칙 (%s):" % base.commit
    if base.rules_commit != base.commit:
        head = "규칙 (%s · 팀 규칙은 %s):" % (base.commit, base.rules_commit)
    lines, notices = [head], []
    handbook = team_layout.handbook(base.roadmaps_dir)
    for path, rev, budget_key in ((base.team.rules, base.rules_commit, repo_defaults.BUDGET_KEYS[0]),
                                  (handbook, base.commit, repo_defaults.BUDGET_KEYS[1])):
        loaded = team_rules.read_loaded(_opened(base, rev, git), path)
        if loaded is None:
            notices.append("%s 가 기준 커밋에 없다" % path)
            continue
        lines.append(loaded.text)
        note = team_rules.budget_note(path, loaded.size, base.settings[budget_key], budget_key)
        if note:
            notices.append(note)
    return lines, notices


def emit(first: str, notices: list, body: list) -> str:
    """첫 줄 · `알림: <글>` 줄들 · 본문 줄들을 이은 글. 끝 줄바꿈이 없는 조각에는 하나를 붙인다."""
    parts = [first] + ["알림: %s" % n for n in notices] + list(body)
    return "".join(p if p.endswith("\n") else p + "\n" for p in parts if p)


def _leader_bundle(roadmap: str) -> str:
    git = roadmap_status.Git(os.getcwd())
    base = open_base(git, roadmap)
    role = role_block(git, base, team_layout.LEADER_ROLE)
    rules, notices = rules_block(git, base)
    return emit("기준 커밋: %s" % base.commit, notices, role + rules)


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="start_bundle.py", description="일꾼의 시작 묶음")
    ap.add_argument("--roadmap", required=True)
    ap.add_argument("--role", required=True, choices=team_layout.ROLES)
    ap.add_argument("--job")
    ap.add_argument("--stage", choices=team_layout.STAGES)
    return ap


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    try:
        a = build_parser().parse_args(argv)
        if a.roadmap.startswith("/"):
            raise Usage("--roadmap 은 레포 상대 경로다: %s" % a.roadmap)
        if a.job is not None or a.stage is not None or a.role != team_layout.LEADER_ROLE:
            raise Usage("과제 묶음은 아직 낼 수 없다 — 리더 묶음은 --role %s 만 준다" % team_layout.LEADER_ROLE)
        text = _leader_bundle(a.roadmap)
    except Usage as exc:
        print(PREFIX + "사용법 오류 — %s" % exc, file=sys.stderr)
        return 2
    except Refused as exc:
        print(PREFIX + "멈춤 — %s" % exc, file=sys.stderr)
        return 1
    except Unchecked as exc:
        print(PREFIX + "검사 불가 — %s" % exc, file=sys.stderr)
        return 3
    except Exception as exc:  # 반쯤 나온 묶음을 내지 않는다
        print(PREFIX + "검사 불가 — 내부 오류 %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 3
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
