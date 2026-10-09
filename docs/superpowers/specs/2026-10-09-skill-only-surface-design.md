# skill-only 호출 표면 · Design

> 부르는 모양이 하나이고, 그 모양으로 부르면 늘 같은 것이 돈다.

devbrew 의 사용자 호출 표면(slash 명령 · slash skill · kill switch · 핸드오프 문구)을 «기능당 사용자 진입 skill 하나» 체계로 통일하고 이 브랜치(`feature/unify-command-surface`)에서 구현한다.

## Handoff Context

- 입력 brief: `docs/superpowers/interview/2026-10-08-skill-only-surface-interview.md` (확정 17항목, 커밋 67824eff)
- brief audit: `docs/superpowers/interview/2026-10-08-skill-only-surface-interview.audit.md` (RC1~RC28 · §6 S1~S9)
- brainstorming 결정: 이 문서 `## 결정 기록` B1~B13
- 재결정 규약: confirmed 항목은 근거가 있으면 보고 후 재결정할 수 있고, 임의 변경은 금지다. 이 문서의 재결정은 B6(C3 예외)과 B13(D3 범위) 둘이다.

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

- quality-gates 파일 수정. 예외는 B6 이고, 그 범위는 정확히 넷이다(D2.3): ① `plugins/quality-gates/tests/test_codex_gate_observation.sh:315` 의 라벨 `case` 줄 ② 그 줄의 주석 ③ CLAUDE.md bump 규칙이 강제하는 qg `plugin.json` patch bump ④ qg `CHANGELOG.md` 의 그 한 항목. 이 문서에서 «B6 한 줄»은 이 넷을 가리킨다. ③ · ④ 는 v10 브랜치도 고치는 파일이라 머지 때 겹친다 — 번호와 항목은 나중에 머지하는 쪽이 해소한다.
- kill switch 이름 변경.
- deprecation alias · fallback 명령.
- qg v10 설계 대체. 이 작업은 규칙을 정하고 v10 은 그 규칙을 따른다(C4).
- 쉬운 말 출력 문구 작업.
- 지난 기록(docs/archive · 지난 spec/plan/brief · CHANGELOG 과거 항목)의 옛 이름 교체.

## Constraints

brief §2 의 C1~C11 · D1~D6 을 그대로 따른다. 이 설계에 직접 닿는 것:

- C3 qg 파일은 고치지 않고 보고만 한다. **B6 예외**: 디렉토리 개명이 직접 깨뜨리는 `plugins/quality-gates/tests/test_codex_gate_observation.sh` 의 라벨 `case` 줄과 그 주석, 그리고 bump 규칙이 강제하는 qg `plugin.json` · `CHANGELOG.md` 한 항목만 고친다(Non-goals 의 넷).
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
- `reviewing-spec` → `spec-review` 는 brief D3 의 범위(qg 밖 명령 4개) 밖이다 — **B13 재결정**(D3 범위에 user-invocable skill 이름 하나를 더함, 근거 D5 · 축 A, 사용자 동의)으로 개명한다. 이 개명으로 C3 아래에서 고칠 수 없는 qg 인용(`quality-pipeline/SKILL.md:394` · `critiquing-artifacts/SKILL.md:154` · `scripts/run_codex_reviewer.sh:49`, 그리고 B6 라벨 줄 밖의 `test_codex_gate_observation.sh:70` 주석)이 옛 이름으로 남고, 락 `--report` 를 거쳐 §6 보고서에 행으로 실린다.

### §2 구성요소와 파일

| 단위 | 책임 | 의존 |
|---|---|---|
| `shared/entry/entry_preflight.py` (정본) | 상수 인자 `<plugin> <skill>` 를 받아 플러그인 kill switch(`DEVBREW_<PLUGIN>_DISABLE`)를 판정하고, 루트를 도출해 감시줄 한 줄을 출력한다(아래 «검사 항목»). 내부 실패는 전부 잡아 rc 0 + `error` 줄로 바꾼다. | 표준 라이브러리만 — **import 하는 형제 모듈 없음** |
| `plugins/{spec-distill,plugin-audit,project-init}/scripts/entry_preflight.py` | 정본을 가리키는 심볼릭 링크 | 위 |
| 진입 skill 공통 머리 | `!` 줄 하나 · `allowed-tools` 사전 허용 한 항목 · `argument-hint` · `## 진입 단계` 절 | 위 |
| `shared/entry/check_invocation_surface.py` + `shared/tests/test_invocation_surface.sh` | §4 락. `--report` 모드는 qg 위반 표를 낸다 | `git ls-files` |
| `plugins/project-init/skills/project-init/SKILL.md` | 명령 본문을 옮긴 진입 skill, `cost_class: low`(agent · codex · 웹 없음 — 지출 게이트 없음) | 위 머리 |

**import 하지 않는 이유** — 심볼릭 링크로 실행된 스크립트의 `sys.path[0]` 는 링크를 푼 정본 디렉토리(`shared/entry/`)다. 형제 import 는 리포 트리와 `--plugin-dir` 로드에서 정본 옆을 찾으므로 `kill_switch_active` 가 풀리지 않는다(`shared/tests/test_copy_of_contract.sh:723-726` 실측). 또 플러그인 단위만 보는 함수를 정본 `kill_switch_active.py` 에 더하면 qg 의 copy-of 사본까지 바이트를 맞춰야 해서 C3 와 충돌한다. 그래서 `entry_preflight` 는 `DEVBREW_<PLUGIN>_DISABLE` 한 변수만 정본과 **같은 도출 규칙**(`-` → `_`, 대문자화, 값이 정확히 `1`)으로 직접 읽는다. 두 도출의 일치는 락 테스트가 플러그인 셋에 대해 `kill_switch_active(p, "_")` 의 DISABLE 판정과 대조해 잰다.

**검사 항목** (전부 인자 없음 · 사용자 입력 없음):
1. `DEVBREW_<PLUGIN>_DISABLE == "1"` → `disabled` 줄.
2. 루트: cwd 에서 `git rev-parse --show-toplevel`. 실패하면(비-git 디렉토리 · git 부재) cwd 를 쓰고 감시줄에 `root_source=cwd` 를 붙인다 — `ok` 다. `/project-init` 은 git 이 아직 없는 디렉토리에서 돈다.
3. 그 밖의 예외 → `error` 줄.

검증 항목(이 절의 몫): 리포 경로 실행 `python3 plugins/<p>/scripts/entry_preflight.py <p> <s>` 가 플러그인 셋 모두에서 `ok` 를 낸다 · 비-git 임시 디렉토리에서 `ok … root_source=cwd` · `DEVBREW_<P>_DISABLE=1` 에서 `disabled`. `shared/README.md` 디렉토리 표에 `entry/` 를 추가한다.

감시줄 형식(한 줄, 고정 접두):

```
[devbrew-entry] ok plugin=<p> skill=<s> root=<절대경로> [root_source=cwd]
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
| 감시줄 없음 · 그 밖 | «사전 검사 결과 없음 — 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다»를 보고하고 멈춘다 |

- rc≠0 이면 플랫폼이 호출 전체를 끊고, 헤드리스에서는 그것이 0턴 rc=0 조용한 실패가 된다. 그래서 스크립트는 자기 실패를 rc 0 + `error` 줄로 바꾼다.
- 남는 rc≠0 경로는 «스크립트 부재 · python3 부재» 둘이다. 이 경로는 fail-closed 로 끊긴다. 세 README 에 공시한다.
- 플러그인 전체 kill switch 를 본문 산문으로 다시 확인하던 자리(`conducting-interview` · `framing-requests` 의 `DEVBREW_SPEC_DISTILL_DISABLE` 산문)는 1단계로 대체한다. skill 고유 스위치(`review_entry.py` 의 셋 · 은퇴 스위치 공시)는 1.5 에 그대로 남는다.
- **1단계의 스위치 판정은 `DEVBREW_<PLUGIN>_DISABLE=1` 하나뿐이다**(D1.1). `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다 — `<plugin>:<skill>` 같은 새 토큰을 만들지 않는다. 이 사실을 세 README 의 kill switch 절에 적는다.
- **의미 확장 공시** — `DEVBREW_<PLUGIN>_DISABLE` 은 CLAUDE.md 정의대로 «그 플러그인 전체»를 끈다. 그래서 지금까지 훅만 끄던 `DEVBREW_PROJECT_INIT_DISABLE` 은 앞으로 `/project-init` 진입도 `disabled` no-op 으로 만든다(plugin-audit · spec-distill 은 이미 진입을 끄던 스위치다). project-init CHANGELOG 의 `Changed` 와 README 에 이 확장을 공시한다.

**2. `@경로` 풀기** — 산문 규칙과 Read 도구로 한다.
- 인자가 `@` 로 시작하는 공백 없는 한 토큰일 때만 발동한다.
- `@` 를 뗀다. 상대경로는 감시줄 `root=` 기준으로 푼다. 절대경로인데 존재하지 않으면 `root=` 기준 상대경로로 한 번 더 시도한다.
- 실패하면 시도한 절대경로와 관측 사유를 담아 멈춘다. 인터뷰·프레이밍을 시작하지 않는다.
- M4 결과로 규칙을 확정한다. 이 규칙은 `/interview` Step 1.5 의 seed audit 경로 한 줄 출력을 그대로 잇는다.
- `@` 로 시작하는데 공백이 섞였으면 풀지 않고 공백을 알리고 멈춘다.
- 성공하면 Read 원문 전체(frontmatter 포함)가 «풀린 입력»이다. 발동하지 않으면 «풀린 입력» = skill 이 받은 인자 그대로.
- 3단계 trivia · seed 인식 · S1 · 본 절차는 «풀린 입력»을 읽는다.
- `/interview` Step 2.5 조언은 `spec-interview` 진입 단계 3.5 로 잇는다(완전명 `/spec-distill:request-framing`).
- `@` 단계는 `spec-interview` · `request-framing` 에 둔다. `spec-review` 는 경로 앞의 `@` 하나만 뗀다. plugin-audit · project-init 에는 없다.

**3. trivia** — `references/trivia-escape.md` 다섯 패턴. 안내의 `<command>` 는 완전명(`spec-distill:spec-interview` · `spec-distill:request-framing`)으로 채운다. `force` 탈출구는 유지한다.

**인자 경계** — `$ARGUMENTS` · 위치 인자는 산문 자리에만 둔다. `!` 줄과 ```` ```! ```` 블록 안에는 두지 않는다(락 D).

**핸드오프** — `framing-requests` 의 «호출 모양» 정본(883행 부근)과 `finishing.md` 등 기계가 내는 안내는 완전명으로 바꾼다.

### §4 락 — 표면 정합

대상은 `git ls-files` 에서 도출한다. qg 파일(`plugins/quality-gates/**`)은 **보고 모드**로 돌린다 — 위반을 RED 로 막지 않고 표로 내며, 그 표가 §6 보고서의 원천이다. **보고 모드의 수명은 모든 축(A~I)에 한 조건으로 걸린다**: `plugins/quality-gates/commands/` 가 있는 동안 유지되고, 그 디렉토리가 사라지면 모든 축에서 qg 파일도 RED 판정으로 바뀐다. 보고 표와 RED 메시지가 그 수명을 함께 적는다.

| 축 | 대상 (도출) | 판정 |
|---|---|---|
| A 이름 | `user-invocable: false` 가 아닌 skill = 진입 skill | `name` = 디렉토리, kebab 두 단어 이상, 첫 단어가 `-ing` 형이 아님 |
| B 내부 | `user-invocable: false` skill | 첫 단어가 `-ing` 형(동명사) |
| C 머리 | 진입 skill | `!` 줄 정확히 하나, 인자 = 자기 `<plugin> <name>`, `allowed-tools` 가 그 한 항목만, `## 진입 단계` 절 존재 |
| D 인자 경계 | 모든 SKILL.md · references 의 `!` 줄과 ```` ```! ```` 블록 | 사용자 인자 토큰(`$ARGUMENTS` · `${ARGUMENTS}` · `$0`~`$9` · `$[0-9]`) 0개 |
| E 키 | 모든 SKILL.md frontmatter | 공식 키 집합 ∪ {`cost_class`} 안에서만 (판정 출처는 아래 «축 E 와 `validate --strict`») |
| F 모델 호출 | `disable-model-invocation: true` 인 진입 skill | 집합이 **정확히** {plugin-audit, project-init} |
| G 안내 | 기계 코퍼스(`plugins/*/{skills,hooks,scripts,templates,references,agents}/**`) | `/p:x` 는 실재하는 사용자 호출 가능 skill 로 풀린다. 진입 skill 짧은 이름의 bare `/x` 는 RED |
| H 명령 층 | `plugins/*/commands/` | qg 밖 0개. qg 는 `plugins/quality-gates/commands/` 가 있는 동안 보고 모드 |
| I 옛 이름 | 살아 있는 표면(아래) | 옛 이름 0개 + **양성 짝**: 새 이름 다섯이 각 자기 자리에 실재 |

- 살아 있는 표면: `plugins/**` · `shared/**` · `CLAUDE.md` · `README.md` · `docs/philosophy/**` · `docs/plugin-authoring.md`. 제외는 `**/CHANGELOG.md` · `*/tests/fixtures/**`(기록된 데이터) · 락 자신의 두 파일(`shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh`) 넷뿐이다. 그 밖에 옛 이름 리터럴을 담아야 하는 테스트는 리터럴을 조각으로 잇는다.
- 옛 이름 집합: 호출 토큰 `/interview` · `conducting-interview` · `framing-requests` · `reviewing-spec` · `auditing-plugins` · `commands/(interview|request-framing|plugin-audit|project-init).md`.
- **호출 토큰의 경계**(축 G 의 `/x` · `/p:x` 와 축 I 의 `/interview` 에 공통): 앞은 줄 시작 · 공백 · 백틱 · 따옴표 · 여는 괄호 · `「` 중 하나이고, 뒤는 공백 · 백틱 · 따옴표 · `@` · 닫는 괄호 · `」` · 줄 끝 중 하나다. 앞이 단어 문자나 `/` · `.` 이거나 뒤가 `/` 면 경로 조각이라 호출 토큰이 아니다 — `docs/superpowers/interview/` · `plugins/plugin-audit/…` · `skills/spec-review/` 는 GREEN 이다.
- RED 메시지는 자기 범위를 밝힌다. 예: «qg 는 `plugins/quality-gates/commands/` 가 있는 동안 보고만 된다».

**축 E 와 `validate --strict`** — brief §4 는 manifest 검증을 공식 검사기 `claude plugin validate --strict` 에 맡기는 쪽을 [취함]으로 골랐다. 그래서 plugin.json(manifest) 검증은 락이 다시 하지 않고 `validate --strict` 실행 하나를 락의 한 단계로 둔다. skill frontmatter 미지 키는 순서대로 정한다: ① 구현 첫 단계에서 미지 키(`bogus_key: 1`)를 심은 SKILL.md 로 `validate --strict` 가 그 키를 잡는지 실측한다. ② 잡으면 축 E 는 그 실행 결과로 판정하고 손 목록을 두지 않는다. ③ 못 잡으면 공식 문서의 키 목록 ∪ {`cost_class`} 를 테스트에 두고 목록 출처와 확인 날짜를 주석에 적는다 — 손 목록은 플랫폼이 키를 더하면 거짓 RED 를 내는 대가가 있다(«알려진 한계»). 실측 결과는 §7 표에 E0 로 기록한다. E0 실측(2026-10-09, CLI 2.1.294): 잡지 않는다 → ③ 손 목록. manifest 단계는 error 를 모두 RED 로 한다. warning 은 hooks 의 `${CLAUDE_PLUGIN_ROOT}` 따옴표 경고 한 종류만 면제하고, 그 면제는 보고서 3부 행이 된다.

**이빨** — 테스트가 임시 복사본(`git clone --no-local`)에 축마다 변이를 심고, RED 와 그 축의 사유 문자열을 함께 확인한다. 변이는 삭제 · 추가 · 반전 · 표기 변형 네 종류다(예: `!` 줄 삭제 · 둘로 복제 · 인자 바꿔치기 · `$ARGUMENTS`→`${ARGUMENTS}` · `disable-model-invocation` 를 spec-review 에 추가 · plugin-audit 에서 제거 · 옛 이름 재삽입 · 새 skill 디렉토리 삭제). 같은 복사본의 무변이 실행 GREEN 이 양성 대조다. **음성 대조**도 둔다 — 경로 조각(`docs/superpowers/interview/x.md` · `plugins/plugin-audit/README.md`)을 심어도 GREEN 이어야 한다. `PYTHONDONTWRITEBYTECODE=1` 로 돌린다.

### §5 CLAUDE.md 개정문

네 자리. 굵은 글씨가 새 문면이다.

1. 메타데이터(36행): «제거 전 one-minor deprecation window. **예외 — 호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다. 이 예외는 제3자 설치가 확인되면(외부 이슈 · 설치 보고 · 마켓플레이스 공개 등록) 소멸한다. kill switch 이름은 이 예외에 들지 않는다 — 은퇴시키려면 CHANGELOG `Removed` 와 README 에 공시가 필수다.**»
2. `allowed-tools`(42행): «**`allowed-tools` 는 제한이 아니다**(2026-08-22 실측 유지). **command 에서는 쓰지 않는다. skill 에서는 진입 `!` 사전 검사 한 줄의 사전 허용으로만 쓰고 다른 도구를 열거하지 않는다.**» 실측 기록 문장은 남긴다.
3. 네이밍(70행): «**사용자가 부르는 진입 skill 은 짧은 kebab 두 단어 이상(일반어 단독 금지 — `spec-review`, `plugin-audit`)이고 디렉토리 이름 = `name` 이다. 모델만 부르는 내부 skill(`user-invocable: false`)은 동명사(`reviewing-brief`). 기계가 내는 안내는 `/plugin:name` 완전명. 새 `commands/` 는 만들지 않는다 — 사전 단계는 진입 skill 의 `!` 로. 집행: `shared/tests/test_invocation_surface.sh`.**»
4. Polite handoff(87행): `reviewing-spec` → `spec-review`, `conducting-interview` → `spec-interview`.

같이 고치는 곳:
- `docs/plugin-authoring.md` — 13행 canonical 트리의 `commands/` 줄 제거 · 14행 `skills/<gerund-name>/ … (동명사)` 를 `skills/<name>/  # 진입 skill 은 짧은 kebab(spec-review), 내부 skill(user-invocable: false)은 동명사(reviewing-brief)` 로 · 31행 project-init 설명(「`commands/` … `skills/` 없음」)을 skill 하나를 가진 모양으로.
- `docs/philosophy/devbrew-harness-philosophy.md` — 옛 이름 참조 4곳(23 · 44 · 52 · 68행).

### §6 버전 · CHANGELOG · 보고서

- 자리: spec-distill major · project-init major · plugin-audit major(1.0.0) · quality-gates patch(B6). 번호 문자열은 머지 직전에 base 를 보고 확정한다.
- CHANGELOG 셋의 `Removed` 에 옛 이름 → 새 완전명 대응표를 싣는다. plugin-audit 은 기존 CHANGELOG 에 1.0.0 절을 추가한다.
- 보고서 `docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md` 는 세 부분으로 이루어진다.
  1. «v10 이 따를 변경»: 진입은 `!` 를 가진 skill, CLAUDE.md §5 문안 인용, B6 라벨 줄.
  2. 락 `--report` 가 낸 qg 위반 전부. 행마다 «v10 설계가 다룸(행 번호) / 언급 없음» 칸을 붙인다.
  3. «락 밖 qg 위반»(RC4 · RC5 · RC6 · RC8 · RC10 · RC18 + manifest 면제 행).
- 대조 기준: v10 설계 `docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md` @ `5eccf37c82ee6f000baefb0e8e972733ba07eb38`(브랜치 `feature/qg-v10-cleanup`).
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

#### 결과 (2026-10-09, Claude Code 2.1.294)

격리 설치본(haiku · `--permission-mode default` · `--max-turns 4`)에서 f4cb54be 이후 HEAD 의 캐시 복사본으로 쟀다.

| # | 결과 | 관측 |
|---|---|---|
| M1 | **실패** | 브리프 그대로(Skill 도구 승인 없음)는 헤드리스에서 `permission_denied`(tool=Skill, source=config)로 거부돼 주입 본문이 없다. 참고 변형 `--allowedTools Skill`: 주입 본문에 `[devbrew-entry] ok plugin=spec-distill skill=spec-review root=…` 가 있다(`!` 는 모델 호출에서도 돈다). 그러나 이어지는 1.5 의 다줄 Bash 가 승인 없이 막혀(`Contains brace with quote character`) `review-entry: DISABLED` 로 멈추지 못하고 4턴을 소진했다. 두 번째 통과 조건이 불성립 |
| M2 | 통과 9/10 + 재시도 | 열 칸 중 아홉이 첫 시도에 RESULT 에 `[devbrew-entry] disabled plugin=<p> skill=<s>` 를 냈다. spec-review bare(`/spec-review x`)는 첫 시도에 감시줄이 없었고(1.5 Bash 승인 요청으로 흘렀다) 같은 명령 재시도 2회는 모두 `disabled` 줄을 냈다 — 비결정적. `Unknown command` 0 |
| M3 | 통과 | 모델 쪽: `Skill plugin-audit:plugin-audit cannot be used with Skill tool due to disable-model-invocation`. 주입 본문 `skill=plugin-audit` 없음. 사람 쪽은 M2 plugin-audit 두 행 |
| M5 | 통과 | `disableSkillShellExecution: true`(기존 settings.json 에 병합) 하 RESULT 에 `spec-review 사전 검사 불가(정책)` 가 있고 리뷰는 시작되지 않았다 |
| M6 | 통과 | RESULT 가 `[devbrew-entry] disabled plugin=spec-distill skill=spec-interview switch=DEVBREW_SPEC_DISTILL_DISABLE=1` 한 줄. `.claude/spec-distill/` 생성 없음 |
| E0 | 통과 | 위 축 E 문단의 기존 실측(CLI 2.1.294)을 따른다. 이번 단계에서 재측정하지 않았다 |
| M4 | 대기 — 사용자 대화형 | 결과가 오면 §3-2 최종 규칙을 여기에 한 줄로 확정한다 |

실측 중 M5 를 브리프 문구대로 `settings.json` 을 통째로 덮어쓰자 `enabledPlugins` 가 지워져 M5·M6 첫 시도가 «플러그인 미설치»로 무효였다. 병합 방식으로 다시 쟀다.

## Acceptance Criteria

- AC1 `plugins/*/commands/` 는 quality-gates 에만 있다.
- AC2 §1 의 진입 skill 다섯이 그 디렉토리 · `name` 으로 실재하고, `reviewing-brief` 는 `user-invocable: false` 다.
- AC3 진입 skill 다섯이 §2 공통 머리와 §3 진입 단계를 갖는다. `spec-review` 는 1.5 에 기존 `review_entry` 펜스를 유지한다.
- AC4 `disable-model-invocation: true` 인 진입 skill 집합이 정확히 {plugin-audit, project-init} 이다.
- AC5 `entry_preflight.py` 는 정본 하나이고 세 플러그인에 심볼릭 링크로 실린다. `test_copy_of_contract.sh` 가 GREEN 이다.
- AC6 `test_invocation_surface.sh` 가 레포에서 GREEN 이고, 축 A~I 의 변이가 전부 RED 와 그 축의 사유를 낸다. 양성 대조는 GREEN 이다.
- AC7 qg 밖 살아 있는 표면에서 옛 이름이 0건이다(락 I). qg 안의 잔여는 락 `--report` 표를 거쳐 §6 보고서에 행으로 실린다. 미실행 seed(판별 규칙은 plan P10)의 핸드오프 줄도 완전명이다 — 2026-10-09 실측 0줄.
- AC8 CLAUDE.md 네 자리가 §5 문면대로 개정되고 `docs/plugin-authoring.md` · 철학 문서 참조가 갱신된다.
- AC9 세 플러그인과 qg 의 plugin.json 이 §6 자리대로 bump 되고, CHANGELOG 셋에 대응표가 있다.
- AC10 qg 에서 바뀐 것은 `test_codex_gate_observation.sh` 의 라벨 `case` 줄과 그 주석, 그리고 plugin.json · CHANGELOG 뿐이다.
- AC11 M1 · M2 · M3 · M5 · M6 이 통과하고 §7 에 기록된다. M4 결과와 §3-2 최종 규칙이 기록된다.
- AC12 전체 스위트가 baseline 대비 새 RED 0 · 실패 줄 수 증가 0 이다.
- AC13 보고서 `2026-10-09-skill-only-surface-qg-handoff.md` 가 커밋된다.
- AC14 메모리의 옛 호출 이름 줄(`/interview @…` 언급 항목)이 갱신된다.

## Files to Modify

- 새: `shared/entry/entry_preflight.py` · `shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh` · 세 플러그인 `scripts/entry_preflight.py`(링크) · `plugins/project-init/skills/project-init/SKILL.md` · 보고서.
- 개명(`git mv`): spec-distill `skills/{framing-requests,conducting-interview,reviewing-spec}` · plugin-audit `skills/auditing-plugins`.
- 삭제: `plugins/spec-distill/commands/{interview,request-framing}.md` · `plugins/plugin-audit/commands/plugin-audit.md` · `plugins/project-init/commands/project-init.md`.
- 수정 — 진입 skill 다섯의 SKILL.md(머리 · 진입 단계 · 완전명 안내) · `conducting-interview/references/finishing.md` 등 핸드오프 문구 자리 · `plugins/spec-distill/references/trivia-escape.md`(`<command>` 설명) · `conducting-interview/references/seed-input.md` · `finishing.md` 의 «풀린 입력» 치환 · `plugins/plugin-audit/scripts/check-staleness.py` 규칙 (a) · 템플릿 셋(`interview-seed-audit-template.md` · `project/charter.md` · `project/conventions.md`).
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
- **qg 위반을 RED 로 판정하고 그 RED 를 보고로 갈음함**(디렉토리를 개명하되 qg 테스트 RED 를 main 에 남김): 알려진 RED 가 풍경이 되고 v10 과 충돌한다. 채택안은 B6 한 줄 수정 + 락의 qg 보고 모드다.
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
| B6 | **C3 재결정**: 디렉토리 개명이 직접 깨뜨리는 qg 테스트 라벨 줄 하나는 고친다. 범위는 라벨 줄 · 그 주석 · bump 규칙이 강제하는 qg plugin.json patch bump · CHANGELOG 한 항목 넷이다(r2 D2.3) | `test_codex_gate_observation.sh:199` 가 디렉토리 이름을 라벨로 쓰고 `:315` 가 열거한다. 보고 후 사용자 동의, 넷 열거는 리뷰 r2 에서 동의 |
| B7 | OQ15: 살아 있는 표면 + 미실행 seed 만 스위프 | 사용자 선택 |
| B8 | OQ22: plugin-audit 1.0.0 | 사용자 선택 |
| B9 | OQ13: trivia 는 spec 입구 둘의 인자 단계, `@` 푼 뒤, seed 면 건너뜀 | 사용자 선택 |
| B10 | OQ24 · OQ9: M1~M3(+M5 · M6) 머지 게이트, M4 는 사용자 대화형 한 번 | 사용자 선택 |
| B11 | OQ17 · OQ21: qg 보고는 규칙 위반 전부 + v10 대조 칸 | 사용자 선택 |
| B12 | 사전 검사는 공유 정본 + 플러그인별 심볼릭 링크 | 사용자 승인. 기존 배포 방식과 copy-of 락 재사용 |
| — | OQ14 · OQ16 · OQ18: §5 문면 · README 순서 무강제 · 조건형 qg 면제 | 설계 절 승인 |
| B13 | **D3 범위 재결정**: qg 밖 명령 4개에 user-invocable skill 이름 하나(`reviewing-spec` → `spec-review`)를 더한다 | 근거 D5 · 축 A(진입 skill 은 동명사 금지). 리뷰 r1 결정 D1.2 에서 사용자 동의. 대가: qg 안 옛 이름 인용 4곳이 보고서 행으로 남는다(§1) |

- D1.1 · r1 · adopt · c67614cd#r1.1 · "채택 — DISABLE 만, 확장 공시 (권장)" — 1단계의 플러그인 kill switch 판정이 기존 스위치 두 개의 의미를 조용히 넓힌다. `DEVBREW_PROJECT_INIT_DISABLE` 은 지금 훅만 끄는데 앞으로 `/project-init` 명령도 막게 된다. 또 `kill_switch_active(plugin, skill)` 를 재사용하면 `DEVBREW_SKIP_HOOKS=<p>:<skill>` 이라는 문서화되지 않은 토큰이 새로 생긴다.
- D1.2 · r1 · adopt · fe1840a5#r1.1 · "채택 — B13 재결정으로 기록 (권장)" — reviewing-spec → spec-review 개명은 D3 가 정한 범위(qg 밖 명령 4개)를 넘는 다섯째 이름 제거다. 그런데 결정 기록에 재결정으로 남아 있지 않다.
- D2.3 · r2 · adopt · c43e2738#r2.1 · "채택 — 예외를 넷으로 열거 (권장)" — Non-goals 와 B6 는 qg 수정 예외를 「B6 한 줄」로 적었지만, AC10·§6 은 라벨 case 줄과 그 주석에 더해 qg plugin.json patch bump 와 CHANGELOG 까지 고친다. 그래서 C3 예외에 대해 사용자가 동의한 기록이 실제로 고치는 범위보다 좁다.
- D2.4 · r2 · adopt · e3ff3375#r2.1 · "채택 — 현재 변경 유지 (권장)" — finding 없이 바뀜: Handoff Context (modified)
- D3.5 · r3 · adopt · 8e81e781#r3.1 · "채택 — Constraints 변경 유지 (권장)" — finding 없이 바뀜: Constraints (modified)
- docreview 계수 — 66d456cd-0cd7-4277-8466-2811dc3a60f9/2026-10-09-skill-only-surface-design-e85e086e33ade8d5 r1: advice_new=1 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — 66d456cd-0cd7-4277-8466-2811dc3a60f9/2026-10-09-skill-only-surface-design-e85e086e33ade8d5 r2: advice_new=7 · advice_repeat=2 · mc_preexisting_new=1
- docreview 계수 — 66d456cd-0cd7-4277-8466-2811dc3a60f9/2026-10-09-skill-only-surface-design-e85e086e33ade8d5 r3: advice_new=2 · advice_repeat=6 · mc_preexisting_new=0

## Metadata

- 작성일: 2026-10-09
- 브랜치: `feature/unify-command-surface`
- 입력: brief 67824eff
- 영향 플러그인: spec-distill · plugin-audit · project-init · quality-gates(B6 한 줄)
- 다음 단계: `spec-distill:reviewing-spec`(이 문서) → 승인 게이트 «진행» → superpowers:writing-plans

### Deferred to plan

10건 전부 `docs/superpowers/plans/2026-10-09-skill-only-surface.md` 의 «계획 단계 결정» 표가 흡수했다.

| # | 항목 |
|---|---|
| 7b7d0951#r1.1 | 참고(feasibility) #acceptance-criteria — AC7 「살아 있는 표면에서 옛 이름이 0건」은 C3 아래에서 달성할 수 없다. 살아 있는 표면인 `plugins/**` 안의 qg 파일 셋이 `reviewing-spec` 을 담고 있는데, 이것을 고칠 수 없기 때문이다. — 고치면: AC7 을 「qg 밖 살아 있는 표면에서 옛 이름 0건, qg 안의 잔여는 락 `--report` 표를 거쳐 §6 보고서에 행으로 실린다」로 고친다. |
| ad8b5a7f#r2.1 | 참고(data_flow) #6-버전--changelog--보고서 — §6 보고서 2부의 원천은 락 `--report` 하나뿐이다. 그래서 brief OQ17 이 이름 붙인 qg 위반 가운데 락의 어느 축도 보지 않는 것들은 보고서에 들어갈 생산자가 없다. B11 이 정한 「규칙 위반 전부」가 조용히 좁아진다. — 고치면: 보고서에 3부 「락 밖 qg 위반」을 둔다. brief OQ17 과 RC4·RC5·RC6·RC8·RC10·RC18 을 손으로 옮기고, 각 행에 같은 «v10 설계가 다룸 / 언급 없음» 칸을 붙인다. 또는 축 E 의 대상에 `plugins/*/commands/*.md` frontmatter 를 보고 모드로 더해 RC6 을 락이 내게 한다. |
| 98483a2a#r2.1 | 참고(ambiguity) #2-구성요소와-파일 — §2 는 새 `project-init` SKILL.md 에 「`cost_class` 선언」이라고만 하고 값을 정하지 않았다. B5 는 project-init 을 「비용 · 부작용 큰」 쪽으로 분류했는데, CLAUDE.md 는 `high` 이면 `AskUserQuestion` 승인 게이트를 요구한다. 값과 게이트를 둘지를 정한다. |
| f1a3bbc8#r2.1 | 참고(ambiguity) #3-호출-흐름과-오류-처리 — `commands/interview.md` Step 2.5 는 seed 가 아닌 입력에 「💡 `/request-framing` 을 먼저 거치면…」이라는 조언을 낸다(차단은 아니다). §3 의 진입 단계 1~4 는 이 조언을 이어 가는지 버리는지 말하지 않는다. 명령 파일을 지우면 이 조언이 조용히 사라지거나, 구현자마다 다르게 옮긴다. 남길지 여부를 정하고, 남기면 완전명으로 적는다. |
| 94e7636c#r2.1 | 참고(ambiguity) #4-락--표면-정합 — 축 G 의 기계 코퍼스는 `skills/**`·`hooks/**`·`scripts/**` 뿐이고 `plugins/*/templates/**` 와 플러그인 레벨 `references/**` 가 빠져 있다. 그런데 `plugins/spec-distill/templates/interview-seed-audit-template.md:11` 은 `/interview @<seed 경로>` 를 내고, `plugins/project-init/templates/project/charter.md:3`·`conventions.md:3` 은 사용자 프로젝트에 bare `/project-init` 을 심는다. 개명한 뒤에는 이 자리의 bare 진입 이름을 D5(안내는 완전명)대로 잡을 축이 없다. 코퍼스에 넣거나 «알려진 한계»에 제외와 그 이유를 적는다. |
| ce0db444#r2.1 | 참고(handoff_incomplete) #6-버전--changelog--보고서 — 보고서 2부는 행마다 «v10 설계가 다룸(행 번호)» 칸을 요구한다. 그런데 문서 어디에도 대조할 v10 설계의 경로·브랜치·커밋이 없다. brief S1 에만 `feature/qg-review-e2e-publish` 가 있다. `/compact` 뒤에 이 문서만 읽고는 그 칸을 채울 수 없다. v10 설계 파일 경로와 기준 커밋을 적는다. |
| a231cc98#r2.1 | 참고(ambiguity) #files-to-modify — Files to Modify 의 「필요 시 `plugins/plugin-audit/scripts/kill_switch_active.py`(copy-of)」는 r1 이전 설계(entry_preflight 가 kill_switch_active 를 import 하던 안)에서 남은 고아 항목이다. §2 는 「import 하는 형제 모듈 없음」이고 대조 테스트는 shared 정본을 쓴다. plugin-audit 에는 그 사본을 소비할 곳이 없다. 소비자 없는 사본은 `test_copy_of_contract.sh` 머리말 조건 ①이 말하는 fail-open 모양이다. 이 항목을 뺀다. |
| e1b5b3be#r2.1 | 참고(handoff_incomplete) #handoff-context — Handoff Context 는 「brainstorming 결정: 이 문서 `## 결정 기록` B1~B12」라고 적지만 r1 에서 B13 이 더해졌다. 바로 아래 줄도 B13 을 재결정으로 인용한다. 범위를 B1~B13 으로 고친다. |
| e290ddb1#r3.1 | 참고(data_flow) #3-호출-흐름과-오류-처리 — §3-2 `@경로` 풀기가 성공했을 때의 산출물(파일 전문)에 이름이 없고 넘겨받는 쪽도 정해지지 않았다. 지금 seed 인식과 S1 기록은 `$ARGUMENTS` 를 보고 정해지는데, 명령을 없애면 spec-interview 직접 호출의 `$ARGUMENTS` 는 파일 전문이 아니라 `@<경로>` 글자 그대로다. — 고치면: §3-2 에 다음을 적는다: 「성공하면 Read 원문 전체(frontmatter 포함)가 «풀린 입력»이다. 발동하지 않으면 «풀린 입력» = `$ARGUMENTS`. 3단계 trivia · seed 인식 · S1 · 본 절차는 `$ARGUMENTS` 대신 «풀린 입력»을 읽는다」. seed-input.md · finishing.md 의 `$ARGUMENTS` 를 «풀린 입력»으로 바꾸는 일을 Files to Modify 에 올린다. Step 2.5 조언은 진입 단계에 잇거나 폐기한다고 명시한다. |
| 641c4e4c#r3.1 | 참고(placeholder) #files-to-modify — 「필요 시 `plugins/plugin-audit/scripts/kill_switch_active.py`(copy-of)」는 언제 필요한지 조건이 없다. 또 §2 의 「import 하는 형제 모듈 없음」과 모순된다. |
