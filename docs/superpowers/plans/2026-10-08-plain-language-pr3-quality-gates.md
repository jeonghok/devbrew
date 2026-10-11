# 쉬운 말 출력 PR 3 — quality-gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** /qg 의 사람용 고정 문구 — 질문 셋과 선택지, 완료 표, 범위 줄 · trivia 줄 · 범위 경고, 합성기 출력, 시작 배너와 setup 오류 줄 — 가 한국어 쉬운 말이 되고, 합성기 출력의 첫 줄이 스크립트가 계산한 상태 문장이 된다. 모든 리뷰어 지적에 사람에게 보일 한 문장(`plain:`)이 생겨 화면에 먼저 보인다. 판정 줄과 기계가 읽는 줄은 형태가 그대로다. 착수 전 기준선과 비교해 새 실패는 0 이어야 한다.

**Architecture:** 판정은 여전히 `verdict.py` 가 정한다 — 합성기 꼬리의 `verdict:` 줄과 판정 줄(`qg: … · 막는 지적 N · …`, #194 가 이미 한국어로 만들었다)은 그대로다. 합성기의 `**Findings:**` · `blocking:` · `optional:` 줄 · `판정 degrade` 표지 · `dropped as malformed` 토큰도 그대로 둔다(SKILL 의 Final verdict 펜스 · Fix-loop 요약 · 테스트가 읽는다). 바꾸는 것은 그 옆의 사람용 줄과 그 자리뿐이다 — 지시문 문장은 그대로 두고, 지시문이 「그대로 내라」고 적은 문구만 고친다(설계 §6). 합성기 표 머리를 바꾸면 그 표를 `result.md` 로 옮기는 SKILL 펜스의 앵커(`^| … |`)와 분류표 번호가 가리키는 목록 이름도 같은 커밋에서 같은 글자로 바꾼다 — 한쪽만 바뀌면 「지적」 절이 조용히 빈다. `plain:` 칸은 형식을 정하는 곳(agent 정의 넷 · codex 프롬프트 빌더 둘 · 재비판 프로필 · SKILL 의 외부 리뷰어 dispatch 프롬프트)에서 생기고, 넘기는 곳(공유 codex 변환기 · 비코드 합성기의 허용 목록 둘 · 합성기의 재비판 응답 읽기 — 이미 통째로 넘긴다)과 합치는 곳(두 합성기의 dedup)을 지나, 그리는 곳(합성기 표)에서 요약 앞에 선다. 칸이 없는 지적은 지금처럼 나간다 — 칸이 없다고 버리면 처분 회계에서 소실이 된다. 재비판자에게 주는 익명 목록에는 싣지 않는다(프레이밍 차단).

**Tech Stack:** Python 3.9+, bash(macOS 3.2 호환), git.

**Spec:** `docs/superpowers/specs/2026-10-08-plain-language-output-design.md` (brief: `docs/superpowers/interview/2026-10-03-plain-language-output-interview.md`). 선행: PR 1(#188) · PR 2(#193) · PR 4(#195) 머지됨, qg v10 ②(#194, quality-gates 11.0.0) · ③(#196, 12.0.0) · ④(#197, e2e 걷기, 12.1.0) 머지됨 — 이 계획은 브랜치 88a763c2(main 3a8d7d1d 를 merge 한 트리) 기준이다. qg v10 ⑤(차등)는 아직이다 — 둘째로 머지되는 쪽이 맞춘다(「qg v10 차등 계획과의 충돌」). ④ 가 먼저 들어와서 이 계획이 ④ 의 e2e 게이트 문면도 같은 라벨로 바꾼다(R18).

## 목차

- [Global Constraints](#global-constraints)
- [계획이 정한 것](#계획이-정한-것)
- [bc8fae40 뒤 트리가 바뀐 것](#bc8fae40-뒤-트리가-바뀐-것)
- [baba7d19 뒤 트리가 바뀐 것](#baba7d19-뒤-트리가-바뀐-것)
- [qg v10 차등 계획과의 충돌](#qg-v10-차등-계획과의-충돌)
- [Review Focus](#review-focus)
- [Task 0: 착수 준비](#task-0-착수-준비)
- [Task 1: 질문 셋 · 완료 표 · 모델이 그대로 내는 문구](#task-1-질문-셋--완료-표--모델이-그대로-내는-문구-ac6--r15--r18)
- [Task 2: 합성기 · 표를 읽는 SKILL 자리 · 시작 배너 · setup 오류 줄](#task-2-합성기--표를-읽는-skill-자리--시작-배너--setup-오류-줄-goal-2--ac5--ac6--r1--r2--r8--r10--r12--r16)
- [Task 3: `plain:` 칸](#task-3-plain-칸--형식--넘기기--합치기--그리기-5--ac9--d28--deferred-7)
- [Task 4: README · 소개 문구 · 버전](#task-4-readme--소개-문구--버전-8--ac10--r13--r17--r21--r22)

## Global Constraints

- **재결정 규약** — confirmed 항목은 근거가 있으면 보고한 뒤 재결정할 수 있고, 임의 변경은 금지다. 설계 B1~B10 · D1.1~D2.10, PR 1 의 P1~P13, PR 2 의 Q1~Q12, PR 4 의 S1~S16 이 제약이다. 이 계획이 정한 것은 아래 표에 있고, 「사용자 확인」 칸에 표시한 행은 실행 전에 사용자에게 묻는다(R10~R13 은 2026-10-10, R15~R18 은 2026-10-11 에 승인됐다. R19~R22 는 「확인 권장」이다).
- **작업 위치** — `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice`, 브랜치 `feature/plain-language-voice`. subagent 에게 이 절대경로를 매번 못 박는다.
- **보조 파일 자리** — 이 계획의 스크립트(앵커 검사 · 편집 · 고정 단언 갱신 · 테스트 실행 · 변이)는 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/` 에 쓴다. 그 job tmp 는 다른 작업도 담는다 — **글롭으로 `rm` 하지 않는다**(subagent 포함). 지울 때는 만든 경로를 정확한 이름으로만 지운다.
- **git** — merge(rebase 금지), 경로 지정 커밋(`git add <경로>…` — `-A` · `.` 금지), Conventional Commits 에 **한국어 설명**, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. 스태시 금지.
- **편집은 스크립트로** — 각 Task 의 편집 · 고정 단언 갱신은 이 계획에 실린 파이썬 스크립트를 글자 그대로 쓰고 돌린다. 스크립트는 옛 글자가 기대 개수만큼 있는지 먼저 다 재고, 하나라도 다르면 아무것도 쓰지 않고 `STOP` 줄을 내며 끝난다. `STOP` 이 나면 그 자리가 움직인 것이다 — 같은 뜻의 자리를 찾아 고치지 말고 멈춰 보고한다.
- **Python** — `encoding="utf-8"` 명시, `"python3"` 문자열 리터럴 금지(`shared/tests/test_python_floor.sh` 축 E), Python 3.9.
- **처분 회계 소비자** — `synthesize_findings.py` · `synthesize_artifact_findings.py` 에는 컴프리헨션 · `break` · `continue` 를 새로 넣지 않고(for 문 + 대입으로 쓴다 — `shared/tests/test_adjudication_wiring.sh` 의 컴프리헨션 baseline 40), `synthesize_findings.py` 의 310 줄(`dedup()` 의 `continue`) 위에 줄을 넣지 않는다 — `tools/adjudication/check_wiring.py:148` 의 EXEMPT 가 그 분기를 줄 번호로 가리킨다(R14).
- **셸** — 한국어 글자 앞의 셸 변수는 `${v}` 로 쓴다(bash 3.2 는 `「$v」` · `$v개` 를 `set -u` 에서 죽이거나 바이트를 먹는다 — setup 의 새 줄 `세션 ID '${SESSION_ID}'` · `계획 파일: ${PLAN_FILE}` 이 그 자리다). 새 락의 산문 단언은 줄바꿈을 지운 본문에서 잰다(`flat`). 셸 락이 읽는 파일이 늘면 `# guards:` 선언도 같이 넓힌다(`plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` 가 두 방향으로 잰다).
- **새 테스트 파일은 실행 비트로 커밋한다**(`chmod +x` — 모드 100755). `tests/test_runner_adapters.sh` 의 `case_qg_test_scripts_are_executable` 가 비실행 테스트를 RED 로 잡고, 그 RED 가 `test_codex_backward_compat.sh` 로 번진다.
- **새 문면은 부재 락의 코퍼스에 든다** — 파일 전체를 훑는 부재 단언이 새 문장을 잡을 수 있다. 실측: `test_pipeline_verdict_wiring.sh:605` 가 SKILL 전체에서 「리뷰어가 낸 값을 그대로 옮긴다」를 금지한다(옛 confidence 보존 지시) — 옛 계획의 R4 문장이 그 글자를 담아 RED 를 냈다. 이 계획의 문장은 그 글자를 피했다(「리뷰어가 쓴 문장 그대로 싣는다」). 추적 파일(`git ls-files` — index)만 보는 스윕은 새 파일을 커밋 **뒤**에야 본다 — 드라이런 1회차 after 스위트에서 `tests/test_publish_surface_removed.sh` 가 새 락의 부재 단언 안에 적힌 없어진 명령 이름을 잡았다(커밋 전 Task 실행 목록에서는 GREEN 이었다). 그래서 각 Task 의 커밋 Step 은 그런 스윕 셋(`tests/test_publish_surface_removed.sh` · `tests/test_gate_era_prose_absent.sh` · `shared/tests/test_dispatch_disposition.sh`)을 커밋 뒤에 한 번 더 돌고, 새 락은 없어진 명령 이름을 적지 않는다(허용 목록으로 잰다).
- **테스트** — 셸은 리포 루트에서 `bash <경로>`, 하나씩(동시 실행 금지 — 고정 `/tmp` 경로가 경쟁해 거짓 RED 가 난다). Python 은 그 `tests/` 에서 `python3 -m unittest -v <모듈>`. `PYTHONDONTWRITEBYTECODE=1`. `plugins/quality-gates/tests/spike/` 는 돌리지 않는다. Task 0 Step 4 의 `rt.sh` 가 이 규칙대로 돈다. `test_agent_model_mutation.sh` 는 `agents/` 가 커밋된 깨끗한 트리에서만 돈다 — 커밋 **뒤**에 돌린다(Task 3 Step 5).
- **선재 RED(88a763c2)** — `tests/harness/test_skill_orchestration_behavior.sh` 의 FAIL 하나(「R1b→R8 unclaimed 집행 사슬 (집행자가 셀 원본에 닿지 못한다)」, rc=1). 이 파일의 rc 는 이미 1 이라 rc 로는 새 실패가 안 보인다 — **FAIL 줄 수 1 과 그 이름**으로 비교한다. 같은 이유로 변이 셀의 테스트로 쓰지 않는다. `test_codex_backward_compat.sh` · `test_codex_runner_degrade_contract.sh` 는 부하 아래에서 흔들릴 수 있다 — 단독 재실행이 통과하면 새 실패가 아니다. `test_hook_output_schema.py` 는 진짜 워크트리에서만 실패한다(복사본에서는 통과) — 이 PR 과 무관하다.
- **변이** — 커밋한 뒤 변이한다. `pr3_mut.py` 가 먼저 그 Task 의 셀이 부르는 테스트를 깨끗한 HEAD 에서 돌려 전부 통과하는지 본다(양성 대조 — 하나라도 RED 면 모든 셀이 공허하게 RED 다). 그다음 셀마다 새 글자를 정확히 한 번 바꾸고 지정 테스트를 돌린 뒤 `git checkout HEAD -- <파일>` 로 되돌리고 `git diff HEAD --stat` 이 빈지 본다. 새 규칙 문장마다 셀이 있다(지우기 · 뒤집기 · 옛 글로 되돌리기 · 옮기기). `survived=0 skip=0` 이 아니면 그 락에 이빨이 없거나 셀이 어긋났다 — 락을 고친다.
- **경고는 사람에게 닿아야 한다** — 스크립트가 내는 경고 · degrade 는 사람이 읽는 첫 줄이나 끝 보고에도 닿아야 한다(PR 2 · PR 4 리뷰가 둘 다 대화에 닿지 않는 경고를 찾았다). 이 계획: 합성기 첫 줄이 버린 지적 수(R12)와 경고 유무(R16)를 말하고, 그 본문(degrade 공시 · 버린 지적 줄)은 SKILL Step 4.5 가 그대로 보이는 `synth.out` 에 있다. setup 의 오류는 qg.md 가 그대로 보인다. 처분 렌더의 advisory(`[adjudication] …`)는 렌더 자신의 회계 불일치 신호라 stderr 그대로다(설계 밖).
- **라벨의 두 쓰임** — Fix-loop 선택지 이름은 고르는 자리(질문의 `label` · 굵은 분기 불릿 · 선택지 나열 · 「…를 넣지 않는다」 · 「…없이/로 끝나면」)에서 새 라벨로 부른다. 반복 동작의 이름으로서의 Retry(「Retry: file-write safety」 · 「Retry spends one iteration」 · 흐름 그림 「Retry: …」 · 「Retry 면」 · e2e 의 「고침은 Retry 로만」 · 「Retry 의 「적용」 목록」 · 「Retry 뒤」)는 지시문이라 그대로 두고, 흐름 그림 첫 줄 「고치고 다시 돌기(Retry)」가 둘을 묶는다(R19). Accept · Stop 은 개념어로 쓰이지 않는다 — 전부 새 라벨이다.
- **리뷰어 지시 파일은 보안 민감** — 찾는 지시는 한 글자도 바꾸지 않고, 「짧게 써라」를 넣지 않으며, `tools:` 를 바꾸지 않는다. 칸만 더한다(설계 §5).
- **이름** — CLAUDE.md Progressive disclosure: 기계가 내는 안내는 `/plugin:name` 완전명이고, 진입 skill 짧은 이름을 맨몸으로 쓰지 않는다. qg 는 `plugins/quality-gates/commands/qg.md` 하나를 유지하고 호출 표면 락(`shared/tests/test_invocation_surface.sh`)의 보고 모드다 — 이 계획은 보고 표의 행 수(88a763c2: 15)를 늘리지 않는다. 새 command 파일을 만들지 않는다. `/qg` · `/qg branch` · `/qg critique` 는 command 라 그대로 쓴다. `/qg-publish` 는 #196 이 지웠다 — 어느 새 문면에도 쓰지 않는다(`tests/test_publish_surface_removed.sh` 의 개념 별칭 스윕이 `qg[-_]publish|pr[-_ ]understanding` 을 대소문자 무시로 잰다).
- **버전** — 88a763c2 에서 quality-gates 12.1.0 → **12.2.0**(minor — 출력 계약은 그대로이고 새 칸이 생긴다), spec-distill 5.1.1 → **5.1.2**(patch — 링크로 실린 `shared/codex/codex_findings_to_yaml.py` 의 내용이 바뀐다 · 설치본 캐시 키). plugin-audit · project-init 은 건드리지 않는다. 번호는 **머지 직전**에 origin/main 의 두 `plugin.json` 을 보고 다시 정한다(⑤ 도 qg 버전을 올린다(major) — 먼저 머지되는 쪽이 이긴다. 같은 버전 문자열은 충돌 없이 병합된다). 다시 정하면 `pr3_t4_edit.py` 머리의 상수 넷(`QG_OLD_VER` · `QG_OLD_HEAD` · `SD_OLD_VER` · `SD_OLD_HEAD`)과 Step 3 의 인자를 바꾼다. SKILL 제목의 `(v12.1.0)` 도 같은 번호로 올린다(R22 — 릴리스마다 올려 왔다. harness 락은 major 만 잰다).
- **줄 번호** — 이 계획의 줄 번호는 88a763c2 실측이다. 편집은 줄 번호가 아니라 옛 글자로 찾는다.
- **산출 보존** — `~/.claude/sdd-mirror/plain-language-output/pr3/`(기준선 사본 `baseline-d/`).
- **드라이런** — 2026-10-11 88a763c2 복사본에서 이 계획을 Task 0–4 끝까지 글자 그대로 실행했다(보고서: `/Users/jeonghokim/.claude/sdd-mirror/plain-language-output/research/dryrun-pr3d-report.md` — baba7d19 회차는 `dryrun-pr3c-report.md`). 아래 RED 수 · GREEN · 변이 결과는 그 실측이다. 드라이런은 같은 스크립트를 `R=<복사본>` · `LOGS=<복사본 로그>` 환경변수로 돌렸다 — 스크립트 글자는 같다.

## 계획이 정한 것

| # | 정한 것 | 근거 | 사용자 확인 |
|---|---|---|---|
| R1 | 합성기의 **판단에 필요한 0** 과 **기계가 읽는 0** 은 남긴다: 처분 줄(`**처분:** 수용 N · 기각 N · 억제 N · 흡수 N · 미판정 N (미판정은 차단)`) · 배관 손실 줄 · 「탐지 0 · 재비판 0」 줄은 「아무것도 버리지 않았다」·「재비판자가 돌았다」는 공시이고, `**Findings:** 0 CRITICAL / …` · `blocking: 0` · `optional: 0` 은 SKILL 의 Final verdict 펜스(`grep -c "^${k}: "` — 정확히 한 번)와 Fix-loop 요약이 읽는다. | 설계 §3 원칙 3 · §3 표. 락: `test_synthesize_disposition.sh:95` · `test_synthesize_artifact_findings.sh:394-412` · `test_synthesize_recritic.sh:420` · `test_synthesize_findings.sh:59-64`. 공유 모듈 `render_disposition.py` 는 손대지 않는다. | — |
| R2 | 합성기 첫 줄은 `render()` 가 계산한 상태 문장이다(판정과 무관 — 판정에 기대는 줄은 `render()` 에 넣지 않는다). 그 줄이 빈 결과의 「No findings.」 줄을 대신한다. 범위·각도 블록 앞의 쉬운 한 줄은 `--emit-verdict` 꼬리에서 **블록이 있을 때만** 첫 블록 바로 앞에 한 번 낸다 — 둘 다면 「아래는 이 판정이 본 범위(scope)와 리뷰 각도(angles)의 원문이다.」, `scope:` 만이면 「…본 범위(scope)의 원문이다.」, `angles:` 만이면 「아래는 이 판정의 리뷰 각도(angles) 원문이다.」. 그래서 `test_angle_coverage.sh:89-95` 의 「off 는 on 에서 angles: 블록을 뺀 것과 바이트 동일」 불변식이 「angles: 블록과 그 앞의 쉬운 한 줄을 뺀 것」으로 바뀐다. | `test_verdict_vocabulary.sh:460-486` — 판정 없는 출력이 판정 있는 출력의 바이트 접두여야 한다. 블록이 없는데 블록을 가리키는 줄은 거짓이다. | — |
| R3 | 외부 추가 리뷰어(`pr-review-toolkit:*`)의 dispatch 프롬프트 리터럴(SKILL Step 3 「External reviewers」 펜스, :347-357 — #194 가 새로 만든 자리)의 칸 나열에 `plain (optional — …)` 을 더한다. 외부 agent 정의와 모델 고정은 건드리지 않는다. | 설계 D2.8. 옛 계획은 리터럴이 없다고 보고 「추가 리뷰어 — 스코프 도출」 절에 한 줄을 붙였다 — 그 절은 #194 가 지웠고 리터럴이 생겼다(같은 결정, 자리만 옮김). | — |
| R4 | 오케스트레이터가 `$RV/findings.yaml` 을 손으로 쓸 때 `plain:` 도 옮긴다는 문장을 Step 3.5-1 의 「Do not copy a `confidence:` field.」(:456) 바로 뒤에 더한다: 「**각 항목의 `plain:` 은 리뷰어가 쓴 문장 그대로 싣는다** — 없으면 키를 뺀다(지어내지 않는다).」 이 문장이 없으면 칸이 합성기에 닿기 전에 사라진다. 옛 문장의 「리뷰어가 낸 값을 그대로 옮긴다」는 `test_pipeline_verdict_wiring.sh:605` 의 부재 락(옛 confidence 보존 지시)에 걸린다 — 피했다. | 옛 앵커(「합성기가 5 로 채운다」)는 #194 가 confidence 와 함께 지웠다. | — |
| R5 | 「Codex skip 안내」 표의 영어 사유 문구와 `specialist <X> unavailable (<plugin> 미설치) — degraded coverage` 줄, SKILL P1 의 `[quality-gates] disabled via DEVBREW_QUALITY_GATES_DISABLE=1` 은 고치지 않는다. 사유 토큰이 사람에게 그대로 보여야 하고(설치 명령 · 버전 문자열), 락(`test_skill_codex_skip_prose.sh` · `test_review_scope_composition.sh:28`)이 그 글자를 잰다. P1 은 qg.md 가 setup 을 먼저 부르므로 사람에게는 setup 의 거부 줄(R10)이 보인다. | AC6 의 범위는 질문 셋 · 완료 표 · 합성기 · 시작 배너 · setup 의 사람용 줄이다. | — |
| R6 | **폐기**(옛 행 — cancel-qg 보고). #189 가 `/cancel-qg` 를 지웠다. | `git log 24ac11d6`. | — |
| R7 | 비코드 산출물 경로(`critiquing-artifacts`)에는 화면 렌더러가 없다 — `kept:` YAML 을 모델이 읽어 보고한다. 그래서 그 경로의 `plain:` 은 `kept` 에 남는 것까지 재고, 최종 보고 틀에 「`plain:` 이 있으면 그것을 먼저 쓴다」 한 줄을 더한다. | `synthesize_artifact_findings.py` 는 YAML 을 낸다(#194 · #196 은 이 파일을 바꾸지 않았다). | — |
| R8 | Goal 2 의 확인(설계 표 `0b618227#r2.1`): golden 파일 대신 합성기(발견 0건 · 1건 이상 · 버림 · 경고)와 시작 배너의 첫 줄과 0 줄 부재를 단언으로 고정한다. | 이 플러그인의 기존 테스트 관례가 단언이다. 변이 「0 인 등급 되살리기 → RED」를 함께 잰다. | — |
| R9 | **옮겨 간 표면** — cancel 보고와 세션 시작 훅 경고는 #189 가 지웠다. cancel 보고의 뜻(상태를 지웠다 · 못 지웠다)은 setup 의 거부 줄(`refuse` · 다른 세션 · 예약 폴더 — 「… — 지우지 않는다. 아무것도 쓰지 않는다.」)과 없어진 인자 안내(`gone`)로 옮겨 갔고 이미 한국어라 고칠 것이 없다. | `setup-qg.sh:28 · :151 · :160 · :167 · :204`. | — |
| R10 | setup 의 나머지 영어 오류 줄 — kill switch 거부(`:16`) · 인자 오류 넷(`:42` · `:72` · `:84` · `:114-115`) · 세션 ID 둘(`:132-136` · `:142`) — 을 쉬운 말로 시작하게 하고 원래 영어 토큰은 괄호에 남긴다. 기존 락이 그 토큰(`requires at least one glob` · `Unknown argument` · `fails pattern guard`)을 재고, 특히 `! grep -qi 'Unknown argument'` 꼴의 부재 락은 토큰이 사라지면 공허해진다. `--help` 본문은 그대로다. | AC6 「`setup-qg.sh` 의 사람용 고정 문구가 한국어」. 대상 줄은 310ce78f 와 같다(#194 · #196 이 바꾸지 않았다). | 사용자 승인 2026-10-10 |
| R11 | **대상 소멸** — 합성기 꼬리의 「re-run with `/qg --show-low-confidence`」 안내는 #194 가 confidence · 억제와 함께 지웠다. 이 계획은 할 것이 없다(R15 참고). | `synthesize_findings.py` 에 `suppressed` · `show-low-confidence` 가 없다(Task 0 Step 2 의 `plain` 0 · 앵커). | 사용자 승인 2026-10-10 (실행할 것 없음) |
| R12 | 합성기 첫 줄에 버린 지적 수를 붙인다 — 「… 형식이 깨져 버린 지적 N개.」. 버린 주장이 있는 실행의 첫 줄이 「지적 없음」만 말하면 없는 것과 버린 것이 같은 줄로 읽힌다. | 규칙 블록 「없는 것과 확인 못 한 것은 다르다」. 첫 줄은 #194 가 다시 쓴 `render()` 안의 새 코드다(대상은 그대로 있다). | 사용자 승인 2026-10-10 |
| R13 | README 다시 쓰기는 좁게 한다: 첫 문단 · `## 사용` → `## 쓰는 법` 표 · 「파이프라인 흐름」 첫 문단 · 상태도의 질문 표지와 라벨(Task 1). 나머지 절의 머리글과 문면은 글자 그대로 둔다 — 락 여럿이 그 머리글로 절을 자르고 그 안의 낱말을 잰다. 상태도는 #194 가 상자 그림을 트리로 바꿨다 — 바꾸는 것은 질문 표지 한 줄과 라벨 두 줄이다. | 설계 §8 보다 좁다(PR 2 · PR 4 S11 과 같은 방식). | 사용자 승인 2026-10-10 |
| R14 | 처분 회계 소비자에 넣는 코드는 컴프리헨션 · `break` · `continue` 없이 쓰고, `synthesize_findings.py:310`(`dedup()` 의 `continue`) 위에는 줄을 넣지 않는다 — 새 함수 `_status_line` 은 `render()` 바로 위, `_has_plain` 은 `sort_findings()` 바로 위, dedup 물려받기는 `merged = dict(group[0])` 바로 뒤다. | `test_adjudication_wiring.sh`(컴프리헨션 baseline 40 · 버리는 분기 전부에 처분 호출) · `check_wiring.py:148` EXEMPT 키 `310`. 드라이런: 세 Task 뒤 `exempt_stale=0` · 컴프리헨션 40. | — |
| R15 | 완료 표는 칸 이름(판정 · 반복 · 결과)과 제목만 한국어로 바꾸고, **결과 칸의 값은 기계 토큰 그대로 둔다**(`finished` · `accepted with findings iter N` · `aborted iter N`). 그 값을 `## Publish` 의 게시 펜스가 `OUTCOME` 으로 받아 `case` 로 가른다(`aborted*` 면 게시하지 않는다) — 한국어 낱말로 바꾸면 펜스가 「OUTCOME 이 형식 밖」으로 거절한다. 사람에게 보이는 쉬운 말은 완료 보고 첫 문장이 맡는다. | #196 이 결과 칸을 게시 펜스의 입력으로 만들었다. 옛 계획은 결과 값을 「끝났다 \| 지적을 남기고 끝냈다(반복 N) \| 멈췄다(반복 N)」로 바꿨다 — 그대로 두면 게시가 늘 거절된다. 변이 셀이 그 옛 편집을 RED 로 잡는다. | 사용자 승인 2026-10-11 (옛 계획보다 좁다(표의 결과 칸이 영어 토큰으로 남는다) )|
| R16 | 합성기 첫 줄에 경고(degrade) 유무를 붙인다 — 막는 경고면 「판정을 막는 경고가 있다 — 아래를 본다.」, 막지 않는 경고면 「판정을 막지 않는 경고가 있다 — 아래를 본다.」. 경고 본문(`판정 degrade` 공시)은 그대로 아래에 있다. 첫 줄은 `판정 degrade` 표지 글자를 쓰지 않는다(테스트가 표지 개수를 잰다). | 규칙 블록 「확인하지 못한 것 · 빠진 검사는 따로 한 줄씩」 · Global Constraints 「경고는 사람에게 닿아야 한다」(PR 2 · PR 4 의 I1). R12 를 넓힌다. | 사용자 승인 2026-10-11 (R12 보다 넓다 )|
| R17 | 소개 문구 · README 첫 문단 · `## 쓰는 법` 은 #196 의 게시 모양에 맞춘다: `/qg-publish` 행과 「별도 게시 명령」 문장을 쓰지 않고, 「열린 PR 이 있으면 판정 뒤 쉬운 설명과 판정 줄을 코멘트 하나로 단다(`DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` 로 끈다)」를 첫 문단과 `/qg` 행이 말한다. 소개 문구: 「Checks a change before you ship it: one /qg run reviews the diff from several independent angles, runs the tests whose behavior changed, and gives one verdict. When the branch has an open PR, it posts that verdict with a plain-language summary as one new comment.」 | #196 이 `/qg-publish` 를 지우고 게시를 파이프라인에 넣었다. R13 이 승인한 넷의 내용이 바뀐다. | 사용자 승인 2026-10-11 (R13 의 문안이 바뀐다 )|
| R18 | ④ 의 e2e 문면(SKILL `## e2e` 의 E4 불릿 · 첫 문장 · 끝 문장, `references/e2e.md` 5 절 게이트 표의 fail 행 · 「넣지 않는다」 문장 · 6 절 결과 표 · aborted 문장)이 부르는 Fix-loop 선택지 이름을 Task 1 의 라벨(「고치고 다시 돌기」 · 「지금 판정으로 끝내기」 · 「멈추기」)로 바꾼다. 한 실행 안에서 같은 질문이 두 이름으로 불리면 모델이 없는 선택지를 찾는다. ④ 의 테스트는 이 글자를 재지 않는다(`test_e2e_docs.sh` 는 주석 한 줄뿐) — 고정 단언 갱신이 없다. | ④(#197)가 이 PR 보다 먼저 머지됐다. 앞 회차 충돌 표의 「④ 가 먼저면 이 계획이 할 것」. | 사용자 승인 2026-10-11 |
| R19 | e2e 문면에서 반복 동작 이름으로 쓰인 Retry 는 그대로 둔다 — SKILL `## Flow` 의 「(Retry 면 남은 iteration 에서 …)」 · `## Rules` 의 「고침은 Retry 로만 한다」 · e2e 레퍼런스의 「고침은 Fix-loop 의 Retry 로만 한다」 · 「Retry 의 「적용」 목록」 · 「Retry 뒤 다시 걸을 때도」. 선택지를 부르는 자리만 바꾼다(Global Constraints 「라벨의 두 쓰임」). | Task 1 이 SKILL 의 「Retry: file-write safety」 등을 그대로 둔 것과 같은 규칙. 흐름 그림 첫 줄이 「고치고 다시 돌기(Retry)」로 묶는다. | 사용자 승인 2026-10-11 — 권장안 (「고침은 Retry 로만」도 새 라벨로 바꿀지 )|
| R20 | e2e 의 기계가 읽는 글자는 그대로 둔다: e2e 칸 값(`pass` · `fail` · `미확인` · `안 함` · `걸을 것 없음` · `걸을 도구 없음` · `꺼짐(kill switch)` — `verdict.py --e2e` 가 받는다), 그 값을 이름으로 부르는 게이트 선택지(「fail 로 뒤집기」 · 「pass 로 뒤집기」 · 「pass 승인」), `e2e-state.sh` 의 출력 줄(`ready:` · `boot-failed:` · `stop-failed:` · `changed:` · `proposal:`)과 `… rc=` 줄. e2e 질문 · 선택지 · 판정안 문구 · `e2e-state.sh` 의 사람용 오류 줄 · setup 의 「앞 실행의 e2e 앱을 내리지 못했다」는 ④ 가 이미 한국어로 썼다 — 고칠 것이 없다. | 판정 줄이 `e2e pass` 로 보이므로 선택지의 `pass` · `fail` 이 같은 글자여야 사람이 둘을 잇는다. | 사용자 승인 2026-10-11 — 권장안 (선택지의 `pass` · `fail` 을 토큰으로 남김 )|
| R21 | 소개 문구 · README 첫 문단 · `/qg` 행이 e2e 걷기(선택 · 사람 승인)를 한 구절 말한다: 소개 문구 「… runs the tests whose behavior changed, can walk the running app with your approval, and gives one verdict. …」, 첫 문단 「원하면 판정 전에 사람이 승인한 명령으로 앱을 띄워 직접 걸어 본다(e2e 걷기).」, `/qg` 행 「…고칠지 묻고(최대 5번), 판정 전에 앱을 띄워 걸어 볼지 묻는다.」 | ④ 가 소개 문구에 「+ optional human-approved e2e walk」를 더했다 — R17 문안으로 덮으면 그 공개 사실이 사라진다. | 사용자 승인 2026-10-11 — 권장안 (R17 문안에 한 구절이 는다 )|
| R22 | SKILL 제목 `# Quality Gates — In-Turn Orchestrator (v12.1.0)` 을 이 PR 의 qg 버전으로 올린다(Task 4). 앞 회차 계획은 「그대로 둔다」였다. | 릴리스마다 올려 왔다(`git log -G'In-Turn Orchestrator \(v'` — 11.0.0 · 12.0.0 · 12.1.0 커밋이 각각 올렸다). 테스트는 이 글자를 재지 않는다(harness 는 major 만). | 사용자 승인 2026-10-11 — 권장안 (앞 회차 결정을 바꾼다 )|

재결정(확정 항목 변경)은 없다(R22 는 이 계획의 앞 회차 결정을 바꾼다 — 설계 확정 항목이 아니다). 사용자에게 보이던 능력을 없애는 행도 없다 — R11 의 안내는 #194 가 이미 지웠다. 「확인 필요」 행은 없다. 「확인 권장」은 R19 · R20 · R21 · R22 다.

## bc8fae40 뒤 트리가 바뀐 것

이 계획은 bc8fae40 에서 310ce78f 기준으로 다시 쓰였다. 그 뒤 main 에 든 것 중 이 계획에 닿는 것만 적는다(`git log --oneline bc8fae40..baba7d19 -- plugins/quality-gates shared`).

| 바뀐 것 | 들인 PR | 이 계획에서 |
|---|---|---|
| 파이프라인 SKILL 을 v10 흐름으로 다시 씀(932줄) — `## Flow` 그림 · Step 3 구성 표 · 외부 리뷰어 dispatch 프롬프트 리터럴 · Step 3.5 `code-recritic` · Step 5 분류표 · Fix-loop 결정에 둘째 질문(분류) · `## Final verdict` 의 `verdict.py` 펜스와 `result.md` 기록 펜스 | #194 | Task 1 · 2 · 3 의 SKILL 편집을 새 글자로 다시 도출(질문 넷 · 분류 선택지 설명 · 흐름 그림의 라벨 · 차등 기원 안내 · Final verdict 표 · 외부 리뷰어 프롬프트 · Step 3.5-1) |
| 합성기 다시 씀 — confidence · 억제 · `*` 표지 · `--show-low-confidence` 안내 삭제, 표 머리 `\| Sev \| Path:Line \| Summary \| Source \|`, 빈 결과 「No findings.」, `blocking:` · `optional:` 줄, `prepare` 하위명령(익명화 · 역매핑), `qg-recritic` 블록을 직접 읽어 판정 적용 | #194 | Task 2 의 합성기 편집 · 고정 단언 전부 재도출. 「확신 높은 지적」 · 숨긴 수 문구가 사라졌다(R11). 첫 줄은 버린 수(R12) · 경고(R16) |
| `recritic_bridge.py` 삭제 · `test_recritic_bridge.sh` → `test_synthesize_recritic.sh` · `agents/doc-recritic.md` 삭제 · `agents/code-recritic.md` 신설(added 형식이 본문에 있다) | #194 | `plain:` 의 재비판 경로가 합성기 하나다(`to_adjudication_doc` 의 `nf = dict(a)` 가 칸을 통째로 넘긴다 — 코드는 안 고치고 테스트만). code-recritic 본문의 added 문장 · 출력 예시에 칸을 더한다 |
| `verdict.py` 가 판정 줄(`qg: <판정> · 막는 지적 N · 선택 M · 차등 새 실패 K · 제외 패치 X · iter N · <sha>`)을 렌더 | #194 | 판정 줄은 이미 쉬운 말이다 — 고치지 않는다 |
| `security-reviewer.md` 의 confidence 제거 · 출력 키 집합을 `test_security_reviewer_behavior.py` 가 잰다 | #194 | Task 3 고정 단언: 선택 칸 `plain` 을 그 키 집합에 들인다(옛 계획에 없던 자리) |
| `build_codex_prompt.py` 의 confidence 제거 · 기준 블록 · 의도 블록 | #194 | JSON 형식 블록의 `"summary"` 줄은 그대로라 `plain` 줄 더하기는 같다 |
| `check-trivia.sh` · `scout.py` 삭제 | #194 | 해당 없음 |
| `/qg-publish` · `publishing-pr-understanding` · `pr-understanding-builder` 삭제, 파이프라인이 판정 뒤 sink `publish-comment.sh` 로 한 번 게시(`## Publish`), 게시 펜스가 Final verdict 표의 결과 값(`OUTCOME`)을 읽는다 | #196 | 완료 표의 결과 칸은 토큰 그대로(R15). 완료 보고의 「할 일 하나」는 게시 결과 줄 뒤(그 줄은 「스크립트 출력의 마지막」). README 쓰는 법 표에 `/qg-publish` 행이 없다(R17) |
| 공개 소개 문구를 게시 모양으로 바꿈(`each run posts one new PR comment …`) · `shared/tests/test_plugin_description_parity.sh`(PR 4) | #195 · #196 | Task 4 의 옛 소개 문구 · 새 문안(R17) · 실행 목록에 같음 락 |
| README 대폭 정리(460줄) — 상태도가 상자 그림에서 트리로, `## 사용` 은 그대로 | #194 · #196 | 상태도 편집을 트리의 세 줄로(Task 1) |
| `setup-qg.sh` — 배너 둘째 줄 문구만 바뀜(`Pipeline: scope → review → differential test → synthesis · verdict`), git 최상위로 이동 · 자기 세션 폴더 재생성 | #194 · #196 | 배너 편집의 옛 글자만 바꿈. 오류 줄 R10 은 같은 줄 |
| `commands/qg.md` — 라벨을 부르는 문장이 「분류표와 함께 `Retry` / …」로, 「Retry 는 「적용」 항목만 고친다」가 붙음 | #194 | Task 1 의 qg.md 편집을 새 글자로 |
| `commands/cancel-qg.md` · `hooks/` · `/qg branch <name>` 삭제 | #189 (310ce78f 에 이미) | 옛 계획에서 이미 뺐다 |
| quality-gates 12.0.0 · spec-distill 5.1.1 · plugin-audit 1.1.0 · project-init 5.0.2 | #194 · #195 · #196 | 그때의 목표 12.1.0 · 5.1.2 — ④ 가 12.1.0 을 먼저 가져가 지금은 12.2.0 · 5.1.2(Global Constraints 「버전」) |

**#194 · #196 이 이미 한 일이라 뺀 단계:**

1. 옛 Task 2 의 「확신 높은 지적 없음 · 숨긴 지적 N개」 첫 줄 조각 · 꼬리의 「확신 4 이하 지적 N개를 숨겼다」 · `*` 표지 뜻 줄 · `--show-low-confidence` 안내 삭제(R11) — #194 가 억제를 통째로 지웠다.
2. 옛 Task 2 의 표 머리 「확신」 칸 — #194 가 confidence 칸을 지웠다(새 표 머리는 넷).
3. 옛 Task 3 의 `recritic_bridge.py` 경로 테스트(④ `prepare --findings … --out-map`) — 다리가 사라져 합성기의 `prepare` · `--recritic` 로 옮겼다(같은 뜻의 단언, 블록 이름 `qg-recritic`).
4. 옛 Task 3 의 「(합성기가 5 로 채운다)」 앵커와 「`model:` override … (upstream model pinning is respected).」 앵커 — 둘 다 #194 가 지웠다(R3 · R4 를 새 자리로).
5. 옛 Task 4 의 쓰는 법 표 `/qg-publish` 행 · 소개 문구 둘째 문장(「/qg-publish separately posts …」) — #196 이 명령을 지웠다(R17).
6. 판정 줄을 쉬운 말로 만드는 일 — #194 의 `verdict.py` 가 이미 「막는 지적 · 선택 · 차등 새 실패 · 제외 패치」로 낸다(설계에 따로 단계가 없었고, 이 계획도 손대지 않는다).
7. 옛 Task 1 의 「`are explicit: "Abort retry" …`」 라벨 설명 편집 — #194 가 그 문장을 지웠다.

그 밖에 #194 · #196 이 이 계획의 대상 문구(질문 셋 · 선택지 · 완료 표 칸 이름 · 범위 줄 · trivia 줄 · 범위 경고 · 합성기 머리 · 배너 · setup 오류 · `plain:`)를 대신 쉬운 말로 바꿔 둔 자리는 없다.

## baba7d19 뒤 트리가 바뀐 것

이 계획은 baba7d19 에서 한 번 드라이런한 뒤 브랜치가 main 3a8d7d1d(qg v10 ④ e2e 걷기, #197 — quality-gates 12.1.0)를 merge 했다(88a763c2). ④ 가 바꾼 것 중 이 계획에 닿는 것만 적는다(`git diff --stat baba7d19 88a763c2 -- plugins shared .claude-plugin` — 30 파일). 이 계획의 옛 글자(앵커)는 둘(소개 문구 헌장 락 · qg 버전)만 움직였고 나머지는 줄 번호만 밀렸다.

| 바뀐 것 | 이 계획에서 |
|---|---|
| SKILL 에 `## e2e` 절(E0~E5 — 질문 · 부팅 · 걷기 · 걷기 직후 게이트 · 기록, :733-882) 신설. E4 의 fail 행 불릿 · 첫 문장 · 끝 문장이 옛 Fix-loop 라벨(**Retry** · **Accept** · **Stop**, 「Stop 없이 끝나면」 · 「Accept / Stop / pass 로 뒤집기」)을 부른다 | Task 1 이 그 자리를 새 라벨로(R18). 개념어 Retry 는 그대로(R19). 새 락 ⑧ · 변이 셀 열다섯 |
| `references/e2e.md` 신설 — 5 절 게이트 표의 fail 행 「Fix-loop 게이트(Retry / Accept / Stop)」 · 6 절 결과 표 「fail 에서 Accept」 · 「fail 에서 Stop」 · 「루프가 Stop(aborted)…」 | Task 1 이 같은 라벨로(R18). e2e 질문 · 선택지 · 판정안 문구는 이미 한국어다(R20) |
| SKILL `## Flow` 에 e2e 두 줄(Fix-loop 줄 바로 뒤 — 「Retry 면 …」) · Preflight 펜스에 `e2e-state.sh stop` · `## Final verdict` 첫 문단과 판정 펜스(`--prior` · `--e2e`) · 기록 펜스에 `## e2e` · `## 뒤집기` 두 줄 · kill switch 색인 · Rules 문단 · Requirement index 다섯 행 | 이 계획이 바꾸는 글자(흐름 그림 첫 줄 · 완료 표 · 「지적」 앵커 · 끝 문단)는 그대로 — 줄 번호만 밀렸다(SKILL 932 → 1098줄). 「Retry 면」 은 개념어(R19). SKILL 의 `question:` 줄은 여전히 넷이다 — e2e 질문 · 게이트는 레퍼런스의 산문이다 |
| `verdict.py` 의 `--e2e` · `--prior` · `e2e-unconfirmed` 사유 · 판정 줄의 `e2e <칸>` | 판정 줄은 이미 쉬운 말이다 — 손대지 않는다. e2e 칸 값은 토큰(R20) |
| `setup-qg.sh` 에 남은 e2e 앱 정리 넷 줄(:235-238 — 사람용 줄은 이미 한국어, `${E2E_STOP_OUT}` 중괄호) | 이 계획의 대상 줄은 그대로. 배너 줄이 :255-265 → :259-269 |
| README — LD3 · C4 문장, P4 원칙 줄, 파이프라인 표 ④ 행, 상태도에 `├ e2e ──` 줄(라벨 줄 바로 뒤), 사전 요건 e2e, 노브, 보안 문단 · 알려진 한계, kill switch 표 두 행(460 → 481줄) | 이 계획의 README 편집(첫 문단 · 흐름 첫 문단 · 상태도 세 줄 · `## 사용`)은 그대로 맞는다. 첫 문단 · `/qg` 행에 e2e 한 구절(R21). README 락 목록에 `test_e2e_docs.sh` 의 README 단언을 더한다 |
| `commands/qg.md` — Quick Reference 에 `DISABLE_E2E` 행 · Pipeline 에 e2e 불릿(이미 한국어) | 이 계획의 qg.md 편집은 그대로 — 줄만 밀렸다(:108 · :110 · :125 · :135) |
| 소개 문구에 「+ optional human-approved e2e walk」 · `test_charter_citations.sh` 의 `QG_DESC` · quality-gates 12.1.0 · CHANGELOG `## [12.1.0] — 2026-10-11` · SKILL 제목 `(v12.1.0)` | Task 4 의 옛 소개 문구 · 버전 상수(`12.1.0` · `## [12.1.0] — 2026-10-11`) · 새 버전 12.2.0. 새 소개 문구에 e2e 한 구절(R21). 제목도 올린다(R22) |
| 새 테스트 `test_e2e_docs.sh` · `test_e2e_state.sh` · `test_e2e_verdict.sh` · `test_e2e_fixture_app.sh`, 바뀐 테스트 `test_one_pipeline_surface.sh`(절 순서 핀) · `test_skill_run_contract.sh`(`<e2e 칸>`) · `test_verdict_vocabulary.sh`(사유 열둘) · `test_setup_qg.sh` · `test_publish_pipeline_wiring.sh` | `test_e2e_docs.sh` 를 Task 1 · 2 · 4 의 실행 목록에(SKILL `## e2e` · 기록 펜스 · README 를 읽는다). 고정 단언 갱신은 없다(라벨 · 이 계획의 대상 글자를 재지 않는다) |

## qg v10 차등 계획과의 충돌

④(e2e)는 들어왔다(「baba7d19 뒤 트리가 바뀐 것」). `docs/superpowers/plans/2026-10-08-qg-v10-c5-differential.md`(⑤)는 아직 실행 전이다 — **둘째로 머지되는 쪽이 맞춘다**. 이 PR 이 먼저 머지되면 ⑤ 의 편집 단언이 아래 자리에서 터지거나(⑤ 의 규칙대로 「같은 뜻의 자리로 옮겨 적용하고, 뜻이 달라졌으면 멈추고 보고」) 이 PR 의 새 락이 RED 를 낸다. 반대로 ⑤ 가 먼저면 이 계획의 Task 0 Step 1 이 `QG-V10-5-MERGED` 를, Step 2 가 `STOP` 을 낸다 — 이 계획을 그 트리에 맞춰 다시 쓴다(넷째 열).

| ⑤ 의 자리 | 둘이 함께 만지는 파일 · 자리 | 이 PR 이 먼저면 ⑤ 가 다시 할 것 | ⑤ 가 먼저면 이 계획이 다시 할 것 |
|---|---|---|---|
| Task 9 Step 3 — `--plan` 제거: `setup-qg.sh` 의 `--plan)` arm(:70-75)과 배너의 계획 파일 줄(:265-267) · `commands/qg.md` 의 argument-hint · Quick Reference `/qg --plan <path>` 행 · SKILL :116 · :586 | 이 PR 이 쉬운 말로 바꾼 `--plan` 오류 줄(R10)과 「계획 파일: ${PLAN_FILE}」 줄, README `## 쓰는 법` 의 `/qg --plan <path>` 행, `test_plain_synth_output.sh` ⑦ · ⑧ 의 `--plan docs/p.md` 인자 · 「계획 파일」 두 단언 · `--plan` 오류 단언, `test_plain_readme.sh` 의 `/qg --plan` 행 단언 · 「「친다」 칸 허용 목록」의 그 항목 · 「행 다섯」 개수 | 그 두 줄을 지우고(⑤ 의 grep 이 `--plan` arm 을 자리로 찾는다), `test_plain_synth_output.sh` 의 `--plan` 인자 · 단언 셋을 지우고, README 표의 그 행 · `test_plain_readme.sh` 의 행 단언 · 허용 목록 항목을 지우고 개수를 6 → 5(머리 포함)로. ⑤ 의 `test_removed_plan_arg.sh` 는 `assert_not_contains … "Plan file:"` 로 값을 쓰지 않음을 잰다 — 이 PR 뒤에는 그 줄이 「계획 파일:」이라 **그 부재 단언이 공허해진다** — 「계획 파일:」도 함께 잰다 | `pr3_t2_edit.py` 의 `--plan` 오류 · 계획 파일 편집 둘, `pr3_t4_edit.py` 의 `/qg --plan` 행, 두 락의 해당 단언, `pr3_mut.py` 의 「--plan 오류를 영어만으로」 · 「계획 파일 줄을 영어로」 · 「README 표에서 한 행 지우기」 셀을 뺀다(앵커 `STOP` 이 그 자리를 짚는다) |
| Task 0 Step 4 · Task 10 — 개념 별칭 스윕(`aliases-c5.sh` — `'--plan'` · `'plan_path'` 등을 `git ls-files` 의 quality-gates · shared 전체에서 센다, 허용 자리는 ⑤ Task 10 의 표) | 이 PR 의 새 락 둘(`test_plain_synth_output.sh` · `test_plain_readme.sh`)이 `--plan` 글자를 담는다 | 별칭 스윕 결과에 새 락 둘이 나온다 — 위 행대로 그 단언을 지우면 사라진다(허용 표에 더하지 않는다) | 없음 |
| Task 7 — SKILL `## Differential test` 절 교체 · 옛 차등 토큰 정리(Final verdict 펜스의 `K=` 줄 · `$RD/aggregate.yaml` 경로 · 기록 펜스의 「## 차등 테스트」 줄) | SKILL Final verdict 의 `result.md` 기록 펜스 — 이 PR 은 같은 `{ … } >> "$RD/result.md"` 블록의 「## 지적」 줄(`^\| 심각도 \|`)을 바꾸고, ⑤ 는 「## 차등 테스트」 줄을 바꾼다. 완료 표(이 PR)와 `K=` 줄(⑤)은 같은 절의 다른 펜스다 | 글자 충돌 없음(이웃 줄). ⑤ 의 토큰 정리 grep 이 이 PR 의 줄을 잡지 않는지만 본다 | 앵커가 그대로면 할 것 없음 |
| Task 9 Step 6 — 옛 절차 문면 락 정리(`drop_cases.py` 가 `test_pipeline_verdict_wiring.sh` · `test_topic_scope_wiring.sh` · `test_one_pipeline_surface.sh` · `test_verdict_vocabulary.sh` 의 케이스를 지운다) | 이 PR 의 고정 단언 갱신 자리(`test_pipeline_verdict_wiring.sh` 의 `case_n5_and_retry_cover_differential_origin` · `test_topic_scope_wiring.sh:28` 의 도우미 · `:224` 의 `case_trivia_escape_is_gated_by_declaration` · `test_one_pipeline_surface.sh` 의 `case_no_gate_scope_question`) | 글자 충돌 없음 — ⑤ 가 지우는 케이스 목록에 이 자리는 없다(드라이런 실측). 지우는 케이스가 이웃이면 merge 가 줄 단위로 겹칠 수 있다 — 그 파일만 손으로 맞춘다 | 앵커가 그대로면 할 것 없음 |
| Task 9 Step 4 — `build_codex_prompt.py` · `run_codex_reviewer.sh` 의 `DISABLE_SPEC_CONFORMANCE` 제거 · SKILL :135 · :369 · :586 · :1043 | `build_codex_prompt.py`. 이 PR 은 `PROMPT_TEMPLATE` 의 JSON 블록에 `"plain"` 줄을 더한다(:78 뒤) | 글자 충돌 없음 | 없음 |
| Task 10 — README 차등 서술 · kill switch 표의 `DISABLE_SPEC_CONFORMANCE` 행 · 「인자 설명의 `--plan`」 · CHANGELOG · `plugin.json`(major) | README · 버전. ⑤ 가 「인자 설명의 `--plan`」으로 찾는 자리가 이 PR 뒤에는 `## 쓰는 법` 표의 행이다 | 그 행을 지운다(첫 행). 버전을 머지 직전에 다시 정한다 | `pr3_t4_edit.py` 의 버전 상수 넷 |

④ 는 ⑤ 의 Task 0 Step 2(「## ④ e2e」 신호)가 이미 본다 — 이 PR 이 ④ 의 e2e 문면 라벨을 바꿔도 그 신호(`e2e-state.sh` · `## e2e` 절 · `e2e-unconfirmed`)는 그대로다. Task 0 Step 1 이 ⑤ 머지 여부를 신호로 본다(`setup-qg.sh` 의 `--plan)` arm 없음).

## Review Focus

1. **`plain:` 이 없는(또는 공백뿐인) 지적** — 외부 리뷰어는 칸을 안 채울 수 있다. 사람은 그 지적이 사라지지 않고 지금처럼 요약으로 보이길 기대한다. → `test_plain_field_path.sh` ②(변이 「렌더가 칸 없는 지적을 건너뛰기」 · 「공백뿐인 plain 을 있는 것으로」 → RED).
2. **`plain:` 값에 표 칸을 깨는 글자(`|` · 개행)** — 사람은 표가 깨지지 않길 기대한다. → `test_plain_field_path.sh` ⑥(기존 `_cell` 을 지난다 — 행 수와 이스케이프 모양 둘 다).
3. **판정과 무관한 상태 줄이 `verdict:` 를 품는다** — 쉬운 첫 줄에 `verdict: clean` 같은 글자가 들어가면 판정 줄이 둘이 된다. → `test_plain_synth_output.sh` ⑤ 와 Task 2 변이 「첫 줄에 verdict: clean 넣기」(AC5).
4. **합성기 표 머리만 바뀌고 SKILL 앵커는 옛 글자** — `result.md` 의 「지적」 절과 게시 이해글의 재료가 조용히 「(없음)」이 된다. → `test_plain_synth_output.sh` ⑥(SKILL 의 grep 앵커 · sed 범위 · 「고칠 방법」 이름을 SKILL 에서 뽑아 합성기 출력에 대 본다 — 변이 셋).
5. **두 리뷰어가 같은 지적을 내고 하나만 `plain:` 을 썼다** — 합칠 때 칸이 사라지지 않길 기대한다. → `test_plain_field_path.sh` ⑦(코드 경로: 먼저 온 쪽이 남는다 — 그쪽에 칸이 없으면 합쳐진 다른 쪽 중 먼저 온 쪽의 칸을 물려받는다, 남는 쪽에 칸이 있으면 덮어쓰지 않는다 · 비코드 경로: 같은 규칙).
6. **버린 주장 · 경고가 있는 실행의 첫 줄** — 사람은 첫 줄만 읽고 「지적 없음」으로 끝내지 않기를 기대한다. → `test_plain_synth_output.sh` ③ · ④(R12 · R16 — 표가 있는 갈래와 없는 갈래 둘 다).
7. **「멈추기」를 고른 실행** — 사람은 PR 코멘트가 달리지 않는다는 것을 고르기 전에 알기를 기대한다. → 선택지 설명(「PR 코멘트도 달지 않는다」)과 완료 표 결과 칸 토큰(게시 펜스의 `aborted*`, R15).
8. **재비판자가 리뷰어의 쉬운 말에 끌린다** — `plain:` 은 리뷰어의 결론을 풀어 쓴 문장이다. → `test_plain_field_path.sh` ②(익명 목록에 `plain` 이 없다 — 변이 「익명 목록에 plain 싣기」).
9. **e2e 걷기 직후 게이트가 옛 이름을 부른다** — 사람은 루프에서 본 선택지 이름(「고치고 다시 돌기」 · 「지금 판정으로 끝내기」 · 「멈추기」)을 걷기 뒤 게이트에서도 보길 기대한다. → `test_plain_qg_templates.sh` ⑧(SKILL `## e2e` 창 · `references/e2e.md` — 창이 비면 양성 짝이 RED, 변이 열다섯).

---

## Task 0: 착수 준비

- [ ] **Step 1: 트리가 88a763c2 인지, ④ 는 들어왔고 ⑤ 는 아직인지 확인한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
mkdir -p ~/.claude/sdd-mirror/plain-language-output/pr3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3
git status --porcelain
git fetch origin main
git merge-base --is-ancestor origin/main HEAD && echo MAIN-IN-HEAD || echo "MAIN-MOVED $(git rev-list --count HEAD..origin/main)"
git diff --stat 88a763c2 HEAD -- plugins shared tools .claude-plugin CLAUDE.md | tail -1
test -f plugins/quality-gates/scripts/e2e-state.sh && echo QG-V10-4-MERGED || echo QG-V10-4-NOT-MERGED
grep -cx '## e2e' plugins/quality-gates/skills/quality-pipeline/SKILL.md
grep -q -- '--plan)' plugins/quality-gates/scripts/setup-qg.sh && echo QG-V10-5-NOT-MERGED || echo QG-V10-5-MERGED
```

기대: status 는 비었거나 이 계획 파일 한 줄뿐 · `MAIN-IN-HEAD` · diff --stat 빈 출력 · `QG-V10-4-MERGED` · `1`(SKILL 의 `## e2e` 절) · `QG-V10-5-NOT-MERGED`. `MAIN-MOVED <n>` 이면 merge 하지 말고 멈춰 보고한다(`git diff --stat HEAD...origin/main -- plugins/quality-gates shared .claude-plugin` 를 함께). `QG-V10-4-NOT-MERGED` 면 트리가 이 계획보다 뒤다(④ 를 되돌린 트리) — 멈춰 보고한다. `QG-V10-5-MERGED` 면 이 계획은 그 트리에 맞춰 다시 써야 한다(「qg v10 차등 계획과의 충돌」의 넷째 열).

- [ ] **Step 2: 이 계획의 옛 글자가 그대로인지 본다**

아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_anchor_check.sh` 에 그대로 쓰고 돌린다. 줄마다 기대 개수(기본 1, 셋째 인자가 있으면 그 값)와 다르면 `STOP` 이다. `plain` 0 줄 넷은 「아직 아무도 칸을 넣지 않았다」, 310 줄 검사는 R14 의 EXEMPT 자리다.

````bash
#!/usr/bin/env bash
# PR 3 Task 0 Step 2 — 이 계획이 바꾸는 옛 글자가 기대 개수만큼 있는지(grep -cF) 센다. 줄마다 ok 또는 STOP.
set -u
R="${R:-/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice}"
c() { n="$(grep -cF -- "$2" "$R/$1")"; e="${3:-1}"; [ "$n" = "$e" ] && s=ok || s=STOP; printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$n" "$1" "$2" "(기대 ${e})"; }
Q=plugins/quality-gates
S=$Q/skills/quality-pipeline/SKILL.md
T=$Q/tests
# Task 1 — SKILL
c "$S" ' │   막는 지적 또는 차등 defect → Fix-loop (Retry / Accept and finish / Stop)'
c "$S" '건너뛴다: `Trivia diff — pipeline skipped (<한 문장 설명>).` 을 보이고'
c "$S" '`> Review scope: session (<COUNT> changed files). 전체 PR/브랜치는 /qg branch.`'
c "$S" '`> Review scope: topic <topic_key> (<COUNT> changed files · 구성원 <branches>).`'
c "$S" 'scope check degraded (detached HEAD / no base branch / unrelated history / shallow) — empty-scope detection skipped'
c "$S" 'question: "qg iter N: findings remain (<summary>). What next?",'
c "$S" '        {label: "Retry",             description: "Apply the 적용 items of the table'
c "$S" 'description: "표의 적용/제외로 Retry 한다."'
c "$S" '**Retry 옵션 문구 — 차등 테스트 기원(`blocking: 0`)에는 그대로 쓰지 않는다.**'
c "$S" '- **Retry** → apply only the 적용 items'
c "$S" '- **Accept and finish** → [Final verdict](#final-verdict) with Outcome'
c "$S" '- **Stop** → Final verdict with Outcome `aborted iter N`.'
c "$S" 'question: "qg reached max 5 iterations. Last findings: <summary>. Finish with the current verdict or stop?",'
c "$S" 'Branch on answer: **Accept and finish** → Final verdict with Outcome `accepted with findings iter 5`;'
c "$S" 'question: "Retry failed at <file>: <reason>. Abort the retry iteration, or skip this file and continue with the remaining patches?",'
c "$S" '| "$QG/scripts/render-terminal.py" table --title "Quality Gates — Complete"'
c "$S" "printf 'Verdict\\t%s\\nIterations\\t<N>\\nOutcome\\t<finished | accepted with findings iter N | aborted iter N>\\n'"
c "$S" "Then run [Publish](#publish) — the publish result line is the run's last output."
c "$S" 'finished|"accepted with findings iter "[0-9]*|"aborted iter "[0-9]*) ;;'
c "$S" 'question:' 4
# Task 1 — SKILL `## e2e`(④) · references/e2e.md 가 부르는 옛 라벨
E2R=$Q/references/e2e.md
n="$(grep -cx '## e2e' "$R/$S")"; [ "$n" = 1 ] && s=ok || s=STOP; printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$n" "$S" '## e2e (줄 전체)' "(기대 1 — ④ 의 절)"
c "$S" '리뷰·테스트 루프가 Stop 없이 끝나면 최종 판정 전에 이 절을 한 번 돈다. 루프가 Stop 으로 끝났으면(aborted) 이 절을'
c "$S" '- **Retry** (fail 행) — `## Fix-loop` 의 Retry 와 같다:'
c "$S" '  다시 돈다. 루프가 다시 Stop 없이 끝나면 이 절로 돌아오고,'
c "$S" '- **Accept** (fail 행) — `## Final verdict` 로 간다.'
c "$S" '- **Stop** (fail 행) — `## Fix-loop` 의 Stop 과 같다:'
c "$S" '다시 돈 뒤, Retry 와 같은'
c "$S" '- iteration 5 를 다 썼으면 Retry · 리뷰·테스트부터 다시 를 선택지에 넣지 않는다. 그때 fail 행은 Accept / Stop / pass 로'
c "$S" '그다음 `## Final verdict` 로 간다(Retry · 리뷰·테스트부터 다시 · 다시 걷기면 위 E4 의 경로로).'
c "$E2R" '| fail | Fix-loop 게이트(Retry / Accept / Stop) + pass 로 뒤집기 |'
c "$E2R" '남은 iteration 이 없으면 Retry 를 넣지 않는다.'
c "$E2R" '| fail 에서 Accept | `fail` | 아니오 |'
c "$E2R" '| fail 에서 Stop | `fail` | 아니오 |'
c "$E2R" '| 루프가 Stop(aborted) 으로 끝나 e2e 를 건너뜀 |'
c "$E2R" 'fail 에서 Stop 을 고르면 실행은 aborted'
c $Q/skills/critiquing-artifacts/SKILL.md '## 종료 & 최종 요약 (AC11)'
c $Q/commands/qg.md '`Review scope: session (N files)`'
c $Q/commands/qg.md '`Review scope: topic <키> (N files · 구성원 <branches>)`'
c $Q/commands/qg.md '분류표와 함께 `Retry` / `Accept and finish` / `Stop` 로 사용자가 진행을 정한다(최대 5회). Retry 는 「적용」 항목만 고친다.'
c $Q/commands/qg.md 'iteration boundary with `Retry` / `Accept and finish` / `Stop`.'
c $Q/README.md ' │   막는 지적 또는 차등 defect → AskUserQuestion ("findings remain…")'
c $Q/README.md ' │       분류표(항목마다 적용 / 제외 + 사유) · Retry / Accept and finish / Stop'
c $T/e2e-scenarios.md '- `Review scope: topic …` 한 줄.'
c $T/test_skill_orchestration.sh 'findings remain' 4
c $T/harness/test_skill_orchestration_behavior.sh 'findings remain' 2
c $T/test_one_pipeline_surface.sh "assert_grep     \"\$headers\" 'qg iter N'"
c $T/test_readme_state_diagram_complete.sh '  "findings remain"'
c $T/test_pipeline_verdict_wiring.sh "note = seg(r'\\*\\*Retry 옵션 문구"
c $T/test_pipeline_verdict_wiring.sh "bullet = seg(r'- \\*\\*Retry\\*\\* →"
c $T/test_pipeline_verdict_wiring.sh '리뷰어가 낸 값을 그대로 옮긴다'
c $T/test_topic_scope_wiring.sh 'Trivia diff — pipeline skipped' 2
c $T/test_v_requirements.sh "'Retry failed at <file>'"
c $T/test_v_requirements.sh 'question: "qg reached max 5 iterations'
# Task 2 — 합성기 · SKILL 의 표 자리 · setup
SY=$Q/scripts/synthesize_findings.py
c "$SY" 'out = ["## Review Findings (Synthesized)", "", counts_line,'
c "$SY" 'out.insert(3, "No findings.")'
c "$SY" 'f"{dropped_malformed} finding(s) dropped as "'
c "$SY" 'f"{dropped_malformed} finding(s) dropped as malformed "'
c "$SY" 'out.append("| Sev | Path:Line | Summary | Source |")'
c "$SY" "out.append(f\"| {sev} | {path_line} | {_cell(f.get('summary', ''))} | {source} |\")"
c "$SY" 'out.append("**Suggested fixes:**")'
c "$SY" 'fix = str(f.get("proposed_fix", "(none)"))'
c "$SY" '        if scope is not None:'
c "$SY" 'def render(findings, dropped_malformed, report, held_classes, recritic_zero=False, *, blocking):'
c "$SY" 'plain' 0
c "$S" "grep -q '^| Sev |' \"\$SYN\"; then sed -n '/^| Sev |/,/^\$/p' \"\$SYN\";"
c "$S" 'the `**Suggested fixes:**` list carries the same `#k`'
SE=$Q/scripts/setup-qg.sh
c "$SE" 'setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1'
c "$SE" '❌ Error: --paths requires at least one glob'
c "$SE" '❌ Error: --plan requires a file path argument'
c "$SE" '❌ Error: --session-id requires an argument'
c "$SE" '❌ Error: Unknown argument: $1'
c "$SE" 'Use --help for usage information'
c "$SE" '❌ Quality Gates: cannot create pipeline state — session ID is empty.'
c "$SE" "fails pattern guard ([A-Za-z0-9_-]{8,})."
c "$SE" 'echo "🔄 Quality Gates Pipeline"'
c "$SE" 'echo "Pipeline: scope → review → differential test → synthesis · verdict"'
c "$SE" 'echo "Plan file: $PLAN_FILE"'
c "$SE" 'echo "Pipeline runs in this turn."'
c $T/e2e-scenarios.md '(`setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1`)'
c $T/test_synthesize_findings.sh "'No findings\\.' 'a\\.py:10'"
c $T/test_synthesize_findings.sh "'No findings\\. blocking: 0 optional: 0'"
c $T/test_synthesize_findings.sh "'\\| Sev \\| Path:Line \\| Summary \\| Source \\|'"
c $T/test_synthesize_findings.sh "'1 finding\\(s\\) dropped as malformed"
c $T/test_synthesize_disposition.sh "assert_grep \"\$OUT_BP\" 'No findings\\.'"
c $T/test_synthesize_findings_adjudication.py 'self.assertIn("No findings.", clean)'
c $T/test_synthesize_promoted_findings.sh "grep -qE '^2 finding\\(s\\) dropped as malformed'" 2
c $T/test_synthesize_promoted_findings.sh "grep -qE '^1 finding\\(s\\) dropped as malformed'"
c $T/test_v_requirements.sh "'^1 finding\\(s\\) dropped as malformed"
c $T/test_angle_coverage.sh '    /^angles:$/ { skip = n; next }'
# 처분 회계 — dedup 의 continue 가 EXEMPT 키의 줄(310)에 있다(그 위에 줄을 넣지 않는다)
c tools/adjudication/check_wiring.py '("plugins/quality-gates/scripts/synthesize_findings.py", 310,'
l310="$(sed -n '310p' "$R/$SY")"; [ "$l310" = "            continue" ] && s=ok || s=STOP; printf '%s\t-\t%s\t%s\t%s\n' "$s" "$SY:310" "${l310}" "(기대 dedup 의 continue)"
# Task 3 — plain 칸
c shared/codex/codex_findings_to_yaml.py 'DEFAULT_KEYS = ("file", "line", "severity", "confidence", "summary", "proposed_fix")'
c $Q/agents/security-reviewer.md '  summary: <one-sentence describing the vulnerability and its path>'
c $Q/agents/code-recritic.md '`summary` · `proposed_fix` 를 싣는다. 막는 지적의 기준은 프로필 뒤에 붙은 「리뷰 기준」 블록이다.'
c $Q/agents/code-recritic.md '    summary: "..."'
c $Q/agents/artifact-critic.md '    summary: "one sentence"'
c $Q/agents/artifact-adversarial.md '    summary: "..."'
c $Q/scripts/build_codex_prompt.py '      "summary": "<one sentence>",'
c $Q/scripts/build_artifact_codex_prompt.py '    summary: "one sentence"'
c $Q/references/recritic-code-profile.md '- `added` 항목은 `file` · `line` · `severity` · `summary` · `proposed_fix` 를 싣는다. `file` 은 리포 상대 경로다.'
c "$S" 'SUGGESTION — by the criteria block), summary, proposed_fix.'
c "$S" '   never trust an `agent:` a reviewer wrote. Do not copy a `confidence:` field.'
c $Q/scripts/synthesize_artifact_findings.py '"severity", "summary", "proposed_fix", "dedup_key", "stagnation_key")'
c $Q/scripts/synthesize_artifact_findings.py '"severity", "summary", "proposed_fix", "dedup_key")'
c $Q/scripts/synthesize_artifact_findings.py 'by_key[k]["severity"] = g["severity"]'
c "$SY" 'merged = dict(group[0])'
c "$SY" 'def sort_findings(findings):'
c $T/test_security_reviewer_behavior.py 'FINDING_KEYS = {"agent", "file", "line", "severity", "summary", "proposed_fix"}'
c $T/test_security_reviewer_behavior.py '        self.assertEqual(keys, FINDING_KEYS)'
c $T/test_security_reviewer_behavior.py '            self.assertEqual(set(e), FINDING_KEYS)'
c $Q/agents/security-reviewer.md 'plain' 0
c $Q/agents/code-recritic.md 'plain' 0
# Task 4 — README · 소개 문구 · 버전
c $Q/README.md 'Claude Code용 품질 검증 파이프라인 — 한 파이프라인, 한 판정(`clean` · `defect` · `not-certified (<사유>)`). 기준선 대비 차등 테스트는 매 실행 돈다.'
c $Q/README.md '## 사용'
c $Q/README.md '`quality-pipeline` SKILL이 전체 파이프라인을 단일 assistant turn 내에서 serial dispatch로 실행합니다.'
c $Q/README.md 'qg-publish' 0
c $Q/.claude-plugin/plugin.json '"description": "Quality verification pipeline — one pipeline, one verdict'
c .claude-plugin/marketplace.json '"description": "Quality verification pipeline — one pipeline, one verdict'
c shared/tests/test_charter_citations.sh 'QG_DESC = ("Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test + optional human-approved e2e walk) "'
c $Q/.claude-plugin/plugin.json '"version": "12.1.0",'
c plugins/spec-distill/.claude-plugin/plugin.json '"version": "5.1.1",'
c $Q/CHANGELOG.md '## [12.1.0] — 2026-10-11'
c "$S" '# Quality Gates — In-Turn Orchestrator (v12.1.0)'
c plugins/spec-distill/CHANGELOG.md '## [5.1.1] — 2026-10-10'
````

```bash
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_anchor_check.sh > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/anchor.out
grep -c '^ok' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/anchor.out
grep -v '^ok' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/anchor.out
python3 shared/entry/check_invocation_surface.py --report | grep -c '^| [0-9]'
```

기대(드라이런 실측): `124`, 빈 출력, `15`. `STOP` 이 하나라도 있으면 그 줄의 Task 로 가기 전에 멈춰 보고한다.

- [ ] **Step 3: 기준선**

88a763c2 의 기준선은 드라이런이 깨끗한 복사본에서 떠 두었다: `~/.claude/sdd-mirror/plain-language-output/pr3/baseline-d/`(`summary.tsv` · `failures.txt` · `logs/`, 268 파일, rc≠0 은 harness 하나(FAIL 「R1b→R8 unclaimed 집행 사슬」) — 그 회차의 `test_codex_backward_compat.sh` rc=1(실패 줄 0)은 흔들림이라 단독 재실행이 4/4 로 통과했다). Step 1 의 diff --stat 이 비었으면 그것을 쓴다. 아니면 다시 뜬다(약 50분, 그동안 이 워크트리에서 테스트를 돌리지 않는다):

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr3/baseline-d
```

- [ ] **Step 4: 실행 도구 둘**

테스트 실행기 — `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh`:

````bash
#!/bin/bash
# rt.sh <리포 루트 상대 테스트 경로>... — 리포 루트에서 하나씩 돌린다(동시 실행 금지 — 고정 /tmp 경로가 경쟁한다).
# 줄마다: 이름 · rc · 실패 줄 수 · 로그 끝줄. 로그는 $LOGS/<basename>.log 에 남는다.
# .py 는 그 tests 디렉토리에서 unittest, .mjs 는 리포 루트에서 node --test(tap), 나머지는 bash.
R="${R:-/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice}"
LOGS="${LOGS:-/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/logs}"
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

변이 실행기 — `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py`(각 Task 의 마지막 Step 이 부른다):

````python
#!/usr/bin/env python3
"""PR 3 변이 셀 — 커밋한 뒤에 돈다.   pr3_mut.py <리포 루트> <t1|t2|t3|t4>
먼저 양성 대조: 이 Task 의 셀이 부르는 테스트를 깨끗한 HEAD 에서 하나씩 돌려 전부 rc=0 인지 본다(하나라도 RED 면
모든 셀이 공허하게 RED 다 — 멈춘다). 그다음 셀마다: 새 글자를 정확히 한 번 바꾸고, 지정한 테스트를 하나씩 리포
루트 기준으로 돌려 rc 를 적고, `git checkout HEAD -- <파일>` 로 되돌린 뒤 `git diff HEAD --stat` 이 비었는지 본다.
기대: 셀마다 「RED」(지정 테스트 중 하나 이상 rc≠0). 「SURVIVED」 가 하나라도 있으면 그 락에 이빨이 없다.
「SKIP」 은 바꿀 글자가 정확히 한 번이 아니라는 뜻이다 — 셀이나 편집이 어긋났다(실패로 센다).
harness(`tests/harness/test_skill_orchestration_behavior.sh`)는 선재 RED 로 rc 가 이미 1 이라 셀의 테스트로 쓰지 않는다."""
import os, subprocess, sys

R = os.path.abspath(sys.argv[1])
TASK = sys.argv[2]
Q = "plugins/quality-gates/"
QT = Q + "tests/"
S = Q + "skills/quality-pipeline/SKILL.md"
CA = Q + "skills/critiquing-artifacts/SKILL.md"
QGMD = Q + "commands/qg.md"
RM = Q + "README.md"
E2R = Q + "references/e2e.md"
SY = Q + "scripts/synthesize_findings.py"
SE = Q + "scripts/setup-qg.sh"
ART = Q + "scripts/synthesize_artifact_findings.py"
CONV = "shared/codex/codex_findings_to_yaml.py"
AG = Q + "agents/"
TPL = QT + "test_plain_qg_templates.sh"
SYN = QT + "test_plain_synth_output.sh"
FLD = QT + "test_plain_field_path.sh"
RDM = QT + "test_plain_readme.sh"
CHARTER = "shared/tests/test_charter_citations.sh"
PARITY = "shared/tests/test_plugin_description_parity.sh"

MUTS = {
    "t1": [
        ("Fix-loop 질문을 영어로", S, 'question: "qg 반복 N: 남은 지적이 있다(<summary>). 어떻게 할까?",',
         'question: "qg iter N: findings remain (<summary>). What next?",', [TPL, QT + "test_skill_orchestration.sh"]),
        ("최대 반복 질문을 영어로", S, 'question: "qg 가 최대 5번 반복했다. 마지막 지적: <summary>. 지금 판정으로 끝낼까, 멈출까?",',
         'question: "qg reached max 5 iterations. Last findings: <summary>. Finish with the current verdict or stop?",', [TPL, QT + "test_v_requirements.sh"]),
        ("수정 실패 질문을 영어로", S, 'question: "<file> 수정에 실패했다: <reason>. 이번 수정 반복을 멈출까, 이 파일만 건너뛰고 나머지를 계속할까?",',
         'question: "Retry failed at <file>: <reason>. Abort the retry iteration, or skip this file and continue with the remaining patches?",', [TPL, QT + "test_v_requirements.sh"]),
        ("라벨 하나를 영어로", S, '{label: "멈추기",               description: "이 반복에서',
         '{label: "Stop",               description: "이 반복에서', [TPL]),
        ("머리글을 영어로", S, 'header: "qg 반복 N",', 'header: "qg iter N",', [TPL, QT + "test_one_pipeline_surface.sh"]),
        ("분류 설명이 옛 라벨을 부르게", S, 'description: "표의 적용/제외대로 고친다."', 'description: "표의 적용/제외로 Retry 한다."', [TPL]),
        ("멈추기 설명에서 「게시 없음」 지우기", S, '"이 반복에서 멈춘다 — PR 코멘트도 달지 않는다. 지적을', '"이 반복에서 멈춘다. 지적을', [TPL]),
        ("Fix-loop 분기 불릿을 옛 라벨로", S, "- **고치고 다시 돌기** → apply only", "- **Retry** → apply only", [TPL, QT + "test_pipeline_verdict_wiring.sh"]),
        ("최대 반복 분기를 옛 라벨로", S, "**멈추기** → Final verdict with Outcome `aborted iter 5`", "**Stop** → Final verdict with Outcome `aborted iter 5`", [TPL]),
        ("차등 기원 안내의 옵션 이름을 옛 것으로", S, "**「고치고 다시 돌기」 옵션 문구 — 차등", "**Retry 옵션 문구 — 차등", [TPL, QT + "test_pipeline_verdict_wiring.sh"]),
        ("흐름 그림에서 Retry 묶음 지우기", S, "Fix-loop (고치고 다시 돌기(Retry) / ", "Fix-loop (고치고 다시 돌기 / ", [TPL]),
        ("완료 표 제목을 영어로", S, '--title "Quality Gates — 끝"', '--title "Quality Gates — Complete"', [TPL]),
        ("완료 표 결과 칸을 한국어 낱말로(게시 펜스 토큰과 어긋남)", S, "결과\\t<finished | accepted with findings iter N | aborted iter N>",
         "결과\\t<끝났다 | 지적을 남기고 끝냈다(반복 N) | 멈췄다(반복 N)>", [TPL]),
        ("완료 보고 첫 문장 지우기", S, "The completion report opens — before the table — with one Korean sentence: how the run ended (the 결과 cell in plain words) and the verdict value as-is (e.g. 「qg 를 반복 2번 만에 끝냈다 — 판정 defect, 남은 지적을 둔 채 끝냈다.」). ",
         "", [TPL]),
        ("「개수를 다시 풀지 않는다」 지우기", S, " The counts stay in the verdict line — do not restate them.", "", [TPL]),
        ("「할 일 하나」를 뒤집기", S, "end with exactly one next action for the user", "end with a list of every next action for the user", [TPL]),
        ("게시 줄을 «실행의» 마지막 출력으로 되돌리기", S, "the publish result line is the run's last script output.", "the publish result line is the run's last output.", [TPL]),
        ("trivia 줄을 영어로", S, "`작은 수정이라 파이프라인을 건너뛰었다(trivia diff) — <한 문장 설명>.`",
         "`Trivia diff — pipeline skipped (<한 문장 설명>).`", [TPL, QT + "test_topic_scope_wiring.sh"]),
        ("session 범위 줄을 영어로", S, "`> 리뷰 범위: 이번 세션에서 바뀐 파일 <COUNT>개. 브랜치 전체를 보려면 /qg branch.`",
         "`> Review scope: session (<COUNT> changed files). 전체 PR/브랜치는 /qg branch.`", [TPL]),
        ("topic 범위 줄을 영어로", S, "`> 리뷰 범위: 토픽 <topic_key> — 바뀐 파일 <COUNT>개 · 구성원 <branches>.`",
         "`> Review scope: topic <topic_key> (<COUNT> changed files · 구성원 <branches>).`", [TPL]),
        ("범위 경고에서 토큰 지우기", S, "범위를 확인하지 못했다(scope check degraded — detached", "범위를 확인하지 못했다(detached", [TPL]),
        ("범위 경고 꼬리를 영어로", S, "바뀐 파일이 0개인지 보는 검사를 건너뛰었다(fail-open).", "empty-scope detection skipped (fail-open).", [TPL]),
        ("qg.md 라벨 나열 한 자리를 옛 것으로", QGMD, "iteration boundary with `고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기`.",
         "iteration boundary with `Retry` / `Accept and finish` / `Stop`.", [TPL]),
        ("qg.md 고치는 범위 문장을 옛 라벨로", QGMD, "「고치고 다시 돌기」는 「적용」 항목만 고친다.", "Retry 는 「적용」 항목만 고친다.", [TPL]),
        ("qg.md 범위 줄 설명을 영어로", QGMD, "`리뷰 범위: 이번 세션에서 바뀐 파일 N개.`", "`Review scope: session (N files)`", [TPL]),
        ("비평 보고 첫 줄 문장 지우기", CA, "보고의 첫 줄은 끝났는지와 결과 한 문장이다(", "보고는 (", [TPL]),
        ("비평 보고 plain 우선 뒤집기", CA, "그것을 먼저 쓰고 원래 `summary` 는 뒤 괄호에 둔다", "원래 `summary` 를 먼저 쓰고 그것은 뒤 괄호에 둔다", [TPL]),
        ("비평 보고 끝 할 일 지우기", CA, " 맨 끝에 사용자가 할 일 하나를 쓴다.", "", [TPL]),
        ("README 상태도 질문 표지를 영어로", RM, '("남은 지적이 있다…")', '("findings remain…")', [QT + "test_readme_state_diagram_complete.sh"]),
        ("README 상태도 라벨을 옛 것으로", RM, "· 고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기\n", "· Retry / Accept and finish / Stop\n", [TPL]),
        ("e2e 게이트 「고치고 다시 돌기」 불릿을 옛 라벨로", S, "- **고치고 다시 돌기** (fail 행) — `## Fix-loop` 의 「고치고 다시 돌기」와 같다:",
         "- **Retry** (fail 행) — `## Fix-loop` 의 Retry 와 같다:", [TPL]),
        ("e2e 게이트 「지금 판정으로 끝내기」 불릿을 옛 라벨로", S, "- **지금 판정으로 끝내기** (fail 행)", "- **Accept** (fail 행)", [TPL]),
        ("e2e 게이트 「멈추기」 불릿을 옛 라벨로", S, "- **멈추기** (fail 행) — `## Fix-loop` 의 「멈추기」와 같다:",
         "- **Stop** (fail 행) — `## Fix-loop` 의 Stop 과 같다:", [TPL]),
        ("e2e 무효 행의 경로를 옛 라벨로", S, "다시 돈 뒤, 「고치고 다시 돌기」와 같은", "다시 돈 뒤, Retry 와 같은", [TPL]),
        ("e2e 최대 반복 선택지를 옛 라벨로", S, "그때 fail 행은 지금 판정으로 끝내기 / 멈추기 / pass 로", "그때 fail 행은 Accept / Stop / pass 로", [TPL]),
        ("e2e 절 첫 문장을 옛 라벨로", S, "리뷰·테스트 루프가 「멈추기」 없이 끝나면", "리뷰·테스트 루프가 Stop 없이 끝나면", [TPL]),
        ("e2e 재걷기 조건을 옛 라벨로", S, "루프가 다시 「멈추기」 없이 끝나면", "루프가 다시 Stop 없이 끝나면", [TPL]),
        ("e2e 절 끝 문장을 옛 라벨로", S, "(고치고 다시 돌기 · 리뷰·테스트부터 다시 · 다시 걷기면", "(Retry · 리뷰·테스트부터 다시 · 다시 걷기면", [TPL]),
        ("e2e 레퍼런스 게이트 표를 옛 라벨로", E2R, "Fix-loop 게이트(고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기)", "Fix-loop 게이트(Retry / Accept / Stop)", [TPL]),
        ("e2e 레퍼런스 결과 표 「멈추기」를 옛 라벨로", E2R, "| fail 에서 멈추기 |", "| fail 에서 Stop |", [TPL]),
        ("e2e 레퍼런스 「넣지 않는다」를 옛 라벨로", E2R, "「고치고 다시 돌기」를 넣지 않는다.", "Retry 를 넣지 않는다.", [TPL]),
        ("e2e 레퍼런스 aborted 문장을 옛 라벨로", E2R, "fail 에서 「멈추기」를 고르면", "fail 에서 Stop 을 고르면", [TPL]),
        ("e2e 절 머리 앵커 옮기기(창이 빈다)", S, "\n## e2e\n", "\n## e2e 걷기\n", [TPL]),
        ("e2e 절에 옛 선택지 이름 더하기(새 글자는 그대로)", S, "- **지금 판정으로 끝내기** (fail 행) — `## Final verdict` 로 간다.",
         "- **지금 판정으로 끝내기** (fail 행) — `## Final verdict` 로 간다(Accept 와 같다).", [TPL]),
        ("e2e 레퍼런스에 옛 결과 행 더하기(새 행은 그대로)", E2R, "| fail 에서 멈추기 | `fail` | 아니오 |\n",
         "| fail 에서 멈추기 | `fail` | 아니오 |\n| fail 에서 Stop | `fail` | 아니오 |\n", [TPL]),
    ],
    "t2": [
        ("0 인 등급을 빼지 않기", SY, "            if counts[k]:\n                parts.append", "            if True:\n                parts.append", [SYN]),
        ("첫 줄에 verdict: clean 넣기", SY, 's = "리뷰를 합쳤다 — 지적 없음."', 's = "리뷰를 합쳤다 — 지적 없음. verdict: clean"', [SYN]),
        ("상태 첫 줄을 render 에서 빼기", SY, '    out = [_status_line(counts, dropped_malformed, report["degraded"], blocking),\n           "## 리뷰 지적',
         '    out = [\n           "## 리뷰 지적', [SYN, QT + "test_synthesize_findings.sh"]),
        ("버린 수를 첫 줄에서 빼기", SY, '        s += " 형식이 깨져 버린 지적 %d개." % dropped_malformed', "        pass", [SYN]),
        ("막는 경고를 첫 줄에서 빼기", SY, '            s += " 판정을 막는 경고가 있다 — 아래를 본다."', "            pass", [SYN]),
        ("막지 않는 경고를 첫 줄에서 빼기", SY, '            s += " 판정을 막지 않는 경고가 있다 — 아래를 본다."', "            pass", [SYN]),
        ("경고 갈래 뒤집기", SY, "        if blocking:\n            s += \" 판정을 막는", "        if not blocking:\n            s += \" 판정을 막는", [SYN]),
        ("표 머리를 영어로", SY, '"| 심각도 | 위치 | 내용 | 낸 곳 |"', '"| Sev | Path:Line | Summary | Source |"', [SYN, QT + "test_synthesize_findings.sh"]),
        ("고칠 방법 머리를 영어로", SY, '"**고칠 방법:**"', '"**Suggested fixes:**"', [SYN]),
        ("빈 고칠 방법을 영어로", SY, '"(없음)"))', '"(none)"))', [SYN]),
        ("빈 분기 버린 지적 줄에서 토큰 지우기", SY,
         '형식이 깨졌다(dropped as malformed — 매핑이 아니거나, "\n                "목록이어야',
         '형식이 깨졌다(— 매핑이 아니거나, "\n                "목록이어야', [SYN, QT + "test_v_requirements.sh", QT + "test_skill_drop_notice_consumed.sh"]),
        ("표 분기 버린 지적 줄에서 토큰 지우기", SY,
         '형식이 깨졌다(dropped as malformed — 매핑이 아니거나, "\n            "목록이어야',
         '형식이 깨졌다(— 매핑이 아니거나, "\n            "목록이어야', [SYN, QT + "test_synthesize_promoted_findings.sh"]),
        ("빈 분기 버린 지적 줄을 영어로", SY,
         'f"{dropped_malformed}개 지적을 버렸다 — 형식이 깨졌다(dropped as malformed — 매핑이 아니거나, "\n                "목록이어야',
         'f"{dropped_malformed} finding(s) dropped as malformed (매핑이 아니거나, "\n                "목록이어야', [SYN]),
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
        ("SKILL 표 앵커를 옛 영어로(grep · sed 둘 다)", S, "grep -q '^| 심각도 |' \"$SYN\"; then sed -n '/^| 심각도 |/,/^$/p'",
         "grep -q '^| Sev |' \"$SYN\"; then sed -n '/^| Sev |/,/^$/p'", [SYN]),
        ("SKILL 표 sed 범위만 옛 영어로", S, "then sed -n '/^| 심각도 |/,/^$/p'", "then sed -n '/^| Sev |/,/^$/p'", [SYN]),
        ("SKILL Step 5 고칠 방법 이름을 옛 영어로", S, "the `**고칠 방법:**` list carries", "the `**Suggested fixes:**` list carries", [SYN]),
        ("배너 첫 줄을 영어로", SE, 'echo "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다."', 'echo "🔄 Quality Gates Pipeline"', [SYN]),
        ("배너에 과정 나열 되살리기", SE, 'echo "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다."',
         'echo "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다."\necho "Pipeline: scope → review → differential test → synthesis · verdict"', [SYN]),
        ("계획 파일 줄을 영어로", SE, 'echo "계획 파일: ${PLAN_FILE}"', 'echo "Plan file: ${PLAN_FILE}"', [SYN]),
        ("--paths 오류를 영어만으로", SE, 'echo "❌ --paths 뒤에 glob 이 하나도 없다(--paths requires at least one glob)." >&2',
         'echo "❌ Error: --paths requires at least one glob" >&2', [SYN]),
        ("--paths 오류에서 토큰 지우기", SE, '(--paths requires at least one glob)." >&2', '." >&2', [SYN, QT + "test_setup_qg.sh"]),
        ("--plan 오류를 영어만으로", SE, 'echo "❌ --plan 뒤에 파일 경로가 없다(--plan requires a file path argument)." >&2',
         'echo "❌ Error: --plan requires a file path argument" >&2', [SYN]),
        ("--session-id 오류를 영어만으로", SE, 'echo "❌ --session-id 뒤에 값이 없다(--session-id requires an argument)." >&2',
         'echo "❌ Error: --session-id requires an argument" >&2', [SYN]),
        ("모르는 인자 오류에서 토큰 지우기", SE, 'echo "❌ 모르는 인자다(Unknown argument): $1" >&2', 'echo "❌ 모르는 인자다: $1" >&2', [SYN]),
        ("모르는 인자 안내 줄을 영어로", SE, 'echo "   쓰는 법은 --help 로 본다." >&2', 'echo "   Use --help for usage information" >&2', [SYN]),
        ("세션 ID 없음 오류를 영어로", SE, "❌ Quality Gates: 세션 ID(session ID)가 비어 있어 상태 폴더를 만들 수 없다.",
         "❌ Quality Gates: cannot create pipeline state — session ID is empty.", [SYN]),
        ("세션 ID 모양 오류에서 토큰 지우기", SE, "이 아니다(fails pattern guard).\" >&2", "이 아니다.\" >&2", [SYN, QT + "test_precheck_retired.sh"]),
        ("kill switch 거부 줄을 영어로", SE, 'echo "[quality-gates] DEVBREW_QUALITY_GATES_DISABLE=1 이 켜져 있어 /qg 를 시작하지 않는다(setup-qg disabled)." >&2',
         'echo "[quality-gates] setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1" >&2', [SYN]),
    ],
    "t3": [
        ("plain 없는 지적을 건너뛰기", SY, '    for f in findings:\n        srcs = f.get("sources") or [f.get("agent", "?")]',
         '    for f in findings:\n        if not f.get("plain"):\n            continue\n        srcs = f.get("sources") or [f.get("agent", "?")]', [FLD]),
        ("plain 을 요약 뒤로", SY, 'summary = _cell(f"{plain} ({f.get(\'summary\', \'\')})")', 'summary = _cell(f"{f.get(\'summary\', \'\')} ({plain})")', [FLD]),
        ("공백뿐인 plain 을 있는 것으로", SY, "        if isinstance(plain, str) and plain.strip():", "        if isinstance(plain, str):", [FLD]),
        ("kept 허용 목록에서 plain 빼기", ART, '"severity", "summary", "plain", "proposed_fix", "dedup_key")', '"severity", "summary", "proposed_fix", "dedup_key")', [FLD]),
        ("key 허용 목록에서 plain 빼기", ART, '"severity", "summary", "plain", "proposed_fix", "dedup_key", "stagnation_key")',
         '"severity", "summary", "proposed_fix", "dedup_key", "stagnation_key")', [FLD]),
        ("codex 변환기에서 plain 빼기", CONV, '"summary", "proposed_fix", "plain")', '"summary", "proposed_fix")', [FLD]),
        ("코드 합치기에서 물려받기 지우기", SY, '                if _has_plain(g):\n                    merged["plain"] = g["plain"]\n', "                pass\n", [FLD]),
        ("코드 합치기를 «나중 쪽이 이김» 으로", SY, "            for g in reversed(group[1:]):", "            for g in group[1:]:", [FLD]),
        ("코드 합치기가 남는 쪽 plain 을 덮어쓰게", SY, "        if not _has_plain(merged):\n            for g", "        if True:\n            for g", [FLD]),
        ("비코드 합치기에서 물려받기 지우기", ART, '                if not by_key[k].get("plain") and g.get("plain"):\n                    by_key[k]["plain"] = g["plain"]\n', "", [FLD]),
        ("익명 목록에 plain 싣기(프레이밍 누설)", SY, '            if g.get("proposed_fix"):\n                item["proposed_fix"] = str(g.get("proposed_fix"))\n',
         '            if g.get("proposed_fix"):\n                item["proposed_fix"] = str(g.get("proposed_fix"))\n'
         '            if g.get("plain"):\n                item["plain"] = str(g.get("plain"))\n', [FLD]),
        ("보안 리뷰어 형식에서 plain 빼기", AG + "security-reviewer.md",
         "  plain: <optional — the same finding in one plain sentence a first-time reader understands, no internal IDs>\n", "",
         [FLD, QT + "test_security_reviewer_behavior.py"]),
        ("code-recritic added 문장에서 plain 빼기", AG + "code-recritic.md",
         "`plain`(선택)에는 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장을 — 내부 번호 없이 — 쓴다. ", "", [FLD]),
        ("code-recritic 예시에서 plain 빼기", AG + "code-recritic.md", '    plain: "선택 — 처음 보는 사람이 읽을 쉬운 한 문장"\n', "", [FLD]),
        ("artifact-critic 형식에서 plain 빼기", AG + "artifact-critic.md",
         '    plain: "optional — the same finding in one plain sentence for a first-time reader, no internal IDs"\n', "", [FLD]),
        ("artifact-adversarial 형식에서 plain 빼기", AG + "artifact-adversarial.md",
         '    plain: "optional — one plain sentence for a first-time reader, no internal IDs"\n', "", [FLD]),
        ("codex 빌더에서 plain 빼기", Q + "scripts/build_codex_prompt.py",
         '      "plain": "<optional: the same finding in one plain sentence a first-time reader understands, no internal IDs>",\n', "", [FLD]),
        ("artifact codex 빌더에서 plain 빼기", Q + "scripts/build_artifact_codex_prompt.py",
         '    plain: "optional — the same finding in one plain sentence for a first-time reader, no internal IDs"\n', "", [FLD]),
        ("재비판 프로필에서 「내부 번호 없이」 지우기", Q + "references/recritic-code-profile.md", "쉬운 한 문장으로 — 내부 번호 없이 — 쓴다.", "쉬운 한 문장으로 쓴다.", [FLD]),
        ("외부 리뷰어 프롬프트에서 plain 빼기", S,
         "summary, plain (optional — the same finding in one plain sentence a\nfirst-time reader understands, no internal IDs), proposed_fix.", "summary, proposed_fix.", [FLD]),
        ("오케스트레이터 옮겨 적기 지우기", S, "   **각 항목의 `plain:` 은 리뷰어가 쓴 문장 그대로 싣는다** — 없으면 키를 뺀다(지어내지 않는다).\n", "", [FLD]),
        ("오케스트레이터가 plain 을 지어내게", S, "— 없으면 키를 뺀다(지어내지 않는다).", "— 없으면 요약을 보고 지어 넣는다.", [FLD]),
    ],
    "t4": [
        ("plugin.json 소개 문구 한 글자", Q + ".claude-plugin/plugin.json", "Checks a change before you ship it:", "Checks a change before you ship it;", [CHARTER, PARITY]),
        ("marketplace 소개 문구 한 글자", ".claude-plugin/marketplace.json", "Checks a change before you ship it:", "Checks a change before you ship it;", [CHARTER, PARITY]),
        ("README 쓰는 법 머리글을 옛 것으로", RM, "## 쓰는 법\n", "## 사용\n", [RDM]),
        ("README 첫 문장을 옛 것으로", RM, "바뀐 코드를 내보내기 전에 확인한다.", "Claude Code용 품질 검증 파이프라인.", [RDM]),
        ("README 첫 문단의 게시 문장 지우기", RM, " 브랜치에 열린 PR 이 있으면 판정 뒤 쉬운 설명과 판정 줄을 코멘트 하나로 단다(`DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` 로 끈다).", "", [RDM]),
        ("README 첫 문단의 e2e 문장 지우기", RM, " 원하면 판정 전에 사람이 승인한 명령으로 앱을 띄워 직접 걸어 본다(e2e 걷기).", "", [RDM]),
        ("README /qg 행의 e2e 질문 지우기", RM, "고칠지 묻고(최대 5번), 판정 전에 앱을 띄워 걸어 볼지 묻는다.", "고칠지 묻는다(최대 5번).", [RDM]),
        ("README 표에 없어진 게시 명령 행 되살리기", RM, "| 문서 · 설계 · 설정을 비평받을 때 |",
         "| 판정 뒤 PR 에 설명을 올릴 때 | `/qg-publish` | 미리보기 → 승인 → 게시 |\n| 문서 · 설계 · 설정을 비평받을 때 |", [RDM]),
        ("README 표에서 한 행 지우기", RM, "| 특정 계획 파일로 테스트를 고르게 할 때 | `/qg --plan <path>` | 그 계획을 차등 테스트 분류 기준으로 쓴 판정 |\n", "", [RDM]),
        ("README 흐름 문단을 옛 것으로", RM, "파이프라인은 한 턴 안에서 끝까지 돈다(`quality-pipeline` SKILL 이 리뷰어를 차례로 부른다).",
         "`quality-pipeline` SKILL이 전체 파이프라인을 단일 assistant turn 내에서 serial dispatch로 실행합니다.", [RDM]),
    ],
}


def sh(args, cwd=R):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")


def run_test(t):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    if t.endswith(".py"):
        p = subprocess.run([sys.executable, "-m", "unittest", os.path.basename(t)[:-3]], cwd=os.path.join(R, os.path.dirname(t)),
                           capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    else:
        p = subprocess.run(["bash", t], cwd=R, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    return p.returncode


def main():
    if sh(["git", "diff", "HEAD", "--stat"]).stdout.strip():
        sys.exit("STOP: 작업 트리가 HEAD 와 다르다 — 커밋한 뒤에 변이한다")
    cells = MUTS[TASK]
    tests = []
    for cell in cells:
        for t in cell[4]:
            if t not in tests:
                tests.append(t)
    base_red = []
    for t in tests:
        if run_test(t) != 0:
            base_red.append(t)
    if base_red:
        print("BASE-RED\t%s" % " ".join(base_red))
        sys.exit("STOP: 양성 대조 실패 — 깨끗한 HEAD 에서 이미 RED 인 테스트가 있다(셀이 공허하게 RED 가 된다)")
    print("BASE-GREEN\t%d tests" % len(tests))
    red = survived = skip = 0
    for name, rel, old, new, cell_tests in cells:
        path = os.path.join(R, rel)
        s = open(path, encoding="utf-8").read()
        if s.count(old) != 1:
            print("SKIP\t%s\t%s\t(옛 글자 %d번)" % (name, rel, s.count(old)))
            skip += 1
            continue
        try:
            open(path, "w", encoding="utf-8").write(s.replace(old, new))
            rcs = [run_test(t) for t in cell_tests]
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

---

## Task 1: 질문 셋 · 완료 표 · 모델이 그대로 내는 문구 (AC6 · R15 · R18)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — 151(흐름 그림의 Fix-loop 라벨) · 178(trivia 줄) · 240(범위 줄 둘) · 557(범위 경고) · 633-638(Fix-loop 질문) · 646(분류 선택지 설명) · 659-662(차등 기원 옵션 문구) · 665 · 669 · 670(분기 불릿) · 680-684 · 692-693(최대 반복 질문 · 분기) · 719-723(수정 실패 질문) · 735 · 848-856 · 882(`## e2e` 의 첫 문장 · E4 불릿 · 끝 문장 — R18) · 929-930(완료 표) · 943 뒤(완료 보고 한 문장)
- Modify: `plugins/quality-gates/references/e2e.md:87 · :93 · :113-114 · :124 · :126`(게이트 표의 fail 행 · 「넣지 않는다」 · 결과 표 · aborted 문장 — R18)
- Modify: `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:283` 뒤(최종 보고 틀 머리에 한 단락)
- Modify: `plugins/quality-gates/commands/qg.md:108-110 · :125 · :135`(범위 줄 설명 · 라벨을 부르는 세 자리 — 지시문은 그대로, 부르는 글자만)
- Modify: `plugins/quality-gates/README.md:236-238`(상태도의 질문 표지와 라벨 — `test_readme_state_diagram_complete.sh` 가 이 Task 에서 새 낱말을 재므로 같은 커밋)
- Modify: `plugins/quality-gates/tests/e2e-scenarios.md:195`(topic 범위 줄을 인용한다)
- Create: `plugins/quality-gates/tests/test_plain_qg_templates.sh`
- Modify(고정 단언): Step 2 의 표

- [ ] **Step 1: 실패하는 락을 쓴다**

`plugins/quality-gates/tests/test_plain_qg_templates.sh`:

````bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/critiquing-artifacts/SKILL.md plugins/quality-gates/commands/qg.md plugins/quality-gates/README.md plugins/quality-gates/references/e2e.md
#
# 쉬운 말 출력 설계 §4 · AC6 — /qg 의 질문 셋 · 완료 표 · 모델이 그대로 내는 문구가 한국어이고,
# 완료 보고와 비평 최종 보고가 첫 줄 상태 · 끝 할 일 하나를 지시받는다. e2e 걷기 직후 게이트(④)가
# 부르는 Fix-loop 선택지도 같은 라벨이다.
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
RM="$PLUGIN_ROOT/README.md"
E2R="$PLUGIN_ROOT/references/e2e.md"
# 산문은 줄바꿈을 지운 본문에서 잰다 — 다시 쓰일 때 문장이 줄을 넘을 수 있다.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
qlines() { grep -E '^[[:space:]]*question:' "$1"; }
SF="$(flat "$S")"

# ① 질문 — question 줄에서 잰다(새 문구 양성 · 옛 영어 부재 · 분류 질문은 그대로)
assert_grep "$(qlines "$S")" 'question: "qg 반복 N: 남은 지적이 있다\(<summary>\)\. 어떻게 할까\?"' "AC6: Fix-loop 질문이 한국어다"
assert_grep "$(qlines "$S")" 'question: "qg 가 최대 5번 반복했다\. 마지막 지적: <summary>\. 지금 판정으로 끝낼까, 멈출까\?"' "AC6: 최대 반복 질문이 한국어다"
assert_grep "$(qlines "$S")" 'question: "<file> 수정에 실패했다: <reason>\. 이번 수정 반복을 멈출까, 이 파일만 건너뛰고 나머지를 계속할까\?"' "AC6: 수정 실패 질문이 한국어다"
assert_grep "$(qlines "$S")" 'question: "분류표의 적용/제외를 바꿀까요\?' "분류 질문은 그대로 있다(양성 짝)"
assert_not_grep "$(qlines "$S")" 'findings remain|What next|reached max|Retry failed at' "AC6: 영어 질문이 남지 않았다"
assert_eq "$(qlines "$S" | grep -c .)" "4" "AC6: 이 SKILL 의 question 줄은 넷이다(새로 생기거나 사라진 질문 없음)"

# ② 선택지 라벨 · 머리글 — 새 라벨 양성 · 옛 라벨 부재
for l in '고치고 다시 돌기' '지금 판정으로 끝내기' '멈추기' '이번 반복 멈추기' '이 파일만 건너뛰기' '분류표 그대로'; do
  assert_file_grep "$S" "label: \"${l}\"" "AC6: 선택지 라벨 「${l}」"
done
assert_file_absent "$S" 'label: "(Retry|Accept and finish|Stop|Abort retry|Skip this file)"' "AC6: 영어 선택지 라벨이 없다"
for h in 'qg 반복 N' '수정 실패' 'qg 최대 반복' '분류'; do
  assert_file_grep "$S" "header: \"${h}\"" "AC6: 머리글 「${h}」"
done
assert_file_absent "$S" 'header: "(qg iter N|qg max-iter|Retry)"' "AC6: 영어 머리글이 없다"
assert_file_grep "$S" 'description: "표의 적용/제외대로 고친다\."' "AC6: 분류 선택지 설명이 새 라벨 이름 없이 동작을 말한다"
assert_file_absent "$S" '표의 적용/제외로 Retry 한다' "AC6: 분류 선택지 설명이 옛 라벨을 부르지 않는다"
assert_contains "$SF" '{label: "멈추기", description: "이 반복에서 멈춘다 — PR 코멘트도 달지 않는다.' "규칙 블록: 멈추기 설명이 달라지는 것(게시 없음)을 말한다"

# ③ 분기 문장의 굵은 라벨이 새 라벨을 부른다(옛 라벨을 부르면 모델이 없는 선택지를 찾는다)
for l in '고치고 다시 돌기' '지금 판정으로 끝내기' '멈추기'; do
  assert_file_grep "$S" "^- \\*\\*${l}\\*\\* →" "AC6: Fix-loop 분기 불릿 「${l}」"
done
assert_file_absent "$S" '^- \*\*(Retry|Accept and finish|Stop)\*\* →' "AC6: 옛 Fix-loop 분기 불릿이 없다"
assert_contains "$SF" 'Branch on answer: **지금 판정으로 끝내기** → Final verdict with Outcome `accepted with findings iter 5`; **멈추기** → Final verdict with Outcome `aborted iter 5`.' "AC6: 최대 반복 분기가 새 라벨을 부른다"
assert_not_contains "$SF" '**Accept and finish** →' "AC6: 옛 Accept 분기가 없다"
assert_contains "$SF" '**「고치고 다시 돌기」 옵션 문구 — 차등 테스트 기원' "AC6: 차등 기원 안내가 새 옵션 이름을 부른다"
assert_contains "$SF" 'Fix-loop (고치고 다시 돌기(Retry) / 지금 판정으로 끝내기 / 멈추기)' "흐름 그림이 새 라벨을 부르고 이 파일의 Retry 가 어느 선택지인지 묶는다"
assert_not_contains "$SF" 'Fix-loop (Retry / Accept and finish / Stop)' "흐름 그림에 옛 라벨 나열이 없다"

# ④ 완료 표 · 완료 보고
assert_file_grep "$S" 'render-terminal\.py" table --title "Quality Gates — 끝"' "AC6: 완료 표 제목이 한국어다"
assert_file_absent "$S" 'Quality Gates — Complete' "AC6: 옛 완료 표 제목이 없다"
assert_file_grep "$S" "^printf '판정\\\\t%s\\\\n반복\\\\t<N>번\\\\n결과\\\\t<finished \\| accepted with findings iter N \\| aborted iter N>\\\\n'" "AC6 · R15: 완료 표 칸 이름이 한국어이고 결과 칸은 게시 펜스가 읽는 토큰 그대로다"
assert_file_absent "$S" "^printf 'Verdict" "AC6: 옛 영어 칸 이름이 없다"
assert_file_grep "$S" 'finished\|"accepted with findings iter "\[0-9\]\*\|"aborted iter "\[0-9\]\*\)' "R15: 게시 펜스가 같은 세 결과 토큰을 받는다(양성 짝)"
assert_contains "$SF" 'The completion report opens — before the table — with one Korean sentence: how the run ended (the 결과 cell in plain words) and the verdict value as-is' "§4: 완료 보고 첫 줄은 끝난 방식과 판정값"
assert_contains "$SF" 'The counts stay in the verdict line — do not restate them.' "규칙 블록: 개수를 다시 풀어 쓰지 않는다"
assert_contains "$SF" 'After the publish result line, end with exactly one next action for the user' "§4: 완료 보고 끝은 할 일 하나"
assert_contains "$SF" "the publish result line is the run's last script output." "게시 결과 줄은 스크립트 출력의 마지막이다(할 일 줄과 충돌하지 않는다)"
assert_not_contains "$SF" "the publish result line is the run's last output." "게시 줄이 «실행의» 마지막 출력이라는 옛 문장이 없다"

# ⑤ 모델이 그대로 내는 문구 — trivia 줄 · 범위 줄 · 범위 경고
assert_contains "$SF" '건너뛴다: `작은 수정이라 파이프라인을 건너뛰었다(trivia diff) — <한 문장 설명>.` 을 보이고' "AC6: trivia 줄이 한국어다"
assert_file_absent "$S" 'Trivia diff — pipeline skipped' "AC6: 옛 trivia 줄이 없다"
assert_file_grep "$S" '> 리뷰 범위: 이번 세션에서 바뀐 파일 <COUNT>개\. 브랜치 전체를 보려면 /qg branch\.' "AC6: session 범위 줄"
assert_file_grep "$S" '> 리뷰 범위: 토픽 <topic_key> — 바뀐 파일 <COUNT>개 · 구성원 <branches>\.' "AC6: topic 범위 줄"
assert_file_absent "$S" 'Review scope: (session|topic)' "AC6: 옛 범위 줄이 SKILL 에 없다"
assert_file_absent "$QGMD" 'Review scope: (session|topic)' "AC6: 옛 범위 줄이 qg.md 에 없다"
assert_file_grep "$QGMD" '리뷰 범위: 이번 세션에서 바뀐 파일 N개\.' "AC6: qg.md 가 새 session 범위 줄을 설명한다(양성 짝)"
assert_file_grep "$QGMD" '리뷰 범위: 토픽 <키> — 바뀐 파일 N개 · 구성원 <branches>\.' "AC6: qg.md 가 새 topic 범위 줄을 설명한다(양성 짝)"
assert_file_grep "$S" '범위를 확인하지 못했다\(scope check degraded — detached HEAD' "AC6: 범위 경고가 쉬운 말로 시작하고 토큰을 괄호에 둔다"
assert_file_grep "$S" '바뀐 파일이 0개인지 보는 검사를 건너뛰었다\(fail-open\)' "AC6: 범위 경고가 건너뛴 검사를 말한다"
assert_file_absent "$S" 'empty-scope detection skipped' "AC6: 옛 영어 범위 경고 꼬리가 없다"

# ⑥ qg.md 가 부르는 라벨
assert_eq "$(grep -cF '`고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기`' "$QGMD")" "2" "AC6: qg.md 가 새 라벨을 두 자리에서 부른다"
assert_file_absent "$QGMD" '`Retry` / `Accept and finish` / `Stop`' "AC6: qg.md 에 옛 라벨 나열이 없다"
assert_contains "$(flat "$QGMD")" '「고치고 다시 돌기」는 「적용」 항목만 고친다.' "AC6: qg.md 가 고치는 범위를 새 라벨로 말한다"
assert_not_contains "$(flat "$QGMD")" 'Retry 는 「적용」 항목만 고친다' "AC6: qg.md 에 옛 라벨 문장이 없다"

# ⑦ README 상태도가 같은 라벨을 부른다(질문 앵커 표지는 test_readme_state_diagram_complete.sh 가 잰다)
assert_file_grep "$RM" '분류표\(항목마다 적용 / 제외 \+ 사유\) · 고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기$' "AC6: README 상태도가 새 라벨을 부른다"
assert_file_absent "$RM" 'Retry / Accept and finish / Stop' "AC6: README 상태도에 옛 라벨 나열이 없다"

# ⑧ e2e 걷기 직후 게이트(④) — 선택지를 부르는 자리는 Fix-loop 와 같은 새 라벨이다.
# 반복 동작 이름으로서의 Retry(「고침은 Retry 로만」 등)는 지시문이라 그대로 둔다 — 여기서는 선택지 자리만 잰다.
E2S="$(awk '/^## e2e$/{f=1;next} f&&/^## /{exit} f' "$S")"
E2SF="$(printf '%s\n' "$E2S" | tr '\n' ' ' | tr -s ' ')"
assert_grep "$E2S" '^\*\*E4 — 걷기 직후 게이트\.\*\*' "e2e 절을 잘랐다(양성 짝 — 창이 비면 아래 부재 단언이 공허하다)"
for l in '고치고 다시 돌기' '지금 판정으로 끝내기' '멈추기'; do
  assert_grep "$E2S" "^- \\*\\*${l}\\*\\* \\(fail 행\\) — " "AC6: e2e 게이트 fail 행 불릿 「${l}」"
done
assert_not_grep "$E2S" '^- \*\*(Retry|Accept|Accept and finish|Stop)\*\* \(fail 행\)' "AC6: e2e 게이트에 옛 라벨 불릿이 없다"
assert_contains "$E2SF" '`## Fix-loop` 의 「고치고 다시 돌기」와 같다:' "AC6: e2e 「고치고 다시 돌기」가 Fix-loop 의 같은 선택지를 부른다"
assert_contains "$E2SF" '`## Fix-loop` 의 「멈추기」와 같다:' "AC6: e2e 「멈추기」가 Fix-loop 의 같은 선택지를 부른다"
assert_contains "$E2SF" '다시 돈 뒤, 「고치고 다시 돌기」와 같은 경로로 이 절에 돌아와' "AC6: 무효 행이 새 라벨의 경로를 부른다"
assert_contains "$E2SF" 'iteration 5 를 다 썼으면 고치고 다시 돌기 · 리뷰·테스트부터 다시 를 선택지에 넣지 않는다. 그때 fail 행은 지금 판정으로 끝내기 / 멈추기 / pass 로 뒤집기,' "AC6: 최대 반복의 e2e 선택지가 새 라벨이다"
assert_contains "$E2SF" '리뷰·테스트 루프가 「멈추기」 없이 끝나면 최종 판정 전에 이 절을 한 번 돈다. 루프가 「멈추기」로 끝났으면(aborted)' "AC6: e2e 절 첫 문장이 새 라벨을 부른다"
assert_contains "$E2SF" '루프가 다시 「멈추기」 없이 끝나면 이 절로 돌아오고' "AC6: 재걷기 조건이 새 라벨을 부른다"
assert_contains "$E2SF" '(고치고 다시 돌기 · 리뷰·테스트부터 다시 · 다시 걷기면 위 E4 의 경로로)' "AC6: e2e 절 끝 문장이 새 라벨을 부른다"
assert_not_grep "$E2S" 'Accept|Stop|\*\*Retry\*\*|Retry 와 같|Retry ·' "AC6: e2e 절이 옛 선택지 이름(Accept · Stop · 선택지로서의 Retry)을 부르지 않는다"
assert_file_grep "$E2R" '^\| fail \| Fix-loop 게이트\(고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기\) \+ pass 로 뒤집기 \|$' "AC6: e2e 레퍼런스 게이트 표의 fail 행이 새 라벨이다"
assert_file_grep "$E2R" '^\| fail 에서 지금 판정으로 끝내기 \| `fail` \| 아니오 \|$' "AC6: e2e 결과 표 「지금 판정으로 끝내기」 행"
assert_file_grep "$E2R" '^\| fail 에서 멈추기 \| `fail` \| 아니오 \|$' "AC6: e2e 결과 표 「멈추기」 행"
assert_file_grep "$E2R" '^\| 루프가 「멈추기」\(aborted\)로 끝나 e2e 를 건너뜀 \|' "AC6: e2e 결과 표의 건너뜀 행이 새 라벨을 부른다"
E2RF="$(flat "$E2R")"
assert_contains "$E2RF" '남은 iteration 이 없으면 「고치고 다시 돌기」를 넣지 않는다.' "AC6: e2e 레퍼런스가 넣지 않는 선택지를 새 라벨로 부른다"
assert_contains "$E2RF" 'fail 에서 「멈추기」를 고르면 실행은 aborted' "AC6: e2e 레퍼런스의 aborted 문장이 새 라벨을 부른다"
assert_file_absent "$E2R" 'Accept|Stop|Retry /|Retry 를 넣지' "AC6: e2e 레퍼런스에 옛 선택지 이름이 없다"

# ⑨ 비평 최종 보고
CAF="$(flat "$CA")"
assert_contains "$CAF" '보고의 첫 줄은 끝났는지와 결과 한 문장이다' "§4: 비평 최종 보고 첫 줄"
assert_contains "$CAF" '잔여 `kept` 항목에 `plain:` 이 있으면 그것을 먼저 쓰고 원래 `summary` 는 뒤 괄호에 둔다' "R7: 비평 보고가 plain 을 먼저 쓴다"
assert_contains "$CAF" '맨 끝에 사용자가 할 일 하나를 쓴다' "§4: 비평 최종 보고 끝 할 일 하나"
finish
````

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
chmod +x plugins/quality-gates/tests/test_plain_qg_templates.sh
```

- [ ] **Step 2: 고정 단언을 먼저 새 낱말로 바꾼다**

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_skill_orchestration.sh:35 · :36 · :39 · :41` | `findings remain` | `남은 지적이 있다` | 반복 경계 앵커가 정확히 한 질문에만 있다(라우팅 유일성) |
| `test_skill_orchestration.sh:45 · :46` | `Retry` · `Accept and finish` | `고치고 다시 돌기` · `지금 판정으로 끝내기` | Fix-loop 선택지가 있다(옛 `Retry` 단언은 「Retry: file-write safety」 머리글로도 만족돼 공허했다) |
| `harness/test_skill_orchestration_behavior.sh:377 · :382` | `question:.*findings remain` | `question:.*남은 지적이 있다` | 보이기(Step 4.5) 다음에 묻는다 |
| `test_one_pipeline_surface.sh:106` | 머리글 집합에 `qg iter N` | `qg 반복 N` | Fix-loop 결정 도구가 남아 있다(양의 짝) |
| `test_readme_state_diagram_complete.sh:39 · :57` | 표지 `findings remain` | 표지 `남은 지적이 있다` · 부재 목록에 `findings remain` 을 더함 | README 상태도가 질문을 그린다(옛 표지가 남지 않는다 — 양성 짝은 새 표지) |
| `test_pipeline_verdict_wiring.sh:550` | `\*\*Retry 옵션 문구` | `\*\*「고치고 다시 돌기」 옵션 문구` | 차등 기원(`blocking: 0`) 안내가 그 옵션 문구를 바꾸라고 말한다 |
| `test_pipeline_verdict_wiring.sh:554` | `- \*\*Retry\*\* →.*?(?=\n- \*\*Accept)` | `- \*\*고치고 다시 돌기\*\* →.*?(?=\n- \*\*지금 판정으로 끝내기)` | 분기 불릿이 차등 기원 경우를 갈라 말한다 |
| `test_topic_scope_wiring.sh:28 · :224` | `Trivia diff — pipeline skipped` | `작은 수정이라 파이프라인을 건너뛰었다` | 토픽 감지가 trivia 판단보다 먼저다 |
| `test_v_requirements.sh:110` | `Retry failed at <file>` | `<file> 수정에 실패했다` | V9 — Edit 실패는 묻는다(절 제목 `### Retry: error handling` 은 지시문이라 그대로) |
| `test_v_requirements.sh:157` | `question: "qg reached max 5 iterations\.` | `question: "qg 가 최대 5번 반복했다\.` | P18 — 최대 반복 질문이 상한 5 를 말한다 |

이 표는 `git grep -nF -- '<글자>' -- 'plugins/*/tests/*' 'shared/tests/*' 'tools/*'` 를 바뀌는 글자마다(`findings remain` · `Retry` · `Accept` · `Stop` · `fail 행` · `Fix-loop 게이트` · `fail 에서` · `Stop 없이` · `Accept /` · `Retry 와 같` · `qg iter N` · `max-iter` · `Abort retry` · `Skip this file` · `Complete` · `Verdict` · `Iterations` · `Outcome` · `Trivia diff` · `Review scope` · `scope check degraded` · `empty-scope detection` · `Final summary`) 정규식 이스케이프 꼴(`\*\*Retry\*\*`)까지 훑은 결과다. 그대로 GREEN 이어야 하는 것: 개념어 Retry 를 쓰는 단언(`test_runtime_verdict_precedence.sh:102` · `test_v_requirements.sh:108`(절 제목) · `test_qa_ledger.sh`) · `harness` 의 「degraded scope advisory present」(`scope check degraded` 토큰이 괄호에 남는다) · `test_publish_pipeline_wiring.sh`(Outcome 토큰 — R15) · `test_e2e_docs.sh`(④ — e2e 라벨 글자를 재지 않는다. 「Retry」 는 주석 한 줄뿐). 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t1_pins.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 1 — 바뀌는 문구를 고정한 기존 단언을 새 낱말로 (리포 루트를 인자로).
옛 글자가 전부 기대 개수만큼 있는지 먼저 다 재고, 하나라도 다르면 아무것도 쓰지 않고 STOP 한다."""
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
    (T + "test_one_pipeline_surface.sh", "assert_grep     \"$headers\" 'qg iter N'",
                                          "assert_grep     \"$headers\" 'qg 반복 N'"),
    (T + "test_readme_state_diagram_complete.sh", '  "findings remain"\n  "Final verdict"\n',
                                                   '  "남은 지적이 있다"\n  "Final verdict"\n'),
    (T + "test_readme_state_diagram_complete.sh", '"⑤ synthesize" "Final summary"; do',
                                                   '"⑤ synthesize" "Final summary" "findings remain"; do'),
    (T + "test_pipeline_verdict_wiring.sh", r"note = seg(r'\*\*Retry 옵션 문구.*?(?=\n\nBranch on answer:)')",
                                             r"note = seg(r'\*\*「고치고 다시 돌기」 옵션 문구.*?(?=\n\nBranch on answer:)')"),
    (T + "test_pipeline_verdict_wiring.sh", r"bullet = seg(r'- \*\*Retry\*\* →.*?(?=\n- \*\*Accept)')",
                                             r"bullet = seg(r'- \*\*고치고 다시 돌기\*\* →.*?(?=\n- \*\*지금 판정으로 끝내기)')"),
    (T + "test_topic_scope_wiring.sh", "trv = [i for i, l in enumerate(lines) if 'Trivia diff — pipeline skipped' in l]",
                                        "trv = [i for i, l in enumerate(lines) if '작은 수정이라 파이프라인을 건너뛰었다' in l]"),
    (T + "test_topic_scope_wiring.sh", "detect 가 trivia 판단(「Trivia diff — pipeline skipped」)보다 먼저 나온다",
                                        "detect 가 trivia 판단(「작은 수정이라 파이프라인을 건너뛰었다」)보다 먼저 나온다"),
    (T + "test_v_requirements.sh", "'Retry failed at <file>' \"V9 — Edit 실패는 묻는다\"",
                                    "'<file> 수정에 실패했다' \"V9 — Edit 실패는 묻는다\""),
    (T + "test_v_requirements.sh", "'question: \"qg reached max 5 iterations\\.' \\",
                                    "'question: \"qg 가 최대 5번 반복했다\\.' \\"),
]
texts, bad = {}, []
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        bad.append("STOP %s: 옛 글자가 %d번 있다(기대 1): %r" % (rel, n, old[:80]))
        continue
    texts[rel] = t.replace(old, new)
if bad:
    sys.exit("\n".join(bad))
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t1_pins.py .
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_qg_templates.sh $Q/test_skill_orchestration.sh $Q/test_one_pipeline_surface.sh $Q/test_readme_state_diagram_complete.sh $Q/test_pipeline_verdict_wiring.sh $Q/test_topic_scope_wiring.sh $Q/test_v_requirements.sh $Q/harness/test_skill_orchestration_behavior.sh
```

기대(드라이런 실측): `test_plain_qg_templates` 80 중 74 RED(GREEN 여섯은 바뀌기 전에도 참인 것 — 분류 질문 · question 줄 넷(e2e 질문 · 게이트는 레퍼런스의 산문이라 `question:` 줄이 아니다) · 「분류표 그대로」 라벨 · 분류 머리글 · 게시 펜스의 결과 토큰 · `## e2e` 창의 양성 짝) · `test_skill_orchestration` RED · `test_one_pipeline_surface` 1 · `test_readme_state_diagram_complete` RED · `test_pipeline_verdict_wiring` 5 · `test_topic_scope_wiring` 1 · `test_v_requirements` 2 · harness FAIL 3(선재 1 + 이 Task 몫 2).

- [ ] **Step 3: SKILL · critiquing-artifacts · qg.md · README 를 고친다**

아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t1_edit.py` 에 쓰고 `python3 … .` 로 돌린다. 바뀌는 것은 사용자에게 그대로 보이는 문구(질문 · 머리글 · 선택지 라벨 · 설명 · 완료 표 제목과 칸 이름 · 범위 줄 · trivia 줄 · 범위 경고)와 그 라벨을 부르는 글자뿐이다. 차등 기원 안내 · 분기 불릿 · 라벨 설명의 지시 문장은 그대로 두고 그 안에서 부르는 라벨만 새 낱말로 바꾼다. 개념어로서의 Retry(「Retry: file-write safety」 · 「Retry: error handling」 · 「Retry spends one iteration」 · 흐름 그림 둘째 줄 「Retry: 「적용」 항목만 …」)는 지시문이라 그대로다 — 흐름 그림 첫 줄이 「고치고 다시 돌기(Retry)」로 둘을 묶는다. ④ 의 e2e 문면도 같은 규칙이다(R18 · R19): 선택지를 부르는 자리(E4 의 굵은 불릿 · 「Stop 없이 끝나면」 · 「Accept / Stop / pass 로 뒤집기」 · 게이트 표 · 결과 표 · 「Retry 를 넣지 않는다」)만 새 라벨로 바꾸고, 「(Retry 면 …)」 · 「고침은 Retry 로만 한다」 · 「Retry 의 「적용」 목록」 · 「Retry 뒤」는 그대로 둔다. e2e 칸 값 · 「fail 로 뒤집기」 · 「pass 로 뒤집기」의 `pass` · `fail` 은 `verdict.py --e2e` 가 읽는 토큰이라 그대로다(R20). 완료 표의 결과 칸 값은 게시 펜스가 읽는 토큰이라 그대로다(R15). `Then print the last synthesizer output's \`scope:\` block and \`angles:\` block verbatim …` 문장은 그대로 둔다(`test_topic_scope_wiring.sh:290` 이 그 글자를 잰다). 「멈추기」 설명은 고르면 달라지는 것(PR 코멘트가 달리지 않는다 — 게시 펜스의 `aborted*` 갈래)을 말한다(규칙 블록).

````python
#!/usr/bin/env python3
"""PR 3 Task 1 — 질문 셋 · 완료 표 · 모델이 그대로 내는 문구 (리포 루트를 인자로).
옛 글자가 전부 기대 개수(1)만큼 있는지 먼저 다 재고, 하나라도 다르면 아무것도 쓰지 않고 STOP 한다."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
S = "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
CA = "plugins/quality-gates/skills/critiquing-artifacts/SKILL.md"
QGMD = "plugins/quality-gates/commands/qg.md"
README = "plugins/quality-gates/README.md"
E2E = "plugins/quality-gates/tests/e2e-scenarios.md"
E2EREF = "plugins/quality-gates/references/e2e.md"

FIX_OLD = '''      question: "qg iter N: findings remain (<summary>). What next?",
      header: "qg iter N",
      options: [
        {label: "Retry",             description: "Apply the 적용 items of the table (I will Edit the files in this turn), then re-run the pipeline for the next iteration — differential test included."},
        {label: "Accept and finish", description: "Accept current findings as-is and go to the final verdict."},
        {label: "Stop",              description: "Abort the pipeline at this iteration. Address findings and re-run /qg."}
      ],'''
FIX_NEW = '''      question: "qg 반복 N: 남은 지적이 있다(<summary>). 어떻게 할까?",
      header: "qg 반복 N",
      options: [
        {label: "고치고 다시 돌기",      description: "분류표의 「적용」 항목을 이 턴에서 파일에 고치고 다음 반복을 돈다(차등 테스트 포함)."},
        {label: "지금 판정으로 끝내기", description: "남은 지적을 그대로 두고 지금 판정으로 끝낸다."},
        {label: "멈추기",               description: "이 반복에서 멈춘다 — PR 코멘트도 달지 않는다. 지적을 고친 뒤 /qg 를 다시 돌린다."}
      ],'''

RETRY_PARA_OLD = '''**Retry 옵션 문구 — 차등 테스트 기원(`blocking: 0`)에는 그대로 쓰지 않는다.** 그 트리거에는 리뷰어
패치가 없다 — `Retry` 의 `description` 을 "Apply the 적용 fix plans for the regressed units named in
<summary> (e.g. NEW_REGRESSION), then re-run the pipeline for the next iteration — differential test
included." 로 바꿔 싣는다. 다른 옵션 문구는 그대로다.'''
RETRY_PARA_NEW = '''**「고치고 다시 돌기」 옵션 문구 — 차등 테스트 기원(`blocking: 0`)에는 그대로 쓰지 않는다.** 그 트리거에는 리뷰어
패치가 없다 — 「고치고 다시 돌기」의 `description` 을 "<summary> 에 적힌 회귀 단위(예: NEW_REGRESSION)마다
「적용」 계획대로 고치고 다음 반복을 돈다(차등 테스트 포함)." 로 바꿔 싣는다. 다른 옵션 문구는 그대로다.'''

MAX_OLD = '''      question: "qg reached max 5 iterations. Last findings: <summary>. Finish with the current verdict or stop?",
      header: "qg max-iter",
      options: [
        {label: "Accept and finish", description: "Accept residual findings and go to the final verdict."},
        {label: "Stop",              description: "Abort the pipeline. Address findings and re-run /qg."}
      ],'''
MAX_NEW = '''      question: "qg 가 최대 5번 반복했다. 마지막 지적: <summary>. 지금 판정으로 끝낼까, 멈출까?",
      header: "qg 최대 반복",
      options: [
        {label: "지금 판정으로 끝내기", description: "남은 지적을 그대로 두고 지금 판정으로 끝낸다."},
        {label: "멈추기",               description: "파이프라인을 멈춘다 — PR 코멘트도 달지 않는다. 지적을 고친 뒤 /qg 를 다시 돌린다."}
      ],'''

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

TABLE_OLD = '''printf 'Verdict\\t%s\\nIterations\\t<N>\\nOutcome\\t<finished | accepted with findings iter N | aborted iter N>\\n' "$(tail -n 1 "$RD/verdict.out")" \\
  | "$QG/scripts/render-terminal.py" table --title "Quality Gates — Complete"'''
TABLE_NEW = '''printf '판정\\t%s\\n반복\\t<N>번\\n결과\\t<finished | accepted with findings iter N | aborted iter N>\\n' "$(tail -n 1 "$RD/verdict.out")" \\
  | "$QG/scripts/render-terminal.py" table --title "Quality Gates — 끝"'''

END_OLD = '''Then run [Publish](#publish) — the publish result line is the run's last output. The session folder stays for the TTL GC.
'''
END_NEW = '''Then run [Publish](#publish) — the publish result line is the run's last script output. The session folder stays for the TTL GC.

The completion report opens — before the table — with one Korean sentence: how the run ended (the 결과 cell in plain words) and the verdict value as-is (e.g. 「qg 를 반복 2번 만에 끝냈다 — 판정 defect, 남은 지적을 둔 채 끝냈다.」). The counts stay in the verdict line — do not restate them. After the publish result line, end with exactly one next action for the user (e.g. 「남은 지적 2개를 고친 뒤 /qg 를 다시 돌린다」 or 「할 일 없음」).
'''

EDITS = [
    (S, " │   막는 지적 또는 차등 defect → Fix-loop (Retry / Accept and finish / Stop)\n",
        " │   막는 지적 또는 차등 defect → Fix-loop (고치고 다시 돌기(Retry) / 지금 판정으로 끝내기 / 멈추기)\n"),
    (S, "건너뛴다: `Trivia diff — pipeline skipped (<한 문장 설명>).` 을 보이고",
        "건너뛴다: `작은 수정이라 파이프라인을 건너뛰었다(trivia diff) — <한 문장 설명>.` 을 보이고"),
    (S, "`> Review scope: session (<COUNT> changed files). 전체 PR/브랜치는 /qg branch.`",
        "`> 리뷰 범위: 이번 세션에서 바뀐 파일 <COUNT>개. 브랜치 전체를 보려면 /qg branch.`"),
    (S, "`> Review scope: topic <topic_key> (<COUNT> changed files · 구성원 <branches>).`",
        "`> 리뷰 범위: 토픽 <topic_key> — 바뀐 파일 <COUNT>개 · 구성원 <branches>.`"),
    (S, "`> [quality-gates] scope check degraded (detached HEAD / no base branch / unrelated history / shallow) — empty-scope detection skipped (fail-open; this run's scope-empty floor input is unavailable — the other reasons in Step 4's table still apply normally).`",
        "`> [quality-gates] 범위를 확인하지 못했다(scope check degraded — detached HEAD / no base branch / unrelated history / shallow) — 바뀐 파일이 0개인지 보는 검사를 건너뛰었다(fail-open). Step 4 표의 다른 사유는 그대로 적용된다.`"),
    (S, FIX_OLD, FIX_NEW),
    (S, '        {label: "분류표 그대로",           description: "표의 적용/제외로 Retry 한다."},',
        '        {label: "분류표 그대로",           description: "표의 적용/제외대로 고친다."},'),
    (S, RETRY_PARA_OLD, RETRY_PARA_NEW),
    (S, "- **Retry** → apply only the 적용 items", "- **고치고 다시 돌기** → apply only the 적용 items"),
    (S, "- **Accept and finish** → [Final verdict](#final-verdict) with Outcome", "- **지금 판정으로 끝내기** → [Final verdict](#final-verdict) with Outcome"),
    (S, "- **Stop** → Final verdict with Outcome `aborted iter N`.", "- **멈추기** → Final verdict with Outcome `aborted iter N`."),
    (S, MAX_OLD, MAX_NEW),
    (S, "Branch on answer: **Accept and finish** → Final verdict with Outcome `accepted with findings iter 5`;\n**Stop** → Final verdict with Outcome `aborted iter 5`.",
        "Branch on answer: **지금 판정으로 끝내기** → Final verdict with Outcome `accepted with findings iter 5`;\n**멈추기** → Final verdict with Outcome `aborted iter 5`."),
    (S, RF_OLD, RF_NEW),
    # e2e 절(④) — 선택지를 부르는 자리만 새 라벨. 반복 동작 이름으로서의 Retry(「고침은 Retry 로만」 · 흐름 그림 「Retry 면」)는 그대로.
    (S, "리뷰·테스트 루프가 Stop 없이 끝나면 최종 판정 전에 이 절을 한 번 돈다. 루프가 Stop 으로 끝났으면(aborted) 이 절을",
        "리뷰·테스트 루프가 「멈추기」 없이 끝나면 최종 판정 전에 이 절을 한 번 돈다. 루프가 「멈추기」로 끝났으면(aborted) 이 절을"),
    (S, "- **Retry** (fail 행) — `## Fix-loop` 의 Retry 와 같다:",
        "- **고치고 다시 돌기** (fail 행) — `## Fix-loop` 의 「고치고 다시 돌기」와 같다:"),
    (S, "  다시 돈다. 루프가 다시 Stop 없이 끝나면 이 절로 돌아오고,",
        "  다시 돈다. 루프가 다시 「멈추기」 없이 끝나면 이 절로 돌아오고,"),
    (S, "- **Accept** (fail 행) — `## Final verdict` 로 간다.",
        "- **지금 판정으로 끝내기** (fail 행) — `## Final verdict` 로 간다."),
    (S, "- **Stop** (fail 행) — `## Fix-loop` 의 Stop 과 같다:",
        "- **멈추기** (fail 행) — `## Fix-loop` 의 「멈추기」와 같다:"),
    (S, "다시 돈 뒤, Retry 와 같은\n  경로로 이 절에 돌아와",
        "다시 돈 뒤, 「고치고 다시 돌기」와 같은\n  경로로 이 절에 돌아와"),
    (S, "- iteration 5 를 다 썼으면 Retry · 리뷰·테스트부터 다시 를 선택지에 넣지 않는다. 그때 fail 행은 Accept / Stop / pass 로\n  뒤집기,",
        "- iteration 5 를 다 썼으면 고치고 다시 돌기 · 리뷰·테스트부터 다시 를 선택지에 넣지 않는다. 그때 fail 행은 지금 판정으로 끝내기 / 멈추기 / pass 로\n  뒤집기,"),
    (S, "그다음 `## Final verdict` 로 간다(Retry · 리뷰·테스트부터 다시 · 다시 걷기면 위 E4 의 경로로).",
        "그다음 `## Final verdict` 로 간다(고치고 다시 돌기 · 리뷰·테스트부터 다시 · 다시 걷기면 위 E4 의 경로로)."),
    (E2EREF, "| fail | Fix-loop 게이트(Retry / Accept / Stop) + pass 로 뒤집기 |",
             "| fail | Fix-loop 게이트(고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기) + pass 로 뒤집기 |"),
    (E2EREF, "남은 iteration 이 없으면 Retry 를 넣지 않는다.", "남은 iteration 이 없으면 「고치고 다시 돌기」를 넣지 않는다."),
    (E2EREF, "| fail 에서 Accept | `fail` | 아니오 |", "| fail 에서 지금 판정으로 끝내기 | `fail` | 아니오 |"),
    (E2EREF, "| fail 에서 Stop | `fail` | 아니오 |", "| fail 에서 멈추기 | `fail` | 아니오 |"),
    (E2EREF, "| 루프가 Stop(aborted) 으로 끝나 e2e 를 건너뜀 |", "| 루프가 「멈추기」(aborted)로 끝나 e2e 를 건너뜀 |"),
    (E2EREF, "fail 에서 Stop 을 고르면 실행은 aborted", "fail 에서 「멈추기」를 고르면 실행은 aborted"),
    (S, TABLE_OLD, TABLE_NEW),
    (S, END_OLD, END_NEW),
    (CA, "## 종료 & 최종 요약 (AC11)\n\n",
         "## 종료 & 최종 요약 (AC11)\n\n"
         "보고의 첫 줄은 끝났는지와 결과 한 문장이다(예: 「비평을 3라운드 돌고 수렴했다 — 남은 지적 없음.」 · "
         "「상한 5라운드에 닿았다 — 남은 지적 2개.」). 잔여 `kept` 항목에 `plain:` 이 있으면 그것을 먼저 쓰고 "
         "원래 `summary` 는 뒤 괄호에 둔다. 맨 끝에 사용자가 할 일 하나를 쓴다.\n\n"),
    (QGMD, "`Review scope: session (N files)`", "`리뷰 범위: 이번 세션에서 바뀐 파일 N개.`"),
    (QGMD, "`Review scope: topic <키> (N files · 구성원 <branches>)`", "`리뷰 범위: 토픽 <키> — 바뀐 파일 N개 · 구성원 <branches>.`"),
    (QGMD, "분류표와 함께 `Retry` / `Accept and finish` / `Stop` 로 사용자가 진행을 정한다(최대 5회). Retry 는 「적용」 항목만 고친다.",
           "분류표와 함께 `고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기` 로 사용자가 진행을 정한다(최대 5회). 「고치고 다시 돌기」는 「적용」 항목만 고친다."),
    (QGMD, "iteration boundary with `Retry` / `Accept and finish` / `Stop`.",
           "iteration boundary with `고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기`."),
    (README, ' │   막는 지적 또는 차등 defect → AskUserQuestion ("findings remain…")\n'
             ' │       분류표(항목마다 적용 / 제외 + 사유) · Retry / Accept and finish / Stop\n'
             ' │       Retry: 「적용」만 Edit, 「제외」는 excluded.md → 다음 iteration\n',
             ' │   막는 지적 또는 차등 defect → AskUserQuestion ("남은 지적이 있다…")\n'
             ' │       분류표(항목마다 적용 / 제외 + 사유) · 고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기\n'
             ' │       고치고 다시 돌기: 「적용」만 Edit, 「제외」는 excluded.md → 다음 iteration\n'),
    (E2E, "- `Review scope: topic …` 한 줄.", "- `리뷰 범위: 토픽 …` 한 줄."),
]

texts, bad = {}, []
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        bad.append("STOP %s: 옛 글자가 %d번 있다(기대 1): %r" % (rel, n, old[:80]))
        continue
    texts[rel] = t.replace(old, new)
if bad:
    sys.exit("\n".join(bad))
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
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_qg_templates.sh $Q/test_skill_orchestration.sh $Q/test_one_pipeline_surface.sh $Q/test_readme_state_diagram_complete.sh $Q/test_pipeline_verdict_wiring.sh $Q/test_topic_scope_wiring.sh $Q/test_v_requirements.sh $Q/test_review_scope_composition.sh $Q/test_critiquing_artifacts_skill.sh $Q/test_skill_drop_notice_consumed.sh $Q/test_qg_critique_routing.sh $Q/test_runtime_verdict_precedence.sh $Q/test_publish_pipeline_wiring.sh $Q/test_skill_run_contract.sh $Q/test_guards_coverage_bidirectional.sh $Q/test_runner_adapters.sh $Q/test_e2e_docs.sh shared/tests/test_invocation_surface.sh shared/tests/test_plain_language_block.sh shared/tests/test_skill_body_no_positional_tokens.sh $Q/harness/test_skill_orchestration_behavior.sh
grep -a '^FAIL' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/logs/test_skill_orchestration_behavior.sh.log
python3 shared/entry/check_invocation_surface.py --report | grep -c '^| [0-9]'
```

기대(드라이런 실측): 앞의 스물은 `rc=0`(80/80 · 3/3 · 89/89 · 10 markers · 79/79 · 79/79 · 31/31 · 21/21 · 35/35 · 12/12 · 5/5 · 22/22 · 117/117 · 102/102 · 353/353 · 53/53 · 96/96 · 69/69 · 12/12 · 6/6). harness 는 FAIL 줄이 선재 하나(「R1b→R8 unclaimed 집행 사슬」)뿐이다. 보고 표 행 15.

- [ ] **Step 5: 커밋**

```bash
Q=plugins/quality-gates/tests
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/critiquing-artifacts/SKILL.md plugins/quality-gates/commands/qg.md plugins/quality-gates/README.md plugins/quality-gates/references/e2e.md $Q/e2e-scenarios.md \
  $Q/test_plain_qg_templates.sh $Q/test_skill_orchestration.sh $Q/harness/test_skill_orchestration_behavior.sh $Q/test_one_pipeline_surface.sh $Q/test_readme_state_diagram_complete.sh $Q/test_pipeline_verdict_wiring.sh $Q/test_topic_scope_wiring.sh $Q/test_v_requirements.sh
git commit -m "feat(qg): 질문 셋과 완료 표, 모델이 그대로 내는 문구를 한국어 쉬운 말로

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat HEAD | tail -1
git ls-files -s $Q/test_plain_qg_templates.sh | cut -c1-6
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_publish_surface_removed.sh $Q/test_gate_era_prose_absent.sh shared/tests/test_dispatch_disposition.sh
```

기대: `14 files changed` · `100755` · 커밋 뒤 스윕 셋 `rc=0`(40/40 · 7/7 · 19/19).

- [ ] **Step 6: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py . t1 | tee ~/.claude/sdd-mirror/plain-language-output/pr3/mut-t1.txt
```

기대(드라이런 실측): `BASE-GREEN 7 tests` · `cells=45 red=45 survived=0 skip=0`, 줄마다 `restored`. 셀 「완료 표 결과 칸을 한국어 낱말로」는 옛 계획의 편집이 게시 펜스의 토큰과 어긋나는 것을 RED 로 잡는다(R15). e2e 셀 열다섯(R18)은 SKILL `## e2e` · `references/e2e.md` 의 각 자리를 옛 라벨로 되돌리는 열둘, `## e2e` 머리를 옮겨 창을 비우는 하나(양성 짝이 잡는다), 새 글자를 그대로 둔 채 옛 이름을 더하는 둘(부재 단언이 잡는다 — 더하기 축)이다.

---

## Task 2: 합성기 · 표를 읽는 SKILL 자리 · 시작 배너 · setup 오류 줄 (Goal 2 · AC5 · AC6 · R1 · R2 · R8 · R10 · R12 · R16)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py:620` 앞(`_status_line`) · `:628-640`(첫 줄 · 머리글 · 빈 분기) · `:649 · :658 · :662-666 · :668`(표 머리 · 표 행 · 버린 지적 줄 · 고칠 방법) · `:794-795`(`--emit-verdict` 꼬리의 블록 앞 한 줄)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:606`(분류표 번호가 가리키는 목록 이름) · `:933`(`result.md` 의 「지적」 절을 자르는 앵커)
- Modify: `plugins/quality-gates/scripts/setup-qg.sh:16 · :42 · :72 · :84 · :114-115 · :132-136 · :142 · :259-269`(④ 의 e2e 정리 줄 :235-238 은 이미 한국어 — R20)
- Modify: `plugins/quality-gates/tests/e2e-scenarios.md:101`(kill switch 거부 줄을 인용한다)
- Create: `plugins/quality-gates/tests/test_plain_synth_output.sh`
- Modify(고정 단언 — Step 2 의 표)

**Interfaces:**
- Produces: 합성기 stdout 첫 줄 = `_status_line(counts, dropped_malformed, report["degraded"], blocking)`:
  - 발견 0: `리뷰를 합쳤다 — 지적 없음.`
  - 발견 ≥1: `리뷰를 합쳤다 — 남은 지적 N개(심각 a · 중요 b · 제안 c).` (0 인 등급은 뺀다)
  - 뒤에 붙는 것: 버린 것이 있으면 ` 형식이 깨져 버린 지적 N개.`, 경고가 있으면 ` 판정을 막는 경고가 있다 — 아래를 본다.` 또는 ` 판정을 막지 않는 경고가 있다 — 아래를 본다.`
  - 이 줄은 `verdict` 글자도 `판정 degrade` 표지도 담지 않는다.
- 둘째 줄부터: `## 리뷰 지적 (합친 결과)` · 빈 줄 · `**Findings:** …` · `blocking: N` · `optional: M` · 처분 줄 셋(그대로) · … · 표 머리 `| 심각도 | 위치 | 내용 | 낸 곳 |` · `**고칠 방법:**`
- SKILL 의 `result.md` 기록 펜스: `grep -q '^| 심각도 |' "$SYN"; then sed -n '/^| 심각도 |/,/^$/p' "$SYN"` · Step 5: 「the `**고칠 방법:**` list carries the same `#k`」
- `--emit-verdict` 꼬리: 블록이 있을 때만 첫 블록 앞에 쉬운 한 줄(R2).

- [ ] **Step 1: 실패하는 락을 쓴다**

`plugins/quality-gates/tests/test_plain_synth_output.sh` — 재비판 경로(실제 실행과 같은 모양)로 합성기를 부른다(`tests/lib/recritic_fixture.sh`):

````bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/lib/recritic_fixture.sh
#
# 쉬운 말 출력 설계 Goal 2 · AC5 · AC6 (계획 R1 · R2 · R8 · R10 · R12 · R16) — 합성기와 시작 배너의 첫 줄이
# 상태 문장이고 0 인 정상 집계가 없다. 판단에 필요한 0(처분 줄)과 기계가 읽는 줄(**Findings:** ·
# blocking: · optional:)은 남는다. 합성기 표를 읽는 SKILL 자리가 합성기와 같은 글자를 쓴다.
# setup 의 오류 줄은 쉬운 말로 시작하고 원래 영어 토큰을 괄호에 남긴다. 부재 단언마다 양성 짝이 있다.
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
. "$PLUGIN_ROOT/tests/lib/recritic_fixture.sh"
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
SETUP="$PLUGIN_ROOT/scripts/setup-qg.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
export PYTHONDONTWRITEBYTECODE=1
unset CLAUDE_CODE_SESSION_ID
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT
first() { printf '%s\n' "$1" | head -1; }

# ① 발견 0 (재비판 경로 — 실제 실행과 같은 모양)
mkdir -p "$T/e"; printf '[]\n' > "$T/e/findings.yaml"; rf_prep "$T/e"; rf_reply "$T/e" 'verdicts: []'
out="$(rf_synth "$T/e")"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 지적 없음." "Goal 2: 발견 0 의 첫 줄이 상태 문장이다"
assert_not_contains "$out" "No findings" "AC6: 영어 고정 문구가 없다"
assert_grep "$out" '^## 리뷰 지적 \(합친 결과\)$' "AC6: 머리글이 한국어다(양성 짝)"
assert_not_contains "$out" "Review Findings" "AC6: 영어 머리글이 없다"
assert_grep "$out" '^\*\*처분:\*\* ' "R1: 처분 줄(판단에 필요한 0)은 남는다"
assert_grep "$out" '^blocking: 0$' "기계가 읽는 blocking: 줄은 남는다"
assert_not_contains "$(first "$out")" "verdict" "AC5: 쉬운 첫 줄은 verdict 글자를 담지 않는다"
assert_not_contains "$(first "$out")" "경고" "R16: 경고가 없으면 첫 줄에 경고를 말하지 않는다(양성 짝은 ④)"

# ② 발견 ≥1 — 0 인 등급은 첫 줄에서 뺀다. 표 · 고칠 방법이 한국어다
mkdir -p "$T/one"
printf -- '- {agent: security-reviewer, file: app.py, line: 3, severity: CRITICAL, summary: "SQL 을 문자열로 만든다", proposed_fix: "바인딩"}\n' > "$T/one/findings.yaml"
rf_prep "$T/one"; rf_reply "$T/one" 'verdicts:
  - {f: f1, verdict: confirm}'
out="$(rf_synth "$T/one")"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 남은 지적 1개(심각 1)." "Goal 2: 발견 ≥1 의 첫 줄이 상태 문장이고 0 인 등급을 뺀다"
assert_grep "$out" '^\*\*Findings:\*\* 1 CRITICAL / 0 IMPORTANT / 0 SUGGESTION$' "AC5: 기계가 읽는 Findings 줄은 형태 그대로다"
assert_grep "$out" '^\| 심각도 \| 위치 \| 내용 \| 낸 곳 \|$' "AC6: 표 머리가 한국어다"
assert_not_contains "$out" "| Sev |" "AC6: 영어 표 머리가 없다"
assert_grep "$out" '^\*\*고칠 방법:\*\*$' "AC6: 고칠 방법 머리가 한국어다"
assert_not_contains "$out" "Suggested fixes" "AC6: 영어 고칠 방법 머리가 없다"
mkdir -p "$T/mix"
printf -- '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: a}\n- {agent: r, file: b.py, line: 2, severity: IMPORTANT, summary: b, proposed_fix: f}\n- {agent: r, file: c.py, line: 3, severity: SUGGESTION, summary: c, proposed_fix: f}\n' > "$T/mix/findings.yaml"
rf_prep "$T/mix"; rf_reply "$T/mix" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}'
out="$(rf_synth "$T/mix")"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 남은 지적 3개(중요 2 · 제안 1)." "Goal 2: 등급은 심각 · 중요 · 제안 순서이고 0 인 등급(심각)은 없다"
assert_grep "$out" '^- #1 `a\.py:1` — \(없음\)$' "AC6: 고칠 방법이 없는 지적은 「(없음)」이다"
assert_not_contains "$out" "(none)" "AC6: 영어 「(none)」이 없다"

# ③ 버린 지적 — 첫 줄이 버린 수와 막는 경고를 말한다(없는 것과 버린 것은 다르다 — R12 · R16)
mkdir -p "$T/bad"; printf -- '- "매핑이 아닌 항목"\n' > "$T/bad/findings.yaml"; rf_prep "$T/bad"; rf_reply "$T/bad" 'verdicts: []'
out="$(rf_synth "$T/bad" 2>/dev/null)"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 지적 없음. 형식이 깨져 버린 지적 1개. 판정을 막는 경고가 있다 — 아래를 본다." "R12 · R16: 버린 수와 막는 경고를 첫 줄에 붙인다"
assert_grep "$out" '^1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed: ' "AC6: 버린 지적 줄이 쉬운 말로 시작하고 소비자가 읽는 토큰을 남긴다"
assert_not_contains "$out" "finding(s) dropped" "AC6: 옛 영어 버린 지적 줄이 없다"
# 표가 있는 갈래 — 살아남은 지적과 버린 지적이 함께
mkdir -p "$T/bad2"; printf -- '- {agent: r, file: a.py, line: 1, severity: CRITICAL, summary: s, proposed_fix: f}\n- "매핑이 아닌 항목"\n' > "$T/bad2/findings.yaml"
rf_prep "$T/bad2"; rf_reply "$T/bad2" 'verdicts:
  - {f: f1, verdict: confirm}'
out="$(rf_synth "$T/bad2" 2>/dev/null)"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 남은 지적 1개(심각 1). 형식이 깨져 버린 지적 1개. 판정을 막는 경고가 있다 — 아래를 본다." "R12 · R16: 표가 있는 갈래도 버린 수와 경고를 첫 줄에 붙인다"
assert_grep "$out" '^1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed: ' "AC6: 표가 있는 갈래의 버린 지적 줄도 토큰을 남긴다"

# ④ 막지 않는 경고 — 보조 입력(--recritic-diff)이 죽었다(R16)
mkdir -p "$T/aux"
printf -- '- {agent: sec, file: b.py, line: 2, severity: CRITICAL, summary: x}\n' > "$T/aux/findings.yaml"
rf_prep "$T/aux"; rf_reply "$T/aux" 'verdicts:
  - {f: f1, verdict: reject, evidence: "근거"}'
out="$(rf_synth "$T/aux" --recritic-diff "$T/aux/없는.diff" 2>/dev/null)"
assert_eq "$(first "$out")" "리뷰를 합쳤다 — 지적 없음. 판정을 막지 않는 경고가 있다 — 아래를 본다." "R16: 막지 않는 경고도 첫 줄에 말한다"
assert_grep "$out" '공시\(판정을 막지 않음\)' "R16: 그 경고의 본문(degrade 공시)이 아래에 있다(양성 짝)"

# ⑤ --emit-verdict: 판정 줄은 정확히 하나, 쉬운 줄과 섞이지 않는다. 블록 앞에 쉬운 한 줄(AC5 · R2)
printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
out="$(rf_synth "$T/one" --emit-verdict --angles "$T/angles.txt")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^verdict: ')" "1" "AC5: verdict 줄은 정확히 한 번"
assert_eq "$(printf '%s\n' "$out" | grep -c 'verdict:')" "1" "AC5: 그 밖의 줄에 verdict: 글자가 없다"
assert_eq "$(printf '%s\n' "$out" | grep -B1 '^angles:$' | head -1)" "아래는 이 판정의 리뷰 각도(angles) 원문이다." "AC5: angles 블록 바로 앞에 쉬운 한 줄"
assert_eq "$(printf '%s\n' "$out" | grep -c '^아래는 이 판정')" "1" "AC5: 그 쉬운 줄은 한 번만 나온다"
printf 'topic_key: -\nstatus: no-declaration\nreason: -\nbranches: -\nin_base: -\nboundary: -\ntips: -\nseal: -\nseal_on_topic: -\ntree: -\nhead_commit: -\nconflicts: -\ncommits: -\n' > "$T/scope.txt"
out="$(rf_synth "$T/one" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")"
assert_eq "$(printf '%s\n' "$out" | grep -B1 '^scope:$' | head -1)" "아래는 이 판정이 본 범위(scope)와 리뷰 각도(angles)의 원문이다." "AC5: 두 블록이면 scope 블록 앞에 두 블록을 다 가리키는 한 줄"
assert_eq "$(printf '%s\n' "$out" | grep -c '^아래는 이 판정')" "1" "AC5: 두 블록이어도 쉬운 줄은 한 번"
out="$(rf_synth "$T/one" --emit-verdict --scope "$T/scope.txt")"
assert_eq "$(printf '%s\n' "$out" | grep -B1 '^scope:$' | head -1)" "아래는 이 판정이 본 범위(scope)의 원문이다." "AC5: scope 블록만 있으면 그것만 가리킨다"
out="$(rf_synth "$T/one" --emit-verdict)"
assert_not_contains "$out" "아래는 이 판정" "AC5: 블록이 없으면 블록을 가리키는 줄도 없다"
assert_grep "$out" '^verdict: defect$' "AC5: 블록 없는 실행도 판정 줄은 있다(양성 짝)"

# ⑥ 합성기 표를 읽는 SKILL 자리 — 머리 글자와 고칠 방법 목록 이름이 합성기와 같다(한쪽만 바뀌면 조용히 빈 「지적」 절)
out="$(rf_synth "$T/one")"
anchor="$(sed -n "s/.*grep -q '\([^']*\)' \"\$SYN\".*/\1/p" "$SKILL")"
assert_eq "$(printf '%s\n' "$anchor" | grep -c .)" "1" "SKILL Final verdict 의 지적 표 앵커를 하나 찾았다"
assert_eq "${anchor}" "^| 심각도 |" "SKILL 의 지적 표 앵커가 한국어 머리다"
sedpat="$(sed -n "s/.*then sed -n '\/\([^/]*\)\/,\/^\$\/p' \"\$SYN\".*/\1/p" "$SKILL")"
assert_eq "${sedpat}" "${anchor}" "SKILL 의 sed 범위 시작이 grep 앵커와 같은 글자다(한쪽만 바뀌면 빈 절)"
rng="$(printf '%s\n' "$out" | sed -n "/${anchor}/,/^\$/p")"
assert_grep "$rng" '^\| CRITICAL \| app\.py:3 \| SQL 을 문자열로 만든다 \| security-reviewer \|$' "그 앵커로 자른 범위에 지적 행이 든다(result.md 의 「지적」 절이 비지 않는다)"
assert_not_contains "$(sed -n "/grep -q '^| /p" "$SKILL")" "Sev |" "SKILL 에 옛 영어 표 앵커가 없다"
fixes="$(sed -n 's/.*the `\(\*\*[^`]*\*\*\)` list carries the same `#k`.*/\1/p' "$SKILL")"
assert_eq "${fixes}" "**고칠 방법:**" "SKILL Step 5 가 고칠 방법 목록을 합성기와 같은 글자로 부른다"
assert_grep "$out" "^$(printf '%s' "$fixes" | sed 's/\*/\\*/g')\$" "합성기가 SKILL 이 부르는 그 글자를 낸다"

# ⑦ 시작 배너 — 첫 줄이 상태 문장이고 과정 나열이 없다
mkdir -p "$T/w"
out="$(cd "$T/w" && bash "$SETUP" --session-id "plaintest-$$" --plan docs/p.md 2>/dev/null)"
assert_eq "$(first "$out")" "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다." "Goal 2: 시작 배너 첫 줄이 상태 문장이다"
assert_not_contains "$out" "Pipeline:" "Goal 2: 시작 배너에 과정 나열이 없다"
assert_not_contains "$out" "Pipeline runs in this turn" "AC6: 옛 영어 배너 끝줄이 없다"
assert_grep "$out" '^계획 파일: docs/p\.md$' "AC6: 계획 파일 줄이 한국어다"
assert_not_contains "$out" "Plan file" "AC6: 옛 영어 계획 파일 줄이 없다"

# ⑧ setup 오류 줄(R10) — 쉬운 말이 앞, 원래 영어 토큰은 괄호에(기존 락이 그 토큰을 잰다)
err="$(cd "$T/w" && bash "$SETUP" --paths 2>&1 >/dev/null)"
assert_contains "$err" "❌ --paths 뒤에 glob 이 하나도 없다(--paths requires at least one glob)." "R10: --paths 오류"
err="$(cd "$T/w" && bash "$SETUP" --plan 2>&1 >/dev/null)"
assert_contains "$err" "❌ --plan 뒤에 파일 경로가 없다(--plan requires a file path argument)." "R10: --plan 오류"
err="$(cd "$T/w" && bash "$SETUP" --session-id 2>&1 >/dev/null)"
assert_contains "$err" "❌ --session-id 뒤에 값이 없다(--session-id requires an argument)." "R10: --session-id 오류"
err="$(cd "$T/w" && bash "$SETUP" --no-such-flag 2>&1 >/dev/null)"
assert_contains "$err" "❌ 모르는 인자다(Unknown argument): --no-such-flag" "R10: 모르는 인자 오류"
assert_contains "$err" "쓰는 법은 --help 로 본다." "R10: 모르는 인자 오류의 안내 줄"
assert_not_contains "$err" "Use --help" "R10: 옛 영어 안내 줄이 없다"
err="$(cd "$T/w" && bash "$SETUP" 2>&1 >/dev/null)"
assert_contains "$err" "세션 ID(session ID)가 비어 있어 상태 폴더를 만들 수 없다." "R10: 세션 ID 없음 오류"
assert_not_contains "$err" "cannot create pipeline state" "R10: 옛 영어 세션 ID 없음 오류가 없다"
err="$(cd "$T/w" && bash "$SETUP" --session-id 'bad id' 2>&1 >/dev/null)"
assert_contains "$err" "가 허용 모양([A-Za-z0-9_-]{8,})이 아니다(fails pattern guard)." "R10: 세션 ID 모양 오류"
err="$(cd "$T/w" && DEVBREW_QUALITY_GATES_DISABLE=1 bash "$SETUP" 2>&1 >/dev/null)"
assert_contains "$err" "DEVBREW_QUALITY_GATES_DISABLE=1 이 켜져 있어 /qg 를 시작하지 않는다(setup-qg disabled)." "R10: kill switch 거부 줄"
finish
````

```bash
chmod +x plugins/quality-gates/tests/test_plain_synth_output.sh
```

- [ ] **Step 2: 고정 단언을 새 문구로**

전수는 바뀌는 글자를 앞부분 조각까지 찾아 얻었다(`git grep -nF -- '<글자>' -- 'plugins/*/tests/*' 'shared/tests/*' 'tools/*'` — `Review Findings` · `No findings` · `Sev |` · `Sev \|` · `Path:Line` · `Suggested fixes` · `(none)` · `dropped as` · `finding\(s\) dropped` · `see stderr` · `setup-qg disabled` · `requires at least one glob` · `Unknown argument` · `session ID` · `fails pattern guard` · `Pipeline:` · `Plan file` · `Pipeline runs`). 부재 단언은 새 문구에서도 공허하지 않게 양성 짝과 함께 옮긴다. 형식을 설명하는 주석도 같이 고친다(낡은 주석은 다음 사람을 속인다).

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_synthesize_findings.sh:4`(주석) | 표는 Sev · Path:Line · Summary · Source 넷 | 표는 심각도 · 위치 · 내용 · 낸 곳 넷 | 표 칸 설명 |
| `test_synthesize_findings.sh:47` | `No findings\.` | `리뷰를 합쳤다 — 지적 없음\.` | 기각된 지적은 표에 없다 |
| `test_synthesize_findings.sh:52` | `\| Sev \| Path:Line \| Summary \| Source \|` · 부재 `\| Conf \|…` | `\| 심각도 \| 위치 \| 내용 \| 낸 곳 \|` · 부재에 `\| Sev \|` 를 더함 | 표 머리 스키마(confidence 칸 없음) |
| `test_synthesize_findings.sh:94` | `1 finding\(s\) dropped as malformed .*verdict: not-certified …` | `1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed: .*verdict: not-certified …` | V3 — 매핑 아닌 지적은 세고 막는다 |
| `test_synthesize_findings.sh:96 · :100` | 「빈 결과 — No findings 와 0 개수」 · `No findings\. blocking: 0 optional: 0` | 「빈 결과 — 「지적 없음」 첫 줄과 0 개수」 · `^리뷰를 합쳤다 — 지적 없음\. ## 리뷰 지적 \(합친 결과\) .*blocking: 0 optional: 0` · 부재 `No findings` | 빈 결과는 상태 첫 줄로 시작하고 기계가 읽는 0 은 남는다(R1) |
| `test_synthesize_disposition.sh:225` | `No findings\.` | `리뷰를 합쳤다 — 지적 없음\.` | 유일한 항목이 기각돼 빈 표 분기를 태운다 |
| `test_synthesize_findings_adjudication.py:215` | `"No findings."` | `"리뷰를 합쳤다 — 지적 없음."` | clean 실행의 양성 짝 |
| `test_synthesize_promoted_findings.sh:49 · :144`(주석) | `Sev · Path:Line · Summary · Source` · `'Suggested fixes' 절` | `심각도 · 위치 · 내용 · 낸 곳` · `'고칠 방법' 절` | 표 칸 · 고칠 방법 절 설명 |
| `test_synthesize_promoted_findings.sh:223 · :245` | `^2 finding\(s\) dropped as malformed` | `^2개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed` | 버린 주장이 stdout 에 보인다 |
| `test_synthesize_promoted_findings.sh:361` | `^1 finding\(s\) dropped as malformed` | `^1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed` | 스칼라 findings 는 1건 소실 |
| `test_v_requirements.sh:56` | `^1 finding\(s\) dropped as malformed .*이 실행은 clean이 아니다` | `^1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed: .*이 실행은 clean이 아니다` | V3 — 버려진 파손 지적은 세어 공시한다 |
| `test_angle_coverage.sh:89-95`(R-J) | off = on − `angles:` 블록 | off = on − `angles:` 블록 − 그 앞의 쉬운 한 줄 | 각도를 안 주면 블록(과 그 블록을 가리키는 줄)만 빠지고 나머지는 바이트 동일 |

그대로 GREEN 이어야 하는 것(고치지 않는다): `test_skill_drop_notice_consumed.sh`(SKILL 과 합성기가 `dropped as malformed` 를 같은 글자로 쓴다 — 토큰이 괄호에 남는다) · `test_synthesize_disposition.sh:267` · `test_synthesize_recritic.sh:448 · :565`(같은 토큰) · `test_synthesize_recritic.sh:891 · :913`(`SUGGESTION (lowered)` — 심각도 칸의 등급 토큰과 표지는 그대로) · `test_setup_qg.sh:92 · :108 · :111 · :114 · :139`(`Unknown argument` · `requires at least one glob` 토큰 — R10) · `test_precheck_retired.sh:28`(`fails pattern guard` 토큰) · `test_entry_safety_e1_e6.sh:266` · `test_verdict_vocabulary.sh`(**수정 없이** GREEN — AC5). 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t2_pins.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 2 — 합성기 문구를 고정한 기존 단언(과 그 형식을 설명하는 주석)을 새 문구로 (리포 루트를 인자로).
항목은 (파일, 옛, 새, 기대 개수). 옛 글자가 전부 기대 개수만큼 있는지 먼저 다 재고, 하나라도 다르면
아무것도 쓰지 않고 STOP 한다."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
T = "plugins/quality-gates/tests/"
EDITS = [
    (T + "test_synthesize_findings.sh",
     "# 표는 Sev · Path:Line · Summary · Source 넷이다.",
     "# 표는 심각도 · 위치 · 내용 · 낸 곳 넷이다.", 1),
    (T + "test_synthesize_findings.sh",
     "  'No findings\\.' 'a\\.py:10'",
     "  '리뷰를 합쳤다 — 지적 없음\\.' 'a\\.py:10'", 1),
    (T + "test_synthesize_findings.sh",
     "  '\\| Sev \\| Path:Line \\| Summary \\| Source \\|' '\\| Conf \\||suppressed|[0-9] \\* \\|'",
     "  '\\| 심각도 \\| 위치 \\| 내용 \\| 낸 곳 \\|' '\\| Conf \\||\\| Sev \\||suppressed|[0-9] \\* \\|'", 1),
    (T + "test_synthesize_findings.sh",
     "  '1 finding\\(s\\) dropped as malformed .*verdict: not-certified .*reason: findings-lost'",
     "  '1개 지적을 버렸다 — 형식이 깨졌다\\(dropped as malformed: .*verdict: not-certified .*reason: findings-lost'", 1),
    (T + "test_synthesize_findings.sh",
     'run_case "빈 결과 — No findings 와 0 개수" \\',
     'run_case "빈 결과 — 「지적 없음」 첫 줄과 0 개수" \\', 1),
    (T + "test_synthesize_findings.sh",
     "  'No findings\\. blocking: 0 optional: 0' ''",
     "  '^리뷰를 합쳤다 — 지적 없음\\. ## 리뷰 지적 \\(합친 결과\\) .*blocking: 0 optional: 0' 'No findings'", 1),
    (T + "test_synthesize_disposition.sh",
     "assert_grep \"$OUT_BP\" 'No findings\\.' \\",
     "assert_grep \"$OUT_BP\" '리뷰를 합쳤다 — 지적 없음\\.' \\", 1),
    (T + "test_synthesize_findings_adjudication.py",
     '        self.assertIn("No findings.", clean)',
     '        self.assertIn("리뷰를 합쳤다 — 지적 없음.", clean)', 1),
    (T + "test_synthesize_promoted_findings.sh",
     "표는 Sev · Path:Line · Summary · Source 넷이다.",
     "표는 심각도 · 위치 · 내용 · 낸 곳 넷이다.", 1),
    (T + "test_synthesize_promoted_findings.sh",
     "# 표 행만 센다 — 'Suggested fixes' 절도",
     "# 표 행만 센다 — '고칠 방법' 절도", 1),
    (T + "test_synthesize_promoted_findings.sh",
     "grep -qE '^2 finding\\(s\\) dropped as malformed'",
     "grep -qE '^2개 지적을 버렸다 — 형식이 깨졌다\\(dropped as malformed'", 2),
    (T + "test_synthesize_promoted_findings.sh",
     "grep -qE '^1 finding\\(s\\) dropped as malformed'",
     "grep -qE '^1개 지적을 버렸다 — 형식이 깨졌다\\(dropped as malformed'", 1),
    (T + "test_v_requirements.sh",
     "'^1 finding\\(s\\) dropped as malformed .*이 실행은 clean이 아니다'",
     "'^1개 지적을 버렸다 — 형식이 깨졌다\\(dropped as malformed: .*이 실행은 clean이 아니다'", 1),
    (T + "test_angle_coverage.sh",
     "    /^angles:$/ { skip = n; next }\n    skip > 0 { skip--; next }\n    { print }",
     "    /^아래는 이 판정의 리뷰 각도\\(angles\\) 원문이다\\.$/ { next }\n"
     "    /^angles:$/ { skip = n; next }\n    skip > 0 { skip--; next }\n    { print }", 1),
    (T + "test_angle_coverage.sh",
     '"off 는 on 에서 angles: 블록(헤더 1줄 + 각도 ${angle_lines}줄)을 뺀 것과 바이트 동일하다"',
     '"off 는 on 에서 angles: 블록(헤더 1줄 + 각도 ${angle_lines}줄)과 그 앞의 쉬운 한 줄을 뺀 것과 바이트 동일하다"', 1),
]
texts, bad = {}, []
for rel, old, new, want in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != want:
        bad.append("STOP %s: 옛 글자가 %d번 있다(기대 %d): %r" % (rel, n, want, old[:90]))
        continue
    texts[rel] = t.replace(old, new)
if bad:
    sys.exit("\n".join(bad))
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t2_pins.py .
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_synth_output.sh $Q/test_synthesize_findings.sh $Q/test_synthesize_disposition.sh $Q/test_synthesize_findings_adjudication.py $Q/test_synthesize_promoted_findings.sh $Q/test_v_requirements.sh $Q/test_angle_coverage.sh
```

기대(드라이런 실측): `test_plain_synth_output` 55 중 41 RED · `test_synthesize_findings` 4 · `test_synthesize_disposition` 1 · adjudication.py 1 · `test_synthesize_promoted_findings` 3 · `test_v_requirements` 1 · `test_angle_coverage` GREEN(쉬운 줄이 아직 없어 새 awk 줄이 아무것도 거르지 않는다).

- [ ] **Step 3: 합성기 · SKILL 의 표 자리 · setup 을 고친다**

`counts_line`(`**Findings:** …`) · `blocking:` · `optional:` 줄은 그대로 둔다 — 기계가 읽는다(R1). 버린 지적 줄은 쉬운 말이 앞이고 `dropped as malformed` 토큰을 괄호에 남긴다 — SKILL Step 4.5 가 그 토큰을 이름으로 대고 소비한다. 심각도 칸의 등급 토큰(`CRITICAL` · `IMPORTANT` · `SUGGESTION`)과 ` (lowered)` 표지는 그대로다(테스트가 `^| IMPORTANT |` · `SUGGESTION (lowered)` 로 잰다). 표의 요약 칸에 `plain` 을 먼저 쓰는 렌더도 여기서 들어간다(Task 3 이 그 칸을 만든다 — 칸이 없으면 지금처럼 요약만). setup 의 `gone()` · `refuse()` · 다른 세션 · 예약 폴더 줄은 이미 한국어라 그대로다(R9). 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t2_edit.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 2 — 합성기 · 그 표를 읽는 SKILL 자리 · 시작 배너 · setup 오류 줄 (리포 루트를 인자로).
옛 글자가 전부 기대 개수(1)만큼 있는지 먼저 다 재고, 하나라도 다르면 아무것도 쓰지 않고 STOP 한다."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
SY = "plugins/quality-gates/scripts/synthesize_findings.py"
SK = "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
SE = "plugins/quality-gates/scripts/setup-qg.sh"
E2E = "plugins/quality-gates/tests/e2e-scenarios.md"

# render() 위에 둔다 — dedup() 의 줄 번호(tools/adjudication/check_wiring.py 의 EXEMPT 키)보다 아래다.
STATUS_FN = '''_SEV_KO = (("CRITICAL", "심각"), ("IMPORTANT", "중요"), ("SUGGESTION", "제안"))


def _status_line(counts, dropped_malformed, degraded, blocking):
    """사람이 보는 첫 줄 — 스크립트가 계산한 상태 문장. 판정(verdict)과 무관하다:
    판정 없는 출력이 판정 있는 출력의 바이트 접두여야 한다(`--emit-verdict` 꼬리).
    버린 지적과 경고(degrade)는 여기에도 붙인다 — 첫 줄만 읽고 「지적 없음」으로 끝내지 않게."""
    total = sum(counts.values())
    if total == 0:
        s = "리뷰를 합쳤다 — 지적 없음."
    else:
        # for 문으로 쓴다 — 이 파일은 처분 회계 소비자라 컴프리헨션 수가 baseline 으로 묶여 있다
        # (`shared/tests/test_adjudication_wiring.sh`). 0 인 등급은 뺀다(설계 §3 원칙 3).
        parts = []
        for k, ko in _SEV_KO:
            if counts[k]:
                parts.append("%s %d" % (ko, counts[k]))
        s = "리뷰를 합쳤다 — 남은 지적 %d개(%s)." % (total, " · ".join(parts))
    if dropped_malformed > 0:
        s += " 형식이 깨져 버린 지적 %d개." % dropped_malformed
    if degraded:
        if blocking:
            s += " 판정을 막는 경고가 있다 — 아래를 본다."
        else:
            s += " 판정을 막지 않는 경고가 있다 — 아래를 본다."
    return s


def render(findings, dropped_malformed, report, held_classes, recritic_zero=False, *, blocking):'''

EDITS = [
    (SY, "def render(findings, dropped_malformed, report, held_classes, recritic_zero=False, *, blocking):", STATUS_FN),
    (SY, '''    out = ["## Review Findings (Synthesized)", "", counts_line,
           f"blocking: {n_block}", f"optional: {counts['SUGGESTION']}",
           disp_line, plumb_line, gloss_line]
    if not findings:
        out.insert(3, "No findings.")
''',
     '''    out = [_status_line(counts, dropped_malformed, report["degraded"], blocking),
           "## 리뷰 지적 (합친 결과)", "", counts_line,
           f"blocking: {n_block}", f"optional: {counts['SUGGESTION']}",
           disp_line, plumb_line, gloss_line]
    if not findings:
'''),
    (SY, '''                f"{dropped_malformed} finding(s) dropped as "
                "malformed (not a mapping, wrong container type, or missing "
                "file/severity/summary) — see stderr. "
                "**이 실행은 clean이 아니다**: 버려진 주장은 심사되지 않았다.")''',
     '''                f"{dropped_malformed}개 지적을 버렸다 — 형식이 깨졌다(dropped as malformed: 매핑이 아니거나, "
                "담는 형이 틀리거나, file/severity/summary 가 없다) — stderr 참고. "
                "**이 실행은 clean이 아니다**: 버려진 주장은 심사되지 않았다.")'''),
    (SY, '''    out.append("| Sev | Path:Line | Summary | Source |")''',
     '''    out.append("| 심각도 | 위치 | 내용 | 낸 곳 |")'''),
    (SY, '''        out.append(f"| {sev} | {path_line} | {_cell(f.get('summary', ''))} | {source} |")''',
     '''        plain = f.get("plain")
        if isinstance(plain, str) and plain.strip():
            summary = _cell(f"{plain} ({f.get('summary', '')})")
        else:
            summary = _cell(f.get("summary", ""))
        out.append(f"| {sev} | {path_line} | {summary} | {source} |")'''),
    (SY, '''            f"{dropped_malformed} finding(s) dropped as malformed "
            "(not a mapping, wrong container type, or missing "
            "file/severity/summary) — see stderr.")''',
     '''            f"{dropped_malformed}개 지적을 버렸다 — 형식이 깨졌다(dropped as malformed: 매핑이 아니거나, "
            "담는 형이 틀리거나, file/severity/summary 가 없다) — stderr 참고.")'''),
    (SY, '''    out.append("**Suggested fixes:**")''', '''    out.append("**고칠 방법:**")'''),
    (SY, '''        fix = str(f.get("proposed_fix", "(none)"))''', '''        fix = str(f.get("proposed_fix", "(없음)"))'''),
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
    # SKILL — 합성기 표를 읽는 두 자리(머리 글자 · 고칠 방법 목록 이름)를 같은 글자로
    (SK, '''grep -q '^| Sev |' "$SYN"; then sed -n '/^| Sev |/,/^$/p' "$SYN";''',
         '''grep -q '^| 심각도 |' "$SYN"; then sed -n '/^| 심각도 |/,/^$/p' "$SYN";'''),
    (SK, "the `**Suggested fixes:**` list carries the same `#k`", "the `**고칠 방법:**` list carries the same `#k`"),
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
echo "Pipeline: scope → review → differential test → synthesis · verdict"
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

texts, bad = {}, []
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        bad.append("STOP %s: 옛 글자가 %d번 있다(기대 1): %r" % (rel, n, old[:80]))
        continue
    texts[rel] = t.replace(old, new)
if bad:
    sys.exit("\n".join(bad))
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
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_synth_output.sh $Q/test_synthesize_findings.sh $Q/test_synthesize_disposition.sh $Q/test_synthesize_findings_adjudication.py $Q/test_synthesize_promoted_findings.sh $Q/test_v_requirements.sh $Q/test_angle_coverage.sh \
  $Q/test_synthesize_recritic.sh $Q/test_verdict_vocabulary.sh $Q/test_v1_verdict_line.sh $Q/test_topic_scope_wiring.sh $Q/test_scope_tuple.sh $Q/test_pipeline_verdict_wiring.sh $Q/test_publish_pipeline_wiring.sh $Q/test_setup_qg.sh $Q/test_isolation.sh $Q/test_worktree.sh $Q/test_entry_safety_e1_e6.sh $Q/test_precheck_retired.sh $Q/test_skill_drop_notice_consumed.sh $Q/test_qg_false_clean_floor.sh $Q/test_resolution_disclosure.sh $Q/test_plain_qg_templates.sh $Q/test_guards_coverage_bidirectional.sh $Q/test_runner_adapters.sh $Q/test_e2e_docs.sh \
  shared/tests/test_python_floor.sh shared/tests/test_adjudication_wiring.sh shared/tests/test_adjudication_consumed.sh shared/tests/test_dispatch_disposition.sh
grep -a '컴프리헨션 내포' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/logs/test_adjudication_wiring.sh.log
```

기대(드라이런 실측): 서른 전부 `rc=0`(55/55 · 12 · 41/41 · OK · 16/16 · 31/31 · 185/185 · 234/234 · 104/104 · 10/10 · 79/79 · 50/50 · 79/79 · 117/117 · 69/69 · 11/11 · 13/13 · 113/113 · ok · 12/12 · 4/4 · 12/12 · 80/80 · 358/358 · 53/53 · 96/96 · 143/143 · 17/17 · 6/6 · 19/19). `test_verdict_vocabulary.sh` 는 수정 없이 GREEN(AC5). 마지막 줄 `✓ 컴프리헨션 내포 40 <= baseline 40`(R14).

- [ ] **Step 5: 커밋**

```bash
Q=plugins/quality-gates/tests
git add plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/skills/quality-pipeline/SKILL.md $Q/e2e-scenarios.md $Q/test_plain_synth_output.sh \
  $Q/test_synthesize_findings.sh $Q/test_synthesize_disposition.sh $Q/test_synthesize_findings_adjudication.py $Q/test_synthesize_promoted_findings.sh $Q/test_v_requirements.sh $Q/test_angle_coverage.sh
git commit -m "feat(qg): 합성기 첫 줄을 상태 문장으로, 표 · 배너 · setup 오류 줄을 한국어로

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat HEAD | tail -1
git ls-files -s $Q/test_plain_synth_output.sh | cut -c1-6
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_publish_surface_removed.sh $Q/test_gate_era_prose_absent.sh shared/tests/test_dispatch_disposition.sh
```

기대: `11 files changed` · `100755` · 커밋 뒤 스윕 셋 `rc=0`(40/40 · 7/7 · 19/19).

- [ ] **Step 6: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py . t2 | tee ~/.claude/sdd-mirror/plain-language-output/pr3/mut-t2.txt
```

기대(드라이런 실측): `BASE-GREEN 7 tests` · `cells=32 red=32 survived=0 skip=0`. 셀 「SKILL 표 sed 범위만 옛 영어로」는 grep 앵커만 맞고 sed 범위가 어긋난 경우(「지적」 절이 조용히 빈다)를 잡는다.

---

## Task 3: `plain:` 칸 — 형식 · 넘기기 · 합치기 · 그리기 (§5 · AC9 · D2.8 · Deferred 7)

**Files:**
- Modify(형식): `plugins/quality-gates/agents/security-reviewer.md:96` 뒤 · `agents/code-recritic.md:69 · :96` 뒤 · `agents/artifact-critic.md:54` 뒤 · `agents/artifact-adversarial.md:61` 뒤 · `scripts/build_codex_prompt.py:78` 뒤 · `scripts/build_artifact_codex_prompt.py:62` 뒤 · `references/recritic-code-profile.md:10` · `skills/quality-pipeline/SKILL.md:355`(외부 리뷰어 프롬프트 — R3) · `:456` 뒤(옮겨 적기 — R4)
- Modify(넘기기): `shared/codex/codex_findings_to_yaml.py:66` · `scripts/synthesize_artifact_findings.py:133 · :292`. 합성기의 재비판 응답 읽기(`to_adjudication_doc` 의 `nf = dict(a)` · `promote_new_findings` 의 `f = dict(item)`)는 이미 칸을 통째로 넘긴다 — 코드는 고치지 않고 테스트만 더한다. 익명화(`anonymize`)는 재비판자에게 `plain` 을 넘기지 않는다(프레이밍 차단 — 그대로, 락이 잰다)
- Modify(합치기): `scripts/synthesize_artifact_findings.py:128` 뒤 · `scripts/synthesize_findings.py:314` 뒤(dedup) · `:326` 앞(`_has_plain` — `:310` 의 EXEMPT 자리보다 아래, R14)
- Modify(그리기): Task 2 에서 끝났다(표의 요약 칸)
- Modify(고정 단언): `plugins/quality-gates/tests/test_security_reviewer_behavior.py:25 · :62 · :68`
- Create: `plugins/quality-gates/tests/test_plain_field_path.sh`

**Interfaces:**
- 칸 이름 `plain`(문자열, 선택). 뜻: 「처음 보는 사람에게 보일 쉬운 한 문장 — 내부 번호 없이」. 없거나 공백뿐이면 없는 것으로 친다.
- 합치기: 남는 쪽(코드 경로 — 같은 좌표 · 등급 묶음의 먼저 온 쪽, 비코드 경로 — 같은 키의 먼저 온 쪽)에 칸이 없으면 합쳐진 다른 쪽 중 먼저 온 쪽의 칸을 물려받는다. 남는 쪽에 칸이 있으면 덮어쓰지 않는다. (#194 가 confidence 를 지워 코드 경로의 「남는 쪽」이 「신뢰도 높은 쪽」에서 「먼저 온 쪽」으로 바뀌었다.)

- [ ] **Step 1: 실패하는 락을 쓴다**

`plugins/quality-gates/tests/test_plain_field_path.sh`:

````bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/synthesize_artifact_findings.py shared/codex/codex_findings_to_yaml.py plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/code-recritic.md plugins/quality-gates/agents/artifact-critic.md plugins/quality-gates/agents/artifact-adversarial.md plugins/quality-gates/scripts/build_codex_prompt.py plugins/quality-gates/scripts/build_artifact_codex_prompt.py plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/lib/recritic_fixture.sh
#
# 쉬운 말 출력 설계 §5 · AC9 · D2.8 — 생산자마다 리뷰어 출력 하나가 변환·합성을 지나 화면까지 가고, 거기서 plain 이
# 먼저 나온다. plain 이 없는 지적은 버려지지 않고 지금처럼 나온다. 재비판자에게는 plain 을 넘기지 않는다(프레이밍 차단).
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
. "$PLUGIN_ROOT/tests/lib/recritic_fixture.sh"
export PYTHONDONTWRITEBYTECODE=1
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
ART="$PLUGIN_ROOT/scripts/synthesize_artifact_findings.py"
CONV="$REPO_ROOT/shared/codex/codex_findings_to_yaml.py"
S="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
A="$PLUGIN_ROOT/agents"
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }

# ① 형식 — 생산자마다 plain 칸이 형식에 있다. 「explain」 같은 낱말이 우연히 맞지 않게 칸 모양으로 잰다.
assert_file_grep "$A/security-reviewer.md" '^  plain: <optional — the same finding in one plain sentence' "AC9 형식: security-reviewer 의 finding 형식에 plain 칸"
assert_file_grep "$A/artifact-critic.md" '^    plain: "optional — the same finding in one plain sentence' "AC9 형식: artifact-critic 의 finding 형식에 plain 칸"
assert_file_grep "$A/artifact-adversarial.md" '^    plain: "optional — one plain sentence' "AC9 형식: artifact-adversarial 의 new_findings 형식에 plain 칸"
assert_file_grep "$PLUGIN_ROOT/scripts/build_codex_prompt.py" '^      "plain": "<optional: the same finding in one plain sentence' "AC9 형식: codex 코드 리뷰 프롬프트에 plain 칸"
assert_file_grep "$PLUGIN_ROOT/scripts/build_artifact_codex_prompt.py" '^    plain: "optional — the same finding in one plain sentence' "AC9 형식: codex 비코드 리뷰 프롬프트에 plain 칸"
assert_contains "$(flat "$PLUGIN_ROOT/references/recritic-code-profile.md")" '`plain`(선택)에는 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장으로 — 내부 번호 없이 — 쓴다' "AC9 형식(D2.8): 재비판 프로필의 added 형식에 plain"
assert_contains "$(flat "$A/code-recritic.md")" '`plain`(선택)에는 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장을 — 내부 번호 없이 — 쓴다' "AC9 형식(D2.8): code-recritic 의 added 문장에 plain"
assert_file_grep "$A/code-recritic.md" '^    plain: "선택 — 처음 보는 사람이 읽을 쉬운 한 문장"$' "AC9 형식(D2.8): code-recritic 의 출력 예시에 plain"
assert_contains "$(flat "$S")" 'summary, plain (optional — the same finding in one plain sentence a first-time reader understands, no internal IDs), proposed_fix.' "AC9 형식(D2.8 · R3): 외부 리뷰어 dispatch 프롬프트가 plain 을 묻는다"
assert_contains "$(flat "$S")" '**각 항목의 `plain:` 은 리뷰어가 쓴 문장 그대로 싣는다** — 없으면 키를 뺀다(지어내지 않는다).' "R4: 오케스트레이터가 findings.yaml 에 plain 을 옮기고 지어내지 않는다"
# 생성된 codex 프롬프트에 칸이 실제로 실린다(파일 문면이 아니라 빌더 출력)
assert_contains "$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import build_codex_prompt as b; print(b.PROMPT_TEMPLATE)' "$PLUGIN_ROOT/scripts" 2>/dev/null)" '"plain":' "AC9 형식: codex 코드 리뷰 빌더의 PROMPT_TEMPLATE 이 plain 을 싣는다"
# 형식 칸만 더했다 — 리뷰어 도구 목록은 그대로다(Law 2)
assert_file_grep "$A/security-reviewer.md" '^tools: Read, Grep, Glob$' "Law 2: security-reviewer 의 tools 는 그대로다"
assert_file_grep "$A/code-recritic.md" '^tools: Read, Grep, Glob$' "Law 2: code-recritic 의 tools 는 그대로다"

# ② 보안 리뷰어 · 외부 리뷰어 경로 — 오케스트레이터가 쓴 findings.yaml → 재비판 → 합성기 표
mkdir -p "$T/sec"
printf -- '- {agent: security-reviewer, file: app.py, line: 3, severity: CRITICAL, summary: "SQL 문자열 결합", plain: "입력값이 그대로 데이터베이스 명령에 들어간다", proposed_fix: "바인딩"}\n- {agent: code-reviewer, file: lib.py, line: 7, severity: IMPORTANT, summary: "예외를 삼킨다", proposed_fix: "다시 던진다"}\n- {agent: code-reviewer, file: k.py, line: 9, severity: IMPORTANT, summary: "빈 칸", plain: "   ", proposed_fix: p}\n' > "$T/sec/findings.yaml"
rf_prep "$T/sec"; rf_reply "$T/sec" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}'
out="$(rf_synth "$T/sec")"
assert_grep "$out" '\| 입력값이 그대로 데이터베이스 명령에 들어간다 \(SQL 문자열 결합\) \|' "AC9: plain 이 먼저, 원래 요약은 뒤 괄호"
assert_grep "$out" '\| 예외를 삼킨다 \| code-reviewer \|$' "AC9(Review Focus 1): plain 없는 지적도 지금처럼 나온다"
assert_grep "$out" '\| 빈 칸 \| code-reviewer \|$' "공백뿐인 plain 은 없는 것으로 친다"
assert_grep "$out" '^\*\*Findings:\*\* 1 CRITICAL / 2 IMPORTANT / 0 SUGGESTION$' "AC9: 세 지적 모두 셌다(버린 것 없음)"
# 재비판자에게는 plain 을 넘기지 않는다 — 누가 어떻게 풀어 썼는지가 판단을 끌고 간다
assert_not_contains "$(cat "$T/sec/rf.yaml")" "plain" "프레이밍 차단: 익명 목록에 plain 이 없다"
assert_contains "$(cat "$T/sec/rf.yaml")" "SQL 문자열 결합" "익명 목록에 요약은 있다(양성 짝)"

# ③ codex 코드 리뷰 경로 — codex JSONL → codex_findings_to_yaml(default) → 합성기
python3 - "$T/codex.jsonl" <<'PY'
import json, sys
text = "```json\n" + json.dumps({"findings": [{"file": "x.py", "line": 2, "severity": "IMPORTANT",
        "summary": "경계 검사 누락", "plain": "길이를 확인하지 않아 범위를 넘어 읽는다", "proposed_fix": "검사 추가"}]}, ensure_ascii=False) + "\n```"
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": text}}, ensure_ascii=False) + "\n")
PY
python3 "$CONV" < "$T/codex.jsonl" > "$T/codex.yaml"
assert_file_grep "$T/codex.yaml" '^ *plain: ' "AC9: codex 변환이 plain 을 넘긴다"
mkdir -p "$T/cx"
python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1],encoding="utf-8")); fs=d["findings"]; [f.__setitem__("agent","codex-reviewer") for f in fs]; open(sys.argv[2],"w",encoding="utf-8").write(yaml.safe_dump(fs,allow_unicode=True))' "$T/codex.yaml" "$T/cx/findings.yaml"
rf_prep "$T/cx"; rf_reply "$T/cx" 'verdicts:
  - {f: f1, verdict: confirm}'
out="$(rf_synth "$T/cx")"
assert_grep "$out" '\| 길이를 확인하지 않아 범위를 넘어 읽는다 \(경계 검사 누락\) \|' "AC9: codex 지적의 plain 이 화면에 먼저 나온다"

# ④ 재비판자가 더한 지적(added) — qg-recritic 블록 → 합성기
mkdir -p "$T/add"; printf '[]\n' > "$T/add/findings.yaml"; rf_prep "$T/add"
rf_reply "$T/add" 'verdicts: []
added:
  - file: lib.py
    line: 4
    severity: CRITICAL
    summary: "놓친 경로 탐색"
    plain: "사용자가 준 경로로 다른 폴더의 파일을 읽을 수 있다"
    proposed_fix: "정규화 후 비교"'
out="$(rf_synth "$T/add")"
assert_grep "$out" '\| 사용자가 준 경로로 다른 폴더의 파일을 읽을 수 있다 \(놓친 경로 탐색\) \| code-recritic \|' "AC9(D2.8): 재비판 added 의 plain 이 화면에 먼저 나온다"

# ⑤ 비코드 산출물 경로 — key → synth 의 kept 에 plain 이 남는다(R7)
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s1", severity: CRITICAL, summary: "gap A", plain: "이 절은 앞 절과 반대로 말한다", proposed_fix: "fix A"}\n' > "$T/critic.yaml"
python3 "$ART" --phase key --findings "$T/critic.yaml" > "$T/merged.yaml" 2>/dev/null
assert_file_grep "$T/merged.yaml" '^ *plain: ' "AC9: artifact key 단계가 plain 을 넘긴다"
K="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"][0]["dedup_key"])' "$T/merged.yaml")"
printf 'verdicts:\n  - {finding_key: "%s", verdict: confirm, evidence: real}\n' "$K" > "$T/adv.yaml"
out="$(python3 "$ART" --phase synth --findings "$T/merged.yaml" --adversarial "$T/adv.yaml" 2>/dev/null)"
assert_contains "$out" "이 절은 앞 절과 반대로 말한다" "AC9: artifact synth 의 kept 에 plain 이 남는다"

# ⑥ 표 칸을 깨는 글자 (Review Focus 2)
mkdir -p "$T/esc"
printf -- '- agent: security-reviewer\n  file: a.py\n  line: 1\n  severity: IMPORTANT\n  summary: "s"\n  plain: "왼쪽 | 오른쪽\\n둘째 줄"\n  proposed_fix: "p"\n' > "$T/esc/findings.yaml"
rf_prep "$T/esc"; rf_reply "$T/esc" 'verdicts:
  - {f: f1, verdict: confirm}'
out="$(rf_synth "$T/esc")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^| IMPORTANT |')" "1" "Review Focus 2: plain 의 | 와 개행이 표 행을 깨지 않는다"
assert_grep "$out" '왼쪽 \\\| 오른쪽 둘째 줄 \(s\)' "Review Focus 2: | 는 이스케이프되고 개행은 공백이 된다"

# ⑦ 합칠 때 칸이 사라지지 않는다 (Review Focus 5) — 코드 경로 · 비코드 경로
mkdir -p "$T/dup"
printf -- '- {agent: security-reviewer, file: d.py, line: 5, severity: IMPORTANT, summary: "같은 지적", proposed_fix: p}\n- {agent: code-reviewer, file: d.py, line: 5, severity: IMPORTANT, summary: "같은 지적", plain: "같은 줄을 두 리뷰어가 짚었다", proposed_fix: p}\n- {agent: silent-failure-hunter, file: d.py, line: 5, severity: IMPORTANT, summary: "같은 지적", plain: "셋째가 쓴 다른 문장", proposed_fix: p}\n' > "$T/dup/findings.yaml"
rf_prep "$T/dup"; rf_reply "$T/dup" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}
  - {f: f3, verdict: confirm}'
out="$(rf_synth "$T/dup")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^| IMPORTANT | d\.py:5 |')" "1" "Review Focus 5: 같은 지적 셋이 한 행으로 합쳐졌다"
assert_contains "$out" "같은 줄을 두 리뷰어가 짚었다 (같은 지적)" "Review Focus 5: 남는 쪽에 plain 이 없으면 합쳐진 다른 쪽 중 먼저 온 쪽의 plain 을 물려받는다"
assert_not_contains "$out" "셋째가 쓴 다른 문장" "Review Focus 5: 물려받는 것은 하나 — 먼저 온 쪽이다"
mkdir -p "$T/dup2"
printf -- '- {agent: security-reviewer, file: e.py, line: 6, severity: IMPORTANT, summary: "같은 지적", plain: "먼저 온 쪽의 문장", proposed_fix: p}\n- {agent: code-reviewer, file: e.py, line: 6, severity: IMPORTANT, summary: "같은 지적", plain: "나중 쪽의 문장", proposed_fix: p}\n' > "$T/dup2/findings.yaml"
rf_prep "$T/dup2"; rf_reply "$T/dup2" 'verdicts:
  - {f: f1, verdict: confirm}
  - {f: f2, verdict: confirm}'
out="$(rf_synth "$T/dup2")"
assert_contains "$out" "먼저 온 쪽의 문장 (같은 지적)" "Review Focus 5: 남는 쪽에 plain 이 있으면 그대로다"
assert_not_contains "$out" "나중 쪽의 문장" "Review Focus 5: 남는 쪽의 plain 을 덮어쓰지 않는다"
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s2", severity: IMPORTANT, summary: "gap B", proposed_fix: "fix B"}\n' > "$T/c1.yaml"
printf 'findings:\n  - {agent: codex, category: logic, target_anchor: "#s2", severity: IMPORTANT, summary: "gap B", plain: "둘째 절이 빠졌다", proposed_fix: "fix B"}\n' > "$T/c2.yaml"
python3 "$ART" --phase key --findings "$T/c1.yaml" --findings "$T/c2.yaml" > "$T/m2.yaml" 2>/dev/null
assert_eq "$(grep -c '^ *plain: ' "$T/m2.yaml")" "1" "Review Focus 5: 비코드 합치기도 다른 쪽의 plain 을 물려받는다"
finish
````

```bash
chmod +x plugins/quality-gates/tests/test_plain_field_path.sh
```

(③ 의 `python3 - … <<'PY'` 는 `$( )` 밖이라 heredoc 파싱 함정이 없다. `yaml` 은 이 플러그인 테스트가 이미 쓴다. ① 의 형식 단언은 칸 모양(`^  plain: <optional` 등)으로 잰다 — 맨 낱말 `plain` 은 「explain」에도 맞는다.)

- [ ] **Step 2: 고정 단언 — 보안 리뷰어의 출력 키 집합**

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_security_reviewer_behavior.py:25` | `FINDING_KEYS = {…}` | 그 아래 `OPTIONAL_KEYS = {"plain"}` 을 더함 | 출력 키 집합의 정본 |
| `test_security_reviewer_behavior.py:62` | 페르소나 형식 블록의 키 = `FINDING_KEYS` | `= FINDING_KEYS \| OPTIONAL_KEYS` | 형식에 선택 칸이 있다(없으면 RED — 변이 「보안 리뷰어 형식에서 plain 빼기」가 이 테스트로도 잡힌다) · confidence 는 여전히 없다 |
| `test_security_reviewer_behavior.py:68` | fixture 의 키 = `FINDING_KEYS` | `- OPTIONAL_KEYS` 뒤 `= FINDING_KEYS` | fixture 는 선택 칸이 있어도 없어도 된다 |

이 자리는 #194 가 만든 v10 키 집합 락이다(옛 계획엔 없었다 — 드라이런 1회차가 RED 로 찾았다). 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t3_pins.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 3 — 보안 리뷰어의 출력 키 집합을 고정한 단언에 선택 칸 plain 을 들인다 (리포 루트를 인자로).
옛 글자가 전부 기대 개수(1)만큼 있는지 먼저 다 재고, 하나라도 다르면 아무것도 쓰지 않고 STOP 한다."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
T = "plugins/quality-gates/tests/"
EDITS = [
    (T + "test_security_reviewer_behavior.py",
     'FINDING_KEYS = {"agent", "file", "line", "severity", "summary", "proposed_fix"}\n',
     'FINDING_KEYS = {"agent", "file", "line", "severity", "summary", "proposed_fix"}\n'
     '# 쉬운 말 출력 §5 — 사람에게 보일 한 문장(선택 칸). 형식에는 있고, 출력에는 있어도 없어도 된다.\n'
     'OPTIONAL_KEYS = {"plain"}\n'),
    (T + "test_security_reviewer_behavior.py",
     '        self.assertEqual(keys, FINDING_KEYS)\n',
     '        self.assertEqual(keys, FINDING_KEYS | OPTIONAL_KEYS)\n'),
    (T + "test_security_reviewer_behavior.py",
     '            self.assertEqual(set(e), FINDING_KEYS)\n',
     '            self.assertEqual(set(e) - OPTIONAL_KEYS, FINDING_KEYS)\n'),
]
texts, bad = {}, []
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        bad.append("STOP %s: 옛 글자가 %d번 있다(기대 1): %r" % (rel, n, old[:90]))
        continue
    texts[rel] = t.replace(old, new)
if bad:
    sys.exit("\n".join(bad))
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t3_pins.py .
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh plugins/quality-gates/tests/test_plain_field_path.sh plugins/quality-gates/tests/test_security_reviewer_behavior.py
```

기대(드라이런 실측): `test_plain_field_path` 32 중 17 RED(GREEN 열다섯은 Task 2 가 이미 넣은 렌더(plain 먼저 · 이스케이프)와 합성기가 재비판 응답을 통째로 넘기는 것으로 참인 ② · ④ · ⑥, `tools:` 둘, 합치기에서 남는 쪽이 이미 칸을 가진 경우다. RED 열일곱은 형식 열하나 · 변환기 둘 · 비코드 둘 · 물려받기 둘) · `test_security_reviewer_behavior` 1 RED.

- [ ] **Step 3: 형식 아홉 · 넘기는 곳 셋 · 합치기 둘**

찾는 지시는 한 글자도 바꾸지 않는다 — 형식 칸 한 줄(또는 한 문장)을 `summary` 바로 뒤에 더할 뿐이다. `codex_findings_to_yaml.py` 의 `DEFAULT_KEYS` 는 끝에 더하므로 칸이 없는 입력의 출력 바이트는 그대로다 — `yaml_emit`(107-125)은 `if k in f:` 로 있는 키만 쓴다(`plugins/spec-distill/tests/test_codex_findings_to_yaml.py` 의 바이트 고정 GREEN). 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t3_edit.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 3 — plain 칸: 형식 아홉 · 넘기는 곳 셋 · 합치기 둘 (리포 루트를 인자로).
찾는 지시는 한 글자도 바꾸지 않는다 — 형식 칸 한 줄(또는 한 문장)을 summary 바로 뒤에 더할 뿐이다.
옛 글자가 전부 기대 개수(1)만큼 있는지 먼저 다 재고, 하나라도 다르면 아무것도 쓰지 않고 STOP 한다."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
Q = "plugins/quality-gates/"
EDITS = [
    # 형식 — agent 정의 넷(보안 민감: 칸만 더한다 · tools: 불변)
    (Q + "agents/security-reviewer.md",
     "  summary: <one-sentence describing the vulnerability and its path>\n",
     "  summary: <one-sentence describing the vulnerability and its path>\n"
     "  plain: <optional — the same finding in one plain sentence a first-time reader understands, no internal IDs>\n"),
    (Q + "agents/code-recritic.md",
     "`summary` · `proposed_fix` 를 싣는다. 막는 지적의 기준은 프로필 뒤에 붙은 「리뷰 기준」 블록이다.\n",
     "`summary` · `proposed_fix` 를 싣는다. `plain`(선택)에는 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장을 — 내부 번호 없이 — "
     "쓴다. 막는 지적의 기준은 프로필 뒤에 붙은 「리뷰 기준」 블록이다.\n"),
    (Q + "agents/code-recritic.md",
     '    summary: "..."\n',
     '    summary: "..."\n'
     '    plain: "선택 — 처음 보는 사람이 읽을 쉬운 한 문장"\n'),
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
    # 형식 — 외부 추가 리뷰어 dispatch 프롬프트(R3) · 오케스트레이터가 옮겨 적기(R4)
    (Q + "skills/quality-pipeline/SKILL.md",
     "SUGGESTION — by the criteria block), summary, proposed_fix.\n",
     "SUGGESTION — by the criteria block), summary, plain (optional — the same finding in one plain sentence a\n"
     "first-time reader understands, no internal IDs), proposed_fix.\n"),
    (Q + "skills/quality-pipeline/SKILL.md",
     "   never trust an `agent:` a reviewer wrote. Do not copy a `confidence:` field.\n",
     "   never trust an `agent:` a reviewer wrote. Do not copy a `confidence:` field.\n"
     "   **각 항목의 `plain:` 은 리뷰어가 쓴 문장 그대로 싣는다** — 없으면 키를 뺀다(지어내지 않는다).\n"),
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
     '                # 남는 쪽(먼저 온 쪽)에 plain 이 없고 새로 온 쪽에 있으면 물려받는다(칸이 합치기에서 사라지지 않게).\n'
     '                if not by_key[k].get("plain") and g.get("plain"):\n'
     '                    by_key[k]["plain"] = g["plain"]\n'),
    # 합치기 — 코드 합성기 dedup(먼저 온 쪽이 남는다 — 그쪽에 칸이 없으면 합쳐진 다른 쪽 중 먼저 온 쪽의 칸을 물려받는다)
    (Q + "scripts/synthesize_findings.py",
     '        merged = dict(group[0])\n',
     '        merged = dict(group[0])\n'
     '        # 남는 쪽(먼저 온 쪽)에 plain 이 없으면 합쳐진 다른 쪽 중 가장 먼저 온 쪽의 plain 을 물려받는다.\n'
     '        # 뒤에서부터 덮어쓰므로 break 가 없다 — 이 파일은 처분 회계 소비자라 컴프리헨션 ·\n'
     '        # 버리는 분기(break/continue)가 `shared/tests/test_adjudication_wiring.sh` 에 묶여 있다.\n'
     '        if not _has_plain(merged):\n'
     '            for g in reversed(group[1:]):\n'
     '                if _has_plain(g):\n'
     '                    merged["plain"] = g["plain"]\n'),
    # dedup 보다 «뒤»에 둔다 — tools/adjudication/check_wiring.py 의 EXEMPT 가 dedup 안의 분기를 줄 번호로 가리킨다.
    (Q + "scripts/synthesize_findings.py",
     'def sort_findings(findings):\n',
     'def _has_plain(f):\n'
     '    """리뷰어가 쓴 쉬운 한 문장(`plain`)이 있는가 — 문자열이고 공백뿐이 아니어야 있다."""\n'
     '    return isinstance(f.get("plain"), str) and bool(f["plain"].strip())\n'
     '\n'
     '\n'
     'def sort_findings(findings):\n'),
]
texts, bad = {}, []
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        bad.append("STOP %s: 옛 글자가 %d번 있다(기대 1): %r" % (rel, n, old[:90]))
        continue
    texts[rel] = t.replace(old, new)
if bad:
    sys.exit("\n".join(bad))
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

- [ ] **Step 4: 테스트를 돈다(AC9)**

```bash
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_field_path.sh $Q/test_synthesize_findings.sh $Q/test_synthesize_recritic.sh $Q/test_synthesize_promoted_findings.sh $Q/test_synthesize_disposition.sh $Q/test_synthesize_artifact_findings.sh $Q/test_synthesize_artifact_adjudication.py $Q/test_synthesize_findings_adjudication.py $Q/test_recritic_code_profile.sh $Q/test_code_recritic_frontmatter.sh \
  $Q/test_build_codex_prompt.sh $Q/test_artifact_codex_reviewer.sh $Q/test_codex_copies_agree.sh $Q/test_codex_prompt_untrusted_clause.sh $Q/test_codex_result_banner.sh $Q/test_codex_invocation_contract.sh $Q/test_codex_extractor_positive_marker.sh \
  $Q/test_security_reviewer_kill_switch.sh $Q/test_security_reviewer_persona.sh $Q/test_security_reviewer_behavior.py $Q/test_agent_tools_lock_mutation.sh $Q/test_agent_tools_lock_differential.sh $Q/test_artifact_critic_frontmatter.sh $Q/test_artifact_adversarial_frontmatter.sh $Q/test_agent_frontmatter_keys.sh $Q/test_agent_model_unpinned_sweep.sh \
  $Q/test_review_scope_composition.sh $Q/test_skill_orchestration.sh $Q/test_v_requirements.sh $Q/test_skill_run_contract.sh $Q/test_pipeline_verdict_wiring.sh $Q/test_plain_qg_templates.sh $Q/test_plain_synth_output.sh $Q/test_guards_coverage_bidirectional.sh $Q/test_runner_adapters.sh \
  plugins/spec-distill/tests/test_codex_findings_to_yaml.py shared/tests/test_adjudication_wiring.sh shared/tests/test_agent_input_slots.sh shared/tests/test_invocation_surface.sh shared/tests/test_plain_language_block.sh shared/tests/test_docreview_codex.sh shared/tests/test_python_floor.sh shared/tests/test_dispatch_disposition.sh
grep -a '컴프리헨션 내포\|exempt_stale\|면제 목록' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/logs/test_adjudication_wiring.sh.log
git diff HEAD -- plugins/quality-gates/agents | grep '^[-+]tools' || echo "tools 불변"
```

기대(드라이런 실측): 마흔셋 전부 `rc=0`(32/32 · 12 · 234/234 · 16/16 · 41/41 · 42/42 · OK · OK · 26/26 · 21/21 · 13/13 · 15/15 · 77/77 · 43/43 · 5/5 · 39/39 · PASS · 13/13 · 47/47 · OK · 85/85 · 92/92 · 9/9 · 10/10 · PASS · 5/5 · 21/21 · 3/3 · 31/31 · 102/102 · 79/79 · 80/80 · 55/55 · 371/371 · 53/53 · OK · 17/17 · 14/14 · 69/69 · 12/12 · 280/280 · 143/143 · 19/19), `exempt_stale=0` · 면제 11 · 컴프리헨션 40(R14), 마지막 줄 `tools 불변`. `test_pipeline_verdict_wiring.sh` 가 이 목록에 있는 이유: R4 문장이 그 파일의 부재 락(「리뷰어가 낸 값을 그대로 옮긴다」)에 걸리지 않는지 잰다.

- [ ] **Step 5: 커밋 · 깨끗한 트리 전제 락**

```bash
Q=plugins/quality-gates/tests
git add plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/code-recritic.md plugins/quality-gates/agents/artifact-critic.md plugins/quality-gates/agents/artifact-adversarial.md plugins/quality-gates/scripts/build_codex_prompt.py plugins/quality-gates/scripts/build_artifact_codex_prompt.py plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/skills/quality-pipeline/SKILL.md shared/codex/codex_findings_to_yaml.py plugins/quality-gates/scripts/synthesize_artifact_findings.py plugins/quality-gates/scripts/synthesize_findings.py $Q/test_plain_field_path.sh $Q/test_security_reviewer_behavior.py
git commit -m "feat(qg): 리뷰어 지적마다 사람이 읽을 한 문장(plain) 칸, 화면에 먼저

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat HEAD | tail -1
git ls-files -s $Q/test_plain_field_path.sh | cut -c1-6
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_agent_model_mutation.sh $Q/test_publish_surface_removed.sh $Q/test_gate_era_prose_absent.sh shared/tests/test_dispatch_disposition.sh
```

기대: `13 files changed` · `100755` · 넷 다 `rc=0`(46/46 · 40/40 · 7/7 · 19/19 — 첫째는 커밋 전에는 「agents/ 에 미커밋 변경」으로 RED 다).

- [ ] **Step 6: 변이**

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py . t3 | tee ~/.claude/sdd-mirror/plain-language-output/pr3/mut-t3.txt
```

기대(드라이런 실측): `BASE-GREEN 2 tests` · `cells=22 red=22 survived=0 skip=0` — 설계 AC9 의 변이 셋(렌더가 칸 없는 지적을 건너뛰기 · 비코드 허용 목록에서 `plain` 빼기 · 변환기가 `plain` 을 버리기)과 생산자 아홉의 형식 칸 빼기, 합치기 셋(물려받기 지우기 · 나중 쪽이 이김 · 남는 쪽 덮어쓰기), 익명 목록 누설, 새 규칙 문장마다 한 셀(옮겨 적기 지우기 · 「지어내지 않는다」 뒤집기 · 「내부 번호 없이」 지우기 등).

---

## Task 4: README · 소개 문구 · 버전 (§8 · AC10 · R13 · R17 · R21 · R22)

**Files:**
- Modify: `plugins/quality-gates/README.md:3`(첫 문단) · `:225`(「파이프라인 흐름」 첫 문단) · `:302-311`(`## 사용` → `## 쓰는 법`)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:46`(제목의 버전 — R22)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`(description · version) · `.claude-plugin/marketplace.json`(quality-gates 항목) · `shared/tests/test_charter_citations.sh:31-33`(`QG_DESC`)
- Modify: `plugins/quality-gates/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`(version) · `plugins/spec-distill/CHANGELOG.md`
- Create: `plugins/quality-gates/tests/test_plain_readme.sh`

- [ ] **Step 1: README 를 어디까지 다시 쓰는지**

88a763c2 의 README 는 이미 한국어 중심이다(481줄). 다시 쓰는 것은 R13 의 넷뿐이다 — 첫 문단(무엇을 해 주는지 네 문장 — e2e 한 문장(R21) · 게시 한 문장(R17) 포함) · `## 쓰는 법` 표(「이럴 때 — 친다 — 나오는 것」, 진입 명령 다섯 — `/qg-publish` 는 #196 이 지웠다) · 「파이프라인 흐름」 첫 문단 · 상태도의 질문 표지와 라벨(Task 1 에서 끝). 지워지면 안 되는 것(88a763c2 의 README 락 전수 — `git grep -ln README -- plugins/*/tests shared/tests tools` 중 qg README 를 읽는 것):

- `test_readme_state_diagram_complete.sh`: `single assistant turn` 정확히 1번 · `setup-qg.sh` · `SKILL preflight` · `trivia escape` · `qg iter loop` · `① review` · `② differential test` · `③ synthesize → verdict` · `AskUserQuestion` · `남은 지적이 있다` · `Final verdict`. 없어야 하는 것: `stateDiagram-v2` · `Runtime gate dispatch` · `Review gate iter loop` · `gate scope?` · `NEEDS_RESOLUTION` · `⑤ synthesize` · `Final summary` · `findings remain`.
- `test_readme_scope_reconcile.sh`: `리뷰어 구성 ≤ 8` · `총/iteration ≤ 10` · `transparency`(「Fan-out」 문단에 남는다 — 흐름 첫 문단에서 빠져도 GREEN) · `## 리뷰어 구성` · 구성 표의 보안 · 다른 모델 계열 · 재비판 행 · `Prerequisites (optional dependency)` · `` pr-review-toolkit`(code-reviewer `` · `every non-trivia pipeline iteration when detected`. 없어야 하는 것: `len(phase1)` · `= 12` · `subagent fan-out gate` · `gates subagent fan-out` · `feature-dev` · 옛 codex-depth 문구 둘.
- `test_gate_era_prose_absent.sh:53-55`: codex 비용 동의 게이트 주장 부재 · `every non-trivia pipeline iteration when detected (scope-independent)**. Disable globally with …` 줄.
- `test_impact_runtime_docs.sh:53-67`: `## 구조` 머리글로 자른 트리에 스크립트 다섯 · `## 인스턴스화한 원칙` 머리글로 자른 절에 `LD3` · `LD5` · `LD7`.
- `test_artifact_metadata.sh:14-15`: `critique` · `artifact-critic|critiquing-artifacts`.
- `test_e2e_docs.sh`(④): 상태도의 `^ ├ e2e ` 줄 · 파이프라인 표 `^| ④ e2e |` · 사전 요건 `^- **e2e**` · 노브 `DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT`: 90 · kill switch 표 두 행 · 보안 문단 두 줄 · 알려진 한계 줄들 · P4 원칙 줄 · LD3 문장. 없어야 하는 것: 「e2e 걷기로 집행한다」 · 「주장을 거둔다」 · 「주장만 거뒀다」 · 「`--ensure` 경로로 들어오면」. 이 계획의 편집은 그 줄을 건드리지 않는다.
- `test_publish_surface_removed.sh`: README 를 포함한 코퍼스에 `qg[-_]publish|pr[-_ ]understanding` 이 없다(대소문자 무시).
- `test_law2_prose.sh`(모든 `plugins/*/README.md` 의 금지 표현) · `shared/tests/test_dispatch_name_defined.sh` · `shared/tests/test_python_floor.sh`(qg README 에 Python 바닥 prerequisite 를 쓰지 않는다) · `shared/tests/test_invocation_surface.sh` · `tools/adjudication/check_names.py`.
- CLAUDE.md 가 요구하는 절: `## 인스턴스화한 원칙`(Principles Instantiated) · `## 설치된 Hook`(Hooks Installed) · `## 사전 요건`(prerequisites). 머리글과 문면 그대로.

- [ ] **Step 2: 실패하는 락을 쓴다**

`plugins/quality-gates/tests/test_plain_readme.sh`:

````bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/README.md
#
# 쉬운 말 출력 설계 §8 (계획 R13 · R17) — README 첫 문단이 「무엇을 해 주는가」를 쉬운 말로 말하고, `## 쓰는 법` 이
# 「이럴 때 — 친다 — 나오는 것」 표로 진입 명령을 모두 싣는다. 흐름 첫 문단도 쉬운 말이다.
# CLAUDE.md 가 요구하는 원칙 절은 그대로 있다. 부재 단언마다 양성 짝이 있다.
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
RM="$PLUGIN_ROOT/README.md"
# 첫 문단 · 절 본문은 줄바꿈을 지워 잰다 — 다시 쓰일 때 문장이 줄을 넘을 수 있다.
lead="$(awk 'NR>1 && /^## /{exit} NR>1' "$RM" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$lead" "바뀐 코드를 내보내기 전에 확인한다." "§8: 첫 문단이 무엇을 해 주는지로 시작한다"
assert_contains "$lead" "판정 하나(\`clean\` · \`defect\` · \`not-certified (<사유>)\`)를 낸다." "§8: 첫 문단이 판정 셋을 말한다"
assert_contains "$lead" "열린 PR 이 있으면 판정 뒤 쉬운 설명과 판정 줄을 코멘트 하나로 단다" "R17: 첫 문단이 게시를 말한다"
assert_contains "$lead" "원하면 판정 전에 사람이 승인한 명령으로 앱을 띄워 직접 걸어 본다(e2e 걷기)." "R21: 첫 문단이 e2e 걷기(선택 · 사람 승인)를 말한다"
assert_not_contains "$lead" "Claude Code용 품질 검증 파이프라인" "§8: 옛 첫 문단이 없다"
use="$(awk '/^## 쓰는 법$/{f=1;next} f&&/^## /{exit} f' "$RM")"
assert_grep "$use" '^\| 이럴 때 \| 친다 \| 나오는 것 \|$' "§8: 쓰는 법이 「이럴 때 · 친다 · 나오는 것」 표다"
for c in '`/qg`' '`/qg branch`' '`/qg --paths <glob>...`' '`/qg --plan <path>`' '`/qg critique <path>`'; do
  assert_contains "$use" "| ${c} |" "§8: 쓰는 법 표에 ${c} 행이 있다"
done
assert_eq "$(printf '%s\n' "$use" | grep -c '^| [^-|]')" "6" "§8: 표는 머리 하나와 행 다섯이다(없는 명령 행이 없다)"
assert_contains "$use" "열린 PR 이 있으면 코멘트 하나를 단다" "R17: 게시는 /qg 행이 말한다(별도 명령이 없다)"
assert_contains "$use" "판정 전에 앱을 띄워 걸어 볼지 묻는다." "R21: /qg 행이 e2e 질문을 말한다"
# 「친다」 칸은 위 다섯 가운데 하나여야 한다 — 없어진 명령의 이름을 여기 적지 않는다(그 이름은
# tests/test_publish_surface_removed.sh 의 개념 별칭 스윕이 이 파일에서도 잡는다).
cmds="$(printf '%s\n' "$use" | awk -F'|' '/^\| / && !/^\| 이럴 때 /{gsub(/^ +| +$/, "", $3); print $3}')"
bad="$(printf '%s\n' "$cmds" | grep -vxF -e '`/qg`' -e '`/qg branch`' -e '`/qg --paths <glob>...`' -e '`/qg --plan <path>`' -e '`/qg critique <path>`')"
assert_eq "${bad}" "" "R17: 표의 「친다」 칸은 진입 명령 다섯뿐이다(없어진 명령 행이 없다)"
assert_file_absent "$RM" '^## 사용$' "§8: 옛 「사용」 절이 없다(쓰는 법이 대신한다)"
flow="$(awk '/^## 파이프라인 흐름/{f=1;next} f&&/^```/{exit} f' "$RM" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$flow" "파이프라인은 한 턴 안에서 끝까지 돈다" "§8: 흐름 첫 문단이 쉬운 말이다"
assert_contains "$flow" "이 질문은 진행만 정하고 리뷰어 수를 막지 않는다." "§8: 흐름 첫 문단이 질문이 하는 일과 하지 않는 일을 말한다"
assert_not_contains "$flow" "serial dispatch로 실행합니다" "§8: 옛 흐름 문단이 없다"
assert_file_grep "$RM" '^## 인스턴스화한 원칙$' "CLAUDE.md: 원칙 절은 그대로 있다"
finish
````

```bash
chmod +x plugins/quality-gates/tests/test_plain_readme.sh
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh plugins/quality-gates/tests/test_plain_readme.sh
```

기대(드라이런 실측): 20 중 18 RED(GREEN 둘은 「「친다」 칸은 진입 명령 다섯뿐이다」(표가 아직 없어 공허하다 — 양성 짝은 행 다섯과 행 수) · 원칙 절).

- [ ] **Step 3: README · 소개 문구 · 버전 · CHANGELOG**

버전 두 개는 머지 직전에 정한다(Global Constraints 「버전」). 88a763c2 에서 정하면 `12.2.0` · `5.1.2` 다. 스크립트는 옛 버전 문자열과 두 CHANGELOG 의 맨 위 머리를 머리의 상수 넷으로 단언한다 — main 이 그 사이 움직였으면 `STOP` 이다. 그때는 번호를 다시 정하고 상수 넷을 그 트리의 값으로 고친다. 아래를 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t4_edit.py` 에 쓰고 돌린다:

````python
#!/usr/bin/env python3
"""PR 3 Task 4 — README · 소개 문구 · 버전 · CHANGELOG.
   pr3_t4_edit.py <리포 루트> <qg 버전> <spec-distill 버전> <YYYY-MM-DD>
옛 글자(옛 버전 문자열 · 두 CHANGELOG 의 맨 위 머리 포함)가 전부 기대 개수(1)만큼 있는지 먼저 다 재고,
하나라도 다르면 아무것도 쓰지 않고 STOP 한다. main 이 그 사이 움직였으면 아래 상수 넷을 그 트리 값으로 고친다."""
import pathlib, sys

R = pathlib.Path(sys.argv[1])
QV, SV, DAY = sys.argv[2], sys.argv[3], sys.argv[4]
QG_OLD_VER, QG_OLD_HEAD = "12.1.0", "## [12.1.0] — 2026-10-11"
SD_OLD_VER, SD_OLD_HEAD = "5.1.1", "## [5.1.1] — 2026-10-10"
Q = "plugins/quality-gates/"
OLD_DESC = ("Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test + optional "
            "human-approved e2e walk) with multi-plugin review delegation; each run posts one new PR comment "
            "(understanding + verdict line) when the branch has an open PR. Invoke manually via /qg.")
NEW_DESC = ("Checks a change before you ship it: one /qg run reviews the diff from several independent angles, "
            "runs the tests whose behavior changed, can walk the running app with your approval, and gives one "
            "verdict. When the branch has an open PR, it posts that verdict with a plain-language summary as one "
            "new comment.")

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
| 지금 바꾼 것을 내보내기 전에 | `/qg` | 판정 하나와 남은 지적 표. 지적이 남으면 고칠지 묻고(최대 5번), 판정 전에 앱을 띄워 걸어 볼지 묻는다. 열린 PR 이 있으면 코멘트 하나를 단다 |
| 브랜치 전체를 보고 싶을 때 | `/qg branch` | main 대비 브랜치 전체 diff 의 판정 |
| 일부 경로만 볼 때 | `/qg --paths <glob>...` | 그 경로만 리뷰한 판정 |
| 특정 계획 파일로 테스트를 고르게 할 때 | `/qg --plan <path>` | 그 계획을 차등 테스트 분류 기준으로 쓴 판정 |
| 문서 · 설계 · 설정을 비평받을 때 | `/qg critique <path>` | 비평 · 수정 라운드(라운드마다 커밋). 코드는 `/qg` 로 본다 |

`both` · `review` · `runtime` · `--skip-runtime` 은 제거됐다 — 한 줄 공지 후 그대로 진행한다(한 파이프라인이라 게이트 범위가 없다).
'''

QG_CHANGES = '''
## [%s] — %s

### Changed
- /qg 의 질문 셋(반복 · 수정 실패 · 최대 반복)과 선택지, 완료 표의 칸 이름이 한국어 쉬운 말이다. 반복 경계 앵커는 「남은 지적이 있다」다. 완료 표의 결과 칸은 게시 펜스가 읽는 토큰(`finished` · `accepted with findings iter N` · `aborted iter N`) 그대로다. 완료 보고는 끝난 방식과 판정값 한 문장으로 시작해 할 일 하나로 끝난다. 비평 모드의 최종 보고도 같다.
- e2e 걷기 직후 게이트(`## e2e` · `references/e2e.md`)가 부르는 Fix-loop 선택지 이름도 같은 낱말(「고치고 다시 돌기」 · 「지금 판정으로 끝내기」 · 「멈추기」)이다. e2e 칸 값(`pass` · `fail` · `미확인` 등)은 `verdict.py --e2e` 가 읽는 토큰이라 그대로다.
- 합성기 출력의 첫 줄이 스크립트가 계산한 상태 문장이다(예: 「리뷰를 합쳤다 — 남은 지적 2개(심각 1 · 중요 1).」 — 0 인 등급은 빼고, 형식이 깨져 버린 지적과 경고가 있으면 그것도 붙인다). 「No findings.」 줄은 그 첫 줄이 대신한다. 표 머리(`| 심각도 | 위치 | 내용 | 낸 곳 |`) · 「고칠 방법」 · 버린 지적 줄도 한국어다 — 표를 읽는 SKILL 자리(`result.md` 의 「지적」 절 · 분류표 번호)도 같은 글자로 바꿨다. `verdict:` · `**Findings:**` · `blocking:` · `optional:` 줄과 `dropped as malformed` 토큰은 형태 그대로다. 판정 꼬리의 `scope:` · `angles:` 블록 앞에 그것을 가리키는 쉬운 한 줄이 선다.
- 시작 배너가 과정 나열 없이 한 줄로 시작한다. setup 의 오류 줄이 쉬운 말로 시작하고 원래 영어 토큰은 괄호에 남는다.
- 범위 줄(「리뷰 범위: …」) · trivia 줄 · 범위 경고가 쉬운 말이다(`scope check degraded` 토큰은 괄호에 남는다).
- 공개 소개 문구(`plugin.json` · 마켓플레이스)가 무엇을 해 주는지로 시작한다(사람이 승인하는 e2e 걷기 포함). README 의 첫 문단 · 「쓰는 법」 표 · 흐름 첫 문단이 쉬운 말이다.

### Added
- 리뷰어 지적의 `plain:` 칸 — 처음 보는 사람이 읽을 쉬운 한 문장. 보안 리뷰어 · code-recritic 의 added · artifact-critic · artifact-adversarial · codex 리뷰어 둘 · 외부 리뷰어 dispatch 프롬프트에 형식이 있고, 합성기 표가 그것을 요약 앞에 쓴다. 칸이 없으면 지금처럼 나오고, 같은 지적을 합칠 때 칸은 사라지지 않는다. 재비판자에게 주는 익명 목록에는 싣지 않는다.

'''

EDITS = [
    (Q + "README.md",
     "Claude Code용 품질 검증 파이프라인 — 한 파이프라인, 한 판정(`clean` · `defect` · `not-certified (<사유>)`). 기준선 대비 차등 테스트는 매 실행 돈다.",
     "바뀐 코드를 내보내기 전에 확인한다. `/qg` 한 번이 diff 를 여러 독립 각도에서 리뷰하고, 동작이 바뀐 테스트를 "
     "기준선과 지금 트리 양쪽에서 돌려, 판정 하나(`clean` · `defect` · `not-certified (<사유>)`)를 낸다. 원하면 판정 "
     "전에 사람이 승인한 명령으로 앱을 띄워 직접 걸어 본다(e2e 걷기). 브랜치에 열린 PR 이 있으면 판정 뒤 쉬운 설명과 "
     "판정 줄을 코멘트 하나로 단다(`DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` 로 끈다)."),
    (Q + "README.md", USAGE_OLD, USAGE_NEW),
    (Q + "README.md",
     "`quality-pipeline` SKILL이 전체 파이프라인을 단일 assistant turn 내에서 serial dispatch로 실행합니다. fix-loop iteration은 AskUserQuestion으로 사용자 동의를 받아 진행합니다 — 이 도구는 progression/consent를 담당하며, subagent fan-out은 게이트하지 않습니다(fan-out은 transparency + 선언된 max fan-out으로 bound).",
     "파이프라인은 한 턴 안에서 끝까지 돈다(`quality-pipeline` SKILL 이 리뷰어를 차례로 부른다). 지적이 남으면 반복마다 "
     "`AskUserQuestion` 으로 고칠지 묻는다 — 이 질문은 진행만 정하고 리뷰어 수를 막지 않는다. 리뷰어 수는 위 "
     "「Fan-out」 의 선언된 상한이 묶는다."),
    (Q + ".claude-plugin/plugin.json", '"description": "%s",' % OLD_DESC, '"description": "%s",' % NEW_DESC),
    (Q + ".claude-plugin/plugin.json", '"version": "%s",' % QG_OLD_VER, '"version": "%s",' % QV),
    (".claude-plugin/marketplace.json", '"description": "%s",' % OLD_DESC, '"description": "%s",' % NEW_DESC),
    ("shared/tests/test_charter_citations.sh",
     '''QG_DESC = ("Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test + optional human-approved e2e walk) "
           "with multi-plugin review delegation; each run posts one new PR comment (understanding + verdict line) "
           "when the branch has an open PR. Invoke manually via /qg.")''',
     '''QG_DESC = ("Checks a change before you ship it: one /qg run reviews the diff from several independent angles, "
           "runs the tests whose behavior changed, can walk the running app with your approval, and gives one "
           "verdict. When the branch has an open PR, it posts that verdict with a plain-language summary as one "
           "new comment.")'''),
    (Q + "skills/quality-pipeline/SKILL.md", "# Quality Gates — In-Turn Orchestrator (v%s)\n" % QG_OLD_VER,
     "# Quality Gates — In-Turn Orchestrator (v%s)\n" % QV),
    ("plugins/spec-distill/.claude-plugin/plugin.json", '"version": "%s",' % SD_OLD_VER, '"version": "%s",' % SV),
    (Q + "CHANGELOG.md", "\n%s\n" % QG_OLD_HEAD, QG_CHANGES % (QV, DAY) + QG_OLD_HEAD + "\n"),
    ("plugins/spec-distill/CHANGELOG.md", "# Changelog\n\n%s\n" % SD_OLD_HEAD,
     '''# Changelog

## [%s] — %s

### Changed
- 공유 codex 출력 변환기(`codex_findings_to_yaml.py` — 이 플러그인에 링크로 실린다)가 기본 칸 묶음 끝에 `plain` 을 더했다(quality-gates 리뷰어의 쉬운 한 문장 칸). spec-distill 이 쓰는 칸 묶음(design · docreview)의 출력은 그대로다.

%s
''' % (SV, DAY, SD_OLD_HEAD)),
]
texts, bad = {}, []
for rel, old, new in EDITS:
    t = texts.get(rel)
    if t is None:
        t = (R / rel).read_text(encoding="utf-8")
    n = t.count(old)
    if n != 1:
        bad.append("STOP %s: 옛 글자가 %d번 있다(기대 1): %r" % (rel, n, old[:90]))
        continue
    texts[rel] = t.replace(old, new)
if bad:
    sys.exit("\n".join(bad))
for rel, t in texts.items():
    (R / rel).write_text(t, encoding="utf-8")
    print("edited", rel)
````

```bash
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_t4_edit.py . 12.2.0 5.1.2 "$(date +%Y-%m-%d)"
python3 -c 'import json,sys; [json.load(open(p,encoding="utf-8")) for p in sys.argv[1:]]' plugins/quality-gates/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-distill/.claude-plugin/plugin.json && echo "json ok"
python3 -c 'import json; a=json.load(open("plugins/quality-gates/.claude-plugin/plugin.json",encoding="utf-8"))["description"]; b=[p for p in json.load(open(".claude-plugin/marketplace.json",encoding="utf-8"))["plugins"] if p["name"]=="quality-gates"][0]["description"]; print("same" if a==b else "DIFF")'
```

기대: `json ok` · `same`(AC10 — 소개 문구 불일치 0).

- [ ] **Step 4: 테스트를 돈다**

```bash
Q=plugins/quality-gates/tests
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh $Q/test_plain_readme.sh $Q/test_readme_state_diagram_complete.sh $Q/test_readme_scope_reconcile.sh $Q/test_gate_era_prose_absent.sh $Q/test_impact_runtime_docs.sh $Q/test_artifact_metadata.sh $Q/test_law2_prose.sh $Q/test_publish_surface_removed.sh $Q/test_publish_gh_two_files.sh $Q/test_guards_coverage_bidirectional.sh $Q/test_runner_adapters.sh $Q/test_e2e_docs.sh $Q/test_one_pipeline_surface.sh \
  shared/tests/test_charter_citations.sh shared/tests/test_plugin_description_parity.sh shared/tests/test_changelog_integrity.sh shared/tests/test_python_floor.sh shared/tests/test_dispatch_name_defined.sh shared/tests/test_invocation_surface.sh shared/tests/test_copy_of_contract.sh plugins/plugin-audit/tests/test_check_staleness.py plugins/plugin-audit/tests/test_check_shape_completeness.py $Q/harness/test_skill_orchestration_behavior.sh
grep -a '^FAIL' /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/logs/test_skill_orchestration_behavior.sh.log
```

기대(드라이런 실측): 앞의 스물둘은 `rc=0`(20/20 · 10 markers · 18 passed · 7/7 · 6/6 · 5/5 · 42/42 · 40/40 · 6/6 · 373/373 · 53/53 · 96/96 · 89/89 · 12/12 · 9/9 · 27/27 · 143/143 · 6/6 · 69/69 · 208/208 · OK · OK). harness 는 FAIL 줄이 선재 하나뿐이다(제목 버전 — R22 — 은 major 만 잰다).

- [ ] **Step 5: 커밋 · 변이**

```bash
git add plugins/quality-gates/README.md plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/.claude-plugin/plugin.json .claude-plugin/marketplace.json shared/tests/test_charter_citations.sh plugins/quality-gates/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/quality-gates/tests/test_plain_readme.sh
git commit -m "docs(qg): README 와 소개 문구를 쉬운 말로, 버전 올림

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat HEAD | tail -1
git ls-files -s plugins/quality-gates/tests/test_plain_readme.sh | cut -c1-6
bash /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/rt.sh plugins/quality-gates/tests/test_publish_surface_removed.sh plugins/quality-gates/tests/test_gate_era_prose_absent.sh shared/tests/test_dispatch_disposition.sh
python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/pr3_mut.py . t4 | tee ~/.claude/sdd-mirror/plain-language-output/pr3/mut-t4.txt
```

기대: `9 files changed` · `100755` · 커밋 뒤 스윕 셋 `rc=0`(40/40 · 7/7 · 19/19) · `BASE-GREEN 3 tests` · `cells=10 red=10 survived=0 skip=0`(AC10 의 변이 「한 쪽 글자 하나 바꾸기 → RED」를 두 JSON 에서 하나씩 — 헌장 락과 같음 락 둘 다로).

- [ ] **Step 6: 최종 스위트 · 대조**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr3/after-d
B=~/.claude/sdd-mirror/plain-language-output/pr3
for x in baseline-d after-d; do sed -E 's/\(lines [0-9]+, [0-9]+ distance [0-9]+ > 160\)/(lines N)/' "$B/$x/failures.txt" | sort > "/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-$x.txt"; done
comm -13 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-baseline-d.txt /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-after-d.txt
comm -23 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-baseline-d.txt /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/fail-after-d.txt
cut -f1 "$B/after-d/summary.tsv" | sort > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/files-after.txt; cut -f1 "$B/baseline-d/summary.tsv" | sort > /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/files-baseline.txt
comm -3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/files-baseline.txt /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3/files-after.txt
```

기대: 두 failure `comm` 모두 빈 출력 · 파일 `comm` 은 after 쪽에만 새 락 넷(`test_plain_field_path.sh` · `test_plain_qg_templates.sh` · `test_plain_readme.sh` · `test_plain_synth_output.sh`). `test_codex_backward_compat.sh` · `test_codex_runner_degrade_contract.sh` 의 줄이 한쪽에만 있으면 단독으로 다시 돌려 통과하는지 본다(흔들림). `test_hook_output_schema.py` 의 줄이 after 에만 있으면 진짜 워크트리 탓이다(복사본에서 통과 — 이 PR 과 무관). 그 밖의 줄이 나오면 새 실패다 — 고친다.

- [ ] **Step 7: /qg · PR**

`/qg branch` 를 돌리고 묻는다: 「`verdict:` 줄이 여전히 하나이고 쉬운 줄과 섞이지 않는가 · `plain:` 이 없는 지적이 버려지는 길이 없는가 · 합성기 표 머리와 SKILL 의 `result.md` 앵커가 같은 글자인가 · 완료 표의 결과 칸이 게시 펜스의 토큰과 맞는가 · e2e 게이트가 Fix-loop 와 같은 선택지 이름을 부르는가 · 리뷰어 지시의 찾는 규칙이 한 글자도 바뀌지 않았는가(persona = 보안 민감)」.

PR 본문(한국어): 첫 줄 한 문장 · 「계획이 정한 것」 R1~R22(R6 폐기 · R9 옮겨 간 표면 · R11 대상 소멸 · 확인 받은 R10 · R12 · R13 · R15~R18 과 R19~R22 의 답) · 문구 고정 테스트 표(Task 1 · 2 · 3 의 Step 2 — 옛 → 새 · 지키는 뜻) · `plain:` 경로 표(형식 · 넘기기 · 합치기 · 그리기 자리) · 변이 결과(`mut-t1..t4.txt` — 109셀) · 「qg v10 차등 계획과의 충돌」 표 · 할 일 하나: 「작은 변경 하나에 `/qg` 를 돌려, 합성기 첫 줄이 상태 문장이고 질문이 한국어인지 봐 주세요」. 맨 끝 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

머지는 사용자가 `! gh pr merge <n> --merge`. 머지 뒤 ⑤ 계획에 「이 PR 이 먼저 머지됐다 — 충돌 표의 셋째 열을 할 것(특히 `test_removed_plan_arg.sh` 의 「Plan file:」 부재 단언)」을 알린다.
