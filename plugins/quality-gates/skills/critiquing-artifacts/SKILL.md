---
name: critiquing-artifacts
description: >
  Critique → revise → re-critique loop for a single NON-CODE artifact
  (doc / spec / plan / config / prose). Triggered by `/qg critique <path>` or a
  natural-language critique intent ("이 설계문서 비평해줘"). An inherit-tier
  critic + adversarial (+ optional codex co-reviewer) review read-only; the
  orchestrator applies fixes and commits each round. Bounded by max-rounds +
  stagnation + kill switch. Not a code gate — code targets route to the normal
  two-gate pipeline.
cost_class: variable
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Agent
  - AskUserQuestion
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect_codex.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/classify_artifact_target.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/artifact_branch_guard.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/artifact_path_auth.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/artifact_change_signal.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/artifact_commit.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/artifact_max_rounds.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_artifact_findings.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/artifact_stagnation.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_artifact_codex_reviewer.sh:*)
---

# Critiquing Artifacts (`/qg critique`)

비-코드 산출물 하나를 대상으로 **비평 → 수정 → 재비평**을 자율 반복한다. 판정은
산문이 아니라 결정론 헬퍼(§10 스키마 위 순수 함수)가 내리고, 리뷰어는 read-only이며
수정·커밋은 이 오케스트레이터(writer)만 한다 (Law 2). 라운드마다 git 커밋으로 버저닝.

모든 스크립트는 `${CLAUDE_PLUGIN_ROOT}/scripts/` 하위. 아래 단계를 **순서대로** 실행한다.

## 진입 게이트 (파일 손대기 전)

### E0 — Preflight (kill switch)

두 kill switch를 존중한다. 켜져 있으면 한 줄 출력 후 즉시 종료(파일 무변경):
- 전역 `DEVBREW_DISABLE_QUALITY_GATES=1` → `> [quality-gates] critique skipped: quality-gates globally disabled.`
- 모드 전용 `DEVBREW_QG_DISABLE_CRITIQUE=1` → `> [quality-gates] critique mode disabled via DEVBREW_QG_DISABLE_CRITIQUE=1.`

### E1 — 대상 해석 + 코드/비-코드 분류

`critique <path>`면 그 경로가 대상. NL 진입이면 대화/컨텍스트에서 단일 대상 경로를
해석한다. 그 경로로:

```
classify_artifact_target.py <path>
```

- `classification: code` → **종료**: `> [quality-gates] '<path>'는 코드 파일로 보입니다. 코드 리뷰는 /qg (Review 게이트)로 실행하세요.` (비-코드 전용 모드라 코드는 자율 커밋 루프에 넣지 않음.)
- `classification: non_code` → 진행.
- `classification: ambiguous` → E3 *이전에* `AskUserQuestion`으로 확인: *"이 파일(`<path>`)을 산출물로 비평할까요? (코드라면 /qg를 쓰세요.)"* — **예** 확인 없이 자율 루프 진입 금지. "아니오"면 종료.

### E2 — 브랜치 안전 (project_dir 좌표 freeze)

```
artifact_branch_guard.sh
```

출력의 `project_dir:`를 이번 파이프라인의 **frozen 좌표**로 삼는다(이후 재계산 금지).
`branch_ok: false`면 종료:
- `reason: detached_head` → `> [quality-gates] detached HEAD — 커밋 대상 브랜치가 없습니다. 브랜치를 체크아웃한 뒤 재실행하세요.`
- `reason: on_default_or_protected_branch` → `> [quality-gates] 현재 '<branch>'는 기본/보호 브랜치입니다. 자율 커밋을 막습니다 — feature/fix 브랜치에서 재실행하세요.`

### E2b — 대상 HEAD-tracked + clean 전제

```
artifact_change_signal.sh <path>
```

`tracked:`와 `changed:` 두 줄을 **모두** 읽는다(순서대로 판정):
- `tracked: false` → **종료**: `> [quality-gates] '<path>'가 아직 커밋되지 않은(untracked) 파일입니다. 먼저 git add+커밋한 뒤 재실행하세요(라운드별 커밋은 HEAD-tracked 기준선 대비 diff을 커밋합니다).` (`git diff --quiet HEAD`는 untracked 경로를 보지 못해 `changed: false`로 오독될 수 있으므로 — E2b는 `tracked:`를 먼저 판정해 이 오독을 구조적으로 차단한다.)
- `tracked: true` AND `changed: true`(HEAD 대비 uncommitted 변경 존재) → **종료**: `> [quality-gates] '<path>'에 커밋되지 않은 변경이 있습니다. 먼저 커밋/stash 후 재실행하세요(라운드별 커밋 무결성 — pre-existing 변경이 라운드-1 커밋에 섞이지 않도록).`
- `tracked: true` AND `changed: false` → 진행.

### E3 — Upfront 동의 게이트

먼저 한도를 계산한다:

```
artifact_max_rounds.sh
```

`effective_max_rounds:` 값을 읽어(= env clamp, 기본 5) **동의 문구와 루프 한도로 동일하게
사용**한다(동의 범위 = 실행 범위; consent-integrity). `AskUserQuestion`:

> *"대상 = `<path>`, 최대 `<effective_max_rounds>`라운드 비평-수정 루프를 브랜치 `<branch>`에 라운드별 커밋하며 실행할까요?"* — 옵션: **실행** / **대상 변경**(→ E1 재진입) / **취소**.

이 게이트는 N을 되묻지 않는다(값은 고지). cost_class=variable(worst-case high)이라 이
upfront 게이트가 지출-전 명시 승인이다.

## 루프 (라운드 N = 1..effective_max_rounds)

라운드당 디스패치 ≤3(critic + 조건부 codex + adversarial), 최대 동시 실행 2(critic ∥ codex;
adversarial는 병합 후 순차) — 어느 쪽이든 Fan-out factor N≥5 hard gate 미해당. 누적(3×N)은
순차 실행이라 subagent spray 아님.

**1. critic** — `artifact-critic` 디스패치(read-only). 프롬프트에 frozen `project_dir` +
   `artifact_path` 스레딩. 출력 `findings:` YAML을 scratch `critic.yaml`에 저장.

```
Agent({
  subagent_type: "quality-gates:artifact-critic",
  description: "Artifact critique round N",
  prompt: "project_dir: <project_dir>\nartifact_path: <path>\n현재 커밋된 산출물을 비평하고 §10 Finding YAML을 emit하라."
})
```

**2. codex co-reviewer (조건부)** — `detect_codex.sh`로 가용성 확인:
- `codex_available: true` → `run_artifact_codex_reviewer.sh <path> <project_dir> <codex.yaml>`.
  - 출력이 `codex_failed: true`면 **가용 판정 후 런타임 실패**: `> [quality-gates] codex 가용 판정 후 런타임 실패(<reason>) — degraded, inherit-tier 단독.` (crash 아님, C7) codex.yaml은 병합에서 제외.
- `codex_available: false` → **미가용**: `> [quality-gates] codex 미가용(<skip_reason>) — inherit-tier 단독 비평.` (위 런타임-실패 문구와 **구분**된 별도 라인.)

**2.5 merge + key** — critic(+가용·성공 시 codex) findings를 dedup하고 dedup_key를 주입:

```
synthesize_artifact_findings.py --phase key --findings critic.yaml [--findings codex.yaml] > merged.yaml
```

`merged.yaml`의 각 finding은 `dedup_key`를 갖는다(다음 단계 adversarial가 echo).

**3. adversarial** — `artifact-adversarial` 디스패치(read-only). `merged.yaml`을 프롬프트에
   넣어 §10 verdict를 받는다(`finding_key`=각 finding의 `dedup_key`). 출력을 `verdicts.yaml`에
   저장. `project_dir`/`artifact_path` 스레딩. **`merged.yaml`의 keyed 내용(각 finding의
   `dedup_key` 포함)을 프롬프트에 그대로 inline** — 이 스레딩이 빠지면 adversarial이
   `finding_key`를 echo할 수 없어 모든 finding이 미판정(unadjudicated) 처리된다(§10 fail-closed
   경로, Issue 1의 false-convergence 가드가 막아주는 케이스와 직결):

```
Agent({
  subagent_type: "quality-gates:artifact-adversarial",
  description: "Artifact adversarial review round N",
  prompt: "project_dir: <project_dir>\nartifact_path: <path>\n다음은 병합된 keyed findings(merged.yaml)이다 — 각 finding의 dedup_key를 finding_key로 echo하며 §10 verdict(confirm/downgrade/reject)를 매겨라:\n<merged.yaml 전체 내용을 여기 inline>"
})
```

**4. synthesize (결정론)** —

```
synthesize_artifact_findings.py --phase synth --findings merged.yaml --adversarial verdicts.yaml
```

출력에서 `converged` / `degraded` / `degraded_reason` / `unadjudicated` / `kept_*` /
`stagnation_keys` / `kept:`를 읽는다.
- `unadjudicated > 0` → loud log: `> [quality-gates] adversarial 미판정 <N>건 — 이번 라운드 편집 제외(fail-closed).`
- `degraded: true` → adversarial가 0-verdict/파싱불가(findings는 있었음), 또는 findings-side
  로드 실패, 또는 손실 있는 phase-key 병합(`degraded_reason: adversarial|findings_load|sources_failed`).
  kept-empty를 수렴으로 읽지 **않는다** → **NEEDS_RESOLUTION**: `AskUserQuestion`으로
  *"이번 라운드 adversarial 판정 실패(사유: `<degraded_reason>`) — 재시도 / 중단?"*
  (false-convergence fail-open 봉쇄). `degraded_reason`을 사용자에게 노출해 원인(adversarial
  실패인지 findings 로드 실패인지 소스 유실인지)을 알린다.

**5. 수렴 체크** — `converged: true`(kept CRITICAL/IMPORTANT == 0, degraded 아님)면 **수렴,
   루프 종료**. SUGGESTION만 남으면 수렴으로 간주(목록만 surface, 수정 안 함). 수렴 판정은
   독립 kept 집합이 결정(오케스트레이터 자기판단 아님 — Law 2).

**6. 수정 적용** — 미수렴이면, 편집 대상 경로를 방어적으로 재확인:

```
artifact_path_auth.py <project_dir> <path>
```

`auth: reject`면 종료(symlink/traversal escape). `auth: ok`면 반환된 `canonical:` 경로를
곧바로(check와 write 사이 다른 도구 호출 없이 — TOCTOU 방지) 대상으로 kept의
CRITICAL/IMPORTANT finding을 해소하도록 `Edit`/`Write`. Finding에는 path 필드가 없고
`proposed_fix` 자유 텍스트에서 경로를 추출하지 않는다(단일-대상 불변).

**6b. 변경 신호 (커밋 *전* — 반드시 여기서 캡처)** —

```
artifact_change_signal.sh <path>
```

`changed:` 값을 기록한다. `changed: false`(편집이 no-op — 모델이 진전 못 냄)면 커밋을
skip한다. *커밋 후엔 워킹트리가 항상 clean이라 이 신호가 무의미해지므로 반드시 커밋 전에
캡처한다*(라운드-2 리뷰가 잡은 block 버그의 fix).

**7. 커밋** (`changed: true`일 때만) —

```
artifact_commit.sh <path> "critique(round N): <해소한 finding 요약>"
```

`committed_sha:`를 라운드 히스토리에 기록. `no_op: true`면 이번 라운드는 커밋 없음으로
기록(SHA 미기재; step 6b가 이미 걸렀어야 하나 방어적 재확인 경로). `error:`면 loud surface
후 루프 중단.

**8. stagnation 체크** —

```
artifact_stagnation.py --this "<이번 stagnation_keys>" --prev "<직전 stagnation_keys>" --changed "<6b changed>"
```

`stagnant: true`면 루프 종료(reason 기록). `--changed`는 반드시 step 6b의 커밋-전 신호를
쓴다.

**9. N+1로 반복** (종료 조건 미충족 시).

## 종료 & 최종 요약 (AC11)

종료(수렴 / max-rounds / stagnation / NEEDS_RESOLUTION-중단 / kill switch) 시 반드시 출력:
- **라운드 히스토리**: 라운드별 kept 요약 + 각 커밋 SHA.
- **종료 사유**: converged / max_rounds(N) / stagnant(reason) / needs_resolution / killed.
- **잔여 kept 집합**(중단 시): 마지막 라운드의 미해소 CRITICAL/IMPORTANT.

## Law 2 보증

critic·adversarial·codex는 read-only(`disallowedTools` / codex `-s read-only`). 수정·커밋은
이 오케스트레이터만. **매 라운드 독립 critic이 게이트**: 라운드 N의 수정을 라운드 N+1의
*독립* critic이 재검토하며, 최종 "수렴"은 마지막 독립 critic 패스의 kept 집합이 결정 —
자기 편집을 자기 판단으로 승인하는 경로가 구조적으로 없다.

## kill switch (보안 컨트롤)

- `DEVBREW_DISABLE_QUALITY_GATES=1` — 전역 즉시 종료(E0).
- `DEVBREW_QG_DISABLE_CRITIQUE=1` — 이 모드만 종료(E0).
- `DEVBREW_DISABLE_QG_CODEX=1` — codex co-review만 skip(`detect_codex.sh` 존중), inherit-tier 단독으로 degrade.
