#!/usr/bin/env python3
"""check_qa_ledger.py — LD7 원장의 **구조** 게이트 (design 2026-08-01 §5.6, Law 1).

floor 5키 존재 + status ∈ {closed, degraded} + evidence 절 비어있지 않음
+ `derived:` 줄 존재. **의미 판정은 하지 않는다** — "이 evidence가 충분한가"는
사람과 모델의 몫이고, 이 게이트가 하는 일은 silent skip을 불가능하게 만드는 것뿐이다.

여기에 **전사 대조**가 하나 얹힌다 (§11 ⑱ = 라운드 6·7 의 U3). R8 은 R6 이 낸
`attribution_status` 를 `floor:attribution` 의 status 로 *모델이 옮겨 적게* 하는데,
옮겨 적은 값이 기계가 낸 값과 같은지는 아무도 보지 않았다 — `degraded` 를 `closed` 로
잘못(또는 편하게) 옮기면 그대로 PASS 행을 만족시킨다. 이것도 의미 판정이 아니라
**두 필드의 일치**를 보는 구조 검사다. `--aggregate` 는 필수다: 선택 인자면 넘기지
않은 호출자가 조용히 검사를 면제받는다.

usage: check_qa_ledger.py --aggregate <aggregate-yaml> [<evidence-log-path>]
       (evidence-log 인자가 없으면 stdin)
exit:  0 통과 · 1 구조/전사 위반 · 2 사용 오류(집계 읽기·파싱 실패 포함)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

FLOOR_DIMS = ["changed", "behavior", "verification", "attribution", "gap"]
STATUSES = ("closed", "degraded")

# 집계 YAML 의 `attribution_status`. **정확히 한 번**을 요구한다 — 첫 매치만 보면
# 줄을 덧붙여 원하는 값을 앞에 놓는 것으로 대조를 우회할 수 있다.
AGG_ATTR_RE = re.compile(r"^attribution_status: (closed|degraded)$", re.MULTILINE)

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
# "없음"이 derived의 *이름 자리*에 있는지만 본다 — evidence 산문 안 "없음"(흔한 단어,
# 예: "회귀 없음")까지 뽑으면 정상 명명 derived를 모순으로 오판한다 (C1).
DERIVED_NONE_ANY_RE = re.compile(r"^-\s+derived:\s*없음(?=\s|$)")


def read_aggregate_attribution(path: str) -> tuple[str | None, str | None]:
    """집계 YAML → (attribution_status, 오류 메시지). 둘 중 하나만 non-None."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        return None, f"집계 YAML 읽기 실패: {exc}"
    except UnicodeDecodeError as exc:
        # UnicodeDecodeError 는 OSError 의 하위가 아니다 — 따로 잡지 않으면 트레이스백.
        return None, f"집계 YAML 이 UTF-8 이 아닙니다: {exc}"
    hits = AGG_ATTR_RE.findall(text)
    if len(hits) != 1:
        return None, (
            f"집계 YAML 의 `attribution_status` 줄이 {len(hits)}개입니다 (정확히 1개여야 함): "
            f"{path}"
        )
    return hits[0], None


def check(text: str, expected_attribution: str | None = None) -> list[str]:
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

    # 전사 대조 (§11 ⑱). `attribution` 줄이 아예 없거나 status 가 어휘 밖이면 위에서 이미
    # 오류가 났으므로 여기서는 **둘 다 정상일 때의 불일치**만 본다 — 같은 사실로 두 번
    # 야단치지 않는다.
    if expected_attribution is not None and seen.get("attribution") in STATUSES:
        got = seen["attribution"]
        if got != expected_attribution:
            errors.append(
                f"floor:attribution 의 status '{got}' 가 R6 집계의 "
                f"attribution_status '{expected_attribution}' 와 다릅니다 — "
                f"집계값을 원장에 옮길 때 바뀌었습니다 (전사 대조 실패)"
            )

    derived_lines = [ln for ln in text.splitlines() if DERIVED_ANY_RE.match(ln)]
    if not derived_lines:
        # derived의 '의무'는 "만들어라"가 아니라 "판단을 기록하라"다. 0개여도 되지만
        # 줄 자체가 없으면 모델이 목록까지만 하고 멈춘 것과 구분할 수 없다.
        errors.append("`- derived:` 줄이 없습니다 (0개여도 판단은 기록해야 합니다)")
    else:
        # 이름 자리의 "없음"만 none 선언으로 센다. `- derived:없음 — closed — e`처럼
        # 명명 문법까지 만족하면 그건 "없음"이라는 이름의 명명 차원이지 none 선언이
        # 아니다 — 더 구체적인 명명 매치가 이긴다.
        none_lines = [
            ln for ln in derived_lines
            if DERIVED_NONE_ANY_RE.match(ln) and not DERIVED_NAMED_RE.match(ln)
        ]
        named_ok = [ln for ln in derived_lines if DERIVED_NAMED_RE.match(ln)]
        if none_lines and named_ok:
            errors.append("`derived: 없음` 과 명명 derived 차원이 함께 선언됨 (모순)")
        for ln in derived_lines:
            if DERIVED_NONE_RE.match(ln) or DERIVED_NAMED_RE.match(ln):
                continue
            if DERIVED_NONE_ANY_RE.match(ln):
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


USAGE = "usage: check_qa_ledger.py --aggregate <aggregate-yaml> [<evidence-log-path>]"


def main() -> int:
    args = sys.argv[1:]

    # `--aggregate` 는 **필수**다. 선택 인자면 넘기지 않은 호출자가 조용히 전사 대조를
    # 면제받고, 그것이 바로 이 인자가 닫으려는 fail-open 의 모양이다 (AC60 선례).
    agg_path: str | None = None
    rest: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--aggregate":
            if i + 1 >= len(args):
                print(f"check_qa_ledger: --aggregate 에 값이 없습니다\n{USAGE}", file=sys.stderr)
                return 2
            agg_path = args[i + 1]
            i += 2
            continue
        rest.append(args[i])
        i += 1

    if agg_path is None:
        print(f"check_qa_ledger: --aggregate 는 필수입니다\n{USAGE}", file=sys.stderr)
        return 2
    expected_attribution, agg_err = read_aggregate_attribution(agg_path)
    if agg_err is not None:
        print(f"check_qa_ledger: {agg_err}", file=sys.stderr)
        return 2

    args = rest
    if len(args) > 1:
        print(USAGE, file=sys.stderr)
        return 2
    if args:
        try:
            text = Path(args[0]).read_text(encoding="utf-8")
        except OSError as exc:
            print(f"check_qa_ledger: 읽기 실패: {exc}", file=sys.stderr)
            return 2
    else:
        try:
            text = sys.stdin.buffer.read().decode("utf-8")
        except UnicodeDecodeError as exc:
            print(f"check_qa_ledger: stdin이 UTF-8이 아닙니다: {exc}", file=sys.stderr)
            return 2

    errors = check(text, expected_attribution)
    if errors:
        for e in errors:
            print(f"check_qa_ledger: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
