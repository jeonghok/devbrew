# Changelog

`project-init` 플러그인의 모든 주요 변경사항은 본 파일에 기록됩니다.

포맷은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기준으로 하고,
이 프로젝트는 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [3.0.0] — 2026-08-23

### Added
- `tests/test_no_write_matcher_hooks.sh` — 이 플러그인의 `PostToolUse` 항목 중 쓰기 도구(`Write`/`Edit`/`MultiEdit`/`NotebookEdit`)에 발화하는 것이 하나도 없음을 잠근다. matcher 부재·빈 문자열도 "전체 도구에 발화"로 취급하고(실측, Claude Code 2.1.239), `Bash` matcher 항목의 생존을 양성 대조로 확인한다.

### Removed
- **`hooks/docs-lint.py` (PostToolUse, `matcher: "Write|Edit|MultiEdit"`)** — 쓰기-도구 matcher 는 Bash heredoc·`sed -i` 로 쓴 파일을 보지 못한다. 열거를 고치는 대신 검사 자체를 제거했다(이동 아님). 함께 사라지는 검사: R1 크기 · R2 목차 · R5 코드펜스 언어 · R6 내부 링크 해석 · `CLAUDE.md`↔`AGENTS.md` 포인터 drift · `AGENTS.md` 의 `## Project Charter` 필수 하위항목 무결성. 이것들을 대신 수행하는 훅·테스트·게이트는 리포에 없다.
- `tests/test_docs_lint.py` — 위 훅의 테스트.
- `tests/smoke.sh` — 존재 이유가 스스로 밝힌 첫 줄 그대로였다: `# Runs the docs-lint hook against every fixture and asserts expected stdout pattern.` 훅이 사라지며 유일한 소비자를 잃었다.
- `tests/fixtures/` (19개 파일) — 위 smoke script 의 유일한 소비 대상이던 fixture 트리(happy/violation 케이스 전부).

### Deprecated
- kill switch 토큰 `DEVBREW_SKIP_HOOKS=project-init:docs-lint` 은 가리킬 대상을 잃었다. 설정해도 아무 효과가 없다 — 런타임 advisory 는 두지 않는다(대응하는 기능이 옮겨간 것이 아니라 사라졌으므로 조용한 재활성화가 일어날 수 없다). CLAUDE.md §메타데이터의 one-minor deprecation window 없이 훅과 토큰을 같은 릴리스에서 제거한다 — 근거: `hooks/docs-lint.py` 는 애초부터 non-blocking advisory 전용이었다(자기 docstring "Non-blocking advisory pattern: outputs systemMessage on violation, {} on pass"; `main()`의 모든 반환 경로가 `return 0`; `emit()`이 내보내는 JSON은 `{"systemMessage": ...}` 또는 `{}` 뿐, 차단·거부 필드 없음 — 삭제 직전 파일 `git show d44c56a^:plugins/project-init/hooks/docs-lint.py`로 확인). 이 훅의 제거가 깰 수 있는 것은 advisory 메시지 노출뿐이라, deprecation window 가 보호하려는 대상("작동 중인 동작이 예고 없이 사라짐")이 애초에 존재하지 않는다. **이 근거는 훅이 blocking 이었다면 성립하지 않는다** — 그런 경우 이 문단을 전례로 인용하지 말고 별도 deprecation window를 둘 것.

### Changed
- `commands/project-init.md` — 헌장 abort advisory 가 더 이상 "docs-lint 이 사후 플래그합니다"를 약속하지 않는다. `.claude/rules/agent-tool-permission.md` 를 `AGENTS.md` 에서 링크하지 않는 배치 결정은 유지하되, 근거에서 docs-lint R6 참조를 뺐다.

## [2.1.1] — 2026-08-22

`agent-tool-permission.md` 템플릿을 영어로 다시 쓰고 출처·배경 문단을 제거한다.

### Changed
- 템플릿 언어를 한국어 → 영어로. 이 산출물은 임의의 대상 레포에 떨어져 모델이 읽는
  생성물이라 이 리포의 Korean-primary doc convention 적용 대상이 아니다. 되돌림을 막기
  위해 한글 부재를 테스트로 잠갔다.

### Removed
- 출처 문단(`/project-init` 이 생성했다는 설명)과 배경 문단(하니스가 기본 주입하는
  문장에 대한 해설). 근거는 CHANGELOG·PR 에 남기고 산출물에는 행동에 필요한 것만 둔다
  — CLAUDE.md 의 **Self-narrating artifact** 금지 패턴.

## [2.1.0] — 2026-08-22

`/project-init` 이 선택적으로 `.claude/rules/agent-tool-permission.md` 를 생성한다 —
이 리포에서 Agent(subagent) 호출을 매번 승인 없이 허용하는 레포-스코프 규칙 파일.
minor 인 이유: 새 질문 + 새 산출물이라 surface 가 늘었다.

### Added
- `templates/shared/agent-tool-permission.md` — 규칙 본문. 허용 범위는 **Agent 만**이며
  Workflow · deep-research 는 명시적으로 제외한다.
- `commands/project-init.md` `### Step 3.6` — 허용 여부를 묻는 산문 yes/no 질문. 질문 수는
  charter Phase 1 의 `≤4개` 한도와 합산하지 않는다(독립 카운트).
- `commands/project-init.md` `#### 4f` — 허용 시 `.claude/rules/agent-tool-permission.md`
  생성 + `.gitignore` 에 **그 경로 한 줄만** 추가. `.claude/` 통째 무시는 금지 — 대상 레포가
  `.claude/settings.json` 등을 추적 중일 수 있다.
- `tests/test_agent_permission_contract.py` — 템플릿의 범위 제한 문장과 4f 계약의 회귀 락.

### Notes
- 이 산출물은 `AGENTS.md` 에서 링크하지 않는다. git 제외 파일을 커밋되는 문서가 가리키면
  docs-lint R6(내부 링크 해석)이 매 `AGENTS.md` 쓰기마다 발화한다.
- `.claude/rules/*.md` 는 docs-lint 의 검사 대상이 아니다(`hooks/docs-lint.py` 의
  `TARGET_RELPATHS` + `docs/project/` prefix 밖). 짧은 고정 파일이라 수용한 trade-off.

## [2.0.1] — 2026-08-22

`commands/project-init.md`의 `allowed-tools:` frontmatter 줄을 제거한다.
patch인 이유: 이 필드는 애초에 아무 동작도 바꾸지 않았다 — 제거해도 shipping
동작은 한 바이트도 바뀌지 않는다.

### Removed
- `commands/project-init.md`의 `allowed-tools: ["Bash", "Read", "Write",
  "Edit", "Glob", "Grep"]` 줄. 근거(2026-08-22 헤드리스 실측, `--plugin-dir`
  격리 플러그인, 5변형): `allowed-tools: ["Read"]`로 `Bash`를 빼놓아도 `Bash`가
  실행됐고, 스코프 표기(`Bash(<pattern>:*)`)도 범위 밖 명령을 막지 못했다 —
  이 계층은 제한이 아니다. agent frontmatter의 `tools:`(fail-closed, Law 2
  집행 지점)와는 다른 계층이다(CLAUDE.md에 되돌림 방지 문장 추가).

### 동작 무변경
command frontmatter의 선언 하나가 사라졌을 뿐, 실행 경로는 그대로다.

## [2.0.0] — 2026-08-20 (BREAKING)

Task 25(무게 감축): 환경변수 어순을 `DEVBREW_<PLUGIN>_<REST>` 하나로 통일.
`DEVBREW_DISABLE_PROJECT_INIT` → `DEVBREW_PROJECT_INIT_DISABLE`. 이 플러그인이
소유한 유일한 kill switch. `shared/killswitch/kill_switch_active.py` 정본(과 이
플러그인의 `scripts/kill_switch_active.py` 물리 사본)의 전역 스위치 **도출식**도
`DEVBREW_DISABLE_<PLUGIN>` → `DEVBREW_<PLUGIN>_DISABLE`로 함께 바뀌었다 — 리터럴
문자열 치환으로는 안 잡히는 자리였다.

### Deprecated
- 환경변수 어순을 `DEVBREW_<PLUGIN>_<REST>` 하나로 통일. 옛 이름(`DEVBREW_DISABLE_PROJECT_INIT` 등)은
  **fallback 없이 즉시 제거**됐다. 근거: 현재 제3자 설치가 없다 (CLAUDE.md §메타데이터의
  one-minor deprecation window 와의 충돌을 그 조건 아래 수용). **제3자 설치가 생기면 이 근거가
  바뀐다** — 그때는 다음 rename 에 fallback 창을 둔다.

### Changed (devbrew weight-reduction Task 29)
- `commands/project-init.md`의 `allowed-tools:` 표기를 `[Bash, Read, Write,
  Edit, Glob, Grep]`(따옴표 없음)에서 `["Bash", "Read", "Write", "Edit",
  "Glob", "Grep"]`(따옴표 있는 패턴 표기)로 통일했다 — `quality-gates`의
  `cancel-qg.md`/`qg.md`/`qg-publish.md`가 이미 쓰는 표기와 맞춘 것.
  도구 집합은 불변.

### Fixed (devbrew weight-reduction Task 30)
- `tests/test_docs_lint.py:232`(`test_350_lines_with_korean_toc_passes`)가
  한국어 TOC(`## 목차`) 문자열을 `encoding` 미지정으로 쓰고 있었다 —
  non-UTF-8 로케일에서 재현 불가능해질 수 있는 유일한 test-file 자리였다
  (다른 write_text 사이트는 전부 ASCII 픽스처).

## [1.8.0] — 2026-08-19

devbrew-weight-reduction Task 19 — kill switch 판정을 `shared/killswitch/kill_switch_active.py`
정본으로 이관. 이 플러그인의 두 훅은 자체 `kill_switch_active()` 정의를 지우고
`scripts/kill_switch_active.py` (`copy-of` 물리 사본)를 import 한다.

patch 가 아니라 **minor** 인 이유: 두 훅이 **이벤트명 별칭**(`project-init:PostToolUse`)을
새로 받는다. 이관 전에는 훅명만 받았고 spec-distill 훅은 이벤트명·훅명 둘 다 받았다 —
한 플러그인에서 배운 형태가 다른 곳에서 조용히 안 먹는 것이 결함이며, kill switch 는
보안 컨트롤이라(`CLAUDE.md:48`) 그 결함의 방향이 fail-open 이다. 둘 다 받는 쪽으로
통일했다(더 잘 꺼지는 방향 — 회귀는 반대 방향뿐이다).

### Added
- `scripts/kill_switch_active.py` — `shared/killswitch/kill_switch_active.py` 의
  `# copy-of:` 물리 사본. 설치본에는 `shared/` 가 없으므로 형제 사본이어야 import 가 풀린다.
  이 플러그인의 첫 `scripts/` 디렉토리다.
- 두 훅이 `DEVBREW_SKIP_HOOKS=project-init:PostToolUse` 를 받는다(둘 다 PostToolUse 훅이라
  이 토큰 하나가 둘을 함께 끈다).

### Changed
- `hooks/post-tool-use.py`·`hooks/docs-lint.py` — 자체 `kill_switch_active()` 정의 삭제,
  정본 import + `("project-init", "<훅명>", "PostToolUse")` 호출로 교체. 기존 토큰
  (`project-init:post-tool-use`·`project-init:docs-lint`)과 전역
  `DEVBREW_DISABLE_PROJECT_INIT=1` 의 동작은 불변.
- 두 훅의 docstring 에 `Kill switches:` 블록 추가. 이관 전 이 두 파일은 kill switch 환경변수
  이름을 **함수 본문에만** 갖고 있어서, 본문을 정본으로 옮기면 소스 텍스트에서 그 이름이
  사라졌다 — `plugin-audit` 의 `check-shape-completeness.py` 는 등록된 훅 스크립트의
  텍스트에 그 이름이 있는지로 `hooks_killswitch` 를 판정하므로, docstring 이 없으면 이
  플러그인이 그 검사에서 조용히 gap 으로 떨어진다(이관 전후 실측으로 확인).
- `README.md` — 이벤트명 별칭 문서화. `docs-lint` 항목의 *"새 토큰 없음"* 서술은 이제
  거짓이라 문장을 고쳤다(헌장 전용 토큰이 없다는 원래 뜻은 유지).

## [1.7.5] — 2026-08-17

devbrew-weight-reduction Task 14 — 자체 판정 헬퍼 이관. `test_branch_strategy_rebase_clause.sh`의
자체 `pass`/`fail` 카운터·헬퍼 정의를 지우고 `shared/tests/assert.sh` 정본을 source(`pass`→`ok`,
`fail`→`no`로 호출부 개명, 종료를 `finish`로 통일). 판정 로직·assertion 5건은 그대로.

### Changed
- `tests/test_branch_strategy_rebase_clause.sh` — 정본 source, 종료 행동은 non-zero 유지.

## [1.7.4] — 2026-08-17

devbrew-weight-reduction Task 12 — 테스트 디렉토리 규약 3종(`tests`·`scripts/tests`·`hooks/tests`)을
`plugins/<name>/tests/` 하나로 통일. 이 플러그인은 `hooks/tests/`가 `tests/`로 합쳐졌다(기존
`test_branch_strategy_rebase_clause.sh`와 파일명 충돌 없음).

### Changed
- `hooks/tests/*` → `tests/*`(git mv, 6개 항목 — `__init__.py`·`fixtures/`·`smoke.sh`·
  `test_command_contract.py`·`test_docs_lint.py`·`test_post_tool_use.py`). 세 파일의 파이썬
  `Path(__file__).resolve()` 상대경로 재앵커: `test_command_contract.py`(`parents[2]`→`parents[1]`),
  `test_docs_lint.py`/`test_post_tool_use.py`(`.parent.parent`가 더 이상 `hooks/`에 닿지 않아
  `.parent.parent / "hooks"`로 세그먼트 추가 — 착수 전 계측이 `parents[N]` 대괄호 형태만 찾고
  이 `.parent.parent` 체인 형태를 놓쳐, 이동 직후 파이썬 수집이 95→7건으로 무너지는 것으로
  드러났다). `smoke.sh`의 `ROOT=` 4-up dirname을 3-up으로.

### Fixed
- 이동 후 `plugins/project-init/tests` 파이썬 수집 수는 이동 전(`hooks/tests`)과 동일한 95건
  (회귀 0), 셸(`smoke.sh`) GREEN 유지.
- `README.md`의 아키텍처 트리 다이어그램이 `tests/`를 여전히 `hooks/` 아래 중첩으로 그리고
  있었다(리터럴 문자열 `hooks/tests`가 파일에 없어 grep으로 못 잡힘 — 경로가 박스 문자로
  분해된 그림이라 문자열 패턴 검색의 사각지대였다). `tests/`를 `hooks/`의 형제(플러그인
  최상위)로 정정하고 실제 내용(옮겨온 3개 파일 + 기존 `test_branch_strategy_rebase_clause.sh` +
  `__init__.py` + `fixtures/`)을 반영.

## [1.7.3] — 2026-08-03

harness-capability-suppression-sweep Task 11(S4) — 규약 정렬. `templates/github-flow/`와
`templates/git-flow/`의 branch-strategy 템플릿이 "기존 feature 브랜치는 `git merge
origin/main`(또는 `origin/develop`)으로 sync, `git rebase`는 절대 안 됨"이라는
무조건 금지 조항을 신규 프로젝트에 심고 있었다 — rebase가 정말 unsafe한 것은
이미 push돼 다른 사람이 받아간 공유 브랜치뿐인데, 아직 공유되지 않은 로컬 정리까지
막는 과잉 규약이었다.

### Changed
- `templates/github-flow/branch-strategy.md`, `templates/git-flow/branch-strategy.md`:
  무조건 rebase 금지 조항을 "공유된 브랜치는 rebase하지 않는다"로 재정식화 — rebase가
  commit SHA를 rewrite하므로 이미 push돼 공유된 브랜치에서 unsafe하다는 근거는 유지하되,
  아직 공유되지 않은 로컬 브랜치 정리는 각자 판단으로 남긴다. 두 템플릿 모두 동일하게
  변경(한쪽만 고치면 다른 variant에서 억제가 산다).
- 리포 루트 `docs/git-workflow/branch-strategy.md`는 **변경하지 않았다** — 이 문서는
  사용자 본인이 명시한 선호이며 이 sweep의 스코프 밖(C3).

### Added
- `tests/` 디렉토리 신설(이 플러그인 최초의 테스트). `test_branch_strategy_rebase_clause.sh`
  — AC8e 락, 양방향: 템플릿 2개 모두에서 무조건 금지 조항 부재 + 완화된 조항 실재를
  확인하고, 동시에 리포 루트 문서에는 원문 금지 조항이 **그대로 남아 있어야** PASS —
  템플릿만 확인하면 리포 루트를 "정합"이라는 명분으로 함께 덮어써도 못 잡기 때문.

## [1.7.2] — 2026-07-09

(v1.7.1은 marketplace description 압축에 따른 doc-only patch bump — 동작 변경 없음.)

### Fixed

- **S2a migration이 `AGENTS.md`를 `# CLAUDE.md`로 잘못 제목 짓던 문제** — `commands/project-init.md` 4c 행렬은 "비-관리 컨텐츠 (다른 헤딩, 단락, 코드 블록)는 모든 state에서 보존"을 지시하고 H1에 대한 예외가 없었다. 그래서 `# CLAUDE.md`로 시작하는 흔한 형태의 CLAUDE.md를 migrate하면 산출된 `AGENTS.md`가 자기 자신이 아닌 원본 파일명을 제목으로 달았다. 4c S2a에 `(d)` 규칙을 추가 — **이전된 H1이 원본 파일명을 지칭할 때만** `# AGENTS.md`로 재제목하고, `# My Project` 같은 실제 프로젝트 제목은 종전대로 보존한다. 좁은 규칙이라 non-breaking.
- 발견 경위: devbrew context-slimming WS5의 sandbox 재실행 — 감량된 repo 사본에서 `/project-init`을 S2a 승인 경로로 실제 수행해 산출물을 검사했다. 손-큐레이션 컨텐츠는 파괴되지 않고 `AGENTS.md`로 정상 이전됐으며(AC15/AC16 green), 이 제목 결함만 남았다.

### Added

- `hooks/tests/test_command_contract.py` — `commands/project-init.md`의 산문 계약 회귀 락. 명령서는 모델이 따르는 지시서라 동작을 실행할 수 없으므로, 규칙의 *존재*를 잠근다: 4c S2a `(d)` H1 재제목, 그 규칙의 좁은 범위(프로젝트 제목 보존), 보존 규칙이 예외를 명시하는지, 그리고 Step 1의 migration 거절 → 전체 abort (AC21). 각 assert는 규칙을 소유한 텍스트로 스코프된다 — 섹션 마커는 유일성을 강제하고(`section()`), 4c S2a 표 셀이 보존 규칙의 첫 어절을 인용하고 있으므로 그 규칙만은 줄-시작 앵커로 특정한다(`standalone_line()`). 인용문만 남기고 규칙을 지우는 mutation은 RED.

## [1.7.0] — 2026-07-05

### Changed

- **`hooks/post-tool-use.py` enforcement가 선택된 git 전략에 충실해짐** — 브랜치 검증 폴백이 전략 미선언 시 GitHub-Flow 패턴(`^(feature|fix)/…`)을 단정하던 것을 **loud-advisory fail-open**으로 교체. `get_branch_pattern()`의 반환 계약이 `re.Pattern` → `Optional[re.Pattern]`로 바뀌어, 전략 파일 부재·`` ```regex `` 블록 부재·malformed regex·빈/공백-only regex 블록·non-UTF-8 파일(디코딩 불가)의 다섯을 모두 `None`(검증 생략 + discoverable advisory)으로 통일 — 마지막은 crash 대신 loud fail-open(qg-security). Git Flow의 `release/*`·`hotfix/*`가 더는 silent 거부되지 않는다.
- 위반 브랜치 교정 제안이 **활성 패턴에서 파생**(`derive_prefixes()`) — 항상 `feature/<name>`을 제안하던 하드코딩 제거. Git Flow에서 `hotfix-login` 오타에 허용 prefix(`feature, fix, release, hotfix`) 목록과 `git branch -m <prefix>/…` 플레이스홀더를 제시. exotic regex(inline flags `(?i)`·nested group·리터럴 접두)는 `docs/git-workflow/branch-strategy.md` 참조로 강등.
- `main()`이 branch·commit 검증기를 **둘 다 실행**하고 경고를 concatenate — 기존 `or` short-circuit이 compound 명령(`git checkout -b … && git commit -m …`)에서 commit 검증을 건너뛰던 회귀를 봉쇄. advisory·non-blocking 성격 불변.
- `templates/trunk-based/branch-strategy.md` Pattern B 노트에서 `DEVBREW_DISABLE_PROJECT_INIT=1` kill-switch 우회 안내 제거 — hook이 non-blocking advisory임을 정직히 설명(`release/*` backport는 경고를 무시하고 진행; hook 전체를 끄면 commit 검증까지 함께 꺼짐).

### Removed

- `DEFAULT_BRANCH_PATTERN` 상수 완전 제거 — fail-open이 `None`을 반환하므로 GitHub-Flow 디폴트 폴백이 dead code.

### Added

- `hooks/tests/test_post_tool_use.py` — `post-tool-use.py`의 첫 테스트 하니스(`unittest`, `importlib` 로드). F1 fail-open(부재/regex-less/malformed/빈-블록/비-UTF-8)·F1 회귀 락(`DEFAULT_BRANCH_PATTERN` 부재)·F2 파생(`(?i)` 오파싱 방지 포함)·`main()` 이중 검증·비-UTF-8 locale UTF-8 판독·보존 동작(kill switch·non-Bash·malformed JSON·Conventional Commits) 커버.

### Rationale

- 감사 결과 3전략 지원 설계 자체는 건전하나 enforcement 계층이 세 지점에서 미선택 GitHub Flow를 단정하는 전략-불충실 버그였다(brief §1 root cause). "조용히 GitHub Flow로 검증"보다 "시끄럽게 검증 생략"이 fail-open 원칙에 충실. merge/base-branch 런타임 강제(F4/F5)는 "harness lightness — trust the model"로 명시 defer.

## [1.6.0] — 2026-05-31

### Added

- **Project Charter surface** — `/project-init`에 charter step(Step 3.5) 추가. **Phase 0** (fact-routing): `package.json`/`pyproject.toml`/`go.mod`/`Cargo.toml`/`pom.xml`/`build.gradle`/`Gemfile`/`composer.json` 등 manifest와 디렉토리 구조를 스캔해 tech-stack을 `[감지됨]` 라벨로 자동 후보 생성. **Phase 1**: AskUserQuestion ≤4개(vision·non-goals·핵심 conventions·tech-stack 확인)만 사용자에게 묻는다. manifest 부재 시 loud fallback으로 직접 질문 downgrade (C6).
- 헌장 발행: `AGENTS.md`에 `## Project Charter` 요약 섹션(≤약 25줄) + `docs/project/charter.md`·`docs/project/conventions.md`(+ 조건부 `docs/project/glossary.md`) 상세 파일. `CLAUDE.md`는 `@AGENTS.md` thin pointer 유지.
- `templates/project/` — 4개 skeleton(`agents-md-section.md`, `charter.md`, `conventions.md`, `glossary.md`). placeholder만 있는 빈 골격이며 의견 콘텐츠를 주입하지 않는다 (charter 콘텐츠 100% 사용자 elicited).
- `hooks/docs-lint.py` — additive 확장. `is_charter_doc()` predicate로 `docs/project/*.md`를 lint 대상에 추가(기존 4-path exact-set 불변, regression-free) + R-charter 룰: `AGENTS.md`의 `## Project Charter` 섹션(heading-bounded)에서 vision·non-goals·tech-stack 레이블의 존재·비어있지 않음·`{{...}}` placeholder 잔존 없음을 advisory로 검출. **새 hook 파일·새 `hooks.json` entry·새 kill-switch 토큰 0개** — 기존 `DEVBREW_DISABLE_PROJECT_INIT=1` / `DEVBREW_SKIP_HOOKS=project-init:docs-lint`가 헌장 검증까지 커버.
- `hooks/tests/` — charter target / R-charter / template-consistency 테스트 + smoke fixtures(`charter_complete`, `charter_missing_subsection`, `charter_placeholder_residue`, `charter_doc_target`). `smoke.sh`에 `TARGETS` parallel array + length-parity guard 추가(docs/project/*.md 타겟 지원).

### Changed

- `commands/project-init.md` — Step 1 charter 상태 감지(파일 레벨 C-S1/C-S2/C-S3 + 도출 공식), Step 3.5 charter 흐름(Phase 0/1 + bounded Law 1 게이트), Step 4e 헌장 발행 + 멱등 state matrix, Step 5 확인 메시지에 헌장 파일 추가.

### Rationale

- spec-distill(per-feature `spec.md`)·quality-gates(review) 위에 비어 있던 **프로젝트 수준 durable 정의** 레이어를 채운다. 헌장이 AGENTS.md 계층에 거주하므로 매 세션·모든 spec-distill 인터뷰가 passive 상속(추가 런타임 비용 0). v1.5.0이 제거한 canned `## LLM Coding Guidelines`와 정반대 방향 — devbrew 의견이 아니라 사용자가 elicit한 정의만 캡처한다.

## [1.5.0] — 2026-05-26

### Removed

- `templates/shared/llm-guidelines.md` 파일 및 `## LLM Coding Guidelines` 섹션 emission 전면 제거. `/project-init`은 더 이상 타깃 프로젝트의 AGENTS.md에 4-bullet behavior baseline을 주입하지 않는다.
- Plugin layer(`plugin.json` description, `commands/project-init.md` frontmatter & Step 5 확인 메시지, README) 전체에서 Karpathy attribution 및 LLM Coding Guidelines 참조 제거.

### Changed

- `commands/project-init.md` Step 4a 읽기 목록 6 → 5 파일 (`llm-guidelines.md` 제외).
- `commands/project-init.md` Step 4c 4-state matrix의 S1·S2a·S3 행에서 `## LLM Coding Guidelines` 섹션 관리 로직 제거 — `## Git Workflow`만 관리. S2a 셀은 기존 CLAUDE.md의 `## LLM Coding Guidelines` 컨텐츠가 비-관리 컨텐츠로 자동 분류되어 AGENTS.md migration 시 보존됨을 명시.
- devbrew root `CLAUDE.md`에서도 동일 섹션 제거 (dogfooding 일관성).

### Migration / Note

- 이미 이전 버전으로 `/project-init`을 실행한 사용자의 `AGENTS.md` 또는 `CLAUDE.md`에 주입된 `## LLM Coding Guidelines` 섹션은 **자동 제거되지 않는다**. 원하면 manual 삭제 권장.
- 재실행 시(Step 4c S3 path)도 기존 `## LLM Coding Guidelines` 섹션은 비-관리 컨텐츠로 분류되어 보존됨 — `## Git Workflow` 섹션만 in-place 갱신.

### Rationale

- 4-bullet wording (`요청 이상 만들지 않기, 추측 금지` / `인접 코드 청소 금지`)이 action 제약과 suggestion 제약을 구분하지 못해 proactive observation·제안 표면을 의도치 않게 줄이는 chilling effect 발생. wording fix 비용 대비 net benefit이 낮다고 판단하여 전면 제거. Claude Code 기본 시스템 프롬프트가 이미 동등한 행동 baseline (Think Before, Simplicity, Surgical, Goal-driven)을 제공.

## [1.4.0] — 2026-05-17

### Added
- `hooks/docs-lint.py` — root context 파일 (`CLAUDE.md`/`AGENTS.md`/`.claude/CLAUDE.md`/`.claude/AGENTS.md`) 의 5 agent-readable convention rule을 PostToolUse advisory로 검증. R1 size (>200 warn, >300 STRONG), R2 TOC (>300 lines required), R5 fenced code language tag, R6 internal links resolve, R-pointer CLAUDE/AGENTS drift (bidirectional trigger). Non-blocking, kill switch `DEVBREW_SKIP_HOOKS=project-init:docs-lint`. 디자인 근거: Anthropic 공식 ([code.claude.com/docs/en/memory.md] *"target under 200 lines"*) + AGENTS.md 오픈 스펙 ([agents.md] 16+ 벤더 채택) + Chroma 2025 *Context Rot* (input length에 monotonic degradation) + Lost-in-the-Middle (Liu 2023) 3-source 합의.
- `templates/shared/claude-md-pointer.md` — `@AGENTS.md\n` 한 줄, `/project-init`이 CLAUDE.md로 발행하는 thin pointer template.
- `hooks/tests/` — Python stdlib `unittest` 기반 40+ test case (모든 룰 happy/violation + kill switch + symlink + worktree + bidirectional trigger). fixture 9개 서브디렉토리 layout (`fixtures/<case>/AGENTS.md` 또는 `CLAUDE.md`).
- `hooks/tests/smoke.sh` — V2 자동화 smoke script (CI-runnable, no human eyeballing, macOS bash 3.2 호환).

### Changed
- `commands/project-init.md` Step 4 전반 — **AGENTS.md를 canonical**, **CLAUDE.md를 `@AGENTS.md` thin pointer**로 발행. 기존 단일-CLAUDE.md 5-state matrix를 *AGENTS.md × CLAUDE.md 2축 4-state matrix* (S1 clean / S2a CLAUDE-only full / S2b dangling pointer / S3 AGENTS canonical / S4 divergent) 로 재작성. 4-state matrix는 mutually exclusive AND exhaustive — raw 6 조합 중 S2가 (2→1), S4가 (2→1) 압축.
- `commands/project-init.md` Step 1 — 기존 CLAUDE.md가 있고 AGENTS.md가 없으면 migration 프롬프트 추가. 거절 시 전체 abort.
- `commands/project-init.md` Step 5 confirmation — AGENTS.md (canonical) + CLAUDE.md (`@AGENTS.md` thin pointer) 생성 명시.
- `templates/<strategy>/claude-md-section.md` → `agents-md-section.md` 3건 rename (`git mv`로 history 보존).
- `hooks/hooks.json` — PostToolUse에 두 번째 entry 추가 (matcher `Write|Edit|MultiEdit`).
- `plugin.json` description — AGENTS.md primary + thin pointer 패턴 반영.

### Migration notes
- 기존 v1.3.0 사용자가 `/project-init` 재실행 시 S2 path로 진입 → migration 프롬프트 → AGENTS.md 생성 + CLAUDE.md thin pointer 교체.
- 두 hook은 kill switch 토큰이 다름 (`project-init:post-tool-use` vs `project-init:docs-lint`). 둘 모두 끄려면 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use,project-init:docs-lint`.

## [1.3.0] — 2026-05-10

### Added
- `templates/shared/commit-conventions.md`에 `revert` commit type row 추가 (Conventional Commits v1.0.0 / Angular convention 표준 type, AC2). `hooks/post-tool-use.py:21` `CONVENTIONAL_COMMIT_PATTERN`과 line 141 error message도 동기화 (AC17, AC18).
- `templates/shared/commit-conventions.md`에 `## SemVer Mapping` 섹션 신설. `fix→PATCH`, `feat→MINOR`, `BREAKING CHANGE→MAJOR` 매핑 명시 — [Conventional Commits v1.0.0 §1](https://www.conventionalcommits.org/en/v1.0.0/) 정의에 따라 `release-please`/`semantic-release` 자동화 enabler (AC3).
- `templates/shared/commit-conventions.md`에 `## Issue References` 섹션 신설. `Closes: #N` (issue auto-close), `Refs: #N` (참조) footer pattern 예제 (AC4).
- `templates/shared/pr-process.md`에 `## Server-Side Enforcement` 섹션 신설. 6개 GitHub branch protection 항목 (PR reviews, status checks, linear history, no force push, signed commits, dismiss stale approvals) 명시. "client-side hook이 server-side를 대체하지 않음" 강조. [GitHub docs — About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) 참조 (AC6).
- `templates/git-flow/branch-strategy.md`에 `## When NOT to use Git Flow` 섹션 신설. [Vincent Driessen 2020 reflection](https://nvie.com/posts/a-successful-git-branching-model/) paraphrase 인용 — continuous delivery 팀이라면 GitHub Flow 권장, Git Flow는 versioned releases 한정. [Atlassian "legacy" 분류](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) cite (AC8).
- `templates/trunk-based/branch-strategy.md`에 `## Releasing` 섹션 신설. Pattern A (tag from trunk, default) + Pattern B (release branches for legacy version support, cherry-pick from trunk + kill switch 안내). [trunkbaseddevelopment.com](https://trunkbaseddevelopment.com/) canonical 권장 패턴 (AC14).

### Changed
- 3개 strategy의 branch naming regex가 `[\w.-]+` → `[a-z0-9][a-z0-9.-]*`로 tighten. `\w`가 대문자/언더스코어 허용해 산문의 "kebab-case" 권장과 정합성 결여였던 사실 오류 수정 (AC9, AC11, AC13). `hooks/post-tool-use.py:19` `DEFAULT_BRANCH_PATTERN` fallback도 동기화 (AC16). 기존 컨벤션 따르던 사용자 (`feature/foo-bar`)는 영향 없음 — 잘못된 이름 (`feature/Foo_Bar`, `feature/foo_bar`) 쓰던 사용자만 거부됨 (의도된 fix).
- `templates/shared/commit-conventions.md` `## Rules` 섹션의 subject line 한계가 72자 → **50자**로 변경. body wrap 72자 별도 명시. [Tim Pope 2008 *"A Note About Git Commit Messages"*](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html) canonical "50/72 rule" 정렬 — `git log --oneline`, GitHub PR list, 80-col terminal이 50자에서 truncate. [cbea.ms *"How to Write a Git Commit Message"*](https://cbea.ms/git-commit/) 동일 권장 (AC1).

### Fixed
- v1.2.3 이전 templates는 subject line 한계를 72자로 표기해 Tim Pope 50/72 rule의 두 한계 (subject 50 / body 72)를 혼동하고 있었음. AC1으로 시정.

## [1.2.3] — 2026-05-10

### Changed
- devbrew CLAUDE.md *"Korean-primary, English-terms-only"* 정책을 `plugins/project-init/`에 적용 (qg `28c6ffb` precedent 정렬). `README.md`, `CHANGELOG.md`, `commands/project-init.md` 본문이 Korean-primary로 재작성됨; 식별자, code, branch 이름, regex, frontmatter `description`은 영어 유지.
- `templates/shared/llm-guidelines.md`가 v1.2.0에서 확립한 *"English headers/code + Korean explainers"* 하이브리드 패턴을 다른 templates 전체로 확장 — `templates/shared/commit-conventions.md`, `templates/shared/pr-process.md`, `templates/<strategy>/branch-strategy.md` (3개), `templates/<strategy>/claude-md-section.md` (3개). Conventional Commits 식별자, regex, `gh` 명령, branch prefix, `**ALWAYS**`/`**NEVER**` 강조 토큰, `{{SCOPE_CONVENTION}}`/`{{MERGE_STRATEGY}}` placeholder, `## Git Workflow` anchor 영어 유지.

## [1.2.2] — 2026-05-10

### Security
- `hooks/post-tool-use.py`가 devbrew kill-switch 계약을 존중하도록 수정. opt-out: `DEVBREW_DISABLE_PROJECT_INIT=1` 또는 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use`. 이전 버전은 escape hatch가 없어 모든 `Bash` PostToolUse마다 무조건 실행됐고, 이는 `CLAUDE.md` §Plugin Shape ("어떤 훅도 자신의 kill switch 존중을 거부할 수 없음 — kill switch는 보안 컨트롤") 위반이었음.

### Added
- devbrew CLAUDE.md 요구사항에 따른 `README.md` "Hooks Installed" 섹션 (한 줄 "왜 skill이 아닌가" justification + kill-switch 문서화).

### Changed
- `README.md` Architecture tree에 박혀 있던 하드코딩 버전 주석 제거 (플러그인이 `1.2.1`일 때 `v1.2.0`으로 stale).

## [1.2.1] — 2026-05-07

v1.2.0 template default 보정용 same-day 패치 — 의도된 중복 날짜.

### Changed
- `templates/github-flow/branch-strategy.md`와 `templates/git-flow/branch-strategy.md`가 base와 feature 브랜치 동기화 시 default를 `git merge`로 변경. 새로 추가된 "Rules for Claude" 라인이 *"rebase golden rule"* (Pro Git §3.6 *"Rebasing"*)을 인용 — rebase는 history를 rewrite하므로 push된 브랜치에는 unsafe. one-line teachability와 로컬 브랜치 force-push safety를 위해 strict variant (always merge, never rebase) 채택.

### Removed
- 타깃 프로젝트의 `CLAUDE.md`에 더 이상 Andrej Karpathy attribution blockquote (`> Andrej Karpathy의 [LLM 코딩 관찰]...`)가 주입되지 않음. 4-bullet baseline은 그대로. attribution은 플러그인 layer (README, plugin.json description, slash-command 확인 메시지, 본 changelog)에 보존됨 — directive는 타깃 프로젝트의 LLM-context anchor에만 적용.

## [1.2.0] — 2026-05-07

### Added
- 타깃 CLAUDE.md에 `## Git Workflow`와 함께 `## LLM Coding Guidelines` 섹션 주입. 하이브리드 포맷 (English headers + Korean explainers), Andrej Karpathy의 LLM 코딩 관찰을 4줄로 압축.
- 새 공유 template `templates/shared/llm-guidelines.md`.
- README "Principles Instantiated" 섹션이 Law 1 (Clarity Before Code)을 cite.
- 본 `CHANGELOG.md` (devbrew 룰 복구 — v1.1.0에서 누락이었음).

### Changed
- `commands/project-init.md` Step 4가 strategy 섹션 *앞에* LLM Guidelines 섹션을 읽고 prepend하도록 수정. Step 5 confirmation에 새 섹션 명시.
- `plugin.json` description이 dual-purpose 초기화를 반영하도록 업데이트.
- `commands/project-init.md` Step 4c가 단일 섹션 로직에서 4-state matrix로 확장 — `## LLM Coding Guidelines`와 `## Git Workflow`를 인접 블록으로 관리하면서도 비-관리 컨텐츠를 모두 보존.

## [1.1.0] — 2026-04-12

### Added
- 3개 branching strategy로 초기 public release: GitHub Flow, Git Flow, Trunk-based.
- strategy 선택과 CLAUDE.md + `docs/git-workflow/` 파일 생성을 위한 `/project-init` 인터랙티브 command.
- 브랜치 명명·Conventional Commits 포맷을 검증하는 PostToolUse hook.
- Templates: 공유 `commit-conventions.md`와 `pr-process.md`; strategy별 `claude-md-section.md`와 `branch-strategy.md`.
