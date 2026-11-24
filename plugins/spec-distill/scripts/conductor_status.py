#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_status.py — 지휘자 현황(STATUS)의 꼴 · 계산 · `sync`.

STATUS 는 이 스크립트가 계산해 상태 브랜치에 쓴다. 손으로 고치지 않는다. 재료는 상태 계산(`roadmap_status.py --json`) ·
기계 상태 · 상태 브랜치의 편지이고, 글에 싣는 칸은 모두 `scrub` 를 거친다(질문 본문 · 기계 이름 · 절대경로는 나가지 않는다).

종료 코드: 0 · 1(없음/아님) · 2 사용법 · 3 읽기 불가 · 5 다른 세션의 표지.

가져오는 모듈은 `conductor_branch` · `conductor_mail` · `conductor_ledger` · `conductor_state` · `repo_defaults` · `roadmap_model` ·
`roadmap_status` · `suite_lock` · `state_path` · `team_status`(남의 고침을 세는 읽기 함수) 다.
`sync` 는 함수 안에서 `leader_seat` 를 가져온다(규칙 사본의 같아짐 · 갈라짐 · 남의 고침 · 확인한 끝 줄이기) — `show` 는 가져오지 않는다.
"""
from __future__ import annotations

import argparse
import datetime
import difflib
import json
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
import roadmap_model  # noqa: E402
import roadmap_status as RS  # noqa: E402
import suite_lock  # noqa: E402
import team_status as TS  # noqa: E402
from state_path import state_root  # noqa: E402

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
NO_FETCH = "상태 브랜치를 받아 오지 않는 설정이다"
FETCH_HINT = "git fetch origin 'refs/heads/%s*:refs/remotes/origin/%s*' 로 받아 온다" % (CB.STATE_BRANCH_PREFIX, CB.STATE_BRANCH_PREFIX)
NO_STATUS = "STATUS 없음 — conductor_status.py sync 를 돌린다"
SUITE_UNREAD = "스위트 잠금을 읽지 못했다"
LETTERS_UNREAD = "갈라진 상태 브랜치라 글을 읽지 못했다"
OWN_EDITS = "이 기계가 쓴 것으로 적힌 고침 %d"
FOREIGN_TAIL = " — conductor_branch.py confirm 으로 차이를 보고 사용자 확인 뒤 기록한다"


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
        if CB.looks_absolute(tok):   # 경계(괄호 · `=` · `:` 등) 뒤의 절대경로 꼴 — 가리기 · 편지 about 과 한 정의다(M26)
            hits.append(CB.ABSOLUTE_RE.search(tok).start())
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


def leftovers(root, roadmap_rel: str, tip: Optional[str] = None) -> dict:
    """지우기 전에 보이는 남은 것 넷 — 상대가 아직 받지 않은 보낸 글 · 내가 답하지 않은 온 질문 · 남은 대기 줄 · 안 올린 규칙 고침.
    `tip` 이 없으면 로컬 끝에서 센다. 남은 대기 줄은 그 끝의 `pending.md` 에서 `- ` 로 시작하는 줄 수다(파일이 없으면 0)."""
    team = CB.team_of(root, roadmap_rel)
    if tip is None:
        tip = CB.local_tip(root, team.name)
    pending = (CB.read(root, tip, team.path(CB.PENDING_FILE)) or "") if tip is not None else ""
    return {"unreceived": CM.counts(root, team.name, tip, CB.roadmaps(root)).unreceived,
            "unanswered": CM.unanswered(root, team.name, tip),
            "pending": sum(1 for line in pending.splitlines() if line.startswith("- ")),
            "rules": rules_gap(root, roadmap_rel, tip)}


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


def own_lines(own: Optional[list]) -> list:
    """이 기계가 쓴 것으로 적힌 고침 → 알릴 줄들(없거나 재지 못하면 빈 목록) — 막지 않고 드러낸다."""
    if not own:
        return []
    return [OWN_EDITS % len(own)] + ["  %s · %s" % (c[:8], " · ".join(CB.visible(p) for p in paths)) for c, paths in own]


def foreign_line(n: Optional[int]) -> Optional[str]:
    """확인되지 않은 남의 고침 수 → 알릴 한 줄(0 이면 None · 재지 못함이면 「남의 고침을 재지 못했다」)."""
    if n is None:
        return TS.FOREIGN_UNMEASURED
    return TS.FOREIGN % n + FOREIGN_TAIL if n else None


def _settled(LS, root, roadmap_rel: str, session: str, name: str) -> tuple:
    """쓴 뒤 읽을 끝에서 두 쪽 남의 고침을 세고 `확인한 끝` 절을 줄인다 — 알릴 줄들."""
    seen, _split = CB.seen_tip(root, name)
    told = []
    n = LS.settle(root, roadmap_rel, session, seen, told) if seen is not None else None
    line = foreign_line(n)
    return tuple(told) + ((line,) if line else ())


def sync(root, roadmap_rel: str, session: str, now=None, lower_window: bool = True) -> Synced:
    """STATUS 를 계산해 상태 브랜치에 쓴다. 규칙 사본이 기본 브랜치의 지금 글과 같고 규칙 쪽에 확인되지 않은 남의 고침이 없으면
    같은 커밋에서 사본과 `rules-base.md` 를 지운다(STATUS 가 같아도 쓴다). 사본이 갈라졌으면 알린다.
    쓰든 안 쓰든 끝에 읽을 끝의 확인되지 않은 남의 고침(규칙 · 대기 줄)을 세어 알리고 `확인한 끝` 절을 줄인다(M5)."""
    import leader_seat as LS   # 함수 안에서 가져온다 — 현황 화면(show)이 리더 자리를 끌어오지 않게
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
    if LS.rules_state(root, roadmap_rel, tip).verdict == LS.VERDICTS[3]:
        notes.append(LS.DIVERGED + " — conductor_branch.py rules-branch 는 만들지 않는다")

    def droppable(commit):   # 머지된 사본 — 지금 글과 같고 규칙 쪽 남의 고침이 0 일 때만(재지 못함도 남긴다)
        return (commit is not None and LS.rules_state(root, roadmap_rel, commit).verdict == LS.VERDICTS[1]
                and LS.foreign(root, roadmap_rel, commit, TS.rules_paths(team)) == [])

    fresh = render_status(build_status(root, roadmap_rel, session, tip, now))
    if old is not None and not droppable(tip) and _without_stamp(fresh) == _without_stamp(old_text):   # 지울 사본이 있으면 바뀐 것이다
        age = (now - CB.parse_stamp(old.computed)).total_seconds()
        if age <= STALE_AFTER:
            return Synced(None, tuple(notes) + (UNCHANGED,) + _settled(LS, root, roadmap_rel, session, team.name), False)
    if split is None:   # 받아 온 끝 위에서 쓴다 — 로컬 끝에서 고침을 셈하면 남의 끝을 못 보고 「바뀐 것 없음」 으로 끝날 수 있다
        notes.extend(LS.catch_up(root, team.name, tip))   # 앞당겼으면 「다른 곳에서 이 브랜치에 썼다」 — 다시 만들 때와 같은 알림

    def edit(base):   # 사본이 같아 지우면 STATUS 의 줄 수도 0 이다 — 같은 글이라 남은 줄이 없다
        changes = {team.status: render_status(build_status(root, roadmap_rel, session, base.commit, now))}
        if droppable(base.commit):
            changes.update({team.rules: None, team.path(LS.RULES_BASE_FILE): None})
        return changes

    res = CB.write(root, roadmap_rel, session, edit, "STATUS")
    return Synced(res, tuple(notes) + tuple(res.notes) + _settled(LS, root, roadmap_rel, session, team.name), res.commit is not None)


# ── waiting ──────────────────────────────────────────────────────────────────

def waiting_add(root, roadmap_rel: str, session: str, epic: str, kind: str, via: str, now=None) -> Synced:
    """사용자에게 건 질문 한 줄을 기계 상태에 올리고 STATUS 에 싣는다. 같은 (에픽, 종류) 줄이 있으면 — 그 줄이 질문 창이고
    이 세션이 건 것이면 앞 질문은 답을 받은 것이라 새 줄로 바꾸고(언제부터 지금), 그 밖(턴 끝 · 다른 세션의 줄)은 아직 기다리는
    질문이라 언제부터를 두고 건 길 · 세션만 새 값으로 바꾼다(M24 — 턴 끝 줄을 질문 창으로 다시 물으면 다음 sync 가 내린다)."""
    now = now or datetime.datetime.now().astimezone()
    if not (cs.ASK_EPIC_RE.fullmatch(epic) or epic == cs.ASK_NO_EPIC):
        raise CB.BranchError(2, "에픽은 에픽 이름이거나 %s 다: %s" % (cs.ASK_NO_EPIC, CB.visible(repr(epic))))
    if kind not in cs.ASK_KINDS:
        raise CB.BranchError(2, "종류는 %s 중 하나다: %s" % (SEP.join(cs.ASK_KINDS), CB.visible(repr(kind))))
    if via not in cs.ASK_VIA:
        raise CB.BranchError(2, "건 길은 %s 중 하나다: %s" % (SEP.join(cs.ASK_VIA), CB.visible(repr(via))))

    fresh = {"에픽": epic, "종류": kind, "건 길": via, "언제부터": CB.stamp(now), "세션": session}

    def change(d):
        for i, row in enumerate(d[cs.ASKING]):
            if row["에픽"] == epic and row["종류"] == kind:
                answered = row["건 길"] == cs.ASK_WINDOW and row["세션"] == session
                d[cs.ASKING][i] = fresh if answered else dict(row, **{"건 길": via, "세션": session})
                return
        d[cs.ASKING].append(fresh)
    L.update(root, roadmap_rel, session, change)
    return sync(root, roadmap_rel, session, now=now, lower_window=False)


def waiting_clear(root, roadmap_rel: str, session: str, epic: str, kind: Optional[str] = None, now=None):
    """에픽(과 종류를 줬으면 종류)이 같은 줄을 내린다. 세션 칸은 보지 않는다. (내린 줄 수, sync 결과).
    종류는 주었으면 종류 여덟 가운데 하나다 — 아니면 BranchError(2) 이고 아무것도 내리지 않는다."""
    if kind is not None and kind not in cs.ASK_KINDS:
        raise CB.BranchError(2, "종류는 %s 중 하나다: %s" % (SEP.join(cs.ASK_KINDS), CB.visible(repr(kind))))
    gone = []

    def hit(row):
        return row["에픽"] == epic and (kind is None or row["종류"] == kind)

    def change(d):
        gone.extend(r for r in d[cs.ASKING] if hit(r))
        d[cs.ASKING] = [r for r in d[cs.ASKING] if not hit(r)]
    L.update(root, roadmap_rel, session, change)
    return len(gone), sync(root, roadmap_rel, session, now=now, lower_window=False)


# ── 로드맵 사이 ──────────────────────────────────────────────────────────────

SHA_RE = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?")
VERSION_RE = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.+-]+)?")
HOLD_TIME_RE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2} ([0-9]{2}:[0-9]{2}):[0-9]{2}")


def _main_commit(root) -> str:
    sha = repo_defaults.default_branch(str(root))[0]
    if not sha or not SHA_RE.fullmatch(sha):
        raise CB.BranchError(3, "다른 로드맵과 닿는 것을 셀 수 없다 — 기본 브랜치를 찾지 못했다")
    return sha


def _shared_names(root) -> tuple:
    try:
        result = repo_defaults.resolve(str(root))
    except repo_defaults.SettingsError as exc:
        raise CB.BranchError(3, "%s — %s" % (CB.SETTINGS_UNREADABLE, CB.visible(str(exc))))
    names = result["values"].get("shared_files")
    if result["errors"] or not names:
        why = (result["errors"] or ["공유 파일 값이 없다"])[0]
        raise CB.BranchError(3, "%s — %s" % (CB.SETTINGS_UNREADABLE, CB.visible(why)))
    return tuple(names)


def _unchecked_note(block: dict) -> bool:
    return any(str(n).startswith(RS.PR_UNCHECKED) for n in block.get("notes") or [])


def open_branches(root, road) -> list:
    """그 로드맵의 열린 브랜치 — 끝나지 않은 블록의 머지되지 않고 끝이 있는 브랜치마다 한 줄(J32)."""
    out = []
    for b in (road.report or {}).get("blocks") or []:
        if b.get("stage") in CB.DONE_STAGES:
            continue
        unchecked = _unchecked_note(b)
        for s in b.get("branch_states") or []:
            if s.get("tip") and not s.get("merged") and SHA_RE.fullmatch(s["tip"]):
                out.append({"epic": b["id"], "branch": CB.visible(s["branch"]), "tip": s["tip"], "unchecked": unchecked})
    return sorted(out, key=lambda o: (o["epic"], o["branch"]))


def _unfinished_blocks(root, road, main: str) -> list:
    """기본 브랜치의 로드맵 글에서 읽은 끝나지 않은 블록 — [(번호, 단계, 예약, 의존, 미확인)]. 형식 오류면 BranchError(3)."""
    text = CB.read(root, main, road.path)
    if text is None:
        raise CB.BranchError(3, "기본 브랜치에서 로드맵 글을 읽지 못했다")
    _meta, parsed, _rec, _risk, errors = roadmap_model.parse_roadmap(text)
    if errors:
        raise CB.BranchError(3, "로드맵 형식 오류 — %s" % errors[0])
    by_id = {b["id"]: b for b in (road.report or {}).get("blocks") or []}
    out = []
    for p in parsed:
        got = by_id.get(p["id"])
        if p.get("kind") == "decision" or got is None or got.get("stage") in CB.DONE_STAGES:
            continue
        out.append((p["id"], got["stage"], list(p.get("reserved") or []), list(p.get("deps") or []), _unchecked_note(got)))
    return out


def reserve_overlaps(root, mine, other, shared) -> list:
    """두 로드맵의 끝나지 않은 블록 가운데 경로 예약이 겹치는 쌍 — 번호를 `<로드맵 이름>:<번호>` 로 바꿔 넘겨 겹치지 않게 한다."""
    main = _main_commit(root)
    rows, info = [], {}
    for road in (mine, other):
        for bid, stage, reserved, deps, unchecked in _unfinished_blocks(root, road, main):
            key = "%s:%s" % (road.name, bid)
            info[key] = (road.name, bid, stage, unchecked)
            rows.append({"id": key, "reserved": reserved, "deps": ["%s:%s" % (road.name, d) for d in deps]})
    out = []
    for pair in RS.overlaps(rows, shared):
        a, b = pair["blocks"]
        if info[a][0] == info[b][0]:
            continue
        mine_k, theirs_k = (a, b) if info[a][0] == mine.name else (b, a)
        for path in pair["paths"]:
            out.append({"path": CB.visible(path), "theirs": (info[theirs_k][1], info[theirs_k][2]),
                        "mine": (info[mine_k][1], info[mine_k][2]), "unchecked": info[theirs_k][3]})
    return sorted(out, key=lambda r: (r["path"], r["theirs"], r["mine"]))


def changed_overlaps(git, main: str, mine_open: list, other_open: list, shared) -> list:
    """열린 브랜치 쌍이 같은 파일을 바꿨는가 — 공유 파일은 뺀다."""
    cache = {}

    def changed(tip):
        if tip not in cache:
            cache[tip] = {p for p in git.changed(main, tip) if not RS._shared(p, shared)}
        return cache[tip]
    out = []
    for m in mine_open:
        for t in other_open:
            for path in sorted(changed(m["tip"]) & changed(t["tip"])):
                out.append({"path": CB.visible(path), "theirs": t["branch"], "mine": m["branch"], "unchecked": t["unchecked"]})
    return out


def _json_of(git, rev: str, path: str):
    """(이름, 판) — 읽지 못하거나 꼴 밖이면 (None, None)."""
    text = git.blob(rev, path)
    try:
        data = json.loads(text) if text is not None else None
    except (ValueError, RecursionError):
        return None, None
    if not isinstance(data, dict) or not isinstance(data.get("version"), str) or not VERSION_RE.fullmatch(data["version"]):
        return None, None
    name = data.get("name")
    return (name if isinstance(name, str) and name else path), data["version"]


def version_claims(root, git, main: str, open_by_roadmap: dict, shared) -> tuple:
    """(같은 판을 둘 이상이 잡은 것, 읽지 못한 판 파일 수). 판 파일 이름이 공유 파일 목록에 없으면 ([], 0)."""
    if repo_defaults.VERSION_FILE not in shared:
        return [], 0
    rc, out, err = git.run_err("ls-tree", "-r", "-z", "--name-only", main)
    if rc != 0:
        git.fail("ls-tree", rc, err)
        return [], 0
    paths = sorted(p for p in out.split("\0") if p and p.rsplit("/", 1)[-1] == repo_defaults.VERSION_FILE)
    claims, unreadable = [], 0
    for path in paths:
        name, base = _json_of(git, main, path)
        if base is None:
            unreadable += 1
            continue
        held = {}
        for road_name, opened in open_by_roadmap.items():
            for o in opened:
                if not git.exists(o["tip"], path):
                    continue   # 이 브랜치는 그 파일을 갖지 않는다 — 읽지 못한 것이 아니다
                _n, version = _json_of(git, o["tip"], path)
                if version is None:
                    unreadable += 1
                elif version != base:
                    held.setdefault(version, set()).add((CB.visible(road_name), o["branch"]))
        for version, holders in sorted(held.items()):
            if len(holders) >= 2:
                claims.append({"name": CB.visible(name), "base": base, "version": version, "holders": sorted(holders)})
    return claims, unreadable


def default_moves(git, main: str, mine_open: list, reserved: list, shared) -> list:
    """내 열린 브랜치마다 기본 브랜치가 얼마나 앞섰고 그 가운데 내 예약 경로를 건드린 커밋이 몇인가(J33)."""
    diffs = {}

    def paths_of(commit):
        if commit not in diffs:
            rc, out, err = git.run_err("diff", "--name-only", "-z", commit + "^1", commit)
            if rc != 0:
                git.fail("diff", rc, err)
            diffs[commit] = [p for p in out.split("\0") if p] if rc == 0 else []
        return diffs[commit]
    out = []
    for m in mine_open:
        rc, log, err = git.run_err("log", "--first-parent", "--format=%H", "%s..%s" % (m["tip"], main))
        if rc != 0:
            git.fail("log", rc, err)
            continue
        commits = [c for c in log.split() if SHA_RE.fullmatch(c)]
        if not commits:
            continue
        touching, found = 0, set()
        for c in commits:
            hit = {p for p in paths_of(c) if not RS._shared(p, shared) and any(RS._reserves(e, p) for e in reserved)}
            if hit:
                touching += 1
                found |= hit
        out.append({"branch": m["branch"], "ahead": len(commits), "touching": touching,
                    "paths": sorted(CB.visible(p) for p in found)})
    return sorted(out, key=lambda r: r["branch"])


def suites(root, table: list, me: str, unread: Optional[list] = None) -> list:
    """끝나지 않은 다른 로드맵 가운데 스위트 잠금을 쥐고 돌고 있는 것 — 잡은 시각은 `HH:MM` 만(J36). 잠금을 읽지 못한 로드맵은 `unread` 에 이름을 쌓는다."""
    out = []
    for road in table:
        if road.name == me or not road.unfinished:
            continue
        try:
            held = suite_lock.state(suite_lock.lock_path(cs.machine_dir(state_root(str(root)), road.path)))
        except (cs.MachineError, OSError):
            if unread is not None:
                unread.append(CB.visible(road.name))
            continue
        if held["held"] and held["busy"]:
            m = HOLD_TIME_RE.fullmatch(held["taken_at"])
            out.append({"roadmap": CB.visible(road.name), "since": m.group(1) if m else NO_TIME})
    return sorted(out, key=lambda s: s["roadmap"])


def cross_view(root, roadmap_rel: str, now=None) -> dict:
    """내 로드맵과 다른 로드맵 사이의 계산 — 자료만 돌려준다. 다른 지휘자의 STATUS 는 읽지 않는다(J35)."""
    now = now or datetime.datetime.now().astimezone()
    me = CB.team_of(root, roadmap_rel).name
    table = CB.roadmaps(root)
    mine = next((r for r in table if r.name == me), None)
    if mine is None or mine.path != roadmap_rel or mine.report is None:
        raise CB.BranchError(3, "상태를 셀 수 없다 — %s" % CB.visible(mine.why if mine and mine.why else "기본 브랜치에 이 로드맵이 없다"))
    main, shared = _main_commit(root), _shared_names(root)
    git = RS.Git(str(root))
    view = {"me": me, "computed": CB.stamp(now), "reserve": [], "changed": [], "versions": [], "version_unreadable": 0,
            "moves": [], "suites": [], "unchecked_roadmaps": [], "unavailable": None, "status_text": None, "waiting": [], "quiet": [], "malformed_only": [],
            "no_branch": [], "status_unreadable": [], "waiting_malformed": 0, "incoming": None, "counts": None, "no_fetch": False,
            "foreign": 0, "own": [], "bad_names": CB.bad_state_names(root)}
    mine_open = open_branches(root, mine)
    open_by = {me: mine_open}
    for road in table:
        if road.name == me or not road.unfinished:
            continue
        if road.report is None:
            view["unchecked_roadmaps"].append((CB.visible(road.name), CB.visible(road.why or "셀 수 없음")))
            continue
        try:
            reserved = reserve_overlaps(root, mine, road, shared)
        except CB.BranchError as exc:
            view["unchecked_roadmaps"].append((CB.visible(road.name), CB.visible(str(exc))))
            continue
        opened = open_branches(root, road)
        open_by[road.name] = opened
        label = CB.visible(road.name)
        view["reserve"] += [dict(r, roadmap=label) for r in reserved]
        view["changed"] += [dict(r, roadmap=label) for r in changed_overlaps(git, main, mine_open, opened, shared)]
    view["reserve"].sort(key=lambda r: (r["roadmap"], r["path"]))
    view["changed"].sort(key=lambda r: (r["roadmap"], r["path"]))
    view["versions"], view["version_unreadable"] = version_claims(root, git, main, open_by, shared)
    mine_reserved = [e for _i, _s, reserved, _d, _u in _unfinished_blocks(root, mine, main) for e in reserved]
    view["moves"] = default_moves(git, main, mine_open, mine_reserved, shared)
    suite_unread = []
    view["suites"] = suites(root, table, me, suite_unread)
    view["unchecked_roadmaps"] += [(name, SUITE_UNREAD) for name in suite_unread]
    if git.failures:
        view["unchecked_roadmaps"].append(("git", CB.visible(git.failures[0])))
    why = CB.availability(root, roadmap_rel)
    if why:
        view["unavailable"] = CB.visible(why)   # 쓸 수 없는 레포는 git 으로 계산한 것까지만 낸다(AC14)
        return view
    _add_state_view(root, roadmap_rel, me, table, view)
    return view


def fetch_covers(refspecs: list, ref: str) -> bool:
    """`remote.origin.fetch` 의 줄들이 그 ref 를 받아 오는가(J38) — `^` 로 시작하는 줄이 맞으면 다른 줄이 받아도 거짓이다."""
    covered = False
    for spec in refspecs:
        spec = spec.strip()
        negative = spec.startswith("^")
        pattern = spec.lstrip("+^").split(":", 1)[0]
        head, star, tail = pattern.partition("*")
        hit = (ref == pattern) if not star else (len(ref) >= len(head) + len(tail) and ref.startswith(head) and ref.endswith(tail))
        if hit and negative:
            return False
        covered = covered or hit
    return covered


def _fetch_skips_state_branches(root) -> bool:
    rc, url, _e = CB.git(root, "config", "--get", "remote.origin.url")
    if rc != 0 or not url.strip():
        return False   # origin 이 없는 레포는 받아 올 곳이 없다 — 설정 탓이 아니다
    rc, out, _e = CB.git(root, "for-each-ref", "--format=%(refname)", CB.TRACKING_PREFIX + CB.STATE_BRANCH_PREFIX)
    if rc != 0 or out.strip():
        return False
    rc, cfg, _e = CB.git(root, "config", "--get-all", "remote.origin.fetch")
    specs = cfg.splitlines() if rc == 0 else []
    return not fetch_covers(specs, "refs/heads/" + CB.STATE_BRANCH_PREFIX + "x")


def _waiting_rows(status: Status) -> tuple:
    """남이 쓴 STATUS 의 「기다리는 질문」 절 — (닫힌 꼴인 줄들, 꼴 밖이라 내지 않은 줄 수). 세 칸이 모두 닫힌 꼴일 때만 낸다."""
    rows, bad = [], 0
    for line in status.sections["기다리는 질문"]:
        if line == NONE_LINE:
            continue
        cells = line.split(SEP)
        if (len(cells) == 3 and (cs.ASK_EPIC_RE.fullmatch(cells[0]) or cells[0] == cs.ASK_NO_EPIC) and cells[1] in cs.ASK_KINDS
                and CB.parse_stamp(cells[2]) is not None):
            rows.append({"epic": cells[0], "kind": cells[1], "since": cells[2]})
        else:
            bad += 1
    return rows, bad


def _add_state_view(root, roadmap_rel: str, me: str, table: list, view: dict) -> None:
    """상태 브랜치에서 읽는 칸들 — 내 STATUS · 모든 로드맵의 기다리는 질문 · 온 글과 수 · 받아 오는 설정. 쓰지도 받아 오지도 않는다."""
    team = CB.team_of(root, roadmap_rel)
    local = CB.local_tip(root, me)
    seen, split = CB.seen_tip(root, me)
    tip = seen or local
    view["status_text"] = CB.read(root, local, team.status) if local else None   # 내 현황은 내 로컬 끝에서 읽는다(J37)
    if seen or split:   # 상태 브랜치가 없으면 셀 것이 없다
        view["foreign"], view["own"] = _edits(root, roadmap_rel, team, seen)
    waiting = []
    try:
        waiting = [{"roadmap": me, "epic": r["에픽"], "kind": r["종류"], "since": r["언제부터"], "status_computed": None}
                   for r in L.load(root, roadmap_rel)[cs.ASKING]]
    except L.Fail as exc:
        view["unchecked_roadmaps"].append((me, CB.visible(str(exc))))
    for road in table:
        if road.name == me or not road.unfinished:
            continue
        label = CB.visible(road.name)
        try:
            other_tip, why = CB.seen_tip(root, road.name)
            if other_tip is None:
                view["status_unreadable" if why else "no_branch"].append(label)
                continue
            text = CB.read(root, other_tip, CB.team_of(root, road.path).status)
            status = parse_status(text) if text is not None else None
        except (CB.BranchError, StatusError):
            status = None
        if status is None:
            view["status_unreadable"].append(label)
            continue
        rows, bad = _waiting_rows(status)
        view["waiting_malformed"] += bad
        waiting += [dict(r, roadmap=label, status_computed=status.computed) for r in rows]
        if not rows:
            (view["malformed_only"] if bad else view["quiet"]).append((label, status.computed, bad) if bad else (label, status.computed))
    view["waiting"] = sorted(waiting, key=lambda w: (_asked_since({"언제부터": w["since"]}), w["roadmap"], w["epic"], w["kind"]))
    try:
        view["incoming"] = CM.incoming(root, me, tip)
        view["counts"] = CM.counts(root, me, tip, table)
    except Exception as exc:   # 글을 읽지 못해도 화면은 선다 — 읽지 못했다고 알린다
        view["unchecked_roadmaps"].append((me, "온 글을 읽지 못했다 — %s: %s" % (type(exc).__name__, CB.visible(str(exc).split("\n")[0]))))
    if view["incoming"] is not None:
        view["unchecked_roadmaps"] += [(n, LETTERS_UNREAD) for n in view["incoming"].unread if n not in view["status_unreadable"]]
    view["no_fetch"] = _fetch_skips_state_branches(root)


def _edits(root, roadmap_rel: str, team, seen: Optional[str]) -> tuple:
    """(읽을 끝까지 확인되지 않은 남의 고침 수 | None, 이 기계가 쓴 것으로 적힌 고침 목록 | None) —
    규칙 · 대기 줄 경로를 바꾼 커밋. 재지 못하면 둘 다 None. 기계 상태는 한 번만 읽는다.
    닫힘 안의 읽기 함수(`team_status`)로만 센다 — 리더 자리 모듈을 가져오지 않는다."""
    if seen is None:
        return None, None
    try:
        rows = cs.load(cs.machine_path(state_root(str(root)), roadmap_rel), roadmap_rel)[cs.TRUST]
    except Exception:   # 기계 상태를 읽지 못함 — 재지 못함(I11)
        rows = None
    git, trust, paths = RS.Git(str(root)), TS.trust_of(rows), TS.rules_paths(team) + TS.pending_paths(team)
    got = TS.split_edits(git, seen, trust, paths)   # 한 번만 재고 `씀` 으로 가른다 — 둘째 호출만 실패해 목록이 사라지는 길이 없다
    if got is None:
        return None, None
    return len(got[0]), got[1]


# ── show ─────────────────────────────────────────────────────────────────────

def _when(stamp: str, now: datetime.datetime) -> str:
    """읽는 기계의 시각으로 — 오늘이면 `HH:MM`, 아니면 `MM-DD HH:MM`."""
    at = CB.parse_stamp(stamp)
    if at is None:
        return CB.STAMP_UNKNOWN
    local = at.astimezone()
    return local.strftime("%H:%M" if local.date() == now.astimezone().date() else "%m-%d %H:%M")


def _age(stamp: str, now: datetime.datetime) -> str:
    at = CB.parse_stamp(stamp)
    minutes = int(max(0, (now - at).total_seconds()) // 60) if at is not None else 0
    return "%d분" % minutes if minutes < 60 else "%d시간" % (minutes // 60)


def _touch_lines(view: dict) -> list:
    who = lambda name: "이 로드맵" if name == view["me"] else name  # noqa: E731
    unchecked = lambda flag: " (PR 상태 미확인)" if flag else ""  # noqa: E731
    out = []
    for r in view["reserve"]:
        out.append("- 예약 겹침: %s — %s %s(%s) · 이 로드맵 %s(%s)%s" % (r["path"], r["roadmap"], r["theirs"][0], r["theirs"][1],
                                                                       r["mine"][0], r["mine"][1], unchecked(r["unchecked"])))
    for r in view["changed"]:
        out.append("- 바꾼 파일 겹침: %s — %s %s · 이 로드맵 %s%s" % (r["path"], r["roadmap"], r["theirs"], r["mine"], unchecked(r["unchecked"])))
    for v in view["versions"]:
        n = len(v["holders"])
        out.append("- 판 번호: %s — 기본 브랜치 %s · %s 을 %s 잡았다(%s) — 먼저 머지되는 쪽이 그 번호, 뒤쪽은 다시 잡는다" % (
            v["name"], v["base"], v["version"], "둘이" if n == 2 else "%d개 브랜치가" % n,
            " · ".join("%s %s" % (who(road), branch) for road, branch in v["holders"])))
    for m in view["moves"]:
        out.append("- 기본 브랜치의 움직임: %s 보다 %d 커밋 앞섬 · 그 가운데 이 로드맵의 예약 경로를 바꾼 것 %d%s" % (
            m["branch"], m["ahead"], m["touching"], "(%s)" % " · ".join(m["paths"]) if m["paths"] else ""))
    for s in view["suites"]:
        out.append("- 이 기계에서 도는 스위트: %s — %s부터" % (s["roadmap"], s["since"]))
    for name, why in view["unchecked_roadmaps"]:
        out.append("- 검사 불가: %s — %s" % (name, why))
    if view["version_unreadable"]:
        out.append("- 읽지 못한 판 파일 %d" % view["version_unreadable"])
    if view["bad_names"]:
        out.append("- 이름 꼴이 틀린 상태 브랜치 %d" % view["bad_names"])
    return out or ["- 닿는 것 없음"]


def _state_lines(view: dict, now: datetime.datetime) -> list:
    out = ["사용자를 기다리는 질문 (오래된 순)"]
    rows = []
    for w in view["waiting"]:
        age = "" if w["status_computed"] is None else "   (STATUS %s 전 계산)" % _age(w["status_computed"], now)
        rows.append("- %s · %s · %s · %s부터%s" % ("이 로드맵" if w["roadmap"] == view["me"] else w["roadmap"], w["epic"], w["kind"],
                                                _when(w["since"], now), age))
    out += rows or ["- " + NONE_LINE]
    out += ["- %s · 기다리는 질문 없음   (STATUS %s 전 계산)" % (name, _age(at, now)) for name, at in view["quiet"]]
    out += ["- %s · 읽지 못한 기다리는 질문 줄 %d   (STATUS %s 전 계산)" % (name, n, _age(at, now)) for name, at, n in view["malformed_only"]]
    out += ["- %s · %s" % (name, CB.NO_BRANCH) for name in view["no_branch"]]
    out += ["- %s · STATUS 를 읽지 못했다" % name for name in view["status_unreadable"]]
    if view["waiting_malformed"]:
        out.append("읽지 못한 기다리는 질문 줄 %d" % view["waiting_malformed"])
    inc, c = view["incoming"], view["counts"]
    if inc is not None and c is not None:
        out.append("온 글 %d · 아직 받지 않은 보낸 글 %d · 답 기다리는 글 %d" % (len(inc.letters), c.unreceived, c.awaiting))
        for l in inc.letters:
            out.append("- %s → %s · %s · %s:%s" % (CB.visible(l.sender), CB.visible(l.kind), CB.visible(l.about) or "-",
                                                  CB.branch_of(CB.visible(l.sender)), CB.visible(l.path)))
        if c.no_branch or c.to_finished:
            out.append("상대 상태 브랜치 없음 %d · 끝난 로드맵에 보낸 글 %d(세지 않았다)" % (c.no_branch, c.to_finished))
        for text, n in (("보낸 쪽이 맞지 않아 내지 않은 글", inc.wrong_from), ("꼴이 맞지 않아 내지 않은 글", inc.malformed),
                        ("로드맵 없는 상태 브랜치", inc.stray)):
            if n:
                out.append("%s %d" % (text, n))
    if view["no_fetch"]:
        out.append("%s — %s" % (NO_FETCH, FETCH_HINT))
    return out


def render_view(view: dict, now=None) -> str:
    """`show` 가 내는 글 — 계산해 둔 자료만 글로 옮긴다. 쓰지도 받아 오지도 않는다."""
    now = now or datetime.datetime.now().astimezone()
    if view["unavailable"]:
        head = view["unavailable"] + "\n"
    elif view["status_text"] is None:
        head = NO_STATUS + "\n"
    else:
        head = "\n".join(CB.visible(line) for line in view["status_text"].split("\n"))   # 내 글도 화면에 낼 때는 한 번 거른다
    line = None if view["unavailable"] else foreign_line(view["foreign"])
    own = [] if view["unavailable"] else own_lines(view["own"])
    out = [head] + ([line] if line else []) + own + ["다른 로드맵과 닿는 것 (계산 %s)" % _when(view["computed"], now)] + _touch_lines(view)
    if not view["unavailable"]:
        out += _state_lines(view, now)
    return "\n".join(out) + "\n"


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
    sh = sub.add_parser("show", help="다른 로드맵과 닿는 것 · 기다리는 질문 · 온 글을 한 화면에 낸다(읽기만 한다)")
    sh.add_argument("--roadmap", required=True)
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
    if args.cmd == "show":
        try:
            sys.stdout.write(render_view(cross_view(args.root, args.roadmap)))
        except CB.BranchError as exc:
            print("[spec-distill] " + CB.visible(str(exc)), file=sys.stderr)
            return exc.rc
        except Exception as exc:   # 예상 밖 예외도 종료 코드 3 — 화면을 내지 못한 것이다
            print("[spec-distill] 보이지 못했다 — %s: %s" % (type(exc).__name__, CB.visible(str(exc).split("\n")[0])), file=sys.stderr)
            return 3
        return 0
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
