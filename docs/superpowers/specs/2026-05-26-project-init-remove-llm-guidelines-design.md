# project-init v1.5.0 — Remove LLM Coding Guidelines

> **Spec date**: 2026-05-26
> **Target version**: project-init `1.4.0` → `1.5.0`
> **Branch suggestion**: `feature/project-init-remove-llm-guidelines`
> **Worktree**: 새 워크트리에서 작업 진행

## 목차

- §1 Context / Why
- §2 Goals
- §3 Non-goals
- §4 Constraints
- §5 Acceptance Criteria
- §6 Files to Modify
- §7 Verification Plan
- §8 Rejected Alternatives
- §9 Metadata

## §1 Context / Why

현재 `/project-init` 명령은 타깃 프로젝트의 `AGENTS.md`에 `## LLM Coding Guidelines` 4-bullet 섹션을 주입한다 (`templates/shared/llm-guidelines.md`).

```
- Think Before Coding — 가정·혼란·tradeoff 명시, 의심나면 묻기
- Simplicity First — 요청 이상 만들지 않기, 추측 금지
- Surgical Changes — 요청과 직결된 줄만, 인접 코드 청소 금지
- Goal-Driven Execution — 검증 가능한 성공 기준 정의 후 loop
```

이 4-bullet은 Karpathy의 LLM 코딩 관찰에서 파생된 baseline으로 도입됐으나, 실사용 관찰 결과 두 가지 wording이 **action 제약과 suggestion 제약을 구분하지 못함**.

- `Simplicity First — 요청 이상 만들지 않기, 추측 금지`: "요청 이상 만들지 않기"는 code 작성을 막는 의도였으나 strict reading은 *제안·관찰조차* 차단. "추측 금지"는 strict하게 읽으면 proactive observation을 칠링.
- `Surgical Changes — 요청과 직결된 줄만, 인접 코드 청소 금지`: 인접 코드를 *건드리지* 말라는 의도이나 strict reading은 *언급조차* 침묵하도록 만듦.

비교: Claude Code 기본 시스템 프롬프트는 **제안 vs 실행을 명시적으로 분리**하여 *"For exploratory questions... respond in 2-3 sentences with a recommendation and the main tradeoff. Present it as something the user can redirect, not a decided plan. Don't implement until the user agrees."* 라고 적시. 즉 현재 project-init template은 default보다 더 strict하며, suggestion 표면을 의도치 않게 줄이는 chilling effect 발생.

**사용자 판단**: wording을 고치는 비용보다 *제거*가 깔끔. 빈자리에는 아무것도 두지 않고 Claude Code default 행동에 위임. devbrew 자체 root `CLAUDE.md`의 동일 섹션도 dogfood 일관성을 위해 함께 제거.

## §2 Goals

1. `templates/shared/llm-guidelines.md` 파일을 삭제하고 `/project-init`이 향후 `AGENTS.md`에 `## LLM Coding Guidelines` 섹션을 주입하지 않게 한다.
2. 플러그인의 모든 surface (command, README, plugin.json description, 사용자 메시지)에서 LLM Coding Guidelines 및 Karpathy attribution을 제거한다.
3. devbrew root `CLAUDE.md`에서도 동일 섹션을 제거 (dogfooding 일관성).
4. CHANGELOG에 v1.5.0 entry 추가 + `plugin.json` version `1.4.0` → `1.5.0` bump.
5. 변경 후 grep gate가 통과한다 (§7 verification).

## §3 Non-goals

- **Retroactive cleanup 없음**: 이미 `/project-init`을 돌려 4-bullet이 주입된 사용자 프로젝트의 `AGENTS.md` / `CLAUDE.md`는 자동 수정하지 않는다. CHANGELOG에서 manual 안내만.
- **빈자리 placeholder 없음**: "Claude Code defaults에 의존" 식 pointer를 두지 않는다 (같은 chilling 위험 재발 방지).
- **다른 LLM behavior shaping 메커니즘 신설 없음**: Claude Code 기본 시스템 프롬프트에 위임.
- **다른 플러그인 영향 검토 없음**: 본 PR에서는 project-init와 devbrew root만 다룬다. superpowers / quality-gates / commit-commands 의존성 검토는 후속.
- **Wording 재작성 시도 없음**: 사용자가 wording fix를 직접 거절함 (§8 참조).
- **다른 플러그인의 LLM Coding Guidelines coupling 추가 처리 없음** (cross-plugin 사전 grep으로 0건 확인됨, 본 PR scope 외):
  ```bash
  $ grep -rEn "LLM Coding|llm-guidelines|Karpathy" plugins/ --include="*.md" --include="*.py" --include="*.json" | grep -v "plugins/project-init/"
  (0 hits)
  ```
  즉 `superpowers`, `quality-gates`, `commit-commands` 등 어떤 플러그인도 `templates/shared/llm-guidelines.md`를 참조하거나 `## LLM Coding Guidelines` 헤더에 의존하지 않음. 후속 issue tracking 불필요, 본 PR에서 추가 탐색 없음.

## §4 Constraints

- **단일 PR / 단일 commit sequence**: 6개 파일 변경이 한 PR에 묶여야 dogfood 일관성 유지.
- **AGENTS.md primary 모델 보존**: `@AGENTS.md` thin pointer 패턴, 4-state matrix (S1–S4), 16+ 벤더 호환성 모두 unchanged.
- **`templates/<strategy>/agents-md-section.md` 3개 파일 unchanged**: 이미 `## Git Workflow` 섹션만 담고 있어 수정 불필요.
- **Hooks (`post-tool-use.py`, `docs-lint.py`) unchanged**: LLM Coding Guidelines를 참조하지 않음.
- **devbrew CLAUDE.md memory `feedback_spec_when_scope_grows` 준수**: substantial change이므로 spec → plan → 구현 순서. 본 문서가 spec 단계.
- **devbrew CLAUDE.md memory `feedback_plugin_version_bump` 준수**: 같은 commit에서 `plugin.json` version bump 필수.

## §5 Acceptance Criteria

| ID | Criterion |
|---|---|
| **AC1** | `plugins/project-init/templates/shared/llm-guidelines.md` 파일이 git에서 삭제되어 있다. |
| **AC2** | `plugins/project-init/.claude-plugin/plugin.json`의 `version`이 `"1.5.0"`이고, `description`에 "LLM coding baseline" / "Karpathy" 문자열이 존재하지 않는다. |
| **AC3** | `plugins/project-init/commands/project-init.md`의 frontmatter `description`, Step 4a 읽기 목록, Step 4c S1·S2a·S3 matrix 행, Step 5 확인 메시지 어디에도 `llm-guidelines.md` / `## LLM Coding Guidelines` / `Karpathy` 참조가 없다. |
| **AC4** | `plugins/project-init/README.md`의 파일 트리, 기능 테이블, "동작 방식" 섹션, "인스턴스화한 원칙" 섹션 어디에도 LLM Coding Guidelines / Karpathy 언급이 없다 (단, v1.4.0 docs-lint Law 1 bullet은 보존). 추가 점검: "인스턴스화한 원칙" 섹션의 *Plugin shape* bullet에서 `8줄 LLM 블록` 문자열이 부재하고 `(Git Workflow 요약)` 형태로 축소됐다 (grep 패턴이 `LLM Coding`만 잡으므로 별도 확인). |
| **AC5** | `plugins/project-init/CHANGELOG.md` 최상단에 `## [1.5.0] — 2026-05-26` entry가 존재하며 **Removed** / **Changed** / **Note (manual cleanup)** 카테고리를 포함한다. |
| **AC6** | `/Users/jeonghokim/Downloads/devbrew/CLAUDE.md`에 `## LLM Coding Guidelines` 헤더와 4-bullet 블록이 존재하지 않는다 (라인 10–16 영역 제거; `## Git Workflow` 섹션은 보존). |
| **AC7** | Grep gate (CI-runnable, zero-output = pass): `grep -rEn "LLM Coding\|llm-guidelines\|Karpathy" plugins/project-init/ CLAUDE.md \| grep -v "CHANGELOG.md"` — 명령 output이 0줄이면 통과, 1줄 이상이면 실패. CHANGELOG.md의 historical + 신규 1.5.0 entry만 정상적으로 LLM 참조를 보존하므로 grep 결과에서 제외. |
| **AC8** | Smoke test (scratch dir): `/project-init github-flow` 실행 후 생성된 `AGENTS.md`가 `## Git Workflow` 섹션만 포함하고 `## LLM Coding Guidelines` 섹션이 부재. |
| **AC9** | Hook 회귀: `plugins/project-init/hooks/tests/smoke.sh` 통과. |
| **AC10** | Existing-project upgrade (S3 path): 기존 `AGENTS.md`(4-bullet 포함) + `@AGENTS.md` CLAUDE.md 상태에서 `/project-init` 재실행 시 Step 4c S3 path가 동작 — `## Git Workflow`만 in-place 갱신, `## LLM Coding Guidelines` 섹션은 비-관리 컨텐츠로 분류되어 **보존**됨 (사용자 manual cleanup 원칙 실현). |
| **AC11** | Legacy CLAUDE-only migration (S2a path): `AGENTS.md` 없음 + 기존 CLAUDE.md에 `## LLM Coding Guidelines` 4-bullet + `## Git Workflow` 둘 다 존재하는 상태에서 `/project-init` 실행, 사용자 migration 승인 시 — (a) AGENTS.md가 신규 작성되고 그 안에 새 `## Git Workflow` 섹션 + 기존 `## LLM Coding Guidelines` 4-bullet (비-관리 컨텐츠로서 그대로 이전)이 모두 존재, (b) CLAUDE.md는 `@AGENTS.md` 한 줄 thin pointer로 교체됨, (c) 사용자의 LLM 4-bullet 컨텐츠가 silent drop되지 않음. |

## §6 Files to Modify

### 6.1 `plugins/project-init/templates/shared/llm-guidelines.md`

**삭제**. 빈 파일로 두지 않음.

### 6.2 `plugins/project-init/commands/project-init.md`

변경 anchor는 line 번호가 아닌 *인용 텍스트 첫 N자*로 지칭한다 (line drift 내성).

| Anchor (인용 텍스트 prefix) | 현재 | 변경 후 |
|---|---|---|
| Frontmatter `description` 끝부분 `, Karpathy-derived LLM guidelines)` | `"... PR process, Karpathy-derived LLM guidelines)"` | `"... PR process)"` |
| Step 4a 읽기 목록 항목 `${CLAUDE_PLUGIN_ROOT}/templates/shared/llm-guidelines.md` | 6개 파일 (`llm-guidelines.md` 포함) | 5개 파일 (`llm-guidelines.md` 제거) |
| Step 4c **S1** Action 셀의 `agents-md-section.md + llm-guidelines.md merge` | `AGENTS.md 신규 작성 (agents-md-section.md + llm-guidelines.md merge); CLAUDE.md 신규 작성 (claude-md-pointer.md content — @AGENTS.md 한 줄).` | `AGENTS.md 신규 작성 (agents-md-section.md content); CLAUDE.md 신규 작성 (claude-md-pointer.md content — @AGENTS.md 한 줄).` |
| Step 4c **S2a** Action 셀의 `(a) ## LLM Coding Guidelines/## Git Workflow 섹션 추출` | `(a) ## LLM Coding Guidelines/## Git Workflow 섹션 추출, ...` | `(a) ## Git Workflow 섹션 추출, ...` |
| Step 4c **S2a** Action 셀 끝부분 — **명시적 정책 추가** (보존 의도) | (현재 셀에 명시 없음 — ambiguous) | 셀 끝에 한 문장 append: `기존 CLAUDE.md의 ## LLM Coding Guidelines 섹션은 더 이상 plugin이 managed로 취급하지 않으므로 자동으로 비-관리 컨텐츠로 분류되어 (matrix 직후 '비-관리 컨텐츠는 모든 state에서 보존' 규칙에 따라) AGENTS.md migration 시 그대로 이전·보존. CLAUDE.md는 @AGENTS.md 한 줄로 교체되지만 사용자의 4-bullet은 AGENTS.md에 살아남음 — §3 'Retroactive cleanup 없음' 정책과 정합.` |
| Step 4c **S2b** Action 셀의 `새 template만으로 AGENTS.md 신규 작성, CLAUDE.md unchanged.` | `(unchanged — LLM Guidelines 참조 없음)` | **변경 없음 — AC3 검증 대상 아님** (S2b 셀 텍스트는 그대로) |
| Step 4c **S3** Action 셀의 `AGENTS.md의 ## LLM Coding Guidelines/## Git Workflow 섹션만 in-place 갱신.` | `AGENTS.md의 ## LLM Coding Guidelines/## Git Workflow 섹션만 in-place 갱신.` | `AGENTS.md의 ## Git Workflow 섹션만 in-place 갱신.` |
| Step 4c **S4** Action 셀 | `(unchanged — LLM Guidelines 직접 참조 없음, advisory only)` | **변경 없음** |
| Step 5 확인 메시지 `> **{strategy 이름}** 전략으로 git workflow + LLM coding guidelines 초기화 완료.` | `> ... git workflow + LLM coding guidelines 초기화 완료.` | `> ... git workflow 초기화 완료.` |
| Step 5 확인 메시지 `> - AGENTS.md — ## LLM Coding Guidelines와 ## Git Workflow 섹션 추가 (canonical content source)` | `> - AGENTS.md — ## LLM Coding Guidelines와 ## Git Workflow 섹션 추가 ...` | `> - AGENTS.md — ## Git Workflow 섹션 추가 ...` |
| Step 5 확인 메시지 `> 4-bullet LLM Coding Guidelines baseline은 Andrej Karpathy의 LLM 코딩 관찰에서 파생.` | `> 4-bullet LLM Coding Guidelines baseline은 Andrej Karpathy의 LLM 코딩 관찰에서 파생.` | **줄 제거** |

### 6.3 `plugins/project-init/.claude-plugin/plugin.json`

| Key | 현재 | 변경 후 |
|---|---|---|
| `description` | `"Initialize git workflow rules + LLM coding baseline for any project. Select a branching strategy (GitHub Flow, Git Flow, Trunk-based), generate AGENTS.md (canonical) + CLAUDE.md (@AGENTS.md thin pointer) and docs/ with branch naming, Conventional Commits, PR process, and Karpathy-derived LLM coding guidelines. Auto-validates branch/commit + agent-readable docs conventions via hooks."` | `"Initialize git workflow rules for any project. Select a branching strategy (GitHub Flow, Git Flow, Trunk-based), generate AGENTS.md (canonical) + CLAUDE.md (@AGENTS.md thin pointer) and docs/ with branch naming, Conventional Commits, and PR process. Auto-validates branch/commit + agent-readable docs conventions via hooks."` |
| `version` | `"1.4.0"` | `"1.5.0"` |

### 6.4 `plugins/project-init/README.md`

anchor는 line 번호가 아닌 *인용 텍스트 prefix*로 지칭.

| Anchor (인용 텍스트 prefix) | 변경 |
|---|---|
| 첫 단락 끝의 `git workflow + LLM coding baseline 초기화 플러그인` | `+ LLM coding baseline` 제거 → `git workflow 초기화 플러그인`. 나머지 문장 유지. |
| 디렉토리 트리 `│   ├── llm-guidelines.md` | 줄 전체 제거 |
| "동작 방식" 섹션의 `- AGENTS.md — ## LLM Coding Guidelines + ## Git Workflow` | `## LLM Coding Guidelines +` 제거 → `- AGENTS.md — ## Git Workflow (...)` |
| "기능" 테이블 행 ``| **LLM Coding Guidelines** | Karpathy 유래 4-bullet 행동 baseline을 CLAUDE.md에 주입 |`` | 행 전체 제거 |
| "인스턴스화한 원칙" bullet 시작 `**Law 1 (Clarity Before Code)** — 4-bullet LLM Coding Guidelines (Karpathy 유래:` | bullet **전체 제거**. **참고**: 동일 섹션의 v1.4.0 docs-lint bullet (`**Law 1 (Clarity Before Code) — v1.4.0**`로 시작)은 그대로 보존. |
| "인스턴스화한 원칙" bullet 안의 `(8줄 LLM 블록 + Git Workflow 요약)` | `8줄 LLM 블록 + ` 제거 → `(Git Workflow 요약)`. 나머지 문장 유지 ("Plugin shape — minimal pointer pattern" bullet 자체는 보존). |

### 6.5 `plugins/project-init/CHANGELOG.md`

최상단에 다음 entry 삽입:

```markdown
## [1.5.0] — 2026-05-26

### Removed

- `templates/shared/llm-guidelines.md` 파일 및 `## LLM Coding Guidelines` 섹션 emission 전면 제거. `/project-init`은 더 이상 타깃 프로젝트의 AGENTS.md에 4-bullet behavior baseline을 주입하지 않는다.
- Plugin layer(`plugin.json` description, `commands/project-init.md` frontmatter & Step 5 확인 메시지, README) 전체에서 Karpathy attribution 및 LLM Coding Guidelines 참조 제거.

### Changed

- `commands/project-init.md` Step 4a 읽기 목록 6 → 5 파일 (`llm-guidelines.md` 제외).
- `commands/project-init.md` Step 4c 4-state matrix의 S1·S2a·S3 행에서 `## LLM Coding Guidelines` 섹션 관리 로직 제거 — `## Git Workflow`만 관리.
- devbrew root `CLAUDE.md`에서도 동일 섹션 제거 (dogfooding 일관성).

### Migration / Note

- 이미 이전 버전으로 `/project-init`을 실행한 사용자의 `AGENTS.md` 또는 `CLAUDE.md`에 주입된 `## LLM Coding Guidelines` 섹션은 **자동 제거되지 않는다**. 원하면 manual 삭제 권장.
- 재실행 시(Step 4c S3 path)도 기존 `## LLM Coding Guidelines` 섹션은 비-관리 컨텐츠로 분류되어 보존됨 — `## Git Workflow` 섹션만 in-place 갱신.

### Rationale

- 4-bullet wording (`요청 이상 만들지 않기, 추측 금지` / `인접 코드 청소 금지`)이 action 제약과 suggestion 제약을 구분하지 못해 proactive observation·제안 표면을 의도치 않게 줄이는 chilling effect 발생. wording fix 비용 대비 net benefit이 낮다고 판단하여 전면 제거. Claude Code 기본 시스템 프롬프트가 이미 동등한 행동 baseline (Think Before, Simplicity, Surgical, Goal-driven)을 제공.
```

### 6.6 `/Users/jeonghokim/Downloads/devbrew/CLAUDE.md`

라인 10–16 (`## LLM Coding Guidelines` 헤더 + 빈 줄 + 4-bullet + 빈 줄) 제거. 결과: 라인 9의 intro 단락 종료 후 곧장 라인 17의 `## Git Workflow`로 이어짐.

## §7 Verification Plan

1. **Grep gate (필수, AC7) — CI-runnable, zero-output = pass**
   ```bash
   grep -rEn "LLM Coding|llm-guidelines|Karpathy" \
     /Users/jeonghokim/Downloads/devbrew/plugins/project-init/ \
     /Users/jeonghokim/Downloads/devbrew/CLAUDE.md \
     | grep -v "CHANGELOG.md"
   ```
   기대: 명령 output이 **0줄**. 1줄 이상이면 fail. `CHANGELOG.md`의 historical entries (v1.0.0~v1.4.0) + 새 v1.5.0 entry는 정상적으로 LLM 참조를 보존하므로 명시적으로 제외.

   **추가 verification (AC4 — grep으로 잡히지 않는 케이스)**
   ```bash
   grep -n "8줄 LLM 블록" /Users/jeonghokim/Downloads/devbrew/plugins/project-init/README.md
   ```
   기대: 0줄.

2. **Smoke — scratch dir 신규 init (AC8)**
   - 임시 디렉토리에서 `git init` 후 `/project-init github-flow`
   - 생성된 `AGENTS.md`에 `## Git Workflow`만 존재, `## LLM Coding Guidelines` 부재 확인
   - 생성된 `CLAUDE.md`가 `@AGENTS.md` 한 줄 thin pointer 유지 확인

3. **Hook 회귀 (AC9)**
   ```bash
   bash /Users/jeonghokim/Downloads/devbrew/plugins/project-init/hooks/tests/smoke.sh
   ```
   기대: 모든 fixture 통과.

4. **Existing-project upgrade — S3 path (AC10)**
   - 기존 4-bullet 포함 `AGENTS.md` + `@AGENTS.md` pointer `CLAUDE.md`가 있는 디렉토리에서 `/project-init github-flow` 재실행
   - 결과: Step 4c S3 동작 → `## Git Workflow` 섹션만 in-place 갱신, `## LLM Coding Guidelines` 섹션 보존 (비-관리 컨텐츠 분류)

5. **Legacy CLAUDE-only migration — S2a path (AC11)**
   - 임시 디렉토리에 `CLAUDE.md`만 작성 (AGENTS.md 부재): 본문에 `## LLM Coding Guidelines` 4-bullet + `## Git Workflow` 섹션 둘 다 포함시킨다.
   - `/project-init github-flow` 실행 → Step 1 migration prompt 승인 → Step 4c S2a path 진입.
   - 결과 검증:
     - `AGENTS.md`가 새로 생성되었고 그 안에 (i) 새 `## Git Workflow` 섹션 (선택 strategy 기준), (ii) 기존 CLAUDE.md에서 이전된 `## LLM Coding Guidelines` 섹션(4-bullet 그대로)이 모두 존재.
     - `CLAUDE.md`가 `@AGENTS.md` 한 줄 thin pointer로 교체됨.
     - `grep "Think Before Coding" AGENTS.md` → 1줄 hit (사용자 컨텐츠 보존 확인).

6. **devbrew CLAUDE.md self-check**
   - `head -25 CLAUDE.md`로 LLM Coding Guidelines 섹션 제거 + `## Git Workflow`까지 깨끗하게 이어지는지 시각 확인.

## §8 Rejected Alternatives

- **B. Phased deprecation (v1.5.0 = soft deprecate, v2.0.0 = remove)** — 사용자의 *"chilling > 소득"* 결론과 모순. 해로움을 알면서 한 사이클 emission. 작업이 2 PR로 분산되어 compounding cost 증가.
- **C. Wording disambiguation만 적용** — 사용자가 직접 거절. ambiguity는 실재하나 wording fix만으로는 동일 chilling 위험이 재발 가능성. 사용자 판단으로 net benefit 낮음.
- **D. 빈자리에 "Claude Code defaults에 의존" 한 줄 pointer** — AGENTS.md에 behavior 메시지 주입을 다시 시작 → 같은 chilling 위험 재발. 사용자가 명시적으로 "아무것도 안 둠" 선택.
- **E. Retroactive auto-cleanup** — 사용자 agency 침해 + Step 4c "비-관리 컨텐츠 보존" 원칙 위반. 사용자가 명시적으로 "건들지 않음" 선택.
- **F. v2.0.0 major bump** — API/command surface는 unchanged이므로 사용자 코드를 직접 break하지 않음. 사용자가 minor 선택.
- **G. devbrew root CLAUDE.md는 별도 PR** — split-decision 위험 (dogfood 일관성 결함이 같은 commit window 안에서 노출됨). 사용자가 "함께 제거" 선택.

## §9 Metadata

- **Spec author**: Claude (brainstorming skill 진행)
- **User decisions verbatim**:
  - 수정 방향 → Other: "LLM Coding Guidelines 아에 제거하자"
  - 제거 이유 → "Chilling·과도 제약이 실제 소득보다 큼"
  - 빈자리 정책 → "아무것도 안 둘 — clean removal"
  - devbrew 자체 → "함께 제거 (dogfooding 일관성)"
  - Retroactive → "건들지 않음 (사용자 manual)"
  - Approach + Ver → "A + v1.5.0 (minor)"
- **Affected memories** (참고):
  - `feedback_devbrew_design_lightness.md` — 기존 surface 제거가 새 surface 추가보다 우선
  - `feedback_plugin_version_bump.md` — 같은 commit에서 version bump 필수
  - `feedback_spec_when_scope_grows.md` — substantial change이므로 spec 단계 거침 (본 문서)
  - `project_github_flow.md` — PR base는 `main`
- **Next step**: 본 spec 사용자 승인 → `writing-plans` skill로 implementation plan 작성 → 새 워크트리에서 구현 → PR → quality-gates.
