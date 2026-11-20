#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_mail.py — 지휘자끼리 주고받는 편지의 꼴과 보내기.

편지는 보내는 로드맵의 상태 브랜치에, 받는 이 이름의 폴더 아래 `<날짜>-NN.md` 로 쓴다(받는 쪽 브랜치에는 쓰지 않는다).
남이 쓴 글을 읽는 `parse_letter` 는 `LetterError` 밖의 예외를 내지 않는다.

종료 코드: 0 · 1(없음/아님) · 2 사용법 · 3 읽기 불가 · 5 다른 세션의 표지.

가져오는 모듈은 `conductor_branch` 뿐이다.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import conductor_branch as CB  # noqa: E402

LETTER_TYPE = "conductor-letter"
ALL = "all"
KINDS = ("예고", "배운 것", "질문", "답")
QUESTION = KINDS[2]
ANSWER = KINDS[3]
BROADCAST_KINDS = KINDS[:2]
HEAD_KEYS = ("type", "from", "to", "kind", "about", "re", "sent_at")
REQUIRED = ("type", "from", "to", "kind", "sent_at")
BODY_MAX = 2000
ABOUT_MAX = 200
LONG_NOTE = "길다 — 자세한 것은 파일로 남기고 경로를 적는다"
FILE_RE = re.compile(r"([0-9]{4}-[0-9]{2}-[0-9]{2})-([0-9]{2})\.md")   # 남의 글을 읽는다 — `\d` 는 다른 문자의 숫자도 받는다
HEAD_LINE_RE = re.compile(r"([a-z_]+): (\S(?:.*\S)?)")
PATH_IN_TEXT_RE = re.compile(r"(?<![A-Za-z0-9])(?:/[^\s/]+/|~/)")   # 앞 글자가 무엇이든 `/` 둘 이상인 절대경로 꼴 · `~/`
REPLY_RE = re.compile(r"([^/]+)/(.+)")
FENCE = "---"


class LetterError(ValueError):
    pass


# ── 꼴 ───────────────────────────────────────────────────────────────────────

def render_letter(sender: str, to: str, kind: str, sent_at: str, body: str, about: str = "", re_: str = "") -> str:
    head = {"type": LETTER_TYPE, "from": sender, "to": to, "kind": kind, "about": about, "re": re_, "sent_at": sent_at}
    lines = [FENCE] + ["%s: %s" % (key, head[key]) for key in HEAD_KEYS if head[key]] + [FENCE]
    return "\n".join(lines) + "\n" + body.rstrip("\n") + "\n"


def parse_letter(text: str) -> tuple:
    """(머리 칸 사전, 본문). 꼴이 다르면 LetterError."""
    if not isinstance(text, str):
        raise LetterError("글이 아니다")
    lines = text.split("\n")
    if lines[0] != FENCE:
        raise LetterError("첫 줄이 머리 시작(---)이 아니다")
    try:
        close = lines.index(FENCE, 1)
    except ValueError:
        raise LetterError("머리가 닫히지 않았다")
    head = {}
    for line in lines[1:close]:
        m = HEAD_LINE_RE.fullmatch(line)
        if m is None or m.group(1) not in HEAD_KEYS:
            raise LetterError("머리 줄의 꼴이 다르다: %s" % CB.visible(line[:60]))
        if m.group(1) in head:
            raise LetterError("머리 칸이 두 번 나왔다: %s" % m.group(1))
        head[m.group(1)] = m.group(2)
    missing = [k for k in REQUIRED if k not in head]
    if missing:
        raise LetterError("머리 칸이 없다: %s" % ", ".join(missing))
    if head["type"] != LETTER_TYPE:
        raise LetterError("type 이 %s 이 아니다" % LETTER_TYPE)
    if head["kind"] not in KINDS:
        raise LetterError("kind 가 종류 밖이다")
    if CB.parse_stamp(head["sent_at"]) is None:
        raise LetterError("sent_at 이 시각 꼴이 아니거나 달력에 없다")
    about = head.get("about", "")
    if len(about) > ABOUT_MAX or CB.visible(about) != about:
        raise LetterError("about 이 너무 길거나 바꿀 글자가 있다")
    return head, "\n".join(lines[close + 1:])


# ── 보내기 ───────────────────────────────────────────────────────────────────

def _refuse(why: str) -> CB.BranchError:
    return CB.BranchError(2, why)


def _private_roots(root) -> set:
    """about 에 부분 문자열로도 실리면 안 되는 이 기계의 절대경로 — 레포 뿌리 · 상태 루트 · 홈 폴더(절대 · 실경로)."""
    found = set()
    for base in (Path(str(root)), CB.state_path.state_root(str(root)), Path.home()):
        for shape in (base.absolute(), base.resolve()):
            if len(str(shape)) > 1:
                found.add(str(shape))
    return found


def _check_about(root, about: str) -> None:
    if len(about) > ABOUT_MAX:
        raise _refuse("about 은 %d 자까지다" % ABOUT_MAX)
    if CB.visible(about) != about:
        raise _refuse("about 에 제어 글자 · 줄바꿈 · 방향 제어 글자를 쓰지 않는다")
    if any(w.startswith(("/", "~")) for w in about.split()) or PATH_IN_TEXT_RE.search(about):
        raise _refuse("about 에 경로(/ 나 ~ 로 시작하는 낱말 · 낱말 중간의 절대경로)를 쓰지 않는다 — 레포 안 경로는 상대로 적는다")
    for base in _private_roots(root):
        if base in about:
            raise _refuse("about 에 이 레포 · 상태 루트 · 홈 폴더의 절대경로를 쓰지 않는다")
    pattern = CB.machine_pattern()
    if pattern is not None and pattern.search(about):
        raise _refuse("about 에 이 기계의 이름을 쓰지 않는다")


def _check_reply(root, mine: str, to: str, rows: dict, re_: str) -> None:
    m = REPLY_RE.fullmatch(re_)
    if m is None or m.group(1) != to or FILE_RE.fullmatch(m.group(2)) is None:
        raise _refuse("re 는 <받는 로드맵 이름>/<파일> 꼴이고 받는 이와 같은 이름이어야 한다")
    tip, why = CB.seen_tip(root, to)
    if tip is None:
        raise _refuse("받는 쪽 상태 브랜치를 읽지 못해 답할 글을 확인하지 못했다" + (": " + why if why else ""))
    theirs = CB.team_of(root, rows[to].path)
    for folder in (mine, ALL):
        text = CB.read(root, tip, "%s/%s/%s" % (theirs.inbox, folder, m.group(2)))
        if text is None:
            continue
        try:
            head, _body = parse_letter(text)
        except LetterError:
            continue
        if head["from"] == to and head["to"] == folder:
            return
    raise _refuse("답할 글이 받는 쪽에 없다: %s" % CB.visible(re_))


def _check_values(root, mine: str, to: str, kind: str, about: str, re_: str) -> None:
    if kind not in KINDS:
        raise _refuse("종류는 %s 가운데 하나다" % " · ".join(KINDS))
    rows = {r.name: r for r in CB.roadmaps(root)}
    if to != ALL:
        if to == mine:
            raise _refuse("자기 로드맵에게는 보내지 않는다")
        if to not in rows:
            raise _refuse("받는 로드맵이 없다: %s" % CB.visible(to))
        if not rows[to].unfinished:
            raise _refuse("끝난 로드맵이다 — 받지 않는다: %s" % CB.visible(to))
    elif kind not in BROADCAST_KINDS:
        raise _refuse("모두에게는 %s 만 보낸다" % " · ".join(BROADCAST_KINDS))
    if kind == ANSWER:
        if not re_:
            raise _refuse("답은 어느 글에 답하는지(--re)를 적는다")
        _check_reply(root, mine, to, rows, re_)
    elif re_:
        raise _refuse("--re 는 답에만 쓴다")
    _check_about(root, about)


def send(root, roadmap_rel: str, session: str, to: str, kind: str, body: str, about: str = "", re_: str = "", now=None) -> tuple:
    """(Result, 알림 한 줄 또는 None). 받지 않는 값은 BranchError(2) 이고 아무것도 쓰지 않는다."""
    mine = CB.roadmap_name(roadmap_rel)
    team = CB.team_of(root, roadmap_rel)
    off = CB.availability(root, roadmap_rel)   # 꺼짐 · 규칙 거절이 값 검사보다 먼저다(AC14) — 값 검사는 기본 브랜치를 읽는다
    if off:
        return CB.Result(None, False, None, (off,)), None
    _check_values(root, mine, to, kind, about, re_)
    sent_at = CB.stamp(now)
    chosen = []

    def edit(base):
        paths = [p for _mode, p in base.names(team.inbox + "/")]
        path = "%s/%s/%s" % (team.inbox, to, CB.next_letter_name(paths, sent_at[:10]))
        chosen.append(path)   # 다시 만들 때마다 번호를 새로 센다 — 마지막으로 정한 경로가 실제로 쓴 경로다
        return {path: render_letter(mine, to, kind, sent_at, body, about, re_)}

    res = CB.write(root, roadmap_rel, session, edit, "편지 %s/%s" % (to, kind))
    if res.commit is None:
        return res, None
    if len(body.rstrip("\n")) > BODY_MAX:   # 쓴 본문 기준
        res = res._replace(notes=tuple(res.notes) + (LONG_NOTE,))
    return res, "%s 지휘자의 글 — %s:%s" % (mine, CB.branch_of(mine), chosen[-1])


# ── 명령줄 ───────────────────────────────────────────────────────────────────

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="conductor_mail.py", description="지휘자 편지")
    ap.add_argument("--root", default=".")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sd = sub.add_parser("send", help="편지를 보낸다")
    sd.add_argument("--roadmap", required=True)
    sd.add_argument("--session", required=True)
    sd.add_argument("--to", required=True)
    sd.add_argument("--kind", required=True)
    grp = sd.add_mutually_exclusive_group(required=True)
    grp.add_argument("--body")
    grp.add_argument("--body-file")
    sd.add_argument("--about", default="")
    sd.add_argument("--re", dest="re_", default="")
    args = ap.parse_args(argv)
    try:
        body = args.body
        if body is None:
            with open(args.body_file, encoding="utf-8") as fh:
                body = fh.read()
        res, notice = send(args.root, args.roadmap, args.session, args.to, args.kind, body, args.about, args.re_)
    except CB.BranchError as exc:
        print("[spec-distill] " + str(exc), file=sys.stderr)
        return exc.rc
    except Exception as exc:   # 예상 밖 예외도 종료 코드 3 — 보내지 못한 것이다
        print("[spec-distill] 편지를 보내지 못했다 — %s: %s" % (type(exc).__name__, CB.visible(str(exc).split("\n")[0])), file=sys.stderr)
        return 3
    for line in res.notes:
        print("[spec-distill] " + line)
    if notice:
        print(notice)
    return 0


if __name__ == "__main__":
    sys.exit(main())
