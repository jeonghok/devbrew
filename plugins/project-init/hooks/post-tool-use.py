#!/usr/bin/env python3
"""PostToolUse hook for project-init plugin.

Validates two things on Bash tool use:
1. Branch naming — detects git checkout -b / git switch -c and validates
   the branch name against the pattern in docs/git-workflow/branch-strategy.md.
2. Commit message — detects git commit -m and validates Conventional Commits format.

Both validators emit non-blocking warnings via systemMessage.

Kill switches:
  DEVBREW_DISABLE_PROJECT_INIT=1                 - disables this hook entirely
  DEVBREW_SKIP_HOOKS=project-init:post-tool-use  - skip just this one
  DEVBREW_SKIP_HOOKS=project-init:PostToolUse    - skip every PostToolUse hook here
"""

import json
import os
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from kill_switch_active import kill_switch_active  # noqa: E402

# --- Constants ---

CONVENTIONAL_COMMIT_PATTERN = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:\s.+"
)

BRANCH_CREATE_RE = re.compile(r"git\s+(?:checkout\s+-b|switch\s+-c)\s+(\S+)")
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


def get_branch_pattern():
    """Return the declared branch pattern, or None when none is validly declared.

    None => fail-open: 전략 미선언 → 브랜치명 검증을 건너뛴다(loud advisory).
    아래 다섯을 하나의 fail-open 경로로 통일한다: (1) 파일 부재, (2) ```regex 블록
    부재, (3) malformed regex(re.error), (4) 빈/공백-only 블록(.strip() 후 empty),
    (5) non-UTF-8/binary 파일(UnicodeDecodeError) — crash 대신 loud fail-open (qg-security).
    """
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
    strategy_path = os.path.join(
        project_dir, "docs", "git-workflow", "branch-strategy.md"
    )
    try:
        with open(strategy_path, "r", encoding="utf-8") as f:  # explicit UTF-8: 생성 파일이 Korean-primary라 locale 기본 인코딩 의존 시 valid 파일이 non-UTF-8 locale에서 오판됨 (qg-codex)
            content = f.read()
        match = re.search(r"```regex\n(.+?)\n```", content)
        if match and match.group(1).strip():  # 빈/공백-only 캡처 → 무효(fail-open, reviewer cccfc098)
            return re.compile(match.group(1).strip())
    except (OSError, re.error, ValueError):  # OSError⊇FileNotFound/IOError/PermissionError; ValueError⊇UnicodeDecodeError → non-UTF-8 파일도 fail-open (qg-security)
        pass
    return None


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


def validate_branch(command):
    """Check branch creation commands for naming convention compliance."""
    match = BRANCH_CREATE_RE.search(command)
    if not match:
        return None

    branch_name = match.group(1)

    if branch_name in PROTECTED_BRANCHES:
        return None

    pattern = get_branch_pattern()
    if pattern is None:  # 유효 패턴 없음(부재/regex-less/malformed/빈-블록/비-UTF-8) → fail OPEN, loudly
        return (
            "project-init: no valid branch-naming pattern found in "
            "docs/git-workflow/branch-strategy.md — skipping branch-name "
            "validation (fail-open)."
        )
    if pattern.match(branch_name):
        return None

    # Suggest correction — prefixes derived from the active pattern (no feature/ hardcode)
    name_part = branch_name.split("/", 1)[1] if "/" in branch_name else branch_name
    prefixes = derive_prefixes(pattern)
    if prefixes:
        hint = f"Allowed prefixes: {', '.join(prefixes)}"
        cmd = f"Rename with: git branch -m <prefix>/{name_part}   (choose a prefix above)"
    else:  # exotic regex → NO feature/ hardcode
        hint = "See docs/git-workflow/branch-strategy.md for allowed prefixes."
        cmd = None

    lines = [
        f'project-init: Branch "{branch_name}" does not follow naming convention.',
        f"Expected pattern: {pattern.pattern}",
        hint,
    ]
    if cmd:
        lines.append(cmd)
    return "\n".join(lines)


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

    return (
        f"project-init: Commit message does not follow Conventional Commits format.\n"
        f"Expected: <type>(<scope>): <description>\n"
        f"Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\n"
        f"Suggested: {suggested_type}: {first_line}"
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

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    if tool_name != "Bash":
        print(json.dumps({}))
        sys.exit(0)

    command = tool_input.get("command", "")

    # Run BOTH validators (no short-circuit): a branch warning must not
    # suppress commit validation on compound commands (§5.5).
    warnings = [w for w in (validate_branch(command), validate_commit(command)) if w]

    if warnings:
        print(json.dumps({"systemMessage": "\n\n".join(warnings)}))
    else:
        print(json.dumps({}))

    sys.exit(0)


if __name__ == "__main__":
    main()
