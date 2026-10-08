# skill-only 호출 표면 · Design

> 부르는 모양이 하나이고, 그 모양으로 부르면 늘 같은 것이 돈다.

devbrew 의 사용자 호출 표면(slash 명령 · slash skill · kill switch · 핸드오프 문구)을 «기능당 사용자 진입 skill 하나» 체계로 통일하고 이 브랜치(`feature/unify-command-surface`)에서 구현한다.

## Handoff Context

- 입력 brief: `docs/superpowers/interview/2026-10-08-skill-only-surface-interview.md` (확정 17항목, 커밋 67824eff)
- brief audit: `docs/superpowers/interview/2026-10-08-skill-only-surface-interview.audit.md` (RC1~RC28 · §6 S1~S9)
- brainstorming 결정: 이 문서 `## 결정 기록` B1~B12
- 재결정 규약: confirmed 항목은 근거가 있으면 보고 후 재결정할 수 있고, 임의 변경은 금지다. 이 문서의 재결정은 B6(C3 예외) 하나다.

## 목차

- [Goal](#goal)
- [Context / Why](#context--why)
- [Goals](#goals) · [Non-goals](#non-goals) · [Constraints](#constraints)
- [설계](#설계)
  - [§1 호출 지도](#1-호출-지도)
  - [§2 구성요소와 파일](#2-구성요소와-파일)
  - [§3 호출 흐름과 오류 처리](#3-호출-흐름과-오류-처리)
  - [§4 락 — 표면 정합](#4-락--표면-정합)
  - [§5 CLAUDE.md 개정문](#5-claudemd-개정문)
  - [§6 버전 · CHANGELOG · 보고서](#6-버전--changelog--보고서)
  - [§7 실측](#7-실측)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [알려진 한계](#알려진-한계)
- [결정 기록](#결정-기록)
- [Metadata](#metadata)

## Goal

사용자가 어떤 모양으로 부르든 — `/짧은이름` · `/플러그인:완전명` · 모델의 Skill 호출 — 같은 SKILL.md 가 같은 사전 단계를 거쳐 돈다. qg 밖 명령 넷을 그 체계로 옮기고, 그 정합을 테스트(락)로 집행하고, CLAUDE.md 규칙을 개정한다.

## Context / Why

사용자가 `/interview @…` 를 쳤는데 모델이 skill 로 넘기지 못하고 멈췄다(C8). 원인 후보는 `@` 읽기 실패였다. 그러나 brief 가 재구성한 진짜 문제는 **부르는 모양마다 도는 것이 다르다**는 것이다(D1).

- 명령 파일(`commands/*.md`)은 사전 단계(kill switch · trivia · `@` 풀기)를 갖는다. 같은 기능의 skill 을 직접 부르면 그 단계를 건너뛴다. 사용자는 그래서 skill 을 직접 불렀다(C6).
- 플러그인 skill 은 `/plugin:name` 으로 불리고, bare `/name` 은 다른 명령이 그 이름을 쓰지 않을 때만 풀린다. `--plugin-dir` 아래에서는 bare 이름이 아예 등록되지 않았다(헤드리스 실측 `Unknown command`).
- 사용자가 확인한 불편은 넷이다: 명령 오류 · 무엇을 칠지 헷갈림 · 문서와 실제의 불일치 · 쓸모없는 명령(C7).
- 플랫폼도 같은 방향이다. commands 는 «older format» 이고 skills 가 대체한다. 같은 이름이면 skill 이 이긴다.

현재 표면(실측):

| 기능 | 명령 | skill | 비고 |
|---|---|---|---|
| framing | `commands/request-framing.md` (trivia) | `framing-requests` | skill 노출, 직접 부르면 trivia 건너뜀 |
| interview | `commands/interview.md` (kill switch · `@` · trivia) | `conducting-interview` | `user-invocable: false` |
| spec review | 없음 | `reviewing-spec` | 자체 `## 진입 검사` 펜스(`review_entry.py`) |
| plugin audit | `plugin-audit/commands/plugin-audit.md` | `auditing-plugins` | `cost_class: high` |
| project init | `project-init/commands/project-init.md` (230줄) | 없음 | `argument-hint` 없음 |

## Goals

- G1 qg 밖 기능 다섯에 사용자 진입 skill 이 하나씩 있고, 그 밖에 qg 밖 `commands/` 가 없다.
- G2 진입 skill 은 본문 전달 전 `!` 사전 검사를 갖고, 첫 절이 그 결과를 판독한다. 어느 호출 모양이든 같다.
- G3 사용자가 치는 이름은 짧고(일반어 단독 금지), 기계가 내는 안내는 `/plugin:name` 완전명이다.
- G4 위 셋의 정합을 락 하나가 축별로 집행하고, 그 이빨을 변이로 증명한다.
- G5 CLAUDE.md 의 deprecation · `allowed-tools` · 네이밍 규칙을 이 체계에 맞게 개정한다.
- G6 qg 가 따를 변경과 qg 의 규칙 위반을 보고서로 넘긴다.

## Non-goals

- quality-gates 파일 수정. 예외는 B6 한 줄뿐이다.
- kill switch 이름 변경.
- deprecation alias · fallback 명령.
- qg v10 설계 대체. 이 작업은 규칙을 정하고 v10 은 그 규칙을 따른다(C4).
- 쉬운 말 출력 문구 작업.
- 지난 기록(docs/archive · 지난 spec/plan/brief · CHANGELOG 과거 항목)의 옛 이름 교체.

## Constraints

brief §2 의 C1~C11 · D1~D6 을 그대로 따른다. 이 설계에 직접 닿는 것:

- C3 qg 파일은 고치지 않고 보고만 한다. **B6 예외**: 디렉토리 개명이 직접 깨뜨리는 `plugins/quality-gates/tests/test_codex_gate_observation.sh` 의 라벨 `case` 줄과 그 주석만 고친다.
- C9 · D3 바꾸거나 없애는 호출 이름은 alias 없이 즉시 제거하고 major bump 한다.
- D5 짧은 이름 + 일반어 단독 금지 + 안내는 완전명.
- D6 락은 표면 정합을 잰다.
- B2 사용자 인자는 셸에 넘기지 않는다.
- CLAUDE.md: 플러그인을 건드리는 PR 마다 plugin.json bump, Law 2(`tools:` allowlist), 훅 kill switch 존중.

## 설계

### §1 호출 지도

| 치는 이름 | skill 디렉토리 (지금 → 새) | 기계 안내 완전명 | 사람 | 모델 |
|---|---|---|---|---|
| `/request-framing` | `framing-requests` → `request-framing` | `/spec-distill:request-framing` | ✅ | ✅ |
| `/spec-interview` | `conducting-interview` → `spec-interview` (숨김 해제) | `/spec-distill:spec-interview @<seed>` | ✅ | ✅ |
| `/spec-review` | `reviewing-spec` → `spec-review` | `/spec-distill:spec-review <설계문서>` | ✅ | ✅ |
| `/plugin-audit` | `auditing-plugins` → `plugin-audit` | `/plugin-audit:plugin-audit <target> [--seed <path>]` | ✅ | ❌ |
| `/project-init` | 새 `project-init` (명령 본문 이전) | `/project-init:project-init` | ✅ | ❌ |

- 사용자 전용 둘은 frontmatter 에 `disable-model-invocation: true` 를 단다(B5).
- 내부 skill `reviewing-brief` 는 `user-invocable: false` 와 동명사 이름을 유지한다(B4). 호출은 `Skill spec-distill:reviewing-brief $PAYLOAD $AUDIT` 그대로다.
- qg 의 `/qg` · `/qg-publish` · `/cancel-qg` 와 qg skill 셋은 그대로 둔다.

### §2 구성요소와 파일

| 단위 | 책임 | 의존 |
|---|---|---|
| `shared/entry/entry_preflight.py` (정본) | 상수 인자 `<plugin> <skill>` 를 받아 플러그인 kill switch(`DEVBREW_<PLUGIN>_DISABLE`)를 판정하고, 레포 루트와 환경을 검사해 감시줄 한 줄을 출력한다. 내부 실패는 전부 잡아 rc 0 + `error` 줄로 바꾼다. | `kill_switch_active.py` (각 플러그인 `scripts/` 의 copy-of 형제 사본) |
| `plugins/{spec-distill,plugin-audit,project-init}/scripts/entry_preflight.py` | 정본을 가리키는 심볼릭 링크 | 위 |
| 진입 skill 공통 머리 | `!` 줄 하나 · `allowed-tools` 사전 허용 한 항목 · `argument-hint` · `## 진입 단계` 절 | 위 |
| `shared/entry/check_invocation_surface.py` + `shared/tests/test_invocation_surface.sh` | §4 락. `--report` 모드는 qg 위반 표를 낸다 | `git ls-files` |
| `plugins/project-init/skills/project-init/SKILL.md` | 명령 본문을 옮긴 진입 skill, `cost_class` 선언 | 위 머리 |

`plugin-audit/scripts/` 에 `kill_switch_active.py` 형제 사본이 없으면 copy-of 사본을 추가한다. `test_copy_of_contract.sh` 축 1c 가 그 자리를 요구한다.

감시줄 형식(한 줄, 고정 접두):

```
[devbrew-entry] ok plugin=<p> skill=<s> root=<절대경로>
[devbrew-entry] disabled plugin=<p> skill=<s> switch=<변수명>=1
[devbrew-entry] error plugin=<p> skill=<s> reason=<한 줄 사유>
```

`!` 줄 모양(정확한 사전 허용 표기는 M1·M2 실측으로 확정한다):

```
!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" <plugin> <skill>`
```

### §3 호출 흐름과 오류 처리

```
SKILL.md 로드 → `!` 사전 검사(본문 전달 전, 상수 인자만) → 감시줄이 그 자리에 박힘
## 진입 단계
 1. 감시줄 판독
 1.5 skill 고유 검사 (있으면 — spec-review 의 review_entry 펜스)
 2. @경로 풀기
 3. trivia 판정 (request-framing · spec-interview 만, seed 면 건너뜀)
 4. 본 절차 (기존 본문)
```

**1. 감시줄 판독** — `!` 출력 자리(`## 진입 단계` 바로 위)만 본다.

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 1.5 로 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 멈춘다(no-op) |
| `[devbrew-entry] error …` | 사유를 크게 보고하고 멈춘다 |
| `[shell command execution disabled by policy]` | «사전 검사 불가(정책)»를 보고하고 멈춘다(fail-closed) |
| 감시줄 없음 · 그 밖 | 위와 같은 문구로 멈춘다 |

- rc≠0 이면 플랫폼이 호출 전체를 끊고, 헤드리스에서는 그것이 0턴 rc=0 조용한 실패가 된다. 그래서 스크립트는 자기 실패를 rc 0 + `error` 줄로 바꾼다.
- 남는 rc≠0 경로는 «스크립트 부재 · python3 부재» 둘이다. 이 경로는 fail-closed 로 끊긴다. 세 README 에 공시한다.
- 플러그인 전체 kill switch 를 본문 산문으로 다시 확인하던 자리(`conducting-interview` · `framing-requests` 의 `DEVBREW_SPEC_DISTILL_DISABLE` 산문)는 1단계로 대체한다. skill 고유 스위치(`review_entry.py` 의 셋 · 은퇴 스위치 공시)는 1.5 에 그대로 남는다.

**2. `@경로` 풀기** — 산문 규칙과 Read 도구로 한다.
- 인자가 `@` 로 시작하는 공백 없는 한 토큰일 때만 발동한다.
- `@` 를 뗀다. 상대경로는 감시줄 `root=` 기준으로 푼다. 절대경로인데 존재하지 않으면 `root=` 기준 상대경로로 한 번 더 시도한다.
- 실패하면 시도한 절대경로와 관측 사유를 담아 멈춘다. 인터뷰·프레이밍을 시작하지 않는다.
- M4 결과로 규칙을 확정한다. 이 규칙은 `/interview` Step 1.5 의 seed audit 경로 한 줄 출력을 그대로 잇는다.

**3. trivia** — `references/trivia-escape.md` 다섯 패턴. 안내의 `<command>` 는 완전명(`spec-distill:spec-interview` · `spec-distill:request-framing`)으로 채운다. `force` 탈출구는 유지한다.

**인자 경계** — `$ARGUMENTS` · 위치 인자는 산문 자리에만 둔다. `!` 줄과 ```` ```! ```` 블록 안에는 두지 않는다(락 D).

**핸드오프** — `framing-requests` 의 «호출 모양» 정본(883행 부근)과 `finishing.md` 등 기계가 내는 안내는 완전명으로 바꾼다.

### §4 락 — 표면 정합

대상은 `git ls-files` 에서 도출한다. qg 파일은 **보고 모드**로 돌린다 — 위반을 RED 로 막지 않고 표로 내며, 그 표가 §6 보고서의 원천이다.

| 축 | 대상 (도출) | 판정 |
|---|---|---|
| A 이름 | `user-invocable: false` 가 아닌 skill = 진입 skill | `name` = 디렉토리, kebab 두 단어 이상, 첫 단어가 `-ing` 형이 아님 |
| B 내부 | `user-invocable: false` skill | 첫 단어가 `-ing` 형(동명사) |
| C 머리 | 진입 skill | `!` 줄 정확히 하나, 인자 = 자기 `<plugin> <name>`, `allowed-tools` 가 그 한 항목만, `## 진입 단계` 절 존재 |
| D 인자 경계 | 모든 SKILL.md · references 의 `!` 줄과 ```` ```! ```` 블록 | 사용자 인자 토큰(`$ARGUMENTS` · `${ARGUMENTS}` · `$0`~`$9` · `$[0-9]`) 0개 |
| E 키 | 모든 SKILL.md frontmatter | 공식 문서의 skill frontmatter 키 목록 ∪ {`cost_class`}. 목록과 확인 날짜를 테스트 주석에 적는다 |
| F 모델 호출 | `disable-model-invocation: true` 인 진입 skill | 집합이 **정확히** {plugin-audit, project-init} |
| G 안내 | 기계 코퍼스(`plugins/*/skills/**` · `plugins/*/hooks/**` · `plugins/*/scripts/**`) | `/p:x` 는 실재하는 사용자 호출 가능 skill 로 풀린다. 진입 skill 짧은 이름의 bare `/x` 는 RED |
| H 명령 층 | `plugins/*/commands/` | qg 밖 0개. qg 는 `plugins/quality-gates/commands/` 가 있는 동안 보고 모드 |
| I 옛 이름 | 살아 있는 표면(아래) | 옛 이름 0개 + **양성 짝**: 새 이름 다섯이 각 자기 자리에 실재 |

- 살아 있는 표면: `plugins/**` · `shared/**` · `CLAUDE.md` · `README.md` · `docs/philosophy/**` · `docs/plugin-authoring.md`. `**/CHANGELOG.md` 는 제외한다.
- 옛 이름 집합: `/interview`(단어 경계) · `conducting-interview` · `framing-requests` · `reviewing-spec` · `auditing-plugins` · `commands/(interview|request-framing|plugin-audit|project-init).md`.
- RED 메시지는 자기 범위를 밝힌다. 예: «qg 는 `plugins/quality-gates/commands/` 가 있는 동안 보고만 된다».

**이빨** — 테스트가 임시 복사본(`git clone --no-local`)에 축마다 변이를 심고, RED 와 그 축의 사유 문자열을 함께 확인한다. 변이는 삭제 · 추가 · 반전 · 표기 변형 네 종류다(예: `!` 줄 삭제 · 둘로 복제 · 인자 바꿔치기 · `$ARGUMENTS`→`${ARGUMENTS}` · `disable-model-invocation` 를 spec-review 에 추가 · plugin-audit 에서 제거 · 옛 이름 재삽입 · 새 skill 디렉토리 삭제). 같은 복사본의 무변이 실행 GREEN 이 양성 대조다. `PYTHONDONTWRITEBYTECODE=1` 로 돌린다.

### §5 CLAUDE.md 개정문

네 자리. 굵은 글씨가 새 문면이다.

1. 메타데이터(36행): «제거 전 one-minor deprecation window. **예외 — 호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다. 이 예외는 제3자 설치가 확인되면(외부 이슈 · 설치 보고 · 마켓플레이스 공개 등록) 소멸한다. kill switch 이름은 이 예외에 들지 않는다 — 은퇴시키려면 CHANGELOG `Removed` 와 README 에 공시가 필수다.**»
2. `allowed-tools`(42행): «**`allowed-tools` 는 제한이 아니다**(2026-08-22 실측 유지). **command 에서는 쓰지 않는다. skill 에서는 진입 `!` 사전 검사 한 줄의 사전 허용으로만 쓰고 다른 도구를 열거하지 않는다.**» 실측 기록 문장은 남긴다.
3. 네이밍(70행): «**사용자가 부르는 진입 skill 은 짧은 kebab 두 단어 이상(일반어 단독 금지 — `spec-review`, `plugin-audit`)이고 디렉토리 이름 = `name` 이다. 모델만 부르는 내부 skill(`user-invocable: false`)은 동명사(`reviewing-brief`). 기계가 내는 안내는 `/plugin:name` 완전명. 새 `commands/` 는 만들지 않는다 — 사전 단계는 진입 skill 의 `!` 로. 집행: `shared/tests/test_invocation_surface.sh`.**»
4. Polite handoff(87행): `reviewing-spec` → `spec-review`, `conducting-interview` → `spec-interview`.

같이 고치는 곳: `docs/plugin-authoring.md` canonical 구조에서 `commands/` 제거, `docs/philosophy/devbrew-harness-philosophy.md` 의 옛 이름 참조 1곳.

### §6 버전 · CHANGELOG · 보고서

- 자리: spec-distill major · project-init major · plugin-audit major(1.0.0) · quality-gates patch(B6). 번호 문자열은 머지 직전에 base 를 보고 확정한다.
- CHANGELOG 셋의 `Removed` 에 옛 이름 → 새 완전명 대응표를 싣는다. plugin-audit 은 기존 CHANGELOG 에 1.0.0 절을 추가한다.
- 보고서 `docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md` 는 두 부분으로 이루어진다.
  1. «v10 이 따를 변경»: 진입은 `!` 를 가진 skill, CLAUDE.md §5 문안 인용, B6 라벨 줄.
  2. 락 `--report` 가 낸 qg 위반 전부. 행마다 «v10 설계가 다룸(행 번호) / 언급 없음» 칸을 붙인다.
- 다른 워크트리의 v10 설계는 고치지 않는다. 보고서 경로를 사용자에게 넘긴다.
- README 는 호출 줄과 «Principles Instantiated» 만 고친다. 쉬운 말 작업과 순서를 강제하지 않고, 충돌은 나중에 머지하는 쪽이 해소한다(OQ16).

### §7 실측

격리 설치본(`CLAUDE_CONFIG_DIR=<빈 tmp>`)에서 잰다. 쓰기 전에 빈 디렉토리에서 플러그인 0개임을 확인해 격리를 증명한다. 헤드리스 판정은 rc 가 아니라 stream-json 출력 내용으로 한다.

| # | 무엇을 | 통과 조건 | 게이트 |
|---|---|---|---|
| M1 | 모델의 Skill 호출에서도 `!` 가 도는가 (`spec-review`) | 주입 본문에 `[devbrew-entry] ok … skill=spec-review` | 머지 |
| M2 | 설치본에서 bare 이름 · 완전명 | 다섯 모두 감시줄, `Unknown command` 0 | 머지 |
| M3 | `disable-model-invocation` | 사람이 치면 돈다 · 모델은 못 부른다 | 머지 |
| M5 | `disableSkillShellExecution: true` | placeholder 판독 후 크게 멈춤 | 머지 |
| M6 | `DEVBREW_SPEC_DISTILL_DISABLE=1` | `disabled` 줄 · no-op | 머지 |
| M4 | `@` 실패 원인 (대화형, 사용자 실행) | 원인 특정 → §3-2 규칙 확정 | 기록 |

게이트 실측이 틀리면 패치로 덮지 않고 이 설계로 돌아온다. 결과는 이 절에 날짜 · Claude Code 버전과 함께 기록한다.

## Acceptance Criteria

- AC1 `plugins/*/commands/` 는 quality-gates 에만 있다.
- AC2 §1 의 진입 skill 다섯이 그 디렉토리 · `name` 으로 실재하고, `reviewing-brief` 는 `user-invocable: false` 다.
- AC3 진입 skill 다섯이 §2 공통 머리와 §3 진입 단계를 갖는다. `spec-review` 는 1.5 에 기존 `review_entry` 펜스를 유지한다.
- AC4 `disable-model-invocation: true` 인 진입 skill 집합이 정확히 {plugin-audit, project-init} 이다.
- AC5 `entry_preflight.py` 는 정본 하나이고 세 플러그인에 심볼릭 링크로 실린다. `test_copy_of_contract.sh` 가 GREEN 이다.
- AC6 `test_invocation_surface.sh` 가 레포에서 GREEN 이고, 축 A~I 의 변이가 전부 RED 와 그 축의 사유를 낸다. 양성 대조는 GREEN 이다.
- AC7 살아 있는 표면에서 옛 이름이 0건이다(락 I). 미실행 seed 의 핸드오프 줄도 완전명으로 바뀐다.
- AC8 CLAUDE.md 네 자리가 §5 문면대로 개정되고 `docs/plugin-authoring.md` · 철학 문서 참조가 갱신된다.
- AC9 세 플러그인과 qg 의 plugin.json 이 §6 자리대로 bump 되고, CHANGELOG 셋에 대응표가 있다.
- AC10 qg 에서 바뀐 것은 `test_codex_gate_observation.sh` 의 라벨 `case` 줄과 그 주석, 그리고 plugin.json · CHANGELOG 뿐이다.
- AC11 M1 · M2 · M3 · M5 · M6 이 통과하고 §7 에 기록된다. M4 결과와 §3-2 최종 규칙이 기록된다.
- AC12 전체 스위트가 baseline 대비 새 RED 0 · 실패 줄 수 증가 0 이다.
- AC13 보고서 `2026-10-09-skill-only-surface-qg-handoff.md` 가 커밋된다.
- AC14 메모리의 옛 호출 이름 줄(`/interview @…` 언급 항목)이 갱신된다.

## Files to Modify

- 새: `shared/entry/entry_preflight.py` · `shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh` · 세 플러그인 `scripts/entry_preflight.py`(링크) · `plugins/project-init/skills/project-init/SKILL.md` · 필요 시 `plugins/plugin-audit/scripts/kill_switch_active.py`(copy-of) · 보고서.
- 개명(`git mv`): spec-distill `skills/{framing-requests,conducting-interview,reviewing-spec}` · plugin-audit `skills/auditing-plugins`.
- 삭제: `plugins/spec-distill/commands/{interview,request-framing}.md` · `plugins/plugin-audit/commands/plugin-audit.md` · `plugins/project-init/commands/project-init.md`.
- 수정 — 진입 skill 다섯의 SKILL.md(머리 · 진입 단계 · 완전명 안내) · `conducting-interview/references/finishing.md` 등 핸드오프 문구 자리 · `plugins/spec-distill/references/trivia-escape.md`(`<command>` 설명).
- 수정 — 테스트: spec-distill `test_conducting_interview_internal.sh` · `test_conducting_interview_stage.sh` · `test_request_framing_command.sh` · `test_seed_at_path_handoff.sh` · `test_seed_input_provenance.sh` 와 skill 경로를 핀한 그 밖의 spec-distill 테스트, project-init `test_command_contract.py`, plugin-audit `test_check_staleness.py` 와 fixture 셋 · `scripts/check-staleness.py`, shared `test_copy_of_contract.sh` · `test_docreview_advice_procedure.sh` · `test_docreview_procedure_paths.sh` · `test_docreview_round_gate_split.sh` · `test_variant_of_contract.sh`, qg `test_codex_gate_observation.sh`(B6).
- 수정 — 문서 · 메타: `CLAUDE.md` · `docs/plugin-authoring.md` · `docs/philosophy/devbrew-harness-philosophy.md` · 세 플러그인 README · plugin.json(넷) · CHANGELOG(넷) · 미실행 seed 의 핸드오프 줄.

정확한 파일 목록은 writing-plans 가 락 I 의 실행 결과로 확정한다.

## Verification Plan

1. 착수 전 baseline: 전체 셸 · python 테스트를 리포 루트에서 돌려 파일별 rc 와 실패 줄 수를 기록한다(qg 선재 RED 포함).
2. 개명 · 삭제 커밋마다 그 경로를 핀한 테스트를 같은 커밋에서 고치고 `# guards:` 커버리지 락을 돌린다.
3. 락: 레포 GREEN · 변이 RED(축별 사유) · 양성 대조 GREEN.
4. 실측 M1~M6 (§7).
5. 종료: baseline 대조 — 새 RED 0, 실패 줄 수 증가 0. `git diff main --stat -- plugins/quality-gates` 가 AC10 범위 안인지 확인한다.

## Rejected Alternatives

- **도메인-동사 전부 재명명**(`/spec-frame` 등): 규칙은 깔끔하지만 익숙한 `/request-framing` 까지 바뀐다.
- **디렉토리 유지, `name` 만 짧게**: 디렉토리와 이름이 어긋나 C7 을 재생산하고, «`name` 우선» 동작을 실측해야 한다.
- **«다른 skill 이 부르는 것만 모델 허용» 도출 규칙**: 락이 도출로 잴 수 있지만 말로 시켜도 돌지 않는다. 사용자는 비용 · 부작용 큰 둘만 막기로 했다(B5).
- **플러그인별 독립 사전 검사 스크립트**: kill switch 열두 벌 drift 를 재생산한다.
- **산문만으로 사전 단계**(`!` 없음): 모델이 건너뛰어도 소리가 안 난다(B2).
- **trivia 를 진입 다섯 모두에**: 인자가 경로이거나 없는 셋에서는 판정이 늘 «아님»인 의례다.
- **qg RED 를 보고로 남김**: 알려진 RED 가 풍경이 되고 v10 과 충돌한다.
- **레포 전체 스위프**: 지난 결정문의 당시 맥락을 고쳐 쓴다.
- **plugin-audit 0.11.0**: 세 플러그인의 bump 규칙이 갈린다.
- **deprecation alias**: C9 · D3 로 금지.

## 알려진 한계

- 감시줄은 사용자가 인자에 같은 문자열을 넣어 위조할 수 있다. kill switch 의 주체가 같은 사용자라 권한이 넘어가지 않으므로 받아들인다. 파일 내용 주입은 1단계 뒤에 읽히므로 닿지 않는다.
- 스크립트 부재 · python3 부재는 rc≠0 으로 끊기고 헤드리스에서 조용하다. README 공시로만 다룬다.
- 락 G 는 slash 모양의 안내만 본다. «인터뷰 명령을 치세요» 같은 산문 안내는 못 잡는다.
- 락 E 의 키 목록은 문서 확인 시점의 사본이다. 플랫폼이 키를 추가하면 거짓 RED 가 나고, 목록 갱신이 필요하다.
- bare 이름 해석은 Claude Code 버전과 설치된 다른 플러그인에 따라 달라질 수 있다. M2 는 그 시점 한 번의 사실이다.
- README(사람용 문서)는 짧은 이름을 쓴다. 락 G 의 기계 코퍼스 밖이다.

## 결정 기록

| id | 결정 | 근거 |
|---|---|---|
| B1 | OQ19 · OQ20: C4 우선 — 이 작업이 규칙과 CLAUDE.md 조항을 소유하고, v10 은 보고서로 따른다. qg 파일은 고치지 않는다 | 사용자 선택 |
| B2 | OQ10 · OQ23: 인자 없는 `!` 사전 검사 + 감시줄, 사용자 인자는 산문 + 모델 도구 | 사용자 선택. `$ARGUMENTS` 의 셸 인용은 문서에 없다 |
| B3 | OQ12: 익숙한 이름 유지 + 일반어만 교체(§1) | 사용자 선택 |
| B4 | OQ11: 내부 skill 은 숨김 + 동명사 + 락으로 경계 | 사용자 선택 |
| B5 | 모델 호출: 비용 · 부작용 큰 둘(project-init · plugin-audit)만 사용자 전용 | 사용자 선택(권장안은 도출 규칙이었다) |
| B6 | **C3 재결정**: 디렉토리 개명이 직접 깨뜨리는 qg 테스트 라벨 줄 하나는 고친다 | `test_codex_gate_observation.sh:199` 가 디렉토리 이름을 라벨로 쓰고 `:315` 가 열거한다. 보고 후 사용자 동의 |
| B7 | OQ15: 살아 있는 표면 + 미실행 seed 만 스위프 | 사용자 선택 |
| B8 | OQ22: plugin-audit 1.0.0 | 사용자 선택 |
| B9 | OQ13: trivia 는 spec 입구 둘의 인자 단계, `@` 푼 뒤, seed 면 건너뜀 | 사용자 선택 |
| B10 | OQ24 · OQ9: M1~M3(+M5 · M6) 머지 게이트, M4 는 사용자 대화형 한 번 | 사용자 선택 |
| B11 | OQ17 · OQ21: qg 보고는 규칙 위반 전부 + v10 대조 칸 | 사용자 선택 |
| B12 | 사전 검사는 공유 정본 + 플러그인별 심볼릭 링크 | 사용자 승인. 기존 배포 방식과 copy-of 락 재사용 |
| — | OQ14 · OQ16 · OQ18: §5 문면 · README 순서 무강제 · 조건형 qg 면제 | 설계 절 승인 |

## Metadata

- 작성일: 2026-10-09
- 브랜치: `feature/unify-command-surface`
- 입력: brief 67824eff
- 영향 플러그인: spec-distill · plugin-audit · project-init · quality-gates(B6 한 줄)
- 다음 단계: `spec-distill:reviewing-spec`(이 문서) → 승인 게이트 «진행» → superpowers:writing-plans
