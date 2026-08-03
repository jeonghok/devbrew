#!/usr/bin/env bash
# Task 9 (S3e) — adversarial `new_findings:` promotion into synthesize_findings.py
# output. Persona-independent: feeds fixture YAML straight into the synthesizer,
# never reads agents/adversarial.md. If a run of this file could be made green
# by editing the persona prose alone, the read-side wiring could rot unnoticed
# (see task-9 brief). This file must not `grep`/`cat`/`Read` any *.md persona.
set -u
SCRIPT="plugins/quality-gates/scripts/synthesize_findings.py"
PASS=0; FAIL=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
no() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

# --- fixture: no pre-existing findings, one well-formed IMPORTANT new_finding ---
cat > "$tmp/findings_empty.yaml" <<'Y'
[]
Y
cat > "$tmp/adv_new.yaml" <<'Y'
verdicts: []
new_findings:
  - file: plugins/quality-gates/scripts/foo.py
    line: 42
    severity: IMPORTANT
    summary: "missing null check on parsed config"
    reason: "config.get('x') can return None and is dereferenced unchecked at line 42."
Y

out="$(python3 "$SCRIPT" --adversarial "$tmp/adv_new.yaml" --findings "$tmp/findings_empty.yaml")"
rc=$?

# 1. The promoted finding is present in the rendered table.
if echo "$out" | grep -qE 'foo\.py:42.*missing null check on parsed config'; then
  ok "1 — promoted new_finding row present in output table"
else
  no "1 — promoted new_finding row present in output table"
  echo "$out" | sed 's/^/      /'
fi

# 2. The Source column reads "adversarial" (NOT "?" — catches agent vs source typo).
row="$(echo "$out" | grep -E 'foo\.py:42' || true)"
if echo "$row" | grep -qE '\| *adversarial *\|[[:space:]]*$'; then
  ok "2 — Source column reads 'adversarial' (not '?')"
else
  no "2 — Source column reads 'adversarial' (not '?')"
  echo "    row: $row"
fi

# 3. The row carries the '*' caveat (confidence default 5 <= 6 — unverified by any reviewer).
if echo "$row" | grep -qE '\| *5 \*'; then
  ok "3 — promoted row carries '*' caveat at default confidence 5"
else
  no "3 — promoted row carries '*' caveat at default confidence 5"
  echo "    row: $row"
fi

# 4. A malformed new_finding (missing summary) is dropped silently from stdout,
#    reported on stderr, and does NOT change the exit code (0).
cat > "$tmp/adv_malformed.yaml" <<'Y'
verdicts: []
new_findings:
  - file: plugins/quality-gates/scripts/bar.py
    line: 7
    severity: SUGGESTION
Y
out4="$(python3 "$SCRIPT" --adversarial "$tmp/adv_malformed.yaml" --findings "$tmp/findings_empty.yaml" 2>"$tmp/stderr4.txt")"
rc4=$?
stderr4="$(cat "$tmp/stderr4.txt")"
if ! echo "$out4" | grep -q 'bar\.py:7' \
  && echo "$stderr4" | grep -qi 'dropped malformed' \
  && [ "$rc4" -eq 0 ]; then
  ok "4 — malformed new_finding dropped, reported on stderr, exit code 0"
else
  no "4 — malformed new_finding dropped, reported on stderr, exit code 0"
  echo "    rc4=$rc4"
  echo "    stdout: $out4" | sed 's/^/      /'
  echo "    stderr: $stderr4" | sed 's/^/      /'
fi

echo ""
echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
