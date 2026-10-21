#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""repo_defaults.py — 레포 설정의 기본값과 로드맵 frontmatter 의 레포 설정 읽기.

외부 도구가 정한 기본 경로(superpowers 의 설계문서 · 계획 폴더, SDD 의 작업 폴더, 하니스의 worktree 폴더)와 이 플러그인의 지휘자 상태
폴더 이름은 이 모듈에만 글자로 둔다. 로드맵 frontmatter 에 값이 있으면 그것이 이긴다. 읽기만 한다.
"""
from __future__ import annotations

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


def repo_settings(meta: dict) -> dict:
    """로드맵 frontmatter → 레포 설정. 잘못된 값은 errors 에 적고 그 키는 None — 기본값으로 조용히 바꾸지 않는다.
    권장 수(parallel_default)만은 게이트가 아니라서 깨지면 기본값으로 세고 warnings 에 적는다(알리되 멈추지 않는다)."""
    out = {"specs_dir": SPECS_DIR, "plans_dir": PLANS_DIR, "test_command": None, "review_model": None,
           "parallel_default": PARALLEL_DEFAULT, "sources": {}, "errors": [], "warnings": []}
    for key in DIR_KEYS:
        if key not in meta:
            out["sources"][key] = "기본값"
            continue
        folder, why = _folder(key, meta[key])
        out[key] = folder
        out["sources"][key] = "frontmatter"
        if why:
            out["errors"].append("레포 설정 " + why)
    for key in TEXT_KEYS:
        if key not in meta:
            out["sources"][key] = "기본값"
            continue
        out["sources"][key] = "frontmatter"
        value = _unquote(meta[key])
        if value:
            out[key] = value
        else:
            out["errors"].append("레포 설정 %s 값이 비었다" % key)
    for key in COUNT_KEYS:
        if key not in meta:
            out["sources"][key] = "기본값"
            continue
        out["sources"][key] = "frontmatter"
        value = _unquote(meta[key])
        if value.isascii() and value.isdigit() and int(value) >= 1:
            out[key] = int(value)
        else:
            # 권장 수는 게이트가 아니다 — 상태 계산 · 스위트 대조를 멈추지 않고 기본값으로 세되 크게 알린다
            out[key] = PARALLEL_DEFAULT
            out["sources"][key] = "기본값(머리말 값이 깨졌다)"
            out["warnings"].append("레포 설정 %s 는 1 이상의 정수다: %r — 기본 %d 으로 센다" % (key, value, PARALLEL_DEFAULT))
    return out


class SettingsError(ValueError):
    """kind: unreadable · unknown_key · duplicate_key · unquoted_hash · layer_key · bad_value · not_regular_file · lfs_pointer"""

    def __init__(self, kind: str, where: str, message: str = ""):
        super().__init__(message or "%s: %s" % (where, kind))
        self.kind = kind
        self.where = where


def strict_frontmatter(text: str, where: str) -> dict:
    """맨 앞 `---` 블록의 최상위 `키: 값` → {키: 따옴표 벗긴 값}. 줄 규칙은 roadmap_model.frontmatter 와 같고(들여쓴 줄 · 목록 줄 ·
    `#` 줄은 건너뜀) 오류만 더한다. 머리말이 없으면 설정 파일(where == "repo")은 unreadable, 다른 층은 {}."""
    lines = text.split("\n")
    first = lines[0].rstrip("\r")
    if text.startswith("\ufeff"):
        raise SettingsError("unreadable", where, "%s: 머리말 앞에 BOM 이 있다" % where)
    if first != "---":
        if first.startswith("---"):
            raise SettingsError("unreadable", where, "%s: 머리말 여는 줄이 `---` 가 아니다(뒤 공백 포함)" % where)
        if where == "repo":
            raise SettingsError("unreadable", where, "%s: 머리말이 없다" % where)
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
            raise SettingsError("duplicate_key", where, "%s: 같은 키가 둘이다: %s" % (where, key))
        if not raw.strip().startswith(("\"", "'")) and " #" in raw:
            raise SettingsError("unquoted_hash", where, "%s: %s 의 값에 따옴표 없는 ` #` 가 있다 — 값을 따옴표로 감싼다" % (where, key))
        out[key] = _unquote(raw)
    raise SettingsError("unreadable", where, "%s: 머리말이 닫히지 않았다" % where)


def check_layer(meta: dict, layer: str) -> None:
    """층이 받는 키 밖이면 SettingsError — 설정 키지만 그 층 몫이 아니면 layer_key, 아무 층에도 없으면 unknown_key."""
    if layer == "roadmap":
        allowed = ROADMAP_META_KEYS + ROADMAP_LAYER_KEYS
    elif layer == "repo":
        allowed = KEYS
    elif layer == "machine":
        allowed = MACHINE_LAYER_KEYS
    else:
        raise ValueError("알 수 없는 층: %r" % layer)
    for key in meta:
        if key in allowed:
            continue
        if key in KEYS:
            raise SettingsError("layer_key", layer, "%s 층은 %s 를 받지 않는다" % (layer, key))
        raise SettingsError("unknown_key", layer, "%s 층에 모르는 키가 있다: %s" % (layer, key))


def merge_layers(roadmap, repo, repo_label, machine, notices: list) -> dict:
    """로드맵 > 레포 설정 > 기계 상태 > 상수 순으로 합친다. 잘못된 값은 errors 에 적고 그 키는 None — 기본값으로 조용히
    바꾸지 않는다. 권장 수(parallel_default)만은 깨지면 기본값 + warnings."""
    layers = (("로드맵", "roadmap", roadmap), (repo_label or "레포 설정", "repo", repo), ("기계 상태(임시)", "machine", machine))
    out = {"values": {}, "sources": {}, "errors": [], "warnings": [], "notices": list(notices)}
    usable = []
    for label, layer, meta in layers:
        if meta is None:
            continue
        try:
            check_layer(meta, layer)
        except SettingsError as exc:
            out["errors"].append("레포 설정 " + str(exc))
            continue
        usable.append((label, meta))
    for key in KEYS:
        out["values"][key] = _DEFAULTS[key]
        out["sources"][key] = "기본값"
        for label, meta in usable:
            if key not in meta:
                continue
            raw = meta[key]
            out["sources"][key] = label
            if key in _FOLDER_KEYS:
                folder, why = _folder(key, raw)
                out["values"][key] = folder
                if why:
                    out["errors"].append("레포 설정 " + why)
            elif key == "parallel_default":
                value = _unquote(raw)
                if value.isascii() and value.isdigit() and int(value) >= 1:
                    out["values"][key] = int(value)
                else:
                    out["values"][key] = PARALLEL_DEFAULT
                    out["sources"][key] = "기본값(머리말 값이 깨졌다)"
                    out["warnings"].append("레포 설정 %s 는 1 이상의 정수다: %r — 기본 %d 으로 센다" % (key, value, PARALLEL_DEFAULT))
            else:
                value = _unquote(raw)
                if value:
                    out["values"][key] = value
                else:
                    out["values"][key] = None
                    out["errors"].append("레포 설정 %s 값이 비었다" % key)
            break
    return out
