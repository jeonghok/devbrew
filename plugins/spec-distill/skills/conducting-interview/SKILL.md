---
name: conducting-interview
description: >
  Runs the spec-distill problem-space interview stage and produces a terminal
  interview-brief at docs/superpowers/interview/. 종료는 커버리지 원장의 floor
  5차원(root-problem/landscape/skepticism/blind-spot/open-questions)이 모두
  closed일 때이며, check_brief.py의 구조적 게이트로 기계적 검증합니다(Law 1).
  Optionally hands the brief to superpowers:brainstorming.
cost_class: variable
user-invocable: false
---

# Conducting Interview — 문제공간 Stage (Phase 1)

당신은 spec-distill의 인터뷰 stage를 진행 중입니다. 이 stage는 *받아적는* 인터뷰가
아니라 **강한 문제공간 stage**입니다(Double Diamond 1st diamond — brainstorming 해답공간
앞단, 상보적·비중복). 매 라운드를 «지금 이해 · 다음 결정 · 질문 하나»로 묻되, 종료는
**커버리지 원장의 floor 5차원**(root-problem/landscape/skepticism/blind-spot/open-questions)이
**모두 `closed`**일 때만 허용됩니다 — landscape·skepticism 등 통과 의례 메커니즘이 각 차원을
채우는 수단이며, `check_brief.py`가 이를 기계적으로 검증합니다(Law 1 구조 게이트).

산출물은 `spec.md`가 아니라 **interview brief**(brainstorming용 meta-prompt)이며, 이
brief는 **단독 완결 terminal 산출물**입니다 — superpowers가 있으면 brainstorming으로
넘기고(optional), 없으면 brief 자체로 완료합니다.

## State location

`.claude/spec-distill/<session-id>/state.local.md` (per-session 격리, devbrew §4.8 준수)

State frontmatter schema:

```yaml
---
session_id: <uuid>
phase: 1
coverage:                            # G1 커버리지 원장 (floor 5 + derived[]). 종료 driver.
  floor:
    root_problem:   {status: open, evidence: "", reopened: 0, reopen_log: []}
    landscape:      {status: open, evidence: "", reopened: 0, reopen_log: []}
    skepticism:     {status: open, evidence: "", reopened: 0, reopen_log: []}
    blind_spot:     {status: open, evidence: "", reopened: 0, reopen_log: []}
    open_questions: {status: open, evidence: "", reopened: 0, reopen_log: []}
  derived: []                        # 주제-도출 차원 ({name, rationale, status, evidence, reopened, reopen_log})
orchestration:                       # orchestrator 소유, agent read-only
  focused_dimension: null            # 현재 probe 대상 차원 이름 또는 null
  blind_spot_dispatches: 0           # 예산 = 1 + 그 차원의 reopened (자격은 아래 절)
  coverage_mapper_dispatches: 0      # 예산 = 1 + 모든 차원의 reopened 합 (자격은 아래 절)
  open_decisions:                    # 인터뷰 중 결정의 유일한 거처 — OQ<n> 의 산출자
    - id: OQ1
      text: "<한 줄>"
      dimension: blind_spot          # 어느 커버리지 차원에 속하는가 (호출 자격의 입력)
      status: open                   # open | resolved
      resolved_by: null              # resolved 면 그 사용자 발화 S<N>
      touched: false                 # 조사가 닿았는가 (C44 면제의 입력)
non_user_streak: <int>
trivia_escape_armed: false
user_statements: []                  # 매 round 끝 append. 판정 없음 — 확정은 종료 게이트가 결정.
confirm_repost_count: 0              # 종료 확정 확인 재제시 횟수 (상한 2, Unbounded-autonomy 가드)
---
```

State body: 각 라운드의 `## R<n>` 기록(«라운드 규약» 형식) + coverage-mapper 출력 transcript.

**`open_decisions[]` 의 생명주기.** 발급은 orchestrator 가 «다음 결정» 블록을 쓸 때 그 문장에
`OQ<n>` 을 붙이는 것이다(번호는 순증, 인터뷰 안에서만 유일). `status: open → resolved` 는 사용자
발화로만 바뀌고 **해결돼도 목록에서 지우지 않는다** — 조사가 결정을 해결하는 데 기여했으면 그것이
성공 사례인데 목록에서 빠지면 게이트의 실재 검사가 그 조사를 red 로 만든다. `touched` 는
`false → true` 단방향이고 재개방으로도 되돌리지 않는다(되돌리면 면제가 무한해진다). 종료 시
`status: open` 인 것이 payload §3 Open Questions 로, **전량**이 §0 결정 목록으로 직렬화된다 — §0 이
상위집합이고 §3 이 그 중 열린 것이다. `RC<n>` 은 별 state 키를 두지 않는다: V1 이 붙이고 audit §5 의
확인 줄이 곧 레지스터이며, 확인 줄 없는 `RC<n>` 은 게이트가 red 로 잡는다.

**Secret 기록 금지** (P21): 사용자 답변에 token/key/credential 패턴 감지 시 placeholder로 치환 후
기록합니다. **치환 토큰은 `<REDACTED>` 또는 `<REDACTED:라벨>` 형태**로 씁니다(다른 허용 형태:
`<SECRET:...>` · `<TOKEN:...>` · `<KEY:...>` · `<CREDENTIAL:...>` · `<PLACEHOLDER:...>`).
`check_verbatim_coverage.py`가 payload §6 ∪ audit §6 원문 대조에서 **이 토큰 집합**을 보고 L2를 advisory로 강등하므로,
다른 형태로 치환하면 정당한 치환이 red로 잡혀 사용자가 Step B에서 판정해야 합니다(fail-closed 방향).

### State write contract (PN1 — worktree-safe)

`state.local.md`는 `state_path.py`가 **main repo** `.claude/spec-distill/<sid>/`로 라우팅합니다
(`git rev-parse --git-common-dir`). 워크트리 세션에서 이 경로는 워크트리 *밖*이라 `Write`/`Edit`
tool이 차단됩니다 — state 갱신은 **반드시 Bash**로 하십시오:

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py" state-root)"
STATE="$ROOT/<session-id>/state.local.md"
# read-modify-write via python3 -c / heredoc (Edit tool 사용 금지 — main-repo 경로)
```

**brief는 예외**: `docs/superpowers/interview/`는 워크트리 *안*이라 `Write` tool로 정상 작성.

## 라운드 규약 — 지금 이해 · 다음 결정 · 질문 하나

사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다.

```markdown
## R<n>

### 지금 이해
<문제의 현재 재구성 — 바뀐 부분만 한두 문장. 코드·문서에서 확인한 사실(경로 a)과
 외부 근거(landscape·premortem)가 있으면 여기 싣는다. 재개방이면 «→ <차원> 재개방: <사유>»>

### 다음 결정
<무엇을 정하는지 한 줄> · 추천: <첫 선택지> · 트레이드오프: <선택지별 한 줄>

### 질문
<본문>

### 답
→ S<m>
```

- `## R<n>` 은 1부터 순증한다.
- 라운드마다 AskUserQuestion 1회, **질문 1개**다. 첫 선택지가 추천이고 그 라벨 끝에 `(권장)` 을 단다 —
  steelman 절차의 질문만 예외다(아래).
- question 본문은 무엇을 정하는지·용어·기술 사실을 풀고, 각 선택지의 `description` 은 «고르면 무엇이
  달라지는가»를 담는다. 기계 검사는 없다.
- **되묻기** — 직전 답이 보류(«모르겠다/둘 다/아무거나»)·한 단어·이유 없는 추천 수락·근거 없는 단정이면,
  그 라운드의 질문은 이유·사례·실패 조건 중 하나를 되묻고 인터뷰어의 추측을 첫 선택지로 둔다.
  같은 주제의 연속 되묻기는 최대 2회다 — 그 뒤에도 약한 답이면 답을 그대로 기록하고(보류는 «사용자 발화
  기록» 표대로 §3 Open Questions 로도 이월) 다음 질문으로 넘어간다. 그 차원을 자동으로 닫지 않는다.
- **한 라운드에 겹치면** 되묻기 → 외부 근거 처분(landscape·premortem 출력을 받아들일지) → 새 결정 순서로
  앞선 하나가 그 라운드의 질문이 되고, 나머지는 다음 라운드의 «다음 결정»으로 넘어간다. landscape·
  blind_spot 은 그 처분 S 로만 닫힌다.
- **steelman 절차의 질문** — `references/steelman.md` 가 사용자에게 묻는 질문은 전부 그 파일의 규약(선택지
  순서·라벨·추천 표기·시점)을 따르고 각각 `## R<n>` 한 라운드로 기록한다. 이 절의 질문 수·`(권장)` 표기·
  «추천: <첫 선택지>»·겹침 순서는 그 질문들에 적용하지 않으며, steelman 절차가 진행 중이면 그 질문이 겹침
  순서보다 앞선다.
- **인자 없이 `/interview` 를 부른 경로의 R1** 은 seed 도 직전 답도 없으므로 «지금 이해»를 «아직 없음»으로
  두고 질문으로 무엇을 다룰지 묻는다. coverage-mapper 첫 dispatch 시점은 아래 coverage-mapper 절이 정한다.
- 답은 `user_statements` 에 `S<m>` 하나로 append 한다(선택지 = `chosen`, «기타» 자유 입력 = `verbatim`).
  번호 공식은 «사용자 발화 기록» 절 그대로.
- **V1 검문소 — 조사 주장을 «지금 이해»에 싣기 전에.** 계약(`## 조사 주장 계약`)이 산출한
  `repo_claims[]` 항목마다 orchestrator 가 자기 `Read`/`Grep` 으로 ① 경로 실재 → ② 앵커 실재 →
  ③ **주장이 그 자리와 맞는가**(구현을 읽는다 — 인덱스·목차·description 필드만 읽고 판정하지
  않는다) 를 확인하고 ④ 결과를 {확인, 반증, 미확인} 중 하나로 정한 뒤 ⑤ `id: RC<n>` 을 붙여 audit
  `## 5. 프로세스 로그` 에 한 줄로 적는다: `- 확인 RC3 — 확인 — <경로>#<앵커> — 주장과 일치` /
  `- 확인 RC4 — 반증 — <경로>#<앵커> — 그 자리는 <실제>이고 주장은 <주장>이었다` /
  `- 확인 RC5 — 미확인 — <경로>#<앵커> — <왜 확정하지 못했는가>`. `미확인` 은 라벨로 **보인다** —
  조용히 흡수하지 않는다. 이 검문소는 **steelman trigger 와 DEVBREW_SPEC_DISTILL_DISABLE_WEB 어느
  것에도 종속되지 않는다.** steelman 경로는 `references/steelman.md` Step 2 가 V1 의 특수 경우이므로
  두 번 확인하지 않고, 판정만 audit §3 `ST<N>` 과 §5 양쪽에 적는다. 판정이 `반증` 이면 그 항목이
  닿는 확정을 payload §5 에 *원래 / 재결정 / 근거* 세 칸으로 남기고(재결정 자체는 사용자 동의로만
  한다 — P23), 그 차원을 재개방할 수 있다.
- **결정 연결은 §4·§5 에 달고 §3·§0 이 그것을 되가리킨다.** 조사 항목 줄 끝에 레포 `[RC3 → OQ1]` ·
  `[RC3 → 없음]`, 웹 `[→ OQ1]` · `[→ 없음]` 중 하나를 쓴다 — 레포 주장은 연결 안에 항상 `RC<n>` 을
  싣는다(`없음` = 닿는 결정 없음). 하위 불릿은 쓰지 않는다 — 게이트가 들여쓴 불릿도 §4 항목으로 세므로
  즉시 red 다. **§3 은 연결의 대상이고 출처가 아니다** — §3 항목은 그 자체가 열린 결정이라 거기에 연결을 걸면 자기지시가 된다.

## 조사 주장 계약

조사 주장(외부 `evidence[]` · 내부 `repo_claims[]`)의 계약 정본은
`${CLAUDE_PLUGIN_ROOT}/references/research-claims.md` 다. 이 절은 그 파일을 dispatch 로
**배달**하는 책임만 진다 — 계약 본문을 여기 복사하지 않는다.

`${CLAIMS_CONTRACT}` 에는 경로가 아니라 **계약 파일의 내용**을 싣는다 — 플러그인 캐시는 사용자
프로젝트 밖이라 subagent 의 Read 가 거부된다. dispatch 직전(재dispatch 포함)에 아래 펜스를 돌려
그 stdout 전문을 세 dispatch 의 `<claims_contract>` 슬롯에 싣는다. rc 가 0 이 아니면 **그 장치를
dispatch 하지 않는다** — 인터뷰는 계속하되 그 차원을 자동으로 닫지 않고, 공시는 loud advisory +
audit §2 unavailable 사유 다.

<!-- claims-contract:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
# 경로는 `${CLAUDE_PLUGIN_ROOT}` 형태로 쓴다 — 포인터 락이 해석하는 형태는 셋뿐이고
# `$SD/references/…` 는 그 셋에 없어 거부된다(조용히 재해석하지 않는다).
CLAIMS="${CLAUDE_PLUGIN_ROOT}/references/research-claims.md"
claims_rc=0; CLAIMS_CONTRACT="$(cat "$CLAIMS")" || claims_rc=$?
if [ "$claims_rc" -ne 0 ] || [ -z "$CLAIMS_CONTRACT" ]; then
  echo "[spec-distill] 조사 주장 계약을 읽지 못했다(cat rc $claims_rc): $CLAIMS — 이 장치를 dispatch 하지 않는다. 인터뷰는 계속하고, 그 차원을 자동으로 닫지 않는다. coverage-mapper 자리면 audit §2 Budget 에 coverage-mapper 0 (unavailable: 계약 배달 실패) 를 적고, blind-spot-prober 자리면 inline premortem 으로 강등한다." >&2
  exit 1
fi
printf '%s\n' "$CLAIMS_CONTRACT"
```
<!-- claims-contract:end -->

## C43 3-path routing

질문을 만들 때 다음 3 경로 중 하나로 분류해서 routing 하십시오:

| Path | When | Action |
|---|---|---|
| (a) **factual / landscape** | 답이 codebase/git history *또는 외부 prior-art*에 있는 경우 | codebase 는 **orchestrator 가 자기 `Read`/`Grep` 으로 직접 확인하고 subagent 를 부르지 않는다** — 산출은 계약(`## 조사 주장 계약`)의 `repo_claims[]` 이고 라운드 규약의 V1 을 탄다. 웹 스위치와 무관해서 **내부 축의 주 생산자**다. 외부는 web sweep(아래 R2), 표기 `[from-web]`. streak 은 C44 의 면제 규칙이 정한다. |
| (b) **judgment** | 사용자 선호/우선순위/제약 | 사용자에게 묻기 (default path). |
| (d) **ontological** | "이게 무엇인가" 종류 (essence/root cause 등) | essence/root cause 류 — 라벨 강제 없음. 사용자에게 묻기. |

매 라운드의 «지금 이해»·«질문» 에 어떤 path 인지 명시하십시오 — 경로 (a) 로 찾을 수 있는 것은 묻기 전에
먼저 찾아 «지금 이해»에 싣습니다.

**경로 (a) 가 `repo_claims[]` 를 처음 산출하면 그 자리에서 derived 차원 internal_research 를 원장에
admit 한다**(coverage-mapper 제안과 무관 — 조사 행위가 그 차원을 함의한다). 이름은 그 글자대로 쓴다:
게이트가 **정확 일치**로 재고 `internal_research_apparatus` 같은 유사 이름으로는 만족되지 않는다.
그 차원은 **레포 주장의 처분 S** 로 닫고 evidence 에 그 S 를 인용한다 — 종료 시점엔 늦다(닫힘 규칙).

## 사용자 발화 기록 (G1, AC1)

매 round 끝에 사용자가 실제로 답한 것을 `user_statements`에 append합니다. **여기서 무엇도
판정하지 않습니다** — 이 stage는 문제공간이고, 무엇이 확정인지는 종료 직전 사용자 일괄
확인(Step B-0)이 결정합니다.

| 사용자 응답 유형 | path | 기록? | `source` |
|---|---|---|---|
| 자유 텍스트 응답 (수락·거절·요구 무관) | b, d | ✅ | `verbatim` |
| 선택지 선택 | b, d | ✅ | `chosen` |
| 보류 ("잘 모르겠음", "둘 다 괜찮음") | b, d | ✅ — §3 Open Questions로도 이월 | `verbatim` |
| factual auto-confirm | a | ❌ (사용자 발화 아님) | — |

```yaml
- id: S<N>                 # N = user_statements.length + 1 + (최초 요청 원문 있으면 1, 없으면 0 — finishing.md S1 예약과 합의)
  source: verbatim         # verbatim(발화 그대로) | chosen(고른 선택지 라벨 + 요지)
  round: <int>
  text: "<사용자가 실제로 한 말>"    # P21 secret placeholder 치환 적용
```

`status` 필드는 없습니다. `section:` 해답공간 앵커도 없습니다 — 문제공간의 답변을 답이
들어갈 슬롯에 미리 바인딩하면 다음 stage의 탐색이 그 슬롯 모양대로 갇힙니다.

거절도 수락과 똑같이 **발화 그대로** 기록합니다. 반대 명제로 뒤집어 "잠긴 방향"으로
승격시키지 않습니다 — 그 승격이 라운드마다 결정을 박제하던 경로였습니다.

## C44 Dialectic Rhythm Guard

`non_user_streak` 카운터 — 직전 N probe 동안 *사용자 답변이 없었던* 횟수.

- (a) factual auto-confirm: streak +1
- (b) 사용자 답변 받음: streak = 0
- (d) ontological 사용자 답변 받음: streak = 0
- (a) web auto-research: streak +1 (과도하면 강제 (b)로 사용자를 loop에 유지 — AP16).

`non_user_streak >= DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` (default 3) 도달 시:

→ 다음 probe의 질문은 **반드시 (b) judgment path** (사용자에게 직접 질문)로 라우팅. 강제.

**조사 산출의 면제.** 조사가 결정에 닿았으면 그 probe 는 streak 을 올리지 않는다 — 압착의 대가를
가드의 계수 방식에서 지불하되, 면제 예산이 유한하도록 집합 원소에 묶는다. 산출자는 orchestrator
이고 거처는 `orchestration.open_decisions[]` 의 `touched` 필드다(별 키를 두지 않는다).

> 산출 항목의 `decides` 가 status: open 이고 touched: false 인 결정을 하나라도 담으면
> `non_user_streak` **+0**. 그렇지 않으면 **+1**. 그 계수 **뒤에** 그 원소들의 `touched` 를 `true` 로
> 올린다. **열린 결정이 0이면 면제도 0이다.**

**순서가 계약이다 — 「계수 먼저, 표시 나중」.** 표시가 계수보다 앞서면 계수 시점에 「아직 안 닿은
것」이 항상 공집합이라 **첫 연결부터 +1** 이 되고 면제가 영구히 발화하지 않는다.

`touched` 는 단방향이고 재개방으로도 되돌리지 않는다 — 되돌리면 면제가 무한해진다. 그래서 면제
예산은 `|{status: open, touched: false}|` 로 유한하고, **그 집합이 줄어드는 데 의존하지 않는다**:
줄지 않아도 같은 결정의 두 번째 연결이 면제되지 않으므로 예산이 고갈된다.

## coverage-mapper dispatch (자격 + 예산)

`coverage-mapper` 는 고정 floor 위 **주제-도출 차원**을 *제안*하는 advisory 에이전트다(admit 은
orchestrator, G2). 첫 dispatch 는 필수이고 그 뒤는 자격과 예산이 정한다:

1. **R1 첫 질문 전 필수 1회.** 입력: seed 전문(S1)과 그 «다시 검증할 것» 문단, 원장 초기 상태.
   출력의 derived 차원을 admit 한 뒤에야 R1 질문이 나간다. 인자 없이 부른 경로에서는 R1 답을
   받은 뒤 R2 전에.
2. **재개방마다 한 번의 예산이 열린다.** 재개방이 새 파생 차원을 함의할 수 있어서다 — 그래서
   예산이 `1 + 재개방 합` 이다. 자격이 없으면 예산이 남아도 부르지 않는다.

**호출 자격이 예산보다 앞선다.** 다시 부를 자격은 「그 장치가 채우는 차원에 **닿는 열린 결정이
아직 있는가**」다 — `orchestration.open_decisions[]` 에서 `dimension` 이 그 차원이고 `status: open`
인 항목이 하나라도 있는가. **열린 결정이 0이면 자격이 없다 — 예산이 남아도 부르지 않는다.**
자격을 채웠으면 예산을 본다: `coverage_mapper_dispatches < 1 + Σ(모든 차원의 reopened)`.
재개방이 연료다 — 재개방은 정의상 「새 답·외부 근거·코드 사실이 그 차원의 닫힘 근거 S 와 충돌」해야
일어나고 라운드는 사용자 답으로만 도므로 사용자가 시계다.

카운터 `orchestration.coverage_mapper_dispatches`. 종료 시 audit §2 에 `coverage-mapper <k>`
를 쓰고 게이트가 k≥1 을 검사한다. dispatch 가 불가능한 환경(Agent 도구 부재)은
`coverage-mapper 0 (unavailable: <이유>)` 로 적는다 — 게이트는 advisory 로 통과시키고 Step B 가
사람에게 보인다(침묵과 0 은 다르다).

**Web kill switch (dispatch 직전 확인 — 이 블록에 종속)**: `coverage-mapper`는
`WebSearch`/`WebFetch`를 보유한다. kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`이면
dispatch 프롬프트에 `web_disabled: true`를 실어 **codebase 근거만으로 차원을 제안**하게 하고,
loud advisory를 남긴다: `[spec-distill] web 비활성 — coverage-mapper가 codebase 근거만 사용`.
이 확인은 R2의 landscape 확인과 **별개로** 여기 있어야 한다 — kill switch는 보안 컨트롤이고,
egress를 가진 dispatch가 하나라도 게이트 밖에 있으면 스위치는 꺼졌다고 *믿게만* 만든다.
`coverage-mapper`는 `tools:`에 `Bash`가 없어 스스로 확인할 수 없다(Law 2) — orchestrator가
유일한 집행 지점이다.

```bash
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  web_disabled=true
  echo "[spec-distill] web 비활성 — coverage-mapper가 codebase 근거만 사용" >&2
else
  web_disabled=false
fi
```

```
Agent({ description: "Map coverage dimensions", subagent_type: "spec-distill:coverage-mapper",
        prompt: "seed 원문 전량(§6 S1 이 될 값 그대로): <seed>${SEED_TEXT}</seed>. seed 의 «다시 검증할 것 —» 문단(Phase 0 이 추론·외부·열린 것으로 아는 항목. 규약 위반 seed 면 빈 값): <reverify>${SEED_REVERIFY}</reverify>. coverage 원장 상태(열린/닫힌 차원 요약 · focused_dimension · 재개방이면 reopen_log 마지막 항목): <ledger_state>${LEDGER_STATE}</ledger_state>. web_disabled(true면 WebSearch/WebFetch 사용 금지, codebase 근거만): <web_disabled>${WEB_DISABLED}</web_disabled>. 조사 주장 계약(내용 전문): <claims_contract>${CLAIMS_CONTRACT}</claims_contract>. 지금 열린 결정: <open_decisions>${OPEN_DECISIONS}</open_decisions>. 이 주제가 요구하는 derived 차원과 neglect를 제안." })
// **처분** — consumer=orchestrator · fail-closed · disclosure=loud advisory + audit §2 unavailable 사유
```

출력(`derived_dimensions[] + neglect_flag` + `evidence[]`/`repo_claims[]`)은 **advisory** —
orchestrator가 원장에 admit할지 판정한다. `neglect_flag: true`면 다음 probe에서 neglected 차원
하나를 추천 답안으로 제시. 복수 dispatch 시 name 기준 union·dedup. 주장은 «지금 이해»에 싣기 전에
라운드 규약의 V1 을 탄다.

**계약 배달 실패 시** — `## 조사 주장 계약` 펜스의 rc 가 0 이 아니면 이 dispatch 를 하지 않는다.
인터뷰는 계속하고, 그 차원을 자동으로 닫지 않으며, 공시는 loud advisory + audit §2 unavailable 사유
다: audit §2 Budget 의 불릿 줄에 `coverage-mapper 0 (unavailable: 계약 배달 실패)` 를 적는다 —
게이트가 advisory 로 통과시키고 Step B 가 사람에게 보인다.

**첫 dispatch 의 검증 의무(D6)** — seed 의 «다시 검증할 것» 문단 중 **레포로 확인 가능한 항목마다**
`repo_claims` 를 산출해 V1 을 태운다. 「사용자만 답할 수 있는 것」과 「인과 추정」은 대상이 아니다.
그 문단이 비어 있으면(규약 위반 seed — 위 슬롯 주석이 명시 허용) 이 의무는 미발동이고, 그 사실을
audit §5 에 한 줄로 공시한다. Phase 0 은 건드리지 않는다 — 의무는 받는 쪽에 있다.

## 닫힘 · 재개방

**차원은 그 차원에 관한 질문에 사용자가 답한 S 를 근거로만 닫는다**(floor · derived 모두).
sweep·steelman·prober 의 **횟수**는 닫힘 근거가 아니다 — landscape·premortem 출력은 «지금 이해»에 실려,
steelman 출력은 자기 게이트 제시 형식(`references/steelman.md` Step 3)으로 사용자 처분 S 를 받은 뒤 닫힌다.
원장 행의 evidence 는 그 S 를 인용하고, `check_brief.py`가 앵커 실재를 검사한다(«어느 S 가 닫힘을
정당화하는가»는 보지 않는다 — 그 한계는 spec OQ6).
다섯 floor 의 닫힘 발화: root_problem = 재구성 동의 S · landscape = 외부 근거 처분 S ·
skepticism = steelman 판정 S · blind_spot = 숨은 가정·실패 양식 처분 S · open_questions = OQ 목록
확인 S.

**재개방 — `closed → open` 을 허용한다.** 조건: 새 답·외부 근거·코드 사실이 그 차원의 닫힘 근거 S 와
충돌할 때(판단은 orchestrator). 기록: 그 차원의 `reopened` +1, `reopen_log` 에
`{round, reason, conflicts_with: S<N>}` append, 그 라운드의 «지금 이해»에 «→ <차원> 재개방: <사유>».
상한 없음 — 라운드는 사용자 답으로만 돌아 사용자가 시계다. 재개방된 차원이 다시 닫힐 때는 **새 S** 를
인용한다(게이트는 최신 닫힘의 evidence 를 본다).

## blind-spot-prober dispatch (C8 — blind_spot floor 차원)

`blind_spot` floor 차원의 **첫 open→in-progress 전이** 시 `blind-spot-prober`를 dispatch 한다.
**자격이 예산보다 앞선다** — `orchestration.open_decisions[]` 에 `dimension: blind_spot` 이고
`status: open` 인 항목, 즉 그 차원에 **닿는 열린 결정이 아직 있는가**를 먼저 본다. 열린 결정이
0이면 자격이 없다 — 예산이 남아도 부르지 않는다. 자격을 채웠으면 예산:
`blind_spot_dispatches < 1 + coverage.floor.blind_spot.reopened`. dispatch 마다 카운터를 +1 한다.
kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 web 도구
부재면 dispatch 대신 loud advisory 후 **inline premortem**으로 전환한다(C5, §5 위험 항목을
codebase 근거·사용자 판단으로 기록).

```
Agent({ description: "Adversarial premortem", subagent_type: "spec-distill:blind-spot-prober",
        prompt: "지금까지의 framing(재구성된 문제정의 + 사용자 제약 요지): <framing>${FRAMING}</framing>. 조사 주장 계약(내용 전문): <claims_contract>${CLAIMS_CONTRACT}</claims_contract>. 지금 열린 결정: <open_decisions>${OPEN_DECISIONS}</open_decisions>. 이 framing의 hidden assumption과 failure mode를 웹근거와 함께." })
// **처분** — consumer=orchestrator · fail-closed · disclosure=loud advisory + inline premortem 강등
```

출력(`hidden_assumptions[] + failure_modes[]`)을 orchestrator가 payload §5 `## 5. 기각 · Blind Spots`의
**`위험` 항목**(`- 위험 — <숨은 가정 | 실패 양식>: <내용> — <근거>`)으로 기록하고, 다음 라운드의
«지금 이해»에 실어 사용자 처분 S 를 받은 뒤 `blind_spot` floor 차원을 closed 로 전이한다. web 비활성 시 advisory:
`[spec-distill] web 비활성 — blind-spot-prober 자동 생략, inline premortem으로 전환`.

**계약 배달 실패 시** — `## 조사 주장 계약` 펜스의 rc 가 0 이 아니면 이 dispatch 를 하지 않는다.
공시는 loud advisory + inline premortem 강등 이고, web 비활성 경로와 같은 곳으로 간다. 인터뷰는
계속하고 그 차원을 자동으로 닫지 않는다.

**강등된 inline premortem 도 같은 계약을 쓴다** — orchestrator 가 자기 `Read`/`Grep` 으로 레포
근거를 확인하고 `repo_claims` 를 산출해 V1 을 태운다. 웹 근거만 사라지고 내부 축은 돈다.

## 5 통과 의례 (Law 1 구조 게이트, R1–R5)

brief 작성(+ optional brainstorming invoke)은 다음 5 의례를 **모두 통과**해야 허용됩니다.
하나라도 미충족이면 종료 차단. 종료 직전 `check_brief.py gate`로 **기계적 검증**:

| # | 의례 | 통과 기준 | 메커니즘 |
|---|---|---|---|
| R1 | **Problem Reframe** | seed 가 가리키는 **작업 뒤의 진짜 문제**를 재구성한 한 문장 문제정의 + 진짜 goal. seed 의 문장을 되풀이하는 것은 통과가 아니다. | (d) ontological → payload §0 · §1 |
| R2 | **Landscape 수집** | web sweep ≥1회, prior-art/대안이 **인용과 함께** 표면화. | path(a) 확장 → payload §4 External Landscape |
| R3 | **Skepticism 통과** | 의심 triggered 방향이 모두 steelman 후 *유지 / 보완 / 전환 / 보류* 중 하나로 판정. un-challenged 의심 방향은 확정 후보가 될 수 없다. trigger 0건이면 `- 검토 — steelman 0건: …` 한 줄 명시(빈 섹션 금지). | steelman-builder dispatch → payload §5의 **`verdict:` 항목** |
| R4 | **시행착오 기록** | steelman switch된 방향 **또는** 사용자가 명시적으로 폐기한 방향이 *이유와 함께* 기록. 0건이면 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄 명시(빈 섹션 금지). | payload §5의 **`기각` 항목** |
| R5 | **Open Questions 박제** | 미해결 명시("유추 금지"). | payload §3 Open Questions |

### R2 — 웹 Landscape

**탐색 경계** — `request-framing` 은 **레포는 읽되 웹은 보지 않는다.** framing 의 공백은
사용자에게 물어서 메운다. 바깥에서 찾는 것은 이 단계(interview)의 R&R 이다 — landscape ·
steelman · blind-spot premortem · coverage-mapper 넷이 전부 그 장치다.

**질문 라우팅** — 답을 사용자만 알 수 있으면 framing, 사용자 밖에서 찾아야 하면 interview.
같은 주제도 이 기준으로 갈린다.

토픽이 잡히면(round 1–2) landscape sweep을 수행합니다. 각 web 검색 *직전에* kill switch를
재평가합니다(세션 시작 시 캐시 금지).

- 모든 외부 주장은 **출처 URL 필수** — payload §4 External Landscape에 `[취함|피함|중립]` + 이유와 함께.
- kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 web 도구 부재 → **loud** 생략(crash 금지):
  `[spec-distill] web 비활성 — landscape 생략, codebase 근거만 사용`.

### R3 — Steelman 의심 게이트 (P17)

의심 trigger = landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌. 절차 전문(전제 도출 ·
`steelman-builder` dispatch · 게이트-전 확인 · 게이트 제시 블록 · 유지/보완/전환/보류 게이트 · 기록 · steelman 0건의
`검토 —` 항목 · web 비활성 시 steelman 자동 생략)은 `references/steelman.md` 다 — R3 에 들어갈 때 그 파일을 Read 한다.
builder 출력은 verbatim 으로 다룬다(약화·편집 금지). 보류는 §3 OQ 에도 박제한다.

## seed 를 입력으로 받았을 때

**이 절 전문은 `references/seed-input.md` 에 있다** — `$ARGUMENTS` 가 `type: interview-seed` frontmatter
를 가진 문서일 때만 읽는다(조건부 로드 — seed 없는 호출이 더 흔해 finishing.md 보다 조건성이 강하다).

```
Read ${CLAUDE_PLUGIN_ROOT}/skills/conducting-interview/references/seed-input.md
```

그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.

## 종료 — brief 작성 + optional handoff

**종료 절차 전문은 `references/finishing.md` 에 있다.** floor 5차원이 전부 `closed` 가 되어
brief 작성으로 넘어갈 때 그 파일을 Read 로 읽어 그대로 따른다. 인터뷰가 아직 진행 중일 때는
읽지 않는다 — 이 분리의 목적이 그것이다(조건부 로드).

### 나가는 문은 floor 뒤에만 있지 않다

floor 다섯이 전부 `closed` 여야 종료가 열리지만, **사용자는 언제든 종료를 요청할 수 있다.**
그때 미충족 floor 는 **사용자-승인 박제**로 닫는다 — 그 차원의 `evidence` 에
`사용자-승인 박제(@사용자 종료 요청) — §Open Questions 참조` 를 적고, 그 내용을 payload
§3 Open Questions 로 이월한다. 박제 표식이 원장에 남으므로 silent bypass 가 아니다.

발동 조건이 카운터가 아니라 **사용자 발화**라는 점만 예전 escalation 과 다르다. 상한을
없애는 것과 탈출구를 없애는 것은 다르다 — 없애는 것은 사용자 질문의 상한이지 나가는 문이
아니다.

읽어야 하는 조건: `coverage.floor` 의 다섯 차원이 모두 `status: closed`.

```
Read ${CLAUDE_PLUGIN_ROOT}/skills/conducting-interview/references/finishing.md
```

그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.

아래 migration 포인터는 이 SKILL.md 파일 기준 상대경로다 — 레포·설치본 두 레이아웃 모두 이 SKILL.md와 같은 위치에 `references/`가 있어 그대로 resolve 된다.

## In-flight state migration

**이 절 전문은 `references/state-migration.md` 에 있다** — state.local.md 로드 시 §2.4 스키마의
**어떤 키든 부재**를 감지했을 때 읽는다(조건부 로드). `coverage`/`orchestration` 이 통째로 없을
때로 좁히면 **직전 릴리스 세션이 어느 조건에도 안 걸린다** — 그 세션은 두 구조를 이미 갖고
`reopened`·`reopen_log`·`coverage_mapper_dispatches` 만 없기 때문이다. 실제 업그레이드 경로가
바로 그것이므로, 조건은 「구조가 없는가」가 아니라 「**부재 키가 있는가**」다(spec §2.4).

```
Read references/state-migration.md
```

## kill switch

- `DEVBREW_SPEC_DISTILL_DISABLE=1`: 즉시 abort, state.local.md 보존 (실패 분석용).
- `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD=N`: rhythm guard threshold override.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`: web landscape(R2) 비활성 — loud advisory 후 codebase 근거만 사용.
