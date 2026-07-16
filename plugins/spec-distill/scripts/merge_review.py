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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compute_issue_id  # noqa: E402  (sibling helper, centralized id — §8)

# --- verdict precedence (§7b) ------------------------------------------------
RANK = {"approved": 0, "needs_revise": 1, "needs_interview": 2}
INV_RANK = {v: k for k, v in RANK.items()}
CODEX_SEVERITY_REVISE = {"block", "high"}
# The prompt-enumerated codex severity vocabulary (build_spec_codex_prompt.py).
# "medium" is the ONE recognized non-escalating value (§8: advisory surface).
# Any severity outside this set — missing ("") or off-vocab from LLM drift
# ("critical", "blocker") — is treated as escalating (fail-closed): the unsafe
# direction for a severe-but-mislabeled finding is to resolve toward approved.
CODEX_SEVERITY_KNOWN = {"block", "high", "medium"}

SENTINEL_RE = re.compile(r"```spec-review-issues[ \t]*\n(.*?)\n?```", re.DOTALL)
STATUS_RE = re.compile(
    r"^\*\*Status:\*\*\s*(approved|needs_revise|needs_interview)\b", re.MULTILINE
)
SPEC_REVIEW_HEADER_RE = re.compile(r"^##\s+Spec Review\b", re.MULTILINE)


# --- Claude side -------------------------------------------------------------
def extract_claude_verdict(text: str) -> str | None:
    """OQ3: first **Status:** line at/after the '## Spec Review' header; if the
    header is absent, fall back to the first **Status:** line anywhere. Returns
    None if no well-formed Status line exists (unrecoverable).

    No whole-text fallback when the header IS found but its scope has no valid
    Status line: re-searching from position 0 in that case would let a
    pre-header **Status:**-shaped line (echoed reviewed-doc content, a quoted
    prior transcript, or spec-reviewer.md's own output-format docs) get
    scavenged — a fail-open. Unrecoverable in that case is correct; the
    both-degraded fail-safe (needs_revise) takes over downstream."""
    m = SPEC_REVIEW_HEADER_RE.search(text)
    scope = text[m.start():] if m else text
    sm = STATUS_RE.search(scope)
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
    (findings, codex_failed, reason).

    Fail-CLOSED (opt-in-to-success). The well-formed producer contract ALWAYS
    emits a `meta:` block carrying `codex_failed: true|false`
    (codex_findings_to_yaml.py + every run_spec_codex_reviewer.sh fallback). A
    present-but-empty / truncated / markerless file — e.g. OUTPUT_PATH left
    0-byte by an external SIGKILL/OOM/disk-full mid-write — lacks that key.
    Absence of a success token is treated as FAILURE, not as a successful empty
    review: trusting a markerless file would resolve codex to `approved` with
    NO degrade advisory, silently defeating the human-gate backstop that every
    other degrade path raises. Missing file → failed."""
    if not path or not os.path.isfile(path):
        return [], True, "codex_yaml_missing"
    findings: list[dict] = []
    failed = False
    reason = ""
    saw_failed_key = False  # opt-in-to-success sentinel: a valid run sets this
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
                        saw_failed_key = True
                        failed = (v == "true")
                    elif k == "reason":
                        reason = _yaml_unscalar(v)
    if cur:
        findings.append(cur)
    # opt-in-to-success: no explicit codex_failed marker ⇒ the file is empty,
    # truncated, or malformed ⇒ fail-closed (never trust a markerless file as a
    # clean codex run). Discard any partial findings — an untrusted file's
    # content must not feed the verdict or the ledger.
    if not saw_failed_key:
        return [], True, "codex_yaml_malformed"
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
    """approved unless a finding escalates. Fail-CLOSED on unknown severity:
    escalate on block/high (§7b) AND on any severity outside the recognized
    vocabulary — a MISSING or OFF-VOCAB value (e.g. "", "critical", "blocker"
    from LLM drift) escalates to needs_revise rather than silently resolving
    toward approved. Only an explicitly-recognized "medium" (§8 advisory-only)
    is non-escalating."""
    for f in findings:
        sev = str(f.get("severity", "")).lower()
        if sev in CODEX_SEVERITY_REVISE or sev not in CODEX_SEVERITY_KNOWN:
            return "needs_revise"
    return "approved"


# display keys surfaced for codex_findings (transient current-round display
# block — see build_codex_findings_display docstring).
CODEX_DISPLAY_KEYS = ("category", "target_section", "severity", "summary")


def build_codex_findings_display(codex_findings: list[dict], codex_avail: bool) -> list[dict]:
    """Project THIS round's parsed codex findings down to a display-only
    shape (category/target_section/severity/summary, whichever present).

    §5 requires surfacing codex issues with source labels — the persistent
    issue_history ledger only keeps {id, raised_count, dismissed_by_user,
    source, resolved} (category/severity/summary are parsed for verdict/id
    then discarded there). Without a content channel, codex issues reach the
    Human Gate as opaque 12-hex ids while Claude issues reach the author via
    prose. This is a TRANSIENT current-round display block, separate from
    the persistent ledger — it is NOT written back to --history."""
    if not codex_avail or not codex_findings:
        return []
    out = []
    for f in codex_findings:
        if not isinstance(f, dict):
            continue
        out.append({k: f[k] for k in CODEX_DISPLAY_KEYS if k in f})
    return out


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
        # ensure_ascii=False: this repo is Korean-primary and advisories are
        # Korean; escaping them to \uXXXX (sibling check_brief.py avoids this)
        # makes the human-gate advisory unreadable. The output file is UTF-8.
        return json.dumps(s, ensure_ascii=False)
    return s


def _sanitize_history_record(rec: dict) -> dict:
    """Coerce a persisted history record so every downstream int() site is
    safe. dismissed_by_user is USER-EDITABLE (P17) — malformed values (e.g.
    null from a hand-edited history file) are plausible. Global Constraint:
    never crash on malformed input. Well-formed records (raised_count/
    dismissed_by_user already int) round-trip byte-identically."""
    out = dict(rec)
    for key in ("raised_count", "dismissed_by_user"):
        try:
            out[key] = int(out.get(key, 0))
        except (TypeError, ValueError):
            out[key] = 0
    if "resolved" in out and not isinstance(out["resolved"], bool):
        out["resolved"] = bool(out["resolved"])
    return out


def load_history(path: str) -> list[dict]:
    if not path or not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return []
    ih = data.get("issue_history") if isinstance(data, dict) else None
    if not isinstance(ih, list):
        return []
    return [
        _sanitize_history_record(r) for r in ih
        if isinstance(r, dict) and "id" in r
    ]


def _origin_merge(prior_source: str, this_round: set) -> str:
    seen = set()
    if prior_source in ("claude", "codex", "both"):
        seen.update({"claude", "codex"} if prior_source == "both" else {prior_source})
    seen.update(this_round)
    if {"claude", "codex"} <= seen:
        return "both"
    if "codex" in seen:
        return "codex"
    return "claude"


def build_ledger(claude_issues, codex_findings, claude_degraded, history):
    """Union-increment ledger + unified-ledger stagnation scan (§8).

    - raised_count += 1 per id per ROUND (both reviewers flagging = corroboration,
      not double count — AC11).
    - per-issue stagnation: raised_count>=3 AND dismissed_by_user==0 AND the
      id is raised THIS round (AC14), dismissed excluded (P17). The
      this-round gate prevents re-escalating an already-resolved id forever
      (raised_count persists after resolution; membership in this_round_ids
      is the type-safe check, not a `resolved` flag which may be non-bool).
    - round-level (§8): no NEW id this round AND unresolved prior ids persist.
      OQ4: when claude_degraded, the round is 'inconclusive' (a parse failure
      must not read as convergence).
    """
    by_id = {r["id"]: dict(r) for r in history if isinstance(r, dict) and "id" in r}
    prior_ids = set(by_id.keys())

    # ids raised THIS round, tagged by origin.
    round_origin: dict[str, set] = {}
    for it in claude_issues:
        iid = compute_issue_id.compute(it["category"], it["target_section"])
        round_origin.setdefault(iid, set()).add("claude")
    for f in codex_findings:
        cat = str(f.get("category", ""))
        sec = str(f.get("target_section", ""))
        if not cat and not sec:
            continue
        iid = compute_issue_id.compute(cat, sec)
        round_origin.setdefault(iid, set()).add("codex")

    this_round_ids = set(round_origin.keys())

    # mark prior ids not raised this round as resolved; increment raised ids.
    for iid, rec in by_id.items():
        if iid not in this_round_ids:
            rec["resolved"] = True
    for iid, origins in round_origin.items():
        rec = by_id.get(iid) or {"id": iid, "raised_count": 0,
                                  "dismissed_by_user": 0, "source": "", "resolved": False}
        rec["raised_count"] = int(rec.get("raised_count", 0)) + 1
        rec["dismissed_by_user"] = int(rec.get("dismissed_by_user", 0))
        rec["source"] = _origin_merge(rec.get("source", ""), origins)
        rec["resolved"] = False
        by_id[iid] = rec

    new_history = list(by_id.values())

    # per-issue stagnation — gated to ids raised THIS round (type-safe form:
    # membership in this_round_ids, NOT `not rec.get("resolved")`, which is
    # fragile if `resolved` is a non-bool). Without this gate, an id that hit
    # raised_count>=3 and was later fixed (resolved=True, not raised this
    # round) would still land in per_issue forever — re-escalating a
    # resolved issue to the Human Gate every round until the hard cap,
    # defeating convergence.
    per_issue = [rec["id"] for rec in new_history
                 if int(rec.get("raised_count", 0)) >= 3
                 and int(rec.get("dismissed_by_user", 0)) == 0
                 and rec["id"] in this_round_ids]

    # round-level stagnation (OQ4)
    if claude_degraded:
        round_level = "inconclusive"
    else:
        new_ids = this_round_ids - prior_ids
        unresolved_persist = any(
            (iid in this_round_ids) and int(by_id[iid].get("dismissed_by_user", 0)) == 0
            for iid in prior_ids
        )
        round_level = (len(new_ids) == 0 and unresolved_persist)

    return new_history, {"per_issue": per_issue, "round_level": round_level}


def _write_history(path: str, issue_history: list[dict]) -> bool:
    """Persist the ledger atomically (tmp + fsync + os.replace). Returns True on
    success, False on any OSError — the caller raises a LOUD advisory on failure
    (CLAUDE.md loud-degrade; this-round verdict/stagnation stay authoritative on
    stdout regardless). On failure the tmp file is removed so no orphan .tmp is
    left beside the ledger (S-5)."""
    tmp = path + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump({"issue_history": issue_history}, fh, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
        return True
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False


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
    out.append("codex_findings:")
    if not result["codex_findings"]:
        out[-1] = "codex_findings: []"
    else:
        for f in result["codex_findings"]:
            # ensure_ascii=False: codex summaries may be Korean (Korean-primary
            # repo); this is the only content channel for codex findings.
            out.append("  - " + json.dumps(f, sort_keys=True, ensure_ascii=False))
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
        if combined != claude_verdict:
            advisory.append(
                f"[spec-distill v0.20.0] codex co-review가 Claude verdict를 뒤집음 "
                f"(claude={claude_verdict} → combined={combined}, codex={codex_verdict}) "
                f"— codex 독립 판단이 override. 아래 codex_findings 참조.")
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

    # --- ledger (§8): union-increment + unified-ledger stagnation scan ---
    both_dead = claude_unrecoverable and not codex_avail
    history = load_history(args.history)
    if both_dead:
        new_history, stagnation = history, {"per_issue": [], "round_level": "inconclusive"}
    else:
        new_history, stagnation = build_ledger(
            claude_issues if not claude_degraded else [],
            codex_findings if codex_avail else [],
            claude_degraded, history,
        )

    if not both_dead:
        if not _write_history(args.history, new_history):
            advisory.append(
                "[spec-distill v0.20.0] issue_history 원장 기록 실패 (OSError) "
                "— cross-round stagnation 추적이 이번 세션 degraded. verdict와 "
                "이번-라운드 stagnation은 stdout에서 여전히 authoritative.")

    codex_findings_display = build_codex_findings_display(codex_findings, codex_avail)

    result = {
        "combined_verdict": combined,
        "claude_verdict": claude_verdict,
        "codex_verdict": codex_verdict,
        "codex_degraded": not codex_avail,
        "claude_degraded": claude_degraded,
        "claude_verdict_unrecoverable": claude_unrecoverable,
        "stagnation": stagnation,
        "issue_history": new_history,
        "codex_findings": codex_findings_display,
        "advisory": advisory,
    }
    sys.stdout.write(emit(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
