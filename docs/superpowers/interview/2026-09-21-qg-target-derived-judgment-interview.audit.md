---
type: interview-audit
payload: 2026-09-21-qg-target-derived-judgment-interview.md
created_at: 2026-09-21
session_id: 7b85458f-471f-4ab4-a5d1-c25346b17764
source: spec-distill conducting-interview v0.57.0
---

# qg — 판정 구조를 대상에서 도출 · Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성 동의: 「대상 모델의 어긋남」 선택 (@S2)
- floor:landscape — closed — 외부 근거 처분: Gerrit 선언 방식 취함 (@S3)
- floor:skepticism — closed — steelman ST1 판정: 보완(refined) (@S4)
- floor:blind_spot — closed — premortem 처분: 둘 채택·둘 OQ 이월 (@S5)
- floor:open_questions — closed — OQ1..OQ14 목록 확인, 그대로 박제 (@S6)
- derived:charter_cochange — closed — 헌장 Law 2 예외가 제거 대상 에이전트를 이름으로 박고 있으나 그 조항에 락이 없다; S5 ②가 이 차원의 결정이다 (@S5)
- derived:enforcement_teardown — open — 명단-리터럴 락의 해체 순서와 대체 이빨이 미정; payload §3 OQ12 로 이월
- derived:verdict_contract — open — 두 판정 어휘의 산출자가 사라지고 clean 의 뜻이 바뀌는데 소비자 처분이 미정; payload §3 OQ8 로 이월
- derived:scope_input_trust — open — 선언의 가변성·충돌과 도출 입력의 작성자 문제; payload §3 OQ6·OQ14 로 이월
- derived:schema_impedance — open — 문서 엔진과 코드 경로의 앵커·처분·심각도 축 불일치 + 세 번째 사본; payload §3 OQ9 로 이월
- derived:trigger_timing — open — 리뷰 발동 시점과 중복(브랜치별 + spec 전체); payload §3 OQ10 로 이월

## 2. Budget

- 질문 라운드: 5 · agent dispatch: 3 · coverage-mapper 1 · codex 실호출: 0 (성공 0)

(agent dispatch 3 = coverage-mapper 1 + steelman-builder 1 + blind-spot-prober 1. codex 는 이 skill 의 경로에 없다 — brief 리뷰 단계의 축이다.)

## 3. Steelman 원문

#### ST1 — Tier A 항상-디스패치 바닥의 «완전» 제거

**dispatch 입력** — goal: S2 · 전제: P1 판정 구조는 대상에서 도출돼야 하고 고정 명단은 그 도출을 막는 장애물이다(S2) · P2 리뷰어 집합은 스코프에서 도출한다(S1) · P3 내부 반대 근거를 본 뒤에도 Tier A 바닥 제거가 확정이다(S1) · P4 척도 넷은 대등하며 충돌 순서는 미정이다(S1) · P5 차등 테스트는 항상 돈다, 예외는 trivia escape 와 kill switch 둘뿐이다(S1) · P6 P3 과 P5 는 비대칭이다(orchestrator 도출) · P7 Tier C 선택은 model-owned 이고 결정론 셀렉터가 없어 바닥까지 내리면 리뷰어 층 보장이 0이 된다(orchestrator 도출) · 제약: S1–S3 원문 전량 · trigger: landscape 모순 — 도출을 채택하되 바닥을 유지하는 독립 외부 사례 둘(Meta RADAR 하이브리드, dev-loops non-overridable floors)

> ```yaml
> case_for_alternative:
>   statement: "Tier A 바닥을 통째로 없애고 security 각도도 adversarial 판정도 스코프 도출에 맡긴다 — 리뷰어 층에 무조건 자리는 0으로 남긴다."
>   strongest: |
>     goal 의 앞절(«판정 구조를 대상에서 도출») 기준으로 고정 명단은 순수 손실이다. PR 단위 벤치마크에서 자동 코드리뷰 기법은 **전부 정밀도 10% 미만**이고, 역할을 나눈 multi-agent(CR-Agent)는 Overall-F1 9.22% 로 단일 에이전트보다 **낮았다**(arXiv 2509.01494). 정보이론 실험도 이득은 «서로 다른 문제를 보는»(ρ=0.05–0.25) 에이전트에서만 나오고 중복 추가는 +14.9→+13.5→+11.2pp 로 체감한다(arXiv 2511.16708) — docs-only·리네임 diff 에 security-reviewer 를 태우는 것은 상보성이 0에 가까운 중복이고, 그 산출물은 신뢰도를 올리는 대신 FP 로 판정 표면을 오염시켜 **clean 의 의미를 흐리는 쪽**으로 작동한다.
>     「바닥 있음」의 대표 사례인 Meta RADAR 조차 성역을 두지 않는다: deterministic codemod 는 Blanket AutoAccept 로 per-diff AI 리뷰를 **통째 우회**한다 — 무조건 자리는 원리가 아니라 분류의 산물이며, 분류가 정교해지면 자리는 사라져도 된다는 실증이다.
>     P4 의 「단순함」에서도 바닥은 계속 비용을 낸다: 이 두 이름은 SKILL 16회 · README 5곳 · CHANGELOG 11곳 · qg 테스트 4파일에 박혀 있고, 그 대부분이 「명단이 고정이다」를 지키기 위해서만 존재한다. 도출이 유일한 규칙이면 이 회계 전체가 사라진다.
> case_for_current:
>   strongest: |
>     같은 goal 의 **뒷절**(«clean 이 그 실행에서 실제로 검증된 것과 일치»)이 바닥을 요구한다. 바닥을 없애면 「그 각도를 고르지 않았다」와 「그 각도에 문제가 없다」가 같은 `clean` 으로 렌더된다 — 일치가 아니라 일치의 반대다. 그리고 도출기의 실측 성적이 나쁘다: LLM-as-judge 현장 측정에서 판정자는 human-confirmed 문제의 **1/4 미만**만 표면화했고(배치별 2/9=22%, 그리고 23건 중 0건), 실패 원인은 지각이 아니라 **라우팅·루브릭**이었다 — 판정자 메모가 실제 결함을 서술한 114 라운드 중 113 이 엉뚱한 라벨로 분류돼 아무 운영 실패도 트리거하지 못했다(arXiv 2606.10315). 「무엇을 부를지」를 모델 라우팅에 맡기는 것이 바로 그 실패 지점이다.
>     dev-loops #2186 은 같은 비용 문제를 비례성으로 풀되 각도는 *"mandatory angles … are always EVALUATED; on a trivial change they are COMBINED under one reviewer, never DROPPED"* 로 두고, 모호하면 fail-closed, **gate·review·security·hook 트리를 만지면 full fan-out 강제**다 — 이번 변경(qg 의 리뷰·게이트 트리 자체)이 정확히 그 denylist 안에 든다.
>     리포 쪽 근거가 가장 날카롭다: `adversarial` 은 리뷰어가 아니라 **유일한 모델 판정 게이트**이고, 그것이 없으면 `synthesize_findings.py` 가 모든 finding 을 `hold("판정자 부재: adversarial 판정 없음")` 로 fail-open keep → `degraded` → *"이 실행은 clean이 아니다"* 를 찍는다. 즉 오늘 배선에서 adversarial 을 스코프로 빼면 **발견이 하나라도 있는 실행은 구조적으로 not-clean** 이 되고, 발견이 0인 실행의 clean 은 「아무도 판정하지 않았다」를 뜻하게 된다. 사용자 자신의 실측도 같은 방향이다 — 리뷰어 5명의 29건을 그대로 고쳤으면 최소 4건이 순감이었고 그 넷을 막은 것이 adversarial 이다.
> premise_refutation:
>   hits: [P1, P3]
>   why: |
>     **P1** — 반증 대상은 P1 의 둘째 문장 *"고정 명단은 그 도출을 막는 장애물이다"* 다(첫 문장 「도출되어야 한다」는 반증 대상이 아니다).
>     ① `plugins/quality-gates/skills/quality-pipeline/SKILL.md` 의 **"Compose and dispatch the reviewer set (scope-driven)"** 단락(≈322–326줄)은 *같은 문장 안에서* "the floor is fixed, codex is an availability-floor, and **Tier C specialists are chosen by the diff scope**" 라고 쓴다 — 오늘 qg 에서 스코프 도출은 바닥 아래서 **이미 제약 없이 작동 중**이다. 바닥이 막는 것은 도출이 아니라 도출의 **축소 방향**뿐이다.
>     ② dev-loops #2186 은 "review proportionality **within** non-overridable floors" 로 둘을 **포함 관계**로 구현한다 — coverage 는 불변, 리뷰어 수만 바닥 안에서 스케일.
>     ③ RADAR 은 "all diffs pass through three layers: safety checks, Diff Risk Score, and the RADAR Review Agent" 로 바닥을 유지한 채 **위험 도출**(DRS 임계)을 라우팅에 쓴다.
>     세 근거가 같은 것을 말한다: 바닥은 도출의 장애물이 아니라 도출 오류의 **하한**이다. 「장애물」이라는 인과 주장은 그대로 서 있지 못한다.
>     **P3** — 반증 대상은 P3 안에 박힌 *사실* 주장 *"security-reviewer 도 adversarial 도 스코프에서 도출된다"* 중 **adversarial 부분**이다(「확정이다」라는 사용자 결정은 근거로 반증되는 종류가 아니다 — 그것은 사용자가 다시 고를 문제다).
>     `plugins/quality-gates/agents/adversarial.md` frontmatter 의 유일한 판단 입력은 `phase1_findings` (`kind: prior_verdict`) 이고 본문은 자신을 *"the single model-based judgment gate in the Review gate"* 로, 뒤의 합성기를 *"a deterministic script with no judgment of its own"* 로 규정한다. `plugins/quality-gates/scripts/synthesize_findings.py` 의 `apply_verdicts()` 는 그 판정이 없으면 `ledger.hold(finding_id(f), "판정자 부재: adversarial 판정 없음")` 로 표시해 fail-open keep 하고, `shared/adjudication/adjudication.py` 의 `blocks()`(=`held > 0` 이면 참) → `_degraded()` → `synthesize_findings.py` 의 `_degrade_block()` 이 *"**이 실행은 clean이 아니다**: 판정 경로가 온전하지 않았다."* 를 낸다.
>     즉 adversarial 의 선택 변수는 **diff 스코프가 아니라 선행 findings 의 존재**다. 「스코프가 요구하지 않으면 부르지 않는다」는 술어는 이 자리에 적용될 때 참/거짓이 아니라 **범주 오류**이고, 실행하면 위 배선이 그것을 판정 degrade 로 되받는다.
> premise_list_challenge: |
>   목록에는 결함 넷이 있다.
>   **(A) 가장 큰 결함 — 목록이 두 자리를 한 종류로 묶는다.** P2·P3 은 `security-reviewer`(생산자 — 입력 = diff, 스코프 술어가 **적용된다**)와 `adversarial`(판정자 — 입력 = 선행 findings, 스코프 술어가 **적용되지 않는다**)을 한 문장에서 같은 축에 올린다. 이 묶음이 살아 있으면 설계는 「생산자 도출」과 「판정자 제거」를 구분하지 못한 채 **하나의 결정으로 통과시킨다**. 전제는 둘로 쪼개져야 한다.
>   **(B) 빠진 전제 — 도출의 입력을 누가 쓰는가.** S3 에서 사용자는 스코프 쪽 신뢰 축을 「브랜치가 선언하고 qg 는 읽는다」로 좁혔다. 그런데 **리뷰어 도출의 입력인 diff 는 피검자가 쓴다.** 사용자 자신이 이 축을 이미 기록해 뒀다 — 「도출 원천이 피검자가 쓰기 가능한 곳이면 도출은 최악이다; 대조(assert-equality)는 *거부만 하고 선택은 못 해서* 안전하다」. 전제 목록에 이 축이 없다.
>   **(C) 빠진 전제 — clean 의 의미는 「수행된 각도의 집합」이다.** P4 의 네 척도에 **공시**(무엇을 하지 않았는지가 판정 표면에 보이는가)가 없다. 오늘 기계는 이미 그 축을 갖고 있다(`$security_review_absent` → Step 4.5 의 verdict-표면 한 줄). 척도에 없으면 설계는 그 기계를 공짜로 버린다.
>   **(D) 제약 내부의 모순.** 같은 constraints 문단이 *"코드 경로의 adversarial 자리를 공유 문서-리뷰 엔진의 출처-제거 재비판으로 **바꾸는** 것을 이번 범위에 넣고"* 라고 확정한다 — 이는 그 자리를 **없앤다**가 아니라 **대체한다**이다. P3 의 "adversarial 도 스코프에서 도출된다"와 한 문단 안에서 충돌한다. 어느 쪽이 사용자의 뜻인지 목록은 말하지 않는다.
>   **덧붙여 P6 은 실제로는 더 날카롭다.** 리뷰 바닥은 오늘 이미 *"every **non-trivia** iteration"* + 사용자 kill switch 라는 **예외 둘**을 갖는다(SKILL 329 · 335–354줄) — 이는 사용자가 P5 에서 테스트 층에 세운 「항상 + trivia escape + kill switch」와 **글자 그대로 같은 형태**다. 따라서 비대칭은 「형태의 차이」가 아니라 「같은 형태를 한 층에서만 인정하는 것」이고, 그것이 의도인지 미검토인지는 여전히 적혀 있지 않다.
>   **닫힌 경로 확인.** 제약이 닫은 것은 「Tier A **명단** 기반 무조건 디스패치」다. 아래 refined 는 그 명단을 되살리지 않는다 — 각도 coverage 의무와 결손 공시는 제약이 언급조차 하지 않은 축이므로 대안으로 낼 수 있다.
> recommendation: refined
> refined_takes: "① 두 **각도**의 coverage 의무(보안 각도 · 판정 각도) — 「누가 수행하는가」는 스코프가 정하되, 작은 스코프에서는 다른 리뷰어 프롬프트에 접어 넣을 수 있고 **조용히 빠질 수는 없다**(dev-loops #2186 의 always EVALUATED / never DROPPED). ② 결손의 verdict-표면 공시 기계 — 이미 있는 `$security_review_absent` 경로를 두 각도로 일반화. ③ 판정자 부재를 clean 으로 렌더하지 않는 배선(`apply_verdicts` 의 hold → degraded → 「이 실행은 clean이 아니다」). ④ 모호하면 fail-closed(스코프 신호를 못 읽으면 각도는 수행한다)."
> refined_drops: "① 「Tier A 명단 2인을 매 iteration **전용 에이전트로** 디스패치」라는 형태 — 무관 스코프에서 전용 2콜은 버린다. ② 「모델이 스코프 판단으로 뺄 수 없다」는 절대 금지(SKILL 329·742줄) — 뺄 수 있게 하되 뺀 사실이 판정에 실린다. ③ `Tier A/B/C` 라는 **명단 기반** 계층 이름과 그에 붙은 명단-리터럴 락 3앵커(`test_review_floor_lock.sh`) — 각도 coverage 락으로 교체한다(교체 없이 삭제만 하면 리뷰어 층의 결정론 보장이 실제로 0이 된다). ④ security-reviewer 를 docs-only·리네임 diff 에 태우는 무조건성."
> ```
>
> (evidence[] 7건 · repo_claims[] 9건의 전문은 아래 「게이트-전 확인」이 항목별로 판정과 함께 재현한다.)

**게이트-전 확인** — repo_claims: `SKILL.md:322` "model-owned routing … the floor is fixed … Tier C specialists are chosen by the diff scope" 확인 · `SKILL.md:331` "run every non-trivia iteration regardless of scope" + kill switch 335–354 확인 · `adversarial.md:11` `phase1_findings`/`kind: prior_verdict` 및 :24 "single model-based judgment gate", :26 "deterministic script with no judgment of its own" 확인 · `synthesize_findings.py:327` `ledger.hold(…, "판정자 부재: adversarial 판정 없음")` 및 :466 "이 실행은 clean이 아니다" 확인 · `adjudication.py:124–134` `blocks()` = `_held` or `_unknown` or `_has_primary_source_failure()` 확인 · `security-reviewer.md:3` finding YAML 스키마 정본이 `adversarial.md` 의 `## Inputs` 에 있다 확인 · `test_review_floor_lock.sh:19` 명단 리터럴 3앵커 mutation-teeth 확인 · `README.md:245` Phase 1 병렬 ≤8 · 총/iteration ≤10 및 cost_class low/medium 확인 · 삭제 스윕 코퍼스 SKILL 16 · README 5 · CHANGELOG 11 확인이되 **테스트 파일 수는 정정** — builder 의 「4파일」은 과소이고 엄격 토큰 8파일 · 개념 별칭 포함 34파일이다(정정 방향이 builder 주장을 강화한다) · 부착 주장: E1(dev-loops) → P1·P2 확인 · E2(RADAR) → P1·P7 확인 · E3(CR 벤치마크) → P4 확인 · E4(submodularity) → P1·P4 확인 · E5(judge routing) → P7 확인 · E6(CleanVul) → P2·P7 확인 · E7(Refute-or-Promote) → P3 확인이되 builder 가 스스로 "본문에서 게이트의 조건성 여부는 이 도구로 확정하지 못했다"고 공시했으므로 그 라벨을 달아 노출 · 근거 7 중 부착 7 · 리포 주장 9 중 확인 9 · 재검토 자격: 열림 2건(P1·P3)

**사용자 선택** — 보완 (S4)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-09-21) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-09-21)

**게이트 이빨 확인 (orchestrator, 사본 대상 mutation).** 첫 시도 통과는 이빨의 증거가 아니므로 사본에 네 축(삭제·변형·추가·불일치)으로 변이를 넣어 9건 전부 RED 를 확인했다. 양성 대조(변이 없는 사본)는 GREEN.

- M1 sentinel 한 줄 삭제 → RED «confirmed 0건인데 명시 sentinel 없음»
- M2 §2 본문 문구를 frontmatter 와 불일치 → RED «bijection B»
- M3 payload §4 에 외부 URL 주입 → RED «payload에 외부 URL 1건»
- M4 payload §6 에 S2 앵커 주입 → RED «payload §6 앵커가 {S1}이 아니다»
- M5 §5 verdict 참조를 ST1→ST9 → RED «bijection A» 양방향 모두 보고
- M6 §5 기각 항목 전부 제거 → RED «bijection A — 판정 없는 steelman»
- M7 audit floor:skepticism 을 open 으로 → RED «status open != closed»
- M8 audit Budget 의 coverage-mapper 계수 삭제 → RED «coverage-mapper <k> line missing»
- M9 floor evidence 의 S 앵커 제거 → RED «evidence cites no S<N> anchor»

## 5. 프로세스 로그

- round 1: path (d) — 진짜 문제 재구성. 경로 (a) 선행 확인으로 「`/qg review` 는 오늘도 된다」·「devbrew 에서 R5a 는 표면 0인데도 dispatch 된다」·「`qg-worktree.sh` 는 샌드박스와 차등 축을 공유한다(seed 정정)」를 «지금 이해»에 실음. coverage-mapper 6차원 전부 admit.
- round 2: path (a) — 웹 landscape sweep 4회(매 검색 직전 kill switch 재확인, 전부 unset). Gerrit 선언 근거의 처분을 물어 landscape 폐쇄.
- round 3: path (b) — steelman ST1. 게이트-전 확인에서 리포 주장 9/9 확인, 전제 충돌 2건 확인으로 재검토 열림. 사용자가 보완 선택.
- round 4: path (b) — blind-spot premortem 처분. orchestrator 가 마켓플레이스 공개 계약·캐시 스키마·캐시 서빙 술어를 직접 확인했고, `doc-recritic` 이 심볼릭 링크가 아니라 **서로 다른 blob 둘**임을 `git ls-files -s` 로 확인해 premortem 주장을 강화. 확정 하나(실패 개수)가 뒤집힘.
- round 5: path (b) — OQ1..OQ14 박제 확인.

### seed 출처 분류 (seed_provenance.py classify)

- audit: ok · user_confirmed 11 · user_unconfirmed 0 · author 40 · mark_invalid 0
- seed: `docs/superpowers/interview/2026-09-21-qg-review-only-sdd-scope-interview.md`
- seed audit: `docs/superpowers/interview/2026-09-21-qg-review-only-sdd-scope-interview.audit.md`

### 경로 충돌 회피 (orchestrator 판단)

payload 경로 공식(`<날짜>-<kebab-topic>-interview.md`)을 seed 와 같은 주제 slug 로 적용하면 **같은 날짜라 seed 와 seed audit 을 덮어쓴다**. 선례(`2026-09-05-interview-depth-redesign` seed ↔ `2026-09-06-…` brief)는 날짜가 달라 충돌을 피한 경우다. R1 이 주제를 재구성했으므로 재구성된 주제로 slug 를 잡아(`qg-target-derived-judgment`) 충돌을 피했고, seed 와 그 audit 은 보존했다. payload §0 에 seed 경로를 명시해 discoverability 를 유지한다.

### P23 뒤집음 — seed 확정 하나

- 원래(S1, 사용자 확인): 「unit 축을 pass/fail 단일 값이 아니라 상태와 «실패 개수» 를 함께 실어, 양쪽이 모두 빨간 unit 에서도 수가 늘었으면 회귀로 잡는다」
- 재결정(S5): 실패 «집합의 차집합»(자리별 원장)
- 근거: (a) 개수는 신원 없는 스칼라라 교환 가능 — 하나 고쳐지고 하나 깨지면 총합이 같아 여전히 PRE_EXISTING, 역방향은 flaky 하나가 없는 회귀를 발명. (b) `run-test-selection.sh detect` 가 이 워크트리에서 내는 두 러너 중 `shell` 은 unit=파일+종료코드뿐이라 per-test 개수가 존재하지 않고, `AXIS` 가 `error`→`F` 로 접어 `(error,error)` 는 개수로도 못 가른다. (c) `baseline-cache.sh` 가 두 방향에서 부딪힌다 — `:42` 의 `NF != 4 { exit 1 }` 본문 검증(열 추가 시 기존 캐시가 통째로 손상 판정 → `exit 4`, 마커 `qg-baseline-cache:v1` 고정이라 버전으로 갈리지 않음)과 `:85` 의 `$3 ~ /^(pass|absent)$/` 서빙 술어(새 정밀도의 입력인 `fail` 행을 원리적으로 안 내줌).

### blind-spot-prober 산출 요지 (payload §5 「위험」의 출처)

숨은 가정 7 · 실패 양식 7, confidence 0.78. orchestrator 가 직접 확인한 것:

- `.claude-plugin/marketplace.json:11` — `"2-gate quality verification pipeline (review + runtime) …"` 확인. `runtime` 이 공개 계약어다.
- `baseline-cache.sh:42` · `:85` — 위 P23 근거 (c) 참조. **정정**: 같은 파일의 주석이 「옛 상태 토큰은 손상이 아니다」라고 적지만 그 관대함은 `$3` 축에만 있고 `NF` 축에는 없다.
- `plugins/spec-distill/agents/doc-recritic.md`(blob `fd8a1b2b`, 3781B) vs `shared/docreview/agents/doc-recritic.md`(blob `068d3092`, 3730B) — **서로 다른 blob, 둘 다 mode 100644**. 심볼릭 링크가 아니라 이미 갈라진 사본 둘이다. seed 의 「심볼릭 링크로 들어와 있다」는 scripts 에만 해당한다. prober 주장보다 나쁜 방향의 확인이다.
- `CLAUDE.md:25` — Law 2 의 scoped exception 이 제거 대상 에이전트를 이름으로 박고 있다. 그런데 `plugins/quality-gates/tests/test_law2_prose.sh` 는 CLAUDE.md 를 앵커하되 **allowlist/denylist 산문(AC1·AC2)만** 본다 — 그 조항에는 아무 락도 없다. (coverage-mapper 가 이 파일을 「집행자」로 들었으나 실측하면 아니다.)

### coverage-mapper 가 차단한 stale lead

심볼릭 링크 수집기 비대칭은 이미 닫혔다. **잔여**: 그 대칭이 «파일 링크에서만» 성립하므로 `plugins/` 아래 **디렉토리 링크**가 생기면 합치 단언이 RED 다. 공유 엔진을 코드 경로로 끌어오는 이번 작업이 디렉토리 링크를 쓰기로 하면 그 자리가 발화한다(payload §5 마지막 위험 항목).

### coverage-mapper 가 가져온 리포 선례 (검증 완료 — verbatim)

`.superpowers/sdd/2026-09-08-docreview-design-doc-site/progress.md:5`
`Baseline(선재 RED 둘, 실패 «줄 수»): harness/test_skill_orchestration_behavior.sh=2 · test_no_write_matcher_hooks_repo.sh=1`
→ 「file 입도 + 실패 개수」 조합이 이 리포에서 이미 손으로 쓰이고 있다. S5 의 재결정은 이 선례를 «개수» 에서 «자리별 원장» 으로 올리는 것이다.

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 2 · 재리뷰 카운트 1 · 추가 라운드 0 — 라운드 게이트 닫힘(`round_gate_needed: false`), 승인 게이트는 열리지 않음(`approval_ready: false` — 미적용 fix 24 · 채택-미관측 4) · 리뷰 완료: 예(`round_reviewed: true` · `unreviewed_reason: none`). **사용자 선택으로 리뷰를 여기서 닫았다**(S12 — 층위 전환).
- 결정: `## 8. 리뷰 결정` — 라운드 1 decide 5(전부 채택) + fix permit 10, 라운드 2 decide 10(채택 4 · 보류 6) + fix permit 24 · 열린 채 남은 항목: 미적용 fix 24건 · 채택-미관측 4건(아래 「앵커 표기」)
- codex: 있음 — 라운드 1·2 각 1회 실호출, 둘 다 성공(rc 0) · 웹: Claude `doc-critic-web`(프로필 `web: true` · `DEVBREW_SPEC_DISTILL_DISABLE_WEB` unset) · codex 켜짐
- 냉독: gap 1건 (G6 — 상태 표기와 본문 서술의 불일치: frontmatter sentinel 「사용자가 전부 잠정으로 판단」 ↔ §2 머리말 「사용자의 판단이 아니다」. 냉독의 문장: 「두 줄이 같은 표시에 서로 다른 뜻을 붙이고 있어서, 이 항목들을 얼마나 단단한 것으로 읽어야 하는지가 저로서는 명확하지 않았습니다」 → payload §2 머리말). G1~G5 는 0건 — 특히 G1(미결을 확정으로 읽음)이 0 이라 19개 OQ 가 열린 것으로 읽혔다. 비-G 가독성 관측 둘: ①C16·C17 번호 구멍에 설명이 없다 ②공유 엔진의 현재 상태 서술이 여러 조각으로 흩어져 한 번에 안 잡힌다. ①은 §2 머리말에 반영, ②는 미반영(§3 OQ9 가 같은 축을 이미 연다). 1차 dispatch 는 계약 위반으로 실패했고 2차 인라인 결과다 — blob rc 3 + §6 요약 탓에 신뢰도 하향.
- degrade: critic:번들 payload 에 audit 파일명 잔존(rc 3 — 출처가 §6 S1 안의 seed frontmatter 라 immutable) · pipeline:라운드 2 재비판 생략(kill switch 아님 — orchestrator 의 사전 선언 멈춤 조건 발동) · readback:1차 dispatch 가 인라인 대신 경로를 넘겨 실패(에이전트 도구 0개) → 2차 인라인 재dispatch, 단 §6 S1 의 Phase 0 저자 문단을 요약해 실음 + blob rc 3

### 라운드 2 에서 관측된 엔진 거동 셋 (텔레메트리)

1. **앵커 표기 fail-open.** 엔진의 정본 섹션 앵커는 `#0-한눈에`·`#2-제약` 인데 탐지 리뷰어가 `#2. 제약`(점·공백)으로 냈고, 엔진이 그 앵커를 문서의 실재 섹션과 대조하지 않고 permit 을 발급했다. `decide` permit 의 `apply_anchors` 는 orchestrator 의 `--scope` 가 아니라 **finding 자신의 `anchor`** 에서 오므로, 그런 permit 은 관측된 변경과 영원히 매칭되지 않는다. 결과: 라운드 1 에서 실제로 적용한 편집 전부가 라운드 2 에서 「채택 후 미적용(expired)」으로 되살아났다(`revived: 9`). 편집 자체는 파일에 있고 구조 게이트가 bijection 을 통과시킨다.
2. **`decide_hold_not_allowed_for_reraise_successor`.** 재상승 승계 finding 은 `hold`(보류)가 거부된다 — 한 번 결정한 자리가 돌아오면 punt 할 수 없고 채택/기각 중 하나여야 한다. 의도된 락으로 보이며, 이번에 층-1 열 중 넷이 여기 걸려 채택으로 갔다.
3. **`--recritic-skipped` 가 사유를 뭉갠다.** `fin.json` advisory 가 「doc-recritic — kill switch」로 적는데 이번 생략은 kill switch 가 아니었다(`DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC` unset 실측). 그리고 degrade 원장의 `COMPONENTS` 닫힌 열거에 `recritic` 이 없어(critic·direction_reviewer·readback·codex·verbatim_coverage·pipeline) 이 항목을 `pipeline` 으로 기록해야 했다.

### 라운드별 요지

- **라운드 1** — 탐지(doc-critic-web) 층1 4 · 층2 9, codex 4, 합 17 익명화 → 재비판 confirm 14 · reject 3 · added 2 · same_as 1쌍. 사용자가 층-1 다섯을 전부 채택. 저자가 §2 를 15→21 항목으로 재작성.
- **라운드 2** — 탐지 층1 5 · 층2 11, codex 4, 합 20 익명화. **재비판 생략**(위 3). 층-1 다섯 중 둘이 라운드 1 수정의 불완전에서 재발 → orchestrator 의 멈춤 조건 발동 → 사용자가 **층위 전환**을 선택(S12): 층-1 을 §2 가 아니라 §3 OQ15~OQ19 로 이월하고 층-2 충실도만 반영. §2 는 21→19 항목(C16·C17 은 Phase 0 저자 조사라 ✎ 프로즈로 강등).

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 (이 작업 뒤의 진짜 문제):
  > "대상 모델의 어긋남 — qg 의 구조가 「부팅되는 웹앱 · 고정 리뷰 관점 · 한 브랜치 PR」을 전제로 굳어 있는데 실제 대상은 그 전제 밖이다. 그래서 가장 비싼 게이트가 아무것도 검증 못 하고, 무관한 리뷰어가 매번 불리고, 한 작업이 판정 단위로 안 잡힌다. 진짜 goal 은 «판정 구조를 대상에서 도출해 clean 이 그 실행에서 실제로 검증된 것과 일치하게 만드는 것» 이고, 네 축은 그 일치를 만드는 대등한 네 손잡이다."

- **S3** ☑ 선택 (Gerrit 근거의 처분 — spec↔브랜치 묶음을 무엇이 담는가):
  > "선언 방식을 취한다 — 브랜치 쪽(SDD 원장의 `Spec:` 줄을 정형화하든 추적되는 새 자리를 두든)에 spec 을 명시적으로 적고 qg 는 그 선언만 읽는다. 추론 사슬이 없으니 «사슬이 끊겨 조용히 덜 리뷰됨» 경로가 구조적으로 사라지고, scope_input_trust 차원이 «그 선언을 누가 쓰고 무엇이 그것을 검증하나» 로 좁혀진다. 미선언 브랜치의 처분(막기/공시)은 설계가 정한다."

- **S4** ☑ 선택 (ST1 steelman 판정):
  > "보완(refined) — 명단은 되살리지 않고 축을 «명단» 에서 «각도» 로 옮긴다. 취함: ① 두 각도(보안·판정)의 coverage 의무 — 누가 수행하는지는 스코프가 정하고 작은 스코프에선 다른 리뷰어 프롬프트에 접어 넣을 수 있되 조용히 빠질 수는 없다 ② 결손의 verdict-표면 공시 기계(`$security_review_absent` 경로를 두 각도로 일반화) ③ 판정자 부재를 clean 으로 렌더하지 않는 배선 ④ 모호하면 fail-closed. 버림: ① 전용 에이전트 2인 매 iteration 디스패치 ② 「모델이 스코프 판단으로 뺄 수 없다」 절대금지 ③ Tier A/B/C 명단 계층명과 명단-리터럴 락 3앵커(각도 coverage 락으로 교체) ④ docs-only·리네임 diff 의 security-reviewer 무조건성."

- **S5** ☑ 선택 (premortem 처분 — 무엇을 이번 범위에 넣는가):
  > "premortem 처분 — 이번 범위에 넣는 것 둘. ① 실패 «개수» 를 버리고 «자리별 원장»(실패 집합의 차집합)으로 간다 — seed 확정 10 을 뒤집는다. ② `marketplace.json` 의 공개 계약 문자열과 CLAUDE.md:25 Law 2 의 runtime-verifier scoped exception 을 같은 사이클에서 함께 움직인다. 고르지 않은 둘(선언의 가변성·충돌 · N=1 일반화)은 §5 위험 + §3 Open Questions 로 이월한다."

- **S6** ☑ 선택 (Open Questions 박제 확정):
  > "그대로 박제한다 — OQ1..OQ14 를 있는 그대로 brief §3 Open Questions 에 싣고 brief 작성으로 간다. 하나도 추측으로 닫지 않고, 각각이 «누가 열었는가» 와 함께 기록된다. 다음 단계는 이 목록을 열린 채로 받아 설계에서 하나씩 닫는다."

- **S7** ☑ 선택 (라운드 리뷰 decide 1/5 — 스택에서 기준선이 무너진다):
  > "채택 — 작업 시작점으로. C10 을 «묶은 브랜치들의 merge-base» 가 아니라 «그 작업이 시작된 지점» 으로 고친다. 스택(main→A→B)에서 merge-base 는 A 가 되어 A 에서 들어온 실패가 기준선 안에 들어가고, 그러면 C8 의 «작업 전체를 한 덩어리로 본다» 가 무너지며 C14 의 자리별 원장으로도 복구되지 않는다."

- **S8** ☑ 선택 (라운드 리뷰 decide 4/5 — 재판정기 치환이 근거 입력을 잘라낸다):
  > "채택 — 엔진 계약 확장. 공유 재비판기에 diff 슬롯과 «이 변경이 도입했는가» 게이트를 더해 코드 경로를 받게 한다. 선재 결함 필터가 보존되지만, 계약을 확장하면 그 엔진의 다른 사본까지 함께 움직여야 하고 «문서만 보고» 라는 프레이밍 맹목성과 충돌하는지도 가려야 한다."

- **S9** ☑ 선택 (라운드 리뷰 decide 3/5 — C4 가 공개 인자 셋을 조용히 지운다):
  > "채택 — 제거를 명시. «게이트 범위를 고르는 공개 인자 셋(리뷰-전용 인자 · 런타임 생략 플래그 · 상류의 게이트 범위 결정)을 없앤다» 를 §2 에 명시해 C4 의 함의를 드러낸다. 비용·시간 축이 여기서 실제로 떨어지고, 공개 인자 제거는 설치본에 breaking 이다."

- **S10** ☑ 선택 (라운드 리뷰 decide 2/5 — 샌드박스를 지우면 HEAD 축이 함께 죽는다):
  > "채택 — 봉인자는 남긴다. 제거 대상은 runtime-verifier 디스패치와 그 판정 경로이고, 커밋 봉인 및 두 축 트리 생성 배관은 차등 테스트의 일부로 남는다. 제거 목록은 verifier 디스패치 · mutation guard · 브라우저 플로우 · spec AC 런타임 검증 · block policy 로 좁혀진다."

- **S11** ☑ 선택 (라운드 리뷰 decide 5/5 — 브랜치는 N 개인데 HEAD 는 하나다):
  > "채택 — 묶음을 한 트리로. N 개 tip 을 합친 트리(머지 결과 또는 octopus)를 HEAD 축으로 삼는다. 합치기가 충돌하면 그 실행은 판정 불가이고, 실제로 머지된 적 없는 트리를 테스트하게 된다는 점은 설계가 다뤄야 한다. Gerrit 선례는 이 방향을 지지하지 않는다 — 그 선례는 제출만 묶고 리뷰는 개별로 둔다."

- **S12** ☑ 선택 (라운드 2 처리 — 층위):
  > "층위를 바꾼다. 층-1 다섯을 §2 에서 푸는 대신 §3 Open Questions 로 옮긴다(OQ15~OQ19). 근거: 리뷰어가 다섯을 전부 「설계가 결정해야 한다」로 끝맺었고, §2 를 구체화할수록 다음 라운드가 다음 충돌을 찾는 반복이 두 라운드로 실증됐다. 함께: 층-2 충실도 항목(원문에서 떨어진 절 복원 · 출처 표기 정정 · 저자 발명 제거)만 고치고 리뷰를 닫는다."

## 7. 확산 원자료

- «gerrit-topic» — https://gerrit-review.googlesource.com/Documentation/cross-repository-changes.html — topic 문자열이 repo·브랜치를 가로질러 묶음을 만들고, 개별 리뷰는 유지하되 전원 submittable 전엔 아무도 submit 되지 않음. 네임스페이스 부재와 저장소 간 원자성 미보장도 같은 자료에.
- «gerrit-topic» — https://gerrit-review.googlesource.com/Documentation/concept-changes.html — change/topic 개념 정의.
- «gerrit-topic» — https://gerrit-review.googlesource.com/Documentation/intro-user.html — topic 충돌 완화책(username 접두) 권고.
- «radar» — https://arxiv.org/html/2605.30208v1 — Meta RADAR. 모든 diff 가 3층(safety checks · Diff Risk Score · Review Agent)을 통과하고, deterministic codemod 는 Blanket AutoAccept 로 우회. 53.5만 diff · revert 약 1/3 · 인시던트 약 1/50.
- «dev-loops-floors» — https://github.com/mfittko/dev-loops/pull/2186 — non-overridable floors 안의 결정론적 review-proportionality. 필수 각도는 always EVALUATED / never DROPPED, gate·review·security·hook 트리는 크기 무관 full fan-out, 모호하면 fail-closed.
- «parasoft-baseline» — https://docs.parasoft.com/display/DTP20212/Test+Impact+Analysis — baseline 은 expected failures 의 집합이며 실패를 거기 넣어 expected 로 분류한다.
- «parasoft-baseline» — https://www.parasoft.com/blog/test-impact-analysis/ — 변경된 코드 블록을 덮는 테스트만 골라 회귀 부재를 확인하는 impact 엔진.
- «merge-base-hardcode» — https://github.com/srikumarimuddana-lab/spinrvm/issues/5409 — coverage-regression-gate 의 merge-base fallback 이 origin/main 을 하드코딩해 staging 대상 실행에서 틀린 base 를 쓴다.
- «cr-benchmark» — https://arxiv.org/html/2509.01494v1 — PR 단위 벤치마크에서 모든 기법의 정밀도 10% 미만, 역할 분할 multi-agent 의 Overall-F1 9.22% 로 단일보다 낮음.
- «submodularity» — https://arxiv.org/abs/2511.16708 — 상호정보 submodularity. 서로 다른 문제를 보는 에이전트 결합만 이득이고(측정 상관 0.05–0.25) 중복 추가는 한계 이득이 체감.
- «judge-routing» — https://arxiv.org/abs/2606.10315 — 프로덕션 LLM-as-judge 가 사람이 확인한 체계적 문제의 1/4 미만만 표면화. 원인은 지각이 아니라 라우팅·루브릭(114 라운드 중 113 오라벨).
- «cleanvul» — https://arxiv.org/html/2411.17274v2 — 기존 취약 데이터셋 노이즈 40–75%, 주원인이 수정 커밋의 모든 변경을 보안 관련으로 라벨한 것.
- «refute-or-promote» — https://arxiv.org/pdf/2604.19049 — 적대적 재비판을 고정밀 결함 발견의 단계 게이트로 두는 방법론. 게이트의 조건성 여부는 이번 조사에서 확정하지 못함.
- «premortem-routing» — https://arxiv.org/pdf/2605.17548 — 위험 기반 라우팅에서 high-risk 를 low-risk 로 오분류하면 엄격 리뷰가 우회되고, 공격자가 라우팅 규칙을 이해해 저위험으로 보이도록 변경을 빚을 수 있다. 권고 완화책이 라우팅 결정 자체를 심사하는 단계.
- «premortem-routing» — https://cheatsheetseries.owasp.org/cheatsheets/Secure_Code_Review_Cheat_Sheet.html — 보안 코드 리뷰의 범위 결정 지침.

## 8. 리뷰 결정

- D1.1 · r1 · adopt · abf668a4#r1.1 · "채택 — 작업 시작점으로" — C10의 공통 조상을 현행 merge-base 의미로 구하면, main→A→B 스택에서 A·B의 기준선은 A가 된다. 따라서 A에서 도입한 실패가 기준선에 포함되어 작업 전체의 회귀로 잡히지 않으며, C14의 집합 차집합으로도 복구되지 않는다. C8의 작업 전체 검증을 위해 기준선을 작업 시작 전 지점으로 정하도록 C10을 재검토할 것인가?
- D1.2 · r1 · adopt · e54043ef#r1.1 · "채택 — 엔진 계약 확장" — C7 의 치환은 재판정기의 **입력**을 바꾼다 — 오늘의 adversarial 은 `filtered_diff` 를 받아 「코드에 실재하는가(Gate A)」와 「이 diff 가 도입했는가(Gate B)」를 판정하는데, 공유 엔진의 doc-recritic 은 입력 슬롯이 document·findings·profile 셋뿐이고 페르소나가 「문서만 보고」 판단하라 지시한다. 코드 경로에서 선재 결함 필터와 오탐 필터를 잃을지, 아니면 공유 엔진 계약을 확장할지(= spec-distill 사본까지 함께 움직임) 결정이 필요하다. OQ9(어휘·사본)·OQ13(생성기 vs 재판정기)과는 다른 축이다 — 여기서 빠지는 것은 판정의 **근거 입력**이다.
- D1.3 · r1 · adopt · e54043ef#r1.2 · "채택 — 제거를 명시" — C4 의 「trivia escape 와 kill switch 말고는 빠질 길이 없다」는 오늘의 사용자-가시 게이트 범위 선택(`/qg review` · `--skip-runtime` · Decision 1 「Review gate only」)을 삭제하는데, §0·§1·§3 어디에도 그 처분이 없다 — 앞 사이클이 명시적으로 도입한 공개 인자를 없애고 모든 비-trivia `/qg` 가 두 워크트리 생성 + 스위트 2회 실행 비용을 지게 할지 결정이 필요하다(OQ4 의 비용·시간 축이 실제로 떨어지는 첫 자리).
- D1.4 · r1 · adopt · e54043ef#r1.3 · "채택 — 봉인자는 남긴다" — C2·C3·C4 가 함께 서려면 「샌드박스만 제거」가 불가능하다 — 차등의 HEAD 축 트리는 샌드박스가 봉인한 커밋 B 없이는 만들어지지 않으므로, 샌드박스 배관을 지우면 봉인자를 새로 만들거나(= 같은 기계의 개명) HEAD 축을 실제 워킹 트리에서 돌려야 한다(현 설계가 근거를 대고 금지한 경로). 어느 쪽을 택할지 결정이 필요하다.
- D1.5 · r1 · adopt · e54043ef#r1.4 · "채택 — 묶음을 한 트리로" — C8·C10 은 브랜치 N개를 한 판정 단위로 묶지만 차등 실행과 리뷰 입력에는 HEAD 가 하나뿐이다 — N개 tip 의 HEAD 축을 무엇으로 삼을지(머지 결과 트리 / 브랜치별 N회 실행 / 최종 브랜치만)가 정해지지 않으면 C3 의 「기준선·HEAD 양쪽 직접 실행」이 성립하지 않는다. 덧붙여 §4 가 C12 의 근거로 취한 gerrit 선례는 리뷰를 묶지 않고 **제출만** 묶는다 — 「한 번의 리뷰」를 그 선례로 지지할 수 없다.
- D2.6 · r2 · hold · 5443440e#r2.1 · "보류 — 층위를 바꾼다: 이 다섯은 설계 결정이므로 §2 확정이 아니라 §3 Open Questions 로 옮긴다" — finding 없이 바뀜: 0. 한눈에 (modified)
- D2.7 · r2 · hold · abf668a4#r2.1 · "보류 — 층위를 바꾼다: 이 다섯은 설계 결정이므로 §2 확정이 아니라 §3 Open Questions 로 옮긴다" — C19 의 «게이트 범위를 고르는 공개 인자 셋» 이 C2·C20 으로 실제 사라지는 공개 표면보다 적다 — `/qg runtime`·`/qg both`·Decision 2·런타임 env 스위치 둘까지 포함해 breaking 목록을 다시 셀지 결정해야 한다.
- D2.8 · r2 · hold · abf668a4#r2.2 · "보류 — 층위를 바꾼다: 이 다섯은 설계 결정이므로 §2 확정이 아니라 §3 Open Questions 로 옮긴다" — C10 의 «작업이 시작된 지점» 을 무엇이 산출하는지가 어디에도 없고 유일한 후보 자리가 피검자가 쓰는 선언이다 — 시작점의 산출자와, 그 값이 앞으로 밀렸을 때 무엇이 그것을 재는지를 결정해야 한다.
- D2.9 · r2 · hold · abf668a4#r2.3 · "보류 — 층위를 바꾼다: 이 다섯은 설계 결정이므로 §2 확정이 아니라 §3 Open Questions 로 옮긴다" — §2 ✎ 와 §4 는 «합친 한 트리» 에 이를 지지하는 외부 선례가 없다고 적지만 Zuul dependent pipeline 과 GitHub merge queue 가 정확히 그 기계이고 «순서» 와 «구성원 실패 처분» 까지 정의한다 — 순서 없는 octopus 대신 순서 있는 speculative 형태를 채택할지 결정해야 한다.
- D2.10 · r2 · hold · abf668a4#r2.4 · "보류 — 층위를 바꾼다: 이 다섯은 설계 결정이므로 §2 확정이 아니라 §3 Open Questions 로 옮긴다" — C14 의 «자리별 원장»(실패 집합의 차집합)은 테스트 단위 신원을 요구하는데 리포의 실행 층은 러너별 출력 파서를 의도적으로 두지 않아 unit 당 종료 코드 한 값만 낸다 — 파서 층을 새로 만들지(어댑터 9종 한 코드라는 전제가 깨진다), 아니면 C14 를 신원을 낼 수 있는 어댑터로 한정할지 결정해야 한다.
- D2.11 · r2 · hold · abf668a4#r2.5 · "보류 — 층위를 바꾼다: 이 다섯은 설계 결정이므로 §2 확정이 아니라 §3 Open Questions 로 옮긴다" — C2 는 「샌드박스 생성·폐기」를 제거 목록에 두고 C20 은 「커밋 봉인·두 축 트리 생성 배관은 남는다」고 하는데 리포에서 그 둘은 같은 한 서브커맨드다 — 봉인을 남기면서 샌드박스 생성을 지울 수 있는지, 아니면 워크트리 없이 커밋 B 를 만드는 새 봉인자를 설계가 만들지 결정해야 한다.
- D2.12 · r2 · adopt · e54043ef#r2.1 · "채택 — 층위를 바꾼다: 결정은 유지하되 §2 는 잔여 질문을 이름만 남기고 실제 해소는 §3 Open Questions 로 넘긴다 (사용자 선택)" · supersedes D1.2 — 채택 후 미적용(expired): C7 의 치환은 재판정기의 **입력**을 바꾼다 — 오늘의 adversarial 은 `filtered_diff` 를 받아 「코드에 실재하는가(Gate A)」와 「이 diff 가 도입했는가(Gate B)」를 판정하는데, 공유 엔진의 doc-recritic 은 입력 슬롯이 document·findings·profile 셋뿐이고 페르소나가 「문서만 보고」 판단하라 지시한다. 코드 경로에서 선재 결함 필터와 오탐 필터를 잃을지, 아니면 공유 엔진 계약을 확장할지(= spec-distill 사본까지 함께 움직임) 결정이 필요하다. OQ9(어휘·사본)·OQ13(생성기 vs 재판정기)과는 다른 축이다 — 여기서 빠지는 것은 판정의 **근거 입력**이다.
- D2.13 · r2 · adopt · e54043ef#r2.2 · "채택 — 층위를 바꾼다: 결정은 유지하되 §2 는 잔여 질문을 이름만 남기고 실제 해소는 §3 Open Questions 로 넘긴다 (사용자 선택)" · supersedes D1.3 — 채택 후 미적용(expired): C4 의 「trivia escape 와 kill switch 말고는 빠질 길이 없다」는 오늘의 사용자-가시 게이트 범위 선택(`/qg review` · `--skip-runtime` · Decision 1 「Review gate only」)을 삭제하는데, §0·§1·§3 어디에도 그 처분이 없다 — 앞 사이클이 명시적으로 도입한 공개 인자를 없애고 모든 비-trivia `/qg` 가 두 워크트리 생성 + 스위트 2회 실행 비용을 지게 할지 결정이 필요하다(OQ4 의 비용·시간 축이 실제로 떨어지는 첫 자리).
- D2.14 · r2 · adopt · e54043ef#r2.3 · "채택 — 층위를 바꾼다: 결정은 유지하되 §2 는 잔여 질문을 이름만 남기고 실제 해소는 §3 Open Questions 로 넘긴다 (사용자 선택)" · supersedes D1.4 — 채택 후 미적용(expired): C2·C3·C4 가 함께 서려면 「샌드박스만 제거」가 불가능하다 — 차등의 HEAD 축 트리는 샌드박스가 봉인한 커밋 B 없이는 만들어지지 않으므로, 샌드박스 배관을 지우면 봉인자를 새로 만들거나(= 같은 기계의 개명) HEAD 축을 실제 워킹 트리에서 돌려야 한다(현 설계가 근거를 대고 금지한 경로). 어느 쪽을 택할지 결정이 필요하다.
- D2.15 · r2 · adopt · e54043ef#r2.4 · "채택 — 층위를 바꾼다: 결정은 유지하되 §2 는 잔여 질문을 이름만 남기고 실제 해소는 §3 Open Questions 로 넘긴다 (사용자 선택)" · supersedes D1.5 — 채택 후 미적용(expired): C8·C10 은 브랜치 N개를 한 판정 단위로 묶지만 차등 실행과 리뷰 입력에는 HEAD 가 하나뿐이다 — N개 tip 의 HEAD 축을 무엇으로 삼을지(머지 결과 트리 / 브랜치별 N회 실행 / 최종 브랜치만)가 정해지지 않으면 C3 의 「기준선·HEAD 양쪽 직접 실행」이 성립하지 않는다. 덧붙여 §4 가 C12 의 근거로 취한 gerrit 선례는 리뷰를 묶지 않고 **제출만** 묶는다 — 「한 번의 리뷰」를 그 선례로 지지할 수 없다.
