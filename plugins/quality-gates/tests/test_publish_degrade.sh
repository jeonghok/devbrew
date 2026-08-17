#!/usr/bin/env bash
# test_publish_degrade.sh — AC14: gh-absent / fork-403 → artifact-only degrade,
# no retry loop. Verified at the SKILL-prose level (degrade section) + pr-detect
# tolerating gh absence at runtime.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/publishing-pr-understanding/SKILL.md"
DETECT="$PLUGIN_ROOT/scripts/pr-detect.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# SKILL documents artifact-only degrade + no retry loop.
awk '/## Degrade/{f=1} f' "$SKILL" | grep -qiE 'artifact-only' \
  && ok "degrade section: artifact-only" || no "no artifact-only degrade"
awk '/## Degrade/{f=1} f' "$SKILL" | grep -qiE 'no retry|재시도.*없|retry loop' \
  && ok "degrade section: no retry loop" || no "retry-loop prohibition missing"

# pr-detect tolerates gh absence (emits has_pr: no, does not crash).
d=$(mktemp -d)
cat > "$d/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "rev-parse --abbrev-ref HEAD") echo feature;;
  "rev-parse HEAD") echo deadbeef;;
  *) exit 0;;
esac
EOF
chmod +x "$d/git"
# PATH with git stub but NO gh
out=$(PATH="$d:/usr/bin:/bin" bash "$DETECT" 2>/dev/null)
if printf '%s' "$out" | grep -q 'has_pr: no'; then ok "pr-detect degrades when gh absent"; else no "pr-detect crashed/misreported (got: $out)"; fi
rm -rf "$d"
finish
