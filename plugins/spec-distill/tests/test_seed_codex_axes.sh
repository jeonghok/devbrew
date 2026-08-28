#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/run_seed_codex_reviewer.sh plugins/spec-distill/scripts/build_seed_codex_prompt.py plugins/spec-distill/scripts/seed-codex-suppression-checklist.md
#
# seed 억제 축의 **세 지점이 서로를 지탱하는가** — 러너의 fail-point · 빌더가 아는 축 ·
# 그 축의 체크리스트 파일 실재.
#
# **`build_brief_codex_prompt.py` 의 `AXES` 와 parity 를 재지 않는다.** 같은 이름이지만
# 뜻이 다르다: 그쪽은 brief 의 codex 프롬프트 축이고, `brief_review_state.py` 의 `AXES` 는
# degrade 원장의 `affected_axis` 이며, 러너의 `case` 는 실제 fail-point 다. 셋을 등식으로
# 묶으면 **술어 자체가 거짓**이 된다 — parity 락을 세우기 전에 두 열거가 같은 것을 뜻하는지
# 먼저 확인해야 한다는 규칙의 실사례다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
S="$ROOT/plugins/spec-distill/scripts"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/run_seed_codex_reviewer.sh"
  echo "plugins/spec-distill/scripts/build_seed_codex_prompt.py"
  echo "plugins/spec-distill/scripts/seed-codex-suppression-checklist.md"
  exit 0
fi

for f in run_seed_codex_reviewer.sh build_seed_codex_prompt.py seed-codex-suppression-checklist.md; do
  [ -f "$S/$f" ] && ok "실재: $f" || no "부재: $f"
done

# ① 러너가 축을 실제로 받는가 — 산문이 아니라 fail-point 로.
grep -qE "^\s*suppression\)" "$S/run_seed_codex_reviewer.sh" \
  && ok "러너 case 가 suppression 을 받는다" \
  || no "러너 case 에 suppression 갈래가 없다 — 호출이 exit 2 로 죽는다"

# ② 빌더가 그 축을 안다.
grep -qE "suppression" "$S/build_seed_codex_prompt.py" \
  && ok "빌더가 suppression 축을 안다" || no "빌더가 suppression 축을 모른다"

# ③ 체크리스트가 **네 축을 전부** 담는가. 하나라도 빠지면 codex 는 그 축을 안 본다.
cl="$S/seed-codex-suppression-checklist.md"
miss=0
for axis in '근거 없이 추가된 제약' '예시를 필수로 오인' '선택지를 조기에 닫는' '에이전트 추론'; do
  grep -qF -- "$axis" "$cl" || { no "체크리스트에 축 누락: ${axis}"; miss=$((miss + 1)); }
done
[ "$miss" -eq 0 ] && ok "체크리스트가 네 축을 전부 담는다"

# ④ 억제 축은 **판정에 합류하지 않는다** — 체크리스트가 verdict 를 요구하면 안 된다.
grep -qE '판정에 합류하지 않는다|verdict 를 내지 말' "$cl" \
  && ok "체크리스트가 verdict 금지를 명시한다" \
  || no "체크리스트에 verdict 금지가 없다 — findings 가 병합기 없이 사용자에게 가는 설계와 어긋난다"

# ⑤ vacuity 하한 — 체크리스트가 비면 위 ③ 이 공허하다.
n="$(wc -l < "$cl" | tr -d ' ')"
[ "${n:-0}" -ge 10 ] && ok "체크리스트 ${n}줄 (vacuous 아님)" \
                     || no "체크리스트가 ${n}줄뿐 — 축 검사가 공허하다"

finish
