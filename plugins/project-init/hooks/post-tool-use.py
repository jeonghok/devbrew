#!/usr/bin/env python3
"""PostToolUse hook for project-init plugin.

Runs after Bash and EnterWorktree tool calls:
1. Branch naming (Bash and EnterWorktree) — observes, after the call, which
   local branches were just made (their reflog has a create / rename / copy
   line within NEW_BRANCH_WINDOW seconds) — keeping only those the tool input
   names or that cwd has checked out, so another session's branch is left
   alone; a rename command goes only to a branch that is cwd's current
   branch after the call and that the tool input names, or that EnterWorktree
   made — and validates each name
   against the pattern in docs/git-workflow/branch-strategy.md as committed on
   the default branch (refs/remotes/origin/HEAD), not the working tree.
2. Commit message (Bash only) — detects git commit -m and validates
   Conventional Commits format.

Both validators are non-blocking. Each emits a human-facing warning on
systemMessage; the branch validator additionally emits a self-contained,
runnable fix command on hookSpecificOutput.additionalContext (the model
channel) when one exists. The commit validator never emits a model-channel
command — a rewritten commit message re-matches COMMIT_MSG_RE and would
re-fire on the retry without bound, so its suggestion stays on the human
channel only.

Kill switches:
  DEVBREW_PROJECT_INIT_DISABLE=1                 - disables this hook entirely
  DEVBREW_SKIP_HOOKS=project-init:post-tool-use  - skip just this one
  DEVBREW_SKIP_HOOKS=project-init:PostToolUse    - skip every PostToolUse hook here
"""

import json
import os
import pathlib
import re
import shlex
import signal
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from kill_switch_active import kill_switch_active  # noqa: E402

# --- Constants ---

CONVENTIONAL_COMMIT_PATTERN = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:\s.+"
)

DEFAULT_REF = "refs/remotes/origin/HEAD"
STRATEGY_PATH = "docs/git-workflow/branch-strategy.md"
NEW_BRANCH_WINDOW = 60.0
REFLOG_CHUNK = 8192
REFLOG_SCAN_MAX = 1 << 20  # 한 브랜치 reflog 를 거슬러 읽는 상한 — 넘으면 「끝까지 못 읽음」으로 알린다
GIT_BUDGET = 8.0  # 한 실행의 git 호출 전체 — hooks.json 의 timeout(10초) 안
CREATED_PREFIX = "branch: Created from "
RENAMED_RE = re.compile(r"Branch: (?:renamed|copied) refs/heads/.+ to refs/heads/(.+)$")
COMMIT_MSG_RE = re.compile(r"""git\s+commit\s+[^;|&]*-m\s+(['"])(.*?)\1""")
HEREDOC_COMMIT_RE = re.compile(
    r"""git\s+commit\s+[^;|&]*-m\s+['"]\$\(cat\s+<<['"]?(\w+)['"]?\n(.*?)\n\1""",
    re.DOTALL,
)

COMMIT_TYPES = {
    "add": "feat",
    "implement": "feat",
    "create": "feat",
    "introduce": "feat",
    "fix": "fix",
    "repair": "fix",
    "correct": "fix",
    "resolve": "fix",
    "update": "refactor",
    "change": "refactor",
    "modify": "refactor",
    "move": "refactor",
    "rename": "refactor",
    "remove": "chore",
    "delete": "chore",
    "clean": "chore",
    "document": "docs",
    "test": "test",
}

# Protected branches that should never be validated as feature branches
PROTECTED_BRANCHES = {"main", "master", "develop", "dev"}


# --- Helpers ---


class GitTimeout(Exception):
    """The shared git deadline ran out."""


def _deadline():
    return time.monotonic() + GIT_BUDGET


def _git(cwd, *args, deadline=None):
    """Run git in cwd; stdout bytes on rc 0, else None (git 없음 · 레포 아님).

    한 실행의 모든 git 호출은 deadline 하나를 나눠 쓴다. 다 쓰면 GitTimeout —
    프로세스 그룹째 끊어 손자 프로세스가 파이프를 붙잡아도 매달리지 않는다.
    """
    remaining = (deadline if deadline is not None else _deadline()) - time.monotonic()
    if remaining <= 0:
        raise GitTimeout()
    env = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_OPTIONAL_LOCKS="0")
    try:
        p = subprocess.Popen(
            ["git", "-C", cwd, *args], stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env,
            start_new_session=True,
        )
    except OSError:
        return None
    try:
        out, _err = p.communicate(timeout=remaining)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            p.kill()
        try:
            p.communicate(timeout=1)
        except subprocess.TimeoutExpired:
            pass
        raise GitTimeout()
    return out if p.returncode == 0 else None


def checked_out_elsewhere(cwd, deadline=None):
    """{branch: worktree path} for branches checked out in a worktree other than cwd's.

    None when the worktree list can't be read. cwd 의 작업 트리는 cwd 를 품는 가장 긴
    작업 트리 경로다(안에 중첩된 .claude/worktrees/* 를 바깥 작업 트리와 가른다).
    """
    out = _git(cwd, "worktree", "list", "--porcelain", deadline=deadline)
    if out is None:
        return None
    paths, trees, path = [], [], None
    for line in out.decode("utf-8", "replace").splitlines():
        if line.startswith("worktree "):
            path = os.path.realpath(line[len("worktree "):])
            paths.append(path)
        elif line.startswith("branch refs/heads/") and path is not None:
            trees.append((path, line[len("branch refs/heads/"):]))
    here = os.path.realpath(cwd)
    # 브랜치 줄 없는(detached) 작업 트리도 cwd 의 작업 트리일 수 있다 — 모든 경로에서 고른다.
    own = max(
        (p for p in paths if here == p or here.startswith(p.rstrip(os.sep) + os.sep)),
        key=len, default=None,
    )
    return {b: p for p, b in trees if p != own}


def _inert(text):
    """사람 · 모델 줄에 넣는 경로 — 줄바꿈 · 제어 문자를 repr 꼴(`\\n`)로 바꿔 줄을 쪼개거나 지시를 끼우지 못하게 한다."""
    return "".join(c if c.isprintable() else repr(c)[1:-1] for c in text)


def _line_time(line):
    """reflog 한 줄(bytes)의 시각, 읽지 못하면 None."""
    head, sep, _msg = line.partition(b"\t")
    parts = head.split()
    if not sep or len(parts) < 2:
        return None
    try:
        return int(parts[-2])
    except ValueError:
        return None


def _reflog_lines_since(path, cutoff):
    """(줄들, 끝까지 봤나) — reflog 를 끝에서부터 REFLOG_CHUNK 씩 거슬러 읽는다.

    한 명령이 만들기 뒤에 커밋 · 리셋 줄을 얼마든지 남길 수 있다(`checkout -b X && cherry-pick A..B`).
    cutoff 보다 옛 온전한 줄이 나오거나 파일 처음에 닿으면 멈춘다 — 그 앞 줄은 모두 더 옛 줄이다.
    REFLOG_SCAN_MAX 에 닿아도 cutoff 까지 못 봤으면 (읽은 줄, False) 를 낸다.
    """
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        end = pos = f.tell()
        buf = b""
        complete = True
        while pos > 0:
            if end - pos >= REFLOG_SCAN_MAX:
                complete = False
                break
            step = min(REFLOG_CHUNK, pos)
            pos -= step
            f.seek(pos)
            buf = f.read(step) + buf
            whole = buf.split(b"\n")[1:] if pos > 0 else buf.split(b"\n")
            first = next((t for t in map(_line_time, whole) if t is not None), None)
            if first is not None and first < cutoff:
                break
    lines = buf.split(b"\n")
    if pos > 0:
        lines = lines[1:]  # 앞이 잘린 줄 — 그 뒤에 이미 cutoff 보다 옛 줄이 있다
    return [ln.decode("utf-8", "replace") for ln in lines if ln.strip()], complete


def _is_new_branch_line(line, branch, now, window):
    """reflog 한 줄이 window 초 안의 만들기 · 이름 바꾸기 · 복사인가."""
    head, sep, msg = line.partition("\t")
    parts = head.split()
    if not sep or len(parts) < 2:
        return False
    try:
        ts = int(parts[-2])
    except ValueError:
        return False
    if now - ts > window:
        return False
    if msg.startswith(CREATED_PREFIX):
        return True
    m = RENAMED_RE.match(msg)
    return bool(m and m.group(1) == branch)


def new_branches(cwd, now, window=NEW_BRANCH_WINDOW, deadline=None, unread=None):
    """Branches whose reflog has a create / rename / copy line within `window` seconds.

    마지막 줄만 보지 않는다 — `git checkout -b X && git commit` 은 만들기 줄 뒤에 커밋 줄을 남긴다.
    window 안의 줄을 끝까지 읽지 못한(REFLOG_SCAN_MAX) 브랜치는 unread 목록에 더한다.

    공용 git 디렉토리의 logs/refs/heads/** 를 직접 읽는다(브랜치마다 git 을 띄우지
    않는다 · 상태 파일 없음). 레포가 아니거나 reflog 가 없으면 빈 목록.
    """
    out = _git(cwd, "rev-parse", "--git-common-dir", deadline=deadline)
    if out is None:
        return []
    common = os.path.join(cwd, out.decode("utf-8", "replace").strip())
    root = os.path.join(common, "logs", "refs", "heads")
    found = []
    for dirpath, _dirs, files in os.walk(root):
        for fn in files:
            path = os.path.join(dirpath, fn)
            try:
                if os.path.getmtime(path) < now - window:
                    continue
                lines, complete = _reflog_lines_since(path, now - window)
            except OSError:
                continue
            name = os.path.relpath(path, root).replace(os.sep, "/")
            if any(_is_new_branch_line(ln, name, now, window) for ln in lines):
                found.append(name)
            elif not complete and unread is not None:
                unread.append(name)
    return sorted(found)


def read_branch_rule(cwd, deadline=None):
    """(pattern, None) or (None, fail-open notice) — 규칙은 기본 브랜치 판에서 읽는다.

    None => fail-open: 전략 미선언 → 브랜치명 검증을 건너뛴다(loud advisory).
    「origin 원격 없음」 · 「기본 ref 없음」은 따로 알린다. 나머지 다섯은 하나의 fail-open
    안내로 통일한다: (1) 파일 부재, (2) ```regex 블록 부재, (3) malformed regex(re.error),
    (4) 빈/공백-only 블록(.strip() 후 empty), (5) non-UTF-8/binary 파일(UnicodeDecodeError).
    """
    if _git(cwd, "rev-parse", "--verify", "-q", DEFAULT_REF, deadline=deadline) is None:
        remotes = _git(cwd, "remote", deadline=deadline) or b""
        if b"origin" not in remotes.split():
            return None, (
                "project-init: `origin` 원격이 없어 기본 브랜치의 브랜치 이름 규칙을 읽지 못했다 "
                "— 브랜치 이름 검사를 건너뛴다(fail-open)."
            )
        return None, (
            "project-init: 기본 브랜치(origin/HEAD)를 찾지 못해 브랜치 이름 규칙을 읽지 못했다 "
            "— 브랜치 이름 검사를 건너뛴다(fail-open).\n"
            "기본 브랜치를 알려 주려면: git remote set-head origin --auto"
        )
    missing = (
        f"project-init: 기본 브랜치(origin/HEAD) 판의 {STRATEGY_PATH} 에서 쓸 수 있는 "
        "브랜치 이름 규칙을 찾지 못했다 — 브랜치 이름 검사를 건너뛴다(fail-open)."
    )
    raw = _git(cwd, "show", f"{DEFAULT_REF}:{STRATEGY_PATH}", deadline=deadline)
    if raw is None:
        return None, missing
    try:
        content = raw.decode("utf-8")  # explicit UTF-8: locale 과 무관하게 Korean-primary 파일을 읽는다 (qg-codex)
        match = re.search(r"```regex\n(.+?)\n```", content)
        if match and match.group(1).strip():  # 빈/공백-only 캡처 → 무효(fail-open, reviewer cccfc098)
            return re.compile(match.group(1).strip()), None
    except (re.error, ValueError):  # ValueError⊇UnicodeDecodeError → non-UTF-8 파일도 fail-open (qg-security)
        pass
    return None, missing


def get_branch_pattern(cwd):
    """The default branch's declared branch pattern, or None (fail-open)."""
    return read_branch_rule(cwd)[0]


def derive_prefixes(pattern):
    """Extract allowed branch prefixes from a compiled pattern's leading alternation group.

    ^(feature|fix|release|hotfix)/…  ->  ["feature","fix","release","hotfix"]
    ^(?:feature|fix)/…               ->  ["feature","fix"]   (non-capturing OK)
    선두가 identifier-alternation이 아니면(inline flags (?i), nested group, 리터럴 등) → []
    (교정 제안에서 prefix 하드코딩 금지). 그룹 내용을 [a-z][a-z0-9-]* 토큰의 |-결합으로
    못박아 `(?i)` 같은 flag 그룹이 "i" 프리픽스로 오파싱되지 않게 한다(reviewer a909f052).
    """
    m = re.match(
        r"\^?\((?:\?:)?([a-z][a-z0-9-]*(?:\|[a-z][a-z0-9-]*)*)\)", pattern.pattern
    )
    return m.group(1).split("|") if m else []


def guess_commit_type(message):
    """Guess the conventional commit type from a plain message."""
    first_word = message.strip().split()[0].lower() if message.strip() else ""
    return COMMIT_TYPES.get(first_word, "feat")


_NAME_LEFT = r"(?:^|(?<=[\s'\"`=(;&|<>/]))"
_NAME_RIGHT = r"(?=$|[\s'\"`);&|<>])"


def named_in(text, name):
    """도구 입력 글에 브랜치 이름이 한 낱말로 나오는가(`Bad` 는 `Bad2` · `x/Bad.1` 에 들지 않는다)."""
    return bool(text) and re.search(_NAME_LEFT + re.escape(name) + _NAME_RIGHT, text) is not None


def _current_branch(cwd, deadline=None):
    out = _git(cwd, "symbolic-ref", "-q", "HEAD", deadline=deadline)
    ref = out.decode("utf-8", "replace").strip() if out else ""
    return ref[len("refs/heads/"):] if ref.startswith("refs/heads/") else None


def _entered_worktree_branches(cwd, worktree_name, deadline=None):
    """EnterWorktree 의 name 으로 만든 작업 트리가 쓰는 브랜치들, 작업 트리 목록을 못 읽으면 None.

    payload 의 cwd 가 옮기기 전 레포여도 그 작업 트리의 브랜치를 이 호출의 것으로 본다. 경로 끝은
    `/<name>` 이고, name 의 `/` 는 `+` 로(레포 기록의 꼴: feature/x → feature+x) 또는 하위 폴더로 본다.
    """
    if not worktree_name:
        return set()
    tails = _worktree_tails(worktree_name)
    trees = checked_out_elsewhere(cwd, deadline=deadline)
    if trees is None:
        return None
    return {b for b, p in trees.items() if any(p.endswith(t) for t in tails)}


def _worktree_tails(worktree_name):
    name = worktree_name.strip("/")
    return {os.sep + name.replace("/", "+"), os.sep + name.replace("/", os.sep)}


def _cwd_is_linked_worktree(cwd, deadline=None):
    """cwd 가 링크된 작업 트리(메인 체크아웃이 아닌 것)인가 — git-dir 과 공용 git-dir 이 다르다."""
    out = _git(cwd, "rev-parse", "--git-dir", "--git-common-dir", deadline=deadline)
    if not out:
        return False
    dirs = [os.path.realpath(os.path.join(cwd, d)) for d in out.decode("utf-8", "replace").split("\n") if d]
    return len(dirs) == 2 and dirs[0] != dirs[1]


def _cwd_is_entered_worktree(cwd, worktree_name, deadline=None):
    """EnterWorktree 의 name 으로 만든 작업 트리가 cwd 의 작업 트리인가(payload 의 cwd 가 새 작업 트리일 때)."""
    if not worktree_name:
        return False
    out = _git(cwd, "rev-parse", "--show-toplevel", deadline=deadline)
    top = os.path.realpath(out.decode("utf-8", "replace").strip()) if out else ""
    # 메인 체크아웃의 폴더 이름이 name 과 같을 수 있다 — 링크된 작업 트리여야 EnterWorktree 가 만든 것이다.
    return (bool(top) and any(top.endswith(t) for t in _worktree_tails(worktree_name))
            and _cwd_is_linked_worktree(cwd, deadline=deadline))


def observe_branches(cwd, now, text, worktree_name=None, worktree_created=False):
    """Warnings for branches this tool call made just now whose names break the default branch's rule.

    text 는 도구 입력 글(Bash 의 명령)이다 — 새 브랜치 가운데 이 글이 이름을 가리키거나 cwd 가
    지금 쓰는 브랜치이거나 EnterWorktree 의 name 으로 만든 작업 트리의 브랜치만 이 호출이 만든 것으로 본다.
    worktree_created 는 EnterWorktree 가 새 작업 트리를 만든 호출(path 없음)이다.
    """
    deadline = _deadline()
    try:
        return _observe(cwd, now, deadline, text, worktree_name, worktree_created)
    except GitTimeout:
        return [(
            "project-init: git 이 제시간에 끝나지 않아 새 브랜치 이름 검사를 건너뛴다(fail-open).",
            None,
        )]


def _observe(cwd, now, deadline, text, worktree_name=None, worktree_created=False):
    unread = []
    names = [n for n in new_branches(cwd, now, deadline=deadline, unread=unread) if n not in PROTECTED_BRANCHES]
    # 공용 git 디렉토리라 다른 세션이 막 만든 브랜치도 보인다 — 이 호출과 무관한 브랜치는 다루지
    # 않는다(그 이름을 이 세션 모델이 바꾸게 하지 않는다).
    notes = []
    rest = [n for n in names if not named_in(text, n)]
    entered = set()
    current = _current_branch(cwd, deadline=deadline) if (names or unread) else None
    if rest:
        entered = _entered_worktree_branches(cwd, worktree_name, deadline=deadline)
        mine = {current} | (entered or set())
        names = [n for n in names if n not in rest or n in mine]
        if entered is None and any(n not in mine for n in rest):
            # 작업 트리 목록을 못 읽어 EnterWorktree 의 브랜치를 가리지 못했다 — 조용히 빠지지 않게 알린다.
            notes.append((
                "project-init: 작업 트리 목록을 읽지 못해 EnterWorktree 가 만든 브랜치를 가리지 못했다 "
                "— 그 브랜치 이름 검사를 건너뛴다(fail-open).",
                None,
            ))
        elif worktree_created and not worktree_name and any(n not in mine for n in rest):
            # name 없이(무작위 이름) 만든 작업 트리 — cwd 가 옮기기 전 레포면 어느 새 브랜치가 이 호출의 것인지 모른다.
            notes.append((
                "project-init: EnterWorktree 에 name 이 없어 새 작업 트리의 브랜치를 가리지 못했다 "
                "— 그 브랜치 이름 검사를 건너뛴다(fail-open).",
                None,
            ))
    unread = [n for n in unread if n not in PROTECTED_BRANCHES and (named_in(text, n) or n == current)]
    if unread:
        notes.append((
            f"project-init: 브랜치 {', '.join(_inert(n) for n in unread)} 의 reflog 가 길어 최근 "
            f"{int(NEW_BRANCH_WINDOW)}초의 기록을 끝까지 읽지 못했다 — 그 브랜치 이름 검사를 건너뛴다(fail-open).",
            None,
        ))
    if not names:
        return notes
    # 이름 바꾸기 명령의 근거는 명령 글의 해석이 아니라 git 상태다 — 호출 뒤 cwd 의 지금 브랜치이면서
    # 명령 글이 그 이름을 가리키거나, EnterWorktree 가 만든 작업 트리의 브랜치일 때만 낸다. 이름을
    # 가리키기만 한 브랜치(다른 세션 것일 수 있다)와 명령 글이 가리키지 않는 지금 브랜치(같은 체크아웃의
    # 다른 세션)는 알리기만 한다.
    proven = {n for n in names if n == current and named_in(text, n)} | (entered or set())
    if current in names and (
            _cwd_is_entered_worktree(cwd, worktree_name, deadline=deadline)
            or (worktree_created and not worktree_name and _cwd_is_linked_worktree(cwd, deadline=deadline))):
        # EnterWorktree 가 방금 만든 작업 트리의 지금 브랜치 — 다른 세션의 것일 수 없다.
        proven.add(current)
    return notes + _judge(cwd, names, deadline, proven)


UNPROVEN_NOTE = ("\n이 브랜치가 이 명령의 것이라는 근거가 없어(이 명령 뒤의 지금 브랜치가 아니거나 명령이 그 이름을 "
                 "가리키지 않는다 — 다른 세션의 것일 수 있다) 이 세션에서는 이름을 바꾸라고 하지 않는다.")


def _judge(cwd, names, deadline, proven=None):
    """이 호출의 새 브랜치 names 를 기본 브랜치 규칙으로 판정한 (사람, 모델) 알림들.

    proven 밖의 브랜치는 알리기만 하고 이름 바꾸기 명령을 내지 않는다(None 이면 모두 근거 있음).
    """
    pattern, notice = read_branch_rule(cwd, deadline=deadline)
    if pattern is None:  # 유효 패턴 없음 → fail OPEN, loudly
        return [(notice, None)]  # 모델이 할 일이 없다 — 수정할 대상 자체가 없는 경고다
    found = [(n, r) for n, r in ((n, check_branch_name(n, pattern)) for n in names) if r]
    if not any(cmd for _n, (_h, cmd) in found):
        return [r for _n, r in found]
    # 이름 바꾸기는 다른 작업 트리가 쓰는 브랜치에 내지 않는다 — git branch -m 은 그
    # 작업 트리의 HEAD 까지 바꿔 다른 세션의 push · PR · 정리를 깨뜨린다.
    try:
        elsewhere = checked_out_elsewhere(cwd, deadline=deadline)
    except GitTimeout:
        elsewhere = None  # 이름 판정은 이미 났다 — 알림은 내고 명령만 뺀다
    out = []
    for name, (human, cmd) in found:
        if cmd is None:
            pass  # 규칙에서 접두를 뽑지 못한 꼴 — 모델 몫이 원래 없다
        elif elsewhere is None:
            cmd = None
        elif name in elsewhere:
            where = _inert(elsewhere[name])
            human += (f"\n이 브랜치는 다른 작업 트리({where})에서 쓰고 있어 "
                      "이 세션에서는 이름을 바꾸라고 하지 않는다.")
            cmd = (f"브랜치 {shlex.quote(name)}(작업 트리 {where})이 규칙 밖이다 "
                   "— 다른 작업 트리에서 쓰는 중이라 이름 바꾸기 명령을 내지 않는다.")
        elif proven is not None and name not in proven:
            human += UNPROVEN_NOTE
            cmd = None
        out.append((human, cmd))
    if elsewhere is None:
        out.append((
            "project-init: 작업 트리 목록을 읽지 못해 이름 바꾸기 명령은 내지 않는다.",
            "작업 트리 목록을 읽지 못해 규칙 밖 브랜치에 이름 바꾸기 명령을 내지 않았다.",
        ))
    return out


def check_branch_name(branch_name, pattern):
    """(human, model) warning when branch_name breaks pattern, else None."""
    if branch_name in PROTECTED_BRANCHES or pattern.match(branch_name):
        return None

    # Suggest correction — prefixes derived from the active pattern (no feature/ hardcode)
    name_part = branch_name.split("/", 1)[1] if "/" in branch_name else branch_name
    prefixes = derive_prefixes(pattern)
    if prefixes:
        hint = f"허용 접두어: {', '.join(prefixes)}"
        # 옛 이름을 함께 적는다 — 관찰한 브랜치는 지금 브랜치가 아닐 수 있다(worktree add -b).
        cmd = (
            f"Rename the branch: git branch -m {shlex.quote(branch_name)} "
            f"{shlex.quote(prefixes[0] + '/' + name_part)}\n"
            f"Allowed prefixes: {', '.join(prefixes)} — use whichever fits this change."
        )
    else:  # exotic regex → NO feature/ hardcode
        hint = "허용 접두어는 docs/git-workflow/branch-strategy.md 에 있다."
        cmd = None

    lines = [
        f'project-init: 브랜치 이름이 이름 규칙에 맞지 않는다 — "{branch_name}".',
        f"기대하는 형식: {pattern.pattern}",
        hint,
    ]
    # 사람은 「무엇이 왜 틀렸나」를, 모델은 「무엇을 실행하나」를 받는다 (N1).
    # cmd 가 None 인 exotic-regex 경로에서는 모델 몫이 비고, main() 이
    # hookSpecificOutput 자체를 내지 않는다.
    return "\n".join(lines), cmd


def validate_commit(command):
    """Check commit commands for Conventional Commits format."""
    # Skip git merge --no-edit (auto-generated merge commit, no user message to validate)
    if re.search(r"git\s+merge\s+.*--no-edit", command):
        return None

    # Try HEREDOC-style commits first (git commit -m "$(cat <<'EOF'...EOF)")
    heredoc_match = HEREDOC_COMMIT_RE.search(command)
    if heredoc_match:
        message = heredoc_match.group(2)
    else:
        match = COMMIT_MSG_RE.search(command)
        if not match:
            return None
        message = match.group(2)

    # Check first line only (covers both HEREDOC and normal commits)
    first_line = message.split("\n")[0].strip()

    if CONVENTIONAL_COMMIT_PATTERN.match(first_line):
        return None

    suggested_type = guess_commit_type(first_line)

    # 모델 몫은 의도적으로 비어 있다. 이 제안(메시지 재작성)은 고친 메시지로
    # 다시 커밋하면 COMMIT_MSG_RE(:33)에 **재발동**한다 — 브랜치 개명과 달리
    # 구조적 상한이 없다. C16 이 새 강제에 폭주 방지를 요구하는데 이 설계는
    # 가드를 만들지 않기로 했으므로, 비대칭을 숨기지 않고 사람 채널에 남긴다.
    return (
        f"project-init: 커밋 메시지가 Conventional Commits 형식이 아니다.\n"
        f"형식: <type>(<scope>): <설명>\n"
        f"type: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\n"
        f"제안: {suggested_type}: {first_line}",
        None,
    )


# --- Main ---


def main():
    if kill_switch_active("project-init", "post-tool-use", "PostToolUse"):
        print(json.dumps({}))
        sys.exit(0)

    try:
        input_data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        print(json.dumps({}))
        sys.exit(0)

    if not isinstance(input_data, dict):
        print(json.dumps({}))
        sys.exit(0)
    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input") or {}

    if tool_name not in ("Bash", "EnterWorktree"):
        print(json.dumps({}))
        sys.exit(0)

    cwd = input_data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or "."

    # Run BOTH checks (no short-circuit): a branch warning must not
    # suppress commit validation on compound commands (§5.5).
    # EnterWorktree 는 관찰만 한다 — 커밋 명령이 없다.
    if not isinstance(tool_input, dict):
        tool_input = {}
    worktree_name = None
    worktree_created = False
    if tool_name == "Bash":
        text = str(tool_input.get("command", ""))
    else:
        text = " ".join(v for v in tool_input.values() if isinstance(v, str))
        name = tool_input.get("name")
        worktree_name = name if isinstance(name, str) and name.strip("/") else None
        # path 가 있으면 이미 있는 작업 트리로 들어가는 호출이다 — 새 작업 트리를 만들지 않는다.
        worktree_created = not isinstance(tool_input.get("path"), str)
    results = observe_branches(cwd, time.time(), text, worktree_name, worktree_created)
    if tool_name == "Bash":
        commit = validate_commit(text)
        if commit:
            results.append(commit)
    human = [h for h, _m in results if h]
    model = [m for _h, m in results if m]

    out = {}
    if human:
        out["systemMessage"] = "\n\n".join(human)
    if model:
        # 모델이 읽는 채널 (N1). 사람 채널과 **함께** 나간다 — 어느 한쪽으로
        # 옮기면 다른 쪽 수신자를 잃는다.
        out["hookSpecificOutput"] = {
            "hookEventName": "PostToolUse",
            "additionalContext": "\n\n".join(model),
        }
    print(json.dumps(out))

    sys.exit(0)


if __name__ == "__main__":
    main()
