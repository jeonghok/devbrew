#!/usr/bin/env python3
"""spec-distill — 인터뷰 상태 파일(`<줄기>-interview.state.md`)의 진입 판정 · 옛 자리 이월 · seed audit 이름 되찾기.

CLI (판결은 stdout 마지막 줄):
  interview_state.py entry --arg <경로|""> --session <sid> [--cwd <dir>]
  interview_state.py migrate-legacy --session <sid> --topic <kebab> [--seed <경로>] [--date D] [--cwd <dir>]
    rc: 0 옮김 · 1 옮길 옛 파일 없음 · 2 자리 거부(링크 포함)/대상 이미 있음 · 3 읽기/쓰기 실패(옛 파일 그대로) 또는 옛 파일 삭제 실패
  interview_state.py seed-audit-for-session --session <sid> [--cwd <dir>]
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from state_path import (  # noqa: E402
    INTERVIEW_DIR, SESSION_PATTERN, frontmatter_scalars, inside_root, interview_state_path, state_root, worktree_root,
)
from gc_common import root_escapes  # noqa: E402

LEGACY_NAME = "state.local.md"
_SEED_NAME = re.compile(r"\d{4}-\d{2}-\d{2}-([a-z0-9]+(?:-[a-z0-9]+)*)-interview\.md")


def seed_rel(seed: str) -> str:
    real = os.path.realpath(seed)
    root, _ = worktree_root(os.path.dirname(real))
    return os.path.relpath(real, os.path.realpath(str(root)))


def legacy_state(sid: str, cwd: str | None) -> Path | None:
    if not sid or not SESSION_PATTERN.fullmatch(sid):
        return None
    p = state_root(cwd) / sid / LEGACY_NAME
    return p if p.is_file() else None


def resume_candidates(seed: str) -> list[Path]:
    want = seed_rel(seed)
    out = []
    for p in sorted(Path(os.path.realpath(seed)).parent.glob("*-interview.state.md")):
        fm = frontmatter_scalars(p) or {}
        if fm.get("type") != "interview-state" or fm.get("seed") != want:
            continue
        if p.with_name(p.name[:-len(".state.md")] + ".md").exists():
            continue
        out.append(p)
    return out


def cmd_entry(a) -> int:
    arg = a.arg or ""
    if arg.endswith(".state.md"):
        fm = frontmatter_scalars(arg)
        have = None if fm is None else fm.get("type")
        if have != "interview-state":
            print("interview-state: REJECT {0} (type: {1})".format(arg, have or "없음"))
            return 2
        print("interview-state: RESUME {0}".format(os.path.realpath(arg)))
        return 0
    leg = legacy_state(a.session, a.cwd)
    if leg is not None:
        print("interview-state: LEGACY {0}".format(leg))
        return 0
    if arg and (frontmatter_scalars(arg) or {}).get("type") == "interview-seed":
        cands = resume_candidates(arg)
        if cands:
            for c in cands:
                print("candidate: {0}".format(c))
            print("interview-state: ASK")
            return 0
        m = _SEED_NAME.fullmatch(os.path.basename(arg))
        if m:
            print("interview-state: NEW-SEED {0}-brief seed={1}".format(m.group(1), seed_rel(arg)))
            return 0
        print("[spec-distill] seed 이름에서 주제를 떼지 못했다 — 첫 라운드에서 정한다: {0}".format(arg),
              file=sys.stderr)
    print("interview-state: NEW")
    return 0


def cmd_migrate(a) -> int:
    leg = legacy_state(a.session, a.cwd)
    if leg is None:
        print("[spec-distill] 옮길 옛 진행 기록이 없다", file=sys.stderr)
        return 1
    root = state_root(a.cwd)
    if leg.is_symlink() or root_escapes(root, "spec-distill"):
        print("[spec-distill] 옛 진행 기록이 링크이거나 상태 루트가 링크를 거친다 — 옮기지 않는다: {0}".format(leg),
              file=sys.stderr)
        return 2
    path, msgs = interview_state_path(a.topic, a.date, a.cwd)
    for m in msgs:
        print(m, file=sys.stderr)
    if path is None:
        return 2
    if path.exists() or path.is_symlink():
        print("[spec-distill] 옮길 자리에 이미 파일이 있다 — {0}. 덮어쓰지 않는다.".format(path), file=sys.stderr)
        return 2
    tmp = path.with_name("." + path.name + ".tmp")
    try:
        text = leg.read_text(encoding="utf-8")
        head = "type: interview-state\nseed: {0}\n".format(seed_rel(a.seed) if a.seed else "없음")
        new = "---\n" + head + text[4:] if text.startswith("---\n") else "---\n" + head + "---\n" + text
        path.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(str(tmp), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, "wb") as fh:
            fh.write(new.encode("utf-8"))
        os.replace(str(tmp), str(path))
    except (OSError, UnicodeDecodeError) as e:
        if not isinstance(e, FileExistsError):  # 남이 놓은 tmp 는 지우지 않는다
            try:
                tmp.unlink()
            except OSError:
                pass
        print("[spec-distill] 옛 진행 기록을 옮기지 못했다 — {0}".format(e), file=sys.stderr)
        return 3
    try:
        leg.unlink()
    except OSError as e:
        print("[spec-distill] 새 파일은 자리에 놓였다 — {0}. 옛 파일 {1} 은 손으로 지워야 한다 ({2}).".format(
            path, leg, e), file=sys.stderr)
        return 3
    print("[spec-distill] 옛 위치의 진행 기록을 docs 로 옮겼다 — {0}".format(path))
    return 0


def cmd_seed_audit(a) -> int:
    root, _ = worktree_root(a.cwd)
    d = root.joinpath(*INTERVIEW_DIR)
    hits = []
    for p in sorted(d.glob("*-interview.audit.md")):
        fm = frontmatter_scalars(p) or {}
        if fm.get("type") == "interview-seed-audit" and fm.get("session_id") == a.session:
            hits.append(p)
    if not hits:
        return 1
    if len(hits) > 1:
        print("[spec-distill] 이 세션의 seed audit 이 둘 이상이다 — 이름을 고르지 않고 멈춘다:", file=sys.stderr)
        for h in hits:
            print("  {0}".format(h), file=sys.stderr)
        return 2
    print(hits[0].name[:-len(".audit.md")])
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="interview_state.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    x = sp.add_parser("entry")
    x.add_argument("--arg", default="")
    x.add_argument("--session", default="")
    x.add_argument("--cwd", default=None)
    x.set_defaults(fn=cmd_entry)
    x = sp.add_parser("migrate-legacy")
    x.add_argument("--session", required=True)
    x.add_argument("--topic", required=True)
    x.add_argument("--seed", default=None)
    x.add_argument("--date", default=None)
    x.add_argument("--cwd", default=None)
    x.set_defaults(fn=cmd_migrate)
    x = sp.add_parser("seed-audit-for-session")
    x.add_argument("--session", required=True)
    x.add_argument("--cwd", default=None)
    x.set_defaults(fn=cmd_seed_audit)
    a = p.parse_args(argv)
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
