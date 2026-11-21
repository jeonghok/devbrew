#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""merged_pr_range.py — 머지된 PR 하나의 커밋 범위(start..end)를 머지 방식별로 확인한다.

사용:
  merged_pr_range.py --roadmap <로드맵> --pr <번호>          기계 상태 PR 캐시의 headRefOid · mergeCommit 을 읽는다
  merged_pr_range.py --merge <커밋> --head <커밋> --pr <번호>  값을 직접 준다

stdout(rc 0): `start: <40자>` · `end: <40자>` · `how: merge-commit | squash | rebase-<N>`.
종료 코드: 0 확인됨 · 2 사용법 · 3 확인하지 못함(stdout 비움, stderr 한 줄) · 4 캐시에 머지 커밋이 없다.
읽기만 한다 — 허용 git 하위 명령은 GIT_ALLOWED 뿐이다.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import conductor_state as cs  # noqa: E402
from state_path import state_root  # noqa: E402

GIT_ALLOWED = frozenset({"rev-parse", "rev-list", "merge-base", "diff", "patch-id", "cat-file"})
HASH_RE = re.compile(r"[0-9a-f]{7,40}")
FAIL_PREFIX = "[spec-distill] 범위를 확인하지 못했다 — "
DIFF_FLAGS = ("--no-color", "--no-ext-diff", "--no-textconv", "--no-renames")


def _git(repo, *args, input=None):
    if args[0] not in GIT_ALLOWED:
        raise ValueError("허용하지 않는 git 명령: %s" % args[0])
    p = subprocess.run(["git", *args], cwd=str(repo), capture_output=True, input=input,
                       encoding="utf-8", errors="replace")
    return p.returncode, p.stdout


def _commit(repo, x):
    if not HASH_RE.fullmatch(x) and not re.fullmatch(r"[0-9a-f]{40}(~[0-9]+)?", x):
        return None
    rc, out = _git(repo, "rev-parse", "--verify", "--quiet", x + "^{commit}")
    return out.strip() if rc == 0 else None


def _patch_id(repo, a, b):
    rc, diff = _git(repo, "diff", *DIFF_FLAGS, a, b)
    if rc != 0:
        return None
    rc, out = _git(repo, "patch-id", "--stable", input=diff)
    return (out.split() or [""])[0] if rc == 0 else None


def _strict(repo, a, b):
    rc, out = _git(repo, "diff", *DIFF_FLAGS, "--full-index", "-U0", a, b)
    if rc != 0:
        return None
    lines = []
    for ln in out.split("\n"):
        if ln.startswith("index "):
            continue
        lines.append("@@" if ln.startswith("@@") else ln)
    return "\n".join(lines)


def same_change(repo: str, a1: str, b1: str, a2: str, b2: str) -> bool:
    """(a1, b1) 의 변경과 (a2, b2) 의 변경이 글자로 같은가 — patch-id 로 좁히고 -U0 diff 글로 확정한다."""
    p1, p2 = _patch_id(repo, a1, b1), _patch_id(repo, a2, b2)
    if p1 is None or p2 is None or p1 != p2:
        return False
    s1, s2 = _strict(repo, a1, b1), _strict(repo, a2, b2)
    return s1 is not None and s1 == s2


def confirm(repo: str, merge: str, head: str, pr: str) -> tuple:
    """((start, end, how), None) 또는 (None, 사유)."""
    h = _commit(repo, head)
    if h is None:
        return None, "head 커밋 %s 이 이 레포에 없다 — git fetch origin pull/%s/head 뒤 다시 부른다" % (head[:8], pr)
    m = _commit(repo, merge)
    if m is None:
        return None, "머지 커밋 %s 이 이 레포에 없다" % merge[:8]
    rc, out = _git(repo, "rev-list", "--parents", "-n", "1", m)
    parents = out.split()[1:] if rc == 0 else []
    if len(parents) >= 3:
        return None, "부모가 셋 이상인 머지다"
    if len(parents) == 2:
        if parents[1] != h:
            return None, "부모가 둘인데 둘째 부모가 PR 의 head 가 아니다"
        return (parents[0], m, "merge-commit"), None
    if len(parents) != 1:
        return None, "머지 커밋의 부모를 읽지 못했다"
    rc, base = _git(repo, "merge-base", h, m)
    base = base.strip() if rc == 0 else ""
    cnt = 0
    if base:
        rc, c = _git(repo, "rev-list", "--count", base + ".." + h)
        cnt = int(c.strip()) if rc == 0 and c.strip().isdigit() else 0
    if not base or cnt == 0:
        return None, "head 와 머지 커밋의 공통 조상이 없어 PR 의 커밋 수를 셀 수 없다"
    cands = ([(cnt, "rebase-%d" % cnt)] if cnt > 1 else []) + [(1, "squash")]
    for n, how in cands:
        start = _commit(repo, "%s~%d" % (m, n))
        if start and same_change(repo, start, m, base, h):
            return (start, m, how), None
    return None, "부모가 하나인데 바로 앞 커밋부터도 PR 의 커밋 수(%d)만큼 앞부터도 PR 의 변경과 같지 않다" % cnt


def _fail(why):
    print(FAIL_PREFIX + why, file=sys.stderr)
    return 3


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="merged_pr_range.py")
    ap.add_argument("--roadmap")
    ap.add_argument("--merge")
    ap.add_argument("--head")
    ap.add_argument("--pr", required=True)
    try:
        a = ap.parse_args(argv)
    except SystemExit:
        return 2
    if not re.fullmatch(r"[0-9]+", a.pr):
        print("[spec-distill] --pr 는 숫자다", file=sys.stderr)
        return 2
    direct = a.merge is not None or a.head is not None
    if bool(a.roadmap) == direct or (direct and not (a.merge and a.head)):
        print("[spec-distill] --roadmap 하나, 또는 --merge 와 --head 를 함께 준다", file=sys.stderr)
        return 2
    rc, out = _git(".", "rev-parse", "--show-toplevel")
    repo = out.strip()
    if rc != 0 or not repo:
        return _fail("git 레포 안에서 부르지 않았다")
    merge, head = a.merge, a.head
    if a.roadmap:
        try:
            data = cs.load(cs.machine_path(state_root(repo), a.roadmap), a.roadmap)
        except cs.MachineError as exc:
            return _fail("기계 상태를 읽지 못했다(%s)" % exc)
        rows = [r for r in data["PR"] if r["번호"] == "#" + a.pr]
        if not rows or rows[-1]["mergeCommit"] == "-":
            print("[spec-distill] PR #%s 의 머지 커밋이 PR 캐시에 없다 — ledger pr-refresh 뒤 다시 부른다" % a.pr,
                  file=sys.stderr)
            return 4
        merge, head = rows[-1]["mergeCommit"], rows[-1]["headRefOid"]
    got, why = confirm(repo, merge, head, a.pr)
    if got is None:
        return _fail(why)
    print("start: %s\nend: %s\nhow: %s" % got)
    return 0


if __name__ == "__main__":
    sys.exit(main())
