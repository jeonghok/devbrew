#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/lib/recritic_fixture.sh
#
# 쉬운 말 출력 설계 Goal 2 · AC5 · AC6 (계획 R1 · R2 · R8 · R10 · R12 · R16) — 합성기와 시작 배너의 첫 줄이
# 상태 문장이고 0 인 정상 집계가 없다. 판단에 필요한 0(처분 줄)과 기계가 읽는 줄(**Findings:** ·
# blocking: · optional:)은 남는다. 합성기 표를 읽는 SKILL 자리가 합성기와 같은 글자를 쓴다.
# setup 의 오류 줄은 쉬운 말로 시작하고 원래 영어 토큰을 괄호에 남긴다. 부재 단언마다 양성 짝이 있다.
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
. "$PLUGIN_ROOT/tests/lib/recritic_fixture.sh"
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
SETUP="$PLUGIN_ROOT/scripts/setup-qg.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
export PYTHONDONTWRITEBYTECODE=1
unset CLAUDE_CODE_SESSION_ID
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT
first() { printf '%s\n' "$1" | head -1; }

# ① 발견 0 (재비판 경로 — 실제 실행과 같은 모양)
mkdir -p "$T/e"; printf '[]\n' > "$T/e/findings.yaml"; rf_prep "$T/e"; rf_reply "$T/e" 'verdicts: []'
out="$(rf_synth "$T/e")"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 지적 없음." "Goal 2: 발견 0 의 첫 줄이 상태 문장이다"
assert_not_contains "$out" "No findings" "AC6: 영어 고정 문구가 없다"
assert_grep "$out" '^## 리뷰 지적 \(합친 결과\)$' "AC6: 머리글이 한국어다(양성 짝)"
assert_not_contains "$out" "Review Findings" "AC6: 영어 머리글이 없다"
assert_grep "$out" '^\*\*처분:\*\* ' "R1: 처분 줄(판단에 필요한 0)은 남는다"
assert_grep "$out" '^blocking: 0$' "기계가 읽는 blocking: 줄은 남는다"
assert_not_contains "$(first "$out")" "verdict" "AC5: 쉬운 첫 줄은 verdict 글자를 담지 않는다"
assert_not_contains "$(first "$out")" "경고" "R16: 경고가 없으면 첫 줄에 경고를 말하지 않는다(양성 짝은 ④)"

# ② 발견 ≥1 — 0 인 등급은 첫 줄에서 뺀다. 표 · 고칠 방법이 한국어다
mkdir -p "$T/one"
printf -- '- {agent: security-reviewer, file: app.py, line: 3, severity: CRITICAL, summary: "SQL 을 문자열로 만든다", proposed_fix: "바인딩"}\n' > "$T/one/findings.yaml"
rf_prep "$T/one"; rf_reply "$T/one" 'verdicts:
  - {f: f1, verdict: confirm}'
out="$(rf_synth "$T/one")"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 남은 지적 1개(심각 1)." "Goal 2: 발견 ≥1 의 첫 줄이 상태 문장이고 0 인 등급을 뺀다"
assert_grep "$out" '^\*\*Findings:\*\* 1 CRITICAL / 0 IMPORTANT / 0 SUGGESTION$' "AC5: 기계가 읽는 Findings 줄은 형태 그대로다"
assert_grep "$out" '^\| 심각도 \| 위치 \| 내용 \| 낸 곳 \|$' "AC6: 표 머리가 한국어다"
assert_not_contains "$out" "| Sev |" "AC6: 영어 표 머리가 없다"
assert_grep "$out" '^\*\*고칠 방법:\*\*$' "AC6: 고칠 방법 머리가 한국어다"
assert_not_contains "$out" "Suggested fixes" "AC6: 영어 고칠 방법 머리가 없다"
mkdir -p "$T/mix"
printf -- '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: a}\n- {agent: r, file: b.py, line: 2, severity: IMPORTANT, summary: b, proposed_fix: f}\n- {agent: r, file: c.py, line: 3, severity: SUGGESTION, summary: c, proposed_fix: f}\n' > "$T/mix/findings.yaml"
rf_prep "$T/mix"; rf_reply "$T/mix" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}'
out="$(rf_synth "$T/mix")"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 남은 지적 3개(중요 2 · 제안 1)." "Goal 2: 등급은 심각 · 중요 · 제안 순서이고 0 인 등급(심각)은 없다"
assert_grep "$out" '^- #1 `a\.py:1` — \(없음\)$' "AC6: 고칠 방법이 없는 지적은 「(없음)」이다"
assert_not_contains "$out" "(none)" "AC6: 영어 「(none)」이 없다"

# ③ 버린 지적 — 첫 줄이 버린 수와 막는 경고를 말한다(없는 것과 버린 것은 다르다 — R12 · R16)
mkdir -p "$T/bad"; printf -- '- "매핑이 아닌 항목"\n' > "$T/bad/findings.yaml"; rf_prep "$T/bad"; rf_reply "$T/bad" 'verdicts: []'
out="$(rf_synth "$T/bad" 2>/dev/null)"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 지적 없음. 형식이 깨져 버린 지적 1개. 판정을 막는 경고가 있다 — 아래를 본다." "R12 · R16: 버린 수와 막는 경고를 첫 줄에 붙인다"
assert_grep "$out" '^1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed — ' "AC6: 버린 지적 줄이 쉬운 말로 시작하고 소비자가 읽는 토큰을 남긴다"
assert_not_contains "$out" "finding(s) dropped" "AC6: 옛 영어 버린 지적 줄이 없다"
# 표가 있는 갈래 — 살아남은 지적과 버린 지적이 함께
mkdir -p "$T/bad2"; printf -- '- {agent: r, file: a.py, line: 1, severity: CRITICAL, summary: s, proposed_fix: f}\n- "매핑이 아닌 항목"\n' > "$T/bad2/findings.yaml"
rf_prep "$T/bad2"; rf_reply "$T/bad2" 'verdicts:
  - {f: f1, verdict: confirm}'
out="$(rf_synth "$T/bad2" 2>/dev/null)"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 남은 지적 1개(심각 1). 형식이 깨져 버린 지적 1개. 판정을 막는 경고가 있다 — 아래를 본다." "R12 · R16: 표가 있는 갈래도 버린 수와 경고를 첫 줄에 붙인다"
assert_grep "$out" '^1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed — ' "AC6: 표가 있는 갈래의 버린 지적 줄도 토큰을 남긴다"

# ④ 막지 않는 경고 — 보조 입력(--recritic-diff)이 죽었다(R16)
mkdir -p "$T/aux"
printf -- '- {agent: sec, file: b.py, line: 2, severity: CRITICAL, summary: x}\n' > "$T/aux/findings.yaml"
rf_prep "$T/aux"; rf_reply "$T/aux" 'verdicts:
  - {f: f1, verdict: reject, evidence: "근거"}'
out="$(rf_synth "$T/aux" --recritic-diff "$T/aux/없는.diff" 2>/dev/null)"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 지적 없음. 판정을 막지 않는 경고가 있다 — 아래를 본다." "R16: 막지 않는 경고도 첫 줄에 말한다"
assert_grep "$out" '공시\(판정을 막지 않음\)' "R16: 그 경고의 본문(degrade 공시)이 아래에 있다(양성 짝)"

# ④b 주 입력이 죽었다 — 아무도 확인하지 않은 것을 「지적 없음」이라고 말하지 않는다(설계 §3 원칙 3 · 합친 qg #2)
mkdir -p "$T/dead"; printf '[]\n' > "$T/dead/findings.yaml"; rf_prep "$T/dead"; rf_reply "$T/dead" 'verdicts: []'
out="$(python3 "$SYNTH" --findings "$T/dead/없는.yaml" --recritic "$T/dead/reply.txt" --recritic-map "$T/dead/map.json" 2>/dev/null)"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 읽지 못한 입력이 있어 지적 수를 확정하지 못했다. 판정을 막는 경고가 있다 — 아래를 본다." "#2: 주 입력 사망의 첫 줄은 확정하지 못했다고 말한다"
assert_not_contains "$(first "$out")" "지적 없음" "#2: 주 입력 사망의 첫 줄에 「지적 없음」이 없다"
assert_grep "$out" '입력 실패\(주\)' "#2(양의 짝): 그 사실의 본문(degrade 공시)이 아래에 있다"
# 재비판자(판정 축의 주 판정자)가 죽었다 — 같은 규칙
mkdir -p "$T/dead2"; printf -- '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: a, proposed_fix: f}\n' > "$T/dead2/findings.yaml"; rf_prep "$T/dead2"
out="$(python3 "$SYNTH" --findings "$T/dead2/findings.yaml" --recritic "$T/dead2/없는.txt" --recritic-map "$T/dead2/map.json" 2>/dev/null)"
assert_grep "$(first "$out")" '^리뷰를 합쳤다 — (읽지 못한 입력이 있어 지적 수를 확정하지 못했다|남은 지적 [0-9]+개\(.*\)\. 읽지 못한 입력이 있어 지적이 더 있을 수 있다)\.' "#2: 재비판자가 죽은 첫 줄도 확정하지 못했다고 말한다"
mkdir -p "$T/dead3"; printf '[]\n' > "$T/dead3/findings.yaml"; rf_prep "$T/dead3"
out="$(python3 "$SYNTH" --findings "$T/dead3/findings.yaml" --recritic "$T/dead3/없는.txt" --recritic-map "$T/dead3/map.json" 2>"$T/dead3/err")"; rc=$?
assert_not_contains "$(first "$out")" "지적 없음" "#2: 재비판자가 죽고 남은 지적이 0 이어도 첫 줄에 「지적 없음」이 없다"
# 부재 단언의 양성 짝 — 합성기가 죽거나 아무것도 내지 않으면 위 단언은 공허하게 통과한다.
assert_eq "$rc" "0" "#2(양의 짝): 재비판자가 죽어도 합성기는 끝까지 돈다(rc 0)"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 읽지 못한 입력이 있어 지적 수를 확정하지 못했다. 판정을 막는 경고가 있다 — 아래를 본다." "#2(양의 짝): 재비판자가 죽고 지적 0 의 첫 줄은 확정하지 못했다고 말한다"
assert_grep "$out" '^- 입력 실패\(주\): code-recritic — ' "#2(양의 짝): 재비판자 사망이 본문 degrade 공시에 있다"
assert_grep "$(cat "$T/dead3/err")" '재비판 결과를 쓸 수 없다' "#2(양의 짝): stderr 가 재비판 입력 실패를 알린다"
# 표가 있는 갈래 — 살아남은 지적이 있어도 「더 있을 수 있다」를 붙인다(Review Focus)
got="$(PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c 'import synthesize_findings as s; print(s._status_line({"CRITICAL": 0, "IMPORTANT": 1, "SUGGESTION": 0}, 0, True, True, True))')"
assert_eq "$got" "리뷰를 합쳤다 — 남은 지적 1개(중요 1). 읽지 못한 입력이 있어 지적이 더 있을 수 있다. 판정을 막는 경고가 있다 — 아래를 본다." "#2: 표가 있는 갈래도 확정하지 못한 사실을 붙인다"
got="$(PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c 'import synthesize_findings as s; print(s._status_line({"CRITICAL": 0, "IMPORTANT": 1, "SUGGESTION": 0}, 0, False, False))')"
assert_eq "$got" "리뷰를 합쳤다 — 남은 지적 1개(중요 1)." "#2(양의 짝): 입력을 다 읽었으면 붙이지 않는다"
# ⑤ --emit-verdict: 판정 줄은 정확히 하나, 쉬운 줄과 섞이지 않는다. 블록 앞에 쉬운 한 줄(AC5 · R2)
printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
out="$(rf_synth "$T/one" --emit-verdict --angles "$T/angles.txt")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^verdict: ')" "1" "AC5: verdict 줄은 정확히 한 번"
assert_eq "$(printf '%s\n' "$out" | grep -c 'verdict:')" "1" "AC5: 그 밖의 줄에 verdict: 글자가 없다"
assert_eq "$(printf '%s\n' "$out" | grep -B1 '^angles:$' | head -1)" "아래는 이 판정의 리뷰 각도(angles) 원문이다." "AC5: angles 블록 바로 앞에 쉬운 한 줄"
assert_eq "$(printf '%s\n' "$out" | grep -c '^아래는 이 판정')" "1" "AC5: 그 쉬운 줄은 한 번만 나온다"
printf 'topic_key: -\nstatus: no-declaration\nreason: -\nbranches: -\nin_base: -\nboundary: -\ntips: -\nseal: -\nseal_on_topic: -\ntree: -\nhead_commit: -\nconflicts: -\ncommits: -\n' > "$T/scope.txt"
out="$(rf_synth "$T/one" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")"
assert_eq "$(printf '%s\n' "$out" | grep -B1 '^scope:$' | head -1)" "아래는 이 판정이 본 범위(scope)와 리뷰 각도(angles)의 원문이다." "AC5: 두 블록이면 scope 블록 앞에 두 블록을 다 가리키는 한 줄"
assert_eq "$(printf '%s\n' "$out" | grep -c '^아래는 이 판정')" "1" "AC5: 두 블록이어도 쉬운 줄은 한 번"
out="$(rf_synth "$T/one" --emit-verdict --scope "$T/scope.txt")"
assert_eq "$(printf '%s\n' "$out" | grep -B1 '^scope:$' | head -1)" "아래는 이 판정이 본 범위(scope)의 원문이다." "AC5: scope 블록만 있으면 그것만 가리킨다"
out="$(rf_synth "$T/one" --emit-verdict)"
assert_not_contains "$out" "아래는 이 판정" "AC5: 블록이 없으면 블록을 가리키는 줄도 없다"
assert_grep "$out" '^verdict: defect$' "AC5: 블록 없는 실행도 판정 줄은 있다(양성 짝)"

# ⑥ 합성기 표를 읽는 SKILL 자리 — 머리 글자와 고칠 방법 목록 이름이 합성기와 같다(한쪽만 바뀌면 조용히 빈 「지적」 절)
out="$(rf_synth "$T/one")"
# 「지적」 절을 쓰는 줄에서만 뽑는다 — 같은 블록의 「낮춘 지적」 줄도 `grep -q … "$SYN"` 꼴이다
# (그 줄의 앵커 일치는 test_lowered_gate_wiring.sh 가 실제 합성기 출력으로 잰다).
JL="$(grep -F "printf '\n## 지적\n\n'" "$SKILL")"
anchor="$(printf '%s\n' "$JL" | sed -n "s/.*grep -q '\([^']*\)' \"\$SYN\".*/\1/p")"
assert_eq "$(printf '%s\n' "$anchor" | grep -c .)" "1" "SKILL Final verdict 의 지적 표 앵커를 하나 찾았다"
assert_eq "${anchor}" "^| 심각도 |" "SKILL 의 지적 표 앵커가 한국어 머리다"
sedpat="$(printf '%s\n' "$JL" | sed -n "s/.*then sed -n '\/\([^/]*\)\/,\/^\$\/p' \"\$SYN\".*/\1/p")"
assert_eq "${sedpat}" "${anchor}" "SKILL 의 sed 범위 시작이 grep 앵커와 같은 글자다(한쪽만 바뀌면 빈 절)"
rng="$(printf '%s\n' "$out" | sed -n "/${anchor}/,/^\$/p")"
assert_grep "$rng" '^\| CRITICAL \| app\.py:3 \| SQL 을 문자열로 만든다 \| security-reviewer \|$' "그 앵커로 자른 범위에 지적 행이 든다(result.md 의 「지적」 절이 비지 않는다)"
assert_not_contains "$(sed -n "/grep -q '^| /p" "$SKILL")" "Sev |" "SKILL 에 옛 영어 표 앵커가 없다"
fixes="$(sed -n 's/.*the `\(\*\*[^`]*\*\*\)` list carries the same `#k`.*/\1/p' "$SKILL")"
assert_eq "${fixes}" "**고칠 방법:**" "SKILL Step 5 가 고칠 방법 목록을 합성기와 같은 글자로 부른다"
assert_grep "$out" "^$(printf '%s' "$fixes" | sed 's/\*/\\*/g')\$" "합성기가 SKILL 이 부르는 그 글자를 낸다"

# ⑦ 시작 배너 — 첫 줄이 상태 문장이고 과정 나열이 없다
mkdir -p "$T/w"
out="$(cd "$T/w" && bash "$SETUP" --session-id "plaintest-$$" 2>/dev/null)"
assert_eq "$(first "$out")" "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다." "Goal 2: 시작 배너 첫 줄이 상태 문장이다"
assert_not_contains "$out" "Pipeline:" "Goal 2: 시작 배너에 과정 나열이 없다"
assert_not_contains "$out" "Pipeline runs in this turn" "AC6: 옛 영어 배너 끝줄이 없다"
assert_not_contains "$out" "계획 파일" "--plan 이 없어져 배너에 계획 파일 줄이 없다"
assert_not_contains "$out" "Plan file" "AC6: 옛 영어 계획 파일 줄이 없다"

# ⑧ setup 오류 줄(R10) — 쉬운 말이 앞, 원래 영어 토큰은 괄호에(기존 락이 그 토큰을 잰다)
err="$(cd "$T/w" && bash "$SETUP" --paths 2>&1 >/dev/null)"
assert_contains "$err" "❌ --paths 뒤에 glob 이 하나도 없다(--paths requires at least one glob)." "R10: --paths 오류"
err="$(cd "$T/w" && bash "$SETUP" --session-id 2>&1 >/dev/null)"
assert_contains "$err" "❌ --session-id 뒤에 값이 없다(--session-id requires an argument)." "R10: --session-id 오류"
err="$(cd "$T/w" && bash "$SETUP" --no-such-flag 2>&1 >/dev/null)"
assert_contains "$err" "❌ 모르는 인자다(Unknown argument): --no-such-flag" "R10: 모르는 인자 오류"
assert_contains "$err" "쓰는 법은 --help 로 본다." "R10: 모르는 인자 오류의 안내 줄"
assert_not_contains "$err" "Use --help" "R10: 옛 영어 안내 줄이 없다"
err="$(cd "$T/w" && bash "$SETUP" 2>&1 >/dev/null)"
assert_contains "$err" "세션 ID(session ID)가 비어 있어 상태 폴더를 만들 수 없다." "R10: 세션 ID 없음 오류"
assert_not_contains "$err" "cannot create pipeline state" "R10: 옛 영어 세션 ID 없음 오류가 없다"
err="$(cd "$T/w" && bash "$SETUP" --session-id 'bad id' 2>&1 >/dev/null)"
assert_contains "$err" "가 허용 모양([A-Za-z0-9_-]{8,})이 아니다(fails pattern guard)." "R10: 세션 ID 모양 오류"
err="$(cd "$T/w" && DEVBREW_QUALITY_GATES_DISABLE=1 bash "$SETUP" 2>&1 >/dev/null)"
assert_contains "$err" "DEVBREW_QUALITY_GATES_DISABLE=1 이 켜져 있어 /quality-gates:quality-pipeline 을 시작하지 않는다(setup-qg disabled)." "R10: kill switch 거부 줄"
finish
