# R4 — Review-gate Findings 상세 보고 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Review gate가 각 iteration 종료 시 finding 전체(severity / path:line / confidence / summary / source + suggested fixes)를 결정 tool 직전에 사용자에게 표로 surface한다.

**Architecture:** `synthesize_findings.py`(결정적 script)가 표를 렌더하고 `SKILL.md`(orchestrator)가 그 stdout을 verbatim surface한다 — LLM은 표를 포맷하지 않는다(Law 1 결정론). `suppress()`는 binary 억제에서 C30 4-tier rubric(conf 5–6 표시+caveat, ≤4 비-CRITICAL 억제, CRITICAL 항상 표시)으로 확장. reviewer persona(`agents/*.md`)는 0 변경 → 보안 리뷰 불필요.

**Tech Stack:** Python 3 (stdlib + PyYAML), Bash 테스트 하니스(grep -E 정적 검증), Markdown(SKILL / docs / CHANGELOG).

**Source spec:** `docs/superpowers/specs/2026-06-04-qg-r4-findings-detail-design.md` (spec-distill 4라운드 approved).

---

## Locked output strings (spec Rendered-output-contract → 기계 도출)

> spec가 plan에 위임한 "expected_grep / expected_neg 리터럴 도출"(Handoff Context §Deferred to plan). 아래는 `synthesize_findings.py`가 emit하는 **고정 문자열**이며 모든 테스트 패턴이 여기서 나온다. 비교 연산자는 ASCII `<=`(non-ASCII `≤` emit 금지), em-dash `—`는 허용(기존 `render()` 스타일과 일관).

비어있지 않은 findings 출력 구조(위→아래):

1. `## Review Findings (Synthesized)` (헤딩 유지 — AC38 grep 호환)
2. counts line: `**Findings:** <c> CRITICAL / <i> IMPORTANT / <s> SUGGESTION` — `suppressed>0`이면 ` — <n> suppressed (conf <= 4)` tail 부착(0이면 생략). 세 severity는 count 0이어도 항상 포함.
3. 표 헤더: `| Sev | Path:Line | Conf | Summary | Source |` + 구분행 `|---|---|---|---|---|`
4. 표 행: `| <SEV> | <file>:<line> | <conf-cell> | <summary> | <sources> |`
   - conf-cell: `conf <= 6` → `<n> *`(caveat); `conf >= 7` → `<n>`(clean)
   - sources: dedup 시 merge된 reviewer 목록(알파벳 정렬, `, ` 조인)
5. caveat 범례(표에 `*` 행이 ≥1개일 때만): `` `*` = confidence <= 6 (treat with caution). ``
6. suppressed 안내(`suppressed>0`일 때만): `<n> finding(s) suppressed (conf <= 4); re-run with `/qg --show-low-confidence` to see all.`
7. fixes 블록: `**Suggested fixes:**` 헤더 + 각 행 `` - `<file>:<line>` — <proposed_fix> ``

빈 findings(kept=0): `No high-confidence findings. <n> low-confidence findings suppressed.` (기존 동작 유지 — AC39 호환).

caveat 단일 규칙: **표시된 finding의 confidence ≤ 6 ⟺ `*`** (severity 무관). conf ≥ 7은 마커 없음. 비-CRITICAL ≤4는 표에서 빠지므로 마커 대상 아님.

---

## File structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `plugins/quality-gates/scripts/synthesize_findings.py` | 결정적 finding 집계 + 렌더 | `suppress()` 3-way, `render()` 표 |
| `plugins/quality-gates/tests/test_synthesize_findings.sh` | 위 script 단위 검증 | AC36/37/38 갱신 + 신규 케이스 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | Review gate orchestrator | Step 4.5 surface + boundary kept-기준 + v2.3.0 |
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | SKILL protocol-shape 정적 검증 | surface-순서 assert + v2.3.0 패턴 |
| `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` | History 포맷 문서 | 예시를 severity-count로 |
| `plugins/quality-gates/.claude-plugin/plugin.json` | 메타데이터 | 2.2.0 → 2.3.0 |
| `plugins/quality-gates/CHANGELOG.md` | 변경 로그 | `[2.3.0]` 항목 |

`agents/*.md` persona 0 변경. `tests/test_skill_orchestration.sh`는 **편집 안 함**(regression으로만 실행 — `findings remain` 유일성=1 유지 확인).

> **경로 주의:** spec 본문은 behavior 테스트를 `test_skill_orchestration_behavior.sh:151`로 표기하지만 실제 경로는 `tests/harness/` 하위다(`plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`). 본 plan은 실제 경로를 쓴다.

---

## Task 1: Baseline 캡처 (red set 고정)

R4 작업 전 main의 기존 stale red를 캡처해야 회귀 판정이 가능하다([[project_qg_pre_existing_test_reds]] — qg는 CI 없음 + 8개 stale red). **테스트는 repo root에서 실행.**

**Files:** (없음 — 측정만)

- [ ] **Step 1: 작업 브랜치 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew && git branch --show-current
```
Expected: `feature/qg-r4-findings-detail` (spec가 이 브랜치에 커밋됨). 아니면:
```bash
git checkout feature/qg-r4-findings-detail
```

- [ ] **Step 2: 직접 영향 받는 3개 테스트가 현재 green인지 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_synthesize_findings.sh; echo "exit=$?"
bash plugins/quality-gates/tests/test_skill_orchestration.sh; echo "exit=$?"
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"
```
Expected: 세 개 모두 `exit=0` (PASS). 이 세 파일이 R4의 red-first 대상.

- [ ] **Step 3: 전체 qg 테스트 baseline red 캡처**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in plugins/quality-gates/tests/*.sh plugins/quality-gates/tests/harness/*.sh; do
  bash "$t" >/dev/null 2>&1 && echo "PASS $t" || echo "FAIL $t"
done | sort | tee /tmp/qg-baseline-r4.txt
```
Expected: 일부 `FAIL`(기존 stale: codex / consent / security / sandbox 계열). `/tmp/qg-baseline-r4.txt`에 보존 — Task 5에서 이 set과 대조해 "신규 red 0"을 검증한다. (이 파일은 commit 안 함.)

---

## Task 2: `synthesize_findings.py` — `suppress()` 3-way + `render()` 표 (TDD)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py:80-129` (`suppress()` + `render()`)
- Test: `plugins/quality-gates/tests/test_synthesize_findings.sh` (전면 케이스 갱신)

- [ ] **Step 1: 테스트를 새 contract로 재작성 (RED)**

`plugins/quality-gates/tests/test_synthesize_findings.sh`의 **AC34 케이스부터 끝(`echo ""` 직전)까지**, 즉 현재 파일의 29–66행(`# AC34 dedup` ~ AC39 `run_case` 블록 끝)을 아래로 **교체**한다. 하니스(`run_case` 함수, 헤더 1–28행, footer 68–70행)는 그대로 둔다:

```bash
# AC34 dedup + source-merge (table row)
run_case "AC34 dedup+merge" \
  'verdicts: []' \
  '- {agent: code-reviewer, file: a.py, line: 10, severity: IMPORTANT, confidence: 8, summary: x, proposed_fix: y}
- {agent: silent-failure-hunter, file: a.py, line: 10, severity: IMPORTANT, confidence: 6, summary: x, proposed_fix: y}' \
  'a\.py:10 \| 8 \| x \| code-reviewer, silent-failure-hunter' ''

# AC35 reject (unchanged behavior)
run_case "AC35 reject" \
  '- {finding_id: code-reviewer-a.py-10, verdict: reject, reason: x}' \
  '- {agent: code-reviewer, file: a.py, line: 10, severity: CRITICAL, confidence: 9, summary: bug, proposed_fix: fix}' \
  'No high-confidence' 'a.py:10'

# AC36a rubric: conf5 non-CRIT shown WITH caveat; conf4 non-CRIT suppressed
run_case "AC36a conf5 shown+caveat / conf4 suppressed" \
  'verdicts: []' \
  '- {agent: r, file: shown5.py, line: 1, severity: IMPORTANT, confidence: 5, summary: mid, proposed_fix: x}
- {agent: r, file: hidden4.py, line: 1, severity: IMPORTANT, confidence: 4, summary: low, proposed_fix: y}
- {agent: r, file: crit4.py, line: 1, severity: CRITICAL, confidence: 4, summary: critlow, proposed_fix: z}' \
  'shown5\.py:1 \| 5 \*' 'hidden4\.py:1'

# AC36b rubric: CRITICAL always shown (conf4) WITH caveat
run_case "AC36b CRITICAL conf4 shown+caveat" \
  'verdicts: []' \
  '- {agent: r, file: shown5.py, line: 1, severity: IMPORTANT, confidence: 5, summary: mid, proposed_fix: x}
- {agent: r, file: hidden4.py, line: 1, severity: IMPORTANT, confidence: 4, summary: low, proposed_fix: y}
- {agent: r, file: crit4.py, line: 1, severity: CRITICAL, confidence: 4, summary: critlow, proposed_fix: z}' \
  'crit4\.py:1 \| 4 \*' ''

# AC-R4 conf6/conf7 boundary: 6 -> caveat, 7 -> no marker
run_case "ACR4 conf6 boundary caveat" \
  'verdicts: []' \
  '- {agent: r, file: z.py, line: 1, severity: IMPORTANT, confidence: 6, summary: s, proposed_fix: f}' \
  'z\.py:1 \| 6 \*' ''
run_case "ACR4 conf7 boundary no-marker" \
  'verdicts: []' \
  '- {agent: r, file: y.py, line: 1, severity: IMPORTANT, confidence: 7, summary: s, proposed_fix: f}' \
  'y\.py:1 \| 7 \|' '7 \*'

# AC37 sort: CRITICAL row precedes SUGGESTION row (no ### headings anymore)
run_case "AC37 sort CRIT<SUG" \
  'verdicts: []' \
  '- {agent: r, file: a.py, line: 1, severity: SUGGESTION, confidence: 9, summary: s, proposed_fix: f}
- {agent: r, file: b.py, line: 1, severity: CRITICAL, confidence: 9, summary: c, proposed_fix: f}' \
  'CRITICAL \| b\.py:1.*SUGGESTION \| a\.py:1' ''

# AC38 table header schema
run_case "AC38 table header" \
  'verdicts: []' \
  '- {agent: r, file: a.py, line: 1, severity: CRITICAL, confidence: 9, summary: s, proposed_fix: f}' \
  '## Review Findings.*\| Sev \| Path:Line \| Conf \| Summary \| Source \|' ''

# AC-R4 counts line: always-3-severity (zero counts) + no marker at conf>=7
run_case "ACR4 counts zero-fill + no-marker" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}' \
  '\*\*Findings:\*\* 0 CRITICAL / 1 IMPORTANT / 0 SUGGESTION' '8 \*'

# AC-R4 suggested-fixes block below table
run_case "ACR4 fixes block" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: parameterize}' \
  '\*\*Suggested fixes:\*\*.*`x\.py:1` —' ''

# AC-R4 caveat legend present when a caveat row exists
run_case "ACR4 caveat legend present" \
  'verdicts: []' \
  '- {agent: r, file: w.py, line: 1, severity: IMPORTANT, confidence: 5, summary: s, proposed_fix: f}' \
  '`\*` = confidence <= 6 \(treat with caution\)\.' ''

# AC-R4 caveat legend ABSENT when all shown findings are conf>=7
run_case "ACR4 caveat legend absent" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}' \
  '' 'confidence <= 6 \(treat'

# AC-R4 suppressed notice line + counts tail (1 shown, 1 suppressed)
run_case "ACR4 suppressed notice + counts tail" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}
- {agent: r, file: q.py, line: 1, severity: SUGGESTION, confidence: 3, summary: low, proposed_fix: f}' \
  'finding\(s\) suppressed \(conf <= 4\); re-run with `/qg --show-low-confidence` to see all\.' 'q\.py:1 \|'
run_case "ACR4 counts suppressed tail" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}
- {agent: r, file: q.py, line: 1, severity: SUGGESTION, confidence: 3, summary: low, proposed_fix: f}' \
  '1 suppressed \(conf <= 4\)' ''

# AC39 empty
run_case "AC39 empty" \
  'verdicts: []' \
  '' \
  'No high-confidence findings' ''
```

(`q.py:1 \|` neg는 suppressed finding이 표 행으로 새지 않음을 검증 — `q.py:1`은 fixes/notice 어디에도 표 행으로 나오면 안 됨. suppressed는 count로만 반영되므로 통과.)

- [ ] **Step 2: 테스트 실행 → RED 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_synthesize_findings.sh; echo "exit=$?"
```
Expected: `exit=1`. AC34/36a/36b/37/38 + 모든 ACR4 케이스 `FAIL`(현 코드는 불릿+`### CRITICAL` 포맷, conf5는 억제). AC35/AC39만 PASS.

- [ ] **Step 3: `suppress()`를 3-way rubric으로 재작성**

`plugins/quality-gates/scripts/synthesize_findings.py`의 `suppress()`(현 80–89행)를 교체:

```python
def suppress(findings):
    """C30 rubric (R4): kept vs suppressed.

    - CRITICAL: always kept (any confidence).
    - non-CRITICAL: confidence <= 4 -> suppressed; else kept.

    The caveat marker (`*`) is NOT decided here; it is a pure function of
    `confidence <= 6` on any *shown* finding, computed in render().
    """
    kept, suppressed = [], []
    for f in findings:
        sev = f.get("severity", "SUGGESTION")
        conf = int(f.get("confidence", 0))
        if sev != "CRITICAL" and conf <= 4:
            suppressed.append(f)
        else:
            kept.append(f)
    return kept, suppressed
```

- [ ] **Step 4: `render()`를 표 포맷으로 재작성**

`plugins/quality-gates/scripts/synthesize_findings.py`의 `render()`(현 100–129행)를 교체:

```python
def render(findings, suppressed_count):
    if not findings:
        return (
            "## Review Findings (Synthesized)\n\n"
            f"No high-confidence findings. {suppressed_count} low-confidence "
            "findings suppressed.\n"
        )

    counts = {"CRITICAL": 0, "IMPORTANT": 0, "SUGGESTION": 0}
    for f in findings:
        sev = f.get("severity", "SUGGESTION")
        if sev in counts:
            counts[sev] += 1
    counts_line = (
        f"**Findings:** {counts['CRITICAL']} CRITICAL / "
        f"{counts['IMPORTANT']} IMPORTANT / {counts['SUGGESTION']} SUGGESTION"
    )
    if suppressed_count > 0:
        counts_line += f" — {suppressed_count} suppressed (conf <= 4)"

    out = ["## Review Findings (Synthesized)", "", counts_line, ""]
    out.append("| Sev | Path:Line | Conf | Summary | Source |")
    out.append("|---|---|---|---|---|")
    any_caveat = False
    for f in findings:
        sev = f.get("severity", "SUGGESTION")
        conf = int(f.get("confidence", 0))
        if conf <= 6:
            conf_cell = f"{conf} *"
            any_caveat = True
        else:
            conf_cell = f"{conf}"
        path_line = f"{f.get('file')}:{f.get('line')}"
        summary = f.get("summary", "")
        source = ", ".join(f.get("sources", [f.get("agent", "?")]))
        out.append(f"| {sev} | {path_line} | {conf_cell} | {summary} | {source} |")
    out.append("")
    if any_caveat:
        out.append("`*` = confidence <= 6 (treat with caution).")
    if suppressed_count > 0:
        out.append(
            f"{suppressed_count} finding(s) suppressed (conf <= 4); "
            "re-run with `/qg --show-low-confidence` to see all."
        )
    out.append("")
    out.append("**Suggested fixes:**")
    for f in findings:
        out.append(
            f"- `{f.get('file')}:{f.get('line')}` — {f.get('proposed_fix', '(none)')}"
        )
    return "\n".join(out) + "\n"
```

`main()`은 무변경 — 이미 `kept, suppressed = suppress(findings)` → `render(kept, len(suppressed))` 시퀀스다(현 143–146행). `render()` 시그니처도 그대로 `(findings, suppressed_count)`.

- [ ] **Step 5: 테스트 실행 → GREEN 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_synthesize_findings.sh; echo "exit=$?"
```
Expected: `exit=0`, 모든 케이스 PASS (`Total: 14, PASS=14, FAIL=0`).

- [ ] **Step 6: 모듈 docstring의 stale algorithm 설명 1줄 수정**

`synthesize_findings.py` 상단 docstring(현 5–7행)이 `suppress confidence<7 unless severity==CRITICAL`라고 적혀 있다. 동작이 바뀌었으니 동기화:

old:
```python
deterministic (no LLM judgment): apply Adversarial verdicts → group/dedup
by (file,line,severity) → suppress confidence<7 unless severity==CRITICAL
→ sort severity-desc / confidence-desc / file-asc → render Markdown.
```
new:
```python
deterministic (no LLM judgment): apply Adversarial verdicts → group/dedup
by (file,line,severity) → suppress non-CRITICAL confidence<=4 (CRITICAL always
kept; confidence 5-6 shown with a `*` caveat) → sort severity-desc /
confidence-desc / file-asc → render Markdown table.
```

- [ ] **Step 7: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/tests/test_synthesize_findings.sh
git commit -m "feat(quality-gates): render findings table + C30 confidence rubric (R4)"
```

---

## Task 3: SKILL.md Step 4.5 surface + kept-기준 boundary + v2.3.0 (TDD)

**Files:**
- Modify: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh:150-151` (버전 패턴) + 신규 ordering assertion (파일 끝 직전)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:37` (제목), `:249-257` (steps 4–5), `:538` (Final Summary 제목)

- [ ] **Step 1: behavior 테스트에 surface-순서 assert 추가 + 버전 패턴 갱신 (RED)**

먼저 버전 assertion. `test_skill_orchestration_behavior.sh`의 150–151행:

old:
```bash
# Version bumped to 2.2.0 (final summary).
assert_line "v2.2.0 in SKILL" "$(first_line 'v2.2.0|2\.2\.0')"
```
new:
```bash
# Version bumped to 2.3.0 (title + final summary).
assert_line "v2.3.0 in SKILL" "$(first_line 'v2.3.0|2\.3\.0')"
```

다음, ordering assertion 블록을 **persona check 직후(239행 `done` 다음, 241행 `if [[ "$fail" -eq 0 ]]` 직전)**에 삽입:

```bash
# --- v2.3.0 R4: Review-gate findings surfaced before the decision tool ---
# The Surface-findings step (Step 4.5) must precede the iter-boundary
# decision's `findings remain` question. Anchor on the surface-step TEXT,
# NOT the `## Review gate` section heading — a heading always precedes its
# body, so a heading anchor is a tautological PASS (the V7-class defect this
# file was created to avoid). Existence grep alone cannot catch mis-placement.
surface_line=$(first_line 'Surface findings|Step 4\.5')
question_line=$(first_line 'question:.*findings remain')
assert_line "Surface-findings step present" "$surface_line"
assert_order "Surface findings precedes iter-boundary decision" "$surface_line" "$question_line"
```

- [ ] **Step 2: behavior 테스트 실행 → RED 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"
```
Expected: `exit=1`. 실패 항목:
- `FAIL: v2.3.0 in SKILL` — SKILL은 아직 2.2.0.
- `FAIL: Surface-findings step present` (surface_line=0) + `FAIL: Surface findings precedes iter-boundary decision` (earlier=0).

- [ ] **Step 3: SKILL.md 제목 버전 갱신 (line 37)**

old:
```markdown
# Quality Gates — In-Turn Orchestrator (v2.2.0)
```
new:
```markdown
# Quality Gates — In-Turn Orchestrator (v2.3.0)
```

- [ ] **Step 4: SKILL.md Final Summary 버전 갱신 (line 538)**

old:
```markdown
## Quality Gates Pipeline — Complete (v2.2.0)
```
new:
```markdown
## Quality Gates Pipeline — Complete (v2.3.0)
```

- [ ] **Step 5: SKILL.md Review gate steps 4–5 → Step 4.5 surface + kept-기준 boundary**

현재 249–257행 블록:
```markdown
4. Dispatch `quality-gates:synthesizer` (or local synthesize_findings.py)
   to consolidate findings.
5. Compute boundary outcome:
   - findings empty → print `## Review gate iter N: clean` and exit the loop (continue to the Runtime gate).
   - findings non-empty → invoke [Review iter boundary decision](#review-iter-boundary-decision).

If iteration N=5 ends with findings still non-empty: invoke
[Review max-iter decision](#review-max-iter-decision) instead of the
normal iter-boundary decision.
```
를 아래로 **교체**:
```markdown
4. Dispatch `quality-gates:synthesizer` (or local synthesize_findings.py)
   to consolidate findings. **Capture the script's complete stdout** — the
   synthesized Markdown block (counts line + findings table + suggested-fixes
   list, or the empty-state line). You surface this verbatim in step 4.5; do
   NOT reformat or re-summarize it yourself (Law 1 determinism — the script,
   not the orchestrator, owns the rendering).

   **Step 4.5 — Surface findings.** Judge the boundary on the **kept
   (displayed) finding count**, read from the `**Findings:**` counts line in
   that stdout — NOT the raw reviewer count. Three cases:
   - **kept > 0** (the counts line totals ≥ 1 across the three severities) →
     emit the captured stdout to the user as a deliberate assistant message,
     prepended with the single context line `## Review gate iter N — Findings`,
     **before** invoking the decision tool. Then go to step 5.
   - **kept = 0 AND suppressed > 0** (counts all zero; stdout is the
     `No high-confidence findings. N low-confidence findings suppressed.` line
     with N > 0) → no high-confidence finding to act on → treat as **clean**:
     do NOT call AskUserQuestion. Surface only that single
     `No high-confidence findings…` line for transparency, then continue the
     loop / proceed to the Runtime gate.
   - **kept = 0 AND suppressed = 0** → print `## Review gate iter N: clean` and
     exit the loop (continue to the Runtime gate).

5. **Decision tool (kept > 0 only).** Invoke [Review iter boundary
   decision](#review-iter-boundary-decision). Fill its `<summary>` slot by
   **verbatim-copying the `**Findings:**` counts line** from step 4's stdout
   (deterministic extraction — do NOT author a fresh sentence). Append one
   `## History` line of the form
   `Review gate iter N: <c> CRITICAL / <i> IMPORTANT / <s> SUGGESTION → user chose <choice>`
   (severity triplet copied from the same counts line; see
   [state-file-format](references/state-file-format.md#history)).

If iteration N=5 ends with kept > 0: run step 4.5's surface first (same as
above), then invoke [Review max-iter decision](#review-max-iter-decision)
instead of the normal iter-boundary decision. Fill that template's
`Last findings: <summary>` slot with the same verbatim counts line (the
template text itself is unchanged).
```

> 이 블록은 리터럴 `findings remain`을 쓰지 않는다(surface는 `Findings:` 사용) → V2b 유일성(question 라인 1개) 보존. anchor 텍스트 `Step 4.5` / `Surface findings`가 SKILL에서 처음 등장하는 곳이 이 블록이어야 한다(Step 7에서 grep으로 확인).

- [ ] **Step 6: behavior + orchestration 테스트 실행 → GREEN 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"
bash plugins/quality-gates/tests/test_skill_orchestration.sh; echo "exit=$?"
```
Expected: 둘 다 `exit=0`. behavior: `PASS: v2.3.0 in SKILL`, `PASS: Surface-findings step present`, `PASS: Surface findings precedes iter-boundary decision`. orchestration: `PASS V2b (anchor uniqueness: 1 question line)` 유지.

- [ ] **Step 7: anchor 선점 + 잔존 2.2.0 부재 검증**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
S=plugins/quality-gates/skills/quality-pipeline/SKILL.md
echo "--- surface anchor first match (should be the Step 4.5 line) ---"
grep -nE 'Surface findings|Step 4\.5' "$S" | head -1
echo "--- residual 2.2.0 in SKILL (should be empty) ---"
grep -nE 'v?2\.2\.0' "$S" || echo "(none — good)"
```
Expected: 첫 매치가 `**Step 4.5 — Surface findings.**` 라인. 잔존 2.2.0 `(none — good)`.

- [ ] **Step 8: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "feat(quality-gates): surface findings table before Review-gate decision (R4)"
```

---

## Task 4: 메타데이터 동기화 — plugin.json + CHANGELOG + state-file-format

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json:4`
- Modify: `plugins/quality-gates/CHANGELOG.md` (line 5 뒤 새 항목)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md:40`

- [ ] **Step 1: plugin.json 버전 bump**

`plugins/quality-gates/.claude-plugin/plugin.json`:
old:
```json
  "version": "2.2.0",
```
new:
```json
  "version": "2.3.0",
```

- [ ] **Step 2: state-file-format.md History 예시 동기화 (line 40)**

old:
```markdown
- [2026-05-27T10:05:00Z] Review gate iter 1: FAIL → user chose Retry
```
new:
```markdown
- [2026-05-27T10:05:00Z] Review gate iter 1: 1 CRITICAL / 2 IMPORTANT / 1 SUGGESTION → user chose Retry
```
(41행 `Review gate iter 2: PASS`는 clean iter라 무변경.)

- [ ] **Step 3: CHANGELOG `[2.3.0]` 항목 추가**

`plugins/quality-gates/CHANGELOG.md` 5행(`SemVer ... 따릅니다.`) 다음, 6행 `## [2.2.0]` **앞에** 삽입:

```markdown
## [2.3.0] — 2026-06-04

Review gate가 각 iteration 종료 시 `synthesize_findings.py`의 finding 상세(표 +
counts + suggested fixes)를 결정 tool **이전에** 사용자에게 surface한다. 이전에는
AskUserQuestion `<summary>` 한 줄만 노출됐고 상세는 접힌 tool 출력에 묻혔다.
가시성=명확성(Law 1) 개선이며 reviewer persona(`agents/*.md`)는 무변경(보안 리뷰 불필요).

### Added
- **`synthesize_findings.py` 표 렌더**: `render()`가 불릿 목록 대신 Markdown 표
  `| Sev | Path:Line | Conf | Summary | Source |` + `**Findings:**` counts 헤더
  (severity별 count, 항상 3-severity) + 표 밖 `**Suggested fixes:**` 리스트를 emit.
- **SKILL Review gate `Step 4.5 — Surface findings`**: kept(표시) finding 수 기준으로
  boundary를 판정하고, kept>0이면 script stdout 전체를 결정 tool 직전 surface.
  AskUserQuestion `<summary>`·`## History` 항목은 counts line을 verbatim 추출.
- **신규 테스트**: `test_synthesize_findings.sh` counts/caveat/suppressed-notice/
  fixes/conf-boundary 케이스, `test_skill_orchestration_behavior.sh` surface-순서
  `assert_order`(section-heading anchor 금지).

### Changed
- **confidence rubric (C30 4-tier)**: `suppress()`가 binary(conf<7 억제)에서 3-way로 —
  conf 5–6은 표시하되 `*` caveat, conf ≤4 비-CRITICAL만 억제, CRITICAL은 confidence
  무관 항상 표시(conf ≤6이면 `*`). caveat 단일 규칙: 표시된 finding의 confidence ≤ 6 ⟺ `*`.
- **`## History` 라인 포맷**: gate verdict 단어 대신 severity count
  (`iter N: 1 CRITICAL / 2 IMPORTANT / 1 SUGGESTION → user chose Retry`).
  `references/state-file-format.md` 예시 동기화.
- **버전 2.2.0 → 2.3.0** (minor, 새 surface): `plugin.json`, SKILL 제목 + Final
  Summary, `test_skill_orchestration_behavior.sh` 버전 assertion 동기화.
```

- [ ] **Step 4: 메타데이터 정합 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
python3 -c "import json;print('plugin.json:', json.load(open('plugins/quality-gates/.claude-plugin/plugin.json'))['version'])"
grep -n '## \[2.3.0\]' plugins/quality-gates/CHANGELOG.md
grep -n 'CRITICAL / 2 IMPORTANT' plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md
```
Expected: `plugin.json: 2.3.0`; CHANGELOG `[2.3.0]` 라인 출력; state-file 예시 출력.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md
git commit -m "docs(quality-gates): v2.3.0 bump + CHANGELOG + History format (R4)"
```

---

## Task 5: 전체 회귀 + self-review

**Files:** (없음 — 검증만)

- [ ] **Step 1: 전체 qg 테스트 재실행, baseline과 대조**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in plugins/quality-gates/tests/*.sh plugins/quality-gates/tests/harness/*.sh; do
  bash "$t" >/dev/null 2>&1 && echo "PASS $t" || echo "FAIL $t"
done | sort > /tmp/qg-after-r4.txt
echo "=== diff (baseline vs after; 줄이 없어야 신규 회귀 0) ==="
diff /tmp/qg-baseline-r4.txt /tmp/qg-after-r4.txt && echo "NO DIFF — 신규 red 0"
```
Expected: `NO DIFF — 신규 red 0`. baseline의 stale red set과 동일(R4가 새 red를 만들지 않음). 만약 `test_synthesize_findings.sh` / `test_skill_orchestration*.sh`가 baseline에서 PASS였다가 FAIL로 바뀌면 회귀 — 해당 Task로 돌아가 수정.

- [ ] **Step 2: spec Acceptance Criteria 대조 (수동 체크리스트)**

각 AC가 어느 테스트/변경으로 충족되는지 확인:
- AC-R4-1 표 emit → `AC38 table header`
- AC-R4-2 counts 항상-3-severity → `ACR4 counts zero-fill`
- AC-R4-3 conf≤6 caveat / ≥7 no marker / ≤4 비-CRIT suppress → `AC36a`, `ACR4 conf6/conf7 boundary`
- AC-R4-4 CRITICAL 항상 표시(+caveat) → `AC36b`
- AC-R4-5 fixes 표 밖 → `ACR4 fixes block`
- AC-R4-6 정렬 sev→conf→file → `AC37 sort CRIT<SUG`
- AC-R4-7 empty 메시지 → `AC39 empty`
- AC-R4-8 surface가 `findings remain` 앞 → `assert_order` (Task 3 Step 6)
- AC-R4-9 `findings remain` 1개 question → `test_skill_orchestration.sh` V2b
- AC-R4-10 버전 3-사이트 + CHANGELOG + state-file → Task 3 Step 7 + Task 4 Step 4
- AC-R4-11 kept=0&suppressed>0 clean / kept=0&suppressed=0 clean → SKILL Step 4.5 (수동 smoke, Step 4)

- [ ] **Step 3: 수동 smoke (AC 비포함, 권장)**

근거: 전체 `/qg` e2e는 live agent dispatch가 필요해 unit-test 불가. findings를 유발하는 작은 diff(예: SQL-concat fixture류)에서 `/qg review` 실행 후 **성공 기준**: (a) 표 블록이 AskUserQuestion **이전** assistant 메시지로 출력, (b) `<summary>`가 stdout의 `**Findings:**` counts line과 글자 그대로 일치. 시간이 없으면 skip 가능(자동 테스트가 표/순서/버전을 이미 lock).

- [ ] **Step 4: self-review (fresh eyes)**

- placeholder/TODO 잔존 없는지 `synthesize_findings.py` / SKILL 변경부 확인.
- `clearLayers`/`clearFullLayers`류 식별자 불일치 없는지: `suppress()` 반환 `(kept, suppressed)` ↔ `main()` 언팩 ↔ `render(kept, len(suppressed))` 시그니처 일치 확인.
- emit 문자열에 non-ASCII `≤` 없는지(ASCII `<=`만): `grep -n '≤' plugins/quality-gates/scripts/synthesize_findings.py` → 결과 없어야 함.

- [ ] **Step 5: 최종 커밋 정리 (필요 시)**

self-review에서 수정이 생기면 해당 파일을 적절한 Task 메시지 컨벤션으로 추가 커밋. 없으면 skip. PR은 사용자 요청 시에만 생성(branch `feature/qg-r4-findings-detail` → `main`, merge commit).

---

## Self-Review (plan 작성자 체크리스트)

**Spec coverage:** Goals 1–5 모두 매핑 — (1) surface=Task 3 Step 5, (2) 표 컬럼=Task 2 render, (3) C30 rubric=Task 2 suppress + caveat, (4) History severity-count=Task 3 Step 5 + Task 4 Step 2, (5) persona 무변경=전 Task에서 `agents/*.md` 미터치. AC-R4-1..11 전부 Task 5 Step 2에 추적. Files to Modify 7개 파일 전부 Task에 등장(+ `test_skill_orchestration.sh`는 regression-only로 명시).

**Placeholder scan:** 모든 코드/edit 스텝에 실제 내용(코드 블록·old/new 리터럴) 포함. "적절히 처리"류 없음.

**Type consistency:** `suppress() → (kept, suppressed)` (list, list) → `main()` `kept, suppressed = suppress(...)` → `render(kept, len(suppressed))`. `render(findings, suppressed_count)` 시그니처 불변. counts-line/caveat/notice 리터럴이 Task 2 테스트 패턴과 Locked-strings 섹션 간 글자 단위 일치(probe로 검증된 패턴 사용). behavior 테스트 anchor `Surface findings|Step 4\.5` ↔ SKILL `**Step 4.5 — Surface findings.**` 일치.
