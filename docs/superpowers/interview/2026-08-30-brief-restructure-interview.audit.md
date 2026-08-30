---
type: interview-audit
payload: 2026-08-30-brief-restructure-interview.md
created_at: 2026-08-30
session_id: c4c0ff2f-6024-4d33-a35b-840ac08c72b7
source: spec-distill conducting-interview v0.41.0
---

# brief 재구조화 — Interview Audit

> 순수 텔레메트리 — 다음 stage 가 읽는 핸드오프 산출물은 payload 이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다.
> payload frontmatter 의 `audit_file` 이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 진짜 문제는 분량이 아니라 게이트 배치다. 15검사 + bijection 3종 + check_verbatim_coverage 가 payload 를 코퍼스로 삼아 검증 대상이 인계 대상을 부풀렸고, 그 결과 하류에서 distraction(분량)과 poisoning(URL·잘못된 자료)이 난다. 진짜 goal = 검증 대상(audit)과 인계 대상(payload)의 분리 + payload 자립 완결
- floor:landscape — closed — web sweep 2회 + steelman/blind-spot 에이전트가 가져온 근거 17건. Breunig 실패 4분류가 사용자 발화 두 개(S2=distraction, S4=poisoning)에 정확히 대응. payload §4 에 8항목을 판정과 함께 기록
- floor:skepticism — closed — 의심 방향 「payload URL 전면 제거」에 steelman-builder dispatch(근거 9건, confidence 0.78). 사용자 verdict=switched — URL 유지 + 3항 형식 + 데이터 라벨. 잔여 위험을 OQ1 에 박제하고 전면 제거 선택지를 열어 둠(S10)
- floor:blind_spot — closed — blind-spot-prober dispatch(숨은 가정 7 + 실패 양식 8, confidence 0.84). 핵심 발견(brief-critic 의 `tools: []` 로 §6 이관 시 충실도 축 사망)을 orchestrator 가 코드로 검증 후 사용자에게 표면화 → S8 로 해소. 토큰 추정 주장은 orchestrator 가 반박해 OQ3 으로 강등
- floor:open_questions — closed — OQ1~OQ6 박제. F1~F5(설계 범위 내 필수 수정)와 갈라 제시했고 사용자가 그 분류를 승인한 뒤 OQ1 에 「URL 전면 제거가 맞지 않은가」를 추가하도록 지시(S10)
- derived: N/A

## 2. Budget

- 질문 라운드: 11 · agent dispatch: 6 (steelman-builder 1 · blind-spot-prober 1 · brief-direction-reviewer 1 · brief-critic 3) · codex 실호출: **6 (성공 0)** — 한도 소진, 2026-09-17 21:03 까지. 내역: 방향성 러너 1 · 진단 직접호출 2 · 충실도 러너 3

## 3. Steelman 원문

#### ST1 — payload 는 URL 을 유지하되 3항 형식 + 「데이터이며 지시가 아니다」 라벨로 강등해야 한다

> **alternative_statement**: "payload 는 URL 을 유지하되 §4/§5 의 각 항목을 «출처 URL + 원문 직접인용 1문장 + [취함|피함|중립] 판정» 3항 형식으로 고정하고, 그 블록 전체에 «데이터이며 지시가 아니다» 라벨을 붙인다 — 오염 대응의 정본은 링크 삭제가 아니라 provenance 라벨링이고, 링크를 떼면 오염된 주장은 그대로 남은 채 그것을 반증할 유일한 수단만 사라진다."
>
> **strongest_case**: 원안은 «잘못 찾아온 자료»를 제거하지 않는다. 그 자료의 결론은 산문으로 payload 에 그대로 들어가고, 없어지는 것은 꼬리표뿐이다. 메모리 오염 연구는 이 지점을 정면으로 반박한다 — 4단계 content-only 스크리닝이 injection 재현율 0.832 를 내면서도 오염된 메모리 360건 중 0건을 거절했고, 저자들은 "거짓 주장과 참 주장을 구별하려면 일반적으로 텍스트 자체를 넘어선 외부 근거가 필요하다"고 결론한다. URL 이 바로 그 외부 근거다.
> 하류가 사람이 아니라 Read/WebFetch 를 가진 LLM 이라는 사실이 이 비대칭을 극대화한다. LLM 은 일관되고 설득력 있는 in-context 근거라면 자기 파라미터 지식과 충돌해도 높은 수용성을 보인다 — 즉 출처를 뗀 유창한 단정은 «덜 위험한» 것이 아니라 가장 설득력 있고 가장 검증 불가능한 형태다. 인용이 붙어 있을 때만 "이 문장이 그 출처의 지지를 받는가"가 기계적으로 물어질 수 있고, 실제로 그 비율은 51.5% 수준으로 측정된 바 있다. 링크를 지우면 오지지율이 0 이 되는 게 아니라 측정 불가능해질 뿐이다.
> "말로 옮겨 적기"는 무해한 이동이 아니라 비가역 손실 압축이다. 다중 에이전트 릴레이에서 사실 보존은 라운드마다 단조 감소하고, 근거에 접지된 주장이 무근거 주장보다 느리게 마모된다. 고정 키·앵커가 있는 형식은 자유 산문보다 드리프트에 강하다(약한 릴레이에서 6홉 손실 4.7pt 대 20pt+). 원안은 앵커를 없애고 가장 잘 마모되는 형식만 남긴다.
> 보안 문헌의 처방은 삭제가 아니라 강등이다. spotlighting(delimiting/datamarking/encoding)은 신뢰할 수 없는 입력의 출처 신호를 유지·강화해 공격 성공률을 2% 미만으로 떨어뜨렸고, ARGUS 는 influence provenance graph 로 출처를 추적해 28.8%→3.8% 를 달성했다. 두 방어 모두 provenance 가 남아 있어야 성립한다. 원안은 방어의 전제를 지운다.
>
> **weakness_of_current**: 원안은 위험의 담지자를 잘못 지목한다 — 하류를 잘못된 방향으로 끄는 것은 URL 이 아니라 그 URL 이 담아 온 주장이고, 원안은 주장을 남기고 꼬리표만 지운다. 그 결과 (a) 오염된 주장은 그대로 하류 컨텍스트에 들어가고, (b) 하류가 그것을 반증할 유일한 수단(재조회)은 사라지며, (c) 검증 불가능해진 주장은 오히려 더 권위 있게 읽힌다. 또한 '자립 완결'을 URL 제거의 근거로 쓰는 것은 범주 오류다 — 자립 완결의 반대는 링크의 존재가 아니라 필수 정보의 부재이고, URL 은 부피가 아니라 검증 핸들이다. 결정적으로 이 리포의 현행 게이트는 이미 반대 방향으로 못 박혀 있다: `check_brief.py` 는 §4 인용과 §5 verdict URL 을 요구하고, URL 이 없어지는 상태(web kill switch)를 명시적으로 'degraded' 로 분류해 반드시 공시하게 만든다. 원안은 degraded 상태를 정상 상태로 승격시킨다.
>
> **evidence (9건)**: https://arxiv.org/abs/2608.21230v1 (content 스크리닝이 오염 메모리 360건 중 0건 거절) · https://arxiv.org/abs/2403.14720 (Spotlighting, ASR 2% 미만) · https://arxiv.org/html/2605.03378v1 (ARGUS, 28.8%→3.8%) · https://arxiv.org/abs/2304.09848v1 (생성 문장 51.5%만 완전 지지) · https://arxiv.org/html/2403.08319v2 (knowledge conflicts) · https://arxiv.org/pdf/2606.03032 (multi-agent factual attrition) · https://arxiv.org/pdf/2607.08032 (rate-distortion) · https://arxiv.org/html/2607.09678 (relay 메시지 형식 효과) · https://en.wikipedia.org/wiki/Wikipedia:Verifiability
>
> **confidence**: 0.78 — 0.9 로 올리지 않은 이유: (i) 강한 릴레이 tier 에서 메시지 형식 효과가 포화한다는 결과가 있고, (ii) 사용자의 일화가 가리키는 실패가 "URL 존재"가 아니라 "저품질 출처 채택"이라면 출처 티어링만으로 해소되어 어느 쪽도 결정적이지 않다.
>
> **사용자 판정**: switched — 대안 채택. 단 티어링(중간 규율 C)은 명시 기각("1차 출처의 경우도 너무 specific한 논문 자료를 가져오는 경우가 많더라고"). 실패의 진짜 메커니즘은 「하류가 URL 을 읽으면 그 내용만 넘어오는 게 아니라 문서 전체가 들어와 방향과 맥락이 완전 달라진다」이며 사용자는 이를 "근본적으로 해결이 어렵다"고 판단 → OQ1.
>
> **orchestrator 가 걸러낸 것**: builder 의 중간 규율 D("`audit_file` 을 핸드오프 프롬프트에 동반 전달, 비용 0")는 S3(자립 완결)로 이미 닫힌 경로다. builder 는 그 발화를 몰랐다. 게이트 선택지에 넣지 않았다.

## 4. 게이트 실행 기록

- check_brief.py gate — **pass** (2026-08-30) — 총 8회 실행. 최초 통과 → 방향성 재결정 후 1회 red(bijection C, S15~S19 앵커 부재) → §6 append 후 통과 → 충실도 3라운드 수정 후 각각 통과 → 냉독 gap 반영 후 통과 → **확정 반영(21건 confirmed, sentinel 삭제) 후 최종 통과**
- check_verbatim_coverage.py — **exit 0** (2026-08-30) — 총 6회 실행. 1차에서 `not_contained: ["S6"]`(orchestrator 가 §6 옮기며 마지막 문장 절단) → 전문 복원 후 exit 0. 이후 재결정·충실도 3라운드·냉독 반영·확정 반영 시점 모두 exit 0

## 5. 프로세스 로그

- round 0: path (a) — 설계문서 §5.2·§10·§11 정독 + 코드 실측. **선결 문제의 전제가 절반 틀렸음을 확인**: superpowers/6.3.0 brainstorming SKILL 에 `$ARGUMENTS` 계약이 0건이고, `Skill superpowers:brainstorming <brief-path>` 는 devbrew 자신의 `finishing.md:207,233,236,242` 에 있는 문장이다. `resolve_audit()` 은 audit 이름을 payload stem 에서 유도한다.
- round 1: path (b/d) — 하류 인계 모양 4선택지 제시. 사용자가 어느 것도 고르지 않고 **축을 교정**(S2): 확산물이 하류로 넘어가는 것 자체가 문제이므로 소실은 비용이 아니라 목적. 이어 S3(자립 완결)·S4(URL 실패 일화) 도착. orchestrator 추천 ② 철회.
- round 2: path (a) — web sweep 2회. Breunig 4분류가 S2=distraction, S4=poisoning 에 정확 대응. 절별 실측: payload 는 사용자 발화를 두 벌(압축형 17.3% + 원문형 19.2% = 36.5%) 싣는다 — 부피의 최대 단일 원인이 중복 표현.
- round 3: path (b) — S5(압축항목만, YAML 유지). 이어 「확정 항목 원장」이 원 요청에서는 audit 행, S5 에서는 payload 행이라는 충돌을 표면화 → S6(원장/항목 분리).
- round 3.5: path (a/c) — steelman-builder + blind-spot-prober 병렬 dispatch(fan-out 2). 대기 중 B1–B3 얽힘의 실물 확인: `landscape_uncited()` 는 URL 부재를 red 로 하므로 **URL 의 존재가 「조사를 실제로 했다」의 유일한 증거**이고, 그래서 양성 짝이 필요하다. `landscape_present()` 는 §4 에 「생략」 한 단어만 있어도 True 라 짝이 샌다.
- round 4: path (b) — steelman 반환. orchestrator 가 builder 의 리포 주장 4건을 코드로 검증(전부 사실). 사용자 verdict=switched(S7). blind-spot 반환. orchestrator 가 `brief-critic` 의 `tools: []` 를 실물 확인 — **§6 이관이 충실도 축을 죽인다**는 발견을 사용자에게 표면화.
- round 5: path (b) — S8: blob 빌더가 payload + audit §6 을 함께 inline. 격리는 도구 표면으로 성립하고 blob 구성은 오케스트레이터 권한이라는 근거. orchestrator 는 blind-spot 의 "확산물이 리뷰 층으로 되돌아온다(비용)" 주장에 동의하지 않음 — 배제 대상은 하류이지 검증 층이 아니다.
- round 6: path (b) — 도출된 절 구성 제시. §4 의 거처가 원 요청(audit)과 S7(payload)로 갈리는 충돌 표면화 → S9(payload 3항 형식).
- round 7: path (b) — F1~F5 / OQ1~OQ5 분류 제시 → S10(OQ1 에 전면 제거 선택지 추가).
- round 8: path (a) — phase0 진행 상태 실측. PR0~PR4 전량 ship(0.34.0~0.38.0, 현재 0.41.0), `probe_budget.py` 계획대로 삭제, P23 앵커 9곳 실재. 「진행 안 된 것」 = 설계 §11 이월 목록뿐이고 이번 세션 몫 셋은 전부 이 인터뷰가 덮음. **이월 다섯 중 ①②③ 이 이번 결정들로 소멸**(파서 전환 안 함 · verdict 잔류 · §2 제약 잔류), ④⑤ 만 실재. 픽스처 실측 121건(URL 62 + probe 59, 교집합 0).
- round 9: path (b) — 사용자 지시로 brainstorming 6.3.0 원래 과정 대비 우리 payload 의 간섭을 대조. 분류 선점(§7)이 가장 명확한 강제이고 scope 평가·질문·접근법 제안이 억제 위험 → S14.

### orchestrator 가 반박한 에이전트 주장

- blind-spot-prober: "27,590자는 대략 1만 토큰 미만으로 distraction 임계(≈30k) 한참 아래" → **과소추정**. 한글 35%, 47,538바이트. 한국어 토크나이제이션 기준 20,000~35,000 토큰 범위로 추정(정밀 측정 아님). 임계 한참 아래가 아니라 근처. 다만 「원인이 부피가 아닐 수 있다」는 방향은 살아 OQ3 으로 이월.
- blind-spot-prober: "audit 도 함께 inline 하면 확산물이 리뷰 층으로 되돌아온다(비용)" → **동의하지 않음**. 배제 대상은 하류이지 검증 층이 아니다.

### brief 리뷰 라운드 (reviewing-brief)

- 방향성: Claude **9건** / codex 0건(실호출 실패) — 사용자 재결정 **5건**(S15~S19). 미채택 2건(D6 착수 전 토큰 실측 · D7 projection 안) → OQ3·OQ7 로 이월
- 충실도 기록(게이트 아님, 마지막 관측 verdict만 기재): round 1 `needs_revise` critic **8건**(전부 수정) → round 2 `needs_revise` critic **9건**(8건 수정, 1건 수정 불가) → round 3 `needs_revise` critic **10건**(9건 수정, 같은 1건 수정 불가). `brief_critic_rounds: 2` = **cap 도달** → **Step B forced escalate**. codex 는 3라운드 모두 실호출 실패
- **round 3 의 수정 9건은 어느 리뷰어도 보지 않았다(unreviewed).** cap 이 재리뷰를 막고 수정은 허용하므로 구조적으로 그렇게 된다 — 사용자가 유일한 backstop이다
- **관측: 충실도 축은 이 형식에서 0 으로 수렴하지 않는다.** §2 statement 는 여러 절짜리 발화의 ≤160자 요약이라 엄격한 대조는 언제나 델타를 찾는다(3라운드 8→9→10건, 점점 미세). cap 2 가 존재하는 이유이자, **OQ4 가 추상적 우려가 아니라 이 세션에서 3회 관측된 현상**이라는 증거다
- **두 리뷰어가 같은 대상에 반대 판정**: round 2 는 「S1 의 선결 문제 전제가 §2 에 없다」(omission, high)라 해서 C20·C21 을 추가했는데, round 3 은 「C20·C21 이 살아 있는 제약으로 남아 있는데 §5 는 반증됐다고 기록한다」(distortion, high)라 했다. 해소 = 항목은 두되 `status: open` 으로 강등(스키마로 말하고 사용자 문장에 모델 문구를 끼워 넣지 않는다)

#### 미반영 finding (저자가 기각한 것이 아니라 구조적으로 수정 불가)

- **round 2 / insertion / frontmatter** — sentinel `# confirmed 0건 — 사용자가 전부 잠정으로 판단` 은 §6 에 근거가 없는 사용자 귀속이다. **수정 불가 사유**: `check_brief.py:314` 의 `CONFIRMED_SENTINEL_RE` 가 이 문구를 한 줄 전체로 요구하고, 지우면 `confirmed_zero_unsentineled()` 가 red 를 낸다. 저자에게 문구 변경 권한이 없다. OQ5 가 같은 사실을 자기 공시하고 있으며, critic 이 독립적으로 재확인했다 — 두 축이 같은 결함을 가리킨다
- 냉독: **G1·G2·G4·G5 gap 0건.** 냉독은 문서의 축·확정/미결 구분·다음 단계를 정확히 재구성했다. 「읽히지 않은 곳」 4건 중 3건은 실제 결함이라 반영:
  · **G3** — bijection A/B/C 가 이름으로만 인용되고 정의가 없다 → §1 에 용어 정의 3줄 추가(자립 완결 C2 위반이었다)
  · **G3** — C17·C19 의 「나눈 몫」이 무엇인지 문서에 없다 → §1 에 phase0 진행 상태 + 이번 몫 셋 명시
  · **G3** — 재구조화 **결과물의 절 구성**이 문서에 없다(이동 방향만 있었다) → §1 에 payload/audit 도착점 표 + 이월 5개 현재 상태 추가. **orchestrator 가 대화에서만 보여주고 payload 에 안 넣었던 것** — 이 설계가 막으려는 실패를 이 brief 자신이 저질렀다
  · **미반영 / 새 클래스 후보** — 「C20·C21 이 `status: open` 인데 §5 는 반증됐다고 적어, 어느 쪽이 참인지 문서만으로 판단 안 된다」. G1~G5 어디에도 안 맞는다. **G6 후보: 상태 표기와 본문 서술이 어긋나 독자가 어느 쪽이 참인지 판단 못 함.** 관측된 새 클래스를 `reviewing-brief` 의 gap 표에 추가하는 것이 Law 3 compounding 이벤트다
- degrade: `codex:direction:degraded` — 한도 소진(2026-09-17 21:03), 러너 모델 미핀으로 400 이 그것을 가림 / `codex:fidelity:degraded` — 같은 원인, 2라운드 모두 실패
- 격리: zero-tool probe **ZERO_TOOL_OK** — `codex_isolated: false`

### orchestrator 자백 (충실도 리뷰가 적발)

1. **insertion** — C1 의 「소실은 비용이 아니라 목적 쪽이다」는 사용자가 하지 않은 말이고 orchestrator 의 재구성이었다. S1 은 오히려 소실을 *풀어야 할 문제*로 놓았다.
2. **distortion** — C6 의 「URL 전면 제거는 채택하지 않는다」가 앵커 S7 에 없다. S7 은 선택 번호("2")와 관측일 뿐이고 그 선택지 본문이 §6 에 없어 문서 내부 검증이 불가능했다.
3. **evidence_unsupported + provenance_mislabel** — C7 이 S8 에 없는 절(blob 인라인)을 싣고, ☑/chosen 인데 §6 앵커는 🗣 였다.
4. **omission ×3** — S13 후반 지시 · S11·S12 · S1 의 append-only 항목이 §2 에 없었다 → C16·C17·C18 신설.
5. **authority_syntax** — §0 「무엇이 확정」이 전부 provisional 인 항목을 확정으로 서술했다.

### 방향성 리뷰가 적발한 orchestrator 오류 2건

1. S6 추천(payload = id+statement 만)이 게이트 3곳을 깬다 — `BODY_ITEM_RE`(status·⟨S<N>⟩ 문법 요구) · `confirmed_zero_unsentineled()`(status 를 읽음 → sentinel 영구 필수) · `bijection_c_errors`(`if ev and` 공전 → 공허 GREEN).
2. 픽스처 계수 121 → **134**. `## 6. 사용자 원문` 픽스처 74건을 세지 않았다 — 설계문서의 두 축(URL·probe)을 물려받고 이 설계가 만드는 §6 축 밖을 보지 않았다.


### 종료 (Step B)

- 사용자 선택: **① 확정하고 /compact 후 brainstorming**.
- 확정 반영: 21건 `provisional` → `confirmed`. C20·C21 은 `open` 유지(§5 에서 반증·해소된 전제라 확정 대상이 아니다).
- AC12 sentinel `# confirmed 0건 — 사용자가 전부 잠정으로 판단` 은 같은 write 에서 삭제. §0 의 「전부 provisional」 서술도 함께 동기화 — 확정 반영이 그 문장을 거짓으로 만들었다.
- **확정은 봉인이 아니다**(P23): 근거가 있으면 하류가 보고 후 재결정 가능, 임의 변경만 금지.
