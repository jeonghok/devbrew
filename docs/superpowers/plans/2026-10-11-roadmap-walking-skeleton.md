# R0 — 로드맵 · 조각 묶음 · 상태 계산의 걷는 뼈대 Implementation Plan

> 이후 이름 변경(설계문서 결정 기록 B12 · B13): 조각 → 에픽, `slice-bundle` → `epic-bundle`, `slice:` → `epic:`, `## 조각` → `## 에픽`, R5 브랜치 `feature/epic-conductor`. 이 계획의 코드 · 픽스처를 다시 쓸 때는 새 이름을 쓴다.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이번 일의 로드맵 한 장과 조각 묶음 열 개를 레포에 두고, 그 형식을 실제로 지나가는 읽기 전용 스크립트 둘(상태 계산 · 번호 대조)과 실측 · 락 지도 · 충돌표를 R0 PR 하나로 낸다.

**Architecture:** `check_bundle_coverage.py` 가 번호 토큰 문법 · 묶음 `ids:` · spec `## 번호 대조` 표를 읽는 문자열 함수를 내놓고, `roadmap_status.py` 가 그것을 import 해 `origin/main`(또는 `--roadmap-file` 의 작업 트리) 사본의 로드맵 · 묶음 · brief 와 git 이력에서 조각마다 단계와 경고를 계산한다. 로드맵과 묶음은 손으로 정한 배정 표를 버리는 조립기로 펼쳐 만들고, 원문은 바이트 그대로 옮긴다.

**Tech Stack:** Python 3.9 표준 라이브러리(레포의 `python3` 가 `/usr/bin/python3` 3.9.6) · git CLI · bash 테스트(`shared/tests/assert.sh`).

**Spec:** `docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md`

**작업 위치:** 모든 경로는 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-explore-decompose` 기준이다(브랜치 `feature/interview-explore-decompose`). subagent 에게는 이 절대경로를 못 박아 넘긴다 — 같은 이름의 파일이 main 레포에도 생길 수 있다.

**코드는 미리 돌려 봤다.** Task 2 · 3 · 4 의 스크립트 · 테스트 · 로드맵 · 조립기는 2026-10-11 에 이 레포 사본에서 실행해 확인한 그대로다: `test_bundle_coverage.sh` 22/22 · `test_roadmap_status.sh` 67/67 · 실데이터 절 11/11, 실제 레포 git 에서 P1 · P2 머지됨 판정 확인. 리뷰어에게는 「계획이 쓴 코드」라고 밝혀 덜 검사받지 않게 한다.

## Global Constraints

- N1. 사용자 원문은 다시 치지 않는다. 묶음 §6 은 `section6.py` 로 brief §6 과 audit §6 에서 바이트 그대로 옮긴다.
- N2. 두 스크립트는 읽기만 한다. 파일을 쓰지 않고 네트워크에 나가지 않는다.
- N3. 검사 불가를 이상 없음으로 내지 않는다(종료 코드 3).
- N4. git 만 쓴다. `gh` 와 실행 기록은 읽지 않는다(B6).
- N5. 로드맵은 사용자 승인 뒤에만 커밋으로 고친다. 이력은 git 과 로드맵 「재분해 이력」 절이다.
- N6. 버전은 머지 직전에 정한다(spec-distill minor).
- Python 3.9 에서 돌아야 한다 — `from __future__ import annotations`, `match` · 런타임 `X | Y` 금지.
- `plugins/spec-distill/scripts/*.py` 의 `re.compile` 리터럴이 `## 6. 사용자 원문` 의 맨 앞에서 3글자 이상 맞으면 안 된다(`tests/test_check_brief.sh` §6단일화 락). §6 은 `section6.body` 로만 읽는다.
- `open(` · `.read_text(` 는 `encoding="utf-8"` 을 같은 호출에 적는다(`plugins/quality-gates/tests/test_utf8_explicit.py`). `plugins/**/*.py` 에 `"python3"` 문자열 리터럴을 두지 않는다(`shared/tests/test_python_floor.sh`).
- 옛 이름 토큰이 새 파일(스크립트 · 테스트 · README · `docs/superpowers/roadmaps/**`)에 없어야 한다(`plugins/spec-distill/tests/test_review_hook_removed.py`). audit §5 에는 `review-dispatch` 가 있으나 묶음은 audit §6 만 옮기므로 걸리지 않는다.
- 20줄 넘는 같은 블록을 두 파일에 두지 않는다(`shared/tests/test_no_new_duplication.sh`) — 픽스처 빌더는 `test_roadmap_status.sh` 한 곳.
- 새 테스트 파일은 실행 비트(100755)로 커밋한다 — qg 셸 어댑터가 비트 없는 테스트를 맡지 않는다.
- `plugin.json` 의 `description` 은 바꾸지 않는다(마켓플레이스 사본과 같아야 한다). CHANGELOG 새 머리는 main 버전의 바로 다음 minor 다(`shared/tests/test_changelog_integrity.sh` — 건너뛰면 RED).
- diff 에 외부 플러그인 파일과 @ 브랜치의 네 파일(`plugins/spec-distill/skills/spec-interview/references/finishing.md` · `plugins/spec-distill/references/proceed-gate.md` · `plugins/spec-distill/skills/spec-review/SKILL.md` · `plugins/spec-distill/skills/request-framing/SKILL.md`)이 없다(AC10).
- 커밋: Conventional Commits, 설명은 한국어, `type`·`scope` 는 영어, pathspec 으로 커밋(`git commit -- <경로>`), 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. bare `git stash` 금지. `gh pr merge` 는 사용자가 한다. devbrew 에서 fable 모델을 쓰지 않는다.
- 셸 테스트는 리포 루트에서 `bash <파일>` 로 돈다. `PYTHONDONTWRITEBYTECODE=1`.

## Review Focus

1. 머지 뒤 로컬 브랜치를 main 으로 앞당겨 브랜치 끝이 머지 커밋 자신인 경우(실제 레포 `feature/plain-language-voice` 가 이 모양) → 머지됨이어야 한다. 설계 §4 2 의 메시지 규칙은 「지운 브랜치」만 말해 그대로 구현하면 「설계 중」이 나온다 — Task 3 이 규칙을 「지웠거나, 남은 끝이 main 에 다 들어 있음」으로 넓히고 Q1 픽스처로 잡는다(사용자 확인이 필요한 설계 변경 — Task 7 이 설계문서에 반영). 머지 뒤 커밋이 더 붙은 브랜치(Y1)는 그대로 머지됨이 아니다.
2. 비UTF-8 로캘(`LC_ALL=C`)에서 사람용 출력 → 한국어가 깨지지 않고 같은 종료 코드. Task 3 테스트가 잰다.
3. 한글 · 공백이 든 경로(경로 예약 · 바뀐 파일) → 이스케이프 없이 대조한다(`core.quotePath=false` · `-z`). Task 3 테스트가 잰다.
4. partial clone 에서 빠진 객체 → 읽기 명령이 네트워크로 받으러 나가지 않는다(`GIT_NO_LAZY_FETCH=1`). Task 3 테스트가 그 설정의 존재를 잰다.
5. 지휘 절차가 fetch 를 빠뜨려 `origin/main` 이 오래됨 → 출력 첫 줄에 받은 시각(`FETCH_HEAD` 시각)이 보인다. Task 3 테스트가 잰다.

## 「계획으로 넘김」 처분

설계문서 `### Deferred to plan` 의 행마다 이 계획에서 어디로 갔는지다.

| 행 | 처분 |
|---|---|
| 2e6610eb#r2.1 (AC7 확인 방법) | Task 3 테스트 5절 — AST 정적 검사(쓰기 호출 · 쓰기 모드 open · 네트워크 모듈 · git 밖 subprocess · 허용 밖 git) + 실행 전후 작업 트리 · `.git` · ref 비교, 둘 다 양성 대조 |
| ad0bba2e#r1.2 · 0ff3c716#r3.1 (배정 두 곳) | 설계에서 이미 「배정은 한 곳」으로 해소 — 할 일 없음 |
| faed160e#r1.1 · 9d7c2d9a#r1.1 · 00f4602b#r1.1 (실행 기록 · gh) | B6 으로 R5 에 감 — 할 일 없음 |
| 6bf61ec5#r2.1 (설계문서 커밋 브랜치) | 설계 §5 2 에서 해소 — 로드맵 지휘 절차 2 가 싣는다(Task 4) |
| 347952cd#r2.1 (걷기 끝점) | 설계 §7 에서 해소 — R1 걷기는 R0 머지 뒤 |
| eafb26b7#r2.1 (번호 토큰 문법) | Task 2 `parse_ids` |
| fb07a9c2#r2.1 (단계 순서) | Task 3 `compute` — 0 → 확인 · 결정 → 머지됨 → 브랜치 없음 → 계획 · 설계 중 |
| 214ceceb#r3.1 (§1 두 겹) | Task 4 조립기 · 실데이터 테스트 |
| fccf272b#r3.1 (§6 비교 기준) | 기준 하나로 정함: `section6.body(묶음) == section6.body(brief).rstrip("\n") + "\n\n" + section6.body(audit)` — Task 4 실데이터 테스트 |
| d9066335#r4.1 (문자열 함수 · 절 없음) | Task 2 `check(bundle_text, spec_text)`, `## 번호 대조` 절이 없으면 종료 코드 3 |
| e1b5b3be#r4.1 (Handoff Context) | Task 7 |
| 17563e51#r4.1 (R0 번호 대조 범위) | Task 4 — RC18 · RC35 · RC36 · RC72 를 R0 표에 더하고, RC71 → P1 · RC73 · RC77 → P2 · RC85 → P3 · RC81 → P4 블록 `항목:` 에. 「R0 블록 항목 · 발화 = R0 표 첫 칸」을 실데이터 테스트가 잰다 |
| 4라운드 참고 — 경로 예약 겹침 규칙 | Task 3 `overlaps` — 어느 쪽으로도 의존 경로가 없을 때만, `plugin.json` · `CHANGELOG.md` · `README.md` 는 뺀다 |
| 4라운드 참고 — 결정 기록 줄 문법 | Task 3 `parse_roadmap` · Task 4 로드맵 결정 기록 절: `- <블록> · <결정\|머지> · <YYYY-MM-DD> · 「원문」`, 인터뷰 뒤 발화는 새 S 번호 없이 원문 인용 |

## 파일 구조

| 파일 | 책임 |
|---|---|
| `plugins/spec-distill/scripts/check_bundle_coverage.py` | 번호 토큰 문법 · frontmatter · `## ` 절 본문(§6 제외) · 묶음 `ids:` · 번호 대조 표 · `check()` · CLI |
| `plugins/spec-distill/scripts/roadmap_status.py` | 읽기 전용 git 래퍼 · 사본(origin/main · 작업 트리) · 로드맵 파싱 · brief 번호 집합 · 단계 · 경고 · 출력 · CLI |
| `plugins/spec-distill/tests/test_bundle_coverage.sh` | 번호 대조 단위 · 변이 |
| `plugins/spec-distill/tests/test_roadmap_status.sh` | 픽스처 git 레포 단계 · 경고 · 읽기 전용 · 변이 + 실데이터 절 |
| `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` | 조각 블록 15 · 지휘 절차 · 결정 기록 · 재분해 이력 · 위험 번호표 |
| 같은 디렉토리 `R1.md` … `R9.md` · `R2a.md` | 조각 묶음 10 |
| 같은 디렉토리 `locks.md` · `measurements.md` | 락 지도 · 충돌표 / 실측 |

---

### Task 1: 출발 준비 — main 받기 · 기준 스위트 · brief · audit · 계획 커밋

**Files:**
- 커밋: `docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md` · `docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md` (AC12) · `docs/superpowers/plans/2026-10-11-roadmap-walking-skeleton.md` (이 계획 — 상태 계산이 R0 을 「계획」으로 읽는 근거)
- 만듦(레포 밖): `$HOME/.claude/sdd-mirror/r0-roadmap/baseline.sh` · `before.tsv` · `before.names`

**Interfaces:**
- Produces: 최신 main 이 merge 된 브랜치(spec-distill 5.2.0 이상) · 기준 실패 이름 집합 `before.names`

- [ ] **Step 1: 작업 트리 확인**

Run: `git status --porcelain`
Expected: 세 줄 — `?? docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md` · `?? docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md` · `?? docs/superpowers/plans/2026-10-11-roadmap-walking-skeleton.md`. 그 밖의 변경이 있으면 멈추고 보고한다.

- [ ] **Step 2: origin/main 을 merge 로 받는다(rebase 아님)**

Run: `git fetch origin` 다음 `git merge --no-edit origin/main`
Expected: 충돌 없음(2026-10-11 측정: `git merge-tree` 깨끗, main 이 53 커밋 앞섬 — P1 #199 · P2 #200 머지가 들어온다). 이어서 `grep '"version"' plugins/spec-distill/.claude-plugin/plugin.json` → `5.2.0` 이상. 충돌이 나면 멈추고 보고한다.

- [ ] **Step 3: 기준 스위트 스크립트를 쓴다**

`$HOME/.claude/sdd-mirror/r0-roadmap/baseline.sh`:

````bash
#!/usr/bin/env bash
# 스위트 전체를 돌려 테스트별 rc · 실패 줄 수와 실패 줄 이름을 남긴다. 리포 루트에서: bash baseline.sh <출력 접두>
set -u
out="$1"; : > "$out.tsv"; : > "$out.names"
run_capped() { perl -e 'alarm shift; exec @ARGV' 900 "$@"; }
for t in plugins/*/tests/test_*.sh shared/tests/test_*.sh; do
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

- [ ] **Step 4: 기준을 잰다(오래 걸린다 — 백그라운드로)**

Run: `bash "$HOME/.claude/sdd-mirror/r0-roadmap/baseline.sh" "$HOME/.claude/sdd-mirror/r0-roadmap/before"`
Expected: `before.tsv` 에 테스트마다 한 줄, `before.names` 에 실패 줄. rc 만이 아니라 실패 줄 이름 집합을 비교 기준으로 쓴다 — 이미 RED 인 파일 안의 새 실패는 rc 로 안 보인다.

- [ ] **Step 5: brief 와 audit 을 커밋한다**

```bash
git add -- docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md docs/superpowers/plans/2026-10-11-roadmap-walking-skeleton.md
git commit -m "docs(spec-distill): 집요한 탐색 · PM 분해 인터뷰의 brief · audit 과 R0 구현 계획을 커밋한다" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md docs/superpowers/plans/2026-10-11-roadmap-walking-skeleton.md
```

Expected: 커밋의 파일 수 3(`git show --stat HEAD`).

---

### Task 2: 번호 대조 검사 `check_bundle_coverage.py`

**Files:**
- Create: `plugins/spec-distill/scripts/check_bundle_coverage.py`
- Test: `plugins/spec-distill/tests/test_bundle_coverage.sh` (100755)

**Interfaces:**
- Consumes: 없음(`docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md` 의 실제 표를 양성 대조로 읽는다)
- Produces (Task 3 이 import 한다):
  - `class FormatError(ValueError)` — 검사 불가(종료 코드 3)
  - `parse_ids(cell: str) -> list` — 쉼표 · ` · ` 로 나눈 번호 토큰, 문법 밖 조각이 있으면 `FormatError`
  - `id_sort_key(token: str) -> tuple` — C · D · OQ · RC · K · ST · S · «key» 순
  - `frontmatter(text: str) -> dict` · `unquote(value: str) -> str`
  - `section_body(text: str, heading: str) -> str | None` — 펜스 밖 `## ` 절 본문, 둘 이상이면 `FormatError`, `## 6.` 은 `ValueError`
  - `bundle_ids(text: str) -> list` · `table_ids(spec_text: str) -> set`
  - `check(bundle_text: str, spec_text: str) -> dict` — `{"status": 0|1|3, "missing": [...], "extra": [...], "bundle_count", "table_count", "reason"}`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

````bash
#!/usr/bin/env bash
# check_bundle_coverage.py — 조각 묶음 ids 와 조각 spec 의 `## 번호 대조` 표를 맞추는 검사(R0 AC6).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_bundle_coverage.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
C="$S/check_bundle_coverage.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

cat > "$T/bundle.md" <<'MD'
---
type: slice-bundle
slice: R9
roadmap: docs/x/roadmap.md
source_brief: docs/x/brief.md
ids: [C1, D2, OQ3, RC4, K5, ST1, S7, «web-key»]
---

# R9 — 묶음
MD

table_spec() {  # table_spec <첫 칸들...> — 각 인자가 한 행의 첫 칸
  printf -- '---\nsource_interview: docs/x/R9.md\n---\n\n# 설계\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n'
  for cell in "$@"; do printf '| %s | 반영 | §1 |\n' "$cell"; done
  printf '\n## Metadata\n\n- 끝\n'
}

# 1. 이상 없음 — 한 칸에 번호 여럿(쉼표와 ` · ` 둘 다), «key» 포함
table_spec "C1 · D2" "OQ3, RC4" "K5" "ST1 · S7" "«web-key»" > "$T/ok.md"
out="$(python3 "$C" "$T/bundle.md" "$T/ok.md")"; rc=$?
assert_eq "$rc" "0" "빠진 번호 없음 → rc 0"
assert_contains "$out" "빠진 번호 없음 (묶음 번호 8개 · 표 번호 8개)" "이상 없음 줄이 두 수를 센다"

# 2. 빠진 번호 — 나열하고 rc 1
table_spec "C1 · D2" "OQ3" "K5" "S7" > "$T/miss.md"
out="$(python3 "$C" "$T/bundle.md" "$T/miss.md")"; rc=$?
assert_eq "$rc" "1" "빠진 번호 → rc 1"
assert_contains "$out" "빠진 번호 3개 — RC4 · ST1 · «web-key»" "빠진 번호를 묶음 순서대로 나열한다"

# 3. 묶음에 없는 번호가 표에 있으면 정보 줄(종료 코드는 바꾸지 않는다)
table_spec "C1 · D2" "OQ3, RC4" "K5" "ST1 · S7" "«web-key»" "C99" > "$T/extra.md"
out="$(python3 "$C" "$T/bundle.md" "$T/extra.md")"; rc=$?
assert_eq "$rc" "0" "표에만 있는 번호는 rc 를 바꾸지 않는다"
assert_contains "$out" "정보: 묶음에 없는 번호 1개가 표에 있다 — C99" "정보 줄"

# 4. 검사 불가(rc 3) — ids 없음 · 표 깨짐 · 절 없음 · 범위 표기 · 셋째 칸 빔 · 파일 없음
sed '/^ids:/d' "$T/bundle.md" > "$T/noids.md"
out="$(python3 "$C" "$T/noids.md" "$T/ok.md")"; rc=$?
assert_eq "$rc" "3" "ids 없음 → rc 3"
assert_contains "$out" "번호 대조 검사 불가 — 묶음 frontmatter 에 ids 가 없다" "ids 없음 사유"
sed 's/^## 번호 대조$/## 다른 절/' "$T/ok.md" > "$T/nosec.md"
grep -q '^## 번호 대조' "$T/nosec.md" && no "양성 대조: 절 제거가 안 됐다" || ok "양성 대조: 픽스처에서 번호 대조 절이 사라졌다"
python3 "$C" "$T/bundle.md" "$T/nosec.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "\`## 번호 대조\` 절 없음 → rc 3 (표 깨짐과 같은 검사 불가)"
table_spec "K1~K7" > "$T/range.md"
python3 "$C" "$T/bundle.md" "$T/range.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "범위 표기 K1~K7 → rc 3 (토큰 문법 밖)"
printf -- '---\n---\n## 번호 대조\n\n| 번호 | 처리 | 자리 |\n|---|---|---|\n| C1 | 반영 | |\n' > "$T/empty3.md"
python3 "$C" "$T/bundle.md" "$T/empty3.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "셋째 칸이 비면 rc 3"
printf -- '---\n---\n## 번호 대조\n\n| 번호 | 처리 | 자리 |\n|---|---|---|\n| C1 | 했음 | §1 |\n' > "$T/badverb.md"
python3 "$C" "$T/bundle.md" "$T/badverb.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "둘째 칸이 반영/기각이 아니면 rc 3"
python3 "$C" "$T/bundle.md" "$T/없는파일.md" >/dev/null; rc=$?
assert_eq "$rc" "3" "spec 파일 없음 → rc 3"
python3 "$C" "$T/bundle.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "인자 부족 → rc 2"

# 5. 펜스 안의 `## ` 줄은 절 경계가 아니다
{ printf -- '---\n---\n## 번호 대조\n\n```\n## 예시 제목\n```\n\n| 번호 | 처리 | 자리 |\n|---|---|---|\n'
  printf '| C1 · D2 · OQ3 · RC4 · K5 · ST1 · S7 · «web-key» | 반영 | §1 |\n'; } > "$T/fence.md"
python3 "$C" "$T/bundle.md" "$T/fence.md" >/dev/null; rc=$?
assert_eq "$rc" "0" "펜스 안 \`## \` 줄을 절 끝으로 읽지 않는다"

# 6. JSON 출력과 함수 경로(roadmap_status 가 쓰는 문자열 입력)
out="$(python3 "$C" --json "$T/bundle.md" "$T/miss.md")"
assert_contains "$out" '"missing": ["RC4", "ST1", "«web-key»"]' "JSON missing 필드"
out="$(cd "$S" && python3 -c '
import check_bundle_coverage as c, sys
b = open(sys.argv[1], encoding="utf-8").read(); s = open(sys.argv[2], encoding="utf-8").read()
print(c.check(b, s)["status"])' "$T/bundle.md" "$T/miss.md")"
assert_eq "$out" "1" "check(문자열, 문자열) 이 파일 없이 같은 판정을 낸다"

# 7. §6 은 section_body 로 읽지 않는다(section6.body 한 곳)
out="$(cd "$S" && python3 -c '
import check_bundle_coverage as c
try:
    c.section_body("## 6. 사용자 원문\n- x\n", "## 6.")
    print("READ")
except ValueError:
    print("REFUSED")')"
assert_eq "$out" "REFUSED" "section_body 가 §6 읽기를 거부한다"

# 8. 실데이터 양성 대조 — R0 설계문서의 번호 대조 표가 파싱된다(손으로 쓴 실제 표)
R0_SPEC="$ROOT/docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md"
out="$(cd "$S" && python3 -c '
import check_bundle_coverage as c, sys
ids = c.table_ids(open(sys.argv[1], encoding="utf-8").read())
print(len(ids), "C25" in ids, "D26" in ids, "S51" in ids)' "$R0_SPEC" 2>&1)"
assert_grep "$out" "^[0-9]+ True True True$" "R0 설계문서 표가 한 칸 여러 번호까지 파싱된다: $out"

# 9. 변이 — 빠진 번호 판정을 지우면 2번 단언이 무너지는지(통과가 정답인 1번의 짝)
sed 's/return {"status": 1 if missing else 0,/return {"status": 0,/' "$C" > "$T/mut.py"
cmp -s "$C" "$T/mut.py" && no "변이가 적용되지 않았다" || ok "변이 적용됨"
cp "$S/section6.py" "$T/" 2>/dev/null
python3 "$T/mut.py" "$T/bundle.md" "$T/miss.md" >/dev/null; rc=$?
assert_eq "$rc" "0" "변이: status 를 0 으로 고정하면 빠진 번호가 rc 0 — 2번 단언에 이빨이 있다"
finish
````

Run: `chmod +x plugins/spec-distill/tests/test_bundle_coverage.sh`

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_bundle_coverage.sh`
Expected: FAIL — 스크립트가 없어 `can't open file …check_bundle_coverage.py` 로 대부분의 단언이 ✗.

- [ ] **Step 3: 구현한다**

````python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_bundle_coverage.py — 조각 묶음의 번호 집합과 조각 spec 의 `## 번호 대조` 표를 맞춘다.

명령줄: check_bundle_coverage.py <묶음.md> <spec.md> [--json]
종료 코드: 0 빠진 번호 없음 · 1 빠진 번호 있음 · 2 사용법 오류 ·
3 검사 불가(`ids:` 없음 · 표 깨짐 · `## 번호 대조` 절 없음 · 파일을 못 읽음).

`roadmap_status.py` 는 `check(bundle_text, spec_text)` 를 import 해 `git show` 로 읽은 글을 넘긴다.
읽기만 한다 — 파일을 쓰지 않고 네트워크에 나가지 않는다.
"""
from __future__ import annotations

import argparse
import json
import re
import sys

# 번호 한 개 — 확정 C/D · 열린 질문 OQ · 레포 근거 RC · 위험 K · steelman ST · 발화 S, 또는 «key».
TOKEN_RE = re.compile(r"(?:C|D|OQ|RC|K|ST|S)\d+|«[^«»,·\s]+»")
# 번호 여럿의 구분 — 쉼표 또는 ` · `. 범위 표기(`K1~K7`)는 토큰 문법에 맞지 않아 깨짐으로 친다.
SEP_RE = re.compile(r"\s*,\s*|\s+·\s+")
SEP_CELL_RE = re.compile(r":?-{3,}:?")
PREFIX_ORDER = ("C", "D", "OQ", "RC", "K", "ST", "S")
TABLE_HEADING = "## 번호 대조"


class FormatError(ValueError):
    """검사할 수 없는 입력 — 종료 코드 3."""


def parse_ids(cell: str) -> list:
    """번호 칸 하나를 토큰 목록으로. 문법에 맞지 않는 조각이 하나라도 있으면 FormatError."""
    cell = cell.strip()
    if not cell:
        raise FormatError("빈 번호 칸")
    out = []
    for piece in SEP_RE.split(cell):
        if not TOKEN_RE.fullmatch(piece):
            raise FormatError("번호 문법에 맞지 않는 토큰: %r" % piece)
        out.append(piece)
    return out


def id_sort_key(token: str):
    if token.startswith("«"):
        return (len(PREFIX_ORDER), 0, token)
    for i, p in enumerate(PREFIX_ORDER):
        rest = token[len(p):]
        if token.startswith(p) and rest.isdigit():
            return (i, int(rest), token)
    return (len(PREFIX_ORDER) + 1, 0, token)


def frontmatter(text: str) -> dict:
    """맨 앞 `---` 블록의 최상위 `키: 값` 줄. 들여쓴 줄 · 목록 줄은 건너뛴다. 없거나 안 닫혔으면 {}."""
    lines = text.split("\n")
    if not lines or lines[0].rstrip("\r") != "---":
        return {}
    out = {}
    for line in lines[1:]:
        line = line.rstrip("\r")
        if line == "---":
            return out
        if not line or line[0] in " \t-#" or ":" not in line:
            continue
        key, value = line.split(":", 1)
        out.setdefault(key.strip(), value.strip())
    return {}


def unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def _heading_indexes(lines):
    """펜스 밖의 `## ` 줄 번호들. `### ` 는 `## ` 로 시작하지 않으므로 들지 않는다."""
    in_fence = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence and line.startswith("## "):
            yield i


def section_body(text: str, heading: str):
    """`heading` 과 같거나 `heading + " "` 로 시작하는 `## ` 줄 다음부터 다음 `## ` 줄 앞까지.

    없으면 None, 둘 이상이면 FormatError. §6 은 이 함수로 읽지 않는다 — `section6.body` 한 곳이다.
    """
    if heading.startswith("## 6."):
        raise ValueError("§6 은 section6.body 로만 읽는다")
    lines = text.splitlines(keepends=True)
    heads = list(_heading_indexes(lines))
    hits = [i for i in heads
            if lines[i].rstrip("\r\n") == heading or lines[i].startswith(heading + " ")]
    if not hits:
        return None
    if len(hits) > 1:
        raise FormatError("%s 절이 %d개다" % (heading, len(hits)))
    start = hits[0]
    later = [j for j in heads if j > start]
    end = later[0] if later else len(lines)
    return "".join(lines[start + 1:end])


def bundle_ids(text: str) -> list:
    raw = frontmatter(text).get("ids")
    if raw is None:
        raise FormatError("묶음 frontmatter 에 ids 가 없다")
    if not (raw.startswith("[") and raw.endswith("]")):
        raise FormatError("ids 는 한 줄 목록([…])이어야 한다")
    if not raw[1:-1].strip():
        raise FormatError("ids 가 비었다")
    return parse_ids(raw[1:-1])


def _cells(row: str) -> list:
    if not (row.startswith("|") and row.endswith("|")):
        raise FormatError("표 행이 | 로 시작하고 끝나지 않는다: %r" % row)
    return [c.strip() for c in row[1:-1].split("|")]


def table_ids(spec_text: str) -> set:
    """`## 번호 대조` 표의 첫 칸 번호 전부. 절이 없거나 표가 깨졌으면 FormatError."""
    body = section_body(spec_text, TABLE_HEADING)
    if body is None:
        raise FormatError("spec 에 `## 번호 대조` 절이 없다")
    rows = [l.strip() for l in body.splitlines() if l.strip().startswith("|")]
    if len(rows) < 3:
        raise FormatError("번호 대조 표가 없거나 데이터 행이 없다")
    if len(_cells(rows[0])) != 3:
        raise FormatError("번호 대조 표 머리 행이 칸 셋이 아니다")
    sep = _cells(rows[1])
    if len(sep) != 3 or not all(SEP_CELL_RE.fullmatch(c) for c in sep):
        raise FormatError("번호 대조 표 구분 행이 칸 셋이 아니다")
    out = set()
    for row in rows[2:]:
        cells = _cells(row)
        if len(cells) != 3:
            raise FormatError("번호 대조 표 행이 칸 셋이 아니다: %r" % row)
        if not (cells[1].startswith("반영") or cells[1].startswith("기각")):
            raise FormatError("둘째 칸이 반영/기각이 아니다: %r" % row)
        if not cells[2]:
            raise FormatError("셋째 칸(자리 또는 이유)이 비었다: %r" % row)
        out.update(parse_ids(cells[0]))
    return out


def check(bundle_text: str, spec_text: str) -> dict:
    """묶음 ids 중 표에 없는 번호(missing)와 표에만 있는 번호(extra)."""
    try:
        want = bundle_ids(bundle_text)
        have = table_ids(spec_text)
    except FormatError as exc:
        return {"status": 3, "missing": [], "extra": [], "bundle_count": None,
                "table_count": None, "reason": str(exc)}
    seen = set()
    missing = []
    for token in want:
        if token not in have and token not in seen:
            missing.append(token)
        seen.add(token)
    extra = sorted(have - seen, key=id_sort_key)
    return {"status": 1 if missing else 0, "missing": missing, "extra": extra,
            "bundle_count": len(seen), "table_count": len(have), "reason": None}


def render(result: dict) -> str:
    if result["status"] == 3:
        return "번호 대조 검사 불가 — %s" % result["reason"]
    lines = []
    if result["missing"]:
        lines.append("번호 대조: 빠진 번호 %d개 — %s"
                     % (len(result["missing"]), " · ".join(result["missing"])))
    else:
        lines.append("번호 대조: 빠진 번호 없음 (묶음 번호 %d개 · 표 번호 %d개)"
                     % (result["bundle_count"], result["table_count"]))
    if result["extra"]:
        lines.append("정보: 묶음에 없는 번호 %d개가 표에 있다 — %s"
                     % (len(result["extra"]), " · ".join(result["extra"])))
    return "\n".join(lines)


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="check_bundle_coverage.py",
                                 description="조각 묶음의 번호와 spec 의 번호 대조 표를 맞춘다.")
    ap.add_argument("bundle")
    ap.add_argument("spec")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    texts = []
    for path in (args.bundle, args.spec):
        try:
            with open(path, encoding="utf-8") as fh:
                texts.append(fh.read())
        except (OSError, UnicodeDecodeError) as exc:
            result = {"status": 3, "missing": [], "extra": [], "bundle_count": None,
                      "table_count": None, "reason": "파일을 못 읽었다: %s (%s)" % (path, exc)}
            print(json.dumps(result, ensure_ascii=False) if args.json else render(result))
            return 3
    result = check(texts[0], texts[1])
    print(json.dumps(result, ensure_ascii=False) if args.json else render(result))
    return result["status"]


if __name__ == "__main__":
    sys.exit(main())
````

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_bundle_coverage.sh`
Expected: `Total: 22 | Pass: 22 | Fail: 0`

- [ ] **Step 5: 이 파일을 보는 레포 락을 돌린다**

Run, 하나씩:
- `bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep '§6단일화'` → `✗` 없음
- `(cd plugins/quality-gates/tests && python3 -m unittest -q test_utf8_explicit)` → OK
- `bash shared/tests/test_python_floor.sh 2>&1 | tail -1` → `Fail:` 수가 Task 1 기준과 같다
- `(cd plugins/spec-distill/tests && python3 -m unittest -q test_review_hook_removed)` → 기준보다 새 실패 없음

- [ ] **Step 6: 커밋**

```bash
git add --chmod=+x -- plugins/spec-distill/tests/test_bundle_coverage.sh
git add -- plugins/spec-distill/scripts/check_bundle_coverage.py
git commit -m "feat(spec-distill): 조각 묶음 번호와 설계문서 번호 대조 표를 맞추는 검사를 더한다" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- plugins/spec-distill/scripts/check_bundle_coverage.py plugins/spec-distill/tests/test_bundle_coverage.sh
```

Expected: `git ls-files -s plugins/spec-distill/tests/test_bundle_coverage.sh` 가 `100755`.

---

### Task 3: 상태 계산 `roadmap_status.py`

**Files:**
- Create: `plugins/spec-distill/scripts/roadmap_status.py`
- Test: `plugins/spec-distill/tests/test_roadmap_status.sh` (100755)

**Interfaces:**
- Consumes (Task 2): `FormatError` · `bundle_ids` · `check` · `frontmatter` · `id_sort_key` · `parse_ids` · `section_body` · `unquote`, 그리고 `section6.body`
- Produces (Task 4 · 5 · 7 이 쓴다):
  - CLI `roadmap_status.py <로드맵 레포 상대경로> | --roadmap-file <파일> [--json]`, 종료 코드 0 · 1 · 2 · 3
  - `parse_roadmap(text) -> (meta: dict, blocks: list[dict], records: list[dict], risk_rows: list[tuple], errors: list[str])` — 블록 dict 키: `id` · `title` · `fields` · `kind`(`bundle`|`branch`|`decision`) · `deps` · `reserved` · `assigned`
  - `brief_universe(brief, audit) -> (non_s: set, s_ids: set, k_expected: list[tuple])`
  - `overlaps(blocks) -> list[{"blocks": [a, b], "paths": [...]}]`
  - `class Git(cwd)` — `run` · `commit` · `blob` · `exists` · `is_ancestor` · `first_parent_merges` · `changed` · `grep_files` · `fetched_at`; `merged_by(git, merges, main, branch, tip)` · `MAIN_REF` · `_reserves(entry, path)` · `_shared(path)`
  - JSON 키: `roadmap` · `source` · `fetched_at` · `notice` · `blocks[]`(`id` · `title` · `kind` · `stage` · `reason` · `task_status` · `branch` · `deps` · `specs` · `ids` · `warnings`) · `unassigned` · `orphans` · `unknown_ids` · `overlaps` · `format_errors` · `unknown_reasons` · `exit`

설계 대비 한 곳을 넓혔다(Review Focus 1): 머지 메시지 규칙은 브랜치가 지워졌을 때뿐 아니라 남은 브랜치 끝이 `origin/main` 에 다 들어 있을 때도 쓴다. 사용자가 받아들이지 않으면 `merged_by` 의 `if tip and not git.is_ancestor(tip, main): return None` 을 `if tip: return None` 으로 바꾸고 Q1 단언과 그 변이를 지운다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

````bash
#!/usr/bin/env bash
# roadmap_status.py — 로드맵 · git 에서 조각 단계 · 경고를 계산한다(R0 AC1 · AC3 · AC5 · AC7).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_roadmap_status.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
RS="$S/roadmap_status.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
W="$T/work"
g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
        -c init.defaultBranch=main "$@"; }
commit_file() {  # commit_file <경로> <내용> <메시지>
  mkdir -p "$(dirname "$W/$1")" && printf '%s\n' "$2" > "$W/$1" && g add -- "$1" && g commit -qm "$3"
}
pr_merge() {     # pr_merge <번호> <브랜치> — GitHub merge commit 모양
  g checkout -q main && g merge -q --no-ff "$2" -m "Merge pull request #$1 from o/$2"
}
spec_doc() {     # spec_doc <source_interview> <번호 대조 첫 칸>
  printf -- '---\nsource_interview: %s\n---\n\n# 설계\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n| %s | 반영 | §1 |\n' "$1" "$2"
}
js() {           # js <json 파일> <파이썬 식 — r 이 보고서>. 식은 이 테스트가 쓴 고정 문자열뿐이다.
  python3 -c 'import json,sys; r=json.load(open(sys.argv[1],encoding="utf-8")); print(eval(sys.argv[2]))' "$1" "$2"
}
stage() { js "$1" "next(b['stage'] for b in r['blocks'] if b['id']=='$2')"; }
warns() { js "$1" "' | '.join(next(b['warnings'] for b in r['blocks'] if b['id']=='$2'))"; }

# ── 픽스처: brief · audit · 묶음 · 로드맵 ─────────────────────────────────────
write_brief() {  # write_brief <디렉토리>
  mkdir -p "$1"
  cat > "$1/b.md" <<'MD'
---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "가"
  - id: D2
    statement: "나"
---

# brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 하나

## 1. Goal · Non-goal

- Goal: 목표 문장.
- Non-goal: 아닌 것.

## 2. 제약

- 🗣 confirmed **C1** — 가 ⟨S1⟩
- ☑ confirmed **D2** — 나 ⟨S2⟩

## 3. Open Questions

- OQ1: 하나

## 4. External Landscape

- 바깥 사례 «k1» — [취함] [→ OQ1]

## 5. 기각 · Blind Spots

- 기각 — 다른 길 — verdict: refined — ST1 — 부착 1/1
- 위험 — 숨은 가정: 가정 하나 — 근거 없음
- 위험 — 실패 양식: 실패 하나 — 근거 없음
- 위험 — 장치 | 장치 — RC1 (x.md) [RC1 → OQ1]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 처음 요청

## 7. Next Action

다음.
MD
  cat > "$1/b.audit.md" <<'MD'
# audit

## 6. 사용자 원문

- **S2** 🗣 발화 (round 0):
  > 둘째 말

## 7. 확산 원자료

- 없음
MD
}

bundle() {  # bundle <로드맵 디렉토리> <블록> <ids>
  printf -- '---\ntype: slice-bundle\nslice: %s\nroadmap: %s/roadmap.md\nsource_brief: docs/br/b.md\nids: [%s]\n---\n\n# %s\n' \
    "$2" "$1" "$3" "$2" > "$W/$1/$2.md"
}

block() {   # block <id> <브랜치> <의존> <경로 예약> [묶음 값]
  printf '### %s — 조각 %s\n- 의도: %s 의 의도\n- 범위: 한다 %s / 안 한다 없음\n- 의존: %s\n- 브랜치: %s\n- 묶음: %s\n- 경로 예약: %s\n\n' \
    "$1" "$1" "$1" "$1" "$3" "$2" "${5:-$1.md}" "$4"
}

roadmap_head() {
  printf -- '---\ntype: roadmap\nsource_brief: docs/br/b.md\n---\n\n# 로드맵\n\n## 조각\n\n'
}
roadmap_tail() {  # roadmap_tail <결정 기록 줄들>
  printf '## 지휘 절차\n\n1. fetch\n\n## 결정 기록\n\n쉬운 말 PR 은 이미 머지됐다 — 블록 없음.\n%s\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n\n- K1 — 위험 — 숨은 가정: 가정 하나 — 근거 없음\n- K2 — 위험 — 실패 양식: 실패 하나 — 근거 없음\n' "$1"
}

# ── 픽스처: git 이력 ─────────────────────────────────────────────────────────
git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$W" 2>/dev/null
commit_file README.txt "시작" "init"
g push -q origin main

# A1 — merge commit 으로 머지, 브랜치 남음 → 머지됨
g checkout -q -b feature/a1 main; commit_file src/a.txt a "a1"; pr_merge 1 feature/a1
# 동기화 머지: feature/sx 가 main 을 받아온 뒤 main 에 머지된다. U1 은 그 둘째 부모(그때의 main)에서 만든 빈 브랜치.
SYNC_PARENT="$(g rev-parse main)"
g checkout -q -b feature/sx main~1; commit_file src/sx.txt sx "sx"
g merge -q --no-ff main -m "Merge origin/main into feature/sx"
pr_merge 2 feature/sx
g branch -q feature/u1 "$SYNC_PARENT"
# B1 — 머지 뒤 브랜치 지움 → 머지 메시지로 머지됨
g checkout -q -b feature/b1 main; commit_file src/b.txt b "b1"; pr_merge 3 feature/b1; g branch -q -D feature/b1
# E1 의 이웃 — feature/e1-extra 만 머지되고 지워짐. E1 의 feature/e1 은 이름 앞부분만 같다.
g checkout -q -b feature/e1-extra main; commit_file src/e.txt e "e1x"; pr_merge 4 feature/e1-extra; g branch -q -D feature/e1-extra
# F1 — squash 머지(머지 커밋 없음) + 지움 → 결정 기록의 머지 기록으로만 머지됨
g checkout -q main; commit_file src/f.txt f "F1 squash"
# Y1 — 머지된 뒤 같은 브랜치에 커밋이 더 붙음 → 머지됨이 아니다
g checkout -q -b feature/y1 main; commit_file src/y.txt y1 "y1a"; pr_merge 5 feature/y1
g checkout -q feature/y1; commit_file src/y.txt y2 "y1b"
# Q1 — 머지 뒤 로컬 브랜치를 main 으로 앞당김(브랜치 끝 = 머지 커밋 자신) → 머지 메시지로 머지됨
g checkout -q -b feature/q1 main; commit_file src/q.txt q "q1"; pr_merge 6 feature/q1; g branch -q -f feature/q1 main
g checkout -q main
g push -q origin main

# 문서(brief · 묶음 · 로드맵)는 main 의 마지막 커밋으로 둔다
write_brief "$W/docs/br"
mkdir -p "$W/docs/rm"
for b in A1 B1 E1 F1 G1 H1 I1 J1 W1 M1 T1 U1 Y1 Q1; do bundle docs/rm "$b" "C1, S1"; done
bundle docs/rm A1 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
bundle docs/rm V1 "C1, D2, S1"
{ roadmap_head
  block A1 feature/a1 없음 "plugins/p/README.md, src/a.txt"
  block B1 feature/b1 없음 "plugins/p/README.md"
  block E1 feature/e1 없음 "docs/shared/"
  block F1 feature/f1 없음 없음
  block G1 feature/g1 없음 없음
  block H1 feature/h1 없음 없음
  block I1 feature/i1 없음 "src/i.txt"
  block J1 feature/j1 W1 "src/j.txt, src/jw.txt, src/한 글.txt"
  block W1 feature/w1 없음 "docs/shared/x.md, src/jw.txt"
  block L1 feature/l1 없음 없음
  block M1 feature/m1 없음 없음
  block T1 feature/t1 A1 없음
  block U1 feature/u1 없음 없음
  block V1 feature/v1 없음 없음
  block Y1 feature/y1 없음 없음
  block Q1 feature/q1 없음 없음
  printf '### N1 — 묶음 없는 브랜치\n- 의도: n\n- 범위: n\n- 의존: 없음\n- 브랜치: feature/n1\n- 묶음: 없음\n- 경로 예약: 없음\n- spec: docs/superpowers/specs/n1-design.md\n- 발화: S1\n- 항목: C1\n\n'
  printf '### P1 — 결정 끝\n- 의도: p\n- 범위: p\n- 의존: 없음\n- 완료: 결정 기록\n- 묶음: 없음\n- 경로 예약: 없음\n- 발화: S2\n- 항목: D2\n\n'
  printf '### P2 — 결정 대기\n- 의도: p\n- 범위: p\n- 의존: W1\n- 완료: 결정 기록\n- 묶음: 없음\n- 경로 예약: 없음\n- 발화: S2\n- 항목: D2\n\n'
  roadmap_tail "$(printf -- '- F1 · 머지 · 2026-10-11 · 「squash 로 머지했다」\n- P1 · 결정 · 2026-10-11 · 「이걸로 정한다」')"
} > "$W/docs/rm/roadmap.md"
g add -- docs && g commit -qm "docs: 로드맵" && g push -q origin main

# T1 — main 에서 막 만든 빈 브랜치(머지됨이 아니다 — D1.1)
g branch -q feature/t1 main
# G1 — 로컬에만, spec 있음 → 설계 중
g checkout -q -b feature/g1 main
spec_doc docs/rm/G1.md "C1 · S1" > "$W/g1.md"; mkdir -p "$W/docs/superpowers/specs"; mv "$W/g1.md" "$W/docs/superpowers/specs/g1-design.md"
g add -- docs && g commit -qm "g1 spec"
# H1 — 원격에만, spec + 계획 → 계획
g checkout -q -b feature/h1 main
mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
spec_doc docs/rm/H1.md "C1, S1" > "$W/docs/superpowers/specs/h1-design.md"
printf '# 계획\n\n**Spec:** `docs/superpowers/specs/h1-design.md` (§1 · §2) — 참고 `docs/other.md`\n' > "$W/docs/superpowers/plans/h1.md"
g add -- docs && g commit -qm "h1" && g push -q origin feature/h1 && g checkout -q main && g branch -q -D feature/h1
# I1 — J1 만 예약한 src/j.txt 를 바꿈 → 경로 예약 위반
g checkout -q -b feature/i1 main; commit_file src/j.txt i "i1 touches j"; commit_file "src/한 글.txt" i "i1 touches 한글 경로"
# J1 — 의존 W1(준비) 인데 브랜치가 있다 → 설계 중 + 의존 미머지 경고
g checkout -q -b feature/j1 main; commit_file src/j.txt j "j1"
# M1 — spec 둘이 같은 묶음을 가리킨다 → spec 여럿
g checkout -q -b feature/m1 main; mkdir -p "$W/docs/superpowers/specs"
spec_doc docs/rm/M1.md "C1 · S1" > "$W/docs/superpowers/specs/m1-a-design.md"
spec_doc "\"docs/rm/M1.md\"" "C1 · S1" > "$W/docs/superpowers/specs/m1-b-design.md"
g add -- docs && g commit -qm "m1"
# N1 — 묶음 없는 브랜치 블록: spec: 줄의 spec 을 가리키는 계획 → 계획
g checkout -q -b feature/n1 main; mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
printf '# n1\n' > "$W/docs/superpowers/specs/n1-design.md"
printf '**Spec:** `docs/superpowers/specs/n1-design.md`\n' > "$W/docs/superpowers/plans/n1.md"
g add -- docs && g commit -qm "n1"
# V1 — spec 의 번호 대조가 D2 를 빠뜨림 → 생략 경고
g checkout -q -b feature/v1 main; mkdir -p "$W/docs/superpowers/specs"
spec_doc docs/rm/V1.md "C1 · S1" > "$W/docs/superpowers/specs/v1-design.md"
g add -- docs && g commit -qm "v1"
g checkout -q main
g fetch -q origin

# ── 1. origin/main 사본으로 계산 ─────────────────────────────────────────────
OUT="$T/main.json"
(cd "$W" && python3 "$RS" --json docs/rm/roadmap.md > "$OUT"); rc=$?
assert_eq "$rc" "1" "경고가 있는 로드맵 → rc 1"
assert_eq "$(js "$OUT" "r['source']")" "origin/main" "기본 사본은 origin/main"
assert_eq "$(js "$OUT" "r['format_errors']")" "[]" "형식 깨짐 없음"
assert_eq "$(stage "$OUT" A1)" "머지됨" "A1: 머지 커밋의 둘째 부모 = 브랜치 끝 → 머지됨"
assert_eq "$(stage "$OUT" B1)" "머지됨" "B1: 지운 브랜치 · 머지 메시지 정확히 같음 → 머지됨"
assert_eq "$(stage "$OUT" E1)" "준비" "E1: 이름 앞부분만 같은 머지 메시지 → 머지됨 아님(준비)"
assert_eq "$(stage "$OUT" F1)" "머지됨" "F1: 결정 기록의 머지 기록(squash 대체) → 머지됨"
assert_contains "$(js "$OUT" "next(b['reason'] for b in r['blocks'] if b['id']=='F1')")" "결정 기록의 머지 기록" "F1 근거가 결정 기록"
assert_eq "$(stage "$OUT" T1)" "설계 중" "T1: 커밋 없는 새 브랜치는 머지됨이 아니다(D1.1)"
assert_eq "$(stage "$OUT" U1)" "설계 중" "U1: 동기화 머지의 둘째 부모에서 만든 빈 브랜치는 머지됨이 아니다(D4.24)"
assert_eq "$(stage "$OUT" Y1)" "설계 중" "Y1: 머지 뒤 커밋이 더 붙은 브랜치는 머지됨이 아니다"
assert_eq "$(stage "$OUT" Q1)" "머지됨" "Q1: 머지 뒤 main 으로 앞당긴 로컬 브랜치 → 머지 메시지로 머지됨"
assert_eq "$(stage "$OUT" G1)" "설계 중" "G1: 로컬에만 있는 브랜치 · spec 있음 → 설계 중"
assert_eq "$(js "$OUT" "next(b['reason'] for b in r['blocks'] if b['id']=='G1')")" "spec 있음" "G1 근거 「spec 있음」"
assert_eq "$(stage "$OUT" H1)" "계획" "H1: 원격에만 있는 브랜치 · **Spec:** 뒤에 설명과 둘째 백틱 → 계획"
assert_eq "$(stage "$OUT" N1)" "계획" "N1: 묶음 없는 블록의 spec: 으로 계획"
assert_eq "$(stage "$OUT" W1)" "준비" "W1: 브랜치 없음 · 의존 없음 → 준비"
assert_eq "$(stage "$OUT" L1)" "준비" "L1: 브랜치 없음 → 준비"
assert_eq "$(stage "$OUT" P1)" "끝남" "P1: 결정 기록 있음 → 끝남"
assert_eq "$(stage "$OUT" P2)" "대기" "P2: 의존 W1 이 끝나지 않음 → 대기"
assert_eq "$(stage "$OUT" J1)" "설계 중" "J1: 의존 미머지여도 단계는 그대로 계산"
assert_contains "$(warns "$OUT" J1)" "의존 미머지 상태에서 진행 중: W1" "J1: 의존 미머지 진행 경고"
assert_contains "$(warns "$OUT" I1)" "경로 예약 위반: src/j.txt 은 J1 만 예약했다" "I1: 경로 예약 위반"
assert_not_contains "$(warns "$OUT" J1)" "경로 예약 위반" "J1: 자기가 예약한 파일은 위반이 아니다"
assert_contains "$(warns "$OUT" I1)" "경로 예약 위반: src/한 글.txt 은 J1 만 예약했다" "I1: 한글 · 공백 경로도 이스케이프 없이 대조한다"
assert_grep "$(js "$OUT" "r['fetched_at']")" "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$" "origin/main 받은 시각을 낸다(FETCH_HEAD)"
lc="$(cd "$W" && LC_ALL=C LANG=C PYTHONIOENCODING= python3 "$RS" docs/rm/roadmap.md 2>&1)"; rc=$?
assert_eq "$rc" "1" "비UTF-8 로캘(LC_ALL=C)에서도 같은 rc"
assert_contains "$lc" "로드맵 상태 — " "비UTF-8 로캘에서도 한국어 출력이 깨지지 않는다"
assert_file_grep "$RS" 'GIT_NO_LAZY_FETCH="1"' "partial clone 에서 빠진 객체를 받으러 나가지 않게 한다"
assert_contains "$(warns "$OUT" L1)" "묶음 없음: docs/rm/L1.md" "L1: 묶음 없음"
assert_contains "$(warns "$OUT" M1)" "spec 여럿" "M1: spec 여럿(따옴표 친 source_interview 포함)"
assert_contains "$(warns "$OUT" V1)" "생략: docs/superpowers/specs/v1-design.md 이 번호 1개를 빠뜨렸다 — D2" "V1: 생략 경고"
assert_eq "$(js "$OUT" "r['unassigned']")" "[]" "미배정 번호 0"
assert_eq "$(js "$OUT" "r['orphans']")" "[]" "고아 발화 0"
assert_eq "$(js "$OUT" "[o['blocks'] for o in r['overlaps']]")" "[['E1', 'W1']]" "겹침: E1 ↔ W1 만(README 는 빼고, J1→W1 은 의존이 있어 뺀다)"
assert_eq "$(js "$OUT" "next(b['task_status'] for b in r['blocks'] if b['id']=='H1')")" "in_progress" "작업 목록 대응: 계획 → in_progress"
txt="$(cd "$W" && python3 "$RS" docs/rm/roadmap.md)"
assert_grep "$txt" "^로드맵 상태 — 블록 19개 · " "사람용 글 첫 줄이 상태"
assert_contains "$txt" "머지됨 자동 판정은 merge commit 방식에서만 된다" "한계 공시 줄"

# ── 2. --roadmap-file(작업 트리) 사본 · 번호 대조 검사 불가 · 미배정 · 고아 ─────────
mkdir -p "$W/docs/rm2"
bundle docs/rm2 X1 "C1, S1"
bundle docs/rm2 A1 "C1, OQ1, RC1, ST1, «k1», K1, K2, S1, C99"
{ roadmap_head; block A1 feature/a1 없음 없음; block X1 feature/x1 없음 없음; roadmap_tail ""; } > "$W/docs/rm2/roadmap.md"
g checkout -q -b feature/x1 main; mkdir -p "$W/docs/superpowers/specs"
printf -- '---\nsource_interview: docs/rm2/X1.md\n---\n\n# 번호 대조 절이 없다\n' > "$W/docs/superpowers/specs/x1-design.md"
g add -- docs/superpowers && g commit -qm "x1"; g checkout -q main
OUT2="$T/wt.json"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm2/roadmap.md > "$OUT2"); rc=$?
assert_eq "$rc" "3" "번호 대조 검사 불가가 있으면 rc 3"
assert_eq "$(js "$OUT2" "r['source']")" "작업 트리" "--roadmap-file 은 작업 트리 사본"
assert_eq "$(js "$OUT2" "[b['id'] for b in r['blocks']]")" "['A1', 'X1']" "작업 트리 로드맵의 블록을 읽었다(origin/main 사본과 다름)"
assert_contains "$(warns "$OUT2" X1)" "번호 대조 검사 불가(spec 에 \`## 번호 대조\` 절이 없다)" "X1: 검사 불가 경고"
assert_eq "$(js "$OUT2" "r['unassigned']")" "['D2']" "미배정 번호 D2"
assert_eq "$(js "$OUT2" "r['orphans']")" "['S2']" "고아 발화 S2"
assert_eq "$(js "$OUT2" "r['unknown_ids']")" "['C99']" "brief 에 없는 번호 C99"

# ── 3. 형식 깨짐(rc 3) ───────────────────────────────────────────────────────
sed '/^- 의도: A1 의 의도$/d' "$W/docs/rm2/roadmap.md" > "$W/docs/rm2/broken.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm2/broken.md > "$T/broken.json"); rc=$?
assert_eq "$rc" "3" "머리말 빠진 블록 → rc 3"
assert_contains "$(js "$T/broken.json" "r['format_errors']")" "A1: 머리말 의도 가 없다" "형식 깨짐 사유"
mkdir -p "$W/docs/rm3"
for f in A1 X1; do sed 's|docs/rm2/|docs/rm3/|' "$W/docs/rm2/$f.md" > "$W/docs/rm3/$f.md"; done
sed 's/^- K2 — .*/- K2 — 다른 문장/' "$W/docs/rm2/roadmap.md" > "$W/docs/rm3/roadmap.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm3/roadmap.md > "$T/k.json"); rc=$?
assert_eq "$rc" "3" "위험 번호표가 brief 와 다르면 rc 3"
assert_contains "$(js "$T/k.json" "r['format_errors']")" "위험 번호표가 brief §5 위험 줄과 다르다: K2" "위험 번호표 대조"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm2/없음.md > "$T/none.json"); rc=$?
assert_eq "$rc" "3" "로드맵 없음 → rc 3"
(cd "$W" && python3 "$RS" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "2" "인자 없음 → rc 2"

# ── 4. origin/main 없음 → 모든 블록 알 수 없음 · rc 3 ─────────────────────────
git clone -q "$T/origin.git" "$T/noorigin" 2>/dev/null
git -C "$T/noorigin" remote remove origin
(cd "$T/noorigin" && python3 "$RS" --json --roadmap-file docs/rm/roadmap.md > "$T/no.json"); rc=$?
assert_eq "$rc" "3" "origin/main 없음 → rc 3"
assert_eq "$(js "$T/no.json" "sorted({b['stage'] for b in r['blocks']})")" "['알 수 없음']" "모든 블록 알 수 없음"
(cd "$T/noorigin" && python3 "$RS" --json docs/rm/roadmap.md > "$T/no2.json"); rc=$?
assert_eq "$rc" "3" "origin/main 사본 모드에서 origin/main 없음 → rc 3"

# ── 5. 읽기 전용(AC7) — 정적 검사 + 실행 전후 비교, 각각 양성 대조 ──────────────
static_check() {  # static_check <파일...> — 쓰기 · 네트워크 · 허용 밖 git 을 찾으면 줄을 낸다
  python3 - "$@" <<'PY'
import ast, sys
WRITE_ATTRS = {"write_text", "write_bytes", "unlink", "rmdir", "mkdir", "rename", "replace",
               "touch", "chmod", "remove", "makedirs", "rmtree", "symlink_to", "system", "popen"}
NET_MODS = {"socket", "urllib", "http", "requests", "ftplib", "smtplib", "shutil"}
for path in sys.argv[1:]:
    tree = ast.parse(open(path, encoding="utf-8").read())
    allowed = None
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "GIT_ALLOWED" for t in node.targets):
            allowed = {e.value for e in node.value.args[0].elts}
    uses_subprocess = any(isinstance(n, ast.Import) and any(a.name == "subprocess" for a in n.names)
                          for n in ast.walk(tree))
    if uses_subprocess and (allowed is None or not allowed <= {"show", "rev-parse", "log", "diff", "merge-base", "cat-file", "grep"}):
        print("%s: GIT_ALLOWED 가 없거나 읽기 명령 밖을 담는다: %r" % (path, allowed))
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            names = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or ""]
            for n in names:
                if n.split(".")[0] in NET_MODS:
                    print("%s:%d: 네트워크 · 파일 조작 모듈 %s" % (path, node.lineno, n))
        if isinstance(node, ast.Call):
            f = node.func
            name = getattr(f, "attr", getattr(f, "id", ""))
            if name in WRITE_ATTRS:
                print("%s:%d: 쓰기 호출 %s" % (path, node.lineno, name))
            if name == "open":
                mode = node.args[1].value if len(node.args) > 1 and isinstance(node.args[1], ast.Constant) else ""
                for kw in node.keywords:
                    if kw.arg == "mode" and isinstance(kw.value, ast.Constant):
                        mode = kw.value.value
                if set(str(mode)) & set("wax+"):
                    print("%s:%d: 쓰기 모드 open" % (path, node.lineno))
            if name in ("run", "Popen", "call", "check_output", "check_call") and getattr(getattr(f, "value", None), "id", "") == "subprocess":
                first = node.args[0] if node.args else None
                head = first.elts[0] if isinstance(first, ast.List) and first.elts else None
                if not (isinstance(head, ast.Constant) and head.value == "git"):
                    print("%s:%d: git 이 아닌 subprocess" % (path, node.lineno))
PY
}
out="$(static_check "$RS" "$S/check_bundle_coverage.py")"
assert_eq "$out" "" "정적: 두 스크립트에 쓰기 · 네트워크 · git 밖 subprocess · 허용 밖 git 이 없다"
sed 's/GIT_ALLOWED = frozenset({"show",/GIT_ALLOWED = frozenset({"fetch", "show",/' "$RS" > "$T/mut_fetch.py"
assert_contains "$(static_check "$T/mut_fetch.py")" "GIT_ALLOWED" "양성 대조: fetch 를 허용 목록에 넣으면 정적 검사가 잡는다"
printf 'from pathlib import Path\nPath("x").write_text("y", encoding="utf-8")\nimport urllib.request\n' > "$T/mut_write.py"
out="$(static_check "$T/mut_write.py")"
assert_contains "$out" "쓰기 호출 write_text" "양성 대조: write_text 를 잡는다"
assert_contains "$out" "네트워크 · 파일 조작 모듈 urllib.request" "양성 대조: urllib 을 잡는다"
out="$(cd "$S" && python3 -c '
import roadmap_status as r
try:
    r.Git(".").run("fetch")
    print("RAN")
except RuntimeError:
    print("REFUSED")')"
assert_eq "$out" "REFUSED" "실행: 허용 밖 git 하위 명령은 부르기 전에 거부한다"
snap() { (cd "$W" && find . -path ./.git/objects -prune -o -type f -print0 | sort -z | xargs -0 shasum) ; git -C "$W" for-each-ref --format='%(refname) %(objectname)'; }
before="$(snap)"
(cd "$W" && python3 "$RS" --json docs/rm/roadmap.md >/dev/null; python3 "$RS" --roadmap-file docs/rm2/roadmap.md >/dev/null; python3 "$S/check_bundle_coverage.py" docs/rm/V1.md docs/rm/V1.md >/dev/null)
after="$(snap)"
[ "$before" = "$after" ] && ok "실행: 작업 트리 · .git · ref 가 실행 전후 같다" || no "실행: 스크립트가 무언가를 썼다"
printf 'x\n' >> "$W/README.txt"; after2="$(snap)"; git -C "$W" checkout -q -- README.txt
[ "$before" != "$after2" ] && ok "양성 대조: 파일 하나를 바꾸면 비교가 잡는다" || no "양성 대조: 비교가 변화를 못 본다"

# ── 6. 변이 — 첫째 부모 이력 제한(D4.24)과 조상 아님 조건(D1.1)에 이빨이 있는지 ──────
M="$T/mut"; mkdir -p "$M"; cp "$S/section6.py" "$S/check_bundle_coverage.py" "$M/"
sed 's/"log", "--first-parent", "--merges"/"log", "--merges"/' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(--first-parent)" || ok "변이 적용됨(--first-parent)"
(cd "$W" && python3 "$M/roadmap_status.py" --json docs/rm/roadmap.md > "$T/mfp.json")
assert_eq "$(stage "$T/mfp.json" U1)" "머지됨" "변이: --first-parent 를 빼면 U1 이 머지됨 — 위 U1 단언에 이빨이 있다"
sed 's/if m and m.group(1) == branch:/if m and m.group(1).startswith(branch):/' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(정확히 같음)" || ok "변이 적용됨(정확히 같음)"
(cd "$W" && python3 "$M/roadmap_status.py" --json docs/rm/roadmap.md > "$T/mpx.json")
assert_eq "$(stage "$T/mpx.json" E1)" "머지됨" "변이: 정확히 같음을 앞부분 같음으로 바꾸면 E1 이 머지됨 — E1 단언에 이빨이 있다"
sed '/if tip and not git.is_ancestor(tip, main):/,/return None/d' "$RS" > "$M/roadmap_status.py"
cmp -s "$RS" "$M/roadmap_status.py" && no "변이 적용 안 됨(main 에 다 들어 있음)" || ok "변이 적용됨(main 에 다 들어 있음)"
(cd "$W" && python3 "$M/roadmap_status.py" --json docs/rm/roadmap.md > "$T/mff.json")
assert_eq "$(stage "$T/mff.json" Y1)" "머지됨" "변이: 「브랜치 끝이 main 에 들어 있음」 조건을 지우면 Y1 이 머지됨 — Y1 단언에 이빨이 있다"
finish
````

Run: `chmod +x plugins/spec-distill/tests/test_roadmap_status.sh`

픽스처 표 — 코드 분기마다 픽스처가 있다:

| 분기 | 픽스처 | 기대 |
|---|---|---|
| 머지 커밋 둘째 부모 = 끝 | A1 | 머지됨 |
| 지운 브랜치 · 메시지 정확히 같음 | B1 | 머지됨 |
| 메시지 앞부분만 같음 | E1 | 준비 |
| 결정 기록 머지 줄(squash) | F1 | 머지됨 |
| 커밋 없는 새 브랜치(D1.1) | T1 | 설계 중 |
| 동기화 머지 둘째 부모에서 만든 빈 브랜치(D4.24) | U1 | 설계 중 |
| 머지 뒤 커밋이 더 붙음 | Y1 | 설계 중 |
| 머지 뒤 main 으로 앞당긴 로컬 브랜치 | Q1 | 머지됨 |
| 로컬에만 · spec 있음 | G1 | 설계 중 |
| 원격에만 · spec + 계획(`**Spec:**` 뒤 설명 · 둘째 백틱) | H1 | 계획 |
| 묶음 없는 블록 `spec:` + 계획 | N1 | 계획 |
| 브랜치 없음 · 의존 완료 / 미완료 | W1 · L1 / P2 | 준비 / 대기 |
| 결정 기록 있음 | P1 | 끝남 |
| 의존 미머지인데 브랜치 있음 | J1 | 설계 중 + 경고 |
| 다른 조각만 예약한 파일(한글 · 공백 경로 포함) | I1 | 위반 경고 |
| 묶음 파일 없음 · spec 둘 · 빠진 번호 | L1 · M1 · V1 | 경고 |
| 번호 대조 절 없음 · 작업 트리 사본 · 미배정 · 고아 · 모르는 번호 | X1 · rm2 | rc 3 · 각 목록 |
| 형식 깨짐 · 위험 번호표 불일치 · 로드맵 없음 · 인자 없음 | rm2 변형 · rm3 | rc 3 · rc 2 |
| origin/main 없음(두 모드) | noorigin | 전부 알 수 없음 · rc 3 |

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh`
Expected: FAIL — 스크립트가 없어 JSON 파일이 비고 단계 단언이 ✗.

- [ ] **Step 3: 구현한다**

````python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_status.py — 로드맵과 git 을 읽어 조각별 단계 · 경고를 낸다.

명령줄:
  roadmap_status.py <로드맵 경로>           origin/main 의 로드맵을 읽는다(레포 상대경로)
  roadmap_status.py --roadmap-file <파일>   작업 트리의 로드맵을 읽는다(아직 main 에 없을 때)
  --json 이면 JSON 하나를 낸다.

종료 코드: 0 이상 없음 · 1 경고 있음 · 2 사용법 오류 · 3 검사 불가(로드맵 없음 · 형식 깨짐 ·
블록 하나라도 알 수 없음 · 번호 대조 검사 불가 · 번호 전체 집합을 못 셈). 3 > 1 > 0.

읽기만 한다 — 파일을 쓰지 않고 네트워크에 나가지 않는다. git 은 `GIT_ALLOWED` 의 하위 명령만
부르고 fetch 하지 않는다(지휘 절차가 계산 전에 fetch 한다). 단계는 git 으로 알 수 있는 것까지다 —
구현 중 · 구현 끝 · PR 은 R5 가 붙인다.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import section6  # noqa: E402
from check_bundle_coverage import (  # noqa: E402
    FormatError, bundle_ids, check, frontmatter, id_sort_key, parse_ids, section_body, unquote)

MAIN_REF = "refs/remotes/origin/main"
GIT_ALLOWED = frozenset({"show", "rev-parse", "log", "diff", "merge-base", "cat-file", "grep"})
NOTICE = ("머지됨 자동 판정은 merge commit 방식에서만 된다 — squash · rebase 로 머지했으면 "
          "로드맵 결정 기록에 머지 기록을 적는다.")
FIELDS = ("의도", "범위", "의존", "브랜치", "묶음", "경로 예약", "spec", "발화", "항목", "완료")
REQUIRED = {
    "bundle": ("의도", "범위", "의존", "브랜치", "묶음", "경로 예약"),
    "branch": ("의도", "범위", "의존", "브랜치", "묶음", "경로 예약", "spec", "발화", "항목"),
    "decision": ("의도", "범위", "의존", "완료", "묶음", "경로 예약", "발화", "항목"),
}
FORBIDDEN = {"bundle": ("spec", "발화", "항목", "완료"), "branch": ("완료",),
             "decision": ("브랜치", "spec")}
RISK_PREFIXES = ("- 위험 — 숨은 가정", "- 위험 — 실패 양식", "- 위험 — 리뷰 참고")
# 경로 예약 겹침 · 위반에서 빼는 공유 파일 — 버전은 머지 직전에 정한다(N6).
SHARED_BASENAMES = ("plugin.json", "CHANGELOG.md", "README.md")
TASK_STATUS = {"대기": "pending", "준비": "pending", "설계 중": "in_progress",
               "계획": "in_progress", "머지됨": "completed", "끝남": "completed"}
DONE = ("머지됨", "끝남")

BLOCK_HEAD_RE = re.compile(r"### ([A-Z][0-9]+[a-z]?) — (\S.*)")
BLOCK_ID_RE = re.compile(r"[A-Z][0-9]+[a-z]?")
BUNDLE_NAME_RE = re.compile(r"[A-Za-z0-9_-]+\.md")
RISK_ROW_RE = re.compile(r"- (K\d+) — (\S.*)")
MERGE_MSG_RE = re.compile(r"Merge pull request #\d+ from [^/\s]+/(\S+)")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
ID_ITEM_RE = re.compile(r"\s+- id: ([CD]\d+)\s*")
OQ_LINE_RE = re.compile(r"- (OQ\d+) ")
RC_RE = re.compile(r"\bRC\d+\b")
ST_RE = re.compile(r"\bST\d+\b")
KEY_RE = re.compile(r"«[^«»]+»")
S_ANCHOR_RE = re.compile(r"\*\*(S\d+)\*\*")
BACKTICK_RE = re.compile(r"`([^`]+)`")
LIST_SEP_RE = re.compile(r"\s*,\s*|\s+·\s+")


# ── git (읽기 전용) ──────────────────────────────────────────────────────────

class Git:
    def __init__(self, cwd: str):
        self.cwd = cwd
        self.env = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_OPTIONAL_LOCKS="0",
                        GIT_TERMINAL_PROMPT="0", LC_ALL="C")

    def run(self, *args):
        if not args or args[0] not in GIT_ALLOWED:
            raise RuntimeError("허용하지 않은 git 하위 명령: %r" % (args[:1],))
        proc = subprocess.run(["git", "-c", "core.quotePath=false", *args], cwd=self.cwd,
                              env=self.env, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return proc.returncode, proc.stdout.decode("utf-8", "replace")

    def commit(self, ref: str):
        rc, out = self.run("rev-parse", "--verify", "--quiet", ref + "^{commit}")
        return out.strip() if rc == 0 and out.strip() else None

    def toplevel(self):
        rc, out = self.run("rev-parse", "--show-toplevel")
        return out.strip() if rc == 0 else None

    def blob(self, rev: str, path: str):
        rc, out = self.run("cat-file", "blob", "%s:%s" % (rev, path))
        return out if rc == 0 else None

    def exists(self, rev: str, path: str) -> bool:
        return self.run("cat-file", "-e", "%s:%s" % (rev, path))[0] == 0

    def is_ancestor(self, a: str, b: str) -> bool:
        return self.run("merge-base", "--is-ancestor", a, b)[0] == 0

    def first_parent_merges(self):
        rc, out = self.run("log", "--first-parent", "--merges", "--format=%H%x09%P%x09%s",
                           MAIN_REF)
        merges = []
        for line in out.splitlines() if rc == 0 else []:
            parts = line.split("\t", 2)
            if len(parts) == 3:
                merges.append((parts[0], parts[1].split(), parts[2]))
        return merges

    def changed(self, base: str, tip: str):
        rc, out = self.run("diff", "--name-only", "-z", "%s...%s" % (base, tip))
        return [p for p in out.split("\0") if p] if rc == 0 else []

    def grep_files(self, tree: str, fixed: str, pathspec: str):
        rc, out = self.run("grep", "-l", "-z", "-F", "-e", fixed, tree, "--", pathspec)
        prefix = tree + ":"
        return [p[len(prefix):] if p.startswith(prefix) else p
                for p in out.split("\0") if p] if rc == 0 else []

    def fetched_at(self):
        rc, out = self.run("rev-parse", "--git-common-dir")
        if rc != 0:
            return None
        head = Path(self.cwd, out.strip(), "FETCH_HEAD")
        try:
            stamp = head.stat().st_mtime
        except OSError:
            return None
        return datetime.datetime.fromtimestamp(stamp).strftime("%Y-%m-%d %H:%M")


# ── 로드맵 · 묶음 · brief 읽기 ───────────────────────────────────────────────

class Source:
    """로드맵 · 묶음 · brief · audit 을 읽는 사본 — origin/main(rev) 또는 작업 트리(root)."""

    def __init__(self, git: Git, rev=None, root=None):
        self.git, self.rev, self.root = git, rev, root
        self.label = "origin/main" if rev else "작업 트리"

    def read(self, path: str):
        if self.rev:
            return self.git.blob(self.rev, path)
        try:
            return Path(self.root, path).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            return None


def split_list(value: str) -> list:
    value = value.strip()
    if value == "없음":
        return []
    return [p.strip().strip("`") for p in LIST_SEP_RE.split(value) if p.strip()]


def parse_roadmap(text: str):
    """(meta, blocks, records, risk_rows, errors). blocks 는 등장 순서의 dict 목록."""
    errors = []
    meta = frontmatter(text)
    if meta.get("type") != "roadmap":
        errors.append("frontmatter type 이 roadmap 이 아니다")
    if not meta.get("source_brief"):
        errors.append("frontmatter source_brief 가 없다")
    try:
        body = section_body(text, "## 조각")
        rec_body = section_body(text, "## 결정 기록") or ""
        risk_body = section_body(text, "## 위험 번호표") or ""
    except FormatError as exc:
        return meta, [], [], [], errors + [str(exc)]
    if body is None:
        return meta, [], [], [], errors + ["`## 조각` 절이 없다"]

    blocks, cur = [], None
    for line in body.splitlines():
        if line.startswith("### "):
            m = BLOCK_HEAD_RE.fullmatch(line.rstrip())
            if not m:
                errors.append("블록 머리가 `### <번호> — <이름>` 이 아니다: %r" % line)
                cur = None
                continue
            cur = {"id": m.group(1), "title": m.group(2), "fields": {}}
            blocks.append(cur)
        elif cur is not None and line.startswith("- "):
            key, sep, value = line[2:].partition(": ")
            if not sep or key not in FIELDS:
                errors.append("%s: 모르는 머리말 줄 %r" % (cur["id"], line))
            elif key in cur["fields"]:
                errors.append("%s: 머리말 %s 가 두 번 있다" % (cur["id"], key))
            else:
                cur["fields"][key] = value.strip()

    ids = [b["id"] for b in blocks]
    for bid in sorted({i for i in ids if ids.count(i) > 1}):
        errors.append("블록 번호 %s 가 두 번 있다" % bid)
    known = set(ids)
    for b in blocks:
        errors.extend(_validate_block(b, known))
    errors.extend(_cycles(blocks))

    records = []
    for line in rec_body.splitlines():
        if not line.startswith("- "):
            continue
        parts = line[2:].split(" · ", 3)
        if (len(parts) != 4 or parts[0] not in known or parts[1] not in ("결정", "머지")
                or not DATE_RE.fullmatch(parts[2])
                or not (parts[3].startswith("「") and parts[3].rstrip().endswith("」"))):
            errors.append("결정 기록 줄이 `- <블록> · <결정|머지> · <날짜> · 「원문」` 이 아니다: %r"
                          % line)
            continue
        records.append({"block": parts[0], "kind": parts[1], "date": parts[2],
                        "quote": parts[3].rstrip()})
    kinds = {b["id"]: b.get("kind") for b in blocks}
    for r in records:
        if (r["kind"] == "결정") != (kinds.get(r["block"]) == "decision"):
            errors.append("결정 기록: %s 는 %s 블록이라 「%s」 기록을 받지 않는다"
                          % (r["block"], kinds.get(r["block"]), r["kind"]))

    risk_rows = []
    for line in risk_body.splitlines():
        if line.startswith("- K"):
            m = RISK_ROW_RE.fullmatch(line.rstrip())
            if not m:
                errors.append("위험 번호표 줄이 `- K<n> — <원문>` 이 아니다: %r" % line)
            else:
                risk_rows.append((m.group(1), m.group(2)))
    return meta, blocks, records, risk_rows, errors


def _validate_block(b: dict, known: set) -> list:
    f, bid, errs = b["fields"], b["id"], []
    kind = "decision" if "완료" in f else ("branch" if f.get("묶음") == "없음" else "bundle")
    b["kind"] = kind
    for key in REQUIRED[kind]:
        if key not in f:
            errs.append("%s: 머리말 %s 가 없다" % (bid, key))
    for key in FORBIDDEN[kind]:
        if key in f:
            errs.append("%s: %s 블록에는 머리말 %s 를 두지 않는다" % (bid, kind, key))
    if kind == "decision":
        if f.get("완료") != "결정 기록":
            errs.append("%s: 완료 값은 「결정 기록」이어야 한다" % bid)
        if f.get("묶음") != "없음":
            errs.append("%s: 확인 · 결정 블록의 묶음은 「없음」이어야 한다" % bid)
    if kind == "bundle" and "묶음" in f and not BUNDLE_NAME_RE.fullmatch(f["묶음"]):
        errs.append("%s: 묶음 값은 로드맵 옆 파일 이름(R<n>.md)이어야 한다" % bid)
    deps = split_list(f.get("의존", "없음"))
    b["deps"] = deps
    for d in deps:
        if not BLOCK_ID_RE.fullmatch(d) or d not in known or d == bid:
            errs.append("%s: 의존 %r 가 로드맵의 다른 블록이 아니다" % (bid, d))
    b["reserved"] = split_list(f.get("경로 예약", "없음"))
    b["assigned"] = []
    for key, want_s in (("발화", True), ("항목", False)):
        if key in f:
            try:
                toks = parse_ids(f[key])
            except FormatError as exc:
                errs.append("%s: %s — %s" % (bid, key, exc))
                continue
            wrong = [t for t in toks if (t.startswith("S") and t[1:].isdigit()) != want_s]
            if wrong:
                errs.append("%s: %s 줄에 맞지 않는 번호 %s" % (bid, key, " · ".join(wrong)))
            b["assigned"].extend(toks)
    return errs


def _cycles(blocks: list) -> list:
    deps = {b["id"]: b.get("deps", []) for b in blocks}
    state, errs = {}, []

    def visit(n, stack):
        if state.get(n) == 1:
            errs.append("의존이 돈다: %s" % " → ".join(stack + [n]))
            return
        if state.get(n) == 2 or n not in deps:
            return
        state[n] = 1
        for d in deps[n]:
            visit(d, stack + [n])
        state[n] = 2

    for n in deps:
        visit(n, [])
    return errs


def brief_universe(brief: str, audit: str):
    """(non_s, s_ids, k_expected). 셀 수 없으면 FormatError."""
    fm_lines = brief.split("\n---", 1)[0].splitlines()
    non_s = {m.group(1) for line in fm_lines for m in [ID_ITEM_RE.fullmatch(line)] if m}
    s0 = section_body(brief, "## 0.")
    s4 = section_body(brief, "## 4.")
    s5 = section_body(brief, "## 5.")
    if s0 is None or s4 is None or s5 is None:
        raise FormatError("brief 에 §0 · §4 · §5 중 없는 절이 있다")
    non_s |= {m.group(1) for line in s0.splitlines() for m in [OQ_LINE_RE.match(line)] if m}
    non_s |= set(RC_RE.findall(s5)) | set(ST_RE.findall(s5)) | set(KEY_RE.findall(s4))
    k_expected = []
    for prefix in RISK_PREFIXES:
        k_expected += [line[2:] for line in s5.splitlines() if line.startswith(prefix)]
    k_expected = [("K%d" % (i + 1), text) for i, text in enumerate(k_expected)]
    non_s |= {k for k, _ in k_expected}
    s_ids = set()
    for label, doc in (("brief", brief), ("audit", audit)):
        b6 = section6.body(doc)
        if b6 is None:
            raise FormatError("%s §6 을 하나로 읽을 수 없다" % label)
        s_ids |= set(S_ANCHOR_RE.findall(b6))
    if not non_s or not s_ids:
        raise FormatError("brief 번호 집합이 비었다")
    return non_s, s_ids, k_expected


# ── 단계 · 경고 ──────────────────────────────────────────────────────────────

def _reserves(entry: str, path: str) -> bool:
    return path == entry or (entry.endswith("/") and path.startswith(entry))


def _shared(path: str) -> bool:
    return path.rsplit("/", 1)[-1] in SHARED_BASENAMES


def _reachable(blocks: list) -> dict:
    deps = {b["id"]: set(b.get("deps", [])) for b in blocks}
    reach = {}
    for n in deps:
        seen, todo = set(), list(deps[n])
        while todo:
            d = todo.pop()
            if d not in seen:
                seen.add(d)
                todo.extend(deps.get(d, ()))
        reach[n] = seen
    return reach


def find_specs(git: Git, tree: str, block: dict, bundle_path):
    if block["kind"] == "branch":
        spec = block["fields"]["spec"].strip().strip("`")
        return [spec] if git.exists(tree, spec) else []
    if block["kind"] != "bundle" or bundle_path is None:
        return []
    found = []
    for path in git.grep_files(tree, bundle_path, "docs/superpowers/specs/"):
        text = git.blob(tree, path)
        if text and unquote(frontmatter(text).get("source_interview", "")) == bundle_path:
            found.append(path)
    return sorted(found)


def has_plan(git: Git, tree: str, spec: str) -> bool:
    for path in git.grep_files(tree, spec, "docs/superpowers/plans/"):
        for line in (git.blob(tree, path) or "").splitlines():
            if line.lstrip().startswith("**Spec:**"):
                m = BACKTICK_RE.search(line)
                if m and m.group(1) == spec:
                    return True
    return False


def merged_by(git: Git, merges: list, main: str, branch: str, tip):
    """머지됨 근거 한 줄, 아니면 None. 조상 관계만으로는 머지됨이 아니다(D1.1)."""
    if tip:
        for sha, parents, _subj in merges:
            if len(parents) >= 2 and parents[1] == tip and not git.is_ancestor(tip, parents[0]):
                return "main 의 머지 커밋 %s" % sha[:8]
    # 머지 메시지가 이 브랜치를 정확히 부른다 — 브랜치가 지워졌거나, 남은 브랜치 끝이 main 에 다 들어가
    # 있을 때만(머지 뒤 로컬 브랜치를 main 으로 앞당긴 경우). 머지 뒤 커밋이 더 붙었으면 머지됨이 아니다.
    if tip and not git.is_ancestor(tip, main):
        return None
    for sha, _parents, subj in merges:
        m = MERGE_MSG_RE.fullmatch(subj.strip())
        if m and m.group(1) == branch:
            return "머지 메시지 %s (%s)" % (sha[:8], "브랜치 끝이 main 에 들어 있음" if tip
                                          else "브랜치는 지워짐")
    return None


def compute(git: Git, main, blocks: list, records: list, bundles: dict, roadmap_dir: str):
    """블록마다 stage · reason · warnings · specs 를 채운다. 반환: 번호 대조 검사 불가 사유 목록."""
    merges = git.first_parent_merges() if main else []
    by_id = {b["id"]: b for b in blocks}
    rec = {(r["block"], r["kind"]): r for r in records}
    cov_unknown = []
    order, seen = [], set()

    def place(n):
        if n in seen:
            return
        seen.add(n)
        for d in by_id[n].get("deps", []):
            place(d)
        order.append(n)

    for b in blocks:
        place(b["id"])

    for bid in order:
        b = by_id[bid]
        b.update(stage=None, reason="", warnings=[], specs=[], tip=None)
        undone = [d for d in b["deps"] if by_id[d]["stage"] not in DONE]
        if main is None:
            b["stage"], b["reason"] = "알 수 없음", "origin/main 을 못 읽었다"
            continue
        if b["kind"] == "decision":
            r = rec.get((bid, "결정"))
            if r:
                b["stage"], b["reason"] = "끝남", "결정 기록 %s %s" % (r["date"], r["quote"])
            elif undone:
                b["stage"], b["reason"] = "대기", "의존 미완료: %s" % " · ".join(undone)
            else:
                b["stage"], b["reason"] = "준비", "의존 완료"
            continue
        branch = b["fields"]["브랜치"].strip().strip("`")
        tip = git.commit("refs/heads/" + branch) or git.commit("refs/remotes/origin/" + branch)
        b["tip"] = tip
        bundle_path = (roadmap_dir + "/" + b["fields"]["묶음"]) if b["kind"] == "bundle" else None
        why = merged_by(git, merges, main, branch, tip)
        if not why and (bid, "머지") in rec:
            r = rec[(bid, "머지")]
            why = "결정 기록의 머지 기록 %s %s" % (r["date"], r["quote"])
        if why:
            b["stage"], b["reason"] = "머지됨", why
            b["specs"] = find_specs(git, main, b, bundle_path)
        elif not tip:
            if undone:
                b["stage"], b["reason"] = "대기", "의존 미완료: %s" % " · ".join(undone)
            else:
                b["stage"], b["reason"] = "준비", "의존 완료 · 브랜치 없음"
        else:
            b["specs"] = find_specs(git, tip, b, bundle_path)
            if any(has_plan(git, tip, s) for s in b["specs"]):
                b["stage"], b["reason"] = "계획", "계획 있음"
            else:
                b["stage"] = "설계 중"
                b["reason"] = "spec 있음" if b["specs"] else "브랜치 있음 · spec 없음"
            if undone:
                b["warnings"].append("의존 미머지 상태에서 진행 중: %s" % " · ".join(undone))
        if b["kind"] == "bundle" and bundles.get(bid) is None:
            b["warnings"].append("묶음 없음: %s" % bundle_path)
        if len(b["specs"]) > 1:
            b["warnings"].append("spec 여럿: %s" % " · ".join(b["specs"]))
        if b["kind"] == "bundle" and bundles.get(bid) is not None:
            tree = main if b["stage"] == "머지됨" else tip
            for spec in b["specs"]:
                result = check(bundles[bid], git.blob(tree, spec) or "")
                if result["status"] == 1:
                    b["warnings"].append("생략: %s 이 번호 %d개를 빠뜨렸다 — %s" % (
                        spec, len(result["missing"]), " · ".join(result["missing"])))
                elif result["status"] == 3:
                    b["warnings"].append("번호 대조 검사 불가(%s): %s" % (result["reason"], spec))
                    cov_unknown.append("%s %s" % (bid, result["reason"]))

    for b in blocks:
        if b["tip"] and b["stage"] in ("설계 중", "계획"):
            for path in git.changed(main, b["tip"]):
                if _shared(path):
                    continue
                owners = [o["id"] for o in blocks
                          if any(_reserves(e, path) for e in o["reserved"])]
                if owners and b["id"] not in owners:
                    b["warnings"].append("경로 예약 위반: %s 은 %s 만 예약했다"
                                         % (path, " · ".join(owners)))
    return cov_unknown


def overlaps(blocks: list) -> list:
    reach, out = _reachable(blocks), []
    for i, a in enumerate(blocks):
        for b in blocks[i + 1:]:
            if b["id"] in reach[a["id"]] or a["id"] in reach[b["id"]]:
                continue
            shared = sorted({ea for ea in a["reserved"] for eb in b["reserved"]
                             if not _shared(ea) and (_reserves(ea, eb) or _reserves(eb, ea))})
            if shared:
                out.append({"blocks": [a["id"], b["id"]], "paths": shared})
    return out


# ── 출력 ─────────────────────────────────────────────────────────────────────

def build(git: Git, args) -> dict:
    report = {"roadmap": None, "source": None, "fetched_at": git.fetched_at(), "notice": NOTICE,
              "blocks": [], "unassigned": None, "orphans": None, "unknown_ids": [],
              "overlaps": [], "format_errors": [], "unknown_reasons": [], "exit": 3}
    main = git.commit(MAIN_REF)
    if args.roadmap_file:
        top = git.toplevel()
        if top is None:
            report["unknown_reasons"].append("git 레포 안이 아니다")
            return report
        rel = os.path.relpath(os.path.realpath(args.roadmap_file), os.path.realpath(top))
        src = Source(git, root=top)
    else:
        rel = args.roadmap.strip("/")
        if main is None:
            report["unknown_reasons"].append("origin/main 을 못 읽었다")
            report["roadmap"], report["source"] = rel, "origin/main"
            return report
        src = Source(git, rev=main)
    report["roadmap"], report["source"] = rel, src.label
    text = src.read(rel)
    if text is None:
        report["unknown_reasons"].append("로드맵을 못 읽었다: %s (%s)" % (rel, src.label))
        return report
    meta, blocks, records, risk_rows, errors = parse_roadmap(text)
    report["format_errors"] = errors
    if errors:
        report["blocks"] = [{"id": b["id"], "title": b["title"], "stage": "알 수 없음",
                             "reason": "로드맵 형식 깨짐", "warnings": []} for b in blocks]
        return report

    roadmap_dir = rel.rsplit("/", 1)[0] if "/" in rel else "."
    bundles, union = {}, set()
    for b in blocks:
        if b["kind"] != "bundle":
            union.update(b["assigned"])
            continue
        btext = src.read(roadmap_dir + "/" + b["fields"]["묶음"])
        bundles[b["id"]] = btext
        if btext is None:
            continue
        fm = frontmatter(btext)
        bad = [k for k, want in (("type", "slice-bundle"), ("slice", b["id"]),
                                 ("roadmap", rel), ("source_brief", meta.get("source_brief")))
               if unquote(fm.get(k, "")) != want]
        try:
            if bad:
                raise FormatError("frontmatter 가 맞지 않는다: %s" % " · ".join(bad))
            b["assigned"] = bundle_ids(btext)
        except FormatError as exc:
            report["format_errors"].append("%s 묶음 — %s" % (b["id"], exc))
            continue
        union.update(b["assigned"])
    if report["format_errors"]:
        return report

    brief_path = unquote(meta["source_brief"])
    brief = src.read(brief_path)
    audit = src.read(brief_path[:-3] + ".audit.md") if brief_path.endswith(".md") else None
    try:
        if brief is None or audit is None:
            raise FormatError("brief 또는 audit 을 못 읽었다: %s" % brief_path)
        non_s, s_ids, k_expected = brief_universe(brief, audit)
    except FormatError as exc:
        report["unknown_reasons"].append("번호 전체 집합을 셀 수 없다 — %s" % exc)
    else:
        if risk_rows != k_expected:
            diff = [k for k, _ in k_expected if (k, dict(k_expected)[k]) not in risk_rows]
            report["format_errors"].append("위험 번호표가 brief §5 위험 줄과 다르다: %s"
                                           % (" · ".join(diff) or "줄 수가 다르다"))
        report["unassigned"] = sorted(non_s - union, key=id_sort_key)
        report["orphans"] = sorted(s_ids - union, key=id_sort_key)
        report["unknown_ids"] = sorted(union - non_s - s_ids, key=id_sort_key)

    cov_unknown = compute(git, main, blocks, records, bundles, roadmap_dir)
    report["unknown_reasons"] += ["번호 대조 검사 불가 — %s" % c for c in cov_unknown]
    report["overlaps"] = overlaps(blocks)
    for b in blocks:
        ids = b["assigned"]
        report["blocks"].append({
            "id": b["id"], "title": b["title"], "kind": b["kind"], "stage": b["stage"],
            "reason": b["reason"], "task_status": TASK_STATUS.get(b["stage"]),
            "branch": b["fields"].get("브랜치"), "deps": b["deps"], "specs": b["specs"],
            "ids": sorted(ids, key=id_sort_key), "warnings": b["warnings"]})
    return report


def exit_code(report: dict) -> int:
    if (report["format_errors"] or report["unknown_reasons"]
            or any(b["stage"] == "알 수 없음" for b in report["blocks"])):
        return 3
    if (any(b["warnings"] for b in report["blocks"]) or report["unassigned"]
            or report["orphans"] or report["unknown_ids"] or report["overlaps"]):
        return 1
    return 0


def render(report: dict) -> str:
    nwarn = sum(len(b["warnings"]) for b in report["blocks"])
    lines = ["로드맵 상태 — 블록 %d개 · 경고 %d개 · 검사 불가 %d개 (사본: %s · origin/main 받은 시각: %s)"
             % (len(report["blocks"]), nwarn,
                len(report["format_errors"]) + len(report["unknown_reasons"]),
                report["source"] or "알 수 없음", report["fetched_at"] or "알 수 없음"),
             report["notice"], ""]
    for b in report["blocks"]:
        lines.append("%s %s — %s · %s" % (b["id"], b["title"], b["stage"], b["reason"]))
        if b.get("ids"):
            lines.append("    번호: %s" % " · ".join(b["ids"]))
        lines += ["    경고: %s" % w for w in b["warnings"]]
    for label, key in (("미배정 번호", "unassigned"), ("고아 발화", "orphans")):
        vals = report[key]
        lines.append("%s: %s" % (label, "셀 수 없음" if vals is None
                                 else "%d개%s" % (len(vals), " — " + " · ".join(vals) if vals else "")))
    if report["unknown_ids"]:
        lines.append("brief 에 없는 번호: %s" % " · ".join(report["unknown_ids"]))
    lines.append("경로 예약 겹침: %d개" % len(report["overlaps"]))
    lines += ["    %s ↔ %s: %s" % (o["blocks"][0], o["blocks"][1], " · ".join(o["paths"]))
              for o in report["overlaps"]]
    lines += ["형식 깨짐: %s" % e for e in report["format_errors"]]
    lines += ["검사 불가: %s" % r for r in report["unknown_reasons"]]
    return "\n".join(lines)


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="roadmap_status.py",
                                 description="로드맵과 git 을 읽어 조각별 단계 · 경고를 낸다.")
    where = ap.add_mutually_exclusive_group(required=True)
    where.add_argument("roadmap", nargs="?", help="origin/main 기준 로드맵 레포 상대경로")
    where.add_argument("--roadmap-file", help="작업 트리의 로드맵 파일")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    report = build(Git(os.getcwd()), args)
    report["exit"] = exit_code(report)
    print(json.dumps(report, ensure_ascii=False, indent=2) if args.json else render(report))
    return report["exit"]


if __name__ == "__main__":
    sys.exit(main())
````

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh`
Expected: `Total: 67 | Pass: 67 | Fail: 0`

- [ ] **Step 5: 레포 락을 돌린다** — Task 2 Step 5 의 넷을 다시. 셋 다 `roadmap_status.py` 도 본다.

- [ ] **Step 6: 커밋**

```bash
git add --chmod=+x -- plugins/spec-distill/tests/test_roadmap_status.sh
git add -- plugins/spec-distill/scripts/roadmap_status.py
git commit -m "feat(spec-distill): 로드맵과 git 에서 조각 단계와 경고를 계산하는 읽기 전용 스크립트를 더한다" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/tests/test_roadmap_status.sh
```

---

### Task 4: 로드맵 · 조각 묶음 열 개 · 실데이터 테스트

**Files:**
- Create: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md`
- Create: 같은 디렉토리 `R1.md` `R2.md` `R2a.md` `R3.md` `R4.md` `R5.md` `R6.md` `R7.md` `R8.md` `R9.md` (조립기 출력)
- Modify: `plugins/spec-distill/tests/test_roadmap_status.sh` (끝의 `finish` 바로 앞에 실데이터 절)
- Modify: `docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md` (`## 번호 대조` 표에 두 행)
- 만듦(레포 밖, 커밋 안 함): `$HOME/.claude/sdd-mirror/r0-roadmap/assemble_bundles.py`

**Interfaces:**
- Consumes (Task 3): `parse_roadmap` · `brief_universe` · `overlaps`; (Task 2): `bundle_ids` · `table_ids` · `frontmatter` · `section_body` · `id_sort_key`
- Produces: 로드맵 블록 15개(P1 · P2 · R0 = 묶음 없는 브랜치 블록, P3 · P4 = 확인 · 결정 블록, 나머지 10 = 묶음 블록)

배정은 손으로 정한 것이다(B1). 원칙: 블록의 범위에 닿는 확정 C · D, 열린 질문(OQ 의 근거 RC 와 그 OQ 를 가리키는 «key» 를 함께), 위험 K, 그 확정들의 근거 발화 S. 모든 조각이 받드는 공통 묶음 `C25 · D26 · C32 · C35 · D21 · S1 · S13 · S17 · S18 · S30 · S34 · S49` 는 묶음마다 들어간다. 묶음끼리 겹쳐도 된다 — 미배정은 합집합으로 잰다. 의존은 승인 원문 S47 의 순서(R0 → R1‖R2‖R7‖R3‖R4‖R6 → R2a · R5 → R8 → R9)를 그대로 쓰고, 경로 예약이 겹치는 병렬 조각은 S47 순서의 뒤 조각이 앞 조각에 의존한다 — 그래서 R3 의존에 R2 가 있다(둘 다 `design-doc.md` 프로필을 고친다). R4 · R5 · R6 · R8 의 경로 예약은 「없음」이다 — 새로 만들 파일을 설계 전에 알 수 없어서이고, 그 조각의 설계가 정하면 작은 로드맵 PR 로 더한다.

- [ ] **Step 1: 실데이터 절을 테스트 끝(`finish` 앞)에 더한다**

````bash

# ── 7. 실데이터 — 이번 일의 로드맵 · 묶음(R0 AC1 · AC2 · AC3) ─────────────────
# git 없이 함수로 잰다 — origin 이 없는 클론에서도 같은 판정이 나야 한다.
real_check() {  # real_check <리포 루트> — 키<TAB>값 줄들
  (cd "$S" && python3 - "$1" <<'PY'
import sys
from pathlib import Path
import check_bundle_coverage as cbc, roadmap_status as rs, section6
root = Path(sys.argv[1])
rm = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose"
text = (root / rm / "roadmap.md").read_text(encoding="utf-8")
meta, blocks, records, risk, errors = rs.parse_roadmap(text)
print("ERRORS\t%s" % errors)
print("BLOCKS\t%s" % " ".join("%s:%s" % (b["id"], b["kind"]) for b in blocks))
brief = (root / meta["source_brief"]).read_text(encoding="utf-8")
audit = (root / meta["source_brief"].replace(".md", ".audit.md")).read_text(encoding="utf-8")
non_s, s_ids, k_expected = rs.brief_universe(brief, audit)
print("RISK\t%s" % (risk == k_expected and len(risk) == 15))
union, bad = set(), []
want6 = section6.body(brief).rstrip("\n") + "\n\n" + section6.body(audit)
s1 = cbc.section_body(brief, "## 1.")
for b in blocks:
    if b["kind"] != "bundle":
        union |= set(b["assigned"])
        continue
    bt = (root / rm / b["fields"]["묶음"]).read_text(encoding="utf-8")
    fm = cbc.frontmatter(bt)
    if (fm.get("type"), fm.get("slice"), fm.get("roadmap"), fm.get("source_brief")) != (
            "slice-bundle", b["id"], rm + "/roadmap.md", meta["source_brief"]):
        bad.append(b["id"] + ":frontmatter")
    union |= set(cbc.bundle_ids(bt))
    if [l for l in bt.splitlines() if l.startswith("## ")] != [
            "## 0. 역참조", "## 1. Goal · Non-goal", "## 2. 제약", "## 3. 열린 질문",
            "## 4. 웹 근거", "## 5. 기각 · 위험", "## 6. 사용자 원문", "## 7. 인터페이스"]:
        bad.append(b["id"] + ":절")
    if section6.body(bt) != want6:
        bad.append(b["id"] + ":§6")
    if bt.split("### 공통 목표\n", 1)[1].split("\n## 2. ", 1)[0] + "\n" != s1:
        bad.append(b["id"] + ":공통 목표")
    mine = bt.split("### 이 조각의 Goal · Non-goal\n\n", 1)[1].split("\n\n### 공통 목표", 1)[0]
    if mine.splitlines() != ["- 의도: " + b["fields"]["의도"], "- 범위: " + b["fields"]["범위"]]:
        bad.append(b["id"] + ":의도 · 범위")
print("BAD\t%s" % bad)
print("UNASSIGNED\t%s" % sorted(non_s - union, key=cbc.id_sort_key))
print("ORPHANS\t%s" % sorted(s_ids - union, key=cbc.id_sort_key))
print("UNKNOWN\t%s" % sorted(union - non_s - s_ids, key=cbc.id_sort_key))
print("OVERLAPS\t%s" % rs.overlaps(blocks))
r0 = next(b for b in blocks if b["id"] == "R0")
spec = (root / r0["fields"]["spec"]).read_text(encoding="utf-8")
print("R0TABLE\t%s" % (set(r0["assigned"]) == cbc.table_ids(spec)))
PY
  )
}
REAL="$(real_check "$ROOT")"
field_of() { printf '%s\n' "$REAL" | awk -F'\t' -v k="$1" '$1==k {print $2}'; }
assert_eq "$(field_of ERRORS)" "[]" "실데이터 AC1: 로드맵 형식 깨짐 없음"
assert_eq "$(field_of BLOCKS)" "P1:branch P2:branch P3:decision P4:decision R0:branch R1:bundle R2:bundle R7:bundle R3:bundle R4:bundle R6:bundle R2a:bundle R5:bundle R8:bundle R9:bundle" "실데이터 AC1: 블록 15개와 종류"
assert_eq "$(field_of RISK)" "True" "실데이터: 위험 번호표 K1~K15 가 brief §5 원문과 같다"
assert_eq "$(field_of BAD)" "[]" "실데이터 AC2: 묶음 10개의 frontmatter · 절 · §6 · 공통 목표 · 의도 · 범위가 바이트 그대로"
assert_eq "$(field_of UNASSIGNED)" "[]" "실데이터 AC3: 미배정 번호 0"
assert_eq "$(field_of ORPHANS)" "[]" "실데이터 AC3: 고아 발화 0"
assert_eq "$(field_of UNKNOWN)" "[]" "실데이터: brief 에 없는 번호 0"
assert_eq "$(field_of OVERLAPS)" "[]" "실데이터: 의존 없이 겹치는 경로 예약 0"
assert_eq "$(field_of R0TABLE)" "True" "실데이터: R0 블록의 항목 · 발화 = R0 설계문서 번호 대조 표의 첫 칸"
# 양성 대조 — 사본에서 묶음 하나의 번호를 빼고 다른 묶음의 §6 을 한 글자 바꾸면 위 검사가 잡는다
RMD=docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose
mkdir -p "$T/ctl/docs/superpowers/roadmaps" "$T/ctl/docs/superpowers/interview" "$T/ctl/docs/superpowers/specs"
cp -R "$ROOT/$RMD" "$T/ctl/docs/superpowers/roadmaps/"
cp "$ROOT"/docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview*.md "$T/ctl/docs/superpowers/interview/"
cp "$ROOT/docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md" "$T/ctl/docs/superpowers/specs/"
sed -i.bak 's/^ids: \[\(.*\), D46, /ids: [\1, /' "$T/ctl/$RMD/R7.md"
sed -i.bak 's/^  > 내 의도를 왜곡하는 장치들 다 제거야$/  > 내 의도를 왜곡하는 장치들 다 제거다/' "$T/ctl/$RMD/R2.md"
rm -f "$T/ctl/$RMD"/*.bak
CTL="$(real_check "$T/ctl")"
ctl_of() { printf '%s\n' "$CTL" | awk -F'\t' -v k="$1" '$1==k {print $2}'; }
assert_eq "$(ctl_of UNASSIGNED)" "['D46']" "양성 대조: 묶음에서 D46 을 빼면 미배정으로 잡힌다"
assert_contains "$(ctl_of BAD)" "R2:§6" "양성 대조: 묶음 §6 의 한 글자 변경을 잡는다"
````

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -3`
Expected: FAIL — 로드맵이 없어 실데이터 단언이 ✗.

- [ ] **Step 2: 로드맵을 쓴다**

`docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md`:

````markdown
---
type: roadmap
source_brief: docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md
---

# 집요한 탐색 · PM 분해 · 조각별 지휘 · 의도 왜곡 장치 제거 — 로드맵

승인된 분해안(S47)의 조각 지도다. 조각마다 「원본 brief + 이 로드맵 + 조각 묶음」을 넘긴다(D39). 상태 칸은 없다 — 단계는 `plugins/spec-distill/scripts/roadmap_status.py` 가 git 에서 계산한다.

## 조각

### P1 — 다음 세션 @ 명령 브랜치 머지
- 의도: 인터뷰 종료가 다음 세션 @ 명령으로 넘기게 하는 브랜치를 먼저 머지한다
- 범위: 한다 그 브랜치의 계획 실행 · 머지 / 안 한다 이번 로드맵의 조각 작업
- 의존: 없음
- 브랜치: feature/next-session-at-handoff
- 묶음: 없음
- 경로 예약: 없음
- spec: docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md
- 발화: S37
- 항목: D38 · OQ19 · RC17 · RC71

### P2 — qg v10 ⑤ 차등 테스트 머지
- 의도: qg 를 건드리는 조각 앞에 qg v10 ⑤ 차등 테스트를 머지한다
- 범위: 한다 그 브랜치 머지 / 안 한다 이번 로드맵의 qg 변경
- 의존: 없음
- 브랜치: feature/qg-v10-differential
- 묶음: 없음
- 경로 예약: 없음
- spec: docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md
- 발화: S47 · S51
- 항목: RC73 · RC77

### P3 — qg 진입 이름 결정
- 의도: qg 를 건드리는 조각 앞에 qg 진입 이름을 정한다
- 범위: 한다 진입 이름 결정 기록 / 안 한다 qg 코드 변경
- 의존: 없음
- 완료: 결정 기록
- 묶음: 없음
- 경로 예약: 없음
- 발화: S47 · S51
- 항목: RC85

### P4 — 옛 훅 쓰기 경로 브랜치 고아 확인
- 의도: 옛 훅 쓰기 경로 계획이 지금 없는 파일을 전제하는지 확인하고 처분을 정한다
- 범위: 한다 고아 여부 확인 · 처분 결정 기록 / 안 한다 그 계획의 구현
- 의존: 없음
- 완료: 결정 기록
- 묶음: 없음
- 경로 예약: 없음
- 발화: S47
- 항목: RC81

### R0 — 로드맵 · 조각 묶음 · 상태 계산의 걷는 뼈대
- 의도: 조각을 한 곳에서 보고 조각마다 받은 번호를 흘리지 않게 하는 가장 얇은 끝에서 끝까지를 만든다
- 범위: 한다 손으로 만든 로드맵 · 묶음 · 공통 형식 다섯 · 상태 계산 · 번호 대조 · 실측 M1~M3 · 락 지도 · 충돌표 / 안 한다 묶음 자동 생성 · 깊이 검사 · 컨트롤 플레인 · 지휘자 skill
- 의존: P1
- 브랜치: feature/interview-explore-decompose
- 묶음: 없음
- 경로 예약: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/, plugins/spec-distill/scripts/roadmap_status.py, plugins/spec-distill/scripts/check_bundle_coverage.py, plugins/spec-distill/tests/test_roadmap_status.sh, plugins/spec-distill/tests/test_bundle_coverage.sh
- spec: docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md
- 발화: S9 · S11 · S12 · S13 · S14 · S16 · S17 · S18 · S25 · S26 · S27 · S31 · S37 · S39 · S40 · S41 · S47 · S48 · S51
- 항목: C8 · C19 · D22 · D24 · D28 · D29 · D33 · C27 · D20 · D21 · D38 · C25 · D26 · D39 · D40 · D41 · D42 · D45 · D47 · OQ30 · OQ33 · C30 · OQ34 · OQ37 · OQ38 · RC18 · RC35 · RC36 · RC38 · RC72 · RC74 · RC75 · RC76 · RC78 · RC80 · K5 · K8 · K9 · K10 · K14 · K15

### R1 — 인터뷰 탐색 개편
- 의도: 인터뷰가 한 번에 닫지 않고 결정에 닿는 새 사실이 없을 때까지 조사하게 한다
- 범위: 한다 조사 장치 예산 · 자격 · 리듬 강제 · subagent 자리 제한의 제거 또는 수정 · 독립 판정자의 포화 판정 · 조사 상한 20회 · 문제 재구성 단계 제거 / 안 한다 압축 · 리뷰 장치(R2 · R2a) · 번호 인계(R3) · 분해(R4)
- 의존: R0
- 브랜치: feature/interview-persistent-explore
- 묶음: R1.md
- 경로 예약: plugins/spec-distill/skills/spec-interview/SKILL.md, plugins/spec-distill/skills/spec-interview/references/steelman.md, plugins/spec-distill/agents/coverage-mapper.md, plugins/spec-distill/agents/blind-spot-prober.md, plugins/spec-distill/agents/steelman-builder.md, plugins/spec-distill/scripts/check_brief.py, plugins/spec-distill/tests/test_conducting_interview_stage.sh

### R2 — spec-distill 안쪽 압축 · 리뷰 장치
- 의도: spec-distill 안에서 비용 · 압축으로 품질을 깎거나 사용자 결정을 덮는 장치를 제거하거나 공시 · 사용자가 여는 형태로 고친다
- 범위: 한다 압축 규약 · request-framing 압축 · seed · brief · 설계문서 리뷰 프로필의 절감 장치 · brief 템플릿 형식 제약 / 안 한다 인터뷰 조사 장치(R1) · 공유 리뷰 엔진과 qg(R2a)
- 의존: R0, P1
- 브랜치: feature/distill-distortion-devices
- 묶음: R2.md
- 경로 예약: plugins/spec-distill/references/compression.md, plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/references/docreview-profiles/seed.md, plugins/spec-distill/references/docreview-profiles/brief.md, plugins/spec-distill/references/docreview-profiles/design-doc.md, plugins/spec-distill/templates/interview-brief-template.md

### R7 — 상태 저장 재설계 흡수
- 의도: 미구현 상태 저장 재설계 결정 D1~D4 를 이 로드맵 위에서 구현한다
- 범위: 한다 인터뷰 상태는 docs · 임시 폴더는 리뷰 상태만 · 이어 하기는 로드맵 기반 · 긴 · 병렬 실행 중 리뷰 원장 소실 방지 / 안 한다 리뷰 엔진 동작 변경(R2a)
- 의존: R0
- 브랜치: feature/state-storage-redesign
- 묶음: R7.md
- 경로 예약: plugins/spec-distill/scripts/state_path.py, plugins/spec-distill/hooks/session-end-cleanup.py, plugins/spec-distill/scripts/spec-distill-gc.py

### R3 — 번호 인계 · 대조 · 깊이
- 의도: brief 의 모든 번호가 spec 까지 가고 빠지거나 얕으면 경고되게 한다
- 범위: 한다 넘김 글의 덮어쓰기 문장 제거 · /compact 보존에 조사 · 위험 · spec 리뷰에 묶음을 정해진 입력으로 넘기기 · 번호마다 깊이 검사 / 안 한다 묶음 생성(R4) · 표시(R6)
- 의존: R0, P1, R2
- 브랜치: feature/numbered-handoff-coverage
- 묶음: R3.md
- 경로 예약: plugins/spec-distill/skills/spec-interview/references/finishing.md, plugins/spec-distill/skills/spec-review/SKILL.md, plugins/spec-distill/references/proceed-gate.md, plugins/spec-distill/references/docreview-profiles/design-doc.md

### R4 — PM 분해 · 로드맵 · 조각 묶음 · 재분해 경로
- 의도: 인터뷰가 일을 조각으로 나눠 로드맵과 묶음을 내고 하류의 재분해 · 축소 신호를 같은 지도로 되돌리게 한다
- 범위: 한다 분해 판단 · 로드맵 · 묶음 자동 생성(R0 형식) · 재분해 경로 / 안 한다 지휘(R5) · 표시(R6)
- 의존: R0
- 브랜치: feature/interview-pm-decompose
- 묶음: R4.md
- 경로 예약: 없음

### R6 — 컨트롤 플레인
- 의도: 조각 지도 · 단계 · 빠진 것 · 드리프트 알림을 Claude Code 안에서 보이게 한다
- 범위: 한다 상태줄 · 패널 · 작업 목록 표시(M2 · M3 결과에 맞춤) / 안 한다 상태 계산 자체(R0 · R5)
- 의존: R0
- 브랜치: feature/roadmap-control-plane
- 묶음: R6.md
- 경로 예약: 없음

### R2a — 공유 리뷰 엔진 · qg 파급 · persona 보안 리뷰
- 의도: 공유 리뷰 엔진과 qg · 다른 플러그인의 의도 왜곡 장치를 제거하거나 고치고 persona 편집은 보안 리뷰를 거친다
- 범위: 한다 공유 리뷰 엔진 상한 · 조언 접기 · qg 리뷰어 · 루프 상한 · 다른 플러그인의 장치 / 안 한다 spec-distill 안쪽 장치(R2)
- 의존: R1, R2, R7, R3, R4, R6, P2, P3
- 브랜치: feature/shared-review-engine-devices
- 묶음: R2a.md
- 경로 예약: shared/docreview/, plugins/spec-distill/references/reviewing-document.md, plugins/quality-gates/, plugins/project-init/, plugins/plugin-audit/

### R5 — 지휘자
- 의도: 한 세션이 로드맵을 따라 조각을 끝까지 지휘하되 사용자의 결정권과 내용 검토가 남게 한다
- 범위: 한다 외부 정지는 사용자에게 · 실행 기록 회수 · 재개 · 부분 계속 · 머지 원칙 · qg 의도 회귀 · 조각 사이 이음매 · base 이동 · 구현 이후 단계 / 안 한다 상태줄 · 패널(R6)
- 의존: R1, R2, R7, R3, R4, R6, P2, P3
- 브랜치: feature/slice-conductor
- 묶음: R5.md
- 경로 예약: 없음

### R8 — 의존 선언 · 부재 시 강등 · devbrew 밖 경로
- 의도: 이 장치들이 devbrew 밖 레포와 superpowers 부재에서도 통하게 한다
- 범위: 한다 의존 최소 버전 선언 · 부재 시 강등 · 경로 규약 범용화 · squash · rebase 머지 자동 판정 / 안 한다 규칙 문서(R9)
- 의존: R2a, R5
- 브랜치: feature/dependency-portability
- 묶음: R8.md
- 경로 예약: 없음

### R9 — 규칙 · 문서 정리
- 의도: 바뀐 장치에 맞춰 레포 규칙 · 철학 · README · CHANGELOG 를 정리한다
- 범위: 한다 지출 승인 조항 · P22 개정 문안(사용자 승인) · 문서 정리 / 안 한다 장치 동작 변경
- 의존: R8
- 브랜치: feature/rules-docs-cleanup
- 묶음: R9.md
- 경로 예약: CLAUDE.md, docs/philosophy/devbrew-harness-philosophy.md

## 지휘 절차

R5 전까지 지휘 세션이 따르는 절차다. 장치가 아니라 절차다 — 지휘자 skill 은 R5 가 만든다. 지휘 세션은 `/new` 뒤 첫 줄에 `@docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` 를 붙여 연다.

1. `git fetch origin` → `python3 plugins/spec-distill/scripts/roadmap_status.py docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` → 작업 목록을 결과에 맞춘다. 조각 하나에 작업 하나, 제목은 「<번호> <이름> — <단계>」. 대기 · 준비는 시작 전, 설계 중 · 계획은 진행 중, 머지됨 · 끝남은 완료다. 알 수 없음은 작업 상태를 바꾸지 않고 제목 끝에 「알 수 없음(이유)」을 붙인다.
2. 준비 단계 조각을 고른다. 블록의 `브랜치:` 이름으로 `origin/main` 에서 브랜치와 worktree 를 먼저 만들고, 그 조각의 설계문서 · 계획은 모두 그 브랜치에 커밋한다. 설계 단계(brainstorming → 설계문서 → spec-review 승인)는 이 세션에서 한 조각씩 돈다 — spec 승인은 사용자가 조각마다 한다.
3. 설계문서를 커밋한 뒤 spec-review 를 부르기 전에 `python3 plugins/spec-distill/scripts/check_bundle_coverage.py <묶음> <설계문서>` 를 돌려 결과를 사용자에게 보인다. 빠진 번호가 있으면 spec-review 전에 고친다.
4. superpowers 가 묻는 자리(plan 검토 · 실행 방식 · 머지 메뉴)는 그대로 사용자에게 간다.
5. 구현은 조각마다 worktree 에서 돌리고 그동안 다음 조각의 설계를 진행하는 것이 목표다. 백그라운드 실행이 되는지는 실측 M1 이 정한다 — 안 되면 구현도 순차로 하고 그 사실을 알린다. SDD 가 마지막 메시지로 내는 판정 목록(「Rulings I made」)은 그대로 사용자에게 보이고 멈추지 않는다.
6. 조각이 머지될 때마다 남은 조각을 재평가하고, 바뀔 때만 사용자 승인 뒤 로드맵 수정을 전용 작은 브랜치(`feature/roadmap-<요지>`)와 PR 로 올린다. 머지는 사용자가 한다.
7. 구현 커밋에는 `Spec: <조각 설계문서 레포 상대경로>` 트레일러를 단다.

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. squash · rebase 로 머지해 머지 커밋이 없는 조각은 「머지」 줄로 적는다.

쉬운 말 PR 3(`feature/plain-language-voice`)은 이미 머지됐다(#198) — 선행 둘째의 그 부분은 블록을 두지 않는다.

## 재분해 이력

- 2026-10-11 · 처음 로드맵 · 승인 원문 S47 「이대로 승인 (권장) — 고친 분해안(선행 3: @ 브랜치 머지 · qg ⑤·PR3·진입 이름 · hook 브랜치 고아 확인 + R0~R9, 순서 @ 브랜치 → R0 → R1‖R2‖R7‖R3‖R4‖R6 → R2a·R5 → R8 → R9) 승인」 · 선행 3 을 P1~P4 블록으로 나눴다(R0 설계 §1).

## 위험 번호표

brief §5 의 번호 없는 위험 줄에 줄 순서대로 번호를 단다 — 숨은 가정 K1~K7 · 실패 양식 K8~K14 · 리뷰 참고 K15. 오른쪽은 brief 원문 그대로다.

- K1 — 위험 — 숨은 가정: 장치를 없애면 늘 의도를 지키는 쪽으로만 작동한다 — 멈춤 판정의 주인이 조사하는 모델 자신으로 옮겨 무한 조사·조기 「충분」 선언이 사용자 모르게 열린다 — 근거 포화 개념의 불안정·조기 종료 실패 양식·무한 루프 사례
- K2 — 위험 — 숨은 가정: plan·구현을 쭉 가는 것과 왜곡 장치 제거가 서로 맞는다 — 실행 중 혼자 판정(Ruling)은 쭉 가게 하는 장치이고 plan 검토 게이트는 PM 이 plan 을 볼 마지막 자리 — 근거 superpowers SDD·brainstorming 원문
- K3 — 위험 — 숨은 가정: 사용자 말 그대로가 하류에서도 그대로 읽힌다 — brainstorming 은 자기 이해 요약을 새 정본으로 삼아 조각 N개면 N번 재해석 — 근거 Cognition 병렬 에이전트·brainstorming 원문
- K4 — 위험 — 숨은 가정: 인터뷰 시점에 나눈 경계가 맞고 하류가 따른다 — 하류의 2차 분해와 충돌하고 승인된 분해가 봉인되기 쉽다 — 근거 ADaPT·brainstorming 분해 문구
- K5 — 위험 — 숨은 가정: 한 세션이 압축을 여러 번 겪어도 의도와 조각 지도를 잃지 않는다 — 근거 Anthropic 장시간 하니스
- K6 — 위험 — 숨은 가정: 조각이 늘어도 spec 승인이 실질 검토로 남는다 — 도장 찍기로 쇠퇴 — 근거 승인 피로(근거 약함)
- K7 — 위험 — 숨은 가정: 찾은 장치 목록이 완전하고 전부 왜곡이다 — 사용자 자신의 통제 자리가 섞여 있고 모델은 사용자 말에 맞추는 경향 — 근거 Sycophancy 연구
- K8 — 위험 — 실패 양식: 병렬 조각의 암묵 결정 충돌과 버전·CHANGELOG 같은 공유 파일 겹침 — 근거 Cognition·Anthropic 멀티에이전트
- K9 — 위험 — 실패 양식: 압축 뒤 조각 지도·결정 내력 소실 또는 덮어쓰기로 「한 곳」이 실제와 어긋남 — 근거 Anthropic 장시간 하니스
- K10 — 위험 — 실패 양식: 두꺼운 brief 의 역설 — 가운데 묻힌 조사·위험·열린 질문을 하류가 덜 씀 — 근거 Lost in the Middle
- K11 — 위험 — 실패 양식: 외부 문구가 바뀌면 devbrew 쪽 넘김 글이 조용히 무력화됨(설치본과 최신본이 이미 다름) — 근거 superpowers 원문 비교
- K12 — 위험 — 실패 양식: 무한 조사 또는 포화를 가장한 조기 종료 — 근거 무한 루프 사례·조기 종료 실패 양식
- K13 — 위험 — 실패 양식: spec 승인 하나만 남은 통제점이 도장 찍기로 무너지고 실행 판정이 보이지 않음 — 근거 승인 피로(근거 약함)
- K14 — 위험 — 실패 양식: 승인된 분해가 봉인돼 조각 사이를 되돌릴 경로가 없음 — 근거 ADaPT·재결정 규약이 확정 항목 단위뿐
- K15 — 위험 — 리뷰 참고 | [overdesign] #2-제약 — 번호로 추적하는 장치가 다섯 결정(D24·D40·D41·D42·D45)에 나뉘고 번호 체계가 셋이다(D24·D42 의 빠짐 경고는 같은 검사) — 사용자 발화 S 번호에 매단 원장 하나와 spec 리뷰 검사 하나로 합치는 쪽을 설계에서 검토한다(판정은 모두 남기고 구조만 합침) (리뷰 41df26ba#r1.1)
````

- [ ] **Step 3: 버리는 조립기를 쓴다**

`$HOME/.claude/sdd-mirror/r0-roadmap/assemble_bundles.py` — 목적지 파서로 먼저 확인한다: `python3 -m py_compile "$HOME/.claude/sdd-mirror/r0-roadmap/assemble_bundles.py"` 가 조용해야 한다.

````python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R0 묶음 조립기 — 버리는 도구(커밋하지 않는다). 배정 표와 인터페이스는 손으로 정한 것이고,
원문(brief §1 · §2 · §0 · §4 · §5 줄, brief §6 + audit §6)은 바이트 그대로 옮긴다.

쓰기: python3 assemble_bundles.py <리포 루트>
- 로드맵의 `## 위험 번호표` 절 끝에 K1~K15 줄을 붙인다(이미 있으면 그대로 둔다).
- 로드맵 옆에 R1~R9 · R2a 묶음을 쓴다(있으면 덮어쓴다).
"""
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
sys.path.insert(0, str(ROOT / "plugins/spec-distill/scripts"))
import section6  # noqa: E402

RM_DIR = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose"
ROADMAP = RM_DIR + "/roadmap.md"
BRIEF = "docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md"
AUDIT = BRIEF[:-3] + ".audit.md"

ALL = ["C25", "D26", "C32", "C35", "D21", "S1", "S13", "S17", "S18", "S30", "S34", "S49"]
OQ29_KEYS = ["«mast»", "«context-engineering»", "«chroma-context-rot»", "«claude4-best-practices»",
             "«chesterton-fence»", "«sycophancy»"]
DEVICE_COMMON = ["C5", "C11", "C12", "C13", "D15", "D18", "OQ2", "OQ29", "K7", "S3", "S4", "S5",
                 "S7", "S10", "S33"] + OQ29_KEYS
SLICES = {
    "R1": ["C1", "C3", "C4", "C10", "C14", "D16", "D23", "D43", "OQ1", "OQ3", "OQ7", "OQ25", "OQ32",
           "RC1", "RC2", "RC3", "RC4", "RC5", "RC14", "RC16", "RC18", "RC19", "RC21", "RC22", "RC23",
           "RC24", "RC25", "RC26", "RC34", "RC35", "RC36", "RC48", "RC59", "RC67", "ST3", "K1", "K12",
           "«anthropic-multiagent»", "«arxiv-2608.15191»", "«tianpan-convergence»",
           "«arxiv-2604.24978»", "«saunders-saturation»", "«infinite-agentic-loops»",
           "S2", "S6", "S8", "S15", "S43"] + DEVICE_COMMON,
    "R2": ["RC7", "RC28", "RC29", "RC30", "RC31", "RC32", "RC33", "RC39", "RC49", "RC50", "RC55",
           "RC66", "ST3"] + DEVICE_COMMON,
    "R2a": ["RC6", "RC51", "RC52", "RC53", "RC54", "RC56", "RC57", "RC58", "RC65", "RC85", "OQ31",
            "S51"] + DEVICE_COMMON,
    "R3": ["C1", "C2", "C17", "D24", "D40", "D41", "D42", "D45", "OQ4", "OQ5", "OQ8", "OQ9", "OQ21",
           "OQ22", "OQ23", "OQ24", "OQ27", "RC8", "RC9", "RC10", "RC27", "RC40", "RC41", "RC42",
           "RC43", "RC44", "RC45", "RC46", "RC69", "RC74", "RC75", "K3", "K10", "K11", "K15",
           "«contextchain»", "«lightrun»", "«bmad»", "«lost-in-middle»",
           "«superpowers-brainstorming-main»", "S9", "S16", "S38", "S40", "S41", "S42", "S45"],
    "R4": ["C1", "C6", "C9", "D16", "D20", "D28", "D39", "D47", "OQ3", "OQ5", "OQ11", "OQ12",
           "OQ17", "OQ21", "OQ36", "RC11", "RC20", "RC61", "RC68", "RC70", "ST1", "K4", "K14",
           "«bmad»", "«lost-in-middle»", "«taskmaster»", "«kiro-spec-batch»", "«recursive-sdd»",
           "«ralph-specum»", "«superpowers-issue-1173»", "«spec-kit-spec-of-specs»",
           "«eugenelim-pr11»", "«shapeup»", "«adapt»", "«decomposing-requirements-fork»",
           "S8", "S12", "S25", "S38", "S39", "S47", "S48", "S50"],
    "R5": ["C7", "C27", "C30", "C31", "C36", "C48", "D16", "D33", "D37", "OQ3", "OQ9", "OQ10",
           "OQ13", "OQ14", "OQ15", "OQ18", "OQ23", "OQ28", "OQ30", "OQ31", "RC38", "RC47", "RC63",
           "RC76", "RC77", "RC79", "RC85", "ST2", "K2", "K6", "K8", "K13",
           "«spec-kit»", "«approval-fatigue»", "«cc-subagents»", "«superpowers-repo»",
           "«anthropic-long-running»", "«superpowers-sdd»", "«anthropic-building-agents»",
           "«replit-incident»", "«cognition-multi-agents»", "«graphite-mergequeue»",
           "«mergify-queue»", "«worktree-merge-conflicts»", "«augment-worktrees»", "«cdc-contracts»",
           "«spec-drift-traceability»", "«coverge-regression»", "«arxiv-2604.03447»",
           "«arxiv-2606.26924»", "«arxiv-2608.13867»", "«cc-agent-teams»",
           "S8", "S19", "S20", "S21", "S22", "S23", "S24", "S27", "S28", "S29", "S31", "S35", "S36",
           "S51"],
    "R6": ["C7", "C8", "C17", "C19", "C27", "D22", "D23", "D33", "D41", "D43", "OQ4", "OQ6", "OQ34",
           "RC80", "K6", "K13", "S9", "S11", "S14", "S15", "S22", "S31", "S41", "S43"],
    "R7": ["D29", "D46", "OQ12", "OQ20", "OQ37", "RC15", "RC37", "RC60", "K5", "K9", "S26", "S46"],
    "R8": ["C30", "OQ33", "RC78", "RC82", "RC83", "K11", "S27"],
    "R9": ["C5", "C44", "D18", "D34", "OQ16", "OQ26", "OQ35", "RC12", "RC13", "RC14", "RC62", "RC64",
           "RC84", "S10", "S32", "S44"],
}
INTERFACES = {
    "R1": ("R0 의 다섯 형식(묶음 · 로드맵 · roadmap_status 출력 · 번호 대조 · `Spec:` 트레일러)",
           "포화 판정 결과와 조사 상한 도달 신호를 R6 이 읽을 자리에 · 바뀐 인터뷰 종료 조건을 R3 · R4 에"),
    "R2": ("R0 의 다섯 형식",
           "spec-distill 안쪽 장치의 처분(제거 · 수정) 목록을 R2a 와 R9 에"),
    "R2a": ("R0 의 다섯 형식 · P2 · P3 결과 · R2 의 처분 기준",
            "공유 엔진 변경을 qg 소비자와 R5 에 · persona 편집의 보안 리뷰 기록"),
    "R3": ("R0 의 묶음 · 번호 대조 형식과 `check_bundle_coverage.py`",
           "spec-review 가 묶음을 정해진 입력으로 받는 경로(R5 가 부른다) · 깊이 검사 결과(R6 이 보인다)"),
    "R4": ("R0 의 로드맵 · 묶음 형식(손으로 만든 이번 로드맵이 견본)",
           "인터뷰가 같은 형식으로 로드맵 · 묶음을 냄 · 재분해 신호를 R5 에"),
    "R5": ("R0 의 `roadmap_status.py` · 지휘 절차 · 실측 M1 · M4 · M5 · R3 의 spec-review 입력 경로 · P2 · P3",
           "구현 이후 단계와 판정 줄을 상태 계산에 더함 · 지휘자 skill"),
    "R6": ("`roadmap_status.py --json`(R0) · 실측 M2 · M3 · R1 포화 판정 · R3 깊이 경고 · R5 판정 줄",
           "상태줄 · 패널 · 작업 목록 표시"),
    "R7": ("R0 의 로드맵(이어 하기의 기반)",
           "인터뷰 상태를 docs 로, 임시 폴더는 리뷰 상태만 — R1 · R3 이 쓰는 state 경로"),
    "R8": ("R0 의 「devbrew 밖 레포」 한계 공시(§3 끝 · §4 2)",
           "의존 선언 · 부재 시 강등 · squash · rebase 머지 자동 판정을 R0 상태 계산에"),
    "R9": ("모든 조각의 규칙 변경 요구(OQ35 등)",
           "CLAUDE.md · 철학 문서 · README · CHANGELOG 정리"),
}
ORDER = ["R1", "R2", "R2a", "R3", "R4", "R5", "R6", "R7", "R8", "R9"]
PREFIX = ("C", "D", "OQ", "RC", "K", "ST", "S")


def key(t):
    if t.startswith("«"):
        return (9, 0, t)
    for i, p in enumerate(PREFIX):
        if t.startswith(p) and t[len(p):].isdigit():
            return (i, int(t[len(p):]), t)
    raise SystemExit("모르는 번호 %r" % t)


def section(text, prefix):
    lines = text.splitlines(keepends=True)
    start = next(i for i, l in enumerate(lines) if l.startswith(prefix))
    end = next((j for j in range(start + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
    return "".join(lines[start + 1:end])


brief = (ROOT / BRIEF).read_text(encoding="utf-8")
audit = (ROOT / AUDIT).read_text(encoding="utf-8")
roadmap_path = ROOT / ROADMAP
roadmap = roadmap_path.read_text(encoding="utf-8")

s5 = section(brief, "## 5.")
risks = []
for p in ("- 위험 — 숨은 가정", "- 위험 — 실패 양식", "- 위험 — 리뷰 참고"):
    risks += [l for l in s5.splitlines() if l.startswith(p)]
assert len(risks) == 15, len(risks)
k_lines = {"K%d" % (i + 1): "- K%d — %s" % (i + 1, l[2:]) for i, l in enumerate(risks)}
if "\n- K1 — " not in roadmap:
    roadmap = roadmap.rstrip("\n") + "\n\n" + "\n".join(k_lines.values()) + "\n"
    roadmap_path.write_text(roadmap, encoding="utf-8")

c_lines = {}
for l in section(brief, "## 2.").splitlines():
    m = re.match(r"- \S+ (?:confirmed|provisional) \*\*([CD]\d+)\*\* — ", l)
    if m:
        c_lines[m.group(1)] = l
oq_lines = {m.group(1): l for l in section(brief, "## 0.").splitlines()
            for m in [re.match(r"- (OQ\d+) ", l)] if m}
key_lines = {}
for l in section(brief, "## 4.").splitlines():
    for k in re.findall(r"«[^«»]+»", l):
        key_lines[k] = l
rc_lines, st_lines = {}, {}
for l in s5.splitlines():
    m = re.search(r" — (RC\d+) \(", l) or re.search(r"(RC22) \(", l)
    if m:
        rc_lines[m.group(1)] = l
    m = re.search(r" — (ST\d+) — ", l)
    if m:
        st_lines[m.group(1)] = l
s1_body = section(brief, "## 1.")
s6 = section6.body(brief).rstrip("\n") + "\n\n" + section6.body(audit)

blocks = {}
for m in re.finditer(r"(?m)^### (\S+) — (.+)\n((?:- .*\n)+)", roadmap):
    f = {}
    for l in m.group(3).splitlines():
        k, _, v = l[2:].partition(": ")
        f[k] = l
    blocks[m.group(1)] = (m.group(2), f)

for sid in ORDER:
    ids = sorted(set(SLICES[sid] + ALL), key=key)
    title, f = blocks[sid]
    rcst = [rc_lines[i] for i in ids if i.startswith("RC")] + \
           [st_lines[i] for i in ids if i.startswith("ST")] + \
           [k_lines[i] for i in ids if i.startswith("K")]
    keys = []
    for i in ids:
        if i.startswith("«") and key_lines[i] not in keys:
            keys.append(key_lines[i])
    recv, give = INTERFACES[sid]
    out = (
        "---\ntype: slice-bundle\nslice: %s\nroadmap: %s\nsource_brief: %s\nids: [%s]\n---\n\n"
        "# %s — %s · 조각 묶음\n\n"
        "## 0. 역참조\n\n"
        "- 원본 brief: `%s` (audit `%s`)\n"
        "- 로드맵: `%s` 의 `### %s` 블록\n"
        "- 이 조각의 설계문서는 frontmatter `source_interview:` 에 이 묶음 경로를, `roadmap:` 에 로드맵 경로를 적고, "
        "본문 `## 번호 대조` 표(칸: 번호 · 반영/기각 · 자리 또는 이유)에 위 `ids` 전부를 싣는다.\n\n"
        "## 1. Goal · Non-goal\n\n### 이 조각의 Goal · Non-goal\n\n%s\n%s\n\n### 공통 목표\n%s"
        "## 2. 제약\n\n%s\n\n"
        "## 3. 열린 질문\n\n%s\n\n"
        "## 4. 웹 근거\n\n%s\n\n"
        "## 5. 기각 · 위험\n\n%s\n\n"
        "## 6. 사용자 원문\n%s"
        "## 7. 인터페이스\n\n- 받는 것: %s\n- 넘기는 것: %s\n"
    ) % (sid, ROADMAP, BRIEF, ", ".join(ids), sid, title, BRIEF, AUDIT, ROADMAP, sid,
         f["의도"], f["범위"], s1_body,
         "\n".join(c_lines[i] for i in ids if i[0] in "CD" and i[1:].isdigit()) or "- 없음",
         "\n".join(oq_lines[i] for i in ids if i.startswith("OQ")) or "- 없음",
         "\n".join(keys) or "- 없음",
         "\n".join(rcst) or "- 없음",
         s6, recv, give)
    (ROOT / RM_DIR / (sid + ".md")).write_text(out, encoding="utf-8")
    print(sid, len(ids))
````

- [ ] **Step 4: 조립기를 돌린다**

Run: `python3 "$HOME/.claude/sdd-mirror/r0-roadmap/assemble_bundles.py" "$PWD"`
Expected (묶음마다 번호 수):
```
R1 81
R2 46
R2a 45
R3 59
R4 55
R5 78
R6 36
R7 24
R8 19
R9 28
```
로드맵의 위험 번호표는 이미 K1~K15 를 담고 있어 조립기가 건드리지 않는다(`git diff --stat -- docs/superpowers/roadmaps/` 에서 roadmap.md 는 Step 2 그대로).

- [ ] **Step 5: R0 설계문서 번호 대조 표에 두 행을 더한다**

`docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md` 에서 `| RC38 | 반영 | N6 |` 행 바로 아래에:

```markdown
| RC18 · RC35 · RC36 | 반영 | §7 락 지도 — 처분 줄 테스트 · 조사 예산 락 · 구조 게이트 하한 락을 `locks.md` 행으로 |
| RC72 | 반영 | §1 — 쉬운 말 PR 3 은 이미 머지됐다(#198), 로드맵 결정 기록에 적음 |
```

- [ ] **Step 6: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -1`
Expected: `Total: 78 | Pass: 78 | Fail: 0`
Run: `(cd plugins/spec-distill/tests && python3 -m unittest -q test_review_hook_removed)` → 기준보다 새 실패 없음(로드맵 디렉토리는 이 락의 면제 밖이다).

- [ ] **Step 7: 배정 표를 사람용으로 뽑아 둔다(AC4 에서 보인다)**

Run: `python3 plugins/spec-distill/scripts/roadmap_status.py --roadmap-file docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md`
Expected: 첫 줄 `로드맵 상태 — 블록 15개 · …`, P1 · P2 「머지됨」, R0 「계획」(Task 1 이 이 계획을 이 브랜치에 커밋했다), `미배정 번호: 0개` · `고아 발화: 0개` · `경로 예약 겹침: 0개`. 출력을 `$HOME/.claude/sdd-mirror/r0-roadmap/status-task4.txt` 로 남긴다.

- [ ] **Step 8: 커밋**

```bash
git add -- docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose plugins/spec-distill/tests/test_roadmap_status.sh docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md
git commit -m "docs(spec-distill): 이번 일의 로드맵과 조각 묶음 열 개를 손으로 만들고 실데이터 검사를 더한다" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose plugins/spec-distill/tests/test_roadmap_status.sh docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md
```

Expected: 커밋 파일 수 13(로드맵 1 · 묶음 10 · 테스트 1 · 설계문서 1).

---

### Task 5: 락 지도 · 충돌표 — `locks.md` 와 로드맵 의존

**Files:**
- Create: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/locks.md`
- Modify (필요할 때만): 같은 디렉토리 `roadmap.md` 의 `의존:` 줄
- 만듦(레포 밖): `$HOME/.claude/sdd-mirror/r0-roadmap/locks_grep.sh` · `conflicts.py`

**Interfaces:**
- Consumes (Task 3): `Git` · `merged_by` · `MAIN_REF` · `parse_roadmap` · `_reserves` · `_shared`

- [ ] **Step 1: 락 후보를 찾는 스크립트를 쓴다**

`$HOME/.claude/sdd-mirror/r0-roadmap/locks_grep.sh`:

````bash
#!/usr/bin/env bash
# 락 지도 초안 — 조각이 바꿀 동작을 잠근 테스트 줄을 찾는다. 리포 루트에서: bash locks_grep.sh
# 줄 형식: <조각>\t<근거>\t<파일:줄>\t<줄 앞 140자>
set -u
q() {  # q <조각> <근거> <ERE> <pathspec...>
  local slice="$1" why="$2" re="$3"; shift 3
  git grep -n -E -e "$re" -- "$@" 2>/dev/null | head -n 12 | while IFS= read -r hit; do
    printf '%s\t%s\t%s\t%s\n' "$slice" "$why" "${hit%%:*}:$(printf '%s' "$hit" | cut -d: -f2)" "$(printf '%s' "$hit" | cut -d: -f3- | cut -c1-140)"
  done
}
T='plugins/*/tests/*' ; ST='shared/tests/*'
q R1 "RC35 조사 장치 예산 식"       'coverage_mapper_dispatches|blind_spot_dispatches|1 \+ (재개방|reopen)' "$T"
q R1 "RC36 구조 게이트 coverage-mapper 하한" 'coverage-mapper [0-9]|k ?>= ?1|coverage_mapper' plugins/spec-distill/tests/test_check_brief.sh
q R1 "RC3 리듬 강제(답 없는 조사 3회)" 'RHYTHM_GUARD|non_user_streak' "$T"
q R1 "RC24 되묻기 2회"              '되묻기' "$T"
q R1 "RC48 문제 재구성 의례"          '재구성' plugins/spec-distill/tests
q R1 "RC18 처분 줄"                '처분\*\*|consumer=' shared/tests/test_dispatch_disposition.sh
q R2 "RC29 확정 목록 수정 2회"       'confirm_repost_count|재제시' "$T"
q R2 "RC55 선택지 라벨 1–5 낱말"     '1[–-]5 ?(낱말|단어|words)' "$T" "$ST"
q R2 "RC30 압축 규약"              'compression\.md' "$T"
q R2a "RC6 · RC56 · RC65 재리뷰 상한" 'rereview|재리뷰 상한|REREVIEW|cap.?2' "$T" "$ST"
q R2a "RC57 조언 8줄 접기"          'cap 8|--cap|접기' "$ST"
q R2a "RC51 qg 리뷰어 · 루프 상한"    '리뷰어 8|max.?iter|MAX_ITER|5회' plugins/quality-gates/tests
q R2a "RC58 산출물 비평 5라운드"      '5 ?라운드|rounds?.?5|ROUNDS' plugins/quality-gates/tests
q R3 "RC10 덮어쓰기 문장"           '우선한다' "$T"
q R3 "RC9 /compact 보존 목록"       'compact' plugins/spec-distill/tests/test_proceed_gate_adopters.sh plugins/spec-distill/tests/test_handoff_design_mode.sh
q R7 "RC37 SessionEnd · TTL-GC"   'TTL|24 ?시간|ttl' "$T"
````

- [ ] **Step 2: 돌려서 후보를 본다**

Run: `bash "$HOME/.claude/sdd-mirror/r0-roadmap/locks_grep.sh" > "$HOME/.claude/sdd-mirror/r0-roadmap/locks-hits.tsv"`
Expected: 2026-10-11 측정 기준 근거별 3~12건(RC9 는 0건일 수 있다 — 0건이면 그 근거는 「찾지 못함」 행으로 쓴다). 후보마다 그 줄을 열어 「그 조각이 바꿀 동작을 실제로 잠그는가」를 읽고 고른다 — 이름만 같은 줄은 버린다.

- [ ] **Step 3: 충돌표 스크립트를 쓴다**

`$HOME/.claude/sdd-mirror/r0-roadmap/conflicts.py`:

````python
#!/usr/bin/env python3
# 충돌표 초안 — 진행 중 브랜치(머지 안 된 것) × 로드맵 경로 예약. 읽기만 한다.
# 쓰기: python3 conflicts.py <리포 루트> <로드맵 파일>
import subprocess
import sys
from pathlib import Path

root, roadmap = sys.argv[1], sys.argv[2]
sys.path.insert(0, sys.argv[3] if len(sys.argv) > 3 else str(Path(root) / "plugins/spec-distill/scripts"))
import roadmap_status as rs  # noqa: E402

g = rs.Git(root)
main = g.commit(rs.MAIN_REF)
merges = g.first_parent_merges()
_, blocks, _, _, errors = rs.parse_roadmap(Path(roadmap).read_text(encoding="utf-8"))
assert not errors, errors
out = subprocess.run(["git", "-C", root, "for-each-ref", "--format=%(refname)",
                      "refs/heads", "refs/remotes/origin"], capture_output=True, text=True).stdout
seen = {}
for ref in out.split():
    name = ref.split("/", 3)[-1] if ref.startswith("refs/remotes/") else ref[len("refs/heads/"):]
    if name in ("main", "HEAD") or name in seen:
        continue
    seen[name] = ref
mine = {b["fields"].get("브랜치") for b in blocks}
print("| 진행 중 브랜치 | 머지 여부 | 겹치는 예약 경로 | 조각 |")
print("|---|---|---|---|")
for name, ref in sorted(seen.items()):
    tip = g.commit(ref)
    merged = rs.merged_by(g, merges, main, name, tip)
    if merged or name in mine:
        continue
    files = [f for f in g.changed(main, tip) if not rs._shared(f)]
    hits = []
    for b in blocks:
        for f in files:
            if any(rs._reserves(e, f) for e in b["reserved"]):
                hits.append((f, b["id"]))
    paths = sorted({f for f, _ in hits})
    print("| `%s` | 안 됨 (변경 파일 %d개) | %s | %s |" % (
        name, len(files), " · ".join(paths) or "없음",
        " · ".join(sorted({b for _, b in hits})) or "—"))
````

- [ ] **Step 4: 충돌표를 뽑는다**

Run: `git fetch origin` 다음 `python3 "$HOME/.claude/sdd-mirror/r0-roadmap/conflicts.py" "$PWD" docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md`
Expected (2026-10-11 측정): 머지 안 된 진행 중 브랜치 중 경로 예약과 겹치는 것은 둘 — `fix/plain-language-qg-findings`(qg · `shared/docreview/` 18파일 → R2a) · `qg-review/python-floor-uv`(qg · project-init 16파일 → R2a). P1 · P2 와 옛 훅 구현 브랜치(`fix/hook-write-path-bypass-impl`, #134)는 이미 머지돼 표에 없다.

- [ ] **Step 5: `locks.md` 를 쓴다**

모양(행은 Step 2 · 4 결과로 채운다 — 아래 충돌표 두 행은 측정값 그대로):

```markdown
# 락 지도 · 충돌표 — R0

조각이 바꿀 동작을 잠근 테스트와, 진행 중 브랜치와 조각 경로 예약의 겹침이다. 찾은 수는 하한이다 — 조각마다 착수할 때 `locks_grep.sh` 와 같은 검색을 다시 한다. 처리의 기본은 「그 조각이 같은 PR 에서 고친다」.

## 락 지도

| 테스트 파일:줄 | 잠근 동작 | 바꿀 조각 | 처리 |
|---|---|---|---|
| (locks-hits.tsv 에서 고른 줄마다 한 행) | (그 줄이 고정하는 값 · 문구) | R1 등 | 그 조각이 같은 PR 에서 고친다 |

## 충돌표

측정: <YYYY-MM-DD> `git fetch` 직후, `origin/main` <짧은 SHA>.

| 진행 중 브랜치 | 겹치는 예약 경로 | 조각 | 처리 |
|---|---|---|---|
| `fix/plain-language-qg-findings` | (Step 4 출력의 경로) | R2a | R2a 착수 전에 그 브랜치의 머지 또는 폐기를 확인한다(지휘 절차 2). 로드맵 블록으로 둘지는 AC4 승인 때 사용자가 정한다 |
| `qg-review/python-floor-uv` | (Step 4 출력의 경로) | R2a | 위와 같다 |

로드맵 블록끼리의 겹침은 `roadmap_status.py` 의 「경로 예약 겹침」이 잰다 — 지금 0개(R3 → R2 의존으로 풀었다).
```

- [ ] **Step 6: 의존을 반영한다**

충돌표의 겹침이 로드맵 블록(P1~P4)과 닿으면 그 조각 `의존:` 에 그 블록을 더한다(설계 예: R3 → P1, R2a · R5 → P2 · P3 — 지금 로드맵에 이미 있다). 블록이 아닌 브랜치는 위 처리 칸으로만 다룬다. 바꿨으면 Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -1` → `Fail: 0`.

- [ ] **Step 7: 커밋**

```bash
git add -- docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose
git commit -m "docs(spec-distill): R0 락 지도와 진행 중 브랜치 충돌표를 더한다" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose
```

---

### Task 6: 실측 M1~M3 — `measurements.md` (지휘 세션이 직접, subagent 에 맡기지 않는다)

M2 는 사용자가 `/compact` · `/new` 를 쳐야 하고 M1 은 subagent 를 부르는 쪽이 지휘 세션이어야 해서, 이 Task 는 구현 subagent 가 아니라 지휘 세션이 사용자와 함께 한다.

**Files:**
- Create: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md`

- [ ] **Step 1: 버전을 적는다**

Run: `claude --version` · `ls "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/"`
기록: Claude Code 버전 · superpowers 버전 · 날짜.

- [ ] **Step 2: M1 — 버릴 레포를 만든다(devbrew 밖)**

```bash
M1="$HOME/.claude/sdd-mirror/r0-m1/toy"
mkdir -p "$M1" && git -C "$M1" init -q -b main && printf '# toy\n' > "$M1/README.md"
mkdir -p "$M1/docs/superpowers/plans"
printf '# Toy Plan\n\n**Goal:** hello 파일 둘\n\n### Task 1: hello.txt\n- [ ] Step 1: `printf hi > hello.txt` 후 커밋\n\n### Task 2: hello2.txt\n- [ ] Step 1: `printf hi2 > hello2.txt` 후 커밋\n' > "$M1/docs/superpowers/plans/toy.md"
git -C "$M1" add -A && git -C "$M1" -c user.name=t -c user.email=t@example.invalid commit -qm init
```

- [ ] **Step 3: M1 — 백그라운드 subagent 둘을 부른다**

Agent 도구로(모델 지정 없음 — fable 금지), 각 프롬프트에 「`$M1` 절대경로 밖은 건드리지 마라」를 넣는다:
- (a) `isolation: "worktree"` 로 general-purpose: 「`<M1 절대경로>` 에서 `Skill superpowers:brainstorming` 을 `toy: 인사 파일 추가` 로 불러라. 첫 질문을 사용자에게 물을 수 있었는지(AskUserQuestion 도구가 있었는지), 막혔다면 어디서 어떻게 막혔는지 원문 그대로 보고하라.」
- (b) general-purpose: 「`<M1 절대경로>` 에서 `Skill superpowers:subagent-driven-development` 를 `docs/superpowers/plans/toy.md` 로 돌려라. 자기 subagent 를 부를 수 있었는지(Agent 도구), 어디까지 갔고 어디서 멈췄는지 원문 그대로 보고하라.」
(b) 가 도는 동안 지휘 세션에서 작업 목록이 보이는지 확인한다(M2 의 「백그라운드 작업 중」).

- [ ] **Step 4: M2 — 작업 목록의 생존**

TaskCreate 로 작업 둘(「M2 확인 A」 · 「M2 확인 B」)을 만들고 TaskList 결과를 적는다. 사용자에게 `/compact` 를 부탁하고 뒤에 TaskList 를 다시 적는다. 이어서 사용자에게 `/new` 를 부탁하고, 새 세션 첫 줄로 이것을 넣게 한다:
`@docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md TaskList 로 「M2 확인 A」 · 「M2 확인 B」가 보이는지 확인하고 그 결과를 이 파일 M2 절 「/new 뒤」 줄에 원문 그대로 적어라.`

- [ ] **Step 5: M3 — 플러그인이 상태줄을 줄 수 있는가**

claude-code-guide agent 에게: 「Claude Code 플러그인이 상태줄(statusLine)을 제공할 수 있는가, 아니면 사용자 설정(settings.json)뿐인가. 공식 문서 근거 URL 과 함께.」 문서가 「가능」이거나 모호하면 격리 설치(`CLAUDE_CONFIG_DIR=<빈 임시 디렉토리>` — 쓰기 전에 빈 디렉토리임을 먼저 확인)로 확인한다. 로그인이 필요해 못 하면 「격리 설치 실측 못 함(로그인 필요)」을 따로 한 줄로 적는다 — 못 잰 것과 없는 것은 다르다.

- [ ] **Step 6: `measurements.md` 를 쓴다**

```markdown
# 실측 — R0

설계문서에는 결과를 적지 않는다. 결과가 바꾸는 조각은 표의 마지막 칸이다.

| # | 묻는 것 | 결과(한 줄) | 바꾸는 것 |
|---|---|---|---|
| M1 | 백그라운드 subagent(worktree 격리)에서 brainstorming 이 사용자에게 물을 수 있는가 · SDD 가 자기 subagent 를 부르며 끝까지 가는가 | (Step 3) | R5(OQ30) |
| M2 | 지휘 세션의 작업 목록이 /compact · /new 뒤와 백그라운드 작업 중에 남고 보이는가 | (Step 4) | R6(OQ34) |
| M3 | 플러그인이 상태줄을 제공할 수 있는가, 사용자 설정뿐인가 | (Step 5) | R6(OQ34) |
| M4 | 조각 하나를 거치며 superpowers 가 사용자를 기다린 자리 | R1 걷기에서 | D37 확인 · R5 |
| M5 | 지휘 세션이 brainstorming → spec-review → 승인 → writing-plans 를 이어 부른 뒤 지휘 절차로 돌아오는가 | R1 걷기에서 | R5(OQ30) |

## M1
- 날짜 · Claude Code 버전 · superpowers 버전:
- 방법: (Step 2 · 3)
- 원 출력 (a):
- 원 출력 (b):

## M2
- 날짜 · 버전:
- 만든 직후:
- 백그라운드 작업 중:
- /compact 뒤:
- /new 뒤:

## M3
- 날짜 · 버전:
- 문서 근거:
- 격리 설치:

## M4 — R1 걷기에서

## M5 — R1 걷기에서
```

M1 가설(설계 §6): subagent 는 사용자에게 묻지 못한다. 결과가 가설과 다르면 표의 결과 칸에 그 사실을 쓴다.

- [ ] **Step 7: 커밋**

```bash
git add -- docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md
git commit -m "docs(spec-distill): R0 실측 M1~M3 를 기록하고 M4 · M5 자리를 둔다" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md
```

---

### Task 7: 설계문서 정리 · 버전 · 스위트 비교

**Files:**
- Modify: `docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md` (Handoff Context · §4 2 · AC5 · 결정 기록)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/README.md`

- [ ] **Step 1: Handoff Context 에 2~4라운드 결정을 더한다**

`- brainstorming 결정: …` 줄을 이것으로 바꾼다:

```markdown
- brainstorming 결정: `## 결정 기록` B1~B5. spec 리뷰 결정: 1라운드 D1.1 · D1.2 · B6 · B7 · 2라운드 D2.3(머지 방식 한계 공시 + 손 기록 대체) · 3라운드 B8(추가 라운드, 참고 지적 반영) · 4라운드 D4.24(첫째 부모 이력) · B9(추가 라운드 닫음).
```

- [ ] **Step 2: §4 2 의 메시지 규칙을 넓힌다(사용자가 받아들였을 때만)**

§4 2 둘째 항목을 이것으로 바꾼다:

```markdown
   - `origin/main` 의 첫째 부모 이력에 있는 머지 커밋 메시지 `from <owner>/<브랜치>` 의 브랜치 부분이 로드맵의 브랜치 이름과
     **정확히** 같고, 브랜치가 지워졌거나 남은 브랜치 끝이 `origin/main` 에 다 들어 있다(머지 뒤 로컬 브랜치를 main 으로
     앞당긴 경우). 머지 뒤 커밋이 더 붙은 브랜치는 머지됨이 아니다.
```

AC5 의 픽스처 나열에 `머지 뒤 main 으로 앞당긴 로컬 브랜치(머지됨) · 머지 뒤 커밋이 더 붙은 브랜치(머지됨이 아님) · ` 를 `머지 뒤 지운 브랜치 · ` 바로 뒤에 넣는다. `## 결정 기록` 의 B9 줄 다음에 `- B10 — 계획 검토 때 머지 메시지 규칙 확장: 「넓힌다 (권장)」.` 을 더한다. (2026-10-11 계획 검토에서 사용자가 받아들였다 — 되돌리기는 하지 않는다.)

- [ ] **Step 3: 버전을 정한다(N6 — 이 Step 은 PR 머지 직전에 다시 확인한다)**

Run: `git fetch origin` 다음 `git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json | grep '"version"'` → 지금 `5.2.0` 이면 새 버전은 `5.3.0`(main 의 바로 다음 minor). `plugin.json` 의 `"version"` 만 바꾼다(`description` 그대로).

`CHANGELOG.md` 맨 위 `# Changelog` 다음에:

```markdown
## [5.3.0] — <오늘 YYYY-MM-DD>

### Added
- `scripts/roadmap_status.py` — 로드맵과 git 을 읽어 조각마다 단계(대기 · 준비 · 설계 중 · 계획 · 머지됨 · 끝남 · 알 수 없음)와 경고(생략 · 경로 예약 위반 · 의존 미머지 진행 · 묶음 없음 · spec 여럿 · 미배정 번호 · 고아 발화 · 경로 예약 겹침)를 낸다. 읽기만 하고 fetch 하지 않는다. 기본은 `origin/main` 의 로드맵, 아직 main 에 없으면 `--roadmap-file`. 머지됨 자동 판정은 merge commit 방식에서만 되고, squash · rebase 는 로드맵 결정 기록의 머지 줄로 대신한다.
- `scripts/check_bundle_coverage.py` — 조각 묶음 `ids:` 가 설계문서 `## 번호 대조` 표에 다 있는지 본다. 빠지면 1, 표 깨짐 · 절 없음이면 3.
- `tests/test_roadmap_status.sh` · `tests/test_bundle_coverage.sh` — 버릴 git 레포 픽스처의 단계 · 경고, 읽기 전용 검사, 이번 일의 로드맵 · 묶음 실데이터 검사.
```

`README.md` 의 `## Hooks Installed` 바로 앞에:

```markdown
## 로드맵 · 조각 묶음

큰 일을 조각으로 나눠 진행할 때 쓰는 읽기 전용 스크립트 둘이 있습니다. 둘 다 파일을 쓰지 않고 네트워크에 나가지 않습니다.

- `scripts/roadmap_status.py <로드맵 경로>` — `origin/main` 의 로드맵과 git 을 읽어 조각마다 단계와 경고를 냅니다. 아직 main 에 없는 로드맵은 `--roadmap-file <파일>` 로 줍니다. 머지됨 자동 판정은 merge commit 방식에서만 됩니다.
- `scripts/check_bundle_coverage.py <묶음> <설계문서>` — 조각 묶음의 번호가 설계문서 `## 번호 대조` 표에 다 있는지 봅니다.

종료 코드는 둘 다 0 이상 없음 · 1 경고 · 2 사용법 오류 · 3 검사 불가입니다. 형식은 `docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md` §3 에 있습니다.
```

- [ ] **Step 4: 스위트를 다시 돌려 기준과 비교한다**

Run: `bash "$HOME/.claude/sdd-mirror/r0-roadmap/baseline.sh" "$HOME/.claude/sdd-mirror/r0-roadmap/after"` 다음
`bash -c 'comm -13 <(sort -u "$HOME/.claude/sdd-mirror/r0-roadmap/before.names") <(sort -u "$HOME/.claude/sdd-mirror/r0-roadmap/after.names")'`
Expected: 빈 출력(새 실패 줄 없음, AC11). 새 줄이 있으면 그 테스트를 읽고 고친다 — 고칠 수 없는 것은 사유와 함께 보고한다.

- [ ] **Step 5: AC10 diff 확인**

Run: `git diff --name-only origin/main...HEAD`
Expected: 이 계획이 만든 파일만 — `docs/superpowers/{interview,roadmaps,specs,plans}/…` · `plugins/spec-distill/{scripts,tests}/` 의 새 넷 · `plugins/spec-distill/{.claude-plugin/plugin.json,CHANGELOG.md,README.md}`. @ 브랜치의 네 파일과 레포 밖 경로가 없다.

- [ ] **Step 6: 커밋**

```bash
git add -- docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
git commit -m "docs(spec-distill): 5.3.0 — 로드맵 상태 계산과 번호 대조를 README · CHANGELOG 에 싣고 설계문서를 정리한다" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
```

---

### Task 8: 승인 · PR (지휘 세션)

- [ ] **Step 1: AC4 — 로드맵과 배정 표를 사용자에게 보이고 승인받는다**

Run: `python3 plugins/spec-distill/scripts/roadmap_status.py --roadmap-file docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md`
보일 것: 블록 15개의 단계와 번호(출력 그대로) · 미배정 0 · 고아 0 · 겹침 0 · 충돌표의 R2a 두 브랜치 · 옛 훅 구현 브랜치가 이미 머지됐다는 사실(#134 — P4 결정의 재료). AskUserQuestion 하나에 결정 하나로 묻는다: 승인 / 고칠 곳. 고치면 Task 4 의 배정 표(조립기 `SLICES`)나 로드맵을 고치고 조립기를 다시 돌린 뒤 실데이터 테스트를 다시 통과시킨다.

- [ ] **Step 2: PR 을 연다(승인 뒤)**

Run: `git push -u origin feature/interview-explore-decompose` 다음 `gh pr create --base main --title "feat(spec-distill): R0 — 로드맵 · 조각 묶음 · 상태 계산의 걷는 뼈대" --body-file <본문 파일>`
본문: 한 일 · AC 별 확인 결과(스위트 비교 · 실데이터 · 실측 표) · 넓힌 머지 규칙(Review Focus 1) · 충돌표 · 남은 한계(M4 · M5 는 R1 걷기에서). 끝 줄 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

- [ ] **Step 3: 머지 직전(AC13)**

P1 은 이미 머지됐다(#199). 머지 직전에 `git fetch origin` → `git merge --no-edit origin/main` → Task 7 Step 3(버전이 main 의 바로 다음인지) · Step 4(스위트 비교)를 다시 돈다. 머지는 사용자가 `! gh pr merge <번호> --merge` 로 한다. 머지 뒤 지휘 절차의 첫 일은 R1 걷기다(설계 §7).
