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
grep -qF '[spec-distill] 이 인터뷰는 조사 agent 를 최대 <limit>번까지 부른다(agent 안의 검색 · 출처 수는 세지 않는다 · 멈춤은 포화 판정이 정하고 이 수는 비상 끝 · 승인 없이 진행 · 닿으면 연장을 묻는다).' <<<"$CAP_FLAT" \
  && ok "G9/AC6: 첫 조사 전 규모 한 줄(조사 agent · 비상 끝 · 검색 · 출처 수는 세지 않는다)" || no "G9/AC6: 첫 조사 전 규모 한 줄 부재"
# 음의 짝 — 위 리터럴이 양의 짝이다. 「웹 포함」은 agent 안 검색을 세는 것처럼 읽힌다.
grep -qF '웹 포함' <<<"$CAP_FLAT" && no "AC6: 「웹 포함」 잔존" || ok "AC6: 조사 상한 절에 「웹 포함」 없음"
grep -qF '첫 조사 agent dispatch 직전에' <<<"$CAP_FLAT" && ok "G9: 그 줄의 시점 = 첫 조사 dispatch 직전" || no "G9: 시점 문구 부재"
# AC4 — 세는 것 · 세지 않는 것
grep -qF '한 메시지에서 여럿을 띄우면 띄운 수만큼' <<<"$CAP_FLAT" && ok "AC4: 함께 띄우면 띄운 수만큼 센다" || no "AC4: 함께 띄운 조사의 계수 문구 부재"
grep -qF '`SendMessage` 로 이어 부르면 새 조사라 1 이다' <<<"$CAP_FLAT" && ok "AC4: 이어 부르기도 1" || no "AC4: 이어 부르기 계수 문구 부재"
grep -qF 'agent 안의 검색 횟수 · 출처 수는 세지 않는다' <<<"$CAP_FLAT" && ok "AC4: agent 안 검색 · 출처 수는 세지 않는다" || no "AC4: agent 안 검색 · 출처 수 비계수 문구 부재"
# 묶음 표지 머리는 SKILL 에 두 자리(State body 정의 · 조사 상한 절)다 — 파일 전체 grep 은 한쪽을 지워도 통과하므로 자리마다 잰다.
HDR='### 조사 <n> — <장치> · R<round> · 묶음 <b>'
grep -qF "$HDR" <<<"$(awk '/^State body:/' "$SKILL")" && ok "§1: State body 정의의 블록 머리에 묶음 표지" || no "§1: State body 정의의 블록 머리에 묶음 표지 부재"
grep -qF "$HDR" <<<"$CAP_FLAT" && ok "§1: 조사 상한 절의 블록 머리에 묶음 표지" || no "§1: 조사 상한 절의 블록 머리에 묶음 표지 부재"
# 판정자가 묶음 번호 순서 어긋남을 잡는 근거 — 본체가 다는 번호는 1부터 순증한다.
grep -qF '`<b>` 는 인터뷰 안 1부터 순증하는 묶음 번호다' <<<"$CAP_FLAT" && ok "§1: 묶음 번호는 인터뷰 안 1부터 순증" || no "§1: 묶음 번호 순증 문구 부재"
grep -qF "\`${HDR}\` 블록(묶음 표지 없는 옛 블록도 그대로)을 번호 순으로" <<<"$SAT_FLAT" \
  && ok "§1: 판정자 입력 레시피가 새 머리와 옛 블록을 함께 싣는다" || no "§1: 판정자 입력 레시피의 블록 머리 · 옛 블록 문구 부재"
# 묶음 멈춤 규칙(saturation.md ### 상한 도달)이 실제로 읽히는 때 — 합이 닿기 전에도 묶음이 남은 수보다 크면 읽는다.
BATCH_TRIG='한 메시지에서 띄우려는 묶음이 남은 호출 수(`research_limit` − 합)보다 클 때(띄우기 전에)'
grep -qF "$BATCH_TRIG" <<<"$CAP_FLAT" && ok "§2: SKILL 이 묶음이 남은 수보다 클 때 saturation.md 를 읽는다" || no "§2: SKILL 의 묶음 읽기 때 부재 — 58/60 에서 셋을 띄우면 규칙이 안 읽힌다"
grep -qF "$BATCH_TRIG" <<<"$(awk 'NR>2&&/^$/{exit} NR>2' "$SAT" | tr '\n' ' ' | tr -s ' ')" \
  && ok "§2: saturation.md 첫 문단의 읽는 때에 묶음 때" || no "§2: saturation.md 첫 문단에 묶음 읽기 때 부재"
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
# 같은 문구가 «아직» 절과 «판정 불가» 절 둘에 있다 — 통째 grep 은 한쪽을 지워도 통과한다. 절마다 따로 잰다.
UNK_FLAT="$(awk '/^### 판정 불가/{f=1;print;next} /^### /{f=0} f' "$SAT" | tr '\n' ' ' | tr -s ' ')"
[[ -n "$UNK_FLAT" ]] && ok "D23: 판정 불가 절을 떴다" || no "D23: 판정 불가 절 부재 — 아래 락이 공허하다"
grep -qF '재개방되지 않았으면 바로' <<<"$UNK_FLAT" && ok "D23: 판정 불가 절의 판정자 재호출 시점" || no "D23: 판정 불가 절에 판정자 재호출 시점 부재"
NOTYET_FLAT="$(awk '/^### 포화 판정/{f=1;print;next} /^### /{f=0} f' "$SAT" | tr '\n' ' ' | tr -s ' ')"
[[ -n "$NOTYET_FLAT" ]] && ok "D23: 포화 판정 절을 떴다" || no "D23: 포화 판정 절 부재 — 아래 락이 공허하다"
grep -qF '재개방되지 않았으면 바로' <<<"$NOTYET_FLAT" && ok "D23: 포화 판정(아직) 절의 판정자 재호출 시점" || no "D23: 포화 판정 절에 판정자 재호출 시점 부재"
for o in '같은 크기만큼 연장' '지금 포화 판정으로' '인터뷰 종료'; do
  grep -qF "「${o}」" <<<"$CAPHIT_FLAT" && ok "G4: 선택지 «${o}»" || no "G4: 선택지 «${o}» 부재"
done
# §2 — 남은 호출 수보다 큰 묶음은 통째로 멈춘다(잘라 보내면 독립 질문 일부가 조용히 빠진다).
grep -qF '그 묶음의 어느 것도 띄우기 전에 멈춘다' <<<"$CAPHIT_FLAT" && ok "§2: 남은 수보다 큰 묶음은 띄우기 전에 멈춘다" || no "§2: 묶음 멈춤 문구 부재"
grep -qF '일부만 띄우지 않는다' <<<"$CAPHIT_FLAT" && ok "§2: 묶음을 일부만 띄우지 않는다" || no "§2: 일부 dispatch 금지 문구 부재"
grep -qF '`<n>/<limit>` 뒤에 `, 띄우려는 <k>개가 남은 <r>번보다 많다` 를 붙인다' <<<"$CAPHIT_FLAT" \
  && ok "§2: 묶음으로 멈춘 도달 줄은 묶음 크기 · 남은 수를 보인다" || no "§2: 묶음 멈춤 도달 줄의 크기 · 남은 수 문구 부재"
grep -qF '연장해도 묶음이 남은 호출 수보다 크면 띄우지 않고 위 한 줄을 다시 내고 다시 묻는다' <<<"$CAPHIT_FLAT" \
  && ok "§2: 연장 뒤에도 묶음이 안 맞으면 다시 묻는다" || no "§2: 연장 뒤 재질문 문구 부재"
grep -qF '하한 자리도 상한 앞에서 멈춘다' <<<"$SAT_FLAT" && ok "RF4: 하한 자리도 상한 앞에서 멈춘다" || no "RF4: 하한 vs 상한 규칙 부재"
grep -qF '양의 정수가 아니면 60 으로 두고' <<<"$SAT_FLAT" && grep -qF '양의 정수가 아니면 5 로 두고' <<<"$SAT_FLAT" \
  && ok "RF2: 환경 변수 이상값 → 기본값 + 한 줄" || no "RF2: 이상값 처리 문구 부재"
# 포화 판정 — dispatch · 기준 · 반복 감지 · 판정 불가 · 판정 상한
grep -qF 'subagent_type: "spec-distill:saturation-judge"' "$SAT" && ok "D23: 판정자 dispatch" || no "D23: 판정자 dispatch 부재"
grep -qF '**처분** — consumer=orchestrator · fail-closed · disclosure=포화 판정 불가 공시 + 사용자 선택' "$SAT" \
  && ok "RC18: 판정자 처분 줄" || no "RC18: 판정자 처분 줄 부재"
grep -qF '최근 조사 두 묶음' <<<"$SAT_FLAT" && ok "AC7: 최근 조사 두 묶음 기준" || no "AC7: 최근 조사 두 묶음 기준 부재"
grep -qF '최근 조사 두 번' <<<"$SAT_FLAT" && no "AC7: 「최근 조사 두 번」 잔존" || ok "AC7: 「최근 조사 두 번」 없음"
# AC15 — 판단만 남은 경로: 판정자는 그대로 부르고, 사용자가 「조사 불필요」를 고르면 사용자 판단 포화로 닫는다.
for lit in '「조사 불필요 — 판단만 남음」' \
           '`- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — 조사 불필요`' \
           '남은 열린 결정이 모두 사용자의 판단 · 선호이고 조사로 답할 사실 질문이 없으면' \
           '빈 곳이 「조사가 두 묶음 미만」 하나뿐인데' \
           '반복 감지 · 빈 곳 조사로 가기 전에' \
           '그 이유는 남은 열린 결정마다 `OQ<n>` 을 들고 왜 사용자의 판단 · 선호이며 조사로 답할 사실 질문이 없는지를 한 줄씩 적는다' \
           '남은 열린 결정 중 하나라도 사실 부분이 있으면 이 선택지를 내지 않는다' \
           '판정자는 그대로 부른다'; do
  grep -qF -- "$lit" <<<"$NOTYET_FLAT" && ok "AC15: 포화 판정 절에 «${lit}»" || no "AC15: 포화 판정 절에 «${lit}» 부재"
done
grep -qF '요약으로 대신하지 않는다' <<<"$SAT_FLAT" && ok "RF1: 원문 블록이 없으면 요약으로 대신하지 않는다" || no "RF1: 원문 대체 금지 부재"
grep -qF '`may_change` 결정 집합과 `device` 가 둘 다 같으면' <<<"$SAT_FLAT" && ok "D2.5: 반복 감지 기준" || no "D2.5: 반복 감지 기준 부재"
grep -qF '[spec-distill] 포화 판정 불가 — <사유>' <<<"$SAT_FLAT" && ok "판정 불가 한 줄" || no "판정 불가 한 줄 부재"
grep -qF '[spec-distill] 포화 판정 상한 도달 — <k>/<limit>. 연장 · 포화로 보고 종료 · 인터뷰 종료 중 고르세요.' <<<"$SAT_FLAT" \
  && ok "D2.5: 판정 상한 도달 한 줄" || no "D2.5: 판정 상한 도달 한 줄 부재"
# audit §2 줄 형식 — 게이트(check_brief.py)가 읽는 그 글자
for ln in '- 조사 호출 <n>/<limit> (장치별: 커버리지 <a> · 맹점 <b> · 반론 <c> · 레포 조사 <d> · 만든 조사 <o> · 본체 직접 <e>)' \
          '- 상한 도달 <n>/<limit> — 사용자 선택 S<m>: 연장 | 판정으로 | 인터뷰 종료' \
          '- 판정 상한 도달 <k>/<limit> — 사용자 선택 S<m>: 연장 | 포화로 보고 종료 | 인터뷰 종료' \
          '- 포화 판정 <k>: 포화 — <basis 요지>' '- 포화 판정 <k>: 아직 — 빈 곳 <g>개' \
          '- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — <반복 빈 곳 | 판정 불가(<사유>) | 판정 상한 | 조사 불필요>' \
          '- 포화 판정 <k>: 판정 불가(<사유>) — 조사 계속(@S<m>)' '- 포화 판정 <k>: 아직 — 반복 빈 곳 재조사(@S<m>)' \
          '- 사용자 종료(@S<m>) — 포화 판정 전' '- 사용자 종료(@S<m>) — 마지막 판정 아직'; do
  grep -qF -- "$ln" "$SAT" && ok "§4 줄: ${ln:0:40}…" || no "§4 줄 부재: $ln"
done
# 이중 종료 — finishing.md 의 종료 driver
grep -qF '마지막 포화 판정이 «포화»' "$FIN" && ok "B5: finishing 종료 driver 가 포화 판정을 요구" || no "B5: finishing 종료 driver 에 포화 판정 부재"
# I1(최종 리뷰) — 인터뷰 중에는 audit 파일이 없다. 게이트를 정하는 줄은 사건 순간 state 본문 블록에 글자 그대로
# 쌓고, finishing Step A ④ 가 그 블록을 옮긴다. 압축 · 재개 뒤 기억으로 다시 짓는 길을 막는다.
SKILL_FLAT="$(tr '\n' ' ' < "$SKILL" | tr -s ' ')"
EXIT_FLAT="$(awk '/^### 나가는 문은 floor 뒤에만 있지 않다/{f=1;print;next} /^##/{f=0} f' "$SKILL" | tr '\n' ' ' | tr -s ' ')"
[[ -n "$EXIT_FLAT" ]] && ok "I1: SKILL 나가는 문 절을 떴다" || no "I1: SKILL 나가는 문 절 부재 — 아래 락이 공허하다"
PEND='`## audit §2 대기 줄` 에 덧붙인다(종료 때 audit §2 로 옮긴다)'
grep -qF "$PEND" <<<"$SAT_FLAT" && ok "I1: saturation.md 가 사건 줄을 state 대기 줄 블록에 덧붙인다" || no "I1: saturation.md 에 대기 줄 블록 문구 부재"
grep -qF "$PEND" <<<"$EXIT_FLAT" && ok "I1: SKILL 나가는 문의 사용자 종료 줄도 대기 줄 블록으로" || no "I1: SKILL 나가는 문에 대기 줄 블록 문구 부재"
grep -qF '## audit §2 대기 줄' <<<"$(awk '/^State body:/' "$SKILL")" && ok "I1: SKILL state 본문 정의에 대기 줄 블록" || no "I1: SKILL state 본문 정의에 대기 줄 블록 부재"
# 부재(위 셋이 양의 짝) — 인터뷰 중 «audit §2 에 `- …` 를 남긴다» 지시가 사라졌다.
grep -qF 'audit §2 에 `-' <<<"$SAT_FLAT" && no "I1: saturation.md 가 아직 인터뷰 중 audit §2 에 직접 쓰라고 한다" || ok "I1: saturation.md 에 인터뷰 중 audit §2 직접 쓰기 없음"
grep -qF 'audit §2 에 `-' <<<"$SKILL_FLAT" && no "I1: SKILL 이 아직 인터뷰 중 audit §2 에 직접 쓰라고 한다" || ok "I1: SKILL 에 인터뷰 중 audit §2 직접 쓰기 없음"
FIN4="$(awk '/^4\. \*\*Coverage Ledger 직렬화/{f=1;print;next} /^5\. /{f=0} f' "$FIN" | tr '\n' ' ' | tr -s ' ')"
[[ -n "$FIN4" ]] && ok "I1: finishing Step A ④ 를 떴다" || no "I1: finishing Step A ④ 부재 — 아래 락이 공허하다"
grep -qF '`## audit §2 대기 줄` 블록을 글자 그대로 순서대로 옮겨 씁니다' <<<"$FIN4" \
  && ok "I1: finishing ④ 가 대기 줄 블록을 글자 그대로 옮긴다" || no "I1: finishing ④ 에 대기 줄 블록 이송 부재"
grep -qF 'user_choice: S<m>' <<<"$SAT_FLAT" && ok "I1: 사용자 선택이 saturation_log.user_choice 에 적힌다" || no "I1: user_choice 설정 문구 부재"
grep -qF '{k, round, verdict: unavailable, reason, user_choice}' <<<"$SAT_FLAT" && ok "I1: 판정 불가도 saturation_log 한 항목" || no "I1: 판정 불가 항목 형식 부재"
grep -qF '판정자 호출 수는 `saturation_log` 항목 수다' <<<"$SAT_FLAT" && ok "I1: 판정 불가도 판정 상한에 센다" || no "I1: 판정자 호출 수 정의 부재"
grep -qE '^ +saturation_log: \[\] +#.*basis.*user_choice' <<<"$(awk '/^State frontmatter schema:/{f=1;next} f&&/^---$/{n++} f&&n<2' "$SKILL")" \
  && ok "I1: SKILL 스키마의 saturation_log 에 basis" || no "I1: SKILL 스키마의 saturation_log 에 basis 부재"
# I2 — 판정마다 사용자에게 한 줄(판정 · 빈 곳 수 · 다음에 볼 것 · 호출 수).
grep -qF '[spec-distill] 포화 판정 <k>/<saturation_limit>: <포화 | 아직 — 빈 곳 <g>개, 다음: <첫 look_at>> · 조사 호출 <n>/<limit>' <<<"$NOTYET_FLAT" \
  && ok "I2: 포화 판정 절이 판정마다 보이는 한 줄을 낸다" || no "I2: 판정 결과 보이는 한 줄 부재"
grep -qF '같은 줄을 그 라운드의 «지금 이해»에도 싣는다' <<<"$NOTYET_FLAT" && ok "I2: 라운드가 이어지면 «지금 이해»에도" || no "I2: «지금 이해» 싣기 부재"
# I3 — 본체 직접 조사의 원문 블록 = V1 확인 줄 · 웹 항목 줄 그대로(산문 요약 아님).
ORCH='`device: orchestrator` 의 원문 블록은 V1 확인 줄(`- 확인 RC<n> — …`)과 웹 항목 줄 그대로다'
grep -qF "$ORCH" <<<"$CAP_FLAT" && ok "I3: SKILL 이 본체 직접 조사 블록 내용을 정한다" || no "I3: SKILL 에 본체 직접 조사 블록 내용 부재"
grep -qF "$ORCH" <<<"$SAT_FLAT" && ok "I3: saturation.md 입력 레시피가 같은 규칙" || no "I3: saturation.md 에 본체 직접 조사 블록 내용 부재"
# M2 — 상한 값 펜스를 실제로 돌린다: 0 · 00 · 음수 · 문자는 기본값, 앞자리 0 은 10진 정규화.
LIM_FENCE="$(awk '/^### 상한 값/{f=1;next} /^### /{f=0} f&&/^```bash$/{b=1;next} f&&b&&/^```$/{exit} f&&b' "$SAT")"
{ [[ -n "$LIM_FENCE" ]] && bash -n <<<"$LIM_FENCE"; } && ok "M2(양성대조): 상한 값 펜스를 떴고 bash -n 통과" || no "M2: 상한 값 펜스 부재 또는 구문 오류"
for pair in '00|60|5' '0|60|5' '-3|60|5' 'abc|60|5' '007|7|7' '3|3|3' '|60|5'; do
  v="${pair%%|*}"; rest="${pair#*|}"; er="${rest%%|*}"; es="${rest#*|}"
  got="$(DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT="${v}" DEVBREW_SPEC_DISTILL_SATURATION_LIMIT="${v}" bash -c "$LIM_FENCE" 2>/dev/null)"
  [[ "$got" == "research_limit=${er} saturation_limit=${es}" ]] && ok "M2: 값 '${v}' → ${er} · ${es}" || no "M2: 값 '${v}' → «${got}» (기대 ${er} · ${es})"
done
# M3 — 이월 전 조사는 번호가 없다: 판정 불가는 번호 있는 research_log 항목의 블록이 빠졌을 때만.
MIG="$REPO_ROOT/plugins/spec-distill/skills/spec-interview/references/state-migration.md"
MIG_FLAT="$(tr '\n' ' ' < "$MIG" | tr -s ' ')"
grep -qF '번호가 있는 `research_log` 항목' <<<"$SAT_FLAT" && ok "M3: saturation.md 의 블록 누락 = 번호 있는 항목만" || no "M3: saturation.md 블록 누락 범위 부재"
grep -qF '이월 전에 한 조사는 번호가 없다' <<<"$MIG_FLAT" && ok "M3: 이월 전 조사는 번호 없음" || no "M3: state-migration 에 이월 전 조사 규칙 부재"
grep -qF '`### 판정 불가` 경로로 간다' <<<"$MIG_FLAT" && no "M3: 이월 세션이 아직 판정 불가로 고정된다" || ok "M3: 이월 세션의 판정 불가 고정 없음"
grep -qF '두 묶음 미만이면 판정자 규칙대로 «아직»' <<<"$MIG_FLAT" && ok "AC7: state-migration 이 판정자 규칙을 묶음 단위로 인용" || no "AC7: state-migration 의 판정자 규칙 인용이 묶음 단위가 아니다"
grep -qF '두 항목 미만' <<<"$MIG_FLAT" && no "AC7: state-migration 에 「두 항목 미만」 잔존" || ok "AC7: state-migration 에 「두 항목 미만」 없음"
grep -qF '`### 상한 값` 펜스가 정한다' <<<"$MIG_FLAT" && ok "M3: <시작값> 은 상한 값 펜스" || no "M3: <시작값> 출처 부재"
# M4 — description · 도입부가 이중 종료(floor 5 closed + 포화 또는 사용자 종료)를 말한다.
DUAL='포화 판정자가 «포화»를 내거나 사용자가 종료를 고를 때'
grep -qF "$DUAL" <<<"$(awk 'NR>1&&/^---$/{exit} NR>1' "$SKILL" | tr '\n' ' ' | tr -s ' ')" && ok "M4: description 이 이중 종료" || no "M4: description 이 floor 단독 종료"
grep -qF "$DUAL" <<<"$(awk '/^당신은 spec-distill의/{f=1} /^## State location/{f=0} f' "$SKILL" | tr '\n' ' ' | tr -s ' ')" && ok "M4: 도입부가 이중 종료" || no "M4: 도입부가 floor 단독 종료"
# 부재 — 금지 토큰이 새 표면에 없다
for tok in '판정자 조건' '판정자 투입' '다시 묻지 않는다' 'probe''_count' 'web''_budget' 'interview''_round'; do  # 잔재 락(test_probe_sweep_residue.sh)이 이 파일을 스캔하므로 토큰을 둘로 쪼갠다
  grep -qF -- "$tok" "$SAT" && no "부재: saturation.md 에 «${tok}»" || ok "부재: saturation.md 에 «${tok}» 없음"
done
grep -qE '최대 [0-9]+회|[0-9]+회까지' "$SAT" && no "부재: saturation.md 에 숫자 횟수 상한 표현" || ok "부재: 숫자 횟수 상한 표현 없음"
finish
