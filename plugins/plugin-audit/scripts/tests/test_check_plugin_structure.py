import json, os, stat, subprocess, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check-plugin-structure.sh"


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


if __name__ == "__main__":
    unittest.main()
