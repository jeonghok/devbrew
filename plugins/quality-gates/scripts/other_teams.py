"""intent-critic 의 다른 팀 읽기 — 기본 브랜치 · 다른 작업(브랜치) 찾기 · 파일 겹침.

git 은 `_git` 한 자리로만 부른다 — argv 목록(셸 없음) · `git -C <리포>`. 경로를 pathspec 으로
넘길 때는 `lit` 로 경로마다 `:(literal)` 접두를 붙인다(전역 `--literal-pathspecs` 는 쓰지 않는다).
rev 와 경로를 함께 받는 하위 명령(rev-list · log · diff)은 rev 뒤를 `--` 로 닫는다 — 작업 트리에
rev 와 같은 이름의 파일(`HEAD` · 기본 ref 경로)이 있어도 rev 로만 읽힌다.
리포를 바꾸는 명령은 쓰지 않는다. 이 모듈은 `adjudication` 을 쓰지 않는다.
"""
from __future__ import annotations

import os
import subprocess
import sys
from typing import List, Optional

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

ORIGIN_HEAD = "refs/remotes/origin/HEAD"
_REMOTES = "refs/remotes/"
_HEADS = "refs/heads/"
_SHORT_PREFIXES = ("refs/remotes/origin/", _HEADS, _REMOTES)


def _git(repo: str, *args: str):
    try:
        return subprocess.run(["git", "-C", repo] + list(args), capture_output=True)
    except (OSError, ValueError):
        return None


def lit(path: str) -> str:
    return ":(literal)" + path


def _ok(proc) -> bool:
    return proc is not None and proc.returncode == 0


def _text(raw: bytes) -> str:
    # surrogateescape — 읽은 경로를 다시 git 인자로 넘길 때 바이트가 그대로 돌아간다.
    return raw.decode("utf-8", "surrogateescape")


def _rev_ok(rev: str) -> bool:
    """git 인자로 넘길 rev — 비어 있지 않고 `-` 로 시작하지 않으며 한 줄."""
    if not rev or rev.startswith("-"):
        return False
    for ch in rev:
        if ord(ch) < 32 or ord(ch) == 127:
            return False
    return True


def _short_name(ref: str) -> str:
    for prefix in _SHORT_PREFIXES:
        if ref.startswith(prefix) and len(ref) > len(prefix):
            return ref[len(prefix):]
    return ref


def default_branch(repo: str) -> Optional[tuple]:
    """`(짧은 이름, 전체 ref)` — origin/HEAD 의 대상이 실제로 있을 때만."""
    sym = _git(repo, "symbolic-ref", "--quiet", ORIGIN_HEAD)
    if not _ok(sym):
        return None
    ref = _text(sym.stdout).strip()
    if not ref.startswith("refs/") or not _rev_ok(ref):
        return None
    verify = _git(repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}")
    if not _ok(verify):
        return None
    return (_short_name(ref), ref)


def _tips(repo: str) -> Optional[List[tuple]]:
    """`(이름, sha, 시각)` — 끝 커밋 하나에 한 줄(로컬 브랜치 이름이 이긴다). 읽지 못하면 None."""
    proc = _git(repo, "for-each-ref",
                "--format=%(refname)%00%(objectname)%00%(committerdate:unix)",
                "refs/heads", "refs/remotes")
    if not _ok(proc):
        return None
    chosen = {}
    for line in _text(proc.stdout).split("\n"):
        if not line:
            continue
        fields = line.split("\0")
        if len(fields) != 3:
            continue
        ref, sha, when = fields
        if ref.startswith(_REMOTES) and ref.endswith("/HEAD"):
            continue
        local = ref.startswith(_HEADS)
        name = ref[len(_HEADS):] if local else ref[len(_REMOTES):]
        try:
            stamp = int(when)
        except ValueError:
            stamp = 0
        rank = (0 if local else 1, name)
        if sha not in chosen or rank < chosen[sha][0]:
            chosen[sha] = (rank, name, stamp)
    return [(name, sha, stamp) for sha, (_rank, name, stamp) in chosen.items()]


def _z_paths(raw: bytes) -> set:
    """`-z` 이름 목록 — NUL 로 나누고 빈 조각과 조각 앞의 커밋 구분 줄바꿈을 걷는다."""
    out = set()
    for piece in _text(raw).split("\0"):
        if piece.startswith("\n"):
            piece = piece[1:]
        if piece:
            out.add(piece)
    return out


def _merge_base(repo: str, a: str, b: str) -> Optional[str]:
    proc = _git(repo, "merge-base", a, b)
    if not _ok(proc):
        return None
    return _text(proc.stdout).strip() or None


def _later_base(repo: str, sha: str, default_ref: str, end: str) -> Optional[str]:
    """두 merge-base 가운데 뒤의 것 — 기본 쪽이 끝 쪽의 조상이면 끝 쪽, 아니면 기본 쪽."""
    on_default = _merge_base(repo, sha, default_ref)
    on_end = _merge_base(repo, sha, end)
    if on_default is None or on_end is None:
        return on_end if on_default is None else on_default
    if on_default == on_end:
        return on_default
    anc = _git(repo, "merge-base", "--is-ancestor", on_default, on_end)
    return on_end if _ok(anc) else on_default


def _branch_entry(repo: str, name: str, sha: str, stamp: int, default_ref: str,
                  end: str) -> tuple:
    """`(항목 | None, 읽기 실패)` — 항목이 None 이고 실패가 아니면 다른 작업이 아니다."""
    ahead = _git(repo, "rev-list", "--max-count=1", sha, "--not", default_ref, end,
                 "--")
    if not _ok(ahead):
        return None, True
    if not ahead.stdout.strip():
        return None, False
    log = _git(repo, "log", "--no-merges", "--no-renames", "--format=", "--name-only", "-z",
               sha, "--not", default_ref, end, "--")
    if not _ok(log):
        return None, True
    paths = _z_paths(log.stdout)
    diff = _git(repo, "-c", "core.quotePath=false", "diff", "--no-color", "--no-ext-diff",
                "--no-textconv", "--no-renames", "--name-only", "-z", default_ref, sha,
                "--")
    if not _ok(diff):
        return None, True
    if not paths & _z_paths(diff.stdout):
        return None, False
    base = _later_base(repo, sha, default_ref, end)
    return {"name": name, "sha": sha, "time": stamp, "paths": paths, "base": base}, False


def other_work(repo: str, default_ref: str, end: str) -> tuple:
    """`(항목들, 읽지 못한 브랜치 수)` — 기본 브랜치에도 `end` 에도 없는 커밋을 가진 브랜치.

    항목 `{"name", "sha", "time", "paths", "base"}` 는 이름 순이다. git 이 실패한 브랜치는
    항목에 넣지 않고 수로 센다. 브랜치 목록부터 읽지 못하면(또는 rev 가 옵션 꼴이면) 수가
    None 이다 — 「셀 수 없음」 은 0 이 아니다.
    """
    if not _rev_ok(default_ref) or not _rev_ok(end):
        return [], None
    tips = _tips(repo)
    if tips is None:
        return [], None
    entries = []
    unreadable = 0
    for name, sha, stamp in sorted(tips):
        entry, failed = _branch_entry(repo, name, sha, stamp, default_ref, end)
        if failed:
            unreadable += 1
        elif entry is not None:
            entries.append(entry)
    return entries, unreadable


def mark_overlaps(branches: List[dict], names: Optional[set]) -> None:
    """항목마다 `"overlap"` — 바뀐 파일 목록(`names`)과 겹친 경로의 정렬된 목록."""
    for branch in branches:
        branch["overlap"] = sorted(branch["paths"] & names) if names is not None else []
