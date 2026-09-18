import subprocess, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts" / "check-law2.py"

GOOD_WF = (
    "export const meta = { name: 'x', description: 'd', phases: [] }\n"
    "const auditor = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:plugin-auditor'})\n"
    "const refuter = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:audit-refuter'})\n"
    "return { findings: [] }\n"
)
FM_GOOD = "---\nname: plugin-auditor\ntools: Read, Grep, Glob, WebSearch, WebFetch\n---\nbody\n"
FM_GOOD_REFUTER = "---\nname: audit-refuter\ntools: Read, Grep, Glob, WebSearch, WebFetch\n---\nbody\n"
# frontmatter에 tools: 없음, 본문에만 있음 (런타임은 기본 쓰기 도구 부여 → Law 2 구멍)
FM_TOOLS_IN_BODY = "---\nname: plugin-auditor\nmodel: inherit\n---\ntools: Read, Grep, Glob\n"


def run_law2(script_path, agents_dir):
    r = subprocess.run(
        [sys.executable, str(SCRIPT), str(script_path), "--agents-dir", str(agents_dir)],
        capture_output=True, text=True, cwd=str(REPO),
    )
    return r.returncode, r.stderr


class TestFrontmatterScoped(unittest.TestCase):
    def test_tools_only_in_body_is_red(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "wf.js").write_text(GOOD_WF, encoding="utf-8")
            ag = d / "agents"; ag.mkdir()
            (ag / "plugin-auditor.md").write_text(FM_TOOLS_IN_BODY, encoding="utf-8")
            (ag / "audit-refuter.md").write_text(FM_GOOD_REFUTER, encoding="utf-8")
            rc, err = run_law2(d / "wf.js", ag)
            self.assertEqual(rc, 1, f"본문 tools:가 frontmatter로 오인돼 통과했다:\n{err}")

    def test_tools_in_frontmatter_is_green(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "wf.js").write_text(GOOD_WF, encoding="utf-8")
            ag = d / "agents"; ag.mkdir()
            (ag / "plugin-auditor.md").write_text(FM_GOOD, encoding="utf-8")
            (ag / "audit-refuter.md").write_text(FM_GOOD_REFUTER, encoding="utf-8")
            rc, err = run_law2(d / "wf.js", ag)
            self.assertEqual(rc, 0, f"정상 frontmatter tools:가 RED:\n{err}")

    def test_real_workflow_is_green(self):
        # 커밋된 실제 audit-workflow.js + 실제 agents 디렉토리 (회귀 락)
        rc, err = run_law2(REPO / "scripts" / "audit-workflow.js", REPO / "agents")
        self.assertEqual(rc, 0, f"실제 workflow가 Law2 게이트에서 RED:\n{err}")


class TestSmokeMode(unittest.TestCase):
    def test_real_smoke_workflow_green(self):
        r = subprocess.run(
            [sys.executable, str(SCRIPT), str(REPO / "scripts" / "smoke-workflow.js"),
             "--mode", "smoke", "--agents-dir", str(REPO / "agents")],
            capture_output=True, text=True, cwd=str(REPO))
        self.assertEqual(r.returncode, 0, r.stderr)


class TestDefaultAgentsDir(unittest.TestCase):
    """`--agents-dir` 를 안 주면 스크립트 옆 `agents/` 를 본다 — cwd 가 아니다(설계 AC11)."""

    def run_default(self, cwd):
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(REPO / "scripts" / "audit-workflow.js")],
            capture_output=True, text=True, cwd=str(cwd))

    def test_default_resolves_without_repo_cwd(self):
        # cwd 에 plugins/plugin-audit/ 이 없어도 설치본(스크립트 옆) agents 로 돈다.
        with tempfile.TemporaryDirectory() as d:
            r = self.run_default(d)
            self.assertEqual(r.returncode, 0, f"cwd 밖에서 기본 agents 를 못 찾았다:\n{r.stderr}")

    def test_default_ignores_cwd_copy(self):
        # cwd 에 쓰기 도구를 가진 가짜 agents 사본이 있어도 기본값은 그것을 보지 않는다.
        with tempfile.TemporaryDirectory() as d:
            ag = Path(d) / "plugins" / "plugin-audit" / "agents"
            ag.mkdir(parents=True)
            (ag / "plugin-auditor.md").write_text(
                "---\nname: plugin-auditor\ntools: Read, Write, Bash\n---\nbody\n", encoding="utf-8")
            (ag / "audit-refuter.md").write_text(FM_GOOD_REFUTER, encoding="utf-8")
            r = self.run_default(d)
            self.assertEqual(r.returncode, 0, f"기본값이 cwd 의 agents 사본을 읽었다:\n{r.stderr}")


if __name__ == "__main__":
    unittest.main()
