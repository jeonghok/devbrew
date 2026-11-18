"""seed 문법이 줄 안의 가림 표시를 산문으로 받는가 — 줄 머리 · URL · 도메인 · 대괄호 · 다른 꺾쇠는 그대로 거부한다."""
from __future__ import annotations

import contextlib
import io
import pathlib
import sys
import tempfile
import unittest

_SCRIPTS = pathlib.Path(__file__).resolve().parent.parent / "scripts"
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

import check_seed  # noqa: E402
import seed_body  # noqa: E402
import seed_provenance  # noqa: E402
from test_seed_grammar_crosscheck import AUDIT, STRUCT_GATE  # noqa: E402

ACCEPT = ["값은 <REDACTED> 로 가렸다.", "키 <REDACTED:api-key> 를 썼다.", "토큰 <TOKEN:깃허브> 이 있다.",
          "비밀 <SECRET_x> 이다.", "열쇠 <KEY-a.b> 다.", "접속 <CREDENTIAL:db> 다.", "자리 <PLACEHOLDER:x> 다."]
REJECT = ["<REDACTED> 로 시작한다.", "앞 <redacted> 뒤", "앞 <REDACTED: 공백> 뒤", "앞 <REDACTEDX> 뒤",
          "앞 <b>굵게</b> 뒤", "앞 <https://x.y> 뒤", "- <REDACTED> 목록", "앞 [<REDACTED>](x) 뒤",
          "앞 <REDACTED:www.x> 뒤", "키 <REDACTED> 와 <b>굵게</b> 다.", "키 <<REDACTED>> 다."]


class Placeholder(unittest.TestCase):
    def test_accept(self):
        for line in ACCEPT:
            with self.subTest(line):
                self.assertIsNone(seed_body.line_problem(line))

    def test_reject(self):
        for line in REJECT:
            with self.subTest(line):
                self.assertIsNotNone(seed_body.line_problem(line))

    def test_gate_and_marks(self):
        text = "---\ntype: interview-seed\n---\n\n문장 하나.\n\n키 <REDACTED:api-key> 를 썼다.\n"
        with tempfile.TemporaryDirectory(prefix="sd-ph-") as d:
            seed, audit = pathlib.Path(d) / "s.md", pathlib.Path(d) / "a.audit.md"
            seed.write_text(text, encoding="utf-8")
            audit.write_text(AUDIT, encoding="utf-8")
            probs = check_seed.gate(seed, audit)
            self.assertFalse([p for p in probs if p.startswith(STRUCT_GATE)], probs)
            out = io.TextIOWrapper(io.BytesIO(), encoding="utf-8")
            err = io.TextIOWrapper(io.BytesIO(), encoding="utf-8")
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                rc = seed_provenance.main(["marks", str(seed), str(audit)])
            self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
