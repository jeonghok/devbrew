# 있는 것 먼저 — 검토하고 적는 법

설계문서의 `## 있는 것 검토` 절을 쓸 때 따른다. 길을 정해 주지 않는다 — 아래 재료로 견줘서 고르고 이유를 적으며, 고른 것은 사용자가 승인한다.

1. **기본.** 맞는 있는 것이 있으면 그 위에서 만든다. 만들 것이 없는 일(조사 · 결정만)이면 건너뛰고 이유를 적는다.
2. **대상.** 레포 안의 것, 플랫폼 기본 기능, 남이 만들어 유지하는 플러그인과 skill, 널리 쓰이는 패키지와 도구. 실험 딱지가 붙은 것과 에이전트 조율용 프레임워크도 같은 길을 탄다.
3. **탐색 증거가 먼저다.** 결론보다 앞에 어디를 찾았는지와 찾은 후보를 이름으로 적는다.
   - 찾지 못한 곳(도구가 없거나 꺼져 있던 곳)은 못 찾았다고 적는다.
   - 찾지 않기로 한 곳은 그 일에 대한 구체 이유와 함께 적는다. 「해당 없음」 같은 일반 문구로는 서지 않는다.
   - 「없음」은 찾은 곳과 함께일 때만 선다.
   - 바깥을 찾기 전에 환경 변수 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 을 본다. 값이 정확히 `1` 이면 웹과 네트워크로는 찾지 않고, 그 곳은 「웹이 꺼져 찾지 못함」으로 적는다.
   - 아래 영어 절이 드는 찾을 곳은 예시다. 그 레포의 언어와 도구에 맞는 곳을 찾는다.
   - 찾는 일을 누가 어떻게 띄우는지는 부른 자리의 조사 규약을 따른다. 규약이 없는 자리에서는 모델이 정하고 무엇을 띄웠는지 적는다.
4. **바깥 후보마다 보이는 정보 여섯.** 그 레포가 의존으로 적어 둔 남의 것도 바깥 후보다. 레포 안 것은 해당하는 칸만 적는다. 칸마다 그 자리에서 확인한 출처와 날짜를 붙이고, 확인하지 못한 칸은 「확인 못 함」으로 적는다. 여섯 다 문턱이 아니라 보이는 정보다. 점수는 매기지 않는다.
   - 만든 쪽이 공식으로 내는가
   - 널리 쓰이는가 — 재는 단위와 함께
   - 지금도 유지되는가
   - 안정 단계 — 실험 딱지와 알려진 한계
   - 무엇을 실행하고 무엇에 닿는가, 알려진 보안 문제
   - 라이선스와 그것이 지우는 의무
5. **맞는지.** 후보마다 그 설계의 요구 문장(목표 · 수용 기준)에 비춰 맞는 곳과 안 맞는 곳을 적는다.
6. **렌즈 둘.** 접점은 작고 맡기는 일은 큰 것을 먼저 본다 — 재는 것은 크기가 아니라 접점 대비 맡기는 일의 양이다. 일반적인 부분은 있는 것을 쓰고, 이 일만의 설계가 담긴 부분은 만든다.
7. **쓰는 꼴.** 그대로 들이기 · 감싸기 · 가져와 덜어 내고 얹기 · 가져와 안을 고치기 · 방식만 빌리기 · 직접 만들기. 부분 채택도 쓰는 것으로 세고 어느 꼴인지 적는다. 라이선스가 없거나 복사를 허락하지 않으면 가져오는 꼴은 고를 수 없다.
8. **견줄 축.** 상류 추적 · 검증과 테스트 부담(안 고칠수록 준다) · 라이선스가 지우는 일 · 사용자 환경에 생기는 의존 · 요구에 맞추기.
9. **직접 만들기의 이유.** 그 후보에 대해 구체로 적을 때만 선다. 예시는 어느 요구 문장에 안 맞는가, 누구 환경에 어떤 의존이 생기고 없으면 무엇이 깨지는가, 라이선스, 안전이다. 상시 규칙이나 앞 결정을 인용하는 것만으로는 서지 않는다. 직접 만들면 탐색이 찾은 빈 곳을 적는다.
10. **승인.** 맞는 후보가 있으면 그 위에서 짓는 안을 추천 안으로 첫 자리에 둔다.
    - 이미 쓰는 것(플랫폼 기본 기능 · 그 레포가 의존으로 적어 둔 것)은 이름으로 모아 한 번에 승인받는다.
    - 새로 들이는 것은 하나씩 승인받는다.
    - 직접 만들기도 승인받는다.
    - 승인은 설계 대화에서 받고, 받은 승인은 이 절의 결론에 고른 것마다 날짜와 사용자가 한 말로 적는다. 대화에서 승인받지 못한 것은 「승인 전」으로 적는다 — 문서를 승인하는 자리는 이 승인을 대신하지 않는다. 「승인 전」이 남으면 계획으로 넘기기 전에 사용자에게 묻는다.
    - 아래 영어 절의 판정표가 권하는 행동은 승인 전에는 제안이다.
11. **수용 기준.** 고른 것마다 수용 기준을 적는다 — 실제로 쓴다, 들였으면 그 레포가 의존을 적는 자리에 적는다, 가져왔으면 라이선스가 지우는 고지를 싣는다.
12. **고침.** 이미 만든 장치를 고치는 설계면 있는 것으로 옮길 수 있는지도 함께 본다.

아래 영어 절은 찾고 견주는 흐름이다. 이 절과 다르면 이 절이 앞선다.

---

# /search-first — Research Before You Code

Systematizes the "search for existing solutions before implementing" workflow.

## Trigger

Use this skill when:
- Starting a new feature that likely has existing solutions
- Adding a dependency or integration
- The user asks "add X functionality" and you're about to write code
- Before creating a new utility, helper, or abstraction

## Workflow

```
┌─────────────────────────────────────────────┐
│  0. TOOL AVAILABILITY PREFLIGHT             │
│     Check search channels before relying on │
│     them; report skipped channels honestly   │
├─────────────────────────────────────────────┤
│  1. NEED ANALYSIS                           │
│     Define what functionality is needed      │
│     Identify language/framework constraints  │
├─────────────────────────────────────────────┤
│  2. PARALLEL SEARCH (researcher agent)      │
│     ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│     │  npm /   │ │  MCP /   │ │  GitHub / │  │
│     │  PyPI    │ │  Skills  │ │  Web      │  │
│     └──────────┘ └──────────┘ └──────────┘  │
├─────────────────────────────────────────────┤
│  3. EVALUATE                                │
│     Show candidate facts (functionality,    │
│     maint, community, docs, license, deps)  │
├─────────────────────────────────────────────┤
│  4. DECIDE                                  │
│     ┌─────────┐  ┌──────────┐  ┌─────────┐  │
│     │  Adopt  │  │  Extend  │  │  Build   │  │
│     │ as-is   │  │  /Wrap   │  │  Custom  │  │
│     └─────────┘  └──────────┘  └─────────┘  │
└─────────────────────────────────────────────┘
```

## Decision Matrix

| Signal | Action |
|--------|--------|
| Exact match, well-maintained, MIT/Apache | **Adopt** — install and use directly |
| Partial match, good foundation | **Extend** — install + write thin wrapper |
| Multiple weak matches | **Compose** — combine 2-3 small packages |
| Nothing suitable found | **Build** — write custom, but informed by research |

## How to Use

### Step 0: Tool Availability Preflight

This is agent guidance, not an executable setup script. Check only the channels
that are relevant to the task and project in front of you.

| Channel | Check | If missing |
|---------|-------|------------|
| Repository search | `rg --files` and targeted `rg` queries | State that only visible files were inspected |
| Package registry | `npm --version`, `python -I -m pip --version`, or project package manager | Use web/docs search and avoid claiming registry coverage |
| GitHub CLI | `gh auth status` | Use public web or local git history only |
| MCP/docs tools | Available tool list | Fall back to official docs/web search |
| Skills directory | `ls ~/.claude/skills ~/.codex/skills` where applicable | Say no local skill catalog was available |

### Quick Mode (inline)

Before writing a utility or adding functionality, mentally run through:

0. Does this already exist in the repo? → `rg` through relevant modules/tests first
1. Is this a common problem? → Search npm/PyPI
2. Is there an MCP for this? → Check the available tool list and search
3. Is there a skill for this? → Check `~/.claude/skills/`
4. Is there a GitHub implementation/template? → Run GitHub code search for maintained OSS before writing net-new code

## Anti-Patterns

- **Jumping to code**: Writing a utility without checking if one exists
- **Ignoring MCP**: Not checking if an MCP server already provides the capability
- **Silent skipping**: Reporting "nothing found" when a search channel was unavailable
- **Over-customizing**: Wrapping a library so heavily it loses its benefits
- **Dependency bloat**: Installing a massive package for one small feature
