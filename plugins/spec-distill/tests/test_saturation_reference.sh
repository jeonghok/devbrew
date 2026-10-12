#!/usr/bin/env bash
# R1(2026-10-12) — 조사 호출 상한 · 포화 판정 절차(SKILL 조사 상한 절 + references/saturation.md)의 존재 · 부재 락.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/spec-interview/SKILL.md"
SAT="$REPO_ROOT/plugins/spec-distill/skills/spec-interview/references/saturation.md"
FIN="$REPO_ROOT/plugins/spec-distill/skills/spec-interview/references/finishing.md"

[[ -f "$SAT" ]] && ok "saturation.md 실재" || { no "saturation.md 부재"; finish; exit; }
SAT_FLAT="$(tr '\n' ' ' < "$SAT" | tr -s ' ')"
cap_sec="$(awk '/^## 조사 상한 · 포화 판정/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
CAP_FLAT="$(tr '\n' ' ' <<<"$cap_sec" | tr -s ' ')"
[[ -n "$cap_sec" ]] && ok "SKILL: 조사 상한 · 포화 판정 절을 떴다" || no "SKILL: 조사 상한 · 포화 판정 절 부재 — 아래가 공허하다"

# G9 — 첫 조사 전 규모 공시, 승인 미요청
grep -qF '[spec-distill] 이 인터뷰는 조사 subagent 를 최대 <limit>회까지 부른다(웹 포함 · 승인 없이 진행 · 연장은 닿을 때 묻는다).' <<<"$CAP_FLAT" \
  && ok "G9: 첫 조사 전 규모 한 줄" || no "G9: 첫 조사 전 규모 한 줄 부재"
grep -qF '첫 조사 subagent dispatch 직전에' <<<"$CAP_FLAT" && ok "G9: 그 줄의 시점 = 첫 조사 dispatch 직전" || no "G9: 시점 문구 부재"
grep -qF '승인은 묻지 않는다' <<<"$CAP_FLAT" && ok "G9: 승인을 묻지 않는다" || no "G9: 승인 미요청 문구 부재"
# 부르기 기준 · 계수 · 원문 보존
grep -qF '열린 결정을 바꾸거나 새 결정을 열 수 있다고 볼 때마다' <<<"$CAP_FLAT" && ok "§1: 부르기 기준" || no "§1: 부르기 기준 부재"
grep -qF '상한에는 세지 않는다' <<<"$CAP_FLAT" && ok "B4: 본체 직접 조사 · 판정자는 상한에 세지 않는다" || no "B4: 계수 대상 문구 부재"
grep -qF 'Read ${CLAUDE_PLUGIN_ROOT}/skills/spec-interview/references/saturation.md' "$SKILL" \
  && ok "SKILL → saturation.md 포인터" || no "SKILL → saturation.md 포인터 부재"
# 상한 도달 — 세 선택지 · 도달 줄 · 하한도 멈춘다
grep -qF '[spec-distill] 조사 호출 상한 도달 — <n>/<limit>. 연장 · 판정 · 종료 중 고르세요.' <<<"$SAT_FLAT" && ok "G4: 상한 도달 한 줄" || no "G4: 상한 도달 한 줄 부재"
CAPHIT_FLAT="$(awk '/^### 상한 도달/{f=1;print;next} /^### /{f=0} f' "$SAT" | tr '\n' ' ' | tr -s ' ')"
[[ -n "$CAPHIT_FLAT" ]] && ok "G4: 상한 도달 절을 떴다" || no "G4: 상한 도달 절 부재 — 아래 선택지 락이 공허하다"
grep -qF 'state 를 처음 만들 때' <<<"$CAP_FLAT" && ok "RF2: SKILL 이 state 생성 때 상한 시작값을 정한다" || no "RF2: state 생성 때 시작값 문구 부재"
head -6 "$SAT" | tr '\n' ' ' | grep -qF 'state 를 처음 만들 때' && ok "RF2: saturation.md 첫 문단이 state 생성 때를 읽는 때로 든다" || no "RF2: saturation.md 첫 문단에 state 생성 때 부재"
grep -qF '재개방되지 않았으면 바로' <<<"$SAT_FLAT" && ok "D23: 빈 곳 조사 뒤 판정자 재호출 시점" || no "D23: 판정자 재호출 시점 부재"
for o in '같은 크기만큼 연장' '지금 포화 판정으로' '인터뷰 종료'; do
  grep -qF "「${o}」" <<<"$CAPHIT_FLAT" && ok "G4: 선택지 «${o}»" || no "G4: 선택지 «${o}» 부재"
done
grep -qF '하한 자리도 상한 앞에서 멈춘다' <<<"$SAT_FLAT" && ok "RF4: 하한 자리도 상한 앞에서 멈춘다" || no "RF4: 하한 vs 상한 규칙 부재"
grep -qF '양의 정수가 아니면 20 으로 두고' <<<"$SAT_FLAT" && grep -qF '양의 정수가 아니면 5 로 두고' <<<"$SAT_FLAT" \
  && ok "RF2: 환경 변수 이상값 → 기본값 + 한 줄" || no "RF2: 이상값 처리 문구 부재"
# 포화 판정 — dispatch · 기준 · 반복 감지 · 판정 불가 · 판정 상한
grep -qF 'subagent_type: "spec-distill:saturation-judge"' "$SAT" && ok "D23: 판정자 dispatch" || no "D23: 판정자 dispatch 부재"
grep -qF '**처분** — consumer=orchestrator · fail-closed · disclosure=포화 판정 불가 공시 + 사용자 선택' "$SAT" \
  && ok "RC18: 판정자 처분 줄" || no "RC18: 판정자 처분 줄 부재"
grep -qF '최근 조사 두 번' <<<"$SAT_FLAT" && ok "AC4: 최근 조사 두 번 기준" || no "AC4: 최근 조사 두 번 기준 부재"
grep -qF '요약으로 대신하지 않는다' <<<"$SAT_FLAT" && ok "RF1: 원문 블록이 없으면 요약으로 대신하지 않는다" || no "RF1: 원문 대체 금지 부재"
grep -qF '`may_change` 결정 집합과 `device` 가 둘 다 같으면' <<<"$SAT_FLAT" && ok "D2.5: 반복 감지 기준" || no "D2.5: 반복 감지 기준 부재"
grep -qF '[spec-distill] 포화 판정 불가 — <사유>' <<<"$SAT_FLAT" && ok "판정 불가 한 줄" || no "판정 불가 한 줄 부재"
grep -qF '[spec-distill] 포화 판정 상한 도달 — <k>/<limit>. 연장 · 포화로 보고 종료 · 인터뷰 종료 중 고르세요.' <<<"$SAT_FLAT" \
  && ok "D2.5: 판정 상한 도달 한 줄" || no "D2.5: 판정 상한 도달 한 줄 부재"
# audit §2 줄 형식 — 게이트(check_brief.py)가 읽는 그 글자
for ln in '- 조사 호출 <n>/<limit> (장치별: 커버리지 <a> · 맹점 <b> · 반론 <c> · 레포 조사 <d> · 본체 직접 <e>)' \
          '- 상한 도달 <n>/<limit> — 사용자 선택 S<m>: 연장 | 판정으로 | 인터뷰 종료' \
          '- 판정 상한 도달 <k>/<limit> — 사용자 선택 S<m>: 연장 | 포화로 보고 종료 | 인터뷰 종료' \
          '- 포화 판정 <k>: 포화 — <basis 요지>' '- 포화 판정 <k>: 아직 — 빈 곳 <g>개' \
          '- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — <반복 빈 곳 | 판정 불가(<사유>) | 판정 상한>' \
          '- 포화 판정 <k>: 판정 불가(<사유>) — 조사 계속(@S<m>)' '- 포화 판정 <k>: 아직 — 반복 빈 곳 재조사(@S<m>)' \
          '- 사용자 종료(@S<m>) — 포화 판정 전' '- 사용자 종료(@S<m>) — 마지막 판정 아직'; do
  grep -qF -- "$ln" "$SAT" && ok "§4 줄: ${ln:0:40}…" || no "§4 줄 부재: $ln"
done
# 이중 종료 — finishing.md 의 종료 driver
grep -qF '마지막 포화 판정이 «포화»' "$FIN" && ok "B5: finishing 종료 driver 가 포화 판정을 요구" || no "B5: finishing 종료 driver 에 포화 판정 부재"
# 부재 — 금지 토큰이 새 표면에 없다
for tok in '판정자 조건' '판정자 투입' '다시 묻지 않는다' 'probe''_count' 'web''_budget' 'interview''_round'; do  # 잔재 락(test_probe_sweep_residue.sh)이 이 파일을 스캔하므로 토큰을 둘로 쪼갠다
  grep -qF -- "$tok" "$SAT" && no "부재: saturation.md 에 «${tok}»" || ok "부재: saturation.md 에 «${tok}» 없음"
done
grep -qE '최대 [0-9]+회|[0-9]+회까지' "$SAT" && no "부재: saturation.md 에 숫자 횟수 상한 표현" || ok "부재: 숫자 횟수 상한 표현 없음"
finish
