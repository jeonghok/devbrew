---
type: design
topic: interview→brainstorming /compact proceed gate
plugin: spec-distill
target_version: 0.13.0
date: 2026-06-04
status: approved-design
related:
  - plugins/spec-distill/skills/conducting-interview/SKILL.md   # 변경 대상 (Step B)
  - plugins/spec-distill/skills/reviewing-spec/SKILL.md          # 미러링 모델 (Phase 5)
---

# interview → brainstorming `/compact` proceed 게이트 (spec-distill v0.13.0)

> conducting-interview의 brainstorming 핸드오프를, reviewing-spec Phase 5의
> `/compact 후 writing-plans` 게이트와 **대칭**으로 만든다 — 긴 인터뷰 context를
> 해답공간 진입 전에 정리할 수 있게.

## 1. Context / Why

spec-distill에는 두 개의 stage-간 핸드오프가 있다:

1. **interview → brainstorming** — `conducting-interview` Step B. brief(`docs/superpowers/interview/`)
   를 산출한 뒤 `superpowers:brainstorming`으로 넘긴다.
2. **(brainstorming → reviewing-spec →) spec → writing-plans** — `reviewing-spec` Phase 5.
   design doc approve 후 writing-plans로 넘긴다.

(2)는 v0.11.0에서 **단일 `AskUserQuestion` proceed 게이트**로 재설계되어, 사용자가
`/compact 후 writing-plans`(권장) / `바로 writing-plans` / `수정` / `멈춤` 중 선택한다.
`/compact` 옵션은 긴 인터뷰·리뷰 context를 plan 작성 *전에* 정리하는 context 위생 이점을 준다.
이 게이트는 두 가드로 보호된다: **AP2 polite-stop 금지**(approve 후 narrate만 하고 종료
금지)와 **cross-compact 조기진행 금지(AC19)**(`/compact` 노출 직후 같은 턴에 writing-plans로
직진 금지 — 그러면 compact가 무거운 plan-write *뒤에* 와서 이점 소멸).

반면 (1)은 **자동·직진 invoke**다 — superpowers가 있으면 같은 턴에 `superpowers:brainstorming`을
호출하고, 없으면 brief 완료 + advisory. `/compact` 단계도, 게이트도 없다.

**문제**: 인터뷰 stage는 여러 round의 4-block 대화 + web sweep 원문 + steelman 중간산출로
context가 길게 쌓인다. brainstorming(해답공간 설계)은 brief 파일만 읽으면 충분하므로, (2)와
**동일한 context 위생 이점**이 (1)에도 적용된다. 그런데 현재는 그 기회가 없다 — 전체 인터뷰
transcript를 그대로 끌고 brainstorming에 진입한다.

**진짜 goal (R1 reframe)**: 두 핸드오프의 **비대칭을 해소**한다. interview→brainstorming
핸드오프도 `/compact`를 *제안*해서, 사용자가 원하면 brief만 남기고 compact한 fresh context에서
해답공간 설계를 시작할 수 있게 한다.

## 2. Goals

- conducting-interview Step B를 **3옵션 `AskUserQuestion` proceed 게이트**로 재작성:
  ① `/compact 후 brainstorming`(권장) / ② `바로 brainstorming` / ③ `brief만 종료`.
- reviewing-spec Phase 5의 두 가드를 **대칭 이식**: AP2 polite-stop 금지 + cross-compact
  조기진행 금지(verifiable 2-layer).
- superpowers 부재 시 graceful degradation(AC13)을 **그대로 보존** — 게이트 없이 brief
  terminal + advisory.
- NG7(handoff 비강제)을 ③ 옵션으로 **가시화**.

## 3. Non-goals

- reviewing-spec Phase 5 자체 변경 (이미 v0.11.0에서 완성). 본 작업은 interview 쪽만 건드린다.
- `/compact` 게이트 계약의 공유 reference 문서 추출 (§7 Rejected Alternatives B 참조 — lightness로 기각).
- `approve_handoff.sh` 같은 finalizer 스크립트를 interview 쪽에 신설 (§5.3 참조 — 불필요).
- brainstorming(superpowers, 외부 플러그인) 내부 동작 변경.
- conducting-interview의 5 통과 의례(R1–R5) / web budget / steelman 로직 변경.

## 4. Constraints

- **devbrew Law 1–3 + Plugin Shape 상속** (CLAUDE.md). 특히: plugin.json SemVer bump,
  CHANGELOG, README "Principles Instantiated".
- **lightness 우선** (designs default to lightness) — 새 P# 추가 금지, 기존 패턴(AP2/AC19) 흡수.
- **skill self-contained** (progressive disclosure) — Step B 독자가 포인터를 추적하지 않고
  핸드오프 전체를 읽을 수 있어야 함.
- **모델은 `/compact`를 스스로 실행 불가** — 오직 사용자만. 따라서 ① 경로는 본질적으로
  멈춰서 사용자를 기다리는 게이트일 수밖에 없음.
- **state-write via Bash** (PN1) — 단, 본 변경은 새 state 필드를 도입하지 않으므로 해당 없음.

## 5. Design

### 5.1 접근법 (선택: A — 병렬 독립 미러)

| 안 | 내용 | 판정 |
|---|---|---|
| **A. 병렬 독립 미러** | Step B를 자체 완결 3옵션 게이트로 재작성. Phase 5와 구조 평행이되 interview 어휘(brief 보존, brainstorming=다음 stage)로 독립 저술. 상호 cross-reference 한 줄 + 테스트가 가드 문구를 mechanically assert. | **선택** — self-contained + lightness. drift는 cross-ref + 테스트로 봉쇄(Law 3). |
| B. 공유 추출 | `/compact` 게이트 계약을 공유 문서로 빼고 양쪽 참조. | 기각 — 2 call-site에 indirection 과투자, skill self-contained 관례 위배 (§7). |
| C. 최소 inline 증강 | Step B prose 유지, 게이트 문장만 삽입. | 기각 — Phase 5의 2-layer verifiable 가드를 허술 포팅하면 rigor 손실. |

### 5.2 Step B 재작성 (컴포넌트 = conducting-interview/SKILL.md "Step B" 섹션 하나)

핸드오프는 단일 책임 단위다: *brief가 완결되면 다음 stage 진입 방식을 사용자에게 제안한다.*
입력 = 완결·게이트검증된 brief 경로 + superpowers 가용성. 출력 = 게이트 제시(또는 부재
advisory)와 그 응답에 따른 분기.

**B-1 — superpowers 가용성 분기 (AC13 보존)**
- 부재 시: 현행 graceful degradation 그대로 — brief terminal + loud advisory + STOP. **게이트
  없음**(compact 후 넘길 대상 자체가 없음). 기존 advisory 문구 유지.
- 가용 시: B-2 게이트 제시.

**B-2 — 단일 `AskUserQuestion` proceed 게이트 (3옵션, AC20)**

```
question: "interview brief 완결: <brief-path> (5 통과 의례 통과). 다음 단계?"
header:   "Proceed"
options:
  ① "/compact 후 brainstorming (권장)"
       — verbatim /compact 노출 → 사용자 실행 시 brainstorming. 긴 인터뷰
         context(round 대화·web sweep·steelman 중간산출) 정리 이점. brief 보존.
  ② "바로 brainstorming"
       — 즉시 Skill superpowers:brainstorming <brief-path> (compact 없이, 전체 context 유지).
  ③ "brief만 종료"
       — brief는 단독 완결 terminal (NG7). handoff 안 함, 종료.
multiSelect: false
```

**B-3 — 응답 처리**

- **① /compact 후 brainstorming**: 아래 verbatim `/compact` 명령을 *그대로 보이게* 노출
  (`<brief-path>` 치환) + "compact 후 brainstorming 진입 준비됨" 안내:

  > `/compact interview brief at <brief-path> 보존 — brief 본문(특히 Reframe, Landscape,`
  > `Locked Directions, Open Questions)과 경로 참조 유지하고, round-by-round 인터뷰 대화·web`
  > `sweep 원문·steelman 중간 추론은 drop. 다음 단계: Skill superpowers:brainstorming <brief-path>.`

  → **여기서 턴 종료(STOP). 같은 턴에서 brainstorming 호출 금지.** `Skill
  superpowers:brainstorming <brief-path>` 진입은 사용자가 `/compact`를 *실제 실행한 다음 턴*에
  **사용자 트리거**(예: `/compact write design`처럼 compact 뒤에 붙인 진행 인자, 또는 명시적
  진행 요청)로만 일어난다 — 모델은 다음 턴에 자동 진입하지 *않고* 신호를 기다리며, 사용자가
  redirect하면 미진입(NG4·P17). compact된 fresh context에서 brainstorming이 brief를 다시 읽어
  해답공간을 설계한다.

- **② 바로 brainstorming**: 즉시 `Skill superpowers:brainstorming <brief-path>` 호출
  (rich context 유지 — 현행 동작과 동일).

- **③ brief만 종료**: brief terminal advisory(B-1 부재 advisory와 동일 톤) 출력 후 종료.
  handoff 안 함. state는 SessionEnd hook이 cleanup(별도 cleanup 호출 없음).

**B-4 — 두 가드 (load-bearing)**

- **AP2 polite-stop 금지**: ①/② 선택 후 "brief 완결!"만 narrate하고 게이트 제시/Skill 호출을
  skip하는 것은 polite stop. Step B를 *종료*하는 모든 경로는 (a) 위 proceed 게이트를 거치거나
  (①/②/③), (b) 게이트를 거치지 않는 예외(superpowers 부재)는 명시적 advisory 단락을 동반해야
  한다 — 게이트-less silent 종료 금지. (게이트는 사용자가 redirect 가능한 approval gate이므로
  P17 주권에 기여, polite-stop 아님 — 철학 §AP2.)

- **cross-compact 조기진행 금지 (AC21, AC19 대칭)**: 옵션 ① 선택 시 `/compact`를 노출한 *직후*
  같은 턴에서 `brainstorming`으로 직진하는 것은 금지. compact가 무거운 작업 *뒤에* 오면 context
  위생 이점이 사라져 옵션 ①이 무의미해진다(reviewing-spec AC19에서 실측된 실패 패턴의 대칭).
  다음 턴 진입은 *사용자 트리거*로만 일어나며 모델 자동 진입이 아니다(NG4·P17). 옵션 ②는 이
  정지 요건의 *명시적 예외*(compact 없이 즉시 brainstorming).

### 5.3 Phase 5와의 의도적 차이 (isolation)

- **`approve_handoff.sh` 미호출.** reviewing-spec은 spec_path가 stale/삭제된 worktree일 수
  있어 working-tree 검증 + 세션 cleanup 스크립트가 load-bearing. 반면 interview brief는 *같은
  턴에 막 작성*되고 `check_brief.py gate`로 이미 검증된다 — stale 위험 없음. 세션 cleanup도
  불필요: ①/② 핸드오프면 세션이 brainstorming→reviewing-spec으로 이어져 나중
  spec→writing-plans의 approve_handoff가 정리하고, ③종료면 SessionEnd hook이 정리. **새
  스크립트를 만들지 않는 게 정답**(lightness). 단, ① 노출 *전에* `[[ -f <brief-path> ]]`
  한 줄 sanity check는 둔다(막 쓴 파일이라 거의 항상 통과 — race 방어용 경량 가드, 게이트 아님).
- **다음 stage = `superpowers:brainstorming`** (writing-plans 아님). `/compact` preserve 대상도
  brief의 §1 Reframe / §3 Landscape / locked_directions / Open Questions이며, drop 대상은
  round 대화·web sweep 원문·steelman 중간추론.
- **옵션 ③의 의미가 다름.** Phase 5의 ④ "멈춤"은 *나중에 재개*(state 보존)지만, interview ③
  "brief만 종료"는 brief가 단독 완결 terminal이라 *작업 자체가 끝남*(NG7). state는 SessionEnd가
  정리.

## 6. Acceptance Criteria

- **AC20** — superpowers 가용 시, Step B는 brainstorming을 자동 직진 호출하지 *않고* 3옵션
  (`/compact 후 brainstorming` / `바로 brainstorming` / `brief만 종료`) `AskUserQuestion`
  proceed 게이트를 제시한다. *Verify*: `test_conducting_interview_stage.sh`가 SKILL.md에서
  `AskUserQuestion`·세 옵션 라벨 문구·`/compact` verbatim 명령 존재를 grep assert.
- **AC21** — 옵션 ① 경로는 cross-compact 조기진행 금지를 verifiable하게 명문화한다(AC19 대칭,
  2-layer). *Verify*: (i) grep `턴 종료|다음 턴` ≥ 1 **AND** (ii) 옵션 ① 서술 블록 안에서
  '턴 종료(STOP)' + 'brainstorming 같은 턴 호출 금지' + '다음 턴 = 사용자 트리거'가 *함께*
  명시됐음을 리뷰 레이어가 확인(grep 단독은 같은-블록 공존 보장 못 함 — AC11/AC19 선례 수준의
  mechanical 한계 인정).
- **AC22** — AP2 polite-stop 금지가 Step B에 명문화된다(종료 모든 경로 = 게이트 또는 명시적
  advisory). *Verify*: grep `polite[- ]?stop|narrate.*금지|silent 종료 금지`.
- **AC23** — superpowers 부재 시 graceful degradation(brief terminal + loud advisory + STOP,
  게이트 없음)이 보존된다(AC13 불변). *Verify*: 기존 `has 'superpowers.*(부재|없).*advisory'`
  assert 유지 + 게이트가 superpowers-가용 분기 *안에* 있음을 리뷰 확인.
- **AC24** — NG7(handoff 비강제)이 보존된다 — 옵션 ③이 그 가시화. *Verify*: 기존
  `has 'optional|선택'` assert 유지 + ③ 옵션 라벨 grep.

## 7. Rejected Alternatives

- **B. 공유 reference 추출** — `/compact` 게이트 계약을 별도 문서로 빼고 reviewing-spec Phase 5와
  conducting-interview Step B가 둘 다 참조. *기각*: call-site가 2개뿐이라 추출 임계 미달, devbrew
  skill self-contained(progressive disclosure) 관례 위배, indirection 비용 > drift 비용. drift는
  cross-reference 한 줄 + 테스트 mechanical assert로 더 가볍게 봉쇄된다.
- **C. 최소 inline 증강** — Step B prose를 유지하고 게이트 몇 문장만 삽입. *기각*: Phase 5의
  cross-compact 가드는 2-layer verifiable로 정밀 설계됐는데, 허술하게 포팅하면 AC19에서 막은
  "compact 말하고 같은 턴에 직진" 실패가 interview 쪽에서 재현된다.
- **게이트 없이 advisory-only로 `/compact` 권유** — *기각*: 모델은 `/compact`를 실행할 수 없어
  자동 진행하면 영원히 compact가 안 된다. 멈춤(게이트)은 선택이 아니라 메커니즘적 필연.
- **interview 쪽 `approve_handoff.sh` 신설** — *기각*: §5.3. brief는 막 쓰여 검증됐고 cleanup은
  하류 또는 SessionEnd가 담당. 불필요한 스크립트.

## 8. Files to Modify

| 파일 | 변경 |
|---|---|
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | "Step B — optional handoff" 섹션을 §5.2 게이트 설계로 재작성. reviewing-spec Phase 5로의 cross-reference 한 줄 추가. |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | AC20/AC21/AC22 assert 추가. 기존 AC13/optional assert(AC23/AC24)는 유지. |
| `plugins/spec-distill/.claude-plugin/plugin.json` | `0.12.0 → 0.13.0` (minor = 새 surface). |
| `plugins/spec-distill/CHANGELOG.md` | `## [0.13.0] — 2026-06-04` 엔트리 (Added/Changed). |
| `plugins/spec-distill/README.md` | "Principles Instantiated"에 interview-side `/compact` 게이트 대칭 한 줄 + flow 다이어그램에 게이트 표기. |

## 9. Verification Plan

1. **TDD**: 먼저 `test_conducting_interview_stage.sh`에 AC20/AC21/AC22 grep assert 추가 →
   red 확인(현재 SKILL.md엔 게이트 문구 없음) → SKILL.md Step B 재작성 → green.
2. **회귀**: 기존 `test_conducting_interview_stage.sh` 전체 PASS 유지(AC23/AC24 포함).
   `test_brainstorming_entry.sh`(hook+cleanup) PASS 유지 — 본 변경은 hook 미변경이라 무영향.
3. **테스트 실행**: `python3 -m unittest` 대상 아님(이건 .sh). repo root에서 `bash
   plugins/spec-distill/tests/test_conducting_interview_stage.sh` 실행(reference: test runner
   메모 — .sh는 직접 실행).
4. **README sync**: `test_readme_sync.sh`가 있으면 버전·문구 동기화 확인.
5. **수동 e2e(선택)**: superpowers 설치 환경에서 `/interview`로 짧은 인터뷰 → brief 완결 →
   3옵션 게이트가 뜨고 ① 선택 시 verbatim `/compact`가 노출되며 같은 턴에 brainstorming으로
   직진하지 *않음*을 확인.

## 10. Handoff Context

- **구현 위치**: 본 워크트리 `feature/interview-compact-handoff`(main=`b5a20b5`에서 분기,
  spec-distill 0.12.0 베이스). 사용자 지시 — 구현은 main에서 워크트리 생성해 진행.
- **변경의 핵심 1줄**: conducting-interview Step B의 자동 brainstorming invoke를, reviewing-spec
  Phase 5와 대칭인 3옵션 `/compact` proceed 게이트로 교체(가드 2개 포함, approve_handoff 미호출).
- **load-bearing 부분**: 두 가드(AP2 + cross-compact AC21). 이게 없으면 `/compact` 옵션이
  무의미(모델이 말만 하고 직진). 절대 약화 금지.
- **건드리면 안 되는 것**: 5 통과 의례, web budget, steelman, hook(spec-write-validator/
  session-end-cleanup), reviewing-spec Phase 5.
- **다음 단계**: 이 design doc은 brainstorming 산출물이므로 spec-distill Stop hook이 design-mode
  review(reviewing-spec)를 강제할 수 있음 — Law 2 분리 reviewer 검증 후 Phase 5 게이트 →
  writing-plans → 구현(TDD).
