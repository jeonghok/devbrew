# Long-Doc TOC Convention — Design Spec

> **300줄 이상 docs는 상단에 `## 목차`. Anchor jump가 식별자 lookup을 1번에 푼다.**

**Status:** Proposed
**Author:** @Jeongho-K
**Date:** 2026-05-07
**Branch:** `feature/harness-philosophy`
**Related:** [`docs/philosophy/devbrew-harness-philosophy.md`](../philosophy/devbrew-harness-philosophy.md), [`CLAUDE.md`](../../CLAUDE.md)

---

## 1. Context / Why

devbrew의 philosophy doc은 886줄, 80개 heading, P1–P24/AP1–AP16/§4.0–§4.10/§11.1–§11.4 같은 깊은 식별자 체계를 갖고 있다. 이 식별자들은 plugin spec, README, commit message에서 cite된다 (예: *"Implements P12"*, *"Violates AP3"*, *"See §4.0"*). 즉 식별자는 lookup key — 그러나 현재 문서에 TOC가 없어 cite를 받은 reader가 anchor로 jump 못 하고 grep + scroll로 찾아야 한다.

작은 비용처럼 보이지만 누적된다: 매 cite마다 N초 friction × M reader. 더 중요한 건, friction이 cite 자체를 disincentivize한다 — *"식별자보다 그냥 풀어 쓰자"* 같은 drift가 시작되면 §6 Attribution Map과 P# 번호 체계 전체의 가치가 약화된다.

또한 사용자(@Jeongho-K)가 이 PR의 trigger 메시지에서 일반 원칙을 명시했다: *"docs를 저장하는 경우 구조화 하며 목차가 가장 위에 있어야 함"*. 단발 fix가 아니라 repo 전반의 **doc convention** — codify 필요.

## 2. Goals

1. 긴 doc의 식별자/섹션을 상단 TOC에서 anchor 한 번으로 jump 가능.
2. Repo-wide convention을 CLAUDE.md "When Editing This Repo"에 codify해, 미래 long docs가 자동으로 이 패턴 상속.
3. Convention의 임계값과 형식을 데이터 기반으로 결정 (임의 숫자 회피).
4. **이 PR scope는 한정** — philosophy doc + CLAUDE.md 두 파일만. 다른 long docs는 follow-up.

## 3. Non-Goals

- **다른 long docs(roadmap, restructure plan, p24 plan)에 TOC 일괄 추가** — review surface 폭증 + trivia ceremony 위험. Follow-up PR로 분리.
- **TOC 자동 생성 lint/script** — 설계 단순성 우선 (P8). 손으로 유지, drift 발견 시 reviewer가 catch.
- **Anchor 한국어 → 영어 별칭** — GitHub이 percent-encoded URL로 자동 변환, 추가 매핑 layer 불필요.
- **collapsible `<details>` 형식** — diff에서 가시성 ↓, 모바일 GitHub 깨질 수 있음.

## 4. Constraints

- **Korean-primary 유지** (CLAUDE.md "When Editing This Repo"). 새로 추가되는 컨벤션 문구도 한국어.
- **CLAUDE.md ≤ 200줄 권장** (사전 로드 컨텍스트 앵커). 추가는 한 줄 bullet으로 한정.
- **plugin.json version bump 불필요** — 이 PR은 plugin 코드 안 건드림 (`docs/`와 `CLAUDE.md`만).
- **Backward compat**: TOC 추가는 순수 additive — 기존 §식별자/heading 텍스트 변경 없음. 외부 cite 안 깨짐.

## 5. Design

### 5.1 Philosophy Doc TOC

**삽입 위치**: line 1 제목 + line 3-6 에피그래프 + line 8 anchor 설명 다음, line 10 "흡수된 소스" 블록 **이전**. 즉 새로운 line 9-10 (빈 줄 + `---`) 자리에 TOC 블록을 삽입하고, 그 아래 다시 `---` 구분선 → 흡수된 소스 블록.

이유: 제목 + 에피그래프 + 한 줄 정체성 설명은 doc front matter. TOC는 본문 진입 직전. 정체성 → nav → body가 표준 markdown 패턴.

**Depth**: §X.Y. ~30 entries, 본문 대비 ~4%. 깊이 근거:
- 너무 얕으면 (top-level only) §4.0/§5.3/§11.1 cite를 jump 못 함 — TOC의 핵심 가치 상실.
- 너무 깊으면 (모든 P#/AP#까지) 80+ entries, 새 P# 추가 시 매번 TOC 동기화 부담 (drift 위험).
- §X.Y가 sweet spot — 외부에서 cite되는 모든 두 자리 식별자(§2.1, §4.0, §5.3, §11.1)를 cover, P#/AP# 같은 세 자리는 §X.Y로 narrow 후 in-page grep.

**형식**: 평범한 마크다운 bullet list. GitHub 자동 anchor (lowercase, hyphens, special chars stripped, 한국어는 percent-encoded).

**예시 첫 5줄**:
```markdown
## 목차

- [0. The Thesis](#0-the-thesis)
- [1. The Three Laws](#1-the-three-laws-hierarchical-law-n-overrides-law-n1-on-conflict)
  - [Law 1 — Clarity Before Code](#law-1--clarity-before-code)
  - [Law 2 — Writer/Reviewer Independence](#law-2--writer-and-reviewer-must-never-share-a-pass)
```

전체 entries는 implementation 단계에서 생성.

### 5.2 CLAUDE.md Convention

`## When Editing This Repo` 섹션의 기존 4개 bullet 다음에 한 줄 추가:

```markdown
- **`docs/**.md` 파일이 ~300줄 이상이면 상단(제목+에피그래프 다음)에 `## 목차` 섹션 필수** —
  §X.Y depth로 anchor 링크. 섹션 추가/이름 변경/삭제 시 TOC도 같은 commit에서 동기화 (drift 시 cite-by-anchor 깨짐).
```

**임계값 300줄 근거** — repo의 현 doc 분포:
- 60–156줄: 4개 (git-workflow 가이드 + 작은 spec) — 한 화면, TOC 불필요
- 309–503줄: 3개 (roadmap, design, p24 plan) — TOC 가치 명확
- 886–1232줄: 2개 (philosophy, restructure plan) — TOC 거의 필수

156과 309 사이 큰 갭이 자연스러운 cutoff. 300줄을 "한 번에 스크롤로 훑기 시작 어려워지는 지점"의 proxy로 채택. P8 (Maintain Simplicity) 위반 회피 — 짧은 doc은 면제.

### 5.3 Scope: 이번 PR 한정

**포함**:
1. `docs/philosophy/devbrew-harness-philosophy.md` — TOC 블록 추가
2. `CLAUDE.md` — "When Editing This Repo"에 한 줄 추가
3. `docs/specs/2026-05-07-doc-toc-convention-design.md` — 이 spec 자체

**제외 (follow-up)**:
- `docs/philosophy/devbrew-roadmap.md` (367줄)
- `docs/specs/2026-05-06-philosophy-restructure-design.md` (309줄)
- `docs/specs/2026-05-06-writer-reviewer-pattern-p24-plan.md` (503줄)
- `docs/plans/2026-05-06-philosophy-restructure-plan.md` (1232줄)

이유: 5개 long doc의 TOC를 한 PR에 묶으면 review surface가 4×, "trivia ceremony" 위험. Convention codify가 끝나면 다음 doc 편집 PR이 자연스럽게 준수 (Law 3 — discoverability via index).

### 5.4 산출물 다이어그램

```
PR scope:
┌──────────────────────────────────────────────┐
│ CLAUDE.md                                    │
│   └─ "When Editing This Repo" + 1 bullet    │  ← repo-wide rule
├──────────────────────────────────────────────┤
│ docs/philosophy/devbrew-harness-philosophy   │
│   └─ line ~9: ## 목차 (~36 lines)           │  ← first instance
├──────────────────────────────────────────────┤
│ docs/specs/2026-05-07-…-design.md (this)    │  ← spec artifact
└──────────────────────────────────────────────┘

Future follow-up PRs:
  - roadmap, restructure-design, p24-plan, restructure-plan에
    같은 패턴 적용 (각각 300줄 임계값 충족)
```

## 6. Acceptance Criteria

- [ ] philosophy doc 상단에 `## 목차` 섹션 존재, 위치는 line 8 다음 (anchor 설명) 그리고 "흡수된 소스" 블록 이전.
- [ ] TOC entries는 §X.Y depth, ~30개, GitHub 호환 anchor 링크.
- [ ] 모든 anchor가 실제로 동작 — `grep -nE "^## " /path` 결과와 TOC entries가 1:1 일치.
- [ ] CLAUDE.md "When Editing This Repo" 섹션에 ~300줄 임계값 + §X.Y depth + drift sync 의무를 명시한 한 줄 bullet 추가.
- [ ] 본 spec 파일 `docs/specs/2026-05-07-doc-toc-convention-design.md`로 commit.
- [ ] CLAUDE.md 추가 후 전체 줄 수 ≤ 130 → 145 사이 (사전 로드 anchor 부담 ↓ 유지).
- [ ] Conventional Commits로 commit (`docs(philosophy)` scope). PR title은 "docs(philosophy): add TOC + codify long-doc TOC convention".

## 7. Files to Modify

| 파일 | 변경 | Lines |
|---|---|---|
| `docs/philosophy/devbrew-harness-philosophy.md` | TOC 블록 삽입 (line ~9) | +37 / -0 |
| `CLAUDE.md` | "When Editing This Repo"에 한 줄 추가 | +2 / -0 |
| `docs/specs/2026-05-07-doc-toc-convention-design.md` | 신규 spec | +130 / -0 |

총 +169 / -0.

## 8. Verification Plan

1. **Anchor 동작 검증** (정확성):
   - GitHub PR view에서 TOC entries 클릭 → 해당 heading으로 jump 확인.
   - 로컬: `grep -oE "\(#[a-z0-9-]+\)" docs/philosophy/devbrew-harness-philosophy.md | sort -u`가 TOC와 §식별자 anchor 슬러그를 모두 포함.

2. **Convention text 정합성**:
   - CLAUDE.md 새 bullet이 ~300줄 임계값, §X.Y depth, drift sync 세 조건을 모두 명시하는지 확인.
   - "Korean-primary, English-terms-only" 규칙 위반 없음 (식별자/고유명사만 영어).

3. **Backward compat**:
   - 기존 외부 cite (`§4.0`, `P12`, `AP5`)가 변경 없음 — TOC만 추가, heading 텍스트 변경 없음.
   - `git diff main -- docs/philosophy/devbrew-harness-philosophy.md`가 순수 additive.

4. **Self-instantiation**:
   - 본 spec 파일이 130줄 미만이면 TOC 면제 (300줄 임계값 미달) — 컨벤션과 일치.
   - 본 spec이 만약 300줄 넘으면 자기 자신에 TOC 추가.

## 9. Rejected Alternatives

| 대안 | 거절 이유 |
|---|---|
| Top-level만 (~12 entries) TOC | §4.0/§5.3/§11.1 등 외부 cite 식별자를 jump 못 함. lookup 인프라로서 부족. |
| 모든 P#/AP#까지 (~80 entries) | 본문 대비 10%. 새 P# 추가마다 TOC drift 위험. P8 위반 (oversized index for marginal lookup gain). |
| `<details>` collapsible TOC | GitHub 모바일 view에서 깨질 수 있음. Diff에서 즉시 가시성 ↓. CSS 의존성 추가. |
| 별도 `docs/CONVENTIONS.md` 파일 | 한 줄로 표현 가능한 규칙에 새 파일 = P8 위반 + 사전 로드 anchor에서 한 단계 더 멀어짐 (discoverability ↓, Law 3 위반). |
| 임계값 200줄 | 156줄 spec까지 강제 → 의미 있는 추가 가치 없음 (한 화면 근처). 데이터 cluster gap이 156–309 사이라 300이 자연스러움. |
| 임계값 500줄 | 367줄 roadmap, 309줄 design을 면제 — 둘 다 식별자 lookup 가치 명확. 너무 보수적. |
| 영어 anchor 별칭 | §5.1–5.6 한국어 제목용. GitHub 자동 percent-encoded URL이 이미 동작 — 추가 매핑은 P8 위반. |

## 10. Principles Instantiated

이 spec이 embody하는 철학 원칙:

- **P1 (Specification as Artifact)** — 컨벤션 변경을 spec 문서로 먼저 명문화, chat에서 합의로 끝내지 않음.
- **P5 (Filesystem as Memory)** — TOC를 doc 파일 자체에 inline으로 두어, 다음 reader가 외부 lookup 없이 도달.
- **P6 (Progressive Disclosure)** — 800+ 줄 doc을 §X.Y level overview로 첫 화면에 압축.
- **P8 (Maintain Simplicity, YAGNI)** — 300줄 임계값으로 짧은 doc은 면제, 자동화/별도 파일 회피.
- **Law 3 (Compounding Memory)** — CLAUDE.md에 codify해 미래 long doc들이 자동 상속.

## 11. Metadata

- **Author**: @Jeongho-K
- **Trigger**: User prompt `/superpowers:brainstorming` with args *"docs를 저장하는 경우 구조화 하며 목차가 가장 위에 있어야 함 ... 반영해줘"*
- **Decisions logged**:
  - TOC depth = §X.Y (user choice via AskUserQuestion #1)
  - Convention scope = repo-wide via CLAUDE.md (user choice via AskUserQuestion #2)
  - Insertion = before "흡수된 소스" block (user confirmation)
  - Threshold = 300 lines (user confirmation, data-driven)
  - Scope limit = philosophy + CLAUDE.md only (user confirmation)
  - Anchor = GitHub auto-encoding for Korean (user confirmation)
- **Next step**: Implement per `## 7 Files to Modify`. No `writing-plans` skill needed — change is 2 additive edits + this spec, not a multi-step engineering task.
