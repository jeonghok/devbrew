# 이음매 채널 검증 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew 의 이음매 아홉 자리를 결함의 종류 다섯 묶음으로 고친다 — 모델용 지시를 모델이 읽는 채널로 보내고, 소비자 없는 약속·산출물을 지우고, 배포 단위 밖 선결조건을 없애고, 목적지 리터럴을 한 자리로 모으고, 다음 감사가 같은 질문을 하게 한다.

**Architecture:** 새 훅 0 · 새 검사층 0 · 새 추상 0. 순증은 셋뿐이다 — 훅 출력 필드 `hookSpecificOutput`(두 훅), `review-dispatch.py` 모듈 상수 하나, plugin-audit 축 3 의 질문 한 줄. 나머지는 전부 삭제이거나 분기 제거다. 삭제 자리는 이 계획이 §7.2.1 의 네 축으로 **도출**했고(아래 Task 0), 설계는 씨앗만 주었다.

**Tech Stack:** Python 3(훅·게이트 스크립트, `unittest`), bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), Node.js(plugin-audit `audit-workflow.js`), 마크다운 SKILL/command 문서.

**Spec:** `docs/superpowers/specs/2026-09-02-seam-channel-verification-design.md`

## 목차

- [Global Constraints](#global-constraints)
  - [완료 주장의 범위 (좁혀져 있다)](#완료-주장의-범위-좁혀져-있다)
- [이 계획이 소유한 결정 (설계가 미룬 것 D0~D6)](#이-계획이-소유한-결정-설계가-미룬-것-d0d6)
  - [D6 — 형제 겹침 도출 결과 (2026-09-03)](#d6--형제-겹침-도출-결과-2026-09-03)
- [File Structure](#file-structure)
- [Task 0: 착수 전 도출 — 형제 겹침 · baseline · 삭제 자리](#task-0-착수-전-도출--형제-겹침--baseline--삭제-자리)
- [Task 1: 묶음 1a — quality-gates 훅의 채널 분리](#task-1-묶음-1a--quality-gates-훅의-채널-분리)
- [Task 2: 묶음 1b — project-init 훅의 반환 계약 분리](#task-2-묶음-1b--project-init-훅의-반환-계약-분리)
- [Task 3: 묶음 2a — qg 발행 offer 와 sentinel 철회](#task-3-묶음-2a--qg-발행-offer-와-sentinel-철회)
- [Task 4: 묶음 2b — `/compact` 안내의 도착 주장 철회](#task-4-묶음-2b--compact-안내의-도착-주장-철회)
- [Task 5: 묶음 3a — 배포 단위 밖 선결조건 제거 + L 등식 락](#task-5-묶음-3a--배포-단위-밖-선결조건-제거--l-등식-락)
- [Task 6: 묶음 3b — `next_phase` 값 고정 해제](#task-6-묶음-3b--next_phase-값-고정-해제)
- [Task 7: 묶음 4a — 핸드오프 인자를 넷으로](#task-7-묶음-4a--핸드오프-인자를-넷으로)
- [Task 8: 묶음 4b — 목적지 이름을 한 자리로](#task-8-묶음-4b--목적지-이름을-한-자리로)
- [Task 9: 묶음 5 — 다음 감사가 같은 질문을 하게 한다](#task-9-묶음-5--다음-감사가-같은-질문을-하게-한다)
- [Task 10: 버전 bump · CHANGELOG · README](#task-10-버전-bump--changelog--readme)
- [Self-Review — 설계 대조 결과](#self-review--설계-대조-결과)
- [이월 (설계 §11 에서 그대로 따라온다)](#이월-설계-11-에서-그대로-따라온다)
- [착수 전 한 번 더 읽을 것](#착수-전-한-번-더-읽을-것)

---

## Global Constraints

이 절의 값은 설계에서 **그대로** 옮긴 것이다. 모든 Task 의 요구사항에 암묵적으로 포함된다.

| # | 제약 | 출처 |
|---|---|---|
| G1 | 작업 위치는 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+seam-channel-verification`, 브랜치 `feature/seam-channel-verification`, base `094ecbc`. **`cd` 로 메인 리포로 나가지 않는다.** | 설계 Handoff |
| G2 | **N1 (채널)** — 모델에게 하는 말은 `hookSpecificOutput.additionalContext`, 사람에게 하는 말은 `systemMessage`. 한 훅이 둘 다 할 말이 있으면 **둘 다 낸다.** «옮기기» 는 교정이 아니다 | 설계 §1.4 |
| G3 | **N2 (소비자)** — 아무도 읽지 않는 파일을 쓰지 않는다. 소비자가 사라지면 생산도 사라진다 | 설계 §1.4 |
| G4 | **N3 (배포 경계)** — 플러그인 코드는 자기 배포 단위 밖의 파일을 **실행 시점 선결조건**으로 읽지 않는다. 근거 기록으로서의 참조는 허용 | 설계 §1.4 |
| G5 | **N4 (리터럴)** — 강제기의 **목적지 이름**만 한 자리에서 온다. **경로 접두는 대상이 아니다**(범위 밖) | 설계 §1.4 |
| G6 | **N5 (전수)** — 격리 검사는 집합 등식 하나: `agents/*.md` 중 `tools: []` 인 파일 집합 **==** 리터럴 이름 목록 `{brief-critic, brief-readback, seed-critic, seed-readback}`. **선택자를 술어와 같은 값으로 두지 않는다** | 설계 §1.4 · §4.2 |
| G7 | **N6 (삭제의 도출)** — 삭제 자리는 §7.2.1 네 축(**A** 식별자 전수 · **B** 개념 별칭 · **C** 의존 폐포 · **D** 생산자↔소비자 양방향)으로 도출한다. Task 0 의 도출 결과가 정본이고, 각 Task 의 목록은 그 결과의 사본이다 | 설계 §1.4 · §7.2.1 |
| G8 | **부재 락은 만들지 않는다.** 모든 단언은 **양성 증인**(그 경로가 실제로 돌았다는 증거)을 먼저 확인한 뒤 부재를 확인한다 | 설계 §7.2.2 · §7.2.4 |
| G9 | **「기존 스위트가 깨지지 않는 것」은 오라클이 아니다.** 이 변경은 기존 락이 **깨지기를 요구**한다. Task 0 의 baseline 파일이 「예상된 RED」와 **선재 RED** 를 가른다 | 설계 §7.2.3 |
| G10 | **범위 밖 파일 넷 — 절대 건드리지 않는다:** `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` · `plugins/quality-gates/scripts/qg-gc.py` · `plugins/spec-distill/scripts/hook_common.py` · `plugins/spec-distill/scripts/arm_ledger.py`. 앞 둘은 형제 계획이 **정반대를 지시**하고(그쪽 `:784` 「`publish-eligible.md` 는 유지」), 뒤 둘은 형제가 같은 import 구조를 재구성 중이다 | 설계 §3.1 · §5.2 · 사용자 결정 2026-09-03 |
| G11 | **통지 규약** — 형제와 겹치는 파일을 **편집하기 직전에** 무엇을 어떻게 바꾸는지 한 줄을 사용자에게 보고하고, **답을 기다리지 않고 진행**한다. 머지는 rebase 가 아니라 **merge**, 먼저 끝난 쪽을 다른 쪽이 따라간다 | 설계 §7.3 · 사용자 결정 |
| G12 | **버전 bump** — `quality-gates` **major**(5.1.0 → 6.0.0), `spec-distill` minor(0.47.0 → 0.48.0), `project-init` minor(3.0.0 → 3.1.0), `plugin-audit` minor(0.6.4 → 0.7.0). 네 플러그인 전부 **같은 커밋**에서 `plugin.json` + `CHANGELOG.md`(Task 10) | 설계 §8 |
| G13 | **deprecation window 없이 major 제거.** 근거를 CHANGELOG 에 명시: 대체 경로 `/qg-publish` 가 이미 출하돼 동일 기능을 제공하고, 사라지는 것은 자동 «제안» 뿐이다. **`project-init` v2.2.0 전례는 인용하지 않는다** | 설계 §3.1 |
| G14 | **kill switch `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` 는 유지.** 최내부 네트워크 sink 둘(`scripts/comment-upsert.py:77` · `scripts/pr-create.sh:17`)이 진짜 집행이고 범위 밖이다. 사라지는 것은 offer 계층의 **중복 확인 한 겹**뿐 | 설계 §3.1 |
| G15 | **`publish-active.md` 는 유지.** `publish-eligible.md` 와 이름이 비슷하지만 생산자(`publishing-pr-understanding/SKILL.md:206`)와 소비자(`quality-gates/hooks/post-tool-use.py:62-68`)가 둘 다 살아 있다. **삭제 대상이 아니다** | 설계 §3.1 |
| G16 | **`docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` 는 지우지 않는다.** 그것은 `tools: []` 집행의 근거 기록이다. 지우는 것은 **실행 시점에 그 파일을 읽는 코드**다 | 설계 §4.1 |
| G17 | 변이(mutation) 검증 전에 **반드시 커밋**한다. `git checkout --` 는 «내 마지막 변이» 가 아니라 HEAD 로 되돌린다. 모든 변이는 `PYTHONDONTWRITEBYTECODE=1` 로 돌린다(같은 길이 변이가 stale `.pyc` 를 못 넘는다) | 리포 실측 |
| G18 | **커밋 메시지 규약** — Conventional Commits. 말미에 두 줄: `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` / `Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn` | CLAUDE.md · 세션 지시 |

### 완료 주장의 범위 (좁혀져 있다)

아홉 자리 중 **여덟**이 검증 가능한 처방(mutation 락 또는 행동 테스트)을 갖는다. **자리 ④의 `/compact` 자리표시자 치환 한 조각만 검사 없이 남는다** — 그 자리를 읽는 훅이 리포에 없기 때문이다(설계 OQ-J). 이 계획은 그 조각을 «완료» 로 세지 않는다.

---

## 이 계획이 소유한 결정 (설계가 미룬 것 D0~D6)

설계는 일곱 가지를 계획으로 미뤘다. 여기서 전부 닫는다.

| # | 결정 | 답 |
|---|---|---|
| **D0** | 삭제 자리 전수 목록 | **Task 0 이 네 축을 돌려 도출했고 결과가 각 Task 의 Files 블록이다.** Task 0 은 착수 시점에 같은 스윕을 다시 돌려 **드리프트**를 잡는다(값이 달라지면 멈추고 보고) |
| **D1** | 커밋·PR 분해 | **PR 하나 · Task 당 커밋 하나**(총 11). 다섯 묶음이 같은 불변식 집합(N1~N6)을 공유해 따로 리뷰될 이유가 없고, 형제 겹침 통지가 PR 단위라 쪼개면 통지가 다섯 번 나간다 |
| **D2** | baseline 파일 경로·형식 | `<worktree>/.claude/seam-channel/baseline-2026-09-03.tsv` — `<파일경로>\t<rc>\t<PASS|FAIL>` 한 줄씩. `/.claude/*` 가 `.gitignore:219` 로 무시되므로 diff 를 오염시키지 않고 세션을 넘어 살아남는다 |
| **D3** | B1~B4 실행 방식 | B1 = **임시 리포 루트 복사**(격리 설치 불필요 — `docs/audits/` 를 빼고 복사하면 「설치본 밖 파일 부재」가 재현된다) · B2·B3 = 절 스코프 doc-lock · B4 = **순수 함수 단위 테스트**(`frontmatter_errors()`) — 픽스처 파일을 새로 만들지 않는다 |
| **D4** | `next_phase` 픽스처 쌍 | **파일 픽스처를 만들지 않는다.** `frontmatter_errors()` 가 순수 함수라 문자열 두 개로 충분하다: `next_phase` 없는 frontmatter(→ 그 축 오류 없음) · `type` 깨진 frontmatter(→ `type != interview-brief`). 파일 픽스처는 `interview-brief-*.md` 74건과 함께 드리프트하는 부채다 |
| **D5** | L 등식 락의 구현 형태 | **셸**, `test_brief_agents.sh` 안. 표기 변형은 형제 락 `test_seed_agents.sh:131` 을 물려받아 `[]` 와 `[ ]` 둘 다 허용. 다섯째 픽스처는 **임시 디렉토리**에 만든다(가짜 agent 를 출하하지 않는다) |
| **D6** | 형제 겹침 재도출 | **Task 0 이 도출했다** — 아래 표. 착수 시점에 다시 돌린다 |

### D6 — 형제 겹침 도출 결과 (2026-09-03)

`grep -n '^- Modify:' docs/superpowers/plans/*.md` 전수. 진행 중인 계획은 `2026-08-23-hook-write-path-bypass.md` **하나**다.

| 이 범위의 파일 | 형제 계획의 자리 | 종류 | 처분 |
|---|---|---|---|
| `plugins/quality-gates/commands/qg.md` | `:641` (그쪽 `:143-160` Scope 절 · `:124-128` 표) | **줄 충돌** | Task 3 편집 직전 통지 |
| `plugins/spec-distill/hooks/review-dispatch.py` | `:1446` · `:1698` | **줄 충돌** | Task 8 편집 직전 통지 |
| 네 `plugin.json` · `CHANGELOG.md` | `:377-378` · `:831` · `:1953-1954` | **줄 충돌**(버전 리터럴) | Task 10 통지. merge 시 양쪽 bump 를 합산 |
| `plugins/quality-gates/scripts/qg-gc.py` · `.../state-file-format.md` | `:761` · `:783-784` | **지시 충돌** | **범위 밖**(G10) |
| `plugins/spec-distill/scripts/arm_ledger.py` · `hook_common.py` | `:1228` · `:1698` | 구조 재구성 | **범위 밖**(G10) |

**설계가 답을 미룬 것 하나가 여기서 닫힌다 — `test_stale_terms.sh` 는 영향받지 않는다.** 그 락은 `plugins/spec-distill/` 아래 production 파일에서 `breadth-keeper` · `interview_round` · v0.23.0 권위 문법 6개 리터럴을 찾는다(`:1-25` 헤더 · `:26-28` 스코프). **`ZERO_TOOL_*` 토큰은 그 목록에 없고**, 삭제는 원리상 stale term 을 *추가*할 수 없다. 예상된 RED 목록에서 뺀다.

**설계 스냅샷에 없던 두 번째 형제 — 이미 머지됐다.** `2026-08-31-brief-restructure.md` 가 `reviewing-brief/SKILL.md:136`·`:337`, `finishing.md`, `check_brief.py`, `templates/interview-audit-template.md`, `test_reviewing_brief_skill.sh:315` 를 자기 Modify 목록에 올려 두었고 이는 이 범위와 정면으로 겹친다. 그러나 그 작업의 산출물(`scripts/section6.py` · `check_brief.py items` 서브커맨드 · audit 템플릿 `## 6.`)이 **base `094ecbc` 에 이미 존재**하므로 머지 완료로 판정한다. 겹침 아님. 착수 시 Task 0 이 이 판정을 재확인한다.

---

## File Structure

새로 만드는 파일은 **넷**이고 전부 테스트다. 프로덕션 파일은 전부 기존 파일의 편집이다.

### 새로 만드는 것

| 경로 | 책임 |
|---|---|
| `plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh` | **B1** — 배포 단위 밖 파일 없이도 brief 리뷰 격리 락이 도는가 (양성 증인 + 부재) |
| `plugins/spec-distill/tests/test_check_brief_frontmatter.py` | **B4 · MU10 · MU11** — `frontmatter_errors()` 순수 함수의 축별 판정 |
| `plugins/quality-gates/tests/test_qg_publish_handoff.sh` | **B2 · B3a · B3b** — 파이프라인 종료가 자동 offer 가 아니라 명시 안내로 끝나는가 |
| `plugins/plugin-audit/tests/test_axis3_reachability_question.sh` | **MU12** — 감사 축 3 이 도달 질문을 담는가 |

### 편집하는 프로덕션 파일

| 경로 | 무엇이 바뀌나 | Task |
|---|---|---|
| `plugins/quality-gates/hooks/post-tool-use.py` | `:84-92` 단일 `systemMessage` → 사람 몫 + 모델 몫 두 채널 | 1 |
| `plugins/project-init/hooks/post-tool-use.py` | `validate_branch`·`validate_commit` 반환 계약을 (사람, 모델) 쌍으로. `main()` 이 두 채널로 분배 | 2 |
| `plugins/quality-gates/commands/qg.md` | offer 절 삭제 → `/qg-publish` 안내 한 줄. 표의 자동 offer 행 삭제 | 3 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | sentinel 절·목차 항목·두 쓰기 지점 삭제 | 3 |
| `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` | R8 sentinel 쓰기 삭제 | 3 |
| `plugins/quality-gates/scripts/setup-qg.sh` | stale sentinel 청소 두 곳 삭제 | 3 |
| `plugins/spec-distill/skills/conducting-interview/references/finishing.md` | `:237` 안내 문구 · `:239` 자리표시자 · `:90`·`:95`·`:101`·`:104` 인자 넷 | 4·7 |
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | probe 선결조건 절 삭제 + `:62` 근거 문장 재서술 + `:500` 상호참조 정리 | 5 |
| `plugins/spec-distill/templates/interview-audit-template.md` | `:57` 격리 줄 삭제 | 5 |
| `plugins/spec-distill/scripts/check_brief.py` | `:909-910` `next_phase` 검사 삭제 | 6 |
| `plugins/spec-distill/hooks/review-dispatch.py` | 목적지 이름 리터럴 6곳 → 모듈 상수 + 보간 | 8 |
| `plugins/plugin-audit/scripts/audit-workflow.js` | 축 3 질문 목록에 도달 질문 한 항목 추가 | 9 |

### 편집하는 테스트 파일

| 경로 | 무엇이 바뀌나 | Task |
|---|---|---|
| `plugins/quality-gates/tests/test_qg_publish_offer.sh` | **삭제**(offer 소멸) | 3 |
| `plugins/quality-gates/tests/test_setup_qg.sh` | Case 7·8 (`:107-147`) 삭제 | 3 |
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | sentinel 배선 블록(`:538-620` 중 해당 구간) 삭제 | 3 |
| `plugins/spec-distill/tests/test_brief_agents.sh` | probe 종속(`:9`·`:17-25`·`:99-109`) 삭제 → **L 등식 락** | 5 |
| `plugins/spec-distill/tests/test_reviewing_brief_skill.sh` | 축 C 폐포(`$WFAIL`·`$WFAIL_BASH`·`$DEGRADE_RE`·`$WOK`) 삭제 | 5 |
| `plugins/spec-distill/tests/test_brief_review_state.py` | `:169-173` probe 실패 record 2건 전제 삭제 | 5 |
| `plugins/spec-distill/tests/test_brief_review_meta.sh` | `:109`·`:129` 결정론 검사 목록에서 `zero-tool probe` 항목 삭제 | 5 |
| `plugins/spec-distill/tests/test_brief_review_entry.sh` | `:172`·`:190` 세 변수 → **네 변수** | 7 |

---

### Task 0: 착수 전 도출 — 형제 겹침 · baseline · 삭제 자리

**Files:**
- Create: `.claude/seam-channel/baseline-2026-09-03.tsv` (git-ignored — `.gitignore:219` 이 `/.claude/*` 를 무시)
- Create: `.claude/seam-channel/derivation-2026-09-03.txt` (git-ignored)
- Read only: `docs/superpowers/plans/*.md`

**Interfaces:**
- Consumes: 없음 (첫 Task)
- Produces: `baseline-2026-09-03.tsv` — `<파일경로>\t<rc>\t<PASS|FAIL>` 한 줄씩. 이후 모든 Task 의 "테스트 실행" 단계가 이 파일과 대조해 **예상된 RED** 와 **선재 RED** 를 가른다. `derivation-2026-09-03.txt` — 네 축 스윕의 raw 출력.

**이 Task 가 커밋을 남기지 않는 이유:** 산출물 둘 다 git-ignored 다. 완료 판정은 두 파일이 비어 있지 않은 것.

- [ ] **Step 1: 워크트리·브랜치 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+seam-channel-verification
git rev-parse --abbrev-ref HEAD
git status --porcelain
mkdir -p .claude/seam-channel
```

기대: 브랜치가 `feature/seam-channel-verification`, 작업트리는 이 계획문서 외 깨끗함.

- [ ] **Step 2: 형제 겹침 재도출 (D6 드리프트 검사)**

```bash
grep -n '^- Modify:' docs/superpowers/plans/*.md > .claude/seam-channel/derivation-2026-09-03.txt
grep -c '' .claude/seam-channel/derivation-2026-09-03.txt
```

기대: 이 계획의 「D6 — 형제 겹침 도출 결과」 표와 **같은 파일 집합**. 새 파일이 나타나면 **멈추고 사용자에게 보고**한다 — 특히 `plugins/quality-gates/hooks/post-tool-use.py` · `plugins/project-init/hooks/post-tool-use.py` · `plugins/spec-distill/skills/reviewing-brief/SKILL.md` · `plugins/plugin-audit/scripts/audit-workflow.js` 넷 중 하나가 형제 목록에 새로 오르면 그 Task 의 처분이 바뀐다.

- [ ] **Step 3: 두 번째 형제(brief-restructure)가 머지됐음을 재확인**

```bash
test -f plugins/spec-distill/scripts/section6.py && echo "section6 present"
grep -c 'check_brief.py items' plugins/spec-distill/scripts/check_brief.py
grep -c '^## 6\. 사용자 원문' plugins/spec-distill/templates/interview-audit-template.md
```

기대: `section6 present` / `1` 이상 / `1`. 하나라도 0 이면 그 계획이 **진행 중**이라는 뜻이므로 멈추고 보고한다.

- [ ] **Step 4: baseline 캡처 — 네 플러그인 스위트**

이 리포에는 CI 가 없고 `main` 에 오래된 RED 가 있다. baseline 없이 시작하면 이후의 RED 가 내 것인지 원래 것인지 가릴 수 없다. **셸 변수 누산기는 `Bash` 도구가 호출마다 새 셸이라 구조적으로 깨진다** — 그래서 파일이다.

러너 스크립트를 만든다 (`.claude/seam-channel/run-baseline.sh`):

```bash
#!/usr/bin/env bash
# baseline 러너 — 네 플러그인의 셸/파이썬 테스트를 전부 돌려 rc 를 파일에 적는다.
# set -e 를 쓰지 않는다: 실패한 테스트에서 러너가 죽으면 나머지를 못 잰다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/.claude/seam-channel/baseline-2026-09-03.tsv"
: > "$OUT"
export PYTHONDONTWRITEBYTECODE=1
for p in quality-gates spec-distill project-init plugin-audit; do
  d="$ROOT/plugins/$p/tests"
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    ( cd "$ROOT" && bash "$f" ) >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then v=PASS; else v=FAIL; fi
    printf '%s\t%s\t%s\n' "${f#$ROOT/}" "$rc" "$v" >> "$OUT"
  done < <(find "$d" -maxdepth 2 -name 'test_*.sh' | sort)
  while IFS= read -r f; do
    ( cd "$ROOT" && python3 -m unittest discover -s "$(dirname "$f")" -p "$(basename "$f")" ) >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then v=PASS; else v=FAIL; fi
    printf '%s\t%s\t%s\n' "${f#$ROOT/}" "$rc" "$v" >> "$OUT"
  done < <(find "$d" -maxdepth 2 -name 'test_*.py' | sort)
done
printf 'TOTAL\t%s\tFAIL=%s\n' "$(grep -c '' "$OUT")" "$(grep -c 'FAIL$' "$OUT")" >> "$OUT"
```

실행과 확인:

```bash
bash .claude/seam-channel/run-baseline.sh
grep 'FAIL$' .claude/seam-channel/baseline-2026-09-03.tsv
tail -1 .claude/seam-channel/baseline-2026-09-03.tsv
```

기대: 파일이 비어 있지 않고 마지막 줄이 `TOTAL<TAB><n><TAB>FAIL=<m>`. **그 `m` 건이 선재 RED 다** — 이후 모든 Task 는 이 목록에 없는 RED 만 자기 것으로 센다. `m` 이 0 이면 그것도 기록한다(모든 이후 RED 가 내 것이라는 뜻).

- [ ] **Step 5: 삭제 자리 네 축 스윕 (D0)**

```bash
{
  echo "=== 축 A: publish-eligible 식별자 전수 ==="
  grep -rn 'publish-eligible' plugins/ shared/ 2>/dev/null
  echo "=== 축 A: ZERO_TOOL / zero-tool 식별자 전수 ==="
  grep -rn 'ZERO_TOOL\|zero-tool\|zero_tool' plugins/ shared/ 2>/dev/null
  echo "=== 축 A: next_phase 식별자 전수 ==="
  grep -rn 'next_phase' plugins/ shared/ 2>/dev/null
  echo "=== 축 B: 개념 별칭 (sentinel / companion / 표식) ==="
  grep -rn 'sentinel\|companion file\|표식 파일' plugins/quality-gates/ 2>/dev/null
  echo "=== 축 C: 의존 폐포 — 삭제 구간이 대입하는 변수 ==="
  grep -n 'BRS\|WFAIL\|DEGRADE_RE\|WOK' plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/tests/test_reviewing_brief_skill.sh
  echo "=== 축 D: 생산자 vs 소비자 — degrade 사슬 ==="
  grep -n 'degrade-append\|DEGRADE_FALLBACK_FILE\|brief_review_degradations' plugins/spec-distill/skills/reviewing-brief/SKILL.md
} >> .claude/seam-channel/derivation-2026-09-03.txt
grep -c '' .claude/seam-channel/derivation-2026-09-03.txt
```

**축 C 와 D 를 뺀 스윕은 스윕이 아니다.** 축 C 없이 자른 `set -u` 스크립트는 RED 가 아니라 **중단**되고(unbound variable), 그러면 Step 4 의 baseline 이 오라클로 기능하지 않는다. 축 D 없이 지운 생산자는 소비자를 영구히 «값 없음» 으로 만든다.

- [ ] **Step 6: 도출 결과를 이 계획의 Files 블록과 대조**

각 Task 의 `**Files:**` 목록이 Step 5 출력의 부분집합인지 확인한다. **Step 5 에 있는데 어느 Task 에도 없는 자리가 나오면 멈추고 보고**한다. 범위 밖으로 **의도한** 자리는 이것뿐이다:

| 자리 | 왜 남기나 |
|---|---|
| G10 의 네 파일 | 형제와 지시 충돌 / 구조 재구성 |
| `plugins/quality-gates/scripts/qg-gc.py:49` `SESSION_MARKERS` | G10 — 생산자 없는 참조로 **사문 잔존**이 의도된 상태(설계 OQ-N) |
| `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md:67` | 〃 |
| `plugins/quality-gates/tests/test_qg_gc.py:165-176` | 픽스처가 그 파일을 **손으로** 만들므로 GREEN 유지. 예상된 RED 아님 |
| `plugins/*/CHANGELOG.md` 의 과거 언급 | released 기록 — Keep-a-Changelog 불변 |

- [ ] **Step 7: 완료 확인 (커밋 없음)**

```bash
test -s .claude/seam-channel/baseline-2026-09-03.tsv && echo "baseline OK"
test -s .claude/seam-channel/derivation-2026-09-03.txt && echo "derivation OK"
git status --porcelain
```

기대: 두 `OK` 줄. `git status` 는 `.claude/` 가 무시되므로 이 계획문서 외 비어 있다.

---

### Task 1: 묶음 1a — quality-gates 훅의 채널 분리

**Files:**
- Modify: `plugins/quality-gates/hooks/post-tool-use.py:84-92`
- Test: `plugins/quality-gates/tests/test_hook_publish_suppression.py` (기존 파일에 클래스 추가)

**Interfaces:**
- Consumes: Task 0 의 `baseline-2026-09-03.tsv`
- Produces: 훅의 stdout JSON 이 **두 키**를 갖는다 — `systemMessage: str` + `hookSpecificOutput: {"hookEventName": "PostToolUse", "additionalContext": str}`. 기존 소비자(`test_kill_switches.py:304` · `test_hook_publish_suppression.py:40`)의 `systemMessage` 존재 단언은 그대로 참이다.

**형제 겹침:** 없음. D6 표 확인 — 형제 계획은 `plugins/quality-gates/hooks/hooks.json`(그쪽 `:435`)만 올려 두었고 이 `.py` 는 목록에 없다.

**왜 «옮기기» 가 아니라 «병행» 인가 (G2):** `MEAS-M6` 은 `additionalContext` 가 모델에 **도달함**만 쟀다. 「사람 채널로 보낸 것을 모델이 못 본다」는 반대 명제는 재지 않았다(설계 OQ-K). 옮기면 그 미측정 명제에 베팅하면서 사람 수신자를 확실히 잃는다. 병행이면 반대 명제가 거짓이어도 잃는 것이 없다.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`plugins/quality-gates/tests/test_hook_publish_suppression.py` 의 `PublishSuppression` 클래스 **아래에** 추가한다. (`run_hook(cwd)` 헬퍼는 그 파일 `:15-25` 에 이미 있고 `tool_response.stdout` 을 `https://github.com/o/r/pull/42` 로 준다.)

```python
class ChannelSplit(unittest.TestCase):
    """MU1·MU2 — 모델용 지시는 additionalContext, 사람용 사실은 systemMessage."""

    def test_model_instruction_goes_to_additional_context(self):
        with tempfile.TemporaryDirectory() as d:
            out = run_hook(d)
            hso = out.get("hookSpecificOutput", {})
            self.assertEqual(hso.get("hookEventName"), "PostToolUse")
            ac = hso.get("additionalContext", "")
            self.assertIn("setup-qg.sh", ac, "기동 명령이 모델 채널에 없다")
            self.assertIn("quality-gates:quality-pipeline", ac,
                          "skill 호출 지시가 모델 채널에 없다")

    def test_human_fact_stays_in_system_message(self):
        with tempfile.TemporaryDirectory() as d:
            sm = run_hook(d).get("systemMessage", "")
            self.assertIn("https://github.com/o/r/pull/42", sm,
                          "PR 사실이 사람 채널에 없다")

    def test_system_message_is_not_an_instruction_dump(self):
        """MU1 의 역방향: 기동 지시가 systemMessage 로 되돌아가면 RED."""
        with tempfile.TemporaryDirectory() as d:
            sm = run_hook(d).get("systemMessage", "")
            self.assertNotIn("setup-qg.sh", sm,
                             "기동 명령이 사람 채널에 남아 있다 — 채널이 갈리지 않았다")
```

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_hook_publish_suppression.py' -v`

Expected:
- `test_model_instruction_goes_to_additional_context` **FAIL** — `hookSpecificOutput` 키가 없어 `hookEventName` 이 `None`
- `test_system_message_is_not_an_instruction_dump` **FAIL** — `setup-qg.sh` 가 아직 `systemMessage` 안에 있다
- `test_human_fact_stays_in_system_message` **PASS** — 이것이 **양성 증인**이다(G8): 훅이 실제로 발화하고 그 경로가 살아 있음을 세 단언 중 하나가 미리 확인한다. 셋 다 FAIL 이면 훅이 아예 안 도는 것이므로 원인이 다르다.

- [ ] **Step 3: 최소 구현**

`plugins/quality-gates/hooks/post-tool-use.py` 의 `:84-92` 를 통째로 교체한다. 교체 전 원문:

```python
    result = {
        "systemMessage": (
            f"Quality Gates: PR created at {pr_url}. "
            "You MUST now initialize the quality-gates pipeline. "
            f'Run: Bash("{setup_script} --session-id {session_id} --pr-url {pr_url}") '
            "Then invoke Skill(\"quality-gates:quality-pipeline\") "
            "to begin the pipeline (Review gate → Runtime gate)."
        )
    }
```

교체 후:

```python
    # 채널 분리 (N1): 사람에게는 사실을, 모델에게는 지시를 — **둘 다** 낸다.
    # `systemMessage` 는 사용자 표시용이고, 모델 컨텍스트에 주입되는 필드는
    # `hookSpecificOutput.additionalContext` 다. 한쪽으로 옮기면 다른 쪽 수신자를
    # 잃는다 — 지시가 사람 채널에만 있으면 강제처럼 보이는 서술이 된다.
    result = {
        "systemMessage": f"Quality Gates: PR created at {pr_url}.",
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": (
                f"Quality Gates: a PR was created at {pr_url}. "
                "You MUST now initialize the quality-gates pipeline. "
                f'Run: Bash("{setup_script} --session-id {session_id} --pr-url {pr_url}") '
                'Then invoke Skill("quality-gates:quality-pipeline") '
                "to begin the pipeline (Review gate → Runtime gate)."
            ),
        },
    }
```

- [ ] **Step 4: 통과를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_hook_publish_suppression.py' -v`
Expected: 5 tests, 0 failures.

기존 소비자 회귀 확인 — 이 둘은 **GREEN 을 유지해야** 한다 (N1 병행의 직접 증거):

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_kill_switches.py'`
Expected: PASS. `:304` 의 `assertIn("systemMessage", proc.stdout)` 와 `:119` 의 kill-switch 하 `assertNotIn` 이 둘 다 여전히 참이다. RED 면 병행이 아니라 옮기기를 한 것이므로 Step 3 을 다시 본다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/hooks/post-tool-use.py plugins/quality-gates/tests/test_hook_publish_suppression.py
```

커밋 메시지 (파일로 쓴 뒤 `git commit -F`):

```
fix(quality-gates): 기동 지시를 모델 채널로, PR 사실은 사람 채널에 (묶음 1a)

훅이 "You MUST now initialize ..." 를 systemMessage 하나로 냈다. 그 필드는
번들 문서가 "Display a message to the user" 로 적은 사람 채널이고, 모델 컨텍스트
주입은 hookSpecificOutput.additionalContext 다. 강제처럼 보이는 자리가 실은
서술이었다.

옮기지 않고 둘 다 낸다. MEAS-M6 은 additionalContext 의 도달만 쟀고 "사람
채널로 보낸 것을 모델이 못 본다" 는 반대 명제는 재지 않았다 — 옮기면 그
미측정 명제에 베팅하면서 사람 수신자를 확실히 잃는다.

기존 락 둘(test_kill_switches.py:304 · test_hook_publish_suppression.py:40)이
systemMessage 존재를 sanity 로 단언하는데, 병행이라 그대로 GREEN 이다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

- [ ] **Step 6: 변이로 이빨을 확인한다 (MU1 · MU2)**

**커밋 뒤에 한다** — `git checkout --` 는 «내 마지막 변이» 가 아니라 HEAD 로 되돌리므로, 커밋 전에 변이하면 작업이 사라지고 복원 후 clean 이 성공처럼 보인다(G17).

| 변이 | 무엇을 한다 | 기대 |
|---|---|---|
| **MU1** | `additionalContext` 본문을 `systemMessage` 값으로 되돌리고 `hookSpecificOutput` 키를 지운다 | **RED** — `test_model_instruction_goes_to_additional_context` + `test_system_message_is_not_an_instruction_dump` |
| **MU2** | `"systemMessage": f"..."` 한 줄을 지운다 | **RED** — `test_human_fact_stays_in_system_message` + 기존 `test_no_sentinel_still_suggests`(`:40`) |

각 변이마다:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_hook_publish_suppression.py'
git checkout -- plugins/quality-gates/hooks/post-tool-use.py
git status --porcelain plugins/quality-gates
```

마지막 줄은 **반드시 비어야** 한다. 둘 중 하나라도 RED 를 못 내면 락에 이빨이 없는 것이다 — 멈추고 보고한다.

---

### Task 2: 묶음 1b — project-init 훅의 반환 계약 분리

**Files:**
- Modify: `plugins/project-init/hooks/post-tool-use.py` — `validate_branch`(`:111-149`) · `validate_commit`(`:152-181`) · `main()`(`:209-214`)
- Test: `plugins/project-init/tests/test_post_tool_use.py` (기존 파일에 클래스 추가)

**Interfaces:**
- Consumes: Task 0 의 baseline
- Produces: 두 validator 가 **평문 문자열 하나** 대신 **`(human, model)` 튜플**을 반환한다. 매치 없음은 여전히 `None`. `main()` 이 `human` 조각들만 `"\n\n".join(...)` 으로 `systemMessage` 에, `model` 조각이 하나라도 있으면 `hookSpecificOutput.additionalContext` 로 낸다.

**형제 겹침:** `plugins/project-init/tests/test_post_tool_use.py` 가 형제 계획 `:308` 에 올라 있다. **편집 직전에 한 줄 통지**(G11): *"project-init test_post_tool_use.py 에 ChannelSplit 클래스를 추가합니다 — 기존 클래스·단언은 건드리지 않습니다."* 훅의 `.py` 자체는 형제 목록에 없다.

**`:137` 한 줄만 고치면 채널이 갈리지 않는 이유:** 그 문자열은 여전히 `main()` `:212` 의 **단일 sink** 로 흘러간다. 반환 계약을 바꾸지 않으면 어느 조각이 사람 몫인지 `main()` 이 알 방법이 없다.

**`validate_commit` 은 왜 `systemMessage` 에 남는가 (MU4):** 두 검사의 **재진입성이 다르다.**

| 검사 | 제안하는 수정 | 자기 정규식에 재발동? |
|---|---|---|
| `validate_branch` | 브랜치 개명 (`git branch -m ...`) | **아니오** — `BRANCH_CREATE_RE`(`:32`)가 `git\s+(?:checkout\s+-b|switch\s+-c)` 뿐이라 개명 명령은 안 걸린다 |
| `validate_commit` | 커밋 메시지 재작성 | **예** — 고친 메시지로 다시 커밋하면 `COMMIT_MSG_RE`(`:33`)에 다시 걸린다 |

C16 은 새 강제에 폭주 방지를 요구하는데 이 설계는 새 가드를 만들지 않기로 했다. **비대칭을 숨기지 않고 적는 쪽**을 택한다. 이 결정 자체를 MU4 가 락으로 지킨다 — 다음 저자가 "대칭이 예쁘다"며 커밋 쪽도 옮기면 RED 다.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`plugins/project-init/tests/test_post_tool_use.py` 끝에 추가한다. (기존 헬퍼 `run_hook(payload, cwd=...)` 와 `write_strategy(tmp, regex)` 를 그대로 쓴다 — 각각 `:264`·`:297` 근처에서 이미 쓰이고 있다.)

```python
class ChannelSplit(unittest.TestCase):
    """MU3·MU4 — 브랜치 수정 명령은 모델 채널로, 커밋 경고는 사람 채널에 남는다."""

    def _branch_violation(self, tmp):
        write_strategy(tmp, r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$")
        payload = {"tool_name": "Bash",
                   "tool_input": {"command": "git checkout -b BadName"}}
        out, rc = run_hook(payload, cwd=tmp)
        self.assertEqual(rc, 0)
        return json.loads(out)

    def test_branch_fix_command_goes_to_model_channel(self):
        tmp = tempfile.mkdtemp()
        try:
            data = self._branch_violation(tmp)
            ac = data.get("hookSpecificOutput", {}).get("additionalContext", "")
            self.assertEqual(data.get("hookSpecificOutput", {}).get("hookEventName"),
                             "PostToolUse")
            self.assertIn("git branch -m", ac, "수정 명령이 모델 채널에 없다")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_branch_fact_and_hint_stay_human(self):
        """양성 증인 — 사람 채널이 여전히 사실과 기대 패턴을 싣는다."""
        tmp = tempfile.mkdtemp()
        try:
            data = self._branch_violation(tmp)
            sm = data.get("systemMessage", "")
            self.assertIn("does not follow naming convention", sm)
            self.assertIn("Expected pattern:", sm)
            self.assertIn("Allowed prefixes: feature, fix, release, hotfix", sm)
            self.assertNotIn("git branch -m", sm,
                             "수정 명령이 사람 채널에 남아 있다 — 채널이 갈리지 않았다")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_commit_warning_stays_in_system_message(self):
        """MU4 — 커밋 경고는 자기 정규식에 재발동하므로 모델 채널로 보내지 않는다."""
        tmp = tempfile.mkdtemp()
        try:
            write_strategy(tmp, r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
            payload = {"tool_name": "Bash",
                       "tool_input": {"command": 'git commit -m "add thing"'}}
            out, rc = run_hook(payload, cwd=tmp)
            data = json.loads(out)
            sm = data.get("systemMessage", "")
            self.assertIn("Conventional Commits", sm)
            self.assertIn("Suggested: feat: add thing", sm)
            ac = data.get("hookSpecificOutput", {}).get("additionalContext", "")
            self.assertNotIn("Conventional Commits", ac,
                             "커밋 경고가 모델 채널로 갔다 — 재진입 비대칭이 깨졌다")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_clean_command_emits_neither_channel(self):
        tmp = tempfile.mkdtemp()
        try:
            write_strategy(tmp, r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
            payload = {"tool_name": "Bash",
                       "tool_input": {"command": "git checkout -b feature/ok"}}
            out, rc = run_hook(payload, cwd=tmp)
            self.assertEqual(json.loads(out), {})
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
```

`shutil`·`tempfile`·`json` 은 그 파일이 이미 import 한다(`:1-20`). 없으면 추가한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/project-init/tests -p 'test_post_tool_use.py' -v`

Expected:
- `test_branch_fix_command_goes_to_model_channel` **FAIL** (`hookSpecificOutput` 부재)
- `test_branch_fact_and_hint_stay_human` **FAIL** (`git branch -m` 이 아직 `systemMessage` 안)
- `test_commit_warning_stays_in_system_message` **PASS** — **양성 증인**
- `test_clean_command_emits_neither_channel` **PASS** — 양성 증인

- [ ] **Step 3: 최소 구현 — 반환 계약**

`validate_branch` 의 반환을 셋 다 바꾼다. `:123-128`(fail-open advisory — **사람 몫**):

```python
    if pattern is None:  # 유효 패턴 없음(부재/regex-less/malformed/빈-블록/비-UTF-8) → fail OPEN, loudly
        return (
            "project-init: no valid branch-naming pattern found in "
            "docs/git-workflow/branch-strategy.md — skipping branch-name "
            "validation (fail-open).",
            None,  # 모델이 할 일이 없다 — 수정할 대상 자체가 없는 경고다
        )
```

`:142-149`(경고 본문) 을 교체한다:

```python
    lines = [
        f'project-init: Branch "{branch_name}" does not follow naming convention.',
        f"Expected pattern: {pattern.pattern}",
        hint,
    ]
    # 사람은 「무엇이 왜 틀렸나」를, 모델은 「무엇을 실행하나」를 받는다 (N1).
    # cmd 가 None 인 exotic-regex 경로에서는 모델 몫이 비고, main() 이
    # hookSpecificOutput 자체를 내지 않는다.
    return "\n".join(lines), cmd
```

`validate_commit` 은 반환 **형태만** 맞추고 모델 몫을 비운다. `:176-181` 을 교체:

```python
    # 모델 몫은 의도적으로 비어 있다. 이 제안(메시지 재작성)은 고친 메시지로
    # 다시 커밋하면 COMMIT_MSG_RE(:33)에 **재발동**한다 — 브랜치 개명과 달리
    # 구조적 상한이 없다. C16 이 새 강제에 폭주 방지를 요구하는데 이 설계는
    # 가드를 만들지 않기로 했으므로, 비대칭을 숨기지 않고 사람 채널에 남긴다.
    return (
        f"project-init: Commit message does not follow Conventional Commits format.\n"
        f"Expected: <type>(<scope>): <description>\n"
        f"Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\n"
        f"Suggested: {suggested_type}: {first_line}",
        None,
    )
```

`main()` `:207-214` 를 교체:

```python
    # Run BOTH validators (no short-circuit): a branch warning must not
    # suppress commit validation on compound commands (§5.5).
    results = [r for r in (validate_branch(command), validate_commit(command)) if r]
    human = [h for h, _m in results if h]
    model = [m for _h, m in results if m]

    out = {}
    if human:
        out["systemMessage"] = "\n\n".join(human)
    if model:
        # 모델이 읽는 채널 (N1). 사람 채널과 **함께** 나간다 — 어느 한쪽으로
        # 옮기면 다른 쪽 수신자를 잃는다.
        out["hookSpecificOutput"] = {
            "hookEventName": "PostToolUse",
            "additionalContext": "\n\n".join(model),
        }
    print(json.dumps(out))
```

- [ ] **Step 4: 통과를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/project-init/tests -p 'test_post_tool_use.py' -v`
Expected: 0 failures. **기존 단언 넷이 GREEN 을 유지해야 한다** — `:170`(`does not follow naming convention`) · `:264`(`Allowed prefixes: ...`) · `:290`(`fail-open`) · `:291`·`:309`(`Conventional Commits`). 넷 다 사람 몫에 남기 때문이다. 하나라도 RED 면 사람/모델 분배를 잘못한 것이다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/project-init/hooks/post-tool-use.py plugins/project-init/tests/test_post_tool_use.py
```

메시지:

```
fix(project-init): 브랜치 수정 명령을 모델 채널로 (묶음 1b)

두 validator 가 평문 문자열 하나를 반환하고 main() 이 단일 systemMessage 로
합쳐 냈다. :137 의 수정 명령만 고쳐서는 채널이 갈리지 않는다 — 그 문자열이
여전히 :212 의 같은 sink 로 흘러간다. 반환을 (사람, 모델) 쌍으로 바꿨다.

커밋 경고는 사람 채널에 남긴다. 그 제안은 고친 메시지로 다시 커밋하면
COMMIT_MSG_RE 에 재발동하는데(브랜치 개명은 BRANCH_CREATE_RE 에 안 걸린다),
상한을 만들려면 새 가드가 필요하고 이 설계는 가드를 만들지 않는다. 비대칭을
숨기지 않고 락으로 고정한다.

기존 단언 넷(:170 · :264 · :290 · :309)은 전부 사람 몫이라 GREEN 을 유지한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

- [ ] **Step 6: 변이로 이빨을 확인한다 (MU3 · MU4)**

| 변이 | 무엇을 한다 | 기대 |
|---|---|---|
| **MU3a** | `validate_branch` 의 `return "\n".join(lines), cmd` 를 `return "\n".join(lines + ([cmd] if cmd else [])), None` 로 되돌린다 | **RED** — `test_branch_fix_command_goes_to_model_channel` + `test_branch_fact_and_hint_stay_human` |
| **MU3b** | `main()` 에서 `out["systemMessage"] = ...` 두 줄을 지운다 | **RED** — `test_branch_fact_and_hint_stay_human` + 기존 `:290`·`:309` |
| **MU4** | `validate_commit` 의 `return (..., None)` 을 `return (None, ...)` 로 뒤집는다(커밋 경고를 모델 채널로) | **RED** — `test_commit_warning_stays_in_system_message` |

각 변이마다:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/project-init/tests -p 'test_post_tool_use.py'
git checkout -- plugins/project-init/hooks/post-tool-use.py
git status --porcelain plugins/project-init
```

셋 다 RED 를 내야 한다. MU4 가 GREEN 이면 재진입 비대칭이 락에 잡히지 않는 것이고, 그러면 §2.2 의 결정이 문서에만 있고 코드에는 없다.

---

### Task 3: 묶음 2a — qg 발행 offer 와 sentinel 철회

**Files:**
- Modify: `plugins/quality-gates/commands/qg.md` — offer 절(`### After the pipeline: publish offer`, 현재 `:73-117`) 삭제 → 안내 한 줄. Quick Reference 표의 자동 offer 행(현재 `:138`) 삭제
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — 목차 항목(`:93`) · Preflight stale 청소 서술(`:143-147`) · sentinel 절(`## Publish-eligible sentinel`, `:900-923`) · Final Summary 쓰기 지점(`:941-947`)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md:1197-1204` — R8 sentinel 쓰기 절
- Modify: `plugins/quality-gates/scripts/setup-qg.sh` — `:17-18` 주석 · `:37-38` global-kill 청소 · `:169-179` stale 청소
- Delete: `plugins/quality-gates/tests/test_qg_publish_offer.sh`
- Modify: `plugins/quality-gates/tests/test_setup_qg.sh:107-147` (Case 7·8 삭제)
- Modify: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh:538-620` (sentinel 배선 블록 삭제)
- Create: `plugins/quality-gates/tests/test_qg_publish_handoff.sh` (**B2**)
- **건드리지 않는다:** `plugins/quality-gates/scripts/qg-gc.py` · `.../references/state-file-format.md` · `plugins/quality-gates/tests/test_qg_gc.py` (G10 · 설계 OQ-N)

**Interfaces:**
- Consumes: Task 0 의 baseline · derivation 축 A(`publish-eligible`)·축 B(`sentinel`)
- Produces: `.claude/quality-gates/<sid>/publish-eligible.md` 를 **쓰는 코드가 0**, **읽는 코드가 0**. `/qg` 종료는 `### After the pipeline` 절에서 `/qg-publish` 안내 한 줄로 끝난다.

**형제 겹침 — 편집 직전 통지 (G11):** `plugins/quality-gates/commands/qg.md` 가 형제 계획 `:641`(그쪽 `:143-160` Scope 절 · `:124-128` 표)에 올라 있다. 통지 문면: *"qg.md 의 offer 절(`### After the pipeline: publish offer`)을 삭제하고 안내 한 줄로 대체합니다. Quick Reference 표에서 자동 offer 행 하나를 지웁니다. Scope 절은 건드리지 않습니다."*

**왜 sentinel 도 함께 지우나 (G3/N2):** `publish-eligible.md` 를 **쓰는 곳이 둘**(Final Summary · Runtime R8), **읽는 곳이 하나**(offer). 읽는 하나가 offer 이므로 offer 를 지우면 소비자가 0 이 된다 → 생산도 지운다. 아무도 읽지 않는 파일을 계속 쓰는 것이 Law 3 이 이름 붙인 theater 다.

**혼동 금지 — 표식이 둘이다:**

| 표식 | 생산자 | 소비자 | 처분 |
|---|---|---|---|
| `publish-eligible.md` | Final Summary · Runtime R8 | offer 하나 | **삭제** |
| `publish-active.md` | `publishing-pr-understanding/SKILL.md:206` | **qg 훅 자신**(`hooks/post-tool-use.py:62-68`) | **유지** (G15) |

**kill switch 는 사라지지 않는다 (G14).** `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` 의 진짜 집행은 최내부 네트워크 sink 둘(`scripts/comment-upsert.py:77` PATCH/POST 차단 · `scripts/pr-create.sh:17` push+`gh pr create` 차단)이고 둘 다 범위 밖이다. 사라지는 것은 offer 계층의 중복 확인 한 겹(`qg.md:83`·`:89`)과 그 락(`test_qg_publish_offer.sh:34`)뿐이다. `test_pr_create.sh` · `test_publish_kill_switch.py` · `test_qg_publish_docs.sh` 는 전부 유지.

- [ ] **Step 1: 형제 통지를 보낸다** (G11 — 답을 기다리지 않는다)

- [ ] **Step 2: 실패하는 테스트를 먼저 쓴다 — B2**

`plugins/quality-gates/tests/test_qg_publish_handoff.sh` 를 새로 만든다:

```bash
#!/usr/bin/env bash
# B2 — 파이프라인 종료가 자동 offer 가 아니라 명시 안내로 끝나는가.
#
# 양성 증인을 먼저 세운다: 종료 절이 **존재**하고 그 안에 /qg-publish 안내가
# 있는가. 그다음에야 부재를 묻는다. 부재만 보는 단언은 절을 통째로 지워도
# 통과하므로 스위트의 GREEN 을 완료로 오독하게 만든다.
#
# 술어를 절 스코프로 앵커하는 이유: qg.md 에는 삭제 대상과 무관한
# AskUserQuestion 이 여럿 남는다. 파일 전역으로 읽으면 영구 실패하고, 삭제된
# 구간으로 읽으면 그 구간이 사라졌으므로 공허참이다. **남는 절**을 앵커로 잡아야
# 둘 다 피한다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CMD="$PLUGIN_ROOT/commands/qg.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
test -f "$CMD" || { echo "FAIL: command missing at $CMD"; exit 1; }

# 남는 절을 앵커로 잡는다 — 헤딩부터 다음 '##'/'###' 헤딩 앞까지.
WIN="$(awk '/^### After the pipeline/{f=1;print;next} f&&/^#{2,3} /{exit} f{print}' "$CMD")"

# (1) 양성 증인 — 그 절이 실재한다 (비어 있으면 절이 통째로 사라진 것).
[ -n "$WIN" ] && ok "종료 절이 실재한다 (앵커 유효)" \
  || no "종료 절이 없다 — 앵커가 죽었다. 부재 단언이 공허참이 된다"

# (2) 양성 증인 — 그 절이 /qg-publish 안내를 담는다.
grep -qF '/qg-publish' <<<"$WIN" \
  && ok "종료 절이 /qg-publish 안내를 담는다" \
  || no "종료 절에 /qg-publish 안내가 없다 — 대체 경로가 사라졌다"

# (3) 부재 — 그 절 안에 자동 offer 가 없다.
grep -qF 'AskUserQuestion' <<<"$WIN" \
  && no "종료 절에 AskUserQuestion 이 남아 있다 — 자동 offer 가 철회되지 않았다" \
  || ok "종료 절에 AskUserQuestion 없음 (자동 offer 철회됨)"

# (4) 부재 — 그 절이 sentinel 을 읽지 않는다.
grep -qF 'publish-eligible' <<<"$WIN" \
  && no "종료 절이 여전히 publish-eligible sentinel 을 읽는다" \
  || ok "종료 절이 sentinel 을 읽지 않음 (소비자 0)"

# (5) B3a/B3b — 생산자 둘이 각자 사라졌는가. 양성 증인을 각 경로마다 따로 세운다:
#     한 테스트로 묶으면 한쪽만 지워도 통과한다.
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
RG="$PLUGIN_ROOT/skills/quality-pipeline/references/runtime-gate.md"

FS="$(awk '/^## Final Summary/{f=1;print;next} f&&/^## /{exit} f{print}' "$SKILL")"
grep -qF 'render-terminal.py table' <<<"$FS" \
  && ok "B3a 양성 증인: Final Summary 절이 자기 고유 산출물(표 렌더)을 담는다" \
  || no "B3a 앵커 죽음 — Final Summary 절을 못 찾았다"
grep -qF 'publish-eligible' <<<"$FS" \
  && no "B3a: Final Summary 가 여전히 sentinel 을 쓴다" \
  || ok "B3a: Final Summary 가 sentinel 을 쓰지 않음"

R8="$(awk '/^\*\*Step R8/{f=1} f{print} f&&/^\*\*Step R9/{exit}' "$RG")"
grep -qF 'Step R9' <<<"$R8" \
  && ok "B3b 양성 증인: R8 창이 R9 경계까지 실재한다" \
  || no "B3b 앵커 죽음 — R8 창을 못 찾았다"
grep -qF 'publish-eligible' <<<"$R8" \
  && no "B3b: Runtime R8 이 여전히 sentinel 을 쓴다" \
  || ok "B3b: Runtime R8 이 sentinel 을 쓰지 않음"

# (6) publish-active.md 는 **유지**다 — 이 테스트가 엉뚱한 표식을 지우게 만들지
#     않도록 그 생산자·소비자가 살아 있음을 양성으로 확인한다.
grep -qF 'publish-active.md' "$PLUGIN_ROOT/hooks/post-tool-use.py" \
  && ok "publish-active.md 소비자 생존 (지우면 안 되는 쪽)" \
  || no "publish-active.md 소비자가 사라졌다 — 엉뚱한 표식을 지웠다"
grep -qF 'publish-active.md' "$PLUGIN_ROOT/skills/publishing-pr-understanding/SKILL.md" \
  && ok "publish-active.md 생산자 생존" \
  || no "publish-active.md 생산자가 사라졌다 — 엉뚱한 표식을 지웠다"
finish
```

- [ ] **Step 3: 실패를 확인한다**

Run: `bash plugins/quality-gates/tests/test_qg_publish_handoff.sh`

Expected: 단언 (1)(2)(5-양성×2)(6×2) **PASS** — 이것들이 양성 증인이다. 단언 (3)(4)(5-부재×2) **FAIL** — offer 와 sentinel 이 아직 있다. 즉 **4 FAIL / 6 PASS**. 양성이 하나라도 FAIL 이면 앵커가 잘못된 것이므로 Step 2 로 돌아간다.

- [ ] **Step 4: offer 절을 삭제하고 안내 한 줄로 대체한다**

`plugins/quality-gates/commands/qg.md` 의 `### After the pipeline: publish offer` 헤딩부터 `### Quick Reference` 바로 앞까지(현재 `:73-117`)를 아래로 교체한다:

```markdown
### After the pipeline

파이프라인 스킬이 종료해 제어가 이 커맨드로 돌아오면 아래 한 줄을 출력하고
끝낸다. **자동 offer 를 띄우지 않는다** — 이어서 게시할지는 사용자가 다음 턴에
정한다.

> 이어서 PR 이해글을 게시하려면: `/qg-publish`
```

Quick Reference 표에서 자동 offer 행(현재 `:138`, `| (완료 후 자동) | 비중단 완료 시 …` 로 시작하는 줄) **한 줄을 삭제**한다. 바로 위의 `| `/qg-publish [--dry-run]` |` 행은 **남긴다**.

- [ ] **Step 5: sentinel 생산자 둘과 그 서술을 삭제한다**

| 파일 | 무엇을 지우나 |
|---|---|
| `SKILL.md:93` | 목차의 `- [Publish-eligible sentinel](#publish-eligible-sentinel) — …` 한 줄 |
| `SKILL.md:143-147` | `setup-qg.sh --ensure`는 또한 …` 문단 전체 (stale 청소 서술) |
| `SKILL.md:900-923` | `## Publish-eligible sentinel` 절 전체 (다음 헤딩 `## Final Summary` 앞까지) |
| `SKILL.md:941-947` | `**Publish-eligible sentinel (non-aborted completion only).**` 문단 전체 |
| `runtime-gate.md:1197-1204` | `**Publish-eligible sentinel (single-gate …)**` 문단 전체 (`**Step R9 …` 앞까지) |

**절 경계를 줄 번호로만 믿지 않는다.** 각 삭제 전에 경계를 재확인한다:

```bash
grep -n '^## \|^### ' plugins/quality-gates/skills/quality-pipeline/SKILL.md | sed -n '/Publish-eligible/,+1p'
grep -n '^\*\*Step R9' plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md
```

`SKILL.md:944-945` 의 앵커 링크 `[Publish-eligible sentinel](#publish-eligible-sentinel)` 가 문단과 함께 사라지므로 **깨진 앵커가 남지 않는다.** 삭제 후 확인:

```bash
grep -n 'publish-eligible-sentinel' plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md
```
기대: 출력 없음.

- [ ] **Step 6: stale 청소 코드를 삭제한다**

`plugins/quality-gates/scripts/setup-qg.sh`:
- `:17-18` 의 설명 주석 두 줄 삭제
- `:37-38` 의 `rm -f ".claude/quality-gates/$_kill_sid/publish-eligible.md" \` + 뒤따르는 `|| echo "[quality-gates] WARN: …" >&2` 삭제. **global-kill early-exit 자체는 남긴다** — 그것이 kill switch 다(G14)
- `:169-179` 의 `# --- Stale publish-eligible sentinel cleanup (v2.10.0) ---` 주석 블록과 `rm -f ".claude/quality-gates/$SESSION_ID/publish-eligible.md"` 삭제

삭제 후 문법 검사 (셸 본문 추출기는 조용히 깨진다 — 먼저 파싱한다):

```bash
bash -n plugins/quality-gates/scripts/setup-qg.sh && echo "syntax OK"
grep -n 'publish-eligible' plugins/quality-gates/scripts/setup-qg.sh
```
기대: `syntax OK`, 두 번째는 출력 없음.

- [ ] **Step 7: 락 셋을 정리한다 (예상된 RED)**

```bash
git rm plugins/quality-gates/tests/test_qg_publish_offer.sh
```

`plugins/quality-gates/tests/test_setup_qg.sh` — `# --- Case 7:` (`:107`) 부터 `# --- Case 9` 또는 파일 끝 직전까지, 즉 Case 7·8 (`:107-147`) 을 삭제한다. 경계 확인:

```bash
grep -n '^# --- Case' plugins/quality-gates/tests/test_setup_qg.sh
```
Case 7 시작 줄과 **그다음 Case 시작 줄**(있으면) 사이만 지운다. 지운 뒤 `bash -n` 으로 파싱을 확인하고, 남은 Case 들이 쓰는 변수(`$SID_DIR` 등)가 여전히 대입되는지 축 C 로 확인한다:

```bash
bash -n plugins/quality-gates/tests/test_setup_qg.sh && echo "syntax OK"
grep -n 'SID_DIR' plugins/quality-gates/tests/test_setup_qg.sh
```

`plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` — `:538` `# --- v2.10.0 publish-eligible sentinel wiring ---` 부터 그 블록 끝까지, 그리고 `:619` 의 `'publish-eligible.md'  # publish sentinel` **한 줄**(배열 원소)을 삭제한다. 이 파일은 `fs_start`·`fs_end`·`r8_start`·`r8_end` 변수를 그 블록 안에서 대입하고 소비하므로 **축 C 폐포로 함께 지운다**:

```bash
grep -n 'fs_start\|fs_end\|r8_start\|r8_end' plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
bash -n plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh && echo "syntax OK"
```

폐포 밖에서 그 변수를 쓰는 자리가 있으면 그 자리도 함께 처리한다 — **`set -u` 스크립트에서 폐포를 안 지키면 RED 가 아니라 중단**이고, 중단은 baseline 대조를 무력화한다.

- [ ] **Step 8: 통과를 확인한다**

```bash
bash plugins/quality-gates/tests/test_qg_publish_handoff.sh
bash plugins/quality-gates/tests/test_setup_qg.sh
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_qg_gc.py'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_publish_kill_switch.py'
bash plugins/quality-gates/tests/test_qg_publish_docs.sh
```

Expected: 전부 PASS.
- `test_qg_publish_handoff.sh` — 10/10
- `test_qg_gc.py` **GREEN 유지** — `:165-176` 픽스처가 `publish-eligible.md` 를 **손으로** 만들므로 생산자 삭제와 무관하다. 여기가 RED 면 `qg-gc.py` 를 잘못 건드린 것(G10 위반)
- `test_publish_kill_switch.py` · `test_qg_publish_docs.sh` **GREEN 유지** — kill switch 의 진짜 집행은 그대로다(G14)

**baseline 대조:** 새로 RED 가 된 파일이 있으면 `.claude/seam-channel/baseline-2026-09-03.tsv` 에서 그 줄을 찾는다. `FAIL` 이었으면 선재 RED(내 것 아님), `PASS` 였으면 내가 깬 것이다.

- [ ] **Step 9: 커밋**

```bash
git add -u plugins/quality-gates
git add plugins/quality-gates/tests/test_qg_publish_handoff.sh
```

(`git add -A` 는 쓰지 않는다 — 범위 밖 파일을 쓸어담는다.) 메시지:

```
feat(quality-gates)!: 자동 발행 offer 와 그 sentinel 을 철회 (묶음 2)

publish-eligible.md 를 쓰는 곳이 둘, 읽는 곳이 하나였고 그 하나가 offer 였다.
offer 를 지우면 소비자가 0 이 되므로 생산도 지운다 — 아무도 읽지 않는 파일을
계속 쓰는 것이 Law 3 이 이름 붙인 theater 다.

BREAKING CHANGE: 파이프라인 비중단 완료 시 뜨던 "PR 이해글 이어서 게시?"
AskUserQuestion 이 사라진다. 대체 경로는 /qg-publish 이고 이미 출하돼 있다.

deprecation window 없이 제거하는 근거: 창이 보호하는 대상은 "작동 중인 동작을
잃고 대안이 없는 사용자" 인데, 대체 경로가 선출하돼 있고 사라지는 것은 자동
「제안」 뿐이라 그런 사용자가 존재하지 않는다.

kill switch DEVBREW_QUALITY_GATES_DISABLE_PUBLISH 는 사라지지 않는다. 진짜
집행은 최내부 sink 둘(comment-upsert.py:77 · pr-create.sh:17)이고 범위 밖이다.
사라지는 것은 offer 계층의 중복 확인 한 겹뿐이다.

publish-active.md 는 유지다 — 이름이 비슷하지만 생산자와 소비자가 둘 다 살아
있고 /qg-publish 가 만든 PR 에 파이프라인이 되따라붙는 것을 막는다.

qg-gc.py 의 SESSION_MARKERS 와 state-file-format.md:67 은 형제 작업이 정반대를
지시해 범위 밖으로 뺐다 — 생산자 없는 참조로 사문 잔존한다(의도된 상태).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

- [ ] **Step 10: 변이로 이빨을 확인한다**

| 변이 | 무엇을 한다 | 기대 |
|---|---|---|
| **V3-1** | `qg.md` 의 `### After the pipeline` 절 안에 `AskUserQuestion({...})` 한 줄을 되살린다 | **RED** — 단언 (3) |
| **V3-2** | `SKILL.md` Final Summary 절에 `publish-eligible.md` 를 쓴다는 문장 한 줄을 되살린다 | **RED** — B3a 부재 |
| **V3-3** | `runtime-gate.md` R8 창에 같은 문장을 되살린다 | **RED** — B3b 부재 |
| **V3-4** | `qg.md` 의 `### After the pipeline` **헤딩을 개명**한다 | **RED** — 단언 (1)(2). 앵커가 죽으면 부재 단언이 공허참이 되는데, 양성 증인이 그것을 잡는다 |
| **V3-5** | `hooks/post-tool-use.py:62-68` 의 `publish-active.md` 블록을 지운다 | **RED** — 단언 (6). 엉뚱한 표식을 지우는 사고를 잡는다 |

**V3-2 와 V3-3 이 따로여야 한다** — 하나로 묶으면 한쪽만 지워도 통과한다. 각 변이 후 `git checkout -- <file>` 하고 `git status --porcelain plugins/quality-gates` 가 비는지 확인한다.

---

### Task 4: 묶음 2b — `/compact` 안내의 도착 주장 철회

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md:237` (안내 문구) · `:239` (`<brief-path>` ×2)
- Test: 없음 (**아래 「이 Task 에 락이 없는 이유」 참조**)

**Interfaces:**
- Consumes: 없음
- Produces: `finishing.md` 옵션 ① 의 안내가 「준비됨」이라는 상태 주장 대신 **사람이 다음 턴에 무엇을 하는지**를 적는다.

**형제 겹침:** 없음. `finishing.md` 는 형제 계획 `2026-08-31-brief-restructure.md` 의 목록에 있으나 그 작업은 base 에 머지됐다(Task 0 Step 3 이 확인).

**인터뷰가 확정한 것을 재결정했다 — 설계 §9 의 기록을 여기 옮긴다.** 원래 C12 는 이 자리에 `PreCompact matcher=manual` 훅을 붙이기로 했다. 코드를 읽고 두 가지가 드러나 뒤집었다: ⑴ 이 리포 전체에 `PreCompact`/`PostCompact` 훅이 **0개**라 채널 «선택» 이 아니라 «신설» 이고 brief 의 Non-goal 이 그것을 막는다. ⑵ `finishing.md:243-244` 가 이미 *"사용자가 `/compact` 를 실제 실행한 다음 턴에 **사용자 트리거**로만 일어난다"* 고 적어 철회할 «자동 이어짐 약속» 이 애초에 없다. **측정은 원안을 지지했다** — `PreCompact manual` 이 발화하고 그 출력이 압축을 넘어 모델에 도달하는 것은 인터뷰에서 실측됐다(`shared/tests/fixtures/seamprobe/MEASUREMENT.md` 의 `COMPACT_CHANNEL_OK`). 기각의 근거는 「되지 않는다」가 아니라 「새로 만들 값어치가 없다」다.

**이 Task 에 락이 없는 이유 — 완료 주장을 여기서 좁힌다(OQ-J).** `<brief-path>` 치환은 「모델이 사용자에게 보여준 텍스트」를 읽어야 검사할 수 있는데 **그 층에 훅이 없다**(리포 전체에 그 이벤트가 0개). 자리 ①의 `<file>` 은 치환에 실패하면 `build_brief_bundle.py` 가 rc 2 로 잡지만, `/compact` 템플릿은 사용자에게 그대로 붙여넣게 노출되므로 잡는 자리가 없다. **아홉 자리 중 이 한 조각만 검사 없이 남는다** — 이 계획은 그것을 완료로 세지 않는다. 안내 문구 교체(아래 Step 1)는 doc 편집이고, 그 자체를 락으로 고정하면 문면 하나에 회귀 락을 다는 것이라 비용이 이익을 넘는다.

- [ ] **Step 1: `:237` 의 도착 주장을 걷어낸다**

현재:

```markdown
  brief 재저장 → `check_brief.py gate` 재실행(통과 확인) → 아래 verbatim `/compact` 명령을
  *그대로 보이게* 노출 + "compact 후 brainstorming 진입 준비됨" 안내:
```

「준비됨」은 압축 **뒤의 상태**에 대한 주장인데 아무도 확인하지 않는다. 교체:

```markdown
  brief 재저장 → `check_brief.py gate` 재실행(통과 확인) → 아래 verbatim `/compact` 명령을
  *그대로 보이게* 노출 + "다음 턴에 직접 `Skill superpowers:brainstorming <실제 경로>` 를
  부르세요" 안내 (사람이 유일한 운반자다 — 자동으로 이어지지 않는다):
```

- [ ] **Step 2: `:239` 의 자리표시자를 실제 경로로 채우게 지시한다**

현재 `:239` 는 `<brief-path>` 를 두 번 쓴다(`... brief at <brief-path> 보존 ...` 과 `... Skill superpowers:brainstorming <brief-path>.`). 템플릿 줄 **바로 아래**에 지시를 한 줄 더한다:

```markdown
  **`<brief-path>` 두 자리를 Step A 가 방금 쓴 실제 경로로 치환한 뒤 노출한다.** 이 명령은
  사용자가 그대로 붙여넣는 것이므로, 치환하지 않고 내보내면 사용자가 깨진 명령을 실행한다 —
  그리고 그것을 잡는 자리가 없다(자리 ①의 `<file>` 과 달리 fail-closed 검사가 없다).
```

- [ ] **Step 3: 편집이 다른 것을 깨지 않았는지 확인한다**

```bash
grep -n '준비됨' plugins/spec-distill/skills/conducting-interview/references/finishing.md
grep -c 'brief-path' plugins/spec-distill/skills/conducting-interview/references/finishing.md
bash plugins/spec-distill/tests/test_brief_review_entry.sh
bash plugins/spec-distill/tests/test_stale_terms.sh
```

기대: 첫 줄 출력 없음. 둘째는 `:239`(×2) + `:242` + `:248` 이 남아 **4 이상**(이 Task 는 `:239` 의 자리표시자를 *지우지* 않고 치환하라고 **지시**만 더한다 — 치환은 실행 시점에 모델이 한다). 뒤 둘은 PASS(예상된 RED 없음).

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/skills/conducting-interview/references/finishing.md
```

```
fix(spec-distill): /compact 안내에서 확인되지 않는 도착 주장을 걷어낸다 (묶음 2b)

"compact 후 brainstorming 진입 준비됨" 은 압축 뒤의 상태에 대한 주장인데
아무도 확인하지 않는다. 사람이 다음 턴에 무엇을 하는지로 바꾼다 — 이 자리의
유일한 운반자가 사람임을 숨기지 않는 문면이다.

인터뷰가 확정한 C12(PreCompact matcher=manual 신설)를 재결정했다. 이 리포에
PreCompact/PostCompact 훅이 0개라 채널 선택이 아니라 신설이고 brief 의
Non-goal 이 막는다. 그리고 finishing.md:243-244 가 이미 사람을 유일 트리거로
적고 있어 철회할 자동 이어짐 약속이 애초에 없었다. 측정은 원안을 지지했다
(MEASUREMENT.md 의 COMPACT_CHANNEL_OK) — 기각 근거는 "되지 않는다" 가 아니라
"새로 만들 값어치가 없다" 다.

<brief-path> 치환 지시를 더했으나 락은 없다. 모델이 사용자에게 보여준 텍스트를
읽는 훅이 리포에 없기 때문이다. 아홉 자리 중 이 한 조각만 검사 없이 남는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

---

### Task 5: 묶음 3a — 배포 단위 밖 선결조건 제거 + L 등식 락

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md` — `:62`(근거 문장 재서술) · `:105-131`(`## zero-tool 격리 선결 조건` 절 전체 삭제) · `:500`(상호참조 정리)
- Modify: `plugins/spec-distill/templates/interview-audit-template.md:57` (격리 줄 삭제)
- Modify: `plugins/spec-distill/tests/test_brief_agents.sh` — `:9`(`AUDIT=`) · `:17-25`(fail-closed 판독) · `:99-109`(verdict 분기) 삭제 → **L 등식 락**
- Modify: `plugins/spec-distill/tests/test_reviewing_brief_skill.sh:161-189` (축 C 폐포 전체 삭제)
- Modify: `plugins/spec-distill/tests/test_brief_review_state.py:169-173` (probe 실패 record 2건 전제 삭제)
- Modify: `plugins/spec-distill/tests/test_brief_review_meta.sh:109`·`:129` (결정론 검사 목록에서 `zero-tool` 항목 삭제)
- Create: `plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh` (**B1**)
- **건드리지 않는다:** `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` (G16 — 근거 기록은 남는다)

**Interfaces:**
- Consumes: Task 0 의 derivation 축 A(`ZERO_TOOL`)·축 C(`$WFAIL` 폐포)·축 D(degrade 생산자↔소비자)
- Produces: `reviewing-brief` 파이프라인이 `docs/audits/` 아래 어떤 파일도 **실행 시점 선결조건**으로 읽지 않는다. 충실도 verdict 는 **무조건 hard gate**. `test_brief_agents.sh` 가 집합 등식 **L** 을 집행한다: `agents/*.md` 중 `tools:` 가 빈 리스트인 파일 집합 == `{brief-critic, brief-readback, seed-critic, seed-readback}`.

**형제 겹침:** 없음 (형제 계획 `:1699` 의 테스트 12개 목록에 이 파일들은 없다). `test_stale_terms.sh` 는 **영향받지 않는다** — 그 락은 `breadth-keeper`·`interview_round`·v0.23.0 권위 문법 6개를 찾고 `ZERO_TOOL_*` 는 그 목록에 없으며, 삭제는 원리상 stale term 을 추가할 수 없다.

**N3 위반의 형태:** `reviewing-brief/SKILL.md:107` 이 `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` 의 `**분기 판정:**` 한 줄을 **cwd 상대경로**로 읽고, 없으면 파이프라인을 시작하지 않는다. 그 파일은 **플러그인 배포 단위 밖**이라 devbrew 리포 밖 사용자에게는 존재하지 않는다 — fail-closed 가 곧 100% 차단이다. 현재 판정이 `ZERO_TOOL_OK` 이므로 **오늘 도는 갈래는 차단 게이트**다. 분기를 지우고 그 갈래만 남긴다 — **완화가 아니라 유지**다.

**대체물이 아닌 이유:** 무조건 `tools: []` 요구는 신설이 아니다. 같은 플러그인의 `tests/test_seed_agents.sh:123-134` 가 `seed-critic`·`seed-readback` 에 대해 **감사 파일 종속 없이 정확히 그 형태**로 이미 출하돼 있다. 뒤쪽을 앞쪽 모양으로 맞추는 것이고, 결과적으로 기계가 **줄어든다**.

**축 D 경고 — 이것을 빼면 degrade 기록의 생산자가 0 이 된다.** 이 skill 에서 `degrade-append` 를 **실제로 실행**하는 줄은 `:123`·`:126` 둘뿐이고 둘 다 지우는 블록 안이다. 소비자는 전부 남는다(`:73-75` `$DEGRADE_FALLBACK_FILE` · `:79` · `:83` · `:91-103` 「두 번째 채널」 절 · `:519` Step B 산출물 4번). **그러나 남는 degrade 설비는 블록 밖에 이미 있다** — `:73-75` 의 fallback 파일과 `:94` 의 호출 템플릿. 사슬은 끊기지 않는다. 지우는 블록 안의 두 호출은 *probe 실패* 전용 record 였고, 그 분기 자체가 사라지므로 함께 사라지는 것이 맞다.

**`BRS=` 는 블록과 함께 지운다 (옮기지 않는다).** 삭제 후 이 파일에 `$BRS` 를 참조하는 줄이 **0** 이다 — `:94` 의 템플릿은 `... degrade-append ...` 로 그 변수를 쓰지 않고, 나머지 degrade 지점은 전부 산문 `record(...)` 라 경유하지 않는다. 옮기면 **무소비 정의**가 남고, 그것은 이 작업이 진단한 N2 를 또 한 번 뒤집는 것이다.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다 — B1**

`plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh`:

```bash
#!/usr/bin/env bash
# B1 — 배포 단위 밖 파일(docs/audits/…) 없이도 brief 리뷰 격리 락이 도는가.
#
# 양성 증인을 먼저 세운다: 감사 파일이 **없는** 임시 리포 루트에서 격리 락이
# 실제로 **실행되고 통과**하는가. 그다음에야 SKILL 본문에 그 경로 참조가 없음을
# 묻는다. 부재만 보는 단언은 대상을 통째로 지워도 통과한다.
#
# 격리 설치(CLAUDE_CONFIG_DIR)를 쓰지 않는 이유: 재는 것이 "플러그인이 자기 배포
# 단위 밖 파일을 실행 시점에 읽는가" 하나이고, 그 조건은 docs/audits/ 를 빼고
# 복사한 임시 루트로 정확히 재현된다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/plugins" "$T/shared"
cp -R "$REPO_ROOT/plugins/spec-distill" "$T/plugins/"
cp -R "$REPO_ROOT/shared/tests" "$T/shared/"
# 의도적으로 docs/audits/ 를 만들지 않는다 — 이것이 이 테스트의 전제다.
test ! -d "$T/docs/audits" && ok "전제: 임시 루트에 docs/audits/ 가 없다" \
  || no "전제 붕괴 — 임시 루트에 감사 디렉토리가 생겼다"

# (1) 양성 증인 — 감사 파일 없는 루트에서 격리 락이 **돌고 통과**한다.
OUT="$(cd "$T" && bash "$T/plugins/spec-distill/tests/test_brief_agents.sh" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "감사 파일 없는 루트에서 test_brief_agents.sh 가 통과 (선결조건 없음)" \
  || { no "감사 파일 없는 루트에서 격리 락이 실패 (rc=$RC) — 배포 단위 밖 선결조건이 남아 있다"; printf '%s\n' "$OUT" | tail -20; }

# (2) 양성 증인 — 그 실행이 실제로 격리를 **검사했다** (빈 통과가 아니다).
grep -qF 'tools' <<<"$OUT" && ok "그 실행이 tools 표면을 실제로 검사했다" \
  || no "출력에 tools 검사 흔적이 없다 — 락이 조기 종료했을 수 있다"

# (3) 부재 — SKILL 본문이 실행 시점에 배포 단위 밖 경로를 읽지 않는다.
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md"
grep -qF 'docs/audits/' "$SKILL" \
  && no "reviewing-brief SKILL 이 여전히 docs/audits/ 경로를 참조한다 (N3 위반)" \
  || ok "reviewing-brief SKILL 에 배포 단위 밖 경로 참조 없음"

# (4) 양성 증인 — 그 절이 사라졌어도 충실도 hard gate 서술은 남아 있다.
grep -qF 'hard gate' "$SKILL" \
  && ok "충실도 verdict 가 여전히 hard gate 로 서술된다 (차단력 유지)" \
  || no "hard gate 서술이 사라졌다 — 완화가 아니라 유지여야 한다"

# (5) 근거 기록 자체는 지우지 않는다.
test -f "$REPO_ROOT/docs/audits/2026-07-27-spec-distill-zero-tool-probe.md" \
  && ok "probe 감사 문서는 근거 기록으로 남아 있다" \
  || no "감사 문서를 지웠다 — 지우는 것은 그것을 읽는 코드이지 기록이 아니다"
finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh`

Expected: 단언 (1) **FAIL** — 임시 루트에 감사 파일이 없어 `test_brief_agents.sh:18` 이 `exit 1`. (3) **FAIL** — `SKILL.md:107` 이 아직 그 경로를 담는다. (전제)(4)(5) **PASS** — 양성 증인. (2) 는 (1) 이 조기 종료해 FAIL.

- [ ] **Step 3: `SKILL.md` 의 probe 절과 그 부수 참조를 지운다**

**⒜ 절 경계를 재도출한다** (줄 번호를 믿지 않는다 — `:105-125` 로 자르면 bash 펜스 한가운데를 잘라 닫는 백틱 없는 고아 블록이 남는다):

```bash
grep -n '^## \|^#### ' plugins/spec-distill/skills/reviewing-brief/SKILL.md | sed -n '/zero-tool/,+2p'
awk 'NR>=100 && NR<=136 {printf "%d\t%s\n", NR, $0}' plugins/spec-distill/skills/reviewing-brief/SKILL.md | grep -n '```'
```

기대: `## zero-tool 격리 선결 조건` 이 `:105`, 다음 헤딩 `## 진입 첫 액션` 이 `:133`. 펜스는 `:121`·`:129` 쌍. **`:105` 부터 `:131` 까지**(다음 헤딩 앞 빈 줄까지)를 지운다.

**⒝ `:62` 의 근거 문장을 재서술한다.** 현재 그 줄은 `$STATE` 를 먼저 정의하는 이유로 *"아래 probe 실패 분기가 `$STATE`에 쓰므로"* 를 **유일 근거**로 든다. 그 분기가 사라지므로 근거를 바꾼다. 해당 절을 이렇게 고친다:

```
… `$STATE`를 이 절에서 먼저 정의하는 이유는 아래 degrade 기록 경로(`brief_review_state.py`)가
그 값을 쓰기 때문입니다(이 문서 전체가 위에서 아래로 그대로 실행 가능하다는 주장은 아닙니다:
`$PAYLOAD`·`$AUDIT`·`$CODEX_DIR_YAML`·`$CODEX_FID_YAML`은 …
```

즉 `zero-tool 선결 조건보다 먼저` → `이 절에서 먼저`, `아래 probe 실패 분기가 $STATE에 쓰므로 그 값이 먼저 있어야 합니다` → `아래 degrade 기록 경로(brief_review_state.py)가 그 값을 쓰기 때문입니다`. 괄호 안 나머지는 **그대로 둔다**(`$AUDIT` 서술은 Task 7 이 쓴다).

**⒞ `:500` 의 상호참조를 정리한다.** 현재 문장 끝의 `(zero-tool 격리 미보장 분기와 동일한 원인의 신뢰도 저하)` 를 `(격리 전제가 훼손된 라운드의 신뢰도 저하)` 로 바꾼다 — 사라진 분기를 가리키는 참조가 남으면 다음 저자가 없는 절을 찾는다.

**⒟ 확인:**

```bash
grep -n 'zero-tool\|ZERO_TOOL\|docs/audits/' plugins/spec-distill/skills/reviewing-brief/SKILL.md
grep -c '```' plugins/spec-distill/skills/reviewing-brief/SKILL.md
```
기대: 첫 줄 출력 없음. 둘째는 **짝수**(펜스 균형 — 홀수면 고아 블록을 만든 것이다).

- [ ] **Step 4: 템플릿의 격리 줄을 지운다**

`plugins/spec-distill/templates/interview-audit-template.md:57` 의 `- 격리: zero-tool probe <…>` 한 줄 삭제.

```bash
grep -n 'zero-tool' plugins/spec-distill/templates/interview-audit-template.md
```
기대: 출력 없음.

- [ ] **Step 5: `test_brief_agents.sh` 를 무조건 검사 + L 등식으로 바꾼다**

**⒜ 삭제:** `:9` 의 `AUDIT=` 대입, `:17-25` 의 fail-closed 판독 + `VERDICT=` + `case`, `:99-109` 의 `# probe 판정에 따른 …` 주석과 `for a in "${ISOLATED[@]}"` 루프 전체. `:10` 의 `ISOLATED=(...)` 배열도 소비자가 사라지므로 **함께 지운다**(축 C).

**⒝ 그 자리에 L 등식 락을 넣는다** — `:99-109` 이 있던 자리에:

```bash
# --- L : 격리 집합 등식 (N5) ------------------------------------------------
# 스캔한 집합 == 리터럴 이름 목록. **선택자를 술어와 같은 값으로 두지 않는다**:
# 대상을 `tools: []` 에서 도출하면 `tools: Read` 로 넓히는 변이가 대상 집합을
# 벗어나 락이 공허참으로 통과한다(∀x∈{x:P(x)}. P(x)).
#
# 우변이 리터럴이므로 세 방향이 전부 잡힌다:
#   하나를 넓힘   → 좌변이 셋으로 줄어 ≠  → RED
#   다섯째 추가   → 좌변이 다섯으로 늘어 ≠ → RED
#   넷을 동시에   → 좌변이 공집합 ≠        → RED
# 세 번째가 잡히므로 "각 원소가 tools: [] 이다" 는 별도 락이 **논리적으로
# 잉여**다 — 등식이 그것을 함의한다. 잉여를 필요하다고 적으면 다음 저자가
# 등식 쪽을 지운다.
#
# 표기 변형은 형제 락 test_seed_agents.sh:131 을 물려받아 `[]` 와 `[ ]` 를
# 둘 다 빈 리스트로 읽는다.
EXPECTED_ISOLATED="brief-critic
brief-readback
seed-critic
seed-readback"

scan_zero_tool_agents() {
  # $1 = agents 디렉토리. 빈 리스트를 선언한 파일의 basename(확장자 제거)을
  # 정렬해서 낸다.
  local dir="$1" f base fm tl
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .md)"
    fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$f")"
    tl="$(printf '%s\n' "$fm" | sed -n 's/^tools:[[:space:]]*//p' | head -1)"
    tl="${tl%"${tl##*[![:space:]]}"}"   # 트레일링 공백 제거
    case "$tl" in
      "[]"|"[ ]") printf '%s\n' "$base" ;;
    esac
  done | sort
}

ACTUAL_ISOLATED="$(scan_zero_tool_agents "$SD/agents")"
if [ "$ACTUAL_ISOLATED" = "$(printf '%s\n' "$EXPECTED_ISOLATED" | sort)" ]; then
  ok "L: tools 빈 리스트 집합 == 리터럴 목록 (전수)"
else
  no "L: 격리 집합 불일치. 스캔=[$(printf '%s' "$ACTUAL_ISOLATED" | tr '\n' ' ')] 기대=[$(printf '%s' "$EXPECTED_ISOLATED" | tr '\n' ' ')]"
fi
```

**⒞ `ALL` 배열은 남긴다** — `:11` 의 `ALL=("brief-critic" "brief-readback" "brief-direction-reviewer")` 는 `:27` 의 공통 루프가 쓰고, 그 루프는 probe 와 무관하다.

**⒟ 확인:**

```bash
bash -n plugins/spec-distill/tests/test_brief_agents.sh && echo "syntax OK"
grep -n 'AUDIT\|VERDICT\|ISOLATED\|ZERO_TOOL' plugins/spec-distill/tests/test_brief_agents.sh
```
기대: `syntax OK`. 둘째는 `EXPECTED_ISOLATED`·`ACTUAL_ISOLATED`·`scan_zero_tool_agents` 만 나오고 `AUDIT`·`VERDICT`·`ZERO_TOOL` 은 없다.

- [ ] **Step 6: 축 C 폐포 — `test_reviewing_brief_skill.sh:161-189` 를 통째로 지운다**

`# --- T23 / AC2b · AC7 : probe 이진 분기 ---` 주석부터 `# --- T22 / AC15 : degradation record ---` 바로 앞까지. 이 구간이 `WFAIL`(`:167`) · `WFAIL_BASH`(`:173`) · `DEGRADE_RE`(`:177`) · `WOK`(`:181`) 을 **대입하고 소비하는 폐포 전체**다.

**부분 삭제는 RED 가 아니라 중단이다** — 이 파일 `:8` 이 `set -u -o pipefail` 이라 대입만 지우고 소비를 남기면 unbound variable 로 스크립트가 죽고, 그러면 baseline 대조가 무의미해진다.

```bash
grep -n 'WFAIL\|DEGRADE_RE\|WOK' plugins/spec-distill/tests/test_reviewing_brief_skill.sh
bash -n plugins/spec-distill/tests/test_reviewing_brief_skill.sh && echo "syntax OK"
bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh
```
기대: 첫 줄 출력 없음(폐포 밖 소비자 0). 셋째는 PASS.

- [ ] **Step 7: 나머지 두 소비자를 정리한다 (축 A)**

`plugins/spec-distill/tests/test_brief_review_state.py:169-173` — probe 실패 시 record 2건을 전제하는 테스트다. 그 분기가 사라졌으므로 **해당 테스트 메서드를 삭제**한다(사유를 docstring 이 아니라 커밋 메시지에 남긴다 — 산출물에 존재 정당화를 적지 않는다).

`plugins/spec-distill/tests/test_brief_review_meta.sh` — `:109` 의 `for chk in 'check_verbatim_coverage' 'zero-tool probe' 'merge_brief_review' 'T-lock'` 에서 `'zero-tool probe'` 항목 하나, `:129` 의 `DET_CHECKS="… zero-tool …"` 에서 `zero-tool` 토큰 하나를 지운다. **나머지 항목은 그대로** — 결정론 검사 목록 자체는 살아 있다.

- [ ] **Step 8: 통과를 확인한다**

```bash
bash plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh
bash plugins/spec-distill/tests/test_brief_agents.sh
bash plugins/spec-distill/tests/test_seed_agents.sh
bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh
bash plugins/spec-distill/tests/test_brief_review_meta.sh
bash plugins/spec-distill/tests/test_stale_terms.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_brief_review_state.py'
```

Expected: 전부 PASS. `test_seed_agents.sh` 는 **확장하지 않는다** — L 이 그 넷을 이미 덮으므로 형제 락의 열거를 건드릴 이유가 없다. RED 가 나면 `.claude/seam-channel/baseline-2026-09-03.tsv` 에서 그 파일을 찾아 선재 여부를 가른다.

- [ ] **Step 9: 커밋**

```bash
git add -u plugins/spec-distill
git add plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh
```

```
fix(spec-distill): 배포 단위 밖 파일을 선결조건으로 읽지 않는다 (묶음 3a)

reviewing-brief 가 docs/audits/2026-07-27-…md 의 "분기 판정:" 한 줄을 cwd
상대경로로 읽고 없으면 파이프라인을 시작하지 않았다. 그 파일은 플러그인 배포
단위 밖이라 devbrew 리포 밖 사용자에게는 존재하지 않는다 — fail-closed 가 곧
100% 차단이었다.

현재 판정이 ZERO_TOOL_OK 이므로 오늘 도는 갈래는 차단 게이트다. 분기를 지우고
그 갈래만 남긴다 — 완화가 아니라 유지다. 감사 문서 자체는 지우지 않는다:
그것이 tools: [] 집행의 근거 기록이고, 지우는 것은 실행 시점에 그 파일을 읽는
코드다. 이 구별이 N3 의 전부다.

무조건 tools: [] 요구는 신설이 아니다 — test_seed_agents.sh:123-134 가 감사
종속 없이 정확히 그 형태로 이미 출하돼 있다. 뒤쪽을 앞쪽 모양에 맞췄다.

격리 검사를 집합 등식 L 로 올렸다: 스캔한 빈-리스트 집합 == 리터럴 이름 목록
넷. 대상을 tools: [] 에서 도출하면 선택자와 술어가 같은 값이 되어, 하나를
tools: Read 로 넓히는 변이가 대상 집합을 벗어나 공허참으로 통과한다. 우변이
리터럴이라 값 넓히기·신규 추가·동시 이탈 셋이 전부 RED 다. "각 원소가
tools: [] 이다" 는 등식이 함의하므로 두지 않는다.

test_reviewing_brief_skill.sh 는 :161-189 를 폐포째 지웠다 — 그 파일이
set -u 라 대입만 지우고 소비를 남기면 RED 가 아니라 중단이다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

- [ ] **Step 10: 변이로 이빨을 확인한다 (MU5 · MU6 · MU7 + B1)**

**MU5~MU7 이 함께여야 N5 가 성립한다.** 하나라도 GREEN 이 나오면 등식이 세 방향을 다 막지 못하는 것이다.

| 변이 | 무엇을 한다 | 기대 |
|---|---|---|
| **MU5** | `plugins/spec-distill/agents/brief-critic.md:14` 를 `tools: Read` 로 | **RED** — 좌변이 셋 |
| **MU6** | `plugins/spec-distill/agents/` 에 `tools: []` 인 다섯째 `.md` 를 임시 생성(목록은 그대로) | **RED** — 좌변이 다섯 |
| **MU7** | 넷 **모두**를 `tools: Read` 로 | **RED** — 좌변이 공집합 |
| **MU5b** | `brief-critic.md:14` 를 `tools: [ ]`(공백 하나)로 | **GREEN** — 표기 변형 허용(형제 락과 같은 계약). GREEN 이 아니면 D5 의 표기 결정이 코드와 갈린 것 |
| **B1-mut** | `SKILL.md` 에 `docs/audits/…` 참조 한 줄을 되살린다 | **RED** — B1 단언 (3) |
| **B1-mut2** | `test_brief_agents.sh` 를 아무 assert 도 없는 빈 스크립트로 만든다 | **RED** — B1 단언 (2). 「돌긴 돌았다」와 「실제로 검사했다」를 가른다 |

각 변이마다:

```bash
bash plugins/spec-distill/tests/test_brief_agents.sh
bash plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh
git checkout -- plugins/spec-distill
git status --porcelain plugins/spec-distill
```

MU6 은 **파일 생성**이므로 `git checkout --` 로 안 지워진다 — `rm` 으로 직접 지우고 `git status --porcelain` 이 비는지 확인한다.

---

### Task 6: 묶음 3b — `next_phase` 값 고정 해제

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py:909-910` (검사 두 줄 삭제)
- Create: `plugins/spec-distill/tests/test_check_brief_frontmatter.py` (**B4 · MU10 · MU11**)
- **건드리지 않는다:** `plugins/spec-distill/templates/interview-brief-template.md` 의 `next_phase:` 줄 (아래 참조)

**Interfaces:**
- Consumes: 없음
- Produces: `frontmatter_errors(fm)` 가 `next_phase` 축으로는 어떤 값에 대해서도(부재 포함) 오류를 내지 않는다. 나머지 축(`type` · `audit_file` · `user_sourced_items`)의 판정은 **불변**.

**형제 겹침:** 없음 (`check_brief.py` 는 머지된 brief-restructure 의 목록에만 있다).

**왜 형태 계약도 두지 않는가:** 이 필드를 읽는 **런타임 소비자가 0** 이다. 템플릿·픽스처·이 게이트뿐이고, superpowers 부재 처리는 `finishing.md:172` 가 스스로 한다(loud advisory 후 STOP). 소비자가 없는데 게이트만 남기면 그 게이트는 오타(`superpowrs:brainstorming`)를 통과시키면서 **검증하는 것처럼 보인다** — 그것이 이 작업이 진단한 「강제처럼 보이는 서술」의 게이트 버전이다. 검사를 남기려면 먼저 소비자를 만들어야 하는데 그것은 새 강제 신설이라 Non-goal 이다.

**필드 자체는 템플릿에 남긴다 — 지우면 다른 락이 깨진다.** `plugins/spec-distill/tests/test_brief_no_statement_cap.sh:28-32` 가 `next_phase: superpowers:brainstorming` 을 **앵커**로 쓴다(*"이 템플릿에 고유하고 안정적인 줄"*). 게이트 검사만 지우고 필드는 정보성 메타데이터로 둔다. 이것은 축 D(생산자↔소비자) 스윕이 잡은 자리다.

**C19 는 이것으로 충족된다** — 요구가 사라지므로 devbrew 밖 사용자에게 이 축의 차단이 없다.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다 — B4**

`plugins/spec-distill/tests/test_check_brief_frontmatter.py`:

```python
"""frontmatter_errors() 의 축별 판정. Run: python3 -m unittest.

파일 픽스처를 쓰지 않는다 — 이 함수는 순수 함수이고, interview-brief-*.md
74건과 함께 드리프트하는 부채를 새로 만들 이유가 없다.
"""
from __future__ import annotations
import importlib.util
import sys
import unittest
from pathlib import Path

# check_brief.py 는 :66 에서 `import section6` 를 한다(같은 scripts/ 디렉토리).
# spec_from_file_location 은 그 디렉토리를 sys.path 에 넣어주지 않으므로 직접 넣는다 —
# 안 넣으면 ModuleNotFoundError 로 이 파일이 통째로 collection 에서 죽는다.
_SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

_SPEC = importlib.util.spec_from_file_location("check_brief", _SCRIPTS / "check_brief.py")
check_brief = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(check_brief)

VALID = """---
type: interview-brief
next_phase: superpowers:brainstorming
audit_file: docs/superpowers/interview/x.audit.md
user_sourced_items:
  - id: S1
---
"""


def errs(text: str) -> list[str]:
    return check_brief.frontmatter_errors(text)


class NextPhaseNotAdjudicated(unittest.TestCase):
    """B4 · MU10 — 게이트가 next_phase 값을 판정하지 않는다."""

    def test_baseline_valid_frontmatter_has_no_errors(self):
        """양성 증인 — 이 픽스처가 애초에 통과한다 (아래 단언들이 공허하지 않다)."""
        self.assertEqual(errs(VALID), [])

    def test_missing_next_phase_is_not_an_error(self):
        text = VALID.replace("next_phase: superpowers:brainstorming\n", "")
        self.assertEqual(
            [e for e in errs(text) if "next_phase" in e], [],
            "next_phase 부재가 여전히 오류로 잡힌다")

    def test_other_next_phase_value_is_not_an_error(self):
        text = VALID.replace("superpowers:brainstorming", "anything:at-all")
        self.assertEqual(
            [e for e in errs(text) if "next_phase" in e], [],
            "next_phase 의 다른 값이 여전히 오류로 잡힌다")


class OtherAxesStillBite(unittest.TestCase):
    """MU11 — next_phase 를 지우면서 게이트 전체를 무력화하지 않았다."""

    def test_broken_type_still_fails(self):
        text = VALID.replace("type: interview-brief", "type: something-else")
        self.assertIn("type != interview-brief", errs(text))

    def test_missing_user_sourced_items_still_fails(self):
        text = VALID.replace("user_sourced_items:\n  - id: S1\n", "")
        self.assertIn("user_sourced_items key absent", errs(text))

    def test_missing_audit_file_still_fails(self):
        text = VALID.replace(
            "audit_file: docs/superpowers/interview/x.audit.md\n", "")
        self.assertTrue([e for e in errs(text) if "audit_file" in e],
                        "audit_file 축이 죽었다")

    def test_absent_frontmatter_still_fails(self):
        self.assertEqual(errs("no frontmatter here"), ["frontmatter absent"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_check_brief_frontmatter.py' -v`

Expected: `test_missing_next_phase_is_not_an_error` **FAIL** · `test_other_next_phase_value_is_not_an_error` **FAIL**. `OtherAxesStillBite` 넷과 `test_baseline_valid_frontmatter_has_no_errors` **PASS** — **양성 증인**이다. baseline 이 FAIL 이면 `VALID` 픽스처가 틀린 것이므로 `frontmatter_errors` 를 다시 읽고 고친다(이 단언이 나머지의 공허참을 막는 자리다).

- [ ] **Step 3: 최소 구현 — 두 줄 삭제**

`plugins/spec-distill/scripts/check_brief.py` 의 `frontmatter_errors()` 에서:

```python
    if not re.search(r"^next_phase:\s*superpowers:brainstorming\s*$", fm, re.MULTILINE):
        errs.append("next_phase != superpowers:brainstorming")
```

두 줄을 지운다. **`type` 검사(`:907-908`)와 그 아래 `audit_file`·`user_sourced_items` 는 건드리지 않는다** — 소비자가 있다.

- [ ] **Step 4: 통과를 확인한다**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_check_brief_frontmatter.py' -v
bash plugins/spec-distill/tests/test_brief_no_statement_cap.sh
bash plugins/spec-distill/tests/test_check_brief.sh
```

Expected: 7 tests 0 failures · 뒤 둘 PASS. `test_brief_no_statement_cap.sh` 가 RED 면 템플릿의 `next_phase:` 줄을 실수로 지운 것이다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/test_check_brief_frontmatter.py
```

```
fix(spec-distill): 게이트가 next_phase 값을 판정하지 않는다 (묶음 3b)

check_brief.py 가 next_phase: superpowers:brainstorming 을 정확 일치로 요구해,
superpowers 없는 사용자에게 구조 게이트가 통과 불가였다 — probe 선결조건과 같은
결과를 낸다.

형태 계약도 두지 않는다. 이 필드를 읽는 런타임 소비자가 0 이고, 소비자가 없는데
게이트만 남기면 오타를 통과시키면서 검증하는 것처럼 보인다. 검사를 남기려면
먼저 소비자를 만들어야 하는데 그것은 새 강제 신설이라 Non-goal 이다.

필드 자체는 템플릿에 남긴다 — test_brief_no_statement_cap.sh:28-32 가 그 줄을
앵커로 쓴다. 게이트 검사만 지우고 정보성 메타데이터로 둔다.

앞선 논거 하나를 철회한다: "interview-seed 가 next_phase: spec-distill:interview
를 쓰므로 형태 검사가 두 산출물 타입에 모두 맞는다" 는 공허했다 — 두 줄 위
:907-908 이 type: interview-brief 를 하드 요구하므로 이 게이트는 seed 문서에
애초에 적용되지 않는다.

MU11 로 게이트가 통째로 죽지 않았음을 가른다 — type·audit_file·
user_sourced_items 셋은 깨뜨리면 여전히 RED 다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

- [ ] **Step 6: 변이로 이빨을 확인한다 (MU10 · MU11)**

| 변이 | 무엇을 한다 | 기대 |
|---|---|---|
| **MU10-rev** | 지운 두 줄을 되살린다 | **RED** — `NextPhaseNotAdjudicated` 둘 |
| **MU11** | `frontmatter_errors()` 의 본문을 `return []` 로 바꾼다(게이트 전체 무력화) | **RED** — `OtherAxesStillBite` **넷 전부**. MU10 의 GREEN 이 「게이트가 통째로 죽어서」가 아님을 이것이 가른다 |
| **MU11b** | `type` 검사만 지운다 | **RED** — `test_broken_type_still_fails` 하나만 |

각 변이 후 `git checkout -- plugins/spec-distill/scripts/check_brief.py` 하고 `git status --porcelain plugins/spec-distill` 이 비는지 확인한다.

---

### Task 7: 묶음 4a — 핸드오프 인자를 넷으로

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md` — `:90`(「3개」) · `:95` 뒤(`AUDIT=` 추가) · `:101`(호출 라인) · `:104`(「세 인자는」)
- Modify: `plugins/spec-distill/tests/test_brief_review_entry.sh:172`(순회 목록) · `:190`(대입 확인 목록) · `:155-157`·`:186-189`(주석의 기수)

**Interfaces:**
- Consumes: Task 0 의 derivation 축 A(`$AUDIT`·`$PAYLOAD`)·축 B(개념 별칭)
- Produces: `finishing.md` 의 A.5 블록이 `PAYLOAD`·`AUDIT`·`CODEX_DIR_YAML`·`CODEX_FID_YAML` **넷**을 세우고 호출 라인이 넷을 넘긴다. `test_brief_review_entry.sh` 가 넷을 요구한다.

**형제 겹침:** 없음.

**진짜 결함은 인자 하나다.** `reviewing-brief/SKILL.md:62` 가 `$PAYLOAD`·`$AUDIT`·`$CODEX_DIR_YAML`·`$CODEX_FID_YAML` **네 개**를 호출자가 쥐고 넘기는 값이라고 명시하는데, `finishing.md:101` 은 **세 개**만 넘긴다. `$AUDIT` 이 빠지면 조용히 죽지는 않으나 **두 소비자가 함께 무너진다**:

| 소비자 | 결과 |
|---|---|
| `build_brief_bundle.py` (`SKILL.md:302`) | rc 2 → **충실도 리뷰 통째 skip**, degrade record 로만 남음 |
| `check_verbatim_coverage.py` (`SKILL.md:136` 진입 첫 액션 · `:362` 수정 후 재실행) | §6 원문 완전성 **결정론 검사**가 같은 빈 값으로 깨짐 |

**`<file>` 자리표시자는 유지한다** — 이미 fail-closed 다. `PAYLOAD="docs/superpowers/interview/<file>"` 을 그대로 복사하면 `build_brief_bundle.py` 의 파일 존재 검사가 rc 2 를 내고 `reviewing-brief` 는 *"critic 을 dispatch 하지 않는다"* 로 간다. 자리 ④의 `/compact` 템플릿과 결함의 종류는 같지만 **fail-closed 유무가 갈린다**(Task 4 참조).

**그리고 락이 결함을 고정하고 있다.** `test_brief_review_entry.sh:172` 가 세 변수만 순회하고 `:190` 이 세 할당만 확인한다. 이 락은 결함을 통과시키는 것이 아니라 **요구한다** — 인자를 넷으로 고치려면 락도 함께 고쳐야 한다.

**「3」이 흩어진 자리는 열거하지 않고 도출한다 (축 A·B).** 개수를 단언하지 않는 이유: 앞 판본이 «다섯 자리» 라고 적었고 리뷰가 두 자리를 더 찾아 최소 일곱이 됐다. **열거를 거부하면서 개수만 단언하면 계획이 그 숫자를 완료 오라클로 읽어 여섯째에서 멈춘다.**

- [ ] **Step 1: 「3」의 자리를 도출한다 (열거하지 않는다)**

```bash
# 축 A — 식별자 전수
grep -rn '\$AUDIT\|AUDIT=' plugins/spec-distill/skills/conducting-interview/ plugins/spec-distill/tests/test_brief_review_entry.sh
grep -rn '\$PAYLOAD\|PAYLOAD=' plugins/spec-distill/skills/conducting-interview/ plugins/spec-distill/tests/test_brief_review_entry.sh
# 축 B — 개념 별칭 (숫자를 말하는 산문)
grep -rn '세 인자\|3개\|변수 3\|3종\|세 변수\|이 세 값\|세 핸드오프' plugins/spec-distill/skills/conducting-interview/ plugins/spec-distill/tests/
```

출력 전부가 이 Task 의 편집 대상이다. **씨앗(전수 아님)**: `finishing.md:90`·`:104` · `test_brief_review_entry.sh:155-157`·`:165-168`·`:186-189`. 도출 결과가 씨앗보다 많으면 많은 쪽을 따른다.

- [ ] **Step 2: 실패하는 테스트를 먼저 쓴다 — 락을 넷으로 고친다**

`plugins/spec-distill/tests/test_brief_review_entry.sh:172` 의 순회 목록에 `'$AUDIT'` 을 더한다:

```bash
for handoff_var in '$PAYLOAD' '$AUDIT' '$CODEX_DIR_YAML' '$CODEX_FID_YAML'; do
```

`:190` 의 대입 확인 목록에 `'AUDIT='` 을 더한다:

```bash
for var in 'PAYLOAD=' 'AUDIT=' 'CODEX_DIR_YAML=' 'CODEX_FID_YAML='; do
```

같은 write 에서 축 B 를 처리한다 — `:155-157` 과 `:186-189` 주석의 「세 핸드오프 변수」·「세 변수」·「핸드오프 변수 3종」·「이 세 값을」 을 전부 **넷**으로 고친다. 숫자가 갈리면 다음 저자가 어느 쪽을 정본으로 읽을지 정해지지 않는다.

- [ ] **Step 3: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_brief_review_entry.sh`

Expected: `invocation 라인(코멘트 제외)에 $AUDIT 부재` **FAIL** + `A.5에 AUDIT 확립 부재` **FAIL**. 나머지 단언(다른 세 변수 · kill switch · A.5 규모 · 복제 금지)은 **PASS** — 양성 증인이다. 전부 FAIL 이면 `$WA5` 윈도우 앵커가 죽은 것이므로 원인이 다르다.

- [ ] **Step 4: 최소 구현 — `finishing.md` 를 넷으로**

`:90` 의 「핸드오프 변수 3개를」 → 「핸드오프 변수 4개를」.

`:92-98` 의 bash 펜스에 `AUDIT=` 한 줄을 더한다 (`PAYLOAD=` **바로 아래** — 둘이 같은 산출물의 짝이다):

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py" state-root)"
harness_sid="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py" session-id)"
PAYLOAD="docs/superpowers/interview/<file>"          # Step A가 방금 쓰고 검증한 경로
AUDIT="${PAYLOAD%.md}.audit.md"                      # payload 의 audit sidecar (§6 S2+ 원문)
CODEX_DIR_YAML="$ROOT/$harness_sid/codex-direction.yaml"
CODEX_FID_YAML="$ROOT/$harness_sid/codex-fidelity.yaml"
```

`:101` 의 호출 라인을 네 인자로:

```
Skill spec-distill:reviewing-brief $PAYLOAD $AUDIT $CODEX_DIR_YAML $CODEX_FID_YAML
```

`:104` 의 「세 인자는 **주석이 아니라 호출 라인 위에** 있어야 합니다」 → 「**네** 인자는 …」. 같은 문장이 *"`reviewing-brief`는 이 값들을 스스로 정의하지 않는다고 명시하므로"* 라고 이유를 대는데 그 이유가 바로 `$AUDIT` 에도 적용된다.

**`AUDIT=` 의 값을 `${PAYLOAD%.md}.audit.md` 로 도출하는 것이 왜 안전한가:** `build_brief_bundle.py:106` 의 `p.add_argument("audit_file")` 이 audit 을 **위치 인자로 요구**하고, `blessed_audit()`(`:77`)이 *"경로를 유추하지 않는다는 원칙은 유지한다. 호출자는 여전히 audit 을 명시해야 하고"* 라고 적는다. 즉 **빌더가 스스로 구하지 않으므로 호출자가 세워야 한다** — 이 도출은 호출자 쪽에서 명시하는 행위이지 빌더의 원칙을 어기는 것이 아니다. 그리고 v0.47.0 의 신원 대조가 게이트가 통과시킨 audit 과 다르면 거절하므로, 도출이 틀리면 조용히 지나가지 않는다.

> **brief 의 사실 하나가 코드에 의해 반증됐다.** brief §6 `S1` 은 *"넷째는 v0.47.0 이 빌더 쪽에서 스스로 구하게 고쳤는데 산문이 안 따라왔다"* 고 적었다. 코드는 반대다(위 인용 둘). **설계의 방향(인자 넷으로)이 옳고 brief 가 틀렸다** — brief 를 읽고 이 처방을 되돌리지 말 것. 확정 사실도 면역이 아니다(P23: 재발견 금지는 반증 금지가 아니다).

- [ ] **Step 5: 통과를 확인한다**

```bash
bash plugins/spec-distill/tests/test_brief_review_entry.sh
bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh
bash plugins/spec-distill/tests/test_brief_review_meta.sh
```
Expected: 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/tests/test_brief_review_entry.sh
```

```
fix(spec-distill): 핸드오프가 네 인자를 넘긴다 (묶음 4a)

reviewing-brief 는 $PAYLOAD·$AUDIT·$CODEX_DIR_YAML·$CODEX_FID_YAML 넷을
호출자가 쥐고 넘기는 값이라 명시하는데 finishing.md:101 이 셋만 넘겼다.
$AUDIT 이 빠지면 조용히 죽지는 않으나 두 소비자가 함께 무너진다:
build_brief_bundle.py 가 rc 2 로 충실도 리뷰를 통째 skip 하고,
check_verbatim_coverage.py 의 §6 원문 완전성 결정론 검사가 같은 빈 값으로 깨진다.

락이 결함을 고정하고 있었다 — test_brief_review_entry.sh:172 가 세 변수만
순회하고 :190 이 세 할당만 확인한다. 통과시키는 것이 아니라 요구하는 형태라
같은 커밋에서 넷으로 고쳤다. 주석의 기수도 함께 고쳤다 — 숫자가 갈리면 다음
저자가 어느 쪽을 정본으로 읽을지 정해지지 않는다.

brief §6 S1 은 "v0.47.0 이 빌더 쪽에서 스스로 구하게 고쳤다" 고 적었으나 코드는
반대다: build_brief_bundle.py:106 이 audit 을 위치 인자로 요구하고 blessed_audit()
docstring 이 "호출자는 여전히 audit 을 명시해야 하고" 라고 적는다. v0.47.0 이
더한 것은 자기 도출이 아니라 신원 대조다.

<file> 자리표시자는 유지한다 — 그대로 복사하면 파일 존재 검사가 rc 2 를 내는
fail-closed 다. /compact 템플릿과 결함의 종류는 같지만 그쪽에는 이 검사가 없다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

- [ ] **Step 7: 변이로 이빨을 확인한다 (MU8)**

| 변이 | 무엇을 한다 | 기대 |
|---|---|---|
| **MU8** | `finishing.md:101` 호출 라인에서 `$AUDIT` 를 뺀다 | **RED** — `invocation 라인 … $AUDIT 부재` |
| **MU8b** | `AUDIT=` 대입 줄만 지운다(호출 라인은 그대로) | **RED** — `A.5에 AUDIT 확립 부재` |
| **MU8c** | `$AUDIT` 를 호출 라인의 **트레일링 `#` 주석 뒤로** 옮긴다 | **RED** — `strip_trailing_linecomment`(`:171`)가 주석을 잘라내므로. 이 변이가 「주석에만 적혀 있으면 호출은 인자 없이 나간다」를 락이 실제로 잡는지 확인한다 |

각 변이 후 `git checkout -- plugins/spec-distill` · `git status --porcelain plugins/spec-distill`.

---

### Task 8: 묶음 4b — 목적지 이름을 한 자리로

**Files:**
- Modify: `plugins/spec-distill/hooks/review-dispatch.py` — 모듈 상수 추가 + 런타임 메시지 6곳(`:89` `:466` `:585` `:700` `:721` `:754`)
- Test: `plugins/spec-distill/tests/test_review_dispatch.sh` (기존 — 락 추가)

**Interfaces:**
- Consumes: 없음
- Produces: `review-dispatch.py` 에 모듈 상수 `REVIEW_SKILL = "reviewing-spec"` 가 있고, **런타임 메시지 전부가 그 상수 값을 포함**한다.

**형제 겹침 — 편집 직전 통지 (G11):** `plugins/spec-distill/hooks/review-dispatch.py` 가 형제 계획 `:1446`·`:1698` 에 올라 있다. **줄 충돌이지 지시 충돌이 아니다** — 저쪽은 `PENDING_RE`·`strip_pending` 등 **정의**를 지우고 이쪽은 **문자열 리터럴만** 건드리므로 merge 로 합쳐진다. 통지 문면: *"review-dispatch.py 에 모듈 상수 REVIEW_SKILL 을 추가하고 런타임 메시지 6곳의 'reviewing-spec' 리터럴을 f-string 보간으로 바꿉니다. 정의·정규식·제어 흐름은 건드리지 않습니다."*

**상수가 `hook_common.py` 가 아니라 이 파일에 사는 이유:** 그 리터럴의 소비자가 이 파일 하나뿐이라 공유 모듈이 필요 없다. 공유가 실제로 필요해지는 것은 두 번째 소비자가 생길 때이고, 지금 만들면 그것이 C8 이 기각한 «필요 없는 추상» 이다. **그리고 `hook_common.py` 는 G10 으로 범위 밖이다.**

**「목적지」의 정체:** 이 훅은 목적지 skill 을 직접 호출하지 않는다 — `decision: "block"` 과 `reason` 텍스트를 내고 모델이 그것을 읽는다. 즉 목적지는 **메시지에 박힌 이름**이다. 상수 하나 + 보간이면 충분하고, 그 이상은 C8 이 기각한 전면 데이터-구동이다.

**경로 접두는 이 Task 의 대상이 아니다 (G5/N4).** `arm_ledger.py:41` `PREFIX` ↔ `resolve_mode.py:9` `PATH_PREFIX` 는 통합 대상이 맞으나 `arm_ledger.py` 가 G10 으로 범위 밖이다.

- [ ] **Step 1: 형제 통지를 보낸다** (답을 기다리지 않는다)

- [ ] **Step 2: 실패하는 테스트를 먼저 쓴다 — MU9**

`plugins/spec-distill/tests/test_review_dispatch.sh` 끝(`finish` 앞)에 추가한다:

```bash
# --- MU9 : 목적지 이름이 한 자리에서 온다 -----------------------------------
# 삭제 변이로는 이빨을 못 잰다 — 상수를 지우면 import 에러로 전부 죽으므로
# "함께 죽었다" 가 "한 자리에서 온다" 의 증거가 되지 못한다. **값 변경 변이**가
# 잡히도록, 판정 가능한 단언으로 못 박는다:
#   "런타임 메시지 전부가 상수 값을 포함한다."
# 리터럴이 남은 자리가 있으면 상수 값을 바꿨을 때 그 자리에서 실패한다.
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
CONST_VAL="$(sed -n 's/^REVIEW_SKILL[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$HOOK" | head -1)"
[ -n "$CONST_VAL" ] && ok "MU9: 모듈 상수 REVIEW_SKILL 선언" \
  || no "MU9: REVIEW_SKILL 상수가 없다 — 목적지가 여전히 흩어져 있다"

# 양성 증인 — 런타임 메시지가 실제로 존재한다 (0건이면 아래 부재가 공허참).
# 모듈 docstring(첫 """ 블록)은 대상에서 뺀다: f-string 이 될 수 없어 손 갱신으로
# 남는다(설계 §5.2). 그래서 docstring 을 지난 뒤부터 센다.
BODY="$(awk 'BEGIN{d=0} /^"""/{d++; next} d>=2' "$HOOK")"
MSG_HITS="$(grep -c "$CONST_VAL" <<<"$BODY")"
[ "$MSG_HITS" -ge 1 ] && ok "MU9 양성 증인: 본문에 목적지 언급 ${MSG_HITS}건" \
  || no "MU9: 본문에 목적지 언급이 0건 — 앵커가 죽었다"

# 부재 — 본문의 목적지 언급 중 **상수를 경유하지 않는 리터럴**이 없다.
# 상수 선언 줄 자신은 제외한다.
STRAY="$(grep -n "$CONST_VAL" <<<"$BODY" | grep -v 'REVIEW_SKILL[[:space:]]*=' || true)"
[ -z "$STRAY" ] && ok "MU9: 목적지 리터럴이 본문에 없다 (전부 상수 경유)" \
  || { no "MU9: 상수를 경유하지 않는 목적지 리터럴이 남아 있다"; printf '%s\n' "$STRAY"; }
```

**`$SD` 를 쓰지 않는 이유:** 그 파일은 `:4` 에서 `REPO_ROOT` 만 세우고 `SD` 는 정의하지 않는다(실측). 형제 락의 관습을 흉내 내 `$SD` 를 쓰면 `set -u` 아래에서 unbound variable 로 **중단**된다 — RED 가 아니라 중단이라 baseline 대조가 무너진다.

- [ ] **Step 3: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_review_dispatch.sh`
Expected: `MU9: REVIEW_SKILL 상수가 없다` **FAIL**. 기존 단언 전부 **PASS**(양성 증인 — 이 파일의 다른 락이 살아 있다).

- [ ] **Step 4: 최소 구현**

**⒜ 상수를 선언한다.** import 블록 아래, 첫 함수 정의 위에:

```python
# 이 훅이 모델에게 지시하는 **목적지 skill 의 이름**. 아래 런타임 메시지 전부가
# 이 값을 보간한다 — 이름이 바뀌면 여기 한 줄만 바뀐다.
# 모듈 docstring 은 f-string 이 될 수 없어 이 상수를 쓰지 못한다. 이름을 바꾸면
# docstring 도 손으로 갱신할 것 (그 드리프트를 잡는 락은 없다).
REVIEW_SKILL = "reviewing-spec"
```

**⒝ 런타임 메시지 6곳을 보간으로 바꾼다.** 각 자리의 현재 문자열과 교체 후:

| 자리 | 현재 | 교체 |
|---|---|---|
| `:89` | `"reviewing-spec 을 직접 호출하라."` | `f"{REVIEW_SKILL} 을 직접 호출하라."` |
| `:466` | `f"({state_path}). 파일을 복구하거나 reviewing-spec 을 직접 호출하라."` | `f"({state_path}). 파일을 복구하거나 {REVIEW_SKILL} 을 직접 호출하라."` |
| `:585` | `"리뷰가 필요하면 reviewing-spec 을 직접 호출하라."` | `f"리뷰가 필요하면 {REVIEW_SKILL} 을 직접 호출하라."` |
| `:700` | `"MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출.",` | `f"MANDATORY: 다음 turn 첫 액션으로 {REVIEW_SKILL} skill 호출.",` |
| `:721` | `"끝났다 — 자동 dispatch를 중단한다. 리뷰가 필요하면 reviewing-spec을 "` | `f"끝났다 — 자동 dispatch를 중단한다. 리뷰가 필요하면 {REVIEW_SKILL}을 "` |
| `:754` | `"systemMessage": "[spec-distill] reviewing-spec dispatch enforced for next turn"` | `"systemMessage": f"[spec-distill] {REVIEW_SKILL} dispatch enforced for next turn"` |

**`:98-99`·`:116`·`:129`·`:150`·`:618` 은 대상이 아니다** — 그것들은 `spec-distill:Stop`·`spec-distill:validator` 같은 **훅 토큰 이름**이지 목적지 skill 이 아니다. 축 A 스윕이 함께 걸리지만 개념이 다르므로 남긴다.

**⒞ `:16` 모듈 docstring 은 리터럴을 유지한다** — 모듈 docstring 은 f-string 이 될 수 없다. 설계 의도를 적는 산문이므로 상수와 함께 **손으로** 갱신한다. 이 드리프트를 잡는 자리가 없다는 사실은 §11 OQ-O 로 남는다.

- [ ] **Step 5: 통과를 확인한다**

```bash
python3 -c "import ast,sys; ast.parse(open('plugins/spec-distill/hooks/review-dispatch.py',encoding='utf-8').read())" && echo "parse OK"
bash plugins/spec-distill/tests/test_review_dispatch.sh
bash plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh
bash plugins/spec-distill/tests/test_arm_once.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_hook_output_schema.py'
```
Expected: 전부 PASS. `test_review_dispatch_design_mandate.sh` 가 mandate 문면을 리터럴로 핀할 수 있으니 RED 면 그 락의 기대 문자열을 확인한다 — **보간 결과가 원문과 바이트 동일해야 한다**(상수 값이 `"reviewing-spec"` 이므로 동일하다).

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/hooks/review-dispatch.py plugins/spec-distill/tests/test_review_dispatch.sh
```

```
refactor(spec-distill): 목적지 skill 이름을 모듈 상수 한 자리로 (묶음 4b)

review-dispatch.py 의 런타임 메시지 6곳이 "reviewing-spec" 을 각자 리터럴로
들고 있었다. 이 훅은 목적지를 직접 호출하지 않고 block 결정과 reason 텍스트를
내므로, 「목적지」는 메시지에 박힌 이름이다 — 상수 하나 + 보간이면 충분하고
그 이상은 전면 데이터-구동이라 기각했다.

상수를 hook_common.py 가 아니라 이 파일에 둔다: 소비자가 이 파일 하나뿐이라
공유 모듈이 필요 없고, hook_common.py 는 형제 작업이 재구성 중이라 범위 밖이다.

락은 「런타임 메시지 전부가 상수 값을 포함한다」로 세웠다. 삭제 변이로는 이빨을
못 잰다 — 상수를 지우면 import 에러로 전부 죽으므로 "함께 죽었다" 가 "한
자리에서 온다" 의 증거가 되지 못한다. 값 변경 변이가 잡히는 형태여야 한다.

모듈 docstring(:16)은 대상이 아니다 — f-string 이 될 수 없어 손 갱신으로 남고,
상수 값과 갈리는 드리프트를 잡는 자리가 없다(OQ-O).

훅 토큰 이름(spec-distill:Stop 등)은 개념이 달라 남긴다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

- [ ] **Step 7: 변이로 이빨을 확인한다 (MU9)**

| 변이 | 무엇을 한다 | 기대 |
|---|---|---|
| **MU9** | `REVIEW_SKILL = "reviewing-spec"` 의 **값을** `"reviewing-spec-v2"` 로 바꾼다 | **GREEN** (전부 보간이면 락은 새 값으로 다시 대조한다) |
| **MU9b** | MU9 상태에서 `:700` 한 줄만 리터럴 `"reviewing-spec"` 으로 되돌린다 | **RED** — 그 자리가 상수 값을 포함하지 않는다. **이것이 MU9 의 본 변이다** |
| **MU9c** | 상수 선언 줄을 지운다 | **RED** — 첫 단언(`REVIEW_SKILL 상수 선언`) + `NameError`. 「함께 죽었다」이므로 증거로는 약하고, 그래서 MU9b 가 정본이다 |

MU9b 가 RED 를 못 내면 락이 「상수를 경유한다」가 아니라 「어딘가에 그 문자열이 있다」를 재는 것이다 — 멈추고 락을 고친다.

각 변이 후 `git checkout -- plugins/spec-distill/hooks/review-dispatch.py` · `git status --porcelain plugins/spec-distill`.

---

### Task 9: 묶음 5 — 다음 감사가 같은 질문을 하게 한다

**Files:**
- Modify: `plugins/plugin-audit/scripts/audit-workflow.js` — 축 3(`n: 3`, `name: 'enforcement 능력'`, 현재 `:343-362`)의 `question` 배열에 항목 추가
- Create: `plugins/plugin-audit/tests/test_axis3_reachability_question.sh` (**MU12**)

**Interfaces:**
- Consumes: 없음
- Produces: 축 3 프롬프트가 **두 질문**을 더 담는다 — ⑴ 모델용 지시가 모델이 읽는 채널로 나가는가 ⑵ 한 산출물이 다음에 넘기는 값에 도착 확인 자리가 있는가.

**형제 겹침:** `audit-workflow.js` 가 형제 계획 `2026-08-23-subagent-adjudication-contract.md:1208`(그쪽 `:589-591`)에 있으나 **그 작업은 머지됐다**(memory: #132·#133). Task 0 Step 2 가 이 판정을 재확인한다. 진행 중인 `hook-write-path-bypass` 목록에는 없다.

**빈칸을 채우는 것이지 축을 만드는 것이 아니다.** 축 3 은 *"대상의 hook/enforcement 가 실제로 무엇을 **막는가**"* 는 묻지만 *"그 지시가 수신자에게 **도달하는가**"* 는 안 묻는다. CLAUDE.md 의 *"버그가 리뷰를 탈출하면 잡았어야 할 reviewer persona 를 편집하는 것이 해결책 — 그 commit 이 compounding 이벤트(Law 3)"* 가 이 형태의 이름이다.

**형태 락으로 충분한 이유:** 축 3 에 더하는 것은 **프롬프트 텍스트**이고, 프롬프트는 텍스트가 곧 산출물이다. 채널의 경우 형태(어느 JSON 키)와 도달(모델이 읽는가)이 갈렸지만, 여기서는 그 절이 프롬프트에 실리는 것이 곧 리뷰어가 그 질문을 받는 것이다. 별도 도달 측정이 필요 없다.

**한계, 명시적으로:** 이 질문은 사용자가 `/plugin-audit` 을 실행할 때만 발화한다. 감사 없이 새 자리가 생기면 여전히 안 묻는다. 상시 발화하는 자리(CLAUDE.md)는 상시 로드 표면을 늘려 기각했다 — 리포가 최근 로드 표면을 19.8% 줄였다(#122).

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다 — MU12**

**`audit-workflow.test.mjs` 에 넣지 않는다 — `AXES` 를 import 할 수 없다.** 실측: `audit-workflow.js:1` 이 `export` 하는 것은 `meta` 하나뿐이고 `AXES` 는 export 없는 모듈 지역 `const` 다. 기존 테스트(`audit-workflow.test.mjs:1-3`)도 `_wf_harness.mjs` 에서 `runWorkflow`·`stubOneFinding`·`DEFAULT_PACK` 만 가져온다. `AXES.find(...)` 를 쓰는 테스트는 **작성 시점에 이미 죽는다.** `AXES` 에 `export` 를 붙이는 길도 있으나, 락 하나를 위해 모듈 공개 표면을 넓히는 것이라 택하지 않았다.

**대신 소스 텍스트 락**을 쓴다 — 리포의 형제 락(`test_qg_publish_offer.sh`)과 같은 형태로 축 3 객체를 awk 창으로 잡는다. **이것으로 충분한 이유는 위에 적었다**: 축에 더하는 것은 프롬프트 텍스트이고 프롬프트는 텍스트가 곧 산출물이다.

`plugins/plugin-audit/tests/test_axis3_reachability_question.sh`:

```bash
#!/usr/bin/env bash
# MU12 — 감사 축 3 이 「지시가 수신자에게 도달하는가」를 묻는가.
#
# AXES 는 audit-workflow.js 의 export 없는 모듈 지역 const 라 import 할 수 없다
# (그 파일이 export 하는 것은 meta 하나뿐). 락 하나를 위해 공개 표면을 넓히는
# 대신 소스 텍스트를 축 3 객체 창으로 잡는다.
#
# 창은 `n: 3,` 부터 `n: 4,` 앞까지 — 파일 전역으로 읽으면 다른 축에 적힌 문구로도
# 만족되고, 새로 더한 줄만으로 읽으면 그 줄이 사라졌을 때 공허참이다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
WF="$REPO_ROOT/plugins/plugin-audit/scripts/audit-workflow.js"
. "$REPO_ROOT/shared/tests/assert.sh"
test -f "$WF" || { echo "FAIL: audit-workflow.js missing at $WF"; exit 1; }

AX3="$(awk '/^[[:space:]]*n: 3,/{f=1} f{print} f&&/^[[:space:]]*n: 4,/{exit}' "$WF")"

# (1) 양성 증인 — 창이 실재한다.
[ -n "$AX3" ] && ok "축 3 창이 실재한다 (앵커 유효)" \
  || no "축 3 창이 비었다 — 앵커가 죽었다. 아래 단언이 공허참이 된다"

# (2) 양성 증인 — 그 창이 축 3 의 원래 질문을 **여전히** 담는다.
#     더하는 것이지 대체하는 것이 아니다.
grep -qF '무엇을 막는가' <<<"$AX3" \
  && ok "축 3 의 원래 질문 보존" \
  || no "축 3 의 원래 질문이 사라졌다 — 추가가 아니라 대체를 했다"
grep -qF 'kill switch' <<<"$AX3" \
  && ok "축 3 의 kill switch 항목 보존" \
  || no "축 3 의 kill switch 항목이 사라졌다"

# (3) 새 질문 — 채널.
grep -qF 'systemMessage' <<<"$AX3" \
  && ok "축 3 이 사람 채널을 이름으로 묻는다" \
  || no "축 3 이 systemMessage 를 사람 채널로 지목하지 않는다"

# (4) 새 질문 — 값 전달의 도착 확인.
grep -qF '도착했는지 확인하는 자리' <<<"$AX3" \
  && ok "축 3 이 값 전달의 도착 확인을 묻는다" \
  || no "축 3 이 도착 확인 자리를 묻지 않는다"

# (5) 축을 만들지 않았다 — AXES 원소는 여섯 그대로.
NAX="$(grep -cE '^[[:space:]]*n: [0-9]+,' "$WF")"
[ "$NAX" -eq 6 ] && ok "AXES 원소 6 유지 (축을 만들지 않았다)" \
  || no "AXES 원소가 ${NAX}개 — 축을 추가·삭제했다. 이 작업은 질문만 더한다"
finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/plugin-audit/tests/test_axis3_reachability_question.sh`

Expected: 단언 (3)(4) **FAIL** — 새 질문이 아직 없다. (1)(2)(5) **PASS** — 양성 증인 + 축 개수. (1) 이 FAIL 이면 `n: 3,` 앵커의 들여쓰기가 정규식과 다른 것이므로 `grep -n 'n: 3,' plugins/plugin-audit/scripts/audit-workflow.js` 로 실제 형태를 보고 awk 패턴을 맞춘다.

- [ ] **Step 3: 최소 구현**

`plugins/plugin-audit/scripts/audit-workflow.js` 의 축 3 `question` 배열에서, `'- kill switch(...)가 실제로 존중되는가 — 코드로 확인하라.',` 줄 **바로 아래**에 두 줄을 더한다:

```javascript
      '- **훅·스킬·커맨드가 모델에게 하는 지시가 모델이 실제로 읽는 채널로 나가는가** —',
      '  `systemMessage` 는 사람 채널이다. 그리고 한 산출물이 다음 산출물에 넘기는 값(경로·인자·',
      '  표식 파일)에 **그것이 도착했는지 확인하는 자리**가 있는가, 아니면 도착을 가정만 하는가.',
```

**기존 항목을 지우지 않는다** — 더하는 것이지 대체하는 것이 아니다.

- [ ] **Step 4: 통과를 확인한다**

```bash
node --check plugins/plugin-audit/scripts/audit-workflow.js && echo "syntax OK"
bash plugins/plugin-audit/tests/test_axis3_reachability_question.sh
node --test plugins/plugin-audit/tests/audit-workflow.test.mjs
node --test plugins/plugin-audit/tests/smoke-workflow.test.mjs
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_preamble_schema_parity.py'
```
Expected: 전부 PASS. `test_preamble_schema_parity.py` 가 축 개수·스키마를 핀할 수 있으니 RED 면 **축을 추가한 것이 아니라 질문을 추가한 것**임을 확인한다(락 (5) 의 `n:` 개수가 6 이어야 한다). `audit-workflow.test.mjs` 는 **건드리지 않는다** — 프롬프트 문자열이 길어졌을 뿐 워크플로 동작은 불변이므로 GREEN 을 유지해야 한다. RED 면 프롬프트 길이·형식을 핀하는 단언이 있다는 뜻이니 그 단언을 읽고 판단한다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/plugin-audit/scripts/audit-workflow.js plugins/plugin-audit/tests/test_axis3_reachability_question.sh
```

```
feat(plugin-audit): 감사 축 3 이 「지시가 도달하는가」를 묻는다 (묶음 5)

축 3(enforcement 능력)은 "대상의 hook 이 무엇을 막는가" 는 묻지만 "그 지시가
수신자에게 도달하는가" 는 안 물었다. 이번 작업이 고친 아홉 자리가 전부 후자의
실패였고, 감사가 그것을 잡을 질문을 갖고 있지 않았다.

축을 만들지 않고 기존 축의 질문 목록에 항목을 더한다 — AXES.length 는 6 그대로다.
기존 항목은 지우지 않는다.

형태 락으로 충분하다: 축에 더하는 것은 프롬프트 텍스트이고 프롬프트는 텍스트가
곧 산출물이다. 채널의 경우 형태(어느 JSON 키)와 도달(모델이 읽는가)이 갈렸지만
여기서는 그 절이 프롬프트에 실리는 것이 곧 리뷰어가 질문을 받는 것이다.

한계: 이 질문은 /plugin-audit 실행 시에만 발화한다. 상시 발화하는 자리
(CLAUDE.md)는 상시 로드 표면을 늘려 기각했다(#122 가 19.8% 줄인 그 표면).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

- [ ] **Step 6: 변이로 이빨을 확인한다 (MU12)**

| 변이 | 무엇을 한다 | 기대 |
|---|---|---|
| **MU12** | 축 3 에서 새로 더한 세 줄을 지운다 | **RED** — 단언 (3)(4) |
| **MU12b** | 새 세 줄을 **축 2** 의 `question` 으로 옮겨 붙인다 | **RED** — awk 창이 `n: 3,` 부터라 축 2 의 문구는 안 잡힌다. 「어딘가에 있다」가 아니라 「그 축에 있다」를 재는지 가른다 |
| **MU12c** | 축 3 의 원래 질문(`무엇을 막는가`)을 지우고 새 질문만 남긴다 | **RED** — 단언 (2). 대체가 아니라 추가임을 지킨다 |
| **MU12d** | 축 3 을 통째로 지운다(`AXES` 가 다섯이 된다) | **RED** — 단언 (1)(5). 창이 죽으면 부재 단언이 공허참이 되는 것을 양성 증인이 잡는다 |

각 변이 후 `git checkout -- plugins/plugin-audit` · `git status --porcelain plugins/plugin-audit`.

---

### Task 10: 버전 bump · CHANGELOG · README

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (5.1.0 → **6.0.0**) · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/README.md`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (0.47.0 → **0.48.0**) · `CHANGELOG.md`
- Modify: `plugins/project-init/.claude-plugin/plugin.json` (3.0.0 → **3.1.0**) · `CHANGELOG.md`
- Modify: `plugins/plugin-audit/.claude-plugin/plugin.json` (0.6.4 → **0.7.0**) · `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1~9 의 모든 변경
- Produces: 네 플러그인의 cache key 가 갱신된다. bump 가 없으면 **cache key 가 silent stale** 이 된다.

**형제 겹침 — 편집 직전 통지 (G11):** 네 `plugin.json` · `CHANGELOG.md` 가 형제 계획 `:377-378`·`:831`·`:1953-1954` 에 전부 올라 있다. **줄 충돌**(버전 리터럴)이고 merge 시 사람이 양쪽 bump 를 합산한다. 통지 문면: *"네 플러그인 plugin.json 을 bump 합니다 — quality-gates 6.0.0(major, 자동 offer 제거) · spec-distill 0.48.0 · project-init 3.1.0 · plugin-audit 0.7.0. 머지 시 버전 충돌이 나면 양쪽 변경을 합산해 더 높은 쪽으로."*

**왜 한 커밋에 넷을 모으나 (D1):** 설계 §8 이 *"네 플러그인 전부 같은 커밋에서 `plugin.json` bump + `CHANGELOG.md` 항목"* 이라고 적었다. PR 단위 규칙(「플러그인을 건드리는 모든 PR 마다 bump」)은 이것으로 충족되고, 묶음마다 bump 하면 spec-distill 이 한 PR 안에서 네 번 올라간다.

- [ ] **Step 1: 형제 통지를 보낸다** (답을 기다리지 않는다)

- [ ] **Step 2: `quality-gates` — major bump + BREAKING 근거**

`plugins/quality-gates/.claude-plugin/plugin.json` 의 `"version": "5.1.0"` → `"6.0.0"`.

`CHANGELOG.md` 최상단(`# 변경 로그` 헤더와 포맷 안내 **아래**, `## [5.1.0]` **위**)에 추가:

```markdown
## [6.0.0] — 2026-09-03

### Removed

- **파이프라인 완료 후 자동 발행 offer 와 그 sentinel `publish-eligible.md`.**
  `publish-eligible.md` 를 쓰는 곳이 둘(Final Summary · Runtime R8), 읽는 곳이
  하나(offer)였다. 읽는 하나를 지우면 소비자가 0 이 되므로 생산도 지운다 —
  아무도 읽지 않는 파일을 계속 쓰는 것이 Law 3 이 이름 붙인 theater 다.
  함께 사라지는 것: `commands/qg.md` 의 offer 절과 Quick Reference 의 자동 offer
  행 · `SKILL.md` 의 sentinel 절·목차·두 쓰기 지점 · `runtime-gate.md` 의 R8
  쓰기 · `setup-qg.sh` 의 stale 청소 두 곳 · `tests/test_qg_publish_offer.sh` ·
  `test_setup_qg.sh` Case 7·8 · `test_skill_orchestration_behavior.sh` 의 배선 락.

  **deprecation window 없이 제거한다.** CLAUDE.md 는 제거 전 one-minor 창을
  요구하지만, 창이 보호하는 대상은 *작동 중인 동작을 잃고 대안이 없는 사용자*다.
  대체 경로 `/qg-publish` 가 이미 출하돼 동일 기능을 제공하고 사라지는 것은 자동
  «제안» 뿐이라 그런 사용자가 존재하지 않는다. **`project-init` v2.2.0 전례를
  인용하지 않는다** — 그 CHANGELOG 이 스스로 *"이 근거는 훅이 blocking 이었다면
  성립하지 않는다"* 고 적었고 offer 는 사용자 상호작용이라 그 단서에 걸린다.
  위 근거는 그것과 다른 근거(대체 경로의 선출하)이며 새로 세운 것이다.

### Changed

- **`hooks/post-tool-use.py` 가 모델용 지시와 사람용 사실을 두 채널로 나눠 낸다.**
  기동 지시("You MUST now initialize …")가 `systemMessage` 하나로만 나갔다. 그
  필드는 번들 문서가 *"Display a message to the user"* 로 적은 사람 채널이고,
  모델 컨텍스트 주입은 `hookSpecificOutput.additionalContext` 다. **옮기지 않고
  둘 다 낸다** — `additionalContext` 의 도달은 실측했으나(`shared/tests/fixtures/
  seamprobe/` 의 `MEAS-M6`) 「사람 채널로 보낸 것을 모델이 못 본다」는 반대 명제는
  재지 않았다. 옮기면 그 미측정 명제에 베팅하면서 사람 수신자를 확실히 잃는다.

### 유지 (혼동 방지)

- `publish-active.md` 는 **삭제 대상이 아니다** — 이름이 비슷하지만 생산자
  (`publishing-pr-understanding/SKILL.md:206`)와 소비자(`hooks/post-tool-use.py:62-68`)가
  둘 다 살아 있고, `/qg-publish` 가 만든 PR 에 파이프라인이 되따라붙는 것을 막는다.
- kill switch `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` 는 **사라지지 않는다.** 진짜
  집행은 최내부 네트워크 sink 둘(`scripts/comment-upsert.py:77` ·
  `scripts/pr-create.sh:17`)이고, 사라지는 것은 offer 계층의 중복 확인 한 겹뿐이다.

### Known gaps

- `scripts/qg-gc.py:49` 의 `SESSION_MARKERS` 와 `references/state-file-format.md:67`
  의 companion-file 서술이 **생산자 없는 참조**로 남는다. 진행 중인 별개 작업이 그
  두 파일에 대해 정반대를 지시해 이번 범위에서 뺐다(사용자 판정). 무해하지만 사문이며,
  그 작업이 끝난 뒤 어느 쪽이 정리할지는 미정이다.
```

`README.md` — Quick Reference/Commands 표에 자동 offer 를 서술하는 줄이 있으면 지운다:

```bash
grep -n 'offer\|publish-eligible' plugins/quality-gates/README.md
```

- [ ] **Step 3: `spec-distill` — minor bump**

`"version": "0.47.0"` → `"0.48.0"`. `CHANGELOG.md` 최상단(`# Changelog` 아래)에:

```markdown
## [0.48.0] — 2026-09-03

### Removed

- **`reviewing-brief` 의 zero-tool probe 선결 조건.** `SKILL.md:107` 이
  `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` 를 **cwd 상대경로**로
  읽고 없으면 파이프라인을 시작하지 않았다. 그 파일은 플러그인 배포 단위 밖이라
  devbrew 리포 밖 사용자에게는 존재하지 않는다 — fail-closed 가 곧 100% 차단이었다.
  현재 판정이 `ZERO_TOOL_OK` 이므로 **오늘 도는 갈래는 차단 게이트**다. 분기를 지우고
  그 갈래만 남긴다 — 완화가 아니라 유지다. **감사 문서 자체는 지우지 않는다**:
  그것이 `tools: []` 집행의 근거 기록이고, 지우는 것은 실행 시점에 그 파일을 읽는
  코드다.
- **`check_brief.py` 의 `next_phase` 값 검사.** 읽는 런타임 소비자가 0 인데
  게이트만 남으면 오타를 통과시키면서 검증하는 것처럼 보인다. 필드는 템플릿에
  정보성 메타데이터로 **남는다**(`test_brief_no_statement_cap.sh:28-32` 가 그 줄을
  앵커로 쓴다).

### Added

- **격리 집합 등식 락 L** (`tests/test_brief_agents.sh`) — `agents/*.md` 중 `tools:`
  가 빈 리스트인 파일 집합이 리터럴 이름 목록 넷과 **같다**. 대상을 `tools: []` 에서
  도출하면 선택자와 술어가 같은 값이 되어, 하나를 `tools: Read` 로 넓히는 변이가 대상
  집합을 벗어나 락이 공허참으로 통과한다. 우변이 리터럴이라 값 넓히기·신규 추가·동시
  이탈 셋이 전부 RED 다. *"각 원소가 `tools: []` 이다"* 는 등식이 함의하므로 두지 않는다.
- `tests/test_brief_review_no_external_precondition.sh` (B1) ·
  `tests/test_check_brief_frontmatter.py` (B4).

### Fixed

- **핸드오프가 네 인자를 넘긴다.** `finishing.md:101` 이 셋만 넘겨 `$AUDIT` 이
  빠졌고, 두 소비자가 함께 무너졌다 — `build_brief_bundle.py` 가 rc 2 로 충실도
  리뷰를 통째 skip 하고 `check_verbatim_coverage.py` 의 §6 결정론 검사가 같은 빈
  값으로 깨진다. `tests/test_brief_review_entry.sh:172`·`:190` 의 락이 결함을
  **요구**하고 있었으므로 같은 커밋에서 넷으로 고쳤다.
- **`/compact` 안내에서 확인되지 않는 도착 주장 철회.** *"compact 후 brainstorming
  진입 준비됨"* 은 압축 뒤의 상태에 대한 주장인데 아무도 확인하지 않는다.

### Changed

- `hooks/review-dispatch.py` 의 목적지 skill 이름이 **모듈 상수 하나**에서 온다.
  런타임 메시지 6곳이 각자 리터럴을 들고 있었다.

### Known gaps

- `review-dispatch.py:16` 의 모듈 docstring 은 f-string 이 될 수 없어 손 갱신으로
  남고, 상수 값과 갈리는 드리프트를 잡는 자리가 없다.
- `/compact` 템플릿의 `<brief-path>` 치환에는 **기계가 없다** — 모델이 사용자에게
  보여준 텍스트를 읽는 훅이 리포에 없다. 이번 작업의 아홉 자리 중 이 한 조각만
  검사 없이 남는다.
```

- [ ] **Step 4: `project-init` — minor bump**

`"version": "3.0.0"` → `"3.1.0"`. `CHANGELOG.md` 에:

```markdown
## [3.1.0] — 2026-09-03

### Changed

- **`hooks/post-tool-use.py` 의 두 validator 가 `(사람 몫, 모델 몫)` 쌍을 반환한다.**
  전에는 평문 문자열 하나를 반환하고 `main()` 이 단일 `systemMessage` 로 합쳐 냈다 —
  브랜치 수정 명령(`git branch -m …`)만 모델 채널로 가르려면 그 문자열이 여전히
  같은 sink 로 흘러가므로 반환 계약을 바꿔야 했다. 사람은 「무엇이 왜 틀렸나」를,
  모델은 「무엇을 실행하나」를 받는다. **둘 다 낸다.**

### 의도적 비대칭 (락으로 고정)

- **커밋 메시지 경고는 `systemMessage` 에 남는다.** 두 검사의 재진입성이 다르다:
  브랜치 개명은 `BRANCH_CREATE_RE`(`checkout -b` / `switch -c`)에 안 걸리지만,
  커밋 메시지 재작성은 고친 메시지로 다시 커밋하면 `COMMIT_MSG_RE` 에 **다시 걸린다.**
  상한을 만들려면 새 가드(세션당 1회 표식)가 필요한데 이 설계는 가드를 만들지
  않기로 했다. 비대칭을 숨기지 않고 테스트로 고정한다.

### Known gaps

- 브랜치 검사 정규식이 `checkout -b`·`switch -c` 두 형태만 잡는다. 브랜치 개명과
  워크트리 생성 시의 브랜치 지정은 안 걸린다. 하드코딩이 아니라 커버리지 갭이라
  이번 범위에 넣지 않았다.
```

- [ ] **Step 5: `plugin-audit` — minor bump**

`"version": "0.6.4"` → `"0.7.0"`. `CHANGELOG.md` 에:

```markdown
## [0.7.0] — 2026-09-03

### Added

- **축 3(enforcement 능력)이 「지시가 수신자에게 도달하는가」를 묻는다.** 그 축은
  *"대상의 hook 이 무엇을 막는가"* 는 묻지만 도달은 안 물었다. 두 질문을 더한다 —
  ⑴ 모델에게 하는 지시가 모델이 실제로 읽는 채널로 나가는가(`systemMessage` 는
  사람 채널이다) ⑵ 한 산출물이 다음에 넘기는 값에 도착 확인 자리가 있는가.
  **축을 만들지 않는다** — `AXES.length` 는 6 그대로이고 기존 항목도 지우지 않는다.

### Known gaps

- 이 질문은 사용자가 `/plugin-audit` 을 실행할 때만 발화한다. 감사 없이 새 자리가
  생기면 여전히 안 묻는다. 상시 발화하는 자리(`CLAUDE.md`)는 상시 로드 표면을 늘려
  기각했다.
```

- [ ] **Step 6: 전 스위트를 돌려 baseline 과 대조한다**

```bash
bash .claude/seam-channel/run-baseline.sh
```

**주의:** 이 실행은 `baseline-2026-09-03.tsv` 를 **덮어쓴다.** 먼저 원본을 보존한다:

```bash
cp .claude/seam-channel/baseline-2026-09-03.tsv .claude/seam-channel/baseline-BEFORE.tsv
bash .claude/seam-channel/run-baseline.sh
cp .claude/seam-channel/baseline-2026-09-03.tsv .claude/seam-channel/baseline-AFTER.tsv
diff .claude/seam-channel/baseline-BEFORE.tsv .claude/seam-channel/baseline-AFTER.tsv
```

**판정:**
- `AFTER` 에만 있는 `FAIL` = **내가 깬 것.** 예상된 RED 목록(Task 3·5·7 이 의도적으로 지운 락)에 있으면 그 파일이 실제로 삭제·수정됐는지 확인하고, 없으면 **멈추고 고친다.**
- `BEFORE` 에만 있는 `FAIL` = 내가 고친 선재 RED(있으면 CHANGELOG 에 적는다).
- 양쪽에 있는 `FAIL` = **선재 RED**, 이번 작업과 무관.

- [ ] **Step 7: 커밋**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/quality-gates/README.md
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git add plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md
git add plugins/plugin-audit/.claude-plugin/plugin.json plugins/plugin-audit/CHANGELOG.md
```

```
chore: 네 플러그인 bump + CHANGELOG (이음매 채널 검증)

quality-gates 5.1.0 → 6.0.0 (major — 출하된 자동 offer 가 사라진다)
spec-distill  0.47.0 → 0.48.0
project-init  3.0.0  → 3.1.0
plugin-audit  0.6.4  → 0.7.0

한 커밋에 넷을 모은다 — 묶음마다 bump 하면 spec-distill 이 한 PR 안에서 네 번
올라간다. bump 가 없으면 cache key 가 조용히 stale 이 된다.

각 CHANGELOG 에 Known gaps 를 적었다: 생산자 없는 참조 둘(범위 밖 판정),
docstring 드리프트를 잡는 자리 부재, /compact 자리표시자에 기계 없음.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01SoaS39Z7qsvULGcJrDT1bn
```

- [ ] **Step 8: 최종 확인**

```bash
git log --oneline 094ecbc..HEAD
git status --porcelain
grep -H '"version"' plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/.claude-plugin/plugin.json plugins/project-init/.claude-plugin/plugin.json plugins/plugin-audit/.claude-plugin/plugin.json
bash shared/tests/test_changelog_integrity.sh
bash shared/tests/test_dispatch_disposition.sh
```

Expected: 커밋 11개(설계 4 + 구현 7 ~ 10) · 작업트리 clean · 네 버전이 위 값 · `shared/tests` 둘 PASS(`test_changelog_integrity.sh` 는 CHANGELOG 형식을, `test_dispatch_disposition.sh` 는 dispatch 처분 앵커를 잰다 — 이 작업이 subagent dispatch 자리를 만들지 않으므로 후자는 불변이어야 한다).

---

## Self-Review — 설계 대조 결과

계획을 다 쓴 뒤 설계와 대조했다. 세 축을 봤다.

### 1. 설계 커버리지 — 빠진 것 없음

| 설계 항목 | 어느 Task |
|---|---|
| §2 묶음 1 (자리 ⑥ ⑧) | Task 1 · Task 2 |
| §3 묶음 2 (자리 ② ④) | Task 3 · Task 4 |
| §4 묶음 3 (자리 ③ ⑦) | Task 5 · Task 6 |
| §5 묶음 4 (자리 ① ⑤) | Task 7 · Task 8 |
| §6 묶음 5 (자리 ⑨) | Task 9 |
| §7.1 MU1–MU12 (12건) | MU1·2 → T1 · MU3·4 → T2 · MU5·6·7 → T5 · MU8 → T7 · MU9 → T8 · MU10·11 → T6 · MU12 → T9 |
| §7.2.4 B1–B4 | B1 → T5 · B2·B3a·B3b → T3 · B4 → T6 |
| §7.2.1 네 축 도출 | Task 0 Step 5 + 각 Task 의 축별 스윕 |
| §7.2.3 예상된 RED vs 선재 RED | Task 0 Step 4 (baseline) + Task 10 Step 6 (BEFORE/AFTER diff) |
| §7.3 작업 순서 | Task 0 → 1·2 → 3·4 → 5·6 → 7·8 → 9 → 10 |
| §8 버전 | Task 10 |
| Handoff D0–D6 | 「이 계획이 소유한 결정」 표 |

### 2. 계획 자신의 결함 셋을 고쳤다 (작성 중 발견)

세 건 다 **계획에 적힌 테스트 코드가 실행 시점에 죽는** 형태였다. 리뷰 없이 실행에 들어갔다면 Task 6·8·9 가 각각 첫 스텝에서 막혔을 것이다.

| # | 무엇이 틀렸나 | 어떻게 고쳤나 |
|---|---|---|
| ⑴ | Task 6 의 `importlib` 로드가 `check_brief.py:66` 의 `import section6` 를 못 푼다 — `spec_from_file_location` 은 그 디렉토리를 `sys.path` 에 넣지 않는다 | `sys.path.insert` 를 명시 |
| ⑵ | Task 8 의 락이 `$SD` 를 쓰는데 `test_review_dispatch.sh` 는 `:4` 에서 `REPO_ROOT` 만 세운다 — `set -u` 아래 **중단**(RED 아님) | `$REPO_ROOT/plugins/spec-distill` 로 |
| ⑶ | Task 9 의 락이 `AXES.find(...)` 를 쓰는데 `audit-workflow.js:1` 이 `export` 하는 것은 `meta` **하나뿐**이고 `AXES` 는 모듈 지역 `const` 다 | `.mjs` 테스트를 버리고 형제 락(`test_qg_publish_offer.sh`)과 같은 **셸 소스 텍스트 락**으로. 락 하나 때문에 모듈 공개 표면을 넓히지 않는다 |

⑵ 와 ⑶ 은 같은 결함형이다 — **형제 파일의 관습을 확인 없이 흉내 냈다.** 리포 지식은 인용해야지 기억으로 풀어 쓰면 메커니즘이 소실된다.

### 3. 설계가 미룬 답 둘을 실측으로 닫았다

| 설계의 미결 | 답 | 근거 |
|---|---|---|
| *"저쪽 `:1699` 의 테스트 12개 중 `test_stale_terms.sh` 가 이쪽 삭제의 영향을 받는지는 계획이 확인한다"* | **받지 않는다** | 그 락은 `plugins/spec-distill/` 아래 production 파일에서 `breadth-keeper`·`interview_round`·v0.23.0 권위 문법 6개를 찾는다(`:1-28`). `ZERO_TOOL_*` 는 그 목록에 없고, 삭제는 원리상 stale term 을 추가할 수 없다 |
| D5 *"표기 변형(`tools: [ ]` 등) 허용 범위"* | `[]` 와 `[ ]` 둘 다 | 새로 정할 것이 아니었다 — 형제 락 `test_seed_agents.sh:131` 의 `case "$tl" in "[]"|"[ ]")` 를 물려받는다 |

### 4. 설계 스냅샷에 없던 형제 하나를 찾았고 무해로 판정했다

설계 §7.3 은 진행 중 형제로 `2026-08-23-hook-write-path-bypass.md` **하나**만 들었다. `grep -n '^- Modify:'` 전수는 `2026-08-31-brief-restructure.md` 도 냈고, 그쪽은 `reviewing-brief/SKILL.md`·`finishing.md`·`check_brief.py`·`interview-audit-template.md`·`test_reviewing_brief_skill.sh` 를 자기 목록에 올려 두어 **이 범위와 정면으로 겹친다.**

**머지 완료로 판정했다** — 그 작업의 산출물이 base `094ecbc` 에 이미 있다(`scripts/section6.py` 실재 · `check_brief.py` 의 `items` 서브커맨드 실재 · audit 템플릿의 `## 6. 사용자 원문` 실재). Task 0 Step 3 이 착수 시점에 이 판정을 다시 확인하고, 셋 중 하나라도 없으면 멈춘다.

### 5. 이 계획이 **재지 않는** 것

- **삭제의 효과.** 재는 것은 「삭제가 무엇을 깨지 않았는지」와 「대체 계약이 실제로 도는지」(B1~B4)뿐이다.
- **증상 개선.** 감사가 발단으로 든 두 증상(「brief 리뷰가 잘 안 불린다」·「qg 가 끝나도 PR 발행으로 안 이어진다」)이 실제로 줄었는지는 이 작업으로 답해지지 않는다. **범위 완료와 증상 개선은 같은 것이 아니다.**
- **`systemMessage` 의 반대 명제.** `MEAS-M6` 은 `additionalContext` 의 도달만 쟀다. N1 이 «옮기기» 가 아니라 «병행» 인 이유가 그것이다.
- **`/compact` 자리표시자 치환.** 검사할 층에 훅이 없다. 완료 주장이 아홉이 아니라 여덟인 이유.

---

## 이월 (설계 §11 에서 그대로 따라온다)

이 계획이 **닫지 않는** 열린 질문. 착수 중에 새로 답이 생기면 해당 CHANGELOG 의 Known gaps 에 적는다.

| # | 무엇 | 왜 안 하나 |
|---|---|---|
| OQ-A | `stop_hook_active` 를 훅이 참조하지 않는다 | 범위 밖. 대상이 이 훅의 유일한 폭주 방지 장치라 회귀 위험이 가장 크다. **처방은 적혀 있다**: 참조를 넣으면 기존 억제의 발동 조건이 줄 수 있는데 스위트로는 안 보인다(GREEN 유지) — 무엇이 그 억제를 트리거하는지 코드에서 **먼저 전수 열거**한 뒤 수정 전후로 집합을 비교하라 |
| OQ-D | 하니스 에이전트 목록이 `tools: []` 넷을 전부 **"All tools"** 로 오표시 | 플러그인 쪽에서 고칠 수단이 없다. 집행 자체는 2026-07-27 probe 가 확인했으므로 표시만 틀렸다. **위험은 다음 저자가 그 목록을 믿고 선언을 «고치는» 것** — L 등식 락이 그 사고를 RED 로 잡는다 |
| OQ-I | `MEAS-M6` 재실행의 **주체** | 트리거(설치 번들 버전 변화 관찰) · 기록(`MEASUREMENT.md` 헤더) · 실행(그 파일의 「재현하는 법」 M6 블록) · 기대(카나리 에코 1/1)는 정해져 있다. 자동 릴리스 게이트로 만들면 새 강제 신설이라 Non-goal |
| OQ-J | `/compact` 자리표시자에 기계가 없다 | 모델이 사용자에게 보여준 텍스트를 읽는 훅이 리포에 없다. 완료 주장을 여덟로 좁힌 근거 |
| OQ-L | `validate_commit` 의 비대칭이 다음 저자에게 어떻게 읽힐지 | 근거는 확실하나(재진입성) 읽힘을 확인하지 않았다. MU4 가 락으로 고정한다 |
| OQ-M | 경로 접두 통합(`arm_ledger.py:41` ↔ `resolve_mode.py:9`) | 형제가 그 파일들을 재구성 중. **착수 조건 셋:** ⑴ `tests/test_arm_ledger.py:512-519` 는 고치는 것이 아니라 **지운다**(지킬 등식이 사라진다) ⑵ `tests/test_discover_candidates.py:20` 이 `PREFIX = arm_ledger.PREFIX` 로 **모듈 속성**을 읽으므로 재노출 형태에 따라 살거나 죽는다 ⑶ 통합 값이 두 소비자에게 같게 도달하는지 확인하는 **값 변경 변이**가 필요하다(MU9 는 목적지 상수 전용이라 이 자리를 안 덮는다) |
| OQ-N | `qg-gc.py:49` · `state-file-format.md:67` 의 생산자 없는 참조 | 형제와 지시 충돌로 범위 밖. 무해하지만 N2 가 금지하는 상태. 그 작업이 끝난 뒤 어느 쪽이 정리할지 미정 |
| OQ-O | 목적지 상수와 `review-dispatch.py:16` docstring 의 드리프트 | 모듈 docstring 은 f-string 이 될 수 없어 손 갱신으로 남고, 갈리는 것을 잡는 자리가 없다 |
| OQ-C·E·F·G·H | 증상 · subagent 왕복 · 스킬↔스크립트 왕복 · 정책 불일치의 나머지 · 훅 커버리지 서술 | 전부 범위 밖 또는 이번 미착수 |
| 관찰 | `project-init` 브랜치 검사 정규식이 `checkout -b`·`switch -c` 두 형태만 잡는다 | 하드코딩이 아니라 커버리지 갭. **이 워크트리의 브랜치가 검사를 안 받은 이유이기도 하다** |

---

## 착수 전 한 번 더 읽을 것

- **작업 위치는 워크트리다.** `cd` 로 메인 리포에 나가지 않는다. `git stash` 는 워크트리 간 공유 스택이라 쓰지 않는다 — 작업을 치워야 하면 임시 WIP 커밋으로.
- **`git add -A` 를 쓰지 않는다.** 범위 밖 파일(G10 의 넷)을 쓸어담는다.
- **변이는 커밋 뒤에.** `git checkout --` 는 HEAD 로 되돌린다. 복원 후 clean 은 성공처럼 보인다.
- **`PYTHONDONTWRITEBYTECODE=1`.** 같은 길이 변이는 stale `.pyc` 를 못 넘어 거짓 GREEN·거짓 RED 를 둘 다 낸다.
- **셸 편집 뒤엔 `bash -n`, 파이썬 편집 뒤엔 `ast.parse`, JS 편집 뒤엔 `node --check`.** 본문 추출기는 조용히 깨지고, 판별 신호는 blast radius 불일치다 — 선스윕이 그것보다 싸다.
- **인용한 사실은 전부 `094ecbc` 의 코드에서 직접 확인했다.** 그 과정에서 인터뷰 서술 셋이 틀린 것으로 드러났다: ⑴ probe 선결조건은 두 자리가 아니라 **네 파일** ⑵ `/compact` 자리의 자동 이어짐 약속은 **존재하지 않는다** ⑶ `<file>` 자리표시자는 **이미 fail-closed** 다. **확정 사실도 면역이 아니다** — 실행 중에도 인용 전에 코드를 본다.
- **배달지 표를 근거로 쓸 때 줄 번호를 조심하라.** `docs/superpowers/specs/2026-08-05-agent-transparency-design.md` 에서 `PostToolUse` ✅ 행은 **`:361`** 이다(`:359` 는 `TaskCreated` ❌ 행). 그리고 그 ✅ 는 **matcher `Agent` 한정**으로 쓰여 있다 — 이 작업의 두 훅은 matcher `Bash` 이고, 그 간극을 메운 것이 `MEAS-M6` 이다.
