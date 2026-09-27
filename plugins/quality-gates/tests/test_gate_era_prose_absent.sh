#!/usr/bin/env bash
# guards: plugins/quality-gates/*.md plugins/quality-gates/.claude-plugin/plugin.json
# test_gate_era_prose_absent.sh — 한 파이프라인 뒤 옛 게이트 시대 문구의 부재 (설계 §6.5.3 · §16 범위 기록).
#
# `Review gate` · `Runtime gate` · `2-gate`/`two-gate` 는 게이트가 둘이던 시절의 이름이다 — 한 파이프라인
# 뒤에 남으면 산문이 없는 게이트를 가리킨다. 코퍼스는 qg 의 산문 전체(추적되는 *.md 와 plugin.json)이고
# tests/ · CHANGELOG.md 는 이력이라 뺀다. 음의 락이라 양의 짝을 둔다 — 코퍼스 하한 · 고친 자리의 새 문구.
# `Review` · `Runtime` 의 첫 글자는 대문자로 잰다 — 소문자 `hard-review gate`(SKILL 의 제거 이력 한 줄)는
# 다른 말이다. `Gate`/`gate`, `-`/공백, 복수형 `gates` 는 모두 잡는다(모의 실행이 `Runtime Gate` ·
# `Two-gate` · `2 gates` 생존을 실측했다).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
corpus() {
  (cd "$ROOT" && git ls-files -- 'plugins/quality-gates/*.md' 'plugins/quality-gates/.claude-plugin/plugin.json' \
    | grep -v -E '^plugins/quality-gates/(tests/|CHANGELOG\.md$)')
}
[ "${1:-}" = "--emit-scanned" ] && { corpus; exit 0; }
. "$ROOT/shared/tests/assert.sh"
QG="$ROOT/plugins/quality-gates"

case_gate_era_tokens_absent() {
  local files n f hit bad=0
  files=$(corpus)
  n=$(printf '%s\n' "$files" | grep -c .)
  if [ "$n" -ge 15 ]; then
    ok "코퍼스 ${n}개(qg 의 *.md · plugin.json, tests · CHANGELOG 제외 — 하한 15)"
  else
    no "코퍼스가 ${n}개뿐이다(하한 15) — 도출이 무너졌다"
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    hit=$(grep -n -E '(Review|Runtime)[ -][Gg]ates?|(^|[^A-Za-z0-9])([Tt]wo|2)[- ][Gg]ates?' -- "$ROOT/$f" | head -3 | tr '\n' ' ')
    if [ -n "$hit" ]; then bad=$((bad+1)); no "$f 에 옛 게이트 문구가 남았다: $hit"; fi
  done <<EOF
$files
EOF
  [ "$bad" -eq 0 ] && ok "qg 산문에 Review gate · Runtime gate · 2-gate 가 없다"
}

case_new_wording_present() {
  assert_file_grep "$QG/agents/security-reviewer.md" '^description: Phase 1 of the qg review pipeline — always-run code-level security review' \
    "security-reviewer 설명이 한 파이프라인의 Phase 1 을 이름 붙인다"
  assert_file_grep "$QG/agents/security-reviewer.md" 'the code-level security specialist for review pipeline Phase 1\.' \
    "security-reviewer 역할 문장이 한 파이프라인의 Phase 1 을 이름 붙인다"
  assert_file_grep "$QG/agents/pr-understanding-builder.md" "qg's review pipeline \(\`/qg\`\) and the publish orchestrator" \
    "pr-understanding-builder 가 판정을 한 파이프라인의 몫으로 넘긴다"
  assert_file_grep "$QG/skills/publishing-pr-understanding/SKILL.md" '^리뷰 파이프라인의 몫\), artifact' \
    "publishing SKILL 이 판정을 /qg 리뷰 파이프라인의 몫으로 넘긴다"
  assert_file_grep "$QG/skills/critiquing-artifacts/SKILL.md" '^  /qg pipeline \(one pipeline, one verdict\)\.$' \
    "critiquing SKILL 이 코드 대상을 한 파이프라인으로 보낸다"
}

for c in case_gate_era_tokens_absent case_new_wording_present; do
  "$c"
done
finish
