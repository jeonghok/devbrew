# qg Gate 1 Plan Discovery — Design

**작성일:** 2026-05-10
**대상 플러그인:** `quality-gates` (v1.6.3 → v1.7.0)
**관련 sister:** `superpowers:writing-plans`

## 1. Context / Why

`/qg`의 Gate 1 (`plan-verifier` agent)이 사용자가 superpowers로 작성한 plan을 찾지 못한다.

**근본 원인 — path mismatch:**

- `superpowers:writing-plans` skill은 plan을 **`docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`** (project-local)에 저장한다 (`SKILL.md:18`).
- `quality-gates:plan-verifier` agent는 **`~/.claude/plans/`** (user home, global)만 스캔한다 (`plan-verifier.md:37, 41`).

결과: 사용자가 superpowers 워크플로우 (`brainstorming` → `writing-plans` → 코드 작성)로 만든 plan이 Gate 1 입장에서는 존재하지 않음. `~/.claude/plans/`에 옛날 무관한 plan이 남아있는 경우 잘못된 plan을 verify하기도 한다 (현재 41개 옛 파일이 그 위치에 있음).

**왜 Law 3 (compounding) 이슈이기도 한가:**

`plan-verifier`는 같은 marketplace의 sister-plugin (`superpowers`)이 산출한 결과물을 consume해야 하는데, 그 convention drift가 README에 명시되지 않아 silent breakage가 됨. CLAUDE.md "Silent coupling은 버그" 위반. Cross-plugin reader/writer 약속을 명시적으로 만들 필요.

## 2. Goals

- `superpowers:writing-plans`가 출력하는 project-local plan을 Gate 1이 자동 발견.
- 기존 `~/.claude/plans/` 사용자는 동일하게 동작 (back-compat 유지).
- Discovery 알고리즘이 markdown agent의 자유서술이 아니라 결정적 script로 분리되어 unit test 가능.
- Report에 어떤 source에서 plan을 가져왔는지 명시 (사용자 디버깅성).
- Cross-plugin reader/writer 결합을 README에 명시 (Law 3 compounding).

## 3. Non-goals

- `superpowers:writing-plans`의 저장 경로 변경 (upstream 영역).
- `docs/superpowers/specs/` 활용 — specs는 design doc이고 task checkbox가 없음 (실측: 3개 spec 모두 0 checkboxes vs plans 59~80 checkboxes).
- Branch-name 기반 fuzzy match — false negative 빈번, "trivia ceremony" 위험.
- `$CLAUDE_PLANS_DIR` env override — YAGNI; `--plan <path>`로 충분.
- `~/.claude/plans/`의 옛 plan을 project-local로 옮기는 migration 스크립트 — 사용자가 `mv` 한 줄.
- E2E /qg 통합 테스트 추가 — discovery script 단위 테스트로 95% 커버.

## 4. Constraints

- Agent는 read-only (Law 2). Discovery script도 mkdir/write 금지.
- `plan-verifier`는 leaf agent — sub-dispatch 불가 (`Agent`/`Task` with `subagent_type` 사용 금지).
- 모든 변경은 단일 PR/commit으로 묶여야 rollback이 한 줄 (`git revert <merge-sha>`).
- CLAUDE.md "plugin.json 모든 PR마다 SemVer bump" — 새 surface 추가이므로 minor bump (`1.6.3` → `1.7.0`).
- README의 "Principles Instantiated" 섹션 갱신 필수.

## 5. Acceptance Criteria

1. **AC1 — Project-local discovery:** `docs/superpowers/plans/`에 unchecked checkbox를 가진 plan이 있을 때 `/qg`가 그 plan을 verify하고 report의 `**Source:**` 필드가 `project-local`이다.
2. **AC2 — Legacy fallback:** `docs/superpowers/plans/`가 비어있고 `~/.claude/plans/`에만 plan이 있을 때 후자를 verify하고 `**Source:** legacy-global` + deprecation 경고 1줄 출력.
3. **AC3 — Priority over checkbox status:** `docs/superpowers/plans/`에 all-checked plan이 있고 `~/.claude/plans/`에 unchecked plan이 있어도 project-local을 선택 (priority가 checkbox status보다 우선).
4. **AC4 — Explicit override wins:** `--plan <path>`가 존재하는 파일이면 다른 source 무시하고 그 파일 사용. `**Source:** explicit`.
5. **AC5 — Explicit invalid:** `--plan <path>`가 존재하지 않으면 SKIP (fallback 안 함). reason: `"Explicit --plan path does not exist: <path>"`.
6. **AC6 — Non-plan filter:** glob이 잡은 파일에 `- [ ]` / `- [x]` checkbox가 0개면 plan 자격 없음 — 다음 candidate로 fall-through.
7. **AC7 — Both empty:** 두 source 모두 비어있으면 SKIP, reason: `"No plan file found. Searched: docs/superpowers/plans/, ~/.claude/plans/"`.
8. **AC8 — Multiple unchecked candidates:** 한 source에 unchecked plan 2개 이상이면 mtime 가장 최근 것 선택 (현재 동작 유지).
9. **AC9 — Discovery is unit-tested:** `tests/test_discover_plan.sh`가 9개 fixture case를 모두 통과.
10. **AC10 — Downstream propagation:** Gate 1이 emit하는 `gate1_summary.plan_path`가 선택된 plan의 절대 경로 또는 repo-relative 경로로 채워짐. Gate 2의 `superpowers:code-reviewer` dispatch가 이 path를 그대로 받음.

## 6. Architecture

### 6.1 Plan Discovery Order

위→아래로 스캔하며 첫 자격 candidate에서 멈춤.

| Priority | Source | 조건 |
|---|---|---|
| 1 | `--plan <path>` (CLI 명시) | 존재하면 사용, 없으면 SKIP (no fallback) |
| 2 | `docs/superpowers/plans/*.md` | 자격 = checkbox ≥1. 자격 candidate가 하나라도 있으면 이 source 사용 |
| 3 | `~/.claude/plans/*.md` | 자격 = checkbox ≥1. project-local이 비었을 때만 consult. 첫 hit이면 deprecation 경고 |

**선택 source 내부의 파일 선택 규칙:**

1. 자격 candidate 중 unchecked checkbox 있는 파일이 있으면 → 그 중 mtime 가장 최근.
2. 모두 all-checked면 → 자격 candidate 중 mtime 가장 최근 ("방금 끝낸 plan, PASS 처리 정상").

이 규칙을 source-level priority와 헷갈리지 말 것: source priority는 항상 source-level에서 먼저 결정 (project-local에 자격 candidate 있으면 legacy 안 봄), 파일 선택은 *선택된 source 내부에서만* 적용.

**핵심 결정:** project-local에 자격 candidate가 *하나라도* 있으면 legacy는 쳐다보지 않음. 두 source를 mtime 기준으로 섞으면 `~/.claude/plans/`의 옛날 파일이 더 최근일 때 false-match — 정확히 현재 발생 중인 버그.

### 6.2 Component: `scripts/discover-plan.sh`

Discovery 알고리즘을 markdown agent에서 분리해 결정적 script로 만든다. Agent의 자유서술 implementation이 매번 즉흥 발생하던 것이 정확히 이 버그의 원인.

```
입력:
  --plan <path>      (optional; CLI 명시 override)

출력 (stdout, 한 줄 JSON):
  {"plan_path": "<absolute-or-empty>",
   "source": "explicit|project-local|legacy-global|none",
   "reason": "<human-readable>"}

종료 코드:
  0 — found (plan_path 비어있지 않음)
  1 — not found (어떤 source에도 자격 candidate 없음)
  2 — invalid input (--plan path가 존재하지 않음)
```

### 6.3 Component: `agents/plan-verifier.md` (Step 1 재작성)

```
1. plan_path 인자 분기:
   - plan_path == "auto" 또는 빈 값 → `discover-plan.sh` (인자 없이) 호출
   - plan_path가 명시된 경로 → `discover-plan.sh --plan <path>` 호출
2. JSON 파싱:
   - exit 1 → verdict: SKIP, reason: "<reason from JSON>"
   - exit 2 → verdict: SKIP, reason: "Explicit --plan path does not exist: <path>"
   - exit 0 → plan_path를 들고 Step 2로 진행
3. source가 "legacy-global"이면 report 헤더 직전에 deprecation 한 줄 emit:
   "⚠️ Legacy plan source: ~/.claude/plans/. Consider migrating to docs/superpowers/plans/."
```

### 6.4 Report 변경 (Step 5 template)

```
## Plan Verification Report (Gate 1)

**Plan:** docs/superpowers/plans/2026-05-10-foo-plan.md
**Source:** project-local        ← 새 필드
**Total Items:** 59
...
```

`Source` 필드는 사용자가 "왜 이 plan을 verify했는지" 즉시 인지 가능하게 한다. legacy fallback이 fire하면 시각적 단서.

### 6.5 Downstream propagation (변경 없음)

`quality-pipeline` SKILL.md가 이미 `gate1_summary.plan_path`로 path를 그대로 흘림. Gate 2의 `superpowers:code-reviewer` dispatch와 Gate 3 runtime-verifier도 path를 그대로 받음. Path가 absolute이든 repo-relative이든 둘 다 유효 — 변경 불필요.

## 7. Edge Cases

| ID | 시나리오 | 동작 |
|---|---|---|
| E1 | `--plan <path>` 존재하지 않음 | SKIP, reason 명시. Fallback 안 함 (의도 무시 = bigger sin) |
| E2 | Glob이 README 등 non-plan 파일을 잡음 | checkbox 0개면 plan 자격 없음 → 다음 candidate fall-through |
| E3 | Branch switch 후 stale plan | 의도적으로 안 풀음. `--plan` override 1순위로 사용자 escape hatch 충분. branch fuzzy match는 anti-pattern 위험 |
| E4 | 두 source 모두 비어있음 | SKIP, reason: `"No plan file found. Searched: docs/superpowers/plans/, ~/.claude/plans/"` |
| E5 | `docs/superpowers/plans/` 디렉토리 자체 없음 | glob 빈 list → 자연스럽게 legacy로 fallback. mkdir 시도 안 함 (Law 2 read-only) |

## 8. Files to Modify

| 동작 | 경로 | 변경 요지 |
|---|---|---|
| CREATE | `plugins/quality-gates/scripts/discover-plan.sh` | Discovery 알고리즘 (priority + glob + checkbox count → JSON) |
| CREATE | `plugins/quality-gates/tests/test_discover_plan.sh` | 9 fixture cases (§9 매트릭스) |
| MODIFY | `plugins/quality-gates/agents/plan-verifier.md` | Step 1 재작성: discover-plan.sh 호출 + JSON 파싱 + source 필드. Step 5 report template에 `**Source:**` 라인. Deprecation 경고 조건. `--plan` non-existent 처리 |
| MODIFY | `plugins/quality-gates/.claude-plugin/plugin.json` | `1.6.3` → `1.7.0` (minor: 새 surface) |
| MODIFY | `plugins/quality-gates/CHANGELOG.md` | `## [1.7.0] — 2026-05-10` Added/Changed/Fixed 섹션 |
| MODIFY | `plugins/quality-gates/README.md` | (a) "Plan Discovery Sources" 섹션, (b) "Principles Instantiated"에 Law 3 cross-plugin compounding 한 줄, (c) Prerequisites에 superpowers soft-dependency 표기 |

## 9. Verification Plan

### 9.1 Unit tests (`tests/test_discover_plan.sh`)

bash + tmpdir 패턴 (기존 `test_setup_qg.sh` 스타일). 각 케이스 평균 <50줄, 9개 함수.

| # | Setup | 기대 결과 |
|---|---|---|
| 1 | 양쪽 source 모두 비어있음 | `source=none, exit=1` |
| 2 | project-local에 plan 1개 (unchecked) | `source=project-local`, 그 plan |
| 3 | project-local에 plan 1개 (all checked) + legacy에 plan 1개 (unchecked) | `source=project-local` (priority가 checkbox status보다 우선) |
| 4 | project-local 비어있음 + legacy에 plan 1개 | `source=legacy-global` |
| 5 | project-local에 README.md (0 checkboxes) only + legacy 비어있음 | `source=none, exit=1` (checkbox 없으면 plan 자격 없음) |
| 6 | `--plan /tmp/foo.md` (존재) | `source=explicit` |
| 7 | `--plan /nonexistent.md` | `exit=2, source=none` |
| 8 | project-local에 plan 2개 (둘 다 unchecked, mtime 다름) | 최신 mtime 파일 |
| 9 | project-local에 plan 2개 (둘 다 0 checkboxes) | falls through to legacy |

### 9.2 Manual verification (배포 전)

- 현재 repo에서 `/qg gate1` 실행 → `docs/superpowers/plans/2026-05-10-project-init-templates-industry-alignment-plan.md`가 자동 선택되고 report에 `**Source:** project-local` 출력 확인.
- `~/.claude/plans/`만 두고 `docs/superpowers/plans/` 임시로 비워서 deprecation 경고 fire 확인.

## 10. Rejected Alternatives

- **`$CLAUDE_PLANS_DIR` env override 추가** — YAGNI. `--plan <path>` 1순위가 power-user escape hatch로 충분. env 1개 더 추가하면 discovery 우선순위가 4단계 → 4-stack은 mental model 비용이 가치 초과.
- **specs를 discovery source에 포함** — 실측: 모든 spec이 0 checkboxes. plan-verifier의 checkbox 기반 verify 로직과 호환 불가. 강행하면 specs는 항상 SKIP되어 기능적으로는 plans-only와 동일하지만 사용자 혼동만 추가.
- **Branch-name fuzzy match** — false negative 빈번 (사용자 명명 컨벤션 천차만별). "trivia ceremony" anti-pattern. `--plan <path>` 1줄로 동일 효과.
- **Discovery 로직을 markdown agent prose에 그대로 두고 source list만 추가** — 정확히 이 버그 발생 원인의 재발 메커니즘. 결정적 script로 분리해야 unit-testable.
- **Migration 스크립트 (`~/.claude/plans/` → `docs/superpowers/plans/` 자동 이동)** — Law 2 read-only 위반 + 사용자 의도 추정. Deprecation 경고 1줄 + `mv` 한 줄로 충분.

## 11. Metadata

- **Spec**: `docs/superpowers/specs/2026-05-10-qg-plan-discovery-design.md`
- **Plugin**: `plugins/quality-gates/` (1.6.3 → 1.7.0)
- **Sister-plugin (read contract)**: `superpowers:writing-plans` (writes to `docs/superpowers/plans/`)
- **Principles Instantiated**:
  - Law 2 — discover-plan.sh가 결정적 script로 분리되어 agent의 자유서술 implementation을 제거 (writer/reviewer 분리의 기계적 강제와 같은 정신).
  - Law 3 — cross-plugin reader (`quality-gates`)가 sister writer (`superpowers:writing-plans`)의 출력 위치를 README에 명시함으로써 silent coupling을 명시적 contract로 승격.
  - P12 (trivia escape) — non-plan markdown 파일을 자동 필터해 "checkbox 없는 파일도 plan으로 강행" 같은 ceremony를 방지.
- **Rollback**: 단일 commit. `git revert <merge-sha>` 한 줄.
