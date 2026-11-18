# 스위치와 상태 자리 이전 — 첫 판 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 켜진 끄기 변수를 skill 첫머리에 보이고(플러그인마다 끄기 변수 표 하나), 은퇴 예정 20개를 공시하고, CLAUDE.md 의 두 글머리와 감사 검사를 새 규칙에 맞추고, 품질 게이트 · 감사의 일회용 작업 사본을 `.claude/worktrees/` 로 옮긴다 — 옛 변수는 지금과 똑같이 끈다.

**Architecture:** 끄기 변수 표는 `plugins/<X>/switches.md`(마크다운 표 — `dependencies.md` 와 같은 자리 · 같은 꼴)다. 진입 사전 검사(`shared/entry/entry_preflight.py`, 네 플러그인이 링크로 싣는다)가 **자기를 부른 경로**(링크를 풀지 않은 경로)에서 플러그인 폴더를 찾아 그 표를 읽고, 감시줄 아래에 `[devbrew-switch]` 줄을 낸다. 작업 사본은 지금 작업 트리 꼭대기의 `.claude/worktrees/` 에 플러그인이 드러나는 이름으로 만들고, 지우기는 그 자리 · 그 이름 꼴 · 브랜치를 쥐지 않은 것만 한다.

**Tech Stack:** Python 3(3.8 문법 바닥 — 사전 검사) · bash(macOS 3.2 호환) · 마크다운 표 · 기존 셸 테스트 도구(`shared/tests/assert.sh`) · unittest.

**Spec:** `docs/superpowers/specs/2026-11-18-official-switches-state-design.md` — 이 계획은 그 문서의 **첫 판(AC1–AC17)** 만 한다. 둘째 판(AC18–AC27)은 F3 의 둘째 계획과 F5 가 머지된 뒤 따로 계획한다.

## Global Constraints

- 끄기 변수는 값이 정확히 `1` 일 때만 켜진 것이다. `DEVBREW_SKIP_HOOKS` 는 쉼표로 나누고 양끝 공백을 걷은 **전체 토큰** 대조다(설계 2).
- 사전 검사는 어느 경우에도 rc 0 이다. import 는 `os` · `subprocess` · `sys` 뿐이다(`shared/tests/test_entry_preflight.sh` #10). 3.8 문법으로 파싱돼야 한다 — 함수 시그니처에 `list[str]` 같은 주석을 달지 않는다.
- 사전 검사가 표를 찾는 길은 `os.path.abspath(__file__)` 의 두 단계 위 폴더의 `switches.md` 다. **`realpath` 를 쓰지 않는다** — 리포에서는 링크(`plugins/<X>/scripts/entry_preflight.py`)로, 설치본에서는 진짜 파일로 실행되고, 두 경우 모두 부른 경로의 플러그인 폴더가 표의 자리다.
- 은퇴 예정 20개는 첫 판에서 **고치기 전과 똑같이 끈다**(AC6). 그 동작을 재는 기존 테스트 파일은 diff 가 없어야 한다 — 예외는 이 계획이 이름 대는 셋(`shared/tests/test_entry_preflight.sh` · `shared/tests/test_python_floor.sh` · `plugins/plugin-audit/tests/test_check_shape_completeness.py`)뿐이고 이유는 각 과제가 적는다.
- 사람에게 보이는 줄의 글자는 이 계획이 정한 그대로다(과제 2 · 3 · 4). 은퇴 예정 줄은 **몇 판 뒤인지 약속하지 않는다**(AC2 — 설계 2 의 예시 줄에 남은 「다음 판부터 듣지 않는다」 는 쓰지 않는다).
- 레포 락(`reference_new_plugin_script_locks`): `plugins/**/*.py` 에 `"python3"` 리터럴 금지 · 스크립트의 `open(` · `.read_text(` 에 `encoding` 필수 · 같은 20줄(200자 이상) 블록이 두 파일에 있으면 `shared/tests/test_no_new_duplication.sh` 가 RED(두 작업 사본 스크립트에 비슷한 함수를 둘 때 글자를 맞춰 베끼지 않는다) · 새 셸 테스트는 100755 로 커밋한다(`git ls-files -s` 로 확인).
- bash 3.2: `set -u` 아래 빈 배열은 `${arr[@]+"${arr[@]}"}` 로 펼친다 · `$var` 바로 뒤에 한글이 오면 `${var}` 로 쓴다.
- 판: 네 플러그인 모두 **minor** 로 올린다. 번호는 **머지 직전 기본 브랜치(`origin/main`) 위의 다음 minor** 다 — 지금 번호를 박지 않는다(과제 12).
- 다른 로드맵이 예약한 파일에 닿는 줄은 최소로 한다(아래 파일 표의 「겹침」 칸).
- 전체 스위트는 아래 줄로만 돈다(지휘자 대조와 같은 공유 잠금 — 못 잡으면 주인 · 잡은 시각을 보고한다. `--owner` 는 도는 agent 의 이름으로 바꾼다). 과제 안에서는 좁은 테스트만 돈다:
  `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/suite-lock --owner f7-plan1 --wait 14400 -- bash -c 'bash tools/suite/run-all.sh'`
  구현 담당이 하위 agent 를 띄우면 그 글에도 이 줄과 경로를 그대로 싣는다.
- 이 세션과 하위 agent 는 Claude Code 를 안에서 다시 띄워 잴 수 없다(`claude -p` 금지). 그런 측정은 과제로 넣지 않고 「재지 못함」 으로 적는다(아래 끝 절).
- 커밋: 한국어 Conventional Commits(type · scope 는 영어), pathspec 으로 커밋한다. 변이(mutation)는 커밋한 뒤에 하고 `git checkout HEAD -- <파일>` + `git diff HEAD` 로 되돌림을 확인한다.

## Review Focus

1. **개발자 셸에 남는 끄기 변수가 켜져 있다**(예: `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` 을 늘 export) — 사전 검사 테스트의 「출력이 감시줄 한 줄과 같다」 단언이 그 환경에서 거짓 RED 가 나면 안 된다. 테스트는 네 표에서 이름을 도출해 모두 `env -u` 로 걷는다(과제 2).
2. **링크로 실행 · 설치본 사본으로 실행** — 표를 부른 경로 기준으로 찾아야 한다. 정본 경로(`shared/entry/`)로 직접 부르면 표가 없어 「읽지 못했다」 가 나오는 것이 맞다(과제 2 의 위치 테스트).
3. **망가진 표** — 파일 없음 · BOM · CRLF · 머리줄 틀림 · 다른 플러그인의 표 · 이름 꼴 틀림 · 같은 이름 두 행 · 너무 큼 · UTF-8 아님. 감시줄은 그대로이고 「읽지 못했다」 한 줄, rc 0(과제 2).
4. **`DEVBREW_SKIP_HOOKS` 의 꼴** — 여러 토큰 · 양끝 공백 · 남의 플러그인 토큰 · 접두가 같은 다른 토큰(`spec-distill:review-entry-x`) · 별칭. 자기 표의 정확한 토큰만 줄을 낸다(과제 2).
5. **`.claude/` 를 무시하지 않는 저장소** — 봉인 · 리뷰 범위 · 지문에서 이 세션의 등록된 qg 사본만 빠지고, 같은 폴더의 사용자 worktree 는 지금처럼 다뤄진다. linked worktree 안에서 부르면 그 worktree 안의 `.claude/worktrees/` 에 생긴다(과제 8 · 9 · 10).

---

## 계획의 판단

설계가 계획에 넘긴 것(Handoff Context 의 「계획이 정한다」 · `### Deferred to plan` 의 계획 몫 여섯)과 그 밖에 이 계획이 정한 것이다.

| # | 정할 것 | 정한 것 | 이유 |
|---|---|---|---|
| J1 | 끄기 변수 표의 파일 꼴과 자리 | `plugins/<X>/switches.md` — frontmatter `type: devbrew-switches` · `plugin: <X>`, 표 칸은 `이름 · 끄는 것 · 상태 · 대신할 길` | `dependencies.md` 가 같은 자리 · 같은 꼴로 이미 있다(있는 것 먼저). 마크다운이라 README 와 글자로 대조된다 |
| J2 | `[devbrew-switch]` 줄의 정확한 글자 | 과제 2 의 「줄 글자」 표 | AC2 — 시점을 약속하지 않는다 |
| J3 | 옛 자리의 예약 이름을 언제 지우나 | `setup-qg.sh` 의 `worktrees` 예약은 **둘째 판에서** 뺀다. `baseline-cache` 는 설계 4 의 표대로 그대로 | 첫 판 동안 옛 자리에 남은 사본이 있을 수 있다. 첫 판은 `setup-qg.sh` 를 고치지 않는다 |
| J4 | 철학 문서 · 저술 가이드를 고치는 때(dfa850c3#r1.1) | 저술 가이드의 트리 두 줄(`hooks/` 주석 · 새 `switches.md` 줄)은 **첫 판**, 철학 P13 · P21 은 **둘째 판 몫** | 가이드의 `hooks/ … DEVBREW_<PLUGIN>_DISABLE=1 opt-out` 은 새 CLAUDE.md 와 반대로 새 코드를 쓰게 한다. 새 플러그인은 진입 skill 이 있으면 표가 있어야 「읽지 못했다」 가 안 난다. P13 · P21 은 첫 판 동안에도 참이다(통째 끄기 변수가 아직 듣는다) — 두 판 사이 철학 문서가 옛 규칙을 말하는 것은 PR 본문에 적는다 |
| J5 | 「꺼져 있다」 줄이 건너뛰는 스크립트의 값 확인은 아니라는 것(40d01f8f#r2.1) | README 「끄는 길」 이 전제를 적는다 — 그 줄은 사전 검사가 값을 본 것이고, 같은 세션의 Bash 로 도는 스크립트가 같은 환경을 물려받는다는 전제에 선다. 실제 건너뜀은 그 단계가 내는 건너뜀 알림으로 본다 | 확인 줄을 스크립트마다 새로 만들지 않는다(장치보다 지침) |
| J6 | 옛 이름 별칭을 수에 넣나(a7d5e63d#r2.1) | 별칭은 같은 행의 이름 칸에 함께 적고 **수에 넣지 않는다**. 수는 행의 첫 이름을 네 표에 걸쳐 중복 없이 센다 — 남음 7 · 은퇴 예정 20 = 27 | 설계 1 의 표(별칭 빼고 7)와 같다. 둘째 판 AC20 의 「7개(옛 이름 별칭 하나 포함)」 는 그 행을 뜻한다 |
| J7 | 「표를 읽지 못했다」 줄의 머리말(c9bee8f9#r3.1) | `[devbrew-switch]` 로 낸다 | 진입 skill 의 새 문장이 이 머리말의 줄을 그대로 보이므로 사용자에게 닿는다. 둘째 판의 「계속할지 묻기」 도 이 줄을 본다 |
| J8 | 설정 파일을 거쳐 간접으로 읽는 codex 끄기 셋(9dc11d92#r3.1) | 첫 판의 「남음 이름마다 읽는 코드」 테스트는 간접 꼴(`scripts/*.conf` 의 `<KEY>=<이름>` 줄 + 같은 플러그인 스크립트의 `${!<KEY>`)을 읽는 코드로 센다. 둘째 판의 감사 검사도 같은 규칙을 쓴다(둘째 판 몫) | codex 셋은 `codex-killswitch.conf` + `detect_codex.sh` 로만 읽힌다 |
| J9 | README 안내 둘(번호 대조 «cc-settings») | 「끄는 길」 이 한 번 실행에만 끄는 길(`claude --settings <파일>` 의 `enabledPlugins` — P1 이 잰 길)과 worktree 안 세션의 로컬 설정 파일(공식 문서 — 재지 않음)을 적는다 | 설계가 README 안내로 넘겼다 |
| J10 | 표에 싣는 「듣는 곳」 의 뜻 | 그 플러그인의 skill · 스크립트가 **실제로 돌리는** 코드가 읽는 것. quality-gates 는 `run_docreview_codex_reviewer.sh` 링크를 싣지만 부르지 않으므로 웹 끄기 둘을 qg 표에 싣지 않는다 | 알림은 실제로 꺼지는 자리에서 보여야 한다(설계 2) |
| J11 | 은퇴 줄(둘째 판)의 자리 | 표 읽기와 줄 만들기가 상태 「은퇴」 를 지금부터 받는다(fixture 로 잰다). 첫 판의 진짜 표에는 「은퇴」 행이 없다 | 둘째 판은 표의 상태 칸만 바꾸면 된다 |
| J12 | 옛 자리의 사본을 무엇까지 치우나(AC15) | 새로 만들기 전에 옛 자리의 **같은 세션 이름**(`base-<8자>` · `head-<8자>` · `rt-<8자>`)만 같은 복구 규칙으로 지운다. 다른 세션의 옛 사본은 지우기 명령이 옛 경로로 받는다 | 지금의 복구도 같은 이름만 지운다. 옛 판으로 같은 레포에서 도는 다른 세션의 사본을 지우지 않는다 |
| J13 | 감사 샌드박스 복사가 옛 자리를 계속 빼나 | 첫 판은 `.claude/worktrees/audit-rt-*` 와 옛 `.claude/plugin-audit/worktrees/*` 를 함께 뺀다. 옛 쪽은 둘째 판에서 지운다 | 옛 판 세션의 사본이 새 사본 안으로 복사되지 않게 |
| J14 | 품질 게이트 리뷰 범위의 「다른 세션 사본」 알림 | 옛 자리의 등록된 사본도 지금처럼 「이전 실행이 남긴 트리」 로 알린다(둘째 판에서 뺀다). 이 세션의 것으로 빼는 것은 새 자리만 | AC14 — 고치기 전과 같은 알림 |
| J15 | 지문(e2e)이 이 세션을 아는 길 | `fingerprint --out <파일>` 의 파일이 `<꼭대기>/.claude/quality-gates/<세션>/` 바로 아래면 그 폴더 이름을 세션으로 쓴다. 아니면 사본을 새로 빼지 않는다 | 부르는 skill 줄(예약 파일)을 고치지 않는다. 지금 부르는 곳은 모두 `$D/e2e-*.txt` 다 |
| J16 | 감사 파서의 탭 들여쓰기 테스트가 고정할 값 | 지금 동작(탭 들여쓰기의 `cost_class` 를 선언으로 읽는다)을 고정한다 | 고치는 범위는 0열 주석뿐이다(설계 6 ④) |
| J17 | AC4 의 락 자리 | 새 테스트 `shared/tests/test_switch_tables.sh` 가 진입 skill 아홉의 문장을 잰다. `shared/tests/test_invocation_surface.sh`(F5 예약)와 `check_invocation_surface.py` 는 고치지 않는다 | 예약 겹침을 피한다 |

**둘째 판 몫으로만 적는 것:** 철학 P13 · P21(J4) · 감사 검사의 「이름 댄 끄기 변수마다 읽는 코드」 요건과 fixture 셋(2e6610eb#r2.1 · J8) · project-init 훅이 은퇴 이름을 표의 「은퇴」 행에서 읽기(720316b3#r3.1) · `setup-qg.sh` 의 `worktrees` 예약 빼기(J3) · 옛 자리 치우기 · 옛 경로 받기 · 옛 자리 알림 빼기(J12 · J13 · J14) · `[devbrew-entry] disabled` 와 진입 skill 아홉의 그 행 · 「이 표가 보는 kill switch」 문장 지우기.

---

## 파일 표

| 파일 | 과제 | 하는 일 | 겹침 |
|---|---|---|---|
| `plugins/{spec-distill,quality-gates,plugin-audit,project-init}/switches.md` | 2 | 새 파일 — 끄기 변수 표 | — |
| `shared/entry/entry_preflight.py` | 2 | 표 읽기 · `[devbrew-switch]` 줄 | — (네 플러그인 판이 오른다) |
| `shared/tests/test_entry_preflight.sh` | 2 | 줄 · 위치 · 망가진 표 테스트, 깨끗한 환경 도출 | — |
| `shared/tests/test_switch_tables.sh` | 3 · 4 | 새 파일 — 수 · README 대조 · 남음 읽는 코드 · 진입 문장 | — |
| `plugins/*/README.md` (넷) | 3 · 6 · 9 | `## 끄는 길` 절. 감사 README 의 감사 기준 줄 · qg README 의 사본 자리 줄 | qg README — 품질 게이트 로드맵 예약(새 절 하나 + 한 줄) |
| 진입 skill 아홉의 `SKILL.md` | 4 | 진입 단계 첫 문단 끝에 한 문장(줄 수 늘지 않음) | request-framing · pm-interview — F3 · F5 · quality-pipeline — 품질 게이트 로드맵 · epic-conductor — 지휘자 맥락 경제 로드맵(각 한 줄) |
| `CLAUDE.md` | 5 | `### 런타임 상태 & 훅` 의 두 글머리 | 지휘자 맥락 경제 로드맵(다른 줄) |
| `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` | 5 | 두 글머리 줄 전체 · 부재 단언 범위 | — |
| `docs/plugin-authoring.md` | 5 | 트리 두 줄(J4) | — |
| `plugins/plugin-audit/scripts/check-shape-completeness.py` · `check-staleness.py` · `audit-workflow.js` | 6 · 7 | 훅 kill switch 요건 빼기 · 지시문 한 줄 · 0열 주석 | — |
| `plugins/plugin-audit/tests/test_check_shape_completeness.py` · `test_check_staleness.py` | 6 · 7 | 요건 빼기 테스트 · 파서 테스트 | — |
| `shared/tests/test_python_floor.sh` | 6 | 지우는 함수를 부르던 두 블록(A11 · 축 C 의 감사기 판정) 빼기 | — |
| `plugins/quality-gates/scripts/qg-worktree.sh` | 8 | 새 자리 · 이름 · 좁은 지우기 · `own-paths` | 품질 게이트 로드맵(scripts/ 전체) |
| `plugins/quality-gates/scripts/review-diff.sh` · `seal-worktree.sh` · `e2e-state.sh` | 9 | 이 세션 사본 빼기의 자리 | 품질 게이트 로드맵 |
| `plugins/quality-gates/tests/` 의 사본 자리 테스트 | 8 · 9 | 자리 글자 · 새 동작 | — |
| `plugins/plugin-audit/scripts/audit-sandbox.sh` · 테스트 둘 | 10 | 새 자리 · 이름 · 레포 밖 검사 · 좁은 지우기 · 복사 빼기 | — |
| `plugins/project-init/tests/test_post_tool_use_branch.sh` | 11 | 일회용 사본에 브랜치 알림이 없다 | — |
| `plugins/*/.claude-plugin/plugin.json` · `plugins/*/CHANGELOG.md` | 12 | 판 · 기록 | — |

고치지 않는 것: `plugins/plugin-audit/scripts/run-own-tests.sh`(자리를 모른다 — 샌드박스 스크립트가 낸 경로를 쓴다) · `plugins/quality-gates/scripts/setup-qg.sh`(J3) · `plugins/quality-gates/scripts/publish-comment.sh`(본문 모음은 `[ -f ]` 로 폴더 줄을 건너뛴다) · `shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh` · 설계 Files to Modify 의 「고치지 않는 것」.

---

### Task 1: 다시 확인

설계문서의 근거 자리가 지금 코드에서도 그런지 본다. 다르면 **멈추고** 지휘자에게 보고한다(어느 확인 · 무엇이 달랐나 · 이 계획의 어느 과제가 닿나). 고치지 않는다.

**Files:** 없음(읽기만).

- [ ] **Step 1: 끄기 변수의 듣는 곳**

각 플러그인의 비테스트 추적 파일(링크는 대상 내용)에서 27개 이름과 별칭 둘(`DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` · 토큰 별칭)이 나오는 자리를 모은다(`git ls-files plugins/<X>` 에서 `/tests/` · `CHANGELOG` · `README` 를 빼고 파일마다 `grep -E '(^|[^A-Z0-9_])<이름>([^A-Z0-9_]|$)'`). 기대 — 과제 2 의 네 표가 싣는 이름이 그 플러그인에서 나오고, 표에 없는 이름은 그 플러그인의 **도는 코드**에서 읽히지 않는다(J10: qg 의 `scripts/run_docreview_codex_reviewer.sh` 링크는 qg skill 이 부르지 않는다 — `git grep -n 'run_docreview_codex_reviewer' -- plugins/quality-gates ':!*/tests/*' ':!*CHANGELOG*'` 가 주석 줄만 낸다). project-init 의 `scripts/devbrew-python.sh` 에 나오는 `DEVBREW_SPEC_DISTILL_DISABLE` 은 주석의 예시다.

`DEVBREW_SKIP_HOOKS` 토큰 — `git grep -nohE 'DEVBREW_SKIP_HOOKS=[a-z-]+:[A-Za-z-]+' -- plugins shared ':!*CHANGELOG*' ':!*/tests/*'` 의 살아 있는 토큰이 표의 여섯(+별칭 둘)과 은퇴한 옛 토큰(`spec-distill:Stop` · `:PostToolUse` · `:UserPromptSubmit` 등 — 표에 싣지 않는다)뿐이다.

- [ ] **Step 2: 진입 skill · 줄 상한 · 소비자 · 자리 글자**

Run:
```bash
grep -l '^!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" ' plugins/*/skills/*/SKILL.md | wc -l
awk '/^<!-- plain-language:begin -->$/{s=1} s==0{n++} s==2{s=0; if ($0 != "") n++; next} /^<!-- plain-language:end -->$/{s=2} END{print n+0}' plugins/spec-distill/skills/pm-interview/SKILL.md
grep -n '^SKILL_LINE_CAP=' plugins/spec-distill/tests/test_conducting_interview_stage.sh
git grep -n '_metadata_cost_class\|_hooks_killswitch_present\|_has_killswitch\|hooks_killswitch\|KILL_SWITCH_RE' -- ':!docs' ':!*CHANGELOG*'
git grep -ln 'quality-gates/worktrees\|plugin-audit/worktrees' -- plugins shared ':!*CHANGELOG*'
```
Expected: `9` · 줄 수가 상한보다 작다(계획을 쓸 때 602 · 상한 604 — 과제 4 는 줄을 늘리지 않는다) · 소비자는 감사 스크립트 둘 · `plugins/plugin-audit/tests/test_check_shape_completeness.py` · `plugins/plugin-audit/tests/test_check_staleness.py`(규범 이름 `kill switch`) · `shared/tests/test_python_floor.sh` · 자리 글자는 `qg-worktree.sh` · `review-diff.sh` · `audit-sandbox.sh` 와 테스트 여섯(`test_audit_sandbox_create.sh` · `test_audit_sandbox_mutation_guard.sh` · `test_differential_trees.sh` · `test_qg_worktree_helper.sh` · `test_review_diff.sh` · `test_runtime_contract_invariance.sh` · `test_seal_no_side_effects.sh`) · README 한 줄(qg Principles 의 `.claude/<plugin>/worktrees/` 컨벤션).

- [ ] **Step 3: 보고**

달라진 것이 없으면 「다시 확인 — 설계 · 계획과 같다」 한 줄을 과제 보고에 적고 과제 2 로 간다. 커밋 없음.

---

### Task 2: 끄기 변수 표 넷과 사전 검사의 `[devbrew-switch]` 줄

**AC:** AC1 · AC2 · AC3 · AC6(사전 검사 쪽)

**Files:**
- Create: `plugins/spec-distill/switches.md` · `plugins/quality-gates/switches.md` · `plugins/plugin-audit/switches.md` · `plugins/project-init/switches.md`
- Modify: `shared/entry/entry_preflight.py`
- Test: `shared/tests/test_entry_preflight.sh`

**Interfaces:**
- Produces (in `entry_preflight.py`, 다른 과제와 테스트가 importlib 로 부른다):
  - `TABLE_FILE = "switches.md"` · `SWITCH_PREFIX = "[devbrew-switch]"` · `HEADER = "| 이름 | 끄는 것 | 상태 | 대신할 길 |"` · `SEPARATOR = "|---|---|---|---|"` · `STATES = ("남음", "은퇴 예정", "은퇴")`
  - `class TableError(Exception)` — `.reason`(한 줄 한국어)
  - `table_path(script_path)` → `<script_path 의 두 단계 위>/switches.md`(문자열, 링크를 풀지 않는다)
  - `read_table(path, plugin)` → 행 목록. 행은 `{"names": [str, ...], "what": str, "state": str, "instead": str}`. 어긋나면 `TableError`
  - `active_names(row, environ)` → 켜진 이름의 표시 글자 목록(`NAME=1` 또는 `DEVBREW_SKIP_HOOKS=<토큰>`)
  - `switch_lines(rows, environ)` → 줄 목록(표의 행 순서)
  - `unreadable_line(reason)` → 줄 하나

- [ ] **Step 1: 네 표를 쓴다**

모두 같은 꼴이다:

```markdown
---
type: devbrew-switches
plugin: <플러그인>
---

# <플러그인> 끄기 변수

상태: 남음 = 계속 듣는다 · 은퇴 예정 = 지금은 듣고, 곧 듣지 않는다 · 은퇴 = 더 듣지 않는다.

| 이름 | 끄는 것 | 상태 | 대신할 길 |
|---|---|---|---|
```

행(이 순서 그대로). 「대신할 길」 칸에 `P` 라고만 적은 곳은 자리표시다 — 그 칸에 아래 글자를 넣는다:

```
Claude Code 의 플러그인 끄기(`/plugin` · `claude plugin disable` · 설정의 `enabledPlugins`) — 새 세션부터 먹는다
```

spec-distill:

| 이름 | 끄는 것 | 상태 | 대신할 길 |
|---|---|---|---|
| `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` | codex 리뷰 | 남음 | — |
| `DEVBREW_SPEC_DISTILL_DISABLE_WEB` | 인터뷰와 brief 리뷰의 웹 조사 | 남음 | — |
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST` | 지휘자의 스위트 대조가 저장소 테스트를 돌리기 | 남음 | — |
| `DEVBREW_SPEC_DISTILL_DISABLE` | spec-distill 전체 | 은퇴 예정 | `P` |
| `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC` | 문서 리뷰의 재비판 | 은퇴 예정 | 없음 — 작은 일에서 건너뛰는 것은 모델 판단이 이유를 적고 한다 |
| `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW` | brief 리뷰 | 은퇴 예정 | 없음 — 작은 일에서 건너뛰는 것은 모델 판단이 이유를 적고 한다 |
| `DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE` | request-framing 의 워크트리 질문 | 은퇴 예정 | 질문에 「아니오」 로 답한다 |
| `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` | 설계문서 리뷰 | 은퇴 예정 | `/spec-distill:spec-review` 를 부르지 않는다 |
| `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` | 설계문서 리뷰 | 은퇴 예정 | `/spec-distill:spec-review` 를 부르지 않는다 |
| `DEVBREW_QUALITY_GATES_DISABLE_WEB` | brief 리뷰가 codex 에 여는 웹 검색 | 은퇴 예정 | `DEVBREW_SPEC_DISTILL_DISABLE_WEB` |
| `DEVBREW_SKIP_HOOKS=spec-distill:statusline` | 상태줄과 로드맵 지도 | 은퇴 예정 | 상태줄 설정을 지운다 |
| `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` · `DEVBREW_SKIP_HOOKS=spec-distill:session-end-cleanup` | 리뷰 원장 정리 | 은퇴 예정 | 유예 시간 `DEVBREW_SPEC_DISTILL_TTL_HOURS` 를 크게 준다 |
| `DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc` | 리뷰 원장 정리 | 은퇴 예정 | 유예 시간 `DEVBREW_SPEC_DISTILL_TTL_HOURS` 를 크게 준다 |

quality-gates:

| 이름 | 끄는 것 | 상태 | 대신할 길 |
|---|---|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE_CODEX` | codex 리뷰 | 남음 | — |
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST` | 리뷰 대상 저장소의 테스트 실행(차등 테스트 · e2e 부팅) | 남음 | — |
| `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` | 열린 PR 에 코멘트 달기 | 남음 | — |
| `DEVBREW_QUALITY_GATES_DISABLE` | quality-gates 전체 | 은퇴 예정 | `P` |
| `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER` | 보안 리뷰어 | 은퇴 예정 | 없음 — 보안 리뷰는 늘 돈다 |
| `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE` | 문서 비평 | 은퇴 예정 | `/quality-gates:artifact-critique` 를 부르지 않는다 |
| `DEVBREW_QUALITY_GATES_DISABLE_E2E` | e2e 걷기 | 은퇴 예정 | e2e 질문에 「아니오」 로 답한다. 실행 자체를 막으려면 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST` |
| `DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC` | 의도 점검 | 은퇴 예정 | 없음 — 읽기만 하는 단계다 |
| `DEVBREW_SKIP_HOOKS=quality-gates:qg-gc` | 남의 세션 폴더 정리 | 은퇴 예정 | 유예 시간 `DEVBREW_QUALITY_GATES_TTL_HOURS` 를 크게 준다 |

plugin-audit:

| 이름 | 끄는 것 | 상태 | 대신할 길 |
|---|---|---|---|
| `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX` | codex 감사 | 남음 | — |
| `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX` · `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` | 감사 대상 플러그인의 테스트 실행 | 남음 | — |
| `DEVBREW_PLUGIN_AUDIT_DISABLE` | plugin-audit 전체 | 은퇴 예정 | `P` |
| `DEVBREW_PLUGIN_AUDIT_DISABLE_WEB` | codex 감사의 웹 검색 | 은퇴 예정 | `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX` — codex 는 쓰되 웹만 막는 길은 없어진다 |

project-init:

| 이름 | 끄는 것 | 상태 | 대신할 길 |
|---|---|---|---|
| `DEVBREW_PROJECT_INIT_DISABLE` | project-init 전체(훅과 셋업) | 은퇴 예정 | `P` |
| `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` · `DEVBREW_SKIP_HOOKS=project-init:PostToolUse` | 브랜치 · 커밋 확인 훅 | 은퇴 예정 | 플러그인 끄기, 또는 설정의 `disableAllHooks` |

- [ ] **Step 2: 실패하는 테스트를 쓴다** (`shared/tests/test_entry_preflight.sh`)

a. **깨끗한 환경 도출** — `CLEAN` 을 고정 목록 대신 네 표의 이름(환경변수 꼴 전부)과 `DEVBREW_SKIP_HOOKS` 의 `env -u` 로 만든다(importlib 로 `read_table` 을 불러 도출 · 도출 수가 0 이면 `no`).
b. **배포 경로로 부르기** — 지금 정본 `"$S"` 를 직접 부르는 절(#2 · #3 · #4 · #5 · #8 · #8b · #11)을 그 플러그인의 링크(`$ROOT/plugins/<p>/scripts/entry_preflight.py`)로 부른다. 정본 경로는 플러그인 폴더가 아니라 표가 없다. 단언 줄은 그대로다.
c. **#7(통째 끄기 판정)** — `got` 을 첫 줄(감시줄)에서만 뽑는다(`head -n 1`). 단언 줄은 그대로다. disabled 줄 모양 단언(지금 73행)은 첫 줄과 비교하고, 둘째 줄이 `[devbrew-switch] 꺼져 있다 — project-init 전체(훅과 셋업)(DEVBREW_PROJECT_INIT_DISABLE=1). 곧 은퇴한다 — 대신: ` 로 시작하는지 단언을 더한다(설계 3 — 통째 끄기 변수가 켜지면 은퇴 예정 줄이 붙는다). 이 파일이 AC6 의 「단언 그대로」 의 예외인 이유다 — 바뀌는 것은 부르는 경로와 줄 뽑기이고 판정값은 같다.
d. 새 절 — 설치본 꼴: `$TMP/inst/<p>/scripts/entry_preflight.py`(`cp -L`)와 `$TMP/inst/<p>/switches.md`(fixture — 남음 · 은퇴 예정 · 은퇴 · 별칭 행 · 토큰 행을 하나씩)를 만들고 그 사본으로 부른다:
   - `test_lines_by_state`: 각 상태 행의 이름을 `=1` 로 켜면 아래 「줄 글자」 그대로의 줄. 둘을 켜면 표의 행 순서로 두 줄.
   - `test_alias`: 별칭만 켜도 그 행의 줄이 나오고 괄호에 켠 이름이 보인다. 둘 다 켜면 한 줄에 ` · ` 로 둘.
   - `test_value_not_one`: `true` · ` 1` · `0` · 빈 값이면 줄이 없다(감시줄 한 줄만).
   - `test_not_in_table`: 표에 없는 끄기 변수(`DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` 을 spec-distill fixture 로)는 줄이 없다.
   - `test_skip_hooks_tokens`: `DEVBREW_SKIP_HOOKS="x:y, spec-distill:review-entry ,foo"` → 그 행 한 줄. `spec-distill:review-entry-x` · `review-entry` 만 · 남의 플러그인 토큰 → 줄 없음.
   - `test_location_follows_invoked_path`: 같은 이름을 켜고 리포 링크로 부르면 리포 표의 「끄는 것」 이, 설치본 사본으로 부르면 fixture 의 「끄는 것」 이 나온다(양성 대조). 정본 경로(`"$S"`)로 부르면 `[devbrew-switch] 끄기 변수 표를 읽지 못했다 — ` 로 시작하는 줄 하나.
   - `test_unreadable`: fixture 를 망가뜨린 꼴마다(파일 없음 · 머리줄 다름 · 구분줄 다름 · 칸 셋 · `plugin:` 이 다른 플러그인 · frontmatter `type` 다름 · 이름이 백틱 밖 · 이름 꼴 틀림(`DEVBREW_x`) · 상태 `남는다` · 같은 이름 두 행 · 64 KiB 넘음 · UTF-8 아님) rc 0 · 첫 줄이 감시줄 그대로 · 둘째 줄이 `[devbrew-switch] 끄기 변수 표를 읽지 못했다 — ` 로 시작 · 줄은 둘뿐.
   - `test_bom_crlf_empty`: BOM 이 붙은 표 · CRLF 줄끝 표는 정상으로 읽힌다. 행이 없는 표(머리줄 둘만)는 줄 없이 감시줄 하나.
   - `test_usage_error_no_switch_lines`: 인자 개수가 틀리면 error 줄 하나뿐이다.

**줄 글자** (`{what}` = 끄는 것 칸, `{names}` = `active_names` 를 ` · ` 로 이은 것, `{instead}` = 대신할 길 칸):

| 상태 | 줄 |
|---|---|
| 남음 | `[devbrew-switch] 꺼져 있다 — {what}({names})` |
| 은퇴 예정 | `[devbrew-switch] 꺼져 있다 — {what}({names}). 곧 은퇴한다 — 대신: {instead}` |
| 은퇴 | `[devbrew-switch] 더 듣지 않는다 — {what}({names}). 대신: {instead}` |
| 표를 읽지 못함 | `[devbrew-switch] 끄기 변수 표를 읽지 못했다 — {사유}. 켜진 끄기 변수가 있는지 알 수 없다` |

- [ ] **Step 3: 실패를 본다**

Run: `bash shared/tests/test_entry_preflight.sh`
Expected: 새 절의 `✗` 줄들(`[devbrew-switch]` 줄이 없다). 기존 절은 통과.

- [ ] **Step 4: `entry_preflight.py` 를 고친다**

- `main()` 순서: 감시줄을 지금처럼 만든다 → 인자가 정확히 둘이고 비지 않았으면, 따로 감싼 `try` 안에서 `read_table(table_path(os.path.abspath(__file__)), plugin)` → `switch_lines(rows, os.environ)`. `TableError` 는 `unreadable_line(e.reason)`, 그 밖의 예외는 `unreadable_line(<예외 이름>)` 이다. 감시줄 다음 줄부터 순서대로 쓴다. 쓰기 실패 처리는 지금의 devnull 길 그대로. 켜진 것이 없으면 쓰는 바이트는 고치기 전과 같다.
- `read_table`: 64 KiB 까지 바이트로 읽어(넘으면 사유 「표 파일이 너무 크다」) `utf-8-sig` 로 풀고 줄마다 끝의 `\r` 를 걷는다. frontmatter(첫 줄 `---` 부터 다음 `---` 까지)의 `type: devbrew-switches` · `plugin: <인자>` 를 확인한다. `|` 로 시작하는 첫 줄이 `HEADER`, 다음 줄이 `SEPARATOR`, 그 뒤 이어진 `|` 줄이 행이다. 표가 끝난 뒤 또 `|` 줄이 오면 사유 「표가 둘이다」. 행은 칸 넷(양끝 `|` 를 뗀 뒤 `|` 로 나눔), 이름 칸은 ` · ` 로 나눈 각 조각이 백틱으로 싼 이름이다. 이름은 `DEVBREW_` 로 시작하고 나머지가 `A-Z 0-9 _` 뿐인 것(길이 9 이상), 또는 `DEVBREW_SKIP_HOOKS=<a>:<b>`(`a` · `b` 는 `A-Za-z0-9-` 한 글자 이상)다. 상태는 `STATES` 중 하나. 네 표 전체가 아니라 한 표 안에서 같은 이름이 두 번 나오면 사유. 정규식(`re`)을 쓰지 않는다.
- `active_names`: 이름이 토큰 꼴이면 `DEVBREW_SKIP_HOOKS` 를 쉼표로 나눠 양끝 공백을 걷은 토큰과 전체 대조, 아니면 `environ.get(name) == "1"`.
- 모듈 머리말에 표의 자리 규칙 한 줄(부른 경로의 플러그인 폴더 · 링크를 풀지 않는다)을 더한다.

- [ ] **Step 5: 통과를 본다**

Run: `bash shared/tests/test_entry_preflight.sh`
Expected: `✗` 없음.

- [ ] **Step 6: 출력 불변을 바이트로 견준다(AC1)**

Run(깨끗한 환경 · 이 레포 꼭대기에서):
```bash
git show HEAD:shared/entry/entry_preflight.py > "$TMPDIR/old_preflight.py"
env -u … python3 "$TMPDIR/old_preflight.py" spec-distill spec-review > "$TMPDIR/old.out"
env -u … python3 plugins/spec-distill/scripts/entry_preflight.py spec-distill spec-review > "$TMPDIR/new.out"
cmp "$TMPDIR/old.out" "$TMPDIR/new.out" && echo SAME
```
(커밋 전이라 `HEAD` 가 고치기 전 판이다. `env -u …` 는 Step 2a 의 목록.) 네 플러그인 모두 `SAME`.

- [ ] **Step 7: 변이로 이빨을 본다**

커밋한 뒤 하나씩: ① `table_path` 를 `os.path.realpath` 로 → `test_location_follows_invoked_path` RED ② 토큰 대조를 부분 문자열(`in`)로 → `test_skip_hooks_tokens` RED ③ `== "1"` 을 `in ("1", "true")` 로 → `test_value_not_one` RED. 되돌리고 `git diff HEAD` 가 비었는지 본다.

- [ ] **Step 8: Commit**

```bash
git add plugins/spec-distill/switches.md plugins/quality-gates/switches.md plugins/plugin-audit/switches.md plugins/project-init/switches.md shared/entry/entry_preflight.py shared/tests/test_entry_preflight.sh
git commit -m "feat(entry): 끄기 변수 표를 읽어 켜진 것을 사전 검사 줄로 보인다"
```

---

### Task 3: README 「끄는 길」 과 표 대조 테스트

**AC:** AC5

**Files:**
- Create: `shared/tests/test_switch_tables.sh` (100755)
- Modify: `plugins/spec-distill/README.md`(`## 끄는 법` 바로 앞) · `plugins/quality-gates/README.md`(`## 설정` 바로 앞) · `plugins/plugin-audit/README.md`(`## Prerequisites (cross-plugin 의존)` 바로 앞) · `plugins/project-init/README.md`(`## 통합` 바로 앞)

**Interfaces:**
- Consumes: Task 2 의 `read_table` · `HEADER` · `SEPARATOR`(importlib 로 `shared/entry/entry_preflight.py` 를 불러 쓴다)
- Produces: `test_switch_tables.sh` 의 절 구조(Task 4 가 절 E 를 더한다)

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`shared/tests/test_switch_tables.sh`)

대상 플러그인은 `plugins/*/scripts/entry_preflight.py` 가 있는 플러그인에서 도출한다(넷이 아니면 `no`).
- A `tables_readable`: 플러그인마다 `switches.md` 가 있고 `read_table` 이 오류 없이 읽는다.
- B `counts`: 네 표의 행 첫 이름을 중복 없이 모으면 27, 그중 상태 남음 7 · 은퇴 예정 20 · 은퇴 0(주석: 둘째 판이 은퇴 20 으로 바꾼다). 한 이름이 두 표에 실리면 두 표의 상태가 같다.
- C `readme_matches_table`: 각 README 에 `## 끄는 길` 절이 하나, 그 절 안에 `<!-- switches:begin -->` · `<!-- switches:end -->` 가 하나씩, 그 사이(앞뒤 빈 줄 제외)가 그 플러그인 `switches.md` 의 머리줄부터 마지막 행까지와 바이트로 같다. 절 안에 `claude plugin disable` · `enabledPlugins` · `/reload-plugins` · `새 세션` · `--settings` · `settings.local.json` · `` `env` 칸 `` · `[devbrew-switch]` 가 있다.
- D `kept_names_have_readers`: 각 표의 상태 남음 행의 이름(별칭 포함)마다 그 플러그인의 비테스트 추적 파일(`switches.md` · `README.md` · `CHANGELOG.md` · `entry_preflight.py` 빼고, 링크는 대상 내용)에 읽는 꼴이 하나 이상 있다. 읽는 꼴: 셸 `$<이름>` · `${<이름>`, 파이썬 `environ.get("<이름>"` · `environ["<이름>"]` · `getenv("<이름>"`, 간접(J8) — `scripts/*.conf` 의 `<KEY>=<이름>` 줄 + 같은 플러그인 파일의 `${!<KEY>`. 앞을 걷어 `#` 로 시작하는 줄과 첫 낱말이 `echo` · `printf` · `print(` 인 줄은 세지 않는다.

- [ ] **Step 2: 실패를 본다**

Run: `bash shared/tests/test_switch_tables.sh`
Expected: C 의 `✗`(README 에 절이 없다). A · B · D 는 통과.

- [ ] **Step 3: README 넷에 `## 끄는 길` 절을 쓴다**

절의 차례(네 README 같은 차례, 그 플러그인 이름으로):
1. 통째 끄기 — Claude Code 의 플러그인 끄기(`/plugin` 화면 · `claude plugin disable <플러그인>` · 설정의 `enabledPlugins`). 끄면 skill 과 훅이 함께 꺼지고 새 세션부터 먹는다 — 도는 세션은 `/reload-plugins` 뒤. 한 번 실행에만 끄려면 `claude --settings <파일>` 의 `enabledPlugins` 에 `"<플러그인>@<마켓플레이스>": false`(J9). worktree 안에서 연 세션은 본 체크아웃의 `.claude/settings.local.json` 을 쓴다(공식 설정 문서 — 이 레포에서 재지 않았다).
2. 끄기 변수를 주는 두 길 — 셸 환경변수, 또는 Claude Code 설정(`settings.json`)의 `env` 칸. `env` 칸의 값이 Bash 로 도는 스크립트에 닿는지는 재지 않았다. 확인하는 법 — 적은 뒤 이 플러그인의 진입 skill 을 부르면 첫머리에 `[devbrew-switch] 꺼져 있다 — …` 줄이 보인다. 보이지 않으면 셸 환경변수로 준다. 이 줄은 사전 검사가 값을 본 것이다 — 같은 세션의 Bash 로 도는 스크립트가 같은 환경을 물려받는다는 전제에 선다. 실제로 건너뛰었는지는 그 단계의 건너뜀 알림으로 본다(J5).
3. 표 — `<!-- switches:begin -->` 와 `<!-- switches:end -->` 사이에 `switches.md` 의 표를 그대로. 그 아래 한 줄: 「은퇴 예정 이름은 지금은 그대로 끈다. 곧 은퇴하며, 은퇴 뒤에는 「대신할 길」 칸을 쓴다.」
4. spec-distill · quality-gates 만: 변수마다 자세한 동작은 아래 기존 절(spec-distill 「끄는 법」 · quality-gates 「Kill switches (보안 컨트롤)」)에 있다는 한 줄. 기존 절은 고치지 않는다.

- [ ] **Step 4: 통과를 본다**

Run: `bash shared/tests/test_switch_tables.sh && bash plugins/spec-distill/tests/test_brief_review_meta.sh && bash shared/tests/test_writer_trust_notice.sh`
Expected: `✗` 없음(뒤의 둘은 spec-distill README 의 `## 끄는 법` 을 묻는 기존 락).

- [ ] **Step 5: 변이**

커밋한 뒤: ① README 표의 한 행에서 상태를 바꾼다 → C RED ② `plugins/plugin-audit/scripts/codex-killswitch.conf` 의 `CODEX_KILL_SWITCH_VAR=` 줄을 주석으로 → D RED ③ spec-distill 표의 은퇴 예정 행 하나를 지운다 → B RED. 되돌리고 `git diff HEAD` 확인.

- [ ] **Step 6: Commit**

```bash
git add shared/tests/test_switch_tables.sh plugins/spec-distill/README.md plugins/quality-gates/README.md plugins/plugin-audit/README.md plugins/project-init/README.md
git ls-files -s shared/tests/test_switch_tables.sh   # 100755
git commit -m "docs(readme): 네 플러그인 README 에 끄는 길과 끄기 변수 표를 싣는다"
```

---

### Task 4: 진입 skill 아홉의 한 문장

**AC:** AC4

**Files:**
- Modify: 진입 skill 아홉 — `plugins/plugin-audit/skills/plugin-audit/SKILL.md` · `plugins/project-init/skills/project-init/SKILL.md` · `plugins/quality-gates/skills/{artifact-critique,quality-pipeline}/SKILL.md` · `plugins/spec-distill/skills/{epic-conductor,pm-interview,request-framing,roadmap-status,spec-review}/SKILL.md`
- Test: `shared/tests/test_switch_tables.sh`(절 E)

- [ ] **Step 1: 실패하는 테스트를 쓴다** — 절 E `entry_skills_show_switch_lines`

진입 skill 은 `^!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" ` 줄이 있는 `SKILL.md` 에서 도출한다(9 가 아니면 `no`). 각 파일의 `## 진입 단계` 절(다음 `## ` 앞까지)에 아래 문장이 정확히 한 번 있고, 그 문장이 든 줄이 `이 절이 다른 모든 절보다 먼저 돈다.` 로 시작한다.

문장(앞에 공백 하나를 두고 그 줄 끝에 붙인다 — 백틱까지 글자 그대로):

```
감시줄 아래에 `[devbrew-switch]` 로 시작하는 줄이 있으면 감시줄이 무엇이든 그 줄들을 고치지 않고 사용자에게 보인다.
```

- [ ] **Step 2: 실패를 본다** — Run: `bash shared/tests/test_switch_tables.sh` · Expected: E 의 `✗` 아홉.

- [ ] **Step 3: 아홉 파일의 `## 진입 단계` 첫 문단 줄 끝에 문장을 붙인다**

새 줄을 만들지 않는다(pm-interview 의 줄 상한). 감시줄 판독 표 · 「이 표가 보는 kill switch」 문장은 건드리지 않는다.

- [ ] **Step 4: 통과와 이웃 락을 본다**

Run:
```bash
bash shared/tests/test_switch_tables.sh
bash shared/tests/test_invocation_surface.sh
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh
bash plugins/spec-distill/tests/test_repo_literals.sh
bash plugins/spec-distill/tests/test_request_framing_entry.sh
bash plugins/spec-distill/tests/test_epic_conductor_skill.sh
bash shared/tests/test_entry_dep_needs.sh
git diff HEAD --numstat -- 'plugins/*/skills/*/SKILL.md'
```
Expected: `✗` 없음 · numstat 은 아홉 파일 각 `1	1`(AC4 — 판독 표는 diff 가 없다).

- [ ] **Step 5: Commit**

```bash
git add plugins/plugin-audit/skills/plugin-audit/SKILL.md plugins/project-init/skills/project-init/SKILL.md plugins/quality-gates/skills/artifact-critique/SKILL.md plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/spec-distill/skills/epic-conductor/SKILL.md plugins/spec-distill/skills/pm-interview/SKILL.md plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/skills/roadmap-status/SKILL.md plugins/spec-distill/skills/spec-review/SKILL.md shared/tests/test_switch_tables.sh
git commit -m "feat(skills): 진입 단계가 [devbrew-switch] 줄을 그대로 보인다"
```

---

### Task 5: CLAUDE.md 두 글머리 · 규칙 락 · 저술 가이드 두 줄

**AC:** AC8 · AC10

**Files:**
- Modify: `CLAUDE.md:70-71` · `docs/plugin-authoring.md`(트리) · `plugins/quality-gates/tests/test_governance_no_capability_caps.sh:267-272,292-293`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- 270–272 행(옛 kill switch 글머리 단언)을 지우고: `assert_eq "$(cline '**JSON이 아니라 마크다운 state.**')" "$STATE_LINE"` · `assert_eq "$(cline '**끄는 길은 공식 장치 먼저.**')" "$SWITCH_LINE"`(두 변수는 아래 글자 그대로 테스트 안에 둔다). 267–269 행은 그대로 둔다.
- `assert_not_contains "$(cat "$CLAUDE_MD")" '모든 훅에 kill switch'` + 양성 짝은 위 `$SWITCH_LINE` 단언.
- 292–293 행: 판정 함수 `ps_banned <파일>` 이 `## Plugin Shape` 절(그 제목 다음 줄부터 다음 `## ` 앞까지)에 `integrity` 나 `모든 PR마다` 가 있으면 그 낱말을 낸다. 진짜 CLAUDE.md → 빈 값. 임시 사본에 절 **밖**(`## Doc Conventions` 아래)에 두 낱말을 넣은 것 → 빈 값. 절 **안**에 넣은 것 → 비지 않음(AC10).
- 저술 가이드 트리(`TREE6`): `assert_contains "$TREE6" '├── switches.md'` · `assert_not_contains "$TREE6" 'DEVBREW_<PLUGIN>_DISABLE=1 opt-out'`.

`STATE_LINE` (설계 5 의 상태 글머리 — 「① 의 수명은 넷이다 — 」 뒤는 지금 문장 그대로):

```
- **JSON이 아니라 마크다운 state.** 상태 자리는 성격으로 가른다 — ① 세션과 리뷰어가 읽고 쓰는 런타임 state 는 `.claude/<plugin>/` 하위에 산다(git-ignored) ② 플러그인이 스스로 만드는 일회용 작업 사본(git worktree)은 작업 트리 꼭대기의 `.claude/worktrees/` 에 그 플러그인이 드러나는 이름으로 만들고 자기가 만든 것만 지운다(예외 — 지휘자의 스위트 대조 사본은 지휘 기계 상태 폴더 아래에 둔다) ③ 스크립트만 쓰고 잃어도 다시 만들 수 있는 캐시는 Claude Code 의 플러그인 데이터 폴더(`${CLAUDE_PLUGIN_DATA}`)에 프로젝트마다 갈리게 두고, 쓰지 못하면 알리고 캐시 없이 돈다 ④ 인터뷰처럼 세션을 넘어 남아야 하는 기록은 docs 의 추적 파일에 두고 산출물과 함께 커밋한다. ① 의 수명은 넷이다 — 세션 단위(`.claude/<plugin>/<session-id>/<file>` — 다음 시작 때 지우고 TTL GC 가 남은 것을 치운다. 지금은 qg 다) · 문서 단위 리뷰 원장(그 문서가 사라질 때 정리) · 로드맵 단위 지휘 기계 상태(`machine.md`) · 실행 단위 산출(plugin-audit 실행 폴더 — 지우지 않는다). spec-distill 의 상태 루트는 worktree 에서 불러도 메인 레포 쪽이고 처음 만들 때 자기 `.gitignore` 를 둔다. spec-distill 펜스의 상태 폴더 쓰기는 writer(`nofollow_write`)를 거쳐 마지막 경로 성분의 링크를 따라가지 않는다. 예외 하나 — plugin-audit 실행 폴더는 넘겨받은 `--repo-root`(기본 cwd) 아래에 링크 검사 없이 만든다. **Secret 기록 금지** — placeholder 참조 사용 (철학 P21).
```

`SWITCH_LINE` (설계 5 의 끄는 길 글머리 그대로):

```
- **끄는 길은 공식 장치 먼저.** 플러그인을 통째로 끄는 길은 Claude Code 의 플러그인 끄기다(`/plugin` · `claude plugin disable` · 설정의 `enabledPlugins`) — 통째 끄기용 환경변수를 두지 않는다. 끄는 환경변수(`DEVBREW_<PLUGIN>_DISABLE_<기능>=1`)는 skill 이 묻지 않고 하는 일 가운데 사용자가 막고 싶을 수 있는데 공식 장치로 막을 길이 없는 것(내용을 바깥으로 보냄 · 남의 코드를 실행 · 바깥에 글을 올림)에만 둔다. 끄기 변수마다 읽는 코드가 있다 — skill 문장으로만 꺼지는 스위치는 두지 않는다. 켜진 끄기 변수는 진입 사전 검사가 skill 첫머리에 한 줄로 보인다. 끄기 변수는 보안 컨트롤이다 — 읽는 코드는 그 값을 무시할 수 없고, 은퇴는 한 판 동안 옛 이름을 그대로 듣고 알린 뒤에 하며 CHANGELOG `Removed` 와 README 에 공시한다.
```

저술 가이드 트리 두 줄: `hooks/` 줄 주석을 `# optional — 끄는 길은 Claude Code 의 플러그인 끄기다(통째 끄기용 환경변수를 두지 않는다)` 로 바꾸고, `dependencies.md` 줄 바로 아래에 `├── switches.md             # 진입 skill 이 있으면 필수 — 끄기 변수 표(이름 · 끄는 것 · 상태 · 대신할 길). 진입 사전 검사가 읽고 README 「끄는 길」 이 같다. 끄기 변수가 없으면 머리줄 둘만` 를 더한다.

- [ ] **Step 2: 실패를 본다** — Run: `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · Expected: 새 단언의 `✗`.

- [ ] **Step 3: `CLAUDE.md` 70 · 71 행을 위 두 줄로 바꾸고, 저술 가이드 두 줄을 고친다**

- [ ] **Step 4: 통과 · diff 범위를 본다**

Run:
```bash
bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh
git diff HEAD --numstat -- CLAUDE.md
git diff HEAD -U0 -- CLAUDE.md | grep '^@@'
```
Expected: `✗` 없음 · `2	2	CLAUDE.md` · 덩이 머리는 70–71 행 하나(AC8 — 다른 글머리와 다른 절은 diff 가 없다).

- [ ] **Step 5: 변이** — 커밋한 뒤 ① `SWITCH_LINE` 줄 끝에 ` 다만 지키지 않아도 된다.` 를 붙인다 → RED ② 71 행을 옛 「모든 훅에 kill switch」 글머리로 되돌린다 → RED. 되돌리고 확인.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md docs/plugin-authoring.md plugins/quality-gates/tests/test_governance_no_capability_caps.sh
git commit -m "docs(claude-md): 상태 자리를 네 갈래로, 끄는 길을 공식 장치 먼저로 고친다"
```

---

### Task 6: 감사 검사가 훅 kill switch 를 요구하지 않는다

**AC:** AC9

**Files:**
- Modify: `plugins/plugin-audit/scripts/check-shape-completeness.py`(CHECKLIST 의 `hooks_killswitch` · 66 행 · `_CMD_SCRIPT_RE` · `_walk_hook_commands` · `_hooks_killswitch_present` · `_has_killswitch` 삭제) · `plugins/plugin-audit/scripts/check-staleness.py`(`KILL_SWITCH_RE` · `scan_category_absence` 의 (3) 삭제, docstring 의 「4개」 → 「3개」) · `plugins/plugin-audit/scripts/audit-workflow.js:389` · `plugins/plugin-audit/README.md:94`
- Test: `plugins/plugin-audit/tests/test_check_shape_completeness.py` · `plugins/plugin-audit/tests/test_check_staleness.py` · `shared/tests/test_python_floor.sh`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- `test_check_shape_completeness.py`: `ANCHORS` 에서 `hooks_killswitch` 를 뺀다. `hooks_killswitch` 를 묻는 테스트 여섯(204–282 · 313 행 근처)을 아래 둘로 바꾼다 — `test_hook_without_switch_is_not_a_gap`: 등록된 훅 스크립트가 어떤 끄기 변수도 읽지 않는 fixture → 출력의 requirement 이름 목록에 `hooks_killswitch` 가 없고 모든 항목이 고치기 전과 같은 값(`plugin_json_fields` 등 다섯이 참). `test_checklist_names`: 출력 requirement 이름이 정확히 `plugin_json_fields · readme_principles · changelog_if_v1 · agents_allowlist · skills_cost_class · deps_declared`.
- `test_check_staleness.py`: kill switch 테스트 셋(590–621 행)을 `test_hook_without_readme_switch_is_not_a_fact` 하나로 — 훅이 있고 README 에 끄기 변수 언급이 없어도 `norm == "kill switch"` 사실이 없다. `TestCategoryAbsence` docstring 을 셋으로.
- `shared/tests/test_python_floor.sh`: A11 블록(383–405 행 — `_has_killswitch` 를 직접 부른다)과 축 C 의 감사기 판정 블록(715–736 행 근처 — `hooks_killswitch` 를 읽는다)과 574 행 근처 설명 주석을 지운다. 해석기의 스위치 동작을 재는 다른 단언은 그대로다. 이 파일이 AC6 예외인 이유 — 지우는 것은 감사 요건의 판정이고 스위치 동작이 아니다.
- 지시문(AC9): `plugins/plugin-audit/tests/test_axis3_reachability_question.sh` 를 고치지 않고, `plugins/plugin-audit/tests/audit-workflow.test.mjs` 에 단언 하나 — 축 3 질문에 `DEVBREW_<PLUGIN>_DISABLE\`` 와 `DEVBREW_SKIP_HOOKS` 가 없고 `DEVBREW_<PLUGIN>_DISABLE_<기능>` 이 있다.

- [ ] **Step 2: 실패를 본다**

Run: `python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_check_s*.py' -v` · `node --test plugins/plugin-audit/tests/audit-workflow.test.mjs`
Expected: 새 테스트 FAIL(requirement 가 아직 있다).

- [ ] **Step 3: 고친다**

- 위 함수 · 상수 · 갈래를 지운다(남는 쓰임이 없다 — Task 1 Step 2 가 소비자를 확인했다).
- `audit-workflow.js:389` 를 `'- 끄기 변수(kill switch, \`DEVBREW_<PLUGIN>_DISABLE_<기능>\`)가 실제로 존중되는가 — 그 값을 보고 그 일을 건너뛰는 코드가 있는지 코드로 확인하라.',` 로 바꾼다(`kill switch` 낱말은 기존 축 3 락이 묻는다).
- 감사 README 94 행을 `- **끄는 길 (감사 기준)** — 훅에 kill switch 를 요구하지 않는다. 훅을 끄는 길은 Claude Code 의 플러그인 끄기다(CLAUDE.md 「끄는 길은 공식 장치 먼저」).` 로 바꾼다.

- [ ] **Step 4: 통과를 본다**

Run:
```bash
python3 -m unittest discover -s plugins/plugin-audit/tests -v 2>&1 | tail -3
node --test plugins/plugin-audit/tests/audit-workflow.test.mjs
bash plugins/plugin-audit/tests/test_axis3_reachability_question.sh
bash shared/tests/test_python_floor.sh
for p in spec-distill quality-gates plugin-audit project-init; do python3 plugins/plugin-audit/scripts/check-shape-completeness.py plugins/$p; done
```
Expected: 실패 없음 · 네 플러그인 모두 남은 여섯 요건이 고치기 전과 같은 값(고치기 전 값은 Step 1 전에 같은 명령으로 떠 둔다).

- [ ] **Step 5: Commit**

```bash
git add plugins/plugin-audit/scripts/check-shape-completeness.py plugins/plugin-audit/scripts/check-staleness.py plugins/plugin-audit/scripts/audit-workflow.js plugins/plugin-audit/README.md plugins/plugin-audit/tests/test_check_shape_completeness.py plugins/plugin-audit/tests/test_check_staleness.py plugins/plugin-audit/tests/audit-workflow.test.mjs shared/tests/test_python_floor.sh
git commit -m "feat(plugin-audit): 훅에 kill switch 를 요구하던 감사 요건을 뺀다"
```

---

### Task 7: 감사 파서가 `metadata` 안의 0열 주석을 건너뛴다

**AC:** AC16

**Files:**
- Modify: `plugins/plugin-audit/scripts/check-shape-completeness.py` · `plugins/plugin-audit/scripts/check-staleness.py` 의 `_metadata_cost_class`(두 사본)
- Test: `plugins/plugin-audit/tests/test_check_shape_completeness.py`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
def test_zero_column_comment_inside_metadata(self):   # 「metadata:\n# note\n  cost_class: low\n」 → 선언
def test_one_line_form_is_not_declared(self):         # 「metadata: {cost_class: low}\n」 → 선언 아님
def test_tab_indent_is_declared(self):                # 「metadata:\n\tcost_class: low\n」 → 선언(J16 — 지금 동작)
def test_two_copies_are_identical(self):              # ast 로 두 파일의 _metadata_cost_class 원문을 떠 같은지
```
첫 셋은 `_mk_plugin(..., skill_fm=...)` 로 만들어 `skills_cost_class` 의 `present` 를 본다. 넷째는 `ast.get_source_segment` 로 두 스크립트의 함수 원문을 뜬다.

- [ ] **Step 2: 실패를 본다** — Run: `python3 -m unittest plugins/plugin-audit/tests/test_check_shape_completeness.py -v` · Expected: 첫 테스트 FAIL.

- [ ] **Step 3: 두 사본에서 블록 안의 `line[0] == "#"` 줄을 `continue` 로 건너뛴다** — 들여쓰지 않은 그 밖의 줄은 지금처럼 블록을 닫는다. 두 사본은 글자 그대로 같게.

- [ ] **Step 4: 통과를 본다** — Run: `python3 -m unittest discover -s plugins/plugin-audit/tests -v 2>&1 | tail -3` · Expected: OK.

- [ ] **Step 5: Commit**

```bash
git add plugins/plugin-audit/scripts/check-shape-completeness.py plugins/plugin-audit/scripts/check-staleness.py plugins/plugin-audit/tests/test_check_shape_completeness.py
git commit -m "fix(plugin-audit): metadata 블록 안의 0열 주석이 블록을 닫지 않는다"
```

---

### Task 8: 품질 게이트의 비교용 사본을 `.claude/worktrees/` 로

**AC:** AC11 · AC12 · AC13 · AC15(품질 게이트 쪽)

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh`
- Test: `plugins/quality-gates/tests/test_qg_worktree_helper.sh` · `test_differential_trees.sh` · `test_runtime_contract_invariance.sh`

**Interfaces:**
- Produces: `qg-worktree.sh own-paths <session-id>` → 이 세션의 등록된 사본의 **레포 기준 상대 경로**(`.claude/worktrees/qg-base-<8자>` · `.claude/worktrees/qg-head-<8자>` 중 있는 것) 한 줄씩. 등록 판정은 `git worktree list --porcelain` 의 `worktree` 경로와 물리 경로(`pwd -P`) 일치. rc 0, 사용 오류 · 나쁜 세션 id 는 rc 2. Task 9 가 쓴다.
- 사본 경로: `<git rev-parse --show-toplevel 의 물리 경로>/.claude/worktrees/qg-{base,head}-<세션 id 앞 8자>`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

임시 저장소에서(`.claude/` 를 무시하지 않는 것과 무시하는 것 둘):
- `test_new_location`(AC11): `create-baseline` · `create-head` 가 낸 경로가 `<top>/.claude/worktrees/qg-base-<8>` · `qg-head-<8>` 이고, `.claude/quality-gates/worktrees/` 는 생기지 않는다. linked worktree 안에서 부르면 그 worktree 꼭대기 아래다.
- `test_keep_others`(AC12): `.claude/worktrees/` 에 브랜치를 쥔 worktree `feat-x`(안에 추적 안 되는 파일 하나)와 이름이 다른 detached worktree `other` 를 두고 만들기 · 다시 만들기 · 지우기를 돈다 → 둘과 그 파일이 그대로다(양성 대조: 같은 실행에서 자기 사본은 생기고 지워진다).
- `test_branch_holding_same_name_stops`(AC12): `qg-base-<8>` 이름으로 브랜치를 쥔 worktree 가 있으면 만들기 rc 2 · `remove` rc 2, 그 worktree 는 그대로.
- `test_recover_same_name`(AC12): 같은 이름의 링크(밖의 폴더를 가리킨다) → 링크만 지우고 밖의 폴더는 그대로, 새 사본이 생긴다. 등록이 풀린 같은 이름 폴더 · 브랜치를 쥐지 않은 같은 이름 worktree → 지우고 다시 만든다.
- `test_escape_refused`(AC13): `.claude/worktrees` 가 레포 밖을 가리키는 링크면 만들지 않는다(rc 2) — 기존 D9 · 133 행의 링크 테스트를 새 자리로 옮긴다.
- `test_old_location_cleaned`(AC15 · J12): 옛 자리 `.claude/quality-gates/worktrees/base-<8>`(등록된 detached)를 두고 `create-baseline` → 옛 사본이 지워지고 새 사본이 생긴다. 옛 자리의 다른 세션 이름 `base-zzzzzzzz` 는 그대로. `remove <옛 자리 경로>` 는 지운다.
- `test_remove_scope`: `remove` 는 `<top>/.claude/worktrees/qg-(base|head)-<1~8자>` 와 옛 `<top>/.claude/quality-gates/worktrees/(base|head)-<1~8자>` 만 받는다 — `.claude/worktrees/feat-x` · 밖 · `..` 경로는 rc 2. 없는 자기 이름 경로는 rc 0. 기존 `missing-12345678` 단언은 `qg-base-missing1` 로 바꾼다.
- `test_own_paths`: 사본 둘을 만든 뒤 `own-paths <sid>` 가 두 줄, 지운 뒤 빈 출력, 나쁜 sid 는 rc 2.
- `test_runtime_contract_invariance.sh` 의 자리 글자(45 · 182 행)를 새 자리로.

- [ ] **Step 2: 실패를 본다** — Run: `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh; bash plugins/quality-gates/tests/test_differential_trees.sh; bash plugins/quality-gates/tests/test_runtime_contract_invariance.sh` · Expected: 새 단언 `✗`.

- [ ] **Step 3: 고친다**

- `make_detached_worktree`: `parent="$main_root/.claude/worktrees"`, 이름 `qg-${prefix}-${sid_short}`. 레포 밖 검사 · 링크 검사(52–63 행)는 새 자리로 그대로. 만들기 전 순서 — ① 옛 자리 `"$main_root/.claude/quality-gates/worktrees/${prefix}-${sid_short}"` 가 있으면 아래 복구 규칙으로 지운다 ② 새 자리 같은 이름: 링크면 링크만 지운다 · 브랜치를 쥔 등록된 worktree 면 `die`(「자기 이름의 사본이 브랜치를 쥐고 있다 — 지우지 않는다: $wt」) · 그 밖이면 지금처럼 지우고 다시 만든다.
- 브랜치를 쥐었나: `git worktree list --porcelain` 의 블록에서 `worktree <경로>` 의 물리 경로가 대상과 같고 `branch ` 줄이 있으면 참. 함수 하나(`holds_branch <abs-path>`)로 두고 `own-paths` 의 등록 판정과 같은 읽기를 쓴다.
- `remove`: 대상의 가장 깊은 실재 조상을 풀어 붙인 경로(지금 방식)의 부모가 `$repo_root/.claude/worktrees` 이고 이름이 `qg-(base|head)-[A-Za-z0-9_-]{1,8}` 이거나, 부모가 `$repo_root/.claude/quality-gates/worktrees` 이고 이름이 `(base|head)-[A-Za-z0-9_-]{1,8}` 일 때만 받는다. 브랜치를 쥔 worktree 면 `die`.
- `own-paths` 서브명령을 더하고 머리말 Subcommands 목록 · 30 행 주석의 「플러그인 네임스페이스 안」 을 새 자리로 고친다.

- [ ] **Step 4: 통과를 본다** — Step 2 의 명령 · Expected: `✗` 없음.

- [ ] **Step 5: 변이** — 커밋한 뒤 ① `holds_branch` 가 늘 거짓을 내게 → `test_branch_holding_same_name_stops` RED ② `remove` 의 이름 검사를 뺀다 → `test_remove_scope` RED ③ 옛 자리 정리 줄을 지운다 → `test_old_location_cleaned` RED. 되돌리고 확인.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_worktree_helper.sh plugins/quality-gates/tests/test_differential_trees.sh plugins/quality-gates/tests/test_runtime_contract_invariance.sh
git commit -m "feat(quality-gates): 비교용 사본을 .claude/worktrees/ 에 qg- 이름으로 만들고 자기 것만 지운다"
```

---

### Task 9: 품질 게이트의 리뷰 범위 · 봉인 · 지문이 새 자리의 이 세션 사본만 뺀다

**AC:** AC14(품질 게이트 쪽)

**Files:**
- Modify: `plugins/quality-gates/scripts/review-diff.sh:229-258` · `plugins/quality-gates/scripts/seal-worktree.sh:38-56` · `plugins/quality-gates/scripts/e2e-state.sh`(`cmd_fingerprint` 과 그 python 의 두 git 호출) · `plugins/quality-gates/README.md:27`
- Test: `plugins/quality-gates/tests/test_review_diff.sh` · `test_seal_no_side_effects.sh` · `test_e2e_state.sh`

**Interfaces:**
- Consumes: Task 8 의 `qg-worktree.sh own-paths <session-id>`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- `test_review_diff.sh`: 자리 글자를 새 자리 · 새 이름으로 옮긴다(56 · 525–526 · 622–658 · 810–824 행의 `.claude/quality-gates/worktrees/(base|head)-…` → `.claude/worktrees/qg-(base|head)-…`). 더하는 단언: 옛 자리의 **다른 세션** 등록된 사본은 지금처럼 「이전 실행이 남긴 트리」 로 알린다(J14) · `.claude/worktrees/feat-x`(사용자 worktree)는 고치기 전과 같이 중첩 레포로 알린다(새로 빠지지 않는다 — AC14).
- `test_seal_no_side_effects.sh`(135–160 행의 두 case): 이 세션의 등록된 `.claude/worktrees/qg-base-sess0002` 가 무시 안 됨 · 무시됨 두 갈래 모두에서 봉인 트리에 없다. 더하는 case `case_seal_keeps_user_worktree`: 무시 안 되는 저장소의 `.claude/worktrees/feat-x`(사용자 worktree)는 봉인 트리에 지금처럼 gitlink 로 실린다(양성 대조). 다른 세션 이름 `qg-base-zzzzzzzz` 도 실린다.
- `test_e2e_state.sh`: `fingerprint --out <top>/.claude/quality-gates/<sid>/e2e-before.txt` 를 이 세션의 등록된 `.claude/worktrees/qg-head-<8>` 이 있을 때와 없을 때 떠서 `compare` 가 `same` 이다. `--out` 이 세션 폴더가 아니면 그 사본이 지문에 실린다(J15 — 새로 빼지 않는다).

- [ ] **Step 2: 실패를 본다** — Run: `bash plugins/quality-gates/tests/test_review_diff.sh; bash plugins/quality-gates/tests/test_seal_no_side_effects.sh; bash plugins/quality-gates/tests/test_e2e_state.sh` · Expected: 새 단언 `✗`.

- [ ] **Step 3: 고친다**

- `review-diff.sh`: `QG_WT_ANY_RE='^\.claude/(worktrees/qg-|quality-gates/worktrees/)(base|head)-[A-Za-z0-9_-]{1,8}/$'` · `QG_WT_RE='^\.claude/worktrees/qg-(base|head)-'"$SID8"'/$'`. 229 행 근처 출처 주석의 자리를 고친다. `is_registered_wt` 는 그대로.
- `seal-worktree.sh`: 서브셸 전에 `own=$(bash "$(dirname "${BASH_SOURCE[0]}")/qg-worktree.sh" own-paths "$sid")`(실패하면 빈 값). 제외 배열 — `.claude/quality-gates` 가 무시 안 되면 `:(exclude).claude/quality-gates`, `own` 의 경로마다 `git check-ignore -q <경로>` 가 무시 안 됨이면 `:(exclude)<경로>`. 배열이 비면 `add -A`, 아니면 `add -A -- . <배열>`(빈 배열은 `${arr[@]+…}`). 41–52 행 주석에 새 자리 한 줄.
- `e2e-state.sh`: `cmd_fingerprint` 에서 `--out` 파일의 폴더(물리 경로)의 부모가 `<top>/.claude/quality-gates` 면 그 폴더 이름으로 `own-paths` 를 부르고, 결과를 python 에 인자로 넘겨 두 git 호출의 pathspec 에 `:(exclude)<경로>` 로 더한다. 머리말 fingerprint 설명에 한 줄.
- qg README 27 행: `.claude/<plugin>/worktrees/<name>-<sid-short>/` 컨벤션 문장을 「플러그인이 스스로 만드는 일회용 worktree 는 작업 트리 꼭대기의 `.claude/worktrees/` 에 플러그인이 드러나는 이름(`qg-base-<sid 8자>`)으로 만든다 — CLAUDE.md 상태 글머리 ②」 로 바꾼다(그 줄의 버전 표기 `(v1.15.0)` 는 그대로).

- [ ] **Step 4: 통과를 본다**

Run: Step 2 의 명령과 `bash plugins/quality-gates/tests/test_publish_comment_sink.sh; bash plugins/quality-gates/tests/test_isolation.sh`
Expected: `✗` 없음.

- [ ] **Step 5: 변이** — 커밋한 뒤 ① 봉인의 own 제외를 빼고 무시 안 됨 갈래 case 를 돈다 → RED ② `QG_WT_ANY_RE` 에서 옛 자리 갈래를 뺀다 → J14 단언 RED. 되돌리고 확인.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/review-diff.sh plugins/quality-gates/scripts/seal-worktree.sh plugins/quality-gates/scripts/e2e-state.sh plugins/quality-gates/README.md plugins/quality-gates/tests/test_review_diff.sh plugins/quality-gates/tests/test_seal_no_side_effects.sh plugins/quality-gates/tests/test_e2e_state.sh
git commit -m "feat(quality-gates): 리뷰 범위 · 봉인 · 지문이 새 자리의 이 세션 사본만 뺀다"
```

---

### Task 10: 감사의 자체 테스트 사본을 `.claude/worktrees/` 로

**AC:** AC11 · AC12 · AC13 · AC14 · AC15(감사 쪽)

**Files:**
- Modify: `plugins/plugin-audit/scripts/audit-sandbox.sh`(머리말 13–14 행 · `create-sandbox` 42–56 · 72 행 · `remove`)
- Test: `plugins/plugin-audit/tests/test_audit_sandbox_create.sh` · `test_audit_sandbox_mutation_guard.sh`(28 · 31 · 436 행의 자리 도출)

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`test_audit_sandbox_create.sh`)

Task 8 과 같은 축으로, 이름 `audit-rt-<8>` · 옛 자리 `.claude/plugin-audit/worktrees/rt-<8>`:
- 새 자리(AC11 — 본 체크아웃과 linked worktree 둘) · 다른 worktree 보존(AC12) · 같은 이름 브랜치 worktree 면 멈춤 · 링크는 링크만 · 등록 풀린 폴더는 다시 만듦 · `.claude/worktrees` 가 밖을 가리키는 링크면 만들지 않음(AC13 — 이 스크립트에 새로 생기는 검사) · 옛 자리 같은 이름 정리와 `remove <옛 경로>`(AC15) · `remove` 범위(157 · 160 행 단언을 새 이름 꼴로).
- `test_copy_skips_audit_trees`(AC14): 무시 안 되는 저장소에 다른 세션의 `.claude/worktrees/audit-rt-zzzzzzzz`(등록된 worktree)와 옛 `.claude/plugin-audit/worktrees/rt-yyyyyyyy` 를 두고 `create-sandbox` → 새 사본 안에 둘 다 없다. 같은 폴더의 `.claude/worktrees/feat-x` 는 사본 안에 지금처럼 복사된다(새로 빠지지 않는다).
- kill switch 단언(122–132 행)은 그대로 통과해야 한다(AC6).

- [ ] **Step 2: 실패를 본다** — Run: `bash plugins/plugin-audit/tests/test_audit_sandbox_create.sh; bash plugins/plugin-audit/tests/test_audit_sandbox_mutation_guard.sh` · Expected: 새 단언 `✗`.

- [ ] **Step 3: 고친다**

- `create-sandbox`: `parent="$main_root/.claude/worktrees"` · `sandbox="$parent/audit-rt-${sid_short}"` · `sid_short` 문자 검사(qg 와 같은 허용 글자). 만들기 전에 `qg-worktree.sh` 52–63 행과 같은 뜻의 레포 밖 · 링크 검사(글자를 베끼지 말고 이 스크립트의 꼴로 — 중복 락). 옛 자리 같은 이름 정리 → 새 자리 같은 이름 복구(링크만 · 브랜치면 `die` · 그 밖 지우고 다시).
- 복사 빼기(72 행): `.claude/worktrees/audit-rt-*` 와 `.claude/plugin-audit/worktrees/*`(J13).
- `remove`: `<top>/.claude/worktrees/audit-rt-<1~8자>` 와 옛 `<top>/.claude/plugin-audit/worktrees/rt-<1~8자>` 만 받고 브랜치 worktree 면 `die`.
- 머리말 · 72 행 · 454 행 주석의 자리를 고친다.

- [ ] **Step 4: 통과를 본다**

Run: Step 2 의 명령과 `python3 -m unittest plugins/plugin-audit/tests/test_run_own_tests.py -v 2>&1 | tail -3; bash plugins/plugin-audit/tests/test_run_own_tests_accumulate.sh`
Expected: 실패 없음.

- [ ] **Step 5: 변이** — 커밋한 뒤 ① 복사 빼기의 새 자리 갈래를 지운다 → `test_copy_skips_audit_trees` RED ② 레포 밖 검사를 지운다 → AC13 단언 RED. 되돌리고 확인.

- [ ] **Step 6: Commit**

```bash
git add plugins/plugin-audit/scripts/audit-sandbox.sh plugins/plugin-audit/tests/test_audit_sandbox_create.sh plugins/plugin-audit/tests/test_audit_sandbox_mutation_guard.sh
git commit -m "feat(plugin-audit): 자체 테스트 사본을 .claude/worktrees/ 에 audit-rt- 이름으로 만들고 레포 밖이면 만들지 않는다"
```

---

### Task 11: project-init 훅이 일회용 사본에 브랜치 알림을 내지 않는다

설계 상류 · 하류 연계의 확인 몫이다. 훅 파일(지휘자 맥락 경제 로드맵 예약)은 고치지 않는다 — 테스트가 RED 면 멈추고 보고한다.

**Files:**
- Test: `plugins/project-init/tests/test_post_tool_use_branch.sh`

- [ ] **Step 1: 테스트를 쓴다** — `fresh` 레포 `W` 에서 `git -C "$W" worktree add --detach "$W/.claude/worktrees/qg-base-sess1234" HEAD` 뒤 `hook Bash "$W" 'bash /x/scripts/qg-worktree.sh create-baseline abc sess1234'` → `field ac` 와 `field systemMessage` 가 비었다. 같은 꼴로 `audit-rt-sess1234` 와 `audit-sandbox.sh create-sandbox sess1234`.

- [ ] **Step 2: 돈다** — Run: `bash plugins/project-init/tests/test_post_tool_use_branch.sh` · Expected: `✗` 없음(일회용 사본은 detached 라 브랜치가 없다). RED 면 멈추고 보고.

- [ ] **Step 3: Commit**

```bash
git add plugins/project-init/tests/test_post_tool_use_branch.sh
git commit -m "test(project-init): 일회용 사본 만들기에 브랜치 알림이 없음을 못 박는다"
```

---

### Task 12: 기본 브랜치를 합치고 판 · CHANGELOG

**AC:** AC7 · AC6(확인)

PR 을 만들기 직전에 한다.

**Files:**
- Modify: `plugins/*/.claude-plugin/plugin.json` · `plugins/*/CHANGELOG.md`

- [ ] **Step 1: 기본 브랜치를 합친다** — `git fetch origin && git merge origin/main`(충돌은 이 계획의 뜻으로 푼다. 같은 판으로 올린 `plugin.json` 은 충돌 목록에 안 뜰 수 있다 — Step 2 에서 직접 견준다).

- [ ] **Step 2: 판을 정한다** — 플러그인마다 `git show origin/main:plugins/<X>/.claude-plugin/plugin.json` 의 판에서 다음 minor(`a.b.c` → `a.(b+1).0`). 열린 F3 PR 이 먼저 머지됐으면 그 판 위의 다음 minor 다.

- [ ] **Step 3: `plugin.json` 과 CHANGELOG 머리를 쓴다** — `## [<판>] — <오늘 날짜>`:
- `### Added` — 끄기 변수 표(`switches.md`)와 진입 skill 첫머리의 `[devbrew-switch]` 줄 · README 「끄는 길」.
- `### Changed` — quality-gates: 비교용 사본 자리 `.claude/worktrees/qg-…` · plugin-audit: 자체 테스트 사본 자리 `.claude/worktrees/audit-rt-…`(레포 밖이면 만들지 않는다) · 훅 kill switch 감사 요건 제거 · 0열 주석 파서 고침.
- `### Deprecated` — 그 플러그인 표의 은퇴 예정 이름마다 `` `<이름>` — 대신: <대신할 길> ``(별칭은 같은 줄). 「곧 은퇴한다 — 지금은 그대로 끈다」 를 첫 줄에.

- [ ] **Step 4: 확인**

Run:
```bash
bash shared/tests/test_changelog_integrity.sh
for p in spec-distill quality-gates plugin-audit project-init; do python3 - "$p" <<'PY'
import importlib.util, sys
p = sys.argv[1]
s = importlib.util.spec_from_file_location("ep", "shared/entry/entry_preflight.py"); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
rows = m.read_table("plugins/%s/switches.md" % p, p)
cl = open("plugins/%s/CHANGELOG.md" % p, encoding="utf-8").read().split("\n## [")[1]
dep = cl.split("### Deprecated", 1)[1].split("\n### ", 1)[0] if "### Deprecated" in cl else ""
miss = [r["names"][0] for r in rows if r["state"] == "은퇴 예정" and r["names"][0] not in dep]
print(p, "빠진 은퇴 예정:", miss)
PY
done
```
Expected: 무결성 통과 · 넷 모두 `빠진 은퇴 예정: []`(AC7).

AC6 확인 — 은퇴 예정 이름을 담은 테스트 파일 중 이 계획이 이름 댄 셋 밖에는 diff 가 없다:
```bash
git grep -lE 'DEVBREW_(SPEC_DISTILL|QUALITY_GATES|PLUGIN_AUDIT|PROJECT_INIT)_DISABLE([^A-Z0-9_]|$)|DISABLE_SECURITY_REVIEWER|DISABLE_RECRITIC|DISABLE_BRIEF_REVIEW|DISABLE_WORKTREE|DESIGN_MODE_DISABLE|QUALITY_GATES_DISABLE_CRITIQUE|QUALITY_GATES_DISABLE_WEB|PLUGIN_AUDIT_DISABLE_WEB|DISABLE_E2E|DISABLE_INTENT_CRITIC|DEVBREW_SKIP_HOOKS' -- 'shared/tests/*' 'plugins/*/tests/*' | grep -v /fixtures/ > "$TMPDIR/ac6.txt"
git diff --name-only origin/main...HEAD -- $(cat "$TMPDIR/ac6.txt")
```
Expected: `shared/tests/test_entry_preflight.sh` · `shared/tests/test_python_floor.sh` · `plugins/plugin-audit/tests/test_check_shape_completeness.py` 와 이 계획이 자리 글자만 고친 테스트(Task 8 · 9 · 10 · 11 의 파일 — 그 diff 에 스위치 단언 변경이 없는지 눈으로 본다) 밖에는 없다.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/.claude-plugin/plugin.json plugins/plugin-audit/.claude-plugin/plugin.json plugins/project-init/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/quality-gates/CHANGELOG.md plugins/plugin-audit/CHANGELOG.md plugins/project-init/CHANGELOG.md
git commit -m "chore(release): 네 플러그인 판을 minor 로 올리고 은퇴 예정을 공시한다"
```

---

### Task 13: 전체 스위트(AC17)

- [ ] **Step 1: 공유 잠금 아래에서 돈다** — Global Constraints 의 잠금 줄 그대로. 못 잡으면 주인 · 잡은 시각을 보고한다.
- [ ] **Step 2: 실패를 가른다** — `FAILED` 줄마다 이 브랜치 변경과 닿는지 적는다. worktree 에서만 나는 기존 실패(예: `TestCrossResolverAdvisory`)는 그렇다고 적는다. 기본 브랜치와의 대조는 지휘자 대조(merge_check)가 한다. 이 브랜치에만 있는 실패가 0 이 될 때까지 고친다(고친 것은 그 과제의 뜻 안에서 · 커밋 pathspec).

---

## 실행 방식의 마지막 전체 리뷰

고른 실행 방식(subagent-driven 의 마지막 전체 리뷰 · native 의 마지막 리뷰)의 리뷰어에게 아래를 그대로 싣는다.

- 설계문서 `## Acceptance Criteria` 의 첫 판 목록(AC1–AC17) 원문.
- 요청: AC 마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>` 로 보고하라.
- 끝에서 끝 흐름 셋을 따로 물어라 — ① 끄기 변수를 켠 채 진입 skill 을 부르면 표 → 사전 검사 줄 → skill 의 새 문장 → 사용자에게 보임 ② qg 실행 한 번의 사본 만들기 → 봉인 · 리뷰 범위 · 지문의 빼기 → 지우기 ③ 감사 실행 한 번의 샌드박스 만들기 → 복사 → 지우기. 각 이음매의 rc 소비와 상태 가정.
- 이 계획이 쓴 테스트 코드(Task 2 · 3 · 8 · 9 · 10 의 테스트)는 계획이 정한 것이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — `$TMPDIR/f7-plan1-ac-report.md`(지휘자가 준 `TMPDIR`. 없으면 이 worktree 의 `.claude/tmp/f7-ac-report.md`). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다(`## 결정 기록` · `## 지휘 기록` 은 고치지 않는다). PR 을 만들기 전에

`python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-18-official-switches-state-design.md <보고 파일 경로>`

를 돌려 경고를 사용자에게 보인다. PR 본문에는 「손으로 한 번」 확인하는 법 둘(설계 Verification Plan)과 J4 의 두 판 사이 사실을 적는다.

## 재지 못함

- 설치본을 `claude plugin disable` 로 끄면 진입 skill 이 보이지 않는지 · 설정의 `env` 칸 값이 skill 첫머리 줄에 닿는지 — 이 세션은 Claude Code 를 다시 띄울 수 없다. PR 본문에 사용자가 손으로 확인하는 법을 적는다(설계 Verification Plan 「손으로 한 번」).
- 샌드박스를 켠 세션에서 `.claude/worktrees/` 만들기가 되는지(설계 남는 한계) — 같은 이유.
- worktree 안 세션이 본 체크아웃의 `.claude/settings.local.json` 을 쓴다는 것(J9) — 공식 문서만 읽었다.
