---
name: epic-conductor
description: >
  사용자가 `/spec-distill:epic-conductor [<로드맵 경로>]` 로 부른다. 승인된 로드맵의 에픽들을 이 세션이 끝까지 지휘한다 —
  다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇고, 사람 몫(설계 · spec 승인 · 계획의 설계에 없던 결정)은
  이 세션에서 한 번에 한 에픽씩 배경과 함께 묻고, 계획 · 구현 · 머지 전 확인은 하위 agent 와 스크립트로 병렬로 끝까지 간다.
cost_class: high
argument-hint: "[<로드맵 경로>]"
allowed-tools:
  - Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill epic-conductor)
---

# epic-conductor — 로드맵 지휘

<!-- plain-language:begin -->
## 사람에게 쓰는 글
이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. 지시문·subagent 프롬프트·state 파일에는 적용하지 않는다. 아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다. 부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고, 이 블록은 낱말에만 적용한다.
- 처음 보는 사람이 한 번에 이해하게 쓴다. 번호·해시·필드 이름·내부 용어는 가리키는 내용을 문장으로 먼저 쓰고 괄호 안에만 둔다. 지어낸 말은 쓰지 않거나 처음 쓸 때 풀어 쓴다.
- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일 하나. 할 일이 없으면 없다고 쓴다.
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천은 「(권장)」으로 표시한다.
- 제목과 목록으로 나누되 표의 칸은 짧게 쓴다. 굵은 글씨는 꼭 필요한 곳에만 쓴다.
- 사용자가 알 필요 없는 글은 쓰지 않는다: 도구 호출 사이의 진행 설명, 전부 정상인 항목의 나열. 확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.
- 판정·개수·공시 줄은 스크립트가 낸 쉬운 첫 줄을 그대로 쓰고, 자기 말로 다시 풀거나 덧붙이지 않는다. 스크립트·subagent 가 낸 원문은 고치지 않는다. 스크립트가 풀어 두지 않은 오류에만 쉬운 설명을 앞에 붙이되 통과·실패는 말하지 않는다.
- 사용자와 대화하는 언어로 쓴다. 코드·명령·고유명사·자연스러운 대응어가 없는 기술어는 영어 그대로 둔다. 커밋·PR은 그 레포의 규칙을 따르고, 없으면 대화 언어로 쓴다.
예) 전: `[미적용 fix] 3720b2b7#r1.1` → 후: 리뷰가 고치라고 한 곳 하나가 아직 안 고쳐졌다(3720b2b7#r1.1).
예) 전: (codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건) → 후: 이상 없음.
<!-- plain-language:end -->

지휘의 걸음은 두 reference 가 담는다 — 이 본문은 진입 · 시작 승인 · 차례 · 통합 리뷰어와 옮김 대조의 dispatch 자리만 둔다.

!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill epic-conductor`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽고 아래 순서대로 간다.

### 1. 감시줄 판독

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 2 로 간다. 그 줄의 `root=` 값을 아래에서 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고, spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼져 있어 지휘하지 않는다고 알린다 — 지휘자 없이 진행하려면 스위치를 풀고 지휘자를 부르지 않은 채 이 플러그인 references 폴더의 지휘 절차 파일(conducting.md) 끝 절인 손으로 따르는 절차를 따르라고 한 줄로 알린 뒤 멈춘다 |
| `[devbrew-entry] error …` | `[spec-distill] epic-conductor 사전 검사 실패 — <reason= 값>. 지휘하지 않는다.` 를 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[spec-distill] epic-conductor 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다. 지휘하지 않는다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[spec-distill] epic-conductor 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 지휘하지 않는다.` 를 내고 멈춘다 |

이 표가 보는 kill switch 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 하나다.

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

줄마다 `<경로><탭><끝나지 않은 에픽 수>` 다. 하나면 그것, 여럿이면 `AskUserQuestion` 으로 고르게 한다. 종료 코드 2(없음)면 그 줄을 보이고 멈추고, 3 이면 사유를 보이고 멈춘다.

### 3. 자리 · 세션 · 표지

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
cd "<root>" && echo "toplevel=$(git rev-parse --show-toplevel)" && git worktree list --porcelain | head -1
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""
claim_rc=
if [ -n "$sid" ]; then cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" claim --roadmap "<로드맵>" --session "$sid"; claim_rc=$?; fi
echo "session=${sid:-없음}"
echo "claim_rc=${claim_rc:-없음}"
cd "<root>" && python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote; echo "default_rc=$?"
```

Bash 도구는 호출마다 새 셸이다 — 아래 모든 펜스는 첫 줄(플러그인 루트 가드)과 세션 id 줄을 자기 안에 갖고, 한 번의 Bash 호출로 돌린다. 앞 펜스의 셸 변수를 이어 쓰지 않는다.

- `toplevel=` 이 첫 worktree 줄(메인 체크아웃)과 다르면 「이 세션은 worktree 안에서 시작했다(<경로>) — 여기서도 지휘한다. 에픽 worktree 로는 하니스의 worktree 옮겨 가기로 오간다」 를 한 줄로 알린다. 새 세션을 열라고 하지 않는다.
- `session=없음` 이면 표지를 잡을 수 없다 — 「세션 id 를 얻지 못해 기계 상태를 쓸 수 없다 — 읽기 전용으로 지도만 보인다」 를 알리고 `control_plane.py show <로드맵>` 을 보인 뒤 멈춘다.
- `default_rc=` 가 0 이 아니면(3 기본 브랜치 없음 · 5 원격과 다름 · 그 밖 모두) 그 줄(`[spec-distill] …`, 없으면 종료 코드)을 보이고, `claim_rc=0` 이면 4 끝의 표지 풀기 펜스(`conductor_ledger.py" release`)를 돌린 뒤 멈춘다. rc 0 의 「대조하지 못했다」 줄은 보이고 간다.
- `claim_rc=` 가 0 이면 4 로 간다. 5 면 다른 세션이 지휘 중이다 — 이 세션은 읽기 전용이다. 지도를 보이고, 넘겨받을지 `AskUserQuestion` 으로 묻는다(「읽기만 (권장)」 · 「넘겨받기 — 그 세션은 쓰기를 멈춘다」). 넘겨받기면 아래 펜스를 돌린 뒤 4 로 간다. 0 · 5 가 아닌 값(3 기계 상태 읽기 불가 포함)이면 그 사유를 보이고 멈춘다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""; [ -n "$sid" ] || { echo "[spec-distill] 세션 id 를 얻지 못했다 — 기계 상태를 쓰지 않고 멈춘다" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" takeover --roadmap "<로드맵>" --session "$sid"
```

### 4. 시작 승인

아래 펜스로 남은 에픽과 의존 순서를 읽는다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/control_plane.py" show "<로드맵>"
```

그 출력으로 규모 줄 하나를 만든다 — `남은 에픽 <n>(<번호 목록>) · agent 약 <n> · 순서 <번호 → 번호 …>`. agent 수는 에픽마다 계획 1 · 구현 1(실행 방식 안의 agent 는 task 수에 따라 더) · 통합 리뷰 1 이상에, 이 세션의 spec 리뷰가 라운드마다 부르는 리뷰어 agent(탐지 · 재비판 둘 이상, 라운드 상한까지)를 더한 대략이다. 같은 상태에서는 같은 줄이 나오게 이 꼴 그대로 쓴다.

규모 줄을 보이고 아래 펜스로 승인 상태를 본다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""; [ -n "$sid" ] || { echo "[spec-distill] 세션 id 를 얻지 못했다 — 기계 상태를 쓰지 않고 멈춘다" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" approval --roadmap "<로드맵>" --session "$sid" --scale "<규모 줄>"
```

- 종료 코드 0(「공시만 — …」): 그 줄을 보이고 5 로 간다.
- 종료 코드 0 이 아니면(1 「승인 필요」 · 3 기계 상태 읽기 불가 포함, 그 밖 모두) 공시만으로 넘어가지 않고 `AskUserQuestion` 으로 묻는다 — 「이 규모로 지휘 시작 (권장)」 · 「멈춤」. 3 이면 기계 상태를 읽지 못했다는 사유를 질문에 함께 보인다. 시작이면 아래 펜스를 돌리고, 종료 코드가 0 이 아니면 그 사유를 보이고 멈춘다(5 로 가지 않는다). 0 이면 5 로 간다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""; [ -n "$sid" ] || { echo "[spec-distill] 세션 id 를 얻지 못했다 — 기계 상태를 쓰지 않고 멈춘다" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" approve --roadmap "<로드맵>" --session "$sid" --scale "<규모 줄>"
```

멈춤이면 표지를 풀고 멈춘다.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""; [ -n "$sid" ] || { echo "[spec-distill] 세션 id 를 얻지 못했다 — 기계 상태를 쓰지 않고 멈춘다" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" release --roadmap "<로드맵>" --session "$sid"
```

승인 전에는 agent 를 보내지 않는다. 그 뒤의 dispatch 는 띄우기 전에 규모만 알리고 간다.

**`cost_class: high` 의 이름 붙인 예외 — 같은 세션 이어 부르기.** 레포 규칙은 high skill 이 쓰기 전에 `AskUserQuestion` 으로 승인받게 한다. 이 skill 은 같은 세션 · 표지가 살아 있고 · 규모 줄이 글자 그대로 같을 때만, 기계 상태 `## 시작 승인` 에 이미 받은 승인을 다시 쓰고 묻는 대신 공시한다(압축 뒤 이어 부를 때마다 같은 질문을 되풀이하지 않게). 규모가 바뀌었거나 다른 세션이거나 표지를 새로 잡았다면 다시 묻는다.

### 5. 지휘 순환

```
Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md
Read ${CLAUDE_PLUGIN_ROOT}/references/conductor-dispatch.md
```

두 파일의 `<SD>` 는 위 `Read` 줄의 플러그인 폴더(이 skill 이 쓰는 spec-distill 의 절대경로)다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.

`conducting.md` 의 `## 지휘 순환` 걸음 1~7 을 차례로 돈다 — 1 맞추기 · 2 사람 몫 모으기 · 3 다음 일 고르기와 보내기 · 4 돌아오기 · 5 머지 전 확인 · 6 머지 뒤 · 7 끝. 하위에게 보내는 글은 `conductor-dispatch.md` 의 틀이고 그 파일의 처분 줄을 보내는 자리마다 단다. `conducting.md` 의 손으로 따르는 절차는 지휘자를 부르지 않고 진행할 때의 것이다 — 이 skill 안에서는 따르지 않는다.

### 6. 통합 리뷰어

걸음 5 의 통합 리뷰는 아래 자리에서 부른다. `REVIEW_REQUEST` 는 `superpowers:requesting-code-review` 의 리뷰 요청 틀(`code-reviewer.md`)을 이 PR 로 채운 글, `MERGED_COPY` 는 `merge_check.py --keep-merged` 가 남긴 합친 사본, 나머지 셋은 `conductor_ledger.py review-pack` 이 만든 폴더의 파일 경로다. 그 skill 이 스스로 부르는 agent 는 쓰기 도구를 가져 쓰지 않는다 — 틀에서는 무엇을 · 왜 · 범위 칸만 빌려 채운다. 버전 관리 도구를 돌리라는 말과 틀의 출력 형식은 넣지 않는다: 리뷰어는 diff 를 그 도구가 아니라 `PR_DIFF` · `OPEN_DIFFS` 파일과 합친 사본에서 읽고, 내는 형식은 agent 의 `## 내는 것` 이다. 로드맵 frontmatter `review_model` 이 이 dispatch 의 모델 칸이 받는 이름이면 그 값을 주고, 아니면 모델 칸을 빼 세션 모델로 가며 그 사실을 알린다. 이음매가 여럿이면 여럿을 동시에 부른다. 통합 리뷰 지적 전부를 「이 PR 이 고침」 · 「뒤 에픽이 고침」으로 나눠 PR 본문 인계 절과 사용자에게 보인다.

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
    <handoffs>${HANDOFFS}</handoffs>"
)
```

### 7. 옮김 대조

하위가 돌려보낸 사람 자리를 옮긴 에픽이 끝나면(걸음 6) 아래 자리에서 옮김 대조 agent 를 부른다. `RELAY_FILES` 는 그 에픽의 relay 폴더(`conductor_ledger.py resource-dir --roadmap <로드맵> --kind relay --name <에픽>` 이 내는 경로) 안 `relay-*.md` 파일들(계획 agent 의 입력 줄 · 받은 질문 원문 같은 다른 파일은 옮긴 기록이 아니다)의 절대경로를 한 줄에 하나씩 적은 글이다. 그런 파일이 없으면 부르지 않고 「옮긴 질문 없음」 한 줄을 그 에픽 이름과 함께 보인다. 모델 칸은 6 과 같다 — 로드맵 frontmatter `review_model` 이 받는 이름이면 그 값을 주고, 아니면 빼서 세션 모델로 가며 그 사실을 알린다. 옮김 대조 결과 전부(일치 · 어긋남 · 확인 못 함)를 그 에픽 이름과 함께 사용자에게 보인다 — 어긋남이 있으면 그 자리를 그 에픽 설계문서 `## 지휘 기록` 에 적는다.

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

사람에게 쓰는 글은 위 쉬운 말 규칙을 따른다. 지휘자가 정할 질문(흐름 승인 · 감사 · 계획 검토 · 옮긴 질문 · spec 승인)은 `AskUserQuestion` 으로 묻고 질문 문장 앞머리에 에픽 이름을 쓴다(따로 된 첫 줄로 쓰지 않는다). brainstorming 대화는 brainstorming 이 정한 메시지 모양(첫 메시지 · 열린 문장 질문 하나 · 되비춤)을 따른다 — 위 규칙의 순서(첫 줄 상태 · 끝 할 일)를 붙이지 않고 낱말 규칙만 지키며, 지휘 소식(상태 · 목록 · 다른 에픽 소식)은 그 메시지에 얹지 않고 따로 된 메시지로 보인다. 사람에게 보이는 글에서 하위 agent 는 단계대로 「계획 담당자」 · 「구현 담당자」 라고 부른다. 하위가 돌려보낸 사람 자리는 `conductor-dispatch.md` 의 `## 사람 자리` 대로 배경을 먼저 쉬운 말로 쓴 뒤 선택지를 원문 그대로 묻는다. 진행 상황 · 돌고 있는 일의 수를 말할 때는 `conducting.md` 걸음 1 의 맞추기 순서대로 같은 턴에 원천(하니스 agent 목록 · 상태 계산 · 실행 원장)을 다시 조회하고 「HH:MM 기준」 을 붙인다 — 조회하지 않은 숫자는 말하지 않는다.
