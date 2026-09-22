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
    print(f"verdict: {msg}", file=sys.stderr)
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


def decide(*, defect=False, review_blocked=False, differential_text=None,
           extra_reasons=(), legacy_verdict=None):
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
    # `degraded`(공시)가 아니라 `blocks()`(차단)를 받는다.
    if review_blocked:
        add("findings-lost")

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
    ap.add_argument("--differential", default="")
    ap.add_argument("--defect", action="store_true")
    ap.add_argument("--review-blocked", action="store_true")
    ap.add_argument("--reason", action="append", default=[])
    ap.add_argument("--legacy-verdict", default="")
    args = ap.parse_args()
    sys.stdout.write(render(decide(
        defect=args.defect,
        review_blocked=args.review_blocked,
        differential_text=read_or_none(args.differential),
        extra_reasons=args.reason,
        legacy_verdict=args.legacy_verdict or None,
    )))
    return 0


if __name__ == "__main__":
    sys.exit(main())
