"""test_comment_upsert.py — marker idempotency by immutable comment.user.id
(design §7, AC7). --comments-json stubs the existing-comments list so no network.
Run: python3 -m unittest (from repo root)."""
from __future__ import annotations
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = PLUGIN_ROOT / "scripts" / "comment-upsert.py"
MARKER = "<!-- pr-understanding:v1 -->"
MY_ID = "583231"


def run(comments, dry_run=True, my_id=MY_ID):
    with tempfile.TemporaryDirectory() as d:
        body = Path(d) / "body"; cj = Path(d) / "comments.json"
        body.write_text(MARKER + "\n\nhello", encoding="utf-8")
        cj.write_text(json.dumps(comments), encoding="utf-8")
        argv = [sys.executable, str(SCRIPT), "--pr", "123", "--marker", MARKER,
                "--body-file", str(body), "--my-id", my_id, "--repo", "o/r",
                "--comments-json", str(cj)]
        if dry_run:
            argv.append("--dry-run")
        return subprocess.run(argv, capture_output=True, text=True)


def action(out: str):
    for line in out.splitlines():
        if line.startswith("action:"):
            return line.split(":", 1)[1].strip()
    return None


def mkc(cid, uid, first_line, html="https://x/c"):
    return {"id": cid, "user": {"id": int(uid)}, "body": first_line + "\nrest",
            "html_url": html}


class CommentUpsert(unittest.TestCase):
    def test_zero_match_posts(self):
        r = run([mkc(1, 999, "unrelated")])
        self.assertEqual(action(r.stdout), "post", r.stdout)

    def test_one_match_patches(self):
        r = run([mkc(1, MY_ID, MARKER)])
        self.assertEqual(action(r.stdout), "patch", r.stdout)

    def test_two_match_refuses(self):
        r = run([mkc(1, MY_ID, MARKER), mkc(2, MY_ID, MARKER, "https://y/c")])
        self.assertEqual(action(r.stdout), "refuse", r.stdout)
        self.assertIn("https://x/c", r.stdout)
        self.assertIn("https://y/c", r.stdout)

    def test_attacker_marker_not_selected(self):
        # attacker posts our marker under a DIFFERENT user id → must NOT count → POST
        r = run([mkc(1, 999, MARKER)])
        self.assertEqual(action(r.stdout), "post", r.stdout)

    def test_substring_marker_not_matched(self):
        # marker only as a substring of the first line → not an exact match → POST
        r = run([mkc(1, MY_ID, "prefix " + MARKER)])
        self.assertEqual(action(r.stdout), "post", r.stdout)

    def test_empty_my_id_matches_nothing(self):
        # A userless/empty-uid comment bearing our marker must NOT be selected
        # when my_id is empty (defense against an empty authed id).
        c = {"id": 1, "user": {"id": ""}, "body": MARKER + "\nrest", "html_url": "https://x/c"}
        r = run([c], my_id="")
        self.assertEqual(action(r.stdout), "post", r.stdout)

    def test_producer_tier_marker_is_matched(self):
        # A stored comment whose first line is the builder's real tier=N marker
        # must be found (PATCH) when the orchestrator passes the tier-less marker.
        c = {"id": 1, "user": {"id": int(MY_ID)},
             "body": "<!-- pr-understanding:v1 tier=2 -->\nbody", "html_url": "https://x/c"}
        r = run([c])   # run() posts with MARKER = tier-less canonical
        self.assertEqual(action(r.stdout), "patch", r.stdout)

    def test_tier_drift_still_matches_no_duplicate(self):
        # Stored at tier=2, re-run conceptually at tier=3 → the tier-less matcher
        # still finds the tier=2 comment → PATCH, not a duplicate POST.
        c = {"id": 1, "user": {"id": int(MY_ID)},
             "body": "<!-- pr-understanding:v1 tier=2 -->\nold", "html_url": "https://x/c"}
        r = run([c])
        self.assertEqual(action(r.stdout), "patch", r.stdout)


if __name__ == "__main__":
    unittest.main()
