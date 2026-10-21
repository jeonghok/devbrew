"""출하 audit 템플릿의 §2 계수는 게이트의 답을 미리 채우지 않는다 (v0.57.0).

발단: 그 줄의 다른 계수는 전부 `<n>` placeholder 인데 `coverage-mapper` 만 리터럴 통과값
`1` 을 달고 있었다. coverage-mapper 를 한 번도 dispatch 하지 않은 턴이 템플릿을 그대로
채우면 **게이트가 조용히 통과**한다 — 실패도 advisory 도 없고 Step B 에 아무것도 안 뜬다.
spec §2.3 은 *unavailable sentinel* 이 피검자 기록임은 공시하지만, 템플릿이 통과값을
기본으로 나눠 준다는 것은 공시하지 않았다.

**R18 과의 충돌과 그 해소.** R18 은 「산문이 판정을 지지 않게」 하려고 T-TPL 이 출하
템플릿의 **데이터 줄에 실제 숫자**를 요구하게 했다. 두 요구는 같은 출하 파일에서 동시에
성립할 수 없다. 그래서 판정 대상을 옮긴다: 출하 템플릿에는 `<k>` 를 두고, **숫자를 치환한
합성 사본**에 대해 게이트 형태를 단언한다. R18 이 막던 것(산문이 판정을 지는 것)은 여기서
**더 직접** 재진다 — 데이터 불릿을 지운 사본에서 게이트가 여전히 통과하면 red 다.

이 파일은 grep 사본이 아니라 `check_brief.py` 의 **실물** `budget_mapper_failures` 를
불러 쓴다. 재도출한 정규식을 테스트에 복사해 두면 피검자가 바뀌어도 테스트만 계속
green 일 수 있다 — 판정자는 하나여야 한다.
"""
from __future__ import annotations
import importlib.util
import sys
import unittest
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))
_SPEC = importlib.util.spec_from_file_location("check_brief", _SCRIPTS / "check_brief.py")
check_brief = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(check_brief)

TPL = (Path(__file__).resolve().parent.parent / "templates"
       / "interview-audit-template.md")

MAPPER = "coverage-mapper"


def mapper_bullet(text):
    """§2 의 mapper 계수를 담은 **데이터 불릿** 줄. 없으면 None."""
    for ln in text.splitlines():
        st = ln.strip()
        if st[:1] in ("-", "*") and MAPPER in st:
            return ln
    return None


class AuditTemplateGateShape(unittest.TestCase):
    def setUp(self):
        self.text = TPL.read_text(encoding="utf-8")

    def test_corpus_is_actually_read(self):
        """양성 대조 — 템플릿을 못 읽었으면 아래 단언들은 공허하다."""
        self.assertIn("## 2. Budget", self.text, "출하 템플릿에서 §2 Budget 을 못 찾았다")
        self.assertIsNotNone(mapper_bullet(self.text),
                             "§2 에 coverage-mapper 데이터 불릿이 없다 — 락이 겨눌 대상 부재")

    def test_shipped_template_does_not_prefill_the_passing_value(self):
        """출하 템플릿의 mapper 계수는 placeholder 여야 한다 (A3).

        리터럴 숫자를 두면 dispatch 0 회 턴이 그대로 옮겨 적어 게이트가 통과한다.
        """
        bullet = mapper_bullet(self.text)
        after = bullet.split(MAPPER, 1)[1].lstrip()
        self.assertFalse(
            after[:1].isdigit(),
            "출하 템플릿이 coverage-mapper 계수를 숫자로 미리 채웠다 — 게이트가 발화할 수 "
            "없다. placeholder 로 두어라. 문제의 줄: %r" % (bullet,))
        self.assertIn("<k>", after[:4],
                      "mapper 계수 자리에 `<k>` placeholder 가 없다: %r" % (bullet,))

    def test_unfilled_template_is_red_not_silent(self):
        """채우지 않은 템플릿은 통과가 아니라 red 다 — 침묵보다 red."""
        fails, advisories = check_brief.budget_mapper_failures(self.text)
        self.assertTrue(fails,
                        "`<k>` 를 안 채운 템플릿이 게이트를 통과했다 — 산문이 판정을 지고 있다")
        self.assertEqual(advisories, [],
                         "미기입 템플릿이 advisory 로 흘러갔다 — 그건 «측정 불가» 가 아니다")

    def test_filled_copy_passes(self):
        """숫자를 치환한 합성 사본은 통과한다 — 템플릿이 가르치는 형태가 실제로 읽힌다."""
        filled = self.text.replace("%s <k>" % MAPPER, "%s 2" % MAPPER)
        self.assertNotEqual(filled, self.text, "치환이 안 먹었다 — 아래 단언이 공허하다")
        fails, _ = check_brief.budget_mapper_failures(filled)
        self.assertEqual(fails, [],
                         "채운 사본이 red 다 — 템플릿이 게이트가 못 읽는 형태를 가르친다: %r"
                         % (fails,))

    def test_prose_alone_cannot_satisfy_the_gate(self):
        """R18 이 막던 것: 데이터 불릿이 사라지면 **설명 산문**이 판정을 대신 지면 안 된다.

        §2 머리 산문에는 `coverage-mapper 0 (unavailable: <사유>)` 예시가 살아 있다.
        게이트가 불릿에 앵커되어 있지 않으면 그 예시 하나가 통과를 만들어 낸다.
        """
        filled = self.text.replace("%s <k>" % MAPPER, "%s 2" % MAPPER)
        bullet = mapper_bullet(filled)
        self.assertIsNotNone(bullet)
        stripped = "\n".join(ln for ln in filled.splitlines() if ln != bullet)
        self.assertIn(MAPPER, stripped,
                      "산문의 mapper 예시까지 함께 사라졌다 — 이 단언이 공허하다")
        fails, advisories = check_brief.budget_mapper_failures(stripped)
        self.assertTrue(
            fails,
            "데이터 불릿을 지웠는데 게이트가 통과했다 — §2 머리 설명 산문이 판정을 지고 "
            "있다(R18 이 막던 것이 다시 열렸다). advisories=%r" % (advisories,))

    def test_saturation_placeholder_is_red(self):
        """출하 템플릿의 포화 줄은 자리표다 — 채우지 않으면 red (침묵보다 red)."""
        self.assertIn("포화 판정 <k>:", self.text, "§2 에 포화 판정 자리표 줄이 없다")
        fails, _ = check_brief.saturation_failures(self.text, set())
        self.assertTrue(fails, "자리표를 안 채운 템플릿이 포화 검사를 통과했다")

    def test_saturation_filled_copy_passes(self):
        filled = self.text.replace(
            next(ln for ln in self.text.splitlines() if ln.startswith("- 포화 판정 <k>:")),
            "- 포화 판정 1: 포화 — 최근 두 조사 새로움 없음")
        fails, adv = check_brief.saturation_failures(filled, set())
        self.assertEqual((fails, adv), ([], []))

    def test_saturation_prose_alone_does_not_satisfy(self):
        """설명 산문은 판정에 참여하지 않는다 — 데이터 불릿을 지운 사본은 red."""
        stripped = "\n".join(ln for ln in self.text.splitlines()
                             if not ln.startswith("- 포화 판정"))
        fails, _ = check_brief.saturation_failures(stripped, set())
        self.assertTrue(fails, "데이터 줄 없이 산문만으로 포화 검사가 통과했다")


    def test_template_source_has_no_version_tail(self):
        """두 인터뷰 템플릿의 frontmatter `source:` 값은 판 꼬리 없이 이름뿐이다."""
        import re
        tdir = TPL.parent
        for name in ("interview-audit-template.md", "interview-brief-template.md"):
            text = (tdir / name).read_text(encoding="utf-8")
            head = text.split("\n---\n", 2)[0] if text.startswith("---") else ""
            vals = [ln.split(":", 1)[1].strip() for ln in head.splitlines()
                    if ln.startswith("source:")]
            self.assertEqual(vals, ["spec-distill pm-interview"], name)
            self.assertIsNone(re.search(r"v\d", vals[0]), name)


if __name__ == "__main__":
    unittest.main()
