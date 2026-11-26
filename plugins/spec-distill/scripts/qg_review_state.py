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
import datetime
import functools
import re
import shutil
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import List, Optional, Tuple

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import conductor_ledger as L  # noqa: E402
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


class GitError(Exception):
    """git 이 답하지 못했다 — 사유 글을 담는다."""


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


def c_unbuilt(ctx: Ctx) -> int:
    print("[spec-distill] %s 명령은 아직 받지 않는다" % ctx.a.cmd, file=sys.stderr)
    return RC_USAGE


HANDLERS = {"open": c_open}


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
    except GitError as exc:
        print("까닭 · git 이 답하지 못했다 — %s" % exc)
        return RC_FILE


if __name__ == "__main__":
    sys.exit(main())
