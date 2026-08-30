## 종료 — brief 작성 + optional handoff

종료 driver는 **커버리지 원장의 floor 5차원이 전부 `closed`** 인 것이다(고정 라운드 수 아님, G1).
다음을 모두 만족하면 brief를 작성합니다:

- floor `root_problem` closed — 진짜 problem이 한 문장으로 재구성(R1 계열).
- floor `landscape` closed — landscape가 인용과 함께 수집(R2 계열, web sweep 메커니즘 유지).
- floor `skepticism` closed — 의심 방향이 모두 steelman 통과(R3 계열, steelman-builder 게이트 유지).
- floor `blind_spot` closed — blind-spot-prober가 unknown-unknown을 표면화하고 payload §5의 `위험` 항목에 기록.
- floor `open_questions` closed — 미해결 명시(박제, "유추 금지").

각 차원의 status 전이(open→in-progress→closed)와 evidence 기록은 **orchestrator만** 수행하며
(coverage-mapper·blind-spot-prober는 read-only 제안자, Law 2), state.local.md에 쓰는 동시에
audit §1 `## Coverage Ledger`에 직렬화합니다.

**사용자-승인 박제로 닫힌 floor** — `evidence` 가 `사용자-승인 박제` 로 시작하는 차원은
그 내용을 payload `## 3. Open Questions` 에 한 항목으로 옮긴다. 박제된 차원은 「닫혔다」가
아니라 「사용자가 지금은 안 하기로 했다」이므로, 다음 단계가 그것을 열린 질문으로 본다.

### Step A — brief 작성 (terminal 산출물, 2파일)

1. `${CLAUDE_PLUGIN_ROOT}/templates/interview-brief-template.md`로 payload **8-section**
   구조(§0 한눈에 – §7 Next Action)를, `${CLAUDE_PLUGIN_ROOT}/templates/interview-audit-template.md`로
   audit **5-section** 구조를 확보합니다.
2. 경로 (둘 다 워크트리 안 → `Write` tool 사용):
   - payload: `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.md`
   - audit:   `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.audit.md`
   - payload frontmatter: `type: interview-brief`, `next_phase: superpowers:brainstorming`,
     `session_id`(기존 spec-distill 세션 재사용), `audit_file`(audit의 **basename만** —
     경로 구분자가 들어가면 게이트가 거부합니다), `user_sourced_items[]`.
3. **`user_sourced_items` 직렬화**: state의 `user_statements`를 훑어 제약으로 승격할 항목을
   고르고, 각각에 id·`source`·`statement`·`evidence`(그 발화의 `S<N>`)를 붙입니다.
   **이 시점의 `status`는 전부 `provisional`입니다** — `confirmed`는 Step B-0의 사용자 확인
   으로만 발생합니다. 모델 추론은 이 리스트에 넣지 말고 본문에 ✎ 프로즈로 씁니다.
   `user_statements`의 발화 전부를 payload §6에 **전문 보존**하고 `S<N>` 앵커를 답니다.
   **최초 요청 원문은 `S1`이다.** `$ARGUMENTS`(사용자가 `/interview`에 함께 넘긴 rough
   request)를 `user_statements`의 첫 항목과 **같은 형식**으로 §6 맨 앞에 넣습니다.
   Phase 0 을 거친 세션에서는 그 `$ARGUMENTS` 가 `interview-seed` 파일 전문이고, 그때도
   같은 규칙이 그대로 적용됩니다:
   ```yaml
   - id: S1
     source: verbatim
     round: 0
     text: "<$ARGUMENTS 원문 그대로>"    # P21 secret placeholder 치환 적용
   ```
   존재하면(인자 있음) `user_statements`의 id 번호도 이 예약을 반영해 `S1`이 아니라
   `S2`부터 시작합니다 — 최초 요청 원문 있으면 1, 없으면 0 을 더해 SKILL.md `사용자 발화
   기록`의 번호 공식과 합의합니다(그러지 않으면 §6에 `S1` 앵커가 원문과 첫 답변 둘로
   중복되거나, state의 `S1`과 payload의 `S1`이 서로 다른 텍스트를 가리켜
   `check_verbatim_coverage.py`의 앵커 중복·포함 검사가 red를 냅니다).
   비어 있으면(인자 없이 호출) `S1`을 만들지 않고 `S2`부터 시작하지 않습니다 — 번호는
   `user_statements`의 순서를 따르고, 최초 요청이 없으면 첫 사용자 답변이 `S1`입니다.
   원문 보존은 **관례가 아니라 요구**입니다 — 게이트 15항 어디에도 이 요구가 없어서,
   보존되지 않은 인터뷰가 나와도 지금까지 아무것도 red가 되지 않았습니다.
   구조상 이 시점의 `confirmed`는 **항상 0건**이므로, frontmatter에 sentinel 한 줄
   (`# confirmed 0건 — 사용자가 전부 잠정으로 판단`)을 **반드시** 함께 씁니다 — 템플릿이
   `user_sourced_items:` 블록 첫 줄로 상속시키는 그 줄입니다. 이 줄이 sentinel로 인정되려면
   **한 줄 전체**가 그 문구여야 합니다(다른 문장 안에 인용된 같은 문자열은 무효). 없으면
   게이트가 "확인 게이트 우회 신호"로 red를 냅니다 — sentinel은 *확인을 건너뛴 brief*와
   *사용자가 전부 잠정으로 판단한 brief*를 가르는 유일한 표식이라 생략할 수 없습니다.
   확정 반영 시에는 B-3 「확정 반영 절차」대로 같은 write에서 이 줄을 지웁니다.
4. **Coverage Ledger 직렬화**(게이트 *전*): state의 `coverage`를 **audit §1**에 한 줄당 한
   차원으로 직렬화(floor 5행 + derived 또는 `- derived: N/A`). floor 전부 `closed`가 아니면
   이 시점에 도달하면 안 됩니다(종료 driver 위반). steelman 원문은 audit §3에
   `#### ST<N> — <한 줄 요지>` 헤딩과 함께 verbatim으로 남기고, payload §5의 `verdict:` 항목이
   그 `ST<N>`을 참조합니다 — 양방향 일치가 게이트 대상입니다.
5. **기계적 게이트 검증** — 직렬화 직후. payload 경로만 넘기면 게이트가 `audit_file`로
   audit을 해석합니다:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_brief.py" gate "docs/superpowers/interview/<file>"
   ```
   exit ≠ 0 이면 **brief를 finalize하지 말고** 보고된 미충족 항목을 보완(누락 섹션·무인용
   landscape·형식 미달 verdict 항목·`기각` 0건·floor open·bijection 불일치·**`confirmed`
   0건 sentinel 누락**). 통과(exit 0)할 때까지 반복합니다. 마지막 항목은 이 단계에서
   **매번** 발화할 수 있는 유일한 실패입니다 — Step A는 정의상 전부 `provisional`이므로,
   위 3의 sentinel을 빠뜨리면 첫 게이트 실행이 항상 red입니다.

### Step A.5 — brief 리뷰 파이프라인 진입 (Law 2 분리 리뷰, v0.24.0)

게이트(Step A 5)를 통과한 payload는 **Law 1 구조 자기검사**를 마친 것이고, 아직 **분리 리뷰**를
받지 않았습니다. 여기서 `reviewing-brief` skill로 넘깁니다 — 축은 둘(충실도·방향성), 담당은
셋 + codex이며, 절차는 그 skill이 소유합니다(여기에 복제하지 않습니다).

핸드오프 변수 3개를 그 skill과 같은 리졸버로 세팅합니다(state 배치 규약 정합, PN1):

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py" state-root)"
harness_sid="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py" session-id)"
PAYLOAD="docs/superpowers/interview/<file>"          # Step A가 방금 쓰고 검증한 경로
CODEX_DIR_YAML="$ROOT/$harness_sid/codex-direction.yaml"
CODEX_FID_YAML="$ROOT/$harness_sid/codex-fidelity.yaml"
```

```
Skill spec-distill:reviewing-brief $PAYLOAD $CODEX_DIR_YAML $CODEX_FID_YAML
```

세 인자는 **주석이 아니라 호출 라인 위에** 있어야 합니다 — `reviewing-brief`는 이 값들을 스스로 정의하지 않는다고 명시하므로, `#` 뒤에만 적혀 있으면 호출은 인자 없이 나가고 callee는 정의되지 않은 변수를 쥡니다.

- 그 skill이 `cost_class: high` 진입 승인 게이트를 띄웁니다(모델 호출 하한 5 · 상한 9).
- `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1`이면 파이프라인이 전체 skip되고 skip record가
  Step B 게이트 질문에 표시됩니다 — 조용한 생략이 아닙니다.
- 리뷰가 payload를 수정할 수 있습니다(§2 제약·§3 OQ 등). 수정이 일어나면 Step B는 **리뷰 후
  최종 문서**를 봅니다.
- 산출물 4종(확정 후보 / 방향성 C4 항목 / readback 요약 + gap / 모든 degrade record)이
  Step B 게이트로 넘어옵니다.

### Step B — proceed 게이트 (handoff 방식 제안)

brief는 **단독 완결 terminal 산출물**입니다(NG7 — handoff는 강제가 아니라 사용자 선택).
Step B는 단일 책임 단위입니다: *brief가 완결되면 다음 stage(brainstorming 해답공간) 진입
방식을 사용자에게 제안한다.* 입력 = 완결·`check_brief.py` 검증된 brief 경로 + superpowers
가용성.

**이 게이트의 공통 계약(순서 · 두 가드 · 예외 경로)은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 에 있습니다.**
`reviewing-spec` Phase 5 의 `/compact` proceed 게이트와 **같은 골격**이며, 두 벌을 독립 저술하던
것을 그 파일로 모았습니다 — 한쪽만 고치면 다른 쪽이 조용히 갈라지기 때문입니다. Step B 에
실제로 진입할 때 읽고 그대로 따릅니다. 아래에는 이 skill 의 **어휘**(확정 후보 제시 · 옵션 라벨 ·
verbatim `/compact` 템플릿 · superpowers 가용성 분기)만 남습니다.

```
Read ${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md
```

플러그인 레벨 경로입니다 — 이 파일 옆이 아니라 플러그인 루트 아래
(`plugins/spec-distill/references/proceed-gate.md`)에 있습니다. 두 skill 이 공유하므로 어느
skill 밑에도 두지 않았습니다.

#### B-0 — 확정 후보 제시 (게이트에 흡수, AC2)

Step A가 끝난 시점에 `user_sourced_items`는 **전부 `provisional`**입니다. `confirmed`로의
전이는 아래 B-2 게이트에서 사용자가 확정-후-진행 옵션(①/②)을 고를 때만 일어납니다.
별도 확인 의례를 만들지 않는 이유는 종료 시 사용자 상호작용이 2회가 되기 때문입니다 —
확인을 기존 proceed 게이트에 흡수해 1회로 유지합니다.

게이트를 띄우기 *전에* 확정 후보 목록을 **프로즈로** 출력합니다(목록이 길 수 있으므로
`AskUserQuestion`은 선택지만 담당):

- 각 후보를 `<id> — <statement> (source, ⟨S<N>⟩)` 한 줄로.
- **확정 후보에서 제외한 항목도** 한 줄씩 이유와 함께 보여줍니다 — 제외 항목을 감추면
  사용자가 누락을 잡을 수 없습니다.
- 모델의 후보 판정은 **제안일 뿐**입니다. 어떤 항목도 이 출력만으로 `confirmed`가 되지 않습니다.

**재제시 상한** (금지 패턴 *Unbounded autonomy* 가드): 최초 제시는 0회째입니다. 사용자가
옵션 ③(확정 목록 수정)을 고를 때마다 state의 `confirm_repost_count`를 +1 하고 **2회까지**
허용합니다. 3번째 ③ 요구 시 전 항목을 `provisional`로 강등하고 아래 **고정 문자열**을 출력한
뒤 게이트를 재제시하지 않고 **④와 동일한 terminal 경로로 종료합니다**(handoff 안 함 —
사용자가 ③을 골랐지 ①/②를 고른 적이 없으므로, 게이트 없이 brainstorming으로 자동 진행하는
것은 B-4의 P17/AP2 금지 대상이다). 종료 방향인 이유는 확정이 덜 되는 쪽이 안전한 방향이기
때문입니다:

```
[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등
```

카운터는 프로즈 self-tracking이 아니라 state에 씁니다(PN1 Bash write contract):

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py" state-root)"
STATE="$ROOT/<session-id>/state.local.md"
# confirm_repost_count read-modify-write via python3 -c / heredoc
```

#### B-1 — superpowers 가용성 분기

- **superpowers 부재 시**: 현행 graceful degradation 그대로 — brief를 완료하고 **loud advisory**를 낸 뒤 **정지(STOP)**. 게이트 없음(compact 후 넘길 대상 자체가 없음). crash·spec-mode fallback **금지**(단독 완결, graceful degrade):

  > `[spec-distill] interview brief 완결: docs/superpowers/interview/<file>. superpowers 설치 시 brainstorming 해답공간 단계로 이어집니다. 미설치 시 이 brief를 직접 다음 작업의 입력으로 사용하세요.`

- **superpowers 가용 시**: B-2 proceed 게이트 제시.

#### B-2 — 단일 `AskUserQuestion` proceed 게이트 (4옵션, AC2)

게이트 *이전*에 brief 경로 존재를 확인합니다(`[[ -f <brief-path> ]]` — race 방어 경량 가드,
`AskUserQuestion` 게이트 자체는 아님). 부재 시 정본(`proceed-gate.md`)의 `## Step A` 대로
`/compact`를 노출하지 *않고* loud advisory 후 STOP(brief 는 막 검증됐고 하류·SessionEnd 가 cleanup 을 맡는다 — 설계 §5.3):

> `[spec-distill] brief '<brief-path>' 부재 — 재작성/세션 리셋 필요`

(Step A의 작성 + `check_brief.py` 검증 직후라 정상 경로에선 발생하지 않습니다.)

brief 유효 시 **한 번의** `AskUserQuestion`으로 다음 단계를 제안합니다:

게이트를 띄우기 *전에* Step A.5 리뷰 산출물을 프로즈로 출력합니다(B-0 확정 후보 목록 다음):

1. **방향성 C4 항목** — `<출처(Claude|codex)> — <무엇을 뒤집자는 것인가> — <근거> — <결정할 질문>`.
2. **readback 요약 전문** + gap 목록(*어느 클래스 / 요약의 어느 문장 / payload의 어느 절*).
3. **미반영 findings** — 있으면 각각 이유와 함께. 저자가 임의로 기각한 것이 아니라 사용자 판정
   대상입니다.

**이 skill 의 degrade 채널** (정본 Step B 가 각 skill 에 이름을 대라고 요구하는 그것):
state 의 `brief_review_degradations` 원장 + `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1`
로 파이프라인이 통째로 skip된 경우의 skip record(A.5). `degrade 없음`은 **그 원장을 실제로
읽었다는 주장**이므로, 원장을 조회하지 않은 채 쓰지 않습니다.

그리고 `question` 텍스트에 **모든 degrade record를 한 줄씩** 싣습니다 — 옵션 description이
아니라 question 본문이어야 사용자가 옵션을 고르기 *전에* 봅니다. record가 없으면
`degrade 없음`을 한 줄로 명시합니다(침묵과 구분).

```javascript
AskUserQuestion({
  questions: [{
    question: "interview brief 완결: <brief-path> (구조 게이트 통과, 리뷰 <verdict 요약>). 확정 후보·방향성 항목·readback gap은 위 목록대로. degrade: <record 한 줄씩 | degrade 없음>. 다음 단계?",
    header: "Proceed",
    options: [
      {label: "확정하고 /compact 후 brainstorming (권장)", description: "확정 후보를 status: confirmed로 반영 → 재저장 → 게이트 재실행 → verbatim /compact 노출. 긴 인터뷰 context 정리 이점."},
      {label: "확정하고 바로 brainstorming", description: "확정 반영 후 즉시 Skill superpowers:brainstorming <brief-path> 호출 (compact 없이, 전체 context 유지)."},
      {label: "확정 목록 수정", description: "확정 후보를 고쳐 다시 제시 (상한 2회). 확정 전이 없음."},
      {label: "brief만 종료", description: "brief는 단독 완결 terminal (NG7). 전 항목 provisional 유지, handoff 안 함."}
    ],
    multiSelect: false
  }]
})
```

#### B-3 — 응답 처리

**규약의 거처 (C5).** `superpowers:brainstorming`은 spec-distill을 모르고 brief frontmatter를
읽지 않습니다 — 전달은 순수 프로즈 경로입니다. 그래서 C4 재결정 프로토콜은 brief 파일이
아니라 **orchestrator의 호출 프롬프트**에 싣습니다. brief는 순수 데이터(`source`/`status`/
`evidence`)만 나릅니다. 아래 ①과 ② **양쪽 모두** 같은 문장을 싣습니다.

**확정 반영 절차 (①/② 공통).** `provisional` → `confirmed` 전이와 함께, Step A가 confirmed
0건일 때 넣었던 sentinel 한 줄(`# confirmed 0건 — 사용자가 전부 잠정으로 판단`)이 남아 있으면
**같은 write에서 삭제**합니다. `check_brief.py`는 이 잔존을 잡지 못합니다 — confirmed가 한 건이라도
있으면 sentinel *요구*가 해제될 뿐 잔존을 거부하지는 않아, 지우지 않으면 confirmed 항목 옆에
"전부 잠정"이라 적힌 자기모순 brief가 그대로 나갑니다. 삭제까지 마친 뒤 재저장 → 게이트 재실행.

- **① 확정하고 /compact 후 brainstorming**: 확정 후보를 `status: confirmed`로 반영 →
  brief 재저장 → `check_brief.py gate` 재실행(통과 확인) → 아래 verbatim `/compact` 명령을
  *그대로 보이게* 노출 + "compact 후 brainstorming 진입 준비됨" 안내:

  > `/compact interview brief at <brief-path> 보존 — brief 본문(특히 §0 한눈에, §2 제약, §3 Open Questions, §6 사용자 원문), audit 파일 경로 참조, **그리고 아래 '재결정 규약' 문장**을 유지하고, round-by-round 인터뷰 대화·web sweep 원문·steelman 중간 추론은 drop. 재결정 규약: confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 다음 단계: Skill superpowers:brainstorming <brief-path>.`

  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것**(compact 전
  brainstorming 진입 = 옵션 ① 무력화). `Skill superpowers:brainstorming <brief-path>` 진입은
  사용자가 `/compact`를 *실제 실행한 다음 턴*에 **사용자 트리거**(예: `/compact write design`처럼
  compact 뒤에 붙인 진행 인자, 또는 명시적 진행 요청)로만 일어난다 — 모델은 다음 턴에 자동
  진입하지 *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17).

- **② 확정하고 바로 brainstorming**: 확정 반영 → 재저장 → 게이트 재실행 → 즉시
  `Skill superpowers:brainstorming <brief-path>` 호출하되, **호출 프롬프트에 C4 문장을 함께
  싣는다**:

  > `confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.`

  이것은 아래 cross-compact 정지 요건의 *명시적 예외*다.

- **③ 확정 목록 수정**: 확정 전이 없음. `confirm_repost_count` +1 후 B-0으로 돌아가 수정된
  목록을 재제시(상한 2회 — 초과 시 B-0의 강등 경로).

- **④ brief만 종료**: 전 항목 `provisional` 유지. brief terminal advisory(B-1 부재 advisory와
  같은 톤) 출력 후 종료. handoff 안 함. state는 SessionEnd hook이 cleanup.

#### B-4 — 두 가드 (load-bearing)

두 가드의 **전문은 `proceed-gate.md` 의 `## Step C`** 입니다(Step B 머리의 포인터).
여기 남는 것은 이 skill 의 어휘로만 성립하는 두 문장입니다:

- **AP2 polite-stop 금지**: ①/② 선택 후 "brief 완결!"만 narrate 하고 게이트 제시/`Skill
  superpowers:brainstorming` 호출을 skip 하는 것은 **polite stop** — 금지. Step B 를 *종료*하는
  모든 경로는 (a) 위 proceed 게이트를 거치거나(①/②/③/④), (b) 게이트를 거치지 않는 예외
  (superpowers 부재 — B-1)면 명시적 advisory 단락을 동반해야 한다 — 게이트-less **silent 종료
  금지**.
- **cross-compact 조기진행 금지**: 옵션 ① 의 정지 요건과 다음 턴 진입 조건은 B-3 ① 에 인라인으로
  있습니다(그것이 이 skill 의 실행형이자 기계적 검증 앵커입니다). 옵션 ② 는 그 정지 요건의
  *명시적 예외*(compact 없이 즉시 brainstorming)이며, B-3 ② 가 그렇게 적고 있습니다.

이 stage는 brief까지로 종료됩니다. handoff를 *강제하지 않습니다*(NG7).
