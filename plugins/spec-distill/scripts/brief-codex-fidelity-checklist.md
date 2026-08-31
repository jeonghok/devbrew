AXIS-MARKER: brief-fidelity-axis-only

You are reviewing ONE axis only: **fidelity** of an interview brief — whether the
model's summary distorted, dropped, or invented the user's words. You are NOT
judging whether the user's direction is a good idea, and you are NOT looking for
better alternatives. A separate reviewer owns that axis.

The ground truth is ALL of the user's verbatim statements, and they sit in **two**
places in the document you were given: the payload's own `## 6. 사용자 원문` section
(the original request, `S1`) and the block after `<<<AUDIT-VERBATIM>>>` (`S2` and up).
**Both are ground truth.** If you read only one, every item whose `evidence:` is `S1`
has no original to compare against, and you cannot judge its `distortion` or
`evidence_unsupported`. Everything in §2 제약 and the frontmatter `user_sourced_items`
is a model-written summary of that ground truth, anchored by `evidence: S<N>`.
Compare them.

Check EACH of these six categories explicitly and report per-category:

- `distortion` — a §2 statement changes the meaning of the `S<N>` original it cites.
- `omission` — something load-bearing is missing from §2. Scan **both** ground-truth
  locations for this one: the payload's `## 6. 사용자 원문` section and the
  `<<<AUDIT-VERBATIM>>>` block. Every other category follows an `S<N>` anchor to its
  original; this one has no anchor to follow, so reading half the corpus silently
  yields "nothing missing".
- `insertion` — a constraint appears in §2 that the user never said.
- `provenance_mislabel` — the 🗣 (user said) / ☑ (user chose) / ✎ (model inferred)
  marker, or `source: verbatim|chosen`, is wrong for that item.
- `authority_syntax` — authority-closing phrasing has crept back in: language that
  declares a decision final and forecloses reopening it, or a schema field name that
  implies a decision is pinned shut rather than merely recorded. The brief records
  direction; it does not forbid revisiting it.
- `evidence_unsupported` — `evidence: S<N>` points at a real anchor, but that
  statement (in whichever of the two ground-truth locations carries `S<N>`) does not
  actually support the §2 claim. The structural gate only checks that the anchor
  exists; this is the axis a machine cannot close.

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
