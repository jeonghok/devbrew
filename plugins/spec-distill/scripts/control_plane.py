#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""control_plane.py — 로드맵 상태와 진행 중 인터뷰를 상태줄 한 줄 · 지도 · 작업 목록 줄로 보인다.

명령줄:
  control_plane.py statusline                    상태줄 한 줄. 늘 rc 0.
  control_plane.py show [<로드맵 경로>]           지도. rc 0.
  control_plane.py show <로드맵 경로> <에픽>   에픽 하나로 내려가는 보기. 없는 에픽이면 rc 2.
  control_plane.py show --tasks [<로드맵 경로>]   작업 목록 줄 `<제목><탭><pending|in_progress|completed|keep>`.
                                                 검사 불가 · 로드맵 없음 · 꺼짐이면 표준 출력이 비고 표준 오류에
                                                 사유, rc 3. 기본 브랜치에 없는 로드맵이면 rc 4.
                                                 로드맵이 여럿인데 경로가 없으면 rc 2.

단계 · 경고는 `roadmap_status.py <경로> --json`(기본 브랜치 사본)을 하위 프로세스로 불러 읽기만 한다.
레포 파일과 git 상태를 바꾸지 않는다 — 쓰는 것은 `<git 공용 디렉토리>/devbrew/control-plane.json` 캐시 하나다.
받은 지 N분은 캐시 밖에서 매번 FETCH_HEAD 수정 시각으로 읽는다.
"""
from __future__ import annotations

import argparse
import copy
import datetime
import errno
import hashlib
import json
import os
import re
import select
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
from kill_switch_active import kill_switch_active  # noqa: E402
import conductor_state as cs  # noqa: E402
import repo_defaults  # noqa: E402
import suite_lock  # noqa: E402
from roadmap_model import BLOCK_ID_RE, DEFAULT_REF, NO_DEFAULT, FormatError  # noqa: E402
from state_path import state_root_for_common  # noqa: E402

DONE = ("머지됨", "끝남")
# 상태줄 묶음 — 상태 계산의 단계 이름 + R5 가 더할 이름. 대기 · 끝난 단계 · 알 수 없음은 세지 않는다.
BUCKETS = (("설계", ("설계 중",)), ("구현", ("계획", "구현 중", "구현 끝", "PR")), ("준비", ("준비",)))
IMPL_STAGES = ("구현 중", "구현 끝", "PR")
GH_STATES = {"OPEN": "열림", "MERGED": "머지됨", "CLOSED": "닫힘"}
LEDGER_MAX_BYTES = 1 << 20
MACHINE_MAX_BYTES = 1 << 20
LEDGER_MAX_COUNT = 50
GH_CALL_CAP = 5.0
IMPL_DONE_MARK = " — 구현 끝 · "  # roadmap_status 가 일부 머지 이유에 붙이는 모양
UNCOUNTED = ("대기", "머지됨", "끝남", "알 수 없음")
TASK_STATES = ("pending", "in_progress", "completed")
TOP_WARNINGS = (("고아 발화", "orphans"), ("미배정 번호", "unassigned"),
                ("brief 에 없는 번호", "unknown_ids"))
CTRL_RE = re.compile(r"[\x00-\x1f\x7f-\x9f]")
QUEUE_HEADING = "## audit §2 대기 줄"
NO_ROADMAP = "로드맵 없음 — 기본 브랜치에 끝나지 않은 블록이 있는 로드맵이 없다"


def clean(value) -> str:
    """제어 문자(탭 · 줄바꿈 · ESC 포함)를 공백으로 — 한 줄 출력과 탭 두 칸을 깨지 않게."""
    return CTRL_RE.sub(" ", str(value))


def folder_name(path: str) -> str:
    parts = path.strip("/").split("/")
    return parts[-2] if len(parts) >= 2 else parts[-1]


def count_warnings(report: dict) -> int:
    """블록 경고 줄 수 + 맨 위 경고 갈래 중 비지 않은 것 하나씩."""
    n = sum(len(b.get("warnings") or []) for b in report.get("blocks") or [])
    return n + sum(1 for _label, key in TOP_WARNINGS if report.get(key))


def bucket_counts(items):
    counts = dict((name, 0) for name, _stages in BUCKETS)
    other = 0
    for _path, report in items:
        for b in report.get("blocks") or []:
            stage = b.get("stage")
            if stage and stage.startswith("일부 머지"):
                counts["구현"] += 1
                continue
            for name, stages in BUCKETS:
                if stage in stages:
                    counts[name] += 1
                    break
            else:
                if stage not in UNCOUNTED:
                    other += 1
    return counts, other


def failed_report(path: str, reason: str) -> dict:
    """상태 계산을 못 읽었을 때의 보고서 — 상태 계산의 키를 모두 갖고 exit 3 이다."""
    return {"roadmap": path, "source": None, "fetched_at": None, "notice": "", "blocks": [],
            "unassigned": None, "orphans": None, "unknown_ids": [], "overlaps": [],
            "format_errors": [], "unknown_reasons": [reason], "exit": 3, "bridge_error": True}


def first_line(report: dict) -> str:
    """상태 계산의 쉬운 첫 줄 그대로."""
    try:
        import roadmap_status
        return roadmap_status.render(report).split("\n", 1)[0]
    except Exception as exc:  # noqa: BLE001 — 첫 줄을 못 만들어도 지도의 나머지는 보인다
        return "로드맵 상태 — 첫 줄을 만들지 못했다(%s)" % type(exc).__name__


# ── 인터뷰 상태 파일 ──────────────────────────────────────────────────────────

def _field(line: str, key: str):
    """들여쓴 `key: 값` 줄이면 주석을 뗀 값, 아니면 None."""
    if not line[:1].isspace():
        return None
    name, sep, value = line.strip().partition(":")
    if not sep or name != key:
        return None
    return value.split("#", 1)[0].strip()


def _short(value: str) -> str:
    value = str(value)
    return value if len(value) <= 80 else value[:80] + "…"


def _count(value: str) -> bool:
    value = value.strip()
    return value.isascii() and value.isdigit() and len(value) <= 9


def parse_interview_state(text: str) -> dict:
    """{"n": 조사 호출 합, "limit": 상한, "last": 대기 줄의 마지막 사건 | None}. 셀 수 없으면 ValueError."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        raise ValueError("frontmatter 가 없다")
    end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if end is None:
        raise ValueError("frontmatter 가 닫히지 않았다")
    head = lines[1:end]
    if not head or head[0].strip() != "type: interview-state":
        raise ValueError("첫 키가 type: interview-state 가 아니다")
    n = limit = None
    for line in head:
        value = _field(line, "research_dispatches")
        if value is not None:
            if not (value.startswith("{") and value.endswith("}")):
                raise ValueError("research_dispatches 가 {…} 모양이 아니다")
            n = 0
            for part in (p for p in value[1:-1].split(",") if p.strip()):
                _key, sep, val = part.partition(":")
                if not sep or not _count(val):
                    raise ValueError("research_dispatches 칸을 셀 수 없다: %s" % _short(part.strip()))
                n += int(val.strip())
        value = _field(line, "research_limit")
        if value is not None:
            if not _count(value):
                raise ValueError("research_limit 가 수가 아니다: %s" % _short(value))
            limit = int(value)
    if n is None or limit is None:
        raise ValueError("research_dispatches · research_limit 를 찾지 못했다")
    last, in_queue = None, False
    for line in lines[end + 1:]:
        if line.startswith("## "):
            in_queue = line.strip() == QUEUE_HEADING
        elif in_queue and line.startswith("- "):
            last = line[2:].strip()
    return {"n": n, "limit": limit, "last": last}


def _latest(interview):
    return sorted(interview.get("items") or [], key=lambda it: it.get("mtime", 0), reverse=True)


def interview_segment(interview) -> str:
    if not interview or not interview.get("supported"):
        return ""
    parts = []
    items = _latest(interview)
    if items:
        seg = "인터뷰 조사 %d/%d" % (items[0]["n"], items[0]["limit"])
        parts.append(seg + (" 외 %d" % (len(items) - 1) if len(items) > 1 else ""))
    if interview.get("errors"):
        parts.append("인터뷰 셀 수 없음")
    return " · ".join(parts)


def interview_lines(interview) -> list:
    if not interview or not interview.get("supported"):
        return ["인터뷰: 셀 수 없음 — 이 플러그인 버전은 인터뷰 상태 파일을 아직 남기지 않는다"]
    items, errors = _latest(interview), interview.get("errors") or []
    if not items and not errors:
        return ["인터뷰: 진행 중 없음"]
    out = ["인터뷰: 진행 중 %d개" % len(items)]
    for it in items:
        line = "    %s — 조사 %d/%d" % (it["path"], it["n"], it["limit"])
        if it.get("last"):
            line += " · 마지막 사건: %s" % it["last"]
        out.append(clean(line))
    out += [clean("    %s — 셀 수 없음(%s)" % (e["path"], e["reason"])) for e in errors]
    return out


# ── 세 출력 ──────────────────────────────────────────────────────────────────

def statusline_text(items, interview, minutes, select_error=None) -> str:
    """상태줄 한 줄. items 는 고른 로드맵 [(경로, 보고서)] — 수는 전부의 합이고 이름은 첫 로드맵이다."""
    parts = []
    if items:
        parts.append(folder_name(items[0][0]) + (" 외 %d" % (len(items) - 1) if len(items) > 1 else ""))
        counts, other = bucket_counts(items)
        parts += ["%s %d" % (name, counts[name]) for name, _stages in BUCKETS]
        if other:
            parts.append("기타 %d" % other)
        w = sum(count_warnings(r) for _p, r in items)
        parts.append("경고 %d" % w if w else "경고 없음")
        parts.append("받은 지 %d분" % minutes if minutes is not None else "받은 시각 모름")
    seg = interview_segment(interview)
    if seg:
        parts.append(seg)
    if any(r.get("exit") == 4 for _p, r in items):
        parts.append("기본 브랜치에 없음")
    if select_error or any(r.get("exit") == 3 for _p, r in items):
        parts.append("검사 불가")
    return clean(" · ".join(parts))


def machine_error_line(why) -> str:
    """사유가 이미 «기계 상태» 로 시작하면 머리말을 겹쳐 붙이지 않는다."""
    why = str(why)
    return clean(why if why.startswith("기계 상태") else "기계 상태를 읽지 못했다 — %s" % why)


OUTSIDE = "로드맵 밖"
WORK_DONE = ("끝", "끝남", "머지됨")


def recommended(report: dict):
    """(권장 수, 출처). 로드맵 frontmatter `parallel_default` 가 없으면 기본값. 값이 깨졌으면 (None, 사유)."""
    settings = report.get("settings") or {}
    value = settings.get("parallel_default", repo_defaults.PARALLEL_DEFAULT) if settings else repo_defaults.PARALLEL_DEFAULT
    if value is None:
        return None, "로드맵 머리말 parallel_default 가 깨졌다"
    src = (settings.get("sources") or {}).get("parallel_default", "기본값")
    return value, ("로드맵 머리말" if src == "frontmatter" else "기본값")


def works_lines(report: dict) -> list:
    """기계 상태의 「작업」 표(로드맵 밖 일 포함) · 돌고 있는 큰 작업 수와 권장 수 · 공유 스위트 잠금. 기계 상태 사본이다 —
    지휘자는 사용자에게 말하기 전에 하니스 agent 목록으로 맞춘다."""
    machine = report.get("machine")
    lines = []
    lock = report.get("suite_lock") or ""
    busy = bool(lock) and not lock.endswith("비어 있음")
    if machine is not None and (machine.get("살아 있는 agent") or machine.get("작업") or busy):
        rec, src = recommended(report)
        rec_text = ("권장 %d(%s — 상한이 아니다, 사용자가 늘린다)" % (rec, src)) if rec is not None else ("권장 수 모름 — %s" % src)
        lines.append(clean("돌고 있는 큰 작업 %d(기계 상태 사본) · %s" % (len(machine.get("살아 있는 agent") or []), rec_text)))
        rows = machine.get("작업") or []
        lines.append("작업:" if rows else "작업: 없음(로드맵 밖 일 포함)")
        for w in rows:
            lines.append(clean("    %s %s — %s · %s · 담당 %s · %s" % (w["종류"], w["이름"], w["에픽"], w["단계"], w["담당"], w["근거"])))
    if busy or (lock and lines):
        lines.append(clean(lock))
    return lines


def show_text(items, interview, notes, first_line_fn, select_error=None) -> str:
    lines = []
    if select_error:
        lines.append(clean("검사 불가: %s" % select_error))
    elif not items:
        lines.append(NO_ROADMAP)
    for path, report in items:
        lines.append(clean(first_line_fn(report)))
        lines.append(clean("로드맵: %s" % path))
        if report.get("machine_error"):
            lines.append(machine_error_line(report["machine_error"]))
        if report.get("not_on_default"):
            lines.append(clean("로드맵이 아직 기본 브랜치(%s)에 없다 — 머지 전이면 `--roadmap-file` 로 계산한다"
                               % (report.get("default_branch") or "알 수 없음")))
        blocks = report.get("blocks") or []
        stages = dict((b.get("id"), b.get("stage")) for b in blocks)
        for b in blocks:
            line = "%s %s — %s · %s" % (b.get("id"), b.get("title"), b.get("stage"), b.get("reason"))
            waiting = [d for d in b.get("deps") or [] if stages.get(d) not in DONE]
            if waiting:
                line += " ← 기다림: " + " · ".join(waiting)
            lines.append(clean(line))
            lines += [clean("    경고: %s" % w) for w in b.get("warnings") or []]
            if b.get("pr"):
                lines.append(clean("    PR: %s" % pr_text(b["pr"])))
            lines += [clean("    원장 읽기 불가: %s — %s" % (f["path"], f["reason"])) for f in b.get("ledger_failures") or []]
            if b.get("ledger_cut"):
                lines.append(clean("    %s" % b["ledger_cut"]))
        for label, key in TOP_WARNINGS:
            vals = report.get(key)
            if vals is None:
                lines.append("%s: 셀 수 없음" % label)
            elif vals:
                lines.append(clean("%s: %d개 — %s" % (label, len(vals), " · ".join(vals))))
        ov = report.get("overlaps") or []
        if ov:
            lines.append("경로 예약 겹침(정보): %d개" % len(ov))
            lines += [clean("    %s ↔ %s: %s" % (o["blocks"][0], o["blocks"][1], " · ".join(o["paths"]))) for o in ov]
        lines += [clean("검사 불가: 형식 깨짐 — %s" % e) for e in report.get("format_errors") or []]
        lines += [clean("검사 불가: %s" % r) for r in report.get("unknown_reasons") or []]
        ruled = [b for b in blocks if "rulings" in b]
        if ruled:
            lines.append("판정 줄:")
            rows = []
            for b in ruled:
                if b["rulings"] is None and b.get("ledger_failures"):
                    rows.append(clean("    %s: 셀 수 없음 — 실행 원장을 읽지 못했고 설계문서 `## 판정` 도 없다" % b.get("id")))
                elif b["rulings"] is None and report.get("machine_error"):
                    rows.append(clean("    %s: 셀 수 없음 — 기계 상태를 읽지 못해 원장을 모른다" % b.get("id")))
                elif b["rulings"] is None:
                    rows.append(clean("    %s: 셀 수 없음 — 실행 원장도 설계문서 `## 판정` 도 없다" % b.get("id")))
                else:
                    rows += [clean("    %s: %s" % (b.get("id"), r)) for r in b["rulings"]]
            lines += rows or ["    없음"]
        lines += works_lines(report)
    lines += interview_lines(interview)
    lines += [clean("캐시를 쓰지 못했다 — %s" % n) for n in notes]
    return "\n".join(lines)


def tasks_output(items, select_error=None):
    """(표준 출력 줄들, 표준 오류 글, rc). rc 가 0 이 아니면 지휘자는 작업 목록을 바꾸지 않는다."""
    if select_error:
        return [], clean("검사 불가 — %s" % select_error), 3
    if not items:
        return [], "로드맵 없음 — 작업 목록을 바꾸지 않는다", 3
    if len(items) > 1:
        return [], clean("로드맵이 여럿이다 — 경로를 하나 주라: %s" % " · ".join(p for p, _r in items)), 2
    _path, report = items[0]
    if report.get("exit") == 4:
        return [], clean("로드맵이 아직 기본 브랜치에 없다 — 머지 전이면 roadmap_status.py --roadmap-file %s 로 계산한다"
                         % _path), 4
    if report.get("exit") == 3:
        reasons = (["형식 깨짐 — %s" % e for e in report.get("format_errors") or []]
                   + list(report.get("unknown_reasons") or []))
        return [], clean("검사 불가 — %s" % (" · ".join(reasons) or "상태 계산이 3 을 냈다")), 3
    out = []
    for b in report.get("blocks") or []:
        title = "%s %s — %s" % (b.get("id"), b.get("title"), b.get("stage"))
        state = b.get("task_status")
        if state in TASK_STATES:
            out.append(clean(title) + "\t" + state)
        else:
            reason = b.get("reason") or "작업 상태가 없다"
            out.append(clean("%s · 알 수 없음(%s)" % (title, reason)) + "\tkeep")
    for w in (report.get("machine") or {}).get("작업") or []:
        if w["에픽"] != OUTSIDE:
            continue
        state = "completed" if w["단계"] in WORK_DONE else "in_progress"
        out.append(clean("%s %s %s — %s" % (OUTSIDE, w["종류"], w["이름"], w["단계"])) + "\t" + state)
    return out, "", 0


# ── git · 인터뷰 파일 · 캐시 (읽기 전용 — 쓰는 것은 캐시 파일 하나) ──────────────────

ROADMAP_RE = re.compile(r"docs/superpowers/roadmaps/[^/]+/roadmap\.md")
GIT_OK = frozenset({"rev-parse", "ls-tree", "for-each-ref"})
CACHE_VERSION = 1
STATE_SUFFIX = "-interview.state.md"
STATUSLINE_BUDGET = 3.0
SHOW_BUDGET = 30.0
STDIN_WAIT = 0.5
STDIN_MAX_BYTES = 1 << 16
STATE_MAX_BYTES = 1 << 16
STATE_FILES_MAX = 200
FOLDER_ENTRIES_MAX = 10000
CACHE_MAX_BYTES = 8 << 20
LAST_LINES_MAX = 20
TIMED_OUT_LINE = "상태줄 — 시간 초과"


class TimedOut(Exception):
    pass


class Deadline:
    def __init__(self, seconds: float):
        self.end = time.monotonic() + seconds

    def left(self, what: str) -> float:
        left = self.end - time.monotonic()
        if left <= 0:
            raise TimedOut(what)
        return left


def run_bounded(argv, cwd, env, deadline: Deadline, what: str):
    """(rc, 표준 출력 바이트). 남은 시간을 넘기면 프로세스 묶음째 죽이고 TimedOut."""
    wait = deadline.left(what)
    try:
        proc = subprocess.Popen(argv, cwd=cwd, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, start_new_session=True)
    except (OSError, subprocess.SubprocessError):
        return 127, b""
    try:
        out, _err = proc.communicate(timeout=wait)
    except BaseException as exc:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        try:
            proc.communicate(timeout=1)
        except BaseException:
            pass
        if isinstance(exc, subprocess.TimeoutExpired):
            raise TimedOut(what)
        raise
    return proc.returncode, out


def read_capped(path, limit: int) -> str:
    """일반 파일만 limit 바이트까지 UTF-8 로 읽는다 — 링크를 따라가지 않고 장치 · 파이프에서 기다리지 않는다.
    일반 파일이 아니거나 넘으면 ValueError, 링크면 OSError."""
    fd = os.open(str(path), os.O_RDONLY | os.O_NONBLOCK | getattr(os, "O_NOFOLLOW", 0))
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise ValueError("일반 파일이 아니다")
        with os.fdopen(fd, "rb") as fh:
            fd = None
            data = fh.read(limit + 1)
    finally:
        if fd is not None:
            os.close(fd)
    if len(data) > limit:
        raise ValueError("파일이 %d바이트를 넘는다" % limit)
    return data.decode("utf-8")


class Repo:
    def __init__(self, cwd: str, deadline: Deadline):
        self.cwd, self.deadline = cwd, deadline
        self.env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0",
                        GIT_NO_LAZY_FETCH="1", LC_ALL="C")

    def git(self, *args):
        if not args or args[0] not in GIT_OK:
            raise RuntimeError("허용하지 않은 git 하위 명령: %r" % (args[:1],))
        rc, out = run_bounded(["git", "-c", "core.quotePath=false"] + list(args), self.cwd, self.env,
                              self.deadline, "git " + args[0])
        return rc, out.decode("utf-8", "replace")

    def line(self, *args):
        rc, out = self.git(*args)
        return out.strip() if rc == 0 and out.strip() else None


def open_repo(cwd: str, deadline: Deadline):
    top = Repo(cwd, deadline).line("rev-parse", "--show-toplevel")
    return Repo(top, deadline) if top else None


def fetch_stamp(repo: Repo):
    """이 워크트리와 공용 git 디렉토리의 FETCH_HEAD 수정 시각 중 새것 — 상태 계산의 fetched_at 과 같은 출처."""
    stamps = []
    for args, tail in ((("rev-parse", "--git-path", "FETCH_HEAD"), ""),
                       (("rev-parse", "--git-common-dir"), "FETCH_HEAD")):
        out = repo.line(*args)
        if out:
            try:
                stamps.append(Path(repo.cwd, out, tail).stat().st_mtime)
            except OSError:
                continue
    return max(stamps) if stamps else None

def default_ref(repo):
    """(커밋, 전체 참조 이름) — origin/HEAD 가 가리키는 기본 브랜치. 없으면 (None, None)."""
    sha = repo.line("rev-parse", "--verify", "--quiet", DEFAULT_REF + "^{commit}")
    if not sha:
        return None, None
    return sha, repo.line("rev-parse", "--symbolic-full-name", DEFAULT_REF)


def candidates(repo: Repo, main):
    """([(경로, blob)], 사유). 기본 브랜치가 없으면 고를 것이 없다(로드맵 없음과 같다)."""
    if not main:
        return [], None
    rc, out = repo.git("ls-tree", "-r", "-z", main, "--", "docs/superpowers/roadmaps/")
    if rc != 0:
        return [], "기본 브랜치의 로드맵 목록을 읽지 못했다(git ls-tree rc %d)" % rc
    found = []
    for entry in (e for e in out.split("\0") if e):
        meta, _tab, path = entry.partition("\t")
        if ROADMAP_RE.fullmatch(path):
            found.append((path, meta.split()[-1]))
    return sorted(found), None


def interview_files(root: str):
    """(지원 여부, [(레포 상대 경로, Path, mtime_ns)] 짝 brief 없는 것, 폴더 사유 | None)."""
    try:
        supported = "interview-state" in (SCRIPTS / "state_path.py").read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        supported = False
    if not supported:
        return False, [], None
    folder = Path(root, "docs", "superpowers", "interview")
    for part in ("docs", "docs/superpowers", "docs/superpowers/interview"):
        try:
            if stat.S_ISLNK(os.lstat(os.path.join(root, part)).st_mode):
                return True, [], "인터뷰 폴더 경로에 링크가 있다: %s" % part
        except FileNotFoundError:
            return True, [], None
        except OSError as exc:
            return True, [], "인터뷰 폴더를 읽지 못했다(%s)" % type(exc).__name__
    names = set()
    try:
        with os.scandir(str(folder)) as entries:
            for entry in entries:
                if len(names) >= FOLDER_ENTRIES_MAX:
                    return True, [], "인터뷰 폴더 항목이 %d개를 넘는다" % FOLDER_ENTRIES_MAX
                try:
                    entry.name.encode("utf-8")
                except UnicodeEncodeError:
                    continue
                names.add(entry.name)
    except OSError as exc:
        return True, [], "인터뷰 폴더를 읽지 못했다(%s)" % type(exc).__name__
    progress = sorted(n for n in names
                      if n.endswith(STATE_SUFFIX) and n[: -len(".state.md")] + ".md" not in names)
    if len(progress) > STATE_FILES_MAX:
        return True, [], "진행 중 인터뷰 상태 파일이 %d개를 넘는다(%d개)" % (STATE_FILES_MAX, len(progress))
    files = []
    for name in progress:
        try:
            mtime_ns = os.lstat(str(folder / name)).st_mtime_ns
        except OSError:
            mtime_ns = -1
        files.append(("docs/superpowers/interview/" + name, folder / name, mtime_ns))
    return True, files, None


def read_interviews(supported, files, folder_error, deadline: Deadline) -> dict:
    summary = {"supported": supported, "items": [], "errors": []}
    if folder_error:
        summary["errors"].append({"path": "docs/superpowers/interview", "reason": folder_error})
    for rel, path, mtime_ns in files:
        deadline.left("인터뷰 상태 파일")
        try:
            item = parse_interview_state(read_capped(path, STATE_MAX_BYTES))
        except OSError as exc:
            summary["errors"].append({"path": rel, "reason": "읽지 못했다(%s)" % type(exc).__name__})
            continue
        except UnicodeDecodeError:
            summary["errors"].append({"path": rel, "reason": "UTF-8 이 아니다"})
            continue
        except ValueError as exc:
            summary["errors"].append({"path": rel, "reason": _short(str(exc))})
            continue
        item.update(path=rel, mtime=mtime_ns / 1e9)
        summary["items"].append(item)
    return summary


def cache_key(repo: Repo, main, main_full, mode, targets):
    """기본 브랜치 커밋 · 브랜치 머리 목록(기본 브랜치 · symref 줄 뺌) · 대상 로드맵의 기본 브랜치 사본. 인터뷰 상태는
    키에 없다(매번 읽는다). git 을 못 읽으면 None — 캐시를 쓰지 않는다."""
    rc, out = repo.git("for-each-ref", "--format=%(refname) %(objectname) %(symref)", "refs/heads", "refs/remotes")
    if rc != 0:
        return None
    kept = []
    for row in out.splitlines():
        name, _oid, symref = (row.split(" ") + ["", ""])[:3]
        if name != main_full and not symref:  # 기본 브랜치는 첫 요소가, 가리키는 참조(origin/HEAD)는 그 대상이 맡는다
            kept.append(row)
    refs = "\n".join(kept)
    refs_hash = hashlib.sha256(refs.encode("utf-8")).hexdigest()
    parts = [code_stamp(), mode, main or "-", refs_hash, "\n".join("%s=%s" % t for t in targets)]
    return hashlib.sha256("\0".join(parts).encode("utf-8")).hexdigest()


CODE_STAMP_FILES = ("roadmap_status.py", "roadmap_model.py", "section6.py", "check_bundle_coverage.py", "control_plane.py",
                    "repo_defaults.py", "conductor_state.py")


def code_stamp() -> str:
    """상태 계산 · 표시 스크립트의 크기와 수정 시각 — 플러그인이 바뀌면 옛 결과를 쓰지 않는다."""
    out = []
    for name in CODE_STAMP_FILES:
        try:
            st = os.stat(str(SCRIPTS / name))
            out.append("%s:%d:%d" % (name, st.st_size, st.st_mtime_ns))
        except OSError:
            out.append(name + ":-")
    return ";".join(out)


def cache_file(repo: Repo):
    common = repo.line("rev-parse", "--git-common-dir")
    if not common:
        return None
    return Path(repo.cwd, common) / "devbrew" / "control-plane.json"


def load_cache(path):
    """(entries, last, 사유 | None). last 는 레포 최상위 → 마지막 상태줄. 없는 캐시는 사유가 아니다."""
    try:
        text = read_capped(path, CACHE_MAX_BYTES)
    except FileNotFoundError:
        return {}, {}, None
    except OSError as exc:
        return {}, {}, "캐시 파일을 읽지 못했다(%s)" % type(exc).__name__
    except ValueError:
        return {}, {}, "캐시 파일이 깨져 있었다"
    try:
        data = json.loads(text)
        if data.get("version") != CACHE_VERSION or not isinstance(data.get("entries"), dict):
            raise ValueError("모양이 다르다")
    except (ValueError, AttributeError):
        return {}, {}, "캐시 파일이 깨져 있었다"
    last = data.get("last")
    return data["entries"], (last if isinstance(last, dict) else {}), None


def sweep_stale_tmp(folder):
    """끊긴 쓰기가 남긴 10분 넘은 임시 파일을 지운다."""
    limit = time.time() - 600
    try:
        with os.scandir(str(folder)) as entries:
            for entry in entries:
                if entry.name.startswith(".control-plane.") and entry.name.endswith(".tmp"):
                    try:
                        if entry.stat(follow_symlinks=False).st_mtime < limit:
                            os.unlink(entry.path)
                    except OSError:
                        pass
    except OSError:
        pass


def save_cache(path, entries, last):
    """임시 파일 + os.replace 로 원자적으로 쓴다 — 잠금이 없어 동시 실행이 서로 기다리지 않는다. 실패하면 사유."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        sweep_stale_tmp(path.parent)
        fd, tmp = tempfile.mkstemp(prefix=".control-plane.", suffix=".tmp", dir=str(path.parent))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                json.dump({"version": CACHE_VERSION, "entries": entries, "last": last}, fh, ensure_ascii=False)
            os.replace(tmp, str(path))
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
    except (OSError, ValueError) as exc:
        return "캐시 파일을 쓰지 못했다(%s)" % (getattr(exc, "strerror", None) or type(exc).__name__)
    return None


def cached_view(entry, key):
    """캐시 항목이 이 키에 맞고 모양이 온전하면 (items, select_error), 아니면 None."""
    if key is None or not isinstance(entry, dict) or entry.get("key") != key:
        return None
    try:
        items = [(str(p), r) for p, r in entry["items"] if isinstance(r, dict)]
        if len(items) != len(entry["items"]):
            return None
        return items, entry.get("select_error")
    except (KeyError, TypeError, ValueError):
        return None


def run_status(repo: Repo, path: str) -> dict:
    """roadmap_status.py <경로> --json 을 부른다. 못 읽으면 검사 불가(3) 보고서."""
    rc, out = run_bounded([sys.executable, str(SCRIPTS / "roadmap_status.py"), path, "--json"], repo.cwd,
                          None, repo.deadline, "상태 계산 " + path)
    try:
        report = json.loads(out.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        report = None
    if (not isinstance(report, dict) or not isinstance(report.get("blocks"), list)
            or report.get("exit") not in (0, 1, 3, 4)):
        return failed_report(path, "상태 계산 출력을 읽지 못했다(rc %d)" % rc)
    return report


def unfinished(report: dict) -> bool:
    return report.get("exit") in (3, 4) or any(b.get("stage") not in DONE for b in report.get("blocks") or [])


def _pr_unknown(why: str) -> dict:
    return {"number": None, "state": "알 수 없음", "source": why}


def pr_text(pr: dict) -> str:
    if pr["state"] == "알 수 없음":
        return "알 수 없음 — %s" % pr["source"]
    if pr["number"] is None:
        return "%s(%s)" % (pr["state"], pr["source"])
    return "%s %s(%s)" % (pr["number"], pr["state"], pr["source"])


def _why(exc) -> str:
    if isinstance(exc, FileNotFoundError):
        return "파일이 없다"
    if isinstance(exc, ValueError):
        return str(exc)
    if getattr(exc, "errno", None) == errno.ELOOP:
        return "링크다"
    return type(exc).__name__


def active_branch(b: dict):
    return next((s["branch"] for s in b.get("branch_states") or [] if not s.get("merged") and s.get("tip")), None)


def machine_for(repo, roadmap_rel: str):
    """(기계 상태, 사유). 파일이 없으면 빈 것. 깨졌으면 (None, 사유) — 빈 것으로 읽지 않는다."""
    common = repo.line("rev-parse", "--git-common-dir")
    if not common:
        return None, "git 공용 디렉토리를 찾지 못했다"
    try:
        path = cs.machine_path(state_root_for_common(Path(repo.cwd, common).resolve()), roadmap_rel)
        try:
            text = read_capped(path, MACHINE_MAX_BYTES)
        except FileNotFoundError:
            return cs.empty(), None
        except (OSError, ValueError) as exc:  # 링크 · 파이프 · 큰 파일은 읽지 않고 사유로 낸다
            return None, "기계 상태 파일을 읽지 못했다: %s (%s)" % (path, _why(exc))
        return cs.parse_machine(text, roadmap_rel), None
    except (cs.MachineError, FormatError) as exc:  # 한 파일이 깨져도 화면 전체를 비우지 않는다
        return None, str(exc)


def suite_lock_for(repo, roadmap_rel: str) -> str:
    """공유 스위트 잠금의 주인 · 잡은 시각 한 줄. 경로를 못 풀면 그 사유."""
    common = repo.line("rev-parse", "--git-common-dir")
    if not common:
        return "스위트 잠금: 읽지 못함 — git 공용 디렉토리를 찾지 못했다"
    try:
        mdir = cs.machine_dir(state_root_for_common(Path(repo.cwd, common).resolve()), roadmap_rel)
    except cs.MachineError as exc:
        return "스위트 잠금: 읽지 못함 — %s" % exc
    return suite_lock.describe(suite_lock.lock_path(mdir))


def gh_lookup_for(repo, deadline):
    """브랜치 → PR 사실을 `gh pr list` 로. gh 가 없으면 None."""
    exe = shutil.which("gh")
    if not exe:
        return None
    env = dict(os.environ, GH_PROMPT_DISABLED="1", NO_COLOR="1", GH_NO_UPDATE_NOTIFIER="1")

    def lookup(branch: str) -> dict:
        try:
            own = Deadline(min(deadline.left("gh pr list"), GH_CALL_CAP))  # 호출마다 상한 — 하나가 멈춰도 나머지가 산다
            rc, out = run_bounded([exe, "pr", "list", "--state", "all", "--head", branch,
                                   "--json", "number,state", "--limit", "1"], repo.cwd, env, own, "gh pr list")
        except TimedOut:
            return _pr_unknown("gh 시간 초과")
        if rc != 0:
            return _pr_unknown("gh 실패(rc %d)" % rc)
        try:
            data = json.loads(out.decode("utf-8"))
        except (UnicodeDecodeError, ValueError):
            return _pr_unknown("gh 출력을 읽지 못했다")
        if not isinstance(data, list):
            return _pr_unknown("gh 출력 모양이 다르다")
        if not data:
            return {"number": None, "state": "없음", "source": "gh"}
        if not isinstance(data[0], dict):
            return _pr_unknown("gh 출력 모양이 다르다")
        state, number = GH_STATES.get(data[0].get("state")), data[0].get("number")
        if state is None or not isinstance(number, int):
            return _pr_unknown("gh 출력 모양이 다르다")
        return {"number": "#%d" % number, "state": state, "source": "gh"}
    return lookup


def _rulings(b: dict, paths: list, read, deadline) -> None:
    """판정을 실행 원장에서, 못 읽은 원장이 있으면 설계문서 `## 판정` 보관본을 합쳐 b 에 싣는다."""
    rulings, failures = None, []
    if len(paths) > LEDGER_MAX_COUNT:
        b["ledger_cut"] = "원장 %d개 중 %d개만 읽음" % (len(paths), LEDGER_MAX_COUNT)
    for ledger in paths[:LEDGER_MAX_COUNT]:
        if not os.path.isabs(ledger):
            failures.append({"path": ledger, "reason": "절대 경로가 아니다"})
            continue
        try:
            if deadline is not None:
                deadline.left("원장 읽기")
            rulings = (rulings or []) + cs.ledger_rulings(read(ledger, LEDGER_MAX_BYTES))
        except TimedOut:
            failures.append({"path": ledger, "reason": "시간 초과"})
        except (OSError, ValueError) as exc:
            failures.append({"path": ledger, "reason": _why(exc)})
    archived = b.get("rulings_archived")
    had_ledger = rulings is not None
    if had_ledger:
        b["rulings_source"] = "실행 원장"
    if archived is not None and (rulings is None or failures):
        seen = set(r.lstrip("- ").strip() for r in rulings or [])
        rulings = (rulings or []) + [r for r in archived if r.lstrip("- ").strip() not in seen]
        b["rulings_source"] = "실행 원장 + 설계문서 ## 판정" if had_ledger else "설계문서 ## 판정"
    if failures:
        b["ledger_failures"] = failures
    if rulings is not None or failures or b.get("stage") != "머지됨":
        b["rulings"] = rulings


def merged_prs(b: dict, prs: dict, gh_lookup) -> list:
    """머지된 에픽의 브랜치마다 PR — 기계 상태 캐시가 먼저, 없으면 gh. 머지 커밋 메시지는 해석하지 않는다(호스트마다 다르다)."""
    out = []
    for s in b.get("branch_states") or []:
        br = s["branch"]
        if br in prs:
            row = prs[br]
            out.append((br, {"number": row["번호"], "state": "머지됨", "source": "기계 상태"}))
        elif gh_lookup is None:
            out.append((br, _pr_unknown("기계 상태에 없고 gh 가 없다")))
        else:
            out.append((br, gh_lookup(br)))
    return out


def overlay(items, machine_lookup, gh_lookup, use_gh: bool, read=read_capped, deadline=None, focus=None) -> None:
    """기계 상태 · 실행 원장 · gh 를 보고서에 얹는다 — 캐시 밖에서 매번 읽는다(캐시 열쇠에 넣지 않는다).
    use_gh 가 거짓(상태줄)이면 gh 도 원장도 판정도 읽지 않는다 — 상태줄은 그것들을 보이지 않는다."""
    for path, report in items:
        machine, why = machine_lookup(path)
        report["machine"], report["machine_error"] = machine, why
        ledgers, prs = {}, {}
        for row in (machine or {}).get("실행 원장", []):
            ledgers.setdefault(row["에픽"], []).append(row["원장"])
        for row in (machine or {}).get("PR", []):
            prs[row["브랜치"]] = row
        for b in report.get("blocks") or []:
            stage = b.get("stage") or ""
            partial = stage.startswith("일부 머지")
            br = active_branch(b)
            if br and (stage == "구현 끝" or (partial and IMPL_DONE_MARK in (b.get("reason") or ""))):
                if br in prs:
                    row = prs[br]
                    b["pr"] = {"number": row["번호"], "state": row["상태"], "source": "기계 상태"}
                elif not use_gh:
                    b["pr"] = _pr_unknown("기계 상태에 없다(상태줄은 gh 를 부르지 않는다)")
                elif gh_lookup is None:
                    b["pr"] = _pr_unknown("기계 상태에 없고 gh 가 없다")
                else:
                    b["pr"] = gh_lookup(br)
                if stage == "구현 끝" and b["pr"]["state"] == "열림":
                    b["stage"], b["reason"] = "PR", "%s 열림(%s)" % (b["pr"]["number"], b["pr"]["source"])
            if use_gh and focus is not None and b.get("id") == focus and stage == "머지됨":
                b["merged_prs"] = merged_prs(b, prs, gh_lookup)
            if use_gh and (stage in IMPL_STAGES or partial or stage == "머지됨"):
                _rulings(b, ledgers.get(b.get("id"), []), read, deadline)


def gather(cwd: str, arg, deadline: Deadline, ctx: dict, use_gh: bool = True, focus=None):
    """화면에 필요한 것 전부. 받은 시각은 캐시 밖에서 매번 읽는다. ctx 에 레포 최상위 · 캐시 상태를 남긴다."""
    view = {"items": [], "interview": None, "notes": [], "minutes": None, "select_error": None}
    repo = open_repo(cwd, deadline)
    supported, files, folder_error = interview_files(repo.cwd if repo else cwd)
    if repo is None:
        view["interview"] = read_interviews(supported, files, folder_error, deadline)
        if arg:
            view["items"] = [(arg, failed_report(arg, "git 레포 안이 아니다"))]
        return view
    stamp = fetch_stamp(repo)
    fetched = None
    if stamp is not None:
        view["minutes"] = max(0, int((time.time() - stamp) // 60))
        fetched = datetime.datetime.fromtimestamp(stamp).strftime("%Y-%m-%d %H:%M")
    main, main_full = default_ref(repo)
    view["no_default"] = bool(not arg and main is None
                              and repo.line("for-each-ref", "--count=1", "--format=%(refname)", "refs/remotes"))
    if arg:
        if os.path.isabs(arg):
            arg = os.path.relpath(os.path.realpath(arg), os.path.realpath(repo.cwd))
        arg = arg[2:] if arg.startswith("./") else arg
        blob = repo.line("rev-parse", "--verify", "--quiet", "%s:%s" % (main, arg)) if main else None
        targets, select_error = [(arg, blob or "-")], None
    else:
        targets, select_error = candidates(repo, main)
    mode = arg or "*"
    key = cache_key(repo, main, main_full, mode, targets)
    path = cache_file(repo)
    entries, last, note = load_cache(path) if path else ({}, {}, "git 공용 디렉토리를 찾지 못했다")
    ctx.update(top=repo.cwd, cache=path, entries=entries, last=last)
    if note:
        view["notes"].append(note)
    interview = read_interviews(supported, files, folder_error, deadline)  # 캐시 밖: 병렬 worktree 가 서로의 칸을 밀지 않는다
    hit = cached_view(entries.get(mode), key)
    if hit is not None:
        items, select_error = hit
    else:
        reports = [(p, run_status(repo, p)) for p, _blob in targets]
        items = reports if arg else [(p, r) for p, r in reports if unfinished(r)]
        if key is None:
            view["notes"].append("캐시 키를 만들지 못했다(git 읽기 실패)")
        elif path is not None and not select_error and not any(r.get("bridge_error") for _p, r in reports):
            kept = dict((k, v) for k, v in entries.items() if k == "*" and k != mode)
            kept[mode] = {"key": key, "items": [[p, r] for p, r in items],
                          "select_error": select_error}
            ctx["entries"] = kept
            err = save_cache(path, kept, last)
            if err:
                view["notes"].append(err)
    items = copy.deepcopy(items)  # 덧씌움이 캐시 항목(ctx["entries"])에 섞여 디스크에 남지 않게
    for _p, r in items:
        r["fetched_at"] = fetched  # 첫 줄의 받은 시각도 캐시 밖에서
    overlay(items, lambda rel: machine_for(repo, rel), gh_lookup_for(repo, deadline) if use_gh else None, use_gh,
            deadline=deadline, focus=focus)
    if use_gh:
        for p, r in items:
            r["suite_lock"] = suite_lock_for(repo, p)
    view.update(items=items, interview=interview, select_error=select_error)
    return view


# ── 명령줄 ───────────────────────────────────────────────────────────────────

def switch_name():
    if os.environ.get("DEVBREW_SPEC_DISTILL_DISABLE") == "1":
        return "DEVBREW_SPEC_DISTILL_DISABLE=1"
    if kill_switch_active("spec-distill", "statusline"):
        return "DEVBREW_SKIP_HOOKS 의 spec-distill:statusline"
    return None


def stdin_dir():
    """상태줄 표준 입력 JSON 의 workspace.current_dir → cwd. 없거나 읽을 수 없으면 None.
    STDIN_WAIT 초 · STDIN_MAX_BYTES 까지만 받는다 — 닫히지 않는 입력에도 기다리지 않는다."""
    try:
        if sys.stdin is None or sys.stdin.isatty():
            return None
        fd = sys.stdin.fileno()
        end = time.monotonic() + STDIN_WAIT
        chunks, size = [], 0
        while size <= STDIN_MAX_BYTES:
            wait = end - time.monotonic()
            if wait <= 0:
                break
            ready, _w, _x = select.select([fd], [], [], wait)
            if not ready:
                break
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
        data = json.loads(b"".join(chunks).decode("utf-8") or "{}")
        for cand in ((data.get("workspace") or {}).get("current_dir"), data.get("cwd")):
            if isinstance(cand, str) and os.path.isdir(cand):
                return cand
    except Exception:  # noqa: BLE001 — 표준 입력이 이상하면 프로세스 cwd 를 쓴다
        return None
    return None


def remember_line(ctx: dict, line: str):
    """레포마다 마지막 상태줄을 캐시에 둔다 — 시간 초과 때 낸다. 바뀌었을 때만 쓴다."""
    path, top, last = ctx.get("cache"), ctx.get("top"), ctx.get("last")
    if path is None or top is None or not isinstance(last, dict) or last.get(top) == line:
        return
    kept = dict(list((k, v) for k, v in last.items() if k != top)[-(LAST_LINES_MAX - 1):])
    kept[top] = line
    save_cache(path, ctx.get("entries") or {}, kept)


def timed_out_line(ctx: dict) -> str:
    path, top = ctx.get("cache"), ctx.get("top")
    if path is not None and top is not None:
        _entries, last, _note = load_cache(path)
        if isinstance(last.get(top), str) and last[top]:
            return clean(last[top] + " · 시간 초과")
    return TIMED_OUT_LINE


def cmd_statusline() -> int:
    ctx = {}
    try:
        if switch_name():
            print("")
            return 0
        deadline = Deadline(STATUSLINE_BUDGET)
        v = gather(stdin_dir() or os.getcwd(), None, deadline, ctx, use_gh=False)
        line = statusline_text(v["items"], v["interview"], v["minutes"], v["select_error"])
        remember_line(ctx, line)
        print(line)
    except TimedOut:
        print(timed_out_line(ctx))
    except Exception as exc:  # noqa: BLE001 — 상태줄은 늘 한 줄을 낸다
        print(clean("검사 불가 — 상태줄 내부 오류(%s)" % type(exc).__name__))
    return 0


def epic_view(path: str, report: dict, epic: str):
    """(줄들, rc) — 에픽 하나의 묶음 · 설계문서 · 계획 · 브랜치 · PR · 의존 · 동시 가능 · 선택 칸 · 넘김 · 판정 · 자원.
    줄마다 경로나 번호가 있어 한 단계 더 내려갈 수 있다."""
    blocks = report.get("blocks") or []
    b = next((x for x in blocks if x.get("id") == epic), None)
    if b is None:
        have = " · ".join(str(x.get("id")) for x in blocks) or "없음"
        return [clean("에픽 %s 가 로드맵 %s 에 없다 — 있는 에픽: %s" % (epic, path, have))], 2
    stages = dict((x.get("id"), x.get("stage")) for x in blocks)
    out = [clean("%s %s — %s · %s" % (b["id"], b.get("title"), b.get("stage"), b.get("reason"))),
           clean("  로드맵: %s" % path)]

    def row(label, values):
        out.append(clean("  %s: %s" % (label, " · ".join(values) if values else "없음")))

    def branch_cell(s):
        if s.get("merged"):
            return "%s(머지됨)" % s["branch"]
        return "%s(%s)" % (s["branch"], "진행 — %s" % s["tip"][:8] if s.get("tip") else "아직 없음")

    row("묶음", [b["bundle"]] if b.get("bundle") else [])
    row("설계문서", b.get("specs") or [])
    row("계획", b.get("plans") or [])
    row("브랜치", [branch_cell(s) for s in b.get("branch_states") or []])
    if b.get("pr"):
        out.append(clean("  PR: %s" % pr_text(b["pr"])))
    if b.get("merged_prs"):
        out.append(clean("  PR: " + " · ".join("%s %s" % (br, pr_text(pr)) for br, pr in b["merged_prs"])))
    row("의존", ["%s(%s)" % (d, stages.get(d)) for d in b.get("deps") or []])
    if b.get("parallel") is None:
        out.append("  동시에 갈 수 있는 에픽: 셀 수 없음")
    else:
        row("동시에 갈 수 있는 에픽", [p["id"] + ("(경로 예약 겹침: %s)" % " · ".join(p["overlap"]) if p.get("overlap") else "")
                              for p in b["parallel"]])
    for key, value in (b.get("extras") or {}).items():
        out.append(clean("  %s: %s" % (key, value)))
    handoffs = report.get("handoffs")
    if handoffs is None:
        out.append("  열린 넘김: 셀 수 없음")
    else:
        mine = [h for h in handoffs if epic in (h.get("giver"), h.get("receiver")) and h.get("state") != "확인됨"]
        unc = [h for h in mine if h.get("state") == "셀 수 없음"]
        counted = len(mine) - len(unc)
        text = "없음" if not mine else "%d개" % counted
        if unc:
            text = ("%d개 · " % counted if counted else "") + "셀 수 없음 %d개" % len(unc)
        out.append("  열린 넘김: %s" % text)
        for h in mine:
            arrow = "받음 ← %s" % h["giver"] if h["receiver"] == epic else "줌 → %s" % h["receiver"]
            out.append(clean("    %s: %s · %s · %s" % (arrow, h["item"], h["state"], h["basis"])))
    if "rulings" not in b:
        stage = b.get("stage")
        if stage in DONE and report.get("machine_error"):
            out.append("  판정 줄: 셀 수 없음 — 기계 상태를 읽지 못해 원장을 모른다")
        elif stage in DONE:
            out.append("  판정 줄: 없음 — 판정 기록 없이 %s" % stage)
        elif stage == "알 수 없음":
            out.append("  판정 줄: 셀 수 없음 — 단계를 알 수 없다")
        elif b.get("kind") == "decision":
            out.append("  판정 줄: 아직 없음")
        else:
            out.append("  판정 줄: 아직 없음(구현 전)")
    elif b["rulings"] is None:
        if report.get("machine_error"):
            out.append("  판정 줄: 셀 수 없음 — 기계 상태를 읽지 못해 원장을 모른다")
        elif b.get("ledger_failures"):
            out.append("  판정 줄: 셀 수 없음 — 실행 원장을 읽지 못했고 설계문서 `## 판정` 도 없다")
        else:
            out.append("  판정 줄: 셀 수 없음 — 실행 원장도 설계문서 `## 판정` 도 없다")
    else:
        out.append(clean("  판정 줄: %d개(%s)" % (len(b["rulings"]), b.get("rulings_source"))))
        out += [clean("    %s" % r) for r in b["rulings"]]
    out += [clean("  원장 읽기 불가: %s — %s" % (f["path"], f["reason"])) for f in b.get("ledger_failures") or []]
    if b.get("ledger_cut"):
        out.append(clean("  %s" % b["ledger_cut"]))
    if report.get("machine_error"):
        out.append(clean("  " + machine_error_line(report["machine_error"])))
    elif report.get("machine") is not None:
        m = report["machine"]
        row("자원", ["%s %s(%s)" % (r["종류"], r["경로"], r["용도"]) for r in m.get("자원", []) if r["에픽"] == epic])
        row("살아 있는 agent", ["%s(%s · %s)" % (r["이름"], r["일"], r["worktree"])
                              for r in m.get("살아 있는 agent", []) if r["에픽"] == epic])
        row("기다리는 질문", [r["질문"] for r in m.get("기다리는 질문", []) if r["에픽"] == epic])
    out += [clean("  경고: %s" % w) for w in b.get("warnings") or []]
    out += [clean("  정보: %s" % n) for n in b.get("notes") or []]
    return out, 0


def cmd_show(tasks: bool, arg, epic=None) -> int:
    sw = switch_name()
    if sw:
        if tasks:
            sys.stderr.write("꺼져 있다 — %s\n" % sw)
            return 3
        print("꺼져 있다 — %s" % sw)
        return 0
    try:
        v = gather(os.getcwd(), arg, Deadline(SHOW_BUDGET), {}, focus=epic)
    except TimedOut as exc:
        msg = clean("검사 불가 — 시간 초과(%s, %d초)" % (exc, SHOW_BUDGET))
        if tasks:
            sys.stderr.write(msg + "\n")
            return 3
        print(msg)
        return 0
    except Exception as exc:  # noqa: BLE001 — 계산이 죽어도 0 · 1 로 보이지 않는다
        msg = clean("검사 불가 — 내부 오류(%s: %s)" % (type(exc).__name__, exc))
        if tasks:
            sys.stderr.write(msg + "\n")
            return 3
        print(msg)
        return 0
    shown_error = v["select_error"] or (NO_DEFAULT if v.get("no_default") and not v["items"] else None)
    if epic:
        _path, report = v["items"][0] if v["items"] else (arg, None)
        if report is None or report.get("exit") in (3, 4):
            if report is not None and report.get("blocks") and not report.get("format_errors") and not any(x.get("id") == epic for x in report["blocks"]):
                lines, rc = epic_view(_path, report, epic)
                print("\n".join(lines))
                return rc
            if report is not None and report.get("exit") == 4:
                print("에픽 보기를 내지 못했다 — 로드맵이 아직 기본 브랜치에 없다, 전체 지도를 보인다")
            else:
                print("에픽 보기를 내지 못했다 — 로드맵 검사 불가, 전체 지도를 보인다")
            print(show_text(v["items"], v["interview"], v["notes"], first_line, shown_error))
            return 0
        lines, rc = epic_view(_path, report, epic)
        print("\n".join(lines))
        return rc
    if tasks:
        out, err, rc = tasks_output(v["items"], shown_error)
        if out:
            print("\n".join(out))
        if err:
            sys.stderr.write(err + "\n")
        return rc
    print(show_text(v["items"], v["interview"], v["notes"], first_line, shown_error))
    return 0


def _cancel(signum, _frame):
    raise TimedOut("취소 신호 %d" % signum)


def main(argv=None) -> int:
    for sig in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, _cancel)
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    ap = argparse.ArgumentParser(prog="control_plane.py",
                                 description="로드맵 상태를 상태줄 · 지도 · 작업 목록 줄로 보인다.")
    sub = ap.add_subparsers(dest="cmd")
    sub.add_parser("statusline")
    sp = sub.add_parser("show")
    sp.add_argument("--tasks", action="store_true")
    sp.add_argument("roadmap", nargs="?")
    sp.add_argument("epic", nargs="?")
    args = ap.parse_args(argv)
    if args.cmd == "statusline":
        return cmd_statusline()
    if args.cmd == "show":
        if args.roadmap is not None and (not args.roadmap.strip() or args.roadmap.startswith("-")):
            sys.stderr.write("사용법: 로드맵 경로는 비지 않고 - 로 시작하지 않는다\n")
            return 2
        if args.epic is not None and (args.tasks or not BLOCK_ID_RE.fullmatch(args.epic)):
            sys.stderr.write("사용법: 에픽은 로드맵 경로 뒤에 하나(`<대문자><숫자>[소문자]`), --tasks 와 함께 쓰지 않는다\n")
            return 2
        return cmd_show(args.tasks, args.roadmap, args.epic)
    ap.print_usage(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
