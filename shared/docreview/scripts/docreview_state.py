#!/usr/bin/env python3
"""docreview_state.py — 문서 리뷰 엔진의 세션 라운드 원장 (leaf 모듈).

state 디렉토리는 **인자**(`--state-dir`)다. 호스트의 `state_path.py` 를 import 하지 않는다 —
두 호스트의 시그니처가 다르다(spec-distill: resolve_session_id+state_root(cwd) / quality-gates:
state_root(hook_input, hook_name)). 파일은 `<state-dir>/docreview-state.md` 하나이고
frontmatter 의 `docreview:` 트리가 원장, 본문은 사람이 읽는 사건 로그다. `state.local.md` 는
건드리지 않는다 — 그 파일은 brief 파이프라인의 줄 파서가 소유한다.

서브커맨드: init · begin-round · exempt-anchors · decide · fix · ask · defer · observe-diff · gate
전이 규칙의 정본은 plan(2026-09-06-document-review-engine.md)의 D13 표다.
"""
from __future__ import annotations

import argparse
import collections
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


GateRow = collections.namedtuple("GateRow", "name ledger pred open blocks render")

# ── 상태 축의 정본 ──────────────────────────────────────────────────────────
# 한 항목이 「열려 있는가(계보·stagnation) · 승인을 막는가 · 게이트에 보이는가」는
# 이 표 하나가 정한다. 설계 §6.4 「공통 뿌리 — 상태 축의 열거」: 같은 사실을 세 곳이
# 각자 열거하면 그 열거들이 어긋나고 어긋난 자리가 곧 fail-open 이다. 상태를 늘리는
# 사람은 이 표에 행을 더하고, 차단 행이면 렌더러 이름을 반드시 채운다 —
# test_docreview_gate_visibility.sh 가 「차단 집합 ⊆ 가시성 집합」을 별도 단언으로
# 재므로(Ruling 26/29 — C1 재발 방지: 가시성 코퍼스 등식 하나만으로는 이 포함관계를
# 안 잰다, 실측으로 걸렸다) 렌더러 없는 차단 행은 그 락에서 즉시 RED 다. 표 자체의
# 다섯 열(name·ledger·open·blocks·render) 이 흔들리는 것은 같은 락의 리터럴 증인
# 표(Ruling 29)가 잡는다.
#
# `render` 가 None 인 행은 «보이지 않아도 되는» 행이다. 오늘 그런 행은 없다 —
# 비차단 행도 승인 게이트가 한 번은 보여준다(설계 §8.2). None 을 남겨 두는 것은
# 미래에 정말로 안 보여도 되는 상태가 생겼을 때의 자리다.
GATE_ROWS = (
    GateRow("open_decide", "decides", lambda r: r["state"] == "open", True, True, "decide"),
    GateRow("adopted", "decides", lambda r: r["state"] == "adopted", True, True, "adopted"),
    GateRow("blocked_expired", "decides",
            lambda r: r["state"] == "expired" and not r.get("superseded_by"), True, True, "expired"),
    GateRow("superseded_expired", "decides",
            lambda r: r["state"] == "expired" and bool(r.get("superseded_by")), True, False, "superseded"),
    GateRow("held_decide", "decides", lambda r: r["state"] == "held", False, False, "held_decide"),
    GateRow("unapplied_fix", "fixes",
            lambda r: r["state"] in ("pending", "intent_passed"), True, True, "unapplied_fix"),
    GateRow("escalated_fix", "fixes", lambda r: r["state"] == "escalated", True, True, "escalated_fix"),
    GateRow("held_fix", "fixes", lambda r: r["state"] == "held", True, False, "held_fix"),
    GateRow("blocking_ask_open", "asks",
            lambda r: not r.get("answered") and bool(r.get("blocks")), True, False, "blocking_ask"),
    GateRow("ask_open", "asks",
            lambda r: not r.get("answered") and not r.get("blocks") and not r.get("from_decide"),
            False, False, "ask_open"),
)


def gate_bucket(st, row) -> list:
    return sorted(i for i, r in st[row.ledger].items() if row.pred(r))


def is_open(st, fid) -> bool:
    if fid not in st["findings"]:
        return False
    for row in GATE_ROWS:
        if not row.open:
            continue
        r = st[row.ledger].get(fid)
        if r is not None and row.pred(r):
            return True
    return False


def _is_reraise_successor(st, fid) -> bool:
    """이 id 를 `superseded_by` 로 가리키는 만료 항목이 있는가 — 즉 승계된 의무를 지는가."""
    return any(d.get("superseded_by") == fid for d in st["decides"].values())


# ── 선택지 축의 정본 (설계 §6.4 알려진 한계 (a)) ───────────────────────────────
# 상태 축(GATE_ROWS)이 「열려 있는가·막는가·보이는가」를 한 표로 모으듯, 이 함수쌍은
# 「이 decide 에 실제로 받아들여지는 재결정이 무엇인가」를 한 곳으로 모은다. 순수
# 부분(`_decide_choices_for`)과 원장을 읽는 래퍼(`decide_choices`)로 가른다 —
# [Task 4 fix round 1 — 리뷰 I1 정정] 원안은 래퍼 하나뿐이었고 `docreview_route.py`
# 의 `_decision_view` 는 "원장에 이 id 가 아직 없다"는 이유로 아예 안 썼다. 그런데
# 그 함수가 정말 못 보는 것은 **이 id 자신의 원장 레코드**뿐이다 — 승계 여부
# (`_is_reraise_successor`)는 전방 포인터가 **바로 그 직전 줄**(`_resolve_ids_and_
# lineage`)에서 이미 대상 레코드(원본, 이 id 가 아니다)에 찍히므로 라우팅 시점에도
# 계산 가능하고, 상태는 `record_findings` 가 몇 줄 뒤 무조건 "open" 으로 적을 값이라
# 호출부가 이미 알고 있다. 순수 부분을 갈라내면 `_decision_view` 는 원장을 몰라도
# `_decide_choices_for("open", _is_reraise_successor(st, it["id"]))` 로 같은 답을
# 낼 수 있다 — 선택지 로직은 여전히 한 곳(이 함수)뿐이고, `decide_choices`(원장
# 래퍼)는 원장에 없는 id 를 «open 인 셈 치는» 승격을 하지 않는다(그 승격은 나중에
# 진짜 모르는 상태를 감추는 쪽으로 작동한다 — 실패는 닫힌 채로 둔다).
def _decide_choices_for(state, is_successor) -> list:
    """선택지 계산의 순수 부분 — 원장 조회 없이 상태·승계 여부만 본다."""
    if state not in ("open", "expired"):
        return []
    if state == "expired" or is_successor:
        return ["adopt", "reject"]          # 보류 없음 — 의무를 넘길 자리가 없다
    return ["adopt", "reject", "hold"]


def decide_choices(st, fid) -> list:
    """이 항목에 «실제로 받아들여지는» 재결정 선택지 목록 — 원장에서 상태를 읽는 래퍼.
    `cmd_decide` 의 거부 술어와 `_rg_decide`(render_gate 의 「대안:」 줄)·`_rg_expired`
    가 이 래퍼를 쓴다. 원장에 id 가 아직 없으면(예: 이 라운드에 막 채번됐지만 아직
    `record_findings` 전인 id) 상태를 모른다 — `open` 으로 승격하지 않고 빈 리스트를
    낸다(fail-closed). 원장에 있다는 사실 없이 상태를 안다고 «주장»할 수 있는 유일한
    호출부는 `_decision_view` 하나뿐이고, 그 자리는 이 래퍼가 아니라 `_decide_choices_for`
    를 직접 쓴다(위 헤더 참조)."""
    d = st["decides"].get(fid)
    if d is None:
        return []
    return _decide_choices_for(d.get("state"), _is_reraise_successor(st, fid))


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
    # 수용 술어는 `decide_choices` 하나로 모은다(설계 §6.4 한계 (a)). rejected · held ·
    # applied 는 이미 누군가 의무를 졌거나 소멸한 것이라 다시 열지 않는다. adopted 도
    # 거부한다 — 그 라운드에 이미 연 permit 이 아직 관측을 기다리는 중이라, 다음
    # 라운드가 스스로 applied 나 expired 로 답한다(재결정할 대상이 아니라 결과를
    # 기다리는 중인 것뿐이다). open·expired 만 재결정을 받되(설계 §6.4 탈출구 — 후속이
    # 끝내 안 생기는 입력에 사용자의 길이 없으면 영구 차단이다), expired 와 재상승
    # 후속(승계된 의무를 진 open)은 「보류」가 빠진다 — 「보류」는 항목을 held 로 내려
    # 어떤 차단 목록에도 안 들게 만들어 «한 번의 보류로 승인이 열린다», expired 에선
    # 탈출구가 아니라 구멍이고 재상승 후속에선 그 구멍이 원본의 차단을 한 홉 건너에서
    # 푼다(§6.4 한계 (a) 그 자체 — 「만료라서 못 한다」와 「승계 의무를 지고 있어서 못
    # 한다」는 다른 사실이라 사유 리터럴도 갈린다).
    allowed = decide_choices(st, a.id)
    if not allowed:
        return fail("decide_not_open", id=a.id, state=d["state"])
    if a.choice not in allowed:
        if d["state"] == "expired":
            return fail("decide_hold_not_allowed_for_expired", id=a.id)
        return fail("decide_hold_not_allowed_for_reraise_successor", id=a.id)
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
    # 예약과 사용자 결정 중 «먼저 온 하나만» 후속을 만든다(설계 §6.4). 재결정이 왔으므로
    # 이 finding 의 미소비 예약은 폐기한다 — 안 그러면 뒤늦게 소비된 예약이 이미 처리된
    # 계보에 후속을 또 만들어 한 계보에 병렬 의무가 선다.
    st["reraise"] = [r for r in (st.get("reraise") or []) if r["finding_id"] != a.id]
    # 항목이 expired 를 벗어났다 — 낡은 포인터를 지운다(설계 §6.4 규칙②: 사용자
    # 재결정, 그 계보에 새 permit 이 열릴 때 포인터를 비운다). 안 그러면 이 재결정이
    # 다시 만료했을 때 옛 포인터가 그 새 만료를 조용히 풀어버린다.
    d.pop("superseded_by", None)
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
        reason = a.reason or "check-intent 거부"
        # [Fix round 1 — M7/Ruling 30] 원장(`st["escalated"]`)이 아니라 fix 레코드
        # 자신에도 사유를 남긴다 — 원장은 소비되면 비므로(Task 2) 렌더가 나중 라운드에
        # 읽을 자리가 없어진다(`_rg_escalated_fix` 참조).
        fx["escalate_reason"] = reason
        st["escalated"].append({"finding_id": a.id, "reason": reason, "round": n})
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
        d.pop("superseded_by", None)   # 이 만료 인스턴스는 끝났다 — 낡은 포인터가 다음 만료를 풀면 안 된다
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
    # 재상승 예약은 누적한다(설계 §6.4) — `finalize` 가 재상승 루프 전에 빠져나간 라운드의
    # 예약이 살아남아야 그것을 «소비하는» finalize 가 후속을 만든다. 대입으로 덮어쓰면
    # 다음 라운드 observe-diff 가 그 예약을 지워 후속이 영영 안 생긴다.
    # dedup 은 `finding_id` 로 한다 — 같은 계보에 라운드당 후속 하나(AC21).
    # 리뷰 R1(fix round 1) — 지금 CLI 경로로는 이 dedup 이 실제로 걸릴 상태를 만들 수
    # 없다: permit 은 `decision_id` 로 유일하고 한 번만(`consumed=True`) 처리되며, 같은
    # finding 이 다시 만료해도 그 후속은 `cmd_finalize` 의 id 배정 루프(`it["id"] = "%s#r%d.%d"`)가
    # 매번 새로 발급하는 id 를 쓰므로 `finding_id` 가 절대 겹치지 않는다(Task 3 의 재만료가
    # 실측 — 원 라운드 id 와 후속 라운드 id 는 항상 다르다). Task 4 의 만료 재결정 탈출구도
    # 같은 id 에 새 permit 을 여는 것과 그 id 의 미소비 예약을 폐기하는 것을 **같은 호출
    # 안에서 함께** 하므로(§`docreview_state.cmd_decide`, 그 사이 어떤 observe-diff 도
    # 끼어들 수 없다) 충돌이 생기지 않는다. 그래서 이 가드는 **지금 도달 가능한 상태를
    # 막는 살아있는 불변식이 아니라 defense-in-depth** 다 — [Task 4 fix round 1 정정]
    # 유일한 도달 경로는 픽스처(`st_open_permit.py`)로 `cmd_decide` 를 완전히 우회해
    # 같은 id 에 두 번째 permit 을 직접 여는 것이다. `record-findings` 재심기 뒤 실제
    # `cmd_decide` 로 재채택하는 경로(Task 2/3 원안)는 그 재채택 자체가 첫 예약을 먼저
    # 지워버려 이 상태에 이르지 못한다(`case_AC21_reraise_dedup` 이 이제 그 픽스처로 이
    # 상태를 만든다).
    pending = list(st.get("reraise") or [])
    seen = {p0["finding_id"] for p0 in pending}
    for r0 in reraise:
        if r0["finding_id"] in seen:
            continue
        pending.append(r0)
        seen.add(r0["finding_id"])
    st["reraise"] = pending
    _refresh_open_lineages(st, n)
    save_state(a.state_dir, st, "observe-diff applied=%d expired=%d" % (len(applied), len(expired)))
    _emit({"ok": True, "applied": applied, "expired": expired, "reraise": pending, "progress": r["progress"]})
    return 0


def gate_summary(st) -> dict:
    n = int(st["round"])
    rr = int(st["rereview_count"])
    fx = st["fixes"]
    asks = st["asks"]
    # 만료가 승인을 막는지는 «전방» 포인터 하나가 정한다(설계 §6.4). 역방향으로 세면
    # (「나를 가리키는 finding 이 있다」) 의무를 안 지는 후속 — 비차단 ask · drop ·
    # defer · 재비판 reject — 이 하나만 와도 차단이 풀린다. 라우터의 자동 계보 연결이
    # 지목 없는 finding 에도 supersedes 를 붙이기 때문이다. superseded_by 를 쓰는 곳은
    # 재상승 루프 하나뿐이라 그 기록은 의무의 증거다. 기록이 없으면 막는다 — fail-closed.
    g = {"round": n, "rereview_count": rr, "cap_reached": rr >= REREVIEW_CAP}
    for row in GATE_ROWS:
        g[row.name] = gate_bucket(st, row)
    g["asks_open"] = sorted(i for i, x in asks.items() if not x.get("answered"))
    g["defers"] = sorted(i for i, f in st["findings"].items() if f.get("disposition") == "defer")
    g["dropped"] = sorted(i for i, f in fx.items() if f["state"] == "dropped")
    g["extra_rounds"] = st["extra_rounds"]
    cur = st["rounds"].get(str(n), {})
    prev = st["rounds"].get(str(n - 1), {})
    g["stagnation"] = bool(n >= 2 and cur.get("open_lineages") and
                           cur.get("open_lineages") == prev.get("open_lineages") and int(cur.get("progress", 0)) == 0)
    g["approval_ready"] = not any(g[row.name] for row in GATE_ROWS if row.blocks)
    g["round_gate_needed"] = bool(g["open_decide"] or g["blocking_ask_open"])
    g["approval_gate_open"] = g["approval_ready"] or g["cap_reached"] or g["stagnation"]
    g["two_stage"] = g["approval_gate_open"] and not g["approval_ready"]
    g["next_round_mode"] = None if g["approval_ready"] else ("budget" if rr < REREVIEW_CAP else "extra_approval")
    rep = cur.get("route_report") or {}
    g["degrade"] = rep.get("degrade") or {}
    g["advisory"] = rep.get("advisory") or []
    g["counts"] = {k: rep.get(k, 0) for k in ("rejected", "bucket_conflicts", "lineage_mismatch",
                                              "revived", "reraise_unconsumed", "escalated_unconsumed")}
    g["counts"]["user_rejected"] = sum(1 for v in st["rejected_lineages"].values() if v.get("by") == "user")
    return g


_CHOICE_LABEL = {"adopt": "채택(적용)", "reject": "기각(원복)", "hold": "보류"}


def _post_kind_notice(d) -> str:
    """사후(`post`) 결정에만 붙는 고지 꼬리 — 「채택」이 원복 의무를 관측 없이
    종결한다는 뜻이 성립하는 «모든» 렌더러가 같은 문장을 낸다(설계 §6.4 — 규범
    문장은 렌더러가 아니라 그 뜻이 성립하는가에 묶인다). 리터럴은 여기 한 곳뿐 —
    `_rg_decide`·`_rg_expired` 둘 다 이 함수를 부른다. [fix round 1 — 리뷰 I1] 전엔
    `_rg_expired` 안에 인라인으로만 있어, 재상승 후속이 (이 태스크 이후) `post` 를
    물려받아도 그 후속이 아직 열린 decide 인 동안(`_rg_decide` 로 렌더되는 동안)은
    이 뜻이 사용자에게 안 닿았다 — §6.4 한계 (b) 의 절반이 렌더 축에서 그대로
    열려 있던 자리."""
    return " — 「채택」은 원복 의무를 관측 없이 종결한다" if d.get("kind") == "post" else ""


def _rg_decide(st, g, fid):
    # [Task 4 — §6.4 한계 (a)] 「대안:」 줄은 `dv.get("alternatives")`(docreview_route.py
    # `_decision_view` 의 상수 목록)가 아니라 `decide_choices` 로 낸다 — 그쪽은 라우팅
    # 시점(record_findings 이전)에 불려 이 id 를 못 보므로 여기가 «제안 = 수용» 이
    # 실제로 성립하는 유일한 자리다(위 `decide_choices` 헤더 코멘트). `dv` 는 변경·근거·
    # 영향 세 필드에는 여전히 쓴다 — 그 셋은 항목별 서술이라 선택지 축과 무관하다.
    f = st["findings"][fid]
    dv = f.get("decision_view") or {}
    alternatives = [_CHOICE_LABEL[c] for c in decide_choices(st, fid)]
    d = st["decides"].get(fid) or {}
    return ["[decide%s] %s — %s%s" % (" auto" if dv.get("auto") else "", fid, f.get("summary"), _post_kind_notice(d)),
            "  변경: %s" % dv.get("change", f.get("summary")),
            "  근거: %s" % dv.get("basis", f.get("evidence") or "—"),
            "  대안: %s" % " / ".join(alternatives),
            "  영향: %s" % dv.get("impact", f.get("anchor"))]


def _rg_adopted(st, g, fid):
    return ["[채택·미관측] %s — %s (다음 라운드 diff 가 적용을 관측해야 닫힌다)"
            % (fid, st["findings"][fid].get("summary"))]


def _rg_expired(st, g, fid):
    # [Task 4 fix round 1 — 리뷰 I4 정정] 예전엔 여기 "(채택 / 기각%s)" 를 직접
    # 하드코딩했다 — `_rg_decide` 를 고치면서 남긴 **두 번째, 안 이어진 열거**였다.
    # `decide_choices` 가 expired 에 항상 내는 값과 우연히 일치했을 뿐 그 함수를
    # 쓰지 않았으므로, 둘이 갈려도(예: `decide_choices` 가 언젠가 expired 에 대안
    # 선택지를 더 낸다면) 이 줄은 조용히 낡은 채로 남았을 것이다 — 이 태스크가
    # 닫으려던 「제안 ≠ 수용」이 형제 렌더러에 그대로 있었다. `decide_choices` 로
    # 통일한다(M3 부산물 — `_rg_decide` 와 라벨 어휘도 이제 같다).
    d = st["decides"].get(fid) or {}
    alt = " / ".join(_CHOICE_LABEL[c] for c in decide_choices(st, fid))
    return ["[만료·차단] %s — %s (%s%s)" % (fid, st["findings"][fid].get("summary"), alt, _post_kind_notice(d))]


def _rg_superseded(st, g, fid):
    d = st["decides"].get(fid) or {}
    return ["[만료·승계됨] %s → %s" % (fid, d.get("superseded_by"))]


def _rg_held_decide(st, g, fid):
    # [Fix round 1 — I3/Ruling 28] 원래 문구("승인 게이트에서 답하거나 기각한다")는
    # 실측으로 둘 다 거짓이었다 — `ask --answered` 는 이 항목을 안 닫고(hold 가 심은
    # ask 는 blocks 가 비어 있어 `cmd_ask` 의 unhold 루프가 아무 fix 도 안 건드리고,
    # decides 레코드는 여전히 state=="held" 로 남는다) `decide --choice reject` 는
    # `decide_not_open`(§`cmd_decide`, held 는 재결정 대상이 아니다)으로 거부된다.
    # §8.1 은 「보류」를 decide 를 ask 로 내리는 **사용자 자신의 선택**으로 규정하고
    # §8.2 는 그것을 승인 게이트의 「남은 ask 목록」에서 보여준다고만 한다 — 되돌리는
    # 절차는 설계에 없다. 그래서 사실만 적는다: 존재는 렌더되고 승인은 막지 않는다.
    # 새 전이를 만들지 않는다(룰링 28 — `decide --choice reject` 를 held 에 허용하는
    # 것은 spec 근거 없는 행동 변경이다).
    return ["[decide 보류] %s — %s (사용자가 보류했다 — 승인을 막지 않고, 승인 게이트의 남은 ask 목록에 보인다, §8.2)"
            % (fid, st["findings"][fid].get("summary"))]


def _rg_unapplied_fix(st, g, fid):
    return ["[미적용 fix] %s — %s (적용 예정 / drop)" % (fid, st["findings"][fid].get("summary"))]


def _rg_escalated_fix(st, g, fid):
    # [Fix round 1 — I2/M7/Ruling 27·30] `st["escalated"]` 는 소비되면 빈다(Task 2,
    # round>=n 수명) — 그 리스트를 스캔해 사유를 얻던 원래 코드는 소비 뒤 하드코딩
    # 기본값("check-intent 거부")으로 조용히 대체되어, `anchor_protected` 같은 진짜
    # 사유가 둘째 라운드부터 거짓 일반화됐다(M7 실측). 사유는 escalate 시점에
    # `cmd_fix`/`docreview_anchor.escalate()` 가 fix 레코드 자신에 `escalate_reason`
    # 으로 함께 남긴다(아래 두 자리) — 원장이 아니라 레코드에 있으므로 예약 소비와
    # 무관하게 남는다. 값이 없으면(도달 불가하지만) 있는 척 지어내지 않고 「사유
    # 불명」이라 말한다(룰링 30 — 그럴듯한 기본값을 지어내는 것은 모른다고 인정하는
    # 것보다 나쁘다). `escalated` 는 그대로 차단·가시 유지(룰링 27 — §6.4 한계 (c) 는
    # 비차단·비가시 둘 다를 결함으로 지목했다, 비차단으로 만드는 것은 수선이 아니다) —
    # 다만 `cmd_fix --event drop` 이 상태 가드 없이 이미 이 상태에서 동작하므로(AC23
    # 이 연 탈출구, 새 전이 아님) 렌더가 그 사실을 `_rg_unapplied_fix` 처럼 알려준다.
    fx = st["fixes"].get(fid) or {}
    why = fx.get("escalate_reason") or "사유 불명"
    return ["[fix 상향 대기] %s — %s (사유: %s, drop 하면 이 차단이 풀린다)"
            % (fid, st["findings"][fid].get("summary"), why)]


def _rg_held_fix(st, g, fid):
    return ["[fix 보류] %s — 전제 ask 미응답" % fid]


def _rg_blocking_ask(st, g, fid):
    f = st["findings"][fid]
    return ["[ask 비차단] %s — %s → 전제인 fix: %s"
            % (fid, f.get("summary"), ", ".join(f.get("blocks") or []))]


def _rg_ask_open(st, g, fid):
    return ["[ask] %s — %s" % (fid, st["findings"][fid].get("summary"))]


GATE_RENDERERS = {"decide": _rg_decide, "adopted": _rg_adopted, "expired": _rg_expired,
                  "superseded": _rg_superseded, "held_decide": _rg_held_decide,
                  "unapplied_fix": _rg_unapplied_fix, "escalated_fix": _rg_escalated_fix,
                  "held_fix": _rg_held_fix, "blocking_ask": _rg_blocking_ask, "ask_open": _rg_ask_open}


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
    for row in GATE_ROWS:
        fn = GATE_RENDERERS.get(row.render) if row.render else None
        if fn is None:
            continue
        for fid in g[row.name]:
            out.extend(fn(st, g, fid))
    c = g["counts"]
    out.append("기각 %d건(재비판) · 사용자 기각 %d · drop %d · bucket 충돌 %d · 계보 지목 불일치 %d · 기각 계보 재상승 %d · 미소비 재상승 예약 %d · 미소비 상향 예약 %d"
               % (c["rejected"], c["user_rejected"], len(g["dropped"]), c["bucket_conflicts"],
                  c["lineage_mismatch"], c["revived"], c["reraise_unconsumed"], c["escalated_unconsumed"]))
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


def cmd_gate_rows(a) -> int:
    print(json.dumps([{"name": r.name, "ledger": r.ledger, "open": r.open,
                       "blocks": r.blocks, "render": r.render} for r in GATE_ROWS],
                     ensure_ascii=False))
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
    x = sp.add_parser("gate-rows"); x.set_defaults(fn=cmd_gate_rows)
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
