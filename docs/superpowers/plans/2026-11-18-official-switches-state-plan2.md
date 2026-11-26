# 스위치와 상태 자리 이전 — 둘째 판(실제 은퇴) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 은퇴 예정이던 끄기 변수 20개를 실제로 은퇴시킨다 — 읽는 코드 · 펜스 · skill 과 reference 와 템플릿의 문장을 지우고, 켜져 있으면 「더 듣지 않는다 — 대신할 길」 을 보이며, spec-distill · quality-gates · plugin-audit 의 진입 skill 은 은퇴한 통째 끄기 변수가 켜져 있거나 끄기 변수 표를 못 읽었으면 계속할지 한 번 묻는다. 남는 7개는 지금과 똑같이 끈다.

**Architecture:** 은퇴의 주인은 첫 판이 만든 끄기 변수 표(`plugins/<X>/switches.md`)다 — 20개 행의 상태 칸을 `은퇴` 로 바꾸면 사전 검사(`shared/entry/entry_preflight.py`)가 이미 있는 「더 듣지 않는다」 줄을 낸다. 사전 검사의 `disabled` 감시줄 · 훅과 이름 붙은 자리의 판정 정본(`shared/killswitch/` 와 사본 셋) · 훅 해석기의 스위치 갈래는 지운다. project-init 훅은 은퇴 이름을 스크립트에 적지 않고 같은 표의 `은퇴` 행을 사전 검사 모듈로 읽는다. 감사 검사는 「skill 과 README 가 이름 댄 끄기 변수마다 읽는 코드가 있다」 를 새로 잰다.

**Tech Stack:** Python 3(사전 검사는 3.8 문법 바닥) · bash(macOS 3.2 호환) · 마크다운 표 · 셸 테스트 도구(`shared/tests/assert.sh`) · unittest · node(`audit-workflow.test.mjs`).

**Spec:** `docs/superpowers/specs/2026-11-18-official-switches-state-design.md` — 이 계획은 그 문서의 **둘째 판(AC18–AC27)** 만 한다. 첫 판(AC1–AC17)은 PR #301 로 머지됐다.

## Global Constraints

- 끄기 변수는 값이 정확히 `1` 일 때만 켜진 것이다. `DEVBREW_SKIP_HOOKS` 는 쉼표로 나누고 양끝 공백을 걷은 **전체 토큰** 대조다(설계 2) — 사전 검사의 표 읽기에 이미 있는 규칙을 그대로 쓴다.
- 사전 검사는 어느 경우에도 rc 0 이다. import 는 `os` · `subprocess` · `sys` 뿐이다. 3.8 문법으로 파싱돼야 한다.
- 남는 7개(별칭 `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` 포함)의 동작을 재는 기존 단언은 **바꾸지 않는다**(AC20). 바꿔야 통과하면 동작이 바뀐 것이다 — 멈추고 보고한다.
- 사람에게 보이는 글자는 설계가 정한 것과 이 계획의 「계획이 정한 글자」 표(G1–G7)뿐이다. 표에 없는 새 문장이 필요하면 멈추고 보고한다.
- 은퇴한 20개의 이름은 끄기 변수 표의 `은퇴` 행 · README 의 은퇴 표(아래 J2) · CHANGELOG 밖에 남지 않는다(AC18). 스위치 이름을 적는 새 코드는 쓰지 않는다 — 은퇴 이름이 필요한 코드는 표를 읽는다.
- **확인을 지우거나 합치거나 줄이는 커밋은 아래 「지우기 · 합치기 · 줄이기 표」 를 사용자가 승인한 뒤에만 만든다.** 승인 전에는 그 표에 없는 확인을 지우지 않는다. 사라지는 확인마다 `docs/removed-tests.md` 에 한 줄을 남긴다(그 파일의 줄 꼴).
- 끄기 변수 확인은 보안 갈래다(`docs/testing.md` 「보안 갈래」). 새로 쓰거나 고치거나 옮긴 보안 확인은 변이(삭제 · 추가 · 반전 · 형태 바꾸기)로 RED 를 보이고 양성 대조를 둔다. 「없어야 한다」 확인에는 「있을 때 잡힌다」 짝을 둔다.
- 리뷰 기준(`plugins/*/references/docreview-profiles/*`)과 agent 정의(`plugins/*/agents/*`)는 고치지 않는다 — 보호 줄 「Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다.」 는 남는 7개에 여전히 참이다. 고쳐야 할 일이 생기면 그 둘만 한 커밋에 모으고 앞뒤 뜻 대조를 과제 보고에 싣는다.
- 레포 락: `plugins/**/*.py` 에 `"python3"` 리터럴 금지 · `open(` · `.read_text(` 에 `encoding` 필수 · 같은 20줄(200자 이상) 블록 두 파일 금지 · 새 셸 테스트는 100755 · bash 3.2 에서 `$var` 바로 뒤 한글은 `${var}` · `set -u` 아래 빈 배열은 `${arr[@]+"${arr[@]}"}`.
- 판: 네 플러그인 모두 **major**. 번호는 머지 직전 기본 브랜치(`origin/main`) 위의 다음 major 다 — 이 계획에 박지 않는다(과제 16).
- 과제 안에서는 좁은 테스트와 **바꾼 파일을 코퍼스로 읽는 락**만 돈다(과제마다 「경계 락」 줄). 전체 스위트는 구현 담당이 돌지 않는다 — 지휘자가 공유 잠금 아래에서 돈다(과제 17). 꼭 돌아야 하면 먼저 `python3 tools/suite/suite_peers.py --list` 가 비었는지 보고, 지휘자가 준 잠금 자리로 `python3 plugins/spec-distill/scripts/suite_lock.py run --lock <지휘 자원 폴더>/suite-lock --owner <도는 agent 이름> --wait 3600 -- bash -c '<스위트 명령>'` 로만 돈다. 하위 agent 를 띄우면 이 줄을 그대로 싣는다.
- 커밋: 한국어 Conventional Commits(type · scope 는 영어) · pathspec 으로 커밋 · 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-18-official-switches-state-design.md`. 변이는 커밋한 뒤에 하고 `git checkout HEAD -- <파일>` + `git diff HEAD` 로 되돌림을 확인한다. 변이 테스트는 `PYTHONDONTWRITEBYTECODE=1`.
- 이 세션과 하위 agent 는 Claude Code 를 안에서 다시 띄워 잴 수 없다. 그런 측정은 「재지 못함」 으로 적는다.

## Review Focus

1. **개발자 셸에 은퇴 변수가 늘 켜져 있다**(예: `DEVBREW_SPEC_DISTILL_DISABLE=1` 을 export 한 채 개발) — 남는 테스트가 그 환경에서 거짓 RED · 거짓 GREEN 이 나면 안 된다. 깨끗한 환경 목록은 고정 목록이 아니라 표에서 도출한다(첫 판의 `test_entry_preflight.sh` 절 1 그대로) — 과제 2 가 표의 은퇴 행도 걷히는지 본다.
2. **은퇴한 통째 끄기 변수 + 화면 없는 실행** — 질문을 띄울 수 없으면 멈춰야 한다. 글로만 집행되는 자리라 과제 3 이 문장을 보안 갈래로 문다(문장 전체 · 자리 · 짝).
3. **project-init 표가 망가졌거나 없다** — 훅은 덧붙임 줄 없이 지금처럼 돌아야 한다(설계 3). 과제 12 가 망가진 표 · 표 없음 · 은퇴 행 없음을 본다.
4. **`DEVBREW_SKIP_HOOKS` 에 은퇴 토큰과 옛 토큰(`spec-distill:Stop`)이 섞여 있다** — 사전 검사는 은퇴 토큰 줄을, spec-review 진입 검사는 옛 토큰 알림을 내고, 어느 쪽도 끄지 않는다. 옛 토큰 알림은 은퇴한 이름을 권하지 않는다(과제 4).
5. **설치본에서 사전 검사 모듈이 훅 옆에 없다** — project-init 훅이 `scripts/entry_preflight.py` 를 import 하지 못하면 덧붙임 없이 돌아야 한다(과제 12).

---

## 다시 센 것 — 계획을 쓸 때(2026-11-26, 이 브랜치 끝 `b296938c`)

설계(2026-11-18 승인) 뒤 F3 둘째 계획 · F5 계획 넷이 앞단 skill 을 다시 짰다. 그 뒤의 나무를 직접 셌다. 셈은 추적 파일의 본문(심볼릭 링크 제외)에서 정확한 이름(뒤 글자가 `[A-Z0-9_]` 가 아닌 것)으로 했다. 과제 1 이 같은 방법으로 다시 센다.

**은퇴할 20개 — AC18 코퍼스(스크립트 · 펜스 · skill · reference · 템플릿)의 자리**

| 이름 | 자리(파일:수) | 테스트 · README · CHANGELOG · 기록 문서 |
|---|---|---|
| `DEVBREW_SPEC_DISTILL_DISABLE` | `scripts/control_plane.py:2` · `ledger_sweep.py:1` · `review_entry.py:2` · `shared/python/devbrew-python.sh:1`(주석) · project-init 사본 :1(주석) · skill `context-build:2` · `epic-conductor:1` · `intent-sync:2` · `reviewing-brief:1` · `roadmap-draft:1` · `roadmap-status:1` · `spec-review:3` · `references/epic-handoff.md:1` · `templates/roadmap-template.md:1` | 34 · 7 · 6 · 97 |
| `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC` | skill `intent-sync:2` · `reviewing-brief:1` · `spec-review:1` | 3 · 2 · 1 · 15 |
| `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW` | skill `reviewing-brief:2` · `context-build/references/finishing.md:1` | 5 · 2 · 2 · 13 |
| `DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE` | skill `intent-sync:3` · `templates/interview-seed-audit-template.md:1` | 3 · 2 · 3 · 20 |
| `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` | `review_entry.py:2` · skill `spec-review:1` | 5 · 5 · 6 · 24 |
| `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` | `review_entry.py:2` · skill `spec-review:1` | 9 · 6 · 6 · 48 |
| `DEVBREW_QUALITY_GATES_DISABLE_WEB` | `shared/docreview/scripts/run_docreview_codex_reviewer.sh:2` · skill `reviewing-brief:1` | 11 · 2 · 3 · 15 |
| `DEVBREW_SKIP_HOOKS=spec-distill:statusline` | `control_plane.py:1` · skill `roadmap-status:1` | 5 · 2 · 2 · 14 |
| `…=spec-distill:SessionEnd` · 별칭 `…:session-end-cleanup` | `ledger_sweep.py:2` | 7 · 4 · 7 · 39 |
| `DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc` | `ledger_sweep.py:1` | 3 · 2 · 4 · 19 |
| `DEVBREW_QUALITY_GATES_DISABLE` | `artifact_commit.sh:1` · `e2e-state.sh:2` · `intent_critic.py:1` · `publish-comment.sh:1` · `qg-gc.py:1` · `setup-qg.sh:2` · skill `artifact-critique:3` · `quality-pipeline:3` · 철학 P17:1 | 34 · 6 · 4 · 72 |
| `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER` | skill `quality-pipeline:5` | 3 · 4 · 6 · 21 |
| `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE` | `artifact_commit.sh:1` · skill `artifact-critique:3` | 5 · 2 · 2 · 9 |
| `DEVBREW_QUALITY_GATES_DISABLE_E2E` | `e2e-state.sh:2` · skill `quality-pipeline:1` | 10 · 4 · 2 · 24 |
| `DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC` | `intent_critic.py:1` · skill `quality-pipeline:1` | 6 · 2 · 4 · 13 |
| `DEVBREW_SKIP_HOOKS=quality-gates:qg-gc` | `qg-gc.py:1` | 6 · 5 · 3 · 20 |
| `DEVBREW_PLUGIN_AUDIT_DISABLE` | skill `plugin-audit:4` | 3 · 3 · 1 · 18 |
| `DEVBREW_PLUGIN_AUDIT_DISABLE_WEB` | `run_audit_codex_reviewer.sh:3` | 2 · 3 · 1 · 7 |
| `DEVBREW_PROJECT_INIT_DISABLE` | `hooks/post-tool-use.py:1`(docstring) · skill `project-init:1` · `templates/shared/pr-process.md:1` · `docs/git-workflow/pr-process.md:1` | 7 · 3 · 3 · 15 |
| `…=project-init:post-tool-use` · 별칭 `…:PostToolUse` | `hooks/post-tool-use.py:2`(docstring) | 6 · 4 · 8 · 12 |

- 맨이름 `DEVBREW_SKIP_HOOKS` 가 나오는 비테스트 코드: `shared/killswitch/kill_switch_active.py` 와 사본 셋(spec-distill · quality-gates · project-init) · `shared/python/devbrew-python.sh` 와 project-init 사본 · `entry_preflight.py:26`(표의 토큰 행 읽기) · `review_entry.py`(판정 + 옛 토큰 알림) · `control_plane.py` · `ledger_sweep.py` · `qg-gc.py` · `post-tool-use.py`. skill 다섯(`context-build` · `intent-sync` · `roadmap-draft` · `roadmap-status` · `spec-review`)의 「이 표가 보는 kill switch」 문장.
- 이름을 글자로 적지 않고 도출하는 자리: `entry_preflight.py` 의 `switch_name()` · `kill_switch_active.py` · 해석기의 `kill_switch_active()` · `shared/docreview/references/reviewing-document.md:17` 의 `DEVBREW_<HOST>_DISABLE` · `tools/adjudication/check_names.py` 의 `killswitch_keys()`(호출 리터럴에서 키를 도출).
- `kill_switch_active` 를 import 하는 곳: `review_entry.py:22` · `control_plane.py:42` · `ledger_sweep.py:31` · `qg-gc.py:32` · `post-tool-use.py:42`. 해석기는 `hooks.json` 의 `--plugin project-init --hook post-tool-use` 로 판정한다.

**남는 7개 — 읽는 코드**

| 이름 | 읽는 코드 |
|---|---|
| `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` | `plugins/spec-distill/scripts/codex-killswitch.conf` → `detect_codex.sh` |
| `DEVBREW_QUALITY_GATES_DISABLE_CODEX` | `plugins/quality-gates/scripts/codex-killswitch.conf` · `run_codex_reviewer.sh:2` |
| `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX` | `plugins/plugin-audit/scripts/codex-killswitch.conf` |
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST` | `e2e-state.sh:2` · `shared/test-selection/run-test-selection.sh:3` · skill 펜스 `quality-pipeline` |
| `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX` · 별칭 | `audit-sandbox.sh:7` · `run-own-tests.sh:2` |
| `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` | `publish-comment.sh:1` |
| `DEVBREW_SPEC_DISTILL_DISABLE_WEB` | `check_brief.py:2` · `run_docreview_codex_reviewer.sh:2` · skill `context-build:7` · `intent-sync:2` · `reviewing-brief:7` · reference `existing-first.md:1` · `steelman.md:2` |

**설계와 달라진 자리**(설계의 수용 기준 · 의도는 바뀌지 않는다고 판단했다 — 지휘자가 다시 본다)

1. 진입 skill 은 **아홉이 아니라 열**이다 — `request-framing` · `pm-interview` 가 `intent-sync` · `context-build` · `roadmap-draft` 셋이 됐다. spec-distill 여섯 · quality-gates 둘 · plugin-audit 하나 · project-init 하나. AC19 의 「진입 skill 아홉」 은 열로, 「계속할지 묻기」 대상은 아홉(spec-distill 여섯 + quality-gates 둘 + plugin-audit 하나)으로 읽는다. `test_switch_tables.sh` 절 E 는 이미 열을 문다(F5 가 고쳤다).
2. 끄기 변수 표의 웹 행 「끄는 것」 이 `컨텍스트 쌓기와 brief 리뷰의 웹 조사`, 워크트리 행이 `intent-sync 의 워크트리 질문` 으로 이미 바뀌었다(F5). `test_stage_words.sh` 가 표와 README 에서 「인터뷰」 를 막는다.
3. 설계는 `control_plane.py` · `review_entry.py` 를 「정본을 거치지 않고 변수 이름을 직접 적어 읽는 두 자리」 로 적었다. 지금은 둘 다 `kill_switch_active` 를 import 하고 **통째 끄기 변수만** 직접 읽는다(`control_plane.py:1247` · `review_entry.py:24,45`).
4. `shared/entry/check_invocation_surface.py:49-55` 의 `SENTINEL_ROWS` 가 진입 skill 마다 `[devbrew-entry] disabled` 행을 **요구한다** — 설계의 Files to Modify 에 없다. 과제 3 이 고친다.
5. `tools/adjudication/check_names.py` 가 `kill_switch_active()` 호출에서 kill switch 키를 도출한다 — 설계에 없다. 모듈이 지워지면 키가 빈다. 과제 12 가 고친다.
6. 수리 브랜치가 되살린 옛 하위 명령 `state_path.py interview-state` 와 옛 인자 `repo_defaults.py … interview_dir` 는 끄기 변수가 아니라 호출 이름이다 — 설계에 없으므로 **이 계획은 건드리지 않는다**.
7. 설계 3 이 「사전 검사가 끄기 변수 표를 읽지 못했다」 줄에도 묻기로 한 것은 첫 판의 `unreadable_line`(`[devbrew-switch] 끄기 변수 표를 읽지 못했다 — …`)이 이미 낸다.
8. AC18 은 「`DEVBREW_SKIP_HOOKS` 를 읽는 자리 하나(옛 토큰 알림)」 만 남는다고 적지만, 설계 2 · 3 은 사전 검사가 은퇴 토큰 행에 「더 듣지 않는다」 줄을 내고 project-init 훅이 표의 은퇴 행(토큰 포함)을 읽기를 요구한다. 이 계획은 AC18 을 「**끄는 판정**으로 읽는 코드는 0 · 알림으로 읽는 자리는 `review_entry.py`(옛 토큰) · `entry_preflight.py`(표 토큰 행) 둘이고, project-init 훅은 `entry_preflight.py` 를 import 해 쓴다」 로 읽는다(J1).

---

## 계획의 판단

설계에 없이 이 계획이 정한 것이다. 지휘자가 설계 안의 일인지 사용자에게 물을 일인지 가른다.

| # | 정할 것 | 정한 것 | 이유 |
|---|---|---|---|
| J1 | AC18 의 「읽는 자리 하나」 | 위 「달라진 자리」 8 | 설계 2 · 3 과 함께 지킬 수 있는 읽기 |
| J2 | README 의 「은퇴 표」 | README `## 끄는 길` 절의 표(`switches.md` 바이트 사본 — 첫 판의 절 C)의 `은퇴` 행. 따로 표를 더하지 않는다. 자세한 절(spec-distill 「끄는 법」 · quality-gates 「Kill switches」)에서는 20개 이름을 지운다 | 한 주인(표)과 그 사본. 같은 이름이 README 두 곳에 있으면 대조할 것이 늘어난다 |
| J3 | 진입 skill 이 「은퇴한 통째 끄기 변수 줄」 을 알아보는 법 | 은퇴 이름을 skill 에 적지 않고 줄 머리 `[devbrew-switch] 더 듣지 않는다 — <플러그인> 전체(` 로 알아본다. 표의 세 통째 끄기 행 「끄는 것」 이 정확히 `<플러그인> 전체` 임을 절 B2 가 문다 | AC18 이 skill 에 은퇴 이름을 금한다 |
| J4 | 「계속할지 묻기」 문장의 자리 | 각 진입 skill `## 진입 단계` 첫 문단 줄 끝(첫 판 문장 바로 뒤)에 한 문장(G1). 질문 꼴(G2)도 같은 문장 안 | 첫 판과 같은 자리 · 같은 꼴. 새 reference 를 두지 않는다 |
| J5 | `review_entry.py` 의 출력 | `disabled` · `reason` 를 빼고 `{"advisories": [...]}` 만 낸다. spec-review 펜스는 `review-entry: PROCEED` 만 낸다(진입 검사 자신이 실패하면 지금처럼 멈춤 — 그때의 줄은 지금 글 그대로). 파일 이름은 그대로 | 판정할 것이 없다. 늘 거짓인 칸을 남기지 않는다 |
| J6 | 해석기의 `--event` · `--plugin` · `--hook` 인자 | 받되 쓰지 않는다. `hooks.json` 은 고치지 않는다 | 훅 등록 파일을 건드리지 않는다(지휘 로드맵이 그 훅 파일을 예약한 적이 있다). 인자 뜻은 해석기 머리 주석에 한 줄 |
| J7 | intent-critic 의 건너뜀 사유 `kill-switch` | 더 만들지 않는다. 읽기 쪽 허용 값(`SKIP_REASONS`)에는 남기고 `state-file-format.md:121` 에 「옛 판이 남긴 값」 이라 적는다 | 옛 판이 쓴 돌려주는 꼴 파일을 새 판이 읽다 거부하지 않게 |
| J8 | e2e 의 `꺼짐(kill switch)` 칸 · `e2e-gate rc=3` | 그대로 — 차등 테스트 끄기(남음)가 여전히 e2e 부팅을 막는다. 문장의 「`DISABLE_E2E`」 갈래만 지운다 | 설계 1 「실행 자체를 막으려면 차등 테스트 끄기」 |
| J9 | 승인 게이트 정본의 「kill switch 예외 경로」 | `proceed-gate.md:109` · `intent-sync` · `reviewing-brief` · spec-review 의 예외 목록에서 `kill switch` 항목을 지운다 | 남는 7개 가운데 게이트를 건너뛰게 하는 것이 없다 |
| J10 | 철학 문서의 범위 | P13 · P21 에 더해 P17 의 `(전역 DEVBREW_QUALITY_GATES_DISABLE=1 은 전부를 끈다)` 도 고친다 | AC25 는 P13 · P21 만 적지만 P17 이 은퇴 이름을 권한다 |
| J11 | 저술 가이드 | 첫 판이 트리 두 줄을 고쳤다. 이 판은 `switches.md` 줄 끝에 「끄기 변수는 보안 컨트롤이다 — 이름마다 읽는 코드가 있어야 한다」 를 더한다 | AC25 의 「보안 컨트롤」 뜻이 가이드에 없다 |
| J12 | 감사 검사 새 요건의 이름 · 앵커 | `switches_have_readers` · 출처 `CLAUDE.md §런타임 상태 & 훅`. 이름 꼴은 `DEVBREW_` 로 시작하고 `DISABLE` 이 든 대문자 이름. 읽는 꼴은 첫 판 절 D 의 꼴(J8 의 간접 `.conf` 포함)과 같다 | 설계 5 와 첫 판 J8 |
| J13 | 옛 작업 사본 자리 | `qg-worktree.sh` · `audit-sandbox.sh` 의 옛 자리 치우기와 옛 경로 받기, `review-diff.sh` 의 옛 자리 알림, 감사 복사의 옛 자리 빼기, `setup-qg.sh` 의 `worktrees` 예약을 지운다(첫 판 J3 · J12–J14). `baseline-cache` 예약은 그대로 | 설계 4 「이 둘은 둘째 판에서 뺀다」 |
| J14 | 미룸 표의 「자기 사본 정의 맞추기」 행 | `is_registered_wt` 가 `git worktree list --porcelain` 의 `branch` 줄도 읽어, 브랜치를 쥔 같은 이름 worktree 는 이 세션 사본으로 빼지 않고 「이전 실행이 남긴 트리」 알림도 하지 않는다(사용자 worktree 와 같이 다룬다) | 설계 `## 미룸` 의 받는 곳이 이 판이다 |
| J15 | `test_old_gc` 의 모듈 | 같은 옛 커밋(`OLD_GC_COMMIT`)의 `kill_switch_active.py` 를 `git show` 로 꺼내 쓴다 | 옛 GC 를 돌려 보는 확인을 지키며 모듈을 지운다 |
| J16 | `dependencies.md` | 판 칸을 `check_deps.py measure` 로 다시 잰다(quality-gates major 가 spec-distill 표의 판 칸에 닿는다). 손으로 고치지 않는다 | 설계는 「고치지 않는 것」 에 적었지만 판 칸은 재는 값이다 — 지휘자 지시 |

---

## 계획이 정한 글자

설계에 글자가 없어 이 계획이 지었다. 지휘자가 가른다.

| # | 자리 | 글자 |
|---|---|---|
| G1 | 진입 skill 아홉의 `## 진입 단계` 첫 문단 줄 끝(`<P>` 는 그 플러그인 이름 글자) | `` 감시줄 아래에 `[devbrew-switch] 더 듣지 않는다 — <P> 전체(` 로 시작하는 줄이나 `[devbrew-switch] 끄기 변수 표를 읽지 못했다` 로 시작하는 줄이 있으면 그 줄을 보인 뒤 `AskUserQuestion` 으로 계속할지 한 번 묻고, 「계속한다」 를 고를 때만 간다 — 물을 수 없거나 답이 없으면 멈춘다. `` |
| G2 | 그 질문(같은 문장 뒤에 이어 적는다) | 질문 `끄던 변수가 켜져 있지만 더 듣지 않는다 — 계속하면 이 skill 이 그대로 돈다(codex · 웹 조사로 내용을 보내거나, 남의 코드를 돌리거나, PR 에 글을 올릴 수 있다). 계속할까?` · 선택지 `계속한다`(얻음: 이 skill 을 지금 쓴다 · 내줌: 꺼 두었다고 믿던 일이 돈다) · `멈춘다`(얻음: 아무것도 돌지 않는다 · 내줌: 변수를 풀거나 플러그인 끄기를 쓴 뒤 다시 불러야 한다). 추천 표시는 Q3 의 답을 따른다 |
| G3 | project-init 훅 — 알림이 있을 때 사람 채널(`systemMessage`) 끝에 덧붙이는 한 줄(켜진 은퇴 이름을 ` · ` 로 잇는다) | `[devbrew-switch] 더 듣지 않는다 — 플러그인 끄기를 쓴다(<이름들>)` |
| G4 | README 넷 — 표 아래의 첫 판 줄(「은퇴 예정 이름은 지금은 그대로 끈다 …」)을 바꾼 줄 | `은퇴 이름은 더 듣지 않는다 — 켜 두면 진입 skill 첫머리에 「더 듣지 않는다」 줄이 보인다. 「대신할 길」 칸을 쓴다.` · spec-distill · quality-gates · plugin-audit 만 이어서: `통째 끄기 변수가 켜져 있으면 진입 skill 이 계속할지 한 번 묻는다.` |
| G5 | `review_entry.py` 의 옛 토큰 알림의 대신할 길(`ALTERNATIVES`) | `설계문서 리뷰를 끄려면 /spec-distill:spec-review 를 부르지 않는다. 플러그인 전체는 Claude Code 의 플러그인 끄기(/plugin · claude plugin disable · 설정의 enabledPlugins).` |
| G6 | 리뷰 엔진의 재비판 건너뜀 사유(`docreview_route.py:548`) | `모델 판단` — 경고 줄은 `재비판이 돌지 않아 잘못된 지적을 걸러 내지 못했다 (doc-recritic: 모델 판단, skipped)` 가 된다 |
| G7 | 감사 검사 새 요건이 gap 일 때 감사 리포트에 실리는 이름 | 요건 이름 `switches_have_readers` 와 빠진 이름 목록(지금 `requirement` · `present` · `source_doc` 꼴에 `missing` 칸 하나를 더한다) |

---

## 사람에게 물을 것

구현 전에 답이 필요한 것은 Q1 이다. 나머지는 답이 오기 전에도 그 과제만 빼고 갈 수 있다.

- **Q1 — 지우기 · 합치기 · 줄이기 표(아래) 승인.** `docs/testing.md` 「지우기 · 합치기 · 줄이기의 승인과 기록」 의 표다. 판정 칸의 「설계가 동작을 없앰」 은 「값 대비 비용」 다섯 줄 어디에도 없는 사유다 — 보안 갈래 확인은 첫째 줄(못 댄다 → 지운다)을 쓸 수 없어서, 지키던 동작이 설계 3 으로 없어졌다는 사실로 적었다. 이 꼴로 승인받을지 함께 묻는다.
- **Q2 — PR #301 이 넘긴 글자 둘.** ① project-init 표의 `disableAllHooks` 칸 「(모든 플러그인의 훅이 함께 꺼진다)」 가 좁다 — 사용자가 설정에 직접 적은 훅도 끈다(P1 실측). 사용자 지정 상태줄도 꺼진다는 것은 확인되지 않았다(맞다면 spec-distill 상태줄에도 닿는다). 사용자가 정한 글자라 이 계획은 바꾸지 않았다 — 고칠지, 고친다면 글자를. ② README 넷의 「`claude plugin disable` 로 끈 뒤의 효과는 이 레포에서 재지 않았다」 단서 — 손으로 확인하면 지운다. 확인 전이라 이 계획은 그대로 둔다.
- **Q3 — G2 질문의 추천.** 「계속한다」 · 「멈춘다」 가운데 추천을 둘지. 추천이 있으면 첫 자리에 두고 라벨 끝에 「(권장)」 을 단다(`ask-sites.tsv` 종류 `꼬리`). 없으면 종류 `비움`.
- **Q4 — 진입 사전 검사 테스트 절 7 이 플러그인 셋만 돌던 것(PR #301 좁은 재리뷰).** 이 판에서 절 7 은 통째로 바뀐다(과제 2) — 네 플러그인을 다 돈다. 따로 물을 것은 없고 알리기만 한다.

---

## 다른 로드맵이 예약한 파일

이 계획이 고칠 파일 가운데 머지 전 에픽이 예약한 것이다(2026-11-26 `roadmap_status.py` 와 `gh pr list` 기준). 이음매 담당은 지휘자다.

| 파일 | 에픽 · 상태 | 고칠 문단 |
|---|---|---|
| `plugins/spec-distill/scripts/control_plane.py` | 지휘 로드맵 E2(구현 끝 · PR #341 은 이 파일을 안 고친다) | `switch_name()` 과 부르는 두 자리 |
| `plugins/spec-distill/skills/epic-conductor/SKILL.md` | 지휘 E2(PR #341 이 고친다) | 진입 단계 첫 문단 · 감시줄 판독 표의 `disabled` 행 · 「이 표가 보는 kill switch」 문장 |
| `plugins/spec-distill/references/epic-handoff.md` | 지휘 E2(PR #341 이 고친다) · E4(준비) | 머리 문단의 `DEVBREW_SPEC_DISTILL_DISABLE=1` 괄호 |
| `plugins/spec-distill/references/proceed-gate.md` | 지휘 E2 | 109행 예외 목록의 `kill switch` |
| `plugins/spec-distill/skills/roadmap-draft/SKILL.md` · `spec-review/SKILL.md` | 지휘 E4(준비) | 진입 단계 · 판독 표 · spec-review 진입 검사 절 |
| `plugins/spec-distill/dependencies.md` · `CHANGELOG.md` | 지휘 E3 · R5 · qg R7 · R9 | 판 칸(measure) · 이 판의 절 |
| `docs/plugin-authoring.md` | 지휘 R5(대기) · 테스트 방식 E3(PR #338 이 고친다) | `switches.md` 트리 줄 끝 |
| `plugins/quality-gates/scripts/setup-qg.sh` · `publish-comment.sh` · `intent_critic.py` | qg R7 · R8(설계 중) | 통째 끄기 · 의도 점검 끄기 갈래 · `worktrees` 예약 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `artifact-critique/SKILL.md` · `references/intent-critic.md` · `references/state-file-format.md` | qg R7 · R8 · R9(설계 중) | P1 · 보안 리뷰어 끄기 · e2e 끄기 · 의도 점검 끄기 문단 · E0 · 사유 값 |
| `plugins/{spec-distill,quality-gates}/README.md` · `plugin.json` · `CHANGELOG.md` | qg R7 · R8 · R9 · 지휘 E2(PR #341) | 끄는 길 · 자세한 스위치 절 · 판 · 이 판의 절 |
| `shared/tests/fixtures/ask-sites.tsv` | PR #341 이 고친다 | 새 질문 아홉 행 |
| `shared/tests/` · `plugins/*/tests/` | 테스트 방식 E3(구현 중) · E4(대기 — 있는 테스트 정리) · qg R7 · R9 | 아래 지우기 표의 파일들 |

예약과 어긋나는 것(로드맵 F7 칸 — 지휘자가 고친다): F7 칸의 `pm-interview` · `request-framing` SKILL 은 없어졌다 — 지금 이름은 `context-build` · `intent-sync` · `roadmap-draft` 와 내부 `reviewing-brief` 다. 칸에 없는데 이 계획이 고치는 파일: `plugins/{spec-distill,quality-gates,project-init}/scripts/kill_switch_active.py`(삭제) · `plugins/project-init/scripts/devbrew-python.sh` · `plugins/spec-distill/skills/{context-build,intent-sync,reviewing-brief,roadmap-draft}/SKILL.md` · `context-build/references/finishing.md` · `references/{epic-handoff,proceed-gate}.md` · `templates/{roadmap-template,interview-seed-audit-template}.md` · `plugins/quality-gates/scripts/{artifact_commit.sh,publish-comment.sh,intent_critic.py,review-diff.sh}` · `quality-pipeline/references/{intent-critic,state-file-format}.md` · `plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh` · `plugins/project-init/templates/shared/pr-process.md` · `docs/git-workflow/pr-process.md` · `shared/docreview/scripts/{run_docreview_codex_reviewer.sh,docreview_route.py}` · `shared/docreview/references/reviewing-document.md` · `shared/entry/check_invocation_surface.py` · `tools/adjudication/check_names.py` · `plugins/spec-distill/scripts/hook_common.py` · `docs/removed-tests.md` · 끄기 변수 표 넷 · CHANGELOG · plugin.json · `dependencies.md` 넷.

---

## 지우기 · 합치기 · 줄이기 표 (Q1 — 승인 뒤 구현)

판정 칸: 「없앰」 = 설계가 그 동작을 없앰(설계 3 · AC18 · AC21 — 지킬 동작이 없다). 겹침 칸: 없앰은 상대가 없어 「해당 없음」. 보안 칸은 `docs/testing.md` 「보안 갈래」 목록(끄는 스위치가 읽히는가)으로 판정했다. 줄 번호는 `b296938c` 기준이다.

| 테스트(파일 · 케이스) | 판정 | 지키던 것 | 겹침 상대를 열어 봤나 | 보안 확인 섞임 |
|---|---|---|---|---|
| `shared/tests/test_python_floor.sh` A1 · A1b(175-192) · A2 · A3(194-209) · A4a(211-222) · A13 · A16(236-249) · C2(706-716) · 736-753 | 없앰 | 해석기가 통째 끄기 변수 · `DEVBREW_SKIP_HOOKS` 토큰으로 훅을 끈다(PATH 없음 · 글롭 · 빈 이벤트 꼴 포함) | 해당 없음 | 예 — 전부 |
| 〃 축 C 루프(628-642) | 없앰 | 해석기 인자가 훅의 `kill_switch_active(...)` 인자와 같다 | 해당 없음 | 예 |
| `shared/tests/test_entry_preflight.sh` 2 · 9(지키는 파일 선언의 `kill_switch_active.py`) | 줄임(선언에서 뺌) | 정본 모듈이 바뀌면 이 테스트가 뽑힌다 | 해당 없음 | 예 |
| `plugins/project-init/tests/test_post_tool_use.py` `test_kill_switch_disable`(252-260) | 없앰 — 같은 자리에 AC22 테스트로 바꿔 쓴다 | 통째 끄기 변수면 훅이 `{}` | 해당 없음 | 예 |
| `plugins/project-init/tests/test_post_tool_use_branch.sh` 291-306 | 없앰 — AC22 테스트로 바꿔 쓴다 | 세 이름 각각이면 훅이 `{}` · git 호출 0 | 해당 없음 | 예 |
| `plugins/quality-gates/tests/e2e-scenarios.md` 시나리오 L(99-101) · V6(178-186) | 없앰 | 통째 끄기면 setup 이 거부 · 세션 폴더 없음 | 해당 없음 | 예 |
| `plugins/quality-gates/tests/test_artifact_commit.sh` 56-62 | 없앰 | 비평 끄기 · 통째 끄기면 커밋 sink 가 거부 | 해당 없음 | 예 |
| `plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh` 29-30 | 없앰 | E0 의 두 종료 문구 | 해당 없음 | 아니오 |
| `plugins/quality-gates/tests/test_e2e_docs.sh` 223-231 · 265-271 | 줄임(e2e 끄기 줄만 뺌 · 차등 테스트 줄 단언은 그대로) | SKILL 색인 · README 표가 두 스위치를 줄 전체로 싣는다 | 예(같은 케이스) | 아니오 |
| 〃 309-312 | 없앰 | README 범위 절의 e2e 끄기 문장 | 해당 없음 | 아니오 |
| `plugins/quality-gates/tests/test_e2e_state.sh` 107-120 · 370-381 | 줄임(반복 목록에서 `DISABLE_E2E` · `DISABLE` 를 뺌 · `DIFFERENTIAL_TEST` 는 그대로) | 세 변수 각각이면 지문 · 비교 · 부팅이 exit 3 | 예(같은 케이스) | 예 |
| 〃 121-127 · 173-183 | 합침 — 값 꼴(`true` · `1 ` · `01` · `yes` 는 끄지 않는다)을 `DIFFERENTIAL_TEST` 로 옮긴다 | 값이 정확히 `1` 일 때만 끈다 | 아니오 — 구현자가 연다(차등 테스트의 값 꼴 확인은 계획 때 찾지 못함) | 예 |
| `plugins/quality-gates/tests/test_entry_safety_e1_e6.sh` 138-146 · 263-269 · 319-330 | 없앰 | 통째 끄기면 setup · critique 인자가 거부 · qg-gc 토큰이 GC 를 끈다(부분 일치 아님) | 해당 없음 | 예 |
| `plugins/quality-gates/tests/test_intent_critic_wiring.sh` 26 · 54-56 · 129-133 | 없앰 | SKILL · README 가 의도 점검 끄기를 적는다 | 해당 없음 | 아니오 |
| 〃 291-336 · 360-471 · 519-532 · 576-584 | 없앰 | 의도 점검 끄기 · 통째 끄기면 gate · config · prepare 가 gh 를 부르지 않고 꺼짐 줄과 `reason: kill-switch` 를 쓴다(변이 g 포함) | 해당 없음 | 예 |
| `plugins/quality-gates/tests/test_intent_critic.py` `test_kill_switch_first`(1148-1158) | 없앰 | 끄기면 gate 가 꺼짐 줄을 쓴다 | 해당 없음 | 예 |
| `plugins/quality-gates/tests/test_intent_return.py` 92-153 · 758-834 | 없앰 | 끄기면 꺼짐 블록 · 두 이름 공시 · 값 꼴 · prepare 가 읽지 않음 · record 가 쓰지 않음 | 해당 없음 | 예 |
| 〃 `test_contract_and_session_dir`(248-259) | 바꿈 — 건너뜀 블록을 만드는 수단을 끄기 변수에서 `trivia` 갈래로 바꾼다(단언은 그대로) | 돌려주는 꼴 계약 · 세션 폴더 | 해당 없음 | 아니오 |
| `plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh` `case_security_kill_switch_routes_to_absent`(250-286) | 없앰 | 보안 리뷰어 끄기가 `absent` 로 간다 | 해당 없음 | 아니오 |
| `plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh` 파일 전체 | 없앰 | 모든 보안 리뷰어 dispatch 앞에 끄기 게이트가 선다(산문 락) | 해당 없음 | 아니오(보안 컨트롤의 문서 락) |
| `plugins/quality-gates/tests/test_plain_readme.sh` 118-122 | 줄임(의도 점검 끄기 행 단언만 뺌) | README 표의 의도 점검 끄기 행 | 예(같은 케이스) | 아니오 |
| `plugins/quality-gates/tests/test_plain_synth_output.sh` 164-165 | 없앰 | 통째 끄기면 setup 이 한 줄로 거부 | 해당 없음 | 예 |
| `plugins/quality-gates/tests/test_publish_comment_sink.sh` 162-174 | 줄임(전역 갈래만 뺌 · 게시 끄기 단언은 그대로) | 통째 끄기면 sink 가 `skipped: kill-switch` | 예(같은 케이스) | 예 |
| `plugins/quality-gates/tests/test_qg_critique_routing.sh` 36-41 | 없앰 | 통째 끄기면 critique 인자가 거부 | 해당 없음 | 예 |
| `plugins/quality-gates/tests/test_qg_gc.py` `test_kill_switch`(83-88) | 없앰 | 통째 끄기면 GC 가 지우지 않는다 | 해당 없음 | 예 |
| `plugins/spec-distill/tests/test_brief_review_entry.sh` 185-187 · `test_brief_review_meta.sh` T15(50-52) | 없앰 | brief 리뷰 끄기 경로 · README 문서화 | 해당 없음 | 아니오 |
| `plugins/spec-distill/tests/test_control_plane.sh` 167-184 · 변이 406-410 | 없앰 | 통째 끄기 · 지도 토큰이면 상태줄 빈 줄 · show 꺼짐 · `--tasks` rc 3 | 해당 없음 | 예 |
| `plugins/spec-distill/tests/test_epic_conductor_skill.sh` 65-66 · `test_request_framing_entry.sh` 42-43 · 137 · 195 | 없앰 | 판독 표 `disabled` 행 · 워크트리 끄기 문장 | 해당 없음 | 아니오 |
| `plugins/spec-distill/tests/test_kill_switches_v060.sh` 29-49 | 없앰(51-68 은 그대로) | 통째 끄기 · 세 토큰이면 원장 정리가 아무것도 안 지운다 · 남의 토큰은 안 끈다 | 해당 없음 | 예 |
| `plugins/spec-distill/tests/test_ledger_sweep.py` `test_kill_switches_spare_everything`(243-256) | 없앰 | 같은 것(파이썬 쪽) | 해당 없음 | 예 |
| `plugins/spec-distill/tests/test_review_entry.py` 55-81 | 없앰 | 진입 검사가 세 스위치로 끈다 · `=0` 은 안 끈다 | 해당 없음 | 예 |
| `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh` 188-199 | 없앰 | 정본 펜스가 세 스위치를 `DISABLED:<이름>=1` 로 낸다 | 해당 없음 | 예 |
| 〃 2 · 34 · 189 · 330-334(모듈 선언 · 복사) | 줄임 | 모듈이 바뀌면 뽑힌다 · 설치본 흉내에 모듈을 싣는다 | 해당 없음 | 예 |
| `plugins/spec-distill/tests/test_reviewing_brief_skill.sh` 106-111 · 452-458 | 줄임(은퇴 이름 단언만 뺌 · codex · 남는 웹 끄기 단언은 그대로) | brief 리뷰 공시 · 러너가 두 웹 끄기를 읽는다 | 예(같은 케이스) | 예(456-458) |
| `plugins/spec-distill/tests/test_reviewing_spec_disclosure.sh` 40-46 | 줄임(통째 끄기 단언만 뺌) | spec-review 공시 | 예(같은 케이스) | 아니오 |
| `plugins/spec-distill/tests/test_web_kill_switch.sh` 107-120 · 253-286 | 줄임(감사 러너 → 감사 웹 끄기 · qg 경로 docreview → qg 웹 끄기 갈래를 뺌 · spec-distill 웹 끄기는 그대로) | 호출부마다 웹 끄기가 web 을 off 로 바꾼다 | 예(같은 루프) | 예 |
| `shared/tests/test_docreview_codex.sh` 78-83 | 없앰 | qg 웹 끄기 하나로도 러너가 웹을 끈다 | 해당 없음 | 예 |
| `shared/tests/test_cost_disclosure.sh` 119 · 121 · 123-125 | 줄임(은퇴 리터럴만 뺌) | SKILL 의 규모 공시 근처 문구 | 예(같은 케이스) | 아니오 |
| `plugins/plugin-audit/tests/test_skill_orchestration.py` INVARIANTS 14 | 없앰 | SKILL 에 감사 통째 끄기 문자열이 있다 | 해당 없음 | 아니오 |
| `plugins/spec-distill/tests/test_end_gates.sh` 207 의 리터럴 | 없앰(AC23 — 그 문장이 지워진다) | 끝맺음이 엔진 사유에 「끄기 스위치가 아니라 모델 판단」 을 덧붙인다 | 해당 없음 | 아니오 |

바꿔 쓰는 것(지우기가 아니라 새 동작으로 단언을 고친다 — 승인 대상 밖, 과제가 적는다): `test_entry_preflight.sh` 절 7(88-105 — 통째 끄기 변수가 켜져도 `ok` 감시줄 + 「더 듣지 않는다」 줄 · 정본 모듈 오라클 대신 아는 글자) · `test_python_floor.sh` AC9(655-683 — 해석기를 일찍 끝내는 장치를 스위치 대신 「바닥 미만 해석기만 있는 PATH」 로) · `test_handoff_kill_switch.sh` 57-65(양성 짝을 남는 이름으로) · `test_ledger_sweep.py` `test_old_gc`(J15) · `test_review_entry.py` 98-173(대신할 길 문장을 G5 로) · `shared/tests/fixtures/docreview/cases.sh:3621`(G6) · `test_switch_tables.sh` 절 B · B2 · `shared/tests/test_invocation_surface.sh` 41-43 · `test_human_gate.sh` 129(그대로 둔다 — 끄지 못해야 할 미끼다) · `audit-workflow.test.mjs` 701-715(그대로 — 부재가 여전히 참).

깨끗한 환경 목록의 `unset` · `env -u`(B 갈래 — `test_ask_material_wiring.sh:28` 등 열둘)는 은퇴 이름을 담아도 해가 없다. **이 판에서 지우지 않는다**(AC18 의 코퍼스 밖 · 개발자 셸에 은퇴 변수가 남은 경우를 막는 장치다).

---

## 파일 표

| 파일 | 과제 | 하는 일 |
|---|---|---|
| `plugins/*/switches.md` · `plugins/*/README.md` | 2 · 4–10 · 16 | 20행 은퇴 · README 표 동기 · G4 · 자세한 절의 은퇴 이름 지움 |
| `shared/entry/entry_preflight.py` · `shared/tests/test_entry_preflight.sh` | 2 · 12 | `disabled` 감시줄 · `switch_name` 지움 · 절 7 |
| `shared/tests/test_switch_tables.sh` | 2 · 3 · 15 | 절 B · B2 · E2(새) · F(새) |
| 진입 skill 열 `SKILL.md` · `shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh` · `shared/tests/fixtures/ask-sites.tsv` | 3 | 판독 표 `disabled` 행 · 「이 표가 보는 kill switch」 문장 지움 · G1 · G2 |
| `plugins/spec-distill/scripts/review_entry.py` · `skills/spec-review/SKILL.md` | 4 | 진입 판정 지움 · 옛 토큰 알림 G5 |
| `plugins/spec-distill/scripts/{control_plane,ledger_sweep,hook_common}.py` | 5 | 스위치 갈래 지움 |
| spec-distill skill · reference · 템플릿 · `shared/docreview/references/reviewing-document.md` · `run_docreview_codex_reviewer.sh` | 6 | 문장 지움 · qg 웹 끄기 지움 |
| `shared/docreview/scripts/docreview_route.py` · `finishing.md` | 7 | G6 · 덧붙임 문장 지움 |
| quality-gates 스크립트 다섯 · `quality-pipeline` SKILL · references 둘 | 8 | 통째 · 보안 리뷰어 · e2e · 의도 점검 · qg-gc 끄기 지움 |
| `artifact_commit.sh` · `artifact-critique` SKILL | 9 | 비평 끄기 · 통째 끄기 지움 |
| `plugin-audit` SKILL · `run_audit_codex_reviewer.sh` | 10 | 통째 · 웹 끄기 지움 |
| `check-shape-completeness.py` · 그 테스트 · fixture · 감사 README | 11 | 새 요건 |
| `shared/killswitch/` · 사본 셋 · 해석기 둘 · `post-tool-use.py` · `check_names.py` · project-init SKILL · pr-process 둘 | 12 | 삭제 · 훅 덧붙임 줄 |
| `qg-worktree.sh` · `review-diff.sh` · `setup-qg.sh` · `audit-sandbox.sh` · 그 테스트 | 13 | 옛 자리 · 브랜치 쥔 같은 이름 |
| `docs/philosophy/devbrew-harness-philosophy.md` · `docs/plugin-authoring.md` | 14 | P13 · P17 · P21 · 가이드 한 구절 |
| `docs/removed-tests.md` | 4–13 | 사라지는 확인마다 한 줄 |
| `plugins/*/.claude-plugin/plugin.json` · `CHANGELOG.md` · `dependencies.md` | 16 | major · `Removed` · measure |

고치지 않는 것: `plugins/spec-distill/scripts/state_path.py` · `repo_defaults.py`(「달라진 자리」 6) · `plugins/plugin-audit/scripts/prepare-run-dir.py` · 리뷰 기준과 agent 정의 · `plugins/project-init/hooks/hooks.json`(J6) · 지휘 기계 상태와 스위트 대조 코드 · 값 변수 · 이미 있는 `docs/superpowers/roadmaps/*/roadmap.md` 의 끄기 문장(기록) · 깨끗한 환경 목록.

**경계 락**(과제마다 끝에 돈다 — 바꾼 파일을 코퍼스로 읽는 락까지): `bash shared/tests/test_switch_tables.sh` · `bash shared/tests/test_entry_preflight.sh` · `bash shared/tests/test_invocation_surface.sh` · `bash shared/tests/test_ask_recommendation.sh` · `bash shared/tests/test_charter_citations.sh` · `bash shared/tests/test_no_new_duplication.sh` · 그 과제가 고친 파일 이름을 담은 테스트(`git grep -l '<바꾼 파일의 바닥 이름>' -- shared/tests plugins/*/tests tools` 로 찾는다 · `# guards:` 줄 포함). 셸 테스트는 `bash <파일>`, 파이썬은 `python3 -m unittest <파일>`.

---

### Task 1: 다시 확인

**Files:** 없음(읽기만).

- [ ] **Step 1: 이름을 다시 센다** — 위 「다시 센 것」 표와 같은 방법(추적 보통 파일 · 정확 이름)으로 20개와 7개의 자리를 센다. 기대: 표와 같은 파일 목록. 다르면 다른 줄을 과제 보고에 적는다 — 새 파일이 생겼으면 그 파일이 어느 과제 몫인지 정해 적고 간다. **설계의 수용 기준이나 의도를 바꿔야 하는 차이**(예: 은퇴할 변수가 새 동작을 막게 됐다 · 진입 skill 이 하나 더 생겼는데 표가 없다)면 멈추고 지휘자에게 보고한다.
- [ ] **Step 2: 기준 수를 본다**
```bash
grep -l '^!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" ' plugins/*/skills/*/SKILL.md | wc -l   # 10
grep -c '\[devbrew-entry\] disabled' shared/entry/check_invocation_surface.py                                       # 1
git grep -n 'from kill_switch_active import' -- plugins shared                                                       # 다섯 줄
git grep -n 'kill_switch_active' -- tools                                                                            # check_names.py
```
- [ ] **Step 3: 보고** — 같으면 「다시 확인 — 계획과 같다」 한 줄. 커밋 없음.

---

### Task 2: 표 넷의 은퇴와 사전 검사

**AC:** AC19(사전 검사 쪽) · AC26(README 표 쪽)

**Files:** Modify `plugins/{spec-distill,quality-gates,plugin-audit,project-init}/switches.md` · README 넷의 `## 끄는 길` 절 · `shared/entry/entry_preflight.py` · Test `shared/tests/test_entry_preflight.sh` · `shared/tests/test_switch_tables.sh`

**Interfaces:** Produces — `entry_preflight.sentinel()` 은 `ok` · `error` 만 낸다. `read_table` · `active_names` · `switch_lines` · `table_path` 는 그대로(과제 12 의 훅이 import 한다).

- [ ] **Step 1: 실패하는 테스트**
  - `test_switch_tables.sh` 절 B: 기대값을 `("은퇴 예정", retiring, 0)` · `("은퇴", retired, 20)` 으로(97행 주석도). 절 B2: 20행의 상태를 `"은퇴"` 로. 세 통째 끄기 행은 상태와 함께 「끄는 것」 이 정확히 `spec-distill 전체` · `quality-gates 전체` · `plugin-audit 전체` 인지 따로 단언한다(J3 — G1 이 기댄다).
  - `test_entry_preflight.sh` 절 7(88-105)을 바꾼다: 네 플러그인마다 그 플러그인의 통째 끄기 변수(이름은 아는 글자 넷을 테스트에 적는다)를 `=1` 로 켜고 링크로 부르면 첫 줄이 `[devbrew-entry] ok plugin=<p> ` 로 시작하고, 둘째 줄이 `[devbrew-switch] 더 듣지 않는다 — <p> 전체` 로 시작하며 `). 대신: Claude Code 의 플러그인 끄기` 가 든다. 출력 어디에도 ` disabled ` 가 없다(양성 짝: 같은 실행의 `ok` 단언). 값 `true` · ` 1` · `0` · 빈 값이면 감시줄 한 줄뿐이다. `DEVBREW_SKIP_HOOKS=spec-distill:statusline` 은 `ok` 와 「더 듣지 않는다 — 상태줄과 로드맵 지도」 줄. 정본 모듈 import(93행) 오라클은 지운다.
- [ ] **Step 2: 실패를 본다** — `bash shared/tests/test_switch_tables.sh; bash shared/tests/test_entry_preflight.sh` · 기대: 위 단언의 `✗`.
- [ ] **Step 3: 구현** — 표 넷의 20행 상태 칸을 `은퇴` 로(다른 칸은 글자 그대로). 각 README 의 begin/end 사이를 표와 바이트로 맞추고, 표 아래 줄을 G4 로. `entry_preflight.py` 의 `sentinel` 에서 통째 끄기 갈래와 `switch_name()` 을 지우고 머리 docstring 의 kill switch 도출 문단(9–12행 뒷부분)을 지운다.
- [ ] **Step 4: 통과 · 출력 불변** — 두 테스트 `✗` 없음. 은퇴 변수가 하나도 없을 때의 출력이 고치기 전과 바이트로 같다(첫 판 Task 2 Step 6 의 꼴 — `git show HEAD:shared/entry/entry_preflight.py` 를 `$TMPDIR` 에 두고 네 플러그인 링크 자리에서 `cmp`).
- [ ] **Step 5: 변이** — 커밋 뒤 ① `sentinel` 에 통째 끄기 갈래를 되살린다 → 절 7 RED ② 표 하나의 통째 끄기 행 「끄는 것」 을 `전체 기능` 으로 → B2 RED ③ 은퇴 행 하나를 `은퇴 예정` 으로 → B RED. 양성 대조: 변이 없이 GREEN. 되돌리고 `git diff HEAD` 확인.
- [ ] **Step 6: 경계 락 · Commit** — `feat(entry): 끄기 변수 20개를 은퇴로 바꾸고 사전 검사의 통째 끄기 판정을 지운다`

---

### Task 3: 진입 skill 열 — 판독 표 · 계속할지 묻기

**AC:** AC19(skill 쪽)

**Files:** Modify 진입 skill 열(`plugins/plugin-audit/skills/plugin-audit` · `plugins/project-init/skills/project-init` · `plugins/quality-gates/skills/{artifact-critique,quality-pipeline}` · `plugins/spec-distill/skills/{context-build,epic-conductor,intent-sync,roadmap-draft,roadmap-status,spec-review}` 의 `SKILL.md`) · `shared/entry/check_invocation_surface.py:49-55` · `shared/tests/test_invocation_surface.sh:41-43` · `shared/tests/fixtures/ask-sites.tsv` · Test `shared/tests/test_switch_tables.sh`(새 절 E2) · `plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `test_request_framing_entry.sh`

- [ ] **Step 1: 실패하는 테스트 — 절 E2 `entry_skills_retired_question`** (보안 갈래: 글로만 집행되는 막는 자리다)
  - 진입 skill 은 절 E 와 같이 도출한다(10 이 아니면 `no`). 각 파일 전체에 `[devbrew-entry] disabled` · `이 표가 보는 kill switch` 가 없다. 양성 짝: 같은 파일에 `[devbrew-entry] ok` 행이 있다.
  - spec-distill · quality-gates · plugin-audit 의 아홉: `## 진입 단계` 절에 G1(그 플러그인 이름을 넣은 글자) 전체가 정확히 한 번, 첫 판 문장(절 E 의 `SENT`)과 **같은 줄**에서 그 뒤에 있다. 같은 줄에 G2 의 질문 글자와 두 선택지 라벨이 있다.
  - project-init: G1 의 앞머리 `` `[devbrew-switch] 더 듣지 않는다 — `` 가 없다(짝: 아홉에는 있다).
  - G1 의 `<P>` 와 표의 통째 끄기 행 「끄는 것」 이 같은 글자인지(그 플러그인 표를 `read_table` 로 읽어 견준다).
- [ ] **Step 2: 실패를 본다** — `bash shared/tests/test_switch_tables.sh` · 기대: E2 `✗`.
- [ ] **Step 3: 구현**
  - 열 파일의 판독 표에서 `[devbrew-entry] disabled …` 행을 지우고 「이 표가 보는 kill switch …」 문단(한 줄)을 지운다. 그 문단 뒷부분이 다른 스위치를 가리키면(spec-review 52행 · roadmap-status 49행) 그 갈래도 함께 지운다 — 남는 끄기 변수는 그 skill 의 `## kill switch` 류 절이 맡는다.
  - 아홉 파일의 `## 진입 단계` 첫 문단 줄 끝에 ` ` + G1 + ` ` + G2(질문 · 선택지 · 설명)를 붙인다. 새 줄을 만들지 않는다.
  - `check_invocation_surface.py` 의 `SENTINEL_ROWS` 에서 `"[devbrew-entry] disabled",` 를 지우고 `test_invocation_surface.sh` 의 fixture 행을 지운다.
  - `ask-sites.tsv` 에 아홉 행(종류는 Q3 의 답 — 답 전에는 `비움`, 앵커는 G2 의 질문 머리 `끄던 변수가 켜져 있지만 더 듣지 않는다`, 덮는 수 1, 설명 수 2).
  - `test_epic_conductor_skill.sh:65-66` · `test_request_framing_entry.sh:42-43` 을 지운다(표 승인 행).
- [ ] **Step 4: 통과 · 이웃 락** — `bash shared/tests/test_switch_tables.sh; bash shared/tests/test_invocation_surface.sh; bash shared/tests/test_ask_recommendation.sh; bash plugins/spec-distill/tests/test_epic_conductor_skill.sh; bash plugins/spec-distill/tests/test_request_framing_entry.sh; bash plugins/spec-distill/tests/test_stage_prose_trim.sh; bash plugins/spec-distill/tests/test_stage_words.sh` · 기대 `✗` 없음. 줄 상한 락이 있으면(`git grep -n 'LINE_CAP' -- plugins/*/tests`) 함께 돈다.
- [ ] **Step 5: 변이** — ① 한 파일의 G1 에서 `물을 수 없거나 답이 없으면 멈춘다` 를 지운다 ② G1 끝에 ` 다만 묻지 않아도 된다.` 를 붙인다 ③ project-init 에 G1 을 붙인다 ④ 한 파일에 `[devbrew-entry] disabled` 행을 되살린다 → 각각 E2 RED. 양성 대조 GREEN.
- [ ] **Step 6: 경계 락 · Commit** — `feat(skills): 진입 skill 이 통째 끄기 판독 행을 지우고 은퇴 변수가 켜져 있으면 계속할지 묻는다`

---

### Task 4: spec-review 진입 검사

**AC:** AC18(옛 토큰 알림 하나) · AC19

**Files:** Modify `plugins/spec-distill/scripts/review_entry.py` · `plugins/spec-distill/skills/spec-review/SKILL.md`(`## 진입 검사` 펜스와 128–137행 문단 · 472–475행) · `plugins/spec-distill/README.md`(「끄는 법」 의 「먼저」 절 · 「은퇴한 스위치」 절의 대신할 길 두 곳) · Test `plugins/spec-distill/tests/test_review_entry.py` · `test_reviewing_spec_entry_fence.sh` · `test_reviewing_spec_disclosure.sh`

**Interfaces:** Produces — `review_entry.py` stdout 은 `{"advisories": [str, ...]}` 한 줄(J5). `retired_advisories()` 는 인자를 받지 않는다. 상수 `ALTERNATIVES` = G5.

- [ ] **Step 1: 실패하는 테스트** — `test_review_entry.py`: 은퇴 토큰 일곱의 알림 케이스(98-173)의 대신할 길 기대 글자를 G5 로. 새 케이스 `test_retired_switches_do_not_disable`: 세 은퇴 이름(통째 · 설계 모드 · `review-entry` 토큰)을 켜도 출력 키가 `["advisories"]` 하나이고 알림이 비었다. `test_alternatives_name_no_retired_switch`: 옛 토큰 `spec-distill:Stop` 을 켰을 때 알림에 `DEVBREW_SPEC_DISTILL_DISABLE` · `DESIGN_MODE_DISABLE` · `spec-distill:review-entry` 가 없다(짝: `/spec-distill:spec-review` 와 `플러그인 끄기` 가 있다). `test_reviewing_spec_entry_fence.sh`: 세 은퇴 이름 각각에서 펜스 마지막 줄이 `review-entry: PROCEED`. 표 승인 행(55-81 · 188-199)을 지우고 모듈 복사 줄을 뺀다.
- [ ] **Step 2: 실패를 본다** — `python3 -m unittest plugins/spec-distill/tests/test_review_entry.py; bash plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh`
- [ ] **Step 3: 구현** — `review_entry.py` 에서 `kill_switch_active` import · `GLOBAL_VAR` · `DESIGN_MODE_VAR` · `ENTRY_TOKEN` · `disabled_reason()` 을 지우고, `retired_advisories` 의 `verdict` 를 지운다(리뷰는 늘 진행된다 — 「이번 리뷰는 진행된다.」 는 남긴다). 모듈 docstring 의 「끄는 스위치」 목록을 지운다. spec-review 펜스는 `DISABLED` 갈래를 빼고(진입 검사 실패 갈래는 지금 글 그대로), 128–137 문단에서 「끄는 스위치는 셋이고 …」 두 문장과 「정본 proceed-gate.md 의 kill switch 예외 경로다」 를 지운다. README 두 절도 같은 뜻으로.
- [ ] **Step 4: 통과** — Step 2 명령과 `bash plugins/spec-distill/tests/test_reviewing_spec_disclosure.sh` (40-46 의 통째 끄기 단언은 뺀다).
- [ ] **Step 5: 변이** — ① `ALTERNATIVES` 에 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` 을 되살린다 → `test_alternatives_name_no_retired_switch` RED ② `disabled_reason` 을 되살려 `review-entry` 토큰이면 끈다 → 펜스 테스트 RED.
- [ ] **Step 6: `docs/removed-tests.md` · 경계 락 · Commit** — `feat(spec-distill): spec-review 진입 검사가 은퇴 스위치로 끄지 않고 옛 토큰 알림이 새 길을 권한다`

---

### Task 5: spec-distill 스크립트의 스위치 갈래

**AC:** AC18

**Files:** Modify `plugins/spec-distill/scripts/control_plane.py:1246-1251,1306,1414-1420` · `ledger_sweep.py:13,31,53-55,252` · `hook_common.py:11` · `plugins/spec-distill/skills/roadmap-status/SKILL.md`(남은 지도 끄기 언급) · README 「스위치 목록」 의 세 줄 · Test `plugins/spec-distill/tests/test_control_plane.sh` · `test_kill_switches_v060.sh` · `test_ledger_sweep.py` · `test_default_branch.sh:159`

- [ ] **Step 1: 실패하는 테스트** — `test_control_plane.sh` 167-184 를 지우고 새 단언: 통째 끄기 · 지도 토큰을 켜도 `statusline` 이 빈 줄이 아니고 `show` 가 `꺼져 있다` 를 내지 않으며 `show --tasks` rc 가 0 이다(양성 짝: 같은 픽스처에서 변수 없이 같은 출력). `test_kill_switches_v060.sh` 29-49 를 지우고 새 케이스: 통째 끄기 · 세 토큰을 켜도 문서 없는 원장이 지워진다. `test_ledger_sweep.py` 243-256 를 같은 뜻의 `test_retired_switches_do_not_spare`로 바꾼다. `test_old_gc` 는 J15. 모듈 복사 줄(`test_control_plane.sh:39` · `test_default_branch.sh:159`)과 변이 406-410 을 지운다.
- [ ] **Step 2: 실패를 본다** — 세 파일.
- [ ] **Step 3: 구현** — `switch_name()` 과 두 호출 갈래 · `disabled()` 와 호출 · 두 import · docstring 의 kill switch 줄을 지운다. `hook_common.py` docstring 에서 `kill_switch_active` 항목을 지운다.
- [ ] **Step 4: 통과** · **Step 5: 변이** — ① `cmd_statusline` 에 `if os.environ.get(<통째 끄기>) == "1": print(""); return 0` 을 되살린다 → RED ② `main` 에 같은 꼴로 `return 0` → RED. 양성 대조 GREEN.
- [ ] **Step 6: removed-tests · 경계 락 · Commit** — `feat(spec-distill): 지도와 원장 정리가 은퇴한 스위치를 더 듣지 않는다`

---

### Task 6: spec-distill 글과 brief 리뷰의 웹 끄기

**AC:** AC18 · AC20(웹)

**Files:** Modify `plugins/spec-distill/skills/context-build/SKILL.md:51,607` · `intent-sync/SKILL.md:51,126,196,731,1456,1471-1475` · `reviewing-brief/SKILL.md:84-98,484,718` · `epic-conductor/SKILL.md`(과제 3 뒤 남은 것) · `roadmap-draft/SKILL.md`(같다) · `context-build/references/finishing.md:239` · `references/epic-handoff.md:3` · `references/proceed-gate.md:109` · `templates/roadmap-template.md:15` · `templates/interview-seed-audit-template.md:74` · `shared/docreview/references/reviewing-document.md:17,25` · `shared/docreview/scripts/run_docreview_codex_reviewer.sh:470-481` · README 「스위치 목록」 의 나머지 · Test `test_brief_review_entry.sh` · `test_brief_review_meta.sh` · `test_reviewing_brief_skill.sh` · `test_handoff_kill_switch.sh` · `test_web_kill_switch.sh` · `shared/tests/test_docreview_codex.sh` · `test_request_framing_entry.sh:137,195` · `shared/tests/test_cost_disclosure.sh:119`

- [ ] **Step 1: 실패하는 테스트** — `test_docreview_codex.sh` 78-83 을 지우고: `DEVBREW_QUALITY_GATES_DISABLE_WEB=1` 만 켜면 러너가 웹을 **끄지 않는다**(84-89 의 남는 이름 짝은 그대로). `test_reviewing_brief_skill.sh` 456-458 은 러너 소스가 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 을 읽고 `DEVBREW_QUALITY_GATES_DISABLE_WEB` 은 읽지 않는다. `test_handoff_kill_switch.sh` 57-65 의 양성 짝을 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 으로. 나머지는 표 승인 행을 줄인다.
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 구현** — 러너의 조건에서 qg 웹 끄기를 빼고 주석을 고친다. skill · reference · 템플릿의 문장은 **문장째** 지우고, 문장 안에 남는 끄기 변수 갈래가 있으면 그 갈래만 남긴다. `## kill switch` 절의 은퇴 줄을 지운다. `reviewing-brief` 의 brief 리뷰 끄기 갈래(펜스와 문장)를 지운다 — 리뷰는 늘 돈다(F4 의 건너뜀만 남는다). `intent-sync` 731 의 재비판 끄기 문장을 지운다 — 재비판 건너뜀은 모델 판단 길만 남는다. `proceed-gate.md` 와 두 skill 의 예외 목록에서 `kill switch` 를 지운다(J9). `reviewing-document.md:17` 을 `…_DISABLE_CODEX` · `…_DISABLE_WEB` 둘로, `:25` 의 「recritic kill switch 가 아니면」 을 「모델 판단으로 건너뛰지 않았으면」 으로. `epic-handoff.md:3` 의 괄호에서 변수 구절을 지운다(지휘자를 부르지 않고 손 절차로 갈 때). 로드맵 템플릿 15행의 끄기 문장을 지운다.
  - `test_stage_prose_trim.sh` 의 웹 kill switch 문장 락(111-131)은 남는 웹 끄기 문장이라 건드리지 않는다 — 그 펜스 첫 줄 앞에 줄을 더하지 않는다. 시험이 글자로 무는 이유 문장 열넷(PR #335 표)에 닿는 줄을 고쳐야 하면 멈추고 보고한다.
- [ ] **Step 4: 통과** — 위 테스트 파일 전부와 `bash plugins/spec-distill/tests/test_stage_prose_trim.sh; bash plugins/spec-distill/tests/test_stage_words.sh; bash plugins/spec-distill/tests/test_end_gates.sh`.
- [ ] **Step 5: 변이** — ① 러너 조건에 qg 웹 끄기를 되살린다 → `test_docreview_codex.sh` 새 단언 RED ② 러너가 spec-distill 웹 끄기를 안 읽게 → 84-89 RED(양성 대조).
- [ ] **Step 6: removed-tests · 경계 락 · Commit** — `feat(spec-distill): skill 글과 brief 리뷰에서 은퇴한 끄기 변수를 지운다`

---

### Task 7: 리뷰 엔진의 재비판 건너뜀 사유

**AC:** AC23

**Files:** Modify `shared/docreview/scripts/docreview_route.py:542,548` · `plugins/spec-distill/skills/context-build/references/finishing.md:495-496` · Test `shared/tests/fixtures/docreview/cases.sh:3621` · `plugins/spec-distill/tests/test_end_gates.sh:207` · `plugins/spec-distill/tests/test_reviewing_brief_residue.sh`(Q 절)

- [ ] **Step 1: 실패하는 테스트** — `cases.sh:3621` 기대를 `(doc-recritic: 모델 판단, skipped)` 로. `test_reviewing_brief_residue.sh` Q 절에 단언 둘: `--recritic-skipped` 라운드의 첫 줄에 `모델 판단` 이 있고 `kill switch` 가 없다(짝: 같은 줄에 `재비판이 돌지 않아`). `test_end_gates.sh:207` 의 리터럴을 지우고 `assert_not_contains "$B2" '끄기 스위치가 아니라 모델 판단'` (짝: 같은 창의 `「(경고에도 있다)」` 단언).
- [ ] **Step 2: 실패를 본다** — `bash shared/tests/test_docreview.sh`(cases.sh 를 부르는 러너 — `git grep -l 'cases.sh' -- shared/tests` 로 확인) · 나머지 둘.
- [ ] **Step 3: 구현** — `L.source_failed("doc-recritic", "모델 판단", primary=False)` · docstring 의 「kill switch ·」 를 「모델 판단 ·」 으로. 인자 이름 `--recritic-skipped` 는 그대로. `finishing.md` 495-496 의 두 줄(엔진 경고가 `kill switch` 로 나온다 · 덧붙임)을 지운다. 골든 파일에 `kill switch` 가 실린 것이 있으면 다시 뽑지 말고 그 글자만 고친다(지금은 없다 — `git grep -c 'kill switch' -- shared/tests/fixtures/docreview/golden` 0 을 확인).
- [ ] **Step 4: 통과** · **Step 5: 변이** — 사유를 `kill switch` 로 되돌린다 → 새 단언 둘 RED.
- [ ] **Step 6: 보안 리뷰 묶음 확인** — `git diff HEAD~1 --stat -- 'plugins/*/references/docreview-profiles' 'plugins/*/agents'` 가 비었는지(Global Constraints). 
- [ ] **Step 7: 경계 락 · Commit** — `fix(docreview): 모델 판단으로 건너뛴 재비판을 kill switch 가 아니라 모델 판단으로 적는다`

---

### Task 8: quality-pipeline — 통째 · 보안 리뷰어 · e2e · 의도 점검 · 정리 끄기

**AC:** AC18 · AC20(차등 테스트 · 게시)

**Files:** Modify `plugins/quality-gates/scripts/setup-qg.sh:15-16` · `e2e-state.sh:21,40` · `publish-comment.sh:35` · `intent_critic.py`(`KILL_ENV` · `GLOBAL_KILL_ENV` · `KILL_LINE` · `KILL_FAILURE` · `_kill_names` · `_killed` 와 부르는 곳 · 도움말 세 줄) · `qg-gc.py:13-16,32,88-89` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(P1 · 410–418 · 635 · 1375–1383) · `references/intent-critic.md:39,119,291` · `references/state-file-format.md:97,121` · README 「Kill switches (보안 컨트롤)」 · Test 표 승인 행의 qg 파일들

- [ ] **Step 1: 실패하는 테스트** — 새 단언: `test_e2e_state.sh` — `DISABLE_E2E=1` · 통째 끄기 `=1` 이어도 지문 · 부팅이 exit 3 이 아니다(짝: `DIFFERENTIAL_TEST=1` 이면 exit 3 — 기존 단언). 값 꼴 단언을 `DIFFERENTIAL_TEST` 로 옮긴다. `test_publish_comment_sink.sh` — 통째 끄기를 켜도 sink 가 `skipped: kill-switch` 를 내지 않는다(짝: 게시 끄기 단언). `test_qg_gc.py` — 통째 끄기 · qg-gc 토큰을 켜도 만료 폴더가 지워진다. `test_intent_return.py` · `test_intent_critic.py` — 의도 점검 끄기 · 통째 끄기를 켜도 gate 가 `intent-gate: run`(또는 그 실행의 정상 줄)을 낸다. setup — 통째 끄기를 켜도 세션 폴더를 만든다(`test_entry_safety_e1_e6.sh` 의 E1 양성 짝 꼴).
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 구현** — 각 스크립트의 은퇴 변수 갈래를 지운다(남는 변수 갈래는 글자 그대로). `intent_critic.py` 의 건너뜀 사유는 J7. SKILL 의 P1 문단 · 보안 리뷰어 끄기 문단과 각도 표 행 · `## kill switch` 의 세 줄을 지운다 — 보안 리뷰는 늘 돈다. e2e 칸 `꺼짐(kill switch)` 은 J8 로 둔다. references 두 파일의 의도 점검 꺼짐 행을 지우고 `state-file-format.md:121` 는 J7.
- [ ] **Step 4: 통과** — 표의 qg 파일 전부 · `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `bash plugins/quality-gates/tests/test_plain_readme.sh`.
- [ ] **Step 5: 변이** — ① `e2e-state.sh` 반복 목록에 `DISABLE_E2E` 를 되살린다 → RED ② `publish-comment.sh` 에 통째 끄기를 되살린다 → RED ③ `DIFFERENTIAL_TEST` 를 목록에서 뺀다 → 기존 단언 RED(양성 대조 — AC20).
- [ ] **Step 6: removed-tests · 경계 락 · Commit** — `feat(quality-gates): 통째 끄기 · 보안 리뷰어 · e2e · 의도 점검 · 정리 끄기를 은퇴시킨다`

---

### Task 9: artifact-critique — 비평 끄기

**AC:** AC18

**Files:** Modify `plugins/quality-gates/scripts/artifact_commit.sh:15-21` · `plugins/quality-gates/skills/artifact-critique/SKILL.md:10,67-72,81-85,378` · Test `test_artifact_commit.sh` · `test_critiquing_artifacts_skill.sh` · `test_qg_critique_routing.sh` · `shared/tests/test_cost_disclosure.sh:123-125`

- [ ] **Step 1: 실패하는 테스트** — `test_artifact_commit.sh`: 비평 끄기 · 통째 끄기를 켜도 sink 가 커밋한다(HEAD 가 움직인다 — 56-62 의 반대 단언, 짝: 기존 정상 커밋 단언). 나머지는 표 승인 행.
- [ ] **Step 2–4** — sink 의 끄기 갈래와 머리 주석 F-H 를 지우고, SKILL 의 `## kill switch` 절과 E0 를 지운다(E0 가 하던 다른 일이 있으면 그 일만 남긴다). description 의 `+ kill switch` 와 378행 종료 목록의 `kill switch` 를 지운다 — description 을 고치면 `shared/tests/test_invocation_surface.sh` 를 함께 돈다.
- [ ] **Step 5: 변이** — sink 에 비평 끄기를 되살린다 → RED.
- [ ] **Step 6: removed-tests · 경계 락 · Commit** — `feat(quality-gates): 문서 비평 끄기를 은퇴시킨다`

---

### Task 10: plugin-audit — 통째 · 웹 끄기

**AC:** AC18 · AC20(codex · 샌드박스)

**Files:** Modify `plugins/plugin-audit/skills/plugin-audit/SKILL.md:79,95,306-310` · `plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh:37,116-125` · README · Test `test_skill_orchestration.py:14` · `plugins/spec-distill/tests/test_web_kill_switch.sh`(감사 러너 행)

- [ ] **Step 1: 실패하는 테스트** — 감사 러너: `DEVBREW_PLUGIN_AUDIT_DISABLE_WEB=1` 을 켜도 codex 호출의 웹이 켜진 채다(`test_web_kill_switch.sh` 의 관측 꼴 — 감사 러너 행을 「웹 끄기 없음」 으로 바꾼다). codex 끄기 짝: `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX=1` 이면 codex 를 부르지 않는다(기존 단언).
- [ ] **Step 2–4** — 러너의 웹 끄기 갈래와 주석을 지운다(웹은 프로필대로). SKILL 의 phase 0 1 번 항목 · 95행 괄호 · `## kill switch` 의 통째 끄기 줄을 지운다(1 번을 지우면 뒤 번호를 당긴다 — 그 번호를 무는 테스트를 `git grep -n 'phase 0' -- plugins/plugin-audit/tests` 로 찾는다).
- [ ] **Step 5: 변이** — 러너에 웹 끄기를 되살린다 → RED.
- [ ] **Step 6: removed-tests · 경계 락 · Commit** — `feat(plugin-audit): 통째 끄기와 감사 웹 끄기를 은퇴시킨다`

---

### Task 11: 감사 검사 — 이름 댄 끄기 변수마다 읽는 코드

**AC:** AC24

**Files:** Modify `plugins/plugin-audit/scripts/check-shape-completeness.py` · `plugins/plugin-audit/README.md`(감사 기준 줄) · Test `plugins/plugin-audit/tests/test_check_shape_completeness.py` · Create fixture `plugins/plugin-audit/tests/fixtures/switch-readers/{reads,nowhere,comment-only,indirect}/`

**Interfaces:** Produces — `CHECKLIST` 끝에 `("switches_have_readers", "CLAUDE.md §런타임 상태 & 훅")`. 함수 `_switch_readers_gaps(pd) -> list[str]`(읽는 곳이 없는 이름 목록, 정렬). gap 항목에 `missing` 칸(G7).

- [ ] **Step 1: 실패하는 테스트** — fixture 넷(각각 `.claude-plugin/plugin.json` · `README.md` · `skills/x/SKILL.md` · `switches.md`): `reads`(SKILL 이 `DEVBREW_FX_DISABLE_A` 를 이름 대고 `scripts/a.sh` 가 `"${DEVBREW_FX_DISABLE_A:-}"` 를 읽는다) → present · `nowhere`(이름만) → gap, `missing == ["DEVBREW_FX_DISABLE_A"]` · `comment-only`(스크립트의 `#` 주석과 `echo` 줄에만) → gap · `indirect`(`scripts/x.conf` 의 `K=DEVBREW_FX_DISABLE_A` + `scripts/b.sh` 의 `${!K`) → present. 은퇴 행: `switches.md` 에 `은퇴` 로 실린 이름을 SKILL 이 이름 대도 gap 이 아니다. `test_checklist_names` 를 일곱 이름으로. 이 레포의 네 플러그인 모두 `switches_have_readers` 가 present(`python3 plugins/plugin-audit/scripts/check-shape-completeness.py plugins/<p>`).
- [ ] **Step 2: 실패를 본다** — `python3 -m unittest plugins/plugin-audit/tests/test_check_shape_completeness.py`
- [ ] **Step 3: 구현** — 이름 꼴(J12)을 `skills/*/SKILL.md` 전체와 `README.md` 에서 모은다. `switches.md` 의 `은퇴` 행 이름은 뺀다(표는 사전 검사 모듈 없이 이 스크립트가 스스로 읽는다 — 감사 대상은 다른 플러그인일 수 있다. 머리줄 · 상태 칸만 본다). 읽는 꼴은 첫 판 `test_switch_tables.sh` 절 D 와 같다 — 플러그인 폴더의 스크립트(링크는 대상 내용)와 skill 펜스(```` ```bash ```` 안)에서 찾고, `entry_preflight.py` · `switches.md` 는 세지 않는다. `#` 로 시작하는 줄과 첫 낱말이 `echo` · `printf` · `print(` 인 줄은 세지 않는다. 절 D 와 글자를 맞춰 베끼지 않는다(중복 락).
- [ ] **Step 4: 통과** — Step 2 · `bash shared/tests/test_switch_tables.sh` · `node --test plugins/plugin-audit/tests/audit-workflow.test.mjs`.
- [ ] **Step 5: 변이** — ① 주석 줄 거르기를 지운다 → `comment-only` RED ② 간접 꼴을 지운다 → `indirect` RED ③ 은퇴 행 빼기를 지운다 → 이 레포의 project-init 이 gap(RED). 양성 대조 GREEN.
- [ ] **Step 6: 경계 락 · Commit** — `feat(plugin-audit): 이름 댄 끄기 변수마다 읽는 코드가 있는지 감사 검사가 잰다`

---

### Task 12: 판정 정본 · 해석기 삭제와 project-init 훅

**AC:** AC21 · AC22 · AC18

과제 4 · 5 · 8 뒤에 한다(그 과제들이 `kill_switch_active` import 를 지운다).

**Files:** Delete `shared/killswitch/kill_switch_active.py` · `plugins/{spec-distill,quality-gates,project-init}/scripts/kill_switch_active.py` · Modify `shared/python/devbrew-python.sh:12-14,28-87` · `plugins/project-init/scripts/devbrew-python.sh`(같은 곳 — `copy-of` 사본) · `plugins/project-init/hooks/post-tool-use.py:25-28,41-42,608-611` 과 `main` 끝 · `tools/adjudication/check_names.py:49-116` · `plugins/project-init/skills/project-init/SKILL.md`(과제 3 뒤 남은 것) · `plugins/project-init/templates/shared/pr-process.md:61` · `docs/git-workflow/pr-process.md`(같은 문장) · `plugins/project-init/README.md`(설치된 Hook 절의 끄기 줄) · Test `shared/tests/test_python_floor.sh` · `shared/tests/test_entry_preflight.sh:2,9` · `plugins/project-init/tests/test_post_tool_use.py` · `test_post_tool_use_branch.sh` · `shared/tests/test_dispatch_name_defined.sh` · `plugins/spec-distill/tests/test_ledger_sweep.py`(J15)

**Interfaces:** Consumes — 과제 2 의 `entry_preflight.read_table(path, plugin)` · `active_names(row, environ)`. Produces — `post-tool-use.py` 의 `retired_notice(environ) -> str | None`(G3 한 줄 또는 None).

- [ ] **Step 1: 실패하는 테스트**
  - `test_post_tool_use.py` `test_kill_switch_disable` 자리에: `test_retired_switch_still_runs` — 통째 끄기 `=1` 을 켜고 브랜치 알림이 나는 입력을 주면 `systemMessage` 가 지금 알림으로 시작하고 마지막 줄이 `[devbrew-switch] 더 듣지 않는다 — 플러그인 끄기를 쓴다(DEVBREW_PROJECT_INIT_DISABLE=1)`. `test_retired_switch_silent_without_notice` — 같은 변수에 알릴 것이 없는 입력이면 출력이 `{}`. `test_retired_token_alias` — `DEVBREW_SKIP_HOOKS=project-init:PostToolUse` 면 괄호 안이 `DEVBREW_SKIP_HOOKS=project-init:PostToolUse`. `test_table_unreadable_no_suffix` — 임시 사본 플러그인 폴더(훅 · scripts 링크 해제 사본 · 망가진 `switches.md` / 표 없음 / `entry_preflight.py` 없음)에서 알림은 나되 덧붙임 줄이 없다.
  - `test_post_tool_use_branch.sh` 291-306 을 같은 뜻으로(세 이름 각각 — 훅이 돈다 · git 호출이 있다).
  - `test_python_floor.sh`: 표 승인 블록을 지우고 새 단언 — 통째 끄기 · `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` 를 켜도 해석기가 바닥 해석기로 훅을 exec 한다(기존 A5 류의 「exec 됐다」 관측 꼴). AC9 의 조기 종료 장치를 「바닥 미만 해석기만 있는 PATH」 로 바꾼다. 해석기 본문에 `DISABLE` · `SKIP_HOOKS` · `kill_switch_active` 가 없다(짝: `FLOOR_MAJOR=` 가 있다).
  - `test_entry_preflight.sh` 2 · 9 행에서 모듈을 뺀다.
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 구현**
  - 모듈 넷을 `git rm`. 해석기 둘의 kill switch 절(28–87행)과 12–14행의 kill switch 언급을 지우고, 인자 파싱은 J6 대로 두며 머리 주석에 「`--event` · `--plugin` · `--hook` 은 받되 쓰지 않는다(훅 등록 파일과의 호환)」 한 줄. 두 파일은 `copy-of` 사본이라 함께 고친다.
  - 훅: import 와 첫 판정을 지우고 docstring 의 Kill switches 절을 지운다. `retired_notice`: `sys.path` 의 `scripts` 에서 `entry_preflight` 를 import 하고(실패하면 None), `read_table(<훅 두 단계 위>/switches.md, "project-init")` 의 `state == "은퇴"` 행마다 `active_names` 를 모은다. 어떤 예외든 None. 모은 것이 있으면 G3. `main` 에서 `human` 이 비지 않았을 때만 `human.append(notice)`.
  - `check_names.py`: `killswitch_keys()` · `_is_killswitch_call` · `allow_killswitch` 갈래를 지우고 그 결과를 쓰던 README 참조 판정이 은퇴 표의 이름을 dangling 으로 세지 않는지 `bash shared/tests/test_dispatch_name_defined.sh` 로 본다. 세면 README 의 은퇴 표(begin/end 사이)를 그 판정에서 빼는 한 갈래를 더한다.
  - project-init SKILL · pr-process 두 파일 · README 의 은퇴 이름 문장을 지운다(pr-process 의 괄호는 「Hook 이 우회되거나(플러그인 끄기 · …)」 꼴로 남는 뜻만). 두 pr-process 파일의 같음을 무는 테스트가 있으면 함께 돈다(`git grep -l 'pr-process.md' -- plugins/project-init/tests shared/tests`).
- [ ] **Step 4: 통과** — 위 테스트 전부 · `bash shared/tests/test_copy_of_contract.sh` · `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `bash shared/tests/test_check_deps.sh` · `python3 -m unittest plugins/spec-distill/tests/test_ledger_sweep.py`.
- [ ] **Step 5: 변이** — ① 해석기에 통째 끄기 `exit 0` 을 되살린다 → 새 단언 RED ② `retired_notice` 의 `state == "은퇴"` 를 `"남음"` 으로 → RED ③ `human` 이 빌 때도 덧붙이게 → `silent_without_notice` RED ④ 망가진 표에서 예외를 삼키지 않게 → `table_unreadable` RED(훅 rc≠0). 양성 대조 GREEN.
- [ ] **Step 6: removed-tests · 경계 락 · Commit** — `feat(shared): kill switch 판정 정본과 해석기의 스위치 갈래를 지우고 project-init 훅이 은퇴 변수를 알린다`

---

### Task 13: 옛 작업 사본 자리와 브랜치 쥔 같은 이름

설계 4 「이 둘은 둘째 판에서 뺀다」 · 설계 `## 미룸` 의 이 판 몫(J13 · J14).

**Files:** Modify `plugins/quality-gates/scripts/qg-worktree.sh:7,139-141,217,238` · `review-diff.sh:229-230,251,264-288` · `setup-qg.sh:217-218` · `plugins/plugin-audit/scripts/audit-sandbox.sh:16,137-140,157-159,541,558` · Test `plugins/quality-gates/tests/test_qg_worktree_helper.sh` · `test_review_diff.sh` · `test_entry_safety_e1_e6.sh`(예약 이름) · `plugins/plugin-audit/tests/test_audit_sandbox_create.sh` · `test_audit_sandbox_mutation_guard.sh`

- [ ] **Step 1: 실패하는 테스트** — `remove` 가 옛 자리 경로(`.claude/quality-gates/worktrees/base-x` · `.claude/plugin-audit/worktrees/rt-x`)를 거부하고 그 폴더가 그대로다. 만들기가 옛 자리의 같은 세션 사본을 지우지 않는다. `review-diff` 가 옛 자리의 등록 사본을 「이전 실행이 남긴 트리」 로 알리지 않고 다른 추적 안 된 경로처럼 다룬다. `.claude/worktrees/qg-base-<세션8>` 이름으로 **브랜치를 쥔** worktree 를 두면 리뷰 범위가 그것을 이 세션 사본으로 빼지 않고 `git worktree remove` 를 권하지 않는다(짝: 같은 이름의 detached 등록 사본은 지금처럼 뺀다). `setup-qg.sh` 가 세션 id `worktrees` 를 받는다(`baseline-cache` 는 여전히 거부 — 짝).
- [ ] **Step 2–4** — 옛 자리 상수 · 갈래 · 주석을 지운다. `is_registered_wt` 가 `branch ` 줄을 읽어 브랜치를 쥔 등록 worktree 는 거짓을 낸다(J14). 사본 경로를 다루는 기존 단언은 바꾸지 않는다 — 옛 자리를 묻던 단언만 표 승인 꼴로 뒤집는다(이 단언들은 첫 판이 「한 판」 동안 둔 것이라 지우기 표 밖의 「바꿈」 이다).
- [ ] **Step 5: 변이** — ① `is_registered_wt` 의 branch 갈래를 지운다 → RED ② `remove` 가 옛 자리를 다시 받게 → RED. 양성 대조 GREEN.
- [ ] **Step 6: 경계 락 · Commit** — `refactor(worktrees): 옛 사본 자리 처리를 지우고 브랜치를 쥔 같은 이름 worktree 를 자기 사본으로 세지 않는다`

---

### Task 14: 철학 문서와 저술 가이드

**AC:** AC25

**Files:** Modify `docs/philosophy/devbrew-harness-philosophy.md:47-48,51,59-60` · `docs/plugin-authoring.md:13` · Test `plugins/quality-gates/tests/test_governance_no_capability_caps.sh`

- [ ] **Step 1: 실패하는 테스트** — 새 단언(철학 문서의 `### P13 —` · `### P21 —` 절과 가이드 트리를 떠서): 셋 어디에도 `per-plugin kill switch` · `hooks kill switch` · `어떤 훅도 inspect해서 거부할 수 없고` · `DEVBREW_<PLUGIN>_DISABLE=1` 이 없다. P13 절에 `플러그인 끄기` 가, P21 절에 `끄기 변수는 보안 컨트롤` 이, 가이드 트리에 `플러그인 끄기` 와 `보안 컨트롤` 이 있다(양성 짝). P17 절에 `DEVBREW_QUALITY_GATES_DISABLE=1` 이 없다.
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 구현** — 뜻만 바꾼다(설계 5 의 CLAUDE.md 글머리를 따라): P13 의 「per-plugin kill switch」 → 「통째 끄기는 Claude Code 의 플러그인 끄기」 · 「사전 검사가 kill switch 를 모델 판단 밖에서 집행한다」 → 「사전 검사가 켜진 끄기 변수를 모델 판단 밖에서 보인다」. P21 의 「kill switch는 보안 컨트롤이라 어떤 훅도 inspect해서 거부할 수 없고」 → 「끄기 변수는 보안 컨트롤이라 읽는 코드가 그 값을 무시할 수 없고」 · 코드 줄의 `hooks kill switch` → `끄기 변수 표(switches.md)`. P17 의 괄호 → 「(플러그인 전부를 끄는 길은 플러그인 끄기다)」. 가이드는 J11. 철학 문서의 `## 목차` 는 절 이름이 바뀌지 않아 그대로다.
- [ ] **Step 4: 통과** — Step 1 테스트 · `bash shared/tests/test_charter_citations.sh`.
- [ ] **Step 5: 변이** — P21 에 옛 구절을 되살린다 → RED.
- [ ] **Step 6: Commit** — `docs(philosophy): P13 · P17 · P21 과 저술 가이드를 공식 플러그인 끄기와 끄기 변수 규칙에 맞춘다`

---

### Task 15: 은퇴 이름의 부재와 남는 이름의 양성 짝

**AC:** AC18 · AC20

**Files:** Test `shared/tests/test_switch_tables.sh`(새 절 F `retired_names_absent`)

- [ ] **Step 1: 테스트를 쓴다** — 코퍼스: `git ls-files` 의 보통 파일 가운데 `plugins/*/{skills,references,templates,scripts,hooks,agents}/**` · `shared/**`(`/tests/` 와 `README` · `CHANGELOG` · `switches.md` 를 뺀다) · `tools/**`(테스트 뺀다) · `docs/git-workflow/**` 전체의 **본문 전체**(펜스 안팎 모두). 은퇴 이름: 절 B2 의 기대표에서 상태 `은퇴` 인 행의 이름 전부(별칭 포함 — 토큰 행은 `DEVBREW_SKIP_HOOKS=` 뒤 토큰 글자로도 찾는다). 단언: ① 어느 은퇴 이름도 코퍼스에 없다(정확 이름 경계) ② 맨이름 `DEVBREW_SKIP_HOOKS` 가 나오는 파일 집합이 정확히 `{plugins/spec-distill/scripts/review_entry.py, shared/entry/entry_preflight.py}` 다(J1 — 등호) ③ 양성 짝: 남는 7개(별칭 포함) 각각이 코퍼스에 한 번 이상 있다 ④ 계측기 양성 대조: 임시 사본 코퍼스에 은퇴 이름 하나를 넣으면 ① 이 잡는다(테스트 안에서 문자열로 한 번 돈다).
- [ ] **Step 2: 돈다** — `bash shared/tests/test_switch_tables.sh` · 기대 `✗` 없음. RED 면 남은 자리를 그 자리의 과제 뜻으로 고친다(새 문장을 짓지 않는다 — 지우기만. 짓게 되면 멈추고 보고).
- [ ] **Step 3: 변이** — ① `templates/roadmap-template.md` 에 통째 끄기 문장을 되살린다 → ① RED ② `control_plane.py` 에 `DEVBREW_SKIP_HOOKS` 한 줄 → ② RED ③ `codex-killswitch.conf` 하나의 키 줄을 주석으로 → ③ RED.
- [ ] **Step 4: Commit** — `test(switches): 은퇴한 끄기 변수 이름이 코드와 글에 없고 남는 일곱은 있음을 못 박는다`

---

### Task 16: 기본 브랜치를 합치고 판 · CHANGELOG · README 공시 · 의존 표

**AC:** AC26

PR 을 만들기 직전에 한다.

**Files:** Modify `plugins/*/.claude-plugin/plugin.json` · `plugins/*/CHANGELOG.md` · `plugins/*/dependencies.md` · README 넷(공시 확인)

- [ ] **Step 1: 합친다** — `git fetch origin && git merge origin/main`. 같은 판으로 올린 `plugin.json` 은 충돌 목록에 안 뜰 수 있다 — Step 2 에서 직접 견준다.
- [ ] **Step 2: 판** — 플러그인마다 `git show origin/main:plugins/<X>/.claude-plugin/plugin.json` 의 판에서 다음 major(`a.b.c` → `(a+1).0.0`).
- [ ] **Step 3: CHANGELOG** — `## [<판>] — <오늘>`: `### Removed` 에 그 플러그인 표의 `은퇴` 이름마다 `` `<이름>` — 대신: <대신할 길 칸> ``(별칭은 같은 줄) · 지운 장치(사전 검사의 `disabled` 감시줄 · 정본과 사본 · 해석기 갈래 · 옛 사본 자리)를 해당 플러그인에. `### Changed` — 진입 skill 의 계속할지 묻기 · project-init 훅의 덧붙임 줄 · 엔진 사유 글자 · 감사 새 요건(plugin-audit `### Added`).
- [ ] **Step 4: 의존 표** — 넷 각각 `python3 shared/deps/check_deps.py measure --plugin-root plugins/<X>`(J16).
- [ ] **Step 5: 확인**
```bash
bash shared/tests/test_changelog_integrity.sh
bash shared/tests/test_switch_tables.sh
```
그리고 첫 판 Task 12 Step 4 의 꼴로 플러그인마다 「표의 `은퇴` 첫 이름 가운데 이 판 절의 `### Removed` 에 없는 것」 이 `[]` 인지 본다. README 넷의 `## 끄는 길` 표에 `은퇴` 행이 그 플러그인 표와 같은 수인지(spec-distill 10 · quality-gates 6 · plugin-audit 2 · project-init 2).
- [ ] **Step 6: Commit** — `chore(release): 네 플러그인 판을 major 로 올리고 은퇴한 끄기 변수를 Removed 에 공시한다`

---

### Task 17: PR 본문 재료와 전체 스위트

**AC:** AC27

- [ ] **Step 1: PR 본문 재료** — `$TMPDIR/f7-plan2-pr-material.md`(지휘자가 준 `TMPDIR`, 없으면 이 worktree 의 `.claude/tmp/`)에: ① `docs/testing.md` 「테스트할 자리」 꼴의 표(칸 넷 — 자리 · 확인할 동작 · 잡는 것 · 못 잡는 것 · 테스트 파일)로 이 판이 더하거나 고친 테스트(과제 2 · 3 · 4 · 5 · 6 · 7 · 8 · 11 · 12 · 13 · 14 · 15) ② 사용자가 승인한 지우기 표(Q1) 그대로 ③ 「손으로 한 번」 둘(설계 Verification Plan) — 설치본에서 은퇴 변수를 켜고 진입 skill 을 부르면 「더 듣지 않는다」 줄과 질문이 보이는지, project-init 훅 알림 끝의 덧붙임 줄 ④ Q2 의 남은 둘.
- [ ] **Step 2: 전체 스위트** — 지휘자가 공유 잠금 아래에서 돈다(Global Constraints). 구현 담당은 돌지 않는다. 실패마다 이 브랜치 변경과 닿는지 적고, 이 브랜치에만 있는 실패가 0 이 될 때까지 그 과제의 뜻 안에서 고친다.

---

## 실행 방식의 마지막 전체 리뷰

고른 실행 방식의 마지막 리뷰어(쓰기 도구 없는 agent)에게 아래를 그대로 싣는다.

- 설계문서 `## Acceptance Criteria` 의 둘째 판 목록(AC18–AC27) 원문.
- 요청: AC 마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>` 로 보고하라.
- 끝에서 끝 흐름 넷을 따로 물어라 — ① 은퇴한 통째 끄기 변수를 켠 채 spec-distill 진입 skill 을 부르면 표 → 사전 검사 줄 → G1 → 질문 → 계속/멈춤 ② 같은 것을 project-init 에서(묻지 않고 감) ③ project-init 훅이 알림을 낼 때 표 → `retired_notice` → `systemMessage` 끝 ④ `--recritic-skipped` 라운드의 엔진 경고 → 끝맺음의 경고 줄. 각 이음매의 rc 소비와 상태 가정.
- 과제 사이 이음매를 물어라 — 과제 3 의 G1 이 기대는 표의 「끄는 것」 글자(과제 2) · 과제 12 의 훅이 import 하는 사전 검사 함수(과제 2) · 과제 15 의 등호 집합이 과제 4 · 12 의 결과와 맞는지 · 과제 11 의 감사 요건이 과제 2 의 은퇴 행을 빼는지.
- 이 계획이 쓴 테스트 코드(과제 2 · 3 · 11 · 12 · 15 의 새 절과 케이스)는 **계획이 정한 것**이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — `$TMPDIR/f7-plan2-ac-report.md`(없으면 이 worktree 의 `.claude/tmp/f7-plan2-ac-report.md`). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다(`## 결정 기록` · `## 지휘 기록` 은 고치지 않는다). PR 을 만들기 전에 `python3 plugins/spec-distill/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-18-official-switches-state-design.md <보고 파일 경로>` 를 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글은 첫 줄에 상태, 번호 · 해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 끝에 할 일(기본 하나 — 여럿이거나 병렬이면 밝힌다).

## 재지 못함

- 설치본에서 은퇴 변수를 켠 채 진입 skill 이 「더 듣지 않는다」 줄과 질문을 실제로 보이는지 · 화면 없는 실행에서 멈추는지 — 이 세션은 Claude Code 를 다시 띄울 수 없다. 글로만 집행되는 자리라 과제 3 의 문장 락이 지킬 수 있는 데까지다.
- `claude plugin disable` 로 끈 효과 · 설정의 `env` 칸이 Bash 스크립트에 닿는지(첫 판과 같다 — Q2 ②).
- project-init 훅의 덧붙임 줄이 실제 세션의 사람 채널에 보이는지(훅 출력 JSON 까지만 잰다).
