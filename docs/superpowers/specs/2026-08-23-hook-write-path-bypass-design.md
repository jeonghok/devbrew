---
name: hook-write-path-bypass
type: design
date: 2026-08-23
next_phase: superpowers:writing-plans
---

# 훅 쓰기-경로 우회 봉쇄 — Design

> `PostToolUse` 는 **도구가 돌았다**를 알려줄 뿐 **그 도구가 무엇을 바꿨는지**는 알려주지 않는다.
> 세 훅은 그 층에서 파일에 대한 불변식을 지키려 했고, 그래서 도구 이름을 열거해야 했다.
> 열거는 언제나 새는 쪽으로 틀린다. 답은 열거를 고치는 것이 아니라 **그 층을 떠나는 것**이다.

## Handoff Context

> 이 설계를 처음 보는 사람(또는 `/compact` 후 자기 자신)이 30초에 핵심을 잡게 하는 블록.
> 대화 컨텍스트를 가정하지 않는다.

**TL;DR** — devbrew 세 플러그인이 `matcher: "Write|Edit|MultiEdit"` 인 `PostToolUse` 훅을 하나씩
가진다. Bash heredoc·`sed -i` 로 같은 파일을 쓰면 그 셋이 전부 안 돈다. 이 설계는 열거를
고치지 않는다. **그 훅들을 없앤다.** spec-distill 의 검사는 이미 존재하는 `Stop` 훅이
흡수하고, quality-gates 와 project-init 의 훅은 삭제한다. 결과적으로 이 리포에
쓰기-matcher `PostToolUse` 훅이 0개가 되어 버그 클래스 자체가 사라진다.

**최종 상태 — 훅 넷이 사라진다**

| 플러그인 | 훅 | 결정 |
|---|---|---|
| spec-distill | `hooks/spec-write-validator.py` (`PostToolUse`) | 삭제 — 기존 `Stop` 훅이 흡수 |
| spec-distill | `hooks/pending-review-reminder.py` (`UserPromptSubmit`) | 삭제 — `pending_review:` 계약 은퇴에 따른 강제 결과 (§4.1) |
| quality-gates | `hooks/post-tool-use-session-tracker.py` | 삭제 — `/qg` scope 를 git 기반으로 |
| project-init | `hooks/docs-lint.py` | 삭제 — 이동 아님, 검사 자체를 제거 |
| project-init | `hooks/post-tool-use.py` (`matcher: "Bash"`) | 손대지 않음 |
| quality-gates | `hooks/post-tool-use.py` (`matcher: "Bash"`) | 손대지 않음 |

spec-distill 은 훅 4개에서 2개(`Stop`·`SessionEnd`)로 줄어든다.

**규모** — 삭제되는 표면을 참조하는 파일은 손으로 센 목록보다 훨씬 많다. 그래서 §10 은
파일을 열거하지 않고 **도출 규칙과 완료 oracle** 을 정한다.

| 삭제되는 표면 | 리포 안 참조 파일 |
|---|---|
| `spec-write-validator` | 17 |
| `pending_review` · `pending-review-reminder` | 23 |
| `files.md` (quality-gates) | 17 |
| `docs-lint` (project-init) | 8 |

**이 설계가 서 있는 실측** (2026-08-22~23, Claude Code 2.1.239)

| 잰 것 | 결과 |
|---|---|
| `spec-write-validator.py` 1회 (경로 불일치 조기 return) | 31.6 ms |
| `post-tool-use-session-tracker.py` 1회 | 23.6 ms |
| `docs-lint.py` 1회 | 26.2 ms |
| 맨 `python3` 기동 | 17.4 ms — 위 비용의 약 70% |
| `git status --porcelain -- <pathspec>` | 12.8 ms |
| `git status` 코드와 `is_born` 의 대응 | `??` ⟺ not born · `A ` ⟺ born · ` M` ⟺ born (§4.2) |
| `PostToolUse` 에서 `matcher` 키 생략 | 전체 도구에 발화 — 이 사실이 §9 AC1 의 형태를 결정한다 |
| subagent 의 Bash heredoc | `PostToolUse`·`PostToolBatch` 둘 다 발화 |

프로브 플러그인은 `shared/tests/fixtures/hookprobe/` 에 이미 커밋돼 있다 (commit `1a37123`).

**암묵 컨텍스트 (문서 밖 근거)**

| 무엇 | 어디서 왔나 |
|---|---|
| 세 플러그인 전부를 대상으로 | 사용자 결정 — 실제 규모를 제시한 뒤 재확인 |
| 훅이 필요한지부터 따진다 — 훅은 비용이다 | 사용자 결정 |
| `docs-lint` 는 이동이 아니라 제거 | 사용자 결정 |
| 한 번에 arm 하는 문서는 하나, 나머지는 advisory | 사용자 결정 |
| `/cancel-review` 를 이 설계에서 분리 | 사용자 결정 — §7 |
| 발단 | 이 리포에서 실제 발생 — 세션 지시가 Bash 쓰기를 요구했고 `docs/superpowers/specs/` 문서 3개가 게이트를 통과하지 않은 채 커밋됨 |

**plan 으로 넘기는 미결**: §14.

## 목차

- [1. 문제](#1-문제)
- [2. 판본 1~4 가 왜 폐기됐나](#2-판본-14-가-왜-폐기됐나)
- [3. 결정 — 쓰기-matcher 훅을 없앤다](#3-결정--쓰기-matcher-훅을-없앤다)
  - [3.1 세 훅이 같은 질문을 하지 않는다](#31-세-훅이-같은-질문을-하지-않는다)
  - [3.2 손대지 않는 것 — `matcher: "Bash"` 훅 둘](#32-손대지-않는-것--matcher-bash-훅-둘)
- [4. spec-distill — 기존 `Stop` 훅이 흡수한다](#4-spec-distill--기존-stop-훅이-흡수한다)
  - [4.1 `pending_review:` 계약을 은퇴시킨다](#41-pending_review-계약을-은퇴시킨다)
  - [4.2 발견 — `git status` 한 번, 그 이상은 없다](#42-발견--git-status-한-번-그-이상은-없다)
  - [4.3 구조 검증 — subprocess 에서 import 로](#43-구조-검증--subprocess-에서-import-로)
  - [4.4 두 종류 block 의 우선순위](#44-두-종류-block-의-우선순위)
  - [4.5 루프 상한 — 도달 후에는 dispatch 도 하지 않는다](#45-루프-상한--도달-후에는-dispatch-도-하지-않는다)
  - [4.6 git 이 없는 리포](#46-git-이-없는-리포)
  - [4.7 kill switch 재편 — 은퇴 토큰에는 발화 주체가 필요하다](#47-kill-switch-재편--은퇴-토큰에는-발화-주체가-필요하다)
- [5. quality-gates — scope 를 git 으로](#5-quality-gates--scope-를-git-으로)
  - [계약을 바꿔야 하는 두 곳](#계약을-바꿔야-하는-두-곳)
- [6. project-init — 제거가 남기는 것](#6-project-init--제거가-남기는-것)
- [7. 이 설계에서 분리한 것 — `/cancel-review`](#7-이-설계에서-분리한-것--cancel-review)
- [8. 비용 — 방향은 이미 유도된다](#8-비용--방향은-이미-유도된다)
- [9. Acceptance Criteria](#9-acceptance-criteria)
- [10. 무엇을 고치는가 — 목록이 아니라 규칙](#10-무엇을-고치는가--목록이-아니라-규칙)
  - [규칙](#규칙)
  - [완료 oracle](#완료-oracle)
  - [oracle 로 덮이지 않는 것 — 반드시 손으로 결정하는 편집](#oracle-로-덮이지-않는-것--반드시-손으로-결정하는-편집)
  - [새로 만드는 것](#새로-만드는-것)
- [11. 검증 계획](#11-검증-계획)
  - [11.1 회귀 락](#111-회귀-락)
  - [11.2 이빨 확인](#112-이빨-확인)
  - [11.3 행동 케이스](#113-행동-케이스)
  - [11.4 선재 RED](#114-선재-red)
- [12. 기각한 대안](#12-기각한-대안)
- [13. 위험](#13-위험)
- [14. 미결](#14-미결)

## 1. 문제

세 플러그인이 같은 모양의 훅을 하나씩 가진다. matcher 가 도구 이름을 열거하므로,
열거 밖의 도구로 같은 파일을 쓰면 훅이 돌지 않는다.

| 플러그인 | 훅 | 열거 밖으로 새면 |
|---|---|---|
| spec-distill | `hooks/spec-write-validator.py` | Law 1 구조 검증이 실행되지 않고 리뷰도 arm 되지 않는다 |
| quality-gates | `hooks/post-tool-use-session-tracker.py` | 변경 파일이 `/qg` 세션 scope 에 안 잡힌다 |
| project-init | `hooks/docs-lint.py` | 문서 컨벤션 검사가 실행되지 않는다 |

열거는 두 층에 있다 — `hooks.json` 의 `matcher` 와 파이썬 스크립트 안의 allowlist
(`spec-write-validator.py:393`, `post-tool-use-session-tracker.py:22`, `docs-lint.py:32`).
합계 여섯 곳이다.

**발단은 가정이 아니라 사건이다.** 이 리포의 한 세션에 *"파일 변경은 Write/Edit 대신
Bash(sed·heredoc·짧은 스크립트)로 하라"* 는 운영 지시가 걸려 있었다. 모델은 그대로 따랐고,
`docs/superpowers/specs/` 의 문서 3개가 Law 1 게이트를 한 번도 통과하지 않은 채 커밋됐다.
kill switch 는 켜지지 않았다. 게이트는 꺼졌다고 **말하지 않고** 꺼졌다.

**세 훅의 심각도는 같지 않다.** spec-distill 만 차단(`exit 2`)한다. quality-gates 는
기록만 하고, project-init 는 `systemMessage` advisory 만 낸다. 그러나 셋 다 같은 구조적
결함을 공유하므로 한 설계에서 다룬다.

## 2. 판본 1~4 가 왜 폐기됐나

이 문서는 다섯 번째 판본이다. 전문은 commit `1a37123`(판본 1~3) 과 `2bc07aa`(판본 4) 에 있다.

| 판본 | 방식 | 깨진 이유 |
|---|---|---|
| 1 | `matcher` 삭제 + payload 의 `file_path` 로 분기 | 도구 열거가 `hooks.json` 밖 파이썬에도 있었다 (세 곳) |
| 2 | 위 + degrade 정교화 | `Read` 의 `tool_input` 도 `file_path` — 읽기만 해도 검증·arm 이 돌았다 |
| 3 | payload 를 안 보고 파일시스템 관찰 + 내용 해시 | 귀속 상실 — `git checkout`·`merge`·에디터 편집이 "이 도구 호출이 바꿨다"가 된다 |
| 4 | 훅 삭제 (현 방향) | 방향은 유지됐다. 삭제 범위를 손으로 열거해 세 번 빠뜨렸고, 락 둘이 서로 모순됐다 |

**핵심 발견은 판본 1~3 이 함께 확인한 것이다.** `PostToolUse` 는 *도구가 돌았다*를 알려줄 뿐
*그 도구가 무엇을 바꿨는지*는 알려주지 않는다. 그 간극을 메우는 길은 둘뿐이고 둘 다
구조적 대가가 있다.

| 길 | 대가 |
|---|---|
| payload 를 읽어 추론 | 도구·스키마 **열거**로 되돌아간다 |
| 파일시스템을 관찰 | **귀속 상실** + 비용이 dirty 집합 크기에 비례 |

**세 번째 길은 그 층에 없다.** 판본 4 부터는 세 번째 길을 찾지 않는다. **질문을 바꾼다** —
"무엇이 바뀌었나" 대신 "지금 불변식이 깨졌나"를 묻는다. 후자는 귀속을 요구하지 않고,
대상 집합을 변경 기록이 아니라 각 플러그인 자신의 규칙에서 도출한다.

**판본 4 가 남긴 교훈은 방향이 아니라 방법이다.** 삭제되는 표면의 소비자를 손으로 열거하면
빠뜨린다 — 세 번 빠뜨렸고 그중 한 번은 `grep` 출력을 `head` 로 자른 결과였다. 그래서 §10 은
목록 대신 **규칙과 완료 oracle** 을 정한다.

## 3. 결정 — 쓰기-matcher 훅을 없앤다

### 3.1 세 훅이 같은 질문을 하지 않는다

각 훅이 실제로 답하려는 질문을 확인하면 셋 중 둘은 "무엇이 바뀌었나"를 아예 필요로 하지
않는다.

| 훅 | 훅이 묻는 것 | 변경 기록이 필요한가 |
|---|---|---|
| project-init `docs-lint` | "이 파일들이 규약을 지키나" — 대상은 고정 4개 + `docs/project/*.md` | 아니오. 대상이 변경과 무관하게 도출된다 |
| spec-distill `spec-write-validator` | "리뷰 안 거친 design doc 이 있나" + 구조 검증 | 아니오. arm-once 원장과 `is_born` 이 이미 **상태** 질문이다 |
| quality-gates `session-tracker` | "이 세션이 건드린 파일 집합" | 예. 누적이 본질이다 |

세 번째(quality-gates)에서 무엇을 잃는가. **오늘의 손실은 scope 축소다** — Bash 로 쓴 파일이
`files.md` 에 안 잡혀 `/qg` 가 좁은 scope 로 돈다. §5 이후에는 그 축소가 **사라진다**:
기본 scope 가 git 에서 도출되므로 어떤 도구로 썼든 같은 답이 나온다.

**정직-verdict floor 를 근거로 들지 않는다.** 판본 4 는 여기서 floor(`resolved scope == 0
AND changes_exist == yes` → `NOT certified clean`, kill 불가)를 안전 근거로 인용했는데,
§5 가 scope 와 floor 를 같은 git 입력 위에 올리면 그 인용은 무의미해진다 — 잡을 축소가
남지 않기 때문이다. floor 자체는 죽지 않는다(모델의 under-resolution, `--paths` scope,
degrade 분기에서 계속 발화한다). 죽는 것은 **floor 를 근거로 삼는 논증**이다. 근거는
축소가 사라진다는 사실 하나로 충분하고, 그것이 더 강하다.

### 3.2 손대지 않는 것 — `matcher: "Bash"` 훅 둘

quality-gates 와 project-init 는 각각 `matcher: "Bash"` 인 두 번째 `PostToolUse` 훅을 가진다.

| 훅 | 무엇을 보나 |
|---|---|
| `project-init/hooks/post-tool-use.py` | `tool_input.command` 문자열 — 브랜치명·커밋 메시지 규약 |
| `quality-gates/hooks/post-tool-use.py` | `tool_input.command` 와 `tool_response.stdout` — `gh pr create` 성공 감지 |

**둘 다 파일이 아니라 명령을 검증한다.** 어느 쪽도 `file_path` 를 읽지 않는다
(project-init 쪽이 `branch-strategy.md` 를 여는 것은 검증 **패턴**을 읽기 위해서지 그
파일을 검증하기 위해서가 아니다). 검사 대상이 명령 자체이므로 `matcher: "Bash"` 가
정확한 표현이고, 쓰기 경로 우회의 영향을 받지 않는다.

이 구분은 락에 반영된다 — §11.1 L1 은 `Bash` 만 담은 matcher 를 **허용**하고, §11.2 는
그 허용을 GREEN 이 정답인 양성 대조로 잠근다.

## 4. spec-distill — 기존 `Stop` 훅이 흡수한다

`review-dispatch.py`(Stop) 는 이미 존재하고, **리뷰 강제가 실제로 일어나는 지점**이다.
`spec-write-validator.py`(PostToolUse) 는 그 훅에 `pending_review:` 라는 연료를 넣어주는
역할이다. 연료 조달을 Stop 훅 자신이 하면 PostToolUse 훅은 필요 없다. **신규 훅은 없다.**

### 4.1 `pending_review:` 계약을 은퇴시킨다

`spec-write-validator.py` 는 `pending_review:` 블록의 **유일한 writer** 다. 그것을 지우면서
블록만 남겨두면 소비자들이 영구히 빈손이 된다. 그래서 계약 자체를 은퇴시킨다.

| 무엇 | 지금 | 판본 5 |
|---|---|---|
| `pending_review:` 블록 | validator 가 쓰고 Stop·reminder 가 읽음 | **은퇴** — 아무도 쓰지 않고 아무도 읽지 않는다 |
| `hooks/pending-review-reminder.py` (`UserPromptSubmit`) | `PENDING_RE` 미검출 시 즉시 `return 0` | **삭제** — 연료가 없어져 영구 no-op |
| `arm_ledger.strip_pending_file` · CLI `strip-pending` | 진입 시 pending 제거 | **은퇴** |
| `skills/reviewing-spec/SKILL.md` Step 1 | pending 을 읽고 strip 호출 | 발견-기반으로 개정 (§10 필수 편집) |
| `last_dispatched_at` + TTL 가드 | pending 검출 **뒤에** 도달 | **유지하되 도달 조건이 바뀐다** — 발견 결과가 비어있지 않을 때 |
| `armed_paths` 원장 · `dispatch_attempts` G6 상한 | 그대로 | 그대로 |

**판본 4 의 "5. TTL 가드 · G6 상한 · 원장 veto (기존 그대로)" 는 거짓이었다.**
`review-dispatch.py:131-133` 은 pending 이 없으면 TTL 가드(`:134-144`) *이전에* `return 0`
한다. pending 을 은퇴시키면 그 진입 조건이 사라지므로, 가드의 도달 조건을 새로 못 박아야
한다. 위 표의 마지막 두 행이 그것이다.

**rewrite 실패 경로.** 오늘은 상태 rewrite 가 실패하면 block 을 억제하고 다음 프롬프트의
reminder 가 줍는다(`review-dispatch.py:21`·`:262`). reminder 가 사라지면 그 backstop 도
사라진다. 대체물은 **발견이 무상태라는 사실**이다 — 다음 `Stop` 이 같은 문서를 다시
발견한다. 다만 `last_dispatched_at` 을 기록하지 못했으므로 TTL 가드가 무력해져 block
storm 위험이 남는다. 그래서 rewrite 실패 시에는 block 을 억제하고 `systemMessage` advisory 를
낸다 — 기존 `state-unreadable` 분기와 같은 모양이며, **loud 하되 루프하지 않는다.**

### 4.2 발견 — `git status` 한 번, 그 이상은 없다

`spec-write-validator.py` 의 `PATH_PREFIX` 는 `docs/superpowers/specs/` 하나뿐이다.

```
git status --porcelain -z -uall --no-optional-locks -- ':(glob)**docs/superpowers/specs/**'
```

| 플래그 | 왜 |
|---|---|
| `-z` | 파일명의 공백·개행·비-UTF-8 바이트가 인용·이스케이프 없이 NUL 구분으로 나온다 |
| `-uall` | 새 하위 디렉토리 안의 문서가 디렉토리 하나로 접히지 않고 파일 단위로 나온다 |
| `--no-optional-locks` | 훅이 인덱스 락을 잡아 사용자의 동시 git 명령을 막지 않는다 |
| `:(glob)**…**` | 접두사를 **어느 깊이에서든** 잡는다 |

**`:(top,literal)` 을 쓰지 않는 이유.** 그것은 리포 최상위에 고정하는데, 이 플러그인의
나머지는 접두사를 경로 **어디에서든** substring 으로 찾는다 — `resolve_mode` 는
`PATH_PREFIX not in file_path`, `canonical_key` 는 `raw_path.find(PREFIX)` 다. 최상위 고정은
중첩 접두 경로를 조용히 후보에서 뺀다. `:(glob)` 이 나머지 코드와 의미를 맞춘다. 둘이
어긋나지 않는다는 것은 L4 가 잠근다.

**born 여부를 status 코드에서 읽는다.** 실측으로 대응이 정확함을 확인했다.

| status 코드 | 상태 | `is_born` | 이 설계의 처분 |
|---|---|---|---|
| `??` | untracked | **거짓** | 구조 검증 + arm 후보 |
| `A ` | `git add` 만 됨 | 참 | 구조 검증만 |
| ` M` · `M ` · `MM` | 커밋 후 수정 | 참 | 구조 검증만 |
| (출력에 없음) | tracked·미수정 | 참 | 대상 아님 |
| `D` · `UU` · `R` · `C` | 삭제·충돌·rename·copy | — | **후보에서 제외** |

삭제된 파일은 읽을 수 없고, 충돌 마커가 든 파일은 구조 검증이 반드시 실패해 사용자가
손대지 않은 문서로 턴을 막는다.

**그러므로 후보당 `git ls-files` 호출이 필요 없다.** 판본 4 는 `should_arm` 을 그대로 두어
후보마다 `arm_ledger.is_born` 을 부르게 했고, 그것이 `GIT_TIMEOUT_SEC=5` 짜리 subprocess 를
문서 수만큼 띄웠다. 발견이 born 플래그를 함께 주면 `should_arm` 은 그 값을 **받아서** 쓴다.
`is_born` 함수 자체는 남는다(다른 호출자가 있다) — 이 경로에서 다시 부르지 않을 뿐이고,
둘이 같은 답을 낸다는 것은 L5 가 잠근다.

**후보 상한.** 한 턴에 구조 검증하는 문서를 5개로 제한한다. 초과분은 이름과 함께
advisory 를 내고 다음 턴에 다시 발견된다. `Stop` 훅의 timeout 이 10초이고 문서 읽기·파싱이
문서 크기에 비례하므로, 상한 없이는 큰 문서 여럿이 훅을 timeout 으로 죽인다 — 그때는
출력도 신호도 남지 않는다.

### 4.3 구조 검증 — subprocess 에서 import 로

`parse_spec_structure.py` 는 순수 함수(`find_missing_sections`·`parse_frontmatter`·
`validate_locked_decisions`·`load_blacklist`·`scan_ambiguity`·`scan_placeholders`)와
CLI 래퍼(`cmd_*`)가 이미 갈라져 있다. 그런데 현재 훅은 순수 함수를 `subprocess.run` 으로
부른다 — design 모드 2회, spec 모드 4회. 각 `cmd_*` 가 파일을 자기가 다시 읽으므로
spec 모드는 같은 파일을 4번 읽는다.

**흡수하면서 import 로 바꾼다.** `review-dispatch.py` 는 이미 `sys.path.insert` 로
`scripts/` 를 넣고 `arm_ledger`·`state_path` 를 import 한다 — 같은 플러그인, 같은 경로,
기존 관례다.

| 무엇 | 지금 (도구 호출당) | 판본 5 (턴당) |
|---|---|---|
| 파서 subprocess | 2 (design) / 4 (spec) | **0** |
| `git` subprocess | 0 (validator 안) + `is_born` 1 | **1** — `git status` |
| 문서 읽기 | 2 / 4 | 후보당 1 |
| 중첩 `timeout` | `call_parser` 의 `timeout=10` 이 훅 timeout 10초 안에 | 없음 |

**시간 예산.** `Stop` 훅 timeout 10초 안에서 `git status` 1회(12.8ms) + 후보 최대 5개의
읽기·파싱이 돈다. 파싱은 in-process 라 프로세스 기동이 없다. 중첩된 하위 프로세스
timeout 이 남지 않는 것이 이 변경의 정확성 이득이며, **비용 이득과는 별개다.**

**모드 판정을 옮긴다.** `resolve_mode` 와 `_frontmatter_has_locked_decisions` 를
`scripts/` 로 옮겨 Stop 훅이 import 한다. `tests/test_resolve_mode_scope.sh` 가 그 함수를
파일 경로로 로드하므로 그 테스트의 로드 경로도 함께 옮긴다 (§10 필수 편집).

### 4.4 두 종류 block 의 우선순위

흡수 후 한 훅이 두 종류의 `decision: block` 을 낼 수 있다.

| 종류 | 사유 | 언제 |
|---|---|---|
| 구조 실패 | Layer 1 이 잡은 ambiguity·placeholder·섹션 누락 | 후보 중 하나라도 검증 실패 |
| 리뷰 강제 | `reviewing-spec` 을 다음 턴 첫 액션으로 | 검증 통과 + arm 자격 |

**구조 실패가 먼저다.** 검증 실패가 하나라도 있으면 그 사유만 block 으로 내고 리뷰
dispatch 는 하지 않는다. 이유는 순서가 아니라 의미다 — 구조가 깨진 문서를 리뷰어에게
보내면 리뷰어가 같은 것을 다시 지적하고, 그 라운드는 `rereview_count` 만 태운다.

한 턴에 하나의 block 만 낸다. 두 사유를 합쳐서 내지 않는다 — 모델이 무엇을 먼저 해야
하는지가 흐려진다.

### 4.5 루프 상한 — 도달 후에는 dispatch 도 하지 않는다

구조 검증이 매 턴 실패하면 매 턴 block 이 나가고, 모델이 고치지 못하면 멈추지 않는다.
CLAUDE.md 의 **Unbounded autonomy** 금지 조항이 직접 걸린다.

`arm_ledger` 의 `dispatch_attempts`(G6, 상한 3)와 **동형의 별도 카운터**
`validation_attempts` 를 문서 키별로 둔다.

- 구조 실패로 block 을 낼 때마다 그 문서의 `validation_attempts` 를 1 증가시킨다.
- 구조 검증을 통과하면 그 문서의 카운터를 삭제한다.
- 상한(3)에 닿으면 그 문서는 이번 세션에서 **구조 검증도 리뷰 dispatch 도 하지 않는다.**

**dispatch 도 멈추는 이유**를 명시한다. 검증 없이 dispatch 하면 §4.4 가 금지한
"구조 깨진 문서를 리뷰어에게 보내기"가 정확히 일어난다. 그러므로 상한 도달은 그 문서를
이번 세션의 자동 경로에서 통째로 내린다.

**그 문서가 Law 1 게이트를 벗어나는 것은 사실이다.** 조용히가 아니라 advisory 와 함께다.
문면은 `dispatch_attempts` 상한의 것과 같은 형태로 **수명 사실만** 적고 면제를 적지 않으며,
사용자가 `reviewing-spec` 을 직접 부르는 경로가 남아 있음을 알린다.

`dispatch_attempts` 를 재사용하지 않는다. 둘은 서로 다른 실패를 세고, 합치면 구조 실패
2회 뒤에 리뷰 dispatch 가 1회밖에 남지 않는다.

### 4.6 git 이 없는 리포

발견이 git 에 의존하므로, git 이 없거나 리포가 아니면 후보가 0이 되고 게이트가 꺼진다.
현재 동작(`is_born` 이 git 실패 시 arm 쪽으로 fail-open)과 방향이 반대다.

**이 설계는 게이트를 끄고 크게 알린다.**

> `[spec-distill] git 을 쓸 수 없어(리포 아님 또는 git 부재) design doc 발견이 불가능하다 —
> 이 세션에서 자동 구조 검증과 리뷰 arm 이 동작하지 않는다. reviewing-spec 을 직접 호출하라.`

세션당 1회만 낸다 (반복 advisory 는 무시되는 신호가 된다). 래치는 state 디렉토리의 마커
파일로 둔다.

**대안을 기각한 이유**: git 이 없을 때 `docs/superpowers/specs/` 전체를 glob 해 후보로
삼으면, 기존 문서 5개가 있는 리포에서 세션마다 5번의 리뷰가 발동한다. Law 1 은 과리뷰를
under-review 보다 선호하지만, 실사용이 불가능한 과리뷰는 kill switch 로 통째 꺼지는
결말을 부른다 — 그것이 최대 fail-open 이다.

이것은 **현재 대비 좁아지는 커버리지**다. §13 R3 에 위험으로 올린다.

**두 번째 좁아짐**: 발견은 훅의 cwd 리포만 본다. 다른 체크아웃(예: main repo 에서 도는
훅이 `<main_repo>/.claude/worktrees/<name>/` 아래의 문서를 볼 때)의 문서는 `git status` 에
나오지 않는다. 오늘의 payload-기반 validator 는 어느 경로가 오든 검사했고, `is_born` 은
바로 그 경우를 위해 절대경로를 **일부러 접지 않는다**(`arm_ledger.py:194-201` 의 측정된
fix). 발견-기반으로 바꾸면 그 커버리지가 줄어든다. §13 R11 에 올린다.

### 4.7 kill switch 재편 — 은퇴 토큰에는 발화 주체가 필요하다

훅 넷이 사라지면 아래 토큰이 가리킬 대상이 없어진다.

| 토큰 | 지금 | 판본 5 |
|---|---|---|
| `DEVBREW_SKIP_HOOKS=spec-distill:validator` | Layer 1 만 끔 | 대상 없음 |
| `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` | Layer 1 만 끔 | 대상 없음 |
| `DEVBREW_SKIP_HOOKS=spec-distill:reminder` · `:UserPromptSubmit` | nag 만 끔 | 대상 없음 |
| `DEVBREW_SKIP_HOOKS=project-init:docs-lint` | docs-lint 만 끔 | 대상 없음 |
| `DEVBREW_SKIP_HOOKS=spec-distill:Stop` · `:review-dispatch` | 리뷰 dispatch 만 끔 | **구조 검증까지 함께 끔** |
| `DEVBREW_SKIP_HOOKS=project-init:PostToolUse` | 훅 둘 다 끔 | 남는 `post-tool-use.py` 를 끔 — 유효 |
| `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` | Layer 1 유지 + arm skip | 그대로 |
| `DEVBREW_SPEC_DISTILL_DISABLE=1` · `DEVBREW_PROJECT_INIT_DISABLE=1` | 전체 | 그대로 |

**deprecation window 에는 발화 주체가 있어야 한다.** `shared/killswitch/kill_switch_active.py`
는 호출자가 넘긴 (plugin, hook, event) 삼중항에만 토큰을 대조한다. 훅을 지우면 그 토큰을
검사하는 주체가 사라지므로, "대상 없음" advisory 를 낼 곳이 없다 — 문서에만 적힌
deprecation window 는 window 가 아니다. CLAUDE.md 는 kill switch 를 보안 컨트롤로 취급한다.

**같은 플러그인의 남은 훅이 낸다.** spec-distill 은 `review-dispatch.py`(Stop),
project-init 은 `post-tool-use.py`(Bash matcher) 가 `DEVBREW_SKIP_HOOKS` 를 파싱해
은퇴 토큰이 있으면 세션당 1회 advisory 를 낸다. 다음 minor 에서 그 검사와 토큰을 함께
제거한다.

**잃는 조합이 하나 있다** — "리뷰는 끄고 구조 검증은 유지". `SKIP_AUTOREVIEW` 가 그 조합의
지정 대체재다 (arm 을 끄고 Layer 1 은 남긴다).

## 5. quality-gates — scope 를 git 으로

`post-tool-use-session-tracker.py` 와 그 산출물 `files.md` 를 제거한다. `/qg` 의 기본 scope 가
"이 세션이 편집한 파일"에서 **git 이 보고하는 변경**으로 바뀐다.

**이것은 관측 가능한 기본 동작 변경이다** — quality-gates 4.2.3 → 5.0.0 (major).

| 무엇 | 지금 | 판본 5 |
|---|---|---|
| 기본 scope 출처 | `files.md` 누적 | base 대비 `git diff` + `git status` + untracked |
| 세션 중 커밋된 변경 | `files.md` 에 남음 | base 대비 diff 가 잡음 |
| Bash 로 쓴 파일 | **누락** | 잡힘 — 이 설계의 목적 |
| 리포 밖 절대경로 편집 | `files.md` 에 남음 | **잡히지 않음** — `--paths` 로 명시 |
| 브랜치 전환 시 | `pre-pipeline-check.sh` 가 `files.md` 를 지움 | 아래 anchor 교체 |

### 계약을 바꿔야 하는 두 곳

목록이 아니라 **계약**이라서 §10 의 도출 규칙으로 덮이지 않는다. 명시한다.

**① `scripts/pre-pipeline-check.sh` 의 staleness anchor.** 결과 코드 `cleared_stale`·
`preserved` 는 `-f "$SESSION_FILE"` 분기 안에서만 도달하고 `cleared_branch_mismatch` 의
삭제 대상도 그 파일이다. `files.md` 가 사라지면 세 코드가 전부 `no_session_data` 로
접히는데, `skills/quality-pipeline/SKILL.md:151-159` 는 이 코드들을 **닫힌 계약**으로
소비한다("모르는 값은 계약 위반이지 fresh 로 취급할 것이 아니다"). anchor 를
`pipeline.md` 로 옮긴다 — 이미 `qg-gc.py` 의 `SESSION_MARKERS` 에 있고 파이프라인 상태의
정본이다. 코드 다섯 종은 그대로 유지된다.

**② `skills/quality-pipeline/SKILL.md` 의 `$resolved_scope_file_count`.** 그 파일
`:513-521` 이 이 값을 정의하며 session 모드를 "`files.md` 항목"에 못 박는다(`:516`).
그것이 정직-verdict floor 의 입력이다. git-도출 scope 에 대해 이 값을 **명시적으로
재정의**한다. `:518-521` 의 "판정 불가를 조용히 0으로 취급하지 말 것" degrade 분기는
그대로 유지한다 — scope 와 floor 가 여전히 갈라질 수 있는 유일한 자리이고, 그것은
신호가 아니라 degrade 다.

## 6. project-init — 제거가 남기는 것

`docs-lint.py`(503줄) 와 `tests/test_docs_lint.py`(1052줄) 를 제거한다. 이동이 아니라 제거다.

**사라지는 검사** — 리포 전수 확인 결과 이것을 대신 수행하는 훅·테스트·게이트는 없다.

| 규칙 | 무엇 |
|---|---|
| R1 | 크기 — 200줄 초과 경고, 300줄 초과 강경 |
| R2 | 300줄 초과 시 목차 |
| R5 | 코드펜스 언어 표기 |
| R6 | 내부 링크 해석 |
| R-pointer | `CLAUDE.md` ↔ `AGENTS.md` drift |
| R-charter | `AGENTS.md` 의 `## Project Charter` 필수 하위항목 — vision·non-goals·tech-stack 의 존재·비어있지 않음·치환되지 않은 자리표시자 잔존 |

**같은 커밋에서 고쳐야 하는 문면 둘.**

`commands/project-init.md:125` 는 헌장 입력이 3회 재질문 후에도 비면 abort 하면서 사용자에게
*"docs-lint이 ## Project Charter 미완을 사후 플래그합니다"* 라고 말한다. docs-lint 가
사라지면 아무도 사후 플래그하지 않는다. **이 약속은 철회한다** — 문면을 사후 플래그를
약속하지 않는 형태로 바꾼다. 문장만 고치고 기능을 남겨두는 것이 아니라, 사후 플래그라는
기능 자체를 제공하지 않는다고 밝힌다.

`commands/project-init.md:227` 은 `.claude/rules/agent-tool-permission.md` 를 `AGENTS.md` 에서
링크하지 않는 이유로 *"docs-lint R6 이 매 쓰기마다 발화한다"* 를 든다. 파일 배치 결정 자체는
유지하되(git 에서 제외되는 파일을 커밋되는 문서가 가리키는 것은 그 자체로 부적절하다)
근거 문장에서 docs-lint 참조를 걷어낸다.

**버전**: project-init 2.1.1 → 3.0.0 (major — 훅 제거는 breaking).

**이 결정이 근거하지 않는 것**: docs-lint 의 6개 규칙이 실전에서 몇 번 발화했는지는 모른다.
훅 출력은 로그로 남지 않는다. 판단은 "무엇을 잃는가"에 근거하며 "그것이 얼마나 아까운가"는
측정되지 않았다. 사용자가 그 값을 알고 제거를 선택했다.

## 7. 이 설계에서 분리한 것 — `/cancel-review`

`/spec-distill:cancel-review` 부활은 이 설계에서 뺀다 (사용자 결정). 두 미해결이 그대로
남아 있다.

1. **session-id 획득 경로가 미지정이고, 그것이 v0.25.0 삭제 근거 (d) 그 자체다.**
   `arm_ledger` CLI 는 `<sid>` 를 인자로 요구하고 `state_path.py` 의 CLI 경로는 환경변수에서만
   sid 를 푼다. sid 가 갈리면 cancel 이 훅이 읽지 않는 파일에 쓰고 **성공을 보고한다.**
2. **`--reset` 은 tracked 문서에 아무 효과가 없다.** `should_arm` 의 `is_born` conjunct 를
   `unmark-reviewed` 가 되돌리지 못한다.

둘 다 sid 해석을 정면으로 다뤄야 풀린다. 그때 §12 의 마지막 항목대로 **기존 kill switch 로
왜 부족한가**를 먼저 기각해야 한다.

## 8. 비용 — 방향은 이미 유도된다

판본 4 는 임계를 세 곳에 서로 다르게 적었다 — 미결로 미룬 곳, 엄격 부등식으로 잠근 곳,
비엄격 부등식으로 잠근 곳. 하나로 정리한다. **방향은 이 문서가 이미 가진 수로 유도된다.**

§10 의 측정 시나리오(도구 호출 30회 — Read 20 · Bash 5 · Write 3 · Grep 2)에서:

| 항 | 계산 | 값 |
|---|---|---|
| 삭제되는 세 훅 | Write 3회 × (31.6 + 23.6 + 26.2) ms | **−244 ms** |
| 삭제되는 reminder 훅 | 프롬프트 1회 × 약 20 ms | **−20 ms** |
| 추가되는 발견 | 이미 도는 `Stop` 훅 안에서 `git status` 1회 | **+13 ms** |
| 후보당 `git ls-files` | §4.2 가 제거 | **0** |
| 예상 순감 | | **약 −250 ms/턴** |

17.4ms 인터프리터 바닥의 한 자릿수 배가 아니라 **한 자릿수 배 이상 큰 마진**이므로,
측정이 방향을 뒤집을 가능성은 낮다. 그래서 임계를 머지 게이트로 쓰지 않는다.

**측정은 여전히 한다.** 프로토콜:

| 무엇 | 어떻게 |
|---|---|
| 기준선 | **현재 코드**의 턴당 누적 훅 시간 |
| 비교군 | 이 설계 적용 후 같은 시나리오 |
| 지표 | 플러그인별 합 **과** 턴 벽시계 **둘 다** (병렬·직렬 여부가 이 차이로 드러난다) |
| 측정 방법 | 측정 전용 `hooks.json` 사본에서 `command` 를 `/usr/bin/time -p` 로 감싸고 stderr 를 파일로 리다이렉트 |

**측정 래퍼를 배포본에 넣지 않는다.** `/usr/bin/time -p` 는 stderr 에 쓰는데 spec-distill 의
집행 채널이 stderr 다. 래퍼가 차단 사유를 오염시킨다. `/usr/bin/time` 은 비-macOS 에서
보장되지 않으므로, 부재 시 측정을 **실패로 보고**하고 추정치를 만들지 않는다.

**AC 는 "측정하고 기록한다"까지다.** 비교군이 기준선보다 크면 머지를 막지 않고 **비-차단
advisory** 를 내고 그 사실을 CHANGELOG 에 적는다 — 위 유도가 틀렸다는 신호이므로 사람이
본다. 자동 게이트로 만들면 잡음이 머지를 좌우한다.

## 9. Acceptance Criteria

각 AC 옆의 괄호는 그것을 재는 수단이다 (§11.1 락 번호 또는 §11.3 행동 케이스 번호).

| # | 기준 | 재는 것 |
|---|---|---|
| AC1 | `plugins/*/hooks/hooks.json` 의 **모든** `PostToolUse` 항목이 `matcher` 키를 가지고, 그 값의 alternation 이 `{Bash}` 의 부분집합이다 | L1 |
| AC2 | 삭제 대상 네 훅 파일이 존재하지 않고, 완료 oracle(§10)이 0 히트를 낸다 | L2 |
| AC3 | `review-dispatch.py` 가 `parse_spec_structure` 의 순수 함수를 import 로 호출하고 반환을 소비한다 | L3 |
| AC4 | `review-dispatch.py` 가 `parse_spec_structure.py`(`PARSE_LIB`)를 subprocess 로 실행하지 않는다 | L3 |
| AC5 | 발견의 pathspec 이 `resolve_mode`·`canonical_key` 와 같은 접두 의미(어느 깊이에서든)를 가진다 | L4 · E11 |
| AC6 | 발견이 born 여부를 status 코드에서 도출하고, 그 값이 `arm_ledger.is_born` 과 모든 코드에서 일치한다 | L5 · E14 |
| AC7 | `pending_review:` 를 쓰는 코드도 읽는 코드도 리포에 없다 | L6 |
| AC8 | Bash heredoc 으로 **미커밋** 스코프 문서를 쓰면 턴 끝에 구조 검증이 돌고 리뷰가 dispatch 된다 | E1 |
| AC9 | Bash `sed -i` 로 **커밋된** 스코프 문서를 고치면 구조 검증은 돌고 arm 은 붙지 않는다 | E2 |
| AC10 | 같은 dirty 문서를 Bash 로 두 번째 편집해도 그 턴에 다시 검증된다 | E3 |
| AC11 | 스코프 문서를 `Read` 로 읽기만 한 턴에는 검증도 dispatch 도 일어나지 않는다 | E4 |
| AC12 | subagent 가 Bash 로 쓴 스코프 문서도 AC8 을 만족한다 | E5 |
| AC13 | 한 턴에 문서 3개가 새로 생기면 셋 다 구조 검증을 받고, dispatch 는 자격 있는 것 중 정렬 첫 하나, 나머지 둘의 이름이 advisory 에 나온다 | L7 · E6 |
| AC14 | 한 턴에 문서 7개가 새로 생기면 5개만 검증되고 나머지 2개의 이름이 advisory 에 나온다 | L8 · E15 |
| AC15 | 구조 검증이 실패하면 그 사유로 block 이 나가고 리뷰 dispatch 는 그 턴에 일어나지 않는다 | L9 · E7 |
| AC16 | 같은 문서의 구조 검증이 3회 실패하면 4회째부터 그 문서는 **검증도 dispatch 도 되지 않고** advisory 만 나간다 | L10 · E8 |
| AC17 | 상태 rewrite 가 실패하면 block 을 내지 않고 `systemMessage` advisory 를 내며, 그 턴에 루프하지 않는다 | L11 · E16 |
| AC18 | git 을 쓸 수 없으면 loud advisory 가 세션당 1회 나가고 검증·dispatch 는 일어나지 않는다 | L12 · E9 |
| AC19 | `git status` 호출이 `-z`·`-uall`·`--no-optional-locks`·`:(glob)` 네 요소를 모두 쓰고, 공백·개행·비-UTF-8 바이트가 든 파일명을 올바르게 파싱한다 | L13 · E10 |
| AC20 | kill switch 검사가 발견·검증·dispatch 를 모두 **지배한다** | L14 · E12 |
| AC21 | 은퇴한 kill switch 토큰이 설정돼 있으면 남은 훅이 세션당 1회 "대상 없음" advisory 를 낸다 | L15 · E17 |
| AC22 | Bash 로 쓴 파일이 `/qg` 기본 scope 에 들어간다 | E13 |
| AC23 | `pre-pipeline-check.sh` 가 다섯 결과 코드를 모두 낼 수 있고, `SKILL.md` 의 닫힌 계약이 유지된다 | L16 · E18 |
| AC24 | `SKILL.md` 가 git-도출 scope 에 대해 `$resolved_scope_file_count` 를 정의하고, 판정 불가 degrade 분기가 남아 있다 | L17 |
| AC25 | `commands/project-init.md` 에 `docs-lint` 참조가 없고, 사후 플래그를 약속하는 문장이 없다 | L18 |
| AC26 | 건드린 각 플러그인의 `plugin.json` 이 `origin/main` 보다 높고 그 CHANGELOG 에 해당 버전 항목이 있다 (플러그인별 독립 판정) | L19 |
| AC27 | 은퇴하는 kill switch 토큰 전부가 해당 플러그인 CHANGELOG 의 Deprecated 항목에 문자 그대로 있다 | L20 |
| AC28 | §8 기준선·비교군 측정값이 CHANGELOG 에 기록된다 | L21 |

## 10. 무엇을 고치는가 — 목록이 아니라 규칙

판본 4 는 파일을 손으로 열거했고 세 번 빠뜨렸다 — quality-gates 의 `SKILL.md`(7 참조,
floor 입력 포함), project-init 의 `smoke.sh` 와 fixture 트리, spec-distill 의 테스트 8개와
prose 4개(persona 파일 포함). 네 번째 목록을 더 정확히 쓰는 것으로는 이 클래스가 닫히지
않는다.

### 규칙

삭제되는 표면마다 **basename 과 계약 이름**을 정하고, 그것을 리포 전수 검색해 나오는
모든 참조를 제거한다. 목록은 구현이 기계적으로 도출한다.

| 삭제되는 표면 | 검색어 |
|---|---|
| spec-distill validator | `spec-write-validator` |
| spec-distill reminder | `pending-review-reminder` · `pending_review` · `strip-pending` · `strip_pending_file` |
| quality-gates tracker | `post-tool-use-session-tracker` · `files.md` |
| project-init lint | `docs-lint` · `test_docs_lint` |

### 완료 oracle

각 검색어에 대해 리포 전수 검색이 **CHANGELOG 밖에서 0 히트**여야 한다. CHANGELOG 는
제거 이력을 남기는 자리이므로 유일한 예외다. 이 oracle 자체가 L2 로 잠긴다.

### oracle 로 덮이지 않는 것 — 반드시 손으로 결정하는 편집

검색으로 나오지만 **삭제가 아니라 재작성**이 필요한 자리다. 지우면 계약이 깨진다.

| 파일 | 무엇 |
|---|---|
| `spec-distill/skills/reviewing-spec/SKILL.md` | Step 1 의 pending 기반 진입을 발견 기반으로 개정. read==write 불변식 단락 재작성 |
| `spec-distill/agents/spec-reviewer.md` | persona 파일 — validator 인용 제거. CLAUDE.md 상 보안-민감 편집이라 별도 검토 |
| `spec-distill/tests/test_brief_review_meta.sh` | T18 의 `hooks/` 정확-집합 열거를 남는 두 파일로 갱신 |
| `spec-distill/tests/test_resolve_mode_scope.sh` | `resolve_mode` 의 로드 경로를 `scripts/` 로 |
| `quality-gates/scripts/pre-pipeline-check.sh` | staleness·branch-mismatch anchor 를 `pipeline.md` 로 (§5 ①) |
| `quality-gates/skills/quality-pipeline/SKILL.md` | `$resolved_scope_file_count` 를 git-도출 scope 로 재정의 (§5 ②) |
| `quality-gates/commands/qg.md` | Scope 절 |
| `project-init/commands/project-init.md` | `:125` 약속 철회 · `:227` 근거 갱신 (§6) |
| 각 `plugin.json` | 0.33.0→0.34.0 · 4.2.3→5.0.0 · 2.1.1→3.0.0 |
| 각 `CHANGELOG.md` | Removed · Changed · Deprecated + §8 측정값 |
| 각 `README.md` | Hooks Installed · 디렉토리 트리 · state 파일 목록 · kill switch 조합 문구 |

### 새로 만드는 것

| 파일 | 무엇 |
|---|---|
| `spec-distill/scripts/discover_candidates.py` | §4.2 의 발견 — `git status` 를 여기서 돈다. `review-dispatch.py` 는 이것을 import 한다 |
| `spec-distill/scripts/parse_spec_structure.py` | `resolve_mode`·`_frontmatter_has_locked_decisions` 수용 (기존 파일에 추가) |
| `spec-distill/scripts/arm_ledger.py` | `validation_attempts` 카운터 + 은퇴 토큰 advisory (기존 파일에 추가) |

**발견을 별도 모듈로 두는 이유**는 락이다. `review-dispatch.py` 가 subprocess-free 라는
주장을 AST 로 잠그려면 `git status` 가 그 파일에 있어서는 안 된다. 모듈로 나누면 L3 이
이빨을 유지하고 L13 이 실재하는 대상을 얻는다.

## 11. 검증 계획

### 11.1 회귀 락

각 락은 **양의 짝과 음의 짝을 함께** 가진다. 음의 짝은 실제 부재 명제여야 한다 —
양의 짝을 말만 바꿔 되풀이한 것은 짝이 아니다.

**대상은 구조에서 도출한다.** L1·L2 는 플러그인 이름을 하드코딩하지 않고
`plugins/*/hooks/hooks.json` 을 glob 으로 열거한다. 네 번째 플러그인이 같은 결함을 들고
들어오면 그때도 RED 여야 한다.

| 락 | 양 (존재) | 음 (부재) |
|---|---|---|
| L1 | 모든 `PostToolUse` 항목이 `matcher` 키를 가지고 그 alternation 이 `{Bash}` 의 부분집합이다 | `matcher` 키가 없는 `PostToolUse` 항목이 하나도 없다 |
| L2 | 남아야 할 훅 파일이 존재하고 `hooks.json` 이 그것을 가리킨다 | §10 의 네 검색어가 CHANGELOG 밖에서 0 히트 |
| L3 | `review-dispatch.py` 가 `parse_spec_structure`·`discover_candidates` 를 import 해 호출하고 반환을 소비한다 (AST) | `review-dispatch.py` 에 `PARSE_LIB`/`parse_spec_structure` 를 인자로 갖는 subprocess 호출이 없다 (AST) |
| L4 | 발견 pathspec 이 `:(glob)` 이고 `resolve_mode`·`canonical_key` 와 같은 문서 집합을 낸다 (대조 테스트) | 발견 pathspec 에 `top` 매직이 없다 |
| L5 | 발견이 낸 born 플래그가 `arm_ledger.is_born` 과 다섯 status 코드 전부에서 일치한다 | 발견 경로에 `is_born` 호출이 없다 (AST) |
| L6 | 남은 상태 필드(`armed_paths`·`dispatch_attempts`·`validation_attempts`·`last_dispatched_at`)를 쓰는 코드가 있다 | 리포에 `pending_review` 문자열이 CHANGELOG 밖에서 없다 |
| L7 | dispatch 대상이 자격 있는 것 중 정렬 첫이고 나머지 이름이 advisory 에 실린다 | dispatch 호출이 루프 안에 없다 (AST) |
| L8 | 후보 상한 상수가 존재하고 초과분 이름이 advisory 에 실린다 | 검증 루프가 상한 없이 후보 전체를 도는 형태가 아니다 (AST) |
| L9 | 구조 실패 경로가 block 을 내고 그 경로에서 dispatch 호출에 도달하지 않는다 (AST 지배 관계) | 두 사유가 한 block 문자열에 합쳐지지 않는다 |
| L10 | `validation_attempts` 상한 도달 분기가 검증과 dispatch 를 **둘 다** 건너뛰고 advisory 를 낸다 | 그 분기에서 dispatch 호출에 도달하는 경로가 없다 (AST) |
| L11 | rewrite 실패 분기가 `systemMessage` 를 내고 `decision` 키를 내지 않는다 | 그 분기에 `decision` 이 없다 |
| L12 | git 불능 분기가 advisory 를 내고 후보 목록을 비운 채 반환하며 래치 마커를 쓴다 | 그 분기가 후보 목록을 반환하지 않는다 |
| L13 | `discover_candidates.py` 의 `git status` 인자에 네 요소가 모두 있고 `-z` 출력을 NUL 로 분해한다 | 넷 중 어느 것도 빠지지 않는다 |
| L14 | kill switch 검사가 발견·검증·dispatch 세 호출을 모두 지배한다 (AST) | kill switch 뒤에 조기 호출이 없다 |
| L15 | 은퇴 토큰 advisory 를 내는 코드가 남은 훅 안에 있고 세션당 1회 래치를 쓴다 | 은퇴 토큰을 `kill_switch_active` 의 삼중항으로 넘기는 호출이 없다 |
| L16 | `pre-pipeline-check.sh` 의 다섯 결과 코드가 모두 도달 가능하다 (분기 대조) | 그 스크립트에 `files.md` 참조가 없다 |
| L17 | `SKILL.md` 가 git-도출 scope 에 대한 `$resolved_scope_file_count` 정의와 판정-불가 degrade 분기를 갖는다 | 그 파일에 `files.md` 참조가 없다 |
| L18 | `commands/project-init.md` 가 존재하고 charter abort 문면이 있다 | 그 파일에 `docs-lint` 문자열이 없고 사후 플래그를 약속하는 문장이 없다 |
| L19 | 건드린 각 플러그인의 `plugin.json` 이 `origin/main` 보다 높고 그 CHANGELOG 에 그 버전 항목이 있다 (플러그인별 독립) | 건드린 플러그인 중 bump 가 빠진 것이 없다 |
| L20 | 각 CHANGELOG 에 Deprecated 항목이 있다 | 은퇴 토큰 중 그 항목에 문자 그대로 없는 것이 없다 |
| L21 | CHANGELOG 에 기준선·비교군 두 수가 있다 | 그 두 수 중 자리표시자로 남은 것이 없다 |

**L19 는 플러그인별로 독립 판정한다.** 판본 4 는 "세 `plugin.json` 이 전부"를 요구해
PR 을 셋으로 쪼개면 어느 PR 도 자기 락을 만족시킬 수 없었다. §14 미결 2 가 PR 형태를
열어둔 상태이므로 락이 그 형태를 전제해서는 안 된다.

### 11.2 이빨 확인

각 락은 **mutation 으로 이빨을 증명한다.** 네 축으로 흔든다 — 삭제·추가·반전·형태 변경.

| 락 | mutation | 기대 |
|---|---|---|
| L1 양 | `hooks.json` 하나를 잘못된 JSON 으로 만든다 | RED |
| L1 음 | 어느 `PostToolUse` 항목에서 `matcher` 키를 **통째로 지운다** | RED |
| L1 음 | 어느 `PostToolUse` 항목에 `"matcher": "Write\|Edit"` 를 되살린다 | RED |
| L1 음 | matcher 를 `"NotebookEdit"` 단독으로 넣는다 | RED |
| L1 | matcher 를 `"Bash"` 로 넣는다 | **GREEN** — 양성 대조 (§3.2 가 허용) |
| L2 양 | `review-dispatch.py` 를 지운다 | RED |
| L2 음 | README 에만 `docs-lint.py` 참조를 남긴다 | RED |
| L2 음 | `pending_review` 를 테스트 파일 하나에만 남긴다 | RED |
| L2 음 | 참조를 CHANGELOG 에만 남긴다 | **GREEN** — 양성 대조 (oracle 의 유일 예외) |
| L3 양 | import 는 남기고 반환값을 버린다 | RED |
| L3 음 | `subprocess.run(["python3", PARSE_LIB, ...])` 를 되살린다 | RED |
| L3 음 | 그것을 `os.popen` 으로 바꾼다 | RED |
| L3 | `discover_candidates.py` 안의 `git status` subprocess | **GREEN** — 양성 대조 (L3 은 파서 subprocess 만 금지한다) |
| L4 | pathspec 을 `:(top,literal)` 로 되돌린다 | RED |
| L4 | 중첩 접두 경로 픽스처를 넣는다 | RED (되돌린 상태에서) |
| L5 | born 을 status 코드 대신 `is_born` 재호출로 바꾼다 | RED |
| L5 | `A ` 를 not-born 으로 매핑한다 | RED |
| L6 양 | `last_dispatched_at` 기록을 지운다 | RED |
| L6 음 | `pending_review` 를 한 곳에 되살린다 | RED |
| L7 | 자격 검사를 빼고 위치만으로 첫 문서를 고른다 | RED |
| L7 | advisory 에서 나머지 문서 이름 나열을 지운다 | RED |
| L8 | 후보 상한을 지운다 | RED |
| L8 | 상한은 두되 초과분 advisory 를 지운다 | RED |
| L9 | 구조 실패 뒤에도 dispatch 로 진행하게 만든다 | RED |
| L9 | 두 사유를 한 문자열로 합친다 | RED |
| L10 | 상한 도달 시 검증만 건너뛰고 dispatch 는 하게 만든다 | RED |
| L11 | rewrite 실패 분기에 `decision: block` 을 넣는다 | RED |
| L12 | git 불능 분기가 후보 전체를 반환하게 되돌린다 | RED |
| L12 | `except` 절을 좁힌다 (`Exception` → `FileNotFoundError`) | RED |
| L13 | 네 요소 각각을 하나씩 지운다 (4회 반복) | RED |
| L13 | `-z` 는 남기고 파싱만 개행 분해로 되돌린다 | RED |
| L14 | kill switch 검사를 발견 호출 **뒤로** 옮긴다 | RED |
| L15 | 은퇴 토큰 advisory 코드를 지운다 | RED |
| L16 | anchor 를 `files.md` 로 되돌린다 | RED |
| L17 | `$resolved_scope_file_count` 정의를 지운다 | RED |
| L17 | 판정-불가 degrade 분기를 지운다 | RED |
| L18 | `:125` 문면을 원래대로 되돌린다 | RED |
| L19 | 건드린 플러그인 하나의 bump 를 빼먹는다 | RED |
| L19 | 건드리지 않은 플러그인을 bump 하지 않는다 | **GREEN** — 양성 대조 (독립 판정) |
| L20 | Deprecated 항목에서 토큰 하나를 지운다 | RED |
| L21 | 측정값 하나를 자리표시자로 남긴다 | RED |

`except` 절 좁히기가 있는 이유: 이 플러그인이 실제로 두 번 겪은 실패 모드다
(`UnicodeDecodeError ⊄ OSError`, `ImportError` vs `Exception`). 방향 반전만 잠그면 좁히기는
통과한다.

**셸 본문 추출기를 쓰지 않는다.** 파이썬 대상 락은 `ast.parse`, 셸 대상은 `bash -n` 으로
먼저 스윕한다 — 이 리포에서 정규식 본문 추출기가 다섯 번 연속 조용히 깨진 이력이 있다.

`PYTHONDONTWRITEBYTECODE=1` 로 돌린다 — 같은 길이 변이는 stale `.pyc` 를 넘지 못해 거짓
GREEN·거짓 RED 를 둘 다 낸다.

**양성 대조**: mutation 전 스위트가 GREEN 인지 먼저 확인한다. RED 자체는 계측기가 살아
있다는 증거가 아니다. 위 표의 네 GREEN 행이 그 대조이며, 그중 하나라도 RED 로 나오면
락이 범위를 넘은 것이다.

### 11.3 행동 케이스

정적 검사로 확인할 수 없는 AC 는 헤드리스 턴으로 잰다.

| # | 무엇을 재나 |
|---|---|
| E1 | Bash heredoc → 미커밋 문서 → 턴 끝 구조 검증 + 리뷰 dispatch |
| E2 | Bash `sed -i` → 커밋된 문서 → 구조 검증 실행, arm 없음 |
| E3 | 같은 dirty 문서를 Bash 로 두 번째 편집 → 그 턴에 다시 검증 |
| E4 | 스코프 문서를 `Read` 만 한 턴 → 무반응 |
| E5 | subagent 의 Bash heredoc → E1 과 동일 결과 |
| E6 | 한 턴에 문서 3개 → 검증 3, dispatch 1, advisory 에 나머지 2 |
| E7 | 구조 실패 문서 → 그 사유로 block, dispatch 없음 |
| E8 | 같은 문서 구조 실패 4턴 반복 → 4턴째 advisory, 검증·dispatch 둘 다 없음 |
| E9 | `PATH` 에서 git 제거 → advisory 1회 + 무발동, 두 번째 턴에는 advisory 없음 |
| E10 | 파일명에 공백·개행·비-UTF-8 바이트 → 파싱 정확 |
| E11 | 새 하위 디렉토리 + 중첩 접두 경로의 문서 → 둘 다 발견 |
| E12 | kill switch 켬 → 발견·검증·dispatch 전부 무발동 |
| E13 | Bash 로 쓴 파일이 `/qg` 기본 scope 에 등장 |
| E14 | 다섯 status 코드 픽스처 → 발견의 born 플래그가 `is_born` 과 전부 일치 |
| E15 | 한 턴에 문서 7개 → 검증 5, advisory 에 나머지 2 |
| E16 | state 디렉토리를 읽기전용으로 → block 없음 + `systemMessage` 1회 |
| E17 | 은퇴 토큰을 `DEVBREW_SKIP_HOOKS` 에 설정 → 세션당 1회 "대상 없음" advisory |
| E18 | 브랜치 전환·24시간 경과·정상 → `pre-pipeline-check.sh` 가 서로 다른 세 코드를 낸다 |

프로브 플러그인과 재현 커맨드는 `shared/tests/fixtures/hookprobe/` 에 이미 커밋돼 있다.
`--permission-mode acceptEdits` 없이는 편집이 rc 0 으로 조용히 죽으므로 반드시 붙인다.
임시 디렉토리는 만든 직후 `pwd -P` 로 한 번 정규화한다 — macOS 의 `/tmp` 는 `/private/tmp`
심볼릭 링크라 경로 포함 검사가 조용히 무너진다.

**픽스처를 먼저 검증한다.** E14 의 다섯 status 코드 픽스처를 만들 때 `git commit` 은
이미 staged 된 것을 함께 커밋하므로, staged-only 케이스가 조용히 사라진다 — 이 설계를
쓰는 동안 실제로 겪었고 계측기가 틀린 답을 냈다. 픽스처가 의도한 다섯 상태를 실제로
만들었는지 `git status` 출력으로 먼저 확인한 뒤 본 검사를 돌린다.

### 11.4 선재 RED

작업 전에 세 플러그인 테스트 스위트의 기준선을 캡처한다. quality-gates 에는 `main` 에
선재 RED 가 있는 것으로 기록돼 있어, 그것을 이번 변경의 회귀로 오인하지 않기 위해서다.
기준선 목록에 올리는 각 항목에는 **왜 면제인지 한 줄**을 함께 적는다 — 이유 없는 면제
목록은 그 질문을 영구히 닫는다.

## 12. 기각한 대안

| 대안 | 왜 기각했나 |
|---|---|
| **matcher 에 `Bash` 추가 + 명령어 파싱** | `cat >`·`tee`·`sed -i`·`>>`·`printf`·`perl -i`·`mv`·`git apply` — 열거를 하나 빠뜨릴 때마다 조용한 fail-open. 고치려는 결함을 한 층 아래로 옮긴다 |
| **matcher 에 `Bash` 만 추가 (열거를 정직하게)** | Bash payload 에는 `file_path` 가 없다. 발화한 뒤 무엇을 검사할지가 미정이라 단독으로 성립하지 않는다. 게다가 훅이 모든 호출에 돌아 비용이 배 이상이 된다 |
| **payload 의 `file_path` 로 분기** | `Read` 의 `tool_input` 도 `file_path` 다. 읽기만 해도 검증·arm 이 돈다 — 도구 열거의 재발 (판본 2 의 실패) |
| **`shared/writewatch/` 감지 모듈** | 판본 3 의 방식. 귀속 상실 — `git checkout`·`merge`·에디터 편집이 "이 도구 호출이 바꿨다"가 되어 사용자가 손대지 않은 문서로 턴이 막힌다 |
| **`UserPromptSubmit` 기준선 + 내용 해시** | 위 모듈의 부속. 기준선을 남의 훅에 얹으면 그 훅의 조기 return 경로에 삼켜지고, 그 훅의 kill switch 가 Law 1 기준선까지 끈다 |
| **`pending_review:` 를 Stop 훅이 계속 쓴다** | reminder 훅과 strip 계약을 살리려면 그렇게 해야 하는데, 발견이 무상태라 pending 은 아무 정보도 더하지 않는다. 계약을 살리려고 계약을 위한 데이터를 쓰는 모양이 된다 (§4.1) |
| **후보당 `is_born` 재호출** | 판본 4 의 방식. `git ls-files` 를 문서 수만큼 띄워 `Stop` 훅 timeout 안에 중첩 timeout 을 만든다. status 코드가 같은 답을 이미 준다 (§4.2) |
| **`:(top,literal)` pathspec** | 리포 최상위에 고정돼 중첩 접두 경로를 조용히 뺀다. 플러그인의 나머지는 substring 의미를 쓴다 (§4.2) |
| **후보 상한 없이 전부 검증** | 큰 문서 여럿이면 `Stop` 훅이 timeout 으로 죽고 출력도 신호도 안 남는다 |
| **`os.scandir` 전수 스캔** | 제외 규칙(`.git`·`node_modules`·`.gitignore`)을 손으로 만들어야 하고 그 목록이 **또 하나의 열거**가 된다. git 은 그 규칙을 이미 안다 |
| **`PostToolBatch` 로 교체** | matcher 가 없어 열거 문제는 사라지지만 `exit 2` 가 "루프 정지 + stderr 는 사용자에게만"이라 구조 검증의 모델 피드백을 잃는다 |
| **`FileChanged` 로 파일 감시** | 층위는 가장 정확하나 집행력이 없고(exit≠0 이 사용자에게만 간다), 실측에서 matcher 3변형 모두 0건이었다. `Stop` 로 옮기면 이 이벤트가 답하려던 질문 자체가 없어진다 |
| **`PreToolUse` 로 Bash 쓰기 차단** | 명령어 파싱이 필요해 첫 항목과 같은 fail-open 을 물려받고, 오탐이 무관한 명령을 막는다 |
| **문서로만 "spec 문서는 Write 로 쓰라"** | 이 리포는 프롬프트 수준 분리를 집행으로 인정하지 않는다 (Law 2 의 논리). 이번 사건 자체가 그 규정이 세션 지시에 밀린 사례다 |
| **project-init `docs-lint` 를 `Stop` 훅으로 이동** | 사용자가 검사 자체의 제거를 선택했다. 이동하면 훅 수가 줄지 않고 kill switch deprecation 만 늘어난다 |
| **project-init `docs-lint` 를 `post-tool-use.py` 에 병합** | 명령 검증과 파일 규약 검사라는 다른 두 관심사가 한 프로세스에 들어가고, matcher 를 지워야 하므로 Bash 아닌 호출에서도 깨어난다 |
| **qg 세션 scope 를 다른 누적 수단으로 유지** | 누적은 어느 수단으로 하든 귀속을 요구한다. §3.1 대로 축소 자체가 사라지므로 누적을 버리는 비용이 작다 |
| **삭제 대상 파일 목록을 손으로 열거** | 판본 4 가 그렇게 했고 세 번 빠뜨렸다. 네 번째 목록이 더 정확하리라는 근거가 없다 (§10) |
| **임계 부등식을 머지 게이트로** | §8 의 유도상 예상 마진이 인터프리터 바닥의 한 자릿수 배를 넘으므로, 자동 게이트는 잡음에 좌우될 뿐 정보를 더하지 않는다 |
| **`/cancel-review` 대신 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`** | v0.25.0 이 사전 옵트아웃의 지정 대체재로 명시한 스위치다. §7 분리에 따라 후속 설계가 먼저 결론지어야 한다 |

**뒤집힌 기각 하나.** 판본 3 은 *"`Stop` 훅 턴-끝 전수 검사"* 를 기각했고 사유는
**"quality-gates·project-init 에 `Stop` 훅이 없어 새 훅 둘이 필요하고, 피드백이 턴 끝으로
밀린다"** 였다. 판본 4 부터 이 기각을 뒤집는다. 두 근거가 각각 무너졌다:

1. **새 훅 둘이 필요하지 않다.** 두 플러그인의 훅을 *삭제*하기로 했으므로 `Stop` 훅을 만들
   대상이 없다. spec-distill 은 `Stop` 훅을 이미 가진다 — 신규 훅은 0개다.
2. **피드백 지연이 실제보다 크게 서술됐다.** `PostToolUse` 는 쓰기가 **일어난 뒤** 도는
   훅이라 지금도 문제 있는 내용은 디스크에 앉는다. `Stop` 으로 옮기면 모델이 *언제 아는지*만
   바뀌고, `decision: block` 으로 되돌아온 모델은 같은 턴 안에서 고친다.

미래 리뷰가 이 기각을 다시 들고 오지 않도록 여기 남긴다.

## 13. 위험

| # | 위험 | 완화 |
|---|---|---|
| R1 | `Stop` 훅의 `decision: block` 이 폭주한다 | `review-dispatch.py` 는 이미 TTL 가드·`dispatch_attempts` G6 상한·`armed_paths` veto 로 막혀 있다. 단 TTL 가드의 도달 조건이 pending 에서 발견 결과로 바뀌므로 그 재-anchor 를 §4.1 이 명시한다. 신규 실패 모드에는 §4.5 의 `validation_attempts` 를 둔다. L10·L11 이 잠근다 |
| R2 | 구조 검증이 턴 끝으로 밀려 모델이 문제 있는 문서 위에 계속 쌓는다 | 한 턴 안의 손실이다. `PostToolUse` 도 쓰기 뒤에 돌므로 차이는 "도구 호출 몇 개" 분량이다 |
| R3 | git 불능 리포에서 게이트가 조용히 꺼진다 | §4.6 의 loud advisory. L12 가 양·음 양쪽을 잠근다 |
| R4 | qg 기본 scope 가 리포 밖 절대경로 편집을 놓친다 | `--paths` 로 명시한다. §5 표에 이름으로 적는다 |
| R5 | 한 턴에 여러 문서가 바뀌어 일부가 조용히 리뷰를 잃는다 | §4.2 의 상한 초과분과 §4.4 의 나머지를 **이름과 함께** 노출한다. L7·L8 이 잠근다 |
| R6 | project-init 의 문서 규약 검사가 영구히 사라진다 | 사용자가 손실을 알고 선택했다. §6 이 사라지는 규칙을 이름으로 적고 `:125` 의 약속을 같은 커밋에서 철회한다 |
| R7 | kill switch 조합 하나가 사라진다 ("리뷰만 끄고 구조 검증 유지") | `SKIP_AUTOREVIEW` 가 지정 대체재다. §4.7 이 은퇴 토큰의 발화 주체를 지정한다. L15·L20 이 잠근다 |
| R8 | 세 플러그인이 한 PR 에 major bump 셋을 싣는다 | 락을 플러그인별 독립 판정으로 만들어 PR 형태를 강제하지 않는다 (L19). 형태 결정은 §14 미결 2 |
| R9 | 이 설계 문서 자신이 Bash 로 쓰여 게이트를 우회한다 | 이 문서는 `Write` 도구로 작성했다. 후속 편집도 `Write`·`Edit` 로 한다. 이 세션에는 Bash 쓰기를 지시하는 운영 모드가 걸려 있으므로 그 예외를 명시적으로 적용한다 |
| R10 | codex co-reviewer 부재로 공유-맹점이 검사되지 않는다 | 사용 한도가 2026-09-17 까지 소진돼 있다(실제 호출 2회로 확인). 판본 1~4 와 같은 한계다. 리뷰 결과에 degrade 로 표시하고, 한도 복구 후 재검토를 §14 미결 3 에 올린다 |
| R11 | 다른 체크아웃의 문서가 발견에서 빠진다 | §4.6 두 번째 좁아짐. 오늘의 payload 기반 validator 는 어느 경로든 검사했다. 워크트리에서 작업할 때는 그 워크트리에서 세션을 열면 커버된다 — 그 사실을 README 에 적는다 |
| R12 | `pre-pipeline-check.sh` 의 anchor 교체가 세 결과 코드의 의미를 바꾼다 | L16 이 다섯 코드의 도달 가능성을 잠그고 E18 이 실제로 셋을 만들어 낸다. `SKILL.md` 의 닫힌 계약은 유지된다 |
| R13 | persona 파일(`agents/spec-reviewer.md`) 편집이 리뷰어를 약화시킨다 | CLAUDE.md 상 persona 편집은 보안 리뷰 대상이다. 이번 편집은 삭제된 파일 경로의 인용 제거로 한정하고, 규칙·임계는 건드리지 않는다 — 그 한정을 PR 설명에 명시한다 |

## 14. 미결

| # | 무엇 | 누가 언제 |
|---|---|---|
| 1 | `/cancel-review` (§7) — sid 획득 경로와 `--reset` 의 tracked 문서 무효 | 이 사이클 이후 별도 설계 |
| 2 | 세 플러그인을 한 PR 로 낼지 셋으로 쪼갤지 (락은 두 형태 모두 허용) | plan 단계 |
| 3 | codex 한도 복구(2026-09-17) 후 이 설계의 재검토 여부 | 사용자 판단 |
