#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_model.py — 하위 항목 · 새 선택 칸 · 여러 브랜치 · 재분해 이력(R5 AC1 · AC2 · AC3 · AC5).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py
"""
from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import roadmap_model as M  # noqa: E402

PRE = "93be1042"   # 이 계획 전 — 옛 해석기와 옛 로드맵
RM = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"

HEAD = "---\ntype: roadmap\nsource_brief: b.md\n---\n\n# r\n\n## 에픽\n\n"
TAIL = "## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n"


def block(extra=""):
    return ("### A1 — 가\n- 의도: 의도\n- 범위: 한다 x / 안 한다 y\n- 의존: 없음\n- 브랜치: feature/a\n"
            "- 묶음: A1.md\n- 경로 예약: 없음\n" + extra + "\n")


def git_show(rev_path: str) -> str:
    proc = subprocess.run(["git", "-C", str(REPO), "show", rev_path], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise AssertionError("git show %s 실패 — 기준 커밋이 없는 클론이다: %s"
                             % (rev_path, proc.stderr.decode("utf-8", "replace")))
    return proc.stdout.decode("utf-8")


def old_model():
    """93be1042 의 roadmap_model 을 임시 폴더에 불러온다(section6 은 지금 것 — 해석에 쓰지 않는다)."""
    tmp = Path(tempfile.mkdtemp())
    (tmp / "roadmap_model.py").write_text(git_show(PRE + ":plugins/spec-distill/scripts/roadmap_model.py"),
                                          encoding="utf-8")
    shutil.copy(str(SCRIPTS / "section6.py"), str(tmp / "section6.py"))
    spec = importlib.util.spec_from_file_location("old_roadmap_model", str(tmp / "roadmap_model.py"))
    mod = importlib.util.module_from_spec(spec)
    saved = sys.modules.get("section6")
    sys.path.insert(0, str(tmp))
    try:
        sys.modules.pop("section6", None)
        spec.loader.exec_module(mod)
    finally:
        sys.path.remove(str(tmp))
        if saved is not None:
            sys.modules["section6"] = saved
    shutil.rmtree(str(tmp))
    return mod


def comparable(parsed):
    meta, blocks, records, risks, errors = parsed
    blocks = [{k: v for k, v in b.items() if k != "branches"} for b in blocks]
    return meta, blocks, records, risks, errors


class OldRoadmapsUnchanged(unittest.TestCase):
    """AC1 — 하위 항목이 없는 옛 로드맵은 바뀌기 전과 같은 블록 · 칸 값 · 오류를 낸다."""

    @classmethod
    def setUpClass(cls):
        cls.old = old_model()

    def same(self, text):
        self.assertEqual(comparable(M.parse_roadmap(text)), comparable(self.old.parse_roadmap(text)))

    def test_this_repo_roadmap_before_migration(self):
        self.same(git_show(PRE + ":" + RM))

    def test_small_roadmaps_including_errors(self):
        self.same(HEAD + block() + TAIL)
        self.same(HEAD + block("- 모름: x\n") + TAIL)
        self.same(HEAD + block("- 의도: 두 번\n") + TAIL)
        self.same(HEAD + block("  들여쓴 다른 줄\n") + TAIL)
        self.same(HEAD + "### 이상한 머리\n" + block() + TAIL)


class SubItems(unittest.TestCase):
    def parse(self, body):
        return M.parse_roadmap(HEAD + body + TAIL)

    def test_sub_items_become_the_field_list(self):
        body = block().replace("- 범위: 한다 x / 안 한다 y\n",
                               "- 범위:\n  - 한다: 가 · 나(근거 2026-10-17)\n  - 안 한다: 다\n")
        _m, blocks, _r, _k, errors = self.parse(body)
        self.assertEqual(errors, [])
        self.assertEqual(blocks[0]["fields"]["범위"], ["한다: 가 · 나(근거 2026-10-17)", "안 한다: 다"])

    def test_sub_item_under_one_line_field_is_an_error(self):
        _m, _b, _r, _k, errors = self.parse(block("  - 떠도는 항목\n"))
        self.assertTrue(any("하위 항목" in e for e in errors), errors)

    def test_one_line_field_cannot_take_sub_items(self):
        body = block().replace("- 묶음: A1.md\n", "- 묶음:\n  - A1.md\n")
        _m, _b, _r, _k, errors = self.parse(body)
        self.assertTrue(any("묶음 칸은 한 줄" in e for e in errors), errors)

    def test_empty_list_field_is_an_error(self):
        body = block().replace("- 의도: 의도\n", "- 의도:\n")
        _m, _b, _r, _k, errors = self.parse(body)
        self.assertTrue(any("의도 칸에 값도 하위 항목도 없다" in e for e in errors), errors)

    def test_new_optional_fields_and_unknown_field(self):
        extra = "".join("- %s: 값\n" % k for k in M.EXTRA_FIELDS)
        _m, blocks, _r, _k, errors = self.parse(block(extra))
        self.assertEqual(errors, [])
        self.assertEqual(blocks[0]["fields"]["산출물"], "값")
        _m, _b, _r, _k, errors = self.parse(block("- 모름: x\n"))
        self.assertTrue(any("모르는 머리말 줄" in e for e in errors), errors)

    def test_branches_one_line_and_sub_items(self):
        body = block().replace("- 브랜치: feature/a\n", "- 브랜치: feature/a · `feature/b`\n")
        _m, blocks, _r, _k, errors = self.parse(body)
        self.assertEqual(errors, [])
        self.assertEqual(blocks[0]["branches"], ["feature/a", "feature/b"])
        body = block().replace("- 브랜치: feature/a\n", "- 브랜치:\n  - feature/a\n  - feature/c\n")
        _m, blocks, _r, _k, errors = self.parse(body)
        self.assertEqual(blocks[0]["branches"], ["feature/a", "feature/c"])

    def test_duplicate_branch_is_an_error(self):
        body = block().replace("- 브랜치: feature/a\n", "- 브랜치: feature/a · feature/a\n")
        _m, _b, _r, _k, errors = self.parse(body)
        self.assertTrue(any("브랜치가 두 번" in e for e in errors), errors)

    def test_list_values_for_deps_and_reserved(self):
        body = block().replace("- 경로 예약: 없음\n", "- 경로 예약:\n  - `src/a.py`\n  - docs/x/\n")
        _m, blocks, _r, _k, errors = self.parse(body)
        self.assertEqual(errors, [])
        self.assertEqual(blocks[0]["reserved"], ["src/a.py", "docs/x/"])


class Quotes(unittest.TestCase):
    def test_nested_quote_counts_once(self):
        text = "앞 「에픽 실행 방식, 「끝에 할 일 하나」, 해둬」 · 「둘」"
        self.assertEqual(M.quotes(text), ["「에픽 실행 방식, 「끝에 할 일 하나」, 해둬」", "「둘」"])
        self.assertTrue(M.is_quote("「가 「나」 다」"))
        self.assertFalse(M.is_quote("「가」 「나」"))
        self.assertEqual(M.strip_quotes("R5 「R6 말」 끝"), "R5   끝")


class History(unittest.TestCase):
    def hist(self, body):
        return M.parse_history("## 재분해 이력\n\n" + body + "\n## 위험 번호표\n")

    def test_new_form(self):
        entries, errors = self.hist("### 2026-10-17 · 재분해\n- 바뀜: 바뀜 R5 · 새 R11\n- 원문:\n"
                                    "  - 「이대로 다시 나눈다」\n  - 「가 「나」 다」\n")
        self.assertEqual(errors, [])
        self.assertEqual(entries, [{"date": "2026-10-17", "reason": "재분해", "changes": ["바뀜 R5 · 새 R11"],
                                    "quotes": ["「이대로 다시 나눈다」", "「가 「나」 다」"], "no_words": "",
                                    "form": "new"}])

    def test_no_user_words_form(self):
        entries, errors = self.hist("### 2026-10-15 · 판정\n- 바뀜:\n  - 가 「설계 판정」\n"
                                    "- 원문: 없음 — 사용자 말 없음(R6 설계 판정)\n")
        self.assertEqual(errors, [])
        self.assertEqual(entries[0]["quotes"], [])
        self.assertEqual(entries[0]["no_words"], "사용자 말 없음(R6 설계 판정)")
        for body, want in {"### 2026-10-15 · x\n- 원문: 없음 — \n": "원문이 없다",
                           "### 2026-10-15 · x\n- 원문: 없음\n": "하위 항목으로",
                           "### 2026-10-15 · x\n- 원문: 없음 — 사유\n- 원문:\n  - 「a」\n": "함께"}.items():
            _e, errs = self.hist(body)
            self.assertTrue(any(want in e for e in errs), (body, errs))

    def test_changes_as_sub_items(self):
        entries, errors = self.hist("### 2026-10-17 · 수정\n- 바뀜:\n  - 가\n  - 나\n- 원문:\n  - 「좋아」\n")
        self.assertEqual(errors, [])
        self.assertEqual(entries[0]["changes"], ["가", "나"])

    def test_old_one_line_form_still_reads(self):
        entries, errors = self.hist("- 2026-10-11 · 처음 로드맵 · 승인 원문 S47 「이대로 승인」\n- 없음\n")
        self.assertEqual(errors, [])
        self.assertEqual(entries[0]["form"], "old")
        self.assertEqual(entries[0]["quotes"], ["「이대로 승인」"])

    def test_new_form_errors(self):
        cases = {"### 날짜아님 · x\n- 원문:\n  - 「a」\n": "머리가",
                 "### 2026-10-17 · x\n- 바뀜: y\n": "원문이 없다",
                 "### 2026-10-17 · x\n- 원문:\n  - 인용 아님\n": "원문 줄은",
                 "### 2026-10-17 · x\n- 원문: 「한 줄」\n": "하위 항목으로",
                 "### 2026-10-17 · x\n- 원문:\n  - 「a」\n그냥 줄\n": "읽지 못한 줄"}
        for body, want in cases.items():
            _e, errors = self.hist(body)
            self.assertTrue(any(want in e for e in errors), (body, errors))

    def test_parse_roadmap_reports_history_errors(self):
        text = HEAD + block() + TAIL.replace("- 없음\n", "### 2026-10-17 · x\n- 바뀜: y\n")
        _m, _b, _r, _k, errors = M.parse_roadmap(text)
        self.assertTrue(any("원문이 없다" in e for e in errors), errors)


class BriefUniverseSection4(unittest.TestCase):
    """§4 의 «key» 는 항목(열 0 목록 머리 + 들여 쓴 이음 줄)에서만 센다 — 펜스 안 · 항목 밖 산문은 세지 않는다."""

    FX = REPO / "plugins" / "spec-distill" / "tests" / "fixtures"

    def universe(self, extra_section4):
        brief = (self.FX / "interview-brief-valid.md").read_text(encoding="utf-8")
        audit = (self.FX / "interview-brief-valid.audit.md").read_text(encoding="utf-8")
        marker = "- Next.js app-router SSR «nextjs-docs» — [취함] — 데이터 형태와 부합\n"
        self.assertIn(marker, brief)
        non_s, _s, _k = M.brief_universe(brief.replace(marker, marker + extra_section4), audit)
        return non_s

    def test_fence_and_prose_keys_not_counted(self):
        base = self.universe("")
        self.assertIn("«nextjs-docs»", base)
        extra = self.universe("\n산문 줄의 «prose-key»\n```\n- 펜스 안 «fence-key»\n```\n")
        self.assertEqual(extra, base)

    def test_item_and_continuation_keys_counted(self):
        extra = self.universe("- 둘째 항목 «second-key» — [피함] — 이유\n  이음 줄 «cont-key»\n")
        self.assertIn("«second-key»", extra)
        self.assertIn("«cont-key»", extra)

    def test_head_rc_counted(self):
        extra = self.universe("- 레포 주장 «repo-k» — [중립] — 이유 [RC7 → 없음]\n")
        self.assertIn("RC7", extra)

    def test_body_line_rc_not_counted(self):
        extra = self.universe("- 둘째 «body-k» — [중립] — 이유 [→ 없음]\n  본문 줄 RC8 (a/b.py)\n")
        self.assertNotIn("RC8", extra)

    def test_out_of_grammar_anchor_makes_universe_uncountable(self):
        brief = (self.FX / "interview-brief-valid.md").read_text(encoding="utf-8")
        audit = (self.FX / "interview-brief-valid.audit.md").read_text(encoding="utf-8")
        for bad in ("\n- **\uff332**", "\n\u00a0- **S2**", "\n- **S2**\u2028- **S3**"):
            with self.assertRaises(M.FormatError, msg=repr(bad)):
                M.brief_universe(brief.replace("\n- **S2**", bad, 1), audit)
            with self.assertRaises(M.FormatError, msg=repr(bad)):
                M.brief_universe(brief, audit.replace("\n- **S2**", bad, 1))


class BriefRiskNumbers(unittest.TestCase):
    """AC25 — 위험 번호는 줄에 박힌 것을 읽는다. 옛 brief 는 줄 순서 + 알림 표지."""

    def test_stamped_numbers_are_read(self):
        s5 = ("- 위험 K2 — 실패 양식: 둘 — 근거\n- 기각 — x → y\n"
              "- 위험 K1 — 숨은 가정 | 하나 — RC3 [RC3 → OQ1]\n- 위험 K5 — 리뷰 참고 | 다섯\n")
        rows, by_order = M.brief_risk_numbers(s5)
        self.assertEqual(rows, [("K1", "위험 — 숨은 가정 | 하나 — RC3 [RC3 → OQ1]"),
                                ("K2", "위험 — 실패 양식: 둘 — 근거"), ("K5", "위험 — 리뷰 참고 | 다섯")])
        self.assertFalse(by_order)

    def test_unstamped_keeps_old_order(self):
        s5 = "- 위험 — 실패 양식: 둘\n- 위험 — 숨은 가정: 하나\n"
        self.assertEqual(M.brief_risk_numbers(s5), ([("K1", "위험 — 숨은 가정: 하나"), ("K2", "위험 — 실패 양식: 둘")], True))

    def test_no_risk_lines_is_not_by_order(self):
        self.assertEqual(M.brief_risk_numbers("- 기각 — x → y\n"), ([], False))

    def test_mixed_is_an_error(self):
        with self.assertRaisesRegex(M.FormatError, "K3 부터 박는다"):
            M.brief_risk_numbers("- 위험 K2 — 숨은 가정: a\n- 위험 — 리뷰 참고 | b\n")

    def test_duplicate_is_an_error(self):
        with self.assertRaisesRegex(M.FormatError, "겹친다: K1"):
            M.brief_risk_numbers("- 위험 K1 — 숨은 가정: a\n- 위험 K1 — 실패 양식: b\n")

    def test_other_kinds_are_not_risks(self):
        self.assertEqual(M.brief_risk_numbers("- 위험 — 사실 | 사실 하나 — RC1 (a/b.py) [RC1 → OQ1]\n"), ([], False))


class RoadmapVerdict(unittest.TestCase):
    """로드맵 = 정해진 폴더 바로 아래 폴더 한 단계 안의 .md ∧ 머리말 type: roadmap (R8 AC6)."""
    DIR = "docs/superpowers/roadmaps/"
    TEXT = "---\ntype: roadmap\n---\n# r\n"

    def test_template_and_fixture_are_not_roadmaps(self):
        for path in ("plugins/spec-distill/templates/roadmap-template.md",
                     "plugins/spec-distill/tests/fixtures/conductor-e2e/roadmap.md"):
            verdict, why = M.roadmap_verdict(path, self.TEXT, self.DIR)
            self.assertEqual(verdict, "not_roadmap", path)
            self.assertIn("로드맵 폴더 밖", why)

    def test_two_levels_deep_is_not_roadmap(self):
        verdict, why = M.roadmap_verdict(self.DIR + "x/y/roadmap.md", self.TEXT, self.DIR)
        self.assertEqual(verdict, "not_roadmap")
        self.assertIn("한 단계", why)
        self.assertEqual(M.roadmap_verdict(self.DIR + "roadmap.md", self.TEXT, self.DIR)[0], "not_roadmap")
        self.assertEqual(M.roadmap_verdict(self.DIR + "x/roadmap.txt", self.TEXT, self.DIR)[0], "not_roadmap")

    def test_unreadable_frontmatter_is_counted(self):
        path = self.DIR + "x/roadmap.md"
        for text in (None, "---\ntype: roadmap\n# 닫히지 않음\n", "\ufeff---\ntype: roadmap\n---\n", "--- \ntype: roadmap\n---\n"):
            verdict, why = M.roadmap_verdict(path, text, self.DIR)
            self.assertEqual(verdict, "unreadable", repr(text))
            self.assertTrue(why)
        found, unchecked = M.find_roadmaps([path, self.DIR + "y/roadmap.md"],
                                           {path: None, self.DIR + "y/roadmap.md": self.TEXT}.get, self.DIR)
        self.assertEqual(found, [self.DIR + "y/roadmap.md"])
        self.assertEqual([p for p, _w in unchecked], [path])

    def test_other_type_in_folder(self):
        verdict, why = M.roadmap_verdict(self.DIR + "x/A1.md", "---\ntype: epic-bundle\n---\n", self.DIR)
        self.assertEqual(verdict, "not_roadmap")
        self.assertIn("epic-bundle", why)
        self.assertEqual(M.roadmap_verdict(self.DIR + "x/notes.md", "# 메모\n", self.DIR)[0], "not_roadmap")

    def test_any_md_name_in_folder_is_roadmap(self):
        self.assertEqual(M.roadmap_verdict(self.DIR + "x/plan.md", self.TEXT, self.DIR), ("roadmap", ""))
        quoted = "---\r\ntype: \"roadmap\"\r\n---\r\n"
        self.assertEqual(M.roadmap_verdict("plan/roadmaps/x/plan.md", quoted, "plan/roadmaps/")[0], "roadmap")

    def test_one_read_rule(self):
        """일반 파일(100644 · 100755)은 읽고, 링크 · 서브모듈 · LFS · UTF-8 아님은 사유가 있는 검사 불가, cat 실패는 따로 센다."""
        d = self.DIR
        out = b"".join(b"%s %s %s\t%s\0" % (m, k, s, p.encode("utf-8")) for m, k, s, p in (
            (b"100644", b"blob", b"a1", d + "a/roadmap.md"), (b"100755", b"blob", b"x1", d + "x/roadmap.md"),
            (b"120000", b"blob", b"l1", d + "l/roadmap.md"), (b"160000", b"commit", b"s1", d + "s/roadmap.md"),
            (b"100644", b"blob", b"f1", d + "f/roadmap.md"), (b"100644", b"blob", b"z1", d + "z/roadmap.md"),
            (b"100644", b"blob", b"u1", d + "u/roadmap.md"), (b"100644", b"blob", b"d1", d + "a/deep/r.md"),
            (b"100644", b"blob", b"o1", "docs/x.md")))
        entries = M.tree_entries(out, d)
        self.assertNotIn(d + "a/deep/r.md", entries)
        self.assertNotIn("docs/x.md", entries)
        blobs = {b"a1": self.TEXT.encode(), b"x1": self.TEXT.encode(), b"f1": None,
                 b"z1": b"version https://git-lfs.github.com/spec/v1\noid sha256:00\nsize 1\n", b"u1": b"\xff\xfe---\n"}
        cats = []

        def cat(sha):
            cats.append(sha)
            data = blobs[sha.encode()]
            return (128, b"") if data is None else (0, data)
        failed = set()
        found, unchecked = M.find_roadmaps(list(entries), M.blob_reader(entries, cat, failed), d)
        self.assertEqual(found, [d + "a/roadmap.md", d + "x/roadmap.md"])
        why = dict(unchecked)
        self.assertIn("파일을 읽지 못했다", why[d + "f/roadmap.md"])
        self.assertIn("일반 파일이 아니다", why[d + "l/roadmap.md"])
        self.assertIn("일반 파일이 아니다", why[d + "s/roadmap.md"])
        self.assertIn("LFS", why[d + "z/roadmap.md"])
        self.assertIn("UTF-8", why[d + "u/roadmap.md"])
        self.assertEqual(failed, {d + "f/roadmap.md"})
        self.assertNotIn("l1", cats)
        self.assertNotIn("s1", cats)

    def test_find_roadmaps_reads_only_shaped_paths(self):
        read_paths = []

        def read(path):
            read_paths.append(path)
            return self.TEXT
        paths = [self.DIR + "b/roadmap.md", "docs/x.md", self.DIR + "a/roadmap.md", self.DIR + "a/deep/r.md"]
        found, unchecked = M.find_roadmaps(paths, read, self.DIR)
        self.assertEqual((found, unchecked), ([self.DIR + "a/roadmap.md", self.DIR + "b/roadmap.md"], []))
        self.assertEqual(sorted(read_paths), [self.DIR + "a/roadmap.md", self.DIR + "b/roadmap.md"])


if __name__ == "__main__":
    unittest.main()
