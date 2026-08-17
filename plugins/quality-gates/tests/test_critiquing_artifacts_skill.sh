#!/usr/bin/env bash
# T10 — critiquing-artifacts SKILL orchestration-shape locks (AC2/AC3/AC5/AC10/AC11/AC14).
set -u
S="plugins/quality-gates/skills/critiquing-artifacts/SKILL.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# frontmatter + narrow Bash allowlist (no wildcard)
assert_file_grep "$S" '^name: critiquing-artifacts$' "skill name"
assert_file_absent "$S" '^\s*-\s*Bash\(\*\)\s*$' "no Bash(*) wildcard (narrow allowlist)"
assert_contains "$(cat "$S")" 'classify_artifact_target.py' "wires E1 classifier"
assert_contains "$(cat "$S")" 'artifact_branch_guard.sh' "wires E2 branch guard"
assert_contains "$(cat "$S")" 'artifact_change_signal.sh' "wires change signal"
assert_contains "$(cat "$S")" 'artifact_commit.sh' "wires commit-scope"
assert_contains "$(cat "$S")" 'synthesize_artifact_findings.py' "wires synthesizer"
assert_contains "$(cat "$S")" 'artifact_stagnation.py' "wires stagnation"
assert_contains "$(cat "$S")" 'artifact_max_rounds.sh' "wires max-rounds"
assert_contains "$(cat "$S")" 'run_artifact_codex_reviewer.sh' "wires codex wrapper"
assert_contains "$(cat "$S")" 'detect_codex.sh' "reuses codex detection"

# E0 both kill switches (ENFORCEMENT body, not the bottom kill-switch inventory).
# NOTE: the old `agf 'DEVBREW_DISABLE_QUALITY_GATES'` / `agf 'DEVBREW_QG_DISABLE_CRITIQUE'`
# were inventory-satisfiable — both var names ALSO appear in the "kill switch (보안
# 컨트롤)" inventory at the SKILL foot, so gutting the E0 enforcement body stayed
# GREEN (verified by mutation: deleting E0's exit lines while leaving the inventory
# passed). These exact user-facing exit messages appear ONLY in the E0 enforcement
# lines and nowhere in the inventory.
assert_contains "$(cat "$S")" 'critique skipped: quality-gates globally disabled' "E0 global kill switch (enforcement body, not inventory)"
assert_contains "$(cat "$S")" 'critique mode disabled via DEVBREW_QG_DISABLE_CRITIQUE' "E0 mode kill switch (enforcement body, not inventory)"

# E1 three-branch classify
assert_file_grep "$S" 'code.*(종료|안내|exit)|코드.*종료' "E1 code -> stop"
assert_contains "$(cat "$S")" 'ambiguous' "E1 ambiguous branch"
# NOTE: the old pattern `agf 'AskUserQuestion'` was frontmatter-satisfiable —
# the term is necessarily declared in the frontmatter allowed-tools list (plain,
# no backticks), so deleting every actual gate invocation in the body while
# leaving that declaration intact stayed GREEN (verified by mutation).
# `` `AskUserQuestion`(으로|:) `` matches only the backtick-wrapped body
# invocations (E1/E3/degraded gates) and not the bare frontmatter list entry.
assert_file_grep "$S" '`AskUserQuestion`(으로|:)' "E1/E3 gates use AskUserQuestion (body invocation, not frontmatter)"

# E2b clean precondition + E3 consent-integrity
# NOTE: the old pattern `E2b|clean 전제|HEAD.*clean|dirty` was header-satisfiable —
# the section HEADING itself (`### E2b — 대상 clean 전제`) already contains both
# `E2b` and `clean 전제`, so the assertion passed on the heading alone (verified:
# gutting the E2b ENFORCEMENT body — the changed:true reject / changed:false
# proceed lines — while leaving the heading intact stayed GREEN under the old
# pattern). `커밋/stash 후 재실행` is unique to the enforcement body's dirty-reject
# guidance and absent from the heading and frontmatter.
assert_contains "$(cat "$S")" '커밋/stash 후 재실행' "E2b clean precondition (enforcement body, not heading)"
# whole-branch review fix: E2b must reject an UNTRACKED target too (`git diff
# --quiet HEAD` is blind to untracked paths and silently reads changed:false --
# without this, E2b would misread a wholly-uncommitted file as "clean" and
# proceed, silently breaking the round-by-round-commit guarantee). Body-unique
# phrase (not header-satisfiable): the E2b heading only says "HEAD-tracked +
# clean 전제" -- this exact reject-guidance sentence appears solely in the
# tracked:false enforcement line (verified: gutting just that line while
# leaving the heading intact reddens this assertion).
assert_contains "$(cat "$S")" '아직 커밋되지 않은(untracked) 파일입니다' "E2b rejects an untracked target (tracked: false reject line, body-unique)"
# NOTE: the old pattern `agf 'effective_max_rounds'` was header-satisfiable — the
# term also appears in the LOOP section heading (`## 루프 (라운드 N =
# 1..effective_max_rounds)`), so deleting E3's own consent-integrity body while
# leaving that unrelated heading intact stayed GREEN (verified by mutation).
# `consent-integrity` is the design-term unique to E3's body sentence and absent
# from any heading/frontmatter.
assert_contains "$(cat "$S")" 'consent-integrity' "E3 uses effective_max_rounds (consent-integrity, body-unique)"

# read-only reviewer dispatch (Law 2)
assert_contains "$(cat "$S")" 'artifact-critic' "dispatches artifact-critic"
assert_contains "$(cat "$S")" 'artifact-adversarial' "dispatches artifact-adversarial"
# NOTE: the reviewer dispatches thread project_dir via the literal prompt field
# `project_dir: <project_dir>` (critic + adversarial Agent prompts). This is
# body-unique: the E2 heading uses `project_dir 좌표 freeze` and E2c uses
# `<project_dir>` only as a script arg — neither contains the `project_dir:
# <project_dir>` prompt field. (The prior `project_dir.*스레딩` same-line proxy
# broke when the iter-2 canonical rewrite wrapped the prose across two lines; the
# actual threading field is a stronger, wrap-immune anchor.)
assert_contains "$(cat "$S")" 'project_dir: <project_dir>' "threads project_dir to reviewers (prompt field, body-unique)"

# codex degrade: two DISTINCT lines (unavailable vs runtime-fail).
# NOTE: the loose alternative `가용.*실패` was dropped — the unavailable-arm's
# own parenthetical cross-reference ("...런타임-실패 문구와 구분된 별도 라인")
# contains 가용 (from 미가용) followed by 실패 (from 런타임-실패) on the SAME
# line, so it satisfied this check even with the real runtime-fail line
# deleted (verified: a mutation deleting only the runtime-fail arm stayed
# green under the old pattern). `가용 판정 후.*실패` is unique to the
# runtime-fail arm's own text and doesn't collide with that cross-reference.
assert_file_grep "$S" '미가용|not.*available|codex_available: false' "codex unavailable degrade line"
assert_file_grep "$S" '런타임 실패|runtime.*fail|가용 판정 후.*실패' "codex runtime-fail degrade line (distinct)"

# degraded-adversarial -> NEEDS_RESOLUTION ; un-adjudicated fail-closed loud log
# NOTE: the old `agf 'NEEDS_RESOLUTION'` was header-satisfiable — the token also
# appears in the 종료 사유 summary ("NEEDS_RESOLUTION-중단" / "needs_resolution"), so
# gutting the degraded->NEEDS_RESOLUTION handling body stayed GREEN (verified by
# mutation). This exact degraded-gate question phrase is unique to step 4's body.
assert_contains "$(cat "$S")" '이번 라운드 adversarial 판정 실패' "degraded adversarial -> NEEDS_RESOLUTION (enforcement body, not 종료 summary)"
assert_file_grep "$S" '미판정|un-adjudicated|unadjudicated' "un-adjudicated loud log"

# fan-out <=3 statement
assert_file_grep "$S" 'fan-out.*(3|≤3|<5)|≤3|3.*동시' "fan-out <=3 documented"

# ORDERING LOCK (round-2 block bug): change-signal reference BEFORE commit reference.
# Scoped to the BODY (frontmatter excluded) and to the LAST occurrence of each
# script name: both names are also declared in the frontmatter allowed-tools
# list (wiring order, not execution order) and artifact_change_signal.sh is
# additionally invoked once pre-loop at E2b — a naive first-occurrence,
# whole-file grep is satisfied by either of those and never actually checks
# that step 6b precedes step 7 in the round loop (verified: a body swap of the
# 6b/7 blocks left a first-occurrence/whole-file version of this check green).
fm_end="$(awk '/^---$/{n++; if (n==2){print NR; exit}}' "$S" 2>/dev/null)"
body_lines() { tail -n "+$((${fm_end:-0}+1))" "$S" 2>/dev/null; }
sig_ln="$(body_lines | grep -nF 'artifact_change_signal.sh' | tail -1 | cut -d: -f1)"
com_ln="$(body_lines | grep -nF 'artifact_commit.sh' | tail -1 | cut -d: -f1)"
if [ -n "$sig_ln" ] && [ -n "$com_ln" ] && [ "$sig_ln" -lt "$com_ln" ]; then
  ok "change signal captured BEFORE commit (round-2 regression lock)"
else
  no "change signal must appear before commit (sig=$sig_ln com=$com_ln)"
fi
# ...and the SKILL states the signal is pre-commit
assert_file_grep "$S" '커밋 전|커밋-전|pre-commit|BEFORE.*commit|before the commit' "SKILL states signal is pre-commit"

# F-G ORDERING LOCK: path-auth (E2c) must run BEFORE the reviewers read the artifact.
# A tracked symlink escaping project_dir would otherwise be read by critic/codex
# (and its target exfiltrated to codex) before path_auth ran at step 6 — which is
# SKIPPED entirely on a converged round. Assert the FIRST body occurrence of
# artifact_path_auth.py precedes the FIRST artifact-critic dispatch. Body-scoped
# (path_auth is also declared in the frontmatter allowed-tools) + first-occurrence
# (path_auth recurs at the step-6 TOCTOU re-verify). Mutation: moving path-auth back
# to step-6-only (removing E2c) puts its first body occurrence after the critic
# dispatch -> RED.
auth_ln="$(body_lines | grep -nF 'artifact_path_auth.py' | head -1 | cut -d: -f1)"
critic_ln="$(body_lines | grep -nF 'quality-gates:artifact-critic' | head -1 | cut -d: -f1)"
if [ -n "$auth_ln" ] && [ -n "$critic_ln" ] && [ "$auth_ln" -lt "$critic_ln" ]; then
  ok "path-auth (E2c) precedes reviewer reads (F-G symlink-exfil lock)"
else
  no "path-auth must precede critic dispatch (auth=$auth_ln critic=$critic_ln)"
fi

# F-G completion (iter-2 re-review): ALL THREE reviewer dispatches must thread the
# E2c-frozen <canonical>, NEVER raw `artifact_path: <path>`. The adversarial dispatch
# was the drift caught in re-review (critic/codex were threaded, adversarial was not).
# critic + adversarial thread `artifact_path: <canonical>`; codex threads <canonical>
# as run_artifact_codex_reviewer.sh's first arg. (git commit/change-signal keep the
# tracked <path> — those are NOT `artifact_path:` prompt fields, so the raw-path check
# below is specific to reviewer reads.) Mutation proof: reverting any reviewer
# dispatch to `artifact_path: <path>` reddens the raw-path check (and drops the count).
canon_n="$(grep -cF 'artifact_path: <canonical>' "$S")"
[ "$canon_n" -ge 2 ] && ok "critic + adversarial thread artifact_path: <canonical> (F-G, count=$canon_n)" || no "expected >=2 artifact_path: <canonical> (got $canon_n)"
if grep -qF 'artifact_path: <path>' "$S"; then
  no "a reviewer dispatch still threads raw artifact_path: <path> (F-G drift)"
else
  ok "no reviewer dispatch threads raw artifact_path: <path> (F-G)"
fi
assert_contains "$(cat "$S")" 'run_artifact_codex_reviewer.sh <canonical>' "codex wrapper receives <canonical> arg, not raw <path> (F-G)"
# step-6 edit must re-verify the canonical is UNCHANGED vs E2c (swap detection), not
# blindly re-resolve; body-unique phrase from the step-6 mismatch-reject guidance.
assert_contains "$(cat "$S")" 'canonical mismatch' "step-6 rejects on canonical mismatch (TOCTOU swap detection, F-G)"

# final summary contract
assert_file_grep "$S" '라운드.*히스토리|round.*history|커밋 SHA|commit SHA' "final summary: rounds + commit SHAs"

finish
