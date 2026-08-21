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
