# codex 소비 사슬 통일 — 설계 (1~3단계)

> *실패한 리뷰가 성공한 리뷰처럼 보이면, 그것은 리뷰가 없는 것보다 나쁘다.*

devbrew가 codex를 **소비하는 전 사슬**(가용성 detect → 프롬프트 빌더 → 실행 러너 → JSONL 추출 →
병합/수집)을 하나의 규약 아래 통합한다. 입력은 [`2026-08-02-codex-usage-unification-interview.md`](../interview/2026-08-02-codex-usage-unification-interview.md)이고,
이 문서는 그 brief가 열어둔 미결을 실측으로 닫은 뒤의 해답공간이다.

**출력 계약**(`--output-schema`·findings 스키마·부분 파싱·비용 계측)은 **별도 설계 문서**로
이관됐다 — 사유와 선행 조건은 §11.

**개정 이력**: round-1(`f8cea03`) → round-2 반영(`ce3fe4b`) → **round-3 반영(이 판)**.
round-2 리뷰가 지적 36건(신규 28)으로 **발산**했고, 그 대부분이 두 개의 설계 선택에서
파생함이 드러나 **구조를 바꿨다**(§9 R10·R11, §10).

## 목차

- [1. Context / Why](#1-context--why)
  - [1.1 실측된 사슬 — 5층 20 아티팩트](#11-실측된-사슬--5층-20-아티팩트)
  - [1.2 지금 틀린 답을 내고 있는 것](#12-지금-틀린-답을-내고-있는-것)
  - [1.3 baseline — sweep PR #112 이후](#13-baseline--sweep-pr-112-이후)
  - [1.4 재구성 — codex 는 편의가 아니라 P11 집행이다](#14-재구성--codex-는-편의가-아니라-p11-집행이다)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
  - [4.1 결과 판정의 우선순위 (규범)](#41-결과-판정의-우선순위-규범)
  - [4.2 codex CLI 버전 바닥](#42-codex-cli-버전-바닥)
  - [4.3 실행 관측 기반 계약 검증](#43-실행-관측-기반-계약-검증)
- [5. 설계](#5-설계)
  - [5.1 1단계 — plugin-audit 을 규약 안으로](#51-1단계--plugin-audit-을-규약-안으로)
  - [5.2 2단계 — 결함](#52-2단계--결함)
  - [5.3 3단계 — 나머지 통일](#53-3단계--나머지-통일)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
  - [8.1 baseline](#81-baseline)
  - [8.2 mutation 시나리오](#82-mutation-시나리오)
  - [8.3 실행 검증 (네트워크 필요)](#83-실행-검증-네트워크-필요)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [10. Metadata](#10-metadata)
- [11. 후속 설계로 이관 (출력 계약)](#11-후속-설계로-이관-출력-계약)
- [Handoff Context](#handoff-context)

## 1. Context / Why

### 1.1 실측된 사슬 — 5층 20 아티팩트

| 층 | 아티팩트 | 사본 여부 |
|---|---|---|
| ① 가용성 detect | `qg/scripts/detect_codex.sh` · `sd/scripts/detect_codex.sh` (plugin-audit **부재**) | **사본 2** — 실질 차이는 kill switch 변수명 1줄 |
| ② 프롬프트 빌더 | `qg/build_codex_prompt.py` · `qg/build_artifact_codex_prompt.py` · `sd/build_spec_codex_prompt.py` · `sd/build_brief_codex_prompt.py` · `plugin-audit/scripts/codex-prompt-preamble.md` | 아님 |
| ③ 실행 러너 | 위 4 러너 + `qg/tests/spike/test_codex_json_extraction.sh:33` + `plugin-audit/skills/auditing-plugins/SKILL.md:92`(**산문**) | 아님 — `codex exec` 실행 라인 **6곳** |
| ④ JSONL 추출 | `qg/codex_findings_to_yaml.py` · `sd/codex_findings_to_yaml.py` · `qg/extract_codex_artifact_yaml.py` (plugin-audit **부재**) | **앞 둘이 사본이고 갈라짐** |
| ⑤ 병합/수집 | `sd/merge_review.py` · `sd/merge_brief_review.py` · `qg/synthesize_artifact_findings.py` · `plugin-audit/scripts/assemble-audit-data.py` | 아님 |

**층 ④ 에 plugin-audit 몫이 비어 있다**(round-2 리뷰 적발). `assemble-audit-data.py:162,167` 은
`--codex-side <json>`(`{findings, d_verdicts, oq_answers, new_open_questions}`,
`auditing-plugins/SKILL.md:97-98`)을 요구하는데 그것을 만드는 코드가 없다 — 지금은 모델이 산문
지시를 읽고 손으로 만든다. 1단계가 이 공백을 메운다.

테스트 자산 사본도 있다: mock 6그룹이 바이트 단위로 동일하게 복제돼 있고(`timeout`/`gtimeout`
스텁은 4벌), `test_detect_codex.sh` 는 두 벌인데 qg 9 assert / sd 11 assert 로 **어느 쪽도
합집합이 아니다**(합집합 12).

### 1.2 지금 틀린 답을 내고 있는 것

**(a) quality-gates 변환기가 형식 위반을 성공으로 기록한다.** 재현:

```
입력: codex 가 {"findings": {}} 를 반환   ← 계약상 findings 는 배열

quality-gates  → codex_failed: false | reason: schema_mismatch | raw_findings_type: dict
spec-distill   → codex_failed: true  | reason: schema_mismatch | raw_findings_type: dict
```

`codex_failed: false` 는 소비자에게 *"codex 정상 실행, 발견 0건"*으로 읽힌다. **실행되지 못한
검사가 통과한 검사로 기록된다.** 그리고 quality-gates 는 자기가 선언한 계약을 어긴다 —
`tests/test_codex_runner_degrade_contract.sh:43`.

원인은 vendoring drift 다. spec-distill 사본은 2026-07-29(`3868857`)까지 받았고 quality-gates
사본의 마지막 변경은 **2026-05-14**(`ec82474`)다. 코드 위치는 qg `:199-204` vs sd `:178-202`.
두 사본이 동기 상태인지 검사하는 테스트는 리포 어디에도 없다.

**이 사실이 2026-07-15 기각의 근거를 반증한다.** 그 설계 §14 는 물리 통합을 기각하며
*"qg 버전 drift 에 spec-distill 이 silent 하게 깨진다"*를 근거로 들었는데, 채택된 대안
(vendoring)에서 **같은 drift 가 반대 방향으로 실현됐다.** 무엇을 뒤집는지는 §10 반전 #2 참조.

**(b) 프롬프트가 argv 로 나간다 — 그리고 형태가 두 가지다.**

| 형태 | 호출부 |
|---|---|
| 직접 치환 — `codex exec "$(cat "$PROMPT_FILE")"` | `run_codex_reviewer.sh:142` · `run_artifact_codex_reviewer.sh:39` · `run_spec_codex_reviewer.sh:99` · `run_brief_codex_reviewer.sh:102` |
| **변수 경유** — `PROMPT="$(cat "$PROMPT_FILE")"` (`:17`) → `codex exec "$PROMPT"` (`:33`) | `qg/tests/spike/test_codex_json_extraction.sh` |

두 형태 모두 **프롬프트 전문이 argv 를 지난다.** 형태가 둘이라는 사실이 검증 설계를 지배한다 —
문자열 패턴으로 잡으려 하면 두 번째 형태를 놓치고(round-1 적발), 문법을 정교화하면 셸이 쓸 수
있는 형태 전부를 열거하게 되어 시간에 fail-open 이 된다(round-2 적발). **그래서 §4.3 은
정적 판정을 버리고 실행 관측으로 간다.**

실측: `getconf ARG_MAX` = 1,048,576, 이분 탐색으로 확인한 절벽은 argv 1,042,187 통과 /
1,043,750 `E2BIG`(환경변수 5,232바이트 기준). 실제 merge diff 표본 — `a4e7fa2` 504,601(48%) ·
`4273d9d` 492,541(46%) · **`e45619b` 863,340(82%)**. 크기 상한은 러너·빌더 어디에도 없다.

아직 터지고 있지는 않다. 그러나 러너는 **항상 exit 0 + fallback 산출물**을 내므로 넘는 순간의
실패가 조용하고, 큰 PR 일수록 터진다. 그리고 천장이 둘인데 codex 상한은 1,048,576 **문자**이고
OS 는 1,048,576 **바이트**라, 한국어 프롬프트(UTF-8 3바이트/자)는 **낮은 쪽에 먼저 닿는다**.

**(c) 빨간 테스트 4건이 요구하는 것이 구현돼 있지 않다.** bash 스위트 134개 중 6 red 이고
그중 4개가 codex 관련이다(qg 는 CI 가 없어 stale red 가 누적된다).

- `test_sandbox_enforced.sh` — v1.32.0 에 삭제된 `agents/codex-reviewer.md` 를 겨냥해 **영구 RED**.
  같은 디렉토리의 `test_codex_reviewer_frontmatter.sh:9` 는 **같은 파일이 없어야** PASS 라고
  요구하므로 두 테스트는 동시에 통과할 수 없다. 파서(`tests/lib/extract_codex_invocations.py`)도
  함께 죽어 있다(현재 `:21-27` 이 마크다운 fence 만 읽어 `.sh` 에서 0건).
- `test_codex_reviewer_frontmatter.sh` — 그 파일의 `AC42` 가 `quality-pipeline/SKILL.md` 에서
  `DEVBREW_DISABLE_QG_CODEX` **또는** `codex_available`(`:12` 의 alternation)를 찾지 못한다.
  kill switch 는 동작하지만 문서에서 사라져 **발견 불가**다. 같은 파일의 `-s read-only` assert 는
  원본 grep 이라 **헤더 주석에 만족된다**(mutation 확인).
- `test_skill_codex_skip_prose.sh` — 그 파일의 `AC19` 가 요구하는 visible 4종이 **전부 없고**
  같은 파일 `AC21` 의 섹션 헤더도 없다. silent 2종은 통과한다.
- `test_codex_backward_compat.sh` — 198초, exit 1. **파생 실패**다: check 3(`:78-89`)이 qg
  스위트를 재귀 실행해 4건을 보고하는데 그중 2건이 위 두 항목이고 나머지 2건은 codex 무관이며
  `:81` 의 제외 목록에 **없다**.

**(d) 검사가 "고쳤다"고 적어놓고 고치지 않았다.** `test_codex_runner_no_effort_pin.sh:43-44` 의
주석이 plugin-audit 커버리지를 고쳤다고 서술하지만 실측 커버리지는 **0** 이다 —
`INVOKE` 정규식(`:38`)이 `codex` 앞에 줄머리/공백을 요구하는데 마크다운 인라인 코드는 백틱이
앞에 온다. **1단계가 그 산문을 스크립트로 바꾸면 이 주석은 참이 된다** — 그때 참임을 확인한다.

**거짓 주장은 갭보다 나쁘다** — 다음 사람이 "저건 이미 커버됐다"고 읽고 넘어간다.

### 1.3 baseline — sweep PR #112 이후

brief 의 C8 이 지정한 선행 조건은 충족됐다(`a4e7fa2`, main).

- `model_reasoning_effort` 하향 핀 **4곳 전부 제거**(러너 3 + `tests/spike` 1).
- `test_run_spec_codex_reviewer.sh:39` 의 assert **반전 완료**.
- 신규 락 `qg/tests/test_codex_runner_no_effort_pin.sh` + 호출부 추출 헬퍼.
- `sd/scripts/web_budget.py` **삭제**(201줄) → `tests/test_web_kill_switch.sh`(17/17 PASS).
- sweep §11 별건 목록에 **SDSKILL-06** 등재(리포 파일을 하드 게이트 입력으로 읽음).

### 1.4 재구성 — codex 는 편의가 아니라 P11 집행이다

`docs/philosophy/devbrew-harness-philosophy.md` 의 P11 은 집행 파일로
**`plugins/quality-gates/scripts/run_codex_reviewer.sh` 를 명시**한다. 즉 codex 는 부가 기능이
아니라 **Law 2 를 코드로 집행하는 구조 메커니즘 그 자체**다. 그러면 *"codex 부재 시 loud
degrade"*는 crash 회피가 아니라 **P11 이 집행되지 않았다는 사실을 사람에게 보이는 문제**다.
배너는 *"codex 없음"*이 아니라 **"이 리뷰에는 모델 다양성이 없었다"**를 말해야 한다.

## 2. Goals

1. **codex 리뷰가 실패했는데 성공으로 읽히는 경로를 전부 막는다.** 판정 우선순위는 §4.1.
2. **codex 를 부르는 모든 곳이 같은 절차를 거친다.** 가용성 확인 → kill switch 존중 →
   보안 플래그 + stdin 규약 → 실패 시 loud degrade. plugin-audit 의 산문 지시를 스크립트로
   승격해 규약 안으로 들이고, 비어 있는 층 ④ 몫을 채운다.
3. **codex 의 기본 능력을 손으로 약하게 재구현한 곳을 걷어낸다.** 프롬프트 전달(argv → stdin) ·
   웹 검색(미지정 → 명시).
4. **검사가 자기 커버리지에 대해 참말을 하게 한다.** 계약 판정을 **실행 관측**으로 옮기고,
   열거를 도출로 바꾸고, 거짓 주장을 사실로 만든다.

## 3. Non-goals

- **물리 통합**(§9 R1·R2) · **`codex exec review` 전환**(R3) · **SARIF**(R4) ·
  **severity 어휘 강제 통일**(R5) · **실행값 meta 기록**(R6) · **프롬프트 순서 재배치**(R7) ·
  **diff 절단**(R8) · **`--ignore-user-config`**(R9) · **정적 문법으로 계약 집행**(R10).
- **reasoning effort · model 핀** — sweep 이 제거했고 재도입 락이 있다.
- **`-s read-only` 를 인자화하거나 완화하는 것.**
- **출력 계약 전반** — §11 로 이관.
- SDSKILL-06 해소 — sweep §11 별건 목록 소관.

## 4. Constraints

- **`-s read-only` 는 불가침**(`qg/README.md:30`).
- **kill switch 는 보안 컨트롤**(P21). 게이트는 **호출자 책임**(`reviewing-brief/SKILL.md:26`).
- **plugin-audit 의 blind 독립성.** 새 러너는 qg 프롬프트 빌더를 재사용하지 않는다 —
  `auditing-plugins/SKILL.md:94` 가 금지하며, 이유는 qg 빌더가 최신 spec 의 AC 를 자동 주입해
  blind 를 파괴하기 때문이다.
- **graceful degradation with loud logging.**
- **하니스가 능력을 억제하지 않는다**(사용자 절대 조항). 예외는 load-bearing 인 `-s read-only`.
- **`indeterminate ≠ clean`.** 성공은 **양성 표식**으로만 성립한다.
- **열거 금지.** 검사 대상은 도출한다.
- **baseline 을 유지하거나 개선한다**(§8.1). 어떤 변경이 기존 GREEN 테스트를 RED 로 만들면
  **그 테스트 갱신을 같은 커밋에** 넣는다.
- **SemVer bump + CHANGELOG** — 건드리는 플러그인마다. Korean-primary 문서 규약 준수.

### 4.1 결과 판정의 우선순위 (규범)

신호원이 여럿인데 충돌 시 무엇이 이기는지 정해져 있지 않으면 이 설계의 목적이 성립하지 않는다.
**아래 순서로 판정하고, 앞 단계에서 결론이 나면 뒤를 보지 않는다.**

1. **`codex exec` 의 종료 코드** — exit 0/1 두 개뿐이고 **"항상 exit 0"은 거짓**이다(exit 1 경로
   13곳). `exit ≠ 0` → **결과를 신뢰하지 않는다**. 러너는 이를 `--meta-override-reason
   exit_nonzero` 로 추출기에 전달하고 추출기는 `codex_failed: true` 를 낸다.
   **현행 동작과의 차이**: `run_codex_reviewer.sh:150-172` 는 비영점 exit 에서도 추출기를 계속
   돌린다. 그 자체는 유지한다 — 추출기가 override 를 받아 `codex_failed` 를 세우므로 **판정
   결과는 규칙 1 과 같다**. 바꾸는 것은 없고, 이 문서가 그 동등성을 명시할 뿐이다(AC18 이 잰다).
2. **산출물 파일의 존재와 크기** — 부재 · 0바이트 → `codex_failed: true`. 러너는 시작 시
   truncate 하고 EXIT 트랩에서 비어 있으면 degrade 를 채운다(현행 규약 유지).
3. **파싱 결과의 양성 성공 표식** — `meta.codex_failed: false` 가 **있어야** 정상이다.
   부재 · 판독 불가는 degrade 다. `findings: []` 만으로 clean 으로 읽지 않는다.
4. **스트림 이벤트는 판정 입력이 아니다** — `--json` 의 `error` 이벤트는 **재시도로 성공한
   run 에서도 방출**되므로 실패 신호로 쓰지 않는다. 이 층은 로깅 대상이다.

**stdin 규약** (§4.3 이 관측으로 판정하는 계약): `codex exec` 호출은 프롬프트를 **stdin 으로**
넘기고(`-` 를 argv 에 명시), 프롬프트 바이트가 argv 에 **등장하지 않으며**, `-s read-only` ·
`-C <dir>` · `--json` 을 argv 에 갖는다.

**상태 표현의 truth table** (round-3 리뷰 적발 — 같은 사실이 세 이름으로 흩어져 있는데 변환
계약이 없었다). 층마다 표현이 다른 것은 **유지**하되(각 층의 기성 계약이므로) 대응을 못 박는다:

| 상태 | 추출기 출력(층 ④) | plugin-audit meta(층 ⑤) | 뜻 |
|---|---|---|---|
| **미실행** | 산출물 없음 (호출자가 게이트에서 막음) | `codex.ran: false` · `codex.failed: false` | detect 가 false — kill switch · 미설치 · 버전 |
| **실행-실패** | `meta.codex_failed: true` + `meta.reason` | `codex.ran: true` · `codex.failed: true` | 돌았으나 결과를 신뢰할 수 없음 |
| **실행-성공** | `meta.codex_failed: false` | `codex.ran: true` · `codex.failed: false` | 결과 사용 가능 |

- `codex_failed` 를 **최상위**로 내는 유일한 예외는 `extract_codex_artifact_yaml.py:67-68` 이다
  (기성 shape, 이 사이클에서 바꾸지 않는다). 새 코드는 **`meta:` 하위**에 둔다.
- `codex_audit_to_json.py`(1단계 ②)는 추출기 shape 으로 내고, SKILL 이 그것을 위 표대로
  `codex.ran`/`codex.failed` 로 옮긴다. **AC5 가 세 상태 각각을 실측한다.**

### 4.2 codex CLI 버전 바닥

이 설계는 `codex-cli 0.145.0` 실측에 의존하는데, stdin prompt(`-`)는 **`rust-v0.118.0` 에서
도입**됐다(PR #15917). 그 이전 버전에서는 동작하지 않는다.

- `detect_codex.sh` 는 이미 `codex --version` 을 파싱한다. **`0.118.0` 미만을 degrade** 시키고
  `skip_reason: version_below_floor` 를 낸다.
- **가시성**: `version_below_floor` 는 **visible** 이다(사용자가 조치할 수 있는 사유이므로
  `version known-bad` 와 같은 부류). §5.2③(c)의 표와 AC13 의 정규식 목록에 포함된다.
- **판독 실패 경로**: `detect_codex.sh:50` 은
  `CODEX_VERSION="$("$TIMEOUT_BIN" 5 codex --version 2>/dev/null | head -1 || echo unknown)"` 인데
  **`|| echo unknown` 은 도달하지 않는다** — `||` 가 파이프라인 전체에 걸리고 파이프라인의 종료
  코드는 `head` 의 것인데 `head -1` 은 **빈 입력에도 exit 0** 이다(실측:
  `bash -c 'v="$(true | head -1 || echo unknown)"'` → `v` 는 빈 문자열). 판독 실패의 실제
  관측값은 **빈 문자열**이고, 지금은 그 상태로 `codex_available: true` 가 나간다 —
  §4 의 `indeterminate ≠ clean` 위반이다.
  **그러므로 판정을 문자열 `unknown` 이 아니라 semver 파싱 성공 여부로 건다** —
  `MAJOR.MINOR.PATCH` 를 뽑지 못하면(빈 문자열 포함) `skip_reason: version_unreadable`, visible.
  (round-4 리뷰 적발 — `unknown` 을 키로 삼았다면 닫겠다고 선언한 fail-open 이 그대로 남았다.)
- 현행 known-bad 정규식(`0.120.0/1/2`)은 유지한다. 갱신 경로는 이 사이클 밖이다(brief OQ4).

**대안 비교**: 버전 문자열 대신 **능력 probe**(`codex exec - </dev/null` 이 `"No prompt provided
via stdin."` 를 내는지)로 stdin 지원을 직접 재는 방법이 있다. 더 정확하지만 **detect 단계가
codex 를 한 번 더 실행**해야 하고(현재는 `--version` 만), 그 실행이 auth·네트워크에 걸릴 수
있어 detect 를 무겁게 만든다. **버전 비교를 채택**하고, 능력 probe 는 버전 파싱이 실패하는
경우의 대체 수단으로 §11 에 남긴다.

### 4.3 실행 관측 기반 계약 검증

**round-2 리뷰가 정적 문법 접근을 무너뜨렸다**(§9 R10). 셸이 `codex exec` 를 쓸 수 있는 형태는
열거할 수 없고(다중행 · 변수 경유 · 바이너리 간접 · 마크다운), 열거하려는 시도 자체가 §4 의
"열거 금지"와 충돌하며, 앵커를 변수 이름에 두면 **피검자가 그 이름을 통제**한다.

**그래서 계약은 정적으로 읽지 않고 실행해서 관측한다.**

**메커니즘** — 리포에 이미 있는 mock 자산(`plugins/*/tests/mocks/`, `PATH=` 주입 선례
`test_codex_runner_degrade_contract.sh` 등)의 확장이다:

1. **캡처 mock**: `codex` 라는 이름의 실행 파일이 PATH 앞에 놓인다. 호출되면
   (a) argv 전체를 NUL 구분으로 `$CAPTURE/argv`, (b) stdin 전체를 `$CAPTURE/stdin`,
   (c) 호출 시각·cwd 를 `$CAPTURE/meta` 에 기록하고, 최소한의 유효 JSONL 을 내고 exit 0 한다.
   `--version` 은 바닥을 넘는 값을 답해 detect 를 통과시킨다.
2. **각 러너를 실제로 실행**한다 — 임시 scratch, PATH 에 mock 선행, 필요한 인자 주입.
3. **캡처 결과에 계약을 assert** 한다(§4.1 stdin 규약):
   - argv 에 `-` 가 있고, `-s read-only` · `-C <dir>` · `--json` 이 있다
   - argv 어디에도 **프롬프트 바이트가 등장하지 않는다**(프롬프트 파일 내용과 대조)
   - stdin 에 **프롬프트 바이트가 그대로 들어왔다**

**이 판정은 셸이 그 호출을 어떻게 썼는지에 무관하다** — 다중행이든 변수 경유든 간접 바이너리든
관측 결과가 같다. 주석은 애초에 실행되지 않으므로 주석 만족 문제도 발생하지 않는다.

**후보 발견은 여전히 정적 스캔이다** — 무엇을 실행할지는 알아야 하기 때문이다. 그러나 그 스캔의
역할이 바뀐다: **판정이 아니라 후보 수집**이다. 스캔이 놓친 호출부는 *"잘못된 통과"*가 아니라
*"검사되지 않음"*이고, 그 구분이 결정적이다.

**★ 커버리지는 증명하지 않는다 — vacuity 만 막는다.** 두 번의 시도가 실패했다:

- round-3 초안의 *"후보 집합 == 실행 집합"* 은 **순환적**이었다(codex block). 둘 다 같은 스캔에서
  나오므로 스캐너가 러너 하나를 놓치면 양쪽에서 함께 사라져 GREEN 이 된다.
- round-4 의 *"독립 두 축(피호출자 스캔 vs 호출자 SKILL 경로 추출)"* 도 실패했다(양쪽 리뷰어
  block). 축 B 는 qg SKILL 세 개의 `allowed-tools` 만으로 `.sh` 경로 **20건**(codex 무관 포함)을
  내므로 `A ≠ B` 가 자명하게 성립해 **첫 실행부터 RED** 다. 필터를 넣으면 독립성이 무너진다 —
  이름 패턴은 §9 R10(c)가 기각한 **피검자 통제 앵커**이고, *"codex 를 부르는가"* 는 **축 A 자신**이다.
  게다가 어떤 필터에서도 `A \ B ≠ ∅` 인 항목이 둘 확정돼 있다: `tests/spike/…`(어떤 SKILL 도
  부르지 않는 수동 spike)와 **1단계가 만드는 `run_audit_codex_reviewer.sh`**
  (`auditing-plugins/SKILL.md` 는 `allowed-tools` 가 없고 bash fence 가 0개다).

**세 번째 축은 없다.** 그러므로 이 문서는 *"모든 호출부를 발견했다"* 를 **주장하지 않는다.**
대신 리포가 이미 쓰는 형태를 따른다 — `test_codex_runner_no_effort_pin.sh:50-60` 의
`callsites` **positive 계수**:

- 후보 스캔이 찾은 파일은 **전부** 관측 대상이 돼야 한다(조용한 드롭 금지 — 찾고도 안 돌린 것이
  있으면 RED).
- 관측된 호출부 수가 **0 이면 RED**(계측기 붕괴 감지). 스캔이 눈멀면 이 positive 가 떨어진다.
- 스캔이 못 보는 형태(마크다운 인라인 등)는 **커버리지 갭으로 §10 에 열어 둔다** — 통과로 읽지
  않되, 없는 보장을 주장하지도 않는다.

**게이트 연결은 argv 관측으로 증명되지 않는다.** 실행 관측은 러너 *안*의 argv·stdin 만 보므로,
**호출자 책임인 detect·kill switch 가 러너 앞에 실제로 연결됐는지**는 말해주지 않는다.
kill switch 는 P21 보안 컨트롤이라 이 공백을 남기면 *"껐다고 믿게만"* 만든다.

round-4 리뷰가 초안의 게이트 분류가 **틀렸음**을 적발했다 — `reviewing-spec/SKILL.md` 의 codex
dispatch 조건은 `:81` **산문**이고 `:82-85` bash fence 는 **무조건 실행**된다(그 파일에
`codex_avail` 을 검사하는 `if` 가 없다). 리터럴인 것은 `reviewing-brief:219` **하나뿐**이었다.

그래서 이 사이클은 **분류를 고치는 대신 게이트를 고친다** — 관측 가능한 형태로 만든다:

| 진입점 | 현재 | 이 사이클의 조치 |
|---|---|---|
| `reviewing-brief:219` | 리터럴 `if [[ "$codex_avail" == "true" ]]` | 유지 — 그대로 관측 |
| `reviewing-spec:81` | **산문** | **리터럴 `if` 로 전환**(2단계, `reviewing-brief` 와 동형) |
| `auditing-plugins` | bash fence **0개** | 1단계가 러너를 만들며 **리터럴 게이트 블록도 함께** 넣는다 |
| qg `quality-pipeline` · `critiquing-artifacts` | 산문 | **이 사이클 범위 밖** — §10 에 미해결로 남긴다 |

전환된 진입점은 시나리오별 **mock 호출 횟수**로 잰다: 가용 → 1회 · kill switch → **0회** ·
미설치 → 0회 + 배너 · 버전 바닥 미달 → 0회 + 배너.

**마크다운 산문 호출부는 이 메커니즘 밖이다**(실행할 수 없으므로). 1단계가 plugin-audit 의
산문을 스크립트로 승격해 **범위 안에 남는 산문 호출부를 0 으로 만든다.** 그것이 이 사각의
근본 해법이고, 정규식을 백틱까지 넓히는 것은 해법이 아니다(`:37` 이 의도적으로 배제한
문자열 리터럴이 오탐으로 들어온다).

## 5. 설계

**단계 순서에는 이유가 있다.** round-2 리뷰가 지적한 대로, plugin-audit 을 나중에 두면 그
사이에 **carve-out**(검사가 알면서 놓아주는 예외)이 필요해지고 그 예외를 관리하려고 만료
장치·순서 제약·mutation 이 딸려 나온다 — 없어도 될 구조물이다. **plugin-audit 을 먼저 세우면
그 전부가 사라진다.** 그리고 그 시점부터 산문 호출부가 0 이 되어 §4.3 의 후보 스캔이
사각 없이 돈다.

### 5.1 1단계 — plugin-audit 을 규약 안으로

plugin-audit 은 지금 codex 를 **산문 지시로** 부른다(`skills/auditing-plugins/SKILL.md:92`).
그래서 여섯 가지가 동시에 비어 있다: 가용성 확인 · codex 전용 kill switch · `-C` · `--json` ·
stdin 규약 · **층 ④ 추출기**. 그리고 그 형태 때문에 sweep 의 락이 이 호출부를 못 본다(§1.2(d)).

#### ① 러너 신설

`scripts/run_audit_codex_reviewer.sh` — `-s read-only` · `-C` · `--json` · stdin 규약을 갖고,
형제 러너들의 기성 규약을 따른다(항상 exit 0, 신호는 파일, 시작 시 truncate, EXIT 트랩 degrade).
**프롬프트는 자기 `codex-prompt-preamble.md` 를 쓴다** — qg 빌더 재사용은 금지되어 있다(§4).

#### ② 층 ④ 추출기 신설

`scripts/codex_audit_to_json.py` — codex JSONL 을 plugin-audit 이 소비하는 shape 으로 바꾼다.
형제 추출기들의 기성 규약을 따른다: 마지막 `agent_message` 채택 · **마지막 fenced block 채택**
(중간 메시지 오채택 방지) · degrade 시 `meta.codex_failed` + `meta.reason` 방출 ·
`--stderr-file` · `--meta-override-exit-code` · `--meta-override-reason`.

**★ 소비자가 둘이다** — 초안은 이것을 하나로 뭉갰다(round-3 리뷰 적발, 실측 확인):

| codex 결과의 키 | 실제 소비자 | 근거 |
|---|---|---|
| `findings` (CX-*) | **`audit-workflow.js`** 의 `_args.codexFindings` | `:27` 수신 → `:572-580` refuter 검증 → `:582` `findings` 에 병합 → `:598` dedup |
| `d_verdicts` · `oq_answers` · `new_open_questions` | **`assemble-audit-data.py --codex-side`** | `:57-63` 이 이 셋만 읽어 `source: "codex"` 를 붙여 병합 |

`assemble()` 의 `findings` 는 `wf["findings"]` 에서만 온다(`:49`) — **`codex_side["findings"]` 를
읽는 코드는 없다.** 즉 codex findings 는 workflow 경로로 이미 들어와 있으므로 그 키를
`--codex-side` 로 또 넘기는 것은 무의미하다. `auditing-plugins/SKILL.md:97-98` 이 네 키를 한
문장으로 묶어 *"post-1 에서 `--codex-side` 로 넘긴다"* 라고 적은 것이 오해의 출처다 —
**같은 커밋에서 그 문장을 두 경로로 쪼갠다.**

따라서 이 추출기는 codex 결과 전체를 내고, SKILL 이 `findings` 는 workflow 로,
나머지 셋은 `--codex-side` 로 라우팅한다. **AC2 가 그 분기를 실측한다.**

이 파일이 **§11 선행 조건 (b)** — plugin-audit 출력 shape 확정 — 을 충족시킨다.

#### ③ detect + kill switch

`scripts/detect_codex.sh` 3번째 사본. kill switch 는 `DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX`.
게이트는 SKILL(호출자) 책임이고 러너는 그 변수를 읽지 않는다. §4.2 의 버전 바닥을 포함한다.

#### ④ degrade 상태 표현

`assemble-audit-data.py` 의 meta 에 `codex.failed` 를 추가해 §4.1 의 세 상태(미실행 / 실행-실패 /
실행-성공)를 표현한다. **`validate-audit-data.py:66-73`(B7)을 같은 커밋에서 갱신**한다 —
현재 그 검사는 `codex.ran == true` 이면 codex-source D/OQ 판정 존재를 강제하는데, "실행-실패"
상태는 `ran=true` 이면서 판정이 없으므로 **거짓 RED 가 난다**(round-2 리뷰 적발). 조건을
`ran == true AND failed == false` 로 좁힌다. 렌더러(`render-audit-report.py`)도 세 상태에 대해
서로 다른 문구를 낸다.

#### ⑤ ingestion 관문 확대

`assemble-audit-data.py` 의 `_sanitize_finding`(`:11-31`)이 `findings` 에만 걸려
`d_verdicts`·`oq_answers`·`new_open_questions` 는 정규화 없이 통과한다(`:50-63`) — malformed
입력에 `AttributeError`/`TypeError`/`KeyError` 로 죽는다. 같은 관문을 셋에 확대한다.

**"degrade" 의 의미를 못 박는다**(round-3 리뷰 적발 — 전체 거부 / 항목 삭제 / 기본값 대체 중
무엇인지 미정이었다). **항목별 삭제 + 손실 보고**를 채택한다:

- 각 컬렉션의 원소는 **dict 여야 하고 `id` 가 비어 있지 않은 문자열**이어야 한다. 위반 원소는
  **버리고**, 유효한 형제는 **보존한다**.
- 버린 개수와 사유를 `meta.codex.dropped` 에 남기고 렌더러가 그것을 배너로 낸다 —
  조용히 버리지 않는다(§4 loud logging).
- 컬렉션 자체가 list 가 아니면 그 컬렉션만 **빈 list 로 강등**하고 같은 자리에 사유를 남긴다.
  전체 입력을 거부하지 않는다 — 한 컬렉션의 오류가 나머지 감사 결과를 통째로 버리게 하면
  손실이 더 크다.
- **부분 파싱의 일반형**(finding 단위 재검증 · `droppedFindings`)은 §11 소관이다. 여기서는
  이 세 컬렉션에 대한 위 규칙만 확정한다.

### 5.2 2단계 — 결함

#### ① 변환기 fail-open 봉쇄 + 갈라짐 감지 락 (같은 커밋)

spec-distill 사본의 CR-2 검증을 quality-gates 사본에 이식한다.

**같은 커밋에 갈라짐 감지 락을 넣는다** — 이 결함이 정확히 그 락의 부재로 생겼기 때문이다(Law 3).
락은 파일 diff 가 아니라 **행동**을 잰다: 두 사본에 같은 입력 표본을 넣어 같은 `codex_failed` ·
`reason` 이 나오는지. 표본은 `{"findings": {}}` · `{"findings": [1,2]}` · 정상 · 빈 스트림 ·
펜스 없는 raw JSON · exit code override 유/무.

`detect_codex.sh` 세 사본에도 같은 락을 건다. **kill switch 변수명은 의도된 차이**이므로 그 축만
파라미터로 뺀다 — 순진하게 걸면 첫 실행부터 RED 다. §4.2 의 버전 바닥은 **공통 축**이므로
파라미터로 빼지 않는다.

spec-distill 사본 머리의 주장 *"ONLY adaptation … the emit keyset"* 은 거짓이므로 함께 정정한다.

#### ② 프롬프트를 stdin 으로

```bash
# before (직접 치환 — 러너 4곳)
codex exec "$(cat "$PROMPT_FILE")" \
    -C "$PROJECT_DIR" \
    -s read-only \
    --json \
    < /dev/null > "$STDOUT_FILE" 2>"$STDERR_FILE"

# before (변수 경유 — spike)
PROMPT="$(cat "$PROMPT_FILE")"
…
"$TIMEOUT_CMD" 600 codex exec "$PROMPT" \
    -C "$REPO_ROOT" \
    -s read-only \
    --json \
    < /dev/null > "$STDOUT_FILE" 2>"$STDERR_FILE"

# after (양쪽 공통)
codex exec - \
    -C "$PROJECT_DIR" \
    -s read-only \
    --json \
    < "$PROMPT_FILE" > "$STDOUT_FILE" 2>"$STDERR_FILE"
```

**실제 호출부는 전부 다중행 continuation 이다.** 위 형태를 그대로 쓴다.

1. **`< /dev/null` 을 제거한다.** 남기면 교착이 아니라 `"No prompt provided via stdin."`
   \+ exit 1 이 된다.
2. **`-` 를 명시한다.**
3. **프롬프트 바이트가 바뀐다.** `$(...)` 는 셸이 후행 개행을 삭제하는데 stdin 은 보존한다.
   착수 전에 프롬프트 바이트를 assert 하는 테스트가 있는지 확인한다.

`< /dev/null` 자체는 옛 버그 우회가 아니다 — stdin 을 프롬프트로 쓰지 **않는** 호출부에서는
현재도 필수이며, 그 교착은 PR #15917 로 `rust-v0.118.0` 에 **도입**돼 issue #20919 로 아직
OPEN 이다. 러너 주석이 *"some codex versions"* 로 방향을 거꾸로 쓴 것도 정정한다.

**판정은 §4.3 의 실행 관측이 한다.** V2(§8.3)가 실제 codex 로 한 번 더 확인한다.

#### ③ 빨간 테스트 4건

**(a) 죽은 락의 과녁을 옮긴다.** `test_sandbox_enforced.sh` 를 §4.3 의 **실행 관측**으로
재작성하고, 좀비 파서 `tests/lib/extract_codex_invocations.py` 는 **후보 수집기**로 되살린다
(판정 책임은 지지 않는다). 1단계가 이미 끝났으므로 **carve-out 이 필요 없다** — plugin-audit
러너가 다른 러너와 같은 관측 대상이다.

**(b) kill switch 를 SKILL 에 되돌리고, 이빨 없는 assert 에 이빨을 준다.**
`quality-pipeline/SKILL.md` 에 `DEVBREW_DISABLE_QG_CODEX` 를 문서화한다(그 파일 `AC42` 는
alternation 이므로 하나로 충족). `test_codex_reviewer_frontmatter.sh` 의 `-s read-only` assert 는
**§4.3 관측으로 대체**한다 — 정적 grep 을 정교화하지 않는다.

**(c) skip 사유를 사용자에게 보인다.** `quality-pipeline/SKILL.md` 에 다음을 추가한다.
`test_skill_codex_skip_prose.sh` 가 **정규식으로** 매칭하므로 아래를 그대로 만족시켜야 한다.

- 섹션 헤더: **`Codex skip 안내`**(그 파일 `AC21` 이 리터럴로 grep).
- visible 사유는 각각 최소 1회 등장. 기존 4종 —
  `Codex CLI not installed` · `auth missing` · `no .*timeout` · `version known-bad` —
  에 §4.2 가 추가하는 2종(`version_below_floor` · `version_unreadable`)을 더해 **6종**.
  **세 번째는 리터럴이 아니라 패턴**이므로 한국어 문장으로는 만족되지 않는다. 영문 토큰을 싣는다.
- silent 2종(`kill_switch` · `inside_codex_sandbox`)은 사용자향 메시지를 갖지 않는다.
  그 파일 `AC20` 은 `\[quality-gates\][^\n]*<reason>` 과 `Codex skipped[^\n]*<reason>` 을
  금지하므로, 정책 표에서 이 두 값을 언급하는 줄에 **`[quality-gates]` 접두사나
  `Codex skipped` 문구를 같은 줄에 두지 않는다.**

배너 문구: `[quality-gates] codex 리뷰 미실행 (<사유>) — 이 리뷰에는 모델 다양성이 없었다 (degraded).`

**(d) `test_codex_backward_compat.sh` 는 직접 조치하지 않는다.** 파생 실패이며 (b)·(c)로
4건 → 2건으로 개선된다. **그러나 이 테스트 자체는 여전히 RED 다** — 남는 2건이 `:81` 의
제외 목록에 없기 때문이다. AC17 이 그 산술을 반영한다.

#### ④ 거짓 주장이 참이 됐음을 확인

1단계가 plugin-audit 산문을 스크립트로 바꿨으므로 `test_codex_runner_no_effort_pin.sh:43-44` 의
주석은 이제 **참이다**. 커버리지가 실제로 0 이 아님을 확인하고, 주석에 그 근거(1단계 러너)를 적는다.

### 5.3 3단계 — 나머지 통일

#### ① 프롬프트 주입 방어를 4곳에 확대

현재 `plugin-audit/scripts/codex-prompt-preamble.md` 만 untrusted-data 절을 싣는다. 나머지 codex
경로 4곳은 미신뢰 콘텐츠를 먹이면서 이 방어가 없고, **Claude 쪽 쌍둥이에는 있다**
(`security-reviewer.md:23`, `artifact-critic.md:57-62`). 가장 첨예한 것은 brief 리뷰다 —
Claude critic 은 **가려진 사본**을 받는데 codex 는 **원본 payload** 를 받고,
`merge_brief_review.py:79-81` 이 그 §6 을 *"비신뢰 verbatim"* 이라고 명시한다.

**대안 비교**: 구조적 격리(신뢰/미신뢰를 별도 채널로)가 문구보다 강하나 `codex exec` 는 프롬프트
채널이 하나뿐이라 쓸 수 없다. 태그 구획은 문구와 같은 층이고 추가 이득이 미검증이다.
**따라서 이 사이클은 이미 운용 중인 문구의 전파에 그친다** — 적대적 효과 측정은 §11.

**주의**: "injection" 이 **세 위협**을 덮는다 — argv/stdin → 셸(빌더 4개가 이미 방어) ·
읽는 내용 → 모델 지시(이 항목) · 모델 출력 → 어느 fence 를 믿나(추출기가 이미 방어).

#### ② 웹 posture 를 6곳에서 명시

설정 키가 **둘**임이 실측으로 확인됐다(`--strict-config` + 대조군 — 거짓 키는
`unknown configuration field` 로 거부된다):

| 키 | 뜻 | 값 |
|---|---|---|
| `tools.web_search` | 도구를 주느냐 | `true` 또는 `{context_size, allowed_domains, location}` |
| `web_search` | 어느 모드로 검색하느냐 | `disabled` · `cached`(**기본**) · `indexed` · `live` |

`cached` 는 공식 문서상 *"an OpenAI-maintained index without external web access"* 다.
현행 `run_brief_codex_reviewer.sh:96` 은 **도구만** 켜는데 그 리뷰어의 checklist 는 외부
prior-art 를 요구한다.

**V1 이 이 항목을 게이트한다**(§8.3). 두 결과에 대한 조치를 미리 확정한다:

- **도구만 켜도 외부 검색이 된다** → 문서·brief 는 현행 유지, 코드 diff 에 `tools.web_search=false` 명시.
- **도구만으로는 cached 에 머문다** → 문서·brief 에 `web_search="live"` 추가, 코드 diff 에
  `web_search="disabled"` 명시.

**`test_web_kill_switch.sh` 를 같은 커밋에서 갱신한다**(round-2 리뷰 적발). 그 락은 `:37` 에서
`tools.web_search` 를 가진 `$SD/scripts/*.sh` 를 소비자로 **도출**하고 `:42` 에서
`DEVBREW_SPEC_DISTILL_DISABLE_WEB` 확인을 요구한다 — 웹을 명시하는 순간
`run_spec_codex_reviewer.sh` 가 그 집합에 들어오는데 확인 코드가 없어 **현재 GREEN 인 테스트가
RED 가 된다**. 러너에 kill switch 확인을 함께 넣는다. qg·plugin-audit 의 웹 kill switch 변수명도
이때 선언한다(`DEVBREW_DISABLE_QG_WEB` · `DEVBREW_DISABLE_PLUGIN_AUDIT_WEB`) — AC23 가 그 검사를
플러그인 횡단으로 도출로 바꾸는 순간 필요해진다.

`allowed_domains` 로 도메인을 제한하지 않는다 — prior-art 검색은 어느 도메인이 중요할지 미리
알 수 없어 좁히면 조사 능력을 깎는다(§4 억제 금지).

#### ③ degrade 어휘 — 별칭 한 쌍만 합친다

| 이름 | 정체 |
|---|---|
| `codex_failed` / `codex_degraded` | **같은 술어의 두 이름**(`merge_review.py:441` → `:504` 항등) |
| `codex_yaml_missing` | 술어가 아니라 **reason 값** |
| `sources_failed` | **진짜 다른 술어** — 개수 카운터, codex 전용 아님 |
| `codex.ran` / `codex.failed` | **진짜 다른 술어** — 1단계가 쌍으로 만든 것 |

`codex_degraded` 의 정의를 **한 곳**(`merge_review.py`)에만 두고 다른 파일의 독립 정의를 없앤다.

**quality-gates 코드리뷰 경로의 배너**: `synthesize_findings.py`(502줄)에 `meta`·`codex` 언급이
0건이라 결정론 소비자가 없다. 그 경로는 러너가 쓴 YAML 을 SKILL 오케스트레이터가 직접 읽으므로
**배너를 SKILL 레이어에 건다** — `quality-pipeline/SKILL.md` 가 §4.1 규칙 2·3(파일 부재/0바이트,
양성 표식 부재)을 읽어 배너를 내도록 명시하고, AC24 이 그것을 잰다.

#### ④ 열거를 도출로

| 검사 | 열거된 것 |
|---|---|
| `test_codex_runner_no_effort_pin.sh:124` | qg 러너 2개 |
| `test_codex_runner_degrade_contract.sh` | 러너 1개 |
| `test_web_kill_switch.sh:11` | spec-distill 1개 플러그인 |
| `test_codex_backward_compat.sh:81` | 제외 목록 7개 이름 |

`test_web_kill_switch.sh` 의 도출 패턴을 전파한다.

**★ `:81` 의 7개 이름은 blessed-red 목록이 아니다**(round-4 리뷰 적발 — 초안이 이것을 오독했다).
`:72-74` 주석이 밝히듯 그것은 *"codex 를 건드리는 테스트 제외 + **자기 제외**"* 다. 그리고 같은
목록의 **두 번째 사본이 `:100`** 에 있다.

초안처럼 그 7개를 *"검토된 두 건"* 으로 **교체하면** `test_codex_backward_compat.sh` 가 자기
제외에서 빠져 `:78` 의 glob 가 **자기 자신을 bash 로 재실행**한다 — 198초 × 무한 재귀다.

**그러므로 두 층으로 분리한다:**

1. **구조적 제외(기존 7개, 유지)** — codex 를 건드리는 테스트 + 자기 자신. 이것은 이 메타
   테스트가 *무엇을 재는가* 의 정의이지 red 축복이 아니다. `:81` 과 `:100` 의 **사본을 한 곳으로
   뽑아내는 것을 같은 커밋에** 넣는다(사본이 갈라지면 이 문서가 §1.2(a)에서 고치는 병과 같은 모양).
2. **fingerprint baseline(신규 추가 층)** — 구조적 제외를 통과한 뒤에도 실패하는 것 중
   *검토를 마친* 항목만 `<테스트 파일명> <실패 출력의 sha256>` 쌍으로 등재한다. 현재 대상은
   `test_consent_marker_write_failure.sh` · `test_security_reviewer_kill_switch.sh` 둘이다.
   - **미등재이거나 fingerprint 가 달라진 실패는 항상 RED** — 같은 파일이 *다른 이유로* 실패하기
     시작하면 해시가 바뀌어 잡힌다.
   - **등재됐는데 GREEN 이 된 항목도 RED** — stale 등재를 남기지 않는다(양방향).
   - ⚠ **채취 표면이 미정이다**(round-4 지적, §10) — 현행 루프는 `> /dev/null 2>&1` 로 출력을
     버리므로 채취 자체가 코드 변경을 요구하고, 등재 대상 하나는 이 설계가 편집하는
     `quality-pipeline/SKILL.md` 의 grep 카운트를 출력한다. 구현 시 stdout/stderr 범위와
     경로·카운트 정규화를 먼저 정한다.

#### ⑤ 복사본 나머지 두 종

mock 6그룹은 갈라짐 행동 락으로 덮는다. `test_detect_codex.sh` 두 벌은 **합집합**으로 만든다 —
기존 12 케이스 + §4.2 가 추가하는 2 케이스(바닥 미달 · 판독 불가) = **14**.

## 6. Acceptance Criteria

> **번호 규약** — `AC1`~`AC26` 는 **이 문서 소유**다. 기존 테스트 파일이 자기 안에서 쓰는 AC 이름
> (예: `test_skill_codex_skip_prose.sh` 의 `AC19`)은 **별개 네임스페이스**이며, 인용할 때는 항상
> 소유 파일명을 함께 적는다.

### 1단계 — plugin-audit

- **AC1** `plugin-audit/scripts/run_audit_codex_reviewer.sh` 가 존재하고, §4.3 실행 관측에서
  `-` · `-s read-only` · `-C <dir>` · `--json` 을 argv 에 갖고 프롬프트를 stdin 으로 넘긴다.
- **AC2** `plugin-audit/scripts/codex_audit_to_json.py` 가 codex JSONL 을 변환하고, 마지막
  `agent_message` + 마지막 fenced block 을 취하며, degrade 시 `meta.codex_failed` +
  `meta.reason` 을 낸다. **그리고 SKILL 이 결과를 두 경로로 라우팅한다** — `findings` 는
  `audit-workflow.js` 의 `codexFindings` 로, `d_verdicts`·`oq_answers`·`new_open_questions` 는
  `assemble-audit-data.py --codex-side` 로. `SKILL.md:97-98` 의 네 키를 한 문장으로 묶은 서술이
  같은 커밋에서 두 경로로 쪼개진다.
- **AC3** plugin-audit 이 detect 게이트를 거치고 `DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX` 를
  존중한다. 러너는 그 변수를 읽지 않는다(게이트는 호출자 책임).
- **AC4** 새 러너 파일에서 `build_codex_prompt|build_artifact_codex_prompt|
  build_spec_codex_prompt|build_brief_codex_prompt` 매칭이 **0건**이다(blind 보존).
- **AC5** plugin-audit meta 가 `codex.ran` 과 `codex.failed` 를 함께 갖고 §4.1 truth table 의
  세 상태를 구분한다 — **세 상태 각각을 실제로 만들어 관측한다**(게이트 차단 / 러너 실패 /
  정상). `validate-audit-data.py` 의 B7 이 `ran == true AND failed == false` 로 좁혀져
  "실행-실패"에 거짓 RED 를 내지 않는다. 렌더러가 세 상태에 서로 다른 문구를 낸다.
- **AC6** `assemble-audit-data.py` 의 ingestion 관문이 `findings` 외에 `d_verdicts` ·
  `oq_answers` · `new_open_questions` 에도 걸린다. §5.1⑤ 규칙대로 **위반 원소만 버리고 유효한
  형제는 보존**하며, 버린 개수·사유가 `meta.codex.dropped` 를 거쳐 배너로 나온다. 컬렉션 자체가
  list 가 아니면 그 컬렉션만 빈 list 로 강등하고 전체 입력을 거부하지 않는다. 어느 경우에도
  예외로 죽지 않는다.
- **AC7** 1단계 종료 시 §4.3 후보 스캔이 **`run_audit_codex_reviewer.sh` 를 찾는다** —
  착수 전 오늘은 plugin-audit 전체에서 스캔 결과가 0건이므로(백틱 선행 산문, 실측) 이 AC 는
  **착수 전 FALSE → 착수 후 TRUE** 로 전이한다. (round-4 리뷰 적발: 초안의 *"산문 호출부가 0"* 은
  계측기가 산문을 볼 수 없어 **착수 전에 이미 참**인 vacuous AC 였다.)

### 2단계 — 결함

- **AC8** `{"findings": {}}` 입력에 두 변환기가 **같은** `codex_failed: true` +
  `reason: schema_mismatch` 를 낸다.
- **AC9** 비-dict 원소(`{"findings": [1, 2]}`)에 두 변환기가 같은 판정을 내고
  `bad_element_types` 를 emit 한다.
- **AC10** 갈라짐 감지 락이 존재하고, 한쪽 사본만 변경하는 mutation 에 RED 가 된다.
  kill switch 변수명만 다른 상태에서는 GREEN 이다.
- **AC11** §4.3 실행 관측이 후보 스캔이 찾은 **모든** 러너에 대해 §4.1 stdin 규약을 확인한다 —
  argv 에 프롬프트 바이트 부재 · stdin 에 프롬프트 바이트 존재 · `-`·`-s read-only`·`-C`·`--json`
  존재. **찾고도 안 돌린 것이 있으면 RED**, 관측된 호출부 수가 **0 이면 RED**(계측기 붕괴).
  **이 AC 는 커버리지를 주장하지 않는다** — 스캔이 못 보는 형태는 §10 의 열린 갭이다.
  argv 대조는 프롬프트 파일 바이트와의 **완전 일치가 아니라 부분 문자열 포함**으로 판정한다
  (round-4 지적: `$(cat f)` 는 후행 개행을 삭제하므로 완전 일치 비교는 누출을 놓친다).
- **AC12** 리터럴 게이트를 가진 **세 진입점**(`reviewing-brief` 기존 · `reviewing-spec` 전환 ·
  `auditing-plugins` 신규)에서 **mock 호출 횟수**가 시나리오별로 맞는다 —
  가용 1회 · kill switch **0회** · 미설치 0회+배너 · 버전 바닥 미달 0회+배너.
  quality-gates 의 두 산문 게이트는 이 사이클 범위 밖이며 §10 에 **미해결로** 남는다.
- **AC13** `quality-pipeline/SKILL.md` 에 `Codex skip 안내` 섹션이 있고 visible **6종**
  (`Codex CLI not installed` · `auth missing` · `no .*timeout` · `version known-bad` ·
  `version_below_floor` · `version_unreadable`)이 각각 최소 1회 매칭되며,
  `kill_switch`·`inside_codex_sandbox` 를 언급하는 줄에 `[quality-gates]` 접두사나
  `Codex skipped` 문구가 **같은 줄에 없다**.
- **AC14** `quality-pipeline/SKILL.md` 에 `DEVBREW_DISABLE_QG_CODEX` 가 등장한다.
- **AC15** 세 detect 사본이 §4.2 의 바닥(`0.118.0` 미만 → `version_below_floor`)과 판독 실패
  (`unknown` → `version_unreadable`)를 갖고, 갈라짐 락이 그 축을 **공통으로** 판정한다.
- **AC16** `test_codex_runner_no_effort_pin.sh:43-44` 주석이 참이 됐음을 확인한다 —
  plugin-audit 커버리지가 0 이 아니고, 주석이 그 근거(1단계 러너)를 적는다.
- **AC17** 2단계 종료 시 bash 스위트 RED 는 baseline 6건에서 **3건**으로 줄어든다 —
  codex 무관 2건 + 그 둘 때문에 계속 실패하는 `test_codex_backward_compat.sh` 1건.
- **AC18** §4.1 규칙 1 의 동등성이 확인된다 — `codex exec` 가 비영점 exit 을 낸 실행에서
  최종 산출물이 `codex_failed: true` 다(추출기를 계속 돌리는 현행 흐름에서도).
- **AC19** V2(§8.3)가 통과했고 그 증거물이 `docs/audits/<실행일 YYYY-MM-DD>-codex-stdin-v2/` 에
  §8.3 의 증거물 정책대로 보존됐다 — manifest(대상 커밋 SHA · 러너별 sha256 · `codex --version` ·
  실행 명령 · 판정) + 관측 argv(프롬프트 바이트 제외) + stdin 바이트수·sha256 + 산출물의
  `meta:` 블록 + stderr. **원시 프롬프트와 JSONL 전문은 보존하지 않는다**(P21).
  manifest 의 러너 해시가 현재 소스와 다르면 그 증거는 stale 이다.
  **이 AC 없이는 2단계를 닫지 않는다.**

### 3단계 — 나머지 통일

- **AC20** codex 프롬프트 4종 전부에 untrusted-data 절이 있다. 판정은 소스 주석이 아니라
  **각 빌더를 실행해 방출된 프롬프트 문자열**에서 한다.
- **AC21** codex 호출부 6곳 각각이 **아래 표의 값과 일치**한다 — 존재만 확인하지 않는다
  (round-3 리뷰 적발: 전부 `disabled` 로 둬도 통과하는 AC 였다). `test_web_kill_switch.sh` 가
  같은 커밋에서 갱신되어 GREEN 을 유지한다.

  | 호출부 | `tools.web_search` | `web_search` 모드 | 웹 kill switch |
  |---|---|---|---|
  | `run_codex_reviewer.sh` (코드 diff) | `false` | `disabled` | 해당 없음(이미 OFF) |
  | `run_artifact_codex_reviewer.sh` (산출물) | `false` | `disabled` | 해당 없음 |
  | `run_spec_codex_reviewer.sh` (design doc) | `true` | V1 분기표 | `DEVBREW_SPEC_DISTILL_DISABLE_WEB` |
  | `run_brief_codex_reviewer.sh` (brief) | `true` | V1 분기표 | `DEVBREW_SPEC_DISTILL_DISABLE_WEB` |
  | `run_audit_codex_reviewer.sh` (감사) | `true` | V1 분기표 | `DEVBREW_DISABLE_PLUGIN_AUDIT_WEB` |
  | `spike/test_codex_json_extraction.sh` | `false` | `disabled` | 해당 없음 — 수동 spike |

  **spike 를 OFF 로 두는 이유**: JSONL shape 을 재는 것이 목적이라 외부 검색이 결과를
  비결정적으로 만든다. **plugin-audit 을 ON 으로 두는 이유**: 감사 preamble 이 외부 근거를
  요구하고, 그 경로는 이미 P21 preamble 을 가진 유일한 경로다.
- **AC22** `codex_degraded` 가 `codex_failed` 에서 파생됨이 **한 곳에서만** 정의된다.
- **AC23** §5.3④ 표의 검사 4종이 대상을 도출한다. 새 러너를 추가하는 mutation 에 자동 포함된다.
  `test_codex_backward_compat.sh` 는 **두 층**을 갖는다 — ① 기존 구조적 제외 7개(codex 테스트 +
  **자기 자신**)를 **유지**하고 `:81`/`:100` 사본을 한 곳으로 뽑아낸다, ② 그 위에 fingerprint
  baseline 을 **추가**해 `<파일명> <실패 출력 sha256>` 쌍으로 검토된 2건만 등재한다.
  **미등재·해시 불일치 실패는 RED**, **등재됐는데 GREEN 이 된 항목도 RED**.
  ⚠ 자기 제외를 빼면 `:78` glob 가 자기를 재귀 실행한다(198초 × ∞) — 교체가 아니라 추가다.
- **AC24** quality-gates 코드리뷰 경로에서 §4.1 규칙 2·3(파일 부재/0바이트, 양성 표식 부재)이
  배너로 사용자에게 닿는다 — SKILL 레이어가 그 판정을 수행한다.
- **AC25** `test_detect_codex.sh` 두 벌이 각각 14 케이스 합집합을 갖는다.
- **AC26** mock 6그룹이 갈라짐 행동 락의 대상이다.

## 7. Files to Modify

### 1단계

| 파일 | 변경 |
|---|---|
| `plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh` | **신규** |
| `plugins/plugin-audit/scripts/codex_audit_to_json.py` | **신규** (층 ④ 공백) |
| `plugins/plugin-audit/scripts/detect_codex.sh` | **신규** (3번째 사본 + §4.2) |
| `plugins/plugin-audit/skills/auditing-plugins/SKILL.md` | 산문 → 러너 호출 · **리터럴 bash 게이트 블록**(현재 bash fence 0개) · kill switch · `findings`/나머지 셋 라우팅 분리 |
| `plugins/plugin-audit/scripts/assemble-audit-data.py` | `codex.failed` · 관문 확대 |
| `plugins/plugin-audit/scripts/validate-audit-data.py` | B7 조건 좁히기 (**같은 커밋**) |
| `plugins/plugin-audit/scripts/render-audit-report.py` | 세 상태 문구 |
| `plugins/plugin-audit/.claude-plugin/plugin.json` + `CHANGELOG.md` | bump |

### 2단계

| 파일 | 변경 |
|---|---|
| `plugins/quality-gates/scripts/codex_findings_to_yaml.py` | CR-2 검증 이식 |
| `plugins/spec-distill/scripts/codex_findings_to_yaml.py` | 헤더 주장 정정 |
| `plugins/quality-gates/tests/test_codex_copies_agree.sh` | **신규** — 갈라짐 행동 락 |
| `plugins/quality-gates/tests/mocks/capture-codex/codex` | **신규** — argv·stdin 캡처 mock |
| `plugins/quality-gates/tests/test_codex_invocation_contract.sh` | **신규** — §4.3 실행 관측 |
| `plugins/*/scripts/detect_codex.sh` (3) | §4.2 바닥 + 판독 실패 |
| `plugins/{quality-gates,spec-distill}/scripts/run_*codex*.sh` (4) | argv → stdin |
| `plugins/quality-gates/tests/spike/test_codex_json_extraction.sh` | argv → stdin |
| `plugins/quality-gates/tests/lib/extract_codex_invocations.py` | 후보 수집기로 부활 |
| `plugins/quality-gates/tests/test_sandbox_enforced.sh` | §4.3 관측으로 재작성 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | kill switch + `Codex skip 안내` |
| `plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh` | §4.3 관측으로 대체 |
| `plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh` | 주석을 사실로 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | `:81` 산문 조건 → 리터럴 `if [[ "$codex_avail" == "true" ]]` (`reviewing-brief:219` 와 동형) |
| `plugins/quality-gates/tests/test_skill_codex_skip_prose.sh` | visible 4종 → **6종**(§4.2 가 추가하는 둘) |
| `plugins/{quality-gates,spec-distill}/tests/test_detect_codex.sh` | 바닥·판독실패 케이스 |
| 2 플러그인 `plugin.json` + `CHANGELOG.md` | bump |

### 3단계

| 파일 | 변경 |
|---|---|
| `plugins/{quality-gates,spec-distill}/scripts/build_*codex*prompt.py` (4) | untrusted-data 절 |
| 러너 5 + spike | 웹 명시 |
| `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh` | 웹 kill switch 확인 (**같은 커밋**) |
| `plugins/spec-distill/tests/test_web_kill_switch.sh` | 갱신 (**같은 커밋**) · 플러그인 횡단 도출 |
| `plugins/spec-distill/scripts/merge_review.py` | 별칭 단일 정의 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | 코드리뷰 경로 배너 |
| `test_codex_runner_degrade_contract.sh` · `test_codex_backward_compat.sh` | 열거 → 도출 |
| mock 6그룹 | 갈라짐 락 대상 편입 |
| 3 플러그인 `plugin.json` + `CHANGELOG.md` | bump |

## 8. Verification Plan

### 8.1 baseline

2026-08-06 main(`a4e7fa2`) 실측: **bash 134개 중 pass 128 / fail 6**. 6 RED 전부 quality-gates.
그중 codex 관련 4건이 이 설계의 대상이고, 나머지 2건(`test_consent_marker_write_failure.sh` ·
`test_security_reviewer_kill_switch.sh`)은 범위 밖이다.

**커밋 유효성**: 각 커밋은 이 baseline 을 유지하거나 개선해야 한다. **기존 GREEN 테스트를 RED 로
만드는 변경은 그 테스트 갱신을 같은 커밋에 넣는다** — 알려진 사례 둘: AC5 의 B7(1단계),
AC21 의 `test_web_kill_switch.sh`(3단계).

python 스위트는 별도로 캡처한다. spec-distill 의 python 테스트는 `-m unittest` 로만 돌고
**repo root 에서** 실행해야 경로가 맞는다.

### 8.2 mutation 시나리오

| 락 | mutation | 기대 |
|---|---|---|
| 갈라짐 락(AC10) | qg 사본에서 CR-2 검증 블록만 삭제 | RED |
| 갈라짐 락(AC10) | sd 사본의 kill switch 변수명만 변경 | GREEN(의도된 차이) |
| 갈라짐 락(AC15) | 한 사본의 버전 바닥만 삭제 | RED |
| 계약 관측(AC11) | 한 러너를 `codex exec "$(cat …)"` 로 되돌림 | RED (argv 에 프롬프트 바이트 출현) |
| 계약 관측(AC11) | **변수 경유로 우회** — `P="$(cat f)"` … `codex exec "$P"` | RED (관측은 형태에 무관) |
| 계약 관측(AC11) | **간접 바이너리로 우회** — `CODEX=codex; "$CODEX" exec …` | RED (같은 이유) |
| 계약 관측(AC11) | `< /dev/null` 을 continuation 줄에 되살림 | RED (stdin 이 비어 관측됨) |
| 계약 관측(AC11) | 한 러너에서 `--json` 삭제 | RED |
| 계약 관측(AC11) | 헤더 주석에만 `-s read-only` 를 남기고 invocation 에서 삭제 | RED (주석은 실행되지 않음) |
| 후보 교차검사(AC11) | 후보 스캔이 한 러너를 놓치도록 정규식 훼손 | RED (후보≠실행 집합, 또는 플러그인 하한 미달) |
| B7 좁히기(AC5) | B7 을 `ran == true` 로 되돌리고 실행-실패 상태 투입 | RED |
| 관문 확대(AC6) | `d_verdicts` 에 비-dict 원소 투입 | 예외 아닌 degrade |
| skip 안내(AC13) | visible 사유 1개 삭제 | RED |
| skip 안내(AC13) | silent 사유를 `[quality-gates]` 접두사 줄에 언급 | RED |
| 주입 방어(AC20) | 한 빌더의 절을 소스 주석으로만 남기고 방출 프롬프트에서 제거 | RED |
| 웹 명시(AC21) | 한 호출부의 웹 인자 삭제 | RED |
| 도출 락(AC23) | 새 러너 추가 후 락 파일 무변경 | 새 러너가 자동 검사 대상 |
| blind 락(AC4) | 새 러너에서 qg 빌더를 호출 | RED |

**계측기 자체를 의심한다**: mutation 이 도달 불가한 위치에 착지하거나 전제를 붕괴시키면
GREEN 이 난다. **그리고 mutation 이 신규 락이 아니라 기존 락에 잡히고 있지 않은지 확인한다** —
`-s read-only` 삭제는 기존 `test_codex_runner_no_effort_pin.sh:99-120` 도 잡으므로, 위 표의
해당 행은 **신규 계약 테스트만 단독 실행**해 귀속을 확정한다.

### 8.3 실행 검증 (네트워크 필요)

- **V1 — 웹 모드.** **`web_search` item 의 출현 여부는 판별에 쓸 수 없다**(round-3 리뷰 적발) —
  그 item 은 cached 인덱스 조회에서도 나타나므로 모드 승격을 증명하지 못한다. 대신 **cached 가
  가질 수 없는 사실**을 묻는다: 프롬프트에 *"방금 만든 nonce 문자열이 포함된 URL 을 열어
  그 문자열을 그대로 답하라"* 를 넣고, 그 URL 을 실행 직전에 공개 위치(예: 이 리포의
  최신 커밋을 가리키는 GitHub raw 링크)에 만든다. **답이 nonce 를 담으면 live, 못 담으면
  cached** 다. `tools.web_search=true` 단독 · `+ web_search="live"` 두 조건으로 각 1회.
  **3단계 §5.3② 를 게이트하고**, 판정과 증거물을 남긴다.
- **V2 — stdin 전환 실동작.** 전환된 5개 호출부가 각각 최소 1회 실제 codex 로 실행되어 정상
  산출물을 내는지. **2단계를 게이트한다(AC19).**
  **증거물 정책**(round-3 리뷰 적발 — 출처·민감정보·보존 규칙이 없었다):
  - 경로는 `docs/audits/<실행일 YYYY-MM-DD>-codex-stdin-v2/` — `<실행일>` 은 V2 를 실제로
    수행한 날짜로 치환한다.
  - **manifest 를 함께 남긴다**: 대상 커밋 SHA · 러너 파일별 `sha256` · `codex --version` ·
    실행 명령 · 판정. 나중에 이 manifest 의 러너 해시가 현재 소스와 다르면 그 증거는
    **stale 로 간주**한다(오래된 로그 재사용 방지).
  - **원시 프롬프트와 JSONL 전문은 보존하지 않는다.** 프롬프트에서 파생된 코드 조각과 모델
    출력이 리포에 영구 보존되는 것을 막는다(P21). 남기는 것은 관측된 argv(프롬프트 바이트를
    제외한 플래그만) · stdin **바이트 수와 sha256** · 산출물 YAML 의 `meta:` 블록 ·
    러너 stderr 다. 본문이 필요하면 해시로 대조한다.
- **V3 — degrade 실동작.** kill switch · 미설치(PATH 조작) · auth 실패(mock) · 버전 바닥 미달 ·
  버전 판독 불가 각 경로를 실제로 태워 배너가 사용자에게 보이는지. **문구 grep 만으로는
  충족되지 않는다** — AC13 의 grep 은 필요조건이고 이 실행이 충분조건이다.
- **V4 — plugin-audit 러너.** 새 러너 + 추출기가 detect 게이트 · kill switch · 세 상태 표현 ·
  `--codex-side` shape 변환을 실제로 수행하는지. **1단계를 게이트한다.**

## 9. Rejected Alternatives

- **R1 — 마켓플레이스 내부 symlink 로 물리 통합.** git 소스가 하나가 되어 drift 가 원천 제거된다.
  **상태: 조사 미완결, 사용자가 추진하지 않기로 결정.** 미확인으로 남은 것은 (a) symlink
  dereference 가 일반 파일에도 적용되는지(문서 예시가 디렉토리뿐), (b) `--plugin-dir` 설치에서
  skip 된다는 문서 진술의 실제 영향 — devbrew 는 그 방식을 주 검증 수단으로 쓴다. **이 둘은
  기각의 기술적 근거가 아니라 조사 대상**이며, 사용자가 이번 사이클에서 조사 비용을 쓰지 않기로
  선택했다.
- **R2 — `codex-kit` 을 5번째 플러그인으로 발행 + `dependencies`.** manifest 에 `dependencies`
  필드가 실재하고 semver range 를 지원함을 대조군 probe 로 확인했다. **기각 사유(기술적)**:
  파일 주소를 주지 않는다 — 공식 문서가 *"Installed plugins cannot reference files outside their
  directory"* 라고 못 박는다. 캐시 경로 계산의 함정 중 하나는 리포에 이미 살아 있다:
  `plugin-audit/scripts/check-plugin-structure.sh:20` 의 `sort | tail -1` 을 실제 qg 캐시
  (`2.13.0`/`2.14.3`/`2.14.20`)에 적용하면 **`2.14.3` 이 선택된다**. 버전 제약이 동작하려면
  `{plugin}--v{version}` 태그가 필요한데 devbrew 태그는 1개다. 사용자 동의.
- **R3 — `codex exec review` 로 전환.** **기각 사유 셋**: (a) **커스텀 프롬프트와 상호배타** —
  실측: `codex exec review --base master "focus on security"` →
  `error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'`. (b) `--output-schema`
  가 조용히 무시된다(#35596 + `load_output_schema` 미호출). (c) 웹검색 하드 비활성
  (`tasks/review.rs:105-110`). 구조화 결과도 exec 의 `--json` 에서 버려진다.
  **OpenAI 쿡북도 `codex exec review` 를 쓰지 않고 `git diff` 를 손수 계산한다.**
- **R4 — SARIF 등 기성 findings 포맷.** devbrew 는 터미널 CLI 라 유일한 실익(GitHub
  code-scanning)이 해당 없고, GitHub 은 위치 없는 result 를 표시하지 않는데 리뷰 절반이 prose 다.
  SonarQube 의 SARIF 임포트는 `level` 을 통째로 무시하고 DefectDojo 파서는 4값을 3값으로
  붕괴시키며 미인식 값을 `Medium` 으로 fail-open 한다. Anthropic 자신의
  `claude-code-security-review`(5,769★)도 SARIF 를 내지 않는다.
- **R5 — severity 어휘 3종 통일.** SonarQube 가 3년에 걸쳐 실패했다 — 10.2 에서 5값→3값 매핑 시
  `BLOCKER`/`CRITICAL` 이 둘 다 `HIGH` 로 18개월 붕괴, 결국 legacy 를 un-deprecate 했다.
  세 어휘는 서로 다른 병합기로만 흘러 한 곳에서 만나지 않는다. **귀결(어휘 보존 표현)은 §11.**
- **R6 — 실행된 model·effort 를 meta 에 기록**(brief C6). 실제 적용값을 주는 유일 경로는
  rollout 파일 스크레이핑인데(override 실험으로 적용값 확인), 그 표면이 `[UNSTABLE]` 로 주석돼
  있고 함정이 넷이다. 정식 경로는 `codex exec` 를 버리고 `app-server` 를 구동해야 한다.
  애초 위험(하향 핀)은 sweep 이 제거했고 재도입 락이 있다. rollout 파일에는 프롬프트 전문이
  들어 있어 P21 노출면이기도 하다.
- **R7 — 프롬프트 순서 재배치.** 텍스트 공통 prefix 는 91%로 늘지만 **런 간 캐시가 붙지 않는다** —
  동일 바이트 1·2·3회차에서 `cached_input_tokens` 가 11,008 고정(23.8%). 원인은
  `prompt_cache_key` 가 기본값 session_id 라 호출마다 새 키이고 설정 불가이기 때문이다
  (`core/src/client.rs:483-487`).
- **R8 — diff 절단.** 리뷰 대상을 잘라내는 것은 탐지력 직접 삭감이고 §4 억제 금지와 충돌한다.
  교차-파일 결함이 실제 지적의 약 15.5%이며, *"리뷰가 완료된 것처럼 보이는데 실제로는
  부분집합만 받았다"* 는 상태가 만들어진다(pr-agent#2565). **비용 계측·경고는 §11.**
- **R9 — `--ignore-user-config`.** 약 2,048 토큰을 아끼지만 사용자의 effort·web 설정이 함께
  날아가고, 그 구간은 stable prefix 라 어차피 캐시된다.
- **R10 — 정적 문법으로 계약을 집행**(round-2 이후 신규 기각). 초안은 §4.3 을 정규식 + 변수
  역추적으로 설계했다. **기각 사유**: (a) 셸이 `codex exec` 를 쓸 수 있는 형태를 열거할 수 없고
  (`$(cat`·`$(<`·`read -r -d ''`·`mapfile`·`printf -v`·인자 전달), 열거 자체가 §4 의 "열거 금지"와
  충돌한다. (b) *"역추적 실패 = 위반"* 의 실패 정의가 양방향으로 열린다 — 느슨하면
  `PROMPT="$2"` 우회가 통과하고 엄하면 오늘의 5곳 전부가 만족 불가다(`PROJECT_DIR="${2:-}"` 형태
  때문). (c) 규약을 `$PROMPT_FILE` 이라는 **변수 이름**에 묶으면 앵커가 피검자 통제 아래 놓인다.
  (d) 채택하려던 정본 `_invocation_block()` 은 줄만 돌려주어 argv 와 리다이렉트를 구분하지 못한다.
  → **실행 관측으로 대체**(§4.3). 정적 스캔은 후보 수집으로 격하한다.
- **R11 — 능력 probe 로 stdin 지원 판정**(§4.2 대안). 버전 문자열보다 정확하지만 detect 가
  codex 를 한 번 더 실행해야 하고 그 실행이 auth·네트워크에 걸릴 수 있다. **버전 비교를
  채택**하고 probe 는 버전 파싱 실패 시의 대체 수단으로 §11 에 남긴다.

## 10. Metadata

- **입력 brief**: `docs/superpowers/interview/2026-08-02-codex-usage-unification-interview.md`.
- **선행 조건 충족**: brief C8 의 sweep PR 이 `a4e7fa2`(#112)로 머지됨.
- **brief 대비 반전된 전제 4건**:
  1. *"spike 의 4번째 medium 핀이 이 사이클 잔여"* → sweep 이 이미 제거(§1.3).
  2. **층 ④ 에는 정본이 없었고, 있어야 한다.** brief C9 는 `codex_findings_to_yaml.py` 에 대해
     *"사본 유지 + drift 락"* 만 정하고 **정본을 지정하지 않았다** — §1.2(a)의 drift 는 그
     공백에서 발생했다. 이 설계는 그 층의 **행동 정본을 spec-distill 로** 잡는다.
     **brief C5 는 층 ① `detect_codex.sh` 에 대해 *"정본 = qg 판"* 을 정한 사용자 선택이며,
     이 설계는 그것을 뒤집지 않는다** — 층 ① 두 사본은 의도된 kill switch 변수명 외에 차이가
     없어 판정할 drift 자체가 없다.
  3. *"injection 이 두 위협을 덮는다"* → **셋**이다(§5.3①).
  4. *"severity 어휘 2종"* → **3종**이다. plugin-audit 이 `CRITICAL/HIGH/MEDIUM/LOW` 를 쓴다 —
     `plugin-audit/scripts/render-audit-report.py:15`(`SEV_RANK`) · `audit-workflow.js:77`(enum).
- **codex 실측 환경**: `codex-cli 0.145.0`, 소스는 `openai/codex` tag `rust-v0.145.0`
  (`25af12f7`). 사용자 config 는 `model = "gpt-5.6-sol"` · `model_reasoning_effort = "xhigh"`.
- **리뷰 이력**:
  - **round 1**(대상 `f8cea03`): Claude 12 + codex 12 → `needs_revise`.
  - **round 2**(대상 `ce3fe4b`): Claude 20 + codex 14 → `needs_revise`. 원장 36건(신규 28) 으로
    **발산**. 원인이 두 설계 선택으로 좁혀졌다 — (i) 1단계를 먼저 두어 생긴 carve-out 이
    만료 장치·순서 AC·mutation 2행을 파생시켰고, (ii) 정적 문법(§4.3 초안)이 열거 불가·앵커
    스티어링·구현 이중화를 파생시켰다. **이 판은 그 둘을 구조적으로 제거했다** — 단계 순서를
    바꿔 carve-out 을 없애고(사용자 승인), 계약 판정을 실행 관측으로 옮겼다(사용자 승인, §9 R10).
  - **round 3**(대상 `16933a3`): **Claude 축 사망**(API 세션 한도) — `claude_verdict: null` ·
    `claude_verdict_unrecoverable: true` 로 병합이 codex 단독 verdict 를 냈고
    `round_level: inconclusive`(축 하나가 죽은 라운드를 수렴으로 오독하지 않는다).
    codex 9건(12 → 14 → **9**), 원장 42건(20 → 36 → 42, 증가폭 +16 → +6).
    **per-issue stagnation 발화**(한 항목 3회 제기) → 라우팅 표가 사람에게 강제 escalate.
    사용자가 *"필수 8건 고치고 1단계 구현 시작"* 을 선택했고 이 판이 그 반영본이다.
    반영 항목: `--codex-side` 두 경로 분리(사실 오류) · V1 판별 불가(사실 오류) ·
    순환 교차검사(block) · 상태 truth table · malformed degrade 의미 · AC21 웹 값 표 ·
    fingerprint baseline · 게이트 관측 AC 신설 · V2 증거물 정책.
  - **round 4**(대상 `a64f251`): **두 축 모두 생존** — Claude 13 + codex 8 → `needs_revise`,
    원장 49건(20 → 36 → 42 → 49). **per-issue stagnation 4건**(1건은 4회째)으로 다시 사람에게
    escalate. 그러나 이 라운드가 처음으로 경계를 그었다 — 리뷰어 판정:
    *"1단계 본체와 2단계의 변환기 봉쇄·argv→stdin 은 지금 문서만으로 구현 가능하고, 구현 불가한
    것은 검증 장치(AC11·AC12·AC23)뿐"*. block 3건이 전부 **round-3 에서 내가 새로 넣은 장치**를
    겨눴다: 축 B 가 자명하게 `A≠B`(qg SKILL 3개만으로 `.sh` 20건) · `reviewing-spec:81` 이 산문인데
    §10 이 리터럴이라 주장 · fingerprint 가 `:81` 의 **자기 제외**를 지워 198초 무한 재귀.
    이 판은 그 6건((a)(b)(c) 해당)을 반영했고, 나머지는 **판정하지 않은 미해결**로 남겼다 —
    *"알려진 한계"* 로 확정하지 않는다(사용자 지시).
  - **기각한 지적 1건**(round 1, codex): *"`AC42` 가 두 토큰 모두를 요구"* → 실제 검사는
    `grep -q 'DEVBREW_DISABLE_QG_CODEX\|codex_available'`(`test_codex_reviewer_frontmatter.sh:12`)
    의 **alternation** 이므로 하나로 충족 — 실행으로 확인. round-2 리뷰가 이 반증을 옳다고 확인했다.
- **round-3 이후의 정지 조건**(사용자 합의): 이후 리뷰 지적 중 **(a) 사실이 틀린 주장,
  (b) 실행을 깨뜨리는 것, (c) 사용자를 해치는 것** 셋만 고치고, 문체·완결성 지적은 이 문서에
  알려진 한계로 기록한 뒤 구현에 착수한다. 근거: 하니스를 다듬는 동안 대상은 0건 개선된다.
- **미해결로 남기는 것 — 판정하지 않았다.** 아래는 *"이대로 괜찮다"* 가 아니라 **"이 사이클에서
  결론 내지 못했다"** 다. 구현 중 사실이 드러나면 그때 판정한다.
  1. **qg 두 산문 게이트**(`quality-pipeline` · `critiquing-artifacts`)는 모델이 detect 를
     돌리므로 AC12 관측 밖이다. **`DEVBREW_DISABLE_QG_CODEX` 는 모델이 게이트를 건너뛰면
     우회된다** — P21 보안 컨트롤의 미검증이다. 이 사이클은 spec-distill·plugin-audit 세 곳을
     리터럴로 만들지만 qg 둘은 손대지 않는다. **그 전환이 필요한지, 필요하다면 언제인지는
     판정하지 않았다.**
  2. **후보 스캔이 못 보는 호출 형태**(마크다운 인라인 · 바이너리 간접). §4.3 이 커버리지를
     주장하지 않는 이유이며, 세 번째 독립 축을 찾지 못했다. **더 나은 축이 있는지 열려 있다.**
  3. **fingerprint 채취 표면**(stdout/stderr 범위 · 경로·카운트 정규화). 현행 루프가 출력을
     버리므로 채취가 코드 변경을 요구하고, 등재 대상 하나의 출력이 이 설계가 편집하는 파일의
     grep 카운트를 담는다. **구현 시 먼저 정한다.**
  4. **`0.118.0` 바닥의 근거가 확정적이지 않다.** PR #15917 본문이 *"legacy stdin-as-prompt 유지 +
     prompt+stdin 조합 추가"* 로 읽힐 여지가 있다(round-4 지적). 바닥이 실제보다 높으면 멀쩡한
     버전을 degrade 시키는 **능력 억제**가 된다 — §4 절대 조항에 걸린다. 방향은 보수적이라
     당장 위험하지 않으나, §11 의 능력 probe 로 **한 번 재고 확정해야 한다.**
  5. **`test_web_kill_switch.sh:37` 의 도출 술어가 값을 보지 않는다** — AC21 대로
     `tools.web_search=false` 를 명시하면 qg 러너가 도출 집합에 편입돼 `:42` 확인을 요구받는다.
     술어를 값 인식으로 바꿀지, 죽은 스위치를 만들지 않을지 **정하지 않았다.**
  6. **`extract_codex_artifact_yaml.py` 의 최상위 `codex_failed` shape**(§4.1 예외). 기성 계약이라
     건드리지 않았고, 통일할지 여부를 판정하지 않았다.
  7. **`--json` 이벤트 관용**(모르는 타입 로깅)은 §11 소관으로 넘겼다.
  8. **AC 번호가 외부 네임스페이스와 숫자로 충돌한다**(양쪽에 AC19·AC20·AC21 존재). 번호 규약이
     소유 파일명 병기로 구분을 유지하지만 **자동화는 그 규약을 읽지 않는다** — 이 사이클의 재번호
     스크립트가 실제로 한 곳을 오염시켰다가 복구했다. 구조적 해법은 정하지 않았다.
  9. **§8.2 귀속 주석 불완전** — `-s read-only` 만 기존 락 중복으로 적었으나 `--json`·`-C` 삭제도
     `test_codex_runner_no_effort_pin.sh:124-131` 이 잡는다. 해당 mutation 행들도 신규 계약
     테스트 단독 실행으로 귀속을 확정해야 한다.
  10. **§8.2 mutation 표에 기각된 백스톱 인용이 남아 있다** — *"플러그인 하한 미달"* 은 §4.3 이
      불충분하다고 기각했는데 표가 여전히 RED 근거로 인용한다. 구현자가 기각된 것을 되살릴 유인이다.
- **미확인으로 남는 것**: `tools.web_search=true` 단독이 모드를 승격시키는지(V1 이 nonce 로 답한다) ·
  `--json` 이벤트 스키마의 명시적 stability 정책(리포에서 확인 불가) · 대용량 piped diff 에
  대한 제3자 벤치마크(없음).

## 11. 후속 설계로 이관 (출력 계약)

round-1 리뷰에서 **두 리뷰어가 독립적으로** 분리를 요구했고 사용자가 승인했다. 이관 사유:

- **자기 인정된 미결**: 원안(`f8cea03` §5.3②)이 스스로 *"dedup 설계를 먼저 하고 severity 를
  나중에"* 라고 적었다 — 선행 설계가 없는 상태로 AC 를 썼다.
- **자기모순**(codex 적발): 원안 `f8cea03` 의 AC29 는 severity 매핑의 **전 값 왕복**을 요구하는데
  §9 R5 는 카디널리티가 달라 무손실 매핑이 불가능하다고 적는다.

이관 항목: `--output-schema` + `-o` 도입(펜스 경로는 백스톱 유지) · findings 스키마 설계 ·
`{scale, value, source}` severity 보존 표현 + conformance test · 부분 파싱 + `droppedFindings` ·
이벤트 타입 관용 · 프롬프트 토큰 계측과 272K 경고 · 임시 산출물 수명 정책 · 주입 방어의
적대적 효과 측정 · §4.2 의 능력 probe 대체 수단(R11).

**선행 조건**: (a) dedup 설계 — severity 는 dedup 해시에 들어갈 수 있어 매핑을 먼저 정하면
dedup 이 그 결정에 묶인다. (b) **이 문서 1단계 완료** — plugin-audit 의 `--codex-side` 출력
shape 가 확정돼야 스키마 경계를 정할 수 있다(1단계 ②가 그것을 만든다). (c) 토큰 계수 방법
확정 — 272K 경계까지 여유가 3.4%(9,472/281,472)라 `len/4` 류 근사로는 판정할 수 없다.

## Handoff Context

### TL;DR

codex 를 부르는 6곳이 같은 절차를 거치게 하고(1·3단계), 실패가 성공으로 읽히는 경로를 막는다
(2단계). 실행자는 **1단계(plugin-audit) → 2단계(결함) → 3단계(나머지 통일)** 순으로, 각 항목을
독립 커밋으로 진행한다.

가장 중요한 사실 둘:
1. **계약 검증은 정적 grep 이 아니라 실행 관측이다**(§4.3). argv·stdin 을 캡처하는 mock codex 를
   PATH 에 얹고 러너를 실제로 태워 판정한다. 셸이 그 호출을 어떻게 썼는지는 무관하다.
2. **락 반전과 대상 변경을 같은 커밋에** 넣어야 baseline 조건이 성립한다. 특히 알려진 두
   곳 — 1단계의 `validate-audit-data.py` B7, 3단계의 `test_web_kill_switch.sh` — 은 그렇게
   하지 않으면 GREEN 이던 테스트가 RED 가 된다.

### Implicit context (문서에 안 적혀 있으면 실행자가 모를 것들)

- **baseline 은 이미 캡처됐다**: `a4e7fa2` 에서 bash 134개 중 6 red. 그 6건 중 2건
  (`test_consent_marker_write_failure.sh` · `test_security_reviewer_kill_switch.sh`)은 codex 무관
  pre-existing 이므로 **고치려 들지 말 것**. qg 는 CI 가 없어 stale red 가 누적된다.
- **`test_codex_backward_compat.sh` 는 198초 걸린다.** 타임아웃을 짧게 잡으면 실패로 오인한다.
- **spec-distill 의 python 테스트는 `-m unittest` 로만 돈다**(pytest 아님), **repo root 에서** 실행.
- **`~/Downloads` 아래라 TCC 권한 회수가 일어나면** `stat` 은 되는데 `open` 이 실패하며 테스트가
  대량 실패한다 — 회귀로 오인하지 말 것.
- **러너를 직접 실행할 때 `CLAUDE_PLUGIN_ROOT` 를 export 해야 한다.** 러너는 `set -u` 아래
  그 변수를 읽으므로 미설정이면 즉시 죽는데 **exit 0 을 내고 degrade YAML 만 남긴다** —
  이 설계가 다루는 실패 분포의 실례이며 이 문서 작성 중 실제로 한 번 밟았다.
- **spec-distill 의 Stop 훅이 모든 `*-design.md` write 에 리뷰를 강제한다.** 정상 동작이다.
- **codex 를 실제로 부르는 검증(V1~V4)은 사용자 과금이다.** 각 항목 1회로 설계돼 있고,
  V2 는 증거물을 `docs/audits/` 에 남겨 사후 재현 없이도 확인 가능하게 한다.
- **캡처 mock 은 새로 만들지만 인프라는 있다** — `plugins/*/tests/mocks/` 와 `PATH=` 주입
  선례(`test_codex_runner_degrade_contract.sh` 등)를 그대로 쓴다.

### Deferred to plan

- 각 단계 안에서의 **파일별 편집 순서**(무엇을 먼저 건드려야 중간 상태의 RED 가 최소인지).
- 캡처 mock 의 인자 주입 방식 — 러너마다 필요한 인자가 달라 harness 가 그것을 어떻게 공급할지.
- 갈라짐 락의 입력 표본 집합을 파일로 둘지 테스트 안에 인라인할지.
- §11 이관 항목의 착수 시점과 선행 조건 (a)(b)(c) 의 순서.
