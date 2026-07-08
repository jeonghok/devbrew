---
name: devbrew-context-slimming
type: design-doc
created_at: 2026-07-09
status: draft
approach: "B — lean rewrite"
source_interview: docs/superpowers/interview/2026-07-08-devbrew-context-slimming-interview.md
locked_directions: "LD1–LD9 (interview brief frontmatter — 재논쟁 금지)"
history_disposition: "annotated tag (pre-slim-archive-2026-07-09) 후 working-tree 삭제"
implementation: "ultracode (Workflow orchestration)"
---

# devbrew Context Slimming — Design (Approach B: Lean Rewrite)

> **구조적 핵심으로 환원한다.** "특별함 = 구조적 load-bearing"만 남기고, 현대 모델+하네스가
> 기본 수행하거나 코드·generic best-practice가 커버하는 재진술·역사 축적·외부 인용 장치를 걷어낸다.
> 보안/정확성 집행 계층은 category error를 피해 **불변으로 보존**한다(LD8).

이 설계는 `2026-07-08-devbrew-context-slimming-interview.md` brief를 해답공간으로 이어받은
산출물이다. 실측 맵(4-mapper understand 워크플로우)으로 OQ1/OQ2/OQ3/OQ5를 해소했고, OQ4/OQ6는
아래 §6·§7에서 확정한다.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints (LD8 보존 경계)](#4-constraints-ld8-보존-경계)
- [5. Workstreams (아키텍처)](#5-workstreams-아키텍처)
  - [5.1 WS1 — 철학 doc lean rewrite (OQ1)](#51-ws1--철학-doc-lean-rewrite-oq1)
  - [5.2 WS2 — history 아카이브 + 삭제 (OQ2)](#52-ws2--history-아카이브--삭제-oq2)
  - [5.3 WS3 — agent strip (OQ3)](#53-ws3--agent-strip-oq3)
  - [5.4 WS4 — 런타임 컨텍스트 트림 (OQ5)](#54-ws4--런타임-컨텍스트-트림-oq5)
  - [5.5 WS5 — project-init 재실행 (OQ4)](#55-ws5--project-init-재실행-oq4)
- [6. PR 분해 & 프로세스 rigor (OQ6)](#6-pr-분해--프로세스-rigor-oq6)
- [7. Acceptance Criteria](#7-acceptance-criteria)
- [8. Files to Modify](#8-files-to-modify)
- [9. Verification Plan](#9-verification-plan)
- [10. Rejected Alternatives](#10-rejected-alternatives)
- [11. Metadata](#11-metadata)
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

감량 후 project-init을 재실행해 스캐폴딩을 lean baseline에서 재생성한다(LD3).

## 2. Goals

- **G1**: 철학 doc을 "24개 원칙 카탈로그"에서 "구조 메커니즘 → 코드 지도"로 재작성 — KEEP-12
  구조 원칙만 존치, 각각 코드 cross-ref로 뒷받침(prose 재진술 대체). `P#` 앵커 보존.
- **G2**: 외부 인용 apparatus(Appendix A·Attribution Map·quote 블록)와 `../reference` 포인터
  제거 → doc self-contained·경량화(LD7).
- **G3**: ~80k줄 역사 docs를 annotated tag로 봉인 후 working-tree에서 삭제 → repo 경량화, git
  복구성 유지(OQ2).
- **G4**: non-gating convenience agent(pr-understanding-builder)를 strip — load-bearing
  게이트/보안-critical/model-diversity가 아닌 편의 스캐폴딩 제거(OQ3, LD9).
- **G5**: always-on 컨텍스트(CLAUDE.md 저술 섹션·verbose description)를 포인터화·압축(OQ5, target C).
- **G6**: project-init 재실행으로 스캐폴딩 재생성 + slimmed baseline과 대조(LD3, OQ4).
- **G7**: 감량 과정 자체를 devbrew 자기 규율(spec→review→compound)로 진행하되 rigor를 리스크
  등급에 맞춤(OQ6) — plugin/persona 접촉 변경엔 full 게이트, 순수 docs 변경엔 경량.

## 3. Non-goals

- **NG1**: 구조적 보안/정확성 게이트 strip 금지 — KEEP-12, KEEP-6 agent + codex, Law 2 tool-deny,
  결정론 fail-closed 셸 게이트, spec 5-ritual(`check_brief.py`), `/qg` 게이트는 대상 아님(LD8).
- **NG2**: plugin CHANGELOG(`plugins/*/CHANGELOG.md`) 정리는 범위 밖 — 버전 이력은 load-bearing.
- **NG3**: `docs/git-workflow/`(241줄), `docs/philosophy/` 자체 삭제는 아님 — git-workflow는
  load-bearing 가이드, 철학 doc은 삭제가 아니라 rewrite(파일 존치, `P#` 앵커 유지).
- **NG4**: 인터뷰 조력 agent(steelman-builder·breadth-keeper) strip 금지 — steelman은 R3
  Skepticism 게이트를 채우는 Law 1 조력, breadth는 tunneling 방지(B 확정, C안 기각).
- **NG5**: MEMORY.md 아카이브는 repo PR이 *아니라* 사용자 메모리 도구 액션(repo 밖 경로) — 설계엔
  포함하되 구현 시퀀스에서 별도 취급.
- **NG6**: 이번 감량 self-approval 금지 — 설계 doc은 Law 2 분리 reviewer(spec-reviewer + 독립
  adversarial 렌즈)가 검증하고, 최종 승인은 사용자.

## 4. Constraints (LD8 보존 경계)

"strip은 prose/docs/refs/history/런타임컨텍스트 한정, 구조 게이트는 보존." 구체 불변식:

- **C-KEEP-PRINCIPLES**: 철학 KEEP-12(P2·P3·P4·P10·P11·P12·P13·P17·P18·P21·P22 + AP3)는 존치.
  더해 **P8 determinism-economy 통찰**("결정론 가드는 load-bearing에만")은 이 감량 자체를 정당화하는
  devbrew-original 메타룰이므로 essence doc 또는 CLAUDE.md에 반드시 생존(AC로 강제).
- **C-KEEP-AGENTS**: security-reviewer·adversarial·runtime-verifier·test-scope-validator·
  spec-reviewer + codex 스크립트 경로는 존치(전부 정확성/보안 게이트 또는 model-diversity).
- **C-LAW2**: 7개 reviewer agent의 `Write`/`Edit` deny frontmatter 불변. runtime-verifier의
  scoped `Write`(R6 예외)는 orchestrator git-diff mutation guard로 분리 — 이 구조 불변.
- **C-DETERMINISM**: 결정론 fail-closed 셸 게이트(`check-review-scope.sh`, `check_brief.py`,
  qg 게이트 스크립트)와 kill switch 존중은 불변.
- **C-NO-DANGLING**: 모든 cross-ref(`P#`·`AP#`·`§X.Y`·파일 링크)는 rewrite 후 resolve하거나
  같은 커밋에서 갱신 — dangling 참조 금지(리뷰 게이트 강제).
- **C-GIT-RECOVER**: history 삭제 전 annotated tag로 봉인 + `git status` clean 확인 —
  uncommitted 손실 0.

## 5. Workstreams (아키텍처)

각 워크스트림은 독립 unit — 명확한 입력/출력/검증을 가지며 개별 PR로 격리된다(§6).

### 5.1 WS1 — 철학 doc lean rewrite (OQ1)

**입력**: `docs/philosophy/devbrew-harness-philosophy.md`(938) + `docs/philosophy/*roadmap*.md`(367)
+ Appendix A 분류(§Appendix A).
**출력**: ~200줄 essence doc + 트림된 roadmap(또는 제거) + 갱신된 cross-ref.

- **KEEP-12를 full 엔트리로**: 각 엔트리 = {메커니즘 이름, instantiate하는 Law, 코드 cross-ref
  (`path` 또는 `path:line`), 한 줄 "왜 load-bearing"}. prose 재진술 금지 — 코드를 가리킨다.
- **STRIP-8 제거**: P16(미구현 벤치마크)·AP4·AP7·AP8·AP10·AP11·AP14·AP17(§Appendix A 참조).
- **TRIM-21 처리**: 규칙이 CLAUDE.md에 이미 full로 있는 것은 philosophy 엔트리 제거(규칙은
  CLAUDE.md 존치), devbrew-original 통찰을 담은 것(특히 **P8 determinism-economy**)은 tight
  one-liner로 생존. 판정 세부는 writing-plans가 Appendix A 기준으로 확정.
- **외부 apparatus 제거**(LD7·G2): Appendix A(876–938)·§6 Attribution Map(689–737)·§0/§5 quote
  블록·absorbed-source 인벤토리·`../reference` 포인터.
- **roadmap doc**: 실제 near-term 계획만 존치, 미구현 aspirational/흡수 문단 삭제. 남는 실질
  로드맵이 없으면 doc 제거(+ cross-ref 갱신).
- **cross-ref 정합(C-NO-DANGLING)**: CLAUDE.md의 철학 §-anchor 인용(§1 Law 2 R6 note·§2.1·§4.8·
  §5.3·§2·§11.1 등)과 `P#`/`AP#` 인용, 그리고 모든 plugin README "Principles Instantiated"의
  `P#` 인용을 rewrite 후 상태로 갱신. CLAUDE.md의 "24개 원칙·14개 anti-pattern" 문구도 새 프레이밍
  (KEEP-12 구조 메커니즘)으로 정정.
- **TOC**: essence doc이 <300줄이면 `## 목차` 면제(Doc Conventions).

### 5.2 WS2 — history 아카이브 + 삭제 (OQ2)

**입력**: 현재 HEAD(활성 slimming 산출물 포함 커밋 이후). **출력**: 태그 + 경량화된 working-tree.

- `git tag -a pre-slim-archive-2026-07-09 -m "<메시지>"` — 삭제 전 봉인.
- working-tree 삭제: `docs/superpowers/plans/`(53)·`docs/superpowers/specs/`의 **기존 52파일**·
  `docs/superpowers/handoffs/`·`docs/superpowers/verification-logs/`·`docs/research/` +
  `docs/qg-defending-code-harness-gap-assessment.md`.
- **자기-삭제 방지(중요)**: 이번 slimming의 활성 산출물 — 이 design doc, 대응 plan, interview
  brief — 은 태그 시점 커밋에 이미 존재하므로 삭제 대상에서 **제외**한다. 삭제는 pre-existing
  역사분만 겨냥(glob이 활성 산출물을 포함하지 않도록 명시 경로/제외 목록). 병합 후 최종 패스에서
  이 3개도 아카이브 가능.
- 삭제 전 `git status` clean 확인(C-GIT-RECOVER). 복구: `git checkout <tag> -- <path>`.

### 5.3 WS3 — agent strip (OQ3)

**입력**: `plugins/quality-gates/agents/pr-understanding-builder.md` + qg-publish continuation
배선. **출력**: agent 제거 + 배선 제거 + qg 버전/CHANGELOG.

- 제거 대상: pr-understanding-builder agent(zero-filesystem PR-이해 산출물 저자, 정확성/보안
  게이트 아님) + 그것을 dispatch하는 publish continuation(SKILL/command/scripts의 offer·generate·
  publish 경로).
- **Blast radius(명시)**: 최근 병합된 opt-in PR-understanding-publish 기능(v2.9–2.10, #94/#95)을
  되돌린다. PR-이해 생성은 현대 모델이 inline 수행하는 커뮤니케이션 편의라 load-bearing 테스트에서
  strip 부합 — 되돌림 규모가 크므로 spec-review 게이트에서 재확인(사용자 carve-out 가능).
- persona 편집 = 보안-민감(P21) → qg **SemVer major bump**(shipped 기능 제거) + Law 2 리뷰 +
  `/qg` 파이프라인 + CHANGELOG `Removed` 엔트리.
- **경계**: 배선 제거가 나머지 `/qg` 게이트(Review·Runtime)를 건드리지 않음을 확인 — publish는
  파이프라인 *종료 후* offer라 게이트와 독립. 제거 후 `/qg` 정상 동작(AC로 강제).

### 5.4 WS4 — 런타임 컨텍스트 트림 (OQ5 / target C)

**입력**: CLAUDE.md·plugin.json description·SKILL.md description·MEMORY.md. **출력**: 포인터화된
CLAUDE.md + 압축 description + (별도) 아카이브된 MEMORY.

- **CLAUDE.md**: 'Building a New Plugin' starter tree + 2개 reference-impl 워크스루를
  `docs/plugin-authoring.md`로 이관, 본문엔 한 줄 포인터. Three Laws·Plugin Shape·Forbidden
  Patterns·Git Workflow·Doc Conventions 핵심은 존치.
- **plugin.json description**: project-init ~90단어 → 1문장(→ project-init patch bump).
- **SKILL.md description**: quality-pipeline·conducting-interview의 verbose trigger-phrase 문단
  압축(트리거 유효성 유지 — 과압축으로 skill 발동 실패 금지)(→ 해당 plugin patch bump).
- **MEMORY.md**(NG5, repo 밖): 종료-MERGED 프로젝트 로그(spec-distill v0.11–0.19, qg v2.1–2.10)를
  링크 아카이브 파일로 이동, always-on 인덱스엔 활성 `feedback_*` + 최신-state만. 메모리 도구 액션.

### 5.5 WS5 — project-init 재실행 (OQ4 / LD3)

**입력**: slimmed baseline(WS1–4 완료 후). **출력**: 재생성된 스캐폴딩 + 대조 리포트.

- project-init을 재실행해 git-workflow 가이드·charter·AGENTS/CLAUDE 포인터를 lean baseline에서
  재생성.
- **재유입 방지**: 재생성물을 slimmed CLAUDE.md/philosophy와 대조 — stripped 내용(카탈로그 재진술·
  인용 apparatus)이 재도입되지 않았는지 확인. 손-큐레이션된 Three Laws/Forbidden Patterns는
  덮어쓰지 않음(project-init은 스캐폴딩만 생성, 핵심 규칙은 보존).
- **범위 확정(OQ4)**: 재생성 = 템플릿/스캐폴딩 계층만. CLAUDE.md의 구조 규칙 본문은 WS1·WS4에서
  이미 확정된 것을 유지, project-init은 그 위에 포인터/워크플로우 파일만 재생성.

## 6. PR 분해 & 프로세스 rigor (OQ6)

GitHub Flow, PR 단위 merge-back(rebase 금지 — merge). rigor를 **리스크 등급**에 맞춤:

| PR | 워크스트림 | 접촉 | rigor |
|---|---|---|---|
| **PR0** | 이 design doc + interview brief 커밋 | docs-only | 이 브랜치. Law 2 분리 리뷰(이미 진행) |
| **PR1** | WS1 철학 rewrite + roadmap + `../reference` 제거 + cross-ref 정합 | docs + CLAUDE.md (+ 접촉 시 plugin README) | 가드레일 레이어(P21 인접) → **분리 리뷰 패스**. plugin README 접촉 시 해당 plugin **patch bump** |
| **PR2** | WS2 history 태그 + 삭제 | docs-only, 기계적 | 경량 — 삭제 목록 + 태그 복구 확인만 |
| **PR3** | WS3 agent strip + publish 배선 제거 | plugins/quality-gates | **major bump + Law 2 리뷰 + /qg 파이프라인 + CHANGELOG** |
| **PR4** | WS4 CLAUDE.md 포인터화 + description 압축 | CLAUDE.md + 접촉 plugin | 접촉 plugin별 **patch bump + /qg**. CLAUDE.md-only 부분은 경량 리뷰 |
| **PR5** | WS5 project-init 재실행 + 대조 | 스캐폴딩 파일 | 재생성 검증(대조 리포트) |

- **rigor 원칙(P8 적용)**: 결정론 게이트(bump·/qg·Law 2 리뷰)는 *실제 persona/게이트를 건드리는*
  PR3·PR4에만. 순수 docs 감량(PR1·PR2)엔 분리 리뷰는 두되 plugin 게이트는 부과하지 않음 — 감량
  프로세스 자체에 "결정론은 load-bearing에만" 원칙 적용.
- **구현 = 울트라코드**: 각 PR을 Workflow 오케스트레이션으로 구현(subagent-driven task 분해 +
  Law 2 분리 리뷰 + 필요 PR에 /qg). writing-plans가 PR별 task/AC/검증을 상세화.
- **MEMORY 아카이브**(WS4 일부, NG5): repo PR 밖 메모리 도구 액션 — PR 시퀀스와 병렬.

## 7. Acceptance Criteria

**WS1 (철학 rewrite)**
- **AC1**: 슬림된 philosophy doc에 KEEP-12(P2·P3·P4·P10·P11·P12·P13·P17·P18·P21·P22·AP3)가 전부
  존재하고, 각 엔트리가 ≥1개 코드 cross-ref(`path` 또는 `path:line`)를 포함한다.
- **AC2**: STRIP-8(P16·AP4·AP7·AP8·AP10·AP11·AP14·AP17)의 standalone 엔트리가 doc에 부재.
- **AC3**: P8 determinism-economy 통찰이 philosophy essence 또는 CLAUDE.md에 문장으로 생존.
- **AC4**: Appendix A(Direct Quotes)·§6 Attribution Map·absorbed-source 인벤토리·`../reference`
  포인터가 부재(grep으로 0건).
- **AC5**: CLAUDE.md·README·philosophy 내 모든 `P#`/`AP#`/철학 `§X.Y`/파일-링크 cross-ref가
  resolve한다 — dangling 0건(§9 검증).
- **AC6**: CLAUDE.md의 "24개 원칙·14개 anti-pattern" 문구가 새 프레이밍으로 정정됨.

**WS2 (history)**
- **AC7**: `pre-slim-archive-2026-07-09` annotated 태그가 존재하고, `git cat-file -e
  <tag>:docs/superpowers/plans/<임의파일>` 및 `...:docs/superpowers/specs/<임의 기존파일>`이 성공.
- **AC8**: working-tree에서 plans/·기존 specs 52파일·handoffs/·verification-logs/·research/ +
  gap-assessment doc이 삭제됨.
- **AC9**: 활성 slimming 산출물(이 design doc·plan·interview brief)은 working-tree에 **잔존**.
- **AC10**: 삭제 커밋 시점 `git status`가 clean이었고 uncommitted 손실 0.

**WS3 (agent strip)**
- **AC11**: `plugins/quality-gates/agents/pr-understanding-builder.md`가 부재하고, 그것을
  참조하던 SKILL/command/scripts 배선이 전부 제거됨(grep으로 dangling dispatch 0건).
- **AC12**: qg plugin.json이 major bump되고 CHANGELOG에 `Removed` 엔트리가 추가됨.
- **AC13**: strip 후 `/qg` 파이프라인(Review·Runtime 게이트)이 정상 동작하고 qg guard 테스트가
  green(회귀 0).

**WS4 (런타임 트림)**
- **AC14**: CLAUDE.md의 'Building a New Plugin' starter tree + reference-impl 워크스루가
  `docs/plugin-authoring.md`로 이관되고 본문엔 한 줄 포인터만 남음; 이관 내용이 대상 파일에 존재.
- **AC15**: project-init plugin.json description이 1문장으로 압축되고 patch bump됨.
- **AC16**: 압축된 SKILL.md description이 여전히 유효 트리거를 유지(skill 발동 회귀 0 — 수동 확인).

**WS5 (project-init 재실행)**
- **AC17**: project-init 재실행 후 스캐폴딩이 재생성되고, 대조 리포트가 stripped 내용(카탈로그
  재진술·인용 apparatus)의 재유입 0건을 확인.
- **AC18**: 손-큐레이션 Three Laws/Forbidden Patterns가 덮어쓰이지 않음.

**프로세스**
- **AC19**: PR3·PR4가 접촉 plugin별 SemVer bump를 포함(cache key stale 방지).
- **AC20**: 이 설계 doc이 Law 2 분리 reviewer(spec-reviewer + 독립 adversarial)의 검증을 통과한
  뒤 writing-plans로 진행(self-approval 금지, NG6).

## 8. Files to Modify

**WS1**: `docs/philosophy/devbrew-harness-philosophy.md`(rewrite) · `docs/philosophy/*roadmap*.md`
(트림/제거) · `CLAUDE.md`(cross-ref·문구 정정, `../reference` 포인터 제거) · 접촉 시
`plugins/*/README.md`(Principles Instantiated cross-ref).
**WS2**: 삭제 — `docs/superpowers/plans/` · `docs/superpowers/specs/`(기존 52) ·
`docs/superpowers/handoffs/` · `docs/superpowers/verification-logs/` · `docs/research/` ·
`docs/qg-defending-code-harness-gap-assessment.md`. 생성 — annotated 태그(파일 아님).
**WS3**: 삭제 — `plugins/quality-gates/agents/pr-understanding-builder.md` + publish continuation
배선(SKILL/command/scripts — 정확 경로는 writing-plans가 grep 확정). 수정 —
`plugins/quality-gates/.claude-plugin/plugin.json`(major bump) · `plugins/quality-gates/CHANGELOG.md`.
**WS4**: `CLAUDE.md`(포인터화) · 신규 `docs/plugin-authoring.md` · `plugins/project-init/.claude-plugin/plugin.json`
· 접촉 `plugins/*/skills/*/SKILL.md`(description) + 대응 plugin.json bump. (별도)
`~/.claude/projects/.../memory/MEMORY.md` + 아카이브 파일 — 메모리 도구.
**WS5**: project-init 재실행 산출물(스캐폴딩) + 대조 리포트(임시).

## 9. Verification Plan

- **AC1/AC2/AC4**: philosophy doc grep — KEEP-12 각 `P#`/`AP3` 헤더 존재 + 각 근처 코드 cross-ref
  패턴; STRIP-8 헤더 부재; `Appendix A`·`Attribution`·`../reference` 문자열 0건.
- **AC3**: `determinism` / `결정론` 통찰 문장이 philosophy 또는 CLAUDE.md에 grep hit.
- **AC5 (load-bearing)**: 스크립트로 CLAUDE.md·README·philosophy에서 인용된 모든 `P\d+`/`AP\d+`/
  철학 `§[\d.]+` 토큰을 추출 → slimmed philosophy에 대응 앵커 존재 여부 대조 → dangling 리스트가
  비어야 통과. 헤더-satisfiable 함정 회피 위해 body-unique 앵커로 검증.
- **AC7/AC10**: `git tag -l pre-slim-archive-2026-07-09` + `git cat-file -e <tag>:<path>` 성공 +
  삭제 커밋 직전 `git status --porcelain` empty였음을 커밋 로그로 확인.
- **AC11**: `grep -rn pr-understanding-builder plugins/` → 0건(agent 파일·배선 모두).
- **AC13**: `/qg` self-dogfood 1회(Review+Runtime) + qg guard 테스트 스위트 실행 → green.
- **AC14**: `docs/plugin-authoring.md` 존재 + starter tree 문자열이 CLAUDE.md에 부재·신규 파일에
  존재.
- **AC16**: 압축된 각 SKILL 발동 수동 확인(트리거 문구가 skill 매칭 유지).
- **AC17/AC18**: 재생성 전/후 diff → 스캐폴딩 파일만 변경, 핵심 규칙 본문 무변경; stripped 문자열
  재유입 grep 0건.
- **전 PR**: 접촉 plugin 테스트 스위트 green(qg guard, spec-distill `-m unittest`, project-init
  hook tests) + plugin.json bump 확인.

## 10. Rejected Alternatives

- **Approach A (보수적 in-place 트림)** — STRIP-8 + 표면 인용만 제거, TRIM-21은 문단 유지, 전
  agent 보존. 기각: repo 무게·중복이 상당 부분 잔존, "카탈로그 → 코드 지도" 정체성 전환 미달.
  리스크 최저지만 "특별함만 남긴다"(LD4)에 미흡.
- **Approach C (최대 — 철학을 CLAUDE.md로 흡수·doc 삭제)** — 기각: README "Principles
  Instantiated"의 `P#` cross-ref와 CLAUDE.md 링크가 전부 깨져 Law 3 compounding substrate 손실;
  convenience agent 3개 전부 strip은 인터뷰 R3(steelman)/breadth Law-1 조력 능력 저하(NG4);
  CLAUDE.md 과압축은 persona 유지보수의 "왜" 논거 손실.
- **history: 태그 없이 그냥 삭제** — 기각: git 이전 커밋에 남아 복구는 가능하나 archaeology
  friction; annotated 태그가 명명된 복구 지점을 zero-cost로 제공.
- **history: 별도 저장소로 이동** — 기각: in-repo git-log 연속성 단절, 과거 맥락 추적이 다른 repo를
  요구. 태그가 연속성 유지하며 동일 복구성 제공.
- **history: orphan 아카이브 브랜치** — 기각(태그 대비): branch 목록에 영구 잔존(소음). 태그가
  더 가벼움.
- **pr-understanding-builder를 strip 대신 inline화** — 기각(현 설계): zero-filesystem 순수성이
  load-bearing 게이트가 아니므로 기능째 제거가 "특별함만 남긴다"에 부합. 단 blast radius가 커
  spec-review에서 재확인(사용자가 carve-out하면 이 대안으로 전환 가능).

## 11. Metadata

- **버전 영향**: qg **major**(WS3 기능 제거) · project-init **patch**(WS4 description) · description
  접촉 plugin별 **patch**(WS4) · PR1이 plugin README 접촉 시 해당 plugin **patch**. 각 bump는
  같은 PR에서(cache key stale 방지, AC19).
- **PR 순서**: PR0(design) → PR1(철학) → PR2(history) → PR3(agent) → PR4(런타임) → PR5(project-init).
  PR1–PR4는 대체로 독립이나 cross-ref 정합상 PR1을 먼저 병합 권장. PR5는 WS1–4 병합 후.
- **머지 정책**: merge commit(rebase 금지 — feedback_git_merge_over_rebase). stacked PR base
  삭제 주의(feedback_stacked_pr_base_deletion).
- **구현**: 울트라코드(Workflow) — PR별 subagent-driven 구현 + Law 2 분리 리뷰 + 필요 PR /qg.
- **다음 단계**: 이 doc Law 2 리뷰 통과 → 사용자 리뷰 게이트 → `superpowers:writing-plans`.

## Appendix A — 철학 doc keep/trim/strip 분류 (ground truth)

understand 워크플로우 map:philosophy 산출. writing-plans/rewrite의 기준.

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

**STRIP-8 (generic 재진술·미구현·redirect)**

P16(미구현 벤치마크·§9 Q9 미해결) · AP4(LOC 지표·gstack anecdote) · AP7(vague names·CLAUDE.md
중복) · AP8(tool-response pollution·generic) · AP10(stale indexes·P5 흡수 redirect) ·
AP11(tool scoping·P3 흡수 redirect) · AP14(unchallenged consensus·AP13/P11 재표현) ·
AP17(chat-only state·P14 흡수 redirect).

**TRIM-21 (규칙 실재 but 중복/over-explained — CLAUDE.md 존치분은 엔트리 제거, 통찰분은 one-liner)**

P1·P5·P6·P7·P8*·P9·P14·P15·P19·P20·P23·P24 / AP1·AP2·AP5·AP6·AP9·AP12·AP13·AP15·AP16.
*P8(determinism-economy)은 devbrew-original 통찰 → 반드시 생존(AC3).

**외부 apparatus(LD7 strip)**: Appendix A(876–938, ~100% verbatim quote) · §6 Attribution
Map(689–737) · §0 Thesis quote 4개 · §5 tension quote 다수 · absorbed-source 인벤토리(54–61) ·
`../reference` 포인터(CLAUDE.md:8).

**CLAUDE.md 중복 ~12섹션**: §1 Three Laws · §2.2 P3 · §2.4 P6/P13/P19/P21/P22/P23 · §2.3 P5/§4.8
markdown state · §3 anti-corollaries(AP2/AP3/AP5/AP9/AP16) · P12/AP5 trivia · §4.0 디렉토리 구조.
