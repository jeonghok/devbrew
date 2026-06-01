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

# Safely remove the throwaway repo a sandbox lives in. Guards against an
# ascending `rm -rf` when $SANDBOX is empty/malformed (which would otherwise
# resolve far outside the temp dir). This test-suite is security-sensitive.
cleanup_sandbox() {
  local sb="$1"
  case "$sb" in
    */.claude/quality-gates/worktrees/?*) ;;
    *) echo "  ⚠ cleanup_sandbox: refusing unexpected path '$sb'" >&2; return 0 ;;
  esac
  local repo="${sb%/.claude/quality-gates/worktrees/*}"
  [[ -n "$repo" && "$repo" != "$sb" && -d "$repo" ]] \
    || { echo "  ⚠ cleanup_sandbox: bad repo root for '$sb'" >&2; return 0; }
  case "$repo" in
    /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) rm -rf "$repo" ;;
    *) echo "  ⚠ cleanup_sandbox: repo '$repo' not under a temp dir; skipping rm" >&2 ;;
  esac
}

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
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: clean sandbox -> no downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "clean sandbox -> forced_downgrade: no" || fail "clean misreported: $(field "$G" forced_downgrade)"
cleanup_sandbox "$SANDBOX"

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
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: git-ignored new file -> non-product (no downgrade)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'DB_URL=local\n' > "$SANDBOX/.env"   # ignored — setup-only fix, PASS-able
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "ignored new file -> no downgrade (setup-only PASS path)" || fail "ignored file wrongly downgraded"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: non-ignored new file -> product (downgrade)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const fix = 1\n' > "$SANDBOX/newfix.js"   # NOT ignored -> product
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "non-ignored new file -> forced_downgrade: yes" || fail "new product file not caught"
printf '%s' "$G" | grep -q "newfix.js" \
  && pass "new file in disallowed_new_files" || fail "newfix.js not surfaced"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: new symlink -> product regardless of ignore]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
( cd "$SANDBOX" && ln -s /etc/hosts .env_link )   # name unlikely-ignored; symlink always product
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "new symlink -> forced_downgrade: yes" || fail "new symlink not caught"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: tracked deletion -> forced downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
rm "$SANDBOX/tracked.txt"   # verifier deletes a tracked product file
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "tracked deletion -> forced_downgrade: yes" || fail "deletion not caught"
printf '%s' "$G" | grep -q "tracked.txt" \
  && pass "deleted file surfaced in tracked_diff" || fail "deleted file not surfaced"
cleanup_sandbox "$SANDBOX"

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
cleanup_sandbox "$SANDBOX"

echo "[C-E(a): assume-unchanged hides tracked mutation -> caught by content-hash]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACKED\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" update-index --assume-unchanged tracked.txt
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "assume-unchanged tracked mutation -> forced_downgrade: yes (H-AC2a)" || fail "C-E assume-unchanged EVADED"
cleanup_sandbox "$SANDBOX"

echo "[C-E(b): skip-worktree hides tracked mutation -> caught by content-hash]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACKED\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" update-index --skip-worktree tracked.txt
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "skip-worktree tracked mutation -> forced_downgrade: yes (H-AC2b)" || fail "C-E skip-worktree EVADED"
cleanup_sandbox "$SANDBOX"

echo "[C-A(iv): .gitignore tamper to hide a new file -> caught by content-hash on tracked .gitignore]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'node_modules/\n.env\nsecretfix.js\n' > "$SANDBOX/.gitignore"
printf 'export const x=1\n' > "$SANDBOX/secretfix.js"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass ".gitignore tamper -> forced_downgrade: yes (H-AC3iv)" || fail "C-A .gitignore EVADED"
printf '%s' "$G" | grep -q ".gitignore" \
  && pass ".gitignore change surfaced in tracked_diff" || fail ".gitignore not surfaced"
cleanup_sandbox "$SANDBOX"

echo "[C-B: bad baseline sha -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "bad baseline -> exit 4 (H-AC1)" || fail "bad baseline exit was $RC (expected 4)"
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "bad baseline -> forced_downgrade: yes" || fail "bad baseline not forced"
printf '%s' "$G" | grep -q "guard_error:" \
  && pass "guard_error surfaced" || fail "guard_error missing"
cleanup_sandbox "$SANDBOX"

echo "[NEW-03(a): snapshot missing -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
rm -f "$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "snapshot missing -> exit 4 (H-AC1)" || fail "snapshot-missing exit was $RC"
cleanup_sandbox "$SANDBOX"

echo "[NEW-03(b): snapshot malformed (key removed) -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
grep -v '^stash_sha=' "$SNAP" > "$SNAP.tmp" && mv "$SNAP.tmp" "$SNAP"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "snapshot malformed -> exit 4 (H-AC1)" || fail "snapshot-malformed exit was $RC"
cleanup_sandbox "$SANDBOX"

echo "[I-D: single-quote filename stays valid YAML + forced]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'x\n' > "$SANDBOX/foo'bar.js"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "single-quote new file -> forced_downgrade: yes (H-AC5)" || fail "single-quote file not caught"
if python3 -c "import yaml" 2>/dev/null; then
  printf '%s' "$G" | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin.read())" 2>/dev/null \
    && pass "guard output valid YAML with single-quote filename" || fail "single-quote breaks YAML"
else
  pass "yaml parse check skipped (pyyaml unavailable)"
fi
cleanup_sandbox "$SANDBOX"

echo "[C-A(i): common-dir info/exclude smuggle -> ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
echo 'onlyhack.js' >> "$(git -C "$SANDBOX" rev-parse --git-common-dir)/info/exclude"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "common info/exclude smuggle -> forced (H-AC3i)" || fail "C-A common EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "ignore_channel_tampered flagged" || fail "tamper flag missing"
cleanup_sandbox "$SANDBOX"

echo "[C-A(ii): per-worktree gitdir info/exclude smuggle -> ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
WTDIR="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)"
mkdir -p "$WTDIR/info"; echo 'onlyhack.js' >> "$WTDIR/info/exclude"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "per-worktree info/exclude smuggle -> forced (H-AC3ii)" || fail "C-A per-worktree EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "per-worktree ignore_channel_tampered flagged" || fail "per-worktree tamper flag missing"
cleanup_sandbox "$SANDBOX"

echo "[C-A(iii): core.excludesFile smuggle -> ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
EXC=$(mktemp); echo 'onlyhack.js' > "$EXC"
git -C "$SANDBOX" config core.excludesFile "$EXC"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "core.excludesFile smuggle -> forced (H-AC3iii)" || fail "C-A excludesFile EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "excludesFile ignore_channel_tampered flagged" || fail "excludesFile tamper flag missing"
rm -f "$EXC"; cleanup_sandbox "$SANDBOX"

echo "[C-A(iii-tilde): ~/-relative core.excludesFile smuggle -> ignore_channel_tampered]"
THOME=$(mktemp -d); R=$(mktemp -d)
(cd "$R" && git init -q -b main && git config user.email t@t && git config user.name t)
printf 'orig\n' > "$R/tracked.txt"
printf 'node_modules/\n.env\n' > "$R/.gitignore"
printf '# global ignore\n' > "$THOME/.gitignore_global"
(cd "$R" && git add -A && git commit -q -m init && git config core.excludesFile '~/.gitignore_global')
OUT=$(cd "$R" && HOME="$THOME" "$WT" create-sandbox "tildexcl0123456" 2>/dev/null)
SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const backdoor=1\n' > "$SANDBOX/backdoor.js"   # product file
echo 'backdoor.js' >> "$THOME/.gitignore_global"              # smuggle via global ignore
G=$(HOME="$THOME" "$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "~/-relative excludesFile smuggle -> forced (H-AC3iii tilde)" || fail "C-A excludesFile(~/) EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "~/ excludesFile ignore_channel_tampered flagged" || fail "~/ excludesFile tamper flag missing"
cleanup_sandbox "$SANDBOX"; rm -rf "$THOME"

echo "[C-D-c (NEW-05): persistent logAllRefUpdates=false left set -> reflog_logging_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
git -C "$SANDBOX" config core.logAllRefUpdates false
printf 'orig\nHACK\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" add -A >/dev/null 2>&1
git -C "$SANDBOX" -c user.email=q@q -c user.name=q commit -q -m sneaky
git -C "$SANDBOX" reset --hard "$BASE" >/dev/null 2>&1
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "persistent logAllRefUpdates tamper -> forced (H-AC4c)" || fail "C-D-c EVADED"
printf '%s' "$G" | grep -q "reflog_logging_tampered" \
  && pass "reflog_logging_tampered flagged" || fail "logging-tamper flag missing"
cleanup_sandbox "$SANDBOX"

echo "[C-D-a: stash push reverts tree -> caught by stash snapshot-delta]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACK\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" stash push -u -q
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "stash-revert -> forced (H-AC4a)" || fail "C-D stash EVADED"
printf '%s' "$G" | grep -q "stash_added" \
  && pass "stash_added flagged" || fail "stash flag missing"
cleanup_sandbox "$SANDBOX"

echo "[C-D-b: commit + reset --hard B reverts tree -> caught by reflog snapshot-delta]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACK\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" add -A >/dev/null 2>&1
git -C "$SANDBOX" -c user.email=q@q -c user.name=q commit -q -m sneaky
git -C "$SANDBOX" reset --hard "$BASE" >/dev/null 2>&1
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "commit+reset-revert -> forced (H-AC4b)" || fail "C-D reset EVADED"
printf '%s' "$G" | grep -q "reflog_advanced" \
  && pass "reflog_advanced flagged" || fail "reflog flag missing"
cleanup_sandbox "$SANDBOX"

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
