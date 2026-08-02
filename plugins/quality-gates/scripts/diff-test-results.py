#!/usr/bin/env python3
"""diff-test-results.py — 기준선×HEAD 짝짓기 → 귀속 (design 2026-08-01 §5.5).

두 모드:
  per-adapter : --expected/--baseline/--head/--granularity/--runner  → 어댑터 1개의 귀속 YAML
  aggregate   : --aggregate --expected-adapters N <yaml>...          → verdict_input 집계
                (N개 어댑터 YAML을 하나의 verdict_input으로 합친다 — 오케스트레이터가
                N개를 읽고 최악값을 고르는 경로를 없앤다. §5.5 참고)

결정론이 지키는 것은 *선택*이 아니라 *짝짓기*다. 모델 주장과 독립이어야 백스톱이 된다.
표준 라이브러리만 사용한다 (PyYAML 금지 — 대상 레포에 없을 수 있다).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import NoReturn

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


def fail4(msg: str) -> NoReturn:
    print(f"diff-test-results: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_text_or_fail4(path: str, label: str) -> str:
    """입력 파일을 읽는다. 부재·권한 오류 등(OSError)은 계약상 exit 4(파싱 실패)다 —
    처리되지 않은 traceback으로 exit 1이 새면 오케스트레이터의 0/2/4 분기가 미분류
    크래시를 받는다."""
    try:
        return Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        fail4(f"{label} 파일을 읽을 수 없음: {path} ({exc})")


def read_results(path: str, label: str) -> dict[str, tuple[str, str]]:
    """3열 TSV → {unit: (status, exit)}. 중복 unit / 미지 상태 / 필드 수 오류는 exit 4."""
    rows: dict[str, tuple[str, str]] = {}
    for lineno, raw in enumerate(read_text_or_fail4(path, label).splitlines(), 1):
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
    # 백슬래시 → 따옴표 → 제어문자(\n \r \t) 순. 백슬래시를 먼저 두 배로 만들지
    # 않으면 이후 단계가 삽입하는 백슬래시가 다시 이스케이프돼 이중으로 샌다.
    # \n/\r을 놔두면 라인-지향 파서(Task 7의 aggregate — hand-rolled, per-line
    # 정규식 매치)가 값 중간에서 줄이 갈라져 귀속을 오염시킨다.
    escaped = (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return '"' + escaped + '"'


def per_adapter(args: argparse.Namespace) -> int:
    expected = [
        ln.strip()
        for ln in read_text_or_fail4(args.expected, "expected").splitlines()
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

    out = [f"runner: {args.runner}"]
    if attributions:
        out.append("attributions:")
        for unit, verdict, note in attributions:
            out.append(f"  - unit: {yaml_str(unit)}")
            out.append(f"    verdict: {verdict}")
            out.append(f"    note: {yaml_str(note)}")
    else:
        # 빈 목록을 bare `attributions:`로 내면 YAML에서 null로 파싱된다 —
        # `for a in doc["attributions"]:`가 TypeError로 죽는다. 영향분 0개는
        # 실제 케이스(테스트-무관 변경)이고 Task 7이 이 출력을 소비하므로
        # 명시적으로 빈 flow-sequence를 낸다.
        out.append("attributions: []")
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


def _one(pattern: str, text: str, path: str, what: str) -> str:
    """정확히 한 번 매치되는 값을 뽑는다. 0회도 2회도 exit 4 — 집계는 fail-closed다."""
    hits = re.findall(pattern, text, re.M)
    if len(hits) != 1:
        fail4(f"{path}: '{what}' 가 {len(hits)}회 매치 (정확히 1회여야 함)")
    return hits[0]


def parse_adapter_yaml(path: str) -> tuple[str, str, dict[str, bool], dict[str, int]]:
    """per_adapter()가 실제로 내는 형상을 파싱한다.

    `counts`는 per_adapter()가 flow-mapping 한 줄로 emit한다(위 주석 참고) — 블록
    스타일(`  key: value` 줄마다)로 가정하면 이 파일의 실제 출력에서 0회 매치돼
    유효한 입력 전부에서 exit 4가 난다. `attributions:`는 집계가 쓰지 않으므로
    건드리지 않는다 — 빈 `attributions: []`도 그냥 지나간다.
    """
    text = read_text_or_fail4(path, "aggregate-input")
    runner = _one(r"^runner: (\S+)$", text, path, "runner")
    status = _one(r"^attribution_status: (closed|degraded)$", text, path, "attribution_status")
    flags: dict[str, bool] = {}
    for key in ("confirmed_product_defect", "silent_drop", "baseline_unrunnable"):
        flags[key] = _one(rf"^  {key}: (true|false)$", text, path, key) == "true"

    counts_body = _one(r"^counts: \{(.*)\}$", text, path, "counts")
    counts: dict[str, int] = {}
    for key, val in re.findall(r"([a-z_]+): (\d+)", counts_body):
        if key in counts:
            # 조용한 last-wins는 집계를 입력 순서에 의존하게 만든다 (T45의 unit
            # 중복 처리와 같은 이유).
            fail4(f"{path}: counts 키 '{key}' 중복 (정확히 1회여야 함)")
        counts[key] = int(val)
    expected_keys = {c.lower() for c in CATEGORIES}
    if set(counts) != expected_keys:
        # 0회도 기본값(0)으로 메우지 않는다 — 누락된 카테고리를 조용히 0으로
        # 취급하면 그 카테고리의 회귀가 집계에서 사라진다.
        missing = sorted(expected_keys - set(counts))
        extra = sorted(set(counts) - expected_keys)
        fail4(f"{path}: counts 키 불일치 (missing={missing}, extra={extra})")
    return runner, status, flags, counts


def _aggregate(args: argparse.Namespace) -> int:
    if args.expected_adapters is None:
        print("diff-test-results: --aggregate 에는 --expected-adapters 가 필요합니다",
              file=sys.stderr)
        return 2
    if len(args.yamls) != args.expected_adapters:
        # 어댑터 하나의 결과 파일이 통째로 빠졌을 때 verdict가 낙관적으로 새는 것을
        # 막는다. 남은 것만 조용히 합치지 않는다 (M25 — 이 블록이 지켜야 하는 mutation).
        fail4(f"입력 YAML {len(args.yamls)}개 != --expected-adapters "
              f"{args.expected_adapters} (낙관적 부분 집계 금지)")

    adapters: list[str] = []
    per_adapter_counts: dict[str, dict[str, int]] = {}
    combined = {"confirmed_product_defect": False, "silent_drop": False,
                "baseline_unrunnable": False}
    degraded = False
    for path in args.yamls:
        runner, status, flags, counts = parse_adapter_yaml(path)
        if runner in adapters:
            # 같은 runner가 두 번 오면 개수 대조가 무력해진다 (다른 어댑터 하나가
            # 통째로 빠져도 총 개수는 맞아떨어질 수 있다).
            fail4(f"중복 runner '{runner}' — 어댑터 축 개수 대조가 무력해짐")
        adapters.append(runner)
        per_adapter_counts[runner] = counts
        for key in combined:
            # OR — 한 어댑터의 확증 회귀는 다른 어댑터가 전부 green이어도 전체
            # 판정을 확증 결함으로 만든다. degrade(silent_drop 등)도 같은 이유로
            # confirmed_product_defect에 삼켜지지 않고 독립적으로 살아남는다.
            combined[key] = combined[key] or flags[key]
        degraded = degraded or status == "degraded"

    # runner 이름은 여기서도, per_adapter()의 `runner: {args.runner}`에서도
    # yaml_str()로 따옴표 처리하지 않는다 — parse_adapter_yaml()의 `^runner: (\S+)$`
    # 가 공백 없는 토큰만 받아들이고, runner는 자유 입력이 아니라 §5.9의 닫힌
    # 8-어댑터 표에서만 오는 값이라 `]`/`,`/`{`/`}` 같이 이 파일의 손-롤 flow
    # 문법을 깨는 문자가 들어올 경로가 없다. 자유 입력(unit 이름 등)은 yaml_str로
    # 이스케이프한다 — 이 둘을 섞으면 안 된다.
    out = [f"adapters: [{', '.join(adapters)}]", "verdict_input:"]
    for key in ("confirmed_product_defect", "silent_drop", "baseline_unrunnable"):
        out.append(f"  {key}: {'true' if combined[key] else 'false'}")
    out.append(f"attribution_status: {'degraded' if degraded else 'closed'}")
    if adapters:
        out.append("per_adapter:")
        for runner in adapters:
            pairs = ", ".join(
                f"{k}: {v}" for k, v in sorted(per_adapter_counts[runner].items())
            )
            out.append(f"  {runner}: {{{pairs}}}")
    else:
        # 빈 매핑을 bare `per_adapter:`로 내면 YAML에서 null로 파싱된다 — 같은
        # 함정을 per_adapter()의 `attributions: []`가 이미 한 번 봉쇄했다(위 주석).
        out.append("per_adapter: {}")
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
    if args.aggregate:
        return _aggregate(args)
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
