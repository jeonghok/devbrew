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
    if yaml is None:
        raise RuntimeError("pyyaml_missing")
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


def cmd_profile_check(a) -> int:
    try:
        prof = load_profile(a.profile)
    except ProfileError as e:
        fail("profile_invalid", detail=str(e), profile=a.profile)
        return 2
    pub = {k: v for k, v in prof.items() if k != "body"}
    print(json.dumps(pub, ensure_ascii=False, indent=1))
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


# ── 전이 ────────────────────────────────────────────────────────────────
PUBLIC_FIELDS = ("id", "lineage", "bucket", "supersedes", "origin", "layer", "category", "anchor",
                 "disposition", "summary", "edit_scope", "blocks", "evidence", "decision_view",
                 "state", "promotion", "promoted_from", "immutable", "kind")


def is_open(st, fid) -> bool:
    f = st["findings"].get(fid)
    if not f:
        return False
    d = f.get("disposition")
    if d == "decide":
        return st["decides"].get(fid, {}).get("state") in ("open", "adopted", "expired")
    if d == "fix":
        return st["fixes"].get(fid, {}).get("state") in ("pending", "intent_passed", "held", "escalated")
    if d == "ask":
        a = st["asks"].get(fid, {})
        return (not a.get("answered")) and bool(a.get("blocks"))
    return False


def _refresh_open_lineages(st, n) -> None:
    r = st["rounds"].setdefault(str(n), {"open_lineages": [], "progress": 0, "route_report": None})
    r["open_lineages"] = sorted({st["findings"][f]["lineage"] for f in st["findings"] if is_open(st, f)})


def record_findings(st, findings, n) -> None:
    """라우팅이 끝난 finding 목록을 원장에 적는다 (route.finalize 와 record-findings CLI 가 부른다)."""
    for it in findings:
        fid = it["id"]
        st["findings"][fid] = {k: it.get(k) for k in PUBLIC_FIELDS}
        if it.get("state") == "rejected":
            continue
        d = it.get("disposition")
        if d == "decide":
            st["decides"][fid] = {"state": "open", "kind": it.get("kind") or "pre",
                                  "immutable": bool(it.get("immutable")),
                                  "prev_hash": it.get("prev_hash"), "round": n}
        elif d == "fix":
            st["fixes"][fid] = {"state": "pending", "round": n, "scope": None}
        elif d == "ask":
            st["asks"][fid] = {"answered": False, "blocks": list(it.get("blocks") or []), "round": n}
    for _fid, a in st["asks"].items():
        if a.get("answered"):
            continue
        for b in a.get("blocks") or []:
            fx = st["fixes"].get(b)
            if fx and fx["state"] == "pending":
                fx["state"] = "held"
    _refresh_open_lineages(st, n)


def append_under_heading(path: Path, heading: str, line: str) -> None:
    """append-only: 그 헤딩 절의 끝에 한 줄. 헤딩이 없으면 파일 끝에 헤딩부터 만든다."""
    text = path.read_text(encoding="utf-8") if path.is_file() else ""
    lines = text.split("\n")
    level = len(heading) - len(heading.lstrip("#"))
    idx = next((i for i, l in enumerate(lines) if l.strip() == heading.strip()), None)
    if idx is None:
        text = text.rstrip("\n") + "\n\n" + heading.strip() + "\n\n" + line + "\n"
        path.write_text(text, encoding="utf-8")
        return
    end = len(lines)
    for j in range(idx + 1, len(lines)):
        m = re.match(r"^(#{1,6})[ \t]+", lines[j])
        if m and len(m.group(1)) <= level:
            end = j
            break
    while end > idx + 1 and lines[end - 1].strip() == "":
        end -= 1
    lines[end:end] = [line]
    if end + 1 < len(lines) and lines[end + 1].strip() != "":
        lines[end + 1:end + 1] = [""]
    path.write_text("\n".join(lines), encoding="utf-8")


def _log_line(entry, f) -> str:
    s = "- %s · r%d · %s · %s · \"%s\"" % (entry["decision_id"], entry["round"], entry["choice"],
                                           ", ".join(entry["finding_ids"]), entry["quote"])
    if entry.get("supersedes"):
        s += " · supersedes %s" % entry["supersedes"]
    return s + " — " + (f.get("summary") or "")


def cmd_record_findings(a) -> int:
    st = load_state(a.state_dir)
    data = json.loads(Path(a.json).read_text(encoding="utf-8"))
    findings = data.get("findings") if isinstance(data, dict) else data
    if not isinstance(findings, list):
        return fail("findings_not_list")
    record_findings(st, findings, int(st["round"]))
    save_state(a.state_dir, st, "record-findings (%d)" % len(findings))
    _emit({"ok": True, "recorded": len(findings)})
    return 0


def cmd_exempt_anchors(a) -> int:
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    n = int(st["round"])
    out = []
    for s in st["applied_scopes"]:
        if int(s["round"]) == n - 1:
            out.append(s["scope"])
    for _did, p in st["permits"].items():
        if int(p["round"]) == n and not p.get("consumed"):
            out.extend(p["apply_anchors"])
    for key in ("decision_log", "defer_target"):
        t = prof[key]
        if t.get("kind") == "doc_section":
            out.append(heading_anchor(t["heading"]))
    print(json.dumps(sorted(set(out)), ensure_ascii=False))
    return 0


def cmd_decide(a) -> int:
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    d = st["decides"].get(a.id)
    if not d:
        return fail("unknown_decide", id=a.id)
    if d["state"] != "open":
        return fail("decide_not_open", id=a.id, state=d["state"])
    n = int(st["round"])
    f = st["findings"][a.id]
    entry = {"decision_id": "D%d.%d" % (n, len(st["decision_log"]) + 1), "round": n,
             "finding_ids": [a.id], "lineage": f["lineage"], "choice": a.choice, "quote": a.quote}
    prev = [e for e in st["decision_log"] if e.get("lineage") == f["lineage"]]
    if prev:
        entry["supersedes"] = prev[-1]["decision_id"]
    permit = None
    if a.choice == "hold":
        d["state"] = "held"
        st["asks"][a.id] = {"answered": False, "blocks": [], "round": n, "from_decide": True}
        f["disposition"] = "ask"
    elif a.choice == "reject":
        st["rejected_lineages"][f["lineage"]] = {"by": "user", "why": a.quote, "round": n}
        if d.get("kind") == "post":
            d["state"] = "adopted"
            permit = {"kind": "revert", "apply_anchors": [f["anchor"]], "expect_hash": d.get("prev_hash"),
                      "round": n + 1, "finding_id": a.id, "consumed": False}
        else:
            d["state"] = "rejected"
    else:  # adopt
        if d.get("kind") == "post":
            d["state"] = "applied"
        else:
            d["state"] = "adopted"
            if d.get("immutable"):
                secs = st["snapshots"][str(n)]["sections"]
                anchors = anchors_matching(prof["fix_anchors"], secs)
            else:
                anchors = [f.get("edit_scope") or f["anchor"]]
            permit = {"kind": "apply", "apply_anchors": anchors, "round": n + 1,
                      "finding_id": a.id, "consumed": False}
    if permit:
        st["permits"][entry["decision_id"]] = permit
    d["decision_id"] = entry["decision_id"]
    st["decision_log"].append(entry)
    if a.log_file:
        heading = prof["decision_log"].get("heading")
        if not heading:
            return fail("profile_decision_log_is_state_only")
        append_under_heading(Path(a.log_file), heading, _log_line(entry, f))
    _refresh_open_lineages(st, n)
    save_state(a.state_dir, st, "decide %s %s" % (a.id, a.choice))
    out = {"ok": True, "decision_id": entry["decision_id"], "state": d["state"], "permit": permit}
    if entry.get("supersedes"):
        out["supersedes"] = entry["supersedes"]
    _emit(out)
    return 0


def cmd_fix(a) -> int:
    st = load_state(a.state_dir)
    fx = st["fixes"].get(a.id)
    if not fx:
        return fail("unknown_fix", id=a.id)
    n = int(st["round"])
    ev = a.event
    if ev == "intent-pass":
        if not a.scope:
            return fail("scope_required")
        fx["state"] = "intent_passed"
        fx["scope"] = a.scope
        fx["round"] = n
        st["applied_scopes"].append({"finding_id": a.id, "scope": a.scope, "round": n})
    elif ev == "drop":
        fx["state"] = "dropped"
        st["decision_log"].append({"decision_id": "D%d.%d" % (n, len(st["decision_log"]) + 1), "round": n,
                                   "finding_ids": [a.id], "lineage": st["findings"][a.id]["lineage"],
                                   "choice": "drop", "quote": a.reason or ""})
        if a.log_file:
            prof = load_profile(st["profile"])
            if prof["decision_log"].get("heading"):
                append_under_heading(Path(a.log_file), prof["decision_log"]["heading"],
                                     _log_line(st["decision_log"][-1], st["findings"][a.id]))
    elif ev == "hold":
        fx["state"] = "held"
    elif ev == "unhold":
        if fx["state"] == "held":
            fx["state"] = "pending"
    elif ev == "escalate":
        fx["state"] = "escalated"
        st["escalated"].append({"finding_id": a.id, "reason": a.reason or "check-intent 거부", "round": n})
    else:
        return fail("unknown_event", event=ev)
    _refresh_open_lineages(st, n)
    save_state(a.state_dir, st, "fix %s %s" % (a.id, ev))
    _emit({"ok": True, "state": fx["state"]})
    return 0


def cmd_ask(a) -> int:
    st = load_state(a.state_dir)
    ask = st["asks"].get(a.id)
    if not ask:
        return fail("unknown_ask", id=a.id)
    if a.answered:
        ask["answered"] = True
        for b in ask.get("blocks") or []:
            fx = st["fixes"].get(b)
            if fx and fx["state"] == "held":
                fx["state"] = "pending"
    _refresh_open_lineages(st, int(st["round"]))
    save_state(a.state_dir, st, "ask %s answered=%s" % (a.id, bool(a.answered)))
    _emit({"ok": True, "answered": ask["answered"]})
    return 0


def cmd_defer(a) -> int:
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    f = st["findings"].get(a.id)
    if not f or f.get("disposition") != "defer":
        return fail("not_a_defer", id=a.id)
    t = prof["defer_target"]
    if t.get("kind") != "doc_section":
        return fail("profile_has_no_defer_target")
    append_under_heading(Path(a.log_file), t["heading"], "| %s | %s |" % (a.id, f.get("summary") or ""))
    f["deferred"] = True
    save_state(a.state_dir, st, "defer %s appended" % a.id)
    _emit({"ok": True})
    return 0


def cmd_observe_diff(a) -> int:
    st = load_state(a.state_dir)
    n = int(st["round"])
    diff = json.loads(Path(a.diff).read_text(encoding="utf-8"))
    touched = {c["anchor"] for c in diff.get("changed", [])}
    touched |= {e["anchor"] for e in diff.get("exempt_applied", [])}
    touched |= {e["scope"] for e in diff.get("exempt_applied", []) if e.get("scope")}
    cur = {s["anchor"]: s["hash"] for s in st["snapshots"].get(str(n), {}).get("sections", [])}
    applied, expired, reraise = [], [], []
    r = st["rounds"].setdefault(str(n), {"open_lineages": [], "progress": 0, "route_report": None})
    for did, p in st["permits"].items():
        if p.get("consumed") or int(p["round"]) != n:
            continue
        fid = p["finding_id"]
        d = st["decides"].get(fid)
        if not d:
            continue
        if p["kind"] == "apply":
            hit = any(x in touched for x in p["apply_anchors"])
        else:
            hit = cur.get(p["apply_anchors"][0]) == p.get("expect_hash")
        p["consumed"] = True
        if hit:
            d["state"] = "applied"
            r["progress"] += 1
            applied.append(fid)
        else:
            d["state"] = "expired"
            expired.append(fid)
            reraise.append({"finding_id": fid, "kind": p["kind"],
                            "reason": "라운드 %d 에 %s 변경 관측 없음 (%s)" % (
                                n, "원복" if p["kind"] == "revert" else "채택", did)})
    for fid, fx in st["fixes"].items():
        if fx["state"] == "intent_passed" and int(fx.get("round") or 0) == n - 1 and fx.get("scope") in touched:
            fx["state"] = "applied"
            r["progress"] += 1
            applied.append(fid)
    st["reraise"] = reraise
    _refresh_open_lineages(st, n)
    save_state(a.state_dir, st, "observe-diff applied=%d expired=%d" % (len(applied), len(expired)))
    _emit({"ok": True, "applied": applied, "expired": expired, "reraise": reraise, "progress": r["progress"]})
    return 0


def gate_summary(st) -> dict:
    n = int(st["round"])
    rr = int(st["rereview_count"])
    dec = st["decides"]
    fx = st["fixes"]
    asks = st["asks"]
    g = {
        "round": n, "rereview_count": rr, "cap_reached": rr >= REREVIEW_CAP,
        "open_decide": sorted(i for i, d in dec.items() if d["state"] == "open"),
        "adopted": sorted(i for i, d in dec.items() if d["state"] in ("adopted", "expired")),
        "unapplied_fix": sorted(i for i, f in fx.items() if f["state"] in ("pending", "intent_passed")),
        "held_fix": sorted(i for i, f in fx.items() if f["state"] == "held"),
        "asks_open": sorted(i for i, x in asks.items() if not x.get("answered")),
        "blocking_ask_open": sorted(i for i, x in asks.items() if not x.get("answered") and x.get("blocks")),
        "defers": sorted(i for i, f in st["findings"].items() if f.get("disposition") == "defer"),
        "dropped": sorted(i for i, f in fx.items() if f["state"] == "dropped"),
        "extra_rounds": st["extra_rounds"],
    }
    cur = st["rounds"].get(str(n), {})
    prev = st["rounds"].get(str(n - 1), {})
    g["stagnation"] = bool(n >= 2 and cur.get("open_lineages") and
                           cur.get("open_lineages") == prev.get("open_lineages") and int(cur.get("progress", 0)) == 0)
    g["approval_ready"] = not g["open_decide"] and not g["adopted"] and not g["unapplied_fix"]
    g["round_gate_needed"] = bool(g["open_decide"] or g["blocking_ask_open"])
    g["approval_gate_open"] = g["approval_ready"] or g["cap_reached"] or g["stagnation"]
    g["two_stage"] = g["approval_gate_open"] and not g["approval_ready"]
    g["next_round_mode"] = None if g["approval_ready"] else ("budget" if rr < REREVIEW_CAP else "extra_approval")
    rep = cur.get("route_report") or {}
    g["degrade"] = rep.get("degrade") or {}
    g["advisory"] = rep.get("advisory") or []
    g["counts"] = {k: rep.get(k, 0) for k in ("rejected", "bucket_conflicts", "lineage_mismatch", "revived")}
    g["counts"]["user_rejected"] = sum(1 for v in st["rejected_lineages"].values() if v.get("by") == "user")
    return g


def render_gate(st, g) -> str:
    deg = g["degrade"]
    out = []
    if deg.get("codex_absent"):
        out.append("codex 없음 — 모델 다양성 0 (%s)" % (deg.get("codex_reason") or "?"))
    elif g["advisory"]:
        out.append("degrade: " + " · ".join(g["advisory"]))
    else:
        out.append("degrade 없음")
    out.append("라운드 %d · 재리뷰 %d/%d%s%s" % (g["round"], g["rereview_count"], REREVIEW_CAP,
                                              " · 상한 도달" if g["cap_reached"] else "",
                                              " · stagnation" if g["stagnation"] else ""))
    F = st["findings"]
    for fid in g["open_decide"]:
        f = F[fid]
        dv = f.get("decision_view") or {}
        out.append("[decide%s] %s — %s" % (" auto" if dv.get("auto") else "", fid, f.get("summary")))
        out.append("  변경: %s" % dv.get("change", f.get("summary")))
        out.append("  근거: %s" % dv.get("basis", f.get("evidence") or "—"))
        out.append("  대안: %s" % " / ".join(dv.get("alternatives") or ["채택", "기각", "보류"]))
        out.append("  영향: %s" % dv.get("impact", f.get("anchor")))
    for fid in g["blocking_ask_open"]:
        f = F[fid]
        out.append("[ask 비차단] %s — %s → 전제인 fix: %s" % (fid, f.get("summary"), ", ".join(f.get("blocks") or [])))
    if g["held_fix"]:
        out.append("보류된 fix(전제 ask 미응답): " + ", ".join(g["held_fix"]))
    if g["approval_gate_open"] and g["unapplied_fix"]:
        out.append("미적용 fix(적용 예정 / drop): " + ", ".join(g["unapplied_fix"]))
    c = g["counts"]
    out.append("기각 %d건(재비판) · 사용자 기각 %d · drop %d · bucket 충돌 %d · 계보 지목 불일치 %d · 기각 계보 재상승 %d"
               % (c["rejected"], c["user_rejected"], len(g["dropped"]), c["bucket_conflicts"],
                  c["lineage_mismatch"], c["revived"]))
    if g["approval_ready"]:
        out.append("다음: 승인 게이트 — 진행 옵션 활성")
    elif g["two_stage"]:
        out.append("다음: 승인 게이트 1단계 — 열린 항목을 처리한 뒤 진행 옵션 (다음 라운드 = %s)" % g["next_round_mode"])
    else:
        out.append("다음: 라운드 %d (%s)" % (g["round"] + 1, g["next_round_mode"]))
    return "\n".join(out)


def cmd_gate(a) -> int:
    st = load_state(a.state_dir)
    g = gate_summary(st)
    if a.render:
        print(render_gate(st, g))
    else:
        print(json.dumps(g, ensure_ascii=False))
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
    x = sp.add_parser("profile-check"); x.add_argument("profile")
    x.set_defaults(fn=cmd_profile_check)

    def sd(x):
        x.add_argument("--state-dir", required=True)
        return x
    x = sd(sp.add_parser("record-findings")); x.add_argument("--json", required=True); x.set_defaults(fn=cmd_record_findings)
    x = sd(sp.add_parser("exempt-anchors")); x.set_defaults(fn=cmd_exempt_anchors)
    x = sd(sp.add_parser("decide")); x.add_argument("--id", required=True)
    x.add_argument("--choice", required=True, choices=("adopt", "reject", "hold"))
    x.add_argument("--quote", required=True); x.add_argument("--log-file", default=None); x.set_defaults(fn=cmd_decide)
    x = sd(sp.add_parser("fix")); x.add_argument("--id", required=True)
    x.add_argument("--event", required=True, choices=("intent-pass", "drop", "hold", "unhold", "escalate"))
    x.add_argument("--scope", default=None); x.add_argument("--reason", default=None)
    x.add_argument("--log-file", default=None); x.set_defaults(fn=cmd_fix)
    x = sd(sp.add_parser("ask")); x.add_argument("--id", required=True)
    x.add_argument("--answered", action="store_true"); x.set_defaults(fn=cmd_ask)
    x = sd(sp.add_parser("defer")); x.add_argument("--id", required=True)
    x.add_argument("--log-file", required=True); x.set_defaults(fn=cmd_defer)
    x = sd(sp.add_parser("observe-diff")); x.add_argument("--diff", required=True); x.set_defaults(fn=cmd_observe_diff)
    x = sd(sp.add_parser("gate")); x.add_argument("--render", action="store_true"); x.set_defaults(fn=cmd_gate)
    return p


def main(argv=None) -> int:
    a = build_parser().parse_args(argv)
    try:
        return a.fn(a)
    except FileNotFoundError as e:
        return fail("state_missing", path=str(e))
    except (ValueError, RuntimeError) as e:
        return fail("state_unreadable", detail=str(e))
    except ProfileError as e:
        return fail("profile_invalid", detail=str(e))


if __name__ == "__main__":
    sys.exit(main())
