#!/usr/bin/env bash
# Task 9 (S3e) — adversarial `new_findings:` promotion into synthesize_findings.py
# output. Persona-independent: feeds fixture YAML straight into the synthesizer,
# never reads agents/adversarial.md. If a run of this file could be made green
# by editing the persona prose alone, the read-side wiring could rot unnoticed
# (see task-9 brief). This file must not `grep`/`cat`/`Read` any *.md persona.
set -u
SCRIPT="plugins/quality-gates/scripts/synthesize_findings.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT


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

# ── 8·9·10: 값이 malformed일 때의 계약 (2026-08-04 /qg 라운드 1) ──────────────
# 셋 다 "어떤 리뷰어의 잘못된 한 필드가 리뷰 전체의 진실성을 무너뜨리지 않는다"를
# 잰다. 승격 경로 전용이 아니다 — 크래시 지점은 정렬·억제·표시 어디에나 있었고,
# 소비자별로 막으면 새 소비자에서 다시 터진다.

# 8 — 어느 리뷰어든 비수치 confidence가 합성을 죽이지 않는다.
#     예전: dedup/suppress/sort/render의 맨 int()가 ValueError → exit 1 + stdout 공백.
#     같이 죽는 것에 다른 리뷰어의 진짜 CRITICAL이 포함된다는 점이 이 케이스의 핵심이라
#     픽스처에 진짜 CRITICAL을 함께 넣는다.
cat > "$tmp/findings_badconf.yaml" <<'Y'
findings:
  - file: src/auth.py
    line: 42
    severity: CRITICAL
    confidence: 9
    summary: "real SQL injection"
    agent: security-reviewer
  - file: src/util.py
    line: 7
    severity: IMPORTANT
    confidence: high
    summary: "malformed confidence"
    agent: code-reviewer
Y
if out8="$(python3 "$SCRIPT" --findings "$tmp/findings_badconf.yaml" 2>/dev/null)" \
   && echo "$out8" | grep -q 'real SQL injection'; then
  ok "8 — 비수치 confidence가 있어도 exit 0이고 다른 리뷰어의 CRITICAL이 살아남는다"
else
  no "8 — 비수치 confidence가 있어도 exit 0이고 다른 리뷰어의 CRITICAL이 살아남는다"
fi

# 9 — severity 표기 차이가 CRITICAL을 강등시키지 않는다.
#     예전: 멤버십 검사가 정확 일치라 `Critical`이 SUGGESTION으로 렌더됐고,
#     SKILL은 counts line으로 경계를 판정하므로 판정 자체가 틀렸다.
cat > "$tmp/findings_sevcase.yaml" <<'Y'
findings:
  - file: src/auth.py
    line: 42
    severity: Critical
    confidence: 9
    summary: "casing must not demote"
    agent: security-reviewer
Y
if python3 "$SCRIPT" --findings "$tmp/findings_sevcase.yaml" 2>/dev/null \
     | grep -q '^\*\*Findings:\*\* 1 CRITICAL'; then
  ok "9 — severity 표기 차이가 counts line에서 강등되지 않는다"
else
  no "9 — severity 표기 차이가 counts line에서 강등되지 않는다"
fi

# 10 — 승격 발견이 전부 malformed일 때 stdout이 clean으로 읽히면 안 된다.
#      예전: render()가 findings 비면 먼저 return해 drop 공지가 도달 불가였고,
#      SKILL은 stdout만 읽어 counts=0 → `## Review gate: clean`을 찍었다.
#      stderr에만 있는 공지는 이 경로에서 없는 것과 같다.
cat > "$tmp/adv_all_malformed.yaml" <<'Y'
verdicts: []
new_findings:
  - severity: CRITICAL
    summary: "auth bypass — no file key"
  - file: x.py
    summary: "no severity key"
Y
out10="$(python3 "$SCRIPT" --adversarial "$tmp/adv_all_malformed.yaml" --findings "$tmp/findings_empty.yaml" 2>/dev/null)"
if echo "$out10" | grep -qE '^2 finding\(s\) dropped as malformed' \
   && echo "$out10" | grep -q '이 실행은 clean이 아니다'; then
  ok "10 — 전부 malformed일 때 소실이 stdout에 드러난다 (clean으로 읽히지 않는다)"
else
  no "10 — 전부 malformed일 때 소실이 stdout에 드러난다 (clean으로 읽히지 않는다)"
  echo "$out10" | sed 's/^/      /'
fi

# 10b — 같은 공지가 **primary 리뷰어** 출처의 소실에도 나가야 한다.
#       케이스 10은 adversarial 승격 경로만 쟀다. apply_verdicts()는 non-mapping
#       finding을 카운터도 stderr도 없이 버렸고, 리뷰어가 발견을 문자열로 내면
#       (LLM 출력에서 흔하다) CRITICAL 주장이 통째로 증발한 뒤 stdout은
#       `No high-confidence findings.` + exit 0 — **버려진 CRITICAL이 clean으로
#       렌더**됐다 (2026-08-05 /qg 라운드 2 적발). 한쪽 출처만 세는 drop 채널은
#       "이 실행은 clean이 아니다"를 말할 자격이 없다.
cat > "$tmp/findings_str.yaml" <<'Y'
findings:
  - "CRITICAL: hardcoded AWS key in src/config.py:11"
  - "CRITICAL: auth bypass in src/auth.py:44"
Y
out10b="$(python3 "$SCRIPT" --findings "$tmp/findings_str.yaml" 2>/dev/null)"
if echo "$out10b" | grep -qE '^2 finding\(s\) dropped as malformed' \
   && echo "$out10b" | grep -q '이 실행은 clean이 아니다'; then
  ok "10b — primary 리뷰어 출처의 소실도 같은 채널로 stdout에 드러난다"
else
  no "10b — primary 리뷰어 출처의 소실도 같은 채널로 stdout에 드러난다"
  echo "$out10b" | sed 's/^/      /'
fi

# 10c — 컨테이너 자체가 malformed여도 파이프라인이 죽지 않는다.
#       `_conf()`가 항목의 *필드*를 막은 뒤에도 컨테이너 *타입*은 열려 있었다:
#       `new_findings: 5` → `for item in 5` → TypeError → exit 1 + stdout 공백.
#       같이 죽는 것에 다른 리뷰어의 진짜 CRITICAL이 포함된다.
cat > "$tmp/adv_scalar.yaml" <<'Y'
verdicts: []
new_findings: 5
Y
cat > "$tmp/findings_one_crit.yaml" <<'Y'
findings:
  - {file: a.py, line: 1, severity: CRITICAL, summary: real bug, confidence: 9, agent: security-reviewer}
Y
out10c="$(python3 "$SCRIPT" --adversarial "$tmp/adv_scalar.yaml" --findings "$tmp/findings_one_crit.yaml" 2>/dev/null)"
rc10c=$?
if [ "$rc10c" -eq 0 ] && echo "$out10c" | grep -q '1 CRITICAL'; then
  ok "10c — 비-리스트 new_findings가 다른 리뷰어의 CRITICAL을 죽이지 않는다"
else
  no "10c — 비-리스트 new_findings가 다른 리뷰어의 CRITICAL을 죽이지 않는다 (rc=$rc10c)"
  echo "$out10c" | sed 's/^/      /'
fi

# 10d — severity가 비-스칼라여도 죽지 않는다(`_norm_sev`의 멤버십 검사가 unhashable).
cat > "$tmp/findings_listsev.yaml" <<'Y'
findings:
  - {file: a.py, line: 1, severity: [CRITICAL], summary: s, confidence: 9, agent: sec}
Y
out10d="$(python3 "$SCRIPT" --findings "$tmp/findings_listsev.yaml" 2>/dev/null)"
rc10d=$?
if [ "$rc10d" -eq 0 ] && echo "$out10d" | grep -q '\*\*Findings:\*\*'; then
  ok "10d — 비-스칼라 severity가 합성을 죽이지 않는다"
else
  no "10d — 비-스칼라 severity가 합성을 죽이지 않는다 (rc=$rc10d)"
  echo "$out10d" | sed 's/^/      /'
fi

# 10e — 승격 발견이 다른 리뷰어의 보증을 **참칭할 수 없다**.
#       `f = dict(item)`이 리뷰어가 준 `sources`를 그대로 복사했고, 승격 항목은
#       dedup()의 그룹핑을 건너뛰므로(passthrough) 병합이 덮어쓸 기회도 없었다.
#       결과: 아무 리뷰어도 하지 않은 주장이 `Source: security-reviewer, code-reviewer`로
#       렌더됐다. `agent` 강제만으로는 id 참칭만 막고 표시 계층은 열려 있었다.
cat > "$tmp/adv_forged_sources.yaml" <<'Y'
verdicts: []
new_findings:
  - file: evil.py
    line: 1
    severity: CRITICAL
    summary: "아무 리뷰어도 하지 않은 주장"
    confidence: 9
    sources: [security-reviewer, code-reviewer]
Y
out10e="$(python3 "$SCRIPT" --adversarial "$tmp/adv_forged_sources.yaml" --findings "$tmp/findings_empty.yaml" 2>/dev/null)"
row10e="$(echo "$out10e" | grep 'evil.py' | head -1)"
if echo "$row10e" | grep -q '| adversarial |' \
   && ! echo "$row10e" | grep -q 'security-reviewer'; then
  ok "10e — 승격 발견의 Source가 adversarial로 강제된다 (교차 보증 위조 불가)"
else
  no "10e — 승격 발견의 Source가 adversarial로 강제된다 (교차 보증 위조 불가)"
  echo "      $row10e"
fi

# 11 — 표기가 다른 CRITICAL이 **낮은 confidence에서도** 억제되지 않는다.
#      케이스 9만으로는 부족하다: 거기 픽스처는 confidence 9라 suppress()가
#      severity를 raw로 읽어 비-CRITICAL로 판정해도 바닥(<=4)을 넘어 어차피
#      kept였다 — 정규화를 suppress에서 되돌려도 GREEN이었다(mutation N6).
#      CRITICAL의 계약은 "어떤 confidence에서도 항상 kept"이므로, 그 특권이
#      걸리는 유일한 값 영역(conf<=4)에서 재야 이 정규화에 이빨이 생긴다.
cat > "$tmp/findings_sevcase_lowconf.yaml" <<'Y'
findings:
  - file: src/auth.py
    line: 42
    severity: Critical
    confidence: 2
    summary: "low-confidence critical must survive suppression"
    agent: security-reviewer
Y
if python3 "$SCRIPT" --findings "$tmp/findings_sevcase_lowconf.yaml" 2>/dev/null \
     | grep -q 'low-confidence critical must survive suppression'; then
  ok "11 — 표기가 다른 CRITICAL이 낮은 confidence에서도 억제되지 않는다"
else
  no "11 — 표기가 다른 CRITICAL이 낮은 confidence에서도 억제되지 않는다"
fi

# --- 12 — dedup()의 그룹핑 키가 비-해시가능 `file`에 죽지 않는다 (라운드 3) ---
# 라운드 2가 키 튜플 `(file, line, severity)` 중 severity만 총함수화하고 형제 둘을
# raw로 남겼다. `file: [a.py]` 하나로 defaultdict 조회가 TypeError를 던져
# exit 1 + stdout 공백 — **다른 리뷰어의 진짜 CRITICAL까지 함께** 소실됐다.
cat > "$tmp/f_unhashable.yaml" <<'Y'
findings:
  - agent: security-reviewer
    file: [a.py]
    line: 1
    severity: CRITICAL
    summary: "list-valued file"
    confidence: 9
  - agent: code-reviewer
    file: real.py
    line: 2
    severity: CRITICAL
    summary: "GENUINE-CRIT-MUST-SURVIVE"
    confidence: 9
Y
out12="$(python3 "$SCRIPT" --findings "$tmp/f_unhashable.yaml" 2>/dev/null)"; rc12=$?
if [ "$rc12" -eq 0 ] && printf '%s' "$out12" | grep -q 'GENUINE-CRIT-MUST-SURVIVE' \
   && printf '%s' "$out12" | grep -q '2 CRITICAL'; then
  ok "12 — 비-해시가능 file이 리뷰 전체를 죽이지 않고 두 발견 모두 살아남는다"
else
  no "12 — 비-해시가능 file이 리뷰 전체를 죽이지 않고 두 발견 모두 살아남는다 (rc=$rc12)"
fi

# --- 13 — 컨테이너 수준 소실도 drop 채널로 **집계**된다 (라운드 3) ---
# `_as_list`가 stderr만 찍고 0을 돌려주면 stdout 공지가 안 나가고, 그 공지에
# keying하는 SKILL의 Dropped-finding override가 발화하지 못한다 → 버려진
# CRITICAL이 clean으로 렌더. 건수까지 맞아야 한다(2건이면 2로 보고).
cat > "$tmp/f_one.yaml" <<'Y'
findings:
  - agent: security-reviewer
    file: ok.py
    line: 1
    severity: IMPORTANT
    summary: "정상"
    confidence: 9
Y
cat > "$tmp/adv_container.yaml" <<'Y'
verdicts: []
new_findings:
  first:
    file: x.py
    severity: CRITICAL
    summary: "승격돼야 할 CRITICAL 1"
  second:
    file: y.py
    severity: CRITICAL
    summary: "승격돼야 할 CRITICAL 2"
Y
out13="$(python3 "$SCRIPT" --findings "$tmp/f_one.yaml" --adversarial "$tmp/adv_container.yaml" 2>/dev/null)"
if printf '%s' "$out13" | grep -qE '^2 finding\(s\) dropped as malformed'; then
  ok "13 — new_findings가 매핑이면 소실 2건이 drop 공지에 집계된다"
else
  no "13 — new_findings가 매핑이면 소실 2건이 drop 공지에 집계된다"
fi

# --- 14 — 스칼라 `findings:`가 글자 단위로 순회되지 않는다 (라운드 3) ---
# load_yaml이 `_as_list` 초크포인트를 우회해서, 문자열 하나가 문자당 드롭 1건으로
# 보고됐다(39건). 주장 하나는 1건이다.
printf 'findings: "CRITICAL: hardcoded key in config.py:11"\n' > "$tmp/f_scalar.yaml"
out14="$(python3 "$SCRIPT" --findings "$tmp/f_scalar.yaml" 2>/dev/null)"
if printf '%s' "$out14" | grep -qE '^1 finding\(s\) dropped as malformed'; then
  ok "14 — 스칼라 findings는 1건 소실로 집계된다(글자 수 아님)"
else
  no "14 — 스칼라 findings는 1건 소실로 집계된다(글자 수 아님)"
fi

# --- 15 — verdicts 컨테이너 소실도 같은 채널로 집계된다 (라운드 3) ---
cat > "$tmp/adv_badverdicts.yaml" <<'Y'
verdicts:
  a: {finding_id: x, verdict: reject}
Y
out15="$(python3 "$SCRIPT" --findings "$tmp/f_one.yaml" --adversarial "$tmp/adv_badverdicts.yaml" 2>/dev/null)"
if printf '%s' "$out15" | grep -qE '^1 finding\(s\) dropped as malformed'; then
  ok "15 — verdicts가 매핑이면 소실이 drop 공지에 집계된다"
else
  no "15 — verdicts가 매핑이면 소실이 drop 공지에 집계된다"
fi
finish
