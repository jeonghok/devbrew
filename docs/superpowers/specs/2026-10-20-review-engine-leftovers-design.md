---
name: review-engine-leftovers
type: design
created_at: 2026-10-20
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R12.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R12 — R2a 남은 리뷰 엔진 · qg 소결함 · Design

> R2a 와 R11 이 남긴 공유 리뷰 엔진 · qg · project-init · plugin-audit 의 작은 결함과 보안 제안을 고친다 — 새 명령 · 새 상태보다 이미 있는 허가 · 거부와 이유 · 공시 · 락 넓히기로.

## 목차

- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Anti-goals](#anti-goals)
- [Constraints](#constraints)
- [설계](#설계)
  - [§1 범위 — 남은 것 · 이미 고친 것 · 더한 것](#1-범위--남은-것--이미-고친-것--더한-것)
  - [§2 엔진 값 · 원문 절 · 리뷰어 입력](#2-엔진-값--원문-절--리뷰어-입력)
  - [§3 라우터 — 흡수 · 앵커 · 임시 번호](#3-라우터--흡수--앵커--임시-번호)
  - [§4 보호 · 정리 · 닫힌 리뷰](#4-보호--정리--닫힌-리뷰)
  - [§5 원장 쓰기 순서 — 펜스 락을 산문까지](#5-원장-쓰기-순서--펜스-락을-산문까지)
  - [§6 손 편집 · 결정 줄 · 재분해 절차](#6-손-편집--결정-줄--재분해-절차)
  - [§7 qg 판정 — 다시 읽지 않기](#7-qg-판정--다시-읽지-않기)
  - [§8 락 · 판정기 빈틈](#8-락--판정기-빈틈)
  - [§9 문서 · project-init · 지휘 절차](#9-문서--project-init--지휘-절차)
  - [§10 위험에 대한 답](#10-위험에-대한-답)
  - [§11 계획 나누기](#11-계획-나누기)
- [있는 것 검토](#있는-것-검토)
- [상류 · 하류 연계](#상류--하류-연계)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [결정 기록](#결정-기록)
- [번호 대조](#번호-대조)
- [원칙 · 입력 대조](#원칙--입력-대조)
- [미룸](#미룸)
- [지휘 기록](#지휘-기록)
- [Metadata](#metadata)

## Context / Why

묶음 R12 의 의도는 「R2a 와 R11 이 남긴 공유 리뷰 엔진 · qg · project-init · plugin-audit 의 작은 결함과 보안 제안을 고친다」다. 받는 것은 R2a 설계문서(`docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md`) `## 미룸` 의 받는 곳 R12 행(:122 · :419 · :421-423 · :433-437 · :440-449)과 R2a 계획 2~4 · R11 이 남긴 결함 · 보안 제안이다. 설계 대화에서 사용자가 세 덩어리를 정했다(`## 결정 기록` U1~U7).

- 범위 분류는 그대로다(U1). 묶음 범위의 「리뷰어 둘의 같은 질문 흡수 때 기다리던 수정 목록 소실」은 main 이 이미 고쳤다(f28bb3fa — 준비 단계의 흡수가 두 쪽 막는 목록을 합친다). 남은 것은 재비판 단계의 흡수(`_absorb_same_as`)가 흡수된 쪽의 `blocks` 를 합치지 않는 자리 하나다(§3).
- 범위 밖에서 들어온 것을 더한다(U1): PR #231 엔진 잔여 셋 · PR #234 의 「codex 가 검토 대상 트리의 AGENTS.md 를 지시로 읽을 수 있다」(받는 곳 없던 넘김) · R10 계획 2 통합 리뷰의 재분해 rc 1 가르기 · R10 계획 3 의 로드맵 R1 · R3 · R5 경로 예약 정리 · R10 계획 3 통합 리뷰의 호출 표면 축 I 변이 유지 · R10 relay 대조의 지휘 절차 교훈 · R10 계획 3 push 보안 리뷰의 qg MEDIUM 둘.
- qg 판정 상태는 「다시 읽지 않기」로 정했다(U2) — 수치는 만든 직후 읽어 `verdict.py` 인자로 넘기고, 리뷰 판정은 레포 코드가 돌기 전에 확정한다. CLAUDE.md 상태 규칙은 그대로다.
- 설계 항목의 기본안을 모두 채택하되 장치는 가볍게 한다(U3) — 새 명령 · 새 상태보다 이미 있는 허가(`check-intent`) · 거부와 이유 · 공시 · 락 넓히기가 먼저다.

지금 레포에서 확인한 것(origin/main 6e4acd2a):

- 엔진 환경 변수는 최솟값(`MINIMUM`, `docreview_config.py:16`)만 있고 최댓값이 없다. 범위 밖 값은 `ConfigInvalid` 로 라운드를 시작하지 않는 길이 이미 있다(`resolve`).
- 불변 절의 「추가만 허용」(`docreview_state._appended_only`)은 옛 줄 해시가 새 줄 해시의 앞부분이면 통과시킨다. brief §6 의 마지막 `S<N>` 항목 밑에 이어 붙인 줄(새 항목이 아닌 이어 쓴 글)도 통과한다.
- `related-changes`(`cmd_related_changes`)는 절 제목을 `json.dumps(ensure_ascii=False)` 그대로 내고, 진입 skill 셋이 그 출력을 `<related_changes>…</related_changes>` 슬롯에 싣는다(spec-review · reviewing-brief · request-framing 의 탐지 · 재비판 펜스).
- 원장 쓰기 순서 락 `ac8_scan`(`plugins/spec-distill/tests/test_ledger_wiring.sh:101`)은 첫 줄이 정확히 ```` ```bash ```` 인 펜스만 읽고 「펜스 밖 산문은 읽지 않는다」(:94). 절차서 `reviewing-document.md`(정본 `shared/docreview/references/reviewing-document.md`, spec-distill `references/` 에는 링크)의 :87-88 은 `declare-related` · `log-decision` 을 산문으로 지시하고 이 파일은 락의 대상(`GUARDED`, :98)에 없다.
- 재비판 흡수 `_absorb_same_as`(`docreview_route.py:584`)는 생존자의 빈 산문 칸만 형제에게서 채우고 `blocks` 는 합치지 않는다 — 준비 단계의 흡수(`cmd_prepare`, f28bb3fa)는 합친다. 코드 읽기로 확인했고 재현은 계획이 RED 로 먼저 본다.
- 보호 · 불변 판정(`docreview_anchor.classify_anchor` :110 · `docreview_state.anchors_matching` · `round_fence`)은 그 라운드(와 직전) 스냅숏의 부모 관계로만 계산한다.
- `finalize` 는 준비(`pending_recritic`)가 없으면 `finalize_failed` 를 남긴다(`cmd_finalize` :1087) — 같은 라운드에 이미 `route_report` 가 있어도 그렇다.
- 쉼표로 이은 복수 앵커 `edit_scope` 는 라우터(`normalize` :159)가 그대로 통과시키고, `check-intent` 가 문자열 하나와 비교해 되돌릴 수 없는 escalated 로 굳힌다. `§` 가 든 제목은 엔진 slug(`slugify`)가 `§` 를 빼는데 리뷰어는 `#§b-…` 로 낸다.
- qg 합성기 `finding_id`(`synthesize_findings.py:162`)는 `agent-file-line` 이라 같은 줄의 다른 지적이 겹친다. 요약 정규화는 `_same_claim`(:339)에 이미 있다.
- plugin-audit 의 kill switch 정규식 `_KILLSWITCH_RE`(`check-shape-completeness.py:177`)는 `DEVBREW_[A-Z0-9_]*_DISABLE` 로 플러그인 자기 이름에 묶이지 않는다. 자기 이름은 같은 파일이 이미 읽는다(`own_name`, :65).
- 배선 락의 면제 표 `EXEMPT`(`tools/adjudication/check_wiring.py:145`)는 `(경로, 줄, 정체)` 를 키로 쓰고, 정체가 바이트까지 같은 두 자리(escalated · reraise 예약의 `continue in _auto_decides @ if not f0`)는 줄 번호로만 갈린다.
- 철학 문서 `docs/philosophy/devbrew-harness-philosophy.md:28` 은 「문서 리뷰 자리 넷(design doc·brief·seed·generic)」이라 적었다 — 엔진 프로필로 리뷰하는 자리는 셋이고 qg 의 `generic` 프로필은 엔진 테스트만 읽는다.
- 호출 표면 락(`shared/entry/check_invocation_surface.py`)의 `_LEAD`(:65)는 `*` · `[` · `|` · `>` 뒤를 보지 못하고, `_OLD_TRAIL`(:73)은 ` /qg.md` 를 RED 로 본다(안전 쪽 오탐). 살아 있는 표면(`LIVE_TOP` · `LIVE_PREFIX`, :77-78)에 `docs/git-workflow/` 와 `.claude-plugin/marketplace.json` 이 없다.
- qg 최종 판정 펜스(quality-pipeline `SKILL.md` `## Final verdict`)는 마지막 iteration 의 `synth.out` · `differential.yaml` · `excluded.md` · `range-scope.txt` 를 다시 읽는다 — 그 사이에 e2e 걷기와 차등 테스트(레포 코드)가 돈다. `verdict.py` 는 수치를 이미 인자로 받고(`--blocking` · `--optional` · `--new-failures` · `--excluded`, :241-244) 축 플래그(`--defect` · `--review-blocked` · `--angle-absent` · `--reason`)도 있다.
- qg `review-diff.sh` 는 제외 경로를 `:(exclude,literal)<경로>` pathspec 으로 뺀다 — 이 pathspec 은 폴더 접두에도 맞는다. 차등 worktree 를 건너뛰는 `QG_WT_RE`(`(base|head)-<8자>`)와 `is_registered_wt` 는 이번 실행의 세션과 묶이지 않는다(qg-worktree.sh 는 이름을 세션 id 앞 8자로 짓는다, `qg-worktree.sh:43`).
- 추적 안 되는 중첩 레포는 리뷰하지 않고 Step 1c 의 `degraded: yes` 로 판정을 막는다(PR #234 — 중첩 레포 안을 펼친 고침이 레포 밖 파일 유출(HIGH) · 중첩 레포 설정의 명령 실행(CRITICAL)을 만들었다).
- PR #232 의 「같은 단서 id 두 축」은 이미 고쳐졌다(62ba87a0 이 main 에 있다 — `audit-workflow.js` 가 시작 전에 멈춘다). 이 에픽 범위가 아니다.

## Goals

- G1 엔진 값 · 원문 절 · 리뷰어 입력 슬롯이 범위 밖 값과 모양을 거부하거나 이스케이프하고, 거부는 이유를 보인다.
- G2 라우터 · 재비판 흡수 · 보호 계산이 항목 · 막는 목록 · 보호를 조용히 잃지 않는다.
- G3 원장 쓰기는 표지 확인 줄 다음에만 일어난다는 규칙을 락이 산문까지 지킨다 — 엔진은 spec-distill 표지를 모른 채로.
- G4 사람의 결정(기각 되돌리기 · 재분해 · 닫힌 뒤 결정 줄)이 이미 있는 허가 · 결정 줄 길로 기록되고, 다음 라운드에 같은 것을 다시 묻지 않는다.
- G5 qg 판정은 판정 전에 도는 레포 코드가 닿는 파일을 다시 읽지 않는다. 리뷰 diff 에서 경로가 조용히 빠지지 않고, 중첩 레포는 리뷰하지 않고 이유를 실어 막는다.
- G6 락 · 판정기 · 문서 · 지휘 절차의 남은 빈틈을 이빨(변이 RED)과 양의 짝을 갖춰 닫는다.

## Non-goals

- R2a 계획 2~4 의 범위 · R8 의 권한 경계(엔진 밖 원장 쓰기, R2a 설계 AC17 가) · R13 의 인터뷰 쪽 소결함(`check_brief` 의 `source: chosen` 대조 · 엔진 skill 셋의 링크 따라 쓰기 · V1 확인 줄 자리).
- CLAUDE.md 상태 규칙 개정(U2 — 그대로 둔다).
- project-init 「CLAUDE.md 는 그대로 두기」 + C-S3 (b) 동작 변경(손실 없음 — 공시만, §9).
- superpowers 의 파일 · 동작(C25 · C35 · D26).

## Anti-goals

- 새 엔진 명령 · 새 원장 칸 · 새 설정 파일을 먼저 만드는 것(U3). 이미 있는 허가 · 거부 · 공시 · 락이 표현하지 못한다고 계획이 보인 자리에만 더하고, 그때는 설계 변경으로 지휘 세션에 알린다. 예외 둘은 사용자가 정했다(U10) — 라운드 기록의 `finalize_out`(finalize 두 번째가 같은 보고를 내는 재료) · `engine_lines` 항목의 `kind: count` 표지(닫힌 리뷰의 마지막 계수 줄 알아보기).
- 엔진(`shared/docreview`)이 spec-distill 의 표지(`reviewing-by`)를 알게 하는 것 — 계층이 뒤집힌다(§5).
- relay-checker 에 문장 수 세기 같은 새 판정을 더하는 것(U3 — 지휘 절차 규칙 한 줄과 기록 걸음만).
- 설계문서 프로필에 새 비교 축을 더하는 것 — 이미 있는 `approaches_comparison` 축의 설명에 한 줄을 더해 맡긴다(C32 · U7).
- 엔진 slug 규칙을 바꾸는 것 — 골든이 흔들린다(§3).
- 조용히 고치기(재번호 · 강제 변환으로 숨기기) — 고칠 수 없는 모양은 거부하고 이유를 보인다.

## Constraints

- C25 · C35 · D26 — 외부 플러그인은 건드리지 않는다. codex 는 호출 플래그 · 설정만 바꾼다.
- C32 — 원래 있는 것을 다시 만들지 않는다(`## 있는 것 검토`).
- D21 — 묶음 §5 의 위험은 없다. 이 설계가 새로 여는 위험에 §10 이 답한다.
- CLAUDE.md — 기본값과 판단 · 레포 전용 값 금지 · 상류 · 하류 연계 · 진입점에서 따라 내려가기 · 있는 것 먼저 · 처분 줄 · 모든 훅에 kill switch · 마크다운 상태.
- 락 지도(`locks.md`)의 R12 행 넷(`cases_advice.sh` `case_advice_pre_upgrade_ledger` · `case_AC6_render_cap` · 골든 `case_T05_T06_reject.gate.txt` · `case_T11_permit_keeps_disposition.gate.txt`)이 지키는 「기본값 + 덮어쓰기가 먹는다」를 지킨다 — 최댓값은 기본값 · 테스트가 쓰는 값보다 넉넉하다.
- 셸 펜스는 macOS bash 3.2 에서 돈다. 새 · 바뀐 셸 테스트는 실행 비트(100755)를 갖는다.
- 경로 예약: R13 은 이 에픽 뒤에 간다(로드맵 R13 의존 · 순서 이유 — 「엔진 skill 셋은 R12 의 펜스 락 뒤에」). R8 은 R10 · R12 · R13 뒤에 간다. 이 에픽이 고치는 spec-review `SKILL.md` · request-framing · reviewing-brief 는 R13, `docreview_state.py` · `review-diff.sh` · `redecompose.md` · `conducting.md` 는 R8 도 예약했다 — 그래서 이 문서는 그 파일들을 함수 · 절 · 펜스 이름으로 가리킨다.

## 설계

### §1 범위 — 남은 것 · 이미 고친 것 · 더한 것

| 항목 | 처분 | 자리 |
|---|---|---|
| 엔진 환경 변수 최댓값 | 고침 | §2 |
| 원문 절 마지막 앵커 밑 이어 붙인 줄 | 고침 | §2 |
| `</related_changes>` 주입 | 고침 | §2 |
| `declare-related` 펜스 락 · `log-decision` 표지 가드 | 고침(락) | §5 |
| 리뷰어 둘의 같은 질문 흡수 때 수정 목록 소실 | 이미 고침(f28bb3fa) — 남은 재비판 흡수 자리만 고침 | §3 |
| 확인된 결정의 보호가 자식 절에 붙지 않음 | 고침 | §4 |
| finalize 두 번 · 복수 앵커 · § 앵커 | 고침 | §4 · §3 |
| 설계문서 프로필의 대안 비교 축 | 고침 — 새 축 없이 `approaches_comparison` 설명에 한 줄(U7) | §9 |
| 번호 대조 · 미룸 손 편집의 허가 길 | 고침(절차) | §6 |
| 리뷰가 닫힌 뒤 손으로 쓴 결정 줄 | 고침 | §4 |
| qg 판정 id 충돌 | 고침 | §7 |
| plugin-audit kill switch 정규식 | 고침 | §8 |
| `check_wiring.py` 줄 번호 핀 | 고침 | §8 |
| 철학 P3 「자리 넷」 | 고침 | §9 |
| 공유 락 빈틈 다섯 | 고침 | §3 · §8 |
| project-init 헌장 모서리 셋 | 그대로 두기는 공시 · 둘은 고침 | §9 |
| qg 판정 상태 위치 | 고침(다시 읽지 않기) | §7 |
| qg e2e 시나리오 수 상한 공시 | 고침 | §7 |
| 더함: PR #231 엔진 잔여 셋 | 고침 | §6 |
| 더함: codex 가 검토 트리 AGENTS.md 를 지시로 읽음(PR #234) | 고침 또는 공시 | §7 |
| 더함: 재분해 rc 1 가르기(R10 계획 2 통합 리뷰) | 고침 | §6 |
| 더함: 로드맵 R1 · R3 · R5 경로 예약의 옛 `skills/spec-interview/` | 지휘자의 로드맵 PR | §9 |
| 더함: 호출 표면 축 I 대안 둘 · 변이 일곱 유지(R10 계획 3 통합 리뷰) | 유지 · 다시 RED 확인 | §8 |
| 더함: 중첩 레포 리뷰 다시 열기 · push 보안 MEDIUM 둘 | 고침 | §7 |
| 더함: 지휘 절차 교훈 둘(R10 relay 대조) | 규칙 한 줄 · 기록 걸음 | §9 |

### §2 엔진 값 · 원문 절 · 리뷰어 입력

- **최댓값 표.** `docreview_config.py` 에 `MINIMUM` 옆 같은 꼴의 `MAXIMUM` 표를 둔다. `_int` 가 범위 밖 값을 지금처럼 `ConfigInvalid` 로 거부하고, 부르는 쪽(`begin-round` · `advice`)은 지금처럼 라운드를 시작하지 않고 이유(이름 · 값 · 허용 범위 · 출처)를 보인다. 프로필 · 진입 값도 같은 표를 지난다. 값은 기본값과 지금 테스트가 쓰는 값(탐지 3 · 재리뷰 상한 2 · 참고 목록 8 · 요약 폭 60 등)보다 넉넉하게 계획이 정하고 README 에 공시한다(지휘자 판단 — 「사용자가 연다」는 그 범위 안에서다).
- **원문 절의 이어 쓴 줄.** 불변 절의 「추가만 허용」을 「새 항목만 추가」로 좁힌다. `_appended_only` 가 옛 줄 해시가 앞부분이라는 조건에 더해, 덧붙은 꼬리의 첫 내용 줄(앞의 빈 줄은 건너뛴다)이 0열에서 시작하는 새 목록 항목(`- `)일 때만 참이다. 스냅숏은 지금 줄 해시만 남기므로, 스냅숏을 만들 때 줄마다 「0열 `- ` 로 시작하는가」 표시를 함께 남긴다(`docreview_anchor.py snapshot` 이 만드는 스냅숏의 칸 하나 — 원장의 새 개념이 아니라 이미 있는 스냅숏 자료에 더하는 것, 지휘자 판단. `begin-round` 가 스냅숏 칸을 원장으로 옮겨 적는 자리(`line_hashes` 를 덧붙이는 같은 자리)에서 이 표시도 옮긴다). 판정은 그 라운드 스냅숏의 표시로 하므로 뒤늦게 다시 계산해도(finalize · 게이트 · 따라잡기) 같은 답이다. 마지막 항목 밑에 이어 쓴 줄(들여쓴 인용 줄 · 이어지는 글)은 그 절의 바뀜으로 센다. 엔진은 `S<N>` 문법을 모른다 — 마크다운 목록 항목만 본다(지휘자 판단). 새 `S<N>` 의 정당성(원장에 있는 번호인지)은 지금처럼 진입 검사(`check_verbatim_coverage.py`)가 맡는다.
- **`</related_changes>` 주입.** `cmd_related_changes` 가 JSON 을 낼 때 `<` · `>` · `&` 를 JSON 유니코드 이스케이프 `\u003c` · `\u003e` · `\u0026` 으로 바꿔 낸다. 같은 JSON 값이라 읽는 쪽은 바뀌지 않고, 슬롯의 닫는 표시가 일찍 나올 수 없다. 진입 skill 셋은 고치지 않는다.

### §3 라우터 — 흡수 · 앵커 · 임시 번호

- **재비판 흡수의 막는 목록.** `_absorb_same_as` 가 생존자의 빈 산문 칸을 채우는 자리에서 흡수된 형제의 `blocks` 도 생존자에 합친다(중복 없이, 준비 단계 흡수 `cmd_prepare` 와 같은 규칙). `_remap_blocks` 의 생존자 매핑은 그대로다.
- **복수 앵커.** `normalize` 가 `edit_scope` 에 앵커가 둘 이상(쉼표 · 공백으로 이은 `#a, #b`)이면 그 항목을 받지 않고 이유(`edit_scope_multi_anchor`)와 함께 보류로 센다(`L.hold` — 게이트에 보인다). 나눠서 둘로 만들지 않는다.
- **`§` 앵커.** 엔진 slug 는 그대로 두고, 라우터가 리뷰어가 낸 `anchor` · `edit_scope` 의 앵커 글자에 엔진 slug 와 같은 문자 제거(`_SLUG_STRIP`)를 적용한다. 바뀐 값은 강제(`coerced`, 게이트 판정을 바꾸지 않으면 degrade 아님)로 센다. 리뷰어 · 엔진이 같은 앵커를 보게 된다(지휘자 판단 — 엔진 slug 를 바꾸면 골든이 흔들린다).
- **같은 블록 안 같은 임시 번호.** `merge_list_blocks` 가 한 블록 안에서 같은 `ref` 를 두 항목이 쓰면 뒤 항목을 받지 않고 이유(`duplicate_ref`)와 함께 보류로 센다. 조용히 덮거나 다시 번호 매기지 않는다.
- **흡수 분기의 배선 락.** 흡수로 항목을 버리는 분기(`merge_list_blocks` · `cmd_prepare` 의 `ev("absorbed", …)`)를 배선 락 스캔이 처분 호출로 인식하게 넓힌다 — 지금은 단언 하나(`ev("absorbed")`)만 지킨다. 넓힌 뒤 그 분기에서 `ev` 호출을 지우면 배선 락이 RED 다.

### §4 보호 · 정리 · 닫힌 리뷰

- **보호의 계보.** 보호 · 불변 판정이 그 라운드 스냅숏만이 아니라 원장의 앞선 스냅숏 전부에서 그 앵커가 보호 · 불변 절(또는 그 자식)이었는지를 본다. 원장 스냅숏을 뒤에서부터 걷는 방식은 `_expected_lines` 의 걷기를 쓴다. 지금 스냅숏만 보고 보호 · 불변을 계산하는 자리가 모두 같은 계보 함수를 지난다 — `check-intent`(`classify_anchor`) · `round_fence` · `begin-round` 의 불변 절 줄 해시 남기기 · `scope_problem` · `_immutable_adopt_anchors`(계획이 `grep` 으로 다시 세어 빠짐없이 묶는다). 그래야 밀려난 자식 절이 자리마다 다르게 판정되지 않는다. 채택한 제목 삽입으로 자식 절이 울타리 밖으로 밀려나도 보호가 이어진다. 채택한 결정의 허가(permit)는 그 변경 하나에만 걸린다 — 보호 이력은 이어지고 다음 변경은 다시 묻는다(U6). 보호는 엔진이 스스로 풀지 않는다 — 엔진은 「경계를 옮기는 결정」을 알아볼 표지가 없고, 표지를 새로 만들지 않는다(가벼운 쪽, 지휘자 판단). 보호된 절을 울타리 밖으로 내는 길은 없다 — 계보가 앞선 스냅숏 전부를 보므로 지금 제목을 바꿔도 보호는 이어지고, 이후 변경마다 묻는다(지휘자 판단, 가장 가벼운 쪽). README 와 AC9 에 「한 번 보호된 절은 이후 변경마다 다시 묻는다」를 적는다. 앞선 스냅숏에서 보호였던 앵커와 같은 slug 의 새 절이 생기면 보호 쪽으로 닫는다(질문으로 올라온다 — 과한 쪽을 감수, 지휘자 판단).
- **finalize 두 번.** `cmd_finalize` 가 준비가 없는데(`no_pending_recritic`) 그 라운드의 `route_report` 가 이미 있으면 거부 기록(`finalize_failed`)을 남기지 않고, 「이 라운드는 이미 정리됐다」를 알리고 같은 보고를 rc 0 으로 다시 낸다(멱등). 준비가 다른 라운드 것이거나 보고가 없으면 지금처럼 거부한다.
- **닫힌 뒤 손으로 쓴 결정 줄.** 결정 기록 절(프로필 `decision_log` 이 문서 절인 자리)에 엔진 밖에서 더해진 줄이 리뷰가 닫힌 뒤에 생겼으면, 재리뷰 라운드의 줄 출처 판정(`_log_verdicts`)이 그 줄을 「허가 없이 바뀜」 결정이 아니라 기록으로 읽고 게이트에 「리뷰가 닫힌 뒤 손으로 더한 결정 줄 N개 — 기록으로 읽었다」와 그 줄들을 보인다. 닫힘의 표지는 이미 있다 — 끝맺음 펜스가 그 라운드의 계수 줄을 엔진으로 쓴다(`cmd_advice --log-file`, 원장 `engine_lines` 에 남는다). 기록으로 받는 줄은 닫힌 뒤 다음 재리뷰가 시작될 때 이미 있던 줄로 한정한다(U5) — 결정 기록 절에서 원장이 아는 마지막 계수 줄보다 아래에 있고, 그 재리뷰의 첫 라운드 시작 스냅숏(`begin-round` 가 원장에 남기는 스냅숏)에 이미 있는 줄이다. 그 스냅숏 뒤에 더한 줄은 열린 리뷰의 손 편집이라 지금처럼 허가를 묻는다. 계수 줄이 여럿이면 마지막 것을 쓰고, 계수 줄 위에 끼워 넣은 줄은 지금처럼 묻는다. 그 표지 뒤의 줄만 해당하고, 다른 절 · 열린 리뷰 안의 손 편집은 지금처럼 묻는다(울타리를 넓히지 않는다).

### §5 원장 쓰기 순서 — 펜스 락을 산문까지

`declare-related` · `log-decision` 을 「표지 확인 줄 다음에만」 부른다는 규칙을 엔진이 아니라 락이 지킨다(지휘자 판단 — 엔진은 spec-distill 표지를 모른다).

- `ac8_scan` 의 대상을 spec-distill 이 싣는 문서(`plugins/spec-distill/` 아래 `.md`, 링크로 실린 정본 포함) 가운데 엔진 이름을 대는 파일 전부로 넓힌다 — 목록을 적지 않고 `git ls-files` 와 엔진 이름으로 도출한다. 지금 트리에서는 진입 skill 셋 · `finishing.md` 에 더해 절차서 `reviewing-document.md`(링크 — 정본은 `shared/docreview/references/`)와 README 가 들어온다. 링크는 정본 하나로 센다(Grep 류가 링크를 건너뛰므로 `git ls-files` 의 mode 120000 을 따라간다).
- 펜스 밖 산문에서 `docreview_state.py declare-related` 또는 `docreview_state.py log-decision` 꼴(스크립트 이름이 붙은 꼴만 — 하위 명령 이름만 적은 설명 · `check-intent` 등 다른 쓰기 명령은 세지 않는다)이 나오는 문단(스크립트 이름과 하위 명령 사이에 따옴표 · 백틱 · `$SD/scripts/` 같은 경로 접두가 끼어도 같은 꼴로 센다 — 표기마다 음성 변이를 둔다)은 같은 문단에 표지 확인 규칙(「표지 확인 줄 다음에만」)을 담아야 한다. 담지 않으면 RED 다. 문단은 빈 줄 사이 블록, 목록 안에서는 항목 하나다. 지시와 설명을 가르지 않는다 — 그 꼴이 나오면 센다(좁고 가벼운 쪽, 지휘자 판단). 처분 줄 · 쓰기 명령 목록 문단은 지금처럼 뺀다.
- 양의 짝: 규칙을 담은 산문 · 기존 펜스는 통과한다. 음의 짝: 규칙 문장을 지운 산문 문단 · 펜스 밖으로 옮긴 호출이 RED 다.
- 엔진 밖에서 셸이 원장을 쓰는 길 전체는 R8 몫이다(`## 미룸`).

### §6 손 편집 · 결정 줄 · 재분해 절차

- **번호 대조 · 미룸 표의 손 편집.** 기각 되돌리기(spec-review 「기타 칸 — 기각 번호 되돌리기」 문단)와 재분해(`redecompose.md` 의 「진행 중 에픽의 범위가 바뀌면」 줄)가 표 행을 고치기 전에 이미 있는 허가 길을 받는 걸음을 절차에 적는다 — 그 라운드의 채택 결정에 `declare-related` 로 그 절을 묶거나, 결정 permit 이 있으면 `check-intent --decision-id` 로 그 절을 확인한다. 새 엔진 명령은 만들지 않는다. 두 절차의 실제 자리에서 그 허가를 받을 결정이 없어(예: 게이트 기타 칸의 답) 허가 길로 표현되지 않는지는 계획이 먼저 확인한다(`### Deferred to plan`) — 표현되지 않으면 그 사실을 설계 변경으로 지휘 세션에 보고한다.
- **`spec_path` 작은따옴표 대입.** spec-review 가 펜스 앞에 붙이라는 `spec_path='<…>'` · `repo_root='<…>'` · `bundle_arg='<…>'` · `bundle_path='<…>'` 한 줄(지금 아홉 자리)을, 따옴표 heredoc 에서 읽는 꼴(`IFS= read -r spec_path <<'DEVBREW_PATH_EOF'`)로 바꾼다 — 경로에 `'` 가 있어도 셸로 새지 않는다. `$(…)` 안 heredoc 은 쓰지 않는다.
- **재분해의 사용자 말.** `redecompose.md` 「적용」 펜스의 `--approval "<사용자 말 그대로>"` 를 결정 줄 펜스와 같은 꼴(따옴표 heredoc → 임시 파일 · 변수)로 바꾼다 — 말 안의 `"` · `$` · 역따옴표가 셸로 새지 않는다. `roadmap_write.py` 의 인자는 바꾸지 않는다.
- **다른 레포 cwd 의 결정 줄 펜스.** 결정 줄 펜스(`decision-line`)가 상태 루트를 cwd 가 아니라 `spec_path` 가 사는 레포에서 얻는다 — 펜스 첫머리에서 `spec_path` 의 폴더로 들어가고(실패하면 멈춤), 그 레포가 cwd 레포와 다르면 그 사실을 알린다. 지금은 cwd 가 다른 레포면 원장을 못 찾아 「원장 없음 — 손으로 쓴다」로 빠진다.
- **재분해 rc 1 가르기.** `redecompose.md` 「적용」의 rc 1 이 모두 「3 으로 돌아간다(표 고치기)」로 가는 것을 가른다 — 사유가 brief §5 위험 줄(`K 번호가 없는 줄` · `K 번호가 겹친다`, `roadmap_model.py:453` · `:458`)이면 표로 풀리지 않으므로 멈추고 사유를 보인다. 재분해는 이력 brief 를 고치지 않는다. `RISK_ORDER_NOTICE`(`roadmap_write.py:41`)는 정보 줄이라 멈추지 않는다고 적는다. 인터뷰 끝의 같은 가르기(`finishing.md:626-629`)를 본뜬다.

### §7 qg 판정 — 다시 읽지 않기

U2 를 따른다 — 판정에 쓰는 값은 만든 직후 같은 턴에 읽어 들고 가고, 판정 펜스는 파일을 다시 읽지 않는다. 세션 폴더의 파일은 기록으로 남는다(CLAUDE.md 상태 규칙 그대로).

**범위는 최종 판정만이다(U4).** 지키는 것은 최종 판정 줄의 수치 · 축이다. 반복 중간 단계(Step 4.5 표면화 · 라우팅, 낮춘 지적 게이트 · 되올려 다시 합성하기, Fix-loop 분류, result.md 기록)가 차등 테스트 뒤에 세션 폴더를 다시 읽는 것과, 레포 코드가 남긴 프로세스가 반복 2 이후의 리뷰 입력에 닿을 수 있다는 것은 바꾸지 않고 README 「한계」 절에 알린다 — 「qg 는 최종 판정 수치를 레포 코드가 돌기 전 또는 만든 직후에 읽어 지킨다. 반복 중간 단계와 레포 코드가 남긴 프로세스의 영향은 막지 않는다. 판정 뒤 게시 단계(게시 여부를 `range-scope.txt` 유무와 result.md 의 `## 게시` 줄로 정한다)도 같다」.

- **순서.** iteration 마다 ① 리뷰(Step 1 · 1b · 3 · 3.5) 뒤, 차등 테스트(레포 코드) 전에 리뷰 축 합성을 끝낸다 — 합성기가 리뷰 축 판정(막는 지적 수 · 선택 수 · 리뷰 축 사유 · 각도 결손)을 내고 오케스트레이터가 그 출력을 곧바로 읽어 턴에 든다. 그다음 ② 차등 테스트를 돌고 D5 직후 `new_failures` 와 차등 축 판정을 읽어 든다. Fix-loop 의 제외 항목 수는 `excluded.md` 에 한 줄을 더할 때마다 턴에서 센다. 범위 모드의 시작 · 끝 커밋은 Preflight 에서 범위를 얼린 직후 읽어 든다.
- **최종 판정.** `## Final verdict` 펜스는 `--prior "$SYN"` 과 `differential.yaml` · `excluded.md` · `range-scope.txt` 재독을 지우고, `verdict.py` 의 이미 있는 인자(`--blocking` · `--optional` · `--new-failures` · `--excluded` · `--sha` · `--defect` · `--review-blocked` · `--angle-absent` · `--reason` · `--e2e`)로만 넘긴다. 그 인자는 모델이 숫자를 고르거나 옮겨 적은 것이 아니다 — 숫자를 만든 직후의 펜스(리뷰 축 합성 직후 · 차등 테스트 직후 · 제외 항목을 더한 직후 · 범위를 얼린 직후)가 판정 인자 줄(`qg-verdict-args: …`)을 기계 출력으로 내고, 최종 판정 펜스는 그 줄들을 글자 그대로 붙인다(U8). 기존 규칙 R24 「판정은 기계 출력을 직접 읽고, 모델이 옮겨 적지 않는다」는 「판정 인자는 기계가 낸 줄의 글자 그대로」로 바뀌고, R24 · V1 · K-3 · K-7 을 인용하는 자리를 계획이 `grep` 으로 전부 뽑아 함께 고친다(지금 확인된 것 — `skills/quality-pipeline/references/differential-test.md` 의 R24 문장 둘 · `skills/quality-pipeline/SKILL.md` 의 「(V1 · R24)」 · `scripts/verdict.py` 주석 · `README.md` · `tests/test_v1_verdict_line.sh` · `tests/test_diff_test_results.py` 의 ProducerToVerdict · `tests/harness/test_skill_orchestration_behavior.sh` · `tests/test_publish_pipeline_wiring.sh`(K-3), 그리고 아래 락. 판정 펜스가 지금 쓰는 `--line` · `--iter` · `--e2e-overridden` 도 기계가 낸 줄에 포함된다). 그 문장과 락(`references/differential-test.md` 의 R24 줄 · `tests/test_e2e_docs.sh` 의 R24 · K-3 · K-7 단언 · `tests/test_differential_procedure.sh` 의 R24 케이스 · `tests/test_skill_run_contract.sh` 의 R24 단언)을 함께 고친다. 어느 축이 이미 있는 플래그로 표현되지 않으면 그 축에 플래그를 하나 더하는 것까지만 한다(새 상태 파일 없음). Step 1c 의 `degraded: yes` 는 지금처럼 턴에서 `--reason error-axis` 로 간다.
- **판정 id.** `finding_id` 를 `agent-file-line-<요약 지문>` 으로 바꾼다 — 요약 지문은 `_same_claim` 의 정규화(공백 접기 · casefold)를 한 함수로 꺼내 그 결과의 짧은 해시다(내용 기반 · 순서 무관). `anonymize` · `to_adjudication_doc` · `dedup` 의 흡수 기록이 같은 함수를 지난다. `test_synthesize_recritic.sh` 의 충돌 케이스 넷을 「같은 줄 · 다른 요약은 다른 id」 · 「같은 요약은 같은 id」로 다시 쓴다.
- **제외 pathspec 접두 우회.** 걸러진 diff 를 만들 때 제외를 pathspec 으로 빼지 않고, 남길 경로를 `:(literal)` 로 명시해 diff 를 만든다. 그 뒤 전체 이름 목록의 모든 경로가 제외 목록 또는 걸러진 목록에 있는지 대조하고, 어느 쪽에도 없으면 `degraded: yes` 와 그 경로를 크게 알린다. 다른 바뀐 경로의 접두인 경로는 제외 목록에서 거부한다.
- **worktree 건너뛰기의 세션 결속.** `is_qg_state` 의 worktree 갈래가 `(base|head)-<8자>` 의 8자가 `--dir` 세션 폴더 이름의 앞 8자와 같을 때만 건너뛴다(`qg-worktree.sh` 의 이름 규칙). `git worktree list` 확인은 유지한다. 맞지 않으면 리뷰 안 된 중첩 레포로 보고 `degraded: yes` 다.
- **중첩 레포 리뷰 다시 열기 — 대안 갈래로 닫음.** 추적 안 되는 중첩 레포와 선언되지 않은 gitlink 는 리뷰하지 않고 `degraded: yes` 로 막으며 그 이유를 출력에 싣는다. 그 안을 안전하게 읽는 길은 라운드마다 새 보안 결함을 낳았다(색인 파싱 · index 버전 4 · `includeIf`).
- **codex 와 검토 트리의 AGENTS.md.** 검토 대상 트리를 작업 폴더로 `codex exec` 를 부르는 러너 전부(지금 넷 — qg 의 코드 · 산출물, 공유 문서 리뷰, plugin-audit 의 `run_audit_codex_reviewer.sh`; 계획이 `codex exec` 호출을 `grep` 으로 다시 세어 도출한다)가 검토 대상 트리의 프로젝트 문서(AGENTS.md)를 지시로 불러오지 않게 codex 설정을 넘긴다. 설치된 codex 가 그 설정을 받지 않으면 codex 축 공시 줄과 README 한계 절에 「codex 가 검토 대상 트리의 AGENTS.md 를 지시로 읽을 수 있다」를 적는다(지휘자 판단 — 외부 도구의 동작은 바꾸지 못하고 공시가 가장 가볍다).
- **e2e 시나리오 수 상한 공시.** `references/e2e.md` §1 · §2 — 만들 수 있는 시나리오가 셋을 넘으면 질문 본문에 「시나리오 후보 N개 중 셋만 만들었다 — 「기타」 칸에 적으면 그 자리에서 더 만든다」를 싣는다(R2a 설계 :122 의 처분). 선택지 넷 제약은 도구 제약이라 그대로다.

### §8 락 · 판정기 빈틈

- **`check_wiring.py` 키.** `EXEMPT` · `exempt_key` 의 키에서 줄 번호를 빼고 `(경로, 정체)` 로 한다. 정체가 같은 두 자리(escalated · reraise 예약)는 정체에 둘러싼 `for` 의 순회 대상 글자를 더해 내용으로 가른다(지휘자 판단 — 순서 번호는 자리를 다시 줄 번호처럼 만든다). 그래도 정체가 겹치면 RED 다. `stale_exempt` 는 그대로 집합 대조를 하고, 코드를 위에 더해도 재앵커가 필요 없다. 면제 줄번호 주석과 재앵커 함정 문단은 새 규칙에 맞게 줄인다.
- **plugin-audit kill switch.** `_has_killswitch` 가 그 플러그인 이름(`own_name` 을 대문자 · `_` 로 바꾼 것)의 `DEVBREW_<PLUGIN>_DISABLE` 또는 `DEVBREW_SKIP_HOOKS` 를 요구한다. 다른 플러그인의 스위치 · 하위 스위치만 있으면 gap 이다. 공유 모듈(`kill_switch_active.py` 등)로 이름을 읽는 훅이 있으면 그 꼴도 받는다 — 지금 레포의 모든 플러그인이 같은 판정을 받는지 계획이 잰다.
- **copy-of-contract 소비 도출.** 한 플러그인 문서의 다른 플러그인 전체 경로 인용(`plugins/<다른>/scripts/<이름>`)은 소비로 세지 않는다 — 소비는 같은 플러그인 안의 참조다. 양성 짝에 `doc-critic.md` 를 더해 `.md` 전량 제외 같은 넓은 제외를 잡게 하고, 낡은 제외 목록 주석을 고친다.
- **같은 이름 블록.** 「첫 블록만 읽는」 구현을 가르는 케이스를 더한다 — 두 블록이 서로 다른 성한 항목을 담고 둘 다 읽혔는지 단언한다(`case_same_name_block_broken_kills_critic` 혼자로는 못 가른다).
- **호출 표면.** `_LEAD` 에 `*` · `[` · `|` · `>`(마크다운 강조 · 링크 · 표 칸 · `<code>`) 뒤를 더하고, `_OLD_TRAIL` 이 ` /qg.md` 같은 파일 이름 꼴을 RED 로 보지 않게 한다. 살아 있는 표면에 `docs/git-workflow/` 와 `.claude-plugin/marketplace.json` 을 더한다. 넓힐 때마다 음성 대조를 같이 둔다. 축 I 의 개명 대안 둘(`spec-interview` · `spec-distill:interview(?![-A-Za-z0-9_])`)과 변이 일곱(`test_invocation_surface.sh` 의 `i_si` · `i_sp` · `i_np` · `i_pm` · `i_fx` · 실제 변이 `si` · `pm`)을 유지하고, 고친 뒤 그 변이로 다시 RED · GREEN 을 확인한다.

### §9 문서 · project-init · 지휘 절차

- **설계 프로필의 대안 비교(U7).** `references/docreview-profiles/design-doc.md` 의 `approaches_comparison` 설명에 한 줄을 더한다 — 「Rejected Alternatives 의 각 대안이 채택안과 같은 기준으로 비교됐는가 — 한 단어로만 기각했으면 지적」. 축 수 · 골든은 그대로다(persona 성격의 프로필 편집 — 강화라 보안 리뷰 대상은 아니지만 PR 에 밝힌다).
- **지휘 절차의 닫힌 리뷰 결정 줄.** `references/conducting.md` 걸음 4 ③ 「리뷰가 닫혔고 원장이 남았으면 `## 결정 기록` 에 쓰지 않고 … `## 지휘 기록` 에 둔다」를 「리뷰가 닫혔으면 `## 결정 기록` 절 끝(마지막 계수 줄 아래)에 쓴다 — 다음 재리뷰가 그 줄을 기록으로 읽는다(§4 · U5)」로 바꾼다. 그 문장을 글자로 고정한 `tests/test_conducting_loop.sh` · `test_conducting_reference.sh` 의 단언도 함께 바꾼다.

- **철학 P3.** `docs/philosophy/devbrew-harness-philosophy.md:28` 을 「문서 리뷰 자리 셋(design doc · brief · seed)을 통일하는 엔진은 `shared/docreview/` — qg 의 `generic` 프로필은 엔진 테스트만 읽는다」로 고친다.
- **project-init 「CLAUDE.md 는 그대로 두기」 + C-S3 (b).** 동작은 그대로 둔다(지휘자 판단 — 손실이 없다). README 와 skill(S4 선택지 설명 · Step 5 보고)에 「이 선택이면 AGENTS.md 에 `## Project Charter` 가 생기지 않아 실행마다 CLAUDE.md 의 헌장 절을 다시 읽는다」를 적는다.
- **옮기기 중복 공시.** S4 「옮기기」에서 AGENTS.md 에 이미 관리 절이 있어 CLAUDE.md 의 같은 이름 절(`## Project Charter`, 또는 git 규칙을 지킨 실행의 `## Git Workflow`)을 옮기지 않을 때, advisory 와 Step 5 보고에 「CLAUDE.md 의 `<절>` 은 AGENTS.md 에 이미 있어 옮기지 않았다 — CLAUDE.md 가 포인터로 바뀌며 사라졌다」를 적는다.
- **Step 5 문구.** 「CLAUDE.md 를 그대로 뒀다면:」을 「「CLAUDE.md 는 그대로 두기」를 골랐다면:」으로 바꾸고 `test_command_contract.py` 의 접두를 함께 고친다.
- **지휘 절차 교훈(U3 의 가벼운 꼴).** `references/conductor-dispatch.md` `## 사람 자리` 에 두 가지를 적는다. 하나, 선택지 설명을 옮길 때 원문의 문장을 하나도 빼지 않는다(번역해도 문장 수를 지킨다). 둘, 미리 받은 답을 뒤 하위 agent 에 실을 때 그 dispatch 에 실제로 넣은 문장을 그 relay 파일의 「돌려보낸 글」에 덧붙인다. relay-checker 의 판정은 바꾸지 않는다.
- **로드맵 R1 · R3 · R5 경로 예약.** 세 블록의 `경로 예약` 에 남은 `plugins/spec-distill/skills/spec-interview/…` 를 `skills/pm-interview/…` 로 바꾼다. 번호 · 범위 · 의존을 바꾸지 않는 이름 따라가기라 재분해 규칙(머지된 에픽은 범위를 바꾸지 않는다)의 대상이 아니다. 로드맵 고침은 계획 안의 과제가 아니라 지휘자의 로드맵 PR 이 한다(R10 설계 §11 과 같은 꼴) — 생성기가 머지된 블록을 거부하면 그 PR 에서 손으로 고치고 로드맵 `## 결정 기록` 에 까닭을 한 줄 남긴다(지휘자 판단).

### §10 위험에 대한 답

묶음 §5 의 위험은 「없음」이다(D21 — 답할 K 가 없다). 이 설계가 새로 여는 위험과 답:

- 락을 넓히면 지금 문서가 RED 가 될 수 있다(§5 · §8) — 넓히기 전에 지금 트리에서 돌려 걸리는 자리를 같은 PR 에서 고치고, 변이로 이빨을, 음 · 양의 짝으로 과잉을 확인한다.
- 판정 id 가 바뀌면 이전 실행과 id 가 이어지지 않는다(§7) — id 는 한 실행 안에서만 쓰인다. 계획이 실행 사이 id 를 읽는 소비자가 없는지 확인한다.
- 중첩 레포 안을 읽는 길이 PR #234 의 두 위험 부류를 다시 연다(§7) — 그래서 리뷰하지 않고 막는 동작을 지키고, git 실행 · 링크 따라가기가 없음을 적대 픽스처(설정에 명령을 심은 중첩 레포 · 레포 밖을 가리키는 링크)로 잰다.
- worktree 건너뛰기를 세션에 묶으면, 중단된 이전 실행이 남긴 qg worktree 가 `.claude/` 를 무시하지 않는 레포에서 판정을 막는다(지금은 세션과 무관하게 건너뛴다) — 이유 줄에 「이전 qg 실행이 남긴 worktree <경로> — 다른 qg 실행이 쓰고 있지 않으면 `git worktree remove --force <경로>` 로 지운 뒤 다시 돌려라」를 싣는다(§7).
- 판정 펜스가 파일을 다시 읽지 않으면 오케스트레이터가 값을 잘못 옮길 수 있다(§7) — 옮긴 값은 판정 줄에 그대로 보이고, 세션 폴더의 기록과 대조할 수 있다(사람 · 다음 리뷰).

### §11 계획 나누기

기본 제안(계획 담당자가 일의 모양을 보고 바꿀 수 있고 이유를 계획에 적는다):

1. **엔진 · spec-distill 절차** — §2 · §3 · §4 · §5 · §6, 그리고 §9 의 지휘 절차(conducting.md 걸음 4 ③) 바꾸기(§4 의 엔진 변경과 같은 PR 이어야 지휘자가 쓰는 길과 엔진이 받는 길이 함께 바뀐다). 브랜치 `feature/review-engine-leftovers`. R13 이 기다리는 펜스 락(§5)이 여기 있다.
2. **qg** — §7. 브랜치 `feature/qg-verdict-state`.
3. **락 · 판정기 · 문서 · project-init · 지휘 절차** — §8 · §9(로드맵 고침과 conducting.md 걸음 4 ③ 제외 — 그것은 계획 1). 브랜치 `feature/review-lock-leftovers`.

셋은 대부분 다른 파일을 고쳐 병렬로 갈 수 있다. 겹치는 곳은 `tools/adjudication/check_wiring.py`(계획 1 의 흡수 분기 락 · 계획 2 의 합성기 · 계획 3 의 키 바꾸기)와 버전 파일이다 — 공유 엔진은 링크로 spec-distill 과 quality-gates 에 함께 실려 나가므로 계획 1 · 2 는 quality-gates 를, 계획 1 · 2 · 3 은 spec-distill 을 올린다. 판 번호와 CHANGELOG 머리는 머지 직전 지휘자가 정하고, 늦게 머지되는 쪽이 기본 브랜치를 합쳐 그 둘을 다시 맞춘다 — 계획 3 이 먼저 머지되면 나머지는 줄 번호를 다시 박지 않는다. 늦게 머지되는 쪽이 기본 브랜치를 합치고 스위트를 다시 돈다. 브랜치 줄과 경로 예약(이 문서 `## Files to Modify` 가운데 R12 예약에 없는 `plugins/quality-gates/scripts/review-diff.sh` · `verdict.py` · `run_codex_reviewer.sh` · `run_artifact_codex_reviewer.sh` · `plugins/quality-gates/tests/test_review_diff.sh` · `plugins/plugin-audit/tests/test_check_shape_completeness.py` · `plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh` · `plugins/spec-distill/tests/test_conducting_loop.sh` · `test_conducting_reference.sh` · `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md` · `plugins/quality-gates/tests/test_e2e_docs.sh` · `test_differential_procedure.sh` · `test_skill_run_contract.sh` · `test_v1_verdict_line.sh` · `test_diff_test_results.py` · `tests/harness/test_skill_orchestration_behavior.sh` · `test_publish_pipeline_wiring.sh` · AC23 · AC24 테스트 자리 · 건드린 플러그인의 `plugin.json` · `CHANGELOG.md` · `README.md`)은 지휘자가 설계 승인 뒤 로드맵 PR 로 고친다.

## 있는 것 검토

- 레포 안(쓴다): `docreview_config.MINIMUM` · `ConfigInvalid` · `resolve`(최댓값) · `_appended_only`(좁힌다) · `_expected_lines` 의 스냅숏 걷기(보호 계보) · `cmd_prepare` 흡수의 `blocks` 합치기 규칙(재비판 흡수) · `L.hold` · `L.coerced`(거부 · 강제 계수) · `_SLUG_STRIP`(앵커 정규화) · `check-intent --decision-id` · `declare-related`(손 편집 허가) · 결정 줄 펜스(`decision-line`)의 heredoc 꼴(따옴표 · 사용자 말) · `cmd_advice --log-file` 의 계수 줄과 `engine_lines`(닫힘 표지) · `_log_verdicts`(줄 출처) · `ac8_scan` 과 쓰기 명령 도출(펜스 락) · `finishing.md` 의 rc 1 가르기(재분해) · `verdict.py` 의 수치 · 축 인자(qg 판정) · `_same_claim` 정규화(판정 id) · `own_name`(kill switch) · `exempt_key` · `stale_exempt`(배선 락) · `qg-worktree.sh` 의 이름 규칙 · `e2e-state.sh compare --before-sha256`(선례로만).
- 레포 안(이미 고쳐 뺌): f28bb3fa(준비 단계 흡수의 막는 목록) · 62ba87a0(plugin-audit 단서 id 두 축).
- 레포 밖: codex CLI 의 설정 넘기기(`-c key=value`, codex-cli 0.160.0 `codex exec --help` 로 확인) — AGENTS.md 불러오기를 끄는 키는 계획이 실측한다. 새 외부 패키지는 쓰지 않는다.
- 기각: 해시 대조(`e2e-state` 꼴)로 qg 상태를 지키기 · 레포 밖 상태 폴더(U2) · relay-checker 문장 수 세기 · 새 표 행 쓰기 엔진 명령(허가 길이 표현 못 한다고 계획이 보일 때만).

## 상류 · 하류 연계

- 받는 곳: 묶음 R12.md · R2a 설계 `## 미룸` R12 행(:122 · :419 · :421-423 · :433-437 · :440-449) · PR #231 넘김(엔진 잔여 셋) · PR #234 넘김(판정 상태 위치 · codex AGENTS.md · 중첩 레포) · R10 계획 2 통합 리뷰(재분해 rc 1) · R10 계획 3(로드맵 경로 예약) · R10 계획 3 통합 리뷰(축 I) · R10 relay 대조(지휘 절차) · R10 계획 3 push 보안 리뷰(qg MEDIUM 둘) · 설계 대화의 사용자 결정 U1~U7.
- 넘기는 곳: 고친 엔진(→ spec-distill 진입 skill 셋 · qg 문서 비평) · 펜스 락(→ R13 의 엔진 skill 셋 고침이 이 락 위에서 간다) · qg 판정(→ qg 사용자 · 지휘자 걸음 7) · 지휘 절차 규칙(→ 지휘자 · relay-checker) · 엔진 밖 원장 쓰기(→ R8, `## 미룸`).
- 되돌아오는 길: 계획 · 구현에서 이 설계를 다시 나눌 근거가 보이면(예: §6 허가 길이 표현되지 않음 · §7 중첩 레포 길) 재분해 신호 · 설계 변경으로 지휘 세션에 보고한다(`references/redecompose.md`).
- 같은 상태를 읽는 다른 표면: 원장(`docreview-state.md`)을 읽는 진입 skill 셋 · 게이트 렌더 · `gate-rows` · 골든 픽스처 · qg 세션 폴더를 읽는 `Publish` · `qg-gc.py` · 배선 락 · 호출 표면 락 · 로드맵 상태 계산(경로 예약). 이음매 담당은 이 에픽.
- 경로 겹침 · 순서: R13(예약 `check_brief.py` · `skills/pm-interview/` · `skills/request-framing/` · `skills/reviewing-brief/` · `skills/spec-review/SKILL.md`)은 이 에픽에 기대고 뒤에 간다. R8(예약 `shared/docreview/scripts/docreview_state.py` · `skills/spec-review/SKILL.md` · `references/redecompose.md` · `references/conducting.md` · `scripts/review-diff.sh` · `scripts/check-review-scope.sh` · project-init 훅)은 R10 · R12 · R13 뒤에 간다. 그래서 이 에픽이 먼저 고치고 뒤 에픽이 기본 브랜치를 합친다.

## Acceptance Criteria

**엔진 값 · 원문 절 · 입력(§2)**
- AC1 `DEVBREW_DOCREVIEW_*` · 프로필 · 진입 값이 `MAXIMUM` 을 넘으면 `begin-round` · `advice` 가 라운드를 시작하지 않고 이름 · 값 · 허용 범위 · 출처를 보인다. 락 지도의 R12 행 넷(기본값 + 덮어쓰기가 먹는다)은 그대로 GREEN 이다.
- AC2 불변 절 마지막 항목 밑에 이어 쓴 줄(들여쓴 인용 줄 포함)은 그 절의 바뀜이고, 0열 새 목록 항목으로 시작하는 추가는 지금처럼 「추가만」 면제다(양 · 음 픽스처).
- AC3 제목에 `</related_changes>` · `<` · `&` 가 든 절의 `related-changes` 출력에 `<` · `>` · `&` 글자가 없고, JSON 으로 읽으면 원래 제목이 나온다.

**라우터(§3)**
- AC4 재비판 `same_as` 로 흡수된 질문이 막던 고침이 생존 질문의 `blocks` 에 남는다(먼저 RED 재현).
- AC5 `edit_scope` 에 앵커가 둘 이상인 항목은 보류로 세지고 사유 `edit_scope_multi_anchor` 가 게이트에 보인다 — 조용히 통과하거나 escalated 로 굳지 않는다.
- AC6 `### §B …` 절을 리뷰어가 `#§b-…` 로 내도 엔진 앵커 `#b-…` 로 정규화되어 permit 이 만료 · 재상승을 되풀이하지 않고, 정규화가 강제 계수에 남는다. 엔진 골든은 바뀌지 않는다.
- AC7 한 블록 안 같은 임시 번호의 뒤 항목은 보류로 세지고 사유 `duplicate_ref` 가 보인다.
- AC8 흡수 분기의 `ev("absorbed", …)` 를 지우는 변이에 배선 락이 RED 다.

**보호 · 정리 · 닫힌 리뷰(§4)**
- AC9 보호 절의 자식 절이 채택한 제목 삽입으로 울타리 밖으로 밀려난 다음 라운드에도 `check-intent` 와 울타리가 그 절을 보호한다. 그 절의 내용 고침을 한 번 채택한 뒤에도 다음 변경은 다시 묻는다(U6).
- AC10 한 라운드에 `finalize` 를 두 번 부르면 둘째가 rc 0 으로 같은 보고를 내고 게이트가 「미검증」이 아니다. 준비가 다른 라운드 것이면 지금처럼 거부한다.
- AC11 끝맺음 펜스가 계수 줄을 쓴 뒤, 다음 재리뷰가 시작되기 전에 결정 기록 절에 손으로 더한 줄은 재리뷰에서 「허가 없이 바뀜」 결정이 아니라 기록으로 읽히고 게이트에 수와 줄이 보인다. 재리뷰 시작 뒤에 더한 줄 · 다른 절의 손 편집은 지금처럼 묻는다(U5 — 닫힌 뒤 추가 · 재리뷰 중 추가 각각의 픽스처). 지휘 절차(conducting.md 걸음 4 ③)가 닫힌 리뷰의 결정 줄을 이 자리에 쓰도록 바뀌었다.

**펜스 락(§5)**
- AC12 `ac8_scan` 대상이 도출되고 `reviewing-document.md` 를 포함한다. `docreview_state.py declare-related` · `docreview_state.py log-decision` 꼴이 나오는 산문 문단에 표지 확인 규칙이 없으면 RED 이고(규칙 문장을 지우는 변이로 확인), 규칙을 담은 문단은 통과한다. 엔진 코드는 표지를 읽지 않는다.

**절차(§6)**
- AC13 기각 되돌리기 · 재분해 절차가 표 행을 고치기 전 허가 받기 걸음(`declare-related` 또는 `check-intent --decision-id`)을 적고, 그 길로 고친 행이 다음 라운드에 「허가 없이 바뀜」으로 돌아오지 않는다(끝에서 끝 픽스처) — 또는 계획이 허가 길이 표현 못 함을 보이고 지휘 세션에 설계 변경으로 보고했다.
- AC14 `'` · `"` · `$` · 역따옴표가 든 설계문서 경로 · 사용자 말로 spec-review 펜스 · 재분해 적용 펜스 · 결정 줄 펜스가 셸로 새지 않고 글자 그대로 넘어간다.
- AC15 cwd 가 다른 레포여도 결정 줄 펜스가 `spec_path` 레포의 원장을 찾아 엔진으로 쓰고, 레포가 다르다는 것을 알린다.
- AC16 재분해 적용의 rc 1 사유가 brief §5 위험 줄이면 표 고치기로 돌아가지 않고 멈춘다. `RISK_ORDER_NOTICE` 는 정보로 적혀 있다.

**qg(§7)**
- AC17 판정 인자는 숫자를 만든 직후의 펜스가 낸 `qg-verdict-args:` 줄의 글자 그대로이고, 기존 R24 문장과 그 락이 새 규칙에 맞게 바뀌었다(옛 문장이 남지 않는다, U8). 최종 판정 펜스와 판정까지의 펜스가 `synth.out` · `differential.yaml` · `excluded.md` · `range-scope.txt` 를 판정 입력으로 다시 읽지 않고 수치 · 축을 `verdict.py` 인자로만 넘긴다(펜스 문면 락). 리뷰 축 합성이 차등 테스트 전에 끝난다. 반복 중간 단계는 바꾸지 않고, README 한계 절에 그 범위(U4)가 있다.
- AC18 판정 전에 세션 폴더의 파일을 바꾸는 픽스처(차등 테스트 · e2e 대역이 `synth.out` 을 지움 · `differential.yaml` 을 고침)에서도 판정 줄이 턴에 든 값과 같다.
- AC19 같은 리뷰어 · 파일 · 줄의 다른 요약 두 지적이 다른 `finding_id` 를 갖고, 하나 기각 · 하나 유지가 hold 없이 처리된다. 같은 요약은 같은 id 다.
- AC20 제외한 경로가 다른 바뀐 경로의 접두인 경우 그 아래 파일이 리뷰 diff 에서 조용히 빠지지 않는다 — 실리거나 `degraded: yes` 와 경로가 보인다. 이름 목록 대조가 빠진 경로를 잡는다.
- AC21 다른 세션 접미의 `worktrees/(base|head)-<8자>/` 등록 worktree 는 건너뛰지 않고 리뷰 안 된 중첩 레포로 `degraded: yes` 다. 이번 세션 접미는 지금처럼 건너뛴다.
- AC22 중첩 레포 — 추적 안 되는 중첩 레포 · 선언되지 않은 gitlink 는 리뷰하지 않고 `degraded: yes` 와 그 이름을 이스케이프한 이유 줄을 내며, Step 1c 가 그 줄을 사용자에게 옮긴다. 그 중첩 레포 설정의 명령은 돌지 않고 링크 뒤의 파일은 리뷰에 실리지 않는다.
- AC23 `codex exec` 를 부르는 러너 전부(도출 — 지금 넷)가 AGENTS.md 불러오기를 끄는 설정을 넘기거나, 넘기지 못하면 codex 축 공시 줄 · README 한계 절에 그 사실이 있다.
- AC24 e2e 시나리오 후보가 셋을 넘으면 질문 본문에 후보 수와 「기타」 칸으로 더 여는 길이 있다.

**락 · 판정기(§8)**
- AC25 `EXEMPT` 키에 줄 번호가 없고, 면제한 분기 위에 코드를 더해도 `exempt_stale=0` 이다. 정체가 겹치는 두 면제를 만들면 RED 이고, 가드 글자를 바꾸면 지금처럼 RED 다.
- AC26 plugin-audit 가 다른 플러그인 이름의 `DEVBREW_*_DISABLE` 만 있는 훅을 gap 으로 낸다. 지금 레포 플러그인들의 판정은 바뀌지 않는다(실측 대조).
- AC27 copy-of-contract 소비 도출이 다른 플러그인 전체 경로 인용을 소비로 세지 않고, `doc-critic.md` 양성 짝이 넓은 제외 변이에 RED 다.
- AC28 「첫 블록만 읽는」 변이에 같은 이름 블록 케이스가 RED 다.
- AC29 호출 표면 락이 `*/qg*` · `[/qg]` · 표 칸 `|/qg` · `<code>/qg</code>` 를 잡고 ` /qg.md` 꼴은 통과시키며, `docs/git-workflow/` · `.claude-plugin/marketplace.json` 을 본다(각각 음성 대조). 축 I 의 변이 일곱이 고친 뒤에도 기대대로 RED · GREEN 이다.

**문서 · project-init · 지휘(§9)**
- AC30 철학 문서에 「자리 넷」 문장이 없고 엔진 자리 셋과 qg `generic` 의 쓰임이 적혀 있다.
- AC31 project-init README · skill 에 「CLAUDE.md 는 그대로 두기」 + C-S3 (b) 동작 공시가 있고, S4 「옮기기」가 옮기지 않은 같은 이름 절을 advisory · Step 5 에 밝히며, Step 5 의 그 줄이 「「CLAUDE.md 는 그대로 두기」를 골랐다면:」으로 시작한다(테스트 접두 함께).
- AC32 `conductor-dispatch.md` `## 사람 자리` 에 원문 문장 보존 규칙과 「돌려보낸 글」 덧붙이기 걸음이 있다. relay-checker 는 바뀌지 않는다.
- AC32a design-doc 프로필 `approaches_comparison` 설명에 기각 대안의 같은 기준 비교 문장이 있고 축 수 · 골든은 그대로다(U7).
- AC33 로드맵 R1 · R3 · R5 블록의 경로 예약에 `skills/spec-interview/` 가 없다(지휘자 로드맵 PR).

**공통**
- AC34 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고쳤고, 변이로 이빨을 확인했다. 음의 락에는 양의 짝이 있다. 건드린 플러그인은 버전을 올리고 CHANGELOG 에 적는다.

## Files to Modify

- `shared/docreview/scripts/docreview_config.py` · `docreview_state.py` · `docreview_route.py` · `docreview_anchor.py`(§2 · §3 · §4) · `shared/tests/test_docreview_route.sh` · `shared/tests/fixtures/docreview/`(cases · cases_advice · 새 픽스처)
- `tools/adjudication/check_wiring.py` · `shared/tests/test_adjudication_wiring.sh`(§3 흡수 분기 · §8 키)
- `plugins/spec-distill/references/docreview-profiles/design-doc.md`(§9 — `approaches_comparison` 설명 한 줄, U7) · `plugins/spec-distill/references/conducting.md` 걸음 4 ③ · `plugins/spec-distill/tests/test_conducting_loop.sh` · `test_conducting_reference.sh`(§9 — 고정 문장)
- `plugins/spec-distill/tests/test_ledger_wiring.sh` · `shared/docreview/references/reviewing-document.md`(§5 · §6 — spec-distill `references/` 의 링크가 가리키는 정본)
- `plugins/spec-distill/skills/spec-review/SKILL.md`(§5 산문 · §6 대입 꼴 · 결정 줄 펜스 · 기각 되돌리기 걸음) · `skills/request-framing/SKILL.md` · `skills/reviewing-brief/SKILL.md`(§5 의 넓힌 락이 거는 산문만) · `references/redecompose.md` · `references/conductor-dispatch.md`
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `scripts/synthesize_findings.py` · `scripts/verdict.py`(축 플래그가 모자랄 때만) · `scripts/review-diff.sh` · `scripts/run_codex_reviewer.sh` · `scripts/run_artifact_codex_reviewer.sh` · `scripts/run_docreview_codex_reviewer.sh`(공유 정본 쪽) · `references/e2e.md`(플러그인 루트) · `skills/quality-pipeline/references/differential-test.md`(R24 문장) · `tests/test_synthesize_recritic.sh` · `tests/test_review_diff.sh` · `tests/test_e2e_docs.sh` · `tests/test_differential_procedure.sh` · `tests/test_skill_run_contract.sh`(R24 · K-3 · K-7) · codex 러너 설정 · 공시 테스트(AC23) · e2e 상한 공시 테스트(AC24) 자리
- `plugins/plugin-audit/scripts/check-shape-completeness.py` · `plugins/plugin-audit/tests/test_check_shape_completeness.py`
- `shared/tests/test_copy_of_contract.sh` · `shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh`
- `docs/philosophy/devbrew-harness-philosophy.md`
- `plugins/project-init/skills/project-init/SKILL.md` · `plugins/project-init/README.md` · `plugins/project-init/tests/test_command_contract.py`
- 건드린 플러그인마다 `plugin.json` · `CHANGELOG.md` · README(공시 · 한계)
- 계획 밖(지휘자 로드맵 PR): 로드맵 R1 · R3 · R5 경로 예약 · R12 브랜치 줄 · 경로 예약

## Verification Plan

- 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고친다. 락은 변이(삭제 · 추가 · 반전 · 형태 변경)로 이빨을 확인하고 양성 대조를 둔다. 변이 전에 커밋한다.
- 엔진: 기존 골든 · 케이스 스위트(`shared/tests/test_docreview_*.sh`)가 그대로 GREEN — 골든이 바뀌면 그 까닭을 계획에 적는다(§3 의 `§` 정규화는 골든을 바꾸지 않아야 한다).
- qg: 판정 상태 변조 픽스처(AC18) · 제외 접두 픽스처(AC20) · 다른 세션 worktree 픽스처(AC21) · 적대 중첩 레포 픽스처(AC22)를 임시 레포에서 돈다. 보안 재현은 격리한 임시 레포에서만 한다.
- codex 설정은 설치된 codex 로 실측한다(AGENTS.md 에 표지 문장을 심은 임시 트리에서 codex 출력이 그 지시를 따르지 않는지).
- 전체 스위트(`bash tools/suite/run-all.sh`) 대조 · 에픽 사이 통합 리뷰(지휘자).

## Rejected Alternatives

- qg 상태를 레포 밖(`TMPDIR` · `~/.claude/quality-gates`)으로 — CLAUDE.md 상태 규칙 개정이 필요하고, 같은 사용자로 도는 레포 코드는 레포 밖에도 닿는다(U2).
- qg 판정 파일의 해시를 턴에 들고 대조 — 다시 읽기를 지키는 장치가 하나 더 생긴다. 다시 읽지 않으면 필요 없다(U2).
- 엔진이 `reviewing-by` 표지를 직접 확인 — 공유 엔진이 spec-distill 을 알게 되어 계층이 뒤집힌다. 락으로 지킨다(§5).
- 번호 대조 · 미룸 표 행을 쓰는 새 엔진 명령 — 이미 있는 허가 길을 먼저 쓴다(U3). 계획이 표현 못 함을 보일 때만 다시 연다.
- 설계문서 프로필에 새 대안 비교 축 추가 — 있는 `approaches_comparison` 설명 한 줄로 충분하다(C32 · U7).
- 엔진 slug 가 `§` 를 남기게 바꾸기 — 모든 골든의 앵커가 흔들린다. 리뷰어 쪽을 정규화한다.
- 복수 앵커를 나눠 둘로 받기 · 같은 임시 번호를 다시 매기기 — 리뷰어가 낸 것과 다른 것을 조용히 만든다. 거부하고 이유를 보인다.
- 「추가만 허용」 판정에 `S<N>` 문법을 넣기 — 엔진이 spec-distill 문법을 알게 된다. 목록 항목만 본다.
- 닫힌 리뷰의 원장에 새 「닫힘」 칸 · 재리뷰 init 의 기록 칸 — 끝맺음 펜스의 계수 줄이 이미 닫힘을 남긴다.
- `check_wiring` 키에 줄 번호를 두고 재앵커 스크립트를 더하기 — 재앵커 함정(같은 정체 두 자리)이 남는다.
- 중첩 레포 안에서 git 을 돌려 파일 목록 얻기 — 중첩 레포 설정이 명령을 실행한다(PR #234 CRITICAL). 무시 규칙 없이 폴더를 통째로 펼치기 — 의존 폴더가 리뷰를 덮는다.
- relay-checker 가 설명 문장 수를 세기 — 새 판정 장치다(U3).
- project-init 「그대로 두기」 동작을 바꿔 AGENTS.md 에 헌장 절을 만들기 — 사용자가 고른 「손대지 않음」의 뜻이 흐려지고 손실은 없다.

## 결정 기록

- U1 · 결정 · 2026-10-20 · 사용자 — 「틀리거나 빠진거 없어」 (덩어리 1 — 범위 분류 · 이미 고친 수정 목록 소실 빼기 · 범위 밖 셋 더하기)
- U2 · 결정 · 2026-10-20 · 사용자 — 「다시 읽지 않기 (권장)」 (덩어리 2 — qg 판정 수치는 만든 직후 읽어 인자로, 리뷰 판정은 레포 코드가 돌기 전에 확정, CLAUDE.md 상태 규칙 그대로. 중첩 레포 리뷰 다시 열기 · push 보안 지적 둘은 R12 범위)
- U10 · 결정 · 2026-10-20 · 사용자 — 「Subagent-driven (권장)」(계획 셋 실행 방식) · 「알리기만 (권장)」(채택 결정 없는 표 손 편집은 알림만) · 「더한다 (권장)」(finalize 두 번을 위한 원장 칸 finalize_out — Anti-goal 「새 원장 칸」의 예외 하나) · 「더한다 (권장)」(engine_lines 의 kind: count 표지)
- U9 · 결정 · 2026-10-20 · 사용자 — 「고친 대로 둠 (권장)」(2라운드 반영 절) · 「열지 않음 (권장)」(추가 라운드)
- 지휘자 판단 · 2026-10-20 · spec 리뷰 3라운드 참고 반영 — 보호 해제 길 없음(제목 바꾸기 문장 뺌) · 계보 함수를 지나는 자리 다섯 · 줄 머리 표시는 `begin-round` 옮겨 적기 자리에서 · R24 인용 자리는 `grep` 으로 전부 · codex 러너는 `codex exec` 호출 전부로 도출(plugin-audit 포함) · 경로 예약 추가 목록에 테스트 파일들.
- U8 · 결정 · 2026-10-20 · 사용자 — 「기계가 낸 줄을 그대로 (권장)」 (spec 리뷰 2라운드 — qg 판정 인자는 기계가 낸 줄을 글자 그대로, R24 를 그 뜻으로 고침) · 「고친 대로 둠 (권장)」(1라운드 반영 절)
- 지휘자 판단 · 2026-10-20 · spec 리뷰 2라운드 참고 반영 — 줄 머리 표시는 스냅숏에 남김 · 보호는 엔진이 스스로 풀지 않음(README 공시) · 산문 락은 따옴표 · 경로 접두 표기도 셈 · conducting.md 걸음 4 ③ 은 계획 1 · 빠진 테스트 자리 채움.
- U5 · 결정 · 2026-10-20 · 사용자 — 「고친다 — 재리뷰 시작 전 줄만 (권장)」 (spec 리뷰 1라운드 06800cb8#r1.1)
- U6 · 결정 · 2026-10-20 · 사용자 — 「고친다 — 그 변경에만 허가 (권장)」 (spec 리뷰 1라운드 06800cb8#r1.2)
- U7 · 결정 · 2026-10-20 · 사용자 — 「고친다 — 설명 한 줄 더하기 (권장)」 (spec 리뷰 1라운드 b3bf4e58#r1.1 — 덩어리 3 의 「빼기」를 대체)
- 지휘자 판단 · 2026-10-20 · spec 리뷰 1라운드 참고 반영 — 「추가만」의 줄 모양은 문서 본문에서 읽음(해시만으로는 못 봄) · conducting.md 걸음 4 ③ 을 결정 기록 절 끝에 쓰는 쪽으로 바꿈(§4 의 새 길을 지휘 절차가 쓰게).
- U4 · 결정 · 2026-10-20 · 사용자 — 「최종 판정만 (권장)」 (설계문서 점검 답 — qg 「다시 읽지 않기」는 최종 판정 수치만 지키고 반복 중간 단계 · 남은 프로세스의 영향은 README 한계로 공시)
- 지휘자 판단 · 2026-10-20 · 설계문서 점검 답 — 산문 락은 `docreview_state.py declare-related | log-decision` 꼴만 · 문단은 빈 줄 블록 또는 목록 항목 · 지시와 설명을 가르지 않음 · 보호 계보는 채택 결정의 허가가 그 앵커를 덮으면 끝나고 같은 slug 새 절은 보호 쪽으로 닫음 · 「닫힌 뒤 손으로 쓴 줄」은 위치(마지막 계수 줄 아래)로 가림. (앞의 둘은 spec 리뷰 1라운드 U5 · U6 과 2라운드 지휘자 판단으로 대체됨 — §4 본문이 정본)
- U3 · 결정 · 2026-10-20 · 사용자 — 「좋아 다만 이것도 역시 너무 과한 장치로 가진 말고」 (덩어리 3 — 설계 항목 기본안 표 채택, 새 명령 · 새 상태보다 이미 있는 허가 · 거부와 이유 · 공시 · 락 넓히기 먼저)
- 앞선 결정 · 2026-10-20 · 사용자 — 「R12 로 (권장)」 (qg 판정 상태 위치를 R12 로 — PR #234)
- 지휘자 판단 · 2026-10-20 — project-init 「CLAUDE.md 는 그대로 두기」 + C-S3 (b) 는 손실이 없어 동작을 바꾸지 않고 README · skill 에 공시한다(§9).
- 지휘자 판단 · 2026-10-20 — 지휘 절차 교훈은 `conductor-dispatch.md` 규칙 한 줄과 「돌려보낸 글」 덧붙이기 걸음까지만, relay-checker 는 그대로(§9).
- 지휘자 판단 · 2026-10-20 · 설계문서 작성 — 최댓값은 기본값 · 테스트 값보다 넉넉하게 계획이 정하고 공시(§2) · 「추가만」은 0열 새 목록 항목으로 판정(엔진은 `S<N>` 을 모름, §2) · `related-changes` 는 엔진 출력 이스케이프만(§2) · 복수 앵커 · 같은 임시 번호는 보류 계수로 거부(§3) · `§` 는 라우터에서 엔진 slug 규칙으로 정규화(§3) · 닫힘 표지는 끝맺음 펜스의 계수 줄(§4) · 펜스 락 대상은 도출(§5) · 대입 꼴은 `read` + 따옴표 heredoc(§6) · 결정 줄 펜스는 `spec_path` 레포로 들어감(§6) · 중첩 레포는 git 없이 · 링크 없이 무시 규칙을 지킬 길이 있을 때만 리뷰(§7) · codex AGENTS.md 는 설정 또는 공시(§7) · `EXEMPT` 같은 정체는 둘러싼 `for` 의 순회 대상으로 가름(§8) · 로드맵 R1 · R3 · R5 는 이름 따라가기라 지휘자 로드맵 PR 이 고침(§9) · 계획 셋과 브랜치 이름(§11).
- D1.1 · r1 · adopt · 06800cb8#r1.1 · "고친다 — 재리뷰 시작 전 줄만 (권장)" — 마지막 계수 줄 아래라는 위치는 리뷰가 닫힌 동안 쓴 줄임을 증명하지 않는다. 재리뷰를 시작한 뒤 손으로 추가한 줄도 이전 계수 줄 아래에 있으므로, 열린 리뷰의 손 편집까지 기록으로 면제된다.
- D1.2 · r1 · adopt · 06800cb8#r1.2 · "고친다 — 그 변경에만 허가 (권장)" — 한 번의 수정 승인을 보호 해제 승인으로 해석한다. 보호 절 밖으로 밀려난 자식 절의 오타 수정을 승인해도 보호 이력이 끝나므로, 이후 내용 변경까지 사용자 확인 없이 허용될 수 있다.
- D1.3 · r1 · adopt · b3bf4e58#r1.1 · "고친다 — 설명 한 줄 더하기 (권장)" — 묶음이 할 일로 받은 「설계문서 프로필의 대안 비교 축」을 설계가 뺐는데, 사용자가 이 항목을 빼기로 승인한 기록이 없다. 지금 있는 두 축도 이 항목이 요청한 것을 잡지 못한다.
- D2.4 · r2 · adopt · 1ac658b5#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §9 문서 · project-init · 지휘 절차 (modified)
- D2.5 · r2 · adopt · 496041cc#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Rejected Alternatives (modified)
- D2.6 · r2 · adopt · 6697c411#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: 원칙 · 입력 대조 (modified)
- D2.7 · r2 · adopt · 6c8b9494#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Files to Modify (modified)
- D2.8 · r2 · adopt · 93a5c0ad#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D2.9 · r2 · adopt · a8a95e6d#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: 번호 대조 (modified)
- D2.10 · r2 · adopt · c6c0ccc8#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Anti-goals (modified)
- D2.11 · r2 · adopt · c934ff7b#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: 상류 · 하류 연계 (modified)
- D3.12 · r3 · adopt · 5267fc19#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §4 보호 · 정리 · 닫힌 리뷰 (modified)
- D3.13 · r3 · adopt · 6697c411#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: 원칙 · 입력 대조 (modified)
- D3.14 · r3 · adopt · 6c8b9494#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Files to Modify (modified)
- D3.15 · r3 · adopt · 7ba96ef1#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §7 qg 판정 — 다시 읽지 않기 (modified)
- D3.16 · r3 · adopt · 8a3ed3b0#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §5 원장 쓰기 순서 — 펜스 락을 산문까지 (modified)
- D3.17 · r3 · adopt · 93a5c0ad#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D3.18 · r3 · adopt · c1d6a48e#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §2 엔진 값 · 원문 절 · 리뷰어 입력 (modified)
- D3.19 · r3 · adopt · e939aca4#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §11 계획 나누기 (modified)
- docreview 계수 — spec-distill/2026-10-20-review-engine-leftovers-desig-974946fb0f229bd2 r1: advice_new=2 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill/2026-10-20-review-engine-leftovers-desig-974946fb0f229bd2 r2: advice_new=5 · advice_repeat=2 · mc_preexisting_new=0
- docreview 계수 — spec-distill/2026-10-20-review-engine-leftovers-desig-974946fb0f229bd2 r3: advice_new=5 · advice_repeat=1 · mc_preexisting_new=0
- 지휘자 판단 · 2026-10-20 · 계획 2 — 중첩 레포 내용 리뷰는 안전한 길이 라운드마다 새 보안 결함을 낳아(색인 파싱 · v4 · includeIf) 설계 §7 의 대안 갈래(리뷰하지 않고 막고 이유를 싣는다)로 돌린다 — 사용자가 다시 열 수 있다
- U11 · 결정 · 2026-10-20 · 사용자 — 「qg에 대한 질문답은 이대로로」 (계획 2 — 중첩 레포 내용 리뷰는 대안 갈래 확정)
- 지휘자 판단 · 2026-10-20 · 계획 2 — 남은 qg worktree 를 지우는 길은 qg-gc 가 아니라 git worktree remove --force 다(qg-gc 는 worktrees/ 를 지우지 않는다)

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| C25 | 반영 | Constraints · §7(codex 는 설정만 넘김) |
| C32 | 반영 | Anti-goals · `## 있는 것 검토` · §1 · §9(대안 비교는 있는 축의 설명 한 줄) |
| C35 | 반영 | Constraints · Non-goals |
| D21 | 반영 | §10(묶음 위험 없음 — 새로 여는 위험에 답) |
| D26 | 반영 | Constraints · §7(codex 쪽은 넘기는 설정 · 공시만) |
| S1 | 반영 | Context(묶음 의도의 출처) · Goals |
| S13 | 반영 | §10 |
| S17 | 반영 | Constraints · Non-goals |
| S18 | 반영 | Constraints · §7 |
| S30 | 반영 | Anti-goals · `## 있는 것 검토` |
| S34 | 반영 | Constraints · Non-goals |
| S49 | 반영 | §1 — 묶음 범위 항목 전부를 다룸(대안 비교 축은 있는 축 설명 한 줄로, 수정 목록 소실은 이미 고쳐 남은 자리만) |

## 원칙 · 입력 대조

| 입력 | 자리 |
|---|---|
| CLAUDE.md 기본값과 판단 | §11 끝 · §2(최댓값은 계획이 정함) |
| CLAUDE.md 레포 전용 값 금지 | §5(대상 도출) · §8(kill switch 는 자기 이름에서) |
| CLAUDE.md 상류 · 하류 연계 | `## 상류 · 하류 연계` |
| CLAUDE.md 진입점에서 따라 내려가기 | §7(판정 줄에 옮긴 값이 보임) · §4(게이트에 기록 줄) |
| CLAUDE.md 있는 것 먼저 | `## 있는 것 검토` |
| CLAUDE.md 처분 줄 · 공시와 차단 | §3(보류 · 강제 계수) |
| 과설계 경계(R8 설계 U5 사용자 「너무 과한 장치와 제약(과설계)만 경계해 devbrew원칙이야」) · U3 | Anti-goals · §5 · §6 · §9 |
| U1 범위 분류 | §1 |
| U2 다시 읽지 않기 | §7 |
| U3 가벼운 장치 | Anti-goals · §2~§6 · §9 |
| U4 qg 는 최종 판정만 | §7 |
| U5 닫힌 뒤 줄은 재리뷰 시작 전만 | §4 |
| U6 허가는 그 변경에만 | §4 |
| U7 대안 비교는 설명 한 줄 | §1 · §9 |
| U8 판정 인자는 기계가 낸 줄 그대로 | §7 · AC17 |
| R2a 설계 미룸 :433(보안 참고 넷) | §2 · §5 |
| R2a 설계 미룸 :434 | §4 |
| R2a 설계 미룸 :435 · :436 | §6 · §4 |
| R2a 설계 미룸 :437 | §5 |
| R2a 설계 미룸 :440-442 | §9 |
| R2a 설계 미룸 :443-447 | §8 · §3 · §4 · Anti-goals · §9 · §7 |
| R2a 설계 미룸 :448 | §7 |
| R2a 설계 미룸 :122 · :449 | §7(e2e 공시) |
| R2a 설계 미룸 :419 · :421 · :422 · :423 | §8 · §3 |
| PR #231 엔진 잔여 셋 | §6 |
| PR #234 codex AGENTS.md · 중첩 레포 | §7 |
| R10 계획 2 통합 리뷰(재분해 rc 1) | §6 |
| R10 계획 3(로드맵 경로 예약) | §9 |
| R10 계획 3 통합 리뷰(축 I 변이) | §8 |
| R10 relay 대조(지휘 절차) | §9 |
| R10 계획 3 push 보안 리뷰(qg MEDIUM 둘) | §7 |

## 미룸

| 항목 | 이유 | 받는 곳 |
|---|---|---|
| 엔진 밖에서 셸이 원장을 쓰는 길 — `declare-related` · `log-decision` 이 표지 확인 없이 불려도 엔진은 거부하지 않는다(락은 절차 문면만 지킨다) | 권한 경계(R2a 설계 AC17 가)는 레포 밖 몫으로 R8 범위다 | R8 |

## 지휘 기록

- spec 승인 · 2026-10-20 · 「승인 — 계획 담당자에게 (권장)」

## Metadata

- 에픽: R12 · 브랜치 `feature/review-engine-leftovers`(계획 1) · `feature/qg-verdict-state`(계획 2) · `feature/review-lock-leftovers`(계획 3) — §11, 로드맵 브랜치 줄은 지휘자 로드맵 PR · 묶음 `R12.md`
- 크기: 계획 셋(§11)
- 의존: R2a · R11(머지됨). 뒤에 R13 · R8.
- 버전: 계획마다 건드린 플러그인(spec-distill · quality-gates · plugin-audit · project-init) minor bump(동작 고침만이면 patch). 번호는 머지 직전에 정한다.

### Deferred to plan

- §6 허가 길: 기각 되돌리기(게이트 기타 칸의 답)와 재분해(「인터뷰 다시 열기」 갈래)에서 표 행 고침을 묶을 채택 결정 · permit 이 있는지 — `declare-related` 또는 `check-intent --decision-id` 로 표현되는지 먼저 확인한다. 표현되지 않으면 새 엔진 명령을 만들기 전에 지휘 세션에 설계 변경으로 보고한다.
- §2 최댓값 네 값과 그 공시 문구.
- §2 「추가만」 판정이 payload §6 · 다른 프로필의 불변 절 실물 꼴(빈 줄 · 출처 표기 블록)에서 맞는지 실측.
- §4 닫힘 표지(계수 줄)가 진입 skill 셋의 모든 닫는 갈래에서 쓰이는지 — 쓰이지 않는 갈래가 있으면 그 갈래의 처리.
- §7 리뷰 축 합성을 차등 테스트 앞으로 옮길 때 합성기 `--emit-verdict` 가 차등 입력 없이 낼 값과, 각 축을 `verdict.py` 의 어느 플래그로 넘기는지의 표. 모자란 플래그만 더한다.
- §7 중첩 레포 파일 목록을 그 레포 안에서 git 을 돌리지 않고 무시 규칙대로 얻는 길(바깥 git 의 무시 판정이 중첩 레포 안 `.gitignore` 를 읽는지 등)의 실측 — 없으면 지금 동작 + 이유 공시. (계획 2 — 안전한 길 없음, 지금 동작 + 이유 공시)
- §7 codex-cli 0.160.0 에서 AGENTS.md(프로젝트 문서) 불러오기를 끄는 설정 키의 실측.
- §7 판정 id 를 실행 사이에 읽는 소비자가 없는지.
- §8 `EXEMPT` 둘러싼 `for` 의 순회 대상 글자를 `scan()` 행에서 얻을 수 있는지 — 없으면 같은 내용 기반의 다른 가르개.
- §8 plugin-audit kill switch 를 자기 이름으로 묶었을 때 레포의 각 플러그인 판정 대조.

| # | 항목 |
|---|---|
| d62bf01a#r1.1 | 참고(data_flow) #2-엔진-값--원문-절--리뷰어-입력 — 새 목록 항목인지 판정하는 데 필요한 줄 모양이 판정 함수까지 전달되지 않는다. 실제 스냅숏 생성과 원장 저장은 본문 대신 줄 해시를 남기므로, 해시만으로 첫 내용 줄의 목록 표지를 확인할 수 없다. — 고치면: 스냅숏 생성 시 줄별 빈 줄 여부와 0열 목록 시작 여부를 계산하고, 불변 절의 해당 정보를 원장에 보존해 추가 판정에 전달한다. 이 정보가 없는 옛 스냅숏은 추가 면제를 적용하지 않는다고 명시하고, 생산·저장·소비 경로를 설계에 연결한다. |
| 8e36d574#r1.1 | 참고(component_relations) #4-보호--정리--닫힌-리뷰 — 제약 절에는 이 에픽이 conducting.md 를 고친다고 적혀 있다. 그런데 어느 절도 무엇을 고치는지 말하지 않고, 수정 파일 목록에도 없다. 그사이 §4 는 닫힌 리뷰에 손으로 쓴 결정 줄을 받아들이게 바뀌지만, 지휘 절차는 그런 줄을 여전히 지휘 기록으로 보낸다. — 고치면: §4 에 conducting.md 걸음 4 ③ 을 「리뷰가 닫혔으면 결정 기록 절 끝, 곧 마지막 계수 줄 아래에 손으로 쓴다. 재리뷰가 그 줄을 기록으로 읽는다」로 바꾸는 걸음을 더한다. Files to Modify 에는 `references/conducting.md` 와 위 두 테스트의 고정 문장을 더하고 AC11 에 지휘 절차 쪽 단언을 붙인다. ③ 을 그대로 두기로 하면 Constraints 에서 conducting.md 를 빼고 §4 에 그 이유를 한 줄 적는다. |
| ed6d45de#r2.1 | 참고(component_relations) #11-계획-나누기 — 지휘 절차(conducting.md 걸음 4 ③)를 「닫힌 리뷰면 결정 기록 절 끝에 손으로 쓴다」로 바꾸는 일은 계획 3 에 있다. 그런데 그 줄을 기록으로 받아 주는 엔진 변경(§4)은 계획 1 에 있다. 둘이 병렬로 머지될 수 있다고 적혀 있어 순서가 보장되지 않는다. |
| 294e4463#r2.1 | 참고(tradeoffs) #7-qg-판정--다시-읽지-않기 — 최종 판정 펜스가 숫자와 축을 「턴에 들고 온 값」으로 넘기게 바꾸면, 판정 숫자는 셸이 기계 출력에서 뽑고 모델이 채우지 않는다는 기존 규칙과 그 규칙을 지키는 락을 뒤집는다. 그런데 설계는 이 사실을 밝히지 않았다. — 고치면: 다시 읽지 않기(U2)는 그대로 둔다. 다만 리뷰 축 합성 직후와 차등 테스트 직후의 펜스가 판정 인자 한 줄(예: `qg-verdict-args: --blocking 2 --optional 1 --defect …`)을 기계 출력으로 내게 한다. 최종 판정 펜스는 그 줄을 글자 그대로 붙여 넣는다 — 모델은 숫자를 고르지 않고 줄을 옮기기만 한다. R24 락은 「판정 인자는 기계가 낸 줄의 글자 그대로」로 바꾸고, test_e2e_docs.sh 의 K-3 · K-7 · R24 단언을 함께 고친다. 설계 §7 · §10 에 이것이 기존 V1 · R24 규칙을 어떻게 바꾸는지 한 줄 적는다. |
| f3af3c5a#r2.1 | 참고(ambiguity) #4-보호--정리--닫힌-리뷰 — §4 는 보호 이력이 「사용자가 보호 경계를 옮기는 결정을 명시로 채택했을 때」만 끝난다고 했다. 그런데 엔진이 어떤 결정을 「경계를 옮기는 결정」으로 알아보는지를 적지 않았다. 결정 기록에는 이와 반대인 앞선 지휘자 판단(허가가 그 앵커를 덮으면 보호가 끝남)이 대체 표시 없이 남아 있다. |
| 4de67ca2#r2.1 | 참고(ambiguity) #5-원장-쓰기-순서--펜스-락을-산문까지 — 산문 락이 세는 꼴을 「`docreview_state.py declare-related` · `docreview_state.py log-decision`」 글자로만 정했다. 그래서 스크립트 이름과 하위 명령 사이에 따옴표 · 백틱 · 경로 변수가 낀 표기(예: `"$SD/scripts/docreview_state.py" log-decision`, `` `docreview_state.py` 의 `declare-related` ``)를 세는지가 정해지지 않았다. 허용할 표기와 그 표기별 음성 변이를 적어야 한다. |
| 1cdda836#r2.2 | 참고(handoff_incomplete) #files-to-modify — Files to Modify 와 §11 의 경로 예약 추가 목록에 바뀌는 테스트 자리가 빠졌다. 최종 판정 펜스를 고정한 plugins/quality-gates/tests/test_e2e_docs.sh, codex 러너 셋의 설정 · 공시를 지킬 테스트(AC23), e2e 시나리오 상한 공시 테스트(AC24)가 없다. Files to Modify 에는 있는 plugins/spec-distill/tests/test_conducting_loop.sh · test_conducting_reference.sh 는 로드맵 R12 예약에도 없고 §11 의 추가 목록에도 없다. |
| 594338de#r3.1 | 참고(handoff_incomplete) #11-계획-나누기 — §11 에 지휘자가 로드맵 PR 로 더할 경로 예약 목록이 있는데, Files to Modify 에 있으면서 R12 예약에도 없는 테스트 파일들이 이 목록에 빠져 있습니다. |
| 20b65960#r3.1 | 참고(handoff_incomplete) #2-엔진-값--원문-절--리뷰어-입력 — 줄마다 「0열 `- ` 로 시작하는가」 표시를 남긴다고 했지만, 원장 스냅숏을 만드는 `begin-round` 가 정해진 칸만 옮겨 적기 때문에 그 표시가 원장에 남지 않습니다. 표시를 옮길 자리(줄 해시를 남기는 같은 자리)를 적어야 합니다. |
| 73b238ba#r3.1 | 참고(handoff_incomplete) #4-보호--정리--닫힌-리뷰 — 계보 함수를 거쳐야 할 자리가 `classify_anchor` 와 `round_fence` 둘만 적혀 있습니다. 지금 스냅숏만 보는 불변 판정 자리 셋이 빠져 있어서, 밖으로 밀려난 자식 절은 울타리에서는 불변인데 다른 곳에서는 불변이 아닌 것으로 갈립니다. |
| 229c1f42#r3.1 | 참고(ambiguity) #7-qg-판정--다시-읽지-않기 — 「검토 대상 트리의 AGENTS.md 를 지시로 읽는다」는 노출에 대해 codex 러너를 셋(코드·산출물·문서 리뷰)만 꼽았습니다. 그런데 레포에는 같은 꼴로 남의 트리를 cwd 로 codex 를 부르는 넷째 러너(plugin-audit)가 있습니다. 러너를 손으로 꼽지 말고 `codex exec` 를 부르는 곳 전부로 도출하게 적어야 합니다. |
| 5e63ff1e#r3.1 | 참고(handoff_incomplete) #7-qg-판정--다시-읽지-않기 — R24 를 고칠 자리 목록이 일부만 있고 한 경로가 틀렸습니다. 이대로면 AC17 의 「옛 문장이 남지 않는다」를 지킬 수 없으니, R24·K-3 를 인용하는 자리를 grep 으로 전부 뽑아 고치도록 바꿔야 합니다. 판정 펜스가 넘기는 인자 목록에서도 지금 쓰는 `--line`·`--iter`·`--e2e-overridden` 이 빠져 있습니다. |
