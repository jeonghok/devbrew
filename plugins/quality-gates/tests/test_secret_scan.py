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


def blocked(out: str) -> bool:
    return "scan_ok: no" in [l.strip() for l in out.splitlines()]


class SecretScanTeeth(unittest.TestCase):
    def test_github_token_blocks(self):
        secret = "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8"
        out = run(f'token = "{secret}"', f'token = "{secret}"')
        self.assertTrue(blocked(out), out)
        self.assertIn("finding:", out)

    def test_aws_key_blocks(self):
        secret = "AKIAIOSFODNN7EXAMPLE"
        out = run(secret, secret)
        self.assertTrue(blocked(out), out)
        self.assertIn("finding:", out)

    def test_high_entropy_in_corpus_blocks(self):
        # Mixed-charset opaque token, Shannon ≈ 5.09 ≥ 4.0. NOT hex: hex maxes at
        # log2(16)=4.0 so it never crosses the threshold — that is deliberate, it
        # stops every git SHA in the corpus from false-positiving.
        secret = "Kj8xQvN2mZ4pR7wL9tB3cF6yD1sA5gH0uE"
        out = run(f"key={secret}", f"key={secret}")
        self.assertTrue(blocked(out), out)
        self.assertIn("finding:", out)

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
        self.assertTrue(blocked(r.stdout), r.stdout)

    def test_nonhttp_url_credentials_block(self):
        # DB/broker connection strings with embedded creds must block regardless of
        # the password's entropy — a KNOWN (corpus-independent) pattern. Includes the
        # password-only userinfo form (redis://:pass@) which needs the empty-user regex.
        for url in ("postgres://user:s3cr3tpassword@db:5432/app",
                    "redis://:hunter2hunter2hunter2@cache:6379"):
            out = run(url, url)
            self.assertTrue(blocked(out), f"{url}\n{out}")
            self.assertIn("finding:", out)

    def test_degraded_corpus_fails_closed(self):
        # Teeth for the corpus-integrity precondition: a degraded (no-merge-base)
        # corpus silently no-ops the corpus-gated detectors, so a high-entropy secret
        # NOT present in the thin corpus would otherwise pass. The scanner must FAIL
        # CLOSED on the degraded header marker rather than certify it clean.
        secret = "Kj8xQvN2mZ4pR7wL9tB3cF6yD1sA5gH0uE"   # high-entropy, absent from corpus
        corpus = "=== PR CONTEXT (degraded: no merge-base with main) ===\n"
        out = run(f"key={secret}", corpus)
        self.assertTrue(blocked(out), out)
        self.assertIn("corpus degraded", out)


if __name__ == "__main__":
    unittest.main()
