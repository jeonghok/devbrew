# quality-gates v2.10.0 — Publish Continuation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/qg` 파이프라인이 비중단 완료되면 사람에게 "PR 이해글을 이어서 생성·게시할까?"를 한 번 opt-in offer하고, "예"면 기존 `publishing-pr-understanding` skill을 command-layer 체이닝으로 이어 실행한다. 부수적으로 `pr-understanding-builder`가 PR 이해글을 한국어-primary로 저술하도록 명시한다.

**Architecture:** 두 계층 분업. **파이프라인 SKILL**은 tool-set 무변경 — 비중단 완료 시에만 fail-safe sentinel(`publish-eligible.md`)을 `Write`할 뿐이고, `Skill`/gh는 얻지 않는다. **커맨드 `/qg.md`**(이미 `Skill`을 갖고 `Skill(quality-pipeline)`을 호출하는 검증된 command→skill 계층)가 파이프라인 종료 후 그 sentinel + kill-switch를 보고 offer→체이닝을 소유한다. sentinel의 stale-delete는 `setup-qg.sh`(SKILL이 Preflight P2에서 이미 호출)가 담당 — SKILL은 `Write`만 있고 `rm`이 없기 때문. G3(한국어 law)는 offer 파일들과 의존성이 전혀 겹치지 않는 독립 변경.

**Tech Stack:** Markdown SKILL/command 프롬프트 (LLM 지시), bash 스크립트(`setup-qg.sh`), bash grep-기반 doc-lock 회귀 테스트. 실행 러너 없음 — SKILL/command는 프롬프트라 정적 section-scoped grep(teeth 증명)으로, `setup-qg.sh`만 진짜 behavioral 테스트로 검증.

## Global Constraints

이 절의 값은 spec에서 verbatim 복사한 프로젝트-전역 요구. 모든 task의 요구에 암묵 포함된다.

- **base:** `main` @ `6dab58e`; 작업 브랜치 `feature/qg-publish-continuation` (spec commit `a68444a` 위).
- **버전 bump (C6):** quality-gates를 건드리는 이 PR은 같은 PR에서 `plugin.json` `version` `2.9.0` → `2.10.0` (minor = 새 표면) + `CHANGELOG.md` `## [2.10.0] — 2026-07-07` 항목이 있어야 한다. cache key가 안 그러면 silent stale.
- **NG6 (불변식, load-bearing):** `skills/quality-pipeline/SKILL.md`의 `allowed-tools`에 `Skill`을 **추가하지 않는다.** skill→skill 중첩은 이 리포에 전례 0. 체이닝은 command→skill로만.
- **C2 (publish skill 무변경):** `skills/publishing-pr-understanding/SKILL.md`의 Preflight~Report 로직은 한 줄도 바뀌지 않는다(NG5 문구 동기화 한 줄만 예외). secret-scan은 여전히 `scan_ok: yes` 리터럴로만 판정 + FAIL-CLOSED. offer는 GitHub write를 pre-consent하지 않는다(NG1/AC8).
- **C3/NG3 (스키마 불변):** `pr-understanding-builder` 출력 스키마 블록(마커·헤더·placeholder 순서)은 불변. G3는 페르소나 **prose** style law만 추가 — 고정 영문 섹션 헤더 유지.
- **sentinel 계약 (모든 task 공유 — 여기서 한 번 정의, 재정의 금지):**
  - **경로:** `.claude/quality-gates/<sid>/publish-eligible.md`, `<sid>` = `$CLAUDE_CODE_SESSION_ID` (파이프라인 state file과 동일 sid; git-ignored, plugin namespace).
  - **내용 (정확히 2줄):**
    ```
    <!-- qg-publish-eligible:v1 -->
    verdict: <disposition-token>
    ```
    - 1번째 줄 = 고정 검증 마커 `<!-- qg-publish-eligible:v1 -->`. 커맨드는 이 마커로 sentinel 유효성을 확인한다.
    - `<disposition-token>` = 파이프라인이 방금 렌더한 terminal 게이트 verdict 토큰(예: `clean`, `proceeded-with-findings iter 2`, `failed`, `SKIP_WITH_EVIDENCE`, `no scope reviewed …`). 사람이 읽는 offer 문구에 verbatim 삽입된다.
  - **기록 조건:** 파이프라인이 **비중단(non-aborted) 완료**에 도달했을 때만 파이프라인이 `Write`한다. abort/trivia/kill-switch-return은 기록 지점에 도달하지 못한다 → sentinel 부재 → offer 미발동(default=no-offer, fail-safe).
  - **Write는 idempotent** — 같은 경로 overwrite. 한 실행이 두 기록 지점(Final Summary + R6)에 모두 도달하면 동일 sentinel을 다시 쓸 뿐 무해.
- **테스트 러너:** bash 테스트는 repo root에서 `bash plugins/quality-gates/tests/<name>.sh`. python은 `-m unittest`. qg는 CI 없음 + main에 일부 pre-existing red 가능 — 작업 전 baseline 캡처(`project_qg_pre_existing_test_reds` 메모리 참조).
- **grep-teeth 규율 ([[grep_lock_header_satisfiable]]):** 모든 정적 doc-lock 회귀 assert는 (a) 헤더가 아닌 **body-unique 문구**를, (b) 해당 섹션 윈도우 안에서 grep하고, (c) 그 블록만 삭제한 mutation으로 teeth를 증명한다. 헤더에도 있는 문구를 assert하면 body 삭제해도 GREEN = teeth 없음.

---

## Task 개요 & 의존성

| Task | 산출물 | 의존 |
|---|---|---|
| **0** | Feasibility 게이트: 커맨드 post-Skill 재진입 검증 (코드 없음, build-time 결정) | — (**먼저**) |
| **1** | `setup-qg.sh` stale-sentinel delete (진짜 behavioral TDD) | Task 0 통과 |
| **2** | 파이프라인 SKILL: sentinel Write 2지점 + description 정제 + `Skill`-부재 락 (정적 teeth) | Task 0, 1 |
| **3** | `/qg.md` post-pipeline offer + `allowed-tools` AskUserQuestion (정적 teeth) | Task 0, 2 |
| **4** | `pr-understanding-builder` 한국어-primary law (**독립** — Task 0 결과 무관) | — |
| **5** | README/publish NG5 정합 + version bump + CHANGELOG + doc-lock 테스트 | Task 2, 3, 4 |

**Task 0가 FAIL하면** (하니스가 파이프라인 스킬 종료 후 커맨드 본문에 재진입하지 않음): Task 2·3을 **아키텍처 fork**한다 — offer를 파이프라인 SKILL 종결 단계로 옮기고 "예" 시 `/qg-publish` **안내만**(§5-B floor)으로 강등. 어느 쪽이든 skill→skill 중첩은 쓰지 않는다. Task 0의 STOP 지침을 따를 것. Task 1·4·5는 fork와 무관하게 그대로.

---

## Task 0: Feasibility 게이트 — 커맨드 post-Skill 재진입 (build-time 결정, 코드 없음)

이 task는 **구현이 아니라 검증**이다. spec Handoff Context의 Plan Task 0. §5-B의 런타임 floor(관측 가능한 Skill 에러)와는 **다른 실패모드** — 여기서 검증하는 건 "하니스가 파이프라인 스킬 턴 종료 후 커맨드 본문의 다음 지시를 계속 실행하는가"이며, 이건 런타임 catch로 구제 불가한 build-time 아키텍처 리스크다.

**Files:**
- Read-only 조사: `plugins/quality-gates/commands/qg.md` (이미 멀티스텝: ① `setup-qg.sh` Bash → ② `Skill(quality-pipeline)`), `plugins/quality-gates/skills/quality-pipeline/SKILL.md`.

**Interfaces:**
- Produces: `feasible: yes|no` 판정 + (yes면) Task 2·3가 쓸 "커맨드는 `Skill(quality-pipeline)` 반환 후 다음 지시를 실행한다"는 확정 근거. (no면) fork 지침 발동.

- [ ] **Step 1: 근거 수집 — 기존 멀티스텝 패턴 확인**

`commands/qg.md`는 이미 두 개의 순차 tool 호출을 한 커맨드 본문에서 수행한다: `## Instructions`의 setup-qg.sh Bash 블록(line 45-47) **다음에** `Skill("quality-gates:quality-pipeline")` 호출(line 49). 즉 "커맨드가 tool 호출 뒤 다음 지시를 계속 실행"은 이 커맨드에서 **이미 검증된 동작**이다. 이 task가 추가하려는 건 ③ post-skill 단계(sentinel 읽기 + offer + 두 번째 `Skill`)로의 **확장**일 뿐, 새로운 하니스 능력이 아니다.

- [ ] **Step 2: 재진입 신뢰성 판정**

다음 질문에 답한다 (SKILL/command 프롬프트 구조 + 하니스 동작 근거로):
1. `Skill("quality-gates:quality-pipeline")`는 tool 호출인가, 아니면 턴을 종료시키는 sub-agent 경계인가? (quality-pipeline은 "single assistant turn" orchestrator — Stop hook·continuation sentinel 없음. SKILL.md line 44-48, 727-728 확인.) → 파이프라인이 **같은 턴** 안에서 완료되면, 커맨드 본문의 이후 지시는 같은 턴에서 계속 실행 가능.
2. 파이프라인이 AskUserQuestion decision point에서 **사용자 Stop**을 받아 조기 종료하면? → 그 경우 sentinel 미기록(Global Constraints) → post-step이 실행돼도 offer 미발동(fail-safe). 재진입이 일어나든 안 일어나든 안전.
3. `/qg runtime`이 Final Summary를 렌더하는가? (SKILL.md line 160-167: "bypasses the Dispatch Loop"). → Task 2가 R6에도 sentinel Write를 두는 이유. 이 Step에서 확정: **불확실하면 R6 Write를 유지**(idempotent라 무해).

- [ ] **Step 3: 결정 기록 + 분기**

- **feasible = yes** (기존 setup-qg→Skill 순차 실행이 재진입을 입증):
  - Task 1로 진행. 판정 근거 한 줄을 이 task의 완료 노트에 남긴다: `Task 0: feasible=yes — qg.md already runs setup-qg.sh Bash then Skill(quality-pipeline) sequentially in one command body; post-skill step is the same pattern extended.`
- **feasible = no** (하니스가 파이프라인 스킬 뒤 커맨드 재진입을 신뢰성 있게 하지 않는 증거 발견):
  - **STOP. 구현하지 말 것.** 사용자에게 fork를 보고: "커맨드 재진입 미보장 확인 → §5-B floor 아키텍처(offer를 파이프라인 SKILL 종결 단계로 이전 + '예' 시 `/qg-publish` 안내만)로 Task 2·3 재설계 필요. 이는 spec Handoff Context가 예견한 대안. writing-plans 재진입 또는 사용자 승인 요청."
  - fork 설계는 이 plan 범위 밖(spec Rejected Alternatives "offer를 파이프라인 SKILL 내부 종결 단계로"의 강등판) — 사용자 확인 후 별도 계획.

- [ ] **Step 4: Commit (판정 노트만 — 코드 변경 없음)**

코드 변경이 없으므로 별도 commit 없음. 판정은 subagent-driven 리뷰 노트/PR 설명에 기록. feasible=yes면 바로 Task 1.

---

## Task 1: `setup-qg.sh` — stale-sentinel delete (behavioral TDD)

이 파이프라인 전체에서 **유일하게 진짜 실행되는** 조각. SKILL/command는 프롬프트라 정적 grep으로만 검증되지만, `setup-qg.sh`는 실제 bash라 진짜 behavioral 테스트가 가능하다 — sentinel absence 불변식(Global Constraints)의 load-bearing 가드.

**왜 SKILL이 아니라 `setup-qg.sh`인가:** `skills/quality-pipeline/SKILL.md`의 `allowed-tools`는 `Write`는 주지만 `rm`/bare `Bash`가 없다(line 14-39) — SKILL은 파일을 **삭제할 수 없다.** spec §9는 "Preflight에 stale 삭제"를 SKILL에 귀속했으나, SKILL의 Preflight P2가 곧 `setup-qg.sh --ensure` 호출(SKILL.md line 99-103)이므로, 삭제를 그 스크립트에 두는 것이 그 요구의 **충실한 메커니즘**이다.

**왜 legacy-cleanup 블록이 아니라 session-id 검증 직후인가:** `setup-qg.sh`는 `--ensure` 모드에서 state file이 이미 있으면 line 168-171에서 **조기 exit 0**한다. state file은 완료 후에도 `/cancel-qg`/SessionEnd까지 남으므로(SKILL.md line 715), **같은 세션의 두 번째 `/qg` 실행**은 그 조기 exit를 탄다 — legacy-cleanup(line 179+)은 실행되지 않는다. 우리가 막으려는 바로 그 cross-run-same-session stale이 조기 exit 뒤에 있다. 따라서 삭제는 **session-id 검증 직후(line 143 뒤), active-pipeline 조기 exit(line 168) 전**에 둬 매 호출 실행돼야 한다.

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh` (session-id 검증 line 143 직후, `# --- Branch worktree mode ---` line 145 앞에 삽입)
- Test: `plugins/quality-gates/tests/test_setup_qg.sh` (기존 파일에 케이스 추가)

**Interfaces:**
- Consumes: `$SESSION_ID` (line 123-143에서 이미 resolve·validate됨).
- Produces: 매 `setup-qg.sh` 호출 시 `.claude/quality-gates/$SESSION_ID/publish-eligible.md`가 **없어짐**(있었다면). Task 2의 SKILL Write가 완료 시 재기록.

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/quality-gates/tests/test_setup_qg.sh`를 읽어 기존 idiom(임시 dir + `CLAUDE_CODE_SESSION_ID` 설정 + 스크립트 실행 + assert) 확인 후, 아래 케이스를 파일 끝의 결과 집계 전에 추가한다. (기존 테스트의 setup/teardown 헬퍼·PASS/FAIL 카운터 변수명에 맞춰 조정 — 없으면 아래 자립 블록 사용.)

```bash
# --- stale publish-eligible.md deletion (v2.10.0) ---
# setup-qg.sh must delete a prior run's publish-eligible sentinel on EVERY
# invocation (incl. --ensure with an existing state file), so a second /qg
# run in the same session cannot inherit a stale offer.
stale_tmp="$(mktemp -d)"
(
  cd "$stale_tmp" || exit 1
  export CLAUDE_CODE_SESSION_ID="staleSentinelTest01"
  sid_dir=".claude/quality-gates/$CLAUDE_CODE_SESSION_ID"
  mkdir -p "$sid_dir"
  # Simulate a completed prior run: state file present (triggers --ensure early-exit)
  # AND a stale sentinel present.
  printf '%s\n' '---' 'session_id: "staleSentinelTest01"' '---' > "$sid_dir/pipeline.md"
  printf '%s\n' '<!-- qg-publish-eligible:v1 -->' 'verdict: clean' > "$sid_dir/publish-eligible.md"
  bash "$PLUGIN_ROOT/scripts/setup-qg.sh" --ensure >/dev/null 2>&1
  if [[ ! -e "$sid_dir/publish-eligible.md" ]]; then
    pass "setup-qg --ensure deletes stale publish-eligible.md even past the early-exit"
  else
    fail "stale publish-eligible.md survived setup-qg --ensure"
  fi
)
rm -rf "$stale_tmp"
```

정확한 `pass`/`fail`/`PLUGIN_ROOT` 변수명은 기존 `test_setup_qg.sh` 헤더에서 확인해 맞춘다.

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/quality-gates/tests/test_setup_qg.sh`
Expected: 새 케이스 **FAIL** ("stale publish-eligible.md survived setup-qg --ensure") — 아직 삭제 로직이 없으므로. 기존 케이스는 GREEN 유지.

- [ ] **Step 3: 최소 구현**

`plugins/quality-gates/scripts/setup-qg.sh`에서 session-id 패턴 검증 블록(line 139-143) 직후, `# --- Branch worktree mode ---`(line 145) 앞에 삽입:

```bash
# --- Stale publish-eligible sentinel cleanup (v2.10.0) ---
# The Task-2 pipeline SKILL writes .claude/quality-gates/<sid>/publish-eligible.md
# only on non-aborted completion; the qg.md command offers publish iff that file
# is present. State files persist across runs in a session, so setup-qg.sh (called
# at SKILL Preflight P2) must clear a prior run's sentinel on EVERY invocation —
# BEFORE the --ensure early-exit below (line ~168), else a second /qg in the same
# session inherits a stale offer (false-offer). SKILL.md itself cannot rm (Write-only
# allowed-tools), so this deletion lives here (its Preflight mechanism).
rm -f ".claude/quality-gates/$SESSION_ID/publish-eligible.md"
```

`rm -f`는 파일이 없으면 no-op(무해) — 첫 실행/genuine no-op에서도 안전. `$SESSION_ID`는 line 140의 `^[A-Za-z0-9_-]{8,}$` 패턴 가드를 이미 통과했으므로 경로 주입 위험 없음.

- [ ] **Step 4: 통과 확인**

Run: `bash plugins/quality-gates/tests/test_setup_qg.sh`
Expected: 새 케이스 **PASS** + 기존 케이스 전부 GREEN.

- [ ] **Step 5: teeth 증명 (mutation)**

Step 3의 `rm -f` 줄을 임시 주석 처리 → `bash plugins/quality-gates/tests/test_setup_qg.sh` → 새 케이스 **FAIL** 확인(테스트가 진짜 삭제를 검증함을 입증) → 주석 해제 복원 → 재실행 GREEN.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/tests/test_setup_qg.sh
git commit -m "feat(quality-gates): setup-qg.sh clears stale publish-eligible sentinel each run

파이프라인 완료 sentinel(publish-eligible.md)의 stale 잔존을 Preflight마다 제거.
--ensure 조기 exit 앞(session-id 검증 직후)에 둬 same-session 두 번째 /qg가
직전 run의 sentinel로 false-offer하는 것을 차단(AC12). SKILL은 Write-only라
rm 불가 → setup-qg.sh가 그 Preflight 메커니즘.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: 파이프라인 SKILL — sentinel Write 2지점 + description 정제 + `Skill`-부재 락

파이프라인이 **비중단 완료 시에만** sentinel을 Write하도록 두 종결 지점에 배선하고, description의 "zero-click" 문구를 정제하며, `allowed-tools`에 `Skill`이 **없음**을 회귀 락으로 고정한다. **`allowed-tools`는 `Skill` 추가 없이 무변경**(NG6) — `Write`는 이미 있음(line 38).

SKILL.md는 프롬프트라 실행되지 않는다 → 검증은 정적 section-scoped grep + teeth. (진짜 behavioral 가드는 Task 1의 setup-qg.sh delete.)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`
  - `description` 정제 (line 11-12 "zero-click" 문구)
  - 새 subsection "Publish-eligible sentinel" (sentinel 포맷 DRY 정의) — `## Final Summary`(line 700) 앞
  - Final Summary에 Write 배선 (line 713 뒤, `State file cleanup` 줄 앞)
  - Runtime gate R6에 Write 배선 (line 640-648 outcome routing)
  - Preflight P2에 "setup-qg.sh가 stale sentinel을 지운다" 한 줄 문서화 (line 103 뒤)
- Test: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` (섹션-스코프 assert 추가)

**Interfaces:**
- Consumes: Task 1이 보장하는 "매 run 시작 시 sentinel 부재".
- Produces: 비중단 완료 시 Global Constraints 포맷의 `publish-eligible.md`. Task 3의 offer가 이걸 읽는다.

- [ ] **Step 1: 실패하는 테스트 작성 (정적 section-scoped, teeth)**

`test_skill_orchestration_behavior.sh` 끝(결과 집계 `exit`/`fail` 판정 전)에 추가. 기존 `first_line`/`first_line_after`/`assert_line` 헬퍼 재사용:

```bash
# --- v2.10.0 publish-eligible sentinel wiring ---
# (a) allowed-tools must NOT contain a standalone `Skill` entry (NG6 — no skill-nesting).
if awk '/^allowed-tools:/{f=1;next} f&&/^[^ -]/{f=0} f' "$SKILL_MD" | grep -qE '^[[:space:]]*-[[:space:]]*Skill[[:space:]]*$'; then
  echo "FAIL: quality-pipeline allowed-tools contains Skill (NG6 violation)"; fail=$((fail+1))
else
  echo "PASS: quality-pipeline allowed-tools has no Skill (NG6)"
fi

# (b) Final Summary section writes the sentinel (body-unique literal in section window).
fs_start="$(first_line '^## Final Summary')"
fs_end="$(first_line_after '^## ' "$fs_start")"
if awk -v s="$fs_start" -v e="$fs_end" 'NR>s && NR<e' "$SKILL_MD" | grep -qF 'publish-eligible.md'; then
  echo "PASS: Final Summary wires publish-eligible.md write (line window $fs_start..$fs_end)"
else
  echo "FAIL: Final Summary missing publish-eligible.md write"; fail=$((fail+1))
fi

# (c) Runtime gate R6 wires the sentinel too (single-gate /qg runtime bypasses Final Summary).
r6_start="$(first_line 'Step R6')"
r6_end="$(first_line_after '^## ' "$r6_start")"
if awk -v s="$r6_start" -v e="$r6_end" 'NR>s && NR<e' "$SKILL_MD" | grep -qF 'publish-eligible.md'; then
  echo "PASS: Runtime R6 wires publish-eligible.md write (line window $r6_start..$r6_end)"
else
  echo "FAIL: Runtime R6 missing publish-eligible.md write"; fail=$((fail+1))
fi

# (d) The write is guarded by a non-aborted disposition (body-unique guard phrase).
if grep -qF 'disposition' "$SKILL_MD" && grep -qiE 'aborted.*(then )?(do not|skip|않).*(sentinel|publish-eligible)|non-aborted' "$SKILL_MD"; then
  echo "PASS: sentinel write guarded by non-aborted disposition"
else
  echo "FAIL: sentinel write missing non-aborted disposition guard"; fail=$((fail+1))
fi
```

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: (b)(c)(d) **FAIL** (아직 Write 미배선), (a) **PASS** (현재도 Skill 없음). 기존 assert 전부 GREEN 유지.

- [ ] **Step 3: 구현 — description 정제**

SKILL.md line 11-12 현재:
```
  With a gate argument (`/qg both|review|runtime`) the happy path requires zero
  user clicks; bare `/qg` asks one upfront gate-scope question (Review only /
  both), then runs click-free on the happy path.
```
끝에 한 문장 추가(게이트=zero-click, publish=별도 opt-in 정제 — 확정 결정 2):
```
  With a gate argument (`/qg both|review|runtime`) the happy path requires zero
  user clicks for the gates; bare `/qg` asks one upfront gate-scope question
  (Review only / both), then runs click-free on the happy path. On non-aborted
  completion the command layer offers an opt-in PR-understanding publish
  continuation (a separate consent-gated step, not a gate).
```

- [ ] **Step 4: 구현 — "Publish-eligible sentinel" subsection (DRY 포맷)**

`## Final Summary`(line 700) **바로 앞**에 새 섹션 삽입:

```markdown
## Publish-eligible sentinel

비중단 완료 시, 커맨드 계층이 읽을 fail-safe sentinel을 `Write`한다. **두 종결
지점**(Final Summary, Runtime R6)이 이 포맷을 공유한다 — 재정의 말고 여기를 참조.

- **경로:** `.claude/quality-gates/<sid>/publish-eligible.md` (`<sid>` =
  `$CLAUDE_CODE_SESSION_ID`, state file과 동일). setup-qg.sh가 Preflight마다
  stale 사본을 지우므로(Preflight P2), 이 파일의 존재 = **이번 run**의 비중단 완료.
- **내용 (정확히 2줄):**
  ```
  <!-- qg-publish-eligible:v1 -->
  verdict: <terminal 게이트 verdict 토큰>
  ```
  1번째 줄은 고정 마커(커맨드의 유효성 검사). `<verdict>`는 방금 렌더한 terminal
  게이트 토큰(`clean` / `proceeded-with-findings iter N` / `failed` /
  `SKIP_WITH_EVIDENCE` / `no scope reviewed …`)을 그대로 — offer 문구에 삽입된다.
- **disposition 가드 (§5-A):** `## Final Summary`는 게이트별 셀을 독립 렌더한다
  (`Review gate\t<token>` / `Runtime gate\t<token>`). **disposition = `aborted`
  iff 어느 한 셀 token이 리터럴 `aborted`로 시작**(Review `aborted iter N` /
  Runtime `aborted`). disposition = aborted면 **sentinel을 쓰지 않는다.** 그 외
  (clean/proceeded-with-findings/failed/skipped/SKIP_WITH_EVIDENCE)는 non-aborted
  → 쓴다.
- **Write는 idempotent** — 같은 경로 overwrite. 한 실행이 Final Summary와 R6에
  모두 도달해도 동일 sentinel을 다시 쓸 뿐(무해).
```

- [ ] **Step 5: 구현 — Final Summary Write 배선**

SKILL.md Final Summary 섹션에서 render-terminal.py 블록(line 707-710) 뒤, `State file cleanup is deferred …`(line 715) **앞**에 삽입:

```markdown
**Publish-eligible sentinel (non-aborted completion only).** 위 두 게이트 셀
token을 검사한다. **어느 셀이든 리터럴 `aborted`로 시작하면 disposition =
aborted → sentinel을 쓰지 않는다**(사용자 Stop). 그 외에는 [Publish-eligible
sentinel](#publish-eligible-sentinel) 포맷으로 `Write`한다 — `<verdict>`는 이
요약의 terminal 게이트 token(Runtime을 돌렸으면 Runtime 셀, review-only면
Review 셀). 이 Write가 커맨드 계층 offer를 arm한다.
```

- [ ] **Step 6: 구현 — Runtime R6 Write 배선**

SKILL.md Step R6 outcome routing(line 640-648)에서, 종결 분기(clean / forced_downgrade=yes / FAIL / SKIP_WITH_EVIDENCE)가 final summary로 가기 전에 sentinel을 쓰도록, R6 블록 끝(line 648 `NEEDS_RESOLUTION` bullet 뒤)에 삽입:

```markdown
**Publish-eligible sentinel (single-gate `/qg runtime` — non-aborted terminal
only).** `/qg runtime`은 Dispatch Loop를 우회하므로(위 [Arguments](#arguments))
Final Summary 기록 지점에 도달하지 않을 수 있다. R6이 **비중단 terminal**
(clean / `forced_downgrade: yes` / FAIL / SKIP_WITH_EVIDENCE)로 종결하면 여기서
[Publish-eligible sentinel](#publish-eligible-sentinel)을 `Write`한다(`<verdict>`
= 그 R6 verdict token). **NEEDS_RESOLUTION → Stop 및 사용자 Stop 경로에서는 쓰지
않는다**(abort → offer 미발동). Final Summary도 도달했다면 idempotent overwrite라
무해.
```

- [ ] **Step 7: 구현 — Preflight P2 문서화 한 줄**

SKILL.md Preflight Step P2(setup-qg.sh 호출, line 99-107) 끝에 한 줄 추가(SKILL 텍스트가 실제를 반영 — sentinel absence 불변식의 출처 명시):

```markdown
`setup-qg.sh --ensure`는 또한 이번 run 시작 시 stale
`.claude/quality-gates/<sid>/publish-eligible.md`를 지운다(매 호출, `--ensure`
조기 exit 앞) — [Publish-eligible sentinel](#publish-eligible-sentinel)이 항상
이번 run의 완료만 반영하도록(SKILL은 `Write`만 있고 삭제 tool이 없어 이 정리는
스크립트가 담당).
```

- [ ] **Step 8: 통과 확인**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: (a)(b)(c)(d) 전부 **PASS** + 기존 assert 전부 GREEN.

- [ ] **Step 9: teeth 증명 (mutation)**

Step 5의 Final Summary Write 단락을 임시 삭제 → 테스트 (b) **FAIL** 확인 → 복원. 마찬가지로 Step 6 단락 삭제 → (c) FAIL → 복원. `allowed-tools`에 `  - Skill`을 임시 추가 → (a) FAIL → 제거. 셋 다 teeth 있음 입증 후 재실행 GREEN.

- [ ] **Step 10: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "feat(quality-gates): pipeline writes publish-eligible sentinel on non-aborted completion

Final Summary(disposition≠aborted) + Runtime R6(비중단 terminal) 두 지점에서
publish-eligible.md sentinel Write. allowed-tools 무변경(Skill 미추가, NG6).
description의 zero-click을 게이트-only로 정제. Preflight가 setup-qg.sh로 stale을
지운다는 사실 문서화. NG6 회귀 락 + sentinel-write teeth.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `/qg.md` — post-pipeline publish offer + `allowed-tools` AskUserQuestion

커맨드에 파이프라인 스킬 종료 후 실행되는 post-pipeline 단계를 추가한다: kill-switch 체크 → sentinel 유효성 → offer `AskUserQuestion` → "예" 시 `Skill(publishing-pr-understanding)`, 관측 가능 실패 시 `/qg-publish` floor. `allowed-tools`에 `AskUserQuestion` 추가(`Skill`·`Bash`·`Read`는 이미 있음, line 4).

**Files:**
- Modify: `plugins/quality-gates/commands/qg.md`
  - `allowed-tools` (line 4)에 `AskUserQuestion` 추가
  - `## Instructions`(line 41-54) 뒤, `### Quick Reference`(line 56) 앞에 새 `### After the pipeline: publish offer` 섹션
  - Quick Reference 표(line 58-76)에 종료 offer 한 줄
- Test: `plugins/quality-gates/tests/test_qg_publish_offer.sh` (**신규** — 기존 `test_qg_publish_command.sh`는 `qg-publish.md` 대상이라 별개; offer는 `qg.md`에 산다)

**Interfaces:**
- Consumes: Task 2가 쓰는 `.claude/quality-gates/<sid>/publish-eligible.md` (마커 + `verdict:` 줄).
- Produces: 사용자에게 보이는 offer + "예" 시 `Skill("quality-gates:publishing-pr-understanding")` 위임 (qg-publish.md의 dispatch와 **동일 호출** — drift 방지 cross-ref).

- [ ] **Step 1: 실패하는 테스트 작성 (신규 파일)**

`plugins/quality-gates/tests/test_qg_publish_offer.sh` 생성 (`test_qg_publish_command.sh` idiom 차용):

```bash
#!/usr/bin/env bash
# test_qg_publish_offer.sh — qg.md post-pipeline publish offer (v2.10.0).
# Static doc-lock: the offer block, its Skill delegation, the /qg-publish floor,
# and AskUserQuestion in allowed-tools. Section-scoped + body-unique (teeth).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CMD="$PLUGIN_ROOT/commands/qg.md"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }
test -f "$CMD" || { echo "FAIL: command missing at $CMD"; exit 1; }

# (1) allowed-tools includes AskUserQuestion (offer 발동용).
AT="$(awk '/^allowed-tools:/{print; exit}' "$CMD")"
grep -q 'AskUserQuestion' <<<"$AT" && pass "allowed-tools includes AskUserQuestion" || fail "AskUserQuestion missing from allowed-tools"

# Section window: '### After the pipeline' 부터 다음 '###'/'##' 헤더 전까지만
# (body-unique + header-satisfiable trap 회피).
OFFER="$(awk '/^### After the pipeline/{f=1;print;next} f&&/^#{2,3} /{exit} f{print}' "$CMD")"

# (2) body-unique offer question phrase (헤더에 없음).
grep -qF 'PR-이해글을 생성해서 게시할까요' <<<"$OFFER" && pass "offer question literal present" || fail "offer question literal missing"

# (3) "예" 분기가 publish skill로 위임.
grep -qF 'publishing-pr-understanding' <<<"$OFFER" && pass "offer delegates to publish skill" || fail "no publish-skill delegation in offer"

# (4) graceful floor: /qg-publish 안내.
grep -qF '/qg-publish' <<<"$OFFER" && pass "offer has /qg-publish floor" || fail "no /qg-publish floor in offer"

# (5) kill switch 체크.
grep -qF 'DEVBREW_QG_DISABLE_PUBLISH' <<<"$OFFER" && pass "offer honors DEVBREW_QG_DISABLE_PUBLISH" || fail "kill switch not checked in offer"

# (6) sentinel 유효성(마커) 체크.
grep -qF 'publish-eligible.md' <<<"$OFFER" && pass "offer checks publish-eligible sentinel" || fail "sentinel presence not checked in offer"

echo "qg-publish-offer: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
```

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/quality-gates/tests/test_qg_publish_offer.sh`
Expected: (1)-(6) 전부 **FAIL** (아직 offer 섹션·AskUserQuestion 없음).

- [ ] **Step 3: 구현 — allowed-tools에 AskUserQuestion 추가**

`commands/qg.md` line 4를 수정:
```
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)", "Bash(rm:*)", "Bash(test:*)", "Agent", "Skill", "Bash", "Read", "Edit", "Write", "Glob", "Grep", "AskUserQuestion"]
```
(`AskUserQuestion`만 추가. 나머지 무변경.)

- [ ] **Step 4: 구현 — post-pipeline offer 섹션**

`## Instructions` 섹션 끝(line 54, "aborted at a decision point." 뒤) — `### Quick Reference`(line 56) 앞에 삽입:

```markdown
### After the pipeline: publish offer

파이프라인 스킬(`Skill("quality-gates:quality-pipeline")`)이 종료해 제어가 이
커맨드로 돌아오면, 아래를 **순서대로** 수행한다. 이는 게이트가 아니라 게이트
**뒤에** 얹힌 opt-in 연속이다 — verdict·pass/fail에 영향 없음.

<!-- 이 "예" 분기의 Skill 호출은 commands/qg-publish.md의 dispatch와 동일 호출.
     두 call site가 drift하지 않도록 함께 수정할 것 (Law 3 위생). -->

1. **Kill switch.** `DEVBREW_QG_DISABLE_PUBLISH=1`이면 offer를 건너뛰고 한 줄만
   출력하고 종료: `> [quality-gates] publish offer disabled via DEVBREW_QG_DISABLE_PUBLISH=1`.
2. **Eligibility (fail-safe — default no-offer).** 아래 둘이 **모두** 참이 아니면
   offer 없이 조용히 종료(비완료/abort/trivia는 sentinel 부재 → 여기서 걸림):
   - `test -f ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/publish-eligible.md"` 성공, **그리고**
   - 그 파일 1번째 줄이 정확히 `<!-- qg-publish-eligible:v1 -->` (마커 유효).
3. **Offer.** sentinel의 `verdict:` 줄 값을 `<verdict>`로 읽어(파싱 실패 시 `완료`
   로 대체) 아래 `AskUserQuestion`을 발동한다:

   ```
   AskUserQuestion({ questions: [{
     question: "게이트 완료 (<verdict>) — 이 브랜치의 PR-이해글을 생성해서 게시할까요? (게시 전 미리보기 + 별도 동의가 있습니다.)",
     header: "PR 이해글",
     options: [
       {label: "예, 이어서 생성·게시", description: "publishing-pr-understanding skill 실행 — 미리보기·secret-scan·동의 게이트를 거쳐 게시."},
       {label: "아니오",              description: "여기서 종료. 나중에 /qg-publish로 따로 실행할 수 있습니다."}
     ], multiSelect: false }]})
   ```

   - **"예, 이어서 생성·게시"** → `Skill("quality-gates:publishing-pr-understanding")`
     를 인자 없이 호출(= 게시 경로). 이후는 그 skill이 소유: Preflight → Build →
     Generate → Scan(FAIL-CLOSED) → Preview → **Consent(informed)** → Publish →
     Report. offer는 GitHub write를 pre-consent하지 **않는다** — 그 skill의
     informed-consent 게이트가 반드시 다시 fire한다(2차 touchpoint).
   - **"아니오"** → 종료.
   - **graceful floor (관측 가능한 Skill 에러에 한함).** post-pipeline 단계가
     **실행은 됐으나** 위 `Skill(...)` 호출이 관측 가능하게 에러(스킬 부재·
     invocation 실패)하면, crash하지 말고 정확히 한 줄 출력한다:
     `> 이어서 게시하려면: /qg-publish` (누락 capability는 downgrade, crash 아님).
```

- [ ] **Step 5: 구현 — Quick Reference 한 줄**

Quick Reference 표(line 58-76)에 `/qg-publish` 줄(line 73) 근처에 종료 offer 행 추가:
```
| (완료 후 자동) | 비중단 완료 시 "PR-이해글 이어서 게시?" opt-in offer (consent-gated; 게이트 아님; `DEVBREW_QG_DISABLE_PUBLISH=1`로 끔) |
```

- [ ] **Step 6: 통과 확인**

Run: `bash plugins/quality-gates/tests/test_qg_publish_offer.sh`
Expected: (1)-(6) 전부 **PASS**.

또한 기존 커맨드 테스트 무회귀:
Run: `bash plugins/quality-gates/tests/test_qg_publish_command.sh`
Expected: 전부 GREEN (이 테스트는 `qg-publish.md` 대상, 무영향).

- [ ] **Step 7: teeth 증명 (mutation)**

offer 섹션에서 `PR-이해글을 생성해서 게시할까요` 줄을 임시 삭제 → (2) FAIL 확인 → 복원. `/qg-publish` floor 줄 삭제 → (4) FAIL → 복원. `allowed-tools`에서 `AskUserQuestion` 임시 제거 → (1) FAIL → 복원. GREEN 재확인.

- [ ] **Step 8: Commit**

```bash
git add plugins/quality-gates/commands/qg.md plugins/quality-gates/tests/test_qg_publish_offer.sh
git commit -m "feat(quality-gates): /qg offers opt-in PR-understanding publish on completion

파이프라인 종료 후 post-pipeline 단계: kill-switch → sentinel 유효성 → offer
AskUserQuestion → '예' 시 Skill(publishing-pr-understanding) 위임, 관측가능
실패 시 /qg-publish floor. command→skill 체이닝(중첩 아님). allowed-tools에
AskUserQuestion 추가. offer literal·delegation·floor·kill-switch teeth.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `pr-understanding-builder` — 한국어-primary style law (G3, 독립)

**독립 변경** — offer 파일들(Task 0-3)과 의존성이 전혀 없다. offer feasibility와 무관하게 단독 구현/머지 가능. 페르소나 **prose** style law 1개만 추가 — 스키마 블록(마커·헤더·placeholder 순서)은 불변(C3/NG3), 고정 영문 섹션 헤더 유지.

**Files:**
- Modify: `plugins/quality-gates/agents/pr-understanding-builder.md` (`## Audience & plain-language lever (§8)` 섹션, line 39-53 — 스타일 law bullet 목록에 추가)
- Test: `plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh` (기존 파일에 prose-law grep 추가; frontmatter 테스트지만 같은 파일 대상이라 자연스러운 집)

**Interfaces:**
- Consumes: 없음.
- Produces: 페르소나에 grep 가능한 Korean-primary law 리터럴. 스키마 shape 불변.

- [ ] **Step 1: 실패하는 테스트 작성**

`test_pr_understanding_builder_frontmatter.sh`를 읽어 idiom 확인 후, 아래 케이스 추가 (없으면 자립 grep):

```bash
# --- Korean-primary style law (G3, v2.10.0) ---
AGENT="$PLUGIN_ROOT/agents/pr-understanding-builder.md"
grep -qF '한국어-primary' "$AGENT" \
  && pass "builder persona declares Korean-primary style law" \
  || fail "Korean-primary style law missing"
# 고정 영문 스키마 헤더는 유지(회귀: 헤더 한국어화 금지).
grep -qF 'In one breath' "$AGENT" \
  && pass "fixed English schema header 'In one breath' retained" \
  || fail "schema header drifted (NG3 violation)"
```

`pass`/`fail`/`PLUGIN_ROOT` 변수명은 기존 파일에 맞춤.

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh`
Expected: 첫 케이스 **FAIL** ("Korean-primary style law missing"), 둘째 케이스 PASS(헤더 현존). 기존 케이스 GREEN.

- [ ] **Step 3: 구현 — style law 추가**

`agents/pr-understanding-builder.md`의 `## Audience & plain-language lever (§8)` 섹션(line 41-53) bullet 목록 끝(line 53 "Tier is a **floor**…" bullet 뒤)에 새 bullet 추가:

```markdown
- **언어 = 한국어-primary.** 산문(prose)은 한국어로 저술한다 — devbrew 문서 관례
  (Korean-primary, English-terms-only)와 정합. 영어는 **식별자**(파일명·타입명·함수명·
  계약 시그니처), **고유명사**, **고정 스키마 섹션 헤더**(`In one breath` /
  `Before → After` / `Testing` / `Risk & Rollout` 등 — 이들은 스키마 shape이라
  번역하지 않는다), 그리고 **번역이 어색한 기술 용어**(`upsert`, `diff`, `sandbox`
  등)에 한정한다. 고정 헤더·마커·placeholder 순서는 이 law가 바꾸지 않는다.
```

- [ ] **Step 4: 통과 확인**

Run: `bash plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh`
Expected: 전부 **PASS**.

기존 페르소나 무회귀:
Run: `bash plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh` (동일) — frontmatter assert(allowedTools:[], disallowedTools, model:opus) 전부 GREEN 확인.

- [ ] **Step 5: teeth 증명**

Step 3 bullet에서 `한국어-primary` 문구를 임시 삭제/변경 → 첫 케이스 FAIL 확인 → 복원.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/agents/pr-understanding-builder.md plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh
git commit -m "feat(quality-gates): pr-understanding-builder authors PR prose in Korean-primary

페르소나에 Korean-primary style law 추가(G3, 독립). devbrew 문서 관례 정합.
고정 영문 스키마 헤더·마커·placeholder 순서는 불변(NG3). 영어는 식별자·
고유명사·헤더·번역 어색 기술 용어에 한정.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: README/publish NG5 정합 + version bump + CHANGELOG + doc-lock

프레이밍 문구를 새 command-layer offer 현실에 맞게 정합하고, `plugin.json`을 `2.10.0`으로 bump하고 `CHANGELOG`를 추가하며, doc-lock 테스트의 버전·프레이밍 assert를 동기화한다. **마지막 task** — 모든 표면이 들어온 뒤 version을 한 번 올린다.

**Files:**
- Modify: `plugins/quality-gates/README.md`
  - line 136 (PR-understanding publish cost 절): "수동·non-auto-chained" 정합
  - line 151-158 (세 번째 게이트 아님 절): "자동 실행도, `/qg` 뒤 auto-chain도 없다"(line 157) 정합. "gh는 게이트에 없다"·"세 번째 게이트 아님"은 **유지**.
- Modify: `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md` line 114 (NG5 문구)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` line 4 (`version`)
- Modify: `plugins/quality-gates/CHANGELOG.md` (top에 `[2.10.0]`)
- Test: `plugins/quality-gates/tests/test_qg_publish_docs.sh` (version assert 2.9.0→2.10.0, NG5 프레이밍 doc-lock)

**Interfaces:**
- Consumes: Task 2-4의 표면(문구가 참조).
- Produces: 정합된 프레이밍 + `2.10.0` cache key + CHANGELOG 이력.

- [ ] **Step 1: 실패하는 테스트 작성/수정**

`test_qg_publish_docs.sh` line 10-13의 버전 assert를 `2.10.0`으로 갱신하고, NG5 정합 프레이밍 doc-lock을 추가:

```bash
grep -qE '"version":[[:space:]]*"2\.10\.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
  && pass "plugin.json version 2.10.0" || fail "version not bumped to 2.10.0"
grep -qE '^## \[2\.10\.0\]' "$PLUGIN_ROOT/CHANGELOG.md" \
  && pass "CHANGELOG has [2.10.0]" || fail "CHANGELOG missing [2.10.0]"
```
추가 (README·publish SKILL의 정합 문구가 both에 존재 — body-unique):
```bash
# NG5 reconciliation: command-layer opt-in offer는 있으나 자동 실행 아님.
grep -qF 'command-layer opt-in offer' "$README" \
  && pass "README reconciles NG5 to command-layer opt-in offer" \
  || fail "README NG5 reconciliation phrase missing"
grep -qF 'command-layer opt-in offer' "$PLUGIN_ROOT/skills/publishing-pr-understanding/SKILL.md" \
  && pass "publish SKILL reconciles NG5" || fail "publish SKILL NG5 phrase missing"
# 유지 불변식: '세 번째 게이트' 부정 + gh 게이트 부재는 남아 있어야.
grep -qF '세 번째 게이트가 아니다' "$README" \
  && pass "README keeps 'not a third gate'" || fail "third-gate framing lost"
```

- [ ] **Step 2: 실패 확인**

Run: `bash plugins/quality-gates/tests/test_qg_publish_docs.sh`
Expected: version(2.10.0)·CHANGELOG·NG5-정합 assert **FAIL**; "세 번째 게이트가 아니다" PASS(현존).

- [ ] **Step 3: 구현 — plugin.json bump**

`.claude-plugin/plugin.json` line 4: `"version": "2.9.0"` → `"version": "2.10.0"`.

- [ ] **Step 4: 구현 — CHANGELOG 항목**

`CHANGELOG.md`의 `## [2.9.0]`(line 6) **앞**에 삽입:

```markdown
## [2.10.0] — 2026-07-07

`/qg` 파이프라인이 비중단 완료되면 커맨드 계층이 "PR 이해글을 이어서 생성·게시?"를
한 번 opt-in offer한다("예" → 기존 `publishing-pr-understanding` skill을 command→skill
체이닝으로 실행; consent·secret-scan 게이트 무변경 — offer + 자체 consent = 2 touchpoint).
파이프라인 tool-set 무변경(`Skill` 미추가, NG6) — 비중단 완료 시 fail-safe
`publish-eligible.md` sentinel만 Write하고 커맨드가 그걸 보고 offer한다. 부수로
`pr-understanding-builder`가 PR 이해글을 한국어-primary로 저술.

### Added
- `commands/qg.md` post-pipeline publish offer (kill-switch → sentinel 유효성 →
  `AskUserQuestion` → "예" 시 `Skill(publishing-pr-understanding)`, 관측가능 실패 시
  `/qg-publish` floor). `allowed-tools`에 `AskUserQuestion` 추가.
- `quality-pipeline` SKILL이 비중단 완료 시 `.claude/quality-gates/<sid>/publish-eligible.md`
  sentinel Write(Final Summary disposition≠aborted + Runtime R6 비중단 terminal).
- `pr-understanding-builder` Korean-primary style law(G3, 독립 — 고정 영문 스키마
  헤더 유지).
- `DEVBREW_QG_DISABLE_PUBLISH=1`이 종료 offer도 끈다(커맨드가 env 직접 체크).

### Changed
- `setup-qg.sh`가 매 Preflight마다 stale `publish-eligible.md`를 지운다(--ensure
  조기 exit 앞) — sentinel이 항상 이번 run 반영. `/qg --reset` rm 목록에도 포함.
- README·publish SKILL NG5 프레이밍 정합: "종료 시 command-layer opt-in offer는
  있으나 자동 실행 아님(consent-gated; 세 번째 게이트 아님; gh는 게이트에 없음)".
- **버전 2.9.0 → 2.10.0** (minor — 새 표면: 종료 시 publish continuation offer).
```

- [ ] **Step 5: 구현 — README 정합 (line 136 + 157)**

README line 136 끝 문장 "`/qg-publish`가 수동·non-auto-chained 호출(Review/Runtime gate 뒤에 자동 연결되지 않음)이라 명시적 실행 자체가 비용 수용으로 간주된다."를 정합:
```
… `/qg-publish`는 명시적 실행이 곧 비용 수용이며, `/qg` 완료 시의 command-layer
opt-in offer로도 이어질 수 있으나 자동 실행이 아니다(offer + 자체 consent =
2 touchpoint) — 게이트가 아니므로 depth 기반 자동 트리거는 없다.
```

README line 157 "…preview를 읽고 AskUserQuestion으로 명시 동의한 뒤에만 일어난다 — 자동 실행도, `/qg` 뒤 auto-chain도 없다."를 정합(핵심: auto-chain 부정 → opt-in offer는 있으나 자동 실행 아님으로):
```
…preview를 읽고 AskUserQuestion으로 명시 동의한 뒤에만 일어난다. `/qg` 완료 시
command-layer opt-in offer로 이어질 수 있으나 **자동 실행은 아니다** — offer(1차)와
publish의 informed-consent(2차) 둘 다 사람의 명시 동의가 필요하다(2 touchpoint).
세 번째 게이트도 아니고, gh는 여전히 게이트 어디에도 없다.
```
(불변식 유지: "세 번째 게이트가 아니다" 헤더 문장 line 151, "gh는 위 두 게이트 어디에도 없다" line 152 그대로.)

- [ ] **Step 6: 구현 — publish SKILL NG5 (line 114)**

`skills/publishing-pr-understanding/SKILL.md` line 114 "…`/qg-publish`는 manual·non-auto-chained(NG5)라 명시적 실행 자체가 수용." 을 정합:
```
… `/qg-publish`는 명시적 실행이 곧 수용이며, `/qg` 완료 시 command-layer opt-in
offer로도 이어질 수 있으나 자동 실행은 아니다(NG5 정합 — offer + 자체 consent =
2 touchpoint; 이 skill 내부 로직은 무변경).
```

- [ ] **Step 7: 통과 확인**

Run: `bash plugins/quality-gates/tests/test_qg_publish_docs.sh`
Expected: 전부 **PASS**.

- [ ] **Step 8: teeth 증명**

README에서 `command-layer opt-in offer` 문구 삭제 → 해당 assert FAIL → 복원. plugin.json version을 임시로 `2.9.0`으로 되돌림 → version assert FAIL → `2.10.0` 복원. GREEN 재확인.

- [ ] **Step 9: `/qg --reset` rm 목록 확인 (C5/AC12)**

`commands/qg.md`의 `--reset` 블록(line 17-27)은 `rm -rf ".claude/quality-gates/$SID"`로 세션 폴더를 통째 지운다(line 20-21) — `publish-eligible.md`는 그 폴더 안이므로 **이미 포함**된다. 추가 rm 줄 불필요. 이 사실을 확인만 하고(별도 편집 없음), 다르면(세션 폴더를 통째 지우지 않는 형태로 바뀌었으면) `publish-eligible.md`를 명시 추가.

- [ ] **Step 10: Commit**

```bash
git add plugins/quality-gates/README.md plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/quality-gates/tests/test_qg_publish_docs.sh
git commit -m "docs(quality-gates): v2.10.0 — reconcile NG5 framing + version bump + CHANGELOG

README·publish SKILL의 'auto-chain 없음'을 'command-layer opt-in offer는 있으나
자동 실행 아님(2 touchpoint)'으로 정합. '세 번째 게이트 아님'·'gh는 게이트에
없음'은 유지. plugin.json 2.9.0→2.10.0 + CHANGELOG [2.10.0]. doc-lock 동기화.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## 최종 검증 (전 task 후)

- [ ] **전체 스위트 무회귀.** repo root에서 관련 스위트 실행 — baseline 대비 새 red 0:
  ```bash
  for t in test_setup_qg.sh test_qg_publish_offer.sh test_qg_publish_command.sh \
           test_qg_publish_docs.sh test_pr_understanding_builder_frontmatter.sh \
           test_qg_publish_skill_orchestration.sh test_skill_orchestration.sh \
           test_qg_pipeline_no_gh.sh harness/test_skill_orchestration_behavior.sh; do
    echo "=== $t ==="; bash "plugins/quality-gates/tests/$t"; echo "exit=$?";
  done
  ```
  (작업 전 캡처한 baseline과 비교 — pre-existing red는 무관, 새 red만 문제.)
- [ ] **수동 e2e (spec §10):** (1) bare `/qg` 완료 → offer → "예" → publish preview 진입. (2) `/qg both` 완료 → offer(클릭 1회 추가 확인). (3) trivia → offer 없음. (4) Review iter `Stop` → offer 없음. (5) `DEVBREW_QG_DISABLE_PUBLISH=1 /qg` → offer 없음. (6) artifact prose 한국어-primary 육안.
- [ ] **`/qg` 도그푸드 (권장, subagent-driven).** 이 브랜치에 `/qg`를 돌려 self-review — codex model-diversity가 fail-open을 잡는 선례 다수(sentinel absence 불변식·kill-switch·fail-safe 분기를 특히 볼 것).

## Self-Review (작성자 체크 — 완료)

**1. Spec coverage:** AC1(Final Summary sentinel+offer)=Task 2·3 / AC2(단일 게이트)=Task 2 R6+3 / AC3(예→Skill, floor)=Task 3 / AC4(trivia 미발동)=Task 1 delete+2 부재+3 eligibility / AC5(Stop 미발동)=Task 2 disposition 가드 / AC6(kill switch)=Task 3 Step1 / AC7(AskUserQuestion in allowed-tools + Skill 부재)=Task 3·2 / AC8(consent 무변경)=C2/Task 3 문구 / AC9(Korean law + 헤더 유지)=Task 4 / AC10(NG5 정합)=Task 5 / AC11(version+CHANGELOG)=Task 5 / AC12(stale delete + reset)=Task 1·5 Step9 / AC13(회귀 커버+teeth)=각 task Step. **전 AC에 task 대응.**

**2. Placeholder scan:** 모든 code step에 실제 코드/명령. "적절히/TBD/handle edge cases" 없음. 각 grep-teeth에 mutation step.

**3. Type consistency:** sentinel 경로·마커·`verdict:` 줄은 Global Constraints에서 단일 정의, 전 task 참조(재정의 없음). `publish-eligible.md` 파일명, `DEVBREW_QG_DISABLE_PUBLISH` env, `PR-이해글을 생성해서 게시할까요` offer literal이 Task 간 일치.
