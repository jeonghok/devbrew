#!/usr/bin/env python3
"""build_codex_prompt.py — Construct codex review prompt from input files.

Reads filtered_diff and the intent-source file from argv file paths. NEVER
takes inline content via argv or stdin — always file paths. Substitutes into a
template using str.replace (no shell, no python eval, no triple-quote).
Writes the assembled prompt to stdout.

Usage:
  python3 build_codex_prompt.py <diff_file> <intent_file>

Why: Inlining reviewed-PR content (diff) into shell or Python string
literals creates an injection vector (Critical issue C1 from Task 4
review). Always pass via filesystem path.

The prompt template is embedded as a Python multiline string. Inputs are
loaded via pathlib.Path.read_text() and substituted via str.replace,
which treats inputs as opaque bytes — no parsing, no escaping, no
evaluation. Output goes to stdout; caller redirects to a scratch file.

The <intent_file> is what discover-spec.sh wrote (a spec, or commit messages
and the open PR body). The caller passes /dev/null when the intent input is
off; any non-regular-file is empty intent, not an error. The criteria block
comes from the plugin's references/review-criteria.md — the same text every
reviewer receives; a missing or empty block is exit 2.
"""

from __future__ import annotations

import pathlib
import re
import sys

# stdout 인코딩 가드와 P21 프리앰블 로더는 형제 사본 `codex_prompt_common.py` 가 갖는다
# (정본 `shared/codex/codex_prompt_common.py`). 형제 import 는 sys.path[0] 에서 풀린다.
from codex_prompt_common import (
    P21_PREAMBLE_PATH,
    configure_stdout,
    load_p21_preamble,
)

configure_stdout()

CRITERIA_PATH = pathlib.Path(__file__).resolve().parent.parent / "references" / "review-criteria.md"


PROMPT_TEMPLATE = """You are a code reviewer. Review the diff for bugs, silent failures,
security issues, and missing error handling. Do not modify any files; you are
in a read-only sandbox.

Set each finding's severity by this rule — CRITICAL or IMPORTANT only when the
finding meets one of the blocking conditions; everything else is SUGGESTION:

{{CRITERIA}}

The <intent> block below is the intent source (a spec, or commit messages and
the PR body). A change that violates a requirement written there is blocking.

{{P21_PREAMBLE}}

<diff>
{{FILTERED_DIFF}}
</diff>

<intent>
{{INTENT}}
</intent>

Output your findings in a fenced JSON code block:

```json
{
  "findings": [
    {
      "file": "<path>",
      "line": <integer>,
      "severity": "CRITICAL | IMPORTANT | SUGGESTION",
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
        print(f"Usage: {sys.argv[0]} <diff_file> <intent_file>", file=sys.stderr)
        return 2

    diff_path = pathlib.Path(sys.argv[1])
    intent_path = pathlib.Path(sys.argv[2])

    if not diff_path.is_file():
        print(f"diff file not found: {diff_path}", file=sys.stderr)
        return 2

    diff_content = diff_path.read_text(encoding="utf-8", errors="replace")
    intent_content = (intent_path.read_text(encoding="utf-8", errors="replace")
                      if intent_path.is_file() else "")

    try:
        criteria = CRITERIA_PATH.read_text(encoding="utf-8").strip("\n")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"리뷰 기준을 읽을 수 없다: {CRITERIA_PATH} ({exc})", file=sys.stderr)
        return 2
    if not criteria.strip():
        print(f"리뷰 기준이 비어 있다: {CRITERIA_PATH}", file=sys.stderr)
        return 2

    try:
        p21 = load_p21_preamble()
    except (OSError, UnicodeDecodeError) as exc:
        print(f"P21 프리앰블을 읽을 수 없다: {P21_PREAMBLE_PATH} ({exc})", file=sys.stderr)
        return 2
    if not p21.strip():
        print(f"P21 프리앰블이 비어 있다: {P21_PREAMBLE_PATH}", file=sys.stderr)
        return 2

    # 한 번에 치환한다 — 이미 들어간 diff·의도 안의 `{{...}}` 리터럴이 다시 치환되지 않는다.
    values = {
        "CRITERIA": criteria,
        "P21_PREAMBLE": p21,
        "FILTERED_DIFF": diff_content,
        "INTENT": intent_content,
    }
    out = re.sub(r"\{\{(CRITERIA|P21_PREAMBLE|FILTERED_DIFF|INTENT)\}\}",
                 lambda m: values[m.group(1)], PROMPT_TEMPLATE)
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
