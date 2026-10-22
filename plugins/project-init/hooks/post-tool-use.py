#!/usr/bin/env python3
"""PostToolUse hook for project-init plugin.

Runs after Bash and EnterWorktree tool calls:
1. Branch naming (Bash and EnterWorktree) — observes, after the call, which
   local branches were just made (their reflog's last line is a create /
   rename / copy within NEW_BRANCH_WINDOW seconds) and validates each name
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


def _git(cwd, *args):
    """Run git in cwd; stdout bytes on rc 0, else None (git 없음 · 레포 아님 · 시간 초과 포함)."""
    env = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_OPTIONAL_LOCKS="0")
    try:
        cp = subprocess.run(
            ["git", "-C", cwd, *args], capture_output=True, env=env, timeout=5
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return cp.stdout if cp.returncode == 0 else None


def _last_reflog_line(path):
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        f.seek(max(0, f.tell() - 8192))
        lines = [ln for ln in f.read().split(b"\n") if ln.strip()]
    return lines[-1].decode("utf-8", "replace") if lines else ""


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


def new_branches(cwd, now, window=NEW_BRANCH_WINDOW):
    """Branches whose reflog's last line made them within `window` seconds.

    공용 git 디렉토리의 logs/refs/heads/** 를 직접 읽는다(브랜치마다 git 을 띄우지
    않는다 · 상태 파일 없음). 레포가 아니거나 reflog 가 없으면 빈 목록.
    """
    out = _git(cwd, "rev-parse", "--git-common-dir")
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
                line = _last_reflog_line(path)
            except OSError:
                continue
            name = os.path.relpath(path, root).replace(os.sep, "/")
            if _is_new_branch_line(line, name, now, window):
                found.append(name)
    return sorted(found)


def read_branch_rule(cwd):
    """(pattern, None) or (None, fail-open notice) — 규칙은 기본 브랜치 판에서 읽는다.

    None => fail-open: 전략 미선언 → 브랜치명 검증을 건너뛴다(loud advisory).
    「기본 ref 없음」은 따로 알린다. 나머지 다섯은 하나의 fail-open 안내로 통일한다:
    (1) 파일 부재, (2) ```regex 블록 부재, (3) malformed regex(re.error),
    (4) 빈/공백-only 블록(.strip() 후 empty), (5) non-UTF-8/binary 파일(UnicodeDecodeError).
    """
    if _git(cwd, "rev-parse", "--verify", "-q", DEFAULT_REF) is None:
        return None, (
            "project-init: 기본 브랜치(origin/HEAD)를 찾지 못해 브랜치 이름 규칙을 읽지 못했다 "
            "— 브랜치 이름 검사를 건너뛴다(fail-open).\n"
            "기본 브랜치를 알려 주려면: git remote set-head origin --auto"
        )
    missing = (
        f"project-init: 기본 브랜치(origin/HEAD) 판의 {STRATEGY_PATH} 에서 쓸 수 있는 "
        "브랜치 이름 규칙을 찾지 못했다 — 브랜치 이름 검사를 건너뛴다(fail-open)."
    )
    raw = _git(cwd, "show", f"{DEFAULT_REF}:{STRATEGY_PATH}")
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


def observe_branches(cwd, now):
    """Warnings for branches made just now whose names break the default branch's rule."""
    names = [n for n in new_branches(cwd, now) if n not in PROTECTED_BRANCHES]
    if not names:
        return []
    pattern, notice = read_branch_rule(cwd)
    if pattern is None:  # 유효 패턴 없음 → fail OPEN, loudly
        return [(notice, None)]  # 모델이 할 일이 없다 — 수정할 대상 자체가 없는 경고다
    return [r for r in (check_branch_name(n, pattern) for n in names) if r]


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
    results = observe_branches(cwd, time.time())
    if tool_name == "Bash" and isinstance(tool_input, dict):
        commit = validate_commit(str(tool_input.get("command", "")))
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
