---
name: epic-conductor
description: >
  사용자가 `/spec-distill:epic-conductor [<로드맵 경로>]` 로 부른다. 승인된 로드맵의 에픽들을 이 세션이 끝까지 지휘한다 —
  다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇고, 사람 몫(설계 · spec 승인 · 계획의 설계에 없던 결정)은
  이 세션에서 한 번에 한 에픽씩 배경과 함께 묻고, 계획 · 구현은 따로 띄운 담당자 세션(herdr-core 가 없으면 하위 agent)으로, 머지 전 확인은 하위 agent 와 스크립트로 병렬로 끝까지 간다.
metadata:
  cost_class: high
argument-hint: "[<로드맵 경로>]"
allowed-tools:
  - Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill epic-conductor)
---

# epic-conductor — 로드맵 지휘

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

지휘의 걸음은 차례(`${CLAUDE_PLUGIN_ROOT}/references/conducting.md`)와 그 걸음 지시서가 담는다 — 이 본문은 진입 · 규모 공시 · 차례 · 통합 리뷰어와 옮김 대조의 dispatch 자리만 둔다.

!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill epic-conductor`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽고 아래 순서대로 간다. 감시줄 아래에 `[devbrew-switch]` 로 시작하는 줄이 있으면 감시줄이 무엇이든 그 줄들을 고치지 않고 사용자에게 보인다.

### 1. 감시줄 판독

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 1.5 로 간다. 그 줄의 `root=` 값을 아래에서 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고, spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼져 있어 지휘하지 않는다고 알린다 — 지휘자 없이 진행하려면 스위치를 풀고 지휘자를 부르지 않은 채 이 플러그인 references 폴더의 손 절차 파일(`conducting-manual.md`)을 따르라고 한 줄로 알린 뒤 멈춘다 |
| `[devbrew-entry] error …` | `[spec-distill] epic-conductor 사전 검사 실패 — <reason= 값>. 지휘하지 않는다.` 를 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[spec-distill] epic-conductor 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다. 지휘하지 않는다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[spec-distill] epic-conductor 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 지휘하지 않는다.` 를 내고 멈춘다 |

이 표가 보는 kill switch 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 하나다.

### 1.5 의존 확인

아래 펜스를 Bash 로 한 번 돌린다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
python3 "$SD/scripts/check_deps.py" entry --plugin-root "$SD" --need python,git,gh
```

| 결과 | 동작 |
|---|---|
| rc 0 (`[devbrew-deps] ok …`) | 아래 superpowers 확인을 한 뒤 2 로 간다 |
| rc 3 (`[devbrew-deps] 멈춤 …`) | 펜스 출력을 그대로 보이고 멈춘다. 지휘하지 않는다 |
| 그 밖 | `[spec-distill] epic-conductor 의존 확인 실패 — 필요한 프로그램의 판을 확인하지 못했다(rc <값>). 지휘하지 않는다.` 와 펜스 출력을 내고 멈춘다 |

superpowers 확인 — skill 목록에 `superpowers:` 로 시작하는 skill 이 하나도 없으면 `[spec-distill] epic-conductor 멈춤 — superpowers 가 필요하다 — Claude Code 의 /plugin 에서 superpowers 를 설치한 뒤 다시 부른다` 를 내고 멈춘다. 지휘하지 않는다.

### 2. 로드맵 정하기

받은 인자(`$ARGUMENTS`)를 본다. 토큰이 하나면 로드맵 경로다 — 앞의 `@` 하나는 뗀다(첨부 꼴로 받은 경우). 뗀 뒤 영문자 · 숫자 · `.` `_` `/` `@` `+` `-` 로만 되어 있고 `-` 로 시작하지 않아야 한다(아니면 셸에 넘기지 않고 `[spec-distill] epic-conductor 인자는 로드맵 경로 하나다 — 받은 것: <인자>.` 를 내고 멈춘다). 절대경로면 아래 펜스의 `git worktree list --porcelain` 이 낸 worktree 루트들 가운데 그 경로를 품는 worktree(가장 깊은 것)를 찾아 그 루트 기준 상대경로로 바꿔 쓴다 — 로드맵의 레포 상대경로는 어느 worktree 에서나 같다(메인 체크아웃 · 에픽 worktree 모두). 어느 worktree 아래도 아니면 `[spec-distill] epic-conductor 로드맵이 이 레포의 어느 worktree 안에도 없다 — 받은 것: <인자>.` 를 내고 멈춘다.

```bash
cd "<root>" && git worktree list --porcelain | sed -n 's/^worktree //p'
```

비었으면 아래 펜스로 찾는다(`<root>` 는 감시줄 `root=` 값).

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" roadmaps
```

줄마다 `<경로><탭><끝나지 않은 에픽 수>` 다 — 둘째 칸이 `검사 불가 — <사유>` 인 줄은 셀 수 없었던 로드맵이니 그 사유를 함께 보인다. 하나면 그것, 여럿이면 `AskUserQuestion` 으로 고르게 한다(추천을 달지 않는다 — 어느 로드맵을 지휘할지는 사용자가 고른다). 종료 코드 2(없음)면 그 줄을 보이고 멈추고, 3 이면 사유를 보이고 멈춘다.

### 3. 맞추기 명령

아래 펜스를 Bash 로 한 번 돌린다(`<root>` 는 감시줄 `root=` 값, `<로드맵>` 은 2 에서 정한 경로). 이 명령이 자리 · 원격 받기 · 작업 목록 · 표지 · 기본 브랜치 · PR 캐시 · 상태 브랜치 · 세션 담당자 · 스위트 잠금 · 실행 원장을 차례로 돌고, 세션 번호는 스스로 읽는다. 이상이 없는 구간은 한 줄이고 이상이 있는 구간은 그 원문이 따른다 — 출력은 고치지 않고 그대로 보인다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/conductor_sync.py" --roadmap "<로드맵>"
```

종료 코드마다 이렇게 한다.

- `0` 이면 4 로 간다.
- `2` 이면 인자 오류다 — 출력을 그대로 보이고 멈춘다.
- `3` 이고 출력에 `옛 판이 쓴 PR 캐시 줄` 이 있으면 멈추지 않고 아래 「옛 PR 캐시 다시 채우기」 로 간다(`--takeover` 를 붙여 돌린 출력에 그 문구가 있어도 같다).
- `3` 이고 그 문구가 없으면(세션 번호를 얻지 못했다 · 기계 상태를 읽지 못했다 등) 출력을 그대로 보이고 멈춘다.
- `5` 면 다른 세션이 지휘 중이다 — 이 세션은 읽기 전용이다. 지도(출력의 작업 목록 · 끝나지 않은 일)를 보이고, 넘겨받을지 `AskUserQuestion` 으로 묻는다(「읽기만 (권장)」 · 「넘겨받기 — 그 세션은 쓰기를 멈춘다」). 설명은 이렇게 쓴다 — 「읽기만」: 얻음: 지휘 중인 다른 세션을 건드리지 않고 지도만 본다 · 내줌: 이 세션은 쓰지 못해 에픽을 보내거나 기록할 수 없다 / 「넘겨받기」: 얻음: 이 세션이 지휘를 이어받아 에픽을 보내고 기록한다 · 내줌: 그 세션의 쓰기가 끊겨 하던 에픽이 어중간하게 남을 수 있다. 넘겨받기면 같은 펜스에 `--takeover` 를 붙여 돌리고 그 종료 코드를 이 표대로 읽는다. 읽기만이면 멈춘다.
- 그 밖 모두(기본 브랜치 확인 실패는 명령이 잡은 표지를 풀고 그 종료 코드로 끝난다)는 그 줄(`멈춤 — <구간>: <사유>`, 없으면 종료 코드)과 출력을 그대로 보이고 멈춘다.

옛 PR 캐시 다시 채우기 — 그 출력이 이름 붙인 `pr-refresh … --reset` 을 이 로드맵으로 돌리고, 0 이면 표지를 푼다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" pr-refresh --roadmap "<로드맵>" --reset; reset_rc=$?
echo "reset_rc=$reset_rc"
if [ "$reset_rc" = 0 ]; then cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" release --roadmap "<로드맵>"; fi
```

- `reset_rc=` 가 0 이 아니면 그 사유(`[spec-distill] …`, 없으면 종료 코드)를 보이고 멈춘다.
- `reset_rc=` 가 0 이면 위 맞추기 명령을 처음부터 다시 돈다 — 5 면 그 사이 다른 세션이 표지를 잡았다 — 위 5 와 같이 한다.

### 4. 규모 공시

맞추기 명령이 낸 `규모 —` 줄은 고치거나 풀어 쓰지 않고 그대로 보인다. 그 줄의 꼴은 `남은 에픽 <n>(<번호 목록>) · agent 약 <n> · 순서 <번호 → 번호 …> · spec 리뷰는 라운드마다 리뷰어 agent 둘 이상, 엔진의 재리뷰 상한까지(사용자가 더 열 수 있다) · 구현 안 agent 수는 task 수에 따라 — 상한 없음` 이다. agent 수는 에픽마다 계획 1 · 구현 1(실행 방식 안의 agent 는 task 수에 따라 더) · 통합 리뷰 1 이상 · qg 담당자(spec 승인 앞 1 · 에픽 PR 마다 머지 앞 1 · 좁은 재리뷰 PR 마다 기본 2 — 사용자가 더 열 수 있다)에, 로드맵 끝 qg 담당자 1 과, 이 세션의 spec 리뷰가 라운드마다 부르는 리뷰어 agent(탐지 · 재비판 둘 이상, 라운드 상한까지)를 더한 대략이다.

규모 줄을 보이고 5 로 간다 — 지출 승인을 묻지 않는다. 그 뒤의 dispatch 도 띄우기 전에 규모만 알리고 간다.

### 5. 지휘 순환

```
Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md
```

차례와 지시서의 `<SD>` 는 위 `Read` 줄의 플러그인 폴더(이 skill 이 쓰는 spec-distill 의 절대경로)다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.

차례의 걸음 표대로 돈다 — 걸음에 들어설 때 그 걸음의 지시서를 읽는다. 보내는 글 틀 · 상태 브랜치 절차는 차례의 함께 읽는 것 칸의 때에 읽는다. 손 절차 파일은 지휘자를 부르지 않고 진행할 때의 것이다 — 이 skill 안에서는 따르지 않는다.

### 6. 통합 리뷰어

걸음 5 의 통합 리뷰는 아래 자리에서 부른다. `REVIEW_REQUEST` 는 `superpowers:requesting-code-review` 의 리뷰 요청 틀(`code-reviewer.md`)을 이 PR 로 채운 글, `MERGED_COPY` 는 `merge_check.py --keep-merged` 가 남긴 합친 사본, 나머지 넷은 `conductor_ledger.py review-pack` 이 만든 폴더의 파일 경로다. 그 skill 이 스스로 부르는 agent 는 쓰기 도구를 가져 쓰지 않는다 — 틀에서는 무엇을 · 왜 · 범위 칸만 빌려 채운다. 버전 관리 도구를 돌리라는 말과 틀의 출력 형식은 넣지 않는다: 리뷰어는 diff 를 그 도구가 아니라 `PR_DIFF` · `OPEN_DIFFS` 파일과 합친 사본에서 읽고, 내는 형식은 agent 의 `## 내는 것` 이다. 모델 칸은 해결자 `repo_defaults.py get review_model --roadmap <로드맵>` 의 값이 이 dispatch 의 모델 칸이 받는 이름일 때만 그 값을 준다. 종료 코드 1(값 없음)이거나 받는 이름이 아니면 모델 칸을 빼 세션 모델로 가며 그 사실을 알리고, 3(설정을 읽지 못함)이면 그 사유 줄을 보이고 모델 칸을 빼 세션 모델로 가며 그 사실을 알린다. 이음매가 여럿이면 여럿을 동시에 부른다. 통합 리뷰 지적 전부를 「이 PR 이 고침」 · 「뒤 에픽이 고침」으로 나눠 PR 본문 인계 절과 사용자에게 보인다.

```
Agent(
  description: "Integration review of epic seams",
  subagent_type: "spec-distill:integration-reviewer",
  // **처분** — consumer=orchestrator · fail-closed · disclosure=통합 리뷰 지적 전부를 「이 PR 이 고침」 · 「뒤 에픽이 고침」으로 나눠 PR 본문 인계 절과 사용자에게 보인다
  model: "<review_model — 받는 이름일 때만>",
  prompt: "<review_request>${REVIEW_REQUEST}</review_request>
    <merged_copy>${MERGED_COPY}</merged_copy>
    <pr_diff>${PR_DIFF}</pr_diff>
    <open_diffs>${OPEN_DIFFS}</open_diffs>
    <handoffs>${HANDOFFS}</handoffs>
    <intents>${INTENTS}</intents>"
)
```

### 7. 옮김 대조

하위가 돌려보낸 사람 자리를 옮긴 에픽이 끝나면(걸음 6) 아래 자리에서 옮김 대조 agent 를 부른다. `RELAY_FILES` 는 그 에픽의 relay 폴더(`conductor_ledger.py resource-dir --roadmap <로드맵> --kind relay --name <에픽>` 이 내는 경로) 안 `relay-*.md` 파일들(계획 agent 의 입력 줄 · 받은 질문 원문 같은 다른 파일은 옮긴 기록이 아니다)의 절대경로를 한 줄에 하나씩 적은 글이다. 그런 파일이 없으면 부르지 않고 「옮긴 질문 없음」 한 줄을 그 에픽 이름과 함께 보인다. 로드맵 끝(걸음 7)에는 로드맵 리뷰 담당자의 relay 폴더(`conductor_ledger.py resource-dir --roadmap <로드맵> --kind relay --name roadmap`)로 같은 자리를 한 번 부르고, 에픽 이름 대신 「로드맵」 을 쓴다. 모델 칸은 6 과 같다 — 해결자 `repo_defaults.py get review_model --roadmap <로드맵>` 의 값이 받는 이름일 때만 그 값을 준다. 종료 코드 1(값 없음)이거나 받는 이름이 아니면 빼서 세션 모델로 가며 그 사실을 알리고, 3(설정을 읽지 못함)이면 그 사유 줄을 보이고 빼서 세션 모델로 가며 그 사실을 알린다. 옮김 대조 결과 전부(일치 · 어긋남 · 확인 못 함)를 그 에픽 이름과 함께 사용자에게 보인다 — 어긋남이 있으면 그 자리를 그 에픽 설계문서 `## 지휘 기록` 에 적는다.

```
Agent(
  description: "Check relayed questions against originals",
  subagent_type: "spec-distill:relay-checker",
  // **처분** — consumer=orchestrator · fail-closed · disclosure=옮김 대조 결과 전부(일치 · 어긋남 · 확인 못 함)를 그 에픽 이름과 함께 사용자에게 보인다
  model: "<review_model — 받는 이름일 때만>",
  prompt: "<relay_files>${RELAY_FILES}</relay_files>"
)
```

## 보이기

사람에게 쓰는 글은 위 쉬운 말 규칙을 따른다. 지휘자가 정할 질문(흐름 승인 · 감사 · 계획 검토 · 옮긴 질문 · spec 승인)은 `AskUserQuestion` 으로 묻고 질문 문장 앞머리에 에픽 이름을 쓴다(따로 된 첫 줄로 쓰지 않는다). brainstorming 대화는 brainstorming 이 정한 메시지 모양(첫 메시지 · 열린 문장 질문 하나 · 되비춤)을 따른다 — 위 규칙의 순서(첫 줄 상태 · 끝 할 일)를 붙이지 않고 낱말 규칙만 지키며, 지휘 소식(상태 · 목록 · 다른 에픽 소식)은 그 메시지에 얹지 않고 따로 된 메시지로 보인다. 사람에게 보이는 글에서 하위 agent 는 단계대로 「계획 담당자」 · 「구현 담당자」 라고 부른다. 하위가 돌려보낸 사람 자리는 `conductor-dispatch.md` 의 `## 사람 자리` 대로 배경을 먼저 쉬운 말로 쓴 뒤 선택지를 원문 그대로(꼬리를 더하는 길은 그 절의 둘뿐) 묻는다. 진행 상황 · 돌고 있는 일의 수를 말할 때는 `conducting.md` 걸음 1 의 맞추기 순서대로 같은 턴에 원천(하니스 agent 목록 · 상태 계산 · 실행 원장)을 다시 조회하고 「HH:MM 기준」 을 붙인다 — 조회하지 않은 숫자는 말하지 않는다. hc 로 띄운 담당자 세션이 있으면 `hc ls` 의 내 자식도 원천으로 함께 센다. qg 담당자가 돌려준 리뷰 결과와 의도 점검 질문은 `references/qg-review.md` 의 `### 결과 글` · `## 묻기` 틀대로 맥락 머리로 시작하는 글로 보인 뒤 묻고, 질문 문장 앞머리에 에픽 이름(로드맵 리뷰면 「로드맵」)을 쓴다. team 형식 로드맵에서 사람 줄이 될 질문은 `ledger ask-head` 의 머리로 시작한다 — 절차는 지휘 절차의 `## team 형식 로드맵` 절이다.
