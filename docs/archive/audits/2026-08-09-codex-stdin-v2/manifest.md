# V2 — argv→stdin 전환 실동작 (2단계 게이트, AC19)

- 대상 커밋: `e9ab8ec4619dbea4ed9b41b8553bb358ac7e24c2` (Task 15b 재실행들은 이 커밋 이후, 아래 "Task 15b Fix round 1"·"Fix round 2" 절 참조)
- codex: `codex-cli 0.147.0` (Task 15 브리프가 기록한 "0.145.0" 이후 로컬 환경이 자연 업그레이드된 것 — 특이사항 아님)
- 실제 codex 호출: **8회**(Task 15) + **2회**(Task 15b Fix round 1) + **1회**(Task 15b Fix round 2, 아래 절) = **총 11회**. Task 15의 8회는 설계 예산(5~6회)을 초과했다 — 근거는 아래 "예산 이탈" 절. Task 15b의 두 라운드는 각각 별도 예산(라운드 1: budget 2, 라운드 2: budget 1)이며 둘 다 그 안에서 소진했다(초과 없음).

| 러너 / 스크립트 | sha256 |
|---|---|
| `quality-gates/scripts/run_codex_reviewer.sh` | `5582b3ff3b6017bbd9af4abb2f213f726bf17aa0e04e7badd2a18f31fe510581` |
| `quality-gates/scripts/run_artifact_codex_reviewer.sh` | `980cdd6eea9e826a1948b46c8453b8ce6be31566a08271b413b2e543506e6860` |
| `spec-distill/scripts/run_spec_codex_reviewer.sh` | `17495aa72e1ba38728420aa82379689a7e6d3297dd6410921e1e339a9a59abd0` |
| `spec-distill/scripts/run_brief_codex_reviewer.sh` | `2023158198d4f47668ea97c2ded442563c6018dc88f5c46bfb8e83cff84201a1` |
| `plugin-audit/scripts/run_audit_codex_reviewer.sh` | `10c32bbdc044bb7ab558581ec43af8e4466d913fb50b7bbd2ab0148f9689502b` |
| `quality-gates/tests/spike/test_codex_json_extraction.sh` | `ab437b0ce9e66de933ffe5407439198b6aa51e73002bf05a4574b45b0b4a40b5` |
| `quality-gates/scripts/extract_codex_artifact_yaml.py` (Task 15b 결함 A 수정) | `ec6e87a8d4eac4ea2e3bc1759f8a537b54acd62cda3298483b4b8da9389791ba` |
| `plugin-audit/scripts/codex-prompt-preamble.md` (Task 15b 결함 B — round 1+2 누적) | `f64c93878efa0f91ba73e327708a9d981371200dc4fc348ee5ec684c5c0dc19c` |

이 manifest 의 러너/스크립트 해시가 현재 소스와 다르면 이 증거는 **stale** 이다. extractor·preamble 두 행은
Task 15b가 편집한 파일이라 여기 처음 추가됐다 — 원래 6행은 Task 15b 어느 라운드에서도 **손대지 않았고**
재계산해도 동일하다(확인 완료). preamble 행의 해시는 round 2에서 다시 갱신됐다(round 1 값에서 변경 —
worked example·원소 필드 명세 추가) — round 1 값(`47fa0308...`)은 더 이상 현재 소스와 일치하지 않는다.

## 관측된 argv (프롬프트 바이트 제외 — 플래그만)

5개 호출부 전부(소스 확인, `grep -n "codex exec" -A10`):

```
codex exec - -C <project_dir> -s read-only [--json] < <prompt_file>
```

`sd-brief` 만 추가로 `-c tools.web_search=true`를 싣는다 — 실제로 관측: sd-brief 실행이
2분 28초 걸렸고(다른 4개는 10~26초), 반환된 finding이 GOV.UK·NASA 문서를 실제로 인용했다.
`-s read-only` 는 5개 호출부 소스 전부에서 로드-베어링 플래그로 존재 — argv 자체(프로세스
인자 나열)는 캡처하지 않는다(P21), 소스 인용으로 확정한다.

## 예산 이탈 — 계획 5~6회 → 실집행 8회

brief Step 3의 spike 스크립트(`test_codex_json_extraction.sh:21-37`)를 읽어 확인한 결과,
"Spike result: 3/3 passed"는 **하나의 codex 호출에 대한 3개 assertion이 아니라 `for i in 1 2 3`
루프 안에서 매 iteration마다 실행되는 서로 다른 3회의 실제 `codex exec` 호출**이다. 실행 전에
소스를 읽어 이 사실을 미리 파악했다. 따라서 총 실집행은 Step 2의 5 + Step 3의 3 = **8회**이며
5~6회 설계 예산을 초과한다.

Task 15 브리프 자신이 이 정확한 시나리오("3/3이 3회 호출이면 총 8회")를 예견하고 "report that
fact rather than silently absorbing it"으로 명시적으로 지시했으므로, 실행을 멈추지 않고
진행한 뒤 여기 명시적으로 기록한다. 사전 승인(2026-08-09 상시 승인)이 지출 자체는 커버하므로
승인 프롬프트는 열지 않았다 — 이탈 사실의 투명한 기록만 이 문서의 몫이다.

## 판정

| 호출부 | rc | `codex_failed` | stdin 바이트 | 비고 |
|---|---|---|---|---|
| qg-code (`run_codex_reviewer.sh`) | 0 | **false** | 9857 | `exit_code: 0`, stderr 0B, findings 1건(CRITICAL) |
| qg-artifact (`run_artifact_codex_reviewer.sh`) | 0 | **false**† | 1419 | Task 15 원 실행 당시는 meta 블록 자체가 없어 리터럴 판정 불가였다(아래 "meta 블록이 없는 성공" 절, 결함 A). Task 15b Fix round 1(아래 절)에서 리터럴 `codex_failed: false` 관측으로 확정 |
| sd-spec (`run_spec_codex_reviewer.sh`) | 0 | **false** | 1945 | `exit_code: 0`, findings 5건 |
| sd-brief (`run_brief_codex_reviewer.sh`) | 0 | **false** | 2258 | `exit_code: 0`, `-c tools.web_search=true` 관측, findings 1건 |
| pa-audit (`run_audit_codex_reviewer.sh`) | 0 | **false**‡ | 1215 | Task 15 원 실행 `reason: malformed_json`(결함 B). Task 15b Fix round 1은 `schema_mismatch`(부분 진전). Task 15b Fix round 2(원소 필드 명세 + worked example 추가 후)에서 리터럴 `codex_failed: false` 관측 — 아래 "Fix round 1"·"Fix round 2" 절 참조 |

† qg-artifact 는 Task 15b round 1이 결함 A(양성 표식 부재)를 고친 뒤 재실행해 리터럴로 확정한 결과다.
‡ pa-audit 은 Task 15b round 1(preamble 스키마 지시 추가)에서는 `codex_failed: true`(`schema_mismatch`)가
남았으나, round 2(원소 필드 명세 + worked example 추가)에서 리터럴 `codex_failed: false`로 닫혔다 —
아래 절 참조.

stdin 바이트 수: qg-code·qg-artifact는 러너가 실행 중 남긴 scratch 파일(`prompt.md`)을 직접
`wc -c`했다(이 두 러너는 scratch를 정리하는 trap이 없다). sd-spec·sd-brief·pa-audit은 scratch가
trap으로 즉시 삭제되므로, 같은 입력으로 프롬프트-빌더 단계만(codex 호출 없이) 재실행해
바이트 수를 재구성했다 — 결정론적 스크립트이므로 원 실행과 바이트 단위로 동일하다. 추가 codex
호출은 없었다. (표의 바이트 수는 Task 15 원 실행 값 그대로 — Task 15b 재실행은 다른 artifact/axis
fixture를 썼으므로 바이트 수가 다르고, 이 표가 재는 것은 "argv→stdin 전환이 작동하는가"이지
바이트 수 자체의 재현이 아니다.)

**stdin 전송 자체(rc=0, `exit_nonzero` 없음, `"No prompt provided via stdin."` 없음)는 5/5
성공** — 이것이 이 태스크의 핵심 검증 대상(argv→stdin 전환)이며 전부 통과했다. JSON 추출까지
포함한 완전 양성(`codex_failed: false` 리터럴 관측)은 Task 15 원 실행 시점 3/5(qg-code, sd-spec,
sd-brief) → Task 15b round 1 후 4/5(+qg-artifact) → **Task 15b round 2 후 5/5**(+pa-audit).
5개 호출부 전부가 리터럴 양성 표식으로 확정됐다.

## qg-artifact — meta 블록이 없는 성공 (하니스 사각지대) [Task 15b 결함 A로 수정됨]

> **수정 완료 (Task 15b, 2026-08-09).** 이 절이 기술하는 갭(성공 경로에 `meta:` 블록·양성
> 표식이 없음)은 `extract_codex_artifact_yaml.py`의 성공 경로에 `meta: {codex_failed: false}`를
> 추가해 닫혔다. 아래 원문은 **당시 관측을 그대로 보존**한다(무엇이 왜 결함이었는지의 기록 —
> Law 3). 수정 후 리터럴 확인은 "Task 15b Fix round 1" 절 참조.

`extract_codex_artifact_yaml.py`의 성공 경로는 `agent: codex-reviewer` + `findings: [...]`만
방출하고 **`meta:` 자체를 내지 않는다** — `codex_failed: true`는 오직 실패(degrade) 경로에서만
등장한다(스크립트 79~101행 확인). 그 결과 brief Step 2가 준 관측 하니스
(`grep -A6 '^meta:' || python3 -c "...['meta']"`)를 그대로 이 출력에 돌리면 **공백**이 나온다 —
"failed to run" 과 "성공했지만 이 스크립트 계약상 meta를 안 냄"이 겉보기에 구분되지 않는다.

수동으로 `o-art.yaml` 전체를 읽어 확인: `agent: codex-reviewer`, `findings`에 스키마가 온전한
항목 1건(`category`/`severity`/`summary`/`proposed_fix` 모두 채워짐), degrade 마커 부재.
`codex_failed: true`가 어디에도 없고 findings가 유효한 구조라는 두 사실의 결합으로 이 호출은
**양성**이라고 판정한다 — 다만 다른 4개 호출부처럼 `codex_failed: false` 리터럴로 확정할 수는
없다. 이것은 브리프의 자동 관측 harness 자체의 사각지대이며, V2 게이트가 아니었다면 발견되지
않았을 것이다.

## pa-audit — 실패 (`malformed_json`) [Task 15b 결함 B로 수정됨 — 2라운드 끝에 완전히 닫힘]

> **완전 수정 (Task 15b, 2026-08-09, 2라운드).** `codex-prompt-preamble.md`에 응답 스키마
> 지시(펜스된 JSON 한 블록·네 키)를 추가한 round 1은 `malformed_json`(파싱 자체 실패)을
> 없앴지만 `schema_mismatch`(원소 타입 위반)로 실패 양상만 바꿨다. 배열 원소가 dict여야
> 한다는 것과 컬렉션별 최소 필드, worked example을 추가한 round 2에서 리터럴
> `codex_failed: false`로 완전히 닫혔다. 아래 원문은 **당시(Task 15) 관측을 그대로 보존**한다.

`codex-prompt-preamble.md`는 codex에게 "report findings ... with file:line evidence"라고만
지시하고 JSON 출력 스키마를 요구하지 않는다. `codex_audit_to_json.py`는 마지막 agent_message가
fenced 또는 raw JSON으로 파싱되지 않으면 `malformed_json`으로 degrade한다. 이 V2 브리프가 준
`axis.md`는 한 문장짜리 최소 질문이라 codex가 산문으로 답했고(실제 답변 요지는 CLAUDE.md의
법칙 구조에 대한 정확한 한 문장 — 내용 자체는 틀리지 않았다), 그 결과 파서가 JSON을 찾지 못했다.

`exit_code: 0`이고 stderr에 `"No prompt provided via stdin."`가 없다는 점에서 **stdin 전송
자체는 성공**했다 — 이 태스크가 검증하려는 argv→stdin 전환은 이 호출부에서도 작동한다. 실패는
그 다음 단계(JSON 스키마 추출)에서 발생했다. 이것이 stdin 전환 자체의 결함인지, 실제 운영에서
축 질문 파일이 (이 합성 axis.md와 달리) JSON 스키마 지시를 함께 싣기 때문에 실전에서는 안
나는 실패인지는 이 태스크 범위 밖이다 — brief 지시대로 axis.md를 바꾸거나 재시도해 통과시키지
않는다. 관측된 사실만 기록한다.

## Step 3 — spike

`bash plugins/quality-gates/tests/spike/test_codex_json_extraction.sh` → **3/3 passed**
(3회의 개별 `codex exec` 호출, 위 "예산 이탈" 절 참조). fixture
`plugins/quality-gates/tests/spike/fixtures/codex_jsonl_sample.json`가 성공 시 계약대로 갱신됨.

**스키마 비교**: `git diff`로 확인한 결과 이벤트 shape은 동일
(`thread.started`/`turn.started`/`item.completed`/`turn.completed`, 4줄 그대로)이나,
`turn.completed.usage` 객체에 이전 fixture에는 없던 키 `cache_write_input_tokens`가 새로
나타났다 — `thread_id`·라인 번호·토큰 수치 같은 내용물 차이가 아니라 **필드 집합이 늘어난
스키마 변화**다. 현재 어떤 추출기도(`codex_findings_to_yaml.py`/`extract_codex_artifact_yaml.py`/
`codex_audit_to_json.py`) `usage` 객체를 소비하지 않으므로(grep 확인, 프로덕션 코드에서 0건)
오늘 당장 깨지는 소비자는 없다. 그러나 이것은 codex CLI 산출물 형태의 실측 변화이므로
brief 지시대로 **되돌리지 않고 유지·커밋**한다.

## Task 15b Fix round 1 — 결함 A·B 수정 후 (2026-08-09, 실제 codex 2회)

Task 15(V2 최초 실행)가 두 실제 결함을 적발했다: **결함 A** — `extract_codex_artifact_yaml.py`
성공 경로에 양성 표식(`codex_failed: false`)이 없어 "성공"과 "조용한 실패"가 구별되지 않음
(indeterminate ≠ clean 위반). **결함 B** — `codex-prompt-preamble.md`가 응답 스키마를 전혀
지시하지 않아 `codex_audit_to_json.py`가 요구하는 4키 JSON을 codex가 낼 이유가 없었음(산출자
없는 소비자). 둘 다 고친 뒤, **영향받은 두 호출부만** 다시 태웠다(나머지 셋은 Task 15에서 이미
`codex_failed: false`였으므로 재실행하지 않음 — 예산 절약).

수정 내용: `plugins/quality-gates/scripts/extract_codex_artifact_yaml.py`의 성공 경로가
`meta: {codex_failed: false}`를 낸다(형제 추출기 `codex_findings_to_yaml.py`와 같은 모양).
`plugins/plugin-audit/scripts/codex-prompt-preamble.md`에 응답 형식 지시(펜스된 JSON 한
블록·정확히 네 키·추출기의 "마지막 펜스" 관습과 정합)를 추가했다.

| 호출부 | rc | `codex_failed` | 비고 |
|---|---|---|---|
| qg-artifact | 0 | **false** | findings 2건(IMPORTANT × 2, `completeness`·`ambiguity`) — 결함 A는 완전히 닫혔다: 리터럴 양성 표식이 처음으로 관측됨 |
| pa-audit | 0 | **true** | `reason: schema_mismatch`, `bad_element_types: str`, `bad_element_keys: oq_answers` — 아래 상세 |

**qg-artifact — 완전 성공.** 결함 A 수정이 그대로 통했다: `agent: codex-reviewer` /
`findings:` 2건 / `meta: {codex_failed: false}`. 락 A(`test_codex_extractor_positive_marker.sh`)가
이 회귀를 앞으로 막는다.

**pa-audit — 진짜 진전, 그러나 여전히 실패.** 실패 *양상*이 바뀌었다: Task 15 원 실행은
`malformed_json`(codex가 산문으로 답해 fenced JSON 자체를 못 찾음)이었다. 재실행은 codex가
preamble의 새 지시를 따라 **정확히 네 키를 가진 fenced JSON 블록으로 답했다** — 파싱은
성공했다. 그런데 `oq_answers` 배열의 원소가 dict가 아니라 문자열이어서
`validate_collections()`의 원소-타입 검사(`codex_audit_to_json.py:98`)가 `schema_mismatch`로
degrade시켰다. 원인 추정(관측, 확정 아님): 이 V2용 합성 `axis.md`는 열린 질문을 하나도 안
주는 한 문장짜리 질문이라, "open questions 답하라"는 새 지시를 codex가 축 질문 자체에 대한
답변을 문자열로 채워 넣는 것으로 해석한 듯하다 — preamble이 각 배열 **원소의 내부 스키마**
(예: `oq_answers`의 각 항목이 `{id, answer}` 형태여야 한다는 것)까지는 지시하지 않는다.

**이 라운드에서는 고치지 않았다.** 브리프가 명시적으로 지시한 대로("codex_failed: true가 남으면
reason을 읽고 정직하게 보고한다 — 통과시키려고 테스트나 기대치를 조정하지 않는다") 그대로
기록만 했다. 실제 codex 예산(round 1: 2회)도 소진했었다 — round 1 세션 내 세 번째 시도로
재실행할 여지가 없었다. 원소 내부 스키마 지시(컬렉션별 최소 필드 + worked example)는 이
라운드의 "요구 성질"(브리프 §결함 B, "하나의 펜스된 JSON 블록, 네 키")을 넘어서는 범위라고
당시 판단했으나, 그 범위 밖의 갭이 바로 남은 실패 원인이었다 — 컨트롤러가 원인을 규명해
**Fix round 2**로 후속 지시했다. 아래 절 참조.

## Task 15b Fix round 2 — preamble 원소 스키마 + worked example (2026-08-09, 실제 codex 1회)

**원인 (컨트롤러 규명).** preamble round 1은 네 키가 "each an array"라고만 말했다 — **원소가
무엇이어야 하는지는 말하지 않았다.** codex는 `"oq_answers": ["문자열"]`을 냈고, 그건 유효한
배열이지만 추출기는 `[x for x in raw if isinstance(x, dict)]`(`codex_audit_to_json.py:97`)로
**모든 컬렉션의 모든 원소가 dict**여야 한다고 요구한다. 산출자가 소비자의 요구를 여전히 다
듣지 못한 것 — 같은 병의 한 겹 아래.

**수정.** `codex-prompt-preamble.md`에 "Element shape" 문단을 추가했다: 원소는 항상 JSON
객체, 컬렉션별 최소 필드 — 추측이 아니라 실제 소비자에서 도출:
  - `findings`: `id`/`axis`/`title`/`severity`/`evidence` — `audit-workflow.js`의
    `codexFindings` 병합·dedup·심층검증 tier 필터가 실제로 읽는 필드(`:608-627`).
  - `d_verdicts`: `id`/`verdict`(enum)/`reason` — `verdict`는 `validate-audit-data.py:49`가
    **모든 source**(claude·codex 공통)에 대해 `VALID_VERDICT` 멤버십을 강제한다.
  - `oq_answers`: `id`/`answer`/`reason` — `assemble-audit-data.py`의 claude-source backfill
    패턴(`:118`)과 `AXIS_SCHEMA`(`audit-workflow.js:104-115`)의 실제 필드.
  - `new_open_questions`: `id`/`axis`/`observation`/`why_not_gap` — `why_not_gap`은
    `validate-audit-data.py:93-95`가 **모든 source**에 대해 강제하는 하드 요구.

펜스된 worked example 하나를 preamble에 추가했다 — "이건 네 답이 아니다, 네 답은 여전히
마지막 펜스여야 한다"는 문장으로 anti-injection 규약(추출기의 마지막-펜스 관습)과의 충돌을
막았다.

**행동 락 추가.** `test_preamble_schema_parity.py`에 세 번째 테스트
(`test_preamble_example_satisfies_extractor`)를 추가했다 — preamble의 worked example
자체를 추출기 자신의 `FENCE_RE`로 뽑아 실제로 추출기에 먹이고 `codex_failed: false`를
잰다. round 1의 키-이름 parity 락은 이 결함(원소 타입)을 통과시켰다 — 이름은 다 있었으니까.
mutation 증명: worked example의 `oq_answers` 원소를 객체 대신 문자열로 바꾸면(mB-3)
정확히 이 새 락이 RED가 되고, 실패 사유가 실제 V2 실패와 **동일한 문구**
(`schema_mismatch`/`bad_element_keys: oq_answers`)로 재현됐다.

**재실행.** pa-audit 1회(round 2 예산 1 전량 소진):

| 호출부 | rc | `codex_failed` | 비고 |
|---|---|---|---|
| pa-audit | 0 | **false** | `oq_answers` 1건 — `{id, answer, reason, evidence[]}` 형태, `evidence`는 CLAUDE.md 6개 지점을 인용. 완전히 닫혔다 |

**결과.** codex가 preamble의 worked example을 그대로 따라 `oq_answers`를 올바른 객체
배열로 냈다 — round 1에서 남았던 `schema_mismatch`가 사라지고 리터럴 `codex_failed: false`가
관측됐다. 5개 호출부 전부 리터럴 양성 표식으로 확정.

## 보존하지 않는 것 (P21)

원시 프롬프트와 JSONL 전문은 남기지 않는다. 남기는 것은 러너 해시·관측된 플래그·stdin 바이트
수·`meta:` 블록(pa-audit의 200자 preview 포함 — 이미 추출기 자체가 절단한 것이지 이 문서가
새로 절단한 것이 아니다)뿐이다.
