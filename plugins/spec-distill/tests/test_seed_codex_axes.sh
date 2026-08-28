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

# ── fix round 1 (Important 3) ────────────────────────────────────────────────
# 위 ①~⑤는 전부 **정적** grep이다 — 세 파일이 "이 단어를 담고 있다"만 재고,
# 러너가 실제로 codex를 부르는지·빌더가 실제로 checklist 내용을 프롬프트에
# 옮기는지는 아무것도 재지 않는다. 리뷰가 실측으로 보였다: 세 파일을 전부 속이
# 빈 decoy(4줄 case문 하나 · 주석 한 줄 · 리터럴만 나열한 11줄)로 바꿔도 위
# 여덟 assertion이 8/8 GREEN이었다. 형제 test_brief_codex_axes.sh는 처음부터
# 이 함정을 피한다 — body-unique 마커를 체크리스트에 심고, 빌더를 **실행**해
# 그 마커가 출력에 실제로 실리는지 보고, 러너도 mock codex로 **실행**해 계약을
# 확인한다. 아래는 같은 원리를 이 축(하나뿐인 suppression)에 맞춰 좁힌 것이다.
MK='AXIS-MARKER: seed-suppression-axis-only'

[ "$(grep -cF "$MK" "$cl")" = "1" ] && ok "체크리스트에 body-unique 마커 1회 실재" \
                                     || no "체크리스트 마커가 없거나 중복"

# 형제 brief 체크리스트로 마커가 새면 축 귀속이 흐려진다(교차 오염 부재 확인).
leaked=0
for other in "$S"/brief-codex-*-checklist.md; do
  [ -f "$other" ] || continue
  grep -qF "$MK" "$other" && leaked=$((leaked + 1))
done
[ "$leaked" -eq 0 ] && ok "형제 brief 체크리스트에 seed 마커 오염 없음" \
                     || no "형제 brief 체크리스트 ${leaked}곳에 seed 마커가 새어 있다"

# 빌더를 실제로 실행해 마커 + payload 본문이 출력에 실리는가 — 정적 grep이
# 아니라 실행 관측. 빌더가 checklist를 무시하고 다른 텍스트를 내도(또는 빌더
# 자체가 decoy라 출력이 비어도) 위 정적 검사는 못 잡지만 이건 잡는다.
PAY="$(mktemp -t sd-seed-axes-payload-XXXXXX)" || PAY=""
if [ -z "$PAY" ]; then
  no "payload 임시파일 생성 실패 — 아래 빌더 실행 검증을 건너뛴다"
else
  printf '## 초안\n\nSEED_AXES_LOCK_PAYLOAD_MARKER 로그인이 가끔 실패한다.\n' > "$PAY"
  builder_out="$(cd "$S" && python3 build_seed_codex_prompt.py --axis suppression "$PAY" 2>/dev/null)" || builder_out=""
  if [ -z "$builder_out" ]; then
    no "빌더 실행 출력이 비었다 — --axis suppression 이 프롬프트를 못 낸다"
  else
    grep -qF "$MK" <<<"$builder_out" \
      && ok "빌더 실행 출력에 checklist 마커 실재(실행 관측)" \
      || no "빌더 실행 출력에 checklist 마커가 없다 — checklist 내용이 실제로 프롬프트에 안 실린다"
    grep -qF "SEED_AXES_LOCK_PAYLOAD_MARKER" <<<"$builder_out" \
      && ok "빌더 실행 출력에 payload 본문 실재" \
      || no "빌더 실행 출력에 payload 본문이 없다 — 위 마커 판정이 무의미하다"
  fi
  rm -f "$PAY"
fi

# 러너를 mock codex로 실제로 한 번 실행해, 해피 패스가 선-기록 값
# (`reason: runner_incomplete`)에서 벗어나는지 잰다. 정적 검사 ①은 case
# 라벨의 존재만 재므로 러너를 4줄짜리 decoy(라벨만 있고 그 뒤로 아무 것도
# 안 함)로 바꿔도 통과한다 — 실행 결과로 판정을 옮긴다.
#
# fix round 2 (Important 3 잔여) — 위 "선-기록 값에서 벗어났는가"만으로는
# **산출물의 출처**를 못 잰다. 리뷰어 재현: case 라벨만 받고 빌더도 codex도
# 전혀 안 부른 채 `findings: []` + `codex_failed: false` + 그럴듯한 reason을
# 직접 써버리는 러너가 이 검사를 그대로 통과했다(13/13 GREEN) — "값이
# runner_incomplete 가 아니다"는 "codex 가 실제로 호출됐다"의 증거가 아니다.
# 그래서 mock codex 자신이 **자기 호출 여부를 기록**하게 한다(sentinel 파일) —
# 산출물을 조작해도 codex 를 안 불렀으면 sentinel 이 없다. mock 이 sentinel 을
# 쓰는 시점은 JSONL 을 내기 **전**이라, 그 뒤 추출 단계가 어떻게 실패해도
# "codex 가 불렸다"는 사실 자체는 남는다.
RUNBIN="$(mktemp -d -t sd-seed-axes-bin-XXXXXX)" || RUNBIN=""
if [ -z "$RUNBIN" ]; then
  no "mock codex bindir 생성 실패 — 아래 러너 실행 검증을 건너뛴다"
else
  SENTINEL="$RUNBIN/codex.invoked"
  cat > "$RUNBIN/codex" <<'MOCKEOF'
#!/usr/bin/env bash
[ -n "${CODEX_MOCK_SENTINEL:-}" ] && : > "$CODEX_MOCK_SENTINEL"
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": []}\n```"}}
JSONL
exit 0
MOCKEOF
  chmod +x "$RUNBIN/codex"
  RPAY="$(mktemp -t sd-seed-axes-runpayload-XXXXXX)" || RPAY=""
  ROUT="$(mktemp -t sd-seed-axes-runout-XXXXXX)" || ROUT=""
  if [ -z "$RPAY" ] || [ -z "$ROUT" ]; then
    no "러너 실행 스크래치 생성 실패 — 아래 검증을 건너뛴다"
  else
    rm -f "$ROUT" "$SENTINEL"
    printf '## 초안\n\n로그인이 가끔 실패한다.\n' > "$RPAY"
    PATH="$RUNBIN:$PATH" CLAUDE_PLUGIN_ROOT="$ROOT/plugins/spec-distill" CODEX_MOCK_SENTINEL="$SENTINEL" \
      bash "$S/run_seed_codex_reviewer.sh" suppression "$RPAY" "$ROOT" "$ROUT" >/dev/null 2>&1
    if [ ! -s "$ROUT" ]; then
      no "러너 실행 후 산출물이 없거나 비었다 — fail-closed 계약 위반이거나 러너가 실질적으로 아무 것도 안 한다"
    elif grep -q 'reason: runner_incomplete' "$ROUT"; then
      no "러너가 선-기록 값(runner_incomplete)에서 벗어나지 못했다 — 실행이 끝까지 진행되지 않았다"
    else
      ok "러너가 mock codex로 실제로 끝까지 진행됐다(선-기록 값에서 벗어남)"
    fi
    [ -f "$SENTINEL" ] \
      && ok "mock codex가 실제로 호출됐다(sentinel 실재) — 산출물이 codex 실행 없이 조작되지 않았다" \
      || no "mock codex가 호출되지 않았다(sentinel 부재) — 산출물이 codex 없이 조작됐을 수 있다"
    rm -f "$RPAY" "$ROUT" "$SENTINEL"
  fi
  rm -rf "$RUNBIN"
fi

finish
