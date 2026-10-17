#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_write.py migrate — 옛 블록을 새 형식으로, 인용을 잃지 않고(R5 AC4).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_migrate.py
"""
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
import roadmap_render as R  # noqa: E402
import roadmap_write as W  # noqa: E402
from roadmap_model import parse_history, parse_roadmap, quotes  # noqa: E402

PRE = "ed0da79f"   # #221 까지 합친 첫 병합 커밋 — 이 앞의 로드맵이 옮기기 전 정본이다
RM = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"


def git_show(rev_path: str) -> str:
    proc = subprocess.run(["git", "-C", str(REPO), "show", rev_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise AssertionError("git show %s 실패: %s" % (rev_path, proc.stderr.decode("utf-8", "replace")))
    return proc.stdout.decode("utf-8")


class MigrateText(unittest.TestCase):
    def test_crlf_roadmap_keeps_every_crlf(self):
        old = road(blk(), blk(head="### A2 — 나\n")).replace("\n", "\r\n")
        new = W.migrated_text(old, None)
        self.assertEqual(new.count("\r\n"), new.count("\n"))
        self.assertEqual(new, old.replace(OLD_SCOPE.replace("\n", "\r\n"), NEW_SCOPE.replace("\n", "\r\n")))

    def test_migrate_reads_crlf_without_folding_it(self):
        import shutil
        import tempfile
        tmp = tempfile.mkdtemp()
        try:
            path = Path(tmp) / "roadmap.md"
            raw = road(blk()).replace("\n", "\r\n").encode("utf-8")
            path.write_bytes(raw)
            self.assertEqual(W.read(path, keep_newlines=True).encode("utf-8"), raw)
            self.assertNotIn("\r", W.read(path))
        finally:
            shutil.rmtree(tmp)

    def test_old_blocks_become_new_with_same_quotes(self):
        old = git_show(PRE + ":" + RM)
        new = W.migrated_text(old, lambda n: git_show("%s:%s/%s" % (PRE, Path(RM).parent.as_posix(), n)))
        self.assertNotEqual(new, old)
        self.assertEqual(set(quotes(old)), set(quotes(new)))
        self.assertEqual(parse_roadmap(new)[4], [])
        self.assertIn("- 범위:\n  - 한다: ", new)

    def test_migrated_text_is_a_fixed_point(self):
        old = git_show(PRE + ":" + RM)
        read = lambda n: git_show("%s:%s/%s" % (PRE, Path(RM).parent.as_posix(), n))  # noqa: E731
        once = W.migrated_text(old, read)
        self.assertEqual(W.migrated_text(once, read), once)


HEAD = "---\ntype: roadmap\nsource_brief: b.md\n---\n\n# r\n\n## 에픽\n\n"
TAIL = "## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n"
OLD_SCOPE = "- 범위: 한다 x 「말」 / 안 한다 y\n"
NEW_SCOPE = "- 범위:\n  - 한다: x 「말」\n  - 안 한다: y\n"


def blk(intent="- 의도: 의도\n", scope=OLD_SCOPE, extra="", head="### A1 — 가\n"):
    return (head + intent + scope + "- 의존: 없음\n- 브랜치: feature/a\n- 묶음: A1.md\n- 경로 예약: 없음\n"
            + extra + "\n")


def road(*parts):
    return HEAD + "".join(parts) + TAIL


class MigrateKeepsEveryOtherByte(unittest.TestCase):
    """블록의 범위 한 줄만 바뀌고 나머지는 글자 그대로이거나, 옮기지 않고 거절한다."""

    def check(self, old):
        new = W.migrated_text(old, lambda n: None)
        self.assertEqual(new, old.replace(OLD_SCOPE, NEW_SCOPE))
        self.assertNotEqual(new, old)
        self.assertEqual(W.migrated_text(new, lambda n: None), new)

    def test_prose_line_under_epics_section(self):
        self.check(road("에픽 절 머리 설명 한 줄.\n\n", blk()))

    def test_prose_line_inside_block(self):
        self.check(road(blk(extra="블록 안의 설명 줄 「말」\n")))

    def test_sub_item_intent_stays(self):
        self.check(road(blk(intent="- 의도:\n  - 하나\n  - 둘\n")))

    def test_flow_none_stays(self):
        self.check(road(blk(extra="- 흐름: 없음\n")))

    def test_two_do_items_stay_separate(self):
        two = "- 범위:\n  - 한다: a\n  - 한다: b\n  - 안 한다: c\n"
        old = road(blk(scope=two, head="### A0 — 영\n"), blk())
        new = W.migrated_text(old, lambda n: None)
        self.assertEqual(new, old.replace(OLD_SCOPE, NEW_SCOPE))
        self.assertIn(two, new)

    def test_already_new_is_no_change(self):
        old = road(blk(scope=NEW_SCOPE))
        self.assertEqual(W.migrated_text(old, lambda n: None), old)

    def test_unconvertible_scope_is_refused(self):
        for scope in ("- 범위: n\n", "- 범위: 한다 a / 안 한다 b / 안 한다 c\n"):
            with self.assertRaises(W.Refused):
                W.migrated_text(road(blk(scope=scope)), lambda n: None)



# 사용자 말이 아닌 「…」 — 원문 칸에 두지 않는다(설계 §6). 옛 줄에서 이 인용을 뺀 나머지가 사용자 말이다.
NOT_USER_WORDS = {
    "「에픽」": "단위 이름으로 고른 용어 표시",
    "「하나」": "바꾸기 전 문구를 가리키는 용어 표시",
    "「R7 착수 중 수정 — 몰아 받기」": "다른 이력 줄의 이름표",
    "「병렬 구현 중 수정 — 통합 리뷰」": "다른 이력 줄의 이름표",
    "「병렬 머지 중 수정 — 지휘 절차 8 · 9」": "다른 이력 줄의 이름표",
    "「병렬 머지 중 수정 — 하위 동작 동일」": "다른 이력 줄의 이름표",
    "「감사 뒤 수정」": "다른 이력 줄의 이름표",
    "「새 세션 작업 목록 재충전은 지휘 절차가 맡는다」": "R6 설계 판정(사용자 말 아님)",
}

# (항목 키, 바뀜 항목 번호) → 그 항목 끝에 붙은 승인 인용의 원문 칸 번호(1부터). 키는 `날짜 · 사유`(같은 키가 또 나오면 ` #n`).
# 여기 없는 바뀜 항목은 사용자 말을 담지 않는다.
APPROVALS = {
    ('2026-10-11 · 처음 로드맵', 0): (1,),
    ('2026-10-11 · 승인 뒤 수정(R0 설계 B11~B13)', 0): (1,),
    ('2026-10-11 · 승인 뒤 수정(R0 설계 B11~B13)', 1): (2,),
    ('2026-10-11 · 승인 뒤 수정(R0 설계 B11~B13)', 2): (3,),
    ('2026-10-13 · P3 결정 뒤 수정', 0): (1,),
    ('2026-10-15 · R7 착수 중 수정', 0): (1, 2, 3, 4, 5, 6, 7),
    ('2026-10-15 · R7 착수 중 수정', 1): (8,),
    ('2026-10-15 · R3 설계 중 수정', 0): (1, 2),
    ('2026-10-15 · 병렬 구현 중 수정', 0): (1, 2),
    ('2026-10-16 · 병렬 머지 중 수정', 0): (1,),
    ('2026-10-17 · 병렬 머지 중 수정', 0): (1,),
    ('2026-10-17 · 병렬 머지 중 수정', 2): (2,),
    ('2026-10-17 · 감사 뒤 수정', 0): (1,),
    ('2026-10-17 · 감사 뒤 수정 #2', 0): (1,),
    ('2026-10-17 · 지휘 점검 중 수정', 1): (1, 2, 3, 4, 5, 6),
    ('2026-10-17 · 압축 감사 뒤 수정', 0): (1, 2, 3, 4, 5, 6, 7, 8),
    ('2026-10-17 · 재분해', 1): (1,),
    ('2026-10-17 · 흐름 고정 점검 뒤 수정', 5): (1, 2, 3),
    ('2026-10-17 · 재분해 #2', 0): (1, 2),
    ('2026-10-17 · 재분해 #2', 1): (3,),
    ('2026-10-17 · 재분해 #2', 2): (4,),
    ('2026-10-17 · 재분해 #2', 3): (5,),
    ('2026-10-17 · 재분해 #2', 8): (6,),
}


class LiveRoadmap(unittest.TestCase):
    """이 로드맵은 옮겨졌다 — 옛 꼴 블록 · 옛 꼴 이력이 없고, 옮기기 전 인용을 하나도 잃지 않았다."""

    def setUp(self):
        self.text = (REPO / RM).read_text(encoding="utf-8")

    def test_no_quote_lost_since_before_migration(self):
        lost = set(quotes(git_show(PRE + ":" + RM))) - set(quotes(self.text))
        self.assertEqual(lost, set())

    def test_each_history_entry_keeps_its_original_quotes_in_order(self):
        """옛 한 줄마다 그 줄의 「…」 들이 순서대로 같은 새 항목 안(바뀜 · 원문)에 있다 — 합쳐 세는 집합 대조가 못 보는 손실."""
        old = git_show(PRE + ":" + RM)
        old_body = old.split("## 재분해 이력\n", 1)[1].split("\n## ", 1)[0]
        old_lines = [l for l in old_body.splitlines() if l.startswith("- 20")]
        new_body = self.text.split("## 재분해 이력\n", 1)[1].split("\n## ", 1)[0]
        entries = ["### " + e for e in new_body.split("\n### ")[1:]]
        self.assertGreaterEqual(len(entries), len(old_lines))
        for line, entry in zip(old_lines, entries):
            seq = quotes(entry)
            at = 0
            for q in quotes(line):
                try:
                    at = seq.index(q, at) + 1
                except ValueError:
                    self.fail("%s: 옛 인용이 순서대로 있지 않다: %s" % (entry.splitlines()[0], q))

    def test_user_words_column_holds_only_quotes_or_none(self):
        entries, errors = parse_history(self.text)
        self.assertEqual(errors, [])
        for e in entries:
            self.assertTrue(bool(e["quotes"]) != bool(e["no_words"]), e["date"])

    def _entries(self, added=False):
        """(키, 새 항목, 그 항목의 옛 줄 인용들) — 옛 줄과 새 항목은 날짜 순서로 짝지어진다.

        added=True 면 PRE 뒤에 더해진 항목(옛 줄이 없다)을 (키, 항목, None) 으로 낸다. 기본은 옛 줄이 있는 항목만."""
        old_entries, _ = parse_history(git_show(PRE + ":" + RM))
        new_entries, errors = parse_history(self.text)
        self.assertEqual(errors, [])
        self.assertGreaterEqual(len(new_entries), len(old_entries))
        self.assertEqual([e["date"] for e in old_entries], [e["date"] for e in new_entries[:len(old_entries)]])
        seen, out, extra = {}, [], []
        for i, n in enumerate(new_entries):
            k = "%s · %s" % (n["date"], n["reason"])
            seen[k] = seen.get(k, 0) + 1
            key = k if seen[k] == 1 else "%s #%d" % (k, seen[k])
            if i < len(old_entries):
                out.append((key, n, old_entries[i]["quotes"]))
            else:
                extra.append((key, n, None))
        return extra if added else out

    def test_entries_added_after_pre_are_checked_by_their_own_rule(self):
        """PRE 뒤에 더해진 항목은 옛 줄이 없다 — 원문은 자기 바뀜 항목 끝 승인 인용의 부분집합이고 사용자 말이 아닌 인용이 없다."""
        added = self._entries(added=True)
        self.assertTrue(added, "PRE 뒤에 더해진 이력 항목이 없다 — 이 검사가 비어 있다")
        for key, e, _none in added:
            self.assertTrue(e["changes"], key)
            approved = [q for c in e["changes"] for q in quotes(c) if q not in NOT_USER_WORDS]
            self.assertEqual(e["quotes"], approved, "%s: 원문 칸과 바뀜 줄의 사용자 인용이 같지 않다" % key)
            self.assertTrue(bool(e["quotes"]) != bool(e["no_words"]), key)
            self.assertEqual([q for q in e["quotes"] if q in NOT_USER_WORDS], [], key)
            if e["no_words"]:
                continue
            for c in e["changes"]:
                self.assertTrue(c.endswith("」"), "%s: 바뀜 항목이 승인 인용으로 끝나지 않는다: %s" % (key, c))

    def test_user_words_column_is_exactly_the_original_user_quotes(self):
        for key, e, orig in self._entries():
            want = [q for q in orig if q not in NOT_USER_WORDS]
            self.assertEqual(e["quotes"], want, key)
            if not want:
                self.assertTrue(e["no_words"], key)

    def test_no_foreign_quote_in_an_entry(self):
        for key, e, orig in self._entries():
            body = "\n".join(e["changes"] + e["quotes"])
            self.assertLessEqual(set(quotes(body)), set(orig), key)

    def test_changes_carry_the_user_quotes_in_the_same_order(self):
        for key, e, _orig in self._entries():
            got = [q for c in e["changes"] for q in quotes(c) if q not in NOT_USER_WORDS]
            self.assertEqual(got, e["quotes"], key)

    def test_each_approval_sits_on_its_own_change(self):
        """손으로 핀한 APPROVALS 는 PRE 에 있던 항목만 — 뒤에 더해진 항목은 위 검사가 자기 규칙으로 잰다."""
        pinned = self._entries()
        self.assertTrue(pinned, "PRE 의 이력 항목이 없다 — 이 검사가 비어 있다")
        for key, e, _orig in pinned:
            for i, c in enumerate(e["changes"]):
                at = tuple(e["quotes"].index(q) + 1 for q in quotes(c) if q not in NOT_USER_WORDS)
                self.assertEqual(at, APPROVALS.get((key, i), ()), "%s 바뀜 %d" % (key, i))

    def test_history_is_new_form(self):
        entries, errors = parse_history(self.text)
        self.assertEqual(errors, [])
        self.assertEqual([e["date"] for e in entries if e["form"] == "old"], [])

    def test_scopes_are_sub_items(self):
        _m, blocks, _r, _k, errors = parse_roadmap(self.text)
        self.assertEqual(errors, [])
        one_line = [b["id"] for b in blocks if isinstance(b["fields"].get("범위"), str)
                    and R.SCOPE_RE.fullmatch(b["fields"]["범위"])]
        self.assertEqual(one_line, [])


if __name__ == "__main__":
    unittest.main()
