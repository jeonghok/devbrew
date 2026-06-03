# R4 — Review-gate findings 상세 보고 (design)

> Review gate가 각 iter 종료 시 finding 전체를 표로 사용자에게 출력한 뒤 결정을 묻는다.
> devbrew 개선 백로그 `R4` (bucket B). asks 원문: `.claude/devbrew-improvement-asks.md`.

## Context / Why

`quality-gates`의 Review gate는 iter마다 reviewer(security-reviewer / code-reviewer / codex / adversarial)를 dispatch하고, `scripts/synthesize_findings.py`가 결정적(deterministic)으로 findings를 dedup·정렬·suppress한다. 그런데 **synthesize 결과가 사용자에게 deliberate하게 surface되지 않는다**:

- `synthesize_findings.py`는 이미 상세 Markdown(file:line / summary / sources / confidence / fix)을 stdout으로 렌더한다 (`render()`, 현 line 100-129). 불릿 형식.
- 이 stdout은 orchestrator의 `Bash` tool result로 transcript에 **존재은 하나**, (i) 접힌 tool 출력이라 시각적으로 묻히고, (ii) `SKILL.md` Review gate step 5는 이 블록을 사용자에게 다시 제시하라는 지시 없이 곧장 `AskUserQuestion`으로 가며, 그 템플릿은 한 줄 `<summary>`만 실어 나른다 (SKILL.md 현 line 277-294).

즉 **진짜 gap은 "데이터 부재"가 아니라 "deliberate한 surface 부재"**. 사용자는 어떤 finding 때문에 Retry/Proceed/Stop을 골라야 하는지 한 줄 요약만 보고 결정하게 된다.

## Goals

1. Review gate가 **각 iter 종료 시(결정 tool 직전)** finding 전체를 사용자에게 표로 출력한다.
2. 표는 한눈에 분류 가능해야 한다: severity / path:line / confidence / summary / source.
3. confidence 표시는 roadmap **C30 rubric**을 따른다(9–10·7–8 표시, 5–6 주의 표기, 3–4 억제, CRITICAL은 confidence 무관 항상 표시).
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
- **plugin.json bump:** `plugins/quality-gates/`를 건드리므로 같은 PR에서 `2.2.0 → 2.3.0` (minor, 새 surface). SKILL.md 내 `v2.2.0` 문자열과 `test_skill_orchestration_behavior.sh`의 버전 assertion도 동기화. ([[feedback_plugin_version_bump]])
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

**Findings:** 1 CRITICAL / 2 IMPORTANT / 1 SUGGESTION · 2 suppressed (conf ≤ 4)

| Sev        | Path:Line        | Conf | Summary                          | Source                   |
|------------|------------------|------|----------------------------------|--------------------------|
| CRITICAL   | auth.py:42       | 9    | SQL injection via unescaped id   | security-reviewer, codex |
| IMPORTANT  | api/users.py:88  | 8    | Missing ownership check (IDOR)   | code-reviewer            |
| IMPORTANT  | cache.py:30      | 6 *  | Race on shared dict              | adversarial              |
| SUGGESTION | util.py:5        | 7    | Unclear variable name x          | code-reviewer            |

`*` = confidence ≤ 6 (treat with caution). 2 findings suppressed (conf ≤ 4) — re-run with `/qg --show-low-confidence`.

**Suggested fixes:**
- `auth.py:42` — parameterize the query (bound params, not f-string)
- `api/users.py:88` — assert resource.owner_id == current_user.id before mutate
- `cache.py:30` — guard the dict with a lock
- `util.py:5` — rename x to a domain term
```

설계 결정:
- **단일 표**, 정렬 = severity-desc → confidence-desc → file-asc (기존 `sort_findings` 유지). `Sev` 컬럼이 grouping 대신.
- **`fix`는 표 밖** 리스트 (긴 fix가 표 레이아웃을 깨지 않게).
- 플레인 ASCII (이모지 없음, 하우스 스타일).
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

### SKILL.md Review gate 변경

현재 step 4(synthesize) → 5(boundary) 사이에 삽입:

> **Step 4.5 — Surface findings.** synthesize_findings.py 반환 후 findings 非empty면 그 stdout 전체를 사용자에게 deliberate 메시지로 출력(`## Review gate iter N — Findings` 컨텍스트 1줄 prepend) — 결정 tool **이전에**. `**Findings:**` 라인을 AskUserQuestion `<summary>`와 History append에 재사용.

- AskUserQuestion 템플릿: `<summary>` = counts line. **`findings remain` 앵커 유지**(surface 블록엔 미사용 — V2b 유일성).
- max-iter 결정에도 동일 surface 적용.
- History(R2 rule): `Review gate iter 2: 1 CRITICAL / 2 IMPORTANT / 1 SUGGESTION → user chose Retry`.

## Acceptance Criteria

- **AC-R4-1:** `synthesize_findings.py`가 非empty findings에 대해 Markdown **표**(`| Sev | Path:Line | Conf | Summary | Source |`)를 출력한다.
- **AC-R4-2:** 출력 첫 블록에 `**Findings:** <n> CRITICAL / <n> IMPORTANT / <n> SUGGESTION` counts 라인이 있다.
- **AC-R4-3:** 표시된 finding의 confidence ≤ 6이면 `*` caveat 마커가 붙고(severity 무관), confidence ≥ 7이면 마커가 없다. confidence ≤ 4 비-CRITICAL은 표에서 빠지고 suppressed count에 반영된다.
- **AC-R4-4:** severity=CRITICAL은 confidence와 무관하게 항상 표에 표시된다(conf≤4 포함, `*` 마커 부착).
- **AC-R4-5:** `proposed_fix`는 표 밖 `**Suggested fixes:**` 리스트에 path:line 키로 렌더된다.
- **AC-R4-6:** 정렬은 severity-desc → confidence-desc → file-asc (CRITICAL 행이 SUGGESTION 행보다 먼저).
- **AC-R4-7:** empty findings → `No high-confidence findings` 메시지(기존 동작 유지).
- **AC-R4-8:** SKILL Review gate가 결정 tool 직전 findings 블록을 surface하는 step을 명시 포함한다.
- **AC-R4-9:** `findings remain`는 SKILL 전체에서 정확히 1개 `question:` 라인에만 존재(V2b 불변).
- **AC-R4-10:** `plugin.json` = 2.3.0, SKILL `v2.3.0` 문자열, CHANGELOG `[2.3.0]`, state-file-format.md History 예시가 새 포맷.

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
2. **TDD:** `test_synthesize_findings.sh` AC34–39 갱신 + 신규 케이스(counts/caveat/fixes/suppress=conf≤4)를 먼저 red로 작성 → `synthesize_findings.py` 구현 → green.
3. `test_skill_orchestration.sh` (findings remain 유일성), `test_skill_orchestration_behavior.sh` (버전 2.3.0) green.
4. 회귀: 작업 후 전체 qg 테스트 = baseline red set만 남고 신규 red 0.
5. (수동) `/qg`를 findings 발생 diff에 실행해 표가 결정 직전 surface되는지 e2e 확인.

## Rejected Alternatives

- **A2 — orchestrator(LLM)가 표 렌더:** 비결정적. `synthesize_findings.py`가 LLM synthesizer agent를 대체한 설계 의도 위반. 기각.
- **A3 — `--emit-summary` 플래그로 summary/표 분리 출력:** `**Findings:**` 헤더 한 줄이 이미 summary를 겸하므로 부수 복잡도만 추가. 기각.
- **Full C30 schema (category + fingerprint + specialist):** persona 3곳 편집 + 보안 리뷰. R5가 영구 descope되어 fingerprint 수요 없음, category는 source로 대체 가능. design-lightness로 기각.
- **엄격 표시 정책(CRITICAL/IMPORTANT만 본문, SUGGESTION appendix):** confidence rubric과 이중 필터가 되어 중신뢰 SUGGESTION이 사라질 위험. "전체 표(rubric 단일 필터)"로 기각.

## Metadata

- **Backlog ID:** R4 (bucket B). R5는 영구 descope.
- **Plugin:** quality-gates 2.2.0 → 2.3.0 (minor).
- **Date:** 2026-06-04.
- **Branch:** `feature/qg-r4-findings-detail`.
- **Principles instantiated:** Law 1(가시성=명확성), design-lightness(category/persona 회피), §5.3 no-numeric-scoring 준수(confidence는 categorical 표시 rubric이지 점수 게이트 아님).
