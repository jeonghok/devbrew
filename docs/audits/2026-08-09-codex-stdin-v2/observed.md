# 관측된 meta 블록 (원시 프롬프트·JSONL 전문은 보존하지 않는다 — P21)

## o-code.yaml (qg-code)

```
meta:
  codex_failed: false
  exit_code: 0
```

## o-art.yaml (qg-artifact)

```
(메타 블록 없음. brief Step 2의 grep -A6 '^meta:' / python fallback 둘 다 공백을 낸다 —
 이 러너의 추출기(extract_codex_artifact_yaml.py)는 성공 경로에서 meta: 자체를 방출하지
 않는다. 수동 확인: `agent: codex-reviewer` + findings 1건, 스키마 온전
 (category/severity/summary/proposed_fix 모두 존재), degrade 마커 부재. 자세한 판정 근거는
 manifest.md "qg-artifact — meta 블록이 없는 성공" 절 참조.)
```

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

## o-audit.json (pa-audit)

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
