# 다음 세션 `@` 명령 · Design

> `/new` 다음 첫 줄이 읽을 파일을 붙여 온다.

spec-distill 의 세 proceed 게이트(request-framing · spec-interview · spec-review)가 ①·② 에서 내는
「다음 세션 명령」을 공통 규칙 하나로 묶는다. 다음 세션의 첫 줄이 읽을 파일을 `@` 로 붙여 오게 하고,
읽을 파일이 여럿이어도 같은 규칙으로 넘긴다. 구현 브랜치는 `feature/next-session-at-handoff` 이다.

## Handoff Context

- 입력: 사용자 요청(2026-10-11) — 「interview 마지막에도 framing처럼 "@" 명령을 띄워줘서 무조건 읽게끔
  만들고 싶어 compact나 new 이런거 한 뒤에 다음 세션 명령으로 무조건 처음에 읽게 만들게 하려고 이거
  shared로 만들자」 + 「읽어야 할게 여러개일 수도 있으니 확장성 있게」.
- brainstorming 결정: 이 문서 `## 결정 기록` D1~D6. interview brief 는 없다(사용자가 brainstorming 으로 바로 들어왔다).
- 재결정 규약: confirmed 항목은 근거가 있으면 보고 후 재결정할 수 있고, 임의 변경은 금지다.

## Context / Why

request-framing 은 ① `/new` · ② `/compact` 다음에 `/spec-distill:spec-interview @<seed 경로>` 를 보인다.
다음 세션은 첫 턴에 seed 를 반드시 읽는다. 다만 이 보장은 받는 쪽에서 온다 — spec-interview 의
`## 진입 단계` 2 가 `@` 를 떼고 Read 한다.

spec-interview(`references/finishing.md` B-2·B-3)와 spec-review(`## 게이트`)는 그렇지 않다. ① 은 보존 지시가 긴
`/compact …` 한 줄을 보이고, ② 는 같은 세션에서 바로 다음 skill 로 간다. `/compact` 를 하든 `/new` 를 하든,
다음 세션이 산출물을 처음부터 읽는다는 장치가 없다. 다음 skill(superpowers:brainstorming ·
superpowers:writing-plans)은 외부 플러그인이라 `@` 를 풀지 않는다.

`@` 에 관한 실측은 다음과 같다(헤드리스 `claude -p`, haiku, 도구 Read·Bash·Grep·Glob 차단):

| 입력 | 결과 |
|---|---|
| 평문 `@a.md @b.md 두 파일의 첫 줄을 …` | 두 무작위 표지가 모두 나옴 — **여러 개 첨부됨** (2026-10-11) |
| 평문 `c.md 의 첫 줄을 …` (`@` 없음, 음성 대조) | `NONE` |
| 평문 `@<절대경로>/c.md …` (다른 cwd) | 표지가 나옴 — 절대경로도 첨부됨 (2026-10-11) |
| slash 인자 `/argprobe:echoargs @<파일>` | `$ARGUMENTS` 에 글자 그대로, **첨부 안 됨** (2026-09-10) |
| slash 인자 `@`, 대화형 | 재지 않음 |

## Goals

- G1. 세 게이트의 ①·② 가 같은 모양을 쓴다: 첫 줄 `/new` 또는 `/compact`, 둘째 줄은 ①·② 공통.
- G2. 둘째 줄이 다음 세션 첫 턴에 읽을 파일을 반드시 붙여 온다.
- G3. 읽을 파일이 여럿이어도 규칙과 락을 고치지 않고 넘긴다 — 각 skill 의 경로 목록에 원소만 더한다.
- G4. 규칙의 정본은 하나다(`plugins/spec-distill/references/proceed-gate.md`).

## Non-goals

- spec-interview `## 진입 단계` 2 가 받는 경로 수를 넓히지 않는다(오늘 1).
- 어떤 skill 의 목록에도 원소를 실제로 더하지 않는다(오늘 모두 1개).
- spec-interview 에 brief 커밋을 더하지 않는다. `/new` 는 같은 디렉토리의 파일을 지우지 않는다.
- 리포 `shared/` 에 새 정본을 두지 않는다 — 소비자가 spec-distill 하나뿐이다(D3).

## Constraints

- C1. `shared/entry/check_invocation_surface.py` 축 G 는 skill 문면의 외부 slash 명령(`/superpowers:…`)을 거부한다.
- C2. proceed-gate 계약의 채택자 락(`test_proceed_gate_adopters.sh`)이 요구하는 어휘 넷 — `턴 종료|다음 턴` ·
  `polite stop` · `degrade 채널` · `재결정|반증` — 은 각 채택자의 자기 표면에 남는다.
- C3. C5(spec-interview): 재결정 규약(C4 문장)은 brief 가 아니라 다음 skill 을 부르는 프롬프트에 싣는다.
- C4. 정지 요건(가드 2): 명령을 노출한 턴은 거기서 끝난다.

## 설계

### §1 정본 — `proceed-gate.md` 개정

**Step B 표.** ① 과 ② 를 고정한다.

| # | 뜻 |
|---|---|
| ① | 권장 핸드오프 — `/new` 와 다음 세션 줄을 노출하고 **턴 종료** |
| ② | 차선 핸드오프 — `/compact` 와 같은 다음 세션 줄을 노출하고 **턴 종료** |
| ③ | 수정 필요 — 후속 질문으로 분기 |
| ④ | 멈춤 — 상태 보존하고 종료 |

- 「각 skill 이 채우는 것」의 「①/② 의 핸드오프 종류(`/compact` · `/new` · 바로 진행)와 노출할 명령」을
  「**읽힐 경로 목록과 다음 세션 줄**(`## 다음 세션 명령`)」으로 바꾼다.
- 가드 1 의 「바로 진행 옵션은 다음 단계 진입이다」 문장과 가드 2 의 「바로 진행 옵션은 이 정지 요건의
  **명시적 예외**다」 문단을 지운다. 정지 요건에 예외가 없어진다.

**새 절 `## 다음 세션 명령`** (Step C 앞). 담는 규칙:

1. **두 줄, 따로 입력.** 첫 줄은 `/new`(①) 또는 맨 `/compact`(②)다. 둘째 줄(「다음 세션 줄」)은 ①·② 가 같다.
   `/new` 뒤 같은 줄의 텍스트는 세션 이름이 되고 `/compact` 뒤 텍스트는 요약 지시로만 쓰인다. 그래서
   두 줄을 따로 입력하라는 안내를 명령과 함께 낸다.
2. **읽힐 경로 목록.** 각 skill 은 경로 목록(1개 이상)을 정한다. 첫 원소가 주 산출물이다. 다음 세션 줄은 원소마다
   `@<경로>` 토큰을 하나씩, 공백으로 나눠 줄 맨 앞(slash 형이면 skill 이름 바로 뒤)에 목록 순서대로 둔다.
3. **줄의 모양은 받는 쪽이 정한다.**
   - 받는 쪽이 진입 단계에서 `@` 를 스스로 푸는 skill 이면 `/<plugin>:<skill> @<경로>…` 이다. 받는 쪽마다
     **받을 수 있는 경로 수**를 아래 표에 적고, 목록은 그 수를 넘지 못한다.
   - 그 밖의 받는 쪽(외부 skill)이면 `@` 토큰들로 시작하는 평문 프롬프트다. 토큰 뒤에 부를 skill 과
     그 skill 이 정한 운반 문장을 잇는다. 경로 수 제한이 없다 — 토큰마다 하니스가 첨부한다(실측).
4. **받는 쪽 한도 표.**

   | 받는 쪽 | `@` 를 푸는 자리 | 받을 수 있는 경로 수 |
   |---|---|---|
   | `spec-distill:spec-interview` | `## 진입 단계` 2 | 1 |
   | 외부 skill (평문 줄) | 하니스 첨부 | 제한 없음 |

5. **치환과 거부.** 목록의 모든 원소를 실제 경로로 치환한 뒤 노출한다. 상대경로는 작업 디렉토리 기준이다.
   치환하지 않은 자리표가 하나라도 남거나 경로에 공백이 있으면 노출하지 않는다. 그 사실을 advisory
   한 줄로 내고 멈춘다 — 깨진 줄을 사용자가 실행하면 그것을 잡는 자리가 없다.
6. **Step A 를 모든 원소에.** 원소 하나라도 working-tree 에 없으면 명령을 노출하지 않는다. 없는 경로를 전부
   담아 Step A advisory 를 낸다.
7. **위치 공시.** 명령과 함께 작업 디렉토리 절대경로(`pwd`)를 낸다 — 다른 터미널에서 새 세션을 열 때
   그 디렉토리에서 열어야 상대경로 `@` 가 풀린다.

### §2 채택자

| skill | 읽힐 경로 목록 | 다음 세션 줄 |
|---|---|---|
| request-framing | `[<seed 경로>]` | `/spec-distill:spec-interview @<seed 경로>` (현행) |
| spec-interview | `[<brief-path>]` | 아래 (가) |
| spec-review | `[<spec_path>]` | 아래 (나) |

(가) spec-interview — 지금 ② 호출 프롬프트의 C4 문장 · 순서 문장과 ① `/compact` 템플릿의 글 규칙 구절을 그대로 옮긴다:

> `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로로 Skill spec-distill:spec-review 를 부른다 — brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다. superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다. spec-review 가 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`

(나) spec-review:

> `@<spec_path> 이 설계문서로 Skill superpowers:writing-plans 를 시작하라. confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`

각 skill 의 서술 규칙:
- 다음 세션 줄은 skill 안에서 **한 번만** 정의한다(「다음 세션 줄 — ①/② 공통」 블록).
  ①·② 서술은 첫 줄과 그 블록을 가리킨다.
- ①·② 서술 블록마다 정지 요건 셋을 둔다: 턴 종료(STOP) · 같은 턴에서 다음 skill 을 부르지 않는다 ·
  다음 턴의 사용자 트리거로만 진입한다(정본 「검증」 2 의 리뷰 레이어 요건).

**spec-interview 변경.**
- B-2 옵션 라벨과 설명:
  - ① 「확정하고 /new 후 brainstorming (권장)」 — 확정 후보를 확정으로 바꿔 저장하고, 붙여 넣을 두 줄(`/new` 와 다음 세션 줄)을 보여 준다.
  - ② 「확정하고 /compact 후 brainstorming」 — 같은 두 줄을 첫 줄만 `/compact` 로 보여 준다.
  - ③·④ 는 그대로 둔다.
- B-3 ①·②:
  - 순서는 확정 반영 → 재저장 → `check_brief.py gate` 재실행 → 두 줄 + `pwd` 노출 → 턴 종료이다.
  - 긴 `/compact interview brief at …` 템플릿과 ② 「바로」 경로를 지운다.
  - 「규약의 거처 (C5)」 문단은 「C4 문장은 다음 세션 줄에 싣는다」로 고친다.
- B-4 의 「옵션 ② 는 그 정지 요건의 *명시적 예외*」 문장을 지운다.

**spec-review 변경.**
- `## 게이트` 2단계 표:
  - ① 「미커밋 확인 → `/new` 후 다음 세션 줄 (권장) — 두 줄을 노출하고 **턴 종료**」
  - ② 「미커밋 확인 → `/compact` 후 같은 줄 — 두 줄을 노출하고 **턴 종료**」
- 긴 `/compact 설계문서 …` 템플릿을 (나) 블록으로 바꾼다. 「① 의 정지 요건」 불릿은 「①/② 의 정지 요건」이 된다.
- `### 미커밋 확인` 은 그대로 ①/② 직전에 돈다.

**request-framing 변경.**
- 「호출 모양」 절의 다음 두 문단을 정본 `## 다음 세션 명령` 포인터 한 줄로 줄인다:
  - 두 줄 따로 입력 안내
  - `pwd` 공시
- 옵션 표 ①·② 행 · 노출 모양 펜스 · 커밋 절은 그대로 둔다. 락 `test_seed_at_path_handoff.sh` 의 표 단언과
  `'`/new` 뒤 같은 줄에'` · `'세션 이름'` 단언이 이 절을 재므로, 그 두 문구는 포인터 문장 안에 남긴다.

### §3 락

모두 `plugins/spec-distill/tests/` 아래다. 바꾸는 락은 새 문면을 먼저 단언해 RED 를 확인한 뒤 문면을 고친다.

| 락 | 지금 | 바뀐 뒤 |
|---|---|---|
| `test_seed_at_path_handoff.sh` (정본 단언) | ② 행 `'바로 진행'` · 「채우는 것」 `바로 진행` · 가드 2 「명시적 예외」 현존 | 새 ①·② 행 문면 · `## 다음 세션 명령` 절의 경로 목록 · 받는 쪽 한도 표 · 치환 거부 문장 현존. Step B 표와 가드 2 블록 안 `바로 진행` **부재** + 그 블록을 읽었다는 양성 짝 |
| `test_conducting_interview_stage.sh` | B-2 라벨 둘 · `/compact interview brief at` · B-3 ①·② 창의 `보고 후 재결정` | 새 라벨 둘. 「다음 세션 줄」 블록에 `보고 후 재결정` · C5 어휘. B-3 ①·② 창마다 그 블록 참조 + `턴 종료` |
| `test_review_handoff_order.sh` | `/compact interview brief at` 줄의 순서 · ② 「바로」 창 | `@<brief-path> 이 interview brief 로` 줄(정확히 1개)에서 순서 · 자리표 유일성 · 「보다 이 순서가 우선한다」 · 「게이트 없이 끝나면 …」 |
| `test_plain_gate_templates.sh` | `'/compact .*사람에게 쓰는 글 규칙'` 각 1 · `/compact 설계문서` 줄 자리표 | 각 skill 의 다음 세션 줄에서 `사람에게 쓰는 글 규칙` 정확히 1 · 자리표 유일 |
| **새** `test_next_session_command.sh` | — | 아래 |

`test_next_session_command.sh` (`# guards: plugins/spec-distill/**`, `--emit-scanned`):
- 채택자는 `shared/tests/adopter_derivation.sh` 로 도출하고, 바닥은 3 이다.
- 채택자마다 자기 표면(SKILL.md + references)에서 다음 세션 줄을 찾는다.
  - 다음 세션 줄은 `@<` 로 시작하는 인용 줄, 또는 `/spec-distill:spec-interview @<` 를 담은 줄이다.
  - 이 줄이 **정확히 1개**여야 한다(①·② 가 따로 정의하면 2).
- 평문 줄은 `@<…>` 토큰으로 시작한다. slash 줄의 `@<…>` 토큰 수는 정본 한도 표의 수 이하다.
  - 한도 표는 정본에서 읽는다. 락이 숫자를 들고 있지 않는다.
- 정본 `## 다음 세션 명령` 절에 일곱 규칙의 핵심 문구가 있다. 각 단언에 양성 짝을 붙인다.

### §4 문서 · 버전

- `plugins/spec-distill/README.md` 의 Step B 흐름(L53) · finishing ①·② 설명 · 미커밋 확인 줄 · AP2 단락을
  새 옵션으로 고친다.
- `CLAUDE.md` Polite handoff 의 「옵션 ①(/compact 후 writing-plans) 선택 시 /compact 노출 후 같은 턴에 writing-plans로 직진하는」을
  「옵션 ①·②(`/new`·`/compact` 뒤 다음 세션 줄) 선택 시 명령 노출 후 같은 턴에 다음 단계로 직진하는」으로 고친다.
- `plugin.json` 5.1.1 을 올린다. CHANGELOG 에는 다음을 적는다.
  - Changed: 세 게이트의 ①·② 모양과 다음 세션 줄
  - Removed: 「바로 brainstorming」·「바로 writing-plans」 옵션 — 사용자 결정 재건이라 deprecation 창을 두지 않는다
  - 번호는 머지 직전에 정한다.

## Acceptance Criteria

- AC1. 정본 `proceed-gate.md` 가 ① `/new` · ② `/compact` 를 고정하고, `## 다음 세션 명령` 절에 §1 의 규칙 1~7 을 갖는다.
  Step B 표 · 가드 1 · 가드 2 에 「바로 진행」이 없다.
- AC2. 세 채택자가 각자 다음 세션 줄을 자기 표면에 정확히 하나 갖는다. ①·② 서술은 그 줄을 공유한다.
- AC3. spec-interview · spec-review 의 다음 세션 줄은 `@<자리표>` 로 시작하는 평문이다.
  - C4 문장과 「사람에게 쓰는 글 규칙」 구절을 담는다.
  - spec-interview 줄은 brainstorming → spec-review → writing-plans 순서 문장을 담는다.
- AC4. 세 skill 의 ①·② 서술 블록에 정지 요건 셋이 있다. 「바로」 진행 경로는 없다.
- AC5. request-framing 의 다음 세션 줄은 그대로다. `@` 토큰 수가 받는 쪽 한도(1) 이하다.
- AC6. §3 의 락이 전부 GREEN 이다. 새 락은 §Verification 의 변이 각각에 RED 를 낸다.
- AC7. `check_invocation_surface.py` 와 spec-distill · shared 스위트에 새 FAIL 이 없다(baseline 의 FAIL 이름 집합 대비).
- AC8. README · CLAUDE.md · plugin.json · CHANGELOG 가 §4 대로 바뀌었다.

## Files to Modify

- `plugins/spec-distill/references/proceed-gate.md`
- `plugins/spec-distill/skills/spec-interview/references/finishing.md`
- `plugins/spec-distill/skills/spec-review/SKILL.md`
- `plugins/spec-distill/skills/request-framing/SKILL.md`
- `plugins/spec-distill/tests/test_seed_at_path_handoff.sh`
- `plugins/spec-distill/tests/test_conducting_interview_stage.sh`
- `plugins/spec-distill/tests/test_review_handoff_order.sh`
- `plugins/spec-distill/tests/test_plain_gate_templates.sh`
- `plugins/spec-distill/tests/test_next_session_command.sh` (새 파일)
- `plugins/spec-distill/README.md` · `CLAUDE.md`
- `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`

## Verification Plan

1. **baseline.** 착수 전 리포 루트에서 다음을 bash 로 돌려 FAIL «이름» 집합을 기록한다.
   - `plugins/spec-distill/tests/*.sh` · `*.py`
   - `shared/tests/*.sh`
2. **RED → GREEN.** 락을 먼저 고치고 RED 를 확인한 뒤 문면을 고쳐 GREEN 을 확인한다.
3. **변이 (커밋 후, `PYTHONDONTWRITEBYTECODE=1`).** 아래 각 변이에 RED 가 나야 한다.
   - spec-interview ② 블록에 다음 세션 줄을 하나 더 쓴다.
   - request-framing 줄에 `@<x>` 를 더한다(한도 초과).
   - spec-review 줄의 첫 `@` 를 지운다.
   - 정본의 경로 목록 문장을 지운다.
   - 정본 Step B ② 행에 「바로 진행」을 되살린다.
   - 정본 한도 표의 spec-interview 수를 0 으로 바꾼다.

   복원은 `git checkout HEAD --` 후 `git diff HEAD` 로 확인한다. 양성 대조로, 변이 전 GREEN 을 같은 실행에서 확인한다.
4. **표면 락.** `python3 shared/entry/check_invocation_surface.py` 가 GREEN 이다.
5. **대화형 끝에서 끝(사용자와 함께).**
   - spec-interview 를 끝까지 돌려 ① 을 고른다.
   - 노출된 두 줄과 `pwd` 를 확인한다.
   - `/new` 뒤 둘째 줄을 입력해 첫 턴에 brief 가 첨부되고 brainstorming 이 시작되는지 본다.
   - spec-review ① 도 같은 확인을 한다.

## Rejected Alternatives

- **slash 형 `/superpowers:brainstorming @<경로>`** — 기각.
  - 인자의 `@` 는 헤드리스에서 첨부되지 않았다.
  - 축 G(C1)가 외부 slash 명령을 거부한다.
- **리포 `shared/handoff/` 새 정본 + 심볼릭 링크** — 기각. 소비자가 spec-distill 하나이고, `proceed-gate.md` 가 이미 세 skill 의 공통 계약이다. 새 파일은 링크 계약 락만 늘린다(D3).
- **「바로 진행」 옵션 유지(①/new · ②바로)** — 기각. 세 게이트의 모양이 다시 갈라지고, 정지 요건에 예외가 남는다(D1).
- **경로를 하나로 고정** — 기각. 사용자가 확장성을 요구했다(D6). 목록으로 받는 비용은 토큰 반복 규칙 한 줄이다.
- **spec-interview 진입 단계 2 를 지금 여러 경로로 넓히기** — 기각(YAGNI). 둘째 파일이 아직 없다. 한도 표가 그 경계를 적는다.

## 알려진 한계

- 평문 줄은 파일 첨부를 하니스가 보장한다. 다음 skill 을 실제로 부르는 일은 모델이 그 줄을 읽고 한다 — slash 형의 호출 보장과 맞바꾼 것이다.
- 다음 세션 줄은 사용자가 손으로 옮긴다. 줄이 길어(spec-interview) 복사 실수의 여지가 있다.
- 락은 줄의 모양과 개수를 잰다. ①·② 서술 블록 안 정지 요건 셋의 공존은 리뷰 레이어가 맡는다(정본 「검증」의 기존 한계).

## 결정 기록

- D1. 세 게이트를 framing 모양(① `/new` · ② `/compact` · ③ 수정 · ④ 멈춤)으로 맞춘다. 「바로 진행」을 없앤다. (사용자, 2026-10-11)
- D2. 외부 받는 쪽의 줄은 평문 `@` 프롬프트다. (사용자, 2026-10-11)
- D3. 공통 규칙은 `proceed-gate.md` 에 흡수한다. (사용자, 2026-10-11)
- D4. spec-review → writing-plans 에도 적용한다. (사용자, 2026-10-11) D1 의 모양까지 포함한다고 읽었다 — 설계 리뷰 게이트에서 확인한다.
- D5. 다음 세션 줄은 ①·② 공통이고, skill 당 한 번만 정의한다.
- D6. 읽힐 파일은 경로 목록이다. 받는 쪽 한도는 정본 표가 쥔다. (사용자, 2026-10-11)

## Metadata

- 작성일: 2026-10-11
- 브랜치: `feature/next-session-at-handoff` (base `origin/main` 3a8d7d1d)
- 영향 플러그인: spec-distill
- 다음 단계: `spec-distill:spec-review`(이 문서) → 승인 게이트 → superpowers:writing-plans
