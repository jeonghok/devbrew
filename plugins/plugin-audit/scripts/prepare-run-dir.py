#!/usr/bin/env python3
"""prepare-run-dir.py — plugin-audit 실행 디렉토리를 만든다 (지출 동의 승인 직후 한 번).

<repo-root>/.claude/plugin-audit/<date>-<target>[-N]/ 을 os.mkdir 로 원자적으로 만들고 그 안에
`*` 한 줄짜리 .gitignore 를 쓴다. 이미 있으면 -2, -3 … 을 붙여 다시 시도한다 — 기존 디렉토리를
덮거나 비우지 않는다.

stdout 두 줄:
  1. 실행 디렉토리의 절대경로 (basename = 실행 키)
  2. sandbox id — 실행 키의 SHA-256 앞 8 hex. audit-sandbox.sh create-sandbox 는 받은 id 의 앞
     8글자만 sandbox 이름에 쓰고 같은 이름의 sandbox 를 지우고 다시 만든다. 날짜로 시작하는 실행
     키를 그대로 넘기면 같은 달의 감사가 한 sandbox 로 접힌다.

rc: 0 성공 · 1 디렉토리를 만들지 못함 · 2 인자 형식 위반(target · date).
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import os
import re
import sys
from pathlib import Path

TARGET_RE = re.compile(r"[A-Za-z0-9._-]+")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
MAX_SUFFIX = 999


def valid_target(target: str) -> bool:
    return (bool(TARGET_RE.fullmatch(target))
            and ".." not in target and not target.startswith("."))


def sandbox_id(run_key: str) -> str:
    return hashlib.sha256(run_key.encode("utf-8")).hexdigest()[:8]


def make_run_dir(parent: Path, key: str) -> Path:
    parent.mkdir(parents=True, exist_ok=True)
    for n in range(1, MAX_SUFFIX + 1):
        candidate = parent / (key if n == 1 else f"{key}-{n}")
        try:
            os.mkdir(candidate)
        except FileExistsError:
            continue
        return candidate
    raise FileExistsError(f"{parent / key} 와 -2 … -{MAX_SUFFIX} 가 전부 이미 있다")


def main(argv: list[str] | None = None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="plugin-audit 실행 디렉토리를 만든다")
    ap.add_argument("target")
    ap.add_argument("--repo-root", type=Path, default=Path("."))
    ap.add_argument("--date", default=None, help="YYYY-MM-DD (기본: 오늘의 로컬 날짜)")
    args = ap.parse_args(argv)
    if not valid_target(args.target):
        print(f"[prepare-run-dir] target 형식 불허: {args.target!r} — "
              "[A-Za-z0-9._-]+ 이고 '..' 를 포함하지 않으며 '.' 으로 시작하지 않아야 한다",
              file=sys.stderr)
        return 2
    date = args.date if args.date is not None else datetime.date.today().isoformat()
    if not DATE_RE.fullmatch(date):
        print(f"[prepare-run-dir] date 형식 불허: {date!r} — YYYY-MM-DD", file=sys.stderr)
        return 2
    parent = args.repo_root.resolve() / ".claude" / "plugin-audit"
    try:
        run_dir = make_run_dir(parent, f"{date}-{args.target}")
        (run_dir / ".gitignore").write_text("*\n", encoding="utf-8")
    except OSError as e:
        print(f"[prepare-run-dir] 실행 디렉토리를 만들지 못했다: {e}", file=sys.stderr)
        return 1
    print(run_dir)
    print(sandbox_id(run_dir.name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
