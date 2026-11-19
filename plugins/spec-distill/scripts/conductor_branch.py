#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_branch.py — 지휘자 상태 브랜치(`conductor/<로드맵 폴더 이름>`)의 이름 · 쓸 수 있는지 판정 · 읽기.

작업 폴더 · index · HEAD 를 쓰지 않는다 — git 은 읽기 하위 명령(`GIT_ALLOWED`)만 부른다. 뒤 과제가 쓰기 · 올리기와
명령줄(`ensure` · `delete`)을 더한다.

종료 코드(명령줄이 생기면): 0 · 1(없음/아님) · 2 사용법 · 3 읽기 불가 · 5 다른 세션의 표지.

가져오는 모듈은 `conductor_state` · `repo_defaults` · `state_path` · `team_layout` · `branch_tip` · `roadmap_model` 뿐이다.
"""
from __future__ import annotations

import datetime
import json
import os
import re
import socket
import subprocess
import sys
import unicodedata
from pathlib import Path
from typing import NamedTuple, Optional

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import branch_tip  # noqa: E402
import conductor_state as cs  # noqa: E402
import repo_defaults  # noqa: E402
import roadmap_model  # noqa: E402
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
GIT_ALLOWED = frozenset({"rev-parse", "cat-file", "ls-tree", "for-each-ref", "config", "merge-base"})
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
                if line.startswith(head) and line[len(head):]:
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
