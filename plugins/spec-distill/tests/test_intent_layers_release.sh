#!/usr/bin/env bash
# guards: plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/quality-gates/CHANGELOG.md plugins/spec-distill/README.md plugins/quality-gates/README.md
# 다섯 층 재편의 판 · 변경 기록 · README 락 — 변경 기록의 한 절이 새 글자와 옛 기록 읽기를 적는다.
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
# 버전과 무관하게 찾는다 — 내용은 한 번 나간 판의 절에 산다. 다음 판 절이 위에 얹혀도 깨지지 않는다.
sec_has() {    # sec_has <변경기록> <리터럴>... — 한 `## [판]` 절 안에 리터럴이 모두 있는지
  f=$1; shift
  python3 -I -c '
import re,sys
t=open(sys.argv[1],encoding="utf-8").read()
secs=re.split(r"(?m)^(?=## \[)",t)
sys.exit(0 if any(s.startswith("## [") and all(n in s for n in sys.argv[2:]) for s in secs) else 1)
' "$f" "$@"
}
sec_has plugins/spec-distill/CHANGELOG.md 'intent_dir' '옛 기록' 'context-state:' \
  && ok "spec-distill 변경 기록: 한 절이 새 설정 키 · 옛 기록 읽기 · 판결 글자를 적는다" \
  || no "spec-distill 변경 기록에 새 설정 키 · 옛 기록 읽기 · 판결 글자를 함께 적은 절이 없다"
sec_has plugins/quality-gates/CHANGELOG.md 'source_intent' \
  && ok "quality-gates 변경 기록: source_intent" || no "quality-gates 변경 기록에 source_intent 를 적은 절이 없다"
has plugins/spec-distill/README.md 'docs/superpowers/intent/'
has plugins/quality-gates/README.md 'source_intent,source_interview,roadmap,source_brief,type=roadmap,type=epic-bundle'
finish
