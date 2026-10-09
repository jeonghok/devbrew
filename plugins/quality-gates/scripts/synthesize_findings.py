#!/usr/bin/env python3
"""합성기 — 재비판 판정 적용 · dedup · 정렬 · 렌더 · 판정 입력.

결정론이다(모델 판단 없음). 두 얼굴:

  prepare (CLI 하위명령)  탐지 finding 을 출처 없이 익명화해 재비판자(`code-recritic`)에게 줄
                          목록과 역매핑을 파일로 쓴다.
  합성 (기본 CLI)         재비판 응답을 읽어 판정을 적용하고 dedup·정렬·렌더한 뒤, 판정 입력
                          (`blocking >= 1` 이 defect)을 `verdict.py` 로 넘긴다.

입력(합성):
  --findings PATH      탐지 finding YAML 목록
  --recritic PATH      재비판자 응답 원문 — `--recritic-map` 과 함께
  --recritic-map PATH  `prepare` 가 쓴 역매핑 JSON
  --recritic-diff PATH 재비판자에게 준 diff (선택 — added 의 file 도출에만)
  --emit-verdict       본 보고서 뒤에 `scope:`·`angles:`(있으면) · `verdict:` 꼬리를 싣는다
  --differential PATH  diff-test-results.py 의 집계 YAML
  --reason R           호출자만 아는 사유(반복 가능, verdict.REASONS 안)
  --angles PATH        각도 상태 파일(`<각도>: <상태>` 세 줄)
  --scope PATH         스코프 튜플(topic-head.sh 산출물)

본 보고서는 `**Findings:**` 개수 줄 다음에 `blocking: N`(살아남은 CRITICAL·IMPORTANT)과
`optional: M`(SUGGESTION)을 싣는다(K-4). confidence 는 읽지도 쓰지도 않는다 — 오탐 거르기는
재비판의 관문 A 가 한다.

exit: 0 정상 · 2 잘못된 호출 · 4 판정축 실패(stdout 비움).
"""
import argparse
import json
import re
import sys
from collections import defaultdict

import yaml

from adjudication import Ledger
from render_disposition import disposition_lines
import angles as _angles
import scope_tuple as _scope_tuple
import verdict as _verdict


SEV_ORDER = {"CRITICAL": 0, "IMPORTANT": 1, "SUGGESTION": 2}
SEVERITIES = ("SUGGESTION", "IMPORTANT", "CRITICAL")   # 낮은 것 → 높은 것. raise 는 위로만

ADJUDICATOR = "code-recritic"          # 승격 저자 = 재비판자 agent 의 frontmatter name:
BLOCK = "qg-recritic"
UNKNOWN = "미지"
EMPTY_SLOT_NOTE = "# 탐지 0건 — 이 목록은 비어 있다. 놓친 결함이 있으면 added 로 낸다."
_DIFF_FILE = re.compile(r"^diff --git a/(\S+) b/(\S+)$", re.M)

NEW_FINDING_REQUIRED = ("file", "severity", "summary")

# degrade 공시의 고정 마커. 소실(`dropped as malformed`)과 다른 사건이다.
DEGRADE_MARKER = "판정 degrade"
RECRITIC_ZERO_LINE = "탐지 0 · 재비판 0 — 재비판자가 돌았고 더한 finding 이 없다."


# ── 입력 ─────────────────────────────────────────────────────────────

def _read_source(path, ledger=None):
    """경로가 주어진 YAML 을 읽는다. Returns `(data, dead)`.

    못 읽는 것(OSError · 비-UTF-8 · YAML 파손)은 전부 주 입력 실패다 — raw traceback 으로
    0/2/4 계약을 탈출하지 않는다(V2).
    """
    try:
        with open(path, encoding="utf-8") as f:
            return yaml.safe_load(f), False
    except (OSError, UnicodeDecodeError, yaml.YAMLError) as exc:
        why = type(exc).__name__
        if ledger is not None:
            ledger.source_failed(str(path), why, primary=True)
        print(f"[synthesize_findings] 입력을 읽지 못했다: {path} ({why}) "
              "— 이 축의 주 입력 실패다", file=sys.stderr)
        return None, True


def load_findings(path, ledger=None):
    """Return `(list, dropped, dead)`. 경로 없음은 실패가 아니고, 경로가 있는데 못 읽으면 dead."""
    if not path:
        return [], 0, False
    data, dead = _read_source(path, ledger)
    if dead:
        return [], 0, True
    # 빈 finding 파일은 「발견 0」이다 — 탐지 리뷰어는 정당하게 아무것도 안 낼 수 있다.
    data = data or []
    if isinstance(data, dict) and "findings" in data:
        items, dropped = _as_list(data.get("findings"), "findings", ledger)
    else:
        items, dropped = _as_list(data, "findings document", ledger)
    return items, dropped, False


def _as_list(value, what, ledger=None):
    """Return `(list, dropped)` — 목록이 아니면 버리되 **센다**(V3).

    세지 않으면 버려진 CRITICAL 이 clean 으로 렌더된다. 매핑이면 항목 수, 스칼라는 1건.
    """
    if isinstance(value, list):
        return value, 0
    if not value:
        return [], 0
    lost = len(value) if isinstance(value, dict) else 1
    if ledger is not None:
        ledger.source_failed(
            what, "expected list, got %s — %d건" % (type(value).__name__, lost),
            primary=False)
    print(f"[synthesize_findings] {what} is {type(value).__name__}, "
          f"expected list — {lost}건 무시하고 계속한다"
          "(해당 입력은 심사되지 않았다)", file=sys.stderr)
    return [], lost


def extract_verdicts(doc, ledger=None):
    if isinstance(doc, dict):
        return _as_list(doc.get("verdicts"), "verdicts", ledger)
    return _as_list(doc, "판정자 문서", ledger)


def extract_new_findings(doc, ledger=None):
    if isinstance(doc, dict):
        return _as_list(doc.get("new_findings"), "new_findings", ledger)
    return [], 0


# ── 정체성 · severity ────────────────────────────────────────────────

def _norm_file(f):
    """`file` 을 해시 가능한 문자열로 — dedup 키가 튜플이라 목록 하나에 전체가 죽는다."""
    v = f.get("file", "")
    if isinstance(v, str):
        return v
    if isinstance(v, (list, tuple)):
        return ", ".join(str(x) for x in v)
    return str(v)


def _norm_line(f):
    v = f.get("line", 0)
    if isinstance(v, bool):
        return 0
    if isinstance(v, int):
        return v
    try:
        return int(str(v).strip())
    except (TypeError, ValueError):
        return 0


def _normalize_identity(f, ledger=None):
    """수집 지점에서 `file`·`line` 을 확정한다 — 소비 지점마다 가드하지 않는다."""
    for key, fn in (("file", _norm_file), ("line", _norm_line)):
        raw = f.get(key)
        new = fn(f)
        if ledger is not None and raw != new:
            ledger.coerced(key, raw, new, gate=False)
        f[key] = new
    return f


def finding_id(f):
    return f"{f.get('agent', 'unknown')}-{f.get('file', '')}-{f.get('line', '')}"


def _fold_sev(value):
    return value.strip().upper() if isinstance(value, str) else value


def _norm_sev(f):
    """아는 버킷으로. 빠졌거나 모르는 값은 IMPORTANT — 총 함수이고, 결측을 낙관값으로 채우지 않는다(V8).

    defect 는 살아남은 CRITICAL·IMPORTANT 로 정해지므로, 모르는 severity 를 SUGGESTION 으로 접으면
    그 finding 하나뿐인 실행이 거짓 clean 이 된다(9.3.1 의 confidence 결측 사고와 같은 모양).
    """
    folded = _fold_sev(f.get("severity"))
    if isinstance(folded, str) and folded in SEV_ORDER:
        return folded
    print(f"[synthesize_findings] unknown or missing severity {f.get('severity')!r}; "
          "treating as IMPORTANT (결측을 낙관값으로 채우지 않는다)", file=sys.stderr)
    return "IMPORTANT"


def _normalize_severity(f, ledger=None):
    """수집 지점에서 severity 를 확정한다. 표기만 다른 값은 조용히, 결측·미지는 강제로 센다."""
    raw = f.get("severity")
    new = _norm_sev(f)
    if ledger is not None and _fold_sev(raw) != new:
        ledger.coerced("severity", raw, new, gate=True)
    f["severity"] = new
    return f


# ── 재비판 판정 적용 ─────────────────────────────────────────────────

def promote_new_findings(raw_new, existing, *, author, ledger=None):
    """재비판자의 `added` 를 진짜 finding 으로 승격한다. Returns `(promoted, dropped)`.

    출처는 `agent` 에 쓰고(`sources` 는 리뷰어 값을 믿지 않고 버린다), id 는 `finding_id()`
    로 합성한다. 승격 항목은 `promoted: True` — dedup 이 같은 좌표의 다른 결함과 합치지 않게.
    """
    promoted, dropped = [], 0
    seen = {finding_id(f) for f in existing if isinstance(f, dict)}
    for item in raw_new:
        if not isinstance(item, dict):
            dropped += 1
            if ledger is not None:
                ledger.hold(repr(item)[:60], "항목 파손: not a mapping")
            print("[synthesize_findings] dropped malformed promoted finding: "
                  "not a mapping", file=sys.stderr)
            continue
        missing = [k for k in NEW_FINDING_REQUIRED if not item.get(k)]
        if missing:
            dropped += 1
            if ledger is not None:
                ledger.hold(repr(item.get("summary", item))[:60],
                            "항목 파손: missing %s" % ", ".join(missing))
            print("[synthesize_findings] dropped malformed promoted finding: "
                  f"missing {', '.join(missing)}", file=sys.stderr)
            continue
        f = dict(item)
        f.pop("sources", None)
        f.pop("confidence", None)
        f["agent"] = author
        f["promoted"] = True
        _normalize_identity(f, ledger=ledger)
        _normalize_severity(f, ledger=ledger)
        fid = finding_id(f)
        if fid in seen:
            base, suffix = fid, 2
            while f"{base}-{suffix}" in seen:
                suffix += 1
            fid = f"{base}-{suffix}"
            print("[synthesize_findings] promoted finding id collision on "
                  f"{base}; disambiguated to {fid}", file=sys.stderr)
        seen.add(fid)
        f["finding_id"] = fid
        promoted.append(f)
    return promoted, dropped


def apply_verdicts(findings, verdicts, ledger=None, adjudicator_dead=False):
    """판정을 적용한다. Returns `(out, dropped_malformed)`.

    - 매핑이 아닌 finding 은 버리되 센다(V3).
    - 판정 없는 finding 은 유지하고 `hold` 로 센다(다음 소비자가 사람이다). 판정자가 통째로
      죽었으면 항목마다 세지 않는다 — 그 사망은 원장에 이미 있고 `angle-absent` 로 나간다.
    - `raise` 는 올리기만, `lower` 는 SUGGESTION 으로만 내린다(관문 E).
    """
    by_id = {v.get("finding_id"): v for v in verdicts if isinstance(v, dict)}
    out, dropped = [], 0
    for f in findings:
        if not isinstance(f, dict):
            dropped += 1
            if ledger is not None:
                ledger.hold(repr(f)[:60], "항목 파손: not a mapping")
            print("[synthesize_findings] dropped malformed finding "
                  f"({type(f).__name__}, expected mapping): {str(f)[:80]!r}",
                  file=sys.stderr)
            continue
        f = _normalize_severity(_normalize_identity(dict(f), ledger=ledger), ledger=ledger)
        f.pop("confidence", None)
        v = by_id.get(finding_id(f))
        if v is None:
            if ledger is not None and not adjudicator_dead:
                ledger.hold(finding_id(f), "판정자 부재: 판정자 판정 없음")
            out.append(f)
            continue
        kind = v.get("verdict", "confirm")
        if kind == "reject":
            if ledger is not None:
                ledger.reject(finding_id(f), "판정자 기각")
            continue
        if kind == "raise" and "adjusted_severity" in v:
            f = _apply_raise(f, v["adjusted_severity"], ledger)
        elif kind == "lower":
            f = dict(f)
            f["severity"] = "SUGGESTION"
            f["lowered"] = True
        if ledger is not None:
            ledger.accept(finding_id(f))
        out.append(f)
    return out, dropped


def _apply_raise(f, adjusted, ledger):
    """`raise` — 지금보다 진짜로 높을 때만 바꾼다. 낡은 매핑이 낮은 값을 가리키면 강제로 남긴다."""
    new_sev = _fold_sev(adjusted)
    cur_sev = _norm_sev(f)
    new_rank = SEV_ORDER[new_sev] if isinstance(new_sev, str) and new_sev in SEV_ORDER \
        else SEV_ORDER["SUGGESTION"]
    cur_rank = SEV_ORDER[cur_sev]
    if new_rank < cur_rank:
        f = dict(f)
        f["severity"] = new_sev
    elif ledger is not None:
        ledger.coerced("adjusted_severity", new_sev, cur_sev, gate=new_rank > cur_rank)
    return f


def dedup(findings, ledger=None):
    """(file, line, severity) 가 같은 발견을 한 행으로 합치고 `sources` 를 모은다.

    승격 항목은 그룹핑에서 뺀다 — 같은 좌표의 «다른» 결함일 수 있다. 흡수는 소실이 아니다.
    """
    passthrough = [f for f in findings if f.get("promoted")]
    by_key = defaultdict(list)
    for f in findings:
        if f.get("promoted"):
            continue
        by_key[(f.get("file"), f.get("line"), _norm_sev(f))].append(f)
    deduped = []
    for group in by_key.values():
        merged = dict(group[0])
        # `agent: null` 은 None 그대로 둔다 — 문자열 'None' 으로 바꾸면 신원 계약이 그것을
        # 문법 밖 저자로 잘못 센다. 정렬 키는 None 과 문자열이 섞여도 죽지 않게 고른다.
        merged["sources"] = sorted({g.get("agent", "?") for g in group},
                                   key=lambda a: (a is None, str(a)))
        if ledger is not None:
            for g in group[1:]:
                ledger.absorbed(finding_id(g), finding_id(merged))
        deduped.append(merged)
    return deduped + passthrough


def sort_findings(findings):
    return sorted(findings, key=lambda f: (
        SEV_ORDER.get(_norm_sev(f), 9), str(f.get("file", "")), _norm_line(f)))


# ── 재비판 입출력 (code-recritic) ────────────────────────────────────

def anonymize(findings):
    """Returns `(items, mapping)` — 재비판자에게 줄 익명 목록과 역매핑.

    `agent`·`sources`·`confidence` 는 싣지 않는다 — 누가 냈는지 알면 판단이 그 프레이밍을
    흡수한다. `severity` 는 `disposition` 칸으로 싣는다. 매핑이 아닌 항목은 싣지 않는다 —
    합성이 같은 입력에서 그것을 파손으로 센다(여기서 또 세면 이중 계수).
    """
    items, mapping = [], {}
    n = 0
    for f in findings:
        if isinstance(f, dict):
            g = _normalize_identity(dict(f))
            n += 1
            key = f"f{n}"
            sev = _norm_sev(g)
            mapping[key] = {"finding_id": finding_id(g), "severity": sev}
            item = {"f": key, "file": g.get("file", ""), "line": g.get("line", 0),
                    "disposition": sev, "summary": str(g.get("summary", ""))}
            if g.get("proposed_fix"):
                item["proposed_fix"] = str(g.get("proposed_fix"))
            items.append(item)
    return items, mapping


def _single_diff_file(diff_text):
    """diff 가 정확히 한 파일을 건드리면 그 경로, 아니면 None — 고르지 않는다."""
    if not diff_text:
        return None
    paths = set()
    for _a, b in _DIFF_FILE.findall(diff_text):
        paths.add(b)
    return paths.pop() if len(paths) == 1 else None


def _evidence(v):
    """판정의 근거를 문자열로. 비어 있지 않은 문자열이거나, 문자열만 담은 목록(빈 칸을 버리고
    이은 결과가 비어 있지 않을 때)만 근거다. 그 밖의 값(`true` · `0` · `['']` · `[]` · 매핑)은
    「근거 없음」이다 — 근거를 요구하는 판정(reject · lower)이 형식만으로 통과하지 않게.
    """
    raw = v.get("evidence")
    if isinstance(raw, str):
        return raw.strip()
    if isinstance(raw, list):
        parts, all_text = [], True
        for x in raw:
            if isinstance(x, str):
                if x.strip():
                    parts.append(x.strip())
            else:
                all_text = False
        return "; ".join(parts) if all_text else ""
    return ""


def _verdict_for(v, cur_sev, fid, ledger):
    """재비판 판정 하나 → 합성기 판정 하나. 강제는 원장에 남긴다."""
    kind = v.get("verdict")
    out = {"finding_id": fid, "verdict": "confirm"}
    if kind == "confirm":
        pass
    elif kind == "reject":
        evidence = _evidence(v)
        if evidence:
            out = {"finding_id": fid, "verdict": "reject", "reason": evidence}
        else:
            ledger.coerced("verdict", "reject", "confirm", gate=True)
    elif kind == "raise":
        to_raw = v.get("to")
        to = to_raw.strip().upper() if isinstance(to_raw, str) else to_raw
        if to in SEVERITIES:
            if SEVERITIES.index(to) > SEVERITIES.index(cur_sev):
                out = {"finding_id": fid, "verdict": "raise", "adjusted_severity": to}
            else:
                ledger.coerced("to", to_raw, cur_sev, gate=False)
        else:
            ledger.coerced("to", to_raw, None, gate=True)
    elif kind == "lower":
        # 관문 E — 목적지는 SUGGESTION 하나뿐이고 근거가 있어야 한다. 근거 없는 lower 는
        # confirm 으로 강제하고 그 강제를 센다(gate=True — 막는 지적이 그대로 남는다).
        # `to` 는 없거나 SUGGESTION 이어야 한다. 그 밖의 값(IMPORTANT·CRITICAL · 어휘 밖 ·
        # 빈 값 · 문자열 아님)은 SUGGESTION 으로 내려 읽지 않고(fail-closed, V8) confirm 으로
        # 강제해 센다 — 모르는 값을 낙관 방향으로 풀지 않는다.
        evidence = _evidence(v)
        to_raw = v.get("to")
        if "to" in v and _fold_sev(to_raw) != "SUGGESTION":
            ledger.coerced("lower.to", to_raw, "confirm", gate=True)
        elif not evidence:
            ledger.coerced("verdict", "lower", "confirm", gate=True)
        elif cur_sev == "SUGGESTION":
            ledger.coerced("verdict", "lower", "confirm", gate=False)
        else:
            out = {"finding_id": fid, "verdict": "lower",
                   "adjusted_severity": "SUGGESTION", "reason": evidence}
    else:
        ledger.coerced("verdict", kind, "confirm", gate=True)
    if v.get("same_as"):
        ledger.coerced("same_as", v.get("same_as"), None, gate=False)
    return out


def _dead(ledger, why):
    ledger.source_failed(ADJUDICATOR, why, primary=True)
    print(f"[synthesize_findings] 재비판 결과를 쓸 수 없다 ({why}) — 판정 각도의 주 입력 실패다",
          file=sys.stderr)
    return None, True


def to_adjudication_doc(block_text, mapping, ledger, diff_text=None):
    """재비판자 응답 원문 → `({"verdicts", "new_findings", "_raw_*_count"}, dead)`.

    블록이 없거나 깨졌거나 매핑이 아니거나 `verdicts`·`added` 가 목록이 아니면 판정자 사망이다
    (V4 — 재비판 출력 부재는 clean 이 아니다). 같은 finding_id 로 묶인 f 들은 전부 판정되고 그
    판정이 전부 같아야 적용한다 — 일부만 판정된 묶음은 hold 한다.
    """
    from docreview_route import extract_block
    data, err = extract_block(block_text, BLOCK)
    if err is not None:
        return _dead(ledger, f"{BLOCK} 블록 {err}")
    if not isinstance(data, dict):
        return _dead(ledger, f"{BLOCK} 블록이 매핑이 아니다 ({type(data).__name__})")
    raw_verdicts = data.get("verdicts") or []
    raw_added = data.get("added") or []
    if not isinstance(raw_verdicts, list) or not isinstance(raw_added, list):
        return _dead(ledger, "verdicts/added 가 목록이 아니다")

    by_f, split = {}, set()
    for v in raw_verdicts:
        key = str(v.get("f", "")) if isinstance(v, dict) else ""
        if key not in mapping:
            ledger.hold(repr(v)[:60], "항목 파손: 재비판 판정이 알려진 f 를 가리키지 않는다")
        elif key in by_f:
            ledger.hold(key, "항목 파손: 같은 f 에 재비판 판정이 둘")
            split.add(key)
        else:
            by_f[key] = v

    keys_by_fid = {}
    for key in mapping:
        keys_by_fid.setdefault(mapping[key]["finding_id"], []).append(key)

    by_id = {}
    for fid, keys in keys_by_fid.items():
        judged, unjudged = [], []
        for k in keys:
            if k in by_f and k not in split:
                judged.append(k)
            else:
                unjudged.append(k)
        if judged and unjudged:
            ledger.hold(fid, "항목 파손: 같은 finding_id 의 일부 f 만 판정됐다 "
                             "(전부 판정돼야 적용된다)")
        elif judged:
            # 「동일」은 변환 «후» 판정(verdict + adjusted_severity)으로 잰다 — 원문 신호가 같아도
            # f 마다 현재 severity 가 달라 실제 결과가 갈릴 수 있다.
            convs, same = [], True
            for k in judged:
                conv = _verdict_for(by_f[k], mapping[k]["severity"], fid, ledger)
                if convs and ((conv.get("verdict"), conv.get("adjusted_severity"))
                              != (convs[0].get("verdict"), convs[0].get("adjusted_severity"))):
                    same = False
                convs.append(conv)
            if same:
                by_id[fid] = convs[0]
            else:
                ledger.hold(fid, "항목 파손: 같은 finding_id 에 갈린 재비판 판정")
    verdicts = list(by_id.values())

    single = _single_diff_file(diff_text)
    new_findings = []
    for a in raw_added:
        if not isinstance(a, dict):
            ledger.hold(repr(a)[:60], "항목 파손: added 항목이 매핑이 아니다")
            continue
        nf = dict(a)
        nf.pop("f", None)
        if not nf.get("file"):
            nf["file"] = single or UNKNOWN
            ledger.coerced("added.file", None, nf["file"], gate=False)
        raw_sev = nf.get("severity")
        sev = _fold_sev(raw_sev)
        if sev not in SEVERITIES:
            disp = _fold_sev(nf.get("disposition"))
            if disp in SEVERITIES:
                ledger.coerced("added.severity", raw_sev, disp, gate=False)
                sev = disp
            else:
                # V8 — 결측·미지는 IMPORTANT. 공시에는 재비판자가 실제로 쓴 값을 싣는다.
                ledger.coerced("added.severity", raw_sev, "IMPORTANT", gate=True)
                sev = "IMPORTANT"
        nf["severity"] = sev
        nf.pop("disposition", None)
        nf.setdefault("line", 0)
        new_findings.append(nf)
    doc = {"verdicts": verdicts, "new_findings": new_findings,
           "_raw_verdict_count": len(raw_verdicts), "_raw_added_count": len(raw_added)}
    return doc, False


def _read_text(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read(), None
    except (OSError, UnicodeDecodeError) as exc:
        return None, type(exc).__name__


def load_recritic(recritic_path, map_path, diff_path, ledger):
    """`--recritic` 진입점. 역매핑 항목의 형태도 믿지 않는다. Returns `(doc, dead)`."""
    text, why = _read_text(recritic_path)
    if text is None:
        return _dead(ledger, f"응답 파일 {recritic_path}: {why}")
    mtext, why = _read_text(map_path)
    if mtext is None:
        return _dead(ledger, f"역매핑 {map_path}: {why}")
    try:
        mapping = json.loads(mtext)
    except ValueError as exc:
        return _dead(ledger, f"역매핑 JSON 파손: {exc}")
    valid = isinstance(mapping, dict)
    if valid:
        for e in mapping.values():
            if not (isinstance(e, dict) and isinstance(e.get("finding_id"), str)
                    and e.get("severity") in SEVERITIES):
                valid = False
    if not valid:
        return _dead(ledger, "역매핑 항목이 손상됐다 (형식: {finding_id: str, "
                             "severity: SUGGESTION|IMPORTANT|CRITICAL})")
    diff_text = None
    if diff_path:
        diff_text, why = _read_text(diff_path)
        if diff_text is None:
            ledger.source_failed(str(diff_path), why, primary=False)
    return to_adjudication_doc(text, mapping, ledger, diff_text)


def cmd_prepare(argv):
    ap = argparse.ArgumentParser(prog="synthesize_findings.py prepare")
    ap.add_argument("--findings", required=True)
    ap.add_argument("--out-findings", required=True)
    ap.add_argument("--out-map", required=True)
    a = ap.parse_args(argv)
    if not a.findings or not a.out_findings or not a.out_map:
        print("synthesize_findings.py prepare: 빈 경로는 받지 않는다", file=sys.stderr)
        return 2
    findings, _dropped, dead = load_findings(a.findings, ledger=None)
    if dead:
        print(f"synthesize_findings.py prepare: finding 파일을 읽지 못했다: {a.findings}",
              file=sys.stderr)
        return 4
    items, mapping = anonymize(findings)
    text = (yaml.safe_dump(items, allow_unicode=True, sort_keys=False) if items
            else EMPTY_SLOT_NOTE + "\n[]\n")
    with open(a.out_findings, "w", encoding="utf-8") as f:
        f.write(text)
    with open(a.out_map, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=1)
    return 0


# ── 렌더 ─────────────────────────────────────────────────────────────

def _cell(value):
    """표 셀 — 리뷰어 저작 값의 `|`·개행이 행을 쪼개지 않게."""
    return str(value).replace("\r", "").replace("\n", " ").replace("|", "\\|")


def _degrade_block(report, blocking):
    """degrade 공시. 막는 사건이면 not-clean 마커, 아니면 공시 머리줄(공시 ≠ 차단)."""
    if not report["degraded"]:
        return []
    if blocking:
        head = (f"{DEGRADE_MARKER} — **이 실행은 clean이 아니다**: "
                "판정 경로가 온전하지 않았다.")
    else:
        head = f"{DEGRADE_MARKER} — 공시(판정을 막지 않음): 보조 경로가 온전하지 않았다."
    return [head] + [f"- {_cell(r)}" for r in report["reasons"]]


def count_split(findings):
    counts = {"CRITICAL": 0, "IMPORTANT": 0, "SUGGESTION": 0}
    for f in findings:
        counts[_norm_sev(f)] += 1
    return counts


def render(findings, dropped_malformed, report, held_classes, recritic_zero=False, *, blocking):
    counts = count_split(findings)
    n_block = counts["CRITICAL"] + counts["IMPORTANT"]
    disp_line, plumb_line, gloss_line, advisories = disposition_lines(report, held_classes, blocking)
    for a in advisories:
        print(a, file=sys.stderr)
    counts_line = (f"**Findings:** {counts['CRITICAL']} CRITICAL / "
                   f"{counts['IMPORTANT']} IMPORTANT / {counts['SUGGESTION']} SUGGESTION")
    out = ["## Review Findings (Synthesized)", "", counts_line,
           f"blocking: {n_block}", f"optional: {counts['SUGGESTION']}",
           disp_line, plumb_line, gloss_line]
    if not findings:
        out.insert(3, "No findings.")
        if recritic_zero:
            out.append(RECRITIC_ZERO_LINE)
        if dropped_malformed > 0:
            out.append(
                f"{dropped_malformed} finding(s) dropped as "
                "malformed (not a mapping, wrong container type, or missing "
                "file/severity/summary) — see stderr. "
                "**이 실행은 clean이 아니다**: 버려진 주장은 심사되지 않았다.")
        out.extend(_degrade_block(report, blocking))
        return "\n".join(out) + "\n"

    out.append("")
    degrade_lines = _degrade_block(report, blocking)
    if degrade_lines:
        out.extend(degrade_lines)
        out.append("")
    out.append("| Sev | Path:Line | Summary | Source |")
    out.append("|---|---|---|---|")
    for f in findings:
        srcs = f.get("sources") or [f.get("agent", "?")]
        if not isinstance(srcs, (list, tuple)):
            srcs = [srcs]
        sev = _norm_sev(f) + (" (lowered)" if f.get("lowered") else "")
        path_line = _cell("%s:%s" % (f.get("file"), f.get("line")))
        source = _cell(", ".join(str(s) for s in srcs))
        out.append(f"| {sev} | {path_line} | {_cell(f.get('summary', ''))} | {source} |")
    out.append("")
    if dropped_malformed > 0:
        out.append(
            f"{dropped_malformed} finding(s) dropped as malformed "
            "(not a mapping, wrong container type, or missing "
            "file/severity/summary) — see stderr.")
    out.append("")
    out.append("**Suggested fixes:**")
    for i, f in enumerate(findings, 1):
        fix = str(f.get("proposed_fix", "(none)")).replace("\r", " ").replace("\n", " ")
        out.append(f"- #{i} `{f.get('file')}:{f.get('line')}` — {fix}")
    return "\n".join(out) + "\n"


# ── 진입 ─────────────────────────────────────────────────────────────

def _usage(msg):
    print(f"synthesize_findings.py: {msg}", file=sys.stderr)
    sys.exit(2)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ["prepare"]:
        sys.exit(cmd_prepare(argv[1:]))

    ap = argparse.ArgumentParser()
    ap.add_argument("--findings", default="")
    ap.add_argument("--emit-verdict", action="store_true")
    # 기본값 None — 「플래그를 안 줬다」와 「빈 경로를 줬다」를 가른다. 빈 경로는 usage 오류다:
    # 값을 못 구한 호출자가 빈 변수로 부르면 그 축이 조용히 사라져 clean 이 된다.
    ap.add_argument("--differential", default=None)
    ap.add_argument("--reason", action="append", default=[])
    ap.add_argument("--angles", default=None)
    ap.add_argument("--scope", default=None)
    ap.add_argument("--recritic", default=None)
    ap.add_argument("--recritic-map", default=None)
    ap.add_argument("--recritic-diff", default=None)
    args = ap.parse_args(argv)

    for flag, val in (("--differential", args.differential), ("--angles", args.angles),
                      ("--scope", args.scope), ("--recritic", args.recritic),
                      ("--recritic-map", args.recritic_map),
                      ("--recritic-diff", args.recritic_diff)):
        if val is not None and val == "":
            _usage(f"{flag} 는 빈 문자열을 받지 않는다 (플래그를 생략하거나 실제 경로를 줘라)")
    if (args.recritic is None) != (args.recritic_map is None):
        _usage("--recritic 과 --recritic-map 은 함께 준다")
    if args.recritic_diff is not None and args.recritic is None:
        _usage("--recritic-diff 는 --recritic 없이 의미가 없다")
    if not args.emit_verdict:
        for flag, val in (("--differential", args.differential), ("--angles", args.angles),
                          ("--scope", args.scope)):
            if val is not None:
                _usage(f"{flag} 은 --emit-verdict 없이는 의미가 없다 (함께 주거나 {flag} 을 빼라)")
        if args.reason:
            _usage("--reason 은 --emit-verdict 없이는 의미가 없다 (함께 주거나 --reason 을 빼라)")

    ledger = Ledger(items="open")
    if args.recritic is not None:
        doc, adjudicator_dead = load_recritic(
            args.recritic, args.recritic_map, args.recritic_diff, ledger)
    else:
        doc, adjudicator_dead = None, False
    verdicts, dropped_verdicts = extract_verdicts(doc, ledger=ledger)
    raw, dropped_raw, findings_dead = load_findings(args.findings, ledger=ledger)

    findings, dropped_primary = apply_verdicts(raw, verdicts, ledger=ledger,
                                               adjudicator_dead=adjudicator_dead)
    new_raw, dropped_newlist = extract_new_findings(doc, ledger=ledger)
    promoted, dropped_promoted = promote_new_findings(new_raw, findings,
                                                      author=ADJUDICATOR, ledger=ledger)
    # 모든 출처의 소실을 한 채널로 합친다 — 컨테이너 수준과 항목 수준 둘 다(V3).
    dropped_malformed = (dropped_raw + dropped_verdicts + dropped_newlist
                         + dropped_primary + dropped_promoted)
    review_blocked = ledger.items_unaccounted() or dropped_malformed > 0
    blocking = ledger.blocks() or dropped_malformed > 0
    findings = sort_findings(dedup(findings + promoted, ledger=ledger))
    split = count_split(findings)
    n_block = split["CRITICAL"] + split["IMPORTANT"]   # K-4 의 blocking

    # 판정 «계산»은 본 보고서를 쓰기 «전»에 한다 — fail4 면 stdout 이 비어 있어야 한다.
    decision, angle_states, scope = None, None, None
    if args.emit_verdict:
        if args.scope is not None:
            scope = _scope_tuple.parse(_scope_tuple.read_or_fail4(args.scope))
        scope_reason = _scope_tuple.reason_of(scope) if scope is not None else None
        angle_absent = ledger.primary_source_failed()
        if args.angles is not None:
            declared = _angles.parse(_angles.read_or_fail4(args.angles))
            # AC10a — 수행자 집합은 이 실행이 실제로 «낸» finding 에서 도출한다. `agent` 는
            # 항상 세고 `sources` 는 더할 뿐이다(비신뢰 값이 `agent` 를 가리지 못하게).
            authors, missing_agent = set(), 0
            for f in findings + raw:
                if isinstance(f, dict):
                    a = f.get("agent")
                    if a is None or str(a) in ("", "?"):
                        missing_agent += 1
                    else:
                        authors.add(str(a))
                    srcs = f.get("sources") or []
                    if not isinstance(srcs, (list, tuple)):
                        srcs = [srcs]
                    for s in srcs:
                        if not (s is None and a is None):
                            s = str(s)
                            if s and s != "?":
                                authors.add(s)
            _angles.check_author_identity(authors, missing_agent)
            _angles.check_self_adjudication(declared, authors)
            dead_angles = []
            if findings_dead:
                dead_angles.append("security")
            if adjudicator_dead:
                dead_angles.append("adjudication")
            angle_states = _angles.with_dead_sources(declared, dead_angles)
            angle_absent = angle_absent or _angles.blocks(angle_states)
        decision = _verdict.decide(
            defect=n_block >= 1,                 # 살아남은 CRITICAL·IMPORTANT 가 1건 이상(K-4)
            review_blocked=review_blocked,
            angle_absent=angle_absent,
            differential_text=_verdict.read_or_none(args.differential),
            extra_reasons=args.reason + ([scope_reason] if scope_reason else []),
        )

    report = ledger.report()
    raw_verdict_count = doc.get("_raw_verdict_count", 0) if isinstance(doc, dict) else 0
    raw_added_count = doc.get("_raw_added_count", 0) if isinstance(doc, dict) else 0
    recritic_zero = (args.recritic is not None and not adjudicator_dead
                     and not raw and dropped_raw == 0
                     and not verdicts and not new_raw
                     and raw_verdict_count == 0 and raw_added_count == 0)
    sys.stdout.write(render(findings, dropped_malformed, report, ledger.held_by_class(),
                            recritic_zero=recritic_zero, blocking=blocking))
    if args.emit_verdict:
        if scope is not None:
            sys.stdout.write(_scope_tuple.render(scope))
        if angle_states is not None:
            sys.stdout.write(_angles.render(angle_states))
        sys.stdout.write(_verdict.render(decision))


if __name__ == "__main__":
    main()
