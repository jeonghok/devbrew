# Quality-Gates v1.5.0 — E2E Verification Scenarios

> **제거된 표면(v11.0.0).** `scout` · depth(quick/standard/deep) · Phase 1/2 · 게이트 번호 · `max_gate2_iterations` 는 없다. 아래 B–F · I 의 scout 서술은 역사 기록이다 — 오늘의 리뷰어 구성은 기본 셋 + 조건부 넷 + `code-recritic` 이고 합성기·Fix-loop 는 `skills/quality-pipeline/SKILL.md` 가 정본이다.
>
> **Historical (v2.2.x snapshot).** Model lines below predate the 2026-09-06 «no `model` key» convention; scenario H's "Task 1 model-override experiment" measured dispatch-time override of `inherit`, which gate agents no longer receive.

This document records the manual verification scenarios for the v1.5.0 redesign.
Live `/qg` runs require an interactive Claude Code session against a real PR;
this file specifies *what to test* and *what passing looks like* so a reviewer
or a future re-verification can reproduce the results.

A static-checks summary is at the bottom.

## Setup (once)

1. Confirm branch is `feature/qg-cost-reduction` merged or rebased on `main`.
2. Confirm `pr-review-toolkit`, `feature-dev`, and `superpowers` plugins are
   installed (`/plugin list`).
3. Confirm tests pass:
   ```bash
   python3 -m unittest discover plugins/quality-gates/tests -v
   ```
   Expected: 23 tests pass.

## Scenarios

### A — Trivia (whitespace)
**Setup**: pick any single source file; add one trailing-whitespace edit.
**Run**: `/qg`
**Expected**: instant PASS, 0 dispatches. State file shows `outcome: trivia-skipped`, `trivia_kind: whitespace`. Pipeline message says "Trivia change (whitespace); review skipped."

### A2 — Trivia (rename)
**Setup**: `git mv old.py new.py` with no other edits.
**Run**: `/qg`
**Expected**: instant PASS, 0 dispatches. `trivia_kind: rename`.

### A3 — NOT trivia (comment-only safety check)
**Setup**: edit one comment line (single file, ≤3 lines, but not whitespace/rename).
**Run**: `/qg`
**Expected**: trivia escape does NOT fire. Pipeline proceeds to Gate 1, then Quick depth in Gate 2. Confirms our intentional decision to leave comment-only outside the trivia path (language fragility).

### B — Quick (small single-file diff)
**Setup**: single Python file, ~30 LOC change, no new files.
**Run**: `/qg`
**Expected** dispatches in order:
- (역사) scout 가 `depth: quick` 을 냈다 — 지금은 오케스트레이터가 리뷰어 구성을 정한다
- pr-review-toolkit:code-reviewer (upstream Opus) — Phase 1
- synthesizer (Sonnet) — Phase 1.6
Total: 3 dispatches. AskUserQuestion does NOT fire (Phase 1+2 = 1 < 4).

### C — Standard (multi-file, mid-size)
**Setup**: ~100 LOC across two files.
**Run**: `/qg`
**Expected** dispatches:
- (역사) scout 가 `depth: standard` 를 냈다
- code-reviewer (Opus, upstream) + silent-failure-hunter (Sonnet override) — Phase 1
- (역사) scout 계획의 Phase 2 agent 0–2개
- adversarial (Opus) — Phase 1.5
- synthesizer (Sonnet) — Phase 1.6
Total: 5–7 dispatches. AskUserQuestion fires only if Phase 1+2 ≥ 4.

### D — Deep (large diff, AskUserQuestion gate)
**Setup**: ≥200 LOC AND new file added AND a config file (`*.json` / `*.toml`) touched.
**Run**: `/qg`
**Expected**:
- (역사) scout 가 `depth: deep` 을 냈다.
- Phase 1+2 = 5 ≥ 4 → **AskUserQuestion fires** with the three options.
- Choose `phase1-only` → Phase 2 skipped; only Phase 1 (3) + adversarial + synth = 5 dispatches.

### E — No cross-gate restart
**Setup**: PR with code that intentionally has a Gate 2 issue requiring file changes (e.g., bug that the reviewer will spot).
**Run**: `/qg`
**Expected**: Gate 2 emits `NEEDS_RESTART` after fix-loop exhaustion → user-choice prompt fires (`gate2_user_choice`). Pipeline does NOT auto-restart from Gate 1. User picks "Apply changes and re-run `/qg`" → pipeline ends with abort signal.

### F — Within-Gate-2 fix loop
**Setup**: PR where Phase 1 finds CRITICAL issues that the skill can fix in-place.
**Run**: `/qg`
**Expected**: fix → re-run review (delta diff: only changed files) → either PASS or another fix iteration. After ≤5 iterations, either PASS or `gate2_max_exceeded` user-choice fires.

### G — `/qg --paths` override
**Setup**: edit files outside `plugins/quality-gates/`.
**Run**: `/qg --paths "plugins/quality-gates/**"`
**Expected**: review sees only the matched paths (the others are excluded from diff). Session-files content is ignored.

### H — Cross-plugin model respect
**Run**: any /qg invocation that dispatches `pr-review-toolkit:code-reviewer`.
**Inspect**: state file dispatch summary should show `model: opus` for that agent (upstream-hardcoded, not overridden), while devbrew agents (no `model` key) show `model: sonnet` (Task 1 model-override experiment confirmed this works).

### I — Repeat detection
**Setup**: contrive a PR where Phase 1 finds the same finding twice (e.g., the auto-fix doesn't actually fix the root cause).
**Run**: `/qg`
**Expected**: after iteration 2 with an identical dispatch + synthesizer result, the SKILL surfaces the Gate 2 iter-boundary decision via AskUserQuestion (Retry / Proceed to Gate 3 / Stop) with a repeat-detected note in the prompt, before reaching the hard cap `max_gate2_iterations=5`.

### J — Branch switch mid-session
**Run**: edit a file on `feature/qg-cost-reduction`, then `git checkout main`, then `/qg`.
**Expected**: scope is git-derived fresh at invocation time (branch diff against base, unioned with the worktree's own changed files), not cached from a prior turn or session file — `/qg` on `main` reviews `main`'s own diff against its base, not the leftover `feature/qg-cost-reduction` diff. No explicit reset step is needed; there is no session-scope file to go stale.


### L — `DEVBREW_QUALITY_GATES_DISABLE=1`
**Run**: set env var, then start a new Claude Code session AND attempt `/qg`.
**Expected**: the `/qg` command's setup fence calls `setup-qg.sh`, which refuses with one line (`setup-qg disabled via DEVBREW_QUALITY_GATES_DISABLE=1`) and exit 1 before writing anything (`tests/test_entry_safety_e1_e6.sh`); `/qg` shows that line and stops — the pipeline skill is not invoked. If the skill is reached anyway, SKILL Preflight P1 returns immediately.

## Static Wiring Checks (automated)

> **제거된 표면 — 역사 기록으로 남긴다.** 오늘의 파이프라인에는 대응 경로가 없다.
> 아래 agent 목록의 `plan-verifier`는 이 스냅샷보다도 먼저 삭제된 죽은 참조다(무관한
> 선재 staleness). `runtime-verifier`는 실재하던 agent였으나 이후 릴리스에서 사라졌다 —
> ②차등 테스트가 그 자리를 대신한다.

Run this from repo root any time:

```bash
python3 -c "
import yaml, json, os
print('Agents (model + cost_class):')
for a in ['scout','adversarial','synthesizer','plan-verifier','runtime-verifier']:  # 역사 목록 — scout 등은 v11 에서 없다
    fm = open(f'plugins/quality-gates/agents/{a}.md').read().split('---')[1]
    d = yaml.safe_load(fm)
    print(f'  {a}: model={d.get(\"model\")}, cost_class={d.get(\"cost_class\")}')
print()
print('SKILL cost_class:', yaml.safe_load(open('plugins/quality-gates/skills/quality-pipeline/SKILL.md').read().split('---')[1])['cost_class'])
print('plugin.json version:', json.load(open('plugins/quality-gates/.claude-plugin/plugin.json'))['version'])
"

python3 -m unittest discover plugins/quality-gates/tests -v 2>&1 | tail -3
```

Expected output (final state):

```
Agents (model + cost_class):
  scout: model=sonnet, cost_class=low
  adversarial: model=opus, cost_class=low
  synthesizer: model=sonnet, cost_class=low
  runtime-verifier: model=(none — user setting/session), cost_class=variable

SKILL cost_class: variable
plugin.json version: 2.2.x

Ran 23 tests in 0.NNNs
OK
```

## v1.6.0 Scenarios (per-session state)

### V1 — Concurrent sessions do not share pipeline state

**Setup**: Two terminal sessions A and B in the same project (same worktree). Both have valid `CLAUDE_CODE_SESSION_ID` env vars (`$SID_A`, `$SID_B`).
1. In A: run `/qg`. Verify `.claude/quality-gates/$SID_A/result.md` is created.
2. In B: run `/qg`. Verify `.claude/quality-gates/$SID_B/result.md` is created, independent of A's.
3. Review scope itself is git-derived (branch diff against base, unioned with the worktree's own changed files) — since A and B share the same worktree, both sessions resolve the SAME scope from git; there is no per-session file tracker to isolate.

**Pass**: `$SID_A` and `$SID_B` each have their own `result.md`; neither session's result file is touched by the other's run.

### V2 — Dormant session GC

**Setup**: Backdate a sibling session's files mtime by 25 hours.
```bash
old=$(($(date +%s) - 25 * 3600))
touch -t "$(date -r $old +%Y%m%d%H%M)" .claude/quality-gates/oldsess0001/pipeline.md
touch -t "$(date -r $old +%Y%m%d%H%M)" .claude/quality-gates/oldsess0001
```
1. Run `/qg` (any flavor). Verify `.claude/quality-gates/oldsess0001/` no longer exists.
2. Set `DEVBREW_QUALITY_GATES_GC_VERBOSE=1` and observe stdout: `[quality-gates] GC: removed 1 stale session folder(s)`.



### V5 — GC lock contention silent

1. Hold the lock from a shell — 락은 state root 디렉토리 자신이다(락 파일 없음):
```bash
python3 -c 'import fcntl, os, time
fd = os.open(".claude/quality-gates", os.O_RDONLY | os.O_DIRECTORY)
fcntl.flock(fd, fcntl.LOCK_EX); print("holding"); time.sleep(600)'
# (keep shell open with lock held)
```
2. In another terminal, run `/qg`. The GC step inside setup should silently skip (no error).
3. Stale folders preserved.

### V6 — Kill switch globally disables

```bash
DEVBREW_QUALITY_GATES_DISABLE=1 /qg
```
1. Verify no `.claude/quality-gates/` folder created.
2. Verify `qg-gc.py` exits 0 without action.

### T-1 — 토픽 스코프: 형제 브랜치 둘 + 미커밋 변경

**Setup:** 일회용 리포에 형제 브랜치 둘(`Spec: docs/x.md#p1`), 현재 브랜치에 미커밋 파일.

**Run:** `/qg`

**Expected:**
- `Review scope: topic …` 한 줄.
- 판정 꼬리의 `scope:` 블록에 `mode: topic` · 두 선언 커밋의 `commit:` 줄.
- 형제 브랜치에 회귀를 심으면 `defect`.
- 형제가 같은 파일을 달리 고치면 `not-certified (merge-conflict)` 와 그 파일.

## Out-of-Scope for This Verification

- Live cost telemetry (recording actual $ per run for each depth tier) —
  needs a real billing endpoint; deferred to first-week-after-merge metrics.
- A/B comparison vs v1.4.0 baseline — needs the same PR run on both versions;
  recommended for the first 5 PRs after merge.
- Automated E2E test harness — would require a Claude Code subprocess invocation
  pattern that the current toolchain does not standardize. Manual verification
  via the scenarios above is the contract.

