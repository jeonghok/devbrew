"""seed 본문 · audit `## 6` 을 읽는 쪽들이 같은 판정을 내는가 — 만든 입력으로 교차 대조한다.

손으로 적은 우회 목록이 아니다. 고정 씨앗의 난수로 표기 조합(블록 머리 표지 · 겹친 컨테이너 · 유니코드
범주표의 글자 · 호환 글자 · 링크 · HTML · 표시 변형)을 수백 개 만들고, 만든 쪽이 아는 정답(정직한 산문 /
막아야 할 구조)과 세 읽는 쪽의 판정이 모두 같은지 본다.

- seed: `seed_body.parse_seed` 가 거부한 줄이 있다 ⇔ `check_seed.gate` 가 «산문이 아닌 구조» 로 막는다 ⇔
  `seed_provenance marks` 가 판단을 거부한다(rc 2) ⇔ `classify` 도 거부한다(rc 2). 정직한 산문은 셋 다 받는다.
- `## 6`: `decision_line_problems` 가 줄을 잡는다 ⇔ `parse_lines` 가 거부한다 ⇔ `user-quotes` · `check-drops`
  가 rc 2 다. 기록 줄 · 계수 줄 · `없음` 은 넷 다 받는다.
읽는 쪽은 같은 프로세스에서 부르고(속도), 몇 개는 CLI 로도 불러 배선이 같은지 본다.
"""
from __future__ import annotations

import contextlib
import io
import pathlib
import random
import subprocess
import sys
import tempfile
import unittest

_SCRIPTS = pathlib.Path(__file__).resolve().parent.parent / "scripts"
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

import check_seed  # noqa: E402
import seed_body  # noqa: E402
import seed_provenance  # noqa: E402
import seed_review_log  # noqa: E402

SEED_RNG = 20261015
STRUCT_GATE = "seed 에 산문이 아닌 구조가 있다"
STRUCT_PROV = "[seed_provenance] seed 에 산문이 아닌 구조가 있다"
CONFIRMED = "세션 스토어 개편은 이번에 하지 않는다."
FRONT = "---\ntype: interview-seed\n---\n\n"

AUDIT = """---
type: interview-seed-audit
---

## 1. 원문

로그인이 가끔 실패한다.

## 2. 질문 전체

### 라운드 1

- 확인 질문: 라운드 1
  - 내가 읽은 것: 「%s」 — 고름

## 3. 긴 초안

긴 초안.

## seed 에서 덜어 낸 것

없음

## 4. 비평과 냉독

## 5. degrade

## 6. 리뷰 결정

- 답 · r1 · aaaa0001#r1.1 · "QUOTE_REAL" — 요약
""" % CONFIRMED

WORDS = ["로그인", "세션", "서버", "토큰", "경합", "재현", "버그", "기록", "요청", "사용자", "화면", "설정",
         "배포", "검사", "조사", "방향", "이유", "근거", "결정", "범위"]
ENDINGS = ["이다.", "를 본다.", "가 의심된다.", "는 아직 모른다.", "를 다시 본다.", "에서 실패한다."]

# 블록 머리 표지 — 산문 줄이 아닌 것으로 읽혀야 할 줄 머리들
BLOCK_PREFIXES = ["#", "##", "###", "####### ", "# ", "## ", "###### ", ">", "> ", ">>", "- ", "* ", "+ ",
                  "1. ", "1) ", "10. ", "| ", "```", "~~~", "    ", "===", "---", "- [ ] ",
                  "<h2>", "<div>", "<!-- ", "[x]: ", "[x](", "</", "=", "~", "-", "+", "|", ":", "!", "\\",
                  "&nbsp;", "$", "%", "^"]
# 혼자 선 줄로만 구조가 되는 것(가로줄 · setext 밑줄) — `***글자` 는 강조 산문이라 머리 표지가 아니다
STANDALONE = ["***", "___", "---", "===", "* * *", "- - -", "_ _ _", "***   "]
CONTAINERS = [">", "> ", "- ", "* ", "1. ", "> - ", "   "]
# 유니코드 범주표 — 글자 규칙이 거부해야 할 범주(서식 · 줄 구분 · 사용자 정의 · 제어 · 미할당)
REJECT_CODEPOINTS = {
    "Cf": [0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF, 0x00AD, 0x202E, 0x2066, 0x061C, 0x180E],
    "Zl/Zp": [0x2028, 0x2029],
    "Co": [0xE000, 0xF8FF],
    "Cc": [0x07, 0x1B, 0x0B, 0x0C, 0x85, 0x09, 0x1C, 0x1D, 0x1E],
    "Cn": [0x0378, 0x0870],
}
# 줄 머리에 오면 산문이 아닌 호환 · 닮은꼴 글자(NFKC 로 표지가 되거나, 표지처럼 읽히는 기호)
LOOKALIKE_STARTS = [0xFF03, 0xFF1E, 0xFF0D, 0xFF0B, 0xFF5C, 0xFF1C, 0xFF3B, 0xFE63, 0x2010, 0x2212,
                    0x2043, 0x2022, 0x00B7, 0x2026, 0x203B]
INLINE_FORBIDDEN = ["[a](b)", "![i](p)", "[a][b]", "<https://x.org>", "https://x.org", "HTTPS://x.org",
                    chr(0xFF48) + chr(0xFF54) + chr(0xFF54) + chr(0xFF50) + "://x.org", "ftp://x.org",
                    "www.x.com", "<b>x</b>", "<!-- x -->", "[open: x]", chr(0xFF3B) + "추론" + chr(0xFF1A) + "x"
                    + chr(0xFF3D), "`https://x.org`", "[^1]"]
BRACKETS = [("(", ")"), ("[", "]"), ("{", "}"), ("【", "】"), ("〔", "〕"), ("<", ">"), ("«", "»"),
            ("「", "」"), ("『", "』"), (chr(0xFF08), chr(0xFF09)), (chr(0xFE59), chr(0xFE5A)), ("“", "”")]
# 라운드 3 — 인라인 코드 경계 표기(백틱 길이 · 이웃 백틱 · 이스케이프) × 금지 조각. 코드 안도 면제가 없다.
BACKTICK_WRAPS = ["`%s`", "``%s`", "`` %s ``", "\\`%s`", "```%s```", "`%s``", "``%s``"]
CODE_FORBIDDEN = ["<h2>대안</h2>", "[x](y)", "[OPEN: 미해결 질문]", "<b>", "[^1]", "https://x.org", "www.x.com"]
HONEST_CODE = ["`src/auth/`", "`a < b`", "``a`b``", "`x.py`", "`make test`", "`--fix`"]
# 라운드 3 — 공백 글자만 있는 줄(문단 경계를 읽는 쪽마다 달리 보는 줄)
WHITESPACE_LINES = [" ", "   ", "    ", chr(0xA0), chr(0x2000), chr(0x2007), chr(0x200A), chr(0x202F), chr(0x205F),
                    chr(0x3000), chr(0x1680), chr(0x09), " " + chr(0xA0), chr(0x3000) * 2]
# 라운드 3 — audit 의 줄 나눔 글자(`\n` 밖에서 splitlines 가 끊는 것)
AUDIT_SEPARATORS = [0x2028, 0x2029, 0x85, 0x0B, 0x0C, 0x1C, 0x1D, 0x1E]
MARK_CORES = ["사용자 확인", "사용자확인", "사용자가 확인", "사용자 확인함", " 사용자 확인 ", "사용자" + chr(0x200B) + " 확인"]


def _io():
    return io.TextIOWrapper(io.BytesIO(), encoding="utf-8")


def _run_main(fn, argv):
    out, err = _io(), _io()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        try:
            rc = fn(argv)
        except Exception:  # noqa: BLE001 — CLI 의 최상위 처리와 같다(rc 2)
            rc = 2
    err.seek(0)
    return rc, err.read()


class Gen:
    def __init__(self):
        self.r = random.Random(SEED_RNG)

    def sentence(self):
        r = self.r
        s = " ".join(r.choice(WORDS) for _ in range(r.randint(2, 4))) + " " + r.choice(ENDINGS)
        k = r.random()
        if k < 0.15:
            s = "`src/%s/` 안에서 " % r.choice(["auth", "api", "db"]) + s
        elif k < 0.25:
            s = "**%s** " % r.choice(WORDS) + s
        elif k < 0.32:
            s = "「%s」 " % r.choice(WORDS) + s
        elif k < 0.38:
            s = "(%s) " % r.choice(WORDS) + s
        elif k < 0.44:
            s = "%d년에 " % r.randint(2000, 2030) + s
        elif k < 0.50:
            s = s[:-1] + " — a < b 이고 버그 #%d 이다." % r.randint(1, 99)
        elif k < 0.56:
            s = r.choice(["/compact ", "@docs/x.md ", "— ", "/spec-distill:pm-interview "]) + s
        elif k < 0.66:
            s = s[:-1] + " " + r.choice(HONEST_CODE) + " 를 본다."
        return s

    def honest(self):
        r = self.r
        paras = []
        for _ in range(r.randint(1, 3)):
            lines = [self.sentence() for _ in range(r.randint(1, 3))]
            paras.append("\n".join(lines))
        if r.random() < 0.5:
            paras.insert(r.randint(0, len(paras)), CONFIRMED + " (사용자 확인)")
        if r.random() < 0.3:
            paras.append("다시 검증할 것 — " + self.sentence())
        return FRONT + "\n\n".join(paras) + "\n"

    def _embed(self, bad_line):
        r = self.r
        paras = [self.sentence() for _ in range(r.randint(0, 2))]
        paras.insert(r.randint(0, len(paras)), bad_line)
        return FRONT + "\n\n".join(paras) + "\n"

    def forbidden(self):
        """(라벨, seed) 를 축마다 만든다."""
        r = self.r
        out = []
        for p in BLOCK_PREFIXES:
            for _ in range(3):
                out.append(("block " + repr(p), self._embed(p + self.sentence())))
        for s in STANDALONE:
            out.append(("standalone " + repr(s), self._embed(self.sentence() + "\n\n" + s)))
        for _ in range(60):
            depth = r.randint(1, 3)
            pre = "".join(r.choice(CONTAINERS) for _ in range(depth))
            inner = r.choice(["## 대안", "# 미해결 질문", "<h2>대안</h2>", "Open Questions", "- 항목", self.sentence()])
            line = pre + inner
            if pre.strip() == "" and not inner.startswith(("#", "<", "-")):
                continue  # 공백만의 머리 + 산문은 정직한 산문이다(0–3칸 들여쓰기)
            out.append(("container " + repr(pre), self._embed(line)))
        for cat, cps in REJECT_CODEPOINTS.items():
            for cp in cps:
                for _ in range(3):
                    s = self.sentence()
                    at = r.randint(0, len(s))
                    out.append(("char %s U+%04X" % (cat, cp), self._embed(s[:at] + chr(cp) + s[at:])))
        for cp in LOOKALIKE_STARTS:
            out.append(("lookalike U+%04X" % cp, self._embed(chr(cp) + " " + self.sentence())))
        for frag in INLINE_FORBIDDEN:
            for _ in range(3):
                s = self.sentence()
                out.append(("inline " + repr(frag), self._embed(s[:-1] + " " + frag + " 를 본다.")))
        for o, c in BRACKETS:
            for core in MARK_CORES:
                mark = o + core + c
                if mark == seed_body.MARK:
                    continue
                out.append(("mark " + repr(mark), self._embed(self.sentence() + " " + mark)))
        setext = [self.sentence() + "\n" + u for u in ("---", "===", "-", "= = =")]
        out += [("setext " + repr(u[-3:]), self._embed(u)) for u in setext]
        for wrap in BACKTICK_WRAPS:
            for frag in CODE_FORBIDDEN:
                out.append(("code " + repr(wrap % frag), self._embed(self.sentence()[:-1] + " " + (wrap % frag) + " 이다.")))
        for ws in WHITESPACE_LINES:
            for where in ("between", "inside"):
                a, b = self.sentence(), self.sentence()
                body = a + "\n" + ws + "\n" + b if where == "between" else a + "\n" + ws + "\n\n" + b
                out.append(("whitespace %r %s" % (ws, where), FRONT + body + "\n"))
        return out


class SeedCrossCheck(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="sd-xcheck-")
        cls.dir = pathlib.Path(cls.tmp.name)
        cls.audit = cls.dir / "a.audit.md"
        cls.audit.write_text(AUDIT, encoding="utf-8")
        g = Gen()
        cls.honest = [("honest %d" % i, g.honest()) for i in range(150)]
        cls.forbidden = g.forbidden()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _readers(self, text):
        seed = self.dir / "s.md"
        seed.write_text(text, encoding="utf-8")
        parsed = seed_body.parse_seed(text)
        probs = check_seed.gate(seed, self.audit)
        gate_struct = any(p.startswith(STRUCT_GATE) for p in probs)
        m_rc, m_err = _run_main(seed_provenance.main, ["marks", str(seed), str(self.audit)])
        c_rc, _ = _run_main(seed_provenance.main, ["classify", str(seed), "--audit", str(self.audit)])
        return bool(parsed.rejected), probs, gate_struct, m_rc, STRUCT_PROV in m_err, c_rc

    def test_corpus_size(self):
        """양성 대조 — 만든 입력이 실제로 수백 개다(공허 통과 방지)."""
        self.assertGreaterEqual(len(self.forbidden), 300)
        self.assertGreaterEqual(len(self.honest), 150)

    def test_forbidden_all_readers_refuse(self):
        miss = []
        for label, text in self.forbidden:
            rej, probs, gate_struct, m_rc, m_struct, c_rc = self._readers(text)
            if not (rej and gate_struct and m_rc == 2 and m_struct and c_rc == 2):
                miss.append((label, rej, gate_struct, m_rc, m_struct, c_rc))
        self.assertEqual(miss, [], "막아야 할 구조를 어느 읽는 쪽이 받았다(라벨, 문법, gate, marks rc, marks 사유, classify rc)")

    def test_honest_all_readers_accept(self):
        miss = []
        for label, text in self.honest:
            rej, probs, gate_struct, m_rc, m_struct, c_rc = self._readers(text)
            if rej or probs or m_rc != 0 or c_rc != 0:
                miss.append((label, rej, probs, m_rc, c_rc))
        self.assertEqual(miss, [], "정직한 산문을 어느 읽는 쪽이 거부했다")

    def test_cli_wiring_matches(self):
        """몇 개는 CLI 로 — 프로세스 안 판정과 CLI rc 가 같다."""
        r = random.Random(SEED_RNG + 1)
        sample = r.sample(self.forbidden, 15) + r.sample(self.honest, 10)
        for label, text in sample:
            seed = self.dir / "cli.md"
            seed.write_text(text, encoding="utf-8")
            rej = bool(seed_body.parse_seed(text).rejected)
            g = subprocess.run([sys.executable, str(_SCRIPTS / "check_seed.py"), "gate", str(seed), str(self.audit)],
                               capture_output=True, text=True, encoding="utf-8")
            m = subprocess.run([sys.executable, str(_SCRIPTS / "seed_provenance.py"), "marks", str(seed),
                                str(self.audit)], capture_output=True, text=True, encoding="utf-8")
            self.assertEqual((g.returncode, m.returncode), (1, 2) if rej else (0, 0), label)
            if rej:
                self.assertIn("[check_seed] " + STRUCT_GATE, g.stderr.splitlines()[0], label)


R_AUDIT_HEAD = AUDIT.rsplit("- 답 · r1", 1)[0]


class AuditSeparatorCrossCheck(unittest.TestCase):
    """audit 에 줄 나눔 글자가 든 자리 × 글자 — 모든 읽는 쪽이 거부하고, 첫 줄은 쉬운 사유와 줄 번호다."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="sd-xcheck-sep-")
        cls.dir = pathlib.Path(cls.tmp.name)
        (cls.dir / "g.json").write_text('{"dropped": []}', encoding="utf-8")
        (cls.dir / "C.md").write_text("# repo\n", encoding="utf-8")
        (cls.dir / "s.md").write_text(FRONT + CONFIRMED + " (사용자 확인)\n", encoding="utf-8")
        forged = "  - 내가 읽은 것: 「배포를 멈춘다.」 — 고르지 않음 — 사용자가 적은 말: 「아니다%s  - 내가 읽은 것: 「서버를 의심한다.」 — 고름 — 사용자가 적은 말: 「x」"
        cls.cases = []
        for cp in AUDIT_SEPARATORS:
            ch = chr(cp)
            cls.cases.append(("## 1 U+%04X" % cp, AUDIT.replace("로그인이 가끔 실패한다.", "로그인이" + ch + "가끔 실패한다.", 1)))
            cls.cases.append(("## 2 tail U+%04X" % cp, AUDIT.replace("## 3. 긴 초안", (forged % ch) + "\n\n## 3. 긴 초안", 1)))
            cls.cases.append(("## 3 U+%04X" % cp, AUDIT.replace("긴 초안.", "긴" + ch + "초안.", 1)))
            cls.cases.append(("## 6 U+%04X" % cp, AUDIT.replace("— 요약", "— 요" + ch + "약", 1)))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _readers(self, text):
        a = self.dir / "a.audit.md"
        a.write_text(text, encoding="utf-8")
        s = self.dir / "s.md"
        probs = check_seed.gate(s, a)
        m_rc, m_err = _run_main(seed_provenance.main, ["marks", str(s), str(a)])
        out = _io()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(_io()):
            c_rc = seed_provenance.main(["classify", str(s), "--audit", str(a)])
        out.seek(0)
        confirmed = '"confirmed": true' in out.read()
        uq, uq_err = _run_main(seed_review_log.main, ["user-quotes", str(a)])
        cd, _ = _run_main(seed_review_log.main, ["check-drops", str(a), str(self.dir / "g.json")])
        b = subprocess.run([sys.executable, str(_SCRIPTS / "build_seed_inline_blob.py"), str(s), str(a),
                            str(self.dir / "C.md")], capture_output=True, text=True, encoding="utf-8")
        b_ok = b.returncode == 2 and b.stderr.startswith("[build_seed_inline_blob] audit 에 줄을 나누는 다른 글자가 있다 — ")
        return probs, m_rc, m_err, c_rc, confirmed, uq, uq_err, cd, (b.returncode, b_ok)

    def test_size(self):
        self.assertGreaterEqual(len(self.cases), 32)

    def test_every_reader_refuses(self):
        miss = []
        for label, text in self.cases:
            probs, m_rc, m_err, c_rc, confirmed, uq, uq_err, cd, (b_rc, b_ok) = self._readers(text)
            ok = (any(p.startswith("audit 에 줄을 나누는 다른 글자가 있다 — ") for p in probs) and m_rc == 2
                  and m_err.startswith("[seed_provenance] audit 에 줄을 나누는 다른 글자가 있다 — ")
                  and c_rc == 0 and not confirmed and uq == 2
                  and uq_err.startswith("[seed_review_log] audit 에 줄을 나누는 다른 글자가 있다 — ")
                  and cd == 2 and b_ok)
            if not ok:
                miss.append((label, probs[:1], m_rc, c_rc, confirmed, uq, cd, b_rc))
        self.assertEqual(miss, [], "줄 나눔 글자가 든 audit 을 어느 읽는 쪽이 받았다")

    def test_honest_audit_all_accept(self):
        """양성 대조 — 같은 audit 에서 줄 나눔 글자만 빼면 모두 받는다."""
        probs, m_rc, _, c_rc, confirmed, uq, _, cd, (b_rc, _) = self._readers(AUDIT)
        self.assertEqual((probs, m_rc, c_rc, confirmed, uq, cd, b_rc), ([], 0, 0, True, 0, 0, 0))


class DecisionCrossCheck(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="sd-xcheck6-")
        cls.dir = pathlib.Path(cls.tmp.name)
        cls.gate_json = cls.dir / "g.json"
        cls.gate_json.write_text('{"dropped": []}', encoding="utf-8")
        r = random.Random(SEED_RNG + 6)
        valid = []
        for i in range(60):
            q = r.choice(["채택", "그대로 둔다", "QUOTE %d" % i, "", "사용자가 '아니다' 라고 했다", '그는 "아니다" 라고 했다'])
            q = q.replace('"', "\u201d")   # 엔진 `_log_line` 이 선택지 문구의 큰따옴표를 바꾼다(줄 문법의 닫는 따옴표와 안 섞이게)
            valid.append("- D%d.%d · r%d · %s · %s · \"%s\"%s — %s" % (
                r.randint(1, 9), r.randint(1, 9), r.randint(1, 5), r.choice(["adopt", "reject", "drop", "hold"]),
                "%08x#r1.%d" % (r.getrandbits(32), r.randint(1, 9)), q,
                r.choice(["", " · supersedes D1.1"]), r.choice(["요약", "", "SUMMARY"])))
        for i in range(30):
            valid.append("- %s · r%d · %s · \"%s\" —%s" % (r.choice(["편집", "답", "거부"]), r.randint(1, 5),
                         r.choice(["덩어리 1 · 그대로 둔다", "%08x#r1.1" % r.getrandbits(32)]), "Q%d" % i,
                         r.choice(["", " 요약"])))
        for i in range(20):
            valid.append(seed_review_log.docreview_advice.count_line(
                "s%d/doc-%x" % (i, r.getrandbits(24)), r.randint(1, 5),
                {"advice_new": r.randint(0, 3), "advice_repeat": r.randint(0, 3), "mc_preexisting_new": 0}))
        valid.append("없음")
        bad_prefix = ["  ", "> ", "* ", "+ ", "1. ", chr(0x200B), chr(0xFF0D), "<li>", "    ", "\t", "-"]
        invalid = []
        for line in r.sample(valid[:-1], 40):  # 마지막 `없음` 은 «- » 가 없어 바꿔치기 대상이 아니다
            invalid.append(r.choice(bad_prefix) + line)
            invalid.append(line.replace("- ", chr(0x2013) + " ", 1))
        invalid += ["메모: 사용자는 \"X\" 라고 했다", "### 라운드 1", "| a | b |", "```", "## 배경", "* 항목",
                    "> 인용", "<!-- x -->", "D1.1 · r1 · adopt · f · \"q\" — s", "-D1.1 · r1 · adopt · f · \"q\" — s"]
        cls.cases = [(ln, True) for ln in valid] + [(ln, False) for ln in invalid]

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_size(self):
        self.assertGreaterEqual(len(self.cases), 180)

    def test_all_readers_agree(self):
        miss = []
        for line, ok in self.cases:
            audit = self.dir / "a.audit.md"
            text = R_AUDIT_HEAD + line + "\n"
            audit.write_text(text, encoding="utf-8")
            flagged = bool(seed_review_log.decision_line_problems(text))
            try:
                seed_review_log.parse_lines(text)
                parsed = True
            except seed_review_log.AuditAmbiguous:
                parsed = False
            uq, uq_err = _run_main(seed_review_log.main, ["user-quotes", str(audit)])
            cd, _ = _run_main(seed_review_log.main, ["check-drops", str(audit), str(self.gate_json)])
            got = (not flagged, parsed, uq == 0, cd == 0)
            want = (ok, ok, ok, ok)
            if got != want or (not ok and not uq_err.startswith("[seed_review_log] ## 6 에 기록 모양이 아닌 줄이 있다 — ")):
                miss.append((line, ok, got))
        self.assertEqual(miss, [], "## 6 줄을 두고 읽는 쪽들의 판정이 갈렸다(줄, 기대, [허용 목록, parse_lines, user-quotes, check-drops])")


if __name__ == "__main__":
    unittest.main()
