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
#
# 접는 것은 **비대칭 방향만** 산다. `(P,error)` 는 확증 회귀로 옳지만 `(error,error)`
# 의 `PRE_EXISTING` 은 "둘 다 판정 못 했다"를 "둘 다 똑같이 빨갛다"로 오인한 라벨이다.
# 그래서 축은 그대로 두고 **인증만 막는다** — per_adapter() 의 `error_axis_seen`
# (아래 degraded 식)이 `error` 가 닿은 어댑터를 `closed` 로 내보내지 않는다.
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


def parse_detected(raw: str) -> set[str]:
    """`--baseline-detected` 를 러너 이름 집합으로. 센티널 `NONE` = 공집합.

    빈 문자열은 받지 않는다 — "감지 0개"는 `NONE` 으로 **명시**해야 한다. 빈 인자를
    공집합으로 조용히 받아주면, 값을 못 구한 호출자가 `--baseline-detected ""` 로
    넘겨도 통과해 이 게이트가 무의미해진다.
    """
    tokens = [t for t in re.split(r"[,\s]+", raw.strip()) if t]
    if not tokens:
        fail4("--baseline-detected 가 비어 있음 (감지 0개는 'NONE' 으로 명시)")
    if tokens == ["NONE"]:
        return set()
    if "NONE" in tokens:
        fail4("--baseline-detected 에 'NONE' 과 러너 이름이 공존")
    return set(tokens)


def per_adapter(args: argparse.Namespace) -> int:
    expected = [
        ln.strip()
        for ln in read_text_or_fail4(args.expected, "expected").splitlines()
        if ln.strip()
    ]
    base = read_results(args.baseline, "baseline")
    head = read_results(args.head, "head")

    # **기준선 행은 그 어댑터가 merge_base 트리에 실재할 때만 증거다.**
    #
    # 이 플래그가 *필수*인 이유는 그것이 막는 사슬에 있다: 캐시(§5.4)는 세션보다
    # 오래 살고 `.claude/quality-gates/` 아래 있어 verifier 의 Bash 와 `run` 이
    # 실행하는 저장소 코드가 닿는다. 선택된 전 unit 에 `pass` 를 심으면 R4① 이
    # **전량 적중**이 되고, ②가 "미적중분이 있을 때만" 도는 스텝이라 **기준선
    # 워크트리가 아예 만들어지지 않는다**. merge_base 에 그 어댑터가 없어서 원래
    # 전량 `unrun` → BASELINE_UNRUNNABLE → degraded → PASS 불가였던 실행이
    # STILL_GREEN → closed → **PASS** 로 바뀐다.
    #
    # §5.4 의 비대칭 논증(심어진 `pass` 는 (P,F)=NEW_REGRESSION 으로 fail-closed)이
    # 이 줄을 놓쳤다: 그 표는 **실제값이 pass 또는 fail 인 경우만** 셌고 실제값이
    # `unrun` 인 줄이 없었다. 그 줄은 결함 축이 아니라 **인증 축**이라 `fail` 전용
    # 재검증이 닿지 않는다.
    #
    # 그래서 판정을 캐시가 아니라 **기준선 트리의 관측**에 묶는다. 전량 적중이 ②를
    # 억제하는 경로 자체가 사라진다 — 캐시 행은 비용만 낮출 수 있고
    # `attribution_status: closed` 의 유일 근거가 될 수 없다.
    #
    # **이 값의 출처는 `detect` 가 아니라 `probe` 다 (/qg iter-5 SR1).** 앞 버전은
    # "이 값을 정직하게 만드는 경로는 merge_base 워크트리에서 `detect` 를 돌리는
    # 것뿐" 이라고 적었고 그것이 틀렸다: `detect` 는 *이 트리가 무엇을 선언했는가* 만
    # 보므로, 선언은 있고 toolchain 이 없는 트리에서도 러너 이름을 내준다. 전량
    # 적중이면 `run` 이 호출되지 않아 실행-시점 관문(환경 디렉토리 gitignore ·
    # `setup_cmd` · 러너 바이너리)이 한 번도 돌지 않고, 그러면 원래 전량 `unrun` →
    # BASELINE_UNRUNNABLE → degraded → PASS 불가였을 실행이 다시 STILL_GREEN →
    # closed → PASS 가 된다 — 지금 이 주석이 닫았다고 주장한 바로 그 사슬이 한 칸
    # 옆으로 옮겨간 것이다. `run-test-selection.sh probe` 가 테스트를 하나도 돌리지
    # 않고 그 관문만 통과시켜 값을 실행 기반으로 되돌린다.
    #
    # 같은 검사가 SKILL.md R4② 산문("두 집합이 다르면 한쪽에만 있는 어댑터의 unit 은
    # 반대편에서 `unrun` 이 되어 귀속이 degrade 된다")에 **처음으로 집행자를** 준다.
    # 그 규칙은 지금까지 어떤 컴포넌트도 소유하지 않았다.
    baseline_detected = parse_detected(args.baseline_detected)
    runner_grounded = args.runner in baseline_detected

    attributions = []
    counts = {c.lower(): 0 for c in CATEGORIES}
    error_axis_seen = False
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
                error_axis_seen = True
            if h[0] == "error":
                notes.append("head=(error)")
                error_axis_seen = True
            b_axis = AXIS[b[0]]
            if not runner_grounded:
                # 캐시가 무엇을 내줬든, 기준선 트리에 어댑터가 없으면 그 행은 관측이
                # 아니다. 행을 고쳐 쓰지 않고 **축만** 미실행으로 내린다 — 원본 상태는
                # note 에 남아 사람이 추적할 수 있다.
                notes.append(f"기준선 트리에 어댑터 {args.runner} 없음 (행 '{b[0]}' 무시)")
                b_axis = "U"
            verdict = ATTR[(b_axis, AXIS[h[0]])]
        # `_SUSPECT`는 계약이다 — 확증이 아니라는 표시이고, 이 경로에서 verdict는
        # PASS가 될 수 없다 (gbrain skills/testing 선례의 degrade 라벨).
        if verdict == "BASELINE_UNRUNNABLE":
            notes.append("git-귀속 degrade: REGRESSION_SUSPECT/PRE_EXISTING_SUSPECT/UNKNOWN")
        counts[verdict.lower()] += 1
        attributions.append((unit, verdict, "; ".join(notes)))

    # **`error` 가 어느 축에든 닿으면 이 어댑터는 인증할 수 없다.**
    #
    # `error` = 러너가 0/1/127 이 아닌 코드로 끝났다 = *판정하지 못했다*. 어느
    # 읽기로도 "영향분을 확인했다"가 참이 되지 않는다. 그런데 `error` 는 fail 축으로
    # 접히므로 양측 `error` 는 `(F,F)=PRE_EXISTING` → DEFECTS 밖 → `closed` →
    # **테스트를 하나도 판정하지 않고 PASS** 였다. **실측 트리거는 pytest·cargo 뿐이다**:
    # pytest exit 5(수집 0개)·2(import 실패)·4(잘못된 ini 옵션), cargo 컴파일 에러(101).
    # 이 자리에 jest/vitest "No tests found" 와 "전제조건 없는 shell 하니스" 를 함께
    # 적었던 앞 문장은 **거짓이었다** (/qg iter-3 실측): vitest 는 매치 파일 0개도
    # 테스트 0개인 파일도 exit 1 이고 jest 도 같으며, 전제조건 없는 shell 하니스도
    # exit 1 이다. exit 1 은 `fail` 이라 이 규칙에 **닿지 않는다**.
    #
    # 종료코드를 러너별로 열거해 `unrun` 으로 보내는 수정은 iter-2 에서 **더 나쁜
    # 결함**을 만들었다 — pytest exit 2 는 환경이 아니라 *제품 파손*이라, `unrun`
    # 으로 보내면 "이 diff 가 import 를 깼다"가 terminal FAIL 에서 비차단으로
    # 내려갔다(실측). 열거는 두 의미를 한 축에 욱여넣으려다 매번 한쪽을 잃는다.
    # 여기서는 **열거하지 않는다**: 판정 못 한 것은 인증 못 한다, 로 끝난다.
    # 비대칭 `(P,error)` 는 그대로 `NEW_REGRESSION`(확증 결함)이고, 대칭
    # `(error,error)` 는 결함이 아니라 **degrade** 다. 두 방향이 동시에 표현된다.
    #
    # **잔여 (열려 있음 — 이 규칙이 닫는 것보다 크다).** 판정 실패를 **exit 1** 로 내는
    # 러너는 여기에 닿지 않는다. 실측 인스턴스: go 컴파일 에러 · vitest/jest 의 "No test
    # files found" 와 테스트 0개인 파일 · 전제조건 없는 shell 하니스. 전부 테스트 실패와
    # 같은 코드라 종료 코드만으로 구분 불가이고, 러너별 출력 파서는 §5.9 가 금지한다.
    # 즉 이 수정은 pytest·cargo 축만 닫는다.
    # **아무것도 판정하지 않았으면 인증하지 않는다 (/qg iter-3 CRITICAL, 2명 독립).**
    # 빈 `--expected` 는 attributions 를 비우고 모든 카운트를 0 으로 만들어 아래 어떤
    # 항목도 참이 되지 않는다 → `closed` + 3플래그 전부 false → R8 의 PASS 행이 결정론
    # 조건을 **전부** 충족한다. 그것을 막던 유일한 것은 SKILL.md 의 한국어 문장이고,
    # 그 동작을 통째로 지워도 문장의 grep 락은 GREEN 이다. 판정 0건은 결함이 아니지만
    # **인증도 아니다**.
    # 도말(smear) — 실행이 배치였는데 어댑터의 unit 입도는 그보다 잘다면, `run` 은
    # **한 번의 종료 코드를 전 unit 에 그대로 찍는다**(run-test-selection.sh:796-802).
    # 그 상태로 양측이 red 면 실제로는 회귀인 unit 까지 `(F,F)=PRE_EXISTING` 으로
    # 접혀 `closed` → PASS 가 된다. 설계의 2단 구조(bulk red → 실패분만 per-unit
    # 재실행)가 이것을 막게 돼 있으나 그건 산문이고, 산문을 지워도 막히지 않았다.
    #
    # bulk 가 **green** 인 경우는 도말이 아니다 — 배치 green 은 전 unit 이 통과했다는
    # 뜻이라 각 행이 정직하다. 그래서 조건은 red 가 실제로 섞인 `pre_existing > 0` 이다.
    # **`pre_existing > 0` 단독으로 넓히지 않는다**: stale red 하나 있는 레포마다 모든
    # 배치 실행이 degrade 돼 PASS 가 구조적으로 도달 불가가 된다(iter-2·iter-3 을 물었던
    # 과잉강화 형태).
    #
    # 잔여(명시): `new_regression > 0` 도 도말 아래선 spurious 일 수 있다(head 배치가
    # red 면 실제로 통과한 unit 도 fail 로 찍힌다). 그 방향은 **거짓 red** 라 인증을
    # 막는 쪽이므로 여기서 degrade 로 올리지 않는다 — 귀속의 정확도 문제이지 인증
    # 우회가 아니다.
    smeared = (
        args.mode == "bulk"
        and args.granularity != "bulk"
        and counts["pre_existing"] > 0
    )
    degraded = (
        not expected
        or counts["baseline_unrunnable"] > 0
        or counts["silent_drop"] > 0
        or error_axis_seen
        or (args.granularity == "bulk" and counts["pre_existing"] > 0)
        or smeared
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
    # per_adapter() 의 `not expected` 와 같은 이유 — 어댑터 0개 집계는 "결함 없음"이
    # 아니라 "아무것도 대조하지 않았음"이다. `--expected-adapters 0` + YAML 0개는 위
    # 개수 대조를 통과하므로, 여기서 막지 않으면 `closed` 로 나간다.
    if not adapters:
        degraded = True

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
    # 실행 **mode** 는 어댑터 **granularity** 와 다른 축이다. granularity 는 어댑터가
    # 무엇을 unit 으로 보는가이고(`detect` 출처), mode 는 이번 실행이 그 unit 들을
    # 한 번에 돌렸는가다(`run` 의 인자). 둘을 같은 것으로 읽으면 아래 도말 degrade 가
    # granularity:file 어댑터에 **증명 가능하게 발화하지 않는다** (/qg iter-5 SF1).
    p.add_argument("--mode", choices=["bulk", "per-unit"])
    p.add_argument("--runner")
    # 값의 출처는 `run-test-selection.sh probe` 가 기준선 트리에서 `usable: yes` 를 낸
    # 러너 집합이다 — `detect` 의 집합이 **아니다**. `detect` 는 선언만 보므로 캐시
    # 전량 적중일 때 "그 트리에서 실제로 돌 수 있었다"를 재지 못한다 (/qg iter-5 SR1).
    p.add_argument("--baseline-detected")
    p.add_argument("--aggregate", action="store_true")
    p.add_argument("--expected-adapters", type=int)
    p.add_argument("yamls", nargs="*")
    return p


def main() -> int:
    args = build_parser().parse_args()
    if args.aggregate:
        return _aggregate(args)
    # `baseline_detected` 를 여기 넣는 것이 이 플래그의 이빨이다 — 선택 인자로 두고
    # 부재 시 "전부 감지된 것으로 간주"하면, 값을 못 구한 호출자(= 기준선 트리를
    # 안 만든 호출자)가 정확히 이 검사가 막으려던 경로로 통과한다.
    missing = [
        f"--{n.replace('_', '-')}"
        for n in ("expected", "baseline", "head", "granularity", "mode", "runner",
                  "baseline_detected")
        if getattr(args, n) is None
    ]
    if missing:
        print(f"diff-test-results: 필수 인자 누락: {' '.join(missing)}", file=sys.stderr)
        return 2
    return per_adapter(args)


if __name__ == "__main__":
    sys.exit(main())
