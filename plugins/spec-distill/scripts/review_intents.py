# -*- coding: utf-8 -*-
"""review_intents.py — 통합 리뷰 묶음의 intents.md: 이 PR 과 함께 진행된 다른 에픽들의 설계문서 전문(설계 §5 · 결정 D2.2)."""
from __future__ import annotations

from control_plane import clean
from roadmap_model import DEFAULT_REF

NOT_STARTED = ("대기", "준비")
MERGED = "머지됨"
UNKNOWN = "알 수 없음"
NONE_LINE = "함께 진행된 에픽 없음"
FALLBACK = "기준을 세울 수 없어 갈라진 점(merge-base)으로 쟀다 — %s"


def _one(value) -> str:
    return clean(value).strip()


def _base(report: dict, epic: str, tip: str, git_fn):
    """(기준 커밋, 첫 줄, 경고 또는 None). 기준 커밋을 세우지 못하면 커밋은 None."""
    me = next((b for b in report.get("blocks") or [] if b.get("id") == epic), None)
    specs = list((me or {}).get("specs") or [])
    if me is None:
        why = "상태 계산에 %s 블록이 없다" % epic
    elif not specs:
        why = "%s 의 설계문서 · 산출물이 없다" % epic
    else:
        rc, out, err = git_fn("log", "--diff-filter=A", "--format=%H", "--reverse", tip, "--", *specs)
        first = out.split()[0] if rc == 0 and out.split() else None
        if first:
            return first, "기준 커밋 %s — %s 의 설계문서를 처음 더한 커밋" % (first[:8], epic), None
        why = ("설계문서를 처음 더한 커밋을 읽지 못했다(%s)" % _one(err)[-160:] if rc
               else "%s 의 설계문서를 더한 커밋이 이 브랜치에 없다" % epic)
    rc, out, err = git_fn("merge-base", DEFAULT_REF, tip)
    if rc or not out.strip():
        line = "기준 커밋을 세우지 못해 뺄 수 있는 에픽이 없다 — %s · 갈라진 점도 읽지 못했다(%s)" % (why, _one(err)[-160:])
        return None, line, line
    line = FALLBACK % why
    return out.strip(), line, line


def _excluded(b: dict, base, git_fn) -> bool:
    """이 에픽 설계 전에 끝난 바탕인가 — 하나라도 확인하지 못하면 아니다(싣는다)."""
    specs = list(b.get("specs") or [])
    states = list(b.get("branch_states") or [])
    if base is None or not specs or not states:
        return False
    if any(git_fn("cat-file", "-e", "%s:%s" % (base, p))[0] != 0 for p in specs):
        return False
    for s in states:
        if not s.get("merged") or not s.get("tip"):
            return False
        if git_fn("merge-base", "--is-ancestor", s["tip"], base)[0] != 0:
            return False
    return True


def _section(b: dict, git_fn, warns: list) -> list:
    eid = b.get("id")
    label = MERGED if b.get("stage") == MERGED else "열림"
    tree = DEFAULT_REF if label == MERGED else (b.get("tip") or DEFAULT_REF)
    unknown = None
    if b.get("stage") == UNKNOWN:
        unknown = "단계를 알 수 없다 — %s" % _one(b.get("reason") or "이유 없음")
        warns.append("%s: %s" % (eid, unknown))
    specs = list(b.get("specs") or [])
    if not specs:
        return ["### %s(%s)" % (eid, label), "", unknown or "설계문서 없음", ""]
    lines = []
    for path in specs:
        lines += ["### %s %s(%s)" % (eid, path, label), ""]
        if unknown:
            lines += [unknown, ""]
        rc, text, err = git_fn("show", "%s:%s" % (tree, path))
        if rc:
            why = "읽지 못함 — %s" % (_one(err)[-160:] or "git show rc %d" % rc)
            warns.append("%s %s %s" % (eid, path, why))
            lines += [why, ""]
        else:
            lines += [text, ""]
    return lines


def uncountable(why) -> tuple:
    """상태 계산이 실패했을 때의 (intents.md 글, 경고 줄들) — 묶음은 멈추지 않는다."""
    line = "함께 진행된 에픽을 셀 수 없다 — %s" % _one(why)
    return line + "\n", [line]


def build(report: dict, epic: str, tip: str, git_fn) -> tuple:
    """(intents.md 글, 경고 줄들). git_fn(*args) -> (rc, stdout, stderr) 는 레포에 묶인 git."""
    warns = []
    base, first, warn = _base(report, epic, tip, git_fn)
    if warn:
        warns.append(warn)
    body = []
    for b in report.get("blocks") or []:
        if b.get("id") == epic or b.get("stage") in NOT_STARTED or _excluded(b, base, git_fn):
            continue
        body += _section(b, git_fn, warns)
    if not body:
        return "%s\n%s\n" % (first, NONE_LINE), warns
    return "\n".join([first, ""] + body).rstrip("\n") + "\n", warns
