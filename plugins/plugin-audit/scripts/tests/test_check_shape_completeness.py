import json, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check-shape-completeness.py"
REPO = Path(__file__).resolve().parents[4]        # repo root (plugins/plugin-audit/scripts/tests → parents[4])
CLAUDE_MD = REPO / "CLAUDE.md"

# checklist requirement → CLAUDE.md §Plugin Shape body-unique anchor
ANCHORS = {
    "plugin_json_fields": "필수: `name`, `description`, `version`",
    "readme_principles": '"Principles Instantiated"',
    "changelog_if_v1": "v1.0.0 이상이면 `CHANGELOG.md`",
    "agents_allowlist": "`tools:` allowlist를 선언",
    "skills_cost_class": "모든 skill에 `cost_class` 선언",
    "hooks_killswitch": "모든 훅에 kill switch",
    "deps_declared": "최소 버전이 선언된 의존성",
}


def run(plugin_dir):
    r = subprocess.run([sys.executable, str(SCRIPT), str(plugin_dir), "--repo-root", str(REPO)],
                       capture_output=True, text=True)
    return r, (json.loads(r.stdout) if r.stdout.strip() else {})


def _mk_plugin(d, version="0.1.0", drop_version=False):
    d = Path(d)
    (d / ".claude-plugin").mkdir(parents=True)
    pj = {"name": "myplugin", "description": "x"}
    if not drop_version:
        pj["version"] = version
    (d / ".claude-plugin" / "plugin.json").write_text(json.dumps(pj), encoding="utf-8")
    (d / "README.md").write_text("# myplugin\n## Principles Instantiated\n- Law 1\n", encoding="utf-8")
    return d


class TestShapeCompleteness(unittest.TestCase):
    def test_version_missing_is_gap(self):   # AC-10
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d, drop_version=True)
            r, obj = run(d)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertFalse(gaps["plugin_json_fields"]["present"], "missing version not flagged")

    def test_complete_plugin_no_json_gap(self):
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d)
            r, obj = run(d)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertTrue(gaps["plugin_json_fields"]["present"])

    def test_single_pass_no_loop(self):
        # 결정론부는 shape_gaps를 1회 emit — 각 requirement 정확히 1개
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d)
            r, obj = run(d)
            reqs = [g["requirement"] for g in obj["shape_gaps"]]
            self.assertEqual(len(reqs), len(set(reqs)), "requirement duplicated (loop?)")

    def test_checklist_synced_with_claude_md(self):   # 회귀 락 (C15)
        shape = CLAUDE_MD.read_text(encoding="utf-8").split("## Plugin Shape")[1].split("## Building")[0]
        for req, anchor in ANCHORS.items():
            self.assertIn(anchor, shape, f"checklist '{req}' anchor drifted from CLAUDE.md §Plugin Shape")

    def test_deps_declared_gap_when_cross_plugin_dispatch_without_prereqs(self):
        # cross-plugin dispatch present + no "Prerequisites" section in README → real gap
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d)   # README has no "Prerequisites" section
            agents_dir = Path(d) / "agents"
            agents_dir.mkdir()
            (agents_dir / "x.md").write_text(
                "---\ntools: Read\n---\nDispatch: agentType: 'quality-gates:security-reviewer'\n",
                encoding="utf-8",
            )
            r, obj = run(d)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertFalse(gaps["deps_declared"]["present"],
                              "cross-plugin dispatch without Prerequisites not flagged")

    def test_deps_declared_ok_when_no_cross_plugin_dispatch(self):
        # no cross-plugin dispatch at all → nothing to declare, not a gap
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d)
            r, obj = run(d)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertTrue(gaps["deps_declared"]["present"])

    def test_malformed_plugin_json_is_gap_not_crash(self):
        # C6: 존재하지만 malformed한 plugin.json은 크래시(감사 중단)가 아니라 shape gap이어야.
        # F는 바로 이 malformation을 잡으라고 있는데, 무가드 json.loads는 그 입력에서 죽는다.
        with tempfile.TemporaryDirectory() as d:
            dd = Path(d)
            (dd / ".claude-plugin").mkdir(parents=True)
            (dd / ".claude-plugin" / "plugin.json").write_text("{ not valid json ", encoding="utf-8")
            (dd / "README.md").write_text("# x\n## Principles Instantiated\n- L\n", encoding="utf-8")
            r, obj = run(dd)
            self.assertEqual(r.returncode, 0, f"malformed plugin.json이 크래시했다:\n{r.stderr}")
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertFalse(gaps["plugin_json_fields"]["present"],
                             "malformed plugin.json이 shape gap으로 기록되지 않음")

    def test_cost_class_body_mention_does_not_satisfy(self):
        # C7: cost_class 체크는 frontmatter 키만 인정해야 한다 — 본문(prose) 언급은 gap을 못
        # 가려야 (whole-file grep은 header-satisfiable 함정, 같은 파일 _has_tools_allowlist는
        # 이미 frontmatter를 추출한다).
        with tempfile.TemporaryDirectory() as d:
            dd = _mk_plugin(d)
            skill = dd / "skills" / "s"
            skill.mkdir(parents=True)
            # frontmatter엔 cost_class 없음, 본문에만 'cost_class' 언급
            (skill / "SKILL.md").write_text(
                "---\nname: s\ndescription: d\n---\n이 스킬의 cost_class는 본문에서만 논한다.\n",
                encoding="utf-8")
            r, obj = run(dd)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertFalse(gaps["skills_cost_class"]["present"],
                             "frontmatter에 cost_class 없는데 본문 언급이 present=True로 통과 (header-satisfiable)")

    def test_deps_declared_self_reference_not_counted_as_cross_plugin(self):
        # agents/x.md references the plugin's OWN namespace ("myplugin:helper") → not cross-plugin
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d)   # plugin.json name == "myplugin"; README has no "Prerequisites"
            agents_dir = Path(d) / "agents"
            agents_dir.mkdir()
            (agents_dir / "x.md").write_text(
                "---\ntools: Read\n---\nDispatch: agentType: 'myplugin:helper'\n",
                encoding="utf-8",
            )
            r, obj = run(d)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertTrue(gaps["deps_declared"]["present"],
                             "self-reference should not count as cross-plugin dispatch")


if __name__ == "__main__":
    unittest.main()
