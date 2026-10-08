---
name: qg-v10-rebuild
type: design
created_at: 2026-10-08
source_interview: docs/superpowers/interview/2026-10-03-qg-v10-rebuild-interview.md
next_phase: superpowers:writing-plans
---

# qg v10 재건 · Design

> 오래된 부품이 문제가 아니라, 부품마다 박힌 옛 가정과 리뷰마다 장치를 덧붙여 온 공정이 문제다.

## Handoff Context

**TL;DR** — quality-gates(qg)를 지금 모델·Claude Code 위의 얇은 v10 으로 갈아끼운다. `/qg` 한 번이
차등 테스트 → 리뷰 → (선택) e2e → PR 코멘트까지 간다. 컷오버는 다섯 번이고 각각 독립 PR·릴리스다:
① 정리 → ② 리뷰 다이어트 → ③ 게시 → ④ e2e(이음매 완성) → ⑤ 차등 테스트. 옛 교훈은 락이 아니라
이 문서의 요구 목록(§요구 목록)으로 옮긴다.

**Implicit context** —
- 인터뷰 brief(`source_interview`)의 §2 확정 28건이 이 문서의 정답이다. 이 문서의 결정은 그 위에서
  brainstorming 이 OQ19~OQ30 을 닫은 결과다(§결정 기록).
- 재결정 규약: 확정 항목은 근거가 있으면 보고 후 재결정할 수 있고, 임의 변경은 금지다. 이 문서에는
  재결정이 다섯 있다(§결정 기록 재결정 R1~R5).
- 구성요소 조사는 qg 9.3.6 기준이다(2026-10-04, 읽기 전용 Explore 4건). 줄 번호 인용은 그 시점의 것이다.
- 범위 밖: `/qg critique`, spec-distill 공동 소유 docreview 엔진(D25). qg 의 critique 관련 파일은
  건드리지 않는다.
- 사용자 지시: 리뷰는 opus. 외부 플러그인 리뷰어를 쓰는 방식은 유지한다.

## 목차

- [Goals](#goals)
- [Non-goals](#non-goals)
- [Context / Why](#context--why)
- [Constraints](#constraints)
- [Architecture](#architecture)
  - [§1 흐름](#1-흐름)
  - [§2 리뷰와 다이어트](#2-리뷰와-다이어트)
  - [§3 차등 테스트](#3-차등-테스트)
  - [§4 e2e](#4-e2e)
  - [§5 게시](#5-게시)
  - [§6 진입·상태·그 밖의 부품](#6-진입상태그-밖의-부품)
  - [§7 컷오버](#7-컷오버)
  - [§8 헌장 세 줄](#8-헌장-세-줄)
- [요구 목록 (옛 교훈)](#요구-목록-옛-교훈)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives · Trade-offs](#rejected-alternatives--trade-offs)
- [알려진 한계](#알려진-한계)
- [결정 기록](#결정-기록)
- [Metadata](#metadata)

## Goals

- G1. `/qg` 한 번이 차등 테스트 → 리뷰 → (선택) e2e → PR 코멘트까지 이어서 가고, 사람이 믿고 판단할 검증
  보고를 낸다(C1).
- G2. e2e 신설 · 게시 백지 재건 · 게시 장치 걷기 · 리뷰 다이어트를 모두 중심으로 다룬다(C9).
- G3. 구성요소마다 가정을 다시 재어 삭제/새로/유지를 정하고, 부품 단위로 갈아끼운다(D17·D18).
- G4. 옛 qg 가 사고를 겪으며 얻은 교훈(거짓 clean·fail-open 수정)을 잃지 않는다 — §요구 목록.
- G5. 재건 공정이 다시 무거워지지 않는다 — 리뷰 라운드 멈춤 기준과 다음 사이클 후보 목록(§7).

## Non-goals

- 전체를 한꺼번에 백지에서 짓고 한 번에 갈아끼우는 것.
- `/qg critique`, spec-distill 공동 소유 docreview 엔진과 그 공유 파일(adjudication · render_disposition ·
  codex 공유 스크립트 · prompt-preamble)의 수정.
- qg 가 push 하거나 PR 을 만드는 것.
- Law 2 를 지키려고 과한 장치를 덧붙이는 것(C21).
- 외부 플러그인 리뷰어의 페르소나·모델 고정을 바꾸는 것.

## Context / Why

지금 qg 결과는 믿을 보고가 못 된다. 네 얼굴이 있다:
- 런타임을 걸어보지 않는다.
- PR 에 남지 않는다.
- 게시 장치가 무겁다.
- 과잉 처방이 판정을 쥐어 수정이 의도에서 벗어난다.

9.3.6 의 처방이 판정을 쥐는 자리는 둘이다. `synthesize_findings.py:899` 의 `defect=bool(kept)` 는
SUGGESTION 하나로도 defect 를 낸다. `SKILL.md:730` 의 Retry 는 남은 지적 전부의 제안 패치를 의도
대조 없이 적용한다.

뿌리는 둘이다(brief S14).
- **부품마다 박힌 옛 가정.**
  - `scout.py` 의 줄 수 depth 표
  - confidence ≤4 억제(9.3.x 패치 셋의 원천)
  - sonnet 고정 `feature-dev:code-architect`
  - 세션을 넘는 baseline 캐시(fail-open 사고 셋의 원천)
- **리뷰마다 장치를 덧붙여 온 공정.** 1주 전 재설계한 파이프라인 SKILL 이 955줄이고, 그 뒤 이틀 사이
  패치가 여섯 번 나왔다. 차등 테스트는 산문·스크립트 약 3,800줄에 테스트 약 6,100줄이다.

한꺼번에 잘라낸 하니스 단순화는 성능을 재현하지 못했고, 부품을 하나씩 뺄 때 통했다(brief §4
«harness-design»). 그래서 부품 단위로 가정을 다시 재고 하나씩 갈아끼운다.

## Constraints

brief §2 의 확정 28건(C1~C9 · D10~D14 · C15~C16 · D17~D19 · C20~C21 · D22~D26 · C27 · D28)이 그대로
제약이다. D28 은 R2(§결정 기록)로 재결정됐다. 이 문서가 더하는 제약은 brainstorming 에서 사용자가 정한
것이다.

- K1. 리뷰는 opus 다. qg 소유 리뷰 agent 는 `model: opus` 로 고정하고, 외부 `inherit` 리뷰어는 세션 모델을
  따른다(외부 플러그인의 모델 설정을 우회하지 않는다).
- K2. 외부 플러그인 리뷰어(pr-review-toolkit)를 쓰는 방식은 유지한다.
- K3. 이해글은 오케스트레이터가 직접 쓴다(사용자 선택 — 남는 위험은 §알려진 한계).
- K4. 컷오버는 부품 단위 제자리 교체다. 비교·롤백 기준인 옛판은 설치된 main 판이다(재결정 R5 — D18 의
  「옆에 세워」를 바꿈).
- K5. 표와 재건에 새 락·원장을 두지 않는다(D18). 테스트는 요구를 검증하는 것이고 새 장치가 아니다.

## Architecture

### §1 흐름

```
/qg
 ├ 진입 ── kill switch · 범위(git 기반: 브랜치 또는 Spec: 토픽)
 │         · 의도 출처 한 줄 공시 (Spec: 트레일러 → 커밋 메시지·PR 본문)
 ├ iteration (최대 5)
 │   ① 차등 테스트   오케스트레이터가 러너를 직접 호출
 │   ② 리뷰        기본 3 + 조건부 ≤4 → code-recritic → 합성 → 판정 한 줄
 │   막는 지적 또는 차등 defect → Fix-loop 게이트 (Retry / Accept / Stop)
 │       Retry: 「적용」 패치만 쓰고 「제외」는 공시 → 다음 iteration
 ├ e2e 질문 (루프 끝, 한 번) → 걷기 → 걷기 직후 게이트
 │   fail → Fix-loop 게이트 다시 (Retry 면 남은 iteration 에서 ①② 후 같은 승인 경로로 다시 걷기)
 ├ 최종 판정 ── clean / defect / not-certified(사유)
 └ 게시 ── sink 한 곳: 조건 확인 → secret-scan → 새 코멘트, 그 밖엔 한 줄 알림
```

판정은 `verdict.py` 하나가 정한다. 닫힌 열거이고 우선순위는 defect > not-certified > clean 이다. e2e 가
더하는 것은 아래 표뿐이다.

| e2e 결과 | 판정 |
|---|---|
| 승인된 pass | 불변(다른 축이 정함) |
| 승인된 fail | defect |
| 미확인 · 무효이고 다시 걷지 않음 | `not-certified (e2e-unconfirmed)` — REASONS 맨 뒤 |
| 안 한다 · 걸을 것 없음 · 걸을 도구 없음 · e2e kill switch | 불변 + 코멘트 공시 |

Stop·중단으로 끝난 실행(Final Summary `Outcome: aborted …`)은 게시하지 않는다.

**iteration 회계** — Retry 한 번이 iteration 하나를 쓴다. 걷기 직후 게이트의 「다시 걷기」는 iteration 을 쓰지
않는다. iteration 5 를 다 쓴 뒤 e2e 가 fail 이면 Fix-loop 게이트에서 Retry 를 빼고(Accept / Stop / pass 로
뒤집기) 지금의 Max-iter 처리와 같게 닫는다.

### §2 리뷰와 다이어트

**리뷰어 구성** (iteration 당 최대 8, 선언 ≤10 안)

| 자리 | agent | 모델 | 조건 |
|---|---|---|---|
| 정확성 | `pr-review-toolkit:code-reviewer` | opus (외부 고정) | 항상 |
| 보안 | `quality-gates:security-reviewer` | opus (고정, 새로) | 항상. 꺼지면 `not-certified (angle-absent)` |
| 다른 모델 계열 | codex 러너 | GPT 계열 | 항상 시도. 없으면 공시만 |
| 테스트 품질 | `pr-review-toolkit:pr-test-analyzer` | 세션 모델 | 테스트 파일 변경 |
| 조용한 실패 | `pr-review-toolkit:silent-failure-hunter` | 세션 모델 | 에러 처리·catch·fallback 변경 |
| 타입 설계 | `pr-review-toolkit:type-design-analyzer` | 세션 모델 | 새 타입·인터페이스 |
| 주석 | `pr-review-toolkit:comment-analyzer` | 세션 모델 | 주석·docstring 대량 변경 |
| 재비판 | `quality-gates:code-recritic` (새로) | opus (고정) | 항상(탐지 0건이어도) |

조건부 넷은 오케스트레이터가 규칙표를 보고 고른다. 삭제: `scout.py`, 6종 메뉴의 depth 안내,
`feature-dev:code-architect`.

**기준 블록** — 모든 리뷰어 dispatch(외부 포함)와 codex 프롬프트에 같은 블록을 싣는다.

| 막는 지적 (CRITICAL·IMPORTANT) | 선택 사항 (SUGGESTION) |
|---|---|
| 이 변경이 만들거나 고친 동작이 틀림 | 스타일·이름·구조 취향 |
| 의도 출처에 적힌 요구를 어김 | 추상화·일반화·방어 코드 추가 |
| 변경이 스스로 더하거나 고친 통제가 뚫리는 구체 경로 | 이 변경이 하지 않은 보안 강화·미래 대비 |

블록 앞에 `intent: <출처>` 한 줄과 그 내용을 싣는다. 출처는 `discover-spec.sh`(새로)가 D13 사슬로 정한다:
1. HEAD 쪽 커밋의 `Spec:` 트레일러가 가리키는 spec
2. 없으면 브랜치 커밋 메시지 + 열린 PR 본문

mtime 은 쓰지 않는다. PR 본문은 `discover-spec.sh` 가 읽기 전용 `gh pr view` 로 읽는다. gh 가 없거나 미인증이면
커밋 메시지만 쓰고 그 사실을 `intent:` 줄에 붙인다. codex 도 같은 기준 블록과 의도 출처를 받는다 — qg 소유
러너(`run_codex_reviewer.sh`)와 프롬프트 빌더(`build_codex_prompt.py`)가 spec AC 대신 이 둘을 싣는다.

**code-recritic** — qg 전용 재비판 agent 다. `tools: Read, Grep, Glob`, `model: opus`. 입력은 출처를 가린
지적 목록 + diff + 의도 출처 + 프로필(`references/recritic-code-profile.md`)이다.
- 관문 A~D 는 지금 문구를 옮긴다.
- 관문 D 에 경계 한 줄을 더한다: 「변경이 스스로 더하거나 고친 통제가 뚫리는 구체 경로를 짚으면 막는 지적이다」.
- **관문 E(처방 초과)** 를 새로 둔다. 변경이 하지 않은 일을 하라는 처방이고 이 변경에서 구체적 실패를 보이지
  못하면 `lower` 한다. 목적지는 `SUGGESTION` 하나뿐이고, `evidence` 에 의도 출처나 diff 를 인용해야 한다.
  근거 없는 `lower` 는 `confirm` 으로 강제하고 그 강제를 계수한다.
- 어휘는 confirm · reject(+evidence) · raise(+to, 위로만) · lower(+evidence, SUGGESTION 으로만) · same_as · added 다.

**합성·판정** (`synthesize_findings.py` 새로)
- 재비판 판정을 적용하고 dedup·정렬·렌더한다. 각도 회계(`angles.py`)와 판정(`verdict.py`)으로 넘긴다.
- **defect 입력 = 살아남은 CRITICAL·IMPORTANT 가 1건 이상.** SUGGESTION 은 로컬 결과에만 둔다(D14).
- confidence 필드와 억제를 걷는다. 오탐 거르기는 관문 A 가 맡는다.
- 공유 `adjudication.py` 를 그대로 import 한다(처분 회계, 축 B 락).

**Fix-loop 게이트와 Retry**
- 게이트는 막는 지적마다 「적용 / 제외(사유)」를 보인다. 오케스트레이터가 제안 패치를 의도 출처와 대조해
  정한다. 제외 사유는 셋이다: 변경 범위 밖 파일을 건드림 · 의도에 없는 동작·기능을 더함 · SUGGESTION.
- 그 분류는 기본값이다. 사용자는 게이트에서 항목별로 적용·제외를 바꿀 수 있다(SUGGESTION 을 넣는 것도 된다).
- **패치가 없는 defect**(차등 회귀 · 승인된 e2e fail)는 오케스트레이터가 고칠 계획을 직접 쓴다. 범위는 실패한
  단위나 불충족 기대 상태에 한정하고, 같은 의도 대조를 거쳐 같은 「적용 / 제외」 줄로 게이트에 보인다.
- Retry 는 「적용」 목록만 Edit 한다. 제외 목록은 로컬 결과에 남기고, 그 수를 판정 줄에 싣는다.
- 경로 안전 검사(realpath·commonpath)와 Edit 실패 처리(묻기)는 유지한다.

### §3 차등 테스트

요구 R1~R24(§요구 목록)를 지키는 얇은 새 기계다.

| 부품 | 처분 | 하는 일 |
|---|---|---|
| `resolve-baseline.sh` | 유지 | 베이스라인 사실 6개. 리뷰 범위 판정과 공유 |
| `seal-worktree.sh` | 유지 | 작업트리 전체(untracked 포함)를 커밋으로 봉인 |
| `qg-worktree.sh` | 줄임 | `create-baseline` · `create-head`(HEAD sha 재검증) · `remove` 만 |
| `run-test-selection.sh` | 새로 | `detect` · `assign` · `run` · `granularity` · `total`. 결과는 exit code 로만. 어댑터 9종 |
| `compute-test-scope-candidates.sh` | 새로, 얇게 | 후보 **바닥**: 이름 일치 · 바뀐 테스트 · `# guards:`. 모델은 더하기만 |
| `diff-test-results.py` | 새로 | 짝짓기·집계 + unclaimed 검사 흡수. 출력은 판정에 직접 |
| `baseline-cache.sh` · `probe` · `check_qa_ledger.py` · `test-scope-validator` · `discover-plan.sh` · R3 공백 게이트 | 삭제 | 지워도 조용히 통과하는 것이 없다 |
| `references/differential-test.md` | 새로 | 1013줄 → 요구 목록 + 짧은 절차 |

**실행 안 메모** — 한 번의 `/qg` 안에서 merge-base 는 고정이다. 베이스라인 행을 R-init 이 만든 리포 밖
임시 디렉토리에 두고 같은 실행의 다음 iteration 에서 재사용한다. 새 단위만 베이스라인을 다시 돌리고,
실행이 끝나면 지운다. 세션을 넘는 캐시는 없다.

### §4 e2e

**질문** — 리뷰·테스트 루프 뒤, 최종 판정 직전에 한 번 묻는다. aborted 이거나 e2e kill switch 가 켜져
있으면 묻지 않고 공시만 한다.
- 오케스트레이터가 diff 와 의도 출처로 시나리오 1~3개를 만든다. 시나리오마다 다음을 적는다:
  - 표면(웹 UI / API / CLI)
  - 부팅 명령(글자 그대로)과 그 출처(CLAUDE.md · README · package.json · Makefile 등)
  - 걸을 단계
  - 관측 가능한 기대 상태 목록
- 선택지는 시나리오들 / 걸을 것 없음(사유) / 안 한다이고, 「기타」로 고칠 수 있다.
- 걸을 표면이 없다고 판단해도 질문은 띄우고 「걸을 것 없음」을 첫 선택지로 둔다.
- 웹 UI 인데 브라우저 MCP 가 없으면 그 시나리오에 「걸을 도구 없음」을 표시한다.
- 시나리오를 고르는 것이 그 부팅 명령을 호스트에서 실행해도 된다는 승인이다.

**걷기**
1. `e2e-state.sh` 로 코드 상태 지문을 잰다: HEAD + 추적 파일 diff 내용 해시 + untracked 목록.
2. 승인된 명령으로 앱을 백그라운드로 띄우고 준비 신호(포트·로그 줄)를 기다린다.
3. 웹은 브라우저 MCP(접근성 트리 스냅숏)로, API·CLI 는 Bash 로 걷는다.
4. 승인된 명령이 띄운 로컬 origin 만 걷는다. 파일 업로드와 외부 origin 이동은 하지 않는다.
5. 걷다 버그를 보면 고치지 않고 기록한다. 고침은 Retry 로만 한다.
6. 띄운 프로세스는 모든 종료 경로에서 내린다.
7. 지문을 다시 잰다. HEAD 나 추적 파일 diff 내용 해시가 다르면 판정안은 「무효(코드 변경)」다. 새 untracked
   파일은 목록으로 보인다.

**증거표와 판정안** — 기대 상태마다 관측(도구 출력 원문 인용)과 판정(충족 / 불충족 / 미확인)을 적는다.
판정안은 셋 중 하나다:
- 전부 충족이면 pass
- 하나라도 불충족이면 fail
- 불충족 없이 미확인이 있으면 미확인

**걷기 직후 게이트** (D22 의 reviewer = 감독하는 사람)

| 판정안 | 선택지 |
|---|---|
| pass | 승인 / fail 로 뒤집기 / 다시 걷기 |
| fail | Fix-loop 게이트(Retry / Accept / Stop) + pass 로 뒤집기 |
| 미확인 · 무효 | 다시 걷기 / 그대로 둠 |

뒤집기는 한 줄 사유를 받아 로컬 결과에 남기고, 판정 줄에 「사람이 뒤집음」으로 표시한다. Retry 뒤 다시
걸을 때는 같은 승인 경로·명령을 쓰고 경로 질문은 생략하며, 걷기 직후 게이트는 매번 띄운다.

**범위** — e2e 는 현재 체크아웃만 걷는다. 토픽 스코프가 다른 브랜치를 묶었으면 그 사실을 공시한다.
kill switch 는 `DEVBREW_QUALITY_GATES_DISABLE_E2E=1` 하나다. 파일은 `references/e2e.md`,
`scripts/e2e-state.sh`, `tests/fixtures/e2e-app/` 이다. agent 는 없다(C20).

### §5 게시

게시의 모든 통제를 sink 스크립트 `scripts/publish-comment.sh` 한 곳에 둔다. gh **쓰기**(코멘트)는 이 sink
하나만 한다. 오케스트레이터는 gh 를 직접 부르지 않고, 리뷰 전 읽기는 `discover-spec.sh` 의 읽기 전용
`gh pr view` 하나뿐이다(§2). sink 는 다음 순서로 동작한다.

1. `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` 확인(코드)
2. gh 존재·인증 확인(부작용 전)
3. `gh pr view` 로 현재 브랜치의 열린 PR 번호 확인
4. corpus 생성(변경 파일 내용 + 커밋 메시지, merge-base 가 없으면 degraded 헤더) → `secret-scan.py`.
   첫 줄 리터럴 `scan_ok: yes` 로만 통과
5. 길이가 65,536자를 넘으면 자르지 않고 건너뜀
6. `gh pr comment <n> --body-file <파일>`
7. 마지막 줄 리터럴 `posted: <url>` 또는 `skipped: <사유>`

**건너뛰는 경우** — 모두 한 줄 알림이고 gh 코멘트 호출은 0 이다. aborted 는 파이프라인이 sink 를 부르지 않고
직접 한 줄을 낸다. 나머지 여섯은 sink 가 `skipped: <사유>` 로 낸다:
- PR 없음
- PR 닫힘·머지
- kill switch
- scan 실패
- gh 없음·미인증
- 길이 초과

**코멘트** — 오케스트레이터가 코드를 안 읽는 사람 기준으로 한국어로 쓴다.

```
## <이 변경을 한 줄로>
<무엇이 바뀌나 — 2~3문장>
**전 → 후**  <짧은 표 또는 두 줄>
**어떻게 확인했나**  <차등 테스트·e2e 를 한두 줄로>

---
qg: <판정>[ (<사유>)] · 막는 지적 N · 선택 M · 차등 새 실패 K · e2e <상태> · 제외 패치 X · iter I · <short sha>
```

이해글과 판정 줄은 오케스트레이터가 그 실행의 결과에서 만든다. 지적 목록·SUGGESTION·증거표는 로컬 결과에만
남는다(D24). 마커·upsert·identity·다이어그램·tier·`--history` 는 없다.

### §6 진입·상태·그 밖의 부품

| 부품 | 처분 | 근거 |
|---|---|---|
| `commands/qg.md` | 새로, 얇게 | `--reset`·`--gc` 의 ```` ```! ```` 펜스 제거. `critique` 라우팅 블록은 그대로 |
| `scripts/setup-qg.sh` | 새로, 최소 | kill switch · SID 가드(패턴 `[A-Za-z0-9_-]{8,}`) · 인자 거부 |
| `/qg branch <name>` | 삭제 | 만든 worktree 안에서 파이프라인이 일하지 않는다(재결정 R4). 인자 표면은 아래 |
| `qg-worktree.sh` `create`·`sanitize`·`validate` | 삭제 | branch 모드 전용 |
| `create-sandbox`·`mutation-guard` | plugin-audit 로 이전 | qg 는 안 쓴다. plugin-audit `run-own-tests.sh` 의 하드코딩 경로·`quality-gates ≥ 2.12.0` 선언 제거 |
| `/cancel-qg` + `cancel-qg-core.sh` · `hooks/*` · `state_path.py` · `devbrew-python.sh` 사본 · `read-frontmatter.py` | 삭제 | 단일 턴이고 남길 worktree 가 없다. 남은 상태는 TTL GC |
| `qg-gc.py` · `gc_common.py` · `kill_switch_active.py` | 유지·갱신 | 로컬 결과 폴더 TTL 정리(setup 이 호출). `qg-gc.py` 의 세션 표지 목록에 `result.md` 를 더하고 사라지는 표지(`pipeline.md` 등)를 뺀다 — 안 그러면 새 결과 폴더가 정리되지 않는다 |
| 로컬 결과 | 새로 | `.claude/quality-gates/<sid>/result.md`: 지적 전부 · SUGGESTION · 증거표 · 제외 패치 · 뒤집기 사유 |
| `references/state-file-format.md` | 새로 | 위 형식 |
| `check-trivia.sh` | 삭제 | 오케스트레이터 판단으로 대체. 사유 `trivia` 는 유지 |
| `discover-spec.sh` · `discover_common.sh` | 새로 / 삭제 | D13 사슬(§2). codex 의 spec AC 입력도 여기서 |
| 토픽 스코프 넷 · `check-review-scope.sh` · `angles.py` · `verdict.py` | 유지 | `verdict.py` 는 `e2e-unconfirmed` 추가 |
| codex 사슬 | 유지·갱신 | qg 소유 `run_codex_reviewer.sh`·`build_codex_prompt.py` 가 spec AC 대신 기준 블록과 의도 출처를 싣고 confidence 필드를 뺀다(§2). 공유 파일 무변경 |
| `security-reviewer.md` | 유지·갱신 | `model: opus`, 기준 블록 반영, 「cutoff < 7」 등 낡은 문구 정리. custody·위치 토큰 범주 유지 |
| `doc-recritic.md` 사본 · `recritic_bridge.py` | 삭제 | code-recritic 으로 대체(R1) |
| `render-terminal.py` | 줄임 | `table` 만 |
| scout · filter-docs · discover-plan · check-changelog-korean-primary · check-allowed-tools-order · experiment-model-override · gate3·test-scope fixture | 삭제 | 실행자가 없거나 옛 비용 가정 |
| README | 다시 씀 | Cost Class·파이프라인 흐름·Recipes 의 낡은 서술 정리 |

**인자 표면**

| 인자 | v10 | 컷오버 |
|---|---|---|
| 맨 `/qg` | 유지 — git 기반 범위(브랜치 또는 Spec: 토픽) | — |
| 맨 `/qg branch` | 유지 — 범위가 비었을 때 브랜치 전체로 다시 보는 복구 경로 | — |
| `--paths <glob>…` | 유지 — 범위 좁히기 | — |
| `critique …` | 그대로(범위 밖) | — |
| `branch <name>` · `--reset` · `--gc` · `--pr-url` | 삭제 — 제거 안내 한 줄을 내고 끝남. GC 는 setup 이 자동으로 돈다. `--pr-url` 은 값을 출력만 하고 소비자가 없다 | ① |
| `--plan` | 삭제 — 제거 안내 한 줄 | ⑤(`discover-plan.sh` 와 함께) |

**kill switch 목록** (`DEVBREW_QUALITY_GATES_` 접두)

| 스위치 | v10 | 컷오버 |
|---|---|---|
| `DISABLE`(전체) · `DISABLE_CODEX` · `DISABLE_DIFFERENTIAL_TEST` · `DISABLE_SECURITY_REVIEWER` · `DISABLE_PUBLISH` · `DISABLE_WEB` | 유지 | — (`DISABLE_PUBLISH` 집행은 ③에서 sink 로) |
| `DISABLE_E2E` | 새로 | ④ |
| `DISABLE_BRANCH_WORKTREE` · `KEEP_WORKTREE` | 삭제(branch 모드와 함께) | ① |
| `DISABLE_RUNTIME_SANDBOX` | plugin-audit 로 이전, `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX` 로 개명 | ① |
| `DISABLE_SPEC_CONFORMANCE` | 삭제 — codex 입력이 spec AC 에서 의도 출처로 바뀐다 | ② |
| `DEVBREW_SKIP_HOOKS` 의 `quality-gates:session-start-advisor`·`session-end-cleanup` 토큰 | 삭제(훅과 함께). `quality-gates:qg-gc` 는 유지 | ① |

### §7 컷오버

다섯 번의 독립 PR·릴리스다. 버전 번호는 머지 직전에 정한다.

| # | 내용 | 컷오버 조건 |
|---|---|---|
| ① 정리 | **대체물이 필요 없는 삭제만**: branch 모드 · `/cancel-qg` · 훅 · `state_path.py` · `devbrew-python.sh` 사본 · `read-frontmatter.py` · `filter-docs.sh` · `check-changelog-korean-primary.py` · `check-allowed-tools-order.sh` · `experiment-model-override.md` · gate3 fixture · 인자 넷 · plugin-audit 이전 · `qg-gc.py` 표지 갱신 · CLAUDE.md deprecation 조건 | qg·shared·plugin-audit 스위트 · E1~E6 테스트 · 개념 별칭 삭제 스윕 0 |
| ② 다이어트 | §2 전부 · discover-spec(gh 읽기 포함) · codex 입력 갱신 · trivia 판단 + 그 대체로 지워지는 `scout.py` · `feature-dev:code-architect` · `check-trivia.sh` · `doc-recritic.md` 사본 · `recritic_bridge.py` · 로컬 결과 `result.md` | V1~V12 테스트(변이로 이빨 확인) · 재생 비교 통과(AC8) · persona 편집이라 보안 리뷰 |
| ③ 게시 | §5 전부 · 즉시 제거 · P21 앵커 · P17 · description · pr-process.md | P1~P7 테스트(변이로 이빨 확인) · 실제 PR 1회 게시 · sink 건너뛰기 여섯 경우 · aborted 미호출 |
| ④ e2e | §4 전부 · P4 · 이음매 AC | X1~X4 테스트 · fixture 앱 버그 브랜치에서 fail 포착 · 실제 앱 프로젝트 1회 |
| ⑤ 차등 | §3 전부 + 마지막 소비자와 함께 지워지는 `discover-plan.sh` · `discover_common.sh` · `test-scope-validator` · test-scope fixture · `--plan` | R1~R24 테스트(변이로 이빨 확인) · 같은 입력에서 옛판과 같은 범주 |

**삭제 규칙** — 부품은 그것의 대체물이 실리는 컷오버, 또는 그것의 마지막 소비자가 사라지는 컷오버에서 지운다.
그래야 각 중간 릴리스가 혼자 온전하다.

**공정**(OQ25)
- 컷오버 PR 마다 리뷰 라운드는 최대 2 다. 같은 자리에 새 차단이 또 나오면 라운드를 더 돌지 않고 층위를 의심한다.
- 그 변경의 결함이 아닌 「새 장치 추가」 지적은 아래 다음 사이클 후보 목록으로 보낸다.

**다음 사이클 후보** — (비어 있음. 컷오버 리뷰가 채운다.)

### §8 헌장 세 줄

| 자리 | 문장 | 컷오버 |
|---|---|---|
| `docs/philosophy/devbrew-harness-philosophy.md` P4 | 기존 문장 「지금 devbrew 에는 runtime tier 의 집행 코드가 없다 — qg 는 … runtime tier 를 주장하지 않는다」를 **대체**: 「qg 는 runtime tier 를 사람이 승인하는 e2e 걷기로 집행한다 — 오케스트레이터의 판정은 판정안이고 reviewer 는 감독하는 사람이다(Law 2 해석)」. P4 코드 앵커에 `plugins/quality-gates/references/e2e.md` 를 더한다 | ④ |
| 같은 문서 P17 | 「qg 의 매 실행 PR 코멘트 게시는 사용자의 상시 동의다」 | ③ |
| `CLAUDE.md` 메타데이터 절 | 「사용자가 명시 결정한 재건은 deprecation 창 없이 제거하고 CHANGELOG Removed 에 적는다」 | ① |

P21 의 코드 앵커 `comment-upsert.py` 는 ③에서 `publish-comment.sh` 로 옮긴다. `shared/tests/test_charter_citations.sh`
가 그것을 잰다.

## 요구 목록 (옛 교훈)

각 줄의 형식은 「요구 — 출처 — 지우면 조용히 통과하는 것」이다. 버전은 qg CHANGELOG 기준이고, 테스트는 요구
번호를 이름에 싣는다.

**차등 테스트**
- R1 0 단위·0 어댑터는 `not-certified (scope-empty)` 다 — 3.0.0 iter-3 · 9.0.0 — 빈 실행의 clean
- R2 어느 축이든 error 는 인증을 막고, (pass, error) 는 NEW_REGRESSION 이다 — 3.0.0 AC61 — 크래시의 PRE_EXISTING 위장
- R3 exit 127·러너 없음·setup 실패는 unrun 이고 (unrun, x) 는 baseline-unrunnable 이다 — 3.0.0 — 도구 부재의 PRE_EXISTING 위장
- R4 0/1/127 밖의 exit 는 unrun 으로 접지 않는다 — iter-2 revert — pytest exit 2 회귀의 은폐
- R5 baseline 행은 baseline 트리에서 실제로 돈 것만 유효하다 — AC60 · SR1 — 심은 pass
- R6 실행 안 메모는 리포 밖에 살고 실행과 함께 사라진다 — 2.x 캐시 사고 — 세션 넘는 오염
- R7 단위마다 축별 정확히 한 행이다. 누락은 SILENT_DROP, 중복은 hard error — 3.0.0 — 행 증발
- R8 expected 목록은 두 결과 파일과 독립인 입력이다 — 3.0.0 — 결과가 스스로 분모를 정함
- R9 bulk·smear 의 양쪽 red 는 `granularity-smear` 이고, granularity 는 러너에서 도출한다 — iter-6 C5 — 거친 실행의 회귀 은폐
- R10 per-unit 의 양쪽 red 는 차단하지 않고 공시한다 — 9.x 설계 §6.4.2 — (과차단 방지)
- R11 HEAD 축은 작업트리 전체를 봉인한 별도 트리이고, live worktree 는 쓰지 않는다 — 8.1.0 · 9.0.0 — 미커밋 변경 누락
- R12 HEAD sha 가 baseline 과 같으면 거부한다 — 9.0.0 — 전부 STILL_GREEN
- R13 same_as_head + clean tree 는 not-certified 다 — iter-3/4 — 비교 없는 clean
- R14 baseline 트리는 어댑터를 스스로 다시 탐지한다 — AC47 — 한쪽에만 있는 러너
- R15 flaky 는 NEW_REGRESSION 만 HEAD 트리에서 정확히 1회 재실행하고, 실패하면 원래 행을 유지한다 — 3.0.0 — 무한 재시도의 거짓 green
- R16 고른 단위를 어느 어댑터도 못 돌리면 막는다 — 3.0.0 — 안 돈 테스트의 clean
- R17 생산자 실패를 「비었음」으로 읽지 않는다 — iter-7 — 후보 0 의 거짓 범위
- R18 짝짓기·집계의 non-zero exit·판독 불가 키는 `not-certified (error-axis)` 다 — 9.0.0 — 기계 고장의 clean
- R19 산출 파일 수 ≠ 어댑터 수이면 집계를 거부한다 — M25 · F11 — 부분 집계
- R20 단위는 worktree 안에 있어야 하고, shell 단위는 `tests/*.sh` +x 다. assign·run 양쪽에서 검사한다 — I5 — 경로 탈출 실행
- R21 unittest 는 못 판정하는 파일을 claim 하지 않고, go 단위는 `*_test.go` 를 요구한다 — 3.0.0 — 공허한 exit 0
- R22 kill switch 는 오케스트레이터와 러너 양쪽에서 repo 코드 실행을 막는다 — 9.0.0 · 9.1.0 — 산문만의 보안 통제
- R23 일회용 트리는 모든 종료 경로에서 제거한다 — F8c — 세션이 clean 에 못 돌아감
- R24 판정은 기계 출력을 직접 읽고 모델 전사를 거치지 않는다 — 3.0.0 — 전사 오류의 clean

**리뷰·판정**
- V1 판정 어휘는 `verdict.py` 의 닫힌 열거 하나이고, 「검증 못 했다」는 일급 값이다 — 9.0.0 — 미검증의 clean
- V2 합성기의 rc·빈 stdout 은 clean 이 아니다 — 2.14.15~17 · 4.3.3 · 8.5.0 — 크래시의 clean
- V3 파손·누락된 finding 은 막는다(silent-drop · findings-lost) — 9.0.0 — 지적 증발
- V4 재비판 출력 부재는 clean 이 아니다 — 8.5.0 — 검증 단계 사망의 clean
- V5 보안 각도가 없으면 `not-certified (angle-absent)` 다 — 9.0.0 — 보안 리뷰 없는 clean
- V6 codex 산출물은 실행 전에 비운다. 0바이트·`codex_failed`·키 누락은 degraded 이고, 공시하되 막지 않는다 — 3.1.0 · 3.4.0 — 직전 실행 결과의 재사용
- V7 리뷰 범위가 비었는데 커밋이 있으면 거짓 clean 을 막는다(`check-review-scope.sh` 독립 신호) — 2.6.0 · 5.0.0 — 빈 범위의 clean
- V8 결측 필드를 낙관값으로 채우지 않는다 — 9.3.1 — 결측의 통과
- V9 Retry 경로는 realpath·commonpath 로 프로젝트 안에 가두고, Edit 실패는 묻는다 — 1.32.1 I10 · I6 — 심링크 탈출 쓰기 · 조용한 누락
- V10 결정론 백스톱은 오케스트레이터가 직접 부르고, subagent 자기 보고로 대체하지 않는다 — 3.0.0 LD5 — 요약된 증거
- V11 비신뢰 신원 문법은 `fullmatch` 로 검사한다 — 8.5.0 — 개행 꼬리 우회
- V12 리뷰어 dispatch 는 `project_dir` 를 명시한다 — 1.14.0 — 워크트리 오인

**게시**
- P1 secret-scan 통과는 첫 줄 리터럴 `scan_ok: yes` 로만 본다 — 2.7.0 — 파이프가 삼킨 exit code
- P2 scan 예외·degraded corpus 는 fail-closed 다 — 2.9.0 — 스캔 실패의 게시
- P3 kill switch 는 가장 안쪽 sink 의 코드가 집행한다 — 6.0.0 — 산문 우회 게시
- P4 본문은 `--body-file` 불투명 바이트로 넘긴다 — 2.9.0 — 셸 해석
- P5 부작용 전에 gh 인증을 확인한다 — 2.9.0 — 반쯤 된 부작용
- P6 sink 결과는 리터럴 줄로 읽는다 — 2.9.0 — 실패의 성공 위장
- P7 diff·커밋 메시지는 비신뢰 데이터다 — P21 — 주입된 지시

**진입·안전**
- E1 빈 SID 나 패턴 밖 SID 로 `rm -rf` 하지 않는다 — 1.32.1 TQ-2 — 형제 세션 삭제
- E2 플러그인 루트를 cwd 로 대체하지 않는다 — 7.6.1 — 리포 스크립트 실행
- E3 skill 본문에 셸 위치 인자(`$1`)를 쓰지 않는다 — 7.6.0 — Skill 인자 치환
- E4 GC 는 `safe_rmtree`·루트 탈출 검사·심링크 루트 거부를 한다 — 3.4.0 · 7.5.3 — 루트 밖 삭제
- E5 kill switch 는 전체 토큰으로 일치시킨다 — 1.6.2 — 형제 훅 오살
- E6 repo git 훅을 끈다(`core.hooksPath`) — 9.1.0 — 리뷰 대상 훅 실행

**e2e (새로)**
- X1 pass 는 기대 상태마다 관측 증거가 인용될 때만 성립한다(D10)
- X2 걷기 중 추적 파일이 바뀌면 그 판정안은 무효다(OQ29)
- X3 승인된 명령이 띄운 로컬 origin 만 걷고, 업로드·외부 이동은 하지 않는다 — 2.12.0 MCP 유출 교훈
- X4 띄운 프로세스는 모든 종료 경로에서 내린다

## Acceptance Criteria

**이음매** (e2e → 판정 → 코멘트, D28)
- AC1 승인된 e2e fail 은 판정 defect 가 되고, 게시된 코멘트의 판정 줄이 `qg: defect` 와 `e2e fail` 을 함께 싣는다.
- AC2 다른 축이 clean 일 때 e2e 미확인을 「그대로 둠」으로 닫으면 판정이 `not-certified (e2e-unconfirmed)` 이고,
  판정 줄도 같다. 다른 축에 defect 나 앞선 사유가 있으면 판정은 그대로이고 e2e 칸에 「미확인」이 나온다.
- AC3 「안 한다」 · 「걸을 것 없음」 · 「걸을 도구 없음」은 다른 축이 정한 판정을 바꾸지 않고, 판정 줄의 e2e 칸에 그 상태가 나온다.

**리뷰 다이어트**
- AC4 재비판 뒤 SUGGESTION 만 남고 다른 축이 clean 이면 판정은 clean 이다.
- AC5 재비판 뒤 IMPORTANT 가 1건 남으면 판정은 defect 다.
- AC6 code-recritic 의 `lower` 는 SUGGESTION 으로만 적용된다. evidence 없는 `lower` 는 confirm 으로 강제되고 강제 수가 계수된다.
- AC7 Fix-loop 게이트가 막는 지적마다 적용/제외와 사유를 보이고, Retry 뒤 제외된 패치의 대상 줄은 바뀌지 않으며, 판정 줄의 「제외 패치」 수가 제외 목록 길이와 같다.
  사용자가 게이트에서 바꾼 분류가 Retry 에 그대로 반영된다. 패치가 없는 defect(차등 회귀 · e2e fail)의 고칠 계획도
  같은 적용/제외 줄로 게이트에 나온다.
- AC8 사람이 고른 과거 결함 diff(옛 qg 가 막은 것) 전부에서 v10 리뷰가 각 결함을 막는 지적으로 낸다 — 컷오버 ② 의 조건.
- AC9 매 실행 출력에 `intent:` 줄이 정확히 한 번 나오고, `discover-spec.sh` 는 파일 mtime 을 읽지 않는다.
  같은 의도 출처와 기준 블록이 codex 프롬프트에도 들어간다. gh 가 없으면 `intent:` 줄이 그 사실을 싣는다.
- AC10 `security-reviewer`·`code-recritic` frontmatter 는 `model: opus` 와 `tools: Read, Grep, Glob` 이다.
- AC11 `scout.py` 와 `feature-dev:code-architect` 가 qg 어디에서도 dispatch 되지 않는다.

**게시**
- AC12 열린 PR 이 있는 정상 실행은 새 코멘트를 정확히 하나 만들고, 기존 코멘트를 수정하지 않으며, sink 의 마지막 줄이 `posted: <url>` 이다.
- AC13 sink 가 건너뛰는 여섯 경우(PR 없음 · PR 닫힘·머지 · kill switch · scan 실패 · gh 없음·미인증 · 길이 초과) 각각에서
  sink 의 마지막 줄이 `skipped: <사유>` 이고 gh 코멘트 호출이 0 이다. aborted 실행은 sink 를 부르지 않고 한 줄을 낸다.
- AC14 kill switch 가 켜진 채 sink 를 직접 불러도 네트워크 호출이 0 이다.
- AC15 gh 를 호출하는 qg 파일은 둘뿐이다: `publish-comment.sh`(코멘트 생성과 그 앞의 인증·PR 확인)와
  `discover-spec.sh`(읽기 전용 `gh pr view`). gh 쓰기는 `publish-comment.sh` 에만 있다.
- AC16 Files to Modify ③ 의 삭제 대상과 `/qg-publish` 표면이 없고, `shared/tests/test_charter_citations.sh` 가 green 이다.

**e2e**
- AC17 걷기 중 추적 파일을 바꾸거나 HEAD 를 옮기면 판정안이 「무효(코드 변경)」로 바뀐다.
- AC18 증거 인용이 없는 기대 상태가 하나라도 있고 불충족이 없으면 판정안이 미확인이다.
- AC19 `tests/fixtures/e2e-app` 의 버그 주입 브랜치에서 `/qg` 를 돌리면 e2e 판정안이 fail 이고, 승인하면 판정이 defect 다.
- AC20 `DEVBREW_QUALITY_GATES_DISABLE_E2E=1` 이면 e2e 질문이 뜨지 않고 판정 줄에 그 사실이 나온다.
- AC21 걷기가 어느 경로로 끝나든 승인된 명령이 띄운 프로세스가 남지 않는다.

**차등 테스트**
- AC22 R1~R24 각각에 이름이 그 번호를 싣는 테스트가 있고, 요구를 깨는 변이에서 그 테스트가 RED 다.
- AC23 같은 입력(이 리포의 브랜치 하나 이상)에서 v10 과 설치된 main 판의 차등 범주가 같다.

**정리·헌장**
- AC24 §6 의 삭제 대상이 없고, 개념 별칭(이름 · 표면 · §6 kill switch 목록의 삭제·개명 환경 변수) 스윕이 0건이며, plugin-audit 스위트가 이전된 스크립트로 green 이다.
- AC25 `/qg branch <name>` · `--reset` · `--gc` · `--pr-url` · `--plan` 은 각각 제거 안내 한 줄을 내고 끝난다. 맨 `/qg branch` 와 `--paths` 는 동작한다.
- AC26 §8 의 세 문장이 각 자리에 있고, P4 의 옛 「runtime tier 를 주장하지 않는다」 문장은 없으며, P4 코드 앵커가 `references/e2e.md` 를 인용한다.
- AC27 각 컷오버의 중간 릴리스에서 qg 가 참조하는 스크립트·agent 가 모두 실재한다(삭제 규칙, §7).
- AC28 `qg-gc.py` 가 `result.md` 만 가진 만료 폴더를 지운다.

## Files to Modify

**① 정리**
- 삭제:
  - `plugins/quality-gates/scripts/{filter-docs.sh,check-changelog-korean-primary.py,check-allowed-tools-order.sh,experiment-model-override.md,cancel-qg-core.sh,read-frontmatter.py,state_path.py,devbrew-python.sh}`
  - `plugins/quality-gates/commands/cancel-qg.md`, `plugins/quality-gates/hooks/`
  - `tests/fixtures/gate3/` 와 대응 테스트
- 수정:
  - `plugins/quality-gates/scripts/qg-worktree.sh` (branch·sandbox 하위명령 제거)
  - `scripts/qg-gc.py` (세션 표지에 `result.md`)
  - `scripts/setup-qg.sh`, `commands/qg.md`, `skills/quality-pipeline/SKILL.md`(branch·`--reset`·`--gc`·`--pr-url` 문단), `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`
- plugin-audit:
  - 추가: `plugins/plugin-audit/scripts/` 에 sandbox·mutation-guard
  - 수정: `run-own-tests.sh`, `README.md`, `skills/auditing-plugins/SKILL.md`, 해당 테스트, `plugin.json`
- 헌장: `CLAUDE.md` 메타데이터 절 한 줄
- shared: `shared/tests/test_python_floor.sh` — qg 의 `devbrew-python.sh`·`hooks.json`·두 훅을 목록과 resolver
  테스트 대상으로 핀한다. 지우는 파일을 그 목록과 대상에서 뺀다.

**② 다이어트**
- 추가: `plugins/quality-gates/agents/code-recritic.md`
- 수정:
  - `references/recritic-code-profile.md`
  - `scripts/synthesize_findings.py`, `scripts/verdict.py`(defect 입력)
  - `scripts/discover-spec.sh`(D13 사슬 + 읽기 전용 `gh pr view`), `scripts/run_codex_reviewer.sh`, `scripts/build_codex_prompt.py`
  - `agents/security-reviewer.md`
  - `skills/quality-pipeline/SKILL.md`(리뷰·Fix-loop·trivia 절), `references/state-file-format.md`(`result.md`)
- 삭제: `agents/doc-recritic.md`, `scripts/recritic_bridge.py`, `scripts/scout.py`, `scripts/check-trivia.sh` 와 대응 테스트
- shared: `shared/tests/test_docreview_copy_set.sh` EXPECTED 한 줄
- 헌장: `docs/philosophy/devbrew-harness-philosophy.md` P11 코드 앵커(`agents/doc-recritic.md` 인용)를
  `agents/code-recritic.md` 로 옮긴다. 안 옮기면 `shared/tests/test_charter_citations.sh` 가 RED 다.

**③ 게시**
- 추가: `scripts/publish-comment.sh`
- 수정: `scripts/secret-scan.py`(degraded 헤더 계약을 새 corpus 와 맞춤)
- 삭제:
  - `commands/qg-publish.md`, `skills/publishing-pr-understanding/`, `agents/pr-understanding-builder.md`
  - `scripts/{comment-upsert.py,gh-identity.sh,pr-create.sh,pr-detect.sh,build-pr-context.sh,diagram-facts.sh}`
  - `render-terminal.py` 의 두 하위명령
  - 대응 테스트(뒤집을 것은 뒤집기)
- 헌장·소비자:
  - `docs/philosophy/devbrew-harness-philosophy.md`(P17 · P21 앵커)
  - `.claude-plugin/marketplace.json`, `shared/tests/test_charter_citations.sh` 리터럴
  - `docs/git-workflow/pr-process.md`, `plugins/project-init/templates/shared/pr-process.md`(+ project-init `plugin.json`)

**④ e2e**
- 추가: `references/e2e.md`, `scripts/e2e-state.sh`, `tests/fixtures/e2e-app/`
- 수정: `scripts/verdict.py`(`e2e-unconfirmed`), `skills/quality-pipeline/SKILL.md`, P4

**⑤ 차등**
- 수정(다시 씀):
  - `scripts/{run-test-selection.sh,diff-test-results.py,compute-test-scope-candidates.sh}`
  - `references/differential-test.md`
  - 차등 테스트들
- 삭제: `scripts/{baseline-cache.sh,check_qa_ledger.py,discover-plan.sh,discover_common.sh}`, `agents/test-scope-validator.md`,
  `tests/fixtures/test-scope/`, `--plan` 인자 문단

## Verification Plan

- 컷오버마다 그 PR 이 닿은 소비자 스위트 전부를 돌린다: qg `tests/`, `shared/tests/`, plugin-audit, project-init.
  스위트는 리포 루트에서 돈다. 착수 전에 base 의 RED 를 줄 수와 함께 캡처한다(선재 RED 와 새 실패 구분).
- 통과가 정답인 테스트는 변이로 이빨을 확인한다. 부재 락에는 양의 짝을 둔다.
- ② **재생 비교**:
  1. 사람이 과거 결함 diff 를 고른다(CHANGELOG 사고와 qg 리뷰가 막은 실제 버그).
  2. 설치된 main 판과 브랜치 판을 같은 diff 에 돌린다.
  3. v10 이 각 결함을 막는 지적으로 내는지 본다. 하나라도 놓치면 컷오버하지 않는다. 한 번 재는 측정이고 락으로 남기지 않는다.
- ③ 실제 열린 PR 하나에 `/qg` 를 돌려 코멘트 1건을 확인한다. sink 건너뛰기 여섯 경우는 gh 스텁으로, aborted 는
  파이프라인 경로로 확인한다.
- ④ fixture 앱의 정상·버그 브랜치 두 개로 pass·fail 을 걷는다. 릴리스 전 사용자의 실제 앱 프로젝트에서 한 번 걷는다.
- ⑤ 같은 브랜치에서 옛판·새판의 차등 범주를 비교한다.

## Rejected Alternatives · Trade-offs

| 대안 | 기각 이유 |
|---|---|
| 1st-party `/code-review` 로 탐지·검증 대체 | 다이어트 지렛대(dispatch 프롬프트·재비판)를 잃는다. 로컬에서 REVIEW.md 를 안 읽고 cleanup 을 낸다. qg 가 모델 호출로 부를 수 있는지 미확인이다 |
| qg 소유 정확성 리뷰어 신설 | 사용자가 외부 플러그인 방식 유지를 골랐다(K2). 대가: code-reviewer 페르소나(CLAUDE.md 지침·스타일)가 다이어트와 엇갈려 재비판이 걸러야 한다 |
| 현행 메뉴(0~6명) 유지 | 실행마다 리뷰어 구성이 달라 재현이 어렵고, sonnet 고정 리뷰어가 끼어든다 |
| 외부 inherit 리뷰어까지 opus 강제 | 「inherit 은 그대로」 규칙을 뒤집는다. 사용자가 세션 모델 따름을 골랐다 |
| 공유 doc-recritic 사본 재사용 | copy-of 바이트 동일 락 때문에 모델을 못 고치고, 본문이 하향을 금지한다(R1) |
| 이해글을 read-nothing 격리 빌더가 씀 | corpus 완전성은 지키지만 사용자가 오케스트레이터 작성을 골랐다(K3) |
| e2e pass 를 침묵 = 승인으로 공시 | 사람 reviewer 가 실제로 없는 채 clean 이 게시된다 |
| e2e 레시피 선언 파일 | 새 공개 표면이 생기고 첫 실행은 늘 건너뛴다 |
| 브라우저 MCP 필수 / Bash 만 | API·CLI 대상이 늘 「없음」이 되거나, 웹 UI 를 못 걷는다 |
| 차등 기계 유지(직전 설계) | 「교체는 하한을 안 올리고 단순함을 깎는다」는 새 기계를 옆에 붙이는 계산이다. 이번엔 같은 요구로 무게를 걷는다 |
| 차등을 모델이 직접 실행 | 3.0.0 교훈(자기 보고가 백스톱을 요약으로 만듦)을 잃는다 |
| baseline 캐시 유지 | 비용만 아끼고 fail-open 셋의 원천이다. 실행 안 메모가 같은 비용 절감의 대부분을 준다 |
| branch 모드 수리 | 체크아웃·네이티브 worktree 가 같은 일을 한다 |
| v10 파이프라인을 옆에 두고 스위치 | 두 경로 공존 비용. 재생 비교는 설치된 main 판으로 충분하다 |
| 새 플러그인 | 사실상 한꺼번에 갈아끼우기다(S13 기각) |

## 알려진 한계

- **이해글 저자(K3).** 오케스트레이터는 corpus 밖(e2e 로그 · 환경 파일 · CLAUDE.md)도 읽는다. 거기서 새어
  나온 낯선 비밀값은 secret-scan 의 고엔트로피 검출(corpus 안 값만 봄)에 안 걸리고, 알려진 패턴만 잡힌다.
- **매 실행 새 코멘트.** 구독자 알림이 실행마다 간다(brief §4 «codecov»). 사용자가 알고 고른 비용이다.
- **사람 감독의 누락형 오류.** 증거 하한(X1)과 걷기 직후 게이트가 받치지만, 사람이 증거표를 대충 승인하면
  막을 장치는 없다(C21).
- **`git worktree add` 의 post-checkout 훅**은 kill switch 밖이다(기존 공백, README 공시 유지).
- **재생 비교는 표본이다.** 고른 결함 밖의 놓침은 측정되지 않는다.
- **e2e 는 현재 체크아웃만** 걷는다. 토픽의 다른 브랜치는 걷지 않는다.
- **롤백은 이전 버전 재설치 하나다**(재결정 R5). 컷오버 사이에 옛 경로로 돌아가는 스위치는 없다.

## 결정 기록

**brainstorming 이 닫은 열린 질문**

| OQ | 결정 |
|---|---|
| OQ19 | 한 줄 표 = §3·§6. 차등은 요구 24개를 지키며 얇게 새로 |
| OQ20 | 부팅 명령은 추론해 질문에 그대로 노출(선택 = 실행 승인). 표면별 도구, 없으면 공시. 로컬 origin 만 |
| OQ21 | 변경이 스스로 더하거나 고친 통제의 구체 경로는 막고, 하지 않은 보안 강화 처방은 선택 사항 |
| OQ22 | ① 정리 → ② 다이어트 → ③ 게시 → ④ e2e → ⑤ 차등. e2e 는 fixture 앱 + 실제 프로젝트 1회 |
| OQ23 · OQ27 | 헌장 세 줄(§8) |
| OQ24 | sandbox·mutation-guard 를 plugin-audit 로 이전 |
| OQ25 | 요구 목록 + 라운드 최대 2 + 다음 사이클 후보 |
| OQ26 | 걷기 직후 게이트 하나 |
| OQ28 | 외부 플러그인 방식 유지, 고정 기본 3 + 조건부 4 + qg 재비판. opus 는 qg 소유 리뷰어만 고정 |
| OQ29 | 규약 + 걷기 전후 코드 상태 지문 비교 |
| OQ30 | 토픽 스코프 유지, `Spec:` 트레일러는 D13 의 첫 의도 출처 |
| (새) | 이해글은 오케스트레이터가 쓴다. 컷오버는 부품 단위 제자리 교체(재결정 R5) |
| (리뷰 r1) | 인자는 맨 `/qg` · 맨 `/qg branch` · `--paths` · `critique` 만 남긴다(§6). PR 본문 읽기는 `discover-spec.sh` 의 읽기 전용 gh, 쓰기는 sink |

**재결정** (원래 / 재결정 / 근거)

| # | 원래 | 재결정 | 근거 |
|---|---|---|---|
| R1 | 재비판 = qg `doc-recritic` 사본(opus 고정) | qg 전용 `code-recritic` 신설, 사본·bridge 삭제 | copy-of 바이트 동일 락(`shared/tests/test_copy_of_contract.sh`) + 공유 agent 본문 「하향은 요청하지 않는다」(`agents/doc-recritic.md:46`) — 사용자 승인 |
| R2 | D28: plan = 네 갈래 + 이음매 | plan = 컷오버 다섯, 이음매는 ④의 AC | S12 범위 확장 + OQ22 순서. brief 리뷰 지적(abf668a4#r3.2) 해소 — 사용자 승인 |
| R3 | qg agent 에 모델 키 없음(agent-model-unpin) | qg 소유 리뷰 agent 는 `model: opus` | 사용자 지시 「리뷰는 opus」 |
| R4 | `/qg branch <name>` 존재 | 삭제 | 만든 worktree 안에서 파이프라인이 일하지 않음(조사) — 사용자 승인 |
| R5 | D18: v10 을 옆에 세워 구성요소별로 갈아끼움 | 부품 단위 제자리 교체. 설치된 main 판을 비교·롤백 기준으로 씀 | 두 경로 공존 비용 · 재생 비교는 설치된 main 판으로 충분 — 사용자 승인(리뷰 라운드 1) |

**표기** — 이 문서에서 꾸밈 없는 「R<n>」(R1~R24)은 §요구 목록의 차등 테스트 요구다. 위 표의 번호는 「재결정
R<n>」으로 부르며, §6·Trade-offs 의 「(R1)」은 재결정 R1 이다. §3 의 「R-init」과 「R3 공백 게이트」는 현행
`references/differential-test.md` 의 단계 이름(실행 초기화 · 계획 누락 시 묻는 질문)이다.
- D1.1 · r1 · adopt · ce6c4dcc#r1.1 · "고친다(채택) — R5 로 기록" — K4 「부품 단위 제자리 교체」와 기각 대안 「v10 파이프라인을 옆에 두고 스위치」가 확정 D18 「v10 을 옆에 세워 … 갈아끼우며」를 뒤집었는데, 재결정(R1~R4)으로 기록되지 않았다.

## Metadata

- 근거 brief: `docs/superpowers/interview/2026-10-03-qg-v10-rebuild-interview.md` (+ `.audit.md`)
- 대상: `plugins/quality-gates` 9.3.6 → v10 (컷오버 다섯 릴리스)
- 닿는 다른 표면: `plugins/plugin-audit`, `plugins/project-init`(템플릿 한 줄), `shared/tests`, `CLAUDE.md`,
  `docs/philosophy/devbrew-harness-philosophy.md`, `docs/git-workflow/pr-process.md`, `.claude-plugin/marketplace.json`

### Deferred to plan

- 재생 비교에 쓸 과거 결함 diff 의 구체 목록과 고르는 사람.
- 조건부 리뷰어 넷의 신호 판별 규칙의 구체 문구.
- `run-test-selection.sh` 를 하위명령별 파일로 나눌지 여부.
- fixture 앱의 언어·구성과 버그 주입 방식.
- 컷오버별 버전 번호(머지 직전에 정함).
