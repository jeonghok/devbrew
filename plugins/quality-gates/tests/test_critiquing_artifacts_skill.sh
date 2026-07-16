#!/usr/bin/env bash
# T10 — critiquing-artifacts SKILL orchestration-shape locks (AC2/AC3/AC5/AC10/AC11/AC14).
set -u
S="plugins/quality-gates/skills/critiquing-artifacts/SKILL.md"
PASS=0; FAIL=0
ag() { grep -qE "$1" "$S" && { PASS=$((PASS+1)); echo "  PASS: $2"; } || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2"; }; }
agf() { grep -qF "$1" "$S" && { PASS=$((PASS+1)); echo "  PASS: $2"; } || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2"; }; }
ng() { if [ ! -f "$S" ]; then FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2 (file missing)"; return; fi
       grep -qE "$1" "$S" && { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2 (unexpected '$1')"; } || { PASS=$((PASS+1)); echo "  PASS: $2"; }; }

# frontmatter + narrow Bash allowlist (no wildcard)
ag '^name: critiquing-artifacts$' "skill name"
ng '^\s*-\s*Bash\(\*\)\s*$' "no Bash(*) wildcard (narrow allowlist)"
agf 'classify_artifact_target.py' "wires E1 classifier"
agf 'artifact_branch_guard.sh' "wires E2 branch guard"
agf 'artifact_change_signal.sh' "wires change signal"
agf 'artifact_commit.sh' "wires commit-scope"
agf 'synthesize_artifact_findings.py' "wires synthesizer"
agf 'artifact_stagnation.py' "wires stagnation"
agf 'artifact_max_rounds.sh' "wires max-rounds"
agf 'run_artifact_codex_reviewer.sh' "wires codex wrapper"
agf 'detect_codex.sh' "reuses codex detection"

# E0 both kill switches
agf 'DEVBREW_DISABLE_QUALITY_GATES' "E0 global kill switch"
agf 'DEVBREW_QG_DISABLE_CRITIQUE' "E0 mode kill switch"

# E1 three-branch classify
ag 'code.*(종료|안내|exit)|코드.*종료' "E1 code -> stop"
agf 'ambiguous' "E1 ambiguous branch"
agf 'AskUserQuestion' "E1/E3 gates use AskUserQuestion"

# E2b clean precondition + E3 consent-integrity
ag 'E2b|clean 전제|HEAD.*clean|dirty' "E2b clean precondition"
agf 'effective_max_rounds' "E3 uses effective_max_rounds (consent-integrity)"

# read-only reviewer dispatch (Law 2)
agf 'artifact-critic' "dispatches artifact-critic"
agf 'artifact-adversarial' "dispatches artifact-adversarial"
agf 'project_dir' "threads project_dir to reviewers"

# codex degrade: two DISTINCT lines (unavailable vs runtime-fail).
# NOTE: the loose alternative `가용.*실패` was dropped — the unavailable-arm's
# own parenthetical cross-reference ("...런타임-실패 문구와 구분된 별도 라인")
# contains 가용 (from 미가용) followed by 실패 (from 런타임-실패) on the SAME
# line, so it satisfied this check even with the real runtime-fail line
# deleted (verified: a mutation deleting only the runtime-fail arm stayed
# green under the old pattern). `가용 판정 후.*실패` is unique to the
# runtime-fail arm's own text and doesn't collide with that cross-reference.
ag '미가용|not.*available|codex_available: false' "codex unavailable degrade line"
ag '런타임 실패|runtime.*fail|가용 판정 후.*실패' "codex runtime-fail degrade line (distinct)"

# degraded-adversarial -> NEEDS_RESOLUTION ; un-adjudicated fail-closed loud log
agf 'NEEDS_RESOLUTION' "degraded adversarial -> NEEDS_RESOLUTION"
ag '미판정|un-adjudicated|unadjudicated' "un-adjudicated loud log"

# fan-out <=3 statement
ag 'fan-out.*(3|≤3|<5)|≤3|3.*동시' "fan-out <=3 documented"

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
  PASS=$((PASS+1)); echo "  PASS: change signal captured BEFORE commit (round-2 regression lock)"
else
  FAIL=$((FAIL+1)); echo "  ✗ FAIL: change signal must appear before commit (sig=$sig_ln com=$com_ln)"
fi
# ...and the SKILL states the signal is pre-commit
ag '커밋 전|커밋-전|pre-commit|BEFORE.*commit|before the commit' "SKILL states signal is pre-commit"

# final summary contract
ag '라운드.*히스토리|round.*history|커밋 SHA|commit SHA' "final summary: rounds + commit SHAs"

echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
