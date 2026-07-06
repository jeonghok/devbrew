#!/usr/bin/env python3
"""secret-scan.py — the sole content hard-block for PR-understanding publish.

Targets VALUES, not identifiers (design §7). FAIL CLOSED: any error/unreadable
→ scan_ok: no. The orchestrator gates on the literal `scan_ok: yes` line, NEVER
on exit code (a pipe can swallow the code — v2.7.0 fail-open lesson).

Usage: secret-scan.py --payload <file> --corpus <file>
"""
from __future__ import annotations
import argparse
import math
import re
import sys
from collections import Counter

ENTROPY_THRESHOLD = 4.0   # bits/char. Shannon H ≤ log2(len); len<16 ⇒ H<4.0
MIN_ENTROPY_LEN = 16      # (log2(15)=3.907) ⇒ entropy path unreachable <16 chars.

KNOWN_PATTERNS = [
    ("aws-access-key", re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("github-token", re.compile(r"\b(ghp|gho|ghs|ghu)_[A-Za-z0-9]{36,}\b")),
    ("github-pat", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{22,}\b")),
    ("slack-token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("google-api-key", re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b")),
    ("stripe-key", re.compile(r"\b(sk|rk)_live_[0-9A-Za-z]{24,}\b")),
    ("pem-private-key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}")),
    # Scheme-AGNOSTIC credential-in-URL: any `scheme://[user]:pass@host`, not just
    # http(s) — DB/broker connection strings (postgres://, mysql://, redis://:pass@,
    # mongodb://, amqp://) leak low-entropy passwords the entropy heuristic misses.
    # userinfo user part is OPTIONAL (`[^\s/:@]*`) so password-only `redis://:pass@`
    # is caught. This is a KNOWN pattern (corpus-independent) precisely because a
    # low-entropy URL password can never cross the entropy floor.
    ("credential-url", re.compile(r"\b[a-zA-Z][a-zA-Z0-9+.\-]*://[^\s/:@]*:[^\s/:@]+@")),
]
KEYWORD = re.compile(r"(?i)\b(password|passwd|secret|token|api[_-]?key|apikey|access[_-]?key)\b")
ASSIGN = re.compile(r"[:=]\s*(.+)$")
QUOTED = re.compile(r"""(['"])([^'"]{8,})\1""")
# SECRET_TOKEN excludes '/' and '.' so file paths (src/x.ts) tokenize into their
# short segments and are never treated as one high-entropy blob (design §8).
SECRET_TOKEN = re.compile(r"[A-Za-z0-9_+=-]{16,}")


def shannon(s: str) -> float:
    if not s:
        return 0.0
    n = len(s)
    return -sum((c / n) * math.log2(c / n) for c in Counter(s).values())


def normalize(text: str) -> str:
    text = re.sub(r"```[a-zA-Z0-9]*", "", text)   # markdown-unwrap code fences
    return text.replace("`", "")


def _known(s: str):
    for name, pat in KNOWN_PATTERNS:
        if pat.search(s):
            return name
    return None


def _looks_secret(tok: str) -> bool:
    """Opaque, secret-shaped: a known vendor pattern, OR a ≥16-char run that mixes
    letters AND digits with Shannon ≥ 4.0. Pure-alpha identifiers
    (authenticateUserWithToken, StripeWebhookHandler), file paths (contain '/',
    excluded by SECRET_TOKEN), and hex/SHA (entropy < 4.0) are NOT secret-shaped —
    reconciles §7(b) with the §8 mandate that identifiers/paths stay nameable."""
    if _known(tok):
        return True
    if not SECRET_TOKEN.fullmatch(tok):
        return False
    return bool(re.search(r"[A-Za-z]", tok) and re.search(r"[0-9]", tok)
                and len(tok) >= MIN_ENTROPY_LEN and shannon(tok) >= ENTROPY_THRESHOLD)


def _high_entropy_in_corpus(s: str, corpus: str):
    for tok in SECRET_TOKEN.findall(s):
        if _looks_secret(tok) and tok in corpus:
            return "high-entropy-in-corpus"
    return None


def _quoted_source_value(s: str, corpus: str):
    for q in QUOTED.finditer(s):
        v = q.group(2)
        if v in corpus and _looks_secret(v):
            return "quoted-source-value"
    return None


def value_shaped(rhs: str, corpus: str):
    """RHS is value-shaped iff one of the three value blockers matches. Low-entropy
    dictionary RHS (type names/identifiers) returns None regardless of length."""
    return _known(rhs) or _high_entropy_in_corpus(rhs, corpus) or _quoted_source_value(rhs, corpus)


def scan(payload: str, corpus: str):
    findings = []
    for raw in normalize(payload).splitlines():
        line = raw.strip()
        if not line:
            continue
        hit = _known(line) or _high_entropy_in_corpus(line, corpus) or _quoted_source_value(line, corpus)
        if not hit and KEYWORD.search(line):          # keyword = subordinate refinement
            m = ASSIGN.search(line)
            if m:
                why = value_shaped(m.group(1).strip(), corpus)
                if why:
                    hit = f"keyword+{why}"
        if hit:
            findings.append(f"finding: {hit} [redacted]")
    return findings


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--payload", required=True)
    ap.add_argument("--corpus", required=True)
    args = ap.parse_args()
    try:
        payload = open(args.payload, encoding="utf-8", errors="replace").read()
        corpus = open(args.corpus, encoding="utf-8", errors="replace").read()
        # Corpus-integrity precondition (FAIL CLOSED): the two corpus-gated
        # detectors (_high_entropy_in_corpus / _quoted_source_value) silently
        # no-op on a degraded/thin corpus, leaving only the 9 vendor patterns.
        # build-pr-context.sh signals a degraded (no-merge-base) corpus with a
        # `=== PR CONTEXT (degraded: ...` header line; treat that as un-scannable,
        # not clean. Anchored on the exact header (^, MULTILINE) so file contents
        # that merely mention "degraded" never false-trigger the block.
        if re.search(r"^=== PR CONTEXT \(degraded", corpus, re.MULTILINE):
            print("scan_ok: no")
            print("finding: corpus degraded (no merge-base) — fail-closed")
            return 2
        findings = scan(payload, corpus)
    except Exception as e:                             # FAIL CLOSED
        print("scan_ok: no")
        print(f"finding: scan error ({type(e).__name__}) — fail-closed")
        return 2
    if findings:
        print("scan_ok: no")
        for f in findings:
            print(f)
        return 1
    print("scan_ok: yes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
