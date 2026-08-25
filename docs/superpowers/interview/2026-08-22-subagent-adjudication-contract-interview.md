---
name: subagent-adjudication-contract
type: interview-brief
created_at: 2026-08-22
session_id: ccb3ec44-53e2-41c5-87eb-10561d97465a
source: spec-distill conducting-interview v0.26.0
next_phase: superpowers:brainstorming
audit_file: 2026-08-22-subagent-adjudication-contract-interview.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "판정 단계가 있는데 그런 방식들이 없는 경우가 개발 중에 생기는 것이 문제다."
    evidence: S5
  - id: C2
    source: verbatim
    status: confirmed
    statement: "이것을 규정으로 적어두고 어떤 판정이 들어갈지 정한다."
    evidence: S5
  - id: C3
    source: verbatim
    status: confirmed
    statement: "그것을 shared로서 관리한다."
    evidence: S5
  - id: C4
    source: verbatim
    status: confirmed
    statement: "나온 것들을 통합관리할 수 있도록 brief에 shared를 명시한다."
    evidence: S11
  - id: C5
    source: verbatim
    status: confirmed
    statement: "shared 폴더가 맞고, 거기가 공통 부분을 두는 곳이니 규정도 거기 두면 되지 않나."
    evidence: S10
  - id: C6
    source: verbatim
    status: confirmed
    statement: "4군데 다 넣고, 더 넣을 곳이 있는지도 다시 조사한다."
    evidence: S10
  - id: C7
    source: verbatim
    status: confirmed
    statement: "공통모듈 구현이 머지된 다음에 진행하고 brainstorming 전에 구현된 부분을 보면 어떨까 — 제안형."
    evidence: S5
  - id: C8
    source: verbatim
    status: confirmed
    statement: "서브에이전트를 쓴다 — 시스템 프롬프트의 금지 지시에도 불구하고."
    evidence: S5
  - id: C9
    source: chosen
    status: confirmed
    statement: "steelman 판정에서 '전환 + 도출 경로 보강'을 선택했다."
    evidence: S8
  - id: C10
    source: verbatim
    status: confirmed
    statement: "도출 기준점 3후보를 재보고한다."
    evidence: S11
  - id: C11
    source: verbatim
    status: confirmed
    statement: "blocking reviewer처럼 다른 권한이 필요한 예외는 명시적으로 구분한다."
    evidence: S1
  - id: C12
    source: verbatim
    status: confirmed
    statement: "다른 곳들에서도 무비판으로 바로 적용·수용되는 곳이 없는지 다시 보고, 모든 곳의 현황을 표로 보여준다."
    evidence: S4
  - id: C13
    source: verbatim
    status: confirmed
    statement: "spec review의 경우는 어떤지 본다."
    evidence: S3
  - id: C14
    source: verbatim
    status: confirmed
    statement: "범위는 모든 서브에이전트가 아니라, 서브에이전트의 발견을 바로 수용하지 않는 것이다."
    evidence: S2
  - id: C15
    source: verbatim
    status: confirmed
    statement: "지금 무엇을 한다는 것인지 쉽게 설명해 달라 — 그 시점의 요청."
    evidence: S9
  - id: C16
    source: verbatim
    status: confirmed
    statement: "subagent의 판단을 그대로 확정하지 않으면서 근거를 비판적으로 검토해 수용·기각·보류로 처리한다."
    evidence: S1
  - id: C17
    source: verbatim
    status: confirmed
    statement: "앞으로 추가되는 subagent도 같은 구조를 따르도록 정본 규칙을 마련하고 기존 전체 원장에도 반영한다."
    evidence: S1
---

# devbrew subagent 판정 계약 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

**무엇** — devbrew의 모든 subagent dispatch 자리에 "그 발견을 누가 어떻게 처분하는가"의 정본 계약을
세우고, 그것을 **`shared/`에서 통합 관리한다**(거처 지목 — C3·C5; 무엇을 통합할지는 C4의 "나온 것들"이며
자리·결함 두 원장으로의 분해는 저자 도출이다).

**왜** — 조사 결과 dispatch 자리 **33곳** 중 **10곳이 무검증 직행**이고, 별도로 **11곳이 판정 단계
안에서 조용히 버린다**. 후자가 더 위험하다 — 이 리포에서 발견이 소실된 최악의 두 사고가 그 자리에서
났고, "판정자가 있는가"만 묻는 census는 그 두 곳을 준수로 채점했다.

**무엇이 정해졌나** — 사용자 발화에서 나온 제약 17항목이 종료 게이트에서 `confirmed` 로 확정됐다(§2).
저자 도출로 남은 것: 새 frontmatter
키와 SDD import 기각(ST1 — 사용자 발화는 옵션 라벨뿐이고 그 내용은 저자가 붙였다, §2 ✎(3)) · 자리 도출 후보로 **에이전트 이름 패턴 훑기**(저자
측정 5/5 표기 커버 — 사용자 수용 앵커는 아직 §6에 없다) · **거처는 `shared/`(C3·C5), 배포 형태는 미정** — 심볼릭
링크로 `skills/*/references/`에 내리는 형태는 §8 가드를 경로 모양만으로 통과함이 실측됐다(OQ1·OQ2 /
방향성 D4 — audit §5).

**무엇이 열려 있음** — `shared/` 안의 배치와 배포 형태, drop-채널 관측 가능성의 측정 방법, 생성 시점
독자에게 규정을 읽히는 경로(현재 권위가 외부 플러그인 skill).

**다음 stage** — brainstorming 해답공간. 진입 전 `shared/` 구현물(README·두 계약 락)을 읽는다.

## 1. Goal · Non-goal

- **Goal 1**: subagent 발견의 처분 계약을 정본화하고 `shared/`에서 통합 관리한다(C3·C5) — 배포 형태는 OQ1·OQ2 가 판정한다.
- **Goal 2**: 새 dispatch 자리가 계약 없이 추가되는 것을 잡는다(C17) — ✎ *기계가* 잡는다는 집행 형태는 저자 도출이며 §6 앵커가 없다.
- **Goal 3**: 이미 발견된 21건(무검증 10 + 조용한 버림 11)을 한 원장에 **등재**한다 — 등재는 추적이며 수리 범위 확정이 아니다(OQ10).
- **Non-goal 1(잠정)**: CI 도입. 근거로 든 설계 C16 은 같은 설계 문서에 **미해소 부채**로 기록돼 있고 §6에 이를 지지하는 사용자 앵커가 없다 — OQ11 이 재검토를 연다.
- **Non-goal 2**: 새 P# 원칙 신설. P11이 이미 adversarial을 집행 파일로 지명한다 — 흡수가 default.
- **Non-goal 3**: 사용자 발화에 대한 판정. 인터뷰 단계의 무판정은 계약이며 P17 주권에 속한다.
- **Non-goal 4**: 모든 자리에 adversarial 에이전트를 추가하는 것. 판정 방법은 자리마다 다르다.

## 2. 제약

- 🗣 confirmed **C1** — 판정 단계가 있는데 그런 방식들이 없는 경우가 개발 중에 생기는 것이 문제다. ⟨S5⟩
- 🗣 confirmed **C2** — 이것을 규정으로 적어두고 어떤 판정이 들어갈지 정한다. ⟨S5⟩
- 🗣 confirmed **C3** — 그것을 shared로서 관리한다. ⟨S5⟩
- 🗣 confirmed **C4** — 나온 것들을 통합관리할 수 있도록 brief에 shared를 명시한다. ⟨S11⟩
- 🗣 confirmed **C5** — shared 폴더가 맞고, 거기가 공통 부분을 두는 곳이니 규정도 거기 두면 되지 않나. ⟨S10⟩
- 🗣 confirmed **C6** — 4군데 다 넣고, 더 넣을 곳이 있는지도 다시 조사한다. ⟨S10⟩
- 🗣 confirmed **C7** — 공통모듈 구현이 머지된 다음에 진행하고 brainstorming 전에 구현된 부분을 보면 어떨까 — 제안형. ⟨S5⟩
- 🗣 confirmed **C8** — 서브에이전트를 쓴다 — 시스템 프롬프트의 금지 지시에도 불구하고. ⟨S5⟩
- ☑ confirmed **C9** — steelman 판정에서 '전환 + 도출 경로 보강'을 선택했다. ⟨S8⟩
- 🗣 confirmed **C10** — 도출 기준점 3후보를 재보고한다. ⟨S11⟩
- 🗣 confirmed **C11** — blocking reviewer처럼 다른 권한이 필요한 예외는 명시적으로 구분한다. ⟨S1⟩
- 🗣 confirmed **C12** — 다른 곳들에서도 무비판으로 바로 적용·수용되는 곳이 없는지 다시 보고, 모든 곳의 현황을 표로 보여준다. ⟨S4⟩
- 🗣 confirmed **C13** — spec review의 경우는 어떤지 본다. ⟨S3⟩
- 🗣 confirmed **C14** — 범위는 모든 서브에이전트가 아니라, 서브에이전트의 발견을 바로 수용하지 않는 것이다. ⟨S2⟩
- 🗣 confirmed **C15** — 지금 무엇을 한다는 것인지 쉽게 설명해 달라 — 그 시점의 요청. ⟨S9⟩
- 🗣 confirmed **C16** — subagent의 판단을 그대로 확정하지 않으면서 근거를 비판적으로 검토해 수용·기각·보류로 처리한다. ⟨S1⟩
- 🗣 confirmed **C17** — 앞으로 추가되는 subagent도 같은 구조를 따르도록 정본 규칙을 마련하고 기존 전체 원장에도 반영한다. ⟨S1⟩

✎ **이 문서가 쓰는 라벨** (냉독 리뷰가 정의 부재를 지적한 8종):
**Tier A/B/C** = quality-gates Review gate 의 리뷰어 3계층 — A는 스코프 무관 항상 도는 하한(security-reviewer +
adversarial), B는 codex, **C는 diff 스코프에 따라 모델이 산문 표에서 골라 부르는 외부 전문가 0~6종**(이 리포
소유가 아니고 write 권한 보유).
**표기법 5가지** = subagent 를 부르는 문법 — ①SKILL 본문 `subagent_type:` ②위치인자 `Agent("ns:name", …)`
③Workflow `agentType:` ④skill frontmatter `context: fork` + `agent:` ⑤정의 없이 **산문 표 한 칸**(Tier C).
**33 = 10 + 11 + 12** — 무검증 직행 10, 판정기 내부에서 조용히 버림 11, **나머지 12는 판정과 계측이 둘 다 있는
정상 자리**(qg Review·artifact 비평·plugin-audit 체인 등).
**잔여 8건** = 이름 패턴 훑기가 낸 33 토큰에서 로컬 agent 정의 18 + skill 디렉토리 7 을 자동 제외하고 남은 것 —
외부 Tier C 6 + 죽은 참조 `quality-gates:synthesizer` + hook 이름 `quality-gates:session-tracker`.
**ST1** = audit §3 의 steelman 원문. **D1~D7** = 방향성 리뷰 findings, 목록은 **audit §5**(payload 에는 없다).

✎ **모델 추론(사용자 발화 아님)** — (1) 문제를 "상태가 아니라 생성 과정"이라는 배타적 대조로 재구성한 것
(2) "인터뷰 단계를 무판정 대상에서 제외하자"는 저자 제안 — 사용자는 이를 기각한 적이 없고, C6("4군데 다
넣고")에 따라 저자가 철회했다 (3) C9가 고른 옵션의 내용 — steelman 3단계(4사이트 직접수정 · agent 락에
`# guards:` 한 줄 · SDD import 대신 proceed-gate 정본에 판정 절 흡수)와 원안 기각. 사용자에게 남은 발화는
옵션 라벨뿐이므로 §6만으로는 검증되지 않는다 (4) Goal 2 의 **"기계가 잡게 한다"** 는 집행 형태 — S1 은
"정본 규칙을 마련하고"까지이고 자동 집행을 요구한 발화는 §6에 없다.

✎ **거처와 성립 가능성은 다른 문제다.** 사용자는 C3·C5로 `shared/`를 **지목했다**. 그 지목은 살아 있다.
저자 측정에서 나온 것은 그 배치의 **한 형태**(심볼릭 링크로 `skills/*/references/`에 내리는 것)가 §8 가드를
경로 모양만으로 통과한다는 사실이며, 이는 거처를 무르는 근거가 아니라 **배포 형태의 제약**이다(OQ2·§5 위험).
**"두 원장(자리·결함)"이라는 분해는 저자 도출이다** — 사용자 발화는 "통합관리"(C4)까지다.

✎ **C8의 수명은 원문에 없다.** S5 괄호는 도구 허가만 말하고 그것이 이 세션 한정인지 항구적인지 말하지
않는다. 다음 stage 는 이를 **설계 제약으로 읽어서는 안 된다**.

✎ **C11·C16·C17은 S1 한 문장에서 나왔다.** 같은 발화의 "역할·입력·출력·권한·결과 처리·degrade 방식을 공통
계약으로" 절만 S2 정정으로 대체됐다(§5 첫 항목). **`수용·기각·보류` 3분류와 예외 구분·정본 규칙 요구는
철회 근거가 §6에 없어 살아 있다.**

✎ **C6의 "4군데"는 분모 22 시절의 수다.** S10 발화 시점 census 는 22 자리였고 같은 축 RED 가 4곳이었다.
다음 라운드에 분모가 33으로 재산정되며 같은 축이 10곳이 됐다. 사용자는 같은 발화에서 확장도 요청했으므로
**어디까지를 수리 범위로 볼지**가 OQ10 이다.

✎ C7의 순서 제약은 실측상 **이미 충족**됐다 — PR #117~#124 전부 머지, HEAD `c2539c8`.

## 3. Open Questions

- OQ1: 계약 문면을 `shared/`의 어느 하위에 두나 — 기존 4개(`codex`/`killswitch`/`gc`/`tests`)에 없는 축이다.
- OQ2: 배포 형태 — 심볼릭 링크로 각 플러그인에 내릴 것인가, `CLAUDE.md` 포인터만으로 충분한가.
- OQ3: presence 락과 absence 락의 코퍼스 분리를 어떤 구조적 가드로 강제하나(감사 §8은 "주석은 부족"이라고 명시).
- OQ4: "버린 걸 세는가"를 기계가 어떻게 판정하나 — 코드 패턴인가, 산출물 스키마 요구인가.
- OQ5: 생성 시점 독자에게 규정을 읽히는 경로 — 실제 권위가 외부 플러그인 `plugin-dev:agent-development`다.
- OQ6: 21개 결함을 이 사이클에서 고치나, 계약만 세우고 별도 사이클로 미루나.
- OQ7: Tier C 외부 6종(이 리포 소유 아님, write-capable)을 계약이 어디까지 구속할 수 있나.
- OQ8: 이름 패턴 훑기의 잔여 8건 중 정당한 것(외부·hook)을 어떻게 항구적으로 구분하나 — `none` 면제의 재판을 피해야 한다.
- OQ9: 죽은 참조(`quality-gates:synthesizer`)를 이 사이클에서 제거하나 별건인가.
- OQ10: **수리 범위** — 사용자가 승인한 4곳인가, 재산정 후 같은 축 10곳인가, 21건 전부인가(방향성 D2 — audit §5).
- OQ11: **런타임 seam** — `PostToolUse(matcher=Agent)`가 메인에 배달된다는 실측이 있다. Non-goal 1이 닫은 훅 갈래를 현재 CLI 버전에서 재측정할 것인가(방향성 D1 — audit §5; 되살리기 조건 4개는 이미 명문화).

## 4. External Landscape

- Fusion Agent의 Evidence-Based Adjudication — 에이전트별 인용 근거를 비교해 충돌 해소 — https://dl.acm.org/doi/full/10.1145/3800227.3800266 — [중립] — 근거 비교 축은 유용하나 devbrew는 이미 refuter/grounding으로 구현
- Anthropic multi-agent — subagent 계약은 자기완결 task + 출력 형식 + 새 context가 전부 — https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them — [취함] — 계약을 얇게 유지하는 근거
- Anthropic Building Effective Agents — 가장 단순한 해법부터, 필요할 때만 복잡도 추가 — https://www.anthropic.com/engineering/building-effective-agents — [취함] — 3층 신설 대신 기존 축 재사용의 근거
- superpowers SDD 처분 규율 — park/rule/deferred + Ruling 서식 + silent discard 금지 — https://github.com/obra/superpowers/blob/main/skills/subagent-driven-development/SKILL.md — [피함] — **사용자가 S6에서 지목·S7에서 선택한 원안**이었으나 S8에서 전환. devbrew가 더 강한 형태 보유(수신자가 원장이 아니라 사용자)
- Google Tricorder — 비차단·별도 대시보드형 검사기는 무시됐고, 빌드를 깨뜨릴 때만 품질이 ratchet up — https://cacm.acm.org/research/lessons-from-building-static-analysis-tools-at-google/ — [취함] — "선언 규정 + 비차단 검사기" 기각의 외부 근거
- GitHub CODEOWNERS — branch protection을 켜지 않으면 소유자 선언은 제안일 뿐 요구가 아님 — https://www.arnica.io/blog/what-every-developer-should-know-about-github-codeowners — [취함] — CI 없는 리포에서 새 선언 키의 운명
- Suppression 실증 — 7,357개 중 50.8%가 무용이며 프로젝트당 수는 시간에 따라 증가 — https://software-lab.org/publications/fse2025_suppressions.pdf — [취함] — `none` 면제값이 다수값이 되는 실패의 근거
- Automation complacency — 자동 보조가 있으면 omission error가 훈련으로도 안 줄어듦 — https://journals.sagepub.com/doi/10.1177/0018720810376055 — [중립] — 판정자 추가가 사용자 감시를 줄일 위험

## 5. 기각 · Blind Spots

- 기각 — 모든 subagent를 하나의 계약(역할·입력·출력·권한·결과처리·degrade)으로 통일 → 사용자가 S2에서 직접 정정: 범위는 "발견을 바로 수용하지 않는 것"이다
- 기각 — 무판정 4곳 중 인터뷰 단계를 제외 → **저자 제안이었고 저자가 철회**(사용자가 기각한 발화는 없다; C6 "4군데 다 넣고"가 계기). 그 자리의 무판정 계약은 사용자 발화 대상이지 subagent 보고 대상이 아니다
- 기각 — 모든 agent에 `adjudicated_by:` 전칭 선언 + superpowers SDD 처분 규율 import (**사용자가 S6에서 지목, S7에서 선택한 원안**; S8에서 전환) → 런타임이 읽지 않는 키는 이 리포가 이미 반증한 조합이고(`Principles Instantiated` 5개 중 2개 위반 방치), `none` 허용이 준수와 무판정을 구별 불가능하게 만든다 — https://cacm.acm.org/research/lessons-from-building-static-analysis-tools-at-google/ — verdict: switched — ST1
- 기각 — dispatch 자리를 `subagent_type` grep으로 도출 → 실측 결과 표기법이 5가지이고 그 grep은 1가지만 잡는다. GitHub 게시 경로와 Review gate fan-out 대부분을 놓친다
- 기각 — 표기법을 하나로 통일한 뒤 도출(후보 ⓐ) → 5개 중 3개가 다른 도구 API·다른 계층이거나 설계 의도(model-owned selection)를 파괴해야 통일된다
- 기각 — agent 정의에서 역방향으로 소비자 찾기(후보 ⓒ) → Tier C 외부 6종은 이 리포에 정의가 0개다
- 위험 — 숨은 가정: "판정 유무"가 측정할 옳은 변수다 → 발견 소실 최악의 두 사고는 판정기 *내부*에서 났고 유무 census는 그 자리를 준수로 채점한다 — `plugins/quality-gates/CHANGELOG.md:1927,1931`
- 위험 — 숨은 가정: 정본을 `shared/`에 두면 생성 과정이 읽는다 → `CLAUDE.md`·`docs/plugin-authoring.md` 모두 "shared" 0회이고 실제 생성 권위는 외부 플러그인 skill이다 — grep 실측
- 위험 — 숨은 가정: 자기신고 선언이 실제 판정 경로와 같다 → 앵커가 피검자 통제 문자열이면 감사 범위가 무너진다 — `plugins/spec-distill/tests/test_web_kill_switch.sh:278`
- 위험 — 실패 양식: `none`이 다수값이 되어 규정이 면제 원장으로 변한다 — https://software-lab.org/publications/fse2025_suppressions.pdf
- 위험 — 실패 양식: 락이 키의 부재에만 이빨을 가져 값이 락을 만족시킨다. 판별법 = `none`을 전 파일에 심는 mutation이 RED가 아니면 이빨 0
- 위험 — 실패 양식: 판정을 넣자 정보가 줄어든다 — refute가 기각과 함께 기계적 사실까지 지운다
- 위험 — 실패 양식: 규정이 subagent 생성을 억제해 census가 볼 수 없는 곳에서 Law 2가 약해진다 — 리포 절대 조항 "무겁게 만들어 능력 제한 금지"
- 위험 — 실패 양식: `shared/` 정본을 심볼릭 링크로 `skills/*/references/`에 내리면 §8 가드가 **경로 모양으로** own 판정해 통과시킨다 — 가드가 참이 아닌 초록을 찍는다 — `shared/tests/presence_corpus.sh:35`
- 위험 — 숨은 가정: Non-goal 1의 "실행 지점을 늘리지 않는다"가 훅 갈래까지 닫는다 → 인용된 C16 은 설계 문서에 **미해소 부채**로 기록돼 있지 해결된 결정이 아니다 — `docs/superpowers/specs/2026-08-16-devbrew-weight-reduction-design.md`
- 위험 — 실패 양식: 규정 자신이 무판정 지점이 된다 — `CLAUDE.md:44` "막지 않는 것을 막는다고 믿게 만드는 선언은 없는 것보다 나쁘다"

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S1** 🗣 최초 요청:
  > "먼저 `quality-gates`의 advisory subagent 방식과 orchestrator가 결과를 소비하는 구조를 점검해줘. 이 방식을 기준으로 저장소에서 subagent를 사용하는 모든 경로를 조사하고, subagent의 판단을 그대로 확정하지 않으면서도 근거를 비판적으로 검토해 `수용·기각·보류`로 처리하는 공통 구조로 통일해. 역할·입력·출력·권한·결과 처리·degrade 방식을 공통 계약으로 만들고, blocking reviewer처럼 다른 권한이 필요한 예외는 명시적으로 구분해. 앞으로 추가되는 subagent도 같은 구조를 따르도록 정본 규칙을 마련하고 기존 전체 원장에도 반영해."

- **S2** 🗣 방향 정정:
  > "내가 말한게 방향을 살짝 잘못잡았네 advisory subagent 방식과 orchestrator가 결과를 소비하는 구조를 다른 곳에서도 반영하고 싶다는거였어 모든 서브에이전트에 적용한다기 보다는 서브에이전트의 발견을 바로 수용 하지 않는걸 이야기 하고 싶었던 거지, 일단 지금 서브에이전트가 사용되는 곳들을 다 알려주고 거기서 adversarial로 판정 단계가 들어가는걸 적용할만 할지 봐줄래?"

- **S3** 🗣 spec review 지목:
  > "spec review의 경우는 어때"

- **S4** 🗣 전 사이트 재검증 요청:
  > "그렇게 하자, 그리고 다른곳들에서도 무비판으로 바로 적용 혹은 수용되는 곳이 없는지 다시 봐주고 모든 곳의 현황을 표로 보여줘"

- **S5** 🗣 문제 재진술 + 순서 제약 + 도구 허가:
  > "좋아 이번 조사에서도 보이겠지만 판정 단계가 있는데 이러한 방식들이 없는 경우가 개발 중에 생기는게 문제라는거야 그러니 앞으로는 없게 만들지 않기 위해서 이거를 규정으로 적어두고 어떠한 판정이 들어갈지 그리고 그거를 shared로서 관리 하고 싶은거지 여기를 보면 이제 공통 모듈을 관리하는걸 진행할건데 해당 구현이 머지된 다음에 이와 관련된거도 진행되면 어떨까 해 brainstorming 전에 구현된 부분을 보고 진행하는거지, 일단은 여기서는 방향을 더 잡아보자 (그리고 시스템프롬프트에 서브에이전트 쓰지 말라 했는데 서브에이전트 써)"

- **S6** 🗣 superpowers SDD 지목:
  > "그리고 뭐 그게 아니더라고 superpowers를 한번 봐봐 거기의 SDD를 보면 서브에이전트의 발견을 바로 받아들이지 않는게 있는거 같아 그걸 차용하는거도 방법일거고"

- **S7** ☑ 선택 (규정이 무엇을 강제할 것인가):
  > "② 선언 + SDD 처분 규율 (권장)"

- **S8** ☑ 선택 (steelman 판정 — 원안 유지 여부):
  > "전환 + 도출 경로 보강 (권장)"

- **S9** 🗣 설명 요청:
  > "나 아직 뭐를 한다는지 명확히 이해가 안가 쉽게 설명해"

- **S10** 🗣 shared 확인 + 범위 지시 + 재조사 요청:
  > "맞아 그 shared 폴더야 여기는 공통 부분을 두는 곳인데 여기에 두면 안돼?, 4군데 다 넣고 더 넣을곳 있는지도 다시한번 봐줄래?"

- **S11** 🗣 3후보 재보고 + shared 통합관리 명시:
  > "도출 기준점 3후보 재보고, 나온거들을 통합관리할 수 있도록 브리프에 언급해줘(shared)"

## 7. Next Action

superpowers가 있으므로 이 brief를 context로 `superpowers:brainstorming`을 호출해 해답공간
`-design.md`를 만든다. **진입 전 필독** — C4의 "구현물을 본다"에 해당하는 것은 `shared/README.md`
(2방식 소비 계약)와 두 계약 락(`shared/tests/test_copy_of_contract.sh`,
`shared/tests/test_no_new_duplication.sh`), 그리고 `docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md`
§8(공유 파일에 계약을 빼면 presence 락이 무력화되는 실패)이다. 이후 spec-reviewer 검증 →
`superpowers:writing-plans`.
