#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""머지 앞 qg 리뷰의 상태 파일을 만들고 옮기고 읽는 명령 일곱 — open · send · back · record · next · gate · render.

명령줄: `qg_review_state.py <명령> --roadmap <로드맵> --target <대상> [--repo <레포>] [--at <YYYY-MM-DD HH:MM>]`.
대상은 옛 형식 `pr<번호>`, team 형식 `<과제>-plan<n>`. 뺄 파일은 옛 형식 `--spec <설계문서>` · team 형식
`--job-dir <과제 폴더>` 가운데 하나다(open · record · next · gate). 경로는 레포 상대경로다.

종료 코드: 0 됨(관문 열림 포함) · 1 관문 닫힘 · 2 사용법 · 3 파일을 읽거나 쓰지 못함(상태 파일을 읽지 못함 포함) ·
4 받지 않음(`open` 거절 · 그 상태에서 할 수 없는 쓰기).

쓰기 명령은 그 대상의 마지막 리뷰에만 쓴다 — 상태 파일 경로를 인자로 받지 않는다. 보는 것은 상태 파일 · 거기 적힌
경로의 파일 · 보관 폴더 · git · 인자뿐이다.
"""
from __future__ import annotations

import argparse
import contextlib
import copy
import datetime
import functools
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import List, Optional, Tuple

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import conductor_ledger as L  # noqa: E402
import qg_review_archive as A  # noqa: E402
import qg_review_file as F  # noqa: E402

RC_OK, RC_CLOSED, RC_USAGE, RC_FILE, RC_REFUSED = 0, 1, 2, 3, 4

GIT = shutil.which("git") or "git"
COMMANDS = ("open", "send", "back", "record", "next", "gate", "render")
EXCLUDING = ("open", "record", "next", "gate")    # 뺄 파일(--spec | --job-dir)이 필수인 명령

OBTAINED = ("얻음", "리뷰할 것 없음")             # 리뷰할 것 없음은 지적 목록을 얻은 것과 같이 다룬다
FIRST_CAP = 2
ASK_TWO_MAX = "두 번까지"
ONE_MORE = "한 번 더 돌려보낸다"
ASK_INTENT = "의도 점검"
CLEAN_CLOSES = ("막는 지적 없음", "재리뷰로 이어짐", "사용자가 남김")
FIRST_AFTER = ("막는 지적 없음", "사용자가 남김", "리뷰 없이 감")
FAILED_CLOSES = ("다시 보냄", "리뷰 없이 감")
OPEN_HANDLINGS = (F.NO_HANDLING, F.RETURNED_AGAIN)
MARK_OF_REASON = {reason: mark for mark, reason in F.MARK_FOR_REASON.items()}

REPORT_KIND = "report"
RESOURCE_KIND = "qg 보관"
LEGACY_TRACES = ("pr-body", "ledger")
LEGACY_SITES = ("premerge", "recheck")
LEGACY_NOTICE = "알림 · 옛 흔적이 있다 — PR 전체를 처음부터 리뷰한다"
LEGACY_PR_BODY = "할 일 · 사용자 차례 · 옛 PR 본문의 막는 지적과 사용자 답을 한 번 보인다"
GLOB_SPECIALS = "\\*?["
OLD_TARGET_RE = re.compile("pr[1-9][0-9]*")
ASK_FAILED_ID = "q-failed"
ASK_TWO_MAX_ID = "q-cap"
ASK_UNFIXED_ID = "q-unfixed-%d"          # 뒤 수는 그 질문을 적을 때의 「돌려보냄」 줄 수 — 세기를 처음부터 다시 할 자리
WRONG_CHOICE = "잘못 골랐다"

ASK_FAILED = "지적 목록을 얻지 못함"
ASK_UNFIXED = "고치지 않은 막는 지적"
ASK_WORKER = "담당자가 옮긴 질문"
STOP_EPIC = "이 에픽을 멈춘다"
RESEND, NO_REVIEW_GO = "다시 보낸다", "리뷰 없이 머지 준비로 간다"
RETURN_AGAIN, ACCEPT_REBUTTAL = "다시 돌려보낸다", "반박을 받아들이고 남긴 지적으로 적는다"
LEAVE_REST = "남은 지적을 적고 머지 준비로 간다"
CHOICES = {ASK_FAILED: (RESEND, NO_REVIEW_GO, STOP_EPIC),
           ASK_UNFIXED: (RETURN_AGAIN, ACCEPT_REBUTTAL, STOP_EPIC),
           ASK_TWO_MAX: (ONE_MORE, LEAVE_REST, STOP_EPIC)}
RECOMMENDED_TAIL = "(권장)"
MOVED, NOT_YET, NO_FILE, OUT_OF_RANGE = F.RETURN_MOVED
EMPTY_RETURNS = (NO_FILE, OUT_OF_RANGE)
ROUTES = ("설계 대화로", "재분해 신호")
REASON_OF_ROUTE = {"설계 대화로": F.REASON_DESIGN, "재분해 신호": F.REASON_RESPLIT}
ROUTE_OF_REASON = {reason: route for route, reason in REASON_OF_ROUTE.items()}
PICK_KINDS = ("고른 제안", "되올린 지적")
# 구현 담당자가 적는 처리 — 사용자 · 스크립트만 적는 값(사용자가 남김 · 다시 돌려보냄 · 리뷰 없이 가기로 함)은 받지 않는다.
WORKER_HANDLING_HEADS = (F.NO_HANDLING, F.FIXED + " ", F.REBUTTED, F.UNTOUCHED)
OUT_OF_RANGE_NOTICE = "알림 · 적어 낸 고친 커밋 %s 가 범위에 없다"
# 입력 항목 — 종류마다 (칸 이름, 꼴) — 꼴: line(한 줄 · 빈 글 아님) · text(여러 줄 · 빈 글 아님) · any(여러 줄 · 빈 글 됨) · int
ITEM_FIELDS = {
    "answer": (("question", "line"), ("ask_kind", "line"), ("value", "line"), ("original", "any")),
    "record_path": (("question", "line"), ("path", "line")),
    "handling": (("finding", "int"), ("value", "line")),
    "return": (("worker", "line"), ("handling_file", "line")),
    "return_moved": (("value", "line"),),
    "pick": (("text", "text"), ("from_order", "int"), ("pick_kind", "line")),
    "worker_ask": (("question", "line"), ("text", "text")),
    "route": (("question", "line"), ("value", "line")),
    "stop_rule": (("text", "any"),),
    "mark": (("value", "line"),),
}


class GitError(Exception):
    """git 이 답하지 못했다 — 사유 글을 담는다."""


class Usage(Exception):
    """사용법이 틀렸다(종료 코드 2) — 사유 글은 표준 오류로 낸다."""


class Stop(Exception):
    """명령을 끝낸다 — 종료 코드와 표준 출력에 낼 줄들."""

    def __init__(self, rc: int, lines: List[str]):
        super().__init__("\n".join(lines))
        self.rc = rc
        self.lines = lines


# ---------------------------------------------------------------- git

def _git(repo, *args: str) -> str:
    p = subprocess.run([GIT, "-C", str(repo), *args], capture_output=True, encoding="utf-8", errors="replace")
    if p.returncode:
        raise GitError("git %s → %d: %s" % (args[0], p.returncode, p.stderr.strip()[:400]))
    return p.stdout


def resolve(repo, ref: str) -> str:
    """ref → 커밋 해시."""
    return _git(repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}").strip()


def merge_base(repo, base: str, head: str) -> str:
    return _git(repo, "merge-base", base, head).strip()


def glob_literal(path: str) -> str:
    return "".join("\\" + ch if ch in GLOB_SPECIALS else ch for ch in path)


def exclusions(spec: Optional[str] = None, job_dir: Optional[str] = None) -> List[str]:
    """리더가 쓰는 기록 파일 — 옛 형식은 설계문서, team 형식은 과제 폴더의 INTENT.md 와 `results/review-*`."""
    if (spec is None) == (job_dir is None):
        raise ValueError("spec 과 job_dir 가운데 하나만 준다")
    if spec is not None:
        return [glob_literal(spec)]
    job = glob_literal(job_dir.rstrip("/"))
    return [job + "/INTENT.md", job + "/results/review-*"]


def base_commits(repo, start: str, end: str, exclude: List[str]) -> List[str]:
    """`start..end` 에서 뺄 파일 밖을 바꾼 커밋 — 기준 커밋(설계 §2). merge 커밋은 `has_merge` 가 따로 본다."""
    pathspec = ["."] + [":(exclude,glob)" + p for p in exclude]
    out = _git(repo, "log", "--format=%H", "%s..%s" % (start, end), "--", *pathspec)
    return [line for line in out.splitlines() if line]


def has_merge(repo, start: str, end: str) -> bool:
    return bool(_git(repo, "rev-list", "--merges", "%s..%s" % (start, end)).strip())


class GitState:
    """git 에서 읽는 것 — 필요할 때 한 번만 읽는다. `start` 는 지적 목록을 얻은 마지막 리뷰의 끝(없으면 빈 글)."""

    def __init__(self, repo, head: str, exclude: List[str], start: str = "", base: str = ""):
        self.repo, self.head, self.exclude, self.start, self.base = repo, head, list(exclude), start, base

    @functools.cached_property
    def base_commits(self) -> List[str]:
        return base_commits(self.repo, self.start, self.head, self.exclude) if self.start else []

    @functools.cached_property
    def merge(self) -> bool:
        return has_merge(self.repo, self.start, self.head) if self.start else False

    @functools.cached_property
    def merge_base(self) -> str:
        if not self.base:
            raise GitError("기본 브랜치를 받지 않아 PR 의 바탕을 정할 수 없다")
        return merge_base(self.repo, self.base, self.head)


# ---------------------------------------------------------------- 세는 수 · 상한 · 시작

def is_obtained(review: F.Review) -> bool:
    return review.result.kind in OBTAINED


def recheck_start(reviews: List[F.Review]) -> Optional[str]:
    """지적 목록을 얻은 마지막 리뷰의 범위 끝. 없으면 None."""
    for review in reversed(reviews):
        if is_obtained(review):
            return review.range_end
    return None


def counting_from(reviews: List[F.Review]) -> List[F.Review]:
    """세는 범위 — 「다시 구현됨」 · 「재분해 뒤 이어 감」 표시가 붙은 마지막 리뷰 뒤부터."""
    for i in range(len(reviews) - 1, -1, -1):
        if reviews[i].close_mark:
            return list(reviews[i + 1:])
    return list(reviews)


def _counted(review: F.Review) -> bool:
    return review.site == "recheck" and is_obtained(review)


def counted_rechecks(reviews: List[F.Review]) -> int:
    """세는 재리뷰 수 — 세는 범위 안의 좁은 재리뷰 가운데 지적 목록을 얻은 것."""
    return sum(1 for review in counting_from(reviews) if _counted(review))


def cap(reviews: List[F.Review]) -> int:
    """상한 — 처음 2, 「두 번까지」 답이 「한 번 더 돌려보낸다」 인 리뷰마다 그 리뷰까지의 세는 수 + 1."""
    limit, seen = FIRST_CAP, 0
    for review in counting_from(reviews):
        if _counted(review):
            seen += 1
        if any(a.kind == ASK_TWO_MAX and a.answer == ONE_MORE for a in review.answers):
            limit = seen + 1
    return limit


# ---------------------------------------------------------------- 받는 상태

def inconsistency(reviews: List[F.Review]) -> str:
    """칸끼리 맞지 않는 값의 사유. 맞으면 빈 글."""
    for review in reviews[:-1]:
        if review.stage != "닫힘":
            return "차례 %d 은 마지막 리뷰가 아닌데 닫히지 않았다(단계 %s)" % (review.order, review.stage)
    for review in reviews:
        if review.stage != "닫힘":
            continue
        head = "차례 %d 이 「%s」 로 닫혔는데 " % (review.order, review.close_reason)
        if review.close_reason in CLEAN_CLOSES:
            if not is_obtained(review):
                return head + "지적 목록을 얻지 못했다"
            if any(f.handling in OPEN_HANDLINGS for f in review.blocking):
                return head + "처리 없음 · 다시 돌려보냄인 막는 지적이 있다"
            if review.asks:
                return head + "물을 것이 남았다"
            if any(line.moved == "아직" for line in review.returns):
                return head + "처리를 옮기지 않은 돌려보냄이 있다"
        if review.close_reason in FAILED_CLOSES and review.result.kind != "얻지 못함":
            return head + "지적 목록을 얻지 못한 리뷰가 아니다"
        if any(a.kind == ASK_INTENT and a.record == "" for a in review.answers):
            return head + "의도 점검 답의 기록 파일 경로가 비었다"
    return ""


def _decide(reviews: List[F.Review], gs: GitState, site: str) -> Tuple[bool, str, str]:
    """(받나, 까닭, 범위의 꼴) — 꼴은 `whole`(PR 전체) · `same`(마지막 리뷰와 같은 범위) · `recheck`(좁은 재리뷰)."""
    bad = inconsistency(reviews)
    if bad:
        return False, "상태 파일의 칸끼리 맞지 않는다 — " + bad, ""
    if not reviews:
        if site == "recheck":
            return False, "상태 파일이 없다 — 좁은 재리뷰가 아니라 첫 리뷰(--site premerge)를 연다", ""
        return True, "상태 파일이 없다", "whole"
    last = reviews[-1]
    reason = last.close_reason
    if last.stage != "닫힘":
        return False, "마지막 리뷰(차례 %d)가 닫히지 않았다 — 단계 %s" % (last.order, last.stage), ""
    if reason == "다시 보냄" and site == last.site:
        return True, "다시 보냄 — 같은 자리 · 같은 범위", "same"
    if site == "asked":
        return True, "마지막 리뷰가 닫혀 있다 — 이름으로 청한 리뷰", "whole"
    if reason == "다시 보냄":
        return False, "마지막 리뷰가 「다시 보냄」 으로 닫혔다 — 같은 자리(--site %s)로 연다" % last.site, ""
    if reason == "재리뷰로 이어짐":
        if site != "recheck":
            return False, "마지막 리뷰가 「재리뷰로 이어짐」 으로 닫혔다 — 좁은 재리뷰(--site recheck)를 연다", ""
        if not gs.base_commits:
            return False, ("기준 커밋이 없다 — 지적 목록을 얻은 마지막 리뷰의 끝 %s 뒤에 리더 기록 파일 밖을 "
                           "바꾼 커밋이 없다" % gs.start[:8]), ""
        answered = any(a.kind == ASK_TWO_MAX for a in last.answers)
        if counted_rechecks(reviews) >= cap(reviews) and not answered:
            return False, "세는 재리뷰가 상한(%d)에 닿았다 — 「두 번까지」 의 답이 없다" % cap(reviews), ""
        return True, "좁은 재리뷰", "recheck"
    if reason in MARK_OF_REASON:
        if not last.close_mark:
            return False, ("마지막 리뷰가 「%s」 로 닫혔고 「%s」 표시가 없다"
                           % (reason, MARK_OF_REASON[reason])), ""
        if site != "premerge":
            return False, "표시 뒤에는 첫 리뷰(--site premerge)를 연다", ""
        return True, "표시 뒤 첫 리뷰", "whole"
    if reason in FIRST_AFTER:
        if last.filtered_wrong:
            return False, "거른 「잘못 골랐다」 목록이 있다 — 그 행선을 먼저 적는다", ""
        if any(r.site == "premerge" for r in counting_from(reviews)):
            return False, "마지막 리뷰가 「%s」 로 닫혔고 머지 앞 첫 리뷰가 이미 있다" % reason, ""
        if site != "premerge":
            return False, "머지 앞 첫 리뷰가 없다 — 첫 리뷰(--site premerge)를 연다", ""
        return True, "머지 앞 첫 리뷰가 없다", "whole"
    return False, "마지막 리뷰가 「%s」 으로 닫혔다" % reason, ""


def open_accepts(reviews: List[F.Review], git_state: GitState, site: str) -> Tuple[bool, str]:
    """설계 §2 「「열기」 가 받는 상태」 — (받나, 까닭)."""
    ok, why, _shape = _decide(reviews, git_state, site)
    return ok, why


def open_range(reviews: List[F.Review], gs: GitState, shape: str) -> Tuple[str, str]:
    if shape == "same":
        return reviews[-1].range_start, reviews[-1].range_end
    if shape == "recheck" and not gs.merge:
        return gs.start, gs.head
    return gs.merge_base, gs.head


def next_lines(reviews: List[F.Review], gs: GitState, alive: Tuple[str, ...] = (), no_qg: bool = False) -> List[str]:
    """그 상태에서 `next` 가 내는 줄들(첫 줄 `할 일 · …`). `next` 가 없는 동안은 빈 목록이다."""
    return []


# ---------------------------------------------------------------- 보관 폴더

def site_tag(site: str, target: str) -> str:
    return "asked" if site == "asked" else "%s-%s" % (site, target)


def legacy_folders(report_root: Path, target: str) -> List[Path]:
    """상태 파일 없는 같은 대상의 머지 앞 qg 보관 폴더 — 자리 글자 뒤가 `-` 이거나 이름 끝일 때만 같다."""
    if not report_root.is_dir():
        return []
    found = []
    for path in sorted(report_root.iterdir()):
        if path.is_symlink() or not path.is_dir() or not path.name.startswith("qg-"):
            continue
        if (path / F.STATE_NAME).exists():
            continue
        for site in LEGACY_SITES:
            token = "-%s-%s" % (site, target)
            at = path.name.find(token)
            while at != -1:
                after = at + len(token)
                if after == len(path.name) or path.name[after] == "-":
                    found.append(path)
                    break
                at = path.name.find(token, at + 1)
            if found and found[-1] == path:
                break
    return found


def archive_name(report_root: Path, epic: str, tag: str, date: str) -> str:
    stem = "qg-%s-%s-%s" % (epic, tag, date)
    name, n = stem, 1
    while (report_root / name).exists() or (report_root / name).is_symlink():
        n += 1
        name = "%s-%d" % (stem, n)
    return name


# ---------------------------------------------------------------- 명령

class Ctx:
    def __init__(self, a):
        self.a = a
        try:
            self.root = L.top(a.repo)
            self.report_root = L.mpath(self.root, a.roadmap).parent / L.FILES_DIR / REPORT_KIND
        except L.Fail as exc:
            raise Stop(RC_FILE if exc.rc != RC_USAGE else RC_USAGE, ["까닭 · " + str(exc)])
        self.exclude = exclusions(spec=a.spec, job_dir=a.job_dir) if a.cmd in EXCLUDING else []

    def reviews(self) -> List[F.Review]:
        try:
            return F.reviews_for(self.report_root, self.a.target)
        except F.Unreadable as exc:
            raise Stop(RC_FILE, ["까닭 · 상태 파일을 읽지 못했다 — " + exc.reason])

    def last(self) -> Tuple[List[F.Review], Path]:
        """그 대상의 리뷰들과 마지막 리뷰의 상태 파일 경로 — 쓰기 명령은 이 파일에만 쓴다."""
        reviews = self.reviews()
        if not reviews:
            raise Stop(RC_REFUSED, ["까닭 · 대상 %s 의 상태 파일이 없다 — 먼저 open 으로 연다" % self.a.target])
        bad = inconsistency(reviews)
        if bad:
            raise Stop(RC_REFUSED, ["까닭 · 상태 파일의 칸끼리 맞지 않는다 — " + bad])
        return reviews, self.paths()[reviews[-1].order]

    def paths(self) -> dict:
        """그 대상의 차례 → 상태 파일 경로. 마지막 리뷰의 경로를 찾지 못하면 Stop."""
        found = {}
        for path in sorted(self.report_root.glob("*/" + F.STATE_NAME)):
            try:
                review = F.read_review(path)
            except F.Unreadable:
                continue
            if review.target == self.a.target:
                found[review.order] = path
        last = len(self.reviews())
        if last not in found:
            raise Stop(RC_FILE, ["까닭 · 마지막 리뷰(차례 %d)의 상태 파일을 다시 찾지 못했다" % last])
        return found


def _write(path: Path, review: F.Review) -> None:
    try:
        F.write_review(path, review)
    except (ValueError, OSError) as exc:
        raise Stop(RC_FILE, ["까닭 · 상태 파일을 쓰지 못했다 — %s" % exc])


def _ledger(fn, *args):
    """conductor_ledger 의 쓰기 — 그쪽 알림은 표준 오류로 보내고, 실패는 Stop 으로."""
    try:
        with contextlib.redirect_stdout(sys.stderr):
            return fn(*args)
    except L.Fail as exc:
        raise Stop(RC_USAGE if exc.rc == RC_USAGE else RC_FILE, ["까닭 · " + str(exc)])


def c_open(ctx: Ctx) -> int:
    a = ctx.a
    reviews = ctx.reviews()
    head = resolve(ctx.root, a.head)
    gs = GitState(ctx.root, head, ctx.exclude, recheck_start(reviews) or "", resolve(ctx.root, a.base))
    ok, why, shape = _decide(reviews, gs, a.site)
    if not ok:
        raise Stop(RC_REFUSED, ["까닭 · " + why] + next_lines(reviews, gs))
    start, end = open_range(reviews, gs, shape)
    traces = []
    if not reviews and a.site == "premerge":
        traces = list(legacy_folders(ctx.report_root, a.target)) + list(a.legacy_trace or ())
    _ledger(L.need_holder, ctx.root, a.roadmap, a.session)
    tag = site_tag(a.site, a.target)
    name = archive_name(ctx.report_root, a.epic, tag, a.at[:10])
    folder = _ledger(L.resource_dir, ctx.root, a.roadmap, REPORT_KIND, name)
    if L.cs.SEP in str(folder):
        raise Stop(RC_FILE, ["까닭 · 보관 폴더 경로에 칸 구분자가 있어 자원 줄을 적을 수 없다: %s" % folder])
    order = len(reviews) + 1
    review = F.Review(site=a.site, site_tag=tag, target=a.target, order=order, range_start=start, range_end=end)
    try:
        F.write_review(folder / F.STATE_NAME, review)
    except (ValueError, OSError) as exc:
        raise Stop(RC_FILE, ["까닭 · 상태 파일을 쓰지 못했다 — %s" % exc])
    cells = L.cs.SEP.join((RESOURCE_KIND, str(folder), a.epic, "qg 리뷰 %s %d" % (tag, order), a.at))
    _ledger(L.add_resource, ctx.root, a.roadmap, a.session, cells)
    lines = ["보관 폴더 · %s" % folder, "범위 · %s..%s" % (start, end), "자리 글자 · %s" % tag]
    if traces:
        lines.append(LEGACY_NOTICE)
    if "pr-body" in traces:
        lines.append(LEGACY_PR_BODY)
    print("\n".join(lines))
    return RC_OK


def c_send(ctx: Ctx) -> int:
    """보내기 직전 `--phase start`(열림 → 보내는 중) · 보낸 뒤 `--phase done --worker`(보내는 중 → 보냄)."""
    a = ctx.a
    reviews, path = ctx.last()
    review = reviews[-1]
    want = "열림" if a.phase == "start" else "보내는 중"
    if review.stage != want:
        raise Stop(RC_REFUSED, ["까닭 · 마지막 리뷰(차례 %d)의 단계가 %s 이다 — send --phase %s 는 %s 에서만 받는다"
                                % (review.order, review.stage, a.phase, want)])
    if a.phase == "start":
        review.stage = "보내는 중"
    else:
        review.stage, review.worker = "보냄", "%s · %s" % (a.worker, a.at)
    _write(path, review)
    lines = ["단계 · " + review.stage]
    if review.worker:
        lines.append("담당자 · " + review.worker)
    print("\n".join(lines))
    return RC_OK


def _two_max_text(limit: int, count: int) -> str:
    return ("세는 재리뷰가 상한(%d)에 닿았는데 막는 지적 %d개가 돌아왔다 — "
            "한 번 더 돌려보낼지, 남은 지적을 적고 머지 준비로 갈지" % (limit, count))


def apply_outcome(reviews: List[F.Review], out: A.Outcome) -> F.Review:
    """돌아온 결과를 마지막 리뷰에 옮기고, 닫을 수 있으면 「막는 지적 없음」 으로 닫는다."""
    review = reviews[-1]
    r = review.result
    r.kind, r.reason, r.seen_range = out.kind, out.reason, out.seen_range
    r.verdict_line, r.intent_line = out.verdict_line, out.intent_line
    if out.kind == A.NOT_OBTAINED:
        review.asks.append(F.Ask(kind="지적 목록을 얻지 못함", id=ASK_FAILED_ID, text=out.reason))
        review.stage = "돌아옴"
        return review
    review.blocking += out.blocking
    review.filtered_wrong += out.filtered_wrong
    review.filtered_other += out.filtered_other
    review.asks += out.asks
    wrong = review.filtered_wrong or any(a.kind == ASK_INTENT and a.answer == WRONG_CHOICE
                                         for a in review.answers)
    if out.blocking and not wrong and counted_rechecks(reviews) >= cap(reviews):
        review.asks.append(F.Ask(kind=ASK_TWO_MAX, id=ASK_TWO_MAX_ID,
                                 text=_two_max_text(cap(reviews), len(out.blocking))))
    pending_record = any(a.kind == ASK_INTENT and a.record == "" for a in review.answers)
    if not review.blocking and not review.asks and not pending_record:
        review.stage, review.close_reason = "닫힘", "막는 지적 없음"
    else:
        review.stage = "돌아옴"
    return review


def back_todo(reviews: List[F.Review]) -> str:
    """「돌아옴」 뒤의 할 일 한 줄 — `next` 가 짓기 전까지 쓰는 최소의 꼴(Task 7 이 `next_lines` 로 바꾼다)."""
    review = reviews[-1]
    if review.result.kind == A.NOT_OBTAINED:
        return "할 일 · 사용자 차례 · 지적 목록을 얻지 못했다 — %s" % review.result.reason
    if review.asks:
        return "할 일 · 사용자 차례 · 물을 것 %d개 — 먼저 「%s」" % (len(review.asks), review.asks[0].kind)
    if review.stage != "닫힘":
        return "할 일 · 돌려보낸다 · 막는 지적 %d개를 구현 담당자에게 돌려보낸다" % len(review.blocking)
    if review.filtered_wrong:
        return "할 일 · 답 적기 · 거른 「잘못 골랐다」 목록 %d개의 행선을 적는다" % len(review.filtered_wrong)
    if not any(r.site == "premerge" for r in counting_from(reviews)):
        return "할 일 · 열기 · 머지 앞 첫 리뷰(PR 전체)를 연다"
    return "할 일 · 머지 준비 · 막는 지적 없이 닫혔다"


def c_back(ctx: Ctx) -> int:
    """보내는 중 · 보냄 → 돌아옴(또는 바로 닫힘). 보관 폴더의 파일만 본다."""
    reviews, path = ctx.last()
    review = reviews[-1]
    if review.stage not in ("보내는 중", "보냄"):
        raise Stop(RC_REFUSED, ["까닭 · 마지막 리뷰(차례 %d)의 단계가 %s 이다 — back 은 보내는 중 · 보냄에서만 받는다"
                                % (review.order, review.stage)])
    out = A.read_archive(path.parent, review)
    apply_outcome(reviews, out)
    _write(path, review)
    gs = GitState(ctx.root, review.range_end, [], recheck_start(reviews) or "")
    lines = next_lines(reviews, gs)[:1] or [back_todo(reviews)]
    print("\n".join(lines + out.notices))
    return RC_OK


# ---------------------------------------------------------------- 답 적기 · 닫는 조건

def latest_answers(review: F.Review) -> dict:
    """질문 정체 → 그 정체의 마지막 답(앞 답은 「사용자 답」 칸에 남는다)."""
    out = {}
    for a in review.answers:
        out[a.id] = a
    return out


def _unfixed(handling: str) -> bool:
    """반박 · 손대지 않음(꼬리 포함) — 고치지 않은 막는 지적의 질문이 다루는 처리."""
    return handling.startswith(F.REBUTTED) or handling.startswith(F.UNTOUCHED)


def _open(handling: str) -> bool:
    return handling in OPEN_HANDLINGS


def _has_wrong(review: F.Review) -> bool:
    """같은 리뷰에 의도 점검 답 「잘못 골랐다」 나 거른 「잘못 골랐다」 목록이 있다."""
    return bool(review.filtered_wrong) or any(
        a.kind == ASK_INTENT and a.answer == WRONG_CHOICE for a in latest_answers(review).values())


def _pending_record(review: F.Review) -> bool:
    return any(a.kind == ASK_INTENT and a.record == "" for a in review.answers)


def _reset_index(review: F.Review, answer: F.Answer) -> int:
    """「다시 돌려보낸다」 답이 세기를 처음부터 다시 하는 자리 — 그 앞의 「돌려보냄」 줄 수."""
    head = ASK_UNFIXED_ID.split("%")[0]
    tail = answer.id[len(head):] if answer.id.startswith(head) else ""
    if F.ORDER_RE.fullmatch(tail):
        return int(tail)
    # 정체에 줄 수가 없으면(손으로 지은 질문) 답을 적은 때보다 늦게 보낸 줄만 뒤로 본다.
    return sum(1 for line in review.returns if line.at <= answer.at)


def empty_returns(review: F.Review) -> int:
    """쓸 처리 없이 끝난 「돌려보냄」 수 — 마지막 「옮김」 줄이나 「다시 돌려보낸다」 답 가운데 늦은 것의 뒤(설계 §4)."""
    start = 0
    for i, line in enumerate(review.returns):
        if line.moved == MOVED:
            start = i + 1
    for a in review.answers:
        if a.kind == ASK_UNFIXED and a.answer == RETURN_AGAIN:
            start = max(start, _reset_index(review, a))
    return sum(1 for line in review.returns[start:] if line.moved in EMPTY_RETURNS)


def _add_ask(review: F.Review, kind: str, ident: str, text: str) -> None:
    if not any(a.kind == kind for a in review.asks):
        review.asks.append(F.Ask(kind=kind, id=ident, text=text))


def _ask_unfixed(review: F.Review) -> None:
    count = sum(1 for f in review.blocking if _unfixed(f.handling))
    _add_ask(review, ASK_UNFIXED, ASK_UNFIXED_ID % len(review.returns),
             "구현 담당자가 고치지 않고 돌아온 막는 지적 %d개 — 다시 돌려보낼지, "
             "반박을 받아들이고 남긴 지적으로 적을지" % count)


def _after_empty(review: F.Review) -> None:
    """쓸 처리 없이 끝난 줄이 두 번째면 그 지적들을 「손대지 않음 — …」 으로 적고 고치지 않은 막는 지적의 질문을 적는다."""
    if not review.returns or review.returns[-1].moved not in EMPTY_RETURNS or empty_returns(review) < 2:
        return
    value = F.UNTOUCHED_NO_FILE if review.returns[-1].moved == NO_FILE else F.UNTOUCHED_OUT_OF_RANGE
    changed = [f for f in review.blocking if _open(f.handling)]
    for f in changed:
        f.handling = value
    if changed:
        _ask_unfixed(review)


def _fixed_hash(handling: str) -> str:
    return handling[len(F.FIXED) + 1:].split(" — ", 1)[0] if handling.startswith(F.FIXED + " ") else ""


def revert_unreachable(review: F.Review, gs: GitState) -> List[str]:
    """「고친 커밋 <해시>」 가운데 기준 커밋에 없는 것을 「처리 없음」 으로 되돌린다 — 알림 줄들을 낸다.

    되돌렸으면 마지막 「옮김」 줄의 값을 「옮겼으나 범위 밖 커밋」 으로 바꾼다(그 줄이 그 처리를 옮겼다).
    """
    notices, base = [], None
    for f in review.blocking:
        h = _fixed_hash(f.handling)
        if not h:
            continue
        if base is None:
            base = gs.base_commits
        if not any(c.startswith(h) for c in base):
            f.handling = F.NO_HANDLING
            notices.append(OUT_OF_RANGE_NOTICE % h)
    if notices:
        for line in reversed(review.returns):
            if line.moved == MOVED:
                line.moved = OUT_OF_RANGE
                break
    return notices


def close_if_ready(review: F.Review, reviews: List[F.Review], git_state: GitState, route: str = "") -> F.Review:
    """「돌아옴」 인 리뷰를 설계 §1 「닫는 조건」 의 사유 차례로 보고, 맞으면 닫는다.

    `route` 는 의도 점검 답 「잘못 골랐다」 의 행선(설계 대화로 · 재분해 신호) — 그 답에는 행선 칸이 없어 부르는 쪽이 넘긴다.
    """
    if review.stage != "돌아옴" or _pending_record(review):
        return review
    latest = latest_answers(review).values()
    answers = {(a.kind, a.answer) for a in latest}

    def close(reason: str) -> F.Review:
        review.stage, review.close_reason, review.close_mark = "닫힘", reason, ""
        return review

    if any(a.answer == STOP_EPIC for a in latest):
        return close("에픽을 멈춤")
    routes = []
    if any(a.kind == ASK_INTENT and a.answer == WRONG_CHOICE for a in latest):
        routes.append(route)
    routes += [x.dest for x in review.filtered_wrong]
    if routes and all(routes) and not review.asks:
        return close(F.REASON_RESPLIT if "재분해 신호" in routes else F.REASON_DESIGN)
    if (ASK_FAILED, NO_REVIEW_GO) in answers:
        return close("리뷰 없이 감")
    if (ASK_FAILED, RESEND) in answers:
        return close("다시 보냄")
    if review.asks or not is_obtained(review):
        return review
    if review.blocking:
        if any(_open(f.handling) for f in review.blocking) or any(x.moved == NOT_YET for x in review.returns):
            return review
        if git_state.base_commits:
            return close("재리뷰로 이어짐")
        if any(f.handling == F.USER_LEFT for f in review.blocking):
            return close("사용자가 남김")
        return review
    return close("막는 지적 없음")


def _reopen(review: F.Review) -> None:
    review.stage, review.close_reason, review.close_mark = "돌아옴", "", ""


def _refuse(why: str):
    raise Stop(RC_REFUSED, ["까닭 · " + why])


def _check_value(kind: str, name: str, value, shape: str) -> None:
    where = "%s 항목의 %s" % (kind, name)
    if shape == "int":
        if isinstance(value, bool) or not isinstance(value, int) or value < 1:
            raise Usage("%s 는 1 이상의 정수다: %r" % (where, value))
        return
    if not isinstance(value, str):
        raise Usage("%s 는 글이다: %r" % (where, value))
    if shape in ("line", "text") and value.strip() == "":
        raise Usage("%s 가 비었다" % where)
    if shape == "line" and ("\n" in value or "\r" in value):
        raise Usage("%s 는 한 줄이다 — 여러 줄을 접어 적지 않는다: %r" % (where, value))


def load_items(path: Optional[str]) -> List[dict]:
    """`record --input` 의 JSON — `{"items": [...]}`. 꼴이 틀리면 Usage, 읽지 못하면 Stop(rc 3)."""
    if path is None:
        return []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Stop(RC_FILE, ["까닭 · 입력 파일을 읽지 못했다 — %s" % exc.__class__.__name__])
    try:
        data = json.loads(text)
    except ValueError as exc:
        raise Usage("입력 파일이 JSON 이 아니다 — %s" % exc)
    if not isinstance(data, dict) or set(data) != {"items"} or not isinstance(data["items"], list):
        raise Usage('입력은 {"items": [...]} 하나다')
    for item in data["items"]:
        if not isinstance(item, dict) or not isinstance(item.get("kind"), str) or item["kind"] not in ITEM_FIELDS:
            raise Usage("항목의 kind 가 틀 밖이다: %r" % (item,))
        fields = ITEM_FIELDS[item["kind"]]
        if set(item) != {"kind"} | {name for name, _shape in fields}:
            raise Usage("%s 항목의 칸은 %s 이다: %s" % (item["kind"], ", ".join(n for n, _s in fields),
                                                    ", ".join(sorted(item))))
        for name, shape in fields:
            _check_value(item["kind"], name, item[name], shape)
        _check_item(item)
    return data["items"]


def _check_item(item: dict) -> None:
    """상태와 무관한 항목 값 검사."""
    kind = item["kind"]
    if kind == "answer":
        if item["ask_kind"] not in F.ASK_KINDS:
            raise Usage("ask_kind 가 틀 밖이다: %r" % item["ask_kind"])
        value = item["value"].rstrip()
        if value.endswith(RECOMMENDED_TAIL):
            raise Usage("답 값에서 「%s」 꼬리를 떼고 적는다: %r" % (RECOMMENDED_TAIL, item["value"]))
        allowed = CHOICES.get(item["ask_kind"])
        if allowed and item["value"] not in allowed:
            raise Usage("「%s」 질문의 답은 %s 가운데 하나다: %r" % (item["ask_kind"], " · ".join(allowed), item["value"]))
    elif kind == "record_path":
        path = item["path"]
        if path.startswith(F.NO_RECORD_BRANCH):
            if not F.NO_RECORD_RE.fullmatch(path):
                raise Usage("「%s — <사유>」 꼴이다: %r" % (F.NO_RECORD_BRANCH, path))
        else:
            rel = PurePosixPath(path)
            if rel.is_absolute() or ".." in rel.parts or path.startswith("-"):
                raise Usage("기록 파일 경로는 레포 상대경로다: %r" % path)
    elif kind == "handling":
        value = item["value"]
        if not F.HANDLING_RE.fullmatch(value) or not value.startswith(WORKER_HANDLING_HEADS):
            raise Usage("처리 값은 처리 없음 · 고친 커밋 <해시> · 반박 · 손대지 않음 가운데 하나다(꼬리 「 — <글>」): %r"
                        % value)
    elif kind == "return":
        worker, path = item["worker"], item["handling_file"]
        if " · " in worker or worker != worker.strip():
            raise Usage("담당자 이름에 ` · ` · 앞뒤 빈칸을 쓰지 않는다: %r" % worker)
        if not Path(path).is_absolute():
            raise Usage("처리 파일은 절대경로다: %r" % path)
    elif kind == "return_moved" and item["value"] not in (MOVED, NO_FILE):
        raise Usage("return_moved 값은 %s · %s 가운데 하나다: %r" % (MOVED, NO_FILE, item["value"]))
    elif kind == "pick" and item["pick_kind"] not in PICK_KINDS:
        raise Usage("pick_kind 는 %s 가운데 하나다: %r" % (" · ".join(PICK_KINDS), item["pick_kind"]))
    elif kind == "route" and item["value"] not in ROUTES:
        raise Usage("행선은 %s 가운데 하나다: %r" % (" · ".join(ROUTES), item["value"]))
    elif kind == "mark" and item["value"] not in F.MARK_FOR_REASON:
        raise Usage("표시는 %s 가운데 하나다: %r" % (" · ".join(F.MARK_FOR_REASON), item["value"]))


class Recorder:
    """「답 적기」 한 번 — 마지막 리뷰(메모리 안)에 항목을 차례로 적는다. 거절이면 아무것도 쓰지 않는다."""

    def __init__(self, reviews: List[F.Review], gs: GitState, at: str):
        self.reviews, self.review, self.gs, self.at = reviews, reviews[-1], gs, at
        self.route = ROUTE_OF_REASON.get(self.review.close_reason, "")
        self.notices: List[str] = []
        self.prior_changed: List[F.Review] = []
        self.evaluate = False
        self.intent_routed = False

    # 닫힌 리뷰를 되돌린다 — 표시가 붙은 리뷰는 그 결정 뒤의 일이라 되돌리지 않는다.
    def reopen(self, what: str) -> None:
        rv = self.review
        if rv.stage == "닫힘":
            if rv.close_mark:
                _refuse("마지막 리뷰(차례 %d)에 「%s」 표시가 있다 — %s 를 적지 않는다"
                        % (rv.order, rv.close_mark.rsplit(" ", 2)[0], what))
            _reopen(rv)
        self.evaluate = True

    def need_stage(self, what: str, *stages: str) -> None:
        if self.review.stage not in stages:
            _refuse("마지막 리뷰(차례 %d)의 단계가 %s 이다 — %s 는 %s 에서만 받는다"
                    % (self.review.order, self.review.stage, what, " · ".join(stages)))

    def answer(self, item: dict) -> None:
        rv, ident, value = self.review, item["question"], item["value"]
        asked = [a for a in rv.asks if a.id == ident]
        prior = latest_answers(rv).get(ident)
        kind = asked[0].kind if asked else (prior.kind if prior else None)
        if kind is None:
            _refuse("마지막 리뷰(차례 %d)에 질문 %s 가 없다" % (rv.order, ident))
        if kind != item["ask_kind"]:
            _refuse("질문 %s 의 종류는 「%s」 다 — 「%s」 로 적지 않는다" % (ident, kind, item["ask_kind"]))
        if not asked:
            if prior.answer == value and prior.answer_text == item["original"]:
                return                                   # 같은 답 — 다시 적지 않는다
            if rv.stage != "닫힘":
                _refuse("질문 %s 는 이미 답했다 — 다른 답은 닫힌 리뷰에서 다시 띄운 질문에만 적는다" % ident)
        if kind == ASK_WORKER:
            self.need_stage("담당자가 옮긴 질문의 답", "보냄", "돌아옴")
        else:
            self.need_stage("답", "돌아옴", "닫힘")
        if rv.stage != "보냄":
            self.reopen("다른 답")
        rv.asks = [a for a in rv.asks if a.id != ident]
        rv.answers.append(F.Answer(id=ident, kind=kind, answer=value, at=self.at, answer_text=item["original"]))
        if kind == ASK_INTENT and value == WRONG_CHOICE:
            rv.asks = [a for a in rv.asks if a.kind != ASK_TWO_MAX]   # 거둔다 — 답으로 적지 않는다
        elif kind == ASK_UNFIXED and value in (RETURN_AGAIN, ACCEPT_REBUTTAL):
            to = F.RETURNED_AGAIN if value == RETURN_AGAIN else F.USER_LEFT
            for f in rv.blocking:
                if _unfixed(f.handling):
                    f.handling = to
        elif kind == ASK_TWO_MAX and value == LEAVE_REST:
            for f in rv.blocking:
                if _open(f.handling) or _unfixed(f.handling):
                    f.handling = F.USER_LEFT
        elif kind == ASK_FAILED and value == NO_REVIEW_GO:
            self.no_review_prior()

    def no_review_prior(self) -> None:
        """앞 리뷰에서 처리가 「고친 커밋」 인 막는 지적 가운데 아직 그 고침을 본 리뷰가 없는 것을 「리뷰 없이 가기로 함」 으로."""
        before = self.reviews[:-1]
        for i, prior in enumerate(before):
            if any(is_obtained(x) for x in before[i + 1:]):
                continue
            changed = False
            for f in prior.blocking:
                if f.handling.startswith(F.FIXED + " "):
                    f.handling, changed = F.NO_REVIEW, True
            if changed:
                self.prior_changed.append(prior)

    def record_path(self, item: dict) -> None:
        rv, ident = self.review, item["question"]
        prior = latest_answers(rv).get(ident)
        if prior is None or prior.kind != ASK_INTENT:
            _refuse("마지막 리뷰(차례 %d)에 의도 점검 답 %s 가 없다" % (rv.order, ident))
        if prior.record == item["path"]:
            return
        if prior.record:
            _refuse("의도 점검 답 %s 의 기록 파일 경로가 이미 적혀 있다: %s" % (ident, prior.record))
        self.need_stage("기록 파일 경로", "돌아옴")
        prior.record = item["path"]
        self.evaluate = True

    def handle_return(self, item: dict) -> None:
        rv = self.review
        self.need_stage("돌려보냄", "돌아옴")
        if any(x.moved == NOT_YET for x in rv.returns):
            _refuse("처리를 아직 옮기지 않은 「돌려보냄」 이 있다 — 다시 돌려보내지 않는다")
        if rv.asks:
            _refuse("물을 것이 남았다(먼저 「%s」) — 답을 받은 뒤 돌려보낸다" % rv.asks[0].kind)
        if _has_wrong(rv):
            _refuse("「잘못 골랐다」 가 있다 — 구현 길로 돌려보내지 않고 설계 대화가 먼저다")
        if not any(_open(f.handling) for f in rv.blocking):
            _refuse("돌려보낼 막는 지적(처리 없음 · 다시 돌려보냄)이 없다")
        rv.returns.append(F.ReturnLine(worker=item["worker"], at=self.at, path=item["handling_file"]))
        self.evaluate = True

    def moved(self, item: dict, handlings: List[dict]) -> None:
        rv = self.review
        self.need_stage("처리 옮기기", "돌아옴")
        if not rv.returns or rv.returns[-1].moved != NOT_YET:
            _refuse("처리를 옮길 「아직」 인 「돌려보냄」 줄이 없다")
        if (item["value"] == MOVED) != bool(handlings):
            raise Usage("return_moved 「%s」 는 handling 항목을 함께 싣고, 「%s」 는 싣지 않는다" % (MOVED, NO_FILE))
        for h in handlings:
            n = h["finding"]
            if n > len(rv.blocking):
                _refuse("막는 지적 %d 이 없다(마지막 리뷰의 막는 지적 %d개)" % (n, len(rv.blocking)))
            if not _open(rv.blocking[n - 1].handling):
                _refuse("막는 지적 %d 의 처리가 「%s」 다 — 돌려보낸 지적(처리 없음 · 다시 돌려보냄)에만 처리를 옮긴다"
                        % (n, rv.blocking[n - 1].handling))
            rv.blocking[n - 1].handling = h["value"]
        rv.returns[-1].moved = item["value"]
        self.notices += revert_unreachable(rv, self.gs)
        _after_empty(rv)
        if any(_unfixed(f.handling) for f in rv.blocking):
            _ask_unfixed(rv)
        self.evaluate = True

    def pick(self, item: dict) -> None:
        rv = self.review
        if rv.stage not in ("돌아옴", "닫힘"):
            _refuse("마지막 리뷰(차례 %d)가 도는 중이다(단계 %s) — 돌아온 뒤 적는다" % (rv.order, rv.stage))
        if not is_obtained(rv) or (rv.stage == "닫힘" and rv.close_reason not in CLEAN_CLOSES):
            _refuse("마지막 리뷰(차례 %d)가 「%s」 다 — 고른 제안 · 되올린 지적은 지적 목록을 얻은 리뷰에 적는다"
                    % (rv.order, rv.close_reason or rv.result.kind or rv.stage))
        if item["from_order"] > rv.order:
            _refuse("차례 %d 의 리뷰가 없다" % item["from_order"])
        self.reopen("고른 제안")
        origin = "" if item["from_order"] == rv.order else str(item["from_order"])
        rv.blocking.append(F.Finding(kind=item["pick_kind"], text=item["text"], from_review=origin))
        if not _has_wrong(rv) and counted_rechecks(self.reviews) >= cap(self.reviews):
            count = sum(1 for f in rv.blocking if f.kind in PICK_KINDS and _open(f.handling))
            _add_ask(rv, ASK_TWO_MAX, ASK_TWO_MAX_ID,
                     "세는 재리뷰가 상한(%d)에 닿았는데 고른 제안 · 되올린 지적 %d개를 돌려보내야 한다 — "
                     "한 번 더 돌려보낼지, 남은 지적을 적고 머지 준비로 갈지" % (cap(self.reviews), count))

    def worker_ask(self, item: dict) -> None:
        rv = self.review
        self.need_stage("담당자가 옮긴 질문", "보냄")
        if any(a.id == item["question"] for a in rv.asks):
            _refuse("질문 %s 가 이미 물을 것에 있다" % item["question"])
        rv.asks.append(F.Ask(kind=ASK_WORKER, id=item["question"], text=item["text"]))

    def set_route(self, item: dict) -> None:
        rv, ident = self.review, item["question"]
        listed = [x for x in rv.filtered_wrong if x.id == ident]
        prior = latest_answers(rv).get(ident)
        intent = prior is not None and prior.kind == ASK_INTENT and prior.answer == WRONG_CHOICE
        if not listed and not intent:
            _refuse("질문 %s 는 의도 점검 답 「잘못 골랐다」 도, 거른 「잘못 골랐다」 목록의 질문도 아니다" % ident)
        self.need_stage("행선", "돌아옴", "닫힘")
        if intent and prior.record == "":
            _refuse("의도 점검 답 %s 의 기록 파일 경로를 먼저 적는다" % ident)
        if rv.asks:
            _refuse("물을 것이 남았다(먼저 「%s」) — 답을 받은 뒤 행선을 적는다" % rv.asks[0].kind)
        self.reopen("행선")
        for x in listed:
            x.dest = item["value"]
        if intent:
            self.route, self.intent_routed = item["value"], True

    def mark(self, item: dict) -> None:
        rv, value = self.review, item["value"]
        want = F.MARK_FOR_REASON[value]
        if rv.stage != "닫힘" or rv.close_reason != want or rv.close_mark:
            _refuse("「%s」 표시는 「%s」 로 닫히고 표시가 없는 마지막 리뷰에만 붙는다 — 지금 %s%s"
                    % (value, want, rv.stage, (" · " + rv.close_reason) if rv.close_reason else "")
                    + (" · 표시 있음" if rv.close_mark else ""))
        rv.close_mark = "%s %s" % (value, self.at)

    def revert(self) -> None:
        """기준 커밋에 없는 고친 커밋을 되돌리고, 그것으로 줄이 쓸 처리 없이 끝난 두 번째가 됐으면 그 출구로."""
        notices = revert_unreachable(self.review, self.gs)
        if notices:
            self.notices += notices
            _after_empty(self.review)

    def bare(self) -> None:
        """적을 값 없이 — git 과 닫는 조건에 대어 다시 가린다. git 이 사유를 바꾸지 못하는 닫힘(에픽을 멈춤 ·
        「잘못 골랐다」 · 다시 보냄 · 리뷰 없이 감)은 그대로 둔다."""
        rv = self.review
        self.need_stage("다시 가리기", "돌아옴", "닫힘")
        if rv.stage == "닫힘" and rv.close_reason not in CLEAN_CLOSES:
            return
        if rv.stage == "닫힘":
            _reopen(rv)
        self.revert()
        close_if_ready(rv, self.reviews, self.gs, self.route)

    def run(self, items: List[dict]) -> None:
        if not items:
            self.bare()
            return
        handlings = [x for x in items if x["kind"] == "handling"]
        moves = [x for x in items if x["kind"] == "return_moved"]
        if handlings and not moves:
            raise Usage("handling 항목은 return_moved 항목과 함께 싣는다")
        if len(moves) > 1:
            raise Usage("return_moved 항목은 하나만 싣는다")
        for item in items:
            kind = item["kind"]
            if kind == "handling":
                continue
            if kind == "return_moved":
                self.moved(item, handlings)
            elif kind == "return":
                self.handle_return(item)
            elif kind == "stop_rule":
                self.review.stop_rule = item["text"]
            else:
                getattr(self, kind if kind != "route" else "set_route")(item)
        if self.evaluate and self.review.stage == "돌아옴":
            self.revert()
            close_if_ready(self.review, self.reviews, self.gs, self.route)
        if self.intent_routed and self.review.close_reason not in MARK_OF_REASON:
            # 의도 점검 답에는 행선 칸이 없어, 닫지 못한 행선은 남지 않는다 — 조용히 잃지 않고 거절한다.
            _refuse("행선을 적어도 닫히지 않는다 — 거른 「잘못 골랐다」 목록의 행선도 같은 입력에 적는다")


def record_todo(reviews: List[F.Review]) -> str:
    """「답 적기」 뒤의 할 일 한 줄 — `next` 가 짓기 전까지 쓰는 최소의 꼴(Task 7 이 `next_lines` 로 바꾼다)."""
    review = reviews[-1]
    if review.stage in ("열림", "보내는 중", "보냄"):
        if any(a.kind == ASK_WORKER for a in review.asks):
            return "할 일 · 사용자 차례 · 담당자가 옮긴 질문 %s 의 답을 적는다" % review.asks[0].id
        return "할 일 · 기다린다 · 리뷰가 도는 중이다(단계 %s)" % review.stage
    if review.stage == "닫힘":
        reason = review.close_reason
        if reason == "에픽을 멈춤":
            return "할 일 · 사용자 차례 · 에픽을 멈췄다"
        if reason in MARK_OF_REASON and not review.close_mark:
            if reason == F.REASON_DESIGN:
                return "할 일 · 기다린다 · 설계 대화 뒤 다시 구현한 것이 돌아오면 「다시 구현됨」 표시를 적는다"
            return "할 일 · 사용자 차례 · 재분해 신호 — 이어 가면 「재분해 뒤 이어 감」 표시를 적는다"
        if reason in ("다시 보냄", "재리뷰로 이어짐") or reason in MARK_OF_REASON:
            return "할 일 · 열기 · %s" % reason
        return back_todo(reviews)
    if _pending_record(review):
        return "할 일 · 기록 파일 쓰기 · 의도 점검 답의 기록 파일을 쓰고 그 경로를 적는다"
    if any(x.moved == NOT_YET for x in review.returns):
        return "할 일 · 기다린다 · 돌려보낸 구현 담당자의 처리를 기다린다"
    if not review.asks and _has_wrong(review):
        return "할 일 · 답 적기 · 「잘못 골랐다」 의 행선을 적는다"
    return back_todo(reviews)


def c_record(ctx: Ctx) -> int:
    """「답 적기」 — 마지막 리뷰에 적고, 닫을 수 있으면 닫는다. 입력 없이 부르면 다시 가린다."""
    items = load_items(ctx.a.input)
    reviews, path = ctx.last()
    head = resolve(ctx.root, "HEAD")
    gs = GitState(ctx.root, head, ctx.exclude, recheck_start(reviews) or "")
    before = copy.deepcopy(reviews)
    rec = Recorder(reviews, gs, ctx.a.at)
    rec.run(items)
    bad = inconsistency(reviews)
    if bad:
        raise Stop(RC_FILE, ["까닭 · 쓰지 않았다 — 적은 뒤 상태 파일의 칸끼리 맞지 않는다: " + bad])
    paths = ctx.paths() if rec.prior_changed else {}
    for prior in rec.prior_changed:                      # 앞 리뷰 먼저 — 끊겨도 같은 입력으로 다시 부르면 이어진다
        _write(paths[prior.order], prior)
    if reviews[-1] != before[-1]:
        _write(path, reviews[-1])
    lines = next_lines(reviews, gs)[:1] or [record_todo(reviews)]
    print("\n".join(lines + rec.notices))
    return RC_OK


def c_unbuilt(ctx: Ctx) -> int:
    print("[spec-distill] %s 명령은 아직 받지 않는다" % ctx.a.cmd, file=sys.stderr)
    return RC_USAGE


HANDLERS = {"open": c_open, "send": c_send, "back": c_back, "record": c_record}


# ---------------------------------------------------------------- 명령줄

def _parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--roadmap", required=True)
    common.add_argument("--target", required=True)
    common.add_argument("--repo", default=".")
    common.add_argument("--at")
    excl = argparse.ArgumentParser(add_help=False)
    group = excl.add_mutually_exclusive_group(required=True)
    group.add_argument("--spec")
    group.add_argument("--job-dir", dest="job_dir")
    ap = argparse.ArgumentParser(prog="qg_review_state.py", description="머지 앞 qg 리뷰 상태")
    sub = ap.add_subparsers(dest="cmd", required=True)
    parents = {name: [common, excl] if name in EXCLUDING else [common] for name in COMMANDS}
    p = sub.add_parser("open", parents=parents["open"])
    p.add_argument("--site", required=True, choices=F.SITES)
    p.add_argument("--base", required=True)
    p.add_argument("--head", required=True)
    p.add_argument("--epic", required=True)
    p.add_argument("--session", required=True)
    p.add_argument("--legacy-trace", dest="legacy_trace", action="append", choices=LEGACY_TRACES)
    p = sub.add_parser("send", parents=parents["send"])
    p.add_argument("--phase", required=True, choices=("start", "done"))
    p.add_argument("--worker")
    sub.add_parser("back", parents=parents["back"])
    p = sub.add_parser("record", parents=parents["record"])
    p.add_argument("--input")
    p = sub.add_parser("next", parents=parents["next"])
    p.add_argument("--alive", action="append", default=[])
    p.add_argument("--no-qg", dest="no_qg", action="store_true")
    p = sub.add_parser("gate", parents=parents["gate"])
    p.add_argument("--no-qg", dest="no_qg", action="store_true")
    p = sub.add_parser("render", parents=parents["render"])
    p.add_argument("--kind", required=True, choices=("pr-body", "approval", "return-list", "team-fence"))
    p.add_argument("--no-qg", dest="no_qg", action="store_true")
    p.add_argument("--handling-file", dest="handling_file")
    return ap


def _usage(a) -> Optional[str]:
    """argparse 밖의 사용법 검사 — 틀리면 사유 글."""
    if not F.TARGET_RE.fullmatch(a.target):
        return "대상은 pr<번호> 또는 <과제>-plan<n> 이다: %r" % a.target
    if a.at is None:
        a.at = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    elif not F.TIME_RE.fullmatch(a.at):
        return "--at 은 YYYY-MM-DD HH:MM 이다: %r" % a.at
    if a.cmd in EXCLUDING:
        given = a.spec if a.spec is not None else a.job_dir
        rel = PurePosixPath(given)
        if not given or rel.is_absolute() or ".." in rel.parts or given.startswith("-"):
            return "뺄 파일은 레포 상대경로다: %r" % given
        team = not OLD_TARGET_RE.fullmatch(a.target)
        if team != (a.job_dir is not None):
            return "옛 형식 대상(pr<번호>)은 --spec, team 형식 대상(<과제>-plan<n>)은 --job-dir 을 받는다"
    if a.cmd == "send":
        if a.phase == "done" and not a.worker:
            return "send --phase done 은 --worker <담당자 이름> 을 받는다"
        if a.phase == "start" and a.worker is not None:
            return "send --phase start 는 --worker 를 받지 않는다"
        if a.worker is not None and (" · " in a.worker or a.worker != a.worker.strip()
                                     or any(ch in a.worker for ch in "\n\r")):
            return "담당자 이름에 ` · ` · 줄바꿈 · 앞뒤 빈칸을 쓰지 않는다: %r" % a.worker
    if a.cmd == "open":
        if not a.epic or not set(a.epic) <= L.NAME_CHARS or a.epic in (".", ".."):
            return "에픽은 영숫자 · . · _ · - 만 쓴다: %r" % a.epic
        if a.base.startswith("-") or a.head.startswith("-"):
            return "--base · --head 는 ref 다"
    return None


def main(argv=None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    a = _parser().parse_args(argv)
    why = _usage(a)
    if why:
        print("[spec-distill] " + why, file=sys.stderr)
        return RC_USAGE
    try:
        ctx = Ctx(a)
        return HANDLERS.get(a.cmd, c_unbuilt)(ctx)
    except Stop as stop:
        print("\n".join(stop.lines))
        return stop.rc
    except Usage as exc:
        print("[spec-distill] %s" % exc, file=sys.stderr)
        return RC_USAGE
    except GitError as exc:
        print("까닭 · git 이 답하지 못했다 — %s" % exc)
        return RC_FILE


if __name__ == "__main__":
    sys.exit(main())
