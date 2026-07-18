#!/usr/bin/env bash
# artifact_max_rounds.sh — effective_max_rounds = clamp(env, 0..10), default 5 (AC18).
# E3 computes this ONCE, puts it in the consent wording, and the loop uses the
# SAME value -> consent scope == execution scope (no env/consent drift).
set -u
v="${DEVBREW_QG_CRITIQUE_MAX_ROUNDS:-5}"
case "$v" in
  ''|*[!0-9]*) v=5 ;;   # empty or non-integer (incl. negative sign) -> default 5
  *)
    # Strip leading zeros: otherwise `010`/`08` pass through raw and the SKILL's
    # downstream arithmetic mis-reads them (octal / "value too great for base"),
    # and an oversized all-digit value OVERFLOWS `[ -gt ]` (which errors past ~19
    # digits and leaves v UNCLAMPED -> the P18 bounded-autonomy cap defeated).
    # After stripping, a value with >=3 digits is necessarily >=100, so clamp to 10
    # WITHOUT any arithmetic on a huge number; <=2 digits is safe to compare.
    v="${v#"${v%%[!0]*}"}"; [ -z "$v" ] && v=0
    if [ "${#v}" -ge 3 ]; then
      v=10
    elif [ "$v" -gt 10 ]; then
      v=10
    fi
    ;;
esac
echo "effective_max_rounds: $v"
