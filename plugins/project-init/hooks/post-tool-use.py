#!/usr/bin/env python3
"""PostToolUse hook for project-init plugin.

Validates two things on Bash tool use:
1. Branch naming — detects git checkout -b / git switch -c and validates
   the branch name against the pattern in docs/git-workflow/branch-strategy.md.
2. Commit message — detects git commit -m and validates Conventional Commits format.

Both validators emit non-blocking warnings via systemMessage.
"""

import json
import os
import re
import sys

# --- Constants ---

DEFAULT_BRANCH_PATTERN = re.compile(r"^(feature|fix)/[\w.-]+$")
CONVENTIONAL_COMMIT_PATTERN = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?!?:\s.+"
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
    """Load branch naming pattern from docs/git-workflow/branch-strategy.md.

    Falls back to default (feature|fix) if the file doesn't exist
    or doesn't contain a regex block.
    """
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
    strategy_path = os.path.join(
        project_dir, "docs", "git-workflow", "branch-strategy.md"
    )
    try:
        with open(strategy_path, "r") as f:
            content = f.read()
        match = re.search(r"```regex\n(.+?)\n```", content)
        if match:
            return re.compile(match.group(1))
    except (FileNotFoundError, IOError, re.error):
        pass
    return DEFAULT_BRANCH_PATTERN


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
    if pattern.match(branch_name):
        return None

    # Suggest correction
    suggestion = branch_name
    if "/" in suggestion:
        suggestion = suggestion.split("/", 1)[1]
    suggestion = f"feature/{suggestion}"

    return (
        f'project-init: Branch "{branch_name}" does not follow naming convention.\n'
        f"Expected pattern: {pattern.pattern}\n"
        f"Suggested: git branch -m {suggestion}"
    )


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
        f"Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore\n"
        f"Suggested: {suggested_type}: {first_line}"
    )


# --- Main ---


def kill_switch_active():
    """Return True if devbrew kill switch env vars opt this hook out."""
    if os.environ.get("DEVBREW_DISABLE_PROJECT_INIT") == "1":
        return True
    skip_list = [s.strip() for s in os.environ.get("DEVBREW_SKIP_HOOKS", "").split(",")]
    return "project-init:post-tool-use" in skip_list


def main():
    if kill_switch_active():
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

    # Try branch validation first, then commit validation
    warning = validate_branch(command) or validate_commit(command)

    if warning:
        print(json.dumps({"systemMessage": warning}))
    else:
        print(json.dumps({}))

    sys.exit(0)


if __name__ == "__main__":
    main()
