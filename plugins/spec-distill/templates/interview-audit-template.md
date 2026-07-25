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
