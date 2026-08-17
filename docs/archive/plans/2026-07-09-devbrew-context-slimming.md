# devbrew Context Slimming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew를 구조적 핵심(Three Laws의 코드 집행)으로 환원한다 — 철학 doc을 카탈로그에서 코드 지도로 rewrite, ~80k줄 역사를 태그 봉인 후 삭제, 런타임 컨텍스트 트림, 감량 baseline을 sandbox에서 재검증. 구조적 보안/정확성 게이트(LD8)는 불변 보존.

**Architecture:** 4개 순차 PR(각각 `main`에서 분기, 병합 후 다음 분기 — stacked 금지). PR1 철학 rewrite + 멀티플러그인 cross-ref 정합 / PR2 역사 태그+삭제 / PR3 런타임 트림 / PR4 project-init sandbox-verify. 이 프로젝트는 코드가 아니라 문서 감량이므로, TDD의 "failing test → green"에 대응하는 것은 **결정론적 검증 스크립트**(dangling-ref, body-unique grep, two-direction grep, trigger-eval)다 — 각 편집은 검증을 red로 세운 뒤 green으로 만든다.

**Tech Stack:** Markdown(Korean-primary), bash/python 검증 헬퍼(throwaway, 미커밋), git(annotated tag 복구), spec-distill/quality-gates/project-init 플러그인 테스트 스위트.

## Global Constraints

프로젝트 전역 요구 — 모든 task는 아래를 암묵 포함한다. 값은 설계 doc(`docs/superpowers/specs/2026-07-09-devbrew-context-slimming-design.md`)에서 verbatim.

- **LD8 보존 경계 (HARD)**: strip은 prose/docs/refs/history/런타임컨텍스트 한정. **구조 게이트는 절대 strip 금지** — KEEP-12 원칙, KEEP 6 agent(security-reviewer·adversarial·runtime-verifier·test-scope-validator·spec-reviewer + pr-understanding-builder) + codex 스크립트, Law 2 `Write`/`Edit` tool-deny frontmatter, 결정론 fail-closed 셸 게이트(`check-review-scope.sh`·`check_brief.py`·qg 게이트), spec 5-ritual, kill switch. 모델 성능이 향상돼도 불변.
- **KEEP-12 (구조적 load-bearing, 전체 엔트리 존치)**: P2·P3·P4·P10·P11·P12·P13·P17·P18·P21·P22·AP3.
- **P8·P14 필수 생존**: P8(determinism-economy) 두 방향 모두, P14(compaction-survival) 문장으로 — P14는 CLAUDE.md에 **부재**하므로 philosophy essence에서만 생존(README 3곳 인용 backstop).
- **브랜치 토폴로지**: PR1–PR4 각각 `main`에서 순차 분기(직전 PR merge 후). stacked(미병합 브랜치 위 분기) 금지 — base 삭제 시 dependent CLOSED, 복구 불가.
- **머지 정책**: merge commit. rebase 금지.
- **버전 bump**: README/description 접촉 plugin은 같은 PR에서 SemVer **patch** bump(cache key stale 방지). 현재 버전: spec-distill 0.19.0 / quality-gates 2.10.0 / project-init 1.7.0.
- **활성 산출물 보존 (삭제 금지)**: `docs/superpowers/specs/2026-07-09-devbrew-context-slimming-design.md`, `docs/superpowers/interview/2026-07-08-devbrew-context-slimming-interview.md`, 그리고 이 plan 파일(`docs/superpowers/plans/2026-07-09-devbrew-context-slimming.md`).
- **self-approval 금지 (NG6)**: 각 PR은 Law 2 분리(코드 쓴 턴 ≠ 승인 턴). docs PR도 분리 리뷰 패스 + AC5 결정론 스크립트 backstop. 최종 승인은 사용자.
- **rigor는 리스크 등급 매칭 (P8/LD8)**: 결정론 게이트(/qg·codex·plugin 게이트)는 persona/게이트를 *실제로* 건드리는 변경에만. 순수 docs 감량(PR1·PR2)엔 분리 리뷰 + AC5 스크립트만, /qg·codex 미부과.

---

## Ground Truth (실측 — writing-plans 단계 4-mapper 산출)

이 plan은 아래 실측에 기반한다(추정 아님). 구현 시 라인번호는 drift 가능하므로 **content-anchor 우선**, 라인번호는 보조.

### 철학 doc `docs/philosophy/devbrew-harness-philosophy.md` (938줄) 구조

- `## ` 섹션: §목차(10) · §0 Thesis(65) · §1 Three Laws(80; Law 1/2/3 = 82/90/98) · §2 Principles(110; §2.1=114·§2.2=165·§2.3=251·§2.4=295) · §3 Anti-Corollaries(504) · §4 Primitives(513; §4.0–§4.10=517–640) · §5 Tensions(647; §5.1–§5.6=651–681) · §6 Attribution Map(689) · §7 What This Is NOT(741) · §8 Tagline(754) · §9 Roadmap OQ(766) · §10 How Evolves(783) · §11 Migration Table(796; §11.1=800·§11.2=822·§11.3=857·§11.4=862) · Appendix A(876).
- **KEEP-12 헤더 라인**: P2(126)·P3(169)·P4(195)·P10(217)·P11(227)·P12(145)·P13(381)·P17(401)·P18(419)·P21(452)·P22(466)·AP3(209).
- **STRIP-standalone 헤더(제거 대상, 모두 헤더 실재)**: P16(285)·AP4(349, "LOC as Success Metric")·AP7(315)·AP8(321)·AP14(245, "Unchallenged Consensus", P11 하위).
- **STRIP-redirect(standalone 헤더 없음, 부모 body/§11.1에 흡수 prose로만 존재)**: AP10(→P5; prose 253·263, §11.1 813) · AP11(→P3; prose 167·175, §11.1 814) · AP17(→P14; prose 253·275, §5.6 685, §11.1 820).
- **TRIM 원칙 헤더**: P1(118)·P5(255)·P6(299)·P7(327)·P8(335)·P9(363)·P14(267)·P15(277)·P19(440)·P20(291)·P23(487)·P24(177) / AP1(139, "PRD Theater")·AP2(411)·AP5(159, "Trivia Pipeline Overhead")·AP6(355)·AP9(479)·AP12(375)·AP13(239)·AP15(446)·AP16(434).
- **Apparatus 블록(LD7 제거)**: Appendix A Direct Quotes(876–938) · §6 Attribution Map(689–740) · 흡수된 소스 인벤토리(54–61, separator 63) · §11 Migration Table 전체(796–875, 특히 §11.1=800–821) · §0 Thesis quote bullets(73–76) + thesis blockquote(67) · §5 tension quotes(653·677) · §2 전반 `**Roadmap absorption (C##):**` prose 블록(~137·155·207·225·237·265·289·313·373·409·432 …).
- TOC(§목차) 라인 10 존재 — essence doc이 <300줄이면 삭제(TOC 면제).

### roadmap doc `docs/philosophy/devbrew-roadmap.md` (367줄)

- orphaned(파일명 inbound 링크 0). 섹션: How to Read(14) · Decision Summary C1–C68 테이블(23) · Phase 0 Convention Sweep(102) · Phase 1 qg Reviewer Hardening(121) · 페이즈 2–5(175·227·246·272) · 보류(282) · 거절(301) · 의존성 그래프(310) · 미결 질문(330) · Metadata(362).
- 구체적 near-term 계획 실재(Phase 0-1, Go 후보) but 전부 unbuilt. 결정: **트림**(아래 Task 1.3).

### README P#/AP# 인용 (cross-ref 정합 대상)

- **`plugins/spec-distill/README.md`** "Principles Instantiated"(51–97): 인용 = P2(69)·P3(96)·P5(62·70)·P12(71)·P14(72·97)·P17(64·73)·P18(74)·P21(75)·P22(76)·AP1(88)·AP2(64·89)·AP4(90)·AP9(91)·AP14(92)·AP16(93)·AP17(94). **2개 pre-existing 오라벨**:
  - 라인 88 `**AP1 (Self-approval)**` → self-approval의 정본은 **AP3**(AP1은 "PRD Theater"). **AP3으로 교정**.
  - 라인 90 `**AP4 (Trivia ceremony)**` → trivia-ceremony의 정본은 **AP5**(AP4는 "LOC as Success Metric"; qg/README 라인 14가 "former AP5, trivia ceremony"로 authority). **AP5로 교정**.
- **`plugins/quality-gates/README.md`** "인스턴스화한 원칙"(5–47): 인용 = P5(17)·P8(23·24)·P12(14)·P14(17)·P17(37?45)·P18(16·22·25·46)·P21(26·42·43·44)·P22(15·37)·"former AP5"(14)·"former AP9"(15)·"former AP16"(16·25). qg는 이미 "P# anti-corollary (former AP#)" 형태로 이주 완료 — "former AP#"는 historical prose(live citation 아님)이나 stub 앵커로 resolve.
- **`plugins/project-init/README.md`** "인스턴스화한 원칙"(89–98): **numeric P#/AP# 인용 0건**(name-only Law prose + file-link). 접촉 시에만 편집·bump — 정합 pass는 대개 no-op.

### CLAUDE.md (99줄) — WS1 line 8 + §-anchor 정합, WS4 §Building-a-New-Plugin 이관

- `## ` 섹션: Git Workflow(10)·The Three Laws(19)·Plugin Shape(29; ### 하위 33·39·45·52)·Building a New Plugin(57)·Forbidden Patterns(83)·Doc Conventions(96).
- **라인 8**(WS1): `전체 철학(24개 원칙·14개 anti-pattern·소스 하니스 원문 인용)은 …` + `외부 참조 corpus는 ../reference/에 있으며 필요 시에만 탐색 [reference 탐색 가이드](../reference/REFERENCE_HARVEST.md).` — 둘 다 같은 문단(같은 라인).
- **철학 §-anchor 인용(WS1 re-point 대상)**: §2.1/P12(trivia escape 정의) · §1 Law 2 R6 note · §5.3(수치 스코어링 스탠스) · §4.0(canonical 디렉토리 구조, line 31) · §4.8(state namespace) · §11.1(Forbidden Patterns 카탈로그 포인터).
- **§Building a New Plugin = 57–81줄**(WS4 이관 대상): 헤더(57) + Starter 트리 코드펜스(61–74) + Reference 구현 bullets(78–79, quality-gates/project-init 워크스루) + `**Merge 전:**` 라인(81, `[Plugin Shape](#plugin-shape)` 내부 앵커 포함).

### description (WS4 압축 대상)

- `plugins/project-init/.claude-plugin/plugin.json` (1.7.0): ~62단어 4문장 → 1문장.
- `plugins/quality-gates/.claude-plugin/plugin.json` (2.10.0): ~35단어(접촉 시 압축, 경계선 — Task 3.2 판정).
- `plugins/spec-distill/.claude-plugin/plugin.json` (0.19.0): ~43단어.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` description: **보존 필수 NL 트리거 5개** (trigger-eval) = `/qg` · `"run quality gates"` · `"verify my implementation"` · `"check code quality"` · `"is my PR ready to merge"` (+ arg-form `/qg both|review|runtime`).
- `plugins/spec-distill/skills/conducting-interview/SKILL.md` description: **NL 트리거 목록 없음** — `/interview` 슬래시 커맨드만 + `user-invocable: false`. → 평이한 prose 압축(trigger-eval 불요). (설계 §5.4 가정 교정.)

---

## PR1 — 철학 doc lean rewrite + 멀티플러그인 cross-ref 정합 (WS1)

**브랜치**: `feature/slim-philosophy` (main에서 분기, PR0=이 design+plan 병합 후).
**rigor**: 가드레일 인접(P21) → 분리 리뷰 패스 + AC5 결정론 dangling 스크립트 backstop. README 접촉 plugin별 patch bump. /qg·codex 미부과.
**커버 AC**: AC1·AC2·AC3·AC4·AC5·AC6·AC17(부분).

### Task 1.1: cross-ref 인벤토리 + AC5 dangling 검증 스크립트

이 스크립트가 PR1 전체의 "test"다 — 현재 repo에서 green(모든 인용 resolve), rewrite 후에도 green이어야 한다(dangling 0).

**Files:**
- Create: `$CLAUDE_JOB_DIR/tmp/check-slim-crossrefs.sh` (throwaway 검증 헬퍼 — **미커밋**; 감량 프로젝트에 committed 게이트 추가는 slimming과 모순).

**Interfaces:**
- Produces: `check-slim-crossrefs.sh <philosophy-path>` — CLAUDE.md + 3 plugin README + philosophy body에서 `P\d+`/`AP\d+` 인용을 추출해 slimmed philosophy의 resolving 앵커(full `### P#`/`### AP#` 또는 stub `### AP# → …`)와 대조, dangling 리스트 출력. exit 1 = dangling 존재.

- [ ] **Step 1: 검증 스크립트 작성**

```bash
mkdir -p "$CLAUDE_JOB_DIR/tmp"
cat > "$CLAUDE_JOB_DIR/tmp/check-slim-crossrefs.sh" <<'SCRIPT'
#!/usr/bin/env bash
# AC5: CLAUDE.md + 3 plugin README + philosophy 내 모든 P#/AP# 인용이 slimmed philosophy 앵커로 resolve.
set -euo pipefail
REPO="${1:-/Users/jeonghokim/Downloads/devbrew}"
PHIL="$REPO/docs/philosophy/devbrew-harness-philosophy.md"
CITERS=("$REPO/CLAUDE.md" "$REPO/plugins/spec-distill/README.md" "$REPO/plugins/quality-gates/README.md" "$REPO/plugins/project-init/README.md")

# 1) philosophy가 정의하는 앵커 집합(full 헤더 + stub 앵커). stub 형식: "### AP2 → ..." 도 매칭.
anchors="$(grep -oE '^###[[:space:]]+(P|AP)[0-9]+' "$PHIL" | grep -oE '(P|AP)[0-9]+' | sort -u)"

# 2) citer들이 인용하는 토큰. "former AP#"도 토큰으로 추출(stub이 커버해야 함).
cited="$(grep -rhoE '\b(P|AP)[0-9]+\b' "${CITERS[@]}" | sort -u)"

dangling=""
for tok in $cited; do
  echo "$anchors" | grep -qx "$tok" || dangling="$dangling $tok"
done
if [ -n "$dangling" ]; then
  echo "DANGLING (cited but no philosophy anchor):$dangling"
  exit 1
fi
echo "OK: all cited P#/AP# resolve to a philosophy anchor"
SCRIPT
chmod +x "$CLAUDE_JOB_DIR/tmp/check-slim-crossrefs.sh"
```

- [ ] **Step 2: 현재 repo에서 실행 — baseline green 확인**

Run: `bash "$CLAUDE_JOB_DIR/tmp/check-slim-crossrefs.sh"`
Expected: `OK: all cited P#/AP# resolve to a philosophy anchor` (현재 philosophy는 24 P + 14 AP 헤더 전부 보유 → 모든 인용 resolve). 이것이 rewrite가 깨면 안 되는 invariant다.

- [ ] **Step 3: 인용 토큰 세트 스냅샷 기록**

Run: `grep -rhoE '\b(P|AP)[0-9]+\b' CLAUDE.md plugins/*/README.md | sort -u`
이 목록이 rewrite 후 philosophy가 (full 엔트리 또는 stub 앵커로) 반드시 커버해야 하는 최소 앵커 세트다. **오라벨 2개 주의**: spec-distill/README의 `AP1`(→AP3 교정 예정)·`AP4`(→AP5 교정 예정)는 Task 1.4에서 교정되므로, 교정 후엔 AP1/AP4 인용이 사라진다(AP1은 다른 곳 미인용 → 앵커 불요; AP4도 마찬가지).

### Task 1.2: slimmed essence philosophy doc 저술

938줄 → ~180–200줄. **전체 파일 재작성**(Write). 아래 canonical 구조 + KEEP-12 엔트리(각 코드 cross-ref) + TRIM survivor + stub 앵커. STRIP/apparatus는 새 파일에 애초에 미포함.

**Files:**
- Modify (full rewrite): `docs/philosophy/devbrew-harness-philosophy.md`

**Interfaces:**
- Produces (slimmed doc의 canonical 앵커 — Task 1.4 §-anchor re-point의 타깃):
  - `## The Three Laws` (Law 1/2/3, 각 3–4문장 + Law 2 R6 runtime-verifier scoped-Write 예외 1줄)
  - `## Structural Mechanisms` — KEEP-12 (`### P2`…`### AP3`)
  - `## Load-bearing Meta-Rules` — `### P8`, `### P14`
  - `## Anti-Pattern Anchors` — stub 앵커들

- [ ] **Step 1: KEEP-12 엔트리 형식 확정** — 각 엔트리 = {메커니즘 이름, instantiate하는 Law, ≥1 코드 cross-ref(path), 한 줄 "왜 load-bearing"}. prose 재진술 금지. cross-ref 타깃(구현 시 path 확인, 라인 drift 주의):

  | id | 메커니즘 | Law | 코드 cross-ref |
  |---|---|---|---|
  | P2 | The Ambiguity Gate | 1 | `plugins/spec-distill/scripts/check_brief.py` (5-ritual gate) · `plugins/spec-distill/skills/conducting-interview/SKILL.md` |
  | P3 | Writer/Reviewer Isolation via Tool Scoping | 2 | `plugins/spec-distill/agents/spec-reviewer.md` (Write/Edit deny frontmatter) · `plugins/quality-gates/agents/security-reviewer.md` |
  | P4 | Verification Is Infrastructure | 2 | `plugins/quality-gates/agents/runtime-verifier.md` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md` |
  | P10 | Taste Pluralism | 2×3 | `plugins/quality-gates/agents/` persona 파일군 (bug-escape→persona 편집) |
  | P11 | Cross-Model Adversarial | 2 | `plugins/quality-gates/scripts/run_codex_reviewer.sh` · `plugins/quality-gates/agents/adversarial.md` |
  | P12 | Transparency of Planning | 1 | `plugins/spec-distill/commands/interview.md` (trivia escape) · CLAUDE.md Trivia escape |
  | P13 | Hooks/Skills/Agents Separation | — | `plugins/*/hooks/*.json` (namespace·commutativity·kill switch) |
  | P17 | User Sovereignty | 1 | `plugins/spec-distill/skills/reviewing-spec/SKILL.md` Phase 5 (AskUserQuestion gate) |
  | P18 | Stagnation Is a Failure Mode | — | `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (re-review cap 5) · qg Review fix-loop |
  | P21 | Security & Supply Chain | — | `plugins/quality-gates/scripts/comment-upsert.py` (untrusted-input) · hooks kill switch · persona=보안-민감 |
  | P22 | Cost Awareness | — | SKILL.md frontmatter `cost_class` · fan-out N≥5 hard gate |
  | AP3 | Self-Approval (the #1 anti-pattern) | 2 | P3 tool-deny로 구조 집행 — `plugins/spec-distill/agents/spec-reviewer.md` |

- [ ] **Step 2: TRIM survivor 문장 확정** (AC3·AC5 load-bearing):
  - **P8 (determinism-economy) — 두 방향 모두** (AC3, 토큰 grep 아닌 두 문장):
    1. (제거 방향) "편의·라우팅·NL-의도처럼 구조적 escape hatch가 이미 있는 영역엔 결정론 가드를 쌓지 말고 모델을 신뢰한다."
    2. (부과 방향) "결정론은 보안/정확성 게이트(fail-closed)라는 load-bearing 지점에만 정확히 부과한다."
  - **P14 (compaction-survival) — 문장** (CLAUDE.md 부재): "턴 종료 전 load-bearing 사실은 파일로 기록한다 — 대화에만 있는 사실은 compaction 후 사망한다." (README 3곳 인용의 anchor target.)

- [ ] **Step 3: stub 앵커 목록 확정** (인용된 TRIM 원칙, 삭제 아닌 stub 생존 — Task 1.1 스냅샷 기준):
  - `### AP2 → CLAUDE.md Forbidden Patterns` (Polite Stop)
  - `### AP5 → CLAUDE.md Forbidden Patterns` (Trivia ceremony)
  - `### AP9 → CLAUDE.md Forbidden Patterns` (Subagent spray)
  - `### AP16 → CLAUDE.md Forbidden Patterns` (Unbounded autonomy)
  - `### P5 → CLAUDE.md / Filesystem-as-Memory` (인용되나 CLAUDE.md-중복 규칙 — stub 앵커로 인용 resolve)
  - (P8·P14는 Step 2에서 full 문장 생존이므로 stub 아님. AP1/AP4는 Task 1.4 교정 후 미인용 → 앵커 불요.)

- [ ] **Step 4: 전체 essence doc 작성 (Write)** — 위 구조로. 포함 금지(STRIP-standalone body/header): P16·AP4·AP7·AP8·AP14. 포함 금지(STRIP-redirect prose): AP10/AP11/AP17 흡수 문구 및 §11 Migration Table 전체. 포함 금지(apparatus): Appendix A quotes·§6 Attribution·흡수 소스 인벤토리·§0/§5 quote·`**Roadmap absorption (C##):**` 블록. <300줄이므로 TOC 미포함.

- [ ] **Step 5: AC1 검증 — KEEP-12 + 코드 cross-ref 존재**

Run:
```bash
for p in P2 P3 P4 P10 P11 P12 P13 P17 P18 P21 P22 AP3; do
  grep -qE "^###[[:space:]]+$p\b" docs/philosophy/devbrew-harness-philosophy.md && echo "$p ok" || echo "$p MISSING"
done
grep -cE '`plugins/|`docs/|\.md`|\.sh`|\.py`' docs/philosophy/devbrew-harness-philosophy.md
```
Expected: 12개 전부 `ok`; 코드 cross-ref 패턴 hit ≥ 12.

- [ ] **Step 6: AC2 검증 — STRIP 부재 (body-unique, vacuous 방지)**

Run:
```bash
# STRIP-standalone: 헤더 부재
for p in P16 AP4 AP7 AP8 AP14; do grep -qE "^###[[:space:]]+$p\b" docs/philosophy/devbrew-harness-philosophy.md && echo "$p HEADER STILL PRESENT" || echo "$p header gone"; done
# STRIP-redirect: body-unique 흡수 문구 부재 (header 부재만으론 불충분)
grep -niE '흡수된 안티패턴|구 AP1[017]|Migration Table|Anti-Pattern Disposition' docs/philosophy/devbrew-harness-philosophy.md || echo "redirect prose gone"
```
Expected: 5개 header `gone`; redirect/migration 문구 hit 0.

- [ ] **Step 7: AC3 검증 — P8 두 방향**

Run: `grep -nE '모델을 신뢰|가드를 쌓지' docs/philosophy/devbrew-harness-philosophy.md && grep -nE 'load-bearing 지점에만|fail-closed' docs/philosophy/devbrew-harness-philosophy.md`
Expected: 두 방향 문장 모두 hit(제거 방향 AND 부과 방향).

- [ ] **Step 8: AC4 검증 — apparatus 부재**

Run: `grep -niE 'Appendix A|Attribution Map|흡수된 소스|Direct Quotes' docs/philosophy/devbrew-harness-philosophy.md || echo "apparatus gone"`
Expected: hit 0(`apparatus gone`).

### Task 1.3: roadmap doc 트림

**Files:**
- Modify: `docs/philosophy/devbrew-roadmap.md` (367줄 → ~130줄).

- [ ] **Step 1: 트림** — 제거: Decision Summary C1–C68 테이블(23–101) · 보류 항목(282–300) · 거절 항목(301–309) · 페이즈 의존성 그래프(310–329) · 미결 질문(330–361) · Metadata 흡수 링크(362–367). 존치: How to Read(축약) + Phase 0–5 build-order(102–281, 구체 near-term 계획).

- [ ] **Step 2: 검증**

Run: `wc -l docs/philosophy/devbrew-roadmap.md && grep -cE 'Decision Summary|보류 항목|거절 항목|의존성 그래프' docs/philosophy/devbrew-roadmap.md`
Expected: 줄 수 < 180; disposition-apparatus 섹션 hit 0.

- [ ] **Step 3: dangling C## 재확인** (Task 1.2가 C## 흡수 블록 제거했으므로 philosophy가 roadmap을 인용하지 않아야)

Run: `grep -cE '\bC[0-9]+\b.*roadmap|Roadmap absorption' docs/philosophy/devbrew-harness-philosophy.md || echo "no C## coupling"`
Expected: hit 0.

### Task 1.4: cross-ref 정합 (CLAUDE.md + 3 plugin README) + 오라벨 교정 + bump

**Files:**
- Modify: `CLAUDE.md` (line 8 framing + `../reference` 제거 + §-anchor re-point)
- Modify: `plugins/spec-distill/README.md` (AP1→AP3, AP4→AP5 오라벨 교정 + AP14→P11, AP17→P14 re-point)
- Modify: `plugins/quality-gates/README.md` (접촉 시에만; "former AP#"는 stub이 커버 — 대개 무편집)
- Modify: `plugins/project-init/README.md` (numeric 인용 0 — no-op, 접촉 시에만)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (README 접촉 → 0.19.0→0.19.1)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (README 접촉 시 → 2.10.0→2.10.1)

- [ ] **Step 1: CLAUDE.md 라인 8 정정 (AC6 + apparatus)** — `24개 원칙·14개 anti-pattern·소스 하니스 원문 인용` → `구조 메커니즘 KEEP-12 + 코드 지도`; `외부 참조 corpus는 ../reference/에 있으며 필요 시에만 탐색 [reference 탐색 가이드](../reference/REFERENCE_HARVEST.md).` 문장 **삭제**.

- [ ] **Step 2: CLAUDE.md 철학 §-anchor re-point** (AC5 "철학 §X.Y") — essence doc은 새 구조라 옛 §-앵커 부재. 아래 매핑:

  | 옛 인용 | 위치 맥락 | re-point |
  |---|---|---|
  | `§2.1 / P12` | Trivia escape 정의 | `P12` (§2.1 드롭, P12는 KEEP-12 resolve) |
  | `§1 Law 2 R6 note` | qg scoped-exception | `Law 2` (essence Three Laws의 Law 2 R6 1줄) |
  | `§5.3` | 수치 스코어링 스탠스 | `P2` (Ambiguity Gate) |
  | `§4.0` (line 31) | canonical 디렉토리 구조 | CLAUDE.md 자체 `[Plugin Shape](#plugin-shape)` (자기참조 — 안정) |
  | `§4.8` | state namespace | `P13` |
  | `§11.1` | Forbidden Patterns 카탈로그 포인터 | `Structural Mechanisms` 섹션(§2 대체) — §11.1 드롭 |

- [ ] **Step 3: spec-distill/README 오라벨 2건 교정** — 라인 88 `**AP1 (Self-approval)**` → `**AP3 (Self-approval)**`; 라인 90 `**AP4 (Trivia ceremony)**` → `**AP5 (Trivia ceremony)**`.

- [ ] **Step 4: spec-distill/README STRIP 인용 re-point** — 라인 92 `AP14 (Unchallenged consensus)` → `P11 (Cross-Model Adversarial)` (AP14가 P11 하위였으므로 survivor=P11); 라인 94 `AP17 (Compaction-killed facts)` → `P14 (State Survives Compaction)` (AP17→P14 흡수). instantiation 사실은 보존(삭제 아닌 생존 개념 re-point).

- [ ] **Step 5: plugin.json patch bump** — spec-distill 0.19.0→0.19.1(README 접촉). quality-gates는 README 무편집이면 bump 불요("former AP#"가 stub으로 resolve → 편집 없음 확인 후 결정).

- [ ] **Step 6: AC5 검증 — dangling 0 (load-bearing)**

Run: `bash "$CLAUDE_JOB_DIR/tmp/check-slim-crossrefs.sh"`
Expected: `OK: all cited P#/AP# resolve to a philosophy anchor`. 실패 시 dangling 토큰별로 stub 앵커 추가 또는 인용 re-point.

- [ ] **Step 7: re-point 육안 확인** — re-point된 README 줄이 instantiation 사실(어떤 메커니즘이 어떤 원칙을 구현하는지)을 보존하는지 확인(단순 앵커 스왑이 문장을 무의미하게 만들지 않음). P14 문장이 essence에 생존하는지 재확인(README 3 인용의 target).

### Task 1.5: PR1 통합 검증 + 분리 리뷰 + 커밋 + PR

- [ ] **Step 1: 전체 AC 재실행** — Task 1.2 Step 5–8 + Task 1.3 Step 2–3 + Task 1.4 Step 6 전부 green 재확인. essence doc 줄 수 확인: `wc -l docs/philosophy/devbrew-harness-philosophy.md` (목표 ~180–200).

- [ ] **Step 2: 커밋**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-roadmap.md CLAUDE.md plugins/spec-distill/README.md plugins/spec-distill/.claude-plugin/plugin.json
# (quality-gates README/plugin.json 접촉 시 추가)
git commit -m "docs(slimming): 철학 doc essence rewrite + 멀티플러그인 cross-ref 정합 (WS1)"
```

- [ ] **Step 3: 분리 리뷰** (Law 2 — 코드 쓴 턴 ≠ 승인 턴) — 독립 리뷰어가 AC1–AC6 + dangling 스크립트 결과 + 오라벨 교정 정확성 검증. bug 발견 시 잡았어야 할 지점 수정(Law 3). 리뷰 통과 후 PR 오픈(merge commit).

---

## PR2 — history 아카이브 + 삭제 (WS2)

**브랜치**: `feature/slim-history` (main에서 분기, PR1 병합 후).
**rigor**: 경량 — 활성-카브아웃 삭제 목록 + 태그 복구 확인. 기계적.
**커버 AC**: AC7·AC8·AC9·AC10.
**규모**: 113 files / ~79,946줄 삭제, 활성 3산출물(design+interview+plan) 보존.

### Task 2.1: annotated tag 봉인 + 삭제 + 검증

**Files:**
- Delete: `docs/superpowers/plans/` (전량 — **단 활성 plan `2026-07-09-devbrew-context-slimming.md` 제외**; `notes/` 하위 2파일 포함) · `docs/superpowers/specs/` (기존 52 — **활성 design `2026-07-09-...-design.md` 제외**) · `docs/superpowers/interview/` (stale 4: `2026-06-07-qg-scope-capture-interview.md`·`2026-06-20-qg-llm-security-gap-assessment-interview.md`·`2026-07-05-project-init-git-strategy-faithfulness-interview.md`·`2026-07-05-qg-pr-publish-interview.md` — **활성 `2026-07-08-...-interview.md` 제외**) · `docs/superpowers/handoffs/` (1) · `docs/superpowers/verification-logs/` (1) · `docs/research/` (1) · `docs/qg-defending-code-harness-gap-assessment.md` (1).
- Create: annotated 태그 `pre-slim-archive-2026-07-09` (파일 아님).

- [ ] **Step 1: 삭제 전 tree clean 확인 (AC10)**

Run: `git status --porcelain`
Expected: empty(uncommitted 손실 0 보장).

- [ ] **Step 2: annotated 태그 봉인 (AC7)** — 삭제 커밋 직전. 태그 컷 시점의 HEAD가 전체 history를 보유.

```bash
git tag -a pre-slim-archive-2026-07-09 -m "Pre-slim archive: 113 files / ~79,946 lines of append-only history (plans/specs/interview/handoffs/verification-logs/research) sealed before working-tree deletion. Recover via: git checkout pre-slim-archive-2026-07-09 -- <path>"
```

- [ ] **Step 3: 명시적 제외 삭제 (wholesale glob 금지, AC8/AC9)**

```bash
# plans/ — 활성 plan 제외
find docs/superpowers/plans -type f ! -name '2026-07-09-devbrew-context-slimming.md' -delete
# specs/ — 활성 design 제외
find docs/superpowers/specs -type f ! -name '2026-07-09-devbrew-context-slimming-design.md' -delete
# interview/ — stale 4만 (활성 2026-07-08 제외)
git rm docs/superpowers/interview/2026-06-07-qg-scope-capture-interview.md \
       docs/superpowers/interview/2026-06-20-qg-llm-security-gap-assessment-interview.md \
       docs/superpowers/interview/2026-07-05-project-init-git-strategy-faithfulness-interview.md \
       docs/superpowers/interview/2026-07-05-qg-pr-publish-interview.md
# 전량 디렉토리 + 단일 파일
git rm -r docs/superpowers/handoffs docs/superpowers/verification-logs docs/research
git rm docs/qg-defending-code-harness-gap-assessment.md
# find -delete 대상 stage
git add -A docs/superpowers/plans docs/superpowers/specs
# 이제 빈 디렉토리 제거 (plans/notes 등)
find docs/superpowers/plans -type d -empty -delete 2>/dev/null || true
```
(빈 디렉토리 정책: `plans/`는 활성 plan 잔존 → 비지 않음. `handoffs/`·`verification-logs/`·`research/`는 `git rm -r`로 제거됨. `specs/`·`interview/`는 활성 파일 잔존.)

- [ ] **Step 4: 활성 3산출물 잔존 확인 (AC9)**

Run:
```bash
test -f docs/superpowers/specs/2026-07-09-devbrew-context-slimming-design.md && \
test -f docs/superpowers/interview/2026-07-08-devbrew-context-slimming-interview.md && \
test -f docs/superpowers/plans/2026-07-09-devbrew-context-slimming.md && echo "3 active artifacts survive"
```
Expected: `3 active artifacts survive`.

- [ ] **Step 5: 삭제 표본 부재 + 태그 복구 확인 (AC7/AC8)**

Run:
```bash
git tag -l pre-slim-archive-2026-07-09
git cat-file -e pre-slim-archive-2026-07-09:docs/superpowers/plans/notes/2026-05-27-v0-result.md && echo "tag recovery OK"
test ! -f docs/qg-defending-code-harness-gap-assessment.md && echo "gap-assessment deleted"
```
Expected: 태그 존재 + `tag recovery OK`(삭제 파일이 태그에서 복구 가능) + `gap-assessment deleted`.

- [ ] **Step 6: 커밋 + 분리 리뷰 + PR**

```bash
git commit -m "docs(slimming): ~80k줄 history annotated tag 봉인 후 삭제 (WS2)"
```
독립 리뷰어가 AC7–AC10 + 활성 카브아웃 정확성 확인 후 PR(merge commit).

---

## PR3 — 런타임 컨텍스트 트림 (WS4)

**브랜치**: `feature/slim-runtime` (main에서 분기, PR2 병합 후).
**rigor**: 접촉 plugin별 patch bump. description은 trigger-eval(quality-pipeline만). CLAUDE.md-only 부분 경량 리뷰.
**커버 AC**: AC11·AC12·AC13·AC17.
(MEMORY.md 아카이브 = NG5, repo-external 메모리 도구 액션 — 아래 별도 노트. repo AC 스코프 밖 AC14.)

### Task 3.1: CLAUDE.md §Building-a-New-Plugin → docs/plugin-authoring.md 이관

**Files:**
- Create: `docs/plugin-authoring.md`
- Modify: `CLAUDE.md` (57–81줄 → 한 줄 포인터)

**Interfaces:**
- Consumes: CLAUDE.md 57–81줄 content (Starter 트리 + Reference 구현 워크스루 + Merge 전 라인).
- Produces: `docs/plugin-authoring.md` (이관 내용) + CLAUDE.md 포인터.

- [ ] **Step 1: `docs/plugin-authoring.md` 생성** — CLAUDE.md 57–81줄 content 이관(헤더 `# 플러그인 저술 가이드` + Starter 디렉토리 트리 코드펜스 + quality-gates/project-init Reference 워크스루 bullets + Merge 전 라인). 내부 앵커 `[Plugin Shape](#plugin-shape)`는 CLAUDE.md를 가리키므로 `[Plugin Shape](../CLAUDE.md#plugin-shape)`로 재작성(dangling 방지).

- [ ] **Step 2: CLAUDE.md 57–81줄 → 한 줄 포인터** — `## Building a New Plugin` 헤더 존치, 본문을 다음으로 대체: `새 플러그인 스캐폴딩(Starter 트리 + reference 구현 워크스루)은 [docs/plugin-authoring.md](docs/plugin-authoring.md) 참조.`

- [ ] **Step 3: AC11 검증**

Run:
```bash
test -f docs/plugin-authoring.md && \
grep -q 'plugins/<your-plugin>/' docs/plugin-authoring.md && \
! grep -q 'plugins/<your-plugin>/' CLAUDE.md && \
grep -q 'docs/plugin-authoring.md' CLAUDE.md && echo "AC11 ok"
```
Expected: `AC11 ok` (트리는 신규 파일에만, CLAUDE.md엔 포인터만).

### Task 3.2: description 압축 + patch bump

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json` (description → 1문장; 1.7.0→1.7.1)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (description 압축, NL 트리거 5개 보존; qg 2.10.x→patch)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (bump)
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (description 평이 압축, trigger-eval 불요; spec-distill patch)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (bump — PR1이 이미 0.19.1로 올렸으면 0.19.2)

- [ ] **Step 1: project-init description 1문장 압축 (AC12)** — ~62단어 4문장 → 예: `Initialize git-workflow rules and a project charter via a fact-routing interview, then generate agent-readable docs with hook-based validation.` + `version` 1.7.0→1.7.1.

- [ ] **Step 2: quality-pipeline SKILL description 압축 (AC13 대상)** — verbose 문단 축약하되 **NL 트리거 5개 verbatim 보존**: `/qg`·`"run quality gates"`·`"verify my implementation"`·`"check code quality"`·`"is my PR ready to merge"` (+ `/qg both|review|runtime`). qg plugin.json patch bump.

- [ ] **Step 3: conducting-interview SKILL description 평이 압축** — NL 트리거 목록 없음(`/interview` command + user-invocable:false) → trigger-eval 불요, 순수 서술 축약. spec-distill plugin.json patch bump.

- [ ] **Step 4: AC13 검증 — trigger-eval (quality-pipeline만)**

Run: 드롭 아닌 보존 확인 —
```bash
for phrase in 'run quality gates' 'verify my implementation' 'check code quality' 'is my PR ready to merge'; do
  grep -qF "$phrase" plugins/quality-gates/skills/quality-pipeline/SKILL.md && echo "kept: $phrase" || echo "LOST: $phrase"
done
```
Expected: 4개 전부 `kept`. 추가로 skill-creator trigger eval(가용 시)로 압축된 description이 해당 NL 문구에서 여전히 quality-pipeline로 매칭되는지 결정론 검증(command 우회 아닌 NL 트리거 건강).

- [ ] **Step 5: AC12/AC17 검증 — bump**

Run: `git diff --stat && grep '"version"' plugins/project-init/.claude-plugin/plugin.json plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/.claude-plugin/plugin.json`
Expected: 접촉 plugin 전부 patch bump.

- [ ] **Step 6: 접촉 plugin 테스트 green + 커밋 + 분리 리뷰 + PR**

Run: `cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest discover plugins/spec-distill 2>&1 | tail -5` (spec-distill) + project-init hook tests + qg guard.
```bash
git commit -m "docs(slimming): CLAUDE.md 포인터화 + description 압축 + patch bump (WS4)"
```
분리 리뷰(AC11–AC13·AC17) 통과 후 PR.

---

## PR4 — project-init sandbox-verify (WS5)

**브랜치**: `feature/slim-sandbox-verify` (main에서 분기, PR1·PR2·PR3 병합 후).
**rigor**: sandbox diff 리포트 검증. **실제 repo 파일 무변경** — 이 PR은 검증 리포트만 산출(repo change 없음).
**커버 AC**: AC15·AC16.

### Task 4.1: slimmed baseline sandbox 재실행 + 재유입 diff

**Files:**
- Create: `$CLAUDE_JOB_DIR/tmp/slim-sandbox/` (throwaway repo 사본) + diff 리포트(임시). **실제 repo 파일 무변경 — AGENTS.md 미생성.**

- [ ] **Step 1: project-init 재생성 진입점 확인** — `plugins/project-init/commands/` + `hooks/`를 읽어 스캐폴딩 생성 트리거(command/hook/script) 식별. devbrew는 S2(full-content CLAUDE.md + AGENTS.md 부재) 상태 → 재실행은 결정론적으로 (migration 거절→전체 abort) 또는 (승인→S2a AGENTS-primary flip). 어느 쪽도 실제 repo에 트리거하지 않는다.

- [ ] **Step 2: sandbox 사본 생성** — slimmed baseline(PR1·2·3 병합된 main)을 throwaway 디렉토리로 복사:
```bash
SANDBOX="$CLAUDE_JOB_DIR/tmp/slim-sandbox"
rm -rf "$SANDBOX" && cp -R /Users/jeonghokim/Downloads/devbrew "$SANDBOX"
```

- [ ] **Step 3: sandbox에서 project-init 재실행** — Step 1에서 식별한 진입점을 **sandbox 내에서만** 구동, 재생성물 캡처. migration 거절 경로면 스캐폴딩 0 재생성(재유입 trivially 없음); S2a 경로면 AGENTS.md 생성물을 캡처.

- [ ] **Step 4: AC15 검증 — 재유입 0 + 실제 repo 불변**

Run (실제 repo 대상):
```bash
# 실제 repo: AGENTS.md 미생성 + CLAUDE.md-primary 불변
test ! -f /Users/jeonghokim/Downloads/devbrew/AGENTS.md && echo "real repo: no AGENTS.md (unchanged)"
# sandbox 재생성물에 stripped 내용(카탈로그 재진술·인용 apparatus) 재유입 grep
grep -rniE 'Appendix A|Attribution Map|24개 원칙·14개 anti-pattern|../reference/' "$CLAUDE_JOB_DIR/tmp/slim-sandbox" --include='*.md' | grep -v 'plan\|design\|interview' || echo "no re-introduction"
```
Expected: `real repo: no AGENTS.md (unchanged)` + `no re-introduction`.

- [ ] **Step 5: AC16 검증 — 손-큐레이션 무변경** — sandbox 재실행이 실제 repo의 Three Laws/Forbidden Patterns 본문을 덮어쓰지 않았는지(실제 repo CLAUDE.md 무변경) 확인:

Run: `cd /Users/jeonghokim/Downloads/devbrew && git status --porcelain CLAUDE.md docs/philosophy/`
Expected: empty(실제 repo 손-큐레이션 파일 무변경).

- [ ] **Step 6: 리포트 산출 + PR** — 재유입-방지 diff 리포트 요약(임시). repo change 없으므로 PR는 리포트 검증 게이트(또는 리포트를 PR 설명에 첨부). 분리 리뷰로 AC15/AC16 확인.

---

## 병렬 노트 — MEMORY.md 아카이브 (NG5, repo-external)

repo PR이 **아니다** — 사용자 메모리 도구 액션(경로 `~/.claude/projects/.../memory/`). PR 시퀀스와 병렬 처리. AC14는 repo AC 스코프 밖(메모리 도구/수동 확인).

- always-on 인덱스(`MEMORY.md`)에서 종료-MERGED 프로젝트 로그(spec-distill v0.11–0.19, qg v2.1–2.10)를 링크 아카이브 파일로 이동. 인덱스엔 활성 `feedback_*` + 최신-state만 잔존.
- 검증(AC14): 인덱스에 종료-MERGED 로그 부재 + 아카이브 파일에 존재.

---

## Self-Review (writing-plans 체크리스트)

**1. Spec coverage** — 설계 §7 AC1–AC18 매핑:
- AC1(KEEP-12+cross-ref)=Task 1.2 Step 1/5 · AC2(STRIP 2형태)=1.2 Step 6 · AC3(P8 두 방향)=1.2 Step 2/7 · AC4(apparatus)=1.2 Step 8 · AC5(dangling multi-plugin)=1.1+1.4 Step 6 · AC6(24개 원칙 문구)=1.4 Step 1.
- AC7(태그)=2.1 Step 2/5 · AC8(삭제)=2.1 Step 3/5 · AC9(활성 잔존)=2.1 Step 4 · AC10(clean)=2.1 Step 1.
- AC11(포인터화)=3.1 · AC12(project-init desc)=3.2 Step 1 · AC13(trigger-eval)=3.2 Step 2/4 · AC14(MEMORY)=병렬 노트.
- AC15(sandbox diff+repo 불변)=4.1 Step 4 · AC16(손-큐레이션)=4.1 Step 5.
- AC17(bump)=1.4 Step 5 + 3.2 Step 5 · **AC18(Law 2 리뷰 후 writing-plans)=이미 충족**(design이 spec-reviewer 2라운드 approved 후 이 plan 작성).
- **GAP 없음.** (WS3=descoped/NG7, agent strip은 별도 spec.)

**2. Placeholder scan** — "TBD"/"적절히 처리"/"tests 작성(코드 없이)" 없음. 검증 스크립트는 실제 bash 인라인. cross-ref/이관은 정확 경로+라인. 유일한 discovery 스텝(PR4 Step 1: project-init 진입점 식별)은 검증 assertion이 정확하고 진입점만 sandbox에서 확인 — 검증 workstream 특성상 허용.

**3. Type consistency** — 브랜치명(`feature/slim-*`), 태그명(`pre-slim-archive-2026-07-09`), 활성 3산출물 경로, KEEP-12 목록, NL 트리거 5개가 전 task에서 일관. 오라벨 교정(AP1→AP3, AP4→AP5)과 STRIP re-point(AP14→P11, AP17→P14)가 Task 1.4 + AC5 스크립트에서 정합.
