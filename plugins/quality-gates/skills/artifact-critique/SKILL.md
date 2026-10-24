---
name: artifact-critique
description: >
  Critique → revise → re-critique loop for one or more NON-CODE artifacts
  (doc / spec / plan / config / prose). Called as `/quality-gates:artifact-critique <path>` (more paths
  allowed, `--findings-only` for read-only) or on a natural-language critique intent ("이 설계문서 비평해줘").
  Tier-unpinned critics (count chosen by the user, default 1) + adversarial (+ optional codex
  co-reviewer) review read-only; the orchestrator fixes and commits each round, or a read-only
  findings-only pass reports findings without editing. Bounded by max-rounds (the user opens more
  rounds at the cap) + stagnation + kill switch. Not a code gate — code targets route to
  /quality-gates:quality-pipeline (one pipeline, one verdict).
cost_class: variable
allowed-tools:
  - Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" quality-gates artifact-critique)
---

!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" quality-gates artifact-critique`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽는다.

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 아래 의존 확인 펜스로 간다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 멈춘다 |
| `[devbrew-entry] error …` | `[quality-gates] artifact-critique 사전 검사 실패 — <reason= 값>.` 을 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[quality-gates] artifact-critique 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[quality-gates] artifact-critique 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실).` 을 내고 멈춘다 |

의존 확인 — 아래 펜스를 Bash 로 한 번 돌린다.

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
python3 "$QG/scripts/check_deps.py" entry --plugin-root "$QG" --need python,git
```

| 결과 | 동작 |
|---|---|
| rc 0 (`[devbrew-deps] ok …`) | 아래 절차로 간다 — `project_dir` 는 E2 가 정한다 |
| rc 3 (`[devbrew-deps] 멈춤 …`) | 펜스 출력을 그대로 보이고 멈춘다 |
| 그 밖 | `[quality-gates] artifact-critique 의존 확인 실패 — 필요한 프로그램의 판을 확인하지 못했다(rc <값>).` 와 펜스 출력을 내고 멈춘다 |

# Artifact Critique (`/quality-gates:artifact-critique`)

<!-- plain-language:begin -->
## 사람에게 쓰는 글
이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. 지시문·subagent 프롬프트·state 파일에는 적용하지 않는다. 아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다. 부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고, 이 블록은 낱말에만 적용한다.
- 처음 보는 사람이 한 번에 이해하게 쓴다. 번호·해시·필드 이름·내부 용어는 가리키는 내용을 문장으로 먼저 쓰고 괄호 안에만 둔다. 지어낸 말은 쓰지 않거나 처음 쓸 때 풀어 쓴다.
- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일. 할 일은 기본 하나다 — 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다. 할 일이 없으면 없다고 쓴다. 커밋·PR 본문에는 이 순서를 적용하지 않는다.
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천은 「(권장)」으로 표시한다.
- 제목과 목록으로 나누되 표의 칸은 짧게 쓴다. 굵은 글씨는 꼭 필요한 곳에만 쓴다.
- 사용자가 알 필요 없는 글은 쓰지 않는다: 도구 호출 사이의 진행 설명, 전부 정상인 항목의 나열. 확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.
- 판정·개수·공시 줄은 스크립트가 낸 쉬운 첫 줄을 그대로 쓰고, 자기 말로 다시 풀거나 덧붙이지 않는다. 스크립트·subagent 가 낸 원문은 고치지 않는다. 스크립트가 풀어 두지 않은 오류에만 쉬운 설명을 앞에 붙이되 통과·실패는 말하지 않는다.
- 사용자와 대화하는 언어로 쓴다. 코드·명령·고유명사·자연스러운 대응어가 없는 기술어는 영어 그대로 둔다. 커밋·PR은 그 레포의 규칙을 따르고, 없으면 대화 언어로 쓴다.
예) 전: `[미적용 fix] 3720b2b7#r1.1` → 후: 리뷰가 고치라고 한 곳 하나가 아직 안 고쳐졌다(3720b2b7#r1.1).
예) 전: (codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건) → 후: 이상 없음.
<!-- plain-language:end -->

비-코드 산출물 하나 이상을 대상으로 **비평 → 수정 → 재비평**을 자율 반복한다(「고치며 돌기」). 판정은
산문이 아니라 결정론 헬퍼(§10 스키마 위 순수 함수)가 내리고, 리뷰어는 read-only이며
수정·커밋은 이 오케스트레이터(writer)만 한다 (Law 2). 라운드마다 git 커밋으로 버저닝.
「지적만 받기」(`--findings-only`)는 대상마다 한 라운드 비평만 받아 보고하고 편집 · 커밋을 하지 않는다.

## kill switch

**보안 컨트롤** — 아래 스위치는 취향 설정이 아니다; 약화하는 PR은 보안 리뷰 대상이다.

- `DEVBREW_QUALITY_GATES_DISABLE=1` — 전역 즉시 종료(E0).
- `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1` — 이 skill 만 종료(E0).
- `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` — codex co-review만 skip(`detect_codex.sh` 존중), tier-unpinned 단독으로 degrade.

## 진입 게이트 (파일 손대기 전)

모든 스크립트는 `${CLAUDE_PLUGIN_ROOT}/scripts/` 하위다 — 아래에 이름만 적힌 스크립트는 이 경로의 것을
실행한다. 이 경로가 절대 경로로 보이지 않으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고한다. 아래 단계를
**순서대로** 실행한다.

### E0 — Preflight (kill switch)

두 kill switch를 존중한다. 켜져 있으면 한 줄 출력 후 즉시 종료(파일 무변경):
- 전역 `DEVBREW_QUALITY_GATES_DISABLE=1` → `> [quality-gates] artifact-critique 를 건너뛰었다 — quality-gates 전체가 꺼져 있다(DEVBREW_QUALITY_GATES_DISABLE=1).`
- skill 전용 `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1` → `> [quality-gates] artifact-critique 를 건너뛰었다 — DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1 이 켜져 있다.`

### E1 — 대상 해석 + 코드/비-코드 분류 + 모드

이 skill 의 인자로 받은 경로가 대상이다. 경로가 여럿이면(대상이 여럿) 전부 대상이다. NL 진입이면
대화/컨텍스트에서 대상 경로를 해석한다. 대상마다:

```
classify_artifact_target.py <path>
```

- `classification: code` → 그 대상만 빼고 알린다(남은 대상이 0 이면 **종료**). 비-코드 전용 skill 이라 코드는 자율 커밋 루프에 넣지 않는다:
  `> [quality-gates] '<path>'는 코드 파일로 보여 대상에서 뺐다 — 코드 리뷰는 /quality-gates:quality-pipeline 으로 실행하세요.`
- `classification: non_code` → 진행.
- `classification: ambiguous` → E3 *이전에* `AskUserQuestion`으로 확인: *"이 파일(`<path>`)을 산출물로 비평할까요? (코드라면 /quality-gates:quality-pipeline 을 쓰세요.)"* — **예** 확인 없이 자율 루프 진입 금지. "아니오"면 그 대상을 뺀다(남은 대상이 0 이면 종료).

모드를 정한다 — 모드는 실행 전체에 하나다. 인자에 `--findings-only` 가 있거나 요청이 고치지 말고 지적만 원하면
「지적만 받기」(대상마다 한 라운드 비평만 받아 보고하고 편집 · 커밋을 하지 않는다), 아니면 「고치며 돌기」(라운드마다
고치고 커밋한다). `--findings-only` 는 대상 경로가 아니다. 같은 파일을 두 번 적었거나 symlink 와 그것이 가리키는 파일을
함께 적었으면 E2c 가 `canonical` 로 하나로 합친다.

### E2 — 브랜치 안전 (project_dir 좌표 freeze)

```
artifact_branch_guard.sh
```

출력의 `project_dir:`를 이번 파이프라인의 **frozen 좌표**로 삼는다(이후 재계산 금지).
「지적만 받기」는 E2 의 `project_dir:` 만 쓰고 `branch_ok` · E2b 를 요구하지 않는다(커밋하지 않는다) — 곧장 E2c 로 간다.
「고치며 돌기」에서 `branch_ok: false`면 아래 안내 줄을 내고 멈춘다(E2b 끝의 「멈출 때의 선택」):
- `reason: detached_head` → `> [quality-gates] detached HEAD — 커밋 대상 브랜치가 없습니다. 브랜치를 체크아웃한 뒤 재실행하세요.`
- `reason: on_default_or_protected_branch` → `> [quality-gates] 현재 '<branch>'는 기본/보호 브랜치입니다. 자율 커밋을 막습니다 — feature/fix 브랜치에서 재실행하세요.`

`branch_ok: true`이고 출력에 `warn: default_branch_unverified`가 있으면(origin/HEAD 미설정 —
repo의 default를 authoritative하게 결정 못 함) 진행하되 loud advisory를 표시한다: `> [quality-gates]
origin/HEAD 미설정 — '<branch>'가 보호 기본 브랜치가 아님을 확인하세요(heuristic 통과·미검증).`

### E2b — 대상 HEAD-tracked + clean 전제

「고치며 돌기」에서만, 대상마다:

```
artifact_change_signal.sh <path>
```

`tracked:`와 `changed:` 두 줄을 **모두** 읽는다(순서대로 판정):
- `tracked: false` → 안내 줄을 내고 **멈춘다**: `> [quality-gates] '<path>'가 아직 커밋되지 않은(untracked) 파일입니다. 먼저 git add+커밋한 뒤 재실행하세요(라운드별 커밋은 HEAD-tracked 기준선 대비 diff을 커밋합니다).` (`git diff --quiet HEAD`는 untracked 경로를 보지 못해 `changed: false`로 오독될 수 있으므로 — E2b는 `tracked:`를 먼저 판정해 이 오독을 구조적으로 차단한다.)
- `tracked: true` AND `changed: true`(HEAD 대비 uncommitted 변경 존재) → 안내 줄을 내고 **멈춘다**: `> [quality-gates] '<path>'에 커밋되지 않은 변경이 있습니다. 먼저 커밋/stash 후 재실행하세요(라운드별 커밋 무결성 — pre-existing 변경이 라운드-1 커밋에 섞이지 않도록).`
- `tracked: true` AND `changed: false` → 진행.

**멈출 때의 선택** — E2 와 모든 대상의 E2b 를 먼저 끝까지 돌려 멈춘 이유를 모은 뒤(안내 줄은 대상마다 낸다), 질문은
한 번만 한다. 멈춘 대상이 여럿이어도 질문은 하나이고, 질문 글에 멈춘 대상과 이유를 대상마다 나열한다. `AskUserQuestion`:
*"고치며 돌 수 없다 — <멈춘 대상과 이유 목록>. 어떻게 할까요?"* — 옵션:
**지적만 받기로 진행**(실행 전체를 「지적만 받기」로 바꾼다 — 모드는 실행에 하나라 모든 대상이 편집 · 커밋 없이 한 라운드
지적만 받는다. 모드를 바꾸고 E2c 로 간다) /
**그 대상만 빼고 진행**(E2b 에서 멈춘 대상만 빼고 나머지는 「고치며 돌기」로 E2c 로 간다 — E2 에서 멈췄거나 빼면 남는
대상이 0 이면 이 선택지를 내지 않는다) /
**멈추기**(여기서 끝낸다 — 안내 줄대로 고친 뒤 다시 부른다).

### E2c — 대상 경로 인가 (canonical freeze; 리뷰어 read 前)

산출물을 **읽기 전에** 대상 경로를 인가하고 canonical을 freeze한다 — critic/codex가
symlink을 따라 project_dir 밖 파일을 읽어(codex는 외부 프로세스로 유출) 커밋 없이
종료(수렴)하는 경로를 봉쇄한다(인가가 편집 직전 step 6에만 있고 수렴 시 skip되면
리뷰어 read가 인가보다 앞서는 순서 버그). 두 모드 모두, 대상마다:

```
artifact_path_auth.py <project_dir> <path>
```

- `auth: reject` → **종료**: `> [quality-gates] '<path>'가 project_dir 밖을 가리킵니다(symlink/traversal escape) — 대상 거부.`
- `auth: ok` → 반환된 `canonical:`을 그 대상의 이후 **모든** 단계(critic·codex·adversarial read, 편집)의
  **frozen 대상 경로**로 삼는다. **세 리뷰어 모두**의 read와 편집은 raw `<path>`가 아니라
  `canonical`을 쓴다(git 커밋/change-signal은 E2b가 검증한 tracked `<path>` 그대로).
- 인가가 끝나면 `canonical` 이 같은 대상(같은 파일을 두 번 · symlink 와 그 대상)은 먼저 적은 하나만 남기고 알린다:
  `> [quality-gates] '<path>'는 '<먼저 적은 path>'와 같은 파일이라(<canonical>) 한 번만 비평한다.`

> **알려진 한계 (TOCTOU):** E2c는 경로 *문자열*을 freeze하지 캐노니컬 *inode*를 freeze하지
> 않는다 — 인가와 read 사이 동시 로컬 프로세스가 파일을 교체하면 reviewer가 교체된 대상을
> 읽을 수 있다. dev 도구의 위협 모델(자기 repo에서 자기 문서 비평)에선 비현실적이라
> 스냅샷-복사까지 하지 않는다. static escape(committed symlink이 project_dir 밖을 가리킴)는
> E2c가 read 前에 차단하고, step 6는 편집 직전 canonical 불변을 재검증한다.

### E3 — 범위 고르기 · 규모 공시

먼저 한도를 계산한다:

```
artifact_max_rounds.sh
```

`effective_max_rounds:` 값을 읽어(= env clamp, 기본 5) **고지 문구와 루프 한도로 동일하게
사용**한다(고지 범위 = 실행 범위; disclosure-integrity). 상한을 넘는 라운드는 상한에서 사용자가 연 것만 돈다(9).
`AskUserQuestion` 한 번에 두 질문을 싣는다:

(1) 대상 목록 · 모드 · 상한:
> *"대상 `<대상 목록>` 을 「<모드>」로 돌릴까요? (고치며 돌기: 대상마다 최대 `<effective_max_rounds>`라운드 · 브랜치 `<branch>` 에
> 라운드마다 커밋 / 지적만 받기: 대상마다 한 라운드 · 편집 · 커밋 없음). codex 를 쓸 수 있으면 대상 파일의 내용이 codex(바깥
> 프로그램)에 넘어간다 — 지적만 받기는 커밋하지 않은 파일도 그대로 넘긴다."* — 옵션: **실행** / **대상 변경**(→ E1 재진입) /
> **지적만 받기로 바꾸기**(지금 고치며 돌기일 때 — 편집 · 커밋 없이 한 라운드 지적만) 또는 **고치며 돌기로 바꾸기**(지금 지적만
> 받기일 때 — 고르면 E2 의 `branch_ok` 검사와 E2b 를 다시 돈다 — `project_dir` 는 E2 에서 얼린 값 그대로) / **취소**.

(2) 비평자 수:
> *"라운드마다 비평자를 몇 명 부를까요? (기본 1명 — 늘리면 지적을 더 넓게 찾지만 라운드마다 그만큼 더 부른다. 라운드마다
> 부르는 수는 비평자 수 + 2(반박자 1 · codex 1), codex 를 못 쓰면 + 1 — 1명이면 3)"* —
> 옵션: 「1명 (권장)」 · 「2명」 · 「3명」, 기타 칸에 다른 수. 기타 칸의 글이 1 이상의 정수가 아니면 다시 묻는다.
> 고른 수를 `<k>` 로 기록해 루프의 모든 라운드에 쓴다.

이 게이트는 N을 되묻지 않는다(값은 고지). 이 질문은 범위를 고르는 질문이다 — 라운드마다 띄울 수와 상한은 본문에 공시한다. 지출 승인을 묻지 않는다.

## 루프 (대상마다 · 라운드 N = 1..effective_max_rounds — 상한에서 사용자가 더 연다)

대상이 여럿이면 대상마다 이 루프를 차례로 돈다(대상마다 라운드 · 커밋 · 상한 — 한 대상의 루프가 끝나야 다음
대상으로 간다). 「지적만 받기」는 대상마다 한 라운드(1~4)만 돈다.

라운드당 디스패치는 기본 3(비평자 1 · codex 가용 시 1 · 반박자 1)이다 — 비평자 수는 E3 에서 정했다. 비평자를
`<k>` 명으로 정했으면 라운드당 `<k>`+2 이하이고, 동시 실행은 비평자 `<k>` 명 ∥ codex(adversarial 은 병합 후 순차)다.
규모는 E3 에서 사용자가 정하고 아래 줄로 라운드마다 공시하며 라운드끼리는 순차라 subagent spray 아님.

**라운드 시작** — `detect_codex.sh` 로 codex 가용성을 먼저 보고(판정 규칙은 2), dispatch 전에 이 줄을 낸다:

`> [quality-gates] 라운드 <N> (<대상>) — 비평자 <k>명(기본 1명) · codex <부름 | 안 부름(<사유>)> · 반박자 1명`

`<사유>` 는 2 의 `<skip_reason>` 또는 `detector_not_runnable` 이다.

**1. critic** — `artifact-critic` 을 비평자 `<k>` 명(E3 에서 정한 수, 기본 1)만큼 나란히 디스패치(read-only). 각
   프롬프트에 frozen `project_dir` + 그 대상의 E2c 인가 `canonical` 경로(raw `<path>` 아님 — symlink escape 봉쇄)
   스레딩. i 번째 비평자의 `findings:` YAML을 scratch `critic-<i>.yaml`에 저장(i = 1..`<k>`).

```
Agent({
  subagent_type: "quality-gates:artifact-critic",
  // **처분** — consumer=plugins/quality-gates/scripts/synthesize_artifact_findings.py · fail-closed
  description: "Artifact critique round N critic i",
  prompt: "project_dir: <project_dir>${PROJECT_DIR}</project_dir>\nartifact_path: <artifact_path>${CANONICAL_PATH}</artifact_path>\n그 경로의 지금 산출물을 비평하고 §10 Finding YAML을 emit하라."
})
```

**2. codex co-reviewer (조건부)** — 라운드 시작에서 돌린 `detect_codex.sh` 의 판정으로(비평자와 나란히):
- `codex_available: true` → `run_artifact_codex_reviewer.sh <canonical> <project_dir> <codex.yaml>`
  (E2c가 인가한 canonical — codex 프롬프트에 산출물이 임베드되므로 escape symlink는 read 前 거부됨).
  - **rc를 잡는다.** 러너는 평소 exit 0 + 항상 codex.yaml을 쓰지만, 산출물 경로
    자체를 쓸 수 없으면(디렉토리 부재·권한·RO 마운트) loud stderr를 낸 뒤 **exit 3**
    으로 죽는다. `rc == 3`이면 codex.yaml을 읽기 **전에** 지운다(`rm -f codex.yaml`)
    — 지우지 않으면 직전 라운드의 YAML(양성 `codex_failed: false`를 담고 있을 수
    있다)이 그대로 남아 이번 라운드의 codex 판정으로 읽힌다. 형제
    `run_docreview_codex_reviewer.sh`(spec-distill 의 문서 리뷰 러너)와 동일한 exit-3
    계약이고, 그 호출자(`spec-distill`의 `spec-review`·`reviewing-brief` SKILL)가 같은
    `rc==3 → rm -f` 패턴을 구현하고 있다.
  - 출력이 `codex_failed: true`면 **가용 판정 후 런타임 실패**: `> [quality-gates] codex 가용 판정 후 런타임 실패(<reason>) — degraded, tier-unpinned 단독.` (crash 아님, C7) codex.yaml은 병합에서 제외.
- `codex_available: false` → **미가용**: `> [quality-gates] codex 미가용(<skip_reason>) — tier-unpinned 단독 비평.` (위 런타임-실패 문구와 **구분**된 별도 라인.) `<skip_reason>` 자리에는
  `not_installed`·`auth_missing`·`timeout_binary_missing`·`known_bad_version`·
  `version_below_floor`·`version_unreadable`·`kill_switch`·`inside_codex_sandbox`
  외에 형제 설정 `codex-killswitch.conf` 문제를 가리키는 `killswitch_config_missing`·
  `killswitch_config_incomplete`·`killswitch_config_invalid`도 정상적으로 올 수
  있다(정본 통합 이후 새 사유 — `kill_switch`는 이 SKILL이 사용자에게 안내하는
  `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1`의 결과값이라 오히려 가장 흔한 사유다. `kill_switch`·
  `inside_codex_sandbox` 두 사유는 quality-pipeline SKILL에서는 별도 "silent" 표로
  분리돼 배너를 안 낸다 — 사용자가 직접 껐거나 재귀 방지라 결손이 아니기 때문이다.
  이 SKILL은 배너 문구를 하나로 통일하므로 그 구분을 유지하지 않지만, `<skip_reason>`
  값 자체는 quality-pipeline SKILL이 다루는 사유 집합과 같다).
- **`detect_codex.sh` 실행 자체가 실패했거나(비-zero exit·빈 stdout) 출력에
  `codex_available:` 줄이 아예 없으면** → "codex 미가용"이 **아니다**. 정상 실행된 감지기는
  `codex_available: false`여도 항상 `skip_reason`을 함께 낸다(위 열거 중 하나) — 그
  줄 자체가 없다는 것은 감지기가 안 돌았다는 뜻이고, 심볼릭 링크가 끊겼을 수 있다
  (`plugins/quality-gates/scripts/detect_codex.sh`는 `shared/codex/detect_codex.sh`를
  가리키는 상대 심볼릭 링크다). `<skip_reason>` 자리를 `unknown`으로 채우지 말고
  **`detector_not_runnable`**로 구별해 낸다:
  `> [quality-gates] codex 감지기 실행 실패(detector_not_runnable) — tier-unpinned 단독 비평.`
  (위 두 문구와 **구분**된 별도 라인 — "codex가 없다"와 "감지기를 못 돌렸다"는 다른 사실이다.)

**2.5 merge + key** — 비평자 `<k>` 명(+가용·성공 시 codex)의 findings를 dedup하고 dedup_key를 주입:

```
synthesize_artifact_findings.py --phase key --findings critic-1.yaml … --findings critic-k.yaml [--findings codex.yaml] > merged.yaml
```

`merged.yaml`의 각 finding은 `dedup_key`를 갖는다(다음 단계 adversarial가 echo).

**3. adversarial** — `artifact-adversarial`(반박자) 디스패치(read-only). `merged.yaml`을 프롬프트에
   넣어 §10 verdict를 받는다(`finding_key`=각 finding의 `dedup_key`). 출력을 `verdicts.yaml`에 저장.
   `project_dir` + E2c 가 인가한 `canonical`(raw `<path>` 아님)을 스레딩한다. adversarial 은 egress 도구가 없다(`tools: Read, Grep, Glob`)
   — 그래도 산출물을 read 하므로 E2c 가 인가한 그 경로로 읽게 critic · codex 와 같은 canonical 을 넘긴다.
   **`merged.yaml`의 keyed 내용(각 finding의
   `dedup_key` 포함)을 프롬프트에 그대로 inline** — 이 스레딩이 빠지면 adversarial이
   `finding_key`를 echo할 수 없어 모든 finding이 미판정(unadjudicated) 처리된다(§10 fail-closed
   경로, Issue 1의 false-convergence 가드가 막아주는 케이스와 직결):

```
Agent({
  subagent_type: "quality-gates:artifact-adversarial",
  // **처분** — consumer=plugins/quality-gates/scripts/synthesize_artifact_findings.py · fail-closed
  description: "Artifact adversarial review round N",
  prompt: "project_dir: <project_dir>${PROJECT_DIR}</project_dir>\nartifact_path: <artifact_path>${CANONICAL_PATH}</artifact_path>\n다음은 병합된 keyed findings(merged.yaml)이다 — 각 finding의 dedup_key를 finding_key로 echo하며 §10 verdict(confirm/downgrade/reject)를 매겨라:\n<merged_findings>${MERGED_FINDINGS}</merged_findings>"
})
```

**4. synthesize (결정론)** —

```
synthesize_artifact_findings.py --phase synth --findings merged.yaml --adversarial verdicts.yaml
```

출력에서 `converged` / `degraded` / `degraded_reason` / `unadjudicated` / `kept_*` /
`stagnation_keys` / `kept:`를 읽는다.
- `unadjudicated > 0` → loud log(모드마다 다르다):
  - 「고치며 돌기」: `> [quality-gates] adversarial 미판정 <N>건 — 이번 라운드 편집 제외(fail-closed).`
  - 「지적만 받기」: `> [quality-gates] 반박자가 판정 못 한 지적 <N>건 — 고친 것도 버린 것도 아니다, 보고에 「판정 못 함」으로 따로 싣는다.`
- `degraded: true` → adversarial가 0-verdict/파싱불가(findings는 있었음), 또는 findings-side
  로드 실패, 또는 손실 있는 phase-key 병합(`degraded_reason: adversarial|findings_load|sources_failed`).
  kept-empty를 수렴으로 읽지 **않는다** → **NEEDS_RESOLUTION**: `AskUserQuestion`으로
  *"이번 라운드 adversarial 판정 실패(사유: `<degraded_reason>`) — 재시도 / 중단?"*
  (false-convergence fail-open 봉쇄). `degraded_reason`을 사용자에게 노출해 원인(adversarial
  실패인지 findings 로드 실패인지 소스 유실인지)을 알린다.

**4b. 지적만 받기면 여기서 끝** — 「지적만 받기」 모드면 남은 `kept` 를(SUGGESTION 포함) 보고하고 그 대상을 끝낸다 —
   5~9 와 편집 · 커밋을 하지 않는다(종료 사유 `findings_only`). `degraded: true` 면 위 NEEDS_RESOLUTION 게이트가 먼저다.
   `unadjudicated > 0` 이면 보고에 `판정 못 한 지적 <N>건` 을 따로 한 줄로 쓰고, 그 아래 `unadjudicated_items` 를 하나씩
   「판정 못 함」 라벨을 붙여 보인다(`plain:` 이 있으면 먼저, `summary` 는 괄호에).

**5. 수렴 체크** — `converged: true`(kept CRITICAL/IMPORTANT == 0, degraded 아님)면 **수렴,
   루프 종료**. SUGGESTION만 남으면 수렴으로 간주(목록만 surface, 수정 안 함). 수렴 판정은
   독립 kept 집합이 결정(오케스트레이터 자기판단 아님 — Law 2).

**6. 수정 적용** — 미수렴이면, 편집 *직전* 대상 경로를 다시 인가한다(E2c가 read 前
primary 인가를 했고, 이 재확인은 라운드 간 symlink swap을 잡는 TOCTOU 재검증):

```
artifact_path_auth.py <project_dir> <path>
```

`auth: reject`면 종료(symlink/traversal escape). `auth: ok`이고 반환된 `canonical:`이
**E2c에서 freeze한 canonical과 정확히 동일**할 때만 그 경로를 곧바로(check와 write 사이
다른 도구 호출 없이 — TOCTOU 방지) 대상으로 kept의 CRITICAL/IMPORTANT finding을 해소하도록
`Edit`/`Write`. 재확인 canonical이 E2c freeze 값과 **다르면**(라운드 중 symlink이 다른
in-tree 파일로 swap됨) 종료: `> [quality-gates] 대상 경로가 인가 후 변경됨(canonical mismatch) — 중단.` Finding에는 path 필드가 없고
`proposed_fix` 자유 텍스트에서 경로를 추출하지 않는다(라운드마다 대상 하나 불변 — 지금 대상의 canonical 만 편집한다).

**6b. 변경 신호 (커밋 *전* — 반드시 여기서 캡처)** —

```
artifact_change_signal.sh <path>
```

`changed:` 값을 기록한다. `changed: false`(편집이 no-op — 모델이 진전 못 냄)면 커밋을
skip한다. *커밋 후엔 워킹트리가 항상 clean이라 이 신호가 무의미해지므로 반드시 커밋 전에
캡처한다*(라운드-2 리뷰가 잡은 block 버그의 fix).

**7. 커밋** (`changed: true`일 때만) —

```
artifact_commit.sh <path> "critique(round N): <해소한 finding 요약>"
```

`committed_sha:`를 라운드 히스토리에 기록. `no_op: true`면 이번 라운드는 커밋 없음으로
기록(SHA 미기재; step 6b가 이미 걸렀어야 하나 방어적 재확인 경로). `error:`면 loud surface
후 루프 중단.

**8. stagnation 체크** —

```
artifact_stagnation.py --this "<이번 stagnation_keys>" --prev "<직전 stagnation_keys>" --changed "<6b changed>"
```

`stagnant: true`면 루프 종료(reason 기록). `--changed`는 반드시 step 6b의 커밋-전 신호를
쓴다.

**9. N+1로 반복** (종료 조건 미충족 시). 방금 끝난 라운드가 `effective_max_rounds`(또는 사용자가 연 마지막 라운드)이고
수렴하지 않았으면 바로 끝내지 않고 `AskUserQuestion`:
> *"<대상> 비평을 `<N>`라운드 돌았다(상한 `<effective_max_rounds>`) — 남은 지적 `<kept 수>`개. 한 라운드 더 돌까요?"* — 옵션:
> **한 번 더 돌기**(라운드 하나를 더 연다 — 그 끝에 다시 묻는다) / **여기서 끝내기**(종료 사유 max_rounds).

기타 칸의 글이 더 여는 뜻이면 「한 번 더 돌기」와 같은 길이고, 뜻이 분명하지 않으면 다시 묻는다. 연 승인은 라운드
히스토리에 이 줄로 남긴다 — 선택지를 골랐으면 `label` 과 선택지 이름, 기타 칸에 썼으면 `typed` 와 그 글 그대로:
`추가 라운드 승인: <label | typed> · <원문>`

## 종료 & 최종 요약 (AC11)

보고의 첫 줄은 끝났는지와 결과 한 문장이다(예: 「비평을 3라운드 돌고 수렴했다 — 남은 지적 없음.」 · 「상한 5라운드에 닿았다 — 남은 지적 2개.」 · 「지적만 받기로 한 라운드 돌았다 — 지적 3개, 고치지 않음.」). 잔여 `kept` 항목에 `plain:` 이 있으면 그것을 먼저 쓰고 원래 `summary` 는 뒤 괄호에 둔다. 맨 끝에 사용자가 할 일을 쓴다 — 기본 하나, 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다.
판정 못 한 지적이 있으면(`unadjudicated > 0`) 첫 줄에 「판정 못 한 지적 <N>건」을 함께 쓰고, 첫 줄을 「남은 지적 없음」 ·
「이상 없음」처럼 깨끗하게 읽히게 쓰지 않는다.

종료(수렴 / max-rounds / stagnation / 지적만 받기 / NEEDS_RESOLUTION-중단 / kill switch) 시 반드시 출력 — 대상이 여럿이면 대상마다:
- **라운드 히스토리**: 라운드별 비평자 수 · kept 요약 + 각 커밋 SHA(지적만 받기는 커밋 없음) + 추가 라운드 승인 줄.
- **종료 사유**: converged / max_rounds(N) / stagnant(reason) / findings_only / needs_resolution / killed.
- **잔여 kept 집합**(중단 · 지적만 받기 시): 마지막 라운드의 미해소 CRITICAL/IMPORTANT(지적만 받기는 SUGGESTION 도).
- **판정 못 한 지적**(`unadjudicated > 0` 일 때, 모드 무관): `판정 못 한 지적 <N>건` 한 줄과 마지막 라운드의
  `unadjudicated_items` 를 하나씩 「판정 못 함」 라벨로.

## Law 2 보증

critic·adversarial·codex는 read-only(`tools:` allowlist / codex `-s read-only`). 수정·커밋은
이 오케스트레이터만. **매 라운드 독립 critic이 게이트**: 라운드 N의 수정을 라운드 N+1의
*독립* critic이 재검토하며, 최종 "수렴"은 마지막 독립 critic 패스의 kept 집합이 결정 —
자기 편집을 자기 판단으로 승인하는 경로가 구조적으로 없다.
