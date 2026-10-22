# R8 계획 3 — 쓰는 세션의 신뢰: 엔진이 스냅숏을 만든다 · 한계 공시 Implementation Plan

**실행 방식:** Subagent-driven — 사용자 선택 「Subagent-driven (권장)」(2026-10-20)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **시작 조건 — 구현은 R10 · R12 · R13 이 모두 기본 브랜치에 머지된 뒤 시작한다(사용자 결정 U10).** 구현 담당은 먼저 `origin/<기본 브랜치>` 를 merge 하고 이 계획이 인용한 파일 · 함수 · 절을 하나도 빠짐없이 새로 읽어 확인한다(Task 0). 이 계획은 설계 승인(60e21baa) 때 쓰고, R10 · R12(계획 셋) · R13 · 지휘자 수리 3(#245)이 머지된 main(6bd168d1)을 이 브랜치에 합친 트리(d0d787e8)에 맞춰 고쳤다 — 그 사이 R12 가 `shared/docreview` 와 진입 skill 셋(request-framing · reviewing-brief · spec-review)을, R13 이 같은 skill 셋을 고쳐 펜스의 상태 폴더 쓰기가 `nofollow_write.py` 를 지나고 원장 펜스가 문서가 사는 레포의 상태 루트(`state-root-for`)를 쓴다. 진입 skill 셋은 `begin-round` 를 펜스로 부르지 않고 절차서(`shared/docreview/references/reviewing-document.md` 1단계)를 따른다. 파일은 줄 번호가 아니라 함수 · 절 이름으로 가리킨다. 이 계획은 계획 1 · 2 와 파일이 겹치지 않아 그 둘과 따로 갈 수 있다(같은 에픽 브랜치를 쓰면 순서만 지킨다). 계획 2(#251)가 머지된 main(fc9cf33e)에서 다시 읽었다 — 계획 2 는 `shared/docreview` 를 고치지 않았고, 진입 skill 에 의존 확인 펜스(`check_deps.py entry`)를 더했으며(reviewing-brief 는 `## 진입 게이트` 의 첫 펜스, spec-review 는 감시줄 표 다음), 원장 열기 펜스가 `state-root-for … --ensure` 를 쓰고, spec-distill README `## 설정` 에 하위 절 셋(`### 레포 설정 파일` · `### 지원하는 흐름` · `### devbrew 밖 레포`)을 더했다. 아래 과제가 고치는 문장 · 절은 그 변경에 닿지 않는다.

**Goal:** 리뷰 엔진의 `begin-round` 가 호출자에게 스냅숏을 받지 않고 원장에 적힌 문서에서 직접 계산해 위조 인자 · 정직한 실수가 들어올 길을 없애고, 쓰는 세션을 믿는 한계를 리뷰 결과 머리와 README 「한계」 절에 같은 문장으로 알린다.

**Architecture:** `docreview_anchor.py` 의 문서 판독(`parse_sections` 와 보조)을 엔진 `docreview_state.py` 로 옮기고(앵커 모듈은 그것을 가져다 쓴다 — 지금도 앵커가 엔진을 import 하는 방향이다), `cmd_begin_round` 가 `st["doc"]` 을 읽어 스냅숏을 만든다. `--snapshot` 인자를 지우고 진입 skill · reference · 테스트 · 픽스처의 호출을 모두 바꾼다(호환 없음). 공시 문장 하나를 엔진 상수로 두고 `render_gate` 머리와 README 가 같은 글을 쓴다.

**Tech Stack:** Python 3(표준 라이브러리 + PyYAML — 엔진의 기존 의존), bash 3.2 호환 셸, `shared/tests/assert.sh`, `python3 -m unittest`.

**Spec:** `docs/superpowers/specs/2026-10-20-dependency-portability-design.md` (§7 · §8 · Metadata 의 Deferred to plan 첫 항목 · AC25 · AC26 · AC28)

## Global Constraints

- **시작 시점.** R10 · R12 · R13 머지 뒤. 브랜치 `feature/writer-trust`(로드맵 R8 의 셋째 브랜치 — 계획 2 머지 뒤 기본 브랜치에서 새로 만든다). 시작 때 기본 브랜치를 merge 한다(rebase 금지). 커밋은 pathspec, `git stash` 금지, HEAD 를 뒤로 옮기지 않는다.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 와 세션이 주는 `Claude-Session` 줄.
- **버전.** 판 번호는 이 계획에 적지 않는다 — 지휘자가 구현 dispatch 때 정해 준다. 올리는 플러그인은 엔진 파일이 심볼릭 링크로 들어 있는 것(d0d787e8 · fc9cf33e 기준 spec-distill · quality-gates — `git ls-files -s plugins/*/scripts/docreview_state.py` 의 120000 으로 센다). CHANGELOG 머리는 plugin.json 과 같게.
- **세 skill 폴더 펜스의 상태 폴더 쓰기는 `nofollow_write.py` 로.** request-framing · reviewing-brief · spec-review 의 `.md` 펜스에서 상태 폴더에 쓰는 줄은 `"$<루트>/scripts/nofollow_write.py" run|empty|append --out …` 를 지나고, writer 를 부르는 루트 변수는 그 펜스가 다른 스크립트를 부르는 루트 변수와 같다. 집행은 `plugins/spec-distill/tests/test_state_dir_writes.sh`(`scan_writes`) — 그 폴더의 문면 · 펜스를 고치는 과제는 이 테스트를 Test 목록에 둔다. 스냅숏 파일을 쓰던 절차서의 `> snap.json` 줄은 되살리지 않는다.
- **펜스 사이 변수 나르기 금지.** 한 bash 펜스는 앞 펜스에서만 정의된 변수를 쓰지 않는다. `finishing.md` 와 `references/redecompose.md` 둘 다 `plugins/spec-distill/tests/test_finishing_block_scope.py` 가 잰다 — 두 파일의 펜스를 고치면 이 테스트를 돌린다.
- 호환을 두지 않는다(U2) — `--snapshot` 을 받는 길을 남기지 않는다. 넘기면 argparse 의 「모르는 인자」 rc 2 다.
- 같은 세션이 원장을 쓰고 원장의 제약을 받는다는 한계를 레포 안 장치(샌드박스 · 훅 출처 기록 · 별도 프로세스)로 막지 않는다(§7 · U5). 인용마다 「출처 미확인」 라벨을 달지 않는다.
- 공시 문장은 글자 그대로: 「사용자 문구와 원장은 이 세션이 쓴 것이다 — 엔진은 엔진 밖에서 고친 원장 중 요약값이 안 맞는 것만 잡는다」.
- 셸은 macOS bash 3.2 · zsh 호환. 스크립트 파일 읽기는 `encoding="utf-8"`, 인라인 python 은 `python3 -I`. 새 셸 테스트는 `chmod +x` 후 `100755`.
- 사람에게 보이는 새 문면은 `shared/style/plain-language.md`(첫 줄 상태 · 끝에 할 일 하나). 모델이 읽는 reference · skill 문면에는 출처 · 배경 · 정당화를 쓰지 않는다.
- 락은 변이로 이빨을 확인하고 음의 락에는 양의 짝. 변이 전에 커밋하고 복원은 `git checkout HEAD --` + `git diff HEAD`. `PYTHONDONTWRITEBYTECODE=1`(같은 길이 변이의 stale `.pyc`).

## 설계와 다른 점 · 설계에 없던 결정

1. **문서 판독을 엔진으로 옮긴다.** `docreview_anchor.py` 가 맨 위에서 `docreview_state` 를 import 하므로, 엔진이 앵커를 import 하면 순환이 생기고 엔진을 스크립트로 돌릴 때(`__main__`) 엔진 모듈이 두 벌 올라 예외 클래스의 정체가 갈린다. 그래서 `parse_sections` · `HEADING_RE` · `FENCE_RE` · `PREAMBLE` · `_after_frontmatter` 를 엔진으로 옮기고 앵커의 `snapshot_of` · `cmd_snapshot` 은 그대로 둔 채 엔진의 것을 가져다 쓴다. `docreview_anchor.py snapshot` 명령의 출력은 바이트까지 같다.
2. **원장의 문서를 읽지 못하면** `begin-round` 는 원장을 바꾸기 전에 `doc_unreadable`(없음 · 링크 · UTF-8 아님) rc 2 로 멈춘다 — 지금 「스냅숏 파일을 못 읽음」 자리.
3. **설계 Deferred to plan 의 `--snapshot` 호출자 목록은 d0d787e8 에서 열세 파일이다**(설계가 센 열 개 + 절차 reference `shared/docreview/references/reviewing-document.md` + R13 이 더한 둘 — fc9cf33e 에서 다시 세어도 같은 열세 파일이다): `plugins/spec-distill/tests/` 의 `test_framing_review_contract.sh` · `test_ledger_wiring.sh` · `test_reviewing_brief_residue.sh` · `test_reviewing_spec_residue.sh` · `test_seed_review_log.sh` · `test_seed_review_profile.sh` · `test_state_storage_e2e.sh` · `test_state_dir_writes.sh`(원장 링크 거절 세 사례 — 살아 있는 링크 · 하드 링크 · 쓰기 불가 폴더) · `test_ledger_root.sh`(`open_round`), `shared/tests/fixtures/docreview/cases.sh`(`begin-round` 줄 80 — `--snapshot` 이 든 줄 88 가운데 여덟은 `docreview_anchor.py protected --snapshot` 이라 그대로 둔다) · `cases_advice.sh`, `shared/tests/test_docreview_gate_visibility.sh`, `shared/docreview/references/reviewing-document.md`. 스냅숏 파일 이름(`snap.json`)에 기대는 락이 하나 더 있다 — `shared/tests/test_docreview_procedure_paths.sh` 의 산출자 축이 절차서의 `*.json` 이름을 도출하고 `snap.json` 을 카나리아로 쓴다. 진입 skill 셋은 `begin-round` 를 펜스로 부르지 않지만, reviewing-brief · spec-review 의 「선결의 `init` 이 rc 0 이 아니면 …」 문단과 절차서 `reviewing-document.md` 의 선결 문단(「**`init` 의 rc 가 0 이 아니면 …**」)이 「`begin-round` 는 문서를 보지 않으므로」에 기댄다 — 엔진이 원장의 문서를 읽게 되어도 호출자의 문서와 대조하지는 않으므로 결론은 같고, 세 곳의 문장만 「`begin-round` 는 원장에 적힌 문서만 읽으므로」로 맞춘다.
4. **공시 줄의 자리는 `render_gate` 출력의 셋째 줄** — 행 묶음(`GATE_ROWS`)보다 앞이라 설계 §7 의 「리뷰 결과 머리」다. 첫 줄은 상태(쉬운 말 규칙)이고 둘째 줄은 이미 재리뷰 · 설정 줄(`재리뷰 N/M회 썼다(상한 …) · …`)이다 — 절차서 · 진입 skill 여섯 자리(`reviewing-document.md` 3단계 · spec-review 의 재리뷰 상한 · fan-out 규모 · 게이트 줄 설명 · reviewing-brief 의 재리뷰 상한 · request-framing 의 탐지 수)가 「게이트 둘째 줄이 알린다」로 그 줄을 가리키고 `cases.sh` 의 `--render | sed -n 2p` 단언 일곱이 그 줄을 잰다. 그래서 둘째 줄은 옮기지 않는다(Task 0 이 fc9cf33e 에서 찾은 어긋남 — 처음 판은 둘째 줄이었다). JSON `gate` 출력에는 키 `writer_trust_notice` 로 같은 글을 싣는다(기계 소비자가 사람 글을 파싱하지 않게).

## Review Focus

1. **리뷰 도중 사용자가 설계문서를 다른 경로로 옮겼다.** 사람은 엔진이 옛 경로의 빈 스냅숏으로 라운드를 시작하는 대신 원장을 건드리지 않고 「원장의 문서를 읽지 못했다 — <경로>」로 멈추길 기대한다. Task 1 의 `test_begin_round_doc_missing_keeps_ledger` 가 잠근다.
2. **헤딩이 없는 seed 를 리뷰한다(request-framing).** 사람은 엔진이 만든 스냅숏이 지금 호출자가 만들던 것과 같아(머리 없음 표지 포함) 얼림 · 면제 판정이 바뀌지 않길 기대한다. Task 1 의 seed 사례가 잠근다.
3. **옛 판 절차를 기억한 세션이 `--snapshot` 을 넘긴다.** 사람은 조용히 무시되는 대신 rc 2 와 「모르는 인자」를 보고 진입 skill 의 새 절차를 따르길 기대한다. Task 1 의 사례가 잠근다.
4. **`begin-round` 와 `finalize` 사이에 문서가 고쳐졌다.** 사람은 지금과 같이 라운드 스냅숏이 `begin-round` 시점의 문서이고 그 뒤 편집은 다음 라운드의 diff 로 보이길 기대한다. Task 1 의 사례가 잠근다.
5. **게이트 글을 기계가 읽는 소비자(진입 skill 의 게이트 행 판독)가 셋째 줄의 새 공시를 행으로 오독하거나, 둘째 줄을 재리뷰 줄로 읽던 소비자가 밀린 줄을 읽는다.** 사람은 게이트 행 수 · 선택지와 둘째 줄의 재리뷰 줄이 바뀌지 않길 기대한다. Task 2 의 `gate-rows` 사례와 골든 테스트가 잠근다.
6. **불변 절(결정 기록)에 새 항목 하나만 더하고 다음 라운드를 연다.** 사람은 엔진이 스냅숏을 만들게 된 뒤에도 「새 항목만 추가」로 읽혀 얼림 위반으로 막히지 않길 기대한다. Task 1 의 `test_item_marks_carried` 가 잠근다.

## 넘김 대조 — 이 계획이 받는 것

전체 표는 계획 1 `## 넘김 대조`. 이 계획 몫:

| 넘김 | 받는 과제 |
|---|---|
| R12 계획 1 통합 리뷰 — 스냅숏 동치 칸에 `item_marks` | Task 1(동치 사례 · `test_item_marks_carried` · 변이) |
| R13 — `--snapshot` 호출자에 `test_state_dir_writes.sh` 세 사례 · 절차서 `> snap.json` 줄을 되살리지 않는다 | 「설계와 다른 점 3」 · Task 0 Step 4 · Task 1 Step 4 |
| R13 — README 한계 불릿(P21 · P14)을 `## 한계` 절에 합치고 `test_state_dir_writes.sh` 끝 README 락을 맞춘다 | Task 2 |
| R13 설계 `## 미룸` 두 행(Write 도구 쓰기 링크 · 실행 중 다시 심는 링크와 `runner_common.sh` 두 함수) | 설계 U13 — §7 공시로 받음. Task 2(README `## 한계` 의 P21 불릿 · 두 행에 끝냄) |
| R12 설계 `## 미룸` R8 행 둘(`declare-related` · `log-decision` 의 표지 없는 호출 · 엔진 명령 밖 원장 쓰기) | 설계 U14 — §7 공시로 받음. Task 2(README `## 한계` 의 공시 문장 · 두 행에 끝냄) |
| R12 설계 `## 미룸` R8 행 — 보호 절 제목 바꿈 정체 추적(후보) | 설계 U15 — 받지 않음. Task 2(그 행에 「R8 받지 않음」) |
| PR #243 미룸 — `--optional` 을 묶지 않아 「선택 N」 칸이 낮아질 수 있음 | 설계 U16 — qg README 한계 한 줄. Task 2(코드 없음) |

---

### Task 0: 머지 뒤 다시 읽기 · 호출자 다시 세기 · 기준선

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r8-plan3/baseline.sh` (레포 밖)
- Modify: 이 계획 파일

- [ ] **Step 1: 시작 조건.** R10 · R12 · R13 의 PR 이 MERGED 인지 확인한다. 아니면 멈추고 지휘 세션에 보고한다.
- [ ] **Step 2: `git merge --no-edit origin/<기본 브랜치>`.**
- [ ] **Step 3: 다시 읽는다.** `shared/docreview/scripts/docreview_state.py` 의 `cmd_begin_round`(라운드 스냅숏 행에 옮기는 칸 — 불변 절의 `item_marks` 포함) · `snapshot_problem` · `_snapshot_ok` · 「추가만」 판정 함수(`item_marks` 를 읽는 자리) · `render_gate` · `cmd_gate` · `cmd_gate_rows` · 하위 명령 등록부(`P("begin-round")`), `docreview_anchor.py` 의 `parse_sections`(절마다 `item_marks` 를 낸다) · `snapshot_of` · `cmd_snapshot` · `cmd_diff`(`item_marks` 를 뺀다) · `cmd_protected`, `shared/docreview/references/reviewing-document.md` 의 「선결」 · 1단계, 진입 skill 셋(request-framing · reviewing-brief · spec-review)의 라운드 절차 중 스냅숏 · `begin-round` 를 말하는 자리(reviewing-brief · spec-review 의 「선결의 `init` 이 rc 0 이 아니면」 문단), `plugins/spec-distill/README.md` 의 절 목록과 `### Principles 흡수` 의 한계 불릿 둘(P21 상태 폴더 쓰기의 링크 · P14 원장 정리의 뿌리), 락 `plugins/spec-distill/tests/test_state_dir_writes.sh`(원장 링크 거절 세 사례 · 끝의 README 한계 문장 단언) · `shared/tests/test_docreview_procedure_paths.sh`(산출자 축의 `*.json` 이름 도출 · `snap.json` 카나리아), 설계 밖 넘김 — R12 설계(`2026-10-20-review-engine-leftovers-design.md`) `## 미룸` 의 R8 행 셋 · R13 설계(`2026-10-21-interview-gate-leftovers-design.md`) `## 미룸` 의 R8 행 둘.
- [ ] **Step 4: 호출자를 다시 센다.** `git grep -n -e 'begin-round' -- plugins shared ':!*CHANGELOG*' | grep -e '--snapshot'` 와 `git grep -n -e 'snap.json' -e 'docreview_anchor.py" snapshot' -e 'docreview_anchor.py snapshot' -e 'ANCHOR" snapshot' -- plugins shared ':!*CHANGELOG*'`. Expected: 「설계와 다른 점 3」의 열세 파일 + `test_docreview_procedure_paths.sh`. 더 있으면 Task 1 Files 목록에 더한다. `cmd_protected` 의 `--snapshot` 은 begin-round 가 아니라 그대로 둔다.
- [ ] **Step 5: 기준 스위트.** 계획 1 Task 0 Step 5 와 같은 `baseline.sh` 를 `$HOME/.claude/sdd-mirror/r8-plan3/` 에 두고 `before` 를 잰다.

---

### Task 1: `begin-round` 가 원장의 문서에서 스냅숏을 만든다 (AC25)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`parse_sections` 와 보조를 받음 · `cmd_begin_round` · 하위 명령 등록부의 `--snapshot` 지움), `shared/docreview/scripts/docreview_anchor.py` (옮긴 이름을 엔진에서 import), `shared/docreview/references/reviewing-document.md` (1단계 — `docreview_anchor.py snapshot <doc> > snap.json` 줄을 지우고 `begin-round --state-dir D` 만 · 선결 문단의 「`begin-round` 는 문서를 보지 않으므로」 문장), `plugins/spec-distill/skills/reviewing-brief/SKILL.md` · `skills/spec-review/SKILL.md` (「`begin-round` 는 문서를 보지 않으므로」 문장 — 「설계와 다른 점 3」), Task 0 Step 4 의 테스트 · 픽스처 전부 — 그중 `test_state_dir_writes.sh` 의 원장 링크 거절 세 사례(`ds_save_symlink_refused` 의 살아 있는 링크 · `ds_save_hardlink_refused` · `ds_inplace_ro_dir_kept`)는 `snapshot > s1.json` 줄을 지우고 새 꼴로, `test_docreview_procedure_paths.sh` 는 카나리아를 절차서에 남는 이름 `prep.json` · `fin.json` 으로 바꾸고 하한을 2 로(fc9cf33e 의 절차서 이름은 `fin.json` · `prep.json` · `snap.json` 셋이다). `cases.sh` 는 한 번의 치환으로 끝나지 않는다 — 라운드 도우미(`mk_state` · `r1` · `next_round` · `br`)와 그것을 쓰지 않는 사례가 라운드마다 init 과 다른 문서를 스냅숏으로 넘긴다(`next_round "$d" "$FX/design-sample-r2.md"` 24번 · `br "$d" "$FX/brief-append-r1.md"` 등). 엔진이 `st["doc"]` 을 읽으므로 원장의 문서는 도우미가 가진 사본이어야 하고(공유 픽스처 `$FX/…` 를 덮어쓰지 않는다 — `mk_doc_state` 꼴), 라운드를 열기 전에 그 라운드의 문서를 원장의 문서 자리에 옮긴다. 도우미는 `s<n>.json` 을 `docreview_anchor.py snapshot` 으로 계속 만든다 — `next_round` 의 `docreview_anchor.py diff` 와 `protected --snapshot` 여덟 줄이 그 파일을 읽는다. 위조 스냅숏 사례 둘(`snap_edit` 로 줄 해시를 떼고 `snapshot_invalid` 를 기대하는 `case_AC38_r4_snapshot_fields_cannot_switch_guards_off` 와 AC9 불변 사례의 라운드 4 `s4.json`)은 호출자가 스냅숏을 낼 길이 없어지므로 `snapshot_problem` 을 직접 부르는 단언으로 옮기고 원장 위조 절반은 그대로 둔다. 골든(`shared/tests/fixtures/docreview/golden/*.state.md`)의 `doc:` 줄은 원장의 문서가 상태 폴더 사본으로 옮겨 가면 바뀐다 — `capture_finalize_golden.sh` 는 `$REPO_ROOT` 만 자리표로 바꾸므로 그 사본 경로도 자리표로 바꾸게 고치고, 다시 뜬 골든의 차이가 `doc:` 줄뿐인지 `diff` 로 본다
- Test: `shared/tests/test_docreview_state.sh`, `shared/tests/test_docreview_anchor.sh`, `shared/tests/test_docreview_procedure_paths.sh`, `plugins/spec-distill/tests/test_state_dir_writes.sh`, `plugins/spec-distill/tests/test_ledger_root.sh`, `plugins/spec-distill/tests/test_begin_round_snapshot.sh` (새)

**Interfaces:**
- Produces:
  - `docreview_state.parse_sections(text: str, keep_body: bool = False) -> dict` — 옮긴 함수, 동작 같음.
  - `begin-round --state-dir D [--extra-approval Q --extra-approval-source label|typed] [--detectors …]` — `--snapshot` 없음. 스냅숏 = `parse_sections(Path(st["doc"]).read_text(encoding="utf-8"))` 에 `snap["doc"] = st["doc"]`. 그 뒤의 `snapshot_problem` 검사 · 원장 저장은 지금 그대로.
  - 실패: 문서를 못 읽으면 `fail("doc_unreadable", doc=…, why=…)` rc 2, 원장 불변.
- 호출 꼴(절차 · skill · 테스트): `python3 "<엔진>/docreview_state.py" begin-round --state-dir "$D"` — 앞에 있던 `docreview_anchor.py snapshot <doc> > snap.json` 줄을 지운다.

- [ ] **Step 1: 실패하는 테스트**(`test_begin_round_snapshot.sh` — 임시 문서 · 원장):
  - `test_engine_snapshot_equals_anchor_snapshot`: 설계문서 픽스처로 `init` → `begin-round` 뒤 원장의 라운드 1 스냅숏 == 같은 문서의 `docreview_anchor.py snapshot` 출력에서 원장에 싣는 칸(`anchor` · `title` · `level` · `hash` · `parents` · 울타리 절의 `line_hashes` · 불변 절의 `item_marks` — 「새 항목만 추가」 판정이 기댄다) — 바이트 비교. 픽스처에는 `- ` 항목 줄과 아닌 줄이 섞인 불변 절(결정 기록 · 미룸 꼴)이 하나 있어 `item_marks` 가 `0` · `1` 을 둘 다 갖는다(공허 비교 방지).
  - `test_seed_headingless`: 헤딩 없는 seed 픽스처 → 원장의 `headingless: true` 와 절 하나(`DOC_ANCHOR`).
  - `test_snapshot_flag_is_refused`: `--snapshot x.json` → rc 2 · 원장 `round` 그대로.
  - `test_begin_round_doc_missing_keeps_ledger`: `init` 뒤 문서를 지움 → rc 2 · `doc_unreadable` · 원장 바이트 불변.
  - `test_edit_after_begin_round_shows_next_round`: 라운드 1 시작 → 문서 한 절 고침 → 라운드 2 시작 → 얼림 diff(`docreview_route.py finalize` 경로의 기존 함수)가 그 절을 바뀐 것으로 본다.
  - 음의 락 + 양의 짝: Task 0 Step 4 의 파일 전부에 `begin-round` 줄과 `--snapshot` 이 같은 호출에 없다 · `reviewing-document.md` 에 `begin-round --state-dir` 가 있고 `> snap.json` 줄이 없다(되살리지 않는다) · reviewing-brief · spec-review · `reviewing-document.md` 에 「문서를 보지 않으므로」가 없고 새 문장이 있다.
  - `test_item_marks_carried`: 불변 절에 `- ` 항목 하나를 더한 문서로 라운드 2 를 열면 엔진이 만든 스냅숏의 `item_marks` 가 늘어난 표시를 갖고, 「새 항목만 추가」 판정이 지금(호출자 스냅숏)과 같은 답을 낸다.
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_begin_round_snapshot.sh` — Expected: `✗`(지금은 `--snapshot` 이 필수).
- [ ] **Step 3: 엔진을 고친다.** 판독을 옮기고 `cmd_begin_round` 의 `json.loads(Path(a.snapshot)…)` 자리를 위 계산으로. `docreview_anchor.py` 는 옮긴 이름을 `from docreview_state import …` 목록에 더한다.
- [ ] **Step 4: 호출자를 고친다.** Task 0 Step 4 목록 전부 — 픽스처 `cases.sh` 의 `begin-round … --snapshot` 80줄(`protected --snapshot` 여덟 줄은 그대로)은 먼저 `grep -c` 로 세고, Files 의 도우미 · 사례 고침 뒤 `begin-round` 줄 수가 그대로이고 그중 `--snapshot` 이 0 인지 다시 센다(줄 경계가 다른 호출이 남지 않게). `test_state_dir_writes.sh` 의 세 사례는 「원장이 링크면 거절 · 쓰기 불가 폴더 안 원장은 갱신」을 그대로 재는지 변이로 본다 — 엔진의 링크 거절(`ledger_not_plain_file`)을 지우면 두 링크 사례가 RED, 되돌리면 GREEN.
- [ ] **Step 5: 통과를 본다.** Run: `bash plugins/spec-distill/tests/test_begin_round_snapshot.sh && bash shared/tests/test_docreview_state.sh && bash shared/tests/test_docreview_anchor.sh && bash shared/tests/test_docreview_golden.sh && bash shared/tests/test_docreview_mutations.sh && bash shared/tests/test_docreview_procedure_paths.sh && bash plugins/spec-distill/tests/test_state_dir_writes.sh && bash plugins/spec-distill/tests/test_ledger_root.sh` + Task 0 Step 4 의 테스트 파일 전부 — Expected: `✗` 0.
- [ ] **Step 6: 변이**: 엔진이 문서 대신 빈 스냅숏(`{"headingless": False, "sections": []}`)을 쓰게 → 첫 사례 RED · 원장에 옮기는 칸에서 `item_marks` 를 뺌 → `test_item_marks_carried` 와 동치 사례 RED · `doc_unreadable` 검사를 원장 저장 뒤로 → 원장 불변 사례 RED · `--snapshot` 을 받아 무시하게 되살림 → 거부 사례 RED.
- [ ] **Step 7: 커밋** — `fix(docreview): begin-round 가 원장의 문서에서 스냅숏을 직접 만든다`

---

### Task 2: 한계 공시 — 리뷰 결과 머리 · README 「한계」 (AC26)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (상수 `WRITER_TRUST_NOTICE` · `render_gate` 셋째 줄(재리뷰 줄 바로 다음 — 「설계와 다른 점 4」) · `cmd_gate` JSON 의 `writer_trust_notice`), `plugins/spec-distill/README.md` (새 `## 한계` 절 · `### Principles 흡수` 의 한계 불릿 둘을 그 절로 옮김), 골든 기대 파일(`shared/tests/test_docreview_golden.sh` 가 읽는 것), `plugins/spec-distill/tests/test_state_dir_writes.sh` (끝의 README 한계 문장 단언을 `## 한계` 절 안으로 좁힘), `plugins/quality-gates/README.md` (`## 한계` 에 한 줄 — U16), 넘김 표 — R13 설계(`2026-10-21-interview-gate-leftovers-design.md`) `## 미룸` 의 R8 행 둘 · R12 설계(`2026-10-20-review-engine-leftovers-design.md`) `## 미룸` 의 엔진 밖 원장 쓰기 두 행(U13 · U14)의 이유 칸 끝에 `끝냄 — <커밋 8자>(R8)`, R12 의 보호 절 제목 바꿈 정체 추적 행(U15)의 이유 칸 끝에 `R8 받지 않음 — 좁힌 대로 둠(U5)`(꼴은 9c2e4ec3 의 「끝냄 — <sha>(R13)」와 같다). PR #243 의 넘김은 표가 없어 PR 본문 `## 지휘자에게` 에 「U16 으로 qg README 한계 한 줄」을 적는다.
- Test: `shared/tests/test_docreview_gate_plain.sh`, `shared/tests/test_writer_trust_notice.sh` (새), `plugins/spec-distill/tests/test_state_dir_writes.sh`, `plugins/quality-gates/tests/test_verdict_no_reread.sh` (`case_readme_limits` 가 qg README `## 한계` 절을 읽는다), `plugins/spec-distill/tests/test_readme_sync.sh` (`### Principles 흡수` 절을 뽑아 잰다)

**Interfaces:**
- Produces: `WRITER_TRUST_NOTICE = "사용자 문구와 원장은 이 세션이 쓴 것이다 — 엔진은 엔진 밖에서 고친 원장 중 요약값이 안 맞는 것만 잡는다"`.
- README `## 한계` 절(`## 끄는 법` 다음 · `## Prerequisites` 앞. `## 설정` 의 `### devbrew 밖 레포` 불릿은 옮기지 않는다): 첫 줄은 위 문장 그대로, 다음 줄 「샌드박스를 쓰는 사용자는 원장 폴더(상태 폴더의 `.docreview/`) 쓰기를 막을 수 있다 — 막아도 엔진 명령은 같은 폴더를 쓰므로 엔진도 함께 막힌다」(안내만). `--quote-file` · `log-decision --quote` · `decide --quote` 출처와 제목 하나 빠진 audit 은 이 공시로 다룬다는 한 줄. 그 아래에 지금 `### Principles 흡수` 에 있는 한계 불릿 둘(「한계 — 상태 폴더 쓰기의 링크 (P21)」 · 「한계 — 원장 정리의 뿌리 (P14)」)을 글 그대로 옮긴다 — `### Principles 흡수` 에는 그 둘 대신 「한계는 `## 한계` 절」 한 줄. 그 절에 한 줄 더 — 「`declare-related` · `log-decision` 이 표지 확인 없이 불리거나 엔진 명령을 거치지 않고 원장을 쓰는 길도 위 공시로 다룬다 — 엔진은 그런 쓰기를 거부하지 않는다」(U14, 장치 없음). R13 두 행(U13)은 옮긴 P21 불릿이 그대로 공시한다.
- quality-gates README `## 한계` 에 한 줄(U16): 「판정 줄의 「선택 N」 칸은 합성기가 낸 인자를 묶지 않고 옮긴다 — 같은 세션이 낮춰 적을 수 있다. 판정값(통과 · 막음)은 이 칸에 기대지 않는다」. 코드는 바꾸지 않는다.

- [ ] **Step 1: 실패하는 테스트**(`test_writer_trust_notice.sh`): `render_gate` 출력의 셋째 줄 == `WRITER_TRUST_NOTICE` · 둘째 줄은 그대로 `재리뷰 ` 로 시작한다(양의 짝 — `cases.sh` 의 `sed -n 2p` 단언 일곱도 그대로 GREEN) · README `## 한계` 절에 같은 문장이 글자 그대로 있다(엔진 상수에서 읽어 비교 — 두 글이 어긋나면 RED) · README `## 한계` 절에 P21 · P14 한계 불릿이 있고 `### Principles 흡수` 에는 없다(옮김 — 양 · 음 짝) · `gate` JSON 에 `writer_trust_notice` · 인용 라벨 음의 락: 엔진 출력 · 진입 skill 셋에 「출처 미확인」 낱말이 없다 — 양의 짝: 공시 문장은 있다. `gate-rows` 출력의 행 수가 공시 전과 같다(Review Focus 5). README `## 한계` 에 U14 줄이 있다 · quality-gates README `## 한계` 에 「선택 N」 줄이 있다(U16 — 양의 단언만, 글 바꿈 변이로 RED 확인). `test_state_dir_writes.sh` 끝의 README 단언(「Write 도구로 쓰는 상태 폴더 파일(… )은 writer 로 감싸지 못하고」)은 README 전체가 아니라 `## 한계` 절 본문에서 찾게 좁힌다.
- [ ] **Step 2: 실패를 본다.** Run: `bash shared/tests/test_writer_trust_notice.sh; bash plugins/spec-distill/tests/test_state_dir_writes.sh` — Expected: `✗`.
- [ ] **Step 3: 구현.** 골든 기대 파일(`golden/*.gate.txt` · `*.gate.json`)은 셋째 줄 하나(JSON 은 키 하나)만 더해진 차이인지 `diff` 로 확인한 뒤 고친다. README 두 곳을 쓴 커밋의 8자로 넘김 표 다섯 행에 끝냄 넷 · 받지 않음 하나를 적는다(Files 의 꼴).
- [ ] **Step 4: 통과를 본다.** Run: `bash shared/tests/test_writer_trust_notice.sh && bash shared/tests/test_docreview_gate_plain.sh && bash shared/tests/test_docreview_golden.sh && bash shared/tests/test_docreview_gate_visibility.sh && bash plugins/spec-distill/tests/test_state_dir_writes.sh && bash plugins/quality-gates/tests/test_verdict_no_reread.sh && bash plugins/spec-distill/tests/test_readme_sync.sh && bash shared/tests/test_docreview_route.sh` — Expected: `✗` 0.
- [ ] **Step 5: 변이**: README 문장에서 한 글자를 바꿈 → RED · 공시 줄을 마지막 줄로 옮김 → RED · 공시 줄을 둘째 줄로(재리뷰 줄 앞으로) 옮김 → RED · P21 불릿을 `### Principles 흡수` 로 되돌림 → 옮김 사례와 `test_state_dir_writes.sh` 의 좁힌 단언 RED.
- [ ] **Step 6: 커밋** — `docs(docreview): 쓰는 세션을 믿는 한계를 리뷰 결과 머리와 README 에 같은 문장으로`

---

### Task 3: 문서 · 버전 · 스위트 대조 (AC28 마감)

**Files:**
- Modify: 엔진 링크를 가진 플러그인의 `CHANGELOG.md` · `.claude-plugin/plugin.json`, `plugins/spec-distill/README.md` (Principles Instantiated 한 줄)

- [ ] **Step 1: 판 · CHANGELOG.** 엔진 링크를 가진 플러그인마다 판 올림(번호는 지휘자가 구현 dispatch 때 준 것). spec-distill CHANGELOG — Changed(「`begin-round` 는 이제 `--snapshot` 을 받지 않는다 — 원장의 문서에서 스냅숏을 만든다」) · Added(한계 공시). Principles Instantiated 에 「Law 2 — 쓰는 세션을 믿는 한계를 공시한다(장치로 막지 않는다)」. Run: `bash shared/tests/test_changelog_integrity.sh` — Expected: GREEN.
- [ ] **Step 2: 전체 스위트 대조.** `baseline.sh` 로 `after` — Expected: 새 실패 0(있으면 고치거나 이유).
- [ ] **Step 3: 커밋** — `docs(spec-distill): 엔진 스냅숏 · 한계 공시 판 올림`
- [ ] **Step 4: 마지막 전체 리뷰에 AC 를 싣는다.** 고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 이 계획 몫(AC25 · AC26 · AC28) 목록을 싣고 AC 마다 `AC25: 구현됨 — <근거>` 꼴(구현됨 · 미룸 · 빠짐)로 보고하게 한다. 보고를 `$HOME/.claude/sdd-mirror/r8-plan3/ac-report.md`(git 이 추적하지 않음)에 적고, 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표에 올린 뒤 PR 전에 `python3 <spec-distill>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-20-dependency-portability-design.md "$HOME/.claude/sdd-mirror/r8-plan3/ac-report.md" --acs "AC25 · AC26 · AC28"` 의 경고를 사용자에게 보인다.
