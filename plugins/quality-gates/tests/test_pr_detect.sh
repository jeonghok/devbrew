#!/usr/bin/env bash
# test_pr_detect.sh — coverage for scripts/pr-detect.sh (design §11, publish/create branch).
# gh + git are stubbed on PATH; no network, live repo untouched.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/pr-detect.sh"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }
field() { printf '%s\n' "$2" | awk -v k="$1:" '$1==k{print $2}'; }

# mkstub <dir> <gh-behavior> <head_pushed yes|no>
mkstub() {
  local dir="$1" ghmode="$2" pushed="$3"
  cat > "$dir/gh" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "pr" && "\$2" == "view" ]]; then
  case "$ghmode" in
    open)   echo '{"number":123,"url":"https://github.com/o/r/pull/123","state":"OPEN"}';;
    merged) echo '{"number":9,"url":"https://github.com/o/r/pull/9","state":"MERGED"}';;
    none)   exit 1;;
  esac
fi
EOF
  cat > "$dir/git" <<EOF
#!/usr/bin/env bash
case "\$*" in
  "rev-parse --abbrev-ref HEAD") echo feature;;
  "rev-parse HEAD") echo deadbeef;;
  "branch -r --contains deadbeef") [[ "$pushed" == yes ]] && echo "  origin/feature" || true;;
  "ls-remote --exit-code origin") exit 0;;
  *) exit 0;;
esac
EOF
  chmod +x "$dir/gh" "$dir/git"
}

run_case() {
  local ghmode="$1" pushed="$2"
  local d; d=$(mktemp -d); mkstub "$d" "$ghmode" "$pushed"
  PATH="$d:$PATH" bash "$SCRIPT"
  rm -rf "$d"
}

out=$(run_case open yes)
[[ "$(field has_pr "$out")" == yes && "$(field state "$out")" == OPEN \
   && "$(field number "$out")" == 123 && "$(field head_pushed "$out")" == yes ]] \
  && pass "open PR + pushed head" || fail "open (got: $out)"

out=$(run_case merged yes)
[[ "$(field state "$out")" == MERGED ]] && pass "merged PR state surfaced" || fail "merged (got: $out)"

out=$(run_case none no)
[[ "$(field has_pr "$out")" == no && "$(field head_pushed "$out")" == no ]] \
  && pass "no PR + unpushed head" || fail "none (got: $out)"

echo "pr-detect: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
