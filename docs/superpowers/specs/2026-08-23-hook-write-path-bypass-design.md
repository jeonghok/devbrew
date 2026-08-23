---
name: hook-write-path-bypass
type: design
date: 2026-08-23
next_phase: superpowers:writing-plans
---

# 훅 쓰기-경로 우회 봉쇄 — Design

> 훅의 matcher 는 **도구 이름**을 열거한다. 그러나 훅이 지키는 불변식은 **파일**에 대한 것이다.
> 층위가 어긋나 있어서, 열거되지 않은 도구로 같은 파일을 쓰면 게이트가 조용히 꺼진다.

## 상태 — 중단됨 (2026-08-23)

> **이 설계는 구현되지 않았고, 아래 §0 의 이유로 중단됐다.** 본문 §1~§12 는 판본 3 이며
> 라운드 3 리뷰에서 `needs_revise` 를 받았다. **본문을 그대로 구현하지 말 것** — 미해결
> 지적이 §0.3 에 있다. 재개한다면 §0.2 의 발견에서 시작하는 것이 §1 부터 읽는 것보다 빠르다.

### §0.1 무슨 일이 있었나

리뷰 3라운드, 설계 3판본. 매 판본이 앞 판본의 block 을 닫고 **같은 영역에 새 block 을
만들었다.**

| 판본 | 방식 | 신규 block | 깨진 이유 |
|---|---|---|---|
| 1 | matcher 삭제 + payload `file_path` | 4 | 도구 열거가 `hooks.json` 밖 파이썬에도 있었다 (세 곳) |
| 2 | + degrade·`bootstrap` 정교화 | 4 | `Read` 의 `tool_input` 도 `file_path`; 경로집합은 재편집을 못 봄; `not is_born` = `git status` dirty 가 거짓 |
| 3 | payload 안 봄 + 내용 해시 + `UserPromptSubmit` 기준선 | 3 | 귀속 상실; Layer 1 팬아웃이 훅 timeout 초과; 기준선을 남의 훅에 호스팅 |

사용자 결정으로 라운드 4 를 돌지 않고 여기서 멈춘다.

### §0.2 이 작업의 핵심 발견 — 층위에 정보가 없다

**`PostToolUse` 는 *도구가 돌았다*를 알려줄 뿐 *그 도구가 무엇을 바꿨는지*는 알려주지
않는다.** 그 간극을 메우는 길은 둘뿐이고, 둘 다 구조적 대가가 있다.

| 길 | 대가 | 어느 판본이 밟았나 |
|---|---|---|
| payload 를 읽어 추론 | 도구·스키마 **열거**로 되돌아간다. `Read` 를 빼면 `Glob` 이, 그 다음엔 오늘 없는 도구가 남는다 | 1 · 2 |
| 파일시스템을 관찰 | **귀속(attribution) 상실** — `git checkout`·`merge`·에디터 편집이 "이 도구 호출이 바꿨다"가 된다. 비용도 dirty 집합 크기에 비례 | 3 |

**세 번째 길은 이 층에 없다.** 세 판본은 그 사실을 세 방향에서 확인한 셈이다.

따라서 재개 시의 실질적 선택지는 셋이다 (셋 다 이 문서에서 결정되지 않았다):

1. **게이트를 `Stop` 훅으로 옮긴다** — 도구 호출마다가 아니라 턴당 1회. *"이 턴이 바꾼
   파일"* 은 참인 명제라 귀속 문제가 소멸하고, 호출이 30분의 1이라 팬아웃·측정·advisory
   반복 문제가 함께 줄어든다. spec-distill 은 이미 `Stop` 훅을 가지며 **집행도 거기서
   일어난다**. 대가: Layer 1 피드백이 턴 끝으로 밀린다. qg·project-init 은 신규 훅 2개.
2. **열거를 정직하게 한다** — matcher 와 파이썬 allowlist 를 한 곳으로 모으고 `Bash` 를
   포함시킨다. 실제 보고된 벡터는 닫히고, 남는 구멍(`NotebookEdit`·`mcp__*`)을 README·
   CHANGELOG 에 이름으로 적고 새 도구 등장 시 RED 나는 락을 둔다. 클래스는 안 닫히지만
   **열거가 보이게 된다.**
3. 이 문서의 판본 3 을 §0.3 대로 고쳐 계속한다.

### §0.3 미해결 — 라운드 3 지적 14건

**block 3 (전부 판본 3 이 만든 것)**

| # | 무엇 | 확인된 근거 |
|---|---|---|
| N1 | 기준선을 `pending-review-reminder.py` 에 얹으면 죽은 코드 | 그 파일은 :44 kill switch 후 :59·:62·:81·**:83-84** 에서 return. `if not m: return 0` 가 지배 경로. 게다가 *"nag 만 끈다"* 던 `:reminder` 스위치가 Law 1 기준선까지 끈다 |
| N2 | payload 분기 제거 = 귀속 상실 | `git checkout`·`merge`(충돌 마커 든 `UU`)·에디터 편집이 손대지 않은 문서에 `exit 2` 를 유발. §4.5 가 degrade 를 기각한 논리가 정상 경로로 들어왔다 |
| N3 | §5.1 의 "상한 없음"이 훅 timeout 과 충돌 | `hooks.json:22` 훅 timeout = 10초. `call_parser` 는 호출마다 `timeout=10` 인 `python3` 를 띄우고 spec 모드는 4회. 훅이 timeout 으로 죽으면 출력도 신호도 없다 |

**high 6** — ① `changed()` 가 원장을 갱신하므로 소비자가 미룬 문서가 영구히 굶는다 ·
② "해시는 절대값이라 손실 갱신이 자연 복구"는 보고↔기록 분리에는 거짓 (동일 내용 재-Write 가
재발동하지 않음) · ③ git 이 보고하는 후보만 해시하면 `.gitignore`·리포 밖·`skip-worktree`·
clean 필터가 사각지대 (그리고 qg 는 오늘 필터가 **없어서** "기존 동작과 동일"이 거짓) ·
④ status 코드 상태기계 미정의 (`D`·`UU`·`!!`·`R`/`C` 의 X/Y 위치) · ⑤ §7 이 비용의 지배
변수(`|dirty ∪ untracked|`)를 고정하지 않고 L12 는 지어낸 수와 측정값을 구별 못 함 ·
⑥ L10~L12 의 "존재가 곧 불변식" 면제가 성립하지 않음 (**존재 락은 스텁으로 만족된다**)

**medium 5** — ① project-init 이 오늘 없는 git 하드 의존을 얻어 비-git 디렉토리에서 lint 가
영영 안 돎 · ② L6 mutation 이 실제 락과 어긋남 (`copy-of` 마커 사본은 승인된 배포 형태이고,
세 링크를 다 일반 파일로 바꾸면 `SYMLINK_CANONICALS` 도출에서 정본이 빠진다) ·
③ `:(top,literal)` 에 **디렉토리 접두**를 쓰는 것은 `arm_ledger` 선례(전체 파일 경로)의
미측정 확장 · ④ L3 의 음의 짝이 문자열 금지라 거짓 RED 또는 변수명 변경으로 통과 (AST 필요) ·
⑤ 기준선이 모든 리포·모든 세션에 state 디렉토리를 만들고 `undetermined` advisory 에 세션당
1회 래치가 없음

### §0.4 이 리뷰의 한계

**세 라운드 모두 codex co-reviewer 가 불참했다** (사용법 한도 소진, 2026-09-17 까지).
이 리포의 기록상 **모델 다양성은 공유-맹점의 유일한 backstop** 이다. 리뷰어와 저자가
같은 모델 계열이므로, **양쪽이 함께 놓친 것은 한 번도 검사되지 않았다.**

부수적으로 발견된 별개 결함 2건 (이 설계와 무관, 미수정):
`plugins/spec-distill/scripts/run_spec_codex_reviewer.sh` 가 `set -euo pipefail` 아래에서
`${CLAUDE_PLUGIN_ROOT}` 를 기본값 없이 참조한다 (137·186행). `reviewing-spec` 스킬의 bash
블록은 그 변수를 export 하지 않으므로 **codex co-review 가 그 경로에서 구조적으로 도달
불가**하다. 형제 파일 `run_brief_codex_reviewer.sh:17` 에는 같은 결함에 대한 수정과 주석이
이미 있다.

---

> 아래 §1~§12 는 판본 3 본문이다. 위 §0 을 읽지 않고 구현하지 말 것.

## Handoff Context

> 이 설계를 처음 보는 사람(또는 `/compact` 후 자기 자신)이 30초에 핵심을 잡게 하는 블록.
> 대화 컨텍스트를 가정하지 않는다.

**TL;DR** — devbrew 세 플러그인의 `PostToolUse` 훅이 도구 이름을 열거한다. Bash heredoc·`sed -i`
로 같은 파일을 쓰면 훅이 안 돌거나, 돌아도 첫 줄에서 빠져나간다. **열거는 플러그인당 두 곳
— `hooks.json` 의 `matcher` 와 파이썬 스크립트 안의 allowlist — 합계 여섯 곳이다.** 실측으로
확정: `matcher` 키를 생략하면 그 훅은 모든 도구 호출에 발화하고 subagent 호출도 포함된다.
변경은 세 층이다 — matcher 삭제 셋 + 파이썬 allowlist 제거 셋 + **payload 분기 제거**.
훅은 payload 에서 아무것도 추론하지 않고, `shared/writewatch/` 에 "이 프롬프트의 기준선 이후
내용이 바뀐 파일"을 묻는다. 기준선은 `UserPromptSubmit` 이 프롬프트마다 찍는다.

**설계의 중심 결정 (라운드 2 리뷰 후 재설계)**

| 축 | 이전 판본 | 지금 |
|---|---|---|
| 분기 | payload 에 `file_path` 가 있으면 그 경로, 없으면 감지 | **분기 없음** — 언제나 감지 |
| 원장 | 경로 집합 | **경로 → 내용 해시** |
| 기준선 시점 | 세션 첫 도구 호출 | **`UserPromptSubmit`** (도구가 돌기 전) |
| 소비자 정책 | `bootstrap` 파라미터로 공유 계약에 주입 | 공유 계약에서 제거 — 소비자가 반환값을 자기 규칙으로 거른다 |

**이 설계가 서 있는 실측** (2026-08-22, Claude Code 2.1.239, 격리 프로브 + 헤드리스 2회)

| 잰 것 | 결과 |
|---|---|
| `PostToolUse` 에서 `matcher` 키 생략 | 전체 도구에 발화 — Write·Bash 모두 포착 |
| subagent 의 Bash heredoc | `PostToolUse`·`PostToolBatch` 둘 다 발화 |
| main/subagent 구분 | `agent_id` — subagent 는 값, main 은 없음 |
| 번들 훅 이벤트 레지스트리 | 29종 중 matcher 미지원 9종 |
| `FileChanged` 발화 | **0건** — matcher 3변형 모두. 헤드리스라서인지 문법 문제인지 미분리 |

프로브 플러그인은 리포에 커밋한다 (§10.3).

**암묵 컨텍스트 (문서 밖 근거)**

| 무엇 | 어디서 왔나 |
|---|---|
| 세 플러그인 전부를 대상으로 | 사용자 결정 — 라운드 2 후 재확인 |
| 감지 모듈은 `shared/` | 사용자 결정 |
| 한 도구 호출당 문서 하나만 arm, 나머지는 advisory | 사용자 결정 (라운드 1 후) |
| `/cancel-review` 를 이 설계에서 **분리** | 사용자 결정 (라운드 1 후) — §6 |
| §4 근본 재설계 (범위는 유지) | 사용자 결정 (라운드 2 후) |
| 발단 | 이 리포에서 실제 발생 — 세션 지시가 Bash 쓰기를 요구했고 `docs/superpowers/specs/` 문서 3개가 게이트를 통과하지 않은 채 커밋됨 |

**plan 으로 넘기는 미결**

| # | 무엇 |
|---|---|
| 1 | §7 임계의 **값**. 설계는 기준선 측정 프로토콜만 정한다 — 임계는 현재(matcher 있는) 비용을 잰 뒤 그 증분으로 확정한다 |
| 2 | `FileChanged` 가 대화형 세션에서 발화하는지 — 발화하면 §11 의 기각 근거가 바뀐다 |
| 3 | qg·project-init 의 `matcher: "Bash"` 형제 블록을 통합할지 존치할지 (§3.4 가 판단 기준을 정한다) |

## 목차

- [1. 문제](#1-문제)
- [2. 열거는 여섯 곳에 있다](#2-열거는-여섯-곳에-있다)
- [3. 결정 — 세 층을 없앤다](#3-결정--세-층을-없앤다)
- [4. 감지 모듈 `shared/writewatch/`](#4-감지-모듈-sharedwritewatch)
- [5. 세 플러그인 적용](#5-세-플러그인-적용)
- [6. 이 설계에서 분리한 것 — `/cancel-review`](#6-이-설계에서-분리한-것--cancel-review)
- [7. 비용 — 기준선을 먼저 잰다](#7-비용--기준선을-먼저-잰다)
- [8. Acceptance Criteria](#8-acceptance-criteria)
- [9. 고칠 파일](#9-고칠-파일)
- [10. 검증 계획](#10-검증-계획)
- [11. 기각한 대안](#11-기각한-대안)
- [12. 위험](#12-위험)

## 1. 문제

세 플러그인이 같은 모양의 훅을 하나씩 가진다.

| 플러그인 | 훅 | 열거 밖으로 새면 |
|---|---|---|
| spec-distill | `hooks/spec-write-validator.py` | Law 1 구조 검증이 실행되지 않는다 |
| quality-gates | `hooks/post-tool-use-session-tracker.py` | 변경 파일이 `/qg` scope 에 안 잡혀 게이트가 빈 scope 로 clean 을 보고한다 |
| project-init | `hooks/docs-lint.py` | docs 컨벤션 검사가 실행되지 않는다 |

세 실패 모두 **조용하다**. 훅이 안 돌았다는 신호가 어디에도 남지 않고, 게이트가 통과한 것과
게이트가 아예 안 걸린 것이 사용자에게 같은 모양으로 보인다.

**복원되는 범위를 정확히 적는다.** spec-distill 에서 이 설계가 되돌리는 것은 **Layer 1 구조
검증**이다. 자동 리뷰 arm 은 부분적으로만 돌아온다 — `should_arm` 이
`(not is_armed) ∧ (not is_born)` 이고 `is_born` 은 `git ls-files --error-unmatch` 라
**`git add` 만 된 문서도 born 으로 본다**(docstring 명시). 따라서 이미 tracked 인 문서를
`sed -i` 로 고치면 검증은 돌아오고 arm 은 붙지 않는다. 이는 v0.25.0 arm-once 의 의도된
계약이고 이 설계는 그것을 바꾸지 않는다. AC5 가 이 갭을 **명시적으로 잰다**.

## 2. 열거는 여섯 곳에 있다

`matcher` 는 `tool_name` 에 매칭된다 (번들 레지스트리 `matcherMetadata.fieldToMatch`).
그러나 **`hooks.json` 은 열거의 절반일 뿐이다.**

| 플러그인 | ① `hooks.json` matcher | ② 파이썬 allowlist |
|---|---|---|
| spec-distill | `"Write\|Edit\|MultiEdit"` | `spec-write-validator.py:393` — `if tool_name not in ("Write","Edit","MultiEdit"): return 0` |
| quality-gates | `"Edit\|Write\|MultiEdit"` | `post-tool-use-session-tracker.py:22` — `TRACKED_TOOLS` (54행 소비) |
| project-init | `"Write\|Edit\|MultiEdit"` | `docs-lint.py:32` — `TARGET_TOOLS` (459행 소비) |

**둘 중 하나만 지우면 아무것도 고쳐지지 않는다.** matcher 만 지우면 훅은 발화하되 첫 줄에서
`return 0` 한다. "matcher 키가 없다"만 잠그는 락은 **결함이 살아 있는 상태에서 통과**한다 —
이 설계의 판본 1 이 정확히 그 상태였고 리뷰 라운드 1 이 적발했다.

도구 열거는 **공간과 시간 양쪽에 fail-open** 이다. 오늘 빠뜨린 도구(Bash)에 열려 있고,
내일 추가될 도구는 열거 자체가 불가능하다. CLAUDE.md 가 agent frontmatter 에서 denylist 를
금지하는 논리와 같다 — 그 논리가 훅 계층에는 적용되지 않고 있었다.

## 3. 결정 — 세 층을 없앤다

### 3.1 층 ① — `matcher` 키 삭제

세 `hooks.json` 에서 해당 훅의 `"matcher"` 키를 삭제한다. 실측으로 확정된 의미는
"모든 도구 호출에 발화"이며, `exit 2 → 모델에게 stderr 즉시` 라는 기존 집행 의미는 보존된다.

### 3.2 층 ② — 파이썬 allowlist 삭제

`tool_name` 으로 거르지 않는다. `tool_name` 과 `agent_id` 는 **진단 메시지에만** 쓴다 —
subagent 가 쓴 문서도 같은 디스크의 같은 문서이므로 필터가 아니라 라벨이다.

### 3.3 층 ③ — payload 분기 삭제 (판본 2 의 결함)

판본 2 는 `payload.tool_input.file_path` 가 있으면 그 경로를, 없으면 감지 모듈을 쓰는
분기를 뒀다. **틀렸다 — `Read` 의 `tool_input` 도 `file_path` 다.** 그 분기 아래에서는
스코프 문서를 **읽기만 해도** Layer 1 이 돌고, 미커밋이면 단순 읽기가 arm-once 의 1회를
소비하며, qg 는 읽은 파일을 전부 scope 에 넣는다.

교훈은 "`Read` 를 예외 처리하라"가 아니다. **payload 를 보고 "이 호출이 무엇을 했나"를
추론하는 순간 도구 열거로 되돌아간다** — `Read` 를 빼면 `Glob` 이, 그 다음엔 오늘 없는 도구가
남는다. 판본 1 의 결함이 자리만 옮긴 것이었다.

그래서 분기를 없앤다:

```
paths, status = writewatch.changed(ledger_path, pathspec=None)
```

payload 는 읽지 않는다. 읽기 도구는 내용을 바꾸지 않으므로 **자연히 아무것도 반환하지
않는다** — 예외 규칙이 아니라 구조적 귀결이다. 코드 경로가 하나가 되고, 그 하나가 모든
도구·모든 에이전트·모든 미래 도구를 덮는다.

### 3.4 형제 `matcher: "Bash"` 블록

qg 와 project-init 의 `hooks.json` 에는 같은 `PostToolUse` 배열 안에 `matcher: "Bash"` 로
**다른 스크립트**(`post-tool-use.py`)를 도는 두 번째 블록이 각각 있다. 이 설계는 그 블록을
**건드리지 않는다** — 다른 책임(git 명령 검증)이고 이 결함과 무관하다.

**대가를 명시한다**: matcher 를 지우면 Bash 호출 한 번에 그 플러그인의 훅이 둘 돈다.
§7 의 측정은 이 이중 발화를 포함한 상태로 잰다. 통합 여부는 미결 3 으로 넘긴다.

## 4. 감지 모듈 `shared/writewatch/`

### 4.1 무엇을 답하나

한 가지 질문에만 답한다: **"이 프롬프트의 기준선 이후로 내용이 바뀐 파일은 무엇인가."**

arm 여부·리뷰 여부·상한·스코프 정책은 답하지 않는다. 소비자별 규칙이 이 모듈에 들어오면
공유 계약이 아니라 세 정책의 합집합이 된다 (판본 2 의 `bootstrap` 파라미터가 그 실패였다).

```
writewatch.baseline(ledger_path, pathspec=None) -> status          # UserPromptSubmit
writewatch.changed(ledger_path, pathspec=None) -> (list[str], status)   # PostToolUse
```

`status ∈ {"ok", "undetermined"}`.

### 4.2 어떻게 답하나 — git 으로 좁히고 해시로 판정한다

두 단계다. **git 은 후보를 좁히는 데만 쓰고, "바뀌었나"는 내용 해시가 판정한다.**

```
git status --porcelain -z -uall --no-optional-locks -- :(top,literal)<pathspec>
```

| 플래그 | 왜 필요한가 |
|---|---|
| `-z` | 기본 출력은 `core.quotePath` 인용과 개행이 든 파일명에서 깨진다. NUL 구분이 그 둘을 함께 없앤다 |
| `-uall` | 기본 `-unormal` 은 **untracked 디렉토리를 접는다**. 새 하위폴더의 문서가 디렉토리 경로로 반환되고 `.md` 검사에 걸려 조용히 사라진다 |
| `--no-optional-locks` | 없으면 `git status` 가 인덱스를 갱신하며 `index.lock` 을 잡는다 — 매 도구 호출마다, 세 플러그인이, 사용자의 git 명령과 동시에 |
| `:(top,literal)` | pathspec 을 리포 루트에 고정하고 wildmatch 를 끈다. 없으면 하위 디렉토리에서 조용히 빈 결과가 나온다 — `arm_ledger.is_born` 이 이미 한 번 고친 결함이다 |

**출력 파싱**: `XY <path>\0` 이 기본이고, rename/copy(`R`·`C`)는 `XY <to>\0<from>\0` 로
**필드가 하나 더 온다**. 그 여분을 소비하지 않으면 다음 엔트리 파싱이 어긋난다. 도착 경로만
취한다. 디코딩은 `text=False` 로 받아 `decode("utf-8", "surrogateescape")` — 프로세스 locale 에
의존하면 이 리포가 이미 겪은 `UnicodeDecodeError` 클래스가 재발한다.

**판정**: 후보 각각의 `sha256` 을 계산해 원장의 값과 비교한다. 다르거나 원장에 없으면 변경.

경로 집합이 아니라 **내용 해시**인 이유: 이미 dirty 인 파일을 다시 쓰면 경로 집합은 그대로라
차집합이 비고, 그 순간 조용한 무발동 — 즉 **고치려는 결함 그 자체**가 재현된다 (판본 2 의 결함).

### 4.3 기준선은 `UserPromptSubmit` 이 찍는다

`PostToolUse` 는 쓰기 **뒤에** 돈다. 그래서 첫 도구 호출 시점에 원장을 만들면 그 호출의
쓰기가 기준선 안에 들어가 영영 보이지 않는다. 판본 2 는 이 창을 "미커밋 = arm 대상" 이라는
등식으로 덮으려 했는데 **그 등식이 거짓이다** — `is_born` 은 staged 파일도 born 으로 보므로
`not is_born`(untracked 만)과 `git status` 의 dirty 집합(tracked-modified 포함)은 일치하지
않는다.

기준선을 **도구가 돌기 전**으로 올리면 등식이 필요 없다.

| 이벤트 | 하는 일 |
|---|---|
| `UserPromptSubmit` | `baseline()` — 후보 집합의 현재 해시를 원장에 기록. 프롬프트마다 갱신 |
| `PostToolUse` | `changed()` — 후보를 다시 해시해 원장과 비교. 원장은 갱신한다 |

`SessionStart` 를 쓰지 않는 이유: CLAUDE.md 가 `SessionStart` 훅을 **read-only 조언자**로
못 박았고 mutate 를 금지한다. `UserPromptSubmit` 은 그 제약 밖이며, spec-distill 은 이미
이 이벤트에 훅을 가지고 있다.

### 4.4 반환 규약

- **절대경로.** `git rev-parse --show-toplevel` 로 리포 루트를 얻어 `git status` 의
  루트-상대 출력을 절대화한다.
- **정렬.** 키는 절대경로 문자열. 호출 간 순서가 흔들리면 §5.1 의 "첫 문서" 선택이
  비결정적이 된다.
- **필터 없음.** 확장자·디렉토리 규칙은 소비자가 건다 (§5.2).

### 4.5 판정 불능은 `undetermined` 다 — 세 번째 상태

git 부재·리포 밖·타임아웃·원장 판독 실패·기준선 부재는 `(빈 목록, "undetermined")` 를
반환하고 stderr 로 사유를 남긴다.

**"스코프 전체를 바뀐 것으로 간주"는 하지 않는다.** spec-distill 의 Layer 1 검증은 arm
게이트보다 **먼저** 돌고 원장이 묶지 않는다 — 스코프 전체를 돌려주면 손대지도 않은 문서의
검증 실패가 매 도구 호출마다 모델을 차단하고, 문서당 파서 subprocess 여러 개가 §7 예산을
degrade 경로에서 파괴한다. 조용한 무발동을 시끄러운 무한 차단으로 바꾸는 교환이다.

`undetermined` 는 under-review 방향이지만 **조용하지 않다.** 소비자는 검증도 arm 도 하지 않고
advisory 만 낸다:

> `[<plugin>] 이번 도구 호출에서 파일 변경을 판정하지 못했다 (사유: <reason>). 이 스코프의 파일을 썼다면 이번에는 게이트가 걸리지 않았다.`

원래 결함과의 차이는 방향이 아니라 **가시성**이다. 원래 결함은 아무 흔적을 남기지 않았다.

### 4.6 원장의 자리 — 경로는 소비자가 준다

`ledger_path` 는 **인자로 받는다.** 모듈이 계산하지 않는다.

세 플러그인의 state root 계약이 다르기 때문이다 — spec-distill 은 git-aware
(`git rev-parse --git-common-dir`), quality-gates 는 payload cwd 상대이며 그 파일의
docstring 이 *"그 둘은 서로 다른 계약"* 이라고 명시한다. 공유 모듈이 하나를 고르면 다른
쪽이 워크트리에서 어긋난다.

파일은 `<consumer state root>/<session-id>/writewatch.local.md` 에 두고 **경로와 16진
해시만** 담는다 (secret 없음).

**project-init 에는 정리 경로가 없다.** `hooks.json` 에 `PostToolUse` 만 있고, 플러그인
전체에 `SessionEnd`·`session_id` 참조가 **0건**이다. 따라서 다음을 새로 만든다 (§9):

- session-id 해석 (env-first 리졸버 — **형제 플러그인의 사본이 아니라 자기 계약으로** 신규)
- `UserPromptSubmit` 훅 (기준선)
- `SessionEnd` 훅 (원장 삭제)

session-id 를 해석하지 못하면 원장을 만들지 않고 `undetermined` 로 떨어진다 — 정리되지 않는
파일을 만드느니 그 호출에서 판정을 포기한다.

**동시 쓰기**: 원장은 read-modify-write 이고, subagent 병렬 도구 호출에서 같은 파일에
동시 접근이 가능하다. 같은 디렉토리 임시 파일 + `os.replace` 로 원자 교체하고, 손실된
갱신은 다음 호출에서 해시 비교로 자연 복구된다 (해시는 절대값이지 증분이 아니다).

### 4.7 배포 방식

정본은 `shared/writewatch/writewatch.py`, 각 플러그인의 `scripts/writewatch.py` 는 상대
심볼릭 링크. 설치 시점에 실제 파일로 역참조된다 (2026-08-18 실측).

`shared/README.md` 의 **import 형제 사본** 계약은 모듈이 **풀린 디렉토리**에 사본을 요구한다.
세 훅이 모두 `sys.path.insert(0, parents[1]/"scripts")` 를 하므로 모듈은 `scripts/` 에서
풀리고 **배포 심볼릭 링크가 이미 그 요구를 만족한다.** `hooks/` 에 사본을 추가하면
`test_no_new_duplication.sh` 가 설명해야 할 새 중복이 된다 — 만들지 않는다.

다만 그 만족은 **세 줄의 `sys.path.insert` 에 의존한다.** L6 이 그 세 줄을 잠근다.

## 5. 세 플러그인 적용

### 5.1 spec-distill — 한 호출당 arm 하나

`writewatch` 가 문서 N 개를 돌려줘도 **arm 은 하나만 붙는다.** `write_state` 가
`PENDING_RE.sub("", body)` 로 이전 pending 을 지우고 새 블록을 붙이므로, `pending_review:`
블록이 정확히 하나라는 것이 state 포맷의 불변식이다. 순진하게 순회하면 마지막 하나만 arm
되고 나머지는 **조용히 사라진다** — 고치려는 결함의 재생산이다.

| | |
|---|---|
| **Layer 1 구조 검증** | 반환된 문서 중 `resolve_mode` 가 spec/design 으로 판정한 **전부**. 검증은 state 를 안 쓰므로 상한이 없다 |
| **arm** | `should_arm` 이 True 인 문서 중 **정렬 첫 문서** 하나 |
| **나머지** | advisory 로 이름을 나열 — `이번 호출에서 문서 N 개가 바뀌었고 그 중 <first> 에만 리뷰가 붙었다. 나머지: <list>` |

**"정렬 첫"이 아니라 "`should_arm` 이 True 인 것 중 정렬 첫"인 이유**: 위치 규칙만 쓰면
알파벳 첫 문서가 born 이거나 이미 armed 일 때 arm 이 **아무 데도** 붙지 않고, 뒤의 미커밋
문서가 굶는다. 자격 규칙이 먼저다.

**Layer 1 실패**: 실패 사유를 모두 모아 `emit_block` 을 **한 번만** 호출한다. 루프마다
부르면 stdout 에 JSON 이 여러 개 찍혀 훅 출력이 깨진다. 첫 문서 실패로 조기 return 하지
않는다 — 나머지 문서의 검증 결과가 사라진다.

### 5.2 소비자별 필터와 상한

`writewatch` 는 필터를 걸지 않는다. 소비자가 **자기 기존 규칙을 그대로** 적용한다.

| 플러그인 | `pathspec` | 반환 목록 필터 | 출력 상한 |
|---|---|---|---|
| spec-distill | `docs/superpowers/specs/` | 기존 `resolve_mode` | `emit_block` 1회 (§5.1) |
| quality-gates | 없음 (리포 전체) | 없음 — 기존 동작과 동일 | 없음 (scope 는 append-only 집합이라 포맷 불변식이 없다) |
| project-init | 없음 (리포 전체) | 기존 `TARGET_RELPATHS`(정확집합 4) + `is_charter_doc`(접두 규칙) | `emit()` 1회 |

quality-gates 의 `post-tool-use-session-tracker.py` 에는 **스코프 규칙이 없다** — payload 의
`file_path` 를 절대화해 기록할 뿐이다. project-init 의 `docs-lint.py` 는 pathspec 이 아니라
정확집합 + 접두 규칙을 쓴다. 두 사실 모두 판본 2 가 잘못 서술했고 리뷰가 적발했다.

**`emit()` 1회는 project-init 에도 적용된다.** `docs-lint.py:91` 의 `emit()` 은 호출마다
JSON 하나를 찍고 현재 모든 경로에서 정확히 한 번 불린다. 파일마다 부르면 stdout 이 깨진다 —
판본 2 는 이 규칙을 spec-distill 에만 걸었다.

각 플러그인의 kill switch 는 최우선으로 존중된다 — `writewatch` 는 kill switch 검사 **뒤에**
호출된다.

## 6. 이 설계에서 분리한 것 — `/cancel-review`

`/spec-distill:cancel-review` 부활은 이 설계에서 뺀다 (사용자 결정, 라운드 1 후).

1. **session-id 획득 경로가 미지정이었고, 그것이 v0.25.0 삭제 근거 (d) 그 자체다.**
   `arm_ledger` CLI 는 `<sid>` 를 인자로 요구하고 `state_path.py` 의 CLI 경로는 env 에서만
   sid 를 푼다. sid 가 갈리면 cancel 이 훅이 읽지 않는 파일에 쓰고 **성공을 보고한다**.
2. **`--reset` 은 tracked 문서에 no-op 다.** `should_arm` 의 `is_born` conjunct 를
   `unmark-reviewed` 가 되돌리지 못한다.

둘 다 sid 해석을 정면으로 다뤄야 풀린다. 그때 §11 의 마지막 항목대로 **기존 kill switch 로
왜 부족한가**를 먼저 기각해야 한다.

## 7. 비용 — 기준선을 먼저 잰다

matcher 를 지우면 훅이 **모든 도구 호출**에 돈다. Bash 호출에서는 §3.4 의 형제 블록까지
합쳐 훅이 둘 돈다. 비용은 `python3` 프로세스 시작 + `git status` 1회 + 후보 해시다.

**임계 값을 설계가 정하지 않는다.** 판본 2 는 "턴당 1.5초"를 적었는데 **유도가 없었고**,
문서 자신의 산술대로면 달성 불가라 후퇴가 미리 처방된 상태였다. 근거 없는 수를 임계로 쓰면
측정이 결론을 확인하는 의식이 된다.

대신 **측정 프로토콜을 정한다.**

| 무엇 | 어떻게 |
|---|---|
| 기준선 | **현재 코드**(matcher 있는 상태)의 턴당 누적 훅 시간 |
| 비교군 | 이 설계 적용 후 같은 시나리오 |
| 시나리오 | 도구 호출 30회 고정 — Read 20 · Bash 5 · Write 3 · Grep 2 |
| 지표 | 플러그인별 합 **과** 턴 벽시계 **둘 다** 기록 (병렬/직렬 여부가 이 차이로 드러난다) |
| 측정 방법 | 측정 전용 `hooks.json` 사본에서 `command` 를 `/usr/bin/time -p` 로 감싸고 그 stderr 를 파일로 리다이렉트 |

**측정 래퍼를 배포본에 넣지 않는다.** `/usr/bin/time -p` 는 stderr 에 쓰는데, §3.1 이 밝힌
대로 spec-distill 의 집행 채널이 "exit 2 → stderr 가 모델에게"다. 래퍼가 차단 사유를
오염시킨다. 그리고 `/usr/bin/time` 은 비-macOS 에서 보장되지 않으므로, 부재 시 측정을
**실패로 보고**하고 추정치를 만들지 않는다.

**임계 확정 절차 (미결 1)**: 증분이 기준선의 3배를 넘거나 턴 벽시계 증분이 1초를 넘으면
후퇴를 **검토**한다 — 이 두 수는 임계가 아니라 **논의를 여는 방아쇠**이고, 실제 임계는 측정
결과를 보고 사용자가 정한다.

**후퇴안**: 층 ①(matcher 삭제)만 되돌려 `Write|Edit|MultiEdit|Bash` 로 열거하되 층 ②·③은
유지한다 — 그쪽은 비용이 아니라 정확성이다.

**후퇴가 남기는 구멍은 현재형이다.** `Write|Edit|MultiEdit|Bash` 는 오늘 존재하는
`NotebookEdit` 와 MCP 파일쓰기 도구(`mcp__*`)를 열거 밖에 둔다. 미래 도구만의 문제가 아니다.
후퇴하면 이 사실을 README 와 CHANGELOG 에 **그 이름 그대로** 적는다.

## 8. Acceptance Criteria

각 AC 옆의 괄호는 **그것을 재는 수단**이다 (§10.1 락 번호 또는 §10.3 행동 케이스 번호).

| # | 기준 | 재는 것 |
|---|---|---|
| AC1 | 세 `hooks.json` 의 해당 훅 항목이 존재하고, 그 항목에 `matcher` 키가 없다 | L1 |
| AC2 | 세 훅 스크립트에 `tool_name` 기반 allowlist 가 없다 | L2 |
| AC3 | 세 훅이 payload 의 `file_path` 를 **읽지 않는다** (층 ③) | L3 |
| AC4 | Bash heredoc 으로 **untracked** 스코프 문서를 쓰면 Layer 1 이 돌고 `pending_review:` 가 기록된다 | E1 |
| AC5 | Bash heredoc 으로 **tracked** 스코프 문서를 고치면 Layer 1 은 돌고 arm 은 붙지 않는다 (§1 의 의도된 갭) | E2 |
| AC6 | **이미 dirty 인** 문서를 Bash 로 다시 쓰면 그 편집도 감지된다 | E3 |
| AC7 | 스코프 문서를 `Read` 로 읽기만 하면 검증도 arm 도 scope 등록도 lint 도 일어나지 않는다 | E4 |
| AC8 | Layer 1 이 실패하면 exit 2 로 사유가 나가고 `emit_block` 호출은 **1회**다 | L5 · E5 |
| AC9 | Bash 로 쓴 파일이 `/qg` 세션 scope 에 들어간다 | E6 |
| AC10 | subagent 가 Bash 로 쓴 스코프 문서도 AC4 를 만족한다 | E7 |
| AC11 | 한 Bash 호출이 문서 3개를 쓰면 셋 다 Layer 1 을 받고, arm 은 `should_arm` True 중 정렬 첫 하나, 나머지 둘의 이름이 advisory 에 나온다 | L4 · E8 |
| AC12 | git 부재에서 `(빈 목록, "undetermined")` + advisory, 검증·arm 없음 | L7 · E9 |
| AC13 | kill switch 가 켜지면 `writewatch` 가 호출되지 않는다 | L8 |
| AC14 | `git status` 파싱이 `-z` rename 여분 필드·인용·개행·비-UTF-8 바이트를 올바르게 처리한다 | L9 · E10 |
| AC15 | 새 하위 디렉토리 안의 문서가 `-uall` 로 파일 단위로 반환된다 | E11 |
| AC16 | project-init 에 session-id 리졸버·`UserPromptSubmit`·`SessionEnd` 가 있고 세션 종료 시 원장이 삭제된다 | L10 · E12 |
| AC17 | `writewatch` 정본이 `shared/` 에 있고 세 배포 지점이 심볼릭 링크이며 세 훅에 `sys.path.insert` 가 있다 | L6 |
| AC18 | 세 `plugin.json` bump + 각 CHANGELOG 항목 + 세 README "Hooks Installed" 갱신 | L11 |
| AC19 | §7 기준선·비교군 측정값이 CHANGELOG 에 기록된다 (후퇴 여부와 무관하게) | L12 |

## 9. 고칠 파일

| 파일 | 무엇 |
|---|---|
| `shared/writewatch/writewatch.py` | 신규 — 정본 |
| `plugins/{spec-distill,quality-gates,project-init}/scripts/writewatch.py` | 신규 — 상대 심볼릭 링크 |
| `plugins/{spec-distill,quality-gates,project-init}/hooks/hooks.json` | `matcher` 삭제 (층 ①) + `UserPromptSubmit` 등록 |
| `plugins/spec-distill/hooks/spec-write-validator.py` | 393행 allowlist 제거 · payload 분기 제거 · §5.1 |
| `plugins/spec-distill/hooks/pending-review-reminder.py` | 기존 `UserPromptSubmit` 훅에 `baseline()` 호출 추가 |
| `plugins/quality-gates/hooks/post-tool-use-session-tracker.py` | `TRACKED_TOOLS` 제거 · payload 분기 제거 |
| `plugins/quality-gates/hooks/user-prompt-submit-baseline.py` | 신규 — 기준선 |
| `plugins/project-init/hooks/docs-lint.py` | `TARGET_TOOLS` 제거 · payload 분기 제거 · `emit()` 1회 |
| `plugins/project-init/scripts/state_path.py` | 신규 — session-id 리졸버 |
| `plugins/project-init/hooks/user-prompt-submit-baseline.py` | 신규 — 기준선 |
| `plugins/project-init/hooks/session-end-cleanup.py` | 신규 — 원장 정리 |
| `shared/tests/fixtures/hookprobe/` | 신규 — 실측 프로브 (§10.3) |
| 세 `plugin.json` · 세 `CHANGELOG.md` · 세 `README.md` | bump · 항목 · Hooks Installed |
| 회귀 테스트 | §10 |

## 10. 검증 계획

### 10.1 회귀 락

각 락은 **양의 짝과 음의 짝을 함께** 가진다. 음의 락(`X 가 없다`)만 두면 대상을 통째로
삭제해도 통과한다 — 그 상태가 최대 fail-open 이다. 예외를 두지 않는다.

| 락 | 양 (존재) | 음 (부재) |
|---|---|---|
| L1 | 세 `hooks.json` 에 해당 훅 항목이 있고 기대한 스크립트 경로를 가리킨다 | 그 항목에 `matcher` 키가 없다 |
| L2 | 세 훅이 `writewatch.changed` 를 호출하고 반환값을 소비한다 | 세 훅에 `tool_name` allowlist 가 없다 |
| L3 | 세 훅이 `writewatch` 결과만으로 대상을 정한다 | 세 훅에 `tool_input`·`file_path` 참조가 없다 |
| L4 | arm 대상이 `should_arm` True 중 정렬 첫이고 나머지가 advisory 에 나열된다 | arm 호출이 루프 안에 없다 |
| L5 | `emit_block`·`emit` 이 각 훅에서 정확히 한 번 도달 가능하다 | 그 호출이 루프 안에 없다 |
| L6 | 세 배포 지점이 `shared/writewatch/` 심볼릭 링크이고 세 훅에 `sys.path.insert` 가 있다 | `hooks/` 에 사본이 없다 |
| L7 | `undetermined` 분기가 빈 목록 + advisory 를 낸다 | 그 분기가 후보 목록을 반환하지 않는다 |
| L8 | kill switch 검사가 `writewatch` 호출을 **지배한다** (호출 지점마다 위쪽) | kill switch 뒤에 조기 호출이 없다 |
| L9 | 파서가 `-z`·`-uall`·`--no-optional-locks`·`:(top,literal)` 네 플래그를 모두 쓴다 | 넷 중 어느 것도 빠지지 않는다 |
| L10 | project-init 에 세 신규 파일이 있고 `hooks.json` 이 두 이벤트를 등록한다 | — 해당 없음(양만으로 충분: 존재가 곧 불변식) |
| L11 | 세 `plugin.json` 버전이 main 보다 높고 CHANGELOG 에 해당 버전 항목이 있다 | — 해당 없음 |
| L12 | CHANGELOG 에 기준선·비교군 측정값 두 수가 있다 | — 해당 없음 |

L10~L12 는 음의 짝이 없다 — 셋 다 "존재"가 곧 불변식이라 부재 명제가 성립하지 않는다.
**이 예외를 여기 적는 이유는, 판본 2 가 같은 예외를 근거 없이 세 곳에 뒀다가 적발됐기
때문이다.** 근거 없는 `—` 는 두지 않는다.

### 10.2 이빨 확인

각 락은 **mutation 으로 이빨을 증명한다.** 네 축으로 흔든다 — 삭제·추가·반전·형태 변경.

| 락 | mutation | 기대 |
|---|---|---|
| L1 양 | `hooks.json` 에서 훅 항목을 통째로 삭제 | RED |
| L1 음 | `matcher` 키를 되살린다 | RED |
| L2 음 | `if tool_name not in (...)` / `TRACKED_TOOLS` / `TARGET_TOOLS` 를 되살린다 | RED |
| L2 양 | `writewatch` 호출은 두고 반환값을 버린다 | RED |
| L3 음 | `file_path = payload["tool_input"].get("file_path")` 분기를 되살린다 | RED |
| L4 | 자격 검사를 빼고 위치만으로 첫 문서를 고른다 | RED |
| L4 | advisory 에서 나머지 문서 이름 나열을 지운다 | RED |
| L5 | `emit_block` 을 루프 안으로 옮긴다 | RED |
| L6 | 심볼릭 링크를 바이트 동일 사본으로 바꾼다 | RED |
| L6 | `sys.path.insert` 줄을 지운다 | RED |
| L7 | degrade 반환을 후보 전체로 되돌린다 | RED |
| L7 | `except` 절을 좁힌다 (`OSError` → `FileNotFoundError`) | RED |
| L8 | kill switch 검사를 `writewatch` 호출 **뒤로** 옮긴다 | RED |
| L9 | `-uall` 하나만 지운다 (네 플래그 각각에 대해 반복) | RED |

`except` 절 좁히기가 있는 이유: 이 플러그인이 실제로 두 번 겪은 실패 모드다
(`UnicodeDecodeError ⊄ OSError`, `ImportError` vs `Exception`). 방향 반전만 잠그면 좁히기는
통과한다.

`PYTHONDONTWRITEBYTECODE=1` 로 돌린다 — 같은 길이 변이는 stale `.pyc` 를 넘지 못해 거짓
GREEN·거짓 RED 를 둘 다 낸다.

**양성 대조**: mutation 전 스위트가 GREEN 인지 먼저 확인한다. RED 자체는 계측기가 살아
있다는 증거가 아니다.

### 10.3 행동 케이스 — 프로브를 리포에 커밋한다

정적 검사로 확인할 수 없는 AC 는 헤드리스 턴으로 잰다. §8 이 각 AC 옆에 케이스 번호를
달았고, 아래가 그 목록이다.

| # | 무엇을 재나 |
|---|---|
| E1 | Bash heredoc → untracked 문서 → Layer 1 실행 + pending 기록 |
| E2 | Bash `sed -i` → tracked 문서 → Layer 1 실행 + arm 없음 |
| E3 | 같은 dirty 문서를 Bash 로 **두 번째** 편집 → 두 번째도 감지 |
| E4 | 스코프 문서를 `Read` 만 → 세 플러그인 모두 무반응 |
| E5 | Layer 1 실패 문서 → exit 2 + stdout JSON 정확히 1개 |
| E6 | Bash 로 쓴 파일이 `/qg` scope 파일에 등장 |
| E7 | subagent 의 Bash heredoc → E1 과 동일 결과 |
| E8 | 한 Bash 호출로 문서 3개 → 검증 3, arm 1, advisory 에 나머지 2 |
| E9 | `PATH` 에서 git 제거 → `undetermined` advisory + 무발동 |
| E10 | 파일명에 공백·개행·비-UTF-8 바이트 + rename → 파싱 정확 |
| E11 | 새 하위 디렉토리 안의 문서 → 파일 경로로 반환 |
| E12 | 세션 종료 → project-init 원장 삭제 |

프로브 플러그인과 재현 커맨드를 `shared/tests/fixtures/hookprobe/` 에 **커밋한다.**
세션 scratchpad 에만 두면 `/compact` 이후나 새 세션의 구현자가 이 절을 실행할 수 없다 —
설계는 인계되는데 근거와 검증 절차가 인계되지 않는다.

`--permission-mode acceptEdits` 없이는 편집이 rc 0 으로 조용히 죽으므로 반드시 붙인다.
임시 디렉토리는 만든 직후 `pwd -P` 로 한 번 정규화한다 — macOS 의 `/tmp` 는 `/private/tmp`
심볼릭 링크라 경로 포함 검사가 조용히 무너진다.

### 10.4 선재 RED

작업 전에 세 플러그인 테스트 스위트의 기준선을 캡처한다. quality-gates 에는 main 에
선재 RED 가 있는 것으로 기록돼 있어, 그것을 이번 변경의 회귀로 오인하지 않기 위해서다.

## 11. 기각한 대안

| 대안 | 왜 기각했나 |
|---|---|
| **matcher 에 `Bash` 추가 + 명령어 파싱** | `cat >`·`tee`·`sed -i`·`>>`·`printf`·`perl -i`·`mv`·`git apply` … 열거를 하나 빠뜨릴 때마다 조용한 fail-open. 고치려는 결함을 한 층 아래로 옮긴다 |
| **payload 의 `file_path` 로 분기** | `Read` 의 `tool_input` 도 `file_path` 다. 읽기만 해도 검증·arm 이 돈다. `Read` 를 빼면 `Glob` 이, 그 다음엔 오늘 없는 도구가 남는다 — 도구 열거의 재발 (§3.3) |
| **원장을 경로 집합으로** | 이미 dirty 인 파일의 재편집을 못 본다. 조용한 무발동이 그대로 재현된다 (§4.2) |
| **첫 도구 호출에서 기준선** | `PostToolUse` 가 쓰기 뒤에 돌아 그 쓰기가 기준선에 삼켜진다. "미커밋 = arm 대상" 등식으로 덮으려 했으나 `is_born` 이 staged 도 born 으로 보므로 등식이 거짓 (§4.3) |
| **`SessionStart` 에서 기준선** | CLAUDE.md 가 `SessionStart` 훅을 read-only 조언자로 못 박고 mutate 를 금지한다 |
| **`PostToolBatch` 로 교체** | matcher 가 없어 열거 문제는 사라지지만 exit 2 가 "루프 정지 + stderr 는 사용자에게만"이라 Layer 1 의 모델 피드백을 잃는다 |
| **`FileChanged` 로 파일 감시** | 층위는 가장 정확하나 집행력이 없고(exit≠0 은 사용자에게만), 실측에서 matcher 3변형 모두 0건. **부재 증명이 아니므로** 미결 2 로 남긴다 |
| **`Stop` 훅 턴-끝 전수 검사** | qg·project-init 에 `Stop` 훅이 없어 새 훅 둘이 필요하고, 피드백이 턴 끝으로 밀린다 |
| **`PreToolUse` 로 Bash 쓰기 차단** | 명령어 파싱이 필요해 첫 항목과 같은 fail-open 을 물려받고, 오탐이 무관한 명령을 막는다 |
| **`os.scandir` 전수 스캔** | 리포 전체 스코프에서 제외 규칙(`.git`·`node_modules`·`.gitignore`)을 손으로 만들어야 하고 그 목록이 **또 하나의 열거**가 된다. git 은 그 규칙을 이미 안다 |
| **degrade 시 후보 전체 반환** | Layer 1 이 arm 게이트보다 먼저 돌고 원장이 안 묶으므로 손대지 않은 문서가 매 호출마다 모델을 차단한다 (§4.5) |
| **`bootstrap` 같은 소비자 정책 파라미터** | 공유 계약이 세 정책의 합집합이 된다. 반환은 사실만, 정책은 소비자에 (§4.1) |
| **문서로만 "spec 문서는 Write 로 쓰라"** | 이 리포는 프롬프트 수준 분리를 집행으로 인정하지 않는다 (Law 2 의 논리). 이번 사건 자체가 그 규정이 세션 지시에 밀린 사례다 |
| **`/cancel-review` 대신 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`** | v0.25.0 이 사전 옵트아웃의 **지정 대체재**로 명시한 스위치다. §6 분리에 따라 후속 설계가 먼저 결론지어야 한다 — 커맨드가 이 스위치보다 무엇을 더 주는지 답하지 못하면 커맨드는 불필요하다 |

## 12. 위험

| # | 위험 | 완화 |
|---|---|---|
| R1 | 훅이 모든 도구 호출에 돌아 턴이 느려진다 | §7 이 **기준선을 먼저 재고** 임계는 그 결과로 정한다. 근거 없는 수를 임계로 쓰지 않는다 |
| R2 | Bash 호출에서 qg·project-init 의 훅이 둘 돈다 | §7 측정이 이중 발화를 포함한 상태로 잰다. 통합은 측정 후 (미결 3) |
| R3 | `writewatch` 가 조용히 죽어 게이트가 다시 꺼진다 | `undetermined` 가 **반드시 advisory 를 동반**한다. L7 이 양·음 양쪽을 잠근다 |
| R4 | degrade 가 반대 방향의 결함(무한 차단)을 만든다 | `undetermined` 는 빈 목록을 반환한다. L7 mutation 이 후보-전체 복원을 RED 로 잡는다 |
| R5 | 한 호출에 여러 문서가 바뀌어 일부가 조용히 리뷰를 잃는다 | §5.1 이 나머지를 **이름과 함께** 노출한다. L4 가 잠근다 |
| R6 | `UserPromptSubmit` 훅이 실패해 기준선이 없다 | `changed()` 가 `undetermined` 로 떨어지고 advisory 를 낸다. 조용한 무발동이 되지 않는다 |
| R7 | subagent 병렬 호출이 원장을 경합한다 | 원자 교체 + 해시가 절대값이라 손실된 갱신이 다음 호출에서 복구된다 (§4.6) |
| R8 | 세 훅에 같은 코드가 갈라진다 | 정본은 `shared/`, 배포는 심볼릭 링크. L6 이 `sys.path` 전제까지 잠근다 |
| R9 | project-init 원장이 영구 잔존한다 | §4.6 이 리졸버·`SessionEnd` 를 신규 파일로 명시하고 §9·L10 에 올렸다. 해석 실패 시 원장을 만들지 않는다 |
| R10 | 이 설계 문서 자신이 Bash 로 쓰여 게이트를 우회한다 | 이 문서는 Write 도구로 작성했다. 후속 편집도 Write·Edit 로 한다 |
