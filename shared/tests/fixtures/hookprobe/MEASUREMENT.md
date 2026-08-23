# 훅 쓰기-경로 우회 — 실측 리포트 (2026-08-22, Claude Code 2.1.239)

## 문제
`plugins/{spec-distill,quality-gates,project-init}/hooks/hooks.json` 의 PostToolUse
matcher 가 `Write|Edit|MultiEdit` 로 **도구를 열거**한다. Bash(heredoc/sed)로 쓴 파일은
matcher 밖이라 훅이 한 번도 안 돈다.

## M0 — 번들 훅 이벤트 레지스트리 (offset 305341559, v2.1.239)
훅 이벤트 29개 중 matcher 미지원 9개. 관련된 것:

| 이벤트 | matcher field | 집행력 |
|---|---|---|
| PostToolUse | tool_name | exit 2 → 모델에게 stderr 즉시 |
| PostToolBatch | **없음** | exit 2 → 루프 정지(stderr 사용자만) · additionalContext → 모델 |
| FileChanged | 감시할 **파일명** | 없음 (exit≠0 은 사용자만) |

## M1 — matcher 생략 프로브 (Write + Bash heredoc ×2)
- **PostToolUse 에서 `matcher` 키를 생략하면 전체 도구에 발화한다.** Write·Bash 모두 포착.
- PostToolBatch payload keys: cwd, effort, hook_event_name, permission_mode,
  prompt_id, session_id, tool_calls, transcript_path.
  tool_calls[] 원소: tool_input, tool_name, tool_response, tool_use_id.
- FileChanged: 세 matcher 변형(flat / `docs/superpowers/specs/*.md` / `*.md`) 모두 **0건**.
- CwdChanged: 0건.

## M2 — subagent 프로브
- subagent 의 Bash heredoc 에 **PostToolUse·PostToolBatch 둘 다 발화**.
- **`agent_id` 로 main/subagent 구분 가능** (subagent=값, main=없음).
  → 기존 기록(2.1.228 에서 PostToolUse 에 agent_id 없음)은 2.1.239 에서 무효. 메모리 정정함.

## 결론
가장 가벼운 해법 = **`matcher` 키를 지운다.** 도구 열거가 사라져 미래 도구까지 덮이고,
exit 2 → 모델 피드백이라는 기존 Law 1 집행 의미가 그대로 보존된다.
남는 일: Write/Edit 이 아닌 호출에서 "스코프 안 파일이 바뀌었나"를 파일시스템에 묻는
공유 감지 모듈, 그리고 훅이 매 도구 호출마다 도는 비용의 상한.

## 확인 못 한 것 (부재 증명 아님)
- FileChanged 가 헤드리스에서 안 도는 것인지, matcher 문법이 틀린 것인지 미분리.
- matcher 제거 후 실제 턴당 훅 호출 횟수·지연 (미측정).

## 재현하는 법

```bash
PROBE="$(cd "$(dirname "$0")" && pwd -P)"          # 이 픽스처 디렉토리
WS="$(cd "$(mktemp -d)" && pwd -P)" || exit 1      # /tmp→/private/tmp 정규화 필수
cd "$WS" && git init -q . && echo ok > seed.txt \
  && git add -A && git -c user.email=p@p -c user.name=p commit -qm seed

export HOOKPROBE_LOG="$WS/events.jsonl"
printf '%s' 'Do exactly these three things in order, then stop with no commentary:
1. Use the Write tool to create the file probe_write.txt containing the text w1
2. Use the Bash tool with a heredoc to create probe_bash.txt containing b1
3. Use the Bash tool with a heredoc to create docs/superpowers/specs/nested.md containing "# n1"' \
  | claude -p --plugin-dir "$PROBE" --permission-mode acceptEdits \
           --output-format stream-json --verbose > "$WS/stream.json"

python3 -c 'import json,sys
for ln in open(sys.argv[1], encoding="utf-8"):
    r = json.loads(ln); p = r["payload"]
    print(r["event"], p.get("tool_name"), p.get("agent_id"))' "$HOOKPROBE_LOG"
```

**`--permission-mode acceptEdits` 를 빼면 편집이 rc 0 으로 조용히 죽는다** — 그러면 훅이
발화할 일 자체가 없어 "발화 안 함"으로 오판한다.

subagent 경로는 프롬프트만 바꾼다: *"Use the Agent tool (subagent_type general-purpose) to
dispatch one subagent. The subagent task is exactly: use the Bash tool with a heredoc to
create sub_bash.txt containing s1."*

## 번들 훅 이벤트 레지스트리 읽는 법

공개 문서보다 정확하다. 바이트 검색 + 앞뒤 window 로 꺼낸다 (`strings` 는 긴 JS 한 줄을
잘라 먹는다):

```bash
python3 - "$(readlink -f "$(which claude)")" <<'PY'
import sys, pathlib
data = pathlib.Path(sys.argv[1]).read_bytes()
i = data.find(b'PostToolUse:{summary')
print(data[i-4000:i+14000].decode('utf-8', 'replace'))
PY
```
