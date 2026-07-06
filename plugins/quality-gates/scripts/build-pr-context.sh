#!/usr/bin/env bash
# build-pr-context.sh — deterministic PR-understanding context blob (design §4).
# Pure read-only git. This blob is the ONLY input the de-privileged
# pr-understanding-builder agent ever sees (it has zero filesystem tools), and
# it is the secret-scan corpus. Same input → byte-identical output.
#
# Usage: build-pr-context.sh [--base <ref>] [--history]   (default base: origin/main → main)
#   --history appends `git log -p base..HEAD` (PR-create path secret-scan corpus:
#   catches a secret in an intermediate, later-removed commit before git push).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

base_ref="origin/main"; with_history=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base_ref="$2"; shift 2;;
    --history) with_history=1; shift;;
    *) shift;;
  esac
done
git rev-parse --verify -q "$base_ref" >/dev/null 2>&1 || base_ref="main"
base="$(git merge-base "$base_ref" HEAD 2>/dev/null || echo "")"
[[ -n "$base" ]] || { echo "=== PR CONTEXT (degraded: no merge-base with $base_ref) ==="; exit 0; }
branch="$(git rev-parse --abbrev-ref HEAD)"

echo "=== PR CONTEXT (deterministic) ==="
echo "branch: $branch"
echo "base: $base_ref ($base)"
echo
echo "=== COMMIT MESSAGES (base..HEAD) ==="
git log --reverse --format='* %s%n%b' "$base"..HEAD
echo
echo "=== CHANGED FILES (name-status) ==="
git diff --name-status "$base"..HEAD
echo
echo "=== CHANGED FILE CONTENTS ==="
git diff --name-only --diff-filter=ACMR "$base"..HEAD | sort | while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  echo "--- FILE: $f ---"
  if grep -Iq . "$f" 2>/dev/null; then
    cat "$f"
  elif [[ -s "$f" ]]; then
    echo "(binary omitted)"
  fi
  echo
done
echo "=== NEIGHBOR SIGNATURES (imported, repo-relative) ==="
# diagram-facts.sh exits non-zero when there are no nodes; under `set -e`+pipefail
# that would abort the script before the optional history block below. Tolerate it
# (output is unchanged — determinism preserved).
bash "$SCRIPT_DIR/diagram-facts.sh" --base "$base_ref" --nodes | sort | while IFS= read -r n; do
  [[ -f "$n" ]] || continue
  echo "--- NEIGHBOR: $n ---"
  grep -nE '^[[:space:]]*(def |class |export |function |func |public |private )' "$n" 2>/dev/null | head -40 || true
done || true
if [[ "$with_history" -eq 1 ]]; then
  echo
  echo "=== FULL HISTORY (git log -p base..HEAD) ==="
  git log -p "$base"..HEAD
fi
