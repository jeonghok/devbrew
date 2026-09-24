#!/usr/bin/env python3
"""재비판 변환 계층 — qg 코드 경로 ↔ 공유 재비판자 `doc-recritic` (설계 §6.3.4).

재비판자는 문서 리뷰 엔진의 계약으로 말한다: 항목을 `f1`·`f2` … 로 식별하고, 판정은
`confirm`·`reject`(+`evidence`)·`raise`(+`to`)·`same_as`, 신규 발견은 `added` 다.
합성기는 `finding_id`(agent-file-line)로 잇고 `verdicts`·`new_findings` 를 읽는다.
그대로 이으면 기각이 원래 finding 에 반영되지 않고 `added` 가 누락된다.

**변환은 경계를 넘는 쪽이 소유한다** — `shared/docreview` 가 코드 경로의 어휘를 알면
spec-distill 의 문서 경로까지 그 어휘를 지고 다닌다. 그래서 이 파일은 qg 에 산다.

두 얼굴(PR4a 계획 R-N):
  prepare (CLI)          — finding 파일을 출처 없이 익명화하고 역매핑을 파일로 남긴다.
  load_recritic() (모듈) — 재비판자 응답 원문을 합성기의 판정자 문서 모양으로 바꾼다.
                           합성기가 import 해 **같은 프로세스·같은 원장**에서 부른다.

회계 — 값을 버리거나 바꾸는 자리는 전부 원장에 남긴다(R-O 표). 판정을 바꾸는 강제는
`gate=True`(공시), 표기만 바꾸는 강제는 `gate=False` 다(헌장). 이 파일은 판정 값을
내지 않는다 — 그것은 `verdict.py` 다.
"""
import argparse
import json
import re
import sys

import yaml

# `adjudication` 을 import 하지 않는다 — 원장은 호출자(합성기)가 넘긴다(Global Constraints ·
# 모의 실행 A2). 그래서 이 파일의 `for` 안에는 버리는 분기를 두지 않는다: L1 판정기가 이
# 파일을 안 보므로 처분 누락을 잡을 기계가 없다. 조건 블록으로 쓴다.

ADJUDICATOR = "doc-recritic"          # 승격 저자 = 재비판자 agent 의 frontmatter name:
BLOCK = "docreview-recritic"
SEVERITIES = ("SUGGESTION", "IMPORTANT", "CRITICAL")   # 낮은 것 → 높은 것. raise 는 위로만
UNKNOWN = "미지"
EMPTY_SLOT_NOTE = "# 탐지 0건 — 이 목록은 비어 있다. 놓친 결함이 있으면 added 로 낸다."
_DIFF_FILE = re.compile(r"^diff --git a/(\S+) b/(\S+)$", re.M)


def anonymize(findings):
    """Returns `(items, mapping)` — 재비판자에게 줄 익명 목록과 그 역매핑.

    `agent`·`sources`·`confidence` 는 싣지 않는다. 재비판자가 받지 않아야 하는 것은
    「누가 냈나」와 「앞 리뷰어가 무엇이라 결론냈나」다(설계 §6.3.3 프레이밍 맹목성).
    `severity` 는 `disposition` 으로 싣는다 — 그것이 재비판자가 판단할 처분이다(R-O).

    매핑이 아닌 항목은 싣지 않는다. 버리는 것이 아니다: 합성기가 같은 입력에서 그
    항목을 파손으로 센다 — 여기서도 세면 이중 계수다. (`continue` 대신 조건 블록을
    쓰는 이유가 그것이다 — 이 분기는 처분 대상이 아니다.)

    `finding_id` 는 합성기와 **같은 정규화**(`_normalize_identity`)를 거쳐 만든다.
    다르면 모든 판정이 「판정자 부재」로 떨어진다.
    """
    from synthesize_findings import _norm_sev, _normalize_identity, finding_id
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
    """diff 가 정확히 한 파일을 건드리면 그 경로, 아니면 None (R-P — 고르지 않는다)."""
    if not diff_text:
        return None
    paths = set()
    for a, b in _DIFF_FILE.findall(diff_text):
        paths.add(b)
    if len(paths) == 1:
        return paths.pop()
    return None


def _verdict_for(v, cur_sev, fid, ledger):
    """재비판 판정 하나 → 합성기 판정 하나 (R-O 표). 강제는 원장에 남긴다."""
    kind = v.get("verdict")
    out = {"finding_id": fid, "verdict": "confirm"}
    if kind == "confirm":
        pass
    elif kind == "reject":
        evidence = str(v.get("evidence") or "").strip()
        if evidence:
            out = {"finding_id": fid, "verdict": "reject", "reason": evidence}
        else:
            ledger.coerced("verdict", "reject", "confirm", gate=True)
    elif kind == "raise":
        to = v.get("to")
        if to in SEVERITIES:
            if SEVERITIES.index(to) > SEVERITIES.index(cur_sev):
                out = {"finding_id": fid, "verdict": "raise", "adjusted_severity": to}
            else:
                ledger.coerced("to", to, cur_sev, gate=False)
        else:
            ledger.coerced("to", to, None, gate=True)
    else:
        ledger.coerced("verdict", kind, "confirm", gate=True)
    if v.get("same_as"):
        ledger.coerced("same_as", v.get("same_as"), None, gate=False)
    if "layer" in v:
        ledger.coerced("layer", v.get("layer"), None, gate=False)
    return out


def _dead(ledger, why):
    ledger.source_failed(ADJUDICATOR, why, primary=True)
    print(f"[recritic_bridge] 재비판 결과를 쓸 수 없다 ({why}) — 판정 각도의 주 입력 실패다",
          file=sys.stderr)
    return None, True


def to_adjudication_doc(block_text, mapping, ledger, diff_text=None):
    """재비판자 응답 원문 → `({"verdicts": [...], "new_findings": [...]}, dead)`.

    블록이 없거나(잘린 응답 포함) 깨졌거나 매핑이 아니거나, `verdicts`·`added` 가 목록이
    아니면 **판정자 사망**이다 — 그 출력 전체를 믿을 수 없다(주 입력 실패, §6.4.3).
    펜스가 여럿이면 마지막이 이긴다(`extract_block` 의 규칙).
    """
    # 지연 import — 합성기가 이 모듈을 import 할 때마다 문서 리뷰 엔진 전체를 끌어오지
    # 않는다(재비판 경로를 안 쓰는 실행의 폭발 반경을 늘리지 않는다).
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

    by_f = {}
    split = set()
    for v in raw_verdicts:
        key = str(v.get("f", "")) if isinstance(v, dict) else ""
        if key not in mapping:
            ledger.hold(repr(v)[:60], "항목 파손: 재비판 판정이 알려진 f 를 가리키지 않는다")
        elif key in by_f:
            ledger.hold(key, "항목 파손: 같은 f 에 재비판 판정이 둘")
            split.add(key)
        else:
            by_f[key] = v

    by_id = {}
    for key in mapping:
        if key in by_f and key not in split:
            fid = mapping[key]["finding_id"]
            conv = _verdict_for(by_f[key], mapping[key]["severity"], fid, ledger)
            if fid in by_id and by_id[fid] != conv:
                by_id[fid] = None           # 같은 finding_id 에 갈린 판정 — 고르지 않는다
            elif fid not in by_id:
                by_id[fid] = conv
    verdicts = []
    for fid, conv in by_id.items():
        if conv is None:
            ledger.hold(fid, "항목 파손: 같은 finding_id 에 갈린 재비판 판정")
        else:
            verdicts.append(conv)

    single = _single_diff_file(diff_text)
    new_findings = []
    for a in raw_added:
        if not isinstance(a, dict):
            ledger.hold(repr(a)[:60], "항목 파손: added 항목이 매핑이 아니다")
        else:
            nf = dict(a)
            nf.pop("f", None)
            if not nf.get("file"):
                nf["file"] = single or UNKNOWN
                ledger.coerced("added.file", None, nf["file"], gate=False)
            if nf.get("severity") not in SEVERITIES:
                ledger.coerced("added.severity", nf.get("severity"), UNKNOWN, gate=False)
                nf["severity"] = UNKNOWN
            nf.setdefault("line", 0)
            if not nf.get("proposed_fix") and nf.get("replacement"):
                nf["proposed_fix"] = nf.get("replacement")
            new_findings.append(nf)
    return {"verdicts": verdicts, "new_findings": new_findings}, False


def _read_text(path):
    """Returns `(text, why)` — 못 읽으면 text 는 None."""
    try:
        with open(path, encoding="utf-8") as f:
            return f.read(), None
    except (OSError, UnicodeDecodeError) as exc:
        return None, type(exc).__name__


def load_recritic(recritic_path, map_path, diff_path, ledger):
    """합성기의 `--recritic` 진입점. Returns `(doc, dead)` — `load_yaml_doc` 과 같은 모양."""
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
    if not isinstance(mapping, dict):
        return _dead(ledger, "역매핑이 객체가 아니다")
    diff_text = None
    if diff_path:
        diff_text, why = _read_text(diff_path)
        if diff_text is None:
            # 보조 입력이다 — added 의 file 도출에만 쓴다. 죽어도 판정 축은 산다.
            ledger.source_failed(str(diff_path), why, primary=False)
    return to_adjudication_doc(text, mapping, ledger, diff_text)


def cmd_prepare(a):
    from synthesize_findings import load_findings
    findings, _dropped, dead = load_findings(a.findings, ledger=None)
    if dead:
        print(f"recritic_bridge.py: finding 파일을 읽지 못했다: {a.findings}", file=sys.stderr)
        return 4
    items, mapping = anonymize(findings)
    if items:
        text = yaml.safe_dump(items, allow_unicode=True, sort_keys=False)
    else:
        text = EMPTY_SLOT_NOTE + "\n[]\n"
    with open(a.out_findings, "w", encoding="utf-8") as f:
        f.write(text)
    with open(a.out_map, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=1)
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd")
    p = sub.add_parser("prepare")
    p.add_argument("--findings", required=True)
    p.add_argument("--out-findings", required=True)
    p.add_argument("--out-map", required=True)
    a = ap.parse_args()
    if a.cmd != "prepare":
        ap.print_usage(sys.stderr)
        return 2
    if not a.findings or not a.out_findings or not a.out_map:
        print("recritic_bridge.py: 빈 경로는 받지 않는다", file=sys.stderr)
        return 2
    return cmd_prepare(a)


if __name__ == "__main__":
    sys.exit(main())
