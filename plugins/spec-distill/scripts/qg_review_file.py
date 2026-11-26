#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""머지 앞 qg 리뷰 하나의 상태 파일 — 꼴 · 읽기 · 쓰기.

꼴(보관 폴더의 `qg-review-state.md`):

    # qg 리뷰 상태

    - 판: 1
    - 자리: premerge
    - 자리 글자: premerge-pr12
    - 대상: pr12
    - 차례: 1
    - 범위: <시작>..<끝>
    - 단계: 열림
    - 닫힘 사유:
    - 닫힘 표시:
    - 담당자:

    ## 돌아온 결과
    ...(절 일곱 — SECTIONS)

목록 절의 항목은 `### <번호>` 아래 `- 이름: 값` 줄이고, 빈 목록은 `(없음)` 한 줄이다. 여러 줄 값은
`- 이름:` 다음 줄부터 두 칸 들여 쓰고(빈 줄은 두 칸만), 빈 값이면 들여 쓴 줄이 없다. 머리 줄은
문자열 메서드로 가르고 값은 `fullmatch` 로 본다. 꼴이 하나라도 어긋나면 `Unreadable` 이다 — 읽는
쪽은 그 파일을 지우거나 고치지 않는다.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Tuple

import nofollow_write

STATE_NAME = "qg-review-state.md"
FORMAT_VERSION = "1"
TITLE = "# qg 리뷰 상태"
EMPTY_LIST = "(없음)"
INDENT = "  "

SITES = ("premerge", "recheck", "asked")
STAGES = ("열림", "보내는 중", "보냄", "돌아옴", "닫힘")
REASON_DESIGN = "「잘못 골랐다」 — 설계 대화로"
REASON_RESPLIT = "「잘못 골랐다」 — 재분해 신호"
CLOSE_REASONS = ("막는 지적 없음", "재리뷰로 이어짐", "사용자가 남김", "리뷰 없이 감", "다시 보냄",
                 REASON_DESIGN, REASON_RESPLIT, "에픽을 멈춤")
MARK_REIMPLEMENTED = "다시 구현됨"
MARK_RESPLIT_CONTINUE = "재분해 뒤 이어 감"
# 닫힘 표시는 그 사유에만 붙는다.
MARK_FOR_REASON = {MARK_REIMPLEMENTED: REASON_DESIGN, MARK_RESPLIT_CONTINUE: REASON_RESPLIT}

NO_HANDLING = "처리 없음"
FIXED = "고친 커밋"
REBUTTED = "반박"
UNTOUCHED = "손대지 않음"
UNTOUCHED_NO_FILE = "손대지 않음 — 처리 파일 없이 끝남"
UNTOUCHED_OUT_OF_RANGE = "손대지 않음 — 적어 낸 커밋이 범위에 없음"
RETURNED_AGAIN = "다시 돌려보냄"
USER_LEFT = "사용자가 남김"
NO_REVIEW = "리뷰 없이 가기로 함"
# 처리 값. `고친 커밋` 은 뒤에 ` <해시>` 를 받고, `고친 커밋 <해시>` · `반박` · `손대지 않음` 은
# ` — <글>` 꼬리를 받는다(UNTOUCHED_NO_FILE · UNTOUCHED_OUT_OF_RANGE 가 그 꼬리의 두 꼴이다).
HANDLINGS = (NO_HANDLING, FIXED, REBUTTED, UNTOUCHED, UNTOUCHED_NO_FILE, UNTOUCHED_OUT_OF_RANGE,
             RETURNED_AGAIN, USER_LEFT, NO_REVIEW)

RETURN_MOVED = ("옮김", "아직", "처리 파일 없이 끝남", "옮겼으나 범위 밖 커밋")
ASK_KINDS = ("의도 점검", "지적 목록을 얻지 못함", "고치지 않은 막는 지적", "두 번까지", "담당자가 옮긴 질문")
FINDING_KINDS = ("막는 지적", "새로 깨진 테스트", "고른 제안", "되올린 지적")
RESULT_KINDS = ("", "얻음", "얻지 못함", "리뷰할 것 없음")
DESTINATIONS = ("", "설계 대화로", "재분해 신호")
FILTER_LISTS = ("잘못 골랐다", "그 밖")
NO_RECORD_BRANCH = "기록 브랜치 없음"

SECTIONS = ("돌아온 결과", "막는 지적", "돌려보냄", "거른 질문", "물을 것", "사용자 답", "멈출 조건")
HEAD_FIELDS = ("자리", "자리 글자", "대상", "차례", "범위", "단계", "닫힘 사유", "닫힘 표시", "담당자")

_HASH = "[0-9a-f]{7,64}"
_TIME = "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}"
TIME_RE = re.compile(_TIME)
HASH_RE = re.compile(_HASH)
RANGE_RE = re.compile("(%s)[.][.](%s)" % (_HASH, _HASH))
ORDER_RE = re.compile("[1-9][0-9]*")
TAG_RE = re.compile("[A-Za-z0-9][A-Za-z0-9._-]*")
TEAM_TARGET = "[A-Za-z0-9][A-Za-z0-9._-]*-plan[1-9][0-9]*"  # team 형식 대상 `<과제>-plan<n>`
TARGET_RE = re.compile("pr[1-9][0-9]*|" + TEAM_TARGET)
WORKER_RE = re.compile("([^\n]+) · (%s)" % _TIME)
MARK_RE = re.compile("(%s|%s) (%s)" % (MARK_REIMPLEMENTED, MARK_RESPLIT_CONTINUE, _TIME))
HANDLING_RE = re.compile(
    "%s|%s|%s|%s|%s %s(?: — [^\n]+)?|(?:%s|%s)(?: — [^\n]+)?"
    % (NO_HANDLING, RETURNED_AGAIN, USER_LEFT, NO_REVIEW, FIXED, _HASH, REBUTTED, UNTOUCHED))
NO_RECORD_RE = re.compile("%s — [^\n]+" % NO_RECORD_BRANCH)


class Unreadable(Exception):
    """상태 파일의 꼴이 어긋났다 — 사유 글을 담는다."""

    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason


@dataclass
class Result:
    kind: str = ""          # RESULT_KINDS — 돌아오기 전이면 빔
    reason: str = ""        # 얻지 못함의 사유
    seen_range: str = ""    # 결과 파일이 말한 본 범위(`<시작>..<끝>`)
    verdict_line: str = ""
    intent_line: str = ""


@dataclass
class Finding:
    kind: str               # FINDING_KINDS
    text: str               # 원문(여러 줄)
    handling: str = NO_HANDLING
    from_review: str = ""   # 낸 리뷰가 이 리뷰와 다르면 그 리뷰의 표시
    reverted: str = ""      # 범위에 없어 「처리 없음」 으로 되돌린 「고친 커밋」 의 해시 — 새 처리를 적으면 비운다


@dataclass
class ReturnLine:
    worker: str             # 구현 담당자 이름
    at: str                 # 보낸 때
    path: str               # 처리 파일의 경로
    moved: str = "아직"     # RETURN_MOVED


@dataclass
class Filtered:
    id: str
    text: str               # 결과 파일 목록 줄의 정체 뒤 글
    dest: str = ""          # 행선 — 「잘못 골랐다」 목록만, 쓰기 전이면 빔


@dataclass
class Ask:
    kind: str               # ASK_KINDS
    text: str               # 질문 글(여러 줄)
    id: str = ""            # 질문 정체(의도 점검)


@dataclass
class Answer:
    id: str
    kind: str               # ASK_KINDS
    answer: str
    at: str                 # 적은 때
    answer_text: str = ""   # 답 원문(여러 줄)
    record: str = ""        # "" | 기록 파일 경로 | `기록 브랜치 없음 — <사유>`
    question: str = ""      # 답을 적을 때 물을 것에서 옮긴 질문 글(여러 줄) — 승인 기록 다시 보이기가 싣는다


@dataclass
class Review:
    site: str
    site_tag: str
    target: str
    order: int
    range_start: str
    range_end: str
    stage: str = "열림"
    close_reason: str = ""
    close_mark: str = ""
    worker: str = ""
    result: Result = field(default_factory=Result)
    blocking: List[Finding] = field(default_factory=list)
    returns: List[ReturnLine] = field(default_factory=list)
    filtered_wrong: List[Filtered] = field(default_factory=list)
    filtered_other: List[Filtered] = field(default_factory=list)
    asks: List[Ask] = field(default_factory=list)
    answers: List[Answer] = field(default_factory=list)
    stop_rule: str = ""


# ---------------------------------------------------------------- 값 검사

def _one_line(name: str, value) -> None:
    if not isinstance(value, str) or "\n" in value:
        raise Unreadable("%s 값이 한 줄 글이 아니다" % name)


def _filled(name: str, value) -> None:
    _one_line(name, value)
    if value == "":
        raise Unreadable("%s 값이 비었다" % name)


def _block(name: str, value, required: bool = True) -> None:
    if not isinstance(value, str) or (required and value == ""):
        raise Unreadable("%s 값이 비었거나 글이 아니다" % name)


def _among(name: str, value, allowed) -> None:
    if not isinstance(value, str) or value not in allowed:
        raise Unreadable("%s 값이 틀 밖이다: %r" % (name, value))


def _shape(name: str, value, pattern) -> None:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise Unreadable("%s 값의 꼴이 틀렸다: %r" % (name, value))


def check(review: Review) -> None:
    """칸마다 꼴을 본다. 어긋나면 Unreadable."""
    _among("자리", review.site, SITES)
    _shape("자리 글자", review.site_tag, TAG_RE)
    _shape("대상", review.target, TARGET_RE)
    if isinstance(review.order, bool) or not isinstance(review.order, int) or review.order < 1:
        raise Unreadable("차례 값이 1 이상의 정수가 아니다: %r" % (review.order,))
    _shape("범위 시작", review.range_start, HASH_RE)
    _shape("범위 끝", review.range_end, HASH_RE)
    _among("단계", review.stage, STAGES)
    if review.stage == "닫힘":
        _among("닫힘 사유", review.close_reason, CLOSE_REASONS)
    elif review.close_reason != "":
        raise Unreadable("닫히지 않았는데 닫힘 사유가 있다")
    if review.close_mark != "":
        _shape("닫힘 표시", review.close_mark, MARK_RE)
        mark = MARK_RE.fullmatch(review.close_mark).group(1)
        if review.close_reason != MARK_FOR_REASON[mark]:
            raise Unreadable("닫힘 표시 「%s」 가 그 사유에 붙지 않았다" % mark)
    if review.worker != "":
        _shape("담당자", review.worker, WORKER_RE)
    r = review.result
    _among("지적 목록", r.kind, RESULT_KINDS)
    _one_line("사유", r.reason)
    if (r.kind == "얻지 못함") != (r.reason != ""):
        raise Unreadable("얻지 못함에만 사유가 붙는다")
    for name, value in (("본 범위", r.seen_range), ("판정 줄", r.verdict_line),
                        ("의도 점검 줄", r.intent_line)):
        _one_line(name, value)
    for f in review.blocking:
        _among("종류", f.kind, FINDING_KINDS)
        _shape("처리", f.handling, HANDLING_RE)
        if f.reverted != "":
            _shape("되돌린 커밋", f.reverted, HASH_RE)
        _one_line("낸 리뷰", f.from_review)
        _block("원문", f.text)
    for line in review.returns:
        _filled("담당자", line.worker)
        _shape("보낸 때", line.at, TIME_RE)
        _filled("처리 파일", line.path)
        _among("옮김", line.moved, RETURN_MOVED)
    for items, dests in ((review.filtered_wrong, DESTINATIONS), (review.filtered_other, ("",))):
        for item in items:
            _filled("정체", item.id)
            _one_line("글", item.text)
            _among("행선", item.dest, dests)
    for ask in review.asks:
        _among("종류", ask.kind, ASK_KINDS)
        _one_line("정체", ask.id)
        _block("글", ask.text)
    for a in review.answers:
        _one_line("정체", a.id)
        _among("종류", a.kind, ASK_KINDS)
        _block("질문 글", a.question, required=False)
        _filled("답", a.answer)
        _block("답 원문", a.answer_text, required=False)
        _one_line("기록", a.record)
        if a.record.startswith(NO_RECORD_BRANCH):
            _shape("기록", a.record, NO_RECORD_RE)
        _shape("적은 때", a.at, TIME_RE)
    _block("멈출 조건", review.stop_rule, required=False)


# ---------------------------------------------------------------- 쓰기

def _field(name: str, value: str) -> str:
    return "- %s:" % name if value == "" else "- %s: %s" % (name, value)


def _block_lines(name: str, value: str) -> List[str]:
    out = ["- %s:" % name]
    if value != "":
        out += [INDENT + line for line in value.split("\n")]
    return out


def _items(entries: List[List[str]]) -> List[str]:
    if not entries:
        return [EMPTY_LIST]
    out: List[str] = []
    for n, lines in enumerate(entries, 1):
        if n > 1:
            out.append("")
        out.append("### %d" % n)
        out += lines
    return out


def render(review: Review) -> str:
    """상태 파일의 글. 꼴이 어긋난 Review 는 Unreadable."""
    check(review)
    r = review.result
    head = [TITLE, "", _field("판", FORMAT_VERSION)]
    values = (review.site, review.site_tag, review.target, str(review.order),
              "%s..%s" % (review.range_start, review.range_end), review.stage,
              review.close_reason, review.close_mark, review.worker)
    head += [_field(n, v) for n, v in zip(HEAD_FIELDS, values)]
    bodies = {
        "돌아온 결과": [_field("지적 목록", r.kind), _field("사유", r.reason),
                    _field("본 범위", r.seen_range), _field("판정 줄", r.verdict_line),
                    _field("의도 점검 줄", r.intent_line)],
        "막는 지적": _items([[_field("종류", f.kind), _field("처리", f.handling),
                           _field("되돌린 커밋", f.reverted), _field("낸 리뷰", f.from_review)]
                          + _block_lines("원문", f.text)
                          for f in review.blocking]),
        "돌려보냄": _items([[_field("담당자", x.worker), _field("보낸 때", x.at),
                          _field("처리 파일", x.path), _field("옮김", x.moved)]
                         for x in review.returns]),
        "거른 질문": _items([[_field("목록", which), _field("정체", x.id), _field("글", x.text),
                           _field("행선", x.dest)]
                          for which, items in zip(FILTER_LISTS,
                                                  (review.filtered_wrong, review.filtered_other))
                          for x in items]),
        "물을 것": _items([[_field("종류", a.kind), _field("정체", a.id)] + _block_lines("글", a.text)
                        for a in review.asks]),
        "사용자 답": _items([[_field("정체", a.id), _field("종류", a.kind)] + _block_lines("질문 글", a.question)
                         + [_field("답", a.answer)] + _block_lines("답 원문", a.answer_text)
                         + [_field("기록", a.record), _field("적은 때", a.at)]
                         for a in review.answers]),
        "멈출 조건": _block_lines("글", review.stop_rule),
    }
    lines = head
    for name in SECTIONS:
        lines += ["", "## " + name, ""] + bodies[name]
    return "\n".join(lines) + "\n"


def write_review(path: Path, review: Review) -> None:
    """상태 파일을 쓴다 — 임시 파일 + 바꿔 놓기(마지막 경로 성분의 링크를 따라가지 않는다).

    쓰기 전에 그 글을 다시 읽어 같은 Review 가 나오는지 본다 — 아니면 ValueError 로 쓰지 않는다.
    """
    try:
        text = render(review)
        if parse(text) != review:
            raise Unreadable("다시 읽은 값이 쓴 값과 다르다")
    except Unreadable as exc:
        raise ValueError("상태 파일을 쓰지 않았다 — " + exc.reason)
    nofollow_write.replace_bytes(str(path), text.encode("utf-8"))


# ---------------------------------------------------------------- 읽기

class _Cursor:
    def __init__(self, lines: List[str]):
        self.lines = lines
        self.i = 0

    def peek(self) -> Optional[str]:
        return self.lines[self.i] if self.i < len(self.lines) else None

    def take(self) -> str:
        line = self.peek()
        if line is None:
            raise Unreadable("파일이 중간에 끝났다")
        self.i += 1
        return line

    def exact(self, want: str) -> None:
        line = self.take()
        if line != want:
            raise Unreadable("%d번째 줄이 %r 이어야 하는데 %r 이다" % (self.i, want, line))

    def field(self, name: str) -> str:
        line = self.take()
        bare = "- %s:" % name
        if line == bare:
            return ""
        if line.startswith(bare + " ") and len(line) > len(bare) + 1:
            return line[len(bare) + 1:]
        raise Unreadable("%d번째 줄이 「%s」 칸이 아니다: %r" % (self.i, name, line))

    def block(self, name: str) -> str:
        self.exact("- %s:" % name)
        got: List[str] = []
        while True:
            line = self.peek()
            if line is None or not line.startswith(INDENT):
                break
            got.append(line[len(INDENT):])
            self.i += 1
        return "\n".join(got)

    def items(self, read_one) -> list:
        """`(없음)` 이거나 `### 1` 부터 차례로 번호가 붙은 항목들. 절 끝(빈 줄 + `## ` 또는 파일 끝)까지."""
        if self.peek() == EMPTY_LIST:
            self.i += 1
            return []
        out = []
        n = 1
        while True:
            self.exact("### %d" % n)
            out.append(read_one(self))
            nxt = self.peek()
            if nxt is None:
                return out
            if nxt != "":
                raise Unreadable("%d번째 줄이 항목 끝이 아니다: %r" % (self.i + 1, nxt))
            after = self.lines[self.i + 1] if self.i + 1 < len(self.lines) else None
            if after is not None and after.startswith("## "):
                return out
            self.i += 1
            n += 1


def _read_finding(c: _Cursor) -> Finding:
    kind, handling, reverted = c.field("종류"), c.field("처리"), c.field("되돌린 커밋")
    origin = c.field("낸 리뷰")
    return Finding(kind=kind, handling=handling, reverted=reverted, from_review=origin, text=c.block("원문"))


def _read_return(c: _Cursor) -> ReturnLine:
    return ReturnLine(worker=c.field("담당자"), at=c.field("보낸 때"), path=c.field("처리 파일"),
                      moved=c.field("옮김"))


def _read_filtered(c: _Cursor) -> Tuple[str, Filtered]:
    which = c.field("목록")
    item = Filtered(id=c.field("정체"), text=c.field("글"), dest=c.field("행선"))
    return which, item


def _read_ask(c: _Cursor) -> Ask:
    kind, ident = c.field("종류"), c.field("정체")
    return Ask(kind=kind, id=ident, text=c.block("글"))


def _read_answer(c: _Cursor) -> Answer:
    ident, kind = c.field("정체"), c.field("종류")
    question = c.block("질문 글")
    answer = c.field("답")
    text = c.block("답 원문")
    return Answer(id=ident, kind=kind, answer=answer, answer_text=text, record=c.field("기록"),
                  at=c.field("적은 때"), question=question)


def _section(c: _Cursor, name: str) -> None:
    c.exact("")
    c.exact("## " + name)
    c.exact("")


def parse(text: str) -> Review:
    """상태 파일 글 → Review. 꼴이 어긋나면 Unreadable."""
    if not text.endswith("\n"):
        raise Unreadable("끝 줄바꿈이 없다")
    c = _Cursor(text[:-1].split("\n"))
    c.exact(TITLE)
    c.exact("")
    if c.field("판") != FORMAT_VERSION:
        raise Unreadable("모르는 판이다")
    head = {name: c.field(name) for name in HEAD_FIELDS}
    if not ORDER_RE.fullmatch(head["차례"]):
        raise Unreadable("차례 값의 꼴이 틀렸다: %r" % head["차례"])
    span = RANGE_RE.fullmatch(head["범위"])
    if not span:
        raise Unreadable("범위 값의 꼴이 틀렸다: %r" % head["범위"])
    _section(c, SECTIONS[0])
    result = Result(kind=c.field("지적 목록"), reason=c.field("사유"), seen_range=c.field("본 범위"),
                    verdict_line=c.field("판정 줄"), intent_line=c.field("의도 점검 줄"))
    _section(c, SECTIONS[1])
    blocking = c.items(_read_finding)
    _section(c, SECTIONS[2])
    returns = c.items(_read_return)
    _section(c, SECTIONS[3])
    wrong: List[Filtered] = []
    other: List[Filtered] = []
    for which, item in c.items(_read_filtered):
        if which == FILTER_LISTS[0] and not other:
            wrong.append(item)
        elif which == FILTER_LISTS[1]:
            other.append(item)
        else:
            raise Unreadable("거른 질문의 목록 값이 틀렸거나 차례가 섞였다: %r" % which)
    _section(c, SECTIONS[4])
    asks = c.items(_read_ask)
    _section(c, SECTIONS[5])
    answers = c.items(_read_answer)
    _section(c, SECTIONS[6])
    stop_rule = c.block("글")
    if c.peek() is not None:
        raise Unreadable("%d번째 줄부터 꼴 밖의 글이 있다" % (c.i + 1))
    review = Review(site=head["자리"], site_tag=head["자리 글자"], target=head["대상"],
                    order=int(head["차례"]), range_start=span.group(1), range_end=span.group(2),
                    stage=head["단계"], close_reason=head["닫힘 사유"], close_mark=head["닫힘 표시"],
                    worker=head["담당자"], result=result, blocking=blocking, returns=returns,
                    filtered_wrong=wrong, filtered_other=other, asks=asks, answers=answers,
                    stop_rule=stop_rule)
    check(review)
    return review


def read_review(path: Path) -> Review:
    """상태 파일을 읽는다. 꼴이 어긋나거나 UTF-8 이 아니면 Unreadable."""
    try:
        with open(str(path), "rb") as fh:
            data = fh.read()
    except OSError as exc:
        raise Unreadable("읽지 못했다 — " + exc.__class__.__name__)
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        raise Unreadable("UTF-8 이 아니다")
    return parse(text)


def _target_line(path: Path) -> Optional[str]:
    """읽지 못한 파일에서 머리 목록의 대상 값만 — 다른 대상의 파일인지 가를 때만 쓴다."""
    try:
        with open(str(path), "r", encoding="utf-8") as fh:
            for line in fh.read().split("\n")[:16]:
                if line.startswith("- 대상: "):
                    value = line[len("- 대상: "):]
                    return value if TARGET_RE.fullmatch(value) else None
    except (OSError, UnicodeDecodeError):
        return None
    return None


def reviews_for(report_root: Path, target: str) -> List[Review]:
    """`report_root/*/qg-review-state.md` 가운데 대상이 `target` 인 리뷰들을 차례대로.

    읽지 못한 파일은 머리 목록의 대상이 다른 대상으로 읽힐 때만 건너뛰고, 그 밖(같은 대상이거나
    가를 수 없음)은 Unreadable 이다. 같은 대상 안에서 차례가 겹치거나 1 부터 비면 Unreadable.
    """
    root = Path(report_root)
    if not root.is_dir():
        return []
    found: List[Review] = []
    for path in sorted(root.glob("*/" + STATE_NAME)):
        try:
            review = read_review(path)
        except Unreadable as exc:
            other = _target_line(path)
            if other is not None and other != target:
                continue
            raise Unreadable("%s — %s" % (path, exc.reason))
        if review.target == target:
            found.append(review)
    found.sort(key=lambda r: r.order)
    orders = [r.order for r in found]
    if orders != list(range(1, len(found) + 1)):
        raise Unreadable("대상 %s 의 차례가 겹치거나 비었다: %s" % (target, orders))
    return found
