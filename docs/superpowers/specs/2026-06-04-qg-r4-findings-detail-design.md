# R4 — Review-gate findings 상세 보고 (design)

> Review gate가 각 iter 종료 시 finding 전체를 표로 사용자에게 출력한 뒤 결정을 묻는다.
> devbrew 개선 백로그 `R4` (bucket B). asks 원문: `.claude/devbrew-improvement-asks.md`.

> **상태(scope):** 본 문서는 **구현 이전(pre-implementation) 설계 spec**이다. 여기 기술된 코드 변경(`suppress()` 3-way 재작성, SKILL `Step 4.5` surface, v2.3.0 bump, 테스트 추가)은 **writing-plans → 구현 단계의 deliverable**이며 현재 codebase에는 아직 존재하지 않는다(미존재가 정상). 본 spec은 그 구현의 *지침*이고, 리뷰 대상은 지침의 명확성·일관성·테스트 가능성이지 코드 반영 여부가 아니다.

## Context / Why

`quality-gates`의 Review gate는 iter마다 reviewer(security-reviewer / code-reviewer / codex / adversarial)를 dispatch하고, `scripts/synthesize_findings.py`가 결정적(deterministic)으로 findings를 dedup·정렬·suppress한다. 그런데 **synthesize 결과가 사용자에게 deliberate하게 surface되지 않는다**:

- `synthesize_findings.py`는 이미 상세 Markdown(file:line / summary / sources / confidence / fix)을 stdout으로 렌더한다 (`render()`, 현 line 100-129). 불릿 형식.
- 이 stdout은 orchestrator의 `Bash` tool result로 transcript에 **존재은 하나**, (i) 접힌 tool 출력이라 시각적으로 묻히고, (ii) `SKILL.md` Review gate step 5(Compute boundary outcome)는 findings empty면 loop를 clean 종료하고 non-empty면 `Review iter boundary decision` 섹션의 `AskUserQuestion`을 호출하는데 — 그 블록을 사용자에게 다시 제시하라는 지시가 없고, 템플릿은 한 줄 `<summary>`만 실어 나른다.

즉 **진짜 gap은 "데이터 부재"가 아니라 "deliberate한 surface 부재"**. 사용자는 어떤 finding 때문에 Retry/Proceed/Stop을 골라야 하는지 한 줄 요약만 보고 결정하게 된다.

## Goals

1. Review gate가 **각 iter 종료 시(결정 tool 직전)** finding 전체를 사용자에게 표로 출력한다.
2. 표는 한눈에 분류 가능해야 한다: severity / path:line / confidence / summary / source.
3. confidence 표시는 roadmap **C30 rubric**을 따른다(9–10·7–8 표시, 5–6 주의 표기[`*` caveat], **≤4 억제** — 단 severity=CRITICAL은 confidence 무관 항상 표시). confidence 범위는 **1–10**이며, 누락 시 0으로 취급(≤4 규칙에 포함되어 비-CRITICAL이면 suppress). C30 roadmap의 "3–4 억제 / 1–2 P0-only" 구분은 본 설계에서 "비-CRITICAL ≤4 suppress + CRITICAL 항상 표시"로 동치 흡수된다(1–2 비-CRITICAL도 suppress, 1–2 CRITICAL은 CRITICAL-always 규칙으로 표시).
4. History가 severity별 finding count를 누적한다(현재 한 줄 → 의미 있는 한 줄).
5. 가장 가벼운 변경으로 달성한다 — reviewer persona 파일 무변경.

## Non-goals (descoped)

- **`category` 컬럼 / 필드 추가.** 현 finding 스키마(`agent/file/line/severity/confidence/summary/proposed_fix`)에 `category` 필드가 없고, 추가하려면 보안-민감 persona 3곳(security-reviewer / adversarial / codex)을 건드려야 한다. 분류는 이미 있는 `Source`(어느 reviewer가 냈는지)로 충분 — `category`는 YAGNI. (design-lightness: [[feedback_devbrew_design_lightness]])
- **R5 (iter 간 정보 전달 / fingerprint 중복 억제).** 사용자에 의해 **영구 descope** (이후에도 구현 안 함). 따라서 `fingerprint`/`specialist` 필드도 추가하지 않는다.
- **Runtime gate 출력.** R4는 Review gate findings에 한정. Runtime gate evidence-log 출력은 무변경.
- **`--show-low-confidence` 플래그의 실제 토글 구현.** 현재 안내 문구만 존재; 본 작업은 그 동작을 새로 구현하지 않고 문구를 유지한다.

## Constraints

- **Law 2:** persona 파일 무변경 → 보안 리뷰 불필요. `synthesize_findings.py`는 결정적 script(LLM synthesizer agent를 대체한 설계 의도)이므로 렌더는 결정적이어야 한다 — orchestrator(LLM)가 표를 포맷하지 않는다.
- **AC6 / V2b 유일성:** 리터럴 문구 `findings remain`은 SKILL 전체에서 정확히 1개 `question:` 라인에만 등장해야 한다(`test_skill_orchestration.sh:50`). surface 블록은 이 문구를 쓰지 않는다(`Findings:` 사용).
- **plugin.json bump + 버전 3-사이트 동기화:** `plugins/quality-gates/`를 건드리므로 같은 PR에서 `2.2.0 → 2.3.0` (minor, 새 surface). `v2.2.0 → v2.3.0`를 **세 곳 모두** 갱신: (i) `SKILL.md:37` 제목 `(v2.2.0)`, (ii) `SKILL.md:538` Final Summary 템플릿 `(v2.2.0)` — **둘 다** 바꿔야 함(하나만 바꾸면 잔존 `2.2.0`에 아래 테스트가 매칭돼 false-pass), (iii) `test_skill_orchestration_behavior.sh:151` assertion 패턴 `v2.2.0|2\.2\.0` → `v2.3.0|2\.3\.0`. ([[feedback_plugin_version_bump]])
- **CHANGELOG:** qg는 v2.x → `## [2.3.0] — 2026-06-04` 필수.
- **doc-code 정합:** `references/state-file-format.md`의 History 예시를 새 severity-count 포맷으로 동기화.
- **pre-existing reds:** main에 8개 stale red 존재([[project_qg_pre_existing_test_reds]]) — 작업 전 baseline 캡처, 테스트는 repo root에서 실행.

## Design

### 접근법 (A1)

`synthesize_findings.py`가 표 전체를 렌더 → SKILL이 그 stdout을 결정 직전 사용자에게 verbatim 출력. 표의 counts 헤더 한 줄(`**Findings:** 1 CRITICAL / …`)이 곧 AskUserQuestion `<summary>` + History 항목 역할. (대안 A3=summary 분리 플래그, A2=LLM 렌더는 Rejected Alternatives 참조.)

### 변경 파일

| 파일 | 변경 |
|---|---|
| `scripts/synthesize_findings.py` | `render()` 표 전환 + counts 헤더, `suppress()` → C30 4-tier rubric |
| `skills/quality-pipeline/SKILL.md` | Review gate에 surface step 삽입, AskUserQuestion `<summary>`=counts line, History 포맷, v2.3.0 문자열 |
| `tests/test_synthesize_findings.sh` | AC34–39 표 포맷 갱신 + caveat/counts/fixes 신규 케이스 |
| `tests/test_skill_orchestration_behavior.sh` | 버전 assertion 2.3.0 |
| `.claude-plugin/plugin.json` | 2.2.0 → 2.3.0 |
| `CHANGELOG.md` | `[2.3.0]` 항목 |
| `skills/quality-pipeline/references/state-file-format.md` | History 예시 동기화 |

persona 파일(`agents/*.md`) 0 변경.

### 표 레이아웃 (`synthesize_findings.py` stdout)

```markdown
## Review Findings (Synthesized)

**Findings:** 1 CRITICAL / 2 IMPORTANT / 1 SUGGESTION — 2 suppressed (conf <= 4)

| Sev        | Path:Line        | Conf | Summary                          | Source                   |
|------------|------------------|------|----------------------------------|--------------------------|
| CRITICAL   | auth.py:42       | 9    | SQL injection via unescaped id   | security-reviewer, codex |
| IMPORTANT  | api/users.py:88  | 8    | Missing ownership check (IDOR)   | code-reviewer            |
| IMPORTANT  | cache.py:30      | 6 *  | Race on shared dict              | adversarial              |
| SUGGESTION | util.py:5        | 7    | Unclear variable name x          | code-reviewer            |

`*` = confidence <= 6 (treat with caution). 2 finding(s) suppressed (conf <= 4); re-run with `/qg --show-low-confidence` to see all.

**Suggested fixes:**
- `auth.py:42` — parameterize the query (bound params, not f-string)
- `api/users.py:88` — assert resource.owner_id == current_user.id before mutate
- `cache.py:30` — guard the dict with a lock
- `util.py:5` — rename x to a domain term
```

설계 결정:
- **단일 표**, 정렬 = severity-desc → confidence-desc → file-asc (기존 `sort_findings` 유지). `Sev` 컬럼이 grouping 대신.
- **`fix`는 표 밖** 리스트 (긴 fix가 표 레이아웃을 깨지 않게).
- 이모지 없음; 구분자는 기존 `render()`(현 line 116/123) em-dash 스타일과 일관. 정확한 emit 문자열은 아래 **Rendered output contract**에 lock.
- `**Findings:**` 한 줄 = summary 겸 History 소스.
- 헤더 `## Review Findings (Synthesized)` 유지 (AC38 grep 호환).
- empty case: `No high-confidence findings. N low-confidence findings suppressed.` 유지 (AC39 호환).

### confidence rubric (`suppress()` 재작성)

severity(직교축)와 분리한 C30 4-tier:

| confidence | 비-CRITICAL | CRITICAL |
|---|---|---|
| 7–10 | 표시 (clean) | 표시 (clean) |
| 5–6 | 표시 + `*` caveat | 표시 + `*` caveat |
| ≤ 4 | suppress (count만) | 표시 + `*` caveat (CRITICAL은 confidence 무관 항상) |

현행(conf<7 비-CRITICAL 전량 suppress) 대비 **5–6이 새로 보임**(caveat 부) → R4 가시성 목표와 정합. `AC36` 의미 반전(테스트 갱신).

**caveat 마커 단일 규칙:** `*` ⟺ **표시된 finding의 confidence ≤ 6** (severity 무관). 즉 비-CRITICAL 5–6, CRITICAL 5–6, CRITICAL ≤4 모두 `*`. conf ≥ 7은 마커 없음. 비-CRITICAL ≤4는 애초에 표에 안 나오므로 마커 대상 아님.

**counts 라인 의미:** `**Findings:** <n> CRITICAL / <n> IMPORTANT / <n> SUGGESTION`은 **표시된(post-rubric) finding** 기준. suppressed(비-CRITICAL conf≤4)는 severity별로 쪼개지 않고 `· <n> suppressed (conf ≤ 4)` aggregate로만 표기.

구현 노트: 기존 binary `suppress()`를 3-way 분류(`kept` / `kept_caveat` / `suppressed`)로 확장. `kept_caveat`는 표에서 conf 셀에 `*` suffix. CRITICAL은 항상 `kept`(conf≥7) 또는 `kept_caveat`(conf≤6), 절대 `suppressed` 아님.

### Rendered output contract (locked strings)

`synthesize_findings.py`가 emit하는 문자열을 아래로 **고정**한다 — counts line은 verbatim 추출 대상이라 문자 단위로 load-bearing이고, 테스트 fixture는 이 contract에서 기계적으로 도출된다. 이모지 없음, 구분자는 기존 `render()`(현 line 116/123) em-dash 스타일과 일관:

- **counts line:** `**Findings:** <c> CRITICAL / <i> IMPORTANT / <s> SUGGESTION`. suppressed>0이면 ` — <n> suppressed (conf <= 4)` tail 부착(=0이면 tail 생략). severity 셋은 count 0이어도 항상 포함.
- **표 헤더:** `| Sev | Path:Line | Conf | Summary | Source |`.
- **Conf 셀:** clean = `<n>`; caveat(conf<=6) = `<n> *` (숫자·공백·별표).
- **caveat 범례:** `` `*` = confidence <= 6 (treat with caution). ``
- **suppressed 안내(단일 lock):** `<n> finding(s) suppressed (conf <= 4); re-run with `/qg --show-low-confidence` to see all.` — 표 레이아웃 예시의 legend 줄과 **동일 문자열**. (기존 `### Suppressed` heading + `hidden` 문구를 이 compact 1줄로 대체.)
- **fixes 블록:** `**Suggested fixes:**` 헤더 + 행 `` - `<path>:<line>` — <proposed_fix> ``.
- **empty:** `No high-confidence findings. <n> low-confidence findings suppressed.` (AC39 호환).

비교 연산자는 emit 문자열에서 ASCII `<=`를 쓰고 `≤`(non-ASCII)는 emit하지 않는다(grep target에 non-ASCII 회피). 본 설계 doc **산문**은 가독성을 위해 `≤`/`—`를 자유롭게 쓰되 위 emit 문자열에는 해당 없음.

### SKILL.md Review gate 변경

현재 step 4(synthesize) → 5(boundary) 사이에 삽입:

> **Step 4.5 — Surface findings.** boundary outcome은 **kept(표시) finding 수** 기준으로 판정한다(suppress 이후, raw findings 수 아님):
> - **kept > 0** → synthesize_findings.py stdout 전체를 사용자에게 deliberate 메시지로 출력(`## Review gate iter N — Findings` 컨텍스트 1줄 prepend) — 결정 tool **이전에**. 이어서 `Review iter boundary decision`(iter 5면 max-iter) 호출.
> - **kept = 0, suppressed > 0** → 표시할 high-confidence finding 없음 → **clean으로 처리**(loop 계속, AskUserQuestion 미호출). 단 transparency 위해 stdout의 `No high-confidence findings. N low-confidence findings suppressed.` 한 줄을 surface.
> - **kept = 0, suppressed = 0** → 기존 `## Review gate iter N: clean` 메시지 후 loop exit.

counts line 추출은 **결정론적**: stdout에서 `**Findings:**` prefix 라인을 **verbatim 복사**해 AskUserQuestion `<summary>` 및 History append에 사용한다 (LLM이 별도 요약 문구를 생성하지 않음 — Law 1 결정론).

- AskUserQuestion 템플릿: `<summary>` = verbatim counts line. **`findings remain` 앵커 유지**(surface 블록엔 미사용 — V2b 유일성).
- **max-iter 결정**: iter 5에서 kept>0이면 동일하게 Step 4.5 surface 후 `Review max-iter decision` 호출. 그 템플릿의 `Last findings: <summary>`의 `<summary>`도 verbatim counts line으로 채운다 (템플릿 텍스트 자체는 무변경).
- History(R2 rule): `Review gate iter 2: 1 CRITICAL / 2 IMPORTANT / 1 SUGGESTION → user chose Retry`.

## Acceptance Criteria

- **AC-R4-1:** `synthesize_findings.py`가 非empty findings에 대해 Markdown **표**(`| Sev | Path:Line | Conf | Summary | Source |`)를 출력한다.
- **AC-R4-2:** 출력 첫 블록에 `**Findings:** <n> CRITICAL / <n> IMPORTANT / <n> SUGGESTION` counts 라인이 있다. **세 severity는 count가 0이어도 항상 포함**(`0 CRITICAL / 2 IMPORTANT / 0 SUGGESTION` — 결정론적 추출/파싱). count는 kept(표시) finding 기준.
- **AC-R4-3:** 표시된 finding의 confidence ≤ 6이면 `*` caveat 마커가 붙고(severity 무관), confidence ≥ 7이면 마커가 없다. confidence ≤ 4 비-CRITICAL은 표에서 빠지고 suppressed count에 반영된다.
- **AC-R4-4:** severity=CRITICAL은 confidence와 무관하게 항상 표에 표시된다(conf≤4 포함, `*` 마커 부착).
- **AC-R4-5:** `proposed_fix`는 표 밖 `**Suggested fixes:**` 리스트에 path:line 키로 렌더된다.
- **AC-R4-6:** 정렬은 severity-desc → confidence-desc → file-asc (CRITICAL 행이 SUGGESTION 행보다 먼저).
- **AC-R4-7:** empty findings → `No high-confidence findings` 메시지(기존 동작 유지).
- **AC-R4-8:** SKILL Review gate에 surface step이 존재하고, `Review iter boundary decision`의 `findings remain` 라인보다 **먼저** 나타난다. 검증은 `test_skill_orchestration_behavior.sh`의 `assert_order` primitive 사용 — earlier anchor `first_line 'Surface findings|Step 4\.5'`, later anchor `first_line 'question:.*findings remain'`. **`## Review gate` 섹션 헤딩을 anchor로 쓰지 말 것**(헤딩은 항상 내부 라인보다 앞서므로 tautological PASS — V7-class 결함). 존재 grep만으로는 mis-placement를 못 잡아 불충분.
- **AC-R4-9:** `findings remain`는 SKILL 전체에서 정확히 1개 `question:` 라인에만 존재(V2b 불변).
- **AC-R4-10:** `plugin.json` = 2.3.0; SKILL.md의 **두** `(v2.2.0)` 사이트(제목 line 37 + Final Summary line 538) 모두 `(v2.3.0)`로; `test_skill_orchestration_behavior.sh` 패턴 `v2.3.0|2\.3\.0`이며 SKILL에 잔존 `2.2.0` 없음; CHANGELOG `[2.3.0]`; state-file-format.md History 예시가 새 포맷.
- **AC-R4-11:** kept=0 & suppressed>0이면 gate는 clean으로 계속하고(AskUserQuestion 미호출) `No high-confidence findings` 한 줄만 surface한다. kept=0 & suppressed=0이면 기존 clean 메시지.

## Files to Modify

- `plugins/quality-gates/scripts/synthesize_findings.py`
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md`
- `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`
- `plugins/quality-gates/tests/test_synthesize_findings.sh`
- `plugins/quality-gates/tests/test_skill_orchestration_behavior.sh`
- `plugins/quality-gates/.claude-plugin/plugin.json`
- `plugins/quality-gates/CHANGELOG.md`

## Verification Plan

1. **Baseline:** 작업 전 repo root에서 전체 qg 테스트 실행, 기존 8 stale red 캡처([[project_qg_pre_existing_test_reds]]).
2. **TDD:** `test_synthesize_findings.sh` AC34–39 갱신 + 신규 케이스를 먼저 red로 작성 → `synthesize_findings.py` 구현 → green. 신규/갱신 fixture가 cover해야 할 경계:
   - **AC36 의미 반전:** conf=5 IMPORTANT → 이제 표시 + `*` (expected_grep: 해당 행 + `*`); conf=4 비-CRITICAL → suppress (expected_neg: 해당 file:line); conf=4 CRITICAL → 표시 + `*`.
   - **counts 라인:** `0 CRITICAL`을 포함하는 케이스로 zero-count 항상-3-severity 포맷 검증.
   - **fixes 리스트:** `**Suggested fixes:**` 아래 path:line 키 존재.
   - **표 헤더:** `| Sev | Path:Line | Conf | Summary | Source |` 존재.
3. `test_skill_orchestration.sh` (findings remain 유일성 = 1), `test_skill_orchestration_behavior.sh` (버전 2.3.0) green.
4. **Ordering test(자동, AC-R4-8):** `test_skill_orchestration_behavior.sh`에 `assert_order "surface precedes decision" "$(first_line 'Surface findings|Step 4\.5')" "$(first_line 'question:.*findings remain')"` 추가. **section-heading anchor 금지**(`## Review gate`는 tautological PASS — V7-class). test_skill_orchestration.sh의 V2a(section-heading awk)는 이 용도에 부적합 — surface-step 텍스트 자체를 anchor로.
5. 회귀: 작업 후 전체 qg 테스트 = baseline red set만 남고 신규 red 0.
6. **(수동 smoke — AC 비포함; 근거: 전체 `/qg` e2e는 live agent dispatch가 필요해 unit-test 불가):** findings를 유발하는 작은 diff(예: `tests/fixtures/security-reviewer/expected/sql-concat`류 SQL-concat) 위에서 `/qg review` 실행. **성공 기준:** (a) 표 블록이 AskUserQuestion **이전** assistant 메시지로 출력되고, (b) `<summary>`가 stdout의 `**Findings:**` counts line과 글자 그대로 일치.

## Rejected Alternatives

- **A2 — orchestrator(LLM)가 표 렌더:** 비결정적. `synthesize_findings.py`가 LLM synthesizer agent를 대체한 설계 의도 위반. 기각.
- **A3 — `--emit-summary` 플래그로 summary/표 분리 출력:** `**Findings:**` 헤더 한 줄이 이미 summary를 겸하므로 부수 복잡도만 추가. 기각.
- **Full C30 schema (category + fingerprint + specialist):** persona 3곳 편집 + 보안 리뷰. R5가 영구 descope되어 fingerprint 수요 없음, category는 source로 대체 가능. design-lightness로 기각.
- **엄격 표시 정책(CRITICAL/IMPORTANT만 본문, SUGGESTION appendix):** confidence rubric과 이중 필터가 되어 중신뢰 SUGGESTION이 사라질 위험. "전체 표(rubric 단일 필터)"로 기각.

## Handoff Context

**TL;DR:** R4는 Review gate가 *이미 생성하는* finding 상세를 사용자에게 deliberate하게 surface하는 가시성 개선이다. 핵심 결정 3개: (1) **A1 접근** — `synthesize_findings.py`가 표를 렌더하고 SKILL이 verbatim surface (LLM 비결정 렌더 금지); (2) **category/persona 무변경** — design-lightness로 `category` 필드 제외, 분류는 `Source`로; (3) **C30 confidence rubric 채택** — conf 5–6 caveat 노출, ≤4 비-CRITICAL suppress, CRITICAL 항상 표시.

**Implicit context (구현자가 놓치기 쉬운 것):**
- `suppress()`를 binary → 3-way(`kept` / `kept_caveat` / `suppressed`)로 바꾸면 **AC36 의미가 반전**된다(conf5 IMPORTANT: suppress → 표시+`*`). 테스트 갱신 필수.
- boundary outcome은 raw findings가 아니라 **kept** 기준. `kept=0 & suppressed>0`은 clean(질문 안 함).
- `findings remain` 앵커는 SKILL 전체 **정확히 1회**(V2b) — surface 블록은 `Findings:`만 사용.
- 버전 문자열 **3곳 동기화**: `plugin.json` · `SKILL.md`(v2.x 문자열) · `test_skill_orchestration_behavior.sh`.
- `*` caveat 단일 규칙: 표시된 finding의 confidence ≤ 6 ⟺ `*`.

**Deferred to plan (writing-plans가 확정):**
- `expected_grep` / `expected_neg` 리터럴 — 위 **Rendered output contract**의 locked strings에서 기계적으로 도출(plan의 첫 step). contract가 문자열을 lock하므로 red-first TDD 가능(도출이 선행조건).
- 표 컬럼 padding/정렬 등 순수 cosmetic whitespace (테스트는 셀 내용으로 grep, padding 비의존).

## Metadata

- **Backlog ID:** R4 (bucket B). R5는 영구 descope.
- **Plugin:** quality-gates 2.2.0 → 2.3.0 (minor).
- **Date:** 2026-06-04.
- **Branch:** `feature/qg-r4-findings-detail`.
- **Principles instantiated:** Law 1(가시성=명확성), design-lightness(category/persona 회피), §5.3 no-numeric-scoring 준수(confidence는 categorical 표시 rubric이지 점수 게이트 아님).
