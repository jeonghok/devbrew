# 앞단 다시 짜기 — 계획 3 (글 줄이기) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 가른 뒤의 앞단 글(의도 싱크 본문 · 컨텍스트 쌓기 본문과 끝맺음 절차 · 로드맵 잡기의 글)에서 낡은 서술 · 풀 수 없는 옛 설계 번호 · 지시를 받치지 않는 이유 설명을 걷어내고, 이유 문장 안에만 있던 지시는 지시 문장으로 남기며, 설계 5 표에서 계획 칸이 3 인 「한다」 행을 글로 처리한다 — 코드 블록 안의 글자는 바꾸지 않는다.

**Architecture:** 첫 과제가 다시 확인하고 앞 수(파일마다 줄 수 · 낡은 서술 · 풀 수 없는 번호 · 이유 설명)를 잰다. 그 뒤 파일 묶음마다 한 과제씩 — 락을 먼저 쓰고(새 락 `test_stage_prose_trim.sh` 에 자기 묶음의 절을 더한다) 글을 고친 뒤, 커밋 앞뒤의 펜스를 뽑아 견준다. 끝 과제가 뒤 수를 재고 AC37 의 읽는 양을 견준다. 재는 도구 셋(펜스 대조 · 번호 세기 · 이유 원장)은 git 이 무시하는 자리에 두고, 영구히 남는 것은 락 하나와 그 문장을 무는 기존 테스트의 고침뿐이다.

**Tech Stack:** 마크다운(skill 글 · reference · 템플릿 · README · 철학 문서) · bash 3.2 호환 셸 테스트 · Python 3 표준 라이브러리(테스트 안의 스캐너 · 무시되는 자리의 재는 도구) · git.

**Spec:** `docs/superpowers/specs/2026-11-20-front-stage-restructure-design.md` — 실행자는 이 계획과 설계문서를 함께 읽는다(`### 4. 글 줄이기` · `### 5. 넘겨받은 것의 처분` 의 계획 칸 3 행 · `## Acceptance Criteria` 의 계획 3 절과 AC37 · `## 미룸` · `## 판정` · `## 결정 기록`). 설계문서 끝 `### Deferred to plan` 표는 본문에 이미 반영돼 있다 — 그 표의 「고치면」 을 과제로 삼지 않는다. 앞 계획은 `docs/superpowers/plans/2026-11-20-front-stage-restructure-plan1.md` · `…-plan2.md` 다.

## Global Constraints

- **실행 시점.** 이 계획은 계획 2 가 에픽 브랜치에 머지된 뒤의 나무에서 돈다. 과제 1 이 계획 2 의 산출물(`plugins/spec-distill/scripts/legacy_names.py` · `plugins/spec-distill/tests/test_legacy_literals.sh`)이 없으면 멈춘다.
- **코드 블록 밖의 글만 바꾼다(AC32).** ``` · ~~~ 펜스 안의 글자는 바꾸지 않는다. 이 계획이 고치기로 한 펜스는 하나뿐이다 — `skills/context-build/SKILL.md` 의 상태 파일 스키마 펜스(`coverage:` 줄의 주석 `# G1 커버리지 원장`)에서 옛 번호 `G1` 을 지우는 것(AC30 이 앞단 글 전부에서 옛 번호를 없애라고 하는데 그 하나가 펜스 안에 있다). 허용 목록 파일 `.claude/tmp/f5-plan3/fence-allow.tsv` 에 그 한 줄만 둔다. 다른 펜스를 고쳐야 할 자리가 나오면 고치지 말고 멈춰 보고한다. 과제마다 커밋 앞뒤의 펜스를 `fence_diff.py` 로 견준다(과제 1 이 만든다). 펜스를 뽑아 돌리는 기존 테스트(`cut_marked` · `<!-- …:begin -->` 표지로 펜스를 떼는 부분)는 고치지 않는다 — 고치지 않은 채 통과해야 한다.
- **줄 수 목표는 두지 않는다(AC28 · AC37).** 이유 · 이력 설명 갈래의 뒤 수가 앞 수보다 작아야 하고, 남긴 자리는 까닭(범위를 정하는 이유 · 지시를 담은 이유 등)과 함께 PR 본문에 적는다. 각 단계가 읽는 글은 가르기 전 기준을 넘지 않는다(`plugins/spec-distill/tests/test_stage_read_budget.sh` — 의도 싱크 본문 1523 · 컨텍스트 쌓기 본문 + 끝맺음 절차 1587 · 로드맵 잡기 파일 전부 1587. 이 테스트는 고치지 않는다).
- **줄 수 상한 둘.** `skills/intent-sync/SKILL.md` 는 지금 AC37 기준과 같은 1523 줄이다 — 한 줄이라도 늘면 `test_stage_read_budget.sh` 가 실패한다. 더하는 글은 있는 줄에 잇거나 같은 커밋에서 그보다 많이 걷는다. `skills/context-build/SKILL.md` 의 자기 줄 수(쉬운 말 규칙 블록 뺀 줄)는 600 이고 상한은 604 미만이다(`test_conducting_interview_stage.sh` 의 `SKILL_LINE_CAP=604`). 같은 규칙이다.
- **옛 번호 글자(AC30 — 락과 재는 도구가 같은 정규식을 쓴다).** 금지: `C43` · `C4` · `C5` · `C8` · `G1` · `G2` · `N1a` · `N1b` · `N2` · `NG4` · `NG7` · `AC<수>` · `D6` · `OQ6` · `R2a`(앞뒤가 영숫자 · `_` · `.` · `/` · `-` 가 아닌 낱 글자), 옛 판 번호(`v?<수>.<수>.<수>`), 날짜 실측 표기(`20YY-MM-DD`). 남기는 것: 철학 번호(P · AP · Law)와 결과물의 살아 있는 번호(`S<n>` · `K<n>` · `OQ<n>` 꼴의 열린 질문 번호 · `RC<n>` · `ST<n>` · 라운드 `R<n>` · 의례 `R1`–`R5` · 확정 항목 보기의 `C1` · `C2` · `D5` · 에픽 번호 보기 `R0` · `R1` · `P1`). 범위(번호 코퍼스)는 설계 4 가 든 파일이다 — `skills/intent-sync/SKILL.md` · `skills/context-build/SKILL.md` · `skills/context-build/references/finishing.md` · `skills/roadmap-draft/` 아래 추적 파일. 컨텍스트 쌓기의 다른 reference(`state-file.md` 의 `B9` · `F3`, `steelman.md` 의 `C2` · `C4`, `state-migration.md` 의 `v0.22.0`)와 agent 정의(`agents/coverage-mapper.md` 의 `G2`)는 범위 밖이다 — 고치지 않고 PR 본문의 「범위 밖으로 남긴 자리」 에 적는다(agent 정의는 계획 4 의 보안 리뷰 묶음이다).
- **지시를 살린다(AC31 · 설계 Anti-goals).** 문장을 걷기 전에 그 문장 안에 「…한다 · …않는다 · …마라」 꼴의 지시가 있는지 본다. 있으면 지시 문장으로 다시 쓰고, 이유가 규칙의 범위를 정하면(「플러그인 캐시는 프로젝트 밖이라 내용을 싣는다」 처럼 이유가 없으면 두 규칙이 모순으로 읽히는 곳) 이유를 한 구절로 남긴다. 행동을 내는 문장 · 쉬운 말 규칙 블록(`<!-- plain-language:begin -->` ~ `end`)은 건드리지 않는다.
- **낱말.** 새로 쓰는 글은 계획 1 · 2 의 낱말 대응을 따른다 — 단계는 「컨텍스트 쌓기」 · 「로드맵 잡기」 · 「의도 싱크」, 폴더는 「의도 폴더」, 영어는 `context brief`. 「인터뷰」 는 「옛 인터뷰 기록」 처럼 옛 기록을 가리킬 때만 쓴다(`test_stage_words.sh` 가 문다). 계획 2 의 새 글자(`intent_dir` · `source_intent` · `context-state:` · `-context.md` 등)를 쓰고 옛 글자를 새로 들이지 않는다.
- **편집 자리 찾기.** 기본 브랜치와 에픽 브랜치는 이 계획을 쓴 뒤에도 움직였다(계획 2 의 머지). 과제의 편집 자리는 줄 번호가 아니라 그때 grep 해서 찾는 글자로 적었다. 계획 2 가 바꿨을 글자(`interview_dir` → `intent_dir` · `type: interview-seed` → `type: intent-seed` · `-interview.md` → `-context.md` · `source_interview` → `source_intent` · `interview-state:` → `context-state:`)는 grep 글자로 쓰지 않거나 두 꼴을 함께 적었다.
- **판.** spec-distill 을 「머지 직전 기본 브랜치 위의 다음 patch 번호」 로 한 번 올린다(글만 바꾼다 — 새 표면이 없다). quality-gates 의 추적 파일(테스트 포함)을 고치면 quality-gates 도 다음 patch 로 올린다(설계문서 지휘 기록 「quality-gates 판」 의 선례 — 테스트만 바뀌어도 올렸다). 숫자는 박지 않는다 — 같은 판으로 올린 `plugin.json` 은 조용히 합쳐지므로 머지 직전에 `git diff origin/<기본 브랜치> -- plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/.claude-plugin/plugin.json` 으로 견준다. 변경 기록 머리 날짜도 그때 정한다.
- **이 계획 몫이 아닌 것.** 리뷰어 프로필(`references/docreview-profiles/*.md`)과 agent 정의(`plugins/*/agents/*.md` · `shared/docreview/agents/*.md`)는 고치지 않는다 — 계획 4 의 보안 리뷰 묶음이다. 이 계획이 그 파일에 손대야 하는 자리가 나오면 고치지 말고 보고한다. 스크립트의 동작 · 리뷰 기준 · agent 정의를 바꾸는 수리(설계 5 의 계획 칸 4)도 하지 않는다. 템플릿은 글을 더하거나 그 템플릿의 낡은 서술을 고치는 것만 한다.
- **경로 게이트.** 커밋 · PR 펜스의 경로 검사(`repo_defaults.py check-path` · `state_path.py path-inside`)는 넓히지 않는다 — 이 계획은 펜스를 고치지 않는다.
- **정본 `references/proceed-gate.md`.** skill 폴더 이름 글자 `roadmap-draft` 를 넣지 않는다 — 넣으면 `tests/test_proceed_gate_adopters.sh` 가 그 skill 을 게이트 채택자로 세어 실패한다(계획 1 의 통합 리뷰에서 실제로 났다). 「로드맵 잡기」 로 쓴다. 정본의 받는 쪽 한도 표는 첫 칸이 백틱인 행만 `tests/test_next_session_command.sh` 가 기계로 읽는다 — 표에 행을 더하지 않는다.
- **새 문장의 글자.** 과제 본문이 보기로 든 새 문장과 그 과제 Step 1 의 락 글자가 다르면 락 글자를 따른다 — 새 문장은 락이 무는 글자를 그대로 품고, 나머지 낱말은 구현자가 그 자리의 글에 맞춰 쓴다. 과제 본문에서 인라인 코드를 겹 백틱으로 감싼 곳은 계획 문서 안의 표기다 — 파일에는 홑 백틱으로 쓴다.
- **락.** 새로 쓰는 락과 고치는 락은 커밋한 뒤 변이로 이빨을 본다 — 지우기만이 아니라 더하기 · 뒤집기 · 꼴 바꾸기(표기 · 자리)도, 통과가 정답인 변이(양성 대조)와 함께. 기존 락 가운데 약한 것(F4 의 락 여섯 · F3 둘째 계획의 약한 락)은 이 계획이 그 테스트를 고칠 때 닿는 것만 함께 고친다.
- **셸.** 새 셸 테스트는 macOS `/bin/bash` 3.2 에서 돈다 — `$var` 바로 뒤에 한글이 오면 `${var}` 로 쓴다. heredoc 을 `$( )` 안에 두지 않는다. 새 셸 테스트는 `chmod +x` 하고 `git ls-files -s` 로 100755 를 본다. Python 은 `encoding="utf-8"` 를 명시하고 `python3` 리터럴로 부른다. 변이 시험 전에는 커밋하고, 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 이 빈지 본다. Python 변이는 `PYTHONDONTWRITEBYTECODE=1` 로 돌린다. Bash 도구의 셸은 zsh 다 — 파이프의 rc 가 필요하면 `bash -c` 안에서 잡는다.
- **전체 스위트**는 이 줄로만 돌린다(공유 잠금 — 못 잡으면 주인 · 잡은 시각을 보고한다):
  `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/suite-lock --owner <실행자 이름> --wait 7200 -- bash -c 'bash tools/suite/run-all.sh'`
  SDD 구현자에게는 전체 스위트를 맡기지 않는다 — 과제마다 그 과제의 테스트만 돌리고, 전체 스위트는 과제 9 에서 마지막 리뷰와 그 고침 뒤 한 번 돈다.
- **무시되는 자리.** 과제가 남기는 메모 · 원장 · 대조 출력 · 재는 도구는 작업 트리 안에서 `git check-ignore -q <경로>` 가 0 인 자리(`.claude/tmp/f5-plan3/`)에 둔다.

## 옆 로드맵이 예약한 파일 — 이 계획이 고치는 것

옆 로드맵(`docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md`)의 남은 에픽(2026-11-23 기본 브랜치 607ac54e 기준 — 머지 안 된 것은 E2 · E3 · E4 · R5)의 경로 예약과 겹친다. 과제 1 이 그때의 예약을 다시 읽어 이 표를 고친다. 고치는 과제가 시작하기 전에 지휘자에게 파일과 고칠 줄(grep 글자)을 보고하고, 먼저 머지된 쪽 위에서 쓴다.

| 파일 | 예약한 에픽 | 이 계획이 고치는 것(grep 글자) | 과제 |
|---|---|---|---|
| `plugins/spec-distill/skills/roadmap-draft/SKILL.md` | E4 | `**다음 세션 줄 — 분해된 일 ①/② 공통**` · 되돌아가는 길의 `/spec-distill:context-build @<결과물 절대경로>` 문장 · 이유 설명 줄(과제 1 의 원장) | 5 |
| `plugins/spec-distill/skills/roadmap-draft/references/pr-merge.md` | E4 | 이유 설명 줄(과제 1 의 원장 — 없으면 고치지 않는다) | 5 |
| `plugins/spec-distill/dependencies.md` | E3 · R5 | superpowers 행의 「없을 때」 칸(`지휘자 · 로드맵 흐름은 진입에서 멈춘다`) | 6 |
| `plugins/spec-distill/CHANGELOG.md` | R5 | 새 판 절 | 8 |

머지된 R2 가 예약했던 `docs/philosophy/devbrew-harness-philosophy.md`(Law 1 의 `인터뷰 brief 는` · P3 의 `문서 리뷰 자리 셋`)와 `references/proceed-gate.md`(다음 세션 명령 끝 문단의 `각 skill 의 정의 블록이 그 갈래를 적는다`)도 고친다 — 예약은 풀렸지만 같은 문장을 쥔 `CLAUDE.md`(R2 가 예약한 파일 — 이 설계는 고치지 않는다)와 글이 갈라지므로 지휘자가 옆 로드맵에 알린다.

## Review Focus

1. **이유를 걷다가 지시가 같이 사라짐** — 아홉 자리 밖에도 이유 문장 안에만 사는 지시가 있을 수 있다. 원장에서 처분이 `걷음` 인 행마다 그 문장에 지시 꼴이 없음을 과제가 확인하고, 마지막 리뷰가 `걷음` 행을 하나씩 다시 읽어 지시가 빠졌는지 따로 본다. 시험: 과제 9 Step 4 의 「걷은 행 다시 읽기」 물음.
2. **절 머리 · 문구를 바꾼 뒤 그것을 문 테스트가 공허하게 통과** — awk 로 절을 뜨는 테스트가 옛 머리를 찾지 못하면 부재 단언은 빈 글에서 통과한다. 과제마다 바꾼 머리 · 문구를 `plugins/*/tests` · `shared/tests` · `tools` 에서 grep 해 0 건이 될 때까지 고치고, 그 테스트의 양성 대조(절을 떴다는 단언)가 통과하는지 본다. 시험: 과제 2 Step 6 · 과제 3 Step 6 · 과제 5 Step 4 의 grep.
3. **줄 수 상한에 걸림** — 의도 싱크 본문은 기준과 같은 1523 줄이고 컨텍스트 쌓기 본문은 상한 바로 아래다. 더하는 글(원장 밖 행 · 닫힘 규칙의 단서 · 범례)이 한 줄이라도 늘리면 실패한다. 시험: 과제 2 · 4 Step 5 의 `test_stage_read_budget.sh` · `test_conducting_interview_stage.sh`.
4. **펜스 안 글자를 바꿈** — 산문과 펜스 안 안내문이 같은 글을 쥔 자리(예: STOP 줄)에서 산문을 고치며 펜스까지 고칠 수 있다. 시험: 과제마다의 `fence_diff.py` 대조(허용 한 줄 밖은 0).
5. **번호 락이 살아 있는 번호까지 잡거나(거짓 실패) 표기를 바꾼 옛 번호를 놓침(거짓 통과)** — `S12` · `RC3` · `OQ1` · 라운드 `R1` · `C1` 은 남아야 하고 `(C43)` · `NG4·P17` · `[0.57.0]` 은 잡혀야 한다. 시험: 과제 2 의 락 자기 시험(금지 열아홉 · 살아 있는 번호 0)과 Step 8 의 변이.

## 과제 지도

| # | 과제 | 커밋 성격 | AC · 설계 5 행 |
|---|---|---|---|
| 1 | 다시 확인 — 합치기 · 근거 대조 · 예약 · 재는 도구 · 앞 수 · 닿는 선택 지적 | 합치기 커밋만 | AC28(앞 수) · 선행 |
| 2 | 컨텍스트 쌓기 본문과 그 reference · 새 락 | 글 + 락 | AC29 · AC30 · AC31(⑤⑦⑨) · 라운드 꼴 둘 · 닫힘 규칙 S1 · 글 일곱 ⑦ |
| 3 | 끝맺음 절차 | 글 + 락 | AC29 · AC30 · 「두 경우」 머리 · §6 범례 · 글 일곱 ②⑤ |
| 4 | 의도 싱크 본문 · seed 기록 템플릿 | 글 + 락 | AC29 · AC30 · AC31(①②③④⑥⑧) · 경고 표 행 이름 둘 |
| 5 | 로드맵 잡기 | 글 + 락 | AC30 · 글 일곱 ③④ |
| 6 | 공용 글 — 정본 · 결과물 리뷰 skill · 결과물 템플릿 · README · 의존 표 | 글 + 락 | §6 범례 · 「검사 없이 계속」 · 「확정 · 커밋한 뒤 끝」 · 글 일곱 ①⑥ |
| 7 | 철학 문서 | 글 + 락 | AC34 · 철학 문서 훑기 |
| 8 | 판 · 변경 기록 | 판 | — |
| 9 | 마무리 — 뒤 수 · AC37 · 펜스 대조 · 전체 스위트 · AC 보고 | 확인 | AC28 · AC32 · AC37 · AC38 · 전부 |

---

### Task 1: 다시 확인

설계문서가 근거로 든 자리가 계획 2 뒤의 글에서도 그런지 보고, AC28 의 앞 수를 잰다. 과제를 바꿀 만큼 다르면 멈춰 지휘자에게 보고한다. 산출물은 무시되는 자리의 메모 · 원장 · 도구다.

**Files:**
- Create(추적 안 함): `.claude/tmp/f5-plan3/recheck.md` · `.claude/tmp/f5-plan3/reasons.tsv` · `.claude/tmp/f5-plan3/fence-allow.tsv` · `.claude/tmp/f5-plan3/fence_diff.py` · `.claude/tmp/f5-plan3/reason_ledger.py` · `.claude/tmp/f5-plan3/scan_ids.py`
- Modify: (합치기 커밋 · 예약 표가 달라졌을 때의 이 계획 표만)

**Interfaces:**
- Produces: `recheck.md` 의 절 — `## 근거 대조` · `## 낡은 서술 열 곳` · `## 지시 아홉 자리` · `## 설계 5 의 계획 3 행` · `## 옆 로드맵 예약` · `## 기준 커밋` · `## 앞 수` · `## 닿는 선택 지적`. 과제 2–9 가 읽는다.
- Produces: `python3 .claude/tmp/f5-plan3/fence_diff.py <앞 판> <뒤 판|WORKTREE> <허용 목록|-> <경로>...` → 파일마다 `fence: SAME|DIFF|ALLOWED …`, 끝 줄 `fence-diff: OK|FAIL <수>`, rc 0(허용 밖 변경 없음) · 1 · 2. 허용 목록 꼴: `<경로>\t<앞 판 펜스 본문에 든 글자>\t<이유>`.
- Produces: `python3 .claude/tmp/f5-plan3/reason_ledger.py check|count <원장>` → 끝 줄 `reasons: 앞 <행 수> · 남음 <있는 행> · 걷힘 <없는 행>`, `check` 는 조각이 파일에서 정확히 한 번이 아니면 rc 1. 원장 꼴(TSV, 머리 줄 하나): `파일\t줄\t갈래(이유|이력)\t처분(걷음|남김-범위|남김-지시)\t조각(그 문장의 한 줄 안에서 그대로 뗀 20 글자 이상)`.
- Produces: `python3 .claude/tmp/f5-plan3/scan_ids.py <파일>...` → `파일:줄: 글자` 줄들(과제 2 락의 스캐너와 같은 정규식).

- [ ] **Step 1: 합친다** — `git fetch origin` 뒤 `git merge --no-ff origin/<기본 브랜치>`(이름은 `python3 plugins/spec-distill/scripts/repo_defaults.py default-branch --root .`). 이 계획을 에픽 브랜치(`feature/front-stage-restructure`)가 아닌 브랜치에서 시작했으면 `origin/feature/front-stage-restructure` 도 합친다. 충돌이 나면 `git merge --abort` 하고 멈춰 보고한다. 합친 뒤 계획 2 의 산출물(`plugins/spec-distill/scripts/legacy_names.py` · `plugins/spec-distill/tests/test_legacy_literals.sh`)이 없으면 멈춘다. 커밋 메시지: `chore(merge): 기본 브랜치를 F5 브랜치에 합친다` + 끝 줄들. 합친 뒤의 `git rev-parse HEAD` 를 `## 기준 커밋` 에 적는다 — 과제 9 의 앞뒤 대조가 이 커밋을 앞으로 쓴다.

- [ ] **Step 2: 재는 도구 셋을 만든다(계획이 적은 코드 — 계획을 쓸 때 계획 1 뒤의 나무에서 돌려 봤다: 펜스 대조는 같은 판 둘에 `fence-diff: OK 0`, 스키마 펜스 주석 한 글자를 바꾸면 `FAIL 1`, 허용 목록에 그 펜스를 두면 `ALLOWED` · `OK 0`. 원장은 줄바꿈을 넘는 조각을 `0 번 나온다` 로 잡았다)**

`fence_diff.py` — 각 파일을 두 판에서 읽어(`git show <판>:<경로>`, `WORKTREE` 면 작업 트리) 펜스 목록을 순서대로 뽑고 견준다:

```python
OPEN = re.compile(r"^(?P<ind>[ \t]*)(?P<mark>`{3,}|~{3,})(?P<info>.*)$")


def fences(text):
    """열린 줄부터 같은 글자로만 된 같거나 긴 닫는 줄까지를 한 덩어리로(여는 줄 · 닫는 줄 포함)."""
    out, lines, i = [], text.splitlines(), 0
    while i < len(lines):
        m = OPEN.match(lines[i])
        if not m:
            i += 1
            continue
        mark, body, j = m.group("mark"), [lines[i]], i + 1
        while j < len(lines):
            body.append(lines[j])
            s = lines[j].strip()
            if s and set(s) == {mark[0]} and len(s) >= len(mark):
                break
            j += 1
        out.append("\n".join(body))
        i = j + 1
    return out
```

나머지: 펜스 수가 다르면 `fence: DIFF <경로> — 펜스 수 a → b`(허용으로 덮지 않는다), 같은 자리의 펜스가 다르면 앞 판 펜스 본문에 허용 목록의 글자가 들었을 때만 `ALLOWED`, 아니면 `DIFF` 와 unified diff. 읽지 못하면 stderr `[fence_diff] …` · rc 2.

`reason_ledger.py` — 위 Interfaces 의 꼴. `check` 는 조각마다 `파일 글.count(조각) == 1` 인지, `count` 는 `> 0` 인 행을 남음으로 세고 `(파일, 처분)` 별 줄과 끝 줄을 낸다. 머리 줄 밖의 줄이 다섯 칸 · 갈래 · 처분 · 20 글자 조건을 어기면 rc 2.

`scan_ids.py` — 과제 2 Step 1 의 락에서 `<<'PY'` ~ `PY` 사이 파이썬을 그대로 옮긴다(인자 `--self` 갈래 포함). `python3 -c 'import ast,sys;ast.parse(open(sys.argv[1],encoding="utf-8").read())' <파일>` 로 셋 다 파싱을 본다.

`fence-allow.tsv` 에 한 줄: `plugins/spec-distill/skills/context-build/SKILL.md\t# G1 커버리지 원장\tAC30 — 앞단 글의 옛 번호가 스키마 펜스 주석에 있다`(실제 탭). 그 주석 글자가 계획 2 뒤에 다르면 지금 글자로 적는다.

- [ ] **Step 3: 설계문서의 근거를 다시 연다** — 아래를 지금 글에서 확인하고 「같다 / 다르다 — 무엇이」 를 `## 근거 대조` 에 한 줄씩 적는다. 하나라도 과제를 바꿀 만큼 다르면 멈춘다.
  - 줄 수: `wc -l skills/intent-sync/SKILL.md`(계획을 쓸 때 1523) · `skills/context-build/SKILL.md` 의 자기 줄 수(`test_conducting_interview_stage.sh` 의 `skill_own_lines` 와 같은 awk — 600) · `test_stage_read_budget.sh` 의 `BASE_INTENT=1523` · `BASE_INTERVIEW=1587` · `test_conducting_interview_stage.sh` 의 `SKILL_LINE_CAP=604`.
  - `## 낡은 서술 열 곳` — 설계 4 의 열 곳을 grep 해 자리(파일 · 지금 글자)와 상태(남아 있음 / 이미 닫힘 — 무엇이)를 적는다. 계획을 쓸 때(계획 1 뒤 · 계획 2 전) 본 것:
    1. audit 를 「5-section」 이라 부름 — `finishing.md` 의 `audit **5-section** 구조` (템플릿 `interview-audit-template.md` 은 `## 1.`–`## 7.` 일곱 절). 남아 있음.
    2. 스키마에 없는 `decompose_edits` — 앞단 글에 0 건(계획 1 이 `## 분해안` 의 「고친 횟수」 로 옮겼다). 이미 닫힘.
    3. 없는 절 번호 「§2.4 스키마」 — `context-build/SKILL.md` 의 `§2.4 스키마의 **어떤 키든 부재**` · `context-build/references/state-migration.md` 의 `§2.4 스키마의 **부재 키가 있는가**`. 남아 있음.
    4. 출처를 알 수 없는 「spec OQ6」 — `context-build/SKILL.md` 의 `그 한계는 spec OQ6`. 남아 있음.
    5. `framing_degradations` 원장이 「구조적으로 부재」 와 템플릿의 어긋남 — `intent-sync/SKILL.md` 의 `원장이 구조적으로 부재하므로`(본문은 `ledger_rc=1` 로 원장을 쓰지 않는다) vs `templates/interview-seed-audit-template.md` `## 5. degrade` 의 `--ledger-key` · `framing_degradations` 로 기록한 것을 … 직렬화한다`. 남아 있음.
    6. 문장 중간에 끊긴 「4옵션」 — `intent-sync/SKILL.md` 에 `4옵션` 한 글자만 있는 줄(뒤 줄이 `게이트를 띄우고, 게이트 앞 글에 degrade 를`). 남아 있음.
    7. 종료 조건이 건너뜀을 말하지 않음 — `context-build/SKILL.md` 의 소개 문구 · `## 종료` 가 `모델 판단으로 건너뜀` 을 말한다(계획 1 AC15). 이미 닫힘.
    8. 「질문 하나」 와 「여럿 묶기 허용」 의 어긋남 — `context-build/SKILL.md` 의 소개 문단 `«지금 이해 · 다음 결정 · 질문 하나»로 묻되` · 절 머리 `## 라운드 규약 — 지금 이해 · 다음 결정 · 질문 하나` vs 같은 절의 `질문을 여럿 묶을 수 있다`. 남아 있음(설계 5 「묻지 않은 다섯」 행의 「라운드 꼴의 어긋난 문장 둘」 과 같다).
    9. 상태 파일 본문 목록에 빠진 두 절 — `context-build/references/state-file.md` 의 `### 상태 파일 본문의 절` 에 `## 반대 논거 기록 대기` · `## 위험 줄 대기` 가 있다(계획 1 과제 9). 이미 닫힘.
    10. 끝난 일을 가리키는 「R2a 의 일이다」 — `finishing.md` 의 `엔진의 접기 폭 · 요약 폭 상수는 R2a 의 일이다`. 남아 있음.
  - `## 지시 아홉 자리` — 설계 4 의 아홉을 grep 해 자리와 지금 꼴(이미 지시 문장 / 이유 안에만)을 적는다. 계획을 쓸 때 본 자리:
    ① 원자료 기록(audit)을 상태 폴더에 두지 않는다 — `intent-sync/SKILL.md` 의 `` `.claude/spec-distill/` 에 두지 않는 이유는 그 자리가 정리(TTL 기본``(이유 안에만).
    ② worktree 의 기준 설정을 자동으로 바꾸지 않는다 — `intent-sync/SKILL.md` 의 `**자동으로 `` `worktree.baseRef=head` `` 로 바꾸지 않는 이유**`(이유 머리).
    ③ seed 의 frontmatter 를 떼지 않는다 — `intent-sync/SKILL.md` 의 `**frontmatter 를 떼지 않는 이유**`(이유 머리 — 같은 문장의 `type:` 값은 계획 2 가 새 글자로 바꿨다).
    ④ 풀이를 고르는 질문에 추천을 달지 않는다 — `intent-sync/SKILL.md` 의 `두 꼴 모두 추천을 달지 않는다 — 풀이는 저자가 쓴 것이라`(지시 + 이유. 같은 꼴이 `기준 사본이 없어 저자 편집이` · `덜어 낸 것은 저자의 압축 편집이라` 자리에도 있다).
    ⑤ subagent 에 플러그인 파일은 경로가 아니라 내용으로 싣는다 — `context-build/SKILL.md` 의 `` `${CLAIMS_CONTRACT}` 에는 경로가 아니라 **계약 파일의 내용**을 싣는다 — 플러그인 캐시는 사용자``(한 자리 지시 + 범위 이유).
    ⑥ 코드 블록마다 상태 블록을 앞에 이어 붙인다 — `intent-sync/SKILL.md` 의 `「먼저 돌려라」가 아니라 「앞에 이어 붙여라」라고 쓰는 이유가 그것입니다`(이유 안에만 — 「별개 호출로 다시 돌리지 않는다」).
    ⑦ 끄는 변수를 dispatch 자리마다 다시 확인한다 — `context-build/SKILL.md` 의 `이 확인은 R2의 landscape 확인과 **별개로** 여기 있어야 한다 — kill switch는 보안 컨트롤이고`(이유 안에만).
    ⑧ seed 냉독에 경로를 넘기지 않는다 — `intent-sync/SKILL.md` 의 `경로를 넘기는 선택지는 없습니다 — `` `seed-readback` `` 은 `` `tools: []` ``(사실 서술 + 이유).
    ⑨ 해결된 결정을 목록에서 지우지 않는다 — `context-build/SKILL.md` 의 `**해결돼도 목록에서 지우지 않는다**`(이미 지시 + 이유).
  - `## 설계 5 의 계획 3 행` — 설계 5 표에서 계획 칸이 3 인 「한다」 행마다 원문 자리(설계 5 표 아래 「원문 자리」)에서 묶음 수를 다시 읽고 지금 자리를 적는다: 라운드 꼴 문장 둘(위 8) · F4 작은 지적 여덟 가운데 「확정 · 커밋한 뒤 끝」(`README.md` 의 superpowers 줄 · `dependencies.md` superpowers 행 — `brief만 종료` 는 확정하지 않고 커밋한다: `finishing.md` 의 `「brief만 종료」 는 (나눈 일이면 위험 번호 검사 통과 뒤) 종료 안내 직전, 한 번`)와 「두 경우」 머리(`finishing.md` 의 `#### B-S` 첫 문장 `두 경우에 온다` — B-S 로 오는 자리는 셋이다: Step A.5 의 구조 게이트 · B-A 의 구조 게이트가 「나눈 일은 건너뛸 수 없다」 로 막았을 때, 끝 질문 기타 칸) · 철학 문서 훑기 · §6 표시 규칙 범례(범례 글자는 `templates/interview-audit-template.md` 의 `> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론`) · 닫힘 규칙과 의례 한 줄의 `사용자 원문 인용 S(S1 과` · 「검사 없이 계속」 설명(`skills/reviewing-brief/SKILL.md` 의 `「검사 없이 계속」(얻음: 이 검사만 건너뛰고`) · 경고 표의 행 이름 둘(`intent-sync/SKILL.md` 의 `| `` `handoff` · `raw-source` `` |` 행 — PR 299 본문: 경고 원장을 쓰는 `brief_review_state.py` 가 받는 이름 목록 밖) · 재기(이 과제) · 글 일곱(설계 5 표 끝 행 — 아래 과제 2 · 3 · 5 · 6 이 받는다). 「F3 둘째 계획의 락 가운데 약한 것」 · F4 의 「락 여섯」 은 닿는 것만이다.
  - 철학 문서: `docs/philosophy/devbrew-harness-philosophy.md` 의 앞단에 닿는 문장 — Law 1 `인터뷰 brief 는` · P2 코드 앵커(계획 1 이 `skills/context-build/SKILL.md` 로 고쳤다) · P3 의 `문서 리뷰 자리 셋(design doc · brief · seed)` · 「가벼운 꼴」(`짧은 brief`). P8 절의 시작 줄(`### P8 —`)과 끝(다음 `### `)을 적는다.

- [ ] **Step 4: 옆 로드맵 예약을 다시 읽는다** — 그때의 기본 브랜치의 옆 로드맵을 읽어 머지 안 된 에픽의 `경로 예약:` 과 이 계획이 고치는 파일의 교집합을 낸다(`python3 plugins/spec-distill/scripts/roadmap_status.py docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` 로 머지된 에픽을 가른다). 위 「옆 로드맵이 예약한 파일」 표와 다르면 표를 고치는 커밋(`docs(plan): …`)을 하고 지휘자에게 보고한다.

- [ ] **Step 5: 앞 수를 잰다(AC28)** — `## 앞 수` 에 파일마다 한 줄씩 「줄 수 · 낡은 서술(열 곳 가운데 그 파일에 남은 수) · 풀 수 없는 번호(`scan_ids.py` 가 낸 줄 수) · 이유 설명(원장 행 수)」 을 적는다. 파일은 번호 코퍼스 넷(`intent-sync/SKILL.md` · `context-build/SKILL.md` · `context-build/references/finishing.md` · `roadmap-draft/` 아래 추적 파일)이다. 계획을 쓸 때(계획 2 전) 번호는 33 곳이었다(컨텍스트 쌓기 본문 15 · 끝맺음 16 · 의도 싱크 2 · 로드맵 잡기 0).
  - 이유 원장 `reasons.tsv` 를 만든다: 네 묶음의 코드 블록 밖 글을 처음부터 끝까지 읽고, 이유 · 이력 설명인 문장(왜 그렇게 하는지 · 언제 어떻게 바뀌었는지 · 무엇을 실측했는지를 말하고 그 자체로 할 일을 정하지 않는 문장 · 괄호 · 머리)마다 한 행. 처분은 `걷음`(지시를 받치지 않는다) · `남김-범위`(이유가 규칙의 범위를 정한다) · `남김-지시`(이유 안에 지시가 있다 — 지시 문장으로 다시 쓴다). 조각은 그 문장의 한 줄 안에서 그대로 뗀다. 쉬운 말 규칙 블록은 세지 않는다. `python3 .claude/tmp/f5-plan3/reason_ledger.py check .claude/tmp/f5-plan3/reasons.tsv` 가 rc 0 일 때까지 조각을 고친다.
  - 원장의 처분은 과제 2–5 가 따르는 계획이다 — 과제가 글을 읽다 처분을 바꾸면 원장을 고치고 그 행을 커밋 본문에 적는다.

- [ ] **Step 6: 닿는 선택 지적을 뽑는다** — 지휘 세션의 대조표 `/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/tmp/qg-fix-triage/triage.md`(품질 리뷰가 낸 선택 지적을 기준 나무에 대조한 표)에서, 이 계획이 고치는 파일(과제 2–7 의 Files)에 걸리고 판정이 `남아 있음` 인 **선택 지적** 행을 `## 닿는 선택 지적` 에 번호 · 파일 · 자리 · 한 줄 요지로 옮긴다. 막는 지적 · 낮춘 지적 행은 옮기지 않는다. 파일이 없으면 이 걸음을 건너뛰고 그 사실을 그 절에 적는다. 계획을 쓸 때 본 후보(지금 자리로 다시 확인한다): F4-O13(끝맺음 ④ 의 `brief terminal advisory` 를 정의한 곳이 없다 — 과제 3 이 같은 줄을 고친다) · F3b-O23(끝맺음 커밋 절 글이 framing 기록 · seed 의 위치 조건을 말하지 않는다 — 과제 3 이 그 문단에 닿을 때만) · F3b-O25(`steelman.md` 의 `원자료(S1 에 실리는 framing 기록의 사용자 줄)` — 과제 2 의 S1 단서와 같은 뿌리) · F2-O11(의도 싱크 미리 보기 실패 rc 의 처리가 안 적혔다 — 지시를 새로 정하는 일이라 글 줄이기 밖, 닿았지만 고치지 않음). 뒤 과제는 이 절에서 **자기가 고치는 줄이나 바로 그 문단에 걸린 것만** 함께 고치고, 글 줄이기 범위(글을 맞추거나 걷는 것)를 넘는 것은 고치지 않는다. 고친 번호는 그 과제의 커밋 본문에 적는다.

---

### Task 2: 컨텍스트 쌓기 본문과 그 reference · 새 락 (AC29 · AC30 · AC31 ⑤⑦⑨)

**Files:**
- Create: `plugins/spec-distill/tests/test_stage_prose_trim.sh`(100755)
- Modify: `plugins/spec-distill/skills/context-build/SKILL.md` · `skills/context-build/references/state-migration.md` · `skills/context-build/references/state-file.md` · `skills/context-build/references/steelman.md`(F3b-O25 만) · `plugins/spec-distill/README.md`(`- **C43** 3-path` 줄 하나) · `plugins/spec-distill/tests/test_conducting_interview_stage.sh`(바꾼 머리 · 문구를 무는 줄만)

**Interfaces:**
- Consumes: 과제 1 의 `fence_diff.py` · `fence-allow.tsv` · `reasons.tsv` · `## 닿는 선택 지적`.
- Produces: `test_stage_prose_trim.sh` 의 틀 — `NUM_FILES` 배열(번호 코퍼스의 명시 목록) · `has <레포 상대경로> <글자> <라벨>` · `lacks …` · `scan_ids <파일>...`. 과제 3–7 이 자기 절을 `finish` 앞에 더하고 과제 3 · 4 가 `NUM_FILES` 에 자기 파일을 한 줄씩 더한다. 질문 경로 절의 새 머리 `## 3-path routing`.

- [ ] **Step 1: 실패하는 락을 쓴다(계획이 적은 코드 — 계획을 쓸 때 `bash -n` 과 파이썬 `ast.parse` 를 지났고, 계획 1 뒤의 나무에서 자기 시험 둘이 통과하고 옛 번호 33 곳을 냈다)**

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/intent-sync/SKILL.md plugins/spec-distill/skills/context-build/* plugins/spec-distill/skills/roadmap-draft/* plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/README.md plugins/spec-distill/dependencies.md docs/philosophy/devbrew-harness-philosophy.md
# 글 줄이기 — 앞단 글에 풀 수 없는 옛 설계 번호 · 옛 판 번호 · 날짜 실측 표기가 없고(AC30), 낡은 서술이 고쳐졌고(AC29),
# 이유 문장 안에만 있던 지시가 지시 문장으로 남았다(AC31). 철학 번호(P · AP · Law)와 결과물의 살아 있는 번호
# (S · K · OQ · RC · ST · 라운드 R)는 남는다 — 아래 자기 시험이 그것을 잰다(양의 짝).
# 정적 락이다 — 모델이 이 글을 실제로 따르는지는 재지 못한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_stage_prose_trim.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
NUM_FILES=(
  plugins/spec-distill/skills/context-build/SKILL.md
  plugins/spec-distill/skills/roadmap-draft/SKILL.md
  plugins/spec-distill/skills/roadmap-draft/references/pr-merge.md
)
num_corpus() {   # 명시 목록 + 로드맵 잡기 아래에 새로 생긴 추적 파일
  { printf '%s\n' "${NUM_FILES[@]}"; git -C "$ROOT" ls-files -- 'plugins/spec-distill/skills/roadmap-draft/*'; } | sort -u
}
if [ "${1:-}" = "--emit-scanned" ]; then   # 읽는 파일: 번호 코퍼스 + 과제 2–7 의 절이 has · lacks 로 읽는 파일
  { num_corpus
  printf '%s\n' plugins/spec-distill/skills/context-build/references/finishing.md \
    plugins/spec-distill/skills/intent-sync/SKILL.md \
    plugins/spec-distill/skills/context-build/references/state-file.md \
    plugins/spec-distill/skills/context-build/references/state-migration.md \
    plugins/spec-distill/templates/interview-seed-audit-template.md \
    plugins/spec-distill/templates/interview-brief-template.md \
    plugins/spec-distill/skills/reviewing-brief/SKILL.md \
    plugins/spec-distill/references/proceed-gate.md \
    plugins/spec-distill/README.md plugins/spec-distill/dependencies.md \
    docs/philosophy/devbrew-harness-philosophy.md; } | sort -u
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
TMPD="$(mktemp -d "${TMPDIR:-/tmp}/prose-trim.XXXXXX")" || exit 2
trap 'rm -rf -- "$TMPD"' EXIT

has()   { grep -qF -- "$2" "$ROOT/$1" && ok "$3" || no "$3 — 없다: «$2» ($1)"; }
lacks() { grep -qF -- "$2" "$ROOT/$1" && no "$3 — 남아 있다: «$2» ($1)" || ok "$3"; }

# ── AC30 — 옛 번호 스캐너(쉬운 말 규칙 블록만 빼고 코드 블록 안까지 본다) ──────────────────
scan_ids() {
  python3 - "$@" <<'PY'
import re
import sys

OLD = re.compile(
    r"(?<![A-Za-z0-9_./-])(?:C43|C4|C5|C8|G1|G2|N1a|N1b|N2|NG4|NG7|AC\d+|D6|OQ6|R2a)(?![A-Za-z0-9_])"
    r"|(?<![\w.])v?\d+\.\d+\.\d+(?![\w.])"
    r"|(?<!\d)20\d\d-[01]\d-[0-3]\d(?!\d)"
)
SELF_BAD = "C43 절 · (C4) · C5, · C8 — · G1 · G2 · N1a · N1b · N2 · NG4·P17 · NG7 · AC1 · AC12 · D6 · OQ6 · R2a 의 · v0.24.0 · [0.57.0] · 2026-09-10"
SELF_LIVE = "S1 S12 K1 RC3 OQ1 OQ4 R1 R5 P21 AP2 Law 1 C1 C2 D5 ST1 <YYYY-MM-DD> 3-path"

args = sys.argv[1:]
if args == ["--self"]:
    bad = [m.group(0) for m in OLD.finditer(SELF_BAD)]
    live = [m.group(0) for m in OLD.finditer(SELF_LIVE)]
    print("self-bad %d" % len(bad))
    print("self-live %d %s" % (len(live), " ".join(live)))
    sys.exit(0)
for path in args:
    inside = False
    with open(path, encoding="utf-8") as fh:
        for no, line in enumerate(fh, 1):
            if "<!-- plain-language:begin -->" in line:
                inside = True
            if inside:
                if "<!-- plain-language:end -->" in line:
                    inside = False
                continue
            for m in OLD.finditer(line):
                print("%s:%d: %s" % (path, no, m.group(0)))
PY
}

scan_ids --self > "$TMPD/self.txt"
assert_eq "$(sed -n 's/^self-bad //p' "$TMPD/self.txt")" "19" "AC30(양성 대조): 스캐너가 금지 글자 열아홉을 모두 잡는다"
assert_eq "$(sed -n 's/^self-live //p' "$TMPD/self.txt")" "0 " "AC30(양성 대조): 살아 있는 번호(S · K · RC · OQ · 라운드 R · P · AP · C1 · C2 · D5 · ST)는 잡지 않는다"

for f in "${NUM_FILES[@]}"; do
  [ -s "$ROOT/$f" ] && ok "AC30(양의 짝): 번호 코퍼스에 ${f} 가 있다" || no "AC30: 번호 코퍼스의 ${f} 가 없거나 비었다 — 부재 단언이 공허하다"
done
CORPUS="$(num_corpus)"
# shellcheck disable=SC2086
( cd "$ROOT" && scan_ids $CORPUS ) > "$TMPD/ids.txt"
n_hits="$(grep -c . "$TMPD/ids.txt" || true)"
if [ "$n_hits" -eq 0 ]; then ok "AC30: 앞단 글에 옛 설계 번호 · 옛 판 번호 · 날짜 실측 표기가 없다"
else no "AC30: 옛 번호 ${n_hits}곳"; sed 's/^/      /' "$TMPD/ids.txt"; fi
# shellcheck disable=SC2086
( cd "$ROOT" && grep -l -E '(^|[^A-Za-z0-9])P(17|21|23)([^0-9]|$)' $CORPUS ) > "$TMPD/phil.txt" || true
[ -s "$TMPD/phil.txt" ] && ok "AC30(양의 짝): 철학 번호(P17 · P21 · P23)가 남아 있다" || no "AC30: 철학 번호가 하나도 없다 — 지우기가 넘쳤다"
for f in $CORPUS; do lacks "$f" 'decompose_edits' "AC29 ②: 스키마에 없는 상태 키가 ${f##*/} 에 없다(계획 1 이 닫음 — 지킨다)"; done

# ── 컨텍스트 쌓기 본문과 그 reference (과제 2) ────────────────────────────────────────
CB=plugins/spec-distill/skills/context-build/SKILL.md
lacks "$CB" '§2.4' "AC29 ③: 없는 절 번호 「§2.4」 가 본문에 없다"
lacks plugins/spec-distill/skills/context-build/references/state-migration.md '§2.4' "AC29 ③: 없는 절 번호 「§2.4」 가 이전 reference 에 없다"
has   "$CB" 'State location` 의 스키마' "AC29 ③(양의 짝): 스키마를 절 이름으로 가리킨다"
lacks "$CB" '다음 결정 · 질문 하나' "AC29 ⑧: 라운드 꼴이 「질문 하나」 로 적히지 않는다"
has   "$CB" '질문을 여럿 묶을 수 있다' "AC29 ⑧(양의 짝): 여럿 묶기 허용 문장이 남아 있다"
has   "$CB" '모델 판단으로 건너뜀' "AC29 ⑦: 종료 조건이 건너뜀을 말한다(계획 1 이 닫음 — 지킨다)"
has   plugins/spec-distill/skills/context-build/references/state-file.md '## 위험 줄 대기' "AC29 ⑨: 상태 파일 본문 목록에 두 절이 있다(계획 1 이 닫음 — 지킨다)"
has   "$CB" '## 3-path routing' "AC30(양의 짝): 질문 경로 절 머리가 번호 없이 남아 있다"
has   "$CB" 'S1 은 원자료가 실렸을 때만 든다' "닫힘 규칙: 모델이 줄인 S1 은 사용자 원문 인용으로 세지 않는다"
has   "$CB" '해결돼도 목록에서 지우지 않는다' "AC31 ⑨: 해결된 결정을 목록에서 지우지 않는다"
has   "$CB" 'subagent 에 넘기는 플러그인 파일은 경로가 아니라 내용으로 싣는다' "AC31 ⑤: 플러그인 파일은 내용으로 싣는다"
has   "$CB" '웹 kill switch 는 dispatch 자리마다 따로 확인한다' "AC31 ⑦: 끄는 변수를 dispatch 자리마다 확인한다"
has   plugins/spec-distill/skills/context-build/references/state-file.md '리뷰 결정 문구는 그렇게 정했다는 사실과 뜻까지만 읽는다' "글 일곱 ⑦: 컨텍스트 쌓기의 원자료 읽기도 리뷰 결정 문구를 뜻까지만 읽는다"

finish
```

Run: `bash plugins/spec-distill/tests/test_stage_prose_trim.sh` → Expected: FAIL(옛 번호 · 위 부재 · 새 문장).

- [ ] **Step 2: 앞 판을 적는다** — `git rev-parse HEAD` 를 `TASK_BASE` 로 메모한다(펜스 대조의 앞).

- [ ] **Step 3: 옛 번호와 낡은 서술을 고친다(`skills/context-build/SKILL.md` · `state-migration.md`)**
  - 질문 경로 절: 머리 `## C43 3-path routing` → `## 3-path routing`. 본문의 `C43 절의 internal_research admit` → `3-path routing 절의 internal_research admit`(다섯 자리), `C43 경로 (a)` → `3-path routing 의 경로 (a)`. README 의 `- **C43** 3-path Socratic routing` 줄은 `- **3-path routing** — Socratic routing` 꼴로 같은 이름을 쓴다(README 는 번호 코퍼스 밖이지만 본문 머리와 이름이 갈리지 않게).
  - 절 머리 · 괄호의 옛 번호를 뗀다: `## 사용자 발화 기록 (G1, AC1)` → `## 사용자 발화 기록` · `## blind-spot-prober dispatch (C8 — blind_spot floor 차원)` → `## blind-spot-prober dispatch (blind_spot floor 차원)` · `orchestrator, G2)` 의 `, G2` · `**첫 dispatch 의 검증 의무(D6)**` 의 `(D6)` · `inline premortem**으로 전환한다(C5,` 의 `C5, `. 스키마 펜스 주석 `# G1 커버리지 원장` → `# 커버리지 원장`(허용 목록의 한 줄).
  - `그 한계는 spec OQ6` 를 지운다 — 앞 괄호(«어느 S 가 닫힘을 정당화하는가»는 보지 않는다)만 남긴다.
  - `§2.4 스키마` → `` `## State location` 의 스키마``(본문 · `state-migration.md` 둘 다 — 절 이름은 지금 본문의 그 머리 글자 그대로).
  - 라운드 꼴(⑧ · 설계 5 「라운드 꼴의 어긋난 문장 둘」): 절 머리 `## 라운드 규약 — 지금 이해 · 다음 결정 · 질문 하나` → `## 라운드 규약 — 지금 이해 · 다음 결정 · 질문` · 소개 문단 `«지금 이해 · 다음 결정 · 질문 하나»로 묻되` → `«지금 이해 · 다음 결정 · 질문»으로 묻되`. 「질문을 여럿 묶을 수 있다」 문장과 쉬운 말 규칙 블록의 「질문 하나에 결정 하나」 는 그대로다.
  - 닫힘 규칙(설계 5 「사용자 원문 인용 S(S1 과 …)」 행): `## 닫힘 · 재개방` 의 `root_problem = 사용자 원문 인용 S(S1 과 문제를 서술한 발화)` 와 `## 5 통과 의례` 표 R1 행의 `S1 과 문제를 서술한 이후 사용자 발화를 **원문 그대로 인용**해 닫는다` 에 같은 단서를 단다 — `S1 은 원자료가 실렸을 때만 든다(찾지 못함 · 그대로 싣지 못함 갈래의 S1 은 모델이 줄인 글이다)`. `root_problem = 사용자 원문 인용 S` 글자는 남긴다(`test_conducting_interview_stage.sh` 의 양의 짝). `test_interview_raw_source_entry.sh` 의 옛 낱말 목록(`사용자 원문(S1 과 문제를 서술한 발화)` 등)을 새 글에 들이지 않는다. 같은 단서가 `steelman.md` 의 `원자료(S1 에 실리는 framing 기록의 사용자 줄)` 에 닿으면(F3b-O25) 그 구절을 `원자료(framing 기록의 사용자 줄 — 없으면 첫 입력)` 로 맞춘다.

- [ ] **Step 4: 지시를 살리고 이유를 걷는다** — 원장(`reasons.tsv`)의 이 파일 행을 처분대로 고친다. 아홉 자리 가운데 이 파일의 셋:
  - ⑤ `${CLAIMS_CONTRACT}` 문단의 첫 문장을 `subagent 에 넘기는 플러그인 파일은 경로가 아니라 내용으로 싣는다 — 플러그인 캐시는 사용자 프로젝트 밖이라 subagent 의 Read 가 거부된다.` 로 시작하게 다시 쓰고, `${CLAIMS_CONTRACT}` 에 계약 파일의 내용을 싣는다는 문장을 그 뒤에 둔다(범위 이유는 한 구절로 남긴다).
  - ⑦ `**Web kill switch (dispatch 직전 확인 — 이 블록에 종속)**` 문단의 `이 확인은 R2의 landscape 확인과 **별개로** 여기 있어야 한다 — …` 를 `웹 kill switch 는 dispatch 자리마다 따로 확인한다 — R2 의 landscape 확인으로 갈음하지 않는다.` 로 다시 쓰고, 그 뒤의 보안 컨트롤 설명은 원장 처분대로 걷거나 한 구절로 줄인다(`coverage-mapper` 가 `Bash` 가 없어 스스로 확인할 수 없다는 사실은 「orchestrator 가 확인한다」 는 지시의 범위라 남긴다).
  - ⑨ `**해결돼도 목록에서 지우지 않는다**` 는 이미 지시다 — 뒤의 이유(조사가 해결에 기여한 성공 사례 · 게이트의 실재 검사)는 범위를 정하는지 보고 처분대로.
  - 원자료 읽기(글 일곱 ⑦): `references/state-file.md` 의 원자료를 정의하는 문장(`` `## 6. 리뷰 결정` 절의 사용자 문구`` 를 원자료로 드는 문장) 바로 뒤에 `리뷰 결정 문구는 그렇게 정했다는 사실과 뜻까지만 읽는다 — 낱말을 사용자의 글자로 인용하지 않는다.` 를 잇는다(로드맵 잡기 읽기의 같은 문장과 같은 뜻).
  - 줄 수: 본문의 자기 줄 수가 604 미만이어야 한다. 더하는 글은 있는 줄에 잇는다.

- [ ] **Step 5: 통과를 본다** — `bash plugins/spec-distill/tests/test_stage_prose_trim.sh` 의 과제 2 절과 자기 시험(옛 번호 단언은 끝맺음 · 의도 싱크가 아직 코퍼스 밖이라 이 과제에서는 컨텍스트 쌓기 본문 · 로드맵 잡기만 잰다 — 통과) · `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh` · `test_stage_read_budget.sh` · `test_stage_words.sh` · `test_interview_raw_source_entry.sh` · `test_open_research.sh` · `test_stale_terms.sh` · `test_distortion_devices.sh` · `bash shared/tests/test_shell_tests_executable.sh`(새 셸 테스트의 실행 비트). 새 테스트가 걸리는 그 밖의 레포 락(`# guards:` 머리 · UTF-8 명시 · 중복 줄 등)은 과제 9 의 전체 스위트가 잰다 — 거기서 이 파일 이름이 나오면 과제 9 의 고침 물결에서 고친다. Expected: 통과.

- [ ] **Step 6: 바꾼 머리 · 문구를 무는 테스트를 맞춘다** — `git grep -n -e '## C43' -e 'C43 절' -e 'C43 경로' -e '질문 하나»' -e '§2.4' -- 'plugins/*/tests/*' 'shared/tests/*' 'tools/*'` 가 주석 밖에서 0 건이 되게 고친다. 계획을 쓸 때 본 자리: `test_conducting_interview_stage.sh` 의 `awk '/^## C43 /` → `/^## 3-path routing/` · `sed -n 's/^## C43 \([0-9][0-9]*\)-path.*/\1/p'` → `sed -n 's/^## \([0-9][0-9]*\)-path.*/\1/p'` · `grep -qF 'C43 절의 internal_research admit'` → 새 문구. 라벨 글(`ok "C43: …"`)은 「질문 경로」 로 바꿔도 된다. 고친 뒤 그 테스트의 양성 대조(`C43(양성대조): 절·표 행 …개 … 전부 추출`)가 통과하는지 본다.

- [ ] **Step 7: 커밋하고 펜스를 견준다** — `git add -- <고친 파일들>` 뒤 `git commit -m "docs(spec-distill): 컨텍스트 쌓기 본문의 옛 번호 · 낡은 서술 · 이유 설명을 걷고 지시를 남긴다"`(본문에 고친 선택 지적 번호 · 처분을 바꾼 원장 행). 그다음 `python3 .claude/tmp/f5-plan3/fence_diff.py "$TASK_BASE" HEAD .claude/tmp/f5-plan3/fence-allow.tsv <고친 skill · reference 파일들>` → Expected: `fence-diff: OK 0`(context-build 본문은 `ALLOWED … #<스키마 펜스>` 한 줄). 출력을 `.claude/tmp/f5-plan3/fence-task2.txt` 에 남긴다.

- [ ] **Step 8: 변이로 이빨을 본다(커밋 뒤)** — 각각 실패해야 한다: (더하기) 본문 산문에 `(C43)` · (꼴 바꾸기 — 표기) 로드맵 잡기 본문에 `G1,` 와 `v1.2.3` · (자리 바꾸기) 본문 펜스 안 주석에 `# G2` · (지우기 — 양의 짝) ⑨ 문장 · (뒤집기) ⑦ 문장의 「따로 확인한다」 를 「확인하지 않는다」 로 · (스캐너 전제) 락의 `OLD` 에서 `C43|` 를 빼면 자기 시험 열아홉이 열여덟. 통과해야 한다(양성 대조): 쉬운 말 규칙 블록 안에 `C43` · 산문에 `S12 · RC3 · OQ4 · R1` · `3-path`. 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 이 빈지. 새 테스트의 100755 를 본다.

---

### Task 3: 끝맺음 절차 (AC29 · AC30 · 「두 경우」 머리 · §6 범례 · 글 일곱 ②⑤)

**Files:**
- Modify: `plugins/spec-distill/skills/context-build/references/finishing.md` · `plugins/spec-distill/tests/test_stage_prose_trim.sh`(`NUM_FILES` 한 줄 · 과제 3 절) · `plugins/spec-distill/tests/test_end_gates.sh`(④ 의 양의 짝 한 줄) · 바꾼 문구를 무는 그 밖의 테스트

**Interfaces:**
- Consumes: 과제 2 의 락 틀(`NUM_FILES` · `has` · `lacks`).

- [ ] **Step 1: 실패하는 락을 더한다(계획이 적은 코드)** — `NUM_FILES` 에 `plugins/spec-distill/skills/context-build/references/finishing.md` 를 더하고 `finish` 앞에:

```bash
# ── 끝맺음 절차 (과제 3) ──────────────────────────────────────────────────────────────
FIN=plugins/spec-distill/skills/context-build/references/finishing.md
lacks "$FIN" '5-section' "AC29 ①: audit 를 「5-section」 이라 부르지 않는다"
has   "$FIN" 'audit 템플릿의 절 구조를 확보' "AC29 ①(양의 짝): audit 구조를 템플릿으로 가리킨다"
has   "$FIN" '`advice-list` 는 읽기 전용이다' "AC29 ⑩(양의 짝): 끝난 일 문장을 걷고도 읽기 전용 문장은 남는다"
lacks "$FIN" '두 경우에 온다' "「두 경우」 머리: B-S 로 오는 자리를 수로 적지 않는다"
has   "$FIN" 'B-S 로 오는 자리' "「두 경우」 머리(양의 짝): B-S 로 오는 자리를 이름으로 든다"
has   "$FIN" '읽어 보기까지 돈 뒤 Step B 를 B-0 부터 다시 돈다' "「두 경우」: 나눈 일 갈래 뒤에 돌아갈 자리가 있다"
lacks "$FIN" 'brief terminal' "④: 정의 없는 「terminal advisory」 가 없다"
has   "$FIN" '설계(brainstorming)로 넘기지 않는다' "글 일곱 ②: ④ 가 넘기지 않는다는 것을 로드맵 잡기 줄과 가른다"
has   "$FIN" '작업 트리 루트: <루트 절대경로>' "글 일곱 ⑤: 공백 든 경로 안내에 루트 절대경로가 나간다"
has   "$FIN" '그 상대경로에도 공백이 있으면' "글 일곱 ⑤: 상대경로 쪽 공백의 갈래가 있다"
has   "$FIN" '🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론' "§6 범례: 끝맺음 글에 표시 규칙 범례가 있다"
```

Run → Expected: FAIL.

- [ ] **Step 2: 앞 판을 적는다** — `TASK_BASE=$(git rev-parse HEAD)`.

- [ ] **Step 3: 옛 번호와 낡은 서술**
  - 머리 문단: `payload 외부 URL 금지(N1a) · §6 은 사용자 원문 S1~Sn 전부(N1b) · landscape 원자료는 audit 결속(N2)` 의 괄호 셋을 뗀다. `원문 보존은 **관례가 아니라 요구**입니다 — N1b 가` 는 `— 구조 게이트가` 로. `(고정 라운드 수 아님, G1 · 이중 종료)` → `(고정 라운드 수가 아니다 — 이중 종료)`.
  - 보기 `따로 승인할 수 있는 덩어리 3 (C1 · C4 / OQ2 · RC3 / D5)` 의 `C4` → `C2`(보기 번호가 옛 설계 번호와 같은 글자라 락이 잡는다).
  - 절 머리: `### Step A.5 — brief 리뷰 파이프라인 진입 (Law 2 분리 리뷰, v0.24.0)` 의 `, v0.24.0` · `#### B-0 — 확정 후보 제시 (게이트에 흡수, AC2)` 의 `, AC2` · `#### B-2 — 단일 `` `AskUserQuestion` `` proceed 게이트 (4옵션, AC2)` → `(선택지 넷)`.
  - `**규약의 거처 (C5).**` → `**규약의 거처.**` · `그래서 C4 재결정 프로토콜은` → `그래서 재결정 규약은` · `(NG4·P17)` 두 자리 → `(P17)` · `(NG7 — handoff는 강제가 아니라 사용자 선택)` · `*강제하지 않습니다*(NG7)` 의 `NG7` 를 뗀다.
  - Step A 1: `audit **5-section** 구조를 확보합니다` → `audit 템플릿의 절 구조를 확보합니다`.
  - `엔진의 접기 폭 · 요약 폭 상수는 R2a 의 일이다.` 를 지운다.

- [ ] **Step 4: 끝맺음의 글 고침**
  - `#### B-S — 건너뛴 것을 나중에 돌릴 때` 첫 문장 `두 경우에 온다 — …` 를 `B-S 로 오는 자리는 Step A.5 의 구조 게이트와 B-A 의 구조 게이트가 「나눈 일은 건너뛸 수 없다」 로 막았을 때, 그리고 끝 질문(B-2 · B-1)의 기타 칸에 사용자가 건너뛴 것을 하라고 적었을 때다.` 로 바꾼다. `**나눈 일이라 게이트가 막았을 때**` 갈래 끝에 `리뷰 라운드와 읽어 보기까지 돈 뒤 Step B 를 B-0 부터 다시 돈다(B-A 의 다시 짓기 · 게이트 포함).` 를 잇는다(재비판 · codex 갈래와 같은 돌아갈 자리 — 「나눈 일 멈춤 줄 뒤의 길」. 재비판 갈래의 「라운드가 끝나면 Step B 를 B-0 부터 다시 돈다」 와 글자가 겹치지 않게 써서 락이 이 갈래의 문장을 문다).
  - ④(글 일곱 ② · F4-O13): `- **④ brief만 종료**:` 항목을 `전 항목 `` `provisional` `` 유지. (나눈 일이면 Step A 8 의 위험 번호 검사 뒤) 아래 커밋 펜스(`` `context-commit` ``)를 돌리고, 결과물 경로와 확정하지 않고 끝냈다는 한 줄을 보인 뒤 끝낸다. 설계(brainstorming)로 넘기지 않는다 — 나눈 일이면 그 한 줄 뒤에 아래 「로드맵 잡기 줄 — 나눈 일」 을 낸다.` 꼴로 다시 쓴다. `test_end_gates.sh` 의 `assert_contains "$B3" 'brief terminal advisory를 내고 종료. handoff 안 함.'` 양의 짝을 새 문장의 `설계(brainstorming)로 넘기지 않는다` 로 바꾼다(그 줄 위의 부재 단언은 그대로).
  - 공백 안내(글 일곱 ⑤): `**로드맵 잡기 줄 — 나눈 일.**` 문단의 STOP 줄 `` `[spec-distill] 다음 세션 줄을 만들 수 없다 — <사유>. 결과물: <PAYLOAD 값>. …` `` 에 `작업 트리 루트: <루트 절대경로>.` 를 `결과물:` 뒤에 넣고, 문장 끝에 `그 상대경로에도 공백이 있으면 로드맵 잡기를 부를 수 없다 — 레포 설정의 의도 폴더(`` `intent_dir` ``)를 공백 없는 폴더로 바꾸라고 함께 알린다.` 를 잇는다(인라인 코드 안의 안내 글이고 펜스가 아니다).
  - §6 범례: Step A 에서 §6 앵커 줄(`- **S1** 🗣 최초 요청`)을 쓰는 규약 문장 앞에 `> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론` 과 같은 범례를 한 구절로 둔다(`§6 의 표시는 audit 템플릿의 출처 표기를 따른다 — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론.`).
  - `## 닿는 선택 지적` 의 F3b-O23(커밋 절 글)이 이 과제가 고치는 문단에 걸리면 함께 맞춘다 — 걸리지 않으면 두고 그 사실을 적는다.
  - 원장(`reasons.tsv`)의 이 파일 행을 처분대로 고친다. 이 파일과 본문의 합이 1587 을 넘지 않는다.

- [ ] **Step 5: 통과를 본다** — `test_stage_prose_trim.sh`(이제 끝맺음까지 코퍼스) · `test_end_gates.sh` · `test_conducting_interview_stage.sh` · `test_decompose_surface.sh` · `test_superpowers_presence.sh` · `test_plain_gate_templates.sh` · `test_next_session_command.sh` · `test_first_cell_finishing.sh` · `test_distortion_devices.sh` · `test_brief_verbatim_full.sh` · `test_stage_read_budget.sh` · `test_stage_words.sh`. Expected: 통과.

- [ ] **Step 6: 바꾼 문구를 무는 테스트를 맞춘다** — `git grep -n -e '5-section' -e '4옵션, AC2' -e '게이트에 흡수, AC2' -e 'v0.24.0)' -e '규약의 거처 (C5)' -e 'C4 재결정' -e 'NG4·P17' -e '두 경우에 온다' -e 'brief terminal' -e 'R2a 의 일' -- 'plugins/*/tests/*' 'shared/tests/*' 'tools/*'` 가 주석 밖에서 0 건이 되게 고친다.

- [ ] **Step 7: 커밋하고 펜스를 견준다** — `git commit -m "docs(spec-distill): 끝맺음 절차의 옛 번호 · 낡은 서술을 걷고 B-S 머리 · ④ · 공백 안내 · §6 범례를 맞춘다"`. `fence_diff.py "$TASK_BASE" HEAD - plugins/spec-distill/skills/context-build/references/finishing.md` → Expected: `fence-diff: OK 0`. 출력을 `fence-task3.txt` 에.

- [ ] **Step 8: 변이로 이빨을 본다(커밋 뒤)** — 실패해야 한다: (더하기) 머리에 `(N1b)` · (꼴 바꾸기) `(P17)` 를 `(NG4·P17)` 로 되돌림 · (지우기) 범례 문장 · (뒤집기) STOP 줄의 `작업 트리 루트:` 를 지운다 · (자리 바꾸기) `두 경우에 온다` 를 B-S 의 다른 줄에 · (지우기) 나눈 일 갈래의 돌아갈 자리 문장(재비판 갈래의 비슷한 문장이 남아도 실패해야 한다). 통과해야 한다(양성 대조): `C1 · C2 / OQ2 · RC3 / D5` 보기.

---

### Task 4: 의도 싱크 본문 · seed 기록 템플릿 (AC29 · AC30 · AC31 ①②③④⑥⑧ · 경고 표 행 이름 둘)

**Files:**
- Modify: `plugins/spec-distill/skills/intent-sync/SKILL.md` · `plugins/spec-distill/templates/interview-seed-audit-template.md`(`## 5. degrade` 의 괄호 한 곳) · `plugins/spec-distill/tests/test_stage_prose_trim.sh`(`NUM_FILES` 한 줄 · 과제 4 절) · 바꾼 문구를 무는 테스트

- [ ] **Step 1: 실패하는 락을 더한다(계획이 적은 코드)** — `NUM_FILES` 에 `plugins/spec-distill/skills/intent-sync/SKILL.md` 를 더하고:

```bash
# ── 의도 싱크 본문 · seed 기록 템플릿 (과제 4) ─────────────────────────────────────────
IS=plugins/spec-distill/skills/intent-sync/SKILL.md
SAT=plugins/spec-distill/templates/interview-seed-audit-template.md
lacks "$IS" '구조적으로 부재' "AC29 ⑤: 원장 「구조적 부재」 서술이 없다"
has   "$IS" 'Phase 0 은 degrade 원장에 쓰지 않는다' "AC29 ⑤(양의 짝): 본문이 원장을 쓰지 않는다고 말한다"
has   "$SAT" 'Phase 0 은 degrade 원장에 쓰지 않는다' "AC29 ⑤(양의 짝): 기록 템플릿이 본문과 같은 말을 한다"
assert_eq "$(grep -cx '4옵션' "$ROOT/$IS" || true)" "0" "AC29 ⑥: 끊긴 「4옵션」 줄이 없다"
has   "$IS" '게이트 앞 글에 degrade 를 **하나도 빠뜨리지 않고**' "AC29 ⑥(양의 짝): 그 뒤 지시는 남아 있다"
has   "$IS" '덜어 낸 것 표가 든 audit 은 `.claude/spec-distill/` 에 두지 않는다' "AC31 ①"
lacks "$IS" '에 두지 않는 이유는' "AC31 ①: 이유 문장 안에만 있지 않다"
has   "$IS" '`worktree.baseRef` 를 자동으로 `head` 로 바꾸지 않는다' "AC31 ②"
lacks "$IS" '로 바꾸지 않는 이유**' "AC31 ②: 이유 머리가 없다"
has   "$IS" 'seed 의 frontmatter 를 떼지 않는다' "AC31 ③"
lacks "$IS" '**frontmatter 를 떼지 않는 이유**' "AC31 ③: 이유 머리가 없다"
has   "$IS" '풀이를 고르는 질문에는 추천을 달지 않는다' "AC31 ④"
has   "$IS" '코드 블록마다 `## 상태` 블록을 앞에 이어 붙여 같은 `Bash` 호출로 돌린다' "AC31 ⑥"
has   "$IS" 'seed 냉독에는 경로를 넘기지 않는다' "AC31 ⑧"
has   "$IS" '경고 원장에 남지 않는다' "경고 표 행 이름 둘: handoff · raw-source 행이 원장 밖이라고 적는다"
```

Run → Expected: FAIL.

- [ ] **Step 2: 앞 판을 적는다** — `TASK_BASE=$(git rev-parse HEAD)`.

- [ ] **Step 3: 낡은 서술과 옛 번호**
  - ⑤ 원장: `` `framing_degradations` 원장이 구조적으로 부재하므로 이것이 유일한 채널이고`` 를 `Phase 0 은 degrade 원장에 쓰지 않는다 — 이 채널이 유일한 기록이고` 꼴로. 템플릿 `## 5. degrade` 괄호의 `` (`framing_degradations` 원장 — `brief_review_state.py degrade-append … --ledger-key framing_degradations` 로 기록한 것을 축 구분 없이 전부 그대로 직렬화한다. 원장에`` 부분을 `Phase 0 은 degrade 원장에 쓰지 않는다 — 게이트 앞 글에 실은 degrade 줄을 축 구분 없이 전부 그대로 옮긴다.` 로 맞춘다(뒤의 「워크트리 없음」 문장은 그대로). 본문이 `ledger_rc=1` 로 원장을 쓰지 않는 것은 과제 1 이 확인했다.
  - ⑥ 끊긴 줄: `4옵션` 한 글자만 있는 줄을 지운다.
  - `실측 결과는 CHANGELOG `` `[0.57.0]` `` 에 있다` 와 `헤드리스 실측(2026-09-10, 옛 인터뷰 명령)` 의 판 · 날짜를 뗀다 — 그 문장이 원장에서 `걷음` 이면 문장째 걷고, 지시가 있으면 지시만 남긴다.
  - 경고 표(설계 5 「경고 표의 행 이름 둘」): `| … | `` `handoff` · `raw-source` `` | `` `degraded` `` | …` 행이 있는 표 아래 문단(`이 skill 채널의 경고는 질문용으로 「요청 정리 경고 N개:`)에 한 구절을 잇는다 — `` `handoff` · `raw-source` 행은 경고 원장(`brief_review_state.py`)이 받는 이름 밖이라 경고 원장에 남지 않는다 — 게이트 앞 글에만 있다.`` (있는 줄에 잇는다 — 본문 줄 수를 늘리지 않는다).

- [ ] **Step 4: 지시를 살리고 이유를 걷는다** — 원장의 이 파일 행을 처분대로. 여섯 자리:
  - ① `.claude/spec-distill/` 에 두지 않는 이유는 그 자리가 정리(TTL 기본 24시간) 대상이기 때문입니다 — …` → `덜어 낸 것 표가 든 audit 은 `` `.claude/spec-distill/` `` 에 두지 않는다 — 그 자리는 정리(TTL) 대상이다.`
  - ② `**자동으로 `` `worktree.baseRef=head` `` 로 바꾸지 않는 이유** — …` 문단 → `` `worktree.baseRef` 를 자동으로 `head` 로 바꾸지 않는다 — 로컬에만 있는 커밋이 필요한지는 사용자가 정한다. 필요하면 사용자 설정 `worktree.baseRef=head` 로 바꾼다.``(실측 괄호 `v6 실측: …` 은 원장 처분대로).
  - ③ `**frontmatter 를 떼지 않는 이유**: …` → `seed 의 frontmatter 를 떼지 않는다 — `` `type:` `` 줄이 소비자가 seed 를 알아보는 유일한 표지다.`(뒤의 「`check_seed.py` 와 리뷰 번들 조립기가 본문만 보는 것은 별개 사실」 문장은 범위를 정하는지 보고 처분대로. 이 문장의 `type:` 값 글자는 계획 2 가 바꿨다 — 값을 다시 적지 않는다).
  - ④ `두 꼴 모두 추천을 달지 않는다 — 풀이는 저자가 쓴 것이라, 권하면 …` → `풀이를 고르는 질문에는 추천을 달지 않는다 — 풀이는 저자가 쓴 것이다.`(같은 꼴의 둘 — `기준 사본이 없어 저자 편집이` · `덜어 낸 것은 저자의 압축 편집이라` — 은 이미 지시 + 범위 이유라 원장 처분대로).
  - ⑥ `**실행 모양 — …**` 문단: 첫 문장을 `코드 블록마다 `` `## 상태` `` 블록을 앞에 이어 붙여 같은 `` `Bash` `` 호출로 돌린다 — 따로 돌리면 블록이 대입한 값이 넘어가지 않는다.` 로 하고, 「먼저 돌려라」/「앞에 이어 붙여라」 이유 문장은 걷는다.
  - ⑧ `경로를 넘기는 선택지는 없습니다 — …` → `seed 냉독에는 경로를 넘기지 않는다 — `` `seed-readback` `` 은 파일을 열 도구가 없다.`
  - 줄 수: `wc -l` 이 1523 을 넘지 않는다.

- [ ] **Step 5: 통과를 본다** — `test_stage_prose_trim.sh`(이제 번호 코퍼스 넷 전부 — 옛 번호 0) · `test_stage_read_budget.sh` · `test_stage_words.sh` · `test_framing_raw_source.sh` · `test_seed_inline_blob.sh` · `test_dispatch_profile_inline.sh` · `test_seed_gate_wiring.sh` · `test_seed_edit_screen.sh` · `test_framing_review_contract.sh` · `test_seed_at_path_handoff.sh` · `bash shared/tests/test_ask_recommendation.sh`. Expected: 통과.

- [ ] **Step 6: 바꾼 문구를 무는 테스트를 맞춘다** — `git grep -n -e '에 두지 않는 이유' -e '로 바꾸지 않는 이유' -e '떼지 않는 이유' -e '구조적으로 부재' -e '선택지는 없습니다' -e '쓰는 이유가 그것' -e 'framing_degradations` 원장 —' -- 'plugins/*/tests/*' 'shared/tests/*' 'tools/*'` 가 주석 밖에서 0 건이 되게 고친다. 템플릿을 무는 테스트(`test_framing_raw_source.sh` 등)는 그 괄호 글자를 무는지 본다.

- [ ] **Step 7: 커밋하고 펜스를 견준다** — `git commit -m "docs(spec-distill): 의도 싱크 본문의 낡은 서술과 이유 설명을 걷고 이유 안의 지시를 지시 문장으로 남긴다"`. `fence_diff.py "$TASK_BASE" HEAD - plugins/spec-distill/skills/intent-sync/SKILL.md plugins/spec-distill/templates/interview-seed-audit-template.md` → Expected: `fence-diff: OK 0`. 출력을 `fence-task4.txt` 에.

- [ ] **Step 8: 변이로 이빨을 본다(커밋 뒤)** — 실패해야 한다: (더하기) 본문에 `[0.57.0]` · (지우기) ⑧ 문장 · (뒤집기) ② 를 `자동으로 head 로 바꾼다` 로 · (꼴 바꾸기) 본문에 `4옵션` 줄을 되돌림 · (되돌림) ③ 이유 머리를 되살림 · (한 줄 더하기) 본문에 빈 줄 하나(`test_stage_read_budget.sh` 가 1524 로 실패). 통과해야 한다(양성 대조): 쉬운 말 규칙 블록 안의 「질문 하나에 결정 하나」 그대로.

---

### Task 5: 로드맵 잡기 (AC30 · 글 일곱 ③④)

**Files:**
- Modify: `plugins/spec-distill/skills/roadmap-draft/SKILL.md` · `skills/roadmap-draft/references/pr-merge.md`(원장 행이 있을 때만) · `plugins/spec-distill/tests/test_stage_prose_trim.sh`(과제 5 절) · `plugins/spec-distill/tests/test_decompose_surface.sh` · `plugins/spec-distill/tests/test_entry_guidance.sh`(지휘자 줄 표지 `MARK` 한 줄씩)

- [ ] **Step 1: 실패하는 락을 더한다(계획이 적은 코드)**

```bash
# ── 로드맵 잡기 (과제 5) ─────────────────────────────────────────────────────────────
RD=plugins/spec-distill/skills/roadmap-draft/SKILL.md
lacks "$RD" '**다음 세션 줄 — 분해된 일 ①/② 공통**' "글 일곱 ④: 지휘자 줄 제목이 옛 「①/② 공통」 이 아니다"
has   "$RD" '**지휘자 줄 — 로드맵 PR 이 머지된 뒤**' "글 일곱 ④(양의 짝): 지휘자 줄 제목"
has   "$RD" '경로에 공백이 있으면 새 `/spec-distill:context-build` 줄을 보이지 않고' "글 일곱 ③: 되돌아가는 길의 새 컨텍스트 쌓기 줄에 공백 가드가 있다"
```

Run → Expected: FAIL.

- [ ] **Step 2: 앞 판을 적는다** — `TASK_BASE=$(git rev-parse HEAD)`.

- [ ] **Step 3: 고친다**
  - 글 일곱 ④: 표지 `**다음 세션 줄 — 분해된 일 ①/② 공통**` → `**지휘자 줄 — 로드맵 PR 이 머지된 뒤**`(그 아래 인용 줄과 치환 문장은 그대로). `test_decompose_surface.sh` · `test_entry_guidance.sh` 의 `MARK='**다음 세션 줄 — 분해된 일 ①/② 공통**'` 를 새 표지로 바꾼다 — 둘 다 그 표지 아래 첫 줄이 지휘자 호출인지 재는 단언이라 뜻은 그대로다. 로드맵 잡기는 정본의 채택자가 아니다(정본 포인터가 없다) — `test_next_session_command.sh` 는 이 표지를 읽지 않는다(과제 1 에서 `derive_reference_adopters` 결과로 확인).
  - 글 일곱 ③: `## 되돌아가는 길` 의 둘째 갈래 끝 `(`` `/spec-distill:context-build @<결과물 절대경로>` ``)` 뒤에 `— `` `<결과물 절대경로>` `` 를 바꾸지 못하거나 경로에 공백이 있으면 새 `` `/spec-distill:context-build` `` 줄을 보이지 않고 사유와 결과물 경로를 보인다` 를 잇는다(락의 글자 `경로에 공백이 있으면 새 `/spec-distill:context-build` 줄을 보이지 않고` 가 그 문장 안에 든다).
  - 원장의 이 묶음 행을 처분대로(두 파일 모두). 번호 코퍼스에 옛 번호가 생기지 않는다(`R0` · `R1` · `P1` 은 에픽 번호 보기라 남는다).

- [ ] **Step 4: 통과를 본다 · 무는 테스트를 맞춘다** — `test_stage_prose_trim.sh` · `test_decompose_surface.sh` · `test_entry_guidance.sh` · `test_roadmap_draft_skill.sh` · `test_stage_split.sh` · `test_stage_read_budget.sh` · `test_finish_pr_merge.sh` · `test_finish_commit_roadmap.sh`. `git grep -n -F '분해된 일 ①/② 공통' -- 'plugins/*/tests/*' 'shared/tests/*' 'tools/*'` 가 0 건. Expected: 통과.

- [ ] **Step 5: 커밋하고 펜스를 견준다** — `git commit -m "docs(spec-distill): 로드맵 잡기의 지휘자 줄 제목과 되돌아가는 길의 공백 가드를 맞춘다"`. `fence_diff.py "$TASK_BASE" HEAD - plugins/spec-distill/skills/roadmap-draft/SKILL.md plugins/spec-distill/skills/roadmap-draft/references/pr-merge.md` → `fence-diff: OK 0`. 출력을 `fence-task5.txt` 에.

- [ ] **Step 6: 변이로 이빨을 본다(커밋 뒤)** — 실패해야 한다: (되돌림) 옛 표지 · (지우기) 공백 가드 구절 · (자리 바꾸기) 공백 가드를 첫 갈래의 다음 세션 줄 문단으로 옮김(그 문단에도 「경로에 공백이 있으면」 이 있어 락 글자가 다르다 — 락이 「새 `/spec-distill:context-build` 줄」 글자를 무는지 본다). 통과해야 한다(양성 대조): 첫 갈래 문단의 원래 공백 문장 그대로.

---

### Task 6: 공용 글 — 정본 · 결과물 리뷰 skill · 결과물 템플릿 · README · 의존 표

**Files:**
- Modify: `plugins/spec-distill/references/proceed-gate.md` · `plugins/spec-distill/skills/reviewing-brief/SKILL.md` · `plugins/spec-distill/templates/interview-brief-template.md` · `plugins/spec-distill/README.md` · `plugins/spec-distill/dependencies.md` · `plugins/spec-distill/tests/test_stage_prose_trim.sh`(과제 6 절) · 바꾼 문구를 무는 테스트

- [ ] **Step 1: 실패하는 락을 더한다(계획이 적은 코드)**

```bash
# ── 공용 글 (과제 6) ─────────────────────────────────────────────────────────────────
PG=plugins/spec-distill/references/proceed-gate.md
lacks "$PG" '각 skill 의 정의 블록이 그 갈래를 적는다' "글 일곱 ⑥: 정본 끝 문단이 정의 블록만 가리키지 않는다"
has   "$PG" '그 갈래만 다루는 문단' "글 일곱 ⑥(양의 짝): 갈래를 적는 자리에 문단을 든다"
lacks "$PG" 'roadmap-draft' "정본에 로드맵 잡기 skill 폴더 이름 글자가 없다(채택자 락)"
has   plugins/spec-distill/skills/reviewing-brief/SKILL.md '첫 칸 대조 · 답 표시 대조도 건너뛴다' "「검사 없이 계속」: 함께 건너뛰는 것을 말한다"
has   plugins/spec-distill/templates/interview-brief-template.md '🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론' "§6 범례: 결과물 템플릿에 표시 규칙 범례가 있다"
lacks plugins/spec-distill/README.md '확정 · 커밋까지 간 뒤' "「확정 · 커밋한 뒤 끝」: README 가 기본 선택지에만 맞는 말을 하지 않는다"
has   plugins/spec-distill/README.md '「brief만 종료」 는 확정하지 않고 커밋' "「확정 · 커밋한 뒤 끝」(양의 짝): README"
lacks plugins/spec-distill/dependencies.md '지휘자 · 로드맵 흐름은 진입에서 멈춘다' "글 일곱 ①: 로드맵 잡기도 멈추는 것처럼 읽히지 않는다"
has   plugins/spec-distill/dependencies.md '로드맵 잡기는 superpowers 없이도 돈다' "글 일곱 ①(양의 짝): 의존 표"
has   plugins/spec-distill/dependencies.md '「brief만 종료」 는 확정하지 않고 커밋' "「확정 · 커밋한 뒤 끝」(양의 짝): 의존 표"
```

Run → Expected: FAIL.

- [ ] **Step 2: 앞 판을 적는다** — `TASK_BASE=$(git rev-parse HEAD)`.

- [ ] **Step 3: 고친다**
  - 정본 끝 문단(글 일곱 ⑥): `## 다음 세션 명령` 끝 문단의 `— 각 skill 의 정의 블록이 그 갈래를 적는다.` 를 `— 그 갈래는 각 skill 이 적는다(정의 블록, 또는 컨텍스트 쌓기의 나눈 일처럼 그 갈래만 다루는 문단).` 로 바꾼다. skill 폴더 이름 글자를 쓰지 않는다. 한도 표에 행을 더하지 않는다.
  - 결과물 리뷰 skill(「검사 없이 계속」 행): `「검사 없이 계속」(얻음: 이 검사만 건너뛰고 리뷰를 바로 시작한다 · 내줌: 원문이 빠졌어도 통과하고 닫은 답의 출처 대조도 건너뛴다)` 의 내줌에 한 구절 — `첫 칸 대조 · 답 표시 대조도 건너뛴다`. 원문 완전성 검사가 그 둘을 함께 하는지는 `scripts/check_verbatim_coverage.py` 의 머리 docstring 과 검사 함수 이름으로 먼저 확인한다 — 다르면 실제로 함께 건너뛰는 검사의 이름을 쓰고 락 글자도 그에 맞춘다(보고한다). 같은 행의 「비밀값이 아니다」 쪽은 닫았다(설계 5 — 안전한 쪽).
  - 결과물 템플릿 §6 범례(설계 5 「표시 규칙 범례」): `## 6. 사용자 원문` 의 괄호 문단 뒤, `- **S1** 🗣 최초 요청:` 앞에 audit 템플릿과 같은 줄 `> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론` 을 더한다. 구조 게이트가 §6 을 읽는 방식(`check_brief.py` 의 §6 앵커 판독)이 이 줄을 앵커로 오독하지 않는지 `test_check_brief.sh` · `test_brief_verbatim_full.sh` 로 본다.
  - README · 의존 표(F4 「확정 · 커밋한 뒤 끝」 · 글 일곱 ①): README 의 superpowers 줄 `선택지 셋의 끝 질문(확정하고 끝낸다 · 확정 목록 수정 · brief만 종료)으로 확정 · 커밋까지 간 뒤 다음 단계로 넘기지 않고 끝낸다` 를 `선택지 셋의 끝 질문(확정하고 끝낸다 · 확정 목록 수정 · brief만 종료)으로 끝낸다 — 「확정하고 끝낸다」 는 확정한 뒤 커밋하고, 「brief만 종료」 는 확정하지 않고 커밋하며, 어느 쪽도 다음 단계로 넘기지 않는다` 꼴로. 의존 표 superpowers 행의 「없을 때」 칸을 같은 뜻으로 맞추고, `지휘자 · 로드맵 흐름은 진입에서 멈춘다` 를 `지휘자는 진입에서 멈춘다 — 로드맵 잡기는 superpowers 없이도 돈다(「spec 하나로」 의 다음 세션 줄만 superpowers 를 부른다)` 로 바꾼다. 로드맵 잡기가 superpowers 없이 도는지는 `scripts/roadmap_draft_entry.py` 와 `skills/roadmap-draft/SKILL.md` 진입에 superpowers 확인이 없음을 grep 으로 먼저 확인한다 — 있으면 그 사실대로 쓰고 락 글자를 맞춘다(보고한다). 의존 표의 판 칸은 고치지 않는다(`check_deps.py measure` 가 잰다). README 의 같은 뜻 줄(흐름 그림의 `superpowers 가 없으면 선택지 셋의 끝 질문 — …`)은 그대로 둬도 거짓이 아니면 둔다.

- [ ] **Step 4: 통과를 본다** — `test_stage_prose_trim.sh` · `test_proceed_gate_adopters.sh` · `test_next_session_command.sh` · `test_reviewing_brief_skill.sh` · `test_check_brief.sh` · `test_brief_verbatim_full.sh` · `test_superpowers_presence.sh` · `test_stage_words.sh` · `bash shared/tests/test_invocation_surface.sh` · `bash shared/tests/test_ask_recommendation.sh` · `python3 plugins/spec-distill/scripts/check_deps.py`(있으면 — 의존 표 꼴 검사). 바꾼 글자(`각 skill 의 정의 블록이 그 갈래를 적는다` · `확정 · 커밋까지 간 뒤` · `지휘자 · 로드맵 흐름은 진입에서 멈춘다`)를 `plugins/*/tests` · `shared/tests` · `tools` 에서 grep 해 0 건이 되게 고친다. Expected: 통과.

- [ ] **Step 5: 커밋하고 펜스를 견준다** — `git commit -m "docs(spec-distill): 정본 끝 문단 · 검사 건너뛰기 설명 · 결과물 §6 범례 · README 와 의존 표의 끝 질문 서술을 맞춘다"`. `fence_diff.py "$TASK_BASE" HEAD - <고친 다섯 파일>` → `fence-diff: OK 0`. 출력을 `fence-task6.txt` 에.

- [ ] **Step 6: 변이로 이빨을 본다(커밋 뒤)** — 실패해야 한다: (더하기) 정본 산문에 `roadmap-draft` 한 낱말(→ 이 락과 `test_proceed_gate_adopters.sh` 가 함께 실패하는지 본다) · (지우기) 템플릿 범례 줄 · (되돌림) 의존 표의 옛 칸 · (뒤집기) README 의 「확정하지 않고 커밋」 을 「확정한 뒤 커밋」 으로. 통과해야 한다(양성 대조): 정본에 「로드맵 잡기」 낱말 하나 더하기.

---

### Task 7: 철학 문서 (AC34)

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md` · `plugins/quality-gates/tests/test_governance_no_capability_caps.sh`(철학 Law 1 단언 한 줄) · `shared/tests/test_docreview_profiles.sh`(리뷰 자리 셋 단언 한 줄) · `plugins/spec-distill/tests/test_stage_prose_trim.sh`(과제 7 절)

- [ ] **Step 1: 실패하는 락을 더한다(계획이 적은 코드)**

```bash
# ── 철학 문서 (과제 7) ───────────────────────────────────────────────────────────────
PH=docs/philosophy/devbrew-harness-philosophy.md
lacks "$PH" '인터뷰 brief' "AC34: 철학 문서가 옛 단계 이름으로 결과물을 부르지 않는다"
has   "$PH" 'context brief 는 `check_brief.py` 가 구조로 막는다' "AC34(양의 짝): Law 1 의 막는 자리"
has   "$PH" '문서 리뷰 자리 셋(design doc · context brief · intent seed)' "AC34: 리뷰 자리 셋이 새 이름이다"
has   "$PH" 'skills/context-build/SKILL.md' "AC34: P2 코드 앵커가 새 skill 경로다(계획 1 — 지킨다)"
```

Run → Expected: FAIL.

- [ ] **Step 2: 앞 판을 적는다** — `TASK_BASE=$(git rev-parse HEAD)`. P8 절(`### P8 —` 부터 다음 `### ` 앞까지)을 `.claude/tmp/f5-plan3/p8-before.txt` 에 뜬다.

- [ ] **Step 3: 고친다** — Law 1 의 `인터뷰 brief 는 `` `check_brief.py` `` 가 구조로 막는다` → `context brief 는 `` `check_brief.py` `` 가 구조로 막는다` · P3 의 `문서 리뷰 자리 셋(design doc · brief · seed)` → `문서 리뷰 자리 셋(design doc · context brief · intent seed)`(README 의 엔진 라운드 낱말과 같다). 「가벼운 꼴(PR 본문의 계획 · 짧은 brief)」 의 `짧은 brief` 는 컨텍스트 쌓기의 결과물이 아니라 가벼운 설계 글이고 단계 이름이 없어 그대로 둔다 — PR 본문의 「범위 밖으로 남긴 자리」 에 그 까닭을 적는다. P8 절은 건드리지 않는다. 같은 문장을 쥔 `CLAUDE.md` 는 고치지 않는다(옆 로드맵 R2 가 예약한 파일) — 지휘자가 옆 로드맵에 알린다.
  - 무는 테스트: `test_governance_no_capability_caps.sh` 의 `assert_contains "$LAW1_P" '인터뷰 brief 는 `` `check_brief.py` `` 가 구조로 막는다'` → 새 글자(같은 파일의 `LAW1_C`(CLAUDE.md) 단언은 그대로 — `CLAUDE.md` 는 바뀌지 않는다). `test_docreview_profiles.sh` 의 `'문서 리뷰 자리 셋(design doc · brief · seed)'` → 새 글자.

- [ ] **Step 4: 통과를 본다** — `test_stage_prose_trim.sh` · `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `bash shared/tests/test_docreview_profiles.sh` · `bash shared/tests/test_charter_citations.sh` · `bash shared/tests/test_invocation_surface.sh`(철학 문서를 훑는다). P8 절을 다시 떠 `diff .claude/tmp/f5-plan3/p8-before.txt <지금>` 이 빈 출력(AC34 의 「P8 문장은 바뀌지 않았다」 — 영구 락이 아니라 이 계획의 대조다. P8 개정은 옆 로드맵 몫이라 핀으로 막지 않는다). Expected: 통과.

- [ ] **Step 5: 커밋하고 펜스를 견준다** — `git commit -m "docs(philosophy): 앞단 결과물과 리뷰 자리를 새 이름으로 부른다"`. `fence_diff.py "$TASK_BASE" HEAD - docs/philosophy/devbrew-harness-philosophy.md` → `fence-diff: OK 0`.

- [ ] **Step 6: 변이로 이빨을 본다(커밋 뒤)** — (되돌림) Law 1 의 옛 글자 → 이 락과 qg 테스트가 함께 실패 · (꼴 바꾸기) `context brief 는` 을 `context-brief 는` 으로 → 실패. 통과해야 한다(양성 대조): `짧은 brief` 그대로.

---

### Task 8: 판 · 변경 기록

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`(R5) · (과제 7 이 quality-gates 테스트를 고쳤으므로) `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md`

- [ ] **Step 1: 판을 올린다** — 두 `plugin.json` 의 `version` 을 그때 기본 브랜치의 판에서 다음 patch 로(Global Constraints 「판」). spec-distill 변경 기록 맨 위 절 `## [<판>] — <날짜>`: `Changed`(앞단 글의 옛 설계 번호 · 낡은 서술 · 이유 설명을 걷음 · 이유 안의 지시를 지시 문장으로 · 질문 경로 절 머리 `## 3-path routing` · 로드맵 잡기의 지휘자 줄 제목 · 정본 끝 문단 · README 와 의존 표의 끝 질문 서술 · 철학 문서의 앞단 이름) · `Fixed`(audit 「5-section」 · 없는 절 번호 · 끊긴 줄 · seed 기록 템플릿의 원장 서술 · ④ 의 정의 없는 안내 · 공백 든 경로 안내) · `Added`(결과물 템플릿 §6 의 출처 표기 범례 · 락 `test_stage_prose_trim.sh`). quality-gates 변경 기록: `Changed` — 철학 문서 Law 1 의 새 글자를 따라 거버넌스 테스트 한 줄.
- [ ] **Step 2: 통과를 본다** — `bash shared/tests/test_changelog_integrity.sh` · `claude plugin validate plugins/spec-distill` · `claude plugin validate plugins/quality-gates`. Expected: 통과.
- [ ] **Step 3: 커밋** — `git commit -m "chore(spec-distill,qg): 글 줄이기를 변경 기록에 적고 patch 판을 올린다"`.

---

### Task 9: 마무리 — 뒤 수 · AC37 · 펜스 대조 · 전체 스위트 · AC 보고 (AC28 · AC32 · AC37 · AC38 · 전부)

- [ ] **Step 1: 뒤 수를 잰다(AC28)** — 과제 1 의 `## 앞 수` 와 같은 네 갈래를 지금 나무에서 잰다: 줄 수(`wc -l`) · 낡은 서술(열 곳 가운데 남은 수 — 0) · 풀 수 없는 번호(`scan_ids.py` — 0) · 이유 설명(`python3 .claude/tmp/f5-plan3/reason_ledger.py count .claude/tmp/f5-plan3/reasons.tsv` 의 남음 + `git diff <기준 커밋> HEAD` 의 더한 줄 가운데 이유 · 이력 설명인 문장 수). 이유 설명의 뒤 수가 앞 수보다 작지 않으면 멈춰 보고한다. 파일마다 앞뒤 표와, 남긴 행(`남김-범위` · `남김-지시`)의 조각과 까닭을 PR 본문 재료로 `.claude/tmp/f5-plan3/pr-body.md` 에 적는다.

- [ ] **Step 2: AC37 을 견준다** — `bash plugins/spec-distill/tests/test_stage_read_budget.sh` 와 함께 세 묶음의 앞뒤 줄 수(계획 1 의 기준 1523 · 1587 · 1587, 과제 1 의 앞 수, 지금)를 PR 본문 재료에 적는다.

- [ ] **Step 3: 브랜치 전체의 펜스를 견준다(AC32)** — `python3 .claude/tmp/f5-plan3/fence_diff.py <기준 커밋> HEAD .claude/tmp/f5-plan3/fence-allow.tsv $(git diff --name-only <기준 커밋> HEAD -- 'plugins/*.md' 'docs/philosophy/*.md' 'plugins/*/templates/*')` → Expected: `fence-diff: OK 0`(허용 한 줄만 `ALLOWED`). 펜스를 뽑아 돌리는 테스트 파일의 diff 에 펜스 실행 부분(`cut_marked` · `:begin` 표지 근처)의 변경이 없는지 `git diff <기준 커밋> HEAD -- 'plugins/*/tests/*' 'shared/tests/*'` 로 본다. 결과를 PR 본문 재료에.

- [ ] **Step 4: 마지막 전체 리뷰에 AC 목록을 싣는다** — 고른 실행 방식의 마지막 전체 리뷰(SDD 의 최종 리뷰 또는 Native 의 한 번 리뷰)에 설계문서 `## Acceptance Criteria` 의 이 계획 몫(AC28 · AC29 · AC30 · AC31 · AC32 · AC34 · AC37 · AC38)을 글자 그대로 싣고, 리뷰가 AC 마다 한 줄씩 `AC28: 구현됨 — <근거>` 꼴(판정은 구현됨 · 미룸 · 빠짐 가운데 하나)로 보고하게 한다. AC37 은 이 계획 끝에서 견주는 몫만 판정한다. AC38 은 설계 5 표에서 계획 칸이 3 인 「한다」 행마다 근거를 대게 한다 — 행: 라운드 꼴 문장 둘(과제 2) · F4 작은 지적 여덟 가운데 「확정 · 커밋한 뒤 끝」 과 「두 경우」 머리(과제 6 · 3 — 락 여섯은 닿은 것만) · 철학 문서 훑기(과제 7) · §6 범례(과제 3 · 6) · 닫힘 규칙 S1(과제 2) · 「검사 없이 계속」 한 구절(과제 6) · 경고 표 행 이름 둘(과제 4) · 재기(과제 1 · 9) · 글 일곱(① 과제 6 · ② 과제 3 · ③ 과제 5 · ④ 과제 5 · ⑤ 과제 3 · ⑥ 과제 6 · ⑦ 과제 2). 리뷰에 따로 물어라 — ① 원장에서 `걷음` 인 행을 하나씩 다시 읽어 지시가 같이 빠진 자리가 있는가(Review Focus 1) ② 바꾼 절 머리 · 문구를 문 테스트가 빈 블록에서 공허하게 통과하는 자리가 있는가(Review Focus 2) ③ 과제 사이 이음매 — 과제 2 의 락 틀과 과제 3–7 이 더한 절 · `NUM_FILES` 가 끝에 네 파일을 다 갖는가 · 과제 3 의 범례 문장과 과제 6 의 템플릿 줄이 같은 글자인가. 계획이 적은 테스트 · 락 코드(과제 2–7 의 Step 1 · 과제 1 의 도구)는 「계획이 적은 코드」 라고 리뷰어에게 알린다. 보고를 git 이 추적하지 않는 파일(`.claude/tmp/f5-plan3/ac-report.md`)에 적는다.

- [ ] **Step 5: 기본 브랜치를 다시 합친다** — 과제 1 뒤 기본 브랜치가 움직였으면 `git merge --no-ff origin/<기본 브랜치>`(충돌이면 멈춰 보고). 합친 뒤 두 플러그인의 판을 다시 견준다(Global Constraints 「판」). 옆 로드맵 E4 가 머지됐으면 `skills/roadmap-draft/SKILL.md` 의 이 계획 편집이 살아 있는지 본다.

- [ ] **Step 6: 전체 스위트를 돈다** — Global Constraints 의 잠금 줄로, 마지막 리뷰와 그 고침 뒤에 한 번. 기본 브랜치와의 대조는 지휘자가 한다 — 실패 목록을 그대로 보고한다.

- [ ] **Step 7: 미룸을 올리고 대조를 돌린다** — 판정이 미룸 · 빠짐인 AC 와 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올리는 커밋을 한다(`docs(spec): …`). PR 을 만들기 전에 `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-20-front-stage-restructure-design.md .claude/tmp/f5-plan3/ac-report.md` 를 돌려 경고를 사용자에게 보인다.

- [ ] **Step 8: PR 본문 재료를 모은다** — AC28 의 앞뒤 표와 남긴 자리의 까닭 · AC37 앞뒤 · AC32 펜스 대조(허용한 펜스 하나와 그 까닭) · P8 대조 빈 출력 · 범위 밖으로 남긴 자리(컨텍스트 쌓기의 다른 reference 의 `B9` · `F3` · `C2` · `C4` · `v0.22.0` · agent 정의의 `G2` — 계획 4 몫 · 철학 문서의 `짧은 brief`) · 계획이 정한 것(질문 경로 절 머리 `## 3-path routing` · 로드맵 잡기의 지휘자 줄 제목 · ④ 의 끝 안내 한 줄 · 공백 안내의 상대경로 갈래 · B-S 머리 · S1 단서 · 아홉 지시 문장의 글자 · 펜스 하나 허용) · 옆 로드맵에 알린 파일(`dependencies.md` · `skills/roadmap-draft/` · `CHANGELOG.md` · 철학 문서와 `CLAUDE.md` 의 갈라짐) · 닿는 선택 지적(과제 1 `## 닿는 선택 지적` 가운데 고친 번호와, 닿았지만 고치지 않은 번호와 그 이유 — 마지막 보고에도 같은 목록을 싣는다) · quality-gates 판을 올린 이유(테스트 한 줄). push 와 PR 은 지휘자가 한다.

## 계획 4 에 넘길 메모

- `agents/coverage-mapper.md` 의 `G2`(세 자리)는 옛 설계 번호다 — agent 정의라 이 계획이 고치지 않았다. 계획 4 의 보안 리뷰 묶음이 같은 커밋에서 뗄 수 있다.
- 이 계획의 락 `test_stage_prose_trim.sh` 는 「끝맺음의 멈춤 안내」(계획 4 가 고칠 자리) 근처 문장을 무는 단언이 없다 — 계획 4 가 그 문단에 한 줄을 더해도 이 락은 그대로다. 단, 계획 4 가 번호 코퍼스(의도 싱크 본문 · 컨텍스트 쌓기 본문 · 끝맺음 · 로드맵 잡기)에 옛 설계 번호를 다시 들이면 이 락이 실패한다.
- 의도 싱크 본문은 AC37 기준(1523)과 거의 같은 줄 수에서 끝난다 — 계획 4 가 의도 싱크 본문에 글을 더하면 같은 커밋에서 그만큼 걷거나 있는 줄에 잇는다.
- (구현 뒤) 의도 싱크 본문은 1475 줄에서 끝났다 — 기준까지 48 줄 남는다. 컨텍스트 쌓기 본문 + 끝맺음은 1285 줄이다.
- (구현 뒤) 컨텍스트 쌓기의 다른 reference 에 남은 옛 번호(`state-file.md` 의 `B9` · `F3`, `steelman.md` 의 `C2` · `C4`, `state-migration.md` 의 `v0.22.0`)도 설계문서 `## 미룸` 에 계획 4 몫으로 올렸다 — `coverage-mapper.md` 의 `G2` 와 함께 뗄 수 있다.
- (구현 뒤) 이 계획의 락은 끝맺음 · 의도 싱크 · 컨텍스트 쌓기 본문의 시험이 글자로 무는 이유 문장 열넷을 남긴 채 끝났다 — 계획 4 가 그 문단을 고치면 그 시험들이 함께 깨진다(PR 본문의 목록).
