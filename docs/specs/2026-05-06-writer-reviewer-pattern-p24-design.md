---
spec: 2026-05-06-writer-reviewer-pattern-p24
author: Jeongho-K
created: 2026-05-06
status: design-pending-user-review
parent: docs/philosophy/devbrew-harness-philosophy.md
round: R5
---

# P24. Writer/Reviewer Pattern — Adding Anthropic's Named Default to Law 2

> **One-line:** Anthropic *Claude Code Best Practices*가 *"Writer/Reviewer pattern"*으로 명시적으로 명명한 dual-session fresh-context critique loop을 일급 원칙 P24로 §2.2 Law 2 cluster에 추가하고, AP3 본문에 self-bias asymmetry의 Anthropic 근거를 grounding한다.

## 1. Context / Why

`docs/philosophy/devbrew-harness-philosophy.md` (R4, commit `3daa324`)는 §2.2 Under Law 2에서 Writer/Reviewer 분리를 5개 원칙(P3 tool scoping / P4 verification / P10 persona pluralism / P11 cross-model adversarial)과 3개 anti-corollary(AP3 self-approval / AP13 both-models-agree / AP14 unchallenged consensus)로 다룬다. 그런데 이 cluster의 *theoretical anchor* — *왜* writer ≠ reviewer가 load-bearing infrastructure인가의 근거 — 가 doc 어디에도 명시적으로 articulate되어 있지 않다. AP3는 *"Law 2로 엄격히 금지"*라고만 말하고 *왜* 인지의 출처는 분산된 채로 남아 있다.

세 가지 발견이 이 PR을 유발했다:

1. **Anthropic이 직접 명명한 패턴이 cite되지 않고 있음.** Anthropic *Claude Code Best Practices* (live page, `code.claude.com/docs/en/best-practices`)는 *"Run multiple Claude sessions"* 섹션에서 정확히 이 패턴을 *"Writer/Reviewer pattern"*으로 명명하고, *"A fresh context improves code review since Claude won't be biased toward code it just wrote"*라는 self-bias asymmetry 근거를 명시적으로 articulate한다. 이 인용이 doc에 들어와 있지 않다.

2. **Anthropic *Building Effective Agents*의 *evaluator-optimizer* 워크플로우가 없음.** *"In the evaluator-optimizer workflow, one LLM call generates a response while another provides evaluation and feedback in a loop"* — GAN 메타포의 일반화된 정식 명칭. P11 (cross-model adversarial)의 더 좁은 사촌이지만 P11과 별개 axis (same-model fresh-context vs cross-model)이고 doc에 cite되지 않음.

3. **R4 restructure spec의 *"No P24"* 결정과의 정합성.** R4 (이 spec의 parent commit, 2026-05-06)는 *lightness meta-principle*에 따라 roadmap 클러스터 C3+C4+C25+C69를 §4.6 + Law 3 corollary로 흡수하고 새 P# 만들지 않았다 — *"No P24"*라고 명시적으로 선언함. R5 (이 PR)는 그 결정을 *override가 아니라 differentiation* 한다: P24의 출처는 R4가 거부한 roadmap 클러스터가 아니라 *별개 일급 출처* (Anthropic Best Practices의 명시적 명명)이고, lightness 정책의 *"truly orthogonal한 패턴만 신규 P#로 escalation"* 절을 충족한다 — Writer/Reviewer pattern의 *workflow shape* axis는 P3 (enforcement)와 P11 (cross-model gate)과 진짜로 직교한다.

이 PR은 그 anchor를 명시적으로 박는다 — 새 일급 P24 + AP3 grounding + Appendix A verbatim 보존.

## 2. Goals

1. §2.2 Law 2 cluster에 **P24. Writer/Reviewer Pattern (Fresh-Context Critique Loop)** 신설 (P3 본문 뒤, P4 앞).
2. AP3 (Self-Approval) 본문에 Anthropic *fresh-context bias* 인용을 grounding으로 append — AP3에 *근거*가 처음으로 doc 내부에 존재하게 함.
3. §6 Attribution Map에 P24 신규 row 추가 + Law 2 row의 supporting source에 Anthropic *Claude Code Best Practices* 보강.
4. Appendix A의 Anthropic Engineering subsection에 두 verbatim 인용 추가 (Writer/Reviewer pattern + evaluator-optimizer workflow).
5. §11.2 Migration Table 업데이트 — *"No P24"* 줄 교체 + P24 row 삽입 + Modification types legend에 *"NEW"* 추가.

## 3. Non-Goals

- **R4 결정의 relitigation 안 함.** AP3 메타데이터 (*"P4의 anti-corollary"*) 그대로 유지 — R4 restructure에서 의도적으로 P4 뒤에 nest됐고 이 PR이 다시 옮기지 않음.
- **새 anti-pattern (AP18) 추가 안 함.** AP3 (Self-Approval)가 이미 *"같은 context의 self-pass"*를 다루고 있고, 새 AP는 의미 70% duplication. 대신 AP3 본문이 P24-AP3 짝 관계를 명시함.
- **CLAUDE.md root 변경 안 함.** Plugin Shape 섹션이나 Forbidden Patterns 리스트는 변경 없음. CLAUDE.md는 *"불변값/체크리스트/포인터만"* 자기 규정에 P24 surface는 부담. 미래 플러그인 저자는 §2.2 Law 2 cluster의 §2.2 자체에서 P24를 발견.
- **Citation style 일괄 modernization 안 함.** 기존 doc은 Anthropic 페이지를 *"Claude Code Best Practices"*로 cite (page H1은 *"Best practices for Claude Code"*). 이 PR은 기존 컨벤션을 따름; 정확한 페이지 H1로 마이그레이션은 별도 PR.
- **Plugin 변경 안 함.** `plugins/quality-gates/`가 이미 P24의 canonical instantiation이고, 별도 README 업데이트 (*"Principles Instantiated"*에 P24 추가) 는 후속 PR. 본 PR은 docs/philosophy 한정.
- **GAN 메타포를 principle 명칭에 안 씀.** P24의 명칭은 Anthropic의 *"Writer/Reviewer pattern"* 그대로. GAN은 사용자가 처음에 쓴 analogy이지만 lock-in되는 명칭은 Anthropic의 직접 어휘.
- **CHANGELOG 변경 안 함.** docs/philosophy/는 plugin이 아니라 plugin.json semver 규정 적용 안 됨.

## 4. Constraints

- **CLAUDE.md *"Korean-primary, English-terms-only"* 정책.** Doc body 한국어, identifier (P24, AP3, Law 2, §2.2, etc.)와 고유명사 (Anthropic, OMC, gstack, Epsilla, etc.)와 verbatim 인용은 영어. 새 P24 본문은 이 정책에 맞게 작성됨.
- **Verbatim 인용 보존.** Anthropic 인용 두 개는 원문 그대로 — gloss 추가 없이, italic + blockquote 형식 (기존 doc 컨벤션). Original text는 `code.claude.com/docs/en/best-practices` 와 `anthropic.com/engineering/building-effective-agents`에서 fetched.
- **§11.2 *"No P24"* 줄 cleanup.** 그 줄은 이제 false claim — 명시적으로 교체 + R4와의 관계 명시. 이전 결정의 audit trail을 지우지 않고 supersedence 형태로 보존.
- **§2.2 header note 업데이트.** Header (line 121)의 nesting 설명에 P24 R5 추가 사실 한 줄 보강 — *"AP3, AP13, AP14가 anti-corollary로 nested. AP11은 P3 body에 흡수 ... P24는 R5 (2026-05-06)에서 Anthropic *Claude Code Best Practices*의 Writer/Reviewer pattern을 직접 출처로 추가됨."*
- **No Korean companion file.** memory feedback *"devbrew docs are Korean-primary single-file"* — `*.ko.md` 동반 파일 안 만듦.
- **No version bump.** docs/philosophy 변경은 plugins/* touch 아니므로 plugin.json bump 규정 적용 안 됨.

## 5. Acceptance Criteria

- [ ] `docs/philosophy/devbrew-harness-philosophy.md` line 121의 §2.2 header note에 P24 R5 추가 사실 한 문장 append.
- [ ] 같은 파일에 **새 §### P24. Writer/Reviewer Pattern (Fresh-Context Critique Loop)** body 삽입 (P3 본문 끝, P4 앞 위치).
- [ ] P24 body가 다음을 모두 포함: (a) P3와의 axis 차이 (enforcement vs workflow shape) 명시, (b) Anthropic *Claude Code Best Practices* 인용 verbatim, (c) Anthropic *Building Effective Agents* 인용 verbatim, (d) 운영 함의 5 bullet (production-ship default / fresh context required / multi-iteration loop / P3와 동시 적용 / P11과 구분), (e) reference implementation으로 `plugins/quality-gates/` 명시.
- [ ] 같은 파일 AP3 본문 (line 149)에 *"A fresh context improves code review..."* 인용 grounding paragraph append + P24-AP3 짝 관계 명시.
- [ ] 같은 파일 §6 Attribution Map (line 626)의 Law 2 row에 *"Anthropic *Claude Code Best Practices* (Writer/Reviewer pattern)"* 추가.
- [ ] §6 Attribution Map의 P23 row 뒤 (line 649)에 P24 신규 row 삽입: *"Writer/Reviewer Pattern (P24) | Anthropic *Claude Code Best Practices* | Anthropic *Building Effective Agents* (evaluator-optimizer workflow)"*.
- [ ] Appendix A의 Anthropic Engineering subsection 끝 (line 860)에 두 verbatim 인용 append.
- [ ] §11.2 Modification types legend에 *"NEW = R5에서 신규 추가"* append.
- [ ] §11.2 table P23 row 뒤에 P24 row 삽입.
- [ ] §11.2 *"No P24"* 줄을 *"P24 added 2026-05-06 R5"* paragraph로 교체 (R4 결정 audit trail 보존).
- [ ] grep으로 *"Writer/Reviewer pattern"* (대소문자 무시)가 doc에 최소 4회 등장 — Section 1 (P24 body), Section 3 (Attribution map 두 곳), Section 4 (Appendix A), Section 5 (§11.2). discoverability check (Law 3 corollary).
- [ ] grep으로 *"fresh context"* 가 doc에 최소 3회 등장 — P24 body, AP3 body, Appendix A 인용.
- [ ] 모든 수정이 Korean-primary single-file에 적용 — `*.ko.md` 추가 안 함.

## 6. Files to Modify

**한 파일만:** `docs/philosophy/devbrew-harness-philosophy.md`

5 edit cluster:

| Edit | 위치 | 형태 |
|---|---|---|
| 1a | line 121 (§2.2 header note) | inline note 한 문장 append |
| 1b | line 130 뒤 (P3 본문 끝) | 새 §### P24 body 삽입 (~22 line) |
| 2  | line 149 뒤 (AP3 본문 끝) | grounding paragraph append (~1 line) |
| 3a | line 626 (§6 Law 2 row) | supporting source 보강 |
| 3b | line 649 뒤 (§6 P23 row 뒤) | P24 신규 row 삽입 |
| 4  | line 860 뒤 (Appendix A 끝) | 두 verbatim 인용 append (~4 line) |
| 5a | line 753 (§11.2 legend) | "NEW" type 추가 |
| 5b | line 779 뒤 (§11.2 table P23 row 뒤) | P24 row 삽입 |
| 5c | line 781 ("No P24" 줄) | R5 supersedence paragraph로 교체 |

총 9 edit (5 conceptual section, 일부는 multi-edit). 모든 수정은 단일 파일 내, 단일 commit에 적합.

## 7. Verification Plan

1. **Mechanical:**
   - `git diff docs/philosophy/devbrew-harness-philosophy.md`이 위 9 edit과 정확히 일치.
   - 다른 파일 수정 없음 (`git status` 깨끗).
   - Markdown lint (heading levels, blockquote 형식) 통과.

2. **Semantic (인용 정확성):**
   - 두 Anthropic 인용을 원문과 verbatim 비교 — `code.claude.com/docs/en/best-practices`의 "Run multiple Claude sessions" 섹션과 `anthropic.com/engineering/building-effective-agents`의 "Evaluator-optimizer workflow" 섹션을 다시 fetch해서 일치 확인.
   - P24 body의 P3/P11과의 axis 차이 진술이 doc 내 P3/P11의 실제 본문과 모순 없음.

3. **Discoverability (Law 3 corollary):**
   - `grep -ic "writer/reviewer pattern" docs/philosophy/devbrew-harness-philosophy.md` ≥ 4.
   - `grep -ic "fresh context" docs/philosophy/devbrew-harness-philosophy.md` ≥ 3.
   - `grep -c "P24" docs/philosophy/devbrew-harness-philosophy.md` ≥ 5 (P24 본문 + AP3 본문 + §6 row + §11.2 legend/row/note).
   - `grep -c "Best Practices" docs/philosophy/devbrew-harness-philosophy.md` ≥ 4 (기존 + 신규).

4. **Cross-reference 검증:**
   - P24 body가 P3, P4, P11, AP3을 cite하고 그 cite가 doc 내 실제 §### header와 일치.
   - §2.2 header note의 *"R5 (2026-05-06)"*가 spec frontmatter의 round/created와 일치.

5. **Adversarial self-review pass:** spec 자체에 대해 P12 (Transparency of Planning) + Law 1 ambiguity gate 적용 — 아래 §10 Self-Review 섹션 결과 inline.

## 8. Rejected Alternatives

- **(A) Light: 새 P# 없이 Law 2 + P3 본문 강화.** 거절 이유 — 사용자가 *"중요한 패턴 중 하나임"*을 명시적으로 표현; Anthropic이 직접 *"Writer/Reviewer pattern"*으로 명명한 일급 패턴은 일급 슬롯에 들어가는 것이 진실에 가깝다. P24의 axis (workflow shape)는 P3 (enforcement) / P11 (cross-model gate)와 직교 — *truly orthogonal* 기준 충족.
- **(B) Medium: P3 안에 named sub-section "Generator-Evaluator Asymmetry" 신설, P# ID는 안 늘림.** 거절 이유 — Anthropic의 정확한 명칭 *"Writer/Reviewer pattern"*과 *"Generator-Evaluator"* 사이에 명명 표류가 생기고, sub-section 형태는 future README *"Principles Instantiated"* citation에 ID가 없어 검색 단편화. 일급 P# slot이 Law 3 compounding substrate를 더 잘 활성화.
- **(C-variant) Heavy: P24 + 새 AP18 "Self-Review Within Writer Context".** 거절 이유 — AP3 (Self-Approval)가 이미 *"같은 context의 self-pass"*를 다루고 있고, AP18은 의미 70% duplication. AP inflation은 §11.1이 막고자 한 패턴 (R4가 14개 AP를 anti-corollary로 nest하고 3개 흡수했음). 대신 AP3 본문에 grounding 추가가 lightness 정합.
- **(C-variant) Heavy: P24 + CLAUDE.md root *Plugin Shape* 새 bullet.** 거절 이유 — CLAUDE.md 자기 규정 *"불변값/체크리스트/포인터만"*. P24 bullet은 *왜* 부분(self-bias asymmetry)을 끌고 들어와야 의미가 통하고, CLAUDE.md 인플레이션 발생. P24의 surface는 §2.2 Law 2 cluster 자체에서 충분 — 미래 플러그인 저자는 거기서 발견.
- **GAN-style framing을 principle 명칭으로 쓰기.** 거절 이유 — 사용자 직접 명시적 거부 (*"GAN-style framing이 아닌 다른 Writer/Reviewer pattern으로 명명"*). GAN은 conceptual analogy로 brainstorming 단계에서 유용했지만 doc-internal 명칭은 Anthropic의 직접 어휘를 따름. Epsilla writeup의 GAN 분석은 §6 attribution map에서 supporting source로도 cite 안 함 (이미 *"Cognitive gearing"* 출처로 한 번 cite됨, 두 번째 cite는 GAN baggage 가져옴).
- **§2.2 header note에 P24 추가 사실 안 적기.** 거절 이유 — R4에서 *"AP3, AP13, AP14가 anti-corollary로 nested. AP11은 P3 body에 흡수"*라는 명시적 audit trail이 header에 있음. R5 추가도 그 audit trail에 들어가야 일관됨.
- **§11.2 *"No P24"* 줄 그냥 삭제.** 거절 이유 — R4 결정의 *근거*(lightness meta-principle, C3+C4+C25+C69 흡수)가 audit value를 가지고 있음. supersedence paragraph로 교체해서 *"왜 R4는 P24를 안 만들었는데 R5는 만들었는가"*의 차이를 명시 — 미래 round가 같은 패턴을 다시 거절/채택할 때 reasoning을 reuse.
- **Building Effective Agents의 *"evaluator-optimizer"*를 빼고 Best Practices만 cite.** 거절 이유 — *"evaluator-optimizer"*는 패턴의 일반화된 Anthropic 어휘 (Best Practices의 *Writer/Reviewer pattern*은 그 specific instantiation). 둘 다 cite하면 P24가 *Anthropic의 두 다른 essay에서 일관되게 나온 패턴*이라는 강한 attribution 강도가 생김. 인용 두 개는 ~30 단어, 비용 미미.

## 9. Metadata

- **Round:** R5 (post-R4 single-source addition; not from roadmap absorption)
- **Source attribution:** Anthropic *Claude Code Best Practices* (primary); Anthropic *Building Effective Agents* (supporting)
- **Lightness check:** lightness meta-principle 충족 — *"truly orthogonal한 패턴만 신규 P#로 escalation"* 조건. P24의 axis (workflow shape, fresh-context critique loop)는 P3 (enforcement, tool scoping)와 P11 (cross-model gate)에 대해 진짜로 직교.
- **Discoverability:** §2.2 header note + §6 attribution map row + §11.2 migration table row + Appendix A — 4개 인덱스 위치에 P24가 동시 등장. 미래 grep recall 보장.
- **Estimated diff:** ~35 added line (P24 body 22 + AP3 1 + §6 1+1 + Appendix A 4 + §11.2 1+1+~5), ~3 modified line (header note + Law 2 row + legend), ~1 removed line (*"No P24"* paragraph).
- **Plugin version impact:** none (plugins/* touch 없음).
- **Korean parity:** N/A — single-file Korean-primary 정책 (no `*.ko.md`).

## 10. Spec Self-Review (inline, pre-user-review)

| Check | Result |
|---|---|
| Placeholder/TBD scan | None |
| Internal consistency (Goals ↔ ACs ↔ Files) | 5 Goals → 11 ACs (각 Goal에 ≥ 1 AC mapping) → 9 edit cluster (단일 파일). 정합. |
| Scope check | 단일 파일, 단일 commit, 9 edit. 적정 implementation plan 1개 분량. |
| Ambiguity check | P24 body wording은 brainstorming Section 1에서 사용자 OK 받음. AP3 grounding wording은 Section 2 OK. Attribution map은 Section 3 OK. Appendix A는 Section 4 OK + retro-fix 통일 OK. §11.2는 Section 5 OK. 모든 wording이 사전 합의됨. |
| R4 spec과의 충돌 | parent commit *"No P24"* 진술 — 본 PR이 *override*가 아니라 *differentiation* 임을 §1 Context와 §11.2 supersedence paragraph 양쪽에서 명시. R4의 lightness 결정은 *roadmap 클러스터 출처*에 한정됐고, R5의 P24는 *별개 일급 출처* (Anthropic 명시적 명명)에서 도착. 정합. |
| Verbatim quote 정확성 | §7 Verification Plan의 step 2가 다시 fetch + diff로 검증. brainstorming 단계 fetch 결과를 spec에 그대로 lock. |
| 명명 정합 (사용자 의도) | P24 명칭 *"Writer/Reviewer Pattern (Fresh-Context Critique Loop)"* — Anthropic 직접 어휘. GAN-style 명칭 사용자 거부 — §8 Rejected Alternatives에 명시. |
| 다른 파일 변경 없음 검증 | §6 Files to Modify가 단일 파일 명시; §3 Non-Goals가 CLAUDE.md/CHANGELOG/plugin/Korean-companion/citation-style-modernization 모두 명시적 out-of-scope. |

**Self-review verdict:** issue 없음. spec은 user review로 진행 가능.

---

## 11. Implementation Hand-off

이 spec이 user review로 approved되면 superpowers:writing-plans skill에 hand off — 9 edit를 step-by-step plan으로 분해하고 verification command (grep checks, diff inspection, Anthropic page re-fetch)를 명시적 step으로 박는다.

Implementation은 단일 commit (Conventional Commits): `docs(philosophy): add P24 Writer/Reviewer Pattern from Anthropic Best Practices (R5)`. branch: `feature/philosophy-p24-writer-reviewer` (kebab-case 2-4 단어 규정).
