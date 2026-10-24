#!/usr/bin/env bash
# T10 — artifact-critique SKILL orchestration-shape locks (AC2/AC3/AC5/AC10/AC11/AC14).
set -u
S="plugins/quality-gates/skills/artifact-critique/SKILL.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# frontmatter + narrow Bash allowlist (no wildcard)
assert_file_grep "$S" '^name: artifact-critique$' "skill name"
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

# E0 both kill switches (ENFORCEMENT body, not the kill-switch inventory section).
# NOTE: the old `agf 'DEVBREW_QUALITY_GATES_DISABLE'` / `agf 'DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE'`
# were inventory-satisfiable — both var names ALSO appear in the "kill switch (보안
# 컨트롤)" inventory section, so gutting the E0 enforcement body stayed
# GREEN (verified by mutation: deleting E0's exit lines while leaving the inventory
# passed). These exact user-facing exit messages appear ONLY in the E0 enforcement
# lines and nowhere in the inventory.
# R2a 계획 3 Task 12(미룸): 옛 모드 이름(`critique skipped` · `critique mode disabled`)을 skill 이름과
# 쉬운 말로 바꿨다. 두 단언이 지키던 것(E0 집행 줄이 목록 절과 별개로 있다)은 새 문구로 그대로 잰다.
assert_contains "$(cat "$S")" 'artifact-critique 를 건너뛰었다 — quality-gates 전체가 꺼져 있다(DEVBREW_QUALITY_GATES_DISABLE=1)' "E0 global kill switch (enforcement body, not inventory)"
assert_contains "$(cat "$S")" 'artifact-critique 를 건너뛰었다 — DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1 이 켜져 있다' "E0 mode kill switch (enforcement body, not inventory)"

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
# 1..effective_max_rounds)`), so deleting E3's own disclosure-integrity body while
# leaving that unrelated heading intact stayed GREEN (verified by mutation).
# `disclosure-integrity` is the design-term unique to E3's body sentence and absent
# from any heading/frontmatter.
# E3 는 범위 고르기 · 규모 공시다 — 지출 승인을 묻지 않는다. 판정은 E3 절 본문에서만 한다.
E3="$(awk '/^### E3 — /{f=1} f&&/^## /{exit} f' "$S")"
assert_contains "$E3" '### E3 — 범위 고르기 · 규모 공시' "E3 머리가 범위 고르기 · 규모 공시다"
assert_contains "$E3" 'disclosure-integrity' "E3 uses effective_max_rounds (disclosure-integrity, E3 본문 고유)"
assert_contains "$E3" '이 질문은 범위를 고르는 질문이다 — 라운드마다 띄울 수와 상한은 본문에 공시한다.' "E3 끝 문단: 범위 질문 + 본문 공시"
assert_contains "$E3" '지출 승인을 묻지 않는다' "E3 지출 승인을 묻지 않는다"
assert_contains "$E3" '**실행**' "E3 선택지 실행"
assert_contains "$E3" '**대상 변경**' "E3 선택지 대상 변경"
assert_contains "$E3" '**취소**' "E3 선택지 취소"
assert_contains "$E3" '「1명 (권장)」' "E3 비평자 수 선택지"
assert_contains "$E3" 'effective_max_rounds' "E3 effective_max_rounds"
assert_not_contains "$E3" 'consent-integrity' "E3 에 consent-integrity 없다"
assert_not_contains "$E3" '지출-전 명시 승인' "E3 에 지출-전 명시 승인 없다"
assert_not_contains "$E3" '동의 범위 = 실행 범위' "E3 에 동의 범위 = 실행 범위 없다"
assert_not_contains "$(cat "$S")" 'Upfront 동의 게이트' "SKILL 에 Upfront 동의 게이트 없다"
README="plugins/quality-gates/README.md"
assert_file_grep "$README" 'Law 1=E3 범위 고르기 · 규모 공시' "qg README: Law 1=E3 범위 고르기 · 규모 공시"
assert_file_absent "$README" 'Law 1=E3 upfront 동의 게이트' "qg README 에 옛 E3 이름 없다"

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
# NOTE 2 (Task 15 fix round 1, I3): the plain `미가용` alternative was ALSO
# header-satisfiable once the detector-not-runnable bullet was added below the
# real unavailable-banner line — that bullet says `"codex 미가용"이 **아니다**`,
# which contains the bare token `미가용` without the paren, so it alone kept
# this assertion GREEN when the real banner line (`:154`) was deleted (verified
# by mutation, see report). Anchored to `미가용\(` — body-unique to the real
# banner's own `codex 미가용(<skip_reason>)` text; the detector-not-runnable
# bullet never writes that literal open-paren form.
assert_file_grep "$S" '미가용\(|not.*available' "codex unavailable degrade line"
assert_file_grep "$S" '런타임 실패|runtime.*fail|가용 판정 후.*실패' "codex runtime-fail degrade line (distinct)"

# degraded-adversarial -> NEEDS_RESOLUTION ; un-adjudicated fail-closed loud log
# NOTE: the old `agf 'NEEDS_RESOLUTION'` was header-satisfiable — the token also
# appears in the 종료 사유 summary ("NEEDS_RESOLUTION-중단" / "needs_resolution"), so
# gutting the degraded->NEEDS_RESOLUTION handling body stayed GREEN (verified by
# mutation). This exact degraded-gate question phrase is unique to step 4's body.
assert_contains "$(cat "$S")" '이번 라운드 adversarial 판정 실패' "degraded adversarial -> NEEDS_RESOLUTION (enforcement body, not 종료 summary)"
assert_file_grep "$S" '미판정|un-adjudicated|unadjudicated' "un-adjudicated loud log"

# fan-out statement — R2a 계획 3 Task 12(AC29): 비평자 수가 고정 1 에서 「기본 1 · 사용자가 E3 에서 정함」으로
# 바뀌어 고정 상한 ≤3 은 기본값이 됐다. 옛 단언(`fan-out.*(3|≤3|<5)|≤3|3.*동시`)은 「3」 한 글자로도 맞는
# 느슨한 꼴이었다 — 기본값 문장 그 자체를 잰다(본문에만 있다).
assert_contains "$(cat "$S")" '라운드당 디스패치는 기본 3(비평자 1 · codex 가용 시 1 · 반박자 1)이다' "fan-out 기본 3 documented"

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
# critic + adversarial thread `artifact_path: <artifact_path>${CANONICAL_PATH}</artifact_path>`
# (L3 adjudication-topology Task 14 wrapped the E2c `canonical` value in the
# `<tag>${VAR}</tag>` slot-declaration convention — the var name CANONICAL_PATH still
# names the E2c-frozen canonical, not a different value; the literal below is the exact
# tagged form, at least as specific as the old bare `<canonical>` placeholder it
# replaces since it also pins the tag name and the `${VAR}` wrapper). codex threads
# <canonical> as run_artifact_codex_reviewer.sh's first arg (untouched by that
# retagging — that call site is a bash script arg, not an Agent() prompt field). (git
# commit/change-signal keep the tracked <path> — those are NOT `artifact_path:` prompt
# fields, so the raw-path check below is specific to reviewer reads.) Mutation proof:
# reverting any reviewer dispatch to `artifact_path: <path>` reddens the raw-path check
# (and drops the count).
canon_n="$(grep -cF 'artifact_path: <artifact_path>${CANONICAL_PATH}</artifact_path>' "$S")"
[ "$canon_n" -ge 2 ] && ok "critic + adversarial thread artifact_path: <artifact_path>\${CANONICAL_PATH}</artifact_path> (F-G, count=$canon_n)" || no "expected >=2 artifact_path: <artifact_path>\${CANONICAL_PATH}</artifact_path> (got $canon_n)"
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

# AC2(쉬운 말 출력 설계 §2) — 규칙 블록을 넣은 뒤에도 kill switch 목록 절이 압축 뒤 다시 붙는 앞 5,000토큰 안에서 시작한다.
# 근사는 보수(cons) 쪽으로 잰다 — tools/plain-language/token_boundary.py 의 같은 함수다.
ks_lines="$(grep -n '^## kill switch$' "$S" | cut -d: -f1)"
gate_line="$(grep -n '^## 진입 게이트' "$S" | head -1 | cut -d: -f1)"
assert_eq "$(printf '%s\n' "$ks_lines" | grep -c .)" "1" "AC2: kill switch 목록 절은 하나다"
bound="$(PYTHONDONTWRITEBYTECODE=1 python3 -c 'import io,sys; sys.path.insert(0,"tools/plain-language"); import token_boundary as tb; L=io.open(sys.argv[1],encoding="utf-8").read().split("\n"); b=tb.boundary(L,"cons",True); print(len(L)+1 if b is None else b+1)' "$S")"
if [ -n "$ks_lines" ] && [ -n "$gate_line" ] && [ "$ks_lines" -lt "$gate_line" ]; then
  ok "AC2: kill switch 목록 절이 진입 게이트보다 앞이다"
else
  no "AC2: kill switch 목록 절(L${ks_lines:-?})이 진입 게이트(L${gate_line:-?})보다 앞이 아니다"
fi
if [ -n "$ks_lines" ] && [ -n "$bound" ] && [ "$ks_lines" -lt "$bound" ]; then
  ok "AC2: kill switch 목록 절이 앞 5,000토큰 안에서 시작한다(경계 L${bound})"
else
  no "AC2: kill switch 목록 절(L${ks_lines:-?})이 앞 5,000토큰 경계(L${bound:-?}) 밖이다"
fi
assert_contains "$(sed -n "${ks_lines:-1},\$p" "$S" | sed -n '1,/^## [^k]/p')" 'DEVBREW_QUALITY_GATES_DISABLE_CODEX=1' "AC2(양의 짝): 옮긴 절에 codex 스위치 줄이 그대로 있다"

# AC29(R2a 계획 3 Task 12) — 여러 대상 · 「지적만 받기」 읽기 전용 모드 · 상한에서 사용자가 엶 · 비평자 수.
# 모든 문구는 본문에만 있다(제목 · frontmatter 는 영어거나 이 문구를 담지 않는다).
assert_file_grep "$S" '지적만 받기' "읽기 전용 모드(AC29)"
assert_file_grep "$S" '편집 · 커밋을 하지 않는다' "지적만 받기는 커밋하지 않는다"
assert_file_grep "$S" '대상이 여럿' "여러 대상"
assert_file_grep "$S" '비평자 <k>명\(기본 1명\)' "라운드마다 기본값과 쓴 수를 공시"
assert_file_grep "$S" '라운드마다 비평자를 몇 명' "사용자가 그 자리에서 비평자 수를 정한다"
assert_file_grep "$S" '한 번 더 돌기' "라운드 상한에서 사용자가 연다"
assert_file_absent "$S" 'critique skipped|critique mode disabled' "옛 모드 이름이 kill switch 메시지에 없다(미룸)"
# 위 단언들은 낱말 하나라 다른 문장이 대신 채울 수 있다 — 장치마다 그 자리의 문장을 함께 잰다.
assert_contains "$(cat "$S")" '인자에 `--findings-only` 가 있거나' "E1: --findings-only 인자가 모드를 정한다"
assert_contains "$(cat "$S")" '「지적만 받기」는 E2 의 `project_dir:` 만 쓰고 `branch_ok` · E2b 를 요구하지 않는다(커밋하지 않는다) — 곧장 E2c 로 간다.' "지적만 받기는 브랜치 · clean 전제 대신 경로 인가(E2c)로 간다(결정 13)"
# 수정 1(Important 1) — 지적만 받기 · 대상 여럿이 연 보안 불변식을 문장째 잰다.
# 지적만 받기로 가는 문장은 모두 E2c(경로 인가)로 간다 — E3 등 다른 단계로 가면 인가 없이 바깥 파일이 codex 에 간다.
# 단위는 줄이 아니라 문단(빈 줄로 나뉨)이다 — 「지적만 받기」와 「… 로 간다」가 줄바꿈으로 갈라져도 잡힌다.
fo_routes="$(PYTHONDONTWRITEBYTECODE=1 python3 -I -c '
import io, re, sys
paras = io.open(sys.argv[1], encoding="utf-8").read().split("\n\n")
hits = [m for p in paras if "지적만 받기" in p for m in re.findall(r"E[0-9][a-z]? 로 간다", p.replace("\n", " "))]
print(len(hits), " ".join(sorted(set(hits))))
' "$S")"
assert_eq "${fo_routes#* }" "E2c 로 간다" "지적만 받기 문단의 「… 로 간다」는 모두 E2c 다(음성)"
[ "${fo_routes%% *}" -ge 3 ] 2>/dev/null && ok "지적만 받기 문단의 길 안내가 셋 이상 잡힌다(창이 비지 않았다, n=${fo_routes%% *})" \
  || no "지적만 받기 문단의 길 안내 수가 셋 미만(${fo_routes%% *})"
assert_contains "$(cat "$S")" '지적만 받는다. 모드를 바꾸고 E2c 로 간다) /' "멈출 때의 선택: 지적만 받기로 진행은 E2c 로 간다(양성 짝)"
assert_contains "$(cat "$S")" '「고치며 돌기」에서 `branch_ok: false`면 아래 안내 줄을 내고 멈춘다' "고치며 돌기는 branch_ok: false 에서 멈춘다"
assert_contains "$(cat "$S")" '「고치며 돌기」에서만, 대상마다:' "E2b 는 고치며 돌기에서 대상마다 돈다"
assert_contains "$(cat "$S")" '리뷰어 read가 인가보다 앞서는 순서 버그). 두 모드 모두, 대상마다:' "E2c 경로 인가는 두 모드 모두 대상마다 돈다"
assert_contains "$(cat "$S")" '고르면 E2 의 `branch_ok` 검사와 E2b 를 다시 돈다 — `project_dir` 는 E2 에서 얼린 값 그대로' "고치며 돌기로 바꾸면 브랜치 · clean 검사를 다시 돈다(project_dir 는 그대로)"
assert_contains "$(cat "$S")" '`auth: reject` → **종료**' "E2c 거부는 실행을 끝낸다"
# Minor — 여러 대상: 질문 하나 · 실행 전체 전환 · 그 대상만 빼기 · canonical 로 중복 합치기.
assert_contains "$(cat "$S")" '멈춘 대상이 여럿이어도 질문은 하나이고' "멈춘 대상이 여럿이어도 질문은 하나"
assert_contains "$(cat "$S")" '**지적만 받기로 진행**(실행 전체를 「지적만 받기」로 바꾼다' "지적만 받기로 진행은 실행 전체를 바꾼다고 말한다"
assert_contains "$(cat "$S")" '**그 대상만 빼고 진행**' "그 대상만 빼고 진행 선택지"
assert_contains "$(cat "$S")" '와 같은 파일이라(<canonical>) 한 번만 비평한다' "같은 canonical 대상은 한 번만 비평하고 알린다"
assert_contains "$(cat "$S")" '대상 파일의 내용이 codex(바깥' "E3 이 codex 에 파일 내용이 넘어간다고 알린다"
assert_contains "$(cat "$S")" '부르는 수는 비평자 수 + 2(반박자 1 · codex 1), codex 를 못 쓰면 + 1' "비평자 수 질문이 라운드당 부르는 총수를 알린다"
# 수정 1(Important 2) — 지적만 받기 보고가 판정 못 한 지적을 숨기지 않는다.
assert_contains "$(cat "$S")" '「지적만 받기」: `> [quality-gates] 반박자가 판정 못 한 지적 <N>건' "미판정 loud log 가 지적만 받기에서는 편집 제외라고 말하지 않는다"
assert_contains "$(cat "$S")" '「고치며 돌기」: `> [quality-gates] adversarial 미판정 <N>건 — 이번 라운드 편집 제외(fail-closed).`' "고치며 돌기의 미판정 loud log(양성 짝)"
assert_contains "$(cat "$S")" '그 아래 `unadjudicated_items` 를 하나씩' "4b 가 판정 못 한 지적을 하나씩 보인다"
assert_contains "$(cat "$S")" '첫 줄을 「남은 지적 없음」 ·' "판정 못 한 지적이 있으면 첫 줄이 깨끗하게 읽히지 않는다"
assert_contains "$(cat "$S")" '- **판정 못 한 지적**(`unadjudicated > 0` 일 때, 모드 무관)' "종료 요약에 판정 못 한 지적 항목"
lab_n="$(grep -c '「판정 못 함」' "$S")"
[ "$lab_n" -ge 2 ] && ok "「판정 못 함」 라벨이 4b 와 요약 양쪽에 있다(count=$lab_n)" || no "「판정 못 함」 라벨 수 $lab_n < 2"
assert_contains "$(cat "$S")" '**지적만 받기로 진행**' "고치며 돌기가 E2 · E2b 에서 멈추면 지적만 받기로 넘어가는 선택지"
assert_contains "$(cat "$S")" '**지적만 받기로 바꾸기**' "E3 에서 모드를 바꾸는 선택지"
assert_contains "$(cat "$S")" '「1명 (권장)」 · 「2명」 · 「3명」' "E3 비평자 수 선택지(기본 1명 권장)"
assert_contains "$(cat "$S")" '대상이 여럿이면 대상마다 이 루프를 차례로 돈다' "대상마다 라운드 · 커밋 · 상한"
assert_contains "$(cat "$S")" '--findings critic-1.yaml … --findings critic-k.yaml [--findings codex.yaml]' "2.5 가 비평자 k 명의 지적을 모두 합친다"
assert_contains "$(cat "$S")" '`critic-<i>.yaml`' "1: 비평자마다 자기 파일"
assert_contains "$(cat "$S")" '5~9 와 편집 · 커밋을 하지 않는다(종료 사유 `findings_only`)' "지적만 받기는 4 뒤에 보고하고 끝낸다"
assert_contains "$(cat "$S")" '`추가 라운드 승인: <label | typed> · <원문>`' "상한에서 연 승인의 기록 줄(출처 label | typed — B11 꼴)"
assert_contains "$(cat "$S")" 'converged / max_rounds(N) / stagnant(reason) / findings_only /' "종료 사유 목록에 findings_only"
# 순서 락 — 공시 줄은 비평자 dispatch 앞(크게 쓰기 전에 규모를 알린다), 지적만 받기의 멈춤은 4(synth) 뒤 · 5 앞.
ann_ln="$(body_lines | grep -nF '비평자 <k>명(기본 1명)' | head -1 | cut -d: -f1)"
cdisp_ln="$(body_lines | grep -nF 'subagent_type: "quality-gates:artifact-critic"' | head -1 | cut -d: -f1)"
if [ -n "$ann_ln" ] && [ -n "$cdisp_ln" ] && [ "$ann_ln" -lt "$cdisp_ln" ]; then
  ok "라운드 공시 줄이 비평자 dispatch 보다 앞이다"
else
  no "라운드 공시 줄(L${ann_ln:-?})이 비평자 dispatch(L${cdisp_ln:-?})보다 앞이 아니다"
fi
synth_ln="$(body_lines | grep -nF -- '--phase synth' | head -1 | cut -d: -f1)"
fo_ln="$(body_lines | grep -nF '5~9 와 편집 · 커밋을 하지 않는다' | head -1 | cut -d: -f1)"
conv_ln="$(body_lines | grep -nF '**5. 수렴 체크**' | head -1 | cut -d: -f1)"
if [ -n "$synth_ln" ] && [ -n "$fo_ln" ] && [ -n "$conv_ln" ] && [ "$synth_ln" -lt "$fo_ln" ] && [ "$fo_ln" -lt "$conv_ln" ]; then
  ok "지적만 받기의 멈춤이 4(synth) 뒤 · 5(수렴) 앞이다"
else
  no "지적만 받기 멈춤 위치(synth=L${synth_ln:-?} fo=L${fo_ln:-?} conv=L${conv_ln:-?})"
fi
# 상한 게이트는 9(다음 라운드) 자리에 있다 — 한 번 더 돌기가 루프 밖(종료 요약 등)에만 있으면 RED.
nine_ln="$(body_lines | grep -nF '**9. ' | head -1 | cut -d: -f1)"
more_ln="$(body_lines | grep -nF '**한 번 더 돌기**' | head -1 | cut -d: -f1)"
end_ln="$(body_lines | grep -nF '## 종료 & 최종 요약' | head -1 | cut -d: -f1)"
if [ -n "$nine_ln" ] && [ -n "$more_ln" ] && [ -n "$end_ln" ] && [ "$nine_ln" -lt "$more_ln" ] && [ "$more_ln" -lt "$end_ln" ]; then
  ok "상한 게이트(한 번 더 돌기)가 9 와 종료 요약 사이에 있다"
else
  no "상한 게이트 위치(9=L${nine_ln:-?} more=L${more_ln:-?} end=L${end_ln:-?})"
fi

finish
