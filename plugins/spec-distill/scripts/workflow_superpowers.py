#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""workflow_superpowers.py — superpowers 의 계획 · 구현 원장 꼴을 읽는 한 곳. 글만 다루고 쓰지 않는다.

계획의 task 절을 읽는 글자(`TASK_HEAD`)는 이 파일에만 둔다. git 을 부르지 않고 subprocess 를 쓰지 않는다.

명령줄: workflow_superpowers.py place --roadmap <로드맵 레포 상대경로> --job <과제> --stage design|plan [--plan <n>] [--root <레포>]
        그 단계 산출물을 둘 자리를 일러 주는 문장 한 줄을 낸다.
        종료 코드 0 · 2 사용법(plan 단계에 --plan 없음 · 로드맵 자리가 아님) · 3 레포 설정을 못 읽음
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import repo_defaults  # noqa: E402
import team_layout  # noqa: E402

TASK_HEAD = "### Task"
NO_COMMIT = "없음"

_COMPLETE_RE = re.compile(r"Task ([0-9]+): complete")
_COMMITS_RE = re.compile(r"commits [^\s.]+\.\.([0-9a-f]{7,64})(?![0-9A-Za-z])")
_BULLETS = ("- ", "* ")


def _fenced(lines):
    """(줄, 펜스 안 · 펜스 줄 자신이면 True) 짝들."""
    inside = False
    for line in lines:
        if line.lstrip().startswith("```"):
            inside = not inside
            yield line, True
        else:
            yield line, inside


def task_text(plan_text: str) -> str:
    """task 절들(머리 줄 포함)을 이어 붙인 글. 펜스 안 줄은 절 경계가 아니지만 본문에는 든다."""
    out, on, in_fence = [], False, False
    for line in plan_text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        elif not in_fence and (line.startswith("## ") or line.startswith("### ")):
            on = line.startswith(TASK_HEAD)
        if on:
            out.append(line)
    return "\n".join(out)


def task_total(plan_text: str) -> int:
    """펜스 밖에서 task 절 머리로 시작하는 줄의 수."""
    return sum(1 for line, fenced in _fenced(plan_text.splitlines()) if not fenced and line.startswith(TASK_HEAD))


def _unbullet(line: str) -> str:
    line = line.strip()
    for mark in _BULLETS:
        if line.startswith(mark):
            return line[len(mark):].strip()
    return line


RULING_MARK = "Ruling:"


def ruling_said(line: str) -> Optional[str]:
    """판정 줄 규칙 하나 — 줄 어디든 `RULING_MARK` 가 있으면 첫 그것 뒤의 글(앞뒤 공백 뺀). 비면 판정이 아니다."""
    if RULING_MARK not in line:
        return None
    said = line.split(RULING_MARK, 1)[1].strip()
    return said or None


def ledger_lines(ledger_text: str, total: int) -> list:
    """구현 원장에서 결과 파일에 실을 줄들(원장의 차례) — 끝난 Task 줄과 Ruling 줄. 그 밖의 줄은 내지 않는다."""
    out, done = [], set()
    for raw in ledger_text.splitlines():
        line = _unbullet(raw)
        m = _COMPLETE_RE.match(line)
        if m and int(m.group(1)) >= 1:
            n = int(m.group(1))
            if n in done:
                continue
            done.add(n)
            c = _COMMITS_RE.search(line)
            out.append("Task %d/%d: 끝 — %s" % (n, total, c.group(1) if c else NO_COMMIT))
        else:
            said = ruling_said(line)
            item = RULING_MARK + " " + (said or "")
            if said is not None and item not in out:
                out.append(item)
    return out


def place_sentence(path: str, stage: str) -> str:
    """superpowers 에게 산출물을 기본 자리 대신 path 에 쓰라고 전하는 문장. design · plan 만 받는다."""
    if stage == team_layout.STAGES[0]:
        return "설계문서는 기본 자리 대신 %s 에 쓴다." % path
    if stage == team_layout.STAGES[1]:
        return "계획은 기본 자리 대신 %s 에 쓴다." % path
    raise ValueError("자리를 정하는 단계는 %s 뿐이다: %r" % (" · ".join(team_layout.STAGES[:2]), stage))


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="workflow_superpowers.py", description="superpowers 산출물 자리 문장")
    sub = ap.add_subparsers(dest="cmd")
    sub.required = True
    p = sub.add_parser("place")
    p.add_argument("--roadmap", required=True)
    p.add_argument("--job", required=True)
    p.add_argument("--stage", required=True, choices=team_layout.STAGES[:2])
    p.add_argument("--plan", type=int)
    p.add_argument("--root", default=".")
    return ap


def _place(a) -> int:
    try:
        result = repo_defaults.resolve(a.root)
    except repo_defaults.SettingsError as exc:
        print("[spec-distill] 레포 설정을 읽지 못했다 — %s" % exc, file=sys.stderr)
        return 3
    if result["errors"]:
        print("[spec-distill] 레포 설정을 읽지 못했다 — %s" % result["errors"][0], file=sys.stderr)
        return 3
    try:
        team = team_layout.team_from_roadmap(result["values"]["roadmaps_dir"], a.roadmap)
        problem = team_layout.job_name_problem(a.job)
        if problem:
            raise ValueError(problem)
        if a.stage == team_layout.STAGES[0]:
            path = team.design(a.job)
        elif a.plan is None:
            raise ValueError("--stage %s 에는 --plan <n> 이 필요하다" % a.stage)
        else:
            path = team.plan(a.job, a.plan)
        print(place_sentence(path, a.stage))
    except ValueError as exc:
        print("[spec-distill] 사용법 오류 — %s" % exc, file=sys.stderr)
        return 2
    return 0


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    return _place(build_parser().parse_args(argv))


if __name__ == "__main__":
    sys.exit(main())
