# Changelog

## [1.0.1] — 2026-10-09

### Fixed

- `tests/test_severity_mapping.py` docstring 이 quality-gates 의 미지 severity 처리를 「SUGGESTION 으로 강등」이라 적었다 — 지금은 IMPORTANT 로 올리고 강제로 센다. 동작 변화 없음.

## [1.0.0] — 2026-10-09

major 인 이유 — 명령 층이 사라졌고, skill 이 개명돼 사용자 전용이 됐다.

### Removed

| 옛 호출 · 이름 | 새 완전명 |
|---|---|
| `/plugin-audit` 명령 (`commands/plugin-audit.md`) | `/plugin-audit:plugin-audit` (skill) |
| skill `auditing-plugins` | `plugin-audit` |

### Changed

- skill 이 `disable-model-invocation: true` 다 — 모델이 부르지 않는다.
- 본문 전 사전 검사(`scripts/entry_preflight.py`)와 `## 진입 단계` 가 kill switch 와 인자 해석을 맡는다.
- `check-staleness.py` 규칙 (a): `skills/<name>/SKILL.md` 가 뒷받침하는 `/name` 은 dangling 이 아니다.

## [0.11.2] — 2026-10-09

### Changed
- SKILL.md·명령 파일 맨 앞(H1 바로 다음)에 「사람에게 쓰는 글」 규칙 블록을 둔다. 정본은 리포의 `shared/style/plain-language.md` 이고 `shared/tests/test_plain_language_block.sh` 가 같음을 잰다.

## [0.11.1] — 2026-10-09

### Security

- **옛 kill switch 이름이 조용히 무시되던 fail-open 을 닫았다.** `[0.11.0]` 이 `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` 를 `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX` 로 바꾸며 옛 이름을 더 읽지 않았다. 옛 이름으로 자체 테스트 실행을 꺼 둔 사용자에게서 감사 대상의 테스트 코드가 다시 돌았다 — 아무 알림 없이, 그리고 `run-own-tests.sh` 머리의 연기된 CRITICAL(프로세스 · 네트워크 · uid 격리 없음) 아래에서. 이제 `scripts/audit-sandbox.sh create-sandbox` 가 두 이름을 모두 따른다: 어느 쪽이든 값이 정확히 `1` 이면 아무것도 만들기 전에 exit 3 으로 멈춘다. 옛 이름이 멈춘 경우 stderr 한 줄이 옛 이름과 새 이름으로의 개명을 함께 밝힌다. `run-own-tests.sh` 의 skip 사유도 두 이름을 함께 적는다. 정본은 새 이름이다 — README 의 kill switch 절과 rename 표에 적었다.

## [0.11.0] — 2026-10-09

minor 인 이유 — `scripts/run-own-tests.sh` 의 옵션 이름과 kill switch 이름이 바뀌었다.

### Added

- `scripts/audit-sandbox.sh` — 자체 테스트 격리용 일회용 샌드박스(`create-sandbox` · `mutation-guard` · `remove`). quality-gates 10.0.0 이 `qg-worktree.sh` 에서 지운 `create-sandbox` · `mutation-guard` 를 옮겨 왔고, `remove` 는 plugin-audit 의 경로 · 이름에 맞춰 다시 썼다(qg 의 `remove` 는 차등 테스트용으로 남는다 — 두 사본 머리에 서로를 가리키는 줄이 있다). 상태는 `.claude/plugin-audit/worktrees/` 에 산다. 테스트 둘(`tests/test_audit_sandbox_create.sh` · `tests/test_audit_sandbox_mutation_guard.sh`)도 quality-gates 에서 옮겼다.

### Changed

- `scripts/run-own-tests.sh` — 샌드박스 도우미를 스크립트 옆에서 찾는다(cwd 기준 `plugins/quality-gates/...` 경로를 버렸다). 스텁 옵션 `--qg-worktree` → `--sandbox-helper`. 도우미가 없을 때의 skip 사유가 「quality-gates 미설치」에서 「audit-sandbox.sh 부재」로 바뀌었다.
- kill switch `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` → `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX`. 옛 이름은 더 읽지 않는다(fallback 없음) — README 「환경변수 어순 rename」 표에 적었다.
- `scripts/audit-workflow.js` 계약 문구의 형제 구현 예시를 지워진 qg 훅에서 `plugins/spec-distill/hooks/*.py` 로.
- `scripts/prepare-run-dir.py` docstring · SKILL 이 `qg-worktree.sh` 대신 `audit-sandbox.sh` 를 가리킨다.

### Removed

- quality-gates 선택 의존(≥ 2.12.0) — 더는 필요 없다. README Prerequisites 에서 그 항목을 지웠다.

### Security

- **cwd 상대 실행 구멍을 닫았다.** `[0.9.3]` 이 「범위 밖으로 남긴 것」으로 미룬 항목 — `scripts/run-own-tests.sh` 가 `--qg-worktree` 없이 cwd 상대 `plugins/quality-gates/scripts/qg-worktree.sh` 를 **실행**해, 감사하는 저장소의 그 경로에 있는 파일이 돌던 것 — 이 이제 없다. 샌드박스 도우미는 스크립트 옆의 `audit-sandbox.sh` 다.
- **노출이 넓어졌다 — 감사 대상의 자체 테스트가 이제 모든 저장소에서 돈다.** 전에는 devbrew 루트 밖에서 cwd 상대 도우미가 없어 자체 테스트를 건너뛰었다. 이제 도우미를 언제나 찾으므로 감사 대상의 테스트 코드를 언제나 실행한다. 그 격리는 그대로다 — `run-own-tests.sh` 머리의 연기된 CRITICAL: 「"샌드박스"는 audit-sandbox.sh의 `git worktree add --detach HEAD` 일 뿐 프로세스/네트워크/uid 격리가 없다」 · 「그 전까지 미신뢰 대상 감사 금지.」 **신뢰하지 않는 플러그인은 감사하지 않는다** — 자체 테스트 실행을 끄려면 `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX=1`(위 Changed).

## [0.10.0] — 2026-09-28

minor 인 이유 — 산출 경로와 `render-audit-report.py` 의 CLI 가 바뀌었다.

### Added

- `scripts/prepare-run-dir.py` — 지출 동의 승인 직후 실행 디렉토리 `.claude/plugin-audit/<date>-<target>[-N]/` 을 원자적으로 만들고(`-N` 으로 기존 것을 덮지 않는다) 안에 `*` 한 줄짜리 `.gitignore` 를 쓴다. 둘째 줄로 sandbox id(실행 키의 SHA-256 앞 8 hex)를 낸다 — `qg-worktree.sh create-sandbox` 가 id 앞 8글자만 쓰므로 날짜 키를 그대로 넘기면 같은 달 감사가 한 sandbox 로 접힌다.

### Changed

- 모든 산출(`audit.md` · `audit-data.json` · `audit-journal.jsonl`)과 중간 파일이 실행 디렉토리에 쌓인다. 감사 끝에 절대경로를 보고한다. 리포트는 한 번 읽는 작업 산출물이다(README Law 3).
- phase 0 의 clean-tree 선결조건과 post-1 의 커밋 단계를 없앴다.
- 무결성 불일치(post-1 step 5)는 감사를 무효로 한다 — 실행 디렉토리에 `VOID` 를 남기고 종료 보고를 하지 않는다(커밋 단계가 사라져 「롤백」이 가리킬 것이 없어졌다).
- AC6 회귀 테스트의 정답지를 `tests/fixtures/ac6_baseline.json` 으로 옮겼다 — 옛 자리 `docs/audits/` 가 리포에서 사라졌다.

### Removed

- `render-audit-report.py --readme`(README 인덱스 쓰기). `validate-audit-data.py --artifacts` 의 README 링크 · CLAUDE.md 포인터 검사와 `--repo-root` 옵션. 배너 검사(AC-3)는 남는다.

## [0.9.4] — 2026-09-22

### Changed

- 감사 대상 세 플러그인의 `hooks.json` 과 `scripts/` 가 바뀌어 cache key 를 무효화한다.
  이 플러그인 자신의 표면·동작은 바뀌지 않았다. 훅이 없고 셸 자리는 Python 바닥 집행의
  범위 밖이라 `Python 3.12+` prerequisite 를 주장하지 않는다 — 집행하는 주체가 없는
  선언은 두지 않는다.

## [0.9.3] — 2026-09-15

### Security

- **codex 감지 펜스가 cwd 의 `./plugins/plugin-audit` 로 떨어지던 fallback 을 없앴다.** `skills/auditing-plugins/SKILL.md` 의 `PA="${CLAUDE_PLUGIN_ROOT:-./plugins/plugin-audit}"` 는 Bash 도구 환경에 그 변수가 없어 언제나 cwd 상대로 풀렸다. 이제 로드 시 치환되는 bare `${CLAUDE_PLUGIN_ROOT}` 에서 받고, 빈 값이면 `[plugin-audit] 플러그인 루트 미해석 — …` 로 멈춘다.
- **Law 2 정적 게이트가 실행 대상과 같은 플러그인 루트를 본다.** pre-0 의 `check-law2.py` 호출이 자기 워크플로 · agents 를 cwd 상대 `plugins/plugin-audit/…` 로 받아, Workflow 가 실행하는 설치본과 게이트가 검사하는 사본이 갈라질 수 있었다. 호출과 인자를 `${CLAUDE_PLUGIN_ROOT}/…` 로 바꾸고, 「모든 스크립트 호출은 리포 root에서」 진술을 「스크립트는 `${CLAUDE_PLUGIN_ROOT}/scripts/`, 감사 대상 인자는 리포 root 기준」으로 다시 썼다. 치환된 경로는 전부 따옴표로 감쌌다 — 설치 경로에 공백이 있으면 따옴표 없이는 인자가 쪼개져 감사가 dispatch 전에 멈춘다.

### Fixed

- **`scripts/check-law2.py` 의 `--agents-dir` 기본값이 cwd 상대(`plugins/plugin-audit/agents`)였다.** 스크립트 위치 기준(`<플러그인 루트>/agents`)으로 바꿨다 — cwd 에 `plugins/plugin-audit/` 이 없거나 다른 사본이 있어도 설치본 agents 를 검사한다. `tests/test_check_law2.py` 에 두 케이스를 더했다.

**알려진 결과 둘**

- **devbrew 안 dogfooding 이 바뀐다.** 설치본 skill 이 이제 워킹트리가 아니라 설치본 스크립트를 돈다. 워킹트리 코드를 돌리려면 `claude --plugin-dir ./plugins/plugin-audit` 로 로드한다.
- **skill 본문 치환이 없는 하니스에서는 멈춘다.** 경로를 추측하지 않고 가드에서 복구 지시와 함께 멈춘다. 어느 하니스가 그런지는 모른다 — 2.1.270 에서는 치환된다.

**범위 밖으로 남긴 것** — `scripts/check-integrity.sh` 의 harness 변조 감시는 체크아웃 사본을 해시하고, `scripts/run-own-tests.sh` 는 `--qg-worktree` 를 주지 않으면 cwd 상대 `plugins/quality-gates/scripts/qg-worktree.sh` 를 **실행**한다 — 사용자 저장소의 그 경로에 파일이 있으면 그것이 돈다. 이 릴리스 이전부터의 불일치이며 후속으로 넘긴다.

## [0.9.2] — 2026-09-11

### Fixed

- **`scripts/run_audit_codex_reviewer.sh` 의 주석 두 곳이 지워진 spec-distill 러너를 현재형으로 가리켰다.** spec-distill 이 interview brief 리뷰를 공유 문서 리뷰 엔진으로 옮기며 `run_brief_codex_reviewer.sh` 를 지웠다(`plugins/spec-distill/CHANGELOG.md` `[3.1.0]`). 「형제 러너」 주석은 살아 있는 `run_docreview_codex_reviewer.sh` 하나로 줄였고, 선례를 대던 문장은 「지금은 지워진 옛 brief 러너」로 고쳤다. 동작 무변경, 새 surface 없음 — patch.

## [0.9.1] — 2026-09-09

### Fixed

- **`scripts/run_audit_codex_reviewer.sh` 의 형제 러너 주석이 삭제된 spec-distill 파일을 가리키고 있었다.** design doc 자리가 문서 리뷰 엔진으로 전환되며 spec-distill 의 `run_spec_codex_reviewer.sh` 가 삭제됐다(`plugins/spec-distill/CHANGELOG.md` `[1.0.0]`) — "형제 러너" 주석을 `run_brief_codex_reviewer.sh`·`run_docreview_codex_reviewer.sh` 로 정정.
- **`tests/test_run_audit_codex_reviewer.py` 의 blind-보존 금지어 목록이 존재하지 않는 빌더 이름을 검사하고 있었다.** `build_spec_codex_prompt` 는 이미 삭제된 파일이라 이 assertion 이 항상 vacuously 통과했다 — 현재 존재하는 `build_seed_codex_prompt` 로 교체해 다시 이빨을 갖게 했다. 동작 변경 없음, 새 surface 없음 — patch.

## [0.9.0] — 2026-09-06

### Changed

- **agent frontmatter 의 `model: inherit` 를 제거했다 — `inherit` 는 사용자의 subagent
  기본 티어 설정을 덮어쓴다 (CLI 2.1.261 실측, 2026-09-06).** frontmatter 에 `model` 키가
  없으면 하니스가 「`CLAUDE_CODE_SUBAGENT_MODEL` → 세션 모델」 순으로 위임하고, `inherit` 는
  그 첫 단계를 건너뛴다(헤드리스 probe 6회, 설계 §A). 설정이 없는 환경은 동작이 같다.
  규약·락은 「키 부재」 단언으로 반전 — 정본은
  `docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md`.

### Fixed

- **구조 검사가 `model` 키 부재를 degrade 로 세던 것.** plugin-dev `validate-agent.sh` 는
  `model` 을 필수로 요구하는데 그것은 devbrew 규약이 아니다 — 핀을 빼면 agent 마다 degrade
  한 줄이 생겼을 것이다. `check-plugin-structure.sh` 가 `model` 누락 단독은 기록하지 않고
  `color` 누락 단독만 기존대로 degrade 로 남긴다. 구현 중 확인: plugin-dev 검증기는 model 키 없는 agent 에서 ❌ 없이 조용히 죽는다(rc=1) — 그 경우는 agent 별이 아니라 플러그인당 집계 1줄로, model 키가 있는데 죽으면 agent 별 스퓨리어스 exit 줄로 기록한다(테스트 4건, 양성 짝 포함).

## [0.8.2] — 2026-09-05

### Fixed

- **README 의 「Principles Instantiated」에 이 사이클의 instantiation 이 없었다
  (최종 리뷰 K6b).** `처분`·`adjudication`·`Ledger`·`input_slots` 를 전수 grep 하면
  히트 0 이었다. `input_slots`(agent 셋 + `audit-refuter.findings` 의 C6 면제)와
  codex 러너의 `**처분**` 앵커 두 줄을 더했다. **범위 한계를 함께 적었다**: 이
  플러그인의 dispatch 는 `audit-workflow.js` 의 `agent(prompt, {agentType})` 라
  `shared/tests/test_agent_input_slots.sh` 의 `.md` dispatch 코퍼스에 «안 보이고»,
  셋 다 그 락의 새 `unmeasured` 축으로 세어져 이름이 나온다.
- **원장 정정 — `optional: true` 는 이 플러그인의 agent 셋에서 «무동작이 아니다».**
  SDD 원장이 「`optional: true` 는 판정기가 정적 텍스트만 보므로 무동작」이라고
  일반화해 적었는데, dispatch 가 `.md` 코퍼스 밖인 이 셋에서는 **유일한 침묵
  장치**다 — `smoke-probe.md` 에서 그 한 줄만 지우면 `PROBLEM undelivered` 로 즉시
  RED 가 된다(실측). 원장을 정정했다.

## [0.8.1] — 2026-09-04

### Fixed
- **Task 14 수정 라운드 1** — `tools/adjudication/check_slots.py`(L3 판정기,
  `plugins/*/agents/*.md` 전부를 검사)의 dispatch 펜스 스캐너가 들여쓴 펜스를
  구조적으로 못 보고, 한 펜스에 subagent_type 둘이면 조용히 첫 번째로만
  귀속하던 결함을 고쳤다 — 상세는 quality-gates CHANGELOG v6.6.1 참조. 이
  플러그인은 이 판정기의 검사 대상(plugin-auditor·audit-refuter·smoke-probe)이라
  선례대로 함께 bump. 이 라운드에서 이 플러그인의 파일 자체는 변경 없음.

## [0.8.0] — 2026-09-04

### Added
- **agent 3개(plugin-auditor·audit-refuter·smoke-probe)에 frontmatter
  `input_slots:` 선언 — L3(adjudication-topology Task 14).** 셋 다 dispatch 가
  `audit-workflow.js`/`smoke-workflow.js` 의 `agent(prompt, {agentType})` JS
  호출이라 `shared/tests/test_agent_input_slots.sh` 의 `.md`-only dispatch
  코퍼스(`subagent_type: "..."` 펜스 스캔)가 이 dispatch 자리 자체를 구조적으로
  못 본다 — 그래서 슬롯 전부 `optional: true` (미전달이 아니라 관찰 불가라는
  뜻, 각 파일에 주석으로 남김). `audit-refuter` 의 `findings` 는 `plugin-auditor`
  의 raw 감사 findings 를 반박하는 것 자체가 과업이라 `kind: prior_verdict` +
  `tools/adjudication/check_slots.py` 의 기존 `EXEMPT_SLOTS` placeholder(C6(1))를
  실제 태그명으로 채워 사용.

## [0.7.3] — 2026-09-04

### Fixed
- **`shared/tests/test_runner_disposition.sh`(codex 러너 처분 락)가 `consumer=`
  값의 참·거짓을 재지 못했다 — Task 13 수정 라운드 1이 이 플러그인 몫 러너에서
  실제로 그 구멍에 빠졌던 자리(adjudication-topology Task 13 수정 라운드 2).**
  `shared/tests/`에 있어 플러그인 자체는 아니지만 이 락의 코퍼스(`guards:
  plugins/*/scripts/*codex*.sh`)에 이 플러그인의 `run_audit_codex_reviewer.sh`가
  있어 함께 bump — 상세는 `shared/tests/test_runner_disposition.sh` 수정 내용
  참조(quality-gates·spec-distill CHANGELOG에도 같은 설명이 반복 기록됨, 셋 다
  이 락의 코퍼스에 러너가 있다).

## [0.7.2] — 2026-09-04

### Fixed
- **v0.7.1 이 낸 `consumer=orchestrator` 선언이 거짓이었다 — 리뷰가 Critical 로 잡았다
  (Task 13 수정 라운드 1).** `run_audit_codex_reviewer.sh` 의 산출물(`$CODEX_JSON`)을
  같은 플러그인의 `.py` 가 **직접 여는** 자리가 실재했다:
  `assemble-audit-data.py:233` 의 `load(a.codex_side)`(= `Path(p).read_text()`)가 그
  경로를 직접 read 한다 — `codex_audit_to_json.py` 자기 docstring("소비자가 둘이다 …
  나머지 셋은 `assemble-audit-data.py --codex-side`로 간다")과
  `auditing-plugins/SKILL.md:137` 표가 이미 이 사실을 적어 두고 있었는데, v0.7.1 이
  그 인용 바로 옆에서 반대 결론(`orchestrator`)을 냈다. `consumer=` 를
  `plugins/plugin-audit/scripts/assemble-audit-data.py` 로 교정 — 다른 채널
  (`findings` → `audit-workflow.js`, 오케스트레이터가 파싱해 넘길 뿐 파일을 직접
  열지 않는 쪽)은 앵커 산문에 부기만 한다(형제 `run_brief_codex_reviewer.sh` 가
  두 축을 같은 방식으로 처리한 선례). `fail-open`/`disclosure=meta.codex` 는
  리뷰가 독립 확인해 무변경 — `emit_degrade()` 가 실패 시에도 빈 컬렉션의 유효
  JSON 을 쓰므로 `assemble-audit-data.py` 의 `--codex-side` 가 그것을 읽어도
  하류가 막히지 않는다. `shared/tests/test_runner_disposition.sh` 는 이 경로의
  참·거짓을 구조적으로 재지 못해(존재+동일-플러그인만 검사) v0.7.1 도 GREEN 이었다
  — 락이 못 잡는 부류였고, 사람 리뷰가 코드 인용 셋으로 잡았다.

## [0.7.1] — 2026-09-04

### Fixed
- **`scripts/run_audit_codex_reviewer.sh` 가 자기 처분(누가 산출물을 읽는가·죽었을 때
  막는가 공시하는가·어느 채널로 드러나는가)을 밝히지 않고 있었다 — `shared/tests/test_runner_disposition.sh`
  (adjudication-topology Task 13) 가 26 단언 중 24 를 RED 로 잡았다.** 여섯 codex 러너 중
  이 플러그인 몫 하나에 `**처분**` 앵커를 추가: `consumer=orchestrator`(산출물
  `$CODEX_JSON` 을 `auditing-plugins/SKILL.md` 를 실행하는 오케스트레이터가 직접 읽어
  `findings` 는 `audit-workflow.js` 의 `codexFindings` 인자로, `d_verdicts`/`oq_answers`/
  `new_open_questions` 는 `assemble-audit-data.py` 의 `--codex-side` 로 나눠 넘긴다 — 두
  스크립트 중 어느 쪽도 이 파일을 직접 열지 않는다) · `fail-open`(codex 가 죽어도 나머지
  5축 감사(auditor+refuter)는 계속되고 `meta.codex.ran=false` + stderr 배너로만 공시된다
  — 이 축의 주 판정자가 아니라 모델 다양성 보조다) · `disclosure=meta.codex`.

## [0.7.0] — 2026-09-03

### Added

- **축 3(enforcement 능력)이 「지시가 수신자에게 도달하는가」를 묻는다.** 그 축은
  *"대상의 hook 이 무엇을 막는가"* 는 묻지만 도달은 안 물었다. 두 질문을 더한다 —
  ⑴ 모델에게 하는 지시가 모델이 실제로 읽는 채널로 나가는가(`systemMessage` 는
  사람 채널이다) ⑵ 한 산출물이 다음에 넘기는 값에 도착 확인 자리가 있는가.
  **축을 만들지 않는다** — `AXES` 원소는 6 그대로이고 기존 항목도 지우지 않는다.

### Known gaps

- 이 질문은 사용자가 `/plugin-audit` 을 실행할 때만 발화한다. 감사 없이 새 자리가
  생기면 여전히 안 묻는다. 상시 발화하는 자리(`CLAUDE.md`)는 상시 로드 표면을 늘려
  기각했다.

## [0.6.4] — 2026-08-25

### Added
- `tests/audit-workflow.test.mjs` — 결함 #9 의 **대칭 절반**(축 갈래) 회귀 테스트 2건.
  `[0.6.3]` 이 codex 갈래만 잠갔고, 그 테스트의 주석이 스스로 *"한쪽만 잠그면 정확히
  같은 방식으로 재발한다"* 고 적었는데 축 갈래(`scripts/audit-workflow.js:558`)의
  `degradedEvents.push` 를 지워도 스위트가 전건 GREEN 이었다(실측). 단언은 축 수를
  리터럴로 박지 않고 **「미검증 finding 마다 정확히 하나의 공시」** 라는 도출 관계로
  건다. 양성 짝(축 refuter 가 판정하면 공시 없음) 포함.

## [0.6.3] — 2026-08-25

### Added
- `tests/audit-workflow.test.mjs` — `[0.6.1]` 수리의 회귀 테스트 2건. 그 수리가 들어간 뒤에도
  스위트 어디에도 `degradedEvents` 문자열이 없어서, codex 갈래의 `push` 를 지워도 전부 GREEN
  이었다. 원 결함이 「구조가 같은 두 갈래 중 하나만 침묵」이었으므로 계측기 없이는 같은
  방식으로 재발한다. 판정 누락 시 공시가 쌓이는지 + 판정이 있으면 안 쌓이는지(양성 짝).

## [0.6.2] — 2026-08-23

### Added
- dispatch 자리(3곳)에 처분 앵커 — `**처분** — consumer=… · fail-… [· disclosure=…]`. `shared/tests/test_dispatch_disposition.sh` 축 A①②③④·B·C 가 집행한다.

## [0.6.1] — 2026-08-23

### Fixed
- `scripts/audit-workflow.js`: codex 갈래가 `rec.unverified = true`를 세우면서 `degradedEvent`를
  push하지 않아, refuter가 판정을 누락한 codex finding이 배너 없이 통과하던 것. 구조가 같은
  Claude 갈래(axis 결과 병합 루프의 `else if (!v)` 분기)는 이미 `degradedEvents.push(...)`를
  하고 있었다 — codex 병합 루프의 대칭 분기만 침묵이었다. 같은 push 구조로 맞췄다.
