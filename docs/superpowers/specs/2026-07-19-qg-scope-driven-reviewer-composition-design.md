# qg Review gate 스코프-구동 리뷰어 구성 (dynamic reviewer composition)

> **오케스트레이터가 문제 스콥으로 리뷰어를 고른다 — 고정 로스터에서 스코프-구동 구성으로.**
> *리뷰어 선택 로직(scout.py)은 이미 존재하나 고아 상태다. 이 작업은 그것을 오케스트레이터가 실제로 소비하도록 배선하고 3자 drift를 정합한다. qg 에이전트의 tool posture·Law 2 집행은 손대지 않는다(#104 락 유지).*

quality-gates Review gate **리뷰어 구성** 재설계. devbrew Law 1(구조 게이트) 준수 — 필수 섹션 모두 채움.

## 목차

- [Handoff Context](#handoff-context)
- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. 설계](#5-설계)
  - [5.1 리뷰어 3-tier 모델](#51-리뷰어-3-tier-모델)
  - [5.2 Selection — 모델 판단 + scout 힌트 + rubric + 팔레트](#52-selection--모델-판단--scout-힌트--rubric--팔레트)
  - [5.3 투명성 + graceful degradation](#53-투명성--graceful-degradation)
  - [5.4 Security Considerations (write-capable 외부 리뷰어 magnitude)](#54-security-considerations-write-capable-외부-리뷰어-magnitude)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [10. Metadata](#10-metadata)

## Handoff Context

**TL;DR** — Review gate가 리뷰어를 **고정 로스터**로 디스패치하는 것을, **오케스트레이터가 diff 스코프로 선택**(모델 판단 + scout 힌트 + rubric)하도록 바꾼다. floor(security-reviewer + adversarial)는 항상, codex는 있으면 항상, Tier C 전문가는 스코프로 가감. **qg 에이전트의 tool/Law-2 posture는 무변경**(#104 락 유지) — 이 스펙은 순수하게 **리뷰어 구성** 기능이다.

**Implicit context (구현자가 알아야 할 대화 배경, 재파생 불필요):**
- 초기 설계는 리뷰어에 Bash 부여(#104 부분 반전) + mutation 감지 가드 + Law2/P3 원장 개정 + SAST-via-Bash를 포함했으나, adversarial 리뷰(Claude+codex 수렴) 후 **사용자가 SAST 목표를 제거** → Bash·가드·원장 개정·egress 리스크가 전부 불필요해져 스펙을 라우팅 기능으로 환원. (§9.)
- security-auditor의 tool-free graft(secret-masking + CWE 태깅)도 **별도 후속 스펙으로 defer**(2라운드 리뷰가 라우팅과 무관한 독립 변경으로 지적 — §9).
- 따라서 **qg 에이전트 frontmatter `tools:`는 이 작업에서 안 건드린다** — #104(2026-07-19 머지, `fix(law2)!`)가 잠근 `Read, Grep, Glob` 유지.
- 리뷰어 선택은 **의도적으로 모델-주도**(lightness). 결정론 selector 스키마를 두지 않는다(§9 기각). 테스트 표면은 floor 불변·transparency·rubric-embed에만. scout.py는 힌트 provider로 강등하되 로직·테스트 유지.
- git-history/이전-PR 렌즈는 **이미 Bash-무장된 외부** `pr-review-toolkit:code-reviewer`가 수행 — qg-own 에이전트 무변경.

**Deferred to plan (구현 세부 — 설계는 의미(semantic)를 확정, 정확한 리터럴만 plan-level):**
- Tier C 후보 dispatch 프롬프트의 **정확한 문구**(rubric·팔레트 semantic은 §5.2에서 확정; 문장 표현만 plan).
- 각 grep-lock의 **body-unique 리터럴 문자열**(각 lock이 무엇을 assert하는지 semantic은 §6/§8에서 확정; 정확한 grep 패턴만 plan).
- `docs_touched` **판정 경계는 확정됨** — `scripts/filter-docs.sh`가 docs로 분류하는 path 집합 재사용(§5.2.6). plan은 scout.py 배선만.

## 1. Context / Why

**문제: 스코프→리뷰어 선택 로직이 3자 drift 상태다.**

- **`scripts/scout.py`** — 결정론 classifier가 이미 `depth` + `phase1_agents[]` + `phase2_agents[]`를 emit(입력: `changed_lines, new_files, config_touched, type_design, test_change`). "스코프로 리뷰어 고르기"가 이미 코드로 존재한다.
- **`skills/quality-pipeline/SKILL.md` (v2.12.0)** — scout를 실행만 하고 추천을 **버린 채** 고정 로스터(security-reviewer + adversarial 항상, code-reviewer/codex는 "가용하면")만 디스패치. 스코프 무관.
- **`README.md` §166 (v1.5.0 재설계)** — scout-driven 다단계 dispatch(Phase 1/2 depth·scope-aware, 전문가 매핑, §186 AP9 fan-out 게이트)를 문서화하나 SKILL이 안 지킴.

이 작업 = **(a) 고아가 된 스코프-구동 선택을 오케스트레이터가 실제로 수행하도록 배선, (b) README/SKILL/scout 3자 정합.** 부수적으로 좁은 diff의 리뷰어 낭비(효율)와 스코프-맞춤 전문가 누락(커버리지)을 동시에 개선.

## 2. Goals

1. Review gate가 diff 스코프에 맞는 리뷰어 세트를 **오케스트레이터 판단**으로 구성(더하고 빼기).
2. 고정 보안 floor(security-reviewer + adversarial)는 어떤 스코프에서도 불변 — 모델이 못 뺀다(런타임 census teeth 포함 검증).
3. Tier C 전문가 메뉴(pr-review-toolkit 5 + feature-dev:code-architect)를 스코프로 선택 — review-pr §4 rubric + scope-signal 팔레트로.
4. README / SKILL / scout.py 3자 정합(§186 AP9 fan-out 게이트 선언 제거 + max fan-out 재계산 포함).
5. scout에 `docs_touched` 힌트 추가(comment-analyzer 선택 gap 해소).

## 3. Non-goals

- **qg 에이전트 tool posture 무변경** — security-reviewer/adversarial는 #104의 `Read, Grep, Glob` 유지. **Bash/Web 부여 없음.**
- **SAST/CVE 능동 스캔 없음** — `npm audit`/`pip-audit` 실행은 이 스펙 영역 밖. security-reviewer는 기존대로 매니페스트 변경을 **flag만** 한다.
- **security-auditor graft(secret-masking/CWE) 없음** — 별도 후속 스펙으로 defer(§9).
- **mutation 감지 가드 없음** · **Law 2 / P3 원장 개정 없음** · **Runtime gate 무변경.**
- **scout.py 결정론 로직 삭제 없음**(힌트로 강등, 로직·테스트 유지) · **새 결정론 classifier/selector 스키마 신설 없음**(선택=모델 판단).
- **`code-simplifier` 편입 없음**(writer) · **수치 0–100 스코어링 미도입**(P2; qg 1–10 confidence 유지).
- **fan-out consent 게이트 없음**(lightness) · **커뮤니티/미검증 hard dep 없음** · **외부 에이전트 model override 없음**.

## 4. Constraints

- **devbrew Law 2** — Writer ≠ Reviewer. qg 리뷰어 tool을 **안 바꾸므로** #104의 tool-deny 집행을 상속. floor는 물리적 read-only 유지.
- **PR #104 (main @ `9d41efd`, 2026-07-19 머지, `fix(law2)!`)** — qg 리뷰 에이전트를 fail-closed `tools:` allowlist(`Read, Grep, Glob`)로 잠갔다. **본 작업은 이 락을 유지**(건드리지 않음). 머지 확인됨(브랜치 base = #104 반영 main). *주의: 이 세션의 agent-registry 스냅샷은 세션-시작 캐시라 stale — on-disk `agents/*.md`가 진리([[reference_workflow_law2_agenttype]] 함정).*
- **외부 Tier C 에이전트는 write-capable** — pr-review-toolkit=inherit-all(Bash/Write), feature-dev:code-architect=Read+Web. §5.4에서 magnitude를 정직히 다룬다.
- **lightness** ([[feedback_harness_lightness_trust_model]]) — 리뷰어 선택은 routing → 모델 신뢰. 결정론은 floor 불변·transparency·rubric-embed에만.
- **model 하드코딩 존중** ([[feedback_respect_upstream_model_hardcoding]]) — code-reviewer=opus, code-architect=sonnet, 전문가=inherit 그대로.
- **버전** — plugin.json 2.12.0 → **2.13.0**(minor) · **doc convention** — Korean-primary, ≥300줄 TOC.

## 5. 설계

### 5.1 리뷰어 3-tier 모델

```
Tier A — Floor (비-trivia면 항상, 결정론, 모델이 못 뺌)   ← AC1 floor-lock 대상
  ├── security-reviewer   (Phase 1, 병렬)   tools: Read,Grep,Glob (무변경)
  └── adversarial         (Phase 1.5)        tools: Read,Grep,Glob (무변경)

Tier B — Availability-floor (있으면 무조건, 스코프 무관)   ← AC2
  └── codex-reviewer      (detect_codex 참)  — 모델 다양성 = load-bearing

Tier C — Dynamic (모델이 스코프로 선택, advisory, 외부 에이전트; 최대 6 후보)
  ├── pr-review-toolkit:code-reviewer        ← 강한 default (§5.2 정의); floor 아님
  ├── pr-review-toolkit:silent-failure-hunter → 에러핸들링 변경
  ├── pr-review-toolkit:type-design-analyzer  → 신규/변경 타입
  ├── pr-review-toolkit:pr-test-analyzer      → 테스트 변경
  ├── pr-review-toolkit:comment-analyzer      → docs/주석 변경
  └── feature-dev:code-architect             → 대형 구조/아키텍처 변경
```

- **"비-trivia"** = `check-trivia.sh` exit 1(기존 정의; 재정의 안 함).
- **Floor(Tier A) 불변** = 모델이 스코프 판단으로 못 뺀다. AC1이 정적 grep-lock **+ 런타임 census**(§8)로 이빨 부여.
- **code-reviewer는 Tier C "강한 default"** — floor 아님. §5.2 정의: 비-trivial diff면 code-reviewer를 **기본 포함**하되 quick-depth diff에선 drop 가능. AC1 floor-lock 대상은 오직 security-reviewer + adversarial.
- **git-history/이전-PR 렌즈**는 이미 Bash-무장된 `pr-review-toolkit:code-reviewer`가 프롬프트 힌트로 수행 — qg 무변경.

### 5.2 Selection — 모델 판단 + scout 힌트 + rubric + 팔레트

**선택은 의도적으로 모델-주도다**(lightness 결정 — 리뷰어 선택은 routing이지 load-bearing 정확성 게이트가 아님). 결정론 selector I/O 스키마를 두지 **않는다**(§9 기각: 재현성 게이트는 lightness 위반). 테스트 표면은 **floor 불변(AC1) + transparency 라인(AC8) + rubric/팔레트 embed(AC3/AC4)**이며, "어떤 전문가를 뽑았는가"의 정확성은 게이트하지 않는다.

1. **scout 실행(힌트).** `scout.py`가 `depth`(quick/standard/deep) + 추천 subset을 emit → 오케스트레이터의 **힌트**. scout 결정론 로직 유지(Non-goal).
2. **모델이 Tier C 구성** — resolved 스코프(파일·diff) + scout 힌트 + rubric + 팔레트로 판단. Retry마다 재선택.
3. **rubric (review-pr §4 흡수, 자연어 embed):**
   | 스코프 신호 | 전문가 |
   |---|---|
   | 테스트 파일 변경 | pr-test-analyzer |
   | docs/주석 추가 | comment-analyzer |
   | 에러핸들링 변경 | silent-failure-hunter |
   | 타입 추가/변경 | type-design-analyzer |
   | 대형 구조/아키텍처 | feature-dev:code-architect |
   | 비-trivial diff 기본 | pr-review-toolkit:code-reviewer (강한 default; quick-depth만 drop) |
4. **depth→Tier C 크기 가이드라인 (모델 판단, 재현성 게이트 아님):** `quick` → code-reviewer만(또는 없음); `standard` → + 신호-매칭 전문가 1–2; `deep` → + 신호-매칭 전문가(구조 변경이면 code-architect). scout phase2가 힌트.
5. **비-규범 예시 (illustrative only — 게이트 아님, 모델이 최종 판단):**
   | diff 예 | scout depth | 예상 Tier C 선택 |
   |---|---|---|
   | 1-파일 버그픽스 | quick | code-reviewer |
   | 기능 추가(에러핸들링+테스트) | standard | code-reviewer, silent-failure-hunter, pr-test-analyzer |
   | 신규 모듈(새 타입+구조) | deep | code-reviewer, type-design-analyzer, code-architect |
   | 순수 docs 개편 | standard | comment-analyzer (+ code-reviewer) |

   이 표는 **테스트 대상이 아니다** — 모델 판단의 감을 주는 예시. 게이트는 floor/transparency/rubric-embed만(§6).
6. **scope-signal 팔레트 (SKILL 산문, `security-guidance` 카테고리 출처):** 역직렬화(pickle/yaml/torch) · 인젝션(eval/exec/os.system/subprocess-shell) · XSS(innerHTML/dangerouslySetInnerHTML) · crypto(createCipher/AES-ECB) · TLS-verify-disabled · XXE · GHA-workflow-injection · SRI · deps-manifest · migration/schema · public-API · 삭제 파일. 모델 판단을 풍부하게(결정론 아님).
7. **scout `docs_touched` 신호 (경계 확정):** scout 입력에 `docs_touched` boolean 추가. **판정 경계 = `scripts/filter-docs.sh`가 docs로 분류하는 path 집합**(재사용 — 별도 정의 신설 안 함). docs 변경 시 comment-analyzer를 phase2 힌트로. (현재 scout에 docs 신호가 없어 comment-analyzer가 결정론 힌트로 안 나오던 gap 해소.)

### 5.3 투명성 + graceful degradation

- **투명성 (loud):** 매 iteration **user-visible stdout** 한 줄 — 형식: `> [quality-gates] Review iter N — 선택: <리뷰어 목록>(근거: <스코프 신호>) / 제외: <이유 또는 "해당 신호 없음">`. drop·degrade를 조용히 넘기지 않는다. **"loud" = 위 `> [quality-gates]` prefix의 user-visible stdout 라인**(스펙 공통 정의).
- **fan-out 게이트 없음**(lightness); 스프레이는 (a) rubric 자연-바운드(신호 있는 전문가만 발화 — 전형 diff는 1–2), (b) 이 transparency 라인(선택/제외 가시화 — silent 아님), (c) README 재계산 max fan-out 선언, (d) authoring-time hard-review(fan-out ≥5 = CLAUDE.md hard 게이트)로 억제.
- **Graceful degradation:** pr-review-toolkit / feature-dev 미설치 → 해당 Tier C unavailable, **floor(A) + codex(B) + 설치된 것** 계속, **loud log**: `> [quality-gates] specialist <X> unavailable (<plugin> 미설치) — degraded coverage`.
- **의존 명시:** README prerequisites에 pr-review-toolkit·feature-dev를 Tier C optional dependency로 선언.

### 5.4 Security Considerations (write-capable 외부 리뷰어 magnitude)

**정직한 before/after (리뷰 지적 반영 — 유비 아닌 수치; tool census 일치):**
- **Before(현행):** write-capable 외부 advisory 리뷰어 **1개**(`code-reviewer`, "가용하면" 조건부 디스패치). README가 fan-out consent 게이트(`>=4 → AskUserQuestion`)를 여러 곳에 문서화(단, 현행 SKILL에 카운트 체크가 **구현된 적 없음** → documented-not-implemented drift).
- **After(본 스펙):** Tier C 후보 **최대 6개** = **write-capable 5**(pr-review-toolkit, inherit-all/Bash+Write) **+ read/web-only 1**(`feature-dev:code-architect` — tools: Glob/Grep/LS/Read/NotebookRead/WebFetch/TodoWrite/WebSearch, **Write/Edit/Bash 없음**). 즉 write-capable 증가는 **1→최대 5**이고 code-architect는 write-capable이 아니다. 모델이 iteration별 선택. **동시에 fan-out consent 게이트 문서 주장 reconcile(제거)**, **신규 구조 가드 미도입.**

이는 리스크 **category**(외부 advisory 리뷰어의 write-capable soft-spot, 기존 code-reviewer와 동종)가 아니라 **magnitude**(write-capable **1→최대 5**, + read/web-only 1, 게이트 주장 제거)의 확대다 — 이 스펙은 그 확대를 **의도적으로 수용**한다:
- **qg-own floor는 #104 락으로 물리적 read-only 유지** — 이 스펙은 qg의 Law-2 posture를 안 바꾼다.
- 외부 리뷰어는 **advisory**(오케스트레이터가 fix를 소유; 리뷰어 출력은 findings YAML). 이들이 write-capable인 건 upstream posture이며 qg가 통제 불가.
- 무-게이트/무-가드는 **명시적 lightness tradeoff** — 통제는 예방(prevention)이 아니라 **가시성(transparency 라인) + 자연 바운드(rubric) + 재계산 max fan-out 선언 + authoring hard-review**. 예방적 구조 가드(mutation-guard/consent-gate)는 사용자 결정으로 제외(§9); 원하면 별도 후속 스펙 사안.
- **egress:** qg-own 리뷰어엔 Bash/Web 없음(초기 설계의 egress 리스크 소멸). 외부 리뷰어의 egress는 기존 code-reviewer와 동일 수준(신규 아님).

## 6. Acceptance Criteria

1. **AC1 — Floor 불변 (정적 + 런타임 teeth):** 비-trivia diff에서 security-reviewer + adversarial는 스코프 무관 항상 디스패치. (a) SKILL grep-lock: 두 `subagent_type` 블록 무조건 경로 + mutation-teeth; (b) **런타임 census**(§8): self-dogfood 트랜스크립트에서 두 floor dispatch 실측.
2. **AC2 — codex availability-floor:** `detect_codex` 참이면 스코프 무관 항상 디스패치. (기존 codex invariant 테스트 유지 + grep)
3. **AC3 — Tier C 스코프 선택 + rubric embed:** SKILL에 rubric 6항 자연어 embed. (body-unique 문구 섹션-스코프 grep-lock)
4. **AC4 — scope-signal 팔레트:** SKILL에 팔레트(역직렬화·인젝션·XSS·crypto·TLS·XXE·GHA·SRI·deps·migration·public-API·삭제) 산문. (grep-lock)
5. **AC5 — scout docs_touched:** `scout.py` 입력에 `docs_touched`(경계=filter-docs.sh); docs-변경 입력에서 comment-analyzer가 phase2 힌트. (scout unit test)
6. **AC6 — code-reviewer tier 명확화:** code-reviewer는 Tier C(강한 default, quick-depth drop 가능), floor(AC1) 목록엔 없다 — §5.1/§5.2 정합, floor에 "항상" 표기 부재. (grep: floor 목록에 code-reviewer 부재 + Tier C 강한-default 문구 존재)
7. **AC7 — Tool posture 무변경:** `agents/security-reviewer.md`·`agents/adversarial.md` `tools:` = `Read, Grep, Glob`(#104 그대로; Bash/Web 부재). (tools-lock 테스트 — #104 회귀 방지, YAML-우회 봉쇄)
8. **AC8 — "loud" 정의 + transparency:** SKILL에 매 iter 선택/제외 한 줄(`> [quality-gates] Review iter N — 선택:… / 제외:…`); degrade도 `> [quality-gates]` prefix. (grep-lock)
9. **AC9 — fan-out consent 게이트 주장 whole-file reconcile + max fan-out 재계산:** `len(phase1)+len(phase2)>=4 → AskUserQuestion` fan-out consent 게이트 주장은 README **한 곳이 아니라 여러 곳**(현행 대략 line 15 `P22 anti-corollary(former AP9) hard gate`, 37–39 `P22 generalization / same tool gates subagent fan-out`, 141 `AskUserQuestion fan-out count excludes …`, 186 `>=4 … AskUserQuestion`, 190 `동일한 도구가 subagent fan-out gate…`, 240 동일)에 산재한다. **§186만 편집하면 자기모순**([[feedback_gate_scope_blind_spot]] cross-ref drift). 따라서: (a) 이 주장을 전 위치에서 reconcile — qg는 fan-out consent 게이트를 **fire하지 않음**(documented-not-implemented였음); fan-out은 rubric+transparency+**재계산 max fan-out 선언**으로 bound. **P22 instantiation은 "consent 게이트"가 아니라 "transparency 라인 + 선언된 max fan-out + authoring hard-review" 기반으로 restate**(P22 자체는 불변; qg의 instantiation 문구만 정정). (b) **max fan-out 재계산 존치** — phase-1 병렬 ≤ 8(security-reviewer + codex + Tier C 최대 6), 총/iteration ≤ 10(+ adversarial + synthesizer; code-simplifier Phase 3 없음). **검증:** whole-file negative grep(`>=4`/`≥4`-fan-out-AskUserQuestion 게이트 주장 부재) + positive grep(재계산 max fan-out 수치 존재) + P22 instantiation 문구가 transparency-기반으로 정정됐는지. (line 번호는 현재 스냅샷 — plan은 문자열 기준으로 전수 grep.)
10. **AC10 — README §166 정합:** README §166이 새 3-tier 모델 반영 + prerequisites에 pr-review-toolkit·feature-dev optional dep. (grep: 리뷰어 목록 ↔ SKILL 정합)
11. **AC11 — Graceful degradation:** pr-review-toolkit/feature-dev 부재 시 floor+codex 계속 + loud log. (SKILL grep + §8 census 확인)
12. **AC12 — 버전 + CHANGELOG:** plugin.json=2.13.0; CHANGELOG `## [2.13.0] — 2026-07-19`. (grep-lock; minor만 핀, patch digit unpin — [[feedback_version_pin_vs_bump_rule]])
13. **AC13 — Law-2/posture 무변경 + 수치 스코어링 미도입:** qg 리뷰 에이전트에 Bash/Write/Edit/Agent 미부여; Runtime gate·CLAUDE.md Law 2·philosophy 무변경; `code-review`식 0–100 confidence 필터 부재(qg 1–10 유지). (negative grep-lock 세트)
14. **AC14 — Non-goal 가드:** `code-simplifier` `subagent_type` 미등장; 외부 dispatch 블록에 `model:` override 부재; security-auditor graft(secret-masking/CWE) 미포함. (grep-lock)

## 7. Files to Modify

| 파일 | 변경 |
|---|---|
| `skills/quality-pipeline/SKILL.md` | Review gate dispatch 재작성 — scout 힌트 소비 + 3-tier + rubric + scope-signal 팔레트 + depth 가이드라인 + transparency 라인 + graceful degrade. **tool 관련 변경 없음.** |
| `scripts/scout.py` | `docs_touched` 입력 신호(경계=filter-docs.sh) + docs→comment-analyzer phase2 힌트 |
| `README.md` | §166 새 모델 정합 + **fan-out consent 게이트 주장 전 위치 reconcile**(대략 line 15·37–39·141·186·190·240 — 문자열 grep 전수; P22 instantiation을 transparency-기반으로 restate) + max fan-out 수치 재계산 존치 + prerequisites(pr-review-toolkit·feature-dev optional dep) |
| `.claude-plugin/plugin.json` | version → 2.13.0 |
| `CHANGELOG.md` | `## [2.13.0]` — Added(스코프-구동 선택·팔레트·docs_touched) / Changed(scout 힌트 강등·README 정합·AP9 선언 제거) |
| `tests/` | AC1–AC14 grep-lock/behavior/mutation-teeth/census 테스트 신규·갱신 |

**건드리지 않는 파일(명시):** `agents/security-reviewer.md`·`agents/adversarial.md`(tools + persona 전부), `agents/runtime-verifier.md`, `scripts/synthesize_findings.py`, `CLAUDE.md`, `docs/philosophy/*.md`, Runtime gate 스크립트.

## 8. Verification Plan

- **정적(grep-lock):** AC3·AC4·AC6·AC8·AC9·AC10·AC13·AC14 — 각 락은 **body-unique 문구를 섹션 윈도우에서** grep + **mutation으로 이빨 증명**(헤더-satisfiable·nullglob·후행개행 함정 회피 — [[feedback_lock_passes_but_has_no_teeth]], [[feedback_grep_lock_header_satisfiable]]).
- **tools-lock:** AC7 — security-reviewer·adversarial `tools:` = `Read, Grep, Glob` 단언(#104 회귀 방지, YAML-우회 봉쇄).
- **negative grep:** AC9(AP9 게이트 부재 but 수치 존치)·AC13(Bash 부여·Law2 변경·0–100 스코어링 부재)·AC14(graft 미포함).
- **unit:** AC5(scout docs_touched → comment-analyzer 힌트, 경계=filter-docs.sh).
- **런타임 teeth (AC1/AC11 — grep-lock 이빨 보강):** 텍스트-only lock은 모델 준수 미검증([[reference_workflow_law2_agenttype]] "트랜스크립트 census"). 구현 후 `/qg branch` self-dogfood 트랜스크립트에서 `grep -o '"name":"[A-Za-z0-9_-]*"'` census로 **(i) 두 floor 리뷰어 실제 dispatch, (ii) 미설치 전문가 degrade loud-log 발생**을 실측(하이픈 포함 — MCP 놓침 방지).
- **/qg self-dogfood:** 구현 후 `/qg branch` 전체 파이프라인 — codex 모델-다양성 포함 whole-branch 리뷰로 fail-open 재적발([[project_qg_scope_capture]]: 2단계 통과≠버그없음).
- **baseline:** 작업 전 pre-existing red 캡처(repo root 실행 — [[project_qg_pre_existing_test_reds]]).

## 9. Rejected Alternatives

- **리뷰어에 Bash 부여(#104 부분 반전) + mutation 감지 가드 + Law2/P3 원장 개정 + SAST-via-Bash:** 초기 설계. adversarial 리뷰가 (i) 감지 가드 egress 미봉쇄, (ii) 가드 계약 block-급 미정의, (iii) 4-서브시스템 scope_creep, (iv) 당일 머지 #104 반전을 지적 → **사용자가 SAST 목표 제거로 전량 기각.** tool posture 무변경이 가장 가볍고 안전.
- **오케스트레이터가 SAST 결정론 사전실행 후 read-only 텍스트 전달:** Bash-미부여 SAST 대안. → **무의미(moot)** — SAST 목표 자체 제거. (미래 CVE 스캔 시 Bash-arming보다 안전한 출발점.)
- **security-auditor tool-free graft(secret-masking + CWE 태깅):** → **별도 후속 스펙으로 defer.** 2라운드 리뷰가 라우팅과 무관한 독립 finding-schema/persona 변경으로 지적(near-zero shared surface, 독립 revert 가능) — 라우팅-only 스펙 초점 유지를 위해 분리.
- **결정론 scout-driven 선택 / 결정론 selector I/O 스키마:** scout 리스트를 권위로 소비하거나 selector 계약 명세. → **거부(lightness).** 리뷰어 선택은 routing이지 load-bearing 정확성 게이트가 아님 — 재현성 게이트는 모델 신뢰 원칙 위반. 검증은 floor/transparency/rubric-embed에만; "어떤 전문가를 뽑았나"는 비-결정 허용.
- **qg 자체 read-only 전문 리뷰어 신설:** upstream persona 복제 = drift·유지비. 재사용이 DRY.
- **fan-out consent 게이트 / 외부 fan-out 예방 가드:** → 거부(lightness, 사용자 결정). §5.4 가시성-기반 통제로 대체(magnitude는 정직히 명시·수용).
- **code-modernization security-auditor/architecture-critic Tier C 편입:** security-reviewer 중복 + legacy 특화 + Bash 보유.
- **community 에이전트 hard dep:** 미검증·수동 마켓 — 보안 게이트 부적합.

## 10. Metadata

- **Spec:** 2026-07-19 · qg Review gate 스코프-구동 리뷰어 구성
- **Target plugin:** quality-gates v2.12.0 → **v2.13.0**(minor)
- **Branch:** `feature/qg-scope-driven-reviewers` (base: main @ `9d41efd` = #104 머지 후, 확인됨)
- **관련 원장(memory):** [[project_qg_detector_simplification]] · [[project_law2_agent_tool_surface]] · [[feedback_harness_lightness_trust_model]] · [[feedback_respect_upstream_model_hardcoding]] · [[project_qg_scope_capture]] · [[reference_workflow_law2_agenttype]]
- **차용 출처:** `pr-review-toolkit`(전문가·§4 rubric) · `code-review` 플러그인(히스토리/이전-PR 렌즈; 수치 스코어링 제외) · `security-guidance`(설치된 hook 플러그인 — `marketplaces/claude-plugins-official/plugins/security-guidance/hooks/patterns.py`의 25 보안 패턴; agent/skill이 아니라 hook이라 agent registry엔 없음 — scope-signal 팔레트 출처)
- **결정 로그:** 동기=완전 동적 / floor=security+adversarial 고정 / codex=availability-floor / selection=모델 판단·scout 힌트(결정론 selector 스키마 기각) / 메뉴=pr-review-toolkit5+code-architect+히스토리렌즈 / 신호=docs+산문 팔레트 / fan-out 게이트=없음(magnitude 정직 수용) / **tool posture=무변경(#104 락 유지)** / **SAST 제거** / **graft defer** / **원장 무개정** / **mutation guard 없음**
- **후속(구현 단계):** writing-plans → subagent-driven 구현(TDD) → whole-branch 리뷰 → `/qg branch` self-dogfood → 사용자 검토/머지
