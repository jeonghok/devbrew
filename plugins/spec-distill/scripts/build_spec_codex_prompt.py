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

{{P21_PREAMBLE}}

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

    try:
        p21 = load_p21_preamble()
    except (OSError, UnicodeDecodeError) as exc:
        print(f"P21 프리앰블을 읽을 수 없다: {P21_PREAMBLE_PATH} ({exc})", file=sys.stderr)
        return 2
    if not p21.strip():
        print(f"P21 프리앰블이 비어 있다: {P21_PREAMBLE_PATH}", file=sys.stderr)
        return 2
    doc = doc_path.read_text(encoding="utf-8", errors="replace")
    out = PROMPT_TEMPLATE.replace("{{P21_PREAMBLE}}", p21)
    out = out.replace("{{DESIGN_DOC}}", doc)
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
