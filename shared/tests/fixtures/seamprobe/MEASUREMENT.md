# seamprobe — 이음매 채널 실측 (claude 2.1.252 / M6 은 2.1.258, 헤드리스 `claude -p`)

`hookprobe` 의 형제. 그쪽은 도구 이벤트를, 이쪽은 **이음매 채널**(턴·압축·커맨드 확장)을 잰다.

## 결과

| # | 대상 | 결과 |
|---|---|---|
| M1 | `FileChanged` matcher | `watched.txt`(마침표)·`watchedplain`(letters+`_` 만) **둘 다 0회**. 파일은 실제로 변경됨(`hit1` 추가 확인). **문자집합 가설 기각.** |
| M2 | `SessionStart` matcher | `fieldToMatch: source`. `startup` 발화 / `resume`·`compact` 미발화 → 정확히 필터. `--continue` → `source: resume`. 압축 후 → `source: compact`. stdout→모델 **2/2** |
| M3 | 압축 사슬 | `/compact` → `PreCompact{trigger:manual}` → 압축 → `SessionStart{source:compact}` + `PostCompact{trigger:manual}`. 세 stdout 이 **전부 압축을 넘어 모델 도달 3/3** |
| M4 | `UserPromptExpansion` | 발화. matcher=`command_name` 정확 필터(`seamprobe:ping` matcher 는 `echoscan` 에 안 걸림). payload = `command_name`·`command_source:plugin`·`expansion_type:slash_command`. stdout→모델 **1/1** |
| M5 | 번들 이벤트 레지스트리 | 34개. `PreCompact` payload 에 `custom_instructions` 필드 실재 |
| M6 | `PostToolUse`(matcher `Bash`) 의 `hookSpecificOutput.additionalContext` | **메인 대화 모델에 도달 1/1.** 난수 카나리를 `additionalContext` 에**만** 싣고(`stdout` 미사용) 도구 호출 뒤에 물었더니 모델이 그대로 에코했다. payload 키 = `tool_name`·`tool_input`·`tool_response`·`tool_use_id`·`permission_mode`·`effort`·`prompt_id`·`duration_ms`·`session_id`·`cwd`·`transcript_path` |

**분기 판정:** COMPACT_CHANNEL_OK · UPE_CHANNEL_OK · **PTU_AC_CHANNEL_OK** · FILECHANGED_UNCONFIRMED

**M6 이 왜 별도 모드인가** — `dump.py` 의 `stdout` 과 `json_ac` 는 **다른 계약**이다. 한 프로브가
둘을 함께 내면 카나리가 도착했을 때 어느 쪽이 날랐는지 갈리지 않는다. M6 은 `json_ac` 만 켜고
쟀으므로 도착의 원인이 `additionalContext` 로 확정된다.

**matcher 가 중요한 이유** — 이 리포의 선행 설계문서(`docs/superpowers/specs/2026-08-05-agent-transparency-design.md:361`)
는 같은 이벤트를 ✅ 로 적되 **matcher `Agent` 한정**으로 썼다. M6 은 matcher **`Bash`** 로 쟀다 —
`quality-gates`·`project-init` 두 훅이 실제로 쓰는 matcher 다.

## 확인 못 한 것 (부재 증명 아님)

- `FileChanged` 0회의 원인 — 헤드리스에서 watcher 미기동인지, 에이전트 자신의 편집이 watch 대상이 아닌지 **미분리**.
- 대화형(TUI) 미측정. 전부 `claude -p`.
- 빈도 미측정 — M2 의 `source` 필터만 여러 번, 나머지는 변형당 1회. **M6 도 1회다.**
- `PostCompact` 는 레지스트리가 *"stdout shown to user"* 라 적었는데 **모델이 카나리를 에코했다.** 어느 쪽이 계약인지 미확정.
- M6 에서 모델이 낸 **출처 서술**("`PostToolUse:Bash` 훅 블록으로 도착했다")은 자기보고다. 단단한
  사실은 **난수 토큰이 컨텍스트에 있었다**는 것 하나이고, 그 문자열을 낸 것은 그 훅뿐이다.
- M6 은 `systemMessage` 를 **함께 내지 않았다** — 「사람 채널로 보낸 것을 모델이 못 본다」는 반대
  방향의 명제는 이 픽스처가 아직 안 쟀다.

## 재현하는 법

```bash
PROBE="$(cd "$(dirname "$0")" && pwd -P)"
WS="$(cd "$(mktemp -d)" && pwd -P)" || exit 1      # /tmp→/private/tmp 정규화 필수
cd "$WS" && git init -q . && printf 'seed\n' > watched.txt && printf 'seed\n' > watchedplain \
  && git add -A && git -c user.email=p@p -c user.name=p commit -qm seed

export SEAMPROBE_LOG="$WS/events.jsonl"
export SEAMPROBE_TOKEN="$(python3 -c 'import secrets;print(secrets.token_hex(6))')"

# --- M1/M2: 파일 변경 + SessionStart 필터 + stdout 도달 ---
export SEAMPROBE_EMIT_SS_startup=stdout
printf '%s' 'Do these in order, then stop.
1. If your context contains any token beginning with INJ-, output each one prefixed with ECHOTOKEN: . Otherwise output NOCANARY.
2. Use the Bash tool with a heredoc to append the line hit1 to watched.txt
3. Use the Bash tool with a heredoc to append the line hit2 to watchedplain' \
  | claude -p --plugin-dir "$PROBE" --permission-mode acceptEdits \
      --output-format stream-json --verbose > "$WS/s1.json"

# --- M3: 실제 압축 (히스토리 ≥7턴 필요 — 부족하면 "Not enough messages to compact.") ---
export SEAMPROBE_EMIT_PRECOMPACT_manual=stdout
export SEAMPROBE_EMIT_SS_compact=stdout
export SEAMPROBE_EMIT_POSTCOMPACT=stdout
claude -p --plugin-dir "$PROBE" "Reply with exactly: T1" >/dev/null
for i in 2 3 4 5 6 7; do
  claude -p --continue --plugin-dir "$PROBE" "Reply with exactly: T$i" >/dev/null
done
printf '%s' '/compact' | claude -p --continue --plugin-dir "$PROBE" >/dev/null
printf '%s' 'Output every INJ- token in your context prefixed with ECHOTOKEN: , else NOCANARY.' \
  | claude -p --continue --plugin-dir "$PROBE"

# --- M4: 커맨드 확장 ---
export SEAMPROBE_EMIT_UPE_nomatcher=stdout
printf '%s' '/seamprobe:echoscan' | claude -p --plugin-dir "$PROBE"

# --- M6: PostToolUse(matcher Bash) 의 additionalContext 도달 ---
# `stdout` 이 아니라 `json_ac` 만 켠다 — 도착의 원인을 채널 하나로 확정하기 위해서다.
export SEAMPROBE_EMIT_PTU_bash=json_ac
printf '%s' 'Do these two steps in order, then stop.
1. Use the Bash tool to run exactly: echo probe-step-one
2. AFTER that command has completed, scan your context and output every token that begins with INJ- , each on its own line prefixed with ECHOTOKEN: . If there are none, output exactly NOCANARY.' \
  | claude -p --plugin-dir "$PROBE" --permission-mode acceptEdits \
      --output-format stream-json --verbose

python3 -c 'import json,sys
for ln in open(sys.argv[1],encoding="utf-8"):
    r=json.loads(ln); p=r["payload"]
    print(r["label"], {k:p[k] for k in ("source","trigger","command_name") if k in p})' "$SEAMPROBE_LOG"
```

**`--permission-mode acceptEdits` 를 빼면 편집이 rc 0 으로 조용히 죽는다.**
**카나리는 INJ(주입)/ECHOTOKEN(반향)으로 쪼개야** 「훅이 돌았다」와 「모델이 봤다」가 갈린다.

## 번들 레지스트리 읽는 법

```bash
python3 - "$(readlink -f "$(which claude)")" <<'PY'
import sys, pathlib, re
data = pathlib.Path(sys.argv[1]).read_bytes()
i = data.find(b'PostToolUse:{summary')
blob = data[i-3000:i+30000].decode('utf-8','replace')
for n, s in dict(re.findall(r'([A-Z][A-Za-z]+):\{summary:"([^"]*)"', blob)).items():
    print(f"{n:22s} {s}")
PY
```

---

## 부록 — 번들 스키마 판독 (실행 측정이 **아님**)

아래는 프로브를 태워 얻은 것이 **아니라** `claude` 번들에서 읽은 것이다. 지위가 다르므로
위 M1–M5 와 섞지 말 것. 다만 공개 문서·번들의 사람용 `description` 문자열보다 정확하다.

**추출 방법이 둘이고 결과가 다르다 — 이것이 이 부록의 요점이다.**

| 방법 | 무엇을 읽나 | 신뢰도 |
|---|---|---|
| ① `<Event>:{summary…description…}` | 사람용 산문 서술 | **불완전하다.** payload 필드를 빠뜨린다 |
| ② `hook_event_name:N("<Event>")` 뒤의 zod 스키마 | 실제 payload 계약 | 이쪽이 정본 |

`SubagentStop` 이 실례다 — ①은 *"Input to command is JSON with agent_id, agent_type, and
agent_transcript_path"* 라고만 적는데, ②에는 `stop_hook_active` 와 `last_assistant_message` 와
`background_tasks` 가 더 있다. ①만 읽고 「없다」를 단정하면 틀린다(2026-09-02 실제로 틀렸다).

### ②로 읽은 payload 스키마 (2.1.252)

| 이벤트 | 필드 |
|---|---|
| `Stop` | `stop_hook_active` · `last_assistant_message`(opt) · `background_tasks`(opt) |
| `SubagentStop` | `stop_hook_active` · `agent_id` · `agent_transcript_path` · `agent_type` · `last_assistant_message`(opt) · `background_tasks`(opt) |
| `SubagentStart` | `agent_id` · `agent_type` |
| `StopFailure` | `error` · `error_details`(opt) · `last_assistant_message`(opt) |
| `PreCompact` | `custom_instructions` · `compact_summary` |
| `PostCompact` | `compact_summary` |

`last_assistant_message` 의 서술: *"Text content of the last assistant message before stopping.
Avoids the need to read and parse the transcript file."*

### ①로 읽은 matcher·출력 계약 (서술이므로 위 경고가 그대로 적용된다)

| 이벤트 | matcher 가 무엇에 걸리나 | exit 0 |
|---|---|---|
| `SessionStart` | `source` — `startup\|resume\|clear\|compact\|fork` | stdout → Claude |
| `PreCompact` / `PostCompact` | `trigger` — `manual\|auto` | 각각 「compact instructions 로 덧붙음」 / 「stdout → user」 |
| `UserPromptExpansion` | `command_name` | stdout → Claude. **exit 2 = 확장 차단** |
| `SubagentStart` | `agent_type` | JSON `additionalContext` → subagent |
| `FileChanged` | 감시할 파일명(현재 디렉토리) | 집행력 없음. `hookSpecificOutput.watchPaths` 로 감시 목록 갱신 가능 |

전체 이벤트는 34개다.

### 재현

```bash
python3 - "$(readlink -f "$(which claude)")" <<'PY'
import sys, pathlib, re
d = pathlib.Path(sys.argv[1]).read_bytes()

# ② payload 스키마 — 이쪽이 정본
i = d.find(b'hook_event_name:N("Stop")')
blob = d[i-200:i+4200].decode('utf-8', 'replace')
for ev in ["Stop", "StopFailure", "SubagentStart", "SubagentStop", "PreCompact", "PostCompact"]:
    m = re.search(r'hook_event_name:N\("' + ev + r'"\),(.{0,420})', blob, re.S)
    if m:
        print(ev, re.findall(r'(\w+):(?:i\(\)|q\(\)|Nu\(\)|P\(\)|[A-Za-z_$]+\(\))', m.group(1))[:9])

# ① 서술 — 불완전하다는 것을 알고 읽을 것
j = d.find(b'PostToolUse:{summary')
b2 = d[j-3000:j+30000].decode('utf-8', 'replace')
for n, s in dict(re.findall(r'([A-Z][A-Za-z]+):\{summary:"([^"]*)"', b2)).items():
    print(f"{n:22s} {s}")
PY
```

**미측정으로 남는 것** — 위 스키마가 선언하는 필드가 런타임에 실제로 실려 오는지는 이 부록이
재지 않았다. `stop_hook_active` 와 `last_assistant_message` 를 실제로 받아 보려면 `Stop` 또는
`SubagentStop` 훅을 붙인 프로브가 필요하고, 이 픽스처에는 아직 없다.

### 런타임 도달은 이 픽스처가 재지 않았다 — **리포에 이미 있다**

위 스키마 표의 필드가 런타임에 실제로 실려 오는지는 이 픽스처의 프로브가 아니라
`docs/superpowers/specs/2026-08-05-agent-transparency-design.md` 가 2026-08-13 실측으로 기록한다:

- `:157` · `:1857` — `stop_hook_active` 가 `False → True → True` 로 전이하는 것을 관측.
- `:1805` — 에이전트 최종 메시지 필드가 *"페이로드에 실제로 온다(실측)"*.
- `:1855-1861` — **subagent 종료 훅에 `additionalContext` 를 실으면 그 subagent 가 종료되지 않고
  계속 돈다.** 에이전트 **하나**에 훅이 **3회** 발화했고 매 발화마다 응답이 하나 더 생성됐다.
  그 probe 가 emit 상한 2를 걸어 3회에 멈춘 것이고 **당시 구현된 훅에는 상한이 없었다.**
  플랫폼 상한은 `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`(기본 8).

**관측과 주입은 다른 술어다** — 출력 없이 정상 종료하는 훅은 이 폭주를 일으키지 않는다. 그리고
같은 자리가 에이전트 하나당 여러 번 발화하므로 그 층에서 세는 설계는 중복 계수를 다뤄야 한다.

**교훈** — 이 픽스처를 만든 사이클은 번들을 파고 프로브를 짜기 전에 리포를 뒤지지 않았고,
그 사이 형제 세션에 틀린 사실을 한 번 보냈다. 하니스 동작 사실을 재기 전에
`docs/superpowers/specs/` 를 먼저 훑을 것.
