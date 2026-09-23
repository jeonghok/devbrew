#!/usr/bin/env python3
"""판정 어휘 — 세 값과 닫힌 사유 열거 (설계 §6.4.3, AC8 · AC9 · AC23).

**판정 어휘를 이 파일 밖에 두지 않는다.** 산출자가 여럿이면 우선순위
(`defect > not-certified > clean`)를 적용할 자리가 없어진다.

입력은 셋이다 — 리뷰 축(합성기의 원장), 차등 축(`diff-test-results.py` 의
`degrade_causes` · `verdict_input`), 그리고 호출자만 아는 사유(kill switch ·
trivia · 합치기 충돌 · 선언 무효 · 스코프 0 · 각도 부재).
"""
import argparse
import re
import sys

# 우선순위 순서 — 앞이 이긴다. 확증 결함과 미판정이 같은 실행에서 나면 `defect` 다
# (설계 §6.4.3). 이 순서를 뒤집으면 오늘 결함으로 잡히던 실행이 내일 미판정으로
# 내려앉는다.
VALUES = ("defect", "not-certified", "clean")

# 닫힌 열거. **튜플 순서가 곧 `reason:` 우선순위**다 — 앞쪽일수록 「그 뒤 전부를
# 설명한다」: 파이프라인이 아예 안 돈 것 → 대상 자체가 서지 않은 것 → 대조 대상이
# 없는 것 → 리뷰 축 → 차등 축의 해상도 문제.
REASONS = (
    "trivia",               # 파이프라인 전체가 생략됨 (C4 의 두 탈출구 중 하나)
    "kill-switch",          # 차등 테스트가 kill switch 로 생략됨 (나머지 하나)
    "declaration-invalid",  # 트레일러가 있으나 경로 부재 · 한 브랜치에 다른 토픽 키
    "merge-conflict",       # 끝점 합치기가 rc 1 (§6.2.4 · AC7)
    "scope-empty",          # 대조할 대상이 0 인데 변경은 있다
    "findings-lost",        # 리뷰 항목이 소실됐거나 셀 수 없다
    "angle-absent",         # 보안 또는 판정 각도가 absent (§6.3.1 — PR3 가 배선한다)
    "baseline-unrunnable",  # 기준선 축이 안 돌아 귀속의 한쪽이 없음
    "silent-drop",          # 영향분으로 고른 unit 이 HEAD 에서 미확인
    "error-axis",           # 어느 축이든 error 상태가 닿음
    "granularity-smear",    # bulk 도말 또는 smeared
)

# `diff-test-results.py` 의 `degrade_causes` → 이 어휘.
# `expected-empty`(영향분 0개)와 `no-adapters`(어댑터 0개)에는 설계가 이름을 주지
# 않았다 — 둘 다 「대조할 대상이 0 이다」라서 `scope-empty` 로 보낸다(계획 R-A).
CAUSE_TO_REASON = {
    "expected-empty": "scope-empty",
    "no-adapters": "scope-empty",
    "baseline-unrunnable": "baseline-unrunnable",
    "silent-drop": "silent-drop",
    "error-axis": "error-axis",
    "bulk-pre-existing": "granularity-smear",
    "smeared": "granularity-smear",
}

# ── AC23 — 옛 판정 어휘 매핑표. **PR4 가 산출자(runtime-verifier)와 함께 이 블록을
#    통째로 지운다.** PR5 시점에 남아 있으면 그 자체가 결함이다.
#    값만 옮긴다 — 사유는 옮기지 않는다. `SKIP_WITH_EVIDENCE` 는 여러 원인을 한 값에
#    접은 것이라 사유를 복원할 수 없고, 사유 없는 `not-certified` 는 AC8 위반이라
#    낼 수 없다. 그래서 호출자가 `--reason` 을 함께 주지 않으면 fail-closed 다.
LEGACY_VERDICTS = {
    "PASS": "clean",
    "FAIL": "defect",
    "SKIP_WITH_EVIDENCE": "not-certified",
    "NEEDS_RESOLUTION": "not-certified",
}
# ── AC23 블록 끝 ──────────────────────────────────────────────────────────


def fail4(msg):
    # `verdict:` 를 쓰지 않는다 — 그것은 성공 출력의 판정 키다. `field verdict
    # "$text"`(shared/tests/assert.sh:95) 같은 순진한 파서가 이 오류 문장을 넷째
    # 판정값으로 읽는다. 형제 `diff-test-results.py` 의 `print(f"diff-test-results:
    # {msg}", ...)` 와 같은 모양으로 스크립트 이름을 접두사로 쓴다.
    print(f"verdict.py: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_or_none(path):
    """경로가 없으면 `None`(이 실행이 그 축을 안 쓴다) — 있는데 못 읽으면 exit 4.

    둘을 합치면 파일이 사라진 실행이 조용히 `clean` 으로 샌다.
    """
    if not path:
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError as exc:
        fail4(f"차등 산출물을 읽지 못했다: {path} ({exc})")
    except UnicodeDecodeError as exc:
        # UnicodeDecodeError 는 ValueError 의 하위이지 OSError 가 아니다 — 위 절만
        # 두면 비-UTF-8 입력이 raw traceback + exit 1 로 이 docstring 이 금지한
        # 0/2/4 계약을 그대로 탈출한다. 형제 `diff-test-results.py` 의
        # `read_text_or_fail4`(75-82행)는 이미 이 절을 갖고 있다(/qg iter-7 M2) —
        # 여기만 없었던 것이 이번 라운드에서 잡힌 결함이다.
        fail4(f"차등 산출물이 UTF-8 이 아님: {path} ({exc})")


def causes_of(differential_text):
    """`degrade_causes: [...]` 를 정확히 한 번 읽는다. per-adapter 와 집계가 같은 표기다."""
    hits = re.findall(r"^degrade_causes: \[(.*)\]$", differential_text, re.M)
    if len(hits) != 1:
        fail4(f"degrade_causes 줄이 {len(hits)}회 (정확히 1회여야 함)")
    return [c.strip() for c in hits[0].split(",") if c.strip()]


def defect_flag_of(differential_text):
    hits = re.findall(r"^  confirmed_product_defect: (true|false)$",
                      differential_text, re.M)
    if len(hits) != 1:
        fail4(f"confirmed_product_defect 줄이 {len(hits)}회 (정확히 1회여야 함)")
    return hits[0] == "true"


def decide(*, defect=False, review_blocked=False, angle_absent=False,
           differential_text=None, extra_reasons=(), legacy_verdict=None):
    reasons = []

    def add(r):
        if r not in REASONS:
            fail4(f"열거 밖 사유 '{r}' — 어휘는 닫혀 있다")
        if r not in reasons:
            reasons.append(r)

    for r in extra_reasons:
        add(r)

    if differential_text is not None:
        for c in causes_of(differential_text):
            if c not in CAUSE_TO_REASON:
                fail4(f"미지의 degrade_cause '{c}'")
            add(CAUSE_TO_REASON[c])
        defect = defect or defect_flag_of(differential_text)

    # 헌장 — 막는 것은 「항목이 소실됐거나 셀 수 없거나 주 판정자가 죽었을 때」다.
    # 모델 다양성 손실 같은 나머지 degrade 는 공시만 한다. 그래서 원장의
    # `degraded`(공시)가 아니라 차단 쪽 술어를 받는다.
    #
    # 그 셋은 **두 사유로 갈린다**(설계 §6.4.3). 앞 둘(소실·미상)은 항목을
    # «잃은» 것이라 `findings-lost` 이고, 셋째(주 판정자 사망)는 아무도 그 축을
    # «안 본» 것이라 `angle-absent` 다 — 각도가 `absent` 인 것과 같은 사실이다
    # (§6.3.5 의 표: 「도출이 잘못돼 아무도 안 불림 → 각도 absent」).
    # PR2 는 셋을 `findings-lost` 하나로 접고 있었고(I2 가 기록한 알려진 편차),
    # 그 분리에 필요한 공개 accessor 둘을 이 PR 이 `Ledger` 에 세웠다.
    # 호출자는 `review_blocked=ledger.items_unaccounted()` 와
    # `angle_absent=(각도 absent) or ledger.primary_source_failed()` 로 준다.
    if review_blocked:
        add("findings-lost")
    if angle_absent:
        add("angle-absent")

    if legacy_verdict is not None:
        if legacy_verdict not in LEGACY_VERDICTS:
            fail4(f"미지의 옛 판정값 '{legacy_verdict}'")
        mapped = LEGACY_VERDICTS[legacy_verdict]
        if mapped == "defect":
            defect = True
        elif mapped == "not-certified" and not reasons:
            fail4(f"'{legacy_verdict}' 는 사유를 싣지 않는다 — "
                  "사유 없는 not-certified 는 AC8 위반이다. --reason 을 함께 줘라")

    reasons.sort(key=REASONS.index)
    if defect:
        return {"verdict": "defect", "reason": None, "reasons": reasons}
    if reasons:
        return {"verdict": "not-certified", "reason": reasons[0], "reasons": reasons}
    return {"verdict": "clean", "reason": None, "reasons": []}


def render(decision):
    # `VALUES` 를 `decide()` · `render()` 어느 쪽도 참조하지 않으면, "판정 어휘가
    # 이 파일 한 곳에만 산다" 는 이 모듈의 존재 이유가 강제되지 않는 문서가 된다.
    # 여기서 막아 값 자체를 그 상수 밖으로 못 나가게 한다.
    if decision["verdict"] not in VALUES:
        fail4(f"열거 밖 판정값 '{decision['verdict']}' — 어휘는 닫혀 있다")
    out = [f"verdict: {decision['verdict']}"]
    if decision["verdict"] == "not-certified":
        if not decision["reason"]:
            fail4("사유 없는 not-certified (AC8)")
        out.append(f"reason: {decision['reason']}")
    if decision["reasons"]:
        out.append("reasons: [" + ", ".join(decision["reasons"]) + "]")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--differential", default=None)
    ap.add_argument("--defect", action="store_true")
    ap.add_argument("--review-blocked", action="store_true")
    ap.add_argument("--angle-absent", action="store_true")
    ap.add_argument("--reason", action="append", default=[])
    ap.add_argument("--legacy-verdict", default=None)
    args = ap.parse_args()
    # 기본값을 `""` 로 두면 "플래그를 안 줬다" 와 "빈 경로를 줬다" 가 같은 값이
    # 된다 — 값을 못 구한 호출자가 `--differential "$DIFF_YAML"` 을 빈 변수로
    # 호출하면 차등 축이 조용히 사라지고 `clean` 으로 인증된다(read_or_none 의
    # docstring 이 금지한 바로 그 새는 경로). 기본값을 `None` 으로 바꿔 두 경우를
    # 구별하고, **명시적으로 빈 문자열**을 주면 usage 오류(exit 2)로 막는다 —
    # exit 4(fail-closed 판정 실패)가 아니라 exit 2(잘못된 호출)다: 이것은 판정
    # 축의 문제가 아니라 호출 자체가 말이 안 되는 것이다.
    if args.differential is not None and args.differential == "":
        print("verdict.py: --differential 은 빈 문자열을 받지 않는다 "
              "(플래그를 생략하거나 실제 경로를 줘라)", file=sys.stderr)
        return 2
    if args.legacy_verdict is not None and args.legacy_verdict == "":
        print("verdict.py: --legacy-verdict 는 빈 문자열을 받지 않는다",
              file=sys.stderr)
        return 2
    sys.stdout.write(render(decide(
        defect=args.defect,
        review_blocked=args.review_blocked,
        angle_absent=args.angle_absent,
        differential_text=read_or_none(args.differential),
        extra_reasons=args.reason,
        legacy_verdict=args.legacy_verdict,
    )))
    return 0


if __name__ == "__main__":
    sys.exit(main())
