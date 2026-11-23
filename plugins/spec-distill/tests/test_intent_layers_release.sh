#!/usr/bin/env bash
# guards: plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/quality-gates/CHANGELOG.md plugins/spec-distill/README.md plugins/quality-gates/README.md
# 다섯 층 재편의 판 · 변경 기록 · README 락 — 현재 판의 변경 기록 절이 새 글자와 옛 기록 읽기를 적는다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_intent_layers_release.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/.claude-plugin/plugin.json \
    plugins/spec-distill/CHANGELOG.md plugins/quality-gates/CHANGELOG.md plugins/spec-distill/README.md plugins/quality-gates/README.md
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
cd "$ROOT" || exit 1
has() {    # has <파일> <리터럴>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$1: 「$2」"; else no "$1: 「$2」 가 없다"; fi
}
SD_VER=$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["version"])' plugins/spec-distill/.claude-plugin/plugin.json)
QG_VER=$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["version"])' plugins/quality-gates/.claude-plugin/plugin.json)
sd_sec=$(awk -v v="$SD_VER" 'index($0,"## ["v"]")==1{f=1;print;next} f&&/^## \[/{exit} f' plugins/spec-distill/CHANGELOG.md)
qg_sec=$(awk -v v="$QG_VER" 'index($0,"## ["v"]")==1{f=1;print;next} f&&/^## \[/{exit} f' plugins/quality-gates/CHANGELOG.md)
[ -n "$sd_sec" ] && ok "spec-distill 변경 기록에 현재 판 절이 있다" || no "spec-distill 변경 기록에 현재 판 절이 없다"
[ -n "$qg_sec" ] && ok "quality-gates 변경 기록에 현재 판 절이 있다" || no "quality-gates 변경 기록에 현재 판 절이 없다"
printf '%s' "$sd_sec" | grep -q 'intent_dir' && ok "spec-distill 변경 기록: 새 설정 키" || no "spec-distill 변경 기록에 새 설정 키가 없다"
printf '%s' "$sd_sec" | grep -q '옛 기록' && ok "spec-distill 변경 기록: 옛 기록 읽기" || no "spec-distill 변경 기록이 옛 기록을 그대로 읽는다는 것을 적지 않았다"
printf '%s' "$sd_sec" | grep -q 'context-state:' && ok "spec-distill 변경 기록: 판결 글자" || no "spec-distill 변경 기록이 판결 글자 변경을 적지 않았다"
printf '%s' "$qg_sec" | grep -q 'source_intent' && ok "quality-gates 변경 기록: source_intent" || no "quality-gates 변경 기록에 source_intent 가 없다"
has plugins/spec-distill/README.md 'docs/superpowers/intent/'
has plugins/quality-gates/README.md 'source_intent,source_interview,roadmap,source_brief,type=roadmap,type=epic-bundle'
finish
