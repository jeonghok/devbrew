---
name: remove-depth-audit
type: design
created_at: 2026-09-10
source_interview: none
next_phase: superpowers:writing-plans
---

# depth audit 제거 — 설계

> **재지 않는 측정과 쓰이지 않는 형식은 걷어 낸다. 닫힘 규칙은 남긴다.**

spec-distill 인터뷰(`conducting-interview`)에서 0.57.0 이 넣은 사후 깊이 측정(Step A.7)과, 그 측정이 읽던
라운드 형식(«직전 답에서» 블록 + 질문 둘)을 제거하고 라운드를 «지금 이해 · 다음 결정 · 질문 하나»로 대체한다.

## 목차

- [Goal](#goal)
- [Handoff Context](#handoff-context)
- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [1. 제거 — 사후 측정](#1-제거--사후-측정)
- [2. 라운드 규약 대체](#2-라운드-규약-대체)
  - [2.1 새 형식](#21-새-형식)
  - [2.2 규칙](#22-규칙)
  - [2.3 옮겨 가는 규칙](#23-옮겨-가는-규칙)
  - [2.4 지우는 것](#24-지우는-것)
  - [2.5 문구만 고치는 곳](#25-문구만-고치는-곳)
- [3. 테스트 · 락](#3-테스트--락)
  - [3.1 삭제](#31-삭제)
  - [3.2 고치는 락](#32-고치는-락--teststest_conducting_interview_stagesh)
  - [3.3 재조준](#33-재조준)
  - [3.4 새 락](#34-새-락--teststest_stale_termssh-에-한-축)
- [4. 버전 · 문서](#4-버전--문서)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [Open Questions](#open-questions)
- [Concrete Next Action](#concrete-next-action)

## Goal

`conducting-interview` 에서 Step A.7 사후 깊이 측정 전체(스크립트 둘 · agent 하나 · 사람 라벨 질문 · 측정 원장 ·
판정자 투입 조건)와 «직전 답에서» 라운드 블록 + 질문 둘을 제거하고, 라운드를 «지금 이해 / 다음 결정 / 질문
하나»로 대체한다. S앵커 닫힘 게이트 · coverage-mapper 게이트 · 재개방 기록 · Phase 0 «다시 검증할 것» 문단
규약은 유지한다. 제거는 stale-term 부재 락과 기준선 대비 새 실패 0 으로 검증하고 major 릴리스로 출하한다.

## Handoff Context

**TL;DR** — 0.57.0(2026-09-07)의 사후 깊이 측정은 도입 후 기록이 0건이고 사람 e2e 로 한 번도 실행되지
않았다. 라운드 형식(«직전 답에서» 블록)을 코드로 읽는 것은 측정 스크립트 하나뿐이다. 사용자는 세 이유(쓰이지
않는 무게 · 인터뷰가 번거로움 · 방향이 틀렸다)로 둘 다 제거하기로 했다(2026-09-10). 라운드는 지금 형식의
아래 절반(지금 이해 / 다음 결정 / 질문)만 남기고 질문은 하나로 줄이며, 약한 답에 되묻는 규칙은 한 줄로 남긴다.
블록에 기대던 규칙 다섯은 새 자리로 옮긴다.

**Implicit context** (Constraints 에 안 박힌, 작업에 필요한 외부 사실):
- base 는 `origin/main` `e5234326`(그 시점 spec-distill 1.0.1 — 버전은 C2 대로 머지 시점에 다시 잰다). 작업 공간은
  워크트리 `.claude/worktrees/feature+remove-depth-audit`(브랜치 `feature/remove-depth-audit`)다. 메인 체크아웃은
  다른 세션이 함께 쓰며 브랜치를 바꾸므로 이 작업의 모든 명령은 워크트리에서 돈다.
- 0.57.0 설계 원문은 `docs/superpowers/specs/2026-09-06-interview-depth-redesign-design.md` 다. 이 문서는 그
  설계의 일부를 뒤집지만 그 파일은 편집하지 않는다(커밋된 설계 기록).
- 라운드 형식을 읽는 코드는 `scripts/depth_pairs.py` 하나다 — `scripts/`·`hooks/` 전수 `git grep` 에서 다른
  독자 0건. «state 본문은 출력과 같은 형식»(`SKILL.md:56,81`)과 «steelman 대안은 줄바꿈 없이 한 줄로»
  (`steelman.md:86`)는 그 스크립트 때문에 생긴 규칙이다.
- 닫힘 게이트(`check_brief.py` 의 S앵커 · coverage-mapper ≥1 검사)는 depth 를 참조하지 않는다(코드 결합 0).
- `shared/tests/test_dispatch_disposition.sh` 는 «모든 agent 가 dispatch 자리 ≥1»을 면제 없이 잰다.
- `shared/tests/test_adjudication_wiring.sh` 의 대상 파일 집합은 `consumer=` 앵커와 import 로 **도출**되지만
  컴프리헨션 기준값 `COMP_BASELINE=58` 은 **리터럴**이다. `depth_record.py` 가 그중 6 을 기여했다(그 파일의
  이력 주석). 비교가 `-le`(이하)라 값을 바꾸지 않아도 GREEN 이다 — 그래서 C7 · AC7 이 값의 일치를 따로 잰다.
- `test_stale_terms.sh` 의 스코프는 spec-distill 아래 production 전체이고 `CHANGELOG.md`·`tests/` 는 제외다.
  README 는 스코프 **안**이다. 같은 파일에 개념 별칭 목록(V9 `alias_terms`)과 삭제 파일 부재 목록(V10
  `removed_files`, 개수 락 20)이 이미 있다.
- Stop 훅이 이 설계문서의 Law 2 분리 리뷰를 강제한다. 리뷰가 끝나기 전에 커밋하면 훅이 arm 하지 않는다.
- 이 리포는 1.0.0 이상 플러그인의 즉시 제거를 여러 번 했고, 대표 선례 셋은 major bump + CHANGELOG `### Deprecated` 에
  one-minor window 와의 충돌을 적고 «제3자 설치 없음» 조건으로 수용했다(`plugins/project-init/CHANGELOG.md`
  2.0.0·3.0.0 절, `plugins/quality-gates/CHANGELOG.md` 5.0.0 절).
- 착수 전 선재 RED: `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` (rc 1).

**Deferred to plan**:
- 새 SKILL 산문의 최종 문구(이 문서는 형식과 규칙의 내용만 고정한다).
- 각 락의 정규식과 블록 스코프 경계.
- `COMP_BASELINE` 의 실측값.
- 기준선 수집기의 구현(실행기 · 출력 파싱 · 기록 형식) — 설계는 C6 의 불변식과 V1 의 양성 대조만 정한다.
  plan 요구사항: 수집기는 셸 파일마다 끝까지 돌았다는 **완료 증거**를 요구하고, 없으면 그 파일을 실패로 센다 — 기존
  실패 하나를 찍고 중단된 실행이 멀티셋 비교를 통과하지 않게. 의도적으로 지운 테스트 파일은 목록으로 명시해 뺀다.
- README 문구를 쓰는 task 는 `깊이 측정` 대신 다른 말을 쓴다 — 식별자 축이 README 를 포함한다(3.4).
- 사람 e2e 인터뷰를 실행할지 — plan 단계에서 사용자에게 묻는다.

## Context / Why

**0.57.0 이 넣은 것** — (1) 라운드마다 직전 답 S<k> 별 «직전 답에서» 블록(함의·상충·확인한 사실·위험) +
AskUserQuestion 질문 둘(Q1 되비추기 확인, Q2 새 결정), (2) 닫힘 evidence 의 S앵커 게이트, (3) 종료 직전 Step A.7
사후 측정 — `depth_pairs.py` 가 «답 → 다음 블록» 짝을 뽑고, `depth-auditor` 가 짝마다 라벨하고, 사용자가 ≤4개에
라벨하고, `depth_record.py` 가 audit §2 네 줄 · `docs/superpowers/interview/depth/<basename>.json` · 판정자 투입
조건 줄을 낸다. (4) Phase 0 의 seed «다시 검증할 것» 문단 규약.

**측정된 사실**
- `docs/superpowers/interview/depth/` 에는 `.gitkeep` 하나뿐이다 — 도입 이후 기록된 인터뷰 0건.
- `CHANGELOG.md [0.57.0]` 의 V7: 사람 e2e 인터뷰는 실행되지 않았고 AC16 은 미충족이다. 라운드 규약·Step A.7·
  종료 라벨 질문은 라이브 세션에서 한 번도 돌지 않았다.
- 그 결과 판정자 투입 조건(누적 5건 · not_dug 30% · 일치 70%)은 도달할 수 없는 상태로 남아 있다.

**사용자의 이유** (2026-09-10, 셋 다 선택):
1. **쓰이지 않는 무게** — 기록 0건인데 파일 18개와 락 수십 개의 유지비를 진다.
2. **인터뷰가 번거로움** — 매 라운드 질문 둘 · 네 줄 블록 · 종료 라벨 질문의 체감 부담.
3. **방향이 틀렸다** — «직전 답에서» 규약과 사후 측정이 원래 증상(얕은 인터뷰)을 고치지 못한다고 본다.

확정된 설계를 뒤집는 근거는 위 사용자 결정과 측정된 사실이다(철학 P23 — 근거 있는 재결정은 사용자 동의로 허용).

**0.57.0 설계 대비 — 뒤집는 것과 유지하는 것**

| 0.57.0 항목 | 이 설계 |
|---|---|
| G1 · §1 라운드 블록 + 질문 둘 | **뒤집음** — 지금 이해 / 다음 결정 / 질문 하나 |
| G3 · §3 사후 측정 세 층 | **뒤집음** — 전부 제거 |
| G4 · §3.4 판정자 투입 조건 | **뒤집음** — 제거 |
| G2 · §2.1 S앵커 닫힘 게이트 | 유지 (코드 무변경) |
| C4 · §2.3 coverage-mapper dispatch 상한 2 · 게이트 k≥1 | 유지 |
| C3 · §2.2 재개방 (`reopened`·`reopen_log`·audit §1 접미) | 유지 — 표시 자리만 이동 |
| G5 질문 본문·선택지 설명 규칙 | 유지 |
| G6 · §4 Phase 0 문단 규약 · 워크트리 · 커밋 | 유지 — 문단의 소비 자리 문구만 변경 |
| §1.3 되묻기 | 축소 — 한 줄 |

## Goals

- **G1 — 사후 측정이 production 에서 사라진다.** 섹션 1 의 18개 파일이 트리에 없고, 측정 식별자가 production 에
  0건이다.
- **G2 — 라운드는 «지금 이해 / 다음 결정 / 질문 하나»로 돈다.** AskUserQuestion 1회에 질문 1개, 추천이 첫
  선택지(steelman 절차의 질문은 `steelman.md` 규약을 따른다), 약한 답에는 상한 있는 되묻기 한 줄.
- **G3 — 블록에 기대던 규칙이 소리 없이 사라지지 않는다.** 닫힘 근거 · 재개방 표시 · 외부 근거 처분 · seed
  문단 소비 · 경로 표시가 섹션 2.3 의 새 자리를 갖는다.
- **G4 — 유지 대상의 동작이 바뀌지 않는다.** `check_brief.py`·hooks·reviewing-brief·reviewing-spec 은 diff 0.
- **G5 — major 로 출하하고 deprecation window 충돌을 기록한다.**

## Non-goals

- **NG1**: 원래 증상(«질문이 안 떠올라 끝난다» — 얕은 인터뷰)의 대체 해법. Open Questions 로 넘긴다.
- **NG2**: S앵커 게이트 · coverage-mapper 게이트 · `check_brief.py` 의 변경.
- **NG3**: 0.53.1 이전 4-block 원문 · teach-beat · 경로 (c) ambiguity 의 복원.
- **NG4**: 0.57.0 설계문서와 과거 interview brief · audit 문서의 편집.
- **NG5**: reviewing-brief · reviewing-spec · `hooks/*` · Phase 0 워크트리 절의 변경. Phase 0 쪽은 문단 소비 자리를
  가리키는 두 줄(`framing-requests/SKILL.md:44,46`)과 seed 템플릿 표의 한 칸(`templates/interview-seed-template.md:41`)
  만 고친다.
- **NG6**: 새 kill switch · 새 agent · 새 스크립트.

## Constraints

- **C1 (원자 삭제 단위)**: 커밋마다 C6 기준선 대비 새 실패가 0 이어야 한다. 그래서 서로를 가리키는 아래 묶음은
  **한 커밋**에서 함께 바뀐다 — `agents/depth-auditor.md` · `scripts/depth_pairs.py` · `scripts/depth_record.py` ·
  그 테스트 3개와 fixture 11개 · `finishing.md` Step A.7 절과 B-2 깊이 슬롯 · audit 템플릿 §2 깊이 줄 ·
  `test_conducting_interview_stage.sh` 의 A.7 · B-2 깊이 · 템플릿 깊이 줄 락 · `test_finishing_block_scope.py` 의
  양성 대조 · `test_brief_agents.sh` 의 격리 목록 · `COMP_BASELINE` · `docs/superpowers/interview/depth/.gitkeep`.
  이유: 처분 락은 agent 마다 dispatch 자리 ≥1 을, `consumer=` 경로의 실재를 `git ls-files` 로 잰다
  (`shared/tests/test_dispatch_disposition.sh:176`) — 스크립트와 그것을 부르는 절 · 락이 갈라진 중간 커밋은 RED 다.
- **C2 (버전)**: 머지 직전 `origin/main` 을 **merge**(rebase 아님)하고, `plugin.json` 을 그 시점 main 의
  spec-distill 보다 **한 major 위**로 올린다(현재 1.0.1 → 2.0.0). CHANGELOG 최상단 헤딩이 `plugin.json` 과 같은
  값이다. major 인 이유: dispatch 가능한 agent 가 사라지고 라운드 형식과 audit §2 형식이 바뀐다.
- **C3 (Deprecated 기록)**: CHANGELOG `### Deprecated` 에 CLAUDE.md 의 one-minor deprecation window 와 충돌함을
  적고 «제3자 설치 없음(사용자 확인, 2026-09-10)» 조건으로 수용한다. «제3자 설치가 생기면 다음 제거에는 창을
  둔다» 조항을 선례와 같이 붙인다.
- **C4 (부재 락 + 양성 짝)**: 제거 식별자의 부재는 `test_stale_terms.sh` 한 축으로 잰다. 부재 락만으로는 대상
  파일을 통째로 지워도 통과하므로 새 형식의 존재를 재는 양성 짝을 같은 축에 둔다. README 는 제거 식별자를
  인용하지 않고 개념으로 서술한다.
- **C5 (락 규약)**: 산문 락은 절 스코프 + 본문 고유 문구로 잡는다. 새로 쓰거나 고친 락은 변이(통째 삭제 ·
  문구 반전 · 값 변경)로 RED 를 확인하고, 변이 전에 커밋한다. `PYTHONDONTWRITEBYTECODE=1`.
- **C6 (기준선)**: 착수 전 spec-distill 셸 스위트 · `python3 -m unittest discover -s plugins/spec-distill/tests` ·
  `shared/tests` 의 실패를 **(파일, 실패 식별자) 멀티셋**으로 기록한다 — 셸 락은 실패로 찍힌 단언 문구(`no "…"` 출력 줄),
  unittest 는 실패·오류 테스트 id. 셸 파일이 rc≠0 으로 끝났는데 수집된 실패 단언이 없으면 `(파일, rc=<N>)` 하나를
  실패 식별자로 넣는다 — 구문 오류 · 조기 종료로 단언 없이 죽은 파일이 판정을 빠져나가지 않게. 완료 후 «완료 멀티셋 − 기준선 멀티셋 = ∅» 로 새 실패 0 을 판정한다(개수까지 비교해야 기준선에 이미 있는 문구와 같은 새 실패가 묻히지 않는다). 파일별 rc 와
  실패 줄 수는 보조로 함께 적는다 — 그 둘만으로는 같은 파일 안에서 기존 실패가 사라지고 새 실패가 생긴 경우가
  같은 숫자로 보인다. **머지 직전 `origin/main` 을 merge 한 뒤에는 기준선을 다시 잡는다** — merge 한 `origin/main`
  끝 커밋에서 세 스위트를 돌려 새 기준선을 기록하고, merge 커밋 이후의 판정은 그 새 기준선과 비교한다. main 이
  가져온 실패가 이 작업의 회귀로 섞이지 않게, 거꾸로 이 작업의 회귀가 main 탓으로 묻히지 않게 하기 위해서다.
- **C7 (실측 기준값)**: `COMP_BASELINE` 은 `ast` 로 다시 센 값을 쓴다. 58 − 6 = 52 는 예상이지 값이 아니다.
  비교가 `-le` 라 58 을 그대로 두어도 GREEN 이므로, 리터럴이 실측값과 **같은지**를 AC7 에서 따로 잰다 — 같지
  않으면 늘어난 컴프리헨션이 여유분 안에 숨는다.
- **C8 (G7 어휘)**: 새 SKILL 산문은 G7 부재 락이 막는 옛 4-block 어휘를 쓰지 않는다(그 예외는 `steelman.md`
  하나).
- **C9 (순감)**: `conducting-interview/SKILL.md` 는 줄 수가 준다(현재 388).

## 1. 제거 — 사후 측정

**삭제 (18)**

| 종류 | 경로 |
|---|---|
| agent | `plugins/spec-distill/agents/depth-auditor.md` |
| 스크립트 | `plugins/spec-distill/scripts/depth_pairs.py` · `depth_record.py` |
| 테스트 | `plugins/spec-distill/tests/test_depth_pairs.py` · `test_depth_record.py` · `test_depth_auditor_frontmatter.sh` |
| fixture | `plugins/spec-distill/tests/fixtures/depth-state-*.md` 11개 |
| 측정 원장 디렉토리 | `docs/superpowers/interview/depth/.gitkeep` |

**편집 (측정 흔적)**
- `references/finishing.md` — Step A.7 절 전체(127–217행) 삭제. Step B-2 게이트 `question` 의 «깊이: …» 슬롯과
  그 근거 문장(313행) 삭제. 같은 자리의 `check_brief` advisories 슬롯(`coverage-mapper 0 (unavailable)`)은 유지.
- `templates/interview-audit-template.md` — §2 의 깊이 네 줄과 설명 문장 삭제. §2 는 «질문 라운드 · agent
  dispatch · coverage-mapper `<k>` · codex 실호출» 데이터 줄 하나가 된다. 설명의 «다섯 줄»도 그에 맞춘다.
- `references/state-migration.md:32` — `user_statements` 를 비우지 않는 이유에서 «깊이 측정의 근거»를 지운다.
- `README.md` — Law 3 «깊이 측정 원장» 줄 삭제, AP9 agent 목록 11종 → 10종.

**사용자가 겪는 변화**: 인터뷰 종료 시 depth-auditor dispatch 1회와 «파고들었다 / 안 팠다 / 판단불가» 라벨
질문(≤4개)이 없어진다. proceed 게이트 질문에서 «깊이:» 줄이 빠진다.

**함께 사라지는 개념**: 판정자 투입 조건 — 닫힘 거부권 에이전트를 언제 들일지 알려 주던 유일한 신호다(OQ3).
0.57.0 설계의 OQ4 · OQ5 는 대상을 잃는다.

## 2. 라운드 규약 대체

### 2.1 새 형식

사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다. 이 형식을 읽는 스크립트는 없으므로 «계약»이라는
주장은 두지 않는다.

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

### 2.2 규칙

- 라운드마다 AskUserQuestion 1회, **질문 1개**. 첫 선택지가 추천(권장)이다 — steelman 절차의 질문만 예외(아래).
- question 본문은 무엇을 정하는지 · 용어 · 기술 사실을 풀고, 각 선택지의 `description` 은 «고르면 무엇이
  달라지는가»를 담는다. 기계 검사는 없다.
- **되묻기**: 직전 답이 보류 · 한 단어 · 이유 없는 추천 수락 · 근거 없는 단정이면, 그 라운드의 질문은 이유 ·
  사례 · 실패 조건 중 하나를 되묻고 인터뷰어의 추측을 첫 선택지로 둔다. **같은 주제의 연속 되묻기는 최대 2회**다 —
  그 뒤에도 약한 답이면 답을 그대로 기록하고(보류는 «사용자 발화 기록» 표대로 §3 Open Questions 로도 이월) 다음
  질문으로 넘어간다. 그 차원은 자동으로 닫지 않는다.
- **한 라운드에 겹치면** — 되묻기 · 외부 근거 처분(landscape · premortem 출력을 받아들일지) · 새 결정 중 이
  순서로 앞선 하나가 그 라운드의 질문이 되고, 나머지는 다음 라운드의 «다음 결정»으로 넘어간다. 되묻기가 먼저인
  이유는 약한 답 위에 다음 결정을 쌓지 않기 위해서고, 외부 근거 처분이 새 결정보다 먼저인 이유는 landscape ·
  blind_spot 이 그 처분 S 로만 닫히기 때문이다.
- **steelman 절차의 질문** — `references/steelman.md` 가 사용자에게 묻는 모든 질문(지금은 Step 1 의 goal 확인 ·
  Step 3 의 게이트 · Step 4 의 «보완» 직후 질문)은 **전부 그 파일의 규약**(선택지 순서 · 라벨 · 추천 표기 · 시점)을
  따르고 각각 `## R<n>` 한 라운드로 기록한다. 이 절의 질문 수 · (권장) 표기 · «추천: <첫 선택지>» · 겹침 순서는 그
  질문들에 적용하지 않으며, steelman 절차가 진행 중이면 그 질문이 겹침 순서보다 앞선다(Step 4 의 «게이트 직후»
  계약). 경계를 목록이 아니라 «그 파일이 묻는 질문»으로 긋는 이유: 괄호 안은 오늘의 예시이고, 그 파일에 질문이
  늘어도 규칙은 그대로다. 게이트의 고정 순서 · 추천 라벨 없음은 추천이 한쪽으로 쏠리지 않게 하는 장치라 지킨다.
- **인자 없이 `/interview` 를 부른 경로의 R1** 은 seed 도 직전 답도 없으므로 «지금 이해»를 «아직 없음»으로 두고
  질문으로 무엇을 다룰지 묻는다. coverage-mapper 첫 dispatch 는 그 경로에서 R1 답을 받은 뒤 R2 전이다
  (`SKILL.md` coverage-mapper 절 규칙 1 — 그대로 둔다).
- 답은 `user_statements` 에 `S<m>` 하나로 append 한다(선택지 = `chosen`, «기타» 자유 입력 = `verbatim`).
  번호 공식은 «사용자 발화 기록» 절 그대로.

### 2.3 옮겨 가는 규칙

| 규칙 | 지금 자리 | 새 자리 |
|---|---|---|
| 닫힘 근거 | «그 차원의 되비추기에 사용자가 답한 S 뒤에만 닫는다» (`SKILL.md` 닫힘 · 재개방 절) | «차원은 **그 차원에 관한 질문에** 사용자가 답한 S 를 근거로만 닫는다(floor · derived 모두). sweep · steelman · prober 의 횟수는 근거가 아니다 — landscape · premortem 출력은 «지금 이해»에 실려, steelman 출력은 자기 게이트 제시 형식(`steelman.md` Step 3)으로 사용자 처분 S 를 받은 뒤 닫힌다». 한정어 «그 차원에 관한»을 남기는 이유: 어느 S 인지를 보는 게이트가 없어(OQ2) 이 산문이 유일한 방어선이다. blind-spot-prober 절의 «출력을 기록하고 closed 로 전이» 문장(`SKILL.md:296-298`)도 «처분 S 를 받은 뒤 closed» 로 맞춘다 — 지금은 닫힘 절과 어긋난다 |
| landscape 닫힘 발화 | «외부 근거 되비추기 처분 S» (`SKILL.md:272`, `finishing.md:76`) | «외부 근거 처분 S» |
| 재개방 표시 | 그 라운드의 «상충» 줄 | 그 라운드의 «지금 이해». state `reopen_log` · audit §1 접미는 그대로 |
| seed «다시 검증할 것» 문단 | R1 «직전 답에서 — S1» 블록의 입력 (`seed-input.md:11`, `framing-requests/SKILL.md:44`) | R1 의 «지금 이해»·질문의 재료 + coverage-mapper 첫 dispatch 입력. `framing-requests/SKILL.md:46` 의 «되비추기로 검증» → «질문으로 검증» |
| 경로 표시 | 매 라운드의 «확인한 사실»·«질문» (C43 routing 절) | 매 라운드의 «지금 이해»·«질문» |

### 2.4 지우는 것

- «직전 답에서» 블록 형식과 네 줄 규칙, 넷 다 «없음»이면 Q1 되묻기 규칙.
- 질문 둘 절 전체 — Q1(«맞다/모르겠다») · Q2 · Q1 수정 시 재되비추기(같은 주제 최대 2회) · Q2 독립성 규칙.
- `provisional_on` — `user_statements` 스키마 필드와 그 규칙(`SKILL.md` 질문 절 · 발화 기록 절 · 닫힘 절 `:274`). 진행 중 세션에
  남은 필드는 읽는 자가 없어 무해하므로 마이그레이션을 두지 않는다.
- 인자 없이 `/interview` 를 부른 경로의 R1 **블록 면제**(`SKILL.md:110-113` — 면제할 블록이 없어진다). 같은
  문장이 담은 coverage-mapper 첫 dispatch 시점(R1 답 뒤 · R2 전)은 지우지 않는다 — `SKILL.md:229-230` 에 같은
  규칙이 있어 그 자리가 정본으로 남는다. 그 경로의 R1 모양은 2.2 대로.
- «되묻기로 바뀌는 조건» 절(2.2 의 한 줄로 대체)과 그 예시 블록.
- 원칙 문장 «인터뷰어의 다음 행동은 사용자의 직전 답에서 나온다»(사용자 판단 «방향이 틀렸다»).
- «state 본문은 같은 형식 — 측정 스크립트가 읽기 때문» 문장(`SKILL.md:56,81`).
- `steelman.md:84-87` — builder 출력을 «상충» 줄에도 싣는 중복 문단과 한 줄 규칙. steelman 은 자기 게이트
  제시 형식(Step 3)으로 사용자에게 보이고, skepticism 의 닫힘 발화는 steelman 판정 S 그대로다.

### 2.5 문구만 고치는 곳

`SKILL.md` 도입부(17–18행) · `README.md` 7 · 22 · 36 · 145행 · `commands/interview.md:46` — ««직전 답에서» 블록 +
질문 둘»을 «지금 이해 · 다음 결정 · 질문 하나»로. `templates/interview-seed-template.md:41` 의 «Phase 1 이
되비춘다»는 «Phase 1 이 질문으로 확인한다»로. README 145행(devbrother2024 영향)은 라운드 형식이 4-block 의
후손으로 돌아왔고 R3 steelman 게이트의 4-block 과는 다른 물건이라는 사실을 식별자 없이 서술한다.

## 3. 테스트 · 락

### 3.1 삭제

섹션 1 의 테스트 3개와 fixture 11개. 이 파일들을 이름으로 참조하는 러너나 목록은 없다(`git grep` 0건).

### 3.2 고치는 락 — `tests/test_conducting_interview_stage.sh`

| 블록 | 지금 재는 것 | 처리 |
|---|---|---|
| 라운드 규약 (AC1 · AC2) | 블록 · 네 줄 · Q1/Q2 · `provisional_on` · R1 예외 · «`## R<n>` 은 depth_pairs 계약» | 삭제 후 새 형식 락: 소제목 셋 · 질문 1개 · 첫 선택지 (권장) · description 규칙 · 되묻기 상한 · 겹침 순서 · steelman 절차 질문의 예외(«그 파일이 묻는 질문» 도출 규칙) · 인자 없는 R1 모양(2.2). 새 절 제목도 `## 라운드 규약` 으로 시작한다 — 절 추출 awk 앵커(`/^## 라운드 규약/`)가 이 접두어에 묶여 있다 |
| 되묻기 (C1) | 독립 절 | 라운드 규약 절 안의 한 줄로 재조준(세 축 + 추측이 첫 선택지) |
| 닫힘 · 재개방 (G2 · AC5 · C3) | «되비추기에 답한 S 뒤에만» · «상충 줄에 → 재개방» | 섹션 2.3 의 새 문구로 재조준 — 한정어 «그 차원에 관한»을 본문 고유 문구로 잡고, 재개방 표시는 «지금 이해», blind-spot-prober 절의 전이 문장은 «처분 S» 뒤로 |
| floor 닫힘 발화 규약 (`:417-419`) | 닫힘 절에 차원 이름 다섯이 있는가 — 문구는 재지 않는다 | 유지 + **신설**: landscape 의 «외부 근거 처분 S» 를 `SKILL.md` 닫힘 절과 `finishing.md` Step A 4 항 양쪽에서 잰다 |
| seed 문단 소비 (**신설**) | 없음 — `:826` 은 `다시 검증할 것` 만 grep 한다 | seed 입력 절(`seed-input.md`)에서 «다시 검증할 것» · «지금 이해» · coverage-mapper 가 한 문장에 있는가. `framing-requests/SKILL.md` 쪽 같은 관계는 `tests/test_request_framing_command.sh` 에 신설 |
| C43 경로 표시 (**신설**) | 없음 — C43 락은 경로 행 수만 센다 | C43 절 본문이 경로 표시 자리로 «지금 이해»·«질문» 을 가리키는가 |
| Step A.7 | 측정 절차 | 삭제 |
| B-2 «깊이:» 슬롯 · 템플릿 깊이 네 줄 | 존재 | 삭제 — 부재는 3.4 의 stale-term 축이 잰다. 곁의 `coverage-mapper` 슬롯 · 데이터 줄 락은 유지 |
| G7 부재 락 | 옛 4-block 어휘가 `steelman.md` 밖에 없음 | 그대로 |

### 3.3 재조준

- `tests/test_finishing_block_scope.py` — 불변식(펜스끼리 변수를 나르지 않는다)은 남는 펜스(Step A 5 게이트 ·
  A.5 · B-0)에도 적용되므로 유지한다. 양성 대조를 A.7(«펜스 ≥4 + `depth_record.py` 호출 포함») 대신 남는 펜스의
  호출로 옮기고 펜스 수 하한을 3 으로 둔다(Step A 5 게이트 · A.5 · B-0 — 각 절 아래 펜스 위치는 확인했다).
  docstring 의 사례 서술도 그에 맞춘다.
- `tests/test_brief_agents.sh` — 도구 0 격리 agent 목록 `EXPECTED_ISOLATED` 에서 `depth-auditor` 제거(5 → 4).
- `shared/tests/test_adjudication_wiring.sh` — `COMP_BASELINE` 을 실측값으로 바꾸고(C7) 이력 주석 한 줄.

### 3.4 새 락 — `tests/test_stale_terms.sh` 에 한 축

- **부재 — 식별자**: `depth_pairs` · `depth_record` · `depth-auditor` · `직전 답에서` · `provisional_on` · `깊이 측정`
  이 production 에 0건. 스코프 · 제외 규칙은 그 파일의 기존 규칙 그대로(`CHANGELOG.md`·`tests/` 제외).
  `depth-audit`(센티널 이름)은 넣지 않는다 — 이 설계문서 파일명(`…remove-depth-audit-design.md`)과 겹치는데 production
  은 설계문서 경로를 출처로 인용하는 관례가 있어(`README.md:89`) 정직한 인용까지 RED 가 된다. 그 이름이 살던 두
  파일(`agents/depth-auditor.md` · `scripts/depth_record.py`)은 V10 이 부재를 잰다.
- **부재 — 개념 별칭**(V9 `alias_terms` 와 같은 모양이고, V9 처럼 **README 는 제외**한다 — README 는 삭제 연혁을 정직하게 적는 자리라 별칭까지 재면 정직한 서술이 RED 가 되고 락이 무시된다(`test_stale_terms.sh:171-182` 의 측정 근거). 식별자 축은 README 를 포함한다): `되비추` · `되비춘` · `판정자 조건` · `판정자 투입`. 식별자만
  재면 `되비춘다`·`판정자 투입 조건` 처럼 활용·어순이 다른 서술이 살아남는다. `Q1` 은 `OQ1` 과 겹쳐 넣지 않는다.
- **삭제 파일 부재**: 섹션 1 의 spec-distill 아래 17개 경로를 V10 `removed_files` 에 더하고 개수 락을 20 → 37 로
  고친다 — 참조 스윕만으로는 되살아난 파일을 못 잡는다(V10 의 존재 이유). V10 은 `$SD/<경로>` 로 재므로
  `$SD` 밖의 `docs/superpowers/interview/depth/.gitkeep` 은 넣지 않는다 — 그 경로는 AC1 의 1회 확인으로만 잰다.
- **자기 적용 스윕** (2026-09-10 실측): 위 식별자 · 별칭 토큰을 production 전체에 `git grep` 한 결과, 걸리는 파일은
  전부 Files to Modify 의 수정 · 삭제 대상이다. 토큰이나 목록을 바꾸면 이 대조를 다시 한다(V0).
- **양성 짝**: `conducting-interview/SKILL.md` 라운드 규약 절에 새 형식에만 있는 문구 — «질문 1개» 와 되묻기 상한
  문구 — 가 실재한다. `### 지금 이해` 는 지금 판에도 있어 새 형식의 증거가 못 된다.

## 4. 버전 · 문서

- `plugin.json` → 머지 직전 main 기준 다음 major(C2).
- CHANGELOG 최상단 절: 첫 줄에 major 인 이유. **Removed**(섹션 1 의 18개 · 판정자 투입 조건 · `provisional_on` ·
  질문 둘). **Changed**(라운드 규약 · 닫힘 문구 · 재개방 표시 자리 · seed 문단 소비 자리 · audit 템플릿 §2 ·
  proceed 게이트 텍스트 · `COMP_BASELINE`). **Deprecated**(C3). **Verification**(기준선 대비 결과 · 변이 결과 ·
  사람 e2e 실행 여부).
- README «Principles Instantiated» 는 섹션 1 · 2.5 대로.

## Acceptance Criteria

- **AC1 (삭제)**: 섹션 1 의 18개 경로가 `git ls-files` 에 0건이고 `docs/superpowers/interview/depth/` 가 없다.
- **AC2 (부재 락)**: `test_stale_terms.sh` 의 새 축이 GREEN 이고, 식별자 하나를 `SKILL.md` 에 되넣는 변이 · 별칭
  하나(`되비춘`)를 `SKILL.md` 에 되넣는 변이 · 양성 짝 문구 «질문 1개» 를 지우는 변이 · V10 목록에서 항목 하나를
  빼는 변이가 각각 RED 다. 같은 별칭을 README 에 넣으면 GREEN 이다(README 제외가 의도대로 동작한다).
- **AC3 (라운드 규약)**: `SKILL.md` 의 `## 라운드 규약` 으로 시작하는 절에 소제목 셋 · 질문 1개 · 첫 선택지
  (권장) · description 규칙 · 되묻기 한 줄과 그 상한(같은 주제 2회) · 겹침 순서 · steelman 절차 질문의 예외(도출 규칙) · 인자 없는 R1 모양이 있고, 그 절 안에 Q1/Q2 ·
  `provisional_on` · R1 블록 면제가 없다(부재 검사는 이 절로 스코프한다 — coverage-mapper 절의 «인자 없이 부른
  경로에서는 R1 답을 받은 뒤 R2 전에» 는 남는다). `SKILL.md` 줄 수 < 388.
- **AC4 (옮겨 간 규칙)**: 섹션 2.3 의 다섯 행이 새 자리에 있고, 행마다 3.2 의 락이 잰다 — 닫힘 근거 · 재개방
  표시는 «닫힘 · 재개방» 행(재조준), landscape 발화는 «floor 닫힘 발화 규약» 행(신설, `SKILL.md` · `finishing.md`
  양쪽), seed 문단 소비는 «seed 문단 소비» 행(신설, `seed-input.md` · `framing-requests/SKILL.md` 양쪽), 경로
  표시는 «C43 경로 표시» 행(신설). 각 락은 GREEN 이고 문구 반전 변이에 RED 다.
- **AC5 (finishing)**: Step A.7 이 없고, B-2 `question` 에 깊이 슬롯이 없으며, advisories 슬롯은 남아 있다.
- **AC6 (템플릿)**: audit 템플릿 §2 데이터 줄이 하나이고 `coverage-mapper <k>` placeholder 를 유지한다.
  `tests/test_audit_template_gate_shape.py` · `tests/test_check_brief.sh` GREEN.
- **AC7 (재조준)**: `test_finishing_block_scope.py` GREEN, 남는 펜스 하나에 앞 펜스 변수를 쓰는 변이에 RED.
  `test_brief_agents.sh` · `shared/tests/test_dispatch_disposition.sh` · `shared/tests/test_adjudication_wiring.sh`
  GREEN. `COMP_BASELINE` 리터럴이 `ast` 실측값과 **같다**(C7).
- **AC8 (무변경)**: `scripts/check_brief.py` · `hooks/*` · `skills/reviewing-brief/*` · `skills/reviewing-spec/*`
  의 diff 가 0 이다.
- **AC9 (버전)**: `plugin.json` 이 머지 시점 main 보다 한 major 위이고 CHANGELOG 최상단 헤딩과 같다. 그 절에
  Removed · Changed · Deprecated(C3 문구) · Verification 이 있다.
- **AC10 (회귀 0)**: C6 의 (파일, 실패 식별자) 멀티셋에서 «완료 − 기준선 = ∅» 이다 — 최종 커밋뿐 아니라 각 task
  커밋에서도(C1). merge 커밋 이후는 C6 의 새 기준선과 비교한다. 파일별 rc 와 실패 줄 수는 보조 기록이다.

## Files to Modify

```
plugins/spec-distill/.claude-plugin/plugin.json                         다음 major (C2)
plugins/spec-distill/CHANGELOG.md                                       최상단 절 (섹션 4)
plugins/spec-distill/README.md                                          7·22·36·108·136·145행
plugins/spec-distill/commands/interview.md                              46행
plugins/spec-distill/skills/conducting-interview/SKILL.md               도입부 · state 본문 문장 · 라운드 규약 · 되묻기 절 삭제 · C43 문장 · provisional_on · 닫힘 · 재개방 · blind-spot-prober 전이 문장
plugins/spec-distill/skills/conducting-interview/references/finishing.md    76행 · Step A.7 삭제 · B-2 깊이 슬롯
plugins/spec-distill/skills/conducting-interview/references/seed-input.md   11–12행
plugins/spec-distill/skills/conducting-interview/references/steelman.md     84–87행 삭제
plugins/spec-distill/skills/conducting-interview/references/state-migration.md  32행
plugins/spec-distill/skills/framing-requests/SKILL.md                   44·46행
plugins/spec-distill/templates/interview-audit-template.md              §2
plugins/spec-distill/templates/interview-seed-template.md               41행 (표 한 칸)
plugins/spec-distill/agents/depth-auditor.md                            삭제
plugins/spec-distill/scripts/depth_pairs.py                             삭제
plugins/spec-distill/scripts/depth_record.py                            삭제
plugins/spec-distill/tests/test_depth_pairs.py                          삭제
plugins/spec-distill/tests/test_depth_record.py                         삭제
plugins/spec-distill/tests/test_depth_auditor_frontmatter.sh            삭제
plugins/spec-distill/tests/fixtures/depth-state-*.md (11)               삭제
plugins/spec-distill/tests/test_conducting_interview_stage.sh           3.2
plugins/spec-distill/tests/test_finishing_block_scope.py                3.3
plugins/spec-distill/tests/test_brief_agents.sh                         3.3
plugins/spec-distill/tests/test_stale_terms.sh                          3.4 (별칭 축 · V10 목록 20 → 37)
plugins/spec-distill/tests/test_request_framing_command.sh              3.2 (seed 문단 소비 락 신설)
shared/tests/test_adjudication_wiring.sh                                3.3 (C7)
docs/superpowers/interview/depth/.gitkeep                               삭제
```

건드리지 않음: `scripts/check_brief.py` · `hooks/*` · `skills/reviewing-brief/*` · `skills/reviewing-spec/*` ·
`agents/coverage-mapper.md` · `agents/steelman-builder.md` · `agents/blind-spot-prober.md` · 0.57.0 설계문서 ·
과거 interview 문서.

## Verification Plan

- **V0 (자기 적용 스윕)**: 3.4 의 모든 부재 · 별칭 토큰을 production 전체(`CHANGELOG.md`·`tests/` 제외)에
  `git grep` 해 걸리는 파일이 전부 Files to Modify 안인지 대조한다 — 구현 착수 전 1회, 토큰이나 목록을 바꿀 때마다 1회, `origin/main` 을
  merge 한 뒤 1회.
- **V1 (기준선)**: 착수 전 C6 의 세 스위트를 돌려 (파일, 실패 식별자) 멀티셋(보조: 파일별 rc · 실패 줄 수)을 파일로
  남긴다. 수집기는 단언 없이 exit 1 하는 합성 셸 파일 하나로 양성 대조를 한 번 거친다 — 그 파일이 `(파일, rc=1)` 로
  잡히지 않으면 수집기가 고장 난 것이다.
- **V2 (스위트)**: 각 task 커밋과 완료 후 같은 세 스위트를 같은 방식으로 기록하고 멀티셋 차로 새 실패 0 을 판정한다
  (AC10). merge 커밋 이후는 C6 의 새 기준선(merge 한 `origin/main` 끝)과 비교한다. 특히 `test_conducting_interview_stage.sh` ·
  `test_stale_terms.sh` · `test_finishing_block_scope.py` · `test_brief_agents.sh` · `test_audit_template_gate_shape.py`
  · `test_check_brief.sh` · `shared/tests/test_dispatch_disposition.sh` · `shared/tests/test_adjudication_wiring.sh`.
- **V3 (변이)**: 새로 쓰거나 고친 락마다 통째 삭제 · 문구 반전 · 값 변경 변이로 RED 확인 후 복원(AC2 · AC4 · AC7).
  변이 전 커밋, `PYTHONDONTWRITEBYTECODE=1`.
- **V4 (삭제 확인)**: `git ls-files` 로 AC1, `git diff --stat origin/main -- <무변경 목록>` 으로 AC8.
- **V5 (잔존 스윕)**: 식별자만이 아니라 개념 별칭으로도 스윕한다 — `되비추`, `되비춘`, `판정자 투입`, `상충 줄`, `Q1`/`Q2`(OQ 제외),
  `질문 둘`, `A.7`, `depth/` 를 production 전체에서 `git grep`.
- **V6 (사람 e2e)**: 실행 여부는 plan 단계에서 사용자가 정한다. 실행하지 않으면 CHANGELOG Verification 에 «미실행»
  으로 적는다.
- **V7 (리뷰)**: 설계문서 — Stop 훅의 Law 2 분리 리뷰. 구현 — 리포 관례(subagent-driven + 브랜치 전체 리뷰).

## Rejected Alternatives

- **R1 — kill switch 로 끄기**: 요청이 제거다. 18개 파일과 락의 무게가 그대로 남는다.
- **R2 — depth-auditor 만 제거**: 형식 층 스크립트 · 종료 라벨 질문 · 원장이 남아 «번거로움»이 그대로다.
- **R3 — Step A.7 만 제거하고 라운드 형식 유지**: 사용자가 라운드 형식까지 제거를 골랐다(이유 3 «방향이 틀렸다»).
- **R4 — 0.53.1 4-block 원문 복원**: G7 부재 락을 뒤집어야 하고 `steelman.md` 의 4-block 과 같은 이름을 쓰는 두
  물건이 다시 생긴다. 새 형식은 그 내용과 거의 같아 얻는 것이 없다.
- **R5 — 고정 틀 없이 원칙만**: 라운드 기록 모양이 인터뷰마다 달라진다. 사용자가 틀을 남기는 쪽을 골랐다.
- **R6 — 되묻기까지 제거**: 원래 증상에 직접 닿는 유일한 지시이고 비용은 한 줄이다. 사용자가 남기기로 했다.
- **R7 — 두 단계(deprecate → 다음 minor 제거)**: PR 둘, 창 기간 동안 인터뷰가 계속 되비추기 · 라벨 질문을
  띄우거나 끄는 스위치를 새로 만들어야 한다. 대표 선례 3회가 major + 충돌 기록으로 처리했다.
- **R8 — minor 로 조용히 제거**: 규칙 위반을 기록 없이 하고, agent 제거는 이 리포의 SemVer 기준(major = breaking)에
  맞지 않는다.
- **R9 — S앵커 닫힘 게이트까지 제거**: 게이트는 depth 와 코드 결합이 없고 사용자가 남기는 범위를 골랐다.
- **R10 — 원래 증상의 대체 해법을 함께 설계**: 요청 범위는 제거다(NG1).

## Open Questions

- **OQ1**: 원래 증상 — 인터뷰가 «질문이 안 떠올라» 얕게 끝난다. 이 설계는 풀지 않는다. 남는 장치는 S앵커 게이트
  (이벤트 횟수만으로 닫는 것을 막음)와 되묻기 한 줄뿐이다. 다음 사이클의 몫.
- **OQ2**: «아무 S 나 인용해 닫는 것»을 보는 자리가 여전히 없다(0.57.0 설계 OQ6 그대로).
- **OQ3**: 판정자 투입 조건이 사라져 닫힘 거부권 에이전트를 언제 들일지 알려 주는 신호가 없다. OQ1 사이클이
  필요하면 새 신호를 정한다.

## Concrete Next Action

다음 단계: Stop 훅의 설계문서 리뷰(Law 2 분리) → 리뷰 통과 뒤 이 문서 커밋 → 사용자 리뷰 →
`superpowers:writing-plans`.
- Spec 경로: `docs/superpowers/specs/2026-09-10-remove-depth-audit-design.md`
- Plan 산출물: `docs/superpowers/plans/2026-09-10-remove-depth-audit.md`
- plan 의 첫 task 는 V1(기준선), 둘째는 사람 e2e 여부 확인.
