#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/check_seed.py
#
# **한 문장뿐인 seed 가 통과해야 한다.**
#
# 이 락이 재는 것은 기능이 아니라 **금지**다 — `check_seed.py` 에 seed 본문의 «존재
# 검사»를 추가하면 RED 가 난다. 그것이 이 게이트가 양식으로 변질되는 유일한 경로이고,
# 산문으로 적어 둔 금지는 다음 편집자가 「합리적인 추가」로 지나간다.
#
# 픽스처는 헤딩 0 · 필드 0 · 절 0 · 태그 0 · URL 0 인 **한 문장**이다. 어떤 슬롯 존재
# 검사가 들어와도 이 픽스처는 그것을 만족시킬 수 없다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
CHECK="$ROOT/plugins/spec-distill/scripts/check_seed.py"
FIX="$ROOT/plugins/spec-distill/tests/fixtures"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/check_seed.py"
  exit 0
fi

[ -f "$CHECK" ] || { no "check_seed.py 부재"; finish; exit $?; }

PYTHONDONTWRITEBYTECODE=1 python3 "$CHECK" gate \
  "$FIX/seed-one-sentence.md" "$FIX/seed-one-sentence.audit.md" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] \
  && ok "한 문장 seed 가 통과한다 (게이트가 양식이 아니다)" \
  || no "한 문장 seed 가 rc=$rc 로 막혔다 — 본문 존재 검사가 들어왔다. 그것이 payload 를 양식으로 만든다"

# 양성 대조 — 게이트가 «무엇이든 통과시키는» 상태가 아님을 같은 자리에서 증명한다.
# 이것이 없으면 위 ok 는 「검사가 다 죽었다」와 구별되지 않는다.
PYTHONDONTWRITEBYTECODE=1 python3 "$CHECK" gate \
  "$FIX/seed-has-url.md" "$FIX/seed-one-sentence.audit.md" >/dev/null 2>&1
rc2=$?
[ "$rc2" -ne 0 ] \
  && ok "양성 대조: URL 있는 seed 는 막힌다 (게이트가 살아 있다)" \
  || no "양성 대조: URL 있는 seed 가 통과한다 — 검사가 전부 죽었다"

finish
