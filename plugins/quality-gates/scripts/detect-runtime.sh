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

# --- Runnable surfaces ---
SURFACES=()
TEST_RUNNERS=()

# Helper: append to TEST_RUNNERS only if not already present.
# Uses a portable loop (bash 3.2 compatible, safe under set -u).
add_test_runner() {
  local runner="$1"
  local existing
  if [[ ${#TEST_RUNNERS[@]} -gt 0 ]]; then
    for existing in "${TEST_RUNNERS[@]}"; do
      [[ "$existing" == "$runner" ]] && return 0
    done
  fi
  TEST_RUNNERS+=("$runner")
}

# docker-compose
if [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
  COMPOSE_PATH="docker-compose.yml"
  [[ -f docker-compose.yaml ]] && COMPOSE_PATH="docker-compose.yaml"
  SURFACES+=("$(printf '  - kind: docker-compose\n    path: %s\n    requires_decision: true' "$COMPOSE_PATH")")
fi

# npm-scripts: dev / start / serve / test (each as its own surface)
if [[ -f package.json ]]; then
  for script in dev start serve test; do
    if grep -qE "\"$script\"[[:space:]]*:" package.json 2>/dev/null; then
      SURFACES+=("$(printf '  - kind: npm-script\n    name: %s\n    command: npm run %s' "$script" "$script")")
      if [[ "$script" == "test" ]]; then
        add_test_runner "npm"
      fi
    fi
  done
fi

# pytest
if [[ -f pyproject.toml ]] || [[ -f pytest.ini ]] || [[ -f setup.cfg ]]; then
  if [[ -d tests ]] || [[ -d test ]] || \
     find . -maxdepth 2 \( -name "test_*.py" -o -name "*_test.py" \) 2>/dev/null | head -1 | grep -q .; then
    SURFACES+=("$(printf '  - kind: pytest\n    command: pytest')")
    add_test_runner "pytest"
  fi
fi

# cargo (test + run)
if [[ -f Cargo.toml ]]; then
  SURFACES+=("$(printf '  - kind: cargo-test\n    command: cargo test')")
  add_test_runner "cargo"
  if grep -q '\[\[bin\]\]' Cargo.toml 2>/dev/null; then
    SURFACES+=("$(printf '  - kind: cargo-run\n    command: cargo run')")
  fi
fi

# go
if [[ -f go.mod ]]; then
  SURFACES+=("$(printf '  - kind: go-test\n    command: go test ./...')")
  add_test_runner "go"
  # go run requires a main.go entry; check for it
  if find . -maxdepth 2 -name 'main.go' 2>/dev/null | head -1 | grep -q .; then
    SURFACES+=("$(printf '  - kind: go-run\n    command: go run ./...')")
  fi
fi

# Makefile targets
if [[ -f Makefile ]]; then
  for target in run serve test; do
    if grep -qE "^${target}:" Makefile 2>/dev/null; then
      SURFACES+=("$(printf '  - kind: makefile\n    target: %s\n    command: make %s' "$target" "$target")")
      if [[ "$target" == "test" ]]; then
        add_test_runner "make"
      fi
    fi
  done
fi

# --- Emit manifest ---
emit "project_type: $PROJECT_TYPE"

if [[ ${#SURFACES[@]} -eq 0 ]]; then
  emit "runnable_surfaces: []"
else
  emit "runnable_surfaces:"
  for s in "${SURFACES[@]}"; do emit "$s"; done
fi

if [[ ${#TEST_RUNNERS[@]} -eq 0 ]]; then
  emit "test_runners: []"
else
  emit "test_runners:"
  for r in "${TEST_RUNNERS[@]}"; do emit "  - $r"; done
fi

emit "mcp_browser: none"
emit "app_url_candidates: []"
emit "env_status: []"
emit "plan_features: []"
emit "attempted_log_path: .claude/quality-gates/${CLAUDE_CODE_SESSION_ID:-unknown}/gate3-evidence.md"

exit 0
