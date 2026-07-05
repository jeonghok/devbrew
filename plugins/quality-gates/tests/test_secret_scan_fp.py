"""test_secret_scan_fp.py — secret-scan.py must NOT flag identifiers/type names,
including a ≥12-char low-entropy type name. Teeth: a mutation that removes the
value-shape subordination (keyword+colon alone blocks) turns `token: RequestHandler`
RED — proving the value-shape gate is load-bearing, not the length floor (design
§11, AC6; mirrors the 'grep 회귀 락 헤더-satisfiable 함정' lesson).
Run: python3 -m unittest (from repo root)."""
from __future__ import annotations
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = PLUGIN_ROOT / "scripts" / "secret-scan.py"


def run(payload: str, corpus: str) -> str:
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "payload"; c = Path(d) / "corpus"
        p.write_text(payload, encoding="utf-8")
        c.write_text(corpus, encoding="utf-8")
        r = subprocess.run([sys.executable, str(SCRIPT), "--payload", str(p),
                            "--corpus", str(c)], capture_output=True, text=True)
        return r.stdout


def scan_ok(out: str) -> bool:
    return any(line.strip() == "scan_ok: yes" for line in out.splitlines())


def blocked(out: str) -> bool:
    return "scan_ok: no" in [l.strip() for l in out.splitlines()]


def _load_module():
    spec = importlib.util.spec_from_file_location("secret_scan", SCRIPT)
    assert spec and spec.loader  # dynamic import of a hyphen-dir script path
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


class SecretScanFalsePositives(unittest.TestCase):
    def test_short_type_name_passes(self):
        self.assertTrue(scan_ok(run("token: string", "token: string")))

    def test_long_type_name_passes(self):
        # 14-char low-entropy type name — passes because it is NOT value-shaped,
        # NOT because of any length floor.
        self.assertTrue(scan_ok(run("token: RequestHandler", "token: RequestHandler")))

    def test_function_and_path_pass(self):
        payload = "handleWebhook in src/routes/webhook.ts calls verifySignature()"
        self.assertTrue(scan_ok(run(payload, payload)))

    def test_real_value_still_blocks(self):
        secret = "ghp_" + "Z9y8X7w6V5u4T3s2R1q0P9o8N7m6L5k4J3h2"
        self.assertTrue(blocked(run(f"token = {secret}", f"token = {secret}")))

    def test_mutation_teeth(self):
        """If the keyword rule stopped subordinating to value-shape, this input
        would flag. Assert the gate is what passes it: value_shaped() returns
        falsy for the low-entropy RHS."""
        m = _load_module()
        self.assertFalse(bool(m.value_shaped("RequestHandler", "token: RequestHandler")))


if __name__ == "__main__":
    unittest.main()
