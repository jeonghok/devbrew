# R2 spec-distill 안쪽 압축 · 리뷰 장치 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 의 압축 · 리뷰 · 인터뷰 끝내기 장치가 덜어 낸 것을 사용자에게 보이고 되살릴 길을 주며, 사용자 결정을 덮는 장치를 걷는다 — 설계 §4 처분 표 34행을 그대로 집행한다.

**Architecture:** 새 원장 파일 없이 각 장치가 사용자가 이미 보는 자리(seed 게이트 앞 · B-0 확정 목록 · 리뷰 게이트 · 라운드 «지금 이해»)에 한 줄 공시를 더한다. 기계 쪽은 다섯 스크립트(`check_seed.py` · `seed_provenance.py` · `seed_review_log.py` · `build_seed_inline_blob.py` · `check_brief.py` · `check_verbatim_coverage.py`)가 새 형식을 읽고, 문면 쪽은 프로필 셋 · skill 다섯 · 템플릿 셋 · reference 넷을 고친다. 공유 엔진(`shared/docreview/`)은 건드리지 않는다.

**Tech Stack:** Markdown skill/reference/profile, Python 3.9 (`from __future__ import annotations`), bash 락 테스트(`shared/tests/assert.sh`), python unittest.

**Spec:** `docs/superpowers/specs/2026-10-15-distill-distortion-devices-design.md` (리포 상대경로). 실행자는 계획과 설계문서를 함께 읽는다. 설계문서의 §4 처분 표와 `## 결정 기록` 은 사용자 결정이다 — 다시 정하지 않는다.

## 목차

- [Global Constraints](#global-constraints) · [기준선](#기준선-계획-전에-잼) · [Review Focus](#review-focus)
- [설계의 미룬 것 · 권고를 이 계획이 닫는 방법](#설계의-미룬-것--권고를-이-계획이-닫는-방법) · [락 이름 → 테스트 파일](#락-이름--테스트-파일) · [새 락 파일](#새-락-파일--pluginsspec-distillteststest_distortion_devicessh)
- [Task 1 seed 기계](#task-1-seed-기계--audit-의-덜어-낸-것-표--사용자가-적은-말-칸--확인-표시가-문단을-따라감) · [Task 2 seed 쪽 문면](#task-2-seed-쪽-문면--압축-규약--request-framing--seed-템플릿--seed-프로필) · [Task 3 trivia](#task-3-trivia-우회-앞에서-묻는다-n11)
- [Task 4 리뷰 프로필](#task-4-리뷰-프로필--과설계-사다리--3건-상한--원문-대조--brief-고칠-자리--방향-질문--설계문서-scope) · [Task 5 payload §6 전량](#task-5-payload-6-은-원문-전량-추가만-허용-n7) · [Task 6 brief 형식](#task-6-brief-형식--4-여러-줄--1-출처-표시--해결한-결정도-3-에-rc39--n21--n22)
- [Task 7 인터뷰 끝내기](#task-7-인터뷰-끝내기--b-0-공시--재제시-상한-질문--참고-전부-보기--붙여넣은-seed) · [Task 8 reviewing-brief · spec-review](#task-8-reviewing-brief--spec-review--지출-통제-문장--냉독-그-밖--참고-전부-보기--옛-규칙-문장) · [Task 9 라운드 공시](#task-9-spec-interview-라운드-공시--사실-직접-답--밀린-질문--줄인-사실-n5--n6--n16)
- [Task 10 릴리스 표면](#task-10-릴리스-표면--버전--changelog--readme) · [Task 11 변이 검증 · 끝에서 끝](#task-11-변이-검증-ac17--끝에서-끝-픽스처-걷기) · [Self-Review 기록](#self-review-기록)

## Global Constraints

- 모든 경로는 worktree 절대경로 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a661e3ee5bc3ea413` 아래다. main 레포(`/Users/jeonghokim/Downloads/devbrew/plugins/...`)나 다른 worktree 의 같은 이름 파일을 고치지 않는다.
- 브랜치는 `r2-impl`(원격 `feature/distill-distortion-devices` 를 추적). 커밋 설명은 한국어, `type(scope)` 는 영어 — 예 `feat(spec-distill): …`. 구현 커밋 끝 트레일러 세 줄:
  ```
  Spec: docs/superpowers/specs/2026-10-15-distill-distortion-devices-design.md
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01XKSh1VvN6kYTmLJS675MgX
  ```
- 커밋은 pathspec 으로만 한다(`git -C <worktree> add <파일들>` 뒤 `git -C <worktree> commit -F <메시지 파일>`) — `git add -A` · `git add .` 금지. 메시지 파일은 `~/.claude/sdd-mirror/r2-impl/` 아래에 둔다.
- 이 세션의 Bash 가드는 git 이 섞인 복합 명령(`cd … && git …`)을 거부한다. git 은 `git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a661e3ee5bc3ea413 …` 한 줄씩. 여러 단계 스크립트는 `~/.claude/sdd-mirror/r2-impl/<task>/` 아래 파일로 써서 `bash <파일>` 로 돌린다. 공유 tmp 를 glob 으로 지우지 않는다(자기 하위 폴더만).
- Bash 도구 셸은 zsh 다 — `PIPESTATUS` 가 없다. rc 는 파이프 없이 받거나 `bash -c` 안에서 잡는다.
- 셸 테스트는 리포 루트에서 `bash plugins/spec-distill/tests/<이름>.sh` / `bash shared/tests/<이름>.sh` 로 돌린다. 실패 줄은 `  ✗ ` 로 시작한다. python 테스트는 `python3 -m unittest plugins/spec-distill/tests/<이름>.py`.
- 테스트 실행과 변이 검증에는 `PYTHONDONTWRITEBYTECODE=1` 을 건다.
- 새 셸 테스트 파일은 `chmod +x` 하고 커밋 뒤 `git -C <worktree> ls-files -s <파일>` 이 `100755` 인지 본다. 새 테스트 파일에는 `# guards:` 줄을 두지 않는다(두면 `--emit-scanned` 계약을 함께 져야 한다).
- 새 파이썬 코드는 파일을 `encoding="utf-8"` 로 읽고 쓴다. 셸 안 인라인 python 은 `python3 -I -X utf8`, 스크립트 호출에는 `-I` 를 쓰지 않는다. 긴 한글 문자열 줄은 인접 문자열로 나눈다(CPython 토크나이저). 테스트의 python 문자열 안에 `\uXXXX` 를 손으로 쓰지 않는다 — 한글을 그대로 쓴다.
- macOS bash 3.2: `${var}` 뒤에 한글이 바로 오면 중괄호를 쓴다(`「${v}」`). `mapfile` 없음. `set -u` 아래 빈 배열 `"${a[@]}"` 금지.
- 공시 줄 말투 하나(설계 Constraints): `<무엇> 덜어 낸 것 <N>개 — <번호 · 한 줄 이유>` 모양 — 장치마다 「무엇」만 다르다.
- 고정점은 건드리지 않는다: URL 비권위화 · «(사용자 확인)» 글자 보존 · brief §1 보호(리뷰 처분으로는 못 고침) · §6 기존 글자 불변 · trivia `force` 첫 토큰.
- 리뷰어(엔진 `doc-critic*` · `doc-recritic`)에게 `must_catch` 를 보이지 않는 규칙은 그대로다 — 프로필 **본문**에 「이 축은 게이트로 간다」 같은 라우팅 문장을 쓰지 않는다.
- 문면 리터럴은 한 줄 안에 쓰거나 공백 자리에서만 줄을 나눈다 — 락이 줄바꿈을 공백 하나로 접어(`flat`) 잰다.
- 새로 쓰는 문면에 `최대 <숫자>회` · `<숫자>회까지` 를 쓰지 않는다. 새 문면 · 계획 · 커밋 메시지에 옛 리뷰 훅 식별자(예: `review-` 로 시작하는 옛 dispatch 이름)를 쓰지 않는다 — `test_review_hook_removed.py` 가 문서 코퍼스까지 잰다.
- 플러그인 버전은 Task 10 에서 한 번 올린다: `5.5.0` → `5.6.0`(minor). 같은 시기에 R3 · R7 이 병렬로 가므로 머지 직전에 번호가 바뀔 수 있다 — PR 본문에 그렇게 적는다.

## 기준선 (계획 전에 잼)

`~/.claude/sdd-mirror/r2-impl/run_suite.sh <출력>` 이 spec-distill · shared 스위트를 리포 루트에서 돌려 FAIL «이름» 을 정렬해 남긴다. 기준선 `~/.claude/sdd-mirror/r2-impl/baseline-before.txt` — 둘:

- `test_hook_output_schema.py: FAIL: test_python_and_bash_resolvers_agree` (worktree 환경 RED — 알려진 것)
- `test_review_hook_removed.py: FAIL: test_no_identifier_residue` (main 의 `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md:166` 이 옛 식별자를 담음 — 이 에픽 밖, 손대지 않는다)

각 Task 끝의 회귀 판정은 「FAIL 이름 집합 ⊆ 기준선」이다.

## Review Focus

1. **덜어 낸 것 표가 템플릿 머리 행뿐이다** — 저자가 템플릿을 그대로 복사해 데이터 행도 `없음` 줄도 없으면 `check_seed.py` 는 막아야 한다(「덜어 낸 것 0」과 「적지 않음」은 다른 사실). → Task 1 `cut_header_only` 케이스.
2. **«사용자가 적은 말» 안에 「」 이나 ` — ` 가 들어 있다** — 풀이 줄이 모양 어긋남(rc 2)으로 판정되면 사용자가 고쳐 준 말 때문에 seed 리뷰가 멈춘다. 모양이 맞는 줄로 읽혀야 하고, `고르지 않음` 줄이 확인으로 바뀌면 안 된다. → Task 1 `said_brackets` 케이스.
3. **§4 항목의 결정 연결을 둘째 줄로 내렸다** — 여러 줄을 허용한 틈으로 연결이 첫 줄을 떠나면 조사 술어가 그 항목을 「연결 없음」으로 못 보거나, 본문 줄의 `RC<n>` 이 순회 밖으로 빠진다. 둘 다 red 여야 한다. → Task 6 `s4_link_on_body` · `s4_rc_on_body` 케이스.
4. **payload §6 사본이 audit §6 과 글자가 다르다** — payload 에 원문을 겹쳐 두게 되면서 「payload 쪽을 고쳐 지적에 맞추는」 세탁이 열린다. 같은 앵커의 글자가 다르면 `check_verbatim_coverage.py` 가 구조 위반(rc 1)이어야 한다. → Task 5 `dup_differs` 케이스.
5. **`[해결 ⟨S99⟩]` 처럼 없는 발화를 가리키는 해결 토큰** — 모델이 결정을 닫으면서 근거를 지어내는 길. `check_brief.py gate` 가 red 여야 하고, §3 에 남은 정상 해결 결정은 green(양성 짝). → Task 6 `resolved_dangling` · `resolved_kept` 케이스.

## 설계의 미룬 것 · 권고를 이 계획이 닫는 방법

| 항목 | 이 계획의 처리 |
|---|---|
| audit 의 `## seed 에서 덜어 낸 것` 위치와 절 번호 | 번호 없는 절로 `## 3. 긴 초안` 바로 뒤, `## 4. 비평과 냉독` 앞에 둔다 — 기존 번호를 밀지 않는다. 절 경계 목록(`seed_review_log.AUDIT_HEADINGS`)에 더해 `## 3` 본문이 새 절을 삼키지 않게 한다(Task 1) |
| 새 audit 형식을 읽는 기존 파서(1cdda836#r1.1) | `AUDIT_HEADINGS` 에 새 제목 추가(절 경계) · `seed_provenance.py` 의 풀이 줄 정규식 셋(`READING_RE` · `READING_LINE_RE` · `PLACEHOLDER_READING_RE`)이 선택 꼬리 ` — 사용자가 적은 말: 「…」` 를 받는다 · `build_seed_inline_blob.py` 가 새 절을 번들에 싣는다(Task 1) |
| `check_brief.py` §4 여러 줄 판독 · fixture 영향 | §4 만 바꾼다(§0 · §3 · §5 의 항목 판독은 그대로). 항목 = 열 0 의 불릿 줄, 그 뒤 들여쓴 줄 = 본문. 술어는 첫 줄에 걸고, 본문 줄의 연결 괄호 · 첫 줄에 없는 `RC<n>` 은 새 술어 `section4_body_failures` 가 red 로 낸다. 기존 fixture 는 §4 에 들여쓴 불릿이 있는 것만 영향 — Task 6 이 스위트로 실측한다 |
| B-0 화면 순서 · 접기 | 순서: ① brief §1 줄과 출처 → ② 확정 후보 → ③ 확정 후보에서 제외한 항목(기존) → ④ `확정으로 올리지 않은 발화` → ⑤ `위험으로 보낸 참고` → ⑥ (붙여넣기 seed 였을 때만) `출처를 가르지 못한 seed 문장`. **접지 않는다** — B-0 은 프로즈 출력이라 길이 제한이 없고, 접지 않으면 「전부 보기」가 필요 없다(Task 7) |
| 프로필 구조 락의 단언 목록 | Task 2 · Task 4 의 테스트 코드가 frontmatter 줄 전체를 핀한다: seed `layer1` · `must_catch` · `ground_truth` 「사용자가 적은 말」, brief `fix_anchors` · `immutable` · `protected_headings` · `must_catch` · `ground_truth`, design-doc `must_catch` 불변. Task 11 이 각 핀을 변이한다 |
| 「바뀌는 락」 칸의 이름 → 파일 | 아래 「락 이름 → 테스트 파일」 표 |
| 엔진 얼림 검사가 payload §6 추가를 어떻게 보는가 | Task 5 Step 7 이 엔진 CLI 로 실측한다. `frozen_change` 로 잡히면 reviewing-brief 에 그 항목을 「결정 발화 추가」로 밝히는 문장을 두고, 엔진의 「추가만 허용」 구분은 R2a 로 넘긴다(PR 후속 목록) |
| seed 의 `omission` 을 `must_catch` 에도 넣는가 | 넣는다 — seed 프로필은 참고(advisory) 축이 없어 `must_catch` 밖 축은 사용자에게 보일 자리가 없다. 층 1 에만 두면 빠짐 지적이 조용히 접힌다(G3 와 어긋남) |
| 「되살리기」 선택 자리 | proceed 게이트 넷(①~④)은 정본 계약이라 늘리지 않는다. 덜어 낸 것이 1개 이상이면 게이트 직전 검사 넷 **앞에서** `AskUserQuestion` 한 번(「되살리기」 · 「그대로 둔다」) — 되살리면 seed 를 고치고 검사 넷부터 다시 돈다(Task 2) |
| 「참고 전부 보기」 자리 | 접는 줄(`… 외 K건`)이 나왔을 때만 2단계 게이트 앞에 `AskUserQuestion` 한 번(「참고 전부 보기」 · 「접은 채로 둔다」). 펼치기는 엔진 JSON(`advice --state-dir`)을 요약 전문으로 찍는 인라인 python 펜스 — 엔진 상수(`RENDER_CAP` · `SUMMARY_WIDTH`)는 R2a(Task 7 · Task 8) |
| §1 출처 표시 모양 | 줄 끝에 `⟨S<n>⟩`(여럿이면 `⟨S1⟩ · ⟨S4⟩`) 또는 `⟨모델 추론⟩`. 게이트는 표시 존재와, `S<n>` 이 payload §6 에 있는지를 본다(Task 6) |
| §3 해결 결정 모양 | `- OQ4 [해결 ⟨S10⟩]: <원래 질문> — 해결: <한 줄> → 근거 RC3`. 게이트: §0 의 해결 결정은 §3 에도 선두 OQ 로 있어야 하고, §3 의 그 줄에 `[해결 ⟨S` 표시가 있어야 하며, 두 자리의 `S<n>` 이 payload §6 에 있어야 한다(Task 6) |

### 락 이름 → 테스트 파일

| 설계의 이름 | 파일 |
|---|---|
| finishing 락 | `test_conducting_interview_stage.sh` · `test_finishing_block_scope.py` · `test_rereview_cap_consistency.sh` · `test_probe_sweep_residue.sh` · `test_proceed_gate_adopters.sh` · `test_plain_gate_templates.sh` · `test_next_session_command.sh` |
| spec-interview 락 · seed 입력 락 | `test_conducting_interview_stage.sh` · `test_saturation_reference.sh` · `test_stale_terms.sh` · `test_spec_interview_entry.sh` · `test_seed_input_provenance.sh` · `test_seed_at_path_handoff.sh` |
| request-framing 락 | `test_request_framing_entry.sh` · `test_framing_review_contract.sh` · `test_seed_gate_wiring.sh` · `test_seed_edit_diff.sh` · `test_seed_review_log.sh` · `test_seed_inline_blob.sh` · `test_compression_adopters.sh` |
| 템플릿 락 | `test_seed_provenance.sh`(seed audit 템플릿 줄 모양 도출) · `test_audit_template_gate_shape.py` · `test_proceed_gate_adopters.sh` |
| 프로필 구조 락 | `test_seed_review_profile.sh` · `test_overdesign_rubric.sh` · `test_dispatch_profile_inline.sh` · `test_seed_codex_axes.sh` · `test_brief_codex_axes.sh` · shared `test_docreview_profile_schema.sh` · `test_docreview_profiles.sh` · `test_docreview_golden.sh` · `test_docreview_mutations.sh` · `test_docreview_codex.sh` · `test_docreview_layer1_wiring.sh` · `test_docreview_intent.sh` |
| check_seed · seed_provenance 테스트 | `test_check_seed.sh` · `test_seed_one_sentence.sh` · `test_seed_provenance.sh` · `test_seed_input_provenance.sh` |
| check_verbatim_coverage 테스트 | `test_check_verbatim_coverage.sh` · `test_brief_review_entry.sh` |
| reviewing-brief 락 | `test_reviewing_brief_skill.sh` · `test_reviewing_brief_residue.sh` · `test_brief_review_*.sh` · `test_brief_agents.sh` · `test_brief_bundle.sh` · `test_brief_inline_blob.sh` |
| spec-review 락 | `test_reviewing_spec_*.sh` · shared `test_docreview_advice_procedure.sh` · `test_docreview_advice.sh` |

## 새 락 파일 — `plugins/spec-distill/tests/test_distortion_devices.sh`

문면 락은 이 한 파일에 모은다. Task 2 가 만들고(머리 + 자기 절), 뒤 Task 들이 자기 절을 `finish` 앞에 더한다. 머리(Task 2 Step 1 에서 그대로 쓴다):

```bash
#!/usr/bin/env bash
# R2 문면 락 — docs/superpowers/specs/2026-10-15-distill-distortion-devices-design.md 의 AC 가 문면에 남긴 리터럴.
# 줄바꿈을 공백 하나로 접은 본문(flat)에서 잰다. 부재 단언마다 같은 파일의 존재 단언(양성 짝)을 둔다 —
# 파일이 사라지면 부재 단언은 공허하게 통과하기 때문이다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
flat() { if [ -f "$1" ]; then tr '\n' ' ' < "$1" | tr -s ' '; else printf '__MISSING__ %s' "$1"; fi; }
has()   { assert_contains "$(flat "$1")" "$2" "$3"; }
hasnt() { assert_not_contains "$(flat "$1")" "$2" "$3"; }
fm_line() { awk -v k="$2" 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&index($0,k)==1{print;exit}' "$1"; }

# ── 절은 Task 순서대로 아래에 붙는다 ──

finish
```

---

### Task 1: seed 기계 — audit 의 덜어 낸 것 표 · 사용자가 적은 말 칸 · 확인 표시가 문단을 따라감

설계 §1-1 · §1-4(기계) · §1-9(기계) · §1-10 · N8 · N19 · N20 · AC3 · AC16d(N19 · N20 부분).

**Files:**
- Modify: `plugins/spec-distill/templates/interview-seed-audit-template.md`
- Modify: `plugins/spec-distill/scripts/seed_review_log.py`(`AUDIT_HEADINGS`)
- Modify: `plugins/spec-distill/scripts/seed_provenance.py`(정규식 셋 · `classify` 순서 · 머리 docstring)
- Modify: `plugins/spec-distill/scripts/check_seed.py`(check 5 · docstring)
- Modify: `plugins/spec-distill/scripts/build_seed_inline_blob.py`(새 절을 번들에)
- Modify: `plugins/spec-distill/skills/spec-interview/references/seed-input.md`(출처 · 확인 표의 셋째 행 — N20 문면)
- Modify: `plugins/spec-distill/tests/fixtures/seed-*.audit.md`(새 절 추가 — 스윕)
- Create: `plugins/spec-distill/tests/test_seed_cut_table.sh`

**Interfaces:**
- Produces: audit 절 제목 리터럴 `## seed 에서 덜어 낸 것` · 표 머리 행 `| 항목 | 기준 | 원문 위치 | 되살림 |` · 덜어 낸 것이 없을 때의 줄 `없음` · 풀이 줄 선택 꼬리 ` — 사용자가 적은 말: 「<말>」`. Task 2 의 문면 · seed 프로필이 이 이름들을 그대로 쓴다.
- Produces: `seed_review_log.AUDIT_HEADINGS` 에 `"## seed 에서 덜어 낸 것"` 이 든다. `build_seed_inline_blob.CUT_TABLE_SECTION = "## seed 에서 덜어 낸 것"`.
- Produces: `check_seed.py gate` 실패 메시지 두 줄(아래 Step 3 리터럴).

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/spec-distill/tests/test_seed_cut_table.sh`(plan-authored test code):

```bash
#!/usr/bin/env bash
# R2 Task 1 — seed audit 의 덜어 낸 것 표(check_seed check 5) · 풀이 줄의 «사용자가 적은 말» 칸 ·
# 확인 표시가 «다시 검증할 것 —» 문단에서도 따라감(classify) · 번들이 새 절을 싣는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
TMP="$(mktemp -d -t sd-cut-XXXXXX)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

seed() { cat > "$TMP/s.md" <<'EOF'
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: a.audit.md
---

로그인이 가끔 실패한다. 세션 스토어 개편은 이번에 하지 않는다. (사용자 확인)

다시 검증할 것 — 서버 로그는 다시 봐야 한다. 경합이 원인이다. (사용자 확인)
EOF
}
# 주의: «다시 검증할 것 —» 문단의 첫 문장은 그 접두를 글자로 품는다(`segments` 가 문단을 문장으로 쪼갤 뿐
# 접두를 떼지 않는다). 그래서 확인 문장은 둘째 문장에 두고, 첫 문장의 키는 접두를 포함한 전문이다.
# audit — $1 = 덜어 낸 것 절 본문(없으면 절째 뺀다: 값 "__NONE__")
audit() {
  {
    printf -- '---\ntype: interview-seed-audit\n---\n\n## 1. 원문\n\n로그인이 가끔 실패한다.\n\n## 2. 질문 전체\n\n### 라운드 1\n\n'
    printf -- '- 물은 것: 무엇을 하지 않나요\n  - 선택지: 자유 입력\n  - 당신이 답한 것: 세션 스토어는 다음 분기\n'
    printf -- '- 확인 질문: 라운드 1\n'
    printf -- '  - 내가 읽은 것: 「세션 스토어 개편은 이번에 하지 않는다.」 — 고름\n'
    printf -- '  - 내가 읽은 것: 「경합이 원인이다.」 — 고름 — 사용자가 적은 말: 「경합 같다, 확실하진 않다」\n'
    printf -- '  - 내가 읽은 것: 「서버가 원인이다.」 — 고르지 않음 — 사용자가 적은 말: 「「서버」 — 고름 은 아니다」\n\n'
    printf -- '## 3. 긴 초안\n\n긴 초안 본문.\n\n'
    if [ "$1" != "__NONE__" ]; then printf -- '## seed 에서 덜어 낸 것\n\n%s\n\n' "$1"; fi
    printf -- '## 4. 비평과 냉독\n\n## 5. degrade\n\n## 6. 리뷰 결정\n'
  } > "$TMP/a.audit.md"
}
gate() { python3 "$S/check_seed.py" gate "$TMP/s.md" "$TMP/a.audit.md" 2>"$TMP/err"; }

ROWS='| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|
| 재현 절차 재기술 | 자명 | ## 3 둘째 문단 | — |'

seed
# ── check 5: 표 · 없음 · 부재 · 머리 행만
audit "$ROWS";      gate; assert_eq "$?" "0" "cut_rows: 데이터 행이 있는 표는 통과한다"
audit "없음";        gate; assert_eq "$?" "0" "cut_none: 「없음」 한 줄은 통과한다 (덜어 낸 것 0)"
audit "__NONE__";   gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -qF 'seed 에서 덜어 낸 것' "$TMP/err"; } \
  && ok "cut_absent: 절이 없으면 막고 절 이름을 댄다" || no "cut_absent: 절이 없어도 통과했다 (rc=$rc)"
audit '| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|';    gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -qF '표 행도' "$TMP/err"; } \
  && ok "cut_header_only: 머리 행뿐이면 막는다 (적지 않음 ≠ 0개)" || no "cut_header_only: 머리 행뿐인데 통과했다 (rc=$rc)"
# AC3 — URL 금지는 그대로
audit "없음"; printf '\n자료는 https://example.com 에 있다.\n' >> "$TMP/s.md"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "AC3: URL 금지는 그대로다" || no "AC3: seed 의 URL 이 통과했다"
seed

# ── 절 경계: ## 3 본문이 새 절을 삼키지 않는다
audit "$ROWS"
body3="$(python3 -I -X utf8 -c 'import sys; sys.path.insert(0, sys.argv[1]); from seed_review_log import section_body; print(section_body(open(sys.argv[2], encoding="utf-8").read(), "## 3. 긴 초안"))' "$S" "$TMP/a.audit.md")"
assert_not_contains "$body3" "재현 절차 재기술" "boundary: ## 3. 긴 초안 의 본문에 덜어 낸 것 표가 섞이지 않는다"
assert_contains "$body3" "긴 초안 본문." "boundary(양성 짝): ## 3 본문은 읽힌다"

# ── marks: «사용자가 적은 말» 꼬리가 있어도 모양이 맞고(rc 2 아님), 고름 풀이는 확인 근거다
python3 "$S/seed_provenance.py" marks "$TMP/s.md" "$TMP/a.audit.md" > "$TMP/marks.json" 2>"$TMP/err"; rc=$?
assert_eq "$rc" "0" "said_suffix: 꼬리 달린 풀이 줄이 모양 어긋남으로 막히지 않고 두 표시가 다 근거를 얻는다"
assert_not_contains "$(cat "$TMP/err")" "malformed" "said_brackets: 「」 와 ` — 고름` 이 든 적은 말도 모양 어긋남이 아니다"

# ── classify: 표시가 문단보다 먼저 (N20)
python3 "$S/seed_provenance.py" classify "$TMP/s.md" --audit "$TMP/a.audit.md" > "$TMP/c.json"
row() { python3 -I -X utf8 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); r=[x for x in d["sentences"] if x["text"]==sys.argv[2]]; print("%s %s %s" % (r[0]["provenance"], r[0]["confirmed"], r[0]["basis"]) if r else "ABSENT")' "$TMP/c.json" "$1"; }
assert_eq "$(row '경합이 원인이다.')" "user True confirmed_reading" "N20: 확인 표시가 붙은 문장은 «다시 검증할 것 —» 문단 안에서도 사용자 확인이다"
assert_eq "$(row '다시 검증할 것 — 서버 로그는 다시 봐야 한다.')" "author False reverify_paragraph" "N20(양성 짝): 같은 문단의 표시 없는 문장은 저자 · 미확인이다"
assert_eq "$(row '세션 스토어 개편은 이번에 하지 않는다.')" "user True confirmed_reading" "N20(대조): 문단 밖 확인 문장은 그대로 확인이다"

# ── 고르지 않은 풀이에 표시를 붙이면 문단 안에서도 확인이 아니다
cat > "$TMP/s2.md" <<'EOF'
---
type: interview-seed
---

다시 검증할 것 — 로그를 본다. 서버가 원인이다. (사용자 확인)
EOF
python3 "$S/seed_provenance.py" classify "$TMP/s2.md" --audit "$TMP/a.audit.md" > "$TMP/c.json"
assert_eq "$(row '서버가 원인이다.')" "author False reverify_paragraph" "N20(경계): 고르지 않은 풀이에 붙은 표시는 문단 안에서 확인이 되지 않는다"

# ── 번들이 덜어 낸 것 표를 싣는다 (두 소비자)
printf '# repo\n' > "$TMP/CLAUDE.md"
for who in detect recritic; do
  out="$(python3 "$S/build_seed_inline_blob.py" "$TMP/s.md" "$TMP/a.audit.md" "$TMP/CLAUDE.md" --for "$who" 2>/dev/null)"
  assert_contains "$out" "## seed 에서 덜어 낸 것" "blob($who): 번들에 덜어 낸 것 절이 있다"
  assert_contains "$out" "재현 절차 재기술" "blob($who): 표의 행이 실린다"
done

finish
```

- [ ] **Step 2: 실패를 확인한다**

`chmod +x plugins/spec-distill/tests/test_seed_cut_table.sh` 후 `bash plugins/spec-distill/tests/test_seed_cut_table.sh`.
Expected: `cut_absent` · `cut_header_only` · `boundary` · `said_suffix` · `N20` · `blob(*)` 줄이 `✗`.

- [ ] **Step 3: 구현한다**

(a) `seed_review_log.py` — `AUDIT_HEADINGS` 를 다음으로 바꾼다(절 경계는 줄 전체 일치이고 순서는 무관하다):

```python
AUDIT_HEADINGS = (
    "## 1. 원문",
    "## 2. 질문 전체",
    "## 3. 긴 초안",
    "## seed 에서 덜어 낸 것",
    "## 4. 비평과 냉독",
    "## 5. degrade",
    "## 6. 리뷰 결정",
)
```
그 위 주석이나 docstring 에 「여섯」이라고 적힌 곳이 있으면 「일곱」으로 고친다(`section_body` docstring 의 「여섯 제목」).

(b) `seed_provenance.py` — 정규식 셋을 선택 꼬리를 받게 바꾼다(그 밖의 규칙은 그대로):

```python
# 풀이 줄 끝의 선택 꼬리 — 사용자가 «기타» 로 적은 말 · 「아니다」 뒤에 덧붙인 말(N19). 꼬리 안의 글자는
# 비신뢰 요청문이라 판정에 쓰지 않는다 — 줄 모양만 받는다.
SAID_TAIL = r"(?: — 사용자가 적은 말: 「.*」)?"
READING_RE = re.compile(r"^\s*- 내가 읽은 것: 「(?P<t>.*)」 — 고름" + SAID_TAIL + r"\s*$")
READING_LINE_RE = re.compile(r"^\s*- 내가 읽은 것: 「.*」 — (?:고름|고르지 않음)" + SAID_TAIL + r"\s*$")
PLACEHOLDER_READING_RE = re.compile(
    r"^\s*- 내가 읽은 것:\s*「\s*<[^<>」]*>\s*」\s*—\s*<[^<>]*>"
    r"(?:\s*\[\s*—\s*사용자가 적은 말:\s*「\s*<[^<>」]*>\s*」\s*\])?\s*$")
```
`READING_RE` 의 `t` 는 탐욕 그대로 둔다 — 꼬리가 맞을 때 역추적으로 풀이 글자만 남는다. 줄 맨 끝이 `」 — 고름` 이 아니고 꼬리로도 맞지 않으면 지금처럼 모양 어긋남이다.

`classify` 의 판정 순서를 바꾼다(N20 — 표시가 문단보다 먼저):

```python
    for s in segs:
        if s["marked"] and s.get("mark_valid"):
            r = ("user", True, "confirmed_reading")
        elif s["reverify"]:
            r = ("author", False, "reverify_paragraph")
        elif s["text"] and s["text"] in verb_units:
            r = ("user", False, "verbatim")
        elif s["marked"]:
            r = ("author", False, "mark_invalid")
        else:
            r = ("author", False, "none")
```
머리 docstring 에 한 문장을 더한다: 「확인 표시는 문장을 따라간다 — 근거 있는 «(사용자 확인)» 이 붙은 문장은 «다시 검증할 것 —» 문단 안에서도 사용자 확인이다. 그 문단의 표시 없는 문장은 저자 · 미확인이다.」 풀이 줄 모양을 말하는 docstring 문장(`- 내가 읽은 것: 「…」 — 고름|고르지 않음`)과 stderr 메시지 두 곳에 「(끝에 ` — 사용자가 적은 말: 「…」` 가 붙을 수 있다)」를 더한다.

(c) `check_seed.py` — check 4 뒤에 check 5 를 더한다(같은 `atext` 를 쓴다 — 읽기 실패면 이미 그 사실이 실렸으므로 건너뛴다):

```python
CUT_HEADING = "## seed 에서 덜어 낸 것"
CUT_HEADER_ROW = "| 항목 | 기준 | 원문 위치 | 되살림 |"
_CUT_SEP_RE = re.compile(r"^\|[\s:|-]+\|?\s*$")


def cut_table_problems(atext: str) -> list:
    """audit `## seed 에서 덜어 낸 것` — 표(머리 행 + 데이터 행 하나 이상) 또는 `없음` 한 줄(설계 §1-1 · §1-4).
    seed 본문이 아니라 audit 쪽 존재 검사다 — seed 를 양식으로 만들지 않는다(`test_seed_one_sentence.sh`)."""
    m = re.search(r'^##\s*seed 에서 덜어 낸 것\s*$(.*?)(?=^##\s|\Z)', atext, re.M | re.S)
    if m is None:
        return ["audit 에 `## seed 에서 덜어 낸 것` 절이 없다 — 덜어 낸 것이 없으면 `없음` 한 줄을 적는다"]
    lines = [ln.strip() for ln in m.group(1).splitlines() if ln.strip()]
    if any(ln == "없음" for ln in lines):
        return []
    rows = [ln for ln in lines if ln.startswith("|") and ln.replace(" ", "") != CUT_HEADER_ROW.replace(" ", "")
            and not _CUT_SEP_RE.match(ln)]
    if not rows:
        return ["audit 의 `## seed 에서 덜어 낸 것` 절에 표 행도 `없음` 줄도 없다 — 덜어 낸 항목을 한 줄씩 적거나 `없음` 을 적는다"]
    return []
```
`gate()` 의 audit 분기 끝(`## 1. 원문` 검사 뒤, 같은 `else:` 안)에 `problems.extend(cut_table_problems(atext))`. 모듈 docstring 의 「audit 쪽 존재 검사는 **원문 보존 하나뿐**이다」를 「audit 쪽 존재 검사는 **원문 보존**과 **덜어 낸 것 표** 둘이다」로, 맨 윗줄 「다섯」을 「여섯」으로 고친다. URL · 태그 · 답-슬롯 검사는 그대로다.

(d) `build_seed_inline_blob.py` — 상수 `CUT_TABLE_SECTION = "## seed 에서 덜어 낸 것"` 를 `UNTRUSTED_VERBATIM_SECTIONS` 아래에 두고(그 튜플에는 넣지 않는다 — 저자가 쓴 표다), `assemble()` 에서 질문 전체 다음 자리에 두 소비자 모두에게:

```python
    parts.append(f"## 덜어 낸 것 (audit `{CUT_TABLE_SECTION}` — 저자가 쓴 표)\n\n"
                 + _or_none(section_body(audit_text, CUT_TABLE_SECTION)))
```
`main()` 에서 절이 없으면 경고 한 줄(`[spec-distill] 경고: … 에 \`## seed 에서 덜어 낸 것\` 절이 없다 — 「(없음)」으로 조립한다`)을 stderr 로 내고 계속한다. 모듈 docstring 「재료 다섯」을 「재료 여섯」으로 고치고 새 재료를 이름으로 더한다.

(e) 템플릿 `interview-seed-audit-template.md` — `## 3. 긴 초안` 블록 바로 뒤에:

```markdown
## seed 에서 덜어 낸 것

(긴 초안에서 seed 로 가지 않은 항목 — 한 줄에 하나. 「기준」은 압축 규약의 깎는 기준(자명 · 하류가 정할
 것 · 읽으면 아는 것 · 과정 · 상시 규칙 · 출처 링크)이나 seed 템플릿 「쓰지 말 것」의 항목이다. 「원문
 위치」는 `## 1` · `## 2` · `## 3` 안의 자리. 사용자가 게이트 앞에서 되살리면 「되살림」 칸에 `되살림` 을
 적는다. 덜어 낸 것이 없으면 표 대신 `없음` 한 줄을 적는다.)

| 항목 | 기준 | 원문 위치 | 되살림 |
|---|---|---|---|
```
`## 2. 질문 전체` 블록의 확인 질문 줄을 다음으로 바꾸고, 그 블록 머리 괄호 안내 끝에 문장 하나를 더한다:

```markdown
  - 내가 읽은 것: 「<풀이 문장>」 — <고름 | 고르지 않음>[ — 사용자가 적은 말: 「<적은 말 그대로>」]
```
안내 문장: 「«기타» 로 적은 말이나 「아니다」 뒤에 덧붙인 말이 있으면 그 풀이 줄 끝에 ` — 사용자가 적은 말: 「…」` 를 붙인다 — 이 칸도 사용자의 말이다.」 (`«당신이 답한 것» 줄만 사용자의 말이다` 는 「«당신이 답한 것» 줄과 «사용자가 적은 말» 칸만 사용자의 말이다」로.)

(f) `seed-input.md` 의 출처 · 확인 표 셋째 행 `| 그 밖의 저자 문장(«다시 검증할 것 —» 문단 포함) | Phase 0 저자 | 미확인 |` → `| 그 밖의 저자 문장(«다시 검증할 것 —» 문단 안의 표시 없는 문장 포함) | Phase 0 저자 | 미확인 |`, 표 아래 문단 첫머리에 「«(사용자 확인)» 이 붙은 문장은 «다시 검증할 것 —» 문단으로 옮겨져도 확인이다 — 분류기가 표시를 문단보다 먼저 본다.」

(g) fixture 스윕 — `plugins/spec-distill/tests/fixtures/seed-*.audit.md` 중 `## 3. 긴 초안` 이 있는 것에는 그 절 뒤에, 없는 것에는 `## 6. 리뷰 결정` 앞(그것도 없으면 파일 끝)에 `## seed 에서 덜어 낸 것\n\n없음\n` 을 넣는다. **단** 그 픽스처가 「절이 비었다 · 없다」를 재려고 만든 것(이름에 `empty` · `missing` · `no-` 가 들어간 것)은 열어 보고 그 의도가 새 절과 무관할 때만 넣는다. 스윕은 `~/.claude/sdd-mirror/r2-impl/t1/sweep.py` 로 쓰고 바뀐 파일 목록을 진행 기록에 남긴다.

- [ ] **Step 4: 통과를 확인한다**

`bash plugins/spec-distill/tests/test_seed_cut_table.sh` → `Fail: 0`.
그 다음 닿은 락: `test_check_seed.sh` · `test_seed_one_sentence.sh` · `test_seed_provenance.sh` · `test_seed_input_provenance.sh` · `test_seed_inline_blob.sh` · `test_seed_review_log.sh` · `test_framing_review_contract.sh` · `test_seed_edit_diff.sh` · shared `test_docreview_profiles.sh` · `test_docreview_golden.sh`. 깨진 단언은 새 동작으로 맞추되, 그 단언이 지키던 성질(예: `test_seed_provenance.sh` 의 「풀이 줄 모양은 템플릿에서 도출」)이 새 줄 모양에서도 성립하는지 확인하고 고친다 — 성질을 지우지 않는다. 마지막으로 `bash ~/.claude/sdd-mirror/r2-impl/run_suite.sh ~/.claude/sdd-mirror/r2-impl/after-t1.txt` 후 `comm -13 ~/.claude/sdd-mirror/r2-impl/baseline-before.txt ~/.claude/sdd-mirror/r2-impl/after-t1.txt` 가 비어야 한다.

- [ ] **Step 5: 커밋한다**

```
feat(spec-distill): seed audit 에 덜어 낸 것 표와 사용자가 적은 말 칸을 둔다

check_seed 가 표(또는 「없음」)를 보고, 확인 표시는 «다시 검증할 것» 문단에서도 따라간다.
```
+ 트레일러 셋. `git -C <worktree> ls-files -s plugins/spec-distill/tests/test_seed_cut_table.sh` → `100755`.

---

### Task 2: seed 쪽 문면 — 압축 규약 · request-framing · seed 템플릿 · seed 프로필

설계 §1-1~§1-9(문면) · §2-4(seed) · N4 · N8 · N9 · RC30 · RC31 · RC32 · AC1 · AC2 · AC4 · AC6(seed) · AC16d(N19 문면).

**Files:**
- Modify: `plugins/spec-distill/references/compression.md`
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`
- Modify: `plugins/spec-distill/templates/interview-seed-template.md`
- Modify: `plugins/spec-distill/references/docreview-profiles/seed.md`
- Create: `plugins/spec-distill/tests/test_distortion_devices.sh`(머리는 위 「새 락 파일」 절 그대로 + 이 Task 의 절)

**Interfaces:**
- Consumes: Task 1 의 절 제목 `## seed 에서 덜어 낸 것` · 머리 행 · `없음` · ` — 사용자가 적은 말: 「…」`.
- Produces: 공시 리터럴 `seed 에서 덜어 낸 것 <N>개 — <번호 · 한 줄 이유>` · `확인받지 못한 풀이 <N>개 — <seed 문장 위치>` · 선택 라벨 「되살리기」 · 「그대로 둔다」. 압축 규약의 `빼면 표에 남긴다`.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — 「새 락 파일」 머리를 그대로 쓰고 `finish` 앞에 이 절(plan-authored test code):

```bash
# ── Task 2 — 압축 규약 · request-framing · seed 템플릿 · seed 프로필 ──
C="$SD/references/compression.md"; RF="$SD/skills/request-framing/SKILL.md"
ST="$SD/templates/interview-seed-template.md"; SP="$SD/references/docreview-profiles/seed.md"
# AC2 — 세 물음은 「빼면 표에 남긴다」, 고정점 문면은 그대로
has   "$C" '빼면 표에 남긴다' "AC2: 압축 규약의 세 물음이 「빼면 표에 남긴다」를 말한다"
hasnt "$C" '어차피 맞게 할 거면 뺀다.' "AC2(부재): 「어차피 맞게 할 거면 뺀다.」 단독 문장이 없다"
hasnt "$C" '있으면 뺀다.' "AC2(부재): 「있으면 뺀다.」 단독 문장이 없다"
has   "$C" '## 상한을 두지 않는다' "AC2(고정점): 「상한을 두지 않는다」 절이 그대로다"
has   "$C" '확인은 저자가 다시 쓸 수 없는 고정점이다' "AC2(고정점): 확정 표시 고정점 문장이 그대로다"
has   "$C" '링크를 근거로 세우지 말라' "AC2(고정점): URL 비권위화 문장이 그대로다"
has   "$C" '## seed 에서 덜어 낸 것' "§1-1: 압축 규약이 덜어 낸 것 표 자리를 이름으로 댄다"
# AC1 · AC4 — request-framing 게이트 앞 공시와 되살리기
has   "$RF" 'seed 에서 덜어 낸 것 <N>개 — <번호 · 한 줄 이유>' "AC1: seed 게이트 앞에 덜어 낸 것 공시 줄이 있다"
has   "$RF" '「되살리기」' "AC1: 되살리기 선택이 있다"
has   "$RF" '「되살림」 칸' "AC1: 되살린 항목이 표의 「되살림」 칸에 표시된다"
has   "$RF" '확인받지 못한 풀이 <N>개 — <seed 문장 위치>' "AC4: seed 게이트 앞에 확인받지 못한 풀이 공시 줄이 있다"
has   "$RF" '사용자가 적은 말' "§1-9: 확인 질문 기록이 사용자가 적은 말 칸을 말한다"
hasnt "$RF" 'seed 로 나가는 것은 깎은 것뿐' "RC31(부재): 「seed 로 나가는 것은 깎은 것뿐」이 없다"
# N9 — seed 템플릿 「쓰지 말 것」도 표를 거친다
has   "$ST" '## seed 에서 덜어 낸 것' "N9: seed 템플릿 「쓰지 말 것」이 덜어 낸 것 표를 가리킨다"
has   "$ST" '## 쓰지 말 것' "N9(양성 짝): 「쓰지 말 것」 절이 남아 있다"
# AC6(seed) — layer1 · must_catch 에 omission, ground_truth 에 사용자가 적은 말
assert_eq "$(fm_line "$SP" '  layer1:')" "  layer1: [unfounded_addition, example_as_requirement, premature_closure, inference_as_decision, omission]" "AC6: seed layer1 에 omission 이 있다"
assert_eq "$(fm_line "$SP" 'must_catch:')" "must_catch: [unfounded_addition, example_as_requirement, premature_closure, inference_as_decision, omission]" "AC6: seed must_catch 에 omission 이 있다(참고 축이 없는 프로필)"
assert_contains "$(fm_line "$SP" 'ground_truth:')" '사용자가 적은 말' "§1-9: seed ground_truth 가 사용자가 적은 말 칸을 정답으로 싣는다"
has   "$SP" '- `omission` —' "§2-4: seed 프로필 본문에 omission 범주 정의 줄이 있다"
has   "$SP" '덜어 낸 것 표' "§2-4: seed 층 1 머리 · 판정 관계가 덜어 낸 것 표를 대조 자리로 댄다"
```
`chmod +x plugins/spec-distill/tests/test_distortion_devices.sh`.

- [ ] **Step 2: 실패를 확인한다** — `bash plugins/spec-distill/tests/test_distortion_devices.sh` → 위 단언 대부분 `✗`.

- [ ] **Step 3: 구현한다**

(a) `compression.md`
- `## 깎이는 것` 절 뒤에 새 절:
  ```markdown
  ## 덜어 낸 것은 표에 남는다

  seed 로 가지 않은 항목은 버리지 않는다 — audit 의 `## seed 에서 덜어 낸 것` 표(칸: 항목 · 기준 · 원문 위치 ·
  되살림)에 한 줄씩 남는다. **출처 링크**도 seed 에는 넣지 않고 이 표에 출처 항목으로 남긴다. seed 게이트 앞에
  `seed 에서 덜어 낸 것 <N>개 — <번호 · 한 줄 이유>` 가 보이고 사용자가 「되살리기」로 되돌린다. brief 쪽의 같은
  자리는 Step B-0 의 `확정으로 올리지 않은 발화` 줄이다.
  ```
- `## 문장 하나에 적용하는 세 물음` 의 셋:
  1. `… 실행 세부인가. 세부면 빼고, 빼면 표에 남긴다.`
  2. `이 문장을 빼면 에이전트가 **틀리거나 빠뜨릴** 수 있는가. 어차피 맞게 할 거면 빼고, 빼면 표에 남긴다.` (둘째 줄 「대체로 하지만 가끔 빠뜨리는 것은 한 줄 값어치가 있다.」는 그대로)
  3. `레포 \`CLAUDE.md\`·\`AGENTS.md\` 에 이미 있는가. 있으면 빼고, 빼면 표에 남긴다.`
- `## 확정 표시와 마지막 문단` 의 「압축이 문장을 다시 쓰면 표시는 따라가지 않는다.」 문단 끝에: 「글자를 바꾸지 않고 «다시 검증할 것 —» 문단으로 옮긴 문장은 표시를 그대로 지닌다 — 문단이 확인을 지우지 않는다.」
- `## 상한을 두지 않는다` · `## 링크와 사실의 구분` · 「확인은 저자가 다시 쓸 수 없는 고정점이다」는 글자 그대로 둔다. `## seed 와 brief 둘 다 …` 의 `§6 은 \`S1\` 만(N1b)` 은 **Task 5 가** 고친다(여기서 손대지 않는다).

(b) `request-framing/SKILL.md`
- `## 무엇을 남기고 무엇을 깎는가` 의 「긴 초안은 … 남고, **seed 로 나가는 것은 깎은 것뿐**입니다」 → 「긴 초안은 `$AUDIT` 의 `## 3. 긴 초안` 절에 남고, seed 로 나가는 것은 깎은 것이며 **깎여 나간 항목은 `$AUDIT` 의 `## seed 에서 덜어 낸 것` 표에 한 줄씩 남습니다**(칸: 항목 · 기준 · 원문 위치 · 되살림 — 출처 링크도 여기 출처 항목으로). 덜어 낸 것이 없으면 그 절에 `없음` 한 줄을 적습니다.」
- `## 상태` 표에 행 하나: `| 덜어 낸 것 표 | \`$AUDIT\` 의 \`## seed 에서 덜어 낸 것\` 절 | 압축 직후 — seed 와 함께 쓴다 |`.
- `### 확인 질문` 의 「**고른 풀이만 확인이다.** …」 불릿 뒤에 불릿 하나: 「**사용자가 적은 말은 남긴다.** «기타» 로 적은 말이나 「아니다」 뒤에 덧붙인 말은 그 풀이 줄 끝에 ` — 사용자가 적은 말: 「<그대로>」` 로 남긴다 — 리뷰가 그 말을 사용자 원문(«당신이 답한 것» 과 같은 자리)으로 읽는다. 그 질문을 이미 물은 것으로 쳐도 사용자가 고쳐 준 읽기는 사라지지 않는다.」 `**기록**` 문단의 「`- 내가 읽은 것: 「…」 — 고름` 줄은 …」 뒤에 「꼬리의 «사용자가 적은 말» 칸은 seed 프로필의 정답 출처에 든다.」
- `## 확정 — proceed 게이트` 안, `### 게이트 직전 — 넷, 이 순서로` **앞에** 새 소절:
  ```markdown
  ### 게이트 앞 공시 — 덜어 낸 것 · 확인받지 못한 풀이

  게이트 직전 검사 넷을 돌기 **전에** 두 줄류를 사용자에게 보이고, 같은 줄을 게이트 앞 글에도 다시 싣습니다.

  - `seed 에서 덜어 낸 것 <N>개 — <번호 · 한 줄 이유>` — `$AUDIT` 의 `## seed 에서 덜어 낸 것` 표의 행마다
    한 줄(번호는 표의 행 순서, 이유는 「기준」 칸과 항목 한 줄). 표가 `없음` 이면 `seed 에서 덜어 낸 것 0개`.
  - `확인받지 못한 풀이 <N>개 — <seed 문장 위치>` — seed 에 남은 풀이 문장 중 «(사용자 확인)» 이 붙지 않은
    것 전부. 줄마다 이유를 둘 중 하나로 적는다: 「고르지 않음」(확인 질문에서 고르지 않았거나 «기타» 로 다른 말을
    적었거나 답하지 않은 질문의 풀이 — 사용자가 적은 말이 있으면 그 말을 함께) · 「고른 뒤 바뀜」(골랐지만 압축으로
    글자가 바뀌었거나 표시가 빠짐 — `### seed 를 쓴 직후` 의 `marks` 가 뗀 문장 목록이 이 줄의 재료다).

  덜어 낸 것이 1개 이상이면 `AskUserQuestion` 한 번으로 묻습니다 — 「되살리기」(고르면 이어서 되살릴 항목을
  번호로 고르게 한다. 항목이 넷을 넘으면 `### 확인 질문` 처럼 넷씩 나눈다) · 「그대로 둔다」. 되살린 항목은 seed 에
  돌아가고 표의 「되살림」 칸에 `되살림` 을 적습니다. 되살린 seed 는 바로 넘어가지 않습니다 — seed 를 고친 다른
  경우와 같이 아래 검사 넷(표시 · 저자 편집 공시 · 문구 없는 drop · `check_seed.py`)을 1번부터 다시 거쳐 이
  게이트로 돌아옵니다. seed 리뷰를 다시 돌릴지는 seed 수정의 기존 규칙(③ 「수정 필요」)을 따릅니다.
  ```
  (「「되살림」 칸」 리터럴은 위 문단에 있다.)
- `### 게이트 직전 — 넷, 이 순서로` 의 첫 문단 끝에 「「되살리기」로 seed 를 고쳤을 때도 1번부터 다시 돕니다.」

(c) `interview-seed-template.md` — `## 쓰지 말 것` 의 첫 문단 끝에 문장 하나, 목록 끝에 불릿 하나:
- 첫 문단 끝: 「여기 적힌 이유로 뺀 것도 버리지 않는다 — audit `## seed 에서 덜어 낸 것` 표에 기준 칸 「쓰지 말 것(<무엇>)」으로 남기고, 사용자가 게이트 앞에서 되살릴 수 있다.」
- 불릿 `**절 라벨 · 태그 · URL**` 의 설명 끝에: 「출처 링크는 표에 출처 항목으로 남긴다.」
- `**«(사용자 확인)» 을 추론에**` 불릿은 그대로.

(d) `seed.md`(프로필)
- frontmatter: `  layer1: [unfounded_addition, example_as_requirement, premature_closure, inference_as_decision, omission]` · `must_catch: [unfounded_addition, example_as_requirement, premature_closure, inference_as_decision, omission]`.
- `ground_truth` 값: `"줄 단위 — audit \`## 1. 원문\` 전부 · \`## 2. 질문 전체\` 의 «당신이 답한 것» 줄과 풀이 줄 끝의 «사용자가 적은 말» 칸 · \`## 6. 리뷰 결정\` 의 사용자 문구(각 줄의 큰따옴표 안). 그 밖의 줄(질문 문구 · 선택지 · 내가 읽은 것 · 결정 id · finding 요약 · 덜어 낸 것 표)은 저자가 쓴 것이라 읽되 정답이 아니다"`.
- 층 1 머리 문장: 「**뺄셈 검사**다. 「좋은 프롬프트냐」는 묻지 않는다 — 초안이 원문에 없는 것을 더했거나, 원문에 있는 열림을 닫았거나, 원문에 있는 요구가 seed 에도 audit 의 덜어 낸 것 표에도 없는가만 본다.」
- 층 1 판정 관계: 「… **없는 것을 더했거나, 원문이 열어 둔 것을 닫았거나, 원문에 있는 요구가 seed 에도 audit 의 덜어 낸 것 표(`## seed 에서 덜어 낸 것`)에도 없는가**. 정합이 아니라 뺄셈이다 — …」
- 범주 목록 끝에: 「- `omission` — 원문에 있는 요구가 seed 에도, audit 의 `## seed 에서 덜어 낸 것` 표에도 없음(말없이 빠짐). 표에 있으면 빠짐이 아니라 공시된 덜어 냄이다 — 표의 「기준」이 그 요구를 덜어 낼 이유가 못 되면 그것은 `premature_closure` 나 이 범주다.」
- `## 처분 안내` 의 비신뢰 verbatim 불릿(세 자리)을 고치지 않는다. 그 아래에 불릿 하나: 「번들의 `## 덜어 낸 것` 절은 저자가 쓴 표다 — 읽되 정답이 아니다.」

- [ ] **Step 4: 통과를 확인한다** — `bash plugins/spec-distill/tests/test_distortion_devices.sh` → `Fail: 0`. 닿은 락: `test_compression_adopters.sh` · `test_proceed_gate_adopters.sh` · `test_framing_review_contract.sh` · `test_request_framing_entry.sh` · `test_seed_gate_wiring.sh` · `test_seed_review_profile.sh` · `test_seed_codex_axes.sh` · `test_dispatch_profile_inline.sh` · `test_plain_gate_templates.sh` · shared `test_docreview_profile_schema.sh` · `test_docreview_profiles.sh` · `test_docreview_golden.sh` · `test_docreview_mutations.sh` · `test_docreview_codex.sh` · `test_docreview_layer1_wiring.sh`. 깨진 단언은 새 동작으로 맞추되 지키던 성질을 지우지 않는다. 마지막에 run_suite → `after-t2.txt` · 기준선 대비 새 FAIL 0.

- [ ] **Step 5: 커밋한다** — `feat(spec-distill): seed 압축이 덜어 낸 것을 공시하고 되살릴 길을 준다` + 본문 한 줄(「seed 프로필 층 1 에 omission 을 더한다 — 리뷰어 프로필 편집이다.」) + 트레일러. `test_distortion_devices.sh` 가 `100755` 인지 확인.

---

### Task 3: trivia 우회 앞에서 묻는다 (N11)

설계 §1-8 · AC16a.

**Files:**
- Modify: `plugins/spec-distill/references/trivia-escape.md`
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`(`### 3. trivia 판정`)
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md`(`### 3. trivia 판정`)
- Modify: `plugins/spec-distill/tests/test_distortion_devices.sh`

**Interfaces:**
- Produces: 질문 리터럴 `사소한 일로 보고 게이트를 건너뛴다 — 그대로 / 전체 과정으로` · 선택지 라벨 `그대로` · `전체 과정으로` · 질문 안 사유 `맞은 패턴: <해당 패턴 이름>`.

- [ ] **Step 1: 실패하는 테스트** — `test_distortion_devices.sh` 의 `finish` 앞에(plan-authored test code):

```bash
# ── Task 3 — trivia 우회 앞 질문 (N11 · AC16a) ──
TE="$SD/references/trivia-escape.md"; SI="$SD/skills/spec-interview/SKILL.md"
has   "$TE" '사소한 일로 보고 게이트를 건너뛴다 — 그대로 / 전체 과정으로' "AC16a: 우회 전에 「그대로 / 전체 과정으로」 질문이 있다"
has   "$TE" '맞은 패턴: <해당 패턴 이름>' "AC16a: 질문에 맞은 패턴 이름이 보인다"
has   "$TE" 'label: "전체 과정으로"' "AC16a: 「전체 과정으로」 선택지가 있다"
has   "$TE" 'label: "그대로"' "AC16a: 「그대로」 선택지가 있다"
has   "$TE" '「풀린 입력」의 첫 토큰이 정확히 `force` 면 그 토큰을 떼고 이 판정을 건너뛴다 — 나머지가 「풀린 입력」이 된다' "AC16a: 첫 토큰 force 경로가 그대로다"
hasnt "$TE" '해당하면 다음 메시지를 출력하고 진행하지 않는다' "N11(부재): 묻지 않고 안내만 내고 끝내는 옛 문면이 없다"
for f in "$RF" "$SI"; do
  has "$f" '「전체 과정으로」' "N11: $(basename "$(dirname "$f")") 의 trivia 단계가 「전체 과정으로」 분기를 말한다"
done
```

- [ ] **Step 2: 실패 확인** — 위 줄들 `✗`.

- [ ] **Step 3: 구현**

`trivia-escape.md` — 13~20줄(「해당하면 다음 메시지를 출력하고 …」부터 `→ END`)을 다음으로 바꾼다. 다섯 패턴 · `force` 문장은 그대로:

````markdown
해당하면 진행하기 전에 `AskUserQuestion` 한 번으로 사용자에게 묻는다 — 판정은 모델이 했고, 건너뛸지는 사용자가
고른다. `<해당 패턴 이름>` 과 `<command>` 는 호출한 진입 skill 이 채운다 — `<command>` 는 호출한 진입 skill 의
완전명(`spec-distill:spec-interview` · `spec-distill:request-framing`)이다:

```javascript
AskUserQuestion({ questions: [{
  header: "trivia 판정",
  question: "사소한 일로 보고 게이트를 건너뛴다 — 그대로 / 전체 과정으로. 맞은 패턴: <해당 패턴 이름>.",
  multiSelect: false,
  options: [
    {label: "그대로", description: "게이트를 건너뛴다. 아래 안내를 내고 이 skill 을 끝낸다 — 직접 처리하면 된다."},
    {label: "전체 과정으로", description: "trivia 판정을 건너뛰고 이 skill 의 다음 단계로 간다."}
  ]
}]})
```

- **그대로** — 다음 안내를 내고 진행하지 않는다:

  > ⚠ 이 요청은 trivia 패턴(<해당 패턴 이름>)으로 보입니다. 게이트를 우회해서 직접 처리할 수 있습니다.
  > 그래도 진행하시려면 `/<command> force <요청>` 으로 다시 부르거나 더 자세한 컨텍스트를 알려주세요.

  → END (사용자 후속 입력 대기).
- **전체 과정으로** — 이 판정을 건너뛰고 진입 skill 의 다음 단계(`### 4.`)로 간다. 「풀린 입력」은 그대로다.
````

`request-framing/SKILL.md` `### 3. trivia 판정` 본문 → 「`${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md` 를 읽고 「풀린 입력」을 다섯 패턴과 대조한다. 해당하면 그 파일의 질문을 `<command>` = `spec-distill:request-framing` 으로 채워 띄운다 — 「그대로」면 그 파일의 안내 문면을 내고 진행하지 않고, 「전체 과정으로」면 4 로 간다.」
`spec-interview/SKILL.md` `### 3. trivia 판정` 의 「해당하면 그 파일의 안내 문면을 `<command>` = `spec-distill:spec-interview` 로 채워 내고, 인터뷰를 시작하지 않습니다.」 → 「해당하면 그 파일의 질문을 `<command>` = `spec-distill:spec-interview` 로 채워 띄웁니다 — 「그대로」면 안내 문면을 내고 인터뷰를 시작하지 않고, 「전체 과정으로」면 4 로 갑니다.」 (이 줄은 한 줄 그대로 바꿔 SKILL 자기 줄 수가 늘지 않게 한다.)

- [ ] **Step 4: 통과 확인** — `test_distortion_devices.sh` · `test_request_framing_entry.sh` · `test_conducting_interview_stage.sh`(trivia · force · 줄 상한) · `test_seed_at_path_handoff.sh` · `test_spec_interview_entry.sh` · `test_plain_gate_templates.sh`. run_suite → `after-t3.txt` 새 FAIL 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): trivia 우회 전에 그대로 / 전체 과정으로를 묻는다` + 트레일러.

---

### Task 4: 리뷰 프로필 — 과설계 사다리 · 3건 상한 · 원문 대조 · brief 고칠 자리 · 방향 질문 · 설계문서 scope

설계 §2-1 · §2-2 · §2-3 · §2-4(brief) · §2-5 · §2-8 · §2-9 · RC7 · RC49 · RC66 · RC33 · N1 · N14 · AC5 · AC6(brief) · AC7 · AC16b. **리뷰어 프로필 편집 — 보안 리뷰 대상**(CLAUDE.md 「Persona 파일은 보안-민감 코드」): 리뷰어를 약화하지 않는지(자르지 않는 것 · 금지 어법 · 대체안 필수 · 천장 · Law 1·2·3 · kill switch 줄을 지우지 않는다) Step 4 에서 대조한다.

**Files:**
- Modify: `plugins/spec-distill/references/docreview-profiles/brief.md`
- Modify: `plugins/spec-distill/references/docreview-profiles/design-doc.md`(overdesign 절 · 3건 상한 줄 · §2-9 범주 안내만 — `ground_truth` 줄과 깊이 판정 항목은 R3 몫이라 손대지 않는다)
- Modify: `plugins/spec-distill/tests/test_overdesign_rubric.sh`
- Modify: `plugins/spec-distill/tests/test_distortion_devices.sh`

**Interfaces:**
- Produces: brief 프로필 frontmatter `fix_anchors: ["^0\\.", "^2\\.", "^3\\.", "^4\\.", "^5\\."]` · `must_catch: [direction, distortion, omission, invention, provenance_mislabel, authority_syntax, evidence_unsupported]`. Task 5 가 `ground_truth` 와 원문 자리 문장을 「payload §6 이 전량」으로 고친다 — 이 Task 는 `ground_truth` 를 손대지 않는다.

- [ ] **Step 1: 실패하는 테스트** — `test_distortion_devices.sh` 에(plan-authored test code):

```bash
# ── Task 4 — 리뷰 프로필 (AC5 · AC6 · AC7 · AC16b) ──
BP="$SD/references/docreview-profiles/brief.md"; DP="$SD/references/docreview-profiles/design-doc.md"
for P in "$BP" "$DP"; do
  N="$(basename "$P")"
  hasnt "$P" '번호가 작은 쪽' "AC5($N): 「번호가 작은 쪽」 사다리가 없다"
  hasnt "$P" '한 판정자가 한 라운드에' "AC5($N): 판정자당 라운드 상한이 없다"
  hasnt "$P" '2N+α' "AC5($N): 상한 총량 문구가 없다"
  hasnt "$P" '### 상한' "AC5($N): 「상한」 절이 없다"
  has   "$P" '자르지 않는 쪽' "AC5($N): 비기면 자르지 않는 쪽이다"
  has   "$P" '두 해석을 함께 `decide` 로' "AC5($N): 해석이 갈리면 두 해석을 함께 decide 로"
  has   "$P" '이 문서는 이미 최소다' "AC5($N)(양성 짝): 0건 출구 문구는 남는다"
  has   "$P" '근거를 한두 줄 붙일 수 있다' "AC5($N): 0건 출구에 근거를 허용한다"
  hasnt "$P" '**정당화**도 「찾아봤으나 없음」 서술도 붙이지 않는다' "AC5($N)(부재): 0건 근거 금지 문장이 없다"
  has   "$P" '인용으로 대조한다' "AC5($N): 자르라는 판정은 사용자 원문과 인용으로 대조한다"
  has   "$P" '네 개씩 여러 번 나눠 묻는다' "§2-3($N): 게이트 질문은 넷씩 여러 번"
  has   "$P" '대체안은 같은 항목 안에 필수다' "보안($N): 대체안 필수 규약이 남는다"
  has   "$P" '└ 천장' "보안($N): 천장 규약이 남는다"
  has   "$P" 'Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다' "보안($N): 자르지 않는 것 — Law 와 kill switch 줄이 남는다"
done
assert_eq "$(fm_line "$BP" 'fix_anchors:')" 'fix_anchors: ["^0\\.", "^2\\.", "^3\\.", "^4\\.", "^5\\."]' "AC6: brief fix_anchors 가 §0 · §2~§5 다"
assert_eq "$(fm_line "$BP" 'immutable:')" 'immutable: ["^6\\."]' "AC6: brief §6 immutable 은 그대로다"
assert_eq "$(fm_line "$BP" 'protected_headings:')" 'protected_headings: ["^1\\."]' "AC6: brief §1 protected 는 그대로다"
assert_eq "$(fm_line "$BP" 'must_catch:')" 'must_catch: [direction, distortion, omission, invention, provenance_mislabel, authority_syntax, evidence_unsupported]' "AC7: brief must_catch 에 direction 이 있다"
has   "$BP" '`fix` 는 §0 · §2~§5 에 낼 수 있다' "§2-4: brief 처분 안내의 fix 자리가 frontmatter 와 같다"
hasnt "$BP" '`fix` 는 §0·§2 에만 낼 수 있다' "§2-4(부재): 옛 fix 자리 문장이 없다"
has   "$BP" '§2~§5 가 §6 원문을 어떻게 옮겼는지' "§2-4: brief 층 2 가 §2~§5 를 본다"
hasnt "$BP" '§2 요약이 §6 원문을 어떻게 옮겼는지만 본다' "§2-4(부재): 층 2 가 §2 만 보는 문장이 없다"
has   "$DP" '사용자가 요청한 동작을 자르는 지적은 범주를 `scope` 로' "AC16b: 설계문서 프로필이 사용자 요청 자르기를 scope 로 낸다"
assert_eq "$(fm_line "$DP" 'must_catch:')" 'must_catch: [goal_fit, problem_definition, scope, architecture]' "AC16b: 설계문서 must_catch 는 바뀌지 않는다"
```

- [ ] **Step 2: 실패 확인.**

- [ ] **Step 3: 구현** — 두 프로필 공통(overdesign 절):

- `### 판정 절차 — 사다리` 첫 문단의 「**성립하는 첫 단에서 멈춘다.** 두 단이 성립하면 **번호가 작은 쪽**을 고른다.」 → 「**성립하는 단을 다 본다.** 두 단이 비기면 **자르지 않는 쪽**(번호가 큰 쪽)을 고른다. 한 구조를 두고 해석이 둘로 갈리면 하나로 줄이지 않고 두 해석을 함께 `decide` 로 낸다 — 어느 쪽인지는 사용자가 정한다.」
- 사다리 아래의 `⚠ 작은 쪽은 **언제나 더 많이 자르는** …` 문단 → 「이 축은 과설계 **경고**다 — 경고는 남기되 판정이 절감 쪽으로만 기울지 않게 동점은 자르지 않는 쪽으로 간다. 균형 장치는 이 규칙과 `└ 천장` 둘이다.」
- `### 자르지 않는 것` 첫 불릿 뒤에 불릿 하나(파일마다 자기 원문 자리를 댄다 — 두 파일 모두 「인용으로 대조한다」 리터럴을 지닌다):
  - brief.md: 「자르라는 판정이 가리키는 것이 사용자 원문(§6)에 있는지 인용으로 대조한다 — 원문에 있으면 「자르기」가 아니라 `decide` 로 올리고 `evidence` 에 그 원문 `S<N>` 을 인용한다.」
  - design-doc.md: 「자르라는 판정이 가리키는 것이 사용자 원문(frontmatter `source_interview` 가 가리키는 brief 의 §6)에 있는지 인용으로 대조한다 — 원문에 있으면 「자르기」가 아니라 `decide` 로 올리고 `evidence` 에 그 원문 `S<N>` 을 인용한다.」
- `### 0건 출구` 의 「**정당화**도 「찾아봤으나 없음」 서술도 붙이지 않는다.」 → 「근거를 한두 줄 붙일 수 있다(무엇을 보고 이미 최소라고 판단했는가).」 나머지 문장은 그대로.
- `### 상한` 절 전체(제목 포함)를 다음으로 바꾼다:
  ```markdown
  ### 개수

  이 축의 finding 수에 상한을 두지 않는다 — 판정자가 개수를 맞추려고 자르지 않는다. 게이트는 질문을
  `AskUserQuestion` 네 개씩 여러 번 나눠 묻는다.
  ```

brief.md 만:
- frontmatter `fix_anchors: ["^0\\.", "^2\\.", "^3\\.", "^4\\.", "^5\\."]` · `must_catch: [direction, distortion, omission, invention, provenance_mislabel, authority_syntax, evidence_unsupported]`. `immutable` · `protected_headings` · `layer_rubric` 는 그대로.
- `## 층 2 — 충실도` 머리: 「문서 **내부 대조**다. §2~§5 가 §6 원문을 어떻게 옮겼는지 본다 — §2 요약 · §3 열린 질문 · §4 조사 · §5 위험에서 원문의 요구가 빠졌거나 바뀐 곳도 `omission` · `distortion` 으로 잡는다. 외부 정보는 이 층의 오염원이다.」
- `## 처분 안내` 첫 불릿: 「`fix` 는 §0 · §2~§5 에 낼 수 있다(§1 은 보호 — 사용자 결정). §6 원문은 어떤 처분도 바꾸지 못한다 — 이미 있는 원문 글자는 그대로이고, 리뷰 중 사용자 결정 발화가 새 `S<N>` 으로 §6 끝에 더해질 뿐이다(추가만 허용).」 둘째 불릿의 「§0·§2 의 해석이다」 → 「§0 · §2~§5 의 해석이다」.

design-doc.md 만:
- 층 1 목록의 `scope` 불릿 끝에: 「원문 대조(아래 「자르지 않는 것」)로 확인된, 사용자가 요청한 동작을 자르는 지적은 범주를 `scope` 로 낸다(조용히 좁아진 곳) — `overdesign` 으로 내지 않는다.」
- frontmatter 는 손대지 않는다.

`test_overdesign_rubric.sh` 의 AC8 · AC10 · AC11 · I5(b) 단언(사다리 「번호가 작은 쪽」 · 「한 방향 압력」 · 0건 출구 정당화 금지 · 「상한」 절 · 3건 핀)을 새 문면으로 바꾼다 — 존재가 사라지는 것은 부재 단언으로 뒤집고, 각 부재에 같은 절의 존재 짝을 둔다(예: 「상한」 절 추출 양성 짝 → 「개수」 절 추출 양성 짝). 이 파일 머리 주석의 「상한의 무이빨」 문장은 「상한을 없앴다(R2 · B3)」로 고친다.

- [ ] **Step 4: 통과 확인 + 약화 대조** — `test_distortion_devices.sh` · `test_overdesign_rubric.sh` · `test_brief_codex_axes.sh` · `test_dispatch_profile_inline.sh` · `test_brief_agents.sh` · `test_reviewing_spec_*.sh` · shared `test_docreview_profile_schema.sh` · `test_docreview_profiles.sh` · `test_docreview_golden.sh` · `test_docreview_mutations.sh` · `test_docreview_codex.sh` · `test_docreview_intent.sh` · `test_docreview_layer1_wiring.sh` · `test_docreview_advice*.sh`. 그리고 `git -C <worktree> diff HEAD -- plugins/spec-distill/references/docreview-profiles/` 를 읽어 「자르지 않는 것」 목록 · 금지 어법 · 대체안 필수 · 천장 · 층 2 범주 정의 줄이 하나도 지워지지 않았음을 확인해 진행 기록에 적는다. run_suite → `after-t4.txt` 새 FAIL 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 과설계 사다리의 절감 쪽 압력을 끄고 brief 리뷰가 §2~§5 와 방향을 묻게 한다` + 본문 「리뷰어 프로필 편집 — 보안 리뷰 대상. 자르지 않는 것 · 금지 어법 · 대체안 · 천장은 그대로다.」 + 트레일러.

---

### Task 5: payload §6 은 원문 전량, 추가만 허용 (N7)

설계 §3-2 · AC11 · Deferred(엔진 얼림 실측).

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`(N1b)
- Modify: `plugins/spec-distill/scripts/check_verbatim_coverage.py`(합집합 · L1)
- Modify: `plugins/spec-distill/templates/interview-brief-template.md`(§6 · frontmatter 주석 · §2 안내)
- Modify: `plugins/spec-distill/references/docreview-profiles/brief.md`(`ground_truth` · 원문 자리 문장)
- Modify: `plugins/spec-distill/references/compression.md`(`§6 은 \`S1\` 만(N1b)`)
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md`(머리 문단 · Step A.3 의 §6 문장 · Step A.3 의 N1b 문장)
- Modify: `plugins/spec-distill/skills/spec-interview/references/seed-input.md`(「payload §6은 `S1` 으로 불변이므로」)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`(`## 수정 권한` 표 · 결정 발화 추가 문단 · 진입 게이트 rc 표의 「audit §6 에 추가만」)
- Modify: `plugins/spec-distill/tests/fixtures/*`(§6 스윕), `test_check_brief.sh`(U2-T3 · N1b 절), `test_check_verbatim_coverage.sh`
- Create: `plugins/spec-distill/tests/test_brief_verbatim_full.sh`
- Modify: `plugins/spec-distill/tests/test_distortion_devices.sh`

**Interfaces:**
- Produces: `check_brief.payload_verbatim_n1b_failures(payload_text: str, audit_anchors: set) -> list[str]`(옛 `payload_verbatim_is_s1_only` 대체 — 호출 그래프에서 `_body` · `_section_text` 에 닿지 않는다. audit 앵커 집합은 `gate()` 가 `verbatim_anchors(audit_text)` 로 구해 넘긴다). `payload_verbatim_anchors` 는 그대로 — Task 6 이 그것으로 §1 · 해결 토큰의 `S<n>` 을 대조한다.
- Produces: `check_verbatim_coverage.parse_section6_union` — 양쪽에 같은 앵커가 있으면 정규화 글자가 같을 때만 받는다. L1 = (state id ∪ audit 앵커) ⊆ payload 앵커.

- [ ] **Step 1: 실패하는 테스트** — `plugins/spec-distill/tests/test_brief_verbatim_full.sh`(plan-authored test code):

```bash
#!/usr/bin/env bash
# R2 Task 5 — payload §6 은 S1~Sn 원문 전량이고 추가만 허용(설계 §3-2 · AC11).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"; FX="$ROOT/plugins/spec-distill/tests/fixtures"
TMP="$(mktemp -d -t sd-v6-XXXXXX)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

# 기반: 스윕을 마친 정상 쌍(이 Task 의 Step 3 (f) 뒤 payload §6 이 S1~Sn 전량이다)
base() {
  cp "$FX/interview-brief-valid.md" "$TMP/p.md"; cp "$FX/interview-brief-valid.audit.md" "$TMP/p.audit.md"
  python3 -I -X utf8 - "$TMP/p.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
p.write_text(re.sub(r"(?m)^audit_file:.*$", "audit_file: p.audit.md", t, count=1), encoding="utf-8")
PY
}
gate() { python3 "$S/check_brief.py" gate "$TMP/p.md" > "$TMP/out" 2>&1; }
# payload §6 에서 앵커 하나의 항목(머리 줄 + 이어지는 들여쓴 줄)을 지운다
drop_anchor() { python3 -I -X utf8 - "$TMP/p.md" "$1" <<'PY'
import re, sys, pathlib
p, sid = pathlib.Path(sys.argv[1]), sys.argv[2]
lines, out, skip = p.read_text(encoding="utf-8").split("\n"), [], False
for ln in lines:
    if re.match(r"^\s*[-*]\s+\*\*S\d+\*\*", ln):
        skip = bool(re.match(r"^\s*[-*]\s+\*\*%s\*\*" % re.escape(sid), ln))
    elif skip and not (ln.startswith(" ") or ln.strip() == ""):
        skip = False
    if not skip:
        out.append(ln)
p.write_text("\n".join(out), encoding="utf-8")
PY
}

base; gate; assert_eq "$?" "0" "full_ok: payload §6 이 S1~Sn 전량이면 통과한다 (양성 대조)"
base; drop_anchor S2; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q 'N1b' "$TMP/out"; } \
  && ok "n1b_missing_audit: audit §6 의 S2 가 payload §6 에 없으면 red (N1b)" || no "n1b_missing_audit: rc=$rc"
base; drop_anchor S1; gate; rc=$?
[ "$rc" -ne 0 ] && ok "n1b_no_s1: S1 이 없으면 red" || no "n1b_no_s1: S1 없이 통과했다"

# check_verbatim_coverage — 같은 앵커가 양쪽에 같은 글자면 통과, 다르면 구조 위반(rc 1)
CV="$S/check_verbatim_coverage.py"
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"; cp "$FX/brief-verbatim-ok.audit.md" "$TMP/v.audit.md"
STATE="$FX/brief-verbatim-ok.state.local.md"
[ -f "$STATE" ] || STATE="$(ls "$FX"/brief-verbatim-ok*.state* 2>/dev/null | head -1)"
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; assert_eq "$?" "0" "dup_same: payload · audit 의 같은 앵커가 같은 글자면 통과한다"
python3 -I -X utf8 - "$TMP/v.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
# payload 쪽 S2 본문의 첫 인용 줄 끝에 글자를 덧붙인다 — 지적에 맞춰 payload 사본을 고친 모양
t2 = re.sub(r'(\*\*S2\*\*[^\n]*\n\s*>\s*"?[^\n]*?)("?\s*\n)', r"\1 (고침)\2", t, count=1)
assert t2 != t, "S2 항목을 찾지 못했다 — 픽스처를 확인하라"
p.write_text(t2, encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; rc=$?
{ [ "$rc" -eq 1 ] && grep -q '글자가' "$TMP/cv"; } \
  && ok "dup_differs: 같은 앵커의 글자가 다르면 구조 위반(rc 1)" || no "dup_differs: rc=$rc $(head -c 300 "$TMP/cv")"
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"
python3 -I -X utf8 - "$TMP/v.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
lines, out, skip = t.split("\n"), [], False
for ln in lines:
    if re.match(r"^\s*[-*]\s+\*\*S\d+\*\*", ln):
        skip = bool(re.match(r"^\s*[-*]\s+\*\*S2\*\*", ln))
    elif skip and not (ln.startswith(" ") or ln.strip() == ""):
        skip = False
    if not skip:
        out.append(ln)
p.write_text("\n".join(out), encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$STATE" "$TMP/v.audit.md" > "$TMP/cv" 2>&1; rc=$?
{ [ "$rc" -eq 1 ] && grep -q 'S2' "$TMP/cv"; } \
  && ok "payload_missing: state · audit 에 있는 S2 가 payload §6 에 없으면 위반(rc 1)" || no "payload_missing: rc=$rc"

# 추가만 허용 — 결정 발화를 payload §6 · audit §6 · state 에 같은 write 로 더하면 다음 원문 검사가 통과한다
cp "$FX/brief-verbatim-ok.md" "$TMP/v.md"; cp "$FX/brief-verbatim-ok.audit.md" "$TMP/v.audit.md"; cp "$STATE" "$TMP/st.md"
python3 -I -X utf8 - "$TMP/v.md" "$TMP/v.audit.md" "$TMP/st.md" <<'PY'
import re, sys, pathlib
pay, aud, st = (pathlib.Path(x) for x in sys.argv[1:4])
ids = [int(x) for x in re.findall(r"\*\*S(\d+)\*\*", pay.read_text(encoding="utf-8"))]
n = max(ids) + 1
item = '\n- **S%d** 🗣 brief 리뷰 결정:\n  > "방향은 그대로 두고 범위만 줄인다"\n' % n
for f in (pay, aud):
    t = f.read_text(encoding="utf-8")
    m = re.search(r"(?m)^## 6\..*$", t)
    nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
    cut = m.end() + nxt.start() if nxt else len(t)
    f.write_text(t[:cut].rstrip("\n") + "\n" + item + "\n" + t[cut:], encoding="utf-8")
s = st.read_text(encoding="utf-8")
entry = '  - id: S%d\n    source: verbatim\n    round: 99\n    text: "방향은 그대로 두고 범위만 줄인다"\n' % n
s = re.sub(r"(?m)^(user_statements:\s*\n)", lambda m: m.group(1) + entry, s, count=1)
st.write_text(s, encoding="utf-8")
PY
python3 "$CV" "$TMP/v.md" "$TMP/st.md" "$TMP/v.audit.md" > "$TMP/cv" 2>&1
assert_eq "$?" "0" "append_only: 결정 발화를 세 자리에 같은 write 로 더한 뒤 원문 검사가 통과한다"

finish
```
(픽스처의 state 파일 이름은 실제 이름으로 맞춘다 — `ls plugins/spec-distill/tests/fixtures | grep brief-verbatim-ok` 로 확인하고, state fixture 가 없으면 `test_check_verbatim_coverage.sh` 가 state 를 만드는 방식을 이 파일에 옮겨 쓴다. 이 조정은 plan-authored 테스트의 배선 수정이고 단언을 약하게 하지 않는다.)

`test_distortion_devices.sh` 에:

```bash
# ── Task 5 — payload §6 전량 · 추가만 (AC11) ──
RB="$SD/skills/reviewing-brief/SKILL.md"; BT="$SD/templates/interview-brief-template.md"; FN="$SD/skills/spec-interview/references/finishing.md"
hasnt "$RB" '**불변** — 어떤 처분도 닿지 못한다' "AC11(부재): 수정 권한 표에 payload §6 「불변」이 없다"
has   "$RB" '**추가만** — 이미 있는 원문 글자는 어떤 처분도 고치지 못한다' "AC11: 수정 권한 표에 payload §6 「추가만」이 있다"
has   "$RB" '같은 write' "AC11: 결정 발화를 payload §6 · audit §6 · state 에 같은 write 로 더한다"
has   "$BT" '추가만 허용' "AC11: brief 템플릿 §6 이 추가만 허용을 말한다"
hasnt "$BT" '최초 요청 원문 하나만' "N7(부재): brief 템플릿 §6 의 「S1 하나만」이 없다"
hasnt "$FN" '§6 은 `S1` 만(N1b)' "N7(부재): finishing 머리 문단의 「§6 은 S1 만」이 없다"
hasnt "$C"  '§6 은 `S1` 만(N1b)' "N7(부재): 압축 규약의 「§6 은 S1 만」이 없다"
has   "$C"  'S1~Sn 전부(N1b)' "N7: 압축 규약이 §6 은 S1~Sn 전부라고 말한다"
```

- [ ] **Step 2: 실패 확인** — 새 두 파일 실행 → `n1b_missing_audit` 는 지금 통과할 수도 있다(옛 N1b 는 S2 를 red 로 냄) — `full_ok`(스윕 전이라 지금 red) · `dup_same` · `payload_missing` · `append_only` 가 `✗` 인 것을 확인한다.

- [ ] **Step 3: 구현**

(a) `check_brief.py` — `payload_verbatim_is_s1_only` 를 지우고:

```python
S_NUM_RE = re.compile(r"^S(\d+)$")


def payload_verbatim_n1b_failures(payload_text: str, audit_anchors: set) -> list[str]:
    """N1b — payload §6 은 사용자 원문 **S1~Sn 전부**다(R2 · 설계 §3-2). 코퍼스는 payload 원문 §6 span
    (`payload_verbatim_anchors` — 펜스를 벗기지 않는다, v0.46.0). 셋을 본다: S1 이 있다 · 번호가 S1 부터 가장
    큰 번호까지 빠짐없다 · audit §6 의 앵커가 전부 payload §6 에도 있다(audit 은 S2 이상을 같은 글자로 겹쳐
    가진다 — 글자 대조는 `check_verbatim_coverage.py`). state 의 발화 전량과의 대조도 그 스크립트가 한다 —
    이 게이트는 brief 파일만 읽는다. §6 이 없거나 경계가 유일하지 않으면 앵커가 공집합이라 S1 부재로 red 다."""
    anchors = payload_verbatim_anchors(payload_text)
    nums = sorted(int(m.group(1)) for a in anchors for m in [S_NUM_RE.match(a)] if m)
    out = []
    if 1 not in nums:
        out.append("payload §6 에 S1(최초 요청 원문)이 없다")
    if nums:
        gaps = [f"S{n}" for n in range(1, nums[-1] + 1) if n not in nums]
        if gaps:
            out.append("payload §6 의 원문 번호가 빠졌다: " + ", ".join(gaps))
    missing = sorted(a for a in audit_anchors if a not in anchors)
    if missing:
        out.append("audit §6 의 " + ", ".join(missing) + " 가 payload §6 에 없다 — payload §6 은 원문 전량이다")
    return out
```
`gate()` 의 N1b 자리(옛 `payload_verbatim_is_s1_only` 호출과 1383줄 근처 메시지 「(S1만 payload에, 나머지 전량은 audit §6에)」)를 `for msg in payload_verbatim_n1b_failures(text, verbatim_anchors(audit_text)): failures.append(f"N1b — {msg}")` 모양으로 바꾼다(실제 변수 이름 · 실패 목록 이름은 그 함수의 것을 따른다). audit 을 못 읽은 경로에서는 `audit_anchors=set()` 을 넘긴다. `bijection_c_errors` docstring 의 「`S1`은 payload에, `S2` 이상은 audit에 살므로」 → 「payload §6 이 전량이고 audit §6 은 S2 이상의 사본이다 — 합집합은 사본이 어긋났을 때도 dangling 을 잘못 내지 않게 한다」. `payload_verbatim_anchors` docstring 의 「N1b의 등식(`!= {"S1"}`)」 → 「N1b 의 S1 부재」. `test_check_brief.sh` 의 ast 락(N1a · N1b 호출 그래프가 `_body`/`_section_text` 에 닿지 않는다)이 함수 이름을 문다면 새 이름으로 바꾼다 — 새 함수는 `verbatim_anchors` 를 부르지 않으므로(그것은 `gate()` 가 부른다) 성질이 유지된다.

(b) `check_verbatim_coverage.py`:

```python
def parse_section6_union(payload_text: str, audit_text: str) -> dict[str, str]:
    """payload §6 ∪ audit §6. payload §6 이 S1~Sn 원문 전량이고, audit §6 은 S2 이상을 **같은 글자로** 겹쳐
    가진다(R2 · 설계 §3-2). 같은 앵커가 양쪽에 있으면 정규화(N1–N5) 뒤 글자가 같을 때만 받는다 — 다르면
    한쪽을 지적에 맞게 고친 세탁이라 구조 위반이다. 한쪽 절 부재는 ParseError(호출자가 exit 3)."""
    pay = parse_section6(payload_text, "payload")
    aud = parse_section6(audit_text, "audit")
    differ = sorted(k for k in set(pay) & set(aud) if normalize(pay[k]) != normalize(aud[k]))
    if differ:
        raise StructuralViolation(
            f"{', '.join(differ)} 앵커의 글자가 payload §6 과 audit §6 에서 다르다 — 이미 있는 원문 글자는 고치지 못한다")
    merged = dict(aud)
    merged.update(pay)
    return merged
```
`run()` 에서 `items = parse_section6_union(...)` 다음에 payload 앵커 집합을 따로 받는다(`pay_ids = set(parse_section6(payload_text, "payload"))` — 같은 함수를 한 번 더 부르는 비용은 무시한다). L1 루프를 `if sid not in pay_ids: result["missing_ids"].append(sid); continue` 로 바꾸고, 루프 뒤에 audit-only 앵커(`set(items) - pay_ids`)를 `missing_ids` 에 더한다(정렬 · 중복 없이). 머리 docstring 의 L1 줄을 「L1: state `user_statements[].id` ∪ audit §6 앵커 ⊆ **payload** §6 앵커 집합. 위반 → red」로, 4~6줄의 「`S1`은 payload에, `S2` 이상은 audit에」 서술을 「payload §6 이 원문 전량이고 audit §6 은 S2 이상의 같은 글자 사본이다(R2)」로 고친다.

(c) brief 템플릿:
- frontmatter 주석 `evidence: S1              # payload §6엔 S1만 산다 — S2 이상 원문의 evidence는 audit §6 이관` → `evidence: S1              # payload §6 의 S<N> — §6 이 원문 전량이다`.
- §2 안내 「원문은 payload §6(S1)과 audit §6(S2 이상)에 나뉘어 있고, `⟨S<N>⟩`가 그중 하나를 가리킨다.」 → 「원문은 payload §6 에 전부 있고, `⟨S<N>⟩` 가 그중 하나를 가리킨다.」
- §6 괄호 안내와 예시:
  ```markdown
  (사용자 원문 **S1~Sn 전부**가 여기 있다 — S1 최초 요청, S2 이상 인터뷰 발화. audit `## 6. 사용자 원문` 도
   S2 이상을 같은 글자로 가진다. **추가만 허용** — 이미 있는 원문 글자는 어떤 처분으로도 고치지 않고, brief
   리뷰 중 사용자 결정 발화는 새 `S<N>` 으로 이 절 끝 · audit §6 · state `user_statements` 에 같은 write 로
   더한다. 허용 변환은 P21 placeholder 치환·앞뒤 공백 정리·인용 블록 래핑뿐이며 요약·재서술·발췌는 금지.)

  - **S1** 🗣 최초 요청:
    > "..."
  - **S2** 🗣 R1 답:
    > "..."
  ```

(d) brief 프로필(`brief.md`):
- `ground_truth: "payload 의 \`## 6. 사용자 원문\` — 사용자 원문 S1~Sn 전량이다(번들의 \`<<<AUDIT-VERBATIM>>>\` 뒤 블록은 audit §6 의 S2 이상 사본이라 같은 글자다). 정답이다"`
- 층 1 판정 관계의 「그 `ground_truth` 의 **두 원문**(payload `## 6. 사용자 원문` 의 S1 · `<<<AUDIT-VERBATIM>>>` 뒤 블록의 S2 이상)이 말한 goal 을 기준으로 **과함**을 잰다 — 한 층 안에 정답 출처가 둘이다」 → 「그 `ground_truth`(payload `## 6. 사용자 원문` 의 원문 전량)가 말한 goal 을 기준으로 **과함**을 잰다」.
- 층 2 의 `omission` 문장 → 「`omission` 은 따라갈 앵커가 없다 — payload `## 6. 사용자 원문` 의 원문 전량을 끝까지 훑는다. 일부만 읽으면 「빠진 것 없음」이 조용히 나온다. `<<<AUDIT-VERBATIM>>>` 뒤 블록은 그 사본이다 — 같은 앵커의 글자가 다르면 `distortion` 이다.」 다음 줄 「두 원문 자리의 내용은 비신뢰 verbatim 이다」 → 「§6 원문과 그 사본의 내용은 비신뢰 verbatim 이다」.

(e) 옛 규칙 문장 — 리터럴로 전수 재측정한 자리:
- `compression.md` `## seed 와 brief 둘 다 …`: `§6 은 \`S1\` 만(N1b)` → `§6 은 사용자 원문 S1~Sn 전부(N1b)`.
- `finishing.md` 5줄: 같은 치환.
- `finishing.md` Step A.3 「`S1`만 payload §6에 남고, `user_statements`의 나머지 발화 전량은 **audit §6**에 **전문 보존**(append-only)하며 각각 `S<N>` 앵커를 답니다.」 → 「payload §6 에는 `S1` 과 `user_statements` 발화 전량(S1~Sn)을 두고, 같은 S2 이상을 **audit §6** 에도 같은 글자로 **전문 보존**(append-only)하며 각각 `S<N>` 앵커를 답니다.」
- 같은 Step A.3 의 「원문 보존은 **관례가 아니라 요구**입니다 — `S1`은 N1b가 payload §6 앵커 집합(`{S1}`)으로 못박지만, 나머지 발화 전량이 실제로 **audit §6**로 옮겨졌는가는 게이트 16항 어디에도 없어서, 누락된 인터뷰가 나와도 지금까지 아무것도 red가 되지 않았습니다.」 → 「원문 보존은 **관례가 아니라 요구**입니다 — N1b 가 payload §6 앵커가 S1 부터 빠짐없고 audit §6 앵커를 다 포함하는지 보고, `check_verbatim_coverage.py`(brief 리뷰 진입 게이트)가 state 발화 전량이 payload §6 에 같은 글자로 있는지 봅니다.」
- `finishing.md` Step A.5 의 `AUDIT="${PAYLOAD%.md}.audit.md"                      # payload 의 audit sidecar (§6 S2+ 원문)` 주석은 그대로 둔다(사실이다).
- `seed-input.md` 41~42줄 「(payload §6은 `S1` 으로 불변이므로 새 앵커는 audit에만 붙는다)」 → 「(새 앵커는 payload §6 끝과 audit §6 에 같은 글자로 붙는다 — 이미 있는 원문 글자는 고치지 않는다)」.
- `reviewing-brief/SKILL.md` `## 수정 권한` 표 두 행:
  ```markdown
  | payload §6 (`S1`~`Sn`) | **추가만** — 이미 있는 원문 글자는 어떤 처분도 고치지 못한다. 결정 발화만 새 `S<N>` 으로 끝에 더한다 |
  | audit §6 (`S2` 이상) | **append-only** — `S<N>` 추가만, payload §6 과 같은 글자. 기존 본문을 고칠 수 있으면 「지적에 맞게 원문을 고쳐 통과」 라는 laundering 이 열린다 |
  ```
  그 아래 문단 「… 그 결정 발화를 audit §6 에 새 `S<N>` 으로 **추가**한다(state `user_statements` 에도)」 → 「… 그 결정 발화를 새 `S<N>` 으로 payload §6 끝 · audit §6 · state `user_statements` 에 **같은 write** 로 **추가**한다」.
  진입 게이트 rc 표 153줄 「audit §6 에 **추가만** 해서 보완하고」 → 「payload §6 · audit §6 에 **추가만** 해서(같은 글자로) 보완하고」.
- 그 밖에 `git -C <worktree> grep -n -E "S1\`? ?만|S1만|으로 불변|S2\` 이상은 audit|하나만\*\* 여기" -- plugins/spec-distill ':!*CHANGELOG.md' ':!plugins/spec-distill/tests/*'` 를 다시 돌려 남은 자리가 없음을 확인한다(남으면 같은 뜻으로 고친다).

(f) fixture 스윕 — `~/.claude/sdd-mirror/r2-impl/t5/sweep.py`: `plugins/spec-distill/tests/fixtures/` 의 `type: interview-brief` payload 마다 짝 audit(`*.audit.md`)의 §6 항목(머리 줄 `- **S<N>** …` + 이어지는 들여쓴 줄)을 payload §6 의 마지막 항목 뒤에 번호 순으로 복사한다(이미 payload 에 있는 번호는 건너뛴다). **복사하지 않는** 것: 이름이 §6 · 앵커 · verbatim 의 결함을 재는 픽스처(`*-dup-*` · `*-missing-anchor*` · `*-no-sec6*` · `*-anchor-*` · `*-evidence-dangling*` · `*-audit-drop-*` · `brief-verbatim-*`) — 이것들은 하나씩 열어 의도를 보고 새 규칙에서 같은 실패 이유를 내도록 손으로 고친다(예: `brief-verbatim-dup-across` 는 「같은 앵커 · 다른 글자」로 바꿔야 red 가 유지된다). 바뀐 파일 목록과 손으로 고친 픽스처마다 한 줄 이유를 진행 기록에 남긴다.

`test_check_brief.sh` 의 U2-T3(「payload §6 에 S2 → red (N1b 위쪽)」 등)과 `N1b:` 절을 새 규칙으로 바꾼다: S2 가 payload 에 있어도 green(전량이면) · audit 앵커 누락 red · 번호 빠짐 red · 빈 §6 red · §6 안 펜스의 `- **S5**` 는 audit 에 없고 번호가 빠지면 red(코퍼스가 출하 바이트라는 성질 유지). `test_check_verbatim_coverage.sh` 의 「양쪽 같은 앵커 → append-only 위반」 단언은 「같은 앵커 · 다른 글자 → 위반」과 「같은 앵커 · 같은 글자 → 통과」 둘로 바꾼다.

- [ ] **Step 4: 통과 확인** — `test_brief_verbatim_full.sh` · `test_distortion_devices.sh` · `test_check_brief.sh` · `test_check_verbatim_coverage.sh` · `test_check_brief_frontmatter.py` · `test_brief_review_entry.sh` · `test_brief_bundle.sh` · `test_brief_inline_blob.sh` · `test_reviewing_brief_skill.sh` · `test_brief_no_length_cap.sh` · `test_brief_no_statement_cap.sh` · `test_conducting_interview_stage.sh` · `test_seed_input_provenance.sh` · `test_compression_adopters.sh` · `test_roadmap_status.sh` · `test_bundle_coverage.sh`. run_suite → `after-t5.txt` 새 FAIL 0.

- [ ] **Step 5: 엔진 얼림 검사 실측(Deferred)** — `~/.claude/sdd-mirror/r2-impl/t5/freeze.sh` 에 스크립트를 써서 임시 디렉토리에서 돈다(리포 안에서 엔진 상태를 만들지 않는다): 스윕된 `interview-brief-valid.md` 쌍을 임시 디렉토리에 복사 → `python3 plugins/spec-distill/scripts/docreview_state.py` 로 `init --profile <brief 프로필 절대경로> --doc <임시 payload 절대경로> --state-dir <임시>` → 라운드 1 시작(`begin-round`) → payload §6 끝에 새 `S<N>` 항목 추가 → 라운드 2 시작 → 그 라운드의 얼림 diff(`finalize` 의 출력 또는 `round_diff` 를 부르는 서브커맨드 — 정확한 이름은 `docreview_state.py --help` 와 `shared/docreview/references/reviewing-document.md` 의 단계에서 확인한다)를 본다. 결과를 둘 중 하나로 진행 기록 · `~/.claude/sdd-mirror/r2-impl/t5/freeze.txt` 에 적는다:
  - `#6-…` 앵커가 `changed`(`frozen_change`)로 나온다 → `reviewing-brief/SKILL.md` `## 수정 권한` 문단 끝에 「엔진의 얼림 검사는 payload §6 끝의 추가도 `frozen_change` 로 보인다 — 그 항목이 결정 발화 추가 한 건이면 게이트에서 그렇게 밝히고 그대로 둔다(이미 있는 원문 글자가 바뀐 것이면 되돌린다). 엔진 쪽의 「추가만 허용」 구분은 R2a 의 일이다.」를 더하고, PR 후속에 「R2a — 엔진 얼림 검사의 §6 추가만 허용 구분」을 싣는다.
  - 안 나온다(면제됨) → 그 사실과 면제 경로를 적고 문서는 바꾸지 않는다.
  실측을 못 하면(엔진 CLI 가 다른 단계를 요구) 「확인 못 함 — <이유>」로 적고 첫째 경로의 문장을 「보일 수 있다」로 넣는다. 꾸며 적지 않는다.

- [ ] **Step 6: 커밋** — `feat(spec-distill): payload §6 에 사용자 원문 전량을 두고 추가만 허용한다` + 트레일러.

---

### Task 6: brief 형식 — §4 여러 줄 · §1 출처 표시 · 해결한 결정도 §3 에 (RC39 · N21 · N22)

설계 §3-6 · §3-11(기계 · 템플릿) · §3-12 · AC14 · AC16d(N21 · N22).

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Modify: `plugins/spec-distill/templates/interview-brief-template.md`(§0 안내 · §1 · §3 · §4 안내)
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md`(Step A.5 의 결정 연결 · §0 상태 토큰 규약 — `5.` 항목)
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md`(라운드 규약의 「하위 불릿은 쓰지 않는다」 문장 — 한 줄 치환, 줄 수 불변)
- Modify: `plugins/spec-distill/tests/fixtures/*`(§1 표시 · §3 해결 결정 스윕), `test_check_brief.sh`
- Create: `plugins/spec-distill/tests/test_brief_form_r2.sh`

**Interfaces:**
- Consumes: Task 5 의 `payload_verbatim_anchors(payload_text) -> set`.
- Produces: `section4_items(text) -> list[tuple[str, list[str]]]` · `section4_body_failures(text) -> list[str]` · `section1_provenance_failures(text, anchors: set) -> list[str]` · `resolved_decision_failures(text, anchors: set) -> list[str]`. 실패 메시지 머리말 `§4 항목` · `§1` · `해결`.

- [ ] **Step 1: 실패하는 테스트** — `plugins/spec-distill/tests/test_brief_form_r2.sh`(plan-authored test code):

```bash
#!/usr/bin/env bash
# R2 Task 6 — §4 여러 줄 항목(RC39 · AC14) · §1 출처 표시(N21) · 해결한 결정도 §3 에(N22).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"; FX="$ROOT/plugins/spec-distill/tests/fixtures"
TMP="$(mktemp -d -t sd-form-XXXXXX)" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

base() {
  cp "$FX/interview-brief-valid.md" "$TMP/p.md"; cp "$FX/interview-brief-valid.audit.md" "$TMP/p.audit.md"
  python3 -I -X utf8 - "$TMP/p.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
p.write_text(re.sub(r"(?m)^audit_file:.*$", "audit_file: p.audit.md", t, count=1), encoding="utf-8")
PY
}
gate() { python3 "$S/check_brief.py" gate "$TMP/p.md" > "$TMP/out" 2>&1; }
# 절 본문 갈아 끼우기: put <절 번호> <새 본문 파일>
put() { python3 -I -X utf8 - "$TMP/p.md" "$1" "$2" <<'PY'
import re, sys, pathlib
p, num, new = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
t = p.read_text(encoding="utf-8")
m = re.search(r"(?m)^## %s\..*$" % re.escape(num), t)
nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
end = m.end() + nxt.start() if nxt else len(t)
p.write_text(t[:m.end()] + "\n\n" + new.strip("\n") + "\n\n" + t[end:], encoding="utf-8")
PY
}
# 절 끝에 줄 더하기: app <절 번호> <줄 파일> — 기반 픽스처의 결정 · 연결을 지우지 않는다(지우면 무관한 술어가 red 를 낸다)
app() { python3 -I -X utf8 - "$TMP/p.md" "$1" "$2" <<'PY'
import re, sys, pathlib
p, num, add = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
t = p.read_text(encoding="utf-8")
m = re.search(r"(?m)^## %s\..*$" % re.escape(num), t)
nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
end = m.end() + nxt.start() if nxt else len(t)
p.write_text(t[:end].rstrip("\n") + "\n" + add.strip("\n") + "\n\n" + t[end:], encoding="utf-8")
PY
}
# §4 첫 항목 줄을 블록으로 갈아 끼우기(나머지 §4 항목은 그대로): rep4 <블록 파일>
rep4() { python3 -I -X utf8 - "$TMP/p.md" "$1" <<'PY'
import re, sys, pathlib
p, blk = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").strip("\n")
t = p.read_text(encoding="utf-8")
m = re.search(r"(?m)^## 4\..*$", t)
nxt = re.search(r"(?m)^## \d+\.", t[m.end():])
sec_end = m.end() + nxt.start() if nxt else len(t)
h = re.search(r"(?m)^[-*]\s.*$", t[m.end():sec_end])
assert h, "기반 픽스처 §4 에 항목이 없다"
s, e = m.end() + h.start(), m.end() + h.end()
p.write_text(t[:s] + blk + t[e:], encoding="utf-8")
PY
}
# §6 에 실재하는 첫 앵커(스윕 뒤 S1 이 반드시 있다)
SA=S1

# ── §1 출처 표시 (N21)
base; gate; assert_eq "$?" "0" "base: 스윕된 정상 쌍이 통과한다 (양성 대조)"
printf -- "- Goal: 로그인 실패를 줄인다 ⟨%s⟩\n- Non-goal: 세션 스토어 개편 ⟨모델 추론⟩\n" "$SA" > "$TMP/s1"
base; put 1 "$TMP/s1"; gate; assert_eq "$?" "0" "n21_marked: §1 줄마다 출처 표시가 있으면 통과한다"
printf -- "- Goal: 로그인 실패를 줄인다 ⟨%s⟩\n- Non-goal: 세션 스토어 개편\n" "$SA" > "$TMP/s1"
base; put 1 "$TMP/s1"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q '§1' "$TMP/out"; } && ok "n21_unmarked: 출처 표시 없는 §1 줄은 red" || no "n21_unmarked: rc=$rc"
printf -- "- Goal: 로그인 실패를 줄인다 ⟨S99⟩\n" > "$TMP/s1"
base; put 1 "$TMP/s1"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "n21_dangling: §1 의 ⟨S99⟩ 가 §6 에 없으면 red" || no "n21_dangling: 통과했다"

# ── 해결한 결정 (N22) — 기반 결정은 그대로 두고 OQ9 를 더한다
printf -- "- OQ9 [해결 ⟨%s⟩] — 렌더링 전략\n" "$SA" > "$TMP/s0"
printf -- "- OQ9 [해결 ⟨%s⟩]: 렌더링 전략 — 해결: 서버 렌더링으로 간다\n" "$SA" > "$TMP/s3"
base; app 0 "$TMP/s0"; app 3 "$TMP/s3"; gate; assert_eq "$?" "0" "resolved_kept: 해결 결정이 해결 내용과 함께 §3 에 남으면 통과한다 (양성 짝)"
base; app 0 "$TMP/s0"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q 'OQ9' "$TMP/out"; } && ok "resolved_dropped: §0 의 해결 결정이 §3 에 없으면 red" || no "resolved_dropped: rc=$rc"
printf -- "- OQ9 [해결 ⟨S99⟩] — 렌더링 전략\n" > "$TMP/s0d"
printf -- "- OQ9 [해결 ⟨S99⟩]: 렌더링 전략 — 해결: 서버 렌더링\n" > "$TMP/s3d"
base; app 0 "$TMP/s0d"; app 3 "$TMP/s3d"; gate; rc=$?
{ [ "$rc" -ne 0 ] && grep -q 'S99' "$TMP/out"; } && ok "resolved_dangling: 해결 토큰의 S99 가 §6 에 없으면 red" || no "resolved_dangling: rc=$rc"
printf -- "- OQ9: 렌더링 전략\n" > "$TMP/s3n"
base; app 0 "$TMP/s0"; app 3 "$TMP/s3n"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "resolved_unmarked: §3 의 해결 결정 줄에 해결 표시가 없으면 red" || no "resolved_unmarked: 통과했다"

# ── §4 여러 줄 (RC39 · AC14). 기반 픽스처의 §4 첫 항목만 여러 줄로 바꾼다(다른 항목은 그대로).
first4() { python3 -I -X utf8 -c 'import re,sys; t=open(sys.argv[1],encoding="utf-8").read(); m=re.search(r"(?m)^## 4\..*$",t); r=t[m.end():]; print(next(l for l in r.splitlines() if re.match(r"^[-*]\s",l)))' "$TMP/p.md"; }
base; H="$(first4)"
printf -- "%s\n  이유를 둘째 줄에서 이어 쓴다.\n  - 하위 불릿도 본문이다.\n" "$H" > "$TMP/s4"
rep4 "$TMP/s4"; gate; assert_eq "$?" "0" "s4_multiline: 첫 줄이 항목이고 들여쓴 줄은 본문 — 여러 줄 항목이 통과한다"
base; H="$(first4)"; HL="$(printf '%s' "$H" | python3 -I -X utf8 -c 'import re,sys; s=sys.stdin.read(); print(re.sub(r"\s*\[(?:RC\d+\s*)?→[^\]]*\]\s*$","",s))')"
LK="$(printf '%s' "$H" | grep -oE '\[(RC[0-9]+ *)?→[^]]*\]$')"
[ -n "$LK" ] || no "s4 배선: 기반 §4 첫 항목에 결정 연결이 없다 — 연결 달린 항목으로 시작하도록 배선을 고쳐라(아래 단언이 공허하다)"
printf -- "%s\n  둘째 줄. %s\n" "$HL" "$LK" > "$TMP/s4"
rep4 "$TMP/s4"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "s4_link_on_body: 결정 연결이 첫 줄 끝이 아니면 red" || no "s4_link_on_body: 통과했다"
base; H="$(first4)"
printf -- "%s\n  본문에 RC77 을 숨긴다.\n" "$H" > "$TMP/s4"
rep4 "$TMP/s4"; gate; rc=$?
[ "$rc" -ne 0 ] && ok "s4_rc_on_body: 첫 줄에 없는 RC<n> 을 본문에 두면 red" || no "s4_rc_on_body: 통과했다"

finish
```
(기반 픽스처 `interview-brief-valid.md` 에 `contract: v2` 가 없거나 §4 첫 항목에 결정 연결이 없으면 `s4 배선` 줄이 red 로 알린다 — 그때는 계약 v2 와 연결을 가진 다른 정상 픽스처(`git -C <worktree> grep -l "^contract: v2" -- plugins/spec-distill/tests/fixtures`)를 기반으로 바꾼다. 배선 조정이고 단언은 그대로다. `put` 은 §1 처럼 다른 술어가 참조하지 않는 절에만 쓴다.)

- [ ] **Step 2: 실패 확인.**

- [ ] **Step 3: 구현** — `check_brief.py`:

```python
SECTION4 = ("4", "External Landscape")


def section4_items(text: str) -> list[tuple[str, list[str]]]:
    """§4 항목 — (첫 줄, 본문 줄들). R2(RC39): §4 항목은 여러 줄을 허용한다. 열 0 의 불릿 줄이 항목이고, 그 뒤
    들여쓴 줄(불릿이든 아니든)은 그 항목의 본문이다. 빈 줄은 항목을 닫지 않는다. 열 0 의 불릿이 아닌 줄은
    항목을 닫는다. 항목이 열리기 전에 나온 들여쓴 불릿은 그 자체로 항목이다(fail-closed — 본문으로 삼켜
    순회에서 빠지지 않게). **§4 에만 쓴다** — §0 · §3 · §5 의 항목 판독은 `_entry_lines` 그대로다."""
    out: list[tuple[str, list[str]]] = []
    cur = None
    for ln in _section_text(text, *SECTION4).splitlines():
        if not ln.strip():
            continue
        if re.match(r"^[-*]\s", ln) and ln.strip() not in ("-", "*"):
            cur = (ln.strip(), [])
            out.append(cur)
        elif ln[:1] in (" ", "\t"):
            if cur is None:
                if ENTRY_BULLET_RE.match(ln) and ln.strip() not in ("-", "*"):
                    cur = (ln.strip(), [])
                    out.append(cur)
            else:
                cur[1].append(ln.strip())
        else:
            cur = None
    return out


def _section4_heads(text: str) -> list[str]:
    return [h for h, _ in section4_items(text)]


def section4_body_failures(text: str) -> list[str]:
    """§4 여러 줄 항목의 본문 줄 규칙(R2 · RC39 · AC14) — 결정 연결은 항목 **첫 줄 끝**에만 선다. 본문 줄에
    연결 괄호가 있거나, 첫 줄에 없는 `RC<n>` 이 본문 줄에 있으면 red. 본문으로 내린 연결이나 레포 주장이
    조사 술어(①~⑤)의 순회 밖으로 빠지는 길을 막는다."""
    fails = []
    for head, body in section4_items(text):
        head_rcs = set(RC_RE.findall(head))
        for b in body:
            if LINK_ANY_RE.search(b):
                fails.append(f"§4 항목의 결정 연결이 첫 줄 끝이 아니라 본문 줄에 있다: {head[:60]}")
            extra = sorted(set(RC_RE.findall(b)) - head_rcs)
            if extra:
                fails.append(f"§4 항목 본문 줄의 {', '.join(extra)} 가 첫 줄에 없다: {head[:60]}")
    return sorted(set(fails))
```
§4 를 읽는 자리를 첫 줄 목록으로 바꾼다: `landscape_unkeyed` 의 `_entry_lines(sec)` → `_section4_heads(text)`, `landscape_present` 의 마지막 `bool(_entry_lines(sec))` → `bool(_section4_heads(text))`, `landscape_keys_declared` 의 `want` 는 첫 줄과 본문 줄 모두에서 키를 모은다(`for h, body in section4_items(payload_text) for ln in [h, *body]`), `_research_entries_split` 의 `e4` → `_section4_heads(text)`. `gate()` 에 `section4_body_failures(text)` 를 실패로 더한다(계약 v2 와 무관 — §4 형식 규칙이다).

```python
PROVENANCE_MARK_RE = re.compile(r"(?:⟨S\d+⟩(?:\s*·?\s*⟨S\d+⟩)*|⟨모델 추론⟩)\s*$")


def section1_provenance_failures(text: str, anchors: set) -> list[str]:
    """§1 Goal · Non-goal 줄마다 끝에 출처 표시(R2 · N21) — `⟨S<n>⟩`(여럿이면 `⟨S1⟩ · ⟨S4⟩`) 또는
    `⟨모델 추론⟩`. 사용자가 말하지 않은 Non-goal 이나 좁힌 Goal 이 보이지 않은 채 하류의 범위가 되는 것을
    B-0 이 출처와 함께 보이게 하는 표지다. `S<n>` 은 payload §6 에 실재해야 한다."""
    fails = []
    for ln in _entry_lines(_section_text(text, "1", "Goal · Non-goal")):
        if not PROVENANCE_MARK_RE.search(ln):
            fails.append(f"§1 줄에 출처 표시(⟨S<n>⟩ 또는 ⟨모델 추론⟩)가 없다: {ln[:60]}")
            continue
        for sid in re.findall(r"⟨(S\d+)⟩", ln):
            if sid not in anchors:
                fails.append(f"§1 줄의 출처 {sid} 가 payload §6 에 없다: {ln[:60]}")
    return fails


RESOLVED_RE = re.compile(r"\[해결 ⟨(S\d+)⟩\]")


def resolved_decision_failures(text: str, anchors: set) -> list[str]:
    """해결한 결정도 §3 에 남는다(R2 · N22). §0 에서 `[해결 ⟨S<n>⟩]` 로 닫은 결정은 §3 에 선두 OQ 로 있어야
    하고, 그 §3 줄에도 `[해결 ⟨S` 표시가 있어야 한다. §0 · §3 의 해결 토큰이 가리키는 `S<n>` 은 payload §6 에
    실재해야 한다 — 모델이 결정을 닫으면서 근거를 지어내는 길을 막는다."""
    fails = []
    s3 = {}
    for ln in _entry_lines(_section_text(text, "3", "Open Questions")):
        oq = _leading_oq(ln)
        if oq:
            s3[oq] = ln
    for num, title in DECISION_SECTIONS:
        for ln in _entry_lines(_section_text(text, num, title)):
            for sid in RESOLVED_RE.findall(ln):
                if sid not in anchors:
                    fails.append(f"§{num} 의 해결 토큰 {sid} 가 payload §6 에 없다: {ln[:60]}")
    for ln in _entry_lines(_section_text(text, "0", "한눈에")):
        oq = _leading_oq(ln)
        if oq and RESOLVED_RE.search(ln):
            if oq not in s3:
                fails.append(f"§0 에서 해결로 닫은 {oq} 가 §3 에 없다 — 해결한 결정도 해결 내용과 함께 §3 에 남는다")
            elif "[해결 ⟨S" not in s3[oq]:
                fails.append(f"§3 의 {oq} 줄에 해결 표시([해결 ⟨S<n>⟩])가 없다")
    return sorted(set(fails))
```
`gate()` 에서 payload 앵커 `pa = payload_verbatim_anchors(text)` 를 한 번 구해 두 함수에 넘기고 실패에 더한다. 914~915줄 주석(「연결의 위치는 **줄 끝**이고 하위 불릿은 금지다 …」)을 「연결의 위치는 §4 항목 **첫 줄 끝**이다. §4 항목은 여러 줄을 허용하고(R2 · RC39), 본문 줄의 연결 · 첫 줄에 없는 `RC<n>` 은 `section4_body_failures` 가 red 로 낸다. §5 는 지금처럼 한 줄 항목이다.」로 고친다. `_declared_decisions` docstring 의 「§0 이 상위집합이고 §3 이 그 중 열린 것이다」 → 「§0 과 §3 은 같은 결정 전량이다 — §3 은 해결한 결정도 해결 표시와 함께 지닌다(R2 · N22)」.

템플릿(`interview-brief-template.md`):
- §0 안내 「`[열림]`/`[해결 ⟨S<N>⟩]` 상태 토큰을 달고, 해결된 것도 **지우지 않는다**」 뒤에 「— §3 에서도 지우지 않는다」.
- §1:
  ```markdown
  ## 1. Goal · Non-goal

  (줄마다 끝에 출처를 단다 — 사용자 발화에서 왔으면 `⟨S<n>⟩`, 모델이 추론해 쓴 줄이면 `⟨모델 추론⟩`. Step B-0 이
   이 절을 출처와 함께 보이고 사용자가 고치거나 뺀다.)

  - Goal: ... ⟨S1⟩
  - Non-goal: ... ⟨모델 추론⟩
  ```
- §3 안내 「(미해결 명시 — "유추 금지". 탐색 대상이므로 앞쪽에 온다.)」 → 「(열린 결정과 해결한 결정 전부 — 해결한 것도 빼지 않고 해결 표시와 해결 내용 한 줄을 붙인다. 미해결은 "유추 금지". 탐색 대상이므로 앞쪽에 온다.)」, 예시에 `- OQ4 [해결 ⟨S10⟩]: ... — 해결: <한 줄> → 근거 RC3` 한 줄.
- §4 안내의 「하위 불릿으로 쓰지 않는다 — 들여쓴 불릿도 §4 항목으로 세어져 red 다.」 → 「항목은 여러 줄로 쓸 수 있다 — 첫 줄이 항목이고 들여쓴 줄은 그 항목의 본문이다. 결정 연결과 `RC<n>` 은 첫 줄에 둔다(본문 줄에 두면 red).」

`finishing.md` Step A `5.`:
- 「**하위 불릿으로 쓰지 않는다** — 게이트가 들여쓴 불릿도 §4 항목으로 세므로 즉시 red 다.」 → 「§4 항목은 여러 줄로 쓸 수 있다 — 첫 줄이 항목이고 들여쓴 줄은 본문이다. **연결은 첫 줄 끝에 둔다** — 본문 줄의 연결이나 첫 줄에 없는 `RC<n>` 은 게이트가 red 로 낸다.」
- 요약 상호참조 불릿의 「`[해결 …]` 이 붙은 결정은 §3 에서 빠지고 §0 에만 남는다 — **§3 은 미해결의 목록이다.** §0 은 상위집합이므로 state `orchestration.open_decisions[]` **전량**이 여기 직렬화되고, 그중 `status: open` 인 것만 §3 으로 간다.」 → 「해결로 닫은 결정도 §3 에 그대로 남고, 그 항목에 해결 표시와 해결 내용 한 줄을 붙인다: `- OQ4 [해결 ⟨S10⟩]: <원래 질문> — 해결: <한 줄> → 근거 RC3`. §0 과 §3 모두 state `orchestration.open_decisions[]` **전량**이다. 게이트는 §0 의 해결 결정이 §3 에 있는지와 해결 토큰의 `S<n>` 이 payload §6 에 있는지를 본다.」
- 그 아래 문단 「해결된 결정을 §0 에서 지우지 않는 이유: …」의 끝 문장 「「열림」은 상태 토큰이 말하고 목록에서의 부재가 말하지 않는다.」는 그대로 둔다(같은 원리다).

`spec-interview/SKILL.md` 라운드 규약 마지막 불릿의 「하위 불릿은 쓰지 않는다 — 게이트가 들여쓴 불릿도 §4 항목으로 세므로」 + 다음 줄 「즉시 red 다.」 → 같은 두 줄 안에서 「§4 항목은 여러 줄로 쓸 수 있되 연결과 `RC<n>` 은 첫 줄 끝에 — 본문 줄에 두면 게이트가 red 다.」(줄 수를 늘리지 않는다).

fixture 스윕 — `~/.claude/sdd-mirror/r2-impl/t6/sweep.py`: `type: interview-brief` payload 의 §1 불릿 줄 끝에 출처 표시가 없으면 ` ⟨S1⟩` 을 붙인다(S1 은 Task 5 스윕 뒤 모든 정상 payload §6 에 있다). §0 에 `[해결 ⟨S<n>⟩]` 결정이 있는데 §3 에 그 OQ 가 없으면 §3 끝에 `- OQ<n> [해결 ⟨S<n>⟩]: <§0 줄의 한 줄> — 해결: (픽스처)` 를 더하고, §0 줄이 `→ 근거 RC<m>` 을 가지면 같은 꼬리를 붙인다. 이름이 §1 · §3 · 결정 결함을 재는 픽스처는 열어 보고 의도를 지키게 손으로 고친다. `test_check_brief.sh` 의 1851 · 1944줄 근처(`o0="- OQ4 [해결 ⟨S1⟩] — …"`) 케이스는 §3 에 해결 OQ4 줄을 함께 넣도록 고치고, 하위 불릿 케이스(V2-①)는 rc 단언을 유지한다(새 술어로 red).

- [ ] **Step 4: 통과 확인** — `test_brief_form_r2.sh` · `test_check_brief.sh` · `test_check_brief_frontmatter.py` · `test_brief_verbatim_full.sh` · `test_conducting_interview_stage.sh`(줄 상한 포함) · `test_research_claims_contract.sh` · `test_brief_no_length_cap.sh` · `test_brief_no_statement_cap.sh` · `test_finishing_block_scope.py` · `test_roadmap_status.sh` · `test_bundle_coverage.sh` · shared `test_no_new_duplication.sh` · `test_inline_python_isolated.sh`. run_suite → `after-t6.txt` 새 FAIL 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): brief §4 여러 줄을 허용하고 §1 출처와 해결한 결정을 드러낸다` + 트레일러. 새 테스트 파일 `100755` 확인.

---

### Task 7: 인터뷰 끝내기 — B-0 공시 · 재제시 상한 질문 · 참고 전부 보기 · 붙여넣은 seed

설계 §3-1 · §3-3 · §3-4 · §3-8 · §3-9 · §3-11(B-0) · §2-6(brief) · Step A.5 · B-2 문장 · AC8(brief) · AC10 · AC12 · AC16c(N15) · AC16d(N21 B-0).

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md`(B-0 · 재제시 상한 · B-A · B-2 · B-3 ③ · Step A.5 의 §0·§2 문장)
- Modify: `plugins/spec-distill/skills/spec-interview/references/seed-input.md`(N15)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` · `test_probe_sweep_residue.sh`(재제시 상한 고정 문자열)
- Modify: `plugins/spec-distill/tests/test_distortion_devices.sh`

**Interfaces:**
- Consumes: Task 6 의 §1 출처 표시 모양 · Task 4 의 brief `must_catch`(direction 이 질문으로 간다).
- Produces: 리터럴 `확정으로 올리지 않은 발화 <N>개 — S<n> · <한 줄 이유>` · `위험으로 보낸 참고 <N>개 — <id> · <이유>` · `출처를 가르지 못한 seed 문장 <N>개 — 붙여넣기라 분류기를 못 돌림` · 선택 라벨 「계속 고친다(2번 더)」 · 「지금 목록으로 확정」 · 「brief 만 종료」 · 「참고 전부 보기」 · 「접은 채로 둔다」.

- [ ] **Step 1: 실패하는 테스트** — `test_distortion_devices.sh` 에(plan-authored test code):

```bash
# ── Task 7 — 인터뷰 끝내기 (AC8 · AC10 · AC12 · AC16c · AC16d) ──
SIN="$SD/skills/spec-interview/references/seed-input.md"
has   "$FN" '확정으로 올리지 않은 발화 <N>개 — S<n> · <한 줄 이유>' "AC10: B-0 에 안 올린 발화 줄이 있다"
has   "$FN" '위험으로 보낸 참고 <N>개 — <id> · <이유>' "AC10: B-0 에 위험으로 보낸 참고 줄이 있다"
has   "$FN" '§1 의 줄마다 출처' "AC16d(N21): B-0 이 §1 을 출처와 함께 보인다"
has   "$FN" '「계속 고친다(2번 더)」' "AC12: 재제시 상한에 「계속 고친다」 선택이 있다"
has   "$FN" '「지금 목록으로 확정」' "AC12: 재제시 상한에 「지금 목록으로 확정」 선택이 있다"
has   "$FN" '「brief 만 종료」' "AC12: 재제시 상한에 「brief 만 종료」 선택이 있다"
hasnt "$FN" '모든 항목을 잠정(provisional)으로 둔다' "AC12(부재): 자동 강등 고정 문자열이 없다"
hasnt "$FN" '전 항목을 `provisional`로 강등' "AC12(부재): 자동 강등 문면이 없다"
has   "$FN" '자동 강등은 없다' "AC12: 자동 강등이 없음을 말한다"
has   "$FN" '「참고 전부 보기」' "AC8(brief): B-A 에 참고 전부 보기 선택이 있다"
hasnt "$FN" '방향 · overdesign(참고 축)은 라운드 게이트에 오지 않았습니다' "N1(부재): 방향이 참고 축이라는 B-2 문장이 없다"
hasnt "$FN" '리뷰가 payload를 수정할 수 있습니다(§0·§2' "§2-4(부재): Step A.5 의 §0·§2 문장이 없다"
has   "$SIN" '출처를 가르지 못한 seed 문장 <N>개 — 붙여넣기라 분류기를 못 돌림' "AC16c(N15): 붙여넣기 경로가 출처를 못 가른 문장 수를 공시한다"
```

- [ ] **Step 2: 실패 확인.**

- [ ] **Step 3: 구현** — `finishing.md`:

(a) B-0 — 「- 모델의 후보 판정은 **제안일 뿐**입니다. …」 불릿 뒤에:

```markdown
**함께 보이는 공시** — B-A 가 끝난 뒤, 확정 후보와 같은 프로즈 출력에 이 순서로 보입니다. 접지 않습니다
(B-0 은 프로즈라 길이 제한이 없고, 줄이 많아도 전부 보입니다):

1. brief §1 의 줄마다 출처 — `§1 <Goal | Non-goal>: <줄> — 출처 ⟨S<n>⟩ | 모델 추론`(줄 끝 표시 그대로).
   「모델 추론」 줄은 사용자가 말하지 않은 목표 · 비목표다.
2. 확정 후보와 제외 항목(위).
3. `확정으로 올리지 않은 발화 <N>개 — S<n> · <한 줄 이유>` — state `user_statements` 중 어느 `user_sourced_items`
   의 `evidence` 에도 쓰이지 않은 발화, 하나에 한 줄. 0개면 `확정으로 올리지 않은 발화 0개`.
4. `위험으로 보낸 참고 <N>개 — <id> · <이유>` — B-A 가 §5 `위험 — 리뷰 참고` 로 보낸 항목, 하나에 한 줄.
5. (붙여넣은 seed 로 시작한 세션만) `출처를 가르지 못한 seed 문장 <N>개 — 붙여넣기라 분류기를 못 돌림` —
   `references/seed-input.md` 가 R1 에서 보인 그 줄을 다시 보입니다.

「확정 목록 수정」(③)에서 사용자는 이 다섯을 고칠 수 있습니다 — §1 줄을 고치거나 빼고(출처 표시도 함께),
안 올린 발화를 확정 후보에 더하고, 위험으로 보낸 참고를 §3 열린 질문으로 올리고(§0 에도 `[열림]` 으로),
붙여넣은 seed 의 문장 중 자기 말을 사용자 출처로 표시해 확정 후보에 더합니다(`source: verbatim` · `evidence: S1`).
고친 뒤 `check_brief.py gate` 를 다시 돕니다.
```

(b) 「**재제시 상한** …」 문단과 그 아래 고정 문자열 펜스(「```\n[spec-distill] 확정 목록을 두 번 다시 보여 줬는데도 …\n```」)를 다음으로 바꾼다(카운터 펜스는 그대로):

````markdown
**재제시 상한** (금지 패턴 *Unbounded autonomy* 가드): 최초 제시는 0회째입니다. 사용자가 옵션 ③(확정 목록
수정)을 고를 때마다 state 의 `confirm_repost_count` 를 +1 합니다. 2회에 닿은 뒤 다시 ③ 을 고르면 강등하지 않고
`AskUserQuestion` 으로 「계속 고친다(2번 더)」 · 「지금 목록으로 확정」 · 「brief 만 종료」를 묻습니다 — 자동 강등은 없다.
무엇을 할지는 사용자가 매번 고릅니다:

```javascript
AskUserQuestion({ questions: [{
  header: "확정 목록",
  question: "확정 목록을 두 번 고쳤습니다. 어떻게 할까요?",
  multiSelect: false,
  options: [
    {label: "계속 고친다(2번 더)", description: "카운터를 0 으로 되돌리고 B-0 으로 돌아가 다시 고친다."},
    {label: "지금 목록으로 확정", description: "지금 목록의 확정 후보를 확정으로 바꾸고(B-3 확정 반영 절차) B-2 게이트를 다시 띄운다 — 다음 단계는 그 게이트에서 고른다."},
    {label: "brief 만 종료", description: "④ 와 같다 — 모든 항목이 잠정으로 남고 다음 단계로 넘기지 않는다."}
  ]
}]})
```
````

(c) B-3 ③ 「`confirm_repost_count` +1 후 B-0으로 돌아가 수정된 목록을 재제시(상한 2회 — 초과 시 B-0의 강등 경로).」 → 「`confirm_repost_count` +1 후 B-0 으로 돌아가 수정된 목록을 재제시(2회에 닿으면 B-0 의 재제시 상한 질문).」 B-2 옵션 ③ description 「확정 후보를 고쳐 다시 보여 준다(최대 2번). 아직 아무것도 확정되지 않는다.」 → 「확정 후보와 함께 보인 공시를 고쳐 다시 보여 준다(두 번 고친 뒤에는 계속할지 묻는다). 아직 아무것도 확정되지 않는다.」

(d) B-A — 머리 문장 「엔진 `advice` 원장의 방향 · overdesign 항목은 라운드 게이트에 오지 않았습니다」 → 「엔진 `advice` 원장의 참고 항목(`must_catch` 밖 축 — 오늘은 overdesign)은 라운드 게이트에 오지 않았습니다」. 펜스 출력 설명(「펜스 출력(머리 한 줄 + 최대 8줄 + `외 K건`)과 …」) 뒤에:

````markdown
펜스 출력에 접는 줄(`… 외 K건`)이 있으면 박제로 가기 전에 `AskUserQuestion` 한 번 — 「참고 전부 보기」 ·
「접은 채로 둔다」. 「참고 전부 보기」면 아래 펜스로 `advice-list:` 줄이 가리킨 파일의 항목 전부를 요약 전문으로
보입니다(엔진의 접기 폭 · 요약 폭 상수는 R2a 의 일이다):

```bash
python3 -I -X utf8 -c '
import json, sys
items = json.load(open(sys.argv[1], encoding="utf-8")).get("items") or []
print("참고 전부 %d건" % len(items))
for it in items:
    print("- [%s] %s — %s" % (it.get("category"), it.get("anchor"), " ".join(str(it.get("summary") or "").split())))
' "<advice-list: 줄이 가리킨 파일>"
```
````
(이 펜스는 bash 블록이다 — 첫 줄에 플러그인 루트를 쓰지 않으므로 루트 가드가 필요 없다. 블록 범위 락 `test_finishing_block_scope.py` 가 펜스마다 루트 가드를 요구하면 그 락의 규칙대로 가드 한 줄을 앞에 붙인다.)

(e) B-2 목록 1 의 「방향 · overdesign(참고 축)은 라운드 게이트에 오지 않았습니다 — B-A 가 낸 것을 싣습니다」 → 「방향(direction)은 라운드 게이트에서 물었고, overdesign(참고 축)은 라운드 게이트에 오지 않았습니다 — B-A 가 낸 것을 싣습니다」.

(f) Step A.5 의 「- 리뷰가 payload를 수정할 수 있습니다(§0·§2 — 프로필의 수정 자리).」 → 「- 리뷰가 payload 를 수정할 수 있습니다(§0 · §2~§5 — 프로필의 수정 자리. §1 은 사용자 결정이고 §6 은 추가만 허용이다).」

`seed-input.md` — 「**가르는 것은 기계다.**」 불릿 안 「그 줄이 없으면(붙여넣기) 펜스를 돌리지 않고 전부 저자 · 미확인으로 둔다 — … 우회하지 않는다).」 뒤에: 「이때 R1 «지금 이해»에 `출처를 가르지 못한 seed 문장 <N>개 — 붙여넣기라 분류기를 못 돌림` 한 줄을 보이고(N 은 seed 본문 문장 수), 사용자 발화를 옮긴 문장도 brief §2 `user_sourced_items` 에 들지 못한다는 사실을 함께 적는다. Step B-0 이 같은 줄을 다시 보이고 「확정 목록 수정」에서 사용자가 그중 자기 말을 사용자 출처로 표시한다(`finishing.md` B-0).」

`test_conducting_interview_stage.sh` · `test_probe_sweep_residue.sh` 에서 옛 고정 문자열 · 강등 경로를 묻는 단언을 새 질문의 세 라벨로 바꾼다(`confirm_repost_count` 카운터 존재 단언은 남긴다).

- [ ] **Step 4: 통과 확인** — `test_distortion_devices.sh` · `test_conducting_interview_stage.sh` · `test_probe_sweep_residue.sh` · `test_finishing_block_scope.py` · `test_rereview_cap_consistency.sh` · `test_proceed_gate_adopters.sh` · `test_plain_gate_templates.sh` · `test_next_session_command.sh` · `test_seed_input_provenance.sh` · shared `test_docreview_advice_procedure.sh` · `test_inline_python_isolated.sh` · `test_dispatch_disposition.sh`. run_suite → `after-t7.txt` 새 FAIL 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 인터뷰 끝내기가 안 올린 발화 · 위험으로 보낸 참고를 보이고 강등 대신 묻는다` + 트레일러.

---

### Task 8: reviewing-brief · spec-review — 지출 통제 문장 · 냉독 「그 밖」 · 참고 전부 보기 · 옛 규칙 문장

설계 §2-6(spec-review) · §2-7 · §3-5 · §3-2(reviewing-brief 의 fix_anchors · 방향 문장) · AC8(spec-review) · AC9 · AC13.

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md`(Step A.5 비용 문장 — 한 줄)
- Modify: `plugins/spec-distill/README.md`(P22 줄)
- Modify: `plugins/spec-distill/tests/test_reviewing_brief_skill.sh`(지출 통제 단언)
- Modify: `plugins/spec-distill/tests/test_distortion_devices.sh`

**Interfaces:**
- Produces: 리터럴 `재리뷰 상한은 안전 정지이고 승인 게이트에서 사용자가 연다` · 냉독 행 `| G7 | **그 밖** —`.

- [ ] **Step 1: 실패하는 테스트** — `test_distortion_devices.sh` 에(plan-authored test code):

```bash
# ── Task 8 — 비용 문장 · 냉독 · 참고 전부 보기 (AC8 · AC9 · AC13) ──
SR="$SD/skills/spec-review/SKILL.md"; RM="$SD/README.md"
for f in "$FN" "$RB" "$RM"; do
  hasnt "$f" '지출 통제는 엔진의 재리뷰 상한' "AC13(부재): $(basename "$f") 에 「지출 통제는 엔진의 재리뷰 상한」이 없다"
  has   "$f" '재리뷰 상한은 안전 정지이고 승인 게이트에서 사용자가 연다' "AC13: $(basename "$f") 에 안전 정지 문장이 있다"
done
hasnt "$RB" '이 자리의 지출 통제가 그것이다' "AC13(부재): reviewing-brief 의 「이 자리의 지출 통제」가 없다"
hasnt "$RM" '지출 상한은 엔진의 재리뷰 상한이 맡는다' "AC13(부재): README P22 의 옛 문장이 없다"
has   "$RB" '| G7 | **그 밖** —' "AC9: 냉독 분류에 「그 밖」이 있다"
hasnt "$RB" '**닫힌 여섯 클래스**다' "N10(부재): 냉독 분류가 닫힌 여섯이 아니다"
has   "$RB" '`fix_anchors` §0 · §2~§5' "§3-2: reviewing-brief 가 넓힌 fix_anchors 를 댄다"
hasnt "$RB" '`fix_anchors` §0·§2' "§3-2(부재): 옛 fix_anchors 문장이 없다"
hasnt "$RB" '방향 · overdesign 항목은' "§3-2(부재): 방향을 참고로 부르는 문장이 없다"
has   "$SR" '「참고 전부 보기」' "AC8(spec-review): 설계문서 승인 게이트 앞에 참고 전부 보기가 있다"
has   "$SR" '<!-- advice-display:end -->' "AC8(양성 짝): advice 표시 펜스 표지가 그대로다"
```

- [ ] **Step 2: 실패 확인.**

- [ ] **Step 3: 구현**

`reviewing-brief/SKILL.md`:
- `## 절차` 의 「상한은 그 문서가 정하는 **재리뷰 상한 2** 다. 이 자리의 지출 통제가 그것이다 — 라운드 4 이상은」 → 「상한은 그 문서가 정하는 **재리뷰 상한 2** 다. 재리뷰 상한은 안전 정지이고 승인 게이트에서 사용자가 연다 — 라운드 4 이상은」(이어지는 「사용자가 승인 게이트에서 자기 문구로 열어야만 돈다.」는 그대로).
- `## 수정 권한` 머리 「프로필이 엔진에 싣는 것(`fix_anchors` §0·§2 · `protected_headings` §1 · `immutable` §6)」 → 「(`fix_anchors` §0 · §2~§5 · `protected_headings` §1 · `immutable` §6 — §6 은 추가만)」.
- `## 냉독` 의 「받은 산문 요약을 … gap 을 분류한다. **닫힌 여섯 클래스**다:」 → 「… gap 을 분류한다. **여섯 클래스와 「그 밖」**이다:」 · 표 끝에 `| G7 | **그 밖** — 위 여섯에 들지 않지만 요약이 payload 와 다르게 읽은 곳 | 어느 클래스에도 맞지 않는 어긋남 — 무엇이 다른지 한 줄로 |` · 「G1–G6 **전부 0건**이면 readback pass.」 → 「G1–G7 **전부 0건**이면 readback pass.」
- `## Step B 로 돌아간다` 끝 문단 「엔진 `advice` 원장에 쌓인 방향 · overdesign 항목은 호출자 Step B(…)가 끝에서 한 번 보이고」 → 「엔진 `advice` 원장에 쌓인 참고 항목(overdesign — 방향은 라운드 게이트로 간다)은 호출자 Step B(…)가 끝에서 한 번 보이고(접혔으면 「참고 전부 보기」로 펼친다)」.
- 그 밖에 `git -C <worktree> grep -n -E "§0·§2|방향 · overdesign|참고 축" -- plugins/spec-distill/skills` 로 남은 자리를 보고 같은 뜻으로 고친다.

`finishing.md` Step A.5 의 「- 지출 승인 게이트는 없습니다(`cost_class: medium`) — 지출 통제는 엔진의 재리뷰 상한이 합니다: 상한 뒤의」 + 다음 줄 → 「- 지출 승인 게이트는 없습니다(`cost_class: medium`). 재리뷰 상한은 안전 정지이고 승인 게이트에서 사용자가 연다 — 상한 뒤의 추가 라운드는 사용자가 그 skill 의 승인 게이트에서 자기 문구로 열어야만 돕니다.」

`README.md` P22 줄의 「지출 상한은 엔진의 재리뷰 상한이 맡는다」 → 「재리뷰 상한은 안전 정지이고 승인 게이트에서 사용자가 연다」.

`spec-review/SKILL.md` — `<!-- advice-display:end -->` 줄 **뒤**(표지 밖)에:

````markdown
펜스 출력에 접는 줄(`… 외 K건`)이 있으면 2단계 게이트를 띄우기 전에 `AskUserQuestion` 한 번 — 「참고 전부 보기」 ·
「접은 채로 둔다」. 「참고 전부 보기」면 아래 펜스로 엔진 목록 전부를 요약 전문으로 보인다(박제된 표는 설계문서의
`### Deferred to plan` 에 이미 있다 — 이 펜스는 원장을 읽기만 한다). 앞 펜스와 같이 `spec_path='<…>'` 한 줄을 붙여
같은 Bash 호출로 돌린다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
harness_sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
ROOT="$(python3 "$SD/scripts/state_path.py" state-root || true)"
STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --session "$harness_sid" --doc "${spec_path:-}" || true)"
python3 "$SD/scripts/docreview_state.py" advice --state-dir "$STATE_DIR" > "$STATE_DIR/advice-all.json" \
  || { echo "[spec-distill] 참고 전부 보기 실패 — 엔진 원장을 읽지 못했다. 게이트 앞 글에 싣는다."; exit 0; }
python3 -I -X utf8 -c '
import json, sys
items = json.load(open(sys.argv[1], encoding="utf-8")).get("items") or []
print("참고 전부 %d건" % len(items))
for it in items:
    print("- [%s] %s — %s" % (it.get("category"), it.get("anchor"), " ".join(str(it.get("summary") or "").split())))
' "$STATE_DIR/advice-all.json"
```
````
(플러그인 루트 가드 줄은 이 파일의 다른 펜스와 같은 문면이어야 한다 — `test_plugin_root_no_cwd_fallback.sh` 등 shared 락이 그 모양을 잰다. spec-review 의 다른 펜스가 가드 끝에 덧붙이는 「— 리뷰 없이 끝났다 …」 꼬리가 이 파일의 규칙이면 그대로 따른다.)

`test_reviewing_brief_skill.sh` 79~80줄의 `has "$W_PROC" '지출 통제'` → `has "$W_PROC" '안전 정지'`, 메시지 「지출(양의 짝): `## 절차` 가 재리뷰 상한을 안전 정지로 · 라운드 4 의 명시 승인으로 댄다」.

- [ ] **Step 4: 통과 확인** — `test_distortion_devices.sh` · `test_reviewing_brief_skill.sh` · `test_reviewing_brief_residue.sh` · `test_brief_review_*.sh` · `test_brief_agents.sh` · `test_reviewing_spec_*.sh` · `test_readme_sync.sh` · `test_rereview_cap_consistency.sh` · shared `test_docreview_advice_procedure.sh` · `test_plugin_root_no_cwd_fallback.sh` · `test_inline_python_isolated.sh` · `test_skill_body_no_positional_tokens.sh` · `test_entry_preflight.sh`. run_suite → `after-t8.txt` 새 FAIL 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 재리뷰 상한을 안전 정지로 말하고 접힌 참고를 펼칠 길을 준다` + 트레일러.

---

### Task 9: spec-interview 라운드 공시 — 사실 직접 답 · 밀린 질문 · 줄인 사실 (N5 · N6 · N16)

설계 §3-7 · §3-10 · AC15 · AC16c(N16).

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md`(라운드 규약 템플릿 · 불릿)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`(`SKILL_LINE_CAP`)
- Modify: `plugins/spec-distill/tests/test_distortion_devices.sh`

**Interfaces:**
- Produces: 리터럴 `사실로 보고 직접 답한 질문 <N>개` · `밀린 질문 <N>개` · `줄인 사실 <N>개` · 「전부 보기」.

- [ ] **Step 1: 실패하는 테스트** — `test_distortion_devices.sh` 에(plan-authored test code):

```bash
# ── Task 9 — 라운드 공시 (AC15 · AC16c) ──
has "$SI" '사실로 보고 직접 답한 질문 <N>개' "AC15: 라운드 요약에 사실로 보고 직접 답한 질문 수가 있다"
has "$SI" '밀린 질문 <N>개' "AC15: 우선순위에 밀린 질문 목록이 있다"
has "$SI" '줄인 사실 <N>개' "AC16c(N16): «지금 이해»에 줄인 사실 수가 있다"
has "$SI" '「전부 보기」' "AC16c(N16): 줄인 사실을 「전부 보기」로 펼친다"
has "$SI" '### 지금 이해' "AC15(양성 짝): 라운드 규약 템플릿이 그대로 있다"
```

- [ ] **Step 2: 실패 확인.**

- [ ] **Step 3: 구현** — `spec-interview/SKILL.md` `## 라운드 규약`:
- 템플릿의 `### 지금 이해` 자리표 끝 「끝줄 «조사 호출 <n>/<limit> · 이 라운드 본체 직접 <e>»>」 → 「끝줄 «조사 호출 <n>/<limit> · 이 라운드 본체 직접 <e>», 있으면 그 아래 «사실로 보고 직접 답한 질문 <N>개 — …» · «밀린 질문 <N>개 — …» · «줄인 사실 <N>개»>」(같은 줄 안에서 — 템플릿 줄 수를 늘리지 않는다).
- 「- **한 라운드에 겹치면** … 나머지는 다음 라운드의 «다음 결정»으로 넘어간다.」 불릿 끝에 문장 하나: 「넘어간 질문은 그 라운드 «지금 이해»에 `밀린 질문 <N>개 — <한 줄씩>` 으로 보인다 — 숨은 후순위를 두지 않는다.」
- 「- 답은 `user_statements` 에 …」 불릿 앞에 불릿 둘:
  - 「- **사실로 보고 직접 답한 질문** — C43 경로 (a) 로 사용자에게 묻지 않고 직접 확인한 질문은 그 라운드 «지금 이해» 끝에 `사실로 보고 직접 답한 질문 <N>개 — <질문 · 찾은 답 한 줄씩>` 으로 보인다. 사용자가 그 답을 뒤집으면 새 발화가 이긴다.」
  - 「- **줄인 사실** — «지금 이해»의 한두 문장에 들지 못한 그 라운드의 확인 사실이 있으면 끝에 `줄인 사실 <N>개` 를 붙이고, 전문은 state 본문 그 `## R<n>` 의 «지금 이해» 아래에 그대로 적는다. 사용자가 「전부 보기」라고 하면 그 원문을 그대로 보인다.」

`test_conducting_interview_stage.sh` 의 `SKILL_LINE_CAP` — 편집 뒤 `skill_own_lines` 를 재고, 실측 + 8 로 값을 올리며 주석 한 줄을 더한다: `# 2026-10-15 R2: 라운드 공시 셋(사실 직접 답 · 밀린 질문 · 줄인 사실) 불릿 둘 + 문장 하나 — 실측 <n> + 8.` (Task 3 · Task 6 은 줄 수를 늘리지 않았다 — 이 Task 의 순증만 반영된다.)

- [ ] **Step 4: 통과 확인** — `test_distortion_devices.sh` · `test_conducting_interview_stage.sh` · `test_saturation_reference.sh` · `test_stale_terms.sh` · `test_spec_interview_entry.sh` · `test_research_claims_contract.sh` · `test_plain_gate_templates.sh`. run_suite → `after-t9.txt` 새 FAIL 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 라운드가 직접 답한 사실 · 밀린 질문 · 줄인 사실을 공시한다` + 트레일러.

---

### Task 10: 릴리스 표면 — 버전 · CHANGELOG · README

AC18 · Law 3(README Principles).

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`(`5.5.0` → `5.6.0`)
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`
- Modify: `docs/superpowers/specs/2026-10-15-distill-distortion-devices-design.md`(구현 중 새 장치가 나왔으면 §4 표에 행을 더한다 — 없으면 손대지 않는다)

- [ ] **Step 1: 실패하는 테스트** — `test_distortion_devices.sh` 에(plan-authored test code):

```bash
# ── Task 10 — 릴리스 표면 (AC18) ──
PJ="$SD/.claude-plugin/plugin.json"; CL="$SD/CHANGELOG.md"
assert_grep "$(cat "$PJ")" '"version": "5\.6\.[0-9]+"' "AC18: spec-distill minor 가 5.6 이다"
assert_grep "$(head -5 "$CL")" '^## \[5\.6\.[0-9]+\] — 2026-10-1[0-9]$' "AC18: CHANGELOG 머리가 5.6 이다"
has "$RM" '덜어 낸 것' "Law 3: README 가 덜어 낸 것 공시를 말한다"
```
(버전 리터럴은 minor 불변식만 핀하고 patch 는 열어 둔다 — 머지 직전 번호 변경과 충돌하지 않게.)

- [ ] **Step 2: 실패 확인.**

- [ ] **Step 3: 구현**
- `plugin.json` `"version": "5.6.0"`.
- CHANGELOG 맨 위에 `## [5.6.0] — 2026-10-15` — Added / Changed / Removed. 내용(각 한두 줄, 근거와 이력은 쓰지 않는다):
  - Added: seed audit `## seed 에서 덜어 낸 것` 표와 `check_seed.py` 의 표 검사 · seed 게이트 앞 `seed 에서 덜어 낸 것` · `확인받지 못한 풀이` 공시와 「되살리기」 · 풀이 줄의 «사용자가 적은 말» 칸 · seed 프로필 `omission` · B-0 의 §1 출처 · 안 올린 발화 · 위험으로 보낸 참고 · 붙여넣은 seed 공시 · 「참고 전부 보기」 · 냉독 「그 밖」 · 라운드의 사실 직접 답 · 밀린 질문 · 줄인 사실 공시 · `check_brief.py` 의 §1 출처 · 해결 결정 · §4 본문 줄 검사.
  - Changed: payload §6 은 원문 S1~Sn 전량이고 추가만 허용(N1b · `check_verbatim_coverage.py`) · brief 리뷰 `fix` 자리 §0 · §2~§5, 층 2 가 §2~§5 를 봄 · brief `must_catch` 에 `direction` · 과설계 사다리 동점은 자르지 않는 쪽 · 0건 출구 근거 허용 · 자르라는 판정은 사용자 원문 대조 · 설계문서의 사용자 요청 자르기는 `scope` · trivia 우회 전에 「그대로 / 전체 과정으로」 질문 · 확정 목록 재제시 상한은 강등 대신 질문 · 재리뷰 상한은 안전 정지 · §4 항목 여러 줄 · 확인 표시는 «다시 검증할 것» 문단에서도 따라감 · 해결한 결정도 §3 에 남음.
  - Removed: overdesign 판정자당 라운드 3건 상한 · 「번호가 작은 쪽」 사다리 규칙 · 재제시 상한의 자동 강등 · 확인 표시의 문단 내림(N20) · 해결 결정의 §3 제외(N22). 사용자가 결정한 처분(2026-10-15, 설계 §4)이라 deprecation 창을 두지 않는다.
- README:
  - `## Principles Instantiated` 의 Law 1 또는 P17 근처 줄에 한 줄 더한다: 「**덜어 낸 것은 보인다** — seed 압축 · 확정 후보 · 리뷰 참고 · 라운드 요약이 덜어 낸 것을 사용자가 보는 자리에 한 줄로 공시하고 되살릴 길을 준다(R2).」 (절 이름 · 기존 줄 형식은 파일의 것을 따른다.)
  - README 에 overdesign 3건 상한 · 「번호가 작은 쪽」 · payload §6 은 S1 만 · 재제시 강등을 말하는 문장이 있으면 새 동작으로 고친다(`git -C <worktree> grep -n -E "3건|번호가 작은|S1\`? ?만|강등" -- plugins/spec-distill/README.md`).

- [ ] **Step 4: 통과 확인** — `test_distortion_devices.sh` · `test_readme_sync.sh` · shared `test_changelog_integrity.sh` · `test_plugin_description_parity.sh` · `test_invocation_surface.sh`. run_suite → `after-t10.txt` 새 FAIL 0.

- [ ] **Step 5: 커밋** — `chore(spec-distill): R2 릴리스 표면 — 5.6.0 · CHANGELOG · README` + 트레일러(번호는 머지 직전에 바뀔 수 있다).

---

### Task 11: 변이 검증 (AC17) · 끝에서 끝 픽스처 걷기

AC17 · Verification Plan 「끝에서 끝」. 결과는 보고서이고, 락에 이빨이 없으면 그 락만 고쳐 커밋한다.

**Files:**
- Create(리포 밖): `~/.claude/sdd-mirror/r2-impl/t11/mutate.sh` · `~/.claude/sdd-mirror/r2-impl/t11/mutation.md` · `~/.claude/sdd-mirror/r2-impl/t11/e2e.sh` · `~/.claude/sdd-mirror/r2-impl/t11/e2e.md`
- Modify(필요할 때만): 이빨 없는 락 파일

- [ ] **Step 1: 변이 사본을 만든다** — 리포를 건드리지 않는다: `git clone --no-local /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/agent-a661e3ee5bc3ea413 ~/.claude/sdd-mirror/r2-impl/t11/clone` 후 그 사본에서 `git -C <clone> checkout r2-impl`. 사본에서 `bash plugins/spec-distill/tests/test_distortion_devices.sh` 가 GREEN 인지 먼저 본다(양성 대조 — RED 면 변이 결과는 증거가 아니다).

- [ ] **Step 2: 변이 표를 돈다** — 각 줄: 사본의 대상 파일을 바꾸고 → 지정한 락을 돌려 RED(`✗` 줄 ≥ 1 또는 rc ≠ 0)를 확인하고 → `git -C <clone> checkout HEAD -- <파일>` 로 되돌린 뒤 `git -C <clone> diff HEAD --stat` 이 비었는지 본다. 한 변이에 한 축만.

| # | AC | 대상 · 변이(축) | 락 |
|---|---|---|---|
| 1 | AC2 | `compression.md` 의 「빼면 표에 남긴다」 셋을 전부 지운다(삭제) | test_distortion_devices |
| 2 | AC2 | `compression.md` 에 「어차피 맞게 할 거면 뺀다.」 단독 문장을 다시 넣는다(추가) | test_distortion_devices |
| 3 | AC2 | `## 상한을 두지 않는다` 를 `## 상한을 둔다` 로(반전) | test_distortion_devices |
| 4 | AC5 | brief.md 의 「자르지 않는 쪽」을 「자르는 쪽」으로(반전) | test_distortion_devices |
| 5 | AC5 | design-doc.md 에 `### 상한` 절과 「한 판정자가 한 라운드에 3건」을 되살린다(추가) | test_distortion_devices · test_overdesign_rubric |
| 6 | AC5 | brief.md 「인용으로 대조한다」 불릿 삭제 | test_distortion_devices |
| 7 | AC6 | brief.md `fix_anchors` 에서 `"^5\\."` 를 뺀다(삭제) | test_distortion_devices |
| 8 | AC6 | brief.md `immutable` 을 `[]` 로(형태 변경) | test_distortion_devices |
| 9 | AC6 | seed.md `layer1` 에서 `omission` 을 뺀다 | test_distortion_devices |
| 10 | AC11 | reviewing-brief 수정 권한 표에 「**불변** — 어떤 처분도 닿지 못한다」 행을 되살린다(추가) | test_distortion_devices |
| 11 | AC11 | `check_verbatim_coverage.py` 의 글자 비교를 `pass` 로(로직 삭제) | test_brief_verbatim_full(dup_differs) |
| 12 | AC11 | `check_brief.py` N1b 의 audit 앵커 포함 검사를 지운다 | test_brief_verbatim_full(n1b_missing_audit) |
| 13 | AC12 | finishing.md 「「지금 목록으로 확정」」 삭제 | test_distortion_devices |
| 14 | AC12 | finishing.md 에 옛 고정 문자열 「모든 항목을 잠정(provisional)으로 둔다」 추가 | test_distortion_devices |
| 15 | AC13 | reviewing-brief 에 「이 자리의 지출 통제가 그것이다」 되살림 | test_distortion_devices |
| 16 | AC13 | README 의 안전 정지 문장을 옛 문장으로(반전) | test_distortion_devices |
| 17 | AC16a | trivia-escape.md 의 질문 블록 전체 삭제 | test_distortion_devices |
| 18 | AC16a | trivia-escape.md 의 force 문장에서 「첫 토큰이 정확히」를 「첫 토큰에」로(형태 변경) | test_distortion_devices · test_conducting_interview_stage |
| 19 | AC16b | design-doc.md frontmatter `must_catch` 에 `overdesign` 추가 | test_distortion_devices |
| 20 | AC16b | design-doc.md 의 scope 문장 삭제 | test_distortion_devices |
| 21 | AC3 | `check_seed.py` 의 `cut_table_problems` 호출 삭제 | test_seed_cut_table |
| 22 | AC14 | `check_brief.py` 의 `section4_body_failures` 호출 삭제 | test_brief_form_r2 |
| 23 | AC16d | `seed_provenance.classify` 의 순서를 되돌린다(reverify 먼저) | test_seed_cut_table |
| 24 | AC16d | `resolved_decision_failures` 의 §3 존재 검사 삭제 | test_brief_form_r2 |

결과를 `mutation.md` 에 표로(번호 · RED 줄 수 · 되돌림 확인) 적는다. GREEN 으로 살아남은 변이가 있으면 그 락에 단언을 더해(존재 · 부재 짝으로) 리포에서 고치고, 같은 변이를 다시 돌려 RED 를 확인한 뒤 커밋한다 — `test(spec-distill): <AC> 락의 이빨을 세운다`.

- [ ] **Step 3: 끝에서 끝 걷기** — `e2e.sh` 가 임시 디렉토리에서:
  1. seed + audit(덜어 낸 것 표 2행 · 「되살림」 1행 · 사용자가 적은 말 칸 · «다시 검증할 것» 문단 안의 확인 문장) → `check_seed.py gate` rc 0 · `seed_provenance.py marks` rc 0 · `classify` 가 그 문장을 user/True 로 · `build_seed_inline_blob.py` 번들에 표.
  2. brief payload(§6 S1~S4 · §1 출처 표시 · §3 에 해결 OQ · §4 두 줄 항목) + audit(§6 S2~S4 같은 글자) + state(S2~S4) → `check_brief.py gate` rc 0 · `check_verbatim_coverage.py` rc 0.
  3. 같은 brief 에 결정 발화 S5 를 세 자리에 같은 write 로 더함 → 두 검사 rc 0. payload 쪽 S3 글자만 바꿈 → `check_verbatim_coverage.py` rc 1.
  4. Task 5 Step 5 의 얼림 실측 결과(`t5/freeze.txt`)를 인용한다.
  결과를 `e2e.md` 에 적는다. 문면 동작(B-0 공시 · 재제시 질문 · 참고 전부 보기 · trivia 질문 · 라운드 공시)은 모델이 skill 을 읽고 하는 일이라 이 걷기로 재지 못한다 — 그 사실을 「확인 못 함 — 대화형 실행 필요」로 적는다(꾸며 적지 않는다).

- [ ] **Step 4: 정리** — `rm -rf ~/.claude/sdd-mirror/r2-impl/t11/clone`(자기 하위 폴더만). 리포 `git -C <worktree> status --short` 가 비었는지(락 수정 커밋 뒤) 확인.

---

## Self-Review 기록

- 설계 §1-1~§1-10 → Task 1 · 2 · 3, §2-1~§2-9 → Task 2 · 4 · 7 · 8, §3-1~§3-12 → Task 5 · 6 · 7 · 8 · 9, §4 표 34행: 수정 · 제거 28행은 위 Task 에, 넘김 6행(RC55 · N2 엔진 상수 · N12 · N13 · N17 · N18)은 코드 변경 없음 — PR 본문 후속 표(R2a · R3 · R7 · R9)로 간다. §5 넘길 목록 → PR 본문. AC1~AC18 → 각 Task 의 테스트, AC17 → Task 11.
- 이름 일관성: `payload_verbatim_n1b_failures` · `section4_items` · `section4_body_failures` · `section1_provenance_failures` · `resolved_decision_failures` · `cut_table_problems` · `CUT_TABLE_SECTION` · `SAID_TAIL` — 정의한 Task 와 쓰는 Task 가 같은 이름을 쓴다.
- 줄 상한: spec-interview SKILL 은 Task 3 · 6 이 한 줄 치환만, Task 9 만 순증 — Task 9 가 상한을 「실측 + 8」로 옮긴다.
