#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_status.py — 지휘자 현황(STATUS)의 꼴 · 계산 · `sync`.

STATUS 는 이 스크립트가 계산해 상태 브랜치에 쓴다. 손으로 고치지 않는다. 재료는 상태 계산(`roadmap_status.py --json`) ·
기계 상태 · 상태 브랜치의 편지이고, 글에 싣는 칸은 모두 `scrub` 를 거친다(질문 본문 · 기계 이름 · 절대경로는 나가지 않는다).

종료 코드: 0 · 1(없음/아님) · 2 사용법 · 3 읽기 불가 · 5 다른 세션의 표지.

가져오는 모듈은 `conductor_branch` · `conductor_mail` · `conductor_ledger` · `conductor_state` · `repo_defaults` 다.
"""
from __future__ import annotations

import argparse
import datetime
import difflib
import re
import sys
from pathlib import Path
from typing import NamedTuple, Optional

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import conductor_branch as CB  # noqa: E402
import conductor_ledger as L  # noqa: E402
import conductor_mail as CM  # noqa: E402
import conductor_state as cs  # noqa: E402
import repo_defaults  # noqa: E402

STATUS_SECTIONS = ("에픽", "열린 PR", "기다리는 질문", "작업", "편지", "안 올린 규칙 고침")
NONE_LINE = "없음"
STALE_AFTER = 3600   # 초 — 마지막 계산이 이보다 낡으면 달라진 것이 없어도 다시 쓴다
OTHER_SESSION = "다른 세션이 이 로드맵의 현황을 쓰고 있다"
UNCHANGED = "달라진 것이 없다 — 쓰지 않았다"
TITLE_HEAD = "# STATUS — "
ROADMAP_HEAD = "- 로드맵: "
STAMP_HEAD = "- 계산: "
STAMP_LINE = 3   # 계산 줄의 자리(0 부터) — 같은 재료인지 견줄 때 뺀다
NO_TIME = "-"
SEP = " · "
STAMP_LINE_RE = re.compile(cs.STAMP_RE.pattern + r" · 기준 커밋 ([0-9a-f]{8}) · 지휘 세션 ([A-Za-z0-9_-]{8})")
LOCAL_TIME_RE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}")
PATH_MARK, MACHINE_MARK = "<경로>", "<기계>"


class StatusError(ValueError):
    pass


class Status(NamedTuple):
    title: str
    roadmap: str
    computed: str
    base: str
    session: str
    sections: dict


class Synced(NamedTuple):
    result: Optional[CB.Result]
    notes: tuple
    wrote: bool


# ── 꼴 ───────────────────────────────────────────────────────────────────────

def render_status(status: Status) -> str:
    out = [TITLE_HEAD + status.title, "", ROADMAP_HEAD + status.roadmap,
           "%s%s · 기준 커밋 %s · 지휘 세션 %s" % (STAMP_HEAD, status.computed, status.base, status.session)]
    for name in STATUS_SECTIONS:
        out += ["", "## " + name] + ["- " + line for line in status.sections[name]]
    return "\n".join(out) + "\n"


def parse_status(text: str) -> Status:
    """꼴이 이 모듈이 쓰는 것과 다르면 StatusError — 남이 쓴 글일 수 있으니 이 밖의 예외는 내지 않는다."""
    if not isinstance(text, str) or not text.endswith("\n") or text.endswith("\n\n"):
        raise StatusError("글이 줄바꿈 하나로 끝나지 않는다")
    lines = text[:-1].split("\n")
    if len(lines) < 4 or not lines[0].startswith(TITLE_HEAD) or not lines[0][len(TITLE_HEAD):] or lines[1] != "":
        raise StatusError("머리 줄의 꼴이 다르다")
    if not lines[2].startswith(ROADMAP_HEAD) or not lines[2][len(ROADMAP_HEAD):] or not lines[3].startswith(STAMP_HEAD):
        raise StatusError("로드맵 · 계산 줄의 꼴이 다르다")
    m = STAMP_LINE_RE.fullmatch(lines[3][len(STAMP_HEAD):])
    if m is None:
        raise StatusError("계산 줄의 꼴이 다르다")
    computed = lines[3][len(STAMP_HEAD):].split(SEP, 1)[0]
    if CB.parse_stamp(computed) is None:
        raise StatusError("계산 시각이 달력에 없다")
    sections, i = {}, 4
    for name in STATUS_SECTIONS:
        if i + 2 > len(lines) or lines[i] != "" or lines[i + 1] != "## " + name:
            raise StatusError("절 %s 의 자리가 다르다" % name)
        i += 2
        body = []
        while i < len(lines) and lines[i].startswith("- ") and lines[i][2:]:
            body.append(lines[i][2:])
            i += 1
        if not body:
            raise StatusError("절 %s 에 줄이 없다" % name)
        sections[name] = body
    if i != len(lines):
        raise StatusError("절 밖에 글이 더 있다")
    return Status(lines[0][len(TITLE_HEAD):], lines[2][len(ROADMAP_HEAD):], computed, m.group(1), m.group(2), sections)


# ── 가리기 ───────────────────────────────────────────────────────────────────

def scrub(text: str, root) -> str:
    """STATUS 에 싣는 재료 칸의 글 — 줄바꿈은 빈칸, 이 기계의 경로는 `<경로>`, 기계 이름은 `<기계>`(J18)."""
    text = "".join(" " if ch in "\r\n" else ch for ch in str(text))
    roots = CM.private_roots(root)
    out = []
    for tok in re.split(r"(\s+)", text):
        hits = [tok.find(r) for r in roots if r in tok]
        shape = CM.PATH_IN_TEXT_RE.search(tok)   # 앞에 글자가 붙어도 절대경로 꼴이면 잡는다 — 편지 about 과 한 정의다
        if shape is not None:
            hits.append(shape.start())
        if hits:
            tok = tok[:min(hits)] + PATH_MARK
        out.append(tok)
    text = CB.redact("".join(out))
    pattern = CB.machine_pattern()
    if pattern is not None:
        text = pattern.sub(MACHINE_MARK, text)
    return CB.visible(text).strip()


# ── 계산 ─────────────────────────────────────────────────────────────────────

def rules_gap(root, roadmap_rel: str, tip: Optional[str]) -> int:
    """상태 브랜치의 규칙 사본과 기본 브랜치의 그 파일에서 한쪽에만 있는 줄 수(더한 줄 + 뺀 줄). 사본이 없으면 0(J19)."""
    if tip is None:
        return 0
    path = CB.team_of(root, roadmap_rel).rules
    mine = CB.read(root, tip, path)
    if mine is None:
        return 0
    base = repo_defaults.default_branch(str(root))[0]
    theirs = (CB.read(root, base, path) if base else None) or ""
    return sum(1 for d in difflib.ndiff(theirs.splitlines(), mine.splitlines()) if d.startswith(("+ ", "- ")))


def _title(root, roadmap_rel: str, folder: str, base: Optional[str]) -> str:
    text = CB.read(root, base, roadmap_rel) if base else None
    for line in (text or "").split("\n"):
        if line.startswith("# ") and line[2:].strip():
            return scrub(line[2:].strip(), root)
    return scrub(folder, root)


def _local_stamp(value: str, now: datetime.datetime) -> str:
    """기계 상태의 시각(현지 시각 `YYYY-MM-DD HH:MM`)에 계산 시계의 UTC 차이를 붙인다. 꼴이 다르면 `-`."""
    if LOCAL_TIME_RE.fullmatch(value):
        value = value + now.strftime(" %z")
    return value if CB.parse_stamp(value) is not None else NO_TIME


def _asked_since(row: dict) -> datetime.datetime:
    return CB.parse_stamp(row.get("언제부터")) or datetime.datetime.max.replace(tzinfo=datetime.timezone.utc)


def build_status(root, roadmap_rel: str, session: str, tip: Optional[str], now=None) -> Status:
    now = now or datetime.datetime.now().astimezone()
    team = CB.team_of(root, roadmap_rel)
    table = CB.roadmaps(root)
    mine = [r for r in table if r.name == team.name]
    if mine and mine[0].path != roadmap_rel:   # 한 폴더의 다른 로드맵 파일의 보고를 섞어 싣지 않는다(J22)
        raise CB.BranchError(3, "이 상태 브랜치는 다른 로드맵 파일의 것이다(%s) — 쓰지 않는다" % CB.visible(mine[0].path))
    if not mine or mine[0].report is None:
        raise CB.BranchError(3, "상태를 셀 수 없다 — %s" % CB.visible(mine[0].why if mine else "기본 브랜치에 이 로드맵이 없다"))
    base = repo_defaults.default_branch(str(root))[0]
    if not base:
        raise CB.BranchError(3, "상태를 셀 수 없다 — 기본 브랜치를 찾지 못했다")
    blocks = mine[0].report["blocks"]
    data = L.load(root, roadmap_rel)
    epics = []
    for b in blocks:
        if b.get("stage") in CB.DONE_STAGES:
            continue
        line = "%s %s%s%s" % (scrub(b.get("id", ""), root), scrub(b.get("title", ""), root), SEP, scrub(b.get("stage", ""), root))
        reason = scrub(b.get("reason") or "", root)
        epics.append(line + (SEP + reason if reason else ""))

    def epic_of(branch):
        return next((b["id"] for b in blocks if branch in (b.get("branches") or [])), cs.ASK_NO_EPIC)

    prs = ["%s · %s · %s" % (scrub(epic_of(r["브랜치"]), root), scrub(r["번호"], root), scrub(r["브랜치"], root))
           for r in data["PR"] if r["상태"] == cs.PR_STATES[0]]
    asking = ["%s · %s · %s" % (scrub(r["에픽"], root), scrub(r["종류"], root), scrub(r["언제부터"], root))
              for r in sorted(data[cs.ASKING], key=_asked_since)]
    sent_at = {a["이름"]: a["보낸 때"] for a in data["살아 있는 agent"]}
    work = []
    for w in data["작업"]:
        if w["단계"] in cs.WORK_DONE:
            continue
        owner = w["담당"] != NONE_LINE
        when = _local_stamp(sent_at.get(w["담당"], NO_TIME), now) if owner else NO_TIME
        work.append("%s · %s · 담당자 %d · %s" % (scrub(w["종류"], root), scrub(w["이름"], root), 1 if owner else 0, when))
    c = CM.counts(root, team.name, tip, table)
    letters = "보낸 글 %d · 아직 받지 않은 보낸 글 %d · 답 기다리는 글 %d · 받은 글 %d" % (c.sent, c.unreceived, c.awaiting, c.acked)
    sections = {"에픽": epics, "열린 PR": prs, "기다리는 질문": asking, "작업": work, "편지": [letters],
                "안 올린 규칙 고침": ["%d줄" % rules_gap(root, roadmap_rel, tip)]}
    for name in STATUS_SECTIONS:
        sections[name] = sections[name] or [NONE_LINE]
    return Status(_title(root, roadmap_rel, team.name, base), roadmap_rel, CB.stamp(now), base[:8], session[:8], sections)


# ── sync ─────────────────────────────────────────────────────────────────────

def _lower_window(root, roadmap_rel: str, session: str) -> None:
    """건 길이 질문 창이고 이 세션이 건 줄을 내린다 — 이 세션이 다시 돈다는 것이 답을 받았다는 뜻이다."""
    def mine(row):
        return row["건 길"] == cs.ASK_WINDOW and row["세션"] == session
    if any(mine(r) for r in L.load(root, roadmap_rel)[cs.ASKING]):
        L.update(root, roadmap_rel, session, lambda d: d.__setitem__(cs.ASKING, [r for r in d[cs.ASKING] if not mine(r)]))


def _claimed_at(root, roadmap_rel: str) -> Optional[datetime.datetime]:
    try:
        return datetime.datetime.fromtimestamp((L.mpath(root, roadmap_rel).parent / cs.MARKER).stat().st_mtime, datetime.timezone.utc)
    except OSError:
        return None


def _without_stamp(text: str) -> list:
    return [line for i, line in enumerate(text.split("\n")) if i != STAMP_LINE]


def sync(root, roadmap_rel: str, session: str, now=None, lower_window: bool = True) -> Synced:
    now = now or datetime.datetime.now().astimezone()
    L.need_holder(root, roadmap_rel, session)
    if lower_window:
        _lower_window(root, roadmap_rel, session)
    why = CB.availability(root, roadmap_rel)
    if why:
        return Synced(None, (why,), False)
    team = CB.team_of(root, roadmap_rel)
    local = CB.local_tip(root, team.name)
    if local is None:
        raise CB.BranchError(1, "상태 브랜치가 없다 — 먼저 conductor_branch.py ensure 를 돌린다")
    notes = []
    tip, split = CB.seen_tip(root, team.name)
    if tip is None:
        tip = local
        notes.append(CB.visible(split or "앞선 끝을 가리지 못했다"))
    old_text = CB.read(root, tip, team.status)
    old = None
    if old_text is not None:
        try:
            old = parse_status(old_text)
        except StatusError:
            notes.append("앞의 STATUS 를 읽지 못해 새로 쓴다")
    if old is not None:
        if old.roadmap != roadmap_rel:
            raise CB.BranchError(3, "이 상태 브랜치는 다른 로드맵 파일의 것이다(%s) — 쓰지 않는다" % CB.visible(old.roadmap))
        claimed, at = _claimed_at(root, roadmap_rel), CB.parse_stamp(old.computed)
        if old.session != session[:8] and claimed is not None and at is not None and at > claimed:
            notes.append("%s — 세션 %s · %s" % (OTHER_SESSION, old.session, old.computed))
    fresh = render_status(build_status(root, roadmap_rel, session, tip, now))
    if old is not None and _without_stamp(fresh) == _without_stamp(old_text):
        age = (now - CB.parse_stamp(old.computed)).total_seconds()
        if age <= STALE_AFTER:
            return Synced(None, tuple(notes) + (UNCHANGED,), False)
    res = CB.write(root, roadmap_rel, session,
                   lambda base: {team.status: render_status(build_status(root, roadmap_rel, session, base.commit, now))}, "STATUS")
    return Synced(res, tuple(notes) + tuple(res.notes), res.commit is not None)


# ── waiting ──────────────────────────────────────────────────────────────────

def waiting_add(root, roadmap_rel: str, session: str, epic: str, kind: str, via: str, now=None) -> Synced:
    """사용자에게 건 질문 한 줄을 기계 상태에 올리고 STATUS 에 싣는다. 같은 (에픽, 종류) 가 있으면 두고 처음 시각을 지킨다."""
    now = now or datetime.datetime.now().astimezone()
    if not (cs.ASK_EPIC_RE.fullmatch(epic) or epic == cs.ASK_NO_EPIC):
        raise CB.BranchError(2, "에픽은 에픽 이름이거나 %s 다: %s" % (cs.ASK_NO_EPIC, CB.visible(repr(epic))))
    if kind not in cs.ASK_KINDS:
        raise CB.BranchError(2, "종류는 %s 중 하나다: %s" % (SEP.join(cs.ASK_KINDS), CB.visible(repr(kind))))
    if via not in cs.ASK_VIA:
        raise CB.BranchError(2, "건 길은 %s 중 하나다: %s" % (SEP.join(cs.ASK_VIA), CB.visible(repr(via))))

    def change(d):
        if not any(r["에픽"] == epic and r["종류"] == kind for r in d[cs.ASKING]):
            d[cs.ASKING].append({"에픽": epic, "종류": kind, "건 길": via, "언제부터": CB.stamp(now), "세션": session})
    L.update(root, roadmap_rel, session, change)
    return sync(root, roadmap_rel, session, now=now, lower_window=False)


def waiting_clear(root, roadmap_rel: str, session: str, epic: str, kind: Optional[str] = None, now=None):
    """에픽(과 종류를 줬으면 종류)이 같은 줄을 내린다. 세션 칸은 보지 않는다. (내린 줄 수, sync 결과)."""
    gone = []

    def hit(row):
        return row["에픽"] == epic and (kind is None or row["종류"] == kind)

    def change(d):
        gone.extend(r for r in d[cs.ASKING] if hit(r))
        d[cs.ASKING] = [r for r in d[cs.ASKING] if not hit(r)]
    L.update(root, roadmap_rel, session, change)
    return len(gone), sync(root, roadmap_rel, session, now=now, lower_window=False)


# ── 명령줄 ───────────────────────────────────────────────────────────────────

def main(argv=None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="conductor_status.py", description="지휘자 현황")
    ap.add_argument("--root", default=".")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sy = sub.add_parser("sync", help="현황을 계산해 상태 브랜치에 쓴다")
    sy.add_argument("--roadmap", required=True)
    sy.add_argument("--session", required=True)
    wa = sub.add_parser("waiting", help="사용자에게 건 질문을 올리고 내린다")
    wsub = wa.add_subparsers(dest="wcmd", required=True)
    wadd = wsub.add_parser("add")
    wclr = wsub.add_parser("clear")
    for p in (wadd, wclr):
        p.add_argument("--roadmap", required=True)
        p.add_argument("--session", required=True)
        p.add_argument("--epic", required=True)
    wadd.add_argument("--kind", required=True)
    wadd.add_argument("--via", required=True)
    wclr.add_argument("--kind")
    args = ap.parse_args(argv)
    try:
        extra = []
        if args.cmd == "waiting" and args.wcmd == "add":
            out = waiting_add(args.root, args.roadmap, args.session, args.epic, args.kind, args.via)
        elif args.cmd == "waiting":
            n, out = waiting_clear(args.root, args.roadmap, args.session, args.epic, args.kind)
            extra.append("내린 줄 %d" % n)
        else:
            out = sync(args.root, args.roadmap, args.session)
    except (CB.BranchError, L.Fail) as exc:
        print("[spec-distill] " + CB.visible(str(exc)), file=sys.stderr)
        return exc.rc
    except Exception as exc:   # 예상 밖 예외도 종료 코드 3 — 쓰지 못한 것이다
        print("[spec-distill] 현황을 쓰지 못했다 — %s: %s" % (type(exc).__name__, CB.visible(str(exc).split("\n")[0])), file=sys.stderr)
        return 3
    for line in extra + list(out.notes):
        print("[spec-distill] " + line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
