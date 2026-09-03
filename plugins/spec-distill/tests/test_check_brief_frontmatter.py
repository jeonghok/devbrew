"""frontmatter_errors() 의 축별 판정. Run: python3 -m unittest.

파일 픽스처를 쓰지 않는다 — 이 함수는 순수 함수이고, interview-brief-*.md
74건과 함께 드리프트하는 부채를 새로 만들 이유가 없다.
"""
from __future__ import annotations
import importlib.util
import sys
import unittest
from pathlib import Path

# check_brief.py 는 :66 에서 `import section6` 를 한다(같은 scripts/ 디렉토리).
# spec_from_file_location 은 그 디렉토리를 sys.path 에 넣어주지 않으므로 직접 넣는다 —
# 안 넣으면 ModuleNotFoundError 로 이 파일이 통째로 collection 에서 죽는다.
_SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

_SPEC = importlib.util.spec_from_file_location("check_brief", _SCRIPTS / "check_brief.py")
check_brief = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(check_brief)

VALID = """---
type: interview-brief
next_phase: superpowers:brainstorming
audit_file: docs/superpowers/interview/x.audit.md
user_sourced_items:
  - id: S1
---
"""


def errs(text: str) -> list[str]:
    return check_brief.frontmatter_errors(text)


class NextPhaseNotAdjudicated(unittest.TestCase):
    """B4 · MU10 — 게이트가 next_phase 값을 판정하지 않는다."""

    def test_baseline_valid_frontmatter_has_no_errors(self):
        """양성 증인 — 이 픽스처가 애초에 통과한다 (아래 단언들이 공허하지 않다)."""
        self.assertEqual(errs(VALID), [])

    def test_missing_next_phase_is_not_an_error(self):
        text = VALID.replace("next_phase: superpowers:brainstorming\n", "")
        self.assertEqual(
            [e for e in errs(text) if "next_phase" in e], [],
            "next_phase 부재가 여전히 오류로 잡힌다")

    def test_other_next_phase_value_is_not_an_error(self):
        text = VALID.replace("superpowers:brainstorming", "anything:at-all")
        self.assertEqual(
            [e for e in errs(text) if "next_phase" in e], [],
            "next_phase 의 다른 값이 여전히 오류로 잡힌다")


class OtherAxesStillBite(unittest.TestCase):
    """MU11 — next_phase 를 지우면서 게이트 전체를 무력화하지 않았다."""

    def test_broken_type_still_fails(self):
        text = VALID.replace("type: interview-brief", "type: something-else")
        self.assertIn("type != interview-brief", errs(text))

    def test_missing_user_sourced_items_still_fails(self):
        text = VALID.replace("user_sourced_items:\n  - id: S1\n", "")
        self.assertIn("user_sourced_items key absent", errs(text))

    def test_missing_audit_file_still_fails(self):
        text = VALID.replace(
            "audit_file: docs/superpowers/interview/x.audit.md\n", "")
        self.assertTrue([e for e in errs(text) if "audit_file" in e],
                        "audit_file 축이 죽었다")

    def test_absent_frontmatter_still_fails(self):
        self.assertEqual(errs("no frontmatter here"), ["frontmatter absent"])


if __name__ == "__main__":
    unittest.main()
