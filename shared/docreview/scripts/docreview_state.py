#!/usr/bin/env python3
"""docreview_state.py — 문서 리뷰 엔진의 세션 라운드 원장 (leaf 모듈).

state 디렉토리는 **인자**(`--state-dir`)다. 호스트의 `state_path.py` 를 import 하지 않는다 —
두 호스트의 시그니처가 다르다(spec-distill: resolve_session_id+state_root(cwd) / quality-gates:
state_root(hook_input, hook_name)). 파일은 `<state-dir>/docreview-state.md` 하나이고
frontmatter 의 `docreview:` 트리가 원장, 본문은 사람이 읽는 사건 로그다. `state.local.md` 는
건드리지 않는다 — 그 파일은 brief 파이프라인의 줄 파서가 소유한다.

서브커맨드: state-dir-for · init · begin-round · exempt-anchors · decide · fix · ask · defer ·
observe-diff · gate
전이 규칙의 정본은 plan(2026-09-06-document-review-engine.md)의 D13 표다.

상태 디렉토리는 **문서별**이다 — 한 디렉토리의 원장(라운드 · 재리뷰 상한 · finding · permit ·
스냅샷)은 한 문서의 것이다. `state-dir-for` 가 세션 디렉토리와 문서 경로에서 그 자리를
도출하고, `init` 은 이미 있는 원장이 다른 문서(또는 다른 프로필)의 것이면 거부한다.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import os
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


if yaml is not None:
    class _UniqueKeyLoader(yaml.SafeLoader):
        """중복 키를 거절하는 SafeLoader. PyYAML 기본은 같은 키가 두 번 나오면 나중 값으로
        조용히 덮는다. codex 러너의 stdlib 파서는 모양이 다른 중복(`k: [a]` 뒤 `k:` + `- b`)
        에서 앞의 flow 값을 읽어, 같은 프로필을 두 파서가 다른 값으로 읽었다(실측, Task 3c
        R37). 중복 키가 있는 프로필은 이 로더가 진입에서 멈춘다. 러너는 이 로더를 쓰지 않는다
        (PyYAML 을 쓸 수 없다 — T6b) — 대신 허용 목록 줄 문법(러너의 `_parse_frontmatter`)만 받고
        그 밖의 모양과 중복 키에서 `profile_parse_ambiguous` 로 멈춘다. 두 쪽이 같은 값을 읽는다는
        보장은 그 문법의 범위(그 주석이 적는 것)까지이고, 배포 프로필은 러너·게이트 등식 대조
        (test_docreview_codex.sh)가 따로 잰다. 서로 다른 매핑의 같은 이름(`decision_log.heading` ·
        `defer_target.heading`)은 중복이 아니다 — 매핑마다 따로 센다."""

        def construct_mapping(self, node, deep=False):
            keys = [self.construct_object(k, deep=deep) for k, _v in node.value
                    if k.tag != "tag:yaml.org,2002:merge"]
            counts = collections.Counter(k for k in keys if isinstance(k, (str, int, float, bool)))
            dups = sorted(str(k) for k, c in counts.items() if c > 1)
            if dups:
                raise ProfileError("duplicate_key:%s" % ",".join(dups))
            return super().construct_mapping(node, deep=deep)


def _safe_load_unique(text):
    loader = _UniqueKeyLoader(text)
    try:
        return loader.get_single_data()
    finally:
        loader.dispose()


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


def _str_list(v, field, regex=True):
    if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
        raise ProfileError("field_not_str_list:%s" % field)
    if regex:
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
    data = _safe_load_unique(fm) or {}
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
    lr_extra = [k for k in lr if k not in ("layer1", "layer2")]
    if lr_extra:
        raise ProfileError("layer_rubric_fields_unknown:%s" % ",".join(lr_extra))
    # 층 항목은 문자열이다 — 러너도 문자열 목록이 아니면 멈춘다(한 판정, Task 3c R43). 층 범주명은
    # 정규식이 아니므로 컴파일하지 않는다 — 러너는 문자열이면 그대로 싣는다(`"c++"` 를 게이트만
    # `bad_regex` 로 거절하던 반대 방향 발산).
    _str_list(lr["layer1"], "layer_rubric.layer1", regex=False)
    _str_list(lr["layer2"], "layer_rubric.layer2", regex=False)
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
    # 본문(검토 항목)은 탐지·재비판 agent 와 codex 러너가 함께 읽는 루브릭이다. 러너는 빈
    # 본문이면 `profile_body_empty` 로 fail-closed 한다 — 게이트도 같은 판정을 낸다(한 판정).
    if not body.strip():
        raise ProfileError("profile_body_empty")
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


# ── 라운드 diff — 원장의 라운드별 스냅숏으로 엔진이 계산한다 ──────────────────────────────
# 얼림 검사와 permit · fix 적용 관측이 읽는 diff 는 오케스트레이터가 쓰는 파일이 아니다. 두 입력 — 직전 · 이번
# 라운드 스냅숏(`begin-round` 가 원장에 저장한다) — 과 면제 집합의 재료(`applied_scopes` · `permits` · 프로필)가
# 전부 원장에 있으므로 엔진이 계산한다. `docreview_anchor.py diff` CLI 도 같은 `diff_snapshots` 를 부른다.
DOC_ANCHOR = "#__doc__"


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


class LedgerCorrupt(Exception):
    """원장이 관측 · 얼림 검사에 필요한 것을 갖지 않는다(상태 파손) — 이름 있는 실패. 빈 diff 로 넘어가지 않는다."""

    def __init__(self, reason, **extra):
        super().__init__(reason)
        self.reason = reason
        self.extra = extra


def _snapshot_ok(snap) -> bool:
    if not isinstance(snap, dict) or not isinstance(snap.get("sections"), list):
        return False
    return all(isinstance(s, dict) and isinstance(s.get("anchor"), str) and isinstance(s.get("hash"), str)
               and "title" in s for s in snap["sections"])


def snapshot_at(st, k) -> dict:
    """원장의 라운드 k 스냅숏 — 없거나 모양이 틀리면 `snapshot_missing`."""
    snap = (st.get("snapshots") or {}).get(str(k))
    if not _snapshot_ok(snap):
        raise LedgerCorrupt("snapshot_missing", round=k)
    return snap


PERMIT_KINDS = ("apply", "revert")


def _permit_fields(did, p):
    """permit 의 (라운드, 종류, 앵커 목록, finding id) — 모양이 틀리면 `permit_corrupt`. 관측과 면제가 같은 판정을 쓴다."""
    try:
        k, kind, anchors, fid = int(p["round"]), p["kind"], p["apply_anchors"], p["finding_id"]
    except (TypeError, KeyError, ValueError):
        raise LedgerCorrupt("permit_corrupt", decision_id=did)
    if (kind not in PERMIT_KINDS or not isinstance(anchors, list) or not anchors
            or not all(isinstance(x, str) for x in anchors)):
        raise LedgerCorrupt("permit_corrupt", decision_id=did)
    return k, kind, anchors, fid


def exempt_scopes(st, prof, r) -> list:
    """라운드 r 의 얼림 면제 집합(설계 §7 예외 ①②③) — 라운드 r−1 에 통과한 fix 의 범위 ∪ 라운드 r 의 **모든**
    permit 앵커 ∪ 프로필 `decision_log` · `defer_target` 절의 헤딩 앵커. permit 은 소비 여부와 무관하다: 라운드 r 의
    diff 가 정의되는 시점(라운드 r 시작)에는 전부 미소비였고, `finalize` 는 관측으로 소비한 **뒤** 얼림 diff 를
    계산하므로 소비된 permit 을 빼면 허가된 편집이 `frozen_change` 로 둔갑한다."""
    out = []
    for i, s in enumerate(st.get("applied_scopes") or []):
        try:
            sr, scope = int(s["round"]), s["scope"]
        except (TypeError, KeyError, ValueError):
            raise LedgerCorrupt("applied_scope_corrupt", index=i)
        if not isinstance(scope, str):
            raise LedgerCorrupt("applied_scope_corrupt", index=i)
        if sr == r - 1:
            out.append(scope)
    for did, p in (st.get("permits") or {}).items():
        k, _kind, anchors, _fid = _permit_fields(did, p)
        if k == r:
            out.extend(anchors)
    for key in ("decision_log", "defer_target"):
        t = prof[key]
        if t.get("kind") == "doc_section":
            out.append(heading_anchor(t["heading"]))
    return sorted(set(out))


def round_diff(st, prof, r) -> dict:
    """라운드 r 의 얼림 diff — 원장의 스냅숏 r−1 → r 와 그 라운드의 면제 집합. 스냅숏이 없으면 `snapshot_missing`."""
    snaps = st.get("snapshots") or {}
    for k in (r - 1, r):
        if not _snapshot_ok(snaps.get(str(k))):
            raise LedgerCorrupt("snapshot_missing", round=k, diff_round=r)
    return diff_snapshots(snaps[str(r - 1)], snaps[str(r)], exempt_scopes(st, prof, r))


# ── 문서의 정체 · 문서별 상태 디렉토리 ────────────────────────────────────────
# 문서의 정체는 경로다(훅이 경로로 arm 한다). 비교와 디렉토리 도출은 **같은 정규화**
# 하나를 쓴다 — 절대경로 + 심볼릭 링크 해석(`realpath`). 둘이 다른 정규화를 쓰면 같은
# 문서를 다른 표기로 불렀을 때 같은 디렉토리에 앉고도 `init` 이 거부하거나, 그 반대가 된다.
STATE_SUBDIR = "docreview"
_KEY_UNSAFE = re.compile(r"[^A-Za-z0-9._-]+")
_SESSION_OK = re.compile(r"[A-Za-z0-9_-]+")


def doc_identity(doc) -> str:
    return os.path.realpath(doc)


def profile_identity(profile) -> str:
    """프로필의 정체는 이름(파일 stem)이다 — 경로가 아니다. 플러그인 루트가 옮겨져도(버전
    캐시) 같은 프로필은 같은 프로필이다. 호스트마다 상태 루트가 따로라 다른 호스트의 같은
    이름 프로필이 한 디렉토리에서 만나지 않는다."""
    return Path(profile).stem


def state_dir_for(root, session, doc) -> Path:
    """`<root>/<session>/docreview/<이름표>-<정체 해시 16자>` — 세션과 문서 경로의 순수 함수.
    이름표는 사람이 읽으라고 붙인 파일 stem 이고 유일성은 해시가 진다."""
    ident = doc_identity(doc)
    label = _KEY_UNSAFE.sub("-", Path(ident).stem).strip("-.")[:40] or "doc"
    digest = hashlib.sha256(os.fsencode(ident)).hexdigest()[:16]
    return Path(root) / session / STATE_SUBDIR / ("%s-%s" % (label, digest))


# ── 서브커맨드 ───────────────────────────────────────────────────────────
def cmd_state_dir_for(a) -> int:
    # 상대 루트·상대 문서는 cwd 의 함수고(같은 문서가 cwd 마다 다른 자리로 간다), 빈 세션은
    # 루트 바로 아래 자리다. 세션은 경로의 한 성분이라 `[A-Za-z0-9_-]+` 밖(구분자·점·제어
    # 문자)은 받지 않는다 — 개행이 든 세션은 두 줄 경로를 낸다. 전부 거부한다.
    if not a.root or not os.path.isabs(a.root):
        return fail("root_not_absolute", root=a.root)
    if not a.session or not _SESSION_OK.fullmatch(a.session):
        return fail("session_invalid", session=a.session)
    if not a.doc:
        return fail("doc_empty")
    if not os.path.isabs(a.doc):
        return fail("doc_not_absolute", doc=a.doc)
    print(state_dir_for(a.root, a.session, a.doc))
    return 0


def cmd_init(a) -> int:
    if yaml is None:
        return fail("pyyaml_missing")
    try:
        load_profile(a.profile)
    except ProfileError as e:
        return fail("profile_invalid", detail=str(e))
    # 빈 값은 `Path("")` = cwd 가 되어 cwd 에 원장을 만든다 — 없는 디렉토리로 친다.
    if not a.state_dir:
        return fail("state_dir_missing", state_dir=a.state_dir)
    # 문서의 정체(realpath)가 cwd 의 함수가 되면 같은 문서가 cwd 마다 다른 문서로 읽힌다.
    if not a.doc or not os.path.isabs(a.doc):
        return fail("doc_not_absolute", doc=a.doc)
    d = Path(a.state_dir)
    if not d.is_dir():
        return fail("state_dir_missing", state_dir=str(d))
    p = state_path(d)
    if p.is_file():
        st = load_state(d)
        # 다른 문서의 원장을 이어받으면 그 문서의 라운드·재리뷰 상한·finding·permit·
        # 스냅샷이 이 문서에 섞인다. 거부는 원장을 건드리지 않는다.
        have = st.get("doc")
        if not isinstance(have, str) or doc_identity(have) != doc_identity(a.doc):
            return fail("state_doc_mismatch", state_dir=str(d), state_doc=have, requested_doc=a.doc)
        have = st.get("profile")
        if not isinstance(have, str) or profile_identity(have) != profile_identity(a.profile):
            return fail("state_profile_mismatch", state_dir=str(d), state_profile=have,
                        requested_profile=a.profile)
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
    # 라운드 시작 표식 — codex · critic 산출물이 이보다 먼저 쓰였으면 직전 라운드 것이다
    # (`docreview_route._round_staleness`). 프로세스 시계가 아니라 방금 쓴 상태 파일의
    # mtime 을 쓴다: 같은 디렉토리의 codex 파일도 같은 파일시스템 시계로 찍히므로 해상도가
    # 같은 눈금이다.
    st["rounds"][str(n)]["started_mtime_ns"] = state_path(a.state_dir).stat().st_mtime_ns
    save_state(a.state_dir, st)
    _emit({"ok": True, "round": n, "rereview_count": rr})
    return 0


# ── 전이 ────────────────────────────────────────────────────────────────
PUBLIC_FIELDS = ("id", "lineage", "bucket", "supersedes", "origin", "layer", "category", "anchor",
                 "disposition", "summary", "edit_scope", "blocks", "evidence",
                 # 갈래 2 — top-level 이다. `decision_view` 통로는 disposition == "decide"
                 # 에만 열리므로(docreview_route.py `_remap_blocks` 의
                 # `if it["disposition"] == "decide":` 게이트) 그쪽에만
                 # 실으면 fix·defer·ask 로 난 항목의 대체안이 원장에 한 글자도 안 남는다.
                 "replacement", "if_unfixed",
                 "decision_view", "state", "promotion", "promoted_from", "immutable", "kind")


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
    """이번 라운드의 얼림 면제 집합(`exempt_scopes` 의 현재 라운드 값)."""
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    try:
        out = exempt_scopes(st, prof, int(st["round"]))
    except LedgerCorrupt as e:
        return fail(e.reason, **e.extra)
    print(json.dumps(out, ensure_ascii=False))
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


def observe_ledger(st, prof, n) -> dict:
    """라운드 n 에서 permit · fix 의 적용을 관측한다 — `observe-diff` CLI 와 `finalize` 가 함께 쓰는 한 함수.

    `round ≤ n` 인 미소비 permit 전부를 각자 **자기 라운드**의 diff(`round_diff(st, prof, p.round)`)로 본다 — 관측을
    건너뛴 라운드(critic 사망으로 6~7단계를 건너뛴 라운드 · finalize 가 거부된 라운드)의 permit 을 뒤 라운드가 그
    라운드의 스냅숏 쌍으로 따라잡는다. `apply` 는 앵커가 그 diff 에 닿았는가, `revert` 는 그 permit 라운드 스냅숏의
    앵커 해시가 `expect_hash` 와 같은가. `intent_passed` fix 도 같다 — 라운드 r(< n)에 통과한 것을 `round_diff(r+1)`
    로 본다. 관측 없이는 만료하지 않는다(R70): 필요한 스냅숏이 없거나 permit 이 파손이면 `LedgerCorrupt` 로 멈추고,
    호출자는 저장하지 않으므로 아무것도 소비되지 않는다.

    따라잡은 `applied` 는 관측한 라운드(n)의 `progress` 로 센다(선택) — stagnation 입력(설계 §8.4)은 「이번 라운드에
    진행이 관측됐는가」이고, 지난 라운드 자리에 적으면 이번 라운드가 진행 0 으로 읽혀 거짓 stagnation 이 선다.

    관측할 것이 없으면 원장을 바꾸지 않는다(`observed` 거짓) — 같은 라운드에 두 번 불려도 둘째는 무동작이다.
    """
    r = st["rounds"].setdefault(str(n), {"open_lineages": [], "progress": 0, "route_report": None})
    touched_at = {}

    def touched(k):   # 라운드 k 의 diff 가 닿은 앵커 — 라운드마다 한 번 계산한다
        if k not in touched_at:
            diff = round_diff(st, prof, k)
            t = {c["anchor"] for c in diff.get("changed", [])}
            t |= {e["anchor"] for e in diff.get("exempt_applied", [])}
            t |= {e["scope"] for e in diff.get("exempt_applied", []) if e.get("scope")}
            touched_at[k] = t
        return touched_at[k]

    applied, expired, reraise = [], [], []
    for did, p in st["permits"].items():
        k, kind, anchors, fid = _permit_fields(did, p)
        if p.get("consumed") or k > n:
            continue
        d = st["decides"].get(fid)
        if not d:
            continue
        if kind == "apply":
            hit = any(x in touched(k) for x in anchors)
        else:
            cur = {s["anchor"]: s["hash"] for s in snapshot_at(st, k)["sections"]}
            hit = cur.get(anchors[0]) == p.get("expect_hash")
        p["consumed"] = True
        d.pop("superseded_by", None)   # 이 만료 인스턴스는 끝났다 — 낡은 포인터가 다음 만료를 풀면 안 된다
        if hit:
            d["state"] = "applied"
            r["progress"] += 1
            applied.append(fid)
        else:
            d["state"] = "expired"
            expired.append(fid)
            reraise.append({"finding_id": fid, "kind": kind,
                            "reason": "라운드 %d 에 %s 변경 관측 없음 (%s)" % (
                                k, "원복" if kind == "revert" else "채택", did)})
    for fid, fx in st["fixes"].items():
        if fx.get("state") != "intent_passed":
            continue
        try:
            fr = int(fx["round"])
        except (TypeError, KeyError, ValueError):
            raise LedgerCorrupt("fix_corrupt", id=fid)
        if fr < 1:
            raise LedgerCorrupt("fix_corrupt", id=fid)
        if fr < n and fx.get("scope") in touched(fr + 1):
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
    return {"applied": applied, "expired": expired, "reraise": pending, "observed": bool(applied or expired)}


def cmd_observe_diff(a) -> int:
    """이번 라운드의 permit · fix 적용 관측(`observe_ledger`). diff 는 원장의 스냅숏으로 엔진이 계산한다 — 인자가 없다.

    관측한 것이 있을 때만 원장을 쓴다. 필요한 스냅숏이 없거나 permit 이 파손이면 그 이름으로 rc 1 이고 원장은
    그대로다(아무것도 소비되지 않는다)."""
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    n = int(st["round"])
    try:
        obs = observe_ledger(st, prof, n)
    except LedgerCorrupt as e:
        return fail(e.reason, **e.extra)
    if obs["observed"]:
        _refresh_open_lineages(st, n)
        save_state(a.state_dir, st, "observe-diff applied=%d expired=%d" % (len(obs["applied"]), len(obs["expired"])))
    _emit({"ok": True, "applied": obs["applied"], "expired": obs["expired"], "reraise": obs["reraise"],
           "progress": st["rounds"][str(n)]["progress"]})
    return 0


# ── 「미검증」 라운드 — 이번 라운드의 판정이 원장에 없다는 사실 (설계 §9 degrade 표 critic 사망 행) ──
# 엔진이 이 사실을 스스로 안다. 같은 턴 모델의 기억에 맡기면 다음 턴·compact 뒤에는 그 라운드가
# 리뷰된 것처럼 보인다. 사유 키는 둘이다 — `critic_dead`(주 판정자 doc-critic 사망) ·
# `finalize_incomplete`(7단계 라우팅이 끝나지 않았다). 읽는 자리는 셋이고 전부 라운드 번호에 묶인다:
#   · `pending_recritic` — 5단계 `prepare-recritic` 이 `round` 와 함께 쓰고 7단계 `finalize` 의 성공만
#     지운다. 이번 라운드의 것이 남아 있으면 라우팅이 끝나지 않았고, 그 `degrade.critic_dead` 가
#     사유를 가른다(critic 이 두 번 죽으면 5단계가 6~7단계를 건너뛰어 이 상태로 게이트에 온다).
#   · `rounds[n].finalize_failed` — 준비가 없거나 다른 라운드 것이라 `finalize` 가 거부할 때 남긴다.
#   · `rounds[n].route_report.degrade.critic_dead` — critic 이 죽은 채 finalize 한 라운드(`fin.json` 의
#     `blocks` 참)다.
# 다음 라운드는 제 자리(`rounds[n+1]`, 새 준비)를 쓰므로 그 라운드가 정상으로 끝나면 표지가 풀린다.
UNVERIFIED_LABEL = "미검증"
UNVERIFIED_TEXT = {
    "critic_dead": "「미검증」 주 판정자(doc-critic) 사망 — 이 라운드는 리뷰되지 않았다",
    "finalize_incomplete": "「미검증」 라우팅(finalize) 미완 — 이 라운드의 finding 이 원장에 없다",
}
# 「미검증」 사유가 없어도 이번 라운드의 finalize 보고서가 없으면 `round_reviewed` 는 거짓이다(양의 증거).
# 그 라운드는 라벨 없이 공시만 한다 — 「미검증」(라벨 · 승인 게이트 강제)과 다른 공시 사유 `unrouted`.
# 5단계가 rc 0·4 밖으로 끝나고 7단계를 건너뛴 라운드가 여기 온다(Task 7b fix, R54).
UNROUTED_TEXT = "리뷰 완료 아님 — 이번 라운드의 라우팅 보고서가 없다(finalize 를 거치지 않았다)"


def pending_mismatch(st, n):
    """`pending_recritic` 이 라운드 n 의 준비가 아닐 사유 — 라운드 n 의 것이면 None.

    라운드 번호가 없거나 정수가 아니면 어느 라운드 것인지 가를 수 없다(`pending_round_unrecorded`).
    `finalize` 는 이 사유가 있으면 소비하지 않고, `round_unverified` 는 번호 없는 준비를 이번
    라운드의 미완 준비로 친다 — 양쪽 다 닫힌 쪽이다."""
    p = st.get("pending_recritic")
    if not isinstance(p, dict):
        return "no_pending_recritic"
    r = p.get("round")
    if isinstance(r, bool) or not isinstance(r, int):
        return "pending_round_unrecorded"
    if r != n:
        return "pending_recritic_stale"
    return None


def _pending_here(st, n):
    return st["pending_recritic"] if pending_mismatch(st, n) in (None, "pending_round_unrecorded") else None


def round_unverified(st):
    """이번 라운드를 엔진이 「미검증」으로 아는 사유 키(`critic_dead` · `finalize_incomplete`), 아니면 None."""
    n = int(st["round"])
    p = _pending_here(st, n)
    if p is not None:
        deg = p.get("degrade") if isinstance(p.get("degrade"), dict) else {}
        return "critic_dead" if deg.get("critic_dead") else "finalize_incomplete"
    cur = (st.get("rounds") or {}).get(str(n)) or {}
    if cur.get("finalize_failed"):
        return "finalize_incomplete"
    rdeg = (cur.get("route_report") or {}).get("degrade")
    if isinstance(rdeg, dict) and rdeg.get("critic_dead"):
        return "critic_dead"
    return None


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
    unv = round_unverified(st)
    g["approval_ready"] = not any(g[row.name] for row in GATE_ROWS if row.blocks)
    g["round_gate_needed"] = bool(g["open_decide"] or g["blocking_ask_open"])
    # 「미검증」 라운드는 승인 게이트를 그 라벨로 연다(설계 §9 — critic 사망 두 번). 열린 것이 남아
    # 있으면 stagnation 과 같이 두 단계다(아래 `two_stage`).
    g["approval_gate_open"] = g["approval_ready"] or g["cap_reached"] or g["stagnation"] or bool(unv)
    # 상한 도달이면 열린 것이 0 이어도 두 단계다(Park P3·D-U3) — 1단계가 「추가 라운드
    # 1회 열기」(§8.2)를 실어야 하고, 그 문구가 성립하려면 `next_round_mode` 가
    # `extra_approval` 이어야 한다(`approval_ready` 와 무관). 상한 전(`cap_reached`
    # False)은 이 조건이 원래 식으로 접혀 동작이 그대로다 — `budget`/`None` 분기는
    # 손대지 않는다.
    g["two_stage"] = g["cap_reached"] or (g["approval_gate_open"] and not g["approval_ready"])
    g["next_round_mode"] = ("extra_approval" if g["cap_reached"]
                             else (None if g["approval_ready"] else "budget"))
    rep = cur.get("route_report") or {}
    # finalize 가 끝나지 않은 라운드는 보고서가 없다 — 그 라운드 준비의 degrade(codex 부재 등)를 싣는다.
    pend = _pending_here(st, n)
    pdeg = pend.get("degrade") if pend is not None and isinstance(pend.get("degrade"), dict) else None
    g["degrade"] = rep.get("degrade") or pdeg or {}
    g["advisory"] = rep.get("advisory") or []
    # 「미검증」 — 사유 키 · 승인 게이트 라벨(정본은 이 출력, 진입 skill 이 읽는다) · 완료 기록 신호.
    # `round_reviewed` 는 양의 증거를 요구한다: 이번 라운드의 finalize 보고서가 있고 「미검증」이 아닐
    # 때만 참이다 — finalize 를 거치지 않은 라운드는 사유가 없어도 완료로 기록되지 않는다.
    g["unverified"] = unv
    g["approval_label"] = UNVERIFIED_LABEL if unv else None
    g["round_reviewed"] = bool(cur.get("route_report")) and unv is None
    # 공시 사유 — `round_reviewed` 가 거짓인 모든 라운드에 선다. 「미검증」이면 그 사유 키, 아니면 `unrouted`.
    g["unreviewed_reason"] = None if g["round_reviewed"] else (unv or "unrouted")
    g["counts"] = {k: rep.get(k, 0) for k in ("rejected", "bucket_conflicts", "lineage_mismatch",
                                              "revived", "reraise_unconsumed", "escalated_unconsumed")}
    g["counts"]["user_rejected"] = sum(1 for v in st["rejected_lineages"].values() if v.get("by") == "user")
    return g


# category 의 사람말 — 렌더가 쓰는 유일한 자리. 코퍼스는 네 프로필(brief · design-doc ·
# seed · generic)의 층 1·2 축 전부 + 엔진이 직접 만드는 category 다. 렌더는 프로필별이
# 아니라 엔진 하나이므로 두 프로필로 좁히면 가장 흔한 항목(frozen_change)이 상시
# advisory 경로가 된다. `shared/tests/test_docreview_profile_schema.sh` 가 «프로필에서
# 도출한 이름 전부에 사상이 있는가»를 ∀ 로 재므로, 새 축이 사상 없이 들어오면 RED 다.
CATEGORY_GLOSS = {
    # brief · design-doc 공유 층 1
    "overdesign": "goal 대비 과함",
    # brief 층 1·2
    "direction": "방향의 반증", "distortion": "원문의 뜻이 바뀜",
    "omission": "원문에 있는 것이 빠짐", "invention": "원문에 없는 것이 들어옴",
    "provenance_mislabel": "출처 표기가 틀림", "authority_syntax": "열린 것을 확정으로 못박음",
    "evidence_unsupported": "근거가 요약을 안 받침",
    # design-doc 층 1·2
    "goal_fit": "목표가 다른 것을 겨눔", "problem_definition": "문제 정의가 어긋남",
    "scope": "범위가 넓어지거나 좁아짐", "architecture": "확정 제약 위반",
    "component_relations": "의존 방향이 안 닫힘", "data_flow": "데이터가 끊김",
    "tradeoffs": "기각 사유가 확정과 모순", "feasibility": "단정한 리포 사실이 없음",
    "placeholder": "TBD·빈 절", "ambiguity": "두 가지로 읽힘",
    "scope_creep": "분해 안 되는 묶음", "approaches_comparison": "대안 비교 없는 단정",
    "isolation": "컴포넌트 경계가 흐림", "testing": "검증 전략 부재",
    "handoff_incomplete": "이어갈 컨텍스트 부족",
    # seed 층 1
    "unfounded_addition": "원문에 없는 요구가 더해짐", "example_as_requirement": "예시가 요구로 승격됨",
    "premature_closure": "열어 둔 선택이 닫힘", "inference_as_decision": "추론이 결정처럼 쓰임",
    # generic 층 1·2
    "logic": "결론이 전제에서 안 따라 나옴", "assumption": "말해지지 않은 전제",
    "completeness": "약속하고 안 채운 자리", "evidence": "근거 없는 단정",
    "actionability": "무엇을 할지 알 수 없음", "structure": "목차와 본문의 불일치",
    # 엔진이 직접 만드는 것
    "frozen_change": "얼림 검사가 잡은 변경", "other": "분류 없음",
}


def category_gloss(cat):
    """사람말 또는 None. **없으면 조용히 빈칸으로 두지 않는다** — 부르는 쪽이
    원래 이름을 그대로 내고 그 사실을 렌더에 한 줄로 공시한다."""
    return CATEGORY_GLOSS.get(cat)


# 선택지 라벨은 **상태의 함수**다. `cmd_decide` 가 kind=post 에서 reject 에 revert
# permit 을 만드므로(위 `cmd_decide` 의 post 분기 — `kind: "revert"` permit 을 여는
# 자리) 고정 라벨을 사람말로 바꾸면 그 자리에서 «동작을 반대로 설명»하게 된다.
# 회계어(채택·기각·보류)는 괄호 안에 그대로 보존한다 — 낱말을 바꾸는 것이 아니라
# 사람말을 앞에 두는 것이다.
_CHOICE_LABEL = {
    "pre":  {"adopt": "고친다(채택)",        "reject": "그대로 둔다(기각)",      "hold": "나중에 정한다(보류)"},
    "post": {"adopt": "현재 변경 유지(채택)", "reject": "이전 상태로 원복(기각)", "hold": "나중에 정한다(보류)"},
}


def choice_label(choice, kind) -> str:
    """선택지 라벨 — 리터럴이 사는 유일한 자리. `kind` 가 없으면 `pre` 로 읽는다
    (`record_findings` 가 기록 시점에 `it.get("kind") or "pre"` 로 강제하므로
    원장에서 온 값은 항상 둘 중 하나다 — None 은 원장 밖 호출부에서만 온다)."""
    return _CHOICE_LABEL.get(kind or "pre", _CHOICE_LABEL["pre"])[choice]


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
    # [Task 4 — §6.4 한계 (a)] 「대안:」 줄은 `dv.get("alternatives")` 가 아니라
    # `decide_choices` 로 낸다 — 그쪽은 라우팅 시점에 이 id 를 못 보므로 여기가
    # «제안 = 수용» 이 실제로 성립하는 유일한 자리다. `dv` 는 항목별 서술 네 필드에
    # 여전히 쓴다.
    # [갈래 2] 「변경」이 사라지고 「그대로 두면 / 고치면」 둘로 갈린다 — 헤더가 이미
    # 「무엇이 문제인가」를 내므로 동어반복이 원리적으로 불가능해진다. 「영향」은
    # 「자리」다(anchor + 인용수는 영향이 아니라 위치다). **「대안」 줄은 조건부로
    # 내지 않는다** — 그 줄이 `cases.sh` 의 「제안 = 수용」 락의 발동 조건이고,
    # 형제 `_rg_expired` 가 똑같은 실패를 이미 한 번 고쳤다.
    f = st["findings"][fid]
    dv = f.get("decision_view") or {}
    d = st["decides"].get(fid) or {}
    alternatives = [choice_label(c, d.get("kind")) for c in decide_choices(st, fid)]
    lines = ["[decide%s] %s — %s%s" % (" auto" if dv.get("auto") else "", fid, f.get("summary"), _post_kind_notice(d)),
             "  그대로 두면: %s" % dv.get("if_unfixed", f.get("if_unfixed") or "(리뷰어가 안 적음)"),
             "  고치면: %s" % dv.get("replacement", f.get("replacement") or "(대체안 미작성)"),
             "  근거: %s" % dv.get("basis", f.get("evidence") or "—"),
             "  자리: %s" % dv.get("impact", f.get("anchor")),
             "  대안: %s" % " / ".join(alternatives)]
    # 사람말이 없는 category 는 원래 이름으로 나가되 그 사실을 «말한다». 조용히
    # 빈칸으로 두면 사상이 낡았다는 것이 아무 데도 안 남는다(D13-③ 이 안 닫힌다).
    if dv.get("category_unglossed"):
        lines.append("  ↳ 사람말 사상 없음: %s — 원래 이름 그대로 낸다" % dv["category_unglossed"])
    return lines


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
    alt = " / ".join(choice_label(c, d.get("kind")) for c in decide_choices(st, fid))
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
    # 첫 줄 = 그 라운드의 degrade 공시. 「미검증」이면 주 판정자 사망 · 라우팅 미완을 맨 앞에 싣는다 —
    # 그 라운드에 「degrade 없음」이 나올 수 없다.
    first = []
    if g.get("unverified"):
        first.append(UNVERIFIED_TEXT.get(g["unverified"], "「미검증」 (%s)" % g["unverified"]))
    elif g.get("unreviewed_reason"):
        first.append(UNROUTED_TEXT)
    if deg.get("codex_absent"):
        first.append("codex 없음 — 모델 다양성 0 (%s)" % (deg.get("codex_reason") or "?"))
    elif g["advisory"]:
        first.append("degrade: " + " · ".join(g["advisory"]))
    out.append(" ; ".join(first) if first else "degrade 없음")
    ag = "승인 게이트" + ("(「%s」)" % g["approval_label"] if g.get("approval_label") else "")
    out.append("라운드 %d · 재리뷰 %d/%d%s%s" % (g["round"], g["rereview_count"], REREVIEW_CAP,
                                              " · 상한 도달" if g["cap_reached"] else "",
                                              " · stagnation" if g["stagnation"] else ""))
    # [Task 9 ⓓ] GATE_ROWS 10행의 순서는 이미 결정론이지만 «상태 범주» 순이라 그
    # 뜻이 안 보였다. 순위를 새로 매기지 않는다 — 오케스트레이터가 순위를 매기면
    # 그 순위 자체가 판단이고 사용자가 그 위험을 받아들인다고 말한 적이 없다.
    # 있는 순서의 뜻만 낸다. 이 한 줄의 내용은 GATE_ROWS 의 순서에서 읽는다 —
    # 구절 ↔ 행(`.name`) 대응은 다음과 같다:
    #   열린 결정        → open_decide
    #   그다음 관측 대기  → adopted (그 렌더러 자신이 "다음 라운드 diff 가 적용을
    #                       관측해야 닫힌다" 고 말한다 — _rg_adopted)
    #   막힌 것          → blocked_expired · superseded_expired
    #   미적용 수정       → unapplied_fix · escalated_fix · held_fix
    #   질문             → blocking_ask_open · ask_open
    # 「미적용 수정」은 fixes 원장 세 행(6·7·8) 전체를 하위 상태와 무관하게
    # 뜻으로 묶는다 — pending/intent_passed 든 escalated 든 held 든, 셋 다
    # 「아직 적용되지 않은 fix」라는 사실은 같다(적용됐으면 애초에 이 원장에
    # 안 남는다). held_fix 가 여기 들어가는 것은 held_fix 만의 특별 취급이
    # 아니라 이 구절이 «상태 무관·원장 전체»를 가리키기 때문이다.
    # [Task 9 정정] held_decide 가 다섯 구절 밖인 이유는 그래서 "보류
    # 라는 개념은 어느 구절도 못 담는다"가 아니다 — held_fix 가 바로 그 반례다.
    # 진짜 이유는 더 좁다: decides 원장 segment(열린 결정·관측 대기·막힌 것)는
    # fixes 와 달리 «상태 무관·원장 전체»를 가리키는 구절이 없다 — 세 구절이
    # 각각 open_decide·adopted·(blocked_expired·superseded_expired) 라는 특정
    # 하위 상태만 가리키므로 held_decide 를 담을 자리가 애초에 없다. 표의
    # 침묵이지 누락 버그가 아니다(§8.2 가 held_decide 를 승인 게이트의 남은
    # ask 목록에서 따로 보여준다는 전제).
    # [정직 고지] 이 대응은 사람이 적었다 — `cases.sh` 의 `case_gate_head_and_
    # grouping` 은 이 줄의 «내용과 순서»가 아래 리터럴과 정확히 같은지만 기계로
    # 잰다. 그 등식은 이 대응표가 뜻으로 맞다는 증명이 아니다. 「막힌 것」·
    # 「미적용 수정」·「질문」이 여러 행을 한 구절로 묶는 경계도 마찬가지로
    # 사람의 읽기다 — 그 경계에 동의하지 않는 미래 독자는 "원래 그렇게
    # 도출됐다"고 가정하지 말고 이 줄 자체를 고쳐라. GATE_ROWS 를 재정렬하거나
    # 새 행을 끼워 넣으면, 이 줄과 위 대응표와 `case_gate_head_and_grouping`
    # 의 기대 리터럴을 함께 옮겨라 — 셋 중 하나만 고치면 이 줄이 조용히 낡은
    # 설명이 된다.
    out.append("순서: 열린 결정 먼저 · 그다음 관측 대기 · 막힌 것 · 미적용 수정 · 질문")
    prev_anchor = None
    for row in GATE_ROWS:
        fn = GATE_RENDERERS.get(row.render) if row.render else None
        if fn is None:
            continue
        for fid in g[row.name]:
            # [Task 9 ⓓ] 묶음은 «표시»다 — 질문 수도 항목별 선택권도 안 바꾼다
            # (D24). 같은 자리를 건드리는 항목이 연달아 오면 그 사실만 한 줄로
            # 보인다.
            anchor = (st["findings"].get(fid) or {}).get("anchor")
            if anchor and anchor == prev_anchor:
                out.append("  ┆ 같은 자리(%s)" % anchor)
            prev_anchor = anchor
            out.extend(fn(st, g, fid))
    c = g["counts"]
    out.append("기각 %d건(재비판) · 사용자 기각 %d · drop %d · bucket 충돌 %d · 계보 지목 불일치 %d · 기각 계보 재상승 %d · 미소비 재상승 예약 %d · 미소비 상향 예약 %d"
               % (c["rejected"], c["user_rejected"], len(g["dropped"]), c["bucket_conflicts"],
                  c["lineage_mismatch"], c["revived"], c["reraise_unconsumed"], c["escalated_unconsumed"]))
    if g["two_stage"] and g["next_round_mode"] == "extra_approval":
        # 상한 도달 — approval_ready 와 무관하게 두 단계이고(Park P3·D-U3), 1단계는
        # 날 모드 토큰(`extra_approval`)이 아니라 사용자 말로 이름을 낸다. 이 선택지를
        # 고르면 다음 라운드 1단계가 `begin-round --extra-approval "<문구>"` 로 돌고, 그
        # 문구는 사용자 자신이 쓰는 것이라 여기 산문에 미리 채우지 않는다.
        if g["approval_ready"]:
            out.append("다음: " + ag + " 1단계 — 「추가 라운드 1회 열기」(다음 라운드 1단계가 "
                       "begin-round --extra-approval \"<사용자 자신의 문구>\" 로 도는 개별 승인) "
                       "또는 진행 옵션으로")
        else:
            out.append("다음: " + ag + " 1단계 — 열린 항목을 처리한 뒤 진행 옵션, 또는 "
                       "「추가 라운드 1회 열기」(다음 라운드 1단계가 "
                       "begin-round --extra-approval \"<사용자 자신의 문구>\" 로 도는 개별 승인)")
    elif g["approval_ready"]:
        out.append("다음: " + ag + " — 진행 옵션 활성")
    elif g["two_stage"]:
        out.append("다음: " + ag + " 1단계 — 열린 항목을 처리한 뒤 진행 옵션 (다음 라운드 = %s)" % g["next_round_mode"])
    else:
        out.append("다음: 라운드 %d (%s)" % (g["round"] + 1, g["next_round_mode"]))
    # 리뷰 완료가 아닌 라운드에서는 「다음:」 줄이 진행 옵션을 무조건 말하지 않는다 — 그 사실과 사유를 꼬리로 단다.
    if g.get("unreviewed_reason"):
        out[-1] += " — 단 이번 라운드는 리뷰 완료가 아니다(round_reviewed=false · %s)" % g["unreviewed_reason"]
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
    x = sp.add_parser("state-dir-for"); x.add_argument("--root", required=True)
    x.add_argument("--session", required=True); x.add_argument("--doc", required=True)
    x.set_defaults(fn=cmd_state_dir_for)
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
    x = sd(sp.add_parser("observe-diff")); x.set_defaults(fn=cmd_observe_diff)
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
