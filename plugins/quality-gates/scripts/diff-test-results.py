#!/usr/bin/env python3
"""diff-test-results.py — 기준선×HEAD 짝짓기 → 귀속 (design 2026-08-01 §5.5).

두 모드:
  per-adapter : --expected/--baseline/--head/--granularity/--runner  → 어댑터 1개의 귀속 YAML
  aggregate   : --aggregate --expected-adapters N <yaml>...          → verdict_input 집계
                (Task 7이 채운다 — 이 파일은 per-adapter 경로만 구현한다)

결정론이 지키는 것은 *선택*이 아니라 *짝짓기*다. 모델 주장과 독립이어야 백스톱이 된다.
표준 라이브러리만 사용한다 (PyYAML 금지 — 대상 레포에 없을 수 있다).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

STATUSES = {"pass", "fail", "error", "unrun", "absent"}

# 상태값 → 표의 축. `error`는 fail 축으로 접힌다: 수집 에러·import 실패는
# *실제 결함*이지 실행 불능이 아니다 (이번 변경이 import를 깼다면 그것은 회귀다).
AXIS = {"pass": "P", "fail": "F", "error": "F", "absent": "A", "unrun": "U"}

# 16칸 총 함수. 8개 카테고리 밖으로 나가지 않는다.
#   baseline == U        → BASELINE_UNRUNNABLE (귀속의 한쪽 축이 없다)
#   head ∈ {A, U}        → SILENT_DROP        (영향분으로 고른 것이 HEAD에서 미확인)
ATTR = {
    ("P", "P"): "STILL_GREEN",         ("P", "F"): "NEW_REGRESSION",
    ("P", "A"): "SILENT_DROP",         ("P", "U"): "SILENT_DROP",
    ("F", "P"): "FIXED",               ("F", "F"): "PRE_EXISTING",
    ("F", "A"): "SILENT_DROP",         ("F", "U"): "SILENT_DROP",
    ("A", "P"): "NEW_TEST_GREEN",      ("A", "F"): "NEW_TEST_RED",
    ("A", "A"): "SILENT_DROP",         ("A", "U"): "SILENT_DROP",
    ("U", "P"): "BASELINE_UNRUNNABLE", ("U", "F"): "BASELINE_UNRUNNABLE",
    ("U", "A"): "BASELINE_UNRUNNABLE", ("U", "U"): "BASELINE_UNRUNNABLE",
}
CATEGORIES = [
    "STILL_GREEN", "NEW_REGRESSION", "PRE_EXISTING", "FIXED",
    "NEW_TEST_GREEN", "NEW_TEST_RED", "SILENT_DROP", "BASELINE_UNRUNNABLE",
]
# 확증 제품결함 — 이것만 FAIL을 만든다. PRE_EXISTING은 여기 없다: devbrew 자신의
# stale red가 첫 실행부터 게이트를 막으면 이 설계는 쓸 수 없다.
DEFECTS = {"NEW_REGRESSION", "NEW_TEST_RED"}


def fail4(msg: str) -> "NoReturn":  # noqa: F821
    print(f"diff-test-results: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_results(path: str, label: str) -> dict[str, tuple[str, str]]:
    """3열 TSV → {unit: (status, exit)}. 중복 unit / 미지 상태 / 필드 수 오류는 exit 4."""
    rows: dict[str, tuple[str, str]] = {}
    for lineno, raw in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        parts = raw.split("\t")
        if len(parts) != 3:
            fail4(f"{label}:{lineno} 필드 수 {len(parts)} != 3")
        unit, status, code = parts
        if status not in STATUSES:
            fail4(f"{label}:{lineno} 알 수 없는 상태값 '{status}'")
        if unit in rows:
            # 조용한 last-wins는 결과를 입력 순서에 의존하게 만든다.
            fail4(f"{label}:{lineno} 중복 unit 행 '{unit}'")
        rows[unit] = (status, code)
    return rows


def yaml_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def per_adapter(args: argparse.Namespace) -> int:
    expected = [
        ln.strip()
        for ln in Path(args.expected).read_text(encoding="utf-8").splitlines()
        if ln.strip()
    ]
    base = read_results(args.baseline, "baseline")
    head = read_results(args.head, "head")

    attributions = []
    counts = {c.lower(): 0 for c in CATEGORIES}
    for unit in expected:
        notes = []
        b = base.get(unit)
        h = head.get(unit)
        if b is None or h is None:
            # 행 자체가 없는 것은 계약 위반이다. 부재를 추론으로 메우지 않는다.
            verdict = "SILENT_DROP"
            missing = [n for n, v in (("baseline", b), ("head", h)) if v is None]
            notes.append("행 없음: " + ",".join(missing))
        else:
            if b[0] == "error":
                notes.append("baseline=(error)")
            if h[0] == "error":
                notes.append("head=(error)")
            verdict = ATTR[(AXIS[b[0]], AXIS[h[0]])]
        # `_SUSPECT`는 계약이다 — 확증이 아니라는 표시이고, 이 경로에서 verdict는
        # PASS가 될 수 없다 (gbrain skills/testing 선례의 degrade 라벨).
        if verdict == "BASELINE_UNRUNNABLE":
            notes.append("git-귀속 degrade: REGRESSION_SUSPECT/PRE_EXISTING_SUSPECT/UNKNOWN")
        counts[verdict.lower()] += 1
        attributions.append((unit, verdict, "; ".join(notes)))

    degraded = counts["baseline_unrunnable"] > 0 or (
        args.granularity == "bulk" and counts["pre_existing"] > 0
    )

    out = [f"runner: {args.runner}", "attributions:"]
    for unit, verdict, note in attributions:
        out.append(f"  - unit: {yaml_str(unit)}")
        out.append(f"    verdict: {verdict}")
        out.append(f"    note: {yaml_str(note)}")
    out.append(f"attribution_status: {'degraded' if degraded else 'closed'}")
    # counts는 flow-mapping(한 줄)으로 emit한다 — 블록 스타일(키 한 줄씩)로 쓰면
    # `silent_drop`/`baseline_unrunnable`이 카운트 키와 verdict_input 플래그 키에서
    # 동시에 등장해, 순진한 "첫 매치" 파서(소비자 다수가 그렇다 — Task 11 참고)가
    # 카운트를 플래그로 오독한다. design §5.5의 `counts: {new_regression: N, ...}`
    # 표기도 원래 flow-mapping이다.
    counts_body = ", ".join(f"{c.lower()}: {counts[c.lower()]}" for c in CATEGORIES)
    out.append(f"counts: {{{counts_body}}}")
    out.append("verdict_input:")
    out.append(f"  confirmed_product_defect: "
               f"{'true' if any(counts[d.lower()] for d in DEFECTS) else 'false'}")
    out.append(f"  silent_drop: {'true' if counts['silent_drop'] else 'false'}")
    out.append(f"  baseline_unrunnable: "
               f"{'true' if counts['baseline_unrunnable'] else 'false'}")
    print("\n".join(out))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(add_help=True)
    p.add_argument("--expected")
    p.add_argument("--baseline")
    p.add_argument("--head")
    p.add_argument("--granularity", choices=["file", "package", "bulk"])
    p.add_argument("--runner")
    p.add_argument("--aggregate", action="store_true")
    p.add_argument("--expected-adapters", type=int)
    p.add_argument("yamls", nargs="*")
    return p


def main() -> int:
    args = build_parser().parse_args()
    # --aggregate는 Task 7이 채운다. 이 시점에는 per-adapter 경로만 동작한다 —
    # 여기서 `_aggregate`를 참조하면 Task 7 없이는 NameError로 이어지므로,
    # 그 분기는 아예 만들지 않는다 (조정자 지시).
    missing = [
        f"--{n}" for n in ("expected", "baseline", "head", "granularity", "runner")
        if getattr(args, n) is None
    ]
    if missing:
        print(f"diff-test-results: 필수 인자 누락: {' '.join(missing)}", file=sys.stderr)
        return 2
    return per_adapter(args)


if __name__ == "__main__":
    sys.exit(main())
