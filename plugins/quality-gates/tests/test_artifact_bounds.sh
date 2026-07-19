#!/usr/bin/env bash
# T6/AC7/AC18 — effective_max_rounds clamp + stagnation predicate (round-1 guard).
set -u
SCRIPTS="$(cd "$(dirname "$0")/../scripts" && pwd)"
MR="$SCRIPTS/artifact_max_rounds.sh"; ST="$SCRIPTS/artifact_stagnation.py"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
no() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }
mr() { bash "$MR" | sed -n 's/^effective_max_rounds: //p'; }
st() { python3 "$ST" --this "$1" --prev "$2" --changed "$3" | sed -n 's/^stagnant: //p'; }

# max_rounds clamp
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS= mr)" = "5" ] && ok "default 5" || no "default should be 5"
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=3 mr)" = "3" ] && ok "env 3 honored" || no "env 3"
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=99 mr)" = "10" ] && ok "clamp >10 to 10" || no "clamp high"
# clamp BOUNDARY (F-K coverage gap): the exact threshold. Mutation proof: changing
# the script's `-gt 10` to `-gt 11` reddens the 11->10 case (99 alone masks it).
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=10 mr)" = "10" ] && ok "boundary 10 -> 10 (at cap)" || no "boundary 10"
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=11 mr)" = "10" ] && ok "boundary 11 -> 10 (just over cap)" || no "boundary 11"
# F-F: integer OVERFLOW must still clamp (a >19-digit value errors `[ -gt ]` and,
# pre-fix, passed through UNCLAMPED -> P18 bound defeated). Length-check clamps it.
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=999999999999999999999999999999 mr)" = "10" ] && ok "overflow (30-digit) clamps to 10" || no "overflow must clamp (F-F)"
# F-F: leading-zero values must be base-10 normalized, not octal/raw passthrough.
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=010 mr)" = "10" ] && ok "leading-zero 010 -> 10 (not octal 8)" || no "010 normalize (F-F)"
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=08 mr)" = "8" ] && ok "leading-zero 08 -> 8 (not invalid-octal error)" || no "08 normalize (F-F)"
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=0 mr)" = "0" ] && ok "0 allowed (floor)" || no "0 floor"
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=abc mr)" = "5" ] && ok "non-integer -> default 5" || no "non-integer default"
[ "$(DEVBREW_QG_CRITIQUE_MAX_ROUNDS=-4 mr)" = "5" ] && ok "negative -> default 5" || no "negative default"

# stagnation (b): changed==false -> stagnant (no-op edit)
[ "$(st "a,b" "c,d" false)" = "true" ] && ok "(b) no-op edit -> stagnant" || no "(b) no-op should stagnate"
# stagnation (a): same key set (non-empty) + changed true -> stagnant
[ "$(st "a,b" "a,b" true)" = "true" ] && ok "(a) stable keyset -> stagnant" || no "(a) stable keyset"
# ROUND-1 GUARD: prev empty, this non-empty, changed true -> NOT stagnant (regression lock)
[ "$(st "a,b" "" true)" = "false" ] && ok "round-1 (empty prev) NOT stagnant" || no "round-1 must not stagnate (round-2 block bug)"
# progressing: different keysets + changed true -> not stagnant
[ "$(st "a" "a,b" true)" = "false" ] && ok "progressing keyset not stagnant" || no "progressing"
# fail-closed: invalid changed signal -> stagnant (stop rather than loop forever)
[ "$(st "a" "b" garbage)" = "true" ] && ok "invalid changed -> fail-closed stagnant" || no "invalid changed fail-closed"

echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
