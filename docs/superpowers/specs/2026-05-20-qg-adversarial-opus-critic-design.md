# qg adversarial — Opus-critic 정합 + persona 강화 design spec

> qg 비용 절감 탐색 중 발견한 adversarial 모델 선언 drift를, "버그 다운그레이드"가 아니라 **의도된 Opus-critic 패턴으로 정합**하고, 그 역할에 맞게 persona를 강화한다. sonnet 시절의 미니멀 calibration 프롬프트 → opus의 추론을 활용하는 다단계 검증 critic.

**Metadata**
- 출처: 2026-05-20 세션. `/superpowers:brainstorming` 으로 "qg 비용 절감" 탐색 시작 → reference corpus(OMC/codex/CE/superpowers/ouroboros/gstack) 2회 병렬 harvest → adversarial 모델 drift 발견 → 사용자가 Opus-critic 패턴으로 재해석 → persona 리서치(reference 1회 harvest) → 정합 + 강화.
- 대상 플러그인: `plugins/quality-gates/` (변경 전 `v1.30.1` → 변경 후 `v1.31.0`)
- 작성 시점: 구현·검증 완료 후 작성된 **결정 기록** (사용자 요청. brainstorming 흐름에서 spec 문서화 단계를 건너뛴 것을 정합). 구현은 working tree에 존재, 전체 테스트 GREEN.
- 작성자: Claude Opus 4.7 (1M context)
- 관련 메모리: [[respect_upstream_model_hardcoding]] (code-reviewer opus 불가침), [[feedback_plugin_version_bump]], [[feedback_devbrew_design_lightness]]

## Context / Why

사용자가 qg 실행 비용을 낮출 방안을 reference corpus 기반으로 탐색 요청. 분석 결과:

1. **qg는 이미 거의 모든 고전 무손실 cost 레버를 구현**했다 — conditional/lazy dispatch(scout), dedup(synthesizer), repeat/oscillation detection, trivia skip, fix-loop dedup, wall-clock budget, fan-out 게이트, infra agent→script(scout/synth/codex). reference의 cost 기법 대부분이 중복.
2. 사용자가 절감 강도를 **"무손실만"** 으로 선택 → 리뷰 커버리지 감소(depth-retune, skip-gate)는 범위에서 제외. 남는 무손실 헤드룸은 사실상 **모델 티어 정정** 한 갈래.
3. 모델 티어 점검 중 **adversarial 모델 선언 drift** 발견: `agents/adversarial.md` frontmatter = `sonnet`, README 모델 노트(:113) = `sonnet`, README phase 다이어그램(:140) = `opus`, `SKILL.md` Phase 1.5 dispatch = `model="opus"`. Task의 `model=` 이 frontmatter보다 우선하므로 **adversarial은 실제로 opus로 실행**되고 있었고, 세 사이트가 서로 모순.
4. 초기엔 이를 "비용 누수 버그(opus→sonnet 정정)"로 판단했으나, 사용자가 **Anthropic multi-agent 패턴(Opus orchestrator/critic + Sonnet worker; evaluator-optimizer)** 을 들어 반론. qg에 매핑하면 정확히 일치 — Phase 1/2 reviewer는 (code-reviewer 제외) sonnet worker, synthesizer는 deterministic script, 따라서 **adversarial이 Gate 2의 유일한 모델-기반 판단 게이트**. "판단 병목에 capability를 쓴다"는 설계로 보면 opus가 의도. 사용자 결정: **opus로 정합**(품질 우선, 비용 절감은 의도적으로 포기).
5. opus 확정 후 사용자가 "더 적절한 persona가 있으면 리서치 후 수정" 요청 → sonnet 시절의 미니멀 "calibration only" 프롬프트는 opus-critic의 추론 여력을 활용하지 못함. reference corpus에서 critic/validator/false-positive-hunter persona 기법을 harvest하여 **강화**.

핵심 긴장: 본 변경은 **비용을 낮추지 않는다** (adversarial은 원래도 opus 실행). 가치는 (a) 세 사이트 정합으로 drift 제거, (b) persona 강화로 critic 품질 향상, (c) drift 재발 차단 가드. 비용 절감은 별도 후속(depth-retune / skip-gate / domain-scoped diff)으로 분리.

## Goals

1. adversarial 모델 선언을 **세 사이트 모두 opus로 정합** — frontmatter를 single source of truth로, SKILL은 dispatch override 제거 후 frontmatter에 위임(다른 qg-owned agent 관례와 일치).
2. adversarial persona를 **opus-critic에 맞는 다단계 검증 critic으로 강화** — 강화만(약화 금지). 역할(verdict-only, no new findings)·출력 스키마·cwd 금지 규칙 보존.
3. **drift 재발 차단 가드** 신설 — 미래 단일 사이트 편집(특히 cost-cut으로 한 곳만 sonnet)이 CI에서 즉시 fail (Law 3 compounding).
4. README 모델 노트를 opus 근거(Opus-critic 패턴)로 재작성 + 비용 절감 시 건드릴 곳(모델 아닌 iteration 수/diff scope) 안내.

## Non-goals

- **다른 agent의 모델 티어 변경 없음.** code-reviewer(upstream opus 하드코딩, [[respect_upstream_model_hardcoding]]) 불가침. comment-analyzer/test-scope-validator 등의 haiku 다운은 본 spec 범위 밖(별도 결정 보류).
- **depth-retune / skip-gate / domain-scoped diff 없음.** 더 큰 절감 레버지만 커버리지 트레이드를 수반 → 사용자가 "무손실만" 선택으로 보류. 후속 spec 대상.
- **adversarial 역할 변경 없음.** verdict-only(confirm/downgrade/reject) 유지. finding 생성 agent로 바꾸지 않음.
- **출력 계약 파손 없음.** synthesizer(`synthesize_findings.py`)·behavioral test가 소비하는 스키마 보존.
- **confidence 스케일 변경 없음.** qg는 1–10 (synthesizer가 <7 suppress). CE의 0/25/50/75/100 anchor 미도입.
- **새 메커니즘/상태/의존성 없음** ([[feedback_devbrew_design_lightness]]).

## Constraints

- **persona = 보안-민감 코드** (CLAUDE.md "Persona 파일은 보안-민감 코드. 약화 PR은 보안 리뷰 대상"). 본 변경은 rigor 추가(3-gate, evidence bar, realist check)만; 임계치 완화·규칙 제거 없음. CHANGELOG에 강화 의도 명시.
- **출력 스키마 호환**: `synthesize_findings.py:32` 가 `verdicts:` wrapper와 bare top-level list 둘 다 수용. behavioral test fixture는 wrapper 형태. → persona를 wrapper로 정렬(둘 다 호환이나 wrapper가 test·consumer 문서와 일치). `finding_id: <agent>-<file>-<line>` 매칭 키(`apply_verdicts` by_id) 절대 보존.
- **모델 정합 대상 = adversarial뿐.** code-reviewer opus는 upstream 하드코딩이라 별개. 본 가드는 adversarial에만 적용.
- **버전**: 본 변경 = minor (persona 동작 강화 = enhanced capability). `v1.30.1` → `v1.31.0`. 모델 정합만이면 patch지만 persona 강화로 minor. plugin.json 같은 commit bump ([[feedback_plugin_version_bump]]).
- **CHANGELOG 분리**: persona 강화는 `### Changed`, drift 정합은 `### Fixed`, 가드는 `### Added` — 약화로 오해되지 않도록 의도 명시.
- **devbrew lightness**: escalation mode machine·confidence 스케일 교체 등 무거운 기법은 흡수하지 않고 핵심 rigor만 lean하게.

## Acceptance Criteria

- **AC1** `agents/adversarial.md` frontmatter `model: opus` (not sonnet).
- **AC2** `SKILL.md` Phase 1.5 adversarial dispatch에 `model=` override 부재 (frontmatter 위임). 재발 방지 inline 주석 존재.
- **AC3** README 모델 노트가 `` `adversarial` agent uses `model: opus` `` 로 시작하며 Opus-critic 근거 서술. phase 다이어그램(:140)도 opus로 일관.
- **AC4** README 모델 노트에 `` `adversarial` agent uses `model: sonnet` `` 부재.
- **AC5** persona가 per-finding 3-gate(real / introduced-by-this-diff / handled-elsewhere), severity realist check(data-loss/security/auth-bypass/financial 다운그레이드 금지 포함), corroboration 신호, evidence bar, contrarian/manufactured-rejection 금지(persona 실제 표현: `Do not manufacture rejections to seem thorough`)를 선언. 역할 경계(verdict-only, no new findings)·cwd 금지·`disallowedTools` 보존.
- **AC6** persona 출력 스키마: top-level `verdicts:` list, 각 block에 `finding_id`/`verdict`(enum confirm|downgrade|reject) + 선택 `adjusted_severity`/`adjusted_confidence`/`reason`/`better_fix`. `meta_note:` top-level 선택.
- **AC7** drift 가드 `tests/test_adversarial_model_consistency.sh` 신설, 세 사이트 opus 일관성 검증, 현 상태에서 PASS.
- **AC8** behavioral test `test_adversarial_behavior.py` 3개 PASS (출력 계약 보존).
- **AC9** 기존 구조 테스트 무영향: `test_synthesize_findings.sh`, `test_security_reviewer_persona.sh`, `test_agent_color.sh`, `test_agent_frontmatter_keys.sh`, `test_readme_state_diagram_complete.sh` PASS.
- **AC10** plugin.json `1.31.0`, CHANGELOG `[1.31.0]` 항목(Changed/Fixed/Added).

## Files to Modify

| 파일 | 변경 |
|---|---|
| `plugins/quality-gates/agents/adversarial.md` | frontmatter `sonnet`→`opus`; persona 강화(3-gate·realist·corroboration·evidence bar); 출력 `verdicts:` wrapper 정렬 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | Phase 1.5 dispatch `model="opus"` 제거 + frontmatter 위임 drift-prevention 주석 |
| `plugins/quality-gates/README.md` | 모델 노트(:113) opus 근거 재작성 (다이어그램 :140은 이미 opus) |
| `plugins/quality-gates/tests/test_adversarial_model_consistency.sh` | **신규** drift 가드 |
| `plugins/quality-gates/.claude-plugin/plugin.json` | `1.30.1`→`1.31.0` |
| `plugins/quality-gates/CHANGELOG.md` | `[1.31.0]` 항목 |

## Verification Plan

- `bash tests/test_adversarial_model_consistency.sh` → 6/6 PASS (frontmatter opus·not-sonnet, SKILL no-override, README diagram opus·note opus·not-sonnet). **결과: GREEN.**
- `pytest tests/test_adversarial_behavior.py` → 3 PASS (test 함수 내부 라벨 `test_AC45`/`AC46`/`AC47` — verdict enum / missing-key-raises / invalid-yaml; 이 라벨은 `test_adversarial_behavior.py` 자체 명칭이며 본 spec의 AC1–AC10과 무관, cross-spec 잔재). **결과: GREEN.**
- 회귀: `test_synthesize_findings.sh`(6 PASS), `test_security_reviewer_persona.sh`(13 PASS), `test_agent_color.sh`, `test_agent_frontmatter_keys.sh`, `test_readme_state_diagram_complete.sh` → 전부 exit 0. **결과: GREEN.**
- **명시적 배제**: `test_codex_dispatch_invariant.sh` Scenario 4는 FAIL이지만 본 변경과 무관한 *기존(stale) 실패* — scout/synthesizer가 T3-1/T3-2에서 script화됐는데 테스트가 여전히 Agent dispatch 블록을 기대. `git stash`로 확인한 결과 PRE/POST-change 동일하게 exit 1 (내 변경이 도입/악화시키지 않음). adversarial 자신은 project_dir를 보존해 Scenario 4 내 해당 check를 통과. "전부 GREEN" 주장은 *본 변경 scope의 테스트*에 한함. 별도 정리는 Deferred 참조.
- persona 재작성이 기존 테스트를 깨지 않음을 확인: 어떤 테스트도 persona 본문 문구(예: 삭제된 `adversarial-for-its-own-sake`)를 grep으로 의존하지 않음. (주의: `Calibration`/`Recalibration`은 신규 persona에서 *다른 문맥*으로 재사용 — 단어 부재를 주장하는 것이 아님.)
- TDD 순서 준수: 가드 테스트 먼저 작성 → 현 상태 RED(5 fail/1 pass) 확인 → 정합 → GREEN(6 pass).

## Rejected Alternatives

- **sonnet으로 정합 (비용 우선).** README:113의 기존 논거("calibration엔 sonnet 충분")대로 다운. 사용자가 Opus-critic 패턴 근거로 거절(품질 우선). 본 변경은 비용 절감 0을 의도적으로 수용.
- **하이브리드: CRITICAL/IMPORTANT finding 있을 때만 opus, 아니면 sonnet.** critic 패턴 이점을 고위험에서만 취하고 비용 대부분 절감. dispatch 분기 추가(상태/복잡도) → devbrew lightness 위반 + 무손실 헤드룸이 작아 ROI 낮음. 거절.
- **CE "territory between reviewers" 프레이밍 도입** (`ce-adversarial-reviewer.agent.md`). 그 agent는 emergent/cross-component issue를 *생성*하는 reviewer — qg adversarial의 verdict-only 역할을 바꿔버림. 거절(역할 보존).
- **confidence 0/25/50/75/100 anchor 스케일** (CE findings-schema). qg는 1–10 + synthesizer `<7` suppress. 스케일 교체 시 입력/출력 계약·synthesizer 파손. 거절(계약 보존). calibration 가이드만 1–10 내에서 흡수.
- **escalation / adaptive harshness mode machine** (OMC critic). finding 간 상태(모드 전환)를 추가 → leniency drift 우려 + lightness 위반. "per-finding 독립 판단" 한 줄로 대체. 거절.
- **domain-scoped diff / depth-retune / skip-gate** (비용 절감 본류). 커버리지/리뷰 깊이 트레이드 → "무손실만" 범위 밖. **보류(후속 spec)** — 거절이 아니라 deferred.

## Deferred (후속)

비용 절감의 큰 레버는 본 spec 밖에 남아 있음. 미래 세션 진입점:
- **depth-retune**: `scout.py`의 deep 편향 완화 (`new_files>=1` 또는 `config` 또는 `type_design` 단독 → 무조건 deep). 작은 구조적 diff는 standard + 해당 analyzer로.
- **skip-gate 확대**: lockfile-only / generated-only / 순수 version-bump diff를 trivia처럼 전체 skip.
- **domain-scoped diff**: comment-analyzer 등 좁은 agent에 해당 hunk만 전달(적용 범위 좁음).
- **무관 기존 실패**: `test_codex_dispatch_invariant.sh` Scenario 4가 scout/synthesizer를 Agent dispatch 블록으로 기대 — 둘은 T3-1/T3-2에서 script화됨. stale 테스트, 본 변경과 무관(PRE/POST 동일 fail). 별도 정리 대상.
