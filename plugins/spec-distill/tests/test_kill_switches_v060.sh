#!/usr/bin/env bash
# R7 AC9 (§3-3) — 파일을 지우는 장치(리뷰 진입 때의 원장 정리 `scripts/ledger_sweep.py`)의 kill switch 행렬.
# 스위치 넷(전역 하나 + 옛 토큰 셋)이 각각 아무것도 지우지 않고, 스위치 없이 돌리면 지운다(양성 대조).
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# 개발자 셸의 DEVBREW_* 를 물려받지 않는다 — 남은 스위치가 양성 대조를 조용히 막는다.
for _v in $(compgen -e DEVBREW_); do unset "$_v"; done

SWEEP="$PLUGIN_DIR/scripts/ledger_sweep.py"
WORK=$(mktemp -d)
[[ -n "$WORK" && -d "$WORK" ]] || { echo "mktemp -d 실패 — 아무것도 재지 않았다"; exit 1; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" && git init -q
ROOT="$WORK/.claude/spec-distill"
OLD="$ROOT/oldsess01"

# plant_old <나이(시간)> — 옛 세션 폴더(state.local.md 없음)를 만들고 폴더 자신과 그 아래를 늙힌다.
# 나이는 폴더 자신과 그 아래 모든 항목의 최신 mtime 이다 — 폴더만 남기고 늙히면 칸이 공허해진다.
plant_old() {
  mkdir -p "$OLD"
  echo "x" > "$OLD/f"
  python3 -I -c 'import os,sys,time; t=time.time()-float(sys.argv[2])*3600
for p in (os.path.join(sys.argv[1], "f"), sys.argv[1]): os.utime(p, (t, t))' "$OLD" "$1"
}

# 스위치 넷 — 각각 30시간 묵은 폴더를 남긴다.
n=0
for sw in "DEVBREW_SPEC_DISTILL_DISABLE=1" \
          "DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd" \
          "DEVBREW_SKIP_HOOKS=spec-distill:session-end-cleanup" \
          "DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc" \
          "DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd,quality-gates:Stop"; do
  n=$((n+1))
  plant_old 30
  env "$sw" python3 "$SWEEP" --root "$ROOT" >/dev/null
  [[ -d "$OLD" ]] \
    && ok "case ${n}: ${sw} — 원장 정리가 아무것도 지우지 않는다" \
    || no "case ${n}: ${sw} 인데 옛 세션 폴더가 지워졌다"
done

# 다른 플러그인의 토큰은 이 정리를 끄지 않는다.
plant_old 30
env DEVBREW_SKIP_HOOKS="quality-gates:SessionEnd" python3 "$SWEEP" --root "$ROOT" >/dev/null
[[ ! -d "$OLD" ]] \
  && ok "case 6: quality-gates:SessionEnd 는 spec-distill 의 정리를 끄지 않는다" \
  || no "case 6: 다른 플러그인의 토큰이 spec-distill 의 정리를 껐다"

# TTL 재정의 — 2시간 묵은 폴더는 기본 TTL(24h)에서 남고, TTL 1h 에서 지워진다.
plant_old 2
python3 "$SWEEP" --root "$ROOT" >/dev/null
[[ -d "$OLD" ]] \
  && ok "case 7: 기본 TTL 에서 2시간 묵은 폴더는 남는다" \
  || no "case 7: 기본 TTL 인데 2시간 묵은 폴더가 지워졌다"
env DEVBREW_SPEC_DISTILL_TTL_HOURS=1 python3 "$SWEEP" --root "$ROOT" >/dev/null
[[ ! -d "$OLD" ]] \
  && ok "case 8: DEVBREW_SPEC_DISTILL_TTL_HOURS=1 이 2시간 묵은 폴더를 지운다" \
  || no "case 8: TTL 재정의가 듣지 않는다"

# 양성 대조 — 스위치 없이 돌리면 30시간 묵은 폴더를 지운다. 이것이 없으면 위 「남는다」는
# 정리가 고장 나도 통과한다.
plant_old 30
python3 "$SWEEP" --root "$ROOT" >/dev/null
[[ ! -d "$OLD" ]] \
  && ok "양성 대조: 스위치 없이 돌리면 옛 세션 폴더를 지운다" \
  || no "양성 대조: 스위치 없이도 지우지 않는다 — 위 칸들이 공허하다"

finish
