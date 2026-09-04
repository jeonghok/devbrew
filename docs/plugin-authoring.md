# 플러그인 저술 가이드

devbrew의 새 플러그인 스캐폴딩 워크스루 — `CLAUDE.md`의 `## Building a New Plugin`에서 참조.

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
├── agents/                   # optional — 각각 tools: allowlist 선언 (fail-closed)
├── hooks/                    # optional — 각각 DEVBREW_<PLUGIN>_DISABLE=1 opt-out
├── scripts/                  # optional — hook에서 호출하는 shell/python 헬퍼
├── templates/                # optional — 플러그인이 설치하는 정적 파일
└── tests/                    # optional — 테스트는 여기 하나로. hooks/tests·scripts/tests 신설 금지
```

- **agent `model:`은 `inherit`.** 리터럴 티어(`opus`/`sonnet`/`haiku`)를 박으면 하니스가 사용자의 모델 선택을 덮어쓴다 — 세션이 더 강한 모델을 쓸 때는 조용한 하향이고, 더 약한 모델을 쓸 때는 동의 없는 비용 증가다. 어느 방향이든 P8(Determinism Economy) 위반이다. reference: `plugins/plugin-audit/agents/*.md`.
  - **dispatch 시점의 `model` 인자는 오케스트레이터의 재량이다.** 세션 모델이 어떤 것이든 상황에 맞는 티어를 고를 수 있다 — 단, 그 agent 의 출력이 **게이트 판정(verdict·findings)이나 측정(readback 류)에 들어가면 인자를 넘기지 않는다.** writer 인 오케스트레이터가 자기 리뷰어의 티어를 고르는 구조는 Law 2 의 취지와 충돌한다. 재량은 프로브·생성기처럼 사람이 읽는 출력만 내는 agent(예: `smoke-probe`, `transcript-reader`, `pr-understanding-builder`)에 한한다. adversarial 은 `plugins/quality-gates/tests/test_adversarial_model_consistency.sh` 가 dispatch 자리 근처의 `model=` 부재를 집행한다.

**Reference 구현** — 본인 플러그인의 형태와 맞는 것을 읽으세요:

- [`plugins/quality-gates/`](../plugins/quality-gates/) — **writer + reviewer + hook 파이프라인**. 2-gate `tools:` allowlist 격리로 Laws 1–2를 embody. `agents/`, `commands/`, `hooks/`, `scripts/`, `skills/`를 shipping.
- [`plugins/project-init/`](../plugins/project-init/) — **git-workflow enforcement**. Compounding hook과 branching-strategy 템플릿으로 Law 3를 embody. `commands/`, `hooks/`, `templates/`를 shipping. `agents/`나 `skills/` 없음 — hooks-and-templates 플러그인도 유효한 형태.

> **새 agent 를 dispatch 하는 자리를 만들면 처분 앵커 한 줄이 함께 온다** —
> `**처분** — consumer=<같은 플러그인의 .py|.js 경로|orchestrator|human> · fail-<open|closed> · disclosure=<리터럴>`.
> 그 subagent 가 낸 발견을 누가 어떻게 처분하는지, 그리고 버린 것이 어디에 드러나는지를
> 밝힌다. `consumer=` 가 경로면 그 경로는 추적되는 파일로 실재해야 하고 앵커가 사는 파일과
> 같은 플러그인이어야 한다. `disclosure=` 는 `consumer=` 가 `.py` 경로일 때만 생략한다 —
> 그 밖의 소비자에서 빠뜨리면 락의 축 A④ 가 RED 다.
> `shared/tests/test_dispatch_disposition.sh` 가 dispatch 와 앵커를 1:1 로 묶고, 그 락은
> `# guards: plugins/**` 를 선언하므로 `plugins/` 를 건드리는 변경의 Runtime gate 테스트
> 스코프에 들어온다. 회계 모듈은 `shared/adjudication/`.

**단계별 문법 레퍼런스** — `plugin-dev`(claude-plugins-official)가 Claude Code 컴포넌트 문법을 skill로 shipping한다. 해당 단계에 진입할 때만 로드 — 선행 일괄 로드는 progressive disclosure 위반:

- **설계 (brainstorming)** — `plugin-dev:plugin-structure`. 컴포넌트 타입, `plugin.json` 스키마, 디렉토리 레이아웃. 이 단계에서 필요한 유일한 것.
- **구현** — shipping하는 surface별로 `plugin-dev:skill-development` / `command-development` / `agent-development` / `hook-development` / `mcp-integration`.
- **검증** — `/plugin-audit` (읽기전용 6축 감사 → 적대적 반박 → codex 병렬 co-audit).

`plugin-dev`가 주는 것은 **문법**이다. devbrew **정책**(위 트리의 주석 + [Plugin Shape](../CLAUDE.md#plugin-shape))은 이 문서가 유일한 소스이며 충돌 시 우선한다. `plugin-dev`의 `/create-plugin`은 자체 Discovery/Design phase를 갖는 end-to-end 워크플로우 — devbrew에서는 설계를 brainstorming과 spec-distill이 담당하므로 skill을 지식으로만 쓴다.

**output style 컴포넌트** — devbrew 첫 사례는 [`plugins/agent-transparency/`](../plugins/agent-transparency/). `output-styles/<name>.md` 한 파일이며 frontmatter 네 필드가 전부다:

- `name` · `description` — `description` 은 `plugin.json` 과 같은 문구로 두는 것이 관행(중복 서술이 갈리는 것을 막는다).
- **`keep-coding-instructions: true` — 빠뜨리면 안 된다.** 기본값이 `false`라 생략하면 Claude Code 내장 소프트웨어 엔지니어링 지침이 **통째로 사라진다**. 그것이 devbrew 가 금지하는 능력 억제다.
- `force-for-plugin: true` — 설치하면 자동 적용되고 사용자의 `outputStyle` 설정을 **덮어쓴다**. 대가: 스타일만 따로 끄는 길이 없고(플러그인 `settings.json`은 `agent`·`subagentStatusLine` 키만 지원), 여러 플러그인이 켜면 **먼저 로드된 것이 이긴다**. README 맨 앞에 경고를 둘 것.

**output style 은 subagent 에 닿지 않는다.** 메인 대화의 시스템 프롬프트만 바꾸므로, subagent 나 `context: fork` skill 이 따라야 할 규칙은 그쪽 파일에 **따로** 두고 파리티 테스트로 묶어야 한다(사본이 셋이 되면 파리티가 못 보는 자리가 생긴다).

**Merge 전:** [Plugin Shape](../CLAUDE.md#plugin-shape)의 모든 bullet 만족 + 시작 버전 `0.1.0`.
