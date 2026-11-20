# CLAUDE.md

> **Specify before you code. Review before you ship. Compound before you forget.**
> *코드보다 명세 먼저. 배포보다 리뷰 먼저. 잊기 전에 축적.*
>
> *병목은 모델이 아니다. 스펙, 리뷰, 메모리다. devbrew의 역할은 사용자가 의식적으로 기억하지 않아도 이 세 가지가 자동으로 지켜지도록 만드는 것이다.*

devbrew는 Claude Code를 위한 플러그인 마켓플레이스입니다. `plugins/*` 하위의 모든 플러그인은 아래 원칙을 상속합니다. 전체 철학(구조 메커니즘 KEEP-12 + 코드 지도)은 [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md).

## Git Workflow

GitHub Flow. `main`에서 분기, PR로 merge back. 상세는 `docs/git-workflow/`.

- Branch: `main`에서 `feature/*` · `fix/*`(문서만이면 `docs/*`, 설정 · 잡일이면 `chore/*`). kebab-case, 2–4 단어.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- 언어: 커밋 메시지의 설명과 PR 본문은 한국어로 쓴다. `type`·`scope` 는 영어다(예: `fix(qg): 범위 경고를 쉬운 말로`). 다른 레포는 그 레포의 규칙을 따른다.
- PR: merge commit, `docs/git-workflow/pr-process.md` 참고
- project-init 훅이 브랜치 이름 · 커밋 꼴을 확인해 알린다(막지 않는다)

## The Three Laws

이 세 법칙이 모든 플러그인을 지배합니다. **충돌 시 Law N이 Law N+1을 override** — 명확성 먼저, 독립성 둘째, compounding 셋째.

**Law 1 — Clarity Before Code.** 명세가 모호한 상태에서는 구현이 진행되지 않습니다. 코드를 shipping하는 모든 플러그인은 실제 거절 메커니즘을 가져야 합니다 — 최소한 필수 섹션(Context/Why, Goals, Non-goals, Constraints, Acceptance Criteria, Files to Modify, Verification Plan, Rejected Alternatives, Metadata)을 silent하게 skip할 수 없어야 합니다. 지금 막는 자리: 인터뷰 brief 는 `check_brief.py` 가 구조로 막는다. 설계문서 리뷰어가 필수 섹션 누락을 승인을 막는 지적으로 낸다 — 기계 게이트는 아니다. 기본은 설계 → 계획 → 구현이다. 중간 크기 일은 이유를 밝히고 가벼운 꼴(PR 본문의 계획 · 짧은 brief)을 고를 수 있다. 가벼운 꼴도 필수 섹션이 다루는 것을 짧게 덮고, 다루지 않는 섹션은 「해당 없음 — 이유」로 적는다. Adversarial self-review는 구조적 baseline 위에 강력 권장, 수치 스코어링은 허용되지만 권장하지 않음 (철학 P2). *Trivia escape:* 한 문장으로 설명 가능한 trivia diff (typo, rename, 주석-only, formatting — **파일 수와 무관하게**)는 게이트 우회. 정의 및 자격 규정은 philosophy P12 참조.

**Law 2 — Writer and Reviewer Must Never Share a Pass.** 코드를 쓴 턴은 그 코드를 승인할 수 없음. 분리는 프롬프트가 아니라 물리적: `tools:` allowlist frontmatter로 리뷰어가 `Write`/`Edit`을 literally 갖지 못하게 만들기. 쓰기 권한이 있는 리뷰어는 리뷰어가 아님. 검증은 load-bearing 인프라, 나중 생각이 아님.

**Law 3 — Every Cycle Must Leave the System Smarter.** Compounding은 선택적 wrap-up이 아니라 discoverability check가 붙은 이름 붙은 단계. 사이클이 learning을 생산하면 하니스는 그것을 파일로 capture하고 다음 세션이 실제로 찾을 것임을 확인 — 「다음 세션」은 메모리 없는 레포의 세션도 뜻한다: 교훈은 메모리가 아니라 그 동작을 내는 skill · reference · 스크립트 · 락을 고쳐 남긴다(철학 Law 3). 어떤 미래 agent도 읽지 않는 파일에 기록하는 것은 theater.

- **기본값과 판단.** 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓰고 정석 흐름의 의도는 지킨다. 결정론은 보안 · 정확성 게이트에만 — 사람이 정하는 자리를 지키는 관문이 그 게이트다(철학 P8).
- **레포 전용 값 금지.** 경로 · 테스트 명령 · 브랜치 · 모델 같은 값은 도출하거나 레포마다 정하게 한다(철학 P8).
- **상류 · 하류 연계.** 설계마다 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 표면과 이음매 담당을 보인다(철학 P23).
- **진입점에서 따라 내려가기.** 산출물 · 상태가 얽히면 객체 · 링크 · 속성 · 주인을 적어 진입점에서 따라가게 한다(철학 P5).
- **있는 것 먼저.** 설계를 타는 일에서 기본은 맞는 있는 것(레포 안 · 플랫폼 기본 기능 · 남이 유지하는 것) 위에서 만든다 — 찾아본 후보를 먼저 적고, 직접 만들려면 그 후보에 대한 구체 이유를 대고 사용자 승인을 받는다. 외부 것은 후보와 차이를 보이고 사용자 승인 뒤 쓴다. 작은 변경은 지금처럼 그냥 고친다(철학 P8).

## Plugin Shape

`plugins/*`의 모든 플러그인은 [canonical 디렉토리 구조](docs/plugin-authoring.md)를 따르고 아래를 모두 만족해야 합니다.

### 메타데이터 & 버전 관리

- **`plugin.json` — 필수 키와 판 올림.** `plugin.json` 의 필수 키는 `name` 하나다 — `version` · `description` · `author` 를 빼면 `claude plugin validate` 가 경고를 낸다. `version` 을 적은 플러그인은 설치본이 바뀌는 PR 에서 판을 올린다(major = breaking, minor = 새 surface, patch = fix) — 설치본은 판 문자열로 갱신을 알아채서, 올리지 않으면 사용자는 옛 사본에 머문다. 올림 단위는 기본 브랜치에 머지되는 PR 하나다 — PR 안에서 커밋마다 올리지 않는다. 플러그인 X 를 올리는 때는 그 PR 이 ① `plugins/<X>/` 아래 파일(그 폴더 바로 아래의 `plugins/<X>/tests/` 폴더 · `CHANGELOG.md` · `README.md` 는 제외)을 바꾸거나 ② X 가 심볼릭 링크로 싣는 `shared/` 파일을 바꿀 때다. 그 밖의 변경(`shared/tests/` · `tools/` · `docs/` 처럼 설치본에 실리지 않는 것)으로는 올리지 않는다. ① · ② 에 걸려도 동작에 닿지 않는 변경(주석 · 오탈자)만 있는 PR 은 이유를 PR 본문에 적고 올리지 않을 수 있다.
- **v1.0.0 이상이면 `CHANGELOG.md`.** `## [version] — YYYY-MM-DD` with Added/Changed/Deprecated/Removed/Fixed/Security. 제거 전 one-minor deprecation window. 사용자가 명시 결정한 재건은 deprecation 창 없이 제거하고 CHANGELOG Removed 에 적는다. 또 하나의 예외 — 호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다. 이 예외는 제3자 설치가 확인되면(외부 이슈 · 설치 보고 · 마켓플레이스 공개 등록) 소멸한다. kill switch 이름은 이 예외에 들지 않는다 — 은퇴시키려면 CHANGELOG `Removed` 와 README 에 공시가 필수다.
- **`README.md`에 "Principles Instantiated"** — 이 플러그인이 embody하는 철학 법칙/원칙을 한 줄씩. Law 3의 compounding substrate: 미래 검색이 모든 instantiation을 찾음.

### 컴포넌트 격리

- **Scoped agents — default-everything 금지.** 모든 agent는 `tools:` allowlist를 선언한다 (fail-closed — 열거하지 않은 것은 전부 차단). **denylist(`disallowedTools`) 단독 금지**: 공간에 대해 fail-open(열거를 잊은 도구는 허용)이고 **denylist는 시간에 대해 fail-open**이다 — 내일 추가될 도구는 오늘 열거할 수 없다. 역할 프롬프트는 첫머리에 맡는 일을 밝힌다. 맡지 않는 일(쓰기 · 고치기 등)은 `tools:` allowlist 가 막고, 프롬프트가 밝힐 때는 같은 첫머리에 둔다. 특정 영어 공식은 강제하지 않는다. 쓰기 권한이 있는 리뷰어는 Law 2 위반. **agent frontmatter 에서 도구를 다루는 실재 필드는 `tools`(allowlist)와 `disallowedTools`(denylist) 둘뿐이다** — 이와 헷갈려 command/skill 계층의 `allowed-tools`(kebab, 실재 키)를 agent에 camelCase로 옮겨 적거나 skill 의 `disallowed-tools`(kebab)를 agent에 그대로 적으면 존재하지 않는 필드가 되어 조용히 무시된다.
- **`allowed-tools` 는 제한이 아니다.** command 에서는 쓰지 않는다. skill 에서는 진입 사전 검사 한 줄의 사전 허용으로만 쓰고 다른 도구를 열거하지 않는다. 목록 밖 도구도 실행되고 스코프 표기(`Bash(<pattern>:*)`)도 범위 밖 명령을 막지 못한다 — **이 키는 제한이 아니다.** 바로 위 agent의 `tools:`와는 다르다 — 그것은 fail-closed이고 Law 2의 집행 지점이다. 막지 않는 것을 막는다고 믿게 만드는 선언은 없는 것보다 나쁘다. skill 이 도는 동안 도구를 실제로 빼는 실재 키는 `disallowed-tools`(kebab)다 — 그 skill 을 부른 턴에만 걸리고 사용자의 다음 메시지에서 풀린다. denylist 라 빠뜨린 도구와 내일 생길 도구는 막지 못하므로 Law 2 의 집행 지점이 아니다 — Law 2 의 분리는 지금처럼 agent 의 `tools:` allowlist 로만 한다. agent 에서 도구를 빼는 키는 camelCase `disallowedTools` 다.
- **최소 버전이 선언된 의존성.** 플러그인이 기대는 도구 · 다른 플러그인은 그 플러그인의 `dependencies.md` 표(이름 · 최소 판 · 강도 · 없을 때)에 적고, 판 칸은 `check_deps.py measure` 가 잰다(개발 · 검증할 때 깔려 있던 판 — 손으로 고치지 않는다. 판을 잴 길이 없는 외부 플러그인 행만 판 칸 둘에 `—` 를 적는다). `other-plugin:agent-name`을 dispatch하는 플러그인은 README prerequisites에도 `other-plugin`을 리스트. Silent coupling은 버그.
- **모든 skill 은 frontmatter `metadata` 아래에 `cost_class` 를 선언한다** (`low`|`medium`|`high`|`variable`). `high` 는 크게 쓰기 전에 규모(띄울 agent 수 · 라운드 · 상한이 없으면 없다는 사실)를 한 줄로 알리고 진행한다. 어느 클래스의 skill 도 지출 승인을 묻지 않는다 — 상한 · 압축은 공시하고, 사용자가 상한을 여는 질문은 지출 승인이 아니다. 대상 · 모드 · 취소처럼 일의 범위를 고르는 질문도 지출 승인이 아니라 그대로 묻는다. 클래스보다 비싸게 도는 skill 은 버그다.
- **subagent 발견은 처분을 밝힌다.** 모든 dispatch 자리는
  `**처분** — consumer=<같은 플러그인의 .py|.js 경로|orchestrator|human> · fail-<open|closed> · disclosure=<리터럴>`
  한 줄을 갖는다. `consumer=` 가 경로면 그 경로는 추적되는 파일로 **실재해야** 하고 **앵커가 사는
  파일과 같은 플러그인**이어야 한다(설치본에서 다른 플러그인의 스크립트는 도달 불가다).
  `disclosure=` 는 `consumer=` 가 `.py` 경로일 때만 생략한다 — 그때는 그 파일이 회계 모듈을
  실제로 import 하는지가 대신 검사된다. 그 밖의 소비자에서는 **필수**다. 판정기가 항목을 버리면
  센다 — 셀 수 없으면 「셀 수 없음」을 낸다(침묵과 0 은 다른 사실이다). 회계는
  `shared/adjudication/` 이 한다.
  **흡수(dedup)와 강제(coercion)는 소실이 아니다** — 계수하되 그 자체로 degrade 는 아니다.
  다만 **강제가 게이트 판정을 바꾸면**(`gate=True`) degrade 다.
  **공시와 차단은 다른 술어다**: 무엇이 degrade 든 언제나 드러내되, 막는 것은 **항목이
  소실됐거나 셀 수 없거나 그 축의 주(主) 판정자가 죽었을 때**다 — 모델 다양성 손실은 공시하고 막지 않는다.
  미판정 항목의 방향은 다음 소비자가 정한다: 기계면 제외, 사람이면 라벨을 붙여 보여준다.
  집행은 `shared/tests/test_dispatch_disposition.sh`(축 A①②③④·B·C). **축 C 는 채널 «이름»의
  실재까지만 재고 그 채널이 실제로 읽히는지는 못 잰다.**

### 런타임 상태 & 훅

- **JSON이 아니라 마크다운 state.** 상태 자리는 성격으로 가른다 — ① 세션과 리뷰어가 읽고 쓰는 런타임 state 는 `.claude/<plugin>/` 하위에 산다(git-ignored) ② 플러그인이 스스로 만드는 일회용 작업 사본(git worktree)은 작업 트리 꼭대기의 `.claude/worktrees/` 에 그 플러그인이 드러나는 이름으로 만들고 자기가 만든 것만 지운다(예외 — 지휘자의 스위트 대조 사본은 지휘 기계 상태 폴더 아래에 둔다) ③ 스크립트만 쓰고 잃어도 다시 만들 수 있는 캐시는 Claude Code 의 플러그인 데이터 폴더(`${CLAUDE_PLUGIN_DATA}`)에 프로젝트마다 갈리게 두고, 쓰지 못하면 알리고 캐시 없이 돈다 ④ 인터뷰처럼 세션을 넘어 남아야 하는 기록은 docs 의 추적 파일에 두고 산출물과 함께 커밋한다. ① 의 수명은 넷이다 — 세션 단위(`.claude/<plugin>/<session-id>/<file>` — 다음 시작 때 지우고 TTL GC 가 남은 것을 치운다. 지금은 qg 다) · 문서 단위 리뷰 원장(그 문서가 사라질 때 정리) · 로드맵 단위 지휘 기계 상태(`machine.md`) · 실행 단위 산출(plugin-audit 실행 폴더 — 지우지 않는다). spec-distill 의 상태 루트는 worktree 에서 불러도 메인 레포 쪽이고 처음 만들 때 자기 `.gitignore` 를 둔다. spec-distill 펜스의 상태 폴더 쓰기는 writer(`nofollow_write`)를 거쳐 마지막 경로 성분의 링크를 따라가지 않는다. 예외 하나 — plugin-audit 실행 폴더는 넘겨받은 `--repo-root`(기본 cwd) 아래에 링크 검사 없이 만든다. **Secret 기록 금지** — placeholder 참조 사용 (철학 P21).
- **끄는 길은 공식 장치 먼저.** 플러그인을 통째로 끄는 길은 Claude Code 의 플러그인 끄기다(`/plugin` · `claude plugin disable` · 설정의 `enabledPlugins`) — 통째 끄기용 환경변수를 두지 않는다. 끄는 환경변수(`DEVBREW_<PLUGIN>_DISABLE_<기능>=1`)는 skill 이 묻지 않고 하는 일 가운데 사용자가 막고 싶을 수 있는데 공식 장치로 막을 길이 없는 것(내용을 바깥으로 보냄 · 남의 코드를 실행 · 바깥에 글을 올림)에만 둔다. 끄기 변수마다 읽는 코드가 있다 — skill 문장으로만 꺼지는 스위치는 두지 않는다. 켜진 끄기 변수는 진입 사전 검사가 skill 첫머리에 한 줄로 보인다. 끄기 변수는 보안 컨트롤이다 — 읽는 코드는 그 값을 무시할 수 없고, 은퇴는 한 판 동안 옛 이름을 그대로 듣고 알린 뒤에 하며 CHANGELOG `Removed` 와 README 에 공시한다.
- **훅 공존.** 같은 event 내 훅은 교환 가능해야 함. `SessionStart` 훅은 read-only 조언자, 절대 mutate 안 함. 각 훅은 README의 Hooks Installed(한국어 README 는 「설치된 Hook」) 절에 "왜 skill이 아닌가"의 한 줄 justification과 함께 문서화.
- **Loud logging을 동반한 graceful degradation.** 누락된 optional 의존성은 capability를 downgrade하고 알린다, crash하지 않음 — 사용자가 출력에서 fallback이 돌았음을 알 수 있어야 함. 필수 의존(`dependencies.md` 강도 멈춤)은 이유와 설치 방법을 보이고 멈춘다. 의존마다 없을 때의 동작은 그 표의 「없을 때」 칸이 적는다. 훅은 사람에게 말할 자리가 없어 바닥 미만이면 건너뛰고, 그 사실을 README Prerequisites 가 공시한다.

### 네이밍 & 보안

- **Progressive disclosure.** 사용자가 부르는 진입 skill 은 짧은 kebab 두 단어 이상(일반어 단독 금지 — `spec-review`, `plugin-audit`)이고 디렉토리 이름 = `name` 이다. 모델만 부르는 내부 skill(`user-invocable: false`)은 동명사(`reviewing-brief`). 기계가 내는 안내는 `/plugin:name` 완전명. 새 command 파일은 만들지 않는다 — 사전 단계는 진입 skill 의 `!` 로. 모호한 이름 (`helper`, `utils`, `"I can help you..."`) 없음. 집행: `shared/tests/test_invocation_surface.sh`.
- **Persona 파일은 보안-민감 코드.** Reviewer persona를 약화(규칙 제거, 임계치 완화)하는 PR은 보안 리뷰 대상. test-suite 편집과 같은 신중함으로 persona 편집을 treat.

## Building a New Plugin

새 플러그인 스캐폴딩(Starter 트리 + reference 구현 워크스루)은 [docs/plugin-authoring.md](docs/plugin-authoring.md) 참조. 새 플러그인을 설계할 때 기본은 `plugin-dev:plugin-structure` 로 컴포넌트 타입 · `plugin.json` 스키마를 실재하는 surface 위에서 확정하는 것이다 — 다른 길이 맞으면 이유를 적는다. 단계별 문법 레퍼런스 매핑도 같은 문서에.

## Forbidden Patterns

원칙과 그 anti-corollary: [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md)의 Structural Mechanisms · Anti-Pattern Anchors 절. 리뷰에서 이름으로 cite. 자주 fire하는 것들:

- **Self-approval** — 같은 턴의 writer/reviewer (Law 2 위반).
- **Polite stop** — 긍정적 리뷰 후 다음 액션으로 가지 않고 요약을 narrate. Approval gate와 구분: gate는 사용자가 redirect 가능, polite stop은 acknowledge만 가능.
- **Trivia ceremony** — 한 문장 diff에 full pipeline 실행 (Anthropic *Best Practices*).
- **Subagent spray** — 선언 없는 fan-out. 비용과 fan-out을 선언하지 않고 대규모로 퍼뜨리는 것이 anti-pattern이다 (규모 자체가 아니라 선언 없음이). **Agent(subagent) 호출 자체는 이 리포에서 상시 허용** — 매번 승인을 묻지 않는다. 금지되는 것은 선언 없는 대규모 fan-out 뿐이다. Workflow 와 deep-research 는 범위 밖 — 여전히 명시 요청이 필요하다.
- **Self-narrating artifact** — 모델이 읽고 행동하는 산출물(생성 템플릿, 룰 파일, 프롬프트)이 자기 출처("무엇이 이 파일을 만들었다")·배경·존재 정당화를 담는 것. 토큰 낭비이자 의미 왜곡 — 읽는 쪽의 초점이 "무엇을 해야 하나"에서 "이게 왜 있나"로 옮겨가고, 정당화 문장이 지시로 오독된다. 근거와 이력은 CHANGELOG·PR·리뷰에 남기고 산출물에는 행동에 필요한 것만 둔다.
- **Unbounded autonomy** — max-iter count, repeat 감지, 사용자-override kill switch 없는 루프.
- **Polite handoff** — 리뷰 승인 뒤 proceed 게이트 없이 다음 단계를 narrate만 하는 것, 게이트가 정한 멈춤을 건너뛰고 직진하는 것. 둘 다 게이트(P17)를 건너뛴 polite stop(AP2 variant). 게이트 계약 · 예외의 정본은 `plugins/spec-distill/references/proceed-gate.md`.
- **Sealed decision** — 앞 단계의 확정이 하류에서 반증됐는데 피벗 경로가 없는 것 (철학 P23 의 anti-corollary). 재발견 금지는 반증 금지가 아니다 — 근거 있는 재결정은 사용자 동의를 받아 허용하고, 임의 변경만 금지한다.

**버그가 리뷰를 탈출하면** 기본 해결책은 잡았어야 할 reviewer persona 파일을 편집하는 것이다 — 코드만 패치하지 않는다. 그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고치고 이유를 적는다. 그 commit 이 compounding 이벤트다(Law 3).

## Doc Conventions

- **Korean-primary, English-terms-only.** `CLAUDE.md`와 `docs/philosophy/*.md` 등 user-facing 문서는 한국어를 primary로 작성. 영어는 **식별자**(P#, AP#, Law N, §X.Y, plugin 이름), **고유명사**(OMC, gstack, Ouroboros, CE, Anthropic 등), **원문 인용**(verbatim, 어느 방향으로도 gloss 추가 안 함), **기술 용어 중 자연스러운 한국어 대응이 없는 것**(`frontmatter`, `PreCompact`, `subagent`, `hook`, `skill` 등)에 한정.
- **범위.** 위의 영어 범위와 「원문 인용에 풀이를 붙이지 않는다」는 **레포 문서**의 규칙이다. 플러그인이 실행 중 사람에게 내는 글은 `shared/style/plain-language.md` 를 따른다.
- **`docs/**.md` 의 `## 목차` — 기본은 둔다.** 앵커로 인용되는 오래 사는 문서(가이드 · 철학 · 설계문서)가 ~300줄을 넘으면 상단(제목 + 에피그래프 + 한 줄 정체성 다음, 본문 진입 직전)에 `## 목차` 섹션을 두고 §X.Y depth로 anchor 링크한다. 섹션 추가/이름 변경/삭제 시 같은 commit에서 TOC도 동기화 (drift 시 cite-by-anchor 깨짐). 한 번 쓰고 닫는 계획 · 기록은 모델이 판단한다. 짧은 doc(<300줄)은 면제.
