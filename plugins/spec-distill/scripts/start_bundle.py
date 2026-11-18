#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""start_bundle.py — 일꾼이 시작할 때 받는 묶음. 읽기만 하고 표준 출력으로만 낸다.

모든 글은 기본 브랜치의 커밋에서 읽는다(작업 폴더의 사본은 읽지 않는다). 팀 규칙 파일만
`team_layout.leader_ref` 가 말하는 커밋에서 읽는다(리더가 쓰는 파일).

과제 폴더(INTENT.md · 설계 · 계획 · 결과 파일)는 과제 브랜치의 끝에서 읽는다 — 끝은 `team_status.read_tip` 이 고르고,
브랜치가 아직 없으면 기준 커밋에서 읽고 알린다.

명령줄: start_bundle.py --roadmap <로드맵 레포 상대경로> --role <리더 역할>
        start_bundle.py --roadmap <로드맵 레포 상대경로> --job <과제> --stage <단계> [--plan <n>] [--role <역할>]
        종료 코드 0 묶음을 냈다 · 1 멈춤 · 2 사용법 · 3 검사 불가. 0 이 아니면 표준 출력은 비어 있다.
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import NamedTuple, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import job_results  # noqa: E402
import repo_defaults  # noqa: E402
import roadmap_status  # noqa: E402
import team_files  # noqa: E402
import team_layout  # noqa: E402
import team_rules  # noqa: E402
import team_status  # noqa: E402
from roadmap_model import DEFAULT_REF, FormatError, parse_roadmap  # noqa: E402
from workflow_superpowers import place_sentence  # noqa: E402

PREFIX = "[spec-distill] "
Usage = team_rules.Usage
Unchecked = team_rules.Unchecked
DESIGN, PLAN, REVIEW = team_layout.STAGES[0], team_layout.STAGES[1], team_layout.STAGES[3]
NO_BRANCH = "과제 브랜치 %s 가 아직 없다 — 과제 폴더를 기준 커밋에서 읽었다"
NO_BRANCH_FIELD = "블록 %s 의 브랜치 칸에 브랜치가 없다"
ALREADY_MERGED = "%s 는 이미 기본 브랜치에 머지됐다"
PLAIN_NO_PLAN = "설계 없는 흐름의 결과 파일에는 계획 번호가 붙지 않는다"
SYNC_LINE = "맞추는 명령: roadmap_write.py job sync --result %s --role %s --bundle-at %s --job-at %s"


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


# ── 과제 묶음 ────────────────────────────────────────────────────────────────

def result_number(plain: bool, stage: str, plan: Optional[int]) -> Optional[int]:
    """결과 파일 이름에 붙는 계획 번호(U1) — 설계 없는 흐름은 늘 None, 설계 흐름은 design 이 None 이고 그 밖은 plan."""
    if plain or stage == DESIGN:
        return None
    return plan


def attempt_of(names: list, read, stage: str, number: Optional[int]) -> tuple:
    """(시도 번호, 바로 앞 시도의 이름 | None). read(이름) 은 그 결과 파일의 글이나 None.

    그 단계 · 그 계획의 결과 파일이 없으면 (1, None). 가장 새 시도에 끝 줄이 없고 읽지 못한 것(parse_result 의 문제 —
    머리 값의 꼴 포함)도 없으면 그 번호를 잇고(U2), 끝 줄이 있거나 읽지 못하면 다음 번호다(C6)."""
    latest = job_results.newest(names, stage, number)
    if latest is None:
        return 1, None
    attempt = team_layout.parse_result_name(latest)[2]
    text = read(latest)
    result = team_files.parse_result(text) if text is not None else None
    if result is None or result.problems or result.end is not None:
        attempt += 1
    earlier = [n for n in names if (team_layout.parse_result_name(n) or (None, None, attempt))[2] < attempt]
    return attempt, job_results.newest(earlier, stage, number)


def _reader(git, base: Base):
    return team_status.Reader(git, base.commit, base.team, lambda path: git.blob(base.commit, path),
                              lambda path: git.absent(base.commit, path))


def _block(blocks: list, job: str):
    return next((b for b in blocks if b.get("id") == job and b.get("kind") != "decision"), None)


def _branch_commit(git, base: Base, branch: str) -> tuple:
    """(과제 폴더를 읽을 커밋, 알림들) — 끝은 read_tip 이 고른다. 브랜치가 없으면 기준 커밋(U4), 갈라졌으면 Unchecked."""
    tip, note, split = team_status.read_tip(git, branch)
    if split:
        raise Unchecked("과제 브랜치 %s: %s" % (branch, split))
    if tip is None:
        return base.commit, [NO_BRANCH % branch]
    return tip, [note] if note else []


def _task(reader, blocks: list, job: str) -> dict:
    """로드맵 밖 과제 job(I8 — team_status.task_jobs 가 센 것). 둘이거나 없으면 Refused, 세지 못했으면 Unchecked."""
    failed_before = len(reader.git.failures)
    jobs, notes = team_status.task_jobs(reader, blocks)
    found = [j for j in jobs if j["id"] == job]
    if len(found) > 1:
        raise Refused("같은 이름의 %s가 둘이다: %s — %s"
                      % (team_status.OUTSIDE, job, " · ".join(j["branch"] for j in found)))
    if found and found[0]["stage"] == team_status.MERGED:
        raise Refused(ALREADY_MERGED % job)
    if found:
        return found[0]
    heads = ("%s %s " % (team_status.OUTSIDE, job), "%s %s:" % (team_status.OUTSIDE, job))
    mine = [n for n in notes if n.startswith(heads)]
    if mine and all(" 을 세지 않았다 — " in n for n in mine):
        raise Refused(mine[0])
    unread = mine + [n for n in notes if n.startswith((team_status.TASKS_UNCOUNTED, team_status.TASKS_PARTLY))]
    if unread:
        raise Unchecked(unread[0])
    if len(reader.git.failures) > failed_before:
        raise Unchecked("%s — %s" % (team_status.TASKS_UNCOUNTED, reader.git.failures[-1]))
    raise Refused("%s 는 로드맵의 과제 블록도 %s도 아니다" % (job, team_status.OUTSIDE))


def locate(git, base: Base, blocks: list, job: str, plan: Optional[int]) -> tuple:
    """(과제 브랜치 커밋, 흐름이 설계 없는 흐름인가, 단순 작업인가, 알림들).

    에픽은 블록 `브랜치:` 의 plan 번째(없으면 첫째, I12), 단순 작업은 INTENT.md 머리 branch(I8). 끝은 read_tip 이 고른다."""
    reader = _reader(git, base)
    block = _block(blocks, job)
    if block is None:
        task = _task(reader, blocks, job)
        commit, notices = _branch_commit(git, base, task["branch"])
        return commit, True, True, notices
    plain = reader.flow(block) == team_status.PLAIN_FLOW
    branches = block.get("branches") or []
    if not branches:
        raise Refused(NO_BRANCH_FIELD % job)
    n = plan or 1
    if n > len(branches):
        raise Refused("블록 %s 의 브랜치 칸에 %d 번째 브랜치가 없다(브랜치 %d개)" % (job, n, len(branches)))
    commit, notices = _branch_commit(git, base, branches[n - 1])
    return commit, plain, False, notices


def _plan_rule(stage: str, plan: Optional[int], plain: bool) -> None:
    """흐름에 따른 --plan 규칙(설계 §9 · U1) — 어기면 Usage."""
    if plain and plan is not None and stage != PLAN:
        raise Usage("%s — --plan 은 %s 단계에서만 준다" % (PLAIN_NO_PLAN, PLAN))
    if not plain and plan is None and stage in team_layout.PLANNED_STAGES:
        raise Usage("설계 흐름의 %s 단계는 --plan 을 준다" % stage)


def _blocks(git, base: Base) -> list:
    text = git.blob(base.commit, base.team.roadmap)
    if text is None:
        raise Unchecked("로드맵을 읽지 못했다: %s" % base.team.roadmap)
    try:
        _meta, blocks, _records, _risks, errors = parse_roadmap(text)
    except FormatError as exc:
        raise Unchecked("로드맵을 읽지 못했다 — %s" % exc)
    if not blocks and errors:
        raise Unchecked("로드맵을 읽지 못했다 — %s" % errors[0])
    return blocks


def _intent(git, commit: str, path: str, job: str, roadmap: str) -> str:
    """읽을 커밋의 INTENT.md 글. 없거나 머리의 job · roadmap 이 인자와 다르면 Refused, 읽지 못하면 Unchecked."""
    text = git.blob(commit, path)
    if text is None:
        if git.absent(commit, path):
            raise Refused("%s 가 %s 에 없다" % (path, commit))
        raise Unchecked("읽지 못했다: %s" % path)
    try:
        meta = team_files.intent_meta(text)
    except FormatError as exc:
        raise Refused("%s 머리를 읽지 못했다 — %s" % (path, exc))
    try:
        head_roadmap = team_files.roadmap_rel(meta)
    except FormatError as exc:
        raise Refused("%s 머리를 읽지 못했다 — %s" % (path, exc))
    for key, got, want in (("job", meta.get("job"), job), ("roadmap", head_roadmap, roadmap)):
        if got != want:
            raise Refused("%s 머리의 %s 가 인자와 다르다: %r — 인자 %s" % (path, key, got, want))
    return text


def _original_line(base: Base, intent: str, path: str, stage: str) -> str:
    """`원자료:` 줄 — design 은 범위 없이 전체, 그 밖은 INTENT.md 의 범위 줄(조각마다 `<a>–<b>행`)."""
    line = "원자료: %s:%s" % (base.commit, base.team.original)
    if stage == DESIGN:
        return line
    try:
        ranges = team_files.intent_ranges(intent)
    except FormatError as exc:
        raise Refused("%s 의 지시 원문 범위를 읽지 못했다 — %s" % (path, exc))
    if not ranges:
        raise Refused("%s 의 지시 원문에 %s 의 줄 범위가 없다" % (path, base.team.original))
    return "%s %s" % (line, " · ".join("%d–%d행" % r for r in ranges))


def _review_block(git, base: Base) -> list:
    loaded = team_rules.read_loaded(_opened(base, base.commit, git), team_layout.REVIEW_FILE)
    if loaded is None:
        return ["검수 기준: 없음 — %s 가 없다" % team_layout.REVIEW_FILE]
    return ["검수 기준 (%s):" % base.commit, loaded.text]


def _read_list(git, base: Base, job: str, stage: str, names: list) -> list:
    """`읽을 것` 의 앞부분 — design 의 번호 파일(기준 커밋에 있을 때만, I5) · INTENT.md · 설계 파일 · 계획 파일들(번호 차례)."""
    team, read = base.team, []
    if stage == DESIGN:
        sources = team.sources(job)
        if git.exists(base.commit, sources):
            read.append("%s:%s" % (base.commit, sources))
        elif not git.absent(base.commit, sources):
            raise Unchecked("읽지 못했다: %s" % sources)
    read.append(team.intent(job))
    if team_layout.DESIGN_FILE in names:
        read.append(team.design(job))
    return read + [team.plan(job, n) for n in sorted(n for n in map(team_layout.plan_number, names) if n is not None)]


def _job_bundle(a) -> str:
    git = roadmap_status.Git(os.getcwd())
    base = open_base(git, a.roadmap)
    team, job, stage = base.team, a.job, a.stage
    blocks = _blocks(git, base)
    block = _block(blocks, job)
    if block is not None:   # 흐름을 아는 블록은 브랜치를 고르기 전에 인자부터 본다
        _plan_rule(stage, a.plan, _reader(git, base).flow(block) == team_status.PLAIN_FLOW)
    commit, plain, simple, notices = locate(git, base, blocks, job, a.plan)
    _plan_rule(stage, a.plan, plain)
    intent_path = team.intent(job)
    intent = _intent(git, commit, intent_path, job, team.roadmap)
    names = git.names(commit, team.job(job))
    results = job_results.result_names(git, commit, team, job)
    if names is None or results is None:
        raise Unchecked("과제 폴더를 읽지 못했다: %s — %s" % (team.job(job), (git.failures or ["?"])[-1]))

    def result_path(name: str) -> str:
        return team.job(job, team_layout.RESULTS_DIR, name)

    read = _read_list(git, base, job, stage, names)
    body = ["과제: %s" % intent_path]
    if not simple:   # 단순 작업은 받은 말이 INTENT.md 에 있다(U5)
        body.append(_original_line(base, intent, intent_path, stage))
    tail = []
    if stage != REVIEW:
        number = result_number(plain, stage, a.plan)
        attempt, previous = attempt_of(results, lambda name: git.blob(commit, result_path(name)), stage, number)
        if previous:
            read.append(result_path(previous))
        write = team.result(job, stage, attempt, number)
        role = a.role or team_layout.default_role(stage)
        tail = ["쓸 것: %s" % write, SYNC_LINE % (write, role, base.commit, commit)]
        if stage == DESIGN:
            tail.append("쓸 자리: %s" % place_sentence(team.design(job), stage))
        elif stage == PLAN:
            tail.append("쓸 자리: %s" % place_sentence(team.plan(job, a.plan or 1), stage))
        tail += role_block(git, base, role)
    review = job_results.newest(results, REVIEW, result_number(plain, REVIEW, a.plan))
    if review and result_path(review) not in read:
        read.append(result_path(review))
    body += ["읽을 것: %s" % " · ".join(read)] + tail
    rules, rule_notices = rules_block(git, base)
    body += rules
    if stage == REVIEW:
        body += _review_block(git, base)
    return emit("기준 커밋: %s · 과제 브랜치 %s" % (base.commit, commit), notices + rule_notices, body)


def _positive(value: str) -> int:
    if not value.isdigit() or int(value) < 1:
        raise argparse.ArgumentTypeError("1 이상의 수가 아니다: %r" % value)
    return int(value)


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="start_bundle.py", description="일꾼의 시작 묶음")
    ap.add_argument("--roadmap", required=True)
    ap.add_argument("--role", choices=team_layout.ROLES)
    ap.add_argument("--job")
    ap.add_argument("--stage", choices=team_layout.STAGES)
    ap.add_argument("--plan", type=_positive)
    return ap


def _check_args(a) -> None:
    """파일을 읽기 전의 인자 규칙 — 어기면 Usage. 흐름에 따른 --plan 규칙은 로드맵을 읽은 뒤 _plan_rule 이 본다."""
    leader = team_layout.LEADER_ROLE
    if a.roadmap.startswith("/"):   # open_team 이 앞의 / 를 떼기 전에 거절한다(C9)
        raise Usage("--roadmap 은 레포 상대 경로다: %s" % a.roadmap)
    if (a.job is None) != (a.stage is None):
        raise Usage("--job 과 --stage 는 함께 준다")
    if a.job is None:
        if a.role != leader or a.plan is not None:
            raise Usage("과제 · 단계 없이는 --role %s 만 준다" % leader)
        return
    problem = team_layout.job_name_problem(a.job)
    if problem:
        raise Usage(problem)
    if a.role == leader:
        raise Usage("과제 묶음에는 --role %s 를 주지 않는다" % leader)
    if a.stage == DESIGN and a.plan is not None:
        raise Usage("%s 단계에는 --plan 을 주지 않는다" % DESIGN)
    if a.stage == REVIEW and a.role is not None:
        raise Usage("%s 단계에는 --role 을 주지 않는다 — 역할 문서를 싣지 않는다" % REVIEW)


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    try:
        a = build_parser().parse_args(argv)
        _check_args(a)
        text = _leader_bundle(a.roadmap) if a.job is None else _job_bundle(a)
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
