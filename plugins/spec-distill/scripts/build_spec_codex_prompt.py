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
import re
import sys

# stdout 인코딩은 프로세스 locale/PYTHONIOENCODING을 따른다(read_text의 명시적
# encoding="utf-8"과 달리) — 고정하지 않으면 템플릿의 em dash·한국어가 ascii 계열
# 인코딩에서 UnicodeEncodeError로 프로세스를 죽인다. reconfigure는 TextIOWrapper에만
# 있고 sys.stdout을 채울 수 있는 모든 객체에 있지는 않으므로 형제 관용구(둘 다
# plugins/spec-distill/ 하위 — review-dispatch.py 모듈 최상단의 stdin/stdout/stderr
# reconfigure 루프, check_verbatim_coverage.py의 main()이 쓰는 stdout/stderr guard)와
# 같이 guard한다. 단 그 둘이 잡는 예외 클래스가 서로 다르다(전자 AttributeError·OSError,
# 후자 AttributeError·ValueError) — 닫힌 TextIOWrapper는 ValueError를 낸다(실측)로
# 여기서는 합집합을 잡는다.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
except (AttributeError, OSError, ValueError):
    pass

# P21 프리앰블은 **형제 파일** `scripts/prompt-preamble.md` 에서 읽는다 — 그 경로는
# `shared/codex/prompt-preamble.md`
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
