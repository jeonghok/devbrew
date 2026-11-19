#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_branch.py — 지휘자 상태 브랜치(`conductor/<로드맵 폴더 이름>`)의 이름 · 쓸 수 있는지 판정 · 읽기.

작업 폴더 · index · HEAD 를 쓰지 않는다 — 읽기는 읽기 하위 명령으로, 쓰기는 임시 index 위의 배관 명령(`GIT_ALLOWED`)으로
커밋 하나를 만들어 ref 를 옮기고 올린다. 뒤 과제가 다시 만들기와 명령줄 `delete` 를 더한다.

종료 코드: 0 · 1(없음/아님) · 2 사용법 · 3 읽기 불가 · 5 다른 세션의 표지.

가져오는 모듈은 `conductor_state` · `repo_defaults` · `state_path` · `team_layout` · `branch_tip` · `roadmap_model` 뿐이다.
"""
from __future__ import annotations

import datetime
import json
import os
import re
import socket
import argparse
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path
from typing import Callable, NamedTuple, Optional

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import branch_tip  # noqa: E402
import conductor_state as cs  # noqa: E402
import repo_defaults  # noqa: E402
import roadmap_model  # noqa: E402
import state_path  # noqa: E402
import team_layout  # noqa: E402

STATE_BRANCH_PREFIX = "conductor/"
NAME_RE = re.compile(r"[a-z0-9][a-z0-9.-]*")
RECEIVED_FILE = "received.md"
PENDING_FILE = "pending.md"
OFF_NOTE = "상태 브랜치가 꺼져 있다"
RULE_REFUSES = "이 레포의 브랜치 규칙이 conductor/ 를 받지 않는다 — 규칙 문서에 갈래를 더하거나 state_branch 를 끈다"
RULE_UNREADABLE = "브랜치 규칙을 읽지 못했다"
SETTINGS_UNREADABLE = "레포 설정을 읽지 못해 상태 브랜치를 쓰지 않는다"
NO_BRANCH = "상태 브랜치 없음"
RULE_VERDICTS = ("없음", "규칙", "읽지 못함")
DONE_STAGES = ("머지됨", "끝남")
GIT_ALLOWED = frozenset({"rev-parse", "cat-file", "ls-tree", "for-each-ref", "config",
                         "hash-object", "read-tree", "update-index", "write-tree", "commit-tree", "update-ref", "push"})
CONFIG_READ_FORMS = ("--get", "--get-all", "--get-regexp")   # `config` 는 읽는 꼴만 받는다 — 쓰는 꼴은 허용 밖이다
NOT_PUSHED = "아직 안 올라옴"
ZERO_OID = "0" * 40
WRITE_ATTEMPTS = 3
PUSH_TIMEOUT = 120
_NO_STATUS = "상태 계산 출력을 읽지 못했다(rc %d)"


class BranchError(Exception):
    def __init__(self, rc: int, msg: str):
        super().__init__(msg)
        self.rc = rc


# ── git ──────────────────────────────────────────────────────────────────────

def _run(root, *args, env=None, data=None, timeout=None) -> tuple:
    """(rc, stdout 바이트, stderr 바이트). 허용 목록 밖 하위 명령은 RuntimeError."""
    if not args or args[0] not in GIT_ALLOWED:
        raise RuntimeError("허용하지 않는 git 하위 명령: %r" % (args[:1],))
    if args[0] == "config" and args[1:2] not in tuple((f,) for f in CONFIG_READ_FORMS):
        raise RuntimeError("git config 는 읽는 꼴만 부른다: %r" % (args,))
    full = dict(os.environ)   # 부를 때의 환경 — import 때 굳히지 않는다
    full.update(env or {})
    full["LC_ALL"] = "C"
    full["GIT_TERMINAL_PROMPT"] = "0"
    if isinstance(data, str):
        data = data.encode("utf-8")
    try:
        p = subprocess.run(["git", "-c", "core.quotePath=false", *args], cwd=str(root), env=full, input=data,
                           capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, b"", "git 이 시간 안에 끝나지 않았다".encode("utf-8")
    except OSError as exc:
        return 127, b"", ("git 을 부르지 못했다(%s)" % type(exc).__name__).encode("utf-8")
    return p.returncode, p.stdout, p.stderr


def git(root, *args, env=None, data=None, timeout=None) -> tuple:
    """(rc, stdout, stderr) — 글로 푼 git 호출. 허용 목록(GIT_ALLOWED) 밖이면 RuntimeError."""
    rc, out, err = _run(root, *args, env=env, data=data, timeout=timeout)
    return rc, out.decode("utf-8", "replace"), err.decode("utf-8", "replace")


# ── 이름 ─────────────────────────────────────────────────────────────────────

def name_ok(name: str) -> bool:
    """상태 브랜치 이름으로 쓸 수 있는 폴더 이름인가 — git 이 ref 로 받지 않는 꼴(`..` · `.lock` · 끝 `.`)도 거른다."""
    return (isinstance(name, str) and NAME_RE.fullmatch(name) is not None and ".." not in name
            and not name.endswith(".lock") and not name.endswith("."))


def branch_of(name: str) -> str:
    return STATE_BRANCH_PREFIX + name


def ref_of(name: str) -> str:
    return "refs/heads/" + branch_of(name)


def roadmap_name(roadmap_rel: str) -> str:
    """로드맵 폴더 이름 — 경로의 끝에서 둘째 성분(`conductor_state.machine_dir` 와 같은 규칙)."""
    try:
        return cs.machine_dir(Path("."), roadmap_rel).name
    except cs.MachineError as exc:
        raise BranchError(2, str(exc))


def _roadmaps_dir(root) -> str:
    try:
        result = repo_defaults.resolve(str(root))
    except repo_defaults.SettingsError as exc:
        raise BranchError(3, str(exc))
    if result["errors"] or not result["values"].get("roadmaps_dir"):
        raise BranchError(3, "%s — %s" % (SETTINGS_UNREADABLE, (result["errors"] or ["로드맵 폴더 값이 없다"])[0]))
    return result["values"]["roadmaps_dir"]


def team_of(root, roadmap_rel: str) -> team_layout.Team:
    """해결자의 `roadmaps_dir` 과 로드맵 폴더 이름으로 Team. 로드맵이 그 폴더 바로 아래 폴더 한 단계 안이 아니면 BranchError(2)."""
    folder = _roadmaps_dir(root)
    parts = roadmap_rel[len(folder):].split("/") if roadmap_rel.startswith(folder) else []
    if len(parts) != 2 or not parts[0] or not parts[1]:
        raise BranchError(2, "로드맵이 로드맵 폴더(%s) 바로 아래 폴더 한 단계 안이 아니다: %s" % (folder, roadmap_rel))
    reserved = team_layout.ROLES + (team_layout.INBOX_DIR, team_layout.INTENT_DIR, team_layout.JOBS_DIR, team_layout.RESULTS_DIR)
    if not name_ok(parts[0]) or parts[0] in reserved:
        raise BranchError(2, "로드맵 폴더 이름 %s 은 팀 폴더 이름으로 쓸 수 없다: %s" % (visible(parts[0]), visible(roadmap_rel)))
    return team_layout.Team(folder, parts[0])


# ── 글 ───────────────────────────────────────────────────────────────────────

def visible(text: str) -> str:
    """제어 글자 · 서식 글자 · 줄 가름 글자 · 짝 없는 surrogate · 사용자 영역 글자를 보이는 글자(`\\x..` · `\\u....` · `\\U........`)로 바꾼다. 탭은 그대로다."""
    out = []
    for ch in text:
        if ch != "\t" and unicodedata.category(ch) in ("Cc", "Cf", "Zl", "Zp", "Cs", "Co"):
            code = ord(ch)
            out.append("\\x%02x" % code if code < 0x100 else "\\u%04x" % code if code <= 0xFFFF else "\\U%08x" % code)
        else:
            out.append(ch)
    return "".join(out)


def redact(text: str) -> str:
    """올리기 실패 사유에서 원격 주소(`://` 가 든 낱말 · `이름@호스트:경로`)와 절대경로(`/` 로 시작해 `/` 가 둘 이상)를 가린다."""
    out = []
    for tok in re.split(r"""(\s+|['"])""", text):
        if tok and not tok.isspace() and tok not in ("'", '"'):
            if "://" in tok or re.fullmatch(r"[^\s@/:]+@[^\s/:]+:\S*", tok):
                tok = "<원격>"
            elif tok.startswith("/") and tok.count("/") >= 2:
                tok = "<경로>"
        out.append(tok)
    return "".join(out)


def machine_pattern() -> Optional[re.Pattern]:
    """이 기계의 이름(온 이름 · 첫 점 앞 이름, 세 글자 이상)을 낱말로 찾는 정규식. 쓸 이름이 없으면 None."""
    full = socket.gethostname().strip()
    names = []
    for cand in (full, full.split(".", 1)[0]):   # 온 이름이 먼저다 — 짧은 이름이 온 이름을 가로채지 않게
        if len(cand) >= 3 and cand not in names:
            names.append(cand)
    if not names:
        return None
    alts = "|".join(re.escape(n) for n in names)
    return re.compile(r"(?<![A-Za-z0-9])(?:%s)(?![A-Za-z0-9])" % alts, re.IGNORECASE)


# ── 시각 ─────────────────────────────────────────────────────────────────────

def stamp(now: Optional[datetime.datetime] = None) -> str:
    """`YYYY-MM-DD HH:MM ±HHMM`. 시간대 없는 값은 ValueError."""
    if now is None:
        now = datetime.datetime.now().astimezone()
    if now.utcoffset() is None:
        raise ValueError("시간대 없는 시각은 적지 않는다")
    return now.strftime("%Y-%m-%d %H:%M %z")


def parse_stamp(text) -> Optional[datetime.datetime]:
    """꼴(STAMP_RE 전체)이 맞고 달력 · 시계에 있는 값이면 시간대 있는 시각, 아니면 None — 예외를 내지 않는다."""
    if not isinstance(text, str) or cs.STAMP_RE.fullmatch(text) is None:
        return None
    try:
        return datetime.datetime.strptime(text, "%Y-%m-%d %H:%M %z")
    except (ValueError, OverflowError):
        return None


# ── 쓸 수 있는지 ─────────────────────────────────────────────────────────────

def _default_commit(root) -> Optional[str]:
    return branch_tip.resolve(root, roadmap_model.DEFAULT_REF)


def _origin_exists(root) -> Optional[bool]:
    rc, _o, _e = git(root, "config", "--get", "remote.origin.url")
    if rc == 0:
        return True
    return False if rc == 1 else None


def branch_rule(root) -> tuple:
    """("없음", None) · ("규칙", 컴파일한 정규식) · ("읽지 못함", 사유 한 줄) — 기본 브랜치 판의 브랜치 규칙 문서."""
    commit = _default_commit(root)
    if commit is None:
        origin = _origin_exists(root)
        if origin is False:
            return "없음", None   # 올릴 곳이 없어 로컬에만 쓴다
        return "읽지 못함", "기본 브랜치(origin/HEAD)를 모른다 — git remote set-head origin --auto"
    rc, out, _e = _run(root, "ls-tree", "-z", commit, "--", repo_defaults.BRANCH_RULE_FILE)
    entry = out.split(b"\0")[0].decode("utf-8", "replace")
    if rc != 0:
        return "읽지 못함", "기본 브랜치의 %s 목록을 읽지 못했다" % repo_defaults.BRANCH_RULE_FILE
    if not entry:
        return "없음", None
    sha = entry.split("\t", 1)[0].split(" ")[-1]
    rc, blob, _e = _run(root, "cat-file", "blob", sha)
    if rc != 0:
        return "읽지 못함", "기본 브랜치의 %s 를 읽지 못했다" % repo_defaults.BRANCH_RULE_FILE
    try:
        content = blob.decode("utf-8")
    except UnicodeDecodeError:
        return "읽지 못함", "%s 가 UTF-8 글이 아니다" % repo_defaults.BRANCH_RULE_FILE
    match = re.search(r"```regex\n(.+?)\n```", content)   # project-init 훅과 같은 읽기
    if not match or not match.group(1).strip():
        return "읽지 못함", "%s 에 쓸 수 있는 regex 블록이 없다" % repo_defaults.BRANCH_RULE_FILE
    try:
        return "규칙", re.compile(match.group(1).strip())
    except re.error as exc:
        return "읽지 못함", "%s 의 regex 를 컴파일하지 못했다(%s)" % (repo_defaults.BRANCH_RULE_FILE, exc)


def _first_line(text) -> str:
    return (str(text).strip().splitlines() or [""])[0]


def _settings_file_exists(root) -> bool:
    if os.path.lexists(os.path.join(str(root), repo_defaults.SETTINGS_FILE)):
        return True
    rc, _o, _e = git(root, "cat-file", "-e", "HEAD:" + repo_defaults.SETTINGS_FILE)
    return rc == 0


def _settings_verdict(root) -> Optional[str]:
    """설정 단계 — 쓸 수 있으면 None, 아니면 알릴 줄."""
    try:
        result = repo_defaults.resolve(str(root))
    except repo_defaults.SettingsError as exc:
        return "%s — %s" % (SETTINGS_UNREADABLE, _first_line(exc))
    except Exception as exc:   # 설정 읽기의 어떤 예외도 닫는 쪽이다
        return "%s — %s: %s" % (SETTINGS_UNREADABLE, type(exc).__name__, _first_line(exc))
    if result["errors"]:
        return "%s — %s" % (SETTINGS_UNREADABLE, _first_line(result["errors"][0]))
    if result["sources"].get("state_branch") == repo_defaults._no_ref_label and _settings_file_exists(root):
        why = result["notices"][0] if result["notices"] else "기본 브랜치를 알 수 없어 설정 파일을 읽지 못했다"
        return "%s — %s" % (SETTINGS_UNREADABLE, _first_line(why))
    if result["values"].get("state_branch") == repo_defaults.STATE_BRANCH_OFF:
        return OFF_NOTE
    if not repo_defaults.state_branch_on(result["values"]):
        return "%s — state_branch 값을 알 수 없다" % SETTINGS_UNREADABLE
    return None


def availability(root, roadmap_rel: str) -> Optional[str]:
    """쓸 수 있으면 None, 아니면 알릴 줄 하나. 예외를 던지지 않는다."""
    try:
        why = _settings_verdict(root)
        if why:
            return why
        name = roadmap_name(roadmap_rel)
        if not name_ok(name):
            return ("로드맵 폴더 이름 %s 은 상태 브랜치 이름으로 쓸 수 없다 — 소문자 · 숫자 · 하이픈 · 점만 받고, "
                    "`..` 를 담거나 `.lock` · `.` 으로 끝나면 안 된다" % name)
        kind, value = branch_rule(root)
        if kind == "읽지 못함":
            return "%s — %s — 규칙 문서를 고치거나 state_branch 를 끈다" % (RULE_UNREADABLE, value)
        if kind == "규칙" and not value.match(branch_of(name)):
            return RULE_REFUSES
        return None
    except BranchError as exc:
        return str(exc)
    except Exception as exc:   # 판정하지 못하면 쓰지 않는다
        return "%s — %s: %s" % (SETTINGS_UNREADABLE, type(exc).__name__, _first_line(exc))


# ── 읽기 ─────────────────────────────────────────────────────────────────────

def local_tip(root, name: str) -> Optional[str]:
    return branch_tip.resolve(root, ref_of(name))


def seen_tip(root, name: str) -> tuple:
    """(읽을 끝, 사유). 로컬과 origin 추적 ref 가운데 앞선 쪽 끝을 읽는다 — 갈라졌을 때만 (None, 사유)."""
    try:
        tip, _note = branch_tip.tip(root, branch_of(name))   # 한쪽이 앞선 것은 읽지 않을 이유가 아니다
    except branch_tip.TipError as exc:
        return None, str(exc)
    return tip, None


def state_names(root) -> list:
    """로컬이나 origin 추적 ref 에 `conductor/` 브랜치가 있는 이름들(정렬)."""
    rc, out, _e = git(root, "for-each-ref", "--format=%(refname)", "refs/heads/" + STATE_BRANCH_PREFIX,
                      "refs/remotes/origin/" + STATE_BRANCH_PREFIX)
    found = set()
    if rc == 0:
        for line in out.splitlines():
            for head in ("refs/heads/" + STATE_BRANCH_PREFIX, "refs/remotes/origin/" + STATE_BRANCH_PREFIX):
                if line.startswith(head) and name_ok(line[len(head):]):   # 남이 올린 꼬리는 꼴 밖이면 내지 않는다
                    found.add(line[len(head):])
    return sorted(found)


def read(root, commit: str, path: str) -> Optional[str]:
    rc, out, _e = git(root, "cat-file", "blob", "%s:%s" % (commit, path))
    return out if rc == 0 else None


def names(root, commit: str, prefix: str) -> list:
    """[(mode, 경로)] — 그 폴더 아래 전부. 폴더가 없으면 빈 목록."""
    rc, out, _e = git(root, "ls-tree", "-r", "-z", commit, "--", prefix)
    if rc != 0:
        return []
    found = []
    for entry in (e for e in out.split("\0") if e):
        meta, _tab, path = entry.partition("\t")
        found.append((meta.split(" ")[0], path))
    return found


def roadmap_paths(root) -> dict:
    """기본 브랜치의 로드맵 전부(끝난 것도)의 {폴더 이름: 로드맵 경로}. 읽지 못한 후보도 든다(끝난 것으로 치지 않으려고).
    상태 계산을 부르지 않는다. 기본 브랜치를 모르면 BranchError(3)."""
    commit = _default_commit(root)
    if commit is None:
        origin = _origin_exists(root)
        raise BranchError(3, roadmap_model.NO_ORIGIN if origin is False else roadmap_model.NO_DEFAULT)
    folder = _roadmaps_dir(root)
    rc, out, err = _run(root, "ls-tree", "-r", "-z", commit, "--", folder)
    if rc != 0:
        raise BranchError(3, "기본 브랜치의 로드맵 목록을 읽지 못했다: %s" % _first_line(err.decode("utf-8", "replace")))
    entries = roadmap_model.tree_entries(out, folder)

    def cat(sha):
        c_rc, c_out, _c_err = _run(root, "cat-file", "blob", sha)
        return c_rc, c_out
    found, unchecked = roadmap_model.find_roadmaps(list(entries), roadmap_model.blob_reader(entries, cat, set()), folder)
    table = {}
    for path in found + [p for p, _why in unchecked]:
        try:
            table.setdefault(roadmap_name(path), path)
        except BranchError:
            continue
    return table


class Roadmap(NamedTuple):
    name: str
    path: str
    report: Optional[dict]
    why: Optional[str]
    unfinished: bool


def roadmaps(root) -> list:
    """roadmap_paths 의 로드맵마다 `roadmap_status.py --json` 을 하위 프로세스로 불러 채운다(이름순)."""
    rows = []
    for name, path in sorted(roadmap_paths(root).items()):
        p = subprocess.run([sys.executable, str(HERE / "roadmap_status.py"), "--json", path], cwd=str(root),
                           capture_output=True, encoding="utf-8", errors="replace")
        report, why = None, _NO_STATUS % p.returncode
        try:
            rep = json.loads(p.stdout)
            blocks = rep.get("blocks") or []
            if any(b.get("stage") for b in blocks):
                report, why = rep, None
            else:
                reasons = list(rep.get("unknown_reasons") or []) + list(rep.get("format_errors") or [])
                why = _first_line(reasons[0]) if reasons else "단계가 하나도 나오지 않았다"
        except (ValueError, AttributeError):
            pass
        unfinished = report is None or any(b.get("stage") not in DONE_STAGES for b in report["blocks"])
        rows.append(Roadmap(name, path, report, why, unfinished))
    return rows


# ── 쓰기 ─────────────────────────────────────────────────────────────────────

class Base(NamedTuple):
    commit: Optional[str]
    read: Callable[[str], Optional[str]]
    names: Callable[[str], list]


class Result(NamedTuple):
    commit: Optional[str]
    pushed: bool
    onto: Optional[str]
    notes: tuple


def _base(root, commit: Optional[str]) -> Base:
    if commit is None:
        return Base(None, lambda path: None, lambda prefix: [])
    return Base(commit, lambda path: read(root, commit, path), lambda prefix: names(root, commit, prefix))


def _need_marker(root, roadmap_rel: str, session: str) -> None:
    """지휘 표지를 쥔 세션만 쓴다. 아니면 BranchError(5)."""
    d = cs.machine_dir(state_path.state_root(str(root)), roadmap_rel)
    owner = cs.holder(d)
    if owner is None:
        raise BranchError(5, "이 로드맵의 지휘 표지를 잡지 않았다 — 지휘 세션만 상태 브랜치에 쓴다")
    if owner != session:
        raise BranchError(5, "다른 세션(%s)이 이 로드맵을 지휘하고 있다 — 그 세션만 상태 브랜치에 쓴다" % visible(owner[:8]))


def _check_paths(team: team_layout.Team, changes: dict) -> None:
    """낸 경로가 모두 로드맵 폴더 아래의 보통 경로인지 — 아니면 아무것도 쓰기 전에 BranchError(3)."""
    for path, text in changes.items():
        parts = path.split("/") if isinstance(path, str) else []
        if (not isinstance(path, str) or not path.startswith(team.dir + "/") or "\0" in path
                or any(p in ("", ".", "..", ".git") for p in parts) or not (text is None or isinstance(text, str))):
            raise BranchError(3, "상태 브랜치에는 로드맵 폴더 아래만 쓴다: %s" % visible(str(path)))


def _git_fail(err: str, what: str) -> BranchError:
    return BranchError(3, "%s: %s" % (what, visible(_first_line(err))))


def _build_commit(root, tip: Optional[str], changes: dict, message: str, force: bool) -> Optional[str]:
    """임시 index 위에서 커밋 하나를 만든다. 트리가 끝의 트리와 같으면(force 가 아닐 때) None."""
    tmp = tempfile.mkdtemp(prefix="conductor-index-")
    try:
        env = {"GIT_INDEX_FILE": os.path.join(tmp, "index")}
        if tip:
            rc, _o, err = git(root, "read-tree", tip, env=env)
            if rc:
                raise _git_fail(err, "상태 브랜치의 트리를 읽지 못했다")
        for path, text in sorted(changes.items()):
            if text is None:
                rc, _o, err = git(root, "update-index", "--force-remove", "--", path, env=env)
            else:
                rc, blob, err = git(root, "hash-object", "-w", "--stdin", env=env, data=text)
                if rc == 0:
                    rc, _o, err = git(root, "update-index", "--add", "--replace", "--cacheinfo",
                                      "100644,%s,%s" % (blob.strip(), path), env=env)
            if rc:
                raise _git_fail(err, "상태 브랜치에 쓸 글을 만들지 못했다")
        rc, tree, err = git(root, "write-tree", env=env)
        if rc:
            raise _git_fail(err, "상태 브랜치의 트리를 만들지 못했다")
        tree = tree.strip()
        if tip and not force:
            rc, old, _e = git(root, "rev-parse", tip + "^{tree}")
            if rc == 0 and old.strip() == tree:
                return None
        args = ["commit-tree", tree, "-m", message] + (["-p", tip] if tip else [])
        rc, commit, err = git(root, *args)
        if rc:
            raise BranchError(3, "커밋을 만들지 못했다 — git 이름이 없다. git config user.name · user.email 을 정한다: %s"
                              % visible(_first_line(err)))
        return commit.strip()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _push(root, name: str) -> tuple:
    """(올렸는가, 알릴 줄들). origin 이 없거나 거절돼도 쓴 커밋은 로컬에 남는다."""
    if _origin_exists(root) is not True:
        return False, (NOT_PUSHED + " — 올릴 원격이 없다",)
    ref = ref_of(name)
    rc, out, err = git(root, "push", "--porcelain", "origin", "%s:%s" % (ref, ref), timeout=PUSH_TIMEOUT)
    if rc == 0:
        return True, ()
    return False, ("%s — %s" % (NOT_PUSHED, redact(_first_line(err) or _first_line(out) or "git push 가 실패했다")),)


def _write_floor(root, roadmap_rel: str, session: str, edit, what: str, creating: bool) -> Result:
    team = team_of(root, roadmap_rel)
    _need_marker(root, roadmap_rel, session)
    why = availability(root, roadmap_rel)
    if why:
        return Result(None, False, None, (why,))
    name = team.name
    tip = local_tip(root, name)
    if tip is None and not creating:
        raise BranchError(1, "상태 브랜치가 없다 — 먼저 ensure 를 돌린다")
    message = "chore(conductor): %s · 세션 %s" % (" ".join(what.split()), session[:8])
    for _attempt in range(WRITE_ATTEMPTS):
        changes = {} if creating else edit(_base(root, tip))
        if not changes and not creating:
            return Result(None, False, None, ())
        _check_paths(team, changes)
        commit = _build_commit(root, tip, changes, message, creating)
        if commit is None:
            return Result(None, False, None, ())
        rc, _o, err = git(root, "update-ref", ref_of(name), commit, tip or ZERO_OID)
        if rc == 0:
            pushed, notes = _push(root, name)
            return Result(commit, pushed, None, notes)
        now = local_tip(root, name)
        if now == tip:   # 끝은 그대로인데 실패했다 — 이름 충돌 같은 일이다
            raise _git_fail(err, "상태 브랜치 ref 를 옮기지 못했다")
        tip = now
        if tip is None and not creating:
            raise BranchError(1, "상태 브랜치가 없다 — 먼저 ensure 를 돌린다")
    raise BranchError(3, "상태 브랜치 끝이 계속 바뀌어 %d 번 만에 쓰지 못했다 — 잠시 뒤 다시 돈다" % WRITE_ATTEMPTS)


def write(root, roadmap_rel: str, session: str, edit: Callable[[Base], Optional[dict]], what: str) -> Result:
    """`edit` 가 돌려준 {경로: 글 | None} 을 커밋 하나로 쓴다(None 은 지움). 바뀐 것이 없으면 커밋하지 않는다."""
    return _write_floor(root, roadmap_rel, session, edit, what, False)


def ensure(root, roadmap_rel: str, session: str) -> Result:
    """상태 브랜치가 없으면 코드 없는 뿌리 커밋으로 만든다. 있으면 아무것도 바꾸지 않는다."""
    team = team_of(root, roadmap_rel)
    _need_marker(root, roadmap_rel, session)
    why = availability(root, roadmap_rel)
    if why:
        return Result(None, False, None, (why,))
    tip = local_tip(root, team.name)
    if tip is not None:
        return Result(None, False, None, ("있다 — %s(%s)" % (branch_of(team.name), tip[:8]),))
    if _default_commit(root) is not None and roadmap_rel not in roadmap_paths(root).values():
        raise BranchError(1, "로드맵이 기본 브랜치에 없다: %s" % visible(roadmap_rel))
    res = _write_floor(root, roadmap_rel, session, None, "상태 브랜치를 만든다", True)
    if res.commit is None:
        return res
    return res._replace(notes=("만들었다 — %s(%s)" % (branch_of(team.name), res.commit[:8]),) + res.notes)


# ── 명령줄 ───────────────────────────────────────────────────────────────────

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="conductor_branch.py", description="지휘자 상태 브랜치")
    ap.add_argument("--root", default=".")
    sub = ap.add_subparsers(dest="cmd", required=True)
    en = sub.add_parser("ensure", help="상태 브랜치가 없으면 만든다")
    en.add_argument("--roadmap", required=True)
    en.add_argument("--session", required=True)
    args = ap.parse_args(argv)
    try:
        res = ensure(args.root, args.roadmap, args.session)
    except BranchError as exc:
        print("[spec-distill] " + str(exc), file=sys.stderr)
        return exc.rc
    for line in res.notes:
        print("[spec-distill] " + line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
