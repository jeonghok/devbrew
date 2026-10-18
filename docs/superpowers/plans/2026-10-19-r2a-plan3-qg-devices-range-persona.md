# R2a 계획 3 — qg 장치 · 범위 입력 · persona Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** qg 에 범위 입력(`range <시작>[..<끝>]`)과 여러 설계문서 의도를 더하고, 「문서 경로」를 한 자리에서 정의하고, §1 처분표의 qg 장치 열한 행(리뷰어 상한 · 재호출 금지 · 수정 루프 상한 · 낮춘 지적 · 「바뀐 코드만」 · 문서 경로 · 모델 고정 · 문서 비평 · e2e · trivia · 조사용 실행)을 제거하거나 고치고, persona 편집을 보안 리뷰에 올린다.

**Architecture:** 범위는 실행 시작에 새 스크립트 `resolve-range.sh` 가 커밋 둘로 얼려 세션 폴더의 `range-scope.txt` 에 두고, 그 뒤 모든 소비자(리뷰 diff · 설계문서 읽기 · 테스트 후보 · 차등 두 축 · 판정 줄 커밋)가 그 파일만 읽는다 — 공유본 `shared/test-selection/` 은 고치지 않는다(후보 스크립트의 `--topic <경계> <트리>` 가 이미 일반 쌍을 받는다). 리뷰어에게 주는 diff 는 새 `review-diff.sh` 가 모든 범위 모드에서 한 자리에서 만들고, 문서 경로 규칙은 새 `doc_paths.py` 하나가 갖는다. 나머지 장치는 SKILL · reference · persona 문면과 합성기(`synthesize_findings.py`)의 「낮춘 지적」 절로 고친다.

**Tech Stack:** bash 3.2 호환 셸 · Python 3.9(시스템 `python3`, 표준 라이브러리 + PyYAML) · git(`--end-of-options` 는 2.24 이상) · 레포 셸 테스트 하네스(`shared/tests/assert.sh`) · unittest.

**Spec:** `docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` (§4 · AC21~AC30 · 공통 AC36 · AC37 · `## 미룸` 의 계획 3 몫). ★계획 2 가 머지되기 전에는 최신 문면이 계획 2 브랜치에 있다 — `git show feature/shared-review-engine-core:docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` 로 읽는다.

## Global Constraints

- 브랜치는 `feature/shared-review-engine-qg`(origin 기본 브랜치에서 갈라졌다). HEAD 를 뒤로 옮기지 않는다. 커밋은 pathspec 으로(`git commit -- <경로…>`). push · stash 금지(지휘자가 한다). 다른 worktree 의 git 을 조작하지 않는다.
- 커밋 메시지: Conventional Commits, `type(scope)` 영어 · 설명과 본문 한국어. 끝에 `Co-Authored-By` · `Claude-Session` 두 줄(세션이 주는 값 그대로).
- **경계 — 이 계획은 `plugins/quality-gates/` 안만 고친다.** `shared/`(`test-selection` · `docreview` · `entry` · `tests`) · `plugins/spec-distill/` · 설계문서는 고치지 않는다 — 계획 2(`shared/docreview/` · spec-distill 엔진 사본 · 보안 잔여 스크립트)와 R5(공유본 소비자)와 겹치지 않게 하려는 것이다. 어느 Step 이 그 밖을 고쳐야 할 것 같으면 멈추고 지휘자에게 알린다.
- **계획 2 와 겹치는 파일은 셋뿐이다** — `plugins/quality-gates/.claude-plugin/plugin.json` · `CHANGELOG.md`(계획 2 가 qg patch bump 를 싣는다)와 계획 2 가 더하는 링크 `plugins/quality-gates/scripts/docreview_config.py`(이 계획은 건드리지 않는다). 버전 · CHANGELOG 충돌은 머지하는 쪽이 푼다. 각 Task 끝에 `git fetch origin` 뒤 `git merge-tree --write-tree HEAD origin/HEAD` 로 충돌을 미리 본다(rebase 금지 — merge).
- **설계문서 편집은 계획 2 머지 뒤에만** — origin 기본 브랜치를 merge 한 다음 §1 에 행을 더한다. 그 전에 새로 찾은 장치는 `$HOME/.claude/sdd-mirror/r2a-plan3/new-devices.md` 에 적는다(AC37).
- 플러그인 버전: quality-gates 는 minor(새 표면 — 범위 인자 · 환경 변수 · 지적만 받기 모드). **번호는 머지 직전에 지휘자가 정한다** — 이 계획 안에서는 지금 버전(14.0.0)에서 도출한 임시 번호 14.1.0 을 쓰고 인계에 「번호는 머지 직전에 다시 확인」을 적는다.
- 새 셸 테스트는 실행 비트 100755(`chmod +x` 후 `git ls-files -s` 로 확인 — qg 셸 어댑터는 100644 를 맡지 않는다). 스크립트의 파일 읽기는 `encoding="utf-8"` 명시. 플러그인 `.py` 에 `"python3"` 리터럴을 박지 않는다. 인라인 python 은 `python3 -I`(스크립트 파일 호출에는 `-I` 금지). 3.10 이상 문법(`match` · `X | Y` 타입 · `zip(strict=)`)을 쓰지 않는다. 긴 한글 줄은 인접 문자열로 나눈다.
- bash 3.2: `$var` 뒤에 한글 글자가 붙으면 `${var}` 로 쓴다. `$( )` 안 heredoc 금지. Bash 도구 셸은 zsh 다 — `PIPESTATUS` 를 쓰는 검증은 `bash -c` 안에서.
- `SKILL.md` 펜스에 `$` 뒤 숫자(위치 토큰)를 쓰지 않는다(Skill 인자로 치환된다) — 이름 있는 변수로. 펜스마다 플러그인 루트를 그 펜스 안에서 대입한다(`QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || …` — 기존 펜스 첫 줄을 그대로 복사).
- 레포 전용 값을 박지 않는다 — 기본 브랜치 이름(`main` 등) · 절대 경로 · devbrew 경로를 코드와 테스트에 넣지 않는다. 새 테스트의 픽스처 레포는 기본 브랜치를 `trunk` 로 만든다(`git init -q -b trunk`). 레포 루트는 `$(cd "$(dirname "$0")/../../.." && pwd)` 로 도출한다.
- 사용자에게 보이는 새 문면(공시 줄 · 질문 · 선택지 · README · CHANGELOG)은 `shared/style/plain-language.md` 규칙: 첫 줄 상태, 번호 · 내부 기호 · 필드 이름은 괄호 안, 선택지 이름은 짧은 쉬운 말, 추천은 「(권장)」.
- **persona 는 보안-민감 코드다** — `agents/*.md` · `references/review-criteria.md` 편집은 Task 14 가 qg 보안 리뷰어(웹 도구 없음)로 따로 리뷰해 PR 본문 「보안 리뷰」 절에 싣는다. `tools:` allowlist 와 security-reviewer 의 웹 금지 문장은 바꾸지 않는다.
- **락을 의도적으로 뒤집을 때** — 그 단언이 지키던 것을 커밋 본문에 적고, 새 단언에 변이 증거(고침을 되돌린 사본에서 RED)와 양성 짝(창이 비지 않았다는 단언)을 둔다. 락 · persona 수정은 그 Task 리뷰에서 다시 본다.
- 하위 agent 의 임시 폴더는 `TMPDIR=$HOME/.claude/sdd-mirror/r2a-plan3/tmp` 이고 그 안에서도 자기 하위 폴더만 쓴다. 공유 임시 폴더를 glob 으로 지우지 않는다. 테스트는 자기 `mktemp -d` 안에서만 쓴다.

## 설계와 다른 점 · 설계에 없던 결정

설계가 정하지 않았거나 레포 사실과 부딪혀 이 계획이 정한 것이다. 실행 전에 사용자 확인을 받는다(재결정 규약 — 근거를 대고 사용자가 정한다). 각 항목의 「계획의 선택」대로 Task 가 쓰여 있다.

1. **공유본 `resolve-baseline.sh` 를 고치지 않는다.** 설계 Files to Modify 는 계획 3 에 `scripts/resolve-baseline.sh`(범위 기준)를 적었지만, 계획 1 이 그 파일을 `shared/test-selection/` 으로 옮겼고 spec-distill(R5)이 링크로 쓴다. 범위 모드에 필요한 것은 merge-base 가 아니라 시작 커밋과 끝 커밋 둘이고, 후보 스크립트는 `--topic <경계> <트리>` 로 이미 일반 쌍을 받는다(`shared/test-selection/compute-test-scope-candidates.sh:45-50`). 계획의 선택: 새 qg 스크립트 `resolve-range.sh` 가 범위를 풀고, 공유본은 그대로 둔다(spec-distill bump · R5 스위트 영향 없음). 다른 길: `resolve-baseline.sh` 에 `--range` 를 더한다 — 공유본 변경이라 spec-distill bump 와 R5 소비자 스위트가 따라온다.
2. **끝을 생략하면 `origin/HEAD` 만 쓴다.** `origin/HEAD` 가 없거나 가리키는 ref 가 없으면 `main` · `master` 로 대신하지 않고 멈추며, 고치는 길(`git remote set-head origin --auto` 또는 끝을 적기)을 알린다. 다른 길: `resolve-baseline.sh` 의 대체 순서(origin/main → origin/master → …)를 따른다 — 레포 전용 이름에 기댄다.
3. **범위는 실행 시작에 커밋 둘로 얼리고, 범위 모드에서는 「고치고 다시 돌기」와 e2e 를 내지 않는다.** 참고 fa444e32(끝 커밋을 모든 소비자가 같이 쓴다)를 「실행 동안 바뀌지 않는 두 커밋」으로 닫는다. 범위는 이미 있는 커밋이고 지금 체크아웃과 다를 수 있어, 고침을 지금 작업 트리에 적용하면 리뷰한 대상과 고친 대상이 갈린다 — R5 걸음 7 도 「지적은 후속 PR 하나로」다(`plugins/spec-distill/references/conducting.md:65`). 그래서 범위 모드의 결정 게이트는 「지금 판정으로 끝내기 · 멈추기」 둘이고, e2e 칸은 사유 공시와 함께 `안 함` 이다. 다른 길: 지금 체크아웃이 끝 커밋과 같을 때만 고침 · e2e 를 허용하고, 고친 뒤의 끝을 봉인 커밋으로 바꿔 모든 소비자에 배선한다.
4. **범위를 풀지 못하면 판정 없이 멈춘다** — 시작 · 끝을 못 풂 · 시작이 끝의 조상이 아님 · 빈 범위 · 모양 밖(`-` 로 시작 · `...`). 없어진 인자처럼 한 줄을 내고 실행하지 않는다. 다른 길: `not-certified` 판정을 낸다 — 판정 사유 어휘(`verdict.REASONS`)에 새 값이 필요하다.
5. **여러 설계문서의 순서 · 형식.** 커밋 순서(오래된 것 먼저)로 모으고, 같은 경로는 한 번, 한 커밋의 `Spec:` 줄이 여럿이면 전부 받는다. 문서가 하나면 의도 파일은 지금과 바이트가 같고, 둘 이상이면 문서마다 구분 줄 `<!-- qg-spec <k>/<N>: <경로> -->` 를 둔다. 범위 모드에서 설계문서는 끝 커밋의 트리에서 읽고 PR 본문은 읽지 않는다(열린 PR 이 없는 범위). 리뷰어가 「어느 설계의 어느 AC」를 다는 자리는 finding 스키마가 아니라 `references/review-criteria.md` 의 한 줄(설계문서가 여럿이면 막는 지적의 summary 끝 괄호에 근거 문서 경로와 AC 번호)이다 — 스키마 · 합성기는 그대로. codex 러너는 `--range` 를 받아 `discover-spec.sh` 에 넘긴다(러너가 의도를 스스로 정하는 지금 원칙 유지).
6. **문서 경로 규칙의 주인과 읽는 자리.** AC23 의 「한 곳」을 이렇게 읽는다 — 규칙(기본 목록 · 환경 변수 · 보호 규칙 · 포함 우선)은 새 `doc_paths.py` 하나에 있고, 그것을 부르는 자리는 SKILL Step 1 의 새 `review-diff.sh` 펜스 하나다(모든 범위 모드 — 참고 d83a790c). 패턴 문법: `/` 가 없는 패턴은 어느 깊이의 파일 이름에나 맞고, `/` 가 있는 패턴은 레포 루트 기준 경로에 맞는다(`**` 는 여러 마디). **포함 규칙이 먼저다(참고 c7ea8a5f)** — 문서 확장자(`.md` · `.markdown` · `.mdx` · `.rst` · `.txt` · `.adoc`, 또는 확장자 없는 `README` · `CHANGELOG`)인 파일만 뺄 수 있고, 그중 이름이 `CLAUDE.md` · `AGENTS.md` · `SKILL.md` 이거나 경로 마디에 `agents` · `skills` · `commands` · `references` · `templates` · `hooks` · `.claude` · `.claude-plugin` 이 든 파일은 모델이 읽는 파일로 남긴다. 패턴에 걸렸지만 남긴 파일은 이름으로 공시한다. 다른 길(설계 문면): 패턴이 이기고, 뺀 비문서 파일(모델이 읽는 `.md` · 코드)을 이름으로 공시한다.
7. **걸러진 diff 가 비면** 리뷰어 · 차등 테스트 · e2e 를 부르지 않고 기존 사유 `not-certified (scope-empty)`(「대조할 대상이 0 인데 변경은 있다」)로 끝낸다. 다른 길: 새 사유 `docs-only` 를 판정 어휘에 더한다.
8. **`--paths` 범위는 「바뀐 파일 ∩ glob」이다.** 지금은 모델이 「glob 이 가리키는 것」을 풀어 바뀌지 않은 파일까지 셀 수 있었다. `review-diff.sh` 가 git pathspec 으로 정한다.
9. **수정 루프 상한에서 여는 승인은 엔진 B11 꼴이다** — 「한 번 더 돌기」 선택지 이름이나 기타 칸 원문을 받고 출처(`label` · `typed`)와 함께 기록한다. AC25 의 「자기 문구로」를 B11(2026-10-18) 이후 엔진 꼴로 읽는다(설계 §1 「엔진과 같은 꼴」). 다른 길: 기타 칸 원문만 승인으로 받는다(B11 이전 엔진 꼴).
10. **되올리기 흐름.** 합성기가 낮춘 지적마다 번호 `L<k>` · 원래 심각도 · 낮춘 이유를 싣고(`## 낮춘 지적` 절 · `lowered: N` 줄), SKILL Step 4.5 가 낮춘 지적이 있으면 반복마다(판정이 clean 이어도) multiSelect 게이트를 띄운다. 고른 것은 합성기를 `--restore-lowered L1,L3` 로 다시 돌려 원래 심각도로 판정에 넣는다.
11. **e2e 여러 선택** — 고른 시나리오를 번호 순으로 하나씩 걷고 걷기마다 게이트를 띄운다. e2e 칸은 가장 나쁜 결과(`fail` > `미확인` > `pass`)다. 「안 한다」 · 「걸을 것 없음」을 시나리오와 함께 고르면 시나리오만 걷는다.
12. **리뷰어 재시도 · 분할 · 추가.** 일시 실패 1회 재시도는 모든 리뷰어(보안 포함)에 적용하고, 두 번째도 실패하면 지금 규칙(보안은 fail-closed, 외부는 「실패」 표시)대로다. 시작 줄은 dispatch 전에, 끝 줄은 Step 3 의 dispatch 가 모두 돌아온 뒤에 찍는다(AC24 「반복이 끝날 때」를 리뷰 단계의 끝으로 읽는다).
13. **artifact-critique 의 「dispatch 수」는 라운드당 비평자(critic) 수다** — 기본 1, 동의 게이트에서 사용자가 정한다. 반박자 1 · codex 조건부는 그대로. 「지적만 받기」는 한 라운드만 돌고 편집 · 커밋을 하지 않으며, 브랜치 · clean 전제 대신 경로 인가(E2c)만 요구한다. 고치며 돌기 모드에서 브랜치 · clean 전제(E2 · E2b)가 멈추면 「지적만 받기로 진행」을 선택지로 준다.
14. **받는 계획이 정해지지 않은 R2a 미룸 두 행은 이 계획에 넣지 않는다** — `test_copy_of_contract` 도출 오탐(설계 `## 미룸` 의 `shared/tests/test_copy_of_contract.sh` 행)과 호출 표면 락 빈틈(`_LEAD` · 살아 있는 표면 행). 둘 다 `shared/tests` 를 고치므로 계획 2 · R5 와 겹친다. R2a 끝 확인 때 지휘자가 받는 곳을 정한다. 미룸의 라우터 행은 계획 2 몫이다.

참고(`### Deferred to plan`) 중 이 계획이 닿는 것: fa444e32(위 3) · c7ea8a5f(위 6) · d83a790c(위 6 · Task 5) · 11ed67a1(`..<끝>` 은 AC21 이 요구하므로 남긴다 — 끝을 생략한 꼴이 R5 계약이다).

## Review Focus

1. **사용자가 `range -x` · `range A...B` · `range ..B` 를 준다.** git 옵션으로 읽히지 않고, 실행이 「범위 모양 밖」 한 줄로 멈춘다. Task 2 `case_bad_spec` 이 잠근다.
2. **`origin/HEAD` 가 없는 클론(`git remote set-head origin -d` 뒤)에서 `range <시작>` 을 준다.** `main` 으로 몰래 대신하지 않고, 고치는 길을 알리며 멈춘다. Task 2 `case_no_origin_head` 가 잠근다.
3. **실행 도중 기본 브랜치가 움직인다(다른 세션의 fetch).** 모든 반복이 실행 시작에 얼린 끝 커밋을 쓰고, HEAD 축을 다른 커밋으로 세우려 하면 거부된다. Task 2 `case_frozen_end_survives_fetch` 가 잠근다.
4. **`DEVBREW_QUALITY_GATES_DOC_PATHS` 가 설정됐지만 비었거나(`""` · `" , "`) 읽을 수 없는 패턴(`:(exclude)x`)을 담는다.** 비었으면 아무것도 빼지 않고, 읽을 수 없는 패턴은 적용하지 않고 이름으로 공시한다. Task 4 `test_env_set_empty_excludes_nothing` · `test_bad_pattern_disclosed` 가 잠근다.
5. **범위 끝 커밋에는 설계문서가 있는데 지금 체크아웃에는 없다(시작 커밋을 체크아웃한 상태).** 설계문서를 끝 커밋 트리에서 읽어 의도에 싣는다. Task 3 `case_range_reads_spec_from_end_tree` 가 잠근다.

## §1 처분표 닫힘 (AC37 — 이 계획 몫)

| §1 행 | AC | Task |
|---|---|---|
| qg 리뷰어 최대 8, 기계 신호로만 | AC24 | 7 |
| qg 수정 루프 5회 「예외 없음」 | AC25 | 8 |
| 같은 반복에 같은 리뷰어 다시 부르기 금지 | AC24 | 7 |
| 재비판 lower | AC26 | 9 |
| 「바뀐 코드만」 | AC27 | 10 |
| 정의 없는 「문서 경로」 제외 | AC23 | 4 · 5 |
| 리뷰어 모델 opus 고정 둘 | AC27 | 10 |
| 문서 비평 기본 5라운드 · 대상 하나 · 커밋 강제 · dispatch 수 고정 | AC29 | 12 |
| e2e 시나리오 단일 선택 | AC28 | 11 |
| 토픽 선언이면 trivia 우회 불가 | AC28 | 11 |
| 차등 테스트 밖 스위트 실행 금지 | AC28 | 11 |
| 미룸 — `setup-qg.sh` 의 `critique` 안내 모서리 | AC21 | 1 |
| 미룸 — artifact-critique 문면(옛 모드 이름 · 「그 파일로 고정」 · 음성 검사) | AC29 | 12 |
| 미룸 — `test_qg_critique_routing.sh` 의 P1b · P2 순서 | — | 1 |

---

### Task 0: 기준선과 겹침을 잰다 (AC36)

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r2a-plan3/baseline.sh` (레포 밖 — git 이 추적하지 않는다)
- Create: `$HOME/.claude/sdd-mirror/r2a-plan3/new-devices.md` (레포 밖)

- [ ] **Step 1: 기준 스위트 스크립트를 쓴다**

`$HOME/.claude/sdd-mirror/r2a-plan3/baseline.sh`:

````bash
#!/usr/bin/env bash
# 스위트 전체를 돌려 테스트별 rc · 실패 줄 수와 실패 줄 이름을 남긴다. 리포 루트에서: bash baseline.sh <출력 접두>
set -u
out="$1"; : > "$out.tsv"; : > "$out.names"
export TMPDIR="$HOME/.claude/sdd-mirror/r2a-plan3/tmp/suite"; mkdir -p "$TMPDIR"
run_capped() { perl -e 'alarm shift; exec @ARGV' 900 "$@"; }
for t in plugins/*/tests/test_*.sh plugins/*/tests/*/test_*.sh shared/tests/test_*.sh; do
  [ -f "$t" ] || continue
  log="$(PYTHONDONTWRITEBYTECODE=1 run_capped bash "$t" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '✗|^FAIL|^not ok' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out.tsv"
  printf '%s\n' "$log" | grep -E '✗|^FAIL|^not ok' | awk -v t="$t" '{print t "\t" $0}' >> "$out.names"
done
for t in plugins/*/tests/test_*.py; do
  log="$(cd "$(dirname "$t")" && PYTHONDONTWRITEBYTECODE=1 run_capped python3 -m unittest -q "$(basename "$t" .py)" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '^(FAIL|ERROR):' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out.tsv"
  printf '%s\n' "$log" | grep -E '^(FAIL|ERROR):' | awk -v t="$t" '{print t "\t" $0}' >> "$out.names"
done
````

- [ ] **Step 2: 기준을 잰다(오래 걸린다 — 백그라운드로, 다른 스위트와 동시에 돌리지 않는다)**

Run (리포 루트에서): `bash "$HOME/.claude/sdd-mirror/r2a-plan3/baseline.sh" "$HOME/.claude/sdd-mirror/r2a-plan3/before"`
Expected: `before.tsv` 에 테스트마다 한 줄, `before.names` 에 실패 줄. 기준 커밋(`git rev-parse HEAD`)을 `before.base` 에 적는다. 비교는 rc 가 아니라 실패 줄 «이름» 집합으로 한다.

- [ ] **Step 3: 계획 2 와의 겹침을 적는다**

Run: `git fetch origin && git diff --name-only origin/HEAD...feature/shared-review-engine-core | grep '^plugins/quality-gates/' > "$HOME/.claude/sdd-mirror/r2a-plan3/overlap-plan2.txt"; cat "$HOME/.claude/sdd-mirror/r2a-plan3/overlap-plan2.txt"`
Expected: `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/scripts/docreview_config.py` 만(그 밖이 나오면 지휘자에게 알리고 그 파일을 고치는 Task 를 「계획 2 머지 뒤」로 미룬다).

- [ ] **Step 4: 새 장치 목록 파일을 만든다**

`new-devices.md` 첫 줄에 `# R2a 계획 3 — 구현 중 새로 찾은 장치(§1 후보)` 와 칸 머리 `| 장치 | 자리 | 지키던 것 | 처분 제안 |` 를 쓴다. 구현 중 찾은 장치는 여기에 한 줄씩 더한다(Task 15 가 옮긴다).

---

### Task 1: setup 이 범위 인자를 받고 문서 비평 안내 모서리를 닫는다 (AC21 · 미룸)

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh:8-15` (kill switch 앞 첫 인자 검사 삭제), `:33-121` (인자 루프 — `range` · `critique` 위치 무관 · 범위 인자 하나만), `:93-113` (`--help`)
- Test: `plugins/quality-gates/tests/test_setup_qg.sh` (케이스 추가), `plugins/quality-gates/tests/test_qg_critique_routing.sh` (모서리 · 순서 락)

**Interfaces:**
- Produces: `setup-qg.sh [--ensure] [branch | --paths <glob>... | range <spec>] [--session-id <id>]` — `range` 는 뒤 낱말 하나를 소비한다(검증은 모양만 — 커밋 해석은 Task 2). 종료 코드: 1 사용 오류(값 없음 · 값이 `-` 로 시작 · 범위 인자 둘 이상) · 2 없어진 인자 · `critique`. kill switch(`DEVBREW_QUALITY_GATES_DISABLE=1`)는 모든 인자 처리보다 먼저다(rc 1).
- 바뀌지 않음: `--ensure` · `--session-id` · v9/v10 인자 처리 · 세션 폴더 규칙.

- [ ] **Step 1: 실패하는 케이스를 쓴다**

`test_setup_qg.sh` 끝(`finish` 앞)에 — 기존 `assert <label> <cmd>` 도우미와 같은 꼴:

```bash
# --- AC21: range 인자 ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"; git init -q -b trunk; unset CLAUDE_CODE_SESSION_ID
out="$("$SCRIPT" --session-id "test-range-$$" range abc123 2>&1)"; rc=$?
assert "range <값>: rc 0" "[ $rc = 0 ]"
assert "range <값>: 모르는 인자로 읽지 않는다" "! printf '%s' \"\$out\" | grep -q '모르는 인자'"
out="$("$SCRIPT" --session-id "test-range-$$" range 2>&1)"; rc=$?
assert "range 값 없음: rc 1" "[ $rc = 1 ]"
assert "range 값 없음: 이유 한 줄" "printf '%s' \"\$out\" | grep -q 'range 뒤에 시작 커밋이 없다'"
out="$("$SCRIPT" --session-id "test-range-$$" range --gc 2>&1)"; rc=$?
assert "range 값이 - 로 시작: rc 1" "[ $rc = 1 ]"
assert "range 값이 - 로 시작: 이유" "printf '%s' \"\$out\" | grep -q 'range 의 값이 - 로 시작한다'"
for combo in "branch range x" "--paths a/* range x" "range x branch"; do
  out="$("$SCRIPT" --session-id "test-range-$$" $combo 2>&1)"; rc=$?
  assert "범위 인자 둘($combo): rc 1" "[ $rc = 1 ]"
  assert "범위 인자 둘($combo): 이유" "printf '%s' \"\$out\" | grep -q '범위 인자는 하나만'"
done
h="$("$SCRIPT" --help)"
assert "--help 가 range 를 안내한다" "printf '%s' \"\$h\" | grep -qF 'range <시작>[..<끝>]'"
assert "--help 가 critique 를 없어진 인자로 안내한다" "printf '%s' \"\$h\" | grep -q 'critique'"
cd / && rm -rf "$TMPDIR"
```

`test_qg_critique_routing.sh` 에 — 위치 무관 · kill switch 먼저 · P1b 가 P2 앞:

```bash
for args in "branch critique" "--paths critique" "--paths a/* critique" "range critique" "--ensure critique"; do
  out="$(cd "$T" && bash "$SETUP" --session-id "crit-$$-x1" $args 2>&1)"; rc=$?
  assert_eq "$rc" "2" "critique 위치 무관($args): exit 2"
  assert_contains "$out" "/quality-gates:artifact-critique" "critique 위치 무관($args): 새 이름 안내"
done
out="$(cd "$T" && DEVBREW_QUALITY_GATES_DISABLE=1 bash "$SETUP" critique 2>&1)"; rc=$?
assert_eq "$rc" "1" "kill switch 가 critique 안내보다 먼저다(첫 인자)"
out="$(cd "$T" && DEVBREW_QUALITY_GATES_DISABLE=1 bash "$SETUP" --ensure critique 2>&1)"; rc2=$?
assert_eq "$rc2" "$rc" "kill switch 결과는 critique 위치와 무관하다"
p1b=$(grep -n '^\*\*P1b — ' "$SK" | cut -d: -f1); p2=$(grep -n '^\*\*P2 — ' "$SK" | cut -d: -f1)
assert_grep "$p1b" '^[0-9]+$' "P1b 줄을 찾았다(양성 짝)"
[ "$p1b" -lt "$p2" ] && ok "P1b 가 P2 보다 앞이다" || no "P1b 가 P2 보다 뒤다 — 문서 비평 요청이 setup 을 먼저 돌린다"
```

(`$T` · `$SETUP` · `$SK` 는 그 파일의 기존 변수 이름으로 맞춘다 — 없으면 같은 뜻으로 정의한다.)

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/quality-gates/tests/test_setup_qg.sh; bash plugins/quality-gates/tests/test_qg_critique_routing.sh`
Expected: range 케이스 · `branch critique` · `--paths critique` · `range critique` · kill switch 일관 케이스가 ✗.

- [ ] **Step 3: `setup-qg.sh` 를 고친다**

kill switch 앞의 첫 인자 검사(`:13-15`)를 지운다(kill switch 가 먼저). 루프에서: `range)` 는 다음 낱말을 소비하고(없으면 `❌ range 뒤에 시작 커밋이 없다(range requires <시작>[..<끝>]).` rc 1, `-` 로 시작하면 `❌ range 의 값이 - 로 시작한다 — 커밋 이름이 아니다.` rc 1, 값이 `critique` 면 `critique_notice`) 범위 인자 수를 센다. `branch)` 뒤 낱말이 `critique` 면 `critique_notice`, `range` 면 브랜치 이름으로 먹지 않는다(`:54` 의 정규식 끝말 목록에 `range` 를 더한다 — 안 그러면 `branch range x` 가 v9 의 `branch <name>` 으로 읽혀 「없어진 인자」가 된다). `--paths` 의 glob 루프는 `critique` 를 만나면 `critique_notice`, `range` 를 만나면 멈춘다(두 정규식의 끝말 목록에 `range` 를 더한다). 루프 뒤 범위 인자(`branch` · `--paths` · `range`)가 둘 이상이면 `❌ 범위 인자는 하나만 준다(branch · --paths · range 중 하나).` rc 1. `--help` 의 USAGE 에 `range <시작>[..<끝>]` 줄(「Review the commits from <시작> to <끝>; <끝> defaults to origin/HEAD」)과 REMOVED 줄에 `critique (→ /quality-gates:artifact-critique)` 를 더한다.

- [ ] **Step 4: 통과를 본다**

Run: Step 2 와 같다. Expected: 두 파일 모두 실패 0. 변이 확인 — P1b 문단을 P2 뒤로 옮긴 임시 사본을 `$SK` 로 가리켜 순서 단언만 돌리면 ✗(복원 후 `git diff HEAD -- plugins/quality-gates/skills` 가 빈 것을 확인).

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/tests/test_setup_qg.sh plugins/quality-gates/tests/test_qg_critique_routing.sh
git commit -m "feat(qg): setup 이 range 인자를 받고 critique 안내를 위치와 무관하게" -- plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/tests/test_setup_qg.sh plugins/quality-gates/tests/test_qg_critique_routing.sh
```

---

### Task 2: 범위를 커밋 둘로 얼린다 — `resolve-range.sh` · `create-head --range` (AC21)

**Files:**
- Create: `plugins/quality-gates/scripts/resolve-range.sh` (100755)
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh:1-20` (머리 설명), `:85-121` (`create-head` 의 `--range` 갈래)
- Create: `plugins/quality-gates/tests/test_resolve_range.sh` (100755)

**Interfaces:**
- Produces: `resolve-range.sh --out <file> [--] <setup 과 같은 인자 낱말들…>`
  - 낱말 중 `range` 가 없으면 `<file>` 이 있으면 지우고 stdout `range: none`, rc 0.
  - 있으면 그 다음 낱말을 `<spec>` 으로 풀어 `<file>` 에 아래 11줄(이 순서, 전부)을 쓰고 같은 내용을 stdout 에 낸다. `status: ok` 면 rc 0, 그 밖이면 rc 3. `--out` 없음 · `range` 뒤 값 없음은 rc 2.
  ```text
  mode: range
  status: ok|bad-spec|start-unresolved|end-unresolved|not-ancestor|empty
  reason: <한 줄 쉬운 말 | ->
  spec: <받은 값 그대로>
  start: <전체 커밋 id | ->
  end: <전체 커밋 id | ->
  end_from: given|origin/HEAD|-
  end_ref: <refs/remotes/origin/… | ->
  commits: <start..end 커밋 수 | ->
  files: <start..end 바뀐 파일 수 | ->
  head_is_end: yes|no|-
  ```
- Produces: `qg-worktree.sh create-head <end-sha> <session-id> --range <range-scope 파일>` — 파일의 `status: ok` · `start` ≠ `end` · `<end-sha>` 를 커밋으로 푼 값이 파일의 `end:` 와 같을 때만 그 커밋에 detached 트리를 만든다. 아니면 `qg-worktree: range end mismatch …` 또는 `qg-worktree: range scope not ok …` 로 rc 2. 기존 두 갈래(봉인 · `--topic`)는 그대로.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_resolve_range.sh` — 픽스처: 레포 A(`git init -q -b trunk`, 커밋 c0 → c1(코드) → c2 → c3)와 그 클론 R(`git clone -q A R` — `origin/HEAD` → `origin/trunk`), 곁가지 커밋 s1(c0 에서 갈라짐, R 에 fetch). 케이스 이름과 단언:

```bash
case_none()                    # resolve-range.sh --out F -- branch → stdout 'range: none', rc 0, F 없음(미리 만들어 둔 F 도 지워짐)
case_start_only_uses_origin_head()  # -- range <c1> → rc 0
  # field status = ok · start = c1 전체 id · end = c3 · end_from = origin/HEAD
  # end_ref = refs/remotes/origin/trunk · commits = 2 · files = $(git -C R diff --name-only c1 c3 | wc -l)
case_start_end_given()         # range <c1>..<c2> → end = c2 · end_from = given · end_ref = -
case_short_and_ref_names()     # range <c1 앞 7자>..origin/trunk → status ok, end = c3
case_bad_spec()                # 값마다 rc 3 · status bad-spec: '-x' 'c1...c3' '..c3' 'c1..'
case_unresolved_start()        # range 0123456789abcdef0123 → status start-unresolved
case_no_origin_head()          # git -C R remote set-head origin -d 뒤 range <c1>
  # status end-unresolved · reason 에 'git remote set-head origin --auto' 포함 · end = -
case_not_ancestor()            # range <s1> → status not-ancestor
case_empty()                   # range <c3> → status empty (start = end)
case_head_is_end()             # R 을 c1 에 detached → range <c1>..<c3> 의 head_is_end = no; c3 에 → yes
case_frozen_end_survives_fetch()
  # resolve → F. A 에 c4 를 더하고 R 에서 git fetch. F 의 end 는 여전히 c3.
  # qg-worktree.sh create-head <c3> sid12345 --range F → rc 0, 그 트리의 HEAD = c3
  # create-head <c4> sid12345 --range F → rc 2, stderr 'range end mismatch'
  # create-head <c1(=start)> sid12345 --range F → rc 2
  # status 를 empty 로 고친 F' 로 create-head <c3> → rc 2, stderr 'range scope not ok'
case_no_default_branch_literal()   # grep -nw 'main\|master' resolve-range.sh 가 0줄, 'origin/HEAD' 는 있다(양성 짝)
```

`field` 는 `sed -n "s/^$1: //p" "$F"` 로 읽는다. 끝에 `finish`.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `chmod +x plugins/quality-gates/tests/test_resolve_range.sh && bash plugins/quality-gates/tests/test_resolve_range.sh`
Expected: 스크립트가 없어 전부 ✗.

- [ ] **Step 3: `resolve-range.sh` 를 쓰고 `create-head --range` 를 더한다**

`resolve-range.sh`: `<spec>` 을 첫 `..` 에서 나눈다. `...` 를 담거나 시작이 비었거나 `..` 뒤가 비었거나 어느 쪽이든 `-` 로 시작하면 `bad-spec`. 커밋 해석은 `git rev-parse --verify --quiet --end-of-options "<x>^{commit}"` 만 쓴다. 끝이 없으면 `git symbolic-ref --quiet refs/remotes/origin/HEAD` 가 낸 ref 가 실재할 때만 쓰고, 아니면 `end-unresolved`(reason: `origin/HEAD 가 가리키는 기본 브랜치를 찾지 못했다 — git remote set-head origin --auto 를 돌리거나 끝 커밋을 적는다(range <시작>..<끝>)`). `git merge-base --is-ancestor` 가 거짓이면 `not-ancestor`, 시작 = 끝이거나 `git diff --quiet <start> <end>` 면 `empty`. 쓰기는 같은 폴더의 임시 파일에 쓴 뒤 `mv`(원자). 읽기 전용 git 만 쓴다. `create-head` 의 인자 해석에 `$# -eq 5 && "$4" == "--range"` 갈래를 더하고, 위 규칙으로 대조한 뒤 `make_detached_worktree "$2" "$3" head` 를 부른다. 머리 설명(`:13-19`)에 세 번째 갈래를 적는다.

- [ ] **Step 4: 통과를 본다**

Run: `bash plugins/quality-gates/tests/test_resolve_range.sh && bash plugins/quality-gates/tests/test_qg_worktree_helper.sh && bash plugins/quality-gates/tests/test_worktree.sh`
Expected: 실패 0. `git ls-files -s plugins/quality-gates/scripts/resolve-range.sh plugins/quality-gates/tests/test_resolve_range.sh` 의 모드가 100755.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/scripts/resolve-range.sh plugins/quality-gates/tests/test_resolve_range.sh
git commit -m "feat(qg): 범위를 시작 · 끝 커밋 둘로 얼리는 resolve-range 와 create-head --range" -- plugins/quality-gates/scripts/resolve-range.sh plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_resolve_range.sh
```

---

### Task 3: 범위 안 설계문서를 전부 의도로 읽는다 — `discover-spec.sh` (AC22 · AC21)

**Files:**
- Modify: `plugins/quality-gates/scripts/discover-spec.sh:1-17` (머리 설명), `:20-40` (인자 · 범위), `:42-45` (`emit` — `specs`), `:47-82` (트레일러 전부 · 범위 모드 읽기), `:84-112` (범위 모드는 gh 안 부름)
- Modify: `plugins/quality-gates/scripts/run_codex_reviewer.sh:15-30` (사용법), `:150-166` (`--range` 를 `discover-spec.sh` 에 넘김)
- Modify: `plugins/quality-gates/references/review-criteria.md` (한 줄 — persona 급, Task 14 리뷰)
- Test: `plugins/quality-gates/tests/test_discover_spec.sh`, `test_discover_spec_keys.sh`, 러너 인자 계약 테스트(`grep -ln 'discover-spec' plugins/quality-gates/tests/test_codex_*.sh` 로 찾은 파일)

**Interfaces:**
- Produces: `discover-spec.sh --intent-out <file> [--base <sha> | --range <start> <end>]` — `--base` 와 `--range` 를 함께 주면 rc 2.
- Produces: stdout JSON 에 키 `specs`(의도에 실은 설계문서의 리포 상대 경로 목록, 실은 순서) 가 늘 있다. 키 집합은 정확히 `intent_source` · `intent_note` · `intent_file` · `specs`. `intent_note` 에 새 값 `spec 경로 거부 <k>개` · `범위 모드 — PR 본문 안 읽음`.
- Produces: 의도 파일 — 설계문서가 하나면 그 내용 그대로(지금과 바이트 동일), 둘 이상이면 문서마다 `<!-- qg-spec <k>/<N>: <경로> -->` 줄 뒤 내용, 그 뒤 빈 줄.
- Produces: `run_codex_reviewer.sh <diff> <project_dir> <out> [--range <start> <end>]` — 받은 `--range` 를 그대로 `discover-spec.sh` 에 넘긴다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_discover_spec.sh` 의 케이스 1 단언 「앞 커밋의 트레일러가 가리킨 spec 은 의도 본문이 아니다」를 지우고(AC22 가 뒤집는다 — 주석 한 줄로 이유) 아래를 더한다:

```bash
spec_list() { python3 -I -c 'import json,sys; print(" ".join(json.loads(sys.stdin.read())["specs"]))'; }
# AC22 — 트레일러 둘은 둘 다, 커밋 순서(오래된 것 먼저)
out="$(run "$B:$PATH")"
assert_eq "$(printf '%s' "$out" | spec_list)" "docs/superpowers/specs/old-design.md docs/superpowers/specs/new-design.md" "specs: 두 설계문서를 커밋 순서로"
assert_file_grep "$T/intent.md" '^- old$' "의도에 앞 커밋의 설계문서도 실린다"
assert_file_grep "$T/intent.md" '^<!-- qg-spec 2/2: docs/superpowers/specs/new-design.md -->$' "둘 이상이면 문서마다 구분 줄"
# AC22 — 트레일러 하나면 지금과 같다(바이트 동일)
case_single_trailer_identical      # --base <첫 트레일러 커밋> → specs 하나, cmp "$T/intent.md" <(git show HEAD:…/new-design.md) 가 0, 'qg-spec' 줄 없음
case_duplicate_trailer_once        # 같은 경로를 가리키는 커밋 둘 → specs 길이 1
case_multiple_spec_lines_one_commit   # 한 커밋 메시지에 Spec: 줄 둘 → 둘 다
case_one_rejected_among_valid      # Spec: ../x.md 와 정상 하나 → specs 1 · intent_source spec-trailer · intent_note 'spec 경로 거부 1개'
case_range_reads_spec_from_end_tree   # R 을 시작 커밋에 체크아웃(설계문서 파일 없음) 뒤 --range <S> <E> → specs 1, 의도 = git show E:<경로>
case_range_symlink_spec_rejected   # 끝 트리에서 설계문서 경로가 심볼릭 링크(120000) → 그 트레일러 거부, intent_note 에 '거부'
case_range_no_gh_call              # 트레일러 없는 범위 + gh 스텁 → GH_LOG 비었음, intent_source commits, intent_note '범위 모드 — PR 본문 안 읽음'
case_base_and_range_exclusive      # --base X --range A B → rc 2
```

`test_discover_spec_keys.sh`: 키 집합 단언을 네 키(`specs` 포함)로 바꾼다. 러너 계약 테스트에: `PLUGIN_ROOT` 아래 `scripts/discover-spec.sh` 를 인자를 로그에 적는 스텁으로 둔 사본에서 `run_codex_reviewer.sh <diff> <dir> <out> --range AAA BBB` 를 부르면 스텁 로그에 `--range AAA BBB` 가 있다(러너가 플러그인 루트를 어떻게 정하는지 먼저 읽고 그 방식으로 스텁을 꽂는다. 진짜 codex 는 부르지 않는다 — 기존 러너 테스트가 쓰는 `tests/mocks/` 의 mock codex 를 PATH 앞에 둔다).

`review-criteria.md` 단언(같은 파일 또는 `test_recritic_code_profile.sh`): 「설계문서가 여럿이면」 문장이 있다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/quality-gates/tests/test_discover_spec.sh; bash plugins/quality-gates/tests/test_discover_spec_keys.sh`
Expected: 새 케이스들이 ✗.

- [ ] **Step 3: 고친다**

`discover-spec.sh`: 범위는 `--range` 면 `<start>..<end>`, 아니면 지금처럼. 트레일러는 `git log --reverse --format='%H'` 로 훑고 커밋마다 `^Spec: ` 줄 전부(`#` 뒤 제거)를 받는다. 트레일러마다 지금의 경로 검사(절대 · `..` · `.git`)를 하고, 범위 모드가 아니면 지금처럼 작업 트리 realpath 검사 뒤 `git show HEAD:<rel>`, 범위 모드면 `git ls-tree <end> -- <rel>` 의 모드가 `100644` · `100755` 인 blob 일 때만 `git show <end>:<rel>`(링크 · 없음은 거부). 거부는 세고 다음 트레일러로 간다(지금은 첫 거부에서 멈춘다). 같은 `rel` 은 처음 것만. 받은 것이 하나 이상이면 `spec-trailer`, 없으면 지금의 커밋 메시지 사슬 — 범위 모드에서는 gh 를 부르지 않는다. `emit` 은 `specs` 를 `json.dumps` 로 싣는다(인라인 python 은 `-I`). 러너: 넷째 · 다섯째 · 여섯째 인자가 `--range <a> <b>` 면 그대로 넘기고, 그 밖의 넷째 인자는 지금처럼 거부한다. `review-criteria.md` 끝에:

```text
의도 출처에 설계문서가 여럿이면(구분 줄 `<!-- qg-spec k/N: 경로 -->`), 막는 지적마다 summary 끝 괄호에 근거 문서의 경로와 AC 번호를 단다(예: `(docs/a-design.md AC3)`).
```

- [ ] **Step 4: 통과를 본다**

Run: Step 2 의 둘 + 러너 계약 테스트 + `bash plugins/quality-gates/tests/test_publish_gh_two_files.sh`(gh 는 두 파일만)
Expected: 실패 0.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(qg): 범위 안 Spec 트레일러를 전부 의도로 — specs 목록 · 범위 모드는 끝 커밋에서 읽음" -- plugins/quality-gates/scripts/discover-spec.sh plugins/quality-gates/scripts/run_codex_reviewer.sh plugins/quality-gates/references/review-criteria.md plugins/quality-gates/tests/test_discover_spec.sh plugins/quality-gates/tests/test_discover_spec_keys.sh <러너 계약 테스트 경로>
```

---

### Task 4: 문서 경로 규칙과 리뷰 diff — `doc_paths.py` · `review-diff.sh` (AC23)

**Files:**
- Create: `plugins/quality-gates/scripts/doc_paths.py`, `plugins/quality-gates/scripts/review-diff.sh` (100755)
- Create: `plugins/quality-gates/tests/test_doc_paths.py`, `plugins/quality-gates/tests/test_review_diff.sh` (100755)
- Create: `$HOME/.claude/sdd-mirror/r2a-plan3/settings-env-measure.md` (레포 밖 — 실측 기록)

**Interfaces:**
- Produces (`doc_paths.py`):
  - 상수 `ENV_KEY = "DEVBREW_QUALITY_GATES_DOC_PATHS"` · `DEFAULT_DOC_PATHS = ("README*", "CHANGELOG*")` · `DOC_EXTS = (".md", ".markdown", ".mdx", ".rst", ".txt", ".adoc")` · `MODEL_READ_NAMES = ("CLAUDE.md", "AGENTS.md", "SKILL.md")` · `MODEL_READ_SEGMENTS = ("agents", "skills", "commands", "references", "templates", "hooks", ".claude", ".claude-plugin")`.
  - `parse_patterns(raw: Optional[str]) -> Tuple[List[str], List[str], str]` — (적용할 패턴, 읽지 못한 패턴, 출처 `default`|`env`). `None` → 기본 목록 · `default`. 그 밖은 쉼표로 나눠 앞뒤 공백을 버리고 빈 항목을 버린다 — 모두 비면 `[]` · `env`. `:` · `!` 로 시작하거나 제어 문자를 담은 항목은 읽지 못한 패턴.
  - `pattern_regex(pat: str) -> Pattern[str]` — `**/` → `(?:[^/]+/)*`, 끝의 `/**` → `(?:/.*)?`, 그 밖의 `**` → `.*`, `*` → `[^/]*`, `?` → `[^/]`, `[...]`(`[!` → `[^`)은 문자 묶음, 나머지는 `re.escape`. 전체 일치.
  - `matches(pat: str, path: str) -> bool` — 패턴에 `/` 가 없으면 경로의 마지막 마디에, 있으면 경로 전체에 맞춘다.
  - `is_doc_file(path: str) -> bool` · `is_model_read(path: str) -> bool` (위 「설계에 없던 결정」 6 의 규칙).
  - `settings_key_changed(base_text: Optional[str], head_text: Optional[str]) -> bool` — 두 쪽 `.claude/settings.json` 글에서 `env.<ENV_KEY>` 의 있음 · 값이 다르면 참. 두 글이 같으면 거짓. 글이 다른데 한쪽이라도 JSON 으로 읽을 수 없으면 참(기본 목록으로 돌아가는 쪽).
  - `select(paths: List[str], patterns: List[str]) -> Tuple[List[str], List[str]]` — (뺀 경로, 패턴에 걸렸지만 남긴 경로). 뺀 경로 = 어느 패턴에 맞고 문서 파일이며 모델이 읽는 파일이 아닌 것.
  - CLI `doc_paths.py select --names <file> --settings-base <file> --settings-head <file>` — 설정 파일 인자는 없는 경로여도 된다(그쪽에 설정 없음). stdout:
    ```text
    doc_paths_source: default|env|default-settings-changed
    doc_paths: <쉼표 목록 | (없음)>
    bad_patterns: <쉼표 목록 | ->
    excluded: <N>
    kept_model: <M>
    exclude	<경로>        (뺀 경로마다, 탭)
    kept	<경로>           (남긴 경로마다, 탭)
    ```
    rc 0 · 사용 오류 2 · `--names` 를 못 읽음 4.
- Produces (`review-diff.sh`): `review-diff.sh --dir <dir> --iter <N> --mode session|branch|paths|topic|range [--globs <glob>...] [--scope-file <file>]` — `--scope-file` 은 topic 이면 `topic-scope.txt`(`boundary:` · `tree:`), range 면 `range-scope.txt`(`start:` · `end:`). 쓰는 파일: `<dir>/review-i<N>.names`(거르기 전 경로 전부) · `review-i<N>.full.diff`(거르기 전) · `review-i<N>.diff`(걸러진 diff = 리뷰어가 받는 것) · `review-i<N>.doc-paths`(`doc_paths.py` 출력). stdout 9줄:
  ```text
  mode: <mode>
  base: <커밋 id | ->
  head: <커밋 id | worktree>
  degraded: yes|no
  files: <N | ->
  filtered_files: <N | ->
  excluded: <N>
  kept_model: <M>
  doc_paths_source: <doc_paths 출처>
  ```
  범위별 기준: session = `resolve-baseline.sh` 의 `merge_base` 대비 작업 트리(추적 diff ∪ 무시되지 않는 untracked), branch = `merge_base`..HEAD, paths = session 집합 중 `--globs` 에 맞는 것(git pathspec), topic = `boundary`..`tree`, range = `start`..`end`. session · branch · paths 의 기준선이 `degraded: yes` 면 파일을 비워 두고 `degraded: yes` · `files: -` 로 rc 0. git 실패는 rc 4, 사용 오류 rc 2. 설정 비교의 base 쪽은 `git show <base>:.claude/settings.json`, head 쪽은 session · paths 면 작업 트리 파일, 나머지는 `git show <head>:.claude/settings.json`. diff 는 늘 `git -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv` 로, untracked 는 `git diff --no-index --no-color --no-ext-diff -- /dev/null <f>`(rc 1 이 정상) 로 만든다. 걸러진 diff 는 같은 명령에 뺀 경로마다 `':(exclude,literal)<경로>'` 를 붙인다(untracked 는 뺀 경로를 건너뛴다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_doc_paths.py`(unittest, 기존 `.py` 테스트처럼 `importlib` 로 `scripts/doc_paths.py` 를 연다):

```python
def test_default_excludes_readme_changelog_anywhere(self):
    ex, kept = m.select(["README.md", "plugins/x/README.md", "plugins/x/CHANGELOG.md", "docs/a.md", "src/a.py"], list(m.DEFAULT_DOC_PATHS))
    self.assertEqual(ex, ["README.md", "plugins/x/README.md", "plugins/x/CHANGELOG.md"]); self.assertEqual(kept, [])
def test_docs_reviewed_by_default(self):
    ex, _ = m.select(["docs/git-workflow/branch-strategy.md"], list(m.DEFAULT_DOC_PATHS)); self.assertEqual(ex, [])
def test_model_read_kept_even_if_matched(self):
    paths = ["plugins/x/skills/y/SKILL.md", "plugins/x/agents/a.md", "CLAUDE.md", "plugins/x/references/r.md", "docs/guide.md"]
    ex, kept = m.select(paths, ["**/*.md"])
    self.assertEqual(ex, ["docs/guide.md"]); self.assertEqual(kept, paths[:4])
def test_code_never_excluded(self):
    ex, kept = m.select(["src/a.py", "src/notes.md"], ["src/**"])
    self.assertEqual(ex, ["src/notes.md"]); self.assertEqual(kept, ["src/a.py"])
def test_env_unset_is_default(self):        # parse_patterns(None) == (["README*", "CHANGELOG*"], [], "default")
def test_env_set_empty_excludes_nothing(self):   # parse_patterns("") 와 parse_patterns(" , ") 가 ([], [], "env")
def test_env_replaces_defaults(self):      # parse_patterns("docs/drafts/**") → README.md 는 select 에서 안 빠진다
def test_bad_pattern_disclosed(self):      # parse_patterns(":(exclude)x, !y, docs/*.md") == (["docs/*.md"], [":(exclude)x", "!y"], "env")
def test_glob_semantics(self):
    self.assertTrue(m.matches("docs/*.md", "docs/a.md")); self.assertFalse(m.matches("docs/*.md", "docs/x/a.md"))
    self.assertTrue(m.matches("docs/**/*.md", "docs/x/a.md")); self.assertTrue(m.matches("docs/**/*.md", "docs/a.md"))
    self.assertTrue(m.matches("README*", "a/b/README.md")); self.assertFalse(m.matches("README*", "a/READMEx/b.txt"))
def test_settings_changed(self):
    k = '{"env": {"DEVBREW_QUALITY_GATES_DOC_PATHS": "docs/**"}}'
    self.assertFalse(m.settings_key_changed(None, None)); self.assertFalse(m.settings_key_changed(k, k))
    self.assertTrue(m.settings_key_changed(None, k)); self.assertTrue(m.settings_key_changed('{"env": {}}', k))
    self.assertFalse(m.settings_key_changed('{"env": {"X": "1"}}', '{"env": {"X": "2"}}'))
    self.assertTrue(m.settings_key_changed("{not json", k))
def test_cli_output_shape(self):           # select CLI 를 subprocess 로 — 첫 다섯 줄의 키 순서, exclude/kept 줄이 탭 구분
```

`test_review_diff.sh` — 픽스처 레포(`trunk` + 클론으로 `origin/HEAD`):

```bash
case_session_includes_untracked()   # untracked new.py → review-i1.names 에 있고 full.diff 에 '+++ b/new.py'
case_session_doc_excluded()         # README.md 와 src/a.py 를 고침 → review-i1.diff 에 README 없음 · src/a.py 있음
                                    # stdout excluded: 1 · doc-paths 파일에 'exclude<TAB>README.md'
case_range_uses_frozen_pair()       # resolve-range.sh 로 F → R 을 시작 커밋에 체크아웃한 채 --mode range --scope-file F
                                    # base = start · head = end · names = git diff --name-only start end
case_topic_uses_boundary_tree()     # 손으로 쓴 topic 파일(boundary · tree) → base · head 가 그 값
case_settings_change_falls_back()   # 범위 안 커밋이 .claude/settings.json 의 env 키를 더함 + DEVBREW_QUALITY_GATES_DOC_PATHS='docs/**' export
                                    # doc_paths_source: default-settings-changed · docs/x.md 가 diff 에 남는다
case_filtered_empty()               # README.md 만 바뀜 → files: 1 · filtered_files: 0 · review-i1.diff 크기 0
case_degraded_session()             # detached HEAD → degraded: yes · files: - · rc 0
case_paths_mode()                   # src/a.py · lib/b.py 를 고침, --mode paths --globs 'src/*' → names 는 src/a.py 하나
case_no_ext_diff()                  # 레포 설정 diff.external=<표지 파일을 쓰는 스크립트> → 실행 뒤 표지 없음
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `(cd plugins/quality-gates/tests && python3 -m unittest -q test_doc_paths); chmod +x plugins/quality-gates/tests/test_review_diff.sh && bash plugins/quality-gates/tests/test_review_diff.sh`
Expected: 모듈 · 스크립트가 없어 전부 실패.

- [ ] **Step 3: `doc_paths.py` 와 `review-diff.sh` 를 쓴다**

`doc_paths.py` 는 위 Interfaces 그대로(환경 변수는 `os.environ.get(ENV_KEY)` — 「없음」과 「빈 값」을 가른다). `review-diff.sh` 는 형제 `resolve-baseline.sh`(qg `scripts/` 의 링크)와 `doc_paths.py` 를 `BASH_SOURCE` 폴더에서 부른다(cwd 아님). 하위 디렉토리에서 불려도 리포 최상위로 옮겨 일한다. 파일은 `<dir>` 안 임시 이름에 쓴 뒤 `mv`.

- [ ] **Step 4: 통과를 본다**

Run: Step 2 와 같다 + `bash shared/tests/test_inline_python_isolated.sh` + `python3 -m unittest -q test_utf8_explicit`(qg tests 폴더에서)
Expected: 실패 0.

- [ ] **Step 5: 설정 `env` 가 세션 환경 변수로 실리는지 잰다**

버릴 레포(`$HOME/.claude/sdd-mirror/r2a-plan3/tmp/settings-measure/repo`, `git init -q -b trunk`)에 `.claude/settings.json` = `{"env": {"DEVBREW_QUALITY_GATES_DOC_PATHS": "docs/drafts/**"}}` 를 두고 그 폴더에서:
Run: `claude -p 'Run exactly this Bash command and print its output verbatim: printenv DEVBREW_QUALITY_GATES_DOC_PATHS' --allowedTools Bash`
Expected: 출력에 `docs/drafts/**` 가 있으면 「실린다」, 없으면 「안 실린다」. rc 만으로 판정하지 않는다(헤드리스는 실패해도 rc 0 일 수 있다) — 출력 원문 · `claude --version` · 날짜를 `settings-env-measure.md` 에 적는다. 「안 실린다」면 Task 15 의 README 설정 절에 「셸 환경 변수로 준다」를 쓰고 지휘자에게 알린다.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/doc_paths.py plugins/quality-gates/scripts/review-diff.sh plugins/quality-gates/tests/test_doc_paths.py plugins/quality-gates/tests/test_review_diff.sh
git commit -m "feat(qg): 문서 경로 규칙(doc_paths)과 모든 범위의 리뷰 diff(review-diff)를 한 자리로" -- plugins/quality-gates/scripts/doc_paths.py plugins/quality-gates/scripts/review-diff.sh plugins/quality-gates/tests/test_doc_paths.py plugins/quality-gates/tests/test_review_diff.sh
```

---

### Task 5: Step 1 이 리뷰 diff 를 한 자리에서 만든다 (AC23)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:87` · `:94-96` (P2 지울 파일 목록에 `review-i*` — `rm -f "$RD"/review-i*` 꼴), `:172-231` (Step 1 — 1c 펜스, session 펜스 · topic 파일 집합 펜스 · FILTERED_DIFF 문장 교체), `:233-262` (Step 1b — `$resolved_scope_file_count` 출처), `:264-367` (Step 3 — `FILTERED_DIFF` · codex diff 의 출처), `:459-462` (Step 3.5 — `recritic.diff` 는 같은 파일의 사본), `:508-516` (Step 4 표), `## Final verdict` (걸러진 diff 가 빈 실행의 펜스)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (같은 폴더의 다른 파일 목록에 `review-i<N>.*`)
- Test: `plugins/quality-gates/tests/test_review_scope_composition.sh` · `test_topic_scope_wiring.sh` · `test_skill_run_contract.sh` · `test_a20_tool_agnostic_scope.py` (각 파일에서 바뀐 문장을 잡는 단언 — `grep -rn 'FILTERED_DIFF\|exclude-standard\|문서 경로\|documentation paths' plugins/quality-gates/tests` 로 전수를 먼저 찾는다)

**Interfaces:**
- Consumes: `review-diff.sh` (Task 4) — stdout 의 `files:` · `filtered_files:` · `excluded:` · `degraded:` · `doc_paths_source:` 와 `review-i<N>.diff` · `.doc-paths`.
- Produces: 이 iteration 의 `FILTERED_DIFF` = `$RD/review-i<N>.diff` 의 내용(보안 리뷰어 · 외부 리뷰어 · codex · 재비판 모두 같은 파일). `$resolved_scope_file_count` = `files:` 값(여전히 `check-review-scope.sh` 와 독립 — V7).

- [ ] **Step 1: 실패하는 락을 쓴다**

새 단언(`test_review_scope_composition.sh` 에 — 그 파일의 Step 창 자르는 방식을 따른다):

```bash
S1="$(awk '/^### Step 1 — scope$/{f=1;next} f&&/^### Step 1b/{exit} f' "$SK")"
assert_grep "$S1" 'review-diff\.sh" --dir "\$RD" --iter' "Step 1: 리뷰 diff 는 review-diff.sh 한 펜스가 만든다(AC23)"
assert_not_grep "$S1" 'exclude-standard    # \(c\)' "Step 1: 모델이 세 집합을 손으로 합치던 펜스가 없다"
assert_contains "$S1" '`files:`' "Step 1: \$resolved_scope_file_count 는 review-diff 의 files: 값"
assert_contains "$S1" '문서 경로' "Step 1: 문서 경로 공시 줄을 정한다(양성 짝)"
assert_eq "$(grep -c 'README\*' "$SK")" "0" "SKILL 에 문서 경로 패턴을 다시 적지 않는다 — 규칙은 doc_paths.py 하나"
S3="$(awk '/^### Step 3 — reviewers$/{f=1;next} f&&/^### Step 3\.5/{exit} f' "$SK")"
assert_contains "$S3" 'review-i<N>.diff' "Step 3: FILTERED_DIFF 와 codex diff 는 review-i<N>.diff"
FV="$(awk '/^## Final verdict$/{f=1;next} f&&/^## Publish$/{exit} f' "$SK")"
assert_contains "$FV" '--reason scope-empty' "걸러진 diff 가 빈 실행은 scope-empty 판정 펜스로 끝난다"
```

변이: 1c 펜스를 지운 임시 사본에서 첫 단언이 ✗.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/quality-gates/tests/test_review_scope_composition.sh`
Expected: 새 단언 ✗.

- [ ] **Step 3: SKILL 을 고친다**

Step 1 에 「**1c — 리뷰 diff (매 iteration, 스코프를 정한 뒤)**」를 두고 펜스는:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
TOP="$(git rev-parse --show-toplevel)" || { echo "[quality-gates] git 리포 밖이다 — /quality-gates:quality-pipeline 은 git 리포 안에서만 돈다. 멈춘다." >&2; exit 1; }
RD="${TOP}/.claude/quality-gates/<session-id>"
"$QG/scripts/review-diff.sh" --dir "$RD" --iter <N> --mode <session|branch|paths|topic|range> <--globs <glob>... | --scope-file <topic-scope.txt 또는 range-scope.txt 경로>>; echo "review-diff rc=$?"
cat "$RD/review-i<N>.doc-paths"
```

그 아래 규칙(문면): rc 가 0 이 아니면 stderr 와 함께 멈춘다. `degraded: yes` 면 Step 4.5 의 degraded 갈래로 싣는다(0 으로 읽지 않는다). 매 iteration 공시 한 줄 `> [quality-gates] 문서 경로 <doc_paths>(출처: <기본 | 환경 변수 | 기본 — 이 변경이 설정을 바꿨다>) — 리뷰에서 뺀 경로 <excluded>개.` 와, 있으면 `> [quality-gates] 문서 경로 패턴에 걸렸지만 모델이 읽거나 코드라 리뷰에 남겼다: <kept 경로들>` · `> [quality-gates] 읽지 못한 문서 경로 패턴 — 적용하지 않았다: <bad_patterns>`. `files:` > 0 이고 `filtered_files: 0` 이면 `> [quality-gates] 리뷰할 diff 가 비었다 — 바뀐 파일 <files>개가 전부 문서 경로라 리뷰에서 뺐다. 이 실행은 clean 이 아니다.` 를 내고 리뷰어 · 차등 테스트 · e2e 를 건너뛰어 `## Final verdict` 의 「걸러진 diff 가 빈 실행」 펜스로 간다 — 그 펜스는 trivia 펜스와 같은 꼴로 `verdict.py --reason scope-empty --line --blocking 0 --optional 0 --new-failures 0 --excluded 0 --iter <N> --sha <판정 커밋> --e2e '안 함'`. Step 1 의 session 펜스 · topic 파일 집합 펜스 · 「`FILTERED_DIFF` 는 … 문서 경로를 뺀 것이다」 문장은 이 1c 로 대신한다. Step 3 의 `FILTERED_DIFF` · codex diff blob, Step 3.5 의 `recritic.diff` 는 `$RD/review-i<N>.diff` 를 쓴다(재비판은 `cp` 로 `$RV/recritic.diff` 에). security-reviewer dispatch 의 `filtered_diff` 설명 괄호는 「(Step 1c 의 리뷰 diff — 문서 경로를 뺀 것)」.

- [ ] **Step 4: 통과를 본다**

Run: `for t in test_review_scope_composition test_topic_scope_wiring test_skill_run_contract test_skill_orchestration test_plugin_root_no_cwd_fallback; do bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done; bash shared/tests/test_skill_body_no_positional_tokens.sh | tail -1; (cd plugins/quality-gates/tests && python3 -m unittest -q test_a20_tool_agnostic_scope)`
Expected: 실패 0(바뀐 문장을 잡던 기존 단언은 새 자리를 재게 고친다 — 커밋 본문에 단언별로 적는다). `test_plugin_root_no_cwd_fallback.sh` 가 없으면 `shared/tests/` 의 같은 이름을 돌린다.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(qg): Step 1 이 모든 범위의 리뷰 diff 를 review-diff 한 펜스로 — 걸러진 diff 가 비면 scope-empty" -- plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md <고친 테스트 경로들>
```

---

### Task 6: 범위 모드를 파이프라인에 잇는다 (AC21 · AC22)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — frontmatter `argument-hint`(:13) · P2 지울 목록(:87, `range-scope.txt`) · 새 **P2b** · P3(:107-128) · `## Flow`(:132-152) · Step 1(:174 — range 는 override, 1a 를 돌리지 않음) · Step 1b(:233 — 범위 모드는 건너뜀) · Step 3 codex(:356-361) · Step 4.5(:535-561) · `### Fix-loop decision`(:614-661) · `## e2e`(:724-727) · `## Final verdict`(:877-946 — 판정 커밋 · `## 범위`) · `## Publish`(:948-956)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md` D0(:52-73) · D1(:75-112) · D2(:114-154)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (`## 범위` 절 · `range-scope.txt`)
- Create: `plugins/quality-gates/tests/test_range_wiring.sh` (100755)
- Test: `test_differential_procedure.sh` · `test_publish_pipeline_wiring.sh` · `test_v1_verdict_line.sh` · `test_pipeline_verdict_wiring.sh`(판정 펜스의 `--sha` 를 잡는 단언이 있으면)

**Interfaces:**
- Consumes: `resolve-range.sh --out <file> -- <args>` · `create-head <end> <sid> --range <file>` (Task 2), `discover-spec.sh --range <s> <e>` · `run_codex_reviewer.sh … --range <s> <e>` (Task 3), `review-diff.sh --mode range --scope-file <file>` (Task 4), `compute-test-scope-candidates.sh --topic <s> <e>` · `--total --tree <e>` (공유본, 그대로).
- Produces: 범위 모드의 계약 — `/quality-gates:quality-pipeline range <시작>` 이 `<시작>` 부터 `origin/HEAD` 끝까지를 리뷰하고, diff 기준 · 차등 기준선 = `<시작>`, HEAD 축 = 끝 커밋, 판정 줄 커밋 = 끝 커밋, 게시 없음(공시). R5 끝 단계 호출 꼴이다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_range_wiring.sh` — 문면 락(각각 변이 1개와 함께)과 끝에서 끝 사슬 하나:

```bash
assert_grep "$(sed -n '1,20p' "$SK")" '^argument-hint: .*range <시작>\[\.\.<끝>\]' "인자 안내에 range 가 있다 — R5 가 이것으로 범위 입력 여부를 정한다"
P2B="$(awk '/^\*\*P2b — /{f=1} /^\*\*P3 — /{f=0} f' "$SK")"
assert_contains "$P2B" 'resolve-range.sh" --out "$RD/range-scope.txt" -- $ARGUMENTS' "P2b 가 범위를 한 번 얼린다"
assert_contains "$P2B" '범위를 풀지 못했다' "P2b: 못 풀면 판정 없이 멈추는 줄"
assert_contains "$(awk '/^\*\*P2 — /{f=1} /^\*\*P2b — /{f=0} f' "$SK")" 'range-scope.txt' "P2 가 앞 실행의 range-scope.txt 를 지운다"
assert_contains "$(awk '/^\*\*P3 — /{f=1} /^## Flow/{f=0} f' "$SK")" '설계문서 N개' "P3: 여러 설계문서의 의도 줄"
FL="$(awk '/^### Fix-loop decision$/{f=1;next} f&&/^### Max-iter/{exit} f' "$SK")"
assert_contains "$FL" '범위 모드' "Fix-loop: 범위 모드 갈래가 있다(양성 짝)"
# 범위 모드 질문의 선택지 줄들에 「고치고 다시 돌기」가 없다 — 범위 갈래 블록을 잘라 잰다
assert_contains "$(awk '/^## e2e$/{f=1;next} f&&/^\*\*E0/{exit} f' "$SK")" '범위 모드' "e2e: 범위 모드는 걷지 않는다"
FV="$(awk '/^## Final verdict$/{f=1;next} f&&/^## Publish$/{exit} f' "$SK")"
assert_count_ge "printf '%s\n' \"\$FV\" | grep -c 'range-scope.txt'" 3 "판정 펜스(일반 · trivia · scope-empty)가 범위 모드면 끝 커밋을 쓴다"
assert_contains "$(awk '/^## Publish$/{f=1;next} f&&/^## kill switch$/{exit} f' "$SK")" '게시 안 함 — 범위 모드라 PR 코멘트를 달지 않는다' "게시: 범위 모드는 달지 않고 공시한다"
DT="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
assert_file_grep "$DT" 'scope0=range' "D0: 범위 모드의 기준선은 시작 커밋"
assert_file_grep "$DT" '\-\-range "\$RD/range-scope.txt"' "D1: HEAD 축은 create-head --range"
assert_file_grep "$DT" '\-\-topic <start> <end>' "D2: 범위의 후보는 --topic <start> <end>"
```

끝에서 끝 사슬(`case_chain_agrees`): `trunk` 픽스처 레포(origin 클론, 설계문서 둘을 커밋 둘에 `Spec:` 트레일러로, 코드 변경 하나와 `tests/test_x.sh`(100755)) 에서 R 을 **시작 커밋에 체크아웃한 채**: `resolve-range.sh --out F -- range <S>` → `review-diff.sh --dir D --iter 1 --mode range --scope-file F` → `discover-spec.sh --intent-out I --range <S> <E>` → `compute-test-scope-candidates.sh --topic <S> <E>` → `qg-worktree.sh create-head <E> sid12345 --range F`. 단언: review-diff 의 `base:` = S · `head:` = E, `specs` 길이 2, 후보에 `tests/test_x.sh`, HEAD 축 트리의 `git rev-parse HEAD` = E. 만든 트리는 `qg-worktree.sh remove` 로 지운다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `chmod +x plugins/quality-gates/tests/test_range_wiring.sh && bash plugins/quality-gates/tests/test_range_wiring.sh`
Expected: 문면 단언 ✗, 사슬은 Task 2~4 가 있어 통과(사슬이 실패하면 앞 Task 의 계약 결함 — 그 Task 로 돌아간다).

- [ ] **Step 3: SKILL · reference 를 고친다**

- `argument-hint: "[branch|--paths <glob>...|range <시작>[..<끝>]]"`. P2 아래 「Arguments:」 줄에 `range <시작>[..<끝>]` — 끝을 생략하면 `origin/HEAD`.
- **P2b — 범위 (range 인자일 때만 · 실행에 한 번).** 펜스: 루트 · `TOP` · `RD` 대입 뒤 `"$QG/scripts/resolve-range.sh" --out "$RD/range-scope.txt" -- $ARGUMENTS; echo "range rc=$?"`. `range: none` 이면 범위 모드가 아니다. rc 0 이면 한 줄 `> [quality-gates] 리뷰 범위: <start 앞 12자>..<end 앞 12자> — 커밋 <commits>개 · 바뀐 파일 <files>개(끝: <end_from 이 origin/HEAD 면 「기본 브랜치 끝」, given 이면 「적은 끝」>).` rc 3 이면 `[quality-gates] 범위를 풀지 못했다 (<status>: <reason>) — 실행하지 않는다.` 를 내고 멈춘다. rc 2 는 stderr 를 그대로 보이고 멈춘다. 이 파일은 실행 동안 고치지 않는다 — 모든 반복이 같은 두 커밋을 쓴다.
- P3: 범위 모드면 `discover-spec.sh --intent-out "$RD/intent.md" --range <start> <end>`. 의도 줄은 `specs` 가 둘 이상이면 `intent: spec-trailer — 설계문서 N개 (<경로> · <경로> …)`, 하나면 지금 꼴.
- Step 1: 범위 모드는 override(`branch` · `--paths` 와 같은 자리) — 1a 를 돌리지 않고 override 스코프 파일 정리를 돈다. 1c 는 `--mode range --scope-file "$RD/range-scope.txt"`. 범위 투명 줄은 P2b 가 이미 냈다. Step 1b: 범위 모드는 `check-review-scope.sh` 를 돌리지 않는다 — `$changes_exist = yes`(빈 범위는 P2b 가 멈췄다) · `$degraded = no`.
- Step 3 codex: 범위 모드면 러너 끝에 `--range <start> <end>`.
- Step 4.5: 범위 모드면 판정 꼬리 뒤에 `$RD/range-scope.txt` 를 그대로 보인다.
- Fix-loop decision: 범위 모드 갈래 — 첫 질문 `qg 반복 N: 남은 지적이 있다(<summary>). 범위 모드는 이미 있는 커밋을 본다 — 고칠 것은 새 브랜치에서 고친다. 어떻게 끝낼까?` 의 선택지는 「지금 판정으로 끝내기」 · 「멈추기」 둘이고 분류 질문은 없다. 범위 모드는 반복 1 에서 끝나므로 Max-iter 에 닿지 않는다(그 사실을 한 문장).
- `## e2e`: 범위 모드면 질문 없이 e2e 칸 `안 함` 과 `> [quality-gates] 범위 모드라 앱을 걷지 않는다 — 지금 체크아웃이 범위 끝과 다를 수 있다.`
- `## Final verdict`: 세 판정 펜스(일반 · trivia · scope-empty)의 `--sha` 를 `SHA_ARG` 로 — 펜스 안에서 `SHA_ARG="$(git rev-parse --short HEAD)"; RS="$RD/range-scope.txt"; if [ -f "$RS" ]; then SHA_ARG="$(git rev-parse --short "$(sed -n 's/^end: //p' "$RS")")"; fi`. 기록 펜스는 `## 판정` 다음에 `if [ -f "$RD/range-scope.txt" ]; then printf '\n## 범위\n\n'; cat "$RD/range-scope.txt"; fi`.
- `## Publish`: 범위 모드면 1 · 2 대신 이 펜스만 — `result.md` 에 `## 게시` 가 없을 때 `게시 안 함 — 범위 모드라 PR 코멘트를 달지 않는다(범위에는 열린 PR 이 없다)` 를 `## 게시` 절로 덧붙이고 같은 줄을 낸다(게시 펜스의 「한 번만」 규칙과 같은 검사).
- `differential-test.md`: D0 의 스코프 판별 펜스에 범위 갈래 — `RS="$RD/range-scope.txt"; if [ -f "$RS" ] && [ "$(sed -n 's/^status: //p' "$RS")" = ok ]; then printf 'scope0=range\nboundary=%s\n' "$(sed -n 's/^start: //p' "$RS")"; elif …topic…; else echo "scope0=session"; fi`, 범위면 기준선 커밋 = `boundary=`. D1: 범위면 `scope=range; base=<start>; hc=<end>; tree=<end>` 로 읽고 `cand="$hc"; head_tree=$("$QG/scripts/qg-worktree.sh" create-head "$hc" "<session-id>" --range "$RD/range-scope.txt") || head_tree=""`. D2: 「토픽 스코프면」 문장을 「토픽 · 범위 스코프면」으로 — 범위의 후보는 `--topic <start> <end>`, 분모는 `--total --tree <end>`. 기준선 알림 줄의 키 칸은 범위면 `range`.
- `state-file-format.md`: `## 판정` 다음 `## 범위`(범위 모드일 때만) · 다른 파일 목록에 `range-scope.txt`.

- [ ] **Step 4: 통과를 본다**

Run: `for t in test_range_wiring test_differential_procedure test_differential_trees test_publish_pipeline_wiring test_v1_verdict_line test_pipeline_verdict_wiring test_topic_scope_wiring test_skill_run_contract; do printf '%s ' $t; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done`
Expected: 실패 0(바뀐 펜스를 잡던 단언은 새 꼴로 — 커밋 본문에 적는다).

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(qg): 범위 모드 — 시작부터 기본 브랜치 끝까지, 두 커밋을 모든 소비자가 함께 쓴다" -- plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md plugins/quality-gates/tests/test_range_wiring.sh <고친 테스트 경로들>
```

---

### Task 7: 리뷰어 구성은 시작 구성, 규모 공시는 두 줄 (AC24)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — `## Flow` 의 「기본 3 + 조건부 ≤4」(:137), Step 3 `**Composition**`(:278-298), External reviewers 의 실패 문장(:353-354), `**R5 (single setup)**`(:1062-1063)
- Modify: `plugins/quality-gates/README.md` — `## Cost Class`(:120)의 「iteration 당 최대 8」, `## 리뷰어 구성`(:180-207)의 시작 줄 서술
- Test: `plugins/quality-gates/tests/test_review_scope_composition.sh` (+ `grep -rln 'iter N — 선택\|at most 8\|최대 8' plugins/quality-gates/tests` 로 찾은 파일)

**Interfaces:**
- Produces: 두 공시 줄의 정확한 꼴 —
  - 시작 줄(Step 3 의 첫 dispatch 전): `> [quality-gates] iter N — 리뷰어 <계획한 수>명을 부른다(구성표 <a>명 · 근거를 적어 더한 <b>명) — 선택: <리뷰어>(근거: <신호>) / 더함: <리뷰어>(근거: <한 줄>) / 제외: <리뷰어: 이유 또는 "해당 신호 없음">` (`더함:` 은 b > 0 일 때만)
  - 끝 줄(Step 3 의 dispatch 가 모두 돌아온 뒤, 늘): `> [quality-gates] iter N — 다시 부른 리뷰어 <r>명(일시 실패 재시도 <x> · 나눠 돌림 <y>)[ / 실패: <리뷰어>]`

- [ ] **Step 1: 실패하는 락을 쓴다**

```bash
S3="$(awk '/^### Step 3 — reviewers$/{f=1;next} f&&/^### Step 3\.5/{exit} f' "$SK")"
assert_not_grep "$S3" 'at most 8|최대 8' "Step 3: 리뷰어 상한 8 이 없다(AC24 — 비용 장치 제거)"
assert_not_grep "$(cat "$SK")" 'Do not re-dispatch the same reviewer|같은 리뷰어를 다시 부르지' "같은 반복 재호출 금지가 없다(AC24)"
assert_contains "$S3" '시작 구성' "구성표는 시작 구성이다"
assert_contains "$S3" '> [quality-gates] iter N — 리뷰어 <계획한 수>명을 부른다' "시작 줄 꼴"
assert_contains "$S3" '> [quality-gates] iter N — 다시 부른 리뷰어 <r>명(일시 실패 재시도 <x> · 나눠 돌림 <y>)' "끝 줄 꼴"
start_ln=$(printf '%s\n' "$S3" | grep -n '리뷰어 <계획한 수>명을 부른다' | head -1 | cut -d: -f1)
agent_ln=$(printf '%s\n' "$S3" | grep -n 'subagent_type: "quality-gates:security-reviewer"' | head -1 | cut -d: -f1)
[ -n "$start_ln" ] && [ -n "$agent_ln" ] && [ "$start_ln" -lt "$agent_ln" ] && ok "시작 줄은 첫 dispatch 앞에 있다(크게 쓰기 전에 규모를 알린다)" || no "시작 줄이 dispatch 뒤에 있거나 없다"
assert_contains "$S3" '일시 실패' "일시 실패 1회 재시도 규칙"
assert_not_grep "$(cat "$PLUGIN_ROOT/README.md")" '최대 8' "README 에 리뷰어 상한 8 이 없다"
```

변이: Step 3 에 `**Composition** — at most 8 per iteration:` 을 되살린 사본에서 첫 단언 ✗.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/quality-gates/tests/test_review_scope_composition.sh`
Expected: 새 단언 ✗.

- [ ] **Step 3: 문면을 고친다**

`**Composition**` 머리를 「**시작 구성** — 아래 표는 시작점이다. diff 와 의도 출처를 보고 리뷰어를 더할 수 있다 — 신호가 없는 조건부 리뷰어나 이 세션에서 쓸 수 있는 다른 읽기 전용 리뷰 agent 를, 한 줄 근거와 함께. 재비판은 늘 하나다.」로. 그 아래: 시작 줄(dispatch 전) · 끝 줄(Step 3 의 dispatch 가 모두 돌아온 뒤) 꼴 · 「리뷰어가 실패하거나 읽을 수 있는 출력이 없으면 한 번 다시 부른다(일시 실패 재시도). 두 번째도 실패하면 아래 규칙대로다(보안은 fail-closed, 외부는 「실패」)」 · 「diff 가 한 리뷰어에게 너무 크면 파일 묶음으로 나눠 같은 리뷰어를 나란히 부를 수 있다(나눠 돌림) — 묶음마다 같은 프롬프트, diff 만 그 묶음」 · 다시 부른 리뷰어는 끝 줄에 센다. 지금의 「Print exactly one line per iteration, once this step's dispatches have returned」 줄은 끝 줄로 대신한다. `## Flow` 의 「(기본 3 + 조건부 ≤4 → code-recritic)」 → 「(시작 구성 + 근거를 적어 더한 리뷰어 → code-recritic)」. R5 는 「call `setup-qg.sh` only as P2 does and `discover-spec.sh` once per run.」만 남긴다. README 의 Cost Class · 리뷰어 구성 줄을 같은 뜻으로(이 설계가 바꾸는 동작의 줄만 — 나머지 낡은 개념은 R11).

- [ ] **Step 4: 통과를 본다**

Run: `for t in test_review_scope_composition test_skill_orchestration test_plain_readme test_readme_scope_reconcile test_cost_consent; do printf '%s ' $t; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done; bash shared/tests/test_dispatch_disposition.sh | tail -1`
Expected: 실패 0.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(qg): 리뷰어 상한 8 · 같은 반복 재호출 금지를 지우고 규모를 시작 · 끝 두 줄로 공시" -- plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/README.md <고친 테스트 경로들>
```

---

### Task 8: 수정 루프 상한에서 사용자가 한 번씩 연다 (AC25)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — `## Flow`(:136 `iteration N = 1..5`, :151-152 Iteration accounting), Step 4.5 라우팅(:555-561), `### Fix-loop decision` 머리(:616), `### Max-iter decision`(:663-684), `## e2e` E4(:848-849), P2 지울 목록(`extra-iterations.md`), `## Final verdict` 기록 펜스(`## 추가 반복`)
- Modify: `plugins/quality-gates/references/e2e.md` §5(남은 iteration 이 없을 때)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (`## 추가 반복` · `extra-iterations.md`)
- Test: `plugins/quality-gates/tests/test_plain_qg_templates.sh`(:27 · :126-137) · `test_pipeline_verdict_wiring.sh`(:379-429) · `test_v_requirements.sh`(:157-158)

**Interfaces:**
- Produces: 상한 `CAP = 5 + <extra-iterations.md 의 줄 수>`. `$RD/extra-iterations.md` 의 줄 꼴 `- iter <N> 뒤 · 반복 하나 더 · <label|typed> · <원문>`. `result.md` 의 `## 추가 반복` 절(그 파일이 있을 때만, `## 제외 패치` 다음).

- [ ] **Step 1: 실패하는 락을 쓴다**

`test_plain_qg_templates.sh` ⑩ 를 고친다 — 선택지 라벨은 셋(「한 번 더 돌기」 · 「지금 판정으로 끝내기」 · 「멈추기」), 각 라벨이 같은 절의 굵은 분기 글자와 같다(기존 루프 그대로). :27 의 질문 문장 단언을 새 질문으로:

```bash
assert_grep "$(qlines "$S")" 'question: "qg 가 반복 상한\(<CAP>번 — 기본 5번\)에 닿았다\. 마지막 지적: <summary>\.' "AC25: 상한 질문이 기본 5 와 지금 상한을 말한다"
MX="$(awk '/^### Max-iter decision$/{f=1;next} f&&/^### /{exit} f' "$S")"
assert_contains "$MX" 'extra-iterations.md' "한 번 더 돌기는 승인 출처와 원문을 기록한다"
assert_contains "$MX" 'typed' "기타 칸 원문도 승인으로 받는다(출처 typed)"
assert_contains "$MX" '한 번에 하나' "한 번 열면 반복 하나 — 그 끝에 다시 묻는다(상한은 남는다)"
```

`test_pipeline_verdict_wiring.sh` 의 N=5 락(X6 · X8 · `N5_*`)은 「상한(CAP)에서 도달하면」 문단으로 같은 뜻(차등 기원 포함 · Max-iter 를 부른다 · Fix-loop 언급은 부정에 묶임)을 다시 잰다. `test_v_requirements.sh` 의 P18 단언은 「기본 상한 5」 문장을 잰다(상한이 사라지지 않았다는 양성 단언).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `for t in test_plain_qg_templates test_pipeline_verdict_wiring test_v_requirements; do bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -3; done`
Expected: 새 단언 ✗.

- [ ] **Step 3: 문면을 고친다**

Max-iter decision 질문 둘 — 첫째 `qg 가 반복 상한(<CAP>번 — 기본 5번)에 닿았다. 마지막 지적: <summary>. 반복을 하나 더 열까, 지금 판정으로 끝낼까, 멈출까?`(선택지 「한 번 더 돌기」: 「반복을 하나 더 연다 — 분류표의 「적용」 항목을 고치고 다시 돈다(차등 테스트 포함). 그 반복 끝에 다시 묻는다.」 · 「지금 판정으로 끝내기」 · 「멈추기」 — 설명은 지금 문구), 둘째는 Fix-loop decision 의 분류 질문 그대로. 분기: **한 번 더 돌기** → 아래 펜스로 한 줄을 기록하고 Fix-loop 의 「고치고 다시 돌기」와 같은 경로(N += 1). 기타 칸의 글이 반복을 더 여는 뜻이면 같은 경로로 출처 `typed` 와 원문을 기록하고, 끝내기 · 멈추기 뜻이면 그쪽으로 간다. 펜스(루트 · `TOP` · `RD` 대입 뒤):

```bash
printf -- '- iter %s 뒤 · 반복 하나 더 · %s · %s\n' '<N>' '<label 또는 typed>' '<고른 선택지 이름 또는 기타 칸 원문 — 줄바꿈은 공백으로>' >> "$RD/extra-iterations.md"
```

`## Flow` 는 `iteration N = 1..CAP (CAP = 5 + 사용자가 연 반복)`, Iteration accounting 은 「N = CAP 에서는 Retry 가 없다 — Max-iter decision 이 한 번에 하나씩 반복을 더 열 수 있다」. Step 4.5 의 「N < 5」 · 「N=5 에서 도달하면」 · Fix-loop decision 머리의 `N < 5 only — N=5 …` 는 CAP 로(「N=5 는 P18 상한이라 예외가 없다」 → 「상한은 P18 이다 — 넘는 길은 Max-iter decision 의 사용자 승인 하나뿐이다」). e2e E4 · `e2e.md` §5 의 「iteration 5 를 다 썼으면」 · 「남은 iteration 이 없으면」 → 「CAP 에 닿았으면 fail 행에 「고치고 다시 돌기」 대신 「한 번 더 돌기」를 넣고, 고르면 위와 같이 기록한다」. P2 지울 목록과 Final verdict 기록 펜스(`if [ -s "$RD/extra-iterations.md" ]; then printf '\n## 추가 반복\n\n'; cat "$RD/extra-iterations.md"; fi` — `## 제외 패치` 다음)에 반영.

- [ ] **Step 4: 통과를 본다**

Run: Step 2 + `bash plugins/quality-gates/tests/test_e2e_docs.sh | tail -1`
Expected: 실패 0.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(qg): 수정 루프 상한에서 사용자가 반복을 하나씩 더 연다 — 승인 출처와 원문을 기록" -- plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/references/e2e.md plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md <고친 테스트 경로들>
```

---

### Task 9: 낮춘 지적을 보이고 되올린다 (AC26)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py:240-283` (`apply_verdicts` — 원래 심각도 · 이유 보존), `:680-735` (`render` — `lowered:` 줄 · `## 낮춘 지적` 절), `:738-800` (`main` — `--restore-lowered`)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Step 4 펜스 설명(`--restore-lowered`), Step 4.5(낮춘 지적 게이트 · 다시 합성), `## Final verdict` 기록 펜스(`## 낮춘 지적` 복사)
- Modify: `plugins/quality-gates/agents/code-recritic.md:63-65` (lower 의 `evidence` 가 사용자에게 보인다 — persona, Task 14 리뷰)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (`## 낮춘 지적`)
- Create: `plugins/quality-gates/tests/test_synthesize_lowered.py`
- Test: `plugins/quality-gates/tests/test_synthesize_recritic.sh` · `test_synthesize_findings.sh`(출력 줄 수 · 접두를 잡는 단언이 있으면)

**Interfaces:**
- Produces: 합성기 출력 — `optional:` 줄 바로 다음에 늘 `lowered: <n>`. n ≥ 1 이면 지적 표 뒤(`**고칠 방법:**` 앞)에:
  ```text
  ## 낮춘 지적

  | 번호 | 위치 | 원래 심각도 | 내용 | 낮춘 이유 |
  |---|---|---|---|---|
  | L1 | src/a.py:41 | IMPORTANT | <plain (summary) 또는 summary> | <재비판의 evidence> |
  ```
  번호는 입력 finding 순서의 낮춘 것 순서(결정적). 
- Produces: `synthesize_findings.py … --restore-lowered <L번호 쉼표 목록 | all>` — 그 번호의 lower 를 적용하지 않아 원래 심각도로 남긴다. 출력에 `restored: <번호들>` 줄(`lowered:` 다음)과, 절의 그 행 「낮춘 이유」 칸 머리에 `(사용자가 되올림) `. 모르는 번호는 rc 2 · stderr `synthesize_findings.py: 모르는 낮춘 지적 번호: L9`. `--restore-lowered` 는 `--recritic` 없이 주면 rc 2.
- 바뀌지 않음: 판정 없는 출력이 판정 있는 출력의 바이트 접두라는 불변식 · `verdict:` · `blocking:` · `optional:` 줄이 정확히 한 번.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_synthesize_lowered.py` — 기존 `test_synthesize_findings_adjudication.py` 의 모듈 적재 · 재비판 픽스처 꼴(IMPORTANT 하나 · 재비판 `verdict: lower` + `evidence: "의도 출처는 캐시 무효화만 요구한다"`)을 쓴다:

```python
def test_lowered_section_lists_original_severity_and_reason(self):
    out = run_synth(findings=[IMP], recritic=LOWER_F1)
    self.assertIn("lowered: 1\n", out); self.assertIn("blocking: 0\n", out)
    self.assertIn("## 낮춘 지적", out)
    self.assertRegex(out, r"\| L1 \| src/a\.py:41 \| IMPORTANT \| .+ \| 의도 출처는 캐시 무효화만 요구한다 \|")
def test_restore_lowered_puts_it_back(self):
    out = run_synth(findings=[IMP], recritic=LOWER_F1, extra=["--restore-lowered", "L1"])
    self.assertIn("blocking: 1\n", out); self.assertIn("restored: L1\n", out); self.assertIn("(사용자가 되올림)", out)
def test_restore_all(self):                     # 둘을 낮추고 --restore-lowered all → blocking 2
def test_restore_unknown_number_exit2(self):    # --restore-lowered L9 → SystemExit 2, stderr 에 '모르는 낮춘 지적 번호: L9'
def test_no_lowered_no_section(self):           # lower 없음 → 'lowered: 0' 있고 '## 낮춘 지적' 없음
def test_prefix_invariant_holds(self):          # --emit-verdict 없는 출력이 있는 출력의 접두
```

SKILL 락(같은 파일 또는 `test_pipeline_verdict_wiring.sh`): Step 4.5 창에 `lowered:` · `multiSelect: true` · `header: "낮춘 지적"` · `--restore-lowered` 가 있다. Final verdict 기록 펜스에 `## 낮춘 지적` 복사가 있다. code-recritic 창에 「낮춘 지적」 문장이 있다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `(cd plugins/quality-gates/tests && python3 -m unittest -q test_synthesize_lowered)`
Expected: 실패.

- [ ] **Step 3: 합성기 · SKILL · persona 를 고친다**

`apply_verdicts` 의 lower 갈래에서 `f["lowered_from"] = <바꾸기 전 심각도>`, `f["lowered_reason"] = v.get("reason", "")` 를 둔다. `main` 은 `--restore-lowered` 를 받아 판정 적용 전에 낮춘 지적 목록(입력 순서)에서 번호를 풀고, 그 finding 의 lower 판정을 confirm 처럼 다룬다(회계는 `accept` — 사람의 결정이라 강제 계수가 아니다). `render` 는 위 꼴을 낸다(표 칸은 기존 `_cell` 로). SKILL Step 4.5 — 판정 표면화 뒤, 라우팅 앞: `$RV/synth.out` 의 `lowered:` 가 1 이상이면 게이트(반복마다, 판정이 clean 이어도):

```text
AskUserQuestion({ questions: [{
  question: "재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절). 되올릴 것을 고르세요 — 되올리면 원래 심각도로 판정에 들어간다.",
  header: "낮춘 지적",
  options: <n ≤ 3: 지적마다 {label: "<파일 이름>:<줄> (L<k>)", description: "<낮춘 이유를 쉬운 말 한 줄로>"} + {label: "그대로 둔다", description: "낮춘 대로 둔다."}
            n ≥ 4: {label: "전부 되올린다", …} · {label: "그대로 둔다", …} — 일부만이면 「기타」에 번호(예: L1, L3)>,
  multiSelect: true }] })
```

고른 번호가 있으면 Step 4 의 합성 펜스를 `--restore-lowered <번호들>` 을 더해 다시 돌려 `$RV/synth.out` 을 덮고(앞 출력은 `$RV/synth-before-restore.out` 으로 옮긴다) Step 4.5 표면화를 다시 한 뒤 라우팅한다. 기록 펜스는 `sed -n '/^## 낮춘 지적$/,/^$/p' "$SYN"` 의 표를 `## 낮춘 지적` 절로(`## 지적` 다음, 있을 때만). code-recritic 의 lower 항목 끝에: 「lower 의 `evidence` 는 사용자에게 보고서 「낮춘 지적」 절로 그대로 보이고 사용자가 되올릴지 고른다 — 무엇을 왜 낮췄는지 인용과 함께 처음 보는 사람이 읽을 한 문장으로 쓴다.」

- [ ] **Step 4: 통과를 본다**

Run: `(cd plugins/quality-gates/tests && python3 -m unittest -q test_synthesize_lowered test_synthesize_findings_adjudication); for t in test_synthesize_recritic test_synthesize_findings test_pipeline_verdict_wiring test_plain_synth_output; do printf '%s ' $t; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done; bash shared/tests/test_adjudication_wiring.sh | tail -1`
Expected: 실패 0(`test_adjudication_wiring.sh` 의 컴프리헨션 기준선에 걸리면 `for` 문으로 쓴다).

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/tests/test_synthesize_lowered.py
git commit -m "feat(qg): 재비판이 낮춘 지적을 이유와 함께 보이고 게이트에서 되올린다" -- plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/agents/code-recritic.md plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md plugins/quality-gates/tests/test_synthesize_lowered.py <고친 테스트 경로들>
```

---

### Task 10: persona — 모델 고정을 풀고 「원인이 이 변경이면 보고」 (AC27)

**Files:**
- Modify: `plugins/quality-gates/agents/security-reviewer.md:6` (`model: opus` 삭제), `:40` (`filtered_diff` 설명 — 정의를 다시 갖지 않음), `:79` (`## Severity` 범위 문장), `:112` (`## Forbidden` 범위 문장)
- Modify: `plugins/quality-gates/agents/code-recritic.md:13` (`model: opus` 삭제)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:345` (외부 리뷰어 프롬프트 「Report only findings in the changed code.」)
- Modify: `plugins/quality-gates/README.md:75-76` (구조 트리의 `model: opus`), `:128-138` (`### 재비판자(code-recritic) model`)
- Test: `plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh` · `test_agent_model_mutation.sh` · `test_security_reviewer_persona.sh:51` · `test_code_recritic_frontmatter.sh:4,20,35` · `test_skill_run_contract.sh:194`

**Interfaces:**
- Produces: 네 자리의 새 문장(이 글자 그대로 — 락이 잡는다). 바꾸기 전 문장은 각 블록 위 주석:

```text
# security-reviewer ## Severity — 「Code this change did not touch is out of scope — do not report hardening for it (see `## Forbidden`).」 를 대신한다
Report a finding located outside the diff when its cause is this change (for example, a caller or a control the change broke). Do not report hardening for code whose behavior this change did not affect (see `## Forbidden`).

# security-reviewer ## Forbidden — 「- No findings outside the diff's actual code changes.」 를 대신한다
- No findings whose cause is not this change — a location outside the diff is fine when the cause is this change.

# SKILL 외부 리뷰어 프롬프트 — 「Report only findings in the changed code.」 를 대신한다
Report findings this change caused — the location may be outside the diff when the cause is this change.

# security-reviewer ## Inputs 의 filtered_diff 줄(:40)을 대신한다
- `filtered_diff`: the review diff from Step 1c — the pipeline decides which documentation paths it leaves out and discloses that list; do not re-apply your own exclusion.
```

- [ ] **Step 1: 락을 뒤집는다(실패하게)**

- `test_agent_model_unpinned_sweep.sh`: `PINNED=()` — 모든 `plugins/*/agents/*.md` frontmatter 에 model 키가 없어야 한다(사용자 결정 「세션 모델을 따른다」, `flexibility-audit.md`). 단언 0(스윕이 10개 이상을 열었다)은 그대로. 머리 주석의 「qg v10 재결정 R3」을 R2a 결정으로 고친다.
- `test_agent_model_mutation.sh` (g): qg agent 에 `model: opus` 를 더한 사본에서 스윕이 RED.
- `test_security_reviewer_persona.sh:51` · `test_code_recritic_frontmatter.sh:20,35`: model 키가 **없다**는 단언으로.
- 새 단언(`test_security_reviewer_persona.sh`):

```bash
P="$PLUGIN_ROOT/agents/security-reviewer.md"
assert_file_grep "$P" 'when its cause is this change' "Severity: 원인이 이 변경이면 diff 밖 위치도 보고(AC27)"
assert_file_grep "$P" 'a location outside the diff is fine when the cause is this change' "Forbidden: 같은 범위"
assert_file_absent "$P" "No findings outside the diff's actual code changes" "옛 「바뀐 코드만」 문장이 없다"
assert_file_grep "$P" 'Do not report hardening for code whose behavior this change did not affect' "hardening 금지는 남는다(약화 아님 — 양성 짝)"
assert_file_grep "$P" '^tools: Read, Grep, Glob$' "도구 allowlist 그대로"
assert_file_grep "$P" 'you have no web tools' "웹 금지 문장 그대로"
assert_contains "$(cat "$SK")" 'Report findings this change caused — the location may be outside the diff when the cause is this change.' "SKILL 외부 리뷰어 프롬프트도 같은 범위"
```

`test_skill_run_contract.sh:194` 의 문장 단언을 새 문장으로.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `for t in test_agent_model_unpinned_sweep test_agent_model_mutation test_security_reviewer_persona test_code_recritic_frontmatter test_skill_run_contract; do printf '%s ' $t; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done`
Expected: 뒤집은 단언 ✗.

- [ ] **Step 3: persona · SKILL · README 를 고친다**

위 Interfaces 의 글자 그대로 바꾼다. README 의 `model: opus` 서술과 `CLAUDE_CODE_SUBAGENT_MODEL` 예시 절은 「qg 리뷰 agent 는 모델을 고정하지 않는다 — 세션 모델을 따른다」로.

- [ ] **Step 4: 통과를 본다**

Run: Step 2 + `bash plugins/quality-gates/tests/test_agent_frontmatter_keys.sh | tail -1; bash plugins/quality-gates/tests/test_law2_prose.sh | tail -1; (cd plugins/quality-gates/tests && python3 -m unittest -q test_security_reviewer_behavior)`
Expected: 실패 0. 변이: security-reviewer 에 `model: opus` 를 되살린 사본에서 스윕 ✗.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(qg): 리뷰어 모델 고정을 풀고 범위 문장을 「원인이 이 변경이면 보고」로" -- plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/code-recritic.md plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/README.md <고친 테스트 경로들>
```

---

### Task 11: e2e 여러 선택 · 토픽 · 범위 trivia · 조사용 실행 표시 (AC28)

**Files:**
- Modify: `plugins/quality-gates/references/e2e.md` §2(:34-46 — multiSelect), §5(걷기마다 게이트 · 여러 시나리오 순서), §6(e2e 칸 합치기)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — `### Trivia escape`(:154-168), `## e2e` E0 의 `e2e-gate rc=0` 줄(:754-755) · E4 (여러 시나리오)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md:127-131` (D2 의 「D3/D4 밖에서 스위트를 돌리지 않는다」)
- Test: `plugins/quality-gates/tests/test_e2e_docs.sh` · `test_differential_procedure.sh` · trivia 를 잡는 테스트(`grep -rln 'trivia escape 를 \*\*쓰지 않고\*\*\|선언이 있으면 trivia' plugins/quality-gates/tests`)

**Interfaces:**
- Produces: 조사용 실행 표시 줄 `> [quality-gates] 조사용 실행 — 판정에 안 씀: <명령>`. trivia 공시 줄 `작은 수정이라 파이프라인을 건너뛰었다(trivia diff — <토픽 전체 | 범위 전체>) — <한 문장 설명>.`

- [ ] **Step 1: 실패하는 락을 쓴다**

```bash
E="$PLUGIN_ROOT/references/e2e.md"
assert_file_grep "$E" 'multiSelect: true' "e2e 질문은 여러 선택이다(AC28)"
assert_file_absent "$E" '질문 하나, 단일 선택이다' "옛 단일 선택 문장이 없다"
assert_file_grep "$E" 'fail` > `미확인` > `pass`' "여러 시나리오의 e2e 칸은 가장 나쁜 결과"
TR="$(awk '/^### Trivia escape$/{f=1;next} f&&/^## Review$/{exit} f' "$SK")"
assert_contains "$TR" '토픽 전체' "토픽 diff 전체가 trivia 면 우회한다(AC28)"
assert_contains "$TR" 'review-i1.full.diff' "토픽 · 범위의 trivia 판단은 iteration 1 의 거르기 전 diff 전체로"
assert_contains "$TR" 'declaration-invalid' "선언이 깨졌으면 여전히 trivia 우회가 없다(음의 짝)"
DT="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
assert_file_absent "$DT" 'D3/D4 밖에서 스위트를 돌리지 않는다' "조사용 실행 금지 문장이 없다"
assert_file_grep "$DT" '조사용 실행 — 판정에 안 씀' "조사용 실행 표시 줄"
assert_file_grep "$DT" 'DISABLE_DIFFERENTIAL_TEST=1` 이면 조사용 실행도' "kill switch 는 조사용 실행도 막는다(보안 — 양성 짝)"
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/quality-gates/tests/test_e2e_docs.sh | tail -3; bash plugins/quality-gates/tests/test_differential_procedure.sh | tail -3`
Expected: 새 단언 ✗.

- [ ] **Step 3: 문면을 고친다**

- `e2e.md` §2: 「`AskUserQuestion` 질문 하나, 여러 선택(`multiSelect: true`)이다. 선택지는 넷을 넘지 않는다.」 · 「시나리오를 하나 이상 고르면 고른 시나리오만 걷는다 — 「안 한다」 · 「걸을 것 없음」을 함께 골랐어도 그렇다. 시나리오를 고르지 않았으면 고른 다른 선택지로 닫는다.」 · 고른 시나리오마다가 그 명령 실행 승인이다. §5: 「고른 시나리오를 번호 순으로 하나씩 걷는다 — 시나리오마다 SKILL 의 E1~E5 를 돌고 걷기마다 게이트를 띄운다. fail 게이트에서 「고치고 다시 돌기」를 고르면 루프가 돌아온 뒤 고른 시나리오 전부를 다시 걷는다.」 §6 끝: 「여러 시나리오를 걸었으면 판정 줄의 e2e 칸은 가장 나쁜 결과다 — `fail` > `미확인` > `pass`. 「사람이 뒤집음」은 그 칸을 정한 걷기가 뒤집혔을 때다.」
- SKILL Trivia escape: 「선언이 있으면 trivia escape 를 쓰지 않는다」 문단을 — `status: ok`(토픽)와 범위 모드는 이 자리에서 판단하지 않고 iteration 1 의 Step 1c 뒤에 `$RD/review-i1.full.diff`(거르기 전 diff 전체)를 보고 판단한다. 토픽 · 범위 diff 전체가 한 문장으로 설명되면 위 공시 줄을 내고 trivia 펜스로 간다. `declaration-invalid` 면 지금처럼 trivia 우회를 쓰지 않는다(토픽 전체를 볼 수 없다).
- SKILL `## e2e` E0 의 rc=0 줄 · E4: 여러 시나리오 순서와 칸 합치기를 e2e.md 로 가리킨다.
- `differential-test.md` D2: 「D3/D4 밖에서 스위트를 돌리지 않는다.」 → 「D3/D4 밖에서 스위트나 테스트를 돌릴 수 있다 — 원인을 찾는 조사용이다. 돌리기 전에 `> [quality-gates] 조사용 실행 — 판정에 안 씀: <명령>` 한 줄을 내고, 결과를 배정 · 행 파일 · D5 · 합성기에 넣지 않는다. `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이면 조사용 실행도 하지 않는다 — 저장소 코드를 호스트에서 돌리기 때문이다.」

- [ ] **Step 4: 통과를 본다**

Run: `for t in test_e2e_docs test_differential_procedure test_topic_scope_wiring test_one_pipeline_surface; do printf '%s ' $t; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done`
Expected: 실패 0.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(qg): e2e 여러 선택 · 토픽과 범위 전체가 trivia 면 우회 · 조사용 실행은 표시하고 판정에 안 씀" -- plugins/quality-gates/references/e2e.md plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md <고친 테스트 경로들>
```

---

### Task 12: artifact-critique — 여러 대상 · 지적만 받기 · 라운드 열기 · 비평자 수 (AC29 · 미룸)

**Files:**
- Modify: `plugins/quality-gates/skills/artifact-critique/SKILL.md` — frontmatter `description`(:3-10), E0(:64-68 옛 모드 이름), E1(:70-81 여러 대상), E2 · E2b(:83-107 지적만 받기로 넘어가는 선택지), E3(:131-145 모드 · 비평자 수), 루프 머리(:147-150), 1(:152-163 비평자 k 명), 2.5(:198-204), 3 의 egress 문장(:206-209), 5~9(:240-287 지적만 받기는 건너뜀 · 상한에서 사용자가 엶), 종료 요약(:289-296 대상마다)
- Test: `plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh` · `test_artifact_bounds.sh` · `test_artifact_critique_truths.sh` · `test_cost_consent.sh`

**Interfaces:**
- Consumes: `synthesize_artifact_findings.py --phase key --findings <파일>…`(이미 여러 개를 받는다) · `artifact_max_rounds.sh`(그대로).
- Produces: 라운드 시작 공시 줄 `> [quality-gates] 라운드 <N> (<대상>) — 비평자 <k>명(기본 1명) · codex <부름 | 안 부름(<사유>)> · 반박자 1명`. 추가 라운드 기록 줄(라운드 히스토리) `추가 라운드 승인: <label | typed> · <원문>`. 인자 `--findings-only` (지적만 받기).

- [ ] **Step 1: 실패하는 락을 쓴다**

```bash
A="$PLUGIN_ROOT/skills/artifact-critique/SKILL.md"
assert_file_grep "$A" '지적만 받기' "읽기 전용 모드(AC29)"
assert_file_grep "$A" '편집 · 커밋을 하지 않는다' "지적만 받기는 커밋하지 않는다"
assert_file_grep "$A" '대상이 여럿' "여러 대상"
assert_file_grep "$A" '비평자 <k>명\(기본 1명\)' "라운드마다 기본값과 쓴 수를 공시"
assert_file_grep "$A" '라운드마다 비평자를 몇 명' "사용자가 그 자리에서 비평자 수를 정한다"
assert_file_grep "$A" '한 번 더 돌기' "라운드 상한에서 사용자가 연다"
assert_file_absent "$A" 'critique skipped|critique mode disabled' "옛 모드 이름이 kill switch 메시지에 없다(미룸)"
assert_file_absent "$A" '그 파일로 고정' "egress 문장은 경로를 고정한다고 말한다(미룸)"
assert_file_grep "$A" '그 경로로' "egress 문장 양성 짝"
# 음성 검사는 고정 문구가 아니라 실제 tools 줄과 대조한다(미룸)
tools="$(sed -n 's/^tools: //p' "$PLUGIN_ROOT/agents/artifact-adversarial.md")"
assert_contains "$(cat "$A")" "\`tools: ${tools}\`" "egress 문장이 adversarial 의 실제 tools 줄을 그대로 인용한다"
awk 'length > 160 {print FILENAME": "FNR}' "$A" | grep -q . && no "artifact-critique 에 160자 넘는 줄" || ok "긴 줄 없음"
```

(`test_artifact_critique_truths.sh` 의 기존 고정 문구 음성 검사를 위 `tools:` 대조로 바꾼다. 160자 단언은 표 줄 · 펜스 줄이 이미 넘으면 egress 문단 창으로 좁힌다.)

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `for t in test_critiquing_artifacts_skill test_artifact_bounds test_artifact_critique_truths test_cost_consent; do printf '%s ' $t; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done`
Expected: 새 단언 ✗.

- [ ] **Step 3: SKILL 을 고친다**

- description: 「one or more NON-CODE artifacts」 · 「fixes and commits each round, or a read-only findings-only pass」.
- E0: `> [quality-gates] artifact-critique 를 건너뛰었다 — quality-gates 전체가 꺼져 있다(DEVBREW_QUALITY_GATES_DISABLE=1).` · `> [quality-gates] artifact-critique 를 건너뛰었다 — DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1 이 켜져 있다.`
- E1: 인자의 경로가 여럿이면(대상이 여럿) 전부 대상이다. 대상마다 분류하고 `code` 인 대상은 그 대상만 빼고 알린다(남은 대상이 0 이면 종료). 모드: 인자에 `--findings-only` 가 있거나 요청이 지적만 원하면 「지적만 받기」, 아니면 「고치며 돌기」.
- E2 · E2b: 「고치며 돌기」에서 멈추는 조건(detached · 기본/보호 브랜치 · untracked · 커밋 안 된 변경)이면 지금 안내 줄 뒤에 `AskUserQuestion` — 「지적만 받기로 진행」(편집 · 커밋 없이 한 라운드 지적만) · 「멈추기」. 「지적만 받기」는 E2 의 `project_dir:` 만 쓰고 `branch_ok` · E2b 를 요구하지 않는다. E2c(경로 인가)는 두 모드 모두 대상마다.
- E3: 질문 둘 — (1) 지금 질문에 대상 목록 · 모드 · 상한을 싣고 선택지에 「지적만 받기로 바꾸기」를 더한다(지적만 받기면 「고치며 돌기로 바꾸기」 — 그때 E2 · E2b 를 다시 돈다). (2) `라운드마다 비평자를 몇 명 부를까요?` — 「1명 (권장)」 · 「2명」 · 「3명」, 기타 칸에 다른 수.
- 루프 머리: 「라운드당 디스패치는 기본 3(비평자 1 · codex 가용 시 1 · 반박자 1)이다 — 비평자 수는 E3 에서 정했다.」 · 라운드 시작마다 위 공시 줄. 대상이 여럿이면 대상마다 이 루프를 차례로 돈다(대상마다 라운드 · 커밋 · 상한).
- 1: 비평자 k 명을 나란히 dispatch 하고 각자 `critic-<i>.yaml`. 2.5: `--findings critic-1.yaml … --findings critic-k.yaml [--findings codex.yaml]`.
- 3 의 egress 문장(두 줄로): 「`project_dir` + E2c 가 인가한 `canonical`(raw `<path>` 아님)을 스레딩한다. adversarial 은 egress 도구가 없다(`tools: Read, Grep, Glob`) — 그래도 산출물을 read 하므로 E2c 가 인가한 그 경로로 읽게 critic · codex 와 같은 canonical 을 넘긴다.」
- 지적만 받기: 4(synthesize) 뒤 남은 `kept` 를 보고하고 끝낸다 — 5~9 와 편집 · 커밋을 하지 않는다(종료 사유 `findings_only`).
- 상한: `effective_max_rounds` 에 닿았는데 수렴하지 않았으면 `AskUserQuestion` — 「한 번 더 돌기」(라운드 하나를 더 연다 — 그 끝에 다시 묻는다) · 「여기서 끝내기」. 기타 칸의 글이 더 여는 뜻이면 같은 길. 연 승인은 라운드 히스토리에 위 기록 줄로.
- 종료 요약: 대상마다(라운드 히스토리 · 종료 사유 · 잔여 kept), 종료 사유 목록에 `findings_only`.

- [ ] **Step 4: 통과를 본다**

Run: Step 2 + `bash shared/tests/test_dispatch_disposition.sh | tail -1; bash shared/tests/test_invocation_surface.sh | tail -1`
Expected: 실패 0.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(qg): artifact-critique 여러 대상 · 지적만 받기 · 상한에서 사용자가 엶 · 비평자 수 공시" -- plugins/quality-gates/skills/artifact-critique/SKILL.md <고친 테스트 경로들>
```

---

### Task 13: 범위 모드를 버릴 레포에서 실제 명령으로 걷는다 (AC30 · AC21 · AC22)

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r2a-plan3/range-walk.sh` · `range-walk.md` (레포 밖 — 기록)

- [ ] **Step 1: 걷기 스크립트를 쓴다**

`range-walk.sh` 가 `$HOME/.claude/sdd-mirror/r2a-plan3/tmp/range-walk/` 아래(매번 새 하위 폴더)에: 맨 저장소 origin(기본 브랜치 `trunk`) · 그 클론 R · R 에서 커밋 c0(base) · c1(설계문서 A + 코드 + `tests/test_calc.sh` 100755, 트레일러 `Spec: docs/a-design.md`) · c2(설계문서 B + 코드 회귀 하나, 트레일러 `Spec: docs/b-design.md`) · push. R 을 c0 에 detached 로 둔다(끝 ≠ 체크아웃). 이 레포의 qg 스크립트를 절대 경로로 차례로 부르고 각 출력을 `range-walk.md` 에 그대로 붙인다: `setup-qg.sh --session-id walk$$ range <c0>` → `resolve-range.sh --out <RD>/range-scope.txt -- range <c0>` → `discover-spec.sh --intent-out <RD>/intent.md --range <c0> <c2>` → `review-diff.sh --dir <RD> --iter 1 --mode range --scope-file <RD>/range-scope.txt` → `qg-worktree.sh memo-init` → `create-baseline <c0>` · `create-head <c2> --range` → `compute-test-scope-candidates.sh --topic <c0> <c2>` → `run-test-selection.sh assign` · 두 축 `run` → `diff-test-results.py` → `verdict.py --line … --sha <c2 짧은 id>` → 트리 정리 · `memo-drop`.

- [ ] **Step 2: 걷고 기대와 대조한다**

Run: `bash "$HOME/.claude/sdd-mirror/r2a-plan3/range-walk.sh"`
Expected(`range-walk.md` 끝의 대조 표에 적는다): range-scope 의 `end_from: origin/HEAD` · `end_ref: refs/remotes/origin/trunk` · `head_is_end: no`; `specs` 2개(a → b 순); review-diff `base` = c0 · `head` = c2; 후보에 `tests/test_calc.sh`; 차등에서 c2 의 회귀가 `NEW_REGRESSION`; 판정 줄 커밋 = c2. 하나라도 다르면 해당 Task 로 돌아간다.

- [ ] **Step 3: 대화형 걷기를 사람 몫으로 적는다**

`range-walk.md` 에 「미검증 — 대화형 세션에서 같은 버릴 레포로 `/quality-gates:quality-pipeline range <c0>` 를 불러 P2b 한 줄 · 의도 줄(설계문서 2개) · 게시 안 함 줄을 본다(헤드리스는 Skill 진입을 못 잰다)」를 적는다 — PR 본문 확인 항목이다. 커밋 없음(기록은 레포 밖).

---

### Task 14: persona 편집을 보안 리뷰에 올린다 (AC27)

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r2a-plan3/persona-security-review.md` (레포 밖 — 원문 기록), `pr-body-security.md` (PR 본문 절 초안)

- [ ] **Step 1: persona diff 를 만든다**

Run: `git diff "$(cat "$HOME/.claude/sdd-mirror/r2a-plan3/before.base")"..HEAD -- plugins/quality-gates/agents plugins/quality-gates/references/review-criteria.md > "$HOME/.claude/sdd-mirror/r2a-plan3/persona.diff"; wc -l "$HOME/.claude/sdd-mirror/r2a-plan3/persona.diff"`
Expected: security-reviewer · code-recritic · review-criteria 세 파일의 hunk 만.

- [ ] **Step 2: 보안 리뷰어를 따로 부른다**

`quality-gates:security-reviewer`(`tools: Read, Grep, Glob` — 웹 도구 없음)를 그 diff 와 판단 근거와 함께 dispatch 한다:

```text
Agent({
  subagent_type: "quality-gates:security-reviewer",
  // **처분** — consumer=human · fail-closed · disclosure=PR 본문 「보안 리뷰」 절
  description: "R2a 계획 3 persona diff 보안 리뷰",
  prompt: "project_dir: <project_dir><레포 루트 절대 경로></project_dir>
    diff_scope: <diff_scope>paths</diff_scope>
    intent: <intent>persona 편집 — 판단 근거: (1) model: opus 두 줄 삭제는 모델 핀 제거(사용자 결정 「세션 모델을 따른다」)이고 tools allowlist · 웹 금지는 그대로 (2) 범위 문장은 「diff 안만」에서 「원인이 이 변경이면 diff 밖 위치도」로 넓혔고 hardening 금지는 남겼다 — 약화가 아니라 범위 확장 (3) code-recritic 은 lower 근거가 사용자에게 보인다는 문장만 더했다 (4) review-criteria 는 여러 설계문서일 때 근거 문서 · AC 를 다는 한 줄을 더했다</intent>
    criteria: <criteria><references/review-criteria.md 내용></criteria>
    iteration: <iteration>1</iteration>
    filtered_diff: <filtered_diff><persona.diff 내용></filtered_diff>"
})
```

- [ ] **Step 3: 결과를 기록하고 처리한다**

응답 원문을 `persona-security-review.md` 에 붙인다. CRITICAL · IMPORTANT 가 있으면 Task 10(또는 9 · 3) 구현자에게 고침을 보내고, 고친 뒤 Step 1~2 를 다시 돌린다(라운드 2 에서도 같은 자리에 새 block 이면 멈추고 지휘자에게 알린다). `pr-body-security.md` 에 「## 보안 리뷰」 절 초안 — 대상 파일 · 판단 근거 넷 · 리뷰어 결과 요약(지적 수 · 처리) · 「머지 전 사용자 확인 항목」 한 줄. 커밋 없음.

---

### Task 15: 버전 · CHANGELOG · README · 스위트 대조 · 처분표 닫힘 (AC36 · AC37)

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (`"version": "14.1.0"` — 임시, `description` 은 바꾸지 않는다)
- Modify: `plugins/quality-gates/CHANGELOG.md` (맨 위 `## [14.1.0] — <머지 날짜>`)
- Modify: `plugins/quality-gates/README.md` — `## 인스턴스화한 원칙`(한 줄) · `## 쓰는 법` · `## 범위`(range) · `## 의도 출처`(설계문서 여럿) · `## 설정`(`DEVBREW_QUALITY_GATES_DOC_PATHS`) · artifact-critique 서술(여러 대상 · 지적만 받기)
- Create: `$HOME/.claude/sdd-mirror/r2a-plan3/ac-report.md` (레포 밖 — AC 보고 · 인계)

- [ ] **Step 1: README · CHANGELOG · 버전을 쓴다**

CHANGELOG `## [14.1.0] — <머지 날짜>`(머지 날짜는 머지 직전에 채운다 — 임시로 오늘 날짜): **Added** — `range <시작>[..<끝>]` 범위 모드(끝 생략 시 `origin/HEAD`, 게시 없음) · 새 스크립트 `resolve-range.sh` · `review-diff.sh` · `doc_paths.py` · 환경 변수 `DEVBREW_QUALITY_GATES_DOC_PATHS`(기본 `README*` · `CHANGELOG*`, 빈 값은 아무것도 빼지 않음, 이 변경이 설정을 바꾸면 기본으로) · 「낮춘 지적」 절과 되올리기 · artifact-critique 의 여러 대상 · 지적만 받기(`--findings-only`) · 비평자 수. **Changed** — 범위 안 `Spec:` 트레일러를 전부 의도로(`specs`) · 리뷰어 상한 8 과 같은 반복 재호출 금지를 지우고 규모를 시작 · 끝 두 줄로 공시 · 수정 루프 상한(기본 5)에서 사용자가 한 번씩 더 엶 · 리뷰어 모델 고정(`model: opus`)을 풀어 세션 모델을 따름 · 「원인이 이 변경이면 diff 밖도 보고」 · e2e 여러 선택 · 토픽 · 범위 전체가 trivia 면 우회 · 조사용 실행은 표시하고 판정에 안 씀 · `--paths` 는 바뀐 파일 ∩ glob · 걸러진 diff 가 비면 `not-certified (scope-empty)` · artifact-critique 상한에서 사용자가 엶. **Fixed** — `setup-qg.sh` 의 `critique` 안내가 인자 위치 · kill switch 와 무관하게 같다 · artifact-critique 의 옛 모드 이름 · egress 문장. README `## 인스턴스화한 원칙` 에 「P18 — 루프 상한은 남기고 넘는 길은 사용자 승인 하나(수정 루프 · 문서 비평 라운드)」 한 줄. 설정 절은 Task 4 Step 5 의 실측 결과(설정 `env` 가 실리는지)를 따른다.

Run: `bash shared/tests/test_changelog_integrity.sh | tail -1; bash shared/tests/test_plugin_description_parity.sh | tail -1; bash plugins/quality-gates/tests/test_plain_readme.sh | tail -1`
Expected: 실패 0.

- [ ] **Step 2: Commit**

```bash
git commit -m "chore(qg): R2a 계획 3 — 버전 14.1.0(임시) · CHANGELOG · README" -- plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/quality-gates/README.md
```

- [ ] **Step 3: 스위트를 기준과 대조한다(AC36)**

`git fetch origin` 뒤 origin 기본 브랜치가 Task 0 의 기준에서 움직였으면 merge 하고(`git merge origin/HEAD` — rebase 금지) 움직인 기준에서 Task 0 의 스크립트로 `before2` 를 다시 잰다(버릴 클론에서). 그다음:
Run: `bash "$HOME/.claude/sdd-mirror/r2a-plan3/baseline.sh" "$HOME/.claude/sdd-mirror/r2a-plan3/after"; comm -13 <(cut -f2- "$HOME/.claude/sdd-mirror/r2a-plan3/before.names" | sort -u) <(cut -f2- "$HOME/.claude/sdd-mirror/r2a-plan3/after.names" | sort -u)`
Expected: 새 실패 이름 0(선재 RED 는 이름 집합으로만 비교). 하나라도 있으면 그 실패를 낸 Task 로 돌아간다.

- [ ] **Step 4: AC 보고와 인계를 쓴다(AC37)**

`ac-report.md`: AC21~AC30 · AC36 · AC37 마다 「구현됨 — <커밋 · 테스트 이름>」 또는 「미룸 — <이유 · 받는 곳>」. 위 「§1 처분표 닫힘」 표를 커밋 id 와 함께. `new-devices.md` 의 새 장치 — 계획 2 가 머지됐으면 origin 기본 브랜치를 merge 한 뒤 설계문서 §1 에 행으로 더하고 커밋한다(`docs(r2a): 계획 3 이 찾은 장치를 처분표에`), 아직이면 보고에 「계획 2 머지 뒤 §1 에 더함」으로 남긴다. 인계: (1) R5 끝 단계 호출 꼴 `/quality-gates:quality-pipeline range <로드맵 시작 커밋>` — 지휘자가 R5 에 알린다(설계 `## 미룸` 의 R5 행). (2) 로드맵 R2a 블록 `브랜치:` 에 `feature/shared-review-engine-qg` 를 로드맵 PR 로 더한다(§10). (3) 버전 14.1.0 은 임시 — 계획 2 의 qg patch 와 함께 머지 직전에 다시 정한다. (4) PR 본문에 `pr-body-security.md`(Task 14) · Task 13 의 대화형 미검증 항목 · Task 4 Step 5 실측 결과를 싣는다. (5) 받는 계획이 정해지지 않은 R2a 미룸 두 행(「설계에 없던 결정」 14)은 끝 확인에서 받는 곳을 정한다.
