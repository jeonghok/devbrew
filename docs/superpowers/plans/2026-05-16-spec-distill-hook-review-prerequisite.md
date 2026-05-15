# Prerequisite — quality-gates hook output protocol (V8)

> C9 준수: spec-distill PostToolUse / Stop hook 구현 전 empirical 확인.
> 이 문서는 T8 (PostToolUse) / T9 (Stop) 구현자가 quality-gates 소스를
> 다시 읽지 않아도 되도록 충분히 구체적이어야 함.

## PostToolUse (`post-tool-use.py`)

### 역할

`gh pr create`가 성공한 직후 PR URL을 감지해 quality-gates 파이프라인 시작을
트리거하는 **notification-only** hook. 블로킹 차단 로직은 없음.

### stdin 페이로드 schema

```
{
  "tool_name": str,          # "Bash" 이외이면 즉시 exit(0)
  "tool_input":  {"command": str, ...},
  "tool_response": {"stdout": str, ...} | str,
  "session_id":  str,        # 비어있으면 exit(0)
  "cwd":         str
}
```

### Block 메커니즘

**없음.** 이 hook은 차단하지 않는다. 모든 분기가 `sys.exit(0)`으로 종료.

- L37: kill switch 적용 → `print(json.dumps({}))` + `sys.exit(0)`
- L41–42: JSON 파싱 실패 → 빈 JSON + exit(0)
- L50–51: tool != "Bash" 또는 session 없음 → 빈 JSON + exit(0)
- L54–56: command에 `gh pr create` 패턴 없음 → 빈 JSON + exit(0)
- L62–64: state_file 이미 존재(파이프라인 중) → 빈 JSON + exit(0)
- L73–75: PR URL 감지 실패 → 빈 JSON + exit(0)
- L90–91: 정상 경로(PR URL 감지 성공) → systemMessage 주입 + exit(0)

### stdout JSON keys (정상 경로, L80–90)

```python
result = {
    "systemMessage": (
        f"Quality Gates: PR created at {pr_url}. "
        "You MUST now initialize the quality-gates pipeline. "
        f'Run: Bash("{setup_script} --session-id {session_id} --pr-url {pr_url}") '
        'Then invoke Skill("quality-gates:quality-pipeline") with gate=1 '
        "to begin Gate 1."
    )
}
print(json.dumps(result))
sys.exit(0)
```

- **키:** `systemMessage` 단일 키
- **결정 키(`decision`) 없음** — PostToolUse hook은 차단 결정을 내리지 않음
- **stderr:** 정상 경로에서 사용 없음; 파싱 오류 시 Python 기본 traceback만

### kill switch (L27–31)

```python
DEVBREW_DISABLE_QUALITY_GATES=1          # 전체 비활성화
DEVBREW_SKIP_HOOKS=quality-gates:post-tool-use  # 이 hook만 skip
```

whole-token match (쉼표 분리), substring prefix-match 방지.

---

## Stop (`stop-hook.py`)

### 역할

파이프라인 진행 상태를 파일에서 파싱하고, `<qg-signal>` 태그를 읽어 다음 게이트
프롬프트를 주입하는 **파이프라인 오케스트레이터** hook.

### stdin 페이로드 schema

```
{
  "session_id":             str,
  "last_assistant_message": str | {"content": [{"type":"text","text":str},...]} ,
  "transcript_path":        str   # last_assistant_message fallback용
}
```

- L172: `hook_input.get("last_assistant_message", "")` — 우선 소스
- L850–851: `last_assistant_message` 없으면 `transcript_path` fallback

### `<qg-signal>` 태그 파싱 (L188–193)

```python
matches = re.findall(r"<qg-signal\s+(.*?)\s*/>", last_msg)
attrs = dict(re.findall(r'(\w+)="([^"]*)"', matches[-1]))
```

self-closing XML 속성 형식: `<qg-signal gate="1" verdict="PASS" />`

### stdout JSON schema

**모든 블로킹 경로가 동일한 3-키 구조를 사용:**

```python
print(json.dumps({
    "decision":      "block",   # 항상 "block" — continue 결정 없음
    "reason":        str,       # 사용자에게 보이는 다음 프롬프트 텍스트
    "systemMessage": str,       # Claude에 주입되는 시스템 메시지
}))
sys.exit(0)
```

출처 라인:

| 위치 | 경로 |
|------|------|
| L807–811 | `emit_continuation()` 헬퍼 (정상 진행 경로 공통) |
| L861–866 | 신호 없음 → 현재 게이트 재주입 (ralph-loop 패턴) |
| L888–900 | state-file 쓰기 실패 → PIPELINE_ERROR abort |

### `systemMessage` 주입 방식 (L801–812)

```python
def emit_continuation(prompt, sys_msg):
    print(json.dumps({
        "decision": "block",
        "reason": prompt,
        "systemMessage": sys_msg,
    }))
    sys.exit(0)
```

- `reason` = 다음 게이트 Markdown 프롬프트 (사용자 표시용)
- `systemMessage` = Claude 다음 턴 컨텍스트 주입용 짧은 요약 문자열

### 비활성화(exit, no output) 경로

- L817: kill switch → `sys.exit(0)` (JSON 없음 — hook API가 exit(0) = passthrough로 해석)
- L820–821: JSON 파싱 실패 → `sys.exit(0)`
- L824–825: session_id 없음 → `sys.exit(0)`
- L829–830: state_file 없음(파이프라인 미실행) → `sys.exit(0)`
- L904–907: 완료/abort → 폴더 삭제 후 `sys.exit(0)`

### kill switch (L794–798)

```python
DEVBREW_DISABLE_QUALITY_GATES=1          # 전체 비활성화
DEVBREW_SKIP_HOOKS=quality-gates:stop-hook  # 이 hook만 skip
```

---

## 본 plan에 미치는 영향

### Layer 1 — spec-write-validator.py (PostToolUse)

- **차단 메커니즘:** `exit 2` + `stderr` 메시지 (Claude Code harness가 exit 2를 차단으로 해석)
  - quality-gates post-tool-use.py는 차단 없이 exit(0)만 사용하므로 참조 패턴 없음
  - exit 2 패턴은 harness 문서 기준으로 구현; quality-gates는 notification-only이므로 exit 2 미사용
- **stdout 출력 필요 여부:** exit 2만으로 충분; `{"decision": "block", "reason": "..."}` stdout은 Stop hook 전용 키이므로 PostToolUse에서는 사용하지 않음
- **결론:** spec-write-validator.py는 `sys.exit(2)` + `print(..., file=sys.stderr)` 패턴을 사용해야 하며, quality-gates PostToolUse와 달리 `decision` 키 stdout은 불필요

### Layer 2 — review-dispatch.py (Stop)

- **systemMessage 주입 JSON key:** `{"decision": "block", "reason": "...", "systemMessage": "..."}` — 3-키 구조 확정 (L807–811)
- **`decision` 값:** 항상 `"block"` — Stop hook에서 `"continue"`를 명시 emit하는 코드는 없음 (exit(0) no-output이 사실상 continue)
- **신호 없을 때:** `{"decision": "block", "reason": <현재 게이트 프롬프트>, "systemMessage": <짧은 요약>}` — 재주입 루프 (L861–866)
- **결론:** review-dispatch.py는 동일한 3-키 구조를 사용해야 하며, `emit_continuation()` 헬퍼 패턴(`print(json.dumps({...}))` + `sys.exit(0)`)을 그대로 채택

### 핵심 비대칭 정리

| | PostToolUse (post-tool-use.py) | Stop (stop-hook.py) |
|---|---|---|
| 차단 메커니즘 | 없음 (notification only) | `{"decision":"block",...}` + exit(0) |
| stdout 정상 경로 | `{"systemMessage": "..."}` | `{"decision":"block","reason":"...","systemMessage":"..."}` |
| exit(2) 사용 | 없음 | 없음 |
| stderr 사용 | 없음 (오류 시 Python traceback) | 경고 메시지 (`⚠️ Quality Gates: ...`) |
| 신호 소스 | N/A | `last_assistant_message` → `transcript_path` fallback |

**T8 구현자:** PostToolUse로 차단하려면 harness 문서 기준 `exit(2)` 사용. quality-gates는 차단 없이 알림만 하므로 exit(2) 레퍼런스가 없음 — harness 원문 참조 필수.

**T9 구현자:** Stop hook 출력은 반드시 `{"decision":"block","reason":"...","systemMessage":"..."}` 3-키 구조. `reason`은 사용자 표시 프롬프트, `systemMessage`는 Claude 컨텍스트 주입.
