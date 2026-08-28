#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/*/SKILL.md plugins/spec-distill/skills/*/references/*.md
#
# 압축 규약의 **채택자 대칭** — `references/compression.md` 를 채택한 skill 이 자기 표면에
# 압축 어휘를 갖는가. `test_proceed_gate_adopters.sh` 와 같은 골격이되 하한이 다르다.
#
# ── 하한이 2 가 아니라 1 인 이유 ────────────────────────────────────────────
# 형제 락의 하한 2 는 «두 skill 이 공유하니까 플러그인 레벨에 있다»는 배치 근거에서
# 나온다. 이 계약은 다르다 — **오늘 집행 대상은 seed 하나뿐**이고 brief 는 재구조화
# 이후에 채택한다(정본 자신이 그렇게 적는다). 하한 2 를 두면 정직한 상태에 RED 가 난다.
#
# **그래도 하한 1 은 둔다.** 두지 않으면 유일한 채택자가 포인터를 잃는 순간 도출 집합이
# 공집합이 되고 채택자별 루프가 0회 돌아 **vacuous GREEN** 이다. 하한 1 은 열거가
# 아니므로 둘째 채택자가 생겨도 그대로 작동한다.
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
if [ "$n_adopt" -lt 1 ]; then
  no "채택자 도출 ${n_adopt}개 — 유일한 채택자가 포인터를 잃으면 아래 루프가 0회 돌아 vacuous GREEN 이 된다"
  finish; exit $?
fi
ok "채택자 도출 ${n_adopt}개 (열거 아님 — 정본 포인터에서 도출, 하한 1 충족)"

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
