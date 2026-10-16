#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_render 가 R2 형식 brief 를 읽는다 — payload §6 이 S1~Sn 전량 · §4 여러 줄 항목.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_render_r2.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
import check_brief  # noqa: E402
import roadmap_render as R  # noqa: E402
import section6  # noqa: E402
from roadmap_model import section_body  # noqa: E402

R2_BRIEF = """---
type: interview-brief
user_sourced_items:
  - id: C4
    statement: "넷째 확정"
---

# R2 brief

## 0. 한눈에

**결정 목록**

- OQ3 [열림] — 셋째 질문

## 1. Goal · Non-goal

- Goal: 목표. ⟨S1⟩

## 2. 제약

- 🗣 provisional **C4** — 넷째 확정 ⟨S1⟩

## 3. Open Questions

- OQ3 [열림] — 셋째 질문

## 4. External Landscape

- 첫 근거 «alpha» — [취함] [→ OQ3]
  본문 줄 하나 — «alpha» 를 다시 말한다
  본문 줄 둘
- 둘째 근거 «beta» — [중립] [→ OQ3]
  «alpha» 와 견준다

## 5. 기각 · Blind Spots

- 위험 — 사실 | 고칠 자리 — RC9 (p/q.py) [RC9 → OQ3]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 처음 요청

- **S2** ☑ 선택 (round 1):
  > 둘째 말

- **S3** 🗣 발화 (round 2):
  > 셋째 말

## 7. Next Action

다음.
"""
R2_AUDIT = """# audit

## 6. 사용자 원문

- **S2** ☑ 선택 (round 1):
  > 둘째 말

- **S3** 🗣 발화 (round 2):
  > 셋째 말

## 7. 원자료

- 없음
"""
TABLE = """## 분해안

| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |
|---|---|---|---|---|---|---|---|---|---|---|
| A1 | 첫 에픽 | 묶음 | 의도 | 한다 가 / 안 한다 나 | 없음 | feature/a1 | 없음 | C4 · OQ3 · RC9 · «alpha» · «beta» · S1 · S2 · S3 | 없음 | 없음 |
"""


def _bundle(brief=R2_BRIEF, audit=R2_AUDIT):
    row = R.parse_table(TABLE)[0]
    idx = R.index_brief(brief, audit)
    return R.render_bundle(row, idx, "rm/roadmap.md", "iv/b.md", "iv/b.audit.md")


class Section6NoDuplicate(unittest.TestCase):
    """A — payload §6 을 먼저 싣고, audit 항목은 그 `S<n>` 이 payload 에 없는 것만 더한다."""

    def test_each_anchor_once(self):
        s6 = section6.body(_bundle())
        for sid in ("S1", "S2", "S3"):
            with self.subTest(sid):
                self.assertEqual(s6.count("- **%s**" % sid), 1, s6)

    def test_payload_text_whole_and_first(self):
        s6 = section6.body(_bundle())
        self.assertTrue(s6.startswith("\n- **S1** 🗣 최초 요청:\n  > 처음 요청\n\n- **S2**"), s6)
        self.assertIn("- **S3** 🗣 발화 (round 2):\n  > 셋째 말\n", s6)

    def test_audit_only_anchor_still_added(self):
        audit = R2_AUDIT.replace("## 7. 원자료", "- **S4** 🗣 발화 (round 3):\n  > 넷째 말\n\n## 7. 원자료")
        s6 = section6.body(_bundle(audit=audit))
        for sid in ("S1", "S2", "S3", "S4"):
            with self.subTest(sid):
                self.assertEqual(s6.count("- **%s**" % sid), 1, s6)
        self.assertLess(s6.index("- **S3**"), s6.index("- **S4**"))
        self.assertIn("- **S4** 🗣 발화 (round 3):\n  > 넷째 말\n", s6)


class Section4MultiLine(unittest.TestCase):
    """B — §4 항목은 머리 줄 + 들여쓴 본문 줄이 한 덩어리로 실리고, 본문 줄이 key 를 되풀이해도 머리 줄이 남는다."""

    def test_head_and_body_together(self):
        s4 = section_body(_bundle(), "## 4.")
        self.assertEqual(s4, (
            "\n- 첫 근거 «alpha» — [취함] [→ OQ3]\n"
            "  본문 줄 하나 — «alpha» 를 다시 말한다\n"
            "  본문 줄 둘\n"
            "- 둘째 근거 «beta» — [중립] [→ OQ3]\n"
            "  «alpha» 와 견준다\n\n"))

    def test_head_link_not_overwritten(self):
        idx = R.index_brief(R2_BRIEF, R2_AUDIT)
        self.assertTrue(idx.lines["«alpha»"].startswith("- 첫 근거 «alpha» — [취함] [→ OQ3]\n"), idx.lines["«alpha»"])
        self.assertTrue(idx.lines["«beta»"].startswith("- 둘째 근거 «beta» — [중립] [→ OQ3]\n"), idx.lines["«beta»"])

    def test_same_items_as_gate(self):
        """묶음이 싣는 §4 덩어리는 게이트(`check_brief.section4_items`)가 보는 항목과 같다."""
        idx = R.index_brief(R2_BRIEF, R2_AUDIT)
        items = check_brief.section4_items(R2_BRIEF)
        self.assertEqual(len(items), 2)
        for (head, body), key in zip(items, ("«alpha»", "«beta»")):
            with self.subTest(key):
                got = idx.lines[key].split("\n")
                self.assertEqual(got[0], head)
                self.assertEqual([l.strip() for l in got[1:]], body)


if __name__ == "__main__":
    unittest.main()
