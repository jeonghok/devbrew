#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/tests/lib/recritic_fixture.sh
#
# 합성기의 질문 줄 — `질문 줄: 막는 지적 <b>개 · 제안 <s>개 — 가장 무거운 것: <file>:<line> — <요약>` 한 줄.
# 지적이 없으면 `질문 줄: 지적 없음`. 「판정 degrade」 블록이 있으면 끝에 ` · 경고 <n>개: 판정 degrade`
# (n = 그 블록의 `- ` 줄 수). 자리는 `lowered:` 다음(되올림이 있으면 `restored:` 다음).
# 요약은 「가장 무거운 것」 행 「내용」 칸의 쉬운 말 부분을 공백을 접어 80자에서 자른 것(넘으면 79자 + `…`).
# 분기마다 fixture 가 있다: 지적 없음 · 제안만 · 맨 위 심각도가 여럿 · 80자 · 81자 · 200자 · 줄바꿈과 겹친 공백 ·
# degrade 한 줄 · 여러 줄 · degrade 없음 · 지적 수를 확정하지 못함(지적 0 / 지적 있음).
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
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT

# fx <이름> <findings YAML> <재비판 블록> — 재비판 경로 fixture 를 만들고 그 폴더를 낸다.
fx() {
  mkdir -p "$T/$1"; printf '%s\n' "$2" > "$T/$1/findings.yaml"
  rf_prep "$T/$1" >/dev/null; rf_reply "$T/$1" "$3"
  echo "$T/$1"
}
askl() { printf '%s\n' "$1" | sed -n 's/^질문 줄: //p'; }
# 코드 포인트 수 — 셸의 ${#v} 는 로케일에 따라 바이트를 센다.
cps() { python3 -c 'import sys; print(len(sys.argv[1]))' "$1"; }
rep() { python3 -c 'import sys; print(sys.argv[1] * int(sys.argv[2]), end="")' "$1" "$2"; }
# degrade 블록(머리줄 다음 `- ` 줄들)의 줄 수
deg_n() { printf '%s\n' "$1" | awk '/^판정 degrade — /{on=1; next} on && /^- /{n++; next} on{on=0} END{print n+0}'; }

# ── IMPORTANT 1 · SUGGESTION 1 — 제안이 파일 이름 순으로 앞서도 가장 무거운 것은 IMPORTANT 다
FX_TWO=$(fx two '- {agent: r, file: a.py, line: 3, severity: SUGGESTION, summary: 이름을 더 분명하게, proposed_fix: f}
- {agent: r, file: b.py, line: 7, severity: IMPORTANT, summary: 토큰을 검사하지 않는다, proposed_fix: f}' 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}')
out="$(rf_synth "$FX_TWO" 2>/dev/null)"
assert_grep "$out" '^질문 줄: 막는 지적 1개 · 제안 1개 — 가장 무거운 것: [^ ]+:[0-9]+ — ' "질문 줄: 수와 가장 무거운 지적 하나"
assert_eq "$(askl "$out")" "막는 지적 1개 · 제안 1개 — 가장 무거운 것: b.py:7 — 토큰을 검사하지 않는다" "질문 줄: 심각도가 파일 순서보다 먼저다(글자 그대로)"
assert_eq "$(printf '%s\n' "$out" | grep -c '^질문 줄: ')" "1" "질문 줄: 한 줄뿐이다"
assert_eq "$(printf '%s\n' "$out" | sed -n 's/^blocking: //p')" "1" "질문 줄 짝: blocking 줄의 수와 같다"
assert_eq "$(printf '%s\n' "$out" | sed -n 's/^optional: //p')" "1" "질문 줄 짝: optional 줄의 수와 같다"
assert_eq "$(printf '%s\n' "$out" | grep -A1 '^lowered: ' | tail -1)" "질문 줄: 막는 지적 1개 · 제안 1개 — 가장 무거운 것: b.py:7 — 토큰을 검사하지 않는다" "자리: lowered: 바로 다음 줄이다"
assert_not_contains "$out" " · 경고 " "degrade 가 없으면 꼬리가 없다"
assert_eq "$(deg_n "$out")" "0" "전제: 이 fixture 에는 degrade 블록이 없다"

# ── 지적 없음
FX_NONE=$(fx none '[]' 'verdicts: []')
out0="$(rf_synth "$FX_NONE" 2>/dev/null)"
assert_contains "$out0" "질문 줄: 지적 없음" "질문 줄: 지적이 없으면 그렇게 낸다"
assert_eq "$(askl "$out0")" "지적 없음" "질문 줄: 지적이 없으면 꼬리 없이 그 말뿐이다"
assert_eq "$(printf '%s\n' "$out0" | grep -A1 '^lowered: ' | tail -1)" "질문 줄: 지적 없음" "자리: 지적이 없어도 lowered: 바로 다음이다"

# ── 제안만 — 막는 지적 0개, 가장 무거운 것은 표의 첫 행(파일 순)
FX_SUGG=$(fx sugg '- {agent: r, file: z.py, line: 1, severity: SUGGESTION, summary: 뒤의 제안, proposed_fix: f}
- {agent: r, file: m.py, line: 4, severity: SUGGESTION, summary: 앞의 제안, proposed_fix: f}' 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}')
out="$(rf_synth "$FX_SUGG" 2>/dev/null)"
assert_eq "$(askl "$out")" "막는 지적 0개 · 제안 2개 — 가장 무거운 것: m.py:4 — 앞의 제안" "질문 줄: 제안만이면 막는 지적 0개 · 첫 행"

# ── 맨 위 심각도가 여럿 — 표의 첫 행이 이긴다. 쉬운 말(plain)이 있으면 그것만 싣는다
FX_TOP=$(fx top '- {agent: r, file: c.py, line: 5, severity: CRITICAL, summary: 셋째 심각, proposed_fix: f}
- {agent: r, file: 0.py, line: 1, severity: IMPORTANT, summary: 중요 하나, proposed_fix: f}
- {agent: r, file: a.py, line: 9, severity: CRITICAL, summary: 둘째 심각, proposed_fix: f}
- {agent: r, file: a.py, line: 2, severity: CRITICAL, summary: raw sql concat, plain: 사용자 입력이 쿼리에 그대로 들어간다, proposed_fix: f}' 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}
  - {f: f4, verdict: confirm}')
out="$(rf_synth "$FX_TOP" 2>/dev/null)"
first_row="$(printf '%s\n' "$out" | grep -A2 '^| 심각도 | 위치 |' | tail -1)"
assert_contains "$first_row" "| CRITICAL | a.py:2 |" "전제: 표의 첫 행이 a.py:2 다"
assert_eq "$(askl "$out")" "막는 지적 4개 · 제안 0개 — 가장 무거운 것: a.py:2 — 사용자 입력이 쿼리에 그대로 들어간다" "질문 줄: 맨 위 심각도가 여럿이면 표의 첫 행 · 쉬운 말 부분만"
assert_not_contains "$(askl "$out")" "raw sql concat" "질문 줄: 괄호 속 요약은 싣지 않는다"

# ── 길이 — 80자는 그대로, 81자는 79자 + …, 200자도 80자
S80="$(rep 가 80)"; S81="$(rep 나 81)"; S200="$(rep 다 200)"
FX_80=$(fx w80 "- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: ${S80}, proposed_fix: f}" 'verdicts:
  - {f: f1, verdict: confirm}')
FX_81=$(fx w81 "- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: ${S81}, proposed_fix: f}" 'verdicts:
  - {f: f1, verdict: confirm}')
FX_LONG=$(fx long "- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: ${S200}, proposed_fix: f}" 'verdicts:
  - {f: f1, verdict: confirm}')
assert_eq "$(cps "$S80"):$(cps "$S81"):$(cps "$S200")" "80:81:200" "전제: fixture 의 내용 길이가 80 · 81 · 200 이다"
assert_eq "$(askl "$(rf_synth "$FX_80" 2>/dev/null)")" "막는 지적 1개 · 제안 0개 — 가장 무거운 것: a.py:1 — ${S80}" "질문 줄: 80자는 자르지 않는다"
assert_eq "$(askl "$(rf_synth "$FX_81" 2>/dev/null)")" "막는 지적 1개 · 제안 0개 — 가장 무거운 것: a.py:1 — $(rep 나 79)…" "질문 줄: 81자는 79자 + … 로 자른다"
long="$(rf_synth "$FX_LONG" 2>/dev/null | sed -n 's/^질문 줄: .* — //p')"
if [ -n "$long" ] && [ "$(cps "$long")" -le 80 ]; then
  ok "질문 줄: 요약은 80자에서 자른다 ($(cps "$long")자)"
else
  no "질문 줄: 요약이 $(cps "$long")자다(비었거나 80 을 넘는다)"
fi
assert_eq "$long" "$(rep 다 79)…" "질문 줄: 200자 요약도 79자 + … 이다"

# ── 줄바꿈 · 겹친 공백은 공백 하나로 접는다
FX_WS=$(fx ws '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: "첫  줄\n둘째   줄\t끝", proposed_fix: f}' 'verdicts:
  - {f: f1, verdict: confirm}')
assert_eq "$(askl "$(rf_synth "$FX_WS" 2>/dev/null)")" "막는 지적 1개 · 제안 0개 — 가장 무거운 것: a.py:1 — 첫 줄 둘째 줄 끝" "질문 줄: 줄바꿈과 겹친 공백을 접는다"

# ── 판정 degrade — 한 줄(보조 입력 사망) · 여러 줄(근거 없는 기각 강제 + 보조 입력 사망)
FX_DEGRADED=$(fx deg1 '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: 하나, proposed_fix: f}' 'verdicts:
  - {f: f1, verdict: confirm}')
outd="$(rf_synth "$FX_DEGRADED" --recritic-diff "$FX_DEGRADED/없는.diff" 2>/dev/null)"
assert_eq "$(deg_n "$outd")" "1" "전제: 이 fixture 의 degrade 블록은 한 줄이다"
assert_grep "$outd" '^질문 줄: .* · 경고 [0-9]+개: 판정 degrade$' "질문 줄: 판정 degrade 가 있으면 꼬리에 센다"
assert_eq "$(askl "$outd")" "막는 지적 1개 · 제안 0개 — 가장 무거운 것: a.py:1 — 하나 · 경고 1개: 판정 degrade" "질문 줄: degrade 한 줄이면 경고 1개"
FX_DEGN=$(fx degn '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: 하나, proposed_fix: f}
- {agent: r, file: b.py, line: 2, severity: SUGGESTION, summary: 둘, proposed_fix: f}' 'verdicts:
  - {f: f1, verdict: reject}
  - {f: f2, verdict: lower, to: IMPORTANT, evidence: 근거}')
outn="$(rf_synth "$FX_DEGN" --recritic-diff "$FX_DEGN/없는.diff" 2>/dev/null)"
n="$(deg_n "$outn")"
if [ "$n" -ge 2 ]; then ok "전제: 이 fixture 의 degrade 블록은 여러 줄이다 (${n}줄)"; else no "전제: degrade 블록이 ${n}줄이다(둘 이상이어야 한다)"; fi
assert_grep "$(askl "$outn")" " · 경고 ${n}개: 판정 degrade$" "질문 줄: 꼬리의 수가 degrade 블록의 - 줄 수와 같다"
assert_eq "$(printf '%s\n' "$outn" | grep -c '^질문 줄: ')" "1" "질문 줄: degrade 가 있어도 한 줄뿐이다"
# 지적이 없고 degrade 만 있다 — 지적 없음 뒤에 꼬리
FX_DEG0=$(fx deg0 '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: 하나, proposed_fix: f}' 'verdicts:
  - {f: f1, verdict: reject, evidence: 근거}')
out="$(rf_synth "$FX_DEG0" --recritic-diff "$FX_DEG0/없는.diff" 2>/dev/null)"
assert_eq "$(askl "$out")" "지적 없음 · 경고 $(deg_n "$out")개: 판정 degrade" "질문 줄: 지적이 없어도 degrade 꼬리를 붙인다"
assert_eq "$(deg_n "$out")" "1" "전제: 지적 없는 degrade fixture 의 블록은 한 줄이다"

# ── 되올림이 있으면 restored: 다음
FX_BACK=$(fx back '- {agent: r, file: a.py, line: 4, severity: IMPORTANT, summary: 캐시 키를 검증하지 않는다, proposed_fix: f}' 'verdicts:
  - {f: f1, verdict: lower, evidence: "의도 출처는 캐시 무효화만 요구한다"}')
out="$(rf_synth "$FX_BACK" --restore-lowered L1 2>/dev/null)"
assert_eq "$(printf '%s\n' "$out" | grep -A1 '^restored: ' | tail -1)" "질문 줄: 막는 지적 1개 · 제안 0개 — 가장 무거운 것: a.py:4 — 캐시 키를 검증하지 않는다" "자리: 되올림이 있으면 restored: 바로 다음이다"
out="$(rf_synth "$FX_BACK" 2>/dev/null)"
assert_eq "$(askl "$out")" "막는 지적 0개 · 제안 1개 — 가장 무거운 것: a.py:4 — 캐시 키를 검증하지 않는다" "질문 줄: 낮춘 지적은 제안으로 센다(되올리기 전)"

# ── 판정 꼬리 — 질문 줄이 들어와도 verdict 줄과 qg-verdict-args 줄은 끝에 그대로다
printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
out="$(rf_synth "$FX_TWO" --emit-verdict --angles "$T/angles.txt" --verdict-args 2>/dev/null)"
assert_grep "$(printf '%s\n' "$out" | tail -1)" '^qg-verdict-args: ' "판정 꼬리: 마지막 줄은 qg-verdict-args: 다"
assert_grep "$(printf '%s\n' "$out" | tail -2 | head -1)" '^verdict: ' "판정 꼬리: 그 앞 줄은 verdict: 다"
assert_eq "$(printf '%s\n' "$out" | grep -c '^질문 줄: ')" "1" "판정 꼬리: 질문 줄은 본 보고서에 한 번뿐이다"

# ── 지적 수를 확정하지 못했다 — 주 입력(지적 파일 · 재비판자)이 죽었다. 상태 줄과 같은 말을 한다.
# unc_flag <줄> — 확정하지 못했다는 말(「확정하지 못했다」 · 「더 있을 수 있다」)이 있으면 1
unc_flag() { case "$1" in *확정하지\ 못했다*|*"더 있을 수 있다"*) echo 1 ;; *) echo 0 ;; esac; }
FX_UNC0=$(fx unc0 '[]' 'verdicts: []')
outu0="$(python3 "$SYNTH" --findings "$FX_UNC0/없는.yaml" --recritic "$FX_UNC0/reply.txt" --recritic-map "$FX_UNC0/map.json" 2>/dev/null)"
assert_eq "$(askl "$outu0")" "지적 수를 확정하지 못했다 · 경고 $(deg_n "$outu0")개: 판정 degrade" "확정 못 함 · 지적 0: 「지적 수를 확정하지 못했다」(degrade 꼬리는 그대로)"
assert_eq "$(deg_n "$outu0")" "1" "전제: 지적 파일 사망 fixture 의 degrade 블록은 한 줄이다"
assert_not_contains "$(askl "$outu0")" "지적 없음" "확정 못 함 · 지적 0: 「지적 없음」이라고 말하지 않는다"
assert_eq "$(unc_flag "$(printf '%s\n' "$outu0" | head -1)"):$(unc_flag "$(askl "$outu0")")" "1:1" "확정 못 함 · 지적 0: 상태 줄과 질문 줄이 같이 확정하지 못했다고 말한다"
FX_UNC1=$(fx unc1 '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: 하나, proposed_fix: f}' 'verdicts: []')
outu1="$(python3 "$SYNTH" --findings "$FX_UNC1/findings.yaml" --recritic "$FX_UNC1/없는.txt" --recritic-map "$FX_UNC1/map.json" 2>/dev/null)"
assert_eq "$(askl "$outu1")" "막는 지적 1개 · 제안 0개 (더 있을 수 있다) — 가장 무거운 것: a.py:1 — 하나 · 경고 $(deg_n "$outu1")개: 판정 degrade" "확정 못 함 · 지적 있음: 수 뒤에 「(더 있을 수 있다)」"
assert_eq "$(deg_n "$outu1")" "1" "전제: 재비판자 사망 fixture 의 degrade 블록은 한 줄이다"
assert_eq "$(unc_flag "$(printf '%s\n' "$outu1" | head -1)"):$(unc_flag "$(askl "$outu1")")" "1:1" "확정 못 함 · 지적 있음: 상태 줄과 질문 줄이 같이 더 있을 수 있다고 말한다"
# 짝 — 확정된 실행(지적 있음 · 없음 · degrade 만 있음)에는 그 말이 없고, 상태 줄에도 없다
for d in "$FX_TWO" "$FX_NONE"; do
  o="$(rf_synth "$d" 2>/dev/null)"
  assert_eq "$(unc_flag "$(printf '%s\n' "$o" | head -1)"):$(unc_flag "$(askl "$o")")" "0:0" "확정된 실행: 상태 줄도 질문 줄도 확정 못 함을 말하지 않는다 (${d##*/})"
done
assert_eq "$(unc_flag "$(askl "$outd")")" "0" "확정된 실행: 보조 입력만 죽은 degrade 에는 「(더 있을 수 있다)」가 없다"

# ── 함수 — 출력과 같은 글(접두 없이)
got="$(PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c 'import synthesize_findings as s; print(s._ask_line([], 0, 0))')"
assert_eq "$got" "지적 없음" "_ask_line: 지적 없음 · 경고 없음"
got="$(PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c 'import synthesize_findings as s; print(s._ask_line([], 0, 3))')"
assert_eq "$got" "지적 없음 · 경고 3개: 판정 degrade" "_ask_line: 경고 수를 그대로 싣는다"
got="$(PYTHONPATH="$PLUGIN_ROOT/scripts" python3 -c 'import synthesize_findings as s; print(s._ask_line([], 0, 0, True))')"
assert_eq "$got" "지적 수를 확정하지 못했다" "_ask_line: 확정 못 함 · 지적 0 · 경고 없음"
finish
