# plugin-audit

devbrew 플러그인 하나를 고치지 않고 읽기만 해서 감사한다. 읽기 전용 리뷰어가 고른 축마다(기본 여섯) 빈틈을 찾고,
다른 리뷰어가 그 지적을 하나씩 반박해 보며, codex(다른 모델)가 있으면 같은 대상을 따로 감사한다. 결과는
증거가 붙은 빈틈 목록이고, 심각한 것부터 정렬된다.

## 사용법

```
/plugin-audit <target> [--seed <path>]
```

같은 이름이 설치 환경에 있으면 `/plugin-audit:plugin-audit` 로 부른다. 이 skill 은 사용자만 부른다(`disable-model-invocation: true`).

- `<target>` — 감사할 플러그인 이름 (예: `quality-gates`). scope는 `plugins/<target>/**`로 도출.
- `--seed <path>` — optional. 추가 scope · Open Questions · 후보 단서를 담은 markdown.
  없으면 fresh discovery로 degrade(배너 표시).

`cost_class: high` — dispatch 전에 축을 고르고(「중단」으로 멈출 수 있다) 규모를 한 줄로 본 뒤 진행한다 — 지출 승인을 묻지 않는다.
Kill switch: `DEVBREW_PLUGIN_AUDIT_DISABLE=1`.
본문 전 사전 검사(`scripts/entry_preflight.py`)가 이 스위치를 판정한다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다. 그 스크립트나 `python3` 가 없으면 플랫폼이 호출을 끊는다(헤드리스에서는 출력 없이 끝난다).

**산출 위치** — 감사마다 실행 디렉토리 `.claude/plugin-audit/<date>-<target>[-N]/` 이 생긴다(규모 공시 직후, `scripts/prepare-run-dir.py`). 리포트 `audit.md` · 데이터 `audit-data.json` · 원장
`audit-journal.jsonl` 과 중간 파일이 모두 여기 쌓이고, 안의 `.gitignore`(`*`)로 스스로 git-ignore 된다.
감사가 끝나면 상태 한 줄과 리포트(`audit.md`) 경로를 보고한다 — 데이터 · 원장 경로는 물으면 보인다.
같은 날 같은 대상을 다시 감사하면 `-2` 로 새로 만든다.

`DEVBREW_PLUGIN_AUDIT_DISABLE_WEB=1` — codex 감사 co-reviewer의 웹 검색만 비활성화한다
(AC21). 감사 preamble이 외부 prior-art 근거를 요구해 기본은 ON(`web_search="live"`)이지만,
꺼지면 codex가 리포 근거만으로 감사하고 그 사실을 stderr에 loud하게 남긴다 — crash 없음
(graceful degradation).

`DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX=1` — 대상 플러그인의 자체 테스트 실행(`scripts/run-own-tests.sh`가
`scripts/audit-sandbox.sh create-sandbox`로 만든 일회용 샌드박스에서 돈다)을 끈다. 축③은 테스트를 *읽어*
판정한다(배너). 샌드박스는 저장소 상태만 격리한다 — 프로세스 · 네트워크 · uid 격리는 없다.
이 이름이 정본이다. 옛 이름 `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1` 도 별칭으로 여전히 따른다 —
같은 skip 이 되고, `create-sandbox` 가 stderr 한 줄로 개명을 알린다.

`DEVBREW_PLUGIN_AUDIT_STALENESS_REGISTRY` — staleness census가 참조하는 원장 경로 override.

**환경변수 개명.** 이 플러그인이 노출하는
사용자-표면 이름이 `DEVBREW_<PLUGIN>_<REST>` 하나로 통일됐다:

| 옛 이름 | 새 이름 |
|---|---|
| `DEVBREW_DISABLE_PLUGIN_AUDIT` | `DEVBREW_PLUGIN_AUDIT_DISABLE` |
| `DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX` | `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX` |
| `DEVBREW_DISABLE_PLUGIN_AUDIT_WEB` | `DEVBREW_PLUGIN_AUDIT_DISABLE_WEB` |
| `DEVBREW_STALENESS_REGISTRY` (플러그인 토큰 없던 이름) | `DEVBREW_PLUGIN_AUDIT_STALENESS_REGISTRY` |
| `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` | `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX` |

표의 옛 이름은 마지막 줄을 빼고 더는 읽지 않는다. 마지막 줄의 옛 이름 `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1` 은 별칭으로 따른다 — 값이 정확히 `1` 이면 새 이름과 같이 `create-sandbox` 가 exit 3 으로 멈추고, stderr 한 줄이 개명을 알린다.

리포트의 `[severity]` 배지는 `CRITICAL`/`IMPORTANT`/`SUGGESTION` 셋이다. 옛 4어휘(`HIGH` 등)로 쓰인 과거 리포트는 렌더되지만 정렬에서 맨 뒤로 간다.

## Prerequisites (cross-plugin 의존)

의존마다의 최소 판 · 잰 날짜 · 없을 때 동작은 [`dependencies.md`](dependencies.md) 에 있다. 최소 판은 이 판을 개발 · 검증할 때 깔려 있던 판이고, 진입마다 쓰는 의존의 판을 그 표와 대조해(`scripts/check_deps.py entry`) 없거나 낮으면 멈춘다. 이 플러그인은 gh 를 쓰지 않는다.

- **plugin-dev (official, optional)** — 구조 hard-check tier(E)가 `validate-agent.sh`·
  `validate-hook-schema.sh`·`hook-linter.sh`를 감싼다. 공식 캐시에 있으면 심층 구조 사실을
  얹고, **없으면 loud degrade**(core 구조 검사는 F가 self-contained로 커버). E는 bonus-degradable.

## Principles Instantiated

이 플러그인이 instantiate하는 devbrew 철학.

### Three Laws
- **Law 1 (Clarity Before Code)** — 1차 산출물은 증거로 뒷받침된 갭 목록. 빈 감사는 감사가 아니다
  (고른 축이 모두 죽으면 리포트 없음, AC-4). 갭이 적게 나오는 것은 실패가 아니고 없는 갭을 만드는 것이 실패.
- **Law 2 (Writer ≠ Reviewer, 물리 분리)** — 3 agent(`plugin-auditor`·`audit-refuter`·`smoke-probe`)의
  `tools:` allowlist(`Read, Grep, Glob, WebSearch, WebFetch`)가 쓰기·실행을 fail-closed로 차단.
  프롬프트가 아니라 frontmatter scoping. `check-law2.py` 정적 게이트 + smoke가 런타임 실증.
- **Law 3 (Every Cycle Leaves the System Smarter)** — 리포트는 한 번 읽는 작업 산출물이다
  (`.claude/plugin-audit/<실행 키>/`, 스스로 git-ignore). 이 사이클의 compounding 은 감사가 낳은 수정
  커밋과, 기본으로는 reviewer persona 편집이 맡는다 — 그 버그를 더 잘 잡는 자리가 락 · 스크립트 ·
  skill 이면 그것을 고친다.
- **Law 2 (입력 오염 차단) — `input_slots`** — agent 셋이 frontmatter 에 받는 입력의 `tag`/`var`/`kind`
  를 선언한다. `audit-refuter.findings` 는 금지 종류 `prior_verdict` 이며 `tools/adjudication/check_slots.py`
  의 `EXEMPT_SLOTS` 에 C6 인용과 함께 등재돼 있다(반박이 과업이라 대응물이 없다). 집행은
  `shared/tests/test_agent_input_slots.sh`. **범위 한계**: 이 플러그인의 dispatch 는 `audit-workflow.js`
  의 `agent(prompt, {agentType})` 라 그 락의 `.md` dispatch 코퍼스에 «안 보인다» — 셋 다 축 (a)의
  `unmeasured` 로 세어져 이름이 나오고, 슬롯의 `optional: true` 가 그 미관측을 미전달과 가르는 장치다.
- **Law 3 (Compounding) — 처분 앵커** — codex co-audit 러너(`scripts/run_audit_codex_reviewer.sh`)가
  `**처분**` 앵커로 소비자·fail-정책·공시 채널을 밝히고 `shared/tests/test_runner_disposition.sh` 가
  그 값의 참·거짓(추적된 파일인가, 같은 플러그인인가)까지 잰다.

### KEEP-12 원칙
- **P8 (이식성) — 의존 판** — 의존의 최소 판을 손으로 적지 않는다. `scripts/check_deps.py measure` 가 개발 당시 깔린 판을 재서 `dependencies.md` 에 쓰고, 진입은 그 표와 지금 판을 대조해 없거나 낮으면 멈춘다(`check_deps.py entry`).
- **P11 (모델 다양성)** — codex(다른 모델 패밀리)가 blind 독립 co-audit; union-for-recall +
  independent-refutation(majority-vote consensus 금지 — popularity trap).
- **P21 (untrusted-input)** — 감사 대상 파일 내용은 데이터지 지시가 아니다(C). Secret 기록 금지.
- **P22 (cost 인지)** — `cost_class: high` + 규모 공시 한 줄(fan-out 선언). 범위 고르기 질문은 남는다.
- **훅 kill switch (감사 기준)** — 대상 플러그인의 훅은 자기 이름의 스위치(`DEVBREW_<OWN>_DISABLE` · `DEVBREW_SKIP_HOOKS`)를 따라야 한다. 다른 플러그인 스위치나 하위 스위치만 있으면 gap 이다.
- **정직성 (degraded 배너)** — optional 의존성 부재/검증기 크래시/grounding 미검증은 crash가 아니라
  loud degrade + 리포트 상단 배너(품질 게이트 아님, 정직성 컨트롤).

## 컴포넌트

- `skills/plugin-audit/SKILL.md` — 오케스트레이션(범위 고르기 · 규모 공시 → pre-0 → Workflow → post-1). 진입 단계(사전 검사 · 인자 해석) 포함.
- `agents/{plugin-auditor,audit-refuter,smoke-probe}.md` — 읽기전용 agent 3종.
- `scripts/*` — 결정론 게이트·조립·렌더·검증 + Workflow 스크립트.
