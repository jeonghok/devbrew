#!/usr/bin/env bash
# T7/AC5/AC13d — codex artifact sub-pipeline: prompt build + JSONL extract + degrade.
set -u
SCRIPTS="$(cd "$(dirname "$0")/../scripts" && pwd)"
BUILD="$SCRIPTS/build_artifact_codex_prompt.py"; EXTRACT="$SCRIPTS/extract_codex_artifact_yaml.py"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
no() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }
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
cat > "$tmp/valid.jsonl" <<'J'
{"msg":{"type":"agent_message","message":"Here you go:\n```yaml\nfindings:\n  - {agent: x, category: evidence, target_anchor: \"#design\", severity: IMPORTANT, summary: unsupported}\n```\n"}}
J
out="$(python3 "$EXTRACT" < "$tmp/valid.jsonl")"
echo "$out" | grep -q "agent: codex-reviewer" && echo "$out" | grep -q "category: evidence" \
  && ok "extract parses fenced findings + relabels agent" || no "extract failed ($out)"

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
if [ -f "$SCRIPTS/run_artifact_codex_reviewer.sh" ]; then
  CLAUDE_PLUGIN_ROOT="$(cd "$SCRIPTS/.." && pwd)" bash "$SCRIPTS/run_artifact_codex_reviewer.sh" "$tmp/doc.md" "" "$tmp/out.yaml" >/dev/null 2>&1
  grep -q "codex_failed: true" "$tmp/out.yaml" 2>/dev/null && ok "run wrapper degrades on missing project_dir" || no "run wrapper degrade"
else
  no "run_artifact_codex_reviewer.sh missing"
fi

rm -rf "$tmp"
echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
