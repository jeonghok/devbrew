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

당신은 `conducting-interview` Step A가 게이트를 통과시킨 brief(payload)에 **분리 리뷰**를 붙이는 중입니다. 축은 둘(충실도·방향성), 담당은 셋 + 별-모델 codex입니다 — 수정 없는 경로에서 에이전트 3 + codex 2회이고, 충실도 수정 라운드마다 둘이 함께 재실행되어 **상한은 에이전트 5 + codex 4회**입니다.

**당신(orchestrator)의 책임**: dispatch · 결정론 스크립트 호출 · 결과 표면화 · Step B로 전달. **당신의 책임이 아닌 것**: finding을 임의로 기각하는 것 · 방향을 바꾸는 것 · 리뷰어 대신 판정하는 것.

## kill switch (먼저 확인)

- `DEVBREW_DISABLE_SPEC_DISTILL=1` → 즉시 abort, state 보존. 이 skill에 진입하지 않습니다.
- `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` (v0.24.0 신규) → **파이프라인 전체 skip.** `component: pipeline` / `affected_axis: all` / `verification_status: skipped` record를 남기고 loud advisory 후 Step B로 직행합니다. 조용히 건너뛰지 않습니다:

  > `[spec-distill v0.24.0] brief 리뷰 파이프라인 SKIPPED (DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1) — 충실도·방향성·냉독 전부 미검증. Step B 게이트에서 확인하세요.`

- `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1` → codex 호출만 skip(Claude 리뷰는 정상). `detect_codex.sh`가 이 스위치를 `codex_available: false`로 옮기고, **codex를 부르는 지점 전부**(1-c 방향성 · 2-b 충실도 · 2-c 충실도 재실행)가 같은 `$codex_avail`로 게이트됩니다. 러너(`run_brief_codex_reviewer.sh`)는 이 변수를 보지 않습니다 — 게이트는 **호출자 책임**입니다(`run_spec_codex_reviewer.sh`와 같은 규약). 한 지점이라도 게이트 밖이면 사용자 opt-out이 무시된 채 외부 모델에 지출이 나가고, 아래 `affected_axis: all` record가 거짓이 됩니다.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` → 양쪽 웹 없이 진행 + record.

## 진입 승인 게이트 (`cost_class: high`)

이 skill의 지출은 **하한 5 / 상한 9 모델 호출**입니다.

| | 에이전트 dispatch | codex 실행 |
|---|---|---|
| 하한 (수정 없는 경로) | 3 — direction 1 · critic 1 · readback 1 | 2 — 방향성 1 · 충실도 1 |
| 재리뷰 라운드마다 (2-c, 최대 2 라운드) | +1 (fresh critic) | +1 (충실도 재실행) |
| **상한** | **5** | **4** |

재dispatch 상한 2가 이 표의 마지막 행을 묶습니다(2-c). CLAUDE.md 규약대로 **진입 시 1회** 지출 승인을 받고, 승인 질문에는 하한이 아니라 **상한**을 싣습니다 — 사용자가 승인하는 것은 실제로 나갈 수 있는 최대치여야 합니다. 이 게이트는 **무조건**이며 외부 문서의 미래 결론에 의존하지 않습니다.

```javascript
AskUserQuestion({
  questions: [{
    question: "brief 리뷰 파이프라인을 돌립니다 — 에이전트 3 + codex 2회로 시작하고, 충실도 수정이 일어나면 상한 에이전트 5 + codex 4회 (cost_class: high). 진행할까요?",
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
# 두 번째 채널. 경로는 **세션의 순수 함수**여야 한다 — 어느 블록이 언제 재도출해도 같은
# 파일을 가리켜야 하기 때문이다. `$$`(PID)는 Bash 호출마다 달라 재발견이 불가능하고,
# `: >`(truncate)는 이 블록을 다시 실행할 때마다 그때까지 쌓인 record를 지운다.
# 그래서 truncate하지 않고 **touch**만 하며, fallback 경로도 sid로 결정한다.
DEGRADE_FALLBACK_FILE="$ROOT/$harness_sid/brief-degrade-fallback.txt"
touch "$DEGRADE_FALLBACK_FILE" 2>/dev/null \
  || DEGRADE_FALLBACK_FILE="${TMPDIR:-/tmp}/brief-degrade-fallback.${harness_sid:-nosid}.txt"
python3 "$PR/scripts/brief_review_state.py" init "$STATE"; init_rc=$?   # 키 3개 idempotent 추가
```

`init`은 부재 키만 default로 추가합니다(`brief_review_stage: direction` · `brief_critic_rounds: 0` · `brief_review_degradations: []`). 기존 값을 backward-rewrite하지 않습니다. `harness_sid`가 빈 값이면 상태 기록 없이 진행하되 **loud advisory**를 남기고 모든 degrade를 Step B 게이트 텍스트로만 전달합니다(기록 실패를 조용히 삼키지 않습니다).

### 기록 경로가 죽었을 때 (두 번째 채널)

`brief_review_state.py`의 쓰기 서브커맨드는 state가 부재·판독 불가·쓰기 불가·frontmatter 손상일 때 **exit 1 + `{"ok": false, "reason": …}`** 를 냅니다. 빈 `harness_sid`만 실패 원인인 것이 아닙니다. 종료 코드를 안 보면 이렇게 됩니다: `init`이 실패하면 이후 `degrade-append`가 전부 실패하고 마지막 `get`도 실패해, *"모든 degrade를 Step B에 올린다"* 는 요구가 조용히 **"degrade 0건 표시"** 가 됩니다 — 기록이 없는 것과 degrade가 없는 것이 구분되지 않습니다(indeterminate ≠ clean).

그래서 **state는 유일한 채널이 아닙니다.** 규칙 둘:

1. `init_rc != 0`이면 `component: pipeline` / `affected_axis: all` / `verification_status: degraded` advisory를 그 자리에서 loud하게 냅니다(state에 못 쓰므로 record는 아래 2의 사본으로만 남습니다):

   > `[spec-distill v0.24.2] brief 리뷰 state 기록 불가 (<init이 낸 실제 reason>) — degrade 원장이 이 세션에 없습니다. 아래 record는 이 턴 안에서 Step B 질문 텍스트로 직접 전달됩니다.`

2. **모든** `degrade-append` 호출은 종료 코드를 그 자리에서 잡고(파이프 금지 — 진입 첫 액션과 같은 이유), non-zero면 그 record를 `$DEGRADE_FALLBACK_FILE`에 한 줄로 **이어 붙입니다**(`>>`):

   ```bash
   ... degrade-append ... || echo "- (state 기록 실패) component=<c> axis=<a> status=<s> reason=<r>" >> "$DEGRADE_FALLBACK_FILE"
   ```

   **셸 변수가 아니라 파일인 이유**: `Bash` 도구는 호출마다 **새 셸**입니다 — 유지되는 것은 cwd뿐이고
   변수·`export`는 소멸합니다(실측). `$PR`·`$ROOT`·`$STATE`처럼 환경의 순수 함수인 값은 각 블록에서
   다시 계산하면 되지만, 이 채널은 여러 블록에 걸쳐 record를 모으는 **누산기**라 재도출이 불가능합니다.
   변수로 두면 매 append가 빈 값에서 시작해 Step B에서 비어 있고, 원장이 죽었을 때만 작동하는 백업이
   침묵하므로 그 침묵이 그대로 `degrade 없음`으로 렌더됩니다.

Step B로 전달할 때는 `get`의 `brief_review_degradations`와 `$DEGRADE_FALLBACK_FILE`의 줄들을 **합쳐서** 싣습니다. `get` 자체가 실패하면(`ok: false`) 원장 쪽은 비어 있는 것이 아니라 **알 수 없는** 것이므로, `degrade 없음`이라고 쓰지 않고 그 사실을 한 줄로 명시합니다.

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
    --status degraded --reason "zero-tool 불가 — 격리 미보장" \
    || echo "- (state 기록 실패) component=critic axis=fidelity status=degraded reason=zero-tool 불가 — 격리 미보장" >> "$DEGRADE_FALLBACK_FILE"
$BRS degrade-append "$STATE" --component readback --axis readback \
    --status degraded --reason "zero-tool 불가 — 격리 미보장" \
    || echo "- (state 기록 실패) component=readback axis=readback status=degraded reason=zero-tool 불가 — 격리 미보장" >> "$DEGRADE_FALLBACK_FILE"
```

그리고 **D2(payload 파일 하나만 받는다는 구조 조건) 미충족을 조용히 넘기지 않고** C4 경로로 사용자에게 보고합니다(Step B 게이트 question 텍스트).

## 진입 첫 액션 — 원문 완전성 (§6 ↔ state 원장)

```bash
python3 "$PR/scripts/check_verbatim_coverage.py" "$PAYLOAD" "$STATE"; rc=$?
```

파이프를 걸지 마세요 — `| tail`을 붙이면 `$?`가 파이프 마지막 명령의 코드가 되어 죽은 스크립트가 성공으로 읽힙니다(리포 실측).

| rc | 뜻 | 동작 |
|---|---|---|
| `0` | 위반 없음 | 1단계로. **단 `advisories`가 비어 있지 않으면** 그 줄들을 record(`component: verbatim_coverage`, `affected_axis: completeness`, `verification_status: degraded`)로 남기고 Step B에 함께 올립니다 |
| `exit 1` | 위반 발견(`missing_ids`/`not_contained`) | **차단.** §6를 보완(추가만 — 아래 append-only)하고 `check_brief.py gate` → 이 검사를 **재실행**. 리뷰 단계로 넘어가지 않습니다 |
| `exit 1` + `not_contained: ["§6"]` | **구조 위반** (§6 `S<N>` 앵커 중복) | **차단.** append로는 고칠 수 없습니다 — 잘못 추가된 중복 항목을 **제거**해야 합니다(중복 자체가 append-only 위반이고, 남겨두면 어느 쪽이 원문인지 확정되지 않습니다) |
| `exit 3` | 검사 불가(파일 부재·파싱 실패) | degrade 후 계속 + record(`component: verbatim_coverage`, `affected_axis: completeness`, `verification_status: skipped`) |
| `exit 4` | 내부 오류 | `3`과 동일 처리 + 오류 전문을 `--reason`에 |
| 그 외 non-zero | 예측 못 한 실패 | `3`과 동일 취급 — indeterminate ≠ clean |

**rc 0에 `advisories`가 실리는 이유**는 검사가 *"이 발화는 대조하지 못했다"* 를 말할 수 있기 때문입니다(P21 placeholder가 걸친 span, state 쪽 redaction 등). rc만 보고 payload를 버리면 그 사실이 사라져 **강등이 통과로 보입니다** — 강등이 사람에게 닿지 않으면 그것은 강등이 아니라 통과입니다.

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

### 1-a. kill switch 확인 (dispatch 직전)

```bash
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  web_disabled=1
else
  web_disabled=0
fi
```

`brief-direction-reviewer`는 `tools:`에 `Bash`가 **없습니다**(Law 2) — 자기 kill switch를 확인할 경로가 없으므로 판정은 **orchestrator 책임**입니다. 리뷰어에게 `Bash`를 주는 것은 Law 2 위반이므로 대안이 아닙니다.

- `web_disabled == 0` → 평소대로 dispatch.
- `web_disabled == 1` → dispatch 프롬프트에 *"웹 없이 repo + payload 근거로 답하라"* 조건을 실어 dispatch하고 record(`component: direction_reviewer`, `affected_axis: direction`, `verification_status: degraded`, reason=*"web kill switch 활성 — repo 근거만"*). **codex #1의 웹은 자기 실행(`run_brief_codex_reviewer.sh`의 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 분기)에서 같은 스위치를 독립 확인합니다** — 외부 근거가 완전히 죽지 않습니다(이중화).

이 축의 web 호출에는 사전 예산 상한이 없습니다(v0.24.12 — S3d, harness-capability-suppression-sweep). 프롬프트로 검색 횟수를 묶는 것은 E10 위반이므로 대안이 아닙니다.

### 1-b. direction-reviewer dispatch (경로 전달 — 이 축은 근거 폭이 본질)

```javascript
Agent({
  description: "Brief direction review",
  subagent_type: "spec-distill:brief-direction-reviewer",
  prompt: `Review the interview brief at <PAYLOAD_PATH> for directional soundness.
Read the repository and search the web. Answer both axis-(b) questions with evidence.
Every finding must carry exactly one question for the user to decide.
<kill switch 활성 시: "Do not use the web this run — answer from the repository and the brief alone.">`
})
```

**출력을 그대로 쓰지 않고 먼저 결정론적으로 검증합니다.** 이 리뷰어의 계약 산출물은 `brief-direction-findings` 센티널 블록입니다(agent 정의 frontmatter). 냉독(3-a)의 빈 출력이 명시적으로 degrade되는 것과 **대칭**으로 처리합니다:

| 관측 | 판정 |
|---|---|
| 센티널 블록이 있고 항목 0건 | 유효한 *"지적 없음"*. 그대로 1-c로 진행 |
| 출력이 비었다 · 센티널 블록이 없다 · 블록이 깨져 항목을 읽을 수 없다 | **"지적 없음"으로 읽지 않습니다.** record(`component: direction_reviewer`, `affected_axis: direction`, `verification_status: unavailable`, reason=관측한 사실 그대로) |

없는 판정과 *"없다는 판정"* 은 다른 사실입니다(indeterminate ≠ clean). 이 record가 없으면, 리뷰어가 죽고 codex #1도 없는(kill switch·미설치·스키마 파손) 라운드에서 **방향성 축이 통째로 미검증인데 원장에는 아무 흔적이 없는** 상태가 만들어집니다 — Step B 사용자는 그 축이 검토됐다고 읽게 됩니다. 두 담당이 함께 죽은 라운드는 그 사실을 Step B 질문 텍스트에 한 줄로 명시합니다.

### 1-c. codex #1 (방향성 축)

<!-- codex-gate:begin runner=run_brief_codex_reviewer.sh -->
```bash
# 두 필드를 한 번에 포착한다. `codex_available`만 뽑고 `skip_reason`을 버리면 아래
# advisory 템플릿의 `(reason: <skip_reason>)`을 렌더할 값이 없다(사용자는 이유 없는
# "SKIPPED"만 본다). detect_codex.sh 출력은 한 번만 받아 두 값을 함께 읽는다.
DETECT_OUT="$(bash "$PR/scripts/detect_codex.sh")"
codex_avail="$(sed -n 's/^codex_available: //p' <<<"$DETECT_OUT")"   # 판정 1회 — 2-b·2-c가 이 값을 재사용
skip_reason="$(sed -n 's/^skip_reason: //p' <<<"$DETECT_OUT")"
# "감지기를 못 돌렸다"와 "codex가 없다"를 구별한다: 정상 실행된 감지기는 항상 exit 0
# 이고 codex_available: 줄을 낸다(false 여도). 그 줄이 없으면 감지기 자체가 안 돈
# 것이다(빈 stdout·비-zero exit·심볼릭 링크 끊김) — 아래 advisory가 skip_reason:
# unknown으로 뭉개지 않도록 여기서 명시적으로 채운다. `codex_avail` 만으로 가드한다
# (I6: `&& -z "$skip_reason"`는 rc 를 안 잡고 잘린 출력을 빠져나가게 뒀다 — 정본은
# 성공 실행 시 항상 exit 0 이므로 `-z "$codex_avail"` 단독이 산문과 정확히 일치한다).
if [[ -z "$codex_avail" ]]; then skip_reason="detector_not_runnable"; fi
if [[ "$codex_avail" == "true" ]]; then
  bash "$PR/scripts/run_brief_codex_reviewer.sh" direction "$PAYLOAD" "$(pwd)" "$CODEX_DIR_YAML"; runner_rc=$?
  # 러너는 fail-closed 산출물을 **쓰지 못하면** exit 3으로 죽는다(쓰기 불가·디렉토리 부재).
  # 그 경우 직전 라운드 YAML이 그대로 남아 이번 라운드 판정으로 읽히므로, 잔존물을
  # 제거하고 degraded로 기록한다 — 부재는 아래 양성-마커 규칙이 degraded로 잡는다.
  if [[ "$runner_rc" -eq 3 ]]; then rm -f "$CODEX_DIR_YAML"; fi
else
  : # skip + record(component: codex, affected_axis: all, verification_status: skipped)
fi
```
<!-- codex-gate:end -->

codex 부재 시 loud advisory:

> `[spec-distill v0.24.0] codex 방향성 co-review SKIPPED (reason: <skip_reason>) — Claude-only, 모델 다양성 없음 (degraded).`

**축은 죽지 않습니다** — Claude 담당자가 남습니다. 이것이 3-에이전트 분리(E3)의 배당금입니다.

`codex_avail`은 **여기서 한 번만** 구하고 2-b·2-c가 같은 값을 재사용합니다. `affected_axis: all`(양 축 모두 skip)이 참인 근거가 바로 이 공유입니다 — 충실도 쪽 호출이 게이트 밖에 있으면 원장에는 *"codex가 양 축에서 없었다"* 가 남는데 실제로는 codex가 충실도를 봤다는, 기록이 거짓이 되는 상태가 됩니다. 그래서 `skipped` record는 이 한 곳에서만 남기고, 2-b·2-c는 중복 record 없이 같은 게이트만 다시 겁니다.

방향성 축은 병합 스크립트가 없으므로(§"방향성은 병합하지 않습니다") `$CODEX_DIR_YAML`을 **성공 마커 양성 요구**로 읽습니다 — `meta.codex_failed: false`가 **있어야** 정상이고, 파일 부재·0바이트·잘림·판독 불가·`codex_failed: true`는 **전부** degraded입니다. `codex_failed: true`가 "없는지"만 보면 그 술어에 fail-closed 보수가 없어 부재·0바이트·직전 라운드 잔존이 모두 "정상"으로 읽힙니다(fidelity 축은 `merge_review.py`가 같은 opt-in-to-success 규칙을 이미 문서화하고 있습니다). `codex_avail == true`였는데 양성 마커가 없으면 (timeout·exec 실패·`payload_missing` 등 러너 자체의 런타임 실패) record(`component: codex`, `affected_axis: direction`, `verification_status: degraded`)를 남깁니다 — `codex_avail`은 pre-flight **부재**만 잡고, 이 케이스는 2-b가 fidelity 축에서 잡는 것과 대칭인 **런타임 실패**입니다.

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

`blob_rc == 2`면 payload가 없거나 사용법 오류·읽기 실패(비-UTF-8·권한)입니다 — 빈 `<brief>`로 critic을 dispatch하면 indeterminate를 clean으로 오독하는 fail-open이므로 **critic을 dispatch하지 않습니다.** record(`component: critic`, `affected_axis: fidelity`, `verification_status: unavailable`)를 남기고 Step B로 조기 보고합니다. `blob_rc == 3`이면 본문에 위생 미달 잔존이 있다는 뜻입니다 — 원문 보존이 우선이라 지우지 않고 record(`component: critic`, `affected_axis: fidelity`, `verification_status: degraded`)를 남기고 계속합니다. **`0`·`3`이 아닌 그 외 non-zero는 `2`와 동일하게 취급합니다 — dispatch하지 않습니다**(표에 없는 코드를 "계속"으로 흘리면 `${BLOB}`이 빈 문자열인 채 프롬프트에 보간돼 critic이 빈 문서를 리뷰하고 "왜곡 없음"을 보고합니다; indeterminate ≠ clean).

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
if [[ "${codex_avail:-}" == "true" ]]; then
  bash "$PR/scripts/run_brief_codex_reviewer.sh" fidelity "$PAYLOAD" "$(pwd)" "$CODEX_FID_YAML"
else
  : # skip — 1-c의 affected_axis: all record가 이 축까지 덮는다(중복 record 없음)
fi
python3 "$PR/scripts/merge_brief_review.py" \
    --critic-output "$CRITIC_OUT" --codex-yaml "${CODEX_FID_YAML:-/nonexistent}"
```

**병합은 skip 라운드에도 그대로 돕니다.** codex YAML이 없으면 병합이 `codex_degraded: true` + advisory로 그 부재를 loud하게 보고하고, critic 판정이 살아 있으면 `approved`를 막지 않습니다(양쪽 판정 불가일 때만 escalate). 그래서 게이트를 건다고 kill switch가 강제 수정 루프로 바뀌지 않습니다.

codex #2는 **항상 최종 문서를 봅니다** — stale이 원리적으로 불가능합니다. 그 불가능성을 만드는 것은 서술이 아니라 2-c입니다: payload가 수정되는 모든 라운드에서 codex #2와 구조 게이트를 **수정된 바이트에 다시 돌립니다.** 재실행이 없으면 이 문장은 거짓이 되고, 충실도 verdict는 **서로 다른 두 버전의 문서**에서 계산한 합집합이 되어 합집합의 보장을 잃습니다.

병합 stdout의 키를 그대로 씁니다: `fidelity_verdict` · `critic_verdict` · `codex_verdict` · `critic_verdict_unrecoverable` · `codex_isolated` · `codex_degraded` · `fidelity_findings` · `advisory[]`. `advisory[]`는 사용자에게 **그대로** 표시합니다.

`codex_avail == true`였는데도 `codex_degraded: true`이면 (`run_brief_codex_reviewer.sh`가 timeout·exec 실패·`payload_missing` 등으로 fallback YAML을 낸 경우) record(`component: codex`, `affected_axis: fidelity`, `verification_status: degraded`)를 남깁니다 — 1-c의 `affected_axis: all` record는 codex가 애초에 **없는**(kill switch 포함) 케이스만 다루고, 이 record는 codex가 있었는데 **이 라운드에 실패한** 케이스를 다룹니다. `codex_avail == false`인 라운드에도 병합은 YAML 부재를 `codex_degraded: true`로 보고하지만 그건 skip의 결과이므로 여기서 record를 **중복으로 남기지 않습니다**(1-c의 `all`이 이미 덮습니다). 이걸 남기지 않으면 merge 스크립트의 `advisory[]`에만 흔적이 남고 AC15의 degrade 원장에는 흔적이 남지 않습니다.

**권위 계약** — codex는 advisory가 아니라 **binding**입니다. 어느 리뷰어든 Issues를 내면 `needs_revise`이고, codex 단독으로도 verdict가 만들어집니다. `codex_isolated: false`는 **verdict 입력이 아니라 저자용 라벨**입니다 — 이 finding은 프레이밍을 흡수한 리뷰어가 낸 것일 수 있으니 그 가능성을 함께 고려하라는 뜻이고, **등급을 낮추는 근거가 아닙니다.**

`critic_verdict_unrecoverable: true`이고 `codex_degraded: true`면 **approved로 해소하지 않고** 사람에게 올립니다(round-4에서 실측된 verdict 소실의 봉쇄).

### 2-c. 충실도 루프 전이

`fidelity_verdict`가 `needs_revise`면 수정하고 **fresh critic 재리뷰 1회는 구조적으로 필수**입니다(E8 — writer가 자기 수정을 승인하는 경로 차단). 재dispatch **전에** 게이트를 통과해야 합니다:

```bash
# (1) 구조 게이트 재실행 — payload를 고쳤으면 무조건. 값싸고 결정론적입니다.
python3 "$PR/scripts/check_brief.py" gate "$PAYLOAD"; gate_rc=$?
if [[ "$gate_rc" -ne 0 ]]; then
  echo "[spec-distill v0.24.1] 구조 회귀 — 충실도 수정이 frontmatter/섹션 구조를 깨뜨렸다 (Law 1). 재리뷰·재병합으로 넘어가지 않는다; 구조를 먼저 고치고 이 블록을 처음부터 다시 탄다." >&2
  exit 1
fi
# (2) §6에 S<N>을 추가한 라운드면 원문 완전성도 재실행 (진입 첫 액션과 같은 규칙)
python3 "$PR/scripts/check_verbatim_coverage.py" "$PAYLOAD" "$STATE"; vc_rc=$?
# 차단 행은 **실행형**이어야 한다. 대입만 하고 흘려보내면 서술만 차단이고 실행은 통과다 —
# 바로 위 gate_rc가 같은 이유로 실행형 if를 갖는다. 확정 §6 원문 위반이 여기서 안 멈추면
# can-redispatch → bump → 재리뷰로 흘러가 approved가 날 수 있다.
if [[ "$vc_rc" -eq 1 ]]; then
  echo "[spec-distill] §6 원문 완전성 위반 — 충실도 수정이 원장 대조를 깨뜨렸다. 재리뷰·재병합으로 넘어가지 않는다; §6를 보완하고 이 블록을 처음부터 다시 탄다." >&2
  exit 1
fi

CAN_OUT="$ROOT/$harness_sid/brief-can-redispatch.json"
python3 "$PR/scripts/brief_review_state.py" can-redispatch "$STATE" > "$CAN_OUT"; can=$?
if [[ "$can" -eq 0 ]]; then
  python3 "$PR/scripts/brief_review_state.py" bump-critic-round "$STATE"   # 재dispatch 허용된 시점에만 +1
  # ... fresh critic 재dispatch (2-a 블록 그대로, $CRITIC_OUT 덮어쓰기)
  # (3) codex #2도 **수정된 바이트**에 다시 돌린 뒤 재병합한다 — 게이트 통과 후, 이 분기 안에서만
  if [[ "${codex_avail:-}" == "true" ]]; then
    bash "$PR/scripts/run_brief_codex_reviewer.sh" fidelity "$PAYLOAD" "$(pwd)" "$CODEX_FID_YAML"; runner_rc=$?
    if [[ "$runner_rc" -eq 3 ]]; then rm -f "$CODEX_FID_YAML"; fi   # stale 잔존 방지 (위 1-c와 같은 이유)
  else
    : # skip — 1-c의 affected_axis: all record가 이 라운드까지 덮는다
  fi
  MERGE_OUT="$ROOT/$harness_sid/brief-merge.out"
  python3 "$PR/scripts/merge_brief_review.py" \
      --critic-output "$CRITIC_OUT" --codex-yaml "${CODEX_FID_YAML:-/nonexistent}" > "$MERGE_OUT"; merge_rc=$?
  # 이 파일의 다른 결정론 호출은 전부 rc 표를 갖는데 merge만 없었다 — 그 stdout이
  # 2-c 분기 전체가 읽는 verdict인데도. non-zero **또는 빈 stdout**이면 판정이 계산되지
  # 않은 것이다: `fidelity_verdict` 없이 아래 분기로 내려가면 존재하지 않는 키를 읽는다.
  # **빈 stdout 절반이 핵심**이다 — 잘린 write는 exit code로 잡히지 않는다.
  cat "$MERGE_OUT"        # 판정을 **눈으로 볼 수 있게** 되돌린다 — rc를 잡으려고 파일로
                          # 리다이렉트만 하고 아무도 열지 않으면, 2-c(=needs_revise → approved
                          # 전이가 일어나는 바로 그 라운드)의 verdict가 보이지 않는다.
  if [[ "$merge_rc" -ne 0 || ! -s "$MERGE_OUT" ]]; then
    : # record(component: pipeline, affected_axis: fidelity, verification_status: unavailable,
      # reason="merge rc=$merge_rc, 출력 $( [[ -s "$MERGE_OUT" ]] && echo 있음 || echo '비어 있음(잘린 write)' )")
      # 후 Step B로 상신한다. 계산되지 않은 verdict는 approved가 아니다.
  fi
else
  # can == 1은 **두 가지 다른 사실**을 싣고 온다. `escalate` 키로 가른다 —
  # 실패 페이로드({"ok": false, "reason": …})에는 이 키가 아예 없다.
  if grep -q '"escalate": true' "$CAN_OUT"; then
    : # 상한 도달 → Step B forced escalate. record(component: critic, affected_axis: fidelity,
      # verification_status: degraded, reason "재리뷰 상한 2 초과, 미해결 findings 잔존")
  else
    : # state 실패(부재·판독 불가·손상) → 상한과 무관하다. record(component: pipeline,
      # affected_axis: fidelity, verification_status: unavailable, reason=$CAN_OUT의 실제 reason)
  fi
fi
```

**(1) 구조 게이트는 경고가 아니라 차단입니다.** `gate_rc != 0`이면 블록이 `exit 1`로 **거기서 멈춥니다** — 뒤의 `check_verbatim_coverage.py`·`can-redispatch`·`bump-critic-round`·재dispatch가 하나도 실행되지 않습니다. 이유를 변수에만 담고 흘려보내면 서술만 차단이고 실행은 통과입니다(이 파일의 이전 판이 정확히 그 shape이었고, 대입한 변수를 읽는 곳이 리포 전체에 0곳이었습니다). 충실도 수정이 만든 frontmatter·섹션 구조 위반은 **새로 생긴 Law 1 실패**이고, 그것을 안고 진행하면 Step B는 *"구조 게이트가 통과했다"* 를 거짓으로 보고하게 됩니다. 게이트가 초록이 된 뒤 이 블록을 처음부터 다시 탑니다. `vc_rc`는 진입 첫 액션과 **같은 표**(`0` 진행 / `1` 차단 / `3`·`4`·그 외 non-zero는 degrade 후 계속 + record)로 처리합니다.

**(3) codex #2 재실행이 필수인 이유.** 충실도 verdict는 critic과 codex findings의 **fail-closed 합집합**입니다. 두 입력이 서로 다른 버전의 문서에서 나오면 그 합집합은 어느 한 버전에 대해서도 완전하지 않습니다 — 합집합이 주는 보장 자체가 사라집니다. 그리고 codex는 binding이므로, 수정이 새로 만든 왜곡을 codex가 보지 못한 채 승인이 나올 수 있습니다. 재실행 비용은 이미 재dispatch 상한 2가 묶고 있으므로 무한 루프가 되지 않습니다(critic·codex 각각 최대 3회 = 최초 1 + 재2). `$CRITIC_OUT`·`$CODEX_FID_YAML`은 라운드마다 **덮어씁니다** — 이전 라운드의 산출이 남으면 그게 곧 stale입니다. 재실행 라운드에도 2-b의 `codex_degraded` record 규칙이 그대로 적용됩니다. 그리고 이 재실행도 **2-b와 같은 `$codex_avail` 게이트 안**에 있습니다 — 게이트 없이 돌면 사용자 opt-out이 하필 재실행 경로로 새어나가고, 라운드마다 외부 모델 지출이 반복됩니다.

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

**단 그 reason은 `can-redispatch`가 exit 1을 낸 *모든* 경우의 설명이 아닙니다.** 이 서브커맨드는 escalate(상한 도달)와 state 실패(`_fail` — 부재·판독 불가·손상)에 **같은 코드 1**을 씁니다. 코드만 보고 escalate로 단정하면, state가 죽었을 뿐인 라운드에 *"재리뷰 상한 2 초과, 미해결 findings 잔존"* 이라는 **사실이 아닌** record가 원장에 들어갑니다(카운터가 2에 도달한 적이 없어도). 두 사실은 stdout의 `escalate` 키로 갈립니다 — escalate 페이로드에는 `"escalate": true`가 있고 실패 페이로드에는 그 키 자체가 없습니다. 위 2-c 블록의 중첩 `if`가 그 분기입니다.

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

`blob_rc == 2`면 payload가 없거나 사용법 오류·읽기 실패(비-UTF-8·권한)입니다 — 빈 `<document>`로 dispatch하지 않습니다. record(`component: readback`, `affected_axis: readback`, `verification_status: unavailable`)를 남기고 Step B로 조기 보고합니다. `blob_rc == 3`이면 본문에 위생 미달 잔존이 있다는 뜻입니다 — 이 라운드는 그대로 dispatch하되, 그 함의는 3-b에서 다룹니다. **`0`·`3`이 아닌 그 외 non-zero는 `2`와 동일하게 취급합니다 — dispatch하지 않습니다**(냉독은 빈 문서를 받으면 "이해할 내용이 없다"가 아니라 그럴듯한 무내용 요약을 낼 수 있어 gap 판정 자체가 무의미해집니다).

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
python3 "$PR/scripts/brief_review_state.py" get "$STATE"; get_rc=$?   # degradations 회수
```

`conducting-interview` Step B의 proceed 게이트에 **다섯 가지**를 싣습니다:

1. 확정 후보 목록(기존 B-0 프로즈).
2. **방향성 C4 항목** — 출처 라벨 + 사용자가 결정할 질문.
3. **readback 요약 전문 + gap 목록**(세 조각 형식).
4. **모든 degrade record** — `AskUserQuestion`의 **question 텍스트에** 각 record를 한 줄로. 옵션 description이 아니라 question 본문이어야 사용자가 옵션을 고르기 *전에* 봅니다. 배열이 비면 `degrade 없음`을 한 줄로 명시합니다(침묵과 구분). 원천은 **둘**입니다 — `get`의 `brief_review_degradations` **와** `$DEGRADE_FALLBACK_FILE`의 줄들(state 기록이 실패한 record의 두 번째 채널 — 셸 변수는 Bash 호출 간 소멸하므로 파일이어야 합니다). 둘을 합쳐 싣습니다. `get_rc != 0`이면 원장은 *비어 있는* 것이 아니라 *알 수 없는* 것이므로 `degrade 없음` 대신 `degrade 원장 판독 불가 — <get이 낸 실제 reason>`을 한 줄로 명시합니다.
5. **critic 원문 전문(`$CRITIC_OUT`)** — 병합 결과(`fidelity_verdict` · `fidelity_findings`)와 **나란히** 올립니다. `brief-critic`은 `tools: []`이라 자기 출력을 파일로 쓸 수 없어 전사는 **저자**가 합니다(격리의 대가입니다 — 채널 자체는 없앨 수 없습니다). 그래서 `codex_degraded`인 라운드에서는 충실도 판정이 *저자가 쓴 파일 하나*에 얹힙니다. 원문을 함께 올리면 사용자가 전사본과 파싱된 판정을 직접 대조할 수 있습니다 — 검증 불가능한 프로즈 의무를 사람이 실제로 확인 가능한 것으로 바꾸는 장치이고, 아래 "실제 메커니즘은 이 전파"와 같은 백스톱입니다.

**리뷰 생략 방지의 실제 메커니즘이 이 전파입니다.** 결정론 체크가 아닙니다 — 게이트는 *존재*만 보고 사용자는 *내용*을 보므로 사람이 더 강한 백스톱이며, 그래서 *"리뷰 라운드 기록이 있는가"* 같은 이빨 없는 검사를 넣지 않습니다(검사 대상이 통과 조건을 직접 쓰므로).

미반영 findings는 **이유와 함께** 여기 올립니다 — 저자는 어느 리뷰어의 finding도 임의로 기각하지 못합니다(AC7b).

## audit 텔레메트리

`templates/interview-audit-template.md` §4·§5에 리뷰 라운드 기록을 남깁니다(순수 텔레메트리 → audit, D1의 분할선과 정합). 이것은 **기록**이고 게이트 통과 조건이 아닙니다.
