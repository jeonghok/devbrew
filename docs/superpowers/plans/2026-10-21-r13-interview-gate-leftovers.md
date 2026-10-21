# R13 — R10 남은 인터뷰 게이트 · 엔진 skill 소결함 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인터뷰를 닫은 사용자 답의 출처 대조 · 상태 폴더 쓰기의 링크 따라가기 · V1 확인 줄 자리 · 원장 뿌리 · 로드맵 생성 따옴표 · 템플릿 판 꼬리 · 셸 테스트 실행 비트, 일곱 결함을 있는 검사 · 인자 · 옮겨 쓰기 길 위에서 고친다.

**Architecture:** 작은 공용 writer(`shared/docreview/scripts/nofollow_write.py`) 하나를 먼저 세우고, 공유 러너 → skill 이 부르는 스크립트 → 세 skill 의 펜스 순으로 쓰기를 그리로 옮긴다. 원장 뿌리는 `state_path.py state-root-for` 하나로 모으고 펜스는 호출만 바꾼다. 사용자 답 대조는 `check_verbatim_coverage.py` 에 얹고 줄 문법은 `check_brief.py` 의 공개 함수 하나에서 받는다. 나머지(§4 · §6 · §7)는 문면 고침과 락이다.

**Tech Stack:** Python 3.9 표준 라이브러리(`os` · `tempfile` · `subprocess`), macOS bash 3.2 셸 테스트, Markdown.

**Spec:** `docs/superpowers/specs/2026-10-21-interview-gate-leftovers-design.md` (§1~§9 · AC1~AC14 · `### Deferred to plan`)

**구현 브랜치:** `feature/interview-gate-leftovers` — 설계문서와 이 계획이 이미 있다. 새 브랜치를 만들지 않는다.

## Global Constraints

- **판 번호:** spec-distill `8.4.0 → 8.5.0`, quality-gates `14.3.0 → 14.4.0`(공유 러너 · writer 링크가 qg 에도 실린다). R8 이 이 에픽 뒤에 오므로 이 번호로 고정한다 — 머지 직전에 기본 브랜치 판이 바뀌었으면 지휘자가 다시 정한다. CHANGELOG 머리는 plugin.json 과 같게(`shared/tests/test_changelog_integrity.sh`).
- git: merge 만 · HEAD 를 뒤로 옮기지 않는다 · 커밋은 pathspec · `git stash` 금지 · 공유 임시 폴더 glob 삭제 금지 · 다른 worktree 의 git 금지.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 끝에 `Spec: docs/superpowers/specs/2026-10-21-interview-gate-leftovers-design.md` 와 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` · 세션이 주는 `Claude-Session:` 줄.
- 셸: 펜스와 테스트는 `/bin/bash`(3.2)에서 돈다 · `$var` 뒤에 한글이 오면 `${var}` · 새 · 바뀐 셸 테스트는 `chmod +x` 후 `git ls-files -s` 로 `100755` 확인 · 테스트에 `# guards:` 머리를 달지 않는다.
- 파이썬: 3.9 문법 · `open(`/`read_text(`/`write_text(` 에는 `encoding="utf-8"`(`plugins/quality-gates/tests/test_utf8_explicit.py`) · `plugins/**/*.py` 에 `"python3"` 리터럴 금지(`shared/tests/test_python_floor.sh`) · 20줄 이상 같은 블록 금지(`shared/tests/test_no_new_duplication.sh`) · `scripts/*.py` 에 `"## 6. 사용자 원문"` 앞머리와 맞는 `re.compile` 리터럴 금지.
- 테스트 실행은 `PYTHONDONTWRITEBYTECODE=1`. 링크 픽스처(레포 밖을 가리키는 심볼릭 링크 · 하드 링크)는 `mktemp -d` 폴더에서만 만들고, 매 실행 뒤 `git status --porcelain` 이 비었는지 본다.
- **변이:** 락마다 변이(삭제 · 추가 · 반전 · 형태 변경)로 RED 를 보고 양성 대조로 과잉을 본다. 변이 전에 커밋하고, 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --quiet` 로 확인한다. 음의 락에는 양의 짝을 둔다.
- **전체 스위트:** `bash tools/suite/run-all.sh` 는 공유 잠금 아래서만 — `until mkdir /Users/jeonghokim/.claude/sdd-mirror/suite-lock.d; do sleep 30; done`, 그 안 `owner` 파일에 이름과 시각, 끝나면 폴더를 지운다. 과제 안에서는 그 과제가 건드린 테스트와 아래 「이웃 테스트」만 돌린다.
- **사람에게 쓰는 글:** 펜스 · 스크립트가 실행 중 내는 문장은 `shared/style/plain-language.md` 를 따른다. 모델이 읽는 새 문면에 출처 · 존재 정당화를 쓰지 않는다(CLAUDE.md 「Self-narrating artifact」).
- **pm-interview `SKILL.md` 줄 수 래칫:** 자기 줄 수가 지금 571, 상한 `< 572`(`test_conducting_interview_stage.sh` `SKILL_LINE_CAP`). 이 계획은 그 파일의 줄 수를 늘리지 않는다.
- 레포 전용 값을 펜스 · 스크립트에 박지 않는다. persona · 리뷰어 프로필 파일은 건드리지 않는다.

## 설계와 다른 점 · 설계에 없던 결정

- **Q1(승인 대기 — 설계 변경 질문).** 설계 `## Files to Modify` 에 없는 기존 테스트 다섯이 옛 문면 · 옛 동작을 글자로 고정하고 있어, 바꾼 동작에 맞춰 함께 고쳐야 한다: `plugins/spec-distill/tests/test_interview_state_flow.sh`(:215 `touch "${DEGRADE_FALLBACK_FILE` 로 머리 끝을 찾음) · `test_ledger_wiring.sh`(:410 상태 루트 스텁 · :469-473 git 밖 문서 거절 · :871 `> "$BUNDLE"` 리터럴) · `test_reviewing_brief_skill.sh`(:416 `: > "$BUNDLE"` 리터럴) · `test_reviewing_brief_residue.sh`(:513-523 「잠긴 번들」 — 지금은 `>` 가 실패해 rc≠0 이 기대값이지만, writer 는 이름을 바꿔 새 번들을 놓는다) · `test_reviewing_spec_state_keying.sh`(:35 `state-root` 리터럴 — 접두로 지금도 맞지만 새 이름으로 고친다). 지휘자가 R13 경로 예약에 더하는 것을 전제로 과제에 넣는다. 구현 중 스위트가 같은 종류(옛 리터럴 · 옛 동작 고정)를 더 알려 주면 그 파일도 같은 이유로 고치고 보고한다.
- writer 이름은 `nofollow_write.py` 그대로. 자기 실패 rc 는 **73**(감싸는 명령 — `build_brief_bundle.py` 0·2·3 · `build_seed_inline_blob.py` 0·2 · `seed_edit_diff.py` 0·2·3·4 · `codex_findings_to_yaml.py` 0 · `printf` — 이 쓰지 않는 값). 인자 오류도 73 이다(argparse 의 2 는 감싸는 명령의 2 와 겹친다).
- `printf … > f` 자리는 `run --out f -- printf …` 로 감싼다(stdin 모드를 만들지 않는다).
- `check_brief.py` 는 공개 함수 하나(`closing_answer_anchors`)를 더하고, 기존 `landscape_irrelevant` · `saturation_failures` 가 같은 내부 도우미를 쓰게 한다 — 문법이 한 곳에 산다.
- `seed_edit_diff.py` 는 writer 의 `replace_bytes` 를 import 한다(같은 `scripts/` 에 링크가 있다). `docreview_state.py` 는 import 하지 않고 몇 줄을 둔다 — 테스트 넷이 `docreview_state.py` 와 `docreview_config.py` 만 복사한 트리에서 돈다(`test_reviewing_spec_entry_fence.sh:333` · `test_reviewing_spec_residue.sh:104` · `shared/tests/fixtures/docreview/cases.sh:4494` · `cases_advice.sh:524`). 원장은 제자리 덮어쓰기라 writer 의 이름 바꾸기와 모양도 다르다.
- `state-root-for ""`(빈 문서 경로)는 `state-root` 와 같다(cwd 뿌리 · 공시 없음) — 빈 값이 뒤 줄(`state-dir-for`)의 멈춤으로 가는 지금 동작을 그대로 둔다.
- 대상 S 레코드의 `source` 값: `chosen` 통과 · `verbatim` 이나 그 밖의 값(`Chosen` · `selected` …) rc 1 · 키 없음이나 빈 값 rc 3.
- `not_chosen` 의 멈춤 문장은 `check_verbatim_coverage.py` 가 `advisories` 에 싣는다(S 목록 · 마무리 단계가 다시 묻는다 · 세션을 넘겼으면 이어 갈 수 없다). RB rc 표 행은 그 문장을 보이라고 적는다.
- `## 6. 사용자 원문`·audit §2 다시 짓기는 덧붙이기가 아니라 state 에서 **통째로 다시 쓰기**로 finishing 문면에 못 박는다(멱등의 근거).

## Review Focus

1. **상태 폴더가 쓰기 불가인데 직전 번들 파일만 쓰기 가능하다.** 지금 `>` 는 그 파일을 자르고 쓴다. writer `run` 은 이름 바꾸기만 하므로 rc 73 으로 실패하고, 펜스의 기존 실패 갈래(`drop_bundle` → `empty` 의 자르기 갈래)가 직전 번들을 비우고 멈춰야 한다 — 직전 번들이 이번 것으로 남으면 안 된다. Task 5 `rb_bundle_ro_dir_clears_stale` 가 잠근다.
2. **state 레코드의 `source` 가 `chosen` 도 `verbatim` 도 아닌 값이다(`Chosen` · `selected`).** 통과하면 대조를 글자 하나로 넘는다. rc 1 이어야 한다. Task 7 `vc_source_unknown_value_rc1` 이 잠근다.
3. **같은 S 를 「외부 선례 무관」 두 줄 또는 두 닫힘(외부 선례 · 사용자 판단 포화)이 함께 가리킨다.** `not_chosen` 에 한 번만 실려야 한다(번호 순). Task 7 `vc_not_chosen_dedup_sorted` 가 잠근다.
4. **문서 경로가 비었거나 상대 경로이거나 폴더가 아직 없다.** `state-root-for` 가 빈 값은 `state-root` 와 같게, 상대 경로는 cwd 기준 절대화, 폴더 없음은 `payload-root` 와 같은 판정으로 낸다(엉뚱한 상위 폴더의 레포를 집지 않는다). Task 4 의 넷이 잠근다.
5. **승인 원문이 여러 줄이거나 구분 줄(`DEVBREW_ROADMAP_APPROVAL_EOF`)과 똑같은 줄을 담는다.** 여러 줄은 글자 그대로 가야 하고, 구분 줄 규칙은 문면이 바꾸라고 적어야 한다. Task 9 `stepa8_multiline_approval_verbatim` 과 문면 단언이 잠근다.

---

### Task 0: 자리 · 기준선

**Files:** 없음(레포 밖 `$HOME/.claude/sdd-mirror/r13/` 에 기준선만)

- [ ] **Step 1:** `git fetch origin && git status -sb` — `feature/interview-gate-leftovers` 위, origin 이 앞서 있으면 `git merge --ff-only origin/feature/interview-gate-leftovers`(안 되면 멈추고 보고).
- [ ] **Step 2:** 공유 잠금 아래 `bash tools/suite/run-all.sh > $HOME/.claude/sdd-mirror/r13/baseline.txt` — 이미 RED 인 줄을 기준으로 남긴다(뒤 대조에서 새 RED 만 이 계획의 몫이다).

---

### Task 1: 공용 writer · 두 플러그인 링크 (AC4 · AC5 · AC7 링크 부분)

**Files:**
- Create: `shared/docreview/scripts/nofollow_write.py`(100755)
- Create(링크): `plugins/spec-distill/scripts/nofollow_write.py` · `plugins/quality-gates/scripts/nofollow_write.py` → `../../../shared/docreview/scripts/nofollow_write.py`
- Create: `shared/tests/test_nofollow_write.sh`(100755)

**Interfaces:**
- Produces(CLI): `nofollow_write.py run --out P -- <명령…>` → 명령 rc 그대로(띄우지 못하면 127 · 신호면 128+n) · `empty --out P` → 0 / 73 · `append --out P` (stdin) → 0 / 73. writer 자신의 실패는 rc 73 + stderr 한 줄 `[nofollow_write] <사유> — <P>`, 그때 P 는 그대로다.
- Produces(Python): `replace_bytes(path, data: bytes) -> None`(실패면 `OSError`), `EXIT_SELF = 73`.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `shared/tests/test_nofollow_write.sh`(`. shared/tests/assert.sh`, `T="$(mktemp -d)"` · `trap`). 픽스처: `$T/out/` 폴더, 레포 밖 대상 `$T/outside.txt`(내용 `KEEP`).
  - `run_symlink_replaced` — `P=$T/out/b` 가 `$T/outside.txt` 를 가리키는 링크 → `run --out P -- printf 'NEW'` 뒤 `outside.txt` 는 `KEEP`, P 는 링크가 아닌 일반 파일이고 내용 `NEW`, rc 0.
  - `run_hardlink_replaced` — P 가 `outside.txt` 의 하드 링크(링크 수 2) → 같은 결과(`outside.txt` 는 `KEEP`).
  - `run_passes_rc_and_keeps_stdout` — 명령 `sh -c 'printf X; exit 3'` → rc 3 · P 내용 `X`. rc 5 도 같다.
  - `run_missing_command_127` — 없는 명령 → rc 127 · P 는 빈 일반 파일.
  - `run_stdin_inherited` — `printf 'in' | nofollow_write.py run --out P -- cat` → P 내용 `in`.
  - `run_self_failure_73` — P 의 폴더가 없음 → rc 73 · stderr 첫 줄이 `[nofollow_write] ` 로 시작 · P 없음. 폴더가 쓰기 불가(`chmod 555`)이고 P 가 이미 있음 → rc 73 · P 내용 그대로.
  - `bad_args_73` — 모드 없음 · `--out` 없음 · `run` 에 `--` 없음 → 각각 rc 73.
  - `empty_symlink_and_hardlink` — P 가 링크 · 하드 링크 → rc 0, P 는 빈 일반 파일, `outside.txt` 는 `KEEP`.
  - `empty_truncate_branch` — 폴더 `chmod 555` · P 는 쓰기 가능한 일반 파일(내용 `OLD`) → rc 0 · P 크기 0. 같은 조건에서 P 가 링크 → rc 73 · `outside.txt` 는 `KEEP`. P 가 하드 링크(링크 수 2) → rc 73 · 두 이름 다 `OLD`.
  - `append_creates_and_appends` — 없음 → `printf a | append` 로 만든다 · 다시 `printf b` → 내용 `ab`. 빈 stdin(`</dev/null`) → 빈 파일만 만든다(rc 0).
  - `append_refuses_links` — P 가 링크 · 하드 링크 → rc 73 · `outside.txt` 는 `KEEP`.
  - `mode_matches_shell` — `run` 이 만든 파일의 권한이 같은 umask 에서 셸 `>` 가 만든 파일과 같다.
  - `bash32_fence` — 위 셋 중 하나씩을 `/bin/bash -c` 펜스 꼴(`python3 "$W" empty --out "$P" 2>/dev/null || echo fail`)로 돌려 같은 결과.
  - `links_derived` — `git ls-files -s -- 'plugins/*/scripts/run_docreview_codex_reviewer.sh'` 로 공유 러너를 링크로 싣는 플러그인을 도출하고(0개면 RED), 그 플러그인마다 `plugins/<p>/scripts/nofollow_write.py` 가 인덱스에서 mode `120000` 이며 `shared/docreview/scripts/nofollow_write.py` 로 풀린다. 도출 수가 2 이상인지 따로 단언한다.

- [ ] **Step 2: 돌려 실패를 본다** — `bash shared/tests/test_nofollow_write.sh` → writer 부재로 RED.

- [ ] **Step 3: writer 를 쓴다** — `shared/docreview/scripts/nofollow_write.py`.
  - 임시 파일은 `tempfile.mkstemp(dir=<P 의 폴더>, prefix="." + <P 이름> + ".", suffix=".tmp")`(O_EXCL · O_NOFOLLOW) → 권한을 `0o666 & ~umask` 로 맞춤 → 쓰기 → `os.replace(tmp, P)`. 실패하면 tmp 를 지운다.
  - `run`: 명령을 `subprocess.run(argv, stdout=<tmp fd>)` 로 돌린다(stdin · stderr 는 물려준다). 명령 rc 와 무관하게 tmp 를 P 로 놓는다. `FileNotFoundError`/`PermissionError` 로 띄우지 못하면 빈 tmp 를 놓고 127.
  - `empty`: 이름 바꾸기 갈래가 `OSError` 면 `os.open(P, O_WRONLY | O_NOFOLLOW)` → `fstat` 이 일반 파일이고 `st_nlink == 1` 일 때만 `ftruncate(0)`. 아니면 73.
  - `append`: `os.open(P, O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW, 0o666)` → `fstat` 이 일반 파일 · 링크 하나일 때만 stdin 바이트를 쓴다. 아니면 73.
  - 인자는 argparse 없이 직접 가른다. `main` 전체를 `try/except Exception` 으로 감싸 73 으로 낸다. 모듈 import 에는 부작용이 없다.
  - 링크 둘을 `ln -s ../../../shared/docreview/scripts/nofollow_write.py` 로 만든다. `chmod +x` 정본.

- [ ] **Step 4: 돌려 통과를 본다** — `bash shared/tests/test_nofollow_write.sh && bash shared/tests/test_copy_of_contract.sh && bash shared/tests/test_no_new_duplication.sh && bash shared/tests/test_python_floor.sh && python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py`.

- [ ] **Step 5: 배포 링크 락이 두 링크를 집는지 실측** — 커밋한 뒤 사본 레포(`git clone --no-local` 를 `mktemp -d` 에)에서 (가) qg 링크를 지움 (나) qg 링크를 정본 사본 파일로 바꿈 (다) spec-distill 링크를 지움 → `test_copy_of_contract.sh` 와 `test_nofollow_write.sh` 의 RED 여부를 표로 남긴다. 계획이 예상하는 결과: (가)는 `test_copy_of_contract.sh` 가 못 잡고(qg 파일에 `scripts/nofollow_write.py` 를 부르는 문장이 없다) `links_derived` 가 잡는다. (나)(다)는 둘 다 잡는다. 다르면 보고하고 `links_derived` 를 고친다.

- [ ] **Step 6: 커밋** — `git add shared/docreview/scripts/nofollow_write.py plugins/spec-distill/scripts/nofollow_write.py plugins/quality-gates/scripts/nofollow_write.py shared/tests/test_nofollow_write.sh && git commit -m 'feat(docreview): 링크를 따라가지 않는 공용 writer' -- <같은 넷>`.

---

### Task 2: 공유 러너의 상태 폴더 쓰기 (AC7 러너 부분)

**Files:**
- Modify: `shared/docreview/scripts/run_docreview_codex_reviewer.sh`(:50 · :67 · :495-498)
- Test: `shared/tests/test_nofollow_write.sh`

**Interfaces:**
- Consumes: Task 1 CLI(`empty` · `run`, rc 73).
- Produces: 러너 안 `_RUNNER_DIR="$(dirname -- "${BASH_SOURCE[0]}")"` — `runner_common.sh` 와 `nofollow_write.py` 를 같은 자리에서 찾는다.

- [ ] **Step 1: 실패하는 테스트를 더한다**
  - `runner_targeted_lock` — 러너 파일을 읽어(따옴표 heredoc 본문은 구분 줄까지 건너뛴다) 넘기기 꼴 `>` · `>>` · `>|` · `&>` · `N>` 과 `| tee` · `touch` 의 대상을 모은다. 허용: `/dev/null` · fd 복제 · 러너 안에서 `"$SCRATCH/…"` 로만 대입된 변수(`SCRATCH` 는 `mktemp -d` 로만 대입 — 둘 다 러너 글에서 도출). `$OUTPUT_PATH`(`${OUTPUT_PATH}` 포함) 대상과 그 밖의 대상은 RED. 그리고 `nofollow_write.py" empty --out "$OUTPUT_PATH"` 줄이 `trap '…' EXIT` 줄보다 앞에 있고, `write_failclosed` · `_degrade_if_empty` 를 부르는 모든 줄이 그 줄보다 뒤에 있다(이름으로 빼는 이유 — 첫 쓰기가 심어 둔 링크를 이미 일반 파일로 바꿨다 — 를 순서로 잰다).
  - 변이(사본에서): `: > "$OUTPUT_PATH"` 되살림 · `echo x >> "$OUTPUT_PATH"` 추가 · `| tee "${OUTPUT_PATH}"` 추가 · `> /tmp/x` 추가 · writer `empty` 줄을 trap 뒤로 옮김 → 각각 RED. 양성: 원래 러너 GREEN · `> "$PROMPT_FILE"` 추가 GREEN.
  - `runner_e2e_symlink` — `OUTPUT_PATH` 자리에 레포 밖 파일을 가리키는 링크 · 하드 링크를 심고 러너를 돌린다(codex 는 `shared/tests/fixtures/docreview/codex-stub.sh` 를 PATH 의 `codex` 로). 끝난 뒤 바깥 파일 그대로 · `OUTPUT_PATH` 는 YAML 을 담은 일반 파일. 프로필 파일을 없앤 호출(`emit_fallback profile_missing` 갈래)도 같은 단언.
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: 러너를 고친다** — `_RUNNER_DIR` 를 :50 앞에 둔다. :50 → `python3 "$_RUNNER_DIR/nofollow_write.py" empty --out "$OUTPUT_PATH" 2>/dev/null || { 지금 문장; exit 3; }`. :61 `_RUNNER_COMMON` 은 `$_RUNNER_DIR` 에서. :66-67 → `python3 "$_RUNNER_DIR/nofollow_write.py" run --out "$OUTPUT_PATH" -- printf '<지금 형식>' 2>/dev/null || { … exit 3; }`. :490-498 → `if ! python3 "$_RUNNER_DIR/nofollow_write.py" run --out "$OUTPUT_PATH" -- python3 "$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py" <지금 인자> < "$STDOUT_FILE"; then python3 "$_RUNNER_DIR/nofollow_write.py" run --out "$OUTPUT_PATH" -- printf 'findings: []\nmeta:\n  codex_failed: true\n  reason: yaml_conversion_failed\n' || exit 3; exit 0; fi`. 머리 주석의 쓰기 설명을 한 줄로 맞춘다.
- [ ] **Step 4: 돌려 통과를 본다** — `bash shared/tests/test_nofollow_write.sh` 와 이웃 `shared/tests/test_docreview_codex.sh test_codex_runner_scratch_trap_order.sh test_runner_disposition.sh test_codex_project_doc_off.sh` · `plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh test_codex_copies_agree.sh test_codex_invocation_contract.sh test_sandbox_enforced.sh`.
- [ ] **Step 5: 커밋 → 변이(Step 1 목록) → 복원 확인.**

---

### Task 3: skill 이 부르는 스크립트의 쓰기 (AC7 스크립트 부분)

**Files:**
- Modify: `plugins/spec-distill/scripts/seed_edit_diff.py`(:132 · :143 · :164 · :196 · :197)
- Modify: `shared/docreview/scripts/docreview_state.py`(`save_state` :318-328)
- Create: `plugins/spec-distill/tests/test_state_dir_writes.sh`(100755 — Task 5 가 락을 더한다)

**Interfaces:**
- Consumes: `nofollow_write.replace_bytes(path, data: bytes)`.
- Produces: `save_state` 가 원장 자리가 링크이거나 링크 수가 1 이 아니면 `LedgerCorrupt("ledger_not_plain_file", path=<원장 경로>)` 를 낸다(CLI 는 기존 `fail` 로 rc 1 · stderr JSON).

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_state_dir_writes.sh` 머리(`. shared/tests/assert.sh` · `T="$(mktemp -d)"` · `trap`) 와:
  - `sed_init_dangling_base` — `$SEED_BASE` 자리에 아직 없는 바깥 경로를 가리키는 링크 → `seed_edit_diff.py init` 뒤 바깥 경로가 생기지 않았고 기준 사본은 seed 와 같은 일반 파일.
  - `sed_accept_base_link` — 기준 사본 자리가 바깥 파일 링크 · `.shown` 이 지금 seed 의 해시 → `accept` 뒤 바깥 파일 그대로 · 기준 사본은 일반 파일.
  - `sed_hunks_shown_link` — `.shown` 자리가 바깥 파일 링크 → `hunks` 뒤 바깥 파일 그대로 · `.shown` 은 해시를 담은 일반 파일.
  - `sed_revert_markers_link` — `.shown`(해시는 맞게) · `.reverted` 자리가 바깥 링크 → `revert --ids 1` 뒤 두 바깥 파일 그대로.
  - `ds_save_symlink_refused` — 원장 `docreview-state.md` 가 바깥 파일 링크 → `docreview_state.py init --state-dir … --doc … --profile <design-doc 프로필>` 이 rc 1 · stderr 에 `ledger_not_plain_file` · 바깥 파일 그대로. 하드 링크(링크 수 2)도 같다.
  - `ds_era_link_not_followed` — 시대 표지 자리에 아직 없는 바깥 경로를 가리키는 링크 → 원장 저장 뒤 바깥 경로가 생기지 않았다(원장은 저장된다).
  - `ds_inplace_ro_dir_kept` — 폴더 `chmod 555` · 원장은 쓰기 가능한 일반 파일 → 원장 갱신이 된다(지금 성질 — 양성 짝).
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: 고친다**
  - `seed_edit_diff.py`: `import nofollow_write`. `shutil.copyfile(seed, base)` 둘 → `nofollow_write.replace_bytes(base, seed.read_bytes())`. `shown.write_text(…)` 둘 · `marker.write_text(…)` → `replace_bytes(<경로>, <글>.encode("utf-8"))`. :195(사용자 seed 쓰기)는 그대로. `shutil` import 가 남지 않으면 지운다.
  - `docreview_state.save_state`: 원장은 `os.open(path, O_WRONLY | O_CREAT | O_NOFOLLOW, 0o666)` → `fstat` 이 일반 파일 · `st_nlink == 1` 이 아니거나 `ELOOP` 이면 `LedgerCorrupt("ledger_not_plain_file", path=…)` → `ftruncate(0)` → 쓰기. 시대 표지는 `os.open(era, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o666)` 후 닫기(실패는 지금 `except OSError` 갈래). 「제자리 덮어쓰기」 주석은 유지.
- [ ] **Step 4: 통과를 본다** — `bash plugins/spec-distill/tests/test_state_dir_writes.sh` · 이웃 `plugins/spec-distill/tests/test_seed_edit_diff.sh` · `shared/tests/test_docreview_state.sh` · `plugins/spec-distill/tests/test_reviewing_spec_residue.sh` · `test_reviewing_brief_residue.sh` · `test_reviewing_spec_entry_fence.sh`.
- [ ] **Step 5: 커밋 → 변이(`save_state` 를 `open(…, "wb")` 로 되돌림 · `seed_edit_diff` 의 `replace_bytes` 하나를 `write_text` 로) RED 확인 → 복원.**

---

### Task 4: `state_path.py state-root-for` (AC9 단위 부분)

**Files:**
- Modify: `plugins/spec-distill/scripts/state_path.py`(docstring CLI 목록 · `main` · `payload-root` 본문을 함수로)
- Create: `plugins/spec-distill/tests/test_ledger_root.sh`(100755 — Task 6 이 이어 쓴다)

**Interfaces:**
- Produces: `payload_root(payload: str) -> tuple[str | None, bool, str | None]` = (뿌리, git 인가, 거부 사유). `payload-root` CLI 는 이것을 부르고 출력 · rc 가 지금과 같다.
- Produces(CLI): `state_path.py state-root-for <문서 경로>` → stdout 에 상태 루트. 빈 인자 → `state_root()` 와 같다(공시 없음). 링크를 지나는 폴더 → `payload-root` 와 같은 사유 · rc 2 · stdout 비움. git 작업 트리 안 → `state_root(<문서 폴더>)`. 밖 → `state_root()` + stderr `[spec-distill] 문서가 git 작업 트리 밖이다 — 지금 작업 폴더의 레포 원장을 쓴다: <문서 경로>` · rc 0.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — 임시 레포 A · B(`git init -q`), A 에 연결된 worktree 하나.
  - `srf_inside_other_repo` — cwd=B, 문서 A/docs/x.md → stdout = `A/.claude/spec-distill`(`pwd -P` 기준) · stderr 비움.
  - `srf_linked_worktree` — 문서가 A 의 연결된 worktree 안 → A 본 레포의 상태 루트(공용 git 폴더 기준).
  - `srf_outside_git` — cwd=B, 문서 `$T/nogit/x.md` → stdout = B 의 상태 루트 · stderr 가 정확히 위 문장 한 줄.
  - `srf_empty_is_state_root` — 빈 인자 → `state-root` 출력과 같다 · stderr 비움.
  - `srf_relative` — cwd=A, `docs/x.md` → A 의 상태 루트.
  - `srf_missing_folder` — 문서 폴더가 없는 A 안 경로 → `payload-root` 와 같은 rc · 출력.
  - `srf_link_folder_refused` — A 안의 폴더 링크를 지나는 문서 → rc 2 · stdout 비움(`payload-root` 와 같은 사유 줄).
  - `existing_unchanged` — `state-root` · `state-root <cwd>` · `payload-root` 출력이 고치기 전 커밋의 것과 같다(같은 입력 셋으로 대조).
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: 구현** — `payload-root` 본문을 `payload_root()` 로 옮기고 두 하위 명령이 함께 쓴다. 상대 경로는 `os.path.abspath` 로.
- [ ] **Step 4: 통과** — `bash plugins/spec-distill/tests/test_ledger_root.sh && bash plugins/spec-distill/tests/test_state_path.sh`.
- [ ] **Step 5: 커밋.**

---

### Task 5: 세 skill 펜스의 쓰기 → writer · 도출 락 (AC6 · AC7 펜스 부분)

**Files:**
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`(:557-558 · :561 · :630 · :717 · :861 · :883 · :1229 · :1268)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`(`touch` 일곱 :62 · :112 · :206 · :278 · :439 · :480 · :638 · `>>` 셋 :115 · :452 · :490 · `: >` :211 · :283 · :369 · 번들 :295 · :114 자리표 따옴표)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`(:395)
- Test: `plugins/spec-distill/tests/test_state_dir_writes.sh`
- Modify(Q1): `test_interview_state_flow.sh` · `test_ledger_wiring.sh`(:871) · `test_reviewing_brief_skill.sh`(:416) · `test_reviewing_brief_residue.sh`(:513-523)

**Interfaces:**
- Consumes: Task 1 CLI. 펜스의 writer 경로는 그 펜스의 루트 변수(`$PR` 또는 `$SD`) + `/scripts/nofollow_write.py`.
- Produces: `scan_writes <md 파일>` (테스트 안 함수) — rc 0 깨끗 · 1 위반, stderr 줄마다 `<줄 번호>: <사유>: <글>`.

이 과제는 쓰기 줄만 바꾼다 — `state-root` 줄은 Task 6 이 바꾼다(같은 줄을 두 번 고치지 않는다).

- [ ] **Step 1: 락을 쓴다** — `scan_writes` 는 `python3 -I - "$f" <<'PY'` 로(`$( )` 안에 heredoc 을 두지 않는다).
  - 대상 도출: `git ls-files -- 'plugins/spec-distill/skills/request-framing/*' 'plugins/spec-distill/skills/reviewing-brief/*' 'plugins/spec-distill/skills/spec-review/*'` 의 `*.md`(0개면 RED).
  - 펜스 가르기: `^[ \t]*(`{3,}|~{3,})` 로 열고 같은 표지 줄로 닫는다(`newline=""` 로 읽어 CR 을 지우지 않는다). 첫 줄이 정확히 ```` ```bash ```` 인 펜스만 셸로 읽는다.
  - **```bash 펜스 읽기(문자 단위):** `\`+줄바꿈 잇기(작은따옴표 밖) · 작은따옴표 · 큰따옴표(`\` 이스케이프) · 낱말 머리의 `#` 주석 · `$( )`/역따옴표 안은 다시 보통 상태(큰따옴표 안의 `$(` 포함). heredoc(`<<` · `<<-`, `<<<` 아님)은 구분자를 읽고 그 줄 끝 다음부터 구분자 줄까지 본문을 건너뛴다 — 따옴표 없는 구분자인데 본문에 `$(` 나 역따옴표가 있으면 「읽을 수 없는 heredoc 본문」. 넘기기 연산자 `>` · `>>` · `>|` · `&>` · `&>>` · `N>` · `N>>` 를 잡고(`>&N` · `>&-` · `N>&M` 은 fd 복제라 뺀다), `>(` 는 「프로세스 치환」 위반. 명령 자리(줄 머리 · `|` `||` `&&` `;` `(` `{` `!` `then` `do` `else` `elif` `$(` 뒤, 앞의 `NAME=값` 은 건너뜀)의 `tee` · `touch` 는 옵션 아닌 인자가 대상이다. `exec >` · `{ … } >` 는 넘기기로 잡힌다.
  - 허용 대상: `/dev/null` · 대상 전체가 변수 하나(`"$V"` · `"${V}"` · `$V`)이고 `V` 가 같은 펜스의 「mktemp 변수」 — 그 펜스에서 `V` 의 대입이 전부 `$(mktemp …)`(안에 `|| printf '/dev/null'` 허용) 이거나 빈 값(`""` · `''` · 없음)일 때. 그 밖은 위반.
  - **다른 펜스:** ```` ```bash ```` 가 아닌 모든 펜스(```` ```sh ```` · 들여쓴 · 꼬리 공백 · CRLF · `~~~` · 빈 info · 다른 언어)는 줄마다 자리표 `<[^<>\s][^<>\n]*?>` 를 지운 뒤 `(?:^|[\s;&|({])(?:\d*>>?|&>>?|>\|)(?!&)\s*\S` · `(?:^|[\s;&|({])(?:tee|touch)\s` · `exec\s*\d*>` 가 남으면 「검사 밖 펜스의 쓰기」.
  - **실제 셸과 교차 확인:** ```` ```bash ```` 펜스마다 (가) `/bin/bash -n` 이 통과해야 한다(아니면 「셸이 읽지 못하는 펜스」) (나) `f__() {`+펜스+`}` 를 `/bin/bash` 에서 `declare -f f__` 로 펴 낸 본문을 같은 읽기로 다시 읽어, 넘기기 대상의 다중집합이 원문 읽기와 같아야 한다(아니면 「실제 셸과 다르게 읽음」).
  - 단언: 대상 파일마다 `scan_writes` GREEN. 음성 프로브(```` ```bash ```` 한 펜스에 하나씩, 각 RED): `cmd > "$STATE_DIR/x"` · `>> "$STATE_DIR/x"` · `>| "$STATE_DIR/x"` · `&> "$STATE_DIR/x"` · `2> "$STATE_DIR/x"` · `{ a; b; } > "$STATE_DIR/x"` · `exec > "$STATE_DIR/x"` · `cmd | tee "$STATE_DIR/x"` · `touch "$STATE_DIR/x"` · `x="$(cmd > "$STATE_DIR/y")"` · `x="$(mktemp)"; x="$STATE_DIR/y"; echo > "$x"` · `tee >(cat)` · 따옴표 없는 구분자 heredoc 본문의 `$(touch y)` · `cmd \`+줄바꿈+`> "$STATE_DIR/x"`. 펜스 모양 프로브(각 RED): ```` ```sh ```` · ```` ```shell ```` · `  ```bash` · ```` ```bash ```` + 공백 · `~~~bash` · ```` ```BASH ```` · CRLF 펜스에 `> "$STATE_DIR/x"`. 양성 대조(각 GREEN): `T="$(mktemp)"; cat > "$T" <<'EOF'` + 본문 `> "$STATE_DIR/y"` + `EOF` · `e="$(mktemp 2>/dev/null || printf '/dev/null')"; cmd 2>"$e"` · `>&2` · `2>&1` · `2>/dev/null` · `echo "a > b"` · `# x > y` 주석 · 자리표 펜스 `<document>${DOCUMENT}</document>` · `rm -f "$STATE_DIR/x"`.
- [ ] **Step 2: 돌려 실패를 본다** — 세 파일이 RED 이고 위반 줄이 위 `Files` 의 자리와 같다(다른 자리가 나오면 그 자리도 이 과제 몫이다).
- [ ] **Step 3: 펜스를 고친다**(`<루트>` 는 그 펜스가 머리에서 세운 루트 변수 — `$PR` 또는 `$SD`)
  - 번들 · 산출물: `X > "$F" || r=…` → `python3 "<루트>/scripts/nofollow_write.py" run --out "$F" -- X || r=…`(RF :557 · :558 · :883 · :1229, RB :295).
  - `printf … > F`: → `run --out F -- printf …`(RF :717 · :861 · :1268 — `elif !` · `||` 갈래는 지금 꼴 그대로).
  - 비우기 `: > X 2>/dev/null || true`: → `python3 "<루트>/scripts/nofollow_write.py" empty --out X 2>/dev/null || true`(RF :561 · :630, RB :211 · :283 · :369, SR :395). 바로 뒤의 `[ -s … ]` 확인은 그대로.
  - `touch "${DEGRADE_FALLBACK_FILE:-/nonexistent/brief-degrade}" 2>/dev/null || …` → `python3 "$PR/scripts/nofollow_write.py" append --out "${DEGRADE_FALLBACK_FILE:-/nonexistent/brief-degrade}" </dev/null 2>/dev/null || …`(일곱 펜스 같은 글자).
  - `|| echo "<줄>" >> "$DEGRADE_FALLBACK_FILE"` → `|| printf '%s\n' "<줄>" | python3 "$PR/scripts/nofollow_write.py" append --out "$DEGRADE_FALLBACK_FILE"`(RB :115 · :452 · :490).
  - RB :114 의 따옴표 밖 자리표 `<a>` · `<b>` · `<c>` 를 `"<a>"` 꼴로 감싼다 — 셸은 그것을 넘기기로 읽는다. 락이 다른 따옴표 밖 자리표를 알리면 같이 감싼다.
- [ ] **Step 4: 끝에서 끝을 더한다**(같은 파일) — 펜스를 마커 · 머리로 잘라 임시 레포에서 실제로 돈다(펜스 자르기와 실행 틀은 `test_reviewing_brief_residue.sh` 의 `cut_block` · `run_bundle` 과 `test_ledger_wiring.sh` 의 `fence` 를 따른다):
  - `rb_bundle_fence_link` — RB 번들 펜스: `$BUNDLE` 자리에 바깥 파일 링크 → 펜스 뒤 바깥 파일 그대로 · 번들은 일반 파일. 하드 링크도.
  - `rb_bundle_ro_dir_clears_stale` — 상태 폴더 `chmod 555` · 직전 번들(쓰기 가능, 내용 `OLD`) → 펜스가 0 아닌 rc 로 멈추고 번들에 `OLD` 가 없다(Review Focus 1).
  - `rf_bundle_fence_link` — RF 번들 펜스를 변수(`SD` · `STATE_DIR` · `BUNDLE` · `BUNDLE_RC` · `SEED_ABS` · `AUDIT_ABS`)를 앞에 대입해 돌린다: 두 번들 자리의 바깥 링크가 그대로.
  - `rf_hunks_and_drops_link` — `hunks.json` · `gate-drops.json` 자리의 바깥 링크(엔진 원장은 `docreview_state.py init` 으로 만든다) → 펜스 뒤 바깥 파일 그대로.
  - `rb_degrade_fallback_link` — `brief-degrade-fallback.txt` 자리의 바깥 링크 · `degrade-append` 가 실패하는 기록 펜스(`## kill switch`) → 바깥 파일 그대로.
  - `nlink_one_after_rounds` — 위 실행 뒤 상태 폴더 안 일반 파일의 링크 수가 모두 1(`find -type f -links +1` 비움). 계획 작성 때 실측: 메인 레포 상태 루트의 일반 파일 27,562개 중 링크 수 2 이상 0개 · `.docreview/` 안 링크 0개.
- [ ] **Step 5: Q1 의 넷을 고친다** — 옛 리터럴 단언은 새 줄(writer 호출)로, 「잠긴 번들」 은 「writer 가 이름을 바꿔 새 번들을 놓는다 — rc 0 · `OLD` 없음」 으로, `test_interview_state_flow.sh` 의 머리 끝 찾기는 새 `append` 줄로.
- [ ] **Step 6: 통과** — `bash plugins/spec-distill/tests/test_state_dir_writes.sh` 와 이웃 `test_ledger_wiring.sh test_reviewing_brief_skill.sh test_reviewing_brief_residue.sh test_interview_state_flow.sh test_brief_bundle.sh test_reviewing_spec_residue.sh test_framing_review_contract.sh test_dispatch_profile_inline.sh test_seed_gate_wiring.sh test_seed_codex_axes.sh test_brief_codex_axes.sh test_request_framing_open.sh` · `shared/tests/test_plugin_root_no_cwd_fallback.sh test_inline_python_isolated.sh test_skill_body_no_positional_tokens.sh`.
- [ ] **Step 7: 커밋 → 변이** — 각 파일에서 writer 줄 하나씩을 옛 꼴(`>` · `: >` · `touch` · `>>`)로 되돌림 → RED, `scan_writes` 의 heredoc 건너뛰기를 끔 → 양성 대조 RED, 허용 대상에서 `mktemp` 를 뺌 → 양성 대조 RED, 교차 확인 (나) 를 끔 → `cmd \`+줄바꿈 프로브가 어떻게 되는지 기록. 복원 확인.

---

### Task 6: 원장 뿌리를 문서의 레포에서 — 펜스 · 공시 · 락 (AC9 · AC10)

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`(`state-root` 열 자리 · `ledger-open` 공시)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`(`state-root` 아홉 자리 · `ledger-open` 공시 · `decision-line` 펜스 :693-724 · 그 위 산문의 rc 1 사유 목록)
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md`(:330 · :379)
- Test: `plugins/spec-distill/tests/test_ledger_root.sh`
- Modify(Q1): `test_ledger_wiring.sh`(:410 스텁 · :469-473) · `test_reviewing_spec_state_keying.sh`(:35)

**Interfaces:**
- Consumes: Task 4 `state-root-for`.
- Produces: 원장 열기 공시 문장 `[spec-distill] 리뷰 원장은 문서가 사는 레포(${doc_top})의 것을 쓴다 — 지금 작업 폴더의 레포(${here_top:-없음})와 다르다.`

- [ ] **Step 1: 실패하는 테스트를 더한다**
  - `root_lock` — RB · SR · finishing.md 에 `state_path.py" state-root` 뒤에 `-for` 가 오지 않는 호출이 0. `state-root-for` 의 첫 인자가 RB · finishing.md 는 `"$PAYLOAD"` 또는 `"${PAYLOAD:-}"`, SR 은 `"${spec_path:-}"` 또는 `"$spec_path"`. 양의 짝: 세 파일 모두 `state-root-for` 가 1번 이상. RF 는 맨 `state-root` 가 정확히 하나이고 `## 상태` 절 안이다(이유: seed 경로를 `$(pwd)/$SEED` 로 만든다) — 둘째 맨 호출은 RED. 변이: RB 의 한 호출을 맨 `state-root` 로 · RF 에 맨 호출 하나 추가 → 각각 RED.
  - `e2e_other_repo` — cwd=B, 설계문서 A/docs/d-design.md(`## 결정 기록` 있음): SR `ledger-open` → 마지막 줄 `ledger-open: HELD` · 원장 자리가 A 의 상태 루트 아래 · 공시 문장이 정확히 한 번 · B 에 `.claude` 가 생기지 않음. `docreview_state.py init` + `begin-round`(틀은 `test_ledger_wiring.sh` :419-425) 뒤 `decision-line` 펜스 → rc 0 · 결정 줄 한 줄이 문서에 · 「결정 줄은 문서가 사는 레포」 줄 · rc 3 아님.
  - `e2e_same_repo_no_notice` — cwd=A → 두 펜스 출력에 「지금 작업 폴더의 레포(」 없음.
  - `e2e_rb_ledger_open` — RB `ledger-open` 도 cwd=B, payload 가 A 에 있을 때 A 원장 · 공시 한 번.
  - `e2e_outside_git` — 문서 `$T/nogit/d-design.md`, cwd=B: `ledger-open` 이 B 상태 루트 아래 원장을 열고 git 밖 문장(Task 4)이 정확히 한 번 · 「지금 작업 폴더의 레포(」 없음. 이어 `decision-line` 이 거절하지 않고(「git 작업 트리 밖이다」 거절 문장 없음) 같은 원장에 써 rc 0 · 결정 줄이 문서에 · git 밖 문장이 나온다.
  - `prose_limits` — SR 결정 줄 산문의 rc 1 사유 목록에 「문서가 git 작업 트리 밖이다」 가 없다(음) · 그 문단에 「git 작업 트리 밖이면 지금 작업 폴더 레포의 원장에 쓴다」 가 있다(양).
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: 펜스를 고친다**
  - 모든 `ROOT="$(python3 "<루트>/scripts/state_path.py" state-root || true)"` 류 → `state-root-for "<문서 변수>"` 만 끼운다(대입 꼴 `|| true` · `${ROOT:-…}` 그대로). 문서 변수는 RB `"${PAYLOAD:-}"` · SR `"${spec_path:-}"` · finishing.md `"$PAYLOAD"`(펜스가 먼저 대입한다). SR :189 의 `|| true` 없는 꼴도 그대로 둔다.
  - RB · SR `ledger-open` 펜스: `ROOT` 줄 다음에 `common_dir()`(SR :698 과 같은 글자) · `here_top` · `here_common` 을 두고, 문서 폴더가 git 안이면(`doc_top="$(cd "$(dirname "<문서>")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)"`) 공용 git 폴더를 비교해 다르면 위 공시 문장을 낸다. 문서 변수가 비면 건너뛴다. 마지막 줄 판결은 그대로 마지막이다.
  - `decision-line` 펜스: `here_top` · `here_common` 다음, `cd` **앞**에 `ROOT="$(python3 "$SD/scripts/state_path.py" state-root-for "$spec_path" || true)"`. `cd` 뒤 `doc_top` 이 나오면 지금 비교 · 문장(:703) 그대로, 안 나오면 비교 없이 계속(거절 줄 :702 삭제). 아래의 옛 `ROOT=` 줄은 지운다.
  - SR 산문(:690 rc 1 사유 목록)에서 「문서가 git 작업 트리 밖이다」 를 빼고 git 밖이면 cwd 레포 원장에 쓴다는 한 줄을 더한다.
- [ ] **Step 4: Q1 의 둘을 고친다** — `test_ledger_wiring.sh` :410 스텁은 `state-root` · `state-root-for` 둘 다 실패시킨다. :469-473 은 「git 밖이면 cwd 원장에 쓰고 git 밖 줄을 낸다」 로 뒤집는다. `test_reviewing_spec_state_keying.sh` :35 의 리터럴을 `state-root-for` 로.
- [ ] **Step 5: 통과** — `bash plugins/spec-distill/tests/test_ledger_root.sh` · 이웃 `test_ledger_wiring.sh test_reviewing_spec_state_keying.sh test_reviewing_spec_entry_fence.sh test_dispatch_profile_inline.sh test_brief_review_ng3.sh test_decompose_surface.sh test_state_dir_writes.sh test_reviewing_brief_residue.sh test_reviewing_spec_residue.sh test_interview_state_flow.sh`.
- [ ] **Step 6: 커밋 → 변이(`root_lock` 의 둘 · 결정 줄 펜스의 `state-root-for` 를 `cd` 뒤로 옮김 → `e2e_outside_git` RED · 공시 비교를 지움 → `e2e_other_repo` RED) → 복원.**

---

### Task 7: 인터뷰를 닫은 답의 출처 대조 (AC1 · AC2 · AC3)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`(공개 함수 하나 · 두 기존 함수가 같은 도우미를 쓰게)
- Modify: `plugins/spec-distill/scripts/check_verbatim_coverage.py`(`parse_user_statements` · `run` · `main` 예외 JSON · docstring exit 표)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`(rc 표 · 진입 펜스 `1)` 문장)
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md`(Step A ④ 「통째로 다시 쓴다」 · Step A.5 되묻기 갈래)
- Modify: `plugins/spec-distill/README.md` · `CHANGELOG.md`(§2 시점 한계 — 판 머리는 Task 11)
- Test: `plugins/spec-distill/tests/test_check_verbatim_coverage.sh` · `plugins/spec-distill/tests/fixtures/`(새 대조 픽스처)

**Interfaces:**
- Produces: `check_brief.closing_answer_anchors(payload_text: str, audit_text: str) -> list[tuple[str, str]]` — `("S<n>", "irrelevant")`(§4 의 불릿 없는 「외부 선례 무관(@S<n>) — …」 줄마다, 같은 S 는 한 번) + `("S<n>", "saturation")`(audit §2 의 **마지막** 포화 판정 줄이 「사용자 판단 포화(@S<n>)」 일 때만). 「사용자 종료」 는 넣지 않는다.
- Produces: `parse_user_statements` 항목 = `{"id", "text", "source"}`(`source` 는 `_unquote` 값, 키가 없으면 `None`).
- Produces: `run()` 결과 키 `not_chosen: list[str]`(번호 순 · 중복 없음). `main` 의 예외 JSON 도 이 키를 갖는다.

- [ ] **Step 1: 픽스처와 실패하는 테스트를 쓴다** — 쌍은 `interview-brief-v2-valid.{md,audit.md}` 에서 `test_check_brief.sh` `irr_build` 와 같은 변형으로 만들고(§4 항목 둘을 지우고 닫힘 줄을 넣는다 · `- **S2** ☑ 선택 …` 앵커를 payload §6 · audit §6 에), state 는 S 마다 `source` 를 바꿔 쓴다. 새 픽스처 파일은 `fixtures/brief-closing-*.md` 로 둔다.
  - `vc_irrelevant_verbatim_rc1` — 「외부 선례 무관(@S2)」 · S2 `verbatim` → rc 1 · `"not_chosen": ["S2"]` · `advisories` 에 S2 · 「마무리 단계」 문장. 같은 쌍에 S2 `chosen` → 이 대조로 막지 않는다(rc 0, `not_chosen` 빔).
  - `vc_saturation_last_line` — audit §2 마지막 줄 「포화 판정 2: 사용자 판단 포화(@S3) — 조사 불필요」 · S3 `verbatim` → rc 1 · `["S3"]`. 앞 줄이 사용자 판단 포화(@S3)이고 마지막 줄이 판정자 「포화 — …」 → 대조 안 함(rc 0). 마지막 줄 「사용자 종료(@S3) — 포화 판정 전」 · S3 `verbatim` → rc 0.
  - `vc_record_missing_rc1` — 대상 S 가 state 에 없음 → rc 1 · 그 S.
  - `vc_source_absent_rc3` — 대상 레코드에 `source` 키 없음(또는 빈 값) → rc 3 · advisory 「검사 불가」 · `not_chosen` 빔.
  - `vc_source_unknown_value_rc1` — `source: selected` · `source: Chosen` → 각 rc 1(Review Focus 2).
  - `vc_s1_chosen_passes` — 최초 요청 없는 인터뷰(S1 이 첫 답, `chosen`)가 S1 을 가리킴 → rc 0. 최초 요청이 있는 인터뷰(S1 은 state 에 없음)의 「외부 선례 무관(@S1)」 → rc 1.
  - `vc_not_chosen_dedup_sorted` — 「외부 선례 무관(@S4)」 두 줄 + 「…(@S2)」 + 마지막 포화 줄 「사용자 판단 포화(@S4)」, S2 · S4 `verbatim` → `["S2", "S4"]`(Review Focus 3).
  - `vc_violation_beats_indeterminate` — 다른 S 의 P21 자리표로 검사 불가가 섞여도 `not_chosen` 이 있으면 rc 1. user_statements 가 0건이어도 대상이 있으면 rc 1.
  - `check_brief_invariant` — `check_brief.py` 가 state 를 열지 않는다(기존 docstring 문장 그대로 + `test_check_brief.sh` 의 기존 불변식 단언 GREEN).
  - `rb_gate_skip_var_not_chosen` — RB 진입 게이트 펜스(`gate_rc=0;` 부터 펜스 끝까지, `test_reviewing_brief_skill.sh:159-160` 의 자르기 꼴)를 실제 `check_brief.py` · `check_verbatim_coverage.py` 로 돌린다: `not_chosen` 쌍 + `DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE=1` + 오늘 날짜 rc 1 증거 줄 → rc 1 로 멈춘다.
  - `rebuild_once_and_idempotent` — `not_chosen` 쌍(사용자 판단 포화 @S3, S3 `verbatim`)에 되묻기 결과를 넣는다: state 에 S9 `chosen` 을 더하고 `## audit §2 대기 줄` 끝에 `- 포화 판정 2: 사용자 판단 포화(@S9) — 조사 불필요` 를 덧붙인다. 테스트 도우미 `rebuild_step_a`(audit §2 의 사건 줄을 대기 줄 블록으로 통째로 다시 쓰고, payload §6 · audit §6 에 없는 S 를 state 에서 더한다)를 돌리면 audit §2 에 `@S9` 줄이 정확히 한 번 · 대조 rc 0 · `check_brief.py gate` rc 0. 도우미를 한 번 더 돌리면 세 파일의 바이트가 같다.
  - `rebuild_irrelevant_keeps_last_saturation` — 「외부 선례 무관(@S2)」 쌍의 되묻기: brief §4 의 `@S2` 만 `@S9` 로 바꾸고 S9 `chosen` 을 더함 → 대조 · 게이트 통과, audit §2 마지막 포화 판정 줄은 바꾸기 전과 같은 글자.
  - 문장 단언: RB rc 표에 `` `1`(`not_chosen`) `` 행 · 그 행에 「마무리 단계가 그 질문을 선택지로 다시 묻는다」. finishing Step A.5 에 되묻기 갈래 — 「닫는 선택지」 · 「조사 계속」 · 「대기 줄 블록 한 곳에만」 · 「brief §4 그 줄의 `@S` 만」 · 「3 · 4 · 7 · 8 을 다시 돈 뒤 Step A.5 로」 · 「세션을 넘겨」. finishing Step A ④ 에 「다시 돌 때는 … 통째로 다시 쓴다」. README 에 시점 한계 문장(아래 Step 3) · 출처 한계 「사용자가 골랐는지는 증명하지 못한다」 유지. CHANGELOG 의 새 항목에 같은 시점 한계.
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: 구현**
  - `check_brief.py`: 내부 도우미 `_irrelevant_sids(payload_text) -> list[str]`(지금 `landscape_irrelevant` 의 추출) · `_sat_hits(audit_text) -> list[str]`(지금 `saturation_failures` 의 `hits`)를 빼내 두 기존 함수가 쓰게 하고, 그 위에 `closing_answer_anchors` 를 둔다.
  - `check_verbatim_coverage.py`: `import check_brief`(같은 `scripts/`). `parse_user_statements` 가 `source:` 줄을 읽는다. `run` 은 세 파일을 읽고 판독한 뒤 — 빈 `user_statements` 조기 반환 **앞에서** — 대상 S 마다 판정해 `not_chosen` · 검사 불가 표시를 모은다. 판정 순서는 위반 > 검사 불가 > 통과 그대로. `not_chosen` 이 비지 않으면 advisory 한 줄: `인터뷰를 닫은 답 <S 목록>(<외부 선례 무관 | 사용자 판단 포화>)이 고른 선택지로 기록되지 않았다 — 마무리 단계(finishing Step A.5)가 그 질문을 선택지로 다시 묻는다. 이 리뷰를 다른 세션에서 따로 불렀다면 끝난 인터뷰라 이어 갈 수 없다`. docstring exit 표의 1 에 `not_chosen` 을 더한다.
  - RB rc 표: 기존 `1` 행 아래에 설계 §2 표의 행 그대로(뜻 · 동작). 진입 펜스 `1)` 문장은 「§6 원문 완전성 위반이나 닫은 답의 출처 위반」 꼴로.
  - finishing Step A ④ 끝에 「Step A.5 의 되묻기 갈래로 다시 돌 때는 audit §2 의 사건 줄 · §5 의 옮긴 줄 · payload §6 · audit §6 을 state 에서 통째로 다시 쓴다 — 덧붙이지 않는다」. Step A.5 불릿 목록 뒤에 설계 §2 표 「동작」 칸의 되묻기 갈래 문단(닫는 선택지 → state 기록 · 사용자 판단 포화면 대기 줄 블록 한 곳에만 덧붙임 / 외부 선례 무관이면 brief §4 그 줄의 `@S` 만 바꿈 → Step A 3 · 4 · 7 · 8(로드맵이 있을 때)을 다시 돈 뒤 Step A.5 로 / 「조사 계속」 → 같은 세션의 라운드 루프, 다시 닫을 때 finishing 처음부터 · 세션을 넘겨 따로 부른 리뷰에서는 이어 갈 수 없다).
  - README :101 문단 끝에 시점 한계 한 문장: 「이 대조는 brief 를 쓴 뒤 리뷰 진입(`check_verbatim_coverage.py`)에서 돈다 — 리뷰를 거치지 않는 길에서는 돌지 않는다.」 그리고 대조가 state 의 `source: chosen` 을 보게 됐다는 한 줄.
- [ ] **Step 4: 통과** — `bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh` · 이웃 `test_check_brief.sh test_reviewing_brief_skill.sh test_readme_sync.sh test_open_research.sh test_saturation_reference.sh` · `python3 -m unittest plugins/spec-distill/tests/test_audit_template_gate_shape.py`.
- [ ] **Step 5: 커밋 → 변이** — `source` 판정을 `!= "verbatim"` 으로 넓힘(→ `vc_source_unknown_value_rc1` RED) · 마지막 줄 대신 아무 줄의 사용자 판단 포화를 봄(→ `vc_saturation_last_line` RED) · 대상 판정을 빈 원장 조기 반환 뒤로 옮김(→ `vc_violation_beats_indeterminate` RED) · `closing_answer_anchors` 에 사용자 종료를 넣음(→ RED). 복원.

---

### Task 8: V1 확인 줄의 자리 (AC8)

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/SKILL.md`(V1 ⑤ :210-211 · :216 — 줄 수 그대로)
- Modify: `plugins/spec-distill/skills/pm-interview/references/steelman.md`(Step 2 :59-63)
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md`(Step A ④ — 「대체됨」 옮기기 문장 옆)
- Test: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`(:537 · :756) · `plugins/spec-distill/tests/test_fresh_evidence.sh`

- [ ] **Step 1: 단언을 바꾼다**
  - 음(부재): SKILL 에 `audit \`## 5. 프로세스 로그\` 에 한 줄로 적는다` 없음 · steelman.md 에 `audit §5 줄도 함께 남긴다` 없음.
  - 양: SKILL V1 ⑤ 에 「그 라운드의 state `## R<n>` «지금 이해» 아래에 한 줄로 적는다」 와 확인 줄 꼴 셋(`- 확인 RC3 — 확인 — …` 등) · steelman Step 2 에 「state `## R<n>` «지금 이해» 아래에도 함께 남긴다」 · `확인 RC<n> — {확인|반증|미확인}` · 「확인 «행위» 는 한 번이고」. finishing Step A ④ 에 「`- 확인 RC<n> — …` 줄을 라운드 순서대로 audit `## 5. 프로세스 로그` 에 글자 그대로 옮겨 씁니다」.
  - 래칫 단언(:583-590)은 그대로 GREEN 이어야 한다. `test_fresh_evidence.sh` 에 Step A 문장 단언 하나(확인 줄 옮기기가 「대체됨」 옮기기와 같은 걸음에 있다).
  - 게이트: v2-valid audit §5 에서 `- 확인 RC3 …` 줄을 지운 사본 → `check_brief.py gate` red(기존 게이트 ⑤ — 지금처럼).
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: 문면을 고친다** — SKILL ⑤ 는 같은 줄 수로 다시 감는다. :216 은 「판정만 audit §3 `ST<N>` 과 확인 줄 자리 양쪽에 적는다」. steelman :59-63 은 확인 줄을 state 라운드 기록에 두고 끝날 때 finishing 이 audit §5 로 옮긴다고 적는다(「§5 를 빼면 게이트가 막는다」 문장은 「옮기지 않으면」 으로). SKILL :155 「audit §5 의 확인 줄이 곧 레지스터」 는 그대로.
- [ ] **Step 4: 통과** — `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh && bash plugins/spec-distill/tests/test_fresh_evidence.sh && bash plugins/spec-distill/tests/test_saturation_reference.sh`.
- [ ] **Step 5: 커밋 → 변이(옛 문장 하나를 되살림 → 음 RED · finishing 옮기기 문장 삭제 → 양 RED) → 복원.**

---

### Task 9: 로드맵 생성 명령의 따옴표 (AC11)

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md`(Step A 8 펜스 :202-209 · 그 앞 문단)
- Test: `plugins/spec-distill/tests/test_decompose_surface.sh`

- [ ] **Step 1: 실패하는 테스트를 쓴다**
  - 문면: Step A 8 창에 `IFS= read -r title <<'DEVBREW_ROADMAP_TITLE_EOF'` · `<주제 한 줄>` · `cat > "$AF1" <<'DEVBREW_ROADMAP_APPROVAL_EOF'` · `<승인 원문>` · `--title="$title"` · `--approval="$(cat "$AF1")"` · 구분 줄이 글에 있으면 바꾸는 규칙 · 말이 여럿이면 `AF<k>` 를 더하는 규칙. 부재: `--title "<주제 한 줄>"` · `--approval "<승인 원문>"`. 기존 `--plan-table "${BRIEF_REL%.md}.state.md"` · `--audit "${BRIEF_REL%.md}.audit.md"` 단언 유지. B-R 은 「Step A 8 의 명령을 그대로」.
  - `stepa8_e2e_verbatim` — 임시 레포에 `create` 가 받는 brief · audit · state(분해안 표 포함 — 꾸미는 법은 `test_roadmap_write.sh` 의 create 픽스처)를 두고, 펜스를 잘라 `<주제 한 줄>` 자리에 `제목 $HOME \`id\` "q" 'a'`, `<승인 원문>` 자리에 `-승인 $(touch <T>/pwned) "좋아" 'ok'` 를 넣어 `/bin/bash` 로 돈다(`<YYYY-MM-DD>` · `<file>` · `<주제 …>` 자리표도 채운다). rc 0 · 생성된 로드맵에 두 글이 글자 그대로(어느 줄에 실리는지는 `test_roadmap_write.sh` 의 create 단언을 따른다) · `pwned` 없음.
  - `stepa8_multiline_approval_verbatim` — 승인 원문이 두 줄 → 두 줄 그대로(Review Focus 5).
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: 펜스를 고친다** — `references/redecompose.md` §5 펜스와 같은 꼴: 제목은 `IFS= read -r` + 따옴표 heredoc, 승인 원문은 `AD="$(mktemp -d …)"` · `trap 'rm -rf -- "$AD"' EXIT` · `AF1="$AD/1"` · 따옴표 heredoc, 생성기에는 `--title="$title"` · `--approval="$(cat "$AF1")"`. 펜스 앞 문단에 자리 채우기 · 구분 줄 · 여러 말 규칙(redecompose §5 문단과 같은 내용). 나머지 인자는 그대로.
- [ ] **Step 4: 통과** — `bash plugins/spec-distill/tests/test_decompose_surface.sh && bash plugins/spec-distill/tests/test_roadmap_write.sh`.
- [ ] **Step 5: 커밋 → 변이(`--title="$title"` 를 `--title "<주제 한 줄>"` 로 되돌림 → 부재 · e2e RED) → 복원.**

---

### Task 10: 템플릿 판 꼬리 · 셸 테스트 실행 비트 (AC12 · AC13)

**Files:**
- Modify: `plugins/spec-distill/templates/interview-audit-template.md:6` · `interview-brief-template.md:6`
- Test: `plugins/spec-distill/tests/test_audit_template_gate_shape.py`(템플릿을 읽는 기존 테스트 하나)
- Modify(모드만): `plugins/spec-distill/tests/test_brief_bundle.sh` · `test_brief_no_length_cap.sh` · `shared/tests/test_docreview_gate_visibility.sh` · `test_entry_preflight.sh`
- Create: `shared/tests/test_shell_tests_executable.sh`(100755)

- [ ] **Step 1: 실패하는 테스트를 쓴다**
  - `test_audit_template_gate_shape.py` 에 `test_template_source_has_no_version_tail` — 두 템플릿 frontmatter `source:` 값이 `spec-distill pm-interview` 이고 `v\d` 가 없다.
  - `test_shell_tests_executable.sh` — 고르는 규칙은 `tools/suite/run-all.sh` 에서 꺼낸다: 그 파일에서 `< <(find …)` 의 `find` 명령(파이프 앞까지)을 정규식으로 뽑아 레포 뿌리에서 `bash -c` 로 돌린다(뽑지 못하거나 0개면 RED). 고른 파일마다 `git ls-files -s` 의 mode 가 `100755`(인덱스에 없으면 RED). 양성 대조: 독립 도출(`git ls-files` 의 `shared/tests` · `plugins/*/tests` 아래 이름이 `test_*.sh` 이고 경로에 `/spike/` · `/fixtures/` 가 없는 것) 수 = 뽑은 `find` 의 수.
- [ ] **Step 2: 돌려 실패를 본다** — 판 꼬리 RED · 실행 비트 넷 RED.
- [ ] **Step 3: 고친다** — 두 `source:` 를 `source: spec-distill pm-interview` 로. 넷을 `chmod +x` 하고 각각 `./<경로>` 로 직접 돌려 통과를 본다.
- [ ] **Step 4: 통과 · qg 선택 확인** — 두 테스트 GREEN, `git ls-files -s` 로 넷이 100755. `printf '%s\n' <네 경로> | bash shared/test-selection/run-test-selection.sh assign "$PWD" "$(mktemp)"` 의 배정 파일에서 넷이 `unclaimed` 가 아니다.
- [ ] **Step 5: 커밋 → 변이(넷 중 하나를 `git update-index --chmod=-x` → RED · `run-all.sh` 의 `find` 에서 `-not -path '*/fixtures/*'` 를 지운 사본 → 양성 대조 수가 갈라져 RED) → 복원.**

---

### Task 11: 판 · CHANGELOG · README 한계 (AC14)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`(8.5.0) · `CHANGELOG.md` · `README.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`(14.4.0) · `CHANGELOG.md` · `README.md`

- [ ] **Step 1:** spec-distill CHANGELOG `## [8.5.0] — <머지 날짜>` — Changed(대조 강화 · writer 로 쓰기 · 원장 뿌리 `state-root-for` · V1 확인 줄 자리 · Step A 8 heredoc · 템플릿 판 꼬리 · 실행 비트), Security(링크 따라 쓰기). Task 7 이 쓴 시점 한계 항목을 이 머리 아래로 옮긴다. qg CHANGELOG `## [14.4.0] — <날짜>`: 공유 러너의 산출물 쓰기가 링크를 따라가지 않는다 · writer 링크.
- [ ] **Step 2:** README 한계 — spec-distill: §3(Write 도구로 쓰는 상태 폴더 파일 `said-*.txt` · `readback.txt` · `note-<id>.txt` · `critic*.txt` · `recritic.txt` 는 writer 로 감싸지 못한다 · 마지막 경로 성분만 지킨다 · 실행 중 다시 심는 링크는 지키지 않는다 · 러너의 `write_failclosed` · `_degrade_if_empty` 는 첫 쓰기 뒤라 그대로다), §5(「request-framing 의 원장 정리와 지휘자는 지금 작업 폴더 레포의 뿌리를 쓴다 — 다른 레포의 문서를 리뷰하는 동안에는 지금 작업 폴더 레포의 원장이 그때 정리되지 않는다」), §2 는 Task 7 이 넣었다. qg: §3 의 러너 한 줄. 단언은 `test_state_dir_writes.sh`(§3 문장) · `test_ledger_root.sh`(§5 문장)에 하나씩.
- [ ] **Step 3:** `bash shared/tests/test_changelog_integrity.sh && bash shared/tests/test_plugin_description_parity.sh && bash plugins/spec-distill/tests/test_readme_sync.sh` 와 두 단언.
- [ ] **Step 4: 커밋.**

---

### Task 12: 전체 대조 · 마지막 리뷰 · 미룸 · 덮음 확인

- [ ] **Step 1:** 공유 잠금 아래 `bash tools/suite/run-all.sh > $HOME/.claude/sdd-mirror/r13/after.txt`. `baseline.txt` 에 없던 `FAILED` 줄은 이 계획의 몫이다 — 고치고 다시 돈다.
- [ ] **Step 2: 마지막 전체 리뷰** — 고른 실행 방식의 마지막 리뷰(가장 강한 모델 · 쓰기 권한 없는 리뷰어)에 설계문서 `## Acceptance Criteria` 절 전문(AC1~AC14)을 그대로 싣고, AC 마다 한 줄씩 `AC<n>: <구현됨 | 미룸 | 빠짐> — <근거>` 꼴로 보고하게 한다. 함께 묻는다: 과제 사이 이음매(writer rc 73 을 받는 펜스의 실패 갈래 · `state-root-for` 공시가 원장 열기에서 한 번만 나는지 · Task 5 와 Task 6 이 같은 펜스의 다른 줄을 고친 뒤 펜스가 끝에서 끝으로 도는지), 계획이 쓴 테스트 코드(plan-mandated)의 이빨. 보고를 git 이 추적하지 않는 `$HOME/.claude/sdd-mirror/r13/ac-report.md` 에 적는다.
- [ ] **Step 3:** `미룸` · `빠짐` 판정과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 한 행씩 올린다. R8 로 가는 두 행이 로드맵 R8 범위에 실렸는지 확인하고, 아니면 지휘자에게 알린다.
- [ ] **Step 4:** PR 을 만들기 전에 `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/7.3.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-21-interview-gate-leftovers-design.md $HOME/.claude/sdd-mirror/r13/ac-report.md` 를 돌려 경고를 사용자에게 쉬운 말로 보인다.

---

## `### Deferred to plan` 답

| 항목 | 답 |
|---|---|
| writer 이름 · 자기 실패 rc · `printf` 자리 | 계획이 정함 — `nofollow_write.py` · rc 73 · `run --out f -- printf …`(Task 1 · 2 · 5) |
| `check_brief` 문법을 공개 함수로 묶을지 | 계획이 정함 — `closing_answer_anchors` 하나, 기존 두 함수와 같은 도우미(Task 7) |
| 쓰기 락의 파서 · `bash -n` 교차 · 줄 이음 · heredoc | 계획이 정함 — 문자 단위 읽기 + `/bin/bash -n` + `declare -f` 로 편 본문의 대상 다중집합 대조(Task 5 Step 1) |
| 정상 흐름의 링크 수 1 실측 | 실측함 — 메인 레포 상태 루트 일반 파일 27,562개 중 링크 수 2 이상 0 · `.docreview/` 링크 0. 끝에서 끝 단언 `nlink_one_after_rounds`(Task 5) |
| 배포 링크 락이 writer 두 링크를 집는지 | 계획 예상: qg 링크 삭제는 못 잡는다 → `links_derived` 단언을 더하고 Task 1 Step 5 가 변이로 실측한다 |
| `seed_edit_diff.py` · `docreview_state.py` 의 import | 계획이 정함 — 앞은 import, 뒤는 몇 줄(복사 트리 넷 · 제자리 덮어쓰기) |
| fb810950#r1.1 README 한계 문장 | 설계가 (가)로 고쳤다 — Task 11 이 그 문장을 싣고 단언한다 |
| 7b7d0951#r1.1 링크 세트 락 인용 | 설계가 `test_copy_of_contract.sh` + writer 테스트 단언으로 바꿨다 — Task 1 `links_derived` |
| 7dd35c85#r1.1 Non-goals 뜻 | 계획이 정함 — 범위는 §1 표 일곱 항목. qg 쪽은 writer 링크 · 러너 세 자리 · 판 · CHANGELOG · README 뿐 |
| 0459cd4a#r2.1 R8 받는 곳 | 설계가 (가) — 지휘자가 로드맵 PR 로 싣는다. Task 12 Step 3 이 실렸는지 확인한다 |
| 55f10ebb#r2.1 「같은 글자」 뜻 | `state-root-for` 하위 명령으로 풀렸다 — 락은 맨 `state-root` 부재 + 첫 인자가 그 펜스의 문서 변수(Task 6 `root_lock`) |
| fccf272b#r2.1 빼는 함수 둘 | 둘 다 이름으로 빼고, 첫 writer 쓰기보다 뒤에서만 불리는지를 순서로 잰다(Task 2) |
| 89828d81#r3.1 복구 길 | finishing Step A.5 되묻기 갈래 + 끝에서 끝 `rebuild_once_and_idempotent`(Task 7) |
| 2744ebce#r3.2 다시 짓기 멱등 | 다시 도는 걸음은 Step A 3 · 4 · 7 · 8 · A.5, 다시 짓기는 통째로 다시 쓰기 — 문면 + 두 번 돌려 바이트 같음(Task 7) |
| 4482cebd#r4.1 외부 선례 되묻기 | brief §4 `@S` 만 바꾸고 마지막 포화 줄 유지 — `rebuild_irrelevant_keeps_last_saturation`(Task 7) |
| b8cf84d7#r4.1 결정 줄 펜스의 `cd` 순서 | `state-root-for` 를 `cd` 앞에서 부른다 — `e2e_outside_git` 와 그 변이(Task 6) |
| 9986768a#r4.1 R8 로 넘기는 Write 도구 파일 | 설계 미룸 표가 고쳤다 — Task 11 README 한계에 같은 목록 |
| a86f8ade#r4.1 `payload-root` 재사용 | `payload_root()` 함수를 두 하위 명령이 함께 쓴다(Task 4) |
