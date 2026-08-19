#!/usr/bin/env python3
"""build_artifact_codex_prompt.py — construct a codex artifact-critique prompt.

Reads the artifact content from a filesystem PATH only (never inline argv/stdin
— injection mitigation, cf. build_codex_prompt.py). Substitutes via str.replace
(no shell, no eval). Writes the prompt to stdout.

Usage: build_artifact_codex_prompt.py <artifact_path>
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

{{P21_PREAMBLE}}

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
    try:
        p21 = load_p21_preamble()
    except (OSError, UnicodeDecodeError) as exc:
        print(f"P21 프리앰블을 읽을 수 없다: {P21_PREAMBLE_PATH} ({exc})", file=sys.stderr)
        return 2
    if not p21.strip():
        print(f"P21 프리앰블이 비어 있다: {P21_PREAMBLE_PATH}", file=sys.stderr)
        return 2
    content = p.read_text(encoding="utf-8", errors="replace")
    out = PROMPT_TEMPLATE.replace("{{P21_PREAMBLE}}", p21)
    sys.stdout.write(out.replace("{{ARTIFACT}}", content))
    return 0


if __name__ == "__main__":
    sys.exit(main())
