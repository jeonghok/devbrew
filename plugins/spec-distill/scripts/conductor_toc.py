#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_toc.py — 지휘 지시서의 차례(`references/conducting.md`)에서 걸음 표를 읽는다.

차례는 걸음 표(걸음 1 ~ 7 · 단계 이름 · 지시서 경로) · 걸음에 달리지 않은 지시서 · 손으로 따르는 절차 파일을 적는다.
이 모듈은 그 꼴을 읽어 지시서 경로를 내고, 이름 붙은 파일이 다 있는지 본다.

명령줄:
  conductor_toc.py files [--plugin-root <P>] [--kind all|step|extra|manual]   절대경로 한 줄씩(all 은 차례 자신이 맨 앞)
  conductor_toc.py step --stage "<단계>" [--plugin-root <P>]                 <번호>\\t<이름>\\t<절대경로>

종료 코드: 0 · step 에 맞는 걸음이 없으면 1 · 차례를 읽지 못하면 3.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import NamedTuple

TOC_REL = Path("references") / "conducting.md"
HEADER = "| 걸음 | 들어서는 때 | 지시서 | 함께 읽는 것 |"
STEP_COUNT = 7
H_STEPS = "### 걸음 표"
H_EXTRAS = "### 걸음에 달리지 않은 지시서"
H_MANUAL = "## 손으로 따르는 절차"
SD_PATH = re.compile(r"<SD>/references/[a-z0-9-]+\.md")
TICKED_SD = re.compile(r"`(<SD>/references/[^`]*)`")
STAGE_MARK = "단계:"
STAGE_SEP = " · "


class Step(NamedTuple):
    number: int
    name: str
    stages: tuple
    guide: str
    also: str


class Extra(NamedTuple):
    when: str
    guide: str


class Toc(NamedTuple):
    steps: tuple
    extras: tuple
    manual: str


class TocError(Exception):
    """차례의 꼴이 틀렸다. str(exc) 는 사유 한 줄."""


def _section(lines: list, heading: str) -> list:
    """heading 줄 다음부터 같거나 더 높은 단계의 머리 앞까지의 줄."""
    level = len(heading) - len(heading.lstrip("#"))
    try:
        start = lines.index(heading) + 1
    except ValueError:
        raise TocError("차례에 「%s」 절이 없다" % heading.lstrip("# "))
    out = []
    for ln in lines[start:]:
        m = re.match(r"(#+) ", ln)
        if m and len(m.group(1)) <= level:
            break
        out.append(ln)
    return out


def _guide_path(cell: str, where: str) -> str:
    m = re.fullmatch(r"`([^`]*)`", cell)
    path = m.group(1) if m else cell
    if not m or not SD_PATH.fullmatch(path):
        raise TocError("%s 의 지시서 경로가 꼴이 아니다: %s" % (where, cell))
    return path


def _step_rows(block: list) -> list:
    table = []
    started = False
    for ln in block:
        if ln.startswith("|"):
            started = True
            table.append(ln)
        elif started:
            break
        elif ln.strip():
            raise TocError("걸음 표 머리 앞에 표가 아닌 줄이 있다: %s" % ln.strip())
    if not table or table[0].strip() != HEADER:
        raise TocError("걸음 표의 머리 줄이 꼴이 아니다")
    if len(table) < 2 or not re.fullmatch(r"\|[-| :]+\|", table[1].strip()):
        raise TocError("걸음 표의 구분 줄이 없다")
    return table[2:]


def _parse_steps(block: list) -> tuple:
    rows = _step_rows(block)
    steps = []
    for i, ln in enumerate(rows, start=1):
        cells = [c.strip() for c in ln.strip().strip("|").split("|")]
        if len(cells) != 4:
            raise TocError("걸음 %d 행의 칸이 넷이 아니다" % i)
        m = re.fullmatch(r"(\d+) (\S.*)", cells[0])
        if not m or int(m.group(1)) != i:
            raise TocError("걸음 %d 행의 첫 칸이 「%d <이름>」 꼴이 아니다: %s" % (i, i, cells[0]))
        when = cells[1]
        stages = ()
        if STAGE_MARK in when:
            tail = when.split(STAGE_MARK, 1)[1].strip()
            stages = tuple(s.strip() for s in tail.split(STAGE_SEP) if s.strip())
        steps.append(Step(i, m.group(2), stages, _guide_path(cells[2], "걸음 %d" % i), cells[3]))
    if len(steps) < STEP_COUNT:
        raise TocError("걸음 표에 걸음 %d 행이 없다" % (len(steps) + 1))
    if len(steps) > STEP_COUNT:
        raise TocError("걸음 표의 행이 %d 을 넘는다: %d" % (STEP_COUNT, len(steps)))
    seen = {}
    for s in steps:
        for st in s.stages:
            if st in seen:
                raise TocError("단계 이름 「%s」 이 걸음 %d 와 걸음 %d 에 겹친다" % (st, seen[st], s.number))
            seen[st] = s.number
    return tuple(steps)


def _parse_extras(block: list) -> tuple:
    extras = []
    for ln in block:
        if not ln.startswith("- "):
            continue
        when, sep, tail = ln[2:].rpartition(" — ")
        if not sep:
            raise TocError("걸음에 달리지 않은 지시서 줄에 「 — 」 가 없다: %s" % ln)
        extras.append(Extra(when.strip(), _guide_path(tail.strip(), "「%s」" % when.strip())))
    return tuple(extras)


def _parse_manual(block: list) -> str:
    paths = TICKED_SD.findall("\n".join(block))
    if len(paths) != 1:
        raise TocError("손으로 따르는 절차에 지시서 경로가 하나여야 하는데 %d 개다: %s" % (len(paths), ", ".join(paths) or "없음"))
    return _guide_path("`%s`" % paths[0], "손으로 따르는 절차")


def parse(text: str) -> Toc:
    lines = text.splitlines()
    toc = Toc(_parse_steps(_section(lines, H_STEPS)), _parse_extras(_section(lines, H_EXTRAS)),
              _parse_manual(_section(lines, H_MANUAL)))
    seen = set()
    for p in named_files(toc):
        if p in seen:
            raise TocError("지시서 경로가 겹친다: %s" % p)
        seen.add(p)
    return toc


def resolve(plugin_root: Path, sd_path: str) -> Path:
    if not SD_PATH.fullmatch(sd_path):
        raise TocError("지시서 경로가 <SD>/references/<이름>.md 꼴이 아니다: %s" % sd_path)
    return Path(plugin_root) / sd_path[len("<SD>/"):]


def named_files(toc: Toc) -> list:
    """걸음 1 ~ 7 의 지시서 · extras · manual 순서. 차례 파일 자신은 넣지 않는다."""
    return [s.guide for s in toc.steps] + [e.guide for e in toc.extras] + [toc.manual]


def load(plugin_root: Path) -> Toc:
    toc_path = Path(plugin_root) / TOC_REL
    try:
        text = toc_path.read_text(encoding="utf-8")
    except OSError:
        raise TocError("차례가 없다: %s" % toc_path)
    except UnicodeDecodeError:
        raise TocError("차례가 UTF-8 이 아니다: %s" % toc_path)
    toc = parse(text)
    for sd in named_files(toc):
        p = resolve(plugin_root, sd)
        if not p.is_file():
            raise TocError("지시서가 없다: %s" % p)
    return toc


def step_for(toc: Toc, stage: str):
    """단계 이름이 표와 같거나 「<이름> <꼬리>」 면 그 걸음. 아니면 None."""
    for s in toc.steps:
        for st in s.stages:
            if stage == st or stage.startswith(st + " "):
                return s
    return None


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="conductor_toc.py")
    ap.add_argument("--plugin-root", default=str(Path(__file__).resolve().parent.parent))
    sub = ap.add_subparsers(dest="cmd", required=True)
    pf = sub.add_parser("files")
    pf.add_argument("--kind", choices=("all", "step", "extra", "manual"), default="all")
    ps = sub.add_parser("step")
    ps.add_argument("--stage", required=True)
    # --plugin-root 는 하위 명령 뒤에도 받는다
    for p in (pf, ps):
        p.add_argument("--plugin-root", default=argparse.SUPPRESS)
    args = ap.parse_args(argv)
    root = Path(args.plugin_root).resolve()
    try:
        toc = load(root)
        if args.cmd == "files":
            sds = {"step": [s.guide for s in toc.steps], "extra": [e.guide for e in toc.extras],
                   "manual": [toc.manual], "all": named_files(toc)}[args.kind]
            paths = [root / TOC_REL] if args.kind == "all" else []
            paths += [resolve(root, sd) for sd in sds]
            print("\n".join(str(p) for p in paths))
            return 0
        s = step_for(toc, args.stage)
        if s is None:
            print("걸음 없음 — 차례 표에 이 단계가 없다")
            return 1
        print("%d\t%s\t%s" % (s.number, s.name, resolve(root, s.guide)))
        return 0
    except TocError as exc:
        print("[spec-distill] 차례를 읽지 못했다 — %s" % exc, file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
