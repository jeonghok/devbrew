#!/usr/bin/env bash
# T7/AC5/AC13d — codex artifact sub-pipeline: prompt build + JSONL extract + degrade.
set -u
SCRIPTS="$(cd "$(dirname "$0")/../scripts" && pwd)"
FIXTURES="$(cd "$(dirname "$0")/spike/fixtures" && pwd)"
BUILD="$SCRIPTS/build_artifact_codex_prompt.py"; EXTRACT="$SCRIPTS/extract_codex_artifact_yaml.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
tmp="$(mktemp -d)"

# build: artifact content embedded, rubric present, findings fence instruction
echo "# Design" > "$tmp/doc.md"; echo "Some claim without evidence." >> "$tmp/doc.md"
prompt="$(python3 "$BUILD" "$tmp/doc.md")"
echo "$prompt" | grep -q "Some claim without evidence" && ok "artifact content embedded" || no "content not embedded"
echo "$prompt" | grep -qi "read-only" && ok "read-only instruction present" || no "read-only missing"
echo "$prompt" | grep -q "findings:" && ok "findings schema instruction present" || no "findings schema missing"
# build refuses inline (path only) — nonexistent path -> nonzero
python3 "$BUILD" "$tmp/nope.md" >/dev/null 2>&1 && no "missing file should error" || ok "missing file errors (path-only)"

# extract: valid codex JSONL with a ```yaml fence -> findings
# REAL codex 0.130+ event shape (ground truth — see
# plugins/quality-gates/tests/spike/fixtures/codex_jsonl_sample.json and the
# sibling codex_findings_to_yaml.py's extract_last_agent_message): events are
# {"type":"item.completed","item":{"type":"agent_message","text":"..."}}.
# The invented {"msg":{"type":"agent_message","message":...}} shape used here
# previously exists nowhere in real codex output — fixed to reality.
cat > "$tmp/valid.jsonl" <<'J'
{"type":"item.completed","item":{"type":"agent_message","text":"Here you go:\n```yaml\nfindings:\n  - {agent: x, category: evidence, target_anchor: \"#design\", severity: IMPORTANT, summary: unsupported}\n```\n"}}
J
out="$(python3 "$EXTRACT" < "$tmp/valid.jsonl")"
echo "$out" | grep -q "agent: codex-reviewer" && echo "$out" | grep -q "category: evidence" \
  && ok "extract parses fenced findings + relabels agent (REAL item.completed/agent_message shape)" || no "extract failed ($out)"

# ground-truth regression: extract_text() must pull the agent-message TEXT out
# of the REAL captured codex --json stream fixture (Task 0 spike). That
# fixture's codex answer is a JSON-findings block for the CODE-review path
# (not the artifact-critique yaml findings schema), so this asserts only that
# the real event shape is recognized and its text is extracted — not that the
# full yaml-findings pipeline succeeds against it.
out="$(python3 -c "
import sys
sys.path.insert(0, '$SCRIPTS')
import extract_codex_artifact_yaml as m
with open('$FIXTURES/codex_jsonl_sample.json') as f:
    text = f.read()
result = m.extract_text(text)
sys.stdout.write(result if result else '')
")"
echo "$out" | grep -q "lookup() does not validate idx is within range" \
  && ok "extract_text() pulls agent-message text from REAL codex_jsonl_sample.json (item.completed/agent_message shape)" \
  || no "extract_text failed against real fixture (got: ${out:0:120})"

# anti-injection (AC9(b) parity with codex_findings_to_yaml.py): the artifact-
# critique prompt embeds UNTRUSTED artifact content, and codex may quote/echo
# an earlier injected fence before its real answer. The extractor must pick
# the LAST fenced yaml block, defeating a decoy block that appears first.
cat > "$tmp/injected.jsonl" <<'J'
{"type":"item.completed","item":{"type":"agent_message","text":"Decoy echoed from injected artifact content:\n```yaml\nfindings:\n  - {agent: x, category: evidence, target_anchor: \"#design\", severity: IMPORTANT, summary: INJECTED}\n```\nMy real analysis:\n```yaml\nfindings:\n  - {agent: x, category: evidence, target_anchor: \"#design\", severity: IMPORTANT, summary: REAL}\n```\n"}}
J
out="$(python3 "$EXTRACT" < "$tmp/injected.jsonl")"
echo "$out" | grep -q "summary: REAL" && ! echo "$out" | grep -q "summary: INJECTED" \
  && ok "extract picks LAST fenced block, defeating an earlier injected decoy" \
  || no "anti-injection failed — picked wrong fence ($out)"

# extract degrade: nonzero exit override -> codex_failed. Uses the VALID jsonl
# fixture (which extracts cleanly on its own) rather than empty stdin, so this
# assertion actually has mutation teeth on the override branch: empty stdin
# would degrade anyway via the unrelated no_agent_message path and mask a
# deleted/broken override branch (found during Step 5 mutation testing).
out="$(python3 "$EXTRACT" --meta-override-exit-code 1 --meta-override-reason exit_nonzero < "$tmp/valid.jsonl")"
echo "$out" | grep -q "codex_failed: true" && ok "exit override -> codex_failed" || no "exit override degrade ($out)"
# extract degrade: garbage stdin -> codex_failed
out="$(echo "not json at all" | python3 "$EXTRACT")"
echo "$out" | grep -q "codex_failed: true" && ok "garbage stdin -> codex_failed" || no "garbage degrade ($out)"

# run wrapper: missing project_dir -> degrade meta in OUT (no crash)
#
# 〔2026-08-21 PR6 리뷰 L3〕 단언은 `codex_failed: true` 가 아니라 **`reason:` 을
# 구별**한다. 이 러너의 degrade 사유는 여섯이고(`missing_args` ·
# `project_dir_unreachable` · `scratch_uncreatable` · `prompt_build_failed` ·
# `extract_failed` · `aborted_before_completion`) `codex_failed: true` 는 그 전부를
# 만족한다 — 즉 그 문자열만 보는 단언은 **어느 경로를 탔는지 재지 않는다**. 형제
# `test_codex_runner_degrade_contract.sh:90` 이 degrade 고유 문구를 단언해 빌더가
# ImportError 로 죽으면 RED 가 되게 한 것과 같은 판별력을 여기에도 준다.
if [ -f "$SCRIPTS/run_artifact_codex_reviewer.sh" ]; then
  CLAUDE_PLUGIN_ROOT="$(cd "$SCRIPTS/.." && pwd)" bash "$SCRIPTS/run_artifact_codex_reviewer.sh" "$tmp/doc.md" "" "$tmp/out.yaml" >/dev/null 2>&1
  { grep -q "codex_failed: true" "$tmp/out.yaml" && grep -q "^reason: missing_args$" "$tmp/out.yaml"; } 2>/dev/null \
    && ok "run wrapper degrades on missing project_dir (reason: missing_args)" \
    || no "run wrapper degrade — missing_args 를 사유로 밝혀야 한다 ($(cat "$tmp/out.yaml" 2>/dev/null))"
else
  no "run_artifact_codex_reviewer.sh missing"
fi

# F-D: the TERMINAL extract must be guarded like the prompt build -- an extract
# crash that truncates OUT to empty must yield codex_failed (a dropped reviewer,
# not a silent codex-succeeded-with-no-findings). Stub codex on PATH (so the real
# one never runs) + a broken extract that exits nonzero writing nothing; the guard
# must convert that empty OUT into codex_failed. Mutation proof: reverting the
# wrapper's `if ! ... || [ ! -s "$OUT" ]; then emit_fail` to the bare
# `python3 extract > "$OUT"` leaves OUT empty -> RED.
if [ -f "$SCRIPTS/run_artifact_codex_reviewer.sh" ]; then
  stub="$(mktemp -d)"; mkdir -p "$stub/scripts" "$stub/bin"
  cp "$BUILD" "$stub/scripts/build_artifact_codex_prompt.py"
  # 빌더의 형제 import(stdout 가드 + P21 로더). 빠지면 빌더가 ImportError 로 죽어
  # 아래 판정이 추출기 실패가 아니라 빌드 실패를 재게 된다.
  cp "$SCRIPTS/codex_prompt_common.py" "$stub/scripts/codex_prompt_common.py"
  cp "$SCRIPTS/prompt-preamble.md" "$stub/scripts/prompt-preamble.md"
  printf '#!/usr/bin/env python3\nimport sys\nsys.exit(3)\n' > "$stub/scripts/extract_codex_artifact_yaml.py"
  printf '#!/bin/sh\nexit 0\n' > "$stub/bin/codex"; chmod +x "$stub/bin/codex"
  echo "# artifact" > "$stub/art.md"
  PATH="$stub/bin:$PATH" CLAUDE_PLUGIN_ROOT="$stub" \
    bash "$SCRIPTS/run_artifact_codex_reviewer.sh" "$stub/art.md" "$stub" "$stub/out.yaml" >/dev/null 2>&1
  # `reason: extract_failed` 를 단언한다 — `codex_failed: true` 만 보면 스텁이 빌더의
  # 형제 의존을 하나 놓쳤을 때(이번 라운드에 `codex_prompt_common.py` ·
  # `prompt-preamble.md` 가 정확히 그랬다) 빌드가 먼저 죽어 `prompt_build_failed` 가
  # 나오는데도 이 판정이 GREEN 으로 남는다. 그러면 여기서 재려던 추출기 가드는
  # **한 번도 안 돈다.** 실측: 위 두 `cp` 를 빼면 OUT 은 `reason: prompt_build_failed`.
  { [ -s "$stub/out.yaml" ] && grep -q "codex_failed: true" "$stub/out.yaml" \
      && grep -q "^reason: extract_failed$" "$stub/out.yaml"; } \
    && ok "terminal extract guarded: crash -> reason: extract_failed, OUT never empty (F-D)" \
    || no "extract crash must yield reason: extract_failed, not empty OUT nor another degrade path ($(cat "$stub/out.yaml" 2>/dev/null))"
  rm -rf "$stub"

  # F-D/iter2: the `[ ! -s "$OUT" ]` sub-clause specifically -- an extractor that
  # exits 0 but writes NOTHING (empty OUT) must ALSO yield codex_failed. Mutation
  # proof: deleting just `|| [ ! -s "$OUT" ]` leaves THIS case RED (exit 0 -> the
  # `if !` clause is false -> OUT stays empty, un-degraded). The earlier F-D stub
  # exits nonzero so it can't exercise this branch (codex iter-2 finding).
  stub2="$(mktemp -d)"; mkdir -p "$stub2/scripts" "$stub2/bin"
  cp "$BUILD" "$stub2/scripts/build_artifact_codex_prompt.py"
  cp "$SCRIPTS/codex_prompt_common.py" "$stub2/scripts/codex_prompt_common.py"
  cp "$SCRIPTS/prompt-preamble.md" "$stub2/scripts/prompt-preamble.md"
  printf '#!/usr/bin/env python3\nimport sys\nsys.exit(0)\n' > "$stub2/scripts/extract_codex_artifact_yaml.py"
  printf '#!/bin/sh\nexit 0\n' > "$stub2/bin/codex"; chmod +x "$stub2/bin/codex"
  echo "# artifact" > "$stub2/art.md"
  PATH="$stub2/bin:$PATH" CLAUDE_PLUGIN_ROOT="$stub2" \
    bash "$SCRIPTS/run_artifact_codex_reviewer.sh" "$stub2/art.md" "$stub2" "$stub2/out.yaml" >/dev/null 2>&1
  { [ -s "$stub2/out.yaml" ] && grep -q "codex_failed: true" "$stub2/out.yaml" \
      && grep -q "^reason: extract_failed$" "$stub2/out.yaml"; } \
    && ok "terminal extract: exit-0-but-empty OUT -> reason: extract_failed (F-D [ ! -s ] branch)" \
    || no "exit-0 empty extract must yield reason: extract_failed ($(cat "$stub2/out.yaml" 2>/dev/null))"
  rm -rf "$stub2"
fi


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
mkdir -p ""$tmp/fbbin""
cat > ""$tmp/fbbin"/codex" <<'SH'
#!/usr/bin/env bash
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```yaml\nfindings:\n  - category: fallback_probe\n    severity: high\n    summary: FB\n```"}}
JSONL
SH
chmod +x ""$tmp/fbbin"/codex"
FBOUT=""$tmp/fbbin"/../fallback-out.yaml"; rm -f "$FBOUT"
( unset CLAUDE_PLUGIN_ROOT; PATH=""$tmp/fbbin":$PATH" bash "$SCRIPTS/run_artifact_codex_reviewer.sh" "$tmp/doc.md" "$tmp" "$FBOUT" ) >/dev/null 2>&1
if grep -q 'codex_failed: false' "$FBOUT" 2>/dev/null && grep -q 'fallback_probe' "$FBOUT" 2>/dev/null; then
  ok "FALLBACK: env 부재에도 codex 에 도달해 finding 을 낸다"
else
  no "FALLBACK: env 부재에서 codex 에 도달하지 못했다 ($(tr '\n' ' ' < "$FBOUT" 2>/dev/null || echo MISSING))"
fi
grep -qE '^PLUGIN_ROOT="\$\{CLAUDE_PLUGIN_ROOT:-' "$SCRIPTS/run_artifact_codex_reviewer.sh" \
  && ok "FALLBACK: 대입 라인에 fallback 이 있다" \
  || no "FALLBACK: 대입 라인에 fallback 이 없다 (`set -u` 에서 즉사)"
grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/' "$SCRIPTS/run_artifact_codex_reviewer.sh" \
  && no "FALLBACK: fallback 을 우회하는 bare 참조가 남아 있다" \
  || ok "FALLBACK: bare 참조 잔여 없음"

rm -rf "$tmp"
finish
