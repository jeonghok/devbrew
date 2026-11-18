import ast, json, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check-shape-completeness.py"
REPO = Path(__file__).resolve().parents[3]        # repo root (plugins/plugin-audit/tests → parents[3])
CLAUDE_MD = REPO / "CLAUDE.md"

# checklist requirement → CLAUDE.md §Plugin Shape body-unique anchor
ANCHORS = {
    "plugin_json_fields": "`plugin.json` 의 필수 키는 `name` 하나다",
    "readme_principles": '"Principles Instantiated"',
    "changelog_if_v1": "v1.0.0 이상이면 `CHANGELOG.md`",
    "agents_allowlist": "`tools:` allowlist를 선언",
    "skills_cost_class": "모든 skill 은 frontmatter `metadata` 아래에 `cost_class` 를 선언한다",
    "deps_declared": "최소 버전이 선언된 의존성",
}


def run(plugin_dir):
    r = subprocess.run([sys.executable, str(SCRIPT), str(plugin_dir), "--repo-root", str(REPO)],
                       capture_output=True, text=True)
    return r, (json.loads(r.stdout) if r.stdout.strip() else {})


def _mk_plugin(d, version="0.1.0", drop_version=False, skill_fm=None):
    d = Path(d)
    (d / ".claude-plugin").mkdir(parents=True)
    pj = {"name": "myplugin", "description": "x"}
    if not drop_version:
        pj["version"] = version
    (d / ".claude-plugin" / "plugin.json").write_text(json.dumps(pj), encoding="utf-8")
    (d / "README.md").write_text("# myplugin\n## Principles Instantiated\n- Law 1\n", encoding="utf-8")
    if skill_fm is not None:
        (d / "skills" / "s").mkdir(parents=True)
        (d / "skills" / "s" / "SKILL.md").write_text(
            "---\nname: s\ndescription: d\n" + skill_fm + "---\nbody\n", encoding="utf-8")
    return d


class TestShapeCompleteness(unittest.TestCase):
    def _gaps(self, d):
        r, obj = run(d)
        self.assertEqual(r.returncode, 0, r.stderr)
        return {g["requirement"]: g for g in obj["shape_gaps"]}

    def _cost(self, skill_fm):
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d, skill_fm=skill_fm)
            return self._gaps(d)["skills_cost_class"]["present"]

    def _pj(self, obj):
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d)
            (Path(d) / ".claude-plugin" / "plugin.json").write_text(json.dumps(obj), encoding="utf-8")
            return self._gaps(d)["plugin_json_fields"]["present"]

    def test_metadata_cost_class_is_declared(self):            # AC2 새 자리
        self.assertTrue(self._cost("metadata:\n  cost_class: high\n"))

    def test_top_level_only_cost_class_is_not_declared(self):   # AC2 맨 위에만
        self.assertFalse(self._cost("cost_class: high\n"))

    def test_no_cost_class_is_not_declared(self):               # AC2 없음
        self.assertFalse(self._cost(""))

    def test_indented_cost_class_outside_metadata_is_not_declared(self):   # Review Focus 1
        self.assertFalse(self._cost("hooks:\n  cost_class: high\n"))
        self.assertFalse(self._cost("metadata:\n  a: 1\nhooks:\n  cost_class: high\n"))

    def test_metadata_cost_class_after_sibling_child_is_declared(self):    # Review Focus 2
        self.assertTrue(self._cost("metadata:\n  author: x\n\n  cost_class: low\n"))

    def test_nested_deeper_cost_class_is_not_declared(self):
        self.assertFalse(self._cost("metadata:\n  inner:\n    cost_class: low\n"))

    def test_body_metadata_block_is_not_declared(self):         # Review Focus 3
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d, skill_fm="")
            (Path(d) / "skills" / "s" / "SKILL.md").write_text(
                "---\nname: s\ndescription: d\n---\nmetadata:\n  cost_class: high\n", encoding="utf-8")
            self.assertFalse(self._gaps(d)["skills_cost_class"]["present"])

    def test_both_places_counts_metadata(self):                 # Review Focus 5
        self.assertTrue(self._cost("cost_class: high\nmetadata:\n  cost_class: high\n"))

    def test_zero_column_comment_inside_metadata(self):         # AC16 — 0열 주석은 블록을 닫지 않는다
        self.assertTrue(self._cost("metadata:\n# note\n  cost_class: low\n"))

    def test_one_line_form_is_not_declared(self):               # 한 줄 꼴은 블록이 아니다
        self.assertFalse(self._cost("metadata: {cost_class: low}\n"))

    def test_tab_indent_is_declared(self):                      # J16 — 탭 들여쓰기는 선언 (지금 동작)
        self.assertTrue(self._cost("metadata:\n\tcost_class: low\n"))

    def test_two_copies_are_identical(self):                    # 두 사본의 _metadata_cost_class 는 글자 그대로 같다
        def _fn_source(name):
            path = SCRIPT.parent / name
            text = path.read_text(encoding="utf-8")
            fn = next(n for n in ast.parse(text).body
                      if isinstance(n, ast.FunctionDef) and n.name == "_metadata_cost_class")
            return ast.get_source_segment(text, fn)
        self.assertEqual(_fn_source("check-shape-completeness.py"), _fn_source("check-staleness.py"))

    def test_name_only_plugin_json_is_not_gap(self):            # AC9
        self.assertTrue(self._pj({"name": "myplugin"}))

    def test_name_missing_is_gap(self):                         # AC9
        self.assertFalse(self._pj({"version": "0.1.0", "description": "x"}))

    def test_empty_or_nonstring_name_is_gap(self):              # Review Focus 4
        for bad in ("", 5, None):
            self.assertFalse(self._pj({"name": bad}), repr(bad))

    def test_nonstring_version_is_gap(self):                    # AC9
        self.assertFalse(self._pj({"name": "x", "version": 1}))

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
            self.assertEqual(shape.count(anchor), 1, f"checklist '{req}' anchor is not unique in §Plugin Shape")

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

    def test_hook_without_switch_is_not_a_gap(self):  # AC9 — 훅에 끄기 변수를 요구하지 않는다
        # 등록된 훅 스크립트가 어떤 끄기 변수도 읽지 않아도 요건 목록에 hooks_killswitch 가 없고,
        # 나머지 항목은 훅이 없을 때와 같은 값이다.
        with tempfile.TemporaryDirectory() as d:
            dd = _mk_plugin(d)
            hooks = dd / "hooks"; hooks.mkdir()
            (hooks / "hooks.json").write_text(json.dumps({
                "hooks": {"PostToolUse": [{"hooks": [
                    {"type": "command", "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/h.py"}]}]}
            }), encoding="utf-8")
            (hooks / "h.py").write_text("print('no switch here')\n", encoding="utf-8")
            gaps = self._gaps(dd)
            self.assertNotIn("hooks_killswitch", gaps)
            for req in ("plugin_json_fields", "readme_principles", "changelog_if_v1",
                        "agents_allowlist", "skills_cost_class"):
                self.assertTrue(gaps[req]["present"], req)
            self.assertTrue(gaps["deps_declared"]["present"])

    def test_checklist_names(self):  # AC9 — 요건은 정확히 여섯
        with tempfile.TemporaryDirectory() as d:
            _mk_plugin(d)
            names = [g["requirement"] for g in self._gaps_list(d)]
            self.assertEqual(names, ["plugin_json_fields", "readme_principles", "changelog_if_v1",
                                     "agents_allowlist", "skills_cost_class", "deps_declared"])

    def _gaps_list(self, d):
        r, obj = run(d)
        self.assertEqual(r.returncode, 0, r.stderr)
        return obj["shape_gaps"]

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
