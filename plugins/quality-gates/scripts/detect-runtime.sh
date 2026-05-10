#!/usr/bin/env bash
# detect-runtime.sh — emit a YAML manifest describing runtime-verification
# surfaces in the current working directory.
#
# Output (single multi-line YAML to stdout, expected by SKILL.md Gate 3):
#   project_type: web|cli|library|unknown
#   runnable_surfaces: [...]
#   test_runners: [...]
#   mcp_browser: chrome-devtools|playwright|none
#   app_url_candidates: [...]
#   env_status: [...]
#   plan_features: [...]
#   attempted_log_path: .claude/quality-gates/<sid>/gate3-evidence.md
#
# Exit codes: 0 = ok (parse manifest), non-zero = invariant violation
# (skill should fail-open: treat as empty manifest).
#
# Read-only. Never creates / modifies / deletes files.
# Invoke from the project root (relies on $PWD).

set -u  # NOT -e: we want graceful degradation; failure of a sub-detection
        # should not abort the whole detector.

# --- Helpers ---

emit() { printf '%s\n' "$*"; }

# --- Project type detection ---
PROJECT_TYPE="unknown"

# Web: package.json with dev/start/serve, manage.py, app.py with framework, docker-compose
if [[ -f package.json ]] && grep -qE '"(dev|start|serve)"' package.json 2>/dev/null; then
  PROJECT_TYPE="web"
elif [[ -f manage.py ]] || \
     ([[ -f app.py ]] && grep -qE '(flask|fastapi|django)' app.py 2>/dev/null) || \
     ([[ -f main.py ]] && grep -qE '(flask|fastapi|uvicorn|django)' main.py 2>/dev/null); then
  PROJECT_TYPE="web"
elif [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
  PROJECT_TYPE="web"
# CLI: pyproject.toml [project.scripts], Cargo.toml [[bin]] without web deps
elif [[ -f pyproject.toml ]] && grep -q '\[project.scripts\]' pyproject.toml 2>/dev/null; then
  PROJECT_TYPE="cli"
elif [[ -f Cargo.toml ]] && grep -q '\[\[bin\]\]' Cargo.toml 2>/dev/null && \
     ! grep -qE '(actix|axum|rocket|warp)' Cargo.toml 2>/dev/null; then
  PROJECT_TYPE="cli"
# Library: only lib/ or src/ with build script, or only test infra
elif [[ -f package.json ]] && grep -qE '"(test|build)"' package.json 2>/dev/null; then
  PROJECT_TYPE="library"
elif [[ -f pyproject.toml ]] && [[ -d tests ]]; then
  PROJECT_TYPE="library"
fi

# --- Emit minimal manifest (Task 5: skeleton) ---
emit "project_type: $PROJECT_TYPE"
emit "runnable_surfaces: []"
emit "test_runners: []"
emit "mcp_browser: none"
emit "app_url_candidates: []"
emit "env_status: []"
emit "plan_features: []"
emit "attempted_log_path: .claude/quality-gates/${CLAUDE_CODE_SESSION_ID:-unknown}/gate3-evidence.md"

exit 0
