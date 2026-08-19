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
import re
import sys

# stdout 인코딩은 프로세스 locale/PYTHONIOENCODING을 따른다(read_text의 명시적
# encoding="utf-8"과 달리) — 고정하지 않으면 ascii 계열 인코딩에서 한국어 절이
# UnicodeEncodeError로 프로세스를 죽인다. reconfigure는 TextIOWrapper에만 있고
# sys.stdout을 채울 수 있는 모든 객체에 있지는 않으므로 형제 관용구(둘 다
# plugins/spec-distill/ 하위 — review-dispatch.py 모듈 최상단의 stdin/stdout/stderr
# reconfigure 루프, check_verbatim_coverage.py의 main()이 쓰는 stdout/stderr guard)와
# 같이 guard한다. 단 그 둘이 잡는 예외 클래스가 서로 다르다(전자 AttributeError·OSError,
# 후자 AttributeError·ValueError) — 닫힌 TextIOWrapper는 ValueError를 낸다(실측)로
# 여기서는 합집합을 잡는다.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
except (AttributeError, OSError, ValueError):
    pass

# P21 프리앰블은 **형제 파일**에서 읽는다 — 이 경로는 `shared/codex/prompt-preamble.md`
# 를 가리키는 상대 심볼릭 링크이고, 설치 시점에 실제 내용으로 역참조되어 배포 트리 안으로
# 들어온다(설계 §2.2·§16.1). 런타임에 `shared/` 로 나가지 않는다 — `${CLAUDE_PLUGIN_ROOT}`
# 에서 그곳은 도달 불가다(§2.1).
P21_PREAMBLE_PATH = pathlib.Path(__file__).resolve().parent / "prompt-preamble.md"
P21_MARKER_RE = re.compile(r"^[ \t]*<!--.*-->[ \t]*$")


def load_p21_preamble() -> str:
    """정본을 읽어 HTML 주석 줄을 뺀 본문을 낸다. 실패는 삼키지 않는다 — 보안 컨트롤이라
    조용히 빠진 프롬프트는 빠졌다는 사실조차 남기지 않는다(호출자가 rc=2 로 죽는다)."""
    lines = P21_PREAMBLE_PATH.read_text(encoding="utf-8").splitlines()
    return "\n".join(x for x in lines if not P21_MARKER_RE.match(x)).strip("\n")


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
    # passes /dev/null when DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1. Treat any
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
