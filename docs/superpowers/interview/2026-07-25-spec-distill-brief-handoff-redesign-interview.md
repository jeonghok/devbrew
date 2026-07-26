---
name: spec-distill-brief-handoff-redesign
type: interview-brief
created_at: 2026-07-25
session_id: fd4b96a9-264b-4e88-9eb1-f622686709f5
source: spec-distill conducting-interview v0.22.0
next_phase: superpowers:brainstorming
audit_file: 2026-07-25-spec-distill-brief-handoff-redesign-interview.audit.md
# 이 brief는 자기가 제안하는 새 포맷을 스스로 사용한다(dogfood).
# 현행 check_brief.py 스키마(§1..§9 + locked_directions 키)와 의도적으로 다르다.
# 게이트 = 실행함(2026-07-25, exit 1). codex 독립 리뷰 = 실행함(2026-07-25). 둘 다 결과를 본문에 반영.
#
# 두 축을 분리해 기록한다 (codex 리뷰 B1 수용):
#   source : verbatim(🗣 사용자가 직접 타이핑) | chosen(☑ 제시된 선택지에서 고름) | inferred(✎ 모델 추론)
#   status : confirmed(숙고 후 확정) | provisional(잠정) | open(미결)
# "사용자가 말했다"와 "확정된 제약이다"는 다른 것이다. 둘을 한 축으로 묶으면
# 지나가는 말까지 확정으로 굳어 Locked Directions가 이름만 바꿔 되살아난다.
user_sourced_items:
  - {id: C1, source: verbatim, status: confirmed,
     statement: "다음 세션에서 보고 바로 이해되는 내용이 brief 최상단에 와야 한다 — 컨텍스트 엔지니어링 관점의 재구성이다"}
  - {id: C2, source: verbatim, status: confirmed,
     statement: "사람이 한 말은 표기로 구분한다(🗣/☑/✎). 유저가 한 말을 가려내기 위함"}
  - {id: C3, source: chosen, status: confirmed,
     statement: "표기 규약은 포맷 차원 — payload 템플릿 최상단 2줄 고정 블록으로 모든 brief가 상속. 저술규칙/grep레시피/실측기록은 각각 템플릿·critic·audit에 분산"}
  - {id: C4, source: verbatim, status: confirmed,
     statement: "사용자 출처 항목도 이유가 있으면 보고 후 재선택 가능. 임의 변경만 불가 — 파이프라인의 성질이지 brief가 독자에게 요구하는 규약이 아니다"}
  - {id: C5, source: verbatim, status: confirmed, precedence: highest,
     statement: "brief는 방향을 잡는 문서다. 컨텍스트를 제약하는 행동 규약을 담으면 다음 세션의 잠재공간이 좁아진다. 규약·프로토콜은 brief가 아니라 이를 집행하는 템플릿·SKILL·에이전트 프롬프트에 산다"}
  - {id: C6, source: chosen, status: confirmed,
     statement: "출처(source)와 결정 상태(status)를 직교 분해한다 — 사용자 출처라는 사실만으로 확정 제약이 되지 않는다"}
  - {id: D1, source: chosen, status: confirmed,
     statement: "brief를 2파일로 분리한다 — payload + audit(텔레메트리). 분할선은 '재논쟁 차단에 쓰이는 것은 payload / 순수 프로세스 텔레메트리만 audit'"}
  - {id: D2, source: chosen, status: confirmed,
     statement: "brief-critic은 payload 파일 하나만 입력받는 hard gate다. 쓰기 도구 없음. audit·인터뷰 transcript는 주지 않는다"}
  - {id: D3, source: verbatim, status: confirmed,
     statement: "리뷰는 2단계 — critic 이후, 최종 도달 시 '프레시' 서브에이전트가 brief만 읽고 요약 보고. 그 요약이 의도와 맞는지로 handoff 품질을 검증(사용자와 Claude 양쪽 대상)"}
  - {id: D4, source: verbatim, status: confirmed,
     statement: "brief 리뷰에 codex도 활용한다 — 별-모델 독립 리뷰어"}
  - {id: D5, source: verbatim, status: confirmed,
     statement: "리뷰는 충실도만이 아니라 '사용자가 방향성을 잘못 잡은 것은 아닌지'도 본다 — 인터뷰의 skepticism 의례를 최종 단계에서 전체를 조망하며 반복"}
---

# spec-distill interview brief — handoff 재설계

> payload. 프로세스 텔레메트리(커버리지 원장·예산 카운터·steelman 원문·게이트 판정 상세·codex 리뷰 전문)는 `*.audit.md`에 있다.

---

## 0. 한눈에

**무엇을** — spec-distill의 interview brief 포맷을 핸드오프 아티팩트로 재설계하고, brief 품질을 보는 리뷰 파이프라인(critic + codex + readback)을 신설한다.

**왜** — ✎ 현 brief는 해답공간 결정을 *"확정·재논쟁 금지"* 라는 권위 문법으로 박제하고 프로세스 감사 흔적을 읽기 동선 한복판에 둔다. 그래서 다음(compact된) 세션에 의도가 오역 없이·난잡하지 않게 전달되지 않는다. **표면 증상은 "brainstorming이 탐색을 안 함"이지만 원인은 brief의 정보 문법과 배치라는 것이 이 문서의 가설이다**(확정 아님 — 아래 OQ11이 이 가설 자체를 겨눈다).

**확정된 것** — C1 최상단 배치 · C2 출처 표기 · C3 규약은 템플릿 차원 · C4 보고 후 재결정 · **C5(최상위) brief는 규약집이 아니다** · C6 출처와 결정상태 직교 · D1 2파일 분리 · D2 critic은 payload-only hard gate · D3 리뷰 2단계 · D4 codex 병행 · D5 방향성 축.

**열려 있는 것** — OQ1–OQ12 열둘. 그중 무게가 큰 것: **OQ9** 새 템플릿의 섹션 레이아웃(의도적 미결) · **OQ11** 포맷 재작성 전에 전환 adapter만 고쳐 측정해야 하는가 · **OQ12** 2파일이 정말 필요한가.

**다음 stage** — `superpowers:brainstorming`(해답공간).

---

## 1. 사용자가 실제로 한 말 (verbatim)

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

🗣 최초 요청 (`/interview` 인자):
> "brief에서 LD 제거 brainstorming에서 탐색을 진행 안함 결정에 대한 컨텍스트가 너무 강함, 브리프 포맷을 조정하고 마지막에 브리프 리뷰 서브에이전트가 필요함 내 의도와 컨텍스트를 오역없이 쉽게 이해되게 맥락 컨텍스트상 난잡하지 않게 다음 단계로 전달할 수 있어야함"

🗣 probe 1 응답 (제시된 3지선다를 **거부**하고 축을 재설정):
> "다만 다음 세션에서 보고 바로 이해될 수 있는게 가장 위에 나와야 해, 컨텍스트 엔지니어링 관점에서 브리프가 재구성 되어야 하는거지."

🗣 리뷰 2단계화:
> "한가지 더 컨텍스트를 줄게 보고 어떻게 할지 생각해보자, 스펙 디스틸 브리프 완성 후에 비판적 리뷰하는 서브에이전트 필요 이후, 최종에 도달할때 프레시 서브에이전트가 읽고 어떻게 읽히는지 우리가 의도한 내용인지 리뷰하는게 좋겠네 브리프만 읽고 요약보고 해줘서 사용자와 클로드에게 핸드오프로서 잘 만들어졌는지를 검증하는거야"

🗣 표기 규약 요구:
> "그리고 사람이 이야기한거는 그 표기가 있었으면 해 유저가 한말을 구분하기 위함으로"

🗣 사용자 출처의 강도:
> "사용자 발화와 선택도 나에게 뒤집을 이유가 있으면 보고하고 재선택 혹은 보고 할 수 있어 임의로 변경만 안하면 돼"

🗣 지시문 제거:
> "내가 보기에 뭐를 하라고 지시하는걸 지우고 그냥 출처 표기만 하는게 좋을거 같아"

🗣 brief의 정체 (최상위 원칙):
> "지금 우리가 방금 한게 잘못한거야 행동 규약을 브리프에 담은거 여기는 방향을 잡는거지 컨텍스트를 제약할 규약을 브리프에 담게되면 컨텍스트 엔지니어링 상 최악이야, 다음 세션에서 잠재공간이 제한되게 되자나"

🗣 리뷰에 codex 포함:
> "좋아 고치고 리뷰에 codex도 활용한다고 명시해줘"

🗣 리뷰의 두 번째 축:
> "진행하자, 브리프에 명시 되어야 겠지만 리뷰는 사용자가 방향 성을 잘못잡은건 아닌지도 봐줘야 해, 우리 interview에서 하듯이 그걸 최종으로 보는 거지 전체를 바라보며"

☑ 층지기 방식:
> "2-파일 분리" — payload 파일 / audit 파일(Coverage Ledger·예산·steelman 원문)

☑ 리뷰어 계약:
> "brief만 + hard gate" — 리뷰어는 payload 파일 하나만. audit·transcript 미제공. `tools: Read, Grep, Glob`(쓰기 없음). Issues Found → orchestrator 수정 → 재리뷰

☑ steelman 게이트 판정:
> "방어 + 분할선 이동" — 2파일 유지하되 경계를 '재논쟁 차단에 쓰이는 것=payload / 순수 텔레메트리=audit'으로 이동

☑ 표기 규약의 분량:
> "2줄로 압축" — 냉독자에게 필요한 최소(기호 뜻 + 잠김 규칙)만 brief에, 저술규칙·grep 레시피·실측기록은 템플릿·critic·audit로 이관

☑ 포맷 확정 범위:
> "산출물만 명명" — 무엇을 만들지는 적고, 어떻게 생길지(섹션 목록·이름·번호)는 확정하지 않는다

☑ 판별식 구조 (codex 리뷰 B1 응답):
> "직교 분해 수용" — `source`(verbatim|chosen|inferred)와 `status`(confirmed|provisional|open)를 별도 축으로. 사용자 출처라는 사실만으로 확정 제약이 되지 않는다

☑ codex B2·B3 처리:
> "둘 다 OQ로 기록하고 방향 유지" — D1은 유지하되 codex의 두 반론(측정 우선 / 단일 파일)을 근거와 함께 미결로 박제

---

## 2. 진짜 goal / goal이 아닌 것

**진짜 goal**
brief가 핸드오프 아티팩트로서 기능하는 것 — 다음 세션(사람이든 에이전트든)이 위에서부터 읽으면 사용자의 의도와 문제 맥락이 **오역 없이** 잡히고, 해답은 **열린 채로** 남아 탐색이 살아 있는 것.

**goal이 아닌 것**
- "LD 섹션 삭제"가 목적이 아니다. LD 제거는 위 goal에서 파생되는 **결과**다.
- brief를 spec으로 승격시키는 것이 아니다 — brief는 단독 완결 terminal 산출물로 유지된다.
- **brief를 규약집으로 만드는 것이 아니다**(C5). LD가 문제였던 이유는 결정을 담아서가 아니라 **행동을 규정**해서였다. 규약을 더 나은 규약으로 교체하는 설계는 같은 실패의 반복이다.

✎ *분량에 대하여* — 이 재설계의 초점은 정보의 문법과 배치이지만, 그렇다고 **분량 감축을 배제하지 않는다.** 「Landscape」의 context rot 근거(입력이 늘면 정확도 0.92→0.68)는 총 볼륨이 독립적인 레버임을 말한다. 사용자는 "난잡하지 않게"를 요구했을 뿐 정보 감량을 배제한 적이 없다 — 더 짧은 단일 payload도 유효한 후보다(OQ12).

---

## 3. 제약

출처는 전부 「원문」에 있다. 각 항목은 `source`(누가) × `status`(얼마나 굳었나) 두 축을 갖는다.

| 축 | 값 |
|---|---|
| **source** | 🗣 verbatim(직접 타이핑) · ☑ chosen(선택지에서 고름) · ✎ inferred(모델 추론) |
| **status** | confirmed(숙고 후 확정) · provisional(잠정) · open(미결) |

✎ 두 축이 필요한 이유: "사용자가 말했다"는 사실은 **그것이 확정 제약이라는 뜻이 아니다.** 지나가는 아이디어·질문·선택지 anchoring까지 같은 무게로 굳으면 `Locked Directions`가 🗣/☑ 아래에서 이름만 바꿔 되살아난다. (codex 독립 리뷰의 지적을 수용해 도입 — 이전 판은 출처 한 축뿐이었다.)

- 🗣 confirmed **C1** — 다음 세션에서 보고 바로 이해되는 내용이 최상단에 온다.
- 🗣 confirmed **C2** — 사람이 한 말은 표기로 구분한다. 유저가 한 말을 가려내기 위함.
- 🗣 confirmed **C5 (최상위)** — **brief는 방향을 잡는 문서다.** 컨텍스트를 제약하는 행동 규약을 담으면 다음 세션의 잠재공간이 좁아진다. 규약·프로토콜·저술 규칙은 brief가 아니라 그것을 집행하는 곳(템플릿·SKILL·에이전트 프롬프트)에 산다. *다른 제약과 충돌 시 이것이 이긴다.*
- 🗣 confirmed **C4** — 사용자 출처 항목의 강도: 임의 변경은 막되 이유 있는 재결정은 열어둔다(보고 → 사용자 재선택). 파이프라인의 성질이지 brief가 독자에게 요구하는 규약이 아니다(C5).
- ☑ confirmed **C3** — 표기 규약은 개별 brief가 아니라 **템플릿**에 속한다. 저술 규칙·도구 레시피·실측 기록은 각각 템플릿·critic 프롬프트·audit에 산다.
- ☑ confirmed **C6** — 출처와 결정 상태를 **직교 분해**한다. 확정된 것만 재결정 게이트 대상이 된다.
- ☑ confirmed **D1** — 2파일 분리. 분할선 = *재논쟁 차단에 쓰이는 것은 payload / 순수 프로세스 텔레메트리만 audit*. (codex가 이 결정에 새 반론을 냈다 → OQ12에 박제, 방향은 유지)
- ☑ confirmed **D2** — brief-critic은 payload 파일 하나만 받는 **hard gate**. 쓰기 도구 없음(Law 2 물리 분리). audit·transcript 미제공 — 인터뷰의 프레이밍을 흡수하면 바로 그 프레이밍의 오역을 못 보기 때문.
- 🗣 confirmed **D3** — 리뷰는 2단계. critic(분석적 결함 사냥) 이후, 최종 도달 시 **readback**(순진한 cold read → 요약 보고). 대상은 "사용자와 Claude 양쪽"(→ OQ5).
  - ✎ provisional — readback의 순진함은 **프롬프트 오염으로 파괴된다.** "의도가 보존됐는지 확인하라"고 지시하는 순간 그 에이전트는 확인해주는 쪽으로 붕괴한다. **실측됨**: 이 brief로 시범 실행했더니 에이전트가 payload 안의 red-flag 기준을 읽고 그 답을 회피했다고 스스로 보고했다(→ OQ4).
- 🗣 confirmed **D4** — brief 리뷰에 **codex도 활용한다** — 별-모델 독립 리뷰어.
  - ✎ provisional — 같은-계열 모델 둘은 공유 맹점을 갖는다. 이 인터뷰에서도 blind-spot-prober와 steelman-builder(둘 다 같은 계열)가 게이트 fail-open을 못 봤고 **실행 검증**이 잡았다. codex는 그 backstop의 모델-다양성 판이다.
  - ✎ 자산: `scripts/detect_codex.sh`(가용성·kill switch `DEVBREW_DISABLE_SPEC_DISTILL_CODEX`·재귀 가드)는 범용이라 재사용 가능. `build_spec_codex_prompt.py`는 **design-doc 전용 체크리스트**라 brief에는 부적합 — 특히 최신 spec의 AC를 주입하는 성질은 brief 리뷰에서 모델 다양성을 죽이는 오염원이 된다.
- 🗣 confirmed **D5** — 리뷰의 축은 **둘**이다. (a) **충실도** — 모델이 사용자 말을 왜곡·누락·삽입했는가. (b) **방향성 타당성** — *사용자가 잡은 방향 자체가 틀린 것은 아닌가.* (b)는 인터뷰의 skepticism 의례를 최종 단계에서 전체를 조망하며 반복한다.
  - ✎ provisional — D5가 없으면 C4가 사문이 된다. C4는 "뒤집을 이유가 있으면 보고하고 재결정"인데 *뒤집을 이유를 찾는 역할*이 없었다. D5가 그 발화 조건을 만든다. (b)의 산출은 C4 경로로 흐른다 — 리뷰어가 방향을 바꾸는 것이 아니라 사용자에게 보고한다.
  - ✎ (a)와 (b)는 필요한 증거 범위가 반대다 — (a)는 문서 내부 대조, (b)는 외부 근거 조사. D2의 payload-only 계약과 충돌한다(→ OQ8).

### 판별식

새 포맷이 다른 이름의 LD가 되지 않으려면 무엇으로 갈라야 하는가 — **출처 × 결정상태 두 축**, 그리고 **문법**.

문법 축: **권위 문장**("확정·재논쟁 금지")이 아니라 **증거 문장**("X를 해봤고 Y 때문에 버렸다")으로 쓴다.

> ✎ *(모델 주석)* 세 번의 자기교정이 이 판별식을 만들었다. ① "제약 vs 아키텍처" 기준 → 반증(사용자는 아키텍처도 정당하게 결정한다. 기준은 주제가 아니라 출처다). ② 「제약」에 "다시 묻지 않는다"를 써서 LD의 권위 문법을 재도입 → 사용자가 교정(금지 대상은 재논쟁이 아니라 무단 변경). ③ 출처 한 축만으로 잠김을 정함 → codex가 반증(출처 ≠ 확정). 세 실수는 같은 유혹에서 나온다: *확정을 강하게 표현하면 하류가 말을 들을 것이다.*

---

## 4. External Landscape

- **Design fixation** — 제시된 예시 해답이 "premature cognitive commitment"를 유발해 탐색 폭을 줄이고, 후속 산출물이 예시의 특징을 과다 답습한다. 원인은 예시 해답만이 아니라 **문제에 대한 관점과 프로세스** 자체도 포함. — https://www.sciencedirect.com/science/article/pii/S0142694X15000137 — **[취함]** — 현행 템플릿의 `Locked Directions` 섹션이 이 메커니즘.
- **Design fixation의 시간 감쇠** — 노출 후 시간이 지나도 fixation이 유지된다는 실험. — https://www.designsociety.org/download-publication/39836/design_fixation_to_examples_a_study_on_the_time_decay_of_fixation — **[취함]** — compact를 거쳐도 박제된 결정의 영향이 남는다는 근거.
- **문제정의는 해답을 규정하면 안 된다** — 문제 진술이 구현 방법·기술 요구사항을 나열하면 예상 밖 가치를 탐색하지 못하게 제약된다. 문제는 해답과 **co-evolve**한다. — https://ixdf.org/literature/article/stage-2-in-the-design-thinking-process-define-the-problem-and-interpret-the-results — **[취함]** — Double Diamond 1st/2nd diamond 분리의 근거.
- **Lost-in-the-middle (U자 위치 편향)** — 모델은 입력의 앞과 뒤를 잘 보고 중간에서 성능이 떨어진다. 표준 완화책은 **같은 컨텍스트 내 재배치(reordering)**이지 파일 분리가 아니다. — https://arxiv.org/html/2510.10276v1 — **[중립]** — ✎ 이 편향은 특정 QA/RAG 설정에서 측정된 것이며, "brief 최상단=원문, 최하단=Next Action"이 최적이라는 것까지는 입증하지 않는다. 배치의 참고 근거일 뿐 고정 설계의 증명은 아니다(→ OQ9).
- **Context rot — 총 볼륨이 독립 레버** — 증거가 유리하게 배치돼도 입력이 수백→3000 토큰으로 늘면 정확도 0.92→0.68. — https://www.tmls.nyc/research/context-rot-mechanistic — **[취함]** — 압축이 배치와 별개로 작동한다는 근거.
- **Multi-document 이어붙이기 정보 유실** — 여러 문서를 결합할 때 위치에 따라 관련 정보가 유실. — https://arxiv.org/html/2406.16008v1 — **[취함]** — 2파일 분리의 위험.
- **에이전트 반복 질문이 신뢰를 무너뜨린다** — 첫 반복에서 사용자는 기술적 결함으로 인식하고, 두 번째부터 정보 보존 자체를 불신한다. — https://www.augmentcode.com/guides/why-ai-agents-repeat-questions — **[취함]** — LD를 그냥 없앨 때의 **반대 방향 실패**(harassment).
- **Anthropic progressive disclosure** — 필요한 것만 층으로 드러내는 구조가 Skills의 핵심 설계. — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — **[취함]** — payload/audit 2층 구조의 패턴 근거.
- **superpowers `spec-document-reviewer-prompt.md`** (repo 내 성숙 레퍼런스) — 완결성/모순/모호성/범위/YAGNI 5축 + "심각한 갭 없으면 승인" + `Status: Approved | Issues Found`. — **[취함, 단 변형]** — 형식은 차용하되 판정 축이 다르다: 저 리뷰어는 *"구현 계획에 준비됐나"*, 우리 critic은 *"사용자 원문을 왜곡하지 않았나"*.

### 코드베이스에서 확정한 사실

- `superpowers` **6.1.1·6.2.0** brainstorming skill 전문에 `interview`/`brief`/`locked_directions` 언급 **0건**. → frontmatter `locked_directions[]`는 **소비자가 없다**. 전달은 순수 프로즈 경로.
- 같은 skill 체크리스트 **4번 = "Propose 2-3 approaches with trade-offs"**(양 버전 공통). ✎ 탐색 능력은 원래 있으므로, brief의 "재논쟁 금지"가 그 단계를 무력화했다는 것이 이 문서의 인과 **가설**이다(측정되지 않음 → OQ11).
- **6.2.0에서 약화된 것**: 6.1.1 `## Key Principles`의 *"Explore alternatives — Always propose 2-3 approaches before settling"* 줄이 삭제됐다. 탐색 지시가 체크리스트 1곳으로 줄었다.
- 같은 skill 체크리스트 **7번 = "Spec self-review"** — 자기 문서 자기 리뷰(Law 2 위반). spec-distill이 `spec-reviewer`를 덧댄 이유이며 brief에도 같은 구멍이 있다.
- `check_brief.py:214-215` — frontmatter에 `locked_directions` 키가 없으면 게이트 실패. LD는 강제 필수 필드.
- **NG3 vs NG6 내부 긴장**: NG3(`check_brief.py:9`, `spec-reviewer.md:17`)는 *"brief는 분리 review 대상이 아니다"*라고 못 박는데, NG6(`2026-07-20-...-design.md:99`)는 *"게이트는 form·존재만 본다. 의미는 orchestrator + 독립 adversary가 담보"*라고 쓴다. brief용 adversary는 존재하지 않는다.
- **`conducting-interview/SKILL.md`의 compact handoff가 "Locked Directions … 보존"을 직접 주입한다** — ✎ 즉 권위 전달 경로가 템플릿 말고 하나 더 있으며, 이 인터뷰에서 검토되지 않았다(→ OQ11).
- 과거 brief 3건의 LD 개수: **9 / 6 / 5**. 최신 brief의 `LD1`은 아키텍처 선택 전문, `LD5`는 파일 단위 구현 범위까지 확정. 개수가 아니라 **종류**가 문제였다.

---

## 5. Blind Spots & Premortem

`blind-spot-prober` 적대적 premortem (confidence 0.75) + orchestrator 판정.

- **숨은 가정: "구조적 분리 = 컨텍스트 명확성 개선"** — 분리는 정보를 없애지 않고 두 파일 간 sync 의무 + "둘 다 로드된다는 보장 없음"으로 전가한다. — https://arxiv.org/html/2406.16008v1 — **[채택 → 분할선 이동으로 완화, 잔여는 OQ12]**
- **숨은 가정: "파일 최상단 = 모델 유효 컨텍스트 앞쪽"** — brief가 더 큰 프롬프트 뒤에 삽입되면 최상단도 물리적으로 '중간'일 수 있다. verbatim을 나란히 둔다고 하류가 능동적으로 diff한다는 보장은 없다 — **기회의 제공이지 게이트가 아니다**. — https://arxiv.org/pdf/2406.14673 — **[채택 → D3 readback이 닫음: 전달을 추론하지 않고 측정한다]**
- **숨은 가정: "리뷰 에이전트 신설 = 의미 검증 확보"** — 원문 접근권이 없으면 재구성 대 재구성의 순환 검증이 된다. — **[부분 반박]** 「원문」이 verbatim이라 순환은 미성립. **잔여 채택**: 「원문」은 최초 요청만이 아니라 **사용자 발화 전부**를 담아야 한다.
- **실패 양식: audit 파일이 안 읽혀 정보 실종** — trigger: 하류가 두 번째 파일을 열 명시적 지시를 못 받는 경우. brainstorming이 `locked_directions`조차 0건 참조한다는 사실이 이미 실증. — **[채택 → 재논쟁 차단 증거를 payload로 이동]**
- **실패 양식: 리뷰 에이전트의 'LGTM theater'화** — trigger: 오역 발견 시 되돌아가는 게이트가 없으면 devbrew가 금지한 **Polite handoff**의 새 변종. — **[채택 → OQ2/OQ3]**
- **실패 양식: LD 제거가 하류 재질문 harassment를 유발** — trigger: 사용자 출처에 아무 신호가 없으면 brainstorming 체크리스트 4번이 goal까지 재탐색 후보로 흡수. — https://www.augmentcode.com/guides/why-ai-agents-repeat-questions — **[채택 → C4가 답]**

---

## 6. 이미 검토·기각된 것

✎ 모델이 인터뷰 중 검토했다가 기각한 것과 그 이유.

- **LD를 "어투만 완화"** (`재논쟁 금지` → `근거 있으면 재검토 가능`) → 기각. 하류가 라벨을 얼마나 곧이듣는지에 성패가 걸리고, `LD1 = 아키텍처 전문` 같은 내용물 문제는 그대로 남는다.
- **LD 전면 제거, 대체 없음** → 기각. 사용자가 이미 답한 것을 하류가 다시 묻는 harassment로 직결.
- **경계 기준을 "제약 vs 아키텍처"로 잡기** → **반증됨**. 사용자는 아키텍처도 정당하게 결정한다.
- **경계 기준을 출처 한 축으로만 잡기** → **codex 리뷰가 반증**. 출처는 잠김의 필요조건이지 충분조건이 아니다 → C6 직교 분해.
- **감사 흔적을 파일 맨 아래로** → 기각. U자상 맨 아래는 고-attention 자리라 행동가치 없는 텔레메트리가 Next Action보다 눈에 띈다.
- **감사 흔적을 문서 중간에 매장** → 기각. 자리 배분은 최적이지만 사람 독자에겐 여전히 난잡.
- **리뷰어에게 audit + 인터뷰 transcript까지 제공** → 기각. 리뷰어가 "왜 이렇게 재구성했는지"를 먼저 납득한 채 원문을 읽으면 재구성 오류 자체가 정당화된다.
- **리뷰어를 advisory로** → 기각. 이빨 없는 리뷰어는 Law 1의 "실제 거절 메커니즘" 미달이고 바쁠 때 조용히 무시된다.
- **단일 파일로 회귀** (steelman, conf 0.72) → **방어**. steelman의 세 논거 중 "brainstorming이 2번 파일을 열 트리거 0건"을 **분할선 이동**으로 제거하고 "총 볼륨"을 압축으로 흡수. verdict: defended. ✎ 단 codex가 **새 논거**로 재도전했다(분할선을 옮기고 나면 audit엔 순수 텔레메트리만 남는데 그걸 영구 문서로 둘 이유가 약하다) → OQ12에 열어둠.

---

## 7. Open Questions

인터뷰에서 해결되지 않은 것. 추정치를 채워 넣지 않았다.

- **OQ1 — C4 계약을 하류가 실제로 지키게 만드는 메커니즘.** 이 brief는 `superpowers:brainstorming`으로 가는데 그 skill은 spec-distill을 모른다. 프로즈 한 줄로 충분한지, Next Action에 명시할지, brief-critic이 "사용자 출처 항목이 보고 없이 변경됨"을 검출할지 — 셋 다 후보.
- **OQ2 — critic·readback의 재실행 cap.** max-iter 수치와 초과 시 동작(강제 escalate? 사용자 게이트?)이 미정. Unbounded-autonomy 금지 대상.
- **OQ3 — readback의 판정자.** 사용자 단독인가, orchestrator가 gap을 먼저 표면화하고 사용자가 최종인가. 결과가 나쁠 때 되돌아가는 게이트가 없으면 Polite handoff가 된다.
- **OQ4 — readback red-flag 기준을 어디에 둘 것인가.** ⚠ 실측: 기준을 payload에 두면 측정 대상이 오염되어 테스트가 무효가 된다(시범 실행에서 에이전트가 스스로 보고). 기준은 orchestrator·에이전트 프롬프트 쪽에 있어야 한다. 기준의 *내용*과, 이 문서에 남은 언급 자체의 처리가 미정.
- **OQ5 — D3의 "사용자와 Claude 양쪽"이 무엇을 뜻하는가.** readback 에이전트는 하나인데 검증 대상 독자는 둘이다. 사람 대상 검증이 별도 절차라면 그것이 어디에도 규정되지 않았다.
- **OQ6 — C5와 D1~D5의 경계("성질" vs "규약")를 기계적으로 적용할 수 있는가.** 이 구분이 새 템플릿을 쓸 때 실제로 적용 가능한 기준인지 확인되지 않았다. **같은 실수가 재발할 가장 유력한 지점.**
- **OQ7 — `check_brief.py` 게이트 스키마 변경 범위 + 기존 brief 3건 취급.** 게이트 실행 결과 8항목이 실패했고 조항별 판정은 audit 참조. ⚠ **2파일 분리는 게이트에 fail-open 구멍을 낸다** — 현행 게이트가 형식 검증하는 Skepticism·Coverage Ledger가 audit로 가면 게이트가 payload만 읽는 한 두 검증이 통째로 증발한다. 분리와 게이트 스코프 확장은 한 몸. ⚠ 그리고 그 8항목 판정은 당사자가 내렸고 codex 리뷰도 이 부분은 별도 검증하지 않았다.
- **OQ8 — 리뷰 역할들의 배치.** 역할이 넷이다 — critic(a: 충실도) / (b: 방향성, D5) / codex(D4) / readback(D3). ⚠ **D2와 D5가 충돌한다**: D2는 critic을 payload-only + `Read/Grep/Glob`로 묶는데 (b)는 외부 근거 조사를 요구한다. 후보 — (b)를 별도 계약(payload + repo + 제한적 외부조사)으로 분리 / (b)를 codex에 몰아주되 codex 부재 시 fail-open이므로 Claude fallback + loud downgrade 필요 / 넷으로 쪼개면 fan-out 비용.
- **OQ9 — 새 payload 템플릿의 섹션 목록·이름·번호.** ☑ 의도적 미결. 이 brief 자신의 구조는 **작동하는 후보**이지 명세가 아니다. 비교 후보 예시: snapshot-first / verbatim-first / concise-single-file. 제약은 C1·C2·C3·D1뿐이다.
- **OQ10 — readback을 hard verdict로 쓸 수 있는가.** ✎ codex 지적: fresh agent는 잘못 재구성된 payload도 정확히 요약할 수 있다. readback은 "수신자가 무엇을 이해했는가"를 재는 **가독성 테스트**이지 충실도 검증이 아니며, 원래 의도와 비교할 독립 ground truth가 없다. advisory로 제한하고 최종 비교는 사용자에게 맡기는 안이 후보.
- **OQ11 — 포맷 전면 재작성 전에 전환 adapter만 고쳐 측정해야 하는가.** ✎ codex 지적: 실패를 만든 직접 레버는 레이아웃보다 **producer와 전환 프롬프트가 전달한 행동 의미**일 수 있다. 현행 템플릿이 "재논쟁 금지"를 직접 쓰고 `SKILL.md`의 compact handoff도 "Locked Directions 보존"을 주입하는데, 하류는 스키마를 해석하지 않는다. **최소 변경(그 두 문구 제거) 후 과거 brief로 탐색 폭을 회귀 측정하고 전면 재작성은 그 뒤에** — 이 안이 이 작업 전체의 규모 타당성을 겨눈다. ☑ 사용자 판단으로 방향은 유지하되 미결로 박제.
- **OQ12 — 2파일이 정말 필요한가.** ✎ codex 지적: 분할선을 옮긴 뒤 audit에는 하류가 읽지 않아야 할 순수 텔레메트리만 남는데, 그것을 handoff 옆 영구 문서로 유지하면서 게이트까지 2파일로 넓힐 이유가 약하다. 파일 누락·경로 drift·부분 검증이라는 새 실패면이 붙는다. 대안: 단일 payload + 텔레메트리는 기존 session-local state, 장기 감사가 필요하면 별도 validator. ☑ 사용자 판단으로 D1 유지하되 미결로 박제.

---

## 8. Next Action

다음 stage는 `superpowers:brainstorming`(해답공간)이며 이 brief가 그 입력이다. 미결은 OQ1–OQ12.

### 이 brief 자체가 통과한 검증

- **`check_brief.py` 게이트** — 실행(2026-07-25, exit 1). 8항목 실패, 조항별 판정은 audit. brief 쪽 결함 1건은 수정 완료. 나머지는 이 설계가 바꾸려는 게이트 조항. 이 실행이 blind-spot·steelman 둘 다 놓친 fail-open 위험을 드러냈다(OQ7).
- **readback 시범 실행** — 프레시 에이전트가 payload만 읽고 문제 진단·확정/미결·산출물을 정확히 재현했고, "구현 계획을 쓰지 않고 OQ를 2–3안으로 탐색하겠다"고 답했다. 과잉결정 신호는 나오지 않았으나, 에이전트 스스로 그 답이 payload 안 red-flag 기준에 오염됐다고 보고했다(OQ4).
- **codex 독립 리뷰** — 실행(2026-07-25, 충실도 5건 + 방향성 7건). 충실도 지적은 전부 반영했고(출처 미기록·✎ 누락·최상단 배치 위반·규약 잔존·내부 모순), 방향성 지적 중 **판별식의 출처-단일축 결함은 C6로 수용**, 나머지 둘은 OQ11·OQ12로 박제. 전문은 audit.
- **미실행** — `brief-critic` / `brief-readback` 정식 컴포넌트. 이 설계의 산출물이라 아직 존재하지 않는다.

### 생산해야 하는 것

☑ *"산출물만 명명"* — 무엇을 만들지는 적고, 어떻게 생길지는 확정하지 않는다.

| 파일 | 성격 |
|---|---|
| `plugins/spec-distill/templates/interview-brief-template.md` | 재작성 — payload 템플릿 |
| audit(텔레메트리) 템플릿 | 신규 — ✎ 단 OQ12가 2파일 자체를 열어둔 상태 |
| `plugins/spec-distill/scripts/check_brief.py` | 수정 — 섹션 목록 갱신 + `locked_directions` 강제 제거 + 2파일 스코프(fail-open 봉쇄) + 인용 검사 스코프(외부 URL 근거와 코드베이스 근거 구분) |
| brief-critic 에이전트 | 신규 — D2. 쓰기 없는 `tools:` allowlist(Law 2) |
| 방향성 리뷰 역할 | 신규 — D5. ✎ critic과 한 몸일지 별개일지는 OQ8 |
| brief-readback 에이전트 | 신규 — D3. 순진함 보장이 설계 핵심 |
| codex brief-리뷰 프롬프트 빌더 | 신규 — D4. `detect_codex.sh` 재사용, prompt 빌더는 신규 |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 수정 — 종료 파이프라인 재구성. 현행 `pending_locked_decisions`(라운드마다 확정 결정을 모으던 필드)를 source×status 모델로 교체. ✎ compact handoff의 "Locked Directions 보존" 주입도 여기서 처리(OQ11) |
| `plugins/spec-distill/agents/spec-reviewer.md` | 수정(문구) — NG3 서술이 더 이상 사실이 아니게 됨 |
| `plugins/spec-distill/plugin.json` · `CHANGELOG.md` | 수정 — SemVer bump + 이력. ✎ 폭 미정(현재 `v0.22.0`, breaking format이므로 `0.23.0`인지 `1.0.0`인지는 OQ7과 함께) |

✎ 에이전트를 몇 개 파일로 가를지는 **OQ8에서 미결**이다 — 위 표는 *역할* 목록이지 파일 목록이 아니다.

✎ **원문의 불변식은 "내용 불변"이 아니라 "provenance 보존"이다.** critic 수정 루프가 원문을 자유롭게 고치면 순환 검증을 막는 앵커가 무너진다. 그렇다고 내용 불변으로 못 박으면 `CLAUDE.md` P21(secret placeholder 치환)·오타 정정·사용자 철회와 충돌한다. → 기록 시점에 secret은 강제 redaction하고, 이후 변경은 원문 덮어쓰기가 아니라 **사용자 승인 정정 이벤트 + 이유**로 남기는 형태가 후보다(codex 지적 수용).
