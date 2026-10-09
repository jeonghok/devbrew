#!/usr/bin/env bash
# AC6 — design 자리는 **집행하지 못하는 kill switch 를 이름 대지 않는다.**
#
# ── 앵커 재조준 (문서 리뷰 엔진 전환, T7) ────────────────────────────────────
# 옛 판정은 `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` 이 옛 design-doc 리뷰어 agent
# 에 이름으로 실려 있고 README 에도 문서화됐는지를 쟀다. 그 스위치의 **유일한 집행
# 지점이 그 agent 였고**, 엔진 전환으로 그것이 사라지면서 집행 지점이 0 이 됐다.
# 엔진(`shared/docreview/`)은 이 스위치를 읽지 않는다 — 층 2 의 `handoff_incomplete`
# 만 따로 끄는 경로가 없다.
#
# 「막지 않는 것을 막는다고 믿게 만드는 선언은 없는 것보다 나쁘다」(CLAUDE.md, P21).
# 그래서 판정을 뒤집는다: 이 스위치 이름이 design 자리의 표면에 **없어야** 한다.
# 되살리려면 집행 지점을 먼저 만들어야 하고, 이름만 먼저 돌아오면 이 락이 RED 다.
#
# ── 스코프 ──────────────────────────────────────────────────────────────────
# 코퍼스는 T7 이 소유하는 design 자리 표면(진입 skill · design-doc 프로필 · 공유 엔진)
# **더하기 `README.md`**. T8(문서·버전) 이 이 커밋에서 README 의 스위치 목록 행을
# 지우면서 같은 커밋으로 코퍼스를 여기까지 넓혔다 — 넓히지 않고 줄만 지우면, 다음
# 사람이 그 줄을 되살려도(집행 지점 없이) 이 락은 계속 침묵한다. 넓히기 전에는
# 「README 는 코퍼스 밖」이 T8 전까지 영구 RED 를 피하려는 의도적 좁힘이었다(「오래된
# RED 는 풍경이 된다」 회피) — 이 커밋이 그 이유를 없앴으므로 좁힘도 함께 없앤다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
SWITCH='DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK'

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

CORPUS=()
while IFS= read -r f; do
  [ -n "$f" ] && CORPUS+=("$f")
done < <(find "$SD/skills/spec-review" "$SD/references/docreview-profiles" \
              "$REPO_ROOT/shared/docreview" -type f 2>/dev/null | sort)
CORPUS+=("$SD/README.md")

# 양의 짝 ③ — README.md 가 코퍼스 원소로 실재하고 읽을 수 있다.
# 실측(mutation): README.md 를 옮기거나 이름을 바꿔도 배열 리터럴 "$SD/README.md" 는
# 문자열이라 그대로 남고, 아래 `grep -lF` 는 대상 부재를 `2>/dev/null` 로 삼킨다 — 그러면
# 양의 짝 ①(개수 ≥4)·②(살아있는 스위치 두 건)는 나머지 파일들만으로도 만족돼 본 판정이
# README 없이도 조용히 GREEN 을 낸다. 그래서 이 자리를 **파일시스템**에서 직접 확인한다
# (배열 원소 존재 자체가 아니라 그 경로에 실제 파일이 있는지).
if [ -f "$SD/README.md" ]; then
  ok "AC6: README.md 가 코퍼스 경로에 실재한다 (양의 짝 — path drift 감지)"
else
  no "AC6: README.md 가 코퍼스 경로에 없다(path drift) — 아래 부재 판정이 README 없이도 통과할 수 있다"
fi

# 양의 짝 ① — 코퍼스가 비어 있지 않다. 부재 락은 코퍼스가 0 이면 통째로 공허하다.
if [ "${#CORPUS[@]}" -ge 4 ]; then
  ok "AC6: design 자리 표면 ${#CORPUS[@]}개 수집 (부재 판정이 공허하지 않다)"
else
  no "AC6: 코퍼스가 ${#CORPUS[@]}개뿐 — 아래 부재 판정이 공허하다 (find 필터 파손)"
  finish; exit
fi

# 양의 짝 ② — 그 코퍼스를 실제로 **읽었다**. 집행되는 스위치 둘이 거기 있어야 한다.
# 이것이 없으면 코퍼스를 통째로 빈 파일로 바꿔도 아래 부재 판정이 통과한다.
for live in 'DEVBREW_SPEC_DISTILL_DISABLE_CODEX' 'DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC'; do
  if grep -qlF "$live" "${CORPUS[@]}" >/dev/null 2>&1; then
    ok "AC6: 집행되는 스위치 '$live' 가 코퍼스에서 읽힌다 (양의 짝)"
  else
    no "AC6: 집행되는 스위치 '$live' 를 코퍼스에서 못 찾았다 — 코퍼스를 실제로 읽고 있는지 의심"
  fi
done

# 본 판정 — 집행 지점이 없는 스위치 이름이 이 표면에 없다.
HITS="$(grep -lF "$SWITCH" "${CORPUS[@]}" 2>/dev/null || true)"
if [ -z "$HITS" ]; then
  ok "AC6: '$SWITCH' 가 design 자리 표면에 없다 (집행 지점 0 — 이름만 남기지 않는다)"
else
  no "AC6: '$SWITCH' 가 아직 이름 대어진다 — 집행 지점이 없는데 껐다고 믿게 만든다:$(printf '\n  - %s' $HITS)"
fi
finish
