# -*- coding: utf-8 -*-
"""우리 허용 문법(brief_body · seed_body)을 실제 CommonMark 파서(markdown-it-py)와 교차 확인한다(AC19).

두 방향을 잰다.
  - 우리가 앵커 · 결정 줄 · 절 머리로 받은 줄은 파서도 같은 구조(최상위 목록 항목 · h2)로 본다.
  - 파서가 그 구조로 보는 줄은 우리가 받았거나 거부했다. 받지도 거부하지도 않았으면 진짜 어긋남이다.
파서가 없으면 통과가 아니라 「확인 못 함」 — rc 3.
눈에 안 보이는 글자는 소스에 날 글자로 쓰지 않고 chr() 로만 쓴다.
"""
import re
import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
try:
    from markdown_it import MarkdownIt
except ImportError:
    print("확인 못 함(markdown-it-py 없음) — uv sync 로 개발 의존을 받은 뒤 다시 돌린다")
    sys.exit(3)
import brief_body as B  # noqa: E402
import seed_body as S  # noqa: E402

MD = MarkdownIt("commonmark")
REPO = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], cwd=str(HERE), text=True).strip())
DASH = ("-",)
ANY_BULLET = ("-", "*", "+")
NBSP, IDEO, CYR_ZE, CYR_O = chr(0xA0), chr(0x3000), chr(0x417), chr(0x41E)


def norm(s):
    return s.replace("\r\n", "\n").replace("\r", "\n")


def cmp_key(s):
    """파서는 줄 끝 CR 을 줄 나눔으로 읽으므로 줄 글자를 비교할 때 뒤 줄 나눔을 뗀다."""
    return norm(s).rstrip("\n")


def src_lines(doc):
    return norm(doc).split("\n")


def parser_items(doc, markups):
    """최상위(목록 깊이 1 · 인용 밖) 글머리 목록 항목이 시작하는 줄 글자 집합."""
    lines = src_lines(doc)
    out, depth = set(), 0
    for t in MD.parse(norm(doc)):
        if t.type in ("bullet_list_open", "ordered_list_open", "blockquote_open"):
            depth += 1
        elif t.type in ("bullet_list_close", "ordered_list_close", "blockquote_close"):
            depth -= 1
        elif t.type == "list_item_open" and depth == 1 and t.markup in markups and t.map:
            out.add(lines[t.map[0]])
    return out


def parser_h2(doc):
    """파서가 h2 제목으로 읽는 줄 글자 집합(setext 은 글줄과 밑줄 둘 다)."""
    lines = src_lines(doc)
    out = set()
    for t in MD.parse(norm(doc)):
        if t.type == "heading_open" and t.tag == "h2" and t.map:
            out.update(lines[t.map[0]:t.map[1]])
    return out


def make_brief(extra):
    parts = []
    for num, title in B.SECTIONS:
        parts.append("## %s. %s\n%s\n" % (num, title, extra.get(num, "본문")))
    return "\n".join(parts)


def verdict_line(texts_ok, texts_bad, target):
    t = cmp_key(target)
    if t in {cmp_key(x) for x in texts_ok}:
        return "accept"
    if t in {cmp_key(x) for x in texts_bad}:
        return "refuse"
    return "silent"


def anchor_verdict(lines6, key, other=None):
    doc = make_brief(dict(other or {}, **{"6": "\n".join(lines6)}))
    sec = B.section_text(doc, "6")
    lines = B.split_lines(sec)
    ok, bad = B.anchor_lines(sec)
    ours = verdict_line([lines[n - 1] for n, _s, _b in ok], [lines[n - 1] for n, _r in bad], lines6[key])
    sees = cmp_key(lines6[key]) in parser_items(doc, DASH)
    return ours, sees


def head_verdict(lines6, key):
    doc = make_brief({"6": "\n".join(lines6)})
    target = lines6[key]
    body_lines = B.split_lines(B.body_text(doc))
    heads = [ln for ln in body_lines if B.is_section_head(ln) is not None]
    refused = [ln for ln, _why in B.head_problems(doc)]
    ours = verdict_line([target] if target in heads else [], refused, target)
    sees = cmp_key(target) in parser_h2(doc)
    return ours, sees


def decision_verdict(line):
    doc = make_brief({"3": line})
    sec = B.section_text(doc, "3")
    lines = B.split_lines(sec)
    acc, rej = B.decision_entries(sec)
    ours = verdict_line([ln for _oq, ln in acc if B.decision_shaped(ln)], [lines[n - 1] for n, _r in rej], line)
    sees = cmp_key(line) in parser_items(doc, ANY_BULLET)
    return ours, sees


def disagreement(ours, sees):
    """우리가 받았는데 파서는 그 구조가 아니다 · 파서는 구조로 보는데 우리는 받지도 거부하지도 않았다."""
    return (ours == "accept" and not sees) or (ours == "silent" and sees)


ANCHOR9 = "- **S9** 「본문」"

# (이름, §6 줄들, 대상 줄 번호, 다른 절 본문) — 대상 줄이 앵커 꼴 구조인지 우리와 파서가 같은 답을 내야 한다.
ANCHOR_CASES = [
    ("정상 앵커(양성 대조)", [ANCHOR9], 0, None),
    ("날 HTML", ["- <b>S9</b> 「본문」"], 0, None),
    ("이스케이프한 강조", ["- *\\*S5*\\*"], 0, None),
    ("쪼갠 강조", ["- **S**9"], 0, None),
    ("표", ["| a | b |", "|---|---|", "| S9 | 「x」 |"], 2, None),
    ("물결 펜스 안", ["~~~", ANCHOR9, "~~~"], 1, None),
    ("정보 문자열에 백틱이 든 펜스", ["```a``` x", ANCHOR9], 1, None),
    ("정보 문자열에 백틱이 든 펜스 + 뒤 실제 펜스", ["```a``` x", ANCHOR9], 1, {"7": "```\n코드\n```"}),
    ("setext 제목", ["**S9** 「x」", "==="], 0, None),
    ("들여 쓴 앵커", ["  - **S3** 「들임」"], 0, None),
    ("NBSP 앵커", [NBSP + "- **S3** 「NBSP」"], 0, None),
    ("전각 공백 앵커", [IDEO + "- **S3** 「전각」"], 0, None),
    ("별표 앵커", ["* **S3** 「별표」"], 0, None),
    ("번호 앵커", ["1. **S3** 「번호」"], 0, None),
    ("인용 앵커", ["> - **S3** 「인용」"], 0, None),
    ("코드 블록 앵커", ["    - **S3** 「코드」"], 0, None),
    ("열 0 닮은 글자 머리(양성 대조)", ["- **S" + CYR_ZE + "** x"], 0, None),
    ("두 칸 들인 닮은 글자 머리", ["  - **S" + CYR_ZE + "**"], 0, None),
    ("번호 닮은 글자 머리", ["1. **S" + CYR_ZE + "**"], 0, None),
    ("인용 닮은 글자 머리", ["> - **S" + CYR_ZE + "**"], 0, None),
]

HEAD_CASES = [
    ("정상 머리(양성 대조)", ["## 6. 사용자 원문"], 0),
    ("네 칸 들인 머리", ["    ## 0. 한눈에"], 0),
    ("한 칸 들인 머리", [" ## 0. 한눈에"], 0),
    ("세 칸 들인 머리", ["   ## 0. 한눈에"], 0),
    ("빈 h2", ["##"], 0),
    ("빈 h2 + CR", ["##\r"], 0),
    ("setext h2", ["7\\. Next Action", "-----"], 0),
    ("setext h1(h2 아님)", ["7\\. Next Action", "====="], 0),
]

DECISION_CASES = [
    ("정상 결정 줄(양성 대조)", "- OQ1 [해결 ⟨S2⟩] 결정"),
    ("날 HTML", "- <b>OQ1</b> [해결 ⟨S2⟩]"),
    ("이스케이프한 강조", "- *\\*OQ1*\\* [해결 ⟨S2⟩]"),
    ("쪼갠 강조", "- **O**Q1 [해결 ⟨S2⟩]"),
    ("표", "| OQ1 | [해결 ⟨S2⟩] |"),
    ("두 칸 들인 불릿", "  - OQ1 [해결 ⟨S2⟩]"),
    ("번호 목록", "1. OQ1 [해결 ⟨S2⟩]"),
    ("인용 불릿", "> - OQ1 [해결 ⟨S2⟩]"),
    ("키릴 대문자 오 머리 + 표시", "- " + CYR_O + "Q1 [해결 ⟨S2⟩]"),
    ("키릴 대문자 오 머리, 표시 없음", "- " + CYR_O + "Q1 결정 내용"),
]


class CrossCheckClasses(unittest.TestCase):
    def test_anchor_classes(self):
        for name, lines, key, other in ANCHOR_CASES:
            with self.subTest(name):
                ours, sees = anchor_verdict(lines, key, other)
                self.assertFalse(
                    disagreement(ours, sees),
                    "%s: %r — 우리=%s · 파서=%s" % (name, lines[key], ours, "최상위 «-» 항목" if sees else "그 구조 아님"))

    def test_anchor_positive_control(self):
        self.assertEqual(anchor_verdict([ANCHOR9], 0), ("accept", True))
        self.assertEqual(anchor_verdict(["- **S" + CYR_ZE + "** x"], 0), ("refuse", True))

    def test_head_classes(self):
        for name, lines, key in HEAD_CASES:
            with self.subTest(name):
                ours, sees = head_verdict(lines, key)
                self.assertFalse(
                    disagreement(ours, sees),
                    "%s: %r — 우리=%s · 파서=%s" % (name, lines[key], ours, "h2 제목" if sees else "h2 아님"))

    def test_head_positive_control(self):
        self.assertEqual(head_verdict(["## 6. 사용자 원문"], 0), ("accept", True))
        self.assertEqual(head_verdict([" ## 0. 한눈에"], 0), ("refuse", True))

    def test_decision_classes(self):
        for name, line in DECISION_CASES:
            with self.subTest(name):
                ours, sees = decision_verdict(line)
                self.assertFalse(
                    disagreement(ours, sees),
                    "%s: %r — 우리=%s · 파서=%s" % (name, line, ours, "최상위 목록 항목" if sees else "그 구조 아님"))

    def test_decision_positive_control(self):
        self.assertEqual(decision_verdict("- OQ1 [해결 ⟨S2⟩] 결정"), ("accept", True))


def git_files(pattern):
    return subprocess.check_output(["git", "ls-files", pattern], cwd=str(REPO), text=True).split("\n")[:-1]


_COL0 = re.compile(r"^[-*][ \t]")


class RealBriefs(unittest.TestCase):
    def test_real_briefs(self):
        paths = git_files("docs/superpowers/interview/*-interview.md")
        self.assertGreater(len(paths), 0, "실제 brief 가 하나도 없다 — 코퍼스가 비면 이 락은 공허하다")
        for p in paths:
            with self.subTest(p):
                text = (REPO / p).read_text(encoding="utf-8")
                m = B.FRONTMATTER_RE.match(text)
                doc = text[m.end():] if m else text
                dash_items, any_items = parser_items(doc, DASH), parser_items(doc, ANY_BULLET)
                sec6 = B.section_text(text, "6")
                lines6 = B.split_lines(sec6)
                ok, bad = B.anchor_lines(sec6)
                accepted = {lines6[n - 1] for n, _s, _b in ok}
                self.assertTrue(accepted <= dash_items,
                                "우리가 앵커로 받은 줄을 파서는 최상위 «-» 항목으로 보지 않는다: %s" % sorted(accepted - dash_items))
                refused = {lines6[n - 1] for n, _r in bad}
                silent = {ln for ln in lines6 if ln in dash_items and B._ANCHOR_SHAPED.match(B.fold(ln))} - accepted - refused
                self.assertEqual(silent, set(), "파서는 앵커 꼴 항목으로 보는데 우리는 받지도 거부하지도 않았다")
                for num in ("0", "3"):
                    acc, _rej = B.decision_entries(B.section_text(text, num))
                    got = {ln for _oq, ln in acc if _COL0.match(ln)}
                    self.assertTrue(got <= any_items,
                                    "§%s: 우리가 결정 항목으로 받은 줄을 파서는 최상위 목록 항목으로 보지 않는다: %s"
                                    % (num, sorted(got - any_items)))


SEED_TEMPLATE = REPO / "plugins" / "spec-distill" / "templates" / "interview-seed-template.md"
STRUCT_BLOCKS = {"heading_open", "bullet_list_open", "ordered_list_open", "fence", "code_block", "blockquote_open",
                 "html_block", "hr", "table_open"}
SEED_CASES = [
    ("글머리 목록", "- 항목"), ("별표 목록", "* 항목"), ("더하기 목록", "+ 항목"), ("번호 목록", "1. 항목"),
    ("괄호 번호 목록", "1) 항목"), ("ATX 제목", "# 제목"), ("인용", "> 인용"), ("들여 쓴 코드", "    코드"),
    ("백틱 펜스", "```\n코드\n```"), ("물결 펜스", "~~~\n코드\n~~~"), ("HTML 블록", "<div>x</div>"),
    ("표", "| a | b |\n|---|---|\n| c | d |"), ("가로줄", "---"), ("별표 가로줄", "***"),
    ("setext 밑줄", "제목\n==="), ("setext 대시 밑줄", "제목\n---"),
    ("인라인 링크", "앞 [글](x) 뒤"), ("자동 링크", "앞 <https://x.y> 뒤"), ("인라인 HTML", "앞 <b>굵게</b> 뒤"),
    ("한 칸 들인 목록", " - 항목"), ("세 칸 들인 제목", "   # 제목"),
]


def seed_structure_lines(body):
    """파서가 구조로 읽는 본문 줄 — 블록은 시작 줄(setext 은 밑줄 줄), 인라인 구조는 문단의 줄 범위."""
    spans, found = [], set()
    for t in MD.parse(body):
        if t.level == 0 and t.type in STRUCT_BLOCKS and t.map:
            if t.type == "heading_open" and t.markup in ("=", "-"):
                found.add(t.map[1])
            else:
                found.add(t.map[0] + 1)
        elif t.type == "inline" and t.map and any(c.type in ("link_open", "image", "html_inline") for c in t.children):
            spans.append((t.map[0] + 1, t.map[1]))
    return found, spans


class SeedGrammar(unittest.TestCase):
    def check(self, text):
        sp = S.parse_seed(text)
        offset = sp.head.count("\n")
        rejected = {n - offset for n, _why in sp.rejected}
        found, spans = seed_structure_lines(sp.body)
        missing = [ln for ln in sorted(found) if ln not in rejected]
        missing += [a for a, b in spans if not any(a <= r <= b for r in rejected)]
        return missing, rejected

    def test_template_example_is_plain_prose(self):
        m = re.search(r"```markdown\n(.*?)\n```", SEED_TEMPLATE.read_text(encoding="utf-8"), re.S)
        self.assertIsNotNone(m, "seed 템플릿에 예시 펜스가 없다 — 코퍼스가 비면 이 락은 공허하다")
        text = m.group(1) + "\n"
        missing, rejected = self.check(text)
        self.assertEqual((missing, rejected), ([], set()), "템플릿 예시는 우리도 거부하지 않아야 한다")
        self.assertEqual(seed_structure_lines(S.parse_seed(text).body), (set(), []), "템플릿 예시는 파서 눈에도 구조가 없어야 한다")

    def test_structure_classes(self):
        for name, body in SEED_CASES:
            with self.subTest(name):
                text = "---\ntype: interview-seed\n---\n\n문장 하나.\n\n" + body + "\n"
                missing, _rej = self.check(text)
                self.assertEqual(missing, [], "%s: 파서는 구조로 보는데 우리는 거부하지 않은 본문 줄 %r" % (name, body))

    def test_seed_positive_control(self):
        sp = S.parse_seed("---\ntype: interview-seed\n---\n\n문장 하나.\n\n- 항목\n")
        self.assertEqual([n for n, _w in sp.rejected], [7])


FENCE_CORPUS = [
    "```\na\n```\n", "~~~\na\n~~~\n", "```a``` x\n- b\n", "```js\nx\n```\n", "````\n```\n````\n", "```\nx\n````\n",
    "````\nx\n```\n", "```\nx\n``` y\n```\n", "~~~\nx\n```\n~~~\n", "   ```\nx\n   ```\n", "    ```\nx\n    ```\n",
    "```\nunclosed\n", "~~~ a`b\nx\n~~~\n", "``` a`b\nx\n```\n", "```\nx\n ```\n", "```\nx\n```", "~~~\nx\n~~\n",
    "a\n```\nx\n```\nb\n", "```\n```\n- 항목\n",
]


def parser_fence_lines(doc):
    out = set()
    for t in MD.parse(doc):
        if t.type == "fence" and t.level == 0 and t.map:
            out.update(range(t.map[0], t.map[1]))
    return out


def our_fence_lines(doc):
    starts, pos = [], 0
    for ln in doc.split("\n"):
        starts.append(pos)
        pos += len(ln) + 1
    n = doc.count("\n") + (0 if doc.endswith("\n") else 1)
    spans = [m.span() for m in B.FENCE_RE.finditer(doc)]
    return {i for i, st in enumerate(starts) if i < n and any(a <= st < b for a, b in spans)}


SETEXT_CORPUS = [
    "a\n---\n", "a\n===\n", "a\n\n---\n", "- a\n---\n", "- a\n  ---\n", "> a\n---\n", "> a\n> ---\n", "a\nb\n---\n",
    "# a\n---\n", "---\n---\n", "a\n -\n", "a\n----   \n", "    code\n---\n", "<div>\n---\n", "a\n    ---\n",
    "* * *\n---\n", "a\n\n===\n", "1. a\n---\n", "a\n=\n", "> a\nb\n---\n", "- a\nb\n---\n",
]


def parser_setext_lines(doc):
    return {t.map[1] - 2 for t in MD.parse(doc) if t.type == "heading_open" and t.level == 0 and t.markup in ("=", "-") and t.map}


def our_setext_lines(doc):
    lines = doc.split("\n")
    wanted = {ln for ln, _why in B.setext_problems(doc)}
    return {i for i, ln in enumerate(lines) if ln in wanted and i + 1 < len(lines)} if wanted else set()


class FenceAndSetextAgreement(unittest.TestCase):
    def test_fence_implementation_agrees_with_parser(self):
        for doc in FENCE_CORPUS:
            with self.subTest(doc):
                self.assertEqual(our_fence_lines(doc), parser_fence_lines(doc), repr(doc))

    def test_setext_rule_agrees_with_parser_at_top_level(self):
        for doc in SETEXT_CORPUS:
            with self.subTest(doc):
                body = "---\nname: x\n---\n" + doc   # frontmatter 뒤 — 본문만 읽는다
                self.assertEqual(sorted(ln for ln, _w in B.setext_problems(body)),
                                 sorted(doc.split("\n")[i] for i in parser_setext_lines(doc)), repr(doc))
