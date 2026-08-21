#!/usr/bin/env python3
"""build_codex_prompt.py — Construct codex review prompt from input files.

Reads filtered_diff and an optional spec-AC file from argv file paths. NEVER
takes inline content via argv or stdin — always file paths. Substitutes into a
template using str.replace (no shell, no python eval, no triple-quote).
Writes the assembled prompt to stdout.

Usage:
  python3 build_codex_prompt.py <diff_file> <spec_ac_file>

Why: Inlining reviewed-PR content (diff) into shell or Python string
literals creates an injection vector (Critical issue C1 from Task 4
review). Always pass via filesystem path.

The prompt template is embedded as a Python multiline string. Inputs are
loaded via pathlib.Path.read_text() and substituted via str.replace,
which treats inputs as opaque bytes — no parsing, no escaping, no
evaluation. Output goes to stdout; caller redirects to a scratch file.

The <spec_ac_file> carries the Acceptance Criteria SECTION of the project
spec (extracted upstream by run_codex_reviewer.sh — this script does no
parsing). The caller passes /dev/null (a char device, not a regular file)
when no spec was found; this script treats any non-regular-file as empty
context rather than erroring — only a real spec AC file contributes text.
"""

from __future__ import annotations

import pathlib
import sys

# stdout 인코딩 가드와 P21 프리앰블 로더는 **형제 사본** `codex_prompt_common.py` 가
# 갖는다(정본 `shared/codex/codex_prompt_common.py`). 네 빌더가 같은 블록을 주석까지
# 바이트 동일하게 각자 갖고 있었고, P21 은 보안 컨트롤이라 한 곳만 고치면 나머지가
# 조용히 옛 문구를 계속 내보낸다. 형제 import 는 sys.path[0](= 실행되는 스크립트 자신의
# 디렉토리)에서 풀린다 — 그래서 배포 지점마다 물리 사본이 있어야 하고, 그 ∀ 계약은
# shared/tests/test_copy_of_contract.sh 축 1c 가 진다.
from codex_prompt_common import (
    P21_PREAMBLE_PATH,
    configure_stdout,
    load_p21_preamble,
)

# import 부수효과가 아니라 **명시적 호출**이다 — import 만으로 프로세스 전역 상태가
# 바뀌면 그 사실이 호출부에서 안 보인다.
configure_stdout()


PROMPT_TEMPLATE = """You are a code reviewer. Review the diff for bugs, silent failures,
security issues, missing error handling, and design problems. Do not
modify any files; you are in a read-only sandbox.

{{P21_PREAMBLE}}

<diff>
{{FILTERED_DIFF}}
</diff>

<spec_context>
{{SPEC_AC}}
</spec_context>

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
        print(f"Usage: {sys.argv[0]} <diff_file> <spec_ac_file>", file=sys.stderr)
        return 2

    diff_path = pathlib.Path(sys.argv[1])
    spec_ac_path = pathlib.Path(sys.argv[2])

    if not diff_path.is_file():
        print(f"diff file not found: {diff_path}", file=sys.stderr)
        return 2

    diff_content = diff_path.read_text(encoding="utf-8", errors="replace")
    # Spec AC is optional. The canonical "no spec found" path passes /dev/null
    # (a char device, not a regular file); upstream run_codex_reviewer.sh also
    # passes /dev/null when DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1. Treat any
    # non-regular-file as empty context rather than erroring — only a real spec
    # AC file contributes text.
    if spec_ac_path.is_file():
        spec_content = spec_ac_path.read_text(encoding="utf-8", errors="replace")
    else:
        spec_content = ""

    try:
        p21 = load_p21_preamble()
    except (OSError, UnicodeDecodeError) as exc:
        print(f"P21 프리앰블을 읽을 수 없다: {P21_PREAMBLE_PATH} ({exc})", file=sys.stderr)
        return 2
    if not p21.strip():
        print(f"P21 프리앰블이 비어 있다: {P21_PREAMBLE_PATH}", file=sys.stderr)
        return 2

    out = PROMPT_TEMPLATE.replace("{{P21_PREAMBLE}}", p21)
    out = out.replace("{{FILTERED_DIFF}}", diff_content)
    out = out.replace("{{SPEC_AC}}", spec_content)
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
