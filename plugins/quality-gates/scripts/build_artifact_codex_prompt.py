#!/usr/bin/env python3
"""build_artifact_codex_prompt.py — construct a codex artifact-critique prompt.

Reads the artifact content from a filesystem PATH only (never inline argv/stdin
— injection mitigation, cf. build_codex_prompt.py). Substitutes via str.replace
(no shell, no eval). Writes the prompt to stdout.

Usage: build_artifact_codex_prompt.py <artifact_path>
"""
from __future__ import annotations

import pathlib
import sys

PROMPT_TEMPLATE = """You are an artifact critic. Review the NON-CODE artifact below for
logical gaps, unstated assumptions, incompleteness, unsupported claims,
ambiguity, weak actionability, and structural problems. Do NOT modify any
files; you are in a read-only sandbox. Do NOT invent facts to fill a gap —
flag "no supporting evidence" instead of fabricating a replacement.

Use these rubric axes as the `category` value:
- logic — internal contradiction / inconsistency
- assumption — unstated premise asserted without support
- completeness — missing section / uncovered case
- evidence — unsupported factual claim (flag; never fabricate)
- ambiguity — a sentence that reads two ways
- actionability — a spec/plan item that cannot be verified
- structure — ordering / duplication / readability

<artifact>
{{ARTIFACT}}
</artifact>

Emit findings in ONE fenced yaml block and nothing after it:

```yaml
findings:
  - agent: codex-reviewer
    category: logic
    target_anchor: "#section-anchor-or-heading"
    target_lines: "12-18"
    severity: IMPORTANT
    summary: "one sentence"
    proposed_fix: "optional suggested revision"
```

If you find nothing, emit `findings: []` inside the same fence. Use a
round-stable section anchor/heading for `target_anchor` (never a raw line
number), so an unresolved finding keeps a stable identity across rounds.
"""


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <artifact_path>", file=sys.stderr)
        return 2
    p = pathlib.Path(sys.argv[1])
    if not p.is_file():
        print(f"artifact not found: {p}", file=sys.stderr)
        return 2
    content = p.read_text(encoding="utf-8", errors="replace")
    sys.stdout.write(PROMPT_TEMPLATE.replace("{{ARTIFACT}}", content))
    return 0


if __name__ == "__main__":
    sys.exit(main())
