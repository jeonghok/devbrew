---
name: audit-folder-removal
type: design
created_at: 2026-09-28
source_interview: docs/superpowers/interview/2026-09-28-audit-folder-removal-interview.md
next_phase: superpowers:writing-plans
---

# 감사 폴더 제거 · Design

> 지우는 것은 기록을 읽는 코드가 아니라, 아무도 읽지 않는 기록에 매달린 코드의 끈이다.

## Handoff Context

**TL;DR** — `docs/audits/` 와 `docs/archive/audits/` 를 리포에서 없앤다. 폴더에 매달린 활성 의존(plugin-audit 산출
경로 · AC6 기준선 경로 · 존재 단언 · 경로 없는 개념 인용 10곳 · CLAUDE.md `## Audits` 절 · 테스트 속 경로 인용 셋)을
먼저 끊고, 폴더는 맨 마지막에 지운다. 그 길에 **지금 발동 중인** 결함 여섯만 고친다. plugin-audit 은 산출을
`.claude/plugin-audit/<date>-<target>[-N]/` 실행 디렉토리로 옮기고, 리포트를 한 번 읽는 작업 산출물로 규정한다.

**Implicit context** —

(1) 발단: 2026-08-16 weight-reduction 사이클이 이 폴더를 «해결 후 제거»로 정해 두었고, 이번이 그 마무리다.
문제공간은 interview brief(`source_interview`)가 확정했다. 그 brief 의 confirmed 항목(C1~C15 · D7~D22)이 이
설계의 제약이다. **재결정 규약: confirmed 항목은 근거가 있으면 보고한 뒤 재결정할 수 있고, 임의 변경은
금지다.**

(2) 작업 위치: 브랜치 `feature/resolve-audits`, 워크트리
`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/resolve-audits`, base `6f41a6e1`(#180 머지).

(3) brief 가 열어 둔 네 질문(OQ8 · OQ9 · OQ10 · OQ12)과 실행 디렉토리를 만드는 자리는 이 설계의 brainstorming
에서 사용자가 골랐다 — 「결정 기록」 B1~B5.

## 목차

- [Goal](#goal) · [Context / Why](#context--why) · [Goals](#goals) · [Non-goals](#non-goals) ·
  [Constraints](#constraints) · [설계](#설계) · [Acceptance Criteria](#acceptance-criteria) ·
  [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan) ·
  [Rejected Alternatives](#rejected-alternatives) · [알려진 한계](#알려진-한계) · [결정 기록](#결정-기록) ·
  [Metadata](#metadata)

## Goal

두 감사 폴더가 리포에 없고, 그로 인해 새로 깨지는 테스트·플러그인이 0 이며(착수 전 기준선 대비), 폴더가
되살아나면 락이 RED 를 낸다. 그 길에 발동 중인 결함 여섯이 고쳐진다.

## Context / Why

### 1. 폴더에 매달린 끈

측정(2026-09-28, `git grep -nE 'docs/(archive/)?audits' -- plugins shared CLAUDE.md`, CHANGELOG 제외)과 interview
의 RC 확인 줄이 찾은 끈은 이렇다.

- **plugin-audit** — SKILL post-1 의 모든 산출 경로가 `docs/audits/<date>-<target>-audit*` 다(SKILL `:160`·`:167`·
  `:174`·`:189`·`:196`·`:197`). `render-audit-report.py` 는 `--readme` 를 필수로 받아 `docs/audits/README.md`
  인덱스에 항목을 덧붙인다(`:178`·`:186`). `validate-audit-data.py` 의 `validate_artifacts` 는 README 링크와
  CLAUDE.md 의 `docs/audits/` 포인터를 요구한다(`:143`~`:148`). README Law 3 줄이 이 폴더를 compounding 근거로
  든다(`:71`·`:72`). phase 0 의 clean-tree 선결조건은 근거가 「산출물 커밋」이다(`:33`).
- **AC6 기준선** — `tests/fixtures/ac6_build.py:16` 과 `tests/test_ac6_regression.py:7` 이
  `docs/audits/2026-07-15-project-init-audit-data.json` 을 정답지로 읽는다.
- **존재 단언** — `plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh` (5)가 zero-tool-probe
  감사 문서가 **남아 있어야** 한다고 단언한다(`:48`).
- **경로 없는 개념 인용 10곳** — 「감사문서 §3」 식 출처 괄호. `plugins/spec-distill/references/proceed-gate.md`
  `:147`·`:150` · `shared/tests/presence_corpus.sh` `:18`·`:28` · `plugins/spec-distill/tests/test_proceed_gate_adopters.sh`
  `:35`·`:36`·`:187` · `test_brief_review_entry.sh` `:127` · `test_conducting_interview_stage.sh` `:53`·`:835`
  (RC14). 둘레 문장이 메커니즘을 다 말한 뒤 붙은 꼬리표다(RC32 · RC34).
- **경로 인용·표본 셋** — `shared/tests/test_no_new_duplication.sh:247` 주석 · `test_review_hook_removed.py`
  의 HISTORY 정규식(`:110`·`:111`)과 docstring(`:20`·`:21`) · `shared/tests/test_presence_corpus_behavior.sh:95`
  의 합성 표본 `docs/audits/x.md`.
- **CLAUDE.md** `## Audits` 절.

### 2. 발동 중인 결함 여섯

brief §0 「고칠 것」이 실측으로 확인했다(RC1~RC6 · RC19).

1. project-init trunk-based 템플릿 Pattern B 가 `git checkout main` → `git checkout -b release/v1.x` 로 legacy
   release 브랜치를 **현재 main** 에서 자른다(RC3).
2. project-init 4c 매트릭스 S4 의 (i)이 갈라진 CLAUDE.md 를 내용 이관 없이 `@AGENTS.md` 한 줄로 재작성한다.
   바로 아래의 「비-관리 컨텐츠는 모든 state 에서 보존」 불변식과 모순이다(RC2).
3. `plugins/quality-gates/tests/test_cancel_all_fence.sh` 의 인덱스 모드가 100644 다. qg 셸 어댑터는 실행비트로
   테스트를 claim 하므로 `test_runner_adapters.sh` 가 RED 이고, 그것이 `test_codex_backward_compat.sh` 로
   전파된다(RC4 · RC6).
4. `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh:120` 의 양성 대조가 Bash matcher 훅 ≥2 를
   기대한다. qg v7.0.0 이 자기 훅을 의도적으로 지운 뒤로 1개(project-init)다. 락(08-27)이 훅 제거(09-04)보다
   먼저 생겼다 — 틀린 쪽은 테스트다(RC5).
5. `plugins/quality-gates/tests/test_no_secret_prompts.py:24` 의 P21 스캔 glob 이 `skills/*/references/*.md` 만
   본다. 플러그인 레벨 `references/`(`recritic-code-profile.md` · `docreview-profiles/`)는 스캔 밖이다. 지금 새는
   위반은 0 이다(RC1).
6. framing-requests 는 `## degrade 채널` 절을 갖지만, 그 절의 채널 **이름**이 사라지면 RED 를 내는 락이 없다.
   reviewing-spec 은 `test_reviewing_spec_disclosure.sh` (2)가, reviewing-brief 는 자기 락이 잰다(RC19).
   `test_proceed_gate_adopters.sh` 는 「degrade 채널」이라는 라벨의 존재만 잰다.

### 3. plugin-audit 의 산출이 커밋 자리를 잃으면

산출을 git-ignored 자리로 옮기면 Law 3 근거(커밋 + 인덱스)가 사라진다(RC12). 사용자 리포에서는 `.claude/` 가
ignore 된다는 보장도 없다 — devbrew 의 `.gitignore:214`~`:220` 에서만 참이다(RC31). `run-own-tests.sh` 는
필수 인자 `<session-id>` 를 받는데(`:14`·`:15`), SKILL 은 그 값의 출처를 정하지 않는다(RC25). 그 값의 소비자
`qg-worktree.sh create-sandbox` 는 그것을 sanitize(`[A-Za-z0-9._-]`, 64자 이하)해 sandbox 이름에만 쓴다(`:48`~`:56`).
`assemble-audit-data.py` 는 출력 디렉토리를 만들지 않는다(RC17). SKILL 은 중간 파일(consent · BEFORE/AFTER
스냅샷 · `wf.json` · `codex.json` · `meta.json`)의 자리를 정하지 않는다.

## Goals

- G1 — 두 폴더가 없고, 부재 락이 폴더 부활을 RED 로 잡는다(C1 · D9 · D16).
- G2 — 착수 전 기준선 대비 새 실패가 0 이다. 실패 항목의 식별자·내용으로 대조한다(D11 · D17).
- G3 — 결함 여섯이 고쳐지고, 그것으로 RED 였던 테스트(`test_runner_adapters.sh` · `test_codex_backward_compat.sh`
  · `test_no_write_matcher_hooks_repo.sh`)가 GREEN 이 된다.
- G4 — plugin-audit 이 실행 디렉토리에서 post-1 을 끝까지 돈다. 디렉토리는 스스로 git-ignore 되고, P21 스캔은
  유지된다(D10 · D13 · D20).

## Non-goals

- 감사 backlog 청산. 대상·인스턴스가 0 인 잠재 항목은 문서와 함께 버린다(C15 · D8).
- 재사용 지식을 issue · memory · 코드 옆으로 옮기는 것. git 이력이 유일한 보존처다(C3).
- CHANGELOG · `docs/superpowers/` 역사 기록 속 경로 수정(C6).
- 범위 밖 3건의 수정 — qg harness 선재 FAIL 2 · qg 밖 100644 테스트 스크립트 17 · 감사 문서 §7-7(D14).
  「알려진 한계」 L5 에 이유와 함께 적는다.
- 진짜 plugin-audit 감사 한 번(약 30 dispatch)의 실행. G4 는 결정론 구간으로 검증한다.
- `run-own-tests.sh` 의 알려진 보안 한계(프로세스·네트워크 격리 없음)의 해소.

## Constraints

brief §2 의 confirmed 항목 전부다. 이 설계가 특히 기대는 것:

- C4 · D22 — 검사기의 README 링크·CLAUDE.md 포인터 요구를 없애고, 그것을 재던 테스트 3개
  (`test_validate_audit_data.py:301`~`:323`)의 락 순감을 수용한다.
- C5 — AC6 기준선 json 은 `plugins/plugin-audit/tests/fixtures/` 로 옮겨 회귀 테스트를 유지한다.
- D12 — 개념 인용은 괄호만 지우고 둘레 문장은 남긴다. 공유 계약에 §8·§9 번호 인용을 새로 들이지 않는다.
- D13 — 폴더 존재를 잰다 · 경로 이동으로 공허해지는 락은 새 경로로 재앵커한다 · journal P21 스캔을 유지한다 ·
  마무리에서 auto-memory 포인터를 갱신한다.
- D16 — 부재 락은 두 폴더 부재 단언 한 줄이다. 참조 스캔·면제 설계는 두지 않는다.
- 리포 규약 — 플러그인을 건드리는 PR 은 그 플러그인의 `plugin.json` 을 bump 한다. 번호는 머지 직전에 정한다.

## 설계

### §1 구조 — 한 PR, 세 커밋 덩어리 (B4)

1. **끈 끊기 + 폴더 제거** — §2 · §3.
2. **project-init 결함 둘** — §4 의 1 · 2.
3. **테스트·락 넷** — §4 의 3~6.

덩어리 1 안에서 폴더 `git rm` 은 **마지막** 커밋이다. 끈을 다 끊은 뒤에 지워야, 기준선 대조에서 새 실패가
나왔을 때 원인이 「끈이 남았다」인지 「삭제 자체」인지 갈린다.

### §2 plugin-audit — 실행 디렉토리

**새 스크립트 `plugins/plugin-audit/scripts/prepare-run-dir.py`** (B5). phase 0 의 target 검증 직후 한 번 부른다.

- 입력: `<target>`, `--repo-root`(기본 `.`), `--date`(기본 오늘의 로컬 날짜 `YYYY-MM-DD` — 테스트 주입용).
- target 형식 검사: `[A-Za-z0-9._-]+` 이고 `..` 을 포함하지 않으며 `.` 으로 시작하지 않는다. 어기면 rc 2.
- 키: `<date>-<target>`. `<repo-root>/.claude/plugin-audit/<key>/` 를 **원자적으로** 만든다(`os.mkdir`, 이미 있으면
  `-2`, `-3` … 을 붙여 재시도). 기존 디렉토리를 덮거나 비우지 않는다(D10). 최종 키가 64자를 넘으면 rc 2 —
  `qg-worktree.sh` sanitize 의 상한이다.
- 만든 디렉토리 안에 `*` 한 줄짜리 `.gitignore` 를 쓴다(B3).
- stdout 한 줄: 디렉토리의 절대경로. 이후 모든 단계는 이것을 `$RUN_DIR` 로, 그 basename 을 실행 키로 쓴다.

**SKILL(`skills/auditing-plugins/SKILL.md`) 변경**

- phase 0 의 clean-tree 선결조건을 지운다 — 근거가 산출물 커밋이었다.
- phase 0 에 `prepare-run-dir.py` 호출을 넣는다(target 검증 뒤, 지출 동의 게이트 앞). consent 아티팩트부터 모든
  중간 파일을 `$RUN_DIR` 에 둔다.
- `run-own-tests.sh plugins/<target> <실행 키>` — sandbox 이름의 출처가 실행 키다(B2).
- post-1 의 산출 경로: `$RUN_DIR/audit-data.json` · `$RUN_DIR/audit.md` · `$RUN_DIR/audit-journal.jsonl`.
  디렉토리 이름이 날짜와 대상을 이미 담으므로 파일 이름에 반복하지 않는다.
- step 1 의 P21 secret 스캔은 그대로 둔다. 근거 문장을 「커밋 디렉토리」에서 「리포트는 사람이 복사·공유하는
  산출물이다」로 바꾼다(RC26).
- step 4 의 `--readme` 를 지운다. step 6 의 discoverability(README 인덱스 · CLAUDE.md 포인터)를 **종료 보고**로
  바꾼다 — 리포트 · data.json · journal 의 절대경로를 사용자에게 보인다(D10).
- step 7 의 `--artifacts "$RUN_DIR/audit-data.json" --report "$RUN_DIR/audit.md"`.

**스크립트 변경**

- `render-audit-report.py` — `--readme` 인자와 인덱스 쓰기 블록(`:178`·`:186`~`:193`)을 지운다.
- `validate-audit-data.py` — `validate_artifacts` 에서 README · CLAUDE.md 검사(`:143`~`:148`)를 지운다. 배너 검사
  (AC-3)는 남긴다.

**README** — Law 3 줄(`:71`·`:72`)을 「리포트는 한 번 읽는 작업 산출물이다(`.claude/plugin-audit/<실행 키>/`,
스스로 git-ignore). 이 사이클의 compounding 은 감사가 낳은 수정 커밋과 reviewer persona 편집이 맡는다」로 바꾼다
(B1). 사용법 절에 산출 위치를 적는다.

### §3 폴더 제거와 참조 정리

순서대로 한다.

1. **AC6 기준선 이동** — `git mv docs/audits/2026-07-15-project-init-audit-data.json
   plugins/plugin-audit/tests/fixtures/ac6_baseline.json`. `ac6_build.py:4`·`:16` 과 `test_ac6_regression.py:7`
   을 새 경로로 바꾼다. 옮긴 뒤 `test_review_hook_removed.py` 를 돌린다. 그 파일이 역사 면제를 잃고 스캔
   코퍼스에 들어오기 때문이다(RC28). RED 면 fixture 경로를 HISTORY 에 더하고 **이유를 그 파일 docstring 에
   적는다** — 그 파일 스스로의 규칙이다.
2. **개념 인용 10곳** — 출처 괄호만 지운다(D12). 괄호가 문장 끝 「(… 참조)」 같은 독립 구절이면 그 구절째 지운다.
   둘레 문장의 단어는 바꾸지 않는다. 가리키던 절의 번호를 다른 문서 번호로 바꿔 넣지 않는다.
3. **경로 인용·표본 셋**
   - `test_no_new_duplication.sh:247` — 경로·절 인용을 지우고 「코퍼스가 줄어도 락은 GREEN」 개념 문장만 남긴다.
   - `test_review_hook_removed.py` — HISTORY 정규식에서 `^docs/audits/README\.md$` 와 `^docs/audits/\d{4}-…`
     대안을, docstring (a)에서 두 항목을 지운다. `^docs/archive/` 는 유지한다(interview · plans · specs 가 남는다).
   - `test_presence_corpus_behavior.sh:95` — 합성 표본을 `docs/x.md` 로 바꾼다. 「plugins/ 밖 경로」라는 뜻은 같다.
4. **존재 단언 뒤집기** — `test_brief_review_no_external_precondition.sh` (5)를 두 폴더 부재 단언 한 줄로 바꾼다
   (D9 · D16). 대상은 작업 트리의 존재다 — 추적 여부와 무관하게 폴더가 있으면 RED 다(D13 「폴더 존재를 잰다」).
   파일 머리 주석의 (5) 설명도 함께 바꾼다.
5. **CLAUDE.md** `## Audits` 절을 지운다(C2).
6. **`git rm -r docs/audits docs/archive/audits`.**
7. **1회 점검** — 위 `git grep` 을 다시 돌려 남은 줄이 부재 락 파일 자신과 역사 기록뿐인지 확인하고 결과를 PR
   본문에 싣는다. 영구 락이 아니다(D16).

### §4 결함 여섯

1. **Pattern B** — `plugins/project-init/templates/trunk-based/branch-strategy.md` 의 step 1 을 태그 기준으로
   바꾼다: `git fetch --tags` → `git checkout -b release/v1.x <마지막 v1 태그>`(예: `v1.2.4`). 주석으로 「현재
   main 은 이미 다음 major 라 v1 을 고칠 수 없다」를 한 줄 남긴다.
2. **S4(i)** — `plugins/project-init/commands/project-init.md` 4c 표 S4 행의 (i)을 「CLAUDE.md 가 존재하면 관리 섹션
   (`## Git Workflow`)을 뺀 비-관리 컨텐츠를 AGENTS.md 끝에 이전한 뒤 CLAUDE.md 를 `@AGENTS.md` 한 줄로 교체」로
   바꾼다. 원본 파일명을 지칭하는 H1(`# CLAUDE.md`)은 이전하지 않는다 — S2a (d) 와 같은 근거(이전 후 대상을
   잘못 가리킨다)다.
   advisory 문구가 이전될 내용이 있다는 것을 밝힌다. CLAUDE.md 가 없으면 기존대로 포인터만 쓴다.
3. **실행비트** — `git update-index --chmod=+x plugins/quality-gates/tests/test_cancel_all_fence.sh`. 워킹트리
   `chmod` 는 인덱스에 실리지 않는다.
4. **matcher 기대** — `test_no_write_matcher_hooks_repo.sh:120` 의 임계를 `-ge 1` 로 내리고, 주석에 「qg v7.0.0 이
   Bash matcher 훅을 의도적으로 지웠다 — 이 대조의 목적은 grep 이 작동한다는 양성 증인이라 1 로 충분하다」를
   적는다.
5. **P21 glob** — `test_no_secret_prompts.py` 에 플러그인 레벨 `references/**/*.md` 코퍼스를 더한다. 하한은
   **glob 마다 따로** 둔다(각 ≥1). 합계 하나로는 새 glob 이 0건이 돼도 기존 glob 이 채워 통과한다.
6. **framing-requests 채널 이름 락** — `test_framing_review_contract.sh` 에 한 절을 더한다. framing-requests
   SKILL 의 `## degrade 채널` 절을 잘라 내 채널 이름 다섯(`advisory[]` · `blocks` · `gate --render` ·
   `framing_degradations` · 게이트 질문 텍스트)이 모두 있는지 잰다. 절 추출이 비면 RED 다.
   모양은 `test_reviewing_spec_disclosure.sh` (2)를 따른다.

### §5 버전

한 번씩 bump 한다: plugin-audit minor(산출 경로 · render CLI 변경), spec-distill · quality-gates · project-init
patch. CHANGELOG 가 있는 플러그인은 항목을 쓴다. 번호는 머지 직전에 정한다.

## Acceptance Criteria

변이 = 그 AC 의 락이 이빨을 갖는지 보는 일부러 망가뜨리기. 변이 뒤 RED 를 확인하고 되돌린다(커밋 뒤에 한다).

- **AC1** `git ls-files docs/audits docs/archive/audits` 가 0줄이고 두 디렉토리가 작업 트리에 없다. 부재 락이
  GREEN 이다. *변이*: `mkdir -p docs/audits && touch docs/audits/x.md` → 부재 락 RED. `docs/archive/audits` 도
  따로 한 번.
- **AC2** 착수 전 기준선과 비교해 **새 실패 항목이 0** 이다(실패 테스트의 식별자·메시지로 대조, 파일별 rc 와
  실패 줄 수는 보조). 사라진 테스트는 C4 의 3개뿐이고 「의도적 삭제」로 표시된다.
- **AC3** `test_runner_adapters.sh` · `test_codex_backward_compat.sh` · `test_no_write_matcher_hooks_repo.sh` 가
  GREEN 이다.
- **AC4** `prepare-run-dir.py` 단위 테스트 — ① 첫 호출이 `<root>/.claude/plugin-audit/<date>-<target>/` 를 만들고
  그 절대경로를 출력한다 ② 두 번째 호출이 `-2` 를 만들고 첫 디렉토리의 내용을 건드리지 않는다 ③ `.gitignore`
  내용이 `*` 한 줄이다 ④ `../x` · `a/b` · `.x` · 65자 이상 키가 rc 2 다.
  *변이*: `.gitignore` 쓰기를 지우면 ③ RED, 재시도 루프를 `exist_ok=True` 로 바꾸면 ② RED.
- **AC5** 결정론 끝-끝: 임시 git 리포에서 `prepare-run-dir.py` → `assemble-audit-data.py`(AC6 fixture 입력,
  `--out "$RUN_DIR/audit-data.json"`) → `validate-audit-data.py --data` → `render-audit-report.py --out
  "$RUN_DIR/audit.md"` → `validate-audit-data.py --artifacts … --report …` 가 전부 rc 0 이고, 끝난 뒤
  `git status --porcelain` 이 빈 출력이다.
- **AC6** `render-audit-report.py` 에 `--readme` 가 없고 인덱스 파일을 쓰지 않는다. `validate_artifacts` 가 README
  · CLAUDE.md 를 읽지 않고 배너 검사는 유지한다(기존 배너 테스트 GREEN).
- **AC7** plugin-audit SKILL · README 에 `docs/audits` 문자열이 0건이다. SKILL 의 산출 경로가 `$RUN_DIR/` 로
  시작하고, journal P21 스캔 단계가 남아 있으며, `run-own-tests.sh` 의 둘째 인자가 실행 키다.
  `test_skill_orchestration.py` 가 새 경로로 재앵커돼 GREEN 이다. *변이*: SKILL 에서 journal 확보 단계를 assemble
  뒤로 옮기면 RED, `--artifacts "$RUN_DIR"` 처럼 디렉토리를 넘기는 형태를 넣으면 bare-directory 회귀 락 RED.
- **AC8** AC6 기준선이 `plugins/plugin-audit/tests/fixtures/` 에 있고 `test_ac6_regression.py` 가 GREEN 이다.
  `test_review_hook_removed.py` 가 GREEN 이다(면제를 더했다면 docstring 에 이유가 있다).
- **AC9** 개념 인용 10곳의 출처 괄호가 사라지고 둘레 문장은 그대로다. `proceed-gate.md` 에 §8 · §9 번호 인용이
  새로 생기지 않는다. 그 파일들을 재는 기존 락(V11 스캔 포함)이 GREEN 이다.
- **AC10** CLAUDE.md 에 `## Audits` 절이 없다. §3-7 의 1회 점검 결과가 PR 본문에 있다.
- **AC11** Pattern B 의 코드 블록에서 `checkout -b release/` 가 태그 인자를 받고, 바로 앞에 `git checkout main`
  이 없다.
- **AC12** S4 (i) 문구가 비-관리 컨텐츠의 이전을 말하고, 4c 의 보존 불변식과 모순되는 문장이 없다.
- **AC13** `git ls-files -s plugins/quality-gates/tests/test_cancel_all_fence.sh` 의 모드가 100755 다.
- **AC14** matcher 대조가 GREEN 이다. *변이*: project-init `hooks.json` 의 `"matcher": "Bash"` 를 다른 값으로
  바꾸면 RED.
- **AC15** P21 스캔 코퍼스에 플러그인 레벨 references 가 들어가고 glob 별 하한이 있다. *변이*: ① 새 glob 을
  오타로 깨면 RED(기존 glob 이 채워 주지 않는다) ② `references/recritic-code-profile.md` 에 누출 패턴 한 줄을
  넣으면 RED.
- **AC16** framing-requests 채널 이름 락이 GREEN 이다. *변이*: 절에서 `framing_degradations` 를 지우면 RED,
  `## degrade 채널` 헤딩 이름을 바꾸면 RED.
- **AC17** 건드린 네 플러그인의 `plugin.json` version 이 올라가 있다.
- **AC18**(마무리, 리포 밖) auto-memory 에서 `docs/audits` 를 가리키는 줄이 삭제·수정돼, 현존 파일을 가리키지
  않는 포인터가 0 이다.

## Files to Modify

- 새로: `plugins/plugin-audit/scripts/prepare-run-dir.py` · `plugins/plugin-audit/tests/test_prepare_run_dir.py`
  · AC5 끝-끝 테스트(기존 테스트 파일에 둘지 새 파일로 둘지는 계획이 정한다).
- plugin-audit: `skills/auditing-plugins/SKILL.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` ·
  `scripts/render-audit-report.py` · `scripts/validate-audit-data.py` · `tests/fixtures/ac6_build.py` ·
  `tests/test_ac6_regression.py` · `tests/test_render_audit_report.py` · `tests/test_validate_audit_data.py` ·
  `tests/test_skill_orchestration.py` · `tests/fixtures/ac6_baseline.json`(이동).
- spec-distill: `references/proceed-gate.md` · `tests/test_proceed_gate_adopters.sh` · `tests/test_brief_review_entry.sh`
  · `tests/test_conducting_interview_stage.sh` · `tests/test_review_hook_removed.py` ·
  `tests/test_brief_review_no_external_precondition.sh` · `tests/test_no_write_matcher_hooks_repo.sh` ·
  `tests/test_framing_review_contract.sh` · `.claude-plugin/plugin.json` · `CHANGELOG.md`.
- quality-gates: `tests/test_cancel_all_fence.sh`(모드) · `tests/test_no_secret_prompts.py` ·
  `.claude-plugin/plugin.json` · `CHANGELOG.md`.
- project-init: `templates/trunk-based/branch-strategy.md` · `commands/project-init.md` ·
  `.claude-plugin/plugin.json` · `CHANGELOG.md`.
- shared: `tests/presence_corpus.sh` · `tests/test_no_new_duplication.sh` · `tests/test_presence_corpus_behavior.sh`.
- 루트: `CLAUDE.md`. 삭제: `docs/audits/**` · `docs/archive/audits/**`.

## Verification Plan

1. **기준선** — 첫 편집 전에 전 스위트(플러그인별 python `-m unittest` · 셸 테스트는 리포 루트에서 · node 테스트는
   `--test-reporter=tap`)를 돌려 실패 항목의 식별자·메시지를 파일로 남긴다. 파일별 rc 와 실패 줄 수를 보조로
   적는다. qg harness 선재 FAIL 2 도 이번에 잰다. 못 재면 「미측정」과 그 이유를 적는다.
2. **덩어리마다** 그 덩어리가 닿은 소비자의 테스트를 돌린다.
3. **최종** — 같은 스위트를 다시 돌려 AC2 의 대조를 한다. AC3 의 셋이 RED→GREEN 인지 본다.
4. **변이** — AC 의 *변이* 항목을 전부 돌린다. 경로를 옮긴 락(AC7 · AC8)과 새 락(AC4 · AC15 · AC16)이 대상이다.
5. **AC5 끝-끝**과 **§3-7 1회 점검**.
6. **마무리** — 머지 직전에 version 번호를 정하고, auto-memory 포인터를 갱신한다(AC18).

## Rejected Alternatives

- **실행 디렉토리를 SKILL 펜스에서 인라인으로 만든다** — `-N` 충돌 처리와 `.gitignore` 쓰기가 테스트 밖에 남는다(B5).
- **`assemble-audit-data.py` 가 출력 디렉토리를 만든다** — 실행 키는 pre-1 의 `run-own-tests.sh` 에서 이미 필요하다.
  조립은 그보다 늦다(B5).
- **같은 날 재감사는 덮어쓴다** — 이전 리포트를 잃는다. D10(자동 삭제 없음)과 긴장한다(B2).
- **키에 시각을 넣는다(`<date>T<HHMMSS>-<target>`)** — 충돌은 없지만 D20 의 모양을 재결정해야 한다(B2).
- **감사 끝에 갭 목록을 커밋 위치로 넘기는 단계(OQ8 (나))** — SKILL 단계와 테스트가 늘고, 커밋 위치가 매번 달라
  다음 세션의 발견성은 여전히 보장되지 않는다(B1).
- **사용자 리포의 ignore 를 devbrew 한정 전제로 공시만 한다** — 커밋될 수 있고, journal 은 P21 스캔 뒤에도
  transcript 라 민감하다(B3).
- **PR 을 둘 또는 셋으로 나눈다** — bump · 기준선 대조 · base 따라잡기가 PR 수만큼 반복된다(B4).
- **부재 락을 활성 표면 참조 스캔으로** — goal 대비 과하다. 리뷰 라운드 1 에서 사용자가 줄였다(D16).
- **개념 인용이 가리키던 감사 문서 절을 인용 파일 곁으로 흡수** — 인용 10곳이 모두 자기완결이라 중복과
  Self-narrating artifact 를 키운다(ST1, kept).
- **잠재 항목을 함께 고친다** — 대상·인스턴스가 0 이다(C15 · D8).

## 알려진 한계

- **L1** 부재 락은 폴더 부활(다른 브랜치 병합 · 옛 plugin-audit 캐시의 재기록)을 잡는다. 활성 코드에 `docs/audits`
  경로 문자열이 다시 들어오는 것은 잡지 못한다 — 관측되면 참조 스캔으로 올린다(D16).
- **L2** git 이력만 보존처라서 삭제된 감사 문서는 `git grep` 으로 보이지 않는다. pickaxe(`git log -S`)로만 찾는다.
- **L3** plugin-audit 리포트는 ephemeral 이다. 감사 뒤 아무것도 고치지 않으면 그 감사로 배운 것은 남지 않는다(B1).
- **L4** 설치 캐시의 옛 plugin-audit 은 사용자가 갱신하기 전까지 옛 경로로 쓰거나 README · CLAUDE.md 요구로 RED 를
  낸다 — version bump 로 새 사본이 서빙되게 할 뿐, 갱신을 강제하지 않는다.
- **L5** 범위 밖 3건(D14) — qg harness 선재 FAIL 2(감사 폴더와 무관한 RED) · qg 밖 100644 테스트 스크립트 17
  (인덱스 모드 락이 qg 에만 있어 지금 claim 실패가 없다 — 잠재) · 감사 문서 §7-7(요약·정본 정합 검사의 부재 —
  기존 검사의 빈 정의역이 아니고 요약은 지금 정합하다).
- **L6** `run-own-tests.sh` 의 알려진 CRITICAL(샌드박스에 프로세스·네트워크 격리 없음)은 그대로다.

## 결정 기록

brief 의 confirmed 결정(C1~C15 · D7~D22)은 brief 가 정본이다. 아래는 이 설계의 brainstorming 에서 사용자가 고른
것이다(2026-09-28).

- **B1 — OQ8: (가) ephemeral 공시.** README Law 3 줄을 바꾸고 새 단계는 두지 않는다. 기각: (나) 갭 목록 인계 단계 ·
  (가)+종료 안내 한 줄.
- **B2 — OQ9: 실행 키 `<date>-<target>[-N]`.** 충돌이면 `-N` 으로 새로 만든다. 같은 키가 sandbox 이름이고, 중간
  파일도 그 디렉토리에 둔다. 종료 보고에 산출 경로를 적는다. 기각: 같은 날 덮어쓰기 · 시각 포함 키.
- **B3 — OQ12: 자기-ignore `.gitignore`.** 실행 디렉토리 안에 `*` 한 줄. 기각: devbrew 한정 전제 공시 · 둘 다.
- **B4 — OQ10: 한 PR, 커밋은 덩어리별.** plugin-audit minor, 나머지 patch, 번호는 머지 직전. 기각: 두 PR · 세 PR.
- **B5 — 실행 디렉토리는 새 스크립트 `prepare-run-dir.py` 가 만든다.** 기각: SKILL 인라인 펜스 · assemble 이 생성.

## Metadata

- 관련: interview brief `docs/superpowers/interview/2026-09-28-audit-folder-removal-interview.md`(+ `.audit.md`) ·
  seed `docs/superpowers/interview/2026-09-28-resolve-audits-interview.md` · base `6f41a6e1`(#180).
- 영향 플러그인: plugin-audit · spec-distill · quality-gates · project-init. shared 테스트 셋. 루트 CLAUDE.md.

### Deferred to plan

1. AC5 끝-끝 테스트의 자리(`test_assemble_audit_data.py` 확장 또는 새 파일)와 assemble 의 입력 fixture 조합.
2. project-init 템플릿·command 문구를 재는 기존 락 전수 — Pattern B · S4 문구를 리터럴로 기대하는 자리를 리포
   전체에서 grep 해 함께 갱신한다.
3. `test_skill_orchestration.py` 의 재앵커 문자열 확정(SKILL 문구가 정해진 뒤).
4. 기준선 스위트의 실행 명령 목록 — 셸 테스트의 실행비트 여부와 무관하게 `bash <경로>` 로 돌릴 대상 전수.
