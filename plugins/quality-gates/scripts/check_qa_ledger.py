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

두 번째 대조는 `unclaimed` 다 (§11 ㉓ = `/qg` iter-7). `run-test-selection.sh assign`
의 구조적 거부 3곳(워크트리 밖 unit · `unittest_can_judge` 실패 · 실행 수단 없음)이
`unclaimed` 행을 낳고, SKILL 은 *"`unclaimed` 가 하나라도 있으면 `verification:
degraded`"* 라고 지시하는데 그 문장을 읽는 기계가 없었다 — `unclaimed` unit 은 어느
어댑터의 unit 목록에도 없어 `--expected` 에도 안 들어가므로 `SILENT_DROP` 백스톱조차
닿지 않는다. 그래서 **한 번도 안 돈 unit 을 두고 floor 5차원 전부 `closed` → PASS** 가
성립했다.

**인자가 개수가 아니라 경로인 이유.** 원 처방은 `--unclaimed-count <N>` 이었다. 그대로
두면 그 N 은 *모델이 옮겨 적은 숫자*가 되고, 그것은 §11 ⑱ 이 방금 닫은 전사 구멍을
같은 이음매에 다시 뚫는 것이다 — `0` 을 적으면 검사가 사라진다. 그래서 `--aggregate`
와 **같은 모양**으로 받는다: 결정론 스크립트가 낸 파일 경로를 받아 이 게이트가 직접
센다. 남는 축(그 파일이 정말 이번 실행의 `assign` 출력인지 = custody)은 `--aggregate`
와 동일하게 열려 있다 (§6.7 S1) — 새 갭이 아니라 공유된 기등재 갭이다.

usage: check_qa_ledger.py --aggregate <aggregate-yaml> --assign-rows <assign-tsv>
                          [<evidence-log-path>]
       (evidence-log 인자가 없으면 stdin)
exit:  0 통과 · 1 구조/전사 위반 · 2 **인자 모양** 오류 · 4 **내용** 읽기·파싱 실패

`2` 와 `4` 의 경계는 이 리포의 형제 스크립트와 같다 (AC60: *"생략 시 exit 2, 빈 값은
exit 4"*). 인자가 없거나 값이 안 붙은 것은 **호출자의 실수**(2)이고, 파일을 못 읽거나
내용이 계약을 어긴 것은 **판정 불가**(4)다. 둘을 한 코드로 접으면 "부르는 법을 틀렸다"와
"읽었는데 믿을 수 없다"가 구분되지 않는다. 소비자(SKILL R8)는 어느 쪽이든 non-zero 를
PASS 불가로 라우팅하므로 안전 방향은 같지만, **코드가 서로 다른 사실을 말해야** 다음
독자가 오독하지 않는다.
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


def read_unclaimed_count(path: str) -> tuple[int | None, str | None]:
    """배정 TSV → (unclaimed 행 수, 오류 메시지). 둘 중 하나만 non-None.

    행 문법은 `assign` 의 계약 그대로 `<unit>\\t<adapter>\\t<granularity>` 3필드다.
    3필드가 아닌 비어있지 않은 줄은 **세지 못한 것**이므로 0 으로 접지 않고 사용
    오류로 올린다 — 셀 수 없는 입력에서 "unclaimed 0건" 을 만들어 내는 것이 바로
    이 인자가 닫으려는 fail-open 이다.
    """
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        return None, f"배정 TSV 읽기 실패: {exc}"
    except UnicodeDecodeError as exc:
        return None, f"배정 TSV 가 UTF-8 이 아닙니다: {exc}"
    # `splitlines()` 는 `\x0b\x0c\x1c-\x1e\x85\u2028\u2029` 까지 쪼개 **생산자보다 넓은**
    # 줄 모델을 갖는다 — docstring 이 "행 문법은 `assign` 의 계약 그대로" 라고 주장하는 한
    # 소비자의 줄 모델도 생산자와 같아야 한다. `assign` 은 `\n` 으로만 쓴다.
    count = 0
    for lineno, line in enumerate(text.split("\n"), start=1):
        if not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            return None, (
                f"배정 TSV {lineno}행이 3필드가 아닙니다 "
                f"(`<unit>\\t<adapter>\\t<granularity>`): {path}"
            )
        # `granularity` 는 이 설계가 고정한 **닫힌 집합**이라 여기서 검사해도 소유권을
        # 침범하지 않는다. 반대로 `fields[1]`(러너 이름)을 어휘로 검사하면
        # `run-test-selection.sh` 의 어댑터 표를 밖에서 재구현하는 것이라 AC38·AC52 위반이다.
        if fields[2] not in ("file", "package", "bulk"):
            return None, (
                f"배정 TSV {lineno}행의 granularity '{fields[2]}' 가 "
                f"{{file, package, bulk}} 밖입니다: {path}"
            )
        if fields[1] == "unclaimed":
            count += 1
    return count, None


def check(
    text: str,
    expected_attribution: str | None = None,
    unclaimed_count: int = 0,
) -> list[str]:
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

    # `unclaimed` 집행 (§11 ㉓). SKILL 산문의 *"`unclaimed` 가 하나라도 있으면
    # `verification: degraded`"* 를 여기서 기계가 집행한다. 전사 대조와 같은 규율로
    # **`verification` 이 정상 status 일 때만** 본다 — 누락/어휘밖은 위에서 이미 야단쳤다.
    if unclaimed_count > 0 and seen.get("verification") in STATUSES:
        if seen["verification"] != "degraded":
            errors.append(
                f"배정에 `unclaimed` unit 이 {unclaimed_count}건 있는데 "
                f"floor:verification 이 '{seen['verification']}' 입니다 — "
                f"실행 수단이 없는 영향분이 남아 있으므로 `degraded` 여야 합니다 "
                f"(열거는 인증을 대신하지 않는다)"
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


USAGE = (
    "usage: check_qa_ledger.py --aggregate <aggregate-yaml> "
    "--assign-rows <assign-tsv> [<evidence-log-path>]"
)


def main() -> int:
    args = sys.argv[1:]

    # 둘 다 **필수**다. 선택 인자면 넘기지 않은 호출자가 조용히 대조를 면제받고,
    # 그것이 바로 이 인자들이 닫으려는 fail-open 의 모양이다 (AC60 선례).
    opt_paths: dict[str, str] = {}
    rest: list[str] = []
    i = 0
    while i < len(args):
        if args[i] in ("--aggregate", "--assign-rows"):
            if i + 1 >= len(args):
                print(f"check_qa_ledger: {args[i]} 에 값이 없습니다\n{USAGE}", file=sys.stderr)
                return 2
            if args[i] in opt_paths:
                # dict 는 마지막 값이 조용히 이긴다 — `--assign-rows A --assign-rows /dev/null`
                # 이면 집행이 완전히 꺼진 채 exit 0 이다. 인자 **모양** 오류이므로 2.
                print(
                    f"check_qa_ledger: {args[i]} 가 두 번 넘어왔습니다 "
                    f"(마지막 값이 조용히 이깁니다)\n{USAGE}",
                    file=sys.stderr,
                )
                return 2
            opt_paths[args[i]] = args[i + 1]
            i += 2
            continue
        rest.append(args[i])
        i += 1

    for flag in ("--aggregate", "--assign-rows"):
        if flag not in opt_paths:
            print(f"check_qa_ledger: {flag} 는 필수입니다\n{USAGE}", file=sys.stderr)
            return 2
    # 여기부터는 **내용** 축이다 — 읽기·파싱 실패는 4 (위 인자 모양 오류 2 와 구분).
    expected_attribution, agg_err = read_aggregate_attribution(opt_paths["--aggregate"])
    if agg_err is not None:
        print(f"check_qa_ledger: {agg_err}", file=sys.stderr)
        return 4
    unclaimed_count, assign_err = read_unclaimed_count(opt_paths["--assign-rows"])
    if assign_err is not None:
        print(f"check_qa_ledger: {assign_err}", file=sys.stderr)
        return 4

    args = rest
    if len(args) > 1:
        print(USAGE, file=sys.stderr)
        return 2
    if args:
        try:
            text = Path(args[0]).read_text(encoding="utf-8")
        except OSError as exc:
            print(f"check_qa_ledger: 읽기 실패: {exc}", file=sys.stderr)
            return 4
        except UnicodeDecodeError as exc:
            # `UnicodeDecodeError` 는 `OSError` 의 하위가 아니다 — 형제 두 read 경로에서
            # 이미 한 번씩 고친 것과 **같은 버그**가 여기만 남아 있었다(비-UTF-8 원장 →
            # 트레이스백). 세 read 경로가 이제 같은 모양이다.
            print(f"check_qa_ledger: 원장이 UTF-8 이 아닙니다: {exc}", file=sys.stderr)
            return 4
    else:
        try:
            text = sys.stdin.buffer.read().decode("utf-8")
        except UnicodeDecodeError as exc:
            print(f"check_qa_ledger: stdin이 UTF-8이 아닙니다: {exc}", file=sys.stderr)
            return 4

    # 여기 도달했으면 read_unclaimed_count 는 오류 없이 개수를 냈다 (assign_err 분기가 위에서
    # 이미 4 를 냈다). 앞 버전은 `if unclaimed_count else 0` 으로 감쌌는데, 그것은 도달 불가한
    # None 을 **fail-open 방향**(집행 소멸)으로 흡수하는 죽은 방어였다 — 이 파일이 스스로
    # 금지한 패턴이다. 형제 `expected_attribution` 은 같은 자리에서 그대로 넘긴다.
    errors = check(text, expected_attribution, unclaimed_count)
    if errors:
        for e in errors:
            print(f"check_qa_ledger: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
