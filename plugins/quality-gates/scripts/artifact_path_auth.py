#!/usr/bin/env python3
"""artifact_path_auth.py — canonicalize the single E3-fixed target and reject
symlink / `..` escapes out of project_dir (§7 path-auth, AC17). Exit 0 always.

Mirrors the realpath-under-root guard used by the code pipeline SKILL: a target
whose realpath is not project_dir itself nor under project_dir + os.sep is
rejected, defeating symlink or traversal escape of the single-target invariant.
"""
import os
import sys


def main():
    if len(sys.argv) != 3:
        print("auth: reject")
        print("reason: missing_args")
        return 0
    root = os.path.realpath(sys.argv[1])
    target = sys.argv[2]
    abs_target = target if os.path.isabs(target) else os.path.join(root, target)
    cand = os.path.realpath(abs_target)
    # Reject a symlink alias (final component OR any ancestor). git tracks the LINK
    # (blob = target string) while the reviewers/editor operate on the pointed-to
    # file, splitting classification + change-detection + commit (on the raw alias)
    # from review + edit (on canonical): an in-tree symlink to a code file would be
    # critiqued as non-code and its edit left uncommitted, and an escaping symlink
    # would exfiltrate. A critique target must be a real regular file. `root` is
    # already realpath-resolved, so realpath(abs_target) != normpath(abs_target)
    # means a symlink lies somewhere in the target's own path components.
    if cand != os.path.normpath(abs_target):
        print("auth: reject")
        print("reason: symlink_target")
        return 0
    if cand == root or cand.startswith(root + os.sep):
        print("auth: ok")
        print(f"canonical: {cand}")
    else:
        print("auth: reject")
        print("reason: escapes_project_dir")
    return 0


if __name__ == "__main__":
    sys.exit(main())
