#!/usr/bin/env python3
"""spec-distill — 인터뷰 상태 파일(`<줄기>-interview.state.md`)의 진입 판정 · 옛 자리 이월 · seed audit 이름 되찾기.

CLI (판결은 stdout 마지막 줄):
  interview_state.py entry --arg <경로|""> --session <sid> [--cwd <dir>]
  interview_state.py migrate-legacy --session <sid> --topic <kebab> [--seed <경로>] [--date D] [--cwd <dir>]
    rc: 0 옮김 · 1 옮길 옛 파일 없음 · 2 자리 거부(링크 포함)/대상 이미 있음 · 3 읽기/쓰기 실패(옛 파일 그대로) 또는 옛 파일 삭제 실패
  interview_state.py seed-audit-for-session --session <sid> [--topic <kebab>] [--cwd <dir>]
    rc: 0 이름 하나 · 1 없음 · 2 둘 이상 · 3 인터뷰 폴더를 정하지 못함(레포 설정이 깨짐)
    --topic 이면 그 주제(`<날짜>-<주제>-interview`)의 audit 만 센다 — 다른 주제의 것만 있으면 알리고 1.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from state_path import (  # noqa: E402
    SESSION_PATTERN, frontmatter_scalars, inside_root, interview_dir, interview_state_path, physical_cwd_prefix,
    state_root, worktree_root,
)
from gc_common import root_escapes  # noqa: E402

LEGACY_NAME = "state.local.md"
_SEED_NAME = re.compile(r"\d{4}-\d{2}-\d{2}-([a-z0-9]+(?:-[a-z0-9]+)*)-interview\.md")
_AUDIT_TOPIC = re.compile(r"\d{4}-\d{2}-\d{2}-(.+)-interview\.audit\.md")
# 상태 파일 경로는 펜스의 셸 리터럴(`ARG_PATH='<경로>'`)에 붙는다 — 작업 트리 안 상대 경로는 이 글자만 받는다.
_SAFE_REL = re.compile(r"[\w./ -]+")
_UNSAFE_ROOT_CHARS = frozenset("'\x7f").union(chr(c) for c in range(0x20))   # 작업 트리 루트 경로에서 받지 않는 글자


def unsafe_name(path, root) -> str | None:
    """상태 파일 경로가 셸 리터럴에 붙여도 안전한 글자만 쓰는지 — 아니면 사유."""
    real_root = os.path.realpath(str(root))
    rel = os.path.relpath(str(path), real_root)
    if not real_root or _UNSAFE_ROOT_CHARS.intersection(real_root) or not _SAFE_REL.fullmatch(rel):
        return "허용 글자(글자 · 숫자 · 공백 · . _ - /) 밖의 이름이다 — 셸에 붙이지 않는다"
    return None


def seed_rel(seed: str) -> str:
    real = os.path.realpath(seed)
    root, _ = worktree_root(os.path.dirname(real))
    return os.path.relpath(real, os.path.realpath(str(root)))


def legacy_state(sid: str, cwd: str | None) -> Path | None:
    if not sid or not SESSION_PATTERN.fullmatch(sid):
        return None
    p = state_root(cwd) / sid / LEGACY_NAME
    return p if p.is_file() else None


def sibling_reason(state, root) -> str | None:
    """상태 파일 짝 brief(`<줄기>.md`) · audit(`<줄기>.audit.md`) 중 링크(끊긴 것 포함)이거나 작업 트리 밖인 것의 사유."""
    stem = str(state)[:-len(".state.md")]
    for q in (stem + ".md", stem + ".audit.md"):
        why = inside_root(q, root)
        if why:
            return "{0}: {1}".format(os.path.basename(q), why)
    return None


def seed_value(seed: str, cwd: str | None) -> str:
    """상태 파일 `seed:` 값 — seed 가 링크이거나 그 작업 트리 밖이면 `없음`(사유 한 줄은 stderr)."""
    cwd = cwd or os.getcwd()
    abs_seed = physical_cwd_prefix(os.path.abspath(os.path.join(cwd, seed)), cwd)
    root, _ = worktree_root(os.path.dirname(abs_seed))
    why = inside_root(abs_seed, root)
    rel = None if why else seed_rel(abs_seed)
    if rel is None or rel == ".." or rel.startswith(".." + os.sep) or os.path.isabs(rel):
        print("[spec-distill] seed 가 링크이거나 작업 트리 밖이다 — seed 를 없음으로 적는다: {0} ({1})".format(
            seed, why or "작업 트리 밖이다"), file=sys.stderr)
        return "없음"
    return rel


def resume_candidates(seed: str, want: str) -> list[Path]:
    real_dir = os.path.dirname(os.path.realpath(seed))
    root, _ = worktree_root(real_dir)
    out = []
    for p in sorted(Path(real_dir).glob("*-interview.state.md")):
        if inside_root(p, root):   # 링크이거나 작업 트리 밖이면 후보로 내지 않는다
            continue
        why = unsafe_name(p, root)
        if why:
            print("[spec-distill] 이어 갈 후보에서 뺐다 — {0!r} ({1})".format(str(p), why), file=sys.stderr)
            continue
        why = sibling_reason(p, root)
        if why:   # 짝 brief · audit 가 링크면 끝낼 때의 쓰기가 그 링크를 따라간다
            print("[spec-distill] 이어 갈 후보에서 뺐다 — {0} ({1})".format(p, why), file=sys.stderr)
            continue
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
        cwd = a.cwd or os.getcwd()
        abs_arg = physical_cwd_prefix(os.path.abspath(os.path.join(cwd, arg)), cwd)
        root, _ = worktree_root(cwd)
        why = inside_root(abs_arg, root)
        if why:
            print("interview-state: REJECT {0} ({1})".format(arg, why))
            return 2
        why = unsafe_name(abs_arg, root)
        if why:
            print("interview-state: REJECT {0!r} ({1})".format(arg, why))
            return 2
        why = sibling_reason(abs_arg, root)
        if why:
            print("interview-state: REJECT {0} ({1})".format(arg, why))
            return 2
        fm = frontmatter_scalars(abs_arg)
        have = None if fm is None else fm.get("type")
        if have != "interview-state":
            print("interview-state: REJECT {0} (type: {1})".format(arg, have or "없음"))
            return 2
        if os.path.exists(abs_arg[:-len(".state.md")] + ".md"):
            print("interview-state: REJECT {0} (이미 끝난 인터뷰다 — brief 가 있다)".format(arg))
            return 2
        print("interview-state: RESUME {0}".format(abs_arg))
        return 0
    leg = legacy_state(a.session, a.cwd)
    if leg is not None:
        print("interview-state: LEGACY {0}".format(leg))
        return 0
    if arg and (frontmatter_scalars(arg) or {}).get("type") == "interview-seed":
        sv = seed_value(arg, a.cwd)
        cands = [] if sv == "없음" else resume_candidates(arg, sv)
        if cands:
            for c in cands:
                print("candidate: {0}".format(c))
            print("interview-state: ASK")
            return 0
        m = _SEED_NAME.fullmatch(os.path.basename(arg))
        if m:
            print("interview-state: NEW-SEED {0}-brief seed={1}".format(m.group(1), sv))
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
    if (leg.is_symlink() or root_escapes(root, "spec-distill")
            or inside_root(leg, root.parent.parent)):
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
        head = "type: interview-state\nseed: {0}\n".format(seed_value(a.seed, a.cwd) if a.seed else "없음")
        new = "---\n" + head + text[4:] if text.startswith("---\n") else "---\n" + head + "---\n" + text
        path.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(str(tmp), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, "wb") as fh:
            fh.write(new.encode("utf-8"))
        os.replace(str(tmp), str(path))
    except (OSError, UnicodeError) as e:
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
    root, is_git = worktree_root(a.cwd)
    d, why = interview_dir(root, is_git)
    if d is None:
        print(why, file=sys.stderr)
        return 3
    hits = []
    for p in sorted(d.glob("*-interview.audit.md")):
        fm = frontmatter_scalars(p) or {}
        if fm.get("type") == "interview-seed-audit" and fm.get("session_id") == a.session:
            hits.append(p)
    if a.topic:
        # 이름에서 주제를 떼지 못하는 audit 은 주제를 모른다 — 다른 주제로 단정하지 않고 후보에 남긴다
        mine = [p for p in hits if not (m := _AUDIT_TOPIC.fullmatch(p.name)) or m.group(1) == a.topic]
        if hits and not mine:
            print("[spec-distill] 이 세션에 다른 주제의 seed audit 이 있다 — 주제 {0} 는 새 이름으로 연다. 같은 회의를 잇는 "
                  "것이면 TOPIC 을 그 주제로 바꿔 다시 돌린다:".format(a.topic), file=sys.stderr)
            for h in hits:
                print("  {0}".format(h), file=sys.stderr)
        hits = mine
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
    x.add_argument("--topic", default="")
    x.add_argument("--cwd", default=None)
    x.set_defaults(fn=cmd_seed_audit)
    a = p.parse_args(argv)
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
