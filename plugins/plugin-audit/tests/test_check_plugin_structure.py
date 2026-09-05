import json, os, stat, subprocess, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check-plugin-structure.sh"


def _exe(p, body):
    p.write_text(body); p.chmod(p.stat().st_mode | stat.S_IEXEC)


def _stub_plugin_dev(root, kind):
    """kind: 'clean' | 'exit5' | 'crash' | 'absent'"""
    base = Path(root) / "skills" / "hook-development" / "scripts"
    base.mkdir(parents=True)
    ad = Path(root) / "skills" / "agent-development" / "scripts"
    ad.mkdir(parents=True)
    if kind == "absent":
        return   # no scripts
    _exe(ad / "validate-agent.sh", "#!/usr/bin/env bash\necho '❌ Missing field: color'\nexit 1\n")
    _exe(base / "hook-linter.sh", "#!/usr/bin/env bash\necho '✅ clean'\nexit 0\n")
    if kind == "exit5":
        _exe(base / "validate-hook-schema.sh", "#!/usr/bin/env bash\necho 'jq: error Cannot index object with number' >&2\nexit 5\n")
    elif kind == "crash":
        _exe(base / "validate-hook-schema.sh", "#!/usr/bin/env bash\nexit 127\n")
    else:
        _exe(base / "validate-hook-schema.sh", "#!/usr/bin/env bash\necho '✅ ok'\nexit 0\n")


def _mk_target(d):
    d = Path(d)
    (d / "agents").mkdir(parents=True)
    (d / "agents" / "a.md").write_text("---\nname: a\ntools: Read\n---\nbody\n", encoding="utf-8")
    (d / "hooks").mkdir()
    (d / "hooks" / "hooks.json").write_text('{"description":"x","hooks":{"PreToolUse":[]}}', encoding="utf-8")
    (d / "hooks" / "h.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\n", encoding="utf-8")
    return d


def _mk_target_no_sh_hooks(d):
    """like _mk_target but hooks/ has hooks.json + a .py hook only — NO .sh files."""
    d = Path(d)
    (d / "agents").mkdir(parents=True)
    (d / "agents" / "a.md").write_text("---\nname: a\ntools: Read\n---\nbody\n", encoding="utf-8")
    (d / "hooks").mkdir()
    (d / "hooks" / "hooks.json").write_text('{"description":"x","hooks":{"PreToolUse":[]}}', encoding="utf-8")
    (d / "hooks" / "h.py").write_text("#!/usr/bin/env python3\nprint('ok')\n", encoding="utf-8")
    return d


def run(target, pdev_root):
    r = subprocess.run(["bash", str(SCRIPT), str(target), "--plugin-dev-root", str(pdev_root)],
                       capture_output=True, text=True)
    return r, (json.loads(r.stdout) if r.stdout.strip() else {})


def _stub_validate_agent_no_output_crash(root):
    """plugin-dev stub whose validate-agent.sh exits non-zero with NO output at all
    (no ❌/error line) — e.g. a bare 'Permission denied' or truly empty stdout+stderr."""
    base = Path(root) / "skills" / "hook-development" / "scripts"
    base.mkdir(parents=True, exist_ok=True)
    ad = Path(root) / "skills" / "agent-development" / "scripts"
    ad.mkdir(parents=True, exist_ok=True)
    _exe(ad / "validate-agent.sh", "#!/usr/bin/env bash\nexit 1\n")
    _exe(base / "hook-linter.sh", "#!/usr/bin/env bash\necho '✅ clean'\nexit 0\n")
    _exe(base / "validate-hook-schema.sh", "#!/usr/bin/env bash\necho '✅ ok'\nexit 0\n")


def _stub_validate_agent_missing(root, field):
    """plugin-dev stub whose validate-agent.sh fails ONLY on the given missing field."""
    base = Path(root) / "skills" / "hook-development" / "scripts"
    base.mkdir(parents=True, exist_ok=True)
    ad = Path(root) / "skills" / "agent-development" / "scripts"
    ad.mkdir(parents=True, exist_ok=True)
    _exe(ad / "validate-agent.sh",
         "#!/usr/bin/env bash\necho '❌ Missing required field: %s'\nexit 1\n" % field)
    _exe(base / "hook-linter.sh", "#!/usr/bin/env bash\necho '✅ clean'\nexit 0\n")
    _exe(base / "validate-hook-schema.sh", "#!/usr/bin/env bash\necho '✅ ok'\nexit 0\n")


class TestPluginStructure(unittest.TestCase):
    def test_absent_plugin_dev_degrades_not_crash(self):   # AC-9 (부재)
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_plugin_dev(pd, "absent")
            r, obj = run(_mk_target(t), pd)
            self.assertEqual(r.returncode, 0)   # exit 0 (hard error 아님)
            self.assertTrue(obj["degraded"], "plugin-dev absent not degraded")

    def test_exit5_hook_schema_is_degraded_not_fact(self):   # AC-9 (스퓨리어스 exit)
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_plugin_dev(pd, "exit5")
            r, obj = run(_mk_target(t), pd)
            self.assertEqual(r.returncode, 0)
            self.assertTrue(any("hook-schema" in x or "index object" in x for x in obj["degraded"]))
            self.assertFalse(any(f["validator"] == "validate-hook-schema.sh" for f in obj["structure_facts"]),
                             "incompatible validator surfaced as fact (false evidence)")

    def test_crash_validator_is_degraded(self):   # AC-9 (크래시)
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_plugin_dev(pd, "crash")
            r, obj = run(_mk_target(t), pd)
            self.assertEqual(r.returncode, 0)
            self.assertTrue(obj["degraded"])

    def test_hook_linter_fact_surfaced_when_clean(self):
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_plugin_dev(pd, "clean")
            r, obj = run(_mk_target(t), pd)
            self.assertTrue(any(f["validator"] == "hook-linter.sh" for f in obj["structure_facts"]))

    def test_no_sh_hooks_no_false_hook_linter_fact(self):   # AC-9 (unguarded glob false fact)
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_plugin_dev(pd, "clean")
            r, obj = run(_mk_target_no_sh_hooks(t), pd)
            self.assertEqual(r.returncode, 0)
            self.assertFalse(any(f["validator"] == "hook-linter.sh" for f in obj["structure_facts"]),
                             "hook-linter.sh invoked on literal '*.sh' glob — false fact for a plugin with no shell hooks")

    def test_model_missing_alone_is_convention_not_degrade(self):   # spec AC12
        # devbrew 규약: frontmatter 에 model 키를 두지 않는다. plugin-dev 검증기의
        # "model required" 는 이 리포 불변식이 아니므로 degrade 로 기록하지 않는다.
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_validate_agent_missing(pd, "model")
            r, obj = run(_mk_target(t), pd)
            self.assertEqual(r.returncode, 0)
            self.assertFalse([x for x in obj["degraded"] if "validate-agent.sh" in x],
                             obj["degraded"])

    def test_color_missing_alone_still_degrades(self):   # 양성 짝 — 필터가 통째로 죽지 않았다
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_validate_agent_missing(pd, "color")
            r, obj = run(_mk_target(t), pd)
            self.assertEqual(r.returncode, 0)
            self.assertTrue([x for x in obj["degraded"] if "validate-agent.sh" in x],
                            obj["degraded"])

    def test_no_output_crash_is_spurious_degrade(self):   # fix round 1 — loud degradation
        # rc != 0 이지만 ❌/error 매칭 라인이 전혀 없는 경우 (권한 오류, 완전 무출력 등) —
        # model/color 필터에 걸리지 않으니 아무것도 기록 안 하면 조용한 실패다. 형제
        # validator들처럼 "스퓨리어스 exit"로 degrade 되어야 한다 (C14).
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_validate_agent_no_output_crash(pd)
            r, obj = run(_mk_target(t), pd)
            self.assertEqual(r.returncode, 0)
            self.assertTrue(
                [x for x in obj["degraded"] if "validate-agent.sh" in x and "스퓨리어스" in x],
                obj["degraded"])


if __name__ == "__main__":
    unittest.main()
