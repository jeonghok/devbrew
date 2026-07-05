#!/usr/bin/env python3
"""comment-upsert.py — idempotent sticky-comment upsert for PR-understanding.

Scoped by IMMUTABLE comment.user.id (== authed user id), NOT author_association
(design §7). Marker match = the version-family first line, ANCHORED, tolerating
an OPTIONAL ` tier=N` suffix — the builder emits `<!-- pr-understanding:v1 tier=N -->`
but the tier drifts with changed-file count, so matching must ignore it or tier
drift would defeat idempotency (design §7). Pass the tier-less canonical marker
`<!-- pr-understanding:v1 -->`; a stored `... tier=2 -->` first line still matches.
Not a substring match: a first line with any prefix/suffix around the marker fails.

  0 matches → POST (terminal; no re-list-then-PATCH TOCTOU)
  1 match   → PATCH
  ≥2 matches → REFUSE (print both html_urls; human disambiguates)

DEVBREW_QG_DISABLE_PUBLISH=1 or --dry-run → decide but DO NOT mutate.

Usage:
  comment-upsert.py --pr N --marker M --body-file F --my-id ID
                    [--repo owner/name] [--comments-json F] [--dry-run]
"""
from __future__ import annotations
import argparse
import json
import os
import re
import subprocess
import sys


def _list_comments(repo: str, pr: str, stub: str | None):
    if stub:
        return json.load(open(stub, encoding="utf-8"))
    out = subprocess.run(
        ["gh", "api", "--paginate", "--slurp", f"repos/{repo}/issues/{pr}/comments"],
        capture_output=True, text=True, check=True).stdout
    data = json.loads(out)          # --slurp wraps pages: [[...],[...]]
    flat = []
    for page in data:
        flat.extend(page if isinstance(page, list) else [page])
    return flat


def _marker_regex(marker: str):
    """Anchored regex from the version-family marker that tolerates an optional
    ` tier=N` suffix — the builder emits tier=N, but matching must ignore the tier
    so tier drift doesn't defeat idempotency (design §7)."""
    base = re.sub(r"\s+tier=\d+", "", marker.strip())   # normalize away any tier suffix
    if base.endswith("-->"):
        head = base[:-len("-->")].rstrip()
        return re.compile(r"^" + re.escape(head) + r"(?: tier=\d+)? -->$")
    return re.compile(r"^" + re.escape(base) + r"$")


def _matches(comments, marker: str, my_id: str):
    pat = _marker_regex(marker)
    out = []
    for c in comments:
        uid = str((c.get("user") or {}).get("id", ""))
        first = (c.get("body") or "").splitlines()[0].strip() if c.get("body") else ""
        if uid and uid == str(my_id) and pat.match(first):
            out.append(c)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pr", required=True)
    ap.add_argument("--marker", required=True)
    ap.add_argument("--body-file", required=True)
    ap.add_argument("--my-id", required=True)
    ap.add_argument("--repo", default="")
    ap.add_argument("--comments-json", default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    disabled = os.environ.get("DEVBREW_QG_DISABLE_PUBLISH") == "1"
    suppress = args.dry_run or disabled

    try:
        comments = _list_comments(args.repo, args.pr, args.comments_json)
    except Exception as e:  # fail-closed: no confident decision → refuse to mutate
        print("action: refuse")
        print(f"reason: list failed ({type(e).__name__}) — fail-closed")
        return 2

    m = _matches(comments, args.marker, args.my_id)
    if len(m) >= 2:
        print("action: refuse")
        for c in m:
            print(f"url: {c.get('html_url','')}")
        return 3

    action = "post" if len(m) == 0 else "patch"
    print(f"action: {action}")
    if suppress:
        why = "publish disabled" if disabled else "dry-run"
        print(f"note: ({why} — network suppressed)")
        return 0

    if action == "post":
        subprocess.run(["gh", "api", "--method", "POST",
                        f"repos/{args.repo}/issues/{args.pr}/comments",
                        "-F", f"body=@{args.body_file}"], check=True)
    else:
        cid = m[0]["id"]
        subprocess.run(["gh", "api", "--method", "PATCH",
                        f"repos/{args.repo}/issues/comments/{cid}",
                        "-F", f"body=@{args.body_file}"], check=True)
    print("published: yes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
