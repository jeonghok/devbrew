# spec-distill brief 포맷·producer 재설계 (Spec A) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** interview brief의 권위 문법(`locked_directions` / *"재논쟁 금지"*)을 producer·템플릿·게이트·compact 핸드오프 네 곳에서 동시에 제거하고, payload를 8섹션 역피라미드 + 별도 audit 파일로 가르며, 확정 권한을 종료 직전 사용자 일괄 확인으로 되돌린다.

**Architecture:** `check_brief.py`가 단일 파일 게이트에서 **2파일 fail-closed 게이트**로 바뀐다 — payload frontmatter의 `audit_file`(basename만)로 audit을 해석하고, 두 파일에 걸친 세 bijection(A: payload §5 ↔ audit §3 `ST<N>` / B: body §2 ↔ frontmatter 항목 / C: `evidence: S<N>` → payload §6)을 검사한다. `conducting-interview/SKILL.md`의 라운드별 `locked?` decision table은 판정 없는 `user_statements` 기록으로 대체되고, 확정 전이는 종료 proceed 게이트 한 번에 흡수된다.

**Tech Stack:** Python 3.9(시스템 python3 — 3.10+ 문법 금지), 서드파티 import 0개(플러그인 전 스크립트 규약 — 훅이 임의 사용자 환경에서 돈다), bash 3.2(macOS) 테스트 하니스, 마크다운 템플릿.

## Global Constraints

프로젝트 전역 요구사항. **모든 태스크의 요구사항에 암묵적으로 포함된다.**

- **spec 원문**: `docs/superpowers/specs/2026-07-25-spec-distill-brief-format-producer-design.md`. AC1–AC16 / T1–T24 / V1–V10이 이 계획의 검증 표면이다.
- **파이썬**: 시스템 `python3` = **3.9.6**. `match` 문·`X | Y` 런타임 union 금지. `from __future__ import annotations`가 이미 있으므로 `list[str]` 어노테이션은 가능.
- **서드파티 import 금지**: `plugins/spec-distill/scripts/` 전체에 `import yaml`이 **0건**이다. frontmatter는 손으로 파싱한다(PyYAML이 이 머신에 있어도 쓰지 않는다).
- **파일 읽기는 `encoding="utf-8"` 명시** — non-UTF-8 locale fail-open 방지(기존 `check_brief.py` 규약).
- **테스트 하니스**: spec §8.1은 `python3 -m unittest`를 명시하지만 `check_brief` 계열의 실제 하니스는 **bash**(`tests/test_check_brief.sh`)다. 기존 패턴을 따라 bash 파일을 확장한다. 새로 만드는 **Python** 테스트가 생기면 그때만 `-m unittest`(pytest 금지).
- **CI 없음.** 테스트는 repo root에서 개별 실행: `bash plugins/spec-distill/tests/<name>.sh`.
- **baseline (2026-07-26 측정, main 4ebfd78 + 이 브랜치)**: `test_check_brief` 23/23, `test_conducting_interview_stage` 77/77, `test_stale_terms` 3/3, `test_readme_sync` 15/15 — **전부 green**. 어떤 태스크도 이 넷을 red로 남기고 끝내지 않는다.
- **bash 3.2 함정**(이 리포에서 실측된 것): `set -u` 하에서 빈 배열 `"${arr[@]}"` 확장은 crash → 명시 guard 필수. `mktemp` 결과를 받는 대입은 반드시 `|| exit 1` — 빈 문자열이 `rm -rf`에 흘러가면 repo가 지워진다. `$(... -z)` 캡처는 NUL을 잃는다.
- **문서 언어**: Korean-primary. 영어는 식별자·고유명사·원문 인용·대응 한국어가 없는 기술어에 한정.
- **버전**: `plugins/spec-distill/.claude-plugin/plugin.json`을 `0.23.0`으로 bump. **Task 9에서 한 번만** — `tests/test_readme_sync.sh`가 `0.22.x`를 pin하고 있어 먼저 bump하면 Task 1–8이 stale-red가 된다. Task 9가 bump와 pin 갱신을 같은 커밋에 담는다. 버전 리터럴은 **minor까지만** pin(`0\.23\.[0-9]+`).
- **금지 리터럴 6개**(AC13): `locked_directions` · `pending_locked_decisions` · `재논쟁 금지` · `Locked Directions` · `다시 묻지 않는다` · `확정·재논쟁`. 락 스코프 = `plugins/spec-distill/` 하위 production 전 파일, 제외 = `tests/` · `CHANGELOG.md` · `README.md` · 캐시/바이너리. (repo-level `docs/`는 `$SD` 밖이라 자동 제외.)
- **커밋**: Conventional Commits. 각 태스크 끝에서 1커밋. 브랜치 `feature/brief-format-producer`(이미 존재, 7커밋 미푸시).

### Spec 대비 발견된 두 갭 (이 계획이 메움)

구현 착수 전 코드를 읽다 나온 것으로, **spec §7 Files to Modify가 놓친 파일**이다. 그대로 두면 AC13 락이 red가 된다.

1. **`agents/` 3개 파일이 `locked_directions`를 참조한다** — `blind-spot-prober.md:35`, `steelman-builder.md:36`, `coverage-mapper.md:37`의 `## Input` 절. production 파일이므로 AC13 락 스코프 안이다. §7에 없다 → **Task 6에서 함께 편집**한다.
2. **`tests/test_conducting_interview_stage.sh:67`이 `pending_locked_decisions`의 *존재*를 assert한다** (`has 'pending_locked_decisions' "AC1: pending_locked_decisions retained"`). 이 계획은 그 필드를 제거하므로 assert를 **반전**해야 한다(존재 → 부재 + `user_statements` 존재). 같은 파일 98행의 `9-section` assert도 8섹션으로 바뀐다. §7은 `tests/`를 "신규 케이스"로만 적었다 → **Task 6에서 기존 assert 수정**을 명시한다.

### Spec 해석 결정 1건 (사용자 redirect 가능)

spec §5.2의 종료 흐름은 `AskUserQuestion ① 이대로 확정하고 진행 / ② 확정 목록 수정 / ③ 중단` 3지선다로 그려져 있다. 그런데 현행 Step B-2 게이트는 `① /compact 후 brainstorming / ② 바로 brainstorming / ③ brief만 종료` 3지선다이고, `tests/test_conducting_interview_stage.sh:43`이 `바로 brainstorming` 라벨을 assert한다.

두 집합을 그대로 합치면 상호작용이 2회가 되는데, spec §9는 그것을 명시적으로 기각했다(*"기존 `/compact` proceed 게이트에 흡수하면 1회 유지"*). 반면 `바로 brainstorming`(compact 없이 즉시 진행)은 §3 Non-goals에 제거 대상으로 적혀 있지 않은 **shipped 기능**이다.

→ **4옵션 단일 게이트**로 구현한다(`AskUserQuestion`은 2–4 옵션 허용):

| 옵션 | 의미 | `status: confirmed` 전이 |
|---|---|---|
| ① 확정하고 /compact 후 brainstorming (권장) | 확정 + 옵션 ① handoff | ✅ |
| ② 확정하고 바로 brainstorming | 확정 + 옵션 ② handoff | ✅ |
| ③ 확정 목록 수정 | 재제시 (상한 2회) | ❌ |
| ④ brief만 종료 | terminal, handoff 없음 | ❌ |

AC2의 *"옵션 ①을 고를 때만"*은 **"확정-후-진행 옵션(①/②)을 고를 때만"**으로 읽는다. 상호작용 횟수는 1회로 유지되고, 확정이 사용자의 명시적 행위로만 일어난다는 AC2의 실질은 보존된다. **사용자가 3옵션(바로 brainstorming 제거)을 원하면 Task 7만 고치면 된다.**

---

## File Structure

| 파일 | 책임 | 태스크 |
|---|---|---|
| `templates/interview-brief-template.md` | payload 8섹션 역피라미드 + 항목 문법 + 분량 예산 (재작성) | 1 |
| `templates/interview-audit-template.md` | audit 5섹션 텔레메트리 (신규) | 1 |
| `scripts/check_brief.py` | 2파일 fail-closed 게이트 + 스키마 + 3 bijection + 분량 지표 | 1–5 |
| `tests/fixtures/interview-brief-*.md` / `*.audit.md` | 게이트 픽스처 코퍼스 (전면 이관 + 신규) | 1–5 |
| `tests/test_check_brief.sh` | 게이트 구조 테스트 T1–T19, T21–T24 | 1–5 |
| `skills/conducting-interview/SKILL.md` | producer(발화 기록) + 종료 확정 확인 + compact/C4 프로토콜 | 6–7 |
| `agents/{blind-spot-prober,steelman-builder,coverage-mapper}.md` | Input 절의 `locked_directions` 참조 제거 | 6 |
| `tests/test_conducting_interview_stage.sh` | SKILL 계약 assert (기존 반전 + 신규) | 6–7 |
| `tests/test_stale_terms.sh` | AC13 6-리터럴 회귀 락 + mutation | 8 |
| `.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md` · `tests/test_readme_sync.sh` | 버전·이력·원칙 (AC14, T20) | 9 |

`check_brief.py`는 이 계획이 끝나면 ~450줄이 된다. 파일 분할은 하지 않는다 — 단일 게이트 계약이고, 소비자(`SKILL.md`)가 경로 하나만 안다. spec의 *"Deferred to plan: 내부 함수 분해 방식"*은 이 결정을 구현 재량으로 남겼다.

---

## Task 1: 게이트 골격 — 새 템플릿 2종 + 섹션 좌표 이관 + audit 2파일 해석

payload 섹션 번호가 바뀌는 순간 기존 픽스처 16개가 전부 깨지므로, **좌표 이관과 픽스처 코퍼스 재생성은 쪼갤 수 없다.** 이 태스크가 끝나면 새 포맷 정상 쌍이 게이트를 통과하고, 기존 의례(landscape 인용·skepticism 형식·기각 sentinel·Coverage Ledger)가 전부 새 좌표에서 그대로 동작한다.

**Files:**
- Create: `plugins/spec-distill/templates/interview-audit-template.md`
- Create: `plugins/spec-distill/tests/fixtures/interview-brief-valid.audit.md`
- Modify: `plugins/spec-distill/templates/interview-brief-template.md` (전면 재작성)
- Modify: `plugins/spec-distill/scripts/check_brief.py:50-60,84-93,104-120,158-201,204-259,262-293`
- Modify: `plugins/spec-distill/tests/fixtures/interview-brief-*.md` (16개 이관)
- Test: `plugins/spec-distill/tests/test_check_brief.sh`

**Interfaces:**
- Produces:
  - `SECTIONS: list[tuple[str, str]]` — payload 8섹션 `("0","한눈에") … ("7","Next Action")`
  - `AUDIT_SECTIONS: list[tuple[str, str]]` — audit 5섹션 `("1","Coverage Ledger") … ("5","프로세스 로그")`
  - `find_missing_sections(text: str, sections: list = SECTIONS) -> list[str]`
  - `_frontmatter(text: str) -> str` — frontmatter 본문(구분자 제외), 없으면 `""`
  - `resolve_audit(payload: Path, fm: str) -> tuple[Path | None, str | None]` — `(audit_path, error)`
  - `_section_text(text: str, num: str, title: str) -> str` (기존 시그니처 유지)
  - `gate(path: Path) -> int` — payload 경로만 받고 audit은 내부에서 해석

- [ ] **Step 1: 새 payload 템플릿을 쓴다**

`plugins/spec-distill/templates/interview-brief-template.md`를 아래로 **전면 교체**:

````markdown
---
name: <kebab-topic>
type: interview-brief
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill conducting-interview v0.23.0
next_phase: superpowers:brainstorming
audit_file: <YYYY-MM-DD>-<kebab-topic>-interview.audit.md   # basename만 (같은 디렉토리)
# user_sourced_items — **사용자 출처 항목만**. `source: inferred`는 여기 들어갈 수 없다(게이트 fail).
# 모델 추론은 본문 프로즈에 ✎ 표기로만 산다.
# status는 인터뷰 종료 직전 사용자 일괄 확인으로만 confirmed가 된다 — 라운드 중에는 전부 provisional.
# confirmed 0건이면 다음 sentinel 한 줄을 이 블록 안에 명시한다:
#   # confirmed 0건 — 사용자가 전부 잠정으로 판단
user_sourced_items:
  - id: C1
    source: verbatim          # verbatim(발화 그대로) | chosen(선택지 선택)
    status: provisional       # confirmed | provisional | open
    statement: "<160자 이내 — 모델이 쓴 제약 한 줄. P21 secret placeholder 치환>"
    evidence: S1              # §6의 어느 발화에서 나왔는가 — 필수
---

# <Topic> — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

(≤15줄. 무엇 / 왜 / 무엇이 확정 / 무엇이 열려 있음 / 다음 stage. 다음 세션이 여기만 읽고도
 방향을 잡을 수 있어야 한다.)

## 1. Goal · Non-goal

(≤12줄.)

- Goal: ...
- Non-goal: ...

## 2. 제약

(≤30줄. 이 절의 진술은 모델이 쓴 요약이다. 원문은 §6, `⟨S<N>⟩`가 그것을 가리킨다.)

- 🗣 confirmed **C1** — <statement> ⟨S1⟩
- ☑ provisional **D2** — <statement> ⟨S2⟩

✎ (모델 추론은 이 프로즈 형식으로만. frontmatter 계약 밖이라 게이트 대상이 아니다.)

## 3. Open Questions

(≤25줄. 미해결 명시 — "유추 금지". 탐색 대상이므로 앞쪽에 온다.)

- OQ1: ...

## 4. External Landscape

(≤20줄. 1항목 = 1줄, **출처 URL 필수** + [취함|피함|중립] + 이유.)

- ... — https://example.com — [취함] — 이유

## 5. 기각 · Blind Spots

(≤25줄. `기각` 항목이 0건이면 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄 명시(빈 섹션 금지).
 `verdict:`를 가진 항목은 audit §3의 `ST<N>` 참조가 필수다.)

- 기각 — <시도한 방향> → <버린 이유>
- 기각 — <시도한 방향> → <버린 이유> — https://evidence.example — verdict: defended — ST1
- 위험 — <숨은 가정 | 실패 양식>: <내용> — <근거>

## 6. 사용자 원문

(분량 무제한 — **전문 보존**. 허용 변환은 P21 placeholder 치환·앞뒤 공백 정리·인용 블록 래핑뿐이며
 요약·재서술·발췌는 금지. 각 항목이 `S<N>` 앵커를 제공한다.)

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S1** 🗣 최초 요청:
  > "..."
- **S2** ☑ 선택 (<무엇에 대한 선택>):
  > "..."

## 7. Next Action

(≤10줄. superpowers 있으면: 이 brief를 context로 `superpowers:brainstorming` 호출 → `-design.md`
 → reviewer 검증 → writing-plans. 없으면: 이 brief가 완결 산출물 — 직접 사용.)
````

- [ ] **Step 2: 새 audit 템플릿을 쓴다**

`plugins/spec-distill/templates/interview-audit-template.md` (신규):

````markdown
---
type: interview-audit
payload: <YYYY-MM-DD>-<kebab-topic>-interview.md
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill conducting-interview v0.23.0
---

# <Topic> — Interview Audit

> 순수 텔레메트리. 재논쟁 차단에 쓰이는 것은 payload이고, 여기에는 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

(커버리지 원장 직렬화 — floor 5행(전부 closed + evidence) + derived(≥1행 OR N/A sentinel).
 orchestrator가 state.local.md에서 직렬화한다.)

- floor:root_problem — closed — <evidence>
- floor:landscape — closed — <evidence>
- floor:skepticism — closed — <evidence>
- floor:blind_spot — closed — <evidence>
- floor:open_questions — closed — <evidence>
- derived:<name> — closed — <rationale>; <evidence>

## 2. Budget

- probe_count: <n> / cap <n>
- web_sweep_count: <n> / 4
- web_search_count: <n> / 8

## 3. Steelman 원문

(steelman-builder 출력 verbatim. payload §5의 `verdict:` 항목이 여기의 `ST<N>`을 참조한다 —
 양방향 일치가 게이트 대상이다. steelman 0건이면 이 절은 비어 있어도 되고 sentinel도 필요 없다.)

#### ST1 — <한 줄 요지>

> <builder 출력 verbatim — 다단락 가능>

## 4. 게이트 실행 기록

- check_brief.py gate — <pass|fail> (<YYYY-MM-DD>)

## 5. 프로세스 로그

- round <n>: <path (a|b|c|d)> — <한 줄 요약>
````

- [ ] **Step 3: 실패하는 테스트를 쓴다 — 새 포맷 정상 쌍 + 8/5 섹션 + audit 해석**

먼저 canonical 픽스처 쌍을 만든다. `plugins/spec-distill/tests/fixtures/interview-brief-valid.md`를 아래로 **전면 교체**:

````markdown
---
name: sample-topic
type: interview-brief
created_at: 2026-07-26
session_id: testsession01
source: spec-distill conducting-interview v0.23.0
next_phase: superpowers:brainstorming
audit_file: interview-brief-valid.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "대시보드는 SSR로 렌더한다"
    evidence: S1
  - id: D2
    source: chosen
    status: provisional
    statement: "캐시 계층은 인증 뷰까지 확장하지 않는다"
    evidence: S2
---

# Sample Topic — Interview Brief

## 0. 한눈에

TTFP를 줄이는 것이 진짜 목표다. SPA 전환은 수단이었지 목표가 아니었다.

## 1. Goal · Non-goal

- Goal: 대시보드 최초 페인트 시간 단축
- Non-goal: 전체 앱의 렌더링 전략 통일

## 2. 제약

이 절의 진술은 모델이 쓴 요약이다. 원문은 §6, `⟨S<N>⟩`가 그것을 가리킨다.

- 🗣 confirmed **C1** — 대시보드는 SSR로 렌더한다 ⟨S1⟩
- ☑ provisional **D2** — 캐시 계층은 인증 뷰까지 확장하지 않는다 ⟨S2⟩

✎ 렌더링 전략 선택이 이 토픽의 축으로 보인다 (모델 추론).

## 3. Open Questions

- OQ1: 인증 뷰의 캐시 전략 — 해답공간으로 이월.

## 4. External Landscape

- Next.js app-router SSR — https://nextjs.org/docs/app — [취함] — 데이터 형태와 부합

## 5. 기각 · Blind Spots

- 기각 — 전체 클라이언트 SPA → cold load에서 TTFP 회귀
- 기각 — islands architecture 우선 도입 → https://jasonformat.com/islands-architecture/ — verdict: defended — ST1
- 위험 — 숨은 가정 | SSR 호스트가 항상 저지연: cold start 시 TTFP 역전 — https://vercel.com/docs/functions

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S1** 🗣 최초 요청:
  > "대시보드가 너무 느려요. 서버에서 그려주면 안 되나요?"
- **S2** ☑ 선택 (캐시 범위):
  > "인증 뷰는 일단 빼고 갑시다"

## 7. Next Action

superpowers 있으면 이 brief를 context로 brainstorming 호출 → -design.md → reviewer → writing-plans.
````

그리고 `plugins/spec-distill/tests/fixtures/interview-brief-valid.audit.md` (신규):

````markdown
---
type: interview-audit
payload: interview-brief-valid.md
created_at: 2026-07-26
session_id: testsession01
source: spec-distill conducting-interview v0.23.0
---

# Sample Topic — Interview Audit

## 1. Coverage Ledger

- floor:root_problem — closed — §1 Goal (ROOT_CAUSE)
- floor:landscape — closed — §4 Next.js SSR 인용
- floor:skepticism — closed — §5 islands steelman defended
- floor:blind_spot — closed — §5 cold-start 위험
- floor:open_questions — closed — §3 OQ1
- derived:rendering-strategy — closed — SSR/islands 선택이 축; §5 근거

## 2. Budget

- probe_count: 7 / cap 12
- web_sweep_count: 3 / 4
- web_search_count: 3 / 8

## 3. Steelman 원문

#### ST1 — islands architecture가 full SSR보다 나을 수 있다

> 부분 하이드레이션은 인터랙티브 섬만 JS를 싣는다. 대시보드처럼 정적 비율이 높은 화면에서는
> full SSR + 전체 하이드레이션보다 TTI가 유리하다는 벤치마크가 있다.

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-07-26)

## 5. 프로세스 로그

- round 1: (d) ontological — ESSENCE로 진짜 목표 재구성
- round 2: (a) landscape sweep — Next.js SSR
- round 3: (b) judgment — 캐시 범위 선택
````

이제 `plugins/spec-distill/tests/test_check_brief.sh`의 헤더 주석과 앞부분을 교체한다. 파일 맨 위 1–16행을 아래로 바꾼다:

```bash
#!/usr/bin/env bash
# check_brief.py gate (v0.23.0 2파일 계약) — payload 8섹션 + audit 5섹션.
# T1/T2  — 각 섹션 제거 시 red (payload 8 / audit 5), 런타임 생성 픽스처.
# T7     — audit_file 부재 / traversal / 파일 부재 → red ×3 (fail-closed, AC9).
# T13    — Coverage Ledger가 audit에 없으면 red (AC10).
# T15    — 정상 쌍은 green (happy-path 스모크 — 이후 모든 태스크에서 green 유지).
# F3/F4/F5/F8/F9 — 기존 실패 클래스를 새 좌표로 이관.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/check_brief.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# 런타임 섹션-제거 픽스처용 임시 디렉토리.
# macOS bash 3.2: mktemp 대입 실패 시 빈 문자열이 `rm -rf`에 흘러가면 repo가 지워진다 → || exit 1 필수.
TMPD="$(mktemp -d)" || exit 1
[[ -n "$TMPD" && -d "$TMPD" ]] || exit 1
trap 'rm -rf "$TMPD"' EXIT

# T15: 정상 payload + audit 쌍 → green
python3 "$SCRIPT" gate "$FX/interview-brief-valid.md" >/dev/null 2>&1 \
  && note PASS "T15: 정상 payload+audit 쌍이 게이트를 통과" \
  || note FAIL "T15: 정상 쌍은 통과해야 한다"

# T1: payload 8섹션을 각각 제거 → red ×8
for hdr in "0. 한눈에" "1. Goal · Non-goal" "2. 제약" "3. Open Questions" \
           "4. External Landscape" "5. 기각 · Blind Spots" "6. 사용자 원문" "7. Next Action"; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  cp "$FX/interview-brief-valid.audit.md" "$TMPD/interview-brief-valid.audit.md"
  # 헤더 줄만 지운다 — 섹션 본문은 남겨 "헤더 존재 검사"가 실제로 이빨을 갖는지 본다.
  python3 - "$TMPD/p.md" "$hdr" <<'PY'
import sys, pathlib
p, hdr = pathlib.Path(sys.argv[1]), sys.argv[2]
lines = p.read_text(encoding="utf-8").splitlines(True)
p.write_text("".join(l for l in lines if l.strip() != f"## {hdr}"), encoding="utf-8")
PY
  python3 "$SCRIPT" gate "$TMPD/p.md" >/dev/null 2>&1 \
    && note FAIL "T1: payload §$hdr 제거가 통과됨" \
    || note PASS "T1: payload §$hdr 제거 → red"
done

# T2: audit 5섹션을 각각 제거 → red ×5
for hdr in "1. Coverage Ledger" "2. Budget" "3. Steelman 원문" "4. 게이트 실행 기록" "5. 프로세스 로그"; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  cp "$FX/interview-brief-valid.audit.md" "$TMPD/interview-brief-valid.audit.md"
  python3 - "$TMPD/interview-brief-valid.audit.md" "$hdr" <<'PY'
import sys, pathlib
p, hdr = pathlib.Path(sys.argv[1]), sys.argv[2]
lines = p.read_text(encoding="utf-8").splitlines(True)
p.write_text("".join(l for l in lines if l.strip() != f"## {hdr}"), encoding="utf-8")
PY
  python3 "$SCRIPT" gate "$TMPD/p.md" >/dev/null 2>&1 \
    && note FAIL "T2: audit §$hdr 제거가 통과됨" \
    || note PASS "T2: audit §$hdr 제거 → red"
done

# T7: audit_file 부재 / traversal / 파일 부재 → red ×3 (AC9 fail-closed)
cp "$FX/interview-brief-valid.audit.md" "$TMPD/interview-brief-valid.audit.md"
for variant in absent traversal missing; do
  cp "$FX/interview-brief-valid.md" "$TMPD/p.md"
  case "$variant" in
    absent)    sed -i.bak '/^audit_file:/d' "$TMPD/p.md" ;;
    traversal) sed -i.bak 's|^audit_file:.*|audit_file: ../interview-brief-valid.audit.md|' "$TMPD/p.md" ;;
    missing)   sed -i.bak 's|^audit_file:.*|audit_file: __no_such_audit__.md|' "$TMPD/p.md" ;;
  esac
  rm -f "$TMPD/p.md.bak"
  python3 "$SCRIPT" gate "$TMPD/p.md" >/dev/null 2>&1 \
    && note FAIL "T7/$variant: audit_file 결함이 통과됨 (fail-open)" \
    || note PASS "T7/$variant: audit_file 결함 → red"
done
```

기존 테스트의 나머지(F3/F4/F5/F8/F9 + landscape/skepticism/coverage 계열)는 Step 6에서 새 픽스처 이름으로 잇는다.

- [ ] **Step 4: 테스트를 돌려 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: **FAIL 다수** — 새 canonical 픽스처에 `locked_directions`가 없어 `frontmatter_errors`가 red를 내고, `SECTIONS`가 여전히 구 9섹션이라 T15부터 실패한다.

- [ ] **Step 5: `check_brief.py` 좌표·2파일 해석을 구현한다**

`plugins/spec-distill/scripts/check_brief.py`에서 `SECTIONS` 블록(50–60행)을 교체하고 헬퍼를 추가한다:

```python
SECTIONS = [
    ("0", "한눈에"),
    ("1", "Goal · Non-goal"),
    ("2", "제약"),
    ("3", "Open Questions"),
    ("4", "External Landscape"),
    ("5", "기각 · Blind Spots"),
    ("6", "사용자 원문"),
    ("7", "Next Action"),
]

# audit 섹션도 계약이다 — coverage_ledger_failures()와 steelman 대조가 섹션 번호+제목으로
# 본문을 잘라내므로, audit 쪽 번호가 바뀌면 검증이 조용히 빈 문자열을 읽고 통과한다.
AUDIT_SECTIONS = [
    ("1", "Coverage Ledger"),
    ("2", "Budget"),
    ("3", "Steelman 원문"),
    ("4", "게이트 실행 기록"),
    ("5", "프로세스 로그"),
]

FLOOR_KEYS = ["root_problem", "landscape", "skepticism", "blind_spot", "open_questions"]
```

`find_missing_sections`를 파라미터화한다(71–81행 교체):

```python
def find_missing_sections(text: str, sections: list = SECTIONS) -> list[str]:
    body = _body(text)
    missing = []
    for num, title in sections:
        pat = re.compile(
            rf"^##\s+{num}\.\s+{re.escape(title)}\b",
            re.MULTILINE | re.IGNORECASE,
        )
        if not pat.search(body):
            missing.append(f"{num}. {title}")
    return missing
```

frontmatter 헬퍼와 audit 해석을 `_entry_lines` 뒤에 추가한다:

```python
def _frontmatter(text: str) -> str:
    m = FRONTMATTER_RE.match(text)
    return m.group(1) if m else ""


AUDIT_FILE_RE = re.compile(r"^audit_file:\s*(\S+)\s*$", re.MULTILINE)


def resolve_audit(payload: Path, fm: str):
    """payload frontmatter의 audit_file을 해석한다 (AC9, fail-closed).

    audit_file은 신뢰 경계 밖 입력이므로 **basename만** 허용한다(P21 계보) — `../x.md`,
    `/etc/x.md`, `a/b.md`는 전부 Path(...).name != 원문이라 거부된다. 부재·미해석은
    전부 게이트 red이며, 조용히 payload-only 검사로 degrade하지 않는다(2파일 fail-open 봉쇄).
    """
    m = AUDIT_FILE_RE.search(fm)
    if not m:
        return None, "audit_file key absent"
    name = m.group(1).strip().strip('"').strip("'")
    if Path(name).name != name:
        return None, f"audit_file {name!r} is not a basename (traversal rejected)"
    p = payload.parent / name
    if not p.exists():
        return None, f"audit file not found: {name}"
    return p, None
```

- [ ] **Step 6: 좌표 의존 함수와 `gate()`를 새 계약으로 옮긴다**

같은 파일에서 아래를 교체한다.

`landscape_uncited` / `landscape_present`의 §3 → §4:

```python
def landscape_uncited(text: str) -> list[str]:
    if _web_disabled():
        return []  # web off → no URLs obtainable; citation requirement relaxed (AC8)
    sec = _section_text(text, "4", "External Landscape")
    return [ln for ln in _entry_lines(sec) if not URL_RE.search(ln)]


def landscape_present(text: str) -> bool:
    """§4 External Landscape must carry >=1 entry, OR an explicit web-disabled
    sentinel (AC8 graceful degradation). Header presence alone is not research (F3)."""
    sec = _section_text(text, "4", "External Landscape").strip()
    if not sec:
        return False
    if re.search(r"\bN/?A\b|비활성|생략|web[ -]?disabled", sec, re.IGNORECASE):
        return True
    return bool(_entry_lines(sec))
```

`steelman_unlogged()`(123–134행)를 **삭제**한다 — frontmatter `steelman:` 라벨이 `locked_directions`와 함께 사라지므로 이 함수는 영원히 0을 반환하는 죽은 코드가 된다. 그 보장은 Task 4의 bijection A가 이어받는다.

`skepticism_malformed` / `tried_discarded_ok`를 §5 좌표로 옮긴다(내용 강화는 Task 4):

```python
def section5_entries(text: str) -> list[str]:
    return _entry_lines(_section_text(text, "5", "기각 · Blind Spots"))


def skepticism_malformed(text: str) -> list[str]:
    """§5의 `verdict:` 항목 형식 검사. PN4: 정확한 문자열 일치가 아니라 containment."""
    require_url = not _web_disabled()
    bad: list[str] = []
    for ln in section5_entries(text):
        if "verdict:" not in ln:
            continue
        has_url = bool(URL_RE.search(ln))
        has_verdict = any(v in ln.lower() for v in VALID_VERDICTS)
        stripped = URL_RE.sub("", ln).lstrip("- ").strip()
        has_stmt = len(stripped) >= 10
        if not (has_verdict and has_stmt and (has_url or not require_url)):
            miss = []
            if not has_stmt:
                miss.append("statement<10c")
            if require_url and not has_url:
                miss.append("no-url")
            if not has_verdict:
                miss.append("no-verdict")
            bad.append(f"{ln[:60]} :: {','.join(miss)}")
    return bad


REJECT_NA_RE = re.compile(r"^-\s*기각\s*—\s*N/?A\b", re.IGNORECASE)


def tried_discarded_ok(text: str) -> bool:
    """R4 통과 의례 이관 — 구 §7 Tried & Discarded가 §5로 병합됐다.

    병합은 표현의 통합이지 의례의 폐기가 아니다: `기각` 항목이 0건이면 명시 N/A sentinel
    없이는 통과할 수 없다. steelman과 무관하게 사용자가 폐기한 방향도 여기 남는다.
    """
    rej = [ln for ln in section5_entries(text) if ln.lstrip("- ").startswith("기각")]
    sentinel = any(REJECT_NA_RE.match(ln) for ln in rej)
    real = [ln for ln in rej if not REJECT_NA_RE.match(ln)]
    return bool(real) or sentinel
```

`coverage_ledger_failures`의 섹션 좌표를 §6 → audit §1로 바꾼다(172행):

```python
    sec = _section_text(text, "1", "Coverage Ledger")
```

`frontmatter_errors`에서 `locked_directions` 요구(214–215행)를 `audit_file` + `user_sourced_items` 요구로 교체:

```python
    if not AUDIT_FILE_RE.search(fm):
        errs.append("audit_file key absent")
    if not re.search(r"^user_sourced_items\s*:", fm, re.MULTILINE):
        errs.append("user_sourced_items key absent")
```

`gate()`를 2파일로 재작성(219–259행 교체):

```python
def gate(path: Path) -> int:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"pass": False, "failures": [f"brief unreadable: {exc}"]},
                         ensure_ascii=False))
        return 1
    failures: list[str] = []
    fm = _frontmatter(text)

    miss = find_missing_sections(text)
    if miss:
        failures.append(f"missing payload sections: {miss}")
    fe = frontmatter_errors(text)
    if fe:
        failures.append(f"frontmatter: {fe}")

    # --- audit 해석 (fail-closed): 못 열면 audit 측 검증 전체를 skip하지 않고 red ---
    audit_path, audit_err = resolve_audit(path, fm)
    audit_text = ""
    if audit_err:
        failures.append(f"audit: {audit_err}")
    else:
        try:
            audit_text = audit_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            failures.append(f"audit unreadable: {exc}")
        else:
            amiss = find_missing_sections(audit_text, AUDIT_SECTIONS)
            if amiss:
                failures.append(f"missing audit sections: {amiss}")

    sec4_absent = any(m.startswith("4.") for m in miss)
    if not sec4_absent and not landscape_present(text):
        failures.append("External Landscape empty (no entries and no web-disabled sentinel)")
    unc = landscape_uncited(text)
    if unc:
        failures.append(f"uncited landscape entries: {len(unc)}")
    mal = skepticism_malformed(text)
    if mal:
        failures.append(f"malformed §5 verdict entries: {len(mal)}")

    sec5_absent = any(m.startswith("5.") for m in miss)
    if not sec5_absent and not tried_discarded_ok(text):
        failures.append("§5 기각 항목 0건 (N/A sentinel 없음)")

    # Coverage Ledger는 이제 audit에 산다 — audit을 못 열었으면 위에서 이미 red.
    if audit_text and not any(m.startswith("1.") for m in find_missing_sections(audit_text, AUDIT_SECTIONS)):
        cov = coverage_ledger_failures(audit_text)
        if cov:
            failures.append(f"coverage ledger: {cov}")

    ok = not failures
    print(json.dumps({"pass": ok, "failures": failures}, ensure_ascii=False))
    return 0 if ok else 1
```

CLI의 `coverage` 서브커맨드가 audit을 스스로 해석하도록 고친다(286–288행 교체):

```python
    if sub == "coverage":
        audit_path, audit_err = resolve_audit(path, _frontmatter(text))
        if audit_err:
            print(json.dumps({"failures": [audit_err]}, ensure_ascii=False))
            return 1
        audit_text = audit_path.read_text(encoding="utf-8")
        print(json.dumps({"failures": coverage_ledger_failures(audit_text)},
                         ensure_ascii=False))
        return 0
```

모듈 docstring(2–26행)의 서브커맨드 목록과 설명도 새 계약으로 갱신한다 — `gate <payload>`가 `audit_file`로 audit을 해석한다는 사실, `tried-discarded`가 §5를 본다는 사실을 명시.

- [ ] **Step 7: 기존 픽스처 15개를 새 좌표로 이관한다**

canonical(`interview-brief-valid.md`)에서 **한 줄씩만** 다르게 파생시킨다. 전부 `audit_file: interview-brief-valid.audit.md`를 그대로 쓴다(audit 결함 픽스처만 자기 audit을 갖는다).

```bash
cd plugins/spec-distill/tests/fixtures
for f in no-landscape empty-landscape unchallenged missing-section empty-tried na-tried \
         fenced-sections bad-frontmatter web-disabled missing-blind-spot; do
  cp interview-brief-valid.md "interview-brief-$f.md"
done
```

각각에 아래 편집을 적용한다:

| 픽스처 | 편집 | 잡는 것 |
|---|---|---|
| `no-landscape.md` | §4의 URL(` — https://nextjs.org/docs/app`)을 지운다 | R2/AC4 무인용 landscape |
| `empty-landscape.md` | §4의 항목 줄 전체를 지운다(헤더만 남김) | F3 헤더≠연구 |
| `unchallenged.md` | §5의 `verdict: defended` 줄에서 URL과 `verdict: defended`를 지운다 | R3/AC5 형식 미달 |
| `missing-section.md` | `## 3. Open Questions` 헤더 줄을 지운다 | AC2 섹션 부재 |
| `empty-tried.md` | §5의 `기각` 두 줄을 지운다(`위험` 줄만 남김) | R4 기각 0건 |
| `na-tried.md` | §5의 `기각` 두 줄을 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄로 교체 | R4 sentinel |
| `fenced-sections.md` | 본문 전체를 ` ``` ` 펜스로 감싼다(헤더가 코드블록 안에만 있게) | F4 |
| `bad-frontmatter.md` | `type: interview-brief` → `type: spec`, `next_phase:` 줄 삭제 | AC1 frontmatter |
| `web-disabled.md` | §4·§5의 모든 URL을 지운다 | AC8 kill switch 대칭 |
| `missing-blind-spot.md` | `## 5. 기각 · Blind Spots` 헤더 줄을 지운다 | §5 부재 |

audit 결함 픽스처 4쌍(구 coverage 계열 이관)은 payload + 전용 audit을 함께 만든다:

```bash
for f in floor-open floor-evidence-empty missing-derived-row derived-sentinel audit-no-coverage; do
  cp interview-brief-valid.md "interview-brief-$f.md"
  cp interview-brief-valid.audit.md "interview-brief-$f.audit.md"
  sed -i.bak "s|^audit_file:.*|audit_file: interview-brief-$f.audit.md|" "interview-brief-$f.md"
  rm -f "interview-brief-$f.md.bak"
done
```

| audit 픽스처 | 편집 |
|---|---|
| `floor-open.audit.md` | §1의 `floor:landscape — closed` → `floor:landscape — open` |
| `floor-evidence-empty.audit.md` | §1의 `floor:skepticism — closed — <evidence>`에서 evidence를 지워 `- floor:skepticism — closed — ` 로 |
| `missing-derived-row.audit.md` | §1의 `derived:rendering-strategy` 줄 삭제 |
| `derived-sentinel.audit.md` | 같은 줄을 `- derived: N/A`로 교체 |
| `audit-no-coverage.audit.md` | §1의 항목 줄 전체 삭제(헤더만) — T13 |

구 `interview-brief-steelman-unlogged.md`와 `interview-brief-web-disabled-blind-spot.md`는 삭제한다 — 전자의 보장(frontmatter steelman 주장 ↔ 로그)은 Task 4의 bijection A가, 후자는 `web-disabled.md` 하나가 대체한다.

```bash
git rm plugins/spec-distill/tests/fixtures/interview-brief-steelman-unlogged.md \
       plugins/spec-distill/tests/fixtures/interview-brief-web-disabled-blind-spot.md
```

- [ ] **Step 8: 기존 테스트 assert를 새 픽스처·좌표로 잇는다**

`tests/test_check_brief.sh`의 Step 3에서 남겨둔 아래쪽(구 F3–F9 + coverage 블록)을 아래로 교체한다:

```bash
# R2/AC4: 무인용 landscape → red
python3 "$SCRIPT" gate "$FX/interview-brief-no-landscape.md" >/dev/null 2>&1 \
  && note FAIL "무인용 landscape가 통과됨 (R2/AC4)" \
  || note PASS "무인용 landscape가 종료를 차단 (R2/AC4)"

# F3: §4 헤더만 있고 항목 없음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-empty-landscape.md" >/dev/null 2>&1 \
  && note FAIL "F3: 빈 External Landscape가 통과됨" \
  || note PASS "F3: 빈 External Landscape가 종료를 차단"

# R3/AC5: §5 verdict 항목 형식 미달 → red
python3 "$SCRIPT" gate "$FX/interview-brief-unchallenged.md" >/dev/null 2>&1 \
  && note FAIL "형식 미달 verdict 항목이 통과됨 (R3/AC5)" \
  || note PASS "형식 미달 verdict 항목이 종료를 차단 (R3/AC5)"

# PN4: containment 검사가 누락 URL을 지목
python3 "$SCRIPT" skepticism "$FX/interview-brief-unchallenged.md" 2>/dev/null | grep -q 'no-url' \
  && note PASS "PN4: skepticism containment가 누락 URL을 플래그" \
  || note FAIL "PN4: skepticism containment가 누락 URL을 못 잡음"

# AC2: 섹션 부재 → red
python3 "$SCRIPT" gate "$FX/interview-brief-missing-section.md" >/dev/null 2>&1 \
  && note FAIL "섹션 부재가 통과됨 (AC2)" || note PASS "섹션 부재가 종료를 차단 (AC2)"
python3 "$SCRIPT" gate "$FX/interview-brief-missing-blind-spot.md" >/dev/null 2>&1 \
  && note FAIL "§5 부재가 통과됨" || note PASS "§5 부재가 종료를 차단"

# T19 / R4: §5 기각 0건 → red, N/A sentinel → green
python3 "$SCRIPT" gate "$FX/interview-brief-empty-tried.md" >/dev/null 2>&1 \
  && note FAIL "T19: 기각 0건 + sentinel 없음이 통과됨 (R4 증발)" \
  || note PASS "T19: 기각 0건 + sentinel 없음 → red (R4 이관 확인)"
python3 "$SCRIPT" gate "$FX/interview-brief-na-tried.md" >/dev/null 2>&1 \
  && note PASS "T19: 기각 N/A sentinel → green (R4 edge)" \
  || note FAIL "T19: N/A sentinel은 통과해야 한다"

# F4: 펜스 안 헤더는 게이트를 만족시키지 못한다
python3 "$SCRIPT" gate "$FX/interview-brief-fenced-sections.md" >/dev/null 2>&1 \
  && note FAIL "F4: 펜스 안 섹션 헤더가 통과됨" || note PASS "F4: 펜스 안 헤더는 불충분"

# F5: 읽을 수 없는 brief → 구조화 JSON + exit 1, traceback 금지
out="$(python3 "$SCRIPT" gate "$FX/__no_such_brief__.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '"pass": false'; } \
  && note PASS "F5: 읽기 실패 → 구조화 JSON + exit 1" \
  || note FAIL "F5: 읽기 실패는 구조화 JSON이어야 한다"
printf '%s' "$out" | grep -qi 'Traceback' \
  && note FAIL "F5: traceback이 stdout으로 샜다" || note PASS "F5: traceback 누출 없음"

# F9-A: frontmatter 검증 실패 클래스
python3 "$SCRIPT" gate "$FX/interview-brief-bad-frontmatter.md" >/dev/null 2>&1 \
  && note FAIL "F9-A: 잘못된 frontmatter가 통과됨 (AC1)" \
  || note PASS "F9-A: 잘못된 frontmatter가 종료를 차단 (AC1)"

# F8/AC8: web 켜짐 → URL 없는 §4/§5는 red / kill switch → 완화
python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled.md" >/dev/null 2>&1 \
  && note FAIL "F8: web 켜짐 상태에서 URL 없는 항목이 통과됨" \
  || note PASS "F8: web 켜짐 상태에서 URL 없는 항목이 차단됨"
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled.md" >/dev/null 2>&1 \
  && note PASS "AC8: web 비활성 시 URL 요구 완화" \
  || note FAIL "AC8: web 비활성 시 URL 요구가 완화돼야 한다"

# AC10 / C9: Coverage Ledger는 audit에서 검증된다
python3 "$SCRIPT" gate "$FX/interview-brief-floor-open.md" >/dev/null 2>&1 \
  && note FAIL "AC10: floor open이 통과됨" || note PASS "AC10: floor open이 차단됨"
python3 "$SCRIPT" gate "$FX/interview-brief-floor-evidence-empty.md" >/dev/null 2>&1 \
  && note FAIL "AC10: floor evidence 공백이 통과됨" || note PASS "AC10: floor evidence 공백이 차단됨"
python3 "$SCRIPT" gate "$FX/interview-brief-missing-derived-row.md" >/dev/null 2>&1 \
  && note FAIL "C9: derived 행·sentinel 부재가 통과됨" || note PASS "C9: derived 부재가 차단됨"
python3 "$SCRIPT" gate "$FX/interview-brief-derived-sentinel.md" >/dev/null 2>&1 \
  && note PASS "C9: derived N/A sentinel → green" || note FAIL "C9: derived sentinel은 통과해야 한다"

# T13: audit §1 Coverage Ledger가 비어 있음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-audit-no-coverage.md" >/dev/null 2>&1 \
  && note FAIL "T13: 빈 audit Coverage Ledger가 통과됨" \
  || note PASS "T13: 빈 audit Coverage Ledger → red (AC10)"

# coverage 서브커맨드가 audit을 스스로 해석
python3 "$SCRIPT" coverage "$FX/interview-brief-floor-open.md" 2>/dev/null | grep -q 'floor:landscape' \
  && note PASS "coverage 서브커맨드가 audit을 해석해 열린 floor를 플래그" \
  || note FAIL "coverage 서브커맨드가 열린 floor를 플래그해야 한다"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 9: 테스트를 돌려 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: PASS — `Total: 39 | Pass: 39 | Fail: 0` (T15 1 + T1 8 + T2 5 + T7 3 + 이관 22).

회귀 확인: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh` → 77/77 green (아직 SKILL.md를 안 건드렸으므로 불변).

- [ ] **Step 10: 커밋**

```bash
git add plugins/spec-distill/templates/ plugins/spec-distill/scripts/check_brief.py \
        plugins/spec-distill/tests/fixtures/ plugins/spec-distill/tests/test_check_brief.sh
git commit -m "feat(spec-distill): brief 8섹션 payload + audit 2파일 게이트 골격 (T1/T2/T7/T13/T15)"
```

---

## Task 2: `user_sourced_items` 스키마 + bijection C + confirmed sentinel

frontmatter 계약을 집행한다. `inferred`가 리스트에 들어오지 못하고, 모든 항목이 `evidence`를 갖고, 그 `evidence`가 §6에서 해석된다.

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Create: `plugins/spec-distill/tests/fixtures/interview-brief-{no-items,item-no-evidence,item-inferred,item-bad-status,item-bad-source,evidence-dangling,statement-161,statement-160,confirmed-zero,confirmed-zero-sentinel}.md`
- Test: `plugins/spec-distill/tests/test_check_brief.sh`

**Interfaces:**
- Consumes: `_frontmatter(text) -> str`, `_section_text(text, num, title) -> str`, `gate(path) -> int` (Task 1)
- Produces:
  - `parse_user_sourced_items(fm: str) -> list[dict]` — 각 dict는 `{"id","source","status","statement","evidence"}` 부분집합
  - `user_sourced_errors(text: str) -> list[str]`
  - `verbatim_anchors(text: str) -> set[str]` — §6의 `S<N>` 앵커 집합
  - `bijection_c_errors(text: str) -> list[str]`
  - `confirmed_zero_unsentineled(text: str) -> bool`
  - 상수 `VALID_SOURCES`, `VALID_STATUSES`, `REQUIRED_ITEM_FIELDS`, `STATEMENT_MAX = 160`, `CONFIRMED_SENTINEL`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

픽스처를 canonical에서 파생시킨다:

```bash
cd plugins/spec-distill/tests/fixtures
for f in no-items item-no-evidence item-inferred item-bad-status item-bad-source \
         evidence-dangling statement-161 statement-160 confirmed-zero confirmed-zero-sentinel; do
  cp interview-brief-valid.md "interview-brief-$f.md"
done
```

각 편집 (전부 frontmatter만 손대고, bijection B는 Task 3에서 켜지므로 body는 필요한 곳만 맞춘다):

| 픽스처 | frontmatter 편집 | body 동반 편집 |
|---|---|---|
| `no-items.md` | `user_sourced_items:` 블록 전체 삭제 | §2의 🗣/☑ 두 줄 삭제 |
| `item-no-evidence.md` | `C1`의 `evidence: S1` 줄 삭제 | §2 `C1` 줄의 ` ⟨S1⟩` 삭제 |
| `item-inferred.md` | `C1`의 `source: verbatim` → `source: inferred` | — |
| `item-bad-status.md` | `C1`의 `status: confirmed` → `status: locked` | §2 `C1` 줄의 `confirmed` → `locked` |
| `item-bad-source.md` | `D2`의 `source: chosen` → `source: 사용자` | — |
| `evidence-dangling.md` | `D2`의 `evidence: S2` → `evidence: S9` | §2 `D2` 줄의 `⟨S2⟩` → `⟨S9⟩` |
| `statement-161.md` | `C1`의 statement를 정확히 161자로 | §2 `C1` 줄도 같은 161자로 |
| `statement-160.md` | `C1`의 statement를 정확히 160자로 | §2 `C1` 줄도 같은 160자로 |
| `confirmed-zero.md` | `C1`의 `status: confirmed` → `status: provisional` | §2 `C1` 줄도 `provisional` |
| `confirmed-zero-sentinel.md` | 위와 같게 하고 `user_sourced_items:` 줄 **바로 위**에 `# confirmed 0건 — 사용자가 전부 잠정으로 판단` 추가 | 같음 |

160/161자 statement는 아래로 생성한다(정확한 길이 보장):

```bash
python3 - <<'PY'
import pathlib, re
fx = pathlib.Path("plugins/spec-distill/tests/fixtures")
for n in (160, 161):
    s = "대시보드는 SSR로 렌더한다. " + "가" * (n - len("대시보드는 SSR로 렌더한다. "))
    assert len(s) == n, len(s)
    p = fx / f"interview-brief-statement-{n}.md"
    t = p.read_text(encoding="utf-8")
    t = t.replace('statement: "대시보드는 SSR로 렌더한다"', f'statement: "{s}"')
    t = t.replace("**C1** — 대시보드는 SSR로 렌더한다 ⟨S1⟩", f"**C1** — {s} ⟨S1⟩")
    p.write_text(t, encoding="utf-8")
    print(p.name, n)
PY
```

`tests/test_check_brief.sh`의 마지막 `echo`/`Total` 블록 **앞에** 추가:

```bash
# --- Task 2: user_sourced_items 스키마 + bijection C + confirmed sentinel ---

# T3: user_sourced_items 부재 → red
python3 "$SCRIPT" gate "$FX/interview-brief-no-items.md" >/dev/null 2>&1 \
  && note FAIL "T3: user_sourced_items 부재가 통과됨" || note PASS "T3: user_sourced_items 부재 → red"

# T4: evidence 없음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-item-no-evidence.md" >/dev/null 2>&1 \
  && note FAIL "T4: evidence 없는 항목이 통과됨" || note PASS "T4: evidence 없는 항목 → red"

# T5: source: inferred가 리스트에 있음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-item-inferred.md" >/dev/null 2>&1 \
  && note FAIL "T5: source: inferred가 통과됨 (리스트 이름과 내용 불일치)" \
  || note PASS "T5: source: inferred → red"

# T6: 잘못된 status / source → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-item-bad-status.md" >/dev/null 2>&1 \
  && note FAIL "T6: 잘못된 status가 통과됨" || note PASS "T6: 잘못된 status → red"
python3 "$SCRIPT" gate "$FX/interview-brief-item-bad-source.md" >/dev/null 2>&1 \
  && note FAIL "T6: 잘못된 source가 통과됨" || note PASS "T6: 잘못된 source → red"

# T22: bijection C — evidence: S9인데 §6에 S9 없음 → red
python3 "$SCRIPT" gate "$FX/interview-brief-evidence-dangling.md" >/dev/null 2>&1 \
  && note FAIL "T22: dangling evidence가 통과됨 (bijection C 미집행)" \
  || note PASS "T22: dangling evidence → red (bijection C)"

# T23: statement 161자 → red / 160자 → green (hard cap)
python3 "$SCRIPT" gate "$FX/interview-brief-statement-161.md" >/dev/null 2>&1 \
  && note FAIL "T23: 161자 statement가 통과됨 (cap이 hard가 아님)" \
  || note PASS "T23: 161자 statement → red"
python3 "$SCRIPT" gate "$FX/interview-brief-statement-160.md" >/dev/null 2>&1 \
  && note PASS "T23: 160자 statement → green (경계 포함)" \
  || note FAIL "T23: 160자는 통과해야 한다 (off-by-one)"

# T14: confirmed 0건 + sentinel 없음 → red / 있음 → green
python3 "$SCRIPT" gate "$FX/interview-brief-confirmed-zero.md" >/dev/null 2>&1 \
  && note FAIL "T14: confirmed 0건 + sentinel 없음이 통과됨 (확인 게이트 우회)" \
  || note PASS "T14: confirmed 0건 + sentinel 없음 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-confirmed-zero-sentinel.md" >/dev/null 2>&1 \
  && note PASS "T14: confirmed 0건 + sentinel → green" \
  || note FAIL "T14: sentinel이 있으면 통과해야 한다"
```

- [ ] **Step 2: 테스트를 돌려 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: FAIL — T3만 우연히 통과(`frontmatter_errors`의 `user_sourced_items key absent`), 나머지 T4/T5/T6/T22/T23/T14는 검사기가 없어 전부 green이 나와 FAIL로 기록된다.

- [ ] **Step 3: frontmatter 항목 파서를 구현한다**

`check_brief.py`의 `resolve_audit` 뒤에 추가:

```python
VALID_SOURCES = ("verbatim", "chosen")
VALID_STATUSES = ("confirmed", "provisional", "open")
REQUIRED_ITEM_FIELDS = ("id", "source", "status", "statement", "evidence")
STATEMENT_MAX = 160
CONFIRMED_SENTINEL = "# confirmed 0건 — 사용자가 전부 잠정으로 판단"

ITEMS_KEY_RE = re.compile(r"^user_sourced_items\s*:", re.MULTILINE)
ITEM_START_RE = re.compile(r"^\s*-\s+id:\s*(\S+)\s*$")
ITEM_FIELD_RE = re.compile(r"^\s+(\w+):\s*(.*?)\s*$")
ITEM_BULLET_RE = re.compile(r"^\s*-\s")
EVIDENCE_RE = re.compile(r"^S\d+$")


def parse_user_sourced_items(fm: str):
    """frontmatter의 user_sourced_items 블록을 손으로 파싱한다.

    PyYAML을 쓰지 않는 이유: 이 플러그인의 어떤 스크립트도 third-party import를 하지
    않는다 — 훅은 임의 사용자 환경에서 실행되고, 게이트가 ImportError로 죽으면 Law 1
    구조 게이트가 통째로 fail-open된다.

    반환: (items, raw_bullets). raw_bullets는 블록 안 `- ` 줄 수로, items와 개수가
    다르면 파서-포맷 불일치이므로 호출자가 fail-closed로 처리한다(인라인 dict 형식 등).
    """
    lines = fm.splitlines()
    start = None
    for i, ln in enumerate(lines):
        if ITEMS_KEY_RE.match(ln):
            start = i
            break
    if start is None:
        return [], 0
    items = []
    raw = 0
    cur = None
    for ln in lines[start + 1:]:
        if ln.strip() and not ln[0].isspace():
            break  # 다음 최상위 키 → 블록 종료
        if ITEM_BULLET_RE.match(ln):
            raw += 1
        m = ITEM_START_RE.match(ln)
        if m:
            cur = {"id": m.group(1).strip().strip('"').strip("'")}
            items.append(cur)
            continue
        if cur is None:
            continue
        f = ITEM_FIELD_RE.match(ln)
        if f:
            cur[f.group(1)] = f.group(2).strip().strip('"').strip("'")
    return items, raw


def user_sourced_errors(text: str) -> list[str]:
    """user_sourced_items 스키마 검증 (AC6)."""
    fm = _frontmatter(text)
    if not ITEMS_KEY_RE.search(fm):
        return ["user_sourced_items key absent"]
    items, raw = parse_user_sourced_items(fm)
    errs: list[str] = []
    if raw != len(items):
        errs.append(f"user_sourced_items unparseable ({raw} bullets, {len(items)} parsed)")
    seen = set()
    for it in items:
        iid = it.get("id") or "<no-id>"
        if iid in seen:
            errs.append(f"{iid}: duplicate id")
        seen.add(iid)
        for field in REQUIRED_ITEM_FIELDS:
            if not it.get(field):
                errs.append(f"{iid}: {field} missing")
        src = it.get("source")
        if src and src not in VALID_SOURCES:
            # `inferred`는 이 리스트에 들어올 수 없다 — 모델 추론은 본문 ✎ 프로즈로만 산다.
            errs.append(f"{iid}: source {src!r} not in {VALID_SOURCES}")
        st = it.get("status")
        if st and st not in VALID_STATUSES:
            errs.append(f"{iid}: status {st!r} not in {VALID_STATUSES}")
        stmt = it.get("statement") or ""
        if len(stmt) > STATEMENT_MAX:
            errs.append(f"{iid}: statement {len(stmt)}자 > {STATEMENT_MAX} (hard cap)")
        ev = it.get("evidence") or ""
        if ev and not EVIDENCE_RE.match(ev):
            errs.append(f"{iid}: evidence {ev!r} is not S<N>")
    return errs


def confirmed_zero_unsentineled(text: str) -> bool:
    """빈 확정 금지 (AC12) — sentinel 없는 confirmed 0건은 확인 게이트를 건너뛴 신호다."""
    fm = _frontmatter(text)
    items, _ = parse_user_sourced_items(fm)
    if any(it.get("status") == "confirmed" for it in items):
        return False
    return CONFIRMED_SENTINEL not in fm
```

- [ ] **Step 4: bijection C를 구현한다**

같은 파일에 추가:

```python
S_ANCHOR_RE = re.compile(r"^\s*-\s+\*\*(S\d+)\*\*", re.MULTILINE)


def verbatim_anchors(text: str) -> set:
    """§6 사용자 원문이 제공하는 S<N> 앵커 집합."""
    return set(S_ANCHOR_RE.findall(_section_text(text, "6", "사용자 원문")))


def bijection_c_errors(text: str) -> list[str]:
    """bijection C — 모든 evidence: S<N>이 §6에서 해석된다 (AC6).

    한계: 이 검사는 인용된 S<N>의 **존재**만 본다. 요약이 그 원문을 실제로 뒷받침하는지
    (의미적 정합)는 기계 검증하지 않는다 — V9 수동 spot-check가 그 갭을 맡는다.
    역방향(모든 S<N>이 인용될 것)은 요구하지 않는다: 제약으로 승격되지 않은 발화가 있다.
    """
    anchors = verbatim_anchors(text)
    items, _ = parse_user_sourced_items(_frontmatter(text))
    errs = []
    for it in items:
        ev = it.get("evidence")
        if ev and EVIDENCE_RE.match(ev) and ev not in anchors:
            errs.append(f"{it.get('id')}: evidence {ev} not found in §6")
    return errs
```

- [ ] **Step 5: `gate()`에 연결한다**

`gate()`의 `frontmatter: {fe}` 블록 바로 뒤에 삽입:

```python
    ue = user_sourced_errors(text)
    if ue:
        failures.append(f"user_sourced_items: {ue}")
    if confirmed_zero_unsentineled(text):
        failures.append("confirmed 0건인데 명시 sentinel 없음 (확인 게이트 우회 신호)")
    sec6_absent = any(m.startswith("6.") for m in miss)
    if not sec6_absent:
        ce = bijection_c_errors(text)
        if ce:
            failures.append(f"bijection C (evidence→§6): {ce}")
```

CLI에 서브커맨드를 추가한다(`if sub == "frontmatter":` 블록 뒤):

```python
    if sub == "items":
        print(json.dumps({"errors": user_sourced_errors(text),
                          "bijection_c": bijection_c_errors(text)}, ensure_ascii=False))
        return 0
```

모듈 docstring의 서브커맨드 목록에 `check_brief.py items <brief> → {"errors": [...], "bijection_c": [...]}  (AC6)`를 추가한다.

- [ ] **Step 6: 테스트를 돌려 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: PASS — `Total: 50 | Pass: 50 | Fail: 0`. T15가 여전히 green인지 특히 확인한다(정상 쌍 회귀 카나리아).

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/
git commit -m "feat(spec-distill): user_sourced_items 스키마 + bijection C + confirmed sentinel (T3-T6/T14/T22/T23)"
```

---

## Task 3: bijection B — body §2 ↔ frontmatter

안전-critical 축이다. id·기호·status·evidence·**statement 내용**까지 대조해야 ☑ laundering과 라벨-내용 drift가 막힌다. 메타데이터만 맞추면 두 표현이 같은 라벨을 달고 서로 다른 제약을 말해도 통과한다.

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Create: `plugins/spec-distill/tests/fixtures/interview-brief-{body-only-id,fm-only-id,marker-mismatch,status-mismatch,statement-drift,statement-whitespace,anchor-mismatch,anchor-absent,body-malformed}.md`
- Test: `plugins/spec-distill/tests/test_check_brief.sh`

**Interfaces:**
- Consumes: `parse_user_sourced_items(fm) -> (list[dict], int)`, `_section_text`, `_frontmatter` (Task 1–2)
- Produces:
  - `bijection_b_errors(text: str) -> list[str]`
  - `MARKER_SOURCE: dict[str, str]` — `{"🗣": "verbatim", "☑": "chosen"}`
  - `_norm_stmt(s: str) -> str` — 정규화(앞뒤 공백 · 연속 공백 축약 · `**`/`*`/`` ` `` 제거)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```bash
cd plugins/spec-distill/tests/fixtures
for f in body-only-id fm-only-id marker-mismatch status-mismatch statement-drift \
         statement-whitespace anchor-mismatch anchor-absent body-malformed; do
  cp interview-brief-valid.md "interview-brief-$f.md"
done
```

| 픽스처 | 편집 |
|---|---|
| `body-only-id.md` | §2에 `- ☑ provisional **E3** — 세 번째 제약 ⟨S2⟩` 한 줄 추가 (frontmatter에는 없음) |
| `fm-only-id.md` | §2의 `D2` 줄 삭제 (frontmatter에는 남김) |
| `marker-mismatch.md` | §2 `D2` 줄의 `☑` → `🗣` (frontmatter는 `chosen` 유지) |
| `status-mismatch.md` | §2 `D2` 줄의 `provisional` → `confirmed` (frontmatter는 `provisional` 유지) |
| `statement-drift.md` | §2 `D2` 줄의 statement를 `캐시 계층을 인증 뷰까지 확장한다`로 (의미 반전, frontmatter 불변) |
| `statement-whitespace.md` | §2 `C1` 줄의 statement를 `대시보드는  **SSR**로   렌더한다`로 (공백·강조만 다름) → **green 기대** |
| `anchor-mismatch.md` | §2 `C1` 줄의 `⟨S1⟩` → `⟨S2⟩` (frontmatter evidence는 `S1`) |
| `anchor-absent.md` | §2 `C1` 줄에서 ` ⟨S1⟩` 삭제 |
| `body-malformed.md` | §2 `C1` 줄을 `- 🗣 confirmed C1 — 대시보드는 SSR로 렌더한다 ⟨S1⟩`로 (id 강조 `**` 없음) |

테스트 추가(마지막 `echo` 앞):

```bash
# --- Task 3: bijection B (body §2 ↔ frontmatter) ---

# T8: 한쪽에만 있는 id → red ×2 (양방향)
python3 "$SCRIPT" gate "$FX/interview-brief-body-only-id.md" >/dev/null 2>&1 \
  && note FAIL "T8: body §2에만 있는 id가 통과됨" || note PASS "T8: body-only id → red"
python3 "$SCRIPT" gate "$FX/interview-brief-fm-only-id.md" >/dev/null 2>&1 \
  && note FAIL "T8: frontmatter에만 있는 id가 통과됨" || note PASS "T8: frontmatter-only id → red"

# T9: 기호↔source / status 불일치 → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-marker-mismatch.md" >/dev/null 2>&1 \
  && note FAIL "T9: 기호↔source 불일치가 통과됨 (☑ laundering)" || note PASS "T9: 기호↔source 불일치 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-status-mismatch.md" >/dev/null 2>&1 \
  && note FAIL "T9: status 불일치가 통과됨" || note PASS "T9: status 불일치 → red"

# T21: statement 내용 drift → red / 공백·강조기호만 다름 → green
python3 "$SCRIPT" gate "$FX/interview-brief-statement-drift.md" >/dev/null 2>&1 \
  && note FAIL "T21: statement 내용 drift가 통과됨 (같은 라벨, 다른 제약)" \
  || note PASS "T21: statement 내용 drift → red"
python3 "$SCRIPT" gate "$FX/interview-brief-statement-whitespace.md" >/dev/null 2>&1 \
  && note PASS "T21: 공백·강조기호 차이는 정규화로 흡수 → green" \
  || note FAIL "T21: 정규화가 공백·강조 차이를 흡수해야 한다"

# T24: ⟨S<N>⟩ 불일치 / 접미 부재 → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-anchor-mismatch.md" >/dev/null 2>&1 \
  && note FAIL "T24: ⟨S<N>⟩ 불일치가 통과됨" || note PASS "T24: ⟨S<N>⟩ 불일치 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-anchor-absent.md" >/dev/null 2>&1 \
  && note FAIL "T24: ⟨S<N>⟩ 접미 부재가 통과됨 (요약 신호 소실)" || note PASS "T24: ⟨S<N>⟩ 부재 → red"

# 형식 미달 §2 항목은 조용히 사라지지 않고 loud하게 red가 된다
python3 "$SCRIPT" gate "$FX/interview-brief-body-malformed.md" >/dev/null 2>&1 \
  && note FAIL "형식 미달 §2 항목이 통과됨 (silent drop)" || note PASS "형식 미달 §2 항목 → red (loud)"
```

- [ ] **Step 2: 테스트를 돌려 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: FAIL — `anchor-absent`만 우연히 통과할 수 있고(§2 문법 미검증), T8/T9/T21/T24와 malformed는 검사기가 없어 전부 green → FAIL 기록.

- [ ] **Step 3: bijection B를 구현한다**

`check_brief.py`의 `bijection_c_errors` 뒤에 추가:

```python
MARKER_SOURCE = {"🗣": "verbatim", "☑": "chosen"}

# `- 🗣 confirmed **C1** — <statement> ⟨S3⟩`
BODY_ITEM_RE = re.compile(
    r"^\s*-\s+(🗣|☑)\s+(\S+)\s+\*\*([^*]+)\*\*\s+—\s+(.*?)\s+⟨(S\d+)⟩\s*$"
)
# 기호로 시작하지만 위 문법에 맞지 않는 줄을 잡아내기 위한 느슨한 매처.
# 이게 없으면 오타 한 글자가 항목을 id 집합에서 조용히 지워 "frontmatter-only id"라는
# 엉뚱한 메시지로 나타난다 — 원인과 증상이 어긋나면 디버깅이 배로 든다.
BODY_ITEM_LOOSE_RE = re.compile(r"^\s*-\s+(?:🗣|☑)\s")
EMPH_RE = re.compile(r"[*`]")


def _norm_stmt(s: str) -> str:
    """정규화 = 앞뒤 공백 제거 + 연속 공백 1개로 축약 + 마크다운 강조 기호 제거."""
    return re.sub(r"\s+", " ", EMPH_RE.sub("", s)).strip()


def bijection_b_errors(text: str) -> list[str]:
    """bijection B — body §2 ↔ frontmatter (AC7).

    frontmatter가 canonical이고 body는 그 렌더다. id·기호·status·evidence만 맞추면
    두 표현이 같은 라벨을 달고 **서로 다른 제약을 말해도** 통과하므로 statement 내용까지
    정규화 후 대조한다. ✎ 항목은 이 문법을 쓰지 않으므로(프로즈 주석) 대상이 아니다.
    """
    items = {}
    for it in parse_user_sourced_items(_frontmatter(text))[0]:
        if it.get("id"):
            items[it["id"]] = it
    errs: list[str] = []
    body = {}
    for ln in _section_text(text, "2", "제약").splitlines():
        if not BODY_ITEM_LOOSE_RE.match(ln):
            continue
        m = BODY_ITEM_RE.match(ln)
        if not m:
            errs.append(f"malformed §2 item: {ln.strip()[:60]}")
            continue
        marker, status, iid, stmt, ev = m.groups()
        if iid in body:
            errs.append(f"{iid}: duplicate §2 item")
        body[iid] = {"marker": marker, "status": status, "statement": stmt, "evidence": ev}
    for iid in sorted(set(body) - set(items)):
        errs.append(f"{iid}: in body §2 but not in frontmatter")
    for iid in sorted(set(items) - set(body)):
        errs.append(f"{iid}: in frontmatter but not in body §2")
    for iid in sorted(set(body) & set(items)):
        b, f = body[iid], items[iid]
        if MARKER_SOURCE.get(b["marker"]) != f.get("source"):
            errs.append(f"{iid}: body marker {b['marker']} != frontmatter source {f.get('source')!r}")
        if b["status"] != f.get("status"):
            errs.append(f"{iid}: body status {b['status']!r} != frontmatter {f.get('status')!r}")
        if b["evidence"] != f.get("evidence"):
            errs.append(f"{iid}: body ⟨{b['evidence']}⟩ != frontmatter evidence {f.get('evidence')!r}")
        if _norm_stmt(b["statement"]) != _norm_stmt(f.get("statement") or ""):
            errs.append(f"{iid}: body statement != frontmatter statement (정규화 후)")
    return errs
```

- [ ] **Step 4: `gate()`와 CLI에 연결한다**

`gate()`의 bijection C 블록 뒤에 삽입:

```python
    sec2_absent = any(m.startswith("2.") for m in miss)
    if not sec2_absent:
        be = bijection_b_errors(text)
        if be:
            failures.append(f"bijection B (body §2↔frontmatter): {be}")
```

CLI `items` 서브커맨드의 출력에 `"bijection_b": bijection_b_errors(text)`를 추가하고, 모듈 docstring도 함께 갱신한다.

- [ ] **Step 5: 테스트를 돌려 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: PASS — `Total: 59 | Pass: 59 | Fail: 0`.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/
git commit -m "feat(spec-distill): bijection B — body §2 statement까지 frontmatter와 대조 (T8/T9/T21/T24)"
```

---

## Task 4: bijection A + §5 verdict 강화 + 표기 블록

파일 축 drift-guard다. payload가 남으면 *원문 없는 판정*(근거 증발), audit이 남으면 *판정 없는 steelman*(R3 미충족) — 양방향 모두 결함이다.

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Create: `plugins/spec-distill/tests/fixtures/interview-brief-{st-orphan-payload,st-orphan-audit,steelman-empty,verdict-no-url,verdict-no-token,verdict-short,verdict-no-st,no-attribution,attribution-partial}.md` (+ 앞의 셋은 `.audit.md` 동반)
- Test: `plugins/spec-distill/tests/test_check_brief.sh`

**Interfaces:**
- Consumes: `section5_entries(text) -> list[str]`, `resolve_audit`, `_section_text` (Task 1)
- Produces:
  - `ST_HEADING_RE`, `ST_REF_RE`
  - `verdict_entries(entries: list[str]) -> list[str]`
  - `bijection_a_errors(payload_text: str, audit_text: str) -> list[str]`
  - `attribution_block_missing(text: str) -> bool`
  - `skepticism_malformed(text)` 확장 — `ST<N>` 참조 요구 추가

- [ ] **Step 1: 실패하는 테스트를 쓴다**

audit 동반이 필요한 3개는 쌍으로 만든다:

```bash
cd plugins/spec-distill/tests/fixtures
for f in st-orphan-payload st-orphan-audit steelman-empty; do
  cp interview-brief-valid.md "interview-brief-$f.md"
  cp interview-brief-valid.audit.md "interview-brief-$f.audit.md"
  sed -i.bak "s|^audit_file:.*|audit_file: interview-brief-$f.audit.md|" "interview-brief-$f.md"
  rm -f "interview-brief-$f.md.bak"
done
for f in verdict-no-url verdict-no-token verdict-short verdict-no-st no-attribution attribution-partial; do
  cp interview-brief-valid.md "interview-brief-$f.md"
done
```

| 픽스처 | 편집 |
|---|---|
| `st-orphan-payload.md` | §5 verdict 줄의 `— ST1` → `— ST9` (audit에는 ST1만) |
| `st-orphan-audit.audit.md` | §3에 `#### ST2 — 두 번째 대안` + 인용 한 줄 추가 (payload는 ST1만 참조) |
| `steelman-empty.md` / `.audit.md` | payload §5의 verdict 줄 **삭제**(기각 일반 줄은 유지), audit §3의 `#### ST1` 블록 삭제 → **green 기대** (양쪽 공집합, sentinel 불필요) |
| `verdict-no-url.md` | §5 verdict 줄에서 URL 삭제 |
| `verdict-no-token.md` | §5 verdict 줄의 `verdict: defended` → `verdict: 방어함` |
| `verdict-short.md` | §5 verdict 줄을 `- 기각 — ab — https://x.example — verdict: defended — ST1`로 |
| `verdict-no-st.md` | §5 verdict 줄에서 ` — ST1` 삭제 |
| `no-attribution.md` | §6의 `> **출처 표기** …` 줄 삭제 |
| `attribution-partial.md` | 같은 줄에서 `· ✎ 모델 추론` 삭제 |

테스트 추가:

```bash
# --- Task 4: bijection A + §5 verdict 강화 + 표기 블록 ---

# T10: 한쪽에만 있는 ST<N> → red ×2 (양방향)
python3 "$SCRIPT" gate "$FX/interview-brief-st-orphan-payload.md" >/dev/null 2>&1 \
  && note FAIL "T10: payload만 참조하는 ST가 통과됨 (원문 없는 판정)" \
  || note PASS "T10: payload-only ST → red"
python3 "$SCRIPT" gate "$FX/interview-brief-st-orphan-audit.md" >/dev/null 2>&1 \
  && note FAIL "T10: audit에만 있는 ST가 통과됨 (판정 없는 steelman)" \
  || note PASS "T10: audit-only ST → red"

# T12: 양쪽 steelman 공집합 + 기각 항목 존재 + sentinel 없음 → green
python3 "$SCRIPT" gate "$FX/interview-brief-steelman-empty.md" >/dev/null 2>&1 \
  && note PASS "T12: steelman 양쪽 공집합은 sentinel 없이 green (R4 sentinel과 다른 조건)" \
  || note FAIL "T12: steelman 공집합은 sentinel을 요구받지 않는다"

# T11: verdict 항목 결손 → red ×4
for v in no-url no-token short no-st; do
  python3 "$SCRIPT" gate "$FX/interview-brief-verdict-$v.md" >/dev/null 2>&1 \
    && note FAIL "T11/$v: 결손 verdict 항목이 통과됨" || note PASS "T11/$v: 결손 verdict 항목 → red"
done

# T17: web 비활성 시 §4·§5 URL 요구 완화 (기존 graceful degradation 선례 유지)
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-verdict-no-url.md" >/dev/null 2>&1 \
  && note PASS "T17: web 비활성 시 URL 없는 verdict 항목 → green (AC8/AC11)" \
  || note FAIL "T17: web 비활성 시 URL 요구가 완화돼야 한다"
# ...단 ST 참조 요구는 완화되지 않는다 (web과 무관한 파일-축 drift-guard)
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-verdict-no-st.md" >/dev/null 2>&1 \
  && note FAIL "T17: web 비활성이 ST 참조 요구까지 완화시켰다 (과잉 완화)" \
  || note PASS "T17: web 비활성이어도 ST 참조는 계속 요구됨"

# T18: 출처 표기 블록 부재 / 세 기호 중 하나 누락 → red ×2
python3 "$SCRIPT" gate "$FX/interview-brief-no-attribution.md" >/dev/null 2>&1 \
  && note FAIL "T18: 표기 블록 부재가 통과됨" || note PASS "T18: 표기 블록 부재 → red"
python3 "$SCRIPT" gate "$FX/interview-brief-attribution-partial.md" >/dev/null 2>&1 \
  && note FAIL "T18: 기호 누락 표기 블록이 통과됨" || note PASS "T18: 기호 누락 표기 블록 → red"
```

- [ ] **Step 2: 테스트를 돌려 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: FAIL — T10 ×2, T11/no-st, T17 두 번째, T18 ×2가 검사기 부재로 green → FAIL 기록. T11의 no-url/no-token/short는 이미 Task 1의 `skepticism_malformed`가 잡는다.

- [ ] **Step 3: bijection A와 표기 블록 검사를 구현한다**

`check_brief.py`에 추가:

```python
ST_HEADING_RE = re.compile(r"^####\s+(ST\d+)\b", re.MULTILINE)
ST_REF_RE = re.compile(r"\b(ST\d+)\b")
ATTRIBUTION_MARKERS = ("🗣", "☑", "✎")


def verdict_entries(entries: list[str]) -> list[str]:
    return [ln for ln in entries if "verdict:" in ln]


def bijection_a_errors(payload_text: str, audit_text: str) -> list[str]:
    """bijection A — payload §5 ↔ audit §3 (AC11).

    개수 비교가 아니라 **id 집합 비교**다. 실제 steelman 항목은 다단락 블록이지 단일
    불릿이 아니어서 "무엇을 한 항목으로 셀 것인가"가 미정이고, 그러면 집행이 불가능하다.
    양쪽 공집합(steelman 0건)은 그대로 허용한다 — 공집합 == 공집합은 정합이고 steelman은
    조건부 발동이라 0건이 정상이다. sentinel이 필요한 것은 R4(`기각` 0건)뿐이다.
    """
    refs = set()
    for ln in verdict_entries(section5_entries(payload_text)):
        refs |= set(ST_REF_RE.findall(ln))
    declared = set(ST_HEADING_RE.findall(_section_text(audit_text, "3", "Steelman 원문")))
    errs = []
    for st in sorted(refs - declared):
        errs.append(f"{st}: payload §5가 참조하지만 audit §3에 없음 (원문 없는 판정)")
    for st in sorted(declared - refs):
        errs.append(f"{st}: audit §3에 있지만 payload §5가 참조하지 않음 (판정 없는 steelman)")
    return errs


def attribution_block_missing(text: str) -> bool:
    """§6 상단 2줄 출처 표기 블록 존재 검사 (AC5/C3).

    템플릿이 상속시키지만 개별 brief에서 지워질 수 있으므로 게이트가 확인한다.
    """
    for ln in _section_text(text, "6", "사용자 원문").splitlines():
        if ln.lstrip().startswith(">") and all(m in ln for m in ATTRIBUTION_MARKERS):
            return False
    return True
```

`skepticism_malformed`에 `ST<N>` 요구를 더한다 — 함수 안 루프 본문을 아래로 교체:

```python
        has_url = bool(URL_RE.search(ln))
        has_verdict = bool(re.search(r"verdict:\s*(?:%s)\b" % "|".join(VALID_VERDICTS),
                                     ln, re.IGNORECASE))
        has_st = bool(ST_REF_RE.search(ln))
        stripped = ST_REF_RE.sub("", URL_RE.sub("", ln)).lstrip("- ").strip()
        has_stmt = len(stripped) >= 10
        if not (has_verdict and has_stmt and has_st and (has_url or not require_url)):
            miss = []
            if not has_stmt:
                miss.append("statement<10c")
            if require_url and not has_url:
                miss.append("no-url")
            if not has_verdict:
                miss.append("no-verdict")
            if not has_st:
                # web kill switch는 URL 요구만 완화한다 — ST 참조는 파일-축 drift-guard라
                # 웹 가용성과 무관하다.
                miss.append("no-ST-ref")
            bad.append(f"{ln[:60]} :: {','.join(miss)}")
```

- [ ] **Step 4: `gate()`에 연결한다**

`gate()`에서 audit을 읽은 뒤(`amiss` 검사 직후) 블록 안에 추가:

```python
            if not any(m.startswith("3.") for m in amiss):
                ae = bijection_a_errors(text, audit_text)
                if ae:
                    failures.append(f"bijection A (payload §5↔audit §3): {ae}")
```

그리고 §6 검사 블록 근처에 추가:

```python
    if not sec6_absent and attribution_block_missing(text):
        failures.append("§6 출처 표기 블록 부재 (🗣·☑·✎ 세 기호를 모두 담은 인용 줄 필요)")
```

- [ ] **Step 5: 테스트를 돌려 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: PASS — `Total: 70 | Pass: 70 | Fail: 0`.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/
git commit -m "feat(spec-distill): bijection A + ST 참조 요구 + 출처 표기 블록 (T10-T12/T17/T18)"
```

---

## Task 5: 분량 지표 (advisory)

`fail`하지 않는 검사다 — 이 태스크의 실질적 위험은 실수로 fail-closed로 만드는 것이므로, 테스트가 **green + advisory 문자열**을 함께 확인한다.

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Create: `plugins/spec-distill/tests/fixtures/interview-brief-over-budget.md`
- Test: `plugins/spec-distill/tests/test_check_brief.sh`

**Interfaces:**
- Consumes: `_body(text) -> str` (기존)
- Produces:
  - `payload_body_lines_excl_verbatim(text: str) -> int`
  - `LINE_TRIPWIRE = 150`
  - `gate()` JSON 출력에 `"payload_body_lines_excl_verbatim": int` + `"advisories": list[str]` 키 추가

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```bash
cd plugins/spec-distill/tests/fixtures
cp interview-brief-valid.md interview-brief-over-budget.md
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/fixtures/interview-brief-over-budget.md")
t = p.read_text(encoding="utf-8")
# §3 Open Questions에 OQ를 채워 §6 제외 본문을 160줄대로 올린다.
filler = "".join(f"- OQ{i}: 채움 질문 {i} — 해답공간으로 이월.\n" for i in range(2, 145))
t = t.replace("- OQ1: 인증 뷰의 캐시 전략 — 해답공간으로 이월.\n",
              "- OQ1: 인증 뷰의 캐시 전략 — 해답공간으로 이월.\n" + filler)
p.write_text(t, encoding="utf-8")
PY
```

테스트 추가:

```bash
# --- Task 5: 분량 지표 (AC15, advisory — fail하지 않는다) ---

# T16: 본문 150줄 초과(§6 제외) → **green** + advisory 문자열
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-over-budget.md" 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] \
  && note PASS "T16: 분량 초과는 fail하지 않는다 (advisory)" \
  || note FAIL "T16: 분량 초과가 게이트를 red로 만들었다 (advisory여야 함)"
printf '%s' "$out" | grep -q 'payload_body_lines_excl_verbatim' \
  && note PASS "T16: 게이트가 분량 지표를 출력" || note FAIL "T16: 분량 지표 키가 없음"
printf '%s' "$out" | grep -q '트립와이어 150 초과' \
  && note PASS "T16: 150 초과 시 advisory 문자열 출력" || note FAIL "T16: advisory 문자열이 없음"

# 정상 brief는 advisory를 내지 않는다 (false-positive 방지)
python3 "$SCRIPT" gate "$FX/interview-brief-valid.md" 2>/dev/null | grep -q '트립와이어 150 초과' \
  && note FAIL "T16: 예산 이내 brief에 advisory가 붙었다" \
  || note PASS "T16: 예산 이내 brief에는 advisory 없음"

# §6 제외 확인: canonical의 지표가 §6 줄 수만큼 부풀지 않았는지 (본문 40줄대여야 한다)
n="$(python3 "$SCRIPT" gate "$FX/interview-brief-valid.md" 2>/dev/null \
     | python3 -c 'import json,sys; print(json.load(sys.stdin)["payload_body_lines_excl_verbatim"])')"
[[ "$n" -lt 60 ]] \
  && note PASS "T16: §6 사용자 원문이 계수에서 제외됨 (n=$n)" \
  || note FAIL "T16: §6가 계수에 포함된 것으로 보임 (n=$n)"
```

- [ ] **Step 2: 테스트를 돌려 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: FAIL — `payload_body_lines_excl_verbatim` 키가 없어 JSON 파싱이 죽고 advisory assert가 전부 FAIL.

- [ ] **Step 3: 지표를 구현한다**

`check_brief.py`에 추가:

```python
LINE_TRIPWIRE = 150  # §5.3 절별 예산 합계 137 + slack 13. 목표이지 정확성 조건이 아니다.


def payload_body_lines_excl_verbatim(text: str) -> int:
    """분량 지표 (AC15, advisory).

    계수법: frontmatter 제외, `## 6.` 섹션 전체 제외, 빈 줄 제외, 나머지 줄 수.
    원문(§6)은 분량 무제한이므로 총량에서 빼야 인터뷰 길이가 지표를 오염시키지 않는다.
    """
    body = _body(text)
    m = re.search(r"^##\s+6\.\s+", body, re.MULTILINE)
    if m:
        rest = body[m.end():]
        nxt = re.search(r"^##\s+\d+\.", rest, re.MULTILINE)
        body = body[: m.start()] + (rest[nxt.start():] if nxt else "")
    return len([ln for ln in body.splitlines() if ln.strip()])
```

`gate()`의 마지막 블록을 교체:

```python
    ok = not failures
    metric = payload_body_lines_excl_verbatim(text)
    advisories: list[str] = []
    if metric > LINE_TRIPWIRE:
        advisories.append(
            f"[spec-distill] payload 본문 {metric}줄(§6 제외) — 예산 137 / 트립와이어 "
            f"{LINE_TRIPWIRE} 초과. 분량은 목표이지 정확성 조건이 아니므로 차단하지 않는다."
        )
    for a in advisories:
        print(a, file=sys.stderr)
    print(json.dumps({"pass": ok, "failures": failures,
                      "payload_body_lines_excl_verbatim": metric,
                      "advisories": advisories}, ensure_ascii=False))
    return 0 if ok else 1
```

CLI에 `metrics` 서브커맨드를 추가하고 docstring도 갱신:

```python
    if sub == "metrics":
        print(json.dumps({"payload_body_lines_excl_verbatim":
                          payload_body_lines_excl_verbatim(text)}, ensure_ascii=False))
        return 0
```

- [ ] **Step 4: 테스트를 돌려 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: PASS — `Total: 75 | Pass: 75 | Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/
git commit -m "feat(spec-distill): payload 분량 지표 advisory (T16, AC15 — fail하지 않음)"
```

---

## Task 6: producer 교체 — 라운드별 잠금 → 판정 없는 발화 기록

진짜 원인을 고치는 태스크다. 과거 brief의 LD 9/6/5는 모델의 과잉 잠금이 아니라 skill이 지시한 대로 동작한 결과다.

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md:57,129-150,245,335-354,441-451`
- Modify: `plugins/spec-distill/agents/blind-spot-prober.md:35`
- Modify: `plugins/spec-distill/agents/steelman-builder.md:36`
- Modify: `plugins/spec-distill/agents/coverage-mapper.md:37`
- Test: `plugins/spec-distill/tests/test_conducting_interview_stage.sh:67,98`

**Interfaces:**
- Consumes: Task 1의 템플릿 파일명 2종, `check_brief.py gate <payload>` 계약
- Produces: state frontmatter의 `user_statements: []` 필드(스키마 `{id: S<N>, source, round, text}`) — Task 7의 확정 확인이 이 리스트를 소비한다

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_conducting_interview_stage.sh` 67행을 교체한다:

```bash
# AC1: 라운드별 잠금 producer 제거 — pending_locked_decisions는 사라지고 user_statements가 대체
grep -q 'pending_locked_decisions' "$SKILL" \
  && note FAIL "AC1: pending_locked_decisions가 SKILL에 잔존 (라운드별 잠금 producer)" \
  || note PASS "AC1: pending_locked_decisions 제거됨"
has 'user_statements' "AC1: user_statements가 state 스키마에 존재"
```

98행을 교체한다:

```bash
has '8-section|8-섹션|8 섹션' "AC10: Step A가 8섹션 템플릿을 참조"
```

그리고 파일 맨 끝 `echo`/`Total` 블록 앞에 AC1 positive grep(§8.2 요구)을 **섹션 스코프**로 추가한다:

```bash
# --- v0.23.0: 발화 기록 producer (AC1 positive, §8.2) ---
# 전-파일 grep은 헤더-satisfiable 함정에 걸린다(섹션 제목만 남겨도 통과) → awk 블록 스코프 +
# body-unique 문구로 잠근다. mutation: 아래 yaml 블록을 지우면 RED여야 한다.
stmt_block="$(awk '/^## 사용자 발화 기록/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$stmt_block" ]] && grep -q 'user_statements' <<<"$stmt_block"; } \
  && note PASS "AC1: 사용자 발화 기록 섹션이 user_statements 스키마를 담는다" \
  || note FAIL "AC1: 사용자 발화 기록 섹션에 user_statements 스키마가 없다"
{ grep -q 'id: S<N>' <<<"$stmt_block" && grep -qE 'source: verbatim' <<<"$stmt_block"; } \
  && note PASS "AC1: 발화 레코드가 id/source 필드를 명시" \
  || note FAIL "AC1: 발화 레코드 스키마(id: S<N> / source: verbatim)가 없다"
grep -qE 'status 필드는 없습니다|앵커도 없습니다' <<<"$stmt_block" \
  && note PASS "AC1: 라운드 중 status·해답공간 앵커 부재가 명시됨" \
  || note FAIL "AC1: status/앵커 부재 명시가 없다"

# agents 3종의 Input 절이 더 이상 locked_directions를 참조하지 않는다 (spec §7 누락 보강)
for a in blind-spot-prober steelman-builder coverage-mapper; do
  grep -q 'locked_directions' "$REPO_ROOT/plugins/spec-distill/agents/$a.md" \
    && note FAIL "AC13: agents/$a.md가 locked_directions를 참조" \
    || note PASS "AC13: agents/$a.md에 locked_directions 없음"
done
```

- [ ] **Step 2: 테스트를 돌려 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: FAIL — `pending_locked_decisions` 잔존 1건, `user_statements` 부재, 8섹션 미참조, 발화 기록 섹션 부재 3건, agents 3건 = 총 9 FAIL.

- [ ] **Step 3: state 스키마를 교체한다**

`SKILL.md` 57행을 교체:

```yaml
user_statements: []                  # 매 round 끝 append. 판정 없음 — 확정은 종료 게이트가 결정.
confirm_repost_count: 0              # 종료 확정 확인 재제시 횟수 (상한 2, Unbounded-autonomy 가드)
```

- [ ] **Step 4: decision table을 발화 기록으로 교체한다**

`SKILL.md` 129–150행(`## Locked 판정 트리거 (G1, AC1)` 절 전체)을 아래로 교체:

````markdown
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
| sub-agent ambiguity 답안 | c | ✅ ONLY IF 사용자 confirm — **confirm 발화**를 기록 | `verbatim` |

```yaml
- id: S<N>                 # N = user_statements.length + 1
  source: verbatim         # verbatim(발화 그대로) | chosen(고른 선택지 라벨 + 요지)
  round: <int>
  text: "<사용자가 실제로 한 말>"    # P21 secret placeholder 치환 적용
```

`status` 필드는 없습니다. `section:` 해답공간 앵커도 없습니다 — 문제공간의 답변을 답이
들어갈 슬롯에 미리 바인딩하면 다음 stage의 탐색이 그 슬롯 모양대로 갇힙니다.

거절도 수락과 똑같이 **발화 그대로** 기록합니다. 반대 명제로 뒤집어 "잠긴 방향"으로
승격시키지 않습니다 — 그 승격이 라운드마다 결정을 박제하던 경로였습니다.
````

- [ ] **Step 5: 나머지 SKILL 참조 3곳을 고친다**

245행(blind-spot-prober dispatch 프롬프트):

```
        prompt: "재구성된 문제정의: <...>. 지금까지의 사용자 제약 요지: <...>. 이 framing의 hidden assumption과 failure mode를 웹근거와 함께." })
```

335–354행(Step A)에서 템플릿·frontmatter·직렬화·게이트 문단을 교체:

````markdown
### Step A — brief 작성 (terminal 산출물, 2파일)

1. `${CLAUDE_PLUGIN_ROOT}/templates/interview-brief-template.md`로 payload **8-section**
   구조(§0 한눈에 – §7 Next Action)를, `${CLAUDE_PLUGIN_ROOT}/templates/interview-audit-template.md`로
   audit **5-section** 구조를 확보합니다.
2. 경로 (둘 다 워크트리 안 → `Write` tool 사용):
   - payload: `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.md`
   - audit:   `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.audit.md`
   - payload frontmatter: `type: interview-brief`, `next_phase: superpowers:brainstorming`,
     `session_id`(기존 spec-distill 세션 재사용), `audit_file`(audit의 **basename만** —
     경로 구분자가 들어가면 게이트가 거부합니다), `user_sourced_items[]`.
3. **`user_sourced_items` 직렬화**: state의 `user_statements`를 훑어 제약으로 승격할 항목을
   고르고, 각각에 id·`source`·`statement`(160자 이내)·`evidence`(그 발화의 `S<N>`)를 붙입니다.
   **이 시점의 `status`는 전부 `provisional`입니다** — `confirmed`는 Step B-0의 사용자 확인
   으로만 발생합니다. 모델 추론은 이 리스트에 넣지 말고 본문에 ✎ 프로즈로 씁니다.
   `user_statements`의 발화 전부를 payload §6에 **전문 보존**하고 `S<N>` 앵커를 답니다.
4. **Coverage Ledger 직렬화**(게이트 *전*): state의 `coverage`를 **audit §1**에 한 줄당 한
   차원으로 직렬화(floor 5행 + derived 또는 `- derived: N/A`). floor 전부 `closed`가 아니면
   이 시점에 도달하면 안 됩니다(종료 driver 위반). steelman 원문은 audit §3에
   `#### ST<N> — <한 줄 요지>` 헤딩과 함께 verbatim으로 남기고, payload §5의 `verdict:` 항목이
   그 `ST<N>`을 참조합니다 — 양방향 일치가 게이트 대상입니다.
5. **기계적 게이트 검증**(AC3) — 직렬화 직후. payload 경로만 넘기면 게이트가 `audit_file`로
   audit을 해석합니다:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_brief.py" gate "docs/superpowers/interview/<file>"
   ```
   exit ≠ 0 이면 **brief를 finalize하지 말고** 보고된 미충족 항목을 보완(누락 섹션·무인용
   landscape·형식 미달 verdict 항목·`기각` 0건·floor open·bijection 불일치). 통과(exit 0)할
   때까지 반복합니다.
````

441–451행(migration 절)에서 `pending_locked_decisions`를 지운다 — 451행을 교체:

```markdown
기존 필드(`non_user_streak`·`web_*`·`issue_history` 등)는 유지. 구세션의
`pending_locked_decisions`는 승계하지 않고 `user_statements: []`로 fresh seed합니다 —
잠금 레코드를 발화 레코드로 승격하면 판정이 없던 척하는 잠금이 그대로 넘어옵니다.
```

- [ ] **Step 6: agents 3종의 Input 문구를 고친다**

`agents/blind-spot-prober.md:35`:

```markdown
- 현재 재구성된 문제정의(Reframed Problem) + 지금까지 사용자가 말한 제약의 요지.
```

`agents/steelman-builder.md:36`:

```markdown
- (있으면) 지금까지 사용자가 말한 제약의 요지, External Landscape 발췌.
```

`agents/coverage-mapper.md:37`:

```markdown
- (있으면) 현재까지의 사용자 제약 요지, External Landscape 발췌.
```

`steelman-builder.md` 34행의 trigger 목록에 있는 `LD 충돌`도 `기존 사용자 제약과의 충돌`로 고친다 — `LD`는 제거된 어휘다.

- [ ] **Step 7: 테스트를 돌려 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: PASS — 84/84 (기존 77 − 제거 1 + 신규 8).

락 이빨 확인(mutation): `## 사용자 발화 기록` 절의 yaml 블록을 잠시 지우고 재실행 → `AC1: 발화 레코드가 id/source 필드를 명시`가 RED여야 한다. 확인 후 되돌린다.

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/agents/ plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): 라운드별 잠금 producer를 판정 없는 user_statements 기록으로 교체 (AC1)"
```

---

## Task 7: 종료 확정 확인 흡수 + C4 프로토콜 전달

확정 권한이 사용자에게 돌아오는 지점이다. 상호작용은 1회로 유지되고, 재제시에는 상한이 있으며, 초과 시 **덜 잠그는 쪽**(전부 provisional)으로 fail한다.

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md:356-437` (Step B 전체)
- Test: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

**Interfaces:**
- Consumes: `user_statements` / `confirm_repost_count` (Task 6), `check_brief.py gate` (Task 1–5)
- Produces: brief frontmatter의 `status: confirmed` 전이 경로 + brainstorming 호출 프롬프트에 실리는 C4 문장 — 두 handoff 경로(①/②) 모두

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_conducting_interview_stage.sh`의 42–45행 근처(v0.13.0 블록)를 아래로 교체·확장한다:

```bash
# --- v0.23.0: 확정 확인을 흡수한 단일 proceed 게이트 (AC2/AC3) ---
has 'AskUserQuestion' "AC20: Step B proceed 게이트가 AskUserQuestion 사용"
has '확정하고 /compact 후 brainstorming' "AC2: 옵션 ① 라벨 (확정 + /compact)"
has '확정하고 바로 brainstorming' "AC2: 옵션 ② 라벨 (확정 + 즉시)"
has '확정 목록 수정' "AC2: 옵션 ③ 라벨 (재제시)"
has 'brief만 종료' "AC20: 옵션 ④ 라벨 (terminal)"
has '/compact interview brief at' "AC20: verbatim /compact 명령 노출"

# AC2: 재제시 상한 + 초과 시 강등 + 고정 advisory 문자열 (Unbounded-autonomy 가드)
b0_block="$(awk '/^#### B-0/{f=1;print;next} /^#### /{f=0} f' "$SKILL")"
{ [[ -n "$b0_block" ]] && grep -q 'confirm_repost_count' <<<"$b0_block"; } \
  && note PASS "AC2: 재제시 카운터가 state에 기록됨 (프로즈 self-tracking 아님)" \
  || note FAIL "AC2: confirm_repost_count가 B-0 블록에 없다"
grep -qF '[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등' <<<"$b0_block" \
  && note PASS "AC2: 상한 초과 고정 advisory 문자열 (verbatim)" \
  || note FAIL "AC2: 상한 초과 advisory 문자열이 정확히 일치하지 않는다"
grep -qE '전부 provisional|전 항목 .*provisional' <<<"$b0_block" \
  && note PASS "AC2: 상한 초과 시 덜-잠그는 쪽으로 강등" \
  || note FAIL "AC2: 상한 초과 동작(provisional 강등)이 명시되지 않았다"
grep -qE '제외한 것도|제외 항목' <<<"$b0_block" \
  && note PASS "AC2: 확정 후보에서 제외한 항목도 함께 제시 (누락 검출 가능)" \
  || note FAIL "AC2: 제외 항목 제시 요구가 없다"

# AC3: C4 재결정 프로토콜이 **양쪽 경로**의 호출 프롬프트에 실린다
b3_block="$(awk '/^#### B-3/{f=1;print;next} /^#### /{f=0} f' "$SKILL")"
c4=$(grep -c '보고 후 재결정' <<<"$b3_block")
[[ "$c4" -ge 2 ]] \
  && note PASS "AC3: C4 프로토콜이 ①/② 양쪽 경로에 실림 (n=$c4)" \
  || note FAIL "AC3: C4 프로토콜이 한쪽 경로에만 있다 (n=$c4)"
grep -qE '임의 변경.*금지' <<<"$b3_block" \
  && note PASS "AC3: 임의 변경 금지 절반이 명시됨" || note FAIL "AC3: 임의 변경 금지가 없다"

# C5: 규약은 brief가 아니라 호출 프롬프트에 산다
grep -qE '호출 프롬프트|invocation prompt' <<<"$b3_block" \
  && note PASS "C5: 규약의 거처가 호출 프롬프트로 명시됨" \
  || note FAIL "C5: 규약이 brief에 실리지 않는다는 명시가 없다"
```

기존 48–50행의 AC21 cross-compact assert는 그대로 둔다(문구가 유지되므로).

- [ ] **Step 2: 테스트를 돌려 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: FAIL — B-0 블록 부재로 4건, 옵션 라벨 3건, C4 2건, C5 1건 ≈ 10 FAIL.

- [ ] **Step 3: B-0 확정 확인 절을 신설한다**

`SKILL.md`의 `#### B-1 — superpowers 가용성 분기` **앞에** 삽입:

````markdown
#### B-0 — 확정 후보 제시 (게이트에 흡수, AC2)

Step A가 끝난 시점에 `user_sourced_items`는 **전부 `provisional`**입니다. `confirmed`로의
전이는 아래 B-2 게이트에서 사용자가 확정-후-진행 옵션(①/②)을 고를 때만 일어납니다.
별도 확인 의례를 만들지 않는 이유는 종료 시 사용자 상호작용이 2회가 되기 때문입니다 —
확인을 기존 proceed 게이트에 흡수해 1회로 유지합니다.

게이트를 띄우기 *전에* 확정 후보 목록을 **프로즈로** 출력합니다(목록이 길 수 있으므로
`AskUserQuestion`은 선택지만 담당):

- 각 후보를 `<id> — <statement> (source, ⟨S<N>⟩)` 한 줄로.
- **확정 후보에서 제외한 항목도** 한 줄씩 이유와 함께 보여줍니다 — 제외 항목을 감추면
  사용자가 누락을 잡을 수 없습니다.
- 모델의 후보 판정은 **제안일 뿐**입니다. 어떤 항목도 이 출력만으로 `confirmed`가 되지 않습니다.

**재제시 상한** (금지 패턴 *Unbounded autonomy* 가드): 최초 제시는 0회째입니다. 사용자가
옵션 ③(확정 목록 수정)을 고를 때마다 state의 `confirm_repost_count`를 +1 하고 **2회까지**
허용합니다. 3번째 ③ 요구 시 전 항목을 `provisional`로 강등하고 아래 **고정 문자열**을 출력한
뒤 게이트를 재제시하지 않고 진행합니다 — 확정이 덜 되는 쪽이 안전한 방향입니다:

```
[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등
```

카운터는 프로즈 self-tracking이 아니라 state에 씁니다(PN1 Bash write contract):

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" state-root)"
STATE="$ROOT/<session-id>/state.local.md"
# confirm_repost_count read-modify-write via python3 -c / heredoc
```
````

- [ ] **Step 4: B-2 게이트를 4옵션으로 교체한다**

`SKILL.md`의 B-2 `AskUserQuestion` 블록을 교체:

```javascript
AskUserQuestion({
  questions: [{
    question: "interview brief 완결: <brief-path> (구조 게이트 통과). 확정 후보는 위 목록대로. 다음 단계?",
    header: "Proceed",
    options: [
      {label: "확정하고 /compact 후 brainstorming (권장)", description: "확정 후보를 status: confirmed로 반영 → 재저장 → 게이트 재실행 → verbatim /compact 노출. 긴 인터뷰 context 정리 이점."},
      {label: "확정하고 바로 brainstorming", description: "확정 반영 후 즉시 Skill superpowers:brainstorming <brief-path> 호출 (compact 없이, 전체 context 유지)."},
      {label: "확정 목록 수정", description: "확정 후보를 고쳐 다시 제시 (상한 2회). 확정 전이 없음."},
      {label: "brief만 종료", description: "brief는 단독 완결 terminal (NG7). 전 항목 provisional 유지, handoff 안 함."}
    ],
    multiSelect: false
  }]
})
```

- [ ] **Step 5: B-3 응답 처리와 compact 문구를 교체한다**

`#### B-3 — 응답 처리` 절 전체를 교체:

````markdown
#### B-3 — 응답 처리

**규약의 거처 (C5).** `superpowers:brainstorming`은 spec-distill을 모르고 brief frontmatter를
읽지 않습니다 — 전달은 순수 프로즈 경로입니다. 그래서 C4 재결정 프로토콜은 brief 파일이
아니라 **orchestrator의 호출 프롬프트**에 싣습니다. brief는 순수 데이터(`source`/`status`/
`evidence`)만 나릅니다. 아래 ①과 ② **양쪽 모두** 같은 문장을 싣습니다.

- **① 확정하고 /compact 후 brainstorming**: 확정 후보를 `status: confirmed`로 반영 →
  brief 재저장 → `check_brief.py gate` 재실행(통과 확인) → 아래 verbatim `/compact` 명령을
  *그대로 보이게* 노출 + "compact 후 brainstorming 진입 준비됨" 안내:

  > `/compact interview brief at <brief-path> 보존 — brief 본문(특히 §0 한눈에, §2 제약, §3 Open Questions, §6 사용자 원문)과 audit 파일 경로 참조 유지하고, round-by-round 인터뷰 대화·web sweep 원문·steelman 중간 추론은 drop. confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 다음 단계: Skill superpowers:brainstorming <brief-path>.`

  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것**(compact 전
  brainstorming 진입 = 옵션 ① 무력화). `Skill superpowers:brainstorming <brief-path>` 진입은
  사용자가 `/compact`를 *실제 실행한 다음 턴*에 **사용자 트리거**(예: `/compact write design`처럼
  compact 뒤에 붙인 진행 인자, 또는 명시적 진행 요청)로만 일어난다 — 모델은 다음 턴에 자동
  진입하지 *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17).

- **② 확정하고 바로 brainstorming**: 확정 반영 → 재저장 → 게이트 재실행 → 즉시
  `Skill superpowers:brainstorming <brief-path>` 호출하되, **호출 프롬프트에 C4 문장을 함께
  싣는다**:

  > `confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.`

  이것은 아래 cross-compact 정지 요건의 *명시적 예외*다.

- **③ 확정 목록 수정**: 확정 전이 없음. `confirm_repost_count` +1 후 B-0으로 돌아가 수정된
  목록을 재제시(상한 2회 — 초과 시 B-0의 강등 경로).

- **④ brief만 종료**: 전 항목 `provisional` 유지. brief terminal advisory(B-1 부재 advisory와
  같은 톤) 출력 후 종료. handoff 안 함. state는 SessionEnd hook이 cleanup.
````

- [ ] **Step 6: 테스트를 돌려 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: PASS — 94/94.

Run: `bash plugins/spec-distill/tests/test_check_brief.sh` → 75/75 green (회귀 없음).

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): 확정 확인을 proceed 게이트에 흡수 + C4 프로토콜을 호출 프롬프트로 전달 (AC2/AC3)"
```

---

## Task 8: 회귀 락 + mutation 증명

**락의 PASS는 이빨의 증거가 아니다.** 이 태스크의 실질은 락을 쓰는 것이 아니라 **락이 실제로 문다는 것을 보이는 것**이다 — mutation 단계를 건너뛰면 아무것도 검증되지 않는다.

**Files:**
- Modify: `plugins/spec-distill/tests/test_stale_terms.sh`

**Interfaces:**
- Consumes: Task 1–7이 남긴 production 파일 상태(6개 리터럴 잔존 0건)
- Produces: 없음 (테스트 전용)

- [ ] **Step 1: 락을 쓴다**

`tests/test_stale_terms.sh`의 헤더 주석에 (c)를 추가한다:

```bash
# (c) v0.23.0 권위 문법 6개 리터럴이 production에서 제거됐다(AC13).
#     이 검사만 README.md를 **추가로 제외**한다 — README의 "Principles Instantiated"는
#     무엇이 왜 사라졌는지 설명하려면 옛 용어를 인용해야 하고(CHANGELOG를 뺀 것과 같은 이유),
#     우회해야 하는 락은 그 자체로 설계 결함이다. 그 대가로 README는 기계 커버리지가 0이며
#     V10 수동 검토가 그 갭을 맡는다 — 숨기지 않는다.
```

`V7b-2` 블록 뒤, `echo`/`Total` 앞에 추가:

```bash
# --- V8 (AC13): v0.23.0 권위 문법 6개 리터럴 회귀 락 ---
# 스코프 = prod_files − README.md. prod_files를 그대로 재사용하면 AC13의 명시 예외와
# 모순되므로 별도 배열을 만든다.
lock_files=()
for f in "${prod_files[@]}"; do
  [[ "$(basename "$f")" == "README.md" ]] && continue
  lock_files+=("$f")
done
if [[ ${#lock_files[@]} -eq 0 ]]; then
  note FAIL "V8: lock scope empty — filter broken"
else
  # 배열 리터럴로 선언한다(공백 없는 토큰뿐이라 word-split 안전, zsh/bash 양쪽 동일).
  authority_terms=(
    'locked_directions'
    'pending_locked_decisions'
    '재논쟁 금지'
    'Locked Directions'
    '다시 묻지 않는다'
    '확정·재논쟁'
  )
  for term in "${authority_terms[@]}"; do
    hit="$(grep -InIF -- "$term" "${lock_files[@]}" 2>/dev/null || true)"
    [[ -z "$hit" ]] \
      && note PASS "V8/AC13: '$term' 잔존 0건 (production, README 제외)" \
      || { note FAIL "V8/AC13: '$term' 가 production에 잔존:"; printf '%s\n' "$hit"; }
  done
fi
```

- [ ] **Step 2: 락을 돌려 GREEN을 확인한다 (아직 이빨 증명 아님)**

Run: `bash plugins/spec-distill/tests/test_stale_terms.sh`
Expected: PASS — `Total: 9 | Pass: 9 | Fail: 0` (기존 3 + 신규 6).

**이 GREEN은 아무것도 증명하지 않는다.** 셸 파싱 사고(빈 배열·word-split·후행 개행)가 집행을 조용히 0으로 만든 사례가 이 리포에 있다. 다음 단계가 진짜 검증이다.

- [ ] **Step 3: mutation으로 이빨을 증명한다 — 맨앞·중간·맨끝 세 위치**

`authority_terms` 배열의 **첫 항목**(`locked_directions`), **중간 항목**(`Locked Directions`), **마지막 항목**(`확정·재논쟁`)을 각각 되살려 RED가 나오는지 본다. 배열 순회가 중간에서 끊기거나 마지막 원소를 흘리는 사고를 잡는 표준 절차다.

```bash
SKILL=plugins/spec-distill/skills/conducting-interview/SKILL.md
for term in 'locked_directions' 'Locked Directions' '확정·재논쟁'; do
  cp "$SKILL" "$SKILL.bak"
  printf '\n<!-- mutation probe: %s -->\n' "$term" >> "$SKILL"
  if bash plugins/spec-distill/tests/test_stale_terms.sh >/dev/null 2>&1; then
    echo "✗ MUTATION SURVIVED: '$term' — 락에 이빨이 없다"
  else
    echo "✓ mutation killed: '$term'"
  fi
  mv "$SKILL.bak" "$SKILL"
done
```

Expected: 세 줄 모두 `✓ mutation killed`. 하나라도 SURVIVED면 락이 그 항목을 실제로 검사하지 않는 것이므로 Step 1로 돌아간다.

- [ ] **Step 4: 되돌림을 확인한다**

Run: `git diff --stat plugins/spec-distill/skills/conducting-interview/SKILL.md`
Expected: 출력 없음 (mutation이 전부 되돌려졌다). `.bak` 잔존물도 확인:
`ls plugins/spec-distill/skills/conducting-interview/*.bak 2>/dev/null` → 출력 없음.

Run: `bash plugins/spec-distill/tests/test_stale_terms.sh` → 9/9 green.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/tests/test_stale_terms.sh
git commit -m "test(spec-distill): 권위 문법 6개 리터럴 회귀 락 + mutation 이빨 증명 (AC13)"
```

---

## Task 9: 버전 · CHANGELOG · README

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`
- Test: `plugins/spec-distill/tests/test_readme_sync.sh`

**Interfaces:**
- Consumes: Task 1–8의 shipped 동작
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_readme_sync.sh`의 17–24행을 교체한다. 버전 리터럴은 **minor까지만** pin한다 — patch digit을 박으면 다음 doc-only bump마다 stale-red가 된다.

```bash
grep -qE '"version": "0\.23\.[0-9]+"' "$PLUGIN_JSON" \
  && note PASS "T20: plugin.json version 0.23.x" \
  || note FAIL "T20: plugin.json이 0.23.x가 아님"
grep -qE '^## \[0\.23\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "T20: CHANGELOG [0.23.0] 엔트리 + ISO 날짜" \
  || note FAIL "T20: CHANGELOG [0.23.0] 누락/비-ISO"
grep -qE '^## \[0\.2[02]\.0\].*XX' "$CHANGELOG" \
  && note FAIL "T20: CHANGELOG 날짜에 XX placeholder" || note PASS "T20: XX placeholder 없음"
grep -qE '^## \[0\.22\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC11: CHANGELOG [0.22.0] 엔트리 보존 (append-only)" \
  || note FAIL "AC11: CHANGELOG [0.22.0] 엔트리가 사라졌다"
```

26행의 키워드 루프에 v0.23.0 어휘 4개를 추가한다:

```bash
for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC' 'review_in_progress' 'interview-brief' 'steelman-builder' 'cancel-review' 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' 'model diversity' 'coverage-mapper' 'blind-spot-prober' 'probe_budget' 'user_sourced_items' 'audit_file' 'user_statements' 'bijection'; do
```

그리고 AC14의 **네 사실 체크리스트**를 기계 assert로 추가한다(V6가 내용 적절성을 보고, 이건 네 축이 언급조차 안 되는 것을 막는다). `for kw` 루프 뒤에 삽입:

```bash
# AC14: README "Principles Instantiated"가 네 사실을 각각 명시하는지 (섹션 스코프 — 헤더-satisfiable 회피)
pi_block="$(awk '/^## Principles Instantiated/{f=1;print;next} /^## /{f=0} f' "$README")"
{ [[ -n "$pi_block" ]] && grep -qE '라운드별 잠금|라운드마다 결정' <<<"$pi_block"; } \
  && note PASS "AC14/1: 라운드별 잠금 제거 명시" || note FAIL "AC14/1: 라운드별 잠금 제거가 없다"
grep -qE '일괄 확인|사용자 확인' <<<"$pi_block" \
  && note PASS "AC14/2: 종료 시 사용자 일괄 확인 명시" || note FAIL "AC14/2: 사용자 일괄 확인이 없다"
grep -qE 'payload.*audit|2파일|두 파일' <<<"$pi_block" \
  && note PASS "AC14/3: payload/audit 분리 명시" || note FAIL "AC14/3: payload/audit 분리가 없다"
grep -q 'user_sourced_items' <<<"$pi_block" \
  && note PASS "AC14/4: user_sourced_items 계약 명시" || note FAIL "AC14/4: user_sourced_items 계약이 없다"
```

- [ ] **Step 2: 테스트를 돌려 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: FAIL — version 0.22.0, CHANGELOG [0.23.0] 부재, 신규 키워드 4개 부재, AC14 4축 부재 ≈ 10 FAIL.

- [ ] **Step 3: 버전을 bump한다**

`plugins/spec-distill/.claude-plugin/plugin.json`:

```json
  "version": "0.23.0",
```

- [ ] **Step 4: CHANGELOG 엔트리를 쓴다**

`plugins/spec-distill/CHANGELOG.md`의 `# Changelog` 바로 아래에 삽입 (`YYYY-MM-DD`는 **실제 커밋 날짜**로):

```markdown
## [0.23.0] — YYYY-MM-DD

### Added
- **brief 2파일 계약** — payload(`<topic>-interview.md`, 8섹션 역피라미드)와 audit
  (`<topic>-interview.audit.md`, 5섹션 텔레메트리)로 분할. payload frontmatter의 `audit_file`
  (basename만 — traversal 거부)이 audit을 가리키고, 게이트가 두 파일을 함께 검사한다.
  audit 부재·미해석은 fail-closed.
- `templates/interview-audit-template.md` — Coverage Ledger / Budget / Steelman 원문 /
  게이트 실행 기록 / 프로세스 로그.
- **frontmatter `user_sourced_items[]` 계약** — `id`/`source`(`verbatim`|`chosen`)/`status`
  (`confirmed`|`provisional`|`open`)/`statement`(160자 hard cap)/`evidence`(`S<N>`, 필수).
  `source: inferred`는 이 리스트에 들어갈 수 없다 — 모델 추론은 본문 ✎ 프로즈로만 산다.
- **세 bijection** — A: payload §5 `ST<N>` ↔ audit §3 `#### ST<N>`(양방향, 공집합 허용) /
  B: body §2 ↔ frontmatter(id·기호·status·`⟨S<N>⟩`·**statement 내용**까지) /
  C: 모든 `evidence: S<N>`가 payload §6에서 해석됨.
- **종료 확정 확인** — proceed 게이트에 흡수(상호작용 1회 유지). 재제시 상한 2회, 초과 시
  전 항목 `provisional` 강등 + 고정 advisory.
- 분량 지표 `payload_body_lines_excl_verbatim`(§6 제외) — 150 초과 시 advisory, **fail 안 함**.
- `check_brief.py items` / `metrics` 서브커맨드.
- `tests/test_stale_terms.sh` V8 — 권위 문법 6개 리터럴 회귀 락 + mutation 이빨 증명.

### Changed
- **라운드별 잠금 producer 제거** — 매 round 끝 `locked?` decision table이 사라지고,
  판정 없는 `user_statements`(`{id: S<N>, source, round, text}`) 기록으로 대체. `status`도
  해답공간 `section:` 앵커도 붙이지 않는다. 과거 brief의 LD 9/6/5는 모델의 과잉 잠금이 아니라
  skill이 지시한 대로 동작한 결과였다.
- brief 템플릿을 8섹션 역피라미드로 재작성 — 행동 항목(제약·Open Questions)이 앞, 근거·원문이
  뒤. 사용자 원문은 §6에 전문 보존(허용 변환은 P21 placeholder 치환·공백 정리·인용 래핑뿐).
- Coverage Ledger 검증이 payload §6 → audit §1로 이동.
- R4 통과 의례가 payload §5 `기각` 항목 문법으로 이관 — 0건이면 명시 N/A sentinel 없이 fail.
- `/compact` 핸드오프 문구가 새 섹션명을 가리키고 **C4 재결정 프로토콜**을 함께 싣는다.
  직행 경로(옵션 ②)의 호출 프롬프트에도 같은 문장이 실린다 — 규약은 brief가 아니라
  호출 프롬프트에 산다(C5).
- `agents/{blind-spot-prober,steelman-builder,coverage-mapper}.md`의 Input 절이
  `locked_directions` 대신 "사용자 제약 요지"를 받는다.

### Removed
- frontmatter `locked_directions[]` 및 state `pending_locked_decisions[]`.
- brief §2 *"Locked Directions"* 섹션과 *"재논쟁 금지"* 헤더 문구.
- `check_brief.py`의 `steelman_unlogged()` — frontmatter `steelman:` 라벨이 사라져 죽은 코드가
  됐고, 그 보장은 bijection A가 이어받는다.
```

- [ ] **Step 5: README를 갱신한다**

`plugins/spec-distill/README.md`의 v0.22.0 요약 줄 **위**에 v0.23.0 줄을 추가:

```markdown
**v0.23.0**: interview brief를 핸드오프 아티팩트로 재설계. 라운드마다 결정을 잠그던 producer를 제거하고(`user_statements`에 판정 없이 기록), 확정 권한을 **종료 시 사용자 일괄 확인**으로 되돌렸다. brief는 payload(8섹션 역피라미드) + audit(텔레메트리) **두 파일**로 갈라지고 `audit_file`로 묶이며, frontmatter `user_sourced_items` 계약과 세 bijection이 body↔frontmatter·payload↔audit drift를 잡는다.
```

`## Principles Instantiated` 절의 `### Three Laws` 목록에 두 줄을 추가:

```markdown
- **Law 1 (Clarity) — 핸드오프 게이트 (v0.23.0)** — brief 구조 게이트가 **2파일 fail-closed**로 확장. payload frontmatter `audit_file`(basename만, traversal 거부)로 audit을 해석하고, 못 열면 payload-only로 degrade하지 않고 red를 낸다. `user_sourced_items` 스키마 + 세 bijection(A: payload §5 ↔ audit §3 / B: body §2 ↔ frontmatter — statement 내용까지 / C: `evidence: S<N>` → §6)이 라벨과 내용이 어긋나는 drift를 기계로 잡는다.
- **P17 (User sovereignty) — 확정 권한 반환 (v0.23.0)** — 라운드마다 결정을 잠그던 producer를 제거하고 `status: confirmed`를 **종료 시 사용자 일괄 확인**으로만 발생시킨다. 확인은 새 의례가 아니라 기존 proceed 게이트에 흡수돼 상호작용이 1회로 유지된다(trivia ceremony 회피). 재제시에는 상한 2회가 있고 초과 시 전 항목이 `provisional`로 강등된다 — **덜 잠그는 쪽이 안전한 방향**(Unbounded-autonomy 가드).
```

`### Principles 흡수`의 P21 줄을 확장:

```markdown
- **P21 (Secret 기록 금지 / untrusted input)** — state.local.md token/key/credential placeholder 치환. **v0.23.0**: `audit_file`은 frontmatter에서 오는 신뢰 경계 밖 입력이므로 basename으로 제한한다(`../`·절대경로·서브경로 전부 거부).
```

29행 근처 다이어그램의 `5 의례 통과 (check_brief.py gate, Law 1)`은 그대로 둔다 — R1–R5 의례 자체는 살아 있고 좌표만 옮겨갔다.

- [ ] **Step 6: 테스트를 돌려 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: PASS — `Total: 23 | Pass: 23 | Fail: 0`.

전체 회귀:

```bash
for t in test_check_brief test_conducting_interview_stage test_stale_terms test_readme_sync; do
  printf '%-38s' "$t"; bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 \
    && echo GREEN || echo RED
done
```
Expected: 4줄 전부 GREEN.

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md \
        plugins/spec-distill/README.md plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "chore(spec-distill): v0.23.0 메타데이터 + CHANGELOG + README 원칙 (AC14/T20)"
```

---

## Task 10: 수동 검증 (V1–V10) + 탐색 폭 회귀 (AC16)

기계가 못 잡는 것들이다. **이 한계를 숨기지 않는 것이 설계의 일부다** — 락이 커버한다고 주장하면 커버되지 않은 영역이 커버된 것으로 보인다.

**Files:**
- Modify: `plugins/spec-distill/tests/` (검증 중 결함 발견 시)
- Create: 실산출 brief 쌍 (V1 e2e의 부산물)

**Interfaces:** 없음 (검증 전용)

- [ ] **Step 1: 자동 스위트 전체를 마지막으로 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew
fail=0
for t in plugins/spec-distill/tests/test_*.sh; do
  printf '%-56s' "$(basename "$t")"
  if bash "$t" >/dev/null 2>&1; then echo GREEN; else echo RED; fail=1; fi
done
for t in plugins/spec-distill/tests/test_*.py; do
  printf '%-56s' "$(basename "$t")"
  if python3 -m unittest "$t" >/dev/null 2>&1 \
     || (cd plugins/spec-distill/tests && python3 -m unittest "$(basename "$t" .py)" >/dev/null 2>&1); then
    echo GREEN; else echo RED; fail=1; fi
done
echo "aggregate: $([[ $fail -eq 0 ]] && echo GREEN || echo RED)"
```

Expected: 전부 GREEN. RED가 있으면 baseline(이 계획 상단)과 대조해 **이 계획이 만든 것인지** 먼저 가린다.

- [ ] **Step 2: V4 · V5 · V10 — 개방형 부정 판정 (사람이 읽는다)**

리터럴 락이 못 잡는 영역이다. 각각 결과를 한 줄로 기록한다.

| # | 무엇을 읽나 | 무엇을 찾나 |
|---|---|---|
| V4 | `skills/conducting-interview/SKILL.md` 전체 | **이름만 바꾼 라운드별 잠금 구조** — 변수명을 갈아끼운 decision table, `locked?`와 동형인 판정 열, 라운드 끝에 무언가를 "확정"으로 승격시키는 문장 |
| V5 | 새 템플릿 2종 + `SKILL.md` | 독자(다음 세션 모델)에게 **행동을 지시하는 문장**이 남아 있는지 — "다시 묻지 말 것", "이미 결정됨", "이 방향으로 진행" 류. C5 위반 |
| V10 | `README.md` | AC13의 6개 리터럴이 **옛 용어를 인용해 설명하는 맥락 밖에서** 재도입됐는지. 락 스코프 밖이라 기계 커버리지 0 |

V10 보조(판단 재료용, 판정 자체는 사람이 한다):

```bash
grep -nE 'locked_directions|pending_locked_decisions|재논쟁 금지|Locked Directions|다시 묻지 않는다|확정·재논쟁' \
  plugins/spec-distill/README.md
```
각 히트가 *"v0.23.0에서 무엇이 사라졌는지"* 를 설명하는 문장 안에 있으면 정상, 살아 있는 규약처럼 서술돼 있으면 결함이다.

- [ ] **Step 3: V6 — README 네 사실 대조**

`README.md`의 "Principles Instantiated"가 아래 넷을 **각각** 실제로 반영하는지 본다(문자열 존재가 아니라 내용 적절성 — 기계 assert는 Task 9가 이미 걸었다).

1. 라운드별 잠금 제거 2. 종료 시 사용자 일괄 확인 3. payload/audit 분리 4. `user_sourced_items` 계약

- [ ] **Step 4: V1 · V2 — 새 포맷으로 인터뷰 1회 e2e**

`/interview`로 작은 토픽(예: *"이 플러그인의 kill switch 목록을 문서 한 곳으로 모을까"*)을 한 번 돌린다. 확인할 것:

- V1: 종료 시 확정 후보 목록이 **프로즈로** 뜨고, 4옵션 게이트가 한 번만 뜨고, ① 선택 시 `status: confirmed`가 실제로 brief에 반영된 뒤 게이트가 재실행되는가.
- V2: 옵션 ③을 세 번 고르면 전 항목이 `provisional`로 강등되고 고정 문자열이 **정확히** 출력되는가.
- 부산물인 payload/audit 쌍이 `check_brief.py gate`를 통과하는가.

- [ ] **Step 5: V3 · V7 · V8 · V9 — 실산출물 대조**

| # | 확인 |
|---|---|
| V3 | ① `/compact` 문구와 ② 직행 호출 프롬프트 **양쪽**에 C4 문장이 실렸는가 |
| V7 | `python3 plugins/spec-distill/scripts/check_brief.py metrics <payload>` 값이 예산 137 / 트립와이어 150 대비 어디인가 (기록만, 통과 조건 아님) |
| V8 | state의 `user_statements`와 payload §6을 눈으로 대조 — **기록된 발화가 빠짐없이** 옮겨졌는가. 게이트는 state를 읽지 않으므로 기계 검증 불가 |
| V9 | `statement` 2–3개를 표본으로 골라 인용된 `⟨S<N>⟩` 원문이 **실제로 그 요약을 뒷받침하는지**. bijection C는 존재만 보므로 남는 갭 |

- [ ] **Step 6: AC16 — 탐색 폭 회귀 검증 (advisory)**

구 brief(`docs/superpowers/interview/2026-07-20-spec-distill-interview-coverage-driven-*`)를 새 포맷으로 변환해 쌍을 만든다.

**변환 규칙 — 화이트리스트.** "내용 동일"은 성립할 수 없다(권위 문구를 지우는 것이 변환의 목적이므로):

- 허용: 섹션 재배치 · 섹션 재라벨 · **AC13의 6개 금지 문자열**과 §2 권위 헤더 문장 삭제 · 출처 기호(🗣/☑/✎) 부착 · `S<N>`/`ST<N>` id 부여
- 금지: 새 주장 추가 · 기존 주장 재서술 · 위 목록 밖의 정보 삭제

원 brief의 각 문장을 `{유지, 이동, 허용된 삭제}` 중 하나로 분류한 매핑을 남긴다. **"신규" 분류가 1건이라도 있으면 그 실행은 무효다** — 변환자가 포맷 설계 당사자이므로 무의식적 개선이 측정 대상을 "포맷"에서 "다시 쓴 내용"으로 바꿀 수 있다.

각각을 fresh 서브에이전트에 **동일 프롬프트**로 투입하고, `superpowers:brainstorming` 체크리스트 4번(*"Propose 2-3 approaches"*)의 발화 여부를 관측한다. 조건당 3회, 같은 superpowers 버전(6.2.0)·같은 모델로 통제. 결과는 이번 인터뷰의 audit에 기록한다.

**한계**: n=3은 통계적 검정력이 없고, 관측치는 이진이며, 하류가 6.2.0에서 *"Explore alternatives"* 원칙 줄을 잃었으므로 음성이 나와도 원인이 brief가 아닐 수 있다. **방향 전환의 근거가 아니라 Spec B 조준용 신호**로 쓴다 — 그래서 advisory이고, **어떤 결과도 shipping을 막지 않는다.**

- [ ] **Step 7: 발견된 결함을 고치고 커밋한다**

V1–V10 또는 AC16에서 결함이 나오면 **잡았어야 할 검증 층을 함께 고친다** — 코드만 패치하는 것이 아니라. 그 커밋이 compounding 이벤트다(Law 3).

```bash
git add -A plugins/spec-distill docs/superpowers/interview
git commit -m "fix(spec-distill): 수동 검증 V1-V10 반영"
```

결함이 없으면 이 커밋은 생략하고, V1의 실산출 brief 쌍만 커밋한다.

- [ ] **Step 8: PR을 연다**

```bash
git push -u origin feature/brief-format-producer
gh pr create --base main --title "feat(spec-distill): brief 포맷·producer 재설계 (Spec A, v0.23.0)" --body "$(cat <<'EOF'
## 무엇을

interview brief의 권위 문법을 **네 곳에서 동시에** 제거한다 — producer(`SKILL.md`) · 템플릿 · 게이트(`check_brief.py`) · `/compact` 핸드오프. 진짜 원인은 템플릿이 아니라 라운드마다 결정을 잠그고 해답공간 앵커까지 붙이던 producer였다.

## 왜

brainstorming stage가 해답공간 탐색을 하지 않았다. brief가 결정을 *"확정·재논쟁 금지"* 로 박제해 다음 세션의 잠재공간을 좁혔기 때문이다. 과거 brief의 LD 9/6/5는 모델의 과잉 잠금이 아니라 skill이 지시한 대로 동작한 결과다.

## 주요 변경

- **producer**: 라운드별 `locked?` decision table → 판정 없는 `user_statements` 기록
- **확정 권한**: 종료 시 사용자 일괄 확인으로 반환(기존 proceed 게이트에 흡수 — 상호작용 1회 유지, 재제시 상한 2회)
- **2파일**: payload(8섹션 역피라미드) + audit(텔레메트리), `audit_file`로 묶고 fail-closed
- **세 bijection**: payload↔audit / body↔frontmatter(statement 내용까지) / evidence→원문
- **회귀 락**: 권위 문법 6개 리터럴 + mutation 이빨 증명

## 검증

- spec: `docs/superpowers/specs/2026-07-25-spec-distill-brief-format-producer-design.md` (리뷰 5라운드, 32건 반영)
- plan: `docs/superpowers/plans/2026-07-26-spec-distill-brief-format-producer.md`
- T1–T24 기계 / V1–V10 수동 / AC16 탐색 폭 회귀(advisory)

## 후속

Spec B(brief-critic / 방향성 리뷰 / readback / codex 프롬프트 빌더)는 이 PR이 산출한 **실물 brief**를 입력으로 설계한다.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review

**1. Spec coverage** — AC1–AC16 전수 대조:

| AC | 태스크 | AC | 태스크 |
|---|---|---|---|
| AC1 | 6 (+V4 → 10) | AC9 | 1 (T7) |
| AC2 | 7 (+V1/V2 → 10) | AC10 | 1 (T2/T13) |
| AC3 | 7 (+V3 → 10) | AC11 | 4 (T10–T12/T17/T19) |
| AC4 | 1 (T1) + V8 → 10 | AC12 | 2 (T14) |
| AC5 | 4 (T18) | AC13 | 8 |
| AC6 | 2 (T3–T6/T22/T23) + V9 → 10 | AC14 | 9 (T20) + V6 → 10 |
| AC7 | 3 (T8/T9/T21/T24) | AC15 | 5 (T16) + V7 → 10 |
| AC8 | 8 + V5/V10 → 10 | AC16 | 10 |

T1–T24 전부 배정됨(T15는 Task 1의 회귀 카나리아). V1–V10 전부 Task 10. §7 Files to Modify 8파일 + 이 계획이 보강한 4파일(agents ×3, `test_conducting_interview_stage.sh`) 전부 태스크를 가짐.

**2. Placeholder scan** — "적절히 처리", "TODO", "Task N과 비슷하게" 없음. 픽스처 파생은 `cp` + 명시 편집 표로 구체화했고, 코드 스텝은 전부 실제 코드 블록이다. Task 5 Step 1의 빈 python 헤레독은 그 자리에서 대체 코드로 교체하도록 명시했다.

**3. Type consistency** — `parse_user_sourced_items(fm)`는 Task 2에서 `(items, raw)` 튜플을 반환하도록 정의했고, Task 3의 `bijection_b_errors`와 Task 2의 `bijection_c_errors`·`confirmed_zero_unsentineled`가 전부 `[0]` 인덱싱 또는 언패킹으로 소비한다. `find_missing_sections(text, sections=SECTIONS)`의 2번째 인자는 Task 1에서 추가되고 `gate()`가 `AUDIT_SECTIONS`로 호출한다. `section5_entries`는 Task 1이 정의하고 Task 4가 소비한다. `_frontmatter`는 Task 1이 정의하고 Task 2–5가 소비한다. `LINE_TRIPWIRE`·`STATEMENT_MAX`·`CONFIRMED_SENTINEL` 상수는 정의 태스크와 사용 태스크가 일치한다.

**4. 예상 테스트 총계** — `test_check_brief.sh` 39(T1) → 50(T2) → 59(T3) → 70(T4) → 75(T5). `test_conducting_interview_stage.sh` 77 → 84(T6) → 94(T7). `test_stale_terms.sh` 3 → 9(T8). `test_readme_sync.sh` 15 → 23(T9). 이 숫자는 **기대값이지 계약이 아니다** — assert를 더 촘촘히 쓰면 늘어난다. 각 스텝의 판정 기준은 `Fail: 0`이다.
