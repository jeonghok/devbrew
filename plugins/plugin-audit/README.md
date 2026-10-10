# plugin-audit

devbrew 플러그인 하나를 고치지 않고 읽기만 해서 감사한다. 읽기 전용 리뷰어 여섯이 축마다 빈틈을 찾고,
다른 리뷰어가 그 지적을 하나씩 반박해 보며, codex(다른 모델)가 있으면 같은 대상을 따로 감사한다. 결과는
증거가 붙은 빈틈 목록이고, 심각한 것부터 정렬된다.

## 사용법

```
/plugin-audit <target> [--seed <path>]
```

같은 이름이 설치 환경에 있으면 `/plugin-audit:plugin-audit` 로 부른다. 이 skill 은 사용자만 부른다(`disable-model-invocation: true`).

- `<target>` — 감사할 플러그인 이름 (예: `quality-gates`). scope는 `plugins/<target>/**`로 도출.
- `--seed <path>` — optional. 추가 scope · Open Questions · 후보 단서를 담은 markdown.
  없으면 6축 fresh discovery로 degrade(배너 표시).

`cost_class: high` — dispatch 전 `AskUserQuestion` 지출 동의 게이트를 통과해야 한다.
Kill switch: `DEVBREW_PLUGIN_AUDIT_DISABLE=1`.
본문 전 사전 검사(`scripts/entry_preflight.py`)가 이 스위치를 판정한다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다. 그 스크립트나 `python3` 가 없으면 플랫폼이 호출을 끊는다(헤드리스에서는 출력 없이 끝난다).

**산출 위치** — 감사마다 실행 디렉토리 `.claude/plugin-audit/<date>-<target>[-N]/` 이 생긴다(지출 동의
승인 직후, `scripts/prepare-run-dir.py`). 리포트 `audit.md` · 데이터 `audit-data.json` · 원장
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
이 이름이 정본이다. 옛 이름 `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1` 도 별칭으로 여전히 따른다(0.11.1 부터) —
같은 skip 이 되고, `create-sandbox` 가 stderr 한 줄로 개명을 알린다.

`DEVBREW_PLUGIN_AUDIT_STALENESS_REGISTRY` — staleness census가 참조하는 원장 경로 override.

**환경변수 어순 rename (0.6.0, devbrew-weight-reduction Task 25).** 이 플러그인이 노출하는
사용자-표면 이름 4개가 `DEVBREW_<PLUGIN>_<REST>` 하나로 통일됐다:

| 옛 이름 | 새 이름 |
|---|---|
| `DEVBREW_DISABLE_PLUGIN_AUDIT` | `DEVBREW_PLUGIN_AUDIT_DISABLE` |
| `DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX` | `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX` |
| `DEVBREW_DISABLE_PLUGIN_AUDIT_WEB` | `DEVBREW_PLUGIN_AUDIT_DISABLE_WEB` |
| `DEVBREW_STALENESS_REGISTRY` (플러그인 토큰 없던 이름) | `DEVBREW_PLUGIN_AUDIT_STALENESS_REGISTRY` |
| `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` (0.11.0 에 더함 · 0.11.1 부터 별칭으로 따름) | `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX` |

옛 이름은 **fallback 없이 즉시 제거**됐다 — 이 rename 당시(0.6.0) 이 플러그인에는 `CHANGELOG.md`가
없었다(`plugin.json` 버전이 CLAUDE.md §메타데이터의 "v1.0.0 이상이면 CHANGELOG.md" 문턱 아래라 별도
파일을 만들지 않았고, 대신 이 kill-switch 절에 기록했다 — `CHANGELOG.md` 는 0.6.1 부터 있다). 근거는 현재 제3자 설치가 없다는
것 하나이며, CLAUDE.md §메타데이터의 one-minor deprecation window 원칙과의 충돌을 그 조건
아래 수용한 것이다. **제3자 설치가 생기면 이 근거가 바뀐다** — 그때는 다음 rename에
fallback 창을 둔다.

표의 마지막 줄은 0.11.0 에서 더했다 — 샌드박스 도우미가 quality-gates 10.0.0 에서 이 플러그인
(`scripts/audit-sandbox.sh`)으로 옮겨 오며 이름이 바뀌었다. 위 「fallback 없이 즉시 제거」의 **예외다** —
kill switch 는 보안 컨트롤이라, 옛 이름을 조용히 버리면 그것으로 자체 테스트 실행을 꺼 둔 사용자에게서 실행이 다시
켜진다(fail-open). 그래서 0.11.1 부터 옛 이름도 따른다: 값이 정확히 `1` 이면 새 이름과 같이 `create-sandbox` 가
exit 3 으로 멈추고, stderr 한 줄이 옛 이름과 새 이름으로의 개명을 함께 밝힌다. 정본은 새 이름이다.
`CHANGELOG.md` `[0.11.0]` · `[0.11.1]` 에 적었다.

**severity 어휘 통일 (0.6.0, devbrew-weight-reduction Task 28).** 감사 리포트 발견 항목의
`[severity]` 배지가 옛 4-vocab(`CRITICAL`/`HIGH`/`MEDIUM`/`LOW`)에서 quality-gates와 동일한
3-vocab(`CRITICAL`/`IMPORTANT`/`SUGGESTION`)으로 바뀌었다 — `HIGH`→`IMPORTANT`,
`MEDIUM`·`LOW`→`SUGGESTION`. `HIGH`를 `CRITICAL`로 승격하지 않은 이유: quality-gates의
`CRITICAL`은 머지 차단 등급이고 plugin-audit의 `HIGH`는 정렬 순위일 뿐이라, 승격하면 차단
임계가 조용히 내려간다. 옛 어휘로 쓰인 과거 리포트/데이터는 그대로 렌더되지만(크래시 없음)
정렬 순위표에 없어 맨 뒤로 밀린다.

## Prerequisites (cross-plugin 의존)

- **plugin-dev (official, optional)** — 구조 hard-check tier(E)가 `validate-agent.sh`·
  `validate-hook-schema.sh`·`hook-linter.sh`를 감싼다. 공식 캐시에 있으면 심층 구조 사실을
  얹고, **없으면 loud degrade**(core 구조 검사는 F가 self-contained로 커버). E는 bonus-degradable.

## Principles Instantiated

이 플러그인이 instantiate하는 devbrew 철학.

### Three Laws
- **Law 1 (Clarity Before Code)** — 1차 산출물은 증거로 뒷받침된 갭 목록. 빈 감사는 감사가 아니다
  (6축 전멸 시 리포트 없음, AC-4). 갭이 적게 나오는 것은 실패가 아니고 없는 갭을 만드는 것이 실패.
- **Law 2 (Writer ≠ Reviewer, 물리 분리)** — 3 agent(`plugin-auditor`·`audit-refuter`·`smoke-probe`)의
  `tools:` allowlist(`Read, Grep, Glob, WebSearch, WebFetch`)가 쓰기·실행을 fail-closed로 차단.
  프롬프트가 아니라 frontmatter scoping. `check-law2.py` 정적 게이트 + smoke가 런타임 실증.
- **Law 3 (Every Cycle Leaves the System Smarter)** — 리포트는 한 번 읽는 작업 산출물이다
  (`.claude/plugin-audit/<실행 키>/`, 스스로 git-ignore). 이 사이클의 compounding 은 감사가 낳은 수정
  커밋과 reviewer persona 편집이 맡는다.
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
- **P11 (모델 다양성)** — codex(다른 모델 패밀리)가 blind 독립 co-audit; union-for-recall +
  independent-refutation(majority-vote consensus 금지 — popularity trap).
- **P21 (untrusted-input)** — 감사 대상 파일 내용은 데이터지 지시가 아니다(C). Secret 기록 금지.
- **P22 (cost 인지)** — `cost_class: high` + fan-out 선언 + `AskUserQuestion` 지출 동의 게이트.
- **정직성 (degraded 배너)** — optional 의존성 부재/검증기 크래시/grounding 미검증은 crash가 아니라
  loud degrade + 리포트 상단 배너(품질 게이트 아님, 정직성 컨트롤).

## 컴포넌트

- `skills/plugin-audit/SKILL.md` — 오케스트레이션(지출게이트 → pre-0 → Workflow → post-1). 진입 단계(사전 검사 · 인자 해석) 포함.
- `agents/{plugin-auditor,audit-refuter,smoke-probe}.md` — 읽기전용 agent 3종.
- `scripts/*` — 결정론 게이트·조립·렌더·검증 + Workflow 스크립트.
