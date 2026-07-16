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
    cand = os.path.realpath(target if os.path.isabs(target) else os.path.join(root, target))
    if cand == root or cand.startswith(root + os.sep):
        print("auth: ok")
        print(f"canonical: {cand}")
    else:
        print("auth: reject")
        print("reason: escapes_project_dir")
    return 0


if __name__ == "__main__":
    sys.exit(main())
