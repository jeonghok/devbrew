---
name: reviewing-brief
description: >
  Use this skill to run the Law 2 separated review of an interview brief produced by
  conducting-interview. Three stages in order — directional soundness (Claude +
  codex, reports only), fidelity (isolated critic + codex, fail-closed union), cold
  readback (naive re-read) — plus a deterministic §6 원문 completeness check against
  the state ledger. Hands four artifacts to the interview's Step B proceed gate.
cost_class: high
user-invocable: false
---

# Reviewing Brief (interview 종료 단계)

당신은 `conducting-interview` Step A가 게이트를 통과시킨 brief(payload)에 **분리 리뷰**를 붙이는 중입니다. 축은 둘(충실도·방향성), 담당은 셋 + 별-모델 codex 2회입니다.

**당신(orchestrator)의 책임**: dispatch · 결정론 스크립트 호출 · 결과 표면화 · Step B로 전달. **당신의 책임이 아닌 것**: finding을 임의로 기각하는 것 · 방향을 바꾸는 것 · 리뷰어 대신 판정하는 것.

## kill switch (먼저 확인)

- `DEVBREW_DISABLE_SPEC_DISTILL=1` → 즉시 abort, state 보존. 이 skill에 진입하지 않습니다.
- `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` (v0.24.0 신규) → **파이프라인 전체 skip.** `component: pipeline` / `affected_axis: all` / `verification_status: skipped` record를 남기고 loud advisory 후 Step B로 직행합니다. 조용히 건너뛰지 않습니다:

  > `[spec-distill v0.24.0] brief 리뷰 파이프라인 SKIPPED (DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1) — 충실도·방향성·냉독 전부 미검증. Step B 게이트에서 확인하세요.`

- `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1` → codex 2회 호출만 skip(Claude 리뷰는 정상).
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` → 양쪽 웹 없이 진행 + record.

## 진입 승인 게이트 (`cost_class: high`)

이 skill은 에이전트 3 + codex 2 = 모델 호출 5회를 씁니다. CLAUDE.md 규약대로 **진입 시 1회** 지출 승인을 받습니다. 이 게이트는 **무조건**이며 외부 문서의 미래 결론에 의존하지 않습니다.

```javascript
AskUserQuestion({
  questions: [{
    question: "brief 리뷰 파이프라인을 돌립니다 — 에이전트 3 + codex 2회 (cost_class: high). 진행할까요?",
    header: "Review cost",
    options: [
      {label: "전체 리뷰 진행 (권장)", description: "방향성(Claude+codex) → 충실도(격리 critic+codex) → 냉독. 4개 산출물을 Step B 게이트에 올립니다."},
      {label: "건너뛰고 Step B로", description: "리뷰 없이 진행. skip record가 Step B 게이트 질문에 표시됩니다."}
    ],
    multiSelect: false
  }]
})
```

*"건너뛰고 Step B로"* 선택은 kill switch와 동일 경로입니다 — record + loud advisory 후 Step B. 사용자 주권(P17)이고 polite stop이 아닙니다(게이트를 실제로 띄웠고 사용자가 redirect했으므로).

## 상태

state는 새 파일을 만들지 않고 기존 `.claude/spec-distill/<session-id>/state.local.md`에 키 3개를 씁니다. 훅이 읽는 파일과 **같은 리졸버**로 경로를 구합니다. `$STATE`를 zero-tool 선결 조건보다 먼저 정의하는 이유는 하나뿐입니다 — 아래 probe 실패 분기가 `$STATE`에 쓰므로 그 값이 먼저 있어야 합니다(이 문서 전체가 위에서 아래로 그대로 실행 가능하다는 주장은 아닙니다: `$PAYLOAD`·`$CODEX_DIR_YAML`·`$CODEX_FID_YAML`은 이 skill이 정의하지 않는 입력이고, 호출자 `conducting-interview`가 진입 시점에 이미 쥐고 넘기는 값입니다):

```bash
PR="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
harness_sid="$(python3 "$PR/hooks/state_path.py" session-id)"
ROOT="$(python3 "$PR/hooks/state_path.py" state-root)"
STATE="$ROOT/$harness_sid/state.local.md"
python3 "$PR/scripts/brief_review_state.py" init "$STATE"     # 키 3개 idempotent 추가
```

`init`은 부재 키만 default로 추가합니다(`brief_review_stage: direction` · `brief_critic_rounds: 0` · `brief_review_degradations: []`). 기존 값을 backward-rewrite하지 않습니다. `harness_sid`가 빈 값이면 상태 기록 없이 진행하되 **loud advisory**를 남기고 모든 degrade를 Step B 게이트 텍스트로만 전달합니다(기록 실패를 조용히 삼키지 않습니다).

## zero-tool 격리 선결 조건

`brief-critic`·`brief-readback`의 격리는 **도구 표면으로 성립하거나 성립하지 않습니다.** 판정은 `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`의 `**분기 판정:**` 한 줄입니다. 그 파일이 없거나 판정을 읽을 수 없으면 **파이프라인을 시작하지 않습니다** — probe 미실행 상태로 구현·실행을 진행하지 않습니다(AC2b).

probe는 세 조건을 **적대적으로** 확인한 것입니다: **P1** agent 정의가 resolve·dispatch된다 · **P2** 알려진 canary 파일을 읽으라는 명시적 지시에 도구 호출이 불가·거부된다 · **P3** 트랜스크립트 census로 실제 도구 목록이 빈 것을 확인(자기보고 불신). P1만 통과한 것은 *"로드됐다"* 이지 *"도구가 없다"* 가 아닙니다.

#### probe 통과 분기 (`ZERO_TOOL_OK`)

critic·readback이 `tools: []`이므로 audit 도달 경로가 물리적으로 없습니다. 충실도 verdict는 **hard gate**입니다 — `fidelity_verdict: needs_revise`면 3단계로 넘어가지 않고 수정 경로를 탑니다. D2 충족.

#### probe 실패 분기 (`ZERO_TOOL_UNAVAILABLE`)

critic·readback이 `tools: Read`를 유지하므로 격리가 **보장되지 않습니다.** 그러면 충실도 verdict를 **advisory**로 내립니다 — findings를 Step B에 올리고 사용자가 판정하며, 파이프라인을 자동 차단하지 않습니다. 독립성이 보장되지 않는 리뷰어의 판정으로 차단하면 담보하는 것이 없는데 담보하는 척하는 것입니다.

이 분기에서는 아래 두 호출로 **record 2건**을 남깁니다(양쪽 도구가 함께 되돌아가므로 냉독의 *순진함* 전제도 같은 원인으로 훼손됩니다 — gap 판정을 그만큼 낮게 읽어야 합니다):

```bash
BRS="python3 $PR/scripts/brief_review_state.py"
$BRS degrade-append "$STATE" --component critic   --axis fidelity \
    --status degraded --reason "zero-tool 불가 — 격리 미보장"
$BRS degrade-append "$STATE" --component readback --axis readback \
    --status degraded --reason "zero-tool 불가 — 격리 미보장"
```

그리고 **D2(payload 파일 하나만 받는다는 구조 조건) 미충족을 조용히 넘기지 않고** C4 경로로 사용자에게 보고합니다(Step B 게이트 question 텍스트).

## 진입 첫 액션 — 원문 완전성 (§6 ↔ state 원장)

```bash
python3 "$PR/scripts/check_verbatim_coverage.py" "$PAYLOAD" "$STATE"; rc=$?
```

파이프를 걸지 마세요 — `| tail`을 붙이면 `$?`가 파이프 마지막 명령의 코드가 되어 죽은 스크립트가 성공으로 읽힙니다(리포 실측).

| rc | 뜻 | 동작 |
|---|---|---|
| `0` | 위반 없음 | 1단계로 |
| `exit 1` | 위반 발견(`missing_ids`/`not_contained`) | **차단.** §6를 보완(추가만 — 아래 append-only)하고 `check_brief.py gate` → 이 검사를 **재실행**. 리뷰 단계로 넘어가지 않습니다 |
| `exit 3` | 검사 불가(파일 부재·파싱 실패) | degrade 후 계속 + record(`component: verbatim_coverage`, `affected_axis: completeness`, `verification_status: skipped`) |
| `exit 4` | 내부 오류 | `3`과 동일 처리 + 오류 전문을 `--reason`에 |
| 그 외 non-zero | 예측 못 한 실패 | `3`과 동일 취급 — indeterminate ≠ clean |

**왜 진입에 두는가**: §6가 불완전하면 방향성 리뷰도 불완전한 문서를 보고, critic은 §6를 ground truth로 쓰므로 판정 자체가 무의미해집니다. §6에 append가 일어날 때마다 **재실행**합니다.

## 수정 권한 (모든 단계 공통)

| 섹션 | 권한 |
|---|---|
| §0 / §1 / §3 / §4 / §5 / §7 | 자유 수정 |
| §2 제약 | 자유 수정 — **단 frontmatter `user_sourced_items`와 동시**(bijection B가 statement 내용까지 대조하므로 한쪽만 고치면 게이트 red) |
| **§6 사용자 원문** | **append-only.** `S<N>` 항목 **추가**만 허용, 기존 항목 본문 변경 금지(P21 placeholder 치환만 예외) |

§6를 자유롭게 고칠 수 있으면 *critic이 지적 → 원문을 지적에 맞게 고쳐 통과* 라는 laundering이 열립니다. 추가는 덮어쓰기가 아니므로 provenance가 온전히 남습니다.

**저자는 어느 리뷰어의 finding도 임의로 기각하지 못합니다.** 미반영 findings는 **이유와 함께 Step B 게이트에서 사용자에게 올립니다**(P17) — 저자의 자기승인 경로를 차단합니다.

## 1단계 — 방향성 (C4 경로)

방향성이 먼저인 이유: 방향성 지적은 사용자 재결정을 유발하고, 재결정이 나면 §2 제약·§3 OQ가 바뀝니다. 충실도를 먼저 수렴시키면 그 수렴이 무효화됩니다. **충실도는 문서가 더 이상 바뀌지 않는 시점에 봅니다.**

```bash
python3 "$PR/scripts/brief_review_state.py" set-stage "$STATE" direction
```

### 1-a. 웹 예산 확인 (dispatch 전 check)

```bash
python3 "$PR/scripts/web_budget.py" check "$STATE"; web_rc=$?
```

`brief-direction-reviewer`는 `tools:`에 `Bash`가 **없습니다**(Law 2) — 자기 예산을 확인할 경로가 없으므로 판정은 **orchestrator 책임**입니다. 리뷰어에게 `Bash`를 주는 것은 Law 2 위반이므로 대안이 아닙니다.

- `web_rc == 0` → 평소대로 dispatch.
- `web_rc != 0`(소진) → dispatch 프롬프트에 *"웹 없이 repo + payload 근거로 답하라"* 조건을 실어 dispatch하고 record(`component: direction_reviewer`, `affected_axis: direction`, `verification_status: degraded`, reason=*"웹 예산 소진 — repo 근거만"*). **codex #1의 웹은 이 카운터 밖이라 살아 있습니다** — 외부 근거가 완전히 죽지 않습니다(이중화).
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` → 양쪽 웹 없이 + record.

dispatch 후 1회 increment:

```bash
python3 "$PR/scripts/web_budget.py" increment "$STATE"
```

> ⚠️ **계측은 dispatch 단위입니다.** 리뷰어 turn *내부*의 개별 `WebSearch`/`WebFetch` 호출 수는 리뷰어도(`Bash` 없음) orchestrator도(subagent 내부 도구 호출을 볼 수 없음) 셀 수 없습니다. 그래서 `SESSION_CAP = 8`은 이 컴포넌트에 대해 *"검색 8회"* 가 아니라 **dispatch 8회**입니다. 프롬프트로 검색 횟수를 묶는 것은 E10 위반이므로 대안이 아닙니다.

### 1-b. direction-reviewer dispatch (경로 전달 — 이 축은 근거 폭이 본질)

```javascript
Agent({
  description: "Brief direction review",
  subagent_type: "spec-distill:brief-direction-reviewer",
  prompt: `Review the interview brief at <PAYLOAD_PATH> for directional soundness.
Read the repository and search the web. Answer both axis-(b) questions with evidence.
Every finding must carry exactly one question for the user to decide.
<웹 예산 소진 시: "Do not use the web this run — answer from the repository and the brief alone.">`
})
```

### 1-c. codex #1 (방향성 축)

```bash
codex_avail="$(bash "$PR/scripts/detect_codex.sh" | sed -n 's/^codex_available: //p')"
if [[ "$codex_avail" == "true" ]]; then
  bash "$PR/scripts/run_brief_codex_reviewer.sh" direction "$PAYLOAD" "$(pwd)" "$CODEX_DIR_YAML"
else
  : # skip + record(component: codex, affected_axis: all, verification_status: skipped)
fi
```

codex 부재 시 loud advisory:

> `[spec-distill v0.24.0] codex 방향성 co-review SKIPPED (reason: <skip_reason>) — Claude-only, 모델 다양성 없음 (degraded).`

**축은 죽지 않습니다** — Claude 담당자가 남습니다. 이것이 3-에이전트 분리(E3)의 배당금입니다.

`codex_avail == true`였는데도 `$CODEX_DIR_YAML`에 `codex_failed: true`가 남으면 (timeout·exec 실패·`payload_missing` 등 러너 자체의 런타임 실패) record(`component: codex`, `affected_axis: direction`, `verification_status: degraded`)를 남깁니다 — `codex_avail`은 pre-flight **부재**만 잡고, 이 케이스는 2-b가 fidelity 축에서 잡는 것과 대칭인 **런타임 실패**입니다.

### 1-d. 보고 (병합 없음)

**방향성은 병합하지 않습니다** — verdict가 없고 산출물이 *사용자에게 낼 질문*이라 합칠 대상이 없습니다. 두 리뷰어의 항목을 **나란히** 제시하고, 같은 지적이 겹치면 합쳐 보여줍니다(문구가 달라 결정론 dedup은 불가하며 모델 판단에 맡깁니다 — 판단이 틀리면 사용자가 중복을 보거나 하나를 놓칩니다, spec §11 ⑤).

각 항목은 `<출처(Claude|codex)> — <무엇을 뒤집자는 것인가> — <근거 URL/file:line> — <사용자가 결정할 질문>`.

사용자가 방향을 뒤집으면(C4 재결정):

1. `user_sourced_items`의 해당 항목 `status` 변경 또는 항목 교체.
2. 그 **결정 발화를 §6에 새 `S<N>`으로 추가**합니다(기존 항목 수정이 아닙니다). state의 `user_statements`에도 append되므로 다음 완전성 검사가 대조 대상으로 삼습니다.
3. 뒤집힌 방향은 §5 `기각` 항목에 *무엇을 왜 버렸는지* 로 남깁니다 — **증거 문장**이며 권위 문장이 아닙니다(C5).
4. payload 재저장 → `check_brief.py gate` 재실행 → `check_verbatim_coverage.py` 재실행.

리뷰어는 방향을 **바꾸지 않습니다.** 사용자에게 올리고 사용자가 결정합니다(D5b·P17).

## 2단계 — 충실도 (fail-closed 합집합)

```bash
python3 "$PR/scripts/brief_review_state.py" set-stage "$STATE" fidelity
```

### 2-a. critic dispatch 블록

프롬프트에 **payload 전문을 inline**합니다. 경로를 주지 않습니다 — 이 축은 문서 **내부 대조**이고 외부 정보가 오염원입니다. blob은 빌더가 만듭니다(frontmatter의 `audit_file`·`name`·`created_at` 세 값을 `<redacted>`로):

```bash
BLOB="$(python3 "$PR/scripts/build_brief_inline_blob.py" "$PAYLOAD")"; blob_rc=$?
```

`blob_rc == 2`면 payload가 없거나 사용법 오류입니다 — 빈 `<brief>`로 critic을 dispatch하면 indeterminate를 clean으로 오독하는 fail-open이므로 **critic을 dispatch하지 않습니다.** record(`component: critic`, `affected_axis: fidelity`, `verification_status: unavailable`)를 남기고 Step B로 조기 보고합니다. `blob_rc == 3`이면 본문에 위생 미달 잔존이 있다는 뜻입니다 — 원문 보존이 우선이라 지우지 않고 record(`component: critic`, `affected_axis: fidelity`, `verification_status: degraded`)를 남기고 계속합니다.

```javascript
Agent({
  description: "Brief fidelity critic",
  subagent_type: "spec-distill:brief-critic",
  prompt: `Review this interview brief for fidelity — did the §2 summary distort,
drop, or invent what the user said in §6? Check all six categories explicitly.
Emit **Status:** on its own line, then the brief-critic-issues block.

<brief>
${BLOB}
</brief>`
})
```

critic의 raw 출력을 **요약·바꿔쓰기 없이 그대로** `CRITIC_OUT="$ROOT/$harness_sid/brief-critic-raw.txt"`에 저장합니다 — `$STATE`와 같은 세션 디렉토리(`.claude/spec-distill/<session-id>/`) 아래라 plugin state 배치 규약(P13)과 정합합니다. 파싱은 병합 스크립트가 그 파일에서 수행합니다(orchestrator가 category/target_section을 전사하면 안 됩니다).

### 2-b. codex #2 (충실도 축) + 병합

```bash
bash "$PR/scripts/run_brief_codex_reviewer.sh" fidelity "$PAYLOAD" "$(pwd)" "$CODEX_FID_YAML"
python3 "$PR/scripts/merge_brief_review.py" \
    --critic-output "$CRITIC_OUT" --codex-yaml "${CODEX_FID_YAML:-/nonexistent}"
```

codex #2는 **항상 최종 문서를 봅니다** — stale이 원리적으로 불가능합니다.

병합 stdout의 키를 그대로 씁니다: `fidelity_verdict` · `critic_verdict` · `codex_verdict` · `critic_verdict_unrecoverable` · `codex_isolated` · `codex_degraded` · `fidelity_findings` · `advisory[]`. `advisory[]`는 사용자에게 **그대로** 표시합니다.

`codex_degraded: true`이면 (`run_brief_codex_reviewer.sh`가 timeout·exec 실패·`payload_missing` 등으로 fallback YAML을 낸 경우) record(`component: codex`, `affected_axis: fidelity`, `verification_status: degraded`)를 남깁니다 — 1-c의 `affected_axis: all` record는 codex가 애초에 **없는** 케이스만 다루고, 이 record는 codex가 있었는데 **이 라운드에 실패한** 케이스를 다룹니다. 이걸 남기지 않으면 merge 스크립트의 `advisory[]`에만 흔적이 남고 AC15의 degrade 원장에는 흔적이 남지 않습니다.

**권위 계약** — codex는 advisory가 아니라 **binding**입니다. 어느 리뷰어든 Issues를 내면 `needs_revise`이고, codex 단독으로도 verdict가 만들어집니다. `codex_isolated: false`는 **verdict 입력이 아니라 저자용 라벨**입니다 — 이 finding은 프레이밍을 흡수한 리뷰어가 낸 것일 수 있으니 그 가능성을 함께 고려하라는 뜻이고, **등급을 낮추는 근거가 아닙니다.**

`critic_verdict_unrecoverable: true`이고 `codex_degraded: true`면 **approved로 해소하지 않고** 사람에게 올립니다(round-4에서 실측된 verdict 소실의 봉쇄).

### 2-c. 충실도 루프 전이

`fidelity_verdict`가 `needs_revise`면 수정하고 **fresh critic 재리뷰 1회는 구조적으로 필수**입니다(E8 — writer가 자기 수정을 승인하는 경로 차단). 재dispatch **전에** 게이트를 통과해야 합니다:

```bash
python3 "$PR/scripts/brief_review_state.py" can-redispatch "$STATE"; can=$?
if [[ "$can" -eq 0 ]]; then
  python3 "$PR/scripts/brief_review_state.py" bump-critic-round "$STATE"   # 재dispatch 허용된 시점에만 +1
  # ... fresh critic 재dispatch
else
  : # can == 1 → escalate. 더 이상 재dispatch 없음 — Step B forced escalate로 수렴
fi
```

`can == 0`일 때만 카운터를 올리고 재dispatch합니다 — 분기를 주석 하나로 서술하지 않고 `if`로 명시하는 이유는, escalate 경로에서 실수로 카운터가 한 번 더 올라가는 shape을 애초에 봉쇄하기 위해서입니다(clamp가 상한 초과는 막아도, 게이트를 거치지 않고 bump가 실행되는 모양 자체는 AC13이 load-bearing으로 보는 지점입니다).

| # | 상태 | 이벤트 | 동작 | `brief_critic_rounds` |
|---|---|---|---|---|
| 1 | 2단계 진입 | critic #1 dispatch (+ codex #2 병렬) | 병합 → `fidelity_verdict` | **0 유지** — 최초 리뷰는 *재*라운드가 아니다 |
| 2 | `approved` | — | 3단계로 | 0 유지 |
| 3 | `needs_revise` | 저자가 허용 행위로 수정 | **fresh critic 재dispatch 필수** | +1 → 1 |
| 4 | 재리뷰 `approved` | — | 3단계로 | 1 유지 |
| 5 | 재리뷰 `needs_revise`, 카운터 1 | orchestrator 판단 → 수정 + 재dispatch | fresh critic 재dispatch | +1 → 2 |
| 6 | 카운터 `== 2` **이고** Issues 잔존 | — | **Step B forced escalate** | 2 고정 |

**경계값**: escalate는 `== 2`에서 발화합니다(`> 2`를 기다리지 않습니다). fresh 재dispatch는 **최대 2회**이고 critic dispatch 총계는 최대 3회입니다. 카운터는 **수정 후 재dispatch 시점에** 증가합니다(리뷰 결과 수신 시점이 아닙니다).

**상한 불변식**: 어떤 전이도 카운터를 2 초과로 만들지 않습니다. 따라서 3 이상은 도달 불가능한 손상 상태이며 스크립트가 2로 clamp하고 advisory를 냅니다(escalate로 수렴).

**행 6에 도달하면 record를 남깁니다**: `component: critic`, `verification_status: degraded`, reason=*"재리뷰 상한 2 초과, 미해결 findings 잔존"*.

**orchestrator의 허용 행위 — 닫힌 열거:**

| | 행위 |
|---|---|
| ✅ | §0·§1·§2·§3·§4·§5·§7 수정 (§2는 frontmatter와 동시) |
| ✅ | §6에 `S<N>` **추가** |
| ✅ | 미반영 findings를 **이유와 함께** Step B로 이월 |
| ❌ | finding 임의 기각 |
| ❌ | §6 기존 항목 본문 변경 |
| ❌ | 상한을 넘긴 추가 재dispatch |

**충실도에 라운드 루프를 두지 않는 이유**: `reviewing-spec`의 라운드 루프 + cap 5는 design doc 리뷰가 *설계 결함*을 찾는 반복 개선이라 정당합니다. 충실도는 *"§2 요약이 §6 원문을 왜곡했나"* 라는 좁고 거의 기계적인 축이라 반복 수렴 대상이 아닙니다 — 루프는 trivia ceremony입니다.

## 3단계 — 냉독 (advisory 측정)

```bash
python3 "$PR/scripts/brief_review_state.py" set-stage "$STATE" readback
```

문서가 더 이상 바뀌지 않는 시점의 문서를 읽어야 측정에 의미가 있습니다 — 그래서 마지막입니다.

### 3-a. readback dispatch 블록

```bash
BLOB="$(python3 "$PR/scripts/build_brief_inline_blob.py" "$PAYLOAD")"; blob_rc=$?
```

`blob_rc == 2`면 payload가 없거나 사용법 오류입니다 — 빈 `<document>`로 dispatch하지 않습니다. record(`component: readback`, `affected_axis: readback`, `verification_status: unavailable`)를 남기고 Step B로 조기 보고합니다. `blob_rc == 3`이면 본문에 위생 미달 잔존이 있다는 뜻입니다 — 이 라운드는 그대로 dispatch하되, 그 함의는 3-b에서 다룹니다.

```javascript
Agent({
  description: "Brief cold readback",
  subagent_type: "spec-distill:brief-readback",
  prompt: `Read this document cold and say back, in plain prose, what you
understood: what it is trying to do, what is settled and what is still open, and
what happens next. Nothing else.

<document>
${BLOB}
</document>`
})
```

프롬프트에 판정 기준·출력 형식·검사 항목을 **주지 않습니다.** 형식 자체가 오염원입니다(Spec A 인터뷰에서 **실측**: 시범 에이전트가 문서 안의 red-flag 기준을 읽고 그 답을 회피했다고 스스로 보고했습니다). 구조화는 받는 쪽이 합니다.

출력이 비거나 실패하면 record(`component: readback`, `affected_axis: readback`, `verification_status: unavailable`)를 남깁니다 — **"gap 0"으로 읽지 않습니다**(indeterminate ≠ clean).

### 3-b. gap 대조 (요약 ↔ payload)

받은 산문 요약을 payload의 §0/§1/§2/§3/§7과 대조해 gap을 분류합니다. **닫힌 다섯 클래스**입니다:

| # | gap 클래스 | 판정 |
|---|---|---|
| G1 | **미결을 확정으로 읽음** — §3 OQ 항목을 결정된 것으로 요약 | 요약에 그 OQ가 결정으로 등장 |
| G2 | **확정을 미결로 읽음** — `status: confirmed` 항목을 열린 것으로 요약 | 요약에 그 제약이 미결/후보로 등장 |
| G3 | **최상위 제약 누락** — 최상위 항목의 내용이 요약에 없음 | 해당 id의 내용이 요약에 부재 |
| G4 | **Goal ↔ Non-goal 반전** — §1의 Non-goal을 goal로(또는 역) 요약 | 방향이 뒤집힌 서술 존재 |
| G5 | **다음 행동 오독** — §7 Next Action과 다른 다음 단계를 서술 | 요약의 next step ≠ §7 |

**성공 조건**: G1–G5 **전부 0건**이면 readback pass. 1건 이상이면 그 항목을 Step B 게이트에 **세 조각**으로 올립니다 — *어느 클래스 / 요약의 어느 문장 / payload의 어느 절*.

3-a에서 `blob_rc == 3`이었던 라운드는 redaction되지 않은 audit 파일명이 본문에 그대로 남아 있었다는 뜻입니다 — 냉독 에이전트가 문서 메타데이터(파일명 규약)까지 함께 봤을 수 있으므로, 그 라운드의 gap 판정은 **신뢰도 하향**으로 읽습니다(zero-tool 격리 미보장 분기와 동일한 원인의 신뢰도 저하).

**이 판정은 advisory입니다** — pass/fail이 파이프라인을 차단하지 않고 사용자가 최종 판정합니다. 프레시 에이전트는 *잘못 재구성된* payload도 정확히 요약할 수 있습니다 — 원래 의도와 비교할 독립 ground truth가 없으므로 hard verdict로 쓰면 false block이 납니다.

여섯 번째 클래스가 실제로 관측되면 **여기에 추가하는 것이 compounding 이벤트**입니다(Law 3).

## Step B로 전달

```bash
python3 "$PR/scripts/brief_review_state.py" set-stage "$STATE" done
python3 "$PR/scripts/brief_review_state.py" get "$STATE"     # degradations 회수
```

`conducting-interview` Step B의 proceed 게이트에 **네 가지**를 싣습니다:

1. 확정 후보 목록(기존 B-0 프로즈).
2. **방향성 C4 항목** — 출처 라벨 + 사용자가 결정할 질문.
3. **readback 요약 전문 + gap 목록**(세 조각 형식).
4. **모든 degrade record** — `AskUserQuestion`의 **question 텍스트에** 각 record를 한 줄로. 옵션 description이 아니라 question 본문이어야 사용자가 옵션을 고르기 *전에* 봅니다. 배열이 비면 `degrade 없음`을 한 줄로 명시합니다(침묵과 구분).

**리뷰 생략 방지의 실제 메커니즘이 이 전파입니다.** 결정론 체크가 아닙니다 — 게이트는 *존재*만 보고 사용자는 *내용*을 보므로 사람이 더 강한 백스톱이며, 그래서 *"리뷰 라운드 기록이 있는가"* 같은 이빨 없는 검사를 넣지 않습니다(검사 대상이 통과 조건을 직접 쓰므로).

미반영 findings는 **이유와 함께** 여기 올립니다 — 저자는 어느 리뷰어의 finding도 임의로 기각하지 못합니다(AC7b).

## audit 텔레메트리

`templates/interview-audit-template.md` §4·§5에 리뷰 라운드 기록을 남깁니다(순수 텔레메트리 → audit, D1의 분할선과 정합). 이것은 **기록**이고 게이트 통과 조건이 아닙니다.
