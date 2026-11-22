---
name: roadmap-draft
description: >
  사용자가 `/spec-distill:roadmap-draft @<결과물 경로>` 로 부른다. 「나눈다」 로 끝나 커밋된 결과물(brief)에서
  에픽 분해안 표를 짜 승인받고, 로드맵과 에픽 묶음을 만들어 로드맵 폴더와 상태 파일을 커밋한다.
metadata:
  cost_class: medium
argument-hint: "@<결과물 경로>"
allowed-tools:
  - Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill roadmap-draft)
---

# roadmap-draft — 로드맵 잡기


<!-- plain-language:begin -->
## 사람에게 쓰는 글
이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. 지시문·subagent 프롬프트·state 파일에는 적용하지 않는다. 아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다. 추천 표시와 대가 표기는 그 자리에서도 이 블록을 따른다 — 옮긴 질문의 선택지 순서와 설명, steelman 질문의 선택지 순서와 출처 표지만 예외다. 부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고, 이 블록은 낱말에만 적용한다.
- 처음 보는 사람이 한 번에 이해하게 쓴다. 번호·해시·필드 이름·내부 용어는 가리키는 내용을 문장으로 먼저 쓰고 괄호 안에만 둔다. 지어낸 말은 쓰지 않거나 처음 쓸 때 풀어 쓴다.
- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일. 할 일은 기본 하나다 — 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다. 할 일이 없으면 없다고 쓴다. 커밋·PR 본문에는 이 순서를 적용하지 않는다.
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두. 추천이 있는 질문은 질문 창만 보고 고를 수 있게 쓴다 — 질문 위 글은 안 보일 수 있다. 모든 선택지의 설명을 「얻음: … · 내줌: …」 한 줄(길어도 세 줄)로 쓰고, 내줌은 그 선택이 틀렸다고 드러날 때 원인이 될 것 하나다. 추천이 없으면 아무 표시도 쓰지 않는다. 질문 없이 한쪽을 권하는 글에는 그 대가를 한 구절 붙인다.
- 제목과 목록으로 나누되 표의 칸은 짧게 쓴다. 굵은 글씨는 꼭 필요한 곳에만 쓴다.
- 사용자가 알 필요 없는 글은 쓰지 않는다: 도구 호출 사이의 진행 설명, 전부 정상인 항목의 나열. 확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.
- 판정·개수·공시 줄은 스크립트가 낸 쉬운 첫 줄을 그대로 쓰고, 자기 말로 다시 풀거나 덧붙이지 않는다. 스크립트·subagent 가 낸 원문은 고치지 않는다. 스크립트가 풀어 두지 않은 오류에만 쉬운 설명을 앞에 붙이되 통과·실패는 말하지 않는다.
- 사용자와 대화하는 언어로 쓴다. 코드·명령·고유명사·자연스러운 대응어가 없는 기술어는 영어 그대로 둔다. 커밋·PR은 그 레포의 규칙을 따르고, 없으면 대화 언어로 쓴다.
예) 전: `[미적용 fix] 3720b2b7#r1.1` → 후: 리뷰가 고치라고 한 곳 하나가 아직 안 고쳐졌다(3720b2b7#r1.1).
예) 전: (codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건) → 후: 이상 없음.
예) 전: 설명 「더 낫다」 → 후: 「얻음: 겹치는 규칙을 한 번에 고친다 · 내줌: 일이 커져 설계가 길어진다」.
<!-- plain-language:end -->

!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill roadmap-draft`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽고 아래 순서대로 간다. 감시줄 아래에 `[devbrew-switch]` 로 시작하는 줄이 있으면 감시줄이 무엇이든 그 줄들을 고치지 않고 사용자에게 보인다.

### 1. 감시줄 판독

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 1.5 로 간다. 그 줄의 `root=` 값을 2 에서 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 멈춘다(no-op) |
| `[devbrew-entry] error …` | `[spec-distill] roadmap-draft 사전 검사 실패 — <reason= 값>. 로드맵을 잡지 않는다.` 를 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[spec-distill] roadmap-draft 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다. 로드맵을 잡지 않는다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[spec-distill] roadmap-draft 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다. 로드맵을 잡지 않는다.` 를 내고 멈춘다 |

이 표가 보는 kill switch 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 하나다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다.

### 1.5 의존 확인

아래 펜스를 Bash 로 한 번 돌린다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
python3 "$SD/scripts/check_deps.py" entry --plugin-root "$SD" --need python,git
```

| 결과 | 동작 |
|---|---|
| rc 0 (`[devbrew-deps] ok …`) | 2 로 간다 |
| rc 3 (`[devbrew-deps] 멈춤 …`) | 펜스 출력을 그대로 보이고 멈춘다. 로드맵을 잡지 않는다 |
| 그 밖 | `[spec-distill] roadmap-draft 의존 확인 실패 — 필요한 프로그램의 판을 확인하지 못했다(rc <값>). 로드맵을 잡지 않는다.` 와 펜스 출력을 내고 멈춘다 |

### 2. `@경로` 풀기와 진입 검사

받은 인자의 앞뒤 공백을 걷은 값이 `@` 로 시작하는 공백 없는 한 토큰이어야 한다. 아니면 `[spec-distill] roadmap-draft 인자는 결과물 경로 한 토큰(@<경로>)이다 — 받은 것: <인자>. 로드맵을 잡지 않는다.` 를 내고 멈춘다. `@` 를 뗀 경로를 감시줄 `root=` 기준 절대경로로 푼다. 그 경로에 큰따옴표 · `$` · 역따옴표 · `\` · 줄바꿈 · 제어 글자가 있으면 셸에 붙이지 않고 그 사실을 보이고 멈춘다 — 아래 펜스들은 이 경로를 큰따옴표 안에 넣는다. 이 절대경로가 아래 모든 펜스의 `<결과물 절대경로>` 다. audit · 상태 파일은 그 경로 끝의 `.md` 를 `.audit.md` · `.state.md` 로 바꾼 자리다.

아래 펜스의 자리표를 바꿔 Bash 로 한 번 돌린다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<결과물 절대경로>"
case "$BRIEF" in ""|*"<"*) echo "[spec-distill] 진입 검사 입력 부재 — BRIEF 가 비었거나 자리표 그대로다(결과물 절대경로로 바꿔 다시 돌려라)." >&2; exit 2 ;; esac
python3 "$SD/scripts/roadmap_draft_entry.py" --brief "$BRIEF"
```

마지막 줄이 판결이다. 첫 줄(`raw-source:`)은 `## 1. 읽기` 에서 쓴다.

| 마지막 줄 | 동작 |
|---|---|
| `roadmap-entry: OK` | `## 1. 읽기` 로 간다 |
| `roadmap-entry: RESUME` | 아래 「다시 불렀을 때」 로 간다 |
| `roadmap-entry: STOP` | `roadmap-entry: STOP <사유>` 줄들을 고치지 않고 보이고 멈춘다. 사유가 분해됨 줄이 없다는 것이면 나눌지를 이 단계에서 묻지 않는다 — 나눌지는 컨텍스트 쌓기에서 정한다. 사유가 위험 줄 번호면 결과물을 고치지 않고 `## 되돌아가는 길` 의 둘째 갈래대로 길 둘을 보인다 |
| 판결 줄 없음 · 그 밖 | 출력을 그대로 보이고 멈춘다 |

**다시 불렀을 때.** 판결이 `RESUME` 이면 앞선 로드맵 잡기가 도중에 끊긴 것이다(상태 파일에 분해안 표나 생성 기록이 있다). `roadmap-entry: RESUME <무엇이 있는가>` 줄을 그대로 보이고 `AskUserQuestion` 하나로 묻는다 — 「그 표에서 이어 간다」 · 「표를 버리고 처음부터」. 설명은 이렇게 쓴다 — 「그 표에서 이어 간다」: 얻음: 앞서 짠 표를 다시 보고 승인만 다시 받아 생성으로 간다 · 내줌: 그사이 결과물이나 코드가 바뀌었으면 낡은 표를 다시 승인하게 된다 / 「표를 버리고 처음부터」: 얻음: 결과물과 코드를 다시 읽고 표를 새로 짠다 · 내줌: 앞서 짠 표와 고친 내용을 버린다. 권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다. 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다.

- 「그 표에서 이어 간다」 — `## 1. 읽기` 를 마친 뒤 그 표를 `## 3. 분해안 표` 의 화면으로 다시 보이고(그 절의 펜스로 수를 다시 센다) `## 4. 고치기 · 승인` 에서 승인을 다시 받는다. 옛 흐름에서 승인만 하고 끊긴 표도 같은 길이다.
- 「표를 버리고 처음부터」 — 상태 파일의 `## 분해안` 절을 비우고 `## 1. 읽기` 부터 간다. `## 생성 기록` 은 그대로 둔다 — 새 표로 생성할 때 그 기록의 파일만 덮어쓴다.

## 1. 읽기

진입 검사의 첫 줄을 한 줄로 보인다 — `raw-source: FOUND <경로>` 면 「원자료: 읽음 — <경로>」, `raw-source: LOST <사유>` 면 「원자료: 찾지 못함 — <사유>」, `raw-source: NO-FRAMING` 이면 「원자료: 없음」. 이 줄은 막지 않는다.

결과물 전문 · audit · 상태 파일과, 찾았으면 원자료를 읽은 뒤에 표를 제안한다 — 원자료는 찾은 기록 파일의 `## 1. 원문` 절과 `## 2. 질문 전체` 절이다. 넘겨받는 것은 결과물 · audit · 상태 파일 · 원자료뿐이다 — 레포의 코드와 다른 로드맵 파일은 이 단계 자신의 조사다. 같은 세션에서 이어 왔어도 대화가 아니라 이 읽기부터 한다.

## 2. 나누기 전 확인

에픽으로 묶기 전에 결과물의 조사 근거(§4 · §5 의 `RC<n>` 줄)가 가리키는 고칠 자리를 연다 — 에픽마다 고칠 자리를 코드에서 열어 확인하고, 경로 예약에 그 근거를 함께 적는다. 표의 경로 예약 칸에는 경로만 쓴다 — 스크립트가 그 칸을 경로 목록으로 읽는다. 근거는 표 아래에 에픽마다 한 줄로(에픽 번호 · 경로 · 열어 본 자리나 `RC<n>`) 적는다. 레포의 다른 로드맵은 아래 펜스가 낸다(`/spec-distill:roadmap-status` 와 같은 명령 — `<root>` 는 감시줄의 `root=` 값). 로드맵마다 그 파일의 `경로 예약:` 칸을 읽어 다른 로드맵의 경로 예약과 겹치는지 본다 — 겹침은 막지 않고 표 아래에 보인다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/control_plane.py" show
```

## 3. 분해안 표

3. **분해안 표.** 에픽 표를 제안한다. 칸은 기본 열하나다:

   | 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |
   |---|---|---|---|---|---|---|---|---|---|---|

   - 번호는 `<대문자><숫자>`(보기: `R0` · `R1`, 먼저 확인할 일은 `P1`). 가능하면 첫 에픽은 걷는 뼈대 — 가장 얇게 끝에서 끝까지 도는 에픽이다.
   - 종류는 셋이다 — 「묶음」(에픽 묶음 파일을 만든다) · 「브랜치 <설계문서 경로>」(묶음 없이 이미 있는 설계문서를 가리킨다) · 「결정」(브랜치 없이 로드맵 결정 기록으로 끝난다). 「결정」이면 브랜치 칸은 「없음」이다. 그 밖의 브랜치 칸은 `<branch_prefix><kebab>` — 접두는 `get branch_prefix`(`repo_defaults.py`)의 값이다.
   - 범위는 `한다 … / 안 한다 …`. 의존 · 경로 예약은 쉼표로 나열하고 없으면 「없음」. 빈 칸은 두지 않는다. 칸 안의 `|` 는 `\|` 로 쓴다.
   - 배정 번호 — brief 에 쓸 모든 번호(확정 C · D, 열린 질문 OQ, 레포 근거 RC, steelman ST, 웹 «key», 위험 K, 발화 S)를 하나 이상의 에픽에 배정한다. 모든 에픽이 받드는 공통 제약은 여러 에픽에 넣는다. 묶음 없는 두 종류에는 발화(S)와 그 밖의 번호가 하나 이상씩 있어야 한다. 위험 K 는 결과물 §5 위험 줄에 박힌 번호다.
   - 받는 것 · 넘기는 것 — 에픽 사이 인터페이스다. 묶음 §7 에 이 두 칸이 글자 그대로 실린다.
   - 설계 흐름이 아닌 에픽(조사 · 측정 · 결정처럼 설계문서 대신 다른 산출물을 내는 일)이 하나라도 있으면 뒤에 선택 칸 여섯(크기 · 병렬 · 순서 이유 · 근거 · 흐름 · 산출물)을 더한 열일곱 칸으로 쓰고, 쓰지 않는 칸은 「없음」이다. 생성기는 「없음」이 아닌 선택 칸을 에픽 블록에 `- <칸>: <값>` 줄로 쓴다.
   - 흐름 · 산출물 칸의 뜻은 `${CLAUDE_PLUGIN_ROOT}/references/roadmap-ontology.md` 의 에픽 · 산출물 행이다. 조사 에픽은 종류 「묶음」에 `흐름` 「조사 — <단계 한 줄>」, `산출물` 에 결과 파일의 레포 상대경로를 쓴다 — 지휘자가 그 칸을 읽어 설계문서 대신 산출물을 내는 흐름으로 간다. 「결정」은 산출물 없이 로드맵 결정 기록으로 끝나는 일이다.

   표를 상태 파일 본문의 `## 분해안` 절에 위 머리 그대로 적는다 — 처음 적을 때 표 아래에 `고친 횟수: 0` 한 줄을 둔다. 적은 뒤, 승인 질문 전에 아래 펜스로 `roadmap_write.py check --brief … --audit … --plan-table <상태 파일>` 을 돌려 `roadmap-table:` 줄과 그 아래 목록을 고치지 않고 표 아래에 보인다 — 미배정 번호와 고아 발화는 모델이 세지 않는다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<결과물 절대경로>"
case "$BRIEF" in ""|*"<"*) echo "[spec-distill] 표 세기 입력 부재 — BRIEF 가 비었거나 자리표 그대로다(결과물 절대경로로 바꿔 다시 돌려라)." >&2; exit 2 ;; esac
python3 "$SD/scripts/roadmap_write.py" check --brief "$BRIEF" --audit "${BRIEF%.md}.audit.md" --plan-table "${BRIEF%.md}.state.md"
```

   - `roadmap-table: OK …` 면 승인 질문으로 간다.
   - `roadmap-table: FAIL …` 이면 그 줄과 목록을 보인 채 승인 질문으로 간다. 0 이 아닌 수가 있는 표는 생성기가 받지 않는다(`## 5.` 의 생성이 rc 1 로 돌아온다).
   - 첫 줄이 `brief-risk: FAIL` 이면 결과물 쪽 결함이다 — `## 되돌아가는 길` 의 둘째 갈래로 간다. 그 밖의 `roadmap-table: UNKNOWN <사유>` 면 표의 꼴을 고친 뒤 다시 돌린다.
   - rc 2 는 사용법 오류다 — 펜스가 글자 그대로인지 맞춘 뒤 한 번만 다시 돌리고, 또 rc 2 면 출력을 보이고 멈춘다.

## 4. 고치기 · 승인

4. **고치기 · 승인.** `AskUserQuestion` 하나 — 옵션 셋: 「승인」 · 「고치기」 · 「spec 하나로」. 설명은 이렇게 쓴다 — 「승인」: 얻음: 표를 확정하고 로드맵과 묶음을 만든다 · 내줌: 범위나 의존이 틀렸으면 만든 뒤에야 재분해로 고친다 / 「고치기」: 얻음: 고칠 곳을 말로 알려 새 표를 받는다 · 내줌: 고칠 때마다 표를 다시 읽고 확인해야 하고 세 번마다 계속할지 또 묻는다 / 「spec 하나로」: 얻음: 나누지 않고 결과물 하나를 설계로 넘긴다 · 내줌: 표에서 잡은 덩어리별 승인을 버리고 한 설계에 묶는다. 권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다. 고친 횟수는 `## 분해안` 절 안의 `고친 횟수: <n>` 한 줄에 센다 — 「고치기」 로 새 표를 적을 때마다 1 을 더한다. 세 번 고칠 때마다 「계속 고칠까요」를 묻고(옵션: 「계속 고친다」 · 「지금 표로 승인」 · 「spec 하나로」 — 권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다) 자동으로 끝내지 않는다. 「고치기」 면 고친 표를 `## 분해안` 절에 다시 적고 `## 3.` 의 펜스로 다시 센 뒤 이 질문으로 돌아온다. 「spec 하나로」 면 `## 되돌아가는 길` 의 첫 갈래로 간다.
5. **기록.** 승인되면 상태 파일 `## 분해안` 절의 표 아래에 `승인: 「<사용자가 고른 옵션 또는 말>」` 한 줄을 둔다. 로드맵 폴더는 `<roadmaps_dir><YYYY-MM-DD>-<주제 또는 주제-HHMM>/` 다(`roadmaps_dir` 은 레포 설정의 로드맵 폴더) — 폴더 이름은 brief 파일 이름(`<줄기>.md`)에서 끝의 `-interview.md` 를 뗀 것, 곧 brief 파일 이름의 날짜 · 주제 부분 그대로다. 결과물 §7 첫 줄의 `분해됨 — <로드맵 경로>` 는 앞 단계가 이 폴더의 `roadmap.md` 로 이미 썼다 — `## 6.` 의 커밋 펜스가 이 줄에서 로드맵 폴더를 도출한다.

## 5. 생성

표가 승인된 뒤에만 생성기를 돌린다. 펜스의 `<file>` 자리에는 `<결과물 절대경로>` 의 마지막 경로 성분(결과물 파일 이름)만 넣는다 — 절대경로를 넣지 않는다. 제목과 승인 원문은 각자의 heredoc 자리에 따옴표로 감싸지 않고 글자 그대로 넣는다. 제목에 줄바꿈이 있으면 넣지 말고 멈춰 그 사실을 사용자에게 보인다. 넣는 글에 그 자리의 구분 줄(`DEVBREW_ROADMAP_TITLE_EOF` · `DEVBREW_ROADMAP_APPROVAL_EOF`)과 똑같은 줄이 있으면 그 자리의 여는 줄과 닫는 줄의 구분자를 글에 없는 다른 낱말로 함께 바꾼다. 생성기는 말 하나를 한 줄로만 받는다 — 승인 원문이 여러 줄이거나 말이 여럿이면 `AF1=` 줄부터 그 닫는 구분 줄까지를 줄마다 `AF2` · `AF3` … 으로 하나씩 더하고, `--approval="$(cat "$AF<k>")"` 를 하나씩 붙인다(`=` 꼴 — 「-」 로 시작하는 말도 옵션으로 읽히지 않는다). 승인 원문은 이 펜스가 만든 임시 파일에만 살고 펜스가 끝나면 지워진다 — 세션 상태 폴더에 쓰지 않는다. 펜스 줄과 더하는 `AF<k>` 줄은 맨 앞 칸에서 시작한다 — 구분 줄 앞에 칸이 있으면 heredoc 이 닫히지 않는다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
IDIR="$(python3 "$SD/scripts/repo_defaults.py" get interview_dir)" || IDIR=""
[ -n "$IDIR" ] || { echo "[spec-distill] 인터뷰 폴더를 정하지 못했다 — 위 줄의 사유를 고친 뒤 다시 돌린다" >&2; exit 1; }
RMDIR="$(python3 "$SD/scripts/repo_defaults.py" get roadmaps_dir)" || RMDIR=""
[ -n "$RMDIR" ] || { echo "[spec-distill] 로드맵 폴더를 정하지 못했다 — 위 줄의 사유를 고친 뒤 다시 돌린다" >&2; exit 1; }
BRIEF_REL="${IDIR}<file>"
IFS= read -r title <<'DEVBREW_ROADMAP_TITLE_EOF'
<주제 한 줄>
DEVBREW_ROADMAP_TITLE_EOF
AD="$(mktemp -d "${TMPDIR:-/tmp}/roadmap-approval.XXXXXX")" || { echo "[spec-distill] 승인 원문 임시 폴더를 만들지 못했다" >&2; exit 1; }
trap 'rm -rf -- "$AD"' EXIT
AF1="$AD/1"
cat > "$AF1" <<'DEVBREW_ROADMAP_APPROVAL_EOF'
<승인 원문>
DEVBREW_ROADMAP_APPROVAL_EOF
c_rc=0
python3 "$SD/scripts/roadmap_write.py" create --brief "$BRIEF_REL" \
  --audit "${BRIEF_REL%.md}.audit.md" --plan-table "${BRIEF_REL%.md}.state.md" \
  --out "${RMDIR}<YYYY-MM-DD>-<주제 또는 주제-HHMM>/" --title="$title" \
  --date "<YYYY-MM-DD>" --approval="$(cat "$AF1")" || c_rc=$?
exit "$c_rc"
```

rc 0 이면 나온 `[spec-distill]` 줄을 그대로 보이고 `## 6. 커밋` 으로 간다. 생성기는 상태 파일에 `## 생성 기록` 절을 남긴다 — 실패해 표를 고친 뒤 다시 도는 것과 끊긴 뒤 이어 가며 도는 것은 같은 생성 기록 위에서 그 기록의 파일만 덮어쓴다(기록 밖의 파일은 건드리지 않는다). rc 1 이면 사유 줄을 그대로 보이고 사유로 가른다 — 생성기가 이번에 만든 파일은 이미 지워졌고 미리 있던 파일은 그대로다.

- 사유가 `unassigned` · `orphans` · `unknown_ids` 이거나 `brief 에서 줄을 찾지 못한 번호` 면 표를 고친다. `unknown_ids` 는 표가 brief 에 없는 번호(지운 위험의 K 등)를 배정한 것이다 — 표에서 그 번호를 뺀다. `brief 에서 줄을 찾지 못한 번호` 면 그 번호를 brief 에서 찾아 가른다 — brief 에 없으면 `unknown_ids` 와 같이 표에서 뺀다. brief 에 있으면 생성기가 그 줄을 읽지 못한 것이다(생성기의 빈틈) — 표를 고치지 않고 그 번호와 사유를 그대로 보이고 아래 「표로 고칠 수 없는 사유」 처럼 멈춘다. 고칠 번호를 보이고 `## 3.` · `## 4.`(표 고치기 · 승인)로 그 번호를 배정한 뒤 이 절의 명령을 돌린다.
- 사유가 `brief §5 위험 줄 가운데 K 번호가 없는 줄이 있다` 나 `brief §5 위험 줄의 K 번호가 겹친다` 면 표가 아니라 결과물 쪽 결함이다 — 결과물을 고치지 않고 `## 되돌아가는 길` 의 둘째 갈래로 간다.
- 표로 고칠 수 없는 사유(생성기가 만들지 않은 파일의 덮어쓰기 거부 · 못 읽는 파일 — 상태 파일 포함)면 사유를 그대로 보이고 멈춘다. 표로 돌아가 반복하지 않는다. 승인된 표는 상태 파일 `## 분해안` 절에 남아, 사유를 고친 뒤 다시 부르면 그 표에서 이어 갈 수 있다(커밋 펜스는 돌리지 않는다).
- rc 2 는 사용법 오류다(작업 트리 밖 경로 · `--audit` 짝 불일치 · 날짜 꼴). 사유를 보이고, 인자가 이 절의 명령과 글자 그대로인지 맞춘 뒤 한 번만 다시 돌린다. 또 rc 2 면 위의 고칠 수 없는 사유와 같이 멈춘다.

## 6. 커밋

생성이 rc 0 으로 끝난 뒤 한 번 돌린다. 펜스의 `<결과물 절대경로>` 자리표를 진입 단계 2 에서 푼 절대경로로 바꿔 돌리고, 나온 `[spec-distill]` 줄을 그대로 보인다. 넣는 것은 로드맵 폴더와 상태 파일(`## 분해안` · `## 생성 기록` 이 더해졌다) 둘이다 — 결과물 · audit 은 앞 단계가 커밋했고 이 커밋에 넣지 않는다. 커밋 펜스가 결과물 §7 의 `분해됨 — <로드맵 경로>` 줄에서 로드맵 폴더를 도출해 상태 파일과 한 커밋에 넣는다. 결과물이 레포 설정의 폴더(`interview_dir`) 바로 아래가 아니거나, 로드맵 폴더가 레포 설정의 로드맵 폴더(`roadmaps_dir`) 바로 아래가 아니거나(대소문자만 다른 경로 포함), 폴더가 아니거나, 작업 트리 밖이거나 링크를 거치거나, 커밋할 파일이 없거나, §7 의 파일이 `roadmap-check` 를 통과하지 못하면 커밋하지 않는다. 기본 브랜치는 `default-branch --check-remote` 로 얻는다 — 기본 브랜치를 판정하지 못하거나, 지금 기본 브랜치 위거나, 브랜치 위가 아니면(detached HEAD) 커밋하지 않고 손으로 커밋할 목록(로드맵 폴더 · 상태 파일)을 보인다.

<!-- roadmap-commit:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<결과물 절대경로>"
case "$BRIEF" in ""|*"<"*) echo "[spec-distill] 커밋 입력 부재 — BRIEF 가 비었거나 자리표 그대로다(결과물 절대경로로 바꿔 다시 돌려라)."; exit 0 ;; esac
# cwd 접두만 물리 경로로 바꾼다 — 그 아래 성분(링크 포함)은 path-inside 가 잰다.
cwd_l="$(pwd -L)"
case "$BRIEF" in "$cwd_l"/*) BRIEF="$(pwd -P)/${BRIEF#"$cwd_l"/}" ;; esac
stem="${BRIEF%.md}"
STATE_F="${stem}.state.md"
FILES="${STATE_F}"
top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
[ -n "$top" ] || { echo "[spec-distill] 커밋하지 않았다 — git 저장소가 아니다. 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
python3 "$SD/scripts/repo_defaults.py" check-path interview_dir "$BRIEF" --root "$top" || { echo "[spec-distill] 커밋하지 않았다 — 결과물이 정해진 폴더(interview_dir) 바로 아래가 아니다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
# 로드맵 폴더 — 결과물 §7 의 첫 `분해됨 — <로드맵 경로>` 줄.
r7="$(sed -n '/^## 7\./,${/^## 7\./d;/^## /q;s/^[[:space:]]*\(- \)\{0,1\}`\{0,1\}//;/^분해됨 — /{s/^분해됨 — //;s/`.*$//;s/[[:space:]]*$//;p;q;};}' "$BRIEF" 2>/dev/null)" || r7=""
[ -n "$r7" ] || { echo "[spec-distill] 커밋하지 않았다 — 결과물 §7 에 분해됨 줄이 없다. 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
case "$r7" in "$cwd_l"/*) r7="$(pwd -P)/${r7#"$cwd_l"/}" ;; esac
case "$r7" in /*) ;; *) r7="${top}/${r7}" ;; esac
RDIR="$(dirname -- "$r7")"
FILES="${RDIR} · ${STATE_F}"
python3 "$SD/scripts/repo_defaults.py" check-path roadmaps_dir "$RDIR" --root "$top" || { echo "[spec-distill] 커밋하지 않았다 — 결과물 §7 의 로드맵 폴더가 정해진 로드맵 폴더 바로 아래가 아니다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
[ -d "$RDIR" ] || { echo "[spec-distill] 커밋하지 않았다 — 결과물 §7 의 로드맵 폴더가 없거나 폴더가 아니다(${RDIR}). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
python3 "$SD/scripts/state_path.py" path-inside --root "$top" "$BRIEF" "$STATE_F" "$RDIR" || { echo "[spec-distill] 커밋하지 않았다 — 결과물 · 상태 파일 · 로드맵 폴더 중 작업 트리 밖이거나 링크를 거치는 경로가 있다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
# 커밋할 파일은 git 이 정한다(인덱스 + 무시되지 않은 새 파일).
[ -n "$(git -C "$top" ls-files --cached --others --exclude-standard -- "$RDIR")" ] || { echo "[spec-distill] 커밋하지 않았다 — 로드맵 폴더에 커밋할 파일이 없다(${RDIR}). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
python3 "$SD/scripts/repo_defaults.py" roadmap-check "$r7" --root "$top" || { echo "[spec-distill] 커밋하지 않았다 — 결과물 §7 의 로드맵이 로드맵 꼴이 아니다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
d_rc=0
def="$(python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote --root "$top")" || d_rc=$?
[ "$d_rc" -eq 0 ] && [ -n "$def" ] || { echo "[spec-distill] 커밋하지 않았다 — 기본 브랜치를 판정하지 못했다(위 사유). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
cur="$(git -C "$top" branch --show-current 2>/dev/null)" || cur=""
[ -n "$cur" ] || { echo "[spec-distill] 커밋하지 않았다 — 지금 브랜치 위가 아니다(detached HEAD). 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
[ "$cur" != "$def" ] || { echo "[spec-distill] 커밋하지 않았다 — 지금 기본 브랜치(${def})에 있다. 확인한 뒤 직접 커밋하라: ${FILES}"; exit 0; }
c_rc=0
git -C "$top" add -- "$RDIR" "$STATE_F" || c_rc=$?
[ "$c_rc" -ne 0 ] || git -C "$top" commit -q --only -m "docs(roadmap): $(basename -- "$RDIR") 로드맵 · 분해안" -- "$RDIR" "$STATE_F" || c_rc=$?
if [ "$c_rc" -ne 0 ]; then
  echo "[spec-distill] 커밋하지 않았다 — 커밋이 실패했다(rc ${c_rc}). 확인한 뒤 직접 커밋하라: ${FILES}"
else
  echo "[spec-distill] 로드맵 폴더 · 상태 파일을 커밋했다 — $(git -C "$top" rev-parse --short HEAD) (${cur})"
fi
```
<!-- roadmap-commit:end -->

## 7. PR 과 머지 · 지휘자 줄

**PR 과 머지 — 분해된 일 ①/② 만.** 지휘자는 로드맵을 기본 브랜치에서 읽는다 — 브랜치에만 있는 로드맵은 상태를 셀 수 없고, 에픽 worktree 도 기본 브랜치에서 갈라져 묶음 파일이 없다. 그래서 인터뷰가 커밋 뒤 PR 을 열고 머지를 묻는다. 커밋 펜스가 「brief · audit · 상태 파일 · 로드맵 폴더를 커밋했다」 줄을 냈을 때만 돈다 — 그 줄이 아니면(커밋하지 않음 · 실패 · 로드맵 폴더를 빼고 커밋) 이 절을 건너뛰고 두 줄 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다. ④ · B-1 은 PR 을 열지 않는다. 펜스는 모두 마지막 줄이 판결이고, 판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다 — 하나만 다르다: 머지 펜스의 출력에 판결 줄이 없고 `interview-merge-requested:` 표시 줄이 있으면 `NONE` 으로 읽지 않고 3 의 다시 확인 펜스를 돌려 그 판결대로 잇는다. 이 절의 펜스는 gh 를 직접 찾거나 부르지 않고 `gh_repo.py` 의 하위 명령으로만 부른다 — 그 모듈이 gh 를 찾고 origin 레포를 명시한다.

**「여기서 계속」 으로 왔으면.** 게이트의 기타 칸 갈래(정본 `proceed-gate.md` 의 「기타 칸」 — 두 줄 없이 이 세션에서 다음 세션 줄을 따른다)에서는 `interview-merge: MERGED` 를 받은 턴에만 지휘자를 부른다. `MERGED` 여도 출력에 「머지 뒤 origin 을 받지 못했다」 줄이 있으면 부르지 않는다 — 그 줄과 아래 지휘자 줄을 보이고 턴을 끝낸다(받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다). 그 밖(이 절을 건너뜀 · `interview-pr: NONE` · `interview-merge: NONE` · 「직접 머지」)에는 지휘자를 부르지 않는다 — PR 주소(있으면)와 아래 지휘자 줄을 보이고, 그 커밋이 기본 브랜치에 머지된 뒤 그 줄을 입력하라고 알린 뒤 턴을 끝낸다. 머지 전의 로드맵으로는 지휘자가 에픽을 세지 못한다.

1. **PR 열기.** 아래 펜스의 `BRIEF` 자리표를 Step A.5 의 PAYLOAD 절대경로로 바꿔 돌리고 나온 `[spec-distill]` 줄을(그 아래 파일 줄까지) 그대로 보인다. 펜스는 그 브랜치에서 기본 브랜치로 가는 이 레포 안 브랜치의 열린 PR 을 찾고, 브랜치를 push 한 뒤, 찾은 PR 이 있으면 그것을, 없으면 새 PR 을 연다. 이어서 그 PR 이 바꾸는 파일 가운데 인터뷰 폴더 바로 아래도 brief §7 의 로드맵 폴더도 아닌 것을 세어 `interview-pr-files:` 줄로 낸다 — `ONLY`(그런 파일이 없다) · `MIXED`(있다 — 목록을 보인다) · `UNKNOWN`(세지 못했다). 두 폴더는 커밋 펜스와 같은 판정(`check-path`)을 통과한 것만 빼고 센다 — 통과하지 못한 폴더의 파일은 밖의 파일로 센다. push 한 끝 커밋은 `interview-pr-head: <커밋>` 줄로 낸다 — 3 의 머지가 이 커밋에 묶인다. `interview-pr: OPEN <PR 주소>` 면 2 로, `interview-pr: NONE` 이면 두 줄 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.

<!-- interview-pr:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<Step A.5 의 PAYLOAD 절대경로>"
none() { echo "[spec-distill] PR 을 열지 않았다 — $1. 브랜치를 push 하고 PR 을 직접 열어 머지한 뒤 지휘자를 부른다."; echo "interview-pr: NONE"; exit 0; }
case "$BRIEF" in ""|*"<"*) none "BRIEF 가 비었거나 자리표 그대로다(Step A.5 의 PAYLOAD 절대경로로 바꿔 다시 돌려라)" ;; esac
cwd_l="$(pwd -L)"
case "$BRIEF" in "$cwd_l"/*) BRIEF="$(pwd -P)/${BRIEF#"$cwd_l"/}" ;; esac
top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
[ -n "$top" ] || none "git 저장소가 아니다"
cur="$(git -C "$top" branch --show-current 2>/dev/null)" || cur=""
def="$(python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote --root "$top")" || def=""
[ -n "$cur" ] && [ -n "$def" ] && [ "$cur" != "$def" ] || none "지금 브랜치(${cur:-없음})나 기본 브랜치(${def:-없음})를 가르지 못했다"
url="$(python3 "$SD/scripts/gh_repo.py" pr-open --head "$cur" --base "$def" --root "$top")" || none "열린 PR 을 찾지 못했다(위 사유)"
head_sha="$(git -C "$top" rev-parse --verify -q "refs/heads/${cur}^{commit}")" || head_sha=""
[ -n "$head_sha" ] || none "지금 브랜치의 끝 커밋을 읽지 못했다"
git -C "$top" push -q -u origin "$cur" || none "push 가 실패했다(위 사유)"
if [ -z "$url" ]; then
  bf="$(mktemp)" || none "PR 본문 임시 파일을 만들지 못했다"
  rel="${BRIEF#"$top"/}"
  case "$rel" in /*) rel="$(basename -- "$BRIEF")" ;; esac
  printf '## Summary\n- 인터뷰 brief · audit · 상태 파일과 로드맵 폴더를 올린다: `%s`\n- 머지되면 지휘자(`/spec-distill:epic-conductor`)가 이 로드맵을 기본 브랜치에서 읽어 에픽을 시작한다.\n' "$rel" > "$bf"
  url="$(python3 "$SD/scripts/gh_repo.py" pr-create --head "$cur" --base "$def" --title "$(git -C "$top" log -1 --format=%s)" --body-file "$bf" --root "$top")" || url=""
  rm -f "$bf"
  case "$url" in https://*/pull/[0-9]*) ;; *) none "PR 을 만들지 못했다(위 사유)" ;; esac
  echo "[spec-distill] PR 을 열었다 — $url"
else
  echo "[spec-distill] 이 브랜치의 열린 PR 을 쓴다 — $url"
fi
# 이 PR 이 바꾸는 파일 가운데 인터뷰 폴더 바로 아래도 brief §7 의 로드맵 폴더도 아닌 것. 두 폴더는 커밋 펜스와 같은 판정을 통과한 것만 뺀다.
# 끝내기 커밋 펜스가 같은 키로 이미 보인 「값의 출처」 줄만 뺀다 — 그 호출의 사유 · 알림 · 경고 줄과 종료 코드는 그대로다.
nosrc() {
  nf="$(mktemp)" || nf=""
  [ -n "$nf" ] || { "$@"; return; }
  n_rc=0
  "$@" 2> "$nf" || n_rc=$?
  grep -v '^\[spec-distill\] 값의 출처: ' "$nf" >&2
  rm -f "$nf"
  return "$n_rc"
}
idir=""
if nosrc python3 "$SD/scripts/repo_defaults.py" check-path interview_dir "$BRIEF" --root "$top"; then
  idir="$(dirname -- "$BRIEF")"
else
  echo "[spec-distill] brief 가 정해진 인터뷰 폴더 바로 아래가 아니다(위 사유) — 그 폴더의 파일도 밖의 파일로 센다."
fi
r7="$(awk -v p='분해됨 — ' 'index($0,"## 7.")==1{f=1;next} f&&/^## /{exit} f{l=$0; sub(/^[ \t]*(- )?`?/,"",l); if(index(l,p)==1){l=substr(l,length(p)+1); sub(/`.*$/,"",l); sub(/[ \t]+$/,"",l); print l; exit}}' "$BRIEF" 2>/dev/null)" || r7=""
rdir=""
if [ -n "$r7" ]; then
  case "$r7" in "$cwd_l"/*) r7="$(pwd -P)/${r7#"$cwd_l"/}" ;; esac
  case "$r7" in /*) ;; *) r7="${top}/${r7}" ;; esac
  rdir="$(dirname -- "$r7")"
  nosrc python3 "$SD/scripts/repo_defaults.py" check-path roadmaps_dir "$rdir" --root "$top" || { echo "[spec-distill] brief §7 의 로드맵 폴더가 정해진 로드맵 폴더 바로 아래가 아니다(위 사유) — 그 폴더의 파일도 밖의 파일로 센다: ${rdir}"; rdir=""; }
fi
x_rc=0
extra="$(git -C "$top" -c core.quotePath=false diff --name-only "refs/remotes/origin/${def}...${head_sha}" -- . ${idir:+":(exclude,glob)${idir}/*"} ${rdir:+":(exclude)${rdir}"})" || x_rc=$?
if [ "$x_rc" -ne 0 ]; then
  echo "[spec-distill] 이 PR 에 담긴 파일을 세지 못했다(위 사유) — 머지하기 전에 PR 에서 직접 확인한다."
  echo "interview-pr-files: UNKNOWN"
elif [ -z "$extra" ]; then
  echo "[spec-distill] 이 PR 은 인터뷰 폴더와 로드맵 폴더의 파일만 담는다."
  echo "interview-pr-files: ONLY"
else
  x_n="$(printf '%s\n' "$extra" | wc -l | tr -d ' ')"
  echo "[spec-distill] 이 PR 은 인터뷰 폴더 · 로드맵 폴더 밖의 파일 ${x_n}개도 담는다(스무 개까지 보인다):"
  printf '%s\n' "$extra" | head -n 20 | sed 's/^/  - /'
  echo "interview-pr-files: MIXED"
fi
echo "interview-pr-head: $head_sha"
echo "interview-pr: OPEN $url"
```
<!-- interview-pr:end -->

2. **머지 묻기.** `AskUserQuestion` 하나 — 질문 「<주제> — 지휘자는 로드맵을 기본 브랜치에서 읽어, 이 PR(<PR 주소>)이 머지돼야 에픽을 시작할 수 있다. 지금 머지할까?」, 선택지 「머지 (권장)」(얻음: CI 검사 뒤 PR 을 기본 브랜치에 합치고 붙여 넣을 두 줄을 바로 보인다 · 내줌: 합친 뒤에는 되돌리기 번거롭고 CI 를 기다리는 동안 턴이 끝난 채 멈춰 있다) · 「직접 머지」(얻음: 머지 시점과 방식을 내가 정한다 · 내줌: 머지한 뒤 지휘자 줄을 직접 입력해야 해서 한 단계가 사람 몫으로 남는다). 「(권장)」 꼬리는 1 의 펜스가 `interview-pr-files: ONLY` 를 냈을 때만 단다 — 그 두 폴더(인터뷰 폴더 바로 아래 · 로드맵 폴더)의 파일만 바꾸는 PR 이라 머지를 권한다. `MIXED` 나 `UNKNOWN` 이면 꼬리를 떼어 「머지」 로 내고, 질문 앞 글에 1 의 펜스가 보인 파일 목록(세지 못했으면 그 줄)을 다시 보인다 — 무엇이 함께 머지되는지 보고 고르게 한다. 답은 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다.
3. **머지.** 「머지」면 아래 펜스의 `BRIEF` 자리표를 1 과 같은 값으로, `URL` 자리표를 1 의 PR 주소로, `HEAD_SHA` 자리표를 1 의 `interview-pr-head:` 값으로 바꿔 Bash 도구의 백그라운드 실행으로 돌린다(CI 를 기다리는 동안 도구 시간 상한에 걸리지 않게 — 끝나면 알림이 온다). 띄운 턴에는 `[spec-distill] PR 머지를 기다린다 — CI 검사가 끝나면 머지하고 이어 간다(검사는 30분까지 기다린다): <PR 주소>` 한 줄을 보이고 턴을 끝낸다 — 두 줄은 아직 보이지 않는다. 알림이 온 턴에 출력의 `[spec-distill]` 줄을 그대로 보이고 판결대로 잇는다. 알림보다 먼저 사용자가 말을 걸면 그 턴에 백그라운드 출력을 읽어, 판결 줄이 있으면 판결대로 잇고 없으면 아직 기다리는 중이라고 답한다. 사용자가 그만두라고 하면 그 백그라운드 작업을 끝낸다(작업을 끝내면 펜스가 기다리던 gh 도 함께 끝나 머지로 가지 않는다) — 끝낸 출력에 판결 줄이 이미 있으면 그 판결대로 잇는다. 판결 줄이 없고 `interview-merge-requested:` 표시 줄이 있으면 머지 요청이 이미 나갔을 수 있다 — `NONE` 으로 읽지 않고 머지 펜스 아래의 다시 확인 펜스를 돌려 그 판결대로 잇는다. 표시 줄도 없으면 `interview-merge: NONE` 으로 읽어 잇는다. 이 기다림은 polite stop 이 아니다 — ①/② 의 완료 동작(두 줄과 위치를 노출하고 턴을 끝낸다)은 판결을 받은 턴에 한다. 펜스는 PR 주소의 레포가 origin 인지 대조하고, 그 PR 이 열려 있고 이 레포 안의 지금 브랜치에서 기본 브랜치로 가는 PR 이며 끝 커밋이 1 에서 push 한 커밋 그대로인지 먼저 확인한다. 그 PR 이 이미 머지돼 있으면(상태가 머지됨이고 이 레포 안의 지금 브랜치에서 기본 브랜치로 간 PR) 검사를 기다리지도 머지를 요청하지도 않고 머지됨으로 읽는다 — origin 을 받고 판결은 `MERGED` 다. 머지도 그 커밋에 묶어 요청한다 — 묻고 난 뒤(CI 를 기다리는 사이 포함) PR 에 다른 커밋이 올라오면 머지하지 않는다. 막 연 PR 은 CI 가 아직 붙지 않았을 수 있어 「검사 없음」을 1분 동안 다시 본 뒤에야 받아들이고, 검사가 있으면 끝나길 30분까지 기다린다 — 실패한 검사가 있거나 30분을 넘기면 머지하지 않는다. 머지 방식은 그 레포가 허용하는 것 가운데 merge commit → squash → rebase 순서로 시도하고, 하나가 거절되면(보호 규칙 등) 다음 것을 시도한다. 방식마다 요청을 보내기 직전에 표시 줄 `interview-merge-requested: <PR 번호>` 를 낸다. gh 의 머지 명령이 실패로 끝났어도 다시 읽은 PR 이 머지돼 있으면 다음 방식을 시도하지 않고 머지됨으로 읽는다. gh 가 머지를 받아들이면 PR 상태를 다시 읽는다 — 머지 대기열이나 자동 머지를 쓰는 레포에서는 gh 가 요청만 걸어 두고 성공으로 끝나므로, 상태가 `MERGED` 가 아니면 판결은 `NONE` 이다. `MERGED` 면 origin 을 받아 지휘자가 읽는 로컬의 기본 브랜치 ref 를 맞춘다 — 받지 못하면 그 사실을 알리고 판결은 `MERGED` 그대로다. 마지막 줄이 `interview-merge: MERGED` 면 두 줄을 그대로 노출하고(머지 안내 없이), `interview-merge: NONE` 이거나 「직접 머지」면 두 줄 앞에 PR 주소와 함께 지휘 세션을 이 PR 이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.

<!-- interview-merge:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<Step A.5 의 PAYLOAD 절대경로>"
URL="<interview-pr 이 낸 PR 주소>"
HEAD_SHA="<interview-pr 이 낸 끝 커밋>"
none() { echo "[spec-distill] 머지하지 않았다 — $1. 직접 머지한 뒤 지휘자를 부른다: ${URL}"; echo "interview-merge: NONE"; exit 0; }
merged() { git -C "$top" fetch -q origin || echo "[spec-distill] 머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다. 받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다."; echo "interview-merge: MERGED"; exit 0; }
case "$BRIEF" in ""|*"<"*) none "BRIEF 가 비었거나 자리표 그대로다" ;; esac
case "$URL" in https://*/pull/[0-9]*) ;; *) none "PR 주소가 비었거나 자리표 그대로다" ;; esac
case "$HEAD_SHA" in ""|*[!0-9a-f]*) none "끝 커밋이 비었거나 자리표 그대로다" ;; esac
top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
[ -n "$top" ] || none "git 저장소가 아니다"
cur="$(git -C "$top" branch --show-current 2>/dev/null)" || cur=""
def="$(python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote --root "$top")" || def=""
[ -n "$cur" ] && [ -n "$def" ] || none "지금 브랜치(${cur:-없음})나 기본 브랜치(${def:-없음})를 가르지 못했다"
num="$(python3 "$SD/scripts/gh_repo.py" pr-number "$URL" --root "$top")" || none "PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유)"
pr="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || none "PR 을 읽지 못했다(위 사유)"
# 이미 머지된 PR — 상태가 머지됨이고 바탕 · 브랜치가 같은 이 레포의 PR 이면 머지됨으로 읽는다(끝 커밋은 대조하지 않는다).
case "$pr" in "MERGED $def $cur false "*) echo "[spec-distill] PR 이 이미 머지돼 있다 — ${URL}"; merged ;; esac
[ "$pr" = "OPEN $def $cur false $HEAD_SHA" ] || none "이 PR 은 열린, 이 레포의 ${cur} → ${def} PR 이 아니거나 끝 커밋이 물을 때(${HEAD_SHA})와 다르다(읽은 것: ${pr})"
out="$(mktemp)" || none "검사 출력 임시 파일을 만들지 못했다"
n=0
while :; do
  ck_rc=0
  python3 "$SD/scripts/gh_repo.py" pr-checks "$num" --root "$top" > "$out" 2>&1 || ck_rc=$?
  grep -q "no checks reported" "$out" || break
  n=$((n + 1))
  [ "$n" -lt 6 ] || break
  sleep 10
done
if ! grep -q "no checks reported" "$out"; then
  python3 "$SD/scripts/gh_repo.py" pr-checks "$num" --watch --interval 15 --root "$top" > "$out" 2>&1 &
  w=$!
  n=0
  while kill -0 "$w" 2>/dev/null; do
    [ "$n" -lt 120 ] || { kill "$w" 2>/dev/null; rm -f "$out"; none "CI 검사를 30분 기다려도 끝나지 않았다"; }
    sleep 15
    n=$((n + 1))
  done
  ck_rc=0
  wait "$w" || ck_rc=$?
  [ "$ck_rc" -eq 0 ] || { tail -n 20 "$out"; rm -f "$out"; none "CI 검사가 통과하지 않았다(rc ${ck_rc}, 위 목록)"; }
fi
rm -f "$out"
ways="$(python3 "$SD/scripts/gh_repo.py" merge-ways --root "$top")" || ways=""
[ -n "$ways" ] || none "레포가 허용하는 머지 방식을 읽지 못했다(위 사유)"
how=""
for how in --merge --squash --rebase; do
  case " $ways " in *" $how "*) ;; *) continue ;; esac
  # 요청을 보내기 직전의 표시 줄 — 판결 줄 없이 끝난 출력에 이 줄이 있으면 다시 확인 펜스가 돈다.
  echo "interview-merge-requested: $num"
  if python3 "$SD/scripts/gh_repo.py" pr-merge "$num" "$how" --match-head-commit "$HEAD_SHA" --root "$top"; then
    # gh 가 받아들였어도 머지 대기열 · 자동 머지면 아직 머지 전이다 — 상태를 다시 읽는다(15초까지).
    st=""
    n=0
    while :; do
      st="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || st=""
      st="${st%% *}"
      n=$((n + 1))
      [ "$st" != "MERGED" ] && [ "$n" -lt 4 ] || break
      sleep 5
    done
    if [ "$st" != "MERGED" ]; then
      echo "[spec-distill] gh 는 머지 요청을 받았지만 PR 이 아직 머지되지 않았다(읽은 상태: ${st:-읽지 못함}) — 머지 대기열이나 자동 머지를 쓰는 레포면 조건이 채워진 뒤 머지된다. 머지된 것을 확인한 뒤 지휘자를 부른다: ${URL}"
      echo "interview-merge: NONE"
      exit 0
    fi
    echo "[spec-distill] PR 을 머지했다(${how#--}) — ${URL}"
    merged
  fi
  pr="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || pr=""
  case "$pr" in "MERGED $def $cur false "*) echo "[spec-distill] gh 의 머지 명령은 실패로 끝났지만(위 사유) PR 은 머지돼 있다 — ${URL}"; merged ;; esac
  [ "$pr" = "OPEN $def $cur false $HEAD_SHA" ] || none "머지가 거절됐고(위 사유) PR 이 물을 때와 달라졌다 — 끝 커밋이 바뀌었거나 닫혔다(읽은 것: ${pr:-읽지 못함} · 물을 때의 끝 커밋: ${HEAD_SHA})"
  echo "[spec-distill] ${how#--} 머지가 거절됐다(위 사유) — 다음 방식을 시도한다."
done
none "허용된 머지 방식이 모두 거절됐다(위 사유 — 충돌 · 보호 규칙 · 권한)"
```
<!-- interview-merge:end -->

**다시 확인 — 판결 줄 없이 끝난 머지 펜스의 출력에 `interview-merge-requested:` 표시 줄이 있을 때만.** 아래 펜스의 `BRIEF` · `URL` 자리표를 3 과 같은 값으로 바꿔 돌리고(백그라운드로 띄우지 않는다 — 기다림은 15초까지다) 나온 `[spec-distill]` 줄을 그대로 보인 뒤 그 판결대로 잇는다. 펜스는 읽기만 한다 — 머지를 요청하지도 CI 검사를 기다리지도 않는다. PR 주소의 레포가 origin 인지 대조하고, PR 상태를 머지 펜스의 머지 뒤 상태 읽기와 같은 간격 · 횟수(5초 간격 네 번까지)로 읽는다. 상태가 머지됨이고 이 레포 안의 지금 브랜치에서 기본 브랜치로 간 PR 이면 origin 을 받고 `interview-merge: MERGED`, 끝까지 아니면 머지 요청이 나갔다는 사실과 PR 주소를 알리고 `interview-merge: NONE` 이다 — PR 상태를 끝까지 읽지 못했을 때(gh 인증 · 네트워크)도 머지됨으로 읽지 않고, 읽지 못했다는 사실을 따로 알린다.

<!-- interview-merge-recheck:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<Step A.5 의 PAYLOAD 절대경로>"
URL="<interview-pr 이 낸 PR 주소>"
none() { echo "[spec-distill] 머지됐는지 다시 확인하지 못했다 — $1. 머지 요청은 나갔을 수 있다 — PR 에서 머지된 것을 확인한 뒤 지휘자를 부른다: ${URL}"; echo "interview-merge: NONE"; exit 0; }
case "$BRIEF" in ""|*"<"*) none "BRIEF 가 비었거나 자리표 그대로다" ;; esac
case "$URL" in https://*/pull/[0-9]*) ;; *) none "PR 주소가 비었거나 자리표 그대로다" ;; esac
top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
[ -n "$top" ] || none "git 저장소가 아니다"
cur="$(git -C "$top" branch --show-current 2>/dev/null)" || cur=""
def="$(python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote --root "$top")" || def=""
[ -n "$cur" ] && [ -n "$def" ] || none "지금 브랜치(${cur:-없음})나 기본 브랜치(${def:-없음})를 가르지 못했다"
num="$(python3 "$SD/scripts/gh_repo.py" pr-number "$URL" --root "$top")" || none "PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유)"
# 요청 직후에는 아직 열림으로 보일 수 있다 — 머지 펜스의 머지 뒤 상태 읽기와 같은 간격 · 횟수로 읽는다(15초까지).
pr=""
n=0
while :; do
  pr="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || pr=""
  n=$((n + 1))
  case "$pr" in "MERGED $def $cur false "*) break ;; esac
  [ "$n" -lt 4 ] || break
  sleep 5
done
case "$pr" in
  "MERGED $def $cur false "*)
    echo "[spec-distill] 다시 확인하니 PR 이 머지돼 있다 — ${URL}"
    git -C "$top" fetch -q origin || echo "[spec-distill] 머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다. 받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다."
    echo "interview-merge: MERGED" ;;
  "MERGED "*)
    echo "[spec-distill] 머지 요청은 나갔지만 읽은 PR 이 이 레포의 ${cur} → ${def} PR 이 아니다(읽은 것: ${pr}) — PR 에서 직접 확인한 뒤 지휘자를 부른다: ${URL}"
    echo "interview-merge: NONE" ;;
  "")
    echo "[spec-distill] 머지 요청은 나갔지만 PR 상태를 읽지 못했다(위 사유) — 머지됐는지 확인한 뒤 지휘자를 부른다: ${URL}"
    echo "interview-merge: NONE" ;;
  *)
    st="${pr%% *}"
    echo "[spec-distill] 머지 요청은 나갔지만 PR 이 아직 머지되지 않았다(읽은 상태: ${st}) — 머지 대기열이나 자동 머지를 쓰는 레포면 조건이 채워진 뒤 머지된다. 머지된 것을 확인한 뒤 지휘자를 부른다: ${URL}"
    echo "interview-merge: NONE" ;;
esac
```
<!-- interview-merge-recheck:end -->

**다음 세션 줄 — 분해된 일 ①/② 공통**

`/spec-distill:epic-conductor <roadmap-path>`

분해된 일이면 ①/② 의 둘째 줄은 위 brief 줄 대신 이 줄이다 — 지휘자가 이 세션에서 로드맵의 에픽들을 끝까지 이끈다. `<roadmap-path>` 는 로드맵의 절대경로로 치환한다 — 치환하지 못하거나 경로에 공백이 있으면 줄을 노출하지 않고 `[spec-distill] 다음 세션 줄을 만들 수 없다 — <사유>. /spec-distill:epic-conductor 를 인자 없이 부르면 로드맵을 찾는다.` 한 줄을 보인 뒤 멈춘다. 나누지 않은 일의 둘째 줄은 위 brief 줄 그대로다.

## 되돌아가는 길

결과물은 앞 단계만 고친다 — 이 단계가 결과물에서 손대는 것은 「spec 하나로」 를 골랐을 때 §7 의 `분해됨` 줄을 지우는 것 하나뿐이다.

- **「spec 하나로」 를 고르면**(`## 4.` 의 두 질문, 또는 아래 둘째 갈래에서 사용자가 그 길을 말하면) 차례로 간다.
  1. 생성이 이미 성공했으면(상태 파일에 `## 생성 기록` 이 있다) `## 생성 기록` 에 적힌 파일을 지운다 — 기록 밖의 파일은 건드리지 않는다.
  2. 결과물 §7 의 `분해됨 — <로드맵 경로>` 줄을 지운다. 로드맵을 이미 커밋한 뒤(기본 브랜치에 머지되기 전)에 다시 불러 취소하는 것이면 상태 파일의 두 절(`## 분해안` · `## 생성 기록`)도 비운다.
  3. 구조 게이트를 다시 돌린다. 통과하지 않으면 사유를 보이고 멈춘다 — 결과물을 더 고치지 않는다.

     ```bash
     SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
     python3 "$SD/scripts/check_brief.py" gate "<결과물 절대경로>"
     ```

  4. 한 커밋에 넣는다 — 결과물과, 바뀌었으면 상태 파일과 지운 파일(커밋돼 있던 것). 로드맵을 커밋한 뒤의 취소면 생성 기록의 파일 지우기 · 상태 파일의 두 절 비우기 · `분해됨` 줄 지우기를 한 커밋에 넣는다. 제목은 `docs(roadmap): <로드맵 폴더 이름> 나누지 않기로` 다. 경로를 정해 `git add -- <경로들>` 과 `git commit -q --only -m "<제목>" -- <같은 경로들>` 로 커밋한다 — 이미 stage 된 다른 파일을 끌어들이지 않는다. 지금 기본 브랜치 위거나 detached HEAD 면 커밋하지 않고 「커밋하지 않았다 — <사유>. 확인한 뒤 직접 커밋하라: <경로들>」 을 보인다.
  5. 나누지 않은 일의 다음 세션 줄을 낸다 — 컨텍스트 쌓기가 나누지 않은 일에 내는 줄과 같은 글이다:

     > `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. 시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## brainstorming 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.`

     `@<brief-path>` 는 결과물 절대경로로, 줄 안의 `${CLAUDE_PLUGIN_ROOT}` 는 이 플러그인의 절대경로로 바꿔 보인다. 바꾸지 못한 자리표가 남거나 경로에 공백이 있으면 그 줄을 보이지 않고 사유와 결과물 경로를 보인 뒤 멈춘다. 새 세션(`/compact` 또는 `/new` 뒤)에서 그 줄을 입력하라고 알리고 턴을 끝낸다 — 같은 턴에서 brainstorming 을 부르지 않는다.
- **결과물에서 모자란 것을 보거나**(조사가 더 필요하다 등) **생성기가 결과물 쪽 결함으로 실패하면**(진입 검사의 위험 줄 번호 멈춤 · `## 3.` 의 `brief-risk: FAIL` · `## 5.` 의 위험 줄 사유 — 커밋 전 검사를 거치지 않은 옛 결과물 등): 결과물을 고치지 않고 그 사실을 보이고 멈춘다. 끝난 컨텍스트 쌓기는 다시 이을 수 없다. 사용자가 고를 길은 둘이다 — 「spec 하나로」 · 그 결과물을 입력으로 새 `/spec-distill:context-build` 를 시작한다(`/spec-distill:context-build @<결과물 절대경로>`). 사용자가 「spec 하나로」 를 말하면 위 첫 갈래로 간다.
