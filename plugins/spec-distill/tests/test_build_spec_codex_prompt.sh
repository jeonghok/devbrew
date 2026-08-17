#!/usr/bin/env bash
# AC3 + AC4 — 6 judgment categories + structured emit request + path-only input.
set -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD="$PLUGIN_ROOT/scripts/build_spec_codex_prompt.py"
TMP="$(mktemp -d -t sd-build-prompt-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
DOC="$TMP/some-design.md"
printf '# X design\n\n## 2. Goals\nMake it robust.\n' > "$DOC"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

OUT="$(python3 "$BUILD" "$DOC")"

# AC3: all 6 judgment categories present in the prompt
for c in placeholder ambiguity scope_creep approaches_comparison isolation testing; do
  echo "$OUT" | grep -q "$c" && ok "category $c present" || no "category $c missing"
done

# AC3: severity vocab is spec-distill {block,high,medium}, NOT qg vocab
echo "$OUT" | grep -qE 'block[^A-Za-z]*\|?[^A-Za-z]*high[^A-Za-z]*\|?[^A-Za-z]*medium' \
  && ok "severity vocab block|high|medium" || no "severity vocab wrong"
echo "$OUT" | grep -qE 'CRITICAL|IMPORTANT|SUGGESTION' \
  && no "qg vocab leaked (CRITICAL/IMPORTANT/SUGGESTION)" || ok "no qg vocab"

# AC3: each finding requests category + target_section
echo "$OUT" | grep -q 'category' && echo "$OUT" | grep -q 'target_section' \
  && ok "requests category + target_section" || no "missing category/target_section request"

# AC3: doc content is embedded (path was read, not ignored)
echo "$OUT" | grep -q 'Make it robust' && ok "doc content embedded" || no "doc content not embedded"

# AC4: path-only — passing inline content as argv must NOT be treated as a doc.
# The script takes exactly one arg (a path); inline string that isn't a file → error.
python3 "$BUILD" '# inline content ## 2. Goals not a path' >/dev/null 2>&1 \
  && no "AC4: inline content accepted (should require a file path)" \
  || ok "AC4: inline non-path rejected"

# handoff_incomplete is OUT of codex scope (mechanical check) — must NOT be requested.
echo "$OUT" | grep -q 'handoff_incomplete' \
  && no "handoff_incomplete wrongly in codex scope" || ok "handoff_incomplete excluded"

# AC16 (Task 7) — the six categories are a starting vocabulary, not a closed
# list: a real defect that fits none of the six names must have somewhere to
# go (the `other` escape hatch), or it is discarded before merge/dedup ever
# sees it.
echo "$OUT" | grep -qF 'SIX judgment categories only' \
  && no "AC16: 범주가 6개로 닫혀 있다 — 리스트에 없는 진짜 결함이 버려진다" \
  || ok "AC16: 범주 폐쇄 문구 없음"
echo "$OUT" | grep -qE '^- other:' \
  && ok "AC16: other 범주가 프롬프트에 실린다" \
  || no "AC16: other 범주 부재"

# AC16b (fix round 1) — prose alone is not enough. The JSON output-format
# block's `"category":` schema hint is the OUTPUT CONTRACT: when prose and a
# schema disagree, a model writing structured output follows the schema. If
# the hint still enumerates only the six names, a reviewer is told in prose
# to use `other` freely and told by the contract that `other` is not a
# permitted value — the exact drop this task exists to prevent, just moved
# one layer down. Anchored on the `"category":` line specifically (occurs
# exactly once in the rendered output — verified) rather than a whole-output
# grep for the bare word `other`, which is common in prose (line 44's bullet
# itself, "or other unfinished text" at line 33) and would pass on the prose
# alone even if the contract still enumerates six.
echo "$OUT" | grep -qE '"category":[^"]*"[^"]*\bother\b[^"]*"' \
  && ok "AC16b: category 스키마 힌트(contract)에 other 포함" \
  || no "AC16b: category 스키마 힌트가 여전히 6개로 닫혀 있다 — prose와 contract가 모순"
finish
