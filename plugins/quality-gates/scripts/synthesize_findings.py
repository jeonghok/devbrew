#!/usr/bin/env python3
"""Synthesizer (T3-2 refactor) — deterministic finding aggregator.

Replaces agents/synthesizer.md Agent dispatch. The algorithm is fully
deterministic (no LLM judgment): apply Adversarial verdicts → group/dedup
by (file,line,severity) → suppress non-CRITICAL confidence<=4 (CRITICAL always
kept; confidence 5-6 shown with a `*` caveat) → sort severity-desc /
confidence-desc / file-asc → render Markdown table.

Inputs (CLI args):
  --adversarial PATH   YAML file with `verdicts: [...]` (or top-level list)
  --findings PATH      YAML file with list of raw findings

Output (stdout): Markdown matching agents/synthesizer.md schema.
"""
import argparse
import sys
import yaml
from collections import defaultdict


SEV_ORDER = {"CRITICAL": 0, "IMPORTANT": 1, "SUGGESTION": 2}


def load_yaml(path):
    if not path:
        return []
    try:
        with open(path) as f:
            data = yaml.safe_load(f) or []
    except FileNotFoundError:
        return []
    if isinstance(data, dict) and "verdicts" in data:
        return data["verdicts"] or []
    if isinstance(data, dict) and "findings" in data:
        return data["findings"] or []
    return data or []


def load_yaml_doc(path):
    """Load a YAML file and return the raw parsed document (no key flattening).

    load_yaml() flattens `{verdicts: [...]}` down to the list, which discards
    every sibling key. The adversarial document now carries a second top-level
    key (`new_findings`), so the raw document has to survive the load.
    """
    if not path:
        return None
    try:
        with open(path) as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        return None


def extract_verdicts(doc):
    if isinstance(doc, dict):
        return doc.get("verdicts") or []
    return doc or []


def extract_new_findings(doc):
    if isinstance(doc, dict):
        return doc.get("new_findings") or []
    return []


def finding_id(f):
    return f"{f.get('agent', 'unknown')}-{f.get('file', '')}-{f.get('line', '')}"


NEW_FINDING_REQUIRED = ("file", "severity", "summary")
# 승격된 발견의 기본 confidence. suppress()의 바닥(<=4)보다는 위라 표에 실리고,
# render()의 caveat 임계(<=6) 아래라 `*`가 붙는다 — 이 발견은 어떤 리뷰어의
# 판정도 통과하지 않았다(adversarial 자신의 주장이다). 보이되 검증 안 됨으로
# 표시하는 것이 정직한 인코딩이다. 리뷰어가 명시적으로 confidence를 주면 그것을 쓴다.
NEW_FINDING_DEFAULT_CONFIDENCE = 5


def promote_new_findings(raw_new, existing):
    """adversarial의 `new_findings:` 항목을 진짜 finding으로 승격한다.

    Returns (promoted, dropped_malformed).

    출처는 `agent`에 쓴다 — `source`(단수)가 **아니다**. dedup()은 `agent`를 모아
    `sources`를 만들고 render()는 `sources`/`agent`만 읽으므로, `source`로 쓰면
    Source 컬럼이 fallback `?`로 렌더된다.

    id는 verdict가 준 값을 믿지 않고 기존 finding_id() 헬퍼로 합성한다 — 그래야
    신규 발견이 다른 agent의 finding id를 참칭할 수 없다. 기존과 충돌하면 기존이
    이기고(신규를 버리고 loud 기록), 신규끼리 충돌하면 `-2`, `-3` … 를 붙여
    결정론적으로 분리한다.

    승격된 항목에는 `promoted: True`를 찍는다. dedup()은 이 표식을 보고 해당
    항목을 그룹핑에서 **제외**한다 — 승격 이전에는 (file, line, severity) 충돌이
    언제나 "두 리뷰어가 같은 것을 봤다"라 병합이 옳았지만, 승격이 생기면서 충돌이
    "같은 줄의 *다른* 결함"일 수 있게 됐기 때문이다. 병합되면 발견 하나가 조용히
    사라지고, 더 나쁘게는 살아남은 행의 `sources`에 adversarial이 붙어 **하지 않은
    주장을 보증한 것처럼** 렌더된다(2026-08-03 재현, `test_…_promoted_findings.sh`
    케이스 5·6). 실패 방향을 소실이 아니라 중복 쪽으로 돌리는 최소 봉쇄다.

    범위 밖(설계 §11 CHECKS-07): dedup() 자체의 키 설계와 `sources`가 "같은 좌표에
    보고한 agent"인지 "이 발견에 동의한 agent"인지의 의미론은 여전히 미해결이다.
    이 봉쇄는 승격 경로만 그 미해결에서 떼어낸다.
    """
    promoted, dropped = [], 0
    seen = {finding_id(f) for f in existing if isinstance(f, dict)}
    for item in raw_new:
        if not isinstance(item, dict):
            dropped += 1
            print("[synthesize_findings] dropped malformed adversarial finding: "
                  "not a mapping", file=sys.stderr)
            continue
        missing = [k for k in NEW_FINDING_REQUIRED if not item.get(k)]
        if missing:
            dropped += 1
            print("[synthesize_findings] dropped malformed adversarial finding: "
                  f"missing {', '.join(missing)}", file=sys.stderr)
            continue
        f = dict(item)
        f["agent"] = "adversarial"
        f["promoted"] = True
        f["line"] = f.get("line") or 0
        f.setdefault("confidence", NEW_FINDING_DEFAULT_CONFIDENCE)
        fid = finding_id(f)
        if fid in seen:
            base = fid
            suffix = 2
            while f"{base}-{suffix}" in seen:
                suffix += 1
            fid = f"{base}-{suffix}"
            print("[synthesize_findings] adversarial finding id collision on "
                  f"{base}; disambiguated to {fid}", file=sys.stderr)
        seen.add(fid)
        f["finding_id"] = fid
        promoted.append(f)
    return promoted, dropped


def apply_verdicts(findings, verdicts):
    by_id = {v.get("finding_id"): v for v in verdicts if isinstance(v, dict)}
    out = []
    for f in findings:
        if not isinstance(f, dict):
            continue
        v = by_id.get(finding_id(f))
        if v is None:
            out.append(f)
            continue
        verdict = v.get("verdict", "confirm")
        if verdict == "reject":
            continue
        if verdict == "downgrade":
            f = dict(f)
            if "adjusted_severity" in v:
                f["severity"] = v["adjusted_severity"]
            if "adjusted_confidence" in v:
                f["confidence"] = v["adjusted_confidence"]
        out.append(f)
    return out


def dedup(findings):
    """(file, line, severity)가 같은 발견을 한 행으로 합치고 `sources`를 모은다.

    **승격된 발견(`promoted: True`)은 그룹핑에서 제외한다** — 근거는
    promote_new_findings()의 docstring. 요약하면: 승격 이전에는 좌표 충돌이 항상
    "두 리뷰어가 같은 것을 봤다"였지만 이제는 "같은 줄의 다른 결함"일 수 있고,
    합치면 발견이 조용히 사라지는 데다 `sources`가 허위 보증을 만든다.
    """
    passthrough = [f for f in findings if f.get("promoted")]
    by_key = defaultdict(list)
    for f in findings:
        if f.get("promoted"):
            continue
        key = (f.get("file"), f.get("line"), f.get("severity"))
        by_key[key].append(f)
    deduped = []
    for key, group in by_key.items():
        group.sort(key=lambda f: int(f.get("confidence", 0)), reverse=True)
        merged = dict(group[0])
        merged["sources"] = sorted({g.get("agent", "?") for g in group})
        deduped.append(merged)
    return deduped + passthrough


def suppress(findings):
    """C30 rubric (R4): kept vs suppressed.

    - CRITICAL: always kept (any confidence).
    - non-CRITICAL: confidence <= 4 -> suppressed; else kept.

    The caveat marker (`*`) is NOT decided here; it is a pure function of
    `confidence <= 6` on any *shown* finding, computed in render().
    """
    kept, suppressed = [], []
    for f in findings:
        sev = f.get("severity", "SUGGESTION")
        conf = int(f.get("confidence", 0))
        if sev != "CRITICAL" and conf <= 4:
            suppressed.append(f)
        else:
            kept.append(f)
    return kept, suppressed


def sort_findings(findings):
    return sorted(findings, key=lambda f: (
        SEV_ORDER.get(f.get("severity", "SUGGESTION"), 9),
        -int(f.get("confidence", 0)),
        f.get("file", ""),
    ))


def _cell(value):
    """Escape Markdown-table-breaking characters in a single table cell.

    Cell values (summary, source, file) originate from reviewer-agent (LLM)
    output and can contain `|` or newlines, which would split or break a
    pipe-delimited table row. Escape `|` and collapse CR/LF to a space.
    """
    return str(value).replace("\r", "").replace("\n", " ").replace("|", "\\|")


def _norm_sev(f):
    """Return a finding's severity normalized to a known bucket.

    Reviewer personas constrain severity to {CRITICAL, IMPORTANT, SUGGESTION},
    but nothing enforces it at runtime. An unrecognized severity would render
    a table row yet be omitted from the counts line — and the SKILL boundary
    keys on that counts line, so a visible finding could be read as clean
    (kept=0). Normalize to SUGGESTION (warn to stderr) so counts == rows.
    """
    sev = f.get("severity", "SUGGESTION")
    if sev not in SEV_ORDER:
        print(
            f"[synthesize_findings] unknown severity {sev!r}; treating as SUGGESTION",
            file=sys.stderr,
        )
        return "SUGGESTION"
    return sev


def render(findings, suppressed_count, dropped_malformed=0):
    if not findings:
        return (
            "## Review Findings (Synthesized)\n\n"
            f"No high-confidence findings. {suppressed_count} low-confidence "
            "findings suppressed.\n"
        )

    counts = {"CRITICAL": 0, "IMPORTANT": 0, "SUGGESTION": 0}
    rows = []
    any_caveat = False
    for f in findings:
        sev = _norm_sev(f)
        counts[sev] += 1
        conf = int(f.get("confidence", 0))
        if conf <= 6:
            conf_cell = f"{conf} *"
            any_caveat = True
        else:
            conf_cell = f"{conf}"
        path_line = _cell(f"{f.get('file')}:{f.get('line')}")
        summary = _cell(f.get("summary", ""))
        source = _cell(", ".join(f.get("sources", [f.get("agent", "?")])))
        rows.append(f"| {sev} | {path_line} | {conf_cell} | {summary} | {source} |")

    counts_line = (
        f"**Findings:** {counts['CRITICAL']} CRITICAL / "
        f"{counts['IMPORTANT']} IMPORTANT / {counts['SUGGESTION']} SUGGESTION"
    )
    if suppressed_count > 0:
        counts_line += f" — {suppressed_count} suppressed (conf <= 4)"

    out = ["## Review Findings (Synthesized)", "", counts_line, ""]
    out.append("| Sev | Path:Line | Conf | Summary | Source |")
    out.append("|---|---|---|---|---|")
    out.extend(rows)
    out.append("")
    if any_caveat:
        out.append("`*` = confidence <= 6 (treat with caution).")
    if suppressed_count > 0:
        out.append(
            f"{suppressed_count} finding(s) suppressed (conf <= 4); "
            "re-run with `/qg --show-low-confidence` to see all."
        )
    if dropped_malformed > 0:
        out.append(
            f"{dropped_malformed} adversarial finding(s) dropped as malformed "
            "(missing file/severity/summary) — see stderr."
        )
    out.append("")
    out.append("**Suggested fixes:**")
    for f in findings:
        fix = str(f.get("proposed_fix", "(none)")).replace("\r", " ").replace("\n", " ")
        out.append(f"- `{f.get('file')}:{f.get('line')}` — {fix}")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--adversarial", default="")
    ap.add_argument("--findings", default="")
    args = ap.parse_args()

    doc = load_yaml_doc(args.adversarial) if args.adversarial else None
    verdicts = extract_verdicts(doc)
    raw = load_yaml(args.findings) if args.findings else []

    findings = apply_verdicts(raw, verdicts)
    promoted, dropped_malformed = promote_new_findings(extract_new_findings(doc), findings)
    findings = findings + promoted          # 기존 뒤에 append — 기존 표 순서를 흔들지 않는다
    findings = dedup(findings)
    kept, suppressed = suppress(findings)
    kept = sort_findings(kept)

    sys.stdout.write(render(kept, len(suppressed), dropped_malformed))


if __name__ == "__main__":
    main()
