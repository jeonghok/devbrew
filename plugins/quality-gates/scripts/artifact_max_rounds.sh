#!/usr/bin/env bash
# artifact_max_rounds.sh — effective_max_rounds = clamp(env, 0..10), default 5 (AC18).
# E3 computes this ONCE, puts it in the consent wording, and the loop uses the
# SAME value -> consent scope == execution scope (no env/consent drift).
set -u
v="${DEVBREW_QG_CRITIQUE_MAX_ROUNDS:-5}"
case "$v" in
  ''|*[!0-9]*) v=5 ;;   # empty or non-integer (incl. negative sign) -> default 5
esac
if [ "$v" -gt 10 ]; then
  v=10
fi
echo "effective_max_rounds: $v"
