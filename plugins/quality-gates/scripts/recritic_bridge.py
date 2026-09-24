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
        to_raw = v.get("to")
        # fix round 1 Minor 4 — `_norm_sev`(synthesize_findings.py) 와 같은 규율로
        # 대소문자를 접는다. 접지 않으면 `to: critical`(소문자) 이 어휘 밖으로
        # 오판돼 confirm 으로 강제되고 그 강제가 불필요하게 degrade 공시된다.
        to = to_raw.strip().upper() if isinstance(to_raw, str) else to_raw
        if to in SEVERITIES:
            if SEVERITIES.index(to) > SEVERITIES.index(cur_sev):
                out = {"finding_id": fid, "verdict": "raise", "adjusted_severity": to}
            else:
                ledger.coerced("to", to_raw, cur_sev, gate=False)
        else:
            ledger.coerced("to", to_raw, None, gate=True)
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
    """재비판자 응답 원문 → `({"verdicts": [...], "new_findings": [...], ...}, dead)`.

    블록이 없거나(잘린 응답 포함) 깨졌거나 매핑이 아니거나, `verdicts`·`added` 가 목록이
    아니면 **판정자 사망**이다 — 그 출력 전체를 믿을 수 없다(주 입력 실패, §6.4.3).
    펜스가 여럿이면 마지막이 이긴다(`extract_block` 의 규칙).

    반환하는 doc 에는 판정용 두 키(`verdicts`·`new_findings`) 말고 회계 전용 두 키가
    더 있다 — `_raw_verdict_count`·`_raw_added_count`(fix round 1 Important 1). 둘 다
    **변환 전** 원문 길이다. 합성기는 이 값으로 「탐지 0 · 재비판 0」을 판단한다 —
    변환 «후» 길이(`verdicts`/`new_findings`)만 보면 held·파손된 원문(모르는 f 뿐인
    verdicts, 매핑이 아닌 added 항목)이 0 으로 접혀 재비판 0 을 거짓으로 주장한다.
    `load_yaml_doc`(옛 경로)의 doc 에는 이 두 키가 없다 — 호출자가 `args.recritic is
    not None` 으로 이미 갈랐으므로 옛 경로에서 이 키를 찾을 일이 없다.

    콜라이딩 finding_id(같은 agent·file·line, 다른 severity 로 두 finding 이 도출)의
    f 들은 **전부** 판정돼야, 그리고 그 판정이 **전부 같아야**(raise 면 `to` 까지)
    합쳐서 적용한다(fix round 1 Important 2, Law 2). 일부만 판정되면(다른 f 는
    침묵) 그 일부 판정을 조용히 전체에 적용하지 않는다 — 판정 안 된 finding 이
    판정된 형제의 결론을 뒤집어쓰고 사라지는 fail-open 을 막는다.
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

    # fix round 1 Important 2 — 콜라이딩 finding_id 를 «f 단위»가 아니라 «fid 단위»로
    # 묶어, 그 fid 의 f 들이 전부 판정됐는지부터 본다. 일부만 판정되면(다른 f 는
    # by_f 에 없음) 합치지 않고 hold 한다 — 예전 코드는 이 자리를 검사하지 않아
    # 판정 안 된 f 를 그냥 «없었던 셈» 치고 판정된 f 하나로 fid 전체를 결정했다.
    keys_by_fid = {}
    for key in mapping:
        fid = mapping[key]["finding_id"]
        if fid not in keys_by_fid:
            keys_by_fid[fid] = []
        keys_by_fid[fid].append(key)

    by_id = {}
    for fid in keys_by_fid:
        keys = keys_by_fid[fid]
        judged = []
        unjudged = []
        for key in keys:
            if key in by_f and key not in split:
                judged.append(key)
            else:
                unjudged.append(key)
        if judged and unjudged:
            ledger.hold(fid, "항목 파손: 같은 finding_id 의 일부 f 만 판정됐다 "
                             "(전부 판정돼야 적용된다)")
        elif judged:
            # fix round 2 — 「동일」의 기준은 **변환 후** 판정(verdict 종류 +
            # adjusted_severity)이다, reason 만 뺀다. 원문(raw v)의 raise/to 로
            # 비교하면(라운드 1의 결함) 같은 `to` 를 말해도 f 마다 cur_sev 가
            # 달라 실제로는 오르거나(더 낮은 severity 였던 f) 무시되는데(이미
            # 그 severity 이상이던 f, raise 는 위로만) 신호가 같아 보인다 — 무시된
            # raise 의 conv 는 confirm(severity 불변)인데, 오른 conv 는 raise+
            # adjusted_severity 다. 원문 신호가 같다고 대표를 골라 적용하면 오른
            # 쪽의 adjusted_severity 가 무시된 쪽에도 그대로 씌워지거나(내려감),
            # 무시된 쪽의 confirm 이 오른 쪽에도 씌워져(안 오름) 둘 다 fail-open
            # 이다. 변환 후 값으로 비교하면 이 차이가 바로 드러난다. reason 은
            # 제외한다 — 두 reject 가 문구만 달라도 합쳐진다(evidence 텍스트는
            # `apply_verdicts` 가 어차피 고정 라벨로만 기록해 표에 안 실린다).
            # 대표로 쓰는 conv 는 첫 judged 키의 것 — 결정론적이다.
            convs = []
            for key in judged:
                convs.append(_verdict_for(by_f[key], mapping[key]["severity"], fid, ledger))
            sigs = []
            for conv in convs:
                sigs.append((conv.get("verdict"), conv.get("adjusted_severity")))
            same = True
            for s in sigs[1:]:
                if s != sigs[0]:
                    same = False
            if same:
                by_id[fid] = convs[0]
            else:
                ledger.hold(fid, "항목 파손: 같은 finding_id 에 갈린 재비판 판정")
        # else: 아무도 이 fid 를 판정하지 않았다 — 판정자 부재는 apply_verdicts()
        # 가 fail-open 으로 이미 hold 한다(R-K). 여기서 또 세면 이중 계수다.
    verdicts = []
    for fid in by_id:
        verdicts.append(by_id[fid])

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
            # fix round 1 Minor 4·5 — `_norm_sev` 와 같은 규율로 대소문자를 접고
            # (`Critical` 을 미지로 강등시키지 않는다), severity 가 없으면
            # `disposition:` 으로 대신 잡는다 — 익명 목록은 severity 를 그 칸에
            # 실어 보내므로(anonymize()) persona 가 같은 모양을 그대로 되돌려줄
            # 수 있다.
            raw_sev = nf.get("severity")
            sev = raw_sev.strip().upper() if isinstance(raw_sev, str) else raw_sev
            if sev not in SEVERITIES:
                raw_disp = nf.get("disposition")
                disp = raw_disp.strip().upper() if isinstance(raw_disp, str) else raw_disp
                if disp in SEVERITIES:
                    ledger.coerced("added.severity", raw_sev, disp, gate=False)
                    sev = disp
                else:
                    ledger.coerced("added.severity", raw_sev, UNKNOWN, gate=False)
                    sev = UNKNOWN
            nf["severity"] = sev
            nf.pop("disposition", None)
            nf.setdefault("line", 0)
            if not nf.get("proposed_fix") and nf.get("replacement"):
                nf["proposed_fix"] = nf.get("replacement")
            new_findings.append(nf)
    doc = {"verdicts": verdicts, "new_findings": new_findings,
           "_raw_verdict_count": len(raw_verdicts), "_raw_added_count": len(raw_added)}
    return doc, False


def _read_text(path):
    """Returns `(text, why)` — 못 읽으면 text 는 None."""
    try:
        with open(path, encoding="utf-8") as f:
            return f.read(), None
    except (OSError, UnicodeDecodeError) as exc:
        return None, type(exc).__name__


def load_recritic(recritic_path, map_path, diff_path, ledger):
    """합성기의 `--recritic` 진입점. Returns `(doc, dead)` — `load_yaml_doc` 과 같은 모양.

    fix round 1 Important 3 — 역매핑 항목마다 형태를 검증한다. `to_adjudication_doc`
    은 `mapping[key]["finding_id"]`/`["severity"]` 를 방어 없이 첨자로 읽는다: 항목이
    매핑이 아니면 TypeError, `severity` 가 `SEVERITIES` 밖(예: `_verdict_for` 의
    `SEVERITIES.index(cur_sev)`)이면 ValueError, 키 자체가 없으면 KeyError 로 각각
    exit 1(계약 위반)이 샌다. `map.json` 은 우리가 `prepare` 로 쓴 파일이지만 디스크
    사이 손상·수동 편집·구버전 포맷도 입력이므로 신뢰하지 않는다 — 여기서 걸러
    「판정자 사망」으로 돌리면 `to_adjudication_doc` 은 항상 온전한 매핑만 받는다.
    """
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
    valid = True
    for key in mapping:
        entry = mapping[key]
        if not isinstance(entry, dict):
            valid = False
        elif not isinstance(entry.get("finding_id"), str):
            valid = False
        elif entry.get("severity") not in SEVERITIES:
            valid = False
    if not valid:
        return _dead(ledger, "역매핑 항목이 손상됐다 (형식: {finding_id: str, "
                             "severity: SUGGESTION|IMPORTANT|CRITICAL})")
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
