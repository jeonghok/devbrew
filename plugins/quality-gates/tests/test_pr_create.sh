#!/usr/bin/env bash
# test_pr_create.sh — Fix #4: pr-create.sh is a deterministic create-path guard.
# --dry-run OR DEVBREW_QG_DISABLE_PUBLISH=1 → network suppressed, NO push/create.
# Neither set → git push + gh pr create both fire. Stubs git+gh on PATH into a
# call-log (parity with comment-upsert.py dry-run/kill-switch tests).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/pr-create.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Build a stub dir with git+gh that log every invocation to $CALLLOG.
mk_stubs() {
  STUB=$(mktemp -d) || exit 1
  cat > "$STUB/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >> "$CALLLOG"
exit 0
EOF
  cat > "$STUB/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$CALLLOG"
exit 0
EOF
  chmod +x "$STUB/git" "$STUB/gh"
  # Export so the stub subprocesses (children of pr-create.sh) inherit it.
  export CALLLOG="$STUB/calls.log"; : > "$CALLLOG"
}

# (i) --dry-run → "network suppressed" AND no push / pr create in the call-log.
mk_stubs
out=$(PATH="$STUB:$PATH" bash "$SCRIPT" --dry-run --base main --head feature --body-file /dev/null 2>&1)
if printf '%s' "$out" | grep -q 'network suppressed' \
   && ! grep -q 'push' "$CALLLOG" && ! grep -q 'pr create' "$CALLLOG"; then
  ok "--dry-run: network suppressed, no push/create"
else no "--dry-run (out=$out log=$(cat "$CALLLOG"))"; fi
rm -rf "$STUB"

# (ii) DEVBREW_QG_DISABLE_PUBLISH=1 (no --dry-run) → suppressed, no calls.
mk_stubs
out=$(PATH="$STUB:$PATH" DEVBREW_QG_DISABLE_PUBLISH=1 bash "$SCRIPT" --base main --head feature --body-file /dev/null 2>&1)
if printf '%s' "$out" | grep -q 'network suppressed' \
   && ! grep -q 'push' "$CALLLOG" && ! grep -q 'pr create' "$CALLLOG"; then
  ok "kill switch: network suppressed, no push/create"
else no "kill switch (out=$out log=$(cat "$CALLLOG"))"; fi
rm -rf "$STUB"

# (iii) neither set → call-log HAS push AND pr create.
mk_stubs
out=$(PATH="$STUB:$PATH" bash "$SCRIPT" --base main --head feature --body-file /dev/null 2>&1)
if grep -q 'push' "$CALLLOG" && grep -q 'pr create' "$CALLLOG"; then
  ok "live path: git push + gh pr create both fire"
else no "live path (out=$out log=$(cat "$CALLLOG"))"; fi
rm -rf "$STUB"

# Build a stub dir where git and/or gh FAIL, to prove the sink fails CLOSED:
# never print "action: created" on a failed push/create, and never push when gh
# is unavailable/unauth (teeth against reverting the fail-closed fixes). The gh
# stub is ARG-AWARE: `gh auth status` (the pre-push guard) returns $auth_rc,
# everything else (`gh pr create`) returns $create_rc.
mk_stubs_rc() {  # $1=git_rc  $2=gh_create_rc  $3=gh_auth_rc(default 0)
  local auth_rc="${3:-0}"
  STUB=$(mktemp -d) || exit 1
  printf '#!/usr/bin/env bash\necho "git $*" >> "$CALLLOG"\nexit %s\n' "$1" > "$STUB/git"
  { printf '#!/usr/bin/env bash\necho "gh $*" >> "$CALLLOG"\n'
    printf 'case "$1" in\n  auth) exit %s ;;\n  *) exit %s ;;\nesac\n' "$auth_rc" "$2"
  } > "$STUB/gh"
  chmod +x "$STUB/git" "$STUB/gh"
  export CALLLOG="$STUB/calls.log"; : > "$CALLLOG"
}

# (iv) gh auth OK, git push FAILS → create-failed, NO "action: created", gh pr
# create NOT reached, non-zero exit.
mk_stubs_rc 1 0
out=$(PATH="$STUB:$PATH" bash "$SCRIPT" --base main --head feature --body-file /dev/null 2>&1); rc=$?
if printf '%s' "$out" | grep -q 'create-failed' \
   && ! printf '%s' "$out" | grep -q 'action: created' \
   && [[ "$rc" -ne 0 ]] && ! grep -q 'pr create' "$CALLLOG"; then
  ok "git push failure: create-failed, no 'action: created', gh unreached, non-zero exit"
else no "push-failure (out=$out rc=$rc log=$(cat "$CALLLOG"))"; fi
rm -rf "$STUB"

# (v) gh auth OK, git push OK, gh pr create FAILS → create-failed, push WAS
# reached (distinguishes from the guard firing), no "action: created".
mk_stubs_rc 0 1
out=$(PATH="$STUB:$PATH" bash "$SCRIPT" --base main --head feature --body-file /dev/null 2>&1); rc=$?
if printf '%s' "$out" | grep -q 'create-failed' \
   && ! printf '%s' "$out" | grep -q 'action: created' \
   && [[ "$rc" -ne 0 ]] && grep -q 'push' "$CALLLOG"; then
  ok "gh pr create failure: create-failed, push reached, no 'action: created', non-zero exit"
else no "create-failure (out=$out rc=$rc log=$(cat "$CALLLOG"))"; fi
rm -rf "$STUB"

# (vi) gh present but UNAUTHENTICATED (gh auth status fails) → create-skipped,
# NO push (never leaves an orphan pushed branch), non-zero exit.
mk_stubs_rc 0 0 1
out=$(PATH="$STUB:$PATH" bash "$SCRIPT" --base main --head feature --body-file /dev/null 2>&1); rc=$?
if printf '%s' "$out" | grep -q 'create-skipped' \
   && ! grep -q 'push' "$CALLLOG" \
   && ! grep -q 'pr create' "$CALLLOG" \
   && [[ "$rc" -ne 0 ]]; then
  ok "gh unauth: create-skipped, no push, gh pr create unreached, non-zero exit"
else no "gh-unauth (out=$out rc=$rc log=$(cat "$CALLLOG"))"; fi
rm -rf "$STUB"
finish
