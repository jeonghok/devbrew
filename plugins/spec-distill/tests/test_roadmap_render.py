#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_render.py — 분해안 표 · 블록 · 묶음 · 로드맵 글과 정답 견본 대조(R4 AC4 · AC6).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_render.py
"""
from __future__ import annotations

import difflib
import re
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
import roadmap_render as R  # noqa: E402
from roadmap_model import frontmatter, parse_history, quotes, section_body, unquote  # noqa: E402

RM_REL = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose"
RM_DIR = REPO / RM_REL

MINI_BRIEF = """---
type: interview-brief
user_sourced_items:
  - id: C4
    statement: "넷째 확정"
  - id: D7
    statement: "일곱째 결정"
---

# 작은 brief

## 0. 한눈에

**결정 목록**

- OQ3 [열림] — 셋째 질문
- OQ5 [해결 ⟨S2⟩] — 다섯째 질문

## 1. Goal · Non-goal

- Goal: 작은 목표.
- Non-goal: 작은 비목표.

## 2. 제약

- ☑ confirmed **D7** — 일곱째 결정 ⟨S2⟩
- 🗣 provisional **C4** — 넷째 확정 ⟨S1⟩

## 3. Open Questions

- OQ3: 셋째 질문

## 4. External Landscape

- 둘을 한 줄에 «zeta» · «alpha» — [취함] [→ OQ3]

## 5. 기각 · Blind Spots

- 위험 — 사실 | 고칠 자리 — RC9 (p/q.py) [RC9 → OQ3]
- 기각 — 다른 갈래 — verdict: kept — ST4 — 부착 1/1
- 위험 — 실패 양식: 조용한 실패 — 근거 사례
- 위험 — 숨은 가정: 가정 셋 — 근거 약함

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 작은 요청

## 7. Next Action

다음.
"""
MINI_AUDIT = """# audit

## 6. 사용자 원문

- **S2** ☑ 선택 (round 1):
  > 고른 말

## 7. 원자료

- 없음
"""
TABLE = """# state

## 분해안

| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |
|---|---|---|---|---|---|---|---|---|---|---|
| P1 | 먼저 정할 것 | 결정 | 이름을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | 없음 | 없음 | S2 · OQ5 | 없음 | 없음 |
| A1 | 첫 에픽 | 묶음 | 첫 의도 | 한다 가 / 안 한다 나 | P1 | feature/a1 | x/y.py, z/ | RC9 · C4 · «zeta» · «alpha» · K2 · ST4 · D7 · OQ3 · S1 · K1 | P1 의 이름 | 없음 |
| B1 | 앞선 브랜치 | 브랜치 docs/specs/b1-design.md | 브랜치를 머지 | 한다 머지 / 안 한다 새 일 | 없음 | feature/b1 | 없음 | S1 · C4 · OQ3 | 없음 | 없음 |
"""


def read(rel):
    return (REPO / rel).read_text(encoding="utf-8")


class Table(unittest.TestCase):
    def test_parse(self):
        rows = R.parse_table(TABLE)
        self.assertEqual([r.id for r in rows], ["P1", "A1", "B1"])
        self.assertEqual([r.kind for r in rows], [R.KIND_DECISION, R.KIND_BUNDLE, R.KIND_BRANCH])
        self.assertEqual(rows[2].spec, "docs/specs/b1-design.md")
        self.assertEqual(rows[1].reserved, "x/y.py, z/")
        self.assertEqual(rows[1].receives, "P1 의 이름")

    def test_round_trip(self):
        rows = R.parse_table(TABLE)
        self.assertEqual(R.parse_table(R.format_table(rows)), rows)

    def test_pipe_in_cell_round_trip(self):
        rows = R.parse_table(TABLE)
        rows[1].scope = "한다 a | b / 안 한다 c"
        text = R.format_table(rows)
        self.assertIn("a \\| b", text)
        self.assertEqual(R.parse_table(text)[1].scope, "한다 a | b / 안 한다 c")

    def test_rejects(self):
        bad = {
            "머리": TABLE.replace("| 넘기는 것 |", "| 넘김 |", 1),
            "빈 칸": TABLE.replace("| 첫 의도 |", "|  |"),
            "종류": TABLE.replace("| 묶음 |", "| 꾸러미 |"),
            "결정의 브랜치": TABLE.replace("| 결정 | 이름을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | 없음 |",
                                      "| 결정 | 이름을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | feature/p1 |"),
            "발화 없는 결정": TABLE.replace("| S2 · OQ5 |", "| OQ5 |"),
            "번호 문법": TABLE.replace("| S2 · OQ5 |", "| S2 · OQ5~OQ6 |"),
            "번호 두 번": TABLE.replace("| B1 | 앞선", "| A1 | 앞선"),
            "절 없음": TABLE.replace("## 분해안", "## 다른 절"),
        }
        for name, text in bad.items():
            with self.subTest(name):
                with self.assertRaises(R.TableError):
                    R.parse_table(text)


class Render(unittest.TestCase):
    def setUp(self):
        self.rows = R.parse_table(TABLE)
        self.idx = R.index_brief(MINI_BRIEF, MINI_AUDIT)

    def test_blocks(self):
        self.assertEqual(R.render_block(self.rows[0]), (
            "### P1 — 먼저 정할 것\n- 의도: 이름을 정한다\n- 범위:\n  - 한다: 결정\n  - 안 한다: 코드\n- 의존: 없음\n"
            "- 완료: 결정 기록\n- 묶음: 없음\n- 경로 예약: 없음\n- 발화: S2\n- 항목: OQ5\n"))
        self.assertEqual(R.render_block(self.rows[1]), (
            "### A1 — 첫 에픽\n- 의도: 첫 의도\n- 범위:\n  - 한다: 가\n  - 안 한다: 나\n- 의존: P1\n"
            "- 브랜치: feature/a1\n- 묶음: A1.md\n- 경로 예약: x/y.py, z/\n"))
        self.assertEqual(R.render_block(self.rows[2]), (
            "### B1 — 앞선 브랜치\n- 의도: 브랜치를 머지\n- 범위:\n  - 한다: 머지\n  - 안 한다: 새 일\n- 의존: 없음\n"
            "- 브랜치: feature/b1\n- 묶음: 없음\n- 경로 예약: 없음\n- spec: docs/specs/b1-design.md\n"
            "- 발화: S1\n- 항목: C4 · OQ3\n"))

    def test_bundle(self):
        got = R.render_bundle(self.rows[1], self.idx, "rm/roadmap.md", "iv/b.md", "iv/b.audit.md")
        self.assertTrue(got.startswith(
            "---\ntype: epic-bundle\nepic: A1\nroadmap: rm/roadmap.md\nsource_brief: iv/b.md\n"
            "ids: [C4, D7, OQ3, RC9, K1, K2, ST4, S1, «alpha», «zeta»]\n---\n\n# A1 — 첫 에픽 · 에픽 묶음\n"))
        self.assertIn("- 원본 brief: `iv/b.md` (audit `iv/b.audit.md`)\n- 로드맵: `rm/roadmap.md` 의 `### A1` 블록\n", got)
        self.assertIn("### 이 에픽의 Goal · Non-goal\n\n- 의도: 첫 의도\n- 범위: 한다 가 / 안 한다 나\n\n"
                      "### 공통 목표\n\n- Goal: 작은 목표.\n- Non-goal: 작은 비목표.\n\n## 2. 제약\n\n"
                      "- 🗣 provisional **C4** — 넷째 확정 ⟨S1⟩\n- ☑ confirmed **D7** — 일곱째 결정 ⟨S2⟩\n\n", got)
        self.assertIn("## 3. 열린 질문\n\n- OQ3 [열림] — 셋째 질문\n\n", got)
        self.assertIn("## 4. 웹 근거\n\n- 둘을 한 줄에 «zeta» · «alpha» — [취함] [→ OQ3]\n\n", got)
        self.assertIn("## 5. 기각 · 위험\n\n- 위험 — 사실 | 고칠 자리 — RC9 (p/q.py) [RC9 → OQ3]\n"
                      "- 기각 — 다른 갈래 — verdict: kept — ST4 — 부착 1/1\n"
                      "- K1 — 위험 — 숨은 가정: 가정 셋 — 근거 약함\n"
                      "- K2 — 위험 — 실패 양식: 조용한 실패 — 근거 사례\n\n", got)
        self.assertIn("## 6. 사용자 원문\n\n- **S1** 🗣 최초 요청:\n  > 작은 요청\n\n\n- **S2** ☑ 선택 (round 1):\n"
                      "  > 고른 말\n\n## 7. 인터페이스\n\n- 받는 것: P1 의 이름\n- 넘기는 것: 없음\n", got)
        self.assertTrue(got.endswith("- 넘기는 것: 없음\n"))

    def test_bundle_missing_line_refused(self):
        self.rows[1].ids.append("C99")
        with self.assertRaises(R.TableError):
            R.render_bundle(self.rows[1], self.idx, "rm/roadmap.md", "iv/b.md", "iv/b.audit.md")

    def test_roadmap(self):
        text = R.render_roadmap(R.TEMPLATE.read_text(encoding="utf-8"), self.rows, self.idx, "작은 일",
                                "iv/b.md", "rm/roadmap.md",
                                R.history_entry("2026-10-15", "처음 로드맵", [], ["승인"]).rstrip("\n"))
        self.assertTrue(text.startswith("---\ntype: roadmap\nsource_brief: iv/b.md\n---\n\n# 작은 일 — 로드맵\n"))
        self.assertIn("## 에픽\n\n### P1 — 먼저 정할 것\n", text)
        self.assertIn("- 항목: C4 · OQ3\n\n## 지휘 절차\n", text)
        self.assertIn("`/spec-distill:epic-conductor rm/roadmap.md`", text)
        self.assertIn("## 재분해 이력\n\n### 2026-10-15 · 처음 로드맵\n- 원문:\n  - 「승인」\n\n## 위험 번호표\n", text)
        self.assertTrue(text.endswith("- K1 — 위험 — 숨은 가정: 가정 셋 — 근거 약함\n"
                                      "- K2 — 위험 — 실패 양식: 조용한 실패 — 근거 사례\n"))
        self.assertNotIn("{{", text)
        self.assertEqual(section_body(text, "## 에픽"),
                         "\n" + "\n".join(R.render_block(r) for r in self.rows) + "\n")

    def test_roadmap_without_risks(self):
        brief = "\n".join(l for l in MINI_BRIEF.splitlines() if not l.startswith("- 위험 — 숨은")
                          and not l.startswith("- 위험 — 실패")) + "\n"
        idx = R.index_brief(brief, MINI_AUDIT)
        self.assertEqual(idx.k_lines, {})
        text = R.render_roadmap(R.TEMPLATE.read_text(encoding="utf-8"), self.rows, idx, "t", "iv/b.md",
                                "rm/roadmap.md", "- h")
        self.assertTrue(text.endswith("오른쪽은 brief 원문 그대로다.\n\n- 없음\n"))

    def test_splice(self):
        text = R.render_roadmap(R.TEMPLATE.read_text(encoding="utf-8"), self.rows, self.idx, "t", "iv/b.md",
                                "rm/roadmap.md", "- 첫 줄")
        blocks = R.epic_block_texts(text)
        self.assertEqual(list(blocks), ["P1", "A1", "B1"])
        self.assertEqual(blocks["A1"], R.render_block(self.rows[1]))
        swapped = R.replace_epics(text, [blocks["B1"], blocks["P1"]])
        self.assertEqual(list(R.epic_block_texts(swapped)), ["B1", "P1"])
        self.assertEqual(swapped.split("## 지휘 절차")[1], text.split("## 지휘 절차")[1])
        added = R.append_history(text, "- 둘째 줄")
        self.assertIn("## 재분해 이력\n\n- 첫 줄\n- 둘째 줄\n\n## 위험 번호표\n", added)

    def test_extract(self):
        text = R.render_roadmap(R.TEMPLATE.read_text(encoding="utf-8"), self.rows, self.idx, "t", "iv/b.md",
                                "rm/roadmap.md", "- h")
        bundle = R.render_bundle(self.rows[1], self.idx, "rm/roadmap.md", "iv/b.md", "iv/b.audit.md")
        rows = R.extract_rows(text, lambda name: bundle if name == "A1.md" else None)
        want = R.parse_table(TABLE)
        want[1].ids = sorted(set(want[1].ids), key=R.id_sort_key)  # 묶음은 정렬된 ids 를 싣는다
        want[2].ids = ["S1", "C4", "OQ3"]
        self.assertEqual(rows, want)


class Section4RcIndex(unittest.TestCase):
    """§4 항목 첫 줄의 RC 는 그 항목(첫 줄 + 들여 쓴 본문 줄)으로 색인된다."""
    HOOK = "- 둘을 한 줄에 «zeta» · «alpha» — [취함] [→ OQ3]\n"

    def lines(self, section4):
        self.assertIn(self.HOOK, MINI_BRIEF)
        return R.index_brief(MINI_BRIEF.replace(self.HOOK, self.HOOK + section4), MINI_AUDIT).lines

    def test_head_rc_maps_to_item_with_body(self):
        got = self.lines("- 레포 주장 «repo-k» — [중립] — 이유 [RC7 → OQ3]\n  이어지는 본문 줄 (a/b.py)\n")
        self.assertEqual(got["RC7"], "- 레포 주장 «repo-k» — [중립] — 이유 [RC7 → OQ3]\n  이어지는 본문 줄 (a/b.py)")

    def test_section5_line_wins_over_section4_head(self):
        got = self.lines("- 레포 주장 «repo-k» — [중립] — 이유 [RC9 → OQ3]\n")
        self.assertEqual(got["RC9"], "- 위험 — 사실 | 고칠 자리 — RC9 (p/q.py) [RC9 → OQ3]")

    def test_body_line_rc_not_indexed(self):
        got = self.lines("- 둘째 «body-k» — [중립] — 이유 [→ 없음]\n  본문 줄 RC8 (a/b.py)\n")
        self.assertNotIn("RC8", got)


class FormatV2(unittest.TestCase):
    """R5 AC2 · AC3 · AC4 — 범위 하위 항목 · 선택 칸 · 새 재분해 이력."""

    ROW = R.Row("A1", "가", R.KIND_BUNDLE, "", "의도", "한다 상태줄 · 패널(M2 · M3 결과에 맞춤) / 안 한다 계산(R0 · R5)",
                "없음", "feature/a · feature/b", "없음", ["C4"], extras={"크기": "중", "산출물": "docs/r.md"})

    def test_scope_lines_and_text_are_inverse(self):
        for scope in ("한다 a · b / 안 한다 c", "한다 x(가 · 나) / 안 한다 없음", "자유 글 범위"):
            lines = R.scope_lines(scope)
            value = [l[4:] for l in lines[1:]] if lines[0] == "- 범위:" else lines[0][len("- 범위: "):]
            self.assertEqual(R.scope_text(value), scope)
        self.assertEqual(R.scope_lines("한다 a / 안 한다 b"), ["- 범위:", "  - 한다: a", "  - 안 한다: b"])

    def test_scope_text_joins_hand_written_items_and_rejects_others(self):
        self.assertEqual(R.scope_text(["한다: a", "한다: b", "안 한다: c"]), "한다 a · b / 안 한다 c")
        for bad in (["한다: a"], ["안 한다: c"], ["한다: a", "모름: b", "안 한다: c"]):
            with self.assertRaises(R.TableError):
                R.scope_text(bad)

    def test_render_block_new_form(self):
        self.assertEqual(R.render_block(self.ROW),
                         "### A1 — 가\n- 의도: 의도\n- 범위:\n"
                         "  - 한다: 상태줄 · 패널(M2 · M3 결과에 맞춤)\n  - 안 한다: 계산(R0 · R5)\n"
                         "- 의존: 없음\n- 브랜치: feature/a · feature/b\n- 묶음: A1.md\n- 경로 예약: 없음\n"
                         "- 크기: 중\n- 산출물: docs/r.md\n")

    def test_block_round_trip_through_parser(self):
        text = ("---\ntype: roadmap\nsource_brief: b.md\n---\n\n## 에픽\n\n" + R.render_block(self.ROW)
                + "\n## 재분해 이력\n\n- 없음\n")
        rows = R.extract_rows(text, lambda name: (
            "---\ntype: epic-bundle\nepic: A1\nroadmap: r\nsource_brief: b.md\nids: [C4]\n---\n\n"
            "## 7. 인터페이스\n\n- 받는 것: 없음\n- 넘기는 것: 없음\n"))
        self.assertEqual(rows, [self.ROW])

    def test_extract_table_parse_is_stable_with_none_and_list_fields(self):
        block = ("### A1 — 가\n- 의도: 의도\n- 범위: 자유\n- 의존: 없음\n- 브랜치: feature/a\n- 묶음: A1.md\n"
                 "- 경로 예약: 없음\n- 병렬: 없음\n- 근거:\n  - 하나\n  - 둘\n")
        text = "---\ntype: roadmap\nsource_brief: b.md\n---\n\n## 에픽\n\n" + block + "\n## 재분해 이력\n\n- 없음\n"
        bundle = ("---\ntype: epic-bundle\nepic: A1\nroadmap: r\nsource_brief: b.md\nids: [C4]\n---\n\n"
                  "## 7. 인터페이스\n\n- 받는 것: 없음\n- 넘기는 것: 없음\n")
        rows = R.extract_rows(text, lambda name: bundle)
        self.assertNotIn("병렬", rows[0].extras)
        self.assertIn("근거", rows[0].extras)
        self.assertEqual(R.parse_table(R.format_table(rows)), rows)

    def test_table_narrow_unless_extras(self):
        plain = R.Row("B1", "나", R.KIND_DECISION, "", "i", "s", "없음", "없음", "없음", ["S1", "C4"])
        narrow = R.format_table([plain])
        self.assertIn("| " + " | ".join(R.COLUMNS) + " |", narrow)
        self.assertNotIn("크기", narrow)
        wide = R.format_table([plain, self.ROW])
        self.assertIn(" | ".join(R.COLUMNS + R.EXTRA_COLUMNS), wide)
        self.assertEqual(R.parse_table(wide), [plain, self.ROW])
        self.assertEqual(R.parse_table(narrow), [plain])

    def test_history_entry(self):
        self.assertEqual(R.history_entry("2026-10-17", "재분해", ["바뀐 에픽 R5", "새 에픽 R11"], ["좋아", "가 「나」 다"]),
                         "### 2026-10-17 · 재분해\n- 바뀜: 바뀐 에픽 R5 · 새 에픽 R11 「좋아」 · 「가 「나」 다」\n"
                         "- 원문:\n  - 「좋아」\n  - 「가 「나」 다」\n")
        self.assertEqual(R.history_entry("2026-10-17", "재분해", ["바뀐 에픽 R5"], ["하나"]),
                         "### 2026-10-17 · 재분해\n- 바뀜: 바뀐 에픽 R5 「하나」\n- 원문:\n  - 「하나」\n")
        self.assertEqual(R.history_entry("2026-10-17", "처음 로드맵", [], ["승인"]),
                         "### 2026-10-17 · 처음 로드맵\n- 원문:\n  - 「승인」\n")
        for bad in ("열린 「 하나", "닫힌 」 하나", "", "줄\n바꿈", "줄\r바꿈", "줄\u2028바꿈"):
            with self.assertRaises(R.TableError):
                R.history_entry("2026-10-17", "x", [], [bad])

    def test_history_entry_round_trips_with_quotes_at_end_of_change(self):
        for qs in (["하나"], ["첫째", "둘째 「안」"]):
            entry = R.history_entry("2026-10-17", "재분해", ["바뀐 에픽 R5"], qs)
            got, errors = parse_history("## 재분해 이력\n\n" + entry + "\n## 위험 번호표\n")
            self.assertEqual(errors, [])
            self.assertEqual(got[0]["quotes"], ["「%s」" % q for q in qs])
            self.assertEqual(len(got[0]["changes"]), 1)
            self.assertTrue(got[0]["changes"][0].startswith("바뀐 에픽 R5 「"))
            self.assertEqual(quotes(got[0]["changes"][0]), got[0]["quotes"])

    def test_history_entry_without_user_words(self):
        got = R.history_entry("2026-10-15", "판정", ["가 「설계 판정」"], [], no_words="사용자 말 없음(설계 판정)")
        self.assertEqual(got, "### 2026-10-15 · 판정\n- 바뀜: 가 「설계 판정」\n- 원문: 없음 — 사용자 말 없음(설계 판정)\n")
        for quotes, why in (([], ""), (["a"], "사유"), ([], "줄\n바꿈")):
            with self.assertRaises(R.TableError):
                R.history_entry("2026-10-15", "x", [], quotes, no_words=why)

    def test_append_history_new_entry_after_old_lines(self):
        text = "## 재분해 이력\n\n- 2026-10-11 · 처음 · 「a」\n\n## 위험 번호표\n"
        got = R.append_history(text, R.history_entry("2026-10-17", "재분해", [], ["b"]))
        self.assertEqual(got, "## 재분해 이력\n\n- 2026-10-11 · 처음 · 「a」\n\n### 2026-10-17 · 재분해\n"
                              "- 원문:\n  - 「b」\n\n## 위험 번호표\n")


class GoldenSample(unittest.TestCase):
    """AC6 — 이번 로드맵에서 뽑은 표로 만든 묶음 · 블록이 손으로 만든 것과 바이트가 같다."""

    def setUp(self):
        self.roadmap = (RM_DIR / "roadmap.md").read_text(encoding="utf-8")
        self.rows = R.extract_rows(
            self.roadmap,
            lambda n: (RM_DIR / n).read_text(encoding="utf-8") if (RM_DIR / n).is_file() else None)
        self.brief_rel = unquote(frontmatter(self.roadmap)["source_brief"])
        self.audit_rel = self.brief_rel[:-3] + ".audit.md"
        self.idx = R.index_brief(read(self.brief_rel), read(self.audit_rel))

    def _diff(self, name, want, got):
        lines = difflib.unified_diff(want.splitlines(True), got.splitlines(True), "손", "생성", n=1)
        return name + "\n" + "".join(list(lines)[:30])

    def test_kinds_present(self):
        kinds = {r.id: r.kind for r in self.rows}
        self.assertEqual(kinds["P1"], R.KIND_BRANCH)
        self.assertEqual(kinds["P3"], R.KIND_DECISION)
        self.assertEqual(kinds["R0"], R.KIND_BRANCH)
        # 묶음 에픽 수는 살아 있는 로드맵에서 재분해로 늘 수 있다 — 숫자를 박지 않고, 에픽 번호 꼴의
        # 파일(R10.md · P1.md 등)이 묶음 종류 블록과 정확히 같은 집합인지 양쪽으로 잰다: 블록 없는 묶음
        # 파일(지난 재분해의 찌꺼기)도, 묶음이 아닌 블록 이름의 파일도 실패다.
        bundles = sorted(i for i, k in kinds.items() if k == R.KIND_BUNDLE)
        self.assertGreaterEqual(len(bundles), 10)
        on_disk = sorted(p.stem for p in RM_DIR.glob("*.md") if re.fullmatch(r"[PR]\d+[a-z]?", p.stem))
        self.assertEqual(on_disk, bundles)

    def test_bundles_byte_equal(self):
        diffs = []
        for r in self.rows:
            if r.kind != R.KIND_BUNDLE:
                continue
            want = (RM_DIR / (r.id + ".md")).read_text(encoding="utf-8")
            got = R.render_bundle(r, self.idx, RM_REL + "/roadmap.md", self.brief_rel, self.audit_rel)
            if got != want:
                diffs.append(self._diff(r.id, want, got))
        self.assertEqual(diffs, [], "\n".join(diffs))

    def test_blocks_byte_equal(self):
        hand = R.epic_block_texts(self.roadmap)
        diffs = [self._diff(r.id, hand[r.id], R.render_block(r)) for r in self.rows
                 if R.render_block(r) != hand[r.id]]
        self.assertEqual(diffs, [], "\n".join(diffs))

    def test_epics_section_rebuilds(self):
        self.assertEqual(section_body(self.roadmap, "## 에픽"),
                         "\n" + "\n".join(R.render_block(r) for r in self.rows) + "\n")

    def test_risk_table(self):
        hand = [l for l in section_body(self.roadmap, "## 위험 번호표").splitlines() if l.startswith("- K")]
        self.assertEqual(list(self.idx.k_lines.values()), hand)

    def test_table_round_trip(self):
        self.assertEqual(R.parse_table(R.format_table(self.rows)), self.rows)


if __name__ == "__main__":
    unittest.main()
