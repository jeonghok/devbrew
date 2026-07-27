#!/usr/bin/env python3
"""build_brief_codex_prompt.py — axis-scoped codex prompt for an interview BRIEF.

spec-distill Spec B §5.7 · AC6 · AC20. codex는 축별로 **2회** 호출된다(E9) —
이 빌더는 **한 축의 체크리스트만** 조립한다. 프롬프트에 두 축을 함께 담으면 codex가
주의 배분을 스스로 결정하고, findings에 축 태그를 요구해야 하고, 병합에서 다시 갈라야
한다. 호출을 나누면 각 호출이 "이것만 봐라"가 되어 깊이가 오른다.

코드는 **1곳**이고 축은 데이터(`brief-codex-<axis>-checklist.md`)다 — 축마다 코드를
복제하면 모듈화가 아니라 중복이다(spec §9).

design-doc용(spec) 리뷰 프롬프트 빌더를 재사용하지 **않는다**: 최신 spec의 AC를 주입하는
성질이 brief 리뷰에서 모델 다양성을 죽이는 오염원이다.

payload는 **파일 경로로만** 받는다(argv/stdin 인라인 금지 — injection 안전). 본문은
read_text 후 str.replace로 치환한다(파싱·eval 없음).

Usage: build_brief_codex_prompt.py --axis direction|fidelity <payload_file>
"""
from __future__ import annotations

import argparse
import pathlib
import sys

AXES = ("direction", "fidelity")

PROMPT_TEMPLATE = """You are an independent reviewer of an interview brief (not code).
Do NOT modify any files; you are in a read-only sandbox.

{{AXIS_CHECKLIST}}

<interview_brief>
{{BRIEF}}
</interview_brief>
"""


def main() -> int:
    p = argparse.ArgumentParser(prog="build_brief_codex_prompt.py")
    p.add_argument("--axis", required=True, choices=AXES)
    p.add_argument("payload")
    try:
        args = p.parse_args()
    except SystemExit:
        return 2

    payload_path = pathlib.Path(args.payload)
    if not payload_path.is_file():
        print(f"payload file not found: {payload_path}", file=sys.stderr)
        return 2

    checklist_path = (pathlib.Path(__file__).resolve().parent
                      / f"brief-codex-{args.axis}-checklist.md")
    if not checklist_path.is_file():
        print(f"checklist not found: {checklist_path}", file=sys.stderr)
        return 2

    checklist = checklist_path.read_text(encoding="utf-8", errors="replace")
    brief = payload_path.read_text(encoding="utf-8", errors="replace")
    out = (PROMPT_TEMPLATE
           .replace("{{AXIS_CHECKLIST}}", checklist)
           .replace("{{BRIEF}}", brief))
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
