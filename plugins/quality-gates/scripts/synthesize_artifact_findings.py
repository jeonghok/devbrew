#!/usr/bin/env python3
"""synthesize_artifact_findings.py — §10 deterministic artifact-finding pipeline.

Two phases (the same dedup_key/stagnation_key algorithm lives once here):

  --phase key --findings A [--findings B ...]
      Merge critic + codex findings, within-round dedup by dedup_key (first wins,
      merge `agent` into `sources`), inject dedup_key + stagnation_key, emit
      `findings: [...]`. Runs BEFORE adversarial so adversarial can echo dedup_key.

  --phase synth --findings MERGED --adversarial VERDICTS
      Apply verdicts (confirm/downgrade/reject) by finding_key == dedup_key,
      compute the fail-closed kept set, and emit convergence / degraded /
      unadjudicated / severity counts / stagnation_keys / kept list.

Schema: see plan Global Constraints "데이터 계약".
"""
import argparse
import hashlib
import sys

import yaml

SEV = {"CRITICAL", "IMPORTANT", "SUGGESTION"}


def _norm(s):
    return " ".join(str(s if s is not None else "").strip().lower().split())


def dedup_key(f):
    raw = _norm(f.get("category")) + "\0" + _norm(f.get("target_anchor")) + "\0" + _norm(f.get("summary"))
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:12]


def stagnation_key(f):
    raw = _norm(f.get("category")) + "\0" + _norm(f.get("target_anchor"))
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:12]


def _norm_sev(f):
    s = str(f.get("severity", "SUGGESTION")).upper()
    return s if s in SEV else "SUGGESTION"


def _load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return yaml.safe_load(fh)
    except (FileNotFoundError, yaml.YAMLError):
        return "__ERR__"


def _findings_of(doc):
    if isinstance(doc, dict) and isinstance(doc.get("findings"), list):
        return doc["findings"]
    if isinstance(doc, list):
        return doc
    return []


def phase_key(paths):
    by_key = {}
    for p in paths:
        doc = _load(p)
        if doc == "__ERR__":
            continue
        for f in _findings_of(doc):
            if not isinstance(f, dict):
                continue
            g = dict(f)
            g["severity"] = _norm_sev(g)
            k = dedup_key(g)
            g["dedup_key"] = k
            g["stagnation_key"] = stagnation_key(g)
            if k in by_key:
                srcs = set(by_key[k].get("sources", [by_key[k].get("agent", "?")]))
                srcs.add(g.get("agent", "?"))
                by_key[k]["sources"] = sorted(srcs)
            else:
                g["sources"] = [g.get("agent", "?")]
                by_key[k] = g
    fields = ("agent", "sources", "category", "target_anchor", "target_lines",
              "severity", "summary", "proposed_fix", "dedup_key", "stagnation_key")
    out = {"findings": [{k: f.get(k) for k in fields if f.get(k) is not None} for f in by_key.values()]}
    sys.stdout.write(yaml.safe_dump(out, allow_unicode=True, sort_keys=False))


def phase_synth(findings_path, adversarial_path):
    merged_doc = _load(findings_path)
    findings = [dict(f) for f in _findings_of(merged_doc) if isinstance(f, dict)]
    for f in findings:
        f.setdefault("dedup_key", dedup_key(f))
        f["severity"] = _norm_sev(f)

    adv_doc = _load(adversarial_path) if adversarial_path else None
    adv_parse_failed = adv_doc == "__ERR__"
    verdicts, new_findings = [], []
    if isinstance(adv_doc, dict):
        _v = adv_doc.get("verdicts")
        verdicts = _v if isinstance(_v, list) else []
        _nf = adv_doc.get("new_findings")
        new_findings = _nf if isinstance(_nf, list) else []
    elif adv_doc is None:
        # No adversarial file provided at all -> treat as parse failure for the guard.
        adv_parse_failed = True

    by_v = {v.get("finding_key"): v for v in verdicts if isinstance(v, dict)}

    kept = []
    unadjudicated = 0
    for f in findings:
        v = by_v.get(f["dedup_key"])
        if v is None:
            unadjudicated += 1          # fail-closed: exclude from kept (AC16)
            continue
        verdict = str(v.get("verdict", "")).lower()
        if verdict == "reject":
            continue
        if verdict == "downgrade":
            ns = str(v.get("new_severity", "")).upper()
            if ns in SEV:
                f = dict(f)
                f["severity"] = ns
            # missing/invalid new_severity -> keep original severity (fail-closed: don't drop)
        kept.append(f)

    kept_keys = {f["dedup_key"] for f in kept}
    for nf in new_findings:
        if not isinstance(nf, dict):
            continue
        g = dict(nf)
        g["severity"] = _norm_sev(g)
        g["dedup_key"] = dedup_key(g)
        if g["dedup_key"] in kept_keys:
            continue
        kept_keys.add(g["dedup_key"])
        kept.append(g)

    had_findings = len(findings) > 0
    degraded = had_findings and (adv_parse_failed or len(verdicts) == 0)

    crit = sum(1 for f in kept if f["severity"] == "CRITICAL")
    imp = sum(1 for f in kept if f["severity"] == "IMPORTANT")
    sug = sum(1 for f in kept if f["severity"] == "SUGGESTION")
    converged = (not degraded) and (crit + imp == 0)
    skeys = sorted({stagnation_key(f) for f in kept})

    out = {
        "converged": converged,
        "degraded": degraded,
        "unadjudicated": unadjudicated,
        "kept_critical": crit,
        "kept_important": imp,
        "kept_suggestion": sug,
        "stagnation_keys": ",".join(skeys),
        "kept": [
            {k: f.get(k) for k in ("category", "target_anchor", "target_lines",
                                   "severity", "summary", "proposed_fix", "dedup_key")
             if f.get(k) is not None}
            for f in kept
        ],
    }
    sys.stdout.write(yaml.safe_dump(out, allow_unicode=True, sort_keys=False))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phase", choices=["key", "synth"], required=True)
    ap.add_argument("--findings", action="append", default=[])
    ap.add_argument("--adversarial", default="")
    args = ap.parse_args()
    if args.phase == "key":
        phase_key(args.findings)
    else:
        findings_path = args.findings[0] if args.findings else ""
        phase_synth(findings_path, args.adversarial)


if __name__ == "__main__":
    main()
