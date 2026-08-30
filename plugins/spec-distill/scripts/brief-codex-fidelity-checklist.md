AXIS-MARKER: brief-fidelity-axis-only

You are reviewing ONE axis only: **fidelity** of an interview brief — whether the
model's summary distorted, dropped, or invented the user's words. You are NOT
judging whether the user's direction is a good idea, and you are NOT looking for
better alternatives. A separate reviewer owns that axis.

The ground truth is the block after `<<<AUDIT-VERBATIM>>>` (the verbatim user
statements). Everything in §2 제약 and the frontmatter `user_sourced_items` is a
model-written summary of it, anchored by `evidence: S<N>`. Compare them.

Check EACH of these six categories explicitly and report per-category:

- `distortion` — a §2 statement changes the meaning of the `S<N>` original it cites.
- `omission` — something load-bearing after `<<<AUDIT-VERBATIM>>>` is missing from §2.
- `insertion` — a constraint appears in §2 that the user never said.
- `provenance_mislabel` — the 🗣 (user said) / ☑ (user chose) / ✎ (model inferred)
  marker, or `source: verbatim|chosen`, is wrong for that item.
- `authority_syntax` — authority-closing phrasing has crept back in: language that
  declares a decision final and forecloses reopening it, or a schema field name that
  implies a decision is pinned shut rather than merely recorded. The brief records
  direction; it does not forbid revisiting it.
- `evidence_unsupported` — `evidence: S<N>` points at a real anchor, but that
  statement (in the block after `<<<AUDIT-VERBATIM>>>`) does not actually support
  the §2 claim. The structural gate only checks that the anchor exists; this is the
  axis a machine cannot close.

Every finding MUST quote the `S<N>` anchor it relies on, so the author can check you.

You may read the whole repository. Note that you can see files the isolated Claude
reviewer cannot — the orchestrator labels your findings `codex_isolated: false` and
weighs that when reading them, and it never uses that label to lower a finding's grade.

Output your findings in a fenced JSON code block:

```json
{
  "findings": [
    {
      "category": "distortion | omission | insertion | provenance_mislabel | authority_syntax | evidence_unsupported",
      "target_section": "<markdown anchor, e.g. #2-제약>",
      "severity": "block | high | medium",
      "confidence": <integer 1-10>,
      "summary": "<one sentence>",
      "proposed_fix": "<what to change + the `S<N>` anchor you relied on>"
    }
  ]
}
```

If you find no issues, emit `{"findings": []}` inside the same code fence. Do not
output any text after the closing fence.
