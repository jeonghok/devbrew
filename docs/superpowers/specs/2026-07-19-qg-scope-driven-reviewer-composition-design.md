# qg Review gate 스코프-구동 리뷰어 구성 (dynamic reviewer composition)

> **오케스트레이터가 문제 스콥으로 리뷰어를 고른다 — 고정 로스터에서 스코프-구동 구성으로.**
> *리뷰어 선택은 이미 존재하나(scout.py) 고아 상태다. 이 작업은 그것을 오케스트레이터가 실제로 소비하도록 배선하고, 리뷰어를 역할 수행에 필요한 tool로 무장시키되 Law 2를 구조 가드로 유지한다.*

quality-gates Review gate 재설계 스펙. devbrew Law 1(구조 게이트) 준수 — 아래 필수 섹션 모두 채움.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. 설계](#5-설계)
  - [5.1 리뷰어 3-tier 모델](#51-리뷰어-3-tier-모델)
  - [5.2 Selection — 모델 판단 + scout 힌트 + rubric + 팔레트](#52-selection--모델-판단--scout-힌트--rubric--팔레트)
  - [5.3 Tool posture + Law-2 A1 감지 가드](#53-tool-posture--law-2-a1-감지-가드)
  - [5.4 security-reviewer graft (security-auditor 채용)](#54-security-reviewer-graft-security-auditor-채용)
  - [5.5 투명성 + graceful degradation](#55-투명성--graceful-degradation)
  - [5.6 원장 개정 (Law 2 R6 / P3 일반화)](#56-원장-개정-law-2-r6--p3-일반화)
  - [5.7 Security Considerations (잔여 리스크)](#57-security-considerations-잔여-리스크)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [10. Metadata](#10-metadata)

## 1. Context / Why

**문제: 스코프→리뷰어 선택 로직이 3자 drift 상태다.**

- **`scripts/scout.py`** — 결정론 classifier가 이미 `depth` + `phase1_agents[]` + `phase2_agents[]`를 emit(입력: `changed_lines, new_files, config_touched, type_design, test_change`). 즉 "스코프로 리뷰어 고르기"가 이미 코드로 존재한다.
- **`skills/quality-pipeline/SKILL.md` (v2.12.0)** — scout를 실행만 하고 그 추천을 **버린 채** 고정 로스터(security-reviewer + adversarial 항상, code-reviewer/codex는 "가용하면")만 디스패치. 스코프 무관.
- **`README.md` §166 (v1.5.0 재설계)** — scout-driven 다단계 dispatch(Phase 1/2 depth·scope-aware, 전문가 매핑)를 상세히 문서화하나 SKILL이 안 지킴.

따라서 이 작업은 신규 기능이 아니라 **(a) 고아가 된 스코프-구동 선택을 오케스트레이터가 실제로 수행하도록 배선, (b) 3자 정합, (c) 리뷰어를 역할 수행에 필요한 tool로 무장(#104가 회수한 표면을 역할-정당화 하에 부분 복원)하되 Law 2를 구조 가드로 유지**하는 것이다.

**부수 동기:** 현재 fixed 로스터는 (i) 좁은 diff에 무거운 리뷰어를 낭비하고(효율), (ii) 스코프에 맞는 전문 리뷰어(에러핸들링·타입·테스트·docs·아키텍처)를 놓친다(커버리지). 오케스트레이터가 스코프로 더하고 빼면 둘 다 개선된다.

## 2. Goals

1. Review gate가 diff 스코프에 맞는 리뷰어 세트를 **오케스트레이터 판단**으로 구성한다 (더하고 빼기).
2. 고정 보안 floor(security-reviewer + adversarial)는 어떤 스코프에서도 불변 — 모델이 스코프 판단으로 뺄 수 없다.
3. 리뷰어가 **역할을 온전히 수행**하도록 필요한 tool을 부여(`code-modernization:security-auditor` 수준 = `Read, Glob, Grep, Bash`)하되, Law 2는 tool-deny가 아니라 **구조 감지 가드(A1)**로 집행.
4. README / SKILL / scout.py 3자 정합.
5. `security-auditor`의 검증된 방법론(능동 CVE 스캔·read-only-shell 규율·secret 마스킹·CWE 태깅)을 qg security-reviewer에 graft.
6. 원장(Law 2 / P3)을 이 tool posture에 맞게 최소 개정.

## 3. Non-goals

- **Runtime gate 무변경.** runtime-verifier·sandbox·mutation-guard 흐름은 손대지 않는다.
- **scout.py 결정론 로직 삭제 없음** — 힌트 provider로 강등하되 로직·테스트는 유지.
- **새 결정론 classifier 신설 없음** — 선택은 모델 판단(lightness). scout는 힌트만.
- **`code-simplifier` 편입 없음** — writer(코드 수정)이지 리뷰어가 아니다. 메뉴에서 명시 제외.
- **수치 0–100 스코어링 미도입** — `code-review` 플러그인의 0–100 confidence 필터는 devbrew P2 비권장이라 가져오지 않는다. qg security-reviewer의 기존 1–10 confidence calibration은 유지.
- **qg 어느 에이전트에도 `Write`/`Edit`/`MultiEdit`/`Agent` tool 부여 없음** — security-reviewer·adversarial는 `Bash`까지만(security-auditor 수준). write/spawn escape는 안 연다.
- **커뮤니티/미검증 에이전트 hard dependency 없음** — pr-review-toolkit·feature-dev(공식·설치됨)만.
- **외부 에이전트 model override 없음** — 하드코딩 존중.

## 4. Constraints

- **devbrew Law 2** — Writer ≠ Reviewer. 본 작업은 리뷰어에 write-capable tool(Bash)을 주므로 분리를 **구조 가드**로 집행해야 한다(§5.3, §5.6).
- **PR #104 (2026-07-19 머지, `fix(law2)!`)** — 모든 qg 리뷰 에이전트를 fail-closed `tools:` allowlist(`Read, Grep, Glob`)로 잠갔다. 본 작업은 security-reviewer·adversarial를 `+Bash`로 **의도적·부분 복원**한다 — #104를 touch하므로 이 PR은 persona 보안 리뷰 대상이며 CHANGELOG에 명시한다.
- **lightness** ([[feedback_harness_lightness_trust_model]]) — 결정론은 load-bearing(보안·정확성)에만; routing(리뷰어 선택)은 모델 신뢰. fan-out consent 게이트 없음.
- **model 하드코딩 존중** ([[feedback_respect_upstream_model_hardcoding]]) — pr-review-toolkit:code-reviewer=opus, feature-dev:code-architect=sonnet, 전문가=inherit를 그대로 dispatch. wrapper override 금지.
- **버전 bump** — plugin.json 2.12.0 → **2.13.0** (minor, 새 surface). 2.12.0은 #104가 소진.
- **doc convention** — Korean-primary, ≥300줄이면 TOC(본 스펙 포함).

## 5. 설계

### 5.1 리뷰어 3-tier 모델

```
Tier A — Floor (비-trivia면 항상, 결정론)
  ├── security-reviewer   (Phase 1, 병렬)   tools: Read,Glob,Grep,Bash
  └── adversarial         (Phase 1.5)        tools: Read,Glob,Grep,Bash

Tier B — Availability-floor (있으면 무조건, 스코프 무관)
  └── codex-reviewer      (detect_codex 참)  — 모델 다양성 = load-bearing

Tier C — Dynamic (모델이 스코프로 선택, advisory, 외부·write-capable)
  ├── pr-review-toolkit:code-reviewer        (강한 default)  ← git-history/이전-PR 렌즈 수행(Bash 보유)
  ├── pr-review-toolkit:silent-failure-hunter → 에러핸들링 변경
  ├── pr-review-toolkit:type-design-analyzer  → 신규/변경 타입
  ├── pr-review-toolkit:pr-test-analyzer      → 테스트 변경
  ├── pr-review-toolkit:comment-analyzer      → docs/주석 변경
  └── feature-dev:code-architect             → 대형 구조/아키텍처 변경
```

- **"빼기"** = quick-depth diff는 Tier C 최소(예: code-reviewer만), deep diff는 풍부하게.
- **Floor 불변** = A1 floor(security-reviewer+adversarial)는 스코프 판단으로 못 뺀다. 결정론 grep-lock + floor-always mutation 테스트로 보장.
- **git-history/이전-PR 렌즈**([`code-review` 플러그인 차용, 에이전트 아님])는 이미 Bash-무장된 `pr-review-toolkit:code-reviewer`가 프롬프트 힌트로 수행 — regression-prone 파일에 한해 git blame/log/이전 PR 맥락을 가중.

### 5.2 Selection — 모델 판단 + scout 힌트 + rubric + 팔레트

1. **scout 실행(힌트).** `scout.py`가 `depth` + 추천 subset을 emit → 오케스트레이터의 **힌트**(권위 아님). scout 결정론 로직은 유지(Non-goal).
2. **모델이 Tier C 구성.** resolved 스코프(파일·diff) + scout 힌트 + **rubric** + **scope-signal 팔레트**로 판단. 결정론 파서 없음.
3. **rubric (review-pr §4 흡수, 자연어 embed):**
   | 스코프 신호 | 전문가 |
   |---|---|
   | 테스트 파일 변경 | pr-test-analyzer |
   | docs/주석 추가 | comment-analyzer |
   | 에러핸들링 변경 | silent-failure-hunter |
   | 타입 추가/변경 | type-design-analyzer |
   | 대형 구조/아키텍처 | feature-dev:code-architect |
   | 항상(강한 default) | pr-review-toolkit:code-reviewer |
4. **scope-signal 팔레트 (SKILL 산문, `security-guidance` 카테고리 출처):** 역직렬화(pickle/yaml/torch) · 인젝션(eval/exec/os.system/subprocess-shell/child_process) · XSS(innerHTML/dangerouslySetInnerHTML) · crypto(createCipher/AES-ECB) · TLS-verify-disabled · XXE · GHA-workflow-injection · SRI · deps-manifest · migration/schema · public-API surface · 삭제 파일. 모델의 **선택·depth 판단을 풍부하게** — 결정론 아님(산문 체크리스트).
5. **scout `docs_touched` 신호 추가** — scout 입력에 `docs_touched` boolean 추가, docs 변경 시 comment-analyzer를 힌트로. (현재 scout 입력엔 docs 신호가 없어 comment-analyzer가 결정론 힌트로 안 나오던 gap 해소.)
6. **Retry 시 재선택** — 스코프가 바뀌므로 iteration마다 Tier C 재구성.

### 5.3 Tool posture + Law-2 A1 감지 가드

**Tool posture (역할 수행 empower):**
- `security-reviewer`, `adversarial` → `tools: Read, Glob, Grep, Bash` (`code-modernization:security-auditor` 수준). `Write`/`Edit`/`MultiEdit`/`Agent` 부재 유지.
- 외부 Tier C 에이전트 → native 수준으로 dispatch(pr-review-toolkit=inherit-all, feature-dev=Read+Web). override 없음.

**Law-2 A1 감지 가드 (main-tree mutation detection):**
- Bash를 주면 tool-list로는 write/egress를 막을 수 없다(Bash는 superset escape). Law 2는 오직 **구조 가드**로 집행.
- **`scripts/review-mutation-guard.sh` (신규):** Review gate 병렬 팬아웃 **전** working-tree 상태(porcelain + tracked content tree-hash)를 캡처, 팬아웃 **후** 재캡처. 변경 감지 시 non-zero + `mutated_paths` emit. (기존 Runtime fallback working-tree guard 패턴 재사용, SKILL.md 현행 R4 fallback 로직.)
- **SKILL 처리:** dispatch 직후 guard 호출. 변경 감지 → **loud 경고**(user-visible) + evidence 기록 + 해당 iteration findings **suspect** 표기(리뷰어가 리뷰 대상 트리를 변경했으므로). 자동 revert는 안 함(감지가 목적; 사용자가 `git diff`로 확인·revert).
- **격리(sandbox)는 executor 전용** — 실제 product 실행이 목적인 runtime-verifier만 sandbox. 비-실행 리뷰어는 감지로 충분(모델 신뢰). 이 방향은 향후 qg 리뷰 에이전트에도 동일 적용.

### 5.4 security-reviewer graft (security-auditor 채용)

qg security-reviewer는 이미 우월한 부분(untrusted-input discipline, anti-flag 리스트, 1–10 confidence calibration, trusted-artifact custody)을 **유지**한다. security-auditor에서 **추가되는 것만 graft** (replace 아님):

1. **SAST-via-Bash (핵심):** 매니페스트(package.json/requirements.txt/go.mod/…) 변경 시 `npm audit`/`pip-audit` 등 read-only 감사 도구를 **실제 실행**해 CVE 탐지. 출력 verbatim(secret redact) + 수동 findings 병합. → 현행 *"Do not run audit commands / 다운스트림 검증"*을 **능동 CVE 스캔**으로 승격. **Graceful degrade:** 도구·네트워크 부재 시 기존 "매니페스트 변경만 flag"로 fallback + **loud log**.
2. **read-only-shell 규율:** persona에 "shell은 read-only 검사(grep/find/wc/audit)에만; 파일 생성·수정 금지" 명시. Bash를 주는 지금 A1 가드를 persona 층에서 보강 — injection 완화의 정면 대응.
3. **secret redaction 마스킹:** 발견한 credential은 첫 2–4자 + `****`로 마스킹, `file:line` cite, 무엇을 grant하는지 + rotation 권고. Bash로 secret echo 가능해진 지금 필수.
4. **CWE 태깅:** finding YAML에 `cwe: CWE-XXX`(advisory 필드). `synthesize_findings.py`가 pass-through(있으면 표시, 없으면 무시 — backward-compatible).

adversarial도 `read-only-shell` 규율을 persona에 추가(Bash 부여에 대응).

### 5.5 투명성 + graceful degradation

- **투명성 (loud, no silent cap):** 매 iteration 한 줄 — `Review gate iter N — 선택: <리뷰어들>(근거: <스코프 신호>) / 제외: <이유>`. drop·degrade를 조용히 넘기지 않는다. fan-out consent 게이트는 **없음**(lightness); 스프레이는 rubric 자연-바운드 + 이 투명성 + README max fan-out 선언 + authoring-time hard-review로 억제.
- **Graceful degradation:** pr-review-toolkit / feature-dev 미설치 → 해당 Tier C 전문가 unavailable, **floor(A) + codex(B) + 설치된 것**은 계속, **loud log** `specialist <X> unavailable (pr-review-toolkit 미설치) — degraded coverage`.
- **의존 명시:** README prerequisites에 pr-review-toolkit·feature-dev를 Tier C optional dependency로 선언(silent coupling 금지).

### 5.6 원장 개정 (Law 2 R6 / P3 일반화)

새 tool posture(비-실행 리뷰어가 Bash 보유 + 감지 가드)는 현행 Law 2/P3 조문(“쓰기 권한 있는 리뷰어는 리뷰어가 아님; 분리는 tool-deny; default-everything은 P3 위반”)과 충돌한다. lightness상 **새 Law/P# 신설이 아니라 기존 v2.2.0 R6 scoped exception을 일반화**한다.

**개정 조문 (CLAUDE.md Law 2 + `docs/philosophy/devbrew-harness-philosophy.md` line 13-14, P3 line 26-27):**

> Law 2 분리는 tool-deny **또는** tool-표면과 독립적인 **구조 가드**로 집행된다. 가드 강도는 목적에 비례: **(a) executor**(product를 실제 실행 — `runtime-verifier`)는 sandbox + immutable-baseline `git diff` + 무커밋 + 폐기로 **격리(contain)**; **(b) tool-armed 비-실행 리뷰어**(역할상 web-research/git-history/CVE-scan이 필요해 `Read/Grep/Glob`를 넘는 도구를 보유)는 orchestrator가 fan-out 전후 working-tree를 비교하는 **감지(detect)** — mutation → loud + findings-suspect — 로 집행하며, 파괴적 미사용은 capable-model 신뢰에 의존한다. 어느 경우든 리뷰어 verdict와 독립이라 self-approval은 구조적으로 불가능하다. **Default-everything(무감사 전체 tool)은 여전히 금지** — 부여는 역할-정당화 + 가드 하에서만. **untrusted-input을 읽는 리뷰어에게 tool을 줄 땐 injection blast radius를 고려**하고, persona에 read-only-shell 규율을 명시한다.

### 5.7 Security Considerations (잔여 리스크)

- **Bash-무장 리뷰어 + untrusted diff = prompt-injection blast radius.** security-reviewer/adversarial는 attacker-influenced diff를 읽는다. 그 안의 injection이 Bash를 악용하면 exfil/exec 가능. **A1 감지 가드는 쓰기는 잡지만 egress(curl exfil)는 못 잡는다.** 완화: (i) persona read-only-shell 규율(§5.4.2), (ii) 기존 untrusted-input discipline(diff=data), (iii) A1 mutation 감지(쓰기). **egress 잔여 리스크는 capable-model 신뢰로 수용** — 이 PR의 보안 리뷰가 명시적으로 판단한다. 이는 `security-auditor` 자신의 posture(Bash + read-only-shell 규율 + orchestrator read-only 경계)와 동일하다.
- **secret echo:** Bash로 secret을 출력에 노출할 위험 → §5.4.3 masking 규율로 완화.

## 6. Acceptance Criteria

1. **AC1 — Floor 불변:** 비-trivia diff에서 security-reviewer + adversarial는 스코프와 무관하게 항상 디스패치된다. (SKILL grep-lock: 두 `subagent_type` 블록이 무조건 경로에 존재 + floor-always mutation 테스트)
2. **AC2 — codex availability-floor:** `detect_codex` 참이면 스코프 무관 항상 디스패치. (SKILL grep + 기존 codex dispatch invariant 테스트 유지)
3. **AC3 — Tier C 스코프 선택 + rubric embed:** SKILL에 rubric 6항(테스트/docs/에러핸들링/타입/아키텍처/always) 자연어 embed. (body-unique 문구 섹션-스코프 grep-lock)
4. **AC4 — scope-signal 팔레트:** SKILL에 security-guidance 카테고리 팔레트(역직렬화·인젝션·XSS·crypto·TLS·XXE·GHA·SRI·deps·migration·public-API·삭제) 산문 존재. (grep-lock)
5. **AC5 — scout docs_touched:** `scout.py` 입력에 `docs_touched`; docs 변경 입력에서 comment-analyzer가 phase2 힌트에 포함. (scout unit test)
6. **AC6 — fan-out consent 게이트 없음:** SKILL Review dispatch 경로에 fan-out 크기 기반 AskUserQuestion 없음. (negative grep-lock)
7. **AC7 — Tool posture:** `agents/security-reviewer.md`·`agents/adversarial.md` frontmatter `tools:` = 정확히 `Read, Glob, Grep, Bash`(순서 무관 집합); `Write`/`Edit`/`MultiEdit`/`Agent` 부재. (tools-lock 테스트, YAML-우회 봉쇄 포함 — #104 락 패턴 재사용)
8. **AC8 — A1 mutation 감지 가드:** `review-mutation-guard.sh`가 팬아웃 전/후 working-tree 변경을 감지(porcelain + tree-hash), 변경 시 non-zero + `mutated_paths`; SKILL이 dispatch 후 호출하고 변경 시 loud 경고 + findings suspect 처리. (script 테스트: clean→0, 변경 주입→non-zero; SKILL grep)
9. **AC9 — security-reviewer graft:** persona에 (a) SAST-via-Bash + degrade fallback, (b) read-only-shell 규율, (c) secret 마스킹 규율, (d) `cwe` 필드. `synthesize_findings.py`가 `cwe` pass-through(backward-compatible). (persona grep-locks + synthesizer 테스트)
10. **AC10 — 원장 개정 정합:** CLAUDE.md Law 2 + philosophy line 13-14·P3가 일반화된 구조-가드 조문 포함(executor=격리 / 비-실행 리뷰어=감지). (grep-lock: `감지`·`executor`·`비-실행` 동시 존재; CLAUDE.md↔philosophy 정합)
11. **AC11 — Graceful degradation:** pr-review-toolkit/feature-dev 부재 시 floor+codex 계속 + loud log. (SKILL grep + 행동 서술)
12. **AC12 — 투명성:** 매 iter 선택/제외 한 줄 emit. (SKILL grep-lock)
13. **AC13 — 버전 + CHANGELOG:** plugin.json=2.13.0; CHANGELOG `## [2.13.0] — 2026-07-19` with #104 partial-restore 명시. (grep-lock; version은 minor만 핀, patch digit unpin — [[feedback_version_pin_vs_bump_rule]])
14. **AC14 — README §166 정합:** README가 새 3-tier 모델 반영, SKILL과 모순되는 stale phase 리스트 **및 §186 AP9 fan-out 게이트 선언(`len(phase1)+len(phase2)>=4 → AskUserQuestion`) 제거**. (grep: README 리뷰어 목록 ↔ SKILL 정합 + negative grep으로 AP9 fan-out 게이트 선언 부재)
15. **AC15 — 수치 0–100 스코어링 미도입:** `code-review`식 0–100 confidence 필터 부재. qg 기존 1–10 confidence 유지. (negative grep)
16. **AC16 — model 하드코딩 존중:** 외부 에이전트 dispatch 블록에 `model:` override 없음. (grep)
17. **AC17 — Non-goal 가드:** Runtime gate SKILL 섹션(R0–R6) 무변경(diff 없음); qg 어느 리뷰 에이전트에도 `Write`/`Edit`/`Agent` 미부여; code-simplifier `subagent_type` 미등장. (grep-locks)

## 7. Files to Modify

| 파일 | 변경 |
|---|---|
| `skills/quality-pipeline/SKILL.md` | Review gate dispatch 재작성 — 3-tier + scout 힌트 소비 + rubric + scope-signal 팔레트 + 투명성 + A1 감지 가드 호출 + graceful degrade. `allowed-tools`에 `review-mutation-guard.sh` 추가. |
| `agents/security-reviewer.md` | `tools: …, Bash` + security-auditor graft(SAST-via-Bash·read-only-shell·secret 마스킹·cwe 필드) |
| `agents/adversarial.md` | `tools: …, Bash` + read-only-shell 규율 |
| `scripts/scout.py` | `docs_touched` 입력 신호 + docs→comment-analyzer phase2 힌트 |
| `scripts/review-mutation-guard.sh` | **신규** — 팬아웃 전/후 working-tree 감지 |
| `scripts/synthesize_findings.py` | `cwe` 필드 pass-through(backward-compatible) |
| `README.md` | §166 새 모델 정합 + prerequisites에 pr-review-toolkit·feature-dev optional dep + max fan-out 선언 |
| `CLAUDE.md` | Law 2 조문 일반화(§5.6) |
| `docs/philosophy/devbrew-harness-philosophy.md` | Law 2 line 13-14 + P3 line 26-27 일반화 |
| `.claude-plugin/plugin.json` | version → 2.13.0 |
| `CHANGELOG.md` | `## [2.13.0]` — Added/Changed/Security(#104 partial-restore) |
| `tests/` | AC1–AC17 grep-lock/behavior/mutation-teeth 테스트 신규·갱신 |

## 8. Verification Plan

- **정적(grep-lock):** AC1·AC3·AC4·AC6·AC10·AC12·AC14·AC15·AC16·AC17 — 각 락은 **body-unique 문구를 섹션 윈도우에서** grep + **mutation으로 이빨 증명**(헤더-satisfiable·nullglob·후행개행 함정 회피 — [[feedback_lock_passes_but_has_no_teeth]], [[feedback_grep_lock_header_satisfiable]]).
- **tools-lock:** AC7 — security-reviewer·adversarial `tools:` 집합 단언 + YAML-구문 우회(quoted/block-scalar/중복키) 봉쇄(#104 패턴).
- **script:** AC8 — `review-mutation-guard.sh`를 clean tree→exit0, 파일 주입→non-zero로 실측(bash로 실행; NUL/word-split 함정 주의 — [[reference_bash_nul_command_substitution]]).
- **unit:** AC5(scout docs_touched), AC9(synthesize `cwe` pass-through, 없을 때 무해).
- **behavior 서술:** AC2·AC11(graceful degrade loud log).
- **/qg self-dogfood:** 구현 후 브랜치에 `/qg branch` 실행 — codex 모델-다양성 포함 whole-branch 리뷰로 fail-open 재적발(과거 사례상 2단계 통과≠버그없음 — [[project_qg_scope_capture]]).
- **baseline:** 작업 전 pre-existing red 캡처(테스트는 repo root에서 실행 — [[project_qg_pre_existing_test_reds]]).

## 9. Rejected Alternatives

- **결정론 scout-driven 선택(모델 아님):** scout의 phase1/phase2 리스트를 권위로 소비. → 거부: 게이트 재현성엔 좋으나 lightness상 routing은 모델 신뢰가 default. scout는 힌트로 강등.
- **qg 자체 read-only 전문 리뷰어 신설:** 외부 대신 persona 소유. → 거부: upstream persona 복제 = drift·유지비(.ko.md 폐기와 같은 함정). 재사용이 DRY.
- **fan-out consent 게이트(런타임 AskUserQuestion):** 큰 리뷰어 세트에 비용 동의. → 거부: 사용자 지시(lightness). authoring-time hard-review + 투명성으로 대체.
- **B: floor 락 유지 + tool-무거운 역할을 외부 tier에만 배정 / C: 오케스트레이터 inline:** → 거부: 사용자가 A(리뷰어 직접 무장) 선택.
- **A2 sandbox 격리(리뷰어도 sandbox):** → 거부: sandbox는 "실제 실행이 목적"인 executor 전용. 비-실행 리뷰어는 감지로 충분(모델 신뢰).
- **security-reviewer 최소 유지(Bash 미부여):** injection blast radius 축소. → 거부: 사용자가 security-auditor 수준(+Bash) 선택 + graft 채용. 잔여 리스크는 §5.7 + persona 규율로 관리.
- **code-modernization security-auditor/architecture-critic를 Tier C 에이전트로 편입:** → 거부: security-reviewer와 중복 + legacy-uplift 특화. persona 방법론만 graft.
- **community 에이전트(AgentCheck/roborev 등) hard dep:** → 거부: 미검증·수동 마켓. 보안 게이트에 부적합.

## 10. Metadata

- **Spec:** 2026-07-19 · qg Review gate 스코프-구동 리뷰어 구성
- **Target plugin:** quality-gates v2.12.0 → **v2.13.0** (minor)
- **Branch:** `feature/qg-scope-driven-reviewers` (base: main @ #104 머지 후)
- **관련 원장(memory):** [[project_qg_detector_simplification]] · [[project_law2_agent_tool_surface]] · [[feedback_harness_lightness_trust_model]] · [[feedback_respect_upstream_model_hardcoding]] · [[project_qg_untrusted_input_fp_precedent]]
- **차용 출처:** `pr-review-toolkit`(전문가·§4 rubric) · `code-review` 플러그인(히스토리/이전-PR 렌즈, 수치 스코어링 제외) · `security-guidance`(scope-signal 팔레트) · `code-modernization:security-auditor`(SAST·read-only-shell·secret 마스킹·CWE graft)
- **결정 로그:** 동기=완전 동적 / floor=security+adversarial 고정 / codex=availability-floor / selection=모델 판단·scout 힌트 / 메뉴=pr-review-toolkit5+code-architect+히스토리렌즈 / 신호=docs+산문 팔레트 / fan-out 게이트=없음 / tool=security-auditor 수준(Read/Glob/Grep/Bash) / Law2=A1 감지(executor만 sandbox) / 원장=R6·P3 일반화 개정
- **후속(구현 단계):** writing-plans → subagent-driven 구현(TDD) → whole-branch 리뷰 → `/qg branch` self-dogfood → 사용자 검토/머지
