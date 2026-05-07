import unittest
import audit_claude_md as audit


class TestScaffold(unittest.TestCase):
    def test_constants_resolve(self):
        self.assertTrue(audit.CLAUDE_MD.exists(), f"{audit.CLAUDE_MD} missing")
        self.assertTrue(audit.PHILOSOPHY.exists(), f"{audit.PHILOSOPHY} missing")


class TestAnchorPass(unittest.TestCase):
    def test_real_claude_md_has_no_broken_links(self):
        findings = audit.run_anchor_pass(audit.CLAUDE_MD.read_text())
        broken = [f for f in findings if f.kind == "BROKEN_LINK"]
        self.assertEqual(broken, [], f"unexpected broken links: {broken}")


class TestLevenshtein(unittest.TestCase):
    def test_identical(self):
        self.assertEqual(audit._levenshtein("abc", "abc"), 0)

    def test_one_substitution(self):
        self.assertEqual(audit._levenshtein("abc", "abd"), 1)

    def test_two_edits(self):
        self.assertEqual(audit._levenshtein("kitten", "sittin"), 2)

    def test_empty(self):
        self.assertEqual(audit._levenshtein("abc", ""), 3)


class TestSlugify(unittest.TestCase):
    def test_lowercase_and_hyphenate(self):
        self.assertEqual(audit.slugify("The Three Laws"), "the-three-laws")

    def test_strips_punctuation(self):
        # GitHub은 em-dash를 drop. 공백은 hyphen으로.
        # 실제 slugify 출력: em-dash 제거 후 인접 공백이 단일 hyphen으로 병합됨.
        self.assertEqual(
            audit.slugify("Law 1 — Clarity Before Code"),
            "law-1-clarity-before-code",
        )


class TestExtractLinks(unittest.TestCase):
    def test_extracts_relative_link(self):
        text = "see [the doc](docs/foo.md) for details"
        self.assertEqual(
            audit.extract_links(text),
            [("the doc", "docs/foo.md", None, 1)],
        )

    def test_extracts_link_with_anchor(self):
        text = "see [§2](docs/foo.md#section-two)"
        self.assertEqual(
            audit.extract_links(text),
            [("§2", "docs/foo.md", "section-two", 1)],
        )

    def test_skips_http_urls(self):
        self.assertEqual(audit.extract_links("see [link](https://example.com)"), [])


class TestCitationPass(unittest.TestCase):
    def test_real_claude_md_citations_resolve(self):
        findings = audit.run_citation_pass(
            audit.CLAUDE_MD.read_text(),
            audit.PHILOSOPHY.read_text(),
        )
        unresolved = [f for f in findings if f.kind == "UNRESOLVED_CITATION"]
        self.assertEqual(unresolved, [], f"unexpected unresolved: {unresolved}")


class TestCollectTokenAnchors(unittest.TestCase):
    def test_real_philosophy_has_known_tokens(self):
        anchors = audit.collect_token_anchors(audit.PHILOSOPHY.read_text())
        for tok in ["Law 1", "Law 2", "Law 3", "P1", "P12", "P21", "P23", "P24",
                    "§2", "§2.1", "§4", "§5.3", "§11.1"]:
            self.assertIn(tok, anchors, f"missing: {tok}")


class TestExtractTokens(unittest.TestCase):
    def test_extracts_all_token_kinds(self):
        text = "see Law 1 and P12 and AP3 and §2.1 and §4"
        toks = {t for t, _ in audit.extract_tokens(text)}
        self.assertEqual(toks, {"Law 1", "P12", "AP3", "§2.1", "§4"})


class TestCountPass(unittest.TestCase):
    def test_finds_known_drift(self):
        # Synthetic fixtures so this test is independent of whether the live tree is pre- or post-fix.
        stale_claude = "출처·23개 원칙·17개 anti-pattern·10 primitive·6 tension\n"
        synthetic_phil = (
            "\n".join(f"### P{i}. Title" for i in range(1, 25))     # 24 principles
            + "\n"
            + "\n".join(f"### AP{i}. Title" for i in range(1, 15))  # 14 anti-patterns
            + "\n"
            + "\n".join(f"### 4.{i} Title" for i in range(0, 11))   # 11 primitives (4.0..4.10)
            + "\n"
            + "\n".join(f"### 5.{i} Title" for i in range(1, 7))    # 6 tensions
            + "\n"
        )
        findings = audit.run_count_pass(stale_claude, synthetic_phil)
        kinds = [f.detail.split(":")[0] for f in findings if f.kind == "COUNT_DRIFT"]
        self.assertIn("principles", kinds)
        self.assertIn("anti_patterns", kinds)
        self.assertIn("primitives", kinds)
        # tensions is NOT expected — claimed=6 matches actual=6
        self.assertNotIn("tensions", kinds)


class TestCountActual(unittest.TestCase):
    def test_principles(self):
        self.assertEqual(
            audit.count_actual("principles", audit.PHILOSOPHY.read_text()), 24,
        )

    def test_anti_patterns(self):
        self.assertEqual(
            audit.count_actual("anti_patterns", audit.PHILOSOPHY.read_text()), 14,
        )

    def test_primitives(self):
        # §4.0 .. §4.10 → 11
        self.assertEqual(
            audit.count_actual("primitives", audit.PHILOSOPHY.read_text()), 11,
        )

    def test_tensions(self):
        # §5.1 .. §5.6 → 6
        self.assertEqual(
            audit.count_actual("tensions", audit.PHILOSOPHY.read_text()), 6,
        )


class TestSentinelPass(unittest.TestCase):
    def test_real_philosophy_has_all_four_sources(self):
        findings = audit.run_sentinel_pass(
            audit.CLAUDE_MD.read_text(),
            audit.PHILOSOPHY.read_text(),
        )
        self.assertEqual(findings, [], f"unexpected: {findings}")


class TestApplyFixes(unittest.TestCase):
    def test_count_drift_fix(self):
        original = "this doc has 23 원칙 cataloged\n"
        # 23 starts at offset 13 in "this doc has 23 원칙 cataloged"
        f = audit.Finding(
            "COUNT_DRIFT", "CLAUDE.md", 1,
            "principles: claimed=23 actual=24",
            auto_fix=(13, 15, "24"),
        )
        self.assertEqual(
            audit.apply_auto_fixes(original, [f]),
            "this doc has 24 원칙 cataloged\n",
        )

    def test_skips_findings_without_auto_fix(self):
        original = "P25 is cited\n"
        f = audit.Finding("UNRESOLVED_CITATION", "CLAUDE.md", 1, "P25", auto_fix=None)
        self.assertEqual(audit.apply_auto_fixes(original, [f]), original)

    def test_multiple_findings_same_line_compose_correctly(self):
        # Both 23 and 17 on the same line, both must be patched
        original = "23개 원칙·17개 anti-pattern\n"
        # "23" at 0..2, "17" at "23개 원칙·".length: let's compute via index
        idx_17 = original.index("17")
        f1 = audit.Finding("COUNT_DRIFT", "CLAUDE.md", 1, "principles", auto_fix=(0, 2, "24"))
        f2 = audit.Finding("COUNT_DRIFT", "CLAUDE.md", 1, "anti_patterns", auto_fix=(idx_17, idx_17 + 2, "14"))
        # Apply both
        result = audit.apply_auto_fixes(original, [f1, f2])
        self.assertIn("24개 원칙", result)
        self.assertIn("14개 anti-pattern", result)


class TestRenderReport(unittest.TestCase):
    def test_empty_findings(self):
        report = audit.render_report([])
        self.assertIn("(no findings)", report)
        for kind in ["BROKEN_LINK", "BROKEN_ANCHOR", "UNRESOLVED_CITATION",
                     "COUNT_DRIFT", "MISSING_SOURCE_SENTINEL"]:
            self.assertIn(kind, report)

    def test_count_drift_listed(self):
        f = audit.Finding(
            "COUNT_DRIFT", "CLAUDE.md", 5,
            "principles: claimed=23 actual=24",
            auto_fix=(0, 2, "24"),
        )
        report = audit.render_report([f])
        self.assertIn("**Auto-fixed**", report)
        self.assertIn("CLAUDE.md:5", report)


class TestRenderReportNewSections(unittest.TestCase):
    def test_auto_fix_diff_present_when_changes(self):
        original = "old line\n"
        fixed = "new line\n"
        report = audit.render_report([], original, fixed)
        self.assertIn("```diff", report)
        self.assertIn("-old line", report)
        self.assertIn("+new line", report)

    def test_no_diff_when_unchanged(self):
        report = audit.render_report([], "same\n", "same\n")
        self.assertIn("(no auto-fixes applied)", report)

    def test_manual_actions_for_unresolved_citation(self):
        f = audit.Finding("UNRESOLVED_CITATION", "CLAUDE.md", 10, "P99", auto_fix=None)
        report = audit.render_report([f])
        self.assertIn("Recommended manual actions", report)
        self.assertIn("`P99` does not resolve", report)


if __name__ == "__main__":
    unittest.main()
