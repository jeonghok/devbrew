# CLAUDE.md

> **Specify before you code. Review before you ship. Compound before you forget.**
> *코드보다 명세 먼저. 배포보다 리뷰 먼저. 잊기 전에 축적.*
>
> *병목은 모델이 아니다. 스펙, 리뷰, 메모리다. devbrew의 역할은 사용자가 의식적으로 기억하지 않아도 이 세 가지가 자동으로 지켜지도록 만드는 것이다.*

devbrew는 Claude Code를 위한 플러그인 마켓플레이스입니다. `plugins/*` 하위의 모든 플러그인은 아래 원칙을 상속합니다. 전체 철학(24개 원칙·14개 anti-pattern·소스 하니스 원문 인용)은 [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md). 외부 참조 corpus는 `../reference/`에 있으며 필요 시에만 탐색 [reference 탐색 가이드](../reference/REFERENCE_HARVEST.md).

## Git Workflow

GitHub Flow. `main`에서 분기, PR로 merge back. 상세는 `docs/git-workflow/`.

- Branch: `main`에서 `feature/*` 또는 `fix/*`. kebab-case, 2–4 단어.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: merge commit, `docs/git-workflow/pr-process.md` 참고
- project-init 플러그인이 브랜치 명명·commit 포맷 자동 검증

## The Three Laws

이 세 법칙이 모든 플러그인을 지배합니다. **충돌 시 Law N이 Law N+1을 override** — 명확성 먼저, 독립성 둘째, compounding 셋째.

**Law 1 — Clarity Before Code.** 명세가 모호한 상태에서는 구현이 진행되지 않습니다. 코드를 shipping하는 모든 플러그인은 실제 거절 메커니즘을 가져야 합니다 — 최소한 **구조적 게이트** (필수 섹션: Context/Why, Goals, Non-goals, Constraints, Acceptance Criteria, Files to Modify, Verification Plan, Rejected Alternatives, Metadata)를 silent하게 skip할 수 없어야 합니다. Adversarial self-review는 구조적 baseline 위에 강력 권장, 수치 스코어링은 허용되지만 권장하지 않음 (철학 §5.3). *Trivia escape:* 한 문장으로 설명 가능한 trivia diff (typo, rename, 주석-only, single-file formatting)는 게이트 우회. 정의 및 자격 규정은 philosophy §2.1 / P12 참조.

**Law 2 — Writer and Reviewer Must Never Share a Pass.** 코드를 쓴 턴은 그 코드를 승인할 수 없음. 분리는 프롬프트가 아니라 물리적: `allowed-tools` / `disallowed-tools` frontmatter로 리뷰어가 `Write`/`Edit`을 literally 할 수 없게 만들기. 쓰기 권한이 있는 리뷰어는 리뷰어가 아님. 검증은 load-bearing 인프라, 나중 생각이 아님. *Scoped exception (qg v2.2.0):* 실제 서비스를 실행해야 하는 executor(runtime-verifier)는 `Write`를 갖되, 분리는 도구 deny가 아니라 **orchestrator가 immutable baseline 대비 `git diff`로 product 변경을 잡아 verdict를 ≤FAIL로 강제 + 무커밋 + 샌드박스 폐기**하는 구조적 가드로 보장 — verifier 주장과 독립이라 self-approval이 구조적으로 불가능 (철학 §1 Law 2 R6 note).

**Law 3 — Every Cycle Must Leave the System Smarter.** Compounding은 선택적 wrap-up이 아니라 discoverability check가 붙은 이름 붙은 단계. 사이클이 learning을 생산하면 하니스는 그것을 파일로 capture하고 다음 세션이 실제로 찾을 것임을 확인 — discoverability가 위험하면 인덱스 (`AGENTS.md`/`CLAUDE.md`)를 자동 편집. 어떤 미래 agent도 읽지 않는 파일에 기록하는 것은 theater.

## Plugin Shape

`plugins/*`의 모든 플러그인은 [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md) §4.0의 canonical 디렉토리 구조를 따르고 다음을 모두 만족해야 합니다.

### 메타데이터 & 버전 관리

- **모든 PR마다 SemVer bump가 붙는 `plugin.json`.** 필수: `name`, `description`, `version`. 플러그인을 건드리는 모든 PR마다 bump (major = breaking, minor = 새 surface, patch = fix) — 안 그러면 cache key가 silent stale. 보안-critical 의존성은 optional `integrity` field로 pin.
- **v1.0.0 이상이면 `CHANGELOG.md`.** `## [version] — YYYY-MM-DD` with Added/Changed/Deprecated/Removed/Fixed/Security. 제거 전 one-minor deprecation window.
- **`README.md`에 "Principles Instantiated"** — 이 플러그인이 embody하는 철학 법칙/원칙을 한 줄씩. Law 3의 compounding substrate: 미래 검색이 모든 instantiation을 찾음.

### 컴포넌트 격리

- **Scoped agents — default-everything 금지.** 모든 agent는 명시적 `allowedTools`/`disallowedTools`. 역할 프롬프트는 *"You are X. You are responsible for Y. You are NOT responsible for Z."*로 시작. 쓰기 권한이 있는 리뷰어는 Law 2 위반.
- **최소 버전이 선언된 의존성.** `other-plugin:agent-name`을 dispatch하는 플러그인은 README prerequisites에 `other-plugin`을 리스트. Silent coupling은 버그.
- **모든 skill에 `cost_class` 선언** (`low`|`medium`|`high`|`variable`). `high`는 지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke해야 함. Fan-out factor N ≥ 5는 hard review 게이트.

### 런타임 상태 & 훅

- **JSON이 아니라 마크다운 state.** State는 `.claude/<plugin>.local.md`에 살음 (git-ignored, 성공 시 auto-delete, 실패 시 디버깅을 위해 보존). per-session 격리가 필요하면 `.claude/<plugin>/<session-id>/...` 하위 디렉토리도 허용 — plugin namespace(`.claude/<plugin>/`) 하위에 머물 것 (철학 §4.8 참조). **Secret 기록 금지** — placeholder 참조 사용 (철학 P21).
- **모든 훅에 kill switch.** `DEVBREW_DISABLE_<PLUGIN>=1` 또는 `DEVBREW_SKIP_HOOKS=<plugin>:<hook>`. 어떤 훅도 자신의 kill switch 존중을 거부할 수 없음 — kill switch는 보안 컨트롤.
- **훅 공존.** 같은 event 내 훅은 교환 가능해야 함. Signal tag는 `<{plugin}-signal>` 네임스페이스. `SessionStart` 훅은 read-only 조언자, 절대 mutate 안 함. 각 훅은 README의 "Hooks Installed"에 "왜 skill이 아닌가"의 한 줄 justification과 함께 문서화.
- **Loud logging을 동반한 graceful degradation.** 누락된 optional 의존성은 capability를 downgrade, crash하지 않음 — 사용자가 출력에서 fallback이 돌았음을 알 수 있어야 함.

### 네이밍 & 보안

- **Progressive disclosure.** Skill 이름은 동명사 (`running-quality-gates`, `authoring-specs`). Command 이름은 짧은 명령형 (`qg`, `review`). 모호한 이름 (`helper`, `utils`, `"I can help you..."`) 없음.
- **Persona 파일은 보안-민감 코드.** Reviewer persona를 약화(규칙 제거, 임계치 완화)하는 PR은 보안 리뷰 대상. test-suite 편집과 같은 신중함으로 persona 편집을 treat.

## Building a New Plugin

**Starter 디렉토리 트리** — `.claude-plugin/`과 `README.md`는 필수. 나머지 서브디렉토리는 모두 optional이며, 플러그인이 해당 surface를 shipping할 때만 추가:

```
plugins/<your-plugin>/
├── .claude-plugin/
│   └── plugin.json           # 필수 — name, version (0.1.0로 시작), description
├── README.md                 # 필수 — "Principles Instantiated" 섹션 포함
├── CHANGELOG.md              # version ≥ v1.0.0이면 필수
├── commands/                 # optional — 짧은 명령형: qg.md, review.md
├── skills/<gerund-name>/     # optional — running-x, authoring-y (동명사)
│   └── SKILL.md              # cost_class 선언, frontmatter trigger
├── agents/                   # optional — 각각 allowedTools/disallowedTools 선언
├── hooks/                    # optional — 각각 DEVBREW_DISABLE_<PLUGIN>=1 opt-out
├── scripts/                  # optional — hook에서 호출하는 shell/python 헬퍼
└── templates/                # optional — 플러그인이 설치하는 정적 파일
```

**Reference 구현** — 본인 플러그인의 형태와 맞는 것을 읽으세요:

- [`plugins/quality-gates/`](plugins/quality-gates/) — **writer + reviewer + hook 파이프라인**. 3-gate `allowedTools`/`disallowedTools` 격리로 Laws 1–2를 embody. `agents/`, `commands/`, `hooks/`, `scripts/`, `skills/`를 shipping.
- [`plugins/project-init/`](plugins/project-init/) — **git-workflow enforcement**. Compounding hook과 branching-strategy 템플릿으로 Law 3를 embody. `commands/`, `hooks/`, `templates/`를 shipping. `agents/`나 `skills/` 없음 — hooks-and-templates 플러그인도 유효한 형태.

**Merge 전:** 위 [Plugin Shape](#plugin-shape) 모든 bullet 만족 + 시작 버전 `0.1.0`.

## Forbidden Patterns

Full 카탈로그와 case study: [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md) §2 (각 원칙의 anti-corollary) + §11.1 (ID 마이그레이션). 리뷰에서 이름으로 cite. 이 리포에서 가장 자주 fire하는 다섯 개:

- **Self-approval** — 같은 턴의 writer/reviewer (Law 2 위반).
- **Polite stop** — 긍정적 리뷰 후 다음 액션으로 가지 않고 요약을 narrate. Approval gate와 구분: gate는 사용자가 redirect 가능, polite stop은 acknowledge만 가능.
- **Trivia ceremony** — 한 문장 diff에 full pipeline 실행 (Anthropic *Best Practices*).
- **Subagent spray** — 선언 없는 fan-out ≥ 5; single-agent를 default로.
- **Unbounded autonomy** — max-iter count, wall-clock budget, repeat 감지, 사용자-override kill switch 없는 루프.
- **Polite handoff** — brainstorming/spec-distill review-approved 후 다음 단계를 narrate만 하고 spec-distill reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트를 띄우지 않음. 게이트는 사용자가 redirect 가능한 approval gate(P17)이자 AP2 봉쇄 장치 — 게이트를 skip한 narrate-only 종료가 polite-stop의 한 종류 (AP2 variant). 대칭으로, 옵션 ①(/compact 후 writing-plans) 선택 시 /compact 노출 후 같은 턴에 writing-plans로 직진하는 cross-compact 조기 진행도 게이트 P17 우회의 대칭 실패로 금지 (AP2 variant, spec-distill v0.11.0 AC19).

**버그가 리뷰를 탈출하면**, 해결책은 잡았어야 할 reviewer persona 파일을 편집하는 것 — 코드만 패치하는 게 아님. 그 commit이 compounding 이벤트 (Law 3).

## Doc Conventions

- **Korean-primary, English-terms-only.** `CLAUDE.md`와 `docs/philosophy/*.md` 등 user-facing 문서는 한국어를 primary로 작성. 영어는 **식별자**(P#, AP#, Law N, §X.Y, plugin 이름), **고유명사**(OMC, gstack, Ouroboros, CE, Anthropic 등), **원문 인용**(verbatim, 어느 방향으로도 gloss 추가 안 함), **기술 용어 중 자연스러운 한국어 대응이 없는 것**(`frontmatter`, `PreCompact`, `subagent`, `hook`, `skill` 등)에 한정. `*.ko.md` 동반 파일 모델은 폐기 (drift 비용 > 이중 노출 가치).
- **`docs/**.md` 파일이 ~300줄 이상이면 상단(제목 + 에피그래프 + 한 줄 정체성 다음, 본문 진입 직전)에 `## 목차` 섹션 필수.** §X.Y depth로 anchor 링크. 섹션 추가/이름 변경/삭제 시 같은 commit에서 TOC도 동기화 (drift 시 cite-by-anchor 깨짐). 짧은 doc(<300줄, git-workflow 가이드 등)은 면제.