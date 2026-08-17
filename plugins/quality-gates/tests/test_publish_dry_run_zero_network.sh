#!/usr/bin/env bash
# test_publish_dry_run_zero_network.sh — AC9: --dry-run performs no gh mutation.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/comment-upsert.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

d=$(mktemp -d)
cat > "$d/gh" <<'EOF'
#!/usr/bin/env bash
echo "NETWORK CALL: gh $*" >> "$GH_CALLLOG"
exit 0
EOF
chmod +x "$d/gh"
export GH_CALLLOG="$d/calls.log"; : > "$GH_CALLLOG"
printf '<!-- pr-understanding:v1 -->\nx' > "$d/body"
printf '[]' > "$d/comments.json"

PATH="$d:$PATH" python3 "$SCRIPT" --pr 1 --marker '<!-- pr-understanding:v1 -->' \
  --body-file "$d/body" --my-id 5 --repo o/r --comments-json "$d/comments.json" --dry-run >/dev/null

if [[ ! -s "$GH_CALLLOG" ]]; then ok "no gh mutation under --dry-run"; else no "gh called: $(cat "$GH_CALLLOG")"; fi
rm -rf "$d"
finish
