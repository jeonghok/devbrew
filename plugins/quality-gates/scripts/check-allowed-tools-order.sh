#!/usr/bin/env bash
# v1.32.3 I-D: SKILL.md allowed-tools pipeline-order linter.
# Canonical source: 이 스크립트 내부 EXPECTED_ORDER 배열 (single source of truth).
# SKILL.md의 `# Group N — ...` 주석은 *문서화*이지 canonical 아님.
# Drift 감지 시 SKILL.md를 이 linter에 맞춰 수정.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/quality-gates/skills/quality-pipeline/SKILL.md"

EXPECTED_ORDER=(
  # Group 1 — Preflight scripts
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh:*)'
  # Group 2 — Review gate scripts
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_findings.py:*)'
  # Group 3 — Runtime gate scripts
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect_codex.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/compute-test-scope-candidates.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/resolve-baseline.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check_qa_ledger.py:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh:*)'
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/render-terminal.py:*)'
  # 비-플러그인 명령 중 **항목을 가진 유일한 것** — R-init 의 중간 파일 디렉토리 (AC69).
  # SKILL 의 fenced 블록은 항목 없는 맨 셸 유틸리티도 여럿 실행하며(개수는 여기 적지
  # 않는다 — 복제된 census 는 편집마다 어긋난다, §11 ㉜·㊱), 그것들이 항목을 필요로
  # 하는지는 미측정이다. 이 배열은 **항목만** 잠근다: 이 주석의 주장을 잠그는 것은
  # 아무것도 없고, 같은 문장이 SKILL frontmatter·CHANGELOG·설계 §11 에도 복제돼 있다
  # (그 생성기 자체가 §11 ㊱ 로 등재됨).
  'Bash(mktemp:*)'
  # Group 4 — Meta
  'Agent'
  'AskUserQuestion'
  # Group 5 — File operations
  'Read'
  'Glob'
  'Grep'
  'Edit'
  'Write'
)

# Extract allowed-tools list from SKILL.md frontmatter (between first two `---`
# markers). 각 줄에서 `  - <item>` 패턴 추출. 주석 라인(`  # ...`)은 skip.
# mapfile 대신 portable read loop (bash 3.2 호환, macOS 기본 shell).
ACTUAL=()
while IFS= read -r line; do
  ACTUAL+=("$line")
done < <(
  awk '
    /^---$/ { d++; next }
    d == 1 && /^[[:space:]]*-[[:space:]]/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "")
      print
    }
  ' "$SKILL"
)

if [[ "${#ACTUAL[@]}" -ne "${#EXPECTED_ORDER[@]}" ]]; then
  echo "check-allowed-tools-order: tool count mismatch — expected ${#EXPECTED_ORDER[@]}, found ${#ACTUAL[@]}" >&2
  exit 1
fi

fail=0
for i in "${!EXPECTED_ORDER[@]}"; do
  if [[ "${ACTUAL[$i]}" != "${EXPECTED_ORDER[$i]}" ]]; then
    echo "check-allowed-tools-order: position $i: expected '${EXPECTED_ORDER[$i]}', found '${ACTUAL[$i]}'" >&2
    fail=$((fail + 1))
  fi
done

# Defense-in-depth: actual item이 expected set에 없으면 unknown tool.
for actual_item in "${ACTUAL[@]}"; do
  found=0
  for exp in "${EXPECTED_ORDER[@]}"; do
    if [[ "$actual_item" == "$exp" ]]; then
      found=1; break
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    echo "check-allowed-tools-order: unexpected tool: $actual_item" >&2
    fail=$((fail + 1))
  fi
done

if [[ "$fail" -eq 0 ]]; then
  echo "check-allowed-tools-order: OK (${#EXPECTED_ORDER[@]} tools in canonical order)"
  exit 0
else
  echo "check-allowed-tools-order: $fail issue(s) — update SKILL.md to match linter EXPECTED_ORDER" >&2
  exit 1
fi
