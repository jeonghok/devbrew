import re
import unittest
from pathlib import Path

SKILL = Path(__file__).resolve().parents[1] / "skills" / "auditing-plugins" / "SKILL.md"
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
    # blind codex (P11). 2026-08-09 codex 통일 1단계에서 산문 `codex exec -s read-only`를
    # 리터럴 게이트로 바꿨다. `-s read-only`의 집행 지점은 이제 러너
    # (`scripts/run_audit_codex_reviewer.sh`)이고, 그 축은 문서 문자열이 아니라 **실행 관측**으로
    # 잰다 — `test_run_audit_codex_reviewer.py::test_argv_carries_contract_flags_and_dash`가
    # 실제 호출의 argv에서 `-s` 다음 값이 `read-only`임을 확인한다(문자열 grep보다 강하다).
    # 여기서 pin하는 것은 "SKILL이 그 러너를 게이트 안에서 부른다"는 사실이다.
    "codex-gate:begin runner=run_audit_codex_reviewer.sh",
    "자기서술은 감사 material이지 verdict 프레임이 아니다",   # AC-8b redaction (C17)
    "캐시 갱신 + 세션 재시작",                               # GC8
    # H (/qg 2026-07-20 round-2): step-1 --out은 step-6이 검증하는 canonical 경로에 pin돼야 한다
    # (placeholder tmp 경로면 step-6 --artifacts가 파일을 못 찾아 깨진다).
    "--out docs/audits/<date>-<target>-audit-data.json",
    # H: Workflow journal을 canonical 원장 파일로 persist (README/CLAUDE.md §Audits + render 포인터의 실체).
    "audit-journal.jsonl",
    # H R5 (codex re-verify): raw transcript journal 커밋 전 P21 secret 스캔 필수 (자격증명 유출 방지).
    "P21 secret 스캔",
]


class TestSkillOrchestration(unittest.TestCase):
    def test_all_invariants_present(self):
        body = SKILL.read_text(encoding="utf-8")
        for inv in INVARIANTS:
            self.assertIn(inv, body, f"SKILL.md missing load-bearing invariant: {inv}")

    def test_cost_class_high_in_frontmatter(self):
        fm = SKILL.read_text(encoding="utf-8").split("---")[1]
        self.assertIn("cost_class: high", fm)

    def test_journal_acquired_before_assembly(self):  # H R4 (codex re-verify)
        # journal 확보가 assemble/render 뒤에 오면, journal 미획득을 degraded[]에 넣어 배너에 반영할 수
        # 없다(이미 렌더됨). 원장(journal) 확보 스텝이 assemble --out(post-1 조립)보다 **앞서야** 한다.
        body = SKILL.read_text(encoding="utf-8")
        j = body.find("audit-journal.jsonl")
        a = body.find("--out docs/audits/<date>-<target>-audit-data.json")
        self.assertNotEqual(j, -1, "journal persist 스텝 부재")
        self.assertNotEqual(a, -1, "assemble --out canonical 경로 부재")
        self.assertLess(j, a, "journal 확보가 assemble 뒤에 옴 — 미획득 degrade가 배너에 못 실린다 (R4)")

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
