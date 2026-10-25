# -*- coding: utf-8 -*-
"""review_intents.py — 통합 리뷰 묶음의 intents.md: 이 PR 과 함께 진행된 다른 에픽들의 설계문서 전문(설계 §5 · 결정 D2.2)."""
from __future__ import annotations

from control_plane import clean
from roadmap_model import DEFAULT_REF
from roadmap_status import first_added, parse_fp_events

NOT_STARTED = ("대기", "준비")
MERGED = "머지됨"
UNKNOWN = "알 수 없음"
NONE_LINE = "함께 진행된 에픽 없음"
FALLBACK = "기준을 세울 수 없어 갈라진 점(merge-base)으로 쟀다 — %s"
UNVERIFIED = "설계 전 바탕인지 확인하지 못함"
COUNT_LINE = ("머지됨 에픽 %d개는 이 에픽 설계 전에 끝난 바탕인지 확인하지 못해 실었다 — "
              "머릿줄에 「" + UNVERIFIED + "」")
OUT, IN = "뺀다", "싣는다"


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


def _first_parent_line(git_fn):
    """기본 브랜치 첫째 부모 줄의 커밋들(새것 먼저). 읽지 못하면 None."""
    rc, out, _e = git_fn("rev-list", "--first-parent", DEFAULT_REF)
    return out.split() if rc == 0 and out.strip() else None


def _before(commit: str, base: str, git_fn):
    """commit 이 base 이거나 그 조상이면 True, 아니면 False, 읽지 못하면 None."""
    rc = git_fn("merge-base", "--is-ancestor", commit, base)[0]
    return True if rc == 0 else False if rc == 1 else None


def _memo(memo: dict, key: str, make):
    if key not in memo:
        memo[key] = make()
    return memo[key]


def _entry(tip: str, line: list, git_fn):
    """끝이 기본 브랜치에 처음 든 커밋 — 끝이 첫째 부모 줄에 있으면(빨리 감기) 끝 자체, 아니면 줄에서 끝의 자손인
    가장 오래된 커밋(머지 커밋). 끝이 기본 브랜치에 없거나 읽지 못하면 None."""
    if tip in line:
        return tip
    rc, out, _e = git_fn("rev-list", "--ancestry-path", "%s..%s" % (tip, DEFAULT_REF))
    if rc:
        return None
    after = set(out.split())
    return next((c for c in reversed(line) if c in after), None)


def _by_tips(states: list, base: str, git_fn, memo: dict):
    """브랜치마다 끝이 기본 브랜치에 든 커밋으로 잰다(D2.2) — 하나라도 기준 뒤면 IN, 모두 기준 전이면 OUT,
    끝 · 진입 커밋을 확인하지 못한 브랜치가 남으면 None."""
    unknown = not states
    for s in states:
        if not s.get("merged") or not s.get("tip"):
            unknown = True
            continue
        line = _memo(memo, "line", lambda: _first_parent_line(git_fn))
        entry = _entry(s["tip"], line, git_fn) if line else None
        before = _before(entry, base, git_fn) if entry else None
        if before is False:
            return IN
        unknown = unknown or before is None
    return None if unknown else OUT


def _by_docs(specs: list, base: str, git_fn, memo: dict):
    """브랜치가 하나인 머지된 에픽 — 설계문서(산출물)를 기본 브랜치 첫째 부모 줄에 처음 더한 커밋이 그 머지다
    (스쿼시 · 리베이스 · 지운 브랜치에도 남는다). 모두 기준 전이면 OUT, 하나라도 기준 뒤면 IN, 못 찾으면 None.
    처음 더한 커밋은 상태 계산의 doc_added 와 같은 규칙(first_added — 이름 바꿈을 따라간다)으로 찾는다."""
    def events():
        rc, out, _e = git_fn("log", "--first-parent", "-M", "--diff-filter=AR", "--name-status",
                             "--format=%x00%H", DEFAULT_REF)
        return parse_fp_events(out) if rc == 0 else None
    evs = _memo(memo, "events", events)
    added = [first_added(evs, p) for p in specs] if evs else []
    if not added or not all(added):
        return None
    verdicts = [_before(a, base, git_fn) for a in added]
    if False in verdicts:
        return IN
    return None if None in verdicts else OUT


def _verdict(b: dict, base, git_fn, memo: dict):
    """이 에픽 설계 전에 끝난 바탕이면 OUT, 함께 진행됐다고 확인되면 IN, 확인하지 못하면 None(싣는다)."""
    specs = list(b.get("specs") or [])
    if base is None or not specs:
        return None
    if any(git_fn("cat-file", "-e", "%s:%s" % (base, p))[0] != 0 for p in specs):
        return IN   # 지금 경로의 글이 기준 트리에 없다 — 이 에픽 설계 뒤에 든 글이다
    states = list(b.get("branch_states") or [])
    verdict = _by_tips(states, base, git_fn, memo)
    single = len(states) == 1 if states else len(b.get("branches") or []) == 1
    if verdict is None and single and b.get("stage") == MERGED:
        verdict = _by_docs(specs, base, git_fn, memo)
    return verdict


def _section(b: dict, git_fn, warns: list, unverified: bool) -> list:
    eid = b.get("id")
    merged = b.get("stage") == MERGED
    label = (MERGED + (" · " + UNVERIFIED if unverified else "")) if merged else "열림"
    tree = DEFAULT_REF if merged else (b.get("tip") or DEFAULT_REF)
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
    body, memo, n_unverified = [], {}, 0
    for b in report.get("blocks") or []:
        if b.get("id") == epic or b.get("stage") in NOT_STARTED:
            continue
        verdict = _verdict(b, base, git_fn, memo)
        if verdict == OUT:
            continue
        unverified = verdict is None and b.get("stage") == MERGED
        n_unverified += unverified
        body += _section(b, git_fn, warns, unverified)
    if not body:
        return "%s\n%s\n" % (first, NONE_LINE), warns
    head = [first]
    if n_unverified:
        head.append(COUNT_LINE % n_unverified)
        warns.append(COUNT_LINE % n_unverified)
    return "\n".join(head + [""] + body).rstrip("\n") + "\n", warns
