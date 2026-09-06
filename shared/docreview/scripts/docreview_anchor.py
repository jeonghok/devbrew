#!/usr/bin/env python3
"""docreview_anchor.py — 헤딩 단위 앵커 도구.

snapshot(헤딩 파싱 → 섹션 앵커·해시) · diff(두 스냅샷의 헤딩 단위 변경, 얼림 예외 제외) ·
protected(앵커의 보호·불변·fix 허용 여부) · refs(그 앵커를 인용하는 섹션) · check-intent(패치 의도).

파싱 규칙: ATX 헤딩만(setext 없음) · 코드 펜스 안 무시 · frontmatter 건너뜀 · 앵커는 GitHub slug ·
섹션은 그 헤딩부터 다음 헤딩(레벨 무관) 직전까지(평면) · 해시는 우측 공백 제거 본문의 sha1 앞 12자.
보호·불변·fix 허용은 제목과 조상 제목 전부에 대해 정규식 검색한다(하위 절로 캐스케이드).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))  # bare .parent — 배포 지점의 형제를 읽는다
from docreview_state import (  # noqa: E402
    ProfileError, anchors_matching, fail, load_profile, load_state, save_state,
    slugify,
)

HEADING_RE = re.compile(r"^(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$")
FENCE_RE = re.compile(r"^[ \t]{0,3}(`{3,}|~{3,})")
PREAMBLE = "#__preamble__"
DOC_ANCHOR = "#__doc__"


# ── 파싱 ────────────────────────────────────────────────────────────────
def _after_frontmatter(lines) -> int:
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                return i + 1
    return 0


def parse_sections(text: str, keep_body: bool = False) -> dict:
    lines = text.split("\n")
    start = _after_frontmatter(lines)
    heads = []
    fence = None
    for i in range(start, len(lines)):
        line = lines[i]
        fm = FENCE_RE.match(line)
        if fm:
            tok = fm.group(1)[0]
            if fence is None:
                fence = tok
            elif tok == fence:
                fence = None
            continue
        if fence:
            continue
        hm = HEADING_RE.match(line)
        if hm:
            heads.append((i, len(hm.group(1)), hm.group(2).strip()))
    sections = []

    def add(anchor, title, level, a, b, parents):
        body = "\n".join(x.rstrip() for x in lines[a:b]).strip("\n")
        item = {"anchor": anchor, "title": title, "level": level, "line": a + 1,
                "hash": hashlib.sha1(body.encode("utf-8")).hexdigest()[:12],
                "parents": list(parents)}
        if keep_body:
            item["body"] = body
        sections.append(item)

    if not heads:
        if "".join(lines[start:]).strip():
            add(DOC_ANCHOR, "(문서 전체)", 0, start, len(lines), [])
        return {"headingless": True, "sections": sections}
    if "".join(lines[start:heads[0][0]]).strip():
        add(PREAMBLE, "(머리말)", 0, start, heads[0][0], [])
    seen = {}
    stack = []  # [(level, anchor)]
    for k, (ln, lvl, title) in enumerate(heads):
        base = slugify(title)
        n = seen.get(base, 0)
        seen[base] = n + 1
        anchor = "#" + (base if n == 0 else "%s-%d" % (base, n))
        while stack and stack[-1][0] >= lvl:
            stack.pop()
        parents = [a for (_l, a) in stack]
        end = heads[k + 1][0] if k + 1 < len(heads) else len(lines)
        add(anchor, title, lvl, ln, end, parents)
        stack.append((lvl, anchor))
    return {"headingless": False, "sections": sections}


def snapshot_of(doc_path) -> dict:
    snap = parse_sections(Path(doc_path).read_text(encoding="utf-8"))
    snap["doc"] = str(doc_path)
    return snap


# ── diff ────────────────────────────────────────────────────────────────
def resolve_scope(scope: str, old_secs, new_secs) -> set:
    """scope → 앵커 집합. `insert-after:#x` 는 new 에서 #x 바로 다음이고 old 에 없던 앵커 하나."""
    if not scope.startswith("insert-after:"):
        return {scope}
    after = scope.split(":", 1)[1]
    old = {s["anchor"] for s in old_secs}
    for i, s in enumerate(new_secs):
        if s["anchor"] == after and i + 1 < len(new_secs):
            nxt = new_secs[i + 1]
            if nxt["anchor"] not in old:
                return {nxt["anchor"]}
    return set()


def diff_snapshots(old: dict, new: dict, exempt_scopes) -> dict:
    os_, ns = old.get("sections", []), new.get("sections", [])
    om = {s["anchor"]: s for s in os_}
    nm = {s["anchor"]: s for s in ns}
    headingless = bool(old.get("headingless") or new.get("headingless"))
    ex = {}
    for sc in exempt_scopes or []:
        for a in resolve_scope(sc, os_, ns):
            ex[a] = sc
    changed, exempt_applied = [], []

    def rec(anchor, kind, title, oh, nh):
        item = {"anchor": anchor, "kind": kind, "title": title, "old_hash": oh, "new_hash": nh,
                "evidence": "섹션 '%s' (%s) %s — hash %s→%s" % (title, anchor, kind, oh or "∅", nh or "∅")}
        if headingless:
            item["scope"] = DOC_ANCHOR
            exempt_applied.append(item)
        elif anchor in ex:
            item["scope"] = ex[anchor]
            exempt_applied.append(item)
        else:
            changed.append(item)

    for a, s in nm.items():
        if a not in om:
            rec(a, "added", s["title"], None, s["hash"])
        elif om[a]["hash"] != s["hash"]:
            rec(a, "modified", s["title"], om[a]["hash"], s["hash"])
    for a, s in om.items():
        if a not in nm:
            rec(a, "removed", s["title"], s["hash"], None)
    return {"headingless": headingless, "changed": changed, "exempt_applied": exempt_applied}


# ── 보호 부류 ────────────────────────────────────────────────────────────
def classify_anchor(anchor: str, sections, prof: dict) -> dict:
    found = any(s["anchor"] == anchor for s in sections)
    if not found:
        return {"anchor": anchor, "found": False, "protected": False, "immutable": False,
                "fix_allowed": "*" in prof["fix_anchors"]}
    return {
        "anchor": anchor, "found": True,
        "protected": anchor in anchors_matching(prof["protected_headings"], sections),
        "immutable": anchor in anchors_matching(prof["immutable"], sections),
        "fix_allowed": anchor in anchors_matching(prof["fix_anchors"], sections),
    }


# ── 인용 ────────────────────────────────────────────────────────────────
def refs_of(doc_path, anchor: str) -> list:
    snap = parse_sections(Path(doc_path).read_text(encoding="utf-8"), keep_body=True)
    tgt = next((s for s in snap["sections"] if s["anchor"] == anchor), None)
    hits = []
    for s in snap["sections"]:
        if s["anchor"] == anchor:
            continue
        body = s["body"]
        if anchor in body or (tgt and tgt["title"] and tgt["title"] in body):
            hits.append(s["anchor"])
    return hits


# ── CLI ─────────────────────────────────────────────────────────────────
def _emit(obj) -> None:
    print(json.dumps(obj, ensure_ascii=False))


def cmd_snapshot(a) -> int:
    p = Path(a.doc)
    if not p.is_file():
        return fail("doc_missing", doc=str(p))
    _emit(snapshot_of(p))
    return 0


def cmd_diff(a) -> int:
    old = json.loads(Path(a.old).read_text(encoding="utf-8"))
    new = json.loads(Path(a.new).read_text(encoding="utf-8"))
    ex = json.loads(Path(a.exempt).read_text(encoding="utf-8")) if a.exempt else []
    if not isinstance(ex, list):
        return fail("exempt_not_list")
    _emit(diff_snapshots(old, new, ex))
    return 0


def cmd_protected(a) -> int:
    try:
        prof = load_profile(a.profile)
    except ProfileError as e:
        return fail("profile_invalid", detail=str(e))
    snap = json.loads(Path(a.snapshot).read_text(encoding="utf-8"))
    _emit(classify_anchor(a.anchor, snap.get("sections", []), prof))
    return 0


def cmd_refs(a) -> int:
    hits = refs_of(a.doc, a.anchor)
    _emit({"anchor": a.anchor, "refs": len(hits), "sections": hits})
    return 0


# ── 패치 의도 (AC6) ─────────────────────────────────────────────────────
def _reject(reason, **extra):
    out = {"ok": False, "reason": reason}
    out.update(extra)
    print(json.dumps(out, ensure_ascii=False))
    return 1


def cmd_check_intent(a) -> int:
    """두 계약. 일반 fix: 앵커가 그 finding 의 edit_scope 안이고 프로필 fix_anchors 안이며
    보호 부류·immutable 이 아니어야 한다(넷 다 위반이면 escalate 로 다음 라운드 decide 로).
    decision permit: decision_id 가 유효하고 라운드가 맞고 그 apply_anchors 안이면
    edit_scope·fix_anchors·보호 부류를 우회하되 immutable 만은 절대 못 넘는다(AC11 — 예외 0).

    `insert-after:#x` 는 스냅샷에서 #x 를 찾을 수 있는지(`found`)와 별개로 #x 의 `protected`·
    `immutable` 도 본다(R13, 사용자 결정) — 헤딩 파싱이 평면이라(섹션 = 그 헤딩부터 **다음 헤딩**
    직전까지) #x 바로 뒤에 새 헤딩을 넣으면 #x 의 본문이 거기서 잘려 해시가 바뀐다. 즉 "삽입"이
    실제로는 #x 를 변경하므로, 라우터의 승격(anchor 만 봄)과 이 검사(예전엔 found 만 봄)가 함께
    놓치던 틈 — `edit_scope: "insert-after:#<보호 헤딩>"` — 을 여기서 막는다. 사유는 일반 앵커의
    `anchor_protected`/`anchor_immutable` 과 **다른 문자열**(`insert_after_protected`/
    `insert_after_immutable`)을 쓴다 — "내 fix 앵커가 보호"와 "내 삽입 자리가 보호"는 다른 사실이고
    미래 소비자가 구별할 수 있어야 한다. **`fix_anchors`(fix_allowed)는 여전히 안 본다** — 사용자
    결정이 보호/불변 둘에 한정됐다(R13 범위); 새 섹션이 어느 절 "안"으로 들어가는지를 재는 것이
    아니라서 fix_anchors 의 질문과 다르다. 일반 앵커(비-insert-after)에서는 immutable 을 가장 먼저
    본다: brief §6 류는 fix_anchors 밖이기도 하지만 그 사유를 anchor_not_in_fix_anchors 로 흐리면
    「immutable 은 예외 0」이라는 더 강한 사실이 하류에 안 보인다.
    """
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    n = int(st["round"])
    sections = st["snapshots"].get(str(n), {}).get("sections", [])
    f = st["findings"].get(a.finding_id)
    if not f:
        return _reject("unknown_finding", id=a.finding_id)
    intent = a.intent.strip()
    is_insert = intent.startswith("insert-after:")
    target = intent.split(":", 1)[1] if is_insert else intent
    cls = classify_anchor(target, sections, prof)
    if a.decision_id:
        p = st["permits"].get(a.decision_id)
        if not p:
            return _reject("unknown_permit", decision_id=a.decision_id)
        if int(p["round"]) != n:
            return _reject("permit_round_mismatch", permit_round=p["round"], round=n)
        if p.get("consumed"):
            return _reject("permit_consumed")
        if intent not in p["apply_anchors"]:
            return _reject("scope_outside_permit", apply_anchors=p["apply_anchors"])
        if cls["immutable"]:
            return _reject("anchor_immutable")
        print(json.dumps({"ok": True, "contract": "permit", "scope": intent, "decision_id": a.decision_id},
                         ensure_ascii=False))
        return 0
    if f.get("disposition") != "fix":
        return _reject("not_a_fix", disposition=f.get("disposition"))
    fx = st["fixes"].get(a.finding_id)
    if not fx or fx["state"] not in ("pending", "intent_passed"):
        return _reject("fix_not_pending", state=(fx or {}).get("state"))

    def escalate(reason):
        fx["state"] = "escalated"
        st["escalated"].append({"finding_id": a.finding_id, "reason": "check-intent 거부: " + reason, "round": n})
        save_state(a.state_dir, st, "check-intent reject %s (%s)" % (a.finding_id, reason))
        return _reject(reason)

    scope = f.get("edit_scope") or f["anchor"]
    if intent != scope:
        return escalate("scope_outside_edit_scope")
    if is_insert:
        if not cls["found"] and target != PREAMBLE:
            return escalate("insert_after_unresolved")
        if cls["immutable"]:
            return escalate("insert_after_immutable")
        if cls["protected"]:
            return escalate("insert_after_protected")
    else:
        if cls["immutable"]:
            return escalate("anchor_immutable")
        if not cls["fix_allowed"]:
            return escalate("anchor_not_in_fix_anchors")
        if cls["protected"]:
            return escalate("anchor_protected")
    fx["state"] = "intent_passed"
    fx["scope"] = intent
    fx["round"] = n
    st["applied_scopes"].append({"finding_id": a.finding_id, "scope": intent, "round": n})
    save_state(a.state_dir, st, "check-intent pass %s %s" % (a.finding_id, intent))
    print(json.dumps({"ok": True, "contract": "fix", "scope": intent}, ensure_ascii=False))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="docreview_anchor.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    x = sp.add_parser("snapshot"); x.add_argument("doc"); x.set_defaults(fn=cmd_snapshot)
    x = sp.add_parser("diff"); x.add_argument("old"); x.add_argument("new")
    x.add_argument("--exempt", default=None); x.set_defaults(fn=cmd_diff)
    x = sp.add_parser("protected"); x.add_argument("anchor")
    x.add_argument("--profile", required=True); x.add_argument("--snapshot", required=True)
    x.set_defaults(fn=cmd_protected)
    x = sp.add_parser("refs"); x.add_argument("anchor"); x.add_argument("doc"); x.set_defaults(fn=cmd_refs)
    x = sp.add_parser("check-intent"); x.add_argument("finding_id")
    x.add_argument("--intent", required=True); x.add_argument("--state-dir", required=True)
    x.add_argument("--decision-id", default=None); x.set_defaults(fn=cmd_check_intent)
    return p


def main(argv=None) -> int:
    a = build_parser().parse_args(argv)
    try:
        return a.fn(a)
    except FileNotFoundError as e:
        return fail("file_missing", path=str(e))
    except (ValueError, RuntimeError) as e:
        return fail("unreadable", detail=str(e))
    except ProfileError as e:
        return fail("profile_invalid", detail=str(e))


if __name__ == "__main__":
    sys.exit(main())
