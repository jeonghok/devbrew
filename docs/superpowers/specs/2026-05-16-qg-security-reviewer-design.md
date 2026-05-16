# QG Security Reviewer — Design Spec

> **Status:** Draft v2 — revised after spec-distill:spec-reviewer round 1 (6 issues addressed: finding schema anchored, AC10 split into structural + integration smoke, AC6 self-contradiction removed, AC3 grep commands pinned, fixture path pinned)
> **Author:** Jeongho-K (with Claude Opus 4.7)
> **Date:** 2026-05-16
> **Plugin:** `plugins/quality-gates`
> **Plugin bump:** `1.12.0 → 1.13.0` (minor — 새 reviewer surface 추가)
> **Branch:** `worktree-feature+qg-security-reviewer`
> **Revision log:**
> - v1 → v2: spec-reviewer round 1 — (1) finding YAML schema anchored to `adversarial.md:22-30` (Goal 6, AC2); (2) AC10 split into AC10a structural grep + AC10b integration smoke (LLM 비결정성 인정); (3) AC6 "SKILL.md 변경 불필요" 자기 모순 제거 + 발화 검증 명령 명시; (4) AC3 scout.md 변경 grep assertion 명시; (5) fixture path `tests/fixtures/security-reviewer/` 고정 + 최소 파일 목록 명시; (6) §9 concrete next action에 schema 확인 사전 작업 명시.

## 1. Context / Why

QG Gate 2의 Phase 1은 "모든 diff에 always-run" 일반 리뷰어 슬롯이다. 현재 catalog:

- `pr-review-toolkit:code-reviewer` — 일반 코드 리뷰
- `pr-review-toolkit:silent-failure-hunter` — 에러 핸들링 / fallback 안티패턴
- `feature-dev:code-reviewer` — 프로젝트 컨벤션 / CLAUDE.md adherence
- `codex-reviewer` (conditional) — 외부 모델 family를 통한 독립 검증

**보안은 누락**되어 있다. `pr-review-toolkit:code-reviewer`가 "bugs, logic errors, security vulnerabilities, code quality issues" 모두를 다루지만 — 한 agent에 4가지 mission을 dump하면 **specialist depth가 generalist breadth에 흡수**된다 (reference: compound-engineering 패턴이 보안 persona를 별도 분리한 이유).

3개 reference 모두 security를 독립 persona로 다룬다:

- `reference/compound-engineering-plugin/.../ce-security-reviewer.agent.md` — 조건부 dispatch, anchor-based confidence, low effective threshold (P0 + anchor 50 always reports)
- `reference/oh-my-claudecode/agents/security-reviewer.md` — OWASP Top 10 풀스캔, write/edit 차단 frontmatter, opus 모델
- `reference/gstack/review/specialists/security.md` — SCOPE_AUTH 또는 backend>100 lines 게이트, JSON-per-line schema, auth/crypto/secrets 카테고리

devbrew는 이 셋을 **always-run Phase 1 reviewer**로 통합한다. 조건부 dispatch (compound-engineering) 패턴이 더 cost-efficient이지만, 보안 miss 비용 > dispatch overhead 라는 reference 합의가 있고, Trivia escape가 이미 Gate 2 자체를 우회해서 trivial diff에서는 도는 일 자체가 없다.

## 2. Goals

1. `plugins/quality-gates/agents/security-reviewer.md`에 Phase 1 always-run reviewer agent를 추가한다.
2. Scout의 Phase 1 selection table 3개 tier (quick / standard / deep) 모두에 `security-reviewer`를 포함시킨다.
3. SKILL.md의 Phase 1 dispatch sequence가 다른 Phase 1 reviewer와 동일한 prompt template / 병렬 dispatch 패턴으로 security-reviewer를 호출한다.
4. Kill switch (`DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`)가 동작하며 loud-logging degradation을 제공한다.
5. Persona는 code-level review (Gate 1이 plan-level coverage 책임) — false-positive 억제 규칙 명시.
6. 출력은 `plugins/quality-gates/agents/adversarial.md:22-30`이 정의한 canonical finding schema를 따른다 — Phase 1.5 adversarial + Phase 1.6 synthesizer가 파싱하는 동일한 shape:

   ```yaml
   - agent: security-reviewer
     file: <path>
     line: <number>
     severity: CRITICAL | IMPORTANT | SUGGESTION
     confidence: <1-10>
     summary: <one-sentence>
     proposed_fix: <description or code>
   ```

   기존 `pr-review-toolkit:code-reviewer`등의 markdown-prose output과는 다른 별도 path — codex-reviewer가 `codex_findings_to_yaml.py`로 emit하는 shape와 동일. Persona가 이 schema를 직접 emit하도록 본문에서 명시한다 (parser script 경유 없음 — security-reviewer는 LLM agent이므로 직접 YAML 출력).

## 3. Non-goals

- **Plan-level security lens 추가 안 함.** Gate 1 plan-verifier가 이미 spec coverage 검증. compound-engineering의 plan-level lens는 devbrew 컨텍스트에서 중복.
- **외부 vulnerability scanner 자체 실행 안 함.** 의존성 audit 명령 실행은 persona scope 밖. Agent는 dependency 변경을 *findings*로 flag하되 audit는 사용자/CI 영역.
- **다른 Phase 1 reviewer의 보안 항목 제거 안 함.** `pr-review-toolkit:code-reviewer`가 security 항목을 mission에 유지하더라도 specialist depth는 새 agent가 담당 — 중복은 adversarial + synthesizer가 dedupe. Mission overlap 제거는 별도 PR이 필요하면 그때.
- **conditional dispatch로 회귀 안 함.** Phase 1 always-run 결정은 brainstorming에서 사용자 승인 완료.
- **새 P# (devbrew 원칙) 추가 안 함.** Law 2의 instantiation일 뿐 직교 원칙 아님 (memory: devbrew designs default to lightness).
- **upstream `pr-review-toolkit:code-reviewer` mission 편집 안 함.** Cross-plugin 변경은 별도 의사결정.

## 4. Constraints

### 4.1 devbrew 철학

- **Law 1.** 본 spec 9개 필수 섹션 + concrete next action.
- **Law 2.** `security-reviewer.md` frontmatter에 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 명시. 다른 Phase 1 reviewer (codex-reviewer)와 동일 패턴.
- **Law 3.** 본 spec → plan → 구현 사이클 후 `plugin.json` bump + `CHANGELOG.md` entry + `README.md` agent inventory — auto-discoverable.

### 4.2 Plugin shape

- `cost_class: medium` 선언 (always-run × 4번째 agent — high는 과대평가, low는 OWASP-class depth 과소평가).
- Kill switch: `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`. SKILL.md가 Phase 1 dispatch 직전 체크하고 빠질 때 stderr에 loud log.
- `model: inherit` (memory: respect upstream model hardcoding — 다른 Phase 1 agent와 동일).
- Persona 파일은 보안-민감 — 약화 PR은 보안 리뷰 대상.

### 4.3 보안 — agent persona scope

In-scope (hunt categories — 상세 sink/sample은 agent persona 본문에서 다룸):

- Injection 계열 (SQL, NoSQL, command, template engine, directory query)
- Auth/Authz bypass (missing middleware, IDOR, privilege escalation, state-change에 CSRF token 누락)
- Secrets in code/logs (hardcoded credentials, PII가 에러 응답/로그에 노출, URL 안에 들어간 자격 증명)
- SSRF + path traversal (user URL이 server fetch에 흘러감, user path가 canonicalization 없이 fs에 도달)
- Insecure deserialization (untrusted bytes가 executable type을 deserialize하는 sink에 도달)
- Cryptographic misuse (보안 목적 weak hash, token 용도 약한 PRNG, secret 비교에 non-constant-time, hardcoded IV/key, missing salt)
- XSS escape hatch APIs (각 framework의 raw-render / mark-safe / unsafe-innerHTML류)
- Dependency manifest 변경 — finding으로 flag (CRITICAL/HIGH CVE 가능성 노출)

Out-of-scope (anti-flag — false positive 억제):

- Defense-in-depth on already-protected code
- 물리적 / 로컬 접근 필요한 이론적 공격
- Dev/test 전용 insecure transport (HTTP in tests)
- 구체적 finding 없는 generic hardening 추천 (rate limiting, CSP 등) — silent
- **Forced findings 금지** — diff에 보안 surface 없으면 빈 array. Padding 금지.

### 4.4 Confidence calibration

다른 reviewer와 동일한 anchored rubric, 단 **security-specific override**: P0 + anchor 50 always reports (보안 miss cost 큼). Anchor ≤25 suppress.

## 5. Acceptance Criteria

- **AC1.** `plugins/quality-gates/agents/security-reviewer.md` 존재. frontmatter 필수 필드: `name`, `description`, `model: inherit`, `cost_class: medium`, `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`.
- **AC2.** Persona 본문이 "You are X / responsible Y / NOT Z" 형식으로 시작 (Plugin Shape 의무). Persona는 §2 Goal 6의 canonical finding schema를 직접 emit하도록 명시 — 최소한 `agent: security-reviewer`, `file`, `line`, `severity` (CRITICAL|IMPORTANT|SUGGESTION), `confidence` (1–10), `summary`, `proposed_fix` 키를 포함하는 YAML list. **Forced findings 금지** 규칙이 persona 본문에 텍스트로 존재.

  검증 명령:
  ```bash
  grep -E 'agent: security-reviewer|severity:|confidence:|file:|line:' \
    plugins/quality-gates/agents/security-reviewer.md | wc -l
  # expected: >= 5 (5개 schema keyword가 persona에 등장)

  grep -E 'forced findings|Forced findings|빈 array|empty findings' \
    plugins/quality-gates/agents/security-reviewer.md | wc -l
  # expected: >= 1
  ```

- **AC3.** Scout (`agents/scout.md`)의 Phase 1 selection table 3개 tier 모두에 `security-reviewer` 포함. 검증 명령:
  ```bash
  # 1. quick tier에 포함
  grep -E '^\| quick \|.*security-reviewer' plugins/quality-gates/agents/scout.md
  # 2. standard tier에 포함
  grep -E '^\| standard \|.*security-reviewer' plugins/quality-gates/agents/scout.md
  # 3. deep tier에 포함
  grep -E '^\| deep \|.*security-reviewer' plugins/quality-gates/agents/scout.md
  # 모두 1 line match expected
  ```
  추가로 scout.md의 "Phase 1 selection" subset rule (line 84 부근 *"`phase1_agents` must be a subset of the table above for the chosen depth"*)이 새 catalog에 대해 깨지지 않는지 — table에 security-reviewer 추가 + selection list에 동시 반영되어 있는지 검증.

- **AC4.** SKILL.md (`skills/quality-pipeline/SKILL.md`) Phase 1 dispatch 섹션에 security-reviewer dispatch 프롬프트 추가 — Agent A/B/C와 동일 template 형식. 병렬 dispatch tool-call block에 포함. 검증 명령:
  ```bash
  grep -nE 'security-reviewer' plugins/quality-gates/skills/quality-pipeline/SKILL.md
  # expected: >= 3 matches (dispatch prompt + parallel block + section header)
  ```

- **AC5.** SKILL.md Phase 1 dispatch 직전 kill switch 체크 — `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`인 경우 dispatch list에서 빠지고 stderr에 disable log 1줄 emit. 검증 명령:
  ```bash
  grep -nE 'DEVBREW_DISABLE_QG_SECURITY_REVIEWER' plugins/quality-gates/skills/quality-pipeline/SKILL.md
  # expected: >= 1 match (kill switch 체크 코드)
  ```
  기존 codex-reviewer의 `DEVBREW_DISABLE_QG_CODEX` 패턴과 동일 형식.

- **AC6.** Fan-out 게이트 발화 검증 — `deep` depth + codex-reviewer 가용 (`QG_MOCK_CODEX_MANIFEST=available QG_MOCK_CONSENT_OK=1`) + security-reviewer 시, scout이 emit하는 `phase1_agents` list의 size + `external_reviewers` size + `phase2_agents` size 합이 ≥ 4가 되어 AskUserQuestion 게이트가 발화한다.

  검증: 기존 `plugins/quality-gates/tests/test_scout_codex_integration.sh` 패턴을 따라 mock fixture로 scout 호출 → output YAML 파싱 → 합산 ≥ 4 확인. 실제 AskUserQuestion 발화는 SKILL.md 로직이므로 SKILL.md 단위 테스트로 분리 가능 (또는 manual smoke만 수용).

- **AC7.** `plugin.json` version `1.12.0 → 1.13.0`. 검증: `jq -r .version plugins/quality-gates/.claude-plugin/plugin.json` 결과가 정확히 `1.13.0`.

- **AC8.** `CHANGELOG.md` 새 entry: `## [1.13.0] — 2026-05-16` with **Added** (security-reviewer agent), **Changed** (Phase 1 always-run scope expanded), kill switch 명시. 검증: `grep -n '## \[1.13.0\] — 2026-05-16' plugins/quality-gates/CHANGELOG.md` 1줄 매치.

- **AC9.** `README.md`의 agent inventory 섹션에 security-reviewer 한 줄 + kill switch env var 한 줄. "Principles Instantiated" Law 2 항목에 instantiation 추가. 검증: `grep -E 'security-reviewer|DEVBREW_DISABLE_QG_SECURITY_REVIEWER' plugins/quality-gates/README.md | wc -l` 결과 ≥ 2.

- **AC10a (structural — CI-blocking).** Persona 파일 자체가 canonical schema를 emit하도록 instruct되어 있고 forced-findings 금지 규칙이 textually 존재함을 AC2의 grep으로 검증 (AC2와 일부 중복 — AC10a는 schema-shape conformance를 명시적으로 분리하는 목적).

- **AC10b (integration smoke — opt-in, CI-non-blocking).** Fixture 파일 추가:
  - `plugins/quality-gates/tests/fixtures/security-reviewer/sql-concat/diff.patch` — SQL string-concat 형태의 trigger diff
  - `plugins/quality-gates/tests/fixtures/security-reviewer/clean/diff.patch` — 보안 surface 없는 styling-only diff
  - `plugins/quality-gates/tests/fixtures/security-reviewer/expected/sql-concat.schema.yaml` — 최소 expected schema shape (정확한 finding text 아닌 key 존재 + severity enum 만)

  Smoke test 정의: manual local 실행으로 `/qg` 호출 → sql-concat diff에서 ≥ 1 finding emit + clean diff에서 0 findings. LLM 비결정성으로 CI에서는 fail-tolerant. 회귀 알람은 manual 또는 별도 nightly job.

- **AC11.** Kill switch test (CI-blocking, deterministic) — Bash test:
  ```bash
  # plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh
  DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1 \
    bash -c 'source plugins/quality-gates/scripts/<dispatch-helper>.sh; echo "$phase1_agents"' \
    | grep -qv 'security-reviewer'  # dispatch list에 없어야 함
  ```
  실제 구현 시 SKILL.md의 kill switch 체크 로직을 helper script로 분리하거나, mock 환경에서 stderr에 disable log 1줄 발화 확인 (`grep "security-reviewer disabled"`).

- **AC12.** 기존 Gate 2 fixture / snapshot — Phase 1 agent count +1로 인한 expected output 업데이트. 다른 test 회귀 없음. 검증: `cd plugins/quality-gates/tests && for t in test_*.sh; do bash "$t" || echo "REGRESSION: $t"; done` 결과에 regression 없음.

## 6. Files to Modify / Create

### Create

- `plugins/quality-gates/agents/security-reviewer.md` — 새 agent (frontmatter + persona)
- `docs/superpowers/specs/2026-05-16-qg-security-reviewer-design.md` — 본 spec (이 파일)
- `plugins/quality-gates/tests/fixtures/security-reviewer/sql-concat/diff.patch` — trigger 케이스 fixture (SQL string-concat)
- `plugins/quality-gates/tests/fixtures/security-reviewer/clean/diff.patch` — non-trigger 케이스 (styling-only)
- `plugins/quality-gates/tests/fixtures/security-reviewer/expected/sql-concat.schema.yaml` — 최소 expected schema (key 존재 + severity enum)
- `plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh` — AC11 deterministic kill switch test

### Modify

- `plugins/quality-gates/agents/scout.md` — Phase 1 selection table에 security-reviewer 3 tier 모두 추가
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Phase 1 dispatch sequence에 security-reviewer prompt template + kill switch 체크
- `plugins/quality-gates/.claude-plugin/plugin.json` — version bump
- `plugins/quality-gates/CHANGELOG.md` — 1.13.0 entry
- `plugins/quality-gates/README.md` — agent inventory + kill switch env var + Principles Instantiated 갱신

## 7. Verification Plan

1. **Unit-level (fixture):** AC10/AC11 test fixture가 새 expected output snapshot에 맞춰 통과.
2. **Integration:** Local `/qg` 실행 — 의도적으로 보안 surface 있는 diff (SQL string concat) 만들고 security-reviewer가 finding을 emit 하는지 확인. 다음으로 docs-only diff에서 trivia escape가 Gate 2 자체를 우회하는지 확인.
3. **Kill switch:** disable env var 설정 후 `/qg` 실행 — stderr 로그 발화 + dispatch list 누락 확인.
4. **Fan-out gate:** `deep` depth + codex-reviewer 활성화 + security-reviewer 시 `len ≥ 4` 임계가 AskUserQuestion을 trigger하는지 확인.
5. **Regression:** 기존 fixture 전체 실행 — security-reviewer 추가 외 변경 없음 확인.

## 8. Rejected Alternatives

- **Phase 2 conditional dispatch.** 처음 제시한 옵션. compound-engineering 패턴을 그대로 차용하면 cost 최적. 거절 이유: 보안 miss 비용이 dispatch overhead보다 크고, 사용자가 always-run 결정. Trivia escape가 trivial diff cost를 이미 흡수.
- **`pr-review-toolkit:code-reviewer` mission에 보안 강조 추가.** Cross-plugin 편집 필요 + specialist depth 분리 실패. 거절.
- **OWASP 풀체크리스트 강제 (oh-my-claudecode 패턴).** Persona가 비대해지고 false-positive 증가. 거절. Anchor-based confidence + forced-findings 금지 규칙으로 대체.
- **`model: opus` 하드코딩.** memory: respect upstream model hardcoding. inherit 유지.
- **Kill switch 없이 hard-always-run.** Plugin Shape 위반. 거절.
- **새 P# 추가.** memory: devbrew designs default to lightness. Law 2 instantiation으로 충분.

## 9. Concrete Next Action

이 spec 승인 후, `superpowers:writing-plans` skill로 implementation plan을 작성. Plan은 다음 순서를 단계화:

0. **사전 schema 확인** — `adversarial.md:22-30`과 `synthesizer.md` 그리고 `scripts/codex_findings_to_yaml.py`를 다시 한 번 확인하여 finding YAML schema의 모든 키와 enum value (CRITICAL/IMPORTANT/SUGGESTION, confidence 1–10) 가 정확한지 plan 단계에서 lock-in. spec-reviewer round 1에서 anchor로 fix했지만 plan은 이를 코드 inspection으로 한 번 더 확정.
1. `agents/security-reviewer.md` 작성 (persona + frontmatter) — schema emit 의무를 persona 본문에 텍스트로 명시 (key list + forced findings 금지 규칙)
2. `agents/scout.md` Phase 1 selection table 업데이트 — 3개 tier에 security-reviewer 추가 + Phase 1 catalog 리스트도 동시 갱신
3. `skills/quality-pipeline/SKILL.md` Phase 1 dispatch + kill switch 패치 — 기존 codex-reviewer 패턴 (`DEVBREW_DISABLE_QG_CODEX`) 미러링
4. Test fixture 4개 추가 (sql-concat/diff.patch + clean/diff.patch + expected/sql-concat.schema.yaml + test_security_reviewer_kill_switch.sh)
5. `plugin.json` / `CHANGELOG.md` / `README.md` 갱신
6. Local 검증 — AC2/AC3/AC4/AC5/AC7/AC8/AC9 grep assertion + AC11 bash 테스트 + AC12 회귀 테스트. AC10b는 manual smoke로 별도 수행.

## 10. Metadata

- **Spec ID:** qg-security-reviewer-v1
- **Related plugins:** `quality-gates` (touched), `pr-review-toolkit` / `feature-dev` (untouched but referenced in dispatch)
- **Reference sources used:**
  - `reference/compound-engineering-plugin/plugins/compound-engineering/agents/ce-security-reviewer.agent.md`
  - `reference/oh-my-claudecode/agents/security-reviewer.md`
  - `reference/gstack/review/specialists/security.md`
- **devbrew Laws instantiated:** Law 1 (이 spec), Law 2 (`disallowedTools` + persona-as-security-sensitive), Law 3 (CHANGELOG + README compounding).
- **Forbidden patterns avoided:** Self-approval (separate writer/reviewer turn), Polite stop (next action concrete), Trivia ceremony (Gate 2 trivia escape preserved), Subagent spray (Phase 1 catalog at 4, fan-out gate ≥ 4 triggers user consent), Unbounded autonomy (kill switch present).
