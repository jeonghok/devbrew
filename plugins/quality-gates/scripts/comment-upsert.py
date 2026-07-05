#!/usr/bin/env python3
"""comment-upsert.py — idempotent sticky-comment upsert for PR-understanding.

Scoped by IMMUTABLE comment.user.id (== authed user id), NOT author_association
(design §7). Marker match = EXACT trimmed first line, not substring.

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
import subprocess
import sys


def _list_comments(repo: str, pr: str, stub: str | None):
    if stub:
        return json.load(open(stub, encoding="utf-8"))
    out = subprocess.run(
        ["gh", "api", "--paginate", f"repos/{repo}/issues/{pr}/comments"],
        capture_output=True, text=True, check=True).stdout
    # --paginate may concatenate JSON arrays; normalize to a flat list
    data, buf = [], out.strip()
    for chunk in buf.replace("][", "]\x00[").split("\x00"):
        if chunk.strip():
            data.extend(json.loads(chunk))
    return data


def _matches(comments, marker: str, my_id: str):
    out = []
    for c in comments:
        uid = str((c.get("user") or {}).get("id", ""))
        first = (c.get("body") or "").splitlines()[0].strip() if c.get("body") else ""
        if uid and uid == str(my_id) and first == marker:
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
