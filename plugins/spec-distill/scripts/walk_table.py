#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""walk_table.py — 걸음표(기본 표 · 레포가 고친 표)를 읽고 검사한다. 읽기만 하고 표준 출력으로만 낸다.

명령줄: walk_table.py check            걸음 보기가 쓸 표를 검사한다(레포 설정 walk_table 이 있으면 기본 브랜치의 그 파일)
        walk_table.py check <파일>     작업 폴더의 그 파일을 검사한다
        walk_table.py next --roadmap <로드맵> --job <과제>   걸음 보기 — 지금 걸음 · 다음 걸음과 그 칸 · 막는 것
        종료 코드 0 맞다(냈다) · 2 사용법 · 3 검사 불가. 0 이 아니면 표준 출력은 비어 있다.
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import NamedTuple, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import human_lines  # noqa: E402
import repo_defaults  # noqa: E402
import roadmap_status  # noqa: E402
import start_bundle  # noqa: E402
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


# ── 걸음 보기 ────────────────────────────────────────────────────────────────

NONE = "없음"
DONE = " (끝남)"
NEXT_USAGE = "next --roadmap <로드맵> --job <과제>"
UNKNOWN_STAGE = team_status.UNKNOWN
WAITING = "대기"
MERGED = "머지됨"
PR_OPEN = "열림"
GIT_FAILED = "git 읽기 실패 — "
NO_ANCHOR = "걸음표에 %s 걸음이 없어 %s 걸음을 가를 수 없다"


class Next(NamedTuple):
    """다음 걸음 — 닻 이름 · 보이는 이름 · 막는 것을 셀 계획 번호."""
    anchor: str
    shown: str
    plan: Optional[int]


class Trace(NamedTuple):
    """자취가 가리키는 자리 — now 는 (닻 이름, 보이는 이름)들, nxt 는 Next | None, waiting 은 대기 사유 | None."""
    now: list
    nxt: Optional[Next]
    waiting: Optional[str] = None
    notices: tuple = ()


def _next_args(args: list) -> tuple:
    got = {}
    rest = list(args)
    while rest:
        key = rest.pop(0)
        if key not in ("--roadmap", "--job") or key in got or not rest:
            raise Usage("명령은 %s 이다" % NEXT_USAGE)
        got[key] = rest.pop(0)
    if len(got) != 2:
        raise Usage("명령은 %s 이다" % NEXT_USAGE)
    roadmap, job = got["--roadmap"], got["--job"]
    if roadmap.startswith("/"):
        raise Usage("--roadmap 은 레포 상대 경로다: %s" % roadmap)
    problem = team_layout.job_name_problem(job)
    if problem:
        raise Usage(problem)
    return roadmap, job


def _plan_step(k: int, m: int) -> Next:
    """계획 k 의 「계획」 걸음 — 계획이 여럿이고 둘째 뒤면 `계획 (계획 k)` 로 보인다."""
    return Next("계획", "계획 (계획 %d)" % k if k > 1 and m > 1 else "계획", k)


def _after_merge(n: int, m: int) -> Next:
    return _plan_step(n + 1, m) if n < m else Next("회고", "회고", None)


def _design_trace(stage: str, reason: str, specs: list, plans: list, n: int, m: int, scope, pr) -> Trace:
    """설계 흐름에서 브랜치 n 의 끝을 센 단계 → 자리. pr 은 (그 브랜치의 PR 이 열림인가, 캐시를 못 읽은 사유 | None)."""
    if stage == "설계 중":
        if specs:
            return Trace([("설계 검토", "설계 검토"), ("설계 승인", "설계 승인")], Next("계획", "계획", n))
        return Trace([("설계 대화", "설계 대화")], Next("설계 검토", "설계 검토", None))
    if stage == "계획":
        if not plans:
            now = ("설계 승인", "설계 승인" + DONE) if n == 1 else ("머지", "머지 (계획 %d — 끝남)" % (n - 1))
            return Trace([now], _plan_step(n, m))
        got, _why = human_lines.passed(scope, human_lines.KIND_PLAN, n, deep=False)
        return Trace([("계획 확인", "계획 확인" + ("" if got is None else DONE))], Next("구현", "구현", n))
    if stage == "구현 중":
        return Trace([("구현", "구현")], Next("검수", "검수", n))
    if stage == "구현 끝":
        is_open, unread = pr
        if unread:
            return Trace([("검수", "검수"), ("PR 전 확인", "PR 전 확인"), ("머지", "머지")], _after_merge(n, m),
                         notices=(unread,))
        if is_open:
            return Trace([("머지", "머지")], _after_merge(n, m))
        return Trace([("검수", "검수"), ("PR 전 확인", "PR 전 확인")], Next("머지", "머지", None))
    raise Unchecked("%s — %s" % (stage, reason))


def _plain_trace(stage: str, reason: str, result, scope) -> Trace:
    """설계 없는 흐름에서 브랜치 끝을 센 단계 → 자리."""
    running, received = team_layout.PLAIN_FLOW_STAGES
    if stage == received:
        return Trace([("결과 확인", "결과 확인")], None)
    if stage != running:
        raise Unchecked("%s — %s" % (stage, reason))
    got, _why = human_lines.passed(scope, human_lines.KIND_FLOW, None, deep=False)
    if got is None:
        return Trace([("방향 확인", "방향 확인")], Next("진행", "진행", None))
    if result:
        return Trace([("진행", "진행")], Next("결과 확인", "결과 확인", None))
    return Trace([("방향 확인", "방향 확인" + DONE)], Next("진행", "진행", None))


def _start(plain: bool, waiting: Optional[str] = None) -> Trace:
    first = Next("진행", "진행", None) if plain else Next("설계 대화", "설계 대화", None)
    return Trace([("방향 확인", "방향 확인")], first, waiting)


def _pr_state(git, roadmap_rel: str, branch: str) -> tuple:
    rows, _epic_rows, reason = roadmap_status.read_pr_cache(git, roadmap_rel)
    if reason:
        return False, "PR 캐시를 읽지 못했다 — %s" % reason
    return any(r.get("브랜치") == branch and r.get("상태") == PR_OPEN for r in rows), None


def _task_line(report: dict, job: str) -> Optional[dict]:
    """상태 보고의 로드맵 밖 과제(team_status.task_jobs 가 센 것) 가운데 그 과제. 없으면 None, 셀 수 없으면 Unchecked."""
    found = [j for j in report.get("jobs") or [] if j["id"] == job]
    if len(found) > 1:
        raise Unchecked("같은 이름의 %s가 둘이다: %s — %s"
                        % (team_status.OUTSIDE, job, " · ".join(j["branch"] for j in found)))
    if found:
        return found[0]
    notes = report.get("job_notes") or []
    heads = ("%s %s " % (team_status.OUTSIDE, job), "%s %s:" % (team_status.OUTSIDE, job))
    unread = [n for n in notes if n.startswith(heads) or n.startswith((team_status.TASKS_UNCOUNTED, team_status.TASKS_PARTLY))]
    if unread:
        raise Unchecked(unread[0])
    return None


def _block_trace(git, base, reader, block: dict, mine: dict, roadmap_rel: str) -> tuple:
    """(흐름, 자리, n, m, 읽은 끝 | None, 브랜치들) — 로드맵 블록 하나."""
    plain = reader.flow(block) == team_status.PLAIN_FLOW
    flow = team_status.PLAIN_FLOW if plain else team_status.DESIGN_FLOW
    branches = list(mine.get("branches") or [])
    states = list(mine.get("branch_states") or [])
    m = len(branches)
    stage, reason = mine.get("stage") or UNKNOWN_STAGE, mine.get("reason") or ""
    if stage == UNKNOWN_STAGE:
        raise Unchecked(reason)
    active = next((i for i, st in enumerate(states) if not st.get("merged") and st.get("tip")), None)
    merged = [i for i, st in enumerate(states) if st.get("merged")]
    if active is None:
        n = merged[-1] + 1 if merged else 1
        if stage == MERGED:
            return flow, Trace([("결과 확인", "결과 확인")] if plain else [("회고", "회고")], None), n, m, None, branches
        if not merged:
            return flow, _start(plain, reason if stage == WAITING else None), n, m, None, branches
        if plain:
            raise Unchecked("설계 없는 흐름의 %s 에서 다음 브랜치가 없다 — 걸음을 가를 수 없다(%s)" % (stage, reason))
        return flow, Trace([("머지", "머지 (계획 %d — 끝남)" % n)], _after_merge(n, m)), n, m, None, branches
    n = active + 1
    tip = mine.get("tip") or states[active]["tip"]
    copy = dict(block, branches=branches, notes=[])
    got, why, specs, plans = reader.progress(tip, copy, n)
    scope = reader.scope(tip, block["id"], branches)
    if plain:
        return flow, _plain_trace(got, why, (copy.get("job") or {}).get("result"), scope), n, m, tip, branches
    pr = _pr_state(git, roadmap_rel, branches[active]) if got == "구현 끝" else (False, None)
    return flow, _design_trace(got, why, specs, plans, n, m, scope, pr), n, m, tip, branches


def _task_trace(reader, task: dict) -> tuple:
    """(흐름, 자리, n, m, 읽은 끝 | None, 브랜치들) — 로드맵 밖 과제(설계 없는 흐름)."""
    flow, branches = team_status.PLAIN_FLOW, [task["branch"]]
    stage, reason, tip = task["stage"], task["reason"], task.get("tip")
    if stage == team_status.MERGED:
        return flow, Trace([("결과 확인", "결과 확인")], None), 1, 1, None, branches
    if tip is None:
        if stage == UNKNOWN_STAGE:
            raise Unchecked(reason)
        return flow, _start(True), 1, 1, None, branches
    copy = {"id": task["id"], "kind": task["kind"], "fields": {}, "reserved": [], "notes": []}
    got, why, _specs, _plans = reader.progress(tip, copy, 1)
    scope = reader.scope(tip, task["id"], branches)
    return flow, _plain_trace(got, why, (copy.get("job") or {}).get("result"), scope), 1, 1, tip, branches


def _group(steps: list, flow: str, now: list) -> str:
    """지금 걸음 묶음 — 닻 행마다 그 행과 그 뒤에 이어진 기본 이름이 아닌 행들(K4)."""
    names = [s.name for s in steps]
    out = []
    for anchor, shown in now:
        if anchor not in names:
            raise Unchecked(NO_ANCHOR % (anchor, "지금"))
        out.append(shown)
        for step in steps[names.index(anchor) + 1:]:
            if step.name in ANCHORS[flow]:
                break
            out.append(step.name)
    return " · ".join(out)


def _step_of(steps: list, anchor: str) -> Step:
    found = next((s for s in steps if s.name == anchor), None)
    if found is None:
        raise Unchecked(NO_ANCHOR % (anchor, "다음"))
    return found


def next_lines(cwd: str, roadmap: str, job: str) -> list:
    """걸음 보기의 줄들. 자취는 상태 계산(roadmap_status.build · team_status.Reader.progress)에서 받고, 칸은 걸음표에서,
    막는 것은 닻 이름의 단계(ANCHOR_STAGES)로 human_lines 의 관문 표를 꼴 판정으로 센다. 시작 묶음과 같은 길로 연다 —
    open_base 는 작업 폴더(os.getcwd())에서 레포를 찾는다."""
    git = roadmap_status.Git(cwd)
    base = start_bundle.open_base(git, roadmap)
    tables, source = load(cwd)
    blocks = start_bundle._blocks(git, base)
    block = start_bundle._block(blocks, job)
    rel = base.team.roadmap
    report = roadmap_status.build(git, argparse.Namespace(roadmap=rel, roadmap_file=None, json=False))
    failed = [r for r in report.get("unknown_reasons") or [] if r.startswith(GIT_FAILED)]
    if failed:
        raise Unchecked(failed[0])
    reader = start_bundle._reader(git, base)
    told = len(git.failures)
    if block is None:
        task = _task_line(report, job)
        if task is None:
            raise Usage("%s 는 로드맵의 과제 블록도 %s도 아니다" % (job, team_status.OUTSIDE))
        flow, trace, n, m, tip, branches = _task_trace(reader, task)
    else:
        mine = next((b for b in report.get("blocks") or [] if b.get("id") == job), None)
        if mine is None:
            raise Unchecked("상태 보고에 %s 블록이 없다 — %s" % (job, " · ".join(
                (report.get("format_errors") or []) + (report.get("unknown_reasons") or [])) or "사유 없음"))
        flow, trace, n, m, tip, branches = _block_trace(git, base, reader, block, mine, rel)
    steps = tables[flow]
    now = _group(steps, flow, trace.now)
    blocker = NONE
    if trace.waiting:
        blocker = trace.waiting
    elif trace.nxt is not None:
        stage = ANCHOR_STAGES.get((flow, trace.nxt.anchor))
        if stage is not None:
            plain = flow == team_status.PLAIN_FLOW
            plan = trace.nxt.plan if not plain and stage in team_layout.PLANNED_STAGES else None
            scope = reader.scope(tip or base.commit, job, branches)
            reasons = human_lines.missing(scope, stage, plan, plain, deep=False)
            blocker = reasons[0] if reasons else NONE
    if trace.nxt is None:
        nxt = NONE
    else:
        row = _step_of(steps, trace.nxt.anchor)
        nxt = "%s — 누가 %s · 작업 방식 %s · 상한 %s · 도구 %s" % (trace.nxt.shown, row.who, row.method, row.limit, row.tool)
    if len(git.failures) > told:
        raise Unchecked(GIT_FAILED + git.failures[-1])
    lines = []
    if not reader.gate_on():
        lines.append("알림: %s" % human_lines.GATE_OFF)
    lines += ["알림: %s" % note for note in trace.notices]
    lines += ["표: %s" % source,
              "흐름: %s" % flow + (" · 계획 %d/%d" % (n, m) if m >= 2 else ""),
              "지금 걸음: %s" % now,
              "다음 걸음: %s" % nxt,
              "막는 것: %s" % blocker]
    return lines


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    args = list(sys.argv[1:] if argv is None else argv)
    try:
        if args and args[0] == "next":
            roadmap, job = _next_args(args[1:])
            text = "".join(line + "\n" for line in next_lines(os.getcwd(), roadmap, job))
        elif args and args[0] == "check":
            text = _check(args[1:])
        else:
            raise Usage("명령은 check [<파일>] · %s 이다" % NEXT_USAGE)
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
