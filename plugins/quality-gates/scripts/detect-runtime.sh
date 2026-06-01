#!/usr/bin/env bash
# detect-runtime.sh — emit a YAML manifest describing runtime-verification
# surfaces in the current working directory.
#
# Inputs (env vars; all optional except $PWD):
#   $PWD                        — project root (script reads files relative to it)
#   $PLAN_PATH                  — path to plan markdown file. When set and the
#                                 file exists, the script extracts /<route>
#                                 patterns and "X form/page/dashboard/panel"
#                                 phrases into manifest.plan_features.
#   $HOME                       — for ~/.claude/settings.json MCP detection;
#                                 .claude/settings.json and .mcp.json also probed.
#   $CLAUDE_CODE_SESSION_ID     — used to construct attempted_log_path; falls
#                                 back to "unknown" when unset.
#
# Output (single multi-line YAML to stdout, expected by SKILL.md Runtime gate):
#   project_type: web|cli|library|unknown
#   runnable_surfaces: [...]
#   test_runners: [...]
#   mcp_browser: chrome-devtools|playwright|none
#   app_url_candidates: [...]
#   env_status: [...]
#   plan_features: [...]
#   attempted_log_path: $PWD/.claude/quality-gates/<sid>/runtime-evidence.md
#
# Per-kind schema for runnable_surfaces (kind-tagged sum type):
#   docker-compose   — {kind, path, requires_decision}
#   npm-script       — {kind, name ∈ {dev,start,serve,test}, command, requires_decision?}
#   pytest           — {kind, command}
#   cargo-test       — {kind, command}
#   cargo-run        — {kind, command, requires_decision}  (only when Cargo.toml has [[bin]])
#   go-test          — {kind, command}
#   go-run           — {kind, command, requires_decision}  (only when main.go found)
#   makefile         — {kind, target ∈ {run,serve,test}, command, requires_decision?}
#
# Blast-radius rule: process-start kinds (dev/start/serve/run) and any
# surface whose command body matches a network/deploy/destructive signal carry
# requires_decision: true. Test-runner kinds are automatic (no requires_decision).
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

# Returns 0 if the supplied string contains a network/deploy/destructive signal.
# Used to escalate an otherwise-automatic surface to requires_decision.
has_danger_signal() {
  printf '%s' "$1" | grep -qiE 'curl|wget|(^|[^a-z-])ssh([^a-z-]|$)|scp|rsync|deploy|kubectl|terraform|rm[[:space:]]+-rf|git[[:space:]]+push|npm[[:space:]]+publish|docker[[:space:]]+push|--force([[:space:]]|$)'
}

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

# npm-scripts: dev / start / serve / test (each as its own surface).
# Process-start scripts (dev/start/serve) and any script whose command body
# carries a danger signal require an upfront decision (blast-radius gate).
if [[ -f package.json ]]; then
  for script in dev start serve test; do
    if grep -qE "\"$script\"[[:space:]]*:" package.json 2>/dev/null; then
      rd="false"
      case "$script" in
        dev|start|serve) rd="true" ;;
      esac
      script_line=$(grep -E "\"$script\"[[:space:]]*:" package.json 2>/dev/null | head -1)
      has_danger_signal "$script_line" && rd="true"
      block="$(printf '  - kind: npm-script\n    name: %s\n    command: npm run %s' "$script" "$script")"
      [[ "$rd" == "true" ]] && block="$block$(printf '\n    requires_decision: true')"
      SURFACES+=("$block")
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

# cargo (test automatic + run gated)
if [[ -f Cargo.toml ]]; then
  SURFACES+=("$(printf '  - kind: cargo-test\n    command: cargo test')")
  add_test_runner "cargo"
  if grep -q '\[\[bin\]\]' Cargo.toml 2>/dev/null; then
    SURFACES+=("$(printf '  - kind: cargo-run\n    command: cargo run\n    requires_decision: true')")
  fi
fi

# go (test automatic + run gated)
if [[ -f go.mod ]]; then
  SURFACES+=("$(printf '  - kind: go-test\n    command: go test ./...')")
  add_test_runner "go"
  if find . -maxdepth 2 -name 'main.go' 2>/dev/null | head -1 | grep -q .; then
    SURFACES+=("$(printf '  - kind: go-run\n    command: go run ./...\n    requires_decision: true')")
  fi
fi

# Makefile targets (run/serve gated; test automatic unless danger recipe)
if [[ -f Makefile ]]; then
  for target in run serve test; do
    if grep -qE "^${target}:" Makefile 2>/dev/null; then
      rd="false"
      case "$target" in
        run|serve) rd="true" ;;
      esac
      # Scan the target's recipe block for danger signals.
      recipe=$(awk -v t="^${target}:" '
        $0 ~ t { inblk=1; next }
        inblk && /^[^[:space:]]/ { inblk=0 }
        inblk { print }
      ' Makefile 2>/dev/null)
      has_danger_signal "$recipe" && rd="true"
      block="$(printf '  - kind: makefile\n    target: %s\n    command: make %s' "$target" "$target")"
      [[ "$rd" == "true" ]] && block="$block$(printf '\n    requires_decision: true')"
      SURFACES+=("$block")
      if [[ "$target" == "test" ]]; then
        add_test_runner "make"
      fi
    fi
  done
fi

# --- env_status ---
ENV_STATUS=()
for envfile in .env .env.local .env.development; do
  if [[ -f "$envfile" ]]; then
    ENV_STATUS+=("$(printf '  - file: %s\n    exists: true\n    has_example: false' "$envfile")")
  elif [[ -f "${envfile}.example" ]]; then
    ENV_STATUS+=("$(printf '  - file: %s\n    exists: false\n    has_example: true' "$envfile")")
  fi
done

# --- mcp_browser detection ---
# Strategy: read ~/.claude/settings.json or .claude/settings.json for known
# MCP server entries. chrome-devtools wins over playwright.
MCP_BROWSER="none"
SETTINGS_FILES=("$HOME/.claude/settings.json" ".claude/settings.json" ".mcp.json")
for sf in "${SETTINGS_FILES[@]}"; do
  if [[ -f "$sf" ]]; then
    if grep -qi 'chrome-devtools' "$sf" 2>/dev/null; then
      MCP_BROWSER="chrome-devtools"
      break
    fi
    if grep -qi 'playwright' "$sf" 2>/dev/null; then
      MCP_BROWSER="playwright"
      # Don't break — chrome-devtools in another settings file wins
    fi
  fi
done

# --- app_url_candidates ---
URL_CANDIDATES=()
# Default ports
if [[ "$PROJECT_TYPE" == "web" ]]; then
  URL_CANDIDATES+=("http://localhost:3000")
  URL_CANDIDATES+=("http://localhost:8000")
fi
# Parse port mappings from docker-compose
if [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
  COMPOSE_FILE="docker-compose.yml"
  [[ -f docker-compose.yaml ]] && COMPOSE_FILE="docker-compose.yaml"
  # Extract "<host>:<container>" port mappings, take host port
  while IFS= read -r port; do
    [[ -n "$port" ]] && URL_CANDIDATES+=("http://localhost:$port")
  done < <(grep -oE '"[0-9]+:[0-9]+"|- [0-9]+:[0-9]+' "$COMPOSE_FILE" 2>/dev/null \
            | sed -E 's/[^0-9]*([0-9]+):[0-9]+.*/\1/' | sort -u)
fi
# Dedupe
if [[ ${#URL_CANDIDATES[@]} -gt 0 ]]; then
  IFS=$'\n' URL_CANDIDATES=($(printf '%s\n' "${URL_CANDIDATES[@]}" | awk '!seen[$0]++'))
  unset IFS
fi

# --- plan_features extraction ---
PLAN_FEATURES=()
if [[ -n "${PLAN_PATH:-}" ]] && [[ -f "$PLAN_PATH" ]]; then
  # Extract /<word> route patterns and "X form/page" phrases
  while IFS= read -r match; do
    [[ -n "$match" ]] && PLAN_FEATURES+=("$match")
  done < <(grep -oE '/[a-zA-Z][a-zA-Z0-9_/-]*' "$PLAN_PATH" 2>/dev/null | sort -u | head -10)
  while IFS= read -r match; do
    [[ -n "$match" ]] && PLAN_FEATURES+=("\"$match\"")
  done < <(grep -oE '[a-zA-Z]+ (form|page|dashboard|panel)' "$PLAN_PATH" 2>/dev/null | sort -u | head -5)
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

emit "mcp_browser: $MCP_BROWSER"

if [[ ${#URL_CANDIDATES[@]} -eq 0 ]]; then
  emit "app_url_candidates: []"
else
  emit "app_url_candidates:"
  for u in "${URL_CANDIDATES[@]}"; do emit "  - $u"; done
fi

if [[ ${#ENV_STATUS[@]} -eq 0 ]]; then
  emit "env_status: []"
else
  emit "env_status:"
  for e in "${ENV_STATUS[@]}"; do emit "$e"; done
fi

if [[ ${#PLAN_FEATURES[@]} -eq 0 ]]; then
  emit "plan_features: []"
else
  emit "plan_features:"
  for f in "${PLAN_FEATURES[@]}"; do emit "  - $f"; done
fi

emit "attempted_log_path: $PWD/.claude/quality-gates/${CLAUDE_CODE_SESSION_ID:-unknown}/runtime-evidence.md"

exit 0
