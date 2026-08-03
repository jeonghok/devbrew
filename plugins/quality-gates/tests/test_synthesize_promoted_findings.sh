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

# ── Case 5/6: dedup 좌표 충돌 봉쇄 (Task 13 — codex block #1 재현 후 추가) ──
# 승격 이전에는 (file,line,severity) 충돌이 언제나 "두 리뷰어가 같은 것을 봤다"였고
# 병합이 옳았다. 승격이 생기면서 충돌이 "같은 줄의 *다른* 결함"일 수 있게 됐다.
# 병합되면 (a) 발견 하나가 조용히 사라지고 (b) 살아남은 행의 Source에 adversarial이
# 붙어 하지 않은 주장을 보증한 것처럼 렌더된다 — 소실보다 허위 귀속이 더 나쁘다.

cat > "$tmp/findings_collide.yaml" <<'Y'
- file: plugins/quality-gates/scripts/db.py
  line: 42
  severity: IMPORTANT
  confidence: 8
  summary: "missing null check on user lookup"
  agent: security-reviewer
Y
cat > "$tmp/adv_collide.yaml" <<'Y'
verdicts: []
new_findings:
  - file: plugins/quality-gates/scripts/db.py
    line: 42
    severity: IMPORTANT
    summary: "SQL injection via unparameterised query"
    reason: "user input is interpolated into the query string at line 42."
Y

out5="$(python3 "$SCRIPT" --adversarial "$tmp/adv_collide.yaml" --findings "$tmp/findings_collide.yaml")"

# 5. 같은 좌표·같은 severity에서도 두 발견이 **모두** 렌더된다 (조용한 소실 금지).
if echo "$out5" | grep -q 'missing null check on user lookup' \
  && echo "$out5" | grep -q 'SQL injection via unparameterised query'; then
  ok "5 — 같은 file:line:severity의 기존+승격 발견이 둘 다 렌더된다 (소실 없음)"
else
  no "5 — 같은 file:line:severity의 기존+승격 발견이 둘 다 렌더된다 (소실 없음)"
  echo "$out5" | sed 's/^/      /'
fi

# 6. 기존 리뷰어 행의 Source가 adversarial을 **참칭하지 않는다** (허위 귀속 금지).
#    이 assert는 5와 독립이다 — 병합이 일어나면 5만으로도 잡히지만, 미래에
#    "둘 다 렌더하되 sources를 합치는" 잘못된 수정이 들어오면 6만 잡는다.
row6="$(echo "$out5" | grep 'missing null check on user lookup' || true)"
if [ -n "$row6" ] && ! echo "$row6" | grep -q 'adversarial'; then
  ok "6 — 기존 발견 행의 Source에 adversarial이 참칭되지 않는다 (허위 귀속 없음)"
else
  no "6 — 기존 발견 행의 Source에 adversarial이 참칭되지 않는다 (허위 귀속 없음)"
  echo "    row: $row6" | sed 's/^/      /'
fi

# 7. 리뷰어 간 병합은 **그대로 살아 있다** — 봉쇄가 dedup 자체를 죽이지 않았음을
#    증명한다. 이것이 없으면 "dedup을 통째로 제거"해도 5·6이 통과한다.
cat > "$tmp/findings_agree.yaml" <<'Y'
- file: plugins/quality-gates/scripts/db.py
  line: 99
  severity: IMPORTANT
  confidence: 8
  summary: "unvalidated index"
  agent: security-reviewer
- file: plugins/quality-gates/scripts/db.py
  line: 99
  severity: IMPORTANT
  confidence: 6
  summary: "unvalidated index"
  agent: code-reviewer
Y
cat > "$tmp/adv_none.yaml" <<'Y'
verdicts: []
Y
out7="$(python3 "$SCRIPT" --adversarial "$tmp/adv_none.yaml" --findings "$tmp/findings_agree.yaml")"
# 표 행만 센다 — 'Suggested fixes' 절도 같은 경로를 담으므로 스코프 없이 세면
# 병합이 정상이어도 2가 나온다 (이 락을 쓰다 실제로 밟은 계측기 결함).
rows7="$(echo "$out7" | grep -cE '^\| (CRITICAL|IMPORTANT|SUGGESTION) .*db\.py:99' || true)"
row7="$(echo "$out7" | grep -E '^\| (CRITICAL|IMPORTANT|SUGGESTION) .*db\.py:99' || true)"
if [ "$rows7" -eq 1 ] && echo "$row7" | grep -q 'code-reviewer' && echo "$row7" | grep -q 'security-reviewer'; then
  ok "7 — 리뷰어 간 동일 발견은 여전히 1행으로 병합되고 두 source가 합쳐진다"
else
  no "7 — 리뷰어 간 동일 발견은 여전히 1행으로 병합되고 두 source가 합쳐진다"
  echo "    rows=$rows7  row: $row7" | sed 's/^/      /'
fi

echo ""
echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
