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
ln -s "$PLUGIN_ROOT/scripts/build_spec_codex_prompt.py" "$FAKE_ROOT/scripts/build_spec_codex_prompt.py"
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

# ── ABORT: 완료 전 중단이 조용히 지나가지 않는다 ─────────────────────────────
# 트리거는 CLAUDE_PLUGIN_ROOT 미설정(`set -u` 위반) — 이 세션에서 실제로 밟은 조건.
#
# **종료 코드로 재지 않는 이유**: 이 스크립트의 계약은 "항상 exit 0 + 항상 YAML"이고,
# 게다가 bash 3.2.57은 `set -u` abort 시 EXIT 트랩에 `$?`를 0으로 넘긴다 — 종료
# 코드로는 abort와 정상 종료를 구별할 수 없다(2026-08-04 최소 재현). 계약도 플랫폼도
# 종료 코드를 신호로 쓸 수 없게 만든다. 그래서 **산출물**을 잰다.
ABORTOUT="$TMP/abort-out.yaml"
rm -f "$ABORTOUT"
( unset CLAUDE_PLUGIN_ROOT; bash "$RUN" "$DOC" "$FIX2_PROJECT" "$ABORTOUT" ) >/dev/null 2>&1
if [[ -s "$ABORTOUT" ]] && grep -q 'codex_failed: *true' "$ABORTOUT"; then
  ok "ABORT: 완료 전 중단이 codex_failed YAML로 표시된다 (부재 아님)"
else
  no "ABORT: 중단 후 산출물이 없거나 실패 표시가 없다 — 호출자가 읽을 것이 없다"
fi

# stale 재사용 — 더 나쁜 쪽. 이전 run의 결과가 살아남아 이번 라운드 판정으로 쓰이면
# 조용히 틀린 리뷰를 신뢰하게 된다. 시작 시 truncate가 이것을 막는다.
STALEOUT="$TMP/stale-out.yaml"
printf 'findings:\n  - {category: STALE_FROM_PREVIOUS_RUN}\n' > "$STALEOUT"
( unset CLAUDE_PLUGIN_ROOT; bash "$RUN" "$DOC" "$FIX2_PROJECT" "$STALEOUT" ) >/dev/null 2>&1
grep -q 'STALE_FROM_PREVIOUS_RUN' "$STALEOUT" \
  && no "ABORT: 이전 run의 stale 산출물이 살아남아 이번 결과로 재사용된다" \
  || ok "ABORT: stale 산출물이 이번 run 결과로 재사용되지 않는다"
finish
