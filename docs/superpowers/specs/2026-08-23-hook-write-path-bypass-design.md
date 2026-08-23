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

**이 문서는 결정을 적는다.** 도구 동작에 대한 사실 — git pathspec 문법, `git status` 코드의
전수 조합, `-z` 출력의 필드 구조, 락 술어의 정확한 표현 — 은 여기서 단정하지 않는다.
그런 사실은 **테스트 옆에서 확정된다.** 이 문서가 그것들을 산문으로 주장했을 때 다섯
라운드 연속으로 틀렸고, 매번 새로운 방식으로 틀렸다. 아래 §9·§11 은 *무엇이 참이어야
하는가*를 적고 *어떻게 표현하는가*는 plan 과 구현에 맡긴다.

## Handoff Context

> 이 설계를 처음 보는 사람(또는 `/compact` 후 자기 자신)이 30초에 핵심을 잡게 하는 블록.

**TL;DR** — devbrew 세 플러그인이 `matcher: "Write|Edit|MultiEdit"` 인 `PostToolUse` 훅을
하나씩 가진다. Bash heredoc·`sed -i` 로 같은 파일을 쓰면 그 셋이 전부 안 돈다. 이 설계는
열거를 고치지 않는다. **그 훅들을 없앤다.** spec-distill 의 검사는 이미 존재하는 `Stop`
훅이 흡수하고, quality-gates 와 project-init 의 훅은 삭제한다. 결과적으로 이 리포에
쓰기-matcher `PostToolUse` 훅이 0개가 되어 버그 클래스 자체가 사라진다.

**최종 상태**

| 플러그인 | 훅 | 결정 |
|---|---|---|
| spec-distill | `hooks/spec-write-validator.py` (`PostToolUse`) | 삭제 — 기존 `Stop` 훅이 흡수 |
| spec-distill | `hooks/pending-review-reminder.py` (`UserPromptSubmit`) | 삭제 — §4.1 |
| quality-gates | `hooks/post-tool-use-session-tracker.py` | 삭제 — scope 를 git 기반으로 |
| project-init | `hooks/docs-lint.py` | 삭제 — 이동 아님, 검사 자체를 제거 |
| project-init · quality-gates | `hooks/post-tool-use.py` (`matcher: "Bash"`) | 손대지 않음 — §3.2 |

spec-distill 은 훅 4개에서 2개(`Stop`·`SessionEnd`)로 줄어든다. 신규 훅은 없다.

**규모** — 삭제되는 표면을 참조하는 파일은 손으로 센 목록보다 많다. 그래서 §10 은 파일을
열거하지 않고 규칙을 정한다.

| 삭제되는 표면 | `plugins/` 안 참조 파일 |
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
| `PostToolUse` 에서 `matcher` 키 생략 | **전체 도구에 발화** |
| subagent 의 Bash heredoc | `PostToolUse`·`PostToolBatch` 둘 다 발화 |

프로브 플러그인은 `shared/tests/fixtures/hookprobe/` 에 커밋돼 있다 (commit `1a37123`).

**암묵 컨텍스트 (문서 밖 근거)**

| 무엇 | 어디서 왔나 |
|---|---|
| 세 플러그인 전부 | 사용자 결정 — 실제 규모를 제시한 뒤 재확인 |
| 훅은 비용이므로 필요한지부터 따진다 | 사용자 결정 |
| `docs-lint` 는 이동이 아니라 제거 | 사용자 결정 |
| 한 번에 dispatch 하는 문서는 하나, 나머지는 advisory | 사용자 결정 |
| `/cancel-review` 분리 | 사용자 결정 — §7 |
| 기계적 세부를 설계에서 내린다 | 사용자 결정 — 리뷰 5라운드 후 |
| 발단 | 이 리포에서 실제 발생 — 세션 지시가 Bash 쓰기를 요구했고 `docs/superpowers/specs/` 문서 3개가 게이트를 통과하지 않은 채 커밋됨 |

## 목차

- [1. 문제](#1-문제)
- [2. 확정된 것과 폐기된 것](#2-확정된-것과-폐기된-것)
- [3. 결정](#3-결정)
  - [3.1 세 훅이 같은 질문을 하지 않는다](#31-세-훅이-같은-질문을-하지-않는다)
  - [3.2 손대지 않는 것 — `matcher: "Bash"` 훅 둘](#32-손대지-않는-것--matcher-bash-훅-둘)
- [4. spec-distill — 기존 `Stop` 훅이 흡수한다](#4-spec-distill--기존-stop-훅이-흡수한다)
  - [4.1 `pending_review:` 는 은퇴하되 in-flight 는 남는다](#41-pending_review-는-은퇴하되-in-flight-는-남는다)
  - [4.2 발견 — git 은 상계, 판정은 코드의 술어](#42-발견--git-은-상계-판정은-코드의-술어)
  - [4.3 구조 검증 — subprocess 에서 import 로](#43-구조-검증--subprocess-에서-import-로)
  - [4.4 순서와 상한](#44-순서와-상한)
  - [4.5 git 이 없는 리포](#45-git-이-없는-리포)
  - [4.6 kill switch 재편](#46-kill-switch-재편)
- [5. quality-gates — scope 를 git 으로](#5-quality-gates--scope-를-git-으로)
  - [계약을 바꿔야 하는 두 곳](#계약을-바꿔야-하는-두-곳)
- [6. project-init — 제거가 남기는 것](#6-project-init--제거가-남기는-것)
- [7. 이 설계에서 분리한 것 — `/cancel-review`](#7-이-설계에서-분리한-것--cancel-review)
- [8. 비용](#8-비용)
- [9. 구현이 만족해야 하는 것](#9-구현이-만족해야-하는-것)
- [10. 무엇을 고치는가 — 목록이 아니라 규칙](#10-무엇을-고치는가--목록이-아니라-규칙)
  - [규칙](#규칙)
  - [정의역 — 무엇이 "살아있는 소비자 표면"인가](#정의역--무엇이-살아있는-소비자-표면인가)
  - [oracle 로 덮이지 않는 것 — 반드시 손으로 결정하는 편집](#oracle-로-덮이지-않는-것--반드시-손으로-결정하는-편집)
  - [새로 만드는 것](#새로-만드는-것)
- [11. 검증에 요구되는 것](#11-검증에-요구되는-것)
  - [성질](#성질)
  - [mutation](#mutation)
  - [행동 케이스](#행동-케이스)
  - [선재 RED](#선재-red)
- [12. 기각한 대안](#12-기각한-대안)
- [13. 위험](#13-위험)
- [14. 미결 — plan 이 답해야 하는 것](#14-미결--plan-이-답해야-하는-것)

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
기록만 하고, project-init 는 advisory 만 낸다. 셋 다 같은 구조적 결함을 공유한다.

## 2. 확정된 것과 폐기된 것

**핵심 발견** — 판본 1~3 이 세 방향에서 확인했다. `PostToolUse` 는 *도구가 돌았다*를
알려줄 뿐 *그 도구가 무엇을 바꿨는지*는 알려주지 않는다. 간극을 메우는 길은 둘뿐이다.

| 길 | 대가 |
|---|---|
| payload 를 읽어 추론 | 도구·스키마 **열거**로 되돌아간다 |
| 파일시스템을 관찰 | **귀속 상실** + 비용이 dirty 집합 크기에 비례 |

**세 번째 길은 그 층에 없다.** 그래서 이 설계는 세 번째 길을 찾지 않고 **질문을 바꾼다** —
"무엇이 바뀌었나" 대신 "지금 불변식이 깨졌나"를 묻는다. 후자는 귀속을 요구하지 않고,
대상 집합을 변경 기록이 아니라 각 플러그인 자신의 규칙에서 도출한다.

**폐기된 접근** (전문은 commit `1a37123`·`2bc07aa`·`adb123e`): matcher 삭제 + payload 분기
(판본 1·2), `shared/writewatch/` 감지 모듈 + 내용 해시 + `UserPromptSubmit` 기준선 (판본 3).
기각 사유는 §12.

## 3. 결정

### 3.1 세 훅이 같은 질문을 하지 않는다

| 훅 | 훅이 묻는 것 | 변경 기록이 필요한가 |
|---|---|---|
| project-init `docs-lint` | "이 파일들이 규약을 지키나" — 대상은 고정 4개 + `docs/project/*.md` | 아니오 |
| spec-distill `spec-write-validator` | "리뷰 안 거친 design doc 이 있나" + 구조 검증 | 아니오 — arm-once 원장과 `is_born` 이 이미 **상태** 질문이다 |
| quality-gates `session-tracker` | "이 세션이 건드린 파일 집합" | 예 — 누적이 본질이다 |

세 번째에서 **오늘의 손실은 scope 축소**다 — Bash 로 쓴 파일이 `files.md` 에 안 잡혀
`/qg` 가 좁은 scope 로 돈다. §5 이후에는 그 축소가 **사라진다**: 기본 scope 가 git 에서
도출되므로 어떤 도구로 썼든 같은 답이 나온다.

**정직-verdict floor 를 근거로 들지 않는다.** floor(`resolved scope == 0 AND changes_exist
== yes` → `NOT certified clean`)는 scope 와 같은 git 입력 위에 올라오면 이 손실에 대해
발화할 일이 없어진다. floor 자체는 죽지 않는다(모델의 under-resolution, `--paths` scope,
degrade 분기에서 계속 발화한다) — 죽는 것은 floor 를 근거로 삼는 논증이다. 축소가
사라진다는 사실 하나로 충분하고, 그것이 더 강하다.

### 3.2 손대지 않는 것 — `matcher: "Bash"` 훅 둘

| 훅 | 무엇을 보나 |
|---|---|
| `project-init/hooks/post-tool-use.py` | `tool_input.command` — 브랜치명·커밋 메시지 규약 |
| `quality-gates/hooks/post-tool-use.py` | `tool_input.command` 와 `tool_response.stdout` — `gh pr create` 성공 감지 |

**둘 다 파일이 아니라 명령을 검증한다.** 어느 쪽도 `file_path` 를 읽지 않는다 (adversarial
검증으로 양쪽 전 구간 확인). 검사 대상이 명령 자체이므로 `matcher: "Bash"` 가 정확한
표현이고 쓰기 경로 우회의 영향을 받지 않는다. **`Bash` matcher 는 허용되며, 락은 그것을
GREEN 이 정답인 양성 대조로 둔다.**

## 4. spec-distill — 기존 `Stop` 훅이 흡수한다

`review-dispatch.py`(Stop) 는 이미 존재하고 **리뷰 강제가 실제로 일어나는 지점**이다.
`spec-write-validator.py` 는 그 훅에 `pending_review:` 라는 연료를 넣어주는 역할이다.
연료 조달을 Stop 훅 자신이 하면 PostToolUse 훅은 필요 없다.

### 4.1 `pending_review:` 는 은퇴하되 in-flight 는 남는다

`spec-write-validator.py` 는 `pending_review:` 블록의 **유일한 writer** 다. 그것을 지우면서
블록만 남겨두면 소비자들이 영구히 빈손이 된다. 계약을 은퇴시키고, `pending_review` 만
먹는 `pending-review-reminder.py`(UserPromptSubmit) 도 함께 삭제한다.

**그러나 그 블록은 연료 이상이었다.** `reviewing-spec/SKILL.md:40` 이 명시하듯 pending 의
존재는 *"이 문서의 리뷰가 진행 중"* 이라는 유일한 상태이기도 했고, 진입 시 그것을 없애는
것이 subagent 경계에서 발생하는 메인 `Stop` 의 재강제(중복·절단)를 막았다. 발견은
무상태라 그 상태를 재생성하지 못한다 — 리뷰 중인 문서는 여전히 dirty 이고 `armed_paths`
는 verdict 시점에야 기록된다.

**그래서 in-flight 표시를 원장에 남긴다.** dispatch 시점에 찍고 verdict 시점에 해제하며,
in-flight 인 문서는 발견 결과에서 제외된다. `validation_attempts`(§4.4)와 같은 모양이므로
새 개념이 아니다. 30초 TTL 은 그 자체로 리뷰 소요보다 짧아 이 역할을 대신하지 못한다.

**남는 것과 사라지는 것**

| 무엇 | 처분 |
|---|---|
| `armed_paths` · `dispatch_attempts` G6 상한 · `last_dispatched_at` TTL 가드 | 유지 — 단 TTL 가드의 도달 조건이 pending 검출에서 발견 결과로 바뀐다 |
| `pending_review:` · `strip_pending_file` · CLI `strip-pending` | 은퇴 |
| in-flight 표시 | 신규 |
| `pending-review-reminder.py` | 삭제 — 단 그 파일은 `PENDING_RE` 검사 **이전에** TTL-GC 트리거와 state-판독-실패 advisory 를 돈다. 그 둘을 `Stop` 훅이 이어받는지 확인하고 §10 에 반영한다 |

**rewrite 실패 경로.** 오늘은 상태 rewrite 가 실패하면 block 을 억제하고 다음 프롬프트의
reminder 가 줍는다. reminder 가 사라지면 발견이 무상태라는 사실이 그 자리를 대신한다 —
다음 `Stop` 이 같은 문서를 다시 발견한다. 다만 `last_dispatched_at` 을 못 써서 TTL 가드가
무력해지므로, rewrite 실패 시에는 block 을 억제하고 advisory 만 낸다. **loud 하되
루프하지 않는다.**

### 4.2 발견 — git 은 상계, 판정은 코드의 술어

발견은 두 단계다. **이 분리가 결정이고, 각 단계의 문법은 구현이 정한다.**

1. **git 에 넓게 묻는다.** 스코프 접두 아래의 dirty·untracked 문서를 한 번의 `git status`
   로 받는다. 이 단계는 **상계**만 제공하면 된다 — 넘치는 것은 다음 단계가 거른다.
2. **판정은 플러그인 자신의 술어로 한다.** `canonical_key(path) is not None` 이 in-scope
   판정이다. 그것이 `resolve_mode`·`arm_ledger` 가 쓰는 바로 그 술어이므로, 발견이 코드와
   다른 집합을 보는 일이 구조적으로 없어진다.

**pathspec 을 이 문서가 정하지 않는 이유**: 판본 4 는 `:(top,literal)` 을 썼고 중첩 접두
경로를 빠뜨렸다. 판본 5 는 `:(glob)**docs/...` 로 고쳤는데 선행 `**` 가 완전한 경로
컴포넌트가 아니라 아무것도 고치지 못했다(실측: `:(top,literal)` 과 동일 집합). 슬래시를
넣은 `**/docs/...` 도 substring 의미와는 여전히 다르다. **이것은 git wildmatch 에 대한
사실이고, 테스트가 있는 곳에서 확정돼야 한다.** 두 단계 분리는 그 사실이 무엇으로
드러나든 결과가 옳게 만든다.

**born 여부는 git 이 이미 준 정보에서 도출한다.** 후보마다 `git ls-files` 를 다시 띄우지
않는다 — 판본 4 가 그렇게 했고 `Stop` 훅 timeout 안에 중첩 timeout 을 만들었다.
도출 규칙은 **status 코드를 위치로 읽는 규칙 하나**여야 하며, 특정 코드들을 열거해서는
안 된다. 열거하면 `AM`(`git add` 후 Bash 로 수정 — 이 설계가 겨냥하는 바로 그 시나리오)
같은 조합이 조용히 빠진다. 도출 결과가 `arm_ledger.is_born` 과 **모든 조합에서** 일치한다는
것이 요구사항이며, 그것을 재는 것은 픽스처 테스트다.

### 4.3 구조 검증 — subprocess 에서 import 로

`parse_spec_structure.py` 는 순수 함수와 CLI 래퍼(`cmd_*`)가 이미 갈라져 있다. 그런데
현재 훅은 순수 함수를 `subprocess.run` 으로 부른다 — design 모드 2회, spec 모드 4회.
각 `cmd_*` 가 파일을 자기가 다시 읽으므로 spec 모드는 같은 파일을 4번 읽는다.

**흡수하면서 import 로 바꾼다.** `review-dispatch.py` 는 이미 `arm_ledger`·`state_path` 를
같은 방식으로 import 한다.

이득은 비용이 아니라 **정확성**이다. 훅의 timeout 은 10초인데 `call_parser` 는 호출마다
`timeout=10` 을 건다. 문서 하나만 느려도 훅 전체가 timeout 으로 죽고, 그때는 출력도
신호도 남지 않는다. import 는 그 중첩을 없앤다.

**발견은 별도 모듈에 둔다** (`scripts/discover_candidates.py`). `git status` 가 거기 살면
발견의 대조 테스트가 부를 대상이 생기고, `review-dispatch.py` 에 대한 "파서를 subprocess
로 부르지 않는다"는 락이 발견의 git 호출과 충돌하지 않는다.

### 4.4 순서와 상한

**순서** — 한 턴에 두 종류의 block 이 가능하다.

| 종류 | 사유 |
|---|---|
| 구조 실패 | Layer 1 이 잡은 ambiguity·placeholder·섹션 누락 |
| 리뷰 강제 | `reviewing-spec` 을 다음 턴 첫 액션으로 |

**구조 검증이 항상 먼저 돈다** — TTL 가드보다도 먼저다. 가드가 앞에 오면 dispatch 후
30초 동안 Bash 로 쓴 깨진 문서의 검증이 통째로 건너뛰어진다. 구조 실패가 하나라도 있으면
그 사유만 block 으로 내고 리뷰 dispatch 는 하지 않는다 — 구조가 깨진 문서를 리뷰어에게
보내면 그 라운드는 `rereview_count` 만 태운다. 한 턴에 block 은 하나이고 두 사유를 합쳐
내지 않는다.

**턴당 상한** — `Stop` 훅의 timeout 안에 들어가야 하므로 한 턴에 검증하는 문서 수에
상한이 필요하다. **상한은 기아를 만들면 안 된다**: 초과분이 "다음 턴에 다시 발견된다"는
것은 정렬이 안정적이고 이미 검증된 문서가 후보에서 빠질 때만 참이다. 둘 중 하나라도
없으면 dirty 문서가 상한보다 많을 때 뒤쪽이 영구히 검증되지 않는다. 진행 보장이
요구사항이고, 그것을 재는 것은 여러 턴에 걸친 행동 테스트다.

**루프 상한** — 구조 검증이 매 턴 실패하면 매 턴 block 이 나가고 멈추지 않는다.
CLAUDE.md 의 **Unbounded autonomy** 금지 조항이 직접 걸린다. `dispatch_attempts`(G6, 3)와
**동형의 별도 카운터**를 문서별로 둔다. 상한에 닿으면 그 문서는 이번 세션에서 **구조
검증도 리뷰 dispatch 도 하지 않는다** — 검증 없이 dispatch 하면 위 순서 규칙이 금지한
일이 정확히 일어난다. 그 문서가 Law 1 게이트를 벗어나는 것은 사실이며, 조용히가 아니라
advisory 와 함께다. `dispatch_attempts` 를 재사용하지 않는다 — 합치면 구조 실패 2회 뒤에
리뷰 dispatch 가 1회밖에 남지 않는다.

### 4.5 git 이 없는 리포

발견이 git 에 의존하므로 git 이 없거나 리포가 아니면 후보가 0이 되고 게이트가 꺼진다.
현재 동작(`is_born` 이 git 실패 시 arm 쪽으로 fail-open)과 방향이 반대다.

**게이트를 끄고 크게 알린다** — 세션당 1회. 반복 advisory 는 무시되는 신호가 된다.

대안(스코프 디렉토리 전체를 후보로 삼기)을 기각한 이유: 기존 문서 5개가 있는 리포에서
세션마다 5번의 리뷰가 발동한다. Law 1 은 과리뷰를 under-review 보다 선호하지만, 실사용이
불가능한 과리뷰는 kill switch 로 통째 꺼지는 결말을 부른다 — 그것이 최대 fail-open 이다.

**두 번째 좁아짐**: 발견은 훅의 cwd 리포만 본다. 다른 체크아웃의 문서는 `git status` 에
나오지 않는다. 오늘의 payload 기반 validator 는 어느 경로가 오든 검사했고 `is_born` 은
바로 그 경우를 위해 절대경로를 일부러 접지 않는다(`arm_ledger.py:194-201` 의 측정된 fix).
둘 다 §13 에 위험으로 올린다.

### 4.6 kill switch 재편

훅 넷이 사라지면 `spec-distill:validator`·`spec-distill:PostToolUse`·`spec-distill:reminder`·
`spec-distill:UserPromptSubmit`·`project-init:docs-lint` 가 가리킬 대상을 잃는다.
`spec-distill:Stop` 은 이제 **구조 검증까지 함께** 끄고, `project-init:PostToolUse` 는
남는 `post-tool-use.py` 를 계속 가리켜 유효하다.

**잃는 조합이 하나 있다** — "리뷰는 끄고 구조 검증은 유지". `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`
이 그 조합의 지정 대체재다(arm 을 끄고 Layer 1 은 남긴다).

**deprecation window 에는 발화 주체가 필요하다.** `kill_switch_active` 는 호출자가 넘긴
(plugin, hook, event) 삼중항에만 토큰을 대조하므로, 훅을 지우면 그 토큰을 검사하는 주체가
사라진다 — 문서에만 적힌 window 는 window 가 아니다. CLAUDE.md 는 kill switch 를 보안
컨트롤로 취급한다. spec-distill 은 `review-dispatch.py` 가 그 역할을 할 수 있다.
**project-init 은 할 수 없다** — 남는 훅이 `matcher: "Bash"` 라 Bash 호출이 없는 세션에서는
발화하지 않고, 그 플러그인에는 세션 state substrate 자체가 없다. §14 미결 3.

## 5. quality-gates — scope 를 git 으로

`post-tool-use-session-tracker.py` 와 그 산출물 `files.md` 를 제거한다. `/qg` 의 기본 scope 가
"이 세션이 편집한 파일"에서 **git 이 보고하는 변경**으로 바뀐다.

**관측 가능한 기본 동작 변경이다** — quality-gates 4.2.3 → 5.0.0 (major).

| 무엇 | 지금 | 이후 |
|---|---|---|
| 기본 scope 출처 | `files.md` 누적 | git |
| Bash 로 쓴 파일 | **누락** | 잡힘 — 이 설계의 목적 |
| 세션 중 커밋된 변경 | `files.md` 에 남음 | base 대비 diff 가 잡음 |
| 리포 밖 절대경로 편집 | `files.md` 에 남음 | **잡히지 않음** — `--paths` 로 명시 |

### 계약을 바꿔야 하는 두 곳

§10 의 삭제 규칙으로 덮이지 않는다. 지우면 계약이 깨지므로 재작성이 필요하다.

**① `skills/quality-pipeline/SKILL.md` 의 `$resolved_scope_file_count`.** 그 값의 정의가
session 모드를 `files.md` 항목에 못 박고 있고, 그것이 정직-verdict floor 의 입력이다.
git-도출 scope 에 대해 재정의한다. "판정 불가를 조용히 0으로 취급하지 말 것" degrade
분기는 유지한다 — scope 와 floor 가 여전히 갈라질 수 있는 유일한 자리이고, 그것은
신호가 아니라 degrade 다.

**② `scripts/pre-pipeline-check.sh` 의 staleness anchor.** 여러 결과 코드가 `SESSION_FILE`
분기 안에서만 도달하고, `SKILL.md` 가 그 코드들을 **닫힌 계약**으로 소비한다. `files.md`
가 사라지면 대체 anchor 가 필요한데, 후보였던 `pipeline.md` 는 같은 스크립트의 C2 race
fix("세션 소유 `pipeline.md` 를 지우지 않는다")와 충돌한다. **이 자리는 결정되지 않았다** —
§14 미결 2.

## 6. project-init — 제거가 남기는 것

`docs-lint.py`(503줄) 와 `tests/test_docs_lint.py`(1052줄) 를 제거한다. 이동이 아니라 제거다.

**사라지는 검사** — 리포 전수 확인 결과 이것을 대신 수행하는 훅·테스트·게이트는 없다.
R1 크기 · R2 목차 · R5 코드펜스 언어 · R6 내부 링크 해석 · `CLAUDE.md`↔`AGENTS.md` 포인터
drift · `AGENTS.md` 의 `## Project Charter` 필수 하위항목 무결성.

**같은 커밋에서 고쳐야 하는 문면 둘.** `commands/project-init.md` 는 헌장 입력이 비어
abort 할 때 *"docs-lint이 사후 플래그합니다"* 라고 사용자에게 약속한다 — **그 약속을
철회한다.** 문장만 고치고 기능을 남기는 것이 아니라, 사후 플래그라는 기능 자체를 제공하지
않는다고 밝힌다. 같은 파일이 `.claude/rules/agent-tool-permission.md` 를 `AGENTS.md` 에서
링크하지 않는 근거로 docs-lint R6 을 든다 — 배치 결정은 유지하되 근거에서 그 참조를 뺀다.

**버전**: project-init 2.1.1 → 3.0.0 (major — 훅 제거는 breaking).

**이 결정이 근거하지 않는 것**: docs-lint 의 6개 규칙이 실전에서 몇 번 발화했는지는 모른다.
훅 출력은 로그로 남지 않는다. 판단은 "무엇을 잃는가"에 근거하며 "그것이 얼마나 아까운가"는
측정되지 않았다. 사용자가 그 값을 알고 제거를 선택했다.

## 7. 이 설계에서 분리한 것 — `/cancel-review`

`/spec-distill:cancel-review` 부활은 이 설계에서 뺀다 (사용자 결정). 두 미해결이 남아 있다.

1. **session-id 획득 경로가 미지정이고, 그것이 v0.25.0 삭제 근거 (d) 그 자체다.**
   `arm_ledger` CLI 는 `<sid>` 를 인자로 요구하고 `state_path.py` 의 CLI 경로는 환경변수에서만
   sid 를 푼다. sid 가 갈리면 cancel 이 훅이 읽지 않는 파일에 쓰고 **성공을 보고한다.**
2. **`--reset` 은 tracked 문서에 아무 효과가 없다.** `should_arm` 의 `is_born` conjunct 를
   `unmark-reviewed` 가 되돌리지 못한다.

둘 다 sid 해석을 정면으로 다뤄야 풀린다. 그때 §12 의 마지막 항목대로 **기존 kill switch 로
왜 부족한가**를 먼저 기각해야 한다.

## 8. 비용

**방향은 이 문서가 가진 수로 유도된다.** 측정 시나리오(도구 호출 30회 — Read 20 · Bash 5 ·
Write 3 · Grep 2)에서 삭제되는 세 훅은 Write 3회 × (31.6 + 23.6 + 26.2) ms ≈ **244 ms** 를
차지한다. 추가되는 것은 이미 도는 `Stop` 훅 안의 `git status` 1회(약 13 ms)뿐이고, 후보당
`git ls-files` 는 §4.2 가 제거한다. 예상 순감은 200 ms 대다.

`pending-review-reminder.py` 삭제분은 **여기 넣지 않는다** — 그 훅의 실측값이 없다.
추정치를 만들지 않는 것이 아래 프로토콜의 규칙이고, 자기 규칙을 자기가 어길 수 없다.

**측정 프로토콜**: 기준선(현재 코드)과 비교군(적용 후)을 같은 시나리오로 재고, 플러그인별
합과 턴 벽시계를 **둘 다** 기록한다(병렬·직렬 여부가 그 차이로 드러난다). 측정 래퍼는
배포본에 넣지 않는다 — `/usr/bin/time -p` 는 stderr 에 쓰는데 spec-distill 의 집행 채널이
stderr 라 차단 사유를 오염시킨다. 도구 부재 시 측정을 **실패로 보고**하고 추정치를 만들지
않는다.

**측정 결과를 머지 게이트로 쓰지 않는다.** 예상 마진이 17.4 ms 인터프리터 바닥의 여러 배라
자동 부등식은 잡음에 좌우될 뿐 정보를 더하지 않는다. 비교군이 기준선보다 크면 비-차단
advisory 를 내고 CHANGELOG 에 적는다 — 위 유도가 틀렸다는 신호이므로 사람이 본다.

## 9. 구현이 만족해야 하는 것

**요구사항이지 문법이 아니다.** 각 항목을 어떤 술어·문자열로 표현할지는 plan 과 구현이
정하고, 그 표현이 실제로 그 요구를 재는지는 §11 의 mutation 이 증명한다.

| # | 요구 |
|---|---|
| A1 | 어떤 `PostToolUse` 훅도 쓰기 도구에 발화하지 않는다. **matcher 키 부재와 빈 matcher 는 둘 다 전체 도구 발화이므로 둘 다 위반이다** |
| A2 | `Bash` 만 담은 matcher 는 위반이 아니다 (§3.2) |
| A3 | 삭제 대상 네 훅이 존재하지 않고, 살아있는 소비자 표면에 그 참조가 없다 (§10) |
| A4 | `review-dispatch.py` 가 구조 검증을 import 로 수행하며 파서를 subprocess 로 부르지 않는다 |
| A5 | 발견의 in-scope 판정이 `canonical_key` 와 **같은 술어**다 — git 은 상계만 준다 |
| A6 | born 판정이 `arm_ledger.is_born` 과 **모든 status 조합**에서 일치한다. 특정 코드 열거가 아니라 위치 규칙으로 도출한다 |
| A7 | Bash 로 쓴 미커밋 스코프 문서가 턴 끝에 검증되고 리뷰가 dispatch 된다. subagent 가 썼어도 같다 |
| A8 | Bash 로 고친 커밋된 스코프 문서는 검증되지만 arm 되지 않는다 |
| A9 | 스코프 문서를 읽기만 한 턴에는 아무 일도 일어나지 않는다 |
| A10 | 구조 검증이 TTL 가드보다 먼저 돈다 |
| A11 | 구조 실패 시 그 사유만 block 으로 나가고 dispatch 는 그 턴에 없다 |
| A12 | 리뷰가 진행 중인 문서는 발견 결과에서 제외된다 (§4.1) |
| A13 | 턴당 상한이 있고, 상한을 넘는 dirty 문서가 있어도 **모든 문서가 결국 검증된다** (기아 없음) |
| A14 | 검증 실패 상한에 닿은 문서는 검증도 dispatch 도 되지 않고 advisory 만 나간다 |
| A15 | 상태 rewrite 실패 시 block 없이 advisory 만 나가고 루프하지 않는다 |
| A16 | git 을 쓸 수 없으면 세션당 1회 advisory 가 나가고 검증·dispatch 는 없다 |
| A17 | 파일명에 공백·개행·비-UTF-8 바이트가 있어도, rename·copy 항목이 있어도 발견이 정확히 파싱한다 |
| A18 | kill switch 가 발견·검증·dispatch 를 모두 지배한다 |
| A19 | 은퇴한 kill switch 토큰이 설정돼 있으면 사용자가 그 사실을 알게 된다 (수단은 §14 미결 3) |
| A20 | Bash 로 쓴 파일이 `/qg` 기본 scope 에 들어간다 |
| A21 | `pre-pipeline-check.sh` 의 결과 코드 집합이 유지되고 `SKILL.md` 의 닫힌 계약이 성립한다 |
| A22 | `SKILL.md` 가 git-도출 scope 에 대해 `$resolved_scope_file_count` 를 정의하고 판정-불가 degrade 분기를 유지한다 |
| A23 | `commands/project-init.md` 가 사후 플래그를 약속하지 않는다 |
| A24 | 건드린 각 플러그인이 bump 되고 CHANGELOG 항목을 가진다 — **플러그인별 독립 판정** (PR 형태를 전제하지 않는다) |
| A25 | 은퇴 토큰 전부가 해당 CHANGELOG 의 Deprecated 항목에 문자 그대로 있다 |
| A26 | §8 기준선·비교군 측정값이 CHANGELOG 에 기록된다 |

## 10. 무엇을 고치는가 — 목록이 아니라 규칙

파일을 손으로 열거하면 빠뜨린다 — 실제로 세 번 빠뜨렸다(quality-gates 의 `SKILL.md`,
project-init 의 `smoke.sh` 와 fixture 트리, spec-distill 의 테스트 8개와 prose 4개).
네 번째 목록이 더 정확하리라는 근거가 없다.

### 규칙

삭제되는 표면마다 basename 과 계약 이름을 정하고, **살아있는 소비자 표면**을 검색해
나오는 모든 참조를 제거한다. 목록은 구현이 기계적으로 도출한다.

| 삭제되는 표면 | 검색어 |
|---|---|
| spec-distill validator | `spec-write-validator` |
| spec-distill reminder | `pending-review-reminder` · `pending_review` · `strip-pending` · `strip_pending_file` |
| quality-gates tracker | `post-tool-use-session-tracker` · `files.md` |
| project-init lint | `docs-lint` · `test_docs_lint` |

### 정의역 — 무엇이 "살아있는 소비자 표면"인가

**포함**: `plugins/**` (단 `tests/fixtures/` 제외) · `CLAUDE.md` · `docs/philosophy/`.
**제외**: `CHANGELOG.md` · `docs/archive/` · `docs/audits/` · `docs/superpowers/{specs,plans}` ·
`tests/fixtures/`. 제외되는 것은 전부 **기록물**이다 — 과거에 무엇이 있었는지를 남기는
자리이므로 그 이름이 남아야 옳다. Law 3 substrate 를 지우는 것은 이 설계의 목적이 아니다.

**완료 oracle**: 위 정의역에서 각 검색어가 0 히트. 정의역을 파일 목록이 아니라 **성질**로
적었으므로, 새 파일이 생겨도 규칙이 그대로 적용된다.

### oracle 로 덮이지 않는 것 — 반드시 손으로 결정하는 편집

검색으로 나오지만 **삭제가 아니라 재작성**이 필요한 자리다.

| 파일 | 무엇 |
|---|---|
| `spec-distill/skills/reviewing-spec/SKILL.md` | Step 1 을 발견 기반으로 개정. read==write 불변식 단락과 in-flight 계약 재작성 |
| `spec-distill/agents/spec-reviewer.md` | persona 파일 — validator 인용 제거. CLAUDE.md 상 보안-민감이라 별도 검토 |
| `spec-distill/tests/test_brief_review_meta.sh` | `hooks/` 정확-집합 열거를 남는 두 파일로 갱신 |
| `spec-distill/tests/test_resolve_mode_scope.sh` | `resolve_mode` 로드 경로를 `scripts/` 로 |
| `spec-distill/hooks/review-dispatch.py` | 흡수 + TTL-GC 트리거 인계 확인 (§4.1) |
| `quality-gates/scripts/pre-pipeline-check.sh` | anchor 교체 — §14 미결 2 가 먼저 답해야 한다 |
| `quality-gates/skills/quality-pipeline/SKILL.md` | `$resolved_scope_file_count` 재정의 (§5 ①) |
| `quality-gates/commands/qg.md` | Scope 절 |
| `project-init/commands/project-init.md` | 약속 철회 · 근거 갱신 (§6) |
| 각 `plugin.json` · `CHANGELOG.md` · `README.md` | bump · Removed·Changed·Deprecated · Hooks Installed·디렉토리 트리·state 파일·kill switch 문구 |

### 새로 만드는 것

`spec-distill/scripts/discover_candidates.py` — §4.2 의 발견. `git status` 가 여기 살아서
대조 테스트가 부를 대상이 생긴다.

## 11. 검증에 요구되는 것

**락의 표현은 정하지 않는다. 락이 만족해야 하는 성질을 정한다.**

### 성질

- **양·음 짝.** 각 요구는 양(존재)과 음(부재) 양쪽으로 잠근다. **음의 짝이 양의 짝의
  논리적 동어반복이면 짝이 아니다.** 판별법: *이 음의 짝을 삭제해도 양의 짝이 그 결함을
  잡는가.* "잡는다"면 짝이 아니므로 다시 만든다. 판본 4·5 가 연속으로 이 결함을 냈고
  같은 락 번호에서 두 번 났다 — 구현 시 전 락을 이 질문으로 한 번 훑는다.
- **대상은 구조에서 도출한다.** 플러그인 이름을 하드코딩하지 않고 glob 으로 열거한다.
  네 번째 플러그인이 같은 결함을 들고 와도 RED 여야 한다. 정의역에서 무엇을 빼든
  **이유를 함께 적는다** — 커밋된 프로브 픽스처는 matcher 없는 `PostToolUse` 항목을
  실제로 갖고 있으므로 면제라면 그 이유가 필요하다.
- **AC 가 결함이 살아있는 채로 통과하면 AC 가 아니다.** 각 요구마다 "이 요구를 위반하는
  가장 값싼 구현"을 적고 그것이 RED 인지 확인한다.

### mutation

각 락은 mutation 으로 이빨을 증명한다. **네 축으로 흔든다** — 삭제·추가·반전·형태 변경.
방향 반전만 잠그면 형태 변경(`except` 절 좁히기, 동의어 치환)이 통과한다. 이 플러그인은
`UnicodeDecodeError ⊄ OSError` 와 `ImportError` vs `Exception` 으로 그 실패를 두 번 겪었다.

**양성 대조가 필수다.** mutation 전 스위트가 GREEN 인지 먼저 확인한다 — RED 자체는
계측기가 살아 있다는 증거가 아니다. GREEN 이 정답인 대조를 최소 넷 둔다: `Bash` matcher,
기록물에만 남은 참조, 발견 모듈 안의 `git status`, 건드리지 않은 플러그인의 미-bump.

**계측 자체를 먼저 검증한다.** `PYTHONDONTWRITEBYTECODE=1` 로 돌린다(같은 길이 변이는
stale `.pyc` 를 넘지 못해 거짓 GREEN·거짓 RED 를 둘 다 낸다). 파이썬 대상은 `ast.parse`,
셸 대상은 `bash -n` 으로 먼저 스윕한다 — 정규식 본문 추출기가 이 리포에서 다섯 번 연속
조용히 깨졌다. 픽스처가 의도한 상태를 실제로 만들었는지 먼저 확인한다 — 이 설계를 쓰는
동안 `git commit` 이 staged 파일을 함께 커밋해 staged-only 케이스가 조용히 사라졌고
계측기가 틀린 답을 냈다.

### 행동 케이스

정적 검사로 확인할 수 없는 요구(A7~A16, A20)는 헤드리스 턴으로 잰다. 프로브 플러그인과
재현 커맨드는 `shared/tests/fixtures/hookprobe/` 에 커밋돼 있다. `--permission-mode
acceptEdits` 없이는 편집이 rc 0 으로 조용히 죽으므로 반드시 붙인다. 임시 디렉토리는
만든 직후 `pwd -P` 로 정규화한다 — macOS 의 `/tmp` 는 `/private/tmp` 심볼릭 링크라 경로
포함 검사가 조용히 무너진다. A13(기아 없음)은 **여러 턴**에 걸쳐 재야 한다.

### 선재 RED

작업 전에 세 플러그인 테스트 스위트의 기준선을 캡처한다. quality-gates 에는 `main` 에
선재 RED 가 있는 것으로 기록돼 있다. 기준선 목록에 올리는 각 항목에 **왜 면제인지 한 줄**을
함께 적는다 — 이유 없는 면제 목록은 그 질문을 영구히 닫는다.

## 12. 기각한 대안

| 대안 | 왜 기각했나 |
|---|---|
| **matcher 에 `Bash` 추가 + 명령어 파싱** | `cat >`·`tee`·`sed -i`·`>>`·`printf`·`perl -i`·`mv`·`git apply` — 열거를 하나 빠뜨릴 때마다 조용한 fail-open. 고치려는 결함을 한 층 아래로 옮긴다 |
| **matcher 에 `Bash` 만 추가 (열거를 정직하게)** | Bash payload 에는 `file_path` 가 없다. 발화한 뒤 무엇을 검사할지가 미정이라 단독으로 성립하지 않는다. 게다가 훅이 모든 호출에 돌아 비용이 배 이상이 된다 |
| **payload 의 `file_path` 로 분기** | `Read` 의 `tool_input` 도 `file_path` 다. 읽기만 해도 검증·arm 이 돈다 — 도구 열거의 재발 |
| **`shared/writewatch/` 감지 모듈** | 귀속 상실 — `git checkout`·`merge`·에디터 편집이 "이 도구 호출이 바꿨다"가 되어 사용자가 손대지 않은 문서로 턴이 막힌다 |
| **`UserPromptSubmit` 기준선 + 내용 해시** | 위 모듈의 부속. 기준선을 남의 훅에 얹으면 그 훅의 조기 return 경로에 삼켜지고, 그 훅의 kill switch 가 Law 1 기준선까지 끈다 |
| **`pending_review:` 를 통째로 버린다** | 그 블록은 연료이자 **in-flight 표시**였다. 발견이 무상태라 후자를 재생성하지 못한다 — 그래서 은퇴시키되 in-flight 는 원장으로 옮긴다 (§4.1) |
| **후보당 `is_born` 재호출** | `git ls-files` 를 문서 수만큼 띄워 `Stop` 훅 timeout 안에 중첩 timeout 을 만든다. status 정보가 같은 답을 이미 준다 |
| **status 코드를 열거해 매핑** | 열거는 조합을 빠뜨린다. `AM`(add 후 Bash 수정)이 이 설계가 겨냥하는 시나리오인데 열거에서 빠졌다 — 위치 규칙으로 도출해야 한다 |
| **발견의 pathspec 을 이 문서가 확정** | 두 판본 연속 틀렸다. git wildmatch 에 대한 사실은 테스트 옆에서 확정된다 (§4.2) |
| **완료 oracle 을 리포 전수 0 히트로** | 실측상 달성 불가 — 기록물(`docs/audits`·`docs/archive`·과거 plan)과 다른 플러그인 fixture 가 포함돼 0으로 만들면 Law 3 substrate 를 파괴한다. 정의역을 성질로 적어야 한다 (§10) |
| **후보 상한만 두고 진행 보장은 안 둠** | dirty 문서가 상한보다 많으면 뒤쪽이 영구히 검증되지 않는다 |
| **`os.scandir` 전수 스캔** | 제외 규칙(`.git`·`node_modules`·`.gitignore`)을 손으로 만들어야 하고 그 목록이 **또 하나의 열거**가 된다. git 은 그 규칙을 이미 안다 |
| **`PostToolBatch` 로 교체** | matcher 가 없어 열거 문제는 사라지지만 `exit 2` 가 "루프 정지 + stderr 는 사용자에게만"이라 구조 검증의 모델 피드백을 잃는다 |
| **`FileChanged` 로 파일 감시** | 층위는 가장 정확하나 집행력이 없고, 실측에서 matcher 3변형 모두 0건이었다. `Stop` 로 옮기면 이 이벤트가 답하려던 질문 자체가 없어진다 |
| **`PreToolUse` 로 Bash 쓰기 차단** | 명령어 파싱이 필요해 첫 항목과 같은 fail-open 을 물려받고, 오탐이 무관한 명령을 막는다 |
| **문서로만 "spec 문서는 Write 로 쓰라"** | 이 리포는 프롬프트 수준 분리를 집행으로 인정하지 않는다 (Law 2 의 논리). 이번 사건 자체가 그 규정이 세션 지시에 밀린 사례다 |
| **project-init `docs-lint` 를 `Stop` 훅으로 이동** | 사용자가 검사 자체의 제거를 선택했다. 이동하면 훅 수가 줄지 않고 kill switch deprecation 만 늘어난다 |
| **project-init `docs-lint` 를 `post-tool-use.py` 에 병합** | 명령 검증과 파일 규약 검사라는 다른 두 관심사가 한 프로세스에 들어가고, matcher 를 지워야 하므로 Bash 아닌 호출에서도 깨어난다 |
| **qg 세션 scope 를 다른 누적 수단으로 유지** | 누적은 어느 수단으로 하든 귀속을 요구한다. §3.1 대로 축소 자체가 사라지므로 누적을 버리는 비용이 작다 |
| **임계 부등식을 머지 게이트로** | 예상 마진이 인터프리터 바닥의 여러 배라 자동 게이트는 잡음에 좌우될 뿐 정보를 더하지 않는다 |
| **`/cancel-review` 대신 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`** | v0.25.0 이 사전 옵트아웃의 지정 대체재로 명시한 스위치다. §7 분리에 따라 후속 설계가 먼저 결론지어야 한다 |

**뒤집힌 기각 하나.** 판본 3 은 *"`Stop` 훅 턴-끝 전수 검사"* 를 기각했고 사유는
**"quality-gates·project-init 에 `Stop` 훅이 없어 새 훅 둘이 필요하고, 피드백이 턴 끝으로
밀린다"** 였다. 두 근거가 각각 무너졌다:

1. **새 훅 둘이 필요하지 않다.** 두 플러그인의 훅을 *삭제*하기로 했으므로 `Stop` 훅을 만들
   대상이 없다. spec-distill 은 `Stop` 훅을 이미 가진다 — 신규 훅은 0개다.
2. **피드백 지연이 실제보다 크게 서술됐다.** `PostToolUse` 는 쓰기가 **일어난 뒤** 도는
   훅이라 지금도 문제 있는 내용은 디스크에 앉는다. `Stop` 으로 옮기면 모델이 *언제 아는지*만
   바뀌고, `decision: block` 으로 되돌아온 모델은 같은 턴 안에서 고친다.

미래 리뷰가 이 기각을 다시 들고 오지 않도록 여기 남긴다.

## 13. 위험

| # | 위험 | 완화 |
|---|---|---|
| R1 | `Stop` 훅의 block 이 폭주한다 | 기존 TTL 가드·G6 상한·원장 veto 에 더해 §4.4 의 검증-실패 상한. TTL 가드의 도달 조건이 바뀌므로 그 재-anchor 가 §4.1 에 있다 |
| R2 | 리뷰 중 재-dispatch 로 중복·절단이 생긴다 | §4.1 의 in-flight 표시. A12 가 요구한다 |
| R3 | 구조 검증이 턴 끝으로 밀려 모델이 문제 있는 문서 위에 계속 쌓는다 | 한 턴 안의 손실이다. `PostToolUse` 도 쓰기 뒤에 돌므로 차이는 "도구 호출 몇 개" 분량이다 |
| R4 | git 불능 리포에서 게이트가 조용히 꺼진다 | §4.5 의 loud advisory |
| R5 | 다른 체크아웃의 문서가 발견에서 빠진다 | §4.5 두 번째 좁아짐. 그 워크트리에서 세션을 열면 커버된다 — README 에 적는다 |
| R6 | 상한 초과 문서가 굶는다 | A13 이 진행 보장을 요구하고 여러 턴에 걸친 테스트가 잰다 |
| R7 | qg 기본 scope 가 리포 밖 절대경로 편집을 놓친다 | `--paths` 로 명시. §5 표에 이름으로 적는다 |
| R8 | project-init 의 문서 규약 검사가 영구히 사라진다 | 사용자가 손실을 알고 선택했다. §6 이 사라지는 규칙을 이름으로 적고 약속을 철회한다 |
| R9 | 은퇴 토큰이 조용히 무시된다 | spec-distill 은 `review-dispatch.py` 가 알린다. project-init 은 수단이 없다 — §14 미결 3 |
| R10 | `pre-pipeline-check.sh` anchor 교체가 결과 코드의 의미를 바꾼다 | A21 이 코드 집합 유지를 요구. anchor 자체는 §14 미결 2 |
| R11 | persona 파일 편집이 리뷰어를 약화시킨다 | CLAUDE.md 상 persona 편집은 보안 리뷰 대상. 이번 편집은 삭제된 경로의 인용 제거로 한정하고 규칙·임계는 건드리지 않는다 — PR 설명에 명시한다 |
| R12 | 이 설계 문서 자신이 Bash 로 쓰여 게이트를 우회한다 | 이 문서는 `Write` 도구로 작성했다. 후속 편집도 그렇게 한다 |
| R13 | codex co-reviewer 부재로 공유-맹점이 검사되지 않는다 | 사용 한도가 2026-09-17 까지 소진돼 있다(실제 호출 2회로 확인). 리뷰 5라운드 전부 Claude 단독이었다 — 이 설계에서 검사되지 않은 것이 무엇인지 아무도 모른다. §14 미결 4 |

## 14. 미결 — plan 이 답해야 하는 것

| # | 무엇 |
|---|---|
| 1 | 세 플러그인을 한 PR 로 낼지 셋으로 쪼갤지 (A24 가 플러그인별 독립이라 두 형태 모두 허용) |
| 2 | `pre-pipeline-check.sh` 의 staleness anchor — `pipeline.md` 는 같은 스크립트의 C2 race fix 와 충돌한다 (§5 ②) |
| 3 | project-init 의 은퇴 토큰 advisory 수단 — 남는 훅이 `matcher: "Bash"` 이고 세션 state substrate 가 없다 (§4.6) |
| 4 | codex 한도 복구(2026-09-17) 후 이 설계와 구현의 재검토 여부 |
| 5 | `/cancel-review` (§7) — 별도 설계 |
