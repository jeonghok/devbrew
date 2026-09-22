#!/usr/bin/env bash
# guards: shared/docreview/agents/doc-critic*.md plugins/*/agents/doc-critic*.md plugins/*/references/docreview-profiles/*.md
#
# 층 1 의 «판정 관계»를 누가 소유하는가. 탐지 리뷰어 본문이 축 이름과 판정 관계를
# 리터럴로 쥐면 그 문장은 네 자리 중 하나에만 맞는다 — brief 는 ground_truth 를 안 쓰고,
# seed 는 정합이 아니라 뺄셈을 재며, generic 은 외부 정답이 없어 「문서와 문서가 정합한가」
# 로 공허해진다. 그래서 축 이름은 프로필 `layer_rubric.layer1` 이, 판정 관계는 각 프로필
# 본문의 「**층 1 판정 관계** —」 줄이 소유한다.
#
# 이 락이 두 축을 «함께» 재는 이유: 한쪽만 재면 다른 쪽이 조용히 빈다. agent 에서 리터럴을
# 걷어내고 프로필에 관계를 안 적으면 리뷰어는 무엇과 대조할지 어디서도 못 읽는다(부재 락
# 단독의 공허함 — 리포 기록: feedback_negative_locks_need_positive_pair).
#
# 프로필 코퍼스는 **열거가 아니라 글롭 도출**이다. 다섯째 자리가 생기면 그 자리도 자동으로
# 이 계약에 든다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'shared/docreview/agents/doc-critic*.md' \
                  'plugins/*/agents/doc-critic*.md' \
                  'plugins/*/references/docreview-profiles/*.md'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT" || exit 1
. "$HERE/assert.sh"

MARKER='**층 1 판정 관계** —'

# A2 가 세는 리터럴 여덟 축 이름 — 이 목록 자체가 「금지할 대상」이므로 여기서 이름을
# 나열하는 것은 맞다. `컴포넌트 관계` 는 반드시 두 단어 붙은 토큰으로 맞혀야 한다 — 새
# 불릿 산문에 「판정 관계」·「그 자리의 관계」처럼 맨 `관계` 가 정당하게 섞여 있어서,
# `관계` 단독을 목록에 넣으면 오탐이다.
AXIS_NAMES=("목표" "문제정의" "범위" "아키텍처" "컴포넌트 관계" "데이터 흐름" "trade-off" "구현 가능성")
n_axis_names="${#AXIS_NAMES[@]}"
if [ "$n_axis_names" -eq 8 ]; then
  ok "A2 양의 짝: 리터럴 축 이름 목록이 8개다 (아래 카운트 판정이 잴 대상을 갖는다)"
else
  no "A2 양의 짝: 리터럴 축 이름 목록이 ${n_axis_names}개다 — 8개여야 한다. 아래 카운트 판정이 공허하다"
fi

# ── 축 A : agent 사본 넷이 층 1 을 프로필에 위임한다 ─────────────────────────
AGENTS="$(git ls-files -- 'shared/docreview/agents/doc-critic*.md' 'plugins/*/agents/doc-critic*.md')"
n_agents="$(printf '%s\n' "$AGENTS" | grep -c . || true)"
if [ "$n_agents" -ge 4 ]; then
  ok "A0 양의 짝: doc-critic 사본 ${n_agents}개를 코퍼스에서 읽었다 (아래 부재 판정이 공허하지 않다)"
else
  no "A0: doc-critic 사본이 ${n_agents}개다 — 넷 이상이어야 한다. 아래 전부가 공허하다"
fi

for f in $AGENTS; do
  line="$(grep -n '^- \*\*층 1\*\* —' "$f" | head -1)"
  if [ -n "$line" ]; then
    ok "A1: $f 에 층 1 불릿이 하나 있다 (양의 짝)"
  else
    no "A1: $f 에 '- **층 1** —' 불릿이 없다 — 아래 판정이 잴 대상을 잃는다"
    continue
  fi
  body="${line#*:}"
  # A2 — 리터럴 축 열거의 «개수» 판정. 이름 하나가 산문에 예로 섞이는 것은 정상이다 —
  #      둘 이상이 한 불릿에 함께 있으면 그것이 열거다. 여덟 이름 중 앞쪽 세 개
  #      (「목표·문제정의·범위」)만 겨누면 뒤쪽 다섯(아키텍처·컴포넌트 관계·데이터
  #      흐름·trade-off·구현 가능성)이 리터럴로 남아도 통과한다 — 리뷰가 잡은 구멍이다.
  #      그래서 목록(AXIS_NAMES) 전체를 순회해 세고, 2개 이상이면 RED 로 판정한다.
  n_axis_hits=0
  for axis in "${AXIS_NAMES[@]}"; do
    case "$body" in
      *"$axis"*) n_axis_hits=$((n_axis_hits+1)) ;;
    esac
  done
  if [ "$n_axis_hits" -le 1 ]; then
    ok "A2: $f 층 1 불릿에 리터럴 축 열거가 없다 (관찰된 축 이름 수: ${n_axis_hits}/8)"
  else
    no "A2: $f 층 1 불릿이 리터럴 축 열거를 아직 쥐고 있다 (관찰된 축 이름 수: ${n_axis_hits}/8)"
  fi
  # A3 — 프로필 참조 존재(양의 짝: A2 의 부재가 «줄 삭제»로 달성되지 않았다)
  case "$body" in
    *'layer_rubric.layer1'*) ok "A3: $f 층 1 불릿이 layer_rubric.layer1 을 참조한다" ;;
    *) no "A3: $f 층 1 불릿이 layer_rubric.layer1 을 참조하지 않는다" ;;
  esac
  # A4 (AC3) — 근거 요구가 «축 이름»에 안 묶였다. 조건절 자체는 살아 있어야 한다.
  case "$body" in
    *'구현 가능성 finding'*) no "A4: $f 의 근거 요구가 아직 축 이름(구현 가능성)에 묶여 있다" ;;
    *) ok "A4: $f 의 근거 요구가 축 이름에 안 묶여 있다" ;;
  esac
  case "$body" in
    *'리포 사실을 단정하는'*) ok "A4b: $f 에 근거 요구 조건절이 살아 있다 (A4 의 양의 짝 — 조건절 삭제가 아니다)" ;;
    *) no "A4b: $f 에 근거 요구 조건절이 없다 — A4 가 조건절 삭제로 통과한 것이다" ;;
  esac
  # A5 (AC3') — 판정 관계를 agent 본문이 단정하지 않는다.
  n_rel="$(grep -c 'ground_truth.*정합' "$f" || true)"
  if [ "${n_rel:-0}" -eq 0 ]; then
    ok "A5: $f 에 ground_truth 정합을 단정하는 문장이 0건"
  else
    no "A5: $f 에 ground_truth 정합 단정이 ${n_rel}건 남아 있다 (design-doc 자리의 관계이지 네 자리 공통이 아니다)"
  fi
done

# ── 축 B : 프로필 넷이 각자 자기 자리의 판정 관계를 소유한다 ─────────────────
PROFILES="$(git ls-files -- 'plugins/*/references/docreview-profiles/*.md')"
n_prof="$(printf '%s\n' "$PROFILES" | grep -c . || true)"
if [ "$n_prof" -ge 4 ]; then
  ok "B0 양의 짝: 프로필 ${n_prof}개를 글롭으로 도출했다 (열거가 아니다)"
else
  no "B0: 프로필이 ${n_prof}개다 — 넷 이상이어야 한다. 아래 전부가 공허하다"
fi

RELS=""
for p in $PROFILES; do
  n="$(grep -cF "$MARKER" "$p" || true)"
  if [ "${n:-0}" -eq 1 ]; then
    ok "B1: $p 가 자기 층 1 판정 관계를 한 줄로 소유한다"
    RELS="$RELS
$(grep -F "$MARKER" "$p" | head -1)"
  else
    no "B1: $p 의 마커 줄이 ${n}개다 (정확히 하나여야 한다)"
  fi
done

# B2 — 넷이 서로 «다른» 문장이다. 한쪽을 다른 쪽에 베껴 넣으면 자리 경계가 무너진다.
n_rel_lines="$(printf '%s' "$RELS" | grep -c . || true)"
n_uniq="$(printf '%s' "$RELS" | grep . | sort -u | grep -c . || true)"
if [ "${n_rel_lines:-0}" -ge 4 ] && [ "$n_uniq" -eq "$n_rel_lines" ]; then
  ok "B2: 판정 관계 ${n_rel_lines}줄이 전부 서로 다르다 (자리마다 다른 관계를 잰다)"
else
  no "B2: 판정 관계가 ${n_rel_lines}줄인데 서로 다른 것은 ${n_uniq}줄이다 — 자리 경계가 무너졌다"
fi

finish
