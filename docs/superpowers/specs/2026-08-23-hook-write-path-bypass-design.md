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
고치지 않는다. **그 훅 셋을 없앤다.** spec-distill 의 검사는 이미 존재하는 `Stop` 훅이
흡수하고, quality-gates 와 project-init 의 훅은 삭제한다. 결과적으로 이 리포에
쓰기-matcher `PostToolUse` 훅이 0개가 되어 버그 클래스 자체가 사라진다.

**세 플러그인의 최종 상태**

| 플러그인 | 훅 | 결정 |
|---|---|---|
| spec-distill | `hooks/spec-write-validator.py` | 삭제 — 기존 `Stop` 훅(`review-dispatch.py`)이 흡수 |
| quality-gates | `hooks/post-tool-use-session-tracker.py` | 삭제 — `/qg` scope 를 git 기반으로 |
| project-init | `hooks/docs-lint.py` | 삭제 — 이동 아님, 검사 자체를 제거 |
| project-init | `hooks/post-tool-use.py` (`matcher: "Bash"`) | 손대지 않음 |
| quality-gates | `hooks/post-tool-use.py` (`matcher: "Bash"`) | 손대지 않음 |

**이 설계가 서 있는 실측** (2026-08-22~23, Claude Code 2.1.239)

| 잰 것 | 결과 |
|---|---|
| `spec-write-validator.py` 1회 (경로 불일치 조기 return) | 31.6 ms |
| `post-tool-use-session-tracker.py` 1회 | 23.6 ms |
| `docs-lint.py` 1회 | 26.2 ms |
| 맨 `python3` 기동 | 17.4 ms — 위 비용의 약 70% |
| `git status --porcelain -- <pathspec>` | 12.8 ms |
| `PostToolUse` 에서 `matcher` 키 생략 | 전체 도구에 발화 (판본 1~3 의 근거, 이제 미사용) |
| subagent 의 Bash heredoc | `PostToolUse`·`PostToolBatch` 둘 다 발화 |
| 번들 훅 이벤트 레지스트리 | 29종 중 matcher 미지원 9종 |

프로브 플러그인은 `shared/tests/fixtures/hookprobe/` 에 이미 커밋돼 있다 (commit `1a37123`).

**암묵 컨텍스트 (문서 밖 근거)**

| 무엇 | 어디서 왔나 |
|---|---|
| 세 플러그인 전부를 대상으로 | 사용자 결정 |
| 훅이 필요한지부터 따진다 — 훅은 비용이다 | 사용자 결정 (판본 4 착수 시) |
| `docs-lint` 는 이동이 아니라 제거 | 사용자 결정 |
| 한 번에 arm 하는 문서는 하나, 나머지는 advisory | 사용자 결정 |
| `/cancel-review` 를 이 설계에서 분리 | 사용자 결정 — §7 |
| 발단 | 이 리포에서 실제 발생 — 세션 지시가 Bash 쓰기를 요구했고 `docs/superpowers/specs/` 문서 3개가 게이트를 통과하지 않은 채 커밋됨 |

**plan 으로 넘기는 미결**: §14.

## 목차

- [1. 문제](#1-문제)
- [2. 판본 1~3 이 왜 폐기됐나](#2-판본-13-이-왜-폐기됐나)
- [3. 결정 — 쓰기-matcher 훅 셋을 없앤다](#3-결정--쓰기-matcher-훅-셋을-없앤다)
  - [3.1 세 훅이 같은 질문을 하지 않는다](#31-세-훅이-같은-질문을-하지-않는다)
  - [3.2 손대지 않는 것 — `matcher: "Bash"` 훅 둘](#32-손대지-않는-것--matcher-bash-훅-둘)
- [4. spec-distill — 기존 `Stop` 훅이 흡수한다](#4-spec-distill--기존-stop-훅이-흡수한다)
  - [4.1 발견 — `git status` 한 번](#41-발견--git-status-한-번)
  - [4.2 구조 검증 — subprocess 에서 import 로](#42-구조-검증--subprocess-에서-import-로)
  - [4.3 두 종류 block 의 우선순위](#43-두-종류-block-의-우선순위)
  - [4.4 루프 상한](#44-루프-상한)
  - [4.5 git 이 없는 리포](#45-git-이-없는-리포)
  - [4.6 kill switch 재편](#46-kill-switch-재편)
- [5. quality-gates — scope 를 git 으로](#5-quality-gates--scope-를-git-으로)
- [6. project-init — 제거가 남기는 것](#6-project-init--제거가-남기는-것)
- [7. 이 설계에서 분리한 것 — `/cancel-review`](#7-이-설계에서-분리한-것--cancel-review)
- [8. 비용 — 측정 프로토콜](#8-비용--측정-프로토콜)
- [9. Acceptance Criteria](#9-acceptance-criteria)
- [10. 고칠 파일](#10-고칠-파일)
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

## 2. 판본 1~3 이 왜 폐기됐나

이 문서는 네 번째 판본이다. 앞선 세 판본은 전부 **열거를 고치거나 감지 모듈을 만드는**
방향이었고, 리뷰 3라운드에서 매번 같은 영역에 새 block 이 생겼다. 전문은 commit
`1a37123` 에 있다.

| 판본 | 방식 | 깨진 이유 |
|---|---|---|
| 1 | `matcher` 삭제 + payload 의 `file_path` 로 분기 | 도구 열거가 `hooks.json` 밖 파이썬에도 있었다 (세 곳) |
| 2 | 위 + degrade 정교화 | `Read` 의 `tool_input` 도 `file_path` — 읽기만 해도 검증·arm 이 돌았다 |
| 3 | payload 를 안 보고 파일시스템 관찰 + 내용 해시 | 귀속 상실 — `git checkout`·`merge`·에디터 편집이 "이 도구 호출이 바꿨다"가 된다 |

**핵심 발견은 그 셋이 함께 확인한 것이다.** `PostToolUse` 는 *도구가 돌았다*를 알려줄 뿐
*그 도구가 무엇을 바꿨는지*는 알려주지 않는다. 그 간극을 메우는 길은 둘뿐이고 둘 다
구조적 대가가 있다.

| 길 | 대가 |
|---|---|
| payload 를 읽어 추론 | 도구·스키마 **열거**로 되돌아간다 |
| 파일시스템을 관찰 | **귀속 상실** + 비용이 dirty 집합 크기에 비례 |

**세 번째 길은 그 층에 없다.** 판본 4 는 세 번째 길을 찾지 않는다. **질문을 바꾼다** —
"무엇이 바뀌었나" 대신 "지금 불변식이 깨졌나"를 묻는다. 후자는 귀속을 요구하지 않고,
대상 집합을 변경 기록이 아니라 각 플러그인 자신의 규칙에서 도출한다.

## 3. 결정 — 쓰기-matcher 훅 셋을 없앤다

### 3.1 세 훅이 같은 질문을 하지 않는다

각 훅이 실제로 답하려는 질문을 확인하면 셋 중 둘은 "무엇이 바뀌었나"를 아예 필요로 하지
않는다.

| 훅 | 훅이 묻는 것 | 변경 기록이 필요한가 |
|---|---|---|
| project-init `docs-lint` | "이 파일들이 규약을 지키나" — 대상은 고정 4개 + `docs/project/*.md` | 아니오. 대상이 변경과 무관하게 도출된다 |
| spec-distill `spec-write-validator` | "리뷰 안 거친 design doc 이 있나" + 구조 검증 | 아니오. arm-once 원장과 `is_born` 이 이미 **상태** 질문이다 |
| quality-gates `session-tracker` | "이 세션이 건드린 파일 집합" | 예. 누적이 본질이다 |

세 번째(quality-gates)조차 이미 backstop 을 가진다. `commands/qg.md` 의 정직-verdict floor 는
resolved scope 가 0인데 브랜치가 base 보다 앞서 있으면 `check-review-scope.sh` 의
`changes_exist` 를 근거로 verdict 를 `NOT certified clean` 으로 교체한다 (kill 불가).
즉 Bash 쓰기가 세션 scope 에서 놓치는 것은 *조용한 통과*가 아니라 *scope 축소*이고,
축소는 이미 잡힌다.

그러므로 세 훅 모두 현재 자리에 있을 이유가 없다.

### 3.2 손대지 않는 것 — `matcher: "Bash"` 훅 둘

quality-gates 와 project-init 는 각각 `matcher: "Bash"` 인 두 번째 `PostToolUse` 훅을 가진다.

| 훅 | 무엇을 보나 |
|---|---|
| `project-init/hooks/post-tool-use.py` | `tool_input.command` 문자열 — `git checkout -b`/`git switch -c` 의 브랜치명, `git commit -m` 의 메시지 |
| `quality-gates/hooks/post-tool-use.py` | `tool_input.command` 문자열 — `gh pr create` 성공 감지 |

**둘 다 파일이 아니라 명령을 검증한다.** 검사 대상이 명령 자체이므로 `matcher: "Bash"` 가
정확한 표현이고, 쓰기 경로 우회의 영향을 받지 않는다. 이 설계는 둘을 건드리지 않는다.

이 구분은 락에도 반영된다 — §11.1 의 음의 락은 `Write`/`Edit`/`MultiEdit`/`NotebookEdit` 를
포함하는 matcher 를 금지하되 `Bash` matcher 는 허용한다.

## 4. spec-distill — 기존 `Stop` 훅이 흡수한다

`review-dispatch.py`(Stop) 는 이미 존재하고, **리뷰 강제가 실제로 일어나는 지점**이다.
`spec-write-validator.py`(PostToolUse) 는 그 훅에 `pending_review:` 라는 연료를 넣어주는
역할이다. 연료 조달을 Stop 훅 자신이 하면 PostToolUse 훅은 필요 없다. **신규 훅은 없다.**

새 흐름:

```
1. kill switch · 원장 로드                                    (기존 그대로)
2. 발견:  git status --porcelain -z -- docs/superpowers/specs/
      '??'         → 미커밋 문서:   구조 검증 + arm 후보
      ' M' / 'M '  → 커밋된 수정본: 구조 검증만
3. 구조 검증: parse_spec_structure 를 import 로 호출
      실패 → decision:block + 사유. 리뷰 dispatch 는 이번 턴에 하지 않는다
4. 통과한 미커밋 문서 중 armed_paths 에 없는 것 하나를 dispatch
      나머지는 이름과 함께 advisory
5. TTL 가드 · G6 상한 · 원장 veto                              (기존 그대로)
```

### 4.1 발견 — `git status` 한 번

`spec-write-validator.py` 의 `PATH_PREFIX` 는 `docs/superpowers/specs/` 하나뿐이다.
그래서 pathspec 이 한 줄이고 `git status` 호출도 한 번이다.

```
git status --porcelain -z -uall --no-optional-locks -- ':(top,literal)docs/superpowers/specs/'
```

| 플래그 | 왜 |
|---|---|
| `-z` | 파일명의 공백·개행·비-UTF-8 바이트가 인용·이스케이프 없이 NUL 구분으로 나온다 |
| `-uall` | 새 하위 디렉토리 안의 문서가 디렉토리 하나로 접히지 않고 파일 단위로 나온다 |
| `--no-optional-locks` | 훅이 인덱스 락을 잡아 사용자의 동시 git 명령을 막지 않는다 |
| `:(top,literal)` | 경로를 리포 최상위 기준 리터럴로 고정한다 — glob 메타문자와 cwd 의존을 없앤다 |

**두 상태만 소비한다.** `??`(untracked) 는 구조 검증 + arm 후보, ` M`/`M `/`MM`(modified) 는
구조 검증만. 나머지 코드(`D` 삭제, `UU` 충돌, `R`/`C` rename·copy)는 후보에서 제외한다 —
삭제된 파일은 읽을 수 없고, 충돌 마커가 든 파일은 구조 검증이 반드시 실패해 사용자가
손대지 않은 문서로 턴을 막는다.

**`is_born` 과의 관계.** arm 자격은 여전히 `should_arm = (not is_armed) and (not is_born)` 이
결정한다. `??` 는 `is_born` 이 거짓일 강한 신호이지만 동치가 아니다 — `git add` 만 된 파일은
`??` 가 아니면서 `is_born` 은 참이다. 발견은 후보를 좁히는 단계이고 자격 판정은 원장이 한다.
둘을 합치지 않는다.

### 4.2 구조 검증 — subprocess 에서 import 로

`parse_spec_structure.py` 는 순수 함수(`find_missing_sections`·`parse_frontmatter`·
`validate_locked_decisions`·`load_blacklist`·`scan_ambiguity`·`scan_placeholders`)와
CLI 래퍼(`cmd_*`)가 이미 갈라져 있다. 그런데 현재 훅은 순수 함수를 `subprocess.run` 으로
부른다 — design 모드 2회, spec 모드 4회. 각 `cmd_*` 가 파일을 자기가 다시 읽으므로
spec 모드는 같은 파일을 4번 읽는다.

**흡수하면서 import 로 바꾼다.** `review-dispatch.py` 는 이미 `sys.path.insert` 로
`scripts/` 를 넣고 `arm_ledger`·`state_path` 를 import 한다 — 같은 플러그인, 같은 경로,
기존 관례다.

| 무엇 | 지금 | 판본 4 |
|---|---|---|
| 문서당 subprocess | 2 (design) / 4 (spec) | 0 |
| 문서당 파일 읽기 | 2 / 4 | 1 |
| `timeout=10` 하위 프로세스 | 있음 | 없음 |

subprocess 제거는 성능 문제가 아니라 **정확성 문제를 닫는다.** 훅의 `timeout` 은 10초인데
`call_parser` 는 호출마다 `timeout=10` 을 건다. 문서 하나만 느려도 훅 전체가 timeout 으로
죽고, 그때는 출력도 신호도 남지 않는다. import 는 그 중첩을 없앤다.

**모드 판정은 그대로 옮긴다.** `-spec.md` → spec, `-design.md` → design, 그 외 `.md` 는
frontmatter 에 `locked_decisions` 키가 있으면 spec 없으면 design. `resolve_mode` 와
`_frontmatter_has_locked_decisions` 를 `scripts/` 로 옮겨 Stop 훅이 import 한다.

### 4.3 두 종류 block 의 우선순위

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

### 4.4 루프 상한

구조 검증이 매 턴 실패하면 매 턴 block 이 나가고, 모델이 고치지 못하면 멈추지 않는다.
CLAUDE.md 의 **Unbounded autonomy** 금지 조항이 직접 걸린다.

`arm_ledger` 의 `dispatch_attempts`(G6, 상한 3)와 **동형의 별도 카운터**
`validation_attempts` 를 문서 키별로 둔다.

- 구조 실패로 block 을 낼 때마다 그 문서의 `validation_attempts` 를 1 증가시킨다.
- 상한(3)에 닿으면 block 대신 advisory 를 내고 그 문서를 이번 세션에서 더 이상 검증하지
  않는다. 문면은 `dispatch_attempts` 상한의 것과 같은 형태로, **수명 사실만** 적고 면제를
  적지 않는다.
- 구조 검증을 통과하면 그 문서의 카운터를 삭제한다.

`dispatch_attempts` 를 재사용하지 않는다. 둘은 서로 다른 실패를 세고, 합치면 구조 실패
2회 뒤에 리뷰 dispatch 가 1회밖에 남지 않는다.

### 4.5 git 이 없는 리포

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

이것은 **현재 대비 좁아지는 커버리지**다. §13 R6 에 위험으로 올린다.

### 4.6 kill switch 재편

`spec-write-validator.py` 가 사라지면 아래 두 토큰이 가리킬 대상이 없어진다.

| 토큰 | 지금 | 판본 4 |
|---|---|---|
| `DEVBREW_SKIP_HOOKS=spec-distill:validator` | Layer 1 만 끔 | 대상 없음 |
| `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` | Layer 1 만 끔 | 대상 없음 |
| `DEVBREW_SKIP_HOOKS=spec-distill:Stop` / `:review-dispatch` | 리뷰 dispatch 만 끔 | **구조 검증까지 함께 끔** |
| `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` | Layer 1 유지 + arm skip | 그대로 |
| `DEVBREW_SPEC_DISTILL_DISABLE=1` | 전체 | 그대로 |

**잃는 조합이 하나 있다** — "리뷰는 끄고 구조 검증은 유지". `SKIP_AUTOREVIEW` 가 그 조합의
지정 대체재다 (arm 을 끄고 Layer 1 은 남긴다). 두 사라지는 토큰은 CLAUDE.md 의 one-minor
deprecation window 대상이다: 0.34.0 에서 인식하되 *대상 없음* advisory 를 내고, 0.35.0 에서
제거한다.

## 5. quality-gates — scope 를 git 으로

`post-tool-use-session-tracker.py` 와 그 산출물 `files.md` 를 제거한다. `/qg` 의 기본 scope 가
"이 세션이 편집한 파일"에서 **git 이 보고하는 변경**으로 바뀐다.

**이것은 관측 가능한 기본 동작 변경이다** — quality-gates 4.2.3 → 5.0.0 (major).

| 무엇 | 지금 | 판본 4 |
|---|---|---|
| 기본 scope 출처 | `files.md` 누적 | `git status` + base 대비 `git diff` |
| 세션 중 커밋된 변경 | `files.md` 에 남음 | base 대비 diff 가 잡음 |
| 리포 밖 절대경로 편집 | `files.md` 에 남음 | **잡히지 않음** |
| 브랜치 전환 시 | `pre-pipeline-check.sh` 가 `files.md` 를 지움 | 해당 없음 — git 이 항상 현재를 본다 |

**정리해야 하는 소비 지점** (전수):

| 파일 | 무엇 |
|---|---|
| `scripts/pre-pipeline-check.sh:41` | `SESSION_FILE` 정의 및 그 소비 |
| `scripts/qg-gc.py:49` | `SESSION_MARKERS` 에서 `files.md` 제거 |
| `commands/qg.md` Scope 절 | 서술 갱신 |
| `skills/quality-pipeline/references/state-file-format.md` | 동반 파일 목록 |
| `README.md:456,477` | Hooks Installed · state 파일 목록 |
| `tests/test_session_tracker.py` | 삭제 |
| `tests/test_kill_switches.py:131,309` | 이 훅의 side-effect 케이스 제거 |
| `tests/test_session_end_cleanup.py:19` · `tests/test_qg_gc.py:165` · `tests/test_utf8_explicit.py:222` · `tests/test_hook_cwd_contract.py:40,60` · `tests/test_qg_false_clean_floor.sh:44,67,84` · `tests/e2e-scenarios.md:154` | `files.md` 참조 제거 또는 다른 마커로 교체 |

**정직-verdict floor 는 그대로 둔다.** `check-review-scope.sh` 의 `changes_exist` 와 그것에
기대는 floor 는 git 기반이라 이 변경의 영향을 받지 않는다. 오히려 scope 산출과 floor 가
같은 출처를 쓰게 되어 둘이 어긋날 여지가 사라진다.

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
이렇게 말한다:

> `[project-init] charter 미완료: <항목> 비어 abort. git-workflow 산출물은 정상 생성되며,
> docs-lint이 ## Project Charter 미완을 사후 플래그합니다.`

`docs-lint` 가 사라지면 아무도 사후 플래그하지 않는다. **이 약속은 철회한다** — 문면을
사후 플래그를 약속하지 않는 형태로 바꾼다. 문장만 고치고 기능을 남겨두는 것이 아니라,
사후 플래그라는 기능 자체를 제공하지 않는다고 밝힌다.

`commands/project-init.md:227` 은 `.claude/rules/agent-tool-permission.md` 를 `AGENTS.md` 에서
링크하지 않는 이유로 *"docs-lint R6(내부 링크 해석)이 매 `AGENTS.md` 쓰기마다 발화한다"* 를
든다. 파일 배치 결정 자체는 유지하되(git 에서 제외되는 파일을 커밋되는 문서가 가리키는
것은 그 자체로 부적절하다) 근거 문장에서 docs-lint 참조를 걷어낸다.

**버전**: project-init 2.1.1 → 3.0.0 (major — 훅 제거는 breaking).
`DEVBREW_SKIP_HOOKS=project-init:docs-lint` 토큰은 §4.6 과 같은 deprecation window 를 따른다.
`project-init:PostToolUse` 토큰은 남는 `post-tool-use.py` 를 계속 가리키므로 유효하다.

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

## 8. 비용 — 측정 프로토콜

판본 3 은 훅이 늘어나므로 느려지지 않음을 증명하려 했다. 판본 4 는 훅이 줄어드므로
**개선을 증명한다.** 방향이 반대이지만 프로토콜은 같다.

| 무엇 | 어떻게 |
|---|---|
| 기준선 | **현재 코드**의 턴당 누적 훅 시간 |
| 비교군 | 이 설계 적용 후 같은 시나리오 |
| 시나리오 | 도구 호출 30회 고정 — Read 20 · Bash 5 · Write 3 · Grep 2 |
| 지표 | 플러그인별 합 **과** 턴 벽시계 **둘 다** 기록 (병렬·직렬 여부가 이 차이로 드러난다) |
| 측정 방법 | 측정 전용 `hooks.json` 사본에서 `command` 를 `/usr/bin/time -p` 로 감싸고 그 stderr 를 파일로 리다이렉트 |

**측정 래퍼를 배포본에 넣지 않는다.** `/usr/bin/time -p` 는 stderr 에 쓰는데 spec-distill 의
집행 채널이 stderr 다. 래퍼가 차단 사유를 오염시킨다. `/usr/bin/time` 은 비-macOS 에서
보장되지 않으므로, 부재 시 측정을 **실패로 보고**하고 추정치를 만들지 않는다.

**예비 측정** (정식 측정이 아니다 — 프로토콜 밖에서 잰 참고값):
`spec-write-validator.py` 31.6ms · `post-tool-use-session-tracker.py` 23.6ms ·
`docs-lint.py` 26.2ms · 맨 `python3` 기동 17.4ms · `git status` pathspec 12.8ms.
정식 측정은 위 프로토콜대로 다시 수행한다.

**이 설계가 통과해야 할 방향**: 비교군의 턴당 누적 훅 시간이 기준선보다 **작아야 한다.**
크거나 같으면 설계의 전제(훅을 줄이는 것이 개선이다)가 틀린 것이므로 멈추고 재검토한다.
구체적 임계는 §14 미결 1.

## 9. Acceptance Criteria

각 AC 옆의 괄호는 그것을 재는 수단이다 (§11.1 락 번호 또는 §11.3 행동 케이스 번호).

| # | 기준 | 재는 것 |
|---|---|---|
| AC1 | `plugins/*/hooks/hooks.json` 의 어떤 `PostToolUse` 항목도 matcher 에 `Write`·`Edit`·`MultiEdit`·`NotebookEdit` 를 포함하지 않는다 | L1 |
| AC2 | `spec-write-validator.py`·`post-tool-use-session-tracker.py`·`docs-lint.py` 세 파일이 존재하지 않고, 어떤 `hooks.json` 도 그 경로를 참조하지 않는다 | L2 |
| AC3 | `review-dispatch.py` 가 `parse_spec_structure` 의 순수 함수를 import 로 호출하고 반환을 소비한다 | L3 |
| AC4 | `review-dispatch.py` 가 `parse_spec_structure.py` 를 subprocess 로 실행하지 않는다 | L3 |
| AC5 | Bash heredoc 으로 **미커밋** 스코프 문서를 쓰면 턴 끝에 구조 검증이 돌고 리뷰가 dispatch 된다 | E1 |
| AC6 | Bash `sed -i` 로 **커밋된** 스코프 문서를 고치면 구조 검증은 돌고 arm 은 붙지 않는다 | E2 |
| AC7 | 같은 dirty 문서를 Bash 로 두 번째 편집해도 그 턴에 다시 검증된다 | E3 |
| AC8 | 스코프 문서를 `Read` 로 읽기만 한 턴에는 검증도 dispatch 도 일어나지 않는다 | E4 |
| AC9 | subagent 가 Bash 로 쓴 스코프 문서도 AC5 를 만족한다 | E5 |
| AC10 | 한 턴에 문서 3개가 새로 생기면 셋 다 구조 검증을 받고, dispatch 는 자격 있는 것 중 정렬 첫 하나, 나머지 둘의 이름이 advisory 에 나온다 | L4 · E6 |
| AC11 | 구조 검증이 실패하면 그 사유로 block 이 나가고 리뷰 dispatch 는 그 턴에 일어나지 않는다 | L5 · E7 |
| AC12 | 같은 문서의 구조 검증이 3회 실패하면 4회째부터 block 대신 advisory 가 나가고 그 세션에서 재검증되지 않는다 | L6 · E8 |
| AC13 | git 을 쓸 수 없으면 loud advisory 가 세션당 1회 나가고 검증·dispatch 는 일어나지 않는다 | L7 · E9 |
| AC14 | `git status` 호출이 `-z`·`-uall`·`--no-optional-locks`·`:(top,literal)` 네 플래그를 모두 쓰고, 공백·개행·비-UTF-8 바이트가 든 파일명을 올바르게 파싱한다 | L8 · E10 |
| AC15 | 새 하위 디렉토리 안의 문서가 파일 단위로 발견된다 | E11 |
| AC16 | kill switch 검사가 발견·검증·dispatch 를 모두 **지배한다** (호출 지점마다 위쪽) | L9 · E12 |
| AC17 | Bash 로 쓴 파일이 `/qg` 기본 scope 에 들어간다 | E13 |
| AC18 | `commands/project-init.md` 에 `docs-lint` 참조가 없고, 사후 플래그를 약속하는 문장이 없다 | L10 |
| AC19 | 세 `plugin.json` bump + 각 CHANGELOG 항목 + 세 README "Hooks Installed" 갱신 | L11 |
| AC20 | 제거된 kill switch 토큰 둘이 CHANGELOG 의 Deprecated 항목에 이름으로 적혀 있다 | L12 |
| AC21 | §8 기준선·비교군 측정값이 CHANGELOG 에 기록되고 비교군이 기준선보다 작다 | L13 |

## 10. 고칠 파일

| 파일 | 무엇 |
|---|---|
| `plugins/spec-distill/hooks/spec-write-validator.py` | **삭제** |
| `plugins/spec-distill/hooks/review-dispatch.py` | 발견 · 구조 검증 · 우선순위 · `validation_attempts` 흡수 |
| `plugins/spec-distill/scripts/parse_spec_structure.py` | `resolve_mode`·`_frontmatter_has_locked_decisions` 수용 (훅에서 이동) |
| `plugins/spec-distill/scripts/arm_ledger.py` | `validation_attempts` 카운터 추가 |
| `plugins/spec-distill/hooks/hooks.json` | `PostToolUse` 블록 제거 |
| `plugins/quality-gates/hooks/post-tool-use-session-tracker.py` | **삭제** |
| `plugins/quality-gates/hooks/hooks.json` | 쓰기 matcher 블록 제거 (`Bash` 블록 유지) |
| `plugins/quality-gates/scripts/pre-pipeline-check.sh` | `SESSION_FILE` 제거 |
| `plugins/quality-gates/scripts/qg-gc.py` | `SESSION_MARKERS` 갱신 |
| `plugins/quality-gates/commands/qg.md` | Scope 절 갱신 |
| `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` | 동반 파일 목록 갱신 |
| `plugins/project-init/hooks/docs-lint.py` | **삭제** |
| `plugins/project-init/tests/test_docs_lint.py` | **삭제** |
| `plugins/project-init/hooks/hooks.json` | 쓰기 matcher 블록 제거 (`Bash` 블록 유지) |
| `plugins/project-init/commands/project-init.md` | `:125` 약속 철회 · `:227` 근거 갱신 |
| 세 `plugin.json` | 0.33.0→0.34.0 · 4.2.3→5.0.0 · 2.1.1→3.0.0 |
| 세 `CHANGELOG.md` | Removed · Changed · Deprecated 항목 + §8 측정값 |
| 세 `README.md` | "Hooks Installed" · state 파일 목록 |
| 회귀 테스트 | §11 |

## 11. 검증 계획

### 11.1 회귀 락

각 락은 **양의 짝과 음의 짝을 함께** 가진다. 음의 락(`X 가 없다`)만 두면 대상을 통째로
삭제해도 통과한다 — 그 상태가 최대 fail-open 이다.

**대상은 구조에서 도출한다.** L1·L2 는 세 플러그인 이름을 하드코딩하지 않고
`plugins/*/hooks/hooks.json` 을 glob 으로 열거한다. 네 번째 플러그인이 같은 결함을 들고
들어오면 그때도 RED 여야 한다.

| 락 | 양 (존재) | 음 (부재) |
|---|---|---|
| L1 | `plugins/*/hooks/hooks.json` 이 하나 이상 발견되고 전부 파싱된다. 각 `PostToolUse` 항목의 `command` 가 실재 파일을 가리킨다 | 어떤 `PostToolUse` 항목의 matcher 도 `Write`·`Edit`·`MultiEdit`·`NotebookEdit` 를 포함하지 않는다 (`Bash` 는 허용) |
| L2 | 남아야 할 훅 파일(`review-dispatch.py`·두 `post-tool-use.py`)이 존재하고 `hooks.json` 이 그것을 가리킨다 | 삭제 대상 세 파일이 존재하지 않고 어떤 `hooks.json`·테스트·문서도 그 경로를 참조하지 않는다 |
| L3 | `review-dispatch.py` 가 `parse_spec_structure` 의 함수를 import 해 호출하고 그 반환을 조건·수집에 쓴다 (AST) | `review-dispatch.py` 에 `subprocess` 호출이 없다 (AST) |
| L4 | dispatch 대상이 `should_arm` True 인 것 중 정렬 첫이고, 나머지 이름이 advisory 문자열에 실린다 | dispatch 호출이 루프 안에 없다 (AST) |
| L5 | 구조 실패 경로가 block 을 내고 그 경로에서 dispatch 호출에 도달하지 않는다 (AST 지배 관계) | 두 사유가 한 block 문자열에 합쳐지지 않는다 |
| L6 | `validation_attempts` 가 상한에 닿으면 block 대신 advisory 를 내는 분기가 있고, 통과 시 카운터를 삭제하는 호출이 있다 | 상한 상수가 `dispatch_attempts` 의 것과 **별개 이름**이다 |
| L7 | git 불능 분기가 advisory 를 내고 후보 목록을 비운 채 반환한다. 래치 마커를 쓴다 | 그 분기가 후보 목록을 반환하지 않는다 |
| L8 | `git status` 인자에 네 플래그가 모두 있고 `-z` 출력을 NUL 로 분해한다 | 넷 중 어느 것도 빠지지 않는다 |
| L9 | kill switch 검사가 발견·검증·dispatch 세 호출을 **모두 지배한다** (AST 지배 관계) | kill switch 뒤에 조기 호출이 없다 |
| L10 | `commands/project-init.md` 가 존재하고 charter abort 문면이 있다 | 그 파일에 `docs-lint` 문자열이 없고 사후 플래그를 약속하는 문장이 없다 |
| L11 | 세 `plugin.json` 버전이 `origin/main` 보다 높고 각 CHANGELOG 에 그 버전 항목이 있다 | 세 README 의 "Hooks Installed" 에 삭제된 훅 이름이 없다 |
| L12 | 두 CHANGELOG 에 Deprecated 항목이 있다 | 그 항목이 사라지는 토큰 두 개를 **문자 그대로** 담는다 |
| L13 | CHANGELOG 에 기준선·비교군 두 수가 있다 | 비교군이 기준선보다 크지 않다 |

**L10~L13 에도 음의 짝을 뒀다.** 판본 3 은 이 셋에 *"존재가 곧 불변식"* 이라며 음의 짝을
비웠다가 적발됐다 — 존재 락은 스텁으로 만족된다. 근거 없는 면제를 두지 않는다.

### 11.2 이빨 확인

각 락은 **mutation 으로 이빨을 증명한다.** 네 축으로 흔든다 — 삭제·추가·반전·형태 변경.

| 락 | mutation | 기대 |
|---|---|---|
| L1 양 | `hooks.json` 하나를 잘못된 JSON 으로 만든다 | RED |
| L1 양 | `command` 를 없는 파일 경로로 바꾼다 | RED |
| L1 음 | 어느 `PostToolUse` 항목에 `"matcher": "Write\|Edit"` 를 되살린다 | RED |
| L1 음 | matcher 를 `"NotebookEdit"` 단독으로 넣는다 | RED |
| L1 음 | matcher 를 `"Bash"` 로 넣는다 | **GREEN** (양성 대조 — §3.2 가 허용) |
| L2 양 | `review-dispatch.py` 를 지운다 | RED |
| L2 음 | `spec-write-validator.py` 를 빈 파일로 되살린다 | RED |
| L2 음 | README 에만 `docs-lint.py` 참조를 남긴다 | RED |
| L3 양 | import 는 남기고 반환값을 버린다 | RED |
| L3 음 | `subprocess.run(["python3", PARSE_LIB, ...])` 를 되살린다 | RED |
| L3 음 | `subprocess` 를 `os.popen` 으로 바꾼다 | RED |
| L4 | 자격 검사를 빼고 위치만으로 첫 문서를 고른다 | RED |
| L4 | advisory 에서 나머지 문서 이름 나열을 지운다 | RED |
| L5 | 구조 실패 뒤에도 dispatch 로 진행하게 만든다 | RED |
| L5 | 두 사유를 한 문자열로 합친다 | RED |
| L6 | `validation_attempts` 상한 분기를 지운다 | RED |
| L6 | `validation_attempts` 를 `dispatch_attempts` 로 대체한다 | RED |
| L7 | git 불능 분기가 후보 전체를 반환하게 되돌린다 | RED |
| L7 | `except` 절을 좁힌다 (`Exception` → `FileNotFoundError`) | RED |
| L8 | 네 플래그 각각을 하나씩 지운다 (4회 반복) | RED |
| L8 | `-z` 는 남기고 파싱만 개행 분해로 되돌린다 | RED |
| L9 | kill switch 검사를 발견 호출 **뒤로** 옮긴다 | RED |
| L10 | `:125` 문면을 원래대로 되돌린다 | RED |
| L11 | 한 `plugin.json` 만 bump 를 빼먹는다 | RED |
| L12 | Deprecated 항목에서 토큰 하나를 지운다 | RED |
| L13 | 비교군 수를 기준선보다 큰 값으로 바꾼다 | RED |

`except` 절 좁히기가 있는 이유: 이 플러그인이 실제로 두 번 겪은 실패 모드다
(`UnicodeDecodeError ⊄ OSError`, `ImportError` vs `Exception`). 방향 반전만 잠그면 좁히기는
통과한다.

**셸 본문 추출기를 쓰지 않는다.** 파이썬 대상 락은 `ast.parse`, 셸 대상은 `bash -n` 으로
먼저 스윕한다 — 이 리포에서 정규식 본문 추출기가 다섯 번 연속 조용히 깨진 이력이 있다.

`PYTHONDONTWRITEBYTECODE=1` 로 돌린다 — 같은 길이 변이는 stale `.pyc` 를 넘지 못해 거짓
GREEN·거짓 RED 를 둘 다 낸다.

**양성 대조**: mutation 전 스위트가 GREEN 인지 먼저 확인한다. RED 자체는 계측기가 살아
있다는 증거가 아니다. L1 음의 `Bash` matcher 케이스는 **GREEN 이 정답인 양성 대조**이며,
그것이 RED 로 나오면 락이 §3.2 를 위반한 것이다.

### 11.3 행동 케이스

정적 검사로 확인할 수 없는 AC 는 헤드리스 턴으로 잰다. §9 가 각 AC 옆에 케이스 번호를
달았고, 아래가 그 목록이다.

| # | 무엇을 재나 |
|---|---|
| E1 | Bash heredoc → 미커밋 문서 → 턴 끝 구조 검증 + 리뷰 dispatch |
| E2 | Bash `sed -i` → 커밋된 문서 → 구조 검증 실행, arm 없음 |
| E3 | 같은 dirty 문서를 Bash 로 두 번째 편집 → 그 턴에 다시 검증 |
| E4 | 스코프 문서를 `Read` 만 한 턴 → 무반응 |
| E5 | subagent 의 Bash heredoc → E1 과 동일 결과 |
| E6 | 한 턴에 문서 3개 → 검증 3, dispatch 1, advisory 에 나머지 2 |
| E7 | 구조 실패 문서 → 그 사유로 block, dispatch 없음 |
| E8 | 같은 문서 구조 실패 4턴 반복 → 4턴째 advisory, 재검증 없음 |
| E9 | `PATH` 에서 git 제거 → advisory 1회 + 무발동, 두 번째 턴에는 advisory 없음 |
| E10 | 파일명에 공백·개행·비-UTF-8 바이트 → 파싱 정확 |
| E11 | 새 하위 디렉토리 안의 문서 → 파일 단위 발견 |
| E12 | kill switch 켬 → 발견·검증·dispatch 전부 무발동 |
| E13 | Bash 로 쓴 파일이 `/qg` 기본 scope 에 등장 |

프로브 플러그인과 재현 커맨드는 `shared/tests/fixtures/hookprobe/` 에 이미 커밋돼 있다.
`--permission-mode acceptEdits` 없이는 편집이 rc 0 으로 조용히 죽으므로 반드시 붙인다.
임시 디렉토리는 만든 직후 `pwd -P` 로 한 번 정규화한다 — macOS 의 `/tmp` 는 `/private/tmp`
심볼릭 링크라 경로 포함 검사가 조용히 무너진다.

### 11.4 선재 RED

작업 전에 세 플러그인 테스트 스위트의 기준선을 캡처한다. quality-gates 에는 `main` 에
선재 RED 가 있는 것으로 기록돼 있어, 그것을 이번 변경의 회귀로 오인하지 않기 위해서다.
기준선 목록에 올리는 각 항목에는 **왜 면제인지 한 줄**을 함께 적는다 — 이유 없는 면제
목록은 그 질문을 영구히 닫는다.

## 12. 기각한 대안

| 대안 | 왜 기각했나 |
|---|---|
| **matcher 에 `Bash` 추가 + 명령어 파싱** | `cat >`·`tee`·`sed -i`·`>>`·`printf`·`perl -i`·`mv`·`git apply` — 열거를 하나 빠뜨릴 때마다 조용한 fail-open. 고치려는 결함을 한 층 아래로 옮긴다 |
| **matcher 에 `Bash` 만 추가 (열거를 정직하게)** | Bash payload 에는 `file_path` 가 없다. 발화한 뒤 무엇을 검사할지가 미정이라 단독으로 성립하지 않는다 — 감지 방식을 요구하는 것이지 대안이 아니다. 게다가 훅이 모든 호출에 돌아 비용이 배 이상이 된다 |
| **payload 의 `file_path` 로 분기** | `Read` 의 `tool_input` 도 `file_path` 다. 읽기만 해도 검증·arm 이 돈다 — 도구 열거의 재발 (판본 2 의 실패) |
| **`shared/writewatch/` 감지 모듈** | 판본 3 의 방식. 귀속 상실 — `git checkout`·`merge`·에디터 편집이 "이 도구 호출이 바꿨다"가 되어 사용자가 손대지 않은 문서로 턴이 막힌다. 비용도 dirty 집합 크기에 비례한다 |
| **`UserPromptSubmit` 기준선 + 내용 해시** | 위 모듈의 부속. 기준선을 남의 훅에 얹으면 그 훅의 조기 return 경로에 삼켜지고, 그 훅의 kill switch 가 Law 1 기준선까지 끈다 |
| **`os.scandir` 전수 스캔** | 제외 규칙(`.git`·`node_modules`·`.gitignore`)을 손으로 만들어야 하고 그 목록이 **또 하나의 열거**가 된다. git 은 그 규칙을 이미 안다 |
| **`PostToolBatch` 로 교체** | matcher 가 없어 열거 문제는 사라지지만 `exit 2` 가 "루프 정지 + stderr 는 사용자에게만"이라 구조 검증의 모델 피드백을 잃는다 |
| **`FileChanged` 로 파일 감시** | 층위는 가장 정확하나 집행력이 없고(exit≠0 이 사용자에게만 간다), 실측에서 matcher 3변형 모두 0건이었다. `Stop` 로 옮기면 이 이벤트가 답하려던 질문 자체가 없어진다 |
| **`PreToolUse` 로 Bash 쓰기 차단** | 명령어 파싱이 필요해 첫 항목과 같은 fail-open 을 물려받고, 오탐이 무관한 명령을 막는다 |
| **문서로만 "spec 문서는 Write 로 쓰라"** | 이 리포는 프롬프트 수준 분리를 집행으로 인정하지 않는다 (Law 2 의 논리). 이번 사건 자체가 그 규정이 세션 지시에 밀린 사례다 |
| **project-init `docs-lint` 를 `Stop` 훅으로 이동** | 사용자가 검사 자체의 제거를 선택했다. 이동하면 훅 수가 줄지 않고 kill switch deprecation 만 늘어난다 |
| **project-init `docs-lint` 를 `post-tool-use.py` 에 병합** | 명령 검증과 파일 규약 검사라는 다른 두 관심사가 한 프로세스에 들어가고, matcher 를 지워야 하므로 Bash 아닌 호출에서도 깨어난다 |
| **qg 세션 scope 를 다른 누적 수단으로 유지** | 누적은 어느 수단으로 하든 귀속을 요구한다. `/qg branch` 와 정직-verdict floor 가 이미 backstop 이므로 누적을 버리는 비용이 작다 |
| **`/cancel-review` 대신 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`** | v0.25.0 이 사전 옵트아웃의 지정 대체재로 명시한 스위치다. §7 분리에 따라 후속 설계가 먼저 결론지어야 한다 — 커맨드가 이 스위치보다 무엇을 더 주는지 답하지 못하면 커맨드는 불필요하다 |

**뒤집힌 기각 하나.** 판본 3 은 *"`Stop` 훅 턴-끝 전수 검사"* 를 기각했고 사유는
**"quality-gates·project-init 에 `Stop` 훅이 없어 새 훅 둘이 필요하고, 피드백이 턴 끝으로
밀린다"** 였다. 판본 4 는 이 기각을 뒤집는다. 두 근거가 각각 무너졌다:

1. **새 훅 둘이 필요하지 않다.** 두 플러그인의 훅을 *삭제*하기로 했으므로 `Stop` 훅을 만들
   대상이 없다. spec-distill 은 `Stop` 훅을 이미 가진다 — 신규 훅은 0개다.
2. **피드백 지연이 실제보다 크게 서술됐다.** `PostToolUse` 는 쓰기가 **일어난 뒤** 도는
   훅이라 지금도 문제 있는 내용은 디스크에 앉는다. `Stop` 으로 옮기면 모델이 *언제 아는지*만
   바뀌고, `decision: block` 으로 되돌아온 모델은 같은 턴 안에서 고친다.

미래 리뷰가 이 기각을 다시 들고 오지 않도록 여기 남긴다.

## 13. 위험

| # | 위험 | 완화 |
|---|---|---|
| R1 | `Stop` 훅의 `decision: block` 이 폭주한다 | `review-dispatch.py` 는 이미 30초 TTL 가드·`dispatch_attempts` G6 상한·`armed_paths` 원장 veto 로 막혀 있다. 신규 실패 모드(구조 검증)에는 §4.4 의 `validation_attempts` 를 둔다. L6 이 잠근다 |
| R2 | 구조 검증이 턴 끝으로 밀려 모델이 문제 있는 문서 위에 계속 쌓는다 | 한 턴 안의 손실이다. `PostToolUse` 도 쓰기 뒤에 돌므로 차이는 "도구 호출 몇 개" 분량이다 |
| R3 | git 불능 리포에서 게이트가 조용히 꺼진다 | §4.5 의 loud advisory. L7 이 양·음 양쪽을 잠근다 |
| R4 | qg 기본 scope 가 리포 밖 절대경로 편집을 놓친다 | 정직-verdict floor 는 git 기반이라 영향받지 않는다. 리포 밖 편집은 `--paths` 로 명시한다. §5 표에 이름으로 적는다 |
| R5 | 한 턴에 여러 문서가 바뀌어 일부가 조용히 리뷰를 잃는다 | §4 가 나머지를 **이름과 함께** 노출한다. L4 가 잠근다 |
| R6 | project-init 의 문서 규약 검사가 영구히 사라진다 | 사용자가 손실을 알고 선택했다. §6 이 사라지는 규칙을 이름으로 적고, `commands/project-init.md:125` 의 약속을 같은 커밋에서 철회한다 |
| R7 | kill switch 조합 하나가 사라진다 ("리뷰만 끄고 구조 검증 유지") | `SKIP_AUTOREVIEW` 가 지정 대체재다. §4.6 이 deprecation window 를 정한다. L12 가 CHANGELOG 기재를 잠근다 |
| R8 | 세 플러그인이 한 PR 에 major bump 셋을 싣는다 | 분할 여부는 §14 미결 3 |
| R9 | 이 설계 문서 자신이 Bash 로 쓰여 게이트를 우회한다 | 이 문서는 `Write` 도구로 작성했다. 후속 편집도 `Write`·`Edit` 로 한다. 이 세션에는 Bash 쓰기를 지시하는 운영 모드가 걸려 있으므로 그 예외를 명시적으로 적용한다 |
| R10 | codex co-reviewer 부재로 공유-맹점이 검사되지 않는다 | 사용 한도가 2026-09-17 까지 소진돼 있다. 판본 1~3 과 같은 한계다. 이 사실을 리뷰 결과에 degrade 로 표시하고, 한도 복구 후 재검토 대상으로 §14 미결 4 에 올린다 |

## 14. 미결

| # | 무엇 | 누가 언제 |
|---|---|---|
| 1 | §8 의 구체적 임계 — "비교군이 기준선보다 작다"는 방향은 정해졌으나 허용 오차가 미정 | 측정 후 사용자 확정 |
| 2 | `/cancel-review` (§7) — sid 획득 경로와 `--reset` 의 tracked 문서 무효 | 이 사이클 이후 별도 설계 |
| 3 | 세 플러그인을 한 PR 로 낼지 셋으로 쪼갤지 | plan 단계 |
| 4 | codex 한도 복구(2026-09-17) 후 이 설계의 재검토 여부 | 사용자 판단 |
