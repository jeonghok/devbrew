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

- **agent frontmatter 에 `model` 키를 두지 않는다.** 리터럴 티어(`opus`/`sonnet`/`haiku`)는 세션의 모델 선택을 덮어쓰고, `inherit` 는 사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을 덮어쓴다 — CLI 2.1.261 실측(2026-09-06, `docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md` §A). 키가 없으면 하니스는 「사용자 설정 → 세션 모델」 순으로 위임한다. 어느 값이든 하니스가 티어를 정하는 것이라 P8(Determinism Economy) 위반이다. reference: `plugins/plugin-audit/agents/*.md`.
  - **dispatch 시점의 `model` 인자는 오케스트레이터의 재량이다.** 세션 모델이 어떤 것이든 상황에 맞는 티어를 고를 수 있다 — 단, 그 agent 의 출력이 **게이트 판정(verdict·findings)이나 측정(readback 류)에 들어가면 인자를 넘기지 않는다.** writer 인 오케스트레이터가 자기 리뷰어의 티어를 고르는 구조는 Law 2 의 취지와 충돌한다. 재량은 프로브·생성기처럼 사람이 읽는 출력만 내는 agent(예: `smoke-probe`, `pr-understanding-builder`)에 한한다. `quality-gates:doc-recritic`(Phase 1.5 재비판, 공유 정본의 copy-of 사본)이 그 예다 —
frontmatter 에 `model` 키가 없고 dispatch 펜스에도 `model:` 인자가 없다. 정본
frontmatter 의 키 부재는 `shared/tests/test_docreview_agents.sh` 가, 이 플러그인의
사본이 그 정본과 바이트 동일함은 `shared/tests/test_copy_of_contract.sh` 가 잰다
(PR4a — 이전에는 `quality-gates:adversarial` 전용 락
`test_adversarial_model_consistency.sh` 가 세 곳을 함께 쟀으나, 그 agent 와 락은
삭제됐다).

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

**Merge 전:** [Plugin Shape](../CLAUDE.md#plugin-shape)의 모든 bullet 만족 + 시작 버전 `0.1.0`.
