#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_rules.py — team 형식의 규칙 파일(팀 규칙 파일 · 공통 규칙 파일)의 줄 읽기 · 검사 · 승격 후보. 읽기만 한다.

규칙 줄은 줄 머리가 `- [` 인 줄이다. 줄을 ` · ` 로 나누고, 표지(MARKERS)로 시작하는 조각이 칸을 연다.
표지로 시작하지 않는 조각은 앞 칸(첫 표지 앞이면 규칙 글)에 ` · ` 로 다시 붙는다.
이 파일은 파일을 쓰지 않고 subprocess 를 쓰지 않는다 — git 은 `roadmap_status.Git` 이 읽는다.

명령줄: team_rules.py check --roadmap <로드맵 레포 상대경로> [--ref <ref>]
        team_rules.py candidates --roadmap <로드맵 레포 상대경로> [--ref <ref>]
        `--ref` 가 없으면 레포 뿌리의 작업 폴더 파일을(로드맵도), 있으면 그 커밋의 파일을 읽는다.
        종료 코드 0 통과 · 1 어긋남 · 2 사용법 · 3 검사 불가
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import NamedTuple, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import repo_defaults  # noqa: E402
import roadmap_status  # noqa: E402
import team_layout  # noqa: E402
from roadmap_model import frontmatter  # noqa: E402

MARKERS = ("조건:", "출처:", "확인:", "반례 확인:")
COND_KEYS = ("역할", "단계", "경로")
_COND, _SOURCE, _CONFIRM, _COUNTER = MARKERS
_ROLE_KEY, _STAGE_KEY, _GLOB_KEY = COND_KEYS
_SEP = " · "
_SOURCE_SEP = " | "
_RULE_HEAD = "- ["

BAD_TAG = "머리의 태그 꼴이 아니다 — `[<태그>] <규칙 글>` 이어야 하고 태그는 비지 않는다"
NO_TEXT = "규칙 글이 비었다"
MISSING = "%s 칸이 없거나 비었다"
TWICE = "%s 칸이 한 줄에 둘이다"
BAD_KEY = "조건의 키가 아니다: %s"
BAD_COND = "조건의 꼴이 아니다(키=값): %s"
BAD_VALUE = "조건 %s 의 값이 아니다: %s"
NOT_UTF8 = "UTF-8 이 아닌 바이트가 있다 — 깨진 글자로 읽었다"
NO_FILE = "파일이 없다"
SAME_TEXT = "같은 규칙 글이 %s 에도 있다 — 새 줄을 쓰지 않고 출처에 덧붙인다"
NO_PROMOTION = "승격 후보 없음"
PREFIX = "[spec-distill] "
FIRST_HEAD = "규칙 검사: "


class Rule(NamedTuple):
    line_no: int
    raw: str
    tag: str
    text: str
    conds: dict
    sources: tuple
    confirm: Optional[str]
    counter: Optional[str]
    problems: tuple


def head_of(rule) -> str:
    """규칙 줄 머리 — `[<태그>] <규칙 글>`."""
    return "[%s] %s" % (rule.tag, rule.text)


def _fields(line: str) -> tuple:
    """(규칙 머리 조각, [[표지, 값 글자]…]) — 표지로 시작하지 않는 조각은 앞 칸에 다시 붙는다."""
    pieces = line.split(_SEP)
    head = pieces[0]
    fields = []
    for piece in pieces[1:]:
        marker = next((m for m in MARKERS if piece.startswith(m)), None)
        if marker is not None:
            fields.append([marker, piece[len(marker):]])
        elif fields:
            fields[-1][1] += _SEP + piece
        else:
            head += _SEP + piece
    return head, fields


def _conditions(value: str, problems: list) -> dict:
    conds = {}
    for part in value.split(", "):
        key, eq, raw = part.partition("=")
        key, raw = key.strip(), raw.strip()
        if eq and key not in COND_KEYS:
            problems.append(BAD_KEY % key)
            continue
        if not eq or not raw:
            problems.append(BAD_COND % part.strip())
            continue
        values = tuple(v.strip() for v in raw.split("|"))
        allowed = {_ROLE_KEY: team_layout.ROLES, _STAGE_KEY: team_layout.STAGES}.get(key)
        bad = [v for v in values if (v not in allowed if allowed else not v)]
        if bad and allowed:
            problems.extend(BAD_VALUE % (key, v) for v in bad)
        elif bad:
            problems.append(BAD_COND % part.strip())
        else:
            conds[key] = conds.get(key, ()) + values
    return conds


def _rule(line_no: int, raw: str, handbook: bool) -> Rule:
    head, fields = _fields(raw)
    problems, seen = [], {}
    tag, close = "", head.find("]", len(_RULE_HEAD))
    text = ""
    if close >= 0:
        tag, text = head[len(_RULE_HEAD):close].strip(), head[close + 1:]
    for marker, value in fields:
        if marker in seen:
            if TWICE % marker not in problems:
                problems.append(TWICE % marker)
        else:
            seen[marker] = value
    if close >= 0:
        text = text.strip()
    if close < 0 or not tag:
        problems.append(BAD_TAG)
    elif not text:
        problems.append(NO_TEXT)
    conds = {}
    if _COND in seen:
        if seen[_COND].strip():   # 빈 `조건:` 은 조건이 없는 것이다
            conds = _conditions(seen[_COND].strip(), problems)
    sources = tuple(s.strip() for s in seen.get(_SOURCE, "").split(_SOURCE_SEP) if s.strip())
    confirm = seen.get(_CONFIRM, "").strip() or None
    counter = seen.get(_COUNTER, "").strip() or None
    if not sources:
        problems.append(MISSING % _SOURCE)
    if confirm is None:
        problems.append(MISSING % _CONFIRM)
    if handbook and counter is None:
        problems.append(MISSING % _COUNTER)
    return Rule(line_no, raw, tag, text, conds, sources, confirm, counter, tuple(problems))


def parse_rules(text: str, handbook: bool = False) -> list:
    """규칙 줄마다 Rule. 던지지 않는다. handbook 이면 `반례 확인:` 도 필수다."""
    if text.startswith("\ufeff"):
        text = text[1:]
    out = []
    for number, line in enumerate(text.split("\n"), start=1):
        if line.endswith("\r"):
            line = line[:-1]
        if line.startswith(_RULE_HEAD):
            out.append(_rule(number, line, handbook))
    return out


def candidates(rules: list) -> list:
    """출처가 둘 이상인 규칙 줄 — 공통 규칙 파일로 올릴 후보."""
    return [r for r in rules if len(r.sources) >= 2]


def budget_note(label: str, size: int, budget: int, key: str) -> Optional[str]:
    """넘었으면(바이트 수가 예산보다 클 때) 알림 한 줄, 아니면 None."""
    if size <= budget:
        return None
    return "%s: 예산 초과 — %d바이트 · 예산 %d바이트(%s) — 먼저 지우거나 승격하라" % (label, size, budget, key)


class _Loaded(NamedTuple):
    text: str
    size: int
    bad: bool


def _from_bytes(data: bytes) -> _Loaded:
    try:
        return _Loaded(data.decode("utf-8"), len(data), False)
    except UnicodeDecodeError:
        return _Loaded(data.decode("utf-8", "replace"), len(data), True)


def _line(label: str, number: int, why: str, raw: str) -> str:
    return "%s:%d: %s — %s" % (label, number, why, raw)


def _check_loaded(rules_label: str, rules, handbook_label: str, handbook, rules_budget: int, handbook_budget: int) -> list:
    out, seen = [], {}
    if rules is None:
        out.append("%s: %s" % (rules_label, NO_FILE))
    for label, loaded, budget, key, is_handbook in (
            (rules_label, rules, rules_budget, repo_defaults.BUDGET_KEYS[0], False),
            (handbook_label, handbook, handbook_budget, repo_defaults.BUDGET_KEYS[1], True)):
        if loaded is None:
            continue
        if loaded.bad:
            out.append("%s: %s" % (label, NOT_UTF8))
        note = budget_note(label, loaded.size, budget, key)
        if note:
            out.append(note)
        for r in parse_rules(loaded.text, handbook=is_handbook):
            out.extend(_line(label, r.line_no, p, r.raw) for p in r.problems)
            if r.text:
                seen.setdefault(r.text, []).append((label, r))
    for places in seen.values():
        if len(places) >= 2:
            first_label, first = places[0]
            others = " · ".join("%s:%d" % (lb, r.line_no) for lb, r in places[1:])
            out.append(_line(first_label, first.line_no, SAME_TEXT % others, first.raw))
    return out


def check_files(rules_label: str, rules_data: Optional[bytes], handbook_label: str, handbook_data: Optional[bytes],
                rules_budget: int, handbook_budget: int) -> list:
    """어긋남 줄들(`<경로>:<줄 번호>: <사유> — <그 줄>`). None 은 그 파일이 없다는 뜻이다 — 팀 규칙 파일이 없으면
    어긋남 한 줄, 공통 규칙 파일이 없으면 줄을 내지 않는다."""
    return _check_loaded(rules_label, None if rules_data is None else _from_bytes(rules_data),
                         handbook_label, None if handbook_data is None else _from_bytes(handbook_data),
                         rules_budget, handbook_budget)


# ── 레포 · 설정 · 기본 브랜치 · 로드맵 · layout 을 여는 절차(start_bundle 도 부른다) ────────────

class Usage(Exception):
    pass


class Unchecked(Exception):
    pass


class Opened(NamedTuple):
    git: object
    top: str
    values: dict          # repo_defaults.resolve 의 값
    team: object
    rev: Optional[str]    # 읽는 커밋. None 이면 작업 폴더
    rev_name: str


def read_text(opened: Opened, path: str):
    """(글 | None, 없음이 확인됐나). 읽는 곳은 opened.rev(없으면 작업 폴더). 읽지 못하면 Unchecked."""
    loaded = read_loaded(opened, path)
    return (None, True) if loaded is None else (loaded.text, False)


def read_loaded(opened: Opened, path: str) -> Optional[_Loaded]:
    """파일의 (글 · 실제 바이트 수 · 깨진 글자 여부). 없음이 확인되면 None, 읽지 못하면 Unchecked."""
    git = opened.git
    if opened.rev is None:
        full = os.path.join(opened.top, path)
        if not os.path.lexists(full):
            return None
        try:
            with open(full, "rb") as handle:
                return _from_bytes(handle.read())
        except OSError as exc:
            raise Unchecked("읽지 못했다: %s — %s" % (path, exc))
    text = git.blob(opened.rev, path)
    if text is None:
        if git.absent(opened.rev, path):
            return None
        raise Unchecked("읽지 못했다: %s — %s" % (path, (git.failures or ["블롭이 아니다"])[-1]))
    rc, out = git.run("cat-file", "-s", "%s:%s" % (opened.rev, path))
    if rc != 0 or not out.strip().isdigit():
        raise Unchecked("크기를 재지 못했다: %s" % path)
    return _Loaded(text, int(out.strip()), "\ufffd" in text)


def open_team(roadmap_arg: str, ref: Optional[str] = None, default_branch: bool = False) -> Opened:
    """레포 · 설정 · 로드맵 · layout 을 열어 team 형식을 확인한다. 읽는 곳은 `default_branch` 면 기본 브랜치, `ref` 가
    있으면 그 커밋, 둘 다 없으면 작업 폴더다. 사용법 어긋남은 Usage(2), 읽지 못함은 Unchecked(3)."""
    git = roadmap_status.Git(os.getcwd())
    top = git.toplevel()
    if top is None:
        raise Unchecked("git 레포 안이 아니다")
    resolved = repo_defaults.resolve(top)
    if resolved["errors"]:
        raise Unchecked("레포 설정을 읽지 못했다 — %s" % resolved["errors"][0])
    values = resolved["values"]
    try:
        team = team_layout.team_from_roadmap(values["roadmaps_dir"], roadmap_arg.strip("/"))
    except ValueError as exc:
        raise Usage(str(exc))
    rev, rev_name = None, "작업 폴더"
    if default_branch:
        rev, rev_name = git.default_branch()
        if rev is None:
            raise Unchecked(git.default_reason or "기본 브랜치(origin/HEAD)를 모른다")
    elif ref:
        rev, rev_name = git.commit(ref), ref
        if rev is None:
            raise Unchecked("--ref 를 읽지 못했다: %s" % ref)
    opened = Opened(git, top, values, team, rev, rev_name)
    text, missing = read_text(opened, team.roadmap)
    if text is None:
        raise Unchecked("로드맵이 없다: %s (%s)" % (team.roadmap, rev_name))
    try:
        layout = team_layout.layout_of(frontmatter(text))
    except team_layout.UnknownLayout as exc:
        layout = exc.value
    if layout != team_layout.LAYOUT_TEAM:
        raise Usage("team 형식 로드맵이 아니다 — %s 머리말에 `%s: %s` 가 없다"
                    % (team.roadmap, team_layout.LAYOUT_KEY, team_layout.LAYOUT_TEAM))
    return opened


# ── 명령줄 ───────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="team_rules.py", description="team 형식의 규칙 파일 검사")
    sub = ap.add_subparsers(dest="cmd")
    sub.required = True
    for name in ("check", "candidates"):
        p = sub.add_parser(name)
        p.add_argument("--roadmap", required=True)
        p.add_argument("--ref")
    return ap


def _check(a) -> int:
    op = open_team(a.roadmap, a.ref)
    handbook_path = team_layout.handbook(op.values["roadmaps_dir"])
    rules = read_loaded(op, op.team.rules)
    handbook = read_loaded(op, handbook_path)
    if handbook is None:
        print(PREFIX + "%s: %s — 공통 규칙 파일은 없는 채로 검사한다" % (handbook_path, NO_FILE), file=sys.stderr)
    lines = _check_loaded(op.team.rules, rules, handbook_path, handbook, op.values[repo_defaults.BUDGET_KEYS[0]],
                          op.values[repo_defaults.BUDGET_KEYS[1]])
    if lines:
        print("%s어긋남 %d개" % (FIRST_HEAD, len(lines)))
        for line in lines:
            print(line)
        return 1
    count = len(parse_rules(rules.text)) if rules else 0
    common = len(parse_rules(handbook.text, handbook=True)) if handbook else 0
    print("%s통과 — 규칙 줄 %d개 · 공통 규칙 줄 %d개" % (FIRST_HEAD, count, common))
    return 0


def _candidates(a) -> int:
    op = open_team(a.roadmap, a.ref)
    rules = read_loaded(op, op.team.rules)
    found = candidates(parse_rules(rules.text)) if rules else []
    for r in found:
        print(r.raw)
    if not found:
        print(NO_PROMOTION)
    return 0


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    a = build_parser().parse_args(argv)
    try:
        return _check(a) if a.cmd == "check" else _candidates(a)
    except Usage as exc:
        print(PREFIX + "사용법 오류 — %s" % exc, file=sys.stderr)
        return 2
    except Unchecked as exc:
        print(FIRST_HEAD + "검사 불가 — %s" % exc)
        return 3
    except Exception as exc:  # 검사가 죽어도 통과(0) · 어긋남(1)로 내지 않는다
        print(FIRST_HEAD + "검사 불가 — 내부 오류 %s: %s" % (type(exc).__name__, exc))
        return 3


if __name__ == "__main__":
    sys.exit(main())
