# qg Review gate 스코프-구동 리뷰어 구성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** quality-gates Review gate가 리뷰어를 고정 로스터로 디스패치하던 것을, 오케스트레이터가 diff 스코프로 선택(모델 판단 + scout 힌트 + review-pr §4 rubric + scope-signal 팔레트)하도록 재배선하고, scout/SKILL/README 3자 drift를 정합한다. **qg 에이전트의 tool posture·Law 2 집행은 손대지 않는다(#104 `Read, Grep, Glob` 락 유지).**

**Architecture:** 순수 **라우팅** 기능이다. 3-tier 리뷰어 모델 — Tier A floor(security-reviewer + adversarial, 스코프 무관 항상) / Tier B codex(availability-floor) / Tier C 전문가(pr-review-toolkit 5 + feature-dev:code-architect, 스코프로 가감, 최대 6). 선택은 model-owned(lightness — 결정론 selector 스키마 없음). 결정론은 floor 불변·transparency·rubric-embed에만. scout.py는 권위 selector에서 힌트 provider로 강등(로직·테스트 유지) + `docs_touched` 신호 추가.

**Tech Stack:** Bash grep-lock 테스트(섹션-스코프 + mutation-teeth), Python3(scout.py + 그 단위 테스트는 bash), Markdown(SKILL.md/README.md/CHANGELOG.md), JSON(plugin.json). 새 런타임 의존성 0.

---

## Global Constraints

이 섹션의 값은 **spec에서 verbatim 복사**했다. 모든 task의 요구사항에 암묵적으로 포함된다.

- **qg 에이전트 tool posture 무변경.** `agents/security-reviewer.md`·`agents/adversarial.md`의 `tools:`는 `Read, Grep, Glob`(#104 락) 그대로. 이 두 파일은 **이 작업에서 편집하지 않는다.** Bash/Web/Write 부여 없음. (spec §3, §7 "건드리지 않는 파일")
- **건드리지 않는 파일(명시):** `agents/security-reviewer.md`, `agents/adversarial.md`, `agents/runtime-verifier.md`, `scripts/synthesize_findings.py`, `CLAUDE.md`, `docs/philosophy/*.md`, Runtime gate 스크립트. (spec §7)
- **SAST/CVE 능동 스캔 없음** · **mutation 감지 가드 없음** · **Law 2 / P3 원장 개정 없음** · **security-auditor graft 없음**(별도 후속 spec) · **fan-out consent 게이트 없음** · **`code-simplifier` 편입 없음**(writer) · **수치 0–100 스코어링 미도입**(qg 1–10 confidence 유지) · **외부 에이전트 `model:` override 없음**. (spec §3)
- **선택은 model-owned routing** — 결정론 selector I/O 스키마를 **신설하지 않는다**(lightness, spec §9 기각). 테스트 표면은 floor 불변(AC1) + codex availability(AC2) + rubric/팔레트 embed(AC3/AC4) + transparency(AC8)만. "어떤 전문가를 뽑았는가"는 게이트하지 않는다.
- **model 하드코딩 존중** — code-reviewer=opus, code-architect=sonnet, 전문가=inherit 그대로. 외부 에이전트 dispatch에 `model:` override 넣지 않는다.
- **버전:** `plugin.json` 2.12.0 → **2.13.0**(minor). **doc convention:** Korean-primary. SKILL H1 marker(`v2.7.0`)는 **바꾸지 않는다**(repo 컨벤션 = H1 marker ≠ plugin.json; `test_skill_orchestration_behavior.sh:154`가 `v2.7.0`을 핀; 이미 2.8–2.12를 통해 v2.7.0으로 남아 있음).
- **branch:** `feature/qg-scope-driven-reviewers` (base main @ `9d41efd` = #104 머지 후). 이미 이 브랜치에 있음(spec HEAD `a88c539`).

### Pre-flight baseline (작업 시작 전 이미 확인됨 — 재실행으로 재확인)

repo root(`/Users/jeonghokim/Downloads/devbrew`)에서 `bash plugins/quality-gates/tests/<t>.sh` 실행 기준:

- **Pre-existing RED (stale — 옛 SKILL 구조를 pin; 이 작업이 회복):**
  - `test_codex_dispatch_invariant.sh` — 존재하지 않는 `codex_manifest.codex_available == true/false` 프로즈를 grep. **Task 4에서 새 3-tier 구조로 재작성.**
  - `test_scout_codex_integration.sh` — checks 1–5는 GREEN, Scenario 5(`#### Phase 1 (unified dispatch)` 헤딩)만 RED. **Task 4에서 Scenario 5 갱신.**
- **GREEN (반드시 유지):** `test_scout_script`, `test_security_reviewer_persona`(floor tools 정확값 핀 `^tools: Read, Grep, Glob$`), `test_adversarial_persona`(동일), `test_agent_tools_lock_mutation`, `test_agent_frontmatter_keys`, `test_law2_prose`, `test_skill_orchestration_behavior`(harness), `test_artifact_metadata`, `test_qg_publish_docs`.

> **AC7(tool posture 무변경)은 새 테스트가 필요 없다.** `test_security_reviewer_persona.sh:58`과 `test_adversarial_persona.sh:58`이 이미 `grep -c '^tools: Read, Grep, Glob$' == 1`을 단언하고, `test_agent_tools_lock_mutation.sh`가 YAML-우회 whitelist(34 mutation)를 지킨다. AC7 = **이 두 agent 파일을 편집하지 않아 이 테스트들이 GREEN으로 남는 것.** Task 5가 이를 회귀 확인한다.

---

## File Structure

| 파일 | 책임 | Task |
|---|---|---|
| `plugins/quality-gates/.claude-plugin/plugin.json` | version 2.13.0 | 1 |
| `plugins/quality-gates/CHANGELOG.md` | `## [2.13.0]` 엔트리 | 1 |
| `plugins/quality-gates/scripts/scout.py` | `docs_touched` 입력 → comment-analyzer phase2 힌트 | 2 |
| `plugins/quality-gates/tests/test_scout_script.sh` | AC5 — docs_touched 단위 케이스 | 2 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | Review gate dispatch 3-tier 재작성 + 새 `## Reviewer composition (scope-driven)` 섹션. **tool 변경 없음.** | 3 |
| `plugins/quality-gates/tests/test_review_floor_lock.sh` | **신규** — AC1 floor 불변 mutation-teeth | 3 |
| `plugins/quality-gates/tests/test_review_scope_composition.sh` | **신규** — AC3/AC4/AC6/AC8/AC11 + AC13/AC14 negative | 3 |
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | 프록시미티 bound만 완화(160) — locality sanity, 비-load-bearing | 3 |
| `plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` | **재작성** — AC2 codex Tier B availability-floor | 4 |
| `plugins/quality-gates/tests/test_scout_codex_integration.sh` | Scenario 5 갱신(옛 unified-heading → 새 3-tier prose) | 4 |
| `plugins/quality-gates/README.md` | §166 3-tier 재작성 + fan-out 게이트 주장 whole-file reconcile + prerequisites | 4 |
| `plugins/quality-gates/tests/test_readme_scope_reconcile.sh` | **신규** — AC9/AC10 | 4 |

---

## Task 1: Version bump + CHANGELOG (AC12)

버전 bump를 **가장 먼저** 한다 — plugin을 건드리는 변경이므로 같은 브랜치에서 cache-key bump가 붙어야 하고([[feedback_plugin_version_bump]]), `test_qg_publish_docs.sh`가 plugin.json의 현재 minor에 대응하는 CHANGELOG 섹션을 요구하므로 둘을 함께 랜딩한다.

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json:4`
- Modify: `plugins/quality-gates/CHANGELOG.md:6` (새 섹션 삽입)
- Test: `plugins/quality-gates/tests/test_qg_publish_docs.sh` (기존 — 갱신 없음, 커플링 검증), `plugins/quality-gates/tests/test_artifact_metadata.sh` (기존)

**Interfaces:**
- Produces: `plugin.json` version = `2.13.0`; `CHANGELOG.md`에 `## [2.13.0] — 2026-07-19` 섹션(Added/Changed/Principles Instantiated). 이후 모든 task는 2.13.0 위에서 커밋됨.

- [ ] **Step 1: 버전 bump 전 커플링 테스트가 GREEN인지 확인 (baseline)**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_qg_publish_docs.sh`
Expected: PASS (현재 2.12.0 ↔ CHANGELOG [2.12.0] 정합).

- [ ] **Step 2: plugin.json version을 2.13.0으로 bump**

`plugins/quality-gates/.claude-plugin/plugin.json`의 `"version": "2.12.0"`를 아래로:

```json
  "version": "2.13.0",
```

- [ ] **Step 3: 버전만 bump한 상태에서 커플링 테스트가 RED가 되는지 확인 (teeth 증명)**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_qg_publish_docs.sh`
Expected: **FAIL** — `CHANGELOG missing entry for plugin.json current minor 2.13`. 이 RED가 AC12 락의 이빨(버전 bump ↔ CHANGELOG 커플링)을 증명한다.

- [ ] **Step 4: CHANGELOG.md에 [2.13.0] 섹션 삽입**

`plugins/quality-gates/CHANGELOG.md`의 line 5(`## [2.12.0] — 2026-07-19` 바로 위)에 아래 블록을 삽입한다(기존 [2.12.0] 섹션은 그대로 유지):

```markdown
## [2.13.0] — 2026-07-19

Review gate 리뷰어 구성을 **고정 로스터 → 스코프-구동 동적 구성**으로 전환. 오케스트레이터가
diff 스코프로 Tier C 전문가를 선택(모델 판단 + scout 힌트 + review-pr §4 rubric + scope-signal
팔레트)하고, 고정 보안 floor(security-reviewer + adversarial)와 codex availability-floor는
스코프 무관 항상 유지. **qg 에이전트 tool posture는 #104 락(`Read, Grep, Glob`) 그대로 무변경** —
순수 라우팅 기능.

### Added
- Review gate 3-tier 리뷰어 구성: Tier A floor(security-reviewer + adversarial, 항상) /
  Tier B codex(availability-floor) / Tier C 스코프-선택 전문가(pr-review-toolkit 5 +
  feature-dev:code-architect, 최대 6 후보).
- review-pr §4 rubric(스코프 신호 → 전문가 매핑) + scope-signal 팔레트(역직렬화·인젝션·XSS·
  crypto·TLS·XXE·GHA·SRI·deps·migration·public-API·삭제 파일) SKILL embed.
- 매 iteration 선택/제외 transparency 라인(`> [quality-gates] Review iter N — 선택:… / 제외:…`).
- scout `docs_touched` 입력 신호(경계 = filter-docs.sh doc-path 집합) → docs 변경 시
  comment-analyzer를 phase2 힌트로.
- Tier C 미설치 시 graceful degradation loud log(floor + codex는 무영향).

### Changed
- scout.py를 권위 selector에서 **힌트 provider로 강등**(결정론 로직·테스트 유지; 선택은 모델 판단).
- README §166 Review 단계를 3-tier 모델로 재작성 + prerequisites에 pr-review-toolkit·feature-dev를
  Tier C optional dependency로 선언.
- README의 fan-out consent 게이트(`len(phase1)+len(phase2)>=4 → AskUserQuestion`) 주장을 전 위치에서
  reconcile — 이 게이트는 구현된 적 없다(documented-not-implemented). P22 instantiation을
  transparency 라인 + 선언된 max fan-out(phase-1 병렬 ≤ 8, 총/iteration ≤ 10) + authoring
  hard-review 기반으로 restate.
- stale RED 회복: `test_codex_dispatch_invariant.sh`·`test_scout_codex_integration.sh`를 새
  3-tier dispatch 구조에 맞게 갱신.

### Principles Instantiated
- P8 (determinism-economy / harness lightness) — 리뷰어 선택은 model-owned routing; 결정론은
  floor 불변·transparency·rubric-embed에만.
- Law 2 (Writer ≠ Reviewer) — qg floor tool posture 무변경(#104 `Read, Grep, Glob` 락 유지).
- Law 3 (Compounding) — scout 힌트·rubric·팔레트가 미래 리뷰어 선택의 학습 substrate.

```

- [ ] **Step 5: 커플링 테스트가 다시 GREEN인지 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_qg_publish_docs.sh && bash plugins/quality-gates/tests/test_artifact_metadata.sh`
Expected: 둘 다 PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "chore(quality-gates): v2.13.0 version bump + CHANGELOG (scope-driven reviewer composition)"
```

---

## Task 2: scout.py `docs_touched` 신호 (AC5)

scout를 힌트 provider로 유지하되 docs 변경 신호를 추가한다 — 현재 scout에 docs 신호가 없어 comment-analyzer가 결정론 힌트로 안 나오던 gap을 해소. **판정 경계 = `scripts/filter-docs.sh`가 docs로 분류하는 path 집합**(오케스트레이터가 boolean을 계산해 stdin으로 넘김; scout는 라우팅만).

**Files:**
- Modify: `plugins/quality-gates/scripts/scout.py:9-24` (docstring), `:29-64` (decide)
- Test: `plugins/quality-gates/tests/test_scout_script.sh`

**Interfaces:**
- Consumes: stdin JSON에 새 optional key `docs_touched: bool`(기본 false).
- Produces: `docs_touched == true`이면 `phase2_agents`에 `comment-analyzer` 포함(depth 무관 — 작은 순수-docs diff는 quick depth지만 여전히 comment 전문가 힌트가 필요). 기존 depth/phase1/phase2 로직 불변.

- [ ] **Step 1: 실패하는 테스트 추가**

`plugins/quality-gates/tests/test_scout_script.sh`의 line 46(`echo ""` 바로 위, 마지막 `run_case` 다음)에 아래를 삽입한다:

```bash
# --- AC5 (v2.13.0): docs_touched → comment-analyzer phase2 hint ---
# 경계 = filter-docs.sh doc-path 집합(오케스트레이터가 boolean 계산); scout는 라우팅만.
phase2_has() {  # phase2_has <json> <token> <PRESENT|ABSENT>
  local out; out=$(echo "$1" | python3 "$SCRIPT")
  local p2; p2=$(echo "$out" | grep '^phase2_agents:')
  if echo "$p2" | grep -q "$2"; then local got=PRESENT; else local got=ABSENT; fi
  if [[ "$got" == "$3" ]]; then
    echo "PASS: docs_touched case — '$2' $3 ($p2)"; PASS=$((PASS+1))
  else
    echo "FAIL: docs_touched case — '$2' want $3 got $got ($p2)"; FAIL=$((FAIL+1))
  fi
}

# quick-depth pure-docs diff still surfaces comment-analyzer (gap closure).
phase2_has '{"changed_lines": 10, "docs_touched": true}' 'comment-analyzer' PRESENT
# standard-depth docs change → comment-analyzer present.
phase2_has '{"changed_lines": 80, "docs_touched": true}' 'comment-analyzer' PRESENT
# no docs → comment-analyzer absent (no false hint).
phase2_has '{"changed_lines": 80, "docs_touched": false}' 'comment-analyzer' ABSENT
# docs_touched omitted entirely → absent (default false, backward-compat).
phase2_has '{"changed_lines": 80}' 'comment-analyzer' ABSENT
# deep + docs + type_design → both hints coexist.
phase2_has '{"changed_lines": 300, "type_design": true, "docs_touched": true}' 'comment-analyzer' PRESENT
phase2_has '{"changed_lines": 300, "type_design": true, "docs_touched": true}' 'type-design-analyzer' PRESENT
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_scout_script.sh`
Expected: FAIL — docs_touched 케이스들이 `comment-analyzer ABSENT`로 나옴(아직 미구현). 기존 5 케이스는 PASS 유지.

- [ ] **Step 3: scout.py 구현 — docstring 갱신**

`plugins/quality-gates/scripts/scout.py`의 docstring Input 블록(line 10-16)을 아래로 교체한다:

```python
Input (stdin JSON):
  {
    "changed_lines": int,
    "new_files": int,
    "config_touched": bool,
    "type_design": bool,
    "test_change": bool,
    "docs_touched": bool
  }
```

- [ ] **Step 4: scout.py 구현 — decide()에 docs_touched 배선**

`decide(s)`의 입력 파싱부(line 30-34, `test_change = ...` 다음 줄)에 추가:

```python
    docs_touched = bool(s.get("docs_touched", False))
```

그리고 `phase2` 블록(line 57-64)의 끝, `return {` 바로 앞에 추가:

```python
    # docs_touched surfaces comment-analyzer as a phase2 hint regardless of
    # depth — a small pure-docs diff is quick-depth but still wants the comment
    # specialist. Boundary = filter-docs.sh doc-path set (the orchestrator
    # computes this boolean; scout only routes it). AC5.
    if docs_touched:
        phase2.append("comment-analyzer")
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_scout_script.sh`
Expected: PASS — 전체(기존 5 depth 케이스 + 6 docs_touched 케이스). `Total: ..., PASS=..., FAIL=0`.

- [ ] **Step 6: scout-integration 테스트가 여전히 GREEN 부분 유지하는지(회귀 없음) 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_scout_codex_integration.sh; echo "exit=$?"`
Expected: 여전히 RED(Scenario 5만 — Task 4에서 고침), 단 checks 1–5(scout.md 부재, scout.py 존재/실행가능, SKILL이 scout.py 참조 등)는 PASS 유지. scout.py 변경이 새 회귀를 만들지 않았음을 확인.

- [ ] **Step 7: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/scripts/scout.py plugins/quality-gates/tests/test_scout_script.sh
git commit -m "feat(quality-gates): scout docs_touched → comment-analyzer phase2 hint (AC5)"
```

---

## Task 3: SKILL Review gate 3-tier dispatch 재작성 (AC1, AC3, AC4, AC6, AC8, AC11, AC13, AC14)

Review gate step 3(dispatch)를 3-tier 스코프-구동 구성으로 재작성한다. **rubric/팔레트/depth 가이드라인/예시**의 벌크는 새 `## Reviewer composition (scope-driven)` 섹션으로 factor out하고, step 3에는 **floor Agent 블록 + Tier B codex + Tier C 선택 포인터 + transparency + graceful degrade**만 둔다 — 이렇게 해야 step 3의 성장이 작아 harness의 `iter cap near AskUserQuestion` locality bound가 satisfiable하게 유지된다. **tool 관련 변경 없음**(#104 락 유지).

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — step 3 재작성(현재 line 298-337) + 새 섹션 삽입(현재 `## Reviewer dispatch contract` 앞) + Contents 항목 추가
- Modify: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh:106` — proximity bound 120→160
- Create: `plugins/quality-gates/tests/test_review_floor_lock.sh` (AC1)
- Create: `plugins/quality-gates/tests/test_review_scope_composition.sh` (AC3/AC4/AC6/AC8/AC11/AC13/AC14)

**Interfaces:**
- Consumes: step 2 scout 출력(`depth`/`phase1_agents`/`phase2_agents`)을 **힌트**로.
- Produces (grep-lock 대상 body-unique 리터럴):
  - Floor anchor: `Tier A — Floor (스코프 무관, 항상 디스패치` (AC1)
  - `subagent_type: "quality-gates:security-reviewer"` + `subagent_type: "quality-gates:adversarial"` 블록 존치(project_dir 포함) (AC1, harness)
  - Tier B anchor: `Tier B — codex (availability-floor` (AC2, Task 4에서 grep)
  - `강한 default` (AC6), Tier C 6 전문가 이름(AC3), 팔레트 토큰(AC4)
  - Transparency: `> [quality-gates] Review iter N — 선택:` … `제외:` (AC8)
  - Graceful: `specialist` … `unavailable` … `degraded coverage` (AC11)

- [ ] **Step 1: AC1 floor-lock 테스트 신규 작성(실패 예정)**

`plugins/quality-gates/tests/test_review_floor_lock.sh` 생성:

```bash
#!/usr/bin/env bash
# AC1 (v2.13.0) — Review gate floor 불변 mutation-teeth.
# floor(security-reviewer + adversarial)는 스코프 무관 항상 디스패치되어야 하고,
# 모델이 스코프 판단으로 뺄 수 없어야 한다. 정적 grep-lock + 실 SKILL의 복사본을
# 변이시켜 RED가 나는지(=이빨)로 증명. RED가 안 나는 락은 장식이다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
PASS=0; FAIL=0

TMP="$(mktemp -d)" || { echo "FAIL: mktemp"; exit 1; }
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "FAIL: TMP invalid"; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# check_floor <skill-file> → exit 0 (GREEN, floor 불변식 성립) / 1 (RED)
check_floor() {
  local f="$1"
  # (i) floor "항상 디스패치" 선언(body-unique 리터럴).
  grep -qF '스코프 무관, 항상 디스패치' "$f" || return 1
  # (ii) 두 floor dispatch 블록 존재.
  grep -qF 'subagent_type: "quality-gates:security-reviewer"' "$f" || return 1
  grep -qF 'subagent_type: "quality-gates:adversarial"' "$f" || return 1
  return 0
}

expect() {  # expect <GREEN|RED> <file> <msg>
  if check_floor "$2"; then local got=GREEN; else local got=RED; fi
  if [ "$got" = "$1" ]; then PASS=$((PASS+1)); echo "  ✓ $3 ($got)"
  else FAIL=$((FAIL+1)); echo "  ✗ FAIL: $3 — want $1 got $got"; fi
}

echo "== 기준선: 실 SKILL은 floor 불변식 성립 =="
expect GREEN "$SKILL" "실 SKILL GREEN"

echo "== mutation: floor '항상 디스패치' 선언 삭제 → RED =="
grep -vF '스코프 무관, 항상 디스패치' "$SKILL" > "$TMP/m1.md"
expect RED "$TMP/m1.md" "floor always-선언 제거"

echo "== mutation: security-reviewer dispatch 제거 → RED =="
grep -vF 'subagent_type: "quality-gates:security-reviewer"' "$SKILL" > "$TMP/m2.md"
expect RED "$TMP/m2.md" "security-reviewer floor dispatch 제거"

echo "== mutation: adversarial dispatch 제거 → RED =="
grep -vF 'subagent_type: "quality-gates:adversarial"' "$SKILL" > "$TMP/m3.md"
expect RED "$TMP/m3.md" "adversarial floor dispatch 제거"

echo; echo "review-floor-lock: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

```bash
chmod +x /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/test_review_floor_lock.sh
```

- [ ] **Step 2: AC3/4/6/8/11/13/14 composition 테스트 신규 작성(실패 예정)**

`plugins/quality-gates/tests/test_review_scope_composition.sh` 생성:

```bash
#!/usr/bin/env bash
# AC3/AC4/AC6/AC8/AC11 (positive) + AC13/AC14 (negative) — v2.13.0
# Review gate 스코프-구동 구성 프로즈의 존재/부재 grep-lock.
# body-unique 문구를 요구(헤더-satisfiable 함정 회피). 선택 정확성은 게이트하지 않는다(lightness).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
PASS=0; FAIL=0
has()  { if grep -qF "$2" "$SKILL"; then PASS=$((PASS+1)); echo "  ✓ $1"; else FAIL=$((FAIL+1)); echo "  ✗ FAIL(present): $1 — '$2'"; fi; }
hasE() { if grep -qE "$2" "$SKILL"; then PASS=$((PASS+1)); echo "  ✓ $1"; else FAIL=$((FAIL+1)); echo "  ✗ FAIL(present): $1"; fi; }
absent(){ if grep -qF "$2" "$SKILL"; then FAIL=$((FAIL+1)); echo "  ✗ FAIL(absent): $1 — '$2' 잔존"; else PASS=$((PASS+1)); echo "  ✓ $1"; fi; }

echo "== AC3: Tier C rubric — 6 전문가 embed =="
has "code-reviewer 강한 default"      'pr-review-toolkit:code-reviewer'
has "silent-failure-hunter"           'silent-failure-hunter'
has "type-design-analyzer"            'type-design-analyzer'
has "pr-test-analyzer"                'pr-test-analyzer'
has "comment-analyzer"                'comment-analyzer'
has "feature-dev:code-architect"      'feature-dev:code-architect'

echo "== AC4: scope-signal 팔레트 토큰 =="
for tok in '역직렬화' '인젝션' 'XSS' 'crypto' 'TLS' 'XXE' 'GHA' 'SRI' 'deps' 'migration' 'public-API' '삭제 파일'; do
  has "팔레트 토큰: $tok" "$tok"
done

echo "== AC6: code-reviewer는 Tier C 강한 default (floor 아님) =="
has "강한 default 문구" '강한 default'
# floor(Tier A) 윈도우 안에 code-reviewer가 없어야 한다. Tier A anchor → Tier B anchor.
a_start=$(awk '/Tier A — Floor \(스코프 무관, 항상 디스패치/{print NR; exit}' "$SKILL")
a_end=$(awk -v s="$a_start" 'NR>s && /Tier B — codex \(availability-floor/{print NR; exit}' "$SKILL")
if [[ -n "$a_start" && -n "$a_end" ]] && ! awk -v s="$a_start" -v e="$a_end" 'NR>s && NR<e' "$SKILL" | grep -qF 'code-reviewer'; then
  PASS=$((PASS+1)); echo "  ✓ AC6: Tier A floor 윈도우($a_start..$a_end)에 code-reviewer 부재"
else
  FAIL=$((FAIL+1)); echo "  ✗ FAIL AC6: Tier A 윈도우에 code-reviewer 존재 또는 anchor 없음 (s=$a_start e=$a_end)"
fi

echo "== AC8: transparency 라인 (loud 정의) =="
has "transparency prefix"  '> [quality-gates] Review iter N — 선택:'
has "transparency 제외 절"  '제외:'

echo "== AC11: graceful degradation loud log =="
has "degrade: specialist"      'specialist'
has "degrade: unavailable"     'unavailable'
has "degrade: degraded coverage" 'degraded coverage'

echo "== AC13 (negative): 수치 0-100 스코어링 미도입 =="
absent "0-100 스코어링(하이픈)" '0-100'
absent "0–100 스코어링(엔대시)" '0–100'
absent "/100 스코어링"          '/100'

echo "== AC14 (negative): non-goal 가드 =="
absent "code-simplifier subagent_type 미등장" 'code-simplifier'
absent "security-auditor graft 미포함"        'security-auditor'
absent "secret-masking graft 미포함"          'secret-masking'
# Tier C 외부 dispatch에 model: override 부재 — 팔레트/rubric 섹션 윈도우 안에 'model:' 없어야.
c_start=$(awk '/## Reviewer composition \(scope-driven\)/{print NR; exit}' "$SKILL")
c_end=$(awk -v s="$c_start" 'NR>s && /^## /{print NR; exit}' "$SKILL")
if [[ -n "$c_start" && -n "$c_end" ]] && ! awk -v s="$c_start" -v e="$c_end" 'NR>s && NR<e' "$SKILL" | grep -qE '^[[:space:]]*model:'; then
  PASS=$((PASS+1)); echo "  ✓ AC14: composition 섹션에 model: override 부재"
else
  FAIL=$((FAIL+1)); echo "  ✗ FAIL AC14: composition 섹션에 model: override 존재 또는 섹션 없음 (s=$c_start e=$c_end)"
fi

echo; echo "review-scope-composition: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

```bash
chmod +x /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/test_review_scope_composition.sh
```

- [ ] **Step 3: 두 신규 테스트 실행 → 실패 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_review_floor_lock.sh; echo "floor exit=$?"
bash plugins/quality-gates/tests/test_review_scope_composition.sh; echo "comp exit=$?"
```
Expected: 둘 다 FAIL(아직 SKILL 미수정 — floor "항상 디스패치" 리터럴·rubric·팔레트·transparency 부재). floor-lock은 기준선 자체가 RED가 되어 `expect GREEN`이 실패한다.

- [ ] **Step 4: SKILL step 3(dispatch) 재작성**

`SKILL.md`에서 현재 step 3 전체를 교체한다. **교체 대상**: line 298의 `3. Dispatch reviewer subagents in parallel (per [Reviewer dispatch contract](#reviewer-dispatch-contract)).`부터 line 337의 codex 문단 끝(`...the orchestrator passes no additional argument for the codex path.`)까지. **step 4(`4. Dispatch quality-gates:synthesizer...`)는 그대로 둔다.**

교체 후 새 step 3(security-reviewer + adversarial Agent 블록은 기존과 동일하게 project_dir 포함 유지):

````markdown
3. **Compose and dispatch the reviewer set (scope-driven).** You (orchestrator)
   select which reviewers to dispatch this iteration from three tiers. Selection is
   **model-owned routing** (P8 lightness — not a deterministic gate): the floor is
   fixed, codex is an availability-floor, and Tier C specialists are chosen by the
   diff scope per [Reviewer composition (scope-driven)](#reviewer-composition-scope-driven).
   Re-select every iteration. **No qg-own tool posture changes here (#104 lock kept).**

   **Tier A — Floor (스코프 무관, 항상 디스패치; 모델이 스코프 판단으로 뺄 수 없음).**
   `quality-gates:security-reviewer` (Phase 1) and `quality-gates:adversarial`
   (Phase 1.5) run **every non-trivia iteration regardless of scope** — their `tools:`
   posture (`Read, Grep, Glob`, #104 lock) is unchanged. Both MUST include
   `project_dir: "$project_dir"`:

```
Agent({
  subagent_type: "quality-gates:security-reviewer",
  description: "Security review (Review gate iter N)",
  prompt: "Run code-level security review on the current diff.
    project_dir: \"$project_dir\"
    diff_scope: <the review scope you resolved at step 1: session (files.md set) / branch (git diff vs base) / paths (--paths globs)>
    plan_path: <path or 'auto'>
    iteration: N
    <…scout-supplied context…>"
})

Agent({
  subagent_type: "quality-gates:adversarial",
  description: "Adversarial review of Phase-1 findings (Review gate iter N)",
  prompt: "Re-review findings from Phase-1 reviewers for false positives
    and missed exploit paths.
    project_dir: \"$project_dir\"
    phase1_findings: <yaml from security-reviewer + code-reviewer + codex>
    iteration: N"
})
```

   **Tier B — codex (availability-floor: 있으면 무조건, 스코프 무관).** If the codex
   reviewer is available (`detect_codex.sh` returns true), it is dispatched via
   `run_codex_reviewer.sh` this iteration **regardless of scope** — model-family
   diversity is load-bearing. It re-derives scope from the inlined diff blob (build
   that blob from the review scope you resolved at step 1) and additionally injects
   the project spec's Acceptance Criteria into its `<spec_context>` slot, resolved
   **script-internally** by `run_codex_reviewer.sh` (via `discover-spec.sh`) — so no
   `spec_path` dispatch field and no `allowed-tools` change are needed.
   `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1` empties the slot (the script reads the env
   var directly). If codex is unavailable, continue without it — scope does not change
   this.

   **Tier C — Dynamic specialists (모델이 diff 스코프로 선택; 외부 advisory agent).**
   Choose zero or more from the menu in [Reviewer composition (scope-driven)](#reviewer-composition-scope-driven)
   by matching the diff to the rubric + scope-signal palette there.
   `pr-review-toolkit:code-reviewer` is the **강한 default** (Tier C, NOT floor):
   include it on any non-trivial diff; drop it only on a quick-depth diff. Tier C
   agents are advisory — you own fixes; their output is findings YAML. Do NOT thread a
   `model:` override into their dispatch (upstream model pinning is respected).

   **Transparency (loud — 매 iteration user-visible stdout 한 줄).** Emit exactly one
   line documenting the composition, so drops/degrades are never silent:

   > `> [quality-gates] Review iter N — 선택: <디스패치한 리뷰어 목록>(근거: <스코프 신호>) / 제외: <이유 또는 "해당 신호 없음">`

   **Graceful degradation (loud).** If a Tier C candidate is unavailable
   (pr-review-toolkit / feature-dev not installed), continue with floor(A) + codex(B) +
   whatever is installed, and print:

   > `> [quality-gates] specialist <X> unavailable (<plugin> 미설치) — degraded coverage`

   Floor and codex are **not** affected by this degrade. There is **no fan-out consent
   gate** (lightness) — fan-out is bounded by the rubric's natural signal-binding, the
   transparency line above, the recomputed max fan-out declared in the README, and the
   authoring-time hard-review (CLAUDE.md fan-out ≥5 gate).
````

- [ ] **Step 5: SKILL에 `## Reviewer composition (scope-driven)` 섹션 신설**

`SKILL.md`의 `## Reviewer dispatch contract`(현재 line 505) **바로 앞에** 아래 섹션을 삽입한다:

````markdown
## Reviewer composition (scope-driven)

The Review gate reviewer set is composed by scope (spec §5). Selection is
**model-owned** (lightness) — there is no deterministic selector schema; scout is a
hint, not an authority. The 3-tier model:

- **Tier A — Floor** (`quality-gates:security-reviewer` + `quality-gates:adversarial`):
  스코프 무관 항상. `tools: Read, Grep, Glob` (#104 락, 무변경). 모델이 못 뺀다.
- **Tier B — codex** (availability-floor): `detect_codex.sh` 참이면 무조건, 스코프 무관.
- **Tier C — Dynamic specialists** (아래 rubric으로 diff 스코프에 맞춰 가감; 최대 6 후보):

**rubric (review-pr §4 흡수):**

| 스코프 신호 | 전문가 |
|---|---|
| 비-trivial diff 기본 | `pr-review-toolkit:code-reviewer` (강한 default; quick-depth만 drop) |
| 에러핸들링 변경 | `pr-review-toolkit:silent-failure-hunter` |
| 타입 추가/변경 | `pr-review-toolkit:type-design-analyzer` |
| 테스트 파일 변경 | `pr-review-toolkit:pr-test-analyzer` |
| docs/주석 추가 | `pr-review-toolkit:comment-analyzer` |
| 대형 구조/아키텍처 변경 | `feature-dev:code-architect` |

**depth→Tier C 크기 가이드라인 (scout 힌트, 재현성 게이트 아님):** `quick` →
code-reviewer만(또는 없음); `standard` → + 신호-매칭 전문가 1–2; `deep` → + 신호-매칭
전문가(구조 변경이면 code-architect). scout의 `phase1_agents`/`phase2_agents`는 힌트일 뿐
권위가 아니다(Retry마다 재선택).

**scope-signal 팔레트 (모델 판단 보강, 결정론 아님; `security-guidance` 카테고리 출처):**
역직렬화(pickle/yaml/torch) · 인젝션(eval/exec/os.system/subprocess-shell) ·
XSS(innerHTML/dangerouslySetInnerHTML) · crypto(createCipher/AES-ECB) · TLS-verify-disabled ·
XXE · GHA-workflow-injection · SRI · deps-manifest 변경 · migration/schema · public-API 변경 ·
삭제 파일. 이 신호가 보이면 해당 전문가(또는 code-reviewer 프롬프트 힌트)를 풍부하게 고른다.

**비-규범 예시 (illustrative only — 테스트 대상 아님; 모델이 최종 판단):**

| diff 예 | scout depth | 예상 Tier C 선택 |
|---|---|---|
| 1-파일 버그픽스 | quick | code-reviewer |
| 기능 추가(에러핸들링+테스트) | standard | code-reviewer, silent-failure-hunter, pr-test-analyzer |
| 신규 모듈(새 타입+구조) | deep | code-reviewer, type-design-analyzer, code-architect |
| 순수 docs 개편 | standard | comment-analyzer (+ code-reviewer) |

**git-history/이전-PR 렌즈**는 이미 Bash-무장된 `pr-review-toolkit:code-reviewer`가 프롬프트
힌트로 수행한다 — qg-own 에이전트는 Bash/Web을 갖지 않는다(무변경). Tier C 외부 에이전트는
write-capable(pr-review-toolkit inherit-all)이거나 read/web-only(feature-dev:code-architect)이며
모두 advisory다(오케스트레이터가 fix 소유).

````

- [ ] **Step 6: SKILL Contents에 새 섹션 항목 추가(tidiness)**

`SKILL.md`의 `## Contents` 리스트, `- [Review gate](#review-gate) ...`(현재 line 64) 바로 다음 줄에 삽입:

```markdown
   - [Reviewer composition (scope-driven)](#reviewer-composition-scope-driven) — 3-tier + rubric + palette
```

- [ ] **Step 7: 두 신규 락 테스트 실행 → 통과 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_review_floor_lock.sh
bash plugins/quality-gates/tests/test_review_scope_composition.sh
```
Expected: 둘 다 PASS(`... failed` = 0).

- [ ] **Step 8: harness 테스트 실행 — proximity 회귀 확인 후 bound 완화**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; echo "exit=$?"`

Tier B/C 프로즈가 adversarial dispatch와 첫 후속 `AskUserQuestion` 사이 거리를 늘려
`iter cap near Review gate AskUserQuestion` assertion(bound 120)이 FAIL할 수 있다. FAIL하면
line 106의 bound를 완화한다 — `test_skill_orchestration_behavior.sh:106`:

```bash
assert_proximity "iter cap near Review gate AskUserQuestion" "$askuser_review_line" "$itercap_line" 160
```

그리고 line 103-105의 주석에 한 줄 추가(왜 완화했는지 — drift 방지):

```bash
# Locality bound 120→160 in v2.13.0 scope-driven-composition: step 3의 Tier B/C
# dispatch 프로즈(codex availability-floor + Tier C 선택 + transparency + graceful)가
# adversarial dispatch와 iter-boundary 결정 사이 영역을 정당하게 키움. 여전히 tight sanity.
```

Run 재실행: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: PASS(전체 protocol-shape assertions). **주의:** bound가 이미 충분하면(FAIL 안 나면) 이 완화를 하지 말 것 — 불필요한 테스트 약화 금지([[feedback_harness_lightness_trust_model]]).

- [ ] **Step 9: floor tools 핀(AC7) + 다른 SKILL-프로즈 회귀 없음 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_security_reviewer_persona test_adversarial_persona test_agent_tools_lock_mutation test_law2_prose; do
  bash plugins/quality-gates/tests/$t.sh >/dev/null 2>&1 && echo "GREEN $t" || echo "RED $t"
done
```
Expected: 4개 모두 GREEN(agents 미편집 → AC7 회귀 없음; SKILL 재작성이 law2-prose를 안 깸).

- [ ] **Step 10: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/tests/test_review_floor_lock.sh \
        plugins/quality-gates/tests/test_review_scope_composition.sh \
        plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "feat(quality-gates): scope-driven 3-tier reviewer composition in Review gate (AC1/3/4/6/8/11/13/14)"
```

---

## Task 4: stale 테스트 회복 + README 정합 (AC2, AC9, AC10)

두 pre-existing stale RED(`test_codex_dispatch_invariant.sh`, `test_scout_codex_integration.sh` Scenario 5)를 새 3-tier 구조에 맞게 회복하고(AC2 codex Tier B teeth 포함), README §166을 3-tier로 재작성하며 fan-out consent 게이트 주장을 whole-file reconcile한다(AC9/AC10).

**Files:**
- Rewrite: `plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` (AC2)
- Modify: `plugins/quality-gates/tests/test_scout_codex_integration.sh:59-120` (Scenario 5)
- Modify: `plugins/quality-gates/README.md` — §166(line 166-186) + fan-out 주장(line 15, 37-40, 127, 141, 186, 190, 240) + prerequisites
- Create: `plugins/quality-gates/tests/test_readme_scope_reconcile.sh` (AC9/AC10)

**Interfaces:**
- Consumes: Task 3의 SKILL Tier B anchor `Tier B — codex (availability-floor` + floor 블록.
- Produces: README `Phase 1 병렬 ≤ 8` + `총/iteration ≤ 10`(AC9 positive); §166 3-tier + prerequisites(AC10).

- [ ] **Step 1: AC2 codex-invariant 테스트 재작성**

`plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` 전체를 아래로 교체:

```bash
#!/usr/bin/env bash
# AC2 (v2.13.0) — codex is a Tier B availability-floor: dispatched whenever
# detect_codex is true, regardless of diff scope. SKILL.md prose invariant
# (proxy — real LLM dispatch is manual self-dogfood). Rewritten from the
# pre-2.13.0 `codex_manifest.codex_available == true/false` phase1_agents
# fallback structure, which the scope-driven rewrite removed.
set -u
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "OK: $1"; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

# 1. Tier B codex availability-floor prose present (body-unique anchor).
grep -qF 'Tier B — codex (availability-floor' "$SKILL" \
  || fail "1: SKILL missing Tier B codex availability-floor anchor"
ok "1: Tier B codex availability-floor anchor present"

# 2. codex is scope-independent (dispatched regardless of scope when available).
#    Anchor the '스코프 무관' claim within the Tier B window (Tier B anchor → next
#    '**Tier ' or '## ' heading) so it can't be satisfied by the Tier A floor line.
tb_start=$(awk '/Tier B — codex \(availability-floor/{print NR; exit}' "$SKILL")
tb_end=$(awk -v s="$tb_start" 'NR>s && (/\*\*Tier C/ || /^## /){print NR; exit}' "$SKILL")
if [[ -n "$tb_start" && -n "$tb_end" ]] && awk -v s="$tb_start" -v e="$tb_end" 'NR>s && NR<e' "$SKILL" | grep -qF '스코프'; then
  ok "2: codex dispatch is scope-independent (in Tier B window $tb_start..$tb_end)"
else
  fail "2: Tier B window lacks a scope-independence claim (s=$tb_start e=$tb_end)"
fi

# 3. codex dispatched via run_codex_reviewer.sh (script-based, T3-3 unchanged).
grep -qF 'run_codex_reviewer.sh' "$SKILL" \
  || fail "3: SKILL missing run_codex_reviewer.sh invocation"
ok "3: run_codex_reviewer.sh invocation present"

# 4. Floor dispatch blocks still thread project_dir (contract preserved through rewrite).
for name in security-reviewer adversarial; do
  awk -v name="quality-gates:$name" '
    $0 ~ name { found=NR }
    found && NR <= found+12 && /project_dir:/ { ok=1; exit }
    END { exit !ok }
  ' "$SKILL" || fail "4: floor dispatch block for $name lacks project_dir within 12 lines"
done
ok "4: floor dispatch blocks (security-reviewer + adversarial) thread project_dir"

# 5. Negative: the removed pre-2.13.0 fallback structure must be GONE.
for stale in 'codex_manifest.codex_available == false' 'codex_manifest.codex_available == true'; do
  if grep -qF "$stale" "$SKILL"; then
    fail "5: stale pre-2.13.0 codex_manifest prose still present — '$stale'"
  fi
done
ok "5: stale codex_manifest fallback prose absent (scope-driven rewrite)"

echo "PASS: test_codex_dispatch_invariant.sh (Tier B availability-floor, 5 checks)"
```

- [ ] **Step 2: 재작성한 codex-invariant 테스트 실행 → 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_codex_dispatch_invariant.sh`
Expected: PASS(5 checks). (Task 3의 SKILL Tier B 프로즈에 의존 — Task 3 완료 후 GREEN.)

- [ ] **Step 3: scout-integration Scenario 5 갱신**

`plugins/quality-gates/tests/test_scout_codex_integration.sh`의 Scenario 5 전체(line 59의 주석 `# Scenario 5 ...`부터 line 120의 `test_scenario_5_unified_dispatch` 호출까지)를 아래로 교체한다. checks 1–5(line 35-57)는 그대로 둔다:

```bash
# Scenario 5 (v2.13.0) — scope-driven 3-tier dispatch replaced the old
# `#### Phase 1 (unified dispatch)` heading structure. Guard the new prose so
# scout stays a HINT provider under the 3-tier model (not the authority).
test_scenario_5_scope_driven() {
  echo "=== Scenario 5: scope-driven 3-tier dispatch (v2.13.0) ==="
  local skill="$SKILL_MD"

  # 5a: old unified-dispatch heading must be GONE.
  if grep -qF '#### Phase 1 (unified dispatch)' "$skill"; then
    echo "  FAIL 5a: stale '#### Phase 1 (unified dispatch)' heading still present"
    fail=$((fail + 1))
  else
    echo "  PASS: 5a: stale unified-dispatch heading absent"
    pass=$((pass + 1))
  fi

  # 5b: Tier A floor anchor present (scope-independent floor).
  if grep -qF 'Tier A — Floor (스코프 무관, 항상 디스패치' "$skill"; then
    echo "  PASS: 5b: Tier A floor anchor present"; pass=$((pass + 1))
  else
    echo "  FAIL 5b: Tier A floor anchor missing"; fail=$((fail + 1))
  fi

  # 5c: scope-driven composition section present (rubric owner).
  if grep -qF '## Reviewer composition (scope-driven)' "$skill"; then
    echo "  PASS: 5c: Reviewer composition section present"; pass=$((pass + 1))
  else
    echo "  FAIL 5c: Reviewer composition section missing"; fail=$((fail + 1))
  fi

  # 5d: scout is referenced as a HINT, not the authority (phase2 hint phrasing).
  if grep -qE 'scout.*힌트|힌트.*scout' "$skill"; then
    echo "  PASS: 5d: scout framed as a hint"; pass=$((pass + 1))
  else
    echo "  FAIL 5d: scout hint framing missing"; fail=$((fail + 1))
  fi

  echo "=== Scenario 5 done ==="
}
test_scenario_5_scope_driven
```

- [ ] **Step 4: scout-integration 테스트 실행 → 완전 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_scout_codex_integration.sh`
Expected: PASS(checks 1–5 + Scenario 5a–5d) — pre-existing RED 해소.

- [ ] **Step 5: AC9/AC10 README 락 테스트 신규 작성(실패 예정)**

`plugins/quality-gates/tests/test_readme_scope_reconcile.sh` 생성:

```bash
#!/usr/bin/env bash
# AC9/AC10 (v2.13.0) — README fan-out consent 게이트 주장 whole-file reconcile
# + §166 3-tier 정합 + prerequisites. negative(게이트 주장 부재) + positive(재계산
# max fan-out 존재 + 3-tier + optional deps).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RM="$ROOT/plugins/quality-gates/README.md"
PASS=0; FAIL=0
present(){ if grep -qF "$2" "$RM"; then PASS=$((PASS+1)); echo "  ✓ $1"; else FAIL=$((FAIL+1)); echo "  ✗ FAIL(present): $1 — '$2'"; fi; }
presentE(){ if grep -qE "$2" "$RM"; then PASS=$((PASS+1)); echo "  ✓ $1"; else FAIL=$((FAIL+1)); echo "  ✗ FAIL(present): $1"; fi; }
gone(){ if grep -qF "$2" "$RM"; then FAIL=$((FAIL+1)); echo "  ✗ FAIL(absent): $1 — '$2' 잔존"; else PASS=$((PASS+1)); echo "  ✓ $1"; fi; }
goneE(){ if grep -qE "$2" "$RM"; then FAIL=$((FAIL+1)); echo "  ✗ FAIL(absent): $1"; else PASS=$((PASS+1)); echo "  ✓ $1"; fi; }

echo "== AC9 negative: fan-out consent 게이트 주장 전 위치 reconcile =="
gone  "len(phase1) 공식 제거"                'len(phase1)'
gone  "= 12 옛 max fan-out 라인 제거"        '= 12'
goneE "≥4/>=4 fan-out AskUserQuestion 게이트 주장 제거" '(≥ *4|>= *4).*AskUserQuestion'
gone  "subagent fan-out gate 문구 제거(190/240)" 'subagent fan-out gate'
gone  "gates subagent fan-out 문구 제거(37-40)"  'gates subagent fan-out'

echo "== AC9 positive: 재계산 max fan-out 선언 =="
present "phase-1 병렬 ≤ 8"      'Phase 1 병렬 ≤ 8'
present "총/iteration ≤ 10"      '총/iteration ≤ 10'
present "P22 transparency-기반 restate" 'transparency'

echo "== AC10: §166 3-tier + prerequisites =="
present "§166 3-tier 헤딩"       '3-tier'
present "Tier A floor"           'Tier A'
present "Tier B codex"           'Tier B'
present "Tier C 전문가"           'Tier C'
present "prerequisites pr-review-toolkit optional" 'pr-review-toolkit'
present "prerequisites feature-dev optional"       'feature-dev'

echo; echo "readme-scope-reconcile: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

```bash
chmod +x /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/test_readme_scope_reconcile.sh
```

- [ ] **Step 6: README 락 테스트 실행 → 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_readme_scope_reconcile.sh; echo "exit=$?"`
Expected: FAIL — 옛 fan-out 주장 잔존 + 재계산 max fan-out·3-tier·prerequisites 부재.

- [ ] **Step 7: README §166 Review 단계를 3-tier로 재작성**

`README.md`의 line 166-186(`## Review gate 리뷰 단계 (v1.5.0 재설계)`부터 `... = 12.` 문단까지) 전체를 아래로 교체:

````markdown
## Review gate 리뷰 단계 (v2.13.0 스코프-구동 구성)

리뷰어 구성은 **오케스트레이터가 diff 스코프로 선택**한다(모델 판단 + scout 힌트 + review-pr
§4 rubric + scope-signal 팔레트). 3-tier 모델:

```
Tier A — Floor (비-trivia면 항상, 스코프 무관; 모델이 못 뺌)
  ├── quality-gates:security-reviewer   (Phase 1)   tools: Read, Grep, Glob (#104 락)
  └── quality-gates:adversarial          (Phase 1.5)  tools: Read, Grep, Glob (#104 락)
Tier B — codex (availability-floor: detect_codex 참이면 무조건, 스코프 무관)
  └── codex-reviewer (별도 프로세스/모델 패밀리, OS read-only 샌드박스)
Tier C — Dynamic (모델이 스코프로 선택, advisory 외부 에이전트; 최대 6 후보)
  ├── pr-review-toolkit:code-reviewer        ← 강한 default(비-trivial diff), quick-depth만 drop
  ├── pr-review-toolkit:silent-failure-hunter → 에러핸들링 변경
  ├── pr-review-toolkit:type-design-analyzer  → 신규/변경 타입
  ├── pr-review-toolkit:pr-test-analyzer      → 테스트 변경
  ├── pr-review-toolkit:comment-analyzer      → docs/주석 변경
  └── feature-dev:code-architect             → 대형 구조/아키텍처 변경
Phase 1.6  Synthesizer (Phase 1 실행 시 항상) — dedupe/rank (결정론 스크립트)
```

선택은 **model-owned routing**(P8 lightness) — 결정론 selector 스키마 없음. 상세 rubric·
팔레트는 SKILL `## Reviewer composition (scope-driven)` 섹션. scout(`scripts/scout.py`)는
`depth` + 추천 subset을 emit하는 **힌트 provider**(권위 아님).

**Prerequisites (Tier C optional dependencies):** `pr-review-toolkit`(code-reviewer +
silent-failure-hunter + type-design-analyzer + pr-test-analyzer + comment-analyzer),
`feature-dev`(code-architect). 미설치 시 해당 Tier C는 unavailable로 degrade하고 floor(A) +
codex(B) + 설치된 것으로 계속(loud log). floor·codex는 이 degrade의 영향을 받지 않는다.

**Fan-out:** Review gate는 fan-out consent 게이트를 fire하지 **않는다**(과거
`len(phase1)+len(phase2)>=4 → AskUserQuestion`은 documented-not-implemented였음). P22
anti-corollary(subagent spray) instantiation은 **transparency 라인(매 iter 선택/제외 가시화)
+ 선언된 max fan-out + authoring-time hard-review(CLAUDE.md fan-out ≥5)** 기반으로 억제한다.
재계산 max fan-out: **Phase 1 병렬 ≤ 8**(security-reviewer + codex + Tier C 최대 6),
**총/iteration ≤ 10**(+ adversarial + synthesizer; code-simplifier Phase 3 없음).
````

- [ ] **Step 8: README fan-out 주장 잔여 위치 reconcile (whole-file — §186만 고치면 자기모순)**

[[feedback_gate_scope_blind_spot]]: 같은 주장이 여러 곳에 산재하므로 전수 정정한다.

(a) **line 15** — `- **P22 anti-corollary (former AP9, over-dispatching / subagent spray) hard gate** — Phase 1+2 dispatch 수가 ≥4일 때 AskUserQuestion 발동.`를 아래로:

```markdown
- **P22 anti-corollary (former AP9, over-dispatching / subagent spray) 회피** — Review gate는 fan-out consent 게이트를 fire하지 않고(documented-not-implemented였음), transparency 라인 + 선언된 max fan-out(Phase 1 병렬 ≤ 8, 총/iteration ≤ 10) + authoring-time hard-review로 subagent spray를 억제.
```

(b) **line 37-40** — `P22 generalization (consent gate → progression gate):` 문단의 `The same tool that gates subagent fan-out now gates inter-gate progression` 문장을 아래로(문단의 나머지는 유지):

```markdown
  is reused as a **progression primitive** at every gate boundary and Gate
  2 fix-loop iteration. It gates inter-gate progression and fix-loop consent
  (it does NOT gate subagent fan-out — that consent gate was never implemented;
  fan-out is bounded by the transparency line + declared max fan-out) — no new
  principle ID needed.
```

(c) **line 127** — 비용표의 `| Deep | ~55–75% (AskUserQuestion 게이트 발동) |`를 아래로(fan-out-게이트 함의 제거):

```markdown
| Deep | ~55–75% (Tier C 전문가 다수 + codex) |
```

(d) **line 141** — `adversarial` 모델 문단의 `AskUserQuestion fan-out count excludes \`adversarial\`/\`scout\`/\`synthesizer\` (infrastructure dispatches; not user-visible cost).` 문장을 아래로(문단의 나머지 opus 근거는 유지):

```markdown
`adversarial`/`scout`/`synthesizer`는 infrastructure dispatch(사용자-가시 비용 아님)이며, 위 재계산 max fan-out 선언에서 floor/codex/Tier C와 구분해 계산한다.
```

(e) **line 190** — `... 동일한 도구가 subagent fan-out gate와 inter-gate progression gate를 함께 담당합니다.`를 아래로:

```markdown
`v1.32.0`에서 SKILL이 전체 파이프라인을 단일 assistant turn 내에서 serial dispatch로 실행합니다. Inter-gate progression과 Review gate fix-loop iteration은 모두 AskUserQuestion으로 사용자 동의를 받아 진행합니다 — 이 도구는 progression/consent를 담당하며, subagent fan-out은 게이트하지 않습니다(fan-out은 transparency + 선언된 max fan-out으로 bound). (v1.5.0의 turn-by-turn state machine 다이어그램은 제거됨; 단일 다이어그램만 유지.)
```

(f) **line 240** — `**v1.32.0 변경 요약**: ... AskUserQuestion이 subagent fan-out gate와 inter-gate progression gate를 함께 담당합니다.`의 마지막 문장을 아래로:

```markdown
AskUserQuestion이 inter-gate progression gate와 fix-loop consent를 담당합니다(subagent fan-out은 게이트하지 않음).
```

- [ ] **Step 9: README 락 + 상태-다이어그램 회귀 테스트 실행 → 통과 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_readme_scope_reconcile.sh
bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh && echo "diagram GREEN" || echo "diagram RED"
bash plugins/quality-gates/tests/test_diagram_facts.sh 2>/dev/null && echo "facts GREEN" || echo "facts RED/absent"
```
Expected: `test_readme_scope_reconcile` PASS. `test_readme_state_diagram_complete` 여전히 GREEN(다이어그램 line 193-238 미변경). facts 테스트도 GREEN(변경 시 baseline과 비교 — RED면 내 편집이 다이어그램 fact를 깼는지 확인).

- [ ] **Step 10: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/tests/test_codex_dispatch_invariant.sh \
        plugins/quality-gates/tests/test_scout_codex_integration.sh \
        plugins/quality-gates/README.md \
        plugins/quality-gates/tests/test_readme_scope_reconcile.sh
git commit -m "fix(quality-gates): recover stale codex/scout tests + README 3-tier reconcile (AC2/9/10)"
```

---

## Task 5: 전체 스위트 green + 회귀 확인 + self-dogfood 준비 (AC7 회귀, AC1 런타임 teeth, AC11 census)

정적 락은 모델 준수를 검증하지 못한다([[reference_workflow_law2_agenttype]] "트랜스크립트 census"). 전체 스위트가 green이고 새 red가 없음을 확인한 뒤, 런타임 teeth(AC1(b)/AC11)는 `/qg branch` self-dogfood 트랜스크립트 census로 실측한다.

**Files:** (테스트 실행만 — 코드 변경 없음. self-dogfood 발견 시 해당 파일 수정.)

- [ ] **Step 1: 이 작업이 건드린/인접한 테스트 전부 green 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_scout_script test_review_floor_lock test_review_scope_composition \
         test_codex_dispatch_invariant test_scout_codex_integration \
         test_readme_scope_reconcile test_qg_publish_docs test_artifact_metadata \
         test_security_reviewer_persona test_adversarial_persona \
         test_agent_tools_lock_mutation test_agent_frontmatter_keys test_law2_prose; do
  if bash plugins/quality-gates/tests/$t.sh >/dev/null 2>&1; then echo "GREEN  $t"; else echo "RED    $t"; fi
done
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh >/dev/null 2>&1 && echo "GREEN  harness" || echo "RED    harness"
```
Expected: 전부 GREEN. 특히 두 pre-existing stale red(`test_codex_dispatch_invariant`, `test_scout_codex_integration`)가 이제 GREEN — 이 작업이 회복.

- [ ] **Step 2: 전체 qg 스위트 실행 — 새 red가 baseline 대비 0인지 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
red=0; total=0
for f in plugins/quality-gates/tests/test_*.sh plugins/quality-gates/tests/harness/*.sh; do
  total=$((total+1))
  bash "$f" >/dev/null 2>&1 || { echo "RED: $(basename "$f")"; red=$((red+1)); }
done
for f in plugins/quality-gates/tests/test_*.py; do
  total=$((total+1))
  python3 "$f" >/dev/null 2>&1 || { echo "RED(py): $(basename "$f")"; red=$((red+1)); }
done
echo "TOTAL=$total RED=$red"
```
Expected: 남는 RED가 있으면 **작업 전 baseline([[project_qg_pre_existing_test_reds]])과 대조** — 이 작업이 건드린 파일(scout.py/SKILL.md/README.md/plugin.json/CHANGELOG.md + 위 테스트들)과 무관한 pre-existing red만 허용. 이 작업이 만든 새 red는 0이어야 한다. (일부 py 테스트는 환경 의존 pre-existing red일 수 있음 — baseline과 대조해 판별.)

- [ ] **Step 3: git clean-tree 확인 (detached HEAD·잔여 없음)**

Run: `cd /Users/jeonghokim/Downloads/devbrew && git status --porcelain && git branch --show-current`
Expected: 워킹트리 clean(모든 task 커밋됨), branch = `feature/qg-scope-driven-reviewers`(detached HEAD 아님 — [[feedback_review_subagent_baseline_checkout_detaches_head]]).

- [ ] **Step 4: `/qg branch` self-dogfood 런타임 census (AC1(b)/AC11 — 수동, 사람-in-loop)**

이 작업은 자동 테스트로 끝나지 않는다 — spec §8 런타임 teeth는 실제 `/qg branch` 실행이 필요하다. 오케스트레이터가 whole-branch 리뷰(codex 모델-다양성 포함)를 돌린 뒤 트랜스크립트에서 census:

```bash
# self-dogfood 트랜스크립트에서 (하이픈 포함 — MCP 놓침 방지):
grep -o '"name":"[A-Za-z0-9_-]*"' <transcript.jsonl> | sort | uniq -c
```

확인 항목:
- **(i) 두 floor 리뷰어 실제 dispatch** — `quality-gates:security-reviewer` + `quality-gates:adversarial`가 스코프 무관 실제로 떴는가(AC1 런타임 teeth). 정적 grep-lock이 "항상"을 선언해도 모델이 실제로 뺐다면 여기서 잡힌다.
- **(ii) 미설치 전문가 degrade loud-log 발생** — Tier C 미설치 케이스에서 `> [quality-gates] specialist <X> unavailable ... degraded coverage` 라인이 실제 출력됐는가(AC11).
- **(iii) codex Tier B** — `detect_codex` 참이면 codex가 스코프 무관 dispatch됐는가(AC2 런타임 확인).

self-dogfood가 fail-open을 재적발하면([[project_qg_scope_capture]]: 2단계 통과≠버그없음) — **잡았어야 할 곳(SKILL 프로즈 또는 락)을 수정**하고 그 커밋이 compounding 이벤트(Law 3, CLAUDE.md). 수정은 이 plan의 해당 Task 스텝 패턴을 재적용한다.

- [ ] **Step 5: whole-branch 리뷰 → 사용자 검토/머지 (후속)**

self-dogfood green 후: whole-branch 리뷰(codex 병렬 독립 co-review 포함)로 통합 결함 스캔([[project_project_init_audit]] 교훈: per-task 격리 밖 통합결함), 그 다음 사용자 검토/머지. PR 본문에 spec + plan 링크.

---

## Self-Review (이 plan을 spec에 대조 — writing-plans 지시)

**1. Spec coverage (AC1–AC14 → task 매핑):**
- AC1(floor 불변 + 런타임 teeth) → Task 3 Step 1(mutation-teeth 정적) + Task 5 Step 4(census 런타임). ✓
- AC2(codex availability-floor) → Task 4 Step 1-2(재작성 테스트) + Task 3(Tier B 프로즈). ✓
- AC3(rubric embed) → Task 3 Step 2/5. ✓  AC4(팔레트) → Task 3 Step 2/5. ✓
- AC5(scout docs_touched) → Task 2. ✓
- AC6(code-reviewer Tier C 강한 default, floor 아님) → Task 3 Step 2(윈도우-스코프 grep). ✓
- AC7(tool posture 무변경) → agents 미편집(Global Constraints) + Task 3 Step 9 + Task 5 Step 1 회귀 확인(기존 persona/mutation 테스트). ✓
- AC8(loud transparency) → Task 3 Step 2/4. ✓
- AC9(fan-out 주장 whole-file reconcile + max fan-out 재계산) → Task 4 Step 5-9(negative+positive, 6 위치 전수). ✓
- AC10(README §166 정합 + prerequisites) → Task 4 Step 7. ✓
- AC11(graceful degradation) → Task 3 Step 2/4 + Task 5 census. ✓
- AC12(버전 + CHANGELOG) → Task 1(커플링 teeth 포함). ✓
- AC13(Law-2/posture 무변경 + 0-100 미도입) → Task 3 Step 2 negative + Global Constraints. ✓
- AC14(non-goal 가드: code-simplifier/model override/graft) → Task 3 Step 2 negative. ✓

**2. Placeholder scan:** TBD/TODO/"적절히"류 없음 — 모든 스텝에 실제 코드/명령/기대출력. ✓

**3. Type consistency:** floor anchor 리터럴 `스코프 무관, 항상 디스패치`가 SKILL(Task 3 Step 4)·floor-lock(Task 3 Step 1)·scout-integration(Task 4 Step 3)·codex-invariant(Task 4 Step 1)에서 일관. Tier B anchor `Tier B — codex (availability-floor`가 SKILL(Task 3 Step 4)·codex-invariant(Task 4 Step 1)에서 일관. transparency 리터럴 `> [quality-gates] Review iter N — 선택:`이 SKILL·composition 테스트에서 일관. max fan-out 문구 `Phase 1 병렬 ≤ 8`/`총/iteration ≤ 10`이 README(Task 4 Step 7-8)·readme-락(Task 4 Step 5)에서 일관. ✓

**Known plan risk (구현자 주의):** Task 3 Step 8의 harness proximity bound 완화는 **FAIL이 실제로 날 때만** 한다(불필요한 테스트 약화 금지). Task 4 Step 8의 README 편집은 line 번호가 아니라 **인용한 문자열 기준**으로 찾을 것(스냅샷 drift). Task 4 Step 8(a)의 line 15 편집이 `test_law2_prose.sh`/`session-start-advisor` 스캐너를 깨지 않는지 Task 4 Step 9에서 확인(현재 그 테스트들은 `allowedTools` 리터럴만 보므로 무관하지만, 재실행으로 확증).
