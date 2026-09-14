---
name: plugin-root-cwd-fallback
type: design
created_at: 2026-09-14
source_interview: 없음 — /brainstorming 직접 진입. 사용자 결정은 「결정 기록」 절이 정본이다
next_phase: superpowers:writing-plans
---

# 플러그인 루트 cwd fallback 제거 — skill 과 reference 가 제 플러그인만 실행한다 · Design

> 치환은 skill 본문에만 온다. 치환이 닿지 않는 곳에서 cwd 로 떨어지던 끝자락을 멈춤으로 바꾼다.

## 목차

- [Handoff Context](#handoff-context) · [Goal](#goal) · [Context / Why](#context--why)
- [Goals](#goals) · [Non-goals](#non-goals) · [Constraints](#constraints)
- [설계](#설계) — [§1 SKILL.md](#1-skillmd--bare-형태로) · [§2 reference](#2-reference--가드와-skillmd-가-건네는-루트) ·
  [§3 락](#3-락) · [§4 문서 · 버전](#4-문서--버전)
- [Acceptance Criteria](#acceptance-criteria) · [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives) · [알려진 한계](#알려진-한계) · [Concrete Next Action](#concrete-next-action)
- [결정 기록](#결정-기록) — [Deferred to plan](#deferred-to-plan)

## Handoff Context

**TL;DR** — skill·reference 마크다운의 `${CLAUDE_PLUGIN_ROOT:-./plugins/<p>}` 형태가 devbrew 밖에서
사용자 cwd 의 `./plugins/<p>` 로 풀려, 그 저장소에 있는 스크립트·프로필을 실행한다. 이 형태를 세 플러그인
(spec-distill · quality-gates · plugin-audit)에서 없앤다. SKILL.md 는 로드 시 치환되는 bare
`${CLAUDE_PLUGIN_ROOT}` 로, 치환이 오지 않는 reference 파일은 「빈 값이면 멈추는 가드」와 SKILL.md 가
건네는 절대 경로로 루트를 얻는다. 규칙은 새 공용 락 하나가 집행하고, 틀린 전제로 `:-` 형태를 강제하던
quality-gates 락은 은퇴한다. 세 플러그인 patch.

**Implicit context** —
(1) 출처: PR #155 후속 코멘트 항목 7(`reviewing-brief` 의 fallback 1→13줄)과, 같은 결함을 #154 가 후속
F2 로 미룬 것. 사용자는 코멘트 목록 중 이 항목을 첫 묶음으로 골랐다(D1).
(2) 작업 위치: 브랜치 `fix/plugin-root-cwd-fallback`, 워크트리 `.claude/worktrees/plugin-root-cwd-fallback`,
base `add4c9cd`(#155 머지).
(3) 이 문서는 인터뷰 없이 쓰였다. design-doc 프로필의 층 1 정답 출처(브리프 §2)가 없으므로 「결정 기록」이
그 자리를 대신한다.
(4) 아래 「실측」 절의 원자료(헤드리스 트랜스크립트)는 세션 scratchpad 에 있어 사라진다 — 판정에 쓴 줄은
그 절에 옮겨 적었다.
(5) plan 이 정할 것은 문서 끝 `### Deferred to plan` 에 모여 있다.

## Goal

어떤 cwd 에서 실행돼도 devbrew skill 은 자기 플러그인의 스크립트·프로필만 실행하고, 루트를 풀지 못하면
cwd 로 가지 않고 멈춘다.

## Context / Why

**결함.** Bash 도구 환경에는 `CLAUDE_PLUGIN_ROOT` 가 없다. 그래서 `${CLAUDE_PLUGIN_ROOT:-./plugins/<p>}` 는
언제나 cwd 상대 `./plugins/<p>` 로 풀린다. devbrew 리포 안에서는 이것이 워킹트리를 가리켜 맞아 보이지만,
사용자 저장소에서는 두 가지로 틀린다.

- **혼동된 대리인.** 사용자는 신뢰한 저장소의 `.claude/` 훅은 검토해도, devbrew skill 이 그 저장소의
  `plugins/quality-gates/scripts/*.sh` 를 실행하리라고는 예상하지 못한다.
- **버전 섞임.** devbrew 의 옛 체크아웃·포크 안에서는 설치본 skill 이 다른 버전의 스크립트를 조용히 돈다.

위협의 크기는 정확히 적는다 — 폴더를 신뢰한 저장소는 이미 제 훅으로 코드를 실행할 수 있으므로, 이것은
신뢰 경계를 넘는 원격 실행이 아니다. #154 리뷰 게이트 3회차가 IMPORTANT 로 올렸고, #155 에서 자리가 1→13줄로
늘었다.

**현재 분포**(base `add4c9cd`, 본문 기준):

| 파일 | cwd fallback | 비고 |
|---|---|---|
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | 13 | `PR=` 스크립트 · `PROFILE=` · `Read` 한 줄 |
| `plugins/spec-distill/skills/framing-requests/SKILL.md` | 3 | `SD=` 둘 · `check_seed.py` 한 줄 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | 5 (SD 관용구) | 끝자락 `\|\| SD="./plugins/spec-distill"` |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | 6 | 펜스 5 · 산문 1 (Step P0b 설명 포함) |
| `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` | 20 | **reference** — 치환이 오지 않는다 |
| `plugins/plugin-audit/skills/auditing-plugins/SKILL.md` | 1 + 자기 하니스 인자 2 + 루트 진술 1 | codex 감지 펜스(112) · 43–44 의 Law 2 정적 게이트가 자기 워크플로·agents 를 cwd 상대 `plugins/plugin-audit/…` 로 받는다 — 150 의 Workflow 는 설치본을 실행하므로 게이트와 실행 대상이 갈라진다 · 17 「모든 스크립트 호출은 리포 root에서」 — 이름만 적힌 자기 스크립트 호출 약 11개가 이 진술로 cwd 사본에 묶인다 |
| `plugins/plugin-audit/scripts/check-law2.py` | 기본값 1 | 201 `--agents-dir` 기본값 `Path("plugins/plugin-audit/agents")` — cwd 상대 |
| `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` | 산문 1 | 38–40 「devbrew 안에서는 `./plugins/quality-gates`」 — 본문에 치환 토큰이 없어 모델이 받는 유일한 구체 경로 |
| `plugins/spec-distill/skills/conducting-interview/references/finishing.md` | 0 (bare 7) | **reference** — bare 가 빈 값으로 풀려 `/scripts/…` 로 깨진다(기능 결함) |

표는 표기(`:-`)가 아니라 개념 — skill 이 모델에게 주는 루트가 cwd 인 자리(`./plugins/<p>` 리터럴, 자기 하니스를
실행·검사 인자로 넘기는 cwd 상대 `plugins/<p>/…`, 「리포 root에서」 같은 루트 진술) — 으로 센다. 감사 대상
`plugins/<target>` 을 cwd 에서 받는 plugin-audit 동작과 처분 앵커(`consumer=plugins/…`) · 문서 포인터 같은
식별자 용례는 실행 루트가 아니라 범위 밖이다. **이 표는 예시다** — 리뷰 두 라운드가 매번 새 자리를 찾았으므로
전수 목록은 plan 이 구조에서 도출한다(D10).

스크립트(.sh/.py) 다섯의 `${CLAUDE_PLUGIN_ROOT:-…}` 는 모두 `$(dirname "${BASH_SOURCE[0]}")/..` 등
스크립트 자기 위치 기준이라 cwd 와 무관하다. 스크립트 안의 cwd 상대 자기 경로 리터럴은 전수 도출로 셋이다:
`check-law2.py:201`(범위, D1.3) · `check-integrity.sh:135` · `run-own-tests.sh:18`(뒤의 둘은 이 PR 이전부터의
불일치라 범위 밖, D2.7).

**실측** (2026-09-14, Claude Code 2.1.270, 헤드리스 `claude -p --model haiku` 4회, 판정은 하니스가 기록한
항목 기준):

| 위치 | bare `${CLAUDE_PLUGIN_ROOT}` | `${CLAUDE_PLUGIN_ROOT:-./plugins/…}` | 근거 |
|---|---|---|---|
| SKILL.md 본문, `--plugin-dir` 로드 | 절대 경로로 치환(산문·bash 펜스 안 모두) | 글자 그대로 | 세션 트랜스크립트의 skill 본문 항목(user, isMeta) |
| SKILL.md 본문, 설치본 spec-distill 3.1.0 | 절대 경로로 치환. 중첩형 `${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}` 는 안쪽만 | 글자 그대로 | Skill 도구 결과: `SD="${CLAUDE_PLUGIN_ROOT:-/Users/…/cache/devbrew/spec-distill/3.1.0}"` · `Read /Users/…/3.1.0/references/proceed-gate.md` |
| `Read` 로 연 reference 파일 | **글자 그대로** | 글자 그대로 | Read 도구 결과: `R1 bare: ${CLAUDE_PLUGIN_ROOT}/scripts/x.py` |
| Bash 도구 환경 | 변수 없음 | — | 이 세션에서 직접 확인 |

`${CLAUDE_SKILL_DIR}` 도 본문에서만 치환된다. 치환은 글자 그대로의 토큰을 맞추므로
`${CLAUDE_PLUGIN_ROOT-}` 같은 변형은 치환되지 않는다. quality-gates 락
`tests/test_skill_plugin_root_fallback.sh` 의 머리말(4–6)은 「`CLAUDE_PLUGIN_ROOT` 는 Bash 도구 환경에 없다(2.1.239
실측). command 계층의 `!` 펜스는 하니스가 치환하지만 skill 의 지시는 모델이 Bash 도구로 실행하므로 치환이
없다」다. 실측 표지는 앞 문장(Bash 환경)에만 붙고, skill 치환 부재는 그 뒤의 추론이다 — 그 추론이 현 버전
기준으로 틀렸고, 그 락은 이 추론으로 `:-` 형태를 **강제**한다.

## Goals

- G1 — 세 플러그인의 skill·command·reference 마크다운 어디에도 cwd 로 풀리는 플러그인 루트가 없다.
- G2 — reference 파일의 펜스는 루트가 비면 cwd 로 가지 않고 비0 종료 + 복구 지시로 멈춘다.
- G3 — reference 를 여는 SKILL.md 가 그 reference 에 필요한 절대 루트를 건넨다.
- G4 — 규칙 하나를 락 하나가 전 플러그인에 집행하고, 반증된 전제의 락은 사라진다.

## Non-goals

- 스크립트(.sh/.py)의 루트 해석 — 이미 스크립트 기준이다. 예외인 `check-law2.py` 의 `--agents-dir` 기본값은
  범위에 든다(D1.3). `check-integrity.sh` 의 harness 변조 감시 범위와 `run-own-tests.sh` 의 quality-gates
  fallback 은 범위 밖이다(D2.7) — agent 정의는 원래 설치 캐시에서 오고 plugin-audit 은 devbrew 루트에서만
  쓰이므로 이 PR 이전부터 있던 불일치이며, 고치려면 git 밖 해시 수집과 플러그인 간 도달성 설계가 따로 필요하다.
- 설치본 reference 를 메인 에이전트가 `Read` 할 때의 권한 질문(cwd 밖 캐시) — 선재 문제, 따로 다룬다.
- 이미 bare 형태만 쓰는 SKILL.md(publishing-pr-understanding · briefing-current-state · conducting-interview
  본문 한 줄 · framing-requests 산문 넷)에 가드를 덧대는 일 — 치환되지 않아도 `/scripts/…` 로 풀려 cwd 로
  가지 않는다(D6). critiquing-artifacts 는 bare 가 아니라 산문 cwd 지시라 범위에 든다(D1.1).
- PR #155 후속 코멘트의 나머지 항목(엔진 1–4 · GC 4b·4c · 테스트 5 · 문서 6).

## Constraints

- C1 — 치환은 SKILL.md 본문 로드 시 글자 그대로의 `${CLAUDE_PLUGIN_ROOT}` 토큰에만 온다(실측). 그 토큰을
  바꾼 어떤 형태도 SKILL.md 에서 치환을 잃는다.
- C2 — Bash 도구는 호출마다 새 셸이다. 루트 대입은 그 값을 쓰는 펜스 안에 있어야 한다.
- C3 — 가드 앞에 `set -u` 를 두지 않는다. unbound 오류가 복구 메시지를 가린다.
- C4 — 가드 메시지 안에 `${CLAUDE_PLUGIN_ROOT}` 토큰을 쓰지 않는다. SKILL.md 에서는 그것까지 치환된다.
- C5 — 락의 대상 집합은 파일 구조에서 도출한다(손 열거 금지). 파싱은 python 으로 한다.

## 설계

### 1. SKILL.md — bare 형태로

cwd fallback 을 쓰는 SKILL.md 펜스는 루트를 bare 토큰에서 받고, 같은 펜스에서 가드를 통과한다.

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — 이 펜스의 루트 변수를 SKILL.md 가 보여 준 플러그인 절대 경로로 바꿔 다시 실행하라" >&2; exit 1; }
```

(메시지는 초안이다 — 확정 문안은 plan, C4 를 지킨다.) 로드 시 치환되면 `QG="/…/quality-gates/<ver>"` 가 되어 가드는 늘 통과한다. 치환이 없는 하니스에서는 빈
값이 되어 멈춘다. reviewing-spec 의 SD 관용구도 끝자락 `|| SD="./plugins/spec-distill"` 를 이 가드로 바꾼다.
quality-gates Step P0b 의 설명(「devbrew 안에서는 `./plugins/quality-gates`」)과 산문 한 줄도 새 모델로 다시
쓴다.

### 2. reference — 가드와 SKILL.md 가 건네는 루트

reference 파일(`runtime-gate.md` · `finishing.md`)은 `Read` 로 열리므로 어떤 토큰도 치환되지 않는다.

- reference 의 펜스는 1절과 같은 형태로 루트를 대입하고 가드를 통과한다. 모델이 그대로 실행하면 값이
  비어 가드가 멈추고, 메시지가 복구 지시(「SKILL.md 가 보여 준 플러그인 루트 절대 경로로 바꿔 넣고 다시
  실행」)가 된다.
- 그 reference 를 여는 SKILL.md 의 `Read` 줄은 `Read ${CLAUDE_PLUGIN_ROOT}/skills/<skill>/references/<file>.md`
  로 바꾼다 — 치환되어 절대 경로가 된다. 같은 자리에 한 문장을 둔다: 「그 파일에서 플러그인 루트 변수는
  치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다.」 뒤 토큰만 치환되어
  모델에게 절대 경로가 보인다. 해당 자리는 quality-gates `SKILL.md:845` 와 conducting-interview `SKILL.md:315`
  둘이다.
- reference 산문 속 포인터(`finishing.md` 의 `${CLAUDE_PLUGIN_ROOT}/references/compression.md` 등)는 형태를
  바꾸지 않는다 — 위 한 문장이 읽기에도 적용된다.

모델이 바꿔 넣기를 빠뜨려도 결과는 멈춤이지 cwd 실행이 아니다. 이것이 이 설계에서 모델에 기대는 유일한
고리이며, 검증 계획의 프로브가 잰다.

### 3. 락

**새 공용 락** `shared/tests/test_plugin_root_no_cwd_fallback.sh`. 대상은 `plugins/*/skills/**/*.md` ·
`plugins/*/commands/*.md` · `plugins/*/references/**/*.md` 의 본문(frontmatter 제외)이다.

- 축 1 — 본문 전수(산문·펜스 모두)에 `CLAUDE_PLUGIN_ROOT:-` 가 0곳.
- 축 1b — 본문 전수에 cwd 상대 플러그인 루트가 0곳이다(D1.2). 대상은 표기가 아니라 개념이다:
  `./plugins/<p>` 리터럴(대입 끝자락 `|| X="./plugins/<p>"` · 산문 「devbrew 안에서는 `./plugins/<p>`」 모두)과,
  자기 하니스를 실행·검사 인자로 넘기는 cwd 상대 `plugins/<p>/…`. 처분 앵커 · 문서 포인터 같은 식별자 용례와
  감사 대상 `plugins/<target>` 은 제외한다 — 제외 규칙과 수정 뒤 남는 정당 용례 수는 plan 이 base 에서 센다.
- 축 2 — reference 파일(경로에 `/references/` 가 있는 파일)의 bash 펜스 중 변수를 쓰는 것은, 같은 펜스
  안에서 그 사용보다 앞에 가드(빈 값 검사 → 비0 종료)가 있다. **bash 펜스**는 여는 줄이 앞 공백 들여쓰기를
  허용한 `` ```bash `` 이고 닫는 줄이 같은 들여쓰기의 `` ``` `` 인 블록이다 — 행 머리에 고정한 정규식(은퇴하는
  락의 `^```bash`)은 목록 안 펜스 `finishing.md:87–89` 를 놓친다. **사용**은 루트 대입문
  (`X="${CLAUDE_PLUGIN_ROOT}"`)과 가드 자신의 빈 값 검사(`[ -n "$X" ]`)를 뺀 나머지 — 토큰의 다른 등장과
  `$X` 로 경로를 짓거나 명령을 실행하는 등장 — 이며, 전부 가드의 비0 종료보다 뒤에 있어야 한다.
- 축 3 — 변수를 담은 reference 마다, 그 파일 이름으로 그것을 `Read` 하는 SKILL.md 줄이
  `${CLAUDE_PLUGIN_ROOT}/…` 절대 형태이고 같은 절에 치환 안내 문장이 있다.
- 공허 통과 방지 — 축 2 대상 펜스 수와 축 3 대상 reference 수에 하한을 둔다(값은 plan 이 base 에서 센다).
- 양성 대조 — 가드형 펜스가 실제로 존재하고, 가드가 빈 값에서 비0 으로 끝나는지 한 펜스를 잘라 실행한다.

**은퇴** — quality-gates `tests/test_skill_plugin_root_fallback.sh` 를 지운다. 전제가 실측으로 반증됐고, 그
축 A(펜스 안 `:-` 강제)·축 B(bare 금지)는 새 규칙과 반대 방향이다.

**행동 테스트** — 수정된 펜스를 잘라 두 조건에서 실행한다. (a) 치환 흉내(토큰을 픽스처 루트로 텍스트
치환) → 픽스처 플러그인의 스크립트가 돈다. (b) 무치환 · 변수 없음 · cwd 에 `./plugins/<p>/scripts/` 미끼
→ 미끼가 돌지 않고 비0 종료. 펜스를 잘라 실행하는 기존 테스트는 (a) 방식으로 루트를 받도록 고친다.

### 4. 문서 · 버전

- 세 플러그인 CHANGELOG 에 항목과 「알려진 결과」(아래 알려진 한계의 첫 둘)를 적는다. 버전은 patch,
  번호는 머지 직전에 정한다.
- `test_finishing_block_scope.py` 의 머리말 「`CLAUDE_PLUGIN_ROOT` 는 Claude Code 가 export 한다」는 실측과
  어긋나므로 고친다.

## Acceptance Criteria

- **AC1** — 대상 마크다운 본문 어디에도 `CLAUDE_PLUGIN_ROOT:-` 도, cwd 상대 플러그인 루트(축 1b 의 정의)도 없다.
  (새 락 축 1 · 1b)
- **AC2** — reference 의 변수 사용 펜스는 전부 같은 펜스 안 앞선 가드를 가진다. (축 2)
- **AC3** — 변수를 담은 reference 를 여는 SKILL.md `Read` 줄은 절대 형태이고 치환 안내 문장이 같은 절에
  있다. (축 3)
- **AC4** — 무치환 · 변수 없음 · cwd 에 미끼가 있는 조건에서, 수정된 SKILL.md 펜스와 reference 펜스 각각의
  대표 하나를 실행하면 미끼가 실행되지 않고 비0 으로 끝나며 stderr 에 복구 지시가 나온다.
- **AC5** — 치환 흉내 조건에서 같은 펜스가 픽스처 플러그인의 스크립트를 실행한다(AC4 의 양성 짝).
- **AC6** — `test_skill_plugin_root_fallback.sh` 가 없고, 그 이름을 가리키는 활성 참조(테스트 목록 · 기대
  실패 목록 · `# guards:` 선언)가 0이다. 이력 기록(CHANGELOG · `docs/archive/` · 지난 plan)은 제외한다.
- **AC7** — 새 락의 변이가 모두 RED 다: SKILL.md 펜스에 `:-./plugins/x` 추가 · SKILL.md 산문에 추가 ·
  command 에 추가 · reference 펜스의 가드 삭제 · 가드를 사용 뒤로 이동 · `Read` 옆 안내 문장 삭제 ·
  `Read` 줄을 상대 형태로 되돌림 · bare 대입 뒤에 `|| X="./plugins/x"` 끝자락 추가 · SKILL.md 산문에
  「devbrew 안에서는 `./plugins/x`」 추가 · 자기 하니스 실행 인자를 cwd 상대 `plugins/<p>/…` 로 되돌림 ·
  들여쓴 reference 펜스에서 가드 삭제. 양성 대조는 GREEN 이다.
- **AC8** — 전체 스위트(세 플러그인 + shared)에서 base 대비 새 실패가 0이다. 파일별 실패 **줄 수**로
  비교한다.
- **AC9** — 헤드리스 프로브(관찰 · 기록): 브랜치의 플러그인을 `--plugin-dir` 로 로드하고 cwd 에 미끼를 둔
  세션에서 (a) 수정된 SKILL.md 펜스가 절대 경로로 도착한다(하니스 기록) (b) reference 펜스 실행에서 미끼가
  한 번도 실행되지 않는다. 모델이 바꿔 넣었는지 · 가드에서 멈췄는지는 결과로 적는다 — 통과 조건은
  (a)와 「미끼 미실행」이다.
- **AC10** — 세 플러그인 CHANGELOG · patch bump. 알려진 결과 둘이 공시된다.
- **AC11** — plugin-audit 의 Law 2 정적 게이트가 검사하는 워크플로 · agents 는 같은 skill 의 Workflow 가
  실행하는 것과 같은 플러그인 루트에서 온다(`check-law2.py` 의 `--agents-dir` 기본값 포함). cwd 에
  `plugins/plugin-audit/` 이 없는 조건에서도 게이트가 설치본 파일로 돈다.

## Files to Modify

| 파일 | 변경 |
|---|---|
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | fallback 13줄 → bare + 가드 |
| `plugins/spec-distill/skills/framing-requests/SKILL.md` | fallback 3줄(218 · 408 · 633) → bare + 가드 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | SD 관용구 5줄(27 · 112 · 149 · 170 · 299)과 `PROFILE=` 3줄(150 · 173 · 303) |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | `Read` 줄(315) 절대 형태 + 안내 문장 · 318 의 「세 포인터 공통 규칙」 문단 재작성 — finishing 만 절대 형태가 되고 seed-input(292) · state-migration(329) 은 상대 형태로 남으므로 규칙을 둘로 나눠 적는다 |
| `plugins/spec-distill/skills/conducting-interview/references/finishing.md` | 펜스 둘(88 · 175)에 가드 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | Step P0b(116–127) · 펜스 135 · 274 · 293 · 915 · 산문 509 · `Read` 줄 845 · 848–850 의 「상대경로」 문단 재작성 |
| `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` | `QG=` 20줄 → bare + 가드 |
| `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` | 38–40 → 치환되는 bare 토큰으로 스크립트 루트를 알려 주는 문장 (D1.1) |
| `plugins/plugin-audit/skills/auditing-plugins/SKILL.md` | 112 · 17–21 의 루트 진술 재작성 — 「스크립트는 `${CLAUDE_PLUGIN_ROOT}/scripts/`(로드 시 치환), 감사 대상 인자는 리포 root」, 「`--agents-dir` 기본값이 cwd-relative」 서술도 함께 고친다(D2.4) · 43–44 의 `check-law2.py` 호출과 자기 워크플로 · agents 인자를 bare `${CLAUDE_PLUGIN_ROOT}/…` 로 — 산문이라 `$PA` 는 빈 값이다(D1.3) |
| `plugins/plugin-audit/scripts/check-law2.py` | 201 `--agents-dir` 기본값을 스크립트 위치 기준으로 (D1.3) |
| plan 의 도출 스윕이 찾은 나머지 자리 | 같은 규칙 — skill 이 주는 루트를 치환 루트로 (D10) |
| `plugins/quality-gates/tests/test_skill_plugin_root_fallback.sh` | 삭제 |
| `shared/tests/test_plugin_root_no_cwd_fallback.sh` | 신규 |
| 펜스를 잘라 실행하는 기존 테스트 | 치환 흉내로 루트 받기 (목록은 plan) |
| `plugins/spec-distill/tests/test_finishing_block_scope.py` | 머리말 정정 |
| 세 플러그인 `CHANGELOG.md` · `.claude-plugin/plugin.json` | 항목 · patch bump |

## Verification Plan

1. 착수 전 base(`add4c9cd`)에서 전체 스위트를 돌려 파일별 실패 줄 수를 기록한다(main 의 선재 RED 둘 포함).
2. 새 락 GREEN · AC7 변이 행렬 전부 RED · 양성 대조 GREEN. 변이는 커밋 뒤에 걸고 `git checkout HEAD --`
   로 되돌린다.
3. AC4 · AC5 행동 테스트.
4. 구현 뒤 전체 스위트 → 1과 파일별 실패 줄 수 비교(AC8).
5. AC9 헤드리스 프로브(haiku, 몇 회) — 결과를 PR 에 적는다.
6. `/qg` Review gate.

## Rejected Alternatives

- **SD 관용구로 통일(코멘트 원안).** SKILL.md 에서는 오늘 안전하지만 치환이 없는 하니스에서 끝자락이 cwd 로
  떨어지고, reference 파일에는 효과가 없다(C1 · 실측).
- **reference 에 자리표시자(`QG="<QG_ROOT>"`).** 모델이 채우는 점은 2절과 같은데, 파일 종류마다 형태가 둘이
  되어 락이 둘을 갈라야 한다.
- **reference 의 펜스를 SKILL.md 로 되돌리기.** 모델 의존이 0 이 되지만 조건부 로드 분리를 무너뜨려 `/qg`
  마다 `runtime-gate.md` 1206줄을 더 싣는다(#122 무게 감축의 역행).
- **루트를 상태 파일에 적어 reference 가 읽기.** 상태 경로 리졸버(`state_path.py`)가 플러그인 루트를 먼저
  요구해 순환한다.
- **devbrew 안에서만 cwd fallback 을 조건부로 살리기**(마켓플레이스 이름 검사 등). 그 표식을 저장소가
  흉내 낼 수 있어 결함이 돌아온다.
- **quality-gates 락의 전제만 고쳐 유지.** 한 규칙에 락이 둘이 되고, 그 락은 quality-gates 만 재서 형제
  플러그인이 샌다.

## 알려진 한계

- **devbrew 안 dogfooding 이 바뀐다.** 지금은 설치본 skill 이 cwd 의 워킹트리 스크립트를 돈다. 이제는 설치본
  skill 이 설치본 스크립트를 돈다. 워킹트리 코드를 돌리려면 `claude --plugin-dir ./plugins/<p>` 로 로드한다.
- **치환이 없는 하니스에서는 멈춘다.** 어느 버전이 그런지는 모른다 — quality-gates 락의 2.1.239 실측은 Bash
  환경 변수 부재에 대한 것이지 skill 본문 치환에 대한 것이 아니다.
- **락은 이름만 적힌 스크립트 호출과 「리포 root에서」 같은 산문 루트 진술을 잡지 못한다.** 산문이 실행 지시인지
  설명인지를 가려야 해서다. 그 부류는 skill 의 루트 진술을 치환 루트로 바꿔 닫고(D2.4), 전수 목록은 plan 의
  도출 스윕이 만든다(D10). 축 1b 는 `./plugins/<p>` 리터럴 회귀만 잡는다.
- **plugin-audit 스크립트 둘은 여전히 체크아웃을 본다(D2.7).** `check-integrity.sh` 의 harness 변조 감시는
  체크아웃 사본을 해시하는데 실행되는 agent 는 설치 캐시에서 오고, `run-own-tests.sh` 는 quality-gates
  스크립트를 cwd 에서 찾는다. 이 PR 이전부터의 불일치이며 후속으로 넘긴다.
- **대화형 세션은 재지 않았다.** 치환은 하니스 쪽 동작이라 같을 공산이 크다.
- **reference 에서의 루트는 모델이 바꿔 넣는다.** 빠뜨리면 멈추고 복구 지시를 따라 다시 시도한다 —
  보안이 아니라 매끄러움의 비용이다.
- **프로젝트 settings 의 `env` 로 `CLAUDE_PLUGIN_ROOT` 를 심으면 reference 펜스가 그 값을 따른다.** 그런
  저장소는 이미 훅으로 코드를 실행할 수 있어 신뢰 경계 안이다.

## Concrete Next Action

다음 단계: `superpowers:writing-plans` — 입력은 이 문서
(`docs/superpowers/specs/2026-09-14-plugin-root-cwd-fallback-design.md`). 그 전에 이 문서를
`spec-distill:reviewing-spec` 으로 리뷰하고 그 승인 게이트를 거친다.

## 결정 기록

사용자 결정(2026-09-14, 이 세션):

| # | 질문 | 결정 |
|---|---|---|
| D1 | PR #155 후속 목록 중 첫 묶음 | 항목 7 — 보안 fallback |
| D2 | 범위 | 전 플러그인(spec-distill · quality-gates · plugin-audit, reference 둘 포함) |
| D3 | 치환이 없는 reference 에 루트를 건네는 방식 | A — 단일 관용구 + 가드, SKILL.md 가 절대 경로를 건넨다 |
| D4 | 설계 5절(관용구 · reference · 락 · 한계 · 검증) | 승인 |
| D10 | 리뷰 라운드 3 에서 같은 부류(암묵적 cwd 루트)의 새 자리가 나오면 | 설계는 규칙과 도출 방법만 둔다. 전수 목록은 plan 의 도출 스윕이 만들고, 새 자리는 설계를 넓히지 않고 Deferred 로 넘긴다 |

오케스트레이터가 정하고 사용자에게 알린 것(되돌리려면 괄호 안의 한마디):

| # | 정한 것 | 근거 |
|---|---|---|
| D5 | reviewing-spec 의 SD 관용구도 가드로 교체 (「reviewing-spec 은 그대로」) | D2 범위 · SD 끝자락도 cwd |
| D6 | 가드 강제는 reference 펜스만. 이미 bare 인 SKILL.md 는 건드리지 않고, 이번에 고치는 SKILL.md 자리만 가드형을 쓴다 (「SKILL.md 도 전부 가드」) | SKILL.md 의 bare 는 치환되며, 치환이 없어도 `/scripts/…` 로 풀려 cwd 로 가지 않는다. 설계 제시 때의 「SKILL.md 도 가드형」을 줄 전수 뒤 좁혔다 |
| D7 | quality-gates 락 은퇴 · 공용 락으로 대체 (「qg 락은 고쳐서 유지」) | 전제 반증 · 새 락이 전 축을 덮는다 |
| D8 | dogfooding 변화 수용 (「devbrew 안에서는 워킹트리 스크립트 유지」) | 되살리려면 조건부 cwd fallback 이 필요해 보안 수정과 충돌 |
| D9 | 스크립트(.sh/.py) 범위 밖 | 다섯 모두 스크립트 기준 fallback (전수 grep). 스크립트 안의 cwd 상대 리터럴 셋은 D1.3 · D2.7 이 따로 다룬다 |

리뷰 라운드의 결정(번호는 리뷰 엔진이 매긴 `D<라운드>.<순번>` — 위 D1–D10 과 다른 계열이다):

| # | 라운드 | 항목 | 결과 |
|---|---|---|---|
| D1.1 | 1 | critiquing-artifacts 의 산문 cwd 지시 | 채택 — 범위에 넣고 38–40 을 치환 루트 문장으로 |
| D1.2 | 1 | 새 락이 `:-` 표기만 잰다 | 채택 — 락 강화(축 1b · AC1 · AC7 변이) |
| D1.3 | 1 | plugin-audit 정적 게이트의 자기 하니스 경로 | 채택 (a) — 범위에 넣음(43–44 · `check-law2.py` 기본값 · AC11) |
| D2.4 | 2 | auditing-plugins 의 이름 호출 + 17 행 「리포 root에서」 | 채택 — 루트 진술 재작성 |
| D2.5 | 2 | (자동) Acceptance Criteria 절 변경 | 채택 — D1.2 · D1.3 반영분 |
| D2.6 | 2 | (자동) 목차 추가 | 채택 — CLAUDE.md 300줄 규칙 |
| D2.7 | 2 | `check-integrity.sh` · `run-own-tests.sh` 의 cwd 경로 | 채택 (b) — 범위 밖 · 알려진 한계 · 후속 |

### Deferred to plan

- 펜스를 잘라 실행하는 기존 테스트 전수(`test_codex_gate_observation.sh` 의 plugin-audit 블록 ·
  reviewing-brief 계열 · `test_reviewing_spec_entry_fence.sh` 의 무치환 변형 기대 등)와 각각의 치환 흉내 방식.
- `shared/tests/test_skill_reference_pointers.sh` 가 인식하는 포인터 형태와 새 `PROFILE=` 형태의 정합 —
  3.0.0 에서 `$SD/references/…` 형태가 그 락을 RED 로 만든 선례가 있다.
- 가드 메시지 확정 문안(C4).
- 새 락의 하한 값과 `# guards:` 선언 형식.
- 은퇴하는 락을 가리키는 활성 참조 목록(기대 실패 목록 · 러너 목록 등).
- baseline 실행 명령(spec-distill 의 python 테스트는 `-m unittest` 로만 돈다).
- 축 3 이 「같은 절에 치환 안내 문장이 있다」를 무엇으로 인식하는지 — 고정 리터럴 · 마커 · 「같은 절」의 경계.
  부분 문자열로 인식하면 뒤집은 문장도 통과한다(AC7 의 「`Read` 옆 안내 문장 삭제」 변이가 이 규칙에 기댄다).
- 전수 목록 도출 스윕(D10) — 각 플러그인 `scripts/` 의 실제 파일 이름 × 자기 skill · reference · command 본문의
  루트 진술과 실행 지시. 설계의 「현재 분포」 표는 예시다. 이름만 적힌 언급은 실행 지시와 설명을 가려 센다.
