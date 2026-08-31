#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/*/SKILL.md plugins/spec-distill/skills/*/references/*.md
#
# 압축 규약의 **채택자 대칭** — `references/compression.md` 를 채택한 skill 이 자기 표면에
# 압축 어휘를 갖는가. `test_proceed_gate_adopters.sh` 와 하한(2)은 이제 같다(fix round 3)
# — 다른 것은 그 형제 락의 「정본이 이름을 대는 skill」합집합이 여기엔 없다는 점 하나뿐
# 이다(아래 「이름을 리터럴로 박고 양방향 대조하는 대안은…」문단에서 그 이유를 다룬다).
#
# ── guards 선언에 `references/*.md` 글롭이 있는 이유 (fix round 2 — Task 12) ──
# 스캔 로직(아래 `derive_reference_adopters`)은 각 채택자의 `references/*.md` 까지 본다
# — **동적으로**, 채택자가 그 디렉터리를 가지면. 이 파일 상단의 `# guards:` 는 그 동적
# 스캔이 아니라 `test_guards_coverage_bidirectional.sh` 가 재는 **정적 선언**이고, 그
# 락은 각 글롭이 오늘의 `--emit-scanned` 출력을 실제로 덮는지 잰다. round 1 시점엔
# 유일한 채택자 `framing-requests` 가 `references/` 디렉터리를 갖지 않아 `--emit-scanned`
# 가 `SKILL.md` 한 줄만 냈고, 그때 `references/*.md` 글롭을 선언에 남기면 아무것도 안
# 덮는 글롭(「선언이 넓다」)으로 RED 가 났다〔실측, fix round 1〕. 둘째 채택자
# `conducting-interview` 가 brief 를 이 계약의 게이트 집행자로 채택하면서(Task 12,
# `references/finishing.md` 경유) `--emit-scanned` 가 그 경로를 냈고, 그 경로가 옛
# 선언 밖이 되어 반대 방향(「선언이 좁다」)이 RED 를 냈다〔실측, fix round 2〕 — 이
# 문단이 예고한 그 시점이 왔으므로 글롭을 되돌린다.
#
# ── 하한이 2 인 이유 (fix round 3 — 코디네이터 오버룰) ─────────────────────
# 이전 라운드는 하한을 1로 유지했다 — 그 판단을 코디네이터가 뒤집었고, 실측이 그
# 뒤집음을 뒷받침한다. 하한 1은 "이 계약에 채택자가 있다"만 지킨다 — 이 task 이전부터
# 참이던 성질이고, 이 task 가 새로 세운 성질을 지키지 않는다. 실측: `finishing.md`의
# 포인터+어휘 두 문장을 지우면 도출이 2→1이 되는데, 하한 1에서는 **그래도 통과했다**
# (rc=0, silently green) — brief 가 조용히 채택자 집합에서 빠져도 이 락은 몰랐다. 정본의
# 새 heading(「seed 와 brief 둘 다 이 계약을 게이트로 집행한다」)이 정확히 이 대칭을
# 주장하므로, 하한이 그 주장과 같은 수를 요구해야 정본과 락이 같은 것을 말한다. 형제 락
# (`test_proceed_gate_adopters.sh`)의 하한 2도 같은 형태의 근거(「두 skill 이 구조적으로
# 공유한다」)이고 그것을 열거로 치지 않는다 — 여기도 같다.
#
# ── 이름을 리터럴로 박고 양방향 대조하는 대안은 검토 후 채택하지 않았다 ───────
# 코디네이터가 제시한 대안은 `tests/test_brief_agents.sh` F3
# (`UNTRUSTED_VERBATIM_MARKERS`) 골격이다 — 테스트 안에 EXPECTED 튜플을 리터럴로 박고,
# 실제 producer 상수를 missing/extra 양방향으로 대조한다. 그 락은 두 방향 다 실패해야
# 맞다 — 비신뢰 마커 위치가 하나 늘면 critic 문서가 반드시 따라가야 하는 보안 경계라서다.
# 여기 대상(압축 규약 채택자)은 이 파일 위쪽 첫 문단부터 스스로 선언하는 성질과
# 정반대다 — **열거가 아니라 도출**, 셋째 채택자가 생기면 자동으로 대상이 되어야 한다.
# EXPECTED 를 리터럴로 박고 extra 도 실패시키면, 정당한 셋째 채택자가 나타날 때마다 이
# 테스트를 손으로 고쳐야 하는 열거 락이 되어 파일 맨 위 선언과 정면으로 모순된다. 하한
# 2(개수)만으로 오늘 실측한 회귀(2→1)를 그대로 잡는다 — 이름을 안 박아도 이 acceptance
# criterion 을 충족하는 이유가 정확히 이 실측 하나다.
#
# **잔여 위험을 숨기지 않는다.** 하한은 개수이지 구성원이 아니다 — `conducting-interview`
# 가 포인터를 잃는 동시에 무관한 셋째 skill 이 우연히 압축 어휘를 자기 표면에 갖게 되면
# 개수는 그대로 2라 이 하한은 그 치환을 못 잡는다. 형제 락은 이 정확한 간극을 「정본
# 본문이 이름을 대는 skill 을 합집합으로 더한다」로 닫았다(`proceed-gate.md` 는 skill
# 디렉터리 이름을 리터럴로 문다) — 그러나 `references/compression.md` 는 "seed"/"brief"
# 라는 산출물 모양만 말하고 skill 디렉터리 이름은 한 번도 쓰지 않는 문서라(이 fix round
# 이전에도, 이후에도), 그 문서에 skill 이름을 새로 심는 편집은 이 fix round 의 범위 밖
# 이라 지금 하지 않는다. 다음에 이 근방을 고치는 사람을 위해 여기 명시적으로 남긴다 —
# 형제 락도 자기 union 을 추가하기 전엔 같은 gap 을 「이 wave 에서 아직 안 닫혔다」고
# 똑같이 적어 두었었다.
#
# **하한 2 는 그대로 둔다.** 하한이 1에 머물렀다면 유일한 채택자가 포인터를 잃어도
# 「채택자가 있다」는 여전히 참이라 통과한다 — 이 task 가 세운 "seed 와 brief 둘 다"
# 라는 성질이 조용히 무너져도 GREEN 인 것이 바로 이번에 실측으로 잡은 결함이다.
#
# ── 코퍼스 스코프 ───────────────────────────────────────────────────────────
# **정본을 코퍼스에 넣지 않는다.** 정본은 계약을 서술하느라 앵커 어휘를 그대로 담고
# 있어서, 들어오면 아래 존재 단언이 정본 하나로 만족되고 채택 skill 이 자기 문구를
# 통째로 잃어도 GREEN 이 된다(형제 락의 F1 위험과 같은 모양).
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
CANON="$SD/references/compression.md"
CANON_REF='references/compression\.md'

. "$REPO_ROOT/shared/tests/assert.sh"
. "$REPO_ROOT/shared/tests/presence_corpus.sh"
. "$REPO_ROOT/shared/tests/adopter_derivation.sh"

emit_only=0
[ "${1:-}" = "--emit-scanned" ] && emit_only=1

[ -f "$CANON" ] || { [ "$emit_only" -eq 1 ] && exit 0
  no "정본 $CANON 부재 — 채택자 대칭을 잴 대상이 없다"; finish; exit $?; }

# 도출 로직은 `shared/tests/adopter_derivation.sh` 정본 — 형제 락과 인라인으로
# 나눠 가지면 그 자체가 새 20줄 중복이 된다(그 파일의 "왜 공용인가" 절 참고).
# `emit_only=1` 이면 이 호출이 emit 하고 exit 한다 — 아래로 돌아오지 않는다.
derive_reference_adopters "$SD" "$CANON_REF" "$REPO_ROOT" "$emit_only"
adopters="$ADOPTERS"
scanned="$SCANNED"

n_adopt=0
while IFS= read -r a; do [ -n "$a" ] && n_adopt=$((n_adopt + 1)); done < <(printf '%s' "$adopters")
if [ "$n_adopt" -lt 2 ]; then
  no "채택자 도출 ${n_adopt}개 — 하한 2 미만. 정본은 seed·brief 둘 다 게이트로 집행한다고 주장하는데(「seed 와 brief 둘 다 이 계약을 게이트로 집행한다」), 도출된 채택자가 그 대칭을 지금 지키지 못한다"
  finish; exit $?
fi
ok "채택자 도출 ${n_adopt}개 (열거 아님 — 정본 포인터에서 도출, 하한 2 충족 — seed·brief 둘 다 게이트 집행)"

SCANNED_ARR=()
while IFS= read -r f; do
  [ -n "$f" ] && SCANNED_ARR+=("$f")
done < <(printf '%s' "$scanned")
assert_presence_corpus_skill_owned "압축 채택자 표면" "${SCANNED_ARR[@]+"${SCANNED_ARR[@]}"}"

if printf '%s' "$scanned" | grep -qxF -- "$CANON"; then
  no "코퍼스: 정본($CANON)이 스캔 대상에 들어 있다 — 앵커 어휘를 담은 파일이라 단언이 그것으로 만족된다"
else
  ok "코퍼스: 정본이 스캔 대상에 없다 (자기 만족 불가)"
fi

while IFS= read -r skill_dir; do
  [ -n "$skill_dir" ] || continue
  name="$(basename -- "$skill_dir")"
  files=()
  for f in "$skill_dir/SKILL.md" "$skill_dir"/references/*.md; do
    [ -f "$f" ] && files+=("$f")
  done
  if [ "${#files[@]}" -lt 1 ]; then
    no "$name: 표면 파일 0건 — 도출이 깨졌다"
    continue
  fi
  # 불변량 넷을 이름으로 댔는가. 넷 중 하나라도 없으면 그 채택자는 «무엇을 남기는지»를
  # 자기 표면에 적지 않은 것이다 — 압축의 잣대가 정본에만 있으면 실행 시점에 안 읽힌다.
  ic="$(cat "${files[@]}" | grep -cE '의도|steering|방향|goal')"
  [ "$ic" -ge 1 ] \
    && ok "$name: 압축 불변량 어휘 실재 — ${ic}줄 (자기 표면 ${#files[@]}파일)" \
    || no "$name: 압축 불변량(의도·steering·방향·goal)이 자기 표면에 없다"
  # 확산 후 압축 — 순서가 이 계약의 전부다. 「짧게 써라」와 「크게 쓰고 깎아라」는 다른 지시다.
  dc="$(cat "${files[@]}" | grep -cE '확산.*압축|깎')"
  [ "$dc" -ge 1 ] \
    && ok "$name: 확산-후-압축 어휘 실재 — ${dc}줄" \
    || no "$name: 확산 후 압축이 자기 표면에 없다 — 「짧게 써라」는 이 계약이 아니다"
done < <(printf '%s' "$adopters")

finish
