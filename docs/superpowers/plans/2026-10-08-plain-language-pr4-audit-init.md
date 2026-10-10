# 쉬운 말 출력 PR 4 — plugin-audit · project-init Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** plugin-audit 보고서 · 종료 보고 · 둘레 문구와 project-init 훅 경고 · 초기화 보고가 쉬운 말이 되고, 보고서 둘째 줄이 스크립트가 센 상태 문장이 된다. 감사자 지적에 `plain:` 칸이 생겨 보고서 발견 머리에 먼저 보인다. 네 플러그인의 `plugin.json` 과 마켓플레이스 소개 문구가 글자까지 같다는 것을 새 락이 잰다. 착수 전 기준선과 비교해 새 실패는 0 이어야 한다.

**Architecture:** 보고서의 앞 20줄 경고 표지(`⚠` · `degraded`)와 훅의 정규식 · 모델 채널(additionalContext)은 형태가 그대로다. 사람이 보는 줄만 바꾼다. 「판단에 필요한 0」(좌 · 우 근거의 빈 쪽 · 발견 0건 배너)은 지우지 않고 쉬운 문장으로 낸다. 감사자 `plain:` 은 Workflow 출력 스키마(`AXIS_SCHEMA`)의 선택 속성과 codex 프롬프트(`codex-prompt-preamble.md`)의 선택 칸으로 생기고, 넘기는 쪽(Workflow 병합 · `codex_audit_to_json.py` · `assemble-audit-data.py`)은 이미 항목을 통째로 넘기므로 그리는 쪽(`render-audit-report.py`)만 고친다 — 넘기는 쪽은 끝에서 끝까지 가는 테스트로 확인만 한다.

**Tech Stack:** Python 3.9+, node(`--test`), bash(macOS 3.2 호환), git.

**Spec:** `docs/superpowers/specs/2026-10-08-plain-language-output-design.md` (brief: `docs/superpowers/interview/2026-10-03-plain-language-output-interview.md`). 선행: PR 1(#188) · PR 2(#193) 머지됨. **PR 3(quality-gates)은 사용자 결정으로 qg v10 이 끝난 뒤로 미뤘다 — 이 계획은 PR 3 에 기대지 않는다**(「PR 3 · qg v10 과의 관계」). 이 계획은 브랜치 HEAD fb9c9bb4(main 160b6e27 을 merge 로 받은 뒤) 기준이다.

## 목차

- [Global Constraints](#global-constraints)
- [계획이 정한 것](#계획이-정한-것)
- [fb9c9bb4 까지 트리가 바뀐 것](#fb9c9bb4-까지-트리가-바뀐-것)
- [PR 3 · qg v10 과의 관계](#pr-3--qg-v10-과의-관계)
- [Review Focus](#review-focus)
- [Task 0: 착수 준비](#task-0-착수-준비)
- [Task 1: 감사 보고서 · 둘레 문구 · 종료 보고](#task-1-감사-보고서--둘레-문구--종료-보고-goal-2--ac3--s1s5--s9--s16)
- [Task 2: 감사자 지적의 `plain:` 칸](#task-2-감사자-지적의-plain-칸-5--ac9--deferred-7)
- [Task 3: project-init 훅 경고와 초기화 보고](#task-3-project-init-훅-경고와-초기화-보고-s6--s13)
- [Task 4: 소개 문구 같음 락 · README · 버전](#task-4-소개-문구-같음-락--readme--버전-8--ac10--s7--s8--s11--s14)

## Global Constraints

- **재결정 규약** — confirmed 항목은 근거가 있으면 보고한 뒤 재결정할 수 있고, 임의 변경은 금지다. 설계 B1~B10 · D1.1~D2.10, PR 1 의 P1~P13, PR 2 의 Q1~Q12 가 제약이다. PR 3 의 R 행은 PR 3 이 머지되지 않았으므로 제약이 아니다(같은 관례 — 스크립트 편집 · 부재 락의 양성 짝 · 변이 — 는 따른다). 이 계획이 정한 것은 아래 표에 있고, 「사용자 확인」 칸에 표시한 행은 실행 전에 사용자에게 묻는다.
- **작업 위치** — `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice`, 브랜치 `feature/plain-language-voice`. subagent 에게 이 절대경로를 매번 못 박는다.
- **보조 파일 자리** — 이 계획의 스크립트(앵커 검사 · 편집 · 고정 단언 갱신 · 테스트 실행 · 변이)는 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/` 에 쓴다. 그 job tmp 는 다른 작업도 담는다 — **글롭으로 `rm` 하지 않는다**(subagent 포함). 지울 때는 만든 경로를 정확한 이름으로만 지운다.
- **git** — merge(rebase 금지), 경로 지정 커밋(`git add <경로>…` — `-A` · `.` 금지), Conventional Commits 에 **한국어 설명**, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. 스태시 금지.
- **편집은 스크립트로** — 각 Task 의 편집 · 고정 단언 갱신은 이 계획에 실린 파이썬 스크립트를 그대로 쓰고 돌린다. 스크립트는 옛 글자가 기대 개수만큼 있는지 먼저 다 단언하고, 하나라도 다르면 아무것도 쓰지 않고 `STOP` 으로 끝난다. `STOP` 이 나면 그 자리가 움직인 것이다 — 같은 뜻의 자리를 찾아 고치지 말고 멈춰 보고한다.
- **Python** — `encoding="utf-8"` 명시, `"python3"` 문자열 리터럴 금지(`shared/tests/test_python_floor.sh` 축 E), Python 3.9.
- **기계가 읽는 것은 그대로** — `validate-audit-data.py:144-146` 이 보는 리포트 앞 20줄의 `⚠` / `degraded`(새 둘째 줄은 배너를 한 줄 밀 뿐이다), project-init 의 정규식 넷(`CONVENTIONAL_COMMIT_PATTERN` · `BRANCH_CREATE_RE` · `COMMIT_MSG_RE` · `HEREDOC_COMMIT_RE`)과 `regex` 블록 읽기, 훅의 모델 채널(additionalContext — `Rename the branch: …` · `Allowed prefixes: … — use whichever fits this change.`), `audit-workflow.js` 의 `agent` 식별자 2회와 dispatch 두 줄(`check-law2.py` 가 센다), SKILL codex 게이트 블록의 `detect_codex.sh` · `if [[ "$codex_avail" == "true" ]]` · `${skip_reason:-unknown}`(`test_skill_codex_gate.py` · `plugins/quality-gates/tests/test_codex_gate_observation.sh` 가 그 블록을 잘라 실행한다).
- **리뷰어 지시는 보안 민감** — 감사자 · 반박자 · codex 의 찾는 지시는 한 글자도 바꾸지 않고, 「짧게 써라」를 넣지 않으며, `tools:` 를 바꾸지 않는다. 형식에 선택 칸 하나만 더한다(설계 §5).
- **처분 회계** — 이 계획이 고치는 `render-audit-report.py` · `assemble-audit-data.py` 는 회계 소비자가 아니다(S15). 렌더의 `status == "reported"` 거름과 assemble 의 `_sanitize_collection` 은 손대지 않는다. 새 코드는 지적을 버리지 않는다 — `plain:` 이 없거나 비면 지금처럼 제목으로 나간다.
- **셸** — 한국어 글자 앞의 셸 변수는 `${v}` 로 쓴다(bash 3.2 는 `「$v」` · `$v개` 를 `set -u` 에서 죽이거나 바이트를 먹는다 — `check-integrity.sh` 의 새 줄 `파일 ${COUNT}개` 가 그 자리다). 산문 단언은 줄바꿈을 지운 본문(`flat`)에서 잰다. 셸 락이 읽는 파일이 늘면 `# guards:` 선언도 같이 넓힌다(`plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` 가 두 방향으로 잰다).
- **새 테스트 파일의 모드** — 새 셸 락(`shared/tests/test_plugin_description_parity.sh`)은 실행 비트로 커밋한다(`chmod +x` — 모드 100755, `shared/tests/` 의 셸 락 관례). plugin-audit · project-init 의 새 Python 테스트는 그 디렉토리 관례대로 100644 다(기존 `test_*.py` 전부 100644).
- **테스트** — 셸은 리포 루트에서 `bash <경로>`, 하나씩(동시 실행 금지 — 고정 `/tmp` 경로가 경쟁해 거짓 RED 가 난다). Python 은 그 `tests/` 에서 `python3 -m unittest -v <모듈>`, node 는 리포 루트에서 `node --test --test-reporter=tap <파일>`. `PYTHONDONTWRITEBYTECODE=1`. `plugins/quality-gates/tests/spike/` 는 돌리지 않는다. Task 0 Step 4 의 `rt.sh` 가 이 규칙대로 돈다.
- **선재 RED(fb9c9bb4)** — `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` 의 FAIL 하나(「R1b→R8 unclaimed 집행 사슬 (집행자가 셀 원본에 닿지 못한다)」, rc=1). 이 파일의 rc 는 이미 1 이라 rc 로는 새 실패가 안 보인다 — **FAIL 줄 수 1 과 그 이름**으로 비교한다. `plugins/quality-gates/tests/test_codex_backward_compat.sh` 는 부하 아래에서 안쪽의 `test_codex_runner_degrade_contract.sh` 가 흔들려 rc=1 이 날 수 있다(드라이런 기준선에서도 났다) — 단독 재실행이 통과하면 새 실패가 아니다. `test_hook_output_schema.py` 는 진짜 워크트리에서만 실패한다(복사본에서는 통과) — 이 PR 과 무관하다.
- **변이** — 커밋한 뒤 변이한다. `pr4_mut.py` 가 셀마다 새 글자를 정확히 한 번 바꾸고 지정 테스트를 돌린 뒤 `git checkout HEAD -- <파일>` 로 되돌리고 `git diff HEAD --stat` 이 빈지 본다. 새 규칙 문장마다 셀이 있다(지우기 · 뒤집기 · 옛 글로 되돌리기 · 옮기기). `survived=0 skip=0` 이 아니면 그 락에 이빨이 없거나 셀이 어긋났다 — 락을 고친다.
- **이름** — CLAUDE.md Progressive disclosure: 기계가 내는 안내는 `/plugin:name` 완전명이고(`/plugin-audit:plugin-audit` · `/project-init:project-init`), 진입 skill 짧은 이름을 `skills/` · `scripts/` · `hooks/` 안 문면에 맨몸으로 쓰지 않는다(`shared/tests/test_invocation_surface.sh` 축 G). 새 command 파일을 만들지 않는다(축 H).
- **버전** — fb9c9bb4 에서 plugin-audit 1.0.1 → **1.1.0**(minor — `plain:` 칸이 새 표면), project-init 5.0.0 → **5.0.1**(patch — 사람용 문구). quality-gates · spec-distill 은 건드리지 않는다. 번호는 **머지 직전**에 origin/main 의 두 `plugin.json` 을 보고 다시 정한다 — qg v10 ③ 도 project-init patch 를 올린다(먼저 머지되는 쪽이 이긴다. 같은 버전 문자열은 충돌 없이 병합된다). 다시 정하면 `pr4_t4_edit.py` 머리의 상수 넷(`PA_VER_*` · `PI_VER_*`)과 `DATE`, 그리고 `pr4_mut.py` 의 「plugin.json 버전만 되돌리기」 셀을 함께 바꾼다.
- **줄 번호** — 이 계획의 줄 번호는 fb9c9bb4 실측이다(PR 1 의 규칙 블록 · #191 의 진입 머리가 반영된 값). 두 SKILL 은 옛 계획 번호 +37 이다. 편집은 줄 번호가 아니라 옛 글자로 찾는다.
- **산출 보존** — `~/.claude/sdd-mirror/plain-language-output/pr4/`.
- **드라이런** — 2026-10-10 fb9c9bb4 복사본에서 이 계획을 Task 0–4 끝까지 글자 그대로 실행했다(보고서: `/Users/jeonghokim/.claude/sdd-mirror/plain-language-output/research/dryrun-pr4-report.md`). 아래 RED 수 · GREEN · 변이 결과는 그 실측이다.

## 계획이 정한 것

| # | 정한 것 | 근거 | 사용자 확인 |
|---|---|---|---|
| S1 | 보고서 둘째 줄(제목 다음)에 스크립트가 센 상태 문장을 둔다: 「감사를 마쳤다 — 발견 N개(심각 a · 중요 b · 제안 c).」(0 인 등급은 뺀다) 또는 「감사를 마쳤다 — 보고된 발견 없음.」. 그 아래 경고 배너는 지금처럼 앞 20줄 안이다. | 설계 §3 원칙 2 · 표 `0b618227#r2.1`. 첫 줄은 제목이라 테스트가 target 을 잰다(`test_render_audit_report.py:250-252`). | — |
| S2 | 「LD4」 같은 설명 없는 번호는 뜻을 문장으로 먼저 쓰고 괄호에 둔다(배너 여섯: 축 완주 · codex 미실행 · codex 실행-실패 · codex 버림 · 빠지거나 약해진 검사 · 발견 0건). | 규칙 블록 첫 불릿. | — |
| S3 | 좌 · 우 근거의 빈 쪽은 「이 쪽을 받치는 근거는 보고되지 않았다(0건)」로 낸다 — 판단에 필요한 0. 「발견 0건」 배너도 남긴다. | 설계 §3 원칙 3 · D1.2 · AC3⑦. | — |
| S4 | 근거의 `claim` · `file` · `line` · `quote` 가 없으면 `None` 을 찍지 않는다(위치가 없으면 「(위치 없음)」, 줄이 없으면 파일만, 주장 · 인용이 없으면 그 조각을 뺀다). | 조사가 AC6 fixture 렌더에서 `— None:` 과 `` `None:None` `` 을 실측했다(드라이런 재실측: fb9c9bb4 에서 31곳). codex preamble 이 `quote` 를 optional 로 둔다. | — |
| S5 | 종료 보고는 리포트 둘째 줄의 상태 문장으로 시작하고, 리포트(`audit.md`) 경로만 보이며, 맨 끝에 할 일 하나를 쓴다. 데이터 · 원장 경로는 사용자가 물을 때만. | 설계 §4 「파일 경로는 사용자가 열어 볼 것만」. | — |
| S6 | project-init 의 사람 채널(systemMessage)만 한국어로 바꾸고, 사유 토큰(`fail-open` · `Conventional Commits` · 정규식 · 접두어 목록 · 규칙 문서 경로)은 그대로 싣는다. 모델 채널은 바꾸지 않는다. | 설계 §3 · 훅 테스트가 두 채널을 나눠 잰다. | — |
| S7 | 소개 문구 같음은 새 락 `shared/tests/test_plugin_description_parity.sh` 가 잰다 — 술어는 `check-staleness.py:394-417`(`scan_description_drift`)와 같다(같은 `name` 의 `description.strip()` 등식). 디스크의 `plugin.json` 에서 대상을 도출하고, 반대 방향(마켓플레이스 항목에 맞는 `plugin.json` 이 없음)도 잰다. | AC10. 지금 테스트는 fixture 단위뿐이다. | — |
| S8 | project-init README 의 원칙 절 제목을 `## Principles Instantiated` 로 바꾼다(불릿 형식 · 문면 유지). | `check-shape-completeness.py:49` 가 영어 제목만 받아 지금 project-init 이 그 검사에서 빠진다(드라이런 실측: 바꾼 뒤 `readme_principles` True). `check-staleness.py:498` 은 둘 다 받는다. | — |
| S9 | 보고서의 다른 빈 칸 — `답:` · `피해:` · `권고:` · `반대근거:` · 열린 질문 · 단서 판정의 `근거:` — 도 `None` 대신 「(없음)」으로 쓴다. | 드라이런 발견: assemble 의 빈칸 채움(backfill)이 `answer: None` 을 넣어 「답: None」이, codex 최소 필드 지적(preamble 이 `id` · `axis` · `title` · `severity` · `evidence` 만 요구)이 「피해: None」 셋을 찍는다. S4 를 넓힌다. | 사용자 승인 2026-10-10 (S4 보다 넓다) |
| S10 | 명령 층이 사라졌다(#191) — 옛 Task 1 Step 3 의 `commands/plugin-audit.md:14` 오타 고침을 뺀다(같은 뜻의 줄 `skills/plugin-audit/SKILL.md:60` 이 이미 「감사할 플러그인 이름이 필요합니다」). 옛 `commands/project-init.md` 의 보고 틀은 `skills/project-init/SKILL.md:248-267`(Step 5) 로 옮겨 고친다. | `git show --stat 5bbed865 46a63ff1`. 확정 결정을 바꾸지 않는다. | — |
| S11 | README 다시 쓰기를 좁힌다: plugin-audit 는 첫 문단 · 「감사가 끝나면 …」 보고 줄, project-init 은 첫 문단 · 원칙 절 제목(S8). 원칙 절 불릿 문면과 나머지 절은 글자 그대로 둔다(옛 계획은 「설명만 쉬운 문장」). 옛 계획의 「CHANGELOG 가 없다」 거짓 서술 고침은 뺀다 — #190/#191 이 이미 고쳤다(`plugins/plugin-audit/README.md:52-54`). | 설계 §8 「네 README 를 새 규칙대로 다시 쓴다」보다 좁다(PR 2 · PR 3 R13 과 같은 방식). 원칙 불릿은 Law/P 번호가 식별자라 쉬운 문장으로 다시 쓰면 `check-staleness.py` · 리뷰 인용이 기대는 문면이 흔들린다. | 사용자 승인 2026-10-10 (설계 §8 보다 좁다) |
| S12 | 새 문구 락은 플러그인 관례대로 Python unittest 둘 — `plugins/plugin-audit/tests/test_plain_audit_text.py`(SKILL 문구 · check-integrity 실행 · assemble 사유 · preamble · `plain:` 끝에서 끝 · README) · `plugins/project-init/tests/test_plain_init_text.py`(초기화 보고 · README) — 과 셸 락 하나(S7)다. 렌더 · 훅 단언은 기존 파일(`test_render_audit_report.py` · `test_post_tool_use.py`)에 더한다. | 두 플러그인의 테스트는 Python 이 주다. 셸 락은 `shared/tests/` 관례. | — |
| S13 | 훅 테스트의 두 자리를 고친다: `test_post_tool_use.py:170` 은 stdout JSON 원문을 재는데 `json.dumps` 가 한글을 `\uXXXX` 로 내므로 `systemMessage` 를 풀어서 잰다(옛 계획엔 없었다). `:313` 의 부재 단언 `assertNotIn("naming convention", …)` 은 새 문구로 옮긴다 — 옛 영어로 두면 공허하게 GREEN 이다(양성 짝: `:370`). | 드라이런 조사 · 메모리 「음의 락엔 양의 짝」. | — |
| S14 | 소개 문구의 호출은 완전명이다 — 「Run /plugin-audit:plugin-audit <name>.」(옛 계획 문안은 「Run /plugin-audit <name>.」). | CLAUDE.md Progressive disclosure(#191, 2026-10-09). | — |
| S15 | 처분 회계: `render-audit-report.py` · `assemble-audit-data.py` 는 회계 소비자가 아니다 — 어느 쪽도 `adjudication` 을 import 하지 않고, 어느 skill 의 `**처분**` 앵커도 그 둘을 `consumer=` 로 가리키지 않는다(`tools/adjudication/check_wiring.py` 의 `derive_consumers`). `run_audit_codex_reviewer.sh:4` 의 앵커는 `consumer=assemble-audit-data.py · disclosure=meta.codex` 를 가리키는데 이 계획은 `meta.codex` 를 바꾸지 않는다. | `shared/tests/test_adjudication_wiring.sh` · `test_dispatch_disposition.sh` 가 Task 1 · 2 뒤에도 GREEN(드라이런). | — |
| S16 | 상태 줄은 세 등급 밖의 지적(옛 데이터의 `HIGH` · `MEDIUM` · `LOW`)을 「기타 n」으로 센다. 세지 않으면 「발견 2개(심각 1)」처럼 합이 맞지 않는다. | 드라이런 발견: AC6 fixture(`HIGH` 1 · `CRITICAL` 1 보고)가 「발견 2개(심각 1).」을 냈다. 렌더는 옛 등급도 그린다(README 「severity 어휘 통일」). | — |

재결정(확정 항목 변경)은 없다. 사용자에게 보이던 능력을 없애는 행도 없다 — project-init 보고의 다른 플러그인 광고 줄(`/commit` · `/commit-push-pr`)과 벤더 수 줄 삭제는 옛 계획 Task 3 Step 3 그대로이고, 그 두 줄을 잡는 단언은 없다(`grep -n '16+\|/commit\|commit-commands' plugins/project-init/tests/*` → 0건, 드라이런 실측).

## fb9c9bb4 까지 트리가 바뀐 것

계획을 쓴 2026-10-08(232d80c6) 뒤 main 에 든 것 중 이 계획에 닿는 것만 적는다. `render-audit-report.py` · `assemble-audit-data.py` · `check-integrity.sh` · `codex-prompt-preamble.md` · `codex_audit_to_json.py` · `post-tool-use.py` · `test_render_audit_report.py` · `test_post_tool_use.py` 는 그동안 바뀌지 않았다 — 그 줄 번호는 옛 계획 그대로다.

| 바뀐 것 | 들인 PR | 이 계획에서 |
|---|---|---|
| 모든 SKILL.md 의 H1 뒤 규칙 블록(13줄 + 표시 줄) | #188 (PR 1) | 줄 번호 실측 |
| plugin-audit: `commands/plugin-audit.md` 삭제, skill `auditing-plugins` → `skills/plugin-audit/` 개명, 사용자 전용 진입 skill(사전 검사 줄 · `## 진입 단계` 표 · 인자 해석) — 1.0.0 | #191 | 경로 · SKILL 줄 번호(옛 148 → 185, 187-188 → 224-225, 226-230 → 263-267) · 오타 단계 삭제(S10) |
| project-init: `commands/project-init.md` → `skills/project-init/SKILL.md`(사용자 전용 진입 skill) — 5.0.0 | #191 | Task 3 경로 · 줄 번호(옛 215 → 252, 229-230 → 266-267) |
| 호출 표면 락 `shared/tests/test_invocation_surface.sh` · CLAUDE.md 이름 규칙 | #191 | 소개 문구의 완전명(S14) · 모든 Task 실행 목록에 그 락 |
| `audit-workflow.js` 가 자체 테스트 샌드박스를 소유(`audit-sandbox.sh`) | #189 (8a5a7782) | 스키마 자리는 그대로(`:84` steelman_condition — 단 그 줄은 `:115` 에도 있어 **두 번**이다 → 편집 앵커를 `oq_ref` 줄과 묶었다) |
| plugin-audit 옛 sandbox kill switch 이름 존중 · README 문면 | #190 | README 의 「CHANGELOG 가 없다」 서술이 이미 고쳐졌다 → 단계 삭제(S11) |
| `test_severity_mapping.py` docstring — plugin-audit 1.0.1 | #194 (qg v10 ②) | 버전 1.0.1 → 1.1.0 |
| quality-gates 11.0.0 · spec-distill 5.1.0 | #193 · #194 | 이 PR 은 둘을 건드리지 않는다. 새 같음 락이 그 둘의 항목도 잰다(지금 같다) |
| 마켓플레이스 spec-distill 소개 문구 | #193 (9a6b3a5e) | 같은 파일의 다른 항목 — 이 계획의 편집과 겹치지 않는다 |

다른 PR 이 이 계획의 대상 문구를 대신 바꿔 둔 자리는 둘이다: plugin-audit 진입 오류 줄의 오타(S10)와 README 의 CHANGELOG 서술(S11). 나머지 뺀 단계는 없다.

## PR 3 · qg v10 과의 관계

**PR 3 에 기대던 것을 뺐다.** 옛 계획은 「선행: PR 1 · 2 · 3 머지」였고 Task 0 Step 1 이 `PR3-MERGED` 를 확인한 뒤 `git merge origin/main` 했다. 이 계획은 PR 3 을 확인하지 않고 merge 하지 않는다 — fb9c9bb4 가 이미 main 160b6e27 을 받았다. PR 4 의 대상(plugin-audit · project-init · 마켓플레이스 두 항목)은 PR 3 의 대상(quality-gates)과 파일이 겹치지 않는다. 겹치는 것은 `.claude-plugin/marketplace.json` 한 파일의 서로 다른 항목뿐이다.

PR 3 이 나중에 오면: 그 계획의 Task 4 가 qg 소개 문구를 바꿀 때 이 PR 의 같음 락이 `plugin.json` 과 마켓플레이스 두 곳을 같이 바꾸라고 잰다(PR 3 계획은 이미 그렇게 한다). PR 3 계획은 310ce78f 기준이라 qg v10 ② 뒤 트리에 맞춰 다시 써야 하는데, 그때 이 락을 실행 목록에 넣는다.

| qg v10 | 겹치는 자리 | 무엇이 부딪히나 |
|---|---|---|
| ③ — `/qg-publish` 삭제, project-init 템플릿 `templates/shared/pr-process.md` 한 줄, project-init patch · CHANGELOG, qg 공개 description 세 곳 | `plugins/project-init/.claude-plugin/plugin.json` version · `plugins/project-init/CHANGELOG.md` 맨 위 · 마켓플레이스 qg 항목 | ③ 이 먼저면 이 계획의 Task 0 Step 2 가 `"version": "5.0.0",` · `## [5.0.0] — 2026-10-09` 에서 `STOP` 을 낸다 — 버전 상수를 다시 정한다(Global Constraints 「버전」). ③ 의 description 편집은 세 곳을 같은 문자열로 바꾸므로 같음 락과 맞는다. |
| ④ · ⑤ | 없다 | — |

## Review Focus

1. **codex 를 돌렸지만 실패한 감사** — 사람은 「돌리지 않았다」와 「돌았지만 믿을 수 없다」를 다른 일로 읽기를 기대한다(할 일이 설치 vs 재실행). → Task 1 의 고정 단언 갱신: 실행-실패 문구에 「돌리지 않았다」가 없다(`test_ran_but_failed_says_failed_not_missing`).
2. **양쪽 다 근거가 있는 열린 질문** — 「보고되지 않았다」 문장이 나오면 거짓이다. → `test_claim_is_kept_when_present`.
3. **`plain:` 이 없는(또는 빈) 감사자 지적** — 제목으로 지금처럼 나와야 한다. → `test_plain_absent_uses_title` · `test_plain_blank_uses_title` · 끝에서 끝 `test_codex_plain_reaches_the_report_heading_first`(CX-2) · 변이 「렌더가 plain 없는 지적을 건너뛰기」.
4. **커밋 메시지가 한국어인 레포** — 훅 정규식은 type 만 보므로 한국어 설명이 통과해야 한다. → `test_korean_description_passes`(처음부터 통과하는 양의 짝).
5. **마켓플레이스에만 남은 옛 기능 광고** — project-init 소개가 지금 없는 문서 · 헌장 검사를 광고한다. → 같음 락이 등식으로 잡는다(RED-first 1건).
6. **옛 등급 데이터의 상태 줄** — `HIGH` 지적이 상태 줄의 합에서 빠지면 개수가 맞지 않는다. → `test_grades_outside_the_three_are_counted`(S16).
7. **비-UTF-8 locale 의 훅 출력** — 한글 경고가 JSON 이스케이프로 나가 깨지지 않는다. → `test_post_tool_use.py:170`(`LC_ALL=C` · `PYTHONUTF8=0`)이 풀어 읽은 `systemMessage` 를 잰다(S13).

---

## Task 0: 착수 준비

- [ ] **Step 1: 트리가 fb9c9bb4 인지 확인한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
mkdir -p ~/.claude/sdd-mirror/plain-language-output/pr4 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4
git status --porcelain
git fetch origin main
git merge-base --is-ancestor origin/main HEAD && echo MAIN-IN-HEAD || echo "MAIN-MOVED $(git rev-list --count HEAD..origin/main)"
git diff --stat fb9c9bb4 HEAD -- plugins/plugin-audit plugins/project-init shared tools .claude-plugin CLAUDE.md | tail -1
```

기대: status 는 비었거나 이 계획 파일 한 줄뿐 · `MAIN-IN-HEAD` · diff --stat 빈 출력. `MAIN-MOVED <n>` 이면 merge 하지 말고 멈춰 보고한다(`git diff --stat HEAD...origin/main -- plugins/plugin-audit plugins/project-init shared .claude-plugin` 를 함께) — 특히 qg v10 ③ 이 들었는지(「PR 3 · qg v10 과의 관계」).

- [ ] **Step 2: 이 계획의 옛 글자가 그대로인지 본다**

아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_anchor_check.sh` 에 그대로 쓰고 `bash` 로 돌린다. 줄마다 기대 개수(기본 1, 셋째 인자가 있으면 그 값)와 다르면 `STOP` 이다.

````bash
#!/usr/bin/env bash
# PR 4 Task 0 Step 2 — 이 계획이 바꾸는 옛 문구가 기대 개수만큼 있는지(grep -cF) 센다.
set -u
R="${R:-/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice}"
c() { n="$(grep -cF -- "$2" "$R/$1")"; e="${3:-1}"; [ "$n" = "$e" ] && s=ok || s=STOP; printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$n" "$1" "$2" "(기대 ${e})"; }
PA=plugins/plugin-audit
RD=$PA/scripts/render-audit-report.py
SK=$PA/skills/plugin-audit/SKILL.md
PI=plugins/project-init
# Task 1
c "$RD" 'def render(data: dict) -> str | None:'
c "$RD" '    lines = [f"# {target} 읽기전용 감사 — " + meta.get("date", "")]'
c "$RD" '        banners.append(f"⚠ **{6 - len(axis_failures)}/6 축 완주** — {len(axis_failures)}개 축 감사 실패")'
c "$RD" '        banners.append("⚠ **codex 독립 감사 미실행** — LD4 모델 다양성 결손")'
c "$RD" '        banners.append("⚠ **codex 독립 감사 실행-실패** — 돌았으나 결과를 신뢰할 수 없다 "'
c "$RD" '        banners.append(f"⚠ **codex {d.get('"'"'collection'"'"')} {d.get('"'"'count'"'"')}건 폐기** — "'
c "$RD" '        banners.append(f"⚠ **degraded {len(degraded)}건** — 아래 결손 목록 참조")'
c "$RD" '        banners.append("⚠ **발견 0건** — 이것이 *깨끗함*인지 *감사 실패*인지 축 완주 수와 journal로 확인하라")'
c "$RD" '            lines.append(f"- `{ev.get('"'"'file'"'"')}:{ev.get('"'"'line'"'"')}` — {ev.get('"'"'quote'"'"')}")'
c "$RD" '                            lines.append(f"  - {side_label}: 0건")'
c "$RD" '                                lines.append(f"    - `{e.get('"'"'file'"'"')}:{e.get('"'"'line'"'"')}` — {e.get('"'"'claim'"'"')}: {e.get('"'"'quote'"'"')}")'
c "$RD" '                        lines.append(f"    - `{e.get('"'"'file'"'"')}:{e.get('"'"'line'"'"')}` — {e.get('"'"'quote'"'"')}")'
c "$RD" '                    lines.append(f"  - 답: {a.get('"'"'answer'"'"')}")'
c "$RD" "get('file')}:{" 3
c "$RD" "        lines.append(f\"- 피해: {f.get('user_harm')}\")"
c "$RD" "        lines.append(f\"- 반대근거: {f.get('counter_argument')}\")"
c "$RD" "                lines.append(f\"  - 근거: {a.get('reason')}\")"
c "$RD" "                lines.append(f\"  - 근거: {d.get('reason')}\")"
c "$RD" 'plain' 0
c $PA/scripts/assemble-audit-data.py '"reason": "axis incomplete — backfilled", "source": "claude"})'
c $PA/scripts/assemble-audit-data.py '"reason": "axis incomplete — backfilled (unverified)", "source": "claude"})'
CI=$PA/scripts/check-integrity.sh
c "$CI" 'echo "[check-integrity] FATAL: --target requires a value" >&2'
c "$CI" 'echo "[check-integrity] FATAL: --extra-path requires a value" >&2'
c "$CI" 'echo "[check-integrity] FATAL: unknown argument: $1" >&2'
c "$CI" 'echo "[check-integrity] FATAL: mode=ld5 requires --target <name>" >&2'
c "$CI" 'echo "[check-integrity] FATAL: manifest is empty (mode=$MODE) — enumeration produced nothing." >&2'
c "$CI" 'echo "[check-integrity] mode=$MODE files=$COUNT -> $OUT" >&2'
c "$SK" 'echo "[plugin-audit] codex blind co-audit SKIPPED (reason: ${skip_reason:-unknown}) — 이 감사에는 모델 다양성이 없었다 (degraded)." >&2'
c "$SK" 'R5). 통과분만 `$RUN_DIR/audit-journal.jsonl`로 저술한다. 이 파일이 `render-audit-report.py`의 "축 완주 수와'
c "$SK" '   journal로 확인하라" 포인터의 **실체**다 — journal 은 실행 디렉토리의 작업 산출물이고, persist 안 하면 그'
c "$SK" '8. **종료 보고** — step 5 가 일치하고 step 7 이 GREEN 일 때만 이 종료 보고를 한다. 리포트'
c "$SK" '   (`$RUN_DIR/audit-journal.jsonl`)의 절대경로를 사용자에게 보인다. 리포트는 한 번 읽는 작업 산출물이다 —'
c "$SK" '감사할 플러그인 이름이 필요합니다 — /plugin-audit:plugin-audit <target> [--seed <path>]'
TR=$PA/tests/test_render_audit_report.py
c "$TR" '        self.assertIn("codex 독립 감사 미실행", head)'
c "$TR" '        self.assertIn("codex 독립 감사 미실행", out)'
c "$TR" '        self.assertIn("codex 독립 감사 실행-실패", out,'
c "$TR" '        self.assertNotIn("미실행", out,'
c "$TR" '        self.assertIn("codex d_verdicts 2건 폐기", out,'
c "$TR" '        self.assertIn("0건", md, "OQ1 우측이 비었으면 0건으로 명시돼야 (숨기면 안 됨, §9.5)")'
c "$TR" 'class PlainLanguageReport' 0
test -e "$R/$PA/tests/test_plain_audit_text.py" && printf 'STOP\t1\t%s\t(이미 있다)\n' "$PA/tests/test_plain_audit_text.py" || printf 'ok\t0\t%s\t(아직 없다)\n' "$PA/tests/test_plain_audit_text.py"
# Task 2
WF=$PA/scripts/audit-workflow.js
c "$WF" "          oq_ref: { type: 'string' },"
c "$WF" "          steelman_condition: { type: 'string', enum: ['a', 'b', 'c', 'd', 'none', 'pending'] }," 2
c "$WF" 'plain' 0
PR=$PA/scripts/codex-prompt-preamble.md
c "$PR" '    `IMPORTANT`, `SUGGESTION`), `evidence` (array of `{file, line}` objects; `quote` optional).'
c "$PR" '    {"id": "CX-1", "axis": 3, "title": "example finding title", "severity": "IMPORTANT",'
c "$PR" 'plain' 0
c "$RD" "        lines.append(f\"### [{f.get('severity')}] {f.get('title')} ({f.get('id')}){badge}{deep_label(f)}\")"
c $PA/tests/audit-workflow.test.mjs "captured['감사']" 4
# Task 3
HK=$PI/hooks/post-tool-use.py
c "$HK" '            "project-init: no valid branch-naming pattern found in "'
c "$HK" '        hint = f"Allowed prefixes: {'"'"', '"'"'.join(prefixes)}"'
c "$HK" '            f"Allowed prefixes: {'"'"', '"'"'.join(prefixes)} — use whichever fits this change."'
c "$HK" '        hint = "See docs/git-workflow/branch-strategy.md for allowed prefixes."'
c "$HK" "        f'project-init: Branch \"{branch_name}\" does not follow naming convention.',"
c "$HK" '        f"Expected pattern: {pattern.pattern}",'
c "$HK" '        f"project-init: Commit message does not follow Conventional Commits format.\n"'
c "$HK" '        f"Suggested: {suggested_type}: {first_line}",'
c "$HK" 're.compile(' 5
PS=$PI/skills/project-init/SKILL.md
c "$PS" '> **{strategy 이름}** 전략으로 git workflow 초기화 완료.'
c "$PS" '> AGENTS.md primary 패턴으로 OpenAI Codex, Cursor, Aider 등 16+ 벤더가 동일 파일을 인식합니다.'
c "$PS" '> 간결한 git 작업을 위해 `/commit` 또는 `/commit-push-pr` (commit-commands 플러그인) 사용.'
c "$PS" '> 생성/업데이트된 파일:'
TP=$PI/tests/test_post_tool_use.py
c "$TP" '        self.assertIn("skipping", msg)'
c "$TP" '        self.assertIn("does not follow naming convention", out)'
c "$TP" '        self.assertIn("Allowed prefixes: feature, fix, release, hotfix", msg)  # body-unique teeth (not header-satisfiable)'
c "$TP" '        self.assertIn("docs/git-workflow/branch-strategy.md", msg)'
c "$TP" '            self.assertNotIn("naming convention", msg)  # branch OK -> no branch warning'
c "$TP" '            self.assertIn("does not follow naming convention", sm)'
c "$TP" '            self.assertIn("Expected pattern:", sm)'
c "$TP" '            self.assertIn("Allowed prefixes: feature, fix, release, hotfix", sm)'
c "$TP" '            self.assertIn("Suggested: feat: add thing", sm)'
c "$TP" '        self.assertIsNone(_hook.validate_commit('"'"'git commit -m "feat: add thing"'"'"'))'
# Task 4
c $PA/.claude-plugin/plugin.json '"description": "Read-only, evidence-based multi-agent audit of an arbitrary devbrew plugin: 6-axis discovery → adversarial refutation → blind codex co-audit → prioritized gap report. Invoke via /plugin-audit <target> [--seed <path>].",'
c .claude-plugin/marketplace.json '"description": "Read-only, evidence-based multi-agent audit of an arbitrary devbrew plugin: 6-axis discovery → adversarial refutation → blind codex co-audit → prioritized gap report. Invoke via /plugin-audit <target> [--seed <path>].",'
c $PI/.claude-plugin/plugin.json '"description": "Initialize git-workflow rules and a project charter via a fact-routing interview, then generate agent-readable AGENTS.md/CLAUDE.md docs with hook-based validation of branches and commits.",'
c .claude-plugin/marketplace.json '"description": "Initialize git-workflow rules and a project charter via a fact-routing interview, then generate agent-readable AGENTS.md/CLAUDE.md docs with hook-based validation of branches, commits, doc conventions, and charter integrity.",'
c $PA/README.md '임의의 devbrew 플러그인을 **읽기전용·증거기반·multi-agent**로 감사한다. 6축 병렬 발견 →'
c $PA/README.md '감사가 끝나면 세 파일의 절대경로를 보고한다. 같은 날 같은 대상을 다시 감사하면 `-2` 로 새로 만든다.'
c $PA/README.md '`CHANGELOG.md` 는 0.6.1 부터 있다'
c $PI/README.md 'Claude Code용 git workflow 초기화 플러그인. 어떤 프로젝트에든 branching strategy, commit conventions, PR process 룰을 생성한다.'
c $PI/README.md '## 인스턴스화한 원칙'
c $PI/README.md '## Principles Instantiated' 0
c $PA/.claude-plugin/plugin.json '"version": "1.0.1",'
c $PI/.claude-plugin/plugin.json '"version": "5.0.0",'
c $PA/CHANGELOG.md '## [1.0.1] — 2026-10-09'
c $PI/CHANGELOG.md '## [5.0.0] — 2026-10-09'
test -e "$R/shared/tests/test_plugin_description_parity.sh" && printf 'STOP\t1\tshared/tests/test_plugin_description_parity.sh\t(이미 있다)\n' || printf 'ok\t0\tshared/tests/test_plugin_description_parity.sh\t(아직 없다)\n'
test -e "$R/$PI/tests/test_plain_init_text.py" && printf 'STOP\t1\t%s\t(이미 있다)\n' "$PI/tests/test_plain_init_text.py" || printf 'ok\t0\t%s\t(아직 없다)\n' "$PI/tests/test_plain_init_text.py"
test -e "$R/$PA/commands" && printf 'STOP\t1\t%s\t(명령 층이 되살아났다)\n' "$PA/commands" || printf 'ok\t0\t%s\t(없다)\n' "$PA/commands"
test -e "$R/$PI/commands" && printf 'STOP\t1\t%s\t(명령 층이 되살아났다)\n' "$PI/commands" || printf 'ok\t0\t%s\t(없다)\n' "$PI/commands"
````

```bash
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_anchor_check.sh > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/anchor.out
grep -c '^ok' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/anchor.out
grep -v '^ok' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/anchor.out
```

기대: `90`, 빈 출력(fb9c9bb4 실측). `STOP` 이 하나라도 있으면 그 줄의 Task 로 가기 전에 멈춰 보고한다.

- [ ] **Step 3: 기준선**

fb9c9bb4 의 기준선은 드라이런이 깨끗한 복사본에서 떠 두었다: `~/.claude/sdd-mirror/plain-language-output/pr4/baseline/`(`summary.tsv` · `failures.txt` · `logs/`, 273 파일, rc≠0 은 harness 하나(FAIL 1) + 흔들린 `test_codex_backward_compat.sh` 하나). Step 1 의 diff --stat 이 비었으면 그것을 쓴다. 아니면 다시 뜬다(약 50분, 그동안 이 워크트리에서 테스트를 돌리지 않는다):

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr4/baseline
```

- [ ] **Step 4: 실행 도구 둘**

테스트 실행기 — `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/rt.sh`:

````bash
#!/bin/bash
# rt.sh <리포 루트 상대 테스트 경로>... — 리포 루트에서 하나씩 돌린다(동시 실행 금지 — 고정 /tmp 경로가 경쟁한다).
# 줄마다: 이름 · rc · 실패 줄 수 · 로그 끝줄. 로그는 $LOGS/<basename>.log 에 남는다.
# .py 는 그 tests 디렉토리에서 unittest, .mjs 는 리포 루트에서 node --test(tap), 나머지는 bash.
R="${R:-/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice}"
LOGS="${LOGS:-/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/logs}"
cd "$R" || exit 1
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$LOGS"
for t in "$@"; do
  log="$LOGS/$(basename "$t").log"
  case "$t" in
    *.py)  ( cd "$(dirname "$t")" && python3 -m unittest -v "$(basename "$t" .py)" ) > "$log" 2>&1; rc=$? ;;
    *.mjs) node --test --test-reporter=tap "$t" > "$log" 2>&1; rc=$? ;;
    *)     bash "$t" > "$log" 2>&1; rc=$? ;;
  esac
  n=$(grep -acE '^[[:space:]]*✗ |^(FAIL|ERROR)[: ]|^not ok |^BAD ' "$log")
  printf '%s\trc=%s\tfail=%s\t%s\n' "$(basename "$t")" "$rc" "$n" "$(tail -1 "$log" | LC_ALL=C cut -c1-150)"
done
````

변이 실행기 — `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_mut.py`(각 Task 의 마지막 Step 이 부른다):

````python
#!/usr/bin/env python3
"""PR 4 변이 셀 — 커밋한 뒤에 돈다. 셀마다: 새 글자를 정확히 한 번 바꾸고, 지정한 테스트를 하나씩
리포 루트 기준으로 돌려 rc 를 적고, `git checkout HEAD -- <파일>` 로 되돌린 뒤 `git diff HEAD --stat`
이 비었는지 본다.   pr4_mut.py <리포 루트> <t1|t2|t3|t4>
기대: 셀마다 「RED」(지정 테스트 중 하나 이상 rc≠0). 「SURVIVED」 가 하나라도 있으면 그 락에 이빨이 없다.
「SKIP」 은 바꿀 글자가 정확히 한 번이 아니라는 뜻이다 — 셀이나 편집이 어긋났다(실패로 센다)."""
import os, subprocess, sys

R = os.path.abspath(sys.argv[1])
TASK = sys.argv[2]
PA, PI = "plugins/plugin-audit/", "plugins/project-init/"
RD = PA + "scripts/render-audit-report.py"
AS = PA + "scripts/assemble-audit-data.py"
CI = PA + "scripts/check-integrity.sh"
SK = PA + "skills/plugin-audit/SKILL.md"
WF = PA + "scripts/audit-workflow.js"
PR = PA + "scripts/codex-prompt-preamble.md"
CV = PA + "scripts/codex_audit_to_json.py"
HK = PI + "hooks/post-tool-use.py"
PS = PI + "skills/project-init/SKILL.md"
TR = PA + "tests/test_render_audit_report.py"
TT = PA + "tests/test_plain_audit_text.py"
TC = PA + "tests/test_codex_audit_to_json.py"
TM = PA + "tests/audit-workflow.test.mjs"
TU = PI + "tests/test_post_tool_use.py"
TI = PI + "tests/test_plain_init_text.py"
TD = "shared/tests/test_plugin_description_parity.sh"

MUTS = {
    "t1": [
        ("0 인 등급 되살리기", RD, "        if n:\n            parts.append", "        if True:\n            parts.append", [TR]),
        ("기타 등급 빼기", RD, '    if rest:\n        parts.append("기타 %d" % rest)\n', "", [TR]),
        ("상태 줄 빼기", RD, "    lines.append(status_line(findings))\n", "", [TR]),
        ("빈 상태 줄을 영어로", RD, 'return "감사를 마쳤다 — 보고된 발견 없음."', 'return "No findings."', [TR]),
        ("축 배너를 옛 글로", RD, '"⚠ **축 {6 - len(axis_failures)}/6 완주** — {len(axis_failures)}개 축은 감사하지 못했다"',
         '"⚠ **{6 - len(axis_failures)}/6 축 완주** — {len(axis_failures)}개 축 감사 실패"', [TR]),
        ("codex 미실행 배너를 옛 글로", RD, '"⚠ **codex 독립 감사를 돌리지 않았다** — 다른 모델의 확인이 없다(LD4 모델 다양성 결손)"',
         '"⚠ **codex 독립 감사 미실행** — LD4 모델 다양성 결손"', [TR]),
        ("번호를 뜻 앞으로", RD, "— 다른 모델의 확인이 없다(LD4 모델 다양성 결손)\")",
         "— LD4 모델 다양성 결손(다른 모델의 확인이 없다)\")", [TR]),
        ("실행-실패 배너를 옛 글로", RD, '"⚠ **codex 독립 감사가 돌았지만 결과를 믿을 수 없다** — 다른 모델의 확인이 없다"',
         '"⚠ **codex 독립 감사 실행-실패** — 돌았으나 결과를 신뢰할 수 없다 "', [TR]),
        ("버린 배너를 옛 글로", RD, "건을 버렸다** — \"", "건 폐기** — \"", [TR]),
        ("degraded 배너를 옛 글로", RD, 'f"⚠ **빠지거나 약해진 검사 {len(degraded)}건**(degraded) — 아래 「결손」 목록에 있다"',
         'f"⚠ **degraded {len(degraded)}건** — 아래 결손 목록 참조"', [TR]),
        ("발견 0건 배너를 옛 글로", RD, "— 문제가 없어서인지 감사가 실패해서인지는 축 완주 수와 기록(journal)으로 확인하라",
         "— 이것이 *깨끗함*인지 *감사 실패*인지 축 완주 수와 journal로 확인하라", [TR, TT]),
        ("빈 쪽 문장을 0건으로", RD, 'f"  - {side_label}: 이 쪽을 받치는 근거는 보고되지 않았다(0건)"', 'f"  - {side_label}: 0건"', [TR]),
        ("빈 쪽 문장 지우기", RD, 'lines.append(f"  - {side_label}: 이 쪽을 받치는 근거는 보고되지 않았다(0건)")', "pass", [TR]),
        ("위치 없음을 None 으로", RD, '    if file is None or file == "":\n        return "(위치 없음)"\n', "", [TR]),
        ("줄 없는 위치를 None 으로", RD, '    if line is None:\n        return "`%s`" % file\n', "", [TR]),
        ("인용 None 되살리기", RD, '    if ev.get("quote") is not None:\n        body += str(ev.get("quote"))',
         '    body += str(ev.get("quote"))', [TR]),
        ("주장 None 되살리기", RD, '    if with_claim and ev.get("claim"):', "    if with_claim:", [TR]),
        ("빈 칸을 None 으로", RD, 'return "(없음)" if x is None else str(x)', "return str(x)", [TR]),
        ("근거 줄을 옛 f-string 으로", RD, '            lines.append(f"- {ev_text(ev)}")',
         "            lines.append(f\"- `{ev.get('file')}:{ev.get('line')}` — {ev.get('quote')}\")", [TR]),
        ("빈칸 채움 사유를 영어로", AS, '"reason": "축 감사가 끝나지 않아 빈칸을 채웠다(backfilled)", "source"',
         '"reason": "axis incomplete — backfilled", "source"', [TT]),
        ("빈칸 채움(미검증) 사유를 영어로", AS, '"reason": "축 감사가 끝나지 않아 빈칸을 채웠다(backfilled — 검증 안 됨)"',
         '"reason": "axis incomplete — backfilled (unverified)"', [TT]),
        ("--target 오류를 영어로", CI, "FATAL: --target 에 값이 없다(--target requires a value)", "FATAL: --target requires a value", [TT]),
        ("--extra-path 오류를 영어로", CI, "FATAL: --extra-path 에 값이 없다(--extra-path requires a value)",
         "FATAL: --extra-path requires a value", [TT]),
        ("모르는 인자 오류를 영어로", CI, "FATAL: 알 수 없는 인자다 — ${1} (unknown argument)", "FATAL: unknown argument: $1", [TT]),
        ("ld5 오류를 영어로", CI, "FATAL: ld5 모드에는 --target <name> 이 필요하다(mode=ld5 requires --target)",
         "FATAL: mode=ld5 requires --target <name>", [TT]),
        ("빈 목록 오류를 영어로", CI, "FATAL: 해시 목록이 비었다(mode=${MODE}, manifest is empty) — 열거한 파일이 하나도 없다.",
         "FATAL: manifest is empty (mode=$MODE) — enumeration produced nothing.", [TT]),
        ("요약 줄을 영어로", CI, '"[check-integrity] 파일 ${COUNT}개의 해시를 적었다(mode=${MODE}) -> ${OUT}"',
         '"[check-integrity] mode=$MODE files=$COUNT -> $OUT"', [TT]),
        ("건너뜀 줄을 영어로", SK, "codex 독립 감사를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이 감사에는 다른 모델의 확인이 없다. 모델 다양성 없음(degraded).",
         "codex blind co-audit SKIPPED (reason: ${skip_reason:-unknown}) — 이 감사에는 모델 다양성이 없었다 (degraded).", [TT]),
        ("건너뜀 줄의 사유 토큰 지우기", SK, "건너뛰었다 (reason: ${skip_reason:-unknown}) — 이 감사에는", "건너뛰었다 — 이 감사에는",
         [TT, "plugins/quality-gates/tests/test_codex_gate_observation.sh"]),
        ("SKILL 인용을 옛 글로", SK, '   기록(journal)으로 확인하라" 포인터의', '   journal로 확인하라" 포인터의', [TT]),
        ("종료 보고 첫 줄 문장 바꾸기", SK, "첫 줄은 리포트 둘째 줄의\n   상태 문장을 그대로 쓴다", "리포트 둘째 줄의\n   상태 문장을 참고한다", [TT]),
        ("종료 보고 「물을 때만」 뒤집기", SK, "경로는 사용자가 물을 때만 보인다.", "경로도 함께 보인다.", [TT]),
        ("종료 보고 끝 할 일 지우기", SK, " 맨 끝에 사용자가 할 일 하나를 쓴다\n", "\n", [TT]),
    ],
    "t2": [
        ("스키마에서 plain 지우기", WF, "          plain: { type: 'string', description: 'Optional. The same finding in one plain sentence a first-time reader understands — no internal IDs.' },\n", "", [TM]),
        ("plain 을 required 로", WF, "                   'fix_cost_rationale', 'reference_gap'],\n",
         "                   'fix_cost_rationale', 'reference_gap', 'plain'],\n", [TM]),
        ("스키마 설명 지우기", WF, "plain: { type: 'string', description: 'Optional. The same finding in one plain sentence a first-time reader understands — no internal IDs.' }",
         "plain: { type: 'string' }", [TM]),
        ("Workflow 병합이 plain 을 버리기", WF, "    const rec = { ...f, source: 'claude' }", "    const rec = { ...f, plain: undefined, source: 'claude' }", [TM]),
        ("preamble 문장 지우기", PR, "    Optional `plain` (string): the same finding in one plain sentence a first-time reader understands,\n    no internal IDs.\n", "", [TT]),
        ("preamble 예시 키 지우기", PR, '     "plain": "one plain sentence for a first-time reader",\n', "", [TT]),
        ("preamble 을 Required 로", PR, "Optional `plain`", "Required `plain`", [TT]),
        ("변환기가 plain 을 버리기", CV, "        out[key] = [x for x in raw if isinstance(x, dict)]",
         "        out[key] = [{k: v for k, v in x.items() if k != \"plain\"} for x in raw if isinstance(x, dict)]", [TC, TT]),
        ("렌더가 plain 없는 지적을 건너뛰기", RD, "        else:\n            head = f\"{f.get('title')} ({f.get('id')})\"\n",
         "        else:\n            continue\n", [TR, TT]),
        ("plain 과 제목 순서 뒤집기", RD, "            head = f\"{' '.join(plain.split())} ({f.get('title')} · {f.get('id')})\"",
         "            head = f\"{f.get('title')} ({' '.join(plain.split())} · {f.get('id')})\"", [TR, TT]),
        ("plain 줄바꿈 그대로", RD, "{' '.join(plain.split())} (", "{plain} (", [TR]),
        ("빈 plain 도 쓰기", RD, "if isinstance(plain, str) and plain.strip():", "if isinstance(plain, str):", [TR]),
    ],
    "t3": [
        ("fail-open 문구를 영어로", HK, '"project-init: docs/git-workflow/branch-strategy.md 에서 쓸 수 있는 브랜치 이름 규칙을 "\n            "찾지 못했다 — 브랜치 이름 검사를 건너뛴다(fail-open).",',
         '"project-init: no valid branch-naming pattern found in docs/git-workflow/branch-strategy.md — skipping branch-name validation (fail-open).",', [TU]),
        ("사람 채널 접두어를 영어로", HK, '        hint = f"허용 접두어: {', '        hint = f"Allowed prefixes: {', [TU]),
        ("규칙 문서 안내를 영어로", HK, '"허용 접두어는 docs/git-workflow/branch-strategy.md 에 있다."',
         '"See docs/git-workflow/branch-strategy.md for allowed prefixes."', [TU]),
        ("브랜치 위반 줄을 영어로", HK, "f'project-init: 브랜치 이름이 이름 규칙에 맞지 않는다 — \"{branch_name}\".'",
         "f'project-init: Branch \"{branch_name}\" does not follow naming convention.'", [TU]),
        ("기대 형식 줄을 영어로", HK, 'f"기대하는 형식: {pattern.pattern}"', 'f"Expected pattern: {pattern.pattern}"', [TU]),
        ("커밋 첫 줄을 영어로", HK, 'f"project-init: 커밋 메시지가 Conventional Commits 형식이 아니다.\\n"',
         'f"project-init: Commit message does not follow Conventional Commits format.\\n"', [TU]),
        ("형식 줄을 영어로", HK, 'f"형식: <type>(<scope>): <설명>\\n"', 'f"Expected: <type>(<scope>): <description>\\n"', [TU]),
        ("type 줄을 영어로", HK, 'f"type: feat, fix,', 'f"Types: feat, fix,', [TU]),
        ("제안 줄을 영어로", HK, 'f"제안: {suggested_type}: {first_line}"', 'f"Suggested: {suggested_type}: {first_line}"', [TU]),
        ("모델 채널을 한국어로(바뀌면 안 된다)", HK, 'f"Allowed prefixes: {\', \'.join(prefixes)} — use whichever fits this change."',
         'f"허용 접두어: {\', \'.join(prefixes)} — use whichever fits this change."', [TU]),
        ("맞는 브랜치에도 경고", HK, "    if pattern.match(branch_name):\n        return None\n", "", [TU]),
        ("보고 첫 줄을 옛 글로", PS, "> **{strategy 이름}** 전략으로 git workflow 를 초기화했다.", "> **{strategy 이름}** 전략으로 git workflow 초기화 완료.", [TI]),
        ("할 일 줄 지우기", PS, "> 다음 할 일: 새 브랜치를 하나 만들어 보라 — `git checkout -b feature/<이름>` 이면 훅이 이름을 바로 확인한다.\n", "", [TI]),
        ("할 일 줄 둘", PS, "> 다음 할 일: 새 브랜치를",
         "> 다음 할 일: /qg 를 돌려 보라.\n> 다음 할 일: 새 브랜치를", [TI]),
        ("옛 광고 줄 되살리기", PS, "> 다음 할 일: 새 브랜치를",
         "> 간결한 git 작업을 위해 `/commit` 또는 `/commit-push-pr` (commit-commands 플러그인) 사용.\n> 다음 할 일: 새 브랜치를", [TI]),
    ],
    "t4": [
        ("마켓플레이스 project-init 글자 하나", ".claude-plugin/marketplace.json", "adds a hook that checks branch names", "adds a hook that checks branch name", [TD]),
        ("plugin.json plugin-audit 글자 하나", PA + ".claude-plugin/plugin.json", "Audits one devbrew plugin", "Audits one devbrew plugins", [TD]),
        ("마켓플레이스 항목 이름 바꾸기", ".claude-plugin/marketplace.json", '"name": "project-init",', '"name": "project-initx",', [TD]),
        ("plugin-audit README 첫 문단을 옛 글로", PA + "README.md", "devbrew 플러그인 하나를 고치지 않고 읽기만 해서 감사한다.", "임의의 devbrew 플러그인을 감사한다.", [TT]),
        ("plugin-audit README 보고 줄을 옛 글로", PA + "README.md", "감사가 끝나면 상태 한 줄과 리포트(`audit.md`) 경로를 보고한다 — 데이터 · 원장 경로는 물으면 보인다.",
         "감사가 끝나면 세 파일의 절대경로를 보고한다.", [TT]),
        ("project-init README 첫 문단을 옛 글로", PI + "README.md", "프로젝트의 git 작업 규칙(브랜치 이름 · 커밋 메시지 · PR 절차)과 프로젝트 헌장을 짧은 대화로 만들어 준다.",
         "Claude Code용 git workflow 초기화 플러그인.", [TI]),
        ("project-init 원칙 절 제목을 옛 글로", PI + "README.md", "\n## Principles Instantiated\n", "\n## 인스턴스화한 원칙\n", [TI]),
        ("plugin.json 버전만 되돌리기", PA + ".claude-plugin/plugin.json", '"version": "1.1.0",', '"version": "1.0.1",', ["shared/tests/test_changelog_integrity.sh"]),
    ],
}


def sh(args, cwd=R):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")


def run_test(t):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    if t.endswith(".py"):
        p = subprocess.run([sys.executable, "-m", "unittest", os.path.basename(t)[:-3]], cwd=os.path.join(R, os.path.dirname(t)),
                           capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    elif t.endswith(".mjs"):
        p = subprocess.run(["node", "--test", "--test-reporter=tap", t], cwd=R, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", env=env)
    else:
        p = subprocess.run(["bash", t], cwd=R, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    return p.returncode


def main():
    cells = MUTS[TASK]
    red = survived = skip = 0
    for name, rel, old, new, tests in cells:
        path = os.path.join(R, rel)
        s = open(path, encoding="utf-8").read()
        if s.count(old) != 1:
            print("SKIP\t%s\t%s\t(옛 글자 %d번)" % (name, rel, s.count(old)))
            skip += 1
            continue
        try:
            open(path, "w", encoding="utf-8").write(s.replace(old, new))
            rcs = [run_test(t) for t in tests]
        finally:
            sh(["git", "checkout", "HEAD", "--", rel])
        clean = sh(["git", "diff", "HEAD", "--stat"]).stdout.strip() == ""
        verdict = "RED" if any(rcs) else "SURVIVED"
        red += verdict == "RED"
        survived += verdict == "SURVIVED"
        print("%s\t%s\t%s\trc=%s\t%s" % (verdict, name, rel, rcs, "restored" if clean else "NOT-RESTORED"))
        if not clean:
            sys.exit(3)
    print("cells=%d red=%d survived=%d skip=%d" % (len(cells), red, survived, skip))
    sys.exit(0 if survived == 0 and skip == 0 else 1)


main()
````

이하 각 Task 의 명령은 리포 루트(`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice`)에서 돈다. `T=/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4` 는 설명용 약칭이다 — Bash 도구는 호출마다 새 셸이라 명령에는 절대경로를 그대로 쓴다.

---

## Task 1: 감사 보고서 · 둘레 문구 · 종료 보고 (Goal 2 · AC3 · S1~S5 · S9 · S16)

**Files:**
- Modify: `plugins/plugin-audit/scripts/render-audit-report.py:51-171`(도우미 넷 · 상태 줄 · 배너 여섯 · 근거 줄 · 빈 칸)
- Modify: `plugins/plugin-audit/scripts/assemble-audit-data.py:113 · :119`(빈칸 채움 사유)
- Modify: `plugins/plugin-audit/scripts/check-integrity.sh:56 · :64 · :71 · :78 · :154 · :158`(오류 · 요약 줄 — `usage:` 줄 둘은 CLI 사용법이라 그대로)
- Modify: `plugins/plugin-audit/skills/plugin-audit/SKILL.md:185 · :224-225 · :263-267`
- Modify: `plugins/plugin-audit/tests/test_render_audit_report.py`(고정 단언 · 새 클래스)
- Create: `plugins/plugin-audit/tests/test_plain_audit_text.py`

- [ ] **Step 1: 실패하는 테스트**

고정 단언 갱신(PR 본문 표에 그대로 옮긴다 — AC13):

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_render_audit_report.py:67`(주석) · `:74` · `:283` | `"codex 독립 감사 미실행"` | `"codex 독립 감사를 돌리지 않았다"` | 미실행이 앞 20줄에 보인다 |
| `:290` | `"codex 독립 감사 실행-실패"` | `"codex 독립 감사가 돌았지만 결과를 믿을 수 없다"` | 실행-실패가 보인다 |
| `:292` | `assertNotIn("미실행", out, …)` | `assertNotIn("돌리지 않았다", out, …)` | 두 상태가 뭉개지지 않는다 |
| `:305` | `"codex d_verdicts 2건 폐기"` | `"codex d_verdicts 2건을 버렸다"` | 버린 컬렉션 · 개수가 한 줄에 보인다 |
| `:173` | `assertIn("0건", md, …)` | `assertIn("우: 이 쪽을 받치는 근거는 보고되지 않았다(0건)", md, …)` 와 `assertNotIn("좌: 이 쪽을 받치는 근거는 보고되지 않았다", md, …)` | 빈 쪽이 보이고, 근거 있는 쪽엔 거짓 문장이 없다 |

`:89` 의 `"/6"` 은 새 배너 「⚠ **축 5/6 완주** — …」가 그대로 담는다. `:297` 의 `assertNotIn("codex 독립 감사", out)`(codex 정상)은 새 배너 둘이 그 글자로 시작하므로 그대로 이빨이 있다.

아래 셋을 쓰고 돌린다.

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t1_pins.py`:

````python
#!/usr/bin/env python3
"""PR 4 Task 1 Step 1 — test_render_audit_report.py 의 고정 단언을 새 문구로 바꾸고 새 테스트 클래스를 더한다.
pr4_t1_pins.py <리포 루트>. 옛 글자가 기대 개수와 다르면 아무것도 쓰지 않고 STOP."""
import os, sys

R = os.path.abspath(sys.argv[1])
P = os.path.join(R, "plugins/plugin-audit/tests/test_render_audit_report.py")

EDITS = [
    ('    # 배너 고유 문구("codex 독립 감사 미실행")를 직접 단언한다.\n',
     '    # 배너 고유 문구("codex 독립 감사를 돌리지 않았다")를 직접 단언한다.\n'),
    ('        self.assertIn("codex 독립 감사 미실행", head)\n',
     '        self.assertIn("codex 독립 감사를 돌리지 않았다", head)\n'),
    ('        self.assertIn("codex 독립 감사 미실행", out)\n',
     '        self.assertIn("codex 독립 감사를 돌리지 않았다", out)\n'),
    ('        self.assertIn("codex 독립 감사 실행-실패", out,\n',
     '        self.assertIn("codex 독립 감사가 돌았지만 결과를 믿을 수 없다", out,\n'),
    ('        self.assertNotIn("미실행", out,\n',
     '        self.assertNotIn("돌리지 않았다", out,\n'),
    ('        self.assertIn("codex d_verdicts 2건 폐기", out,\n',
     '        self.assertIn("codex d_verdicts 2건을 버렸다", out,\n'),
    ('        self.assertIn("0건", md, "OQ1 우측이 비었으면 0건으로 명시돼야 (숨기면 안 됨, §9.5)")\n',
     '        self.assertIn("우: 이 쪽을 받치는 근거는 보고되지 않았다(0건)", md,\n'
     '                      "OQ1 우측이 비었으면 그 사실을 쉬운 문장으로 낸다 (숨기면 안 됨, §9.5 · AC3⑦)")\n'
     '        self.assertNotIn("좌: 이 쪽을 받치는 근거는 보고되지 않았다", md, "근거가 있는 쪽엔 그 문장이 없다 (대조)")\n'),
]

NEW_CLASS = '''

class PlainLanguageReport(unittest.TestCase):
    """쉬운 말 출력 PR 4 — 둘째 줄이 상태 문장이고, 배너가 뜻을 먼저 말하며, 빈 칸은 None 으로 찍히지 않는다."""

    def _data(self, findings, **meta):
        m = {"target": "zz", "date": "2026-10-10", "codex": {"ran": True, "failed": False}}
        m.update(meta)
        return {"meta": m, "findings": findings, "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [], "degraded": []}

    def _f(self, fid, sev, **kw):
        x = {"id": fid, "axis": 1, "title": "제목 " + fid, "severity": sev, "status": "reported",
             "evidence": [{"file": "a.py", "line": 1, "quote": "q"}], "user_harm": "h",
             "recommendation": "r", "counter_argument": "c", "fix_cost": "S", "reference_gap": "none"}
        x.update(kw)
        return x

    def test_second_line_is_status_and_drops_zero_grades(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "CRITICAL"), self._f("A1-2", "IMPORTANT")]))
        self.assertEqual(rc, 0, err)
        self.assertEqual(md.split("\\n")[1], "감사를 마쳤다 — 발견 2개(심각 1 · 중요 1).")

    def test_second_line_counts_every_grade(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "SUGGESTION"), self._f("A1-2", "CRITICAL"),
                                            self._f("A1-3", "IMPORTANT"), self._f("A1-4", "SUGGESTION")]))
        self.assertEqual(rc, 0, err)
        self.assertEqual(md.split("\\n")[1], "감사를 마쳤다 — 발견 4개(심각 1 · 중요 1 · 제안 2).")

    def test_grades_outside_the_three_are_counted(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "HIGH"), self._f("A1-2", "CRITICAL")]))
        self.assertEqual(rc, 0, err)
        self.assertEqual(md.split("\\n")[1], "감사를 마쳤다 — 발견 2개(심각 1 · 기타 1).",
                         "옛 등급(HIGH) 지적이 상태 줄의 합에서 빠지면 개수가 맞지 않는다")

    def test_no_findings_status_keeps_judgment_banner(self):
        rc, md, err, _ = render(self._data([]))
        self.assertEqual(rc, 0, err)
        self.assertEqual(md.split("\\n")[1], "감사를 마쳤다 — 보고된 발견 없음.")
        self.assertIn("⚠ **발견 0건** — 문제가 없어서인지 감사가 실패해서인지는 축 완주 수와 기록(journal)으로 확인하라", md,
                      "판단에 필요한 0 배너는 남는다(S3)")

    def test_banners_say_the_meaning_first(self):
        data = self._data([self._f("A1-1", "IMPORTANT")], codex={"ran": False, "failed": False})
        data["axis_failures"] = [{"axis": 2, "why": "x"}]
        data["degraded"] = [{"what": "기타 결손", "why": "y"}]
        rc, md, err, _ = render(data)
        self.assertEqual(rc, 0, err)
        head = "\\n".join(md.splitlines()[:20])
        self.assertIn("⚠ **축 5/6 완주** — 1개 축은 감사하지 못했다", head)
        self.assertIn("⚠ **codex 독립 감사를 돌리지 않았다** — 다른 모델의 확인이 없다(LD4 모델 다양성 결손)", head)
        self.assertIn("⚠ **빠지거나 약해진 검사 1건**(degraded) — 아래 「결손」 목록에 있다", head)
        self.assertNotIn("축 감사 실패", md, "옛 축 배너가 남았다")

    def test_empty_slots_are_not_none(self):
        data = self._data([self._f("A1-1", "CRITICAL", evidence=[
            {"quote": "Run /init"}, {"file": "a.py", "line": 3}, {"file": "b.py", "quote": "qb"}]),
            {"id": "CX-1", "axis": 3, "title": "t", "severity": "IMPORTANT", "status": "reported",
             "evidence": [{"file": "c.py", "line": 4}]}])
        data["oq_answers"] = [
            {"id": "OQ1", "source": "claude", "reason": "r",
             "left_evidence": [{"file": "a.py", "line": 1, "quote": "q1"}], "right_evidence": []},
            {"id": "OQ2", "source": "claude", "answer": None, "reason": "r2"}]
        rc, md, err, _ = render(data)
        self.assertEqual(rc, 0, err)
        self.assertNotIn("None", md, "빈 칸이 None 으로 찍히지 않는다(S4 · S9)")
        self.assertIn("- (위치 없음) — Run /init\\n", md)
        self.assertIn("- `a.py:3`\\n", md)
        self.assertIn("- `b.py` — qb\\n", md)
        self.assertIn("    - `a.py:1` — q1\\n", md)
        self.assertIn("  - 답: (없음)\\n", md)
        self.assertIn("- 피해: (없음)\\n- 권고: (없음)\\n- 반대근거: (없음)\\n", md, "codex 최소 필드 지적")

    def test_claim_is_kept_when_present(self):
        data = self._data([])
        data["oq_answers"] = [{"id": "OQ1", "source": "claude", "reason": "r",
                               "left_evidence": [{"claim": "좌주장", "file": "a.py", "line": 1, "quote": "q1"}],
                               "right_evidence": [{"claim": "우주장", "file": "b.py", "line": 2, "quote": "q2"}]}]
        rc, md, err, _ = render(data)
        self.assertEqual(rc, 0, err)
        self.assertIn("    - `a.py:1` — 좌주장: q1\\n", md)
        self.assertIn("    - `b.py:2` — 우주장: q2\\n", md)
        self.assertNotIn("보고되지 않았다", md, "양쪽 다 근거가 있으면 빈 쪽 문장이 없다(Review Focus 2)")
'''


def main():
    s = open(P, encoding="utf-8").read()
    bad = [(a, s.count(a)) for a, _ in EDITS if s.count(a) != 1]
    if "class PlainLanguageReport" in s:
        bad.append(("class PlainLanguageReport", 1))
    anchor = '\n\nif __name__ == "__main__":\n'
    if s.count(anchor) != 1:
        bad.append((anchor, s.count(anchor)))
    if bad:
        for a, n in bad:
            print("STOP %d %r" % (n, a[:80]))
        sys.exit(1)
    for a, b in EDITS:
        s = s.replace(a, b)
    s = s.replace(anchor, NEW_CLASS + anchor)
    open(P, "w", encoding="utf-8").write(s)
    print("t1 pins: %d edits + PlainLanguageReport -> %s" % (len(EDITS), os.path.relpath(P, R)))


main()
````

`plugins/plugin-audit/tests/test_plain_audit_text.py`(새 파일 — Task 2 · 4 가 클래스를 더 붙인다):

````python
"""쉬운 말 출력 PR 4 — plugin-audit 이 사람에게 내는 고정 문구.

SKILL 의 codex 건너뜀 줄 · 렌더 배너를 가리키는 인용 · 종료 보고 틀, check-integrity 의 오류 · 요약 줄,
assemble 의 빈칸 채움 사유가 쉬운 말인지 잰다. 부재 단언마다 같은 자리의 양성 짝이 있다.
산문 단언은 줄바꿈을 지운 본문(flat)에서 잰다 — 다시 쓰일 때 문장이 줄을 넘을 수 있다.
"""
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
REPO = PLUGIN.parents[1]
SKILL = PLUGIN / "skills" / "plugin-audit" / "SKILL.md"
RENDER = PLUGIN / "scripts" / "render-audit-report.py"
INTEGRITY = PLUGIN / "scripts" / "check-integrity.sh"
ASSEMBLE = PLUGIN / "scripts" / "assemble-audit-data.py"


def flat(text):
    return " ".join(text.split())


def gate_block(body):
    m = re.search(r"<!--\s*codex-gate:begin[^>]*-->(.*?)<!--\s*codex-gate:end\s*-->", body, re.S)
    if m is None:
        raise AssertionError("codex-gate 블록이 없다")
    return m.group(1)


class SkillTextTest(unittest.TestCase):
    def setUp(self):
        self.body = SKILL.read_text(encoding="utf-8")
        self.flat = flat(self.body)

    def test_codex_skip_line_is_plain_and_keeps_reason_token(self):
        block = gate_block(self.body)
        self.assertIn("[plugin-audit] codex 독립 감사를 건너뛰었다 (reason: ${skip_reason:-unknown})", block)
        self.assertIn("이 감사에는 다른 모델의 확인이 없다. 모델 다양성 없음(degraded).", block)
        self.assertNotIn("co-audit SKIPPED", block, "옛 영어 건너뜀 줄이 남았다")

    def test_pointer_quote_matches_the_render_banner(self):
        quote = "축 완주 수와 기록(journal)으로 확인하라"
        self.assertIn('"' + quote + '" 포인터의', self.flat, "SKILL 이 렌더 배너를 옛 글자로 인용한다")
        self.assertIn(quote, RENDER.read_text(encoding="utf-8"), "인용한 글자가 렌더 배너에 없다")
        self.assertNotIn("journal로 확인하라", self.flat)

    def test_final_report_template(self):
        a = self.flat.index("8. **종료 보고**")
        b = self.flat.index("## kill switch")
        step = self.flat[a:b]
        self.assertIn("첫 줄은 리포트 둘째 줄의 상태 문장을 그대로 쓴다", step)
        self.assertIn("리포트 (`$RUN_DIR/audit.md`)의 절대경로를 보인다 — 사용자가 열어 볼 것은 이것이다.", step)
        self.assertIn("원장(`$RUN_DIR/audit-journal.jsonl`) 경로는 사용자가 물을 때만 보인다.", step)
        self.assertIn("맨 끝에 사용자가 할 일 하나를 쓴다", step)
        self.assertNotIn("의 절대경로를 사용자에게 보인다", step, "세 경로를 모두 보이던 옛 틀이 남았다")


class IntegrityTextTest(unittest.TestCase):
    def run_ci(self, *args):
        with tempfile.TemporaryDirectory() as t:
            out = str(Path(t) / "m.txt")
            argv = [args[0], out] + list(args[1:]) if args else []
            r = subprocess.run(["bash", str(INTEGRITY)] + argv, cwd=str(REPO),
                               capture_output=True, text=True, encoding="utf-8")
            return r.returncode, r.stderr

    def test_missing_target_value(self):
        rc, err = self.run_ci("ld5", "--target")
        self.assertEqual(rc, 2, err)
        self.assertIn("[check-integrity] FATAL: --target 에 값이 없다(--target requires a value)", err)

    def test_missing_extra_path_value(self):
        rc, err = self.run_ci("ld5", "--extra-path")
        self.assertEqual(rc, 2, err)
        self.assertIn("[check-integrity] FATAL: --extra-path 에 값이 없다(--extra-path requires a value)", err)

    def test_unknown_argument(self):
        rc, err = self.run_ci("ld5", "--bogus")
        self.assertEqual(rc, 2, err)
        self.assertIn("[check-integrity] FATAL: 알 수 없는 인자다 — --bogus (unknown argument)", err)

    def test_ld5_needs_target(self):
        rc, err = self.run_ci("ld5")
        self.assertEqual(rc, 2, err)
        self.assertIn("[check-integrity] FATAL: ld5 모드에는 --target <name> 이 필요하다(mode=ld5 requires --target)", err)

    def test_empty_manifest(self):
        rc, err = self.run_ci("ld5", "--target", "zz-no-such-plugin")
        self.assertEqual(rc, 1, err)
        self.assertIn("[check-integrity] FATAL: 해시 목록이 비었다(mode=ld5, manifest is empty) — 열거한 파일이 하나도 없다.", err)

    def test_summary_line(self):
        rc, err = self.run_ci("harness")
        self.assertEqual(rc, 0, err)
        self.assertRegex(err, r"\[check-integrity\] 파일 [1-9][0-9]*개의 해시를 적었다\(mode=harness\) -> ")
        self.assertNotIn("files=", err, "옛 영어 요약 줄이 남았다")


class AssembleTextTest(unittest.TestCase):
    def test_backfill_reasons_are_plain(self):
        meta = {"date": "2026-01-01", "fanout_declared": 30,
                "consent": {"approved": True, "at": "2026-01-01T00:00Z", "fanout": 30},
                "codex": {"ran": True, "version": "1.0"}, "target": "myplugin", "seed_provided": False}
        files = {
            "workflow-return": {"findings": [], "d_verdicts": [], "oq_answers": [], "new_open_questions": [],
                                "axis_failures": [2], "degraded_events": []},
            "codex-side": {"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            "meta": meta,
            "assigned": {"assigned_d": ["D2"], "assigned_oq": ["OQ1"]},
        }
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            argv = [sys.executable, str(ASSEMBLE)]
            for flag, obj in files.items():
                p = d / (flag + ".json")
                p.write_text(json.dumps(obj), encoding="utf-8")
                argv += ["--" + flag, str(p)]
            out = d / "out.json"
            argv += ["--repo-root", str(d), "--no-grounding", "--out", str(out)]
            r = subprocess.run(argv, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            data = json.loads(out.read_text(encoding="utf-8"))
        d2 = [v for v in data["d_verdicts"] if v["id"] == "D2"]
        oq1 = [v for v in data["oq_answers"] if v["id"] == "OQ1"]
        self.assertEqual(d2[0]["reason"], "축 감사가 끝나지 않아 빈칸을 채웠다(backfilled)")
        self.assertEqual(oq1[0]["reason"], "축 감사가 끝나지 않아 빈칸을 채웠다(backfilled — 검증 안 됨)")
        self.assertNotIn("axis incomplete", json.dumps(data, ensure_ascii=False))


if __name__ == "__main__":
    unittest.main()
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t1_pins.py .
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/rt.sh plugins/plugin-audit/tests/test_plain_audit_text.py plugins/plugin-audit/tests/test_render_audit_report.py
```

기대(드라이런): `test_plain_audit_text.py rc=1 fail=10`(전부), `test_render_audit_report.py rc=1 fail=11`. 새 클래스 중 `test_claim_is_kept_when_present` 는 처음부터 통과한다(Review Focus 2 의 양의 짝).

- [ ] **Step 2: 편집**

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t1_edit.py`:

````python
#!/usr/bin/env python3
"""PR 4 Task 1 Step 2–4 — 감사 보고서 · 둘레 문구 · 종료 보고 틀을 쉬운 말로.
pr4_t1_edit.py <리포 루트>. 파일마다 옛 글자가 정확히 한 번인지 먼저 다 확인하고, 하나라도 다르면
아무것도 쓰지 않고 STOP 으로 끝난다."""
import os, sys

R = os.path.abspath(sys.argv[1])
PA = "plugins/plugin-audit/"

RENDER_HELPERS = '''_SEV_KO = (("CRITICAL", "심각"), ("IMPORTANT", "중요"), ("SUGGESTION", "제안"))


def status_line(findings: list) -> str:
    """제목 다음 줄 — 스크립트가 센 상태 문장. 0 인 등급은 빼고, 세 등급 밖(옛 HIGH 등)은 「기타」로 센다."""
    if not findings:
        return "감사를 마쳤다 — 보고된 발견 없음."
    parts = []
    rest = len(findings)
    for key, ko in _SEV_KO:
        n = 0
        for f in findings:
            if f.get("severity") == key:
                n += 1
        rest -= n
        if n:
            parts.append("%s %d" % (ko, n))
    if rest:
        parts.append("기타 %d" % rest)
    return "감사를 마쳤다 — 발견 %d개(%s)." % (len(findings), " · ".join(parts))


def val(x) -> str:
    """빈 칸은 None 대신 「(없음)」으로 쓴다."""
    return "(없음)" if x is None else str(x)


def where(ev: dict) -> str:
    """근거 위치 — 없는 칸을 None 으로 찍지 않는다."""
    file, line = ev.get("file"), ev.get("line")
    if file is None or file == "":
        return "(위치 없음)"
    if line is None:
        return "`%s`" % file
    return "`%s:%s`" % (file, line)


def ev_text(ev: dict, with_claim: bool = False) -> str:
    """근거 한 줄 — 위치, 그리고 있으면 주장과 인용. 없는 칸은 찍지 않는다."""
    body = ""
    if with_claim and ev.get("claim"):
        body = "%s: " % ev.get("claim")
    if ev.get("quote") is not None:
        body += str(ev.get("quote"))
    return where(ev) + (" — " + body if body else "")


def render(data: dict) -> str | None:
'''

EDITS = {
    PA + "scripts/render-audit-report.py": [
        ("def render(data: dict) -> str | None:\n", RENDER_HELPERS),
        ('    lines = [f"# {target} 읽기전용 감사 — " + meta.get("date", "")]\n',
         '    lines = [f"# {target} 읽기전용 감사 — " + meta.get("date", "")]\n'
         '    lines.append(status_line(findings))\n'),
        ('        banners.append(f"⚠ **{6 - len(axis_failures)}/6 축 완주** — {len(axis_failures)}개 축 감사 실패")\n',
         '        banners.append(f"⚠ **축 {6 - len(axis_failures)}/6 완주** — {len(axis_failures)}개 축은 감사하지 못했다")\n'),
        ('        banners.append("⚠ **codex 독립 감사 미실행** — LD4 모델 다양성 결손")\n',
         '        banners.append("⚠ **codex 독립 감사를 돌리지 않았다** — 다른 모델의 확인이 없다(LD4 모델 다양성 결손)")\n'),
        ('        banners.append("⚠ **codex 독립 감사 실행-실패** — 돌았으나 결과를 신뢰할 수 없다 "\n'
         '                       "(LD4 모델 다양성 결손, degraded)")\n',
         '        banners.append("⚠ **codex 독립 감사가 돌았지만 결과를 믿을 수 없다** — 다른 모델의 확인이 없다"\n'
         '                       "(LD4 모델 다양성 결손, degraded)")\n'),
        ('        banners.append(f"⚠ **codex {d.get(\'collection\')} {d.get(\'count\')}건 폐기** — "\n'
         '                       f"{d.get(\'reason\')} (조용히 버리지 않는다)")\n',
         '        banners.append(f"⚠ **codex {d.get(\'collection\')} {d.get(\'count\')}건을 버렸다** — "\n'
         '                       f"형식이 맞지 않았다({d.get(\'reason\')})")\n'),
        ('        banners.append(f"⚠ **degraded {len(degraded)}건** — 아래 결손 목록 참조")\n',
         '        banners.append(f"⚠ **빠지거나 약해진 검사 {len(degraded)}건**(degraded) — 아래 「결손」 목록에 있다")\n'),
        ('        banners.append("⚠ **발견 0건** — 이것이 *깨끗함*인지 *감사 실패*인지 축 완주 수와 journal로 확인하라")\n',
         '        banners.append("⚠ **발견 0건** — 문제가 없어서인지 감사가 실패해서인지는 축 완주 수와 기록(journal)으로 확인하라")\n'),
        ("            lines.append(f\"- `{ev.get('file')}:{ev.get('line')}` — {ev.get('quote')}\")\n",
         '            lines.append(f"- {ev_text(ev)}")\n'),
        ('                            lines.append(f"  - {side_label}: 0건")\n',
         '                            lines.append(f"  - {side_label}: 이 쪽을 받치는 근거는 보고되지 않았다(0건)")\n'),
        ("                                lines.append(f\"    - `{e.get('file')}:{e.get('line')}` — {e.get('claim')}: {e.get('quote')}\")\n",
         '                                lines.append(f"    - {ev_text(e, with_claim=True)}")\n'),
        ("                    lines.append(f\"  - 답: {a.get('answer')}\")\n",
         '                    lines.append(f"  - 답: {val(a.get(\'answer\'))}")\n'),
        ("        lines.append(f\"- 피해: {f.get('user_harm')}\")\n"
         "        lines.append(f\"- 권고: {f.get('recommendation')}\")\n"
         "        lines.append(f\"- 반대근거: {f.get('counter_argument')}\")\n",
         "        lines.append(f\"- 피해: {val(f.get('user_harm'))}\")\n"
         "        lines.append(f\"- 권고: {val(f.get('recommendation'))}\")\n"
         "        lines.append(f\"- 반대근거: {val(f.get('counter_argument'))}\")\n"),
        ("                lines.append(f\"  - 근거: {a.get('reason')}\")\n",
         "                lines.append(f\"  - 근거: {val(a.get('reason'))}\")\n"),
        ("                lines.append(f\"  - 근거: {d.get('reason')}\")\n",
         "                lines.append(f\"  - 근거: {val(d.get('reason'))}\")\n"),
        ("                        lines.append(f\"    - `{e.get('file')}:{e.get('line')}` — {e.get('quote')}\")\n",
         '                        lines.append(f"    - {ev_text(e)}")\n'),
    ],
    PA + "scripts/assemble-audit-data.py": [
        ('"reason": "axis incomplete — backfilled", "source": "claude"})',
         '"reason": "축 감사가 끝나지 않아 빈칸을 채웠다(backfilled)", "source": "claude"})'),
        ('"reason": "axis incomplete — backfilled (unverified)", "source": "claude"})',
         '"reason": "축 감사가 끝나지 않아 빈칸을 채웠다(backfilled — 검증 안 됨)", "source": "claude"})'),
    ],
    PA + "scripts/check-integrity.sh": [
        ('echo "[check-integrity] FATAL: --target requires a value" >&2',
         'echo "[check-integrity] FATAL: --target 에 값이 없다(--target requires a value)" >&2'),
        ('echo "[check-integrity] FATAL: --extra-path requires a value" >&2',
         'echo "[check-integrity] FATAL: --extra-path 에 값이 없다(--extra-path requires a value)" >&2'),
        ('echo "[check-integrity] FATAL: unknown argument: $1" >&2',
         'echo "[check-integrity] FATAL: 알 수 없는 인자다 — ${1} (unknown argument)" >&2'),
        ('echo "[check-integrity] FATAL: mode=ld5 requires --target <name>" >&2',
         'echo "[check-integrity] FATAL: ld5 모드에는 --target <name> 이 필요하다(mode=ld5 requires --target)" >&2'),
        ('echo "[check-integrity] FATAL: manifest is empty (mode=$MODE) — enumeration produced nothing." >&2',
         'echo "[check-integrity] FATAL: 해시 목록이 비었다(mode=${MODE}, manifest is empty) — 열거한 파일이 하나도 없다." >&2'),
        ('echo "[check-integrity] mode=$MODE files=$COUNT -> $OUT" >&2',
         'echo "[check-integrity] 파일 ${COUNT}개의 해시를 적었다(mode=${MODE}) -> ${OUT}" >&2'),
    ],
    PA + "skills/plugin-audit/SKILL.md": [
        ('  echo "[plugin-audit] codex blind co-audit SKIPPED (reason: ${skip_reason:-unknown}) — 이 감사에는 모델 다양성이 없었다 (degraded)." >&2\n',
         '  echo "[plugin-audit] codex 독립 감사를 건너뛰었다 (reason: ${skip_reason:-unknown}) — 이 감사에는 다른 모델의 확인이 없다. 모델 다양성 없음(degraded)." >&2\n'),
        ('   journal로 확인하라" 포인터의 **실체**다',
         '   기록(journal)으로 확인하라" 포인터의 **실체**다'),
        ("8. **종료 보고** — step 5 가 일치하고 step 7 이 GREEN 일 때만 이 종료 보고를 한다. 리포트\n"
         "   (`$RUN_DIR/audit.md`) · 데이터(`$RUN_DIR/audit-data.json`) · 원장\n"
         "   (`$RUN_DIR/audit-journal.jsonl`)의 절대경로를 사용자에게 보인다. 리포트는 한 번 읽는 작업 산출물이다 —\n"
         "   실행 디렉토리는 git-ignore 되고 커밋하지 않는다. 이 감사의 compounding 은 감사가 낳은 수정 커밋과\n"
         "   reviewer persona 편집이 맡는다.\n",
         "8. **종료 보고** — step 5 가 일치하고 step 7 이 GREEN 일 때만 이 종료 보고를 한다. 첫 줄은 리포트 둘째 줄의\n"
         "   상태 문장을 그대로 쓴다(예: 「감사를 마쳤다 — 발견 5개(심각 1 · 중요 3 · 제안 1).」). 이어서 리포트\n"
         "   (`$RUN_DIR/audit.md`)의 절대경로를 보인다 — 사용자가 열어 볼 것은 이것이다. 데이터(`$RUN_DIR/audit-data.json`) ·\n"
         "   원장(`$RUN_DIR/audit-journal.jsonl`) 경로는 사용자가 물을 때만 보인다. 맨 끝에 사용자가 할 일 하나를 쓴다\n"
         "   (예: 「리포트의 심각 발견부터 고칠지 정해 주세요」). 리포트는 한 번 읽는 작업 산출물이다 — 실행 디렉토리는\n"
         "   git-ignore 되고 커밋하지 않는다. 이 감사의 compounding 은 감사가 낳은 수정 커밋과 reviewer persona 편집이 맡는다.\n"),
    ],
}


def main():
    texts, bad = {}, []
    for rel, edits in EDITS.items():
        s = open(os.path.join(R, rel), encoding="utf-8").read()
        texts[rel] = s
        for a, _b in edits:
            if s.count(a) != 1:
                bad.append((rel, s.count(a), a))
    if bad:
        for rel, n, a in bad:
            print("STOP %s %d %r" % (rel, n, a[:90]))
        sys.exit(1)
    for rel, edits in EDITS.items():
        s = texts[rel]
        for a, b in edits:
            s = s.replace(a, b)
        open(os.path.join(R, rel), "w", encoding="utf-8").write(s)
        print("t1 edit: %d edits -> %s" % (len(edits), rel))


main()
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t1_edit.py .
```

기대: `t1 edit: 16 edits -> …render-audit-report.py` · `2 edits -> …assemble-audit-data.py` · `6 edits -> …check-integrity.sh` · `3 edits -> …SKILL.md`.

- [ ] **Step 3: 테스트**

```bash
P=plugins/plugin-audit/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/rt.sh $P/test_plain_audit_text.py $P/test_render_audit_report.py $P/test_validate_audit_data.py \
  $P/test_run_dir_pipeline.py $P/test_ac6_regression.py $P/test_skill_codex_gate.py $P/test_skill_orchestration.py \
  $P/test_assemble_audit_data.py $P/test_check_integrity.py $P/test_untrusted_data_clause.py \
  plugins/quality-gates/tests/test_codex_gate_observation.sh shared/tests/test_plain_language_block.sh \
  shared/tests/test_invocation_surface.sh shared/tests/test_skill_body_no_positional_tokens.sh \
  shared/tests/test_no_new_duplication.sh shared/tests/test_adjudication_wiring.sh shared/tests/test_dispatch_disposition.sh \
  shared/tests/test_python_floor.sh
```

기대: 18개 전부 `rc=0`(드라이런 실측 — `test_codex_gate_observation.sh` 27/27 · `test_invocation_surface.sh` 69/69 · `test_python_floor.sh` 143/143). `test_skill_orchestration.py` 의 INVARIANTS(`"$RUN_DIR/audit.md"` · `audit-journal.jsonl` · 「통과분만 `$RUN_DIR/audit-journal.jsonl`로 저술」 1회)가 새 종료 보고 틀 뒤에도 GREEN 인지 특히 본다.

손으로 하나 더 본다 — AC6 fixture 렌더에 `None` 이 남지 않는다(내용 속 「None required.」 한 줄만 남는다):

```bash
python3 plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/tests/fixtures/ac6_baseline.json --out /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/ac6.md
grep -n None /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/ac6.md; sed -n 2p /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/ac6.md
```

기대: `180:  - 수정: None required. …` 한 줄, 둘째 줄 `감사를 마쳤다 — 발견 2개(심각 1 · 기타 1).`.

- [ ] **Step 4: 커밋**

```bash
git add plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/scripts/assemble-audit-data.py \
  plugins/plugin-audit/scripts/check-integrity.sh plugins/plugin-audit/skills/plugin-audit/SKILL.md \
  plugins/plugin-audit/tests/test_render_audit_report.py plugins/plugin-audit/tests/test_plain_audit_text.py
git commit -m "feat(plugin-audit): 감사 보고서를 쉬운 말로 — 상태 문장, 번호 풀이, 빈 쪽 근거 문장

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat --format= HEAD | tail -1
```

기대: `6 files changed`.

- [ ] **Step 5: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_mut.py . t1 > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/mut-t1.txt; tail -1 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/mut-t1.txt
```

기대: `cells=33 red=33 survived=0 skip=0`(AC3⑦ 의 「빈 쪽 문장 지우기 → RED」 포함). 셀마다 `restored`.

---

## Task 2: 감사자 지적의 `plain:` 칸 (§5 · AC9 · Deferred 7)

설계 표 `0caa2c01#r2.1`(감사자 형식은 agent 파일이 아니라 Workflow 스키마가 정한다)을 닫는다.

**Files:**
- Modify: `plugins/plugin-audit/scripts/audit-workflow.js:83-84 뒤`(`AXIS_SCHEMA` findings 속성에 `plain` — required 에 넣지 않는다)
- Modify: `plugins/plugin-audit/scripts/codex-prompt-preamble.md:25 뒤 · :39 뒤`(최소 필드 문장 · 예시)
- Modify: `plugins/plugin-audit/scripts/render-audit-report.py`(발견 머리 — 옛 86행, Task 1 뒤의 번호는 다르다)
- Modify: `plugins/plugin-audit/tests/test_render_audit_report.py` · `test_codex_audit_to_json.py` · `audit-workflow.test.mjs` · `test_plain_audit_text.py`

**Interfaces:**
- 발견 머리: `### [<sev>] <plain> (<title> · <id>)<badge><deep>` — `plain` 이 비지 않은 문자열일 때(안의 줄바꿈 · 공백은 한 칸으로). 없거나 비면 지금처럼 `### [<sev>] <title> (<id>)<badge><deep>`.
- 넘기는 쪽 셋 — Workflow 병합(`audit-workflow.js:547 · :588` 의 `{ ...f, source }`), `codex_audit_to_json.py:89`(dict 원소를 통째로), assemble(`wf["findings"]` 그대로) — 은 고치지 않고 테스트로 확인만 한다.

- [ ] **Step 1: 실패하는 테스트**

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t2_pins.py`:

````python
#!/usr/bin/env python3
"""PR 4 Task 2 Step 1 — `plain:` 칸의 실패하는 테스트를 네 파일에 더한다.
pr4_t2_pins.py <리포 루트>. 붙일 자리가 기대 개수와 다르거나 이미 붙었으면 아무것도 쓰지 않고 STOP."""
import os, sys

R = os.path.abspath(sys.argv[1])
T = "plugins/plugin-audit/tests/"
MAIN = '\n\nif __name__ == "__main__":\n'

RENDER_TESTS = '''
    def test_plain_first_then_title(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "CRITICAL", plain="설치본에서 이 파일을 읽을 수 없다")]))
        self.assertEqual(rc, 0, err)
        self.assertIn("### [CRITICAL] 설치본에서 이 파일을 읽을 수 없다 (제목 A1-1 · A1-1)\\n", md)

    def test_plain_absent_uses_title(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "CRITICAL")]))
        self.assertEqual(rc, 0, err)
        self.assertIn("### [CRITICAL] 제목 A1-1 (A1-1)\\n", md, "plain 없는 지적은 지금처럼 나온다(버리지 않는다)")

    def test_plain_blank_uses_title(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "CRITICAL", plain="  ")]))
        self.assertEqual(rc, 0, err)
        self.assertIn("### [CRITICAL] 제목 A1-1 (A1-1)\\n", md)

    def test_plain_with_newline_stays_one_heading(self):
        rc, md, err, _ = render(self._data([self._f("A1-1", "CRITICAL", plain="첫 줄\\n둘째 줄")]))
        self.assertEqual(rc, 0, err)
        self.assertIn("### [CRITICAL] 첫 줄 둘째 줄 (제목 A1-1 · A1-1)\\n", md)
'''

CONVERTER_TEST = '''
    def test_plain_passes_through(self):
        payload = {"findings": [{"id": "CX-1", "axis": 3, "title": "t", "severity": "IMPORTANT",
                                 "evidence": [{"file": "a.py", "line": 1}], "plain": "쉬운 한 문장"}],
                   "d_verdicts": [], "oq_answers": [], "new_open_questions": []}
        rc, out, _ = run(event(fenced(payload)))
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out)["findings"][0]["plain"], "쉬운 한 문장")
'''

WF_TESTS = '''
test('AXIS_SCHEMA findings 에 plain 이 선택 속성으로 있다', async () => {
  const { captured } = await runWorkflow(WF, { stubAgent: stubOneFinding() })
  const items = captured['감사'].properties.findings.items
  assert.equal(items.properties.plain.type, 'string')
  assert.ok(items.properties.plain.description.includes('first-time reader'))
  assert.ok(!items.required.includes('plain'), 'plain 은 required 가 아니다 — 칸이 없는 지적도 산다')
})

test('감사자가 쓴 plain 이 Workflow 결과의 finding 에 그대로 남는다', async () => {
  const { result } = await runWorkflow(WF, { stubAgent: stubOneFinding('IMPORTANT', { plain: '쉬운 한 문장' }) })
  const f = result.findings.find((x) => x.id === 'A1-1')
  assert.equal(f.plain, '쉬운 한 문장')
})
'''

PLAIN_TEXT_TESTS = '''

PREAMBLE = PLUGIN / "scripts" / "codex-prompt-preamble.md"
CONVERTER = PLUGIN / "scripts" / "codex_audit_to_json.py"


class PlainFieldTest(unittest.TestCase):
    """`plain:` 칸 — 형식(codex 프롬프트) · 넘기기(변환기 · 조립) · 그리기(렌더)를 끝에서 끝까지."""

    def test_preamble_offers_plain_as_optional(self):
        text = PREAMBLE.read_text(encoding="utf-8")
        self.assertIn("Optional `plain` (string): the same finding in one plain sentence a first-time reader "
                      "understands, no internal IDs.", flat(text))
        self.assertIn('"plain": "one plain sentence for a first-time reader"', text)

    def test_codex_plain_reaches_the_report_heading_first(self):
        payload = {"findings": [
            {"id": "CX-1", "axis": 3, "title": "t1", "severity": "IMPORTANT",
             "evidence": [{"file": "a.py", "line": 1, "quote": "q"}], "plain": "쉬운 한 문장"},
            {"id": "CX-2", "axis": 3, "title": "t2", "severity": "SUGGESTION",
             "evidence": [{"file": "b.py", "line": 2, "quote": "q"}]}],
            "d_verdicts": [], "oq_answers": [], "new_open_questions": []}
        ev = json.dumps({"type": "item.completed", "item": {"type": "agent_message",
                         "text": "```json\\n" + json.dumps(payload) + "\\n```"}}) + "\\n"
        conv = subprocess.run([sys.executable, str(CONVERTER)], input=ev, capture_output=True, text=True)
        self.assertEqual(conv.returncode, 0, conv.stderr)
        found = json.loads(conv.stdout)["findings"]
        wf_findings = []
        for f in found:
            g = dict(f)
            g.update({"source": "codex", "status": "reported"})
            wf_findings.append(g)
        meta = {"date": "2026-01-01", "fanout_declared": 30,
                "consent": {"approved": True, "at": "2026-01-01T00:00Z", "fanout": 30},
                "codex": {"ran": True, "version": "1.0"}, "target": "myplugin", "seed_provided": False}
        files = {
            "workflow-return": {"findings": wf_findings, "d_verdicts": [], "oq_answers": [],
                                "new_open_questions": [], "axis_failures": [], "degraded_events": []},
            "codex-side": {"d_verdicts": [], "oq_answers": [], "new_open_questions": []},
            "meta": meta, "assigned": {"assigned_d": [], "assigned_oq": []},
        }
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            argv = [sys.executable, str(ASSEMBLE)]
            for flag, obj in files.items():
                p = d / (flag + ".json")
                p.write_text(json.dumps(obj, ensure_ascii=False), encoding="utf-8")
                argv += ["--" + flag, str(p)]
            data_p, md_p = d / "audit-data.json", d / "audit.md"
            argv += ["--repo-root", str(d), "--no-grounding", "--out", str(data_p)]
            r = subprocess.run(argv, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            r = subprocess.run([sys.executable, str(RENDER), str(data_p), "--out", str(md_p)],
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            md = md_p.read_text(encoding="utf-8")
        self.assertIn("### [IMPORTANT] 쉬운 한 문장 (t1 · CX-1)\\n", md)
        self.assertIn("### [SUGGESTION] t2 (CX-2)\\n", md, "plain 없는 codex 지적도 버려지지 않고 나온다")
        self.assertNotIn("None", md, "codex 의 최소 필드 지적에도 None 이 찍히지 않는다")
'''

PLAN = [
    (T + "test_render_audit_report.py", MAIN, RENDER_TESTS, "test_plain_first_then_title"),
    (T + "test_codex_audit_to_json.py", MAIN, CONVERTER_TEST, "test_plain_passes_through"),
    (T + "test_plain_audit_text.py", MAIN, PLAIN_TEXT_TESTS, "class PlainFieldTest"),
]


def main():
    bad, texts = [], {}
    for rel, anchor, _new, marker in PLAN:
        s = open(os.path.join(R, rel), encoding="utf-8").read()
        texts[rel] = s
        if s.count(anchor) != 1 or marker in s:
            bad.append((rel, s.count(anchor), marker in s))
    wf = os.path.join(R, T + "audit-workflow.test.mjs")
    ws = open(wf, encoding="utf-8").read()
    if "AXIS_SCHEMA findings 에 plain" in ws:
        bad.append((T + "audit-workflow.test.mjs", "plain 테스트가 이미 있다", True))
    if "class PlainLanguageReport" not in texts[T + "test_render_audit_report.py"]:
        bad.append((T + "test_render_audit_report.py", "PlainLanguageReport 없음(Task 1 먼저)", False))
    if bad:
        for b in bad:
            print("STOP", b)
        sys.exit(1)
    for rel, anchor, new, _m in PLAN:
        s = texts[rel].replace(anchor, new.rstrip("\n") + "\n" + anchor, 1)
        open(os.path.join(R, rel), "w", encoding="utf-8").write(s)
        print("t2 pins ->", rel)
    open(wf, "w", encoding="utf-8").write(ws.rstrip("\n") + "\n" + WF_TESTS)
    print("t2 pins ->", T + "audit-workflow.test.mjs")


main()
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t2_pins.py .
P=plugins/plugin-audit/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/rt.sh $P/test_render_audit_report.py $P/test_codex_audit_to_json.py $P/test_plain_audit_text.py $P/audit-workflow.test.mjs
```

기대(드라이런): render `fail=2`(plain 먼저 · 줄바꿈), converter `rc=0`(넘기기는 이미 된다 — 확인용), plain_audit_text `fail=2`(preamble · 끝에서 끝), node `rc=1`(`not ok` 1 — 스키마. Workflow 결과에 남는지 재는 둘째 테스트는 처음부터 통과한다).

- [ ] **Step 2: 편집**

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t2_edit.py`:

````python
#!/usr/bin/env python3
"""PR 4 Task 2 Step 2–3 — 감사자 지적의 `plain:` 칸: 형식 둘(Workflow 스키마 · codex 프롬프트)과 그리기(렌더).
pr4_t2_edit.py <리포 루트>. 옛 글자가 정확히 한 번이 아니면 아무것도 쓰지 않고 STOP."""
import os, sys

R = os.path.abspath(sys.argv[1])
PA = "plugins/plugin-audit/"

EDITS = {
    PA + "scripts/audit-workflow.js": [
        ("          oq_ref: { type: 'string' },\n"
         "          steelman_condition: { type: 'string', enum: ['a', 'b', 'c', 'd', 'none', 'pending'] },\n",
         "          oq_ref: { type: 'string' },\n"
         "          steelman_condition: { type: 'string', enum: ['a', 'b', 'c', 'd', 'none', 'pending'] },\n"
         "          plain: { type: 'string', description: 'Optional. The same finding in one plain sentence a first-time reader understands — no internal IDs.' },\n"),
    ],
    PA + "scripts/codex-prompt-preamble.md": [
        ("    `IMPORTANT`, `SUGGESTION`), `evidence` (array of `{file, line}` objects; `quote` optional).\n",
         "    `IMPORTANT`, `SUGGESTION`), `evidence` (array of `{file, line}` objects; `quote` optional).\n"
         "    Optional `plain` (string): the same finding in one plain sentence a first-time reader understands,\n"
         "    no internal IDs.\n"),
        ('    {"id": "CX-1", "axis": 3, "title": "example finding title", "severity": "IMPORTANT",\n',
         '    {"id": "CX-1", "axis": 3, "title": "example finding title", "severity": "IMPORTANT",\n'
         '     "plain": "one plain sentence for a first-time reader",\n'),
    ],
    PA + "scripts/render-audit-report.py": [
        ("        lines.append(f\"### [{f.get('severity')}] {f.get('title')} ({f.get('id')}){badge}{deep_label(f)}\")\n",
         "        plain = f.get(\"plain\")\n"
         "        if isinstance(plain, str) and plain.strip():\n"
         "            head = f\"{' '.join(plain.split())} ({f.get('title')} · {f.get('id')})\"\n"
         "        else:\n"
         "            head = f\"{f.get('title')} ({f.get('id')})\"\n"
         "        lines.append(f\"### [{f.get('severity')}] {head}{badge}{deep_label(f)}\")\n"),
    ],
}


def main():
    texts, bad = {}, []
    for rel, edits in EDITS.items():
        s = open(os.path.join(R, rel), encoding="utf-8").read()
        texts[rel] = s
        for a, _b in edits:
            if s.count(a) != 1:
                bad.append((rel, s.count(a), a))
    if bad:
        for rel, n, a in bad:
            print("STOP %s %d %r" % (rel, n, a[:90]))
        sys.exit(1)
    for rel, edits in EDITS.items():
        s = texts[rel]
        for a, b in edits:
            s = s.replace(a, b)
        open(os.path.join(R, rel), "w", encoding="utf-8").write(s)
        print("t2 edit: %d edits -> %s" % (len(edits), rel))


main()
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t2_edit.py .
```

`test_preamble_schema_parity.py` 는 preamble 의 예시를 추출기에 넣어 `codex_failed: False` 를 잰다 — 모르는 키는 통과한다(드라이런 확인).

- [ ] **Step 3: 테스트**

```bash
P=plugins/plugin-audit/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/rt.sh $P/test_render_audit_report.py $P/test_codex_audit_to_json.py $P/test_plain_audit_text.py $P/audit-workflow.test.mjs \
  $P/smoke-workflow.test.mjs $P/test_preamble_schema_parity.py $P/test_severity_mapping.py $P/test_check_law2.py \
  $P/test_run_audit_codex_reviewer.py $P/test_validate_audit_data.py $P/test_run_dir_pipeline.py $P/test_untrusted_data_clause.py \
  $P/test_agents_generic.py $P/test_check_no_verdict_injection.py shared/tests/test_dispatch_disposition.sh shared/tests/test_agent_input_slots.sh
```

기대: 16개 전부 `rc=0`.

- [ ] **Step 4: 커밋**

```bash
git add plugins/plugin-audit/scripts/audit-workflow.js plugins/plugin-audit/scripts/codex-prompt-preamble.md \
  plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/tests/test_render_audit_report.py \
  plugins/plugin-audit/tests/test_codex_audit_to_json.py plugins/plugin-audit/tests/test_plain_audit_text.py \
  plugins/plugin-audit/tests/audit-workflow.test.mjs
git commit -m "feat(plugin-audit): 감사자 지적에 사람이 읽을 한 문장(plain) 칸, 보고서에 먼저

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat --format= HEAD | tail -1
```

기대: `7 files changed`.

- [ ] **Step 5: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_mut.py . t2 > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/mut-t2.txt; tail -1 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/mut-t2.txt
```

기대: `cells=12 red=12 survived=0 skip=0` — AC9 의 「렌더가 `plain:` 없는 finding 을 건너뛰게 → RED」와, 넘기는 쪽 둘(Workflow 병합 · 변환기)이 `plain` 을 버리게 하는 셀이 포함된다.

---

## Task 3: project-init 훅 경고와 초기화 보고 (S6 · S13)

**Files:**
- Modify: `plugins/project-init/hooks/post-tool-use.py:130-134 · :143 · :149 · :153-154 · :192-195`(사람 채널만 — `:144-147` 의 `cmd` 와 정규식은 그대로)
- Modify: `plugins/project-init/skills/project-init/SKILL.md:252 · :266-267`
- Modify: `plugins/project-init/tests/test_post_tool_use.py`
- Create: `plugins/project-init/tests/test_plain_init_text.py`

- [ ] **Step 1: 실패하는 테스트**

사람 채널 단언 갱신(PR 본문 표 — AC13):

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_post_tool_use.py:90` | `"skipping"` | `"브랜치 이름 검사를 건너뛴다"` | 패턴이 없으면 검사를 건너뛴다고 알린다(`fail-open` 은 그대로 `"fail-open"` 으로 잰다) |
| `:170` | `assertIn("does not follow naming convention", out)` — stdout 원문 | `assertIn("이름 규칙에 맞지 않는다", json.loads(out).get("systemMessage", ""))` | 비-UTF-8 locale 에서도 브랜치 위반을 알린다(S13 — 한글은 JSON 에서 `\uXXXX`) |
| `:263` · `:372`(사람 채널) | `"Allowed prefixes: feature, fix, release, hotfix"` | `"허용 접두어: feature, fix, release, hotfix"` | 허용 접두어를 보인다 |
| `:276` | `"docs/git-workflow/branch-strategy.md"` | `"허용 접두어는 docs/git-workflow/branch-strategy.md 에 있다."` | 규칙 문서를 가리킨다(경로 그대로) |
| `:313` | `assertNotIn("naming convention", msg)` | `assertNotIn("이름 규칙에 맞지 않는다", msg)` | 맞는 브랜치엔 브랜치 경고가 없다(옛 영어로 두면 공허 — 양성 짝 `:370`) |
| `:370` · `:371` | `"does not follow naming convention"` · `"Expected pattern:"` | `"이름 규칙에 맞지 않는다"` · `"기대하는 형식:"` + `assertNotIn("does not follow", sm)` | 브랜치 이름 위반 · 패턴을 보인다 |
| `:390` | `"Suggested: feat: add thing"` | `"제안: feat: add thing"` + 첫 줄 · 형식 · type 줄 단언 셋 + `assertNotIn("Suggested:", sm)` | 고친 메시지를 제안한다 |
| `:191` 뒤 | — | `test_korean_description_passes` | 한국어 설명이 통과한다(Review Focus 4) |

모델 채널 단언(`:266` · `:267` · `:354` · `:355` 의 `"git branch -m"` · `"Allowed prefixes: …"`, `:268-269` · `:357-359` 의 부재 단언, `:392` 의 `NotIn("Conventional Commits")`)은 그대로 둔다. `"Conventional Commits"`(`:144` · `:196` · `:296` · `:314` · `:389`) · `"fail-open"`(`:89` …) 은 새 문구가 그대로 담는다.

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t3_pins.py`:

````python
#!/usr/bin/env python3
"""PR 4 Task 3 Step 1 — test_post_tool_use.py 의 사람 채널 단언을 새 문구로, 새 단언을 더한다.
pr4_t3_pins.py <리포 루트>. 옛 글자가 기대 개수와 다르면 아무것도 쓰지 않고 STOP."""
import os, sys

R = os.path.abspath(sys.argv[1])
P = os.path.join(R, "plugins/project-init/tests/test_post_tool_use.py")

EDITS = [
    ('        self.assertIn("skipping", msg)\n',
     '        self.assertIn("브랜치 이름 검사를 건너뛴다", msg)\n'),
    # 이 단언은 훅의 stdout(JSON) 원문을 본다 — json.dumps 가 한글을 \\uXXXX 로 내므로 풀어서 잰다.
    ('        self.assertIn("does not follow naming convention", out)\n',
     '        self.assertIn("이름 규칙에 맞지 않는다", json.loads(out).get("systemMessage", ""))\n'),
    ('        self.assertIn("Allowed prefixes: feature, fix, release, hotfix", msg)  # body-unique teeth (not header-satisfiable)\n',
     '        self.assertIn("허용 접두어: feature, fix, release, hotfix", msg)  # body-unique teeth (not header-satisfiable)\n'),
    ('        self.assertIn("docs/git-workflow/branch-strategy.md", msg)\n',
     '        self.assertIn("허용 접두어는 docs/git-workflow/branch-strategy.md 에 있다.", msg)\n'),
    ('            self.assertNotIn("naming convention", msg)  # branch OK -> no branch warning\n',
     '            self.assertNotIn("이름 규칙에 맞지 않는다", msg)  # branch OK -> no branch warning (양성 짝: test_branch_fact_and_hint_stay_human)\n'),
    ('            self.assertIn("does not follow naming convention", sm)\n'
     '            self.assertIn("Expected pattern:", sm)\n'
     '            self.assertIn("Allowed prefixes: feature, fix, release, hotfix", sm)\n',
     '            self.assertIn("이름 규칙에 맞지 않는다", sm)\n'
     '            self.assertIn("기대하는 형식:", sm)\n'
     '            self.assertIn("허용 접두어: feature, fix, release, hotfix", sm)\n'
     '            self.assertNotIn("does not follow", sm, "옛 영어 경고가 사람 채널에 남았다")\n'),
    ('            self.assertIn("Suggested: feat: add thing", sm)\n',
     '            self.assertIn("project-init: 커밋 메시지가 Conventional Commits 형식이 아니다.", sm)\n'
     '            self.assertIn("형식: <type>(<scope>): <설명>", sm)\n'
     '            self.assertIn("type: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert", sm)\n'
     '            self.assertIn("제안: feat: add thing", sm)\n'
     '            self.assertNotIn("Suggested:", sm, "옛 영어 제안 줄이 남았다")\n'),
    ('        self.assertIsNone(_hook.validate_commit(\'git commit -m "feat: add thing"\'))\n',
     '        self.assertIsNone(_hook.validate_commit(\'git commit -m "feat: add thing"\'))\n'
     '\n'
     '    def test_korean_description_passes(self):\n'
     '        """커밋 설명이 한국어인 레포(devbrew CLAUDE.md 규칙) — 정규식은 type 만 본다."""\n'
     '        self.assertIsNone(_hook.validate_commit(\'git commit -m "fix(qg): 범위 경고를 쉬운 말로"\'))\n'),
]


def main():
    s = open(P, encoding="utf-8").read()
    bad = [(s.count(a), a) for a, _ in EDITS if s.count(a) != 1]
    if "test_korean_description_passes" in s:
        bad.append((1, "test_korean_description_passes"))
    if bad:
        for n, a in bad:
            print("STOP %d %r" % (n, a[:90]))
        sys.exit(1)
    for a, b in EDITS:
        s = s.replace(a, b)
    open(P, "w", encoding="utf-8").write(s)
    print("t3 pins: %d edits -> %s" % (len(EDITS), os.path.relpath(P, R)))


main()
````

`plugins/project-init/tests/test_plain_init_text.py`(새 파일 — Task 4 가 클래스를 더 붙인다):

````python
"""쉬운 말 출력 PR 4 — project-init 이 사람에게 내는 보고 틀.

초기화 보고(SKILL Step 5)의 첫 줄은 무엇을 했는지 한 문장이고 맨 끝 줄은 사용자가 할 일 하나다.
부재 단언마다 같은 블록의 양성 짝이 있다.
"""
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
SKILL = PLUGIN / "skills" / "project-init" / "SKILL.md"


def report_block(text):
    lines = text.splitlines()
    heads = [i for i, ln in enumerate(lines) if ln.startswith("> 생성/업데이트된 파일:")]
    if len(heads) != 1:
        raise AssertionError("보고 블록 앵커가 유일하지 않다: %d건" % len(heads))
    start = end = heads[0]
    while start > 0 and lines[start - 1].startswith(">"):
        start -= 1
    while end < len(lines) and lines[end].startswith(">"):
        end += 1
    return lines[start:end]


class CompletionReportTest(unittest.TestCase):
    def setUp(self):
        self.block = report_block(SKILL.read_text(encoding="utf-8"))

    def test_first_line_says_what_was_done(self):
        self.assertEqual(self.block[0], "> **{strategy 이름}** 전략으로 git workflow 를 초기화했다.")

    def test_last_line_is_one_next_action(self):
        self.assertEqual(
            self.block[-1],
            "> 다음 할 일: 새 브랜치를 하나 만들어 보라 — `git checkout -b feature/<이름>` 이면 훅이 이름을 바로 확인한다.")
        self.assertEqual(sum(1 for ln in self.block if ln.startswith("> 다음 할 일:")), 1)

    def test_old_lines_are_gone(self):
        joined = "\n".join(self.block)
        self.assertTrue(joined, "보고 블록이 비었다 — 아래 부재 단언이 공허하다")
        self.assertNotIn("초기화 완료", joined)
        self.assertNotIn("16+ 벤더", joined)
        self.assertNotIn("/commit-push-pr", joined)


if __name__ == "__main__":
    unittest.main()
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t3_pins.py .
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/rt.sh plugins/project-init/tests/test_post_tool_use.py plugins/project-init/tests/test_plain_init_text.py
```

기대(드라이런): `test_post_tool_use.py rc=1 fail=6`, `test_plain_init_text.py rc=1 fail=3`.

- [ ] **Step 2: 편집**

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t3_edit.py`:

````python
#!/usr/bin/env python3
"""PR 4 Task 3 Step 2–3 — project-init 훅의 사람 채널(systemMessage)과 초기화 보고 틀을 쉬운 한국어로.
모델 채널(additionalContext)과 정규식은 그대로다. pr4_t3_edit.py <리포 루트>. 옛 글자가 정확히 한 번이
아니면 아무것도 쓰지 않고 STOP."""
import os, sys

R = os.path.abspath(sys.argv[1])
PI = "plugins/project-init/"

EDITS = {
    PI + "hooks/post-tool-use.py": [
        ('            "project-init: no valid branch-naming pattern found in "\n'
         '            "docs/git-workflow/branch-strategy.md — skipping branch-name "\n'
         '            "validation (fail-open).",\n',
         '            "project-init: docs/git-workflow/branch-strategy.md 에서 쓸 수 있는 브랜치 이름 규칙을 "\n'
         '            "찾지 못했다 — 브랜치 이름 검사를 건너뛴다(fail-open).",\n'),
        ('        hint = f"Allowed prefixes: {\', \'.join(prefixes)}"\n',
         '        hint = f"허용 접두어: {\', \'.join(prefixes)}"\n'),
        ('        hint = "See docs/git-workflow/branch-strategy.md for allowed prefixes."\n',
         '        hint = "허용 접두어는 docs/git-workflow/branch-strategy.md 에 있다."\n'),
        ("        f'project-init: Branch \"{branch_name}\" does not follow naming convention.',\n"
         '        f"Expected pattern: {pattern.pattern}",\n',
         "        f'project-init: 브랜치 이름이 이름 규칙에 맞지 않는다 — \"{branch_name}\".',\n"
         '        f"기대하는 형식: {pattern.pattern}",\n'),
        ('        f"project-init: Commit message does not follow Conventional Commits format.\\n"\n'
         '        f"Expected: <type>(<scope>): <description>\\n"\n'
         '        f"Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\\n"\n'
         '        f"Suggested: {suggested_type}: {first_line}",\n',
         '        f"project-init: 커밋 메시지가 Conventional Commits 형식이 아니다.\\n"\n'
         '        f"형식: <type>(<scope>): <설명>\\n"\n'
         '        f"type: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert\\n"\n'
         '        f"제안: {suggested_type}: {first_line}",\n'),
    ],
    PI + "skills/project-init/SKILL.md": [
        ("> **{strategy 이름}** 전략으로 git workflow 초기화 완료.\n",
         "> **{strategy 이름}** 전략으로 git workflow 를 초기화했다.\n"),
        ("> AGENTS.md primary 패턴으로 OpenAI Codex, Cursor, Aider 등 16+ 벤더가 동일 파일을 인식합니다.\n"
         "> 간결한 git 작업을 위해 `/commit` 또는 `/commit-push-pr` (commit-commands 플러그인) 사용.\n",
         "> 다음 할 일: 새 브랜치를 하나 만들어 보라 — `git checkout -b feature/<이름>` 이면 훅이 이름을 바로 확인한다.\n"),
    ],
}


def main():
    texts, bad = {}, []
    for rel, edits in EDITS.items():
        s = open(os.path.join(R, rel), encoding="utf-8").read()
        texts[rel] = s
        for a, _b in edits:
            if s.count(a) != 1:
                bad.append((rel, s.count(a), a))
    if bad:
        for rel, n, a in bad:
            print("STOP %s %d %r" % (rel, n, a[:90]))
        sys.exit(1)
    for rel, edits in EDITS.items():
        s = texts[rel]
        for a, b in edits:
            s = s.replace(a, b)
        open(os.path.join(R, rel), "w", encoding="utf-8").write(s)
        print("t3 edit: %d edits -> %s" % (len(edits), rel))


main()
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t3_edit.py .
```

브랜치 위반 줄은 변수 뒤에 조사를 붙이지 않는다(「브랜치 이름이 이름 규칙에 맞지 않는다 — "<이름>".」) — 이름이 받침으로 끝나는지 알 수 없다. 보고 틀의 새 끝 줄은 「훅」을 담지만 「검증」을 담지 않아 `test_command_contract.py` 의 주장 줄(「hook/훅」과 「검증」을 함께 담은 줄 1개 이하)에 들지 않는다.

- [ ] **Step 3: 테스트 · 불변 확인**

```bash
I=plugins/project-init/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/rt.sh $I/test_post_tool_use.py $I/test_plain_init_text.py $I/test_command_contract.py \
  $I/test_branch_strategy_rebase_clause.sh $I/test_no_write_matcher_hooks.sh shared/tests/test_python_floor.sh \
  shared/tests/test_invocation_surface.sh shared/tests/test_plain_language_block.sh shared/tests/test_no_new_duplication.sh \
  shared/tests/test_skill_body_no_positional_tokens.sh
git diff -U0 plugins/project-init/hooks/post-tool-use.py | grep -E '^[-+].*(re\.compile|```regex|_RE =|_PATTERN =)' || echo "정규식 불변"
git diff -U0 plugins/project-init/hooks/post-tool-use.py | grep -E '^[-+].*(Rename the branch|use whichever fits)' || echo "모델 채널 불변"
```

기대: 10개 전부 `rc=0`, `정규식 불변`, `모델 채널 불변`.

- [ ] **Step 4: 커밋**

```bash
git add plugins/project-init/hooks/post-tool-use.py plugins/project-init/skills/project-init/SKILL.md \
  plugins/project-init/tests/test_post_tool_use.py plugins/project-init/tests/test_plain_init_text.py
git commit -m "feat(project-init): 훅 경고와 초기화 보고를 쉬운 한국어로

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat --format= HEAD | tail -1
```

기대: `4 files changed`.

- [ ] **Step 5: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_mut.py . t3 > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/mut-t3.txt; tail -1 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/mut-t3.txt
```

기대: `cells=15 red=15 survived=0 skip=0` — 「모델 채널을 한국어로(바뀌면 안 된다)」 셀이 모델 채널 락의 이빨을 잰다.

---

## Task 4: 소개 문구 같음 락 · README · 버전 (§8 · AC10 · S7 · S8 · S11 · S14)

**Files:**
- Create: `shared/tests/test_plugin_description_parity.sh`(100755)
- Modify: `plugins/plugin-audit/.claude-plugin/plugin.json` · `plugins/project-init/.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json`(두 항목)
- Modify: `plugins/plugin-audit/README.md:3-5 · :26` · `plugins/project-init/README.md:3 · :96`
- Modify: 두 CHANGELOG(맨 위에 새 항목)
- Modify: `plugins/plugin-audit/tests/test_plain_audit_text.py` · `plugins/project-init/tests/test_plain_init_text.py`(README 클래스)

README 를 고정한 락(fb9c9bb4 재도출 — 이 계획의 편집이 지켜야 할 것): `shared/tests/test_python_floor.sh:857-864 · :875-883`(project-init README 에 「2026-10 이후에도 패치를 받는 버전 중 최빈」 · 바닥 `3.12` · `EOL` · ERE `Python 3\.12\+` 가 있고, plugin-audit README 에는 `Python 3\.12\+` 가 없다) · `plugins/plugin-audit/tests/test_skill_orchestration.py:93-99`(README 에 `.claude/plugin-audit/` 가 있고 `docs/audits` 가 없다) · `check-staleness.py:424-476`(project-init `## 설치된 Hook` 절의 굵은 불릿 수 = `hooks.json` 1개) · `check-shape-completeness.py:49` · `shared/entry/check_invocation_surface.py` 축 I(살아 있는 표면에 옛 이름 `auditing-plugins` · `commands/…md` 없음). 이 계획은 그 자리를 건드리지 않는다.

- [ ] **Step 1: 실패하는 락과 README 단언**

`shared/tests/test_plugin_description_parity.sh`:

````bash
#!/usr/bin/env bash
# guards: plugins/*/.claude-plugin/plugin.json .claude-plugin/marketplace.json
#
# 쉬운 말 출력 설계 AC10 — 플러그인마다 plugin.json 과 마켓플레이스의 소개 문구가 글자까지 같다.
# 술어는 plugins/plugin-audit/scripts/check-staleness.py 의 scan_description_drift 와 같다
# (같은 name 의 description.strip() 등식). 대상은 열거하지 않고 디스크의 plugin.json 에서 도출한다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$ROOT" ls-files -- 'plugins/*/.claude-plugin/plugin.json' .claude-plugin/marketplace.json
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
RES="$(mktemp -t desc-parity-XXXXXX)" || exit 1
[ -n "$RES" ] && [ -f "$RES" ] || exit 1
trap 'rm -f "$RES"' EXIT
python3 - "$ROOT" > "$RES" <<'PY'
import io, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
mp = json.load(io.open(str(root / ".claude-plugin/marketplace.json"), encoding="utf-8"))
by_name = {}
for p in mp.get("plugins", []):
    by_name[p.get("name")] = p
pjs = sorted(root.glob("plugins/*/.claude-plugin/plugin.json"))
print("count %d" % len(pjs))
seen = set()
for pj in pjs:
    d = json.load(io.open(str(pj), encoding="utf-8"))
    name = d.get("name")
    seen.add(name)
    m = by_name.get(name)
    if m is None:
        print("no %s: 마켓플레이스에 항목이 없다" % name)
    elif not (d.get("description") or "").strip():
        print("no %s: plugin.json 에 소개 문구가 없다" % name)
    elif (d.get("description") or "").strip() != (m.get("description") or "").strip():
        print("no %s: plugin.json 과 마켓플레이스 소개 문구가 다르다" % name)
    else:
        print("ok %s: 소개 문구가 글자까지 같다" % name)
for name in sorted(n for n in by_name if n not in seen):
    print("no %s: 마켓플레이스 항목에 맞는 plugin.json 이 없다" % name)
PY
n="$(sed -n 's/^count //p' "$RES")"
[ "${n:-0}" -ge 1 ] && ok "대상 plugin.json ${n}개를 디스크에서 도출했다" || no "대상 plugin.json 이 0개다 — 공허한 통과"
while IFS= read -r line; do
  case "$line" in
    "ok "*) ok "${line#ok }" ;;
    "no "*) no "${line#no }" ;;
  esac
done < "$RES"
finish
````

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t4_edit.py`(단계 `tests` 가 README 단언을, `docs` 가 나머지를 쓴다):

````python
#!/usr/bin/env python3
"""PR 4 Task 4 — 소개 문구 · README · 버전 · CHANGELOG, 그리고 README 문구 락.
pr4_t4_edit.py <리포 루트> <단계>   단계: tests(README 락만 더한다 — RED 확인용) | docs(나머지 편집)
옛 글자가 정확히 한 번이 아니면 아무것도 쓰지 않고 STOP. 버전 · 날짜는 머지 직전에 아래 상수를 다시 정한다."""
import os, sys

R = os.path.abspath(sys.argv[1])
STAGE = sys.argv[2]
PA, PI = "plugins/plugin-audit/", "plugins/project-init/"
PA_VER_OLD, PA_VER_NEW = "1.0.1", "1.1.0"
PI_VER_OLD, PI_VER_NEW = "5.0.0", "5.0.1"
DATE = "2026-10-10"
MAIN = '\n\nif __name__ == "__main__":\n'

PA_DESC_OLD = ("Read-only, evidence-based multi-agent audit of an arbitrary devbrew plugin: 6-axis discovery → "
               "adversarial refutation → blind codex co-audit → prioritized gap report. Invoke via /plugin-audit "
               "<target> [--seed <path>].")
PA_DESC_NEW = ("Audits one devbrew plugin without changing it: six read-only reviewers look for gaps, a second pass "
               "tries to disprove each one, an optional codex audit adds another model's view, and you get a ranked "
               "report of the gaps that hold up. Run /plugin-audit:plugin-audit <name>.")
PI_DESC_PJ_OLD = ("Initialize git-workflow rules and a project charter via a fact-routing interview, then generate "
                  "agent-readable AGENTS.md/CLAUDE.md docs with hook-based validation of branches and commits.")
PI_DESC_MP_OLD = ("Initialize git-workflow rules and a project charter via a fact-routing interview, then generate "
                  "agent-readable AGENTS.md/CLAUDE.md docs with hook-based validation of branches, commits, doc "
                  "conventions, and charter integrity.")
PI_DESC_NEW = ("Sets up git workflow rules and a project charter through a short interview, writes them as "
               "AGENTS.md/CLAUDE.md docs that agents read, and adds a hook that checks branch names and commit messages.")

PA_LEAD_OLD = ("임의의 devbrew 플러그인을 **읽기전용·증거기반·multi-agent**로 감사한다. 6축 병렬 발견 →\n"
               "적대적 반박(기본 verdict=refuted) → blind codex 독립 co-audit → 우선순위 갭 리포트.\n"
               "1차 산출물은 코드가 아니라 **증거로 뒷받침된 우선순위 갭 목록**이다.\n")
PA_LEAD_NEW = ("devbrew 플러그인 하나를 고치지 않고 읽기만 해서 감사한다. 읽기 전용 리뷰어 여섯이 축마다 빈틈을 찾고,\n"
               "다른 리뷰어가 그 지적을 하나씩 반박해 보며, codex(다른 모델)가 있으면 같은 대상을 따로 감사한다. 결과는\n"
               "증거가 붙은 빈틈 목록이고, 심각한 것부터 정렬된다.\n")
PA_DONE_OLD = "감사가 끝나면 세 파일의 절대경로를 보고한다. 같은 날 같은 대상을 다시 감사하면 `-2` 로 새로 만든다.\n"
PA_DONE_NEW = ("감사가 끝나면 상태 한 줄과 리포트(`audit.md`) 경로를 보고한다 — 데이터 · 원장 경로는 물으면 보인다.\n"
               "같은 날 같은 대상을 다시 감사하면 `-2` 로 새로 만든다.\n")
PI_LEAD_OLD = ("Claude Code용 git workflow 초기화 플러그인. 어떤 프로젝트에든 branching strategy, commit conventions, "
               "PR process 룰을 생성한다.\n")
PI_LEAD_NEW = ("프로젝트의 git 작업 규칙(브랜치 이름 · 커밋 메시지 · PR 절차)과 프로젝트 헌장을 짧은 대화로 만들어 준다.\n"
               "결과는 에이전트가 읽는 `AGENTS.md`(그리고 그것을 가리키는 `CLAUDE.md`)와 `docs/` 문서다. 그 뒤로는 훅 하나가\n"
               "`Bash` 호출에서 브랜치 이름과 커밋 메시지를 확인해 알려 준다(막지는 않는다).\n")

PA_LOG = """## [%s] — %s

### Added

- 감사자 지적의 `plain:` 칸(선택) — 처음 보는 사람이 읽을 쉬운 한 문장. Workflow 출력 스키마(`AXIS_SCHEMA`)와 codex 프롬프트(`scripts/codex-prompt-preamble.md`)에 형식이 있고, 보고서가 그 문장을 발견 머리에 먼저 쓴다. 칸이 없거나 비면 지금처럼 제목이 나온다.

### Changed

- 보고서 둘째 줄이 스크립트가 센 상태 문장이다(「감사를 마쳤다 — 발견 5개(심각 1 · 중요 3 · 제안 1).」, 0 인 등급은 뺀다). 경고 배너가 뜻을 먼저 쓰고 번호(LD4)는 괄호에 둔다. 앞 20줄의 `⚠` · `degraded` 표지는 그대로다.
- 열린 질문의 빈 쪽 근거는 「이 쪽을 받치는 근거는 보고되지 않았다(0건)」로 낸다. 비어 있는 칸(위치 · 주장 · 인용 · 답 · 피해 · 권고 · 반대근거 · 근거)을 `None` 으로 찍지 않는다 — 「(위치 없음)」·「(없음)」으로 쓰거나 뺀다.
- 종료 보고가 상태 문장으로 시작해 리포트 경로만 보이고(데이터 · 원장 경로는 물으면), 할 일 하나로 끝난다.
- codex 건너뜀 줄 · `scripts/check-integrity.sh` 의 오류와 요약 줄 · 빈칸 채움 사유가 쉬운 한국어다(사유 토큰과 영어 원문은 괄호에 남긴다).
- 소개 문구를 쉬운 말로 바꿨다. 마켓플레이스와 글자까지 같은지는 `shared/tests/test_plugin_description_parity.sh` 가 잰다.

""" % (PA_VER_NEW, DATE)

PI_LOG = """## [%s] — %s

### Changed

- 훅의 사람용 경고(브랜치 이름 · 커밋 메시지 · 규칙 문서 부재)가 한국어다. 정규식과 모델에게 가는 안내(`Rename the branch: …`)는 그대로다.
- 초기화 보고가 무엇을 했는지 한 문장으로 시작하고 할 일 하나로 끝난다. 다른 플러그인을 권하던 줄과 벤더 수 줄을 뺐다.
- 마켓플레이스 소개 문구가 `plugin.json` 과 같아졌다 — 지금 없는 문서 · 헌장 검사 광고를 뺐다.
- README 첫 문단을 쉬운 말로 바꿨고, 원칙 절 제목이 `## Principles Instantiated` 다(`plugin-audit` 의 `check-shape-completeness.py` 가 이 제목만 읽는다).

""" % (PI_VER_NEW, DATE)

PA_README_TEST = '''

README = PLUGIN / "README.md"


class ReadmeTextTest(unittest.TestCase):
    def setUp(self):
        self.text = README.read_text(encoding="utf-8")
        self.lead = flat(self.text.split("\\n## ", 1)[0].split("\\n", 1)[1])

    def test_lead_says_what_it_does(self):
        self.assertTrue(self.lead.startswith("devbrew 플러그인 하나를 고치지 않고 읽기만 해서 감사한다."), self.lead[:80])
        self.assertIn("결과는 증거가 붙은 빈틈 목록이고, 심각한 것부터 정렬된다.", self.lead)

    def test_done_report_line_matches_the_skill(self):
        body = flat(self.text)
        self.assertIn("감사가 끝나면 상태 한 줄과 리포트(`audit.md`) 경로를 보고한다 — 데이터 · 원장 경로는 물으면 보인다.", body)
        self.assertNotIn("세 파일의 절대경로", body)
'''

PI_README_TEST = '''

README = PLUGIN / "README.md"


class ReadmeTest(unittest.TestCase):
    def setUp(self):
        self.text = README.read_text(encoding="utf-8")

    def test_lead_says_what_it_does(self):
        lead = " ".join(self.text.split("\\n## ", 1)[0].split("\\n", 1)[1].split())
        self.assertTrue(lead.startswith("프로젝트의 git 작업 규칙(브랜치 이름 · 커밋 메시지 · PR 절차)과 프로젝트 헌장을 "
                                        "짧은 대화로 만들어 준다."), lead[:80])
        self.assertIn("브랜치 이름과 커밋 메시지를 확인해 알려 준다(막지는 않는다).", lead)

    def test_principles_heading_is_the_canonical_one(self):
        lines = self.text.splitlines()
        self.assertEqual(lines.count("## Principles Instantiated"), 1)
        self.assertNotIn("## 인스턴스화한 원칙", lines)
'''

DOC_EDITS = {
    PA + ".claude-plugin/plugin.json": [('"description": "%s",' % PA_DESC_OLD, '"description": "%s",' % PA_DESC_NEW),
                                        ('"version": "%s",' % PA_VER_OLD, '"version": "%s",' % PA_VER_NEW)],
    PI + ".claude-plugin/plugin.json": [('"description": "%s",' % PI_DESC_PJ_OLD, '"description": "%s",' % PI_DESC_NEW),
                                        ('"version": "%s",' % PI_VER_OLD, '"version": "%s",' % PI_VER_NEW)],
    ".claude-plugin/marketplace.json": [('"description": "%s",' % PA_DESC_OLD, '"description": "%s",' % PA_DESC_NEW),
                                        ('"description": "%s",' % PI_DESC_MP_OLD, '"description": "%s",' % PI_DESC_NEW)],
    PA + "README.md": [(PA_LEAD_OLD, PA_LEAD_NEW), (PA_DONE_OLD, PA_DONE_NEW)],
    PI + "README.md": [(PI_LEAD_OLD, PI_LEAD_NEW), ("\n## 인스턴스화한 원칙\n", "\n## Principles Instantiated\n")],
    PA + "CHANGELOG.md": [("## [%s] — 2026-10-09\n" % PA_VER_OLD, PA_LOG + "## [%s] — 2026-10-09\n" % PA_VER_OLD)],
    PI + "CHANGELOG.md": [("## [%s] — 2026-10-09\n" % PI_VER_OLD, PI_LOG + "## [%s] — 2026-10-09\n" % PI_VER_OLD)],
}
TEST_EDITS = {
    PA + "tests/test_plain_audit_text.py": [(MAIN, PA_README_TEST.rstrip("\n") + "\n" + MAIN)],
    PI + "tests/test_plain_init_text.py": [(MAIN, PI_README_TEST.rstrip("\n") + "\n" + MAIN)],
}


def apply(table, marker_absent):
    texts, bad = {}, []
    for rel, edits in table.items():
        s = open(os.path.join(R, rel), encoding="utf-8").read()
        texts[rel] = s
        for a, _b in edits:
            if s.count(a) != 1:
                bad.append((rel, s.count(a), a))
        for m in marker_absent.get(rel, ()):
            if m in s:
                bad.append((rel, "이미 있다", m))
    if bad:
        for rel, n, a in bad:
            print("STOP %s %s %r" % (rel, n, a[:90]))
        sys.exit(1)
    for rel, edits in table.items():
        s = texts[rel]
        for a, b in edits:
            s = s.replace(a, b)
        open(os.path.join(R, rel), "w", encoding="utf-8").write(s)
        print("t4 %s: %d edits -> %s" % (STAGE, len(edits), rel))


if STAGE == "tests":
    apply(TEST_EDITS, {PA + "tests/test_plain_audit_text.py": ("class ReadmeTextTest",),
                       PI + "tests/test_plain_init_text.py": ("class ReadmeTest",)})
elif STAGE == "docs":
    apply(DOC_EDITS, {})
else:
    print("STOP 단계는 tests | docs")
    sys.exit(2)
````

```bash
chmod +x shared/tests/test_plugin_description_parity.sh
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t4_edit.py . tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/rt.sh shared/tests/test_plugin_description_parity.sh plugins/plugin-audit/tests/test_plain_audit_text.py plugins/project-init/tests/test_plain_init_text.py
grep -a '✗' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/logs/test_plugin_description_parity.sh.log
```

기대(드라이런): 락 `Total: 5 | Pass: 4 | Fail: 1` 과 `✗ project-init: plugin.json 과 마켓플레이스 소개 문구가 다르다`, 두 Python `fail=2`.

- [ ] **Step 2: 소개 문구 · README · 버전 · CHANGELOG**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_t4_edit.py . docs
```

새 소개 문구(두 파일 같은 글자):
- plugin-audit — 「Audits one devbrew plugin without changing it: six read-only reviewers look for gaps, a second pass tries to disprove each one, an optional codex audit adds another model's view, and you get a ranked report of the gaps that hold up. Run /plugin-audit:plugin-audit <name>.」
- project-init — 「Sets up git workflow rules and a project charter through a short interview, writes them as AGENTS.md/CLAUDE.md docs that agents read, and adds a hook that checks branch names and commit messages.」(마켓플레이스의 옛 「doc conventions, and charter integrity」 광고를 없앤다)

- [ ] **Step 3: 테스트**

```bash
P=plugins/plugin-audit/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/rt.sh shared/tests/test_plugin_description_parity.sh $P/test_plain_audit_text.py plugins/project-init/tests/test_plain_init_text.py \
  shared/tests/test_charter_citations.sh shared/tests/test_changelog_integrity.sh shared/tests/test_python_floor.sh \
  shared/tests/test_invocation_surface.sh shared/tests/test_no_new_duplication.sh $P/test_skill_orchestration.py \
  $P/test_check_shape_completeness.py $P/test_check_staleness.py plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh \
  plugins/quality-gates/tests/test_guards_declaration_mapping.sh plugins/quality-gates/tests/test_runner_adapters.sh
for p in plugin-audit project-init quality-gates spec-distill; do
  printf '%s description drift=' "$p"
  python3 plugins/plugin-audit/scripts/check-staleness.py "plugins/$p" --repo-root . 2>/dev/null | grep -c 'description drift'
done
python3 plugins/plugin-audit/scripts/check-shape-completeness.py plugins/project-init --repo-root . 2>/dev/null \
  | python3 -c 'import json,sys; print([g["present"] for g in json.load(sys.stdin)["shape_gaps"] if g["requirement"]=="readme_principles"])'
```

기대: 14개 전부 `rc=0`(같음 락 5/5 · `test_changelog_integrity.sh` 27/27 · `test_guards_coverage_bidirectional.sh` 347/347), 넷 모두 `description drift=0`(편집 전 project-init 은 1), 마지막 `[True]`.

- [ ] **Step 4: 커밋**

```bash
git add shared/tests/test_plugin_description_parity.sh plugins/plugin-audit/.claude-plugin/plugin.json \
  plugins/project-init/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/plugin-audit/README.md \
  plugins/project-init/README.md plugins/plugin-audit/CHANGELOG.md plugins/project-init/CHANGELOG.md \
  plugins/plugin-audit/tests/test_plain_audit_text.py plugins/project-init/tests/test_plain_init_text.py
git commit -m "docs: plugin-audit · project-init README 와 소개 문구, 소개 문구 같음 락, 버전 올림

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat --format= HEAD | tail -1
git ls-files -s shared/tests/test_plugin_description_parity.sh
```

기대: `10 files changed`, 모드 `100755`.

- [ ] **Step 5: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/pr4_mut.py . t4 > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/mut-t4.txt; tail -1 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr4/mut-t4.txt
```

기대: `cells=8 red=8 survived=0 skip=0`(AC10 의 「한 쪽 글자 하나 바꾸기 → RED」 둘 포함).

- [ ] **Step 6: 최종 스위트 · /qg · PR**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr4/final
S=~/.claude/sdd-mirror/plain-language-output/pr4
for x in baseline final; do sed -E 's/\(lines [0-9]+, [0-9]+ distance [0-9]+ > 160\)/(lines N)/' "$S/$x/failures.txt" | sort > "$S/$x.norm"; done
echo "== final-only"; comm -13 "$S/baseline.norm" "$S/final.norm"
echo "== baseline-only"; comm -23 "$S/baseline.norm" "$S/final.norm"
echo "== files only in final"; comm -13 <(cut -f1 "$S/baseline/summary.tsv" | sort) <(cut -f1 "$S/final/summary.tsv" | sort)
```

기대: final-only 빈 출력(드라이런 after 스위트 실측 — 「스위트 대조」는 보고서). baseline-only 에 `test_codex_backward_compat.sh :: rc=1` 이 있으면 기준선 쪽 흔들림이다. 파일 수 273 → 276(새 테스트 셋). final-only 에 `test_codex_backward_compat.sh` · `test_codex_runner_degrade_contract.sh` 가 나오면 단독으로 다시 돌려 본다. `test_hook_output_schema.py` 가 이 워크트리에서만 실패하면 기준선과 같은지 본다(복사본에서는 통과한다).

`/qg branch` — 묻는다: 「`validate-audit-data.py` 가 읽는 앞 20줄 표지가 그대로인가 · 훅의 정규식과 모델 채널이 그대로인가 · 감사자 · 반박자 · codex 의 찾는 지시가 바뀌지 않았는가 · 문구를 고정한 테스트의 뜻이 유지됐는가(Task 1 · 3 의 표)」.

PR 본문(한국어): 첫 줄 한 문장 · 「계획이 정한 것」 S1~S16(사용자 확인 결과 포함) · 문구 고정 테스트 표(Task 1 Step 1, Task 3 Step 1) · 변이 결과(68 셀) · 할 일 하나: 「`/plugin-audit:plugin-audit project-init` 과 빈 테스트 레포의 `/project-init:project-init` 을 한 번씩 돌려, 보고서 둘째 줄 · 종료 보고와 훅 경고가 읽히는지 봐 주세요」(Verification Plan 4). 그리고 사후 확인 안내 한 줄: 「며칠 쓴 뒤 새 세션 기록 목록을 만들어 `python3 tools/plain-language/measure_output.py <목록>` 으로 PR 1 기준선과 비교한다 — 머지 조건이 아니다(Verification Plan 3)」. 맨 끝 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

머지 직전에 버전을 다시 정한다(Global Constraints 「버전」). 머지는 사용자가 `! gh pr merge <n> --merge`.
