import json, os, subprocess, sys, tempfile, unittest
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

    def test_non_object_plugin_json_is_gap_not_crash(self):
        # 회귀 방지 (codex fix-review): 문법상 유효하나 top-level이 object가 아닌 plugin.json
        # ([], null, 문자열, 숫자)은 크래시(pj.get AttributeError / k in None TypeError)가 아니라
        # shape gap이어야 한다.
        for content in ("[]", "null", '"a string"', "42"):
            with tempfile.TemporaryDirectory() as d:
                dd = Path(d)
                (dd / ".claude-plugin").mkdir(parents=True)
                (dd / ".claude-plugin" / "plugin.json").write_text(content, encoding="utf-8")
                (dd / "README.md").write_text("# x\n## Principles Instantiated\n- L\n", encoding="utf-8")
                r, obj = run(dd)
                self.assertEqual(r.returncode, 0, f"비-object plugin.json({content})이 크래시:\n{r.stderr}")
                gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
                self.assertFalse(gaps["plugin_json_fields"]["present"], f"{content}이 gap으로 기록 안 됨")

    def test_null_version_is_gap_not_crash(self):
        # codex final-review: 유효 object지만 version이 non-string(null 등)이면 _semver_ge가
        # re.findall(None)에서 크래시했다. 크래시가 아니라 gap(present=False)이어야 한다.
        with tempfile.TemporaryDirectory() as d:
            dd = Path(d)
            (dd / ".claude-plugin").mkdir(parents=True)
            (dd / ".claude-plugin" / "plugin.json").write_text(
                '{"name":"x","version":null,"description":"y"}', encoding="utf-8")
            (dd / "README.md").write_text("# x\n## Principles Instantiated\n- L\n", encoding="utf-8")
            r, obj = run(dd)
            self.assertEqual(r.returncode, 0, f"version:null이 크래시:\n{r.stderr}")
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertFalse(gaps["plugin_json_fields"]["present"], "version:null이 gap으로 기록 안 됨")

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

    def test_hooks_killswitch_ignores_non_registered_files(self):  # F (/qg 2026-07-20 round-2)
        # codex: _hook_scripts가 hooks/ 아래를 통째 rglob해 tests/·__init__.py·헬퍼(비-등록 파일)까지
        # 훅으로 오인 → 정상 플러그인(project-init·spec-distill)에 거짓 "kill switch 부재" 사실. hooks.json이
        # 등록한 command 스크립트만 봐야 한다. 등록 훅(real-hook.py)엔 kill switch 있음, 비-등록 tests/엔 없음.
        with tempfile.TemporaryDirectory() as d:
            dd = _mk_plugin(d)
            hooks = dd / "hooks"; (hooks / "tests").mkdir(parents=True)
            (hooks / "hooks.json").write_text(json.dumps({
                "hooks": {"PostToolUse": [{"hooks": [
                    {"type": "command", "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/real-hook.py"}]}]}
            }), encoding="utf-8")
            (hooks / "real-hook.py").write_text(
                "import os\nif os.environ.get('DEVBREW_DISABLE_MYPLUGIN'):\n    raise SystemExit\n", encoding="utf-8")
            (hooks / "tests" / "test_real_hook.py").write_text("assert True  # no kill switch\n", encoding="utf-8")
            (hooks / "tests" / "__init__.py").write_text("", encoding="utf-8")
            r, obj = run(dd)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertTrue(gaps["hooks_killswitch"]["present"],
                            "비-등록 hooks/tests/ 파일이 훅으로 오인돼 거짓 kill-switch 부재 (over-glob)")

    def test_hooks_killswitch_malformed_json_is_gap(self):  # F round-2 (codex re-verify R2)
        # malformed hooks.json → 파싱 실패 → 등록 스크립트 []  → all([])로 조용히 통과하던 fail-open.
        # 판정 불가는 fail-closed로 gap이어야 한다.
        with tempfile.TemporaryDirectory() as d:
            dd = _mk_plugin(d)
            hooks = dd / "hooks"; hooks.mkdir()
            (hooks / "hooks.json").write_text("{ not valid json ", encoding="utf-8")
            r, obj = run(dd)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertFalse(gaps["hooks_killswitch"]["present"],
                             "malformed hooks.json이 all([])로 조용히 통과 (fail-open)")

    def test_hooks_killswitch_dangling_registered_script_is_gap(self):  # F round-2 R2
        # hooks.json이 등록한 command가 참조하는 스크립트가 디스크에 부재 → 검증 불가(dangling) → gap.
        with tempfile.TemporaryDirectory() as d:
            dd = _mk_plugin(d)
            hooks = dd / "hooks"; hooks.mkdir()
            (hooks / "hooks.json").write_text(json.dumps({
                "hooks": {"PostToolUse": [{"hooks": [
                    {"type": "command", "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/ghost.py"}]}]}
            }), encoding="utf-8")   # ghost.py를 만들지 않음
            r, obj = run(dd)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertFalse(gaps["hooks_killswitch"]["present"],
                             "등록된 hook 스크립트가 부재(dangling)인데 통과 (검증 불가 fail-open)")

    def test_hooks_killswitch_path_traversal_is_gap(self):  # V2-4 (codex re-verify round-2, security)
        # 악성 hooks.json의 등록 command가 `../`로 plugin root 밖을 가리키면, 무관한 외부 파일로
        # kill-switch 검사를 만족시키는 read-oracle/traversal이 된다. containment로 plugin root 밖은
        # 판독 전에 거부(gap)해야 한다. 외부 파일은 kill-switch 토큰을 가져 — 미차단 시 present=True(버그).
        with tempfile.TemporaryDirectory() as outside:
            evil = Path(outside) / "evil.py"
            evil.write_text("# DEVBREW_DISABLE_X — plugin 밖 파일\n", encoding="utf-8")
            with tempfile.TemporaryDirectory() as d:
                dd = _mk_plugin(d)
                hooks = dd / "hooks"; hooks.mkdir()
                rel = os.path.relpath(evil, dd)   # ${CLAUDE_PLUGIN_ROOT}(=dd) 기준 상대경로 (../ 포함)
                (hooks / "hooks.json").write_text(json.dumps({
                    "hooks": {"PostToolUse": [{"hooks": [
                        {"type": "command", "command": f"python3 ${{CLAUDE_PLUGIN_ROOT}}/{rel}"}]}]}
                }), encoding="utf-8")
                r, obj = run(dd)
                gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
                self.assertFalse(gaps["hooks_killswitch"]["present"],
                                 "../ traversal이 외부 파일로 kill-switch 검사를 만족 (read-oracle 미차단)")

    def test_hooks_killswitch_flags_registered_hook_without_switch(self):  # F 반대 이빨
        # 검사 무력화 방지: hooks.json이 등록한 훅이 kill switch를 안 가지면 여전히 gap이어야 한다.
        with tempfile.TemporaryDirectory() as d:
            dd = _mk_plugin(d)
            hooks = dd / "hooks"; hooks.mkdir()
            (hooks / "hooks.json").write_text(json.dumps({
                "hooks": {"PostToolUse": [{"hooks": [
                    {"type": "command", "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/bad-hook.py"}]}]}
            }), encoding="utf-8")
            (hooks / "bad-hook.py").write_text("print('no kill switch here')\n", encoding="utf-8")
            r, obj = run(dd)
            gaps = {g["requirement"]: g for g in obj["shape_gaps"]}
            self.assertFalse(gaps["hooks_killswitch"]["present"],
                             "등록된 훅이 kill switch 없는데 통과 (검사가 무력화됨)")

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
