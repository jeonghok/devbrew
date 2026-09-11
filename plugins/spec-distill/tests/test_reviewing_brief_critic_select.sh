#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/references/docreview-profiles/brief.md shared/docreview/scripts/docreview_state.py plugins/spec-distill/scripts/brief_review_state.py plugins/spec-distill/scripts/state_path.py
#
# `reviewing-brief` 탐지 dispatch 의 선택 펜스(critic-select 마커 사이)를 잘라내 차가운 셸(`env -i`)에서
# **실행**해 어느 critic 이 dispatch 되는지 잰다. 읽어서 판정하지 않는다 — 산문 조건은 집행되지 않고,
# 옳아 보이는 펜스가 미할당 변수로 죽는 결함은 실행으로만 드러난다.
#   S1  프로필 web: true · 스위치 꺼짐 → spec-distill:doc-critic-web · advisory 없음 · record 없음
#   S2  프로필 web: true · 스위치 켜짐 → spec-distill:doc-critic · loud advisory · degrade record
#   S3  프로필 web: false            → spec-distill:doc-critic · advisory 없음 · record 없음(스위치와 무관)
#   S4  프로필 판독 불가               → spec-distill:doc-critic · advisory · record — 웹을 켜는 쪽으로 새지 않는다
#   S5  스위치 값이 "1" 이 아님(0·true) → S1 과 같다(계약: 정확히 "1" 만 참)
#   E   앞 블록의 `set -euo pipefail` 을 물려받아도 S1·S2 가 같다
#   L   펜스가 낼 수 있는 값마다 SKILL 에 그 subagent_type 의 dispatch 블록이 정확히 하나
# 펜스는 `## 입력` 블록 뒤에 이어 붙여 한 셸에서 돈다 — SKILL 이 적은 정상 경로와 같다(그 블록이 degrade
# 원장을 init 한다). 프로필은 실제 brief.md 이고, S3·S4 만 그것을 변형한 가짜 플러그인 루트로 만든다.
# 실제 codex·실제 agent 는 부르지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md"
REAL_PROF="$ROOT/plugins/spec-distill/references/docreview-profiles/brief.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
  echo "plugins/spec-distill/references/docreview-profiles/brief.md"
  echo "shared/docreview/scripts/docreview_state.py"
  echo "plugins/spec-distill/scripts/brief_review_state.py"
  echo "plugins/spec-distill/scripts/state_path.py"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-rb-select-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

# ── 블록 추출 ────────────────────────────────────────────────────────────────
FENCE="$SCRATCH/select.sh"
awk '/<!-- critic-select:begin -->/ {g=1; next}
     /<!-- critic-select:end -->/ {g=0}
     g && /^```bash$/ {b=1; next}
     g && b && /^```$/ {b=0; next}
     g && b' "$SKILL" > "$FENCE"
INPUT="$SCRATCH/input.sh"
awk '/^## 입력$/ {s=1; next}
     s && /^## / {exit}
     s && !done && /^```bash$/ {b=1; next}
     s && b && /^```$/ {b=0; done=1; next}
     s && b' "$SKILL" > "$INPUT"
n_fence="$(grep -c . "$FENCE" || true)"
if [ "${n_fence:-0}" -lt 10 ] || ! bash -n "$FENCE" 2>/dev/null || ! grep -q '^echo "CRITIC_AGENT=' "$FENCE"; then
  no "추출: 선택 펜스가 ${n_fence:-0}줄 — 마커가 사라졌거나 문법이 깨졌거나 CRITIC_AGENT 를 내지 않는다. 아래 판정은 무의미하다"
  finish; exit
fi
ok "추출: 선택 펜스 ${n_fence}줄 · bash -n 통과 · CRITIC_AGENT 를 낸다"
if grep -q '^init_rc=0; python3 ' "$INPUT" && bash -n "$INPUT" 2>/dev/null; then
  ok "추출: \`## 입력\` 블록(원장 init 포함)을 잘라냈다"
else
  no "추출: \`## 입력\` 블록을 못 잘랐다 — record 판정이 원장 없이 돈다"
fi
COMBINED="$SCRATCH/combined.sh"
{ cat "$INPUT"; cat "$FENCE"; printf 'echo "__STATE=$STATE"\necho "__FB=$DEGRADE_FALLBACK_FILE"\n'; } > "$COMBINED"
COMBINED_E="$SCRATCH/combined-errexit.sh"
{ echo 'set -euo pipefail'; cat "$COMBINED"; } > "$COMBINED_E"

# ── 계측기 전제 — 차가운 셸의 python3 가 PyYAML 을 찾을 수 있어야 profile-check 가 돈다 ──
# 셀마다 HOME 을 scratch 로 가두므로 사용자 site-packages 가 안 보인다. 차가운 셸과 **같은**
# 인터프리터(PATH=/usr/bin:/bin)가 실제 HOME 에서 찾는 자리를 PYTHONPATH 로 넘긴다.
BASE="/usr/bin:/bin"
YAML_SITE="$(env -i PATH="$BASE" HOME="$HOME" python3 -c 'import os, yaml; print(os.path.dirname(os.path.dirname(os.path.abspath(yaml.__file__))))' 2>/dev/null)"
if [ -z "$YAML_SITE" ]; then
  no "전제: 차가운 셸의 python3 가 PyYAML 을 못 찾는다 — profile-check 가 늘 실패해 모든 셀이 S4 로 합쳐진다"
  finish; exit
fi
real_web="$(env -i PATH="$BASE" HOME="$HOME" python3 "$ROOT/plugins/spec-distill/scripts/docreview_state.py" profile-check "$REAL_PROF" 2>/dev/null \
  | env -i PATH="$BASE" python3 -c 'import json, sys; print(json.load(sys.stdin).get("web"))' 2>/dev/null)"
[ "$real_web" = "True" ] \
  && ok "전제: 실제 brief.md 가 profile-check 로 web: true — S1·S2 는 실제 프로필을 잰다" \
  || no "전제: 실제 brief.md 의 web 이 true 가 아니다('$real_web') — S1·S2 의 기대가 무너진다"

# ── 가짜 플러그인 루트 셋 — scripts 는 실물, references 만 갈아 끼운다 ────────────────
mk_pr() {   # mk_pr <이름> <real|off|bad>
  local pr="$SCRATCH/$1"
  mkdir -p "$pr"
  ln -s "$ROOT/plugins/spec-distill/scripts" "$pr/scripts"
  case "$2" in
    real) ln -s "$ROOT/plugins/spec-distill/references" "$pr/references" ;;
    off)  mkdir -p "$pr/references/docreview-profiles"
          sed 's/^web: true$/web: false/' "$REAL_PROF" > "$pr/references/docreview-profiles/brief.md" ;;
    bad)  mkdir -p "$pr/references/docreview-profiles"
          sed '/^web:/d' "$REAL_PROF" > "$pr/references/docreview-profiles/brief.md" ;;
  esac
  printf '%s\n' "$pr"
}
PR_REAL="$(mk_pr pr-real real)"; PR_OFF="$(mk_pr pr-off off)"; PR_BAD="$(mk_pr pr-bad bad)"
grep -qx 'web: false' "$PR_OFF/references/docreview-profiles/brief.md" \
  && ok "전제: web: false 변형이 적용됐다" || no "전제: web: false 변형이 적용되지 않았다 — S3 가 S1 과 같아진다"
env -i PATH="$BASE" HOME="$HOME" python3 "$ROOT/plugins/spec-distill/scripts/docreview_state.py" profile-check "$PR_OFF/references/docreview-profiles/brief.md" >/dev/null 2>&1 \
  && ok "전제: web: false 변형은 profile-check 를 통과한다 (S3 는 판독 불가가 아니라 진짜 web: false 다)" \
  || no "전제: web: false 변형이 profile-check 에서 떨어진다 — S3 가 S4 와 구별되지 않는다"
env -i PATH="$BASE" HOME="$HOME" python3 "$ROOT/plugins/spec-distill/scripts/docreview_state.py" profile-check "$PR_BAD/references/docreview-profiles/brief.md" >/dev/null 2>&1 \
  && no "전제: web 줄을 지운 변형이 profile-check 를 통과한다 — S4 가 판독 불가를 재지 못한다" \
  || ok "전제: web 줄을 지운 변형은 profile-check 가 거부한다 (S4 의 판독 불가가 실재한다)"

DOCS="$SCRATCH/docs"; mkdir -p "$DOCS"
cp "$ROOT/shared/tests/fixtures/docreview/brief-sample.md" "$DOCS/brief-sample.md"
printf -- '---\nx: 1\n---\n\n## 6. 사용자 원문\n\n- id: S2\n  source: verbatim\n  round: 1\n  text: "둘째 발화"\n' > "$DOCS/brief-sample.audit.md"
DOC="$DOCS/brief-sample.md"; AUD="$DOCS/brief-sample.audit.md"

# ── 실행 ────────────────────────────────────────────────────────────────────
run_select() {   # run_select <셀> <플러그인 루트> [NAME=VALUE…]
  local cell="$1" pr="$2"; shift 2
  local home="$SCRATCH/$cell"; mkdir -p "$home/.claude/spec-distill/$cell"
  # degrade 원장은 인터뷰가 먼저 만든 세션 state 다(`init` 은 있는 파일에 키만 심는다) — 그 모양을 심는다.
  printf -- '---\nsession_id: %s\n---\n\nbody\n' "$cell" > "$home/.claude/spec-distill/$cell/state.local.md"
  ( cd "$home" && env -i PATH="$BASE" HOME="$home" PYTHONPATH="$YAML_SITE" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$pr" DEVBREW_SPEC_DISTILL_SESSION_ID="$cell" PAYLOAD="$DOC" AUDIT="$AUD" \
      "$@" bash "${WITH:-$COMBINED}" ) >"$SCRATCH/$cell.out" 2>"$SCRATCH/$cell.err"
  echo $? > "$SCRATCH/$cell.rc"
}
agent_of() { sed -n 's/^CRITIC_AGENT=//p' "$SCRATCH/$1.out" | tail -1; }
advised() { grep -qE '^\[spec-distill\] (웹 비활성|프로필의 web 값을 읽지 못했다)' "$SCRATCH/$1.err"; }
recorded() {   # recorded <셀> <reason 부분문자열> — degrade 원장 또는 두 번째 채널에 critic/direction/degraded record
  local st fb
  st="$(sed -n 's/^__STATE=//p' "$SCRATCH/$1.out" | tail -1)"
  fb="$(sed -n 's/^__FB=//p' "$SCRATCH/$1.out" | tail -1)"
  { [ -n "$st" ] && [ -f "$st" ] && grep -q 'component: critic' "$st" && grep -q 'affected_axis: direction' "$st" \
      && grep -q 'verification_status: degraded' "$st" && grep -qF "$2" "$st"; } \
    || { [ -n "$fb" ] && [ -f "$fb" ] && grep -q 'component=critic axis=direction status=degraded' "$fb" && grep -qF "$2" "$fb"; }
}
state_seen() {   # 그 셀이 원장 경로를 냈고 원장이 실재하는가 — record 부재 단언의 양의 짝
  local st
  st="$(sed -n 's/^__STATE=//p' "$SCRATCH/$1.out" | tail -1)"
  [ -n "$st" ] && [ -f "$st" ]
}
any_record() {   # any_record <셀> — 사유와 무관하게 critic/direction/degraded record 가 두 채널 어디에든 있는가.
  # 부재 단언은 사유 문자열로 거르지 않는다 — 걸러 두면 다른 사유로 쌓인 record 가 부재 판정을 조용히 통과한다.
  local st fb
  st="$(sed -n 's/^__STATE=//p' "$SCRATCH/$1.out" | tail -1)"
  fb="$(sed -n 's/^__FB=//p' "$SCRATCH/$1.out" | tail -1)"
  { [ -n "$st" ] && [ -f "$st" ] && grep -q 'component: critic' "$st" && grep -q 'affected_axis: direction' "$st"; } \
    || { [ -n "$fb" ] && [ -f "$fb" ] && grep -q 'component=critic axis=direction' "$fb"; }
}

WEB="spec-distill:doc-critic-web"; NOWEB="spec-distill:doc-critic"

check_web() {   # check_web <셀> <라벨> — S1 형태(웹 사본 · 공시 없음 · record 없음)
  assert_eq "$(agent_of "$1")" "$WEB" "$2: 웹 사본을 고른다"
  advised "$1" && no "$2: 웹을 켠 라운드에 degrade advisory 가 나왔다" || ok "$2: advisory 없음"
  if state_seen "$1"; then
    any_record "$1" && no "$2: 웹을 켠 라운드에 critic/direction degrade record 가 남았다" \
                               || ok "$2: degrade record 없음 (원장은 실재한다 — 양의 짝)"
  else
    no "$2: 원장 경로가 없거나 원장이 없다 — record 부재 판정이 공허하다"
  fi
}

run_select sel01web "$PR_REAL"
check_web sel01web "S1(web true · 스위치 꺼짐)"

run_select sel02off "$PR_REAL" DEVBREW_SPEC_DISTILL_DISABLE_WEB=1
assert_eq "$(agent_of sel02off)" "$NOWEB" "S2(web true · 스위치 켜짐): 웹 없는 doc-critic 으로 내려간다"
grep -qF '웹 비활성(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1)' "$SCRATCH/sel02off.err" \
  && ok "S2: loud advisory 가 스위치 이름을 대며 나온다" || no "S2: 스위치로 내려갔는데 advisory 가 없다"
recorded sel02off 'DEVBREW_SPEC_DISTILL_DISABLE_WEB=1' \
  && ok "S2: degrade 원장(또는 두 번째 채널)에 critic/direction/degraded record 가 남았다" \
  || no "S2: 스위치로 내려간 사실이 degrade 채널에 없다 — Step B 에서 「degrade 없음」으로 보인다"

check_noweb_quiet() {   # check_noweb_quiet <셀> <라벨> — S3 형태(웹 없는 사본 · 공시 없음 · record 없음)
  assert_eq "$(agent_of "$1")" "$NOWEB" "$2: 웹 없는 doc-critic"
  advised "$1" && no "$2: web false 프로필에 degrade advisory 가 나왔다 (끌 웹이 없다)" || ok "$2: advisory 없음"
  # S2 의 record 존재 단언과 짝 — web false 는 degrade 가 아니다. 원장이 실재해야 부재가 공허하지 않다.
  if state_seen "$1"; then
    any_record "$1" && no "$2: web false 프로필에 critic/direction degrade record 가 남았다" \
                               || ok "$2: degrade record 없음 (원장은 실재한다 — 양의 짝)"
  else
    no "$2: 원장 경로가 없거나 원장이 없다 — record 부재 판정이 공허하다"
  fi
}
run_select sel03nof "$PR_OFF"
check_noweb_quiet sel03nof "S3(web false)"
run_select sel03nsw "$PR_OFF" DEVBREW_SPEC_DISTILL_DISABLE_WEB=1
check_noweb_quiet sel03nsw "S3(web false · 스위치 켜짐)"

run_select sel04bad "$PR_BAD"
assert_eq "$(agent_of sel04bad)" "$NOWEB" "S4(프로필 판독 불가): 웹 없는 doc-critic — 웹 쪽으로 새지 않는다"
grep -qF '프로필의 web 값을 읽지 못했다' "$SCRATCH/sel04bad.err" \
  && ok "S4: 판독 불가를 loud advisory 로 공시한다" || no "S4: 판독 불가가 조용하다"
recorded sel04bad '판독 불가' && ok "S4: degrade record 가 남았다" || no "S4: 판독 불가가 degrade 채널에 없다"

run_select sel05zer "$PR_REAL" DEVBREW_SPEC_DISTILL_DISABLE_WEB=0
check_web sel05zer "S5(스위치 0)"
run_select sel05tru "$PR_REAL" DEVBREW_SPEC_DISTILL_DISABLE_WEB=true
check_web sel05tru "S5(스위치 true — 계약은 정확히 1)"

WITH="$COMBINED_E" run_select sel06web "$PR_REAL"
assert_eq "$(cat "$SCRATCH/sel06web.rc")" "0" "E: errexit 를 물려받아도 S1 이 끝까지 돈다 (rc 0)"
assert_eq "$(agent_of sel06web)" "$WEB" "E: errexit 아래 S1 도 웹 사본"
WITH="$COMBINED_E" run_select sel06off "$PR_REAL" DEVBREW_SPEC_DISTILL_DISABLE_WEB=1
assert_eq "$(cat "$SCRATCH/sel06off.rc")" "0" "E: errexit 를 물려받아도 S2 가 끝까지 돈다 (rc 0)"
assert_eq "$(agent_of sel06off)" "$NOWEB" "E: errexit 아래 S2 도 웹 없는 doc-critic"
recorded sel06off 'DEVBREW_SPEC_DISTILL_DISABLE_WEB=1' && ok "E: errexit 아래 S2 record 도 남는다" \
  || no "E: errexit 아래에서 S2 record 가 사라졌다"

# ── L 펜스가 낼 수 있는 값 ↔ dispatch 블록 ─────────────────────────────────────
# 값은 펜스의 대입 줄에서 도출한다(열거하지 않는다). 각 값의 dispatch 블록이 정확히 하나여야 모델이
# 펜스 출력과 같은 블록을 찾을 수 있다. 두 값은 서로 달라야 한다 — 같으면 선택이 없다.
VALUES="$(sed -n 's/^[[:space:]]*CRITIC_AGENT="\(spec-distill:[a-z-]*\)"$/\1/p' "$FENCE" | sort -u)"
n_val="$(printf '%s\n' "$VALUES" | grep -c . || true)"
assert_eq "$n_val" "2" "L: 펜스가 낼 수 있는 값이 둘이다 ($(printf '%s' "$VALUES" | tr '\n' ' '))"
for v in $VALUES; do
  n="$(grep -cE "^[[:space:]]*subagent_type: \"${v}\",?$" "$SKILL" || true)"
  assert_eq "$n" "1" "L: 펜스 값 $v 의 dispatch 블록이 정확히 하나"
done
finish
