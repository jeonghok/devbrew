"""test_secret_scan.py — secret-scan.py blocks real values, passes identifiers,
and FAILS CLOSED. Teeth proven by a real-secret fixture that must BLOCK
(design §11, AC6). Run: python3 -m unittest (from repo root)."""
from __future__ import annotations
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
        r = subprocess.run(
            [sys.executable, str(SCRIPT), "--payload", str(p), "--corpus", str(c)],
            capture_output=True, text=True)
        return r.stdout


def scan_ok(out: str) -> bool:
    return any(line.strip() == "scan_ok: yes" for line in out.splitlines())


class SecretScanTeeth(unittest.TestCase):
    def test_github_token_blocks(self):
        secret = "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8"
        out = run(f'token = "{secret}"', f'token = "{secret}"')
        self.assertFalse(scan_ok(out), out)

    def test_aws_key_blocks(self):
        secret = "AKIAIOSFODNN7EXAMPLE"
        out = run(secret, secret)
        self.assertFalse(scan_ok(out), out)

    def test_high_entropy_in_corpus_blocks(self):
        # Mixed-charset opaque token, Shannon ≈ 5.09 ≥ 4.0. NOT hex: hex maxes at
        # log2(16)=4.0 so it never crosses the threshold — that is deliberate, it
        # stops every git SHA in the corpus from false-positiving.
        secret = "Kj8xQvN2mZ4pR7wL9tB3cF6yD1sA5gH0uE"
        out = run(f"key={secret}", f"key={secret}")
        self.assertFalse(scan_ok(out), out)

    def test_identifier_and_path_pass(self):
        # Design §8: identifiers AND file paths must be nameable. Note
        # 'src/StripeWebhookHandler.ts' has Shannon ≈ 4.18 as a whole token — it
        # must still PASS because it is a path, not an opaque secret.
        payload = ("The authenticateUserWithToken function lives in "
                   "src/StripeWebhookHandler.ts and returns a Response.")
        out = run(payload, payload)
        self.assertTrue(scan_ok(out), out)

    def test_fail_closed_on_unreadable(self):
        r = subprocess.run(
            [sys.executable, str(SCRIPT), "--payload", "/no/such", "--corpus", "/no/such"],
            capture_output=True, text=True)
        self.assertFalse(scan_ok(r.stdout), r.stdout)


if __name__ == "__main__":
    unittest.main()
