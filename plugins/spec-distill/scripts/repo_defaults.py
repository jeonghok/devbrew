#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""repo_defaults.py — 레포 설정 해결자: 로드맵 · 레포 설정 파일(기본 브랜치 판) · 기계 상태(임시) · 기본값을 합친다.

외부 도구가 정한 기본 경로(superpowers 의 설계문서 · 계획 폴더, SDD 의 작업 폴더, 하니스의 worktree 폴더)와 이 플러그인의 지휘자 상태
폴더 이름은 이 모듈에만 글자로 둔다. 다른 스크립트는 `resolve` 로 값과 출처를 얻는다. 읽기만 한다.
"""
from __future__ import annotations

import argparse
import os
import re
import stat
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import roadmap_model as _rm  # noqa: E402

SPECS_DIR = "docs/superpowers/specs/"
PLANS_DIR = "docs/superpowers/plans/"
SDD_WORKSPACE = ".superpowers/sdd/"
CONDUCTOR_DIR = "conductor"
WORKTREE_HOME = ".claude/worktrees/"   # 하니스(EnterWorktree)가 worktree 를 두고 옮겨 갈 수 있는 폴더 — 외부 도구 기본값
MERGE_CHECK_DIR = "merge-check"        # 기계 상태 폴더 안의 스위트 대조 일회용 사본 자리(잠금은 suite_lock.py 의 공유 잠금)
PARALLEL_DEFAULT = 3                   # 지휘자가 동시에 돌리는 큰 작업의 권장 수 — 기본값이지 상한이 아니다(사용자가 늘린다)
DIR_KEYS = ("specs_dir", "plans_dir")
TEXT_KEYS = ("test_command", "review_model")
COUNT_KEYS = ("parallel_default",)
ROADMAPS_DIR = "docs/superpowers/roadmaps/"
INTERVIEW_DIR = "docs/superpowers/interview/"
BRANCH_PREFIX = "feature/"
SETTINGS_FILE = ".devbrew.md"
MACHINE_LABEL = "기계 상태(임시)"   # 기계 상태 층의 출처 표기 · 자리 이름
KEYS = ("specs_dir", "plans_dir", "roadmaps_dir", "interview_dir", "test_command", "test_failure_pattern",
        "review_model", "parallel_default", "branch_prefix")
ROADMAP_META_KEYS = ("type", "source_brief")
ROADMAP_LAYER_KEYS = ("specs_dir", "plans_dir", "test_command", "test_failure_pattern", "review_model", "parallel_default")
MACHINE_LAYER_KEYS = ("test_command", "test_failure_pattern")
_FOLDER_KEYS = ("specs_dir", "plans_dir", "roadmaps_dir", "interview_dir")
_DEFAULTS = {"specs_dir": SPECS_DIR, "plans_dir": PLANS_DIR, "roadmaps_dir": ROADMAPS_DIR, "interview_dir": INTERVIEW_DIR,
             "test_command": None, "test_failure_pattern": None, "review_model": None,
             "parallel_default": PARALLEL_DEFAULT, "branch_prefix": BRANCH_PREFIX}


def _unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1].strip()
    return value


def _folder(key: str, raw: str):
    """(폴더, 사유). 레포 상대 폴더만 받고 끝에 `/` 를 붙인다."""
    value = _unquote(raw)
    if not value:
        return None, "%s 값이 비었다" % key
    if value.startswith("/") or value.startswith("~"):
        return None, "%s 는 레포 상대경로여야 한다: %r" % (key, value)
    parts = value.split("/")
    if parts[-1] == "":
        parts = parts[:-1]
    if not parts or any(p in ("", ".", "..") for p in parts):
        return None, "%s 에 빈 조각 · . · .. 를 쓰지 않는다(레포 루트도 안 된다): %r" % (key, value)
    if ".git" in parts:
        return None, "%s 는 .git 아래를 가리킬 수 없다: %r" % (key, value)
    return "/".join(parts) + "/", None


class SettingsError(ValueError):
    """kind: unreadable · unknown_key · duplicate_key · unquoted_hash · layer_key · bad_value · not_regular_file · lfs_pointer"""

    def __init__(self, kind: str, where: str, message: str = ""):
        super().__init__(message or "%s: %s" % (_place(where), kind))
        self.kind = kind
        self.where = where


_places = {"repo": "레포 설정 파일(%s, 기본 브랜치 판)" % SETTINGS_FILE, "machine": MACHINE_LABEL}


def _place(where: str, path: str | None = None) -> str:
    """층 이름(repo · roadmap · machine) → 사람이 읽는 자리 이름."""
    if where == "roadmap":
        return "로드맵(%s)" % path if path else "로드맵"
    return _places.get(where, where)


def strict_frontmatter(text: str, where: str, path: str | None = None) -> dict:
    """맨 앞 `---` 블록의 최상위 `키: 값` → {키: 따옴표 벗긴 값}. 줄 규칙은 roadmap_model.frontmatter 와 같고(들여쓴 줄 · 목록 줄 ·
    `#` 줄은 건너뜀) 오류만 더한다. 머리말이 없으면 설정 파일(where == "repo")은 unreadable, 다른 층은 {}."""
    at = _place(where, path)
    lines = text.split("\n")
    first = lines[0].rstrip("\r")
    if text.startswith("\ufeff"):
        raise SettingsError("unreadable", where, "%s 의 머리말 앞에 BOM 이 있다 — BOM 없는 UTF-8 로 저장한다" % at)
    if first != "---":
        if first.startswith("---"):
            raise SettingsError("unreadable", where, "%s 의 머리말 여는 줄이 `---` 하나가 아니다(뒤 공백 포함) — `---` 만 남긴다" % at)
        if where == "repo":
            raise SettingsError("unreadable", where, "%s 에 머리말이 없다 — 맨 앞에 `---` 로 감싼 머리말을 둔다" % at)
        return {}
    out: dict = {}
    for line in lines[1:]:
        line = line.rstrip("\r")
        if line == "---":
            return out
        if not line or line[0] in " \t-#" or ":" not in line:
            continue
        key, raw = line.split(":", 1)
        key = key.strip()
        if key in out:
            raise SettingsError("duplicate_key", where, "%s 에 같은 키가 둘이다(%s) — 하나만 남긴다" % (at, key))
        value = raw.strip()
        if value[:1] in ("\"", "'"):
            close = value.find(value[0], 1)
            if close < 0:
                raise SettingsError("unreadable", where, "%s 의 값 따옴표가 닫히지 않았다(%s) — 따옴표를 닫는다" % (at, key))
            rest = value[close + 1:]
            if rest and re.match(r"\s+#", rest):
                raise SettingsError("unquoted_hash", where, "%s 의 값 따옴표 뒤에 주석(`#`)이 있다(%s) — 주석을 지우거나 따옴표 안에 넣는다"
                                    % (at, key))
            if rest:
                raise SettingsError("unreadable", where, "%s 의 값 따옴표 뒤에 글자가 더 있다(%s) — 값 전체를 따옴표로 감싼다"
                                    % (at, key))
        elif re.search(r"\s#", raw):
            raise SettingsError("unquoted_hash", where, "%s 의 값에 따옴표 없는 ` #` 가 있다(%s) — 값을 따옴표로 감싼다" % (at, key))
        out[key] = _unquote(raw)
    raise SettingsError("unreadable", where, "%s 의 머리말이 닫히지 않았다 — 머리말 끝에 `---` 줄을 둔다" % at)


def check_layer(meta: dict, layer: str, path: str | None = None) -> None:
    """층이 받는 키 밖이면 SettingsError — 설정 키지만 그 층 몫이 아니면 layer_key, 아무 층에도 없으면 unknown_key."""
    if layer == "roadmap":
        allowed = ROADMAP_META_KEYS + ROADMAP_LAYER_KEYS
    elif layer == "repo":
        allowed = KEYS
    elif layer == "machine":
        allowed = MACHINE_LAYER_KEYS
    else:
        raise ValueError("알 수 없는 층: %r" % layer)
    at = _place(layer, path)
    for key in meta:
        if key in allowed:
            continue
        if key in KEYS:
            raise SettingsError("layer_key", layer, "%s 은 이 설정을 받지 않는다(%s) — 레포 설정 파일(%s)로 옮긴다"
                                % (at, key, SETTINGS_FILE))
        raise SettingsError("unknown_key", layer, "%s 에 모르는 키가 있다(%s) — 키 이름을 고친다" % (at, key))


def merge_layers(roadmap, repo, repo_label, machine, notices: list, default_label: str = "기본값",
                 roadmap_path: str | None = None) -> dict:
    """로드맵 > 레포 설정 > 기계 상태 > 상수 순으로 합친다. 잘못된 값은 errors 에 적고 그 키는 None — 기본값으로 조용히
    바꾸지 않는다. 권장 수(parallel_default)만은 깨지면 기본값 + warnings."""
    layers = (("로드맵", "roadmap", roadmap), (repo_label or "레포 설정", "repo", repo), (MACHINE_LABEL, "machine", machine))
    out = {"values": {}, "sources": {}, "errors": [], "warnings": [], "notices": list(notices)}
    usable = []
    for label, layer, meta in layers:
        if meta is None:
            continue
        path = roadmap_path if layer == "roadmap" else None
        try:
            check_layer(meta, layer, path)
        except SettingsError as exc:
            out["errors"].append(str(exc))
            continue
        usable.append((label, _place(layer, path), meta))
    for key in KEYS:
        out["values"][key] = _DEFAULTS[key]
        out["sources"][key] = default_label
        for label, at, meta in usable:
            if key not in meta:
                continue
            raw = meta[key]
            out["sources"][key] = label
            if key in _FOLDER_KEYS:
                folder, why = _folder(key, raw)
                out["values"][key] = folder
                if why:
                    out["errors"].append("%s: %s" % (at, why))
            elif key == "parallel_default":
                value = _unquote(raw)
                if value.isascii() and value.isdigit() and int(value) >= 1:
                    out["values"][key] = int(value)
                else:
                    out["values"][key] = PARALLEL_DEFAULT
                    out["sources"][key] = "기본값(머리말 값이 깨졌다)"
                    out["warnings"].append("%s: 동시 작업 권장 수는 1 이상의 정수다(%s: %r) — 기본 %d 으로 센다"
                                           % (at, key, value, PARALLEL_DEFAULT))
            else:
                value = _unquote(raw)
                if value:
                    out["values"][key] = value
                else:
                    out["values"][key] = None
                    out["errors"].append("%s 의 값이 비었다(%s) — 값을 채우거나 키를 지운다" % (at, key))
            break
    return out


_no_ref_label = "기본값(기본 브랜치 없음 — 설정 파일 못 읽음)"
_GIT_ENV = {"GIT_TERMINAL_PROMPT": "0", "GIT_OPTIONAL_LOCKS": "0"}
GIT_ALLOWED = frozenset({"rev-parse", "ls-tree", "cat-file", "config"})   # config 는 --get 꼴만
NET_GIT_ALLOWED = frozenset({"ls-remote"})   # 네트워크 — check_remote_head 만 쓴다
REMOTE_TIMEOUT = 10.0
_origin_prefix = _rm.DEFAULT_REF.rsplit("/", 1)[0] + "/"   # refs/remotes/origin/
git_bin_dir = None   # 부르는 쪽이 찾은 git 의 폴더 — 있으면 PATH 앞에 둔다(conductor_ledger 가 정한다)


def _git(cwd: str, *args: str, where: str = "repo", timeout: float = 5, allowed=GIT_ALLOWED) -> tuple:
    """(rc, stdout 바이트). 시간 상한 안에 답이 없거나 git 을 못 부르면 SettingsError — 「없음」으로 읽지 않는다."""
    if not args or args[0] not in allowed:
        raise ValueError("허용 밖 git 하위 명령: %r" % (args[:1],))
    if args[0] == "config" and args[1:2] != ("--get",):
        raise ValueError("git config 는 --get 꼴만 부른다: %r" % (args,))
    env = dict(os.environ, **_GIT_ENV)
    if git_bin_dir:
        env["PATH"] = git_bin_dir + os.pathsep + env.get("PATH", "")
    try:
        proc = subprocess.run(["git", "-c", "core.quotePath=false", *args], cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SettingsError("unreadable", where, "git 을 부르지 못했다(%s) — git 이 있는지, 레포 안에서 불렀는지 확인한다"
                            % type(exc).__name__)
    return proc.returncode, proc.stdout


def _toplevel(cwd: str) -> str:
    rc, out = _git(cwd, "rev-parse", "--show-toplevel")
    top = out.decode("utf-8", "replace").strip()
    if rc != 0 or not top:
        raise SettingsError("unreadable", "repo", "git 레포가 아니다: %s — 레포 안에서 부르거나 --root 로 레포를 준다" % cwd)
    return top


def _outside_repo(base: str) -> bool:
    """git 이 레포를 찾지 못하고 base 의 조상 어디에도 `.git` 이 없으면 True. `.git` 이 있는데 못 읽으면 False(깨짐으로 간다)."""
    if os.environ.get("GIT_DIR") or not os.path.isdir(base):
        return False
    rc, out = _git(base, "rev-parse", "--show-toplevel")
    if rc == 0 and out.strip():
        return False
    p = os.path.realpath(base)
    while True:
        if os.path.lexists(os.path.join(p, ".git")):
            return False
        parent = os.path.dirname(p)
        if parent == p:
            return True
        p = parent


def _default_commit(top: str, run=None):
    """기본 ref 가 가리키는 커밋, 없으면 None."""
    run = run or (lambda *args: _git(top, *args))
    rc, out = run("rev-parse", "--verify", "--quiet", _rm.DEFAULT_REF + "^{commit}")
    sha = out.decode("ascii", "replace").strip()
    return sha if rc == 0 and sha else None


def default_branch(cwd: str) -> tuple:
    """(커밋, 짧은 이름, 못 찾은 사유). 짧은 이름은 기본 ref 의 전체 참조 이름에서 접두 refs/remotes/origin/ 을 벗긴 것 —
    같은 이름의 로컬 브랜치(예: origin/main)가 있어도 흔들리지 않는다. 못 찾으면 사유가 origin 유무에 따라 고치는 법을 담는다."""
    top = _toplevel(cwd)
    sha = _default_commit(top)
    rc, out = _git(top, "rev-parse", "--symbolic-full-name", _rm.DEFAULT_REF)
    short = short_default_name(rc, out.decode("utf-8", "replace"))
    if sha and short:
        return sha, short, None
    rc, _out = _git(top, "config", "--get", "remote.origin.url")
    return None, None, missing_default_reason(rc)


def short_default_name(rc: int, full: str):
    """`rev-parse --symbolic-full-name <기본 ref>` 의 (rc, 출력) → 짧은 이름, 기본 브랜치가 아니면 None. git 을 부르지 않는다."""
    full = full.strip()
    if rc != 0 or not full.startswith(_origin_prefix):
        return None
    short = full[len(_origin_prefix):]
    return short if short and short != "HEAD" else None


def missing_default_reason(origin_rc: int) -> str:
    """기본 브랜치를 못 찾았을 때 `config --get remote.origin.url` 의 rc → 고치는 법. 0 원격 있음 · 1 원격 없음,
    그 밖은 설정을 못 읽은 것이라 멈춘다. git 을 부르지 않는다."""
    if origin_rc == 0:
        return _rm.NO_DEFAULT
    if origin_rc == 1:
        return _rm.NO_ORIGIN
    raise SettingsError("unreadable", "repo", "origin 원격 설정을 읽지 못했다(git config 종료 코드 %d) — git config --get "
                        "remote.origin.url 을 직접 돌려 오류를 확인한다" % origin_rc)


def unchecked_line(local_short: str) -> str:
    return "원격과 대조하지 못했다 — 로컬 기본 브랜치 %s 을 썼다" % local_short


def check_remote_head(cwd: str, local_short: str, timeout: float = REMOTE_TIMEOUT) -> tuple:
    """(same · differs · unchecked, 한 줄). 원격 origin 의 HEAD 를 묻는다(네트워크). 못 물으면 멈추지 않고 unchecked."""
    unchecked = ("unchecked", unchecked_line(local_short))
    try:
        rc, out = _git(_toplevel(cwd), "ls-remote", "--symref", "origin", "HEAD", timeout=timeout,
                       allowed=NET_GIT_ALLOWED)
    except SettingsError:
        return unchecked
    remote = None
    for line in out.decode("utf-8", "replace").splitlines():
        target, _tab, name = line.partition("\t")
        if name == "HEAD" and target.startswith("ref: refs/heads/"):
            remote = target[len("ref: refs/heads/"):]
    if rc != 0 or not remote:
        return unchecked
    if remote == local_short:
        return "same", ""
    return "differs", ("원격 기본 브랜치(%s)가 로컬 기본 브랜치(%s)와 다르다 — git remote set-head origin --auto 로 맞춘 뒤 다시 돈다"
                       % (remote, local_short))


def _read_blob(top: str, commit: str, path: str, where: str, run=None):
    """기본 ref 판의 파일 내용(문자열), 파일이 없으면 None. 일반 파일이 아니면 · LFS 포인터면 · UTF-8 이 아니면 멈춘다."""
    run = run or (lambda *args: _git(top, *args, where=where))
    rc, out = run("ls-tree", "-z", commit, "--", path)
    if rc != 0:
        raise SettingsError("unreadable", where, "기본 브랜치에서 %s 를 찾지 못했다(git ls-tree 실패)" % path)
    entry = out.split(b"\0")[0].decode("utf-8", "replace")
    if not entry:
        return None
    mode, _type, sha = entry.split("\t", 1)[0].split(" ")
    if mode != "100644":
        raise SettingsError("not_regular_file", where, "%s 가 기본 브랜치에서 일반 파일이 아니다(mode %s) — 링크가 아닌 일반 파일로 커밋한다"
                            % (path, mode))
    rc, blob = run("cat-file", "blob", sha)
    if rc != 0:
        raise SettingsError("unreadable", where, "기본 브랜치의 %s 를 읽지 못했다(git cat-file 실패)" % path)
    if blob.split(b"\n", 1)[0].startswith(b"version https://git-lfs"):
        raise SettingsError("lfs_pointer", where, "%s 가 기본 브랜치에서 LFS 포인터다 — LFS 밖의 일반 파일로 커밋한다" % path)
    try:
        return blob.decode("utf-8")
    except UnicodeDecodeError:
        raise SettingsError("unreadable", where, "%s 가 UTF-8 글이 아니다 — UTF-8 로 저장해 커밋한다" % path)


def read_repo_file(cwd: str) -> tuple:
    """(레포 층, 출처 라벨, 알림). 레포 설정 파일은 기본 ref 판에서 읽는다 — 작업 트리의 판은 쓰지 않는다.
    기본 ref 가 없으면 (None, None, [알림]); 기본 ref 에 파일이 없으면 (None, 라벨, 알림)."""
    top = _toplevel(cwd)
    return _repo_file(top, _default_commit(top))


def _repo_file(top: str, commit, run=None) -> tuple:
    in_worktree = os.path.lexists(os.path.join(top, SETTINGS_FILE))
    if commit is None:
        notice = "기본 브랜치를 알 수 없어(origin/HEAD 없음) 레포 설정 파일을 읽지 못하고 기본값을 쓴다"
        if in_worktree:
            notice = "[주의] " + notice + " — 작업 트리의 %s 는 쓰지 않았다" % SETTINGS_FILE
        return None, None, [notice + ". 원격 origin 을 연결하고 `git remote set-head origin --auto` 로 기본 브랜치를 정한다"]
    label = "레포 설정@" + commit[:8]
    text = _read_blob(top, commit, SETTINGS_FILE, "repo", run)
    if text is None:
        notices = []
        if in_worktree:
            notices.append("레포 설정 파일(%s)이 아직 기본 브랜치에 없다 — 기본값을 쓴다" % SETTINGS_FILE)
        return None, label, notices
    return strict_frontmatter(text, "repo"), label, []


def resolve(cwd: str, roadmap: str | None = None, roadmap_text: str | None = None, machine_reader=None,
            run=None) -> dict:
    """네 층을 합친 결과(merge_layers 의 반환). roadmap 은 레포 상대 경로다. run(*git 인자) → (rc, 바이트) 를 주면
    git 을 그것으로 부르고 cwd 를 레포 최상위로 읽는다(상태줄이 시간 예산 안의 git 을 넘긴다)."""
    top = cwd if run else _toplevel(cwd)
    commit = _default_commit(top, run)   # 설정 파일과 로드맵을 같은 커밋에서 읽는다
    repo, label, notices = _repo_file(top, commit, run)
    roadmap_meta = machine = None
    if roadmap is None:
        notices.append("로드맵 없음 — 기계 상태 층 건너뜀")
    else:
        if roadmap_text is None:
            if commit is None:
                raise SettingsError("unreadable", "roadmap", _rm.NO_DEFAULT)
            roadmap_text = _read_blob(top, commit, roadmap, "roadmap", run)
            if roadmap_text is None:
                raise SettingsError("unreadable", "roadmap", "로드맵이 기본 브랜치에 없다(%s) — 로드맵을 머지한 뒤 다시 부른다" % roadmap)
        roadmap_meta = strict_frontmatter(roadmap_text, "roadmap", roadmap)
        if machine_reader is None:
            notices.append("기계 상태 층 건너뜀 — 읽는 함수 없음")
        else:
            try:
                machine = machine_reader(roadmap)
            except SettingsError:
                raise
            except Exception as exc:
                raise SettingsError("unreadable", "machine", "기계 상태(임시)의 레포 설정을 읽지 못했다(%s: %s) — 기계 상태 파일을 확인한다"
                                    % (type(exc).__name__, exc))
    return merge_layers(roadmap_meta, repo, label, machine, notices,
                        default_label=_no_ref_label if label is None else "기본값", roadmap_path=roadmap)


def _repo_relative(top: str, base: str, path: str):
    """경로 인자 → 레포 상대 경로, 레포 밖이면 None. 상대 경로는 base 기준, 절대 경로는 레포 루트(pwd -P) 기준."""
    top_real = os.path.realpath(top)
    if os.path.isabs(path):
        full = os.path.normpath(path)
        given = os.path.normpath(os.path.abspath(base))
        if full.startswith(given + os.sep):
            full = os.path.realpath(base) + full[len(given):]
    else:
        full = os.path.normpath(os.path.join(os.path.realpath(base), path))
    if not full.startswith(top_real + os.sep):
        return None
    return full[len(top_real) + 1:]


def _case_mismatch(top: str, rel: str):
    """디스크에 있는 경로 성분의 실제 이름이 대소문자만 다르면 (인자 성분, 실제 이름), 아니면 None."""
    cur = os.path.realpath(top)
    for part in rel.split("/"):
        try:
            names = os.listdir(cur)
        except OSError:
            return None
        if part in names:
            cur = os.path.join(cur, part)
            continue
        same = [n for n in names if n.casefold() == part.casefold()]
        return (part, same[0]) if same else None
    return None


def judge_path(key: str, folder: str, path: str, base: str) -> str | None:
    """경로의 부모 폴더가 그 키의 폴더와 글자까지 같으면 None, 아니면 거부 사유 한 줄."""
    top = _toplevel(base)
    rel = _repo_relative(top, base, path)
    if rel is None:
        return "레포 밖 경로라 받지 않았다: %s — 레포 %s 안의 경로를 준다" % (path, top)
    parent = os.path.dirname(rel) + "/"
    if parent != folder:
        if parent.casefold() == folder.casefold():
            return "대소문자만 다른 경로라 받지 않았다: %s — 정해진 폴더 %s 의 글자 그대로 쓴다(%s)" % (rel, folder, key)
        return "부모 폴더가 다르다: %s 의 부모는 %s 인데 정해진 폴더는 %s 다(%s) — 그 폴더 바로 아래 경로를 준다" % (rel, parent, folder, key)
    bad = _case_mismatch(top, rel)
    if bad:
        return "대소문자만 다른 경로라 받지 않았다: 인자의 %s 가 디스크에서는 %s 다 — 디스크의 이름에 맞춘다" % bad
    return None


def _say(line: str) -> None:
    print("[spec-distill] " + line, file=sys.stderr)


def _cmd_default_branch(base: str, check_remote: bool) -> int:
    """0 짧은 이름(stdout) · 3 기본 브랜치 없음 · 5 원격과 다름. 대조하지 못하면 알리고 0."""
    _sha, short, why = default_branch(base)
    if why:
        _say(why)
        return 3
    if check_remote:
        state, line = check_remote_head(base, short)
        if state == "differs":
            _say(line)
            return 5
        if state == "unchecked":
            _say(line)
    print(short)
    return 0


def _worktree_reader(top: str):
    """read(레포 상대 경로) — 작업 트리 파일을 로드맵 후보 글의 읽기 규칙(roadmap_model.regular_text)으로 읽는다."""
    def read(rel):
        path = os.path.join(top, rel)
        try:
            if not stat.S_ISREG(os.lstat(path).st_mode):
                return _rm.regular_text(False, b"")
            with open(path, "rb") as fh:
                data = fh.read()
        except FileNotFoundError:
            raise _rm.Unreadable("파일이 없다")
        except OSError as exc:
            raise _rm.ReadFailed("파일을 읽지 못했다(%s)" % type(exc).__name__)
        return _rm.regular_text(True, data)
    return read


def _cmd_roadmap_check(base: str, path: str) -> int:
    """0 로드맵 · 3 아님(사유 한 줄). 로드맵 폴더는 base 레포의 해결자 값, 글은 작업 트리 파일이다."""
    top = _toplevel(base)
    rel = _repo_relative(top, base, path)
    if rel is None:
        _say("레포 밖 경로라 로드맵으로 받지 않았다: %s — 레포 %s 안의 로드맵을 준다" % (path, top))
        return 3
    result = resolve(base)
    for line in result["warnings"] + result["errors"]:
        _say(line)
    if result["errors"]:
        return 3
    folder = result["values"]["roadmaps_dir"]
    verdict, why = _rm.judge_roadmap(rel, _worktree_reader(top), folder)
    if verdict == "roadmap":
        return 0
    if verdict == "unreadable":
        _say("로드맵 검사 불가: %s — %s. 파일과 머리말을 고친다" % (rel, why))
    else:
        _say("로드맵이 아니다: %s — %s. 로드맵은 %s 바로 아래 폴더에 머리말 type: roadmap 으로 둔다" % (rel, why, folder))
    return 3


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="repo_defaults.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_get = sub.add_parser("get")
    p_get.add_argument("key", choices=KEYS)
    p_get.add_argument("--roadmap")
    p_get.add_argument("--root")
    p_chk = sub.add_parser("check-path")
    p_chk.add_argument("key", choices=_FOLDER_KEYS)
    p_chk.add_argument("path")
    p_chk.add_argument("--root")
    p_def = sub.add_parser("default-branch")
    p_def.add_argument("--check-remote", action="store_true")
    p_def.add_argument("--root")
    p_rmc = sub.add_parser("roadmap-check")
    p_rmc.add_argument("path")
    p_rmc.add_argument("--root")
    args = ap.parse_args(argv)
    try:
        base = args.root or os.getcwd()
        if args.cmd == "default-branch":
            return _cmd_default_branch(base, args.check_remote)
        if args.cmd == "roadmap-check":
            return _cmd_roadmap_check(base, args.path)
        if args.cmd == "get" and args.roadmap is None and _outside_repo(base):
            result = merge_layers(None, None, None, None, [
                "git 레포 밖이라 레포 설정 파일을 읽지 못하고 기본값을 쓴다(%s)" % base], default_label=_no_ref_label)
            for line in result["notices"]:
                _say(line)
            _say("값의 출처: %s(%s)" % (result["sources"][args.key], args.key))
            value = result["values"][args.key]
            if value is None:
                return 1
            print(value)
            return 0
        roadmap = getattr(args, "roadmap", None)
        if roadmap is not None:
            roadmap = _repo_relative(_toplevel(base), base, roadmap)
            if roadmap is None:
                _say("레포 밖 경로라 로드맵으로 받지 않았다: %s — 레포 안의 로드맵을 준다" % args.roadmap)
                return 3
        result = resolve(base, roadmap=roadmap)
        for line in result["notices"] + result["warnings"]:
            _say(line)
        if result["errors"]:
            for line in result["errors"]:
                _say(line)
            return 3
        _say("값의 출처: %s(%s)" % (result["sources"][args.key], args.key))
        value = result["values"][args.key]
        if args.cmd == "check-path":
            why = judge_path(args.key, value, args.path, base)
            if why:
                _say(why)
                return 3
            return 0
    except SettingsError as exc:
        _say(str(exc))
        return 3
    except Exception as exc:   # 값 없음(rc 1)으로 읽히지 않게 — 어떤 내부 오류도 깨짐(rc 3)이다
        _say("내부 오류로 판정하지 못했다(%s: %s) — 이 줄을 그대로 알린다" % (type(exc).__name__, exc))
        return 3
    if value is None:
        return 1
    print(value)
    return 0


if __name__ == "__main__":
    sys.exit(main())
