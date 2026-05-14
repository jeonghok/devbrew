#!/usr/bin/env python3
"""build_codex_prompt.py — Construct codex review prompt from input files.

Reads filtered_diff and gate1_summary from argv file paths. NEVER takes
inline content via argv or stdin — always file paths. Substitutes into a
template using str.replace (no shell, no python eval, no triple-quote).
Writes the assembled prompt to stdout.

Usage:
  python3 build_codex_prompt.py <diff_file> <plan_summary_file>

Why: Inlining reviewed-PR content (diff) into shell or Python string
literals creates an injection vector (Critical issue C1 from Task 4
review). Always pass via filesystem path.

The prompt template is embedded as a Python multiline string. Inputs are
loaded via pathlib.Path.read_text() and substituted via str.replace,
which treats inputs as opaque bytes — no parsing, no escaping, no
evaluation. Output goes to stdout; caller redirects to a scratch file.
"""

from __future__ import annotations

import pathlib
import sys

PROMPT_TEMPLATE = """You are a code reviewer. Review the diff for bugs, silent failures,
security issues, missing error handling, and design problems. Do not
modify any files; you are in a read-only sandbox.

<diff>
{{FILTERED_DIFF}}
</diff>

<plan_context>
{{PLAN_SUMMARY}}
</plan_context>

Output your findings in a fenced JSON code block:

```json
{
  "findings": [
    {
      "file": "<path>",
      "line": <integer>,
      "severity": "CRITICAL | IMPORTANT | SUGGESTION",
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
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <diff_file> <plan_summary_file>", file=sys.stderr)
        return 2

    diff_path = pathlib.Path(sys.argv[1])
    plan_path = pathlib.Path(sys.argv[2])

    if not diff_path.is_file():
        print(f"diff file not found: {diff_path}", file=sys.stderr)
        return 2
    if not plan_path.is_file():
        print(f"plan summary file not found: {plan_path}", file=sys.stderr)
        return 2

    diff_content = diff_path.read_text(encoding="utf-8", errors="replace")
    plan_content = plan_path.read_text(encoding="utf-8", errors="replace")

    out = PROMPT_TEMPLATE.replace("{{FILTERED_DIFF}}", diff_content)
    out = out.replace("{{PLAN_SUMMARY}}", plan_content)
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
