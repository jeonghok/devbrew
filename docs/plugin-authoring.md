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
├── hooks/                    # optional — 각각 DEVBREW_DISABLE_<PLUGIN>=1 opt-out
├── scripts/                  # optional — hook에서 호출하는 shell/python 헬퍼
├── templates/                # optional — 플러그인이 설치하는 정적 파일
└── tests/                    # optional — 테스트는 여기 하나로. hooks/tests·scripts/tests 신설 금지
```

- **agent `model:`은 `inherit`.** 리터럴 티어(`opus`/`sonnet`/`haiku`)를 박으면 하니스가 사용자의 모델 선택을 덮어쓴다 — 세션이 더 강한 모델을 쓸 때는 조용한 하향이고, 더 약한 모델을 쓸 때는 동의 없는 비용 증가다. 어느 방향이든 P8(Determinism Economy) 위반이다. reference: `plugins/plugin-audit/agents/*.md`.

**Reference 구현** — 본인 플러그인의 형태와 맞는 것을 읽으세요:

- [`plugins/quality-gates/`](../plugins/quality-gates/) — **writer + reviewer + hook 파이프라인**. 3-gate `tools:` allowlist 격리로 Laws 1–2를 embody. `agents/`, `commands/`, `hooks/`, `scripts/`, `skills/`를 shipping.
- [`plugins/project-init/`](../plugins/project-init/) — **git-workflow enforcement**. Compounding hook과 branching-strategy 템플릿으로 Law 3를 embody. `commands/`, `hooks/`, `templates/`를 shipping. `agents/`나 `skills/` 없음 — hooks-and-templates 플러그인도 유효한 형태.

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
