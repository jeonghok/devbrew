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
  # Build a repo, seal a sandbox via create-sandbox, echo "<sandbox>\n<base>\n<digest>".
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

echo "[R2-AC1 setup: create-sandbox emits snapshot digest as line 3]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
EXPECT=$(git -C "$SANDBOX" hash-object "$SNAP")
[ -n "$DIGEST" ] && [ "$DIGEST" = "$EXPECT" ] \
  && pass "create-sandbox line 3 == hash-object of snapshot" || fail "line-3 digest absent/mismatch (got '$DIGEST', want '$EXPECT')"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: clean sandbox -> no downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "clean sandbox -> forced_downgrade: no" || fail "clean misreported: $(field "$G" forced_downgrade)"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: tracked change -> forced downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'orig\nHACKED TO PASS\n' > "$SANDBOX/tracked.txt"   # product source mutation
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "tracked change -> forced_downgrade: yes" || fail "tracked change not caught"
printf '%s' "$G" | grep -q "tracked.txt" \
  && pass "changed file surfaced in tracked_diff" || fail "tracked.txt not surfaced"

echo "[mutation-guard: independence — verdict ignores any verifier claim]"
# The guard takes only (sandbox, base); there is no input channel for a
# verifier claim. Re-running on the SAME mutated sandbox must still say yes,
# proving the result is git-derived, not passthrough.
G2=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G2" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "independent re-run still forced_downgrade: yes" || fail "non-deterministic guard"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: git-ignored new file -> non-product (no downgrade)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'DB_URL=local\n' > "$SANDBOX/.env"   # ignored — setup-only fix, PASS-able
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "ignored new file -> no downgrade (setup-only PASS path)" || fail "ignored file wrongly downgraded"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: non-ignored new file -> product (downgrade)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'export const fix = 1\n' > "$SANDBOX/newfix.js"   # NOT ignored -> product
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "non-ignored new file -> forced_downgrade: yes" || fail "new product file not caught"
printf '%s' "$G" | grep -q "newfix.js" \
  && pass "new file in disallowed_new_files" || fail "newfix.js not surfaced"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: non-ignored symlink -> product (Layer 1 add -A)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
( cd "$SANDBOX" && ln -s /etc/hosts .env_link )   # non-ignored name -> staged by Layer-1 add -A (the IGNORED-symlink union path is covered by the I-1 test below)
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "new symlink -> forced_downgrade: yes" || fail "new symlink not caught"
cleanup_sandbox "$SANDBOX"

echo "[I-1: IGNORED symlink -> product (ls-files union path, NUL-safe)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
( cd "$SANDBOX" && ln -s /etc/passwd .env )   # .env IS gitignored -> relies on ls-files union, not Layer-1 add -A
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "ignored symlink -> forced_downgrade: yes (I-1, symlink regardless of ignore)" || fail "ignored symlink EVADED (I-1 bypass)"
printf '%s' "$G" | grep -q "\.env" \
  && pass "ignored symlink surfaced in disallowed_new_files" || fail ".env symlink not surfaced"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: tracked deletion -> forced downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
rm "$SANDBOX/tracked.txt"   # verifier deletes a tracked product file
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "tracked deletion -> forced_downgrade: yes" || fail "deletion not caught"
printf '%s' "$G" | grep -q "tracked.txt" \
  && pass "deleted file surfaced in tracked_diff" || fail "deleted file not surfaced"
cleanup_sandbox "$SANDBOX"

echo "[mutation-guard: YAML-metachar filename stays parseable (I1)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'x\n' > "$SANDBOX/[id].tsx"   # bracket = YAML flow-seq metachar
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
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
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'orig\nHACKED\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" update-index --assume-unchanged tracked.txt
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "assume-unchanged tracked mutation -> forced_downgrade: yes (H-AC2a)" || fail "C-E assume-unchanged EVADED"
cleanup_sandbox "$SANDBOX"

echo "[C-E(b): skip-worktree hides tracked mutation -> caught by content-hash]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'orig\nHACKED\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" update-index --skip-worktree tracked.txt
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "skip-worktree tracked mutation -> forced_downgrade: yes (H-AC2b)" || fail "C-E skip-worktree EVADED"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC3(a): force-tracked ignored file, no mutation -> forced_downgrade: no (I-NEW-2)]"
R=$(mktemp -d)
(cd "$R" && git init -q -b main && git config user.email t@t && git config user.name t)
printf 'orig\n' > "$R/tracked.txt"
printf '*.log\n.env\n' > "$R/.gitignore"
printf 'debug\n' > "$R/debug.log"
(cd "$R" && git add -A && git add -f debug.log && git commit -q -m init)   # debug.log is tracked despite *.log ignore
OUT=$(cd "$R" && "$WT" create-sandbox "inew2guard0123456" 2>/dev/null)
SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "force-tracked ignored, clean -> no downgrade (R2-AC3a)" || fail "I-NEW-2 false-positive: $(field "$G" tracked_diff)"
cleanup_sandbox "$SANDBOX"; rm -rf "$R"   # F4: $R cleaned even if create-sandbox failed (cleanup_sandbox early-returns)

echo "[C-A(iv): .gitignore tamper to hide a new file -> caught by content-hash on tracked .gitignore]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'node_modules/\n.env\nsecretfix.js\n' > "$SANDBOX/.gitignore"
printf 'export const x=1\n' > "$SANDBOX/secretfix.js"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass ".gitignore tamper -> forced_downgrade: yes (H-AC3iv)" || fail "C-A .gitignore EVADED"
printf '%s' "$G" | grep -q ".gitignore" \
  && pass ".gitignore change surfaced in tracked_diff" || fail ".gitignore not surfaced"
cleanup_sandbox "$SANDBOX"

echo "[C-B: bad baseline sha -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "bad baseline -> exit 4 (H-AC1)" || fail "bad baseline exit was $RC (expected 4)"
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "bad baseline -> forced_downgrade: yes" || fail "bad baseline not forced"
printf '%s' "$G" | grep -q "guard_error:" \
  && pass "guard_error surfaced" || fail "guard_error missing"
cleanup_sandbox "$SANDBOX"

echo "[NEW-03(a): snapshot missing -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
rm -f "$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "snapshot missing -> exit 4 (H-AC1)" || fail "snapshot-missing exit was $RC"
cleanup_sandbox "$SANDBOX"

echo "[NEW-03(b): snapshot malformed (key removed) -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
grep -v '^stash_sha=' "$SNAP" > "$SNAP.tmp" && mv "$SNAP.tmp" "$SNAP"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "snapshot malformed -> exit 4 (H-AC1)" || fail "snapshot-malformed exit was $RC"
cleanup_sandbox "$SANDBOX"

echo "[I-D: single-quote filename stays valid YAML + forced]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'x\n' > "$SANDBOX/foo'bar.js"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
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
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
echo 'onlyhack.js' >> "$(git -C "$SANDBOX" rev-parse --git-common-dir)/info/exclude"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "common info/exclude smuggle -> forced (H-AC3i)" || fail "C-A common EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "ignore_channel_tampered flagged" || fail "tamper flag missing"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC4: per-worktree info/exclude RULE-ONLY change (no new file) -> Layer 2 ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
WTDIR="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)"
mkdir -p "$WTDIR/info"; echo 'phantom-rule-no-such-file' >> "$WTDIR/info/exclude"   # rule only; NO file planted
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "per-worktree info/exclude rule-only -> forced (R2-AC4)" || fail "Layer 2 excl_wt_sha path EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "ignore_channel_tampered from Layer 2 (R2-AC4)" || fail "Layer 2 tamper flag missing"
# Layer 1/1b must NOT be the catcher (no new/changed tracked file): disallowed must be empty.
printf '%s' "$G" | grep -q "disallowed_new_files: \[\]" \
  && pass "no file flagged — isolation to Layer 2 confirmed (R2-AC4)" || fail "a file was flagged — not isolated to Layer 2"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC4 mutation-test: disabling Layer 2 excl_wt_sha comparison -> rule-only change EVADEs]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
WTDIR="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)"
mkdir -p "$WTDIR/info"; echo 'phantom-rule-no-such-file' >> "$WTDIR/info/exclude"
# Build a mutant copy of the guard with the per-worktree exclude comparison neutralized
# (force the excl_wt_sha branch to always compare equal). sed targets the now_excl_w line.
MUT=$(mktemp)
sed 's|"\$now_excl_w" != "\$(snap_get excl_wt_sha)"|"x" != "x"|' "$WT" > "$MUT"
chmod +x "$MUT"
GM=$(/bin/bash "$MUT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$GM" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "mutant (Layer 2 excl_wt disabled) -> EVADE: forced_downgrade: no (R2-AC4 mutation)" \
  || fail "mutant did NOT evade — the green is not actually traversing Layer 2"
rm -f "$MUT"
cleanup_sandbox "$SANDBOX"

echo "[C-A(iii): core.excludesFile smuggle -> ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
EXC=$(mktemp); echo 'onlyhack.js' > "$EXC"
git -C "$SANDBOX" config core.excludesFile "$EXC"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
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
SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'export const backdoor=1\n' > "$SANDBOX/backdoor.js"   # product file
echo 'backdoor.js' >> "$THOME/.gitignore_global"              # smuggle via global ignore
G=$(HOME="$THOME" "$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "~/-relative excludesFile smuggle -> forced (H-AC3iii tilde)" || fail "C-A excludesFile(~/) EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "~/ excludesFile ignore_channel_tampered flagged" || fail "~/ excludesFile tamper flag missing"
cleanup_sandbox "$SANDBOX"; rm -rf "$THOME"

echo "[C-D-c (NEW-05): persistent logAllRefUpdates=false left set -> reflog_logging_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
git -C "$SANDBOX" config core.logAllRefUpdates false
printf 'orig\nHACK\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" add -A >/dev/null 2>&1
git -C "$SANDBOX" -c user.email=q@q -c user.name=q commit -q -m sneaky
git -C "$SANDBOX" reset --hard "$BASE" >/dev/null 2>&1
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "persistent logAllRefUpdates tamper -> forced (H-AC4c)" || fail "C-D-c EVADED"
printf '%s' "$G" | grep -q "reflog_logging_tampered" \
  && pass "reflog_logging_tampered flagged" || fail "logging-tamper flag missing"
cleanup_sandbox "$SANDBOX"

echo "[C-D-a: stash push reverts tree -> caught by stash snapshot-delta]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'orig\nHACK\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" stash push -u -q
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "stash-revert -> forced (H-AC4a)" || fail "C-D stash EVADED"
printf '%s' "$G" | grep -q "stash_added" \
  && pass "stash_added flagged" || fail "stash flag missing"
cleanup_sandbox "$SANDBOX"

echo "[C-D-b: commit + reset --hard B reverts tree -> caught by reflog snapshot-delta]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'orig\nHACK\n' > "$SANDBOX/tracked.txt"
git -C "$SANDBOX" add -A >/dev/null 2>&1
git -C "$SANDBOX" -c user.email=q@q -c user.name=q commit -q -m sneaky
git -C "$SANDBOX" reset --hard "$BASE" >/dev/null 2>&1
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "commit+reset-revert -> forced (H-AC4b)" || fail "C-D reset EVADED"
printf '%s' "$G" | grep -q "reflog_advanced" \
  && pass "reflog_advanced flagged" || fail "reflog flag missing"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC1(b): no-forge variant — info/exclude changed, snapshot intact -> Layer 2 ignore_channel_tampered]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
echo 'onlyhack.js' >> "$COMMON/info/exclude"     # change ignore, DO NOT touch the snapshot
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -ne 4 ] && pass "no-forge: digest valid, guard does not fail-closed (R2-AC1b)" || fail "no-forge wrongly exit 4"
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "no-forge -> forced_downgrade: yes (Layer 2) (R2-AC1b)" || fail "no-forge not caught"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "ignore_channel_tampered flagged (R2-AC1b)" || fail "Layer 2 tamper flag missing"
cleanup_sandbox "$SANDBOX"

echo "[b-precise crash-recovery (§6.2 step-1a): leftover .qgbak -> Layer-0 pre-restore, no false tamper]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
cp "$COMMON/info/exclude" "$COMMON/info/exclude.orig"   # remember original for the byte-identical assert
mv "$COMMON/info/exclude" "$COMMON/info/exclude.qgbak"  # simulate crash: original parked in .qgbak
: > "$COMMON/info/exclude"                              # ...live file left emptied
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "crash .qgbak -> pre-restore recovers, forced=no" || fail "pre-restore failed: $(field "$G" guard_flags)"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && fail "false ignore_channel_tampered after pre-restore" || pass "no false tamper after pre-restore"
[ ! -f "$COMMON/info/exclude.qgbak" ] \
  && pass ".qgbak consumed by pre-restore" || fail ".qgbak not consumed"
cmp -s "$COMMON/info/exclude" "$COMMON/info/exclude.orig" \
  && pass "common info/exclude restored byte-identical" || fail "info/exclude not restored to original"
rm -f "$COMMON/info/exclude.orig"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC1(d): clean sandbox + correct digest + no tamper -> forced_downgrade: no]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "clean + correct digest -> no downgrade (R2-AC1d)" || fail "clean+digest misreported"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC1(e): honest tracked mutation + correct digest -> forced_downgrade: yes (digest does NOT short-circuit Layer 1)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
printf 'orig\nHACKED TO PASS\n' > "$SANDBOX/tracked.txt"
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "honest mutation + correct digest -> forced (R2-AC1e)" || fail "Layer 1 short-circuited by digest pass"
printf '%s' "$G" | grep -q "tracked.txt" \
  && pass "tracked.txt surfaced (R2-AC1e)" || fail "tracked.txt not surfaced"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC1(a): master-key exploit — forged snapshot + original digest -> guard_fail exit 4]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
printf 'BACKDOOR()\n' > "$SANDBOX/onlyhack.js"                 # new product file
echo 'onlyhack.js' >> "$COMMON/info/exclude"                   # evade Layer 1 (add -A honors common exclude)
NEWH=$(git -C "$SANDBOX" hash-object "$COMMON/info/exclude")
sed "s|^excl_common_sha=.*|excl_common_sha=$NEWH|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"   # forge Layer 2 ref
# orchestrator still holds the ORIGINAL (pre-forge) digest captured at create time:
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "forged snapshot + orig digest -> exit 4 (R2-AC1a)" || fail "master-key exit was $RC (expected 4)"
printf '%s' "$G" | grep -qi "digest" \
  && pass "guard_error cites digest mismatch (R2-AC1a)" || fail "no digest-mismatch reason surfaced"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC1(c): empty digest -> guard_fail exit 4; omitted (2-arg) -> die exit 2]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] && pass "empty digest -> exit 4 (R2-AC1c)" || fail "empty-digest exit was $RC (expected 4)"
"$WT" mutation-guard "$SANDBOX" "$BASE" >/dev/null 2>&1; RC2=$?
[ "$RC2" -ne 0 ] && pass "2-arg call rejected (exit $RC2, never PASS) (R2-AC1c)" || fail "2-arg call was not rejected"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC2(i): common info/exclude-hidden new file, Layer 2 forged-off -> Layer 1b sole catch]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
echo 'onlyhack.js' >> "$COMMON/info/exclude"
NEWH=$(git -C "$SANDBOX" hash-object "$COMMON/info/exclude")
sed "s|^excl_common_sha=.*|excl_common_sha=$NEWH|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"
DIGEST=$(git -C "$SANDBOX" hash-object "$SNAP")     # digest of the patched snapshot -> Layer 0 passes
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "common-hidden file -> forced (Layer 1b sole, R2-AC2i)" || fail "b-precise common EVADED"
printf '%s' "$G" | grep -q "onlyhack.js" \
  && pass "onlyhack.js in disallowed_new_files (R2-AC2i)" || fail "onlyhack.js not surfaced"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && fail "Layer 2 fired — de-vacuum NOT isolated (R2-AC2i)" || pass "Layer 2 silent — de-vacuum isolation holds (R2-AC2i)"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC2(iii): core.excludesFile-hidden new file, Layer 2 forged-off -> Layer 1b sole catch]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
REPO="${SANDBOX%/.claude/quality-gates/worktrees/*}"
EXC="$REPO/.qg_excludes"; echo 'onlyhack.js' > "$EXC"          # throwaway-internal path (N-4: no host ~/.gitconfig)
git -C "$SANDBOX" config --local core.excludesFile "$EXC"
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
EFH=$(git -C "$SANDBOX" hash-object "$EXC")
sed "s|^excludesfile=.*|excludesfile=$EXC|; s|^excludesfile_sha=.*|excludesfile_sha=$EFH|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"
DIGEST=$(git -C "$SANDBOX" hash-object "$SNAP")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "excludesFile-hidden file -> forced (Layer 1b sole, R2-AC2iii)" || fail "b-precise excludesFile EVADED"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && fail "Layer 2 fired — de-vacuum NOT isolated (R2-AC2iii)" || pass "Layer 2 silent (R2-AC2iii)"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC2(ii): per-worktree info/exclude-hidden new file, Layer 2 forged-off -> caught (Layer 1 structural)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
WTDIR="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)"
printf 'export const fix=1\n' > "$SANDBOX/onlyhack.js"
mkdir -p "$WTDIR/info"; echo 'onlyhack.js' >> "$WTDIR/info/exclude"
NEWW=$(git -C "$SANDBOX" hash-object "$WTDIR/info/exclude")
sed "s|^excl_wt_sha=.*|excl_wt_sha=$NEWW|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"
DIGEST=$(git -C "$SANDBOX" hash-object "$SNAP")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
# add -A ignores per-worktree info/exclude in a linked worktree, so Layer 1 stages
# the file; b-precise neutralizes it too. Either way it is caught WITHOUT Layer 2.
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "per-worktree-hidden file -> forced w/o Layer 2 (R2-AC2ii)" || fail "per-worktree file EVADED"
printf '%s' "$G" | grep -q "onlyhack.js" \
  && pass "onlyhack.js surfaced (R2-AC2ii)" || fail "onlyhack.js not surfaced"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC2(iv): baseline .gitignore-matched new file -> no downgrade (usability)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
mkdir -p "$SANDBOX/node_modules"; printf 'x\n' > "$SANDBOX/node_modules/x.js"   # baseline .gitignore has node_modules/
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "baseline-ignored runtime artifact -> no downgrade (R2-AC2iv)" || fail "node_modules false-FAILed"
cleanup_sandbox "$SANDBOX"

echo "[R2-AC2(v): info/exclude-hidden new symlink -> forced (symlink coverage union)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
SNAP="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)/qg-mutation-snapshot"
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
( cd "$SANDBOX" && ln -s /etc/hosts hacklink )
echo 'hacklink' >> "$COMMON/info/exclude"
NEWH=$(git -C "$SANDBOX" hash-object "$COMMON/info/exclude")
sed "s|^excl_common_sha=.*|excl_common_sha=$NEWH|" "$SNAP" > "$SNAP.t" && mv "$SNAP.t" "$SNAP"
DIGEST=$(git -C "$SANDBOX" hash-object "$SNAP")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "info/exclude-hidden symlink -> forced (R2-AC2v)" || fail "b-precise symlink EVADED"
cleanup_sandbox "$SANDBOX"

echo "[R3-AC1(a): verifier-planted .qgbak DIRECTORY -> fail-closed exit 4, main-repo info/exclude uncorrupted (F1/codex-2)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
cp "$COMMON/info/exclude" "$COMMON/info/exclude.orig"      # remember original for the corruption assert
mkdir -p "$COMMON/info/exclude.qgbak"                      # verifier plants a DIRECTORY at the predictable backup path
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] \
  && pass "planted .qgbak directory -> fail-closed exit 4 (R3-AC1a)" || fail "planted .qgbak dir not fail-closed (exit $RC)"
cmp -s "$COMMON/info/exclude" "$COMMON/info/exclude.orig" \
  && pass "common info/exclude uncorrupted by .qgbak dir-plant (R3-AC1a)" || fail "main-repo info/exclude CORRUPTED by .qgbak dir-plant"
rm -rf "$COMMON/info/exclude.qgbak" "$COMMON/info/exclude.orig"
cleanup_sandbox "$SANDBOX"

echo "[R3-AC1(b): verifier-planted regular .qgbak (non-matching) -> NOT restored, original preserved, clean (F1 pre-restore-trust)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
cp "$COMMON/info/exclude" "$COMMON/info/exclude.orig"
printf 'ATTACKER-CONTROLLED-EXCLUDE\n' > "$COMMON/info/exclude.qgbak"   # plant a regular .qgbak the guard did NOT create
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "non-matching .qgbak plant ignored -> clean (R3-AC1b)" || fail "regular .qgbak plant altered verdict ($(field "$G" forced_downgrade))"
cmp -s "$COMMON/info/exclude" "$COMMON/info/exclude.orig" \
  && pass "original info/exclude preserved (not overwritten by .qgbak content) (R3-AC1b)" || fail "main-repo info/exclude DESTROYED by .qgbak content plant"
rm -f "$COMMON/info/exclude.qgbak" "$COMMON/info/exclude.orig"
cleanup_sandbox "$SANDBOX"

echo "[R3-AC2 mutation: b-precise neutralized-diff failure -> fail-closed exit 4 (codex-1 exit-check)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
MUT=$(mktemp)
# Inject a failure into the Layer-1b neutralized diff; the exit-check must fail closed.
sed 's|diff --name-status --diff-filter=A "\$base_tree" "\$cur_tree_neutralized"|diff --name-status --bogus-flag-zzz|' "$WT" > "$MUT"
chmod +x "$MUT"
GM=$(/bin/bash "$MUT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] \
  && pass "b-precise neutralized-diff failure -> fail-closed exit 4 (R3-AC2/codex-1)" || fail "b-precise diff failure NOT fail-closed (exit $RC)"
rm -f "$MUT"
cleanup_sandbox "$SANDBOX"

echo "[R3-AC1(c): verifier plants LIVE info/exclude as DIRECTORY (+matching .qgbak) -> fail-closed, no mv-into-dir (codex-3)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
cp "$COMMON/info/exclude" "$COMMON/info/exclude.qgbak"   # .qgbak = authentic original (matches sealed excl_common_sha)
rm -f "$COMMON/info/exclude"; mkdir "$COMMON/info/exclude"   # verifier plants the LIVE target as a directory
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] \
  && pass "live info/exclude dir-plant -> fail-closed exit 4 (R3-AC1c)" || fail "live dir-plant not fail-closed (exit $RC)"
{ [ -f "$COMMON/info/exclude.qgbak" ] && [ ! -e "$COMMON/info/exclude/exclude.qgbak" ]; } \
  && pass ".qgbak NOT moved into the planted dir (R3-AC1c)" || fail ".qgbak moved into live dir (corruption)"
rm -rf "$COMMON/info/exclude" "$COMMON/info/exclude.qgbak"
cleanup_sandbox "$SANDBOX"

echo "[R3-AC2(b) mutation: hash-object failure on existing regular .qgbak -> fail-closed (codex-4)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
: > "$COMMON/info/exclude"                            # crash-placeholder (empty live) so pre-restore reaches the hash check
printf 'whatever\n' > "$COMMON/info/exclude.qgbak"   # a regular .qgbak the hash-object line then evaluates
MUT=$(mktemp)
sed 's|git -C "\$sandbox" hash-object "\$f.qgbak"|git -C "$sandbox" hash-object --bogus-flag-zzz|' "$WT" > "$MUT"
chmod +x "$MUT"
GM=$(/bin/bash "$MUT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); RC=$?
[ "$RC" -eq 4 ] \
  && pass "hash-object failure on regular .qgbak -> fail-closed exit 4 (R3-AC2b/codex-4)" || fail "hash-failure not fail-closed (exit $RC)"
rm -f "$MUT" "$COMMON/info/exclude.qgbak"
cleanup_sandbox "$SANDBOX"

echo "[R3-AC1(d): planted .qgbak for ABSENT per-worktree info/exclude -> NOT installed by restore_excludes (codex-5)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
WTDIR="$(git -C "$SANDBOX" rev-parse --absolute-git-dir)"
mkdir -p "$WTDIR/info"; rm -f "$WTDIR/info/exclude"                  # ensure live per-worktree exclude is ABSENT
printf 'ATTACKER-IGNORE-RULES\n' > "$WTDIR/info/exclude.qgbak"       # plant a backup the guard did NOT create
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
{ [ ! -f "$WTDIR/info/exclude" ] || ! grep -q 'ATTACKER-IGNORE-RULES' "$WTDIR/info/exclude"; } \
  && pass "planted .qgbak NOT installed as live per-worktree info/exclude (R3-AC1d)" || fail "restore_excludes installed verifier-planted .qgbak (codex-5)"
rm -f "$WTDIR/info/exclude.qgbak"
cleanup_sandbox "$SANDBOX"

echo "[R3-AC1(e): info/exclude tamper + matching-original .qgbak -> tamper NOT erased by pre-restore (codex-6)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT"); DIGEST=$(sed -n '3p' <<<"$OUT")
COMMON="$(git -C "$SANDBOX" rev-parse --git-common-dir)"
cp "$COMMON/info/exclude" "$COMMON/info/exclude.qgbak"        # .qgbak = authentic original (matches sealed excl_common_sha)
echo 'phantom-rule-no-such-file' >> "$COMMON/info/exclude"   # rule-only tamper: live now NON-EMPTY and != original
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "tamper + matching .qgbak -> still forced (pre-restore did NOT erase the tamper) (R3-AC1e)" || fail "matching .qgbak erased tamper signal -> false clean (codex-6 bypass)"
printf '%s' "$G" | grep -q "ignore_channel_tampered" \
  && pass "ignore_channel_tampered preserved despite matching .qgbak (R3-AC1e)" || fail "ignore_channel_tampered suppressed by pre-restore overwrite (codex-6)"
rm -f "$COMMON/info/exclude.qgbak"
cleanup_sandbox "$SANDBOX"

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
