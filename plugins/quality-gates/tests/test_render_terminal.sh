#!/usr/bin/env bash
# test_render_terminal.sh — coverage for scripts/render-terminal.py `table` (the Final verdict STATUS table).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/render-terminal.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

case_table_aligned() {
  local out
  out=$(printf 'target\tPR #123\nidentity\toctocat (id 583231)\n' \
        | python3 "$SCRIPT" table --title "Status")
  # every value column must start at the same offset (aligned, not prose)
  local c1 c2
  c1=$(printf '%s\n' "$out" | grep -n 'PR #123' | head -1 | sed 's/.*://' | awk '{print index($0,"PR")}')
  c2=$(printf '%s\n' "$out" | grep -n 'octocat' | head -1 | sed 's/.*://' | awk '{print index($0,"octocat")}')
  if [[ -n "$c1" && "$c1" == "$c2" ]]; then ok "STATUS columns aligned (offset $c1)"; else no "table not aligned ($c1 vs $c2)"; fi
}

case_table_aligned
# 소비자 배선 — quality-pipeline SKILL 이 render-terminal 을 allowed-tools 에 두고, `## Final verdict` 절(펜스 밖 헤딩만
# 절 경계로 센다)이 `table` 을 부른다. 헤딩부터 EOF 까지 읽으면 뒤따르는 `## Publish` 가 만족시킬 수 있어 절 창으로 잰다.
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
AT="$(awk '/^allowed-tools:/{f=1} f{print} f&&/^---[[:space:]]*$/{exit}' "$SKILL")"
grep -qF 'render-terminal.py' <<<"$AT" \
  && ok "render-terminal.py wired into allowed-tools" \
  || no "render-terminal.py missing from allowed-tools"
FV="$(awk '/^```/{inf=!inf} !inf && /^## /{f=($0=="## Final verdict")} f' "$SKILL")"
if grep -qF 'render-terminal.py" table' <<<"$FV"; then
  ok "Final verdict uses render-terminal.py table"
else
  no "Final verdict does not call render-terminal.py table"
fi
finish
