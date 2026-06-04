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


def finding_id(f):
    return f"{f.get('agent', 'unknown')}-{f.get('file', '')}-{f.get('line', '')}"


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
    by_key = defaultdict(list)
    for f in findings:
        key = (f.get("file"), f.get("line"), f.get("severity"))
        by_key[key].append(f)
    deduped = []
    for key, group in by_key.items():
        group.sort(key=lambda f: int(f.get("confidence", 0)), reverse=True)
        merged = dict(group[0])
        merged["sources"] = sorted({g.get("agent", "?") for g in group})
        deduped.append(merged)
    return deduped


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


def render(findings, suppressed_count):
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

    verdicts = load_yaml(args.adversarial) if args.adversarial else []
    raw = load_yaml(args.findings) if args.findings else []

    findings = apply_verdicts(raw, verdicts)
    findings = dedup(findings)
    kept, suppressed = suppress(findings)
    kept = sort_findings(kept)

    sys.stdout.write(render(kept, len(suppressed)))


if __name__ == "__main__":
    main()
