#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""control_plane.py — 로드맵 상태와 진행 중 인터뷰를 상태줄 한 줄 · 지도 · 작업 목록 줄로 보인다.

명령줄:
  control_plane.py statusline                    상태줄 한 줄. 늘 rc 0.
  control_plane.py show [<로드맵 경로>]           지도. rc 0.
  control_plane.py show --tasks [<로드맵 경로>]   작업 목록 줄 `<제목><탭><pending|in_progress|completed|keep>`.
                                                 검사 불가 · 로드맵 없음 · 꺼짐이면 표준 출력이 비고 표준 오류에
                                                 사유, rc 3. 로드맵이 여럿인데 경로가 없으면 rc 2.

단계 · 경고는 `roadmap_status.py <경로> --json`(origin/main 사본)을 하위 프로세스로 불러 읽기만 한다.
레포 파일과 git 상태를 바꾸지 않는다 — 쓰는 것은 `<git 공용 디렉토리>/devbrew/control-plane.json` 캐시 하나다.
받은 지 N분은 캐시 밖에서 매번 FETCH_HEAD 수정 시각으로 읽는다.
"""
from __future__ import annotations

import re

DONE = ("머지됨", "끝남")
# 상태줄 묶음 — 상태 계산의 단계 이름 + R5 가 더할 이름. 대기 · 끝난 단계 · 알 수 없음은 세지 않는다.
BUCKETS = (("설계", ("설계 중",)), ("구현", ("계획", "구현 중", "구현 끝", "PR")), ("준비", ("준비",)))
UNCOUNTED = ("대기", "머지됨", "끝남", "알 수 없음")
TASK_STATES = ("pending", "in_progress", "completed")
TOP_WARNINGS = (("받드는 에픽 없는 발화", "orphans"), ("미배정 번호", "unassigned"),
                ("brief 에 없는 번호", "unknown_ids"))
CTRL_RE = re.compile(r"[\x00-\x1f\x7f-\x9f]")
DISPATCH_RE = re.compile(r"\s+research_dispatches:\s*\{([^{}]*)\}\s*(?:#.*)?")
LIMIT_RE = re.compile(r"\s+research_limit:\s*(\d+)\s*(?:#.*)?")
QUEUE_HEADING = "## audit §2 대기 줄"
NO_ROADMAP = "로드맵 없음 — origin/main 에 끝나지 않은 블록이 있는 로드맵이 없다"


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
            "format_errors": [], "unknown_reasons": [reason], "exit": 3}


def first_line(report: dict) -> str:
    """상태 계산의 쉬운 첫 줄 그대로."""
    try:
        import roadmap_status
        return roadmap_status.render(report).split("\n", 1)[0]
    except Exception as exc:  # noqa: BLE001 — 첫 줄을 못 만들어도 지도의 나머지는 보인다
        return "로드맵 상태 — 첫 줄을 만들지 못했다(%s)" % type(exc).__name__


# ── 인터뷰 상태 파일 ──────────────────────────────────────────────────────────

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
        m = DISPATCH_RE.fullmatch(line)
        if m:
            n = 0
            for part in (p for p in m.group(1).split(",") if p.strip()):
                _key, sep, val = part.partition(":")
                if not sep or not val.strip().isdigit():
                    raise ValueError("research_dispatches 칸을 셀 수 없다: %s" % part.strip())
                n += int(val.strip())
        m = LIMIT_RE.fullmatch(line)
        if m:
            limit = int(m.group(1))
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
    if select_error or any(r.get("exit") == 3 for _p, r in items):
        parts.append("검사 불가")
    return clean(" · ".join(parts))


def show_text(items, interview, notes, first_line_fn, select_error=None) -> str:
    lines = []
    if select_error:
        lines.append(clean("검사 불가: %s" % select_error))
    elif not items:
        lines.append(NO_ROADMAP)
    for path, report in items:
        lines.append(clean(first_line_fn(report)))
        lines.append(clean("로드맵: %s" % path))
        blocks = report.get("blocks") or []
        stages = dict((b.get("id"), b.get("stage")) for b in blocks)
        for b in blocks:
            line = "%s %s — %s · %s" % (b.get("id"), b.get("title"), b.get("stage"), b.get("reason"))
            waiting = [d for d in b.get("deps") or [] if stages.get(d) not in DONE]
            if waiting:
                line += " ← 기다림: " + " · ".join(waiting)
            lines.append(clean(line))
            lines += [clean("    경고: %s" % w) for w in b.get("warnings") or []]
        for label, key in TOP_WARNINGS:
            vals = report.get(key)
            if vals is None:
                lines.append("%s: 셀 수 없음" % label)
            elif vals:
                lines.append(clean("%s: %d개 — %s" % (label, len(vals), " · ".join(vals))))
        lines += [clean("검사 불가: 형식 깨짐 — %s" % e) for e in report.get("format_errors") or []]
        lines += [clean("검사 불가: %s" % r) for r in report.get("unknown_reasons") or []]
        if any("rulings" in b for b in blocks):
            lines.append("판정 줄:")
            rows = [clean("    %s: %s" % (b.get("id"), r)) for b in blocks for r in b.get("rulings") or []]
            lines += rows or ["    없음"]
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
    return out, "", 0
