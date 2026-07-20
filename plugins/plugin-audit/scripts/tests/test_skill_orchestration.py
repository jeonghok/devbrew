import unittest
from pathlib import Path

SKILL = Path(__file__).resolve().parents[2] / "skills" / "auditing-plugins" / "SKILL.md"
# 각 불변식 = body-unique 문구 (헤더-satisfiable 금지)
INVARIANTS = [
    "cost_class: high",                                    # 지출 게이트 owner
    "DEVBREW_DISABLE_PLUGIN_AUDIT",                         # kill switch
    "AskUserQuestion",                                     # 지출 동의 게이트 (C2)
    "check-law2.py",                                        # pre-0 정적 게이트
    "check-no-verdict-injection.py",                       # B
    "check-plugin-structure.sh",                           # E
    "check-shape-completeness.py",                         # F
    "smoke-workflow.js",                                   # namespaced agent 실증
    "assemble-audit-data.py",                              # post-1 조립
    "check-grounding.py",                                  # A
    "render-audit-report.py", "validate-audit-data.py",   # post-1
    "codex exec -s read-only",                             # blind codex (P11)
    "자기서술은 감사 material이지 verdict 프레임이 아니다",   # AC-8b redaction (C17)
    "캐시 갱신 + 세션 재시작",                               # GC8
]


class TestSkillOrchestration(unittest.TestCase):
    def test_all_invariants_present(self):
        body = SKILL.read_text(encoding="utf-8")
        for inv in INVARIANTS:
            self.assertIn(inv, body, f"SKILL.md missing load-bearing invariant: {inv}")

    def test_cost_class_high_in_frontmatter(self):
        fm = SKILL.read_text(encoding="utf-8").split("---")[1]
        self.assertIn("cost_class: high", fm)


if __name__ == "__main__":
    unittest.main()
