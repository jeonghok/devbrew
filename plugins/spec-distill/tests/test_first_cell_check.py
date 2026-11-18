"""check_verbatim_coverage.py — 첫 칸의 아홉 칸(L4)과 모든 답의 표시 대조(L5)."""
from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_SCRIPTS = _HERE.parent / "scripts"
sys.path.insert(0, str(_SCRIPTS))
sys.path.insert(0, str(_HERE))
CVC = str(_SCRIPTS / "check_verbatim_coverage.py")
RAW = str(_SCRIPTS / "raw_source.py")
GATE = str(_SCRIPTS / "check_brief.py")

import raw_source as RS  # noqa: E402
import raw_source_fixture as FX  # noqa: E402
from test_raw_source_text import LOADABLE  # noqa: E402

BRIEF = "docs/iv/t-brief-interview.md"
OLD = "옛 꼴의 첫 칸 — seed 전문이 사용자 원문 자리에 있다"
QUOTE = '  > "모델이 줄인 요청 한 문단."'
CLOSING = "- 포화 판정 2: 사용자 판단 포화(@S3) — 조사 불필요"
S3_CHOSEN = "- **S3** ☑ 선택 (포화):"
S3_SPOKEN = "- **S3** " + RS.ANCHOR_MARK + " 선택 (포화):"
VS16 = chr(0xFE0F)


def _read(p) -> str:
    return Path(p).read_text(encoding="utf-8")


def _write(p, text: str) -> None:
    Path(p).write_text(text, encoding="utf-8")


def _sub(p, old: str, new: str) -> None:
    text = _read(p)
    if text.count(old) != 1:
        raise AssertionError("%r 가 %s 에 %d번" % (old, p, text.count(old)))
    _write(p, text.replace(old, new))


def s1_with(label: str) -> str:
    return RS.anchor_line(label) + "\n" + QUOTE


class _Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._n = 0

    def repo(self, **kw) -> dict:
        self._n += 1
        return FX.make_repo(Path(self._tmp.name) / ("r%d" % self._n), **kw)

    def place(self, fx) -> None:
        cp = subprocess.run([sys.executable, RAW, "place", "--interview", BRIEF], cwd=fx["repo"],
                            capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(cp.returncode, 0, cp.stdout + cp.stderr)

    def check(self, fx):
        cp = subprocess.run([sys.executable, CVC, fx["brief"], fx["state"], fx["audit"]],
                            capture_output=True, text=True, encoding="utf-8")
        try:
            out = json.loads(cp.stdout)
        except ValueError:
            self.fail("JSON 이 아니다: rc=%d %r %r" % (cp.returncode, cp.stdout, cp.stderr))
        return cp.returncode, out

    def edit_first_cell(self, fx, fn) -> None:
        """결과물의 S1 앵커 줄 다음부터 S2 앵커 줄 앞까지의 줄을 fn 으로 바꾼다."""
        lines = _read(fx["brief"]).split("\n")
        a = next(i for i, ln in enumerate(lines) if ln.startswith("- **S1** "))
        b = next(i for i, ln in enumerate(lines) if ln.startswith("- **S2** "))
        new = fn(list(lines[a + 1:b]))
        self.assertNotEqual(new, lines[a + 1:b], "변이가 첫 칸을 바꾸지 않았다")
        lines[a + 1:b] = new
        _write(fx["brief"], "\n".join(lines))

    def assert_ok(self, rc, out):
        self.assertEqual(rc, 0, out)
        self.assertEqual(out["first_cell"], [], out)
        self.assertEqual(out["source_mismatch"], [], out)


class FirstCell(_Base):
    def test_found_raw_ok(self):
        fx = self.repo()
        self.place(fx)
        rc, out = self.check(fx)
        self.assert_ok(rc, out)
        self.assertNotIn(OLD, out["advisories"])

    def test_gate_and_coverage_together(self):
        for name in ("제목과 코드", "긴 펜스"):
            with self.subTest(name=name):
                fx = self.repo(raw1=LOADABLE[name])
                self.place(fx)
                cp = subprocess.run([sys.executable, GATE, "gate", fx["brief"]], capture_output=True, text=True,
                                    encoding="utf-8")
                self.assertEqual(cp.returncode, 0, cp.stdout + cp.stderr)
                rc, out = self.check(fx)
                self.assert_ok(rc, out)

    def _one_char(self, old, new):
        fx = self.repo()
        self.place(fx)
        self.edit_first_cell(fx, lambda ls: [ln.replace(old, new) for ln in ls])
        rc, out = self.check(fx)
        self.assertEqual(rc, 1, out)
        self.assertEqual(out["first_cell"], ["body_mismatch"], out)
        return [a for a in out["advisories"] if a.startswith("첫 칸 위반")]

    def test_one_char_in_section1(self):
        adv = self._one_char("원문절표지", "원문절표치")
        self.assertEqual(len(adv), 1, adv)
        self.assertIn("원문 절의 글자가", adv[0])
        self.assertNotIn("질문 전체 절", adv[0])

    def test_one_char_in_section2(self):
        adv = self._one_char("어느 쪽부터 고칠까요?", "어느 쪽부터 고칠까?")
        self.assertEqual(len(adv), 1, adv)
        self.assertIn("질문 전체 절의 글자가", adv[0])
        self.assertNotIn("원문 절", adv[0])

    def test_quote_marker_differs(self):
        fx = self.repo()
        self.place(fx)
        self.edit_first_cell(fx, lambda ls: ["> " + ln if ln.strip() == "끝." else ln for ln in ls])
        rc, out = self.check(fx)
        self.assertEqual(rc, 1, out)
        self.assertEqual(out["first_cell"], ["body_mismatch"], out)

    def test_trailing_whitespace_stripped(self):
        fx = self.repo()
        self.place(fx)
        self.edit_first_cell(fx, lambda ls: [ln.rstrip() for ln in ls])
        rc, out = self.check(fx)
        self.assertEqual(rc, 1, out)
        self.assertEqual(out["first_cell"], ["body_mismatch"], out)

    def test_crlf_audit_roundtrip(self):
        fx = self.repo()
        crlf = _read(fx["framing"]).replace("\n", "\r\n")
        Path(fx["framing"]).write_bytes(crlf.encode("utf-8"))
        self.assertIn(b"\r\n", Path(fx["framing"]).read_bytes())
        self.place(fx)
        self.assertNotIn(b"\r", Path(fx["brief"]).read_bytes())
        rc, out = self.check(fx)
        self.assert_ok(rc, out)

    def test_redacted_text_is_judged(self):
        fx = self.repo(raw1=FX.RAW1 + "\n키는 <REDACTED:api-key> 를 썼다.")
        self.place(fx)
        self.assertIn("<REDACTED:api-key>", _read(fx["brief"]))
        rc, out = self.check(fx)
        self.assert_ok(rc, out)

    def test_masked_audit_then_place(self):
        fx = self.repo(raw1=FX.RAW1 + "\n키는 sk-live-abc123 를 썼다.")
        _sub(fx["framing"], "sk-live-abc123", "<REDACTED:api-key>")
        self.place(fx)
        self.assertNotIn("sk-live-abc123", _read(fx["brief"]))
        rc, out = self.check(fx)
        self.assert_ok(rc, out)

    def test_found_unloadable_label(self):
        fx = self.repo(raw1="앞 글 **S3** 뒤 글", s1_line=s1_with(RS.LABEL_UNLOADABLE))
        rc, out = self.check(fx)
        self.assert_ok(rc, out)

    def test_lone_cr_unloadable_label(self):
        # 검사 쪽도 기록을 `read_audit_text` 로 읽는다 — 범용 줄바꿈으로 읽으면 홀로 선 \r 이 줄 나눔이 되어 정당한 라벨이 위반이 된다
        fx = self.repo(raw1="앞\r뒤 줄", s1_line=s1_with(RS.LABEL_UNLOADABLE))
        self.assertIn(b"\xec\x95\x9e\r\xeb\x92\xa4", Path(fx["framing"]).read_bytes())
        rc, out = self.check(fx)
        self.assertEqual(rc, 0, out)
        self.assertEqual(out["first_cell"], [], out)

    def test_unloadable_label_but_loadable(self):
        fx = self.repo(s1_line=s1_with(RS.LABEL_UNLOADABLE))
        rc, out = self.check(fx)
        self.assertEqual(rc, 1, out)
        self.assertEqual(out["first_cell"], ["label_unloadable_but_loadable"], out)
        self.assertIn("첫 칸 위반 — 그대로 실을 수 있는 원자료인데 「그대로 싣지 못함」 라벨을 달았다", out["advisories"])

    def test_found_lost_label(self):
        fx = self.repo(s1_line=s1_with(RS.LABEL_LOST))
        rc, out = self.check(fx)
        self.assertEqual(rc, 1, out)
        self.assertEqual(out["first_cell"], ["label_lost_but_found"], out)
        self.assertIn("첫 칸 위반 — 원자료를 찾았는데 「찾지 못함」 라벨을 달았다", out["advisories"])

    def test_found_old_label(self):
        fx = self.repo(s1_line="- **S1** " + RS.ANCHOR_MARK + " 최초 요청:\n" + QUOTE)
        rc, out = self.check(fx)
        self.assert_ok(rc, out)
        self.assertIn(OLD, out["advisories"])

    def test_lost_lost_label(self):
        fx = self.repo(mode="lost", s1_line=s1_with(RS.LABEL_LOST))
        rc, out = self.check(fx)
        self.assert_ok(rc, out)
        self.assertEqual(out["advisories"], [], out)

    def test_pasted_seed_lost_label(self):
        fx = self.repo(mode="pasted", s1_line=s1_with(RS.LABEL_LOST))
        cp = subprocess.run([sys.executable, RAW, "locate", "--interview", BRIEF], cwd=fx["repo"],
                            capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(cp.returncode, 3, cp.stdout + cp.stderr)
        self.assertTrue(cp.stdout.strip().startswith("raw-source: LOST "), cp.stdout)
        rc, out = self.check(fx)
        self.assert_ok(rc, out)

    def test_lost_raw_label(self):
        for label in (RS.LABEL_RAW, RS.LABEL_UNLOADABLE):
            with self.subTest(label=label):
                fx = self.repo(mode="lost", s1_line=s1_with(label))
                rc, out = self.check(fx)
                self.assertEqual(rc, 1, out)
                self.assertEqual(out["first_cell"], ["label_raw_but_lost"], out)
                want = ("첫 칸 위반 — 원자료를 찾지 못했는데(" + RS.R_AUDIT_MISSING.format(audit=FX.FRAMING_REL)
                        + ") 원자료 라벨을 달았다")
                self.assertIn(want, out["advisories"])

    def test_lost_old_label(self):
        fx = self.repo(mode="lost")
        rc, out = self.check(fx)
        self.assert_ok(rc, out)
        self.assertEqual(out["advisories"], [OLD], out)

    def test_no_framing_new_label(self):
        for label in (RS.LABEL_LOST, RS.LABEL_RAW, RS.LABEL_UNLOADABLE):
            with self.subTest(label=label):
                fx = self.repo(mode="no-framing", s1_line=s1_with(label))
                rc, out = self.check(fx)
                self.assertEqual(rc, 1, out)
                self.assertEqual(out["first_cell"], ["label_on_no_framing"], out)
                self.assertIn("첫 칸 위반 — framing 없는 인터뷰인데 원자료 라벨을 달았다", out["advisories"])

    def test_no_framing_old_label(self):
        fx = self.repo(mode="no-framing")
        rc, out = self.check(fx)
        self.assert_ok(rc, out)
        self.assertNotIn(OLD, out["advisories"])
        self.assertEqual(out["advisories"], [], out)

    def test_sections_unreadable(self):
        fx = self.repo()
        self.place(fx)
        _sub(fx["framing"], "## 2. 질문 전체\n", "")
        rc, out = self.check(fx)
        self.assertEqual(rc, 3, out)
        self.assertEqual(out["first_cell"], [], out)
        self.assertTrue(any(a.startswith("검사 불가 — framing 기록의 원문 절 · 질문 전체 절을 읽지 못해 첫 칸을 견주지 못했다(")
                            for a in out["advisories"]), out)

    def test_ledger_s1_with_raw_label(self):
        fx = self.repo()
        _sub(fx["state"], "- id: S2\n",
             '- id: S1\n  source: verbatim\n  round: 1\n  text: "seed전문표지 — 모델이 줄인 요청 한 문단."\n- id: S2\n')
        self.place(fx)
        rc, out = self.check(fx)
        self.assertEqual(rc, 1, out)
        self.assertIn("S1", out["not_contained"], out)

    def test_violation_survives_empty_ledger(self):
        fx = self.repo(s1_line=s1_with(RS.LABEL_LOST))
        text = _read(fx["state"])
        emptied = re.sub(r"(?m)^user_statements:\n(?:[- ].*\n)*", "user_statements: []\n", text, count=1)
        self.assertNotEqual(emptied, text)
        _write(fx["state"], emptied)
        _sub(fx["audit"], CLOSING, "- 포화 판정 2: 포화 — 최근 두 조사 모두 결정을 바꾸지 않았다")
        rc, out = self.check(fx)
        self.assertEqual(rc, 1, out)
        self.assertEqual(out["first_cell"], ["label_lost_but_found"], out)
        self.assertEqual(out["not_chosen"], [], out)


class Marks(_Base):
    def test_all_match(self):
        fx = self.repo()
        self.place(fx)
        rc, out = self.check(fx)
        self.assert_ok(rc, out)
        self.assertFalse([a for a in out["advisories"] if a.startswith("표시")], out)

    def test_mismatch_new_label(self):
        fx = self.repo()
        self.place(fx)
        _sub(fx["brief"], S3_CHOSEN, S3_SPOKEN)
        rc, out = self.check(fx)
        self.assertEqual(rc, 1, out)
        self.assertEqual(out["source_mismatch"], ["S3"], out)
        self.assertIn("표시 위반 — S3: 결과물의 표시 " + RS.ANCHOR_MARK + " · 상태 파일의 source chosen",
                      out["advisories"])

    def test_mismatch_old_label(self):
        fx = self.repo(mode="no-framing")
        _sub(fx["brief"], S3_CHOSEN, S3_SPOKEN)
        rc, out = self.check(fx)
        self.assertEqual(rc, 0, out)
        self.assertEqual(out["source_mismatch"], [], out)
        self.assertIn("표시 어긋남(알림) — S3: 결과물의 표시 " + RS.ANCHOR_MARK + " · 상태 파일의 source chosen",
                      out["advisories"])

    def test_mismatch_mark_absent(self):
        fx = self.repo()
        self.place(fx)
        _sub(fx["brief"], "- **S4** " + RS.ANCHOR_MARK + " 답:", "- **S4** 답:")
        rc, out = self.check(fx)
        self.assertEqual(rc, 1, out)
        self.assertEqual(out["source_mismatch"], ["S4"], out)
        self.assertIn("표시 위반 — S4: 결과물의 표시 없음 · 상태 파일의 source verbatim", out["advisories"])

    def test_variation_selector_ignored(self):
        fx = self.repo()
        self.place(fx)
        _sub(fx["brief"], "- **S2** " + RS.ANCHOR_MARK + " 답:", "- **S2** " + RS.ANCHOR_MARK + VS16 + " 답:")
        rc, out = self.check(fx)
        self.assert_ok(rc, out)
        self.assertFalse([a for a in out["advisories"] if a.startswith("표시")], out)

    def test_s1_not_in_ledger_skipped(self):
        fx = self.repo()
        self.place(fx)
        self.assertNotIn("- id: S1\n", _read(fx["state"]))
        rc, out = self.check(fx)
        self.assert_ok(rc, out)
        self.assertFalse([a for a in out["advisories"] if "S1" in a], out)

    def test_source_absent_not_compared(self):
        cases = (("- id: S2\n", "source 없음"), ('- id: S2\n  source: ""\n', "source 없음"),
                 ("- id: S2\n  source: typed\n", "source typed"))
        for repl, tail in cases:
            with self.subTest(repl=repl):
                fx = self.repo()
                self.place(fx)
                _sub(fx["state"], "- id: S2\n  source: verbatim\n", repl)
                rc, out = self.check(fx)
                self.assert_ok(rc, out)
                self.assertIn("표시 대조 불가 — S2: " + tail, out["advisories"])
                self.assertEqual([a for a in out["advisories"] if a.startswith("표시 대조 불가")],
                                 ["표시 대조 불가 — S2: " + tail], out)


if __name__ == "__main__":
    unittest.main()
