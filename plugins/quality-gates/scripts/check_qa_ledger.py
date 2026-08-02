#!/usr/bin/env python3
"""check_qa_ledger.py — LD7 원장의 **구조** 게이트 (design 2026-08-01 §5.6, Law 1).

floor 5키 존재 + status ∈ {closed, degraded} + evidence 절 비어있지 않음
+ `derived:` 줄 존재. **의미 판정은 하지 않는다** — "이 evidence가 충분한가"는
사람과 모델의 몫이고, 이 게이트가 하는 일은 silent skip을 불가능하게 만드는 것뿐이다.

usage: check_qa_ledger.py <evidence-log-path>   (인자 없으면 stdin)
exit:  0 통과 · 1 구조 위반 · 2 사용 오류
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

FLOOR_DIMS = ["changed", "behavior", "verification", "attribution", "gap"]
STATUSES = ("closed", "degraded")

# 줄 시작 `- floor:<dim>` + em-dash 구분 status + **비어있지 않은** evidence.
# 헤딩(`## floor:gap`)이나 산문 언급은 이 문법을 만족할 수 없다 — 이것이 M8의 이빨이다.
FLOOR_RE = re.compile(
    r"^-\s+floor:(?P<dim>[a-z_]+)\s+—\s+(?P<status>\w+)\s+—\s+(?P<evidence>\S.*?)\s*$"
)
DERIVED_ANY_RE = re.compile(r"^-\s+derived:")
DERIVED_NONE_RE = re.compile(r"^-\s+derived:\s*없음\s+—\s+(?P<why>\S.*?)\s*$")
DERIVED_NAMED_RE = re.compile(
    r"^-\s+derived:(?P<name>[^\s—]+)\s+—\s+(?P<status>\w+)\s+—\s+(?P<evidence>\S.*?)\s*$"
)


def check(text: str) -> list[str]:
    errors: list[str] = []
    seen: dict[str, str] = {}

    for line in text.splitlines():
        m = FLOOR_RE.match(line)
        if not m:
            continue
        dim, status = m.group("dim"), m.group("status")
        if dim in seen:
            errors.append(f"floor 차원 '{dim}' 이 두 번 선언됨 (어느 것을 믿을지 불명)")
            continue
        if status not in STATUSES:
            errors.append(f"floor:{dim} 의 status '{status}' 가 {STATUSES} 밖")
            continue
        seen[dim] = status

    for dim in FLOOR_DIMS:
        if dim not in seen:
            errors.append(
                f"floor 차원 '{dim}' 누락 — "
                f"`- floor:{dim} — closed|degraded — <evidence>` 줄이 필요합니다"
            )

    derived_lines = [ln for ln in text.splitlines() if DERIVED_ANY_RE.match(ln)]
    if not derived_lines:
        # derived의 '의무'는 "만들어라"가 아니라 "판단을 기록하라"다. 0개여도 되지만
        # 줄 자체가 없으면 모델이 목록까지만 하고 멈춘 것과 구분할 수 없다.
        errors.append("`- derived:` 줄이 없습니다 (0개여도 판단은 기록해야 합니다)")
    else:
        none_lines = [ln for ln in derived_lines if "없음" in ln]
        named_ok = [ln for ln in derived_lines if DERIVED_NAMED_RE.match(ln)]
        if none_lines and named_ok:
            errors.append("`derived: 없음` 과 명명 derived 차원이 함께 선언됨 (모순)")
        for ln in derived_lines:
            if DERIVED_NONE_RE.match(ln) or DERIVED_NAMED_RE.match(ln):
                continue
            if "없음" in ln:
                errors.append(f"`derived: 없음` 에 이유 절이 없습니다: {ln.strip()}")
            else:
                errors.append(
                    f"derived 줄 문법 위반 (`- derived:<name> — <status> — <evidence>`): "
                    f"{ln.strip()}"
                )
        for ln in named_ok:
            st = DERIVED_NAMED_RE.match(ln).group("status")
            if st not in STATUSES:
                errors.append(f"derived status '{st}' 가 {STATUSES} 밖")

    return errors


def main() -> int:
    args = sys.argv[1:]
    if len(args) > 1:
        print("usage: check_qa_ledger.py [<evidence-log-path>]", file=sys.stderr)
        return 2
    if args:
        try:
            text = Path(args[0]).read_text(encoding="utf-8")
        except OSError as exc:
            print(f"check_qa_ledger: 읽기 실패: {exc}", file=sys.stderr)
            return 2
    else:
        text = sys.stdin.read()

    errors = check(text)
    if errors:
        for e in errors:
            print(f"check_qa_ledger: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
