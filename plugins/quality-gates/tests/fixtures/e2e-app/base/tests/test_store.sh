#!/usr/bin/env bash
# Store unit test — add · all · empty-name rejection.
set -eu
cd "$(dirname "$0")/.."
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
from store import Store

s = Store()
assert s.add("apple") == 1
assert s.add(" pear ") == 2
assert s.all() == ["apple", "pear"]
try:
    s.add("   ")
except ValueError:
    pass
else:
    raise SystemExit("empty name was accepted")
print("ok")
PY
