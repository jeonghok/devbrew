"""intent-critic 의 다른 팀 읽기 — 기본 브랜치 · 다른 작업(브랜치) 찾기 · 파일 겹침 · 팀 지도 ·
진행 중인 의도 문서 · 열린 PR · 상한 · 기록(`other-teams.md` 의 글).

git 은 `_git` 한 자리로만 부른다 — argv 목록(셸 없음) · `git -C <리포>`. 경로를 pathspec 으로
넘길 때는 `lit` 로 경로마다 `:(literal)` 접두를 붙인다(전역 `--literal-pathspecs` 는 쓰지 않는다).
rev 와 경로를 함께 받는 하위 명령(rev-list · log · diff · ls-tree)은 rev 뒤를 `--` 로 닫는다 — 작업
트리에 rev 와 같은 이름의 파일(`HEAD` · 기본 ref 경로)이 있어도 rev 로만 읽힌다. `log` 는
`--no-show-signature` 를 단다 — 사용자 설정 `log.showSignature` 가 서명 글을 출력에 섞지 않게. 파일 내용은
`intent_origin` 의 `read_tree` · `read_tracked`(추적되는 보통 파일만 · 링크 없음)로만 읽는다.
리포를 바꾸는 명령은 쓰지 않는다. 네트워크는 `open_prs` 의 열린 PR 목록 한 번뿐이다.
이 모듈은 `adjudication` 을 쓰지 않는다.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from typing import List, Optional

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import doc_paths  # noqa: E402
import intent_origin as io_  # noqa: E402

FILE = "other-teams.md"
HEAD_OVERLAP = "## 겹치는 곳"
HEAD_UNVERIFIED = "## 확인 못 함"
HEAD_MAP = "## 팀 지도"
HEAD_WORK = "## 다른 작업"
HEAD_CAP = "## 상한"
DIFF_LINES = 120
PR_TIMEOUT = io_.GIT_TIMEOUT
PR_LIMIT = 200

# `## 겹치는 곳` 의 빈 자리 줄 — 겹침을 다 보고 없었음 · 겹침을 정하지 못함(침묵과 0 은 다른 사실이다).
NO_OVERLAP = "- 겹침 없음"
OVERLAP_UNKNOWN = "- 겹침 확인 못 함"
NOTHING_UNVERIFIED = "- 없음"
LINE_NO_ROADMAP = "로드맵 없음"
LINE_NO_DEFAULT = "기본 브랜치를 찾지 못함 — 다른 브랜치와 다른 로드맵을 읽지 않았다"
LINE_NAMES_UNKNOWN = "바뀐 파일 목록을 몰라 파일 겹침을 확인 못 함"
LINE_REFS_UNREADABLE = "브랜치 목록을 읽지 못함 — 다른 브랜치를 읽지 않았다"
LINE_INTERVIEW = "인터뷰 단계의 팀은 확인 못 함 — 그 문서의 표시가 설정에 없다"
LINE_WORKTREES_UNREADABLE = "다른 worktree 를 확인 못 함 — worktree 목록을 읽지 못함"
LINE_NO_FETCH = "원격 브랜치를 새로 받지 않았다 — 오래됐을 수 있다"
LINE_UNSEEN = "다른 컴퓨터 · 올리지 않은 작업은 볼 수 없음"
# 브랜치 하나의 읽기가 예외로 끝남(그 브랜치만 빠진다) · 문서 머리가 YAML 로 읽히지 않음.
LINE_BRANCH_FAILED = "브랜치 %s 를 읽지 못함 — %s"
LINE_FRONTMATTER = "%s 의 %s 머리를 읽지 못함 — 의도 문서인지 확인 못 함"
LINE_NO_EPIC = "로드맵 %s 를 읽었지만 에픽 블록을 찾지 못함 — 글자 꼴이 다를 수 있다"
LINE_PR_LIMIT = "열린 PR 이 조회 상한에 닿아 일부를 못 봤을 수 있다"
LINE_DIVERGED = "같은 이름의 원격 사본이 갈라져 있다 — %s"
LINE_FOLDED = "같은 이름의 원격 사본 %d개를 로컬 브랜치와 한 작업으로 묶었다"
LINE_SIBLINGS = "토픽 리뷰의 형제 브랜치 %d개를 다른 팀에서 뺐다 — 이번 리뷰 범위다"
LINE_REVIEW_RECORDS = "리뷰 기록 %d개는 다른 팀 근거로 싣지 않았다"
LINE_TIMEOUTS = "git 읽기 %d번이 시간 한도 %d초를 넘겨 그 읽기를 확인 못 함"
LINE_DOC_TIMEOUT = "%s 의 %s 를 읽지 못함 — %s"
PR_NO_GH = "gh 없음"
PR_NO_ORIGIN = "origin 을 읽지 못함"
PR_TIMED_OUT = "시간 초과"
PR_BAD_REPLY = "gh 응답을 읽지 못함"
# 열린 PR 목록에서 읽는 칸 — 포크 PR 은 머리 브랜치 이름이 이 리포의 이름과 겹칠 수 있어 따로 가린다.
PR_FIELDS = "number,title,headRefName,isCrossRepository"

_EPIC_MARK = "- 의도:"
_EPIC_KEYS = (_EPIC_MARK, "- 범위:", "- 의존:", "- 경로 예약:")
_DECISIONS = "## 결정 기록"

ORIGIN_HEAD = "refs/remotes/origin/HEAD"
_REMOTES = "refs/remotes/"
_HEADS = "refs/heads/"
_SHORT_PREFIXES = ("refs/remotes/origin/", _HEADS, _REMOTES)


_TIMEOUTS = [0]  # 이 모듈의 git 호출 가운데 시간 한도를 넘긴 수 — `collect` 가 시작에 비운다


def _git(repo: str, *args: str):
    try:
        return subprocess.run(["git", "-C", repo] + list(args), capture_output=True,
                              timeout=PR_TIMEOUT)
    except subprocess.TimeoutExpired:
        _TIMEOUTS[0] += 1
        return io_.TIMED_OUT
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


def _ancestor(repo: str, older: str, newer: str) -> Optional[bool]:
    """`older` 가 `newer` 의 조상인가 — git 이 답하지 못하면(실패 · 시간 한도) None."""
    proc = _git(repo, "merge-base", "--is-ancestor", older, newer)
    if proc is None or proc.returncode not in (0, 1):
        return None
    return proc.returncode == 0


def _same_name_drops(repo: str, refs: List[tuple]) -> tuple:
    """같은 이름의 원격 사본을 가른다 → (버릴 ref 이름들, 묶은 수, 갈라진 로컬 이름들).

    원격이 로컬의 조상이면 원격을, 로컬이 원격의 조상이면 로컬을 버리고 묶음으로 센다. 서로
    조상이 아니면 원격을 버리고 로컬 이름을 갈라짐에 남긴다. git 이 답하지 못하면 둘 다 둔다.
    """
    local: dict = {}
    for ref, sha in refs:
        if ref.startswith(_HEADS):
            local[ref[len(_HEADS):]] = (ref, sha)
    drops: set = set()
    folded = 0
    diverged: set = set()
    for ref, sha in refs:
        if not ref.startswith(_REMOTES):
            continue
        _remote, _sep, name = ref[len(_REMOTES):].partition("/")
        if name not in local or local[name][1] == sha:
            continue
        local_ref, local_sha = local[name]
        remote_old = _ancestor(repo, sha, local_sha)
        if remote_old:
            drops.add(ref)
            folded += 1
        elif remote_old is None:
            continue
        else:
            local_old = _ancestor(repo, local_sha, sha)
            if local_old:
                drops.add(local_ref)
                folded += 1
            elif local_old is False:
                drops.add(ref)
                diverged.add(name)
    return drops, folded, sorted(diverged)


def _tips(repo: str, notes: Optional[dict] = None) -> Optional[List[tuple]]:
    """`(이름, sha, 시각)` — 끝 커밋 하나에 한 줄(로컬 브랜치 이름이 이긴다). 읽지 못하면 None.

    같은 이름의 원격 사본은 sha 로 접기 전에 가른다(`_same_name_drops`). `notes` 가 있으면
    `notes["folded"]`(묶은 수) · `notes["diverged"]`(갈라진 로컬 이름들)를 채운다.
    """
    proc = _git(repo, "for-each-ref",
                "--format=%(refname)%00%(objectname)%00%(committerdate:unix)",
                "refs/heads", "refs/remotes")
    if not _ok(proc):
        return None
    rows = []
    for line in _text(proc.stdout).split("\n"):
        fields = line.split("\0")
        if len(fields) != 3:
            continue
        if fields[0].startswith(_REMOTES) and fields[0].endswith("/HEAD"):
            continue
        rows.append(fields)
    drops, folded, diverged = _same_name_drops(repo, [(f[0], f[1]) for f in rows])
    if notes is not None:
        notes["folded"] = folded
        notes["diverged"] = diverged
    chosen = {}
    for ref, sha, when in rows:
        if ref in drops:
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
    log = _git(repo, "log", "--no-show-signature", "--no-merges", "--no-renames", "--format=",
               "--name-only", "-z", sha, "--not", default_ref, end, "--")
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


def other_work(repo: str, default_ref: str, end: str, notes: Optional[dict] = None) -> tuple:
    """`(항목들, 읽지 못한 브랜치 수)` — 기본 브랜치에도 `end` 에도 없는 커밋을 가진 브랜치.

    항목 `{"name", "sha", "time", "paths", "base"}` 는 이름 순이다. git 이 실패한 브랜치는
    항목에 넣지 않고 수로 센다. 브랜치 목록부터 읽지 못하면(또는 rev 가 옵션 꼴이면) 수가
    None 이다 — 「셀 수 없음」 은 0 이 아니다.
    """
    if not _rev_ok(default_ref) or not _rev_ok(end):
        return [], None
    tips = _tips(repo, notes)
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


# ---------------------------------------------------------------- 한 줄 값 · 팀 지도

def one_line(value: str) -> str:
    """기록의 머리 줄 · 앞 두 절에 쓰는 값 — 인쇄할 수 없는 글자(줄바꿈 · 짝 없는 surrogate 포함)는 `?`."""
    out = []
    for ch in value:
        out.append(ch if ch.isprintable() else "?")
    return "".join(out)


def _clean(text: str) -> str:
    """`\\n` · `\\t` 밖의 인쇄할 수 없는 글자(제어 · 방향 · 짝 없는 surrogate)를 `?` 로 — 근거 줄이 늘지 않고 기록 쓰기가 죽지 않게."""
    out = []
    for ch in text:
        out.append(ch if ch in "\n\t" or ch.isprintable() else "?")
    return "".join(out).encode("utf-8", "replace").decode("utf-8")


def _heading_depth(line: str) -> int:
    depth = len(line) - len(line.lstrip("#"))
    return depth if depth and line[depth:depth + 1] == " " else 0


def _epic_block_lines(block: List[str]) -> List[str]:
    """에픽 블록(`### ` 절)에서 머리 줄 · 의도 · 범위 · 의존 · 경로 예약 줄과 바로 딸린 들여쓴 줄."""
    out = [block[0]]
    keep = False
    for line in block[1:]:
        if line.startswith(_EPIC_KEYS):
            keep = True
            out.append(line)
        elif keep and line[:1] in (" ", "\t") and line.strip():
            out.append(line)
        else:
            keep = False
    return out


def _roadmap_parts(roadmap_text: str) -> tuple:
    """(에픽 블록들 — `- 의도:` 줄이 있는 `### ` 절, `## 결정 기록` 절의 줄들)."""
    epics: List[List[str]] = []
    decisions: List[str] = []
    current: Optional[List[str]] = None
    in_decisions = False
    for raw in roadmap_text.split("\n"):
        line = raw.rstrip("\r")
        depth = _heading_depth(line)
        if 0 < depth <= 2:
            current = None
            in_decisions = line.rstrip() == _DECISIONS
            if in_decisions:
                decisions.append(line)
            continue
        if in_decisions:
            decisions.append(line)
        elif depth == 3:
            current = [line]
            epics.append(current)
        elif current is not None:
            current.append(line)
    marked: List[List[str]] = []
    for block in epics:
        for line in block[1:]:
            if line.startswith(_EPIC_MARK):
                marked.append(block)
                break
    while decisions and not decisions[-1].strip():
        decisions.pop()
    return marked, decisions


def _map_body(marked: List[List[str]], decisions: List[str]) -> str:
    out: List[str] = []
    for block in marked:
        out.extend(_epic_block_lines(block))
    out.extend(decisions)
    return "".join(line + "\n" for line in out)


def epic_lines(roadmap_text: str) -> str:
    """로드맵의 에픽 블록(`- 의도:` 줄이 있는 `### ` 절)의 지도 줄 + `## 결정 기록` 절 통째."""
    return _map_body(*_roadmap_parts(roadmap_text))


def _unique(items) -> List[str]:
    out: List[str] = []
    for item in items:
        if item not in out:
            out.append(item)
    return out


def _commit_time(repo: str, rev: str, rel: str) -> int:
    """rev 에서 rel 을 마지막으로 바꾼 커밋의 시각(unix). 모르면 0."""
    if not _rev_ok(rev):
        return 0
    proc = _git(repo, "log", "--no-show-signature", "-1", "--format=%ct", rev, "--", lit(rel))
    if not _ok(proc):
        return 0
    try:
        return int(_text(proc.stdout).strip() or "0")
    except ValueError:
        return 0


def _siblings(listing: List[str], parent: str, filename: str) -> List[str]:
    """`<parent>/<폴더>/<filename>` 꼴의 경로만(폴더 한 마디)."""
    prefix = parent + "/" if parent else ""
    out: List[str] = []
    for path in listing:
        if not path.startswith(prefix):
            continue
        parts = path[len(prefix):].split("/")
        if len(parts) == 2 and parts[0] and parts[1] == filename:
            out.append(path)
    return out


def _listing(where: str, parent: str, *head: str) -> Optional[List[str]]:
    """`git <head…> -- :(literal)<parent>` 의 `-z` 이름 목록. 실패면 None."""
    args = list(head) + ["--"]
    if parent:
        args.append(lit(parent))
    proc = _git(where, *args)
    if not _ok(proc):
        return None
    return sorted(_z_paths(proc.stdout))


def _map_unit(head: str, rel: str, text: str, unverified: List[str]) -> tuple:
    """팀 지도 항목. 에픽 블록이 하나도 없으면 「확인 못 함」 에 그 로드맵을 남긴다."""
    marked, decisions = _roadmap_parts(text)
    if not marked:
        unverified.append(LINE_NO_EPIC % one_line(rel))
    return ("map", one_line(rel), "%s\n%s" % (head, _map_body(marked, decisions)))


def _team_maps(repo: str, tree_root: str, review_commit: str, roadmaps: List[str],
               default: Optional[tuple], unverified: List[str]) -> List[tuple]:
    """팀 지도 항목 `(종류, 이름, 글)` — 이번 로드맵(리뷰 트리) → 나란한 다른 로드맵."""
    units: List[tuple] = []
    read_ok: List[str] = []  # 신뢰 경계를 지난 로드맵만 나란한 폴더를 찾는 기준이 된다
    for rel in roadmaps:
        text, why = io_.read_tree(tree_root, rel)
        if text is None:
            unverified.append("로드맵 %s 를 읽지 못함 — %s" % (one_line(rel), why))
            continue
        read_ok.append(rel)
        units.append(_map_unit("### 이번 로드맵 %s (리뷰 트리)" % one_line(rel), rel, text,
                               unverified))
    if default is None:
        return units
    short, default_ref = default
    found = []  # (시각, 경로, 기본 브랜치에서인가)
    seen = set(roadmaps)
    for parent, filename in _unique(_parents(read_ok)):
        on_default = _listing(repo, parent, "ls-tree", "-r", "-z", "--name-only", default_ref)
        from_default = bool(on_default)
        listing = on_default if from_default else _listing(tree_root, parent, "ls-files", "-z")
        if listing is None:
            unverified.append("다른 로드맵을 찾지 못함 — %s 폴더 목록을 읽지 못함"
                              % one_line(parent or "."))
            continue
        for rel in _siblings(listing, parent, filename):
            if rel in seen:
                continue
            seen.add(rel)
            rev = default_ref if from_default else review_commit
            found.append((-_commit_time(repo, rev, rel), rel, from_default))
    for _when, rel, from_default in sorted(found):
        if from_default:
            text, why = io_.read_tracked(repo, default_ref, rel)
            where = "기본 브랜치 %s" % one_line(short)
        else:
            text, why = io_.read_tree(tree_root, rel)
            where = "리뷰 트리"
        if text is None:
            unverified.append("로드맵 %s 를 읽지 못함 — %s" % (one_line(rel), why))
            continue
        units.append(_map_unit("### 다른 로드맵 %s (%s)" % (one_line(rel), where), rel, text,
                               unverified))
    return units


def _parents(roadmaps: List[str]) -> List[tuple]:
    """로드맵마다 `(부모 폴더, 파일 이름)` — 폴더가 없는(리포 맨 위) 로드맵은 나란한 폴더가 없다."""
    out: List[tuple] = []
    for rel in roadmaps:
        folder, sep, filename = rel.rpartition("/")
        if not sep or not folder:
            continue
        parent = folder.rpartition("/")[0]
        out.append((parent, filename))
    return out


# ---------------------------------------------------------------- 열린 PR

def _parse_prs(raw: bytes) -> tuple:
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError, RecursionError):
        return None, PR_BAD_REPLY
    if not isinstance(data, list):
        return None, PR_BAD_REPLY
    out = []
    for item in data:
        if not isinstance(item, dict):
            return None, PR_BAD_REPLY
        number, title, branch = item.get("number"), item.get("title"), item.get("headRefName")
        fork = item.get("isCrossRepository")
        if isinstance(number, bool) or not isinstance(number, int):
            return None, PR_BAD_REPLY
        if not isinstance(title, str) or not isinstance(branch, str):
            return None, PR_BAD_REPLY
        if not isinstance(fork, bool):  # 포크인지 모르면 짐작하지 않는다
            return None, PR_BAD_REPLY
        out.append({"number": number, "title": title, "branch": branch, "fork": fork})
    return out, None


def open_prs(repo: str) -> tuple:
    """`(목록 | None, 사유 | None)` — 열린 PR 의 번호 · 제목 · 브랜치 이름 · 포크인가. gh 는 한 번, 30초 안에."""
    try:
        found = subprocess.run(["bash", os.path.join(HERE, "gh-repo.sh")], cwd=repo,
                               capture_output=True, stdin=subprocess.DEVNULL, timeout=PR_TIMEOUT)
    except (subprocess.TimeoutExpired, OSError, ValueError):
        return None, PR_NO_ORIGIN
    if found.returncode == 4:
        return None, PR_NO_GH
    origin = found.stdout.decode("utf-8", "replace").strip()
    if found.returncode != 0 or not origin or origin.startswith("-") or not io_.single_line(origin):
        return None, PR_NO_ORIGIN
    argv = ["gh", "pr", "list", "-R", origin, "--state", "open", "--json", PR_FIELDS, "--limit", str(PR_LIMIT)]
    try:
        proc = subprocess.run(argv, cwd=repo, capture_output=True, stdin=subprocess.DEVNULL,
                              timeout=PR_TIMEOUT)
    except subprocess.TimeoutExpired:
        return None, PR_TIMED_OUT
    except (OSError, ValueError):
        return None, PR_NO_GH
    if proc.returncode != 0:
        return None, "gh 실패(rc %d)" % proc.returncode
    return _parse_prs(proc.stdout)


def _names_by_tip(repo: str) -> Optional[dict]:
    """끝 커밋 → 그 커밋을 가리키는 브랜치 이름들(로컬 이름 · 원격 이름에서 원격 접두를 뗀 것)."""
    proc = _git(repo, "for-each-ref", "--format=%(refname)%00%(objectname)",
                "refs/heads", "refs/remotes")
    if not _ok(proc):
        return None
    names: dict = {}
    for line in _text(proc.stdout).split("\n"):
        ref, sep, sha = line.partition("\0")
        if not sep:
            continue
        if ref.startswith(_HEADS):
            name = ref[len(_HEADS):]
        elif ref.startswith(_REMOTES):
            _remote, sep, name = ref[len(_REMOTES):].partition("/")
            if not sep or not name or name == "HEAD":
                continue
        else:
            continue
        names.setdefault(sha, set()).add(name)
    return names


_UNREAD = object()  # `_attach_prs` 가 끝 커밋 이름표를 스스로 읽는다는 뜻(None 은 「읽지 못함」)


def _without_siblings(entries: List[dict], by_tip: Optional[dict], siblings: set) -> tuple:
    """(형제를 뺀 항목들, 뺀 수) — 항목 이름 · 그 끝 커밋을 가리키는 이름 가운데 하나가 형제면 뺀다."""
    kept: List[dict] = []
    removed = 0
    for entry in entries:
        aliases = {entry["name"]}
        if by_tip is not None:
            aliases |= by_tip.get(entry["sha"], set())
        if aliases & siblings:
            removed += 1
        else:
            kept.append(entry)
    return kept, removed


def _attach_prs(repo: str, entries: List[dict], prs: List[dict],
                by_tip=_UNREAD) -> List[int]:
    """항목마다 `"prs"` 를 단다. 끝 커밋이 같은 다른 이름(가려진 로컬 이름 · 원격 이름)도 견준다.

    돌려주는 것: 내용을 볼 수 없는 PR 번호들 — 포크 PR 전부(머리 이름이 이 리포의 이름과
    같아도 그 브랜치가 아니다), 그리고 브랜치가 이 리포의 어느 ref 에도 없는 PR.
    `"fork"` 가 없는 항목(주입한 목록)은 같은 리포의 PR 로 본다.
    """
    if by_tip is _UNREAD:
        by_tip = _names_by_tip(repo)
    known: set = set()
    if by_tip is not None:
        for names in by_tip.values():
            known |= names
    for entry in entries:
        aliases = {entry["name"]}
        if by_tip is not None:
            aliases |= by_tip.get(entry["sha"], set())
        entry["aliases"] = aliases
        entry["prs"] = []
        known |= aliases
    missing: List[int] = []
    for pr in sorted(prs, key=lambda p: p["number"]):
        if pr.get("fork", False):
            missing.append(pr["number"])
            continue
        hit = False
        for entry in entries:
            if pr["branch"] in entry["aliases"]:
                entry["prs"].append(pr)
                hit = True
        if not hit and pr["branch"] not in known:
            missing.append(pr["number"])
    return missing


def _pr_label(entry: dict, prs_known: bool) -> str:
    if not prs_known:
        return "열린 PR 확인 못 함"
    if not entry["prs"]:
        return "열린 PR 없음"
    labels = []
    for pr in entry["prs"]:
        labels.append(("PR #%d %s" % (pr["number"], one_line(pr["title"]))).rstrip())
    return " · ".join(labels)


# ---------------------------------------------------------------- 다른 작업 항목

def _intent_docs(repo: str, entry: dict, markers: List[str], unverified: List[str],
                 skipped: List[int]) -> List[tuple]:
    """그 브랜치 끝에서 읽은 의도 문서 `(경로, 글)` — 다른 작업이 바꾼 문서 파일 가운데.

    머리가 YAML 로 읽히지 않는 문서는 의도 문서로 세지 않고 「확인 못 함」 에 그 브랜치 · 경로를 남긴다.
    머리의 `type` 이 `roadmap-review` 인 리뷰 기록은 싣지 않고 `skipped[0]` 에 센다.
    """
    docs: List[tuple] = []
    for rel in sorted(entry["paths"]):
        # 「문서 파일」 은 넓이 판정(review_breadth)과 같은 뜻 — 모델이 읽는 파일은 빼고.
        if not doc_paths.is_doc_file(rel) or doc_paths.is_model_read(rel):
            continue
        text, why = io_.read_tracked(repo, entry["sha"], rel)
        if text is None:
            if why == io_.REASON_TIMEOUT:
                unverified.append(LINE_DOC_TIMEOUT % (one_line(entry["name"]), one_line(rel),
                                                      io_.REASON_TIMEOUT))
        elif io_.frontmatter_unreadable(text):
            unverified.append(LINE_FRONTMATTER % (one_line(entry["name"]), one_line(rel)))
        elif io_.frontmatter_value(text, "type") == "roadmap-review":
            skipped[0] += 1
        elif io_.is_intent_doc(text, markers):
            docs.append((rel, text))
    return docs


def _overlap_diff(repo: str, base: str, sha: str, rel: str) -> Optional[str]:
    """base..끝 의 그 파일 diff — DIFF_LINES 줄까지, 넘치면 `… <n>줄 더`. 읽지 못하면 None."""
    proc = _git(repo, "-c", "core.quotePath=false", "diff", "--no-color", "--no-ext-diff",
                "--no-textconv", "--no-renames", base, sha, "--", lit(rel))
    if not _ok(proc):
        return None
    lines = proc.stdout.decode("utf-8", "replace").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if len(lines) > DIFF_LINES:
        lines = lines[:DIFF_LINES] + ["… %d줄 더" % (len(lines) - DIFF_LINES)]
    return "".join(line + "\n" for line in lines)


def _with_newline(text: str) -> str:
    return text if not text or text.endswith("\n") else text + "\n"


def _branch_unit(repo: str, entry: dict, default_ref: str, prs_known: bool,
                 unverified: List[str]) -> tuple:
    name = one_line(entry["name"])
    stamp = time.strftime("%Y-%m-%d", time.gmtime(entry["time"]))
    parts = ["### %s · %s · %s · %s\n" % (name, entry["sha"][:7], stamp,
                                         _pr_label(entry, prs_known))]
    for rel, text in entry["docs"]:
        parts.append("#### 의도 문서 %s\n%s" % (one_line(rel), _with_newline(text)))
    base = entry["base"] or default_ref
    for rel in entry["overlap"]:
        diff = _overlap_diff(repo, base, entry["sha"], rel)
        if diff is None:
            unverified.append("%s 의 %s diff 를 읽지 못함" % (name, one_line(rel)))
            continue
        parts.append("#### 겹치는 파일 %s\n%s" % (one_line(rel), diff))
    return ("work", name, "".join(parts))


def _branch_failed(entry: dict, exc: Exception) -> str:
    return LINE_BRANCH_FAILED % (one_line(str(entry.get("name", "?"))), type(exc).__name__)


def _overlap_line(entry: dict, prs_known: bool) -> str:
    label = ""
    if prs_known and entry["prs"]:
        label = " · " + _pr_label(entry, prs_known)
    paths = []
    for rel in entry["overlap"]:
        paths.append(one_line(rel))
    return "%s%s — %s" % (one_line(entry["name"]), label, " · ".join(paths))


def _other_worktrees(repo: str, tree_root: str) -> Optional[int]:
    proc = _git(repo, "worktree", "list", "--porcelain")
    if not _ok(proc):
        return None
    mine = {os.path.realpath(repo), os.path.realpath(tree_root)}
    count = 0
    for line in _text(proc.stdout).split("\n"):
        if line.startswith("worktree ") and os.path.realpath(line[len("worktree "):]) not in mine:
            count += 1
    return count


def _interview_unmarked(markers: List[str]) -> bool:
    for marker in markers:
        if marker not in io_.DEFAULT_MARKERS:
            return False
    return True


# ---------------------------------------------------------------- 기록

def _cap(units: List[tuple], max_bytes: int) -> tuple:
    """순서대로 싣되 넘치는 항목은 건너뛰고 다음을 본다 → (실린 지도, 실린 작업, 상한 줄, 공시)."""
    maps: List[str] = []
    work: List[str] = []
    skipped: List[str] = []
    used = 0
    for kind, name, text in units:
        size = len(text.encode("utf-8"))
        if used + size > max_bytes:
            skipped.append(name)
            continue
        used += size
        (maps if kind == "map" else work).append(text)
    total = len(units)
    if skipped:
        line = "상한 %d바이트 — %d개 중 %d개만 실었다(뺀 것: %s)" % (
            max_bytes, total, total - len(skipped), " · ".join(skipped))
        return maps, work, line, [line]
    return maps, work, "상한 %d바이트 안에 %d개를 모두 실었다" % (max_bytes, total), []


def _section(head: str, lines: List[str], empty_line: str) -> str:
    """머리 + `- <줄>` 들. 줄이 없으면 `empty_line`(이미 `- ` 가 붙은 줄) 하나."""
    if not lines:
        return "%s\n%s\n" % (head, empty_line)
    return head + "\n" + "".join("- %s\n" % line for line in lines)


def collect(repo: str, tree_root: str, review_commit: str, names: Optional[set],
            roadmaps: List[str], markers: List[str], max_bytes: int, list_prs=open_prs,
            siblings: Optional[set] = None) -> dict:
    """다른 팀 기록 → `{"text": 기록 글, "notices": 공시 줄}`. 파일을 쓰지 않는다.

    git 실패는 값으로 다룬다 — 읽지 못한 것은 「확인 못 함」 줄이 된다.
    """
    _TIMEOUTS[0] = 0
    names = set(names) if names is not None else None
    roadmaps = _unique(roadmaps)
    unverified: List[str] = []
    if not roadmaps:
        unverified.append(LINE_NO_ROADMAP)
    default = default_branch(repo)
    units = _team_maps(repo, tree_root, review_commit, roadmaps, default, unverified)
    overlapped: List[dict] = []
    rest: List[dict] = []
    plain = 0
    notes: dict = {"folded": 0, "diverged": []}
    dropped_siblings = 0
    review_records = [0]
    prs_known = False
    overlap_known = False  # 기본 브랜치 · 브랜치 목록 · 바뀐 파일 목록이 모두 있어야 「겹침 없음」 이라 말한다
    if default is None:
        unverified.append(LINE_NO_DEFAULT)
    else:
        entries, unreadable = other_work(repo, default[1], review_commit, notes)
        overlap_known = unreadable is not None and names is not None
        if unreadable is None:
            unverified.append(LINE_REFS_UNREADABLE)
        elif unreadable:
            unverified.append("읽지 못한 브랜치 %d개" % unreadable)
        if names is None:
            unverified.append(LINE_NAMES_UNKNOWN)
        for name in notes["diverged"]:
            unverified.append(LINE_DIVERGED % one_line(name))
        by_tip = _names_by_tip(repo) if unreadable is not None else None
        if siblings:
            entries, dropped_siblings = _without_siblings(entries, by_tip, siblings)
        mark_overlaps(entries, names)
        prs, why = list_prs(repo)
        prs_known = prs is not None
        if not prs_known:
            unverified.append("열린 PR 확인 못 함 — %s" % one_line(str(why)))
        elif len(prs) >= PR_LIMIT:
            unverified.append(LINE_PR_LIMIT)
        for number in _attach_prs(repo, entries, prs or [], by_tip):
            unverified.append("PR #%d 내용 확인 못 함 — 그 브랜치가 이 리포에 없다" % number)
        for entry in entries:
            try:
                entry["docs"] = _intent_docs(repo, entry, markers, unverified, review_records)
            except Exception as exc:  # noqa: BLE001 — 브랜치 하나의 실패가 기록 전체를 지우지 않게
                entry["docs"] = []
                unverified.append(_branch_failed(entry, exc))
            if entry["overlap"]:
                overlapped.append(entry)
            elif entry["docs"]:
                rest.append(entry)
            else:
                plain += 1
        overlapped.sort(key=lambda e: (-len(e["overlap"]), -e["time"], e["name"]))
        rest.sort(key=lambda e: (-e["time"], e["name"]))
        for entry in overlapped + rest:
            try:
                units.append(_branch_unit(repo, entry, default[1], prs_known, unverified))
            except Exception as exc:  # noqa: BLE001 — 같은 까닭(시각이 터무니없는 커밋 등)
                unverified.append(_branch_failed(entry, exc))
    if _interview_unmarked(markers):
        unverified.append(LINE_INTERVIEW)
    worktrees = _other_worktrees(repo, tree_root)
    if worktrees is None:
        unverified.append(LINE_WORKTREES_UNREADABLE)
    elif worktrees:
        unverified.append("다른 worktree %d개의 커밋 안 된 작업은 읽지 않았다" % worktrees)
    if _TIMEOUTS[0]:
        unverified.append(LINE_TIMEOUTS % (_TIMEOUTS[0], io_.GIT_TIMEOUT))
    unverified.extend((LINE_NO_FETCH, LINE_UNSEEN))

    clean_units: List[tuple] = []
    for kind, name, text in units:
        clean_units.append((kind, _clean(name), _clean(text)))
    maps, work, cap_line, notices = _cap(clean_units, max(0, int(max_bytes)))
    overlap_lines: List[str] = []
    for entry in overlapped:
        overlap_lines.append(_overlap_line(entry, prs_known))
    parts = [_section(HEAD_OVERLAP, overlap_lines, NO_OVERLAP if overlap_known else OVERLAP_UNKNOWN),
             _section(HEAD_UNVERIFIED, unverified, NOTHING_UNVERIFIED),
             HEAD_MAP + "\n"] + maps + [HEAD_WORK + "\n"] + work
    if plain:
        parts.append("그 밖의 브랜치 %d개 — 겹침 · 의도 문서 없음\n" % plain)
    if notes["folded"]:
        parts.append(LINE_FOLDED % notes["folded"] + "\n")
    if dropped_siblings:
        parts.append(LINE_SIBLINGS % dropped_siblings + "\n")
    if review_records[0]:
        parts.append(LINE_REVIEW_RECORDS % review_records[0] + "\n")
    parts.append("%s\n%s\n" % (HEAD_CAP, cap_line))
    return {"text": _clean("".join(parts)), "notices": notices}


def summary(text: str) -> tuple:
    """`(겹치는 곳 줄들, 확인 못 함 줄들)` — `HEAD_MAP` 줄 앞까지만 읽는다(본문의 머리 흉내를 보지 않는다)."""
    overlap: List[str] = []
    unverified: List[str] = []
    target = None
    for raw in text.split("\n"):
        line = raw.rstrip("\r")
        if line == HEAD_MAP:
            break
        if line == HEAD_OVERLAP:
            target = overlap
        elif line == HEAD_UNVERIFIED:
            target = unverified
        elif target is not None and line.strip():
            target.append(line)
    return overlap, unverified
