#!/usr/bin/env bash
# AC5 (no discover-spec.sh) + AC6 (C7 mktemp guard) + OQ2 (medium effort)
# + one behavioral integration through a mock codex on PATH.
set -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN="$PLUGIN_ROOT/scripts/run_spec_codex_reviewer.sh"
TMP="$(mktemp -d -t sd-run-codex-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/abort_trigger.sh"

# --- Structural greps (AC5/AC6/OQ2) ---
grep -q 'discover-spec' "$RUN" \
  && no "AC5: discover-spec.sh referenced (C3 circular-injection risk)" \
  || ok "AC5: no discover-spec.sh call"

# C7: the scratch-dir assignment line must be guarded before any trap arms.
grep -qE 'SCRATCH=.*mktemp.*\|\|' "$RUN" \
  && ok "AC6: mktemp SCRATCH assignment has '||' guard" \
  || no "AC6: mktemp SCRATCH assignment not guarded (C7 footgun)"

# C7 (strengthened): the guard must actually PRECEDE the trap arm line number —
# a mutation that moves `trap` above the guarded assignment would still pass
# the existence-only grep above but must fail here.
scratch_guard_line="$(grep -nE 'SCRATCH=.*mktemp.*\|\|' "$RUN" | head -1 | cut -d: -f1)"
trap_line="$(grep -nE "trap.*rm -rf.*SCRATCH.*EXIT" "$RUN" | head -1 | cut -d: -f1)"
if [[ -n "$scratch_guard_line" && -n "$trap_line" && "$scratch_guard_line" -lt "$trap_line" ]]; then
  ok "AC6: SCRATCH guard (line $scratch_guard_line) precedes trap arm (line $trap_line)"
else
  no "AC6: SCRATCH guard does NOT precede trap arm (guard=${scratch_guard_line:-<missing>} trap=${trap_line:-<missing>})"
fi

# 추론 강도 상한 부재 락 — `run_brief_codex_reviewer.sh`가 이미 쓰는 계약을 전파한다.
# 하니스가 medium을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고, 그 하향은
# codex co-review의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다.
# `-c` 인자 줄만 본다 — 주석·문서에서 이름을 *언급*하는 것은 위반이 아니다(실행 경로가 기준).
grep -qE '^[[:space:]]*-c .*model_reasoning_effort' "$RUN" \
  && no "추론 강도가 실행 인자로 핀됨 — 사용자 codex 설정을 하향 억제한다" \
  || ok "추론 강도 미핀 (사용자 codex 설정이 지배)"
# 반대 방향 — 상한 제거가 샌드박스까지 걷어내지 않았음을 증명한다(C1 유지선).
grep -qE '^[[:space:]]*-s read-only' "$RUN" \
  && ok "Law2: -s read-only 샌드박스 플래그 존속" || no "-s read-only 사라짐"
grep -qE '^[[:space:]]*-C ' "$RUN" \
  && ok "-C 작업디렉토리 핀 존속" || no "-C 사라짐"
grep -qE '^[[:space:]]*--json' "$RUN" \
  && ok "--json 파싱 계약 존속" || no "--json 사라짐"

# --- Behavioral: mock codex on PATH produces parsed YAML at out path ---
DOC="$TMP/x-design.md"; printf '# X\n\n## 2. Goals\nrobust.\n' > "$DOC"
mkdir -p "$TMP/codexbin"
cat > "$TMP/codexbin/codex" <<'SH'
#!/usr/bin/env bash
# ignore all args; emit one valid agent_message with findings
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": [{\"category\": \"ambiguity\", \"target_section\": \"#2-goals\", \"severity\": \"high\"}]}\n```"}}
JSONL
exit 0
SH
chmod +x "$TMP/codexbin/codex"
OUT="$TMP/out.yaml"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$TMP/codexbin:/usr/bin:/bin" \
  bash "$RUN" "$DOC" "$PLUGIN_ROOT" "$OUT"
rc=$?
[[ $rc -eq 0 ]] && ok "exit 0" || no "exit $rc (expected 0)"
grep -q 'category: ambiguity' "$OUT" && ok "parsed finding written to out" || no "out yaml missing finding"
grep -q 'codex_failed: false' "$OUT" && ok "codex_failed false on success" || no "codex_failed not false"

# Behavioral: codex exit≠0 → degrade meta (not crash)
cat > "$TMP/codexbin/codex" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$TMP/codexbin/codex"
OUT2="$TMP/out2.yaml"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$TMP/codexbin:/usr/bin:/bin" \
  bash "$RUN" "$DOC" "$PLUGIN_ROOT" "$OUT2" || true
grep -q 'codex_failed: true' "$OUT2" && ok "codex exit1 → codex_failed true" || no "exit1 not marked failed"

# --- FIX 1: codex_findings_to_yaml.py conversion failure must still degrade
# and exit 0 (the final pipeline is otherwise unguarded under set -e).
# Shadow CLAUDE_PLUGIN_ROOT with a fake scripts/ dir: build_spec_codex_prompt.py
# still works (symlinked to the real one), but codex_findings_to_yaml.py always
# fails — so codex itself can "succeed" and the conversion step is what breaks.
FAKE_ROOT="$TMP/fake-plugin-root"
mkdir -p "$FAKE_ROOT/scripts"
# 〔2026-08-22 감사 §7-9〕 FAKE_ROOT 는 **설치본 모양**으로 깐다 — 심볼릭 링크가 아니라
# 물리 사본이다. 앞 판본은 빌더 하나만 링크했고 형제 `codex_prompt_common.py` 를 안 깔았다.
# 그런데도 통과했다: CPython 은 링크된 스크립트의 `sys.path[0]` 을 **realpath 로** 잡으므로
# (3.9.6 실측) 링크된 빌더가 형제를 *정본 옆* 에서 찾아냈다. 같은 GREEN, 다른 이유 —
# 설치본에서는 형제가 물리 사본으로 옆에 있어 import 되고, 테스트에서는 realpath 우회로
# import 됐다. 즉 이 시나리오는 통과하면서 **설치본의 모양을 재고 있지 않았다.**
# 사본으로 깔면 `sys.path[0]` 이 FAKE_ROOT/scripts 가 되어 형제가 실제로 load-bearing
# 이 된다(실측: 형제를 빼면 ModuleNotFoundError 로 실패한다).
# `prompt-preamble.md` 는 리포에서 심볼릭 링크지만 설치 시 역참조되므로 `-L` 로 내용을 깐다
# (`codex_prompt_common.py` 가 `__file__.resolve().parent` 형제로 읽는다).
cp "$PLUGIN_ROOT/scripts/build_spec_codex_prompt.py" "$FAKE_ROOT/scripts/build_spec_codex_prompt.py"
cp "$PLUGIN_ROOT/scripts/codex_prompt_common.py" "$FAKE_ROOT/scripts/codex_prompt_common.py"
cp -L "$PLUGIN_ROOT/scripts/prompt-preamble.md" "$FAKE_ROOT/scripts/prompt-preamble.md"
# 회귀 락 — 다시 링크로 돌아가면 realpath 우회가 되살아나고 위 사본들이 dead weight 가
# 된다. 그 상태는 조용하다(테스트는 계속 통과한다). 그래서 모양 자체를 단언한다.
_fake_links=0
_fake_files=0
for _f in "$FAKE_ROOT"/scripts/*; do
  [ -L "$_f" ] && _fake_links=$((_fake_links + 1))
  { [ -e "$_f" ] || [ -L "$_f" ]; } && _fake_files=$((_fake_files + 1))
done
[ "$_fake_links" -eq 0 ] \
  && ok "§7-9: FAKE_ROOT/scripts 에 심볼릭 링크 0개 (sys.path[0] 이 realpath 로 새지 않는다)" \
  || no "§7-9: FAKE_ROOT/scripts 에 심볼릭 링크가 ${_fake_links}개 있다 — 링크된 스크립트의 sys.path[0] 은 realpath 라, 옆에 깔아둔 형제 사본이 아니라 정본 옆 형제가 import 된다(설치본 모양을 안 재게 된다)"
[ "$_fake_files" -ge 3 ] \
  && ok "§7-9: FAKE_ROOT/scripts 에 파일 ${_fake_files}개 (빌더+형제 모듈+프리앰블이 깔렸다)" \
  || no "§7-9: FAKE_ROOT/scripts 에 파일이 ${_fake_files}개뿐이다 — 설치본이 갖는 형제 파일 하나가 안 깔렸다 (빌더·codex_prompt_common.py·prompt-preamble.md 셋이 필요하다)"
cat > "$FAKE_ROOT/scripts/codex_findings_to_yaml.py" <<'PY'
#!/usr/bin/env python3
import sys
sys.exit(1)
PY
chmod +x "$FAKE_ROOT/scripts/codex_findings_to_yaml.py"

cat > "$TMP/codexbin/codex" <<'SH'
#!/usr/bin/env bash
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": []}\n```"}}
JSONL
exit 0
SH
chmod +x "$TMP/codexbin/codex"
OUT3="$TMP/out3.yaml"
CLAUDE_PLUGIN_ROOT="$FAKE_ROOT" PATH="$TMP/codexbin:/usr/bin:/bin" \
  bash "$RUN" "$DOC" "$PLUGIN_ROOT" "$OUT3"
rc=$?
[[ $rc -eq 0 ]] && ok "FIX1: yaml-conversion failure still exits 0" || no "FIX1: exit $rc (expected 0)"
grep -q 'codex_failed: true' "$OUT3" && grep -q 'reason: yaml_conversion_failed' "$OUT3" \
  && ok "FIX1: degrade YAML has codex_failed true + reason yaml_conversion_failed" \
  || no "FIX1: degrade YAML missing codex_failed:true/reason:yaml_conversion_failed"

# --- FIX 2: relative OUTPUT_PATH must resolve against the invocation cwd,
# NOT against PROJECT_DIR (the script `cd`s into PROJECT_DIR before the final
# write — a relative path taken after that cd would land in the wrong place).
# Use a throwaway PROJECT_DIR (never the real plugin root) so a regression
# here cannot write a stray file into this repo.
cat > "$TMP/codexbin/codex" <<'SH'
#!/usr/bin/env bash
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": []}\n```"}}
JSONL
exit 0
SH
chmod +x "$TMP/codexbin/codex"
FIX2_PROJECT="$TMP/fix2-project"; mkdir -p "$FIX2_PROJECT"
FIX2_CWD="$TMP/fix2-invocation-cwd"; mkdir -p "$FIX2_CWD"
RELOUT="relative-out.yaml"
( cd "$FIX2_CWD" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$TMP/codexbin:/usr/bin:/bin" \
    bash "$RUN" "$DOC" "$FIX2_PROJECT" "$RELOUT" )
rc=$?
[[ $rc -eq 0 ]] && ok "FIX2: relative-output-path run exits 0" || no "FIX2: exit $rc (expected 0)"
[[ -f "$FIX2_CWD/$RELOUT" ]] \
  && ok "FIX2: relative OUTPUT_PATH resolved against invocation cwd" \
  || no "FIX2: relative OUTPUT_PATH NOT written at invocation cwd"
[[ -f "$FIX2_PROJECT/$RELOUT" ]] \
  && no "FIX2: output ALSO/instead landed at PROJECT_DIR (should not)" \
  || ok "FIX2: output NOT mis-resolved against PROJECT_DIR"

abort_trigger_sleeping_codex "$TMP/abortbin"

# ── ABORT: 완료 전 중단이 조용히 지나가지 않는다 ─────────────────────────────
# 트리거는 SIGTERM 이다(shared/tests/abort_trigger.sh). 예전 트리거는
# 플러그인 루트 환경변수를 지워 `set -u` 를 위반시키는 것이었는데, 러너가 fallback 을
# 갖게 되면서 그 조건은 더 이상 중단을 일으키지 않는다 — 트리거를 안 바꾸면 이
# assertion 은 abort 를 한 번도 밟지 않은 채 다른 degrade 경로로 GREEN 이 된다.
#
# **종료 코드로 재지 않는 이유**: 이 스크립트의 계약은 "항상 exit 0 + 항상 YAML"이고,
# 게다가 bash 3.2.57은 abort 시 EXIT 트랩에 `$?`를 0으로 넘긴다 — 종료 코드로는
# abort와 정상 종료를 구별할 수 없다(2026-08-04 최소 재현). 그래서 **산출물**을 잰다.
#
# `reason:` 까지 단언하는 이유: `codex_failed: true` 만 보면 missing_result·
# no_agent_message 같은 평범한 degrade 로도 통과한다(2026-08-23 실측). 그러면 여기서
# 재려던 EXIT 트랩은 한 번도 안 돈다.
ABORTOUT="$TMP/abort-out.yaml"
rm -f "$ABORTOUT"
if run_until_aborted "$TMP/abortbin" "$RUN" "$DOC" "$FIX2_PROJECT" "$ABORTOUT"; then
  if [[ -s "$ABORTOUT" ]] && grep -q 'reason: *aborted_before_completion' "$ABORTOUT"; then
    ok "ABORT: 완료 전 중단이 aborted_before_completion 으로 표시된다"
  else
    no "ABORT: 중단이 abort 로 표시되지 않는다 (산출물: $(tr '\n' ' ' < "$ABORTOUT" 2>/dev/null || echo MISSING))"
  fi
else
  no "ABORT: timeout 바이너리 부재로 트리거를 못 돌렸다 — 이 계약은 이번 실행에서 미검증"
fi

# stale 재사용 — 더 나쁜 쪽. 이전 run의 결과가 살아남아 이번 라운드 판정으로 쓰이면
# 조용히 틀린 리뷰를 신뢰하게 된다. 시작 시 truncate가 이것을 막는다.
STALEOUT="$TMP/stale-out.yaml"
printf 'findings:\n  - {category: STALE_FROM_PREVIOUS_RUN}\n' > "$STALEOUT"
run_until_aborted "$TMP/abortbin" "$RUN" "$DOC" "$FIX2_PROJECT" "$STALEOUT"
grep -q 'STALE_FROM_PREVIOUS_RUN' "$STALEOUT" \
  && no "ABORT: 이전 run의 stale 산출물이 살아남아 이번 결과로 재사용된다" \
  || ok "ABORT: stale 산출물이 이번 run 결과로 재사용되지 않는다"

# ── FALLBACK: CLAUDE_PLUGIN_ROOT 부재에도 codex 에 도달한다 ───────────────────
# 이 러너는 스킬의 bash 블록에서 호출된다. 그 환경에 CLAUDE_PLUGIN_ROOT 는 없다
# (2.1.239 실측) — fallback 이 없으면 `set -u` 아래에서 codex 에 **도달하기 전에**
# 죽는다. 실패가 loud 하긴 해도 co-review 가 매 라운드 0회가 되므로, 이 러너의
# 존재 이유(별-계열 모델의 교차 검증)가 통째로 사라진다.
#
# **결과로 잰다.** "exit 0 + YAML 존재"는 고장난 러너도 만족한다 — degrade 계약이
# 정확히 그렇게 설계돼 있기 때문이다. 그 형태의 락은 이빨이 없다. 여기서는 mock
# codex 를 태워 `codex_failed: false` + 실제 finding 이 나오는지 본다.
# mutation 2축: (a) `:-` fallback 삭제 → RED  (b) fallback 경로 파손 → RED.
mkdir -p ""$TMP/fbbin""
cat > ""$TMP/fbbin"/codex" <<'SH'
#!/usr/bin/env bash
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": [{\"category\": \"fallback_probe\", \"target_section\": \"#fb\", \"severity\": \"high\", \"file\": \"x.py\", \"line\": 1, \"summary\": \"FB\", \"confidence\": 9}]}\n```"}}
JSONL
SH
chmod +x ""$TMP/fbbin"/codex"
FBOUT=""$TMP/fbbin"/../fallback-out.yaml"; rm -f "$FBOUT"
( unset CLAUDE_PLUGIN_ROOT; PATH=""$TMP/fbbin":$PATH" bash "$RUN" "$DOC" "$PLUGIN_ROOT" "$FBOUT" ) >/dev/null 2>&1
if grep -q 'codex_failed: false' "$FBOUT" 2>/dev/null && grep -q 'fallback_probe' "$FBOUT" 2>/dev/null; then
  ok "FALLBACK: env 부재에도 codex 에 도달해 finding 을 낸다"
else
  no "FALLBACK: env 부재에서 codex 에 도달하지 못했다 ($(tr '\n' ' ' < "$FBOUT" 2>/dev/null || echo MISSING))"
fi
grep -qE '^PLUGIN_ROOT="\$\{CLAUDE_PLUGIN_ROOT:-' "$RUN" \
  && ok "FALLBACK: 대입 라인에 fallback 이 있다" \
  || no "FALLBACK: 대입 라인에 fallback 이 없다 (`set -u` 에서 즉사)"
grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/' "$RUN" \
  && no "FALLBACK: fallback 을 우회하는 bare 참조가 남아 있다" \
  || ok "FALLBACK: bare 참조 잔여 없음"

finish
