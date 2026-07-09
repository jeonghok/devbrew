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
├── agents/                   # optional — 각각 allowedTools/disallowedTools 선언
├── hooks/                    # optional — 각각 DEVBREW_DISABLE_<PLUGIN>=1 opt-out
├── scripts/                  # optional — hook에서 호출하는 shell/python 헬퍼
└── templates/                # optional — 플러그인이 설치하는 정적 파일
```

**Reference 구현** — 본인 플러그인의 형태와 맞는 것을 읽으세요:

- [`plugins/quality-gates/`](../plugins/quality-gates/) — **writer + reviewer + hook 파이프라인**. 3-gate `allowedTools`/`disallowedTools` 격리로 Laws 1–2를 embody. `agents/`, `commands/`, `hooks/`, `scripts/`, `skills/`를 shipping.
- [`plugins/project-init/`](../plugins/project-init/) — **git-workflow enforcement**. Compounding hook과 branching-strategy 템플릿으로 Law 3를 embody. `commands/`, `hooks/`, `templates/`를 shipping. `agents/`나 `skills/` 없음 — hooks-and-templates 플러그인도 유효한 형태.

**Merge 전:** [Plugin Shape](../CLAUDE.md#plugin-shape)의 모든 bullet 만족 + 시작 버전 `0.1.0`.
