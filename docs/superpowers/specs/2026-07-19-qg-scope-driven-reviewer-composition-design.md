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
  - [5.4 security-auditor 경량 graft (tool-free)](#54-security-auditor-경량-graft-tool-free)
  - [5.5 Security Considerations](#55-security-considerations)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [10. Metadata](#10-metadata)

## Handoff Context

**TL;DR** — Review gate가 리뷰어를 **고정 로스터**로 디스패치하는 것을, **오케스트레이터가 diff 스코프로 선택**(모델 판단 + scout 힌트 + rubric)하도록 바꾼다. floor(security-reviewer + adversarial)는 항상, codex는 있으면 항상, Tier C 전문가는 스코프로 가감. **qg 에이전트의 tool/Law-2 posture는 무변경**(#104 락 유지) — 이 스펙은 순수하게 **리뷰어 구성** 기능이다.

**Implicit context (구현자가 알아야 할 대화 배경, 재파생 불필요):**
- 초기 설계는 리뷰어에 Bash를 부여(#104 부분 반전) + mutation 감지 가드 + Law 2/P3 원장 개정 + SAST-via-Bash까지 포함했으나, **adversarial 리뷰(Claude+codex 수렴) 후 사용자가 SAST 목표를 제거**하기로 결정 → Bash 부여·가드·원장 개정·egress 리스크가 **전부 불필요**해져 스펙을 라우팅 기능으로 환원했다. (기각 상세는 §9.)
- 따라서 **qg 에이전트 frontmatter `tools:`는 이 작업에서 건드리지 않는다** — #104(2026-07-19 머지, `fix(law2)!`)가 잠근 `Read, Grep, Glob`을 유지한다.
- 리뷰어 선택은 **의도적으로 모델-주도**(lightness). 결정론은 floor 불변·transparency·rubric-embed에만. scout.py는 힌트 provider로 강등하되 로직·테스트는 유지.
- git-history/이전-PR 렌즈는 **이미 Bash-무장된 외부** `pr-review-toolkit:code-reviewer`가 수행 — qg-own 에이전트는 무변경.

**Deferred to plan (writing-plans가 정할 것):**
- Tier C 후보 우선순위·중복 제거의 정확한 프롬프트 문구.
- scout `docs_touched` 판정의 정확한 path 규칙(reuse `filter-docs.sh` 경계).
- CWE 필드 렌더 위치(synthesize_findings.py 표 컬럼).
- 각 grep-lock의 body-unique 문구 선정.

## 1. Context / Why

**문제: 스코프→리뷰어 선택 로직이 3자 drift 상태다.**

- **`scripts/scout.py`** — 결정론 classifier가 이미 `depth` + `phase1_agents[]` + `phase2_agents[]`를 emit(입력: `changed_lines, new_files, config_touched, type_design, test_change`). "스코프로 리뷰어 고르기"가 이미 코드로 존재한다.
- **`skills/quality-pipeline/SKILL.md` (v2.12.0)** — scout를 실행만 하고 추천을 **버린 채** 고정 로스터(security-reviewer + adversarial 항상, code-reviewer/codex는 "가용하면")만 디스패치. 스코프 무관.
- **`README.md` §166 (v1.5.0 재설계)** — scout-driven 다단계 dispatch(Phase 1/2 depth·scope-aware, 전문가 매핑, §186 AP9 fan-out 게이트)를 문서화하나 SKILL이 안 지킴.

이 작업 = **(a) 고아가 된 스코프-구동 선택을 오케스트레이터가 실제로 수행하도록 배선, (b) README/SKILL/scout 3자 정합.** 부수적으로 좁은 diff의 리뷰어 낭비(효율)와 스코프-맞춤 전문가 누락(커버리지)을 동시에 개선한다.

## 2. Goals

1. Review gate가 diff 스코프에 맞는 리뷰어 세트를 **오케스트레이터 판단**으로 구성한다(더하고 빼기).
2. 고정 보안 floor(security-reviewer + adversarial)는 어떤 스코프에서도 불변 — 모델이 스코프 판단으로 뺄 수 없다(런타임 teeth 포함 검증).
3. Tier C 전문가 메뉴(pr-review-toolkit 5 + feature-dev:code-architect)를 스코프로 선택 — review-pr §4 rubric + scope-signal 팔레트로.
4. README / SKILL / scout.py 3자 정합(§186 AP9 fan-out 게이트 선언 제거 포함).
5. scout에 `docs_touched` 힌트 추가(comment-analyzer 선택 gap 해소).
6. security-auditor의 **tool-free** 좋은 부분(secret-masking 규율 + CWE 태깅)을 security-reviewer에 경량 graft.

## 3. Non-goals

- **qg 에이전트 tool posture 무변경** — security-reviewer/adversarial는 #104의 `Read, Grep, Glob` 유지. **Bash/Web 부여 없음.**
- **SAST/CVE 능동 스캔 없음** — `npm audit`/`pip-audit` 실행은 이 스펙 영역 밖(별도 도구·게이트). security-reviewer는 기존대로 매니페스트 변경을 **flag만** 한다.
- **mutation 감지 가드 없음** — 리뷰어가 write-capable이 아니므로(qg-own 기준) 신규 가드 불필요.
- **Law 2 / P3 원장 개정 없음** — 리뷰어 tool posture를 안 바꾸므로 현행 조문 그대로.
- **Runtime gate 무변경.**
- **scout.py 결정론 로직 삭제 없음** — 힌트로 강등하되 로직·테스트 유지. **새 결정론 classifier 신설 없음**(선택=모델 판단).
- **`code-simplifier` 편입 없음**(writer). **수치 0–100 스코어링 미도입**(P2; qg 기존 1–10 confidence 유지).
- **fan-out consent 게이트 없음**(lightness).
- **커뮤니티/미검증 에이전트 hard dep 없음** · **외부 에이전트 model override 없음**(하드코딩 존중).

## 4. Constraints

- **devbrew Law 2** — Writer ≠ Reviewer. 본 작업은 qg 리뷰어 tool을 **안 바꾸므로** #104의 tool-deny 집행을 그대로 상속. floor(security-reviewer+adversarial)는 물리적 read-only 유지.
- **PR #104 (main @ `9d41efd`, 2026-07-19 머지, `fix(law2)!`)** — qg 리뷰 에이전트를 fail-closed `tools:` allowlist(`Read, Grep, Glob`)로 잠갔다. **본 작업은 이 락을 유지한다**(건드리지 않음). (머지 확인됨 — 브랜치 base는 #104 반영된 main.)
- **외부 Tier C 에이전트는 write-capable** — pr-review-toolkit=inherit-all(Bash/Write 포함), feature-dev=Read+Web. 이는 **기존 code-reviewer 디스패치와 동일한 advisory 취급**이며 이 스펙이 새로 여는 표면이 아니다(§5.5).
- **lightness** ([[feedback_harness_lightness_trust_model]]) — 리뷰어 선택은 routing → 모델 신뢰. 결정론은 floor 불변·transparency·rubric-embed에만.
- **model 하드코딩 존중** ([[feedback_respect_upstream_model_hardcoding]]) — pr-review-toolkit:code-reviewer=opus, feature-dev:code-architect=sonnet, 전문가=inherit 그대로 dispatch.
- **버전** — plugin.json 2.12.0 → **2.13.0**(minor, 새 선택 surface).
- **doc convention** — Korean-primary, ≥300줄이면 TOC(본 스펙 포함).

## 5. 설계

### 5.1 리뷰어 3-tier 모델

```
Tier A — Floor (비-trivia면 항상, 결정론, 모델이 못 뺌)   ← AC1 floor-lock 대상
  ├── security-reviewer   (Phase 1, 병렬)   tools: Read,Grep,Glob (무변경)
  └── adversarial         (Phase 1.5)        tools: Read,Grep,Glob (무변경)

Tier B — Availability-floor (있으면 무조건, 스코프 무관)   ← AC2
  └── codex-reviewer      (detect_codex 참)  — 모델 다양성 = load-bearing

Tier C — Dynamic (모델이 스코프로 선택, advisory, 외부 에이전트)
  ├── pr-review-toolkit:code-reviewer        ← 강한 default (§5.2 정의); floor 아님
  ├── pr-review-toolkit:silent-failure-hunter → 에러핸들링 변경
  ├── pr-review-toolkit:type-design-analyzer  → 신규/변경 타입
  ├── pr-review-toolkit:pr-test-analyzer      → 테스트 변경
  ├── pr-review-toolkit:comment-analyzer      → docs/주석 변경
  └── feature-dev:code-architect             → 대형 구조/아키텍처 변경
```

- **"비-trivia"** = `check-trivia.sh` exit 1(기존 정의; 이 스펙이 재정의 안 함).
- **Floor(Tier A) 불변** = 모델이 스코프 판단으로 못 뺀다. AC1이 정적 grep-lock **+ 런타임 census**(§8)로 이빨 부여.
- **code-reviewer는 Tier C의 "강한 default"** — floor가 아니다. §5.2에서 정의: 모델은 비-trivial diff면 code-reviewer를 **기본 포함**하되, 극소 diff(quick depth)에선 drop 가능. AC1 floor-lock 대상은 오직 security-reviewer + adversarial.
- **git-history/이전-PR 렌즈**(`code-review` 플러그인 차용, 에이전트 아님)는 이미 Bash-무장된 `pr-review-toolkit:code-reviewer`가 프롬프트 힌트로 수행 — qg는 무변경.

### 5.2 Selection — 모델 판단 + scout 힌트 + rubric + 팔레트

**선택은 의도적으로 모델-주도다**(lightness 결정). 결정론 selector 스키마를 두지 않는다(§9 기각). 테스트 가능한 표면은 **floor 불변(AC1) + transparency 라인(AC12) + rubric/팔레트 embed(AC3/AC4)**이며, "어떤 전문가를 뽑았는가"의 정확성은 게이트하지 않는다.

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
4. **depth→Tier C 크기 가이드라인 (모델 판단, 하드 게이트 아님):** `quick` → Tier C = code-reviewer만(또는 없음); `standard` → + 신호-매칭 전문가 1–2; `deep` → + 신호-매칭 전문가(구조 변경이면 code-architect 포함). scout의 phase2 리스트가 힌트. **이 매핑은 재현성 게이트가 아니라 서술적 가이드** — floor/transparency/rubric-embed만 검증한다.
5. **scope-signal 팔레트 (SKILL 산문, `security-guidance` 카테고리 출처):** 역직렬화(pickle/yaml/torch) · 인젝션(eval/exec/os.system/subprocess-shell) · XSS(innerHTML/dangerouslySetInnerHTML) · crypto(createCipher/AES-ECB) · TLS-verify-disabled · XXE · GHA-workflow-injection · SRI · deps-manifest · migration/schema · public-API · 삭제 파일. 모델 판단을 풍부하게(결정론 아님).
6. **scout `docs_touched` 신호 추가** — scout 입력에 `docs_touched` boolean; docs 변경 시 comment-analyzer를 phase2 힌트로. (현재 scout에 docs 신호가 없어 comment-analyzer가 결정론 힌트로 안 나오던 gap 해소.)

### 5.3 투명성 + graceful degradation

- **투명성 (loud):** 매 iteration **user-visible stdout** 한 줄 — 형식: `> [quality-gates] Review iter N — 선택: <리뷰어 목록>(근거: <스코프 신호>) / 제외: <이유 또는 "해당 신호 없음">`. drop·degrade를 조용히 넘기지 않는다. **"loud" = 위 `> [quality-gates]` prefix의 user-visible stdout 라인**(전 스펙 공통 정의).
- **fan-out 게이트 없음**(lightness); 스프레이는 rubric 자연-바운드 + 이 투명성 + README max fan-out 선언 + authoring-time hard-review로 억제.
- **Graceful degradation:** pr-review-toolkit / feature-dev 미설치 → 해당 Tier C 전문가 unavailable, **floor(A) + codex(B) + 설치된 것**은 계속, **loud log**: `> [quality-gates] specialist <X> unavailable (<plugin> 미설치) — degraded coverage`.
- **의존 명시:** README prerequisites에 pr-review-toolkit·feature-dev를 Tier C optional dependency로 선언.

### 5.4 security-auditor 경량 graft (tool-free)

SAST-via-Bash·read-only-shell 규율은 **drop**(Bash 미부여). security-auditor에서 **tool 없이도 적용되는** 좋은 부분만 graft(선택·경량, 라우팅 기능과 분리 가능):

1. **secret-masking 규율** — security-reviewer persona에: 발견한 credential은 첫 2–4자 + `****`로 마스킹, `file:line` cite, 무엇을 grant하는지 + rotation 권고. (정적 reader도 secret을 출력에 인용할 수 있으므로 유효.)
2. **CWE 태깅** — finding YAML에 `cwe: CWE-XXX`(advisory 필드). `synthesize_findings.py`가 pass-through(있으면 표시, 없으면 무시 — backward-compatible).

이 graft는 qg 기존 우월 항목(untrusted-input discipline, anti-flag 리스트, 1–10 confidence, trusted-artifact custody)을 **유지**한 채 추가만 한다(replace 아님).

### 5.5 Security Considerations

- **외부 Tier C 에이전트는 write-capable**(pr-review-toolkit=inherit-all). 이는 **기존 `code-reviewer` advisory 디스패치와 동일한 Law-2 soft-spot**이며, 이 스펙이 새로 여는 것이 아니다(더 많은 advisory 외부 리뷰어를 같은 방식으로 추가할 뿐). **qg-own 리뷰어(floor)는 #104 락으로 물리적 read-only 유지** — 이 스펙은 qg의 Law-2 posture를 **바꾸지 않는다**. 외부 advisory 리뷰어에 대한 신규 구조 가드는 도입하지 않는다(현행과 동일 취급; 원한다면 별도 후속 스펙에서 다룰 사안).
- **qg 에이전트에 Bash/egress 표면 미부여** — 초기 설계의 egress-exfil 리스크는 SAST/Bash 제거로 소멸.

## 6. Acceptance Criteria

1. **AC1 — Floor 불변 (정적 + 런타임 teeth):** 비-trivia diff에서 security-reviewer + adversarial는 스코프 무관 항상 디스패치된다. (a) SKILL grep-lock: 두 `subagent_type` 블록이 무조건 경로에 존재 + mutation-teeth; (b) **런타임 census**(§8): self-dogfood 트랜스크립트에서 두 floor 리뷰어 dispatch를 실측.
2. **AC2 — codex availability-floor:** `detect_codex` 참이면 스코프 무관 항상 디스패치. (기존 codex dispatch invariant 테스트 유지 + grep)
3. **AC3 — Tier C 스코프 선택 + rubric embed:** SKILL에 rubric 6항(테스트/docs/에러핸들링/타입/아키텍처/code-reviewer-default) 자연어 embed. (body-unique 문구 섹션-스코프 grep-lock)
4. **AC4 — scope-signal 팔레트:** SKILL에 팔레트(역직렬화·인젝션·XSS·crypto·TLS·XXE·GHA·SRI·deps·migration·public-API·삭제) 산문 존재. (grep-lock)
5. **AC5 — scout docs_touched:** `scout.py` 입력에 `docs_touched`; docs-변경 입력에서 comment-analyzer가 phase2 힌트에 포함. (scout unit test)
6. **AC6 — code-reviewer tier 명확화:** code-reviewer는 Tier C(강한 default, quick-depth drop 가능)로 명시되고 floor(AC1) 목록엔 없다 — §5.1/§5.2 정합, "항상" 표현 부재. (grep: floor 목록에 code-reviewer 부재 + Tier C 강한-default 문구 존재)
7. **AC7 — Tool posture 무변경:** `agents/security-reviewer.md`·`agents/adversarial.md` frontmatter `tools:` = `Read, Grep, Glob`(#104 그대로; Bash/Web 부재). (tools-lock 테스트 — #104 락 회귀 방지)
8. **AC8 — "loud" 정의 + transparency:** SKILL에 매 iter 선택/제외 한 줄(`> [quality-gates] Review iter N — 선택:… / 제외:…`) emit; degrade도 `> [quality-gates]` prefix. (grep-lock)
9. **AC9 — security-auditor 경량 graft:** security-reviewer persona에 secret-masking 규율(2–4자+`****`, rotation) + finding `cwe` 필드; `synthesize_findings.py`가 `cwe` pass-through(없을 때 무해). (persona grep-lock + synthesizer 테스트)
10. **AC10 — README 정합:** README §166이 새 3-tier 모델 반영 + **§186 AP9 fan-out 게이트 선언(`len(phase1)+len(phase2)>=4 → AskUserQuestion`) 제거** + prerequisites에 pr-review-toolkit·feature-dev optional dep. (grep: 리뷰어 목록 ↔ SKILL 정합; negative grep: AP9 fan-out 게이트 선언 부재)
11. **AC11 — Graceful degradation:** pr-review-toolkit/feature-dev 부재 시 floor+codex 계속 + loud log. (SKILL grep + §8 census 확인)
12. **AC12 — 버전 + CHANGELOG:** plugin.json=2.13.0; CHANGELOG `## [2.13.0] — 2026-07-19`. (grep-lock; minor만 핀, patch digit unpin — [[feedback_version_pin_vs_bump_rule]])
13. **AC13 — 수치 0–100 스코어링 미도입 + Law-2 무변경:** `code-review`식 0–100 confidence 필터 부재(qg 1–10 유지); qg 리뷰 에이전트에 Bash/Write/Edit/Agent 미부여; Runtime gate 섹션·CLAUDE.md Law 2·philosophy 무변경. (negative grep-lock 세트)
14. **AC14 — Non-goal 가드:** `code-simplifier` `subagent_type` 미등장; 외부 에이전트 dispatch 블록에 `model:` override 부재. (grep-lock)

## 7. Files to Modify

| 파일 | 변경 |
|---|---|
| `skills/quality-pipeline/SKILL.md` | Review gate dispatch 재작성 — scout 힌트 소비 + 3-tier + rubric + scope-signal 팔레트 + depth 가이드라인 + transparency 라인 + graceful degrade. **tool 관련 변경 없음.** |
| `scripts/scout.py` | `docs_touched` 입력 신호 + docs→comment-analyzer phase2 힌트 |
| `agents/security-reviewer.md` | secret-masking 규율 + `cwe` 필드(**tools: 변경 없음**) |
| `scripts/synthesize_findings.py` | `cwe` 필드 pass-through(backward-compatible) |
| `README.md` | §166 새 모델 정합 + §186 AP9 fan-out 게이트 선언 제거 + prerequisites(pr-review-toolkit·feature-dev optional dep) + max fan-out 선언 |
| `.claude-plugin/plugin.json` | version → 2.13.0 |
| `CHANGELOG.md` | `## [2.13.0]` — Added(스코프-구동 선택·팔레트·docs_touched·경량 graft) / Changed(scout 힌트 강등·README 정합) |
| `tests/` | AC1–AC14 grep-lock/behavior/mutation-teeth/census 테스트 신규·갱신 |

**건드리지 않는 파일(명시):** `agents/security-reviewer.md`·`agents/adversarial.md`의 `tools:` 라인, `agents/runtime-verifier.md`, `CLAUDE.md`, `docs/philosophy/*.md`, Runtime gate 스크립트.

## 8. Verification Plan

- **정적(grep-lock):** AC3·AC4·AC6·AC8·AC10·AC13·AC14 — 각 락은 **body-unique 문구를 섹션 윈도우에서** grep + **mutation으로 이빨 증명**(헤더-satisfiable·nullglob·후행개행 함정 회피 — [[feedback_lock_passes_but_has_no_teeth]], [[feedback_grep_lock_header_satisfiable]]).
- **tools-lock:** AC7 — security-reviewer·adversarial `tools:` = `Read, Grep, Glob` 단언(#104 회귀 방지, YAML-우회 봉쇄 포함).
- **negative grep:** AC10(AP9 게이트 부재)·AC13(0–100 스코어링·Bash 부여·Law2 변경 부재).
- **unit:** AC5(scout docs_touched → comment-analyzer 힌트), AC9(synthesize `cwe` pass-through, 없을 때 무해).
- **런타임 teeth (AC1/AC11 — grep-lock의 이빨 보강):** 텍스트-only lock은 모델 준수를 검증 못 한다([[reference_workflow_law2_agenttype]] "트랜스크립트 census"). 구현 후 `/qg branch` self-dogfood 트랜스크립트에서 `grep -o '"name":"[A-Za-z0-9_-]*"'` census로 **(i) 두 floor 리뷰어가 실제 dispatch됐는지, (ii) 미설치 전문가에서 degrade loud-log가 실제로 났는지** 실측(하이픈 포함 패턴 — MCP 놓침 방지).
- **/qg self-dogfood:** 구현 후 `/qg branch` 전체 파이프라인 — codex 모델-다양성 포함 whole-branch 리뷰로 fail-open 재적발([[project_qg_scope_capture]]: 2단계 통과≠버그없음).
- **baseline:** 작업 전 pre-existing red 캡처(repo root 실행 — [[project_qg_pre_existing_test_reds]]).

## 9. Rejected Alternatives

- **리뷰어에 Bash 부여(#104 부분 반전) + mutation 감지 가드 + Law2/P3 원장 개정 + SAST-via-Bash:** 초기 설계였으나 adversarial 리뷰(Claude+codex)가 (i) 감지 가드가 egress-exfil 미봉쇄, (ii) 가드 계약 block-급 미정의, (iii) 4-서브시스템 scope_creep, (iv) 당일 머지된 #104 보안 락 반전을 지적 → **사용자가 SAST 목표 제거로 전량 기각.** qg tool posture를 안 바꾸는 것이 가장 가볍고 안전.
- **오케스트레이터가 SAST를 결정론 사전실행(scout.py 패턴) 후 read-only 텍스트로 리뷰어 전달:** 리뷰가 제시한 Bash-미부여 SAST 대안. → **무의미(moot)** — SAST 목표 자체를 제거했으므로. (미래에 CVE 스캔을 원하면 이 방식이 Bash-arming보다 안전한 출발점.)
- **결정론 scout-driven 선택(모델 아님) / 결정론 selector 스키마:** scout 리스트를 권위로 소비하거나 selector I/O 계약을 명세. → 거부: 게이트 재현성엔 좋으나 lightness상 routing은 모델 신뢰가 default. scout는 힌트, 검증은 floor/transparency/rubric-embed에만.
- **qg 자체 read-only 전문 리뷰어 신설:** upstream persona 복제 = drift·유지비. 재사용이 DRY.
- **fan-out consent 게이트:** → 거부(lightness). 투명성 + authoring hard-review로 대체.
- **code-modernization security-auditor/architecture-critic를 Tier C 에이전트로 편입:** security-reviewer와 중복 + legacy 특화 + Bash 보유. persona의 tool-free 방법론(secret-masking·CWE)만 graft.
- **community 에이전트 hard dep:** 미검증·수동 마켓 — 보안 게이트 부적합.

## 10. Metadata

- **Spec:** 2026-07-19 · qg Review gate 스코프-구동 리뷰어 구성
- **Target plugin:** quality-gates v2.12.0 → **v2.13.0**(minor)
- **Branch:** `feature/qg-scope-driven-reviewers` (base: main @ `9d41efd` = #104 머지 후, 확인됨)
- **관련 원장(memory):** [[project_qg_detector_simplification]] · [[project_law2_agent_tool_surface]] · [[feedback_harness_lightness_trust_model]] · [[feedback_respect_upstream_model_hardcoding]] · [[project_qg_scope_capture]]
- **차용 출처:** `pr-review-toolkit`(전문가·§4 rubric) · `code-review` 플러그인(히스토리/이전-PR 렌즈; 수치 스코어링 제외) · `security-guidance`(scope-signal 팔레트) · `code-modernization:security-auditor`(secret-masking·CWE — tool-free graft만)
- **결정 로그:** 동기=완전 동적 / floor=security+adversarial 고정 / codex=availability-floor / selection=모델 판단·scout 힌트 / 메뉴=pr-review-toolkit5+code-architect+히스토리렌즈 / 신호=docs+산문 팔레트 / fan-out 게이트=없음 / **tool posture=무변경(#104 락 유지)** / **SAST 제거** / **원장 무개정** / **mutation guard 없음** / graft=tool-free(secret-masking+CWE)만
- **후속(구현 단계):** writing-plans → subagent-driven 구현(TDD) → whole-branch 리뷰 → `/qg branch` self-dogfood → 사용자 검토/머지
