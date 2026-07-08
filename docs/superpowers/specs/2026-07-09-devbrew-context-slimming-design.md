---
name: devbrew-context-slimming
type: design-doc
created_at: 2026-07-09
revised_at: 2026-07-09
status: draft (review round 1 반영)
approach: "B — lean rewrite"
source_interview: docs/superpowers/interview/2026-07-08-devbrew-context-slimming-interview.md
locked_directions: "LD1–LD9 (interview brief frontmatter — 재논쟁 금지)"
history_disposition: "annotated tag (pre-slim-archive-2026-07-09) 후 working-tree 삭제"
scope_note: "agent strip(pr-understanding-builder/publish)은 별도 spec으로 carve-out(2026-07-09 사용자 결정). project-init 재실행은 sandbox-verify만(실제 S2 migration 미트리거)."
implementation: "ultracode (Workflow orchestration)"
---

# devbrew Context Slimming — Design (Approach B: Lean Rewrite)

> **구조적 핵심으로 환원한다.** "특별함 = 구조적 load-bearing"만 남기고, 현대 모델+하네스가
> 기본 수행하거나 코드·generic best-practice가 커버하는 재진술·역사 축적·외부 인용 장치를 걷어낸다.
> 보안/정확성 집행 계층은 category error를 피해 **불변으로 보존**한다(LD8).

이 설계는 `2026-07-08-devbrew-context-slimming-interview.md` brief를 해답공간으로 이어받은
산출물이다. 실측 맵(4-mapper understand 워크플로우)으로 OQ1/OQ2/OQ3/OQ5를 해소했고, OQ4/OQ6는
아래 §6·§7에서 확정한다. Law 2 분리 리뷰(canonical spec-reviewer + 3 adversarial 렌즈 + 반증
검증) 1라운드를 반영해 개정했다 — §Handoff Context 참조.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints (LD8 보존 경계)](#4-constraints-ld8-보존-경계)
- [5. Workstreams (아키텍처)](#5-workstreams-아키텍처)
  - [5.1 WS1 — 철학 doc lean rewrite (OQ1)](#51-ws1--철학-doc-lean-rewrite-oq1)
  - [5.2 WS2 — history 아카이브 + 삭제 (OQ2)](#52-ws2--history-아카이브--삭제-oq2)
  - [5.3 WS3 — agent strip [DESCOPED → 별도 spec]](#53-ws3--agent-strip-descoped--별도-spec)
  - [5.4 WS4 — 런타임 컨텍스트 트림 (OQ5)](#54-ws4--런타임-컨텍스트-트림-oq5)
  - [5.5 WS5 — project-init sandbox-verify (OQ4)](#55-ws5--project-init-sandbox-verify-oq4)
- [6. PR 분해 & 프로세스 rigor (OQ6)](#6-pr-분해--프로세스-rigor-oq6)
- [7. Acceptance Criteria](#7-acceptance-criteria)
- [8. Files to Modify](#8-files-to-modify)
- [9. Verification Plan](#9-verification-plan)
- [10. Rejected Alternatives](#10-rejected-alternatives)
- [11. Metadata](#11-metadata)
- [Handoff Context](#handoff-context)
- [Appendix A — 철학 doc keep/trim/strip 분류 (ground truth)](#appendix-a--철학-doc-keeptrimstrip-분류-ground-truth)

## 1. Context / Why

devbrew의 마크다운은 총 ~93k줄이며, 그중 **plans(64k/53파일) + specs(15k/52파일) = ~80k줄(85%)**
가 append-only 역사다. 철학 doc은 938줄인데 실측상 **~12개 원칙만 구조적 load-bearing**이고 나머지는
generic best-practice 재진술·Anthropic/소스 인용·CLAUDE.md와의 verbatim 중복·미구현 feature 흡수
문단이다. 이 축적이 devbrew의 차별적 핵심(Three Laws의 구조적 집행)을 파묻는다.

실측 reframe(중요): **매 세션 always-on 컨텍스트는 ~145줄로 작다**(CLAUDE.md 98 + MEMORY.md 47;
SessionStart 훅은 clean 세션에서 0 토큰). 철학 doc·history는 always-on이 *아니라* 참조 시에만
로드된다. 따라서 이들 감량의 이득은 "토큰/세션 절감"이 아니라 **repo signal-to-noise(핵심 파묻힘)
와 discoverability 회복**이다. 이는 LD1(B+C 우선)과 모순되지 않으며, "왜 감량하는가"의 논거를
정확히 재조정한다 — target C(런타임)는 소폭·저비용, target A/B(history/철학)는 신호 회복이 이득.

감량 후 project-init을 sandbox에서 재실행해 lean baseline이 깔끔히 재생성됨을 검증한다(LD3, §5.5).

## 2. Goals

- **G1**: 철학 doc을 "24개 원칙 카탈로그"에서 "구조 메커니즘 → 코드 지도"로 재작성 — KEEP-12
  구조 원칙만 존치, 각각 코드 cross-ref로 뒷받침(prose 재진술 대체). `P#` 앵커 보존.
- **G2**: 외부 인용 apparatus(Appendix A·Attribution Map·quote 블록)와 `../reference` 포인터
  제거 → doc self-contained·경량화(LD7).
- **G3**: ~80k줄 역사 docs를 annotated tag로 봉인 후 working-tree에서 삭제 → repo 경량화, git
  복구성 유지(OQ2).
- **G4**: always-on 컨텍스트(CLAUDE.md 저술 섹션·verbose description)를 포인터화·압축(OQ5, target C).
- **G5**: project-init을 sandbox에서 재실행해 lean baseline의 스캐폴딩 재생성이 stripped 내용을
  재유입하지 않음을 검증(LD3, OQ4) — 실제 repo의 CLAUDE.md-primary 구조는 불변.
- **G6**: 감량 과정 자체를 devbrew 자기 규율(spec→review→compound)로 진행하되 rigor를 리스크
  등급에 맞춤(OQ6) — plugin/persona 접촉 변경엔 full 게이트, 순수 docs 변경엔 경량.

> **Descoped (2026-07-09 사용자 결정)**: pr-understanding-builder + qg-publish 기능 strip은 이
> effort의 goal이 *아니다* — 별도 spec으로 carve-out(§5.3, NG7). 리뷰가 그 blast radius(구조적
> 보안 plumbing·#94/#95 revert·별도 rigor 등급)를 드러내 docs-slimming과 뒤섞지 않는다.

## 3. Non-goals

- **NG1**: 구조적 보안/정확성 게이트 strip 금지 — KEEP-12, KEEP 6 agent + codex, Law 2 tool-deny,
  결정론 fail-closed 셸 게이트, spec 5-ritual(`check_brief.py`), `/qg` 게이트는 대상 아님(LD8).
- **NG2**: plugin CHANGELOG(`plugins/*/CHANGELOG.md`) 정리는 범위 밖 — 버전 이력은 load-bearing.
- **NG3**: `docs/git-workflow/`(241줄), `docs/philosophy/` 자체 삭제는 아님 — git-workflow는
  load-bearing 가이드, 철학 doc은 삭제가 아니라 rewrite(파일 존치, `P#` 앵커 유지).
- **NG4**: 인터뷰 조력 agent(steelman-builder·breadth-keeper) strip 금지 — steelman은 R3
  Skepticism 게이트를 채우는 Law 1 조력, breadth는 tunneling 방지(B 확정, C안 기각).
- **NG5**: MEMORY.md 아카이브는 repo PR이 *아니라* 사용자 메모리 도구 액션(repo 밖 경로) — 설계엔
  포함하되 구현 시퀀스에서 별도 취급, repo AC 스코프 밖(AC14).
- **NG6**: 이번 감량 self-approval 금지 — 설계 doc은 Law 2 분리 reviewer(spec-reviewer + 독립
  adversarial 렌즈)가 검증하고, 최종 승인은 사용자.
- **NG7 (신규)**: `pr-understanding-builder` agent + qg-publish continuation 기능 strip은 이
  effort 범위 밖 — 별도 brainstorming→spec→review→/qg 사이클로 처리(§5.3). 이 effort는 그 agent를
  건드리지 않으며, 따라서 C-KEEP-AGENTS는 이 effort 동안 pr-understanding-builder도 포함한다.

## 4. Constraints (LD8 보존 경계)

"strip은 prose/docs/refs/history/런타임컨텍스트 한정, 구조 게이트는 보존." 구체 불변식:

- **C-KEEP-PRINCIPLES**: 철학 KEEP-12(P2·P3·P4·P10·P11·P12·P13·P17·P18·P21·P22 + AP3)는 존치.
  더해 **P8 determinism-economy 통찰**은 이 감량 자체를 정당화하는 devbrew-original 메타룰이므로
  essence doc 또는 CLAUDE.md에 반드시 생존 — **두 방향 모두**(불필요한 결정론 제거 AND load-bearing
  지점에 정확히 부과)를 semantic하게 보존(AC3). 마찬가지로 **P14 compaction-survival 규칙**(턴 종료
  전 load-bearing 사실 파일 기록 / 대화-only 사실은 compaction 후 사망)은 CLAUDE.md에 부재하므로
  philosophy essence에서 문장으로 생존해야 하며, README 3곳 인용이 이를 backstop한다(AC5).
- **C-KEEP-AGENTS**: security-reviewer·adversarial·runtime-verifier·test-scope-validator·
  spec-reviewer + codex 스크립트 경로는 존치. NG7에 따라 pr-understanding-builder도 이 effort 동안
  존치(별도 spec에서 처리).
- **C-LAW2**: reviewer agent의 `Write`/`Edit` deny frontmatter 불변. runtime-verifier의 scoped
  `Write`(R6 예외)는 orchestrator git-diff mutation guard로 분리 — 이 구조 불변.
- **C-DETERMINISM**: 결정론 fail-closed 셸 게이트(`check-review-scope.sh`, `check_brief.py`,
  qg 게이트 스크립트)와 kill switch 존중은 불변.
- **C-NO-DANGLING**: 모든 cross-ref(`P#`·`AP#`·`§X.Y`·파일 링크)는 rewrite 후 resolve하거나
  같은 커밋에서 갱신 — dangling 참조 금지(AC5, body-unique 검증). **README "Principles Instantiated"
  cross-ref 정합은 mandatory·multi-plugin**(spec-distill·quality-gates·project-init 모두 대상);
  제거/개명된 원칙을 인용하던 README 줄은 **삭제가 아니라 생존 개념(KEEP-12)으로 re-point** —
  philosophy §10에 따라 cited 원칙 제거는 breaking change이자 Law-3 instantiation 기록 손실이므로,
  instantiation 사실을 보존하며 앵커만 갱신한다. 인용된 TRIM 원칙은 삭제가 아니라 **stub 앵커**로
  생존(§5.1) — KEEP-12은 전체 엔트리로 존치.
- **C-GIT-RECOVER**: history 삭제 전 annotated tag로 봉인 + `git status` clean 확인 —
  uncommitted 손실 0. 활성 slimming 산출물(design·plan·active interview brief)은 삭제 대상 제외.

## 5. Workstreams (아키텍처)

각 워크스트림은 독립 unit — 명확한 입력/출력/검증을 가지며 개별 PR로 격리된다(§6).

### 5.1 WS1 — 철학 doc lean rewrite (OQ1)

**입력**: `docs/philosophy/devbrew-harness-philosophy.md`(938) + `docs/philosophy/*roadmap*.md`(367)
+ Appendix A 분류.
**출력**: ~200줄 essence doc + 트림된 roadmap(또는 제거) + 갱신된 cross-ref(multi-plugin).

- **KEEP-12를 full 엔트리로**: 각 엔트리 = {메커니즘 이름, instantiate하는 Law, 코드 cross-ref
  (`path` 또는 `path:line`), 한 줄 "왜 load-bearing"}. prose 재진술 금지 — 코드를 가리킨다.
- **STRIP 처리 — 두 형태 구분**(header-satisfiable 함정 회피, feedback_grep_lock_header_satisfiable):
  - **STRIP-standalone**(실제 `### AP##`/`### P##` 헤더 있음): P16·AP4·AP7·AP8·AP14 — 헤더+본문 제거.
  - **STRIP-redirect**(standalone 헤더 없이 KEEP/TRIM 본문·§11.1 마이그레이션 테이블에 흡수된 redirect
    prose로만 존재): AP10(→P5)·AP11(→P3)·AP17(→P14) — **redirect prose 자체를 제거**(header 부재를
    확인하는 것으로는 vacuous). §Appendix A 참조.
- **TRIM 처리**: 규칙이 CLAUDE.md에 이미 full로 있는 것은 philosophy 엔트리 제거(규칙은 CLAUDE.md
  존치), devbrew-original 통찰(특히 P8)·CLAUDE.md 부재 규칙(P14 compaction-survival)은 tight
  one-liner로 생존. 기본 disposition = one-liner; Appendix A의 CLAUDE.md-중복분만 엔트리 제거. **단 엔트리 제거는
  무인용 중복에 한정** — CLAUDE.md/README가 `P#`/`AP#`로 인용하는 TRIM 원칙(AP2·AP5·AP9·AP16, §4.0
  등)은 삭제하지 않고 **stub 앵커**(한 줄 `### AP2 → CLAUDE.md Forbidden Patterns`)로 생존시켜 AC5
  resolve + Law-3 instantiation 기록 보존.
  판정 세부는 writing-plans가 Appendix A 기준으로 확정(AC5 dangling-check + PR1 분리 리뷰가 backstop).
- **외부 apparatus 제거**(LD7·G2): Appendix A(876–938, ~100% verbatim quote)·§6 Attribution
  Map(689–737)·§0/§5 quote 블록·absorbed-source 인벤토리·`../reference` 포인터(CLAUDE.md:8).
- **roadmap doc**: 실제 near-term 계획만 존치, 미구현 aspirational/흡수 문단 삭제. 남는 실질
  로드맵이 없으면 doc 제거(+ cross-ref 갱신).
- **cross-ref 정합(C-NO-DANGLING, mandatory·multi-plugin)**: CLAUDE.md의 철학 §-anchor 인용(§1
  Law 2 R6 note·§2.1·§4.0·§4.8·§5.3·§2·§11.1 등)·`P#`/`AP#` 인용, 그리고 **모든 plugin README "Principles
  Instantiated"의 `P#`/`AP#` 인용**을 rewrite 후 상태로 갱신(삭제 아님 — 생존 개념으로 re-point,
  instantiation 사실 보존). 알려진 실측: spec-distill/README가 STRIP 대상 AP4/AP14/AP17 및 TRIM
  AP1/AP2/AP9/AP16/P5/P14를 인용, quality-gates/README가 P14/P18/P21/AP16/P8을 인용 — §11.1
  마이그레이션 테이블 경유 resolve분 포함. project-init/README는 `P#`/`AP#` 무인용(name-only prose +
  생존 file-link)이라 정합 pass는 대개 no-op — 접촉 시에만 편집·bump(AC17). **기존 오류 수정**: spec-distill/README의 trivia를 AP4로
  오라벨(정확히는 AP5)한 pre-existing 오타를 이 정합 pass에서 교정. CLAUDE.md의 "24개 원칙·14개
  anti-pattern" 문구도 새 프레이밍(KEEP-12 구조 메커니즘)으로 정정.
- **TOC**: essence doc이 <300줄이면 `## 목차` 면제(Doc Conventions).

### 5.2 WS2 — history 아카이브 + 삭제 (OQ2)

**입력**: 현재 HEAD(활성 slimming 산출물 커밋 이후). **출력**: 태그 + 경량화된 working-tree.

- `git tag -a pre-slim-archive-2026-07-09 -m "<메시지>"` — 삭제 전 봉인. **plan 커밋 시점 명시**:
  writing-plans 산출 plan은 이 태그 컷 *이후* 활성 산출물로 커밋되며(§6 PR0 확장) 삭제 대상 제외.
- working-tree 삭제 — **활성 카브아웃 명시**(specs/·plans/·interview/ 모두 "기존분만"):
  - `docs/superpowers/plans/` — **기존분만**(writing-plans가 만들 활성 slimming plan은 제외).
  - `docs/superpowers/specs/` — **기존 52파일만**(활성 2026-07-09 design 제외).
  - `docs/superpowers/interview/` — **stale brief 4개**(qg-scope-capture·qg-llm-security-gap·
    project-init-git-strategy·qg-pr-publish)만; 활성 2026-07-08 slimming brief **제외**.
  - `docs/superpowers/handoffs/`·`docs/superpowers/verification-logs/`·`docs/research/` +
    `docs/qg-defending-code-harness-gap-assessment.md` — 전량.
- 삭제는 wholesale glob 금지 — 활성 3산출물 제외 목록을 명시적으로 유지(AC9). 삭제 전 `git status`
  clean 확인(C-GIT-RECOVER). 복구: `git checkout <tag> -- <path>`.

### 5.3 WS3 — agent strip [DESCOPED → 별도 spec]

**2026-07-09 사용자 결정: 이 effort 범위 밖**(NG7). 리뷰가 밝힌 근거: `pr-understanding-builder`
agent 자체는 zero-tool 편의(strip 가능, LD9 부합)이나, 그것이 서비스하는 qg-publish 기능은 구조적
보안 plumbing(secret-scan fail-closed, `comment.user.id`+anchored-marker 2자물쇠 idempotent upsert,
gh-identity isolation, codex model-diversity가 v2.8–2.10에 잡은 학습을 담은 hardened P21 persona)을
포함한다. 이는 (a) 며칠 전 병합된 #94/#95 revert, (b) docs-slimming과 직교, (c) major bump + Law 2
리뷰 + full /qg + CHANGELOG **Removed** + **one-minor deprecation window**(P23/CLAUDE house rule)를
요구하는 다른 rigor 등급, (d) ~16개 publish/PR test 제거 + setup-qg.sh global-kill sentinel·gate-cell
surgical edit를 수반한다.

→ 별도 `docs/superpowers/specs/<날짜>-qg-publish-strip-design.md`로 자체 brainstorming→spec→review
→/qg 사이클에서 처리. 이 effort는 pr-understanding-builder를 건드리지 않는다.

### 5.4 WS4 — 런타임 컨텍스트 트림 (OQ5 / target C)

**입력**: CLAUDE.md·plugin.json description·SKILL.md description·MEMORY.md. **출력**: 포인터화된
CLAUDE.md + 압축 description + (별도) 아카이브된 MEMORY.

- **CLAUDE.md**: 'Building a New Plugin' starter tree + 2개 reference-impl 워크스루를
  `docs/plugin-authoring.md`로 이관, 본문엔 한 줄 포인터. Three Laws·Plugin Shape·Forbidden
  Patterns·Git Workflow·Doc Conventions 핵심은 존치. (기제 선택 근거는 §10 참조.)
- **plugin.json description**: project-init ~90단어 → 1문장(→ project-init patch bump).
- **SKILL.md description**: quality-pipeline·conducting-interview의 verbose trigger-phrase 문단
  압축(→ 해당 plugin patch bump). **트리거 회귀 방지(AC13)**: `/qg`·`/interview`는 command이기도
  해서 command 호출은 압축된 skill description을 우회 — "command 동작 확인"은 NL-트리거 건강의
  false-positive 신호다. 따라서 skill-creator **trigger eval**로 *드롭된 특정 NL 문구*(예:
  quality-pipeline의 'run quality gates'·'verify my implementation'·'check code quality'·'is my
  PR ready to merge')에 대한 매칭 유지를 결정론적으로 검증한다.
- **MEMORY.md**(NG5, repo 밖): 종료-MERGED 프로젝트 로그(spec-distill v0.11–0.19, qg v2.1–2.10)를
  링크 아카이브 파일로 이동, always-on 인덱스엔 활성 `feedback_*` + 최신-state만. 메모리 도구 액션
  (repo AC 스코프 밖, AC14).

### 5.5 WS5 — project-init sandbox-verify (OQ4 / LD3)

**입력**: slimmed baseline(WS1·WS2·WS4 완료 후). **출력**: 재유입-방지 diff 리포트(임시). 실제 repo
CLAUDE.md 구조 **불변**.

- **project-init S2 사실(리뷰가 밝힘)**: devbrew는 현재 full-content CLAUDE.md + AGENTS.md 부재 =
  project-init의 `S2(CLAUDE-only)` 상태. 실제 재실행은 결정론적으로 둘 중 하나: migration 거절 →
  **전체 run abort**(스캐폴딩 0 재생성); 승인 → **S2a** — CLAUDE.md 본문 전체를 새 AGENTS.md(canonical)로
  이전 + CLAUDE.md를 `@AGENTS.md` 한 줄 포인터로 교체(**AGENTS-primary flip**, Korean-primary
  CLAUDE-primary Doc Conventions와 충돌). 어느 쪽도 "스캐폴딩만 재생성 + CLAUDE.md-primary 유지"와
  양립하지 않는다.
- **결정(2026-07-09 사용자): sandbox-verify만**. 실제 repo의 S2 migration을 **트리거하지 않는다**.
  slimmed baseline의 throwaway 사본(별도 디렉토리/`$CLAUDE_JOB_DIR/tmp` 등)에서 project-init을 돌려
  재생성물을 slimmed CLAUDE.md/philosophy와 **diff-대조**(재유입-방지 리포트)만 산출하고, 실제 repo의
  CLAUDE.md-primary 구조는 불변. AGENTS.md 생성 없음.
- **재유입 방지**: sandbox 재생성물에 stripped 내용(카탈로그 재진술·인용 apparatus)이 재도입되지
  않았는지 확인. 손-큐레이션된 Three Laws/Forbidden Patterns는 이 effort의 어떤 단계도 덮어쓰지 않음.

## 6. PR 분해 & 프로세스 rigor (OQ6)

GitHub Flow, PR 단위 merge-back(rebase 금지 — merge). rigor를 **리스크 등급**에 맞춤:

| PR | 워크스트림 | 접촉 | rigor |
|---|---|---|---|
| **PR0** | 이 design doc + interview brief (+ writing-plans 후 plan) 커밋 | docs-only | 이 브랜치. Law 2 분리 리뷰(진행). plan은 태그 컷 이후 활성 산출물 |
| **PR1** | WS1 철학 rewrite + roadmap + `../reference` 제거 + cross-ref 정합(multi-plugin README) | docs + CLAUDE.md + 3 plugin README | 가드레일 레이어(P21 인접) → **분리 리뷰 패스** + AC5 결정론 dangling-ref 스크립트(body-unique) backstop. README 접촉 plugin별 **patch bump** |
| **PR2** | WS2 history 태그 + 삭제 | docs-only, 기계적 | 경량 — 활성-카브아웃 삭제 목록 + 태그 복구 확인 |
| **PR3** | WS4 CLAUDE.md 포인터화 + description 압축 | CLAUDE.md + docs/plugin-authoring.md + 접촉 plugin | 접촉 plugin별 **patch bump** + description은 **trigger eval**(AC13). CLAUDE.md-only 부분은 경량 리뷰 |
| **PR4** | WS5 project-init sandbox-verify | (임시 리포트만; 실제 repo 파일 무변경) | sandbox diff 리포트 검증 |

- **rigor 원칙(P8 적용)**: 결정론 게이트(bump·/qg·codex·Law 2 full 리뷰)는 *실제 persona/게이트를
  건드리는* 변경에만. 순수 docs 감량(PR1·PR2)엔 분리 리뷰 + AC5 결정론 dangling 스크립트는 두되
  /qg·codex·plugin 게이트는 부과하지 않음 — 감량 프로세스 자체에 "결정론은 load-bearing에만"(P8·LD8·
  feedback_harness_lightness_trust_model) 적용. (PR1은 STRIP에 Law-2/Forbidden-Pattern 앵커를 포함하지
  않고 — AP3·P3=KEEP-12 — AC5 스크립트가 dropped 앵커를 fail-closed로 잡는다.)
- **브랜치 토폴로지(stacked-base-deletion hazard 회피)**: PR1–PR4는 **각각 main에서 순차 분기**
  (직전 PR merge 후 main 갱신 → 다음 PR 분기). stacked(미병합 브랜치 위 분기) 금지 —
  feedback_stacked_pr_base_deletion(base 삭제 시 dependent CLOSED, 복구 불가). 순서 제약: cross-ref
  정합상 PR1 먼저, PR4(sandbox-verify)는 WS1·WS2·WS4 병합 후.
- **구현 = 울트라코드**: 각 PR을 Workflow 오케스트레이션으로 구현(subagent-driven task 분해 + Law 2
  분리 리뷰). writing-plans가 PR별 task/AC/검증을 상세화.
- **MEMORY 아카이브**(WS4 일부, NG5): repo PR 밖 메모리 도구 액션 — PR 시퀀스와 병렬.

## 7. Acceptance Criteria

**WS1 (철학 rewrite)**
- **AC1**: 슬림된 philosophy doc에 KEEP-12(P2·P3·P4·P10·P11·P12·P13·P17·P18·P21·P22·AP3)가 전부
  존재하고, 각 엔트리가 ≥1개 코드 cross-ref(`path` 또는 `path:line`)를 포함한다.
- **AC2**: STRIP-standalone(P16·AP4·AP7·AP8·AP14)의 헤더+본문이 부재하고, **STRIP-redirect
  (AP10·AP11·AP17)의 redirect prose가 KEEP/TRIM 본문·§11.1 테이블에서 제거**됨 — header 부재가
  아니라 body-unique 문구로 검증(vacuous-pass 방지).
- **AC3**: P8 determinism-economy가 philosophy essence 또는 CLAUDE.md에 **두 방향 모두**(불필요한
  결정론 제거 AND load-bearing 지점에 정확히 부과) semantic하게 생존 — 단순 'determinism' 토큰 grep이
  아니라 두 방향 문장 존재를 확인.
- **AC4**: Appendix A(Direct Quotes)·§6 Attribution Map·absorbed-source 인벤토리·`../reference`
  포인터가 부재(grep 0건).
- **AC5 (load-bearing)**: CLAUDE.md·**3 plugin README**·philosophy 내 모든 `P#`/`AP#`/철학 `§X.Y`/
  파일-링크 cross-ref가 resolve — dangling 0건. 제거/개명 원칙 인용은 삭제가 아니라 생존 개념으로
  re-point(Law-3 substrate 보존). P14 compaction-survival 규칙은 README 3곳 인용 backstop으로 생존
  강제. body-unique 앵커로 검증(header-satisfiable 함정 회피).
- **AC6**: CLAUDE.md의 "24개 원칙·14개 anti-pattern" 문구가 새 프레이밍으로 정정 — §9 before/after
  grep으로 검증.

**WS2 (history)**
- **AC7**: `pre-slim-archive-2026-07-09` annotated 태그 존재 + `git cat-file -e <tag>:<임의 삭제
  경로>` 성공(plans/·specs/ 기존파일 표본).
- **AC8**: working-tree에서 plans/(기존분)·specs 기존 52·interview stale 4·handoffs/·
  verification-logs/·research/ + gap-assessment doc이 삭제됨.
- **AC9**: 활성 slimming 산출물(design doc·writing-plans plan·활성 2026-07-08 interview brief)은
  working-tree에 **잔존**(3산출물 전부).
- **AC10**: 삭제 커밋 직전 `git status`가 clean이었고 uncommitted 손실 0.

**WS4 (런타임 트림)**
- **AC11**: CLAUDE.md의 'Building a New Plugin' starter tree + reference-impl 워크스루가
  `docs/plugin-authoring.md`로 이관되고 본문엔 한 줄 포인터만; 이관 내용이 대상 파일에 존재.
- **AC12**: project-init plugin.json description이 1문장으로 압축 + patch bump.
- **AC13**: 압축된 SKILL.md description이 **skill-creator trigger eval에서 드롭된 특정 NL 문구의
  매칭을 유지**(command 우회 아닌 결정론 트리거 검증); 접촉 plugin patch bump.
- **AC14**: MEMORY.md 아카이브(NG5, repo-external) — always-on 인덱스에 종료-MERGED 로그 부재 +
  아카이브 파일에 존재. repo AC 스코프 밖(메모리 도구/수동 확인).

**WS5 (project-init sandbox-verify)**
- **AC15**: sandbox 재생성물 diff 리포트가 stripped 내용(카탈로그 재진술·인용 apparatus) 재유입
  0건을 확인 + 실제 repo의 CLAUDE.md/AGENTS 구조 **무변경**(AGENTS.md 미생성).
- **AC16**: 손-큐레이션 Three Laws/Forbidden Patterns가 어떤 단계도 덮어쓰지 않음.

**프로세스**
- **AC17**: PR1(README 접촉)·PR3(description 접촉)이 접촉 plugin별 SemVer patch bump 포함(cache
  key stale 방지).
- **AC18**: 이 설계 doc이 Law 2 분리 reviewer(spec-reviewer + 독립 adversarial)의 검증을 통과한
  뒤 writing-plans로 진행(self-approval 금지, NG6).

## 8. Files to Modify

**WS1**: `docs/philosophy/devbrew-harness-philosophy.md`(rewrite) · `docs/philosophy/*roadmap*.md`
(트림/제거) · `CLAUDE.md`(cross-ref·문구 정정, `../reference` 포인터 제거) ·
`plugins/spec-distill/README.md` · `plugins/quality-gates/README.md` · `plugins/project-init/README.md`
(Principles Instantiated cross-ref 정합 — mandatory, AP4/AP5 오라벨 교정 포함).
**WS2**: 삭제 — `docs/superpowers/plans/`(기존분) · `docs/superpowers/specs/`(기존 52) ·
`docs/superpowers/interview/`(stale 4) · `docs/superpowers/handoffs/` ·
`docs/superpowers/verification-logs/` · `docs/research/` ·
`docs/qg-defending-code-harness-gap-assessment.md`. 생성 — annotated 태그(파일 아님).
**WS4**: `CLAUDE.md`(포인터화) · 신규 `docs/plugin-authoring.md` ·
`plugins/project-init/.claude-plugin/plugin.json`(description) · 접촉
`plugins/*/skills/*/SKILL.md`(description) + 대응 plugin.json patch bump. (별도)
`~/.claude/projects/.../memory/MEMORY.md` + 아카이브 파일 — 메모리 도구.
**WS5**: sandbox 재생성물(throwaway) + diff 리포트(임시) — 실제 repo 파일 무변경.
**WS3**: (없음 — descoped, 별도 spec, NG7.)

## 9. Verification Plan

- **AC1/AC4**: philosophy grep — KEEP-12 각 `P#`/`AP3` 헤더 + 각 근처 코드 cross-ref 패턴 존재;
  `Appendix A`·`Attribution`·`../reference` 문자열 0건.
- **AC2**: STRIP-standalone(P16·AP4·AP7·AP8·AP14) 헤더 부재 **AND** STRIP-redirect(AP10·AP11·AP17)의
  body-unique redirect 문구가 KEEP/TRIM 본문·§11.1 테이블에서 제거됐는지 문구 grep(header 부재만으로는
  불충분 — vacuous 방지).
- **AC3**: P8 두 방향 문장(예: "결정론을 덜어내는" + "load-bearing … 정확히 거는")이 philosophy
  essence 또는 CLAUDE.md에 모두 grep hit — 토큰 단독 grep 금지.
- **AC5 (load-bearing)**: 스크립트로 CLAUDE.md·3 plugin README·philosophy에서 인용된 모든 `P\d+`/
  `AP\d+`/철학 `§[\d.]+` 토큰 추출 → slimmed philosophy 대응 앵커 대조 → dangling 리스트 empty.
  body-unique 앵커로 검증. re-point된 README 줄이 instantiation 사실을 보존하는지 육안 확인.
  P14 규칙 문장이 essence에 생존하는지 확인(README 3 인용의 anchor target).
- **AC6**: CLAUDE.md before/after grep — 옛 "24개 원칙·14개 anti-pattern" 문구 부재 + 새 프레이밍 존재.
- **AC7/AC10**: `git tag -l pre-slim-archive-2026-07-09` + `git cat-file -e <tag>:<path>` 성공 +
  삭제 커밋 직전 `git status --porcelain` empty(커밋 로그 확인).
- **AC8/AC9**: 삭제 후 활성 3산출물 경로 존재 확인(`test -f`) + 삭제 대상 표본 부재 확인.
- **AC11**: `docs/plugin-authoring.md` 존재 + starter tree 문자열이 CLAUDE.md 부재·신규 파일 존재.
- **AC13**: skill-creator trigger eval 실행 → 드롭된 NL 문구가 여전히 대상 skill로 매칭(결정론).
- **AC15/AC16**: sandbox 재생성 전/후 diff → stripped 문자열 재유입 grep 0건 + 실제 repo CLAUDE.md/
  AGENTS 구조 무변경(AGENTS.md 부재 확인) + 핵심 규칙 본문 무변경.
- **전 PR**: 접촉 plugin 테스트 스위트 green(spec-distill `-m unittest`, project-init hook tests,
  qg guard — WS3 미접촉이므로 publish test 회귀 없음) + plugin.json bump 확인.

## 10. Rejected Alternatives

- **Approach A (보수적 in-place 트림)** — STRIP + 표면 인용만 제거, TRIM은 문단 유지, 전 agent 보존.
  기각 근거(리스크 비대칭 명시): §1 reframe이 인정하듯 이득은 토큰/세션이 아니라 signal-to-noise·
  discoverability이고, A는 STRIP + 인용-apparatus 제거로 S/N 이득의 상당분을 **더 낮은 리스크로**
  포착한다. 그럼에도 B를 택하는 이유는 B의 delta(938줄 doc의 "카탈로그→코드 지도" full rewrite +
  cross-ref 재해소)가 LD4가 요구하는 **정체성 전환**("프로젝트를 특별하게 만드는 것만 남긴다" =
  구조 메커니즘→코드 지도)을 실현하는 load-bearing 작업이기 때문 — A는 카탈로그 형식을 유지해 "특별함
  만 남긴다"에 미달(LD4). 리스크는 C-NO-DANGLING(AC5 결정론 스크립트) + PR1 분리 리뷰로 상쇄. (사용자
  2026-07-09 B 확정; 이 근거는 그 delta가 왜 load-bearing인지를 명문화.)
- **Approach C (최대 — 철학을 CLAUDE.md로 흡수·doc 삭제)** — 기각(실측 근거): README "Principles
  Instantiated"의 `P#` cross-ref(P21×6·P18×6·P17×4 등)와 CLAUDE.md 링크가 전부 깨져 Law 3 compounding
  substrate 손실; convenience agent 전부 strip은 인터뷰 R3/breadth Law-1 조력 저하(NG4).
- **history: 태그 없이 그냥 삭제** — 기각: git 복구는 가능하나 archaeology friction; annotated 태그가
  명명된 zero-cost 복구 지점 제공.
- **history: 별도 저장소로 이동** — 기각: in-repo git-log 연속성 단절.
- **history: orphan 아카이브 브랜치** — 기각(태그 대비): branch 목록 영구 잔존(소음).
- **WS4 CLAUDE.md 포인터화 vs in-place 트림 vs 완전 삭제** — 이관(→docs/plugin-authoring.md 포인터)
  채택 근거: in-place 트림은 always-on 컨텍스트를 못 줄이고(내용 잔존), 완전 삭제는 Law-3 discoverability
  위반(미래 agent가 스캐폴딩 방법을 못 찾음). 이관+포인터가 always-on 절감과 discoverability를 동시
  충족 — 저자용 참조를 필요 시점에만 로드.
- **WS3 pr-understanding-builder strip을 이 effort에 포함/inline화** — 기각(2026-07-09 사용자):
  별도 spec으로 carve-out(NG7·§5.3) — 보안-기능 revert를 docs-slimming과 뒤섞지 않음.

## 11. Metadata

- **버전 영향**: project-init **patch**(WS4 description) · description/README 접촉 plugin별 **patch**
  (WS4·WS1). qg major bump 없음(WS3 descoped). 각 bump는 같은 PR에서(cache key stale 방지, AC17).
- **PR 순서/브랜치**: PR0(design+plan) → PR1(철학) → PR2(history) → PR3(runtime) → PR4(project-init
  sandbox). 각 PR은 **main에서 순차 분기**(stacked 금지, feedback_stacked_pr_base_deletion). PR1
  먼저(cross-ref), PR4 마지막(WS1·2·4 병합 후).
- **머지 정책**: merge commit(rebase 금지 — feedback_git_merge_over_rebase).
- **구현**: 울트라코드(Workflow) — PR별 subagent-driven 구현 + Law 2 분리 리뷰.
- **Carve-out**: WS3(pr-understanding-builder/publish strip)는 별도 spec(NG7).
- **다음 단계**: 이 doc Law 2 리뷰 통과 → 사용자 리뷰 게이트 → `superpowers:writing-plans`.

## Handoff Context

**TL;DR** — devbrew를 구조적 핵심으로 환원하는 감량. Approach B(lean rewrite). 4개 워크스트림:
WS1 철학 doc rewrite(KEEP-12만, 코드 cross-ref) / WS2 history ~80k줄 태그 봉인+삭제 / WS4 런타임
컨텍스트 트림(CLAUDE.md 포인터화·description 압축) / WS5 project-init sandbox-verify. agent strip
(pr-understanding-builder/publish)은 별도 spec으로 carve-out. 울트라코드 구현.

**Implicit context (대화에만 있던 것 — /compact 후 세션이 알아야 할 근거)**:
- 근거 맵은 4-mapper understand 워크플로우 산출(philosophy KEEP-12/STRIP/TRIM 분류=Appendix A,
  always-on 컨텍스트 ~145줄, history ~80k, agent 인벤토리). 추정 아님, 실측.
- Law 2 리뷰 1라운드: canonical spec-reviewer=needs_revise + 3 adversarial 렌즈가 HIGH 5건 제기 →
  독립 반증(refute) 결과 4건 false positive(AC11-grep·TRIM21-미결의혹·P14-strip·PR1-rigor는 설계 AC가
  이미 처리), 1건 HELD(WS5 project-init S2). 이 개정이 그 반영 + canonical CRITICAL(Handoff 부재) +
  실질 MEDIUM/LOW.
- 두 scope 결정은 사용자(2026-07-09): WS3 carve-out, WS5 sandbox-verify.
- S/N reframe: always-on 컨텍스트는 작음 — 철학/history 감량 이득은 signal-to-noise·discoverability
  (토큰/세션 아님).
- project-init S2 사실: devbrew=CLAUDE-only(AGENTS.md 부재) → 실제 재실행은 abort 또는 AGENTS-primary
  flip. sandbox-verify로 회피(실제 repo 불변).
- LD8 경계는 hard: 구조 게이트(Law 2 tool-deny·결정론 fail-closed·spec 5-ritual·/qg) strip 금지.

**Deferred to plan (writing-plans가 결정)**: TRIM 원칙별 collapse-vs-fold(Appendix A CLAUDE.md-중복
맵 기준, 기본=one-liner, P8·P14 필수 생존) · 정확한 grep/삭제 경로 · PR별 task 분해 · sandbox 실행
기제 · AC5 dangling 스크립트 구현 · trigger-eval 대상 문구 목록.

## Appendix A — 철학 doc keep/trim/strip 분류 (ground truth)

understand 워크플로우 map:philosophy 산출 + 리뷰 반증(header-satisfiable 함정) 반영. writing-plans/
rewrite의 기준.

**KEEP-12 (구조적 load-bearing, devbrew-고유)**

| id | title | 이유 |
|---|---|---|
| P2 | The Ambiguity Gate | required-section·visible/declared/refusable spec 게이트 — Law 1 정본 |
| P3 | Writer/Reviewer Isolation via Tool Scoping | 물리 allowedTools/disallowedTools 분리 — Law 2 정의 메커니즘 |
| P4 | Verification Is Infrastructure | 3-tier verification, runtime 게이트 evidence 산출(qg Runtime) |
| P10 | Taste Pluralism | persona 라이브러리 + bug-escape→persona 편집(Law 2×Law 3) |
| P11 | Cross-Model Adversarial | codex model-diversity — fail-open 반복 적발 실증 |
| P12 | Transparency of Planning | trivia-escape 구조 예외 + ExitPlanMode 게이트 |
| P13 | Hooks for Enforcement... | hook 공존 계약(namespace·commutativity·Stop idempotency·kill switch) |
| P17 | User Sovereignty | AskUserQuestion/ExitPlanMode approval 게이트 |
| P18 | Stagnation Is a Failure Mode | circuit breaker(max-iter·repeat-detect·escape hatch) |
| P21 | Security & Supply Chain | persona=보안-민감·kill switch=보안 컨트롤·integrity-pin |
| P22 | Cost Awareness | cost_class + fan-out N≥5 hard 게이트 + high-cost approval |
| AP3 | Self-Approval | Law 2 정본 위반 — P3 tool-deny로 구조 집행(#1 load-bearing) |

**STRIP — 두 형태 구분(리뷰 반증 반영)**

- **STRIP-standalone** (실제 `### P##`/`### AP##` 헤더 존재 → 헤더+본문 제거):
  P16(미구현 벤치마크·§9 Q9 미해결) · AP4(LOC 지표·gstack anecdote) · AP7(vague names·CLAUDE.md
  중복) · AP8(tool-response pollution·generic) · AP14(unchallenged consensus·AP13/P11 재표현).
- **STRIP-redirect** (standalone 헤더 없이 KEEP/TRIM 본문·§11.1 마이그레이션 테이블에 흡수된 redirect
  prose로만 존재 → **redirect prose 제거**, header 부재 확인은 vacuous):
  AP10(→P5 흡수) · AP11(→P3 흡수) · AP17(→P14 흡수).

**TRIM (규칙 실재 but 중복/over-explained — CLAUDE.md 존치분은 엔트리 제거, 통찰/부재규칙은 one-liner)**

P1·P5·P6·P7·**P8**·P9·**P14**·P15·P19·P20·P23·P24 / AP1·AP2·AP5·AP6·AP9·AP12·AP13·AP15·AP16.
- **P8**(determinism-economy) = devbrew-original 통찰 → 두 방향 모두 생존(AC3).
- **P14**(compaction-survival) = CLAUDE.md **부재** 규칙 → philosophy essence에 문장 생존(AC5,
  README 3 인용 backstop). "CLAUDE.md에 이미 있음" 가정 금지 — 없음.

**외부 apparatus(LD7 strip)**: Appendix A(876–938, ~100% verbatim quote) · §6 Attribution
Map(689–737) · §0 Thesis quote 4개 · §5 tension quote 다수 · absorbed-source 인벤토리(54–61) ·
`../reference` 포인터(CLAUDE.md:8).

**CLAUDE.md 중복(TRIM 엔트리-제거 후보 — 단 KEEP-12은 전체 존치, 인용분은 stub 앵커 §5.1)**: §1
Three Laws · §2.2 P3(KEEP-12) · §2.4 P6/P13(KEEP-12)/P19/P21(KEEP-12)/P22(KEEP-12)/P23 · §2.3 P5 ·
§3 anti-corollaries(AP3=KEEP-12 존치; AP2/AP5/AP9/AP16=인용→stub) · P12(KEEP-12)/AP5 trivia · §4.0
디렉토리 구조(CLAUDE.md:31 인용→stub). (주의: (i) 위 KEEP-12(P3·P13·P21·P22·P12·AP3)는 중복이어도
**전체 엔트리 존치** — 중복은 CLAUDE.md 쪽 documentation일 뿐. (ii) P14 compaction-survival은
CLAUDE.md에 **없음** — 중복 목록 포함 금지.)
