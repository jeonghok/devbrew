#!/usr/bin/env python3
"""Synthesizer (T3-2 refactor) — deterministic finding aggregator.

Replaces agents/synthesizer.md Agent dispatch. The algorithm is fully
deterministic (no LLM judgment): apply Adversarial verdicts → group/dedup
by (file,line,severity) → suppress confidence<7 unless severity==CRITICAL
→ sort severity-desc / confidence-desc / file-asc → render Markdown.

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
    kept, suppressed = [], []
    for f in findings:
        sev = f.get("severity", "SUGGESTION")
        conf = int(f.get("confidence", 0))
        if conf < 7 and sev != "CRITICAL":
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


def render(findings, suppressed_count):
    if not findings:
        return (
            "## Review Findings (Synthesized)\n\n"
            f"No high-confidence findings. {suppressed_count} low-confidence "
            "findings suppressed.\n"
        )
    out = ["## Review Findings (Synthesized)", ""]
    for sev_name in ("CRITICAL", "IMPORTANT", "SUGGESTION"):
        bucket = [f for f in findings if f.get("severity") == sev_name]
        if not bucket:
            continue
        out.append(f"### {sev_name}")
        out.append("")
        for f in bucket:
            out.append(
                f"- **{f.get('file')}:{f.get('line')}** — {f.get('summary', '')}"
            )
            out.append(f"  - Sources: {', '.join(f.get('sources', [f.get('agent', '?')]))}")
            out.append(f"  - Confidence: {f.get('confidence')}/10")
            out.append(f"  - Fix: {f.get('proposed_fix', '(none)')}")
        out.append("")
    if suppressed_count > 0:
        out.append("### Suppressed (confidence < 7, severity != CRITICAL)")
        out.append("")
        out.append(
            f"{suppressed_count} finding(s) hidden. "
            "Re-run with `/qg --show-low-confidence` to see all."
        )
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
