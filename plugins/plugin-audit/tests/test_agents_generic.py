import unittest
from pathlib import Path

AGENTS = Path(__file__).resolve().parents[1] / "agents"   # plugins/plugin-audit/agents
SAFE_TOOLS = {"Glob", "Grep", "Read", "WebSearch", "WebFetch"}


def read(name):
    return (AGENTS / name).read_text(encoding="utf-8")


class TestAgentsGeneric(unittest.TestCase):
    def test_no_project_init_literal_in_any_agent(self):
        # 일반화 후 어떤 agent에도 project-init 전용 scope 리터럴이 남으면 안 됨
        for name in ("plugin-auditor.md", "audit-refuter.md", "smoke-probe.md"):
            body = read(name)
            self.assertNotIn("plugins/project-init/**", body, f"{name} pins project-init scope")
            self.assertNotIn("docs/git-workflow/**", body, f"{name} pins project-init doc scope")

    def test_gate_e_uses_target_placeholder(self):
        # audit-refuter Gate E는 <target> 파라미터를 참조해야 한다 (body-unique 문구)
        body = read("audit-refuter.md")
        self.assertIn("Gate E", body)
        self.assertIn("plugins/<target>/**", body)

    def test_all_agents_tools_allowlist(self):
        # frontmatter tools:가 SAFE_TOOLS의 부분집합 (fail-closed)
        for name in ("plugin-auditor.md", "audit-refuter.md", "smoke-probe.md"):
            fm = read(name).split("---")[1]
            line = next(l for l in fm.splitlines() if l.strip().startswith("tools:"))
            tools = {t.strip() for t in line.split(":", 1)[1].split(",")}
            self.assertTrue(tools <= SAFE_TOOLS, f"{name} tools {tools} escape allowlist")
            self.assertNotIn("disallowedTools", fm, f"{name} uses denylist (fail-open in time)")


    def test_auditor_never_drops(self):
        body = read("plugin-auditor.md")
        self.assertNotIn("or drop it", body)
        self.assertNotIn("or drop the gap", body)
        self.assertIn("new_open_questions", body)
        self.assertIn("why_not_gap", body)

    def test_refuter_marks_uncertain_separately(self):
        body = read("audit-refuter.md")
        self.assertNotIn("If you are uncertain, refute.", body)
        self.assertIn("verdict: uncertain", body)
        fm = body.split("---")[1]
        line = next(l for l in fm.splitlines() if l.strip().startswith("tools:"))
        self.assertEqual(line.strip(), "tools: Read, Grep, Glob, WebSearch, WebFetch")

    def test_refuter_unsure_rule_covers_both_schemas(self):
        # 심층검증은 `refuted` boolean 스키마다 — 「uncertain」만 말하면 refuted:false + uncertain 을 고를 수 있다
        body = read("audit-refuter.md")
        self.assertIn("in a `verdict` schema return `uncertain`", body)
        self.assertIn("in a `refuted` boolean schema return `refuted: true` with `uncertain: true`", body)
        self.assertNotIn("If you could not settle it, return `uncertain` — never `survives`.", body)


if __name__ == "__main__":
    unittest.main()
