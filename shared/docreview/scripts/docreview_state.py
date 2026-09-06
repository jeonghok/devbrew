#!/usr/bin/env python3
"""docreview_state.py — 문서 리뷰 엔진의 세션 라운드 원장 (leaf 모듈).

state 디렉토리는 **인자**(`--state-dir`)다. 호스트의 `state_path.py` 를 import 하지 않는다 —
두 호스트의 시그니처가 다르다(spec-distill: resolve_session_id+state_root(cwd) / quality-gates:
state_root(hook_input, hook_name)). 파일은 `<state-dir>/docreview-state.md` 하나이고
frontmatter 의 `docreview:` 트리가 원장, 본문은 사람이 읽는 사건 로그다. `state.local.md` 는
건드리지 않는다 — 그 파일은 훅과 brief 파이프라인의 줄 파서가 소유한다.

서브커맨드: init · begin-round · exempt-anchors · decide · fix · ask · defer · observe-diff · gate
전이 규칙의 정본은 plan(2026-09-06-document-review-engine.md)의 D13 표다.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

STATE_FILE = "docreview-state.md"
REREVIEW_CAP = 2
RANK = {"decide": 4, "ask": 3, "fix": 2, "defer": 1, "drop": 0}
PROFILE_FIELDS = ("detectors", "ground_truth", "allowed_dispositions", "fix_anchors",
                  "immutable", "protected_headings", "layer_rubric", "decision_log",
                  "defer_target", "web")
LOG_KINDS = ("doc_section", "audit_section", "state")
DEFER_KINDS = ("doc_section", "none")


class ProfileError(Exception):
    pass


def fail(reason, **extra):
    out = {"ok": False, "reason": reason}
    out.update(extra)
    print(json.dumps(out, ensure_ascii=False), file=sys.stderr)
    return 1


# ── slug ────────────────────────────────────────────────────────────────
_SLUG_STRIP = re.compile(r"[^\w\s-]", re.UNICODE)


def slugify(title: str) -> str:
    """GitHub 식 앵커: 소문자 · 구두점 제거 · 공백→'-' (연속 하이픈 유지)."""
    s = title.strip().lower()
    s = _SLUG_STRIP.sub("", s)
    return re.sub(r"\s", "-", s)


# ── 프로필 ───────────────────────────────────────────────────────────────
def _split_frontmatter(text: str):
    if not text.startswith("---\n"):
        raise ProfileError("frontmatter_missing")
    end = text.find("\n---\n", 4)
    if end < 0:
        raise ProfileError("frontmatter_unclosed")
    return text[4:end], text[end + 5:]


def _str_list(v, field):
    if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
        raise ProfileError("field_not_str_list:%s" % field)
    for pat in v:
        if pat != "*":
            try:
                re.compile(pat)
            except re.error as e:
                raise ProfileError("bad_regex:%s:%s" % (field, e))
    return v


def load_profile(path) -> dict:
    if yaml is None:
        raise ProfileError("pyyaml_missing")
    p = Path(path)
    if not p.is_file():
        raise ProfileError("profile_not_found:%s" % p)
    fm, body = _split_frontmatter(p.read_text(encoding="utf-8"))
    data = yaml.safe_load(fm) or {}
    if not isinstance(data, dict):
        raise ProfileError("frontmatter_not_mapping")
    missing = [f for f in PROFILE_FIELDS if f not in data]
    extra = [k for k in data if k not in PROFILE_FIELDS]
    if missing:
        raise ProfileError("fields_missing:%s" % ",".join(missing))
    if extra:
        raise ProfileError("fields_unknown:%s" % ",".join(extra))
    if data["detectors"] != 1:
        raise ProfileError("detectors_unsupported:%r" % (data["detectors"],))
    ad = data["allowed_dispositions"]
    if (not isinstance(ad, list) or not ad or any(x not in RANK for x in ad)
            or "decide" not in ad or "ask" not in ad):
        raise ProfileError("allowed_dispositions_invalid")
    for f in ("fix_anchors", "immutable", "protected_headings"):
        _str_list(data[f], f)
    lr = data["layer_rubric"]
    if (not isinstance(lr, dict) or not isinstance(lr.get("layer1"), list) or not lr["layer1"]
            or not isinstance(lr.get("layer2"), list)):
        raise ProfileError("layer_rubric_invalid")
    dl = data["decision_log"]
    if not isinstance(dl, dict) or dl.get("kind") not in LOG_KINDS:
        raise ProfileError("decision_log_invalid")
    if dl["kind"] != "state" and not isinstance(dl.get("heading"), str):
        raise ProfileError("decision_log_heading_missing")
    dt = data["defer_target"]
    if not isinstance(dt, dict) or dt.get("kind") not in DEFER_KINDS:
        raise ProfileError("defer_target_invalid")
    if dt["kind"] == "doc_section" and not isinstance(dt.get("heading"), str):
        raise ProfileError("defer_target_heading_missing")
    if "defer" in ad and dt["kind"] == "none":
        raise ProfileError("defer_allowed_without_target")
    if not isinstance(data["web"], bool):
        raise ProfileError("web_not_bool")
    if not isinstance(data["ground_truth"], str) or not data["ground_truth"].strip():
        raise ProfileError("ground_truth_empty")
    out = dict(data)
    out["name"] = p.stem
    out["path"] = str(p)
    out["body"] = body
    return out


def _titles_of(sec, by_anchor):
    ts = [sec.get("title") or ""]
    for pa in sec.get("parents") or []:
        ps = by_anchor.get(pa)
        if ps:
            ts.append(ps.get("title") or "")
    return ts


def anchors_matching(patterns, sections) -> list:
    """제목 또는 조상 제목이 패턴에 맞는 섹션 앵커. '*' 는 전부."""
    if "*" in patterns:
        return [s["anchor"] for s in sections]
    by = {s["anchor"]: s for s in sections}
    out = []
    for s in sections:
        ts = _titles_of(s, by)
        if any(re.search(pat, t, re.I) for pat in patterns for t in ts):
            out.append(s["anchor"])
    return out


def heading_anchor(heading: str) -> str:
    return "#" + slugify(re.sub(r"^#+\s*", "", heading))


# ── 원장 I/O ────────────────────────────────────────────────────────────
def _empty(doc, profile):
    return {
        "doc": doc, "profile": profile, "round": 0, "rereview_count": 0,
        "extra_rounds": [], "snapshots": {}, "findings": {}, "decides": {},
        "fixes": {}, "asks": {}, "permits": {}, "applied_scopes": [],
        "decision_log": [], "rounds": {}, "pending_recritic": None,
        "rejected_lineages": {}, "escalated": [], "reraise": [],
    }


def state_path(state_dir) -> Path:
    return Path(state_dir) / STATE_FILE


def load_state(state_dir) -> dict:
    p = state_path(state_dir)
    if not p.is_file():
        raise FileNotFoundError(str(p))
    if yaml is None:
        raise RuntimeError("pyyaml_missing")
    text = p.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValueError("frontmatter_missing")
    end = text.find("\n---\n", 4)
    if end < 0:
        raise ValueError("frontmatter_unclosed")
    data = yaml.safe_load(text[4:end]) or {}
    st = data.get("docreview") if isinstance(data, dict) else None
    if not isinstance(st, dict):
        raise ValueError("docreview_key_missing")
    st["_body"] = text[end + 5:]
    return st


def save_state(state_dir, st, log_line=None) -> None:
    body = st.pop("_body", "# docreview 원장\n")
    if log_line:
        body = body.rstrip("\n") + "\n- r%s: %s\n" % (st.get("round"), log_line)
    fm = yaml.safe_dump({"docreview": st}, allow_unicode=True, sort_keys=False,
                        default_flow_style=False)
    state_path(state_dir).write_text("---\n" + fm + "---\n" + body, encoding="utf-8")
    st["_body"] = body


def _emit(obj) -> None:
    print(json.dumps(obj, ensure_ascii=False))


# ── 서브커맨드 ───────────────────────────────────────────────────────────
def cmd_init(a) -> int:
    if yaml is None:
        return fail("pyyaml_missing")
    try:
        load_profile(a.profile)
    except ProfileError as e:
        return fail("profile_invalid", detail=str(e))
    d = Path(a.state_dir)
    if not d.is_dir():
        return fail("state_dir_missing", state_dir=str(d))
    p = state_path(d)
    if p.is_file():
        st = load_state(d)
        _emit({"ok": True, "created": False, "round": st["round"]})
        return 0
    st = _empty(a.doc, a.profile)
    st["_body"] = "# docreview 원장\n"
    save_state(d, st, "init")
    _emit({"ok": True, "created": True, "round": 0})
    return 0


def cmd_begin_round(a) -> int:
    st = load_state(a.state_dir)
    snap = json.loads(Path(a.snapshot).read_text(encoding="utf-8"))
    n = int(st["round"]) + 1
    if n <= 1 + REREVIEW_CAP:
        rr = n - 1
    else:
        if not a.extra_approval:
            _emit({"ok": False, "reason": "cap_reached", "round": n - 1,
                   "rereview_count": st["rereview_count"]})
            return 3
        rr = REREVIEW_CAP
        st["extra_rounds"].append({"round": n, "quote": a.extra_approval})
    st["round"] = n
    st["rereview_count"] = rr
    st["snapshots"][str(n)] = {
        "headingless": bool(snap.get("headingless")),
        "sections": [{k: s.get(k) for k in ("anchor", "title", "level", "hash", "parents")}
                     for s in snap.get("sections", [])],
    }
    st["rounds"].setdefault(str(n), {"open_lineages": [], "progress": 0, "route_report": None})
    save_state(a.state_dir, st, "begin-round (rereview_count=%d%s)"
               % (rr, ", extra" if n > 1 + REREVIEW_CAP else ""))
    _emit({"ok": True, "round": n, "rereview_count": rr})
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="docreview_state.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    x = sp.add_parser("init"); x.add_argument("--state-dir", required=True)
    x.add_argument("--doc", required=True); x.add_argument("--profile", required=True)
    x.set_defaults(fn=cmd_init)
    x = sp.add_parser("begin-round"); x.add_argument("--state-dir", required=True)
    x.add_argument("--snapshot", required=True); x.add_argument("--extra-approval", default=None)
    x.set_defaults(fn=cmd_begin_round)
    return p


def main(argv=None) -> int:
    a = build_parser().parse_args(argv)
    try:
        return a.fn(a)
    except FileNotFoundError as e:
        return fail("state_missing", path=str(e))
    except (ValueError, RuntimeError) as e:
        return fail("state_unreadable", detail=str(e))


if __name__ == "__main__":
    sys.exit(main())
