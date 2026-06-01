#!/usr/bin/env bash
# Unit tests for qg-worktree.sh mutation-guard subcommand (§6.7 / AC7).
# The guard is pure git: its verdict depends ONLY on (sandbox, baseline) —
# never on any verifier self-claim. That is the structural Law 2 defense.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

mk_sandbox() {
  # Build a repo, seal a sandbox via create-sandbox, echo "<sandbox>\n<base>".
  local r; r=$(mktemp -d)
  (cd "$r" && git init -q -b main && git config user.email t@t && git config user.name t)
  printf 'orig\n' > "$r/tracked.txt"
  printf 'node_modules/\n.env\n' > "$r/.gitignore"
  (cd "$r" && git add -A && git commit -q -m init)
  (cd "$r" && "$WT" create-sandbox "guard0123456789" 2>/dev/null)
}

field() { printf '%s\n' "$1" | awk -v k="$2" '$0 ~ "^" k ":" {print; exit}'; }

echo "[create-sandbox: snapshot captured with all 7 keys]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
if [ -f "$SNAP" ]; then
  pass "snapshot file exists at per-worktree gitdir"
else
  fail "snapshot file missing: $SNAP"
fi
miss=0
for k in head_reflog_sha stash_sha excl_common_sha excl_wt_sha excludesfile excludesfile_sha logallrefupdates; do
  grep -q "^$k=" "$SNAP" 2>/dev/null || { miss=$((miss+1)); echo "    missing key: $k"; }
done
[ "$miss" -eq 0 ] && pass "snapshot has all 7 keys" || fail "snapshot missing $miss key(s)"
[ "$(sed -n 's/^logallrefupdates=//p' "$SNAP")" = "true" ] \
  && pass "logAllRefUpdates forced true at baseline" || fail "logAllRefUpdates not true"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: clean sandbox -> no downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "clean sandbox -> forced_downgrade: no" || fail "clean misreported: $(field "$G" forced_downgrade)"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: tracked change -> forced downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACKED TO PASS\n' > "$SANDBOX/tracked.txt"   # product source mutation
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "tracked change -> forced_downgrade: yes" || fail "tracked change not caught"
printf '%s' "$G" | grep -q "tracked.txt" \
  && pass "changed file surfaced in tracked_diff" || fail "tracked.txt not surfaced"

echo "[mutation-guard: independence — verdict ignores any verifier claim]"
# The guard takes only (sandbox, base); there is no input channel for a
# verifier claim. Re-running on the SAME mutated sandbox must still say yes,
# proving the result is git-derived, not passthrough.
G2=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G2" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "independent re-run still forced_downgrade: yes" || fail "non-deterministic guard"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: git-ignored new file -> non-product (no downgrade)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'DB_URL=local\n' > "$SANDBOX/.env"   # ignored — setup-only fix, PASS-able
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "ignored new file -> no downgrade (setup-only PASS path)" || fail "ignored file wrongly downgraded"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: non-ignored new file -> product (downgrade)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const fix = 1\n' > "$SANDBOX/newfix.js"   # NOT ignored -> product
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "non-ignored new file -> forced_downgrade: yes" || fail "new product file not caught"
printf '%s' "$G" | grep -q "newfix.js" \
  && pass "new file in disallowed_new_files" || fail "newfix.js not surfaced"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: new symlink -> product regardless of ignore]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
( cd "$SANDBOX" && ln -s /etc/hosts .env_link )   # name unlikely-ignored; symlink always product
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "new symlink -> forced_downgrade: yes" || fail "new symlink not caught"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: tracked deletion -> forced downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
rm "$SANDBOX/tracked.txt"   # verifier deletes a tracked product file
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "tracked deletion -> forced_downgrade: yes" || fail "deletion not caught"
printf '%s' "$G" | grep -q "tracked.txt" \
  && pass "deleted file surfaced in tracked_diff" || fail "deleted file not surfaced"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: YAML-metachar filename stays parseable (I1)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'x\n' > "$SANDBOX/[id].tsx"   # bracket = YAML flow-seq metachar
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "[id].tsx new file -> forced_downgrade: yes" || fail "bracket file not caught"
if python3 -c "import yaml" 2>/dev/null; then
  if printf '%s' "$G" | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin.read())" 2>/dev/null; then
    pass "guard output is valid YAML with metachar filename"
  else
    fail "guard output not parseable as YAML"
  fi
else
  pass "yaml parse check skipped (pyyaml unavailable)"
fi
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
