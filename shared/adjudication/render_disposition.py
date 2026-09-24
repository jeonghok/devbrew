# -*- coding: utf-8 -*-
"""처분 세 줄 — 소비자들이 공유하는 렌더.

회계 모듈(`adjudication.py`)은 «회계만» 한다(모듈 docstring:3-5). 서식은
이 파일의 몫이고, 여기 한 벌만 둔다 — 사본이 여럿이면 한 칸을 고칠 때 나머지가
남는다.

칸의 합계와 차단은 «같은 집합이 아니다». `coerced` 는 배관 칸에 실리지만
blocks() 가 읽지 않고, `unknown_counts` 는 counts dict 에 없지만 blocks() 의
세 항 중 하나다. 그래서 각 줄에 (차단)/(차단 아님) 을 리터럴로 붙인다.
"""


def disposition_lines(report, held_classes):
    """`Ledger.report()` 와 `held_by_class()` 로 세 줄을 만든다.

    반환은 `(처분줄, 배관줄, 풀이줄, advisory목록)` **4-튜플**. 풀이 줄은 앞 두 줄
    «둘 다»의 낱말을 푸므로 어느 한쪽 문자열 안에 개행으로 넣지 않는다 — 그러면 그
    줄이 다른 줄의 낱말을 설명하는 꼴이 된다. 기존 3-튜플 언패킹은 `ValueError` 로
    소리 내며 깨진다(조용히 넘어가지 않는 것이 이 선택의 핵심이다).

    회계 낱말은 **그대로 둔다** — 바꾸는 것이 아니라 사람말을 옆에 붙인다.
    advisory 는 미지 접두가 있을 때만 비어 있지 않다 — 회계 모듈이 아니라
    소비자가 내는 것이 계약이다.
    """
    c = report["counts"]
    # `.get()` 이 아니라 첨자다 — 이 키는 `report()` 가 항상 낸다. 없으면
    # 회계 계약이 깨진 것이고, 조용한 `[]` 보다 KeyError 가 정직하다.
    unknown = report["unknown_counts"]

    line1 = ("**처분:** 수용 %d · 기각 %d · 억제 %d · 흡수 %d · 미판정 %d"
             "     (차단 아님)"
             % (c["accepted"], c["rejected"], c["suppressed"], c["absorbed"],
                held_classes["판정자 부재"]))

    plumbing = (c["sources_failed"] + held_classes["항목 파손"]
                + held_classes["기타"] + c["coerced"])
    line2 = ("**배관 손실:** %d · 셀 수 없음 %d     (차단: %s)"
             % (plumbing, len(unknown), "예" if report["degraded"] else "아니오"))

    # 「배관 손실」의 풀이는 **바로 위 `plumbing` 의 실제 합**을 따라 적는다 —
    # sources_failed(입력이 죽었다) + 항목 파손 + 기타 + coerced(값을 보정했다).
    # 「판정에 못 들어간 것」으로 적으면 그 칸이 세는 것과 다른 말이 된다.
    line3 = ("↳ 억제=규칙이 자른 것 · 흡수=같은 것끼리 합친 것 · 미판정=볼 사람이 없던 것"
             " · 배관 손실=입력이 죽었거나 항목이 깨졌거나 값을 보정한 것")

    advisories = []
    # `held` 는 «분해해서» 싣는다 — 세 클래스가 두 칸에 나뉘어 들어간다.
    # 그 분해가 무손실인지 여기서 «읽어» 확인한다: 갈리면 두 칸의 합이 실제
    # 보류 건수와 달라지고, 그 차이는 어느 칸에도 안 남는다.
    if sum(held_classes.values()) != c["held"]:
        advisories.append(
            "[adjudication] hold 분류 합 %d ≠ held 총계 %d — 렌더가 항목을 잃는다."
            % (sum(held_classes.values()), c["held"]))
    if held_classes["기타"] > 0:
        advisories.append(
            "[adjudication] hold 사유 %d건이 알려진 접두(「판정자 부재: 」·"
            "「항목 파손: 」)에 안 걸린다 — 배관 칸에 실었으나 분류되지 않았다."
            % held_classes["기타"])
    return line1, line2, line3, advisories


def disposition_report(report, held_classes):
    """구조화된 출력(YAML·키=값)을 내는 소비자용 — 칸을 «이름으로» 편다.

    `report["counts"]` 를 통째로 넘기지 않는다. 통째로 넘기면 소비자 코드에
    카운트 이름이 한 번도 안 나타나고, 그러면 어휘가 늘어도 그 소비자는
    조용하다 — 그것이 L2 가 막으려는 침묵이다. 여기 한 벌만 편다.
    """
    c = report["counts"]
    return {
        "accepted": c["accepted"],
        "rejected": c["rejected"],
        "held": c["held"],
        "absorbed": c["absorbed"],
        "coerced": c["coerced"],
        "sources_failed": c["sources_failed"],
        "suppressed": c["suppressed"],
        "unknown_counts": report["unknown_counts"],
        "held_by_class": dict(held_classes),
        "degraded": report["degraded"],
        "reasons": report["reasons"],
    }
