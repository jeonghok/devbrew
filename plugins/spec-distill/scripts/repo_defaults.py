#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""repo_defaults.py — 레포 설정의 기본값과 로드맵 frontmatter 의 레포 설정 읽기.

외부 도구가 정한 기본 경로(superpowers 의 설계문서 · 계획 폴더, SDD 의 작업 폴더)와 이 플러그인의 지휘자 상태
폴더 이름은 이 모듈에만 글자로 둔다. 로드맵 frontmatter 에 값이 있으면 그것이 이긴다. 읽기만 한다.
"""
from __future__ import annotations

SPECS_DIR = "docs/superpowers/specs/"
PLANS_DIR = "docs/superpowers/plans/"
SDD_WORKSPACE = ".superpowers/sdd/"
CONDUCTOR_DIR = "conductor"
DIR_KEYS = ("specs_dir", "plans_dir")
TEXT_KEYS = ("test_command", "review_model")


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
        return None, "%s 에 빈 조각 · . · .. 를 쓰지 않는다: %r" % (key, value)
    return "/".join(parts) + "/", None


def repo_settings(meta: dict) -> dict:
    """로드맵 frontmatter → 레포 설정. 잘못된 값은 errors 에 적고 그 키는 None — 기본값으로 조용히 바꾸지 않는다."""
    out = {"specs_dir": SPECS_DIR, "plans_dir": PLANS_DIR, "test_command": None, "review_model": None,
           "sources": {}, "errors": []}
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
    return out
