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
#
# **정직한 경계 — 이 락이 재는 것과 못 재는 것.** sentinel 이 재려는 것은
# 「codex 가 호출됐는가」 하나뿐이고, 그것조차 러너가 위조할 수 있다(②). 아래
# 세 모양은 전부 실제로 러너를 갈아끼워 실행해 관측했다:
#   ① codex 를 그대로 부르되(sentinel 이 남는다) 그 응답을 버리고 별도의
#      조작된 YAML(`reason: fabricated_but_codex_was_called`)을 직접 써버리는
#      러너 → 14/14 GREEN. 「그 호출의 **출력이 쓰였는가**」는 안 잰다.
#   ② **codex 를 아예 부르지 않는** 러너 — `${CODEX_MOCK_SENTINEL:-}` 를 자기
#      환경변수에서 직접 읽어 `: > "$CODEX_MOCK_SENTINEL"` 한 줄만 실행하고
#      끝낸다. codex exec 도, mock 실행도, 어떤 부수효과도 없다 → **여전히
#      14/14 GREEN.** ②가 ①보다 싸다(호출 자체가 없다) — 그러니 "codex 호출의
#      부수효과(과금·요청 로그)가 방어선"이라는 말은 성립하지 않는다: ②엔 그
#      부수효과가 애초에 없다.
#   ③ 진짜로 mock codex 를 부르고(sentinel 이 남는다) 그 **진짜 응답을 추출기로
#      태우면서**, 프롬프트는 payload 를 한 글자도 읽지 않는 고정 리터럴인 러너
#      → **14/14 GREEN.** ③의 본문엔 `CODEX_MOCK_SENTINEL` 이 한 번도 안 나온다.
#   **못 잡는 범위는 하한으로만 적을 수 있다.** ②가 드러내는 부류("sentinel 을
#   스스로 위조할 수 있는 러너")는 이 락이 못 잡는 것들의 **하한**이지 전체가
#   아니다 — ③이 그 밖에 있다. 등식으로 적으면 다시 틀린다.
#   **왜 ②가 가능한가**: `CODEX_MOCK_SENTINEL` 은 아래에서 러너를 부르는 **명령
#   앞 env prefix** 로 들어간다 — `CODEX_MOCK_SENTINEL="$SENTINEL" bash
#   "$S/run_seed_codex_reviewer.sh" …` 모양이라, mock codex 자식에만 scope 되지
#   않고 러너 프로세스 자신의 환경에 들어간다. 즉 **측정 대상인 러너가 그 anchor
#   를 볼 수 있고, 보는 대상은 스스로 쓸 수 있다.** 더 강한 설계라면 이 가시성부터
#   끊어야 한다(예: 러너는 값을 모른 채 mock 자식에만 닿는 채널 — fd 상속·소켓 등).
#   **그 강화가 닫는 것은 ②뿐이다**: 경로를 mock 에 박아 넣고 러너 환경에서 그
#   변수를 지운 채 ③을 돌려봤더니 sentinel 은 그대로 남았고 산출물도 선-기록
#   값(runner_incomplete)을 벗어났다 — ③은 sentinel 을 건드리지 않으므로 이
#   강화가 ③에는 닿지 않는다.
#   **아무도 안 재는 세 번째 축**: 「codex 가 호출됐는가」·「그 출력이
#   쓰였는가」 다음에 「**그 호출의 입력이 실제 payload 에서 파생됐는가**」가
#   있다. 위 빌더 실행 검사는 이 테스트가 빌더를 **직접** 불러 재는 것이라 러너가
#   빌더를 건너뛰어도 그대로 GREEN 이다(③이 그 실증) — 러너 수준에서 이 축을 재는
#   단언은 이 파일에 없다. 이 축은 여기서 더 쫓지 않는다(컨트롤러 판정 — 원장에
#   parked) — 이 문단이 그 경계를 다음 독자가 찾을 자리에 남긴다.
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
