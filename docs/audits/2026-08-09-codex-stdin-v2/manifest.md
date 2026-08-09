# V2 — argv→stdin 전환 실동작 (2단계 게이트, AC19)

- 대상 커밋: `e9ab8ec4619dbea4ed9b41b8553bb358ac7e24c2`
- codex: `codex-cli 0.147.0` (Task 15 브리프가 기록한 "0.145.0" 이후 로컬 환경이 자연 업그레이드된 것 — 특이사항 아님)
- 실제 codex 호출: **8회** — Step 2 호출부 5회 + Step 3 spike 3회. **설계 예산(5~6회)을 초과했다.** 근거는 아래 "예산 이탈" 절.

| 러너 | sha256 |
|---|---|
| `quality-gates/scripts/run_codex_reviewer.sh` | `5582b3ff3b6017bbd9af4abb2f213f726bf17aa0e04e7badd2a18f31fe510581` |
| `quality-gates/scripts/run_artifact_codex_reviewer.sh` | `980cdd6eea9e826a1948b46c8453b8ce6be31566a08271b413b2e543506e6860` |
| `spec-distill/scripts/run_spec_codex_reviewer.sh` | `17495aa72e1ba38728420aa82379689a7e6d3297dd6410921e1e339a9a59abd0` |
| `spec-distill/scripts/run_brief_codex_reviewer.sh` | `2023158198d4f47668ea97c2ded442563c6018dc88f5c46bfb8e83cff84201a1` |
| `plugin-audit/scripts/run_audit_codex_reviewer.sh` | `10c32bbdc044bb7ab558581ec43af8e4466d913fb50b7bbd2ab0148f9689502b` |
| `quality-gates/tests/spike/test_codex_json_extraction.sh` | `ab437b0ce9e66de933ffe5407439198b6aa51e73002bf05a4574b45b0b4a40b5` |

이 manifest 의 러너 해시가 현재 소스와 다르면 이 증거는 **stale** 이다.

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
| qg-artifact (`run_artifact_codex_reviewer.sh`) | 0 | *(meta 블록 자체가 없음 — 아래 참조)* | 1419 | stderr 0B |
| sd-spec (`run_spec_codex_reviewer.sh`) | 0 | **false** | 1945 | `exit_code: 0`, findings 5건 |
| sd-brief (`run_brief_codex_reviewer.sh`) | 0 | **false** | 2258 | `exit_code: 0`, `-c tools.web_search=true` 관측, findings 1건 |
| pa-audit (`run_audit_codex_reviewer.sh`) | 0 | **true** | 1215 | `reason: malformed_json` — 아래 참조 |

stdin 바이트 수: qg-code·qg-artifact는 러너가 실행 중 남긴 scratch 파일(`prompt.md`)을 직접
`wc -c`했다(이 두 러너는 scratch를 정리하는 trap이 없다). sd-spec·sd-brief·pa-audit은 scratch가
trap으로 즉시 삭제되므로, 같은 입력으로 프롬프트-빌더 단계만(codex 호출 없이) 재실행해
바이트 수를 재구성했다 — 결정론적 스크립트이므로 원 실행과 바이트 단위로 동일하다. 추가 codex
호출은 없었다.

**stdin 전송 자체(rc=0, `exit_nonzero` 없음, `"No prompt provided via stdin."` 없음)는 5/5
성공** — 이것이 이 태스크의 핵심 검증 대상(argv→stdin 전환)이며 전부 통과했다. JSON 추출까지
포함한 완전 양성(`codex_failed: false` 리터럴 관측)은 3/5(qg-code, sd-spec, sd-brief).
qg-artifact는 메타 부재로 리터럴 판정 불가하나 수동 검사로 양성 확인(아래). pa-audit은
명시적 실패(`codex_failed: true`, `malformed_json`).

## qg-artifact — meta 블록이 없는 성공 (하니스 사각지대)

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

## pa-audit — 실패 (`malformed_json`)

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

## 보존하지 않는 것 (P21)

원시 프롬프트와 JSONL 전문은 남기지 않는다. 남기는 것은 러너 해시·관측된 플래그·stdin 바이트
수·`meta:` 블록(pa-audit의 200자 preview 포함 — 이미 추출기 자체가 절단한 것이지 이 문서가
새로 절단한 것이 아니다)뿐이다.
