# 관측된 meta 블록 (원시 프롬프트·JSONL 전문은 보존하지 않는다 — P21)

> **Task 15b 갱신 (2026-08-09, 누적 round 1+2).** o-art.yaml·o-audit.json 절은 Task 15
> 원 실행의 관측을 보존한 뒤, 그 아래에 결함 A·B 수정 라운드별 재실행(round 1: 실제 codex
> 2회, round 2: 실제 codex 1회)의 관측을 시간순으로 추가했다. 원 관측을 지우지 않는 이유는
> manifest.md와 동일(Law 3 — 무엇이 왜 결함이었는지의 기록).

## o-code.yaml (qg-code)

```
meta:
  codex_failed: false
  exit_code: 0
```

## o-art.yaml (qg-artifact) — Task 15 원 실행

```
(메타 블록 없음. brief Step 2의 grep -A6 '^meta:' / python fallback 둘 다 공백을 낸다 —
 이 러너의 추출기(extract_codex_artifact_yaml.py)는 성공 경로에서 meta: 자체를 방출하지
 않는다. 수동 확인: `agent: codex-reviewer` + findings 1건, 스키마 온전
 (category/severity/summary/proposed_fix 모두 존재), degrade 마커 부재. 자세한 판정 근거는
 manifest.md "qg-artifact — meta 블록이 없는 성공" 절 참조.)
```

## o-art.yaml (qg-artifact) — Task 15b Fix round 1 (결함 A 수정 후)

```
meta:
  codex_failed: false
```

findings 2건(둘 다 IMPORTANT: `completeness`, `ambiguity` — 합성 산출물이 결론·근거 없이
분량 요청만 담고 있다는 취지). 결함 A 수정이 리터럴 양성 표식을 처음으로 냈다.

## o-spec.yaml (sd-spec)

```
meta:
  codex_failed: false
  exit_code: 0
```

## o-brief.yaml (sd-brief)

```
meta:
  codex_failed: false
  exit_code: 0
```

관측된 추가 플래그: `-c tools.web_search=true` (소스 확인). 이 호출만 2분 28초 걸렸고, 반환된
finding이 실제 웹 문서(GOV.UK, NASA 시스템 엔지니어링 핸드북)를 인용했다 — 웹서치 경로가
살아있음을 실행으로 확인.

## o-audit.json (pa-audit) — Task 15 원 실행

```json
{
  "codex_failed": true,
  "reason": "malformed_json",
  "exit_code": 0,
  "raw_text_preview": "이 리포의 `CLAUDE.md`는 모든 `plugins/*`가 GitHub Flow와 함께 **명세 우선·작성/검토 분리·학습 축적**의 세 법칙, 표준 구조·보안·문서화 규칙을 준수하도록 규정한다 (`CLAUDE.md:8-55`)."
}
```

`raw_text_preview`는 추출기(`codex_audit_to_json.py`)가 자체적으로 200자로 절단해 meta에
실은 것이지, 이 문서가 새로 발췌한 것이 아니다 — 프롬프트 본문이나 JSONL 전문이 아니라 실패
사유를 밝히는 meta 필드의 일부이므로 P21 하에서 보존 대상이다. 판정 근거는 manifest.md
"pa-audit — 실패" 절 참조.

## o-audit.json (pa-audit) — Task 15b Fix round 1 (결함 B 부분 수정 후, 여전히 실패)

```json
{
  "codex_failed": true,
  "reason": "schema_mismatch",
  "bad_element_types": "str",
  "bad_element_keys": "oq_answers",
  "exit_code": 0
}
```

`malformed_json`(파싱 자체 실패)이 사라지고 `schema_mismatch`(파싱은 성공, 원소 타입 위반)로
바뀌었다 — preamble 스키마 지시가 codex의 응답 형태(4키 fenced JSON)는 고쳤지만, `oq_answers`
배열 **원소의 내부 형태**(dict 기대, 문자열 수신)까지는 못 고쳤다. `raw_text_preview`가 이번엔
없다 — 이 실패 경로(`validate_collections` 원소-타입 검사)는 `payload` 자체는 이미 dict로
파싱됐으므로 원문 미리보기를 남기지 않는 코드 경로다(`codex_audit_to_json.py` 확인). 판정 근거는
manifest.md "Task 15b Fix round 1" 절 참조.

## o-audit.json (pa-audit) — Task 15b Fix round 2 (원소 스키마 + worked example 추가 후, 성공)

```json
{
  "oq_answers": [
    {
      "id": "AXIS1-Q1",
      "answer": "루트 CLAUDE.md는 devbrew의 모든 플러그인에 상속되는 개발 헌장으로서 Git workflow, 명세·독립 리뷰·학습 축적의 세 법칙, 플러그인 구조·권한·런타임·보안 규칙, 금지 패턴, 문서 및 감사 기록 방식을 규정한다.",
      "reason": "적용 범위와 핵심 규정 영역이 문서에 명시되어 있다.",
      "evidence": ["CLAUDE.md:8", "CLAUDE.md:21", "CLAUDE.md:31", "CLAUDE.md:61", "CLAUDE.md:74"]
    }
  ],
  "meta": { "codex_failed": false, "exit_code": 0 }
}
```

`findings`·`d_verdicts`·`new_open_questions`는 빈 배열(이 축엔 해당 없음 — preamble의
"빈 배열이 정상" 지시가 지켜졌다). `oq_answers` 1건이 preamble의 worked example과 정확히
같은 모양(`id`/`answer`/`reason`, 추가로 `evidence`)으로 나왔다 — codex가 예시를 그대로
따랐다. `answer`는 축 질문에 대한 한 문장 요약 답변이지 프롬프트 본문·JSONL 전문이 아니므로
P21 하에서 보존 대상이다(Task 15 원 실행의 `raw_text_preview`와 같은 근거). `evidence`의
`quote` 필드(코드 원문 인용 6건)는 생략했다 — meta 필드 자체가 아니라 답변이 인용한 별도
증거 payload이므로 여기서는 file:line 위치만 남긴다. 판정 근거는 manifest.md "Task 15b
Fix round 2" 절 참조.
