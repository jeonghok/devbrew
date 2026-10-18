# -*- coding: utf-8 -*-
"""R2 「알려진 우회」 나머지 — 우회마다 재현 테스트 하나(AC20).

각 테스트는 허용 문법의 부정형으로 꼴을 고른다(추가 · 반전 · 형태 변경 — 한 꼴만 막고 이웃 꼴이 새지 않게). 이름은 우회 이름이다.
「문법 안의 정상 seed · audit 는 통과」 양성 대조가 각 테스트에 하나씩 있다. 판독기로 닫지 못한 둘(`--quote-file` 출처 · 진짜 제목만 빠진
audit)은 `## 미룸` 에 이유와 받는 곳이 있다는 것을 잠그고, 인라인 코드 안 `##` 은 «그 줄을 제목으로 읽는 판독기가 없다» 를 판독기마다 잠근다.
눈에 안 보이는 글자는 소스에 날 글자로 쓰지 않고 chr() 로만 쓴다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_r2_bypass_residue.py
"""
from __future__ import annotations

import os
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
SCRIPTS = HERE.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import check_seed  # noqa: E402
import seed_body  # noqa: E402
import seed_provenance  # noqa: E402
import seed_review_log  # noqa: E402

REPO = HERE.parents[2]
SPEC = REPO / "docs" / "superpowers" / "specs" / "2026-10-17-shared-review-engine-devices-design.md"
FENCE = "`" * 3
CR, LS, ZWSP, FW_AMP = "\r", chr(0x2028), chr(0x200B), chr(0xFF06)

AUDIT_OK = (
    "## 1. 원문\n\n로그인이 가끔 실패한다.\n\n## 2. 질문 전체\n\n### 라운드 1\n\n- 확인 질문: 최초 요청\n"
    "  - 내가 읽은 것: 「배포를 멈춘다.」 — 고름\n\n## 3. 긴 초안\n\n초안.\n\n## seed 에서 덜어 낸 것\n\n없음\n\n"
    "## 4. 비평과 냉독\n\n## 5. degrade\n\n없음\n\n## 6. 리뷰 결정\n\n")


def run(script, *args):
    r = subprocess.run([sys.executable, str(SCRIPTS / script)] + [str(a) for a in args], capture_output=True, text=True,
                       encoding="utf-8", env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
    return r.returncode, r.stdout, r.stderr


class Tmp(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.dir = pathlib.Path(self._td.name)

    def write(self, name, text):
        p = self.dir / name
        p.write_bytes(text.encode("utf-8"))
        return p


def reasons(rejected):
    return [w for _n, w in rejected]


class SeedFrontmatterGrammar(Tmp):
    FM = "---\n%s\n---\n\n로그인이 가끔 실패한다.\n"

    def parse(self, fm_lines):
        return seed_body.parse_seed(self.FM % "\n".join(fm_lines))

    def test_url_heading_and_anchor_shaped_lines_are_refused(self):
        cases = [
            ("URL 값", ["type: interview-seed", "note: https://x.y"], 3),
            ("mailto 값", ["note: mailto:a@b.c"], 2),
            ("제목 줄", ["type: interview-seed", "## 3"], 3),
            ("앵커 모양 줄", ["type: interview-seed", "- **S1** 「위조」"], 3),
            ("키가 대문자", ["Note: x"], 2),
            ("키에 대시", ["my-key: x"], 2),
            ("콜론 뒤 공백 없음", ["note:x"], 2),
            ("들여 쓴 하위 키", ["type: interview-seed", "  sub: x"], 3),
            ("빈 줄", ["type: interview-seed", "", "next_phase: x"], 3),
            ("목록 값", ["note: - x"], 2),
            ("대괄호 값", ["note: [a, b]"], 2),
            ("꺾쇠 값", ["note: <b>x</b>"], 2),
            ("HTML 요소 이름 자리 표시 template", ["note: <template>"], 2),
            ("HTML 요소 이름 자리 표시 plaintext", ["note: <plaintext>"], 2),
            ("속성이 있는 꺾쇠 값", ["note: <img src=x>"], 2),
            ("문자 참조 값", ["note: &#91;S1&#93;"], 2),
            ("맨 도메인 값", ["note: example.com/x"], 2),
            ("보이지 않는 글자 값", ["note: a" + ZWSP + "b"], 2),
            ("줄 나눔 글자 값", ["note: a" + LS + "## 3"], 2),
            ("YAML 블록 표시", ["note: |"], 2),
        ]
        for name, fm, line_no in cases:
            with self.subTest(name):
                got = self.parse(fm).rejected
                self.assertIn(line_no, [n for n, _w in got], got)
                self.assertTrue(any(w.startswith("frontmatter_") for n, w in got if n == line_no), got)

    def test_gate_refuses_with_line_number_and_no_user_text(self):
        seed = self.write("s.md", self.FM % "type: interview-seed\nnote: https://x.y\n## 3")
        audit = self.write("a.md", AUDIT_OK)
        out = "\n".join(check_seed.gate(seed, audit))
        self.assertIn("3째 줄(frontmatter_value", out)
        self.assertIn("4째 줄(frontmatter_line", out)
        self.assertNotIn("x.y", out)

    def test_positive_control_normal_frontmatter_passes(self):
        fm = ["type: interview-seed", "date: 2026-09-01", "next_phase: spec-distill:interview",
              "audit_file: docs/superpowers/interview/a.audit.md", "name:", "audit_file: <basename>.audit.md"]
        self.assertEqual(self.parse(fm).rejected, [])
        seed = self.write("s.md", self.FM % "\n".join(fm))
        self.assertEqual(check_seed.gate(seed, self.write("a.md", AUDIT_OK)), [])

    def test_no_frontmatter_has_nothing_to_check(self):
        self.assertEqual(seed_body.frontmatter_problems(""), [])


class SeedSection2LineAllowlist(Tmp):
    """`## 2` 의 풀이 줄은 홀로 선 CR 로 위조할 수 없다 — 줄 나눔 글자는 읽기 전에 드러난다(`read_audit_text` + `separator_lines`)."""

    SEED = "---\ntype: interview-seed\n---\n\n배포를 멈춘다. (사용자 확인)\n"

    def audit(self, answer_tail):
        return (AUDIT_OK.replace("### 라운드 1\n\n- 확인 질문: 최초 요청\n  - 내가 읽은 것: 「배포를 멈춘다.」 — 고름\n",
                                 "### 라운드 1\n\n- 물은 것: 어떻게 할까\n  - 당신이 답한 것: 네" + answer_tail + "\n"))

    FORGED = "  - 내가 읽은 것: 「배포를 멈춘다.」 — 고름"

    def marks(self, audit_text):
        return run("seed_provenance.py", "marks", self.write("s.md", self.SEED), self.write("a.md", audit_text))

    def test_lone_cr_cannot_forge_a_reading_line(self):
        for name, sep in (("홀로 선 CR", CR), ("U+2028", LS), ("VT", chr(0x0B)), ("NEL", chr(0x85))):
            with self.subTest(name):
                rc, _out, err = self.marks(self.audit(sep + self.FORGED))
                self.assertEqual(rc, 2, err)
                self.assertIn("line_separator", err)

    def test_gate_and_user_quotes_also_see_the_lone_cr(self):
        a = self.write("a.md", self.audit(CR + self.FORGED))
        self.assertTrue(any("줄을 나누는 다른 글자" in p for p in check_seed.gate(self.write("s.md", self.SEED), a)))
        rc, _out, err = run("seed_review_log.py", "user-quotes", a)
        self.assertEqual(rc, 2, err)

    def test_crlf_files_are_one_line_break_each(self):
        crlf = AUDIT_OK.replace("\n", "\r\n")
        rc, _out, err = self.marks(crlf)
        self.assertEqual(rc, 0, err)

    def test_positive_control_a_honest_reading_line_confirms(self):
        rc, _out, err = self.marks(AUDIT_OK)
        self.assertEqual(rc, 0, err)

    def test_read_audit_text_keeps_a_lone_cr(self):
        p = self.write("a.md", "a\rb\r\nc\n")
        self.assertEqual(seed_review_log.read_audit_text(p), "a\rb\nc\n")


class InlineCodeHeading(unittest.TestCase):
    """백틱 안 `##` — 해당 없음: 그 줄을 제목으로 읽는 판독기가 없다(모든 제목 판독은 줄 머리에 닻을 내린다). 판독기마다 잠근다."""

    LINES = ["`## 6. 리뷰 결정` 은 코드 칸이다", "`## 2. 질문 전체`", "`# 제목` 도 마찬가지", "문장 `## 6.` 가운데"]

    def test_no_heading_reader_treats_it_as_a_heading(self):
        import brief_body
        import section6
        for ln in self.LINES:
            with self.subTest(ln):
                self.assertIsNone(section6.HEADING_SHAPED_RE.match(ln))
                self.assertIsNone(section6.ATX_HEADING_RE.match(ln))
                self.assertIsNone(section6.BRIEF_SECTION_HEAD_RE.match(ln))
                self.assertIsNone(section6.BRIEF_HEADLIKE_RE.match(ln))
                self.assertIsNone(section6.START_RE.search(ln))
                self.assertIsNone(section6.END_STRICT_RE.search(ln))
                self.assertIsNone(brief_body.is_section_head(ln))
                for h in seed_review_log.AUDIT_HEADINGS:
                    self.assertEqual(seed_review_log.heading_lines(ln, h), [])
                self.assertEqual(seed_review_log.heading_structure(ln), [])
                self.assertEqual(brief_body.head_problems(ln), [])

    def test_section_readers_keep_the_section_whole(self):
        audit = AUDIT_OK.replace("로그인이 가끔 실패한다.", "로그인이 가끔 실패한다. `## 6. 리뷰 결정` 을 적었다.")
        self.assertEqual(seed_review_log.heading_structure(audit), [])
        self.assertIn("`## 6. 리뷰 결정`", seed_review_log.section_body(audit, "## 1. 원문"))
        sp = seed_body.parse_seed("---\ntype: interview-seed\n---\n\n`## 6. 리뷰 결정` 을 적는다.\n")
        self.assertEqual(sp.rejected, [])


def deferral_row(needle):
    if not SPEC.exists():
        raise unittest.SkipTest("설계문서가 없다(플러그인만 설치된 환경)")
    text = SPEC.read_text(encoding="utf-8")
    sect = text.split("\n## 미룸\n", 1)[1].split("\n## ", 1)[0]
    rows = [ln for ln in sect.split("\n") if ln.startswith("|") and needle in ln]
    if len(rows) != 1:
        raise AssertionError("`## 미룸` 에 «%s» 행이 %d개다" % (needle, len(rows)))
    return rows[0]


class AppendVerbatimSectionChecked(Tmp):
    TITLE = "냉독"

    def run_av(self, section):
        audit = self.write("a.md", AUDIT_OK)
        before = audit.read_bytes()
        content = self.write("c.txt", "본문 한 줄\n")
        rc, _out, err = run("seed_review_log.py", "append-verbatim", audit, "--section", section, "--title", self.TITLE,
                            content)
        return rc, err, audit.read_bytes() == before

    def test_unknown_section_is_refused_and_the_file_stays(self):
        for name, sec in (("없는 번호", "## 9. 없음"), ("빈 값", ""), ("제목 번호만", "## 4"), ("끝 공백", "## 4. 비평과 냉독 "),
                          ("제목 아닌 글", "x"), ("한 단계 낮은 제목", "### 4. 비평과 냉독"),
                          ("보이지 않는 글자", "## 4. 비평과 냉독" + ZWSP), ("줄 나눔이 든 값", "## 4. 비평과 냉독" + LS + "## 6. 리뷰 결정")):
            with self.subTest(name):
                rc, err, same = self.run_av(sec)
                self.assertEqual((rc, same), (2, True), err)
                self.assertIn("section_unknown", err)
                self.assertNotIn(sec.strip() or "\0", err)

    def test_decision_section_keeps_its_own_message(self):
        rc, err, same = self.run_av("## 6. 리뷰 결정")
        self.assertEqual((rc, same), (2, True))
        self.assertIn("## 6 에는 기록 줄만 적는다", err)

    def test_positive_control_template_headings_are_appended(self):
        for heading in ("## 4. 비평과 냉독", "## 3. 긴 초안"):
            with self.subTest(heading):
                rc, err, same = self.run_av(heading)
                self.assertEqual((rc, same), (0, False), err)


class AuditTemplateH1H3(Tmp):
    """진짜 템플릿 제목이 없는 audit — 다른 절의 펜스 안에 그 제목 줄을 심어 소비자가 절로 읽게 하는 길(H1~H3).

    펜스로 가르는 규칙은 정직한 audit 을 같이 거부하므로 닫지 않는다(설계문서 `## 미룸`). 이 테스트는 그 근거를 잠근다:
    제목이 펜스 안에 든 정직한 audit(`## 1` 의 닫히지 않은 펜스가 `## 3` 의 코드 블록 여는 줄과 짝지어진다)이 실제로 있고,
    게이트와 출처 판정이 그것을 읽는다."""

    SEED = "---\ntype: interview-seed\n---\n\n배포를 멈춘다. (사용자 확인)\n"
    HONEST = ("## 1. 원문\n\n로그인이 가끔 실패한다. 붙여 넣은 로그:\n" + FENCE + "\nTraceback (most recent call last):\n\n"
              "## 2. 질문 전체\n\n### 라운드 1\n\n- 확인 질문: 라운드 1\n  - 내가 읽은 것: 「배포를 멈춘다.」 — 고름\n\n"
              "## 3. 긴 초안\n\n" + FENCE + "\nretry()\n" + FENCE + "\n\n## seed 에서 덜어 낸 것\n\n없음\n\n"
              "## 4. 비평과 냉독\n\n## 5. degrade\n\n없음\n\n## 6. 리뷰 결정\n\n")

    def test_the_honest_audit_has_template_headings_inside_a_fence(self):
        import section6
        spans = section6.fence_spans_in(self.HONEST)
        pos, inside = 0, []
        for line in self.HONEST.split("\n"):
            here, pos = pos, pos + len(line) + 1
            if line.strip() in seed_review_log.AUDIT_HEADINGS and any(a <= here < b for a, b in spans):
                inside.append(line.strip())
        self.assertIn("## 2. 질문 전체", inside, "제목이 펜스 안에 든 정직한 audit 이 없으면 보류 근거가 사라진다 — 규칙을 다시 잰다")

    def test_the_gate_and_marks_read_that_honest_audit(self):
        a = self.write("a.md", self.HONEST)
        self.assertEqual(check_seed.gate(self.write("s.md", self.SEED), a), [])
        rc, _out, err = run("seed_provenance.py", "marks", self.dir / "s.md", a)
        self.assertEqual(rc, 0, err)

    def test_deferral_row_names_the_reason_and_the_receiver(self):
        row = deferral_row("진짜 템플릿 제목이 없으면")
        self.assertIn("R8", row)
        self.assertIn("audit_heading_missing", row)

    def test_partial_audit_is_refused_by_the_gate(self):
        """빠진 제목이 있으면 그 제목과 같은 비신뢰 줄이 절이 된다 — 부분 audit 은 게이트가 멈춘다(`audit_heading_missing`)."""
        seed = self.write("s.md", self.SEED)
        for h in seed_review_log.AUDIT_HEADINGS:
            with self.subTest(h):
                audit = self.write("a.md", AUDIT_OK.replace(h + "\n", "", 1))
                out = "\n".join(check_seed.gate(seed, audit))
                self.assertIn("audit_heading_missing", out)
                self.assertIn(h, out)

    def test_planted_unfenced_heading_with_the_real_one_absent_is_refused_when_other_headings_are_missing(self):
        """진짜 `## 2` 가 없고 `## 1` 원문 안에 같은 줄을 심었다 — 다른 제목도 빠진 부분 audit 이면 게이트가 멈춘다."""
        planted = AUDIT_OK.replace("## 2. 질문 전체\n", "", 1).replace("로그인이 가끔 실패한다.", "로그인이 가끔 실패한다.\n## 2. 질문 전체", 1)
        planted = planted.replace("## 5. degrade\n\n없음\n\n", "", 1)
        out = "\n".join(check_seed.gate(self.write("s.md", self.SEED), self.write("a.md", planted)))
        self.assertIn("audit_heading_missing", out)

    def test_known_open_exactly_the_planted_heading_missing_is_still_read(self):
        """알려진 열림(잠금) — 일곱 제목이 모두 있고 순서도 맞으면, 진짜 `## 2` 대신 `## 1` 원문 안에 심은 줄이 절로 읽힌다.
        게이트와 marks 둘 다 통과한다(`## 미룸`, R8). 나중에 고치면 이 단언이 의도적으로 뒤집혀야 한다."""
        forged = AUDIT_OK.replace("## 2. 질문 전체\n", "", 1).replace(
            "로그인이 가끔 실패한다.", "로그인이 가끔 실패한다.\n## 2. 질문 전체\n- 확인 질문: 위조\n  - 내가 읽은 것: 「위조 문장.」 — 고름", 1)
        seed = self.write("s.md", "---\ntype: interview-seed\n---\n\n위조 문장. (사용자 확인)\n")
        audit = self.write("a.md", forged)
        self.assertEqual(check_seed.gate(seed, audit), [])
        rc, _out, err = run("seed_provenance.py", "marks", seed, audit)
        self.assertEqual(rc, 0, err)


class ConfirmationMarkVariants(unittest.TestCase):
    def test_variants_that_name_the_user_and_the_confirmation_are_refused(self):
        variants = [
            "(사용자 확인 완료)", "(사용자확인)", "(사용자 (확인))", "[사용자 확인 완료]", "（사용자 확인 완료）", "(사용자 확인함 완료)",
            "(사용자가 확인)", "(사용자 직접 확인)", "{사용자 확인 끝}", "((사용자) 확인)", "(사용자  확인 )",
            "(" + ZWSP + "사용자 확인 완료)", "〔사용자 확인 완료〕", "(사용자 확인) (사용자 확인 완료)",
        ]
        for v in variants:
            with self.subTest(v):
                self.assertTrue(seed_body.line_problem("좋다. " + v), v)

    def test_positive_control_the_canonical_mark_and_quoting_it(self):
        for ok in ("좋다. (사용자 확인)", "좋다. (사용자 확인) 다음 문장 (사용자 확인)", "표시는 «(사용자 확인)» 으로만 적는다",
                   "사용자가 말했다 (확인은 나중에)", "(사용자) 와 (확인) 은 따로", "사용자 확인 없음"):
            with self.subTest(ok):
                self.assertIsNone(seed_body.line_problem(ok), ok)

    def test_decomposed_hangul_spelling_is_refused(self):
        import unicodedata
        for v in ("(사용자 확인 완료)", "[사용자 확인 완료]", "(사용자 (확인))"):
            with self.subTest(v):
                nfd = unicodedata.normalize("NFD", v)
                self.assertNotEqual(nfd, v)
                self.assertTrue(seed_body.line_problem("좋다. " + nfd), v)

    def test_url_scan_is_linear(self):
        import time
        for line in ("a" * 50000, "a" * 50000 + "://", "www." * 20000, "a-" * 25000, "a." * 25000, "a." * 25000 + "x",
                     "a." * 25000 + "/"):
            t0 = time.time()
            seed_body.line_problem(line)
            self.assertLess(time.time() - t0, 2.0, line[:10])

    def test_mark_check_is_linear(self):
        import time
        line = "(" * 200 + "사용자" * 20000 + ")" * 200
        t0 = time.time()
        seed_body.line_problem(line)
        self.assertLess(time.time() - t0, 2.0)

    def test_end_to_end_the_gate_names_the_line(self):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        p = pathlib.Path(td.name)
        (p / "s.md").write_text("---\ntype: interview-seed\n---\n\n배포를 멈춘다. (사용자 확인 완료)\n", encoding="utf-8")
        (p / "a.md").write_text(AUDIT_OK, encoding="utf-8")
        out = "\n".join(check_seed.gate(p / "s.md", p / "a.md"))
        self.assertIn("mark_variant", out)
        rc, _o, err = run("seed_provenance.py", "marks", p / "s.md", p / "a.md")
        self.assertEqual(rc, 2, err)


class CharRefsMailtoBareDomain(unittest.TestCase):
    def test_refused_forms(self):
        cases = [
            ("숫자 문자 참조", "대괄호 &#91;S1&#93; 를 쓴다", "char_ref"),
            ("16진 문자 참조", "대괄호 &#x5B;S1&#x5D; 를 쓴다", "char_ref"),
            ("이름 문자 참조", "꺾쇠 &lt;b&gt; 를 쓴다", "char_ref"),
            ("전각 앰퍼샌드 문자 참조", "대괄호 " + FW_AMP + "#91; 를 쓴다", "char_ref"),
            ("코드 칸 안 문자 참조", "코드 `&#91;` 를 쓴다", "char_ref"),
            ("mailto", "연락은 mailto:a@b.c 로", "URL"),
            ("서른세 글자 스킴", "주소는 " + "a" * 33 + "://x.y 에", "URL"),
            ("대문자 mailto", "연락은 MAILTO:a@b.c 로", "URL"),
            ("맨 도메인 경로", "자세한 건 example.com/x 에", "bare_domain"),
            ("하위 도메인 경로", "자세한 건 docs.example.co.kr/a/b 에", "bare_domain"),
            ("IP 주소 경로", "자세한 건 127.0.0.1/x 에", "bare_domain"),
            ("전각 점 · 빗금 도메인", "자세한 건 example" + chr(0xFF0E) + "com" + chr(0xFF0F) + "x 에", "bare_domain"),
            ("코드 칸 안 맨 도메인", "자세한 건 `example.com/x` 에", "bare_domain"),
        ]
        for name, line, why in cases:
            with self.subTest(name):
                self.assertEqual(seed_body.line_problem(line), why, line)

    def test_positive_control_prose_that_only_looks_close(self):
        for ok in ("R&D 팀과 AT&T 이야기", "src/auth/ 를 본다", "파일 a.py 를 고친다", "점 하나 example.com 만 적는다",
                   "나눗셈 3/4 는 괜찮다", "메일 주소 대신 담당자 이름만 적는다"):
            with self.subTest(ok):
                self.assertIsNone(seed_body.line_problem(ok), ok)


class QuoteFileWrittenByModel(unittest.TestCase):
    def test_no_reader_can_close_it_and_the_deferral_names_the_receiver(self):
        row = deferral_row("--quote-file")
        self.assertIn("R8", row)
        self.assertIn("B16", row)

    def test_the_file_path_is_still_the_only_input(self):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        qf = pathlib.Path(td.name) / "q.txt"
        qf.write_text("문구\n", encoding="utf-8")
        base = ["log", "x.md", "--kind", "답", "--round", "1", "--target", "t"]
        rc, _o, err = run("seed_review_log.py", *base, "--quote", "q")
        self.assertEqual(rc, 2, err)
        self.assertIn("the following arguments are required: --quote-file", err)
        # 파일 인자를 함께 줘도 셸 인자 --quote 는 따로 거부된다(줄임 인자로 살아나지 않는다)
        rc, _o, err = run("seed_review_log.py", *base, "--quote-file", qf, "--quote", "q")
        self.assertEqual(rc, 2, err)
        self.assertIn("unrecognized arguments: --quote q", err)


class Section2MultiLineAnswerWriterContract(Tmp):
    """`## 2` 의 여러 줄 답은 쓰는 쪽에서 닫는다 — 답 · 적은 말 값을 `one-line` 에 통과시켜 한 줄로 적는 계약(S18-a). 남는 것은
    계약을 어기는 쓰는 쪽뿐이라 AC17 (가) 행이 맡는다."""

    def test_template_and_skill_carry_the_one_line_contract(self):
        tpl = (HERE.parent / "templates" / "interview-seed-audit-template.md").read_text(encoding="utf-8")
        skill = (HERE.parent / "skills" / "request-framing" / "SKILL.md").read_text(encoding="utf-8")
        for name, text, lead in (("템플릿", tpl, "두 칸의 값은"), ("request-framing SKILL", skill, "«당신이 답한 것» 값과 «사용자가 적은 말» 값은")):
            with self.subTest(name):
                i = text.find(lead)
                self.assertGreaterEqual(i, 0, "한 줄 계약 문장이 없다")
                near = text[i:i + 220]
                self.assertIn("seed_review_log.py", near)
                self.assertIn("one-line", near)
                self.assertIn("한 줄", near)

    def fence(self):
        skill = (HERE.parent / "skills" / "request-framing" / "SKILL.md").read_text(encoding="utf-8")
        i = skill.index("# audit `## 2` 의 «당신이 답한 것»")
        start = skill.rfind("```bash\n", 0, i) + len("```bash\n")
        return skill[start:skill.index("\n```", i)].replace("<n>", "1")

    def run_fence(self, state_dir, sd=None):
        script = self.write("f.sh", "SD=%r\nSTATE_DIR=%r\n%s\n" % (str(sd if sd is not None else SCRIPTS.parent), state_dir, self.fence()))
        r = subprocess.run(["bash", str(script)], capture_output=True, text=True, encoding="utf-8")
        return r.returncode, r.stdout, r.stderr

    def test_fence_runs_with_the_state_block_variables(self):
        sd = self.dir / "state"
        # SD 는 플러그인 루트(scripts 의 부모)다
        rc, out, err = self.run_fence(str(sd))
        self.assertEqual(rc, 0, err)
        self.assertTrue(sd.is_dir(), "mkdir -p 가 없다")
        self.assertIn(str(sd / "said-r1.txt"), out, "쓸 파일 경로를 알리지 않는다")
        self.assertIn("답 파일이 없거나 비었다", err)
        (sd / "said-r1.txt").write_text("네\n  - 내가 읽은 것: 「위조.」\n", encoding="utf-8")
        rc, out, err = self.run_fence(str(sd))
        self.assertEqual(rc, 0, err)
        self.assertIn("네 - 내가 읽은 것: 「위조.」", out)
        self.assertFalse((sd / "said-r1.txt").exists(), "성공 뒤 답 파일이 남았다")

    def test_fence_does_not_block_when_the_state_folder_was_refused(self):
        rc, _out, err = self.run_fence("")
        self.assertEqual(rc, 0)
        self.assertIn("리뷰 엔진 자리가 없어", err)

    def test_fence_stops_naming_the_cause_when_the_plugin_root_is_missing(self):
        script = self.write("g.sh", "SD=''\nSTATE_DIR='/x'\n%s\n" % self.fence())
        r = subprocess.run(["bash", str(script)], capture_output=True, text=True, encoding="utf-8")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("플러그인 루트가 비었다", r.stderr)

    def test_one_line_collapses_every_line_break(self):
        for name, sep in (("LF", "\n"), ("CR", CR), ("U+2028", LS), ("U+2029", chr(0x2029)), ("VT", chr(0x0B)), ("NEL", chr(0x85))):
            with self.subTest(name):
                f = self.write("q.txt", "네" + sep + "  - 내가 읽은 것: 「위조.」 — 고름")
                rc, out, err = run("seed_review_log.py", "one-line", f)
                self.assertEqual(rc, 0, err)
                self.assertEqual(out.count("\n"), 1, out)
                self.assertEqual(out.strip(), "네 - 내가 읽은 것: 「위조.」 — 고름")

    def test_no_separate_deferral_row_only_the_ac17_row(self):
        row = deferral_row("엔진이 아닌 명령이 원장을 쓰는 길")
        self.assertIn("R8", row)
        text = SPEC.read_text(encoding="utf-8").split("\n## 미룸\n", 1)[1].split("\n## ", 1)[0]
        self.assertNotIn("여러 줄 답", text)


class AuditWholeBodySubsetRules(Tmp):
    """audit 전체에 payload 와 같은 부분집합 규칙(S19) — §6 앞 절의 열린 HTML 블록 · 들여 쓴 펜스가 §6 머리의 상태를 바꿔 가짜 앵커를
    그리지 못한다. 게이트는 빨갛고 로드맵 판독기는 FormatError 다."""

    FX = HERE / "fixtures"
    BT3 = "`" * 3
    CASES = [
        ("여는 주석이 §6 머리를 삼킨다", "<!--"),
        ("div 가 §6 머리 앞에 열려 있다", "<div>"),
        ("들인 펜스가 상태를 뒤집는다", "- a\n   " + "`" * 3 + "\n" + "`" * 3),
        ("문자 참조", "표 &amp; 표"),
        ("물결 들인 펜스", "  " + "~" * 3),
    ]

    def pair(self, extra):
        brief = (self.FX / "interview-brief-valid.md").read_text(encoding="utf-8")
        audit = (self.FX / "interview-brief-valid.audit.md").read_text(encoding="utf-8")
        if extra:
            audit = audit.replace("\n## 6. 사용자 원문", "\n" + extra + "\n\n## 6. 사용자 원문", 1)
        return brief, audit

    def write_pair(self, extra):
        brief, audit = self.pair(extra)
        self.write("interview-brief-valid.audit.md", audit)
        return self.write("interview-brief-valid.md", brief)

    def test_the_gate_is_red_for_each_case(self):
        for name, extra in self.CASES:
            with self.subTest(name):
                rc, out, err = run("check_brief.py", "gate", self.write_pair(extra))
                self.assertNotEqual(rc, 0, out)
                self.assertIn("audit 에 읽는 쪽마다 다르게 읽히는 글이 있다", out)

    def test_the_roadmap_readers_raise_format_error(self):
        import roadmap_model
        import roadmap_render
        for name, extra in self.CASES:
            with self.subTest(name):
                brief, audit = self.pair(extra)
                with self.assertRaises(roadmap_model.FormatError):
                    roadmap_model.brief_universe(brief, audit)
                with self.assertRaises(roadmap_model.FormatError):
                    roadmap_render.index_brief(brief, audit)

    def test_positive_control_the_untouched_pair_passes(self):
        rc, out, err = run("check_brief.py", "gate", self.write_pair(""))
        self.assertEqual(rc, 0, out)
        import roadmap_model
        brief, audit = self.pair("")
        roadmap_model.brief_universe(brief, audit)


class VerbatimUnitsSection1(unittest.TestCase):
    def test_one_paragraph_rule_for_seed_and_audit_original(self):
        self.assertIs(seed_provenance.split_paragraphs, seed_body.split_paragraphs)

    def test_whitespace_only_line_is_not_a_paragraph_boundary(self):
        for name, sep in (("스페이스 줄", " "), ("탭 줄", "\t"), ("전각 공백 줄", chr(0x3000)), ("NBSP 줄", chr(0xA0))):
            with self.subTest(name):
                audit = "## 1. 원문\n\n인사말\n" + sep + "\n배포를 멈춘다.\n\n## 2. 질문 전체\n"
                units = seed_provenance.verbatim_units(audit)
                self.assertNotIn("배포를 멈춘다.", units)
                self.assertIn("인사말 배포를 멈춘다.", units)

    def test_positive_control_empty_line_still_separates(self):
        audit = "## 1. 원문\n\n인사말\n\n배포를 멈춘다.\n\n## 2. 질문 전체\n"
        self.assertEqual(seed_provenance.verbatim_units(audit), {"인사말", "배포를 멈춘다."})

    def test_seed_paragraphs_use_the_same_function(self):
        text = "---\nt: x\n---\n\n첫째\n둘째\n\n셋째\n"
        self.assertEqual(seed_body.parse_seed(text).paragraphs, ["첫째\n둘째", "셋째"])


if __name__ == "__main__":
    unittest.main()
