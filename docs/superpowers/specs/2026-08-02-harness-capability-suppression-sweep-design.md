# 하니스 능력 억제 제거 sweep — 설계

> *"하네스를 결정론적으로 가는건 좋은데 너무 옥죄면 성능 저하가 될 수 있어. 하네스를 가능하다면 가볍게 가져가고 모델을 믿을수도 있어야해."*
> — 사용자, 2026-06-07
>
> **절대 조항**: *"하니스를 무겁게 만들어서 능력을 제한하는 것은 절대 안 된다."* — 사용자, 2026-07-26

devbrew의 모든 컨텍스트 표면에서 하니스가 모델(Claude·codex)의 능력을 정당한 이유 없이 깎는 지점을 제거한다.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. 판별 기준과 census 결과](#5-판별-기준과-census-결과)
- [6. 설계 — 5단계](#6-설계--5단계)
- [7. Acceptance Criteria](#7-acceptance-criteria)
- [8. Files to Modify](#8-files-to-modify)
- [9. Verification Plan](#9-verification-plan)
- [10. Rejected Alternatives](#10-rejected-alternatives)
- [11. 이 사이클에서 제외 — 별건 목록](#11-이-사이클에서-제외--별건-목록)
- [12. Metadata](#12-metadata)

---

## 1. Context / Why

**원칙은 이미 있다 — 실행이 어긋났다.** `docs/philosophy/devbrew-harness-philosophy.md:75`(P8 Determinism
Economy)가 이미 *"결정론 장치는 모델 신뢰가 불충분하고 오류 비용이 높을 때, 즉 load-bearing일 때만
정당하다"* 고 쓴다. 그런데 같은 문서 `:63`(P22)은 *"N≥5는 hard gate"*, `:96`(AP9)은 *"single-agent가
default다"* 를 load-bearing 판정 없이 규약화한다. 이 작업은 **새 원칙 추가가 아니라 기존 원칙 위반
사례의 제거**다.

발단은 2026-07-26 세션에서 작성자(모델)가 codex의 웹 검색에 상한을 박으려 했고 사용자가 교정한
사건이다. 이번 census는 **같은 클래스가 이미 세 개 스크립트에 shipping돼 있었음**을 확인했다
(`model_reasoning_effort="medium"`). 잡힌 것은 시도였지만 코드에는 이미 있었다.

### 1.1 측정된 손실 (가정이 아님)

과거 세션 트랜스크립트에서 부모 세션 모델과 subagent 실제 실행 모델을 대조했다:

| agent | frontmatter | 부모 세션 | **실제 실행** | 관측 |
|---|---|---|---|---|
| `spec-distill:spec-reviewer` | `model: sonnet` | claude-opus-5 | **claude-sonnet-5** | 6회 (07-25~27) |
| `spec-distill:steelman-builder` | `model: sonnet` | claude-opus-5 | **claude-sonnet-5** | 1회 (07-26) |
| `quality-gates:test-scope-validator` | `model: sonnet` | claude-opus-4-8 | **claude-sonnet-5** | 2회 (07-02, 07-07) |
| `quality-gates:adversarial` | `model: opus` | claude-opus-5 | claude-opus-5 | 3회 (07-26~29) |
| `plugin-audit:plugin-auditor` | `model: inherit` | claude-opus-5 | claude-opus-5 | 이번 census |

**sonnet 핀은 실측된 활성 손실이다** — 지난 일주일 spec-review 6회 전부 opus-5 세션이 sonnet-5
리뷰어를 받았다. 리뷰어가 writer보다 약한 상태가 매 dispatch 재현됐다.

**opus 핀은 오늘 손실 0이다** — `opus` 별칭이 세션 세대를 따라간다. 남는 것은 잠재적 상한뿐이다.
같은 결론(REMOVE)이라도 근거 강도가 다르므로 분리해 기록한다 — 뭉개면 약한 논거가 강한 논거를
함께 끌어내린다.

### 1.2 인과 사슬

`blind-spot-prober.md:40`은 웹 검색을 *"1–2회 … **순차 호출**(병렬·투기적 금지, **C5/AP9**)"* 로
묶으면서 **AP9를 근거로 인용한다**. 즉 철학 doc의 규약이 agent 프롬프트까지 내려와 실제로 검색을
2회로 제한하고 있다. 규약 수정(S4)과 프롬프트 수정(S3)은 같은 결함의 두 끝이다.

## 2. Goals

1. `plugins/*`의 모든 `model:` 리터럴 핀을 `model: inherit`으로 정규화하고, 그 핀을 강제하던 테스트
   락을 **양방향 락으로 반전**한다.
2. codex 호출에서 능력 상한(`model_reasoning_effort`)을 제거하되 보안 플래그(`-s read-only`, `-C`)와
   파싱 계약(`--json`)은 보존한다.
3. 조사가 본질인 역할의 도구 결핍(WebSearch 부재 비대칭)을 해소한다.
4. 단일 호출에 씌운 횟수 상한과 탐색 폭을 좁히는 프롬프트 문구를 제거한다.
5. `CLAUDE.md`·philosophy의 규약화된 억제를 **P8 쪽으로 정렬**한다 (새 P# 추가 없이).
6. 억제를 지시하는 메모리를 수정하고, 과거 기록에는 정정을 append한다.
7. 재도입을 막는 회귀 락을 mutation으로 이빨을 증명해 남긴다.

## 3. Non-goals

- **새 원칙(P#) 추가.** devbrew의 default는 기존 원칙 흡수다. 이 sweep의 판별 기준은 이미 P8이다.
- **Law 2 완화.** 리뷰어 `tools:` allowlist에서 쓰기·실행 도구 부재는 이 sweep의 대상이 아니라 전제다.
- **allowlist → denylist 전환.** allowlist는 공간에, denylist는 *시간*에 fail-open이다.
- **fail-open·정확성 결함 수정.** sweep의 반대 방향이므로 §11로 분리한다.
- **격리 해제.** `brief-critic`/`brief-readback`의 `tools: []`, `pr-understanding-builder`의 inert
  `Read`, `runtime-verifier`의 `Write`는 실험 설계이지 억제가 아니다.

## 4. Constraints

- **C1 — 유지선(약화 금지).** Law 2 물리 분리 · kill switch(`DEVBREW_DISABLE_*`) · qg mutation
  guard/digest seal · 정확성 게이트(fail-closed exit, bijection) · 입력 격리.
- **C2 — 기록 vs 활성 규칙.** 미래 세션이 *규칙으로* 읽는 표면은 고치고, *이력으로* 읽는 표면
  (append-only 원장 · 머지된 design/plan · CHANGELOG)에는 정정을 append한다. 통째 제거는 하지 않는다.
- **C3 — 사용자 결정 (2026-08-02, 이 세션에서 확정).**
  - `web_budget.py` 상한 → **제거** (kill switch는 유지)
  - fan-out 조항 → **숫자 임계(N≥5) 제거, 비용 승인 게이트 서술만 유지**
  - `security-reviewer` 웹 도구 → **추가하지 않음** (P21 exfiltration이 실재하는 load-bearing 근거)
  - `adversarial`의 신규 발견 → **승격 허용** (`source: adversarial`로 출처 구분)
  - project-init 템플릿의 rebase 절대 금지 → **템플릿만 완화**, 리포 루트는 사용자 선호로 유지
  - 판정이 갈리면 **default는 유지가 아니라 제거** ("룰은 최대한 들어내는 방향")
- **C4 — 플러그인을 건드리는 커밋마다** `plugin.json` SemVer bump + `CHANGELOG.md` 항목 (devbrew 규약).
- **C5 — 회귀 락은 mutation으로 이빨을 증명**한다. 헤더·주석에만 있어도 통과하는 락은 가짜다.

## 5. 판별 기준과 census 결과

### 5.1 판별식

> **"이 줄을 지우면 무엇이 조용히 통과하게 되는가?"**

답이 "없음"이면 그 줄은 순수 무게다. 답이 "틀린 결과 / 자기승인 / 검증 안 된 scope"면 load-bearing이다.

teethless check의 판별식은 별도다: **"이 검사를 통과시키는 데 필요한 것이 검사 대상 자신이 쓰는 한
줄인가?"** 그렇다면 이빨이 없다. 단, 한계를 명시하고 별도 수동 검증으로 분리한 경우는 올바른
처리다 (`check_brief.py`의 `evidence: S<N>` 앵커가 그 선례).

### 5.2 census 방법과 결과

읽기전용 10축 병렬 조사(`plugin-audit:plugin-auditor`, `tools: Glob, Grep, Read, WebSearch, WebFetch`
— Bash·Write 물리적 부재) → 3슬라이스 양방향 반증(`plugin-audit:audit-refuter`). 슬라이스는 축이
아니라 라운드로빈으로 나눠 finder와 refuter가 같은 프레이밍을 공유하지 않게 했다.

- 총 **110 findings** + refuter 추가 **14건**
- 최종 분류: REMOVE 36 · KEEP 35 · USER_DECISION 37 · FALSE_POSITIVE 2
- **refute가 10건의 분류를 뒤집었다** — 8건을 KEEP으로 되돌리고(load-bearing 오분류 방지), 2건을
  REMOVE로 승격했다. 2건은 사실 주장 자체가 틀려 기각됐다.

reference 구현은 `plugins/plugin-audit/agents/*.md` 3개 — `model: inherit` + 조사 도구 보유로
이 축에서 결함 0건이었다.

### 5.3 리포가 이미 가진 올바른 패턴 (발명이 아니라 전파)

1. **양방향 모델 락** — `plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh:11-12`:
   `ag '^model: inherit$'` + `ng '^model: (opus|sonnet|haiku)'`
2. **단일호출 상한 금지 락 (E10)** — `plugins/spec-distill/tests/test_brief_agents.sh:194`:
   `grep -qE '최대 [0-9]+회|[0-9]+회까지|max_[a-z_]+ *= *[0-9]'` → FAIL
3. **조사 도구 보유** — `plugins/plugin-audit/agents/*.md`

## 6. 설계 — 5단계

각 단계는 독립 커밋이다. 순서는 핸드오프 §4의 지시(모델 핀 → 도구 표면 → 상한)를 따른다.

### S1 — 모델·추론 핀

**변경**: agent frontmatter 7개를 `model: inherit`으로. codex 실행 스크립트 3개에서
`-c 'model_reasoning_effort="medium"'` **플래그만** 삭제 — `-s read-only`(샌드박스)·`-C`(작업디렉토리
핀)·`--json`(파싱 계약)은 유지. 서술 3곳 동기화.

**락 반전 (핵심)**: 핀의 실제 이빨은 frontmatter가 아니라 테스트다. 5개 락을 §5.3 ①패턴으로 반전한다.
반전하지 않으면 frontmatter만 고쳐도 스위트가 RED가 되어 변경이 되돌려진다.

### S2 — 조사 도구 결핍

`spec-reviewer`에 `WebSearch` 추가 — 현재 `WebFetch`만 있어 *URL은 열 수 있는데 찾을 수는 없는*
비대칭이다. `coverage-mapper`에 `WebSearch, WebFetch` 추가. 정확일치 락 2개를 갱신한다.

**`security-reviewer`는 추가하지 않는다** (C3). 대신 :38의 문구를 고쳐 "CVE 미판정"을 약점이 아니라
**명시된 한계**로 기록하게 한다 — `check_brief.py` evidence 앵커의 한계 명시 선례와 같은 처리다.

### S3 — 단일호출 상한·탐색 좁힘

- `blind-spot-prober`·`steelman-builder`의 *"1–2회"* 상한과 *"병렬·투기적 금지"* 삭제
- `test-scope-validator:39`의 허용 컨텍스트 열거에 `spec_path` 추가 — 현재 :46이 spec을 *"PRIMARY
  reference axis"*로 선언하는데 :39의 허용 목록에서 빠져 있어 **자기모순**이다
- `build_spec_codex_prompt.py`의 *"SIX judgment categories only"* 를 개방 (스키마는 유지하되 범주 추가)
- **`web_budget.py` 제거** + 호출부(`conducting-interview/SKILL.md`) + 락 + 문서 정리.
  근거: 인터뷰 루프의 상한은 `probe_budget.py`(12 + raise-cap escape hatch)가 이미 담당하므로
  web 상한은 중복이고, 실질 효과는 인터뷰의 핵심 값인 landscape 조사 깊이를 깎는 것뿐이었다.
- `adversarial.md:149` — 신규 발견의 finding 승격 허용, `source: adversarial`로 출처 구분 (C3)

### S4 — 규약 정렬

| 위치 | 조치 |
|---|---|
| `CLAUDE.md:43` · philosophy `:63` | *"Fan-out factor N ≥ 5는 hard review 게이트"* 삭제. `cost_class: high` 승인 게이트는 **유지** (비용 동의는 P17 load-bearing) |
| `CLAUDE.md:68` · philosophy `:96` | *"single-agent를 default로"* 삭제. *"선언 없는 fan-out"* 이 anti-pattern이라는 부분은 유지 |
| `CLAUDE.md:69` | *"wall-clock budget"* 필수 삭제 — spec-distill v0.17.0이 *"사람 숙고시간 오측정 footgun"* 으로 이미 제거했다. 규약이 플러그인이 폐기한 것을 요구하는 상태 |
| philosophy `:20` | *"모델 성능이 향상돼도 이 메커니즘은 불변이다"* 를 완화 — 현재 비용 임계치까지 재평가 불가로 선언해 **이 sweep 자체를 규칙 위반으로 읽게 만든다** |
| philosophy `:43` | trivia escape의 *single-file* 제약 완화 — 두 파일 이상의 한 줄 변경(오타 3곳, symbol rename)에 full 게이트를 강제해 스스로 금지한 trivia ceremony를 요구한다 |
| `docs/plugin-authoring.md` | `model: inherit` 규약을 명시 — 신규 플러그인이 reference 구현의 리터럴 핀을 복제하는 것을 차단 |
| project-init 템플릿 | rebase 조항을 *"공유된 브랜치를 rebase하지 않는다"* 로 완화 (C3). 리포 루트 `docs/git-workflow/`는 사용자 선호로 **유지** |

### S5 — 메모리 + 과거 기록

- `feedback_respect_upstream_model_hardcoding.md` — :9의 무한정 일반 명제에 **범위 명시**(외부 플러그인
  한정)를 넣고, :14의 *"`model: inherit`이면 sonnet으로 override 가능"* 권장을 삭제한다. 이 줄은
  스윕이 없애려는 행위를 how-to로 처방하고 있다.
- `project_spec_distill_interview_coverage_driven.md:24` — writer를 sonnet으로 처방한 부분 정정
- `MEMORY.md` 인덱스 동기화
- **historical (append only)**: `2026-07-16-law2-agent-tool-surface-design.md`,
  `2026-07-20-spec-distill-interview-coverage-driven` plan/design에 사후 반증 문단 추가

## 7. Acceptance Criteria

- **AC1** `grep -rn '^model:' plugins/ | grep -v inherit` 이 0건.
- **AC2** 3개 codex 실행 스크립트의 `codex exec` 인자에 `model_reasoning_effort`가 **실행 인자로**
  남아 있지 않으면서, 같은 스크립트에 `-s read-only`와 `-C`가 그대로 존재한다. (회귀 락 테스트가
  "핀이 없어야 한다"를 assert하기 위해 그 문자열을 언급하는 것은 위반이 아니다 — AC는 실행 경로에
  대한 것이다.)
- **AC3** `spec-reviewer`·`coverage-mapper`의 `tools:` 에 `WebSearch`가 있고, 쓰기·실행·MCP 도구는 없다.
- **AC4** `security-reviewer`의 `tools:` 는 변경되지 않는다 (`Read, Grep, Glob`).
- **AC5** `blind-spot-prober`·`steelman-builder` 본문에 검색 횟수 상한 표현과 병렬 금지 문구가 없다.
- **AC6** `test-scope-validator:39`의 허용 열거에 `spec_path`가 포함된다.
- **AC7** `web_budget.py`가 삭제되고, 이를 호출하던 지점과 테스트가 함께 정리되며,
  `DEVBREW_SPEC_DISTILL_DISABLE_WEB` kill switch는 계속 동작한다.
- **AC8** `CLAUDE.md`·philosophy에 `N ≥ 5`·`single-agent를 default`·`wall-clock` 문구가 없고,
  `cost_class: high` 승인 게이트 문장은 남아 있다.
- **AC9** 모든 회귀 락이 **양방향**이고, 각 락에 대해 mutation(핀 재도입)이 RED를 만든다.
- **AC10** 변경 후 테스트 스위트의 red가 baseline 6건을 초과하지 않는다.
- **AC11** dispatch 실측으로 (a) `inherit` 에이전트가 세션 모델을 상속하고, (b) `spec-reviewer`가
  `WebSearch`를 실제로 호출할 수 있음을 **트랜스크립트로** 확인한다 (자기보고 불가).
- **AC12** 각 플러그인의 `plugin.json` version bump + `CHANGELOG.md` 항목이 같은 커밋에 있다.

## 8. Files to Modify

**agents (7)** — `quality-gates/agents/{adversarial,pr-understanding-builder,test-scope-validator}.md` ·
`spec-distill/agents/{blind-spot-prober,steelman-builder,coverage-mapper,spec-reviewer}.md`
(+ `security-reviewer.md`는 :38 문구만)

**scripts (5)** — `quality-gates/scripts/{run_codex_reviewer.sh,run_artifact_codex_reviewer.sh}` ·
`spec-distill/scripts/{run_spec_codex_reviewer.sh,build_spec_codex_prompt.py}` ·
`spec-distill/scripts/web_budget.py` (삭제)

**skills / commands (4)** — `spec-distill/skills/conducting-interview/SKILL.md` ·
`quality-gates/skills/publishing-pr-understanding/SKILL.md` ·
`quality-gates/skills/quality-pipeline/references/{dependency-check,state-file-format}.md`

**tests (8)** — `quality-gates/tests/{test_adversarial_model_consistency,test_adversarial_persona,test_pr_understanding_builder_frontmatter,test_test_scope_validator_frontmatter}.sh` ·
`spec-distill/tests/{test_spec_reviewer_frontmatter,test_coverage_mapper_frontmatter,test_web_sweep_bound,test_run_spec_codex_reviewer}.sh`

**docs / 규약 (6)** — `CLAUDE.md` · `docs/philosophy/devbrew-harness-philosophy.md` ·
`docs/plugin-authoring.md` · `quality-gates/README.md` · `spec-distill/README.md` ·
`project-init/templates/github-flow/branch-strategy.md`

**메타 (6)** — 3× `plugin.json` + 3× `CHANGELOG.md` (quality-gates · spec-distill · project-init).
`plugin-audit`은 이 sweep에서 변경 대상이 아니다 — 이미 reference 구현이다.

**메모리 (3)** — `feedback_respect_upstream_model_hardcoding.md` ·
`project_spec_distill_interview_coverage_driven.md` · `MEMORY.md`

## 9. Verification Plan

1. **baseline 대비** — 변경 전 `e45619b`: bash 128개 중 6 red (전부 pre-existing, quality-gates),
   python 189+95 green. 변경 후 red가 6을 넘으면 내가 만든 회귀다.
2. **mutation으로 락 이빨 증명** — 각 양방향 락에 대해 `model: opus`를 되돌려 넣고 RED를 확인한 뒤
   revert. green-expected 락은 모양으로 이빨을 판별할 수 없다.
3. **dispatch 실측** — 변경 후 `spec-reviewer`를 1회 dispatch하고
   `~/.claude/projects/.../subagents/agent-*.jsonl`에서 `"model":"claude-opus-5"`와
   `"name":"WebSearch"` tool_use를 확인한다. 프론트매터에 적혔다는 것은 런타임 반영의 증거가 아니다
   (레지스트리 스냅샷 함정 — 세션 재시작이 필요할 수 있다).
4. **Law 2 무손상** — 전 리뷰어 에이전트의 `tools:` 에 `Write|Edit|MultiEdit|Bash|Agent|Monitor|mcp__`
   가 없음을 기계 검증.
5. **`/qg branch`** — 별-모델(codex) 포함 리뷰. 리포가 반복 실증한 대로 same-family 리뷰어들이
   공유 맹점을 갖기 때문이다.

## 10. Rejected Alternatives

- **`web_budget.py`를 승인 게이트로 전환** — 핸드오프 §1이 제시한 처방이고 비용 동의를 보존하지만,
  게이트 기계장치가 새로 늘어난다. 루프 상한을 `probe_budget.py`가 이미 담당하므로 제거가 더 가볍다.
  *사용자가 제거를 선택했다.*
- **`security-reviewer`에 웹 도구 추가** — 절대 조항에 가장 충실하지만, 전체 소스를 읽는 에이전트에
  네트워크 egress를 여는 것이라 P21 exfiltration 반론이 실재한다. **이 sweep에서 유지 쪽이
  load-bearing 근거를 실제로 댈 수 있는 유일한 항목**이다. *사용자가 미추가를 선택했다.*
- **fan-out 조항 전량 삭제** — 가장 가볍지만 선언 없는 대규모 fan-out에 대한 비용 가시성까지 잃는다.
  *사용자가 "승인 게이트만 남기고 상한 프레임 제거"를 선택했다.*
- **철학 doc에 새 P# 추가** — 판별 기준을 새 원칙으로 못 박는 안. devbrew의 default는 기존 원칙
  흡수이고, 이 기준은 이미 P8이 담고 있다. 새 원칙을 더하는 것 자체가 이 sweep이 줄이려는 무게다.
- **한 커밋으로 일괄 수정** — 리뷰 가능성이 무너진다. 핸드오프 §4가 명시적으로 금지한다.

## 11. 이 사이클에서 제외 — 별건 목록

census가 발견했으나 **sweep의 반대 방향**(억제가 아니라 구멍)인 결함들이다. 섞으면 리뷰가 흐려지므로
분리한다. 별도 사이클에서 다룬다.

| ID | 위치 | 결함 |
|---|---|---|
| CHECKS-01 | `spec-distill/scripts/parse_spec_structure.py:45` | 코드 펜스 안에 인용된 헤더 한 줄로 Law 1 구조 게이트가 만족됨 (fail-open) |
| CHECKS-02 | `parse_spec_structure.py:162` | 단어 경계(`\b`) 없는 부분문자열 매칭 — blacklist 항목이 그것을 포함하는 정상 기술 용어 안에서 발화한다 (git의 `~fast`-forward, 부정 접두사가 붙은 `in`+`~efficient`). **이 표를 처음 쓸 때 실제로 발화해 write가 exit 2로 차단됐다** — 위 두 예시는 검사기 자신의 opt-out 마커 `~`를 붙여야만 기록할 수 있었다 |
| CHECKS-03 | `plugin-audit/scripts/check-shape-completeness.py:100` | frontmatter가 없는 agent도 본문의 `tools:` 한 줄로 Law 2 검사 통과 |
| CHECKS-04 | 같은 파일 `:175` | kill switch를 docstring에 **적기만** 한 훅이 통과 |
| CHECKS-05 | `quality-gates/scripts/check-changelog-korean-primary.py:77` | 얼어붙은 `[1.32.0]` 절만 검사 — 이후 항목에 발화하지 않음 |
| CHECKS-06 | `quality-gates/scripts/synthesize_findings.py:180` | `--show-low-confidence` 가 리포 어디에도 구현돼 있지 않아 findings가 영구 은닉됨 |
| CHECKS-07 | 같은 파일 `:70` | 같은 file:line·severity의 서로 다른 지적을 접으며 **허위 귀속** 발생 |
| SDSKILL-06 | `spec-distill/skills/reviewing-brief/SKILL.md:104` | 리포 밖(마켓플레이스 설치 시) 참조 파일 부재로 brief 리뷰 파이프라인 전체가 degrade |

## 12. Metadata

- **작성일** 2026-08-02
- **브랜치** `fix/harness-capability-suppression-sweep`
- **baseline** `e45619b`
- **근거 문서** `docs/handoffs/2026-07-26-harness-capability-suppression-sweep.md`
- **census 산출** 13 에이전트 / 110 findings + 14 / 2,077,370 subagent tokens / 41분
- **관련 원칙** P8 (Determinism Economy) · P17 (User Sovereignty) · P21 (Security & Supply Chain)
- **선행 기록** `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` (`tools: []` 격리 실측)
