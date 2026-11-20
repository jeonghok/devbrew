#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""walk_table.py — 걸음표(기본 표 · 레포가 고친 표)를 읽고 검사한다. 읽기만 하고 표준 출력으로만 낸다.

명령줄: walk_table.py check            걸음 보기가 쓸 표를 검사한다(레포 설정 walk_table 이 있으면 기본 브랜치의 그 파일)
        walk_table.py check <파일>     작업 폴더의 그 파일을 검사한다
        종료 코드 0 맞다 · 2 사용법 · 3 검사 불가. 0 이 아니면 표준 출력은 비어 있다.
"""
from __future__ import annotations

import sys
from pathlib import Path
from typing import NamedTuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
import human_lines  # noqa: E402
import repo_defaults  # noqa: E402
import team_layout  # noqa: E402
import team_rules  # noqa: E402
import team_status  # noqa: E402

PREFIX = "[spec-distill] "
COLUMNS = ("걸음", "누가", "단계", "관문", "작업 방식", "상한", "도구")
EMPTY = "—"
DEFAULT_TABLE = Path(__file__).resolve().parent.parent / "references" / "walk-table.md"
DEFAULT_SOURCE = "플러그인 기본 표"
FLOWS = (team_status.DESIGN_FLOW, team_status.PLAIN_FLOW)
HEADING = "## "
# 걸음 보기가 지금 걸음을 가르는 닻 — 기본 표의 걸음 이름(차례대로). 레포 표가 이름을 지우면 걸음 보기가 멈춘다.
ANCHORS = {
    team_status.DESIGN_FLOW: ("방향 확인", "설계 대화", "설계 검토", "설계 승인", "계획", "계획 확인", "구현", "검수",
                              "PR 전 확인", "머지", "회고"),
    team_status.PLAIN_FLOW: ("방향 확인", "진행", "결과 확인"),
}
# 닻 이름 → 그 걸음의 단계. 막는 것은 레포 표의 단계 칸이 아니라 이 값을 읽는다(표의 단계 칸은 보여 주기다).
ANCHOR_STAGES = {
    (team_status.DESIGN_FLOW, "설계 대화"): "design", (team_status.DESIGN_FLOW, "설계 검토"): "design",
    (team_status.DESIGN_FLOW, "계획"): "plan", (team_status.DESIGN_FLOW, "구현"): "implement",
    (team_status.DESIGN_FLOW, "검수"): "review", (team_status.PLAIN_FLOW, "진행"): "implement",
}
Usage = team_rules.Usage
Unchecked = team_rules.Unchecked


class Step(NamedTuple):
    name: str
    who: str
    stage: str
    gate: str
    method: str
    limit: str
    tool: str
    line: int


class TableError(ValueError):
    """걸음표가 깨졌다. 글은 `<어디>:<n>행: <사유>` 꼴(절 · 표가 없으면 `<어디>: <사유>`)."""


def _cells(line: str) -> list:
    return [c.strip() for c in line.strip().split("|")[1:-1]]


def _is_separator(cells: list) -> bool:
    return bool(cells) and all(c and set(c) <= set("-:") for c in cells)


def _row(cells: list, where: str, n: int) -> Step:
    at = "%s:%d행" % (where, n)
    cells = [c or EMPTY for c in cells]
    if cells[0] == EMPTY:
        raise TableError("%s: 걸음 이름이 비었다" % at)
    name, who, stage, gate = cells[:4]
    if stage != EMPTY and stage not in team_layout.STAGES:
        raise TableError("%s: 단계 칸은 %s 이거나 %s 이다(%r)" % (at, " · ".join(team_layout.STAGES), EMPTY, stage))
    if gate != EMPTY and gate not in human_lines.KINDS:
        raise TableError("%s: 관문 칸은 %s 이거나 %s 이다(%r)" % (at, " · ".join(human_lines.KINDS), EMPTY, gate))
    return Step(name, who, stage, gate, cells[4], cells[5], cells[6], n)


def _section(lines: list, flow: str, where: str) -> list:
    """`## <흐름>` 제목 줄을 글자 그대로 찾아 그 절의 표를 읽는다. 다른 `## ` 제목이 절을 끝낸다."""
    starts = [i for i, line in enumerate(lines) if line == HEADING + flow]
    if not starts:
        raise TableError("%s: 절 `%s%s` 이 없다" % (where, HEADING, flow))
    if len(starts) > 1:
        raise TableError("%s:%d행: 절 `%s%s` 이 둘이다" % (where, starts[1] + 1, HEADING, flow))
    rows, seen = [], []
    for i in range(starts[0] + 1, len(lines)):
        line = lines[i]
        if line.startswith(HEADING):
            break
        if not line.strip().startswith("|"):
            continue
        rows.append((i + 1, line))
    if not rows:
        raise TableError("%s: 절 `%s%s` 에 표가 없다" % (where, HEADING, flow))
    n, head = rows[0]
    if not head.strip().endswith("|") or tuple(_cells(head)) != COLUMNS:
        raise TableError("%s:%d행: 머리 행이 %s 이어야 한다" % (where, n, " | ".join(COLUMNS)))
    if len(rows) < 2 or not rows[1][1].strip().endswith("|") or not _is_separator(_cells(rows[1][1])):
        raise TableError("%s:%d행: 머리 행 다음은 구분 행이어야 한다" % (where, rows[1][0] if len(rows) > 1 else n))
    steps = []
    for n, line in rows[2:]:
        cells = _cells(line)
        if not line.strip().endswith("|") or len(cells) != len(COLUMNS):
            raise TableError("%s:%d행: 칸이 %d 개여야 한다(줄 끝 `|` 포함)" % (where, n, len(COLUMNS)))
        step = _row(cells, where, n)
        if step.name in seen:
            raise TableError("%s:%d행: 걸음 이름 %r 이 겹친다" % (where, n, step.name))
        seen.append(step.name)
        steps.append(step)
    if not steps:
        raise TableError("%s: 절 `%s%s` 에 걸음이 없다" % (where, HEADING, flow))
    return steps


def parse(text: str, where: str) -> dict:
    """흐름 이름 → 그 절의 걸음들. 절 밖의 글 · 빈 줄은 건너뛰고 칸은 앞뒤 공백을 떼며 빈 칸은 `—` 로 읽는다."""
    lines = [line.rstrip("\r") for line in text.split("\n")]
    return {flow: _section(lines, flow, where) for flow in FLOWS}


def missing_anchors(tables: dict) -> list:
    """표에 없는 닻 이름들(`<흐름>: <이름>`)."""
    out = []
    for flow in FLOWS:
        have = {s.name for s in tables.get(flow, ())}
        out.extend("%s: %s" % (flow, name) for name in ANCHORS[flow] if name not in have)
    return out


def load(cwd: str) -> tuple:
    """(표, 출처 글). 설정이 가리키는 파일은 기본 브랜치의 커밋에서 읽고, 못 읽으면 기본 표로 넘어가지 않고 멈춘다."""
    try:
        resolved = repo_defaults.resolve(cwd)
        if resolved["errors"]:
            raise Unchecked(resolved["errors"][0])
        path = resolved["values"].get("walk_table")
        if path is None:
            return parse(DEFAULT_TABLE.read_text(encoding="utf-8"), DEFAULT_TABLE.name), DEFAULT_SOURCE
        top = repo_defaults._toplevel(cwd)
        commit = repo_defaults._default_commit(top)
        if commit is None:
            raise Unchecked("기본 브랜치를 알 수 없어 걸음표 파일(%s)을 읽지 못했다 — 기본 표로 넘어가지 않는다" % path)
        text = repo_defaults._read_blob(top, commit, path, "repo")
    except repo_defaults.SettingsError as exc:
        raise Unchecked(str(exc))
    if text is None:
        raise Unchecked("걸음표 파일이 기본 브랜치에 없다(%s) — 기본 표로 넘어가지 않는다" % path)
    return parse(text, path), "레포 설정 walk_table: %s@%s" % (path, commit[:8])


def _check(args: list) -> str:
    if len(args) > 1:
        raise Usage("check 는 파일을 하나까지만 받는다")
    if args:
        try:
            text = Path(args[0]).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            raise Unchecked("%s 를 읽지 못했다: %s" % (args[0], exc))
        tables, source = parse(text, args[0]), "파일 %s" % args[0]
    else:
        tables, source = load(".")
    out = "걸음표 맞음 — %s" % source + "".join(" · %s %d걸음" % (flow, len(tables[flow])) for flow in FLOWS) + "\n"
    gone = missing_anchors(tables)
    if gone:
        out += "알림: 걸음 보기가 쓰는 걸음 이름이 없다 — %s\n" % " · ".join(gone)
    return out


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    args = list(sys.argv[1:] if argv is None else argv)
    try:
        if not args or args[0] != "check":
            raise Usage("명령은 check [<파일>] 이다")
        text = _check(args[1:])
    except Usage as exc:
        print(PREFIX + "사용법 오류 — %s" % exc, file=sys.stderr)
        return 2
    except (TableError, Unchecked) as exc:
        print(PREFIX + "검사 불가 — %s" % exc, file=sys.stderr)
        return 3
    except Exception as exc:  # 반쯤 나온 출력을 내지 않는다
        print(PREFIX + "검사 불가 — 내부 오류 %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 3
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
