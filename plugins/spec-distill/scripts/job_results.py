#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""job_results.py — team 형식의 결과 대조 · 받음 줄 다시 계산 · 낡음 판정. 읽기만 한다.

git 은 받은 `roadmap_status.Git` 으로 읽는다(이 파일은 subprocess 를 쓰지 않는다 — 명령줄의 브랜치 끝 고르기는
`team_status.read_tip` → `branch_tip.tip` 이 읽기 전용 git 으로 한다). `roadmap_status` 는 맨 위에서
import 하지 않는다 — 그쪽이 이 모듈을 가져오므로 `main()` 안에서 가져온다.

명령줄: job_results.py check --roadmap <로드맵 레포 상대경로> --job <과제> --result <결과 파일 이름>
                            [--branch <브랜치>] [--date <YYYY-MM-DD>]
        기본 브랜치의 로드맵을 읽어 과제 브랜치 끝의 결과 파일을 대조한다. `--branch` 가 없으면 블록의 브랜치 가운데
        결과 파일 이름의 계획 번호 번째(계획 번호가 없으면 첫째)다. 브랜치 끝은 team_status.read_tip 이 고른다.
        첫 줄이 대조 결과이고, 통과하면 리더가 결정 기록에 적을 받음 줄을 낸다.
        종료 코드 0 통과 · 1 거절 · 2 사용법 · 3 검사 불가
"""
from __future__ import annotations

import argparse
import datetime
import os
import sys
from pathlib import Path
from typing import NamedTuple, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import team_files  # noqa: E402
import team_layout  # noqa: E402
from check_bundle_coverage import AC_TOKEN_RE, acceptance_ids, check_impl  # noqa: E402
from workflow_superpowers import task_text  # noqa: E402

RECEIVED, NOT_RECEIVED, NOT_COUNTED, STALE = "받음", "없음", "세지 않음", "낡음"
FIRST_HEAD = "결과 대조: "
SHOWN_FILES = 5
NOT_A_FILE = "파일이 아닌 경로다(블롭이 아니다): %s"
UNFINISHED = "대조를 끝내지 못했다 — 첫 줄에 실을 수를 얻지 못했다"
PREFIX = "[spec-distill] "
NOT_COUNTED_HEAD, STALE_HEAD = "받음 줄을 세지 않았다", "받은 뒤 바뀜"


def file_note(head: str, name: str, why: str) -> str:
    """결과 파일 하나의 알림 줄 — `<머리>: <결과 파일 이름> — <사유>`."""
    return "%s: %s — %s" % (head, name, why)


def same_fact(note: str, name: str, why: str) -> bool:
    """note 가 머리와 상관없이 결과 파일 name 의 사유 why 를 말하는 file_note 인가 — 한 사실에 알림 하나를 지키는 데 쓴다."""
    return note.endswith(file_note("", name, why))


class Check(NamedTuple):
    ok: bool
    first: str
    problems: list
    unknown: list
    result: object   # 읽힌 team_files.Result 또는 None


def result_names(git, tip: str, team, job: str) -> Optional[list]:
    """결과 폴더의 이름 가운데 결과 파일 이름 꼴인 것(정렬). 막힘 파일 · 자리 지킴 파일은 들지 않는다. 못 읽으면 None."""
    names = git.names(tip, team.results(job))
    if names is None:
        return None
    return [n for n in names if team_layout.parse_result_name(n) is not None]


def newest(names: list, stage: str, plan) -> Optional[str]:
    """그 단계 · 그 계획(None 은 계획 번호 없는 이름)의 가장 큰 시도의 이름. 없으면 None."""
    best = None
    for name in names:
        parsed = team_layout.parse_result_name(name)
        if parsed and parsed[0] == stage and parsed[1] == plan and (best is None or parsed[2] > best[1]):
            best = (name, parsed[2])
    return best[0] if best else None


def plan_scope(plan_text, acs: list) -> list:
    """계획의 task 절에 나오는 AC 가운데 acs 에 있는 것(acs 의 차례). plan_text 가 None 이면 acs 전부."""
    if plan_text is None:
        return list(acs)
    have = {"AC" + m.group(1) for m in AC_TOKEN_RE.finditer(task_text(plan_text))}
    return [a for a in acs if a in have]


def _short(commit) -> str:
    return (commit or "")[:8]


def _read(git, rev: str, path: str) -> tuple:
    """(글 | None, 없음이 확인됐나). 글도 없고 없음도 확인되지 않으면 늘 failures 에 한 줄이 남는다 — git 이 실패했거나
    그 경로가 파일이 아니다(폴더 · 서브모듈). 부르는 쪽은 그 줄을 unknown 으로 옮긴다."""
    text = git.blob(rev, path)
    if text is not None:
        return text, False
    failed_before = len(git.failures)
    if git.absent(rev, path):
        return None, True
    if len(git.failures) == failed_before:   # cat-file -e 가 rc 0 — 경로는 있는데 블롭이 아니다
        git.failures.append(NOT_A_FILE % path)
    return None, False


def _unread(r) -> bool:
    """머리를 읽지 못해 parse_result 가 본문을 읽지 않은 결과."""
    return not r.machine_text and all(v is None for v in (r.stage, r.plan, r.attempt, r.role, r.head, r.bundle_at, r.job_at))


def _ancestor(git, a: str, b: str) -> Optional[bool]:
    rc, _out, err = git.run_err("merge-base", "--is-ancestor", a, b)
    if rc in (0, 1):
        return rc == 0
    git.fail("merge-base", rc, err)
    return None


def _commit_problems(git, r, tip: str) -> list:
    out = []
    if r.head:
        if git.commit(r.head) is None:
            out.append("머리 head %s 가 없는 커밋이다" % _short(r.head))
        elif _ancestor(git, r.head, tip) is False:
            out.append("머리 head %s 가 과제 브랜치에 없다 — 끝 %s 의 조상이 아니다" % (_short(r.head), _short(tip)))
    for key, value in (("bundle_at", r.bundle_at), ("job_at", r.job_at)):
        if value and git.commit(value) is None:
            out.append("머리 %s %s 가 없는 커밋이다" % (key, _short(value)))
    return out


def _ac_check(git, tip: str, team, job: str, r, design: str, problems: list, unknown: list) -> Optional[str]:
    """설계 흐름의 수용 기준 대조. 통과면 첫 줄의 꼬리(`AC <n>개(…)`), 아니면 None."""
    acs = acceptance_ids(design)
    if acs is None:
        unknown.append("설계문서에 수용 기준 절이 없다: %s" % team.design(job))
        return None
    plan_text = None
    if r.plan is not None:
        plan_text, missing = _read(git, tip, team.plan(job, r.plan))
        if plan_text is None and not missing:
            return None   # 계획 파일을 읽지 못했다 — git 실패가 unknown 으로 옮겨진다
    scope = plan_scope(plan_text, acs)
    if plan_text is not None and not scope:   # 셀 수 없는 범위를 0 개로 세어 통과시키지 않는다
        unknown.append("범위를 정할 수 없다 — %s 의 task 절에 설계문서의 AC 가 없다" % team.plan(job, r.plan))
        return None
    ri = check_impl(design, r.machine_text, only=scope)
    if ri["status"] == 3:
        problems.append("수용 기준 대조를 할 수 없다 — %s" % ri["reason"])
        return None
    if ri["unreported"]:
        problems.append("보고에 없는 AC — %s" % " · ".join(ri["unreported"]))
    if ri["unknown_acs"]:
        problems.append("설계문서에 없는 AC 가 보고에 있다 — %s" % " · ".join(ri["unknown_acs"]))
    c = ri["counts"]
    return "AC %d개(구현됨 %d · 미룸 %d · 빠짐 %d)" % (ri["ac_count"], c["구현됨"], c["미룸"], c["빠짐"])


def _output_check(git, r, problems: list) -> str:
    if not r.outputs:
        problems.append("산출물 줄이 없다 — 설계문서가 없는 과제는 `산출물: <경로>` 를 하나 이상 적는다")
    elif r.head:
        for path in r.outputs:
            if git.absent(r.head, path):
                problems.append("산출물 경로가 head 커밋에 없다: %s" % path)
    return "산출물 %d개" % len(r.outputs)


def check_result(git, tip: str, team, job: str, name: str, newer_ok: bool = False) -> Check:
    """tip 의 결과 파일 name 을 대조한다. 사유는 모두 모아 problems 에, 읽지 못한 것은 unknown 에 한 줄씩 둔다.

    newer_ok 가 참이면 「더 새 시도가 있다」 사유 하나만 넣지 않는다(앞 시도의 받음을 다시 잴 때 — 다른 사유는 그대로)."""
    failed_before = len(git.failures)
    problems, unknown, r, tail = [], [], None, None
    parsed = team_layout.parse_result_name(name)
    if parsed is None:
        problems.append("결과 파일 이름 꼴이 아니다(<단계>-<시도>.md · <단계>-plan-<n>-<시도>.md): %s" % name)
    else:
        path = team.result(job, parsed[0], parsed[2], parsed[1])
        text, missing = _read(git, tip, path)
        if text is None:
            if missing:
                problems.append("그 끝(%s)에 결과 파일이 없다: %s" % (_short(tip), path))
        else:
            r = team_files.parse_result(text)
            tail = _check_body(git, tip, team, job, name, parsed, r, problems, unknown, newer_ok)
    unknown += git.failures[failed_before:]
    if not unknown and not problems and tail is None:   # 통과는 첫 줄의 수를 얻었을 때만이다
        unknown.append(UNFINISHED)
    if unknown:
        first = "%s검사 불가 — %s" % (FIRST_HEAD, name)
    elif problems:
        first = "%s거절 %d건 — %s" % (FIRST_HEAD, len(problems), name)
    else:
        first = "%s통과 — %s · head %s · %s" % (FIRST_HEAD, name, _short(r.head), tail)
    return Check(not unknown and not problems, first, problems, unknown, r)


def _check_body(git, tip: str, team, job: str, name: str, parsed: tuple, r, problems: list, unknown: list, newer_ok: bool):
    problems += r.problems
    if _unread(r):
        return None
    if (r.stage, r.plan, r.attempt) != parsed:
        problems.append("머리의 단계 · 계획 · 시도(%s · %s · %s)가 이름과 다르다 — %s" % (r.stage, r.plan, r.attempt, name))
    if r.end is None:
        if not any(p.startswith(team_files.END_EMPTY) for p in r.problems):
            problems.append("끝 줄이 없다 — 아직 도는 중이다")
    elif r.head and r.end != r.head:
        problems.append("끝 줄의 커밋 %s 가 머리의 head 와 다르다(%s)" % (_short(r.end), _short(r.head)))
    problems += _commit_problems(git, r, tip)
    names = result_names(git, tip, team, job)
    if names is not None and not newer_ok:
        latest = newest(names, parsed[0], parsed[1])
        if latest and team_layout.parse_result_name(latest)[2] > parsed[2]:
            problems.append("같은 단계 · 같은 계획의 더 새 시도 %s 가 있다" % latest)
    design, missing = _read(git, tip, team.design(job))
    if design is not None:
        return _ac_check(git, tip, team, job, r, design, problems, unknown)
    if missing:
        return _output_check(git, r, problems)
    return None


def _same_place(name: str, stage: str, plan) -> bool:
    parsed = team_layout.parse_result_name(name)
    return parsed is not None and parsed[0] == stage and parsed[1] == plan


def _kept(path: str, job_dir: str, design: str, outputs: list) -> bool:
    """받은 뒤 바뀐 파일로 셀 것인가. 과제 폴더 안에서는 설계문서 · 계획 파일 · 산출물만 센다."""
    if not path.startswith(job_dir):
        return True
    if path == design or team_layout.plan_number(path[len(job_dir):]) is not None:
        return True
    return any(path == o or path.startswith(o.rstrip("/") + "/") for o in outputs)


def receipt(git, main: str, tip: str, team, job: str, intent_text: str, stage: str, plan,
            reserved: list, outputs: list) -> tuple:
    """(상태, 알림 줄 목록, 가장 새 결과 파일 이름 | None). 결정 기록의 받음 줄을 그 결과 파일로 다시 잰다.

    그 단계 · 그 계획의 받음 줄 가운데 마지막 줄을 쓴다. intent_text 를 읽지 못하면 team_files 의 FormatError 가 난다."""
    names = result_names(git, tip, team, job)
    if names is None:
        return NOT_COUNTED, ["받음 줄을 세지 않았다: 결과 폴더를 읽지 못했다"], None
    latest = newest(names, stage, plan)
    if latest is None:
        return NOT_RECEIVED, [], None
    good, broken = team_files.received(intent_text)
    notes = ["받음 줄을 세지 않았다: 꼴이 깨졌다 — %s" % line for line in broken]
    mine = [x for x in good if _same_place(x.name, stage, plan)]
    if not mine:
        return NOT_RECEIVED, notes, latest
    last = mine[-1]
    if team_layout.parse_result_name(last.name)[2] < team_layout.parse_result_name(latest)[2]:
        return STALE, notes + [file_note(STALE_HEAD, last.name, "더 새 시도 %s 가 있다" % latest)], latest
    c = check_result(git, tip, team, job, last.name)
    if not c.ok:
        return NOT_COUNTED, notes + [file_note(NOT_COUNTED_HEAD, last.name, (c.problems + c.unknown)[0])], latest
    head = c.result.head
    if last.commit != head:
        return NOT_COUNTED, notes + [file_note(NOT_COUNTED_HEAD, last.name, "받음 줄의 커밋 %s 가 결과 파일의 head %s 와 다르다"
                                               % (_short(last.commit), _short(head)))], latest
    job_dir = team.job(job) + "/"
    design = team.design(job)
    if not main:   # 기본 브랜치를 빼지 못하면 합쳐 들어온 변경과 이 과제의 변경을 가르지 못한다
        return NOT_COUNTED, notes + [file_note(NOT_COUNTED_HEAD, last.name, "기본 브랜치를 몰라 받은 뒤의 변경을 가르지 못했다")], latest
    changed = git.touched(tip, [head, main], list(reserved) + list(outputs) + [design, job_dir])
    if changed is None:
        return NOT_COUNTED, notes + [file_note(NOT_COUNTED_HEAD, last.name, "받은 뒤의 변경을 읽지 못했다")], latest
    left = [p for p in changed if _kept(p, job_dir, design, outputs)]
    if left:
        shown = " · ".join(left[:SHOWN_FILES])
        if len(left) > SHOWN_FILES:
            shown += " 외 %d개" % (len(left) - SHOWN_FILES)
        return STALE, notes + [file_note(STALE_HEAD, last.name, shown)], latest
    return RECEIVED, notes, latest


def failed_attempts(git, tip: str, team, job: str, intent_text: str, plan, before: int) -> list:
    """그 계획의 implement 시도 가운데 번호가 before 보다 작은 것을 큰 번호부터 보아, 「끝」 줄이 있고 산 받음 줄이 없는
    시도의 이름들(이어지는 만큼). 머리를 읽지 못한 시도 · 「끝」 줄이 없는 시도 · 산 받음 줄이 있는 시도를 만나면 멈춘다(J12).
    끝났으나 꼴 문제가 있는 시도는 실패로 센다. 결과 파일을 git 이 읽지 못하면 Unchecked 를 낸다.

    산 받음 줄 — 그 결과 파일의 이름과 머리 head 를 가리키는 꼴 맞는 받음 줄이 있고 그 결과 파일이 「더 새 시도」 사유 없이
    결과 대조를 지난다. 막힘 파일은 결과 파일 이름이 아니라 시도가 아니다."""
    names = result_names(git, tip, team, job)
    if names is None:
        raise Unchecked("결과 폴더를 읽지 못했다: %s" % team.results(job))
    stage = team_layout.STAGES[2]
    mine = []
    for name in names:
        parsed = team_layout.parse_result_name(name)
        if parsed and parsed[0] == stage and parsed[1] == plan and parsed[2] < before:
            mine.append((parsed[2], name))
    good, _broken = team_files.received(intent_text)
    out = []
    for _attempt, name in sorted(mine, reverse=True):
        path = team.job(job, team_layout.RESULTS_DIR, name)
        text = git.blob(tip, path)
        if text is None:   # 있는데 읽지 못했다 — 이어짐을 끊지 않고 검사 불가로 낸다
            raise Unchecked("결과 파일을 읽지 못했다: %s" % path)
        r = team_files.parse_result(text)
        if _unread(r) or (r.end is None and not any(x.startswith(team_files.END_EMPTY) for x in r.problems)):   # 머리를 읽지 못한 시도 · 도는 중인 시도(끝 줄이 없다)만 끊는다
            break
        if any(x.name == name and x.commit == r.head for x in good) and check_result(git, tip, team, job, name, newer_ok=True).ok:
            break
        out.append(name)   # 끝났으나 꼴 문제가 있는 시도는 산 받음 줄을 가질 수 없는 실패다
    return out


def failed_streak(git, tip: str, team, job: str, intent_text: str, plan, before: int) -> int:
    """연속 실패 수 — failed_attempts 의 길이."""
    return len(failed_attempts(git, tip, team, job, intent_text, plan, before))


# ── 명령줄 ───────────────────────────────────────────────────────────────────

class Usage(Exception):
    pass


class Unchecked(Exception):
    pass


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="job_results.py", description="team 형식의 결과 대조")
    sub = ap.add_subparsers(dest="cmd")
    sub.required = True
    p = sub.add_parser("check")
    p.add_argument("--roadmap", required=True)
    p.add_argument("--job", required=True)
    p.add_argument("--result", required=True)
    p.add_argument("--branch")
    p.add_argument("--date")
    return ap


def _date(value) -> str:
    if value is None:
        return datetime.date.today().isoformat()
    try:
        if len(value) != 10:
            raise ValueError(value)
        return datetime.date.fromisoformat(value).isoformat()
    except ValueError:
        raise Usage("--date 는 YYYY-MM-DD 꼴의 있는 날짜다: %r" % value)


def _branch_of(roadmap_text: str, job: str, result: str) -> str:
    from roadmap_model import FormatError, parse_roadmap
    try:
        _meta, blocks, _records, _risk, _errors = parse_roadmap(roadmap_text)
    except FormatError as exc:
        raise Unchecked("로드맵을 읽지 못해 블록의 브랜치를 고르지 못했다 — %s" % exc)
    block = next((b for b in blocks if b.get("id") == job and b.get("kind") != "decision"), None)
    if block is None:
        raise Usage("로드맵 블록이 아닌 과제(%s)는 --branch <브랜치> 가 필요하다" % job)
    branches = block.get("branches") or []
    parsed = team_layout.parse_result_name(result)
    n = parsed[1] if parsed and parsed[1] is not None else 1
    if n > len(branches):
        raise Usage("블록 %s 의 브랜치 칸에 계획 %d 의 브랜치가 없다(브랜치 %d개) — --branch 로 준다" % (job, n, len(branches)))
    return branches[n - 1]


def _check(a) -> int:
    import repo_defaults
    import roadmap_status
    from roadmap_model import frontmatter
    date = _date(a.date)
    problem = team_layout.job_name_problem(a.job)
    if problem:
        raise Usage(problem)
    git = roadmap_status.Git(os.getcwd())
    top = git.toplevel()
    if top is None:
        raise Unchecked("git 레포 안이 아니다")
    resolved = repo_defaults.resolve(top)
    if resolved["errors"]:
        raise Unchecked("레포 설정을 읽지 못했다 — %s" % resolved["errors"][0])
    try:
        team = team_layout.team_from_roadmap(resolved["values"]["roadmaps_dir"], a.roadmap.strip("/"))
    except ValueError as exc:
        raise Usage(str(exc))
    main, main_name = git.default_branch()
    if main is None:
        raise Unchecked(git.default_reason or "기본 브랜치(origin/HEAD)를 모른다")
    text, missing = _read(git, main, team.roadmap)
    if text is None:
        raise Unchecked("기본 브랜치에 로드맵이 없다: %s (%s)" % (team.roadmap, main_name) if missing
                        else "로드맵을 읽지 못했다: %s — %s" % (team.roadmap, (git.failures or ["?"])[-1]))
    try:
        layout = team_layout.layout_of(frontmatter(text))
    except team_layout.UnknownLayout as exc:
        layout = exc.value
    if layout != team_layout.LAYOUT_TEAM:
        raise Usage("team 형식 로드맵이 아니다 — %s 머리말에 `%s: %s` 가 없다"
                    % (team.roadmap, team_layout.LAYOUT_KEY, team_layout.LAYOUT_TEAM))
    branch = a.branch or _branch_of(text, a.job, a.result)
    import team_status
    tip, tip_note, split = team_status.read_tip(git, branch)
    if split:
        raise Unchecked(split)
    if tip is None:
        raise Unchecked("브랜치 %s 가 로컬에도 origin 에도 없다" % branch)
    c = check_result(git, tip, team, a.job, a.result)
    print(c.first)
    if tip_note:
        print(tip_note)
    print("브랜치: %s · 끝 %s" % (branch, tip[:8]))
    for p in c.problems:
        print("거절 사유: %s" % p)
    for u in c.unknown:
        print("검사 불가 사유: %s" % u)
    if c.ok:
        print("리더가 과제의 결정 기록에 적을 받음 줄:")
        print(team_files.received_line(date, a.result, c.result.head, c.first))
        return 0
    return 3 if c.unknown else 1


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    a = build_parser().parse_args(argv)
    try:
        return _check(a)
    except Usage as exc:
        print(PREFIX + "사용법 오류 — %s" % exc, file=sys.stderr)
        return 2
    except Unchecked as exc:
        print(FIRST_HEAD + "검사 불가 — %s" % exc)
        return 3
    except Exception as exc:  # 대조가 죽어도 통과(0) · 거절(1)로 내지 않는다
        print(FIRST_HEAD + "검사 불가 — 내부 오류 %s: %s" % (type(exc).__name__, exc))
        return 3


if __name__ == "__main__":
    sys.exit(main())
