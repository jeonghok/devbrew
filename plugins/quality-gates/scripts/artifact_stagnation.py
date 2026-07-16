#!/usr/bin/env python3
"""artifact_stagnation.py — §8 stagnation predicate (pure, AC7).

stagnant ⟺
  (b) changed == false   (§6 step 6b PRE-COMMIT no-op signal — load-bearing), OR
  (a) this_keys == prev_keys AND this_keys non-empty  (stagnation_key set stable
      across rounds — supplementary heuristic).

The round-1 case (prev empty, this non-empty) is NOT stagnation: (a) requires
set equality, and a non-empty set never equals the empty previous set. This is
the exact regression the round-2 review caught (loop must not terminate at
round 1). Invalid `--changed` -> fail-closed stagnant (stop, never loop forever).
"""
import argparse
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--this", default="")
    ap.add_argument("--prev", default="")
    ap.add_argument("--changed", required=True)
    a = ap.parse_args()

    changed = a.changed.strip().lower()
    if changed not in ("true", "false"):
        print("stagnant: true")
        print("reason: invalid_changed_signal")   # fail-closed
        return 0
    if changed == "false":
        print("stagnant: true")
        print("reason: no_op_edit")                # (b) load-bearing
        return 0

    this_keys = {x for x in a.this.split(",") if x}
    prev_keys = {x for x in a.prev.split(",") if x}
    if this_keys and this_keys == prev_keys:
        print("stagnant: true")
        print("reason: keyset_stable")             # (a) supplementary
        return 0

    print("stagnant: false")
    print("reason: progressing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
