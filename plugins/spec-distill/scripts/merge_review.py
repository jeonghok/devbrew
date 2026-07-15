#!/usr/bin/env python3
"""merge_review.py — deterministic merge/ledger engine for spec-distill Phase 3.

spec-distill design §6 #6 / §7 / §8 / §9. Single verifiable boundary that owns
every deterministic operation of the co-review merge (C2): parse BOTH reviewer
outputs (no LLM transcription — [fc2ef911] sealed), derive codex_verdict,
conservatively merge verdicts, and (Task 7) run the unified-ledger stagnation
scan. stdlib only.

CLI:
  merge_review.py --claude-output <path> --codex-yaml <path> --history <json>

Emits YAML on stdout (see design §5 / plan Global Constraints). Verdict recovery
hierarchy (§9): sentinel OK / sentinel bad→**Status:** recovery / **Status:** bad
→codex alone / both bad→needs_revise fail-safe.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

# --- verdict precedence (§7b) ------------------------------------------------
RANK = {"approved": 0, "needs_revise": 1, "needs_interview": 2}
INV_RANK = {v: k for k, v in RANK.items()}
CODEX_SEVERITY_REVISE = {"block", "high"}

SENTINEL_RE = re.compile(r"```spec-review-issues[^\n]*\n(.*?)\n?```", re.DOTALL)
STATUS_RE = re.compile(
    r"^\*\*Status:\*\*\s*(approved|needs_revise|needs_interview)\b", re.MULTILINE
)
SPEC_REVIEW_HEADER_RE = re.compile(r"^##\s+Spec Review\b", re.MULTILINE)


# --- Claude side -------------------------------------------------------------
def extract_claude_verdict(text: str) -> str | None:
    """OQ3: first **Status:** line at/after the '## Spec Review' header; if the
    header is absent, fall back to the first **Status:** line anywhere. Returns
    None if no well-formed Status line exists (unrecoverable)."""
    m = SPEC_REVIEW_HEADER_RE.search(text)
    scope = text[m.start():] if m else text
    sm = STATUS_RE.search(scope)
    if sm:
        return sm.group(1)
    # header found but no Status inside its scope → try whole doc as last resort
    if m:
        sm = STATUS_RE.search(text)
        if sm:
            return sm.group(1)
    return None


def extract_claude_issues(text: str) -> tuple[list[dict] | None, bool]:
    """Parse the LAST ```spec-review-issues fenced block (anti-injection,
    symmetric to codex last-fenced-block). Returns (issues, degraded).
    degraded=True when no well-formed sentinel block yields a JSON {issues:[...]}.
    """
    blocks = SENTINEL_RE.findall(text)
    if not blocks:
        return None, True
    try:
        payload = json.loads(blocks[-1])
    except json.JSONDecodeError:
        return None, True
    if not isinstance(payload, dict) or not isinstance(payload.get("issues"), list):
        return None, True
    issues = []
    for it in payload["issues"]:
        if not isinstance(it, dict):
            continue
        issues.append({
            "category": str(it.get("category", "")),
            "target_section": str(it.get("target_section", "")),
            "severity": str(it.get("severity", "")).lower(),
            "message": str(it.get("message", "")),
        })
    return issues, False


# --- codex side --------------------------------------------------------------
def parse_codex_yaml(path: str) -> tuple[list[dict], bool, str]:
    """Line-parse codex_findings_to_yaml.py output (known shape). Returns
    (findings, codex_failed, reason). Missing file → failed."""
    if not path or not os.path.isfile(path):
        return [], True, "codex_yaml_missing"
    findings: list[dict] = []
    failed = False
    reason = ""
    section = None
    cur: dict | None = None
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for raw in fh.readlines():
            line = raw.rstrip("\n")
            if line.startswith("findings:"):
                section = "findings"
                if "[]" in line:
                    section = None
                continue
            if line.startswith("meta:"):
                if cur:
                    findings.append(cur); cur = None
                section = "meta"
                continue
            if section == "findings":
                if line.strip().startswith("- "):
                    if cur:
                        findings.append(cur)
                    cur = {}
                    # first inline key may follow "- "
                    rest = line.strip()[2:]
                    if ":" in rest:
                        k, _, v = rest.partition(":")
                        cur[k.strip()] = _yaml_unscalar(v.strip())
                elif ":" in line and cur is not None:
                    k, _, v = line.strip().partition(":")
                    cur[k.strip()] = _yaml_unscalar(v.strip())
            elif section == "meta":
                if ":" in line:
                    k, _, v = line.strip().partition(":")
                    k = k.strip(); v = v.strip()
                    if k == "codex_failed":
                        failed = (v == "true")
                    elif k == "reason":
                        reason = _yaml_unscalar(v)
    if cur:
        findings.append(cur)
    return findings, failed, reason


def _yaml_unscalar(v: str):
    v = v.strip()
    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        try:
            return json.loads(v)
        except json.JSONDecodeError:
            return v[1:-1]
    return v


def derive_codex_verdict(findings: list[dict]) -> str:
    for f in findings:
        if str(f.get("severity", "")).lower() in CODEX_SEVERITY_REVISE:
            return "needs_revise"
    return "approved"


# --- merge -------------------------------------------------------------------
def conservative(a: str, b: str) -> str:
    return INV_RANK[max(RANK[a], RANK[b])]


def _yaml_scalar(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if any(c in s for c in ":#\"'\n") or s.strip() != s:
        return json.dumps(s)
    return s


def load_history(path: str) -> list[dict]:
    if not path or not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return []
    ih = data.get("issue_history") if isinstance(data, dict) else None
    return ih if isinstance(ih, list) else []


def build_ledger(claude_issues, codex_findings, claude_degraded, codex_avail, history):
    """Task 6 STUB — pass-through. Task 7 replaces this with the real
    union-increment + unified-ledger stagnation scan."""
    return history, {"per_issue": [], "round_level": False}


def emit(result: dict) -> str:
    out = []
    for k in ("combined_verdict", "claude_verdict", "codex_verdict",
              "codex_degraded", "claude_degraded", "claude_verdict_unrecoverable"):
        out.append(f"{k}: {_yaml_scalar(result[k])}")
    stg = result["stagnation"]
    out.append("stagnation:")
    out.append(f"  per_issue: {json.dumps(stg['per_issue'])}")
    out.append(f"  round_level: {_yaml_scalar(stg['round_level'])}")
    out.append("issue_history:")
    if not result["issue_history"]:
        out[-1] = "issue_history: []"
    else:
        for r in result["issue_history"]:
            out.append("  - " + json.dumps(r, sort_keys=True))
    out.append("advisory:")
    if not result["advisory"]:
        out[-1] = "advisory: []"
    else:
        for a in result["advisory"]:
            out.append(f"  - {_yaml_scalar(a)}")
    return "\n".join(out) + "\n"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--claude-output", required=True)
    p.add_argument("--codex-yaml", required=True)
    p.add_argument("--history", required=True)
    args = p.parse_args()

    claude_text = ""
    if os.path.isfile(args.claude_output):
        with open(args.claude_output, "r", encoding="utf-8", errors="replace") as fh:
            claude_text = fh.read()

    claude_verdict = extract_claude_verdict(claude_text)
    claude_issues, claude_degraded = extract_claude_issues(claude_text)
    codex_findings, codex_failed, codex_reason = parse_codex_yaml(args.codex_yaml)
    codex_avail = not codex_failed
    codex_verdict = derive_codex_verdict(codex_findings) if codex_avail else None

    advisory: list[str] = []
    claude_unrecoverable = claude_verdict is None

    # --- degrade hierarchy (§9 matrix) ---
    if not claude_unrecoverable and codex_avail:
        # both non-None in this branch (claude_unrecoverable False ⇒ claude_verdict set;
        # codex_avail True ⇒ codex_verdict derived) — narrow for the str×str merge.
        assert claude_verdict is not None and codex_verdict is not None
        combined = conservative(claude_verdict, codex_verdict)
    elif not claude_unrecoverable and not codex_avail:
        combined = claude_verdict
        advisory.append(
            f"[spec-distill v0.20.0] codex co-review degraded (reason: {codex_reason or 'unavailable'}) "
            f"— Claude-only, model diversity 없음. combined = Claude verdict.")
    elif claude_unrecoverable and codex_avail:
        combined = codex_verdict
        advisory.append(
            "[spec-distill v0.20.0] Claude verdict unrecoverable (no **Status:** line) "
            "— combined = codex verdict alone.")
    else:  # both unrecoverable
        combined = "needs_revise"  # fail-safe (non-approve); crash·fail-open 금지
        advisory.append(
            "[spec-distill v0.20.0] review indeterminate (Claude verdict unrecoverable "
            "AND codex unavailable) — combined = needs_revise fail-safe, 원장 미갱신.")

    if claude_degraded and not claude_unrecoverable:
        advisory.append(
            "[spec-distill v0.20.0] Claude issue block unparseable (sentinel malformed) "
            "— verdict recovered from **Status:**, this round's Claude issues skipped in ledger.")

    # --- ledger (Task 6 stub; Task 7 real) ---
    both_dead = claude_unrecoverable and not codex_avail
    history = load_history(args.history)
    if both_dead:
        new_history, stagnation = history, {"per_issue": [], "round_level": "inconclusive"}
    else:
        new_history, stagnation = build_ledger(
            claude_issues if not claude_degraded else [],
            codex_findings if codex_avail else [],
            claude_degraded, codex_avail, history,
        )

    result = {
        "combined_verdict": combined,
        "claude_verdict": claude_verdict if claude_verdict else None,
        "codex_verdict": codex_verdict if codex_verdict else None,
        "codex_degraded": not codex_avail,
        "claude_degraded": claude_degraded,
        "claude_verdict_unrecoverable": claude_unrecoverable,
        "stagnation": stagnation,
        "issue_history": new_history,
        "advisory": advisory,
    }
    sys.stdout.write(emit(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
