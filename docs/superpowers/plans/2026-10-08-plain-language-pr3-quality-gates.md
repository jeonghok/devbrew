# 쉬운 말 출력 PR 3 — quality-gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** /qg 의 사람용 고정 문구 — 질문 셋과 선택지, 완료 표, 범위 줄 · trivia 줄 · 범위 경고, 합성기 출력, 시작 배너와 setup 오류 줄 — 가 한국어 쉬운 말이 되고, 합성기 출력의 첫 줄이 스크립트가 계산한 상태 문장이 된다. 모든 리뷰어 지적에 사람에게 보일 한 문장(`plain:`)이 생겨 화면에 먼저 보인다. 판정 줄과 기계가 읽는 줄은 형태가 그대로다. 착수 전 기준선과 비교해 새 실패는 0 이어야 한다.

**Architecture:** 판정은 여전히 `verdict.py` 의 `verdict:` 줄 하나가 정하고, 합성기의 `**Findings:**` 줄 · `판정 degrade` 표지 · `dropped as malformed` 토큰도 그대로 둔다(기계와 SKILL 이 읽는다). 바꾸는 것은 그 옆의 사람용 줄과 그 자리뿐이다 — 지시문 문장은 그대로 두고, 지시문이 「그대로 내라」고 적은 문구만 고친다(설계 §6). `plain:` 칸은 형식을 정하는 곳(agent 정의 · codex 프롬프트 빌더 · 재비판 프로필 · SKILL 의 dispatch 지시)에서 생기고, 넘기는 곳(공유 codex 변환기 · 비코드 합성기의 허용 목록 둘)과 합치는 곳(두 합성기의 dedup)을 지나, 그리는 곳(합성기 표)에서 요약 앞에 선다. 칸이 없는 지적은 지금처럼 나간다 — 칸이 없다고 버리면 처분 회계에서 소실이 된다.

**Tech Stack:** Python 3.9+, bash(macOS 3.2 호환), git.

**Spec:** `docs/superpowers/specs/2026-10-08-plain-language-output-design.md` (brief: `docs/superpowers/interview/2026-10-03-plain-language-output-interview.md`). 선행: PR 1(#188) · PR 2(#193) 머지됨 — 이 계획은 main 310ce78f 기준이다.

## 목차

- [Global Constraints](#global-constraints)
- [계획이 정한 것](#계획이-정한-것)
- [310ce78f 까지 트리가 바뀐 것](#310ce78f-까지-트리가-바뀐-것)
- [qg v10 계획과의 충돌](#qg-v10-계획과의-충돌)
- [Review Focus](#review-focus)
- [Task 0: 착수 준비](#task-0-착수-준비)
- [Task 1: 질문 셋 · 완료 표 · 모델이 그대로 내는 문구](#task-1-질문-셋--완료-표--모델이-그대로-내는-문구-ac6)
- [Task 2: 합성기 · 시작 배너 · setup 오류 줄](#task-2-합성기--시작-배너--setup-오류-줄-goal-2--ac5--ac6--r1--r2--r8--r10--r11--r12)
- [Task 3: `plain:` 칸](#task-3-plain-칸--형식--넘기기--합치기--그리기-5--ac9--d28--deferred-7)
- [Task 4: README · 소개 문구 · 버전](#task-4-readme--소개-문구--버전-8--ac10)

## Global Constraints

- **재결정 규약** — confirmed 항목은 근거가 있으면 보고한 뒤 재결정할 수 있고, 임의 변경은 금지다. 설계 B1~B10 · D1.1~D2.10, PR 1 의 P1~P13, PR 2 의 Q1~Q12 가 제약이다. 이 계획이 정한 것은 아래 표에 있고, 「사용자 확인」 칸에 표시한 행은 실행 전에 사용자에게 묻는다.
- **작업 위치** — `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice`, 브랜치 `feature/plain-language-voice`. subagent 에게 이 절대경로를 매번 못 박는다.
- **보조 파일 자리** — 이 계획의 스크립트(앵커 검사 · 편집 · 고정 단언 갱신 · 테스트 실행 · 변이)는 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/` 에 쓴다. 그 job tmp 는 다른 작업도 담는다 — **글롭으로 `rm` 하지 않는다**(subagent 포함). 지울 때는 만든 경로를 정확한 이름으로만 지운다.
- **git** — merge(rebase 금지), 경로 지정 커밋(`git add <경로>…` — `-A` · `.` 금지), Conventional Commits 에 **한국어 설명**, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. 스태시 금지.
- **편집은 스크립트로** — 각 Task 의 편집은 이 계획에 실린 파이썬 스크립트를 그대로 쓰고 돌린다. 스크립트는 옛 문구가 기대 개수만큼 있는지 단언하고, 하나라도 다르면 아무것도 쓰지 않고 `STOP` 으로 끝난다. `STOP` 이 나면 그 자리가 움직인 것이다 — 같은 뜻의 자리를 찾아 고치지 말고 멈춰 보고한다.
- **Python** — `encoding="utf-8"` 명시, `"python3"` 문자열 리터럴 금지(`shared/tests/test_python_floor.sh` 축 E), Python 3.9.
- **처분 회계 소비자** — `synthesize_findings.py` · `synthesize_artifact_findings.py` 에는 컴프리헨션 · `break` · `continue` 를 새로 넣지 않고(for 문 + 대입으로 쓴다), `synthesize_findings.py` 의 `dedup` 보다 위에 줄을 넣지 않는다(R14).
- **셸** — 한국어 글자 앞의 셸 변수는 `${v}` 로 쓴다(bash 3.2 는 `「$v」` 를 `set -u` 에서 죽인다). 새 락의 산문 단언은 줄바꿈을 지운 본문에서 잰다(`flat`) — 다시 쓰일 때 문장이 줄을 넘을 수 있다. 읽는 파일이 늘면 `# guards:` 선언도 같이 넓힌다(`test_guards_coverage_bidirectional.sh` 가 두 방향으로 잰다).
- **새 테스트 파일은 실행 비트로 커밋한다**(`chmod +x` — 모드 100755). `tests/test_runner_adapters.sh` 의 `case_qg_test_scripts_are_executable` 가 비실행 테스트를 「셸 어댑터가 claim 할 수 없다」로 RED 를 내고, 그 RED 가 `test_codex_backward_compat.sh` 로 번진다(드라이런 2회차 after 스위트가 잡았다).
- **테스트** — 셸은 리포 루트에서 `bash <경로>`, 하나씩(동시 실행 금지 — 고정 `/tmp` 경로가 경쟁해 거짓 RED 가 난다). Python 은 그 `tests/` 에서 `python3 -m unittest -v <모듈>`. `PYTHONDONTWRITEBYTECODE=1`. `plugins/quality-gates/tests/spike/` 는 돌리지 않는다. Task 0 Step 4 의 `rt.sh` 가 이 규칙대로 돈다.
- **선재 RED(310ce78f)** — `tests/harness/test_skill_orchestration_behavior.sh` 의 넷(「iter cap near Review gate」 · 「SKILL 제목 major 불일치」 · 「버전을 단 SKILL 제목이 0개」 · 「R1b→R8 unclaimed」). 이 파일의 rc 는 이미 1 이라 rc 로는 새 실패가 안 보인다 — **FAIL 줄 수 4 와 그 넷의 이름**으로 비교한다. 「iter cap」 줄의 숫자는 SKILL 줄 수 변화로 바뀔 수 있다(같은 단언). `test_codex_backward_compat.sh` 는 부하 아래에서 안쪽의 `test_codex_runner_degrade_contract.sh` 가 흔들려 rc=1 이 날 수 있다 — 단독 재실행이 4/4 면 새 실패가 아니다.
- **변이** — 커밋한 뒤 변이한다. `pr3_mut.py` 가 셀마다 옛 글자를 정확히 한 번 바꾸고 지정 테스트를 돌린 뒤 `git checkout HEAD -- <파일>` 로 되돌리고 `git diff HEAD --stat` 이 빈지 본다. 새 규칙 문장마다 셀이 있다(지우기 · 뒤집기 · 옮기기 · 영어로 되돌리기). `survived=0` 이 아니면 그 락에 이빨이 없다 — 락을 고친다.
- **리뷰어 지시 파일은 보안 민감** — 찾는 지시는 한 글자도 바꾸지 않고, 「짧게 써라」를 넣지 않으며, `tools:` 를 바꾸지 않는다. 칸만 더한다(설계 §5).
- **이름** — CLAUDE.md Progressive disclosure: 기계가 내는 안내는 `/plugin:name` 완전명이고, 진입 skill 짧은 이름(`/spec-review` 등)을 맨몸으로 쓰지 않는다. qg 는 `plugins/quality-gates/commands/` 가 있는 동안 호출 표면 락(`shared/tests/test_invocation_surface.sh`)의 보고 모드다 — 이 계획은 보고 표의 행 수(310ce78f: 22)를 늘리지 않는다(Task 0 Step 2 · 각 Task 의 실행 목록). 새 command 파일을 만들지 않는다. `/qg` · `/qg branch` · `/qg-publish` 는 command 라 그대로 쓴다.
- **버전** — 310ce78f 에서 quality-gates 10.0.3 → **10.1.0**(minor — 출력 계약은 그대로이고 새 칸이 생긴다), spec-distill 5.1.0 → **5.1.1**(patch — 링크로 실린 `shared/codex/codex_findings_to_yaml.py` 의 내용이 바뀐다 · 설치본 캐시 키). plugin-audit · project-init 은 건드리지 않는다. 번호는 **머지 직전**에 origin/main 의 두 `plugin.json` 을 보고 다시 정한다(먼저 머지되는 쪽이 이긴다 — 같은 버전 문자열은 충돌 없이 병합된다).
- **줄 번호** — 이 계획의 줄 번호는 310ce78f 실측이다(PR 1 의 규칙 블록 · #189 · #191 의 진입 머리가 반영된 값). 편집은 줄 번호가 아니라 옛 문구로 찾는다.
- **산출 보존** — `~/.claude/sdd-mirror/plain-language-output/pr3/`.
- **드라이런** — 2026-10-10 310ce78f 복사본에서 이 계획을 Task 0–4 끝까지 글자 그대로 실행했다(보고서: `/Users/jeonghokim/.claude/sdd-mirror/plain-language-output/research/dryrun-pr3-report.md`). 아래 RED 수 · GREEN 수 · 변이 결과는 그 실측이다.

## 계획이 정한 것

| # | 정한 것 | 근거 | 사용자 확인 |
|---|---|---|---|
| R1 | 합성기의 **판단에 필요한 0** 으로 남기는 줄: 처분 줄(`**처분:** 수용 N · 기각 N · 억제 N · 흡수 N · 미판정 N (미판정은 차단)`) · 배관 손실 줄 · 「탐지 0 · 재비판 0」 줄. 이 0 들은 「아무것도 버리지 않았다」·「재비판자가 돌았다」는 공시다. | 설계 §3 원칙 3. 기존 락(`test_synthesize_disposition.sh:191` · `:130`, `test_synthesize_artifact_findings.sh:396-400`, `test_recritic_bridge.sh:420`)이 그 줄들이 늘 보인다고 잰다(310ce78f 재확인). 공유 모듈 `render_disposition.py` 는 손대지 않는다. | — |
| R2 | 합성기 첫 줄은 `render()` 가 계산한 상태 문장이다(판정과 무관 — 판정에 기대는 줄은 `render()` 에 넣지 않는다). 범위·각도 블록 앞의 쉬운 한 줄은 `--emit-verdict` 꼬리에서 **블록이 있을 때만** 첫 블록 바로 앞에 한 번 낸다 — 둘 다면 「아래는 이 판정이 본 범위(scope)와 리뷰 각도(angles)의 원문이다.」, `scope:` 만이면 「…본 범위(scope)의 원문이다.」, `angles:` 만이면 「아래는 이 판정의 리뷰 각도(angles) 원문이다.」. 그래서 `test_angle_coverage.sh` 의 「off 는 on 에서 angles: 블록을 뺀 것과 바이트 동일」 불변식이 「angles: 블록과 그 앞의 쉬운 한 줄을 뺀 것」으로 바뀐다(Task 2 의 고정 단언 표). | `test_verdict_vocabulary.sh:460-486` — 판정 없는 출력이 판정 있는 출력의 바이트 접두여야 한다. 블록이 없는데 블록을 가리키는 줄은 거짓이다. | — |
| R3 | 외부 추가 리뷰어(`pr-review-toolkit:code-reviewer` 등)에게는 SKILL 에 dispatch 프롬프트 리터럴이 없다 — 모델이 쓴다. 그래서 「추가 리뷰어 — 스코프 도출」 절(SKILL:483-489)에 **프롬프트 끝에 붙일 한 줄**을 리터럴로 적는다. 그 절은 AC6 창(SKILL:338 보안 각도 ~ :390 다른 전제 각도 앵커) 밖이다. | 설계 D2.8 · 조사(2026-10-08) · `test_review_scope_composition.sh` 의 창 규칙. | — |
| R4 | 오케스트레이터가 `$RV/findings.yaml` 을 손으로 쓸 때 `plain:` 도 옮긴다는 문장을 `confidence:` 옮기기 문장(SKILL:518) 바로 뒤에 더한다. 이 문장이 없으면 칸이 합성기에 닿기 전에 사라진다. | 조사: security-reviewer · 추가 리뷰어 결과는 오케스트레이터가 옮겨 적는다. | — |
| R5 | 「Codex skip 안내」 표의 영어 사유 문구와 `specialist <X> unavailable … degraded coverage` 줄은 고치지 않는다. 사유 토큰이 사람에게 그대로 보여야 하고(설치 명령 · 버전 문자열), 락(`test_skill_codex_skip_prose.sh` · `test_review_scope_composition.sh:58-59`)이 그 글자를 잰다. | AC6 의 범위는 질문 셋 · 완료 표 · 합성기 · 시작 배너 · setup 의 사람용 줄(옛 cancel 자리 — R9)이다. | — |
| R6 | **폐기** — 옛 행은 `cancel-qg-core.sh` 의 진단 줄을 그대로 두고 `commands/cancel-qg.md` 의 보고를 한국어로 바꾼다고 정했다. #189(qg 10.0.0)가 `/cancel-qg` 와 그 스크립트를 지웠다(파이프라인이 한 턴이라 setup 이 매 실행 세션 폴더를 다시 만든다). 대상이 없다. | `git log 24ac11d6`. | — |
| R7 | 비코드 산출물 경로(`critiquing-artifacts`)에는 화면 렌더러가 없다 — `kept:` YAML 을 모델이 읽어 보고한다. 그래서 그 경로의 `plain:` 은 `kept` 에 남는 것까지 재고, 최종 보고 틀에 「`plain:` 이 있으면 그것을 먼저 쓴다」 한 줄을 더한다. | 조사: `synthesize_artifact_findings.py` 는 YAML 을 낸다. | — |
| R8 | Goal 2 의 확인(설계 표 `0b618227#r2.1`): golden 파일 대신 합성기(발견 0건 · 1건 이상 · 숨김 · 버림)와 시작 배너의 첫 줄과 0 줄 부재를 단언으로 고정한다. | 이 플러그인의 기존 테스트 관례가 단언이다. 변이 「0 인 등급 되살리기 → RED」를 함께 잰다. | — |
| R9 | **옮겨 간 표면** — 설계가 고칠 자리로 적은 `cancel-qg` 메시지와 세션 시작 훅 경고는 #189 가 지웠다. cancel 보고의 뜻(상태를 지웠다 · 못 지웠다)은 setup 의 거부 줄(`refuse` · 다른 세션 · 예약 폴더 — 「… — 지우지 않는다. 아무것도 쓰지 않는다.」)과 없어진 인자 안내(`gone` — 「… 인자는 없어졌다 — …. 실행하지 않는다.」)로 옮겨 갔고, 그 줄들은 이미 한국어 상태 문장이라 이 계획이 고칠 것이 없다. 세션 시작 훅에는 옮겨 간 표면이 없다(qg v10 D-1 「(가) 공시하고 삭제」, 2026-10-09) — 그 단계를 뺀다. | `setup-qg.sh:28 · :151 · :161 · :198`. 확정 결정을 바꾸지 않는다. | — |
| R10 | setup 의 나머지 영어 오류 줄 — kill switch 거부(`:16`) · 인자 오류 넷(`:42` · `:72` · `:84` · `:114-115`) · 세션 ID 둘(`:132-136` · `:142`) — 을 쉬운 말로 시작하게 하고 원래 영어 토큰은 괄호에 남긴다. 기존 락이 그 토큰(`requires at least one glob` · `Unknown argument` · `session`)을 재고, 특히 `! grep -qi 'Unknown argument'` 꼴의 부재 락은 토큰이 사라지면 공허해진다. `--help` 본문은 그대로다(`/qg` 흐름이 부르지 않는 CLI 사용법). | AC6 「`setup-qg.sh` 의 사람용 고정 문구가 한국어」. 옛 계획은 배너와 (지금은 없는) 두 경고만 고쳤다 — 범위가 넓어진다. | 사용자 승인 2026-10-10 |
| R11 | 합성기 꼬리의 「re-run with `/qg --show-low-confidence` to see all」을 옮기지 않고 지운다 — 그 인자는 없다(setup 이 `Unknown argument` 로 거부해 `/qg` 가 시작하지 않는다). 꼬리는 「확신 4 이하 지적 N개를 숨겼다.」 한 줄이다. 옛 계획은 그 안내를 한국어로 옮겼다(없는 할 일을 쉬운 말로 만드는 것). | 드라이런 실측(310ce78f `setup-qg.sh` 의 `case` 에 그 인자가 없다). 사용자에게 보이던 「할 일」 하나가 사라진다. | 사용자 승인 2026-10-10 |
| R12 | 합성기 첫 줄에 버린 지적 수를 붙인다 — 「… 형식이 깨져 버린 지적 N개.」(숨긴 지적 수와 같은 꼴). 버린 주장이 있는 실행의 첫 줄이 「확신 높은 지적 없음.」만 말하면 없는 것과 버린 것이 같은 줄로 읽힌다. | 규칙 블록 「없는 것과 확인 못 한 것은 다르다」 · 드라이런 발견. | 사용자 승인 2026-10-10 |
| R13 | README 다시 쓰기는 좁게 한다: 첫 문단 · `## 사용` → `## 쓰는 법` 표 · 「파이프라인 흐름」 첫 문단 · 상태도 표지(Task 1). 나머지 절의 머리글과 문면(`## 인스턴스화한 원칙` · `## 구조` · `## 설치된 Hook` · `## 리뷰어 구성 — 각도 셋 + 추가 리뷰어` · `## 사전 요건` · `### Kill switches (보안 컨트롤)` · `## 파이프라인 state` …)은 글자 그대로 둔다 — 락 여럿이 그 머리글로 절을 자르고 그 안의 낱말을 재며, 원칙 절 문면은 qg v10 ②~⑤ 가 다시 고친다. | 설계 §8 「네 README 를 새 규칙대로 다시 쓴다」보다 좁다(PR 2 와 같은 방식). | 사용자 승인 2026-10-10 |
| R14 | 처분 회계 소비자에 넣는 코드는 컴프리헨션 · `break` · `continue` 없이 쓰고, `synthesize_findings.py` 의 `dedup` 위쪽에는 줄을 넣지 않는다. `test_adjudication_wiring.sh` 가 컴프리헨션 수(baseline 40)와 「버리는 분기 전부에 처분 호출」을 재고, `tools/adjudication/check_wiring.py` 의 EXEMPT 가 `dedup` 안의 분기를 줄 번호(`synthesize_findings.py:497`)로 가리킨다. | 드라이런 실측 — 생성식 하나 · `break` 하나 · 위쪽 도우미 함수 하나가 각각 RED 를 냈다. | — |

## 310ce78f 까지 트리가 바뀐 것

계획을 쓴 2026-10-08(abc70f66 이전) 뒤 main 에 든 것 중 이 계획에 닿는 것만 적는다.

| 바뀐 것 | 들인 PR | 이 계획에서 |
|---|---|---|
| 모든 SKILL.md · command 파일의 H1 뒤 규칙 블록(13줄 + 표시 줄) | #188 (PR 1) | 줄 번호 실측으로 바꿈. quality-pipeline SKILL 은 옛 번호 +17 |
| `commands/cancel-qg.md` · `scripts/cancel-qg-core.sh` · `tests/test_cancel_qg.sh` 삭제 | #189 | Task 1 Step 4 의 cancel 표와 R6 폐기 · R9 |
| `hooks/session-start-advisor.py` · SessionEnd 훅 삭제(`hooks/` 디렉토리 없음) · `test_session_start_advisor_v2.sh` · `test_kill_switches.py` 삭제 | #189 | Task 2 Step 3 의 훅 경고 단계 삭제(R9) |
| `setup-qg.sh` 최소화 — 「이미 활성」 거부 · pr-review-toolkit 경고 · `Available plugins` · `PR URL` 줄 삭제, `branch <name>` · `--reset` · `--gc` · `--pr-url` 은 안내 한 줄 + exit 2, 배너는 `:252-262` | #189 | Task 2 의 setup 편집을 새 파일에 맞춤. 옛 표의 `test_isolation.sh:152` · `test_kill_switches.py:197` 행 삭제 |
| `commands/qg.md` 의 「Quality-gates state cleared.」 삭제 | #189 | 그 편집 삭제 |
| `/qg branch <name>` worktree 모드 삭제(맨 `/qg branch` 는 남음) · create-sandbox / mutation-guard → plugin-audit | #189 | README 의 쓰는 법 표에 `/qg branch` 만 |
| qg 는 command 파일 둘(`qg.md` · `qg-publish.md`)을 유지하고 호출 표면 락의 보고 모드(행 22) | #191 | Global Constraints 「이름」 · Task 0 Step 2 |
| spec-distill 진입 skill 개명(`spec-review` · `spec-interview` · `request-framing`) | #191 | 이 계획은 spec-distill 문면을 고치지 않는다(CHANGELOG 한 줄뿐) |
| quality-gates 10.0.3 · spec-distill 5.1.0 | #193 (PR 2) | 버전 |

이미 다른 PR 이 해 둬서 뺀 단계는 없다 — #189 · #191 · PR 2 는 이 계획이 바꾸는 문구(질문 셋 · 완료 표 · 합성기 · 배너 · `plain:`)를 하나도 바꾸지 않았다. 뺀 단계는 대상이 사라진 것뿐이다(cancel 보고 · `qg.md` 의 「state cleared」 · 세션 시작 훅 경고 둘 · setup 의 「이미 활성」 오류 · pr-review-toolkit 경고 · `Available plugins` 줄).

## qg v10 계획과의 충돌

`docs/superpowers/plans/2026-10-08-qg-v10-*.md` 의 ②~⑤ 는 아직 실행 전이다. 이 PR 이 먼저 머지되면 그 계획들의 편집 스크립트 단언(`count == 1`)이 아래 자리에서 터진다 — 그 계획의 규칙대로 「같은 뜻의 자리로 옮겨 적용하고, 뜻이 달라졌으면 멈추고 보고」한다. 반대로 그쪽이 먼저 머지되면 이 계획의 Task 0 Step 2 가 `STOP` 을 낸다 — 이 계획을 그 트리에 맞춰 다시 쓴다. 여기서는 구현하지 않는다.

| qg v10 | 겹치는 자리 | 무엇이 부딪히나 |
|---|---|---|
| ② Task 4 — 합성기 다시 씀(confidence · 억제 수 제거, `blocking:` · `optional:`, `recritic_bridge.py` 삭제 → `synthesize_findings.py prepare`) | Task 2 의 합성기 문구 전부 · Task 3 의 `plain` 표 칸과 dedup · `test_plain_field_path.sh` ④(`recritic_bridge.py prepare` 를 부른다) | ② 의 새 표 머리는 `| Sev | Path:Line | Summary | Source |`(영어), 빈 결과 문구는 「No findings.」다. ② 가 뒤에 오면 이 PR 의 한국어 머리와 상태 첫 줄을 그 다시 쓴 파일에 옮겨야 하고, 첫 줄의 「확신이 낮아 숨긴 지적」은 억제가 사라지므로 빠진다. `test_plain_field_path.sh` ④ 는 `prepare` 하위명령으로 바뀐다 |
| ② Task 6 — `SKILL.md` 제자리 재작성(K-8) · Final verdict 에서 `sed -n '/^| Sev |/,/^$/p'` 로 지적 표를 `result.md` 에 옮김 | Task 1 의 질문 셋 · 라벨 · 완료 표 · 범위 줄 · trivia 줄 · 범위 경고 · Task 3 의 R3 · R4 문장 | ② 의 새 SKILL 펜스는 질문을 영어(`qg iter N: findings remain …`)로 다시 적는다. 이 PR 이 먼저면 ② 는 한국어 질문 · 라벨을 옮겨 적어야 하고, **`sed` 의 `^| Sev |` 앵커는 이 PR 의 `| 심각도 |` 머리에서 아무것도 못 잡는다** — 조용히 빈 「지적」 절이 된다 |
| ② Task 3 — `security-reviewer.md` 에 `model: opus` · intent/criteria 슬롯 · confidence 제거, `code-recritic.md` 신설 · `agents/doc-recritic.md` 삭제 | Task 3 의 `security-reviewer.md` `plain:` 줄 · `recritic-code-profile.md` 의 added 문장 | 새 재비판 agent 의 출력 형식에도 `plain` 이 있어야 D2.8 이 유지된다 |
| ② Task 2 — `build_codex_prompt.py` 의 confidence 제거 · 기준 블록 | Task 3 의 `"plain"` 줄(같은 JSON 형식 블록) | 같은 블록을 둘이 고친다 |
| ② Task 5 · ⑤ — `setup-qg.sh`(result.md · `--plan` 제거) | Task 2 의 배너(「계획 파일:」 줄) · 오류 줄 | ⑤ 가 `--plan` 을 지우면 「계획 파일:」 줄과 `--plan` 오류 줄이 사라진다 |
| ③ — `/qg-publish` · `publishing-pr-understanding` 삭제, 공개 description 을 세 곳 같은 문자열로 바꿈 | Task 4 의 소개 문구(「/qg-publish separately posts …」) · README 쓰는 법 표의 `/qg-publish` 행 | ③ 뒤에는 이 소개 문구가 거짓이다 — ③ 이 다시 쓴다 |
| ④ — `setup-qg.sh` 에 남은 앱 정지 · README kill switch 표 | Task 2 의 setup 편집 | 다른 줄이라 글자 충돌은 없다 |

## Review Focus

1. **`plain:` 이 없는 지적** — 외부 리뷰어는 칸을 안 채울 수 있다. 사람은 그 지적이 사라지지 않고 지금처럼 요약으로 보이길 기대한다. → `test_plain_field_path.sh` ②(변이 「렌더가 칸 없는 지적을 건너뛰기」 → RED).
2. **`plain:` 값에 표 칸을 깨는 글자(`|` · 개행)** — 사람은 표가 깨지지 않길 기대한다. → `test_plain_field_path.sh` ⑥(기존 `_cell` 을 지난다 — 행 수와 이스케이프 모양 둘 다).
3. **판정과 무관한 상태 줄이 `verdict:` 를 품는다** — 쉬운 첫 줄에 `verdict: clean` 같은 글자가 들어가면 판정 줄이 둘이 된다. → `test_plain_synth_output.sh` ⑤ 와 Task 2 변이 「첫 줄에 verdict: clean 넣기」(AC5).
4. **재비판자가 새로 더한 지적에 `plain:` 이 있다** — 다리(`recritic_bridge.py`)가 칸을 넘기는지. → `test_plain_field_path.sh` ④.
5. **두 리뷰어가 같은 지적을 내고 하나만 `plain:` 을 썼다** — 합칠 때 칸이 사라지지 않길 기대한다. → `test_plain_field_path.sh` ⑦(코드 경로: 신뢰도 높은 쪽이 남는다 — 그쪽에 칸이 없으면 다른 쪽 중 신뢰도가 가장 높은 쪽의 칸을 물려받는다 · 비코드 경로: 먼저 온 쪽이 남는다 — 같은 규칙).
6. **버린 주장 · 숨긴 지적이 있는 실행의 첫 줄** — 사람은 첫 줄만 읽고 「지적 없음」으로 끝내지 않기를 기대한다. → `test_plain_synth_output.sh` ③ · ④(R12).

---

## Task 0: 착수 준비

- [ ] **Step 1: 트리가 310ce78f 인지 확인한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
mkdir -p ~/.claude/sdd-mirror/plain-language-output/pr3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3
git status --porcelain
git fetch origin main
git merge-base --is-ancestor "$(git log --format=%H -1 --grep='게이트 질문에 결정 하나와 경고 개수만')" origin/main && echo PR2-MERGED || echo PR2-NOT-MERGED
git merge-base --is-ancestor origin/main HEAD && echo MAIN-IN-HEAD || echo "MAIN-MOVED $(git rev-list --count HEAD..origin/main)"
git diff --stat 310ce78f HEAD -- plugins shared tools .claude-plugin CLAUDE.md | tail -1
test -f plugins/quality-gates/scripts/recritic_bridge.py && grep -qF '| Sev | Path:Line | Conf | Summary | Source |' plugins/quality-gates/scripts/synthesize_findings.py && echo QG-V10-2-NOT-MERGED || echo QG-V10-2-MERGED
```

기대: status 는 비었거나 이 계획 파일 한 줄뿐 · `PR2-MERGED` · `MAIN-IN-HEAD` · diff --stat 빈 출력 · `QG-V10-2-NOT-MERGED`. `MAIN-MOVED <n>` 이면 merge 하지 말고 멈춰 보고한다(`git diff --stat HEAD...origin/main -- plugins/quality-gates shared` 를 함께). `QG-V10-2-MERGED` 면 이 계획은 다시 써야 한다(「qg v10 계획과의 충돌」).

- [ ] **Step 2: 이 계획의 옛 문구가 그대로인지 본다**

아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_anchor_check.sh` 에 그대로 쓰고 `bash` 로 돌린다. 줄마다 기대 개수(기본 1, 셋째 인자가 있으면 그 값)와 다르면 `STOP` 이다.

````bash
#!/usr/bin/env bash
# PR 3 Task 0 Step 2 — 이 계획이 바꾸는 옛 문구가 기대 개수만큼 있는지(grep -cF) 센다.
set -u
R="${R:-/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice}"
c() { n="$(grep -cF -- "$2" "$R/$1")"; e="${3:-1}"; [ "$n" = "$e" ] && s=ok || s=STOP; printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$n" "$1" "$2" "(기대 ${e})"; }
S=plugins/quality-gates/skills/quality-pipeline/SKILL.md
# Task 1
c "$S" 'question: "qg iter N: findings remain (<summary>). What next?",'
c "$S" 'question: "qg reached max 5 iterations. Last findings: <summary>. Finish with the current verdict or stop?",'
c "$S" 'question: "Retry failed at <file>: <reason>. Abort the retry iteration, or skip this file and continue with the remaining patches?",'
c "$S" 'findings remain' 3
c "$S" '**Retry 옵션 문구 — 차등 테스트 기원(kept = 0)에는 그대로 쓰지 않는다.** 위 리터럴의'
c "$S" 'are explicit: "Abort retry" terminates the iteration; "Skip this file"'
c "$S" '| $QG/scripts/render-terminal.py table --title "Quality Gates — Complete"'
c "$S" 'Print `Trivia diff — pipeline skipped (one-sentence diff per CLAUDE.md trivia escape).`'
c "$S" '`> Review scope: session (<COUNT> changed files). 전체 PR/브랜치는 /qg branch.`'
c "$S" '`> Review scope: topic <topic_key> (<COUNT> changed files · 구성원 <branches>).`'
c "$S" 'scope check degraded (detached HEAD / no base branch / unrelated history / shallow) — empty-scope detection skipped'
c "$S" 'and the appended `## History` lines from the state file as an indented tree'
c plugins/quality-gates/skills/critiquing-artifacts/SKILL.md '## 종료 & 최종 요약 (AC11)'
c plugins/quality-gates/commands/qg.md '`Review scope: session (N files)`'
c plugins/quality-gates/commands/qg.md '`Review scope: topic <키> (N files · 구성원 <branches>)`'
c plugins/quality-gates/commands/qg.md '`Retry` / `Accept and finish` / `Stop`' 2
c plugins/quality-gates/README.md '("findings remain..." │'
c plugins/quality-gates/README.md 'Final summary  (Verdict · Iterations · Outcome · angles)'
# Task 2
SY=plugins/quality-gates/scripts/synthesize_findings.py
c "$SY" '"## Review Findings (Synthesized)",' 2
c "$SY" 'out = ["## Review Findings (Synthesized)", "", counts_line,'
c "$SY" 'f"No high-confidence findings. {suppressed_count} low-confidence "'
c "$SY" 'out.append("| Sev | Path:Line | Conf | Summary | Source |")'
c "$SY" 'out.append("`*` = confidence <= 6 (treat with caution).")'
c "$SY" 're-run with `/qg --show-low-confidence` to see all.'
c "$SY" 'f"{dropped_malformed} finding(s) dropped as "'
c "$SY" 'f"{dropped_malformed} finding(s) dropped as malformed "'
c "$SY" 'out.append("**Suggested fixes:**")'
c "$SY" 'summary = _cell(f.get("summary", ""))'
c "$SY" '        if scope is not None:'
SE=plugins/quality-gates/scripts/setup-qg.sh
c "$SE" 'echo "🔄 Quality Gates Pipeline"'
c "$SE" 'echo "Pipeline: scope → differential test → reviewers → re-critique → verdict"'
c "$SE" 'echo "Pipeline runs in this turn."'
c "$SE" 'echo "Plan file: $PLAN_FILE"'
c "$SE" 'setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1'
c "$SE" '❌ Error: --paths requires at least one glob'
c "$SE" '❌ Error: --plan requires a file path argument'
c "$SE" '❌ Error: --session-id requires an argument'
c "$SE" '❌ Error: Unknown argument: $1'
c "$SE" '❌ Quality Gates: cannot create pipeline state — session ID is empty.'
c "$SE" "fails pattern guard ([A-Za-z0-9_-]{8,})."
c plugins/quality-gates/tests/e2e-scenarios.md '(`setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1`)'
# Task 3
c shared/codex/codex_findings_to_yaml.py 'DEFAULT_KEYS = ("file", "line", "severity", "confidence", "summary", "proposed_fix")'
c plugins/quality-gates/agents/security-reviewer.md '  summary: <one-sentence describing the vulnerability and its path>'
c plugins/quality-gates/agents/artifact-critic.md '    summary: "one sentence"'
c plugins/quality-gates/agents/artifact-adversarial.md '    summary: "..."'
c plugins/quality-gates/scripts/build_codex_prompt.py '      "summary": "<one sentence>",'
c plugins/quality-gates/scripts/build_artifact_codex_prompt.py '    summary: "one sentence"'
c plugins/quality-gates/references/recritic-code-profile.md '- `added` 항목은 `file` · `line` · `severity` · `summary` · `proposed_fix` 를 싣는다. `file` 은 리포 상대 경로다.'
c "$S" '`model:` override into their dispatch (upstream model pinning is respected).'
c "$S" '(합성기가 5 로 채운다).'
c plugins/quality-gates/scripts/synthesize_artifact_findings.py '"severity", "summary", "proposed_fix", "dedup_key", "stagnation_key")'
c plugins/quality-gates/scripts/synthesize_artifact_findings.py '"severity", "summary", "proposed_fix", "dedup_key")'
c plugins/quality-gates/scripts/synthesize_artifact_findings.py 'by_key[k]["severity"] = g["severity"]'
c "$SY" 'merged = dict(group[0])'
c plugins/quality-gates/agents/security-reviewer.md 'plain' 0
c plugins/quality-gates/scripts/synthesize_findings.py 'plain' 0
# Task 4
c plugins/quality-gates/README.md 'Claude Code용 품질 검증 파이프라인 — 한 파이프라인, 한 판정(`clean` · `defect` · `not-certified (<사유>)`). 기준선 대비 차등 테스트는 매 실행 돈다.'
c plugins/quality-gates/README.md '## 사용'
c plugins/quality-gates/README.md '`quality-pipeline` SKILL이 전체 파이프라인을 단일 assistant turn 내에서 serial dispatch로 실행합니다.'
c plugins/quality-gates/.claude-plugin/plugin.json '"description": "Quality verification pipeline — one pipeline, one verdict'
c .claude-plugin/marketplace.json '"description": "Quality verification pipeline — one pipeline, one verdict'
c shared/tests/test_charter_citations.sh 'QG_DESC = ("Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test) "'
c plugins/quality-gates/.claude-plugin/plugin.json '"version": "10.0.3",'
c plugins/spec-distill/.claude-plugin/plugin.json '"version": "5.1.0",'
````

```bash
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_anchor_check.sh > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/anchor.out
grep -c '^ok' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/anchor.out
grep -v '^ok' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/anchor.out
python3 shared/entry/check_invocation_surface.py --report | grep -c '^| [0-9]'
```

기대: `64`, 빈 출력, `22`(310ce78f 실측). `STOP` 이 하나라도 있으면 그 줄의 Task 로 가기 전에 멈춰 보고한다.

- [ ] **Step 3: 기준선**

310ce78f 의 기준선은 드라이런이 깨끗한 복사본에서 떠 두었다: `~/.claude/sdd-mirror/plain-language-output/pr3/baseline/`(`summary.tsv` · `failures.txt` · `logs/`, 272 파일, rc≠0 은 harness 하나 + 흔들린 `test_codex_backward_compat.sh` 하나). Step 1 의 diff --stat 이 비었으면 그것을 쓴다. 아니면 다시 뜬다(약 50분, 그동안 이 워크트리에서 테스트를 돌리지 않는다):

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr3/baseline
```

- [ ] **Step 4: 실행 도구 둘**

테스트 실행기 — `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh`:

````bash
#!/bin/bash
# rt.sh <리포 루트 상대 테스트 경로>... — 리포 루트에서 하나씩 돌린다(동시 실행 금지 — 고정 /tmp 경로가 경쟁한다).
# 줄마다: 이름 · rc · 실패 줄 수 · 로그 끝줄. 로그는 $LOGS/<basename>.log 에 남는다.
R="${R:-/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice}"
LOGS="${LOGS:-/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/logs}"
cd "$R" || exit 1
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$LOGS"
for t in "$@"; do
  log="$LOGS/$(basename "$t").log"
  case "$t" in
    *.py) ( cd "$(dirname "$t")" && python3 -m unittest -v "$(basename "$t" .py)" ) > "$log" 2>&1; rc=$? ;;
    *)    bash "$t" > "$log" 2>&1; rc=$? ;;
  esac
  n=$(grep -acE '^[[:space:]]*✗ |^(FAIL|ERROR)[: ]|^not ok |^BAD ' "$log")
  printf '%s\trc=%s\tfail=%s\t%s\n' "$(basename "$t")" "$rc" "$n" "$(tail -1 "$log" | LC_ALL=C cut -c1-150)"
done
````

변이 실행기 — `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py`(각 Task 의 마지막 Step 이 부른다):

````python
#!/usr/bin/env python3
"""PR 3 변이 셀 — 커밋한 뒤에 돈다. 셀마다: 옛 글자를 정확히 한 번 바꾸고, 지정한 테스트를 하나씩
리포 루트에서 돌려 rc 와 실패 줄 수를 적고, `git checkout HEAD -- <파일>` 로 되돌린 뒤 `git diff HEAD --stat`
가 비었는지 본다.   pr3_mut.py <리포 루트> <t1|t2|t3|t4>
기대: 셀마다 「RED」(지정 테스트 중 하나 이상 rc≠0). 「SURVIVED」 가 하나라도 있으면 그 락에 이빨이 없다."""
import os, re, subprocess, sys

R = os.path.abspath(sys.argv[1])
TASK = sys.argv[2]
Q = "plugins/quality-gates/"
QT = Q + "tests/"
S = Q + "skills/quality-pipeline/SKILL.md"
CA = Q + "skills/critiquing-artifacts/SKILL.md"
SY = Q + "scripts/synthesize_findings.py"
SE = Q + "scripts/setup-qg.sh"
ART = Q + "scripts/synthesize_artifact_findings.py"
CONV = "shared/codex/codex_findings_to_yaml.py"
TPL = QT + "test_plain_qg_templates.sh"
SYN = QT + "test_plain_synth_output.sh"
FLD = QT + "test_plain_field_path.sh"

MUTS = {
    "t1": [
        ("Fix-loop 질문을 영어로", S, 'question: "qg 반복 N: 남은 지적이 있다(<summary>). 어떻게 할까?",',
         'question: "qg iter N: findings remain (<summary>). What next?",', [TPL, QT + "test_skill_orchestration.sh"]),
        ("최대 반복 질문을 영어로", S, 'question: "qg 가 최대 5번 반복했다. 마지막 지적: <summary>. 지금 판정으로 끝낼까, 멈출까?",',
         'question: "qg reached max 5 iterations. Last findings: <summary>. Finish with the current verdict or stop?",', [TPL]),
        ("수정 실패 질문을 영어로", S, 'question: "<file> 수정에 실패했다: <reason>. 이번 수정 반복을 멈출까, 이 파일만 건너뛰고 나머지를 계속할까?",',
         'question: "Retry failed at <file>: <reason>. Abort the retry iteration, or skip this file and continue with the remaining patches?",', [TPL]),
        ("라벨 하나를 영어로", S, '{label: "멈추기",               description: "이 반복에서',
         '{label: "Stop",               description: "이 반복에서', [TPL]),
        ("분기 불릿을 옛 라벨로", S, "- **고치고 다시 돌기** → kept > 0 이면", "- **Retry** → kept > 0 이면", [TPL]),
        ("완료 표 제목을 영어로", S, '--title "Quality Gates — 끝"', '--title "Quality Gates — Complete"', [TPL]),
        ("완료 보고 문장 지우기", S, "The completion report opens with the table's 판정 and 결과 in one Korean sentence and ends with exactly one next action for the user (e.g. 「남은 지적 2개를 고친 뒤 /qg 를 다시 돌린다」 or 「할 일 없음」).\n",
         "", [TPL]),
        ("완료 보고 문장의 「할 일 하나」를 뒤집기", S, "ends with exactly one next action for the user",
         "ends with a list of every next action for the user", [TPL]),
        ("trivia 줄을 영어로", S, "작은 수정이라 파이프라인을 건너뛰었다 — 한 문장으로 설명되는 diff 다(CLAUDE.md trivia escape).",
         "Trivia diff — pipeline skipped (one-sentence diff per CLAUDE.md trivia escape).", [TPL]),
        ("session 범위 줄을 영어로", S, "`> 리뷰 범위: 이번 세션에서 바뀐 파일 <COUNT>개. 브랜치 전체를 보려면 /qg branch.`",
         "`> Review scope: session (<COUNT> changed files). 전체 PR/브랜치는 /qg branch.`", [TPL]),
        ("범위 경고에서 토큰을 지우기", S, "범위를 확인하지 못했다(scope check degraded — detached",
         "범위를 확인하지 못했다(detached", [TPL, QT + "harness/test_skill_orchestration_behavior.sh"]),
        ("qg.md 라벨을 옛 것으로", "plugins/quality-gates/commands/qg.md", "iteration 마다 `고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기` 로",
         "iteration 마다 `Retry` / `Accept and finish` / `Stop` 로", [TPL]),
        ("비평 보고 첫 줄 문장 지우기", CA, "보고의 첫 줄은 끝났는지와 결과 한 문장이다(", "보고는 (", [TPL]),
        ("비평 보고 plain 우선 뒤집기", CA, "그것을 먼저 쓰고 원래 `summary` 는 뒤 괄호에 둔다", "원래 `summary` 를 먼저 쓰고 그것은 뒤 괄호에 둔다", [TPL]),
        ("비평 보고 끝 할 일 지우기", CA, " 맨 끝에 사용자가 할 일 하나를 쓴다.", "", [TPL]),
        ("차등 기원 안내의 옵션 이름을 옛 것으로", S, "**「고치고 다시 돌기」 옵션 문구 — 차등", "**Retry 옵션 문구 — 차등", [QT + "test_pipeline_verdict_wiring.sh"]),
        ("README 상태도 표지를 영어로", Q + "README.md", "│   최종 요약  (판정", "│   Final summary  (판정", [QT + "test_readme_state_diagram_complete.sh"]),
    ],
    "t2": [
        ("0 인 등급을 빼지 않기", SY, "            if counts[k]:\n                parts.append", "            if True:\n                parts.append", [SYN]),
        ("첫 줄에 verdict: clean 넣기", SY, 's = "리뷰를 합쳤다 — 확신 높은 지적 없음."', 's = "리뷰를 합쳤다 — 확신 높은 지적 없음. verdict: clean"', [SYN]),
        ("빈 분기 첫 줄을 영어로", SY, '_status_line({"CRITICAL": 0, "IMPORTANT": 0, "SUGGESTION": 0}, suppressed_count, dropped_malformed),',
         '"No high-confidence findings.",', [SYN, QT + "test_synthesize_findings.sh"]),
        ("버린 수를 첫 줄에서 빼기", SY, '        s += " 형식이 깨져 버린 지적 %d개." % dropped_malformed', "        pass", [SYN]),
        ("숨긴 수를 첫 줄에서 빼기", SY, '        s += " 확신이 낮아 숨긴 지적 %d개." % suppressed_count', "        pass", [SYN, QT + "test_synthesize_findings.sh"]),
        ("표 머리를 영어로", SY, '"| 심각도 | 위치 | 확신 | 내용 | 낸 곳 |"', '"| Sev | Path:Line | Conf | Summary | Source |"', [SYN, QT + "test_synthesize_findings.sh"]),
        ("고칠 방법 머리를 영어로", SY, '"**고칠 방법:**"', '"**Suggested fixes:**"', [SYN, QT + "test_synthesize_findings.sh"]),
        ("없는 인자 안내 되살리기", SY, 'f"확신 4 이하 지적 {suppressed_count}개를 숨겼다."',
         'f"확신 4 이하 지적 {suppressed_count}개를 숨겼다. 전부 보려면 `/qg --show-low-confidence`."', [SYN, QT + "test_synthesize_findings.sh"]),
        ("버린 지적 줄에서 토큰 지우기", SY, '형식이 깨졌다(dropped as malformed: 매핑이 아니거나, "\n                "담는 형이 틀리거나, file/severity/summary 가 없다) — stderr 참고. "\n                "**이 실행은',
         '형식이 깨졌다(매핑이 아니거나, "\n                "담는 형이 틀리거나, file/severity/summary 가 없다) — stderr 참고. "\n                "**이 실행은',
         [SYN, QT + "test_skill_drop_notice_consumed.sh", QT + "test_synthesize_promoted_findings.sh"]),
        ("블록 앞 쉬운 줄 지우기", SY, '            sys.stdout.write("아래는 이 판정의 리뷰 각도(angles) 원문이다.\\n")', "            pass", [SYN]),
        ("블록 앞 쉬운 줄을 블록 뒤로", SY,
         '        elif angle_states is not None:\n            sys.stdout.write("아래는 이 판정의 리뷰 각도(angles) 원문이다.\\n")\n'
         '        if scope is not None:\n            sys.stdout.write(_scope_tuple.render(scope))\n'
         '        if angle_states is not None:\n            sys.stdout.write(_angles.render(angle_states))',
         '        if scope is not None:\n            sys.stdout.write(_scope_tuple.render(scope))\n'
         '        if angle_states is not None:\n            sys.stdout.write(_angles.render(angle_states))\n'
         '            if scope is None:\n                sys.stdout.write("아래는 이 판정의 리뷰 각도(angles) 원문이다.\\n")', [SYN]),
        ("두 블록 갈래 지우기", SY, "        if scope is not None and angle_states is not None:\n", "        if False:\n", [SYN]),
        ("블록 앞 쉬운 줄을 두 번", SY,
         '            sys.stdout.write("아래는 이 판정의 리뷰 각도(angles) 원문이다.\\n")',
         '            sys.stdout.write("아래는 이 판정의 리뷰 각도(angles) 원문이다.\\n")\n'
         '            sys.stdout.write("아래는 이 판정의 리뷰 각도(angles) 원문이다.\\n")', [SYN]),
        ("배너 첫 줄을 영어로", SE, 'echo "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다."', 'echo "🔄 Quality Gates Pipeline"', [SYN]),
        ("배너에 과정 나열 되살리기", SE, 'echo "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다."',
         'echo "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다."\necho "Pipeline: scope → differential test → reviewers → re-critique → verdict"', [SYN]),
        ("--paths 오류를 영어만으로", SE, 'echo "❌ --paths 뒤에 glob 이 하나도 없다(--paths requires at least one glob)." >&2',
         'echo "❌ Error: --paths requires at least one glob" >&2', [SYN]),
        ("--paths 오류에서 토큰 지우기", SE, 'echo "❌ --paths 뒤에 glob 이 하나도 없다(--paths requires at least one glob)." >&2',
         'echo "❌ --paths 뒤에 glob 이 하나도 없다." >&2', [SYN, QT + "test_setup_qg.sh"]),
        ("모르는 인자 오류에서 토큰 지우기", SE, 'echo "❌ 모르는 인자다(Unknown argument): $1" >&2', 'echo "❌ 모르는 인자다: $1" >&2', [SYN]),
    ],
    "t3": [
        ("plain 없는 지적을 건너뛰기", SY, '    for f in findings:\n        sev = _norm_sev(f)\n        counts[sev] += 1',
         '    for f in findings:\n        if not f.get("plain"):\n            continue\n        sev = _norm_sev(f)\n        counts[sev] += 1', [FLD]),
        ("plain 을 요약 뒤로", SY, 'summary = _cell(f"{plain} ({f.get(\'summary\', \'\')})")', 'summary = _cell(f"{f.get(\'summary\', \'\')} ({plain})")', [FLD]),
        ("kept 허용 목록에서 plain 빼기", ART, '"severity", "summary", "plain", "proposed_fix", "dedup_key")', '"severity", "summary", "proposed_fix", "dedup_key")', [FLD]),
        ("key 허용 목록에서 plain 빼기", ART, '"severity", "summary", "plain", "proposed_fix", "dedup_key", "stagnation_key")',
         '"severity", "summary", "proposed_fix", "dedup_key", "stagnation_key")', [FLD]),
        ("codex 변환기에서 plain 빼기", CONV, '"summary", "proposed_fix", "plain")', '"summary", "proposed_fix")', [FLD]),
        ("코드 합치기에서 물려받기 지우기", SY, '                if _has_plain(g):\n                    merged["plain"] = g["plain"]\n', "                pass\n", [FLD]),
        ("비코드 합치기에서 물려받기 지우기", ART, '                if not by_key[k].get("plain") and g.get("plain"):\n                    by_key[k]["plain"] = g["plain"]\n', "", [FLD]),
        ("보안 리뷰어 형식에서 plain 빼기", Q + "agents/security-reviewer.md",
         "  plain: <optional — the same finding in one plain sentence a first-time reader understands, no internal IDs>\n", "", [FLD]),
        ("codex 빌더에서 plain 빼기", Q + "scripts/build_codex_prompt.py",
         '      "plain": "<optional: the same finding in one plain sentence a first-time reader understands, no internal IDs>",\n', "", [FLD]),
        ("추가 리뷰어 한 줄의 「평소대로」 뒤집기", S, "다른 칸과 찾는 방식은 평소대로다.", "다른 칸은 짧게 줄인다.", [FLD]),
        ("오케스트레이터 옮겨 적기 지우기", S, "      **각 항목의 `plain:` 도 리뷰어가 낸 값을 그대로 옮긴다** — 없으면 키를 뺀다(지어내지 않는다).\n", "", [FLD]),
        ("오케스트레이터가 plain 을 지어내게", S, "— 없으면 키를 뺀다(지어내지 않는다).", "— 없으면 요약을 보고 지어 넣는다.", [FLD]),
        ("재비판 프로필에서 「내부 번호 없이」 지우기", Q + "references/recritic-code-profile.md", "쉬운 한 문장으로 — 내부 번호 없이 — 쓴다.", "쉬운 한 문장으로 쓴다.", [FLD]),
    ],
    "t4": [
        ("plugin.json 소개 문구 한 글자", Q + ".claude-plugin/plugin.json", "Checks a change before you ship it:", "Checks a change before you ship it;", ["shared/tests/test_charter_citations.sh"]),
        ("marketplace 소개 문구 한 글자", ".claude-plugin/marketplace.json", "Checks a change before you ship it:", "Checks a change before you ship it;", ["shared/tests/test_charter_citations.sh"]),
        ("README 쓰는 법 머리글 지우기", Q + "README.md", "## 쓰는 법\n", "## 사용\n", [QT + "test_plain_readme.sh"]),
        ("README 첫 문단을 옛 것으로", Q + "README.md", "바뀐 코드를 내보내기 전에 확인한다.", "Claude Code용 품질 검증 파이프라인.", [QT + "test_plain_readme.sh"]),
    ],
}

FAILRE = re.compile(r"^[ \t]*✗ |^(FAIL|ERROR)[: ]|^not ok |^BAD ", re.M)


def git(*a):
    return subprocess.run(["git", "-C", R] + list(a), capture_output=True, text=True)


def run(t):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    if t.endswith(".py"):
        p = subprocess.run(["python3", "-m", "unittest", os.path.basename(t)[:-3]], cwd=os.path.join(R, os.path.dirname(t)),
                           capture_output=True, text=True, errors="replace", env=env)
    else:
        p = subprocess.run(["bash", t], cwd=R, capture_output=True, text=True, errors="replace", env=env)
    out = p.stdout + p.stderr
    return p.returncode, len(FAILRE.findall(out))


if git("diff", "HEAD", "--stat").stdout.strip():
    sys.exit("STOP: 작업 트리가 HEAD 와 다르다 — 커밋한 뒤에 변이한다")
survived = 0
for name, rel, old, new, tests in MUTS[TASK]:
    path = os.path.join(R, rel)
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    n = text.count(old)
    if n != 1:
        print("SKIP\t%s\t옛 글자가 %d번(기대 1)" % (name, n)); survived += 1
        continue
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text.replace(old, new))
    try:
        res = [(os.path.basename(t),) + run(t) for t in tests]
    finally:
        git("checkout", "HEAD", "--", rel)
    red = any(rc != 0 for _, rc, _ in res)
    clean = not git("diff", "HEAD", "--stat").stdout.strip()
    if not red:
        survived += 1
    print("%s\t%s\t%s\t%s" % ("RED" if red else "SURVIVED", name,
                              " ".join("%s:rc=%d,fail=%d" % r for r in res), "restored" if clean else "DIRTY"))
    if not clean:
        sys.exit("STOP: 복원 뒤 diff 가 남았다")
print("cells=%d survived=%d" % (len(MUTS[TASK]), survived))
````

---

## Task 1: 질문 셋 · 완료 표 · 모델이 그대로 내는 문구 (AC6)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — 213(trivia 줄) · 281(범위 줄 둘) · 627(범위 경고) · 708 · 714(앵커 설명) · 722-735(Fix-loop 펜스) · 738-744(「Retry 옵션 문구」 단락) · 747 · 755 · 757(분기 불릿) · 787-792(수정 실패 펜스) · 799-801(라벨 설명) · 889-894(최대 반복 펜스) · 923-924(완료 표) · 929-930 뒤(완료 보고 한 문장)
- Modify: `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:283-285`(최종 보고 틀 머리에 한 단락)
- Modify: `plugins/quality-gates/commands/qg.md:114-116 · :137 · :147`(범위 줄 설명 · 선택지 라벨을 부르는 두 자리 — 지시문은 그대로, 부르는 글자만)
- Modify: `plugins/quality-gates/README.md:291-296`(상태도의 표지 — `test_readme_state_diagram_complete.sh` 가 이 Task 에서 새 낱말을 재므로 같은 커밋에서 바꾼다)
- Create: `plugins/quality-gates/tests/test_plain_qg_templates.sh`
- Modify(고정 단언): `tests/test_skill_orchestration.sh:35-46` · `tests/harness/test_skill_orchestration_behavior.sh:378 · :383` · `tests/test_one_pipeline_surface.sh:103` · `tests/test_readme_state_diagram_complete.sh:38-39` · `tests/test_pipeline_verdict_wiring.sh:550 · :554`

- [ ] **Step 1: 실패하는 락을 쓴다**

`plugins/quality-gates/tests/test_plain_qg_templates.sh`:

````bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/critiquing-artifacts/SKILL.md plugins/quality-gates/commands/qg.md
#
# 쉬운 말 출력 설계 §4 · AC6 — /qg 의 질문 셋 · 완료 표 · 모델이 그대로 내는 문구가 한국어이고,
# 완료 보고와 비평 최종 보고가 첫 줄 상태 · 끝 할 일 하나를 지시받는다.
# 부재 단언마다 같은 자리의 양성 짝이 있다(부재 락은 통째로 지워도 통과한다).
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
S="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
CA="$PLUGIN_ROOT/skills/critiquing-artifacts/SKILL.md"
QGMD="$PLUGIN_ROOT/commands/qg.md"
# 산문은 줄바꿈을 지운 본문에서 잰다 — 다시 쓰일 때 문장이 줄을 넘을 수 있다.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
qlines() { grep -E '^[[:space:]]*question:' "$1"; }

# ① 질문 셋 — question 줄에서 잰다(새 문구 양성 · 옛 영어 부재)
assert_grep "$(qlines "$S")" 'question: "qg 반복 N: 남은 지적이 있다\(<summary>\)\. 어떻게 할까\?"' "AC6: Fix-loop 질문이 한국어다"
assert_grep "$(qlines "$S")" 'question: "qg 가 최대 5번 반복했다\. 마지막 지적: <summary>\. 지금 판정으로 끝낼까, 멈출까\?"' "AC6: 최대 반복 질문이 한국어다"
assert_grep "$(qlines "$S")" 'question: "<file> 수정에 실패했다: <reason>\. 이번 수정 반복을 멈출까, 이 파일만 건너뛰고 나머지를 계속할까\?"' "AC6: 수정 실패 질문이 한국어다"
assert_not_grep "$(qlines "$S")" 'findings remain|What next|reached max|Retry failed at' "AC6: 영어 질문이 남지 않았다"
assert_eq "$(qlines "$S" | grep -c .)" "3" "AC6: 이 SKILL 의 question 줄은 셋이다(새로 생기거나 사라진 질문 없음)"

# ② 선택지 라벨 — 새 라벨 양성 · 옛 라벨 부재
for l in '고치고 다시 돌기' '지금 판정으로 끝내기' '멈추기' '이번 반복 멈추기' '이 파일만 건너뛰기'; do
  assert_file_grep "$S" "label: \"$l\"" "AC6: 선택지 라벨 「${l}」"
done
assert_file_absent "$S" 'label: "(Retry|Accept and finish|Stop|Abort retry|Skip this file)"' "AC6: 영어 선택지 라벨이 없다"
assert_file_grep "$S" 'header: "qg 반복 N"' "AC6: Fix-loop 머리글"
assert_file_grep "$S" 'header: "수정 실패"' "AC6: 수정 실패 머리글"
assert_file_grep "$S" 'header: "qg 최대 반복"' "AC6: 최대 반복 머리글"

# ③ 분기 문장의 굵은 라벨이 새 라벨을 부른다(옛 라벨을 부르면 모델이 없는 선택지를 찾는다)
for l in '고치고 다시 돌기' '지금 판정으로 끝내기' '멈추기'; do
  assert_file_grep "$S" "^- \\*\\*$l\\*\\* →" "AC6: 분기 불릿 「${l}」"
done
assert_file_absent "$S" '^- \*\*(Retry|Accept and finish|Stop)\*\* →' "AC6: 옛 분기 불릿이 없다"

# ④ 완료 표 · 완료 보고
assert_file_grep "$S" 'render-terminal\.py table --title "Quality Gates — 끝"' "AC6: 완료 표 제목이 한국어다"
assert_file_absent "$S" 'Quality Gates — Complete' "AC6: 옛 완료 표 제목이 없다"
assert_file_grep "$S" "printf '판정\\\\t" "AC6: 완료 표 첫 칸이 「판정」이다"
assert_contains "$(flat "$S")" 'The completion report opens with the table'"'"'s 판정 and 결과 in one Korean sentence and ends with exactly one next action for the user' "§4: 완료 보고는 첫 줄 상태 · 끝 할 일 하나"

# ⑤ 모델이 그대로 내는 문구 — trivia 줄 · 범위 줄 · 범위 경고
assert_file_grep "$S" '작은 수정이라 파이프라인을 건너뛰었다 — 한 문장으로 설명되는 diff 다\(CLAUDE\.md trivia escape\)' "AC6: trivia 줄이 한국어다"
assert_file_absent "$S" 'Trivia diff — pipeline skipped' "AC6: 옛 trivia 줄이 없다"
assert_file_grep "$S" '> 리뷰 범위: 이번 세션에서 바뀐 파일 <COUNT>개\. 브랜치 전체를 보려면 /qg branch\.' "AC6: session 범위 줄"
assert_file_grep "$S" '> 리뷰 범위: 주제 <topic_key> — 바뀐 파일 <COUNT>개 · 구성원 <branches>\.' "AC6: topic 범위 줄"
assert_file_absent "$S" 'Review scope: (session|topic)' "AC6: 옛 범위 줄이 SKILL 에 없다"
assert_file_absent "$QGMD" 'Review scope: (session|topic)' "AC6: 옛 범위 줄이 qg.md 에 없다"
assert_file_grep "$QGMD" '리뷰 범위: 이번 세션에서 바뀐 파일 N개' "AC6: qg.md 가 새 범위 줄을 설명한다(양성 짝)"
assert_file_grep "$S" '범위를 확인하지 못했다\(scope check degraded' "AC6: 범위 경고가 쉬운 말로 시작하고 토큰을 괄호에 둔다"
assert_file_absent "$S" 'empty-scope detection skipped' "AC6: 옛 영어 범위 경고 꼬리가 없다"

# ⑥ qg.md 가 부르는 라벨
assert_eq "$(grep -cF '`고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기`' "$QGMD")" "2" "AC6: qg.md 가 새 라벨을 두 자리에서 부른다"
assert_file_absent "$QGMD" '`Retry` / `Accept and finish` / `Stop`' "AC6: qg.md 에 옛 라벨 나열이 없다"

# ⑦ 비평 최종 보고
CAF="$(flat "$CA")"
assert_contains "$CAF" '보고의 첫 줄은 끝났는지와 결과 한 문장이다' "§4: 비평 최종 보고 첫 줄"
assert_contains "$CAF" '잔여 `kept` 항목에 `plain:` 이 있으면 그것을 먼저 쓰고 원래 `summary` 는 뒤 괄호에 둔다' "R7: 비평 보고가 plain 을 먼저 쓴다"
assert_contains "$CAF" '맨 끝에 사용자가 할 일 하나를 쓴다' "§4: 비평 최종 보고 끝 할 일 하나"
finish
````

```bash
chmod +x plugins/quality-gates/tests/test_plain_qg_templates.sh
```

- [ ] **Step 2: 고정 단언을 먼저 새 낱말로 바꾼다**

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_skill_orchestration.sh:35 · :36 · :39 · :41` | `findings remain` | `남은 지적이 있다` | 반복 경계 앵커가 정확히 한 질문에만 있다(라우팅 유일성) |
| `test_skill_orchestration.sh:45 · :46` | `Retry` · `Accept and finish` | `고치고 다시 돌기` · `지금 판정으로 끝내기` | Fix-loop 선택지가 있다(옛 `Retry` 단언은 「Retry: file-write safety」 머리글로도 만족돼 공허했다) |
| `harness/test_skill_orchestration_behavior.sh:378 · :383` | `question:.*findings remain` | `question:.*남은 지적이 있다` | 보이기(Step 4.5) 다음에 묻는다 |
| `test_one_pipeline_surface.sh:103` | 머리글 집합에 `qg iter N` | `qg 반복 N` | 반복마다 머리글로 구별된다 |
| `test_readme_state_diagram_complete.sh:38-39` | `findings remain` · `Final summary` | `남은 지적이 있다` · `최종 요약` | README 상태도가 질문과 끝을 그린다 |
| `test_pipeline_verdict_wiring.sh:550` | `\*\*Retry 옵션 문구` | `\*\*「고치고 다시 돌기」 옵션 문구` | 차등 기원(kept = 0) 안내가 그 옵션 문구를 바꾸라고 말한다 |
| `test_pipeline_verdict_wiring.sh:554` | `- \*\*Retry\*\* →.*?(?=\n- \*\*Accept)` | `- \*\*고치고 다시 돌기\*\* →.*?(?=\n- \*\*지금 판정으로 끝내기)` | 분기 불릿이 차등 기원 경우를 갈라 말한다 |

이 표는 `grep -rn -e 'Retry' -e 'Accept' -e 'Stop' -e 'findings remain' -e 'Final summary' -e 'qg iter N' -e 'Review scope' -e 'Trivia diff' plugins/*/tests shared/tests tools` 를 정규식 이스케이프 꼴(`\*\*Retry\*\*`)까지 포함해 훑은 결과다 — 맨 문자열로만 찾으면 `test_pipeline_verdict_wiring.sh` 의 두 자리를 놓친다(드라이런 1회차가 놓쳤다). 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t1_pins.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 1 — 바뀌는 문구를 고정한 기존 단언을 새 낱말로 (리포 루트를 인자로)."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
T = "plugins/quality-gates/tests/"
EDITS = [
    (T + "test_skill_orchestration.sh", "assert_file_grep \"$S\" 'findings remain' \"Fix-loop iter anchor\"",
                                         "assert_file_grep \"$S\" '남은 지적이 있다' \"Fix-loop iter anchor\""),
    (T + "test_skill_orchestration.sh", "# AC6 anchor uniqueness (Medium): `findings remain` must appear in EXACTLY",
                                         "# AC6 anchor uniqueness (Medium): `남은 지적이 있다` must appear in EXACTLY"),
    (T + "test_skill_orchestration.sh", "/^[[:space:]]*question:/ && /findings remain/ { c++ }",
                                         "/^[[:space:]]*question:/ && /남은 지적이 있다/ { c++ }"),
    (T + "test_skill_orchestration.sh", "echo \"FAIL V2b uniqueness: 'findings remain' appears in",
                                         "echo \"FAIL V2b uniqueness: '남은 지적이 있다' appears in"),
    (T + "test_skill_orchestration.sh", "assert_file_grep \"$S\" 'Retry' \"Fix-loop iter option\"",
                                         "assert_file_grep \"$S\" '고치고 다시 돌기' \"Fix-loop iter option\""),
    (T + "test_skill_orchestration.sh", "assert_file_grep \"$S\" 'Accept and finish' \"Fix-loop iter option\"",
                                         "assert_file_grep \"$S\" '지금 판정으로 끝내기' \"Fix-loop iter option\""),
    (T + "harness/test_skill_orchestration_behavior.sh", "# decision's `findings remain` question.",
                                                          "# decision's `남은 지적이 있다` question."),
    (T + "harness/test_skill_orchestration_behavior.sh", "question_line=$(first_line 'question:.*findings remain')",
                                                          "question_line=$(first_line 'question:.*남은 지적이 있다')"),
    (T + "test_one_pipeline_surface.sh", "assert_grep     \"$headers\" 'qg iter N'  ",
                                          "assert_grep     \"$headers\" 'qg 반복 N'  "),
    (T + "test_readme_state_diagram_complete.sh", '  "findings remain"\n  "Final summary"\n',
                                                   '  "남은 지적이 있다"\n  "최종 요약"\n'),
    (T + "test_pipeline_verdict_wiring.sh", r"note = seg(r'\*\*Retry 옵션 문구.*?(?=\n\nBranch on answer:)')",
                                             r"note = seg(r'\*\*「고치고 다시 돌기」 옵션 문구.*?(?=\n\nBranch on answer:)')"),
    (T + "test_pipeline_verdict_wiring.sh", r"bullet = seg(r'- \*\*Retry\*\* →.*?(?=\n- \*\*Accept)')",
                                             r"bullet = seg(r'- \*\*고치고 다시 돌기\*\* →.*?(?=\n- \*\*지금 판정으로 끝내기)')"),
]
texts = {}
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        sys.exit("STOP %s: 옛 문구가 %d번 있다(기대 1): %r" % (rel, n, old[:80]))
    texts[rel] = t.replace(old, new)
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t1_pins.py .
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_qg_templates.sh $Q/test_skill_orchestration.sh $Q/test_one_pipeline_surface.sh $Q/test_readme_state_diagram_complete.sh $Q/test_pipeline_verdict_wiring.sh $Q/harness/test_skill_orchestration_behavior.sh
```

기대(드라이런 실측): `test_plain_qg_templates` 36 중 35 RED(GREEN 하나는 「question 줄은 셋」 — 바뀌기 전에도 참) · `test_skill_orchestration` RED · `test_one_pipeline_surface` 1 RED · `test_readme_state_diagram_complete` RED · `test_pipeline_verdict_wiring` 5 RED · harness FAIL 6(선재 4 + 이 Task 몫 2).

- [ ] **Step 3: SKILL · critiquing-artifacts · qg.md · README 를 고친다**

아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t1_edit.py` 에 쓰고 `python3 … .` 로 돌린다. 바뀌는 것은 사용자에게 그대로 보이는 문구(질문 · 머리글 · 선택지 라벨 · 설명 · 완료 표 · 범위 줄 · trivia 줄 · 범위 경고)와 그 라벨을 부르는 글자뿐이다. 「Retry 옵션 문구」 단락 · 분기 불릿 · 라벨 설명의 지시 문장은 그대로 두고 그 안에서 부르는 라벨만 새 낱말로 바꾼다. 개념어로서의 Retry(「Retry: file-write safety」 · 「Retry patches」 · 「Surface "Retry failed"」 · Law 2 문단의 「("Retry" path)」)는 지시문이라 그대로다. `Then print the last synthesizer output's \`scope:\` block and \`angles:\` block verbatim …` 문장은 그대로 둔다(`test_topic_scope_wiring.sh:290` 이 그 글자를 잰다). `scope check degraded` 토큰은 괄호에 남는다(`harness/test_skill_orchestration_behavior.sh` 의 「degraded scope advisory present」).

````python
#!/usr/bin/env python3
"""PR 3 Task 1 — 질문 셋 · 완료 표 · 모델이 그대로 내는 문구 (리포 루트를 인자로)."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
S = "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
CA = "plugins/quality-gates/skills/critiquing-artifacts/SKILL.md"
QGMD = "plugins/quality-gates/commands/qg.md"
README = "plugins/quality-gates/README.md"

FIX_OLD = '''AskUserQuestion({
  questions: [
    {
      question: "qg iter N: findings remain (<summary>). What next?",
      header: "qg iter N",
      options: [
        {label: "Retry",             description: "Apply the suggested fixes (I will Edit the files in this turn), then re-run the pipeline for the next iteration — differential test included."},
        {label: "Accept and finish", description: "Accept current findings as-is and go to the final summary with the current verdict."},
        {label: "Stop",              description: "Abort the pipeline at this iteration. Address findings and re-run /qg."}
      ],'''
FIX_NEW = '''AskUserQuestion({
  questions: [
    {
      question: "qg 반복 N: 남은 지적이 있다(<summary>). 어떻게 할까?",
      header: "qg 반복 N",
      options: [
        {label: "고치고 다시 돌기",      description: "제안된 수정을 이 턴에서 파일에 적용하고 다음 반복을 돈다(차등 테스트 포함)."},
        {label: "지금 판정으로 끝내기", description: "남은 지적을 그대로 두고 지금 판정으로 최종 요약에 간다."},
        {label: "멈추기",               description: "이 반복에서 멈춘다. 지적을 고친 뒤 /qg 를 다시 돌린다."}
      ],'''

RETRY_PARA_OLD = '''**Retry 옵션 문구 — 차등 테스트 기원(kept = 0)에는 그대로 쓰지 않는다.** 위 리터럴의
"Apply the suggested fixes" 는 합성기의 finding-기반 제안을 전제한다 — kept = 0, 차등
테스트 기원 defect 에는 그 제안 자체가 없다(`**Findings:**` counts 줄이 안 나온다). 이
트리거로 디스패치할 때는 `Retry` 옵션의 `description` 을 "Fix the regressed units named
in <summary> (e.g. NEW_REGRESSION), then re-run the pipeline for the next iteration —
differential test included." 로 바꿔 싣는다 — 없는 제안을 있다고 말하지 않는다. 다른
두 옵션 문구는 그대로다.'''
RETRY_PARA_NEW = '''**「고치고 다시 돌기」 옵션 문구 — 차등 테스트 기원(kept = 0)에는 그대로 쓰지 않는다.** 위 리터럴의
"제안된 수정을 이 턴에서 파일에 적용하고" 는 합성기의 finding-기반 제안을 전제한다 — kept = 0, 차등
테스트 기원 defect 에는 그 제안 자체가 없다(`**Findings:**` counts 줄이 안 나온다). 이
트리거로 디스패치할 때는 「고치고 다시 돌기」 옵션의 `description` 을 "<summary> 에 적힌 회귀
단위(예: NEW_REGRESSION)를 고치고 다음 반복을 돈다(차등 테스트 포함)." 로 바꿔 싣는다 — 없는
제안을 있다고 말하지 않는다. 다른 두 옵션 문구는 그대로다.'''

RF_OLD = '''      question: "Retry failed at <file>: <reason>. Abort the retry iteration, or skip this file and continue with the remaining patches?",
      header: "Retry",
      options: [
        {label: "Abort retry",     description: "Abort this Retry iteration entirely; surface as failure to the qg verdict."},
        {label: "Skip this file",  description: "Skip THIS file's fix only; continue applying remaining Retry patches in this iteration."}
      ],'''
RF_NEW = '''      question: "<file> 수정에 실패했다: <reason>. 이번 수정 반복을 멈출까, 이 파일만 건너뛰고 나머지를 계속할까?",
      header: "수정 실패",
      options: [
        {label: "이번 반복 멈추기",  description: "이번 수정 반복 전체를 멈추고 qg 판정에 실패로 올린다."},
        {label: "이 파일만 건너뛰기", description: "이 파일의 수정만 건너뛰고 나머지 수정은 이번 반복에서 계속 적용한다."}
      ],'''

MAX_OLD = '''      question: "qg reached max 5 iterations. Last findings: <summary>. Finish with the current verdict or stop?",
      header: "qg max-iter",
      options: [
        {label: "Accept and finish", description: "Accept residual findings and go to the final summary."},
        {label: "Stop",              description: "Abort the pipeline. Address findings and re-run /qg."}
      ],'''
MAX_NEW = '''      question: "qg 가 최대 5번 반복했다. 마지막 지적: <summary>. 지금 판정으로 끝낼까, 멈출까?",
      header: "qg 최대 반복",
      options: [
        {label: "지금 판정으로 끝내기", description: "남은 지적을 받아들이고 최종 요약에 간다."},
        {label: "멈추기",               description: "파이프라인을 멈춘다. 지적을 고친 뒤 /qg 를 다시 돌린다."}
      ],'''

TABLE_OLD = '''printf 'Verdict\\t<마지막 verdict: 값 — not-certified 면 (<reason>) 포함>\\nIterations\\t<N>\\nOutcome\\t<finished | accepted with findings iter N | aborted iter N>\\n' \\
  | $QG/scripts/render-terminal.py table --title "Quality Gates — Complete"'''
TABLE_NEW = '''printf '판정\\t<마지막 verdict: 값 — not-certified 면 (<reason>) 포함>\\n반복\\t<N>번\\n결과\\t<끝났다 | 지적을 남기고 끝냈다(반복 N) | 멈췄다(반복 N)>\\n' \\
  | $QG/scripts/render-terminal.py table --title "Quality Gates — 끝"'''

HIST_OLD = '''and the appended `## History` lines from the state file as an indented tree
beneath.
'''
HIST_NEW = '''and the appended `## History` lines from the state file as an indented tree
beneath.

The completion report opens with the table's 판정 and 결과 in one Korean sentence and ends with exactly one next action for the user (e.g. 「남은 지적 2개를 고친 뒤 /qg 를 다시 돌린다」 or 「할 일 없음」).
'''

EDITS = [
    (S, "The iter-boundary anchor phrase `findings remain` is specific to this",
        "The iter-boundary anchor phrase `남은 지적이 있다` is specific to this"),
    (S, "> **Spec anchor (AC6):** the literal phrase `findings remain` MUST appear",
        "> **Spec anchor (AC6):** the literal phrase `남은 지적이 있다` MUST appear"),
    (S, FIX_OLD, FIX_NEW),
    (S, RETRY_PARA_OLD, RETRY_PARA_NEW),
    (S, "- **Retry** → kept > 0 이면", "- **고치고 다시 돌기** → kept > 0 이면"),
    (S, "- **Accept and finish** → exit the loop", "- **지금 판정으로 끝내기** → exit the loop"),
    (S, "- **Stop** → emit final summary", "- **멈추기** → emit final summary"),
    (S, RF_OLD, RF_NEW),
    (S, 'are explicit: "Abort retry" terminates the iteration; "Skip this file"',
        'are explicit: "이번 반복 멈추기" terminates the iteration; "이 파일만 건너뛰기"'),
    (S, MAX_OLD, MAX_NEW),
    (S, TABLE_OLD, TABLE_NEW),
    (S, HIST_OLD, HIST_NEW),
    (S, "Print `Trivia diff — pipeline skipped (one-sentence diff per CLAUDE.md trivia escape).`",
        "Print `작은 수정이라 파이프라인을 건너뛰었다 — 한 문장으로 설명되는 diff 다(CLAUDE.md trivia escape).`"),
    (S, "`> Review scope: session (<COUNT> changed files). 전체 PR/브랜치는 /qg branch.`",
        "`> 리뷰 범위: 이번 세션에서 바뀐 파일 <COUNT>개. 브랜치 전체를 보려면 /qg branch.`"),
    (S, "`> Review scope: topic <topic_key> (<COUNT> changed files · 구성원 <branches>).`",
        "`> 리뷰 범위: 주제 <topic_key> — 바뀐 파일 <COUNT>개 · 구성원 <branches>.`"),
    (S, "`> [quality-gates] scope check degraded (detached HEAD / no base branch / unrelated history / shallow) — empty-scope detection skipped (fail-open; this run's scope-empty floor input is unavailable — the other reasons in Step 4's table still apply normally).`",
        "`> [quality-gates] 범위를 확인하지 못했다(scope check degraded — detached HEAD / no base branch / unrelated history / shallow) — 바뀐 파일이 0개인지 보는 검사를 건너뛰었다(fail-open). Step 4 표의 다른 사유는 그대로 적용된다.`"),
    (CA, "## 종료 & 최종 요약 (AC11)\n\n",
         "## 종료 & 최종 요약 (AC11)\n\n"
         "보고의 첫 줄은 끝났는지와 결과 한 문장이다(예: 「비평을 3라운드 돌고 수렴했다 — 남은 지적 없음.」 · "
         "「상한 5라운드에 닿았다 — 남은 지적 2개.」). 잔여 `kept` 항목에 `plain:` 이 있으면 그것을 먼저 쓰고 "
         "원래 `summary` 는 뒤 괄호에 둔다. 맨 끝에 사용자가 할 일 하나를 쓴다.\n\n"),
    (QGMD, "`Review scope: session (N files)`", "`리뷰 범위: 이번 세션에서 바뀐 파일 N개.`"),
    (QGMD, "`Review scope: topic <키> (N files · 구성원 <branches>)`", "`리뷰 범위: 주제 <키> — 바뀐 파일 N개 · 구성원 <branches>.`"),
    (QGMD, "iteration 마다 `Retry` / `Accept and finish` / `Stop` 로", "iteration 마다 `고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기` 로"),
    (QGMD, "iteration boundary with `Retry` / `Accept and finish` / `Stop`.", "iteration boundary with `고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기`."),
    (README,
     '│                                    ("findings remain..." │           │   │\n'
     '│                                     Retry / Accept and   │           │   │\n'
     '│                                     finish / Stop)       │           │   │\n'
     '│                                        │ Retry → next iteration     │   │\n',
     '│                                    ("남은 지적이 있다…"  │           │   │\n'
     '│                                     고치고 다시 돌기 /   │           │   │\n'
     '│                                     지금 판정으로 끝내기 /│           │   │\n'
     '│                                     멈추기)              │           │   │\n'
     '│                                        │ 고치고 다시 돌기 → 다음 반복 │   │\n'),
    (README,
     '│   Final summary  (Verdict · Iterations · Outcome · angles) ◀────────┘   │',
     '│   최종 요약  (판정 · 반복 · 결과 · angles) ◀────────────────────────┘   │'),
]

texts = {}
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        sys.exit("STOP %s: 옛 문구가 %d번 있다(기대 1): %r" % (rel, n, old[:80]))
    texts[rel] = t.replace(old, new)
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t1_edit.py .
```

- [ ] **Step 4: 테스트를 돈다**

```bash
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_qg_templates.sh $Q/test_skill_orchestration.sh $Q/test_one_pipeline_surface.sh $Q/test_readme_state_diagram_complete.sh $Q/test_pipeline_verdict_wiring.sh $Q/test_topic_scope_wiring.sh $Q/test_review_scope_composition.sh $Q/test_critiquing_artifacts_skill.sh $Q/test_skill_drop_notice_consumed.sh $Q/test_qg_critique_routing.sh $Q/test_runtime_verdict_precedence.sh $Q/test_guards_coverage_bidirectional.sh $Q/test_runner_adapters.sh shared/tests/test_invocation_surface.sh shared/tests/test_plain_language_block.sh shared/tests/test_skill_body_no_positional_tokens.sh $Q/harness/test_skill_orchestration_behavior.sh
grep -a '^FAIL' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/logs/test_skill_orchestration_behavior.sh.log
python3 shared/entry/check_invocation_surface.py --report | grep -c '^| [0-9]'
```

기대(드라이런 실측): 앞의 열여섯은 `rc=0`(36/36 · 3/3 · 88/88 · 9 markers · 78/78 · 79/79 · 32 · 35/35 · 12/12 · 5/5 · 22/22 · 349/349 · 53/53 · 69/69 · 14/14 · 6/6). harness 는 FAIL 줄이 선재 넷뿐이다. 보고 표 행 22.

- [ ] **Step 5: 커밋**

```bash
Q=plugins/quality-gates/tests
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/critiquing-artifacts/SKILL.md plugins/quality-gates/commands/qg.md plugins/quality-gates/README.md \
  $Q/test_plain_qg_templates.sh $Q/test_skill_orchestration.sh $Q/harness/test_skill_orchestration_behavior.sh $Q/test_one_pipeline_surface.sh $Q/test_readme_state_diagram_complete.sh $Q/test_pipeline_verdict_wiring.sh
git commit -m "feat(qg): 질문 셋과 완료 표, 모델이 그대로 내는 문구를 한국어 쉬운 말로

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat HEAD | tail -1
```

기대: `10 files changed`.

- [ ] **Step 6: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py . t1 | tee ~/.claude/sdd-mirror/plain-language-output/pr3/mut-t1.txt
```

기대(드라이런 실측): `cells=17 survived=0`, 줄마다 `restored`. 「범위 경고에서 토큰을 지우기」 셀의 harness 는 rc 가 원래 1 이다 — FAIL 줄 수가 4 → 5 로 느는지로 본다.

---

## Task 2: 합성기 · 시작 배너 · setup 오류 줄 (Goal 2 · AC5 · AC6 · R1 · R2 · R8 · R10 · R11 · R12)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py:615-712`(`render()` 앞의 `_status_line` · 빈 분기 · 표 행 · 표 분기 · 꼬리) · `:926-929`(`--emit-verdict` 꼬리의 블록 앞 한 줄)
- Modify: `plugins/quality-gates/scripts/setup-qg.sh:16 · :42 · :72 · :84 · :114-115 · :133-135 · :142 · :252-262`
- Modify: `plugins/quality-gates/tests/e2e-scenarios.md:99`(kill switch 거부 줄을 인용한다)
- Create: `plugins/quality-gates/tests/test_plain_synth_output.sh`
- Modify(고정 단언 — Step 2 의 표)

**Interfaces:**
- Produces: 합성기 stdout 첫 줄 = `_status_line(counts, suppressed_count, dropped_malformed)`:
  - 발견 0: `리뷰를 합쳤다 — 확신 높은 지적 없음.`
  - 발견 ≥1: `리뷰를 합쳤다 — 남은 지적 N개(심각 a · 중요 b · 제안 c).` (0 인 등급은 뺀다)
  - 뒤에 붙는 것: 숨긴 것이 있으면 ` 확신이 낮아 숨긴 지적 N개.`, 버린 것이 있으면 ` 형식이 깨져 버린 지적 N개.`
  - 이 줄은 `verdict` 글자를 담지 않는다.
- 둘째 줄부터: `## 리뷰 지적 (합친 결과)` · 빈 줄 · (발견 ≥1 이면) `**Findings:**` 줄(형태 그대로) · 처분 줄 셋(그대로) · …
- `--emit-verdict` 꼬리: 블록이 있을 때만 첫 블록 앞에 쉬운 한 줄(R2).

- [ ] **Step 1: 실패하는 락을 쓴다**

`plugins/quality-gates/tests/test_plain_synth_output.sh`:

````bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/setup-qg.sh
#
# 쉬운 말 출력 설계 Goal 2 · AC5 · AC6 (계획 R1 · R2 · R8 · R10 · R11) — 합성기와 시작 배너의 첫 줄이
# 상태 문장이고 0 인 정상 집계가 없다. 판단에 필요한 0(처분 줄)은 남는다. setup 의 오류 줄은
# 쉬운 말로 시작하고 원래 영어 토큰을 괄호에 남긴다.
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
SETUP="$PLUGIN_ROOT/scripts/setup-qg.sh"
export PYTHONDONTWRITEBYTECODE=1
unset CLAUDE_CODE_SESSION_ID
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT

# ① 발견 0
printf '[]\n' > "$T/empty.yaml"
out="$(python3 "$SYNTH" --findings "$T/empty.yaml")"
assert_eq "$(printf '%s\n' "$out" | head -1)" "리뷰를 합쳤다 — 확신 높은 지적 없음." "Goal 2: 발견 0 의 첫 줄이 상태 문장이다"
assert_not_contains "$out" "No high-confidence" "AC6: 영어 고정 문구가 없다"
assert_grep "$out" '^## 리뷰 지적 \(합친 결과\)$' "AC6: 머리글이 한국어다(양성 짝)"
assert_grep "$out" '^\*\*처분:\*\* ' "R1: 처분 줄(판단에 필요한 0)은 남는다"
assert_not_contains "$(printf '%s\n' "$out" | head -1)" "verdict" "AC5: 쉬운 첫 줄은 verdict 글자를 담지 않는다"

# ② 발견 ≥1 (심각 1 · 중요 0 · 제안 0 → 0 인 등급은 첫 줄에 없다)
printf -- '- agent: security-reviewer\n  file: app.py\n  line: 3\n  severity: CRITICAL\n  confidence: 9\n  summary: "SQL 을 문자열로 만든다"\n  proposed_fix: "바인딩"\n' > "$T/one.yaml"
out="$(python3 "$SYNTH" --findings "$T/one.yaml")"
assert_eq "$(printf '%s\n' "$out" | head -1)" "리뷰를 합쳤다 — 남은 지적 1개(심각 1)." "Goal 2: 발견 ≥1 의 첫 줄이 상태 문장이고 0 인 등급을 뺀다"
assert_grep "$out" '^\*\*Findings:\*\* 1 CRITICAL / 0 IMPORTANT / 0 SUGGESTION$' "AC5: 기계가 읽는 Findings 줄은 형태 그대로다"
assert_grep "$out" '^\| 심각도 \| 위치 \| 확신 \| 내용 \| 낸 곳 \|$' "AC6: 표 머리가 한국어다"
assert_not_contains "$out" "| Sev |" "AC6: 영어 표 머리가 없다"
assert_grep "$out" '^\*\*고칠 방법:\*\*$' "AC6: 제안 수정 머리가 한국어다"

# ③ 확신이 낮아 숨긴 지적 — 첫 줄과 꼬리가 수를 말하고, 없는 인자를 가리키지 않는다(R11)
printf -- '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}\n- {agent: r, file: q.py, line: 1, severity: SUGGESTION, confidence: 3, summary: low, proposed_fix: f}\n- {agent: r, file: w.py, line: 2, severity: IMPORTANT, confidence: 6, summary: mid, proposed_fix: f}\n' > "$T/sup.yaml"
out="$(python3 "$SYNTH" --findings "$T/sup.yaml")"
assert_eq "$(printf '%s\n' "$out" | head -1)" "리뷰를 합쳤다 — 남은 지적 2개(중요 2). 확신이 낮아 숨긴 지적 1개." "Goal 2: 숨긴 수를 첫 줄에 붙인다"
assert_grep "$out" '^확신 4 이하 지적 1개를 숨겼다\.$' "AC6: 숨긴 지적 꼬리 줄이 한국어다"
assert_grep "$out" '^`\*` = 확신 6 이하 — 조심해서 볼 것\.$' "AC6: 낮은 확신 표시의 뜻이 한국어다"
assert_not_contains "$out" "show-low-confidence" "R11: 없는 인자(/qg --show-low-confidence)를 가리키지 않는다"

# ④ 버린 지적 — 첫 줄이 버린 수를 말하고, 꼬리 줄은 쉬운 말이 앞 · 소비자가 읽는 토큰(dropped as malformed)은 괄호에
printf -- '- "매핑이 아닌 항목"\n' > "$T/bad.yaml"
out="$(python3 "$SYNTH" --findings "$T/bad.yaml" 2>/dev/null)"
assert_eq "$(printf '%s\n' "$out" | head -1)" "리뷰를 합쳤다 — 확신 높은 지적 없음. 형식이 깨져 버린 지적 1개." "Goal 2: 버린 수를 첫 줄에 붙인다(없는 것과 버린 것은 다르다)"
assert_grep "$out" '^1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed: ' "AC6: 버린 지적 줄이 쉬운 말로 시작하고 토큰을 남긴다"

# ⑤ --emit-verdict: 판정 줄은 정확히 하나, 쉬운 줄과 섞이지 않는다. 블록 앞에 쉬운 한 줄(AC5)
printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
out="$(python3 "$SYNTH" --findings "$T/one.yaml" --emit-verdict --angles "$T/angles.txt")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^verdict: ')" "1" "AC5: verdict 줄은 정확히 한 번"
assert_eq "$(printf '%s\n' "$out" | grep -c 'verdict:')" "1" "AC5: 그 밖의 줄에 verdict: 글자가 없다"
assert_eq "$(printf '%s\n' "$out" | grep -B1 '^angles:$' | head -1)" "아래는 이 판정의 리뷰 각도(angles) 원문이다." "AC5: angles 블록 바로 앞에 쉬운 한 줄"
assert_eq "$(printf '%s\n' "$out" | grep -c '^아래는 이 판정')" "1" "AC5: 그 쉬운 줄은 한 번만 나온다"
printf 'topic_key: -\nstatus: no-declaration\nreason: -\nbranches: -\nin_base: -\nboundary: -\ntips: -\nseal: -\nseal_on_topic: -\ntree: -\nhead_commit: -\nconflicts: -\ncommits: -\n' > "$T/scope.txt"
out="$(python3 "$SYNTH" --findings "$T/one.yaml" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")"
assert_eq "$(printf '%s\n' "$out" | grep -B1 '^scope:$' | head -1)" "아래는 이 판정이 본 범위(scope)와 리뷰 각도(angles)의 원문이다." "AC5: 두 블록이면 scope 블록 앞에 두 블록을 다 가리키는 한 줄"
assert_eq "$(printf '%s\n' "$out" | grep -c '^아래는 이 판정')" "1" "AC5: 두 블록이어도 쉬운 줄은 한 번"
out="$(python3 "$SYNTH" --findings "$T/one.yaml" --emit-verdict --scope "$T/scope.txt")"
assert_eq "$(printf '%s\n' "$out" | grep -B1 '^scope:$' | head -1)" "아래는 이 판정이 본 범위(scope)의 원문이다." "AC5: scope 블록만 있으면 그것만 가리킨다"
out="$(python3 "$SYNTH" --findings "$T/one.yaml" --emit-verdict)"
assert_not_contains "$out" "아래는 이 판정" "AC5: 블록이 없으면 블록을 가리키는 줄도 없다"

# ⑥ 시작 배너 — 첫 줄이 상태 문장이고 과정 나열이 없다
mkdir -p "$T/w"
out="$(cd "$T/w" && bash "$SETUP" --session-id "plaintest-$$" --plan docs/p.md 2>/dev/null)"
assert_eq "$(printf '%s\n' "$out" | head -1)" "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다." "Goal 2: 시작 배너 첫 줄이 상태 문장이다"
assert_not_contains "$out" "Pipeline:" "Goal 2: 시작 배너에 과정 나열이 없다"
assert_not_contains "$out" "Pipeline runs in this turn" "AC6: 옛 영어 배너 끝줄이 없다"
assert_grep "$out" '^계획 파일: docs/p\.md$' "AC6: 계획 파일 줄이 한국어다"

# ⑦ setup 오류 줄(R10) — 쉬운 말이 앞, 원래 영어 토큰은 괄호에(기존 락이 그 토큰을 잰다)
err="$(cd "$T/w" && bash "$SETUP" --paths 2>&1 >/dev/null)"
assert_contains "$err" "--paths 뒤에 glob 이 하나도 없다" "R10: --paths 오류가 쉬운 말로 시작한다"
assert_contains "$err" "requires at least one glob" "R10: --paths 오류가 토큰을 남긴다(양성 짝)"
err="$(cd "$T/w" && bash "$SETUP" --no-such-flag 2>&1 >/dev/null)"
assert_contains "$err" "모르는 인자다" "R10: 모르는 인자 오류가 쉬운 말로 시작한다"
assert_contains "$err" "Unknown argument" "R10: 모르는 인자 오류가 토큰을 남긴다(양성 짝)"
err="$(cd "$T/w" && bash "$SETUP" 2>&1 >/dev/null)"
assert_contains "$err" "세션 ID(session ID)가 비어 있어" "R10: 세션 ID 없음 오류가 쉬운 말로 시작한다"
err="$(cd "$T/w" && DEVBREW_QUALITY_GATES_DISABLE=1 bash "$SETUP" 2>&1 >/dev/null)"
assert_contains "$err" "/qg 를 시작하지 않는다(setup-qg disabled)" "R10: kill switch 거부 줄이 쉬운 말이다"
finish
````

```bash
chmod +x plugins/quality-gates/tests/test_plain_synth_output.sh
```

- [ ] **Step 2: 고정 단언을 새 문구로**

전수는 옛 문구를 **앞부분 조각**까지 찾아 얻었다(`No high-confidence` 만 쓰는 자리가 따로 있다 — 드라이런 1회차가 놓쳤다). 부재 단언(셋째 열이 부정형인 것)은 새 문구로 같이 옮긴다 — 옛 영어만 재면 새 문구에서 공허하게 GREEN 이다.

```bash
for lit in 'No high-confidence' 'low-confidence' 'treat with caution' 'confidence <= 6' 'suppressed (conf <= 4)' 'show-low-confidence' 'dropped as malformed' 'Suggested fixes' 'Review Findings' '| Sev |' 'Path:Line' 'setup-qg disabled' 'requires at least one glob' 'Unknown argument' 'session ID' 'Pipeline:' 'Plan file'; do
  printf '== %s\n' "$lit"; /usr/bin/grep -rnF -- "$lit" plugins shared tools 2>/dev/null | /usr/bin/grep -v -e '/golden/' -e 'CHANGELOG' | cut -c1-170
done > ~/.claude/sdd-mirror/plain-language-output/pr3/fixed-string-hits.txt
```

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_angle_coverage.sh:201 · :302` | `No high-confidence findings\. 1 low-confidence` | `확신 높은 지적 없음\. 확신이 낮아 숨긴 지적 1개` | 전부 억제된 분기가 알아보이고 숨긴 수를 말한다 |
| `test_angle_coverage.sh:89-95`(R-J) | off = on − `angles:` 블록 | off = on − `angles:` 블록 − 그 앞의 쉬운 한 줄 | 각도를 안 주면 블록(과 그 블록을 가리키는 줄)만 빠지고 나머지는 바이트 동일 |
| `test_recritic_bridge.sh:442` | `No high-confidence findings. 1 low-confidence` | `확신 높은 지적 없음. 확신이 낮아 숨긴 지적 1개` | 억제된 added 가 억제로 세어진다 |
| `test_synthesize_disposition.sh:125 · :226` | `No high-confidence findings` | `확신 높은 지적 없음` | clean(kept=0) 렌더 분기를 실제로 태운다 |
| `test_synthesize_findings.sh:48` | `No high-confidence` | `확신 높은 지적 없음` | 기각된 지적은 표에 없다 |
| `test_synthesize_findings.sh:88` | `## Review Findings.*\| Sev \| Path:Line \| Conf \| Summary \| Source \|` | `## 리뷰 지적 \(합친 결과\).*\| 심각도 \| 위치 \| 확신 \| 내용 \| 낸 곳 \|` | 표 머리 스키마 |
| `test_synthesize_findings.sh:100` | `\*\*Suggested fixes:\*\*.*`x\.py:1` —` | `\*\*고칠 방법:\*\*.*`x\.py:1` —` | 제안 수정이 위치와 함께 나온다 |
| `test_synthesize_findings.sh:106` | `` `\*` = confidence <= 6 \(treat with caution\)\. `` | `` `\*` = 확신 6 이하 — 조심해서 볼 것\. `` | 낮은 확신 표시의 뜻 |
| `test_synthesize_findings.sh:112`(부재) | `confidence <= 6 \(treat` | `확신 6 이하 — 조심` | 낮은 확신이 없으면 표시 뜻도 없다 |
| `test_synthesize_findings.sh:119` | `finding\(s\) suppressed \(conf <= 4\); re-run with …` · 부재 `q\.py:1 \|` | `확신 4 이하 지적 1개를 숨겼다\.` · 부재 `q\.py:1 \||show-low-confidence` | 숨긴 수를 말하고 없는 인자를 가리키지 않는다(R11) |
| `test_synthesize_findings.sh:130` | `No high-confidence findings\. 1 low-confidence findings suppressed` | `확신 높은 지적 없음\. 확신이 낮아 숨긴 지적 1개\.` | 전부 억제된 빈 분기 |
| `test_synthesize_findings.sh:136`(부재) | `finding\(s\) suppressed\|suppressed \(conf <= 4\)` | `확신 4 이하 지적\|숨긴 지적\|suppressed \(conf <= 4\)` | 억제 0 이면 억제 문구가 없다 |
| `test_synthesize_findings.sh:154` | `No high-confidence findings` | `확신 높은 지적 없음` | 빈 입력 |
| `test_synthesize_findings_adjudication.py:215` | `"No high-confidence findings."` | `"확신 높은 지적 없음."` | clean 실행의 양성 짝 |
| `test_synthesize_findings_adjudication.py:494` | `assertNotIn("suppressed (conf <= 4)", …)` | 그대로 두고 `assertNotIn("숨긴 지적", …)` 한 줄을 더한다 | 억제 0 이면 사람용 줄에도 숨긴 지적이 없다(부재 단언이 새 문구에서도 공허하지 않게) |
| `test_synthesize_promoted_findings.sh:222 · :244` | `^2 finding\(s\) dropped as malformed` | `^2개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed` | 버린 주장이 stdout 에 보인다 |
| `test_synthesize_promoted_findings.sh:363` | `^1 finding\(s\) dropped as malformed` | `^1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed` | 스칼라 findings 는 1건 소실 |

그대로 GREEN 이어야 하는 것(고치지 않는다): `test_skill_drop_notice_consumed.sh`(SKILL 과 합성기가 `dropped as malformed` 를 같은 글자로 쓴다 — 토큰이 괄호에 남는다) · `test_synthesize_disposition.sh:268` · `test_recritic_bridge.sh:449 · :543`(같은 토큰) · `test_setup_qg.sh:73 · :85 · :101 · :104 · :107 · :132`(`session` · `Unknown argument` · `requires at least one glob` 토큰 — R10) · `test_verdict_vocabulary.sh`(**수정 없이** GREEN — AC5).

아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t2_pins.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 2 — 합성기 문구를 고정한 기존 단언을 새 문구로 (리포 루트를 인자로).
항목은 (파일, 옛, 새, 기대 개수). 기대 개수와 다르면 아무것도 쓰지 않고 멈춘다."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
T = "plugins/quality-gates/tests/"
EDITS = [
    (T + "test_angle_coverage.sh",
     "'No high-confidence findings\\. 1 low-confidence'",
     "'확신 높은 지적 없음\\. 확신이 낮아 숨긴 지적 1개'", 2),
    (T + "test_angle_coverage.sh",
     "    /^angles:$/ { skip = n; next }\n    skip > 0 { skip--; next }\n    { print }",
     "    /^아래는 이 판정의 리뷰 각도\\(angles\\) 원문이다\\.$/ { next }\n"
     "    /^angles:$/ { skip = n; next }\n    skip > 0 { skip--; next }\n    { print }", 1),
    (T + "test_angle_coverage.sh",
     '"off 는 on 에서 angles: 블록(헤더 1줄 + 각도 ${angle_lines}줄)을 뺀 것과 바이트 동일하다"',
     '"off 는 on 에서 angles: 블록(헤더 1줄 + 각도 ${angle_lines}줄)과 그 앞의 쉬운 한 줄을 뺀 것과 바이트 동일하다"', 1),
    (T + "test_recritic_bridge.sh",
     "'No high-confidence findings. 1 low-confidence'",
     "'확신 높은 지적 없음. 확신이 낮아 숨긴 지적 1개'", 1),
    (T + "test_synthesize_disposition.sh",
     "'No high-confidence findings' \\",
     "'확신 높은 지적 없음' \\", 2),
    (T + "test_synthesize_findings.sh",
     "'## Review Findings.*\\| Sev \\| Path:Line \\| Conf \\| Summary \\| Source \\|' ''",
     "'## 리뷰 지적 \\(합친 결과\\).*\\| 심각도 \\| 위치 \\| 확신 \\| 내용 \\| 낸 곳 \\|' ''", 1),
    (T + "test_synthesize_findings.sh",
     "'\\*\\*Suggested fixes:\\*\\*.*`x\\.py:1` —' ''",
     "'\\*\\*고칠 방법:\\*\\*.*`x\\.py:1` —' ''", 1),
    (T + "test_synthesize_findings.sh",
     "'`\\*` = confidence <= 6 \\(treat with caution\\)\\.' ''",
     "'`\\*` = 확신 6 이하 — 조심해서 볼 것\\.' ''", 1),
    (T + "test_synthesize_findings.sh",
     "'' 'confidence <= 6 \\(treat'",
     "'' '확신 6 이하 — 조심'", 1),
    (T + "test_synthesize_findings.sh",
     "'finding\\(s\\) suppressed \\(conf <= 4\\); re-run with `/qg --show-low-confidence` to see all\\.' 'q\\.py:1 \\|'",
     "'확신 4 이하 지적 1개를 숨겼다\\.' 'q\\.py:1 \\||show-low-confidence'", 1),
    (T + "test_synthesize_findings.sh",
     "'No high-confidence findings\\. 1 low-confidence findings suppressed' 'x\\.py:1'",
     "'확신 높은 지적 없음\\. 확신이 낮아 숨긴 지적 1개\\.' 'x\\.py:1'", 1),
    (T + "test_synthesize_findings.sh",
     "'' 'finding\\(s\\) suppressed|suppressed \\(conf <= 4\\)'",
     "'' '확신 4 이하 지적|숨긴 지적|suppressed \\(conf <= 4\\)'", 1),
    (T + "test_synthesize_findings.sh",
     "  'No high-confidence findings' ''",
     "  '확신 높은 지적 없음' ''", 1),
    (T + "test_synthesize_findings.sh",
     "  'No high-confidence' 'a.py:10'",
     "  '확신 높은 지적 없음' 'a.py:10'", 1),
    (T + "test_synthesize_findings_adjudication.py",
     'self.assertIn("No high-confidence findings.", clean)',
     'self.assertIn("확신 높은 지적 없음.", clean)', 1),
    (T + "test_synthesize_findings_adjudication.py",
     '''        self.assertNotIn("suppressed (conf <= 4)", out,
                         "「suppressed」 집계에 0 이 아닌 수로 세지지 않는다")''',
     '''        self.assertNotIn("suppressed (conf <= 4)", out,
                         "「suppressed」 집계에 0 이 아닌 수로 세지지 않는다")
        self.assertNotIn("숨긴 지적", out, "사람용 줄(첫 줄 · 꼬리)에도 숨긴 지적이 없다")''', 1),
    (T + "test_synthesize_promoted_findings.sh",
     "grep -qE '^2 finding\\(s\\) dropped as malformed'",
     "grep -qE '^2개 지적을 버렸다 — 형식이 깨졌다\\(dropped as malformed'", 2),
    (T + "test_synthesize_promoted_findings.sh",
     "grep -qE '^1 finding\\(s\\) dropped as malformed'",
     "grep -qE '^1개 지적을 버렸다 — 형식이 깨졌다\\(dropped as malformed'", 1),
]
texts = {}
for rel, old, new, want in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != want:
        sys.exit("STOP %s: 옛 문구가 %d번 있다(기대 %d): %r" % (rel, n, want, old[:90]))
    texts[rel] = t.replace(old, new)
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t2_pins.py .
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_synth_output.sh $Q/test_synthesize_findings.sh $Q/test_synthesize_disposition.sh $Q/test_recritic_bridge.sh $Q/test_angle_coverage.sh $Q/test_synthesize_promoted_findings.sh $Q/test_synthesize_findings_adjudication.py
```

기대(드라이런 실측): `test_plain_synth_output` 34 중 26 RED · `test_synthesize_findings` 7 · `test_synthesize_disposition` 2 · `test_recritic_bridge` 1 · `test_angle_coverage` 2 · `test_synthesize_promoted_findings` 3 · adjudication.py 1.

- [ ] **Step 3: 합성기 · setup 을 고친다**

`counts_line`(`**Findings:** …` 와 ` — N suppressed (conf <= 4)` 꼬리)은 그대로 둔다 — 기계가 읽는다(설계 §3 표). 버린 지적 줄은 쉬운 말이 앞이고 `dropped as malformed` 토큰을 괄호에 남긴다 — SKILL Step 4.5 가 그 토큰을 이름으로 대고 소비한다. setup 의 `gone()` · `refuse()` · 다른 세션 · 예약 폴더 줄은 이미 한국어라 그대로다(R9). 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t2_edit.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 2 — 합성기 · 시작 배너 · setup 오류 줄 (리포 루트를 인자로)."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
SY = "plugins/quality-gates/scripts/synthesize_findings.py"
SE = "plugins/quality-gates/scripts/setup-qg.sh"
E2E = "plugins/quality-gates/tests/e2e-scenarios.md"

STATUS_FN = '''_SEV_KO = (("CRITICAL", "심각"), ("IMPORTANT", "중요"), ("SUGGESTION", "제안"))


def _status_line(counts, suppressed_count, dropped_malformed):
    """사람이 보는 첫 줄 — 스크립트가 계산한 상태 문장. 판정(verdict)과 무관하다:
    판정 없는 출력이 판정 있는 출력의 바이트 접두여야 한다(`--emit-verdict` 꼬리)."""
    total = sum(counts.values())
    if total == 0:
        s = "리뷰를 합쳤다 — 확신 높은 지적 없음."
    else:
        # for 문으로 쓴다 — 이 파일은 처분 회계 소비자라 컴프리헨션 수가 baseline 으로 묶여 있다
        # (`shared/tests/test_adjudication_wiring.sh`). 0 인 등급은 뺀다(설계 §3 원칙 3).
        parts = []
        for k, ko in _SEV_KO:
            if counts[k]:
                parts.append("%s %d" % (ko, counts[k]))
        s = "리뷰를 합쳤다 — 남은 지적 %d개(%s)." % (total, " · ".join(parts))
    if suppressed_count > 0:
        s += " 확신이 낮아 숨긴 지적 %d개." % suppressed_count
    if dropped_malformed > 0:
        s += " 형식이 깨져 버린 지적 %d개." % dropped_malformed
    return s


def render(kept, suppressed_count, dropped_malformed, report, held_classes,'''

EDITS = [
    (SY, "def render(kept, suppressed_count, dropped_malformed, report, held_classes,", STATUS_FN),
    (SY, '''        out = [
            "## Review Findings (Synthesized)",
            "",
            f"No high-confidence findings. {suppressed_count} low-confidence "
            "findings suppressed.",
            disp_line, plumb_line, gloss_line,
        ]''',
     '''        out = [
            _status_line({"CRITICAL": 0, "IMPORTANT": 0, "SUGGESTION": 0}, suppressed_count, dropped_malformed),
            "## 리뷰 지적 (합친 결과)",
            "",
            disp_line, plumb_line, gloss_line,
        ]'''),
    (SY, '''            out.append(
                f"{dropped_malformed} finding(s) dropped as "
                "malformed (not a mapping, wrong container type, or missing "
                "file/severity/summary) — see stderr. "
                "**이 실행은 clean이 아니다**: 버려진 주장은 심사되지 않았다."
            )''',
     '''            out.append(
                f"{dropped_malformed}개 지적을 버렸다 — 형식이 깨졌다(dropped as malformed: 매핑이 아니거나, "
                "담는 형이 틀리거나, file/severity/summary 가 없다) — stderr 참고. "
                "**이 실행은 clean이 아니다**: 버려진 주장은 심사되지 않았다."
            )'''),
    (SY, '''        summary = _cell(f.get("summary", ""))''',
     '''        plain = f.get("plain")
        if isinstance(plain, str) and plain.strip():
            summary = _cell(f"{plain} ({f.get('summary', '')})")
        else:
            summary = _cell(f.get("summary", ""))'''),
    (SY, '''    out = ["## Review Findings (Synthesized)", "", counts_line,
           disp_line, plumb_line, gloss_line, ""]''',
     '''    out = [_status_line(counts, suppressed_count, dropped_malformed), "## 리뷰 지적 (합친 결과)", "", counts_line,
           disp_line, plumb_line, gloss_line, ""]'''),
    (SY, '''    out.append("| Sev | Path:Line | Conf | Summary | Source |")''',
     '''    out.append("| 심각도 | 위치 | 확신 | 내용 | 낸 곳 |")'''),
    (SY, '''    if any_caveat:
        out.append("`*` = confidence <= 6 (treat with caution).")
    if suppressed_count > 0:
        out.append(
            f"{suppressed_count} finding(s) suppressed (conf <= 4); "
            "re-run with `/qg --show-low-confidence` to see all."
        )
    if dropped_malformed > 0:
        out.append(
            f"{dropped_malformed} finding(s) dropped as malformed "
            "(not a mapping, wrong container type, or missing "
            "file/severity/summary) — see stderr."
        )
    out.append("")
    out.append("**Suggested fixes:**")''',
     '''    if any_caveat:
        out.append("`*` = 확신 6 이하 — 조심해서 볼 것.")
    if suppressed_count > 0:
        out.append(f"확신 4 이하 지적 {suppressed_count}개를 숨겼다.")
    if dropped_malformed > 0:
        out.append(
            f"{dropped_malformed}개 지적을 버렸다 — 형식이 깨졌다(dropped as malformed: 매핑이 아니거나, "
            "담는 형이 틀리거나, file/severity/summary 가 없다) — stderr 참고."
        )
    out.append("")
    out.append("**고칠 방법:**")'''),
    (SY, '''        if scope is not None:
            sys.stdout.write(_scope_tuple.render(scope))''',
     '''        if scope is not None and angle_states is not None:
            sys.stdout.write("아래는 이 판정이 본 범위(scope)와 리뷰 각도(angles)의 원문이다.\\n")
        elif scope is not None:
            sys.stdout.write("아래는 이 판정이 본 범위(scope)의 원문이다.\\n")
        elif angle_states is not None:
            sys.stdout.write("아래는 이 판정의 리뷰 각도(angles) 원문이다.\\n")
        if scope is not None:
            sys.stdout.write(_scope_tuple.render(scope))'''),
    # setup-qg.sh
    (SE, 'echo "[quality-gates] setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1" >&2',
         'echo "[quality-gates] DEVBREW_QUALITY_GATES_DISABLE=1 이 켜져 있어 /qg 를 시작하지 않는다(setup-qg disabled)." >&2'),
    (SE, 'echo "❌ Error: --paths requires at least one glob" >&2',
         'echo "❌ --paths 뒤에 glob 이 하나도 없다(--paths requires at least one glob)." >&2'),
    (SE, 'echo "❌ Error: --plan requires a file path argument" >&2',
         'echo "❌ --plan 뒤에 파일 경로가 없다(--plan requires a file path argument)." >&2'),
    (SE, 'echo "❌ Error: --session-id requires an argument" >&2',
         'echo "❌ --session-id 뒤에 값이 없다(--session-id requires an argument)." >&2'),
    (SE, '''      echo "❌ Error: Unknown argument: $1" >&2
      echo "   Use --help for usage information" >&2''',
         '''      echo "❌ 모르는 인자다(Unknown argument): $1" >&2
      echo "   쓰는 법은 --help 로 본다." >&2'''),
    (SE, '''❌ Quality Gates: cannot create pipeline state — session ID is empty.
   Neither --session-id <id> argument nor CLAUDE_CODE_SESSION_ID env var was provided.
   Re-run /qg from Claude Code, or pass --session-id explicitly.''',
         '''❌ Quality Gates: 세션 ID(session ID)가 비어 있어 상태 폴더를 만들 수 없다.
   --session-id <id> 인자도 CLAUDE_CODE_SESSION_ID 환경 변수도 없다.
   Claude Code 안에서 /qg 를 다시 돌리거나 --session-id 를 직접 준다.'''),
    (SE, '''echo "❌ Quality Gates: session ID '$SESSION_ID' fails pattern guard ([A-Za-z0-9_-]{8,})." >&2''',
         '''echo "❌ Quality Gates: 세션 ID '${SESSION_ID}' 가 허용 모양([A-Za-z0-9_-]{8,})이 아니다(fails pattern guard)." >&2'''),
    (SE, '''echo "🔄 Quality Gates Pipeline"
echo ""
echo "Pipeline: scope → differential test → reviewers → re-critique → verdict"
for a in $REMOVED_ARGS; do''',
         '''echo "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다."
for a in $REMOVED_ARGS; do'''),
    (SE, '''if [[ "$PLAN_FILE" != "auto" ]]; then
  echo "Plan file: $PLAN_FILE"
fi
echo ""
echo "Pipeline runs in this turn."''',
         '''if [[ "$PLAN_FILE" != "auto" ]]; then
  echo "계획 파일: ${PLAN_FILE}"
fi'''),
    (E2E, "refuses with one line (`setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1`)",
          "refuses with one line (`[quality-gates] DEVBREW_QUALITY_GATES_DISABLE=1 이 켜져 있어 /qg 를 시작하지 않는다(setup-qg disabled).`)"),
]

texts = {}
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        sys.exit("STOP %s: 옛 문구가 %d번 있다(기대 1): %r" % (rel, n, old[:80]))
    texts[rel] = t.replace(old, new)
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t2_edit.py .
bash -n plugins/quality-gates/scripts/setup-qg.sh && python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' plugins/quality-gates/scripts/synthesize_findings.py && echo "syntax ok"
```

- [ ] **Step 4: 테스트를 돈다**

```bash
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_synth_output.sh $Q/test_synthesize_findings.sh $Q/test_synthesize_disposition.sh $Q/test_recritic_bridge.sh $Q/test_angle_coverage.sh $Q/test_synthesize_promoted_findings.sh $Q/test_synthesize_findings_adjudication.py \
  $Q/test_verdict_vocabulary.sh $Q/test_topic_scope_wiring.sh $Q/test_scope_tuple.sh $Q/test_pipeline_verdict_wiring.sh $Q/test_setup_qg.sh $Q/test_isolation.sh $Q/test_worktree.sh $Q/test_entry_safety_e1_e6.sh $Q/test_skill_drop_notice_consumed.sh $Q/test_qg_false_clean_floor.sh $Q/test_resolution_disclosure.sh $Q/test_guards_coverage_bidirectional.sh $Q/test_runner_adapters.sh \
  shared/tests/test_python_floor.sh shared/tests/test_adjudication_wiring.sh shared/tests/test_adjudication_consumed.sh shared/tests/test_dispatch_disposition.sh
```

기대(드라이런 실측): 스물넷 전부 `rc=0`(34/34 · 19 · 42/42 · 134/134 · 185/185 · 16/16 · OK · 99/99 · 79/79 · 50/50 · 78/78 · 60/60 · 11/11 · 13/13 · 109/109 · 12/12 · 4/4 · 12/12 · 352/352 · 53/53 · 143/143 · 17/17 · 6/6 · 19/19). `test_adjudication_wiring.sh` 의 컴프리헨션 수가 40 그대로인지 본다(R14).

- [ ] **Step 5: 커밋**

```bash
Q=plugins/quality-gates/tests
git add plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/setup-qg.sh $Q/e2e-scenarios.md $Q/test_plain_synth_output.sh \
  $Q/test_angle_coverage.sh $Q/test_recritic_bridge.sh $Q/test_synthesize_disposition.sh $Q/test_synthesize_findings.sh $Q/test_synthesize_findings_adjudication.py $Q/test_synthesize_promoted_findings.sh
git commit -m "feat(qg): 합성기 첫 줄을 상태 문장으로, 배너와 고정 문구를 한국어로

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat HEAD | tail -1
```

기대: `10 files changed`.

- [ ] **Step 6: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py . t2 | tee ~/.claude/sdd-mirror/plain-language-output/pr3/mut-t2.txt
```

기대(드라이런 실측): `cells=18 survived=0`. 셀: 0 인 등급 되살리기 · 첫 줄에 `verdict: clean` · 빈 분기 첫 줄 영어 · 버린 수 빼기 · 숨긴 수 빼기 · 표 머리 영어 · 고칠 방법 머리 영어 · 없는 인자 안내 되살리기 · 버린 지적 줄의 토큰 지우기 · 블록 앞 줄 지우기 · 블록 뒤로 옮기기 · 두 블록 갈래 지우기 · 블록 앞 줄 두 번 · 배너 첫 줄 영어 · 배너에 과정 나열 되살리기 · `--paths` 오류를 영어만으로 · `--paths` 오류 토큰 지우기 · 모르는 인자 오류 토큰 지우기.

---

## Task 3: `plain:` 칸 — 형식 · 넘기기 · 합치기 · 그리기 (§5 · AC9 · D2.8 · Deferred 7)

**Files:**
- Modify(형식): `plugins/quality-gates/agents/security-reviewer.md:87` · `agents/artifact-critic.md:54` · `agents/artifact-adversarial.md:61` · `scripts/build_codex_prompt.py:74` · `scripts/build_artifact_codex_prompt.py:62` · `references/recritic-code-profile.md:10` · `skills/quality-pipeline/SKILL.md:489 뒤 · :518 뒤`(Task 1 은 그 위의 줄 수를 바꾸지 않는다)
- Modify(넘기기): `shared/codex/codex_findings_to_yaml.py:66` · `scripts/synthesize_artifact_findings.py:132-133 · :291-292`
- Modify(합치기): `scripts/synthesize_artifact_findings.py:127-128 뒤` · `scripts/synthesize_findings.py:503 뒤`(dedup) · `:514 앞`(`_has_plain` — dedup **뒤**, R14)
- Modify(그리기): Task 2 에서 끝났다(표의 요약 칸)
- Create: `plugins/quality-gates/tests/test_plain_field_path.sh`

**Interfaces:**
- 칸 이름 `plain`(문자열, 선택). 뜻: 「처음 보는 사람에게 보일 쉬운 한 문장 — 내부 번호 없이」. 없거나 공백뿐이면 없는 것으로 친다.
- `recritic_bridge.py` 는 이미 `added` 의 칸을 통째로 넘긴다(`nf = dict(a)`) — 코드는 고치지 않고 테스트만 더한다. 익명화(`anonymize`)는 재비판자에게 `plain` 을 넘기지 않는다(프레이밍 차단 — 그대로).

- [ ] **Step 1: 실패하는 락을 쓴다**

`plugins/quality-gates/tests/test_plain_field_path.sh`:

````bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/synthesize_artifact_findings.py plugins/quality-gates/scripts/recritic_bridge.py shared/codex/codex_findings_to_yaml.py plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/artifact-critic.md plugins/quality-gates/agents/artifact-adversarial.md plugins/quality-gates/scripts/build_codex_prompt.py plugins/quality-gates/scripts/build_artifact_codex_prompt.py plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/skills/quality-pipeline/SKILL.md
#
# 쉬운 말 출력 설계 §5 · AC9 — 생산자마다 리뷰어 출력 하나가 변환·합성을 지나 화면까지 가고, 거기서 plain 이 먼저 나온다.
# plain 이 없는 지적은 버려지지 않고 지금처럼 나온다.
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
ART="$PLUGIN_ROOT/scripts/synthesize_artifact_findings.py"
B="$PLUGIN_ROOT/scripts/recritic_bridge.py"
CONV="$REPO_ROOT/shared/codex/codex_findings_to_yaml.py"
S="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }

# ① 형식 — 생산자 일곱이 plain 칸을 형식에 싣는다(보안 리뷰어 · artifact-critic · artifact-adversarial ·
#    codex 빌더 둘 · 재비판 프로필 · 추가 리뷰어 dispatch 줄). 「explain」 같은 낱말이 우연히 맞지 않게 칸 모양으로 잰다.
assert_file_grep "$PLUGIN_ROOT/agents/security-reviewer.md" '^  plain: <optional' "AC9 형식: security-reviewer 의 finding 형식에 plain 칸"
assert_file_grep "$PLUGIN_ROOT/agents/artifact-critic.md" '^    plain: "optional' "AC9 형식: artifact-critic 의 finding 형식에 plain 칸"
assert_file_grep "$PLUGIN_ROOT/agents/artifact-adversarial.md" '^    plain: "optional' "AC9 형식: artifact-adversarial 의 new_findings 형식에 plain 칸"
assert_file_grep "$PLUGIN_ROOT/scripts/build_codex_prompt.py" '^      "plain": "<optional' "AC9 형식: codex 코드 리뷰 프롬프트에 plain 칸"
assert_file_grep "$PLUGIN_ROOT/scripts/build_artifact_codex_prompt.py" '^    plain: "optional' "AC9 형식: codex 비코드 리뷰 프롬프트에 plain 칸"
assert_contains "$(flat "$PLUGIN_ROOT/references/recritic-code-profile.md")" '`plain`(선택)에는 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장으로 — 내부 번호 없이 — 쓴다' "AC9 형식(D2.8): 재비판 added 형식에 plain"
assert_contains "$(flat "$S")" '지적마다 `plain:` 칸에 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장으로 더하라(내부 번호 없이). 다른 칸과 찾는 방식은 평소대로다.' "AC9 형식(D2.8): 추가 리뷰어 dispatch 에 붙일 한 줄이 있다"
assert_contains "$(flat "$S")" '**각 항목의 `plain:` 도 리뷰어가 낸 값을 그대로 옮긴다** — 없으면 키를 뺀다(지어내지 않는다).' "R4: 오케스트레이터가 findings.yaml 에 plain 을 옮긴다"
# 생성된 codex 프롬프트에 칸이 실제로 실린다(파일 문면이 아니라 빌더 출력)
assert_contains "$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import build_codex_prompt as b; print(b.PROMPT_TEMPLATE)' "$PLUGIN_ROOT/scripts" 2>/dev/null)" '"plain":' "AC9 형식: codex 코드 리뷰 빌더의 PROMPT_TEMPLATE 이 plain 을 싣는다"

# ② 보안 리뷰어 · 추가 리뷰어 경로 — 오케스트레이터가 쓴 findings.yaml → 합성기 표
printf -- '- agent: security-reviewer\n  file: app.py\n  line: 3\n  severity: CRITICAL\n  confidence: 9\n  summary: "SQL 문자열 결합"\n  plain: "입력값이 그대로 데이터베이스 명령에 들어간다"\n  proposed_fix: "바인딩"\n- agent: code-reviewer\n  file: lib.py\n  line: 7\n  severity: IMPORTANT\n  confidence: 8\n  summary: "예외를 삼킨다"\n  proposed_fix: "다시 던진다"\n' > "$T/f.yaml"
out="$(python3 "$SYNTH" --findings "$T/f.yaml")"
assert_grep "$out" '\| 입력값이 그대로 데이터베이스 명령에 들어간다 \(SQL 문자열 결합\) \|' "AC9: plain 이 먼저, 원래 요약은 뒤 괄호"
assert_grep "$out" '\| 예외를 삼킨다 \|' "AC9(Review Focus 1): plain 없는 지적도 지금처럼 나온다"
assert_grep "$out" '^\*\*Findings:\*\* 1 CRITICAL / 1 IMPORTANT / 0 SUGGESTION$' "AC9: 두 지적 모두 셌다(버린 것 없음)"

# ③ codex 코드 리뷰 경로 — codex JSONL → codex_findings_to_yaml(default) → 합성기
python3 - "$T/codex.jsonl" <<'PY'
import json, sys
text = "```json\n" + json.dumps({"findings": [{"file": "x.py", "line": 2, "severity": "IMPORTANT", "confidence": 8,
        "summary": "경계 검사 누락", "plain": "길이를 확인하지 않아 범위를 넘어 읽는다", "proposed_fix": "검사 추가"}]}, ensure_ascii=False) + "\n```"
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": text}}, ensure_ascii=False) + "\n")
PY
python3 "$CONV" < "$T/codex.jsonl" > "$T/codex.yaml"
assert_file_grep "$T/codex.yaml" '^ *plain: ' "AC9: codex 변환이 plain 을 넘긴다"
python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1],encoding="utf-8")); open(sys.argv[2],"w",encoding="utf-8").write(yaml.safe_dump(d["findings"],allow_unicode=True))' "$T/codex.yaml" "$T/codex-list.yaml"
out="$(python3 "$SYNTH" --findings "$T/codex-list.yaml")"
assert_grep "$out" '\| 길이를 확인하지 않아 범위를 넘어 읽는다 \(경계 검사 누락\) \|' "AC9: codex 지적의 plain 이 화면에 먼저 나온다"

# ④ 재비판자가 더한 지적 — recritic_bridge → 합성기
printf '[]\n' > "$T/empty.yaml"
python3 "$B" prepare --findings "$T/empty.yaml" --out-findings "$T/rf.yaml" --out-map "$T/map.json"
{ printf '재비판을 마쳤습니다.\n\n```docreview-recritic\n'; printf 'verdicts: []\nadded:\n  - file: lib.py\n    line: 4\n    severity: CRITICAL\n    summary: "놓친 경로 탐색"\n    plain: "사용자가 준 경로로 다른 폴더의 파일을 읽을 수 있다"\n    proposed_fix: "정규화 후 비교"\n'; printf '```\n'; } > "$T/reply.txt"
out="$(python3 "$SYNTH" --findings "$T/empty.yaml" --recritic "$T/reply.txt" --recritic-map "$T/map.json")"
assert_grep "$out" '\| 사용자가 준 경로로 다른 폴더의 파일을 읽을 수 있다 \(놓친 경로 탐색\) \|' "AC9(D2.8): 재비판 added 의 plain 이 화면에 먼저 나온다"

# ⑤ 비코드 산출물 경로 — key → synth 의 kept 에 plain 이 남는다
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s1", severity: CRITICAL, summary: "gap A", plain: "이 절은 앞 절과 반대로 말한다", proposed_fix: "fix A"}\n' > "$T/critic.yaml"
python3 "$ART" --phase key --findings "$T/critic.yaml" > "$T/merged.yaml"
assert_file_grep "$T/merged.yaml" '^ *plain: ' "AC9: artifact key 단계가 plain 을 넘긴다"
K="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"][0]["dedup_key"])' "$T/merged.yaml")"
printf 'verdicts:\n  - {finding_key: "%s", verdict: confirm, evidence: real}\n' "$K" > "$T/adv.yaml"
out="$(python3 "$ART" --phase synth --findings "$T/merged.yaml" --adversarial "$T/adv.yaml")"
assert_contains "$out" "이 절은 앞 절과 반대로 말한다" "AC9: artifact synth 의 kept 에 plain 이 남는다"

# ⑥ 표 칸을 깨는 글자 (Review Focus 2)
printf -- '- agent: security-reviewer\n  file: a.py\n  line: 1\n  severity: IMPORTANT\n  confidence: 8\n  summary: "s"\n  plain: "왼쪽 | 오른쪽\\n둘째 줄"\n  proposed_fix: "p"\n' > "$T/esc.yaml"
out="$(python3 "$SYNTH" --findings "$T/esc.yaml")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^| IMPORTANT |')" "1" "Review Focus 2: plain 의 | 와 개행이 표 행을 깨지 않는다"
assert_grep "$out" '왼쪽 \\\| 오른쪽 둘째 줄 \(s\)' "Review Focus 2: | 는 이스케이프되고 개행은 공백이 된다"

# ⑦ 합칠 때 칸이 사라지지 않는다 (Review Focus 5) — 코드 경로 · 비코드 경로
printf -- '- agent: security-reviewer\n  file: d.py\n  line: 5\n  severity: IMPORTANT\n  confidence: 9\n  summary: "같은 지적"\n  proposed_fix: "p"\n- agent: code-reviewer\n  file: d.py\n  line: 5\n  severity: IMPORTANT\n  confidence: 7\n  summary: "같은 지적"\n  plain: "같은 줄을 두 리뷰어가 짚었다"\n  proposed_fix: "p"\n' > "$T/dup.yaml"
out="$(python3 "$SYNTH" --findings "$T/dup.yaml")"
assert_contains "$out" "같은 줄을 두 리뷰어가 짚었다" "Review Focus 5: 신뢰도 높은 쪽에 plain 이 없으면 합쳐진 다른 쪽의 plain 을 물려받는다"
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s2", severity: IMPORTANT, summary: "gap B", proposed_fix: "fix B"}\n' > "$T/c1.yaml"
printf 'findings:\n  - {agent: codex, category: logic, target_anchor: "#s2", severity: IMPORTANT, summary: "gap B", plain: "둘째 절이 빠졌다", proposed_fix: "fix B"}\n' > "$T/c2.yaml"
python3 "$ART" --phase key --findings "$T/c1.yaml" --findings "$T/c2.yaml" > "$T/m2.yaml"
assert_eq "$(grep -c '^ *plain: ' "$T/m2.yaml")" "1" "Review Focus 5: 비코드 합치기도 다른 쪽의 plain 을 물려받는다"
finish
````

```bash
chmod +x plugins/quality-gates/tests/test_plain_field_path.sh
```

(③ 의 `python3 - … <<'PY'` 는 `$( )` 밖이라 heredoc 파싱 함정이 없다. `yaml` 은 이 플러그인 테스트가 이미 쓴다. ① 의 형식 단언은 칸 모양(`^  plain: <optional` 등)으로 잰다 — 맨 낱말 `plain` 은 「explain」에도 맞는다.)

```bash
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh plugins/quality-gates/tests/test_plain_field_path.sh
```

기대(드라이런 실측): 21 중 15 RED(GREEN 여섯은 칸 없는 지적 · 두 지적 셈 · 행 수 · 칸 없는 합치기의 뒤쪽 셈처럼 바뀌기 전에도 참인 것).

- [ ] **Step 2: 형식 일곱 · 넘기는 곳 셋 · 합치기 둘**

찾는 지시는 한 글자도 바꾸지 않는다 — 형식 칸 한 줄을 `summary` 바로 뒤에 더할 뿐이다. `codex_findings_to_yaml.py` 의 `DEFAULT_KEYS` 는 끝에 더하므로 칸이 없는 입력의 출력 바이트는 그대로다 — `yaml_emit`(107-125)은 `if k in f:` 로 있는 키만 쓴다(`plugins/spec-distill/tests/test_codex_findings_to_yaml.py` 의 바이트 고정 GREEN). 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t3_edit.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 3 — plain 칸: 형식 일곱 · 넘기는 곳 셋 · 합치기 둘 (리포 루트를 인자로).
찾는 지시는 한 글자도 바꾸지 않는다 — 형식 칸 한 줄을 summary 바로 뒤에 더할 뿐이다."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
Q = "plugins/quality-gates/"
EDITS = [
    # 형식 — agent 정의 셋(보안 민감: 칸만 더한다 · tools: 불변)
    (Q + "agents/security-reviewer.md",
     "  summary: <one-sentence describing the vulnerability and its path>\n",
     "  summary: <one-sentence describing the vulnerability and its path>\n"
     "  plain: <optional — the same finding in one plain sentence a first-time reader understands, no internal IDs>\n"),
    (Q + "agents/artifact-critic.md",
     '    summary: "one sentence"\n',
     '    summary: "one sentence"\n'
     '    plain: "optional — the same finding in one plain sentence for a first-time reader, no internal IDs"\n'),
    (Q + "agents/artifact-adversarial.md",
     '    summary: "..."\n',
     '    summary: "..."\n'
     '    plain: "optional — one plain sentence for a first-time reader, no internal IDs"\n'),
    # 형식 — codex 프롬프트 빌더 둘
    (Q + "scripts/build_codex_prompt.py",
     '      "summary": "<one sentence>",\n',
     '      "summary": "<one sentence>",\n'
     '      "plain": "<optional: the same finding in one plain sentence a first-time reader understands, no internal IDs>",\n'),
    (Q + "scripts/build_artifact_codex_prompt.py",
     '    summary: "one sentence"\n',
     '    summary: "one sentence"\n'
     '    plain: "optional — the same finding in one plain sentence for a first-time reader, no internal IDs"\n'),
    # 형식 — 재비판 코드 프로필(added)
    (Q + "references/recritic-code-profile.md",
     "- `added` 항목은 `file` · `line` · `severity` · `summary` · `proposed_fix` 를 싣는다. `file` 은 리포 상대 경로다.",
     "- `added` 항목은 `file` · `line` · `severity` · `summary` · `proposed_fix` 를 싣는다. `file` 은 리포 상대 경로다. "
     "`plain`(선택)에는 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장으로 — 내부 번호 없이 — 쓴다."),
    # 형식 — 추가 리뷰어 dispatch 에 붙일 한 줄(R3) · 오케스트레이터가 옮겨 적기(R4)
    (Q + "skills/quality-pipeline/SKILL.md",
     "   `model:` override into their dispatch (upstream model pinning is respected).\n",
     "   `model:` override into their dispatch (upstream model pinning is respected).\n"
     "   추가 리뷰어 dispatch 프롬프트의 끝에 이 한 줄을 그대로 붙인다: 「지적마다 `plain:` 칸에 같은 지적을 처음 보는 "
     "사람이 읽을 쉬운 한 문장으로 더하라(내부 번호 없이). 다른 칸과 찾는 방식은 평소대로다.」 리뷰어가 칸을 채우지 "
     "않으면 지금처럼 진행한다.\n"),
    (Q + "skills/quality-pipeline/SKILL.md",
     "(합성기가 5 로 채운다).\n",
     "(합성기가 5 로 채운다).\n"
     "      **각 항목의 `plain:` 도 리뷰어가 낸 값을 그대로 옮긴다** — 없으면 키를 뺀다(지어내지 않는다).\n"),
    # 넘기는 곳 — 공유 codex 변환기(끝에 더한다: 칸 없는 입력의 출력 바이트 불변)
    ("shared/codex/codex_findings_to_yaml.py",
     'DEFAULT_KEYS = ("file", "line", "severity", "confidence", "summary", "proposed_fix")',
     'DEFAULT_KEYS = ("file", "line", "severity", "confidence", "summary", "proposed_fix", "plain")'),
    # 넘기는 곳 — 비코드 합성기 허용 목록 둘 + 합치기
    (Q + "scripts/synthesize_artifact_findings.py",
     '              "severity", "summary", "proposed_fix", "dedup_key", "stagnation_key")',
     '              "severity", "summary", "plain", "proposed_fix", "dedup_key", "stagnation_key")'),
    (Q + "scripts/synthesize_artifact_findings.py",
     '                                   "severity", "summary", "proposed_fix", "dedup_key")',
     '                                   "severity", "summary", "plain", "proposed_fix", "dedup_key")'),
    (Q + "scripts/synthesize_artifact_findings.py",
     '                    by_key[k]["severity"] = g["severity"]\n',
     '                    by_key[k]["severity"] = g["severity"]\n'
     '                # 남는 쪽에 plain 이 없고 새로 온 쪽에 있으면 물려받는다(칸이 합치기에서 사라지지 않게).\n'
     '                if not by_key[k].get("plain") and g.get("plain"):\n'
     '                    by_key[k]["plain"] = g["plain"]\n'),
    # 합치기 — 코드 합성기 dedup(신뢰도 높은 쪽이 남는다 — 그쪽에 칸이 없으면 다른 쪽의 칸을 물려받는다)
    (Q + "scripts/synthesize_findings.py",
     '        merged = dict(group[0])\n',
     '        merged = dict(group[0])\n'
     '        # 남는 쪽(신뢰도 높은 쪽)에 plain 이 없으면 합쳐진 다른 쪽 중 신뢰도가 가장 높은 쪽의 plain 을\n'
     '        # 물려받는다. 뒤에서부터 덮어쓰므로 break 가 없다 — 이 파일은 처분 회계 소비자라 컴프리헨션 ·\n'
     '        # 버리는 분기(break/continue)가 `shared/tests/test_adjudication_wiring.sh` 에 묶여 있다.\n'
     '        if not _has_plain(merged):\n'
     '            for g in reversed(group[1:]):\n'
     '                if _has_plain(g):\n'
     '                    merged["plain"] = g["plain"]\n'),
    # dedup 보다 «뒤»에 둔다 — tools/adjudication/check_wiring.py 의 EXEMPT 가 dedup 안의 분기를 줄 번호(497)로 가리킨다.
    (Q + "scripts/synthesize_findings.py",
     'def suppress(findings, ledger=None):\n',
     'def _has_plain(f):\n'
     '    """리뷰어가 쓴 쉬운 한 문장(`plain`)이 있는가 — 문자열이고 공백뿐이 아니어야 있다."""\n'
     '    return isinstance(f.get("plain"), str) and bool(f["plain"].strip())\n'
     '\n'
     '\n'
     'def suppress(findings, ledger=None):\n'),
]
texts = {}
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        sys.exit("STOP %s: 옛 문구가 %d번 있다(기대 1): %r" % (rel, n, old[:90]))
    texts[rel] = t.replace(old, new)
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t3_edit.py .
for f in plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/synthesize_artifact_findings.py plugins/quality-gates/scripts/build_codex_prompt.py plugins/quality-gates/scripts/build_artifact_codex_prompt.py shared/codex/codex_findings_to_yaml.py; do
  python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$f" || echo "SYNTAX $f"
done
```

- [ ] **Step 3: 테스트를 돈다(AC9)**

```bash
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_field_path.sh $Q/test_synthesize_findings.sh $Q/test_synthesize_artifact_findings.sh $Q/test_synthesize_artifact_adjudication.py $Q/test_synthesize_findings_adjudication.py $Q/test_recritic_bridge.sh $Q/test_recritic_code_profile.sh \
  $Q/test_build_codex_prompt.sh $Q/test_artifact_codex_reviewer.sh $Q/test_codex_copies_agree.sh $Q/test_codex_prompt_untrusted_clause.sh $Q/test_codex_result_banner.sh $Q/test_codex_invocation_contract.sh $Q/test_codex_extractor_positive_marker.sh \
  $Q/test_security_reviewer_kill_switch.sh $Q/test_security_reviewer_persona.sh $Q/test_security_reviewer_behavior.py $Q/test_agent_tools_lock_mutation.sh $Q/test_agent_tools_lock_differential.sh $Q/test_artifact_critic_frontmatter.sh $Q/test_artifact_adversarial_frontmatter.sh $Q/test_agent_frontmatter_keys.sh \
  $Q/test_review_scope_composition.sh $Q/test_skill_orchestration.sh $Q/test_plain_qg_templates.sh $Q/test_plain_synth_output.sh $Q/test_guards_coverage_bidirectional.sh $Q/test_runner_adapters.sh \
  plugins/spec-distill/tests/test_codex_findings_to_yaml.py shared/tests/test_adjudication_wiring.sh shared/tests/test_agent_input_slots.sh shared/tests/test_invocation_surface.sh shared/tests/test_plain_language_block.sh shared/tests/test_docreview_codex.sh shared/tests/test_python_floor.sh
git diff HEAD -- plugins/quality-gates/agents | grep '^[-+]tools' || echo "tools 불변"
```

기대(드라이런 실측): 서른다섯 전부 `rc=0`(21/21 · … · 364/364 · 53/53 · OK · 17/17 · 14/14 · 69/69 · 14/14 · 280/280 · 143/143), 마지막 줄 `tools 불변`.

- [ ] **Step 4: 커밋**

```bash
git add plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/artifact-critic.md plugins/quality-gates/agents/artifact-adversarial.md plugins/quality-gates/scripts/build_codex_prompt.py plugins/quality-gates/scripts/build_artifact_codex_prompt.py plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/skills/quality-pipeline/SKILL.md shared/codex/codex_findings_to_yaml.py plugins/quality-gates/scripts/synthesize_artifact_findings.py plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/tests/test_plain_field_path.sh
git commit -m "feat(qg): 리뷰어 지적마다 사람이 읽을 한 문장(plain) 칸, 화면에 먼저

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat HEAD | tail -1
```

기대: `11 files changed`.

- [ ] **Step 5: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py . t3 | tee ~/.claude/sdd-mirror/plain-language-output/pr3/mut-t3.txt
```

기대(드라이런 실측): `cells=13 survived=0` — 설계 AC9 의 변이 셋(렌더가 칸 없는 지적을 건너뛰기 · 비코드 허용 목록에서 `plain` 빼기 · 변환기가 `plain` 을 버리기)과 새 규칙 문장마다 한 셀(추가 리뷰어 한 줄의 「평소대로」 뒤집기 · 옮겨 적기 문장 지우기 · 「지어내지 않는다」 뒤집기 · 재비판 프로필의 「내부 번호 없이」 지우기 등).

---

## Task 4: README · 소개 문구 · 버전 (§8 · AC10)

**Files:**
- Modify: `plugins/quality-gates/README.md:3`(첫 문단) · `:262`(「파이프라인 흐름」 첫 문단) · `:367-376`(`## 사용` → `## 쓰는 법`)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`(description · version) · `.claude-plugin/marketplace.json`(quality-gates 항목) · `shared/tests/test_charter_citations.sh:31-33`(`QG_DESC`)
- Modify: `plugins/quality-gates/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`(version) · `plugins/spec-distill/CHANGELOG.md`
- Create: `plugins/quality-gates/tests/test_plain_readme.sh`

- [ ] **Step 1: README 를 어디까지 다시 쓰는지**

310ce78f 의 README 는 이미 한국어 중심이다(529줄). 다시 쓰는 것은 R13 의 넷뿐이다 — 첫 문단(무엇을 해 주는지 세 문장) · `## 쓰는 법` 표(「이럴 때 — 친다 — 나오는 것」, 진입 명령 여섯) · 「파이프라인 흐름」 첫 문단 · 상태도 표지(Task 1 에서 끝). 지워지면 안 되는 것(310ce78f 의 README 락 전수 — `grep -rln 'README' plugins/*/tests shared/tests tools` 에서 qg README 를 읽는 것):

- `test_readme_state_diagram_complete.sh`: `single assistant turn` 정확히 1번 · `setup-qg.sh` · `SKILL preflight` · `trivia escape` · `qg iter loop` · `② differential test` · `⑤ synthesize → verdict` · `AskUserQuestion` · `남은 지적이 있다` · `최종 요약`. 없어야 하는 것: `stateDiagram-v2` · `Runtime gate dispatch` · `Review gate iter loop` · `gate scope?` · `NEEDS_RESOLUTION`.
- `test_readme_scope_reconcile.sh`: `Phase 1 병렬 ≤ 8` · `총/iteration ≤ 10` · `transparency` · `리뷰어 구성 — 각도 셋 + 추가 리뷰어` · `보안 각도 — 매 iteration (모델이 못 뺌)` · `다른 전제 각도 — detect_codex 참이면` · `Prerequisites (추가 리뷰어 optional dependencies)` · `` pr-review-toolkit`(code-reviewer `` · `` feature-dev`(code-architect) `` · `every non-trivia pipeline dispatch when detected`. 없어야 하는 것: `len(phase1)` · `= 12` · `subagent fan-out gate` · `gates subagent fan-out` · 옛 codex-depth 문구 둘.
- `test_qg_publish_docs.sh:26-47`: `### Kill switches` 머리글로 자른 절에 `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` · `deterministic envelope|model-authored|모델 저술` · `/qg-publish` · `파이프라인의 일부가 아니다`. 없어야 하는 것: `command-layer opt-in offer`.
- `test_impact_runtime_docs.sh:53-67`: `## 구조` 머리글로 자른 트리에 새 스크립트 다섯 · `## 인스턴스화한 원칙` 머리글로 자른 절에 `LD3` · `LD5` · `LD7`.
- `test_artifact_metadata.sh:14-15`: `critique` · `artifact-critic|critiquing-artifacts`.
- `shared/tests/test_python_floor.sh:876-883`: qg README 에 `Python 3.<바닥>+` prerequisite 를 쓰지 않는다(훅이 없어 집행 주체가 없다) — `## 사전 요건` 의 「Python 3」 줄은 그대로.
- `test_law2_prose.sh`(모든 `plugins/*/README.md` 의 금지 표현) · `shared/tests/test_dispatch_name_defined.sh` · `tools/adjudication/check_names.py`(README 의 kill switch · dispatch 이름 참조).
- CLAUDE.md 가 요구하는 절: `## 인스턴스화한 원칙`(Principles Instantiated) · `## 설치된 Hook`(Hooks Installed — 「없음」 문단) · `## 사전 요건`(prerequisites). 머리글과 문면 그대로.

- [ ] **Step 2: 실패하는 락을 쓴다**

`plugins/quality-gates/tests/test_plain_readme.sh`:

````bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/README.md
#
# 쉬운 말 출력 설계 §8 — README 첫 문단이 「무엇을 해 주는가」를 쉬운 말로 말하고, `## 쓰는 법` 이
# 「이럴 때 — 친다 — 나오는 것」 표로 진입 명령을 모두 싣는다. 부재 단언마다 양성 짝이 있다.
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
RM="$PLUGIN_ROOT/README.md"
lead="$(awk 'NR>1 && /^## /{exit} NR>1' "$RM" | tr '\n' ' ')"
assert_contains "$lead" "바뀐 코드를 내보내기 전에 확인한다." "§8: 첫 문단이 무엇을 해 주는지로 시작한다"
assert_contains "$lead" "사용자가 미리보기를 승인한 뒤에만 올린다" "§8: 첫 문단이 게시는 승인 뒤라고 말한다"
use="$(awk '/^## 쓰는 법$/{f=1;next} f&&/^## /{exit} f' "$RM")"
assert_grep "$use" '^\| 이럴 때 \| 친다 \| 나오는 것 \|$' "§8: 쓰는 법이 「이럴 때 · 친다 · 나오는 것」 표다"
for c in '`/qg`' '`/qg branch`' '`/qg --paths <glob>...`' '`/qg --plan <path>`' '`/qg critique <path>`' '`/qg-publish`'; do
  assert_contains "$use" "| ${c} |" "§8: 쓰는 법 표에 ${c} 행이 있다"
done
assert_file_absent "$RM" '^## 사용$' "§8: 옛 「사용」 절이 없다(쓰는 법이 대신한다)"
finish
````

```bash
chmod +x plugins/quality-gates/tests/test_plain_readme.sh
```

```bash
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh plugins/quality-gates/tests/test_plain_readme.sh
```

기대(드라이런 실측): 10 중 10 RED.

- [ ] **Step 3: README · 소개 문구 · 버전 · CHANGELOG**

버전 두 개는 머지 직전에 정한다(Global Constraints 「버전」). 310ce78f 에서 정하면 `10.1.0` · `5.1.1` 이다. 스크립트는 옛 버전 문자열(`"version": "10.0.3"` · `"version": "5.1.0"`)과 두 CHANGELOG 의 맨 위 머리를 단언한다 — main 이 그 사이 움직였으면 `STOP` 이다. 그때는 번호를 다시 정하고 스크립트의 옛 문자열을 그 트리의 값으로 고친다. 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t4_edit.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 4 — README · 소개 문구 · 버전 · CHANGELOG (리포 루트, 새 qg 버전, 새 spec-distill 버전, 날짜를 인자로).
   pr3_t4_edit.py <리포 루트> <qg 버전> <spec-distill 버전> <YYYY-MM-DD>"""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
QV, SV, DAY = sys.argv[2], sys.argv[3], sys.argv[4]
Q = "plugins/quality-gates/"
OLD_DESC = ("Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test) "
            "with multi-plugin review delegation, plus a separate consent-gated PR-understanding generate/publish "
            "surface (not a gate). Invoke manually via /qg or /qg-publish.")
NEW_DESC = ("Checks a change before you ship it: one /qg run reviews the diff from several independent angles, "
            "runs the tests whose behavior changed, and gives one verdict. /qg-publish separately posts a "
            "plain-language PR summary, only after you approve it.")

USAGE_OLD = '''## 사용

```
/qg                            # 파이프라인 실행; 세션 단위 diff(선언이 있으면 토픽)
/qg branch                     # 파이프라인 실행; main 대비 풀 브랜치 diff
/qg --paths <glob>...          # 명시 path scope
/qg both|review|runtime|--skip-runtime   # 제거됨 — 한 줄 공지 후 그대로 진행 (한 파이프라인이라 게이트 범위가 없다)
/qg --plan <path>              # 특정 plan 파일 사용
/qg critique <path>            # 비-코드 산출물 비평-수정 루프(별도 skill; 코드 아님)
```
'''
USAGE_NEW = '''## 쓰는 법

| 이럴 때 | 친다 | 나오는 것 |
|---|---|---|
| 지금 바꾼 것을 내보내기 전에 | `/qg` | 판정 하나와 남은 지적 표. 지적이 남으면 고칠지 묻는다(최대 5번) |
| 브랜치 전체를 보고 싶을 때 | `/qg branch` | main 대비 브랜치 전체 diff 의 판정 |
| 일부 경로만 볼 때 | `/qg --paths <glob>...` | 그 경로만 리뷰한 판정 |
| 특정 계획 파일로 테스트를 고르게 할 때 | `/qg --plan <path>` | 그 계획을 차등 테스트 분류 기준으로 쓴 판정 |
| 문서 · 설계 · 설정을 비평받을 때 | `/qg critique <path>` | 비평 · 수정 라운드(라운드마다 커밋). 코드는 `/qg` 로 본다 |
| 판정 뒤 PR 에 설명을 올릴 때 | `/qg-publish` | 미리보기 → 승인 → 게시. 파이프라인의 일부가 아니다 |

`both` · `review` · `runtime` · `--skip-runtime` 은 제거됐다 — 한 줄 공지 후 그대로 진행한다(한 파이프라인이라 게이트 범위가 없다).
'''

EDITS = [
    (Q + "README.md",
     "Claude Code용 품질 검증 파이프라인 — 한 파이프라인, 한 판정(`clean` · `defect` · `not-certified (<사유>)`). 기준선 대비 차등 테스트는 매 실행 돈다.",
     "바뀐 코드를 내보내기 전에 확인한다. `/qg` 한 번이 diff 를 여러 독립 각도에서 리뷰하고, 동작이 바뀐 테스트를 "
     "기준선과 지금 트리 양쪽에서 돌려, 판정 하나(`clean` · `defect` · `not-certified (<사유>)`)를 낸다. PR 설명 게시"
     "(`/qg-publish`)는 따로이고, 사용자가 미리보기를 승인한 뒤에만 올린다."),
    (Q + "README.md", USAGE_OLD, USAGE_NEW),
    (Q + "README.md",
     "`quality-pipeline` SKILL이 전체 파이프라인을 단일 assistant turn 내에서 serial dispatch로 실행합니다. fix-loop iteration은 AskUserQuestion으로 사용자 동의를 받아 진행합니다 — 이 도구는 progression/consent를 담당하며, subagent fan-out은 게이트하지 않습니다(fan-out은 transparency + 선언된 max fan-out으로 bound).",
     "파이프라인은 한 턴 안에서 끝까지 돈다(`quality-pipeline` SKILL 이 리뷰어를 차례로 부른다). 지적이 남으면 반복마다 "
     "`AskUserQuestion` 으로 고칠지 묻는다 — 이 질문은 진행만 정하고 리뷰어 수를 막지 않는다. 리뷰어 수는 위 "
     "「Fan-out」 의 선언된 상한이 묶는다."),
    (Q + ".claude-plugin/plugin.json", '"description": "%s",' % OLD_DESC, '"description": "%s",' % NEW_DESC),
    (Q + ".claude-plugin/plugin.json", '"version": "10.0.3",', '"version": "%s",' % QV),
    (".claude-plugin/marketplace.json", '"description": "%s"' % OLD_DESC, '"description": "%s"' % NEW_DESC),
    ("shared/tests/test_charter_citations.sh",
     '''QG_DESC = ("Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test) "
           "with multi-plugin review delegation, plus a separate consent-gated PR-understanding generate/publish "
           "surface (not a gate). Invoke manually via /qg or /qg-publish.")''',
     '''QG_DESC = ("Checks a change before you ship it: one /qg run reviews the diff from several independent angles, "
           "runs the tests whose behavior changed, and gives one verdict. /qg-publish separately posts a "
           "plain-language PR summary, only after you approve it.")'''),
    ("plugins/spec-distill/.claude-plugin/plugin.json", '"version": "5.1.0",', '"version": "%s",' % SV),
    (Q + "CHANGELOG.md", "\n## [10.0.3] — 2026-10-09\n",
     '''
## [%s] — %s

### Changed
- /qg 의 질문 셋(반복 · 수정 실패 · 최대 반복)과 선택지, 완료 표가 한국어 쉬운 말이다. 반복 경계 앵커는 「남은 지적이 있다」다. 완료 보고는 판정과 결과 한 문장으로 시작해 할 일 하나로 끝난다. 비평 모드의 최종 보고도 같다.
- 합성기 출력의 첫 줄이 스크립트가 계산한 상태 문장이다(예: 「리뷰를 합쳤다 — 남은 지적 2개(심각 1 · 중요 1).」 — 0 인 등급은 빼고, 숨긴 지적 · 버린 지적이 있으면 그 수를 붙인다). 표 머리와 꼬리 문구도 한국어다. 판정 줄 `verdict:` 과 `**Findings:**` 줄, `dropped as malformed` 토큰은 형태 그대로다. 판정 꼬리의 `scope:` · `angles:` 블록 앞에 그것을 가리키는 쉬운 한 줄이 선다.
- 시작 배너가 과정 나열 없이 한 줄로 시작한다. setup 의 오류 줄이 쉬운 말로 시작하고 원래 영어 토큰은 괄호에 남는다.
- 범위 줄(「리뷰 범위: …」) · trivia 줄 · 범위 경고가 쉬운 말이다(`scope check degraded` 토큰은 괄호에 남는다).

### Added
- 리뷰어 지적의 `plain:` 칸 — 처음 보는 사람이 읽을 쉬운 한 문장. 보안 리뷰어 · artifact-critic · artifact-adversarial · codex 리뷰어 둘 · 코드 재비판자의 새 지적 · 추가 리뷰어 dispatch 에 형식이 있고, 합성기 표가 그것을 요약 앞에 쓴다. 칸이 없으면 지금처럼 나오고, 같은 지적을 합칠 때 칸은 사라지지 않는다.

### Removed
- 합성기 꼬리의 「`/qg --show-low-confidence` 로 다시 돌린다」 안내 — 그런 인자가 없다(setup 이 모르는 인자로 거부한다).

## [10.0.3] — 2026-10-09
''' % (QV, DAY)),
    ("plugins/spec-distill/CHANGELOG.md", "# Changelog\n\n## [5.1.0] — 2026-10-09\n",
     '''# Changelog

## [%s] — %s

### Changed
- 공유 codex 출력 변환기(`codex_findings_to_yaml.py` — 이 플러그인에 링크로 실린다)가 기본 칸 묶음에 `plain` 을 더했다(quality-gates 의 리뷰어 칸). spec-distill 이 쓰는 칸 묶음(design · docreview)의 출력은 그대로다.

## [5.1.0] — 2026-10-09
''' % (SV, DAY)),
]
texts = {}
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        sys.exit("STOP %s: 옛 문구가 %d번 있다(기대 1): %r" % (rel, n, old[:90]))
    texts[rel] = t.replace(old, new)
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t4_edit.py . 10.1.0 5.1.1 "$(date +%Y-%m-%d)"
python3 -c 'import json,sys; [json.load(open(p,encoding="utf-8")) for p in sys.argv[1:]]' plugins/quality-gates/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-distill/.claude-plugin/plugin.json && echo "json ok"
python3 -c 'import json; a=json.load(open("plugins/quality-gates/.claude-plugin/plugin.json",encoding="utf-8"))["description"]; b=[p for p in json.load(open(".claude-plugin/marketplace.json",encoding="utf-8"))["plugins"] if p["name"]=="quality-gates"][0]["description"]; print("same" if a==b else "DIFF")'
```

기대: `json ok` · `same`(AC10 — 소개 문구 불일치 0).

- [ ] **Step 4: 테스트를 돈다**

```bash
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_readme.sh $Q/test_readme_state_diagram_complete.sh $Q/test_readme_scope_reconcile.sh $Q/test_qg_publish_docs.sh $Q/test_impact_runtime_docs.sh $Q/test_artifact_metadata.sh $Q/test_law2_prose.sh $Q/test_guards_coverage_bidirectional.sh $Q/test_runner_adapters.sh \
  shared/tests/test_charter_citations.sh shared/tests/test_changelog_integrity.sh shared/tests/test_python_floor.sh shared/tests/test_dispatch_name_defined.sh shared/tests/test_invocation_surface.sh shared/tests/test_copy_of_contract.sh plugins/plugin-audit/tests/test_check_staleness.py
```

기대(드라이런 실측): 열여섯 전부 `rc=0`(10/10 · 9 markers · 17 · 11/11 · 6/6 · 6/6 · 41/41 · 366/366 · 53/53 · 12/12 · 27/27 · 143/143 · 6/6 · 69/69 · 212/212 · OK).

- [ ] **Step 5: 커밋 · 변이**

```bash
git add plugins/quality-gates/README.md plugins/quality-gates/.claude-plugin/plugin.json .claude-plugin/marketplace.json shared/tests/test_charter_citations.sh plugins/quality-gates/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/quality-gates/tests/test_plain_readme.sh
git commit -m "docs(qg): README 와 소개 문구를 쉬운 말로, 버전 올림

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat HEAD | tail -1
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py . t4 | tee ~/.claude/sdd-mirror/plain-language-output/pr3/mut-t4.txt
```

기대: `8 files changed` · `cells=4 survived=0`(AC10 의 변이 「한 쪽 글자 하나 바꾸기 → RED」를 두 JSON 에서 하나씩).

- [ ] **Step 6: 최종 스위트 · 대조**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr3/after
B=~/.claude/sdd-mirror/plain-language-output/pr3
sed -E 's/\(lines [0-9]+, [0-9]+ distance [0-9]+ > 160\)/(lines N)/' "$B/baseline/failures.txt" | sort > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-baseline.txt
sed -E 's/\(lines [0-9]+, [0-9]+ distance [0-9]+ > 160\)/(lines N)/' "$B/after/failures.txt" | sort > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-after.txt
comm -13 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-baseline.txt /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-after.txt
comm -23 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-baseline.txt /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-after.txt
```

기대: 두 `comm` 모두 빈 출력(after 는 baseline 보다 네 파일 많다 — 새 락 넷). `test_codex_backward_compat.sh :: rc=1` 이 한쪽에만 있으면 단독으로 다시 돌려 4/4 인지 본다(흔들리는 안쪽 `test_codex_runner_degrade_contract.sh`). 그 밖의 줄이 나오면 새 실패다 — 고친다.

- [ ] **Step 7: /qg · PR**

`/qg branch` 를 돌리고 묻는다: 「`verdict:` 줄이 여전히 하나이고 쉬운 줄과 섞이지 않는가 · `plain:` 이 없는 지적이 버려지는 길이 없는가 · 리뷰어 지시의 찾는 규칙이 한 글자도 바뀌지 않았는가(persona = 보안 민감)」.

PR 본문(한국어): 첫 줄 한 문장 · 「계획이 정한 것」 R1~R14(R6 폐기 · R9 옮겨 간 표면 · 확인 받은 R10~R13 의 답) · 문구 고정 테스트 표(Task 1 Step 2, Task 2 Step 2 — 옛 → 새 · 지키는 뜻) · `plain:` 경로 표(형식 · 넘기기 · 합치기 · 그리기 자리) · 변이 결과(`mut-t1..t4.txt` — 52셀) · 「qg v10 계획과의 충돌」 표 · 할 일 하나: 「작은 변경 하나에 `/qg` 를 돌려, 첫 줄이 상태 문장이고 질문이 한국어인지 봐 주세요」. 맨 끝 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

머지는 사용자가 `! gh pr merge <n> --merge`. 머지 뒤 main 을 받고 PR 4 계획으로 간다.
