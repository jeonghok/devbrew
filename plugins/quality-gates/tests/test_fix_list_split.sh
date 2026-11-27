#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md
# test_fix_list_split.sh — 고칠 목록을 막는 지적과 제안으로 가르는 규칙(설계 §7 · AC23).
#
# SKILL Step 4.5 의 「고칠 목록」 에서 `### 막는 지적` 은 CRITICAL · IMPORTANT 행을, `### 제안` 은 재비판이 낮춘
# `(lowered)` 행을 포함한 SUGGESTION 행을 받는다. 낱말이 「있다」 만 재면 다른 절로 옮기거나 뒤에 부정을 붙여도
# 통과하므로, 각 절의 규칙 줄을 따로 뽑아 줄 전체를 견준다.
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' plugins/quality-gates/skills/quality-pipeline/SKILL.md; exit 0; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"

S45="$(awk '$0 == "### Step 4.5 — Surface the verdict" {f=1; next} f && /^#{2,3} /{exit} f' "$SKILL")"
[ -n "$S45" ] && ok "Step 4.5 창을 찾았다" || no "Step 4.5 창이 없다 — 아래가 공허하다"
BLOCK="$(printf '%s\n' "$S45" | grep '^- `### 막는 지적` — ')"
SUGG="$(printf '%s\n' "$S45" | grep '^- `### 제안` — ')"
assert_eq "$(printf '%s\n' "$BLOCK" | grep -c .)" "1" "막는 지적 규칙 줄이 하나다"
assert_eq "$(printf '%s\n' "$SUGG" | grep -c .)" "1" "제안 규칙 줄이 하나다"

assert_eq "$BLOCK" '- `### 막는 지적` — `$RV/synth.out` 의 지적 표에서 심각도가 CRITICAL · IMPORTANT 인 행. 한 줄에 하나: `- <심각도> <파일>:<줄> — <내용> · 고칠 방법: <**고칠 방법:** 목록의 같은 #k 줄의 글>`.' \
  "막는 지적은 CRITICAL · IMPORTANT 행을 받는다(줄 전체)"
assert_eq "$SUGG" '- `### 제안` — 같은 표의 SUGGESTION 행(재비판이 낮춘 `(lowered)` 행 포함). 줄 꼴은 위와 같다.' \
  "제안은 재비판이 낮춘 (lowered) 행을 포함한 SUGGESTION 행을 받는다(줄 전체)"
finish
