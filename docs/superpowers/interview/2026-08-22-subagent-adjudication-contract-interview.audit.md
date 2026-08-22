---
type: interview-audit
payload: 2026-08-22-subagent-adjudication-contract-interview.md
created_at: 2026-08-22
session_id: ccb3ec44-53e2-41c5-87eb-10561d97465a
source: spec-distill conducting-interview v0.26.0
---

# devbrew subagent 판정 계약 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성 2회. 최종: 문제는 무판정 자리(상태)가 아니라 새 subagent가 판정 없이 만들어지는 생성 과정 (S5). 사용자가 R1(S2)에서 1차 정정, R4(S5)에서 2차 재진술.
- floor:landscape — closed — web sweep 3회 + 리포 내 prior art. 외부 8건 인용(ACM adjudication · Anthropic multi-agent 2건 · superpowers SDD · Google Tricorder CACM · CODEOWNERS · FSE2025 suppression · automation complacency). 리포 내부: superpowers 6.3.0 SDD `SKILL.md:354-443`, `plugins/spec-distill/references/proceed-gate.md`.
- floor:skepticism — closed — steelman-builder 1회 dispatch(ST1). 사용자 게이트 판정 = switched (S8). 원안(신규 frontmatter 키 + SDD import)이 payload §5 기각 항목으로 이동.
- floor:blind_spot — closed — blind-spot-prober 1회 dispatch(C8 준수). hidden_assumptions 7 + failure_modes 7 산출, payload §5 `위험` 7항목으로 기록. 사용자에게 표면화 완료.
- floor:open_questions — closed — OQ 9건 박제(payload §3). 인터뷰 중 해소된 것 3건(OQ1 처분 수신자 · OQ2 값 어휘 · OQ10 도출 앵커)은 §5 또는 §0으로 이동.
- derived:dispatch_census — closed — 주제가 요구한 파생 차원. 자리 전수를 22 → 33으로 재산정(표기법 5종). 근거: 서브에이전트 조사 2회 + 저자 직접 검증 6회.
- derived:drop_channel_observability — closed — 1차 census가 틀린 변수를 쟀다는 발견으로 신설. "판정기가 자기가 버린 것을 세는가"를 전 소비자에 측정 → 🔴 11곳.

## 2. Budget

- probe_count: 3 / cap 12

## 3. Steelman 원문

#### ST1 — 새 frontmatter 키를 만들지 말고, 이미 있는 `# guards:` 축과 `proceed-gate.md` 정본에 붙여라

> **alternative_statement**: "새 frontmatter 키 `adjudicated_by:` 를 만들지 마라 — 런타임이 읽지 않는 키는 이 리포가 이미 반증한 '선언 규정 + 비차단 검사기' 조합의 재현이다. 대신 세 가지를 이 순서로 한다. (1) 판정이 빠진 4개 사이트를 지금 직접 고친다. (2) 이미 존재하는 `# guards:` 축에 한 줄 — `# guards: plugins/*/agents/*.md` — 을 repo 전역 agent 락 5개에 붙인다. 이 선언은 무게 감축 설계 §5.2 가 **바로 이 케이스를 워크드 예제로 써 놓고 shipping 하지 않은 것**이며, `.md` 글롭이 이미 동작함이 실측된다(test_proceed_gate_adopters.sh:2). 그러면 새 agent `.md` 가 추가되는 순간 agent 락이 자동 선택되고, 양방향 커버리지 테스트가 그 선언에 이빨을 준다 — 아무도 규정을 읽지 않아도, 선언을 빠뜨릴 사람이 없어도 성립한다. (3) SDD 의 처분 규율은 '차용'할 것이 없다 — devbrew 는 그것을 **더 강한 형태로 이미 갖고 있다**. `references/proceed-gate.md` 가 '이번 라운드의 degrade 를 하나도 빠뜨리지 않고 출력', '없으면 없다고 명시 — 침묵과 구분되어야 한다', '채널이 없다는 사실 자체가 degrade' 를 요구하고, 수신자가 자기 원장이 아니라 사용자가 redirect 가능한 `AskUserQuestion`(P17)이며, 채택자 집합이 **열거가 아니라 포인터에서 도출**된다. SDD 를 정본 규칙으로 import 하는 대신 proceed-gate 정본에 판정 절을 흡수시키면, Law 2 의 수신자 문제가 자동으로 해소되고 새 P# 도 새 키도 필요 없다."
>
> **weakness_of_current**: 두 지점이 겹쳐 있다. (1) **키의 소비자가 없다.** 이 리포에서 `tools:` 규정이 지켜지는 유일한 이유는 런타임이 그 키를 읽어서 누락이 즉시 '전부 상속' 이라는 실제 결과를 내기 때문이다. `adjudicated_by:` 에는 그 성질이 전혀 없고, 남는 집행 수단은 검사기뿐인데 이 리포의 측정된 선례(check-shape-completeness.py `return 0` vs 위반 2/5 README)가 비차단 검사기의 결과를 이미 알려 준다. CI 전무라 차단 버전을 만들 자리도 없다. (2) **`none` 허용이 신호를 소거한다.** 규정의 modal 답변이 '아무것도 바꾸지 않는 값'이면 준수와 무판정이 구별 불가능해진다 — proceed-gate.md 가 '침묵과 측정된 없음을 구분하라' 고 요구하는 바로 그 실패를, 새 규정이 스스로 도입한다.
>
> **confidence**: 0.82 (builder 자기 신고)

저자 검증 4건 (전부 참): guards 축의 확장자 무관성 · 설계 §5.2의 `# guards: plugins/*/agents/*.md` 워크드 예제 실재 · proceed-gate.md의 더 강한 계약 · `check-shape-completeness.py` return 0 vs `check-law2.py` return 1 대조군.

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-08-22, 최종 실행 = 확정 반영 후)
- 종료 게이트 — 사용자가 옵션 ①(확정 후 /compact → brainstorming) 선택. **17항목 전부 `provisional` → `confirmed`**, sentinel 한 줄 같은 write 에서 삭제, §0 확정 서술 동기화. 재제시 1/2 사용(옵션 ③ 1회).
- check_verbatim_coverage.py — exit 0 (2026-08-22), **단 1차 실행은 vacuous**
  - 1차: `advisories: ["검사 불가 — state 원장에 user_statements가 0건이다 (대조 대상 없음). 빈 집합 위의 '위반 없음'은 검증이 아니다"]`
  - 원인: 세션 중 TTL-GC 가 state 를 삭제해 원장이 소실됨(§5 사고 기록). 복구 시 발화를 본문 프로즈로만 넣고 frontmatter 목록을 안 채움.
  - 2차: 원장에 11건 기록 후 재실행 → `missing_ids: []`, `not_contained: []`, advisories 없음.
  - **degrade (정직 기록)**: 2차 실행의 원장은 payload §6 에서 파생했다. 따라서 이 검사는 "원장↔§6 일치"를 확인했을 뿐 **"대화 원문↔§6 일치"를 독립적으로 확인하지 못했다.** §6 의 충실도는 reviewing-brief 의 brief-critic(충실도 축)이 판정해야 한다.

## 5. 프로세스 로그

- round 0: (b) — 원 요청 수신. trivia escape 미해당 판정.
- round 1: (a) — quality-gates advisory 구조 점검 + 저장소 subagent 경로 전수 조사(1차, 22곳). web landscape 2회.
- round 2: (b) — probe 1(강제력 4옵션) 사용자 기각. 범위 재정의(S2).
- round 3: (a) — 22 사이트 × "판정 단계 유무" 표. RED 4곳 판정.
- round 4: (a) — S3 지목으로 spec review 재검증. **1차 판정 뒤집힘** — `merge_review.py:250` conservative()=max()는 escalation이지 판정 아님.
- round 5: (a) — 전 사이트 코드 기반 재검증. audits 조회 → S17 갭 미등재(신규).
- round 6: (b) — 문제 재진술(S5). 순서 제약 + subagent 허가 수신.
- round 7: (a) — superpowers SDD 확인(S6 지목). `SKILL.md:354-443` 판정 계약 실재.
- round 8: (c)+(a) — 서브에이전트 2회(shared 작업 실체 / 집행 지점 지도). 저자 검증 8건.
- round 9: (b) — probe 2. 강제 수준 선택 → ②(S7).
- round 10: (c) — steelman-builder + blind-spot-prober 병렬 dispatch(fan-out 2, 선언됨).
- round 11: (b) — probe 3. steelman 게이트 → switched(S8). 저자 검증 4건.
- round 12: (b) — 사용자 이해 요청(S9). 재설명.
- round 13: (b)+(c) — S10 수신. 저자 정정 2건(4군데 유효 / shared 배치 가능). 서브에이전트 2회(자리 재산정 / drop 채널 측정).
- round 14: (a) — 분모 22→33 확정. **저자 자신의 도출 제안이 깨짐**(subagent_type grep은 5표기 중 1개만 커버).
- round 15: (a) — S11 요구대로 도출 3후보 실측. ⓐ불가 / ⓑ성립(5/5 표기, 33토큰, 잔여 8) / ⓒ구조적 실패.

**저자 오류 원장** (이 인터뷰가 스스로 적발한 것):
1. S17을 "이미 덮여 있음"으로 오판 — SKILL 산문의 "결정론 병합"을 판정으로 읽음. 함수 본문이 `max()`였음.
2. 22-사이트 표가 **틀린 변수**를 쟀음 — 판정기 내부의 조용한 버림 11곳을 전부 ✅로 채점.
3. 무판정 4곳을 3곳으로 축소 제안 — 인터뷰의 무판정 계약 대상을 오독(사용자 발화 ≠ subagent 보고). 사용자가 기각.
4. "shared에 두면 생성 시점 독자가 못 읽는다" — 절반만 참. 마크다운 심볼릭 링크 배포 선례를 못 봄.
5. **도출 앵커로 `subagent_type` grep 제안 — 5표기 중 1개만 커버.** 이 리포가 반복 학습한 "열거는 fail-open"에 저자가 그대로 빠짐.

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

- 방향성: Claude 7건 / codex 0건(런타임 실패) — 사용자 재결정 2건(D2·D4 즉시 교정), 5건 Step B 이월(D1·D3·D5·D6·D7)
- 충실도 기록(게이트 아님, 마지막 관측 verdict만 기재): **needs_revise** — critic 라운드1 13건 → 라운드2 12건 → 라운드3 6건(high 1) / codex 0건(3회 전부 런타임 실패) — 재라운드 **2/2 상한 도달, 강제 상신**
- 냉독: **G1–G5 gap 0건 (pass)**. 단 5클래스 밖 결함 관측 — 정의 없는 내부 라벨 8종. 특히 §5가 인용하는 `방향성 D1/D2/D4` 목록이 payload·audit 어디에도 없다(없는 것을 가리키는 인용). **여섯 번째 gap 클래스 후보 — Law 3 compounding 이벤트**
- degrade: verbatim_coverage/completeness · codex/direction · codex/fidelity · critic/fidelity(상한) · readback/readback — **5건**
- 격리: zero-tool probe **ZERO_TOOL_OK** — `codex_isolated: false`(codex 미실행)

#### 미해결 findings (Step B 상신)

**충실도 6건** — ①S1의 처분어휘 `수용·기각·보류`+"근거를 비판적으로 검토해" §2 부재(**high**) ②S1의 "정본 규칙 마련 + 기존 전체 원장 반영"이 앵커 없는 Goal로만 존재 ③Goal 2 "기계가 잡게 한다"의 집행 형태가 §6에 없음 ④C15가 S9 일회성 요청을 항구 요건으로 전환 ⑤§0 "두 원장(자리·결함)" 분해에 "사용자 지목" 태그가 과잉 적용 ⑥frontmatter sentinel이 없는 사용자 행위를 서술(템플릿 강제 문구라 저자가 제거 불가)

#### 방향성 findings 전문 (D1–D7) — payload 가 인용하는 목록의 정본

| id | 무엇을 뒤집자는 것인가 | 결정할 질문 | 상태 |
|---|---|---|---|
| **D1** | "런타임이 읽는 소비자가 없다"는 토대 전제가 실측에 반증 — `PostToolUse` matcher `Agent` 의 `additionalContext` 가 **메인**에 배달된다(`docs/superpowers/specs/2026-08-05-agent-transparency-design.md` 배달지 실측표). 그 훅을 기각한 첫째 근거("에이전트 결과 도착은 유일하게 외부 표시되는 순간이라 백스톱 불필요")가 이 주제에서는 뒤집힌다 — 이 brief 의 전 증거가 그 순간의 소실이다 | 두 런타임 자리를 현재 CLI 버전에서 재측정하고 §11 되살리기 조건 4개에 답할 것인가, 이번에도 닫은 채 `/qg` 전용 락으로 갈 것인가 | **이월** |
| **D2** | C6 의 "4군데"는 분모 22 시절 발화이고, 다음 라운드에 33 재산정으로 같은 축이 10 이 됐다 — 승인 범위와 brief 범위가 다르다 | 재산정 후 10곳(또는 21건) 전부를 범위로 승격할 것인가, 4곳으로 고정하고 나머지를 별건 원장으로 넘길 것인가 | **즉시 교정**(OQ10 신설 + §2 ✎) |
| **D3** | brief 가 "더 위험하다"고 못 박은 절반(조용한 버림 11곳)에 선택한 방향의 인과가 0 — 어떤 "판정자 선언" 계약도 `merge_review.py` 의 `conservative()=max()` 나 `apply_verdicts()` 의 무계수 drop 을 위반으로 만들지 못한다 | Goal 1 을 "정본 계약 문면"에서 **"판정기의 drop 회계를 산출물 스키마로 요구"** 로 바꿀 것인가, 계약을 먼저 세우고 11곳은 다음 사이클로 미룰 것인가 | **이월** |
| **D4** | `shared/` + 심볼릭 링크 배포가 §8 을 막는 유일한 구조적 가드를 **경로 모양만으로** 통과한다 — `shared/tests/presence_corpus.sh:35` 의 술어가 소유가 아니라 경로 패턴 | 정본의 거처를 OQ2 의 답이 나온 뒤 정할 것인가 — `plugins/<p>/references/`(가드가 foreign 으로 RED) 와 `skills/<s>/references/`(가드가 own 으로 통과) 중 어디인가 | **즉시 교정**(거처는 사용자 제약으로 존치, 배포 형태를 OQ2 로 분리) |
| **D5** | `# guards:` + 이름 훑기가 목표 코퍼스를 안 덮는다 — 선언은 `*.sh` 테스트에서만 읽히고(파이썬 락 무시), `--emit-scanned` 미지원 락은 양방향 검사가 초록을 찍으며, Tier C 는 파일에 고정돼 있지 않아 정적 열거 불가. 트리거가 `agents/*.md` 인데 목표는 "새 dispatch 자리"다 | 집행 트리거를 dispatch 표면(`skills/**`·`commands/**`·`hooks/**`·workflow)으로 옮기고 Tier C 를 정적 검출에서 명시 배제할 것인가 | **이월** |
| **D6** | 이 리포는 subagent 에 대한 리포 전역 관문(`fan-out ≥5` 하드 리뷰 게이트)을 이미 **능력 억제로 판정해 삭제**했고 코드가 재도입 인용을 금지한다. 살아남은 형태는 승인 요건이 아니라 **공시 요건**(`ROOT-05`) | 계약을 "모든 dispatch 자리는 판정자를 가져야 한다"는 **승인 요건**으로 쓸 것인가, "모든 판정 자리는 수용·기각·보류와 **버린 것의 수**를 공시해야 한다"는 **공시 요건**으로 쓸 것인가 | **이월** |
| **D7** | 같은 문제를 푼 shipped·하드닝된 템플릿이 리포에 둘 — `test_proceed_gate_adopters.sh`(포인터에서 채택자 도출 + vacuity 하한 + 구조적 가드 + `--emit-scanned`) 와 `test_web_kill_switch.sh`(정의 속성에서 소비자 도출 + ∀ 지배 + 근접 창) | 새 정본 저술 전에 두 템플릿을 판정 축에 인스턴스화할 수 있는지 먼저 실측할 것인가 — 충분하면 "새 정본 + shared 통합" 산출물을 철회할 것인가 | **이월** |

**출처**: `brief-direction-reviewer`(Claude 단독 — codex #1 런타임 실패로 모델 다양성 없음). confidence 자기신고 없음.

**두 리뷰어 상충 1건** — `shared/` 거처에 대해 방향성 D4("확정을 되돌려라 — 가드 우회")와 충실도 라운드2("거처 미정은 S5·S10을 지운 왜곡")가 정반대 판정. 해소: 거처는 사용자 제약으로 복원, 배포 형태를 OQ2로 분리.

**세션 중 사고 1건**: `.claude/spec-distill/<sid>/` 가 spec-distill 자신의 TTL-GC 에 의해 인터뷰 진행 중 삭제됨(`.gc.lock` 2026-08-22 15:22). state append 가 실패했고 대화 기록에서 복구. 이 리포의 별건 결함이며 이 인터뷰 범위 밖.
