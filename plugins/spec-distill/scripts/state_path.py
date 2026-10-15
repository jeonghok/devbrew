#!/usr/bin/env python3
"""spec-distill state path helper.

Resolves state root to <main_repo>/.claude/spec-distill regardless of cwd
(worktree-aware via `git rev-parse --git-common-dir`). Fallback: cwd-relative
with loud stderr log.

CLI:
  python3 state_path.py state-root [<cwd>]    → prints absolute path to stdout
  python3 state_path.py session-id            → prints env-resolved session id (exit 1 if unresolved)
  python3 state_path.py interview-state --topic <kebab> [--date YYYY-MM-DD] [--cwd <dir>]
                                              → prints interview state file path (exit 2 on refusal)
"""
from __future__ import annotations

import datetime
import os
import re
import subprocess
import sys
from pathlib import Path


SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")


def resolve_session_id(payload: dict | None = None) -> str | None:
    """Resolve session_id with precedence: test override → CLAUDE_CODE_SESSION_ID → payload.

    Returns None + loud stderr on unresolved or charset/length validation failure.
    Caller must skip state write but may still emit advisory output.
    """
    sid = (
        os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID")
        or os.environ.get("CLAUDE_CODE_SESSION_ID")
        or (payload or {}).get("session_id")
    )
    if not sid:
        print(
            "[spec-distill] session_id unresolved (env+payload empty) — "
            "state write skipped, hook output retained",
            file=sys.stderr,
        )
        return None
    if not SESSION_PATTERN.match(sid):
        truncated = sid[:32] + ("..." if len(sid) > 32 else "")
        print(
            f"[spec-distill] session_id rejected by charset/length: '{truncated}'",
            file=sys.stderr,
        )
        return None
    return sid


def state_root(cwd: str | None = None) -> Path:
    """Return <main_repo>/.claude/spec-distill. cwd fallback on git failure."""
    if cwd is None:
        cwd = os.getcwd()
    try:
        cp = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=cwd, capture_output=True, text=True, timeout=5, check=False,
        )
        if cp.returncode == 0:
            git_dir = Path(cp.stdout.strip())
            if not git_dir.is_absolute():
                git_dir = (Path(cwd) / git_dir).resolve()
            main_repo = git_dir.parent
            return main_repo / ".claude" / "spec-distill"
    except (subprocess.TimeoutExpired, OSError, FileNotFoundError):
        pass
    fallback = Path(cwd) / ".claude" / "spec-distill"
    print(
        f"[spec-distill] state root fallback: cwd ({cwd}) — main repo 미해석",
        file=sys.stderr,
    )
    return fallback


KEBAB = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
INTERVIEW_DIR = ("docs", "superpowers", "interview")
# 한 인터뷰의 세 자리와 각 자리가 받아들이는 frontmatter `type:`.
_SLOTS = ((".state.md", "interview-state"), (".md", "interview-brief"), (".audit.md", "interview-audit"))


def worktree_root(cwd: str | None = None) -> tuple[Path, bool]:
    """(작업 트리 루트, git 인가). 메인 레포가 아니라 이 cwd 가 속한 worktree 의 루트다."""
    cwd = cwd or os.getcwd()
    try:
        cp = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=cwd, capture_output=True, text=True, timeout=5, check=False,
        )
        if cp.returncode == 0 and cp.stdout.strip():
            return Path(cp.stdout.strip()), True
    except (subprocess.TimeoutExpired, OSError):
        pass
    return Path(cwd).resolve(), False


def inside_root(path, root) -> str | None:
    """path 가 root 안에 있고 root 아래 성분 중 링크가 없으면 None, 아니면 짧은 사유."""
    rel = os.path.relpath(os.path.abspath(str(path)), os.path.abspath(str(root)))
    if rel == ".." or rel.startswith(".." + os.sep) or os.path.isabs(rel):
        return "작업 트리 밖이다"
    cur = os.path.abspath(str(root))
    for part in [] if rel == "." else rel.split(os.sep):
        cur = os.path.join(cur, part)
        if os.path.islink(cur):
            return "링크를 거친다 ({0})".format(cur)
    probe = cur
    while not os.path.lexists(probe) and probe != os.path.dirname(probe):
        probe = os.path.dirname(probe)
    real_root = os.path.realpath(str(root))
    real = os.path.realpath(probe)
    if real != real_root and not real.startswith(real_root + os.sep):
        return "실제 위치가 작업 트리 밖이다"
    return None


def frontmatter_scalars(path) -> dict | None:
    """맨 앞 `---` 블록의 최상위 `key: value` 줄. 읽지 못하면 None, frontmatter 가 없으면 {}."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    if not text.startswith("---\n"):
        return {}
    out = {}
    for line in text[4:].splitlines():
        if line.strip() == "---":
            break
        if not line or line[0] in " \t#-" or ":" not in line:
            continue
        key, val = line.split(":", 1)
        out[key.strip()] = val.strip().strip('"').strip("'")
    return out


def interview_state_path(topic: str, date: str | None = None,
                         cwd: str | None = None) -> tuple[Path | None, list[str]]:
    """`<작업 트리 루트>/docs/superpowers/interview/<날짜>-<topic>-interview.state.md`.

    계산한 세 자리(상태 · brief · audit) 중 이미 있는 파일의 `type:` 이 그 자리의 종류와 다르면
    경로를 내지 않는다 — seed(`interview-seed`) · seed audit(`interview-seed-audit`) 위에 인터뷰를 시작하지 않는다.
    """
    msgs: list[str] = []
    if not topic or not KEBAB.fullmatch(topic):
        return None, ["[spec-distill] topic 이 kebab-case 가 아니다: {0!r}".format(topic)]
    date = date or datetime.date.today().isoformat()
    if not _DATE.fullmatch(date):
        return None, ["[spec-distill] 날짜가 YYYY-MM-DD 가 아니다: {0!r}".format(date)]
    root, is_git = worktree_root(cwd)
    if not is_git:
        msgs.append("[spec-distill] git 저장소가 아니다 — {0} 기준으로 경로를 냈다".format(root))
    d = root.joinpath(*INTERVIEW_DIR)
    stem = "{0}-{1}-interview".format(date, topic)
    for q in [d] + [d / (stem + sfx) for sfx, _ in _SLOTS]:
        why = inside_root(q, root)
        if why:
            msgs.append("[spec-distill] 경로가 작업 트리 밖이거나 링크를 거친다 — {0}: {1}".format(q, why))
            return None, msgs
    for suffix, kind in _SLOTS:
        p = d / (stem + suffix)
        if not (p.exists() or p.is_symlink()):
            continue
        fm = frontmatter_scalars(p)
        have = None if fm is None else fm.get("type")
        if have != kind:
            msgs.append("[spec-distill] 계산한 자리에 다른 종류의 파일이 있다 — {0} (type: {1}). "
                        "남의 파일 위에 인터뷰를 시작하지 않는다.".format(p, have or "없음"))
            return None, msgs
    return d / (stem + ".state.md"), msgs


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: state_path.py {state-root|session-id|interview-state} …", file=sys.stderr)
        return 2
    sub = argv[1]
    if sub == "state-root":
        cwd = argv[2] if len(argv) >= 3 else None
        print(str(state_root(cwd)))
        return 0
    if sub == "session-id":
        # env-only resolve (no hook payload on the CLI path). Skills key their
        # per-session state directory with this sid.
        # 계약: 풀리지 않으면 exit 1, stdout 은 비어 있다.
        # 규칙: 호출자는 빈 sid 로 `$ROOT/$sid/<leaf>` 를 만들지 않는다 — 빈 값이면 소리를
        # 내고 거부한다. 본보기는 `skills/request-framing/SKILL.md` 의 sid 가드다(sid 가
        # 실값이고 mkdir 이 성공할 때만 경로가 생긴다). 호출자는 여기 적지 않고
        # `git grep -n 'state_path.py" session-id'` 로 센다.
        # 알려진 위반(연기): reviewing-brief ## 상태 · spec-interview/references/finishing.md — 빈 sid 가드 없음.
        sid = resolve_session_id(None)
        if sid is None:
            return 1
        print(sid)
        return 0
    if sub == "interview-state":
        def opt(name):
            if name in argv:
                i = argv.index(name)
                if i + 1 < len(argv):
                    return argv[i + 1]
            return None
        path, msgs = interview_state_path(opt("--topic") or "", opt("--date"), opt("--cwd"))
        for m in msgs:
            print(m, file=sys.stderr)
        if path is None:
            return 2
        print(str(path))
        return 0
    if sub == "path-inside":
        if "--root" not in argv or argv.index("--root") + 1 >= len(argv):
            print("usage: state_path.py path-inside --root <R> <PATH>...", file=sys.stderr)
            return 2
        i = argv.index("--root")
        root = argv[i + 1]
        paths = argv[2:i] + argv[i + 2:]
        bad = 0
        for q in paths:
            why = inside_root(q, root)
            if why:
                print("[spec-distill] 경로가 작업 트리 밖이거나 링크를 거친다 — {0}: {1}".format(q, why),
                      file=sys.stderr)
                bad = 1
        return 2 if bad else 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
