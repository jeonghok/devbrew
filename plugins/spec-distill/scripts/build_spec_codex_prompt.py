#!/usr/bin/env python3
"""build_spec_codex_prompt.py — codex review prompt for a DESIGN DOC.

spec-distill design §6 #2. NOT the qg diff+AC model — this reviews a
brainstorming design doc against the same 6 judgment categories the Claude
spec-reviewer uses (design-mode checklist). Takes the design doc as a FILE PATH
only (never inline content via argv/stdin — injection safety, AC4). The doc is
loaded via read_text and substituted via str.replace (opaque bytes — no parse,
no eval). Output → stdout; caller redirects to a scratch prompt file.

Usage:  build_spec_codex_prompt.py <design_doc_file>

Severity vocab is spec-distill {block, high, medium} to match spec-reviewer.md
and merge_review.py's verdict derivation — NOT qg's CRITICAL/IMPORTANT/SUGGESTION
(vocab drift would break the merge). handoff_incomplete is a mechanical
substring/structure check owned by the existing path, so it is NOT a codex
category here.
"""

from __future__ import annotations

import pathlib
import sys

PROMPT_TEMPLATE = """You are an independent design-doc reviewer. You are reviewing a
brainstorming design document (not code). Do NOT modify any files; you are in a
read-only sandbox.

Review the document below. These six judgment categories are the ones the
downstream merge expects most often — they are a starting vocabulary, not a
closed list:

- placeholder: "TBD", "TODO", "FIXME", "fill in later", or other unfinished text.
- ambiguity: unmeasurable phrasing ("robust", "works correctly", "fast",
  "as needed", "good UX") in goals / acceptance criteria.
- scope_creep: multiple independent subsystems bundled such that a single
  implementation plan cannot cleanly decompose them.
- approaches_comparison: a single approach asserted with no 2-3 alternatives +
  tradeoffs presented.
- isolation: component boundaries / interfaces defined so vaguely that unit
  testing or change isolation is impossible.
- testing: no Verification Plan, or only "manual check" — no automated
  verification procedure.
- other: anything real that none of the six names. Use this freely — a genuine
  problem must never be dropped because no listed category fits it. When you use
  `other`, make the `summary` self-explanatory: it is the only place a reader
  learns what kind of issue this is.

<design_doc>
{{DESIGN_DOC}}
</design_doc>

Output your findings in a fenced JSON code block:

```json
{
  "findings": [
    {
      "category": "placeholder | ambiguity | scope_creep | approaches_comparison | isolation | testing | other",
      "target_section": "<markdown anchor of the offending section, e.g. #2-goals>",
      "severity": "block | high | medium",
      "confidence": <integer 1-10>,
      "summary": "<one sentence>",
      "proposed_fix": "<description>"
    }
  ]
}
```

If you find no issues, emit `{"findings": []}` inside the same code fence.
Do not output any text after the closing fence.
"""


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <design_doc_file>", file=sys.stderr)
        return 2

    doc_path = pathlib.Path(sys.argv[1])
    if not doc_path.is_file():
        print(f"design doc file not found: {doc_path}", file=sys.stderr)
        return 2

    doc = doc_path.read_text(encoding="utf-8", errors="replace")
    out = PROMPT_TEMPLATE.replace("{{DESIGN_DOC}}", doc)
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
