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
  - [9.1 Mutation 시나리오](#91-mutation-시나리오--각-락이-무엇에-반응해야-하는가)
  - [9.2 AC11 dispatch 실측 절차](#92-ac11-dispatch-실측-절차)
- [10. Rejected Alternatives](#10-rejected-alternatives)
  - [10.1 Rollout 구조 — 3안 비교](#101-rollout-구조--3안-비교-후-선택)
- [11. 이 사이클에서 제외 — 별건 목록](#11-이-사이클에서-제외--별건-목록)
- [Handoff Context](#handoff-context)
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

각 goal은 **기계적 판별 질의**를 갖는다. 질의가 없으면 완료 여부가 census가 미리 고른 목록과
독립적으로 측정되지 않는다 — 그러면 "다 했다"는 주장이 곧 "내가 고른 것만 했다"가 된다.
질의에 매칭되는 항목은 **전부 변경되거나, load-bearing으로 문서에 명시 정당화**돼야 한다 (AC13).

| # | Goal | 판별 질의 (repo 전역) |
|---|---|---|
| 1 | `model:` 리터럴 핀을 `inherit`으로 정규화하고, 그 핀을 강제하던 테스트 락을 **양방향으로 반전** | `grep -rn '^model:' plugins/ \| grep -v inherit` 그리고 `grep -rln 'model: *\(opus\|sonnet\|haiku\)' plugins/*/tests/` |
| 2 | codex 호출의 능력 상한 제거, 보안 플래그(`-s read-only`·`-C`)와 파싱 계약(`--json`)은 보존 | `grep -rn 'model_reasoning_effort\|codex exec' plugins/*/scripts/` |
| 3 | 조사가 본질인 역할의 도구 결핍 해소 | `plugins/*/agents/*.md` 중 본문이 web 근거·prior-art·landscape·CVE 조회를 **요구**하면서 `tools:`에 `WebSearch`가 없는 것. `WebFetch`만 있고 `WebSearch`가 없는 비대칭은 자동 후보 |
| 4 | 단일 호출 횟수 상한과 탐색 폭을 좁히는 문구 제거 | `grep -rnE '최대 [0-9]+회\|[0-9]+회까지\|[0-9]–[0-9]회\|max_[a-z_]+ *= *[0-9]\|병렬.{0,6}금지\|only\b.*categories' plugins/*/agents/ plugins/*/scripts/ plugins/*/skills/` (spec-distill E10 락의 패턴을 확장) |
| 5 | `CLAUDE.md`·philosophy의 규약화된 억제를 **P8 쪽으로 정렬** (새 P# 추가 없이) | `CLAUDE.md`·`docs/philosophy/*.md`·`docs/plugin-authoring.md`에서 숫자 임계·기본값 편향·필수 예산을 규정한 문장 전수 |
| 6 | 억제를 지시하는 메모리 수정, 과거 기록에는 정정 append | memory dir 전수 중 `type: feedback`이면서 모델·도구·탐색 폭을 **줄이라고 지시**하는 것 |
| 7 | 재도입을 막는 회귀 락을 **mutation으로 이빨을 증명**해 남김 | 각 신규/수정 락에 대해 억제를 되돌리는 mutation이 RED를 만드는지 |

**질의의 한계를 명시한다** (이 sweep의 판별식을 자기 자신에게 적용):

- **goal 1의 두 번째 질의(`plugins/*/tests/`)는 완료 판정에 쓸 수 없다** (round-2 리뷰 적발).
  올바르게 반전된 락도 금지 문자열을 **부정 assert의 인자로 명시해야** 하므로
  (`assert_not_grep "$AGENT" '^model: sonnet$'`), 이 질의는 반전 전후 모두 같은 파일들을 반환한다 —
  *"아직 핀을 강제함"* 과 *"이제 핀을 금지함"* 을 구분하지 못한다. 이것은 이 리포가 이미 문서화한
  **grep-lock header-satisfiable 함정**이 회귀 락이 아니라 *완료 오라클 자체*에 적용된 형태다.
  따라서 이 질의는 **후보 열거(triage) 도구**이고, 락의 방향을 실제로 판정하는 것은 **AC9의
  mutation**뿐이다 — 억제를 되돌려 넣었을 때 RED가 나는지가 유일한 판별자다.
  (goal 1의 *첫* 질의 `grep -rn '^model:'`는 `^model:` 줄-시작 앵커라 실제 frontmatter만 잡으므로
  영향받지 않는다. goal 2의 `codex exec` 질의도 같은 성질이라 육안 확인이 필요하다.)
- goal 3·5·6의 질의는 어휘가 아니라 판단을 요구하므로 완전 기계화가 불가능하다. 따라서 이 세 항목은 **census 원장
(`docs/audits/`에 보존)을 근거 목록으로 삼고, 후속 세션이 재현할 수 있도록 census 방법을 §5.2에
기록**한다. 이것은 결함이 아니라 명시된 한계다 — `check_brief.py`의 `evidence: S<N>` 앵커가
존재만 검사하고 그 한계를 spec에 적어 별도 수동 검증으로 분리한 것과 같은 처리다.

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

S3은 **독립 커밋 6개**로 쪼갠다 (codex 리뷰: 하나의 구현 단위가 아니다). 각각 별도 AC를 갖고
서로를 블록하지 않는다 — 하나가 막히면 나머지는 진행한다.

| 하위 | 내용 | AC |
|---|---|---|
| **S3a** | 검색 횟수 상한·병렬 금지 문구 제거 (`blind-spot-prober`·`steelman-builder`) | AC5 |
| **S3b** | `test-scope-validator`의 허용 컨텍스트 자기모순 해소 | AC6 |
| **S3c** | codex 범주 개방 + 하류 계약 | AC16 |
| **S3d** | `web_budget.py` 상한 제거 + kill switch 이전 (소비자 2곳) | AC7a–d |
| **S3e** | `adversarial` 신규 발견 승격 (persona 4곳 + synthesizer 배선) | AC14a–c |
| **S3f** | ambiguity 매칭 단어경계 | AC15 |

- `blind-spot-prober`·`steelman-builder`의 *"1–2회"* 상한과 *"병렬·투기적 금지"* 삭제
- `test-scope-validator:39`의 허용 컨텍스트 열거에 `spec_path` 추가 — 현재 :46이 spec을 *"PRIMARY
  reference axis"*로 선언하는데 :39의 허용 목록에서 빠져 있어 **자기모순**이다
- `build_spec_codex_prompt.py`의 *"SIX judgment categories only"* 를 개방한다. **범주 계약을
  명시한다**: 기존 6개는 그대로 두고 `other`를 추가하며, `other`를 쓸 때는 `summary`가 스스로
  설명하도록 요구한다. 하류 소비자는 이미 이 확장을 견딘다 — `merge_review.py`는 codex의
  `category`를 **닫힌 열거로 필터하지 않고 자유 문자열로 통과**시키고(BUDGET 축 census가 확인),
  `compute_issue_id.py`는 category를 id 해시 입력으로만 쓴다. 따라서 파서 변경은 불필요하고,
  회귀 락이 "6개로 닫혀 있지 않음 + 미지 범주가 drop되지 않음"을 assert한다 (AC16).
- **`web_budget.py`의 상한 제거** — **소비자가 둘이므로 단순 삭제가 아니다** (round-1 리뷰 적발):

  | 소비자 | 계측 단위 | `probe_budget.py`가 대체하는가 |
  |---|---|---|
  | `conducting-interview/SKILL.md:289,299` | 웹 호출 단위 | **예** — probe 12 + `raise-cap` escape hatch |
  | `reviewing-brief/SKILL.md:174,189` | **dispatch 단위** | **아니오** — `probe_budget.py`는 conducting-interview에서만 참조된다 |

  두 번째 소비자는 `brief-direction-reviewer`가 `Bash`를 갖지 않아(Law 2) orchestrator가 대신
  재는 구조다. 그리고 kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB`이 `web_budget.py:91,134`
  **내부에** 구현돼 있다. 따라서 조치는:
  1. `SWEEP_CAP`·`SESSION_CAP`과 그에 기반한 **게이트(exit 1) 제거** — 상한이 사라진다.
  2. **kill switch는 두 소비자 각각의 인라인 env 체크로 이전**한다 (`check_brief.py:71`이 이미
     쓰는 패턴). 보안 컨트롤이 스크립트와 함께 사라지면 안 된다 (C1).

     **kill switch 계약** (codex 리뷰 2라운드 연속 지적 — 인라인 복제는 계약이 명시돼야 안전하다):

     | 항목 | 규정 |
     |---|---|
     | 변수 | `DEVBREW_SPEC_DISTILL_DISABLE_WEB` |
     | 참으로 취급하는 값 | **정확히 문자열 `"1"`** 하나만. `true`·`yes`·`0`·빈 문자열은 전부 거짓 |
     | 미설정 시 | 웹 **활성** (fail-open이 맞다 — 이건 사용자가 켜는 스위치이지 안전 기본값이 아니다) |
     | 평가 시점 | 각 웹 작업 **직전**. 세션 시작 시 한 번 읽어 캐시하지 않는다 |
     | 적용 범위 | 그 소비자가 수행하는 모든 웹 작업 — 일부만 막으면 스위치가 거짓말이 된다 |
     | 소유 | 각 소비자가 자기 경로를 책임진다. 공유 헬퍼를 새로 만들지 않는다 — 스크립트 하나를 없애려는 작업에서 다른 스크립트를 만드는 것은 순환이다 |
     | 검증 | 소비자별 독립 테스트 (AC7b·AC7c). 한 소비자의 테스트가 다른 소비자를 덮지 않는다 |
  3. 상한이 없어지면 `reviewing-brief`의 *"예산 소진 시 웹 없이 판정"* degrade 분기는 **도달
     불가**가 되므로 그 분기와 그것을 잠그는 `test_reviewing_brief_skill.sh:206-207`(T21)을
     함께 정리하고, 새 락이 *"상한 게이트 부재 + kill switch 동작"* 을 assert하게 바꾼다.
  4. 스크립트는 카운터·게이트가 모두 사라지면 남는 책임이 없으므로 삭제한다.
- **`adversarial.md`의 신규 발견 승격** (C3) — **쓰기 쪽만 고치면 동작하지 않는다**
  (round-2 리뷰가 block으로 적발, 원문 확인 완료).
  - *쓰기 쪽*: `:149`만 고치면 persona가 자기모순이 된다. 같은 선언이 **네 곳**에 있다 —
    `:3`(description) · `:12`("single model-based judgment gate") ·
    `:22`("You are NOT responsible for: producing new findings of your own") · `:149`.
  - *읽기 쪽*: `synthesize_findings.py`의 `apply_verdicts()`(`:44-64`)는
    `by_id = {v["finding_id"]: v ...}`를 만든 뒤 **원본 `findings`만 순회**한다. 매칭되는
    `finding_id`가 없는 verdict — 즉 정의상 *신규* 발견 — 은 `out`에 들어갈 경로가 없다.
    승격을 허용해도 synthesizer가 조용히 drop한다.
  - 따라서 `synthesize_findings.py`에 **신규 발견 수용 경로**를 추가한다. 인터페이스를 명시한다
    (codex 리뷰: *"finding 본문 필드"* 로는 구현이 갈린다):

    | 항목 | 규정 |
    |---|---|
    | 수용 조건 | verdict에 `finding_id`가 없거나 기존 어느 finding과도 매칭되지 않으면서, `file`·`severity`·`summary` 세 필드를 **전부** 가질 때 |
    | id | 기존 `finding_id(f)` 헬퍼로 **합성**한다 — verdict가 준 id를 신뢰하지 않는다(리뷰어가 기존 id를 참칭할 수 있다). 충돌하면 기존 finding이 이긴다 |
    | 출처 | `source: "adversarial"` 를 강제로 덮어쓴다. verdict가 다른 값을 넣어도 무시 |
    | 순서 | 기존 findings **뒤에** append — 기존 표의 순서를 흔들지 않는다 |
    | 불완전 항목 | **조용히 버리지 않는다**: 출력에 넣지 않되 stderr에 `synthesize_findings: dropped malformed adversarial finding: <누락 필드>` 를 찍고, 요약의 `dropped_malformed` 카운터를 증가시킨다. **exit code는 바꾸지 않는다** — 리뷰어 출력 불량으로 파이프라인 전체를 죽이면 그 자체가 새 fail-closed 억제가 된다 |

    이 인터페이스는 persona 프롬프트와 **독립적으로** 테스트한다 — 픽스처 JSON을 직접 넣어
    synthesizer만 검증한다(AC14c). 그래야 persona 편집이 테스트를 green으로 만들지 못한다.
  - 이것은 round-1이 `web_budget.py`에서 잡은 것과 **같은 클래스**(한 층에서 켜고 소비하는
    층에 배선하지 않음)가 그 수정 안에서 재발한 사례다. AC14가 파이프라인 통과를 요구한다.
- **`parse_spec_structure.py:162`의 단어경계 없는 매칭** (round-1 리뷰가 §11에서 끌어올림) —
  `re.escape(phrase)`를 단어경계로 감싸 정상 기술 용어 안의 부분문자열에서 발화하지 않게 한다.
  이것은 fail-open(검사가 약함)이 아니라 **과잉 차단**이고, 이 sweep의 판별식이 정확히 겨냥하는
  능력 억제다 — §11 표를 쓰는 동안 실제로 write를 exit 2로 막았다.

### S4 — 규약 정렬

| 위치 | 조치 |
|---|---|
| `CLAUDE.md:43` · philosophy `:63` | *"Fan-out factor N ≥ 5는 hard review 게이트"* 삭제. `cost_class: high` 승인 게이트는 **유지** (비용 동의는 P17 load-bearing) |
| `CLAUDE.md:68` · philosophy `:96` | *"single-agent를 default로"* 삭제. *"선언 없는 fan-out"* 이 anti-pattern이라는 부분은 유지 |
| `CLAUDE.md:69` | *"wall-clock budget"* 필수 삭제 — spec-distill v0.17.0이 *"사람 숙고시간 오측정 footgun"* 으로 이미 제거했다. 규약이 플러그인이 폐기한 것을 요구하는 상태 |
| philosophy `:20` | *"모델 성능이 향상돼도 이 메커니즘은 불변이다"* 를 완화 — 현재 비용 임계치까지 재평가 불가로 선언해 **이 sweep 자체를 규칙 위반으로 읽게 만든다** |
| philosophy `:43` | trivia escape의 *single-file* 제약 완화 — 두 파일 이상의 한 줄 변경(오타 3곳, symbol rename)에 full 게이트를 강제해 스스로 금지한 trivia ceremony를 요구한다 |
| `docs/plugin-authoring.md` | `model: inherit` 규약을 명시 — 신규 플러그인이 reference 구현의 리터럴 핀을 복제하는 것을 차단 |
| project-init 템플릿 **2개** | rebase 조항을 *"공유된 브랜치를 rebase하지 않는다"* 로 완화 (C3). **동일 문구가 `templates/github-flow/branch-strategy.md:63`과 `templates/git-flow/branch-strategy.md:99` 양쪽에 있다** — 한쪽만 고치면 억제가 다른 variant로 살아남는다 (round-1 리뷰 적발). 리포 루트 `docs/git-workflow/branch-strategy.md:63`은 사용자 본인 선호이므로 **유지** |

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
- **AC7** `web_budget.py`가 삭제되고 **두 소비자 모두**에서 상한 게이트가 사라진다. 검증은
  소비자별로 분리한다 — 하나가 다른 하나를 대신 green으로 만들지 못하게:
  - **AC7a** `grep -rn 'web_budget' plugins/` 이 0건 (production 경로. CHANGELOG의 이력 언급은 제외).
  - **AC7b** `conducting-interview/SKILL.md`에 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 인라인 체크가
    존재하고, 그 값이 `1`일 때 웹 경로를 타지 않음을 테스트가 확인한다.
  - **AC7c** `reviewing-brief/SKILL.md`에 대해 AC7b와 **같은 검증을 독립적으로** 수행한다.
    (round-1 리뷰: 이 분리가 없으면 AC7은 `check_brief.py`의 별도 경로만으로 green이 되는
    green-expected AC다.)
  - **AC7d** `test_reviewing_brief_skill.sh`의 T21이 *"`web_budget.py` 호출 실재"* 대신
    *"상한 게이트 부재 + kill switch 동작"* 을 assert하도록 교체되고, mutation(상한 재도입)이 RED.
- **AC8** S4 표의 **7행 전부**가 기계 검증된다 — 3행만 덮는 AC는 나머지 4행을 조용히 통과시킨다:
  - **AC8a** `CLAUDE.md`·philosophy에 `N ≥ 5`·`single-agent를 default`·`wall-clock` 문구 부재,
    `cost_class: high` 승인 게이트 문장은 존속.
  - **AC8b** philosophy `:20`의 *"모델 성능이 향상돼도 이 메커니즘은 불변이다"* 가 완화돼,
    비용 임계치가 재평가 대상임이 문장으로 확인된다.
  - **AC8c** philosophy `:43`의 trivia escape에 *single-file* 제약이 없다.
  - **AC8d** `docs/plugin-authoring.md`에 agent `model: inherit` 규약 문장이 존재한다.
  - **AC8e** `templates/github-flow/branch-strategy.md`와 `templates/git-flow/branch-strategy.md`
    **둘 다** 무조건 rebase 금지 문구가 없고, 리포 루트 `docs/git-workflow/branch-strategy.md`는
    **변경되지 않는다**(사용자 선호 보존 — 양방향 assert).
- **AC9** 모든 회귀 락이 **양방향**이고, 각 락에 대해 mutation(핀 재도입)이 RED를 만든다.
- **AC10** 변경 후 테스트 스위트의 red가 baseline 6건을 초과하지 않는다.
- **AC11** dispatch 실측으로 (a) `inherit` 에이전트가 세션 모델을 상속하고, (b) `spec-reviewer`가
  `WebSearch`를 실제로 호출할 수 있음을 **트랜스크립트로** 확인한다 (자기보고 불가).
- **AC12** 각 플러그인의 `plugin.json` version bump + `CHANGELOG.md` 항목이 같은 커밋에 있다.
- **AC13** §2의 각 판별 질의를 변경 후 실행했을 때, 매칭되는 항목은 **전부** 변경됐거나
  **아래 스키마를 갖춘 load-bearing allowlist 항목**으로 §12에 등재돼 있다. 잔여 매칭이 있는데
  등재가 없거나 등재가 불완전하면 sweep은 미완이다 — *"정당화돼 있다"* 만으로는 무엇이든 통과한다
  (codex 리뷰 지적). 등재 필수 필드:

  | 필드 | 내용 |
  |---|---|
  | `위치` | `file:line` |
  | `막는 실패` | 이것을 제거하면 **무엇이 조용히 통과하게 되는가** — 이 sweep의 판별식 그대로. "조심스러워서"는 실패 서술이 아니다 |
  | `근거` | 그 실패가 가설이 아니라 실재함을 보이는 것 — 커밋·테스트·과거 사고 기록 |
  | `대안 검토` | 더 가벼운 수단으로 같은 실패를 막을 수 있는지, 왜 안 되는지 |
  | `재검토 조건` | 이 항목을 다시 열 조건. *"영구"* 는 허용하지 않는다 (philosophy `:20`을 완화하는 이 sweep이 자기 예외를 영구화하면 자기모순) |
- **AC14** 승격이 **끝에서 끝까지 동작한다** — persona 편집만으로는 green이 되지 않는다:
  - **AC14a** `adversarial.md`의 *"신규 발견 금지"* 선언이 `:3`·`:12`·`:22`·`:149` **네 곳 모두**에서
    해소된다. 한 곳이라도 남으면 persona 자기모순.
  - **AC14b** `synthesize_findings.py`에 기존 `finding_id`와 매칭되지 않는 verdict를 출력에
    추가하는 경로가 있고, 그 항목에 `source: adversarial`이 붙는다.
  - **AC14c** *(teeth)* 기존 finding 0건 + adversarial 신규 발견 1건을 넣은 픽스처가
    synthesizer를 통과해 **출력에 그 발견이 실재**한다. mutation: 신규 수용 경로를 되돌리면 RED.
    AC14a만으로는 이 AC가 green이 될 수 없다.
- **AC15** `parse_spec_structure.py`의 ambiguity 매칭이 단어경계를 갖는다 — 정상 기술 용어
  (`~fast`-forward, `in`+`~efficient`)가 hit되지 않고, blacklist의 온전한 단어는 계속 hit된다
  (양방향 assert: 완화가 검사를 무력화하지 않았음도 확인). **이 AC를 쓰는 동안 이 검사가 세 번째로
  발화해 write를 막았다** — 두 예시에 붙은 `~`는 검사기 자신의 opt-out 마커다.
- **AC16** `build_spec_codex_prompt.py`의 범주가 6개로 닫혀 있지 않고, 미지 범주를 담은 codex
  출력이 `merge_review.py`를 통과할 때 drop되지 않는다.

## 8. Files to Modify

**agents (7)** — `quality-gates/agents/{adversarial,pr-understanding-builder,test-scope-validator}.md` ·
`spec-distill/agents/{blind-spot-prober,steelman-builder,coverage-mapper,spec-reviewer}.md`
(+ `security-reviewer.md`는 :38 문구만)

**scripts (7)** — `quality-gates/scripts/{run_codex_reviewer.sh,run_artifact_codex_reviewer.sh}` ·
**`quality-gates/scripts/synthesize_findings.py`** (승격된 발견의 읽기 쪽 배선 — round-2 리뷰 적발) ·
`spec-distill/scripts/{run_spec_codex_reviewer.sh,build_spec_codex_prompt.py,parse_spec_structure.py}` ·
`spec-distill/scripts/web_budget.py` (삭제)

**skills / commands (5)** — `spec-distill/skills/conducting-interview/SKILL.md` ·
**`spec-distill/skills/reviewing-brief/SKILL.md`** (web_budget 두 번째 소비자 — round-1 리뷰 적발) ·
`quality-gates/skills/publishing-pr-understanding/SKILL.md` ·
`quality-gates/skills/quality-pipeline/references/{dependency-check,state-file-format}.md`

**tests (11)** — `quality-gates/tests/{test_adversarial_model_consistency,test_adversarial_persona,test_pr_understanding_builder_frontmatter,test_test_scope_validator_frontmatter}.sh` ·
`spec-distill/tests/{test_spec_reviewer_frontmatter,test_coverage_mapper_frontmatter,test_web_sweep_bound,test_run_spec_codex_reviewer}.sh` ·
**`spec-distill/tests/{test_reviewing_brief_skill,test_conducting_interview_stage,test_parse_spec_structure}.sh`**
(앞의 둘은 `web_budget.py` 호출을 잠그고 있어 함께 고치지 않으면 RED)

**docs / 규약 (7)** — `CLAUDE.md` · `docs/philosophy/devbrew-harness-philosophy.md` ·
`docs/plugin-authoring.md` · `quality-gates/README.md` · `spec-distill/README.md` ·
`project-init/templates/github-flow/branch-strategy.md` ·
**`project-init/templates/git-flow/branch-strategy.md`** — 동일 rebase 문구가 양쪽에 있다.
round-2 리뷰: round-1이 지적한 *단일-variant 누락*이 Files to Modify 레벨에서 재발했었다.
(리포 루트 `docs/git-workflow/branch-strategy.md`는 **변경 대상이 아니다** — 사용자 선호 보존)

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

### 9.1 Mutation 시나리오 — 각 락이 무엇에 반응해야 하는가

락이 통과한다는 사실은 이빨의 증거가 아니다. **억제를 되돌려 넣었을 때 RED가 나야** 이빨이다.
각 변경 락마다 아래 mutation을 적용하고 RED를 확인한 뒤 revert한다.

| 락 | mutation (되돌려 넣을 것) | 기대 |
|---|---|---|
| 모델 핀 양방향 락 5개 | 해당 agent frontmatter를 `model: opus`/`model: sonnet`으로 되돌림 | RED |
| 같은 락 (반대 방향) | `model:` 줄을 **삭제** — 핀도 `inherit`도 없는 상태 | RED (`inherit` 존재를 positive assert하므로) |
| codex 추론 상한 락 | `-c 'model_reasoning_effort="medium"'` 재삽입 | RED |
| 같은 락 (보안 보존) | `-s read-only` 제거 | RED — 상한 제거가 샌드박스까지 걷어내지 않았음을 증명 |
| E10 상한 문구 락 | agent 본문에 `최대 2회` 재삽입 | RED |
| `web_budget` T21 교체 락 | 어느 한 소비자에 상한 게이트 재도입 | RED (**소비자별 독립** — 한쪽만 되돌려도 잡혀야 AC7c가 의미 있다) |
| kill switch 락 | `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 체크 제거 | RED, 소비자 각각에 대해 |
| AC14c 승격 락 | `synthesize_findings.py`의 신규 수용 경로 revert | RED |
| AC15 단어경계 락 | `re.escape(phrase)`에서 경계 제거 | RED (정상 용어가 hit) |
| 같은 락 (반대 방향) | blacklist의 온전한 단어 하나를 넣은 픽스처 | **여전히 hit** — 완화가 검사를 죽이지 않았음 |

**락 문구는 body-unique여야 한다.** assert 문구가 헤더나 주석에도 있으면 본문을 삭제해도 GREEN이
나온다 — 이 리포가 이미 겪은 함정이다. 각 락은 섹션 윈도우 안에서 grep하고, 헤더만 남긴
mutation으로 그 사실을 증명한다.

### 9.2 AC11 dispatch 실측 절차

프론트매터에 적혔다는 것은 런타임 반영의 증거가 아니다 — agent 레지스트리는 **세션 시작 시
스냅샷**되므로 편집 직후 같은 세션에서 dispatch하면 옛 정의가 돌 수 있다.

1. S1·S2 커밋 후 **세션을 재시작**한다 (또는 headless `claude -p --plugin-dir`로 fresh 세션).
2. `spec-reviewer`를 1회 dispatch한다 (아무 design doc 대상).
3. `~/.claude/projects/<proj>/<sid>/subagents/agent-<id>.meta.json`에서 `agentType`으로 신원을 확정하고,
   같은 id의 `.jsonl`에서 확인한다:
   - `grep -o '"model":"[^"]*"' …` → `claude-opus-5` (세션 모델). `claude-sonnet-5`면 **핀이 살아 있다**.
   - `grep -o '"name":"[A-Za-z0-9_-]*"' …` → `WebSearch` 실재. 없으면 도구가 프론트매터에만 있고
     런타임에 없다는 뜻이다.
4. 두 관측을 이 문서 §12에 날짜와 함께 기록한다. **에이전트의 자기보고는 증거가 아니다** —
   트랜스크립트만 증거다.

이 절차의 baseline은 이미 있다: 변경 *전* 측정치가 §1.1 표이고, 같은 방법으로 얻었다.

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

### 10.1 Rollout 구조 — 3안 비교 후 선택

세 플러그인 + 루트 규약 + 메모리를 건드리므로 배포 단위를 정해야 한다 (codex 리뷰 지적).

| 안 | 원자성 | 롤백 | SemVer | 리뷰 가능성 |
|---|---|---|---|---|
| **A. 관심사별 커밋 1 PR** (S1→S5, 채택) | 각 커밋이 한 관심사 | 커밋 단위 revert | PR당 3 플러그인 bump 1회씩 | 리뷰어가 *"핀 제거"* 를 세 플러그인에서 한 번에 봄 — 이 sweep의 논거가 **교차-플러그인 일관성**이라 같이 봐야 판단이 선다 |
| B. 플러그인별 PR 3개 | 플러그인 경계 | PR 단위 | PR당 1 bump — 가장 단순 | *같은* 결함이 3 PR에 흩어져 각 리뷰어가 부분만 봄. `CLAUDE.md`·philosophy는 어느 PR에도 자연스럽게 속하지 않음 |
| C. 단일 커밋 단일 PR | 없음 | 전부 아니면 전무 | 1회 | 붕괴 — 핸드오프 §4가 금지 |

**A를 채택한다.** 근거: 이 sweep의 핵심 주장이 *"같은 억제가 플러그인 경계를 넘어 반복된다"* 이므로,
경계로 자르면 그 주장을 리뷰어가 검증할 수 없다. B의 장점(bump 추적 단순화)은 커밋 단위 분리로
이미 대부분 확보된다. 다만 **S1이 예상보다 커지면 S1만 먼저 PR로 내는 것을 허용**한다 — 모델 핀은
독립적으로 완결되고 나머지를 블록하지 않는다.

## 11. 이 사이클에서 제외 — 별건 목록

census가 발견했으나 **sweep의 반대 방향**(억제가 아니라 구멍 — 검사가 너무 *약해서* 틀린 것이
조용히 통과)인 결함들이다. 섞으면 리뷰가 흐려지므로 분리한다. 별도 사이클에서 다룬다.

> **CHECKS-02는 이 표에서 빠졌다** (round-1 리뷰 적발). `parse_spec_structure.py:162`의 단어경계
> 없는 매칭은 fail-open이 아니라 **과잉 차단**이므로 방향이 반대이고, 이 sweep의 대상이다 →
> §6 S3로 이동. 이 표에 남은 항목들은 전부 *"검사가 약해서 틀린 것이 통과"* 형이라 성격이 같다.

| ID | 위치 | 결함 |
|---|---|---|
| CHECKS-01 | `spec-distill/scripts/parse_spec_structure.py:45` | 코드 펜스 안에 인용된 헤더 한 줄로 Law 1 구조 게이트가 만족됨 (fail-open) |
| CHECKS-03 | `plugin-audit/scripts/check-shape-completeness.py:100` | frontmatter가 없는 agent도 본문의 `tools:` 한 줄로 Law 2 검사 통과 |
| CHECKS-04 | 같은 파일 `:175` | kill switch를 docstring에 **적기만** 한 훅이 통과 |
| CHECKS-05 | `quality-gates/scripts/check-changelog-korean-primary.py:77` | 얼어붙은 `[1.32.0]` 절만 검사 — 이후 항목에 발화하지 않음 |
| CHECKS-06 | `quality-gates/scripts/synthesize_findings.py:180` | `--show-low-confidence` 가 리포 어디에도 구현돼 있지 않아 findings가 영구 은닉됨 |
| CHECKS-07 | 같은 파일 `:70` | 같은 file:line·severity의 서로 다른 지적을 접으며 **허위 귀속** 발생 |
| SDSKILL-06 | `spec-distill/skills/reviewing-brief/SKILL.md:104` | 리포 밖(마켓플레이스 설치 시) 참조 파일 부재로 brief 리뷰 파이프라인 전체가 degrade |

## Handoff Context

### TL;DR

devbrew 전 표면에서 하니스가 모델 능력을 깎는 지점을 제거한다. 실행자는 §6의 S1→S5를 순서대로,
각각 독립 커밋으로 진행하면 된다. 가장 중요한 사실 하나: **핀의 실제 이빨은 agent frontmatter가
아니라 테스트 락**이므로, 락을 함께 반전하지 않으면 스위트가 RED가 되어 변경이 되돌려진다.

### Implicit context (문서에 안 적혀 있으면 실행자가 모를 것들)

- **baseline은 이미 캡처됐다.** `e45619b`에서 bash 128개 중 6 red(전부 quality-gates, pre-existing),
  python 189+95 green. 이 6건은 내가 만든 것이 아니므로 고치려 들지 말 것. qg는 CI가 없어 main에
  stale red가 누적돼 있다.
- **`plugins/spec-distill/tests/`의 python 테스트는 `-m unittest`로만 돈다** (pytest 아님), 그리고
  테스트는 **repo root에서** 실행해야 경로가 맞는다.
- **`~/Downloads` 아래라 TCC 권한 회수가 일어나면** `stat`은 되는데 `open`이 실패하며 테스트가
  대량 실패한다 — 회귀로 오인하지 말 것.
- **`model: opus` 별칭은 현재 세션 세대를 따라간다.** 그래서 opus 핀 2건은 오늘 손실이 0이다.
  이 사실을 모르면 "왜 이것도 고치나"라는 리뷰 반론에 답할 수 없다 — 근거는 잠재 상한과
  `cost_class` 자기모순이지, 측정된 downgrade가 아니다.
- **spec-distill의 Stop 훅이 모든 `*-design.md` write에 리뷰를 강제한다.** 이 문서를 고치면
  턴 종료 시 `reviewing-spec`이 다시 요구된다. 정상 동작이다.
- **`parse_spec_structure.py`의 ambiguity 검사가 이 문서 작성을 세 번 막았다.** S3에서 고치기
  전까지는 `~` opt-out 마커로 우회해야 한다.
- **census 원장**은 `$CLAUDE_JOB_DIR/tmp/{census,merged}.json`에 있고, 근거 요약은
  `$CLAUDE_JOB_DIR/tmp/facts.md`다. 세션이 끝나면 사라지므로, 구현 시작 전에 보존이 필요하면
  `docs/audits/`로 옮긴다 (Law 3).

### Deferred to plan

아래 넷은 round-2 리뷰가 *"AC가 요구하는데 미완"* 으로 지적해 **설계로 끌어올렸다** —
`§9.1`(mutation 시나리오) · `§9.2`(AC11 절차) · `§10.1`(rollout 선택) · `§6 S3`(하위 단위와 커밋 경계).

계획 단계에 남는 것은 이 넷뿐이다:

- 각 하위 단계 안에서의 파일별 편집 **순서** (무엇을 먼저 건드려야 중간 상태의 RED가 최소인지)
- §11 별건 8개를 다룰 후속 사이클의 범위와 우선순위

아래 둘은 **여기서 확정한다** (codex 리뷰: 미해결로 남기면 커밋 유효성 판정이 갈린다):

- **커밋 유효성**: 각 커밋은 baseline(bash red 6 · python green)을 **유지하거나 개선**해야 한다.
  중간 커밋이 baseline보다 red를 늘리는 것은 허용하지 않는다 — 락 반전과 대상 변경을 **같은
  커밋에** 넣으면 이 조건이 자연스럽게 성립한다(락만 먼저 고치면 그 커밋이 RED가 된다).
- **메모리 편집은 산출물에 포함되지만 커밋에는 들어가지 않는다.** 메모리 디렉토리는 리포 밖
  (`~/.claude/projects/.../memory/`)이라 git이 추적하지 않는다. 따라서 S5의 메모리 변경은
  커밋 대신 **이 문서 §12에 변경 목록으로 기록**하고, 그것이 유일한 감사 흔적이다.

## 12. Metadata

- **작성일** 2026-08-02
- **브랜치** `fix/harness-capability-suppression-sweep`
- **baseline** `e45619b`
- **근거 문서** `docs/handoffs/2026-07-26-harness-capability-suppression-sweep.md`
- **census 산출** 13 에이전트 / 110 findings + 14 / 2,077,370 subagent tokens / 41분
- **관련 원칙** P8 (Determinism Economy) · P17 (User Sovereignty) · P21 (Security & Supply Chain)
- **선행 기록** `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` (`tools: []` 격리 실측)
