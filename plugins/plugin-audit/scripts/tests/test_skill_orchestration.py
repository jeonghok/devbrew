import re
import unittest
from pathlib import Path

SKILL = Path(__file__).resolve().parents[2] / "skills" / "auditing-plugins" / "SKILL.md"
# 버그 형태: `--artifacts docs/audits/` 뒤에 공백/개행 — 디렉토리를 그대로 넘기면
# validate-audit-data.py가 `read_text()`+`json.loads()`에서 IsADirectoryError로 죽는다 (review fix 1).
_BUGGY_ARTIFACTS_DIR_FORM = re.compile(r"--artifacts docs/audits/\s")
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
    # H (/qg 2026-07-20 round-2): step-1 --out은 step-6이 검증하는 canonical 경로에 pin돼야 한다
    # (placeholder tmp 경로면 step-6 --artifacts가 파일을 못 찾아 깨진다).
    "--out docs/audits/<date>-<target>-audit-data.json",
    # H: Workflow journal을 canonical 원장 파일로 persist (README/CLAUDE.md §Audits + render 포인터의 실체).
    "audit-journal.jsonl",
]


class TestSkillOrchestration(unittest.TestCase):
    def test_all_invariants_present(self):
        body = SKILL.read_text(encoding="utf-8")
        for inv in INVARIANTS:
            self.assertIn(inv, body, f"SKILL.md missing load-bearing invariant: {inv}")

    def test_cost_class_high_in_frontmatter(self):
        fm = SKILL.read_text(encoding="utf-8").split("---")[1]
        self.assertIn("cost_class: high", fm)

    def test_validate_artifacts_invocation_is_not_bare_directory(self):
        # review fix 1 regression lock: `--artifacts docs/audits/` (bare directory, immediately
        # followed by whitespace/newline) crashes validate-audit-data.py with IsADirectoryError —
        # the real contract points --artifacts at the audit-data JSON file + passes --report.
        body = SKILL.read_text(encoding="utf-8")
        self.assertIsNone(
            _BUGGY_ARTIFACTS_DIR_FORM.search(body),
            "SKILL.md still tells the orchestrator to call "
            "`validate-audit-data.py --artifacts docs/audits/` (bare directory) — this crashes "
            "with IsADirectoryError; --artifacts must point at the audit-data JSON file.",
        )
        self.assertIn(
            "--report",
            body,
            "SKILL.md's corrected --artifacts invocation must also pass --report "
            "(the rendered .md), per validate-audit-data.py's real CLI contract.",
        )


if __name__ == "__main__":
    unittest.main()
