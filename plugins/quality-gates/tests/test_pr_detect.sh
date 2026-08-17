#!/usr/bin/env bash
# test_pr_detect.sh — coverage for scripts/pr-detect.sh (design §11, publish/create branch).
# gh + git are stubbed on PATH; no network, live repo untouched.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/pr-detect.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# mkstub <dir> <gh-behavior> <head_pushed yes|no>
mkstub() {
  local dir="$1" ghmode="$2" pushed="$3"
  cat > "$dir/gh" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "pr" && "\$2" == "view" ]]; then
  case "$ghmode" in
    open)   printf '123\thttps://github.com/o/r/pull/123\tOPEN\n';;
    merged) printf '9\thttps://github.com/o/r/pull/9\tMERGED\n';;
    none)   exit 1;;
  esac
fi
EOF
  cat > "$dir/git" <<EOF
#!/usr/bin/env bash
case "\$*" in
  "rev-parse --abbrev-ref HEAD") echo feature;;
  "rev-parse HEAD") echo deadbeef;;
  "rev-parse -q --verify refs/remotes/origin/feature") [[ "$pushed" == yes ]] && exit 0 || exit 1;;
  "merge-base --is-ancestor deadbeef refs/remotes/origin/feature") [[ "$pushed" == yes ]] && exit 0 || exit 1;;
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
   && "$(field number "$out")" == 123 && "$(field head_pushed "$out")" == yes \
   && "$(field url "$out")" == "https://github.com/o/r/pull/123" ]] \
  && ok "open PR + pushed head" || no "open (got: $out)"

out=$(run_case merged yes)
[[ "$(field state "$out")" == MERGED ]] && ok "merged PR state surfaced" || no "merged (got: $out)"

out=$(run_case none no)
[[ "$(field has_pr "$out")" == no && "$(field head_pushed "$out")" == no ]] \
  && ok "no PR + unpushed head" || no "none (got: $out)"

case_head_pushed_scoped_real_git() {
  # REAL git (no stub): a branch cut from origin/main whose HEAD is reachable via
  # origin/main but was never pushed as origin/feature must report head_pushed: no.
  local REPO UP
  UP=$(mktemp -d); ( cd "$UP" && git init -q --bare )
  REPO=$(mktemp -d); cd "$REPO"
  git init -q; git config user.email t@t.test; git config user.name tester
  git remote add origin "$UP"
  git checkout -q -b main; echo a > a.txt; git add -A; git commit -qm a; git push -q origin main
  git checkout -q -b feature   # HEAD == main tip: reachable via origin/main, NOT pushed as origin/feature
  local out; out=$(bash "$SCRIPT" 2>/dev/null)   # gh (real/absent) → has_pr: no; we assert head_pushed only
  if printf '%s' "$out" | grep -q 'head_pushed: no'; then
    ok "head_pushed scoped to origin/<branch> (reachable-elsewhere != pushed)"
  else
    no "head_pushed false-positive on fresh branch (got: $out)"
  fi
  cd / && rm -rf "$REPO" "$UP"
}

case_gh_literally_absent() {
  # gh not on PATH at all → has_pr: no, no crash.
  local d; d=$(mktemp -d)
  cat > "$d/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "rev-parse --abbrev-ref HEAD") echo feature;;
  "rev-parse HEAD") echo deadbeef;;
  *) exit 1;;
esac
EOF
  chmod +x "$d/git"
  local out; out=$(PATH="$d:/usr/bin:/bin" bash "$SCRIPT" 2>/dev/null)
  if printf '%s' "$out" | grep -q 'has_pr: no'; then
    ok "gh literally absent → has_pr: no (no crash)"
  else
    no "gh-absent (got: $out)"
  fi
  rm -rf "$d"
}

case_head_pushed_scoped_real_git
case_gh_literally_absent
finish
