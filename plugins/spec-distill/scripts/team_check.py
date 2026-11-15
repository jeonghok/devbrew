#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_check.py — team 형식 나무(로드맵 · 역할 문서 · 과제 폴더 · 원자료 사본)를 검사한다.

`team_layout.py check --roadmap <로드맵 파일> [--base <ref>]` 가 이 모듈의 run 을 부른다.
종료 코드: 0 통과 · 1 어긋남 · 2 사용법 · 3 검사 불가(검사 불가가 있으면 어긋남보다 앞선다).
읽기만 한다 — 파일을 쓰지 않고 git 은 GIT_ALLOWED 의 읽기 명령만 부른다.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import repo_defaults  # noqa: E402
import roadmap_model as M  # noqa: E402
import team_files as F  # noqa: E402
import team_layout as L  # noqa: E402

GIT_ALLOWED = frozenset({"cat-file", "log", "rev-parse"})
PREFIX = "[spec-distill] "
_PLAN_RE = re.compile(r"plan-([0-9]+)\.md")


# ── git 읽기 ─────────────────────────────────────────────────────────────────

def git_bytes(top, *args) -> tuple:
    """(rc, 표준 출력 바이트). GIT_ALLOWED 밖의 명령은 ValueError. git 을 못 띄우면 (-1, b"")."""
    if not args or args[0] not in GIT_ALLOWED:
        raise ValueError("허용 밖 git 명령: %r" % (args[:1],))
    try:
        proc = subprocess.run(["git", "-C", str(top), *args], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError:
        return -1, b""
    return proc.returncode, proc.stdout


def show(top, commit: str, rel: str):
    """그 커밋의 파일 바이트(변환 없이). 그 커밋이나 파일이 없으면 None."""
    rc, out = git_bytes(top, "cat-file", "blob", "%s:%s" % (commit, rel))
    return out if rc == 0 else None


def _commit_of(top, ref: str):
    rc, out = git_bytes(top, "rev-parse", "--verify", "--quiet", ref + "^{commit}")
    sha = out.decode("utf-8", "replace").strip()
    return sha if rc == 0 and re.fullmatch(r"[0-9a-f]{40}(?:[0-9a-f]{24})?", sha) else None


# ── 읽기 ─────────────────────────────────────────────────────────────────────

def _bytes(path: Path):
    try:
        return path.read_bytes() if path.is_file() else None
    except OSError:
        return None


def _text(path: Path):
    data = _bytes(path)
    try:
        return None if data is None else data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def _meta(text: str) -> dict:
    return {k: M.unquote(v) for k, v in M.frontmatter(text).items()}


def _scope(value) -> str:
    """로드맵 범위 칸 → `한다 … / 안 한다 …` 한 줄(INTENT.md 의 목표 · 하지 않을 것을 만든 꼴)."""
    if isinstance(value, str):
        return value
    do = [i[len("한다: "):] for i in value if i.startswith("한다: ")]
    dont = [i[len("안 한다: "):] for i in value if i.startswith("안 한다: ")]
    if do and dont and len(do) + len(dont) == len(value):
        return "한다 %s / 안 한다 %s" % (" · ".join(do), " · ".join(dont))
    return M.field_text(value)


# ── 검사 ─────────────────────────────────────────────────────────────────────

def _intent_problems(rel: str, text, want: dict) -> list:
    """INTENT.md 의 머리(want 의 키 · 값)와 네 칸. 문제 줄 목록."""
    if text is None:
        return ["%s: 없거나 UTF-8 로 읽지 못했다" % rel]
    meta = _meta(text)
    out = ["%s: 머리 %s 가 %r 이 아니다(%r)" % (rel, k, v, meta.get(k)) for k, v in want.items() if meta.get(k) != v]
    try:
        F.intent_sections(text)
    except F.FormatError as exc:
        out.append("%s: 네 칸을 읽지 못했다 — %s" % (rel, exc))
    return out


def _plan_problems(top: Path, team, job: str, branches: int) -> list:
    folder = top / team.job(job)
    out = []
    for name in sorted(os.listdir(str(folder))) if folder.is_dir() else []:
        m = _PLAN_RE.fullmatch(name)
        if m and not 1 <= int(m.group(1)) <= branches:
            out.append("%s: 계획 번호 %s 가 이 과제의 브랜치 수 %d 를 넘는다 — 계획 하나가 브랜치 하나다"
                       % (team.job(job, name), m.group(1), branches))
    return out


def check_tree(top: Path, team, base=None) -> tuple:
    """(오류 줄들, 검사 불가 줄들, 알림 줄들). 줄마다 그 파일 경로와 무엇이 어긋났는지를 적는다."""
    top = Path(top)
    errors, unknown, notes = [], [], []

    # 1. 로드맵
    blocks = []
    text = _text(top / team.roadmap)
    if text is None:
        errors.append("%s: 로드맵 파일이 없거나 UTF-8 로 읽지 못했다" % team.roadmap)
    else:
        meta = _meta(text)
        if meta.get("type") != "roadmap":
            errors.append("%s: 머리말 type 이 roadmap 이 아니다" % team.roadmap)
        try:
            layout = L.layout_of(meta)
        except L.UnknownLayout as exc:
            layout = exc.value
        if layout != L.LAYOUT_TEAM:
            errors.append("%s: 머리말 %s 이 %s 가 아니다" % (team.roadmap, L.LAYOUT_KEY, L.LAYOUT_TEAM))
        _m, blocks, _r, _k, problems = M.parse_roadmap(text)
        errors.extend("%s: %s" % (team.roadmap, p) for p in problems)

    # 2. 규칙 파일 · 원자료 사본
    if not (top / team.rules).is_file():
        errors.append("%s: 없다" % team.rules)
    original = _bytes(top / team.original)
    sections, total = [], None
    if original is None:
        errors.append("%s: 없다" % team.original)
    else:
        try:
            sections, total = F.parse_original(original), F.line_count(original)
        except F.FormatError as exc:
            errors.append("%s: %s" % (team.original, exc))

    # 3. 로드맵 폴더 바로 아래의 공통 문서
    for path in [L.role_doc(team.roadmaps_dir, r) for r in L.ROLES] + [L.handbook(team.roadmaps_dir)]:
        if not (top / path).is_file():
            errors.append("%s: 없다" % path)

    # 4 · 6 · 7 · 10. 결정 블록이 아닌 블록의 과제 폴더
    by_job = {}
    for b in blocks:
        if b.get("kind") == "decision":
            continue
        job = b["id"]
        by_job[job] = b
        intent_rel = team.intent(job)
        intent_text = _text(top / intent_rel)
        bad = _intent_problems(intent_rel, intent_text, {"type": "job", "job": job, "kind": F.KIND_EPIC, "roadmap": team.roadmap})
        errors.extend(bad)
        src_text = _text(top / team.sources(job))
        if src_text is None:
            errors.append("%s: 없거나 UTF-8 로 읽지 못했다" % team.sources(job))
        else:
            smeta = _meta(src_text)
            errors.extend("%s: 머리 %s 가 %r 이 아니다(%r)" % (team.sources(job), k, v, smeta.get(k))
                          for k, v in (("type", "job-sources"), ("job", job)) if smeta.get(k) != v)
            try:
                M.bundle_ids(src_text)
            except M.FormatError as exc:
                errors.append("%s: ids 를 읽지 못했다 — %s" % (team.sources(job), exc))
        if not (top / team.results(job)).is_dir():
            errors.append("%s: 결과 폴더가 없다" % team.results(job))
        errors.extend(_plan_problems(top, team, job, len(b.get("branches") or [])))
        if bad:
            continue
        try:
            ranges = F.intent_ranges(intent_text)
        except F.FormatError as exc:
            errors.append("%s: 지시 원문 범위를 읽지 못했다 — %s" % (intent_rel, exc))
            ranges = None
        if ranges == []:
            errors.append("%s: 지시 원문에 %s 의 줄 범위가 없다" % (intent_rel, team.original))
        for a, z in ranges or []:
            if total is not None and z > total:
                errors.append("%s: 지시 원문 범위 %d–%d 가 %s 의 %d줄 밖이다" % (intent_rel, a, z, team.original, total))
        fields = b.get("fields") or {}
        notes.extend("%s: %s" % (intent_rel, line)
                     for line in F.intent_drift(intent_text, M.field_text(fields.get("의도", "")), _scope(fields.get("범위", ""))))

    # 5 · 6. 블록이 없는 과제 폴더
    jobs_dir = top / team.path(L.JOBS_DIR)
    for name in sorted(os.listdir(str(jobs_dir))) if jobs_dir.is_dir() else []:
        if not (jobs_dir / name).is_dir():
            continue
        problem = L.job_name_problem(name)
        if problem:
            errors.append("%s: %s" % (team.job(name), problem))
        if name in by_job:
            continue
        intent_rel = team.intent(name)
        intent_text = _text(top / intent_rel)
        kind = _meta(intent_text).get("kind") if intent_text is not None else None
        if kind == F.KIND_EPIC:
            notes.append("%s: 로드맵에 없는 에픽 과제 폴더" % team.job(name))
            continue
        errors.extend(_intent_problems(intent_rel, intent_text, {"type": "job", "job": name, "kind": F.KIND_TASK}))
        if intent_text is not None and kind == F.KIND_TASK:
            meta = _meta(intent_text)
            for key in ("branch", "paths"):
                if not meta.get(key, "").strip("[] "):
                    errors.append("%s: 머리 %s 가 비었다" % (intent_rel, key))
        if not (top / team.results(name)).is_dir():
            errors.append("%s: 결과 폴더가 없다" % team.results(name))
        errors.extend(_plan_problems(top, team, name, 1))

    # 8. 옮긴 구간이 출처와 바이트가 같다
    for s in sections:
        where = "%s %d–%d행(출처 %s · %s %d–%d행)" % (team.original, s.start, s.start + s.last - s.first,
                                                   s.source, s.label, s.first, s.last)
        blob = show(top, s.commit, s.source)
        if blob is None:
            unknown.append("%s: 출처 커밋 %s 의 파일을 읽지 못했다" % (where, s.commit[:12]))
        elif b"".join(F.byte_lines(blob)[s.first - 1:s.last]) != s.body:
            errors.append("%s: 출처의 그 줄들과 바이트가 다르다" % where)

    # 9. 덧붙이기만 — 기준 커밋의 사본이 지금 사본의 앞머리다
    ref = base or M.DEFAULT_REF
    commit = _commit_of(top, ref)
    if commit is None and base:
        unknown.append("%s: 기준 %s 를 읽지 못했다" % (team.original, base))
    elif commit is None:
        notes.append("%s: 기본 브랜치(%s)를 몰라 덧붙이기 검사를 건너뛰었다" % (team.original, ref))
    else:
        old = show(top, commit, team.original)
        if old is not None and original is not None and not original.startswith(old):
            errors.append("%s: 기준 %s 의 사본에서 앞 줄을 바꾸거나 지웠다 — 원자료 사본은 덧붙이기만 받는다" % (team.original, ref))
    return errors, unknown, notes


# ── 명령줄 ───────────────────────────────────────────────────────────────────

def _toplevel(path: Path):
    d = Path(os.path.realpath(str(path)))
    while not d.is_dir():
        d = d.parent
    rc, out = git_bytes(d, "rev-parse", "--show-toplevel")
    top = out.decode("utf-8", "replace").strip()
    return Path(os.path.realpath(top)) if rc == 0 and top else None


def run(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="team_layout.py", description="team 형식 나무를 검사한다.")
    sub = ap.add_subparsers(dest="cmd")
    sub.required = True
    c = sub.add_parser("check", help="로드맵 파일의 팀 폴더를 검사한다(0 통과 · 1 어긋남 · 2 사용법 · 3 검사 불가)")
    c.add_argument("--roadmap", required=True, help="<로드맵 폴더><팀>/" + L.ROADMAP_FILE)
    c.add_argument("--base", help="덧붙이기 검사의 기준 ref(기본 %s)" % M.DEFAULT_REF)
    a = ap.parse_args(argv)   # 사용법 오류는 argparse 가 rc 2 로 끝낸다
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    if a.base is not None and (not a.base or a.base.startswith("-")):
        print(PREFIX + "사용법 오류 — --base 는 ref 이름이다: %r" % a.base, file=sys.stderr)
        return 2
    top = _toplevel(Path(a.roadmap))
    if top is None:
        print(PREFIX + "사용법 오류 — git 작업 트리 밖이다: %s" % a.roadmap, file=sys.stderr)
        return 2
    try:
        rel = Path(os.path.realpath(a.roadmap)).relative_to(top).as_posix()
    except ValueError:
        print(PREFIX + "사용법 오류 — %s 가 작업 트리 %s 밖이다" % (a.roadmap, top), file=sys.stderr)
        return 2
    try:
        result = repo_defaults.resolve(str(top))
    except repo_defaults.SettingsError as exc:
        print(PREFIX + "검사 불가 — 레포 설정을 읽지 못했다: %s" % exc)
        return 3
    if result["errors"]:
        print(PREFIX + "검사 불가 — 레포 설정을 읽지 못해 로드맵 폴더를 정하지 못했다: %s" % result["errors"][0])
        return 3
    try:
        team = L.team_from_roadmap(result["values"]["roadmaps_dir"], rel)
    except ValueError as exc:
        print(PREFIX + "사용법 오류 — %s" % exc, file=sys.stderr)
        return 2
    errors, unknown, notes = check_tree(top, team, a.base)
    for line in errors:
        print(PREFIX + line)
    for line in unknown:
        print(PREFIX + "검사 불가 — " + line)
    for line in notes:
        print(PREFIX + line, file=sys.stderr)
    if unknown:
        return 3
    if errors:
        print(PREFIX + "team 나무 검사: 어긋남 %d줄 — %s" % (len(errors), team.dir))
        return 1
    print(PREFIX + "team 나무 검사: 통과 — %s" % team.dir)
    return 0
