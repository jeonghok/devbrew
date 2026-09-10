# seed `@경로` 핸드오프 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** framing 게이트의 핸드오프를 `/interview @<seed 경로>` 로 바꾸고(권장 = `/new` 후 그 명령), `/interview` 입구가 `@경로` 를 파일 전문으로 풀어 하류에 넘기게 한다.

**Architecture:** 동작 변화는 두 곳이다 — `commands/interview.md` 에 새 Step 1.5(「풀린 입력」)를 두고 Step 2·2.5·3 이 그 값을 쓰게 한다. `framing-requests/SKILL.md` 의 게이트 옵션·호출 모양·두 가드·이름 가드를 새 모양으로 바꾼다. 공유 계약 `references/proceed-gate.md` 는 ①/② 를 「권장/차선 핸드오프」로 일반화하고, 나머지 문서는 문구만 동기화한다. 모든 단언은 새 테스트 하나(`tests/test_seed_at_path_handoff.sh`)에 모이고, 태스크마다 자기 단언을 먼저 더한 뒤(RED) 구현한다(GREEN).

**Tech Stack:** bash 3.2 (macOS 시스템 bash) 셸 락 + `shared/tests/assert.sh` · python 3.9 (`python3 -m unittest`) · 헤드리스 `claude -p` (V4 실동작).

**Spec:** `docs/superpowers/specs/2026-09-10-seed-at-path-handoff-design.md` — §1(framing 게이트) · §2(공유 계약) · §3(`/interview` Step 1.5) · §4(문구 동기화) · AC1–AC11 · V1–V5 · 「Deferred to plan」 표.

## 목차

- [Global Constraints](#global-constraints)
- [File Structure](#file-structure)
- [태스크 순서와 의존](#태스크-순서와-의존)
- [착수 전 baseline](#착수-전-baseline)
- [Task 0: pre-flight — base 이동량 · baseline 재측정 · 변이 도구](#task-0-pre-flight--base-이동량--baseline-재측정--변이-도구)
- [Task 1: `/interview` Step 1.5 와 「풀린 입력」](#task-1-interview-step-15-와-풀린-입력)
- [Task 2: framing 게이트 — 옵션 표 · 호출 모양 · 두 가드 · 이름 가드](#task-2-framing-게이트--옵션-표--호출-모양--두-가드--이름-가드)
- [Task 3: 공유 계약 일반화](#task-3-공유-계약-일반화)
- [Task 4: 문구 동기화와 옛 호출 모양 부재 락](#task-4-문구-동기화와-옛-호출-모양-부재-락)
- [Task 5: 버전 · CHANGELOG · 전체 스위트 · 범위 확인](#task-5-버전--changelog--전체-스위트--범위-확인)
- [Task 6: 실동작 측정(V4)과 사람이 할 관측 둘](#task-6-실동작-측정v4과-사람이-할-관측-둘)

## Global Constraints

모든 태스크의 요구에 이 절이 암묵으로 포함된다.

- **작업 위치** — 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+handoff-gate-reorder`, 브랜치 `feature/handoff-gate-reorder`. 모든 경로는 이 워크트리 기준이다. 메인 체크아웃(`/Users/jeonghokim/Downloads/devbrew`)의 같은 이름 파일을 고치거나 커밋하지 않는다 — 다른 세션이 공유한다. 하위 에이전트에게는 이 절대경로를 그대로 넘긴다.
- **격리 가드** — 이 세션의 Bash 는 `git -C`, 명령 인자 자리에 오는 셸 변수, 복잡한 복합 명령을 거부한다. 그런 명령은 git 이 무시하는 `.claude/handoff-baseline/` 아래 스크립트 파일로 만들어 `bash <파일>` 로 돌린다.
- **셸** — bash 3.2. `mapfile`·`declare -A`·`${var^^}` 금지. `$( )` 안에 heredoc 을 넣지 않는다. awk 정규식의 점은 `[.]` 로 쓴다(`-v` 로 넘긴 `\.` 는 경고와 함께 `.` 이 된다).
- **검색** — 리포 전체 검색은 `git grep -n` 을 쓴다. 셸 `grep -r <pat> .` 은 숨김 디렉토리(`.claude/`)를 건너뛴다.
- **python** — `PYTHONDONTWRITEBYTECODE=1` 을 붙이고 `python3 -m unittest` 로만 돌린다.
- **범위 밖(diff 0)** — `plugins/spec-distill/skills/reviewing-spec/` 전체 · `plugins/spec-distill/skills/conducting-interview/SKILL.md`. `conducting-interview/references/finishing.md` 는 S1 규칙 단락(41–44행) 한 문장만 바뀐다.
- **사용자가 철회한 것** — `reviewing-spec` 승인 게이트의 순서 변경은 하지 않는다. 다시 제안하지도 않는다.
- **「풀린 입력」** — `/interview` Step 1.5 의 결과를 가리키는 이름이다. 이 철자(꺾쇠 인용부호 포함)를 모든 자리에서 그대로 쓴다.
- **플러그인 파일 위생** — 설계 문서의 식별자(AC#, NG#, D#, R#, OQ#, §A)를 플러그인 파일에 적지 않는다. 이미 있는 `AC19`(가드 2 제목)는 그대로 둔다. 근거와 이력은 CHANGELOG 에 적는다(Self-narrating artifact 금지).
- **커맨드 본문의 `$ARGUMENTS`** — Claude Code 가 입력 문자열로 **텍스트 치환**한다. 그래서 `commands/interview.md` 의 설명 산문에 `$ARGUMENTS` 를 새로 쓰지 않는다 — 쓰면 그 자리에 사용자 입력이 박혀 문장이 깨진다. 발동 조건 문장(입력값이 박혀도 뜻이 통하는 자리)만 예외다.
- **버전** — `plugins/spec-distill/.claude-plugin/plugin.json` 을 `1.0.0` → `1.1.0`(minor, 새 입력 모양 = 새 surface)으로 올리고 같은 커밋에 `CHANGELOG.md` 의 `## [1.1.0] — 2026-09-10` 엔트리를 담는다. **번호와 날짜는 잠정이다** — 날짜는 머지하는 날로 바꾸고, 동시 워크트리 `feature/remove-spec-review-hook` 이 spec-distill 을 먼저 머지하면 머지 직전에 다시 정한다. 같은 버전 문자열은 충돌 없이 병합돼 git 이 알려주지 않는다.
- **커밋** — Conventional Commits, scope `spec-distill`. 메시지 끝에 두 줄:
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01EUJwm6ktX8Rvon4NjXVZ6X
  ```
  메시지는 `.claude/handoff-baseline/commit-msg.txt` 에 쓰고 `git commit -q -F .claude/handoff-baseline/commit-msg.txt` 로 커밋한다.
- **변이는 커밋 뒤에** — `git checkout --` 는 HEAD 로 되돌리므로, 커밋하지 않은 편집 위에서 변이하면 편집이 사라진다. Task 0 의 `mutate.sh` 가 이 순서를 강제한다.

---

## File Structure

| 파일 | 책임 | 태스크 |
|---|---|---|
| `plugins/spec-distill/tests/test_seed_at_path_handoff.sh` (신설, mode 100755) | AC1–AC6 + 이름 가드 공백 거부 단언. 태스크마다 자기 절을 덧붙인다 | T1–T4 |
| `plugins/spec-distill/commands/interview.md` | Step 1.5 신설 · Step 2·2.5·3·Arguments·다음 단계를 「풀린 입력」으로 | T1 |
| `plugins/spec-distill/skills/framing-requests/SKILL.md` | description · 도입 · 워크트리 5단계 · 「## 상태」 서술과 이름 가드 · 호출 모양 절 · 두 가드 | T2 |
| `plugins/spec-distill/references/proceed-gate.md` | 채우는 것 · Step A · Step B 표 · 가드 1·2 · 검증 절 · 앵커 절 | T3 |
| `plugins/spec-distill/commands/request-framing.md` | description · 도입 · 다음 단계 | T4 |
| `plugins/spec-distill/skills/conducting-interview/references/seed-input.md` | 3–7행 도착 경로 | T4 |
| `plugins/spec-distill/skills/conducting-interview/references/finishing.md` | 43행 S1 문장 한 곳 | T4 |
| `plugins/spec-distill/templates/interview-seed-audit-template.md` | 11–13행 인용 블록 | T4 |
| `plugins/spec-distill/README.md` | 32–34행 흐름도 | T4 |
| `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` | 1.1.0 · 엔트리 | T5 (T6 가 V4 결과 한 줄 추가) |
| `.claude/handoff-baseline/mutate.sh` · `v4/run_v4.sh` · `v4/judge_v4.py` (git 무시, 커밋 안 함) | 변이 도구 · V4 실행·판정 | T0 · T6 |

## 태스크 순서와 의존

`T0 → T1 → T2 → T3 → T4 → T5 → T6` 엄격 순차다. T1–T3 은 내용상 독립이지만 같은 테스트 파일에 절을 덧붙이므로 병렬로 돌리지 않는다. T4 의 부재 락은 T1·T2 의 편집이 끝나야 GREEN 이 된다. T6 은 T5 까지 커밋된 트리를 헤드리스 세션에 싣는다.

## 착수 전 baseline

2026-09-10, base `c7b4f580`(= origin/main)에서 `.claude/handoff-baseline/run.sh` 로 잰 값이 `.claude/handoff-baseline/baseline.tsv` 에 있다(파일별 `이름<TAB>rc<TAB>실패 줄 수`). spec-distill 테스트 80개 중 rc≠0 은 둘이다.

| 파일 | rc | 실패 줄 |
|---|---|---|
| `test_no_write_matcher_hooks_repo.sh` | 1 | 1 |
| `test_hook_output_schema.py` | 1 | 1 |

`test_skepticism_module.sh` 는 rc 0 인데 실패 줄 수가 3이다 — 출력에 `FAIL` 이라는 낱말이 들어 있어서다. 비교는 rc 가 아니라 **세 칸 전부**로 한다.

---

### Task 0: pre-flight — base 이동량 · baseline 재측정 · 변이 도구

**Files:**
- Create: `.claude/handoff-baseline/mutate.sh` (git 무시)
- Create: `.claude/handoff-baseline/baseline-t0.tsv` · `.claude/handoff-baseline/shared-t0.txt` (git 무시)

**Interfaces:**
- Produces: `bash .claude/handoff-baseline/mutate.sh <file> <기대 ✗ 부분문자열> <old1> <new1> [<old2> <new2> …]` — 커밋된 파일에 치환을 적용하고 새 테스트를 돌려, rc≠0 이면서 기대 문자열이 든 `✗` 줄이 있으면 `RED-OK`, 아니면 `NO-TEETH` 와 rc 1. 끝나면 항상 HEAD 로 되돌리고 깨끗한지 확인한다. T1–T4 의 변이 단계가 쓴다.

- [ ] **Step 1: 위치와 트리 상태 확인**

Run: `pwd && git branch --show-current && git status --short`
Expected: 워크트리 절대경로 · `feature/handoff-gate-reorder` · 빈 출력.

- [ ] **Step 2: base 이동량**

Run: `git fetch -q origin main && git rev-list --count c7b4f580..origin/main && git diff --stat c7b4f580 origin/main -- plugins/spec-distill shared/tests`
Expected: `0` 과 빈 diff. **0 이 아니고 `plugins/spec-distill` 이나 `shared/tests` 가 바뀌었으면 멈추고 보고한다** — 사용자가 동의하면 `git merge origin/main`(rebase 금지)으로 따라잡고 Step 3 의 baseline 을 다시 잰다. 버전 파일(`plugin.json`·`CHANGELOG.md`)이 바뀌었으면 Global Constraints 의 잠정 번호를 그 위로 다시 정한다.

- [ ] **Step 3: spec-distill baseline 재측정**

Run: `bash .claude/handoff-baseline/run.sh .claude/handoff-baseline/baseline-t0.tsv`
그 뒤 Run: `diff .claude/handoff-baseline/baseline.tsv .claude/handoff-baseline/baseline-t0.tsv && echo SAME`
Expected: 출력 마지막 줄 `total=80 nonzero=2`, 그리고 `SAME`.

- [ ] **Step 4: 공용 락 세 개의 baseline**

아래 내용을 `.claude/handoff-baseline/shared-locks.sh` 로 쓴다:

```bash
#!/usr/bin/env bash
# 이 브랜치가 영향을 줄 수 있는 공용 락 셋의 rc 와 ✗ 줄 수.
set -u
WT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$WT" || exit 2
for t in shared/tests/test_no_new_duplication.sh shared/tests/test_changelog_integrity.sh plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh; do
  o="$(bash "$t" 2>&1)"; rc=$?
  n="$(printf '%s\n' "$o" | grep -c '✗')"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$n"
done
```

Run: `bash .claude/handoff-baseline/shared-locks.sh > .claude/handoff-baseline/shared-t0.txt; cat .claude/handoff-baseline/shared-t0.txt`
Expected: 세 줄. 값이 무엇이든 기록한다 — Task 5 가 이것과 비교한다.

- [ ] **Step 5: 변이 도구 작성**

`.claude/handoff-baseline/mutate.sh`:

```bash
#!/usr/bin/env bash
# 변이 1건: <file> 에 치환쌍을 순서대로 적용(각 old 의 첫 출현)하고 새 테스트를 돌린다.
# rc≠0 이면서 <expect> 가 든 ✗ 줄이 있으면 RED-OK. 끝나면 HEAD 로 되돌리고 깨끗한지 확인한다.
set -u
WT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$WT" || exit 2
f="$1"; expect="$2"; shift 2
[ "$#" -ge 2 ] && [ $(( $# % 2 )) -eq 0 ] || { echo "ABORT: 치환쌍이 없거나 홀수다" >&2; exit 2; }
git diff --quiet -- "$f" || { echo "ABORT: $f 에 커밋 안 된 변경이 있다 — 변이 전에 커밋하라" >&2; exit 2; }
python3 - "$f" "$@" <<'PY' || { git checkout -- "$f"; exit 2; }
import sys, pathlib
p = pathlib.Path(sys.argv[1]); pairs = sys.argv[2:]
t = p.read_text(encoding="utf-8")
for old, new in zip(pairs[0::2], pairs[1::2]):
    if old not in t:
        sys.exit("ABORT: 변이 대상 문자열이 없다: %r" % old)
    t = t.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
PY
out="$(bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh 2>&1)"; rc=$?
git checkout -- "$f"
git diff --quiet -- "$f" || { echo "ABORT: 복원 실패 — $f" >&2; exit 2; }
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -F '✗' | grep -qF -- "$expect"; then
  echo "RED-OK   [$expect]"
else
  echo "NO-TEETH rc=$rc [$expect]"
  printf '%s\n' "$out" | grep -F '✗' | head -5
  exit 1
fi
```

Run: `bash -n .claude/handoff-baseline/mutate.sh && echo SYNTAX-OK`
Expected: `SYNTAX-OK`. 커밋하지 않는다(git 무시 경로).

---

### Task 1: `/interview` Step 1.5 와 「풀린 입력」

**Files:**
- Create: `plugins/spec-distill/tests/test_seed_at_path_handoff.sh`
- Modify: `plugins/spec-distill/commands/interview.md` (전문 교체 — Step 1.5 신설, Step 2·2.5·3·Arguments·다음 단계)

**Interfaces:**
- Consumes: Task 0 의 `mutate.sh`.
- Produces: 테스트 파일의 뼈대 — 변수 `ROOT` `SD` `SK` `CANON` `CMD` `RF` `README`, 배열 `CORPUS`(CHANGELOG·tests/ 를 뺀 플러그인 `*.md` 절대경로), 함수 `block <시작 ERE> <멈춤 ERE> <파일>`(시작 줄부터 멈춤 줄 전까지 출력) · `flat`(stdin 의 개행을 공백으로, 연속 공백을 하나로). 파일의 마지막 줄은 항상 `finish` 다 — T2–T4 는 **`finish` 바로 위에** 자기 절을 덧붙인다.

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_seed_at_path_handoff.sh` 를 아래 내용으로 만들고 `chmod 755` 한다(형제 테스트가 100755 다).

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/**
#
# seed `@경로` 핸드오프 — framing 게이트(`/new`·`/compact` → `/interview @<seed 경로>`) ·
# 공유 계약의 권장/차선 핸드오프 · `/interview` Step 1.5 · 옛 호출 모양 부재 · 이름 가드 공백 거부.
#
# 정본 `references/proceed-gate.md` 에 대한 단언은 **정본 자체**를 대상으로 한다 — 채택자
# presence 코퍼스에 정본을 넣는 것이 아니다(그 코퍼스 규칙은 test_proceed_gate_adopters.sh 에 있다).
# 부재 단언에는 코퍼스를 실제로 읽었다는 양성 짝이 붙는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
SK="$SD/skills/framing-requests/SKILL.md"
CANON="$SD/references/proceed-gate.md"
CMD="$SD/commands/interview.md"
RF="$SD/commands/request-framing.md"
README="$SD/README.md"
. "$ROOT/shared/tests/assert.sh"

# 부재 코퍼스: CHANGELOG 와 tests/ 를 뺀 이 플러그인의 문서 전부(추적 + 미추적).
CORPUS=()
while IFS= read -r f; do
  [ -n "$f" ] && CORPUS+=("$ROOT/$f")
done < <(cd "$ROOT" && git ls-files --cached --others --exclude-standard -- 'plugins/spec-distill/*.md' \
  | grep -vE '^plugins/spec-distill/(CHANGELOG\.md$|tests/)')

if [ "${1:-}" = "--emit-scanned" ]; then
  for f in "${CORPUS[@]+"${CORPUS[@]}"}"; do printf '%s\n' "${f#"$ROOT"/}"; done
  exit 0
fi

# 헤딩 블록: 시작 ERE 줄부터 다음 멈춤 ERE 줄 전까지.
block() { awk -v s="$1" -v e="$2" '$0 ~ s {f=1; print; next} f && $0 ~ e {f=0} f' "$3"; }
flat()  { tr '\n' ' ' | tr -s ' '; }

# ── /interview Step 1.5 와 「풀린 입력」 ───────────────────────────────────
l15="$(grep -n '^## Step 1[.]5' "$CMD" | head -1 | cut -d: -f1)"
l2="$(grep -n '^## Step 2: ' "$CMD" | head -1 | cut -d: -f1)"
if [ -n "$l15" ] && [ -n "$l2" ] && [ "$l15" -lt "$l2" ]; then
  ok "AC5: Step 1.5 가 Step 2 보다 앞에 있다 (${l15} < ${l2})"
else
  no "AC5: Step 1.5 가 Step 2 보다 앞에 있지 않다 (Step 1.5=${l15:-없음} Step 2=${l2:-없음})"
fi
s15="$(block '^## Step 1[.]5' '^## ' "$CMD" | flat)"
[ -n "$s15" ] && ok "AC5(양성): Step 1.5 블록을 읽었다" || no "AC5(양성): Step 1.5 블록이 없다 — 아래 단언이 공허하다"
assert_contains "$s15" '`@` 로 시작하는 **공백 없는 한 토큰**일 때만' "AC5: 발동 조건 — 한 토큰 @"
assert_contains "$s15" '**절대경로로** Read 도구에 넘긴다' "AC5: 동작 — Read"
assert_contains "$s15" '줄번호·탭 접두를 뗀 **파일 원문 전체(frontmatter 포함)**' "AC5: 풀린 입력 = frontmatter 포함 파일 전문"
assert_contains "$s15" '「풀린 입력」의 출처는 이 Read 결과다' "§3: 첨부가 따로 와도 출처는 Read 결과"
assert_contains "$s15" '를 읽지 못했다(<관측한 사유>) — seed 를 만든 워크트리 디렉토리에서 세션을 열었는지 확인하라. 인터뷰를 시작하지 않는다.' "AC5: 부재 문구"
assert_contains "$s15" '아래 문구를 내고 멈춘다. **인터뷰를 시작하지 않는다.**' "AC5: 정지 지시"
assert_contains "$s15" '발동하지 않았으면 「풀린 입력」은' "§3: 미발동이면 받은 입력 그대로"
s2="$(block '^## Step 2: ' '^## ' "$CMD" | flat)"
s25="$(block '^## Step 2[.]5' '^## ' "$CMD" | flat)"
s3="$(block '^## Step 3' '^## ' "$CMD")"
sa="$(block '^## Arguments' '^## ' "$CMD" | flat)"
assert_contains "$s2" '「풀린 입력」을 대조' "§3: Step 2 trivia 대조 대상 = 풀린 입력"
assert_contains "$s25" '「풀린 입력」의 frontmatter 에 `type: interview-seed`' "§3: Step 2.5 seed 판별 대상 = 풀린 입력"
assert_contains "$s3" 'Skill conducting-interview <풀린 입력>' "§3: Step 3 인자 = 풀린 입력"
assert_not_contains "$s3" 'Skill conducting-interview $ARGUMENTS' "§3: Step 3 가 치환된 원 인자를 넘기지 않는다"
assert_contains "$sa" '「풀린 입력」 — Step 1.5 의 결과' "§3: Arguments 절이 풀린 입력을 가리킨다"

finish
```

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh; echo "rc=$?"`
Expected: `rc=1`, `✓` 줄 0개 — 모든 줄이 `✗` 다(아직 Step 1.5 가 없고 Step 3 은 `$ARGUMENTS` 를 넘긴다).

- [ ] **Step 3: `commands/interview.md` 교체**

파일 전체를 아래 내용으로 바꾼다. frontmatter·도입·Step 1 은 글자 그대로다.

````markdown
---
description: 강한 문제공간 stage — 메타프롬프팅·웹리서치·steelman으로 방향을 끌어내 brainstorming용 interview brief를 생성. devbrew Law 1 instantiation.
argument-hint: "[rough request]"
---

# /interview

당신은 spec-distill 플러그인의 entry point입니다. `/interview`는 superpowers brainstorming
**앞단의 강한 문제공간 stage**로, 사용자에게서 방향을 끌어내고(메타프롬프팅), 외부 사례를
웹으로 조사하고, 약한 방향을 steelman으로 깨뜨려 **interview brief**(meta-prompt)를 산출합니다.
사용자가 `/interview`를 호출하면 다음 순서로 진행하십시오.

## Step 1: kill switch 존중

다음 환경변수가 set이면 즉시 종료 (no-op):

- `DEVBREW_SPEC_DISTILL_DISABLE=1` — 모든 spec-distill 동작 abort.

(`DEVBREW_SKIP_HOOKS` 는 hook 영역으로, command 자체에는 영향 없음.)

## Step 1.5: `@경로` 인자 풀기

앞뒤 공백을 걷은 `$ARGUMENTS` 가 `@` 로 시작하는 **공백 없는 한 토큰**일 때만 이 단계가 발동한다.
문장 중간에 `@` 가 섞인 입력은 건드리지 않는다.

발동하면 `@` 를 뗀 경로를 세션 작업 디렉토리 기준으로 풀어 **절대경로로** Read 도구에 넘긴다. Read 출력의
줄번호·탭 접두를 뗀 **파일 원문 전체(frontmatter 포함)** 가 「풀린 입력」이다. 대화형에서 같은 파일이 따로
첨부되더라도 「풀린 입력」의 출처는 이 Read 결과다.

Read 가 실패하면(파일 부재 · 경로가 디렉토리 · 권한 등) 관측한 실패 사유를 담아 아래 문구를 내고 멈춘다. **인터뷰를 시작하지 않는다.**

> `[spec-distill] '@<경로>' 를 읽지 못했다(<관측한 사유>) — seed 를 만든 워크트리 디렉토리에서 세션을 열었는지 확인하라. 인터뷰를 시작하지 않는다.`

발동하지 않았으면 「풀린 입력」은 이 command 가 받은 입력 그대로다.

## Step 2: Trivia Escape Check (AP4 회피, AC10)

5 패턴 정의는 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md` 에 있습니다. 그 파일을
읽고 「풀린 입력」을 대조하십시오. 해당하면 그 파일의 안내 문면을 `<command>` = `interview`
으로 채워 출력하고 인터뷰를 시작하지 않습니다.

## Step 2.5: seed 아닌 입력에 대한 조언 (차단 아님)

Phase 0 을 거친 세션은 이 command 를 `/interview @<seed 경로>` 로 부르고, Step 1.5 가 그 파일을
전문으로 풉니다 — seed 는 별도 채널이 아니라 「풀린 입력」으로 옵니다. 그래서 「풀린 입력」의 frontmatter 에
`type: interview-seed` 가 있으면 이 안내는 나가지 않습니다.

「풀린 입력」이 `interview-seed` 가 아니면 한 줄 안내를 낸다 — **막지 않는다.**

> 💡 `/request-framing` 을 먼저 거치면 첫 턴이 정리된 상태로 시작합니다. 지금 그대로
> 진행해도 됩니다.

## Step 3: 인터뷰 진입

Trivia 아닌 경우, `conducting-interview` skill을 invoke하십시오. 인자는 「풀린 입력」입니다 — Step 1.5 가
발동했으면 경로 문자열이 아니라 파일 전문(frontmatter 포함)입니다:

```
Skill conducting-interview <풀린 입력>
```

`conducting-interview` skill이 «직전 답에서» 블록 + 질문 둘 형식으로 첫 round를 진행합니다.

## Arguments

「풀린 입력」 — Step 1.5 의 결과. 사용자가 `/interview`에 함께 넘긴 rough request 그대로이거나, `/interview @<seed 경로>` 로 불렸으면 Phase 0 이 만든 `interview-seed` 파일 전문(frontmatter 포함)이다. 사용자가 seed 전문을 직접 붙여넣은 입력도 그대로 받는다. 비어 있으면 `conducting-interview`가 첫 질문 ("어떤 것을 만들고 싶으신가요?")으로 시작.

## 다음 단계

`conducting-interview` skill로 흐름이 넘어가 5 통과 의례(R1–R5)를 거쳐 interview brief를
`docs/superpowers/interview/`에 생성합니다. 이 command 자체는 trivia escape + `@경로` 풀기 + skill dispatch
책임만 집니다(NG6 — trivia escape 불변).
````

설명 산문에 `$ARGUMENTS` 를 남기지 않은 것은 의도다(Global Constraints — 치환되면 문장이 깨진다). 남은 한 곳은 Step 1.5 의 발동 조건 문장이고, 거기는 입력값이 박혀도 뜻이 통한다.

- [ ] **Step 4: 통과 확인 + 이 파일을 재는 기존 락**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh; echo "rc=$?"`
Expected: `rc=0`, `✗` 0줄.

Run: `for t in test_conducting_interview_stage.sh test_conducting_interview_internal.sh test_stale_terms.sh; do bash plugins/spec-distill/tests/$t >/dev/null 2>&1; echo "$t rc=$?"; done`
Expected: 셋 다 `rc=0`. 특히 stage 테스트의 Step 2 정지 문구(`인터뷰를 시작하지 않습니다`)가 Step 2 블록에 있고 Step 2.5 에 없는지, Step 2.5 에 `막지 않는다`·`request-framing` 이 있는지를 그 테스트가 잰다.

- [ ] **Step 5: 커밋**

`.claude/handoff-baseline/commit-msg.txt`:

```
feat(spec-distill): /interview Step 1.5 — @경로 인자를 파일 전문으로 풀기

trim 한 인자가 @ 로 시작하는 공백 없는 한 토큰이면 그 파일을 읽어 frontmatter 포함
전문을 「풀린 입력」으로 삼고, Step 2·2.5·3 이 그 값을 쓴다. 읽기 실패면 사유를 담아
멈춘다. 헤드리스 실측에서 커맨드 인자의 @경로 는 $ARGUMENTS 에 리터럴로 남았다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EUJwm6ktX8Rvon4NjXVZ6X
```

Run: `git add plugins/spec-distill/tests/test_seed_at_path_handoff.sh plugins/spec-distill/commands/interview.md && git commit -q -F .claude/handoff-baseline/commit-msg.txt && git status --short`
Expected: 빈 출력.

- [ ] **Step 6: 이빨 확인 — 변이 여섯**

양성 대조는 Step 4 의 GREEN 이다. 각 줄을 따로 돌린다. 기대: 여섯 줄 모두 `RED-OK`.

```bash
bash .claude/handoff-baseline/mutate.sh plugins/spec-distill/commands/interview.md "Step 1.5 가 Step 2 보다 앞" '## Step 1.5: `@경로` 인자 풀기' '**(제목 삭제)**'
bash .claude/handoff-baseline/mutate.sh plugins/spec-distill/commands/interview.md "Step 1.5 가 Step 2 보다 앞" '## Step 1.5: `@경로` 인자 풀기' '**(제목이 옮겨졌다)**' '## Step 3: 인터뷰 진입' $'## Step 1.5: `@경로` 인자 풀기\n\n## Step 3: 인터뷰 진입'
bash .claude/handoff-baseline/mutate.sh plugins/spec-distill/commands/interview.md "Step 3 인자 = 풀린 입력" 'Skill conducting-interview <풀린 입력>' 'Skill conducting-interview $ARGUMENTS'
bash .claude/handoff-baseline/mutate.sh plugins/spec-distill/commands/interview.md "AC5: 부재 문구" '를 읽지 못했다(<관측한 사유>)' '를 읽지 못했다'
bash .claude/handoff-baseline/mutate.sh plugins/spec-distill/commands/interview.md "AC5: 정지 지시" '아래 문구를 내고 멈춘다. **인터뷰를 시작하지 않는다.**' '아래 문구를 낸다.'
bash .claude/handoff-baseline/mutate.sh plugins/spec-distill/commands/interview.md "Step 2.5 seed 판별" '「풀린 입력」의 frontmatter 에' '`$ARGUMENTS` 의 frontmatter 에'
```

둘째 줄은 순서 뒤집기 축이다(Step 1.5 제목을 Step 3 앞으로 옮긴다). `NO-TEETH` 가 하나라도 나오면 그 단언을 좁히고(다른 문장이 같은 리터럴을 만족시키는지 먼저 본다) Step 4 부터 다시 한다. 끝나고 `git status --short` 가 비어 있어야 한다.

---

### Task 2: framing 게이트 — 옵션 표 · 호출 모양 · 두 가드 · 이름 가드

**Files:**
- Modify: `plugins/spec-distill/skills/framing-requests/SKILL.md` — 3–7행(description) · 13–14행(도입) · 126–127행(워크트리 5단계) · 204행(「## 상태」 서술) · 241–247행(TOPIC 주석·가드) · 257–259행(IV_NAME 가드·advisory) · 565–608행(호출 모양 절) · 627–635행(두 가드)
- Modify: `plugins/spec-distill/tests/test_seed_at_path_handoff.sh` (`finish` 위에 절 추가)

**Interfaces:**
- Consumes: Task 1 의 `block` · `flat` · `SK`.
- Produces: 없음(이 절의 단언은 자기완결).

- [ ] **Step 1: 실패하는 단언 추가**

테스트 파일 마지막 `finish` 줄 **바로 위**에 붙인다:

```bash
# ── framing 게이트: 옵션 표 · 호출 모양 · 두 가드 ──────────────────────────
call="$(block '^### 호출 모양' '^##' "$SK")"
rows="$(printf '%s\n' "$call" | grep -E '^\| [①②③④] \|')"
nrows="$(printf '%s\n' "$rows" | grep -c .)"
assert_eq "$nrows" "4" "AC1(양성): 호출 모양 절 옵션 표에서 행 4개를 읽었다"
r1="$(printf '%s\n' "$rows" | grep -E '^\| ① \|')"
r2="$(printf '%s\n' "$rows" | grep -E '^\| ② \|')"
for n in '`/new` 후' '`/interview @<seed 경로>`' '권장' '턴 종료'; do assert_contains "$r1" "$n" "AC1: ① 행에 $n"; done
for n in '`/compact` 후' '`/interview @<seed 경로>`' '턴 종료'; do assert_contains "$r2" "$n" "AC1: ② 행에 $n"; done
assert_not_contains "$r2" '권장' "AC1: 권장은 ① 하나"
assert_not_contains "$rows" '바로' "AC1: 옵션 표에 「바로」 진행 행이 없다"
cf="$(printf '%s\n' "$call" | flat)"
assert_contains "$cf" '`<seed 경로>` 는 `$SEED` 의 실제 값' "AC2: 자리표를 실제 값으로 치환하라는 지시"
assert_contains "$cf" '`/new` 뒤 같은 줄에' "AC2: /new 뒤 같은 줄에 붙이지 말라는 안내"
assert_contains "$cf" '세션 이름' "AC2: 같은 줄 텍스트가 세션 이름이 된다는 사실"
assert_contains "$cf" '명령 노출(①/②) 바로 앞' "§4: 핸드오프 직전 커밋 시점 = 명령 노출 바로 앞"
assert_not_contains "$cf" '<seed 전문>' "§1: 호출 모양 절에 옛 붙여넣기 자리표가 없다"

gb="$(block '^### 두 가드' '^##' "$SK")"
stop="$(printf '%s\n' "$gb" | awk '/^- \*\*cross-compact 조기 진행 금지\*\*/{f=1; print; next} f && /^- /{f=0} f' | flat)"
pol="$(printf '%s\n' "$gb" | awk '/^- \*\*polite stop 금지/{f=1; print; next} f && /^- /{f=0} f' | flat)"
[ -n "$stop" ] && ok "AC3(양성): 정지 가드 불릿을 읽었다" || no "AC3(양성): 정지 가드 불릿이 없다 — 아래 단언이 공허하다"
for n in '①/② 어느 쪽이든' '턴 종료(STOP)' '같은 턴에서 인터뷰를 시작하지 않습니다' '**다음 턴**' '사용자 트리거로만'; do
  assert_contains "$stop" "$n" "AC3: 정지 가드 한 불릿 안에 $n"
done
[ -n "$pol" ] && ok "§1(양성): polite stop 불릿을 읽었다" || no "§1(양성): polite stop 불릿이 없다 — 아래 단언이 공허하다"
assert_contains "$pol" '두 줄 명령을 노출하지 않고 설명만 하고 끝내는 것' "§1: 핸드오프 옵션의 polite stop 정의"
assert_not_contains "$gb" '다음 단계로 가지 않는 것은' "§1: 옛 polite stop 문면이 남지 않았다"

# ── 이름 가드: 공백 거부 — 문구가 아니라 case 패턴을 실제로 돌려 잰다 ──────
case_pat() { awk -v c="$1" 'index($0, c) {getline; print; exit}' "$SK" | sed -E 's/^[[:space:]]*//; s/\).*$//'; }
rejects()  { bash -c 'case "$2" in '"$1"') echo R ;; *) echo A ;; esac' _ "$1" "$2"; }
tp="$(case_pat 'case "$TOPIC" in')"
ip="$(case_pat 'case "$IV_NAME" in')"
{ [ -n "$tp" ] && [ -n "$ip" ]; } \
  && ok "이름 가드(양성): case 패턴 둘을 읽었다" \
  || no "이름 가드(양성): case 패턴을 못 읽었다 (TOPIC='${tp}' IV_NAME='${ip}') — 아래 단언이 공허하다"
assert_eq "$(rejects "$tp" 'umbrella-kiosk')" A "이름 가드(양성 짝): 공백 없는 kebab TOPIC 은 통과"
assert_eq "$(rejects "$tp" 'umbrella kiosk')" R "이름 가드: 공백 든 TOPIC 거부"
assert_eq "$(rejects "$tp" "$(printf 'umbrella\tkiosk')")" R "이름 가드: 탭 든 TOPIC 거부"
assert_eq "$(rejects "$tp" '<kebab-topic>')" R "이름 가드: 자리표 TOPIC 거부 (기존 동작 유지)"
assert_eq "$(rejects "$ip" '2026-09-10-umbrella-kiosk-interview')" A "이름 가드(양성 짝): 공백 없는 IV_NAME 은 통과"
assert_eq "$(rejects "$ip" '2026-09-10-umbrella kiosk-interview')" R "이름 가드: 공백 든 IV_NAME 거부"
```

`case_pat` 은 `case "…" in` 다음 줄에서 첫 `)` 앞까지를 패턴으로 떼고, `rejects` 는 그 패턴을 실제 `case` 문으로 돌린다. 패턴 추출이 실패하면 빈 패턴이 `bash -c` 구문 오류가 되어 출력이 비고, `assert_eq` 가 ✗ 를 낸다(fail-closed).

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh; echo "rc=$?"`
Expected: `rc=1`. Task 1 절은 전부 ✓. 새 절의 ✗ 에는 적어도 `① 행에 `/new` 후` · `AC2: 자리표를` · `정지 가드 한 불릿 안에 ①/②` · `공백 든 TOPIC 거부` · `공백 든 IV_NAME 거부` 가 있다. 양성 줄(`(양성)` · `(양성 짝)`)과 `자리표 TOPIC 거부` 는 오늘 문면에서도 ✓ 다 — 그중 하나라도 ✗ 면 추출이 깨진 것이니 구현 전에 테스트를 고친다.

- [ ] **Step 3: SKILL.md 편집 — description · 도입 · 워크트리 · 상태 서술**

(a) 5–7행:

```
  확산(원문 보존 → 레포 읽기 → 질문 라운드) 후 압축해, 새 세션 첫 턴에
  `/interview` 의 인자로 붙여넣는 `interview-seed` 메시지를 만든다. 산출물은 문서가
  아니라 다음 세션의 첫 턴이다.
```
→
```
  확산(원문 보존 → 레포 읽기 → 질문 라운드) 후 압축해, 새 세션 첫 턴의
  `/interview @<seed 경로>` 가 가리키는 `interview-seed` 파일을 만든다. 산출물은 문서가
  아니라 다음 세션의 첫 턴이다.
```

(b) 13–14행의 `**새 세션의 첫\n턴에 그대로 붙여넣는 메시지**입니다.` →
```
**새 세션의 첫
턴 `/interview @<seed 경로>` 가 가리키는 파일**입니다.
```
(줄의 나머지 — `당신은 … 산출물은 문서가 아니라 ` 앞부분과 `그 첫 턴이 어떤 모양인지는 …` 뒷부분 — 는 그대로.)

(c) 126–127행:
```
5. 게이트 텍스트의 «다음 세션 첫 턴» 안내에 워크트리 **절대경로**를 함께 낸다 — 사람이 그 디렉토리에서
   새 세션을 열어 `/interview <seed 전문>` 을 친다.
```
→
```
5. 게이트 텍스트의 «다음 세션 첫 턴» 안내에 워크트리 **절대경로**를 함께 낸다 — 다른 터미널에서 새 세션을
   열 때 그 디렉토리에서 열어야 `/interview @<seed 경로>` 가 그 파일을 찾는다.
```

(d) 204행 `입니다 — seed 파일을 다음 세션의 첫 턴에 붙여넣는 것이고, 그 턴의 모양은` →
`입니다 — 다음 세션의 첫 턴이 `/interview @<seed 경로>` 로 seed 파일을 가리키는 것이고, 그 턴의 모양은`

- [ ] **Step 4: SKILL.md 편집 — 이름 가드 둘**

(a) 241행 `# `TOPIC` 을 요청의 주제(kebab-case)로 바꿔 쓴다. **바꾸기 전에는 이름을 고정하지` →
```
# `TOPIC` 을 요청의 주제(공백 없는 kebab-case)로 바꿔 쓴다 — 공백이 든 이름은 아래 가드가
# 거부한다(seed 경로가 한 토큰이어야 `/interview` 가 `@경로` 로 푼다). **바꾸기 전에는 이름을 고정하지
```

(b) 246행 `  ""|*"<"*|*">"*|*/*) : ;;` → `  ""|*"<"*|*">"*|*/*|*[[:space:]]*) : ;;`

(c) 258행 `  ""|*/*|*"<"*|*">"*)` → `  ""|*/*|*"<"*|*">"*|*[[:space:]]*)`

(d) 259행 advisory 안의 `이 블록의 TOPIC 을 요청 주제(kebab-case)로 바꿔 다시 돌려라` → `이 블록의 TOPIC 을 요청 주제(공백 없는 kebab-case)로 바꿔 다시 돌려라`

`test_seed_gate_wiring.sh` 의 H2 는 「## 상태」 를 처방하는 advisory 가 대는 `${VAR:-}` 변수를 이 블록이 대입하는지 잰다. 이 advisory 는 「## 상태」 를 처방하지 않으므로 H2 의 대상이 아니다.

- [ ] **Step 5: SKILL.md 편집 — 호출 모양 절 (565–608행)**

565행 `### 호출 모양 — 이 파이프라인에서 여기가 정본이다` 부터 608행 `사람이 그 디렉토리에서 새 세션을 열어야 하기 때문입니다.` 까지를 아래로 바꾼다. 「세 실패」 불릿 셋 · 「frontmatter 를 떼지 않는 이유」 단락 · 커밋 bash 펜스 · 「③(수정)·④(멈춤)에서는 커밋하지 않습니다 …」 문장은 **글자 그대로** 옮긴다(`test_request_framing_command.sh` 의 AC12 가 커밋 메시지 리터럴 · `①/② … handoff 직전 … 커밋` · `③/④ … 커밋하지 않` · `절대경로` · `git commit -q -F` 를 이 절에서 잰다).

````markdown
### 호출 모양 — 이 파이프라인에서 여기가 정본이다

**다음 세션의 첫 턴은 `/interview @<seed 경로>` 한 줄입니다.** `<seed 경로>` 는 `$SEED` 의 실제 값
(`docs/superpowers/interview/<날짜>-<topic>-interview.md` 모양의 상대경로)으로 치환한 뒤 노출합니다 —
치환하지 않은 자리표가 나가면 사용자가 깨진 명령을 실행하고, 그것을 잡는 자리가 없습니다.

`@경로` 는 서식 취향이 아닙니다 — **소비자 쪽 계약이 전부 `/interview` 가 넘기는 인자에 키잉돼 있습니다.**
커맨드 인자의 `@경로` 는 헤드리스 실측(2026-09-10)에서 파일로 풀리지 않았고 대화형은 재지 않았습니다 —
어느 쪽이든 `/interview` 가 그 파일을 읽어 전문으로 풀어 넘깁니다. 넘긴 값이 비거나 경로 문자열로 남으면
셋이 함께 조용히 실패합니다:

- `conducting-interview` 의 종료 절차가 「인자 없이 호출되면 `S1` 을 만들지 않는다」이므로
  **사용자가 방금 확정한 요청이 brief §6 에 보존되지 않습니다.**
- `conducting-interview` 의 seed 입력 규약(그 안의 재결정 P23 포함)이 발동할 입력을 못
  받습니다.
- `/interview` 가 방금 Phase 0 을 거친 사용자에게 「`/request-framing` 을 먼저 거치면…」
  조언을 내고, 인터뷰가 「어떤 것을 만들고 싶으신가요?」로 시작합니다.

**frontmatter 를 떼지 않는 이유**: `type: interview-seed` 줄이 소비자가 seed 를 알아보는
유일한 표지입니다. 본문은 라벨 없는 산문이라 그것만으로는 seed 인지 아닌지 구별되지
않습니다. `check_seed.py` 와 억제 번들 조립기가 **본문만** 보는 것은 별개 사실입니다 —
그 둘은 사람이 읽는 메시지를 재고, frontmatter 는 하니스용 메타데이터입니다.

게이트의 네 옵션은 이 모양을 그대로 씁니다 — ①/② 는 두 줄 명령을 노출하는 핸드오프입니다:

| # | 이 skill 의 옵션 |
|---|---|
| ① | `/new` 후 `/interview @<seed 경로>` (권장, 커밋 후) — 두 줄 명령을 노출하고 **턴 종료** |
| ② | `/compact` 후 `/interview @<seed 경로>` (커밋 후) — 두 줄 명령을 노출하고 **턴 종료** |
| ③ | 수정 필요 — 압축을 다시 깎고 이 게이트로 돌아옵니다 |
| ④ | 멈춤 — seed 와 audit 을 남기고 종료 |

노출 모양(① 의 예 — ② 는 첫 줄이 `/compact` 입니다):

```
/new
/interview @docs/superpowers/interview/2026-09-10-<topic>-interview.md
```

`/new` 뒤 같은 줄에 텍스트를 붙이면 그 텍스트는 세션 이름이 됩니다 — 두 줄을 **따로** 입력하라는 안내를
명령과 함께 냅니다. `/compact` 뒤 텍스트도 요약 지시로만 쓰이고 다음 프롬프트로 가지 않으므로 ② 도 같습니다.

**handoff 직전 커밋(①/② 에서만).** 워크트리 안이면 ①/② 를 고른 직후 handoff 직전
커밋을 한 번 합니다 — 명령 노출(①/②) 바로 앞입니다.
③(수정)·④(멈춤)에서는 커밋하지 않습니다 — 수정마다 커밋이 늘고 멈춤에도 커밋이 남는
것을 막기 위해서입니다. 단순 명령 셋, 메시지는 파일로:

```bash
printf 'docs(interview): <topic> interview seed + audit\n' > "$SEED_DIR/commit-msg.txt"
git add "$AUDIT" "$SEED"
git commit -q -F "$SEED_DIR/commit-msg.txt"
```

워크트리가 아니면(거절·부재·스위치) 커밋하지 않고 «미커밋 — 현재 디렉토리» 를 게이트 텍스트에
적습니다. ①/② 의 «다음 세션 첫 턴» 안내에는 **워크트리 절대경로**(`pwd`)를 함께 냅니다 —
다른 터미널에서 새 세션을 열 때 그 디렉토리에서 열어야 `@<seed 경로>` 가 풀리기 때문입니다.
````

- [ ] **Step 6: SKILL.md 편집 — 두 가드 (627–635행)**

`### 두 가드` 아래 불릿 둘을 아래로 바꾼다(제목 줄과 그 뒤 `### 재결정 규약 (P23)` 절은 그대로):

```markdown
- **polite stop 금지 (AP2)** — ①/② 는 둘 다 핸드오프입니다. 이 옵션에서 polite stop 은 두 줄 명령을
  노출하지 않고 설명만 하고 끝내는 것입니다 — 명령을 노출하고 턴을 끝내는 것이 이 옵션의 완료입니다.
  게이트를 거치지 않는 예외 경로(kill switch · 경로 부재)면 명시적 advisory 단락을 동반해야 합니다 —
  게이트-less silent 종료 금지.
- **cross-compact 조기 진행 금지** — ①/② 어느 쪽이든 두 줄 명령을 노출하면 **거기서 턴 종료(STOP)**
  합니다. 같은 턴에서 인터뷰를 시작하지 않습니다. 다음 단계는 사용자가 그 명령을 실제로 친 **다음 턴**의
  사용자 트리거로만 일어납니다.
```

- [ ] **Step 7: 통과 확인 + 이 파일을 재는 기존 락**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh; echo "rc=$?"`
Expected: `rc=0`.

Run: `for t in test_request_framing_command.sh test_proceed_gate_adopters.sh test_seed_gate_wiring.sh test_seed_inline_blob.sh test_seed_agents.sh test_seed_codex_axes.sh test_seed_one_sentence.sh test_compression_adopters.sh test_stale_terms.sh; do bash plugins/spec-distill/tests/$t >/dev/null 2>&1; echo "$t rc=$?"; done; bash shared/tests/test_dispatch_disposition.sh >/dev/null 2>&1; echo "dispatch_disposition rc=$?"`
Expected: 전부 `rc=0`. `test_proceed_gate_adopters.sh` 는 framing 표면에 `턴 종료|다음 턴` · `polite stop` · `degrade 채널` · `재결정|반증` 이 있는지 잰다 — 새 두 가드가 앞의 둘을 유지한다.

- [ ] **Step 8: 커밋**

`.claude/handoff-baseline/commit-msg.txt`:

```
feat(spec-distill): framing 게이트 — /new·/compact 후 /interview @<seed 경로>

옵션을 ① /new 후 /interview @<seed 경로>(권장) · ② /compact 후 같은 명령 · ③ 수정 ·
④ 멈춤으로 바꾸고 「바로 /interview」 를 뺐다. ①/② 는 두 줄 명령을 노출하고 턴을 끝낸다.
두 가드를 두 핸드오프 옵션 기준으로 다시 쓰고, 이름 가드가 공백을 거부한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EUJwm6ktX8Rvon4NjXVZ6X
```

Run: `git add plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/tests/test_seed_at_path_handoff.sh && git commit -q -F .claude/handoff-baseline/commit-msg.txt && git status --short`
Expected: 빈 출력.

- [ ] **Step 9: 이빨 확인 — 변이 아홉**

아래 내용을 `.claude/handoff-baseline/mut-t2.sh` 로 저장하고 `bash .claude/handoff-baseline/mut-t2.sh` 로 돌린다(변수를 명령 자리에 쓰는 줄은 격리 가드가 거부하므로 스크립트 파일로 돌린다). 기대: 아홉 줄 모두 `RED-OK`. 축: 삭제(1·4·5) · 치환(6·7·8) · 순서 뒤집기(2) · 재삽입(3·9).

```bash
#!/usr/bin/env bash
cd "$(dirname "$0")/../.." || exit 2
M=.claude/handoff-baseline/mutate.sh; F=plugins/spec-distill/skills/framing-requests/SKILL.md
bash $M $F '① 행에 `/new` 후' '| ① | `/new` 후' '| ① | `/clear` 후'
bash $M $F '① 행에 `/new` 후' '| ① | `/new` 후 `/interview @<seed 경로>` (권장, 커밋 후)' '| ① | `/compact` 후 `/interview @<seed 경로>` (커밋 후)' '| ② | `/compact` 후 `/interview @<seed 경로>` (커밋 후)' '| ② | `/new` 후 `/interview @<seed 경로>` (권장, 커밋 후)'
bash $M $F '「바로」 진행 행이 없다' '| ② | `/compact` 후 `/interview @<seed 경로>` (커밋 후) — 두 줄 명령을 노출하고 **턴 종료** |' '| ② | 바로 `/interview @<seed 경로>` (커밋 후) — compact 없이 즉시 진행 |'
bash $M $F 'AC2: 자리표를' '`<seed 경로>` 는 `$SEED` 의 실제 값' '`<seed 경로>` 는 seed 경로'
bash $M $F 'AC2: /new 뒤' '`/new` 뒤 같은 줄에 텍스트를 붙이면' '명령 뒤에 텍스트를 붙이면'
bash $M $F '정지 가드 한 불릿 안에 ①/②' '①/② 어느 쪽이든' '옵션 ① 을 고르면'
bash $M $F '공백 든 TOPIC 거부' '*/*|*[[:space:]]*) : ;;' '*/*) : ;;'
bash $M $F '공백 든 IV_NAME 거부' '*">"*|*[[:space:]]*)' '*">"*)'
bash $M $F '옛 polite stop 문면' '- **polite stop 금지 (AP2)** — ' '- **polite stop 금지 (AP2)** — 승인 옵션인데 narrate 만 하고 다음 단계로 가지 않는 것은 polite stop 입니다. '
```

끝나고 `git status --short` 가 비어 있어야 한다.

---

### Task 3: 공유 계약 일반화

**Files:**
- Modify: `plugins/spec-distill/references/proceed-gate.md` — 12–14행(각 skill 이 채우는 것) · 20–21행(Step A) · 33–34행(Step B 표 ①②) · 55–58행(가드 1) · 64–74행(가드 2) · 99행(검증 절 리뷰 레이어) · 117–119행(앵커 절)
- Modify: `plugins/spec-distill/tests/test_seed_at_path_handoff.sh` (`finish` 위에 절 추가)

**Interfaces:**
- Consumes: Task 1 의 `block` · `flat` · `CANON`.
- Produces: 없음.

정본은 채택자 presence 코퍼스에 넣지 않는다(`test_proceed_gate_adopters.sh` 의 구조적 가드). 이 절의 단언은 정본 **자체**를 대상으로 하는 별도 단언이라 그 규칙과 부딪치지 않는다. 정본은 세 채택자(`conducting-interview` · `reviewing-spec` · `framing-requests`)의 이름을 계속 대야 한다 — 채택자 도출이 그 이름에 걸려 있다.

- [ ] **Step 1: 실패하는 단언 추가**

`finish` 줄 바로 위에:

```bash
# ── 공유 계약: 정본 자체에 대한 단언 ───────────────────────────────────────
stepb="$(block '^## Step B' '^## ' "$CANON")"
c1="$(printf '%s\n' "$stepb" | grep -E '^\| ① \|')"
c2="$(printf '%s\n' "$stepb" | grep -E '^\| ② \|')"
{ [ -n "$c1" ] && [ -n "$c2" ]; } && ok "AC4(양성): 정본 Step B 표 ①·② 행을 읽었다" || no "AC4(양성): 정본 Step B 표 ①·② 행이 없다 — 아래 단언이 공허하다"
assert_not_contains "$c1" '/compact' "AC4: Step B ① 행이 /compact 를 못박지 않는다"
assert_contains "$c1" '권장 핸드오프 — skill 이 정한 명령을 노출하고 **턴 종료**' "AC4: ① = 권장 핸드오프, 명령은 skill 이 정한다"
assert_contains "$c2" '차선 핸드오프 — skill 이 정한다' "§2: ② = 차선 핸드오프"
assert_contains "$c2" '바로 진행' "§2: ② 에 바로 진행 선택지가 있다"
fill="$(awk '/^\*\*각 skill 이 채우는 것\*\*/{f=1} f && /^$/{exit} f' "$CANON" | flat)"
assert_contains "$fill" '①/② 의 핸드오프 종류(`/compact` · `/new` · 바로 진행)와 노출할 명령' "§2: 각 skill 이 채우는 것에 핸드오프 종류"
stepa="$(block '^## Step A' '^## ' "$CANON" | flat)"
assert_contains "$stepa" '핸드오프 명령도 노출하지 않는다' "AC4: Step A — 핸드오프 명령도 노출하지 않는다"
assert_not_contains "$stepa" '`/compact` 도 노출하지 않는다' "AC4: Step A 옛 문면이 없다"
g1="$(block '^### 가드 1' '^##' "$CANON" | flat)"
assert_contains "$g1" '완료 동작은 핸드오프 종류가 정한다' "§2: 가드 1 — 완료 동작은 핸드오프 종류가 정한다"
g2="$(block '^### 가드 2' '^##' "$CANON" | flat)"
assert_contains "$g2" 'cross-compact 조기 진행 금지 (AC19)' "§2: 가드 2 제목 유지 (기존 인용이 가리키는 이름)"
assert_contains "$g2" '**명령을 노출하면 그 턴은 거기서 종료(STOP)한다.**' "AC4: 가드 2 — 명령 노출 → 턴 종료"
assert_contains "$g2" '바로 진행 옵션은 이 정지 요건의 **명시적 예외**다' "AC4: 가드 2 — 바로 진행 → 예외"
ver="$(block '^## 검증' '^## ' "$CANON" | flat)"
assert_contains "$ver" '명령을 노출하는 각 옵션의 서술 *블록 안에서*' "§2: 검증 절 리뷰 레이어 = 명령 노출 옵션마다"
assert_contains "$ver" '「호출 모양」 절 옵션 표 ①·② 행' "§2: 앵커 절 — framing 앵커에 ② 행"
```

`block '^## 검증' '^## '` 는 하위 절 `### 앵커는 각 skill 에 있고` 까지 포함한다(`### ` 는 `^## ` 에 맞지 않는다). 가드 블록은 `'^##'` 로 끊어 다음 `###` 에서 멈춘다.

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh; echo "rc=$?"`
Expected: `rc=1`. Task 1·2 절은 전부 ✓. 새 절은 `AC4(양성)` · `가드 2 제목 유지` 두 줄만 ✓ 이고, 나머지는 ✗ 다.

- [ ] **Step 3: `proceed-gate.md` 편집**

(a) 12행 `**각 skill 이 채우는 것**: 대상 문서의 이름 · 옵션 라벨의 어휘 · 다음 단계 skill 이름 ·` 바로 **다음 줄로** 한 줄을 끼운다:

```
**①/② 의 핸드오프 종류(`/compact` · `/new` · 바로 진행)와 노출할 명령** ·
```

(b) 21행 `` `/compact` 도 노출하지 않는다. loud advisory 를 내고 STOP: `` → `핸드오프 명령도 노출하지 않는다. loud advisory 를 내고 STOP:`

(c) Step B 표 ①·② 행:

```
| ① | `/compact` 후 다음 단계 (권장) — verbatim `/compact` 명령을 노출하고 **턴 종료** |
| ② | 바로 다음 단계 — compact 없이 즉시 진행 |
```
→
```
| ① | 권장 핸드오프 — skill 이 정한 명령을 노출하고 **턴 종료** |
| ② | 차선 핸드오프 — skill 이 정한다: 명령을 노출하고 **턴 종료**, 또는 바로 진행 |
```

(d) 가드 1 본문 첫 문단(55–58행)을 아래로 바꾼다(그 뒤 「게이트는 사용자가 redirect 가능한 …」 문단은 그대로):

```
approve(①/②) 를 고른 뒤 *"approved!"* 만 narrate 하고 그 옵션의 완료 동작을 skip 하는 것은
polite stop 이다. 완료 동작은 핸드오프 종류가 정한다 — 명령을 노출하는 옵션은 명령 노출(그 뒤
턴 종료), 바로 진행 옵션은 다음 단계 진입이다. 게이트를 **실제로 띄우는 것** 이 이 금지를 푸는
유일한 방법이며, 게이트를 거치지 않는 예외 경로(Step A 의 경로 부재 · kill switch)는 **명시적
advisory 단락**을 동반해야 한다. 게이트-less silent 종료는 금지다.
```

(e) 가드 2 본문(제목 `### 가드 2 — cross-compact 조기 진행 금지 (AC19)` 는 그대로, 64–74행)을 아래로 바꾼다:

```
명령을 노출하는 옵션(`/compact` · `/new` 등)을 고르면 그 명령을 노출한 **직후 같은 턴에서** 다음
단계로 직진하는 것은 금지다. 명령이 무거운 작업 *뒤에* 오면 context 위생 이점이 사라져 그 옵션이
무의미해진다.

**명령을 노출하면 그 턴은 거기서 종료(STOP)한다.** 다음 단계 진입은 사용자가 그 명령을
*실제 실행한 다음 턴* 에 **사용자 트리거**로만 일어난다 — 모델은 다음 턴에
자동 진입하지 *않고* 신호를 기다리며, 사용자가 redirect 하면 미진입이다(NG4·P17).

polite stop 이 *"진행해야 할 때 멈춤"* 이라면 이것은 *"멈춰야 할 때 진행"* 이다 —
두 방향 모두 게이트의 사용자-주권(P17)을 우회한다.

바로 진행 옵션은 이 정지 요건의 **명시적 예외**다 (다음 단계로 즉시 진행).
```

(`(NG4·P17)` 은 이 파일에 원래 있던 표기라 그대로 둔다.)

(f) 99행 `2. **리뷰** — 옵션 ① 서술 *블록 안에서*` → `2. **리뷰** — 명령을 노출하는 각 옵션의 서술 *블록 안에서*` (줄의 나머지 그대로)

(g) 117–119행:

```
기계적 레이어의 앵커는 **각 skill 의 옵션 ① 서술 블록**에 산다 — `reviewing-spec` 의
`## 게이트` 절 옵션 표 ① 행과 그 아래 「① 의 정지 요건」 불릿, `conducting-interview` 의
`#### B-3` ①, `framing-requests` 의 「호출 모양」 절 옵션 표 ① 이다.
```
→
```
기계적 레이어의 앵커는 **각 skill 의 명령 노출 옵션 서술 블록**에 산다 — `reviewing-spec` 의
`## 게이트` 절 옵션 표 ① 행과 그 아래 「① 의 정지 요건」 불릿, `conducting-interview` 의
`#### B-3` ①, `framing-requests` 의 「호출 모양」 절 옵션 표 ①·② 행이다.
```

`reviewing-spec` · `conducting-interview` 쪽 파일은 건드리지 않는다 — 두 skill 의 ①(`/compact`)·②(바로 진행)는 새 표에 그대로 맞는다. 두 skill 의 가드 1 문면이 자기 ① 의 정지 요건과 어긋나는 것은 이번 변경 전부터 있던 불일치이고 이 계획의 범위 밖이다(Task 6 의 보고에 후속 과제로 적는다).

- [ ] **Step 4: 통과 확인 + 정본을 재는 기존 락**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh; echo "rc=$?"`
Expected: `rc=0`.

Run: `for t in test_proceed_gate_adopters.sh test_rereview_cap_consistency.sh test_brief_review_entry.sh test_conducting_interview_stage.sh test_compression_adopters.sh test_stale_terms.sh; do bash plugins/spec-distill/tests/$t >/dev/null 2>&1; echo "$t rc=$?"; done`
Expected: 전부 `rc=0`. `test_proceed_gate_adopters.sh` 의 합집합(정본이 이름을 대는 skill)이 여전히 셋인지 그 출력의 「채택자 도출」 줄로 확인한다: `bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh | grep '채택자 도출'` → `채택자 도출 3개`.

- [ ] **Step 5: 커밋**

`.claude/handoff-baseline/commit-msg.txt`:

```
refactor(spec-distill): 공유 게이트 계약 ①/② 를 권장/차선 핸드오프로 일반화

Step B 표의 ①/② 가 /compact 와 바로 진행을 못박지 않고 핸드오프 종류와 노출할 명령을
각 skill 이 채우게 했다. 가드 2 는 명령을 노출하는 모든 옵션에 걸리고 바로 진행이 예외,
가드 1 의 완료 동작은 핸드오프 종류가 정한다. reviewing-spec·conducting-interview 는 무수정.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EUJwm6ktX8Rvon4NjXVZ6X
```

Run: `git add plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/tests/test_seed_at_path_handoff.sh && git commit -q -F .claude/handoff-baseline/commit-msg.txt && git status --short`
Expected: 빈 출력.

- [ ] **Step 6: 이빨 확인 — 변이 여섯**

아래를 `.claude/handoff-baseline/mut-t3.sh` 로 저장하고 `bash .claude/handoff-baseline/mut-t3.sh` 로 돌린다. 기대: 여섯 줄 모두 `RED-OK`. 축: 재삽입(1) · 치환(2·3·4·6) · 삭제(5).

```bash
#!/usr/bin/env bash
cd "$(dirname "$0")/../.." || exit 2
M=.claude/handoff-baseline/mutate.sh; F=plugins/spec-distill/references/proceed-gate.md
bash $M $F 'Step B ① 행이 /compact' '| ① | 권장 핸드오프 — skill 이 정한 명령을' '| ① | 권장 핸드오프 — `/compact` 명령을'
bash $M $F '가드 2 — 바로 진행' '바로 진행 옵션은 이 정지 요건의 **명시적 예외**다' '옵션 ② 는 이 정지 요건의 **명시적 예외**다'
bash $M $F 'AC4: Step A' '핸드오프 명령도 노출하지 않는다' '`/compact` 도 노출하지 않는다'
bash $M $F '가드 1 — 완료 동작' '완료 동작은 핸드오프 종류가 정한다' '다음 단계 진입이 완료다'
bash $M $F '앵커 절' '옵션 표 ①·② 행이다' '옵션 표 ① 이다'
bash $M $F '각 skill 이 채우는 것' '①/② 의 핸드오프 종류' '옵션 라벨'
```

끝나고 `git status --short` 가 비어 있어야 한다.

---

### Task 4: 문구 동기화와 옛 호출 모양 부재 락

**Files:**
- Modify: `plugins/spec-distill/commands/request-framing.md` — 2행 · 9–10행 · 37–41행
- Modify: `plugins/spec-distill/skills/conducting-interview/references/seed-input.md` — 3–7행
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md` — 43–44행(두 줄, 줄 수 유지)
- Modify: `plugins/spec-distill/templates/interview-seed-audit-template.md` — 11–13행
- Modify: `plugins/spec-distill/README.md` — 32–34행(71행 v0.41.0 이력 단락은 **그대로**)
- Modify: `plugins/spec-distill/tests/test_seed_at_path_handoff.sh` (`finish` 위에 절 추가)

**Interfaces:**
- Consumes: Task 1 의 `CORPUS` · `SK` · `CMD` · `RF` · `README` · `CANON` · `SD`.
- Produces: 없음.

- [ ] **Step 1: 실패하는 단언 추가**

`finish` 줄 바로 위에:

```bash
# ── 옛 호출 모양 부재(코퍼스 전수) + 새 모양 실재 ──────────────────────────
ncorp="${#CORPUS[@]}"
for need in "$SK" "$CMD" "$RF" "$README" "$CANON"; do
  case " ${CORPUS[*]+"${CORPUS[*]}"} " in
    *" $need "*) ok "AC6(양성): 코퍼스에 ${need#"$ROOT"/} 가 들어 있다" ;;
    *) no "AC6(양성): 코퍼스에 ${need#"$ROOT"/} 가 없다 — 부재 단언이 그 파일을 안 본다" ;;
  esac
done
old_hits="$(grep -nF -e '<seed 전문>' -e '<seed 파일 전문>' -- "${CORPUS[@]+"${CORPUS[@]}"}" 2>&1)"; grc=$?
if [ "$ncorp" -eq 0 ]; then
  no "AC6: 코퍼스 0개 — 부재를 잴 수 없다"
elif [ "$grc" -ge 2 ]; then
  no "AC6: grep 실패(rc=$grc) — 부재를 확인하지 못했다: $old_hits"
elif [ -n "$old_hits" ]; then
  no "AC6: 옛 호출 모양이 남았다:"; printf '%s\n' "$old_hits"
else
  ok "AC6: 옛 호출 모양(<seed 전문> · <seed 파일 전문>) 0건 — 문서 ${ncorp}개"
fi
for f in "$SK" "$RF" "$CMD" "$README"; do
  assert_file_grep "$f" '/interview @<seed 경로>' "AC6: 새 모양이 ${f#"$ROOT"/} 에 있다"
done

# ── 풀어 쓴 옛 서술의 동기화 (§4 목록) ──────────────────────────────────
TPL="$SD/templates/interview-seed-audit-template.md"
SEEDIN="$SD/skills/conducting-interview/references/seed-input.md"
FIN="$SD/skills/conducting-interview/references/finishing.md"
assert_file_grep   "$TPL"    '/interview @<seed 경로>` 가 가리키는 것은 payload' "§4: audit 템플릿 인용 블록이 새 모양"
assert_file_absent "$TPL"    '첫 턴에 붙여넣는' "§4: audit 템플릿에 옛 핸드오프 서술이 없다"
assert_file_grep   "$SEEDIN" '`/interview @<seed 경로>` 를 치게 하고' "§4: seed-input 도착 경로가 새 모양"
assert_file_absent "$SEEDIN" '붙여넣게 하고' "§4: seed-input 에 옛 도착 경로가 없다"
assert_file_grep   "$FIN"    '`@경로` 를 풀어 넘겼든 사용자가 전문을 붙여넣었든' "§4: finishing S1 문장이 두 도착 경로를 다 적는다"
assert_file_absent "$RF"     '붙여넣' "§4: request-framing 에 붙여넣기 핸드오프 서술이 없다"
assert_file_absent "$README" '다음 세션 첫 턴에 붙여넣는 메시지' "§4: README 흐름도에 옛 서술이 없다"
```

부재 단언 셋(`assert_file_absent`)은 파일이 없으면 ✗ 를 낸다(assert.sh 의 fail-closed). 코퍼스 부재 단언의 양성 짝은 위 멤버십 다섯 줄과, 같은 코퍼스를 쓰는 새 모양 실재 단언이다.

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh; echo "rc=$?"`
Expected: `rc=1`. 멤버십 다섯 줄 ✓. `AC6: 옛 호출 모양이 남았다:` 아래 목록에 **`README.md` 와 `commands/request-framing.md` 의 줄만** 나온다 — framing SKILL.md 와 interview.md 가 목록에 있으면 Task 1·2 가 덜 된 것이니 멈추고 보고한다. 새 모양 실재는 SKILL.md·interview.md ✓, request-framing.md·README.md ✗. §4 단언은 전부 ✗.

- [ ] **Step 3: `commands/request-framing.md`**

(a) 2행 → `description: 파이프라인 맨 앞의 회의 — 사용자의 의도·steering·방향·goal 을 싱크해 새 세션 첫 턴 `/interview @<seed 경로>` 가 가리킬 `interview-seed` 로 압축한다.`

(b) 10행 `맡기는가」를 정하고, 그것을 새 세션의 첫 턴에 그대로 붙여넣을 메시지 하나로 압축합니다.` → `맡기는가」를 정하고, 그것을 새 세션의 첫 턴 `/interview @<seed 경로>` 가 가리킬 파일 하나로 압축합니다.`

(c) `## 다음 단계` 본문(37–41행)을 아래로 바꾼다:

```
skill 이 확산 후 압축을 거쳐 `interview-seed` 를 `docs/superpowers/interview/` 에
만듭니다. 그 seed 는 **새 세션의 첫 턴이 가리키는 파일**이고, 그 첫 턴은
`/interview @<seed 경로>` 한 줄입니다 — `/interview` 가 그 파일을 전문으로 풀어 인터뷰에 넘깁니다.
이 모양의 정본과 그렇게 정한 이유는 `framing-requests` skill 의
`## 확정 — proceed 게이트` 안 「호출 모양」 절에 있습니다. 여기서 다시 정하지 않습니다.
```

- [ ] **Step 4: `seed-input.md` 3–7행**

```
`$ARGUMENTS` 가 `type: interview-seed` frontmatter 를 가진 문서면, 그것은 **Phase 0 에서
사용자가 확정한 메시지**다. Phase 0 은 그 파일을 **전문으로** 이 command 의 인자에
붙여넣게 하고(그 호출 모양의 정본은 `framing-requests` 의 「호출 모양」 절이다), 그
frontmatter 줄이 seed 를 알아보는 유일한 표지다 — 본문만 오면 seed 로 인식되지 않아 아래
규약이 발동하지 않는다.
```
→
```
`$ARGUMENTS` 가 `type: interview-seed` frontmatter 를 가진 문서면, 그것은 **Phase 0 에서
사용자가 확정한 메시지**다. Phase 0 은 사용자에게 `/interview @<seed 경로>` 를 치게 하고,
`/interview` 가 그 파일을 전문(frontmatter 포함)으로 풀어 이 skill 에 넘긴다(그 호출 모양의 정본은
`framing-requests` 의 「호출 모양」 절이다). 그 frontmatter 줄이 seed 를 알아보는 유일한 표지다 —
본문만 오면 seed 로 인식되지 않아 아래 규약이 발동하지 않는다.
```

9행 이하(`§6 `S1` 은 `$ARGUMENTS` 원문 그대로다` 등)는 그대로다 — `test_conducting_interview_stage.sh` 가 그 리터럴들을 잰다.

- [ ] **Step 5: `finishing.md` 43–44행 (두 줄 → 두 줄)**

```
   Phase 0 을 거친 세션에서는 그 `$ARGUMENTS` 가 `interview-seed` 파일 전문이고, 그때도
   같은 규칙이 그대로 적용됩니다:
```
→
```
   Phase 0 을 거친 세션에서는 `/interview` 가 `@경로` 를 풀어 넘겼든 사용자가 전문을 붙여넣었든
   그 `$ARGUMENTS` 가 `interview-seed` 파일 전문이고, 그때도 같은 규칙이 그대로 적용됩니다:
```

줄 수를 바꾸지 않는다 — 아래 번호 규칙 단락(51–57행)을 재는 락이 있다. 이 파일의 다른 줄은 손대지 않는다.

- [ ] **Step 6: audit 템플릿 11–13행**

```
> 순수 텔레메트리 — 다음 세션의 첫 턴에 붙여넣는 것은 payload(seed) 파일 전문이고,
> 여기에는 확산·압축이 어떻게 진행됐는지의 과정 기록만 남는다. payload 의 `audit_file`
> 이 이 파일을 가리킨다.
```
→
```
> 순수 텔레메트리 — 다음 세션의 첫 턴 `/interview @<seed 경로>` 가 가리키는 것은 payload(seed)
> 파일이고, 여기에는 확산·압축이 어떻게 진행됐는지의 과정 기록만 남는다. payload 의 `audit_file`
> 이 이 파일을 가리킨다.
```

- [ ] **Step 7: README 32–34행**

세 줄을 아래로 바꾼다(앞의 공백 들여쓰기는 원래 줄과 같게):

```
                                       ▼ [확정 — proceed 게이트] ①/new 후 /interview @경로 · ②/compact 후 /interview @경로 · ③수정 필요 · ④멈춤
                                   interview-seed → docs/superpowers/interview/   ← 문서가 아니라 다음 세션 첫 턴이 가리키는 파일
                                       ▼ 새 세션 첫 턴 = `/interview @<seed 경로>` (/interview 가 frontmatter 포함 전문으로 풀어 인터뷰에 넘김)
```

- [ ] **Step 8: 통과 확인 + 개념어 잔여 스윕**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh; echo "rc=$?"`
Expected: `rc=0`.

Run: `git grep -nE '붙여넣|전문으로|인자로 넣|seed 전문|seed 파일 전문' -- plugins/spec-distill ':!plugins/spec-distill/tests' ':!plugins/spec-distill/CHANGELOG.md'`
Expected: 모든 줄이 아래 셋 중 하나다. 붙여넣기를 **핸드오프 경로로** 서술하는 줄(「첫 턴에 붙여넣는」 류)이 하나라도 있으면 그 줄을 새 모양으로 고치고 Step 8 을 다시 한다.

| 부류 | 기대하는 자리 |
|---|---|
| 이력 · 다른 뜻 · 하류 값의 이름 (그대로 둔다) | README v0.41.0 단락 · framing SKILL.md 냉독 `cat` 출처 서술(「seed 전문이 그대로 나오고」) · `conducting-interview/SKILL.md` 「seed 전문(S1)」 · `agents/coverage-mapper.md` 「seed 전문(S1)」 · `scripts/check_brief.py` 「산문 전문으로」 · `finishing.md` brainstorming `/compact` 명령 서술(「그대로 붙여넣는 것」) |
| 새 메커니즘 서술 | interview.md Step 2.5 「전문으로 풉니다」 · request-framing.md 「전문으로 풀어」 · framing SKILL.md 호출 모양 「전문으로 풀어」 · seed-input.md 「전문(frontmatter 포함)으로 풀어」 |
| 호환(붙여넣기도 받는다) | interview.md Arguments 「seed 전문을 직접 붙여넣은」 · finishing.md S1 「전문을 붙여넣었든」 |

Run: `git grep -nE '<seed 전문>|<seed 파일 전문>|/interview <seed' -- ':!docs/superpowers' ':!docs/archive' ':!plugins/spec-distill/CHANGELOG.md' ':!plugins/spec-distill/tests'`
Expected: 빈 출력(플러그인 밖 — `CLAUDE.md` · 철학 문서 · 다른 플러그인 — 에도 옛 모양이 없다. 계획 작성 시점 실측도 0건).

Run: `for t in test_request_framing_command.sh test_conducting_interview_stage.sh test_readme_sync.sh test_stale_terms.sh test_seed_inline_blob.sh test_check_seed.sh; do bash plugins/spec-distill/tests/$t >/dev/null 2>&1; echo "$t rc=$?"; done; PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_finishing_block_scope.py' 2>&1 | tail -1`
Expected: 셸 여섯 `rc=0`, python 마지막 줄 `OK`.

- [ ] **Step 9: 커밋**

`.claude/handoff-baseline/commit-msg.txt`:

```
docs(spec-distill): seed 핸드오프 서술을 /interview @<seed 경로> 로 동기화

request-framing command · seed-input · finishing 의 S1 문장 · audit 템플릿 · README 흐름도가
「다음 세션 첫 턴에 붙여넣는 메시지」 대신 「첫 턴 /interview @<seed 경로> 가 가리키는 파일」을
적는다. 옛 호출 모양(<seed 전문> · <seed 파일 전문>)의 부재 락과 그 양성 짝을 더했다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EUJwm6ktX8Rvon4NjXVZ6X
```

Run: `git add plugins/spec-distill/commands/request-framing.md plugins/spec-distill/skills/conducting-interview/references/seed-input.md plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/README.md plugins/spec-distill/tests/test_seed_at_path_handoff.sh && git commit -q -F .claude/handoff-baseline/commit-msg.txt && git status --short`
Expected: 빈 출력.

- [ ] **Step 10: 이빨 확인 — 변이 여섯**

아래를 `.claude/handoff-baseline/mut-t4.sh` 로 저장하고 `bash .claude/handoff-baseline/mut-t4.sh` 로 돌린다. 기대: 여섯 줄 모두 `RED-OK`. 축: 재삽입(1·2·4·5) · 삭제(3·6). 3번은 같은 문자열 세 곳을 모두 지운다 — 한 곳만 지우면 나머지 둘이 실재 단언을 만족시켜 이빨을 못 잰다.

```bash
#!/usr/bin/env bash
cd "$(dirname "$0")/../.." || exit 2
M=.claude/handoff-baseline/mutate.sh; P=plugins/spec-distill
bash $M $P/README.md '옛 호출 모양이 남았다' '새 세션 첫 턴 = `/interview @<seed 경로>`' '새 세션 첫 턴 = `/interview <seed 파일 전문>`'
bash $M $P/commands/request-framing.md '옛 호출 모양이 남았다' '`/interview @<seed 경로>` 한 줄입니다' '`/interview <seed 전문>` 한 줄입니다'
bash $M $P/commands/request-framing.md '새 모양이 plugins/spec-distill/commands/request-framing.md' '/interview @<seed 경로>' '/interview' '/interview @<seed 경로>' '/interview' '/interview @<seed 경로>' '/interview'
bash $M $P/templates/interview-seed-audit-template.md 'audit 템플릿' '첫 턴 `/interview @<seed 경로>` 가 가리키는 것은 payload(seed)' '첫 턴에 붙여넣는 것은 payload(seed)'
bash $M $P/skills/conducting-interview/references/seed-input.md 'seed-input' '`/interview @<seed 경로>` 를 치게 하고,' '그 파일을 전문으로 이 command 의 인자에 붙여넣게 하고,'
bash $M $P/skills/conducting-interview/references/finishing.md 'finishing S1' '`@경로` 를 풀어 넘겼든 사용자가 전문을 붙여넣었든' '사용자가'
```

끝나고 `git status --short` 가 비어 있어야 한다.

---

### Task 5: 버전 · CHANGELOG · 전체 스위트 · 범위 확인

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` — `"version": "1.0.0"` → `"version": "1.1.0"`
- Modify: `plugins/spec-distill/CHANGELOG.md` — 맨 위(`# Changelog` 다음 빈 줄 뒤)에 엔트리 추가

**Interfaces:**
- Consumes: Task 0 의 `baseline.tsv` · `shared-t0.txt` · `shared-locks.sh` · `run.sh`.
- Produces: 커밋된 1.1.0 트리 — Task 6 이 이 트리를 헤드리스 세션에 싣는다.

- [ ] **Step 1: plugin.json**

`"version": "1.0.0",` → `"version": "1.1.0",`. 다른 필드는 그대로.

- [ ] **Step 2: CHANGELOG 엔트리**

`# Changelog` 줄과 빈 줄 다음, `## [1.0.0] — 2026-09-09` **위**에 넣는다:

```markdown
## [1.1.0] — 2026-09-10

minor 인 이유: `/interview` 가 새 입력 모양 `@<seed 경로>` 를 받는다 — 새 surface 다. 옛 입력(rough request · seed 전문 붙여넣기)은 그대로 동작한다.

### Added

- **`/interview` Step 1.5 — `@경로` 인자 풀기.** 앞뒤 공백을 걷은 인자가 `@` 로 시작하는 공백 없는 한 토큰이면 그 파일을 Read 로 읽어 frontmatter 포함 전문을 「풀린 입력」으로 삼고, Step 2(trivia) · Step 2.5(seed 판별) · Step 3(`Skill conducting-interview`)이 그 값을 쓴다. 읽기 실패면 사유를 담은 문구를 내고 인터뷰를 시작하지 않는다. 입구에서 직접 푸는 이유: 2026-09-10 헤드리스 실측(`claude -p`)에서 커맨드 인자의 `@경로` 는 `$ARGUMENTS` 에 리터럴로 남고 파일이 첨부되지 않았다(평문 프롬프트의 `@경로` 는 첨부됐다). 대화형 입력은 재지 않았다 — 거기서 첨부되더라도 command 본문이 읽는 것은 치환된 인자라 이 단계가 필요하다.
- `tests/test_seed_at_path_handoff.sh` — framing 옵션 표 · 호출 모양 · 두 가드 · 공유 계약(정본 자체) · Step 1.5 · 옛 호출 모양 부재(코퍼스 멤버십 양성 짝 포함) · 이름 가드 공백 거부(case 패턴을 실제로 돌린다). 단언 종류마다 삭제 · 치환 · 순서 뒤집기 · 재삽입 변이로 RED 를 확인했다.

### Changed

- **framing 게이트의 핸드오프가 `/interview @<seed 경로>` 로 바뀌었다.** 옵션은 ① `/new` 후 `/interview @<seed 경로>`(권장) · ② `/compact` 후 같은 명령 · ③ 수정 · ④ 멈춤이다. ①/② 는 두 줄 명령을 노출하고 턴을 끝낸다. 「바로 `/interview`」 옵션은 없어졌다 — `AskUserQuestion` 한 질문의 옵션 상한이 4 다. `/new` 는 `/clear [name]` 의 별칭이라 같은 줄 뒤 텍스트가 세션 이름이 되므로 두 줄을 따로 입력하게 안내한다. 권장이 `/new` 인 이유: seed 는 framing 대화를 대신하려고 존재하고, `/compact` 는 그 대화의 요약을 남긴다.
- **공유 게이트 계약(`references/proceed-gate.md`)의 ①/② 를 「권장/차선 핸드오프」로 일반화했다.** 핸드오프 종류(`/compact` · `/new` · 바로 진행)와 노출할 명령은 각 skill 이 채운다. 가드 2 는 명령을 노출하는 모든 옵션에 걸리고 바로 진행 옵션이 예외다. 가드 1 의 완료 동작은 핸드오프 종류가 정한다. Step A 는 「핸드오프 명령도 노출하지 않는다」. `reviewing-spec` · `conducting-interview` 는 새 표에 그대로 맞아 바뀌지 않았다. **이 릴리스가 닫지 않는 것**: 두 skill 의 가드 1 문면(「①/② 선택 후 … 다음 단계 진입을 skip 하면 polite stop」)이 자기 ① 의 정지 요건과 어긋나는 것은 이번 변경 전부터 있던 불일치다.
- framing 의 이름 가드(`TOPIC` · `IV_NAME`)가 공백을 거부한다 — seed 경로가 한 토큰이어야 `/interview` 가 `@경로` 로 푼다. 공백 든 경로를 사람이 손으로 넘기면 Step 1.5 는 발동하지 않고 거친 요청으로 받는다.
- 옛 핸드오프(「다음 세션 첫 턴에 붙여넣는 메시지」)를 풀어 쓴 문장을 `commands/request-framing.md` · `conducting-interview/references/seed-input.md` · `finishing.md` 의 S1 문장 · `templates/interview-seed-audit-template.md` · README 흐름도에서 새 모양으로 바꿨다. README 의 v0.41.0 이력 단락은 그 버전이 한 일의 기록이라 그대로 뒀다.

```

- [ ] **Step 3: 버전·CHANGELOG 를 재는 락**

Run: `bash shared/tests/test_changelog_integrity.sh >/dev/null 2>&1; echo "changelog rc=$?"; for t in test_readme_sync.sh test_brief_review_meta.sh; do bash plugins/spec-distill/tests/$t >/dev/null 2>&1; echo "$t rc=$?"; done`
Expected: 셋 다 `rc=0`. `test_changelog_integrity.sh` 는 헤딩 형식(`## [x.y.z] — YYYY-MM-DD`) · 위에서 아래로 순감소 · 건너뛴 버전을 잰다.

- [ ] **Step 4: 커밋**

`.claude/handoff-baseline/commit-msg.txt`:

```
chore(spec-distill): 1.1.0 — seed @경로 핸드오프

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EUJwm6ktX8Rvon4NjXVZ6X
```

Run: `git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md && git commit -q -F .claude/handoff-baseline/commit-msg.txt && git status --short`
Expected: 빈 출력.

- [ ] **Step 5: 전체 spec-distill 스위트 (V3 · AC9)**

Run: `bash .claude/handoff-baseline/run.sh .claude/handoff-baseline/after.tsv`
Expected: 마지막 줄 `total=81 nonzero=2`.

Run: `diff .claude/handoff-baseline/baseline.tsv .claude/handoff-baseline/after.tsv`
Expected: 새 테스트 한 줄의 추가(`> test_seed_at_path_handoff.sh	0	0`)만 나온다. 다른 줄이 하나라도 달라졌으면 — 선재 RED 두 파일의 실패 줄 수가 1 에서 바뀐 경우 포함 — 회귀다. 멈추고 그 파일의 출력을 읽어 원인을 보고한다.

- [ ] **Step 6: 공용 락 셋**

Run: `bash .claude/handoff-baseline/shared-locks.sh > .claude/handoff-baseline/shared-t5.txt; diff .claude/handoff-baseline/shared-t0.txt .claude/handoff-baseline/shared-t5.txt && echo SAME`
Expected: `SAME`. 새 테스트는 `# guards: plugins/spec-distill/**` 를 선언하고 `--emit-scanned` 로 부재 코퍼스를 낸다 — `test_guards_coverage_bidirectional.sh` 가 그 둘이 서로를 덮는지 잰다. `test_no_new_duplication.sh` 는 20줄 이상 같은 블록이 다른 파일과 겹치는지 잰다.

- [ ] **Step 7: 범위 확인 (V5 · AC7)**

Run: `git diff --quiet origin/main...HEAD -- plugins/spec-distill/skills/reviewing-spec plugins/spec-distill/skills/conducting-interview/SKILL.md && echo SCOPE-OK`
Expected: `SCOPE-OK`.

Run: `git diff -U0 origin/main...HEAD -- plugins/spec-distill/skills/conducting-interview/references/finishing.md | grep '^@@'`
Expected: 한 줄 `@@ -43,2 +43,2 @@` — S1 규칙 단락 안의 두 줄뿐.

Run: `git diff --stat origin/main...HEAD`
Expected: 파일 13개 — 설계 문서 · 이 계획 · 계획서 File Structure 표의 플러그인 파일 11개(신설 테스트 포함). 그 밖의 파일이 있으면 멈추고 보고한다.

---

### Task 6: 실동작 측정(V4)과 사람이 할 관측 둘

**Files:**
- Create: `.claude/handoff-baseline/v4/run_v4.sh` · `.claude/handoff-baseline/v4/judge_v4.py` (git 무시, 커밋 안 함)
- Modify: `plugins/spec-distill/CHANGELOG.md` — `[1.1.0]` 의 `### Added` 에 결과 한 줄(전부 PASS 일 때만)

**Interfaces:**
- Consumes: Task 5 까지 커밋된 트리.
- Produces: V4 판정 출력(`PASS`/`FAIL` 줄 + `FAILS=<n>`), 사람이 할 관측 둘의 결과.

**비용** — 헤드리스 세션 2개(sonnet). 첫째 세션은 인터뷰 첫 라운드까지 돌며 하위 agent(coverage-mapper 등)를 부를 수 있다. 웹과 codex 는 kill switch 로 끈다. 수 분이 걸린다.

**S1 보존은 대리 채널로 잰다** — 설계의 이관 항목(2e6610eb)은 「생성된 brief §6 S1 이 픽스처 전문과 일치하는가」를 요구한다. brief 는 인터뷰가 여러 라운드 사용자 답을 받은 뒤에야 생기고, 헤드리스 한 턴으로는 거기 닿지 않는다(헤드리스 세션에는 `AskUserQuestion` 도 없다). 그래서 `Skill conducting-interview` 호출의 인자가 픽스처 전문과 **같은가**를 잰다. `finishing.md` 의 S1 규칙이 §6 S1 에 그대로 옮기는 값이 바로 그 인자다. 이 판정은 「파일을 읽고도 경로를 넘기거나 본문 일부만 넘기는」 실패를 잡는다. 그 인자를 S1 에 옮기는 단계 자체는 재지 않는다 — 그 단계는 이번 변경이 건드리지 않았다.

- [ ] **Step 1: 실행 스크립트**

`.claude/handoff-baseline/v4/run_v4.sh`:

```bash
#!/usr/bin/env bash
# V4 — 워크트리의 spec-distill 을 --plugin-dir 로 싣고 /spec-distill:interview 를 두 번 돌린 뒤 판정한다.
#   ok      : @<픽스처 seed> → 풀린 입력으로 인터뷰가 시작되는가
#   missing : @<없는 경로>   → 부재 문구를 내고 멈추는가
set -u
WT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUG="$WT/plugins/spec-distill"
[ -f "$PLUG/commands/interview.md" ] || { echo "플러그인 경로 이상: $PLUG" >&2; exit 2; }
V4="${CLAUDE_JOB_DIR:-$HOME/.cache/devbrew}/v4-seed-at-path"
case "$V4" in */v4-seed-at-path) ;; *) echo "V4 경로 이상: '$V4'" >&2; exit 2 ;; esac
rm -rf "$V4"
mkdir -p "$V4/docs/superpowers/interview" || exit 2
cd "$V4" || exit 2
git init -q .
SEED_REL="docs/superpowers/interview/2026-09-10-umbrella-kiosk-interview.md"
cat > "$SEED_REL" <<'EOF'
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: 2026-09-10-umbrella-kiosk-interview.audit.md
---

보라색 우산 대여 키오스크가 반납 알림 문자를 이틀 늦게 보낸다. 그 지연의 원인을 찾아 고치고 싶다 (사용자 확인).

다시 검증할 것 — 지연이 문자 발송 대행사 쪽에서 생긴다는 것은 Phase 0 의 추론이다.
EOF
printf '%s\n' "$SEED_REL" > "$V4/seed-rel.txt"
export DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1
run() {
  claude -p "$2" --plugin-dir "$PLUG" --model sonnet --permission-mode acceptEdits \
    --output-format stream-json --verbose > "$V4/$1.jsonl" 2> "$V4/$1.stderr"
  echo "$1 rc=$?"
}
run ok "/spec-distill:interview @$SEED_REL"
run missing "/spec-distill:interview @docs/superpowers/interview/no-such-seed.md"
echo "V4DIR=$V4"
python3 "$WT/.claude/handoff-baseline/v4/judge_v4.py" "$V4" "$PLUG"; echo "judge rc=$?"
```

프롬프트는 위치 인자로 **맨 앞**에 두고 가변 인자 플래그(`--allowedTools` 류)를 쓰지 않는다 — 가변 인자 플래그는 뒤따르는 프롬프트를 삼킨다. 커맨드는 네임스페이스 이름(`/spec-distill:interview`)으로만 등록된다. 권한 플래그가 없으면 편집이 조용히 막히고 rc 는 0 이다 — 그래서 `acceptEdits` 를 준다. 스크래치 디렉토리는 리포 밖이라 그 안의 쓰기는 무해하다. `rm -rf` 앞의 `case` 는 경로가 비거나 엉뚱할 때 지우지 않게 막는다.

- [ ] **Step 2: 판정 스크립트**

`.claude/handoff-baseline/v4/judge_v4.py`:

```python
"""V4 판정 — run_v4.sh 가 남긴 두 stream-json 을 읽어 (a)(b)(c) 와 S1 대리를 판정한다."""
import json
import pathlib
import sys

v4 = pathlib.Path(sys.argv[1])
plug = sys.argv[2]
seed_rel = (v4 / "seed-rel.txt").read_text(encoding="utf-8").strip()
fixture = (v4 / seed_rel).read_text(encoding="utf-8")


def events(name):
    p = v4 / f"{name}.jsonl"
    out = []
    if p.exists():
        for ln in p.read_text(encoding="utf-8").splitlines():
            ln = ln.strip()
            if ln:
                try:
                    out.append(json.loads(ln))
                except ValueError:
                    pass
    return out


def blocks(evs, kind):
    for e in evs:
        if e.get("type") != "assistant":
            continue
        for b in (e.get("message") or {}).get("content") or []:
            if isinstance(b, dict) and b.get("type") == kind:
                yield b


def text(evs):
    return "\n".join(b.get("text", "") for b in blocks(evs, "text"))


def skill_calls(evs):
    return [b.get("input") or {} for b in blocks(evs, "tool_use")
            if b.get("name") == "Skill"
            and str((b.get("input") or {}).get("skill", "")).endswith("conducting-interview")]


fails = 0


def check(ok, label, detail=""):
    global fails
    print(("PASS " if ok else "FAIL ") + label + (f" — {detail}" if detail else ""))
    if not ok:
        fails += 1


ok_ev, miss_ev = events("ok"), events("missing")
check(bool(ok_ev), "ok 실행의 이벤트를 읽었다", f"{len(ok_ev)}개")
check(bool(miss_ev), "missing 실행의 이벤트를 읽었다", f"{len(miss_ev)}개")

raw_ok = (v4 / "ok.jsonl").read_text(encoding="utf-8") if (v4 / "ok.jsonl").exists() else ""
init = next((e for e in ok_ev if e.get("type") == "system" and e.get("subtype") == "init"), {})
plugin_paths = [str(p.get("path", "")) for p in (init.get("plugins") or []) if isinstance(p, dict)]
dev_by_path = plug in plugin_paths
dev_by_text = "Step 1.5" in raw_ok
check(dev_by_path or dev_by_text, "개발 사본이 실렸다",
      f"init.plugins 경로 일치={dev_by_path} · 트랜스크립트에 'Step 1.5'={dev_by_text}")

reads = [b.get("input") or {} for b in blocks(ok_ev, "tool_use") if b.get("name") == "Read"]
check(any(str(r.get("file_path", "")).startswith("/") and str(r.get("file_path", "")).endswith(seed_rel)
          for r in reads),
      "Step 1.5: 픽스처를 절대경로로 Read 했다", f"Read {len(reads)}회")
calls = skill_calls(ok_ev)
check(len(calls) >= 1, "Step 3: Skill conducting-interview 를 호출했다", f"{len(calls)}회")
args = str(calls[0].get("args", "")) if calls else ""
same = args.strip() == fixture.strip()
check(same, "S1 대리: Skill 인자 = 픽스처 전문(frontmatter 포함)",
      "" if same else f"인자 앞 200자: {args[:200]!r}")

t_ok = text(ok_ev)
check("먼저 거치면" not in t_ok, "(a) '/request-framing 을 먼저' 조언이 나오지 않았다")
check("우산" in t_ok, "(b) 첫 라운드 출력이 픽스처의 고유 문장(우산)을 반영한다")
t_miss = text(miss_ev)
check("를 읽지 못했다" in t_miss, "(c) 없는 경로 → 부재 문구를 냈다")
check(not skill_calls(miss_ev), "(c) 없는 경로 → conducting-interview 를 호출하지 않았다")
print(f"FAILS={fails}")
sys.exit(1 if fails else 0)
```

`(b)` 는 모델의 **텍스트 블록**만 본다 — 도구 결과(Read 가 돌려준 파일 내용)는 세지 않는다. 그래서 「우산」이 나왔다면 모델이 풀린 입력을 받아 그 주제로 첫 라운드를 열었다는 뜻이다.

- [ ] **Step 3: 실행**

Run: `bash -n .claude/handoff-baseline/v4/run_v4.sh && python3 -m py_compile .claude/handoff-baseline/v4/judge_v4.py && echo SYNTAX-OK`
Expected: `SYNTAX-OK`.

Run (Bash 도구 timeout 600000): `bash .claude/handoff-baseline/v4/run_v4.sh`
Expected: `ok rc=0` · `missing rc=0` · 판정 줄 전부 `PASS` · `FAILS=0` · `judge rc=0`.

- [ ] **Step 4: 판정 읽기 — 멈출 조건을 먼저 정한다**

- `개발 사본이 실렸다` 가 FAIL 이면 나머지 판정은 무의미하다. 설치 캐시의 1.0.0 이 돌았을 수 있다. 측정 공백으로 보고하고, 설계 결함으로 읽지 않는다.
- `(a)` · `(b)` · `(c)` · `S1 대리` 중 하나라도 FAIL 이면 Step 1.5 의 문면 결함이다. `V4DIR` 의 `ok.jsonl` · `missing.jsonl` 에서 해당 도구 호출과 텍스트를 인용해 원인을 적는다. **문면 수정은 한 번만** 한다. 수정은 Task 1 의 테스트를 먼저 고친 뒤 구현하는 순서로 하고, 커밋 뒤 V4 를 다시 돌린다. 두 번째에도 FAIL 이면 멈추고 사용자에게 증거와 함께 보고한다(설계 재결정 대상일 수 있다).
- 모델의 비결정성 때문에 한 번의 PASS 는 「이 문면으로 한 번 동작했다」까지만 말한다. 보고에도 그렇게 적는다.

- [ ] **Step 5: 결과 기록 (전부 PASS 일 때만)**

`CHANGELOG.md` `[1.1.0]` 의 `### Added` 마지막에 한 줄을 더한다. `<날짜>` 는 V4 를 돌린 날(YYYY-MM-DD)로 채운다:

```markdown
- 실동작 확인(<날짜>, 헤드리스 `claude -p` + `--plugin-dir`, sonnet, 1회): `/spec-distill:interview @<seed>` 가 픽스처를 절대경로로 읽고 frontmatter 포함 전문을 그대로 `conducting-interview` 에 넘겼고, 조언 없이 첫 라운드가 seed 본문으로 시작했다. 없는 경로는 부재 문구를 내고 인터뷰를 시작하지 않았다. 대화형 입력은 재지 않았다.
```

`.claude/handoff-baseline/commit-msg.txt`:

```
docs(spec-distill): 1.1.0 실동작 확인 결과 기록

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EUJwm6ktX8Rvon4NjXVZ6X
```

Run: `git add plugins/spec-distill/CHANGELOG.md && git commit -q -F .claude/handoff-baseline/commit-msg.txt && git status --short`
Expected: 빈 출력.

- [ ] **Step 6: 사람이 할 관측 둘 — 사용자에게 넘긴다**

두 관측은 대화형 터미널이 있어야 하므로 에이전트가 할 수 없다. 아래 절차를 사용자에게 그대로 건네고, 결과를 받으면 PR 본문과 메모리 파일 `reference_command_args_at_path_not_expanded.md` 에 적는다.

**관측 A — `/new` 뒤 작업 디렉토리가 워크트리로 유지되는가.** 권장 옵션 ① 이 흔한 경로에서 성립하는지가 이것에 달렸다. framing 은 세션 도중 `EnterWorktree` 로 cwd 를 옮기기 때문이다.

1. 메인 체크아웃(`/Users/jeonghokim/Downloads/devbrew`)에서 `claude` 를 연다.
2. 「`EnterWorktree` 로 `oq2-probe` 워크트리를 만들어 들어가 줘」라고 요청한다.
3. 전환된 뒤 `/new` 를 친다.
4. `! pwd` 를 친다. `…/.claude/worktrees/oq2-probe` 면 유지된 것이고, `/Users/jeonghokim/Downloads/devbrew` 면 되돌아간 것이다.
5. 정리: `! git worktree remove .claude/worktrees/oq2-probe` 를 친 뒤 `! git branch -D worktree-oq2-probe` 를 친다. 브랜치 이름이 다르면 `! git branch --list 'worktree-oq2*'` 로 먼저 확인한다.

되돌아간다면 ① 은 워크트리를 만든 framing 세션에서 매번 Step 1.5 의 부재 문구로 끝난다. 그 결과는 권장 옵션의 재결정 근거이고, 사용자가 판정한다. 게이트의 워크트리 절대경로 안내가 그때의 복구 경로다.

**관측 B — 대화형 입력에서 커맨드 인자의 `@경로` 가 첨부되는가.**

1. 이 워크트리에서 `claude --plugin-dir .claude/handoff-baseline/probe/plugin` 을 연다.
2. `/argprobe:echoargs @.claude/handoff-baseline/probe/seed.md` 를 친다.
3. 답의 `CONTENT_SEEN=` 줄을 읽는다. `yes` 면 대화형에서는 첨부된다. 그래도 Step 1.5 는 필요하다 — command 본문이 읽는 것은 치환된 인자다. `no` 면 헤드리스와 같다.

---
