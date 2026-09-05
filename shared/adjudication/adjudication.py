"""subagent 발견의 처분 회계.

이 모듈은 **회계만** 한다. 출력 서식의 권위가 아니다 — 각 소비자는 자기 필드명으로
렌더한다(`proceed-gate.md` 이 «이 계약이 정하는 것은 "감추지 않는다" 뿐이고, 각 skill 은
자기 degrade 채널을 자기 어휘 절에 이름으로 명시해야 한다»로 필드 통일을 명시적으로
거절했고, 형제 `_norm_sev` 둘이 반대 방향 기본값을 각자 근거와 함께 갖는다).
인용은 줄번호가 아니라 원문으로 한다 — 그 파일이 늘 때마다 번호가 밀린다(실측:
`:34-37` 은 지금 옵션 표를 가리키고 근거 문장은 다른 자리에 있다).

다섯 가지 처분을 구별한다(`accept()`·`reject()`·`suppressed()` 는 정상 판정이라
이 목록 밖이다 — 여기 있는 것은 «항목이 온전히 판정되지 못한» 방식들이다):
  소실       — 항목이 사라지고 아무도 세지 않음        → hold()
  흡수       — 중복이 흡수처에 귀속, 소실이 아님       → absorbed()
  강제       — 항목이 아니라 값을 대체                 → coerced()
  원리적 미상 — 개수를 셀 방법이 없음                  → uncountable()
  입력 사망   — 판정자(소스) 자체가 죽음               → source_failed()

`degraded`(공시)와 `blocks()`(차단)는 **다른 술어**다:
  blocks()  == held > 0  or  unknown_counts  or  주(主) source_failed
  degraded  == 위 셋 중 하나  or  보조 source_failed  or  coerced(gate=True)
"""

_ITEM_DIRECTIONS = ("open", "closed")


class Ledger:
    """처분 원장.

    items: 미판정 항목의 방향. 다음 소비자가 기계(자동 편집)면 "closed"(제외),
           사람이면 "open"(라벨을 붙여 보여준다). 소비자 «신원»이 아니라
           «방향»이 인자다.
    """

    def __init__(self, items="open"):
        if items not in _ITEM_DIRECTIONS:
            raise ValueError(
                "items must be one of %r, got %r" % (_ITEM_DIRECTIONS, items))
        self.items = items
        self._accepted = []          # [item]
        self._rejected = []          # [(item, why)]
        self._held = []              # [(item, why)]
        self._absorbed = []          # [(item, into)]
        self._coerced = []           # [(field, frm, to, gate)]
        self._sources_failed = []    # [(name, why, primary)]
        self._unknown = []           # [(what, why)]
        self._suppressed = []        # [(item, why)]

    # ── 처분 ──────────────────────────────────────────────────────────
    def accept(self, item):
        """수용."""
        self._accepted.append(item)

    def reject(self, item, why):
        """기각 — 근거 있는 배제."""
        self._rejected.append((item, why))

    def hold(self, item, why):
        """보류 — 판정하지 못했다. 소실의 정직한 이름이다."""
        self._held.append((item, why))

    def absorbed(self, item, into):
        """흡수 — 중복이 `into` 에 귀속됐다. 소실이 아니므로 degraded 가 아니다."""
        self._absorbed.append((item, into))

    def coerced(self, field, frm, to, gate=False):
        """강제 — 항목이 아니라 값을 대체했다.

        gate=True 는 그 대체가 **게이트 판정을 바꾼다**는 뜻이다
        (예: raised_count 5→0 이 `>=3` 정체 게이트를 무력화). 그때만 degraded.
        """
        self._coerced.append((field, frm, to, bool(gate)))

    def source_failed(self, name, why, primary=True):
        """입력 자체가 죽었다.

        primary=True 는 그 축의 유일한 판정자(그것이 죽으면 아무도 안 봤다),
        False 는 모델 다양성 보조(codex 등 — 죽어도 축은 살아 있다).
        """
        self._sources_failed.append((name, why, bool(primary)))

    def uncountable(self, what, why):
        """개수를 원리적으로 모른다.

        0 이 아니다. 0 은 거짓 clean 이다.
        """
        self._unknown.append((what, why))

    def suppressed(self, item, why):
        """규칙 억제 — 판정자의 판단이 아니라 규칙(임계값)이 정한 배제.

        `reject` 와 합치지 않는다. 합치면 「누가 왜 뺐나」가 다시 사라진다.
        degrade 가 아니고 차단하지도 않는다: 규칙이 예상대로 작동한 것이다.
        """
        self._suppressed.append((item, why))

    # ── 파생 술어 ─────────────────────────────────────────────────────
    def _has_primary_source_failure(self):
        return any(primary for (_n, _w, primary) in self._sources_failed)

    def _has_gate_coercion(self):
        return any(gate for (_f, _a, _b, gate) in self._coerced)

    _HOLD_CLASSES = ("판정자 부재", "항목 파손")

    def held_by_class(self):
        """`hold()` 의 `why` 접두별 개수. 합은 항상 `held` 총계와 같다.

        알려진 접두에 안 걸리는 사유는 «기타» 로 «센다» — 버리면 이 반환의
        합이 held 와 갈라지고, 그 차이는 소비자의 출력에서 조용히 사라진다.
        `"기타" > 0` 일 때 advisory 를 내는 것은 소비자의 책임이다 — 이 모듈은
        회계만 하고 렌더 권위가 아니다(모듈 docstring).
        """
        out = {k: 0 for k in self._HOLD_CLASSES}
        out["기타"] = 0
        for (_item, why) in self._held:
            for k in self._HOLD_CLASSES:
                if str(why).startswith(k):
                    out[k] += 1
                    break
            else:
                out["기타"] += 1
        return out

    def blocks(self):
        """차단 — 항목이 소실됐거나 셀 수 없거나 그 축의 주(主) 판정자가 죽었을 때만 참.

        보조(모델 다양성) 손실은 공시하되 막지 않는다. 무조건 True 로 만들면
        test_merge_review.py:130-135(AC10)·:144-148·:154-158 이 깨진다 —
        화석이 아니라 계약이다.
        """
        return (bool(self._held)
                or bool(self._unknown)
                or self._has_primary_source_failure())

    def _degraded(self):
        return (self.blocks()
                or bool(self._sources_failed)
                or self._has_gate_coercion())

    # ── 출력 ─────────────────────────────────────────────────────────
    def reasons(self):
        """degrade 사유를 사람이 읽는 한 줄씩."""
        out = []
        for (item, why) in self._held:
            out.append("보류: %s — %s" % (item, why))
        for (what, why) in self._unknown:
            out.append("셀 수 없음: %s — %s" % (what, why))
        for (name, why, primary) in self._sources_failed:
            out.append("입력 실패(%s): %s — %s"
                       % ("주" if primary else "보조", name, why))
        for (field, frm, to, gate) in self._coerced:
            if gate:
                out.append("강제(게이트 변경): %s %r→%r" % (field, frm, to))
        return out

    def report(self):
        return {
            "counts": {
                "accepted": len(self._accepted),
                "rejected": len(self._rejected),
                "held": len(self._held),
                "absorbed": len(self._absorbed),
                "coerced": len(self._coerced),
                "sources_failed": len(self._sources_failed),
                "suppressed": len(self._suppressed),
            },
            "degraded": self._degraded(),
            "unknown_counts": [what for (what, _why) in self._unknown],
            "reasons": self.reasons(),
        }

    def surfaced(self):
        """미판정 항목 — items 방향에 따라 보여주거나 제외한다."""
        if self.items == "closed":
            return []
        out = [{"label": "held", "item": item, "why": why}
               for (item, why) in self._held]
        out += [{"label": "uncountable", "item": None, "what": what, "why": why}
                for (what, why) in self._unknown]
        return out
