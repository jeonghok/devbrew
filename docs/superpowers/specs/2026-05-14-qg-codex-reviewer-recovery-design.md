---
name: qg-codex-reviewer-recovery
version: 1.0.0
created_at: 2026-05-14
session_id: a4ab65d8-7be3-4a7b-9cf3-ef12afa2589d
status: locked
next_phase: writing-plans
source: brainstorming-round-1
# Locked decisions — 본 세션 brainstorming에서 사용자 명시 응답으로 확정.
# Audit 산출물(`docs/research/`에는 없음, conversation-only): 6 reviewers (3×2 worktree audit)
# 결과 9 critical + 17 important findings. 본 spec은 그 중 PR #33 후속 영역 전체를 다룬다.
locked_decisions:
  - id: LD1
    decision: "Sub-project A (codex-reviewer 복구 + 견고화)를 sub-project B (forward-only 사후 보강)보다 먼저 진행한다."
    rationale: "v1.11.0의 C1+C2 결합으로 codex-reviewer가 production에서 dispatch되지 않음 — blast radius 가장 큰 결함."
  - id: LD2
    decision: "Scope은 Full — 4 critical + 11 important + Law 3 linter 추가까지."
    rationale: "동일 root cause(frontmatter 컨벤션 부재)를 두 번 fix하지 않으려면 linter가 같은 spec에 들어가야 함."
  - id: LD3
    decision: "Law 3 재발 차단 메커니즘은 quality-gates 내부 SessionStart advisor + bash regression test 조합."
    rationale: "cross-plugin coupling 회피 (plugin-dev 의존성 없음), 기존 advisor 패턴 활용, false-positive 위험 최소화."
  - id: LD4
    decision: "C2 (SKILL.md enum vs scout.md 불일치)는 scout이 codex-reviewer에 대한 일체 결정을 하지 않도록 분리하여 해결. dispatch 권한은 SKILL.md만 가진다. SKILL.md 내부에서 가용 codex 리스트를 `external_reviewers` 로컬 변수로 표현(scout output schema에는 추가하지 않음)."
    rationale: "scout의 책임 영역 축소(코드 리뷰 라우팅만, 외부 프로세스 dispatch 결정은 SKILL.md). codex 가용성 판단의 단일 진실(source of truth)이 SKILL.md → manifest 가용성 + consent."
  - id: LD5
    decision: "codex-reviewer dispatch는 scout 판단 영역 밖. codex_manifest.codex_available && consent_ok 시 무조건 Phase 1 parallel dispatch에 포함."
    rationale: "사용자 명시 요구 — '선택적으로 호출되는게 아니라 codex가 깔려있다면 들어가게'."
  - id: LD6
    decision: "PR shape: Stacked 2-PR — v1.11.1 hotfix (C1+C2) → v1.12.0 minor (나머지)."
    rationale: "production blocking 결함은 작은 PR로 빠르게, 보강은 별도. Review burden 분산."
---

# QG Codex-Reviewer 복구 + 견고화 설계

## Goal

PR #33 (v1.11.0)에서 도입했으나 두 가지 결함(C1 frontmatter 키 오류, C2 SKILL.md enum 불일치)으로 production에서 dispatch되지 않는 codex-reviewer를 복구하고, 동일 종류 frontmatter drift가 재발하지 않도록 검증 메커니즘을 추가한다.

## Context / Why

2026-05-14 retroactive QG audit (6 reviewers × 2 worktrees)에서 PR #33 (worktree-qg-codex-spec, MERGED bc06953)에 대해 9 critical + 17 important findings를 발견. 그 중 PR #33 영역의 4 critical과 11 important가 본 spec의 대상이다.

핵심 결함 두 가지가 결합되어 **현재 main에서 v1.11.0 codex-reviewer가 절대 dispatch되지 않는다**:

1. **C1**: `plugins/quality-gates/agents/codex-reviewer.md:6`의 frontmatter가 `allowed-tools` (kebab-case)로 작성되었다. Agent frontmatter는 `allowedTools` (camelCase)가 컨벤션이다 (sibling: `runtime-verifier.md`, `test-scope-validator.md`, `scout.md`). Claude Code agent runtime이 `allowed-tools` 키를 무시한다. CHANGELOG가 광고하는 "3-layer reviewer-writer isolation"의 Layer 2 (narrow Bash whitelist)가 실질적으로 비활성. Test (`tests/test_codex_reviewer_frontmatter.sh:61`)도 같은 잘못된 키를 검사하므로 invariant 자체가 verify 안 됨.

2. **C2**: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`의 Scout 출력 validation은 `phase1_agents ⊆ {code-reviewer, silent-failure-hunter, feature-dev:code-reviewer}` 를 hardcode (3개 한정). 그러나 `agents/scout.md:65-66`은 codex-reviewer를 `phase1_agents`에 추가하라고 모델에 지시. validation FAIL → `scout-fallback` engage → legacy "always 3 parallel" 분기 → codex-reviewer가 silently 빠짐. 운영자에게 보이는 신호 없음.

추가로 timeout 안전성 결함 (C3 `codex --version` no-timeout, C4 `TIMEOUT_CMD` empty fallback) + 11 important (silent failures, schema 미검증, auth regex 협소, docs 동기화 부재 등)이 동일 도메인에 누적되어 있다.

devbrew CLAUDE.md Law 3 ("Every Cycle Must Leave the System Smarter"): C1은 단순 typo fix가 아니라 "agent frontmatter 키 컨벤션을 강제하는 검증 메커니즘이 부재했다"는 신호. fix는 코드 한 줄 + persona 레벨 보강을 동반해야 compounding event.

## Goals

- **G1**: codex가 설치되고 auth되어 있으며 cost consent를 받은 사용자에게는, `/qg` Phase 1 standard/deep iteration에서 codex-reviewer가 **무조건** dispatch되도록 한다 (scout 판단 영역 밖).
- **G2**: codex가 미가용한 사용자에게는 v1.10.x 시점과 동일한 3-agent Phase 1을 regression 없이 유지한다.
- **G3**: 동일 종류 frontmatter 키 drift가 다른 agent 파일이나 future PR에서 재발하지 않도록 검증 layer를 추가한다 (CLAUDE.md "버그가 리뷰를 탈출하면 reviewer persona 파일을 편집" instantiation).
- **G4**: codex 외부 프로세스 호출의 silent failure surface를 닫는다 — timeout 부재 hang, schema 위반 silent coerce, prompt injection 가능 fence parsing, 협소한 auth-error 패턴.
- **G5**: codex-reviewer 관련 사용자-visible docs(README 트리/Gate 2 diagram/fan-out, spec 파일명, CHANGELOG)를 실제 코드 상태와 동기화한다.

## Non-goals

- **NG1**: sub-project B (PR #32 forward-only 후속 보강)는 본 spec 범위 외. 별도 spec.
- **NG2**: cost consent gate UX 변경 없음. 첫 사용 시 사용자 승인 요구는 그대로. "codex 자동 dispatch"는 *consent 받은 후* 자동을 의미.
- **NG3**: codex CLI 자체 동작 변경/패치 없음. 본 plugin이 호출 측만 다룸.
- **NG4**: plugin-dev:plugin-validator 확장 없음 — quality-gates 내부 self-contained linter만.
- **NG5**: 비영어 codex 출력 (일본어/한국어 등) 매칭은 default 범위 밖. AUTH_ERROR_RE 확장은 영어 패턴만 (`401|403|forbidden|unauthor|credential|quota|billing|subscription|expired`).
- **NG6**: codex-reviewer를 quick depth에 dispatch하지 않음 — quick은 in-process subagent도 안 돌리므로 외부 reviewer도 일관성 위해 제외.

## Constraints

- **CN1**: devbrew CLAUDE.md Plugin Shape 준수 — plugin.json SemVer bump (v1.11.0 → v1.11.1 → v1.12.0), CHANGELOG 항목, README "Principles Instantiated" 업데이트.
- **CN2**: PR shape Stacked 2-PR. PR ①(v1.11.1)이 base로 머지된 후 PR ②(v1.12.0)이 base=main으로 rebase 가능해야 함. 사용자 메모리에 따라 stacked PR base를 `--delete-branch`로 삭제하면 dependent PR CLOSED — 본 spec에서는 PR ② 머지 전까지 PR ① 브랜치 보존.
- **CN3**: backward compatibility — codex 미가용한 사용자 환경에서 기존 Phase 1 동작(3-agent parallel)이 동일하게 동작해야 한다. external_reviewers 필드가 빈 배열이면 결과적으로 `phase1_agents ∪ [] == phase1_agents`.
- **CN4**: cost consent gate는 보존. consent marker 파일 (`${HOME}/.claude/quality-gates/codex-cost-consent.md`)이 없으면 첫 사용 시 AskUserQuestion으로 승인 요청 (기존 동작 그대로).
- **CN5**: quality-gates 플러그인은 self-contained — plugin-dev/spec-distill 등 cross-plugin 의존성 추가 금지.
- **CN6**: 모든 훅에 kill switch — `DEVBREW_DISABLE_QG_CODEX=1` (codex-reviewer 전체 비활성, 기존 v1.11.0 가드) 외, frontmatter linter advisor는 `DEVBREW_SKIP_HOOKS=quality-gates:frontmatter-advisor` 로 비활성 가능해야 함.
- **CN7**: scout 출력 schema는 **변경 없음** (backward compatible). 기존 `phase1_agents` / `phase2_agents` / `depth` / `codex_manifest` (input) 필드 유지. **`external_reviewers`는 SKILL.md 내부 로컬 변수로만 존재 — scout output schema에는 추가하지 않는다 (LD4와 정합)**. scout이 codex 관련 dispatch field를 emit하지 않으므로 fallback 경로 schema 변경도 없음.

## Acceptance Criteria

### PR ① (v1.11.1 hotfix) — production blocking 즉시 해결

- **AC1**: `plugins/quality-gates/agents/codex-reviewer.md`의 frontmatter 키가 `allowedTools` (camelCase, line 6). 동시에 `plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh`의 **모든** `allowed-tools` 참조(line 60, 61, 65, 70 — 총 4 occurrences)를 `allowedTools`로 교체. 검증: `grep -rn "allowed-tools" plugins/quality-gates/agents/ plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh` 결과가 0줄. 통합 테스트 `bash plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh` 통과.
- **AC2**: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`의 scout output validation rule (현재 line 438 `phase1_agents ⊆ {code-reviewer, silent-failure-hunter, feature-dev:code-reviewer}`)은 **변경 없이 그대로 유지**. C2 root cause는 SKILL.md 측이 아니라 scout.md가 codex-reviewer를 emit하도록 지시하는 것 → AC3에서 upstream 해결. 본 AC는 SKILL.md validation rule이 AC3 적용 후에도 동일하게 PASS함을 검증 (회귀 방지).
- **AC3**: `plugins/quality-gates/agents/scout.md`에서 codex-reviewer 관련 dispatch instruction을 **구체적으로 제거**:
  - Phase 1 selection table (현재 line 65–70)의 codex-reviewer 조건부 포함 행 삭제.
  - 출력 schema 섹션 (현재 line 54)에서 codex-reviewer를 `phase1_agents` 후보로 언급하는 문구 제거.
  - **보존 (CN7 정합)**: `codex_manifest` *input* 필드는 그대로 유지 (scout이 dispatch 결정에 사용하지 않더라도 input으로 받음을 명시하는 것은 OK — SKILL.md가 dispatch 결정에 사용).
  - 검증: `grep -i "codex" plugins/quality-gates/agents/scout.md`의 결과에서 dispatch/output 관련 mention이 0이고 input/context 관련만 남음.
- **AC4**: `SKILL.md` Phase 1 dispatch logic 변경: standard/deep depth에서 `codex_manifest.codex_available == true` AND consent marker 존재 시, in-process subagent 3개(scout이 결정한 `phase1_agents`)와 함께 codex-reviewer를 **무조건** parallel dispatch에 포함한다. dispatch 결정 권한은 SKILL.md만 가진다. SKILL.md 내부에서 이 가용 codex 리스트를 가리키는 변수명을 `external_reviewers`로 둔다(local 변수, scout output 필드 아님).
  - **자동 검증**: `tests/test_codex_dispatch_invariant.sh` 신규 — `QG_MOCK_CODEX_MANIFEST=available`, `QG_MOCK_CONSENT_OK=1` 환경에서 SKILL.md의 Phase 1 dispatch logic을 inline shell로 시뮬레이션하는 grep+sed 기반 dry-run. codex-reviewer가 dispatch 리스트에 포함되는지 stdout 검증.
- **AC5**: codex 미가용 시(`codex_manifest.codex_available == false` 또는 manifest skip_reason 어떤 값이든) Phase 1은 기존 3-agent dispatch만 수행 — v1.10.x 시점과 byte-equivalent 동작.
  - **자동 검증**: `tests/test_codex_dispatch_invariant.sh` 동일 파일의 두 번째 시나리오 — `QG_MOCK_CODEX_MANIFEST=unavailable`에서 dispatch 리스트가 정확히 3-agent (codex-reviewer 부재)임을 검증.
- **AC6**: plugin.json 버전 v1.11.0 → v1.11.1. CHANGELOG에 `## [1.11.1] — 2026-05-14` 항목 추가 (Fixed/Security 카테고리).

### PR ② (v1.12.0 minor) — 견고화 + Law 3 linter

- **AC7**: `plugins/quality-gates/scripts/detect_codex.sh`의 `codex --version` 호출이 `timeout 5` 또는 `gtimeout 5`로 래핑된다. timeout 바이너리 부재 시 새 7번째 case `skip_reason: timeout_binary_missing` (exit 0 유지). `tests/test_detect_codex.sh`에 두 시나리오 추가 통과.
- **AC8**: `plugins/quality-gates/agents/codex-reviewer.md` agent body가 `TIMEOUT_CMD` 빈 문자열 검사 후 즉시 abort — `OVERRIDE_REASON=no_timeout_binary` 전달 후 codex 호출 회피. 결과 manifest에 `codex_failed: true`, `reason: no_timeout_binary`.
- **AC9**: `plugins/quality-gates/scripts/codex_findings_to_yaml.py`:
  - **(a) Schema mismatch**: findings가 list 아닐 때 빈 배열 coerce + `meta.reason: schema_mismatch` + `meta.raw_findings_type` (e.g., `"dict"`, `"str"`, `"NoneType"`) 기록. 검증 fixture: `tests/fixtures/codex_findings_dict_input.json` (findings를 dict로 emit), `tests/fixtures/codex_findings_string_input.json` (findings를 string으로 emit) 신규.
  - **(b) Last-fence selection**: `parse_fenced_json`을 `FENCED_JSON_RE.search(text)` 에서 `re.findall(FENCED_JSON_RE, text)[-1]` 로 변경 (multiple match 시 마지막 선택). 검증 fixture: `tests/fixtures/codex_two_fenced_blocks.json` 신규 — 첫 block에 `{"findings": []}` (가짜), 두 번째 block에 실제 findings. parser가 두 번째 block을 선택하는지 assert.
  - **(c) AUTH_ERROR_RE 확장**: 기존 `(authentication|auth\s+(failed|error)|invalid\s+(api[\s_]?key|token))` 에 `|401|403|forbidden|unauthor|credential|quota|billing|subscription|expired` 추가 (case-insensitive). 검증 fixture: stderr 샘플 5개 (`401 Unauthorized`, `403 Forbidden`, `quota exceeded`, `subscription required`, `credential expired`) 각각 매칭됨을 `tests/test_findings_parser.sh`가 검증.
  - **(d) stderr 읽기 실패**: `OSError` catch 후 `stderr_text=""`를 emit하기 전에 `meta.stderr_read_error: <errno>` (또는 errno 없을 시 `"<exception type>"`) 기록. 검증: `chmod 000`된 임시 stderr 파일을 input으로 parser 호출 시 `meta.stderr_read_error` 키 존재 검증 (단, CI 환경 root 권한이면 skip).
- **AC10**: `plugins/quality-gates/agents/codex-reviewer.md` agent body:
  - `python3 ... build_codex_prompt.py > "$PROMPT_FILE"` 직후 exit-code 검사 추가, 실패 시 `OVERRIDE_REASON=prompt_build_failed` + codex 호출 회피.
  - `REPO_ROOT="$(git rev-parse --show-toplevel)"` 직후 빈 문자열 검사, 빈 경우 abort.
- **AC11**: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`의 cost consent marker 쓰기에 실패 처리 추가 — SKILL.md prose가 모델에게 `if marker_write_failed: print(...)`를 명령하는 형태가 아니라, **shell command 자체에 `|| { echo "[quality-gates] could not persist consent (errno $?); will re-prompt next run" >&2; }`** 형태로 inline 처리하도록 prose 변경. 검증: 새 `tests/test_consent_marker_write_failure.sh` — `chmod 000 ~/.claude/quality-gates/` 후 SKILL.md의 marker-write snippet을 추출 실행, stderr에 위 메시지 패턴 grep. (CI root 환경 fallback: 가상 `HOME=/dev/null`로 marker-write 실패 강제, 동일 패턴 검증.)
- **AC12**: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`이 `detect_codex.sh` manifest를 schema validation — 필수 키 (`codex_available`, `codex_path`, `codex_version` 또는 `skip_reason`) 부재 시 안전한 default(`codex_available: false`) + stderr warning.
- **AC13**: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`의 scout-fallback 분기에서, codex 가용 + consent OK 시에도 codex-reviewer를 dispatch에 포함 (legacy fallback 경로도 동일 invariant 유지) — fallback이 codex를 silently 떨어뜨리지 않는다.
  - **자동 검증**: `tests/test_codex_dispatch_invariant.sh`에 세 번째 시나리오 추가 — `QG_MOCK_SCOUT_FALLBACK=1`, `QG_MOCK_CODEX_MANIFEST=available`, `QG_MOCK_CONSENT_OK=1` 환경에서 SKILL.md의 fallback 분기 dispatch 리스트에 codex-reviewer가 포함됨을 grep으로 검증. fallback 진입은 mock env var로 강제.
  - **사용자 visibility**: fallback engage 시 SKILL.md prose가 `[quality-gates] scout fallback engaged; codex-reviewer still dispatched (codex_available=true)` 형태의 명시적 stderr 메시지를 inline shell로 emit하도록 변경. silent skip 금지.
- **AC14**: 잘못된 frontmatter 키 검출 — 기존 `plugins/quality-gates/hooks/session-start-advisor.py`에 frontmatter scan 로직을 **확장 추가** (별도 hook 파일 신설 아님). 세션 시작 시 `plugins/*/agents/*.md` 스캔. `^allowed-tools:` 또는 `^disallowed-tools:` (kebab-case) 발견 시 한국어 advice 출력 (`⚠️ <파일경로>: agent frontmatter에 kebab-case 'allowed-tools' 발견. 'allowedTools' (camelCase)가 올바른 컨벤션.`).
  - **Kill switch**: 기존 `DEVBREW_DISABLE_QG=1`이 전체 advisor 비활성. **새 fine-grained switch**: `DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan` — 콜론 두 번 형식으로 advisor 내부 sub-feature 단위 비활성 (다른 advisor sub-feature는 계속 동작). CN6 정합. advisor 파일 상단 docstring에 sub-feature list와 각 sub-feature 비활성 토큰 명시.
- **AC15**: `plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` 신규 — repo 전체에서 `plugins/*/agents/*.md` 파일을 grep, `^allowed-tools:` 또는 `^disallowed-tools:` 발견되면 fail. 통과 시 `agent frontmatter keys: OK` 출력.
- **AC16**: `plugins/quality-gates/README.md`:
  - 디렉토리 트리(또는 동등 섹션)에 신규 4개 파일(`agents/codex-reviewer.md`, `scripts/detect_codex.sh`, `scripts/build_codex_prompt.py`, `scripts/codex_findings_to_yaml.py`) 추가.
  - Gate 2 stage diagram의 Phase 1 박스에 codex-reviewer 노드 추가 (or 별도 `external reviewers` 박스로 분리).
  - Fan-out 수치 표기 시 11 → 12 반영.
  - "Principles Instantiated" 섹션에 Law 2 (3-layer reviewer-writer isolation: frontmatter deny-list + bash allow-list + codex sandbox) 명시.
- **AC17**: `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` 내 모든 `codex-findings-to-yaml.py` / `detect-codex.sh` (dashes) 참조를 실제 underscore 파일명(`codex_findings_to_yaml.py` / `detect_codex.sh`)으로 정리. 검증: `grep -E "codex-findings-to-yaml|detect-codex" docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` 결과가 0줄.
  - **버전 헤더**: OQ1 해소 시 정확한 값(v3 또는 v3.1) 명시. **OQ1 미해소 fallback (default behavior)**: 버전 헤더를 `Draft v3.x — adversarial rounds resolved via PR review history (see git log)` 형태의 placeholder로 기재하고, PR ② body에서 "OQ1 resolved as v3.x — exact round count deferred to git history reconstruction" 명시. 본 AC는 placeholder 형태도 PASS로 간주.
- **AC18**: CHANGELOG에 `## [1.12.0] — 2026-05-14` 항목 추가 — Fixed/Changed/Security 카테고리. PR ① v1.11.1 entry는 superseded 표기 없이 그대로 보존.
- **AC19**: plugin.json 버전 v1.11.1 → v1.12.0.

## Files to Modify

```
PR ① (v1.11.1 hotfix):
  plugins/quality-gates/agents/codex-reviewer.md          # frontmatter 'allowed-tools'→'allowedTools' (line 6)
  plugins/quality-gates/agents/scout.md                   # Phase 1 selection table에서 codex-reviewer 행 제거, output schema의 codex dispatch mention 제거 (codex_manifest input은 보존)
  plugins/quality-gates/skills/quality-pipeline/SKILL.md  # Phase 1 dispatch logic: codex 가용+consent → external_reviewers 로컬 변수에 추가, in-process subagent와 parallel dispatch
  plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh  # line 60/61/65/70의 'allowed-tools' 4 occurrence → 'allowedTools'
  plugins/quality-gates/tests/test_codex_dispatch_invariant.sh  # 신규 — codex_available/unavailable/fallback 3 시나리오 dispatch 리스트 검증
  plugins/quality-gates/.claude-plugin/plugin.json        # 버전 1.11.0 → 1.11.1
  plugins/quality-gates/CHANGELOG.md                      # [1.11.1] 항목 추가

PR ② (v1.12.0 minor, base=PR ①):
  plugins/quality-gates/scripts/detect_codex.sh           # codex --version을 'timeout 5'로 래핑, 7번째 case skip_reason: timeout_binary_missing
  plugins/quality-gates/scripts/codex_findings_to_yaml.py # (a) non-list findings coerce + meta.reason, (b) re.findall last-fence, (c) AUTH_ERROR_RE 확장, (d) stderr read error meta surface
  plugins/quality-gates/agents/codex-reviewer.md          # TIMEOUT_CMD empty 검사 + REPO_ROOT empty 검사 + prompt builder exit-code 검사
  plugins/quality-gates/skills/quality-pipeline/SKILL.md  # consent marker write 실패 inline shell || 처리 + manifest schema validation + fallback 분기 codex inclusion + fallback engage stderr 메시지
  plugins/quality-gates/hooks/session-start-advisor.py    # 기존 advisor 파일에 frontmatter scan sub-feature 추가; sub-feature kill switch 'quality-gates:session-start-advisor:frontmatter-scan' 지원
  plugins/quality-gates/tests/test_agent_frontmatter_keys.sh  # 신규 — repo 전체 plugins/*/agents/*.md에서 'allowed-tools'/'disallowed-tools' grep deny-list
  plugins/quality-gates/tests/test_detect_codex.sh        # timeout 5초 래핑 검증 + timeout_binary_missing case 시나리오 추가
  plugins/quality-gates/tests/test_findings_parser.sh     # non-list (a), last-fence (b), auth regex 5 patterns (c), stderr read error (d) 시나리오 추가
  plugins/quality-gates/tests/test_session_start_advisor.py  # frontmatter scan sub-feature 검증 + sub-feature kill switch 검증
  plugins/quality-gates/tests/test_consent_marker_write_failure.sh  # 신규 — chmod 000 또는 HOME=/dev/null로 marker write 실패 강제, stderr 메시지 패턴 검증
  plugins/quality-gates/tests/fixtures/codex_findings_dict_input.json  # 신규 — AC9(a) 검증용
  plugins/quality-gates/tests/fixtures/codex_findings_string_input.json  # 신규 — AC9(a) 검증용
  plugins/quality-gates/tests/fixtures/codex_two_fenced_blocks.json  # 신규 — AC9(b) 검증용
  plugins/quality-gates/README.md                         # 디렉토리 트리에 신규 4파일 추가, Gate 2 diagram에 codex-reviewer 노드, fan-out 11→12, "Principles Instantiated"에 Law 2 (3-layer isolation) + Law 3 (advisor + test compounding) 추가
  plugins/quality-gates/.claude-plugin/plugin.json        # 버전 1.11.1 → 1.12.0
  plugins/quality-gates/CHANGELOG.md                      # [1.12.0] 항목 추가
  docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md  # codex-findings-to-yaml/detect-codex (dashes) → underscore 정리; 버전 헤더 OQ1 해소 결과 또는 placeholder
```

## Verification Plan

### 자동 (CI/bash)

- **V1**: `bash plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh` — PR ① 후 통과 (AC1).
- **V2**: `bash plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` — PR ② 신규 테스트 통과 (AC15, repo 전체 deny-list 검증).
- **V3**: `bash plugins/quality-gates/tests/test_detect_codex.sh` — 새 시나리오 (timeout 5초 적용, timeout_binary_missing) 포함 통과 (AC7).
- **V4**: `bash plugins/quality-gates/tests/test_findings_parser.sh` — 새 시나리오 (a/b/c/d 4 카테고리) 포함 통과 (AC9).
- **V5**: `bash plugins/quality-gates/tests/test_failure_injection.sh` — 기존 6 mocks가 회귀 없이 통과.
- **V6**: `python3 -m pytest plugins/quality-gates/tests/test_session_start_advisor.py -v` — frontmatter scan sub-feature + kill switch 검증 통과 (AC14).
- **V13**: `bash plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` — PR ① 신규 테스트 통과. 3 시나리오 (codex_available, codex_unavailable, scout_fallback+codex_available) 각각의 dispatch 리스트가 spec 예상과 일치 (AC4 + AC5 + AC13).
- **V14**: `bash plugins/quality-gates/tests/test_consent_marker_write_failure.sh` — marker write 실패 시 stderr 패턴 검증 통과 (AC11).

### 수동 (live codex)

- **V7**: codex CLI 설치된 환경에서 `/qg`. Gate 2 Phase 1 dispatch 메시지에 codex-reviewer가 등장하는지 stdout 확인. consent marker가 없으면 첫 사용 시 AskUserQuestion 등장하고, "Approve always" 후 marker 파일 생성 확인.
- **V8**: codex CLI를 PATH에서 일시 제거(`PATH=$(echo "$PATH" | tr ':' '\n' | grep -v codex | paste -sd:)`) 한 상태에서 `/qg`. Phase 1 dispatch가 기존 3-agent (code-reviewer/silent-failure-hunter/feature-dev:code-reviewer)만 포함하는지 확인 → AC5 회귀 검증.
- **V9**: codex 가용 환경에서 codex CLI 버전을 known-bad (예: 0.120.1 docker 이미지)로 교체 후 `/qg`. detect_codex.sh가 `skip_reason: known_bad_version` emit, codex-reviewer 제외, 사용자에게 명시적 메시지 출력 확인.
- **V10**: `allowed-tools` 키를 잘못 추가한 dummy agent 파일을 `plugins/quality-gates/agents/_test_bad.md`에 일시 작성 → 새 세션 시작 → SessionStart advisor가 한국어 advice 출력 확인. 파일 제거 후 advice 사라짐 확인.

### 코드 리뷰 게이트 (self-verification)

- **V11**: PR ①에 `/qg` 실행. Gate 2 verdict가 **PASS** 또는 **PASS_WITH_WARNINGS** 둘 중 하나여야 PASS로 간주. **FAIL이면 verification 실패** — PR 머지 차단. SKILL.md 변경 자체가 변경된 SKILL.md를 실행하므로 chicken-and-egg 우려가 있으나, 변경의 본질은 dispatch 결정 *로직* 추가이므로 변경된 SKILL.md도 정상 동작. 만약 변경된 SKILL.md가 자기 자신의 변경에 대해 NEEDS_RESTART를 emit하면 본 verification 실패로 간주 (forward-only state machine fix-loop 무한 회피).
- **V12**: PR ②에 `/qg`. 동일 기준 (PASS / PASS_WITH_WARNINGS만 통과). PR ①과 달리 PR ②는 SKILL.md 변경이 더 크므로 self-test 신호 더 강함. 기준: AC4/AC5/AC13 자동 검증 통과 + Gate 2 PASS.

## Rejected Alternatives

- **R1 — Single big PR**: 15–20 파일을 한 PR로 머지. 거부 — review burden 큼, hotfix와 보강이 섞이면 production 배포 risk가 보강 작업 review와 결합. Stacked 2-PR (LD6) 채택.
- **R2 — C2를 phase1_agents enum에 codex-reviewer 추가**: SKILL.md validation rule을 4개로 확장하고 scout이 계속 codex-reviewer를 phase1_agents에 emit. 거부 — scout이 codex 가용성 판단(설치/auth/version/consent)을 못함 → 그것을 SKILL.md가 reentrant 검증해야 → 결정 중복. 또한 사용자 요구 "선택적이 아닌 강제"와 정합하려면 결국 SKILL.md가 override해야 하는데, 그러면 scout의 emit이 무의미. LD4 (scout 책임 축소) 채택.
- **R2b — scout output에 external_reviewers 필드만 informational로 추가**: scout이 codex 가용 여부를 manifest에서 *읽기만* 하고 informational 필드로 echo. 거부 — scout의 출력 schema에 정보를 추가하는 것은 향후 scout 로직 변경 시 또 다른 drift surface(예: 누군가가 informational을 enforceable로 오해). 명확히 scout이 일체 관여 안 함이 단순.
- **R3 — scout이 codex-reviewer 포함/제외 결정**: 사용자 요청에 명시 거부 ("선택적으로 호출되는게 아니라"). codex_manifest 가용성 + consent만으로 자동(LD5).
- **R4 — plugin-dev:plugin-validator 확장으로 frontmatter 검증**: 더 깔끔한 도메인 fit이지만 cross-plugin coupling, plugin-dev 버전 bump 필요. 거부 — CN5 위반. quality-gates 내부 self-contained(LD3).
- **R5 — PreToolUse hook으로 Edit/Write block**: 즉각적이지만 slash command frontmatter는 kebab-case가 valid이므로 false positive 위험. 복잡도 증가. 거부 — advisor (non-blocking) + bash test (CI) 조합으로 충분.
- **R6 — cost consent gate 제거**: 사용자가 명시 안 했음. 기존 동작(첫 사용 consent) 보존하고, consent 후 자동 dispatch로 해석.
- **R7 — Sentinel marker 기반 prompt injection 방어**: `parse_fenced_json` 대신 `<FINDINGS_START>...<FINDINGS_END>` 같은 unique marker 사용. 거부 — codex 모델 출력에 marker가 정확히 emit된다는 보장 없음 (모델 신뢰 의존). last-fence selection이 더 단순하고 prompt 변경 불필요.
- **R8 — Integration test (real codex 호출)**: cost + flaky risk + CI 환경 codex 인증 복잡. 거부 — failure-injection mock 확장으로 충분. 수동 V7–V9가 integration 커버.
- **R9 — Vertical slice 3-PR**: hotfix → 견고화 → linter. 거부 — Stacked 3-PR은 base 의존성 관리 복잡, 머지 도중 base 삭제 시 dependent CLOSED 위험(사용자 메모리). 2-PR이 위험/이득 균형.

## Open Questions

- **OQ1**: `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md`의 정확한 spec 버전 — Draft v3 / 26 issues (spec 헤더) vs Draft v3.1 / 29 issues (CHANGELOG/plan)?
  - **Resolution path**: PR ② 작업 시 `git log --oneline --all -- docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` + spec 본문 git blame으로 reconstruct.
  - **Escalation**: reconstruct 실패 시 사용자에게 한 번 확인. 사용자도 모르면 AC17 fallback default(`Draft v3.x — adversarial rounds resolved via PR review history`) 채택. AC17이 placeholder 형태도 PASS로 정의하므로 OQ1 미해소가 PR ② merge를 차단하지 않음.
- **OQ2**: Frontmatter advisor가 plugin 외부 (예: 사용자 `.claude/agents/`)도 스캔할 것인가? Default — 본 spec 범위는 `plugins/*/agents/*.md`만. 사용자 글로벌 디렉토리는 NG1과 유사한 별도 결정.

## Concrete Next Action

다음 단계: `superpowers:writing-plans` skill을 호출하여 본 spec을 input으로 PR ① + PR ② 각각의 implementation plan 작성.

**정확한 invocation**:
```
Skill(skill="superpowers:writing-plans", args="docs/superpowers/specs/2026-05-14-qg-codex-reviewer-recovery-design.md")
```

writing-plans skill은 `args`로 받은 spec 파일 경로를 읽고, 본 spec의 PR ①/PR ② 분리(AC1–AC6 vs AC7–AC19), Files to Modify 트리, Verification Plan을 직접 참조하여 plan을 작성한다. 만약 writing-plans skill이 args 전달을 지원하지 않으면, skill 호출 직전 conversation에 "spec 경로: <path>" 메시지로 명시적 전달 (fallback).

**산출물**:
- Plan 경로: `docs/superpowers/plans/2026-05-14-qg-codex-reviewer-recovery.md` (단일 파일에 PR ① 섹션 + PR ② 섹션 분리).
- writing-plans skill이 plan 안에 "branch: feature/qg-codex-recovery-hotfix" (PR ①) + "branch: feature/qg-codex-recovery-hardening" (PR ②, base=PR ① branch) stacked 명시 권장.

**PR ② OQ1 dependency**: writing-plans skill 호출 직전 OQ1(spec v3 vs v3.1)을 git log로 reconstruct 시도. plan 안에 OQ1 해소 결과 또는 "placeholder v3.x 사용" 명시 (AC17 정합).
