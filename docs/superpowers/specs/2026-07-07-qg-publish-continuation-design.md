# quality-gates v2.10.0 — 파이프라인 종료 시 publish 이어가기 + PR 한국어 저술 (design)

> **게이트가 끝난 뒤 사람에게 "이 PR 이해글을 이어서 생성·게시할까?"를 묻는 opt-in
> offer를 추가하고, 게시되는 PR 이해글을 한국어-primary로 저술하도록 명시한다.
> publish의 per-run consent·secret-scan 게이트는 그대로 — offer는 두 번째 opt-in이지
> 자동 실행이 아니다.**

- **type:** brainstorming design doc (superpowers 흐름: 이 문서 → spec-reviewer → 사용자 리뷰 → writing-plans)
- **plugin:** `plugins/quality-gates/` (현행 `2.9.0` → `2.10.0`)
- **base:** `main` @ `6dab58e`
- **관련 선행 설계:** `docs/superpowers/specs/2026-07-05-qg-pr-publish-design.md` (v2.9.0 publish 도입)
- **review round 1 반영:** spec-reviewer가 skill→skill 중첩 미검증(a3e98bda) 등 7건 지적 → 메커니즘을
  command-layer 체이닝으로 재설계, Handoff Context 추가, 가드 fail-safe화.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. 확정 결정 (사용자 + review round 1)](#4-확정-결정-사용자--review-round-1)
- [5. 설계 — 동작 (command-layer 체이닝, no skill-nesting)](#5-설계--동작-command-layer-체이닝-no-skill-nesting)
- [6. 발동 조건 (eligible sentinel, fail-safe)](#6-발동-조건-eligible-sentinel-fail-safe)
- [7. 컴포넌트 격리 & 불변식 보존](#7-컴포넌트-격리--불변식-보존)
- [8. Constraints](#8-constraints)
- [9. Files to Modify](#9-files-to-modify)
- [10. Verification Plan](#10-verification-plan)
- [11. Acceptance Criteria](#11-acceptance-criteria)
- [12. Rejected Alternatives](#12-rejected-alternatives)
- [Handoff Context](#handoff-context)
- [13. Metadata](#13-metadata)

## 1. Context / Why

**(ROOT_CAUSE)** v2.9.0에서 `/qg-publish`(PR-이해글 생성·게시)를 도입했지만, 이는 게이트
파이프라인과 **완전히 분리된 수동 커맨드**다(NG5: "manual·non-auto-chained"). 실사용
흐름은 거의 항상 *"게이트 돌리고 → 그 브랜치 PR에 이해글 남기기"* 이므로, 사용자가 매번
`/qg` 뒤에 `/qg-publish`를 **별도로 기억해서 재입력**해야 하는 마찰이 있다.

**해결:** `/qg` 파이프라인이 **끝나는 시점**에, 사람에게 "이어서 PR 이해글을 생성·게시할까?"를
한 번 **offer**한다. "예"면 기존 `publishing-pr-understanding` skill을 그대로 이어서 실행
(그 skill의 preview·secret-scan·informed-consent 게이트는 **무변경**). "아니오"면 종료.
즉 마찰만 없애고 **consent 속성은 100% 보존**한다.

**부차 문제:** 게시되는 PR 이해글의 언어가 지금 *명세되어 있지 않다*. `pr-understanding-builder`
페르소나에 명시적 language law가 없어서 한국어 저술이 **우연**에 의존하고, 고정 스키마
섹션 헤더는 영·한 혼재다(`In one breath`/`Testing`/`Risk & Rollout` vs `지금 어떻게
동작하나`). devbrew 문서 관례(Korean-primary, English-terms-only)와 정합시킨다.

## 2. Goals

- **G1.** `/qg` 파이프라인이 비중단 완료된 뒤, publish 이어가기 여부를 묻는 단일
  `AskUserQuestion` offer를 발동한다. "예" → `publishing-pr-understanding` skill 실행.
- **G2.** offer는 **모든 완료 경로**(bare `/qg`, `/qg both`, 단일 `/qg review`·`/qg runtime`)에서
  **단일 command site**로 일관되게 fire한다 — 파이프라인 내부 게이트 분기별로 흩어지지 않는다.
- **G3.** `pr-understanding-builder`가 PR 이해글을 **한국어-primary**로 저술하도록 페르소나에
  명시적 style law를 추가한다. **G3는 offer 메커니즘(G1/G2/G4)과 파일·의존성이 전혀 겹치지
  않는 독립 변경** — offer feasibility와 무관하게 단독 구현/머지 가능(review c9ca6b6b 반영).
- **G4.** offer 추가로 publish의 per-run consent·secret-scan·멱등 upsert 속성은 **하나도
  바뀌지 않는다**(offer는 GitHub write를 pre-consent하지 않는다).

## 3. Non-goals

- **NG1.** offer의 "예"가 게시를 **자동 승인하지 않는다.** publish skill의 informed-consent
  게이트(exact-bytes preview + 비가역성 고지 + `AskUserQuestion`)는 그대로 두 번째 touchpoint로
  유지된다. offer + consent = 2 touchpoint.
- **NG2.** publish를 "세 번째 게이트"로 만들지 않는다. offer는 게이트가 아니라 게이트 **뒤에**
  얹힌 opt-in 연속일 뿐 — verdict·pass/fail에 영향 없음. `gh`는 여전히 publish skill 스크립트에
  캡슐화되어 있고, **이 설계는 파이프라인·커맨드에 새로운 gh/`Skill` 도달을 더하지 않는다**
  (커맨드의 no-gh는 관례 수준 — 물리 deny 아님; 정확한 불변식은 §7).
- **NG3.** 고정 스키마 섹션 헤더(영문)를 한국어로 번역하지 않는다(스키마 shape·idempotency
  마커·doc-lock 안정성 유지 — G3는 **prose** 언어 law만 추가).
- **NG4.** Review/Runtime 게이트의 verdict 로직·scope·fix-loop을 변경하지 않는다.
- **NG5.** `--publish`/`--no-publish` 같은 인자 표면을 추가하지 않는다(사용자 결정: 모든
  경로에서 묻기 — 인자 플래그 대신 종료 시 단일 offer).
- **NG6.** `quality-pipeline` SKILL의 `allowed-tools`에 `Skill`을 추가하지 않는다 —
  skill→skill 중첩 호출은 이 리포에 전례가 없고(review a3e98bda) 격리 원칙에 어긋난다.
  체이닝은 **검증된 command→skill 패턴**(command 계층)으로만 한다(§5).

## 4. 확정 결정 (사용자 + review round 1)

브레인스토밍 대화에서 확정:

1. **offer 위치 = 파이프라인 종료 시점.** (원래 요청의 "시작 모달 두 번째 문항"에서
   리다이렉트 — "qg가 종료하면 묻는 걸로 변경.") 시작 모달은 `/qg both` 등 인자 경로에
   존재하지 않아 붙일 곳이 없는 반면, 종료 지점은 모든 경로가 공유 + 게이트 결과를 본 뒤
   결정하는 게 맥락상 자연스러움.
2. **모든 완료 경로에서 묻기 (트레이드오프 수용).** `/qg both`의 zero-click happy path에
   클릭 1회가 더해지는 것을 수용. "zero-click" 문구는 *"게이트는 zero-click, publish는
   별도 opt-in"* 으로 정제.
3. **PR 언어 = prose 한국어-primary만 명시 (Option A).** 고정 영문 헤더 유지.

review round 1로 확정:

4. **체이닝 메커니즘 = command-layer(검증된 command→skill), skill→skill 중첩 아님.**
   feasibility 미검증 + 격리 위배(a3e98bda) 회피. offer는 `/qg.md`가 파이프라인 스킬 종료 후
   실행(단일 site).
5. **가드 = fail-safe eligible-sentinel** (default=no-offer; 비중단 완료 시에만 파이프라인이
   sentinel Write). abort/trivia/preflight-fail은 자동으로 offer 미발동(5099daa4·1c1f256c 반영).

## 5. 설계 — 동작 (command-layer 체이닝, no skill-nesting)

**두 계층 분업** — 파이프라인은 "완료 여부"만 신호하고, 커맨드가 offer·체이닝을 소유한다.

**(A) `quality-pipeline` SKILL** — tool-set·gh 도달 **무변경**(`Skill` 미추가).
- **Preflight**: 이번 run 시작 시 stale `publish-eligible.md`(있으면) 삭제 — 직전 run의
  sentinel이 조기-abort run에서 false-offer를 유발하지 않도록.
- **비중단 완료 시에만**: sentinel `.claude/quality-gates/<sid>/publish-eligible.md`를 `Write`.
  기록 지점은 정확히 두 곳: (a) 전체 파이프라인의 `## Final Summary` 렌더 직후 —
  **단, disposition이 `aborted`(사용자 Stop)가 아닐 때만**; (b) 단일 게이트 모드의 verdict
  emit 직후(`/qg review` verdict; `/qg runtime` R6의 clean/FAIL/SKIP_WITH_EVIDENCE
  종결 — 사용자 Stop/abort 제외). sentinel 본문엔 게이트 disposition 한 줄(예:
  `verdict: clean` / `verdict: failed`)을 넣어 커맨드 offer 문구에 재사용.
  - **disposition 도출 규칙(review advisory 반영 — SKILL.md에 리터럴 `disposition` 필드는
    없음).** `## Final Summary`는 게이트별 셀을 독립 렌더한다(`Review gate\t<token>` /
    `Runtime gate\t<token>`). **disposition = `aborted` iff 어느 한 셀의 token이 리터럴
    `aborted…`로 시작**(Review `aborted iter N` / Runtime `aborted`) — 그 외(clean/
    proceeded-with-findings/failed/skipped/SKIP_WITH_EVIDENCE)는 non-aborted → sentinel 기록.
    plan은 이 규칙을 vocabulary 표에서 역추적하지 말고 이대로 배선.
- trivia escape / 사용자 Stop / Preflight P1 kill-switch return / P3 pre-check 하드 abort는
  위 두 지점에 **도달하지 못하므로** sentinel이 없다 → offer 자동 미발동(fail-safe).

**(B) `/qg.md` 커맨드** — 파이프라인 스킬 종료 후 실행되는 **post-pipeline step** 추가.
`/qg.md`는 이미 `Skill`을 갖고 `Skill("quality-gates:quality-pipeline")`을 호출하는 검증된
command→skill 계층이다. publish는 그 뒤의 **두 번째 command→skill**일 뿐(중첩 아님):

1. `DEVBREW_QG_DISABLE_PUBLISH=1`이면 offer skip(+한 줄 loud).
2. `publish-eligible.md` 부재면 offer skip(비완료/abort/trivia — 조용히 종료).
3. sentinel 존재 + kill-switch 미설정이면 offer `AskUserQuestion` 발동:

```
AskUserQuestion({ questions: [{
  question: "게이트 완료 (<verdict from sentinel>) — 이 브랜치의 PR-이해글을 생성해서 게시할까요? (게시 전 미리보기 + 별도 동의가 있습니다.)",
  header: "PR 이해글",
  options: [
    {label: "예, 이어서 생성·게시", description: "publishing-pr-understanding skill 실행 — 미리보기·secret-scan·동의 게이트를 거쳐 게시."},
    {label: "아니오",              description: "여기서 종료. 나중에 /qg-publish로 따로 실행할 수 있습니다."}
  ], multiSelect: false }]})
```

   - **"예"** → `Skill("quality-gates:publishing-pr-understanding")` 호출(인자 없이 = 게시 경로).
     이후는 그 skill이 소유: Preflight → Build → Generate → Scan(FAIL-CLOSED) → Preview →
     **Consent(informed)** → Publish → Report.
   - **"아니오"** → 종료.
   - **graceful floor — 단, 이것이 커버하는 실패는 딱 하나다(review a8af3a4f):** post-pipeline
     블록이 **실행은 되었으나** 두 번째 `Skill(...)` 호출이 *관측 가능하게 에러*(스킬 부재·
     invocation 실패 등)한 경우 — 이때 **crash하지 않고** exact 커맨드 한 줄을 출력한다:
     `> 이어서 게시하려면: /qg-publish` (CLAUDE.md "누락 capability는 downgrade, crash 아님").
   - **§5-B가 커버하지 *못하는* 더 어려운 실패모드:** 하니스가 파이프라인 스킬의 턴 종료 후
     **커맨드 본문에 재진입 자체를 하지 않는** 경우. 그러면 offer·체이닝·이 floor 전부가 같은
     never-executed 블록 안이라 **런타임 catch로 구제 불가**다. 이는 error handling이 아니라
     **build-time 아키텍처 리스크** → **Plan Task 0의 feasibility 게이트**가 사전 검증하고,
     실패 시 catch 추가가 아니라 **command-layer post-step 설계를 폐기**하고 offer를 파이프라인
     SKILL 종결 단계로 이전(+ `/qg-publish` 안내 floor)하는 대안으로 **분기**한다(Handoff
     Context Implicit-context 참조). 즉 §5-B(런타임 floor)와 Task 0(아키텍처 게이트)는 **서로
     다른 실패모드를 담당** — plan-writer는 §5-B를 두 모드 모두의 처리로 오독하면 안 된다.

**qg.md `allowed-tools` 변경**: `AskUserQuestion` **추가**(offer 발동용). `Skill`·`Read`·`Bash`는
이미 존재. → 커맨드는 publish 스킬을 **호출**할 뿐 **gh-특정 grant를 새로 얻지 않는다**(이
설계가 더하는 새 gh/`Skill` 도달은 0; 커맨드의 no-gh는 관례 수준 — 정확한 불변식·기존 bare
`Bash` 단서는 §7).

## 6. 발동 조건 (eligible sentinel, fail-safe)

**default = no-offer.** 파이프라인이 **비중단 완료**를 명시적으로 신호(§5-A: sentinel Write)한
경우에만 커맨드가 offer한다. 이 반전(default-off)이 abort taxonomy를 열거 없이 닫는다:

| 종료 경로 | sentinel | offer |
|---|---|---|
| 전체 파이프라인 정상 완료 (clean / findings / failed / skipped-runtime / SKIP) | 기록됨 | **발동** |
| 단일 `/qg review`·`/qg runtime` 정상 verdict | 기록됨 | **발동** |
| trivia escape (전 게이트 skip) | 미기록(미도달) | 미발동 |
| 사용자 Stop (Review iter/max-iter/Runtime resolve/Retry "Abort retry") | 미기록 | 미발동 |
| Preflight P1 kill-switch return / P3 pre-check 하드 abort | 미기록(미도달) | 미발동 |
| `DEVBREW_QG_DISABLE_PUBLISH=1` | (무관) | 미발동(커맨드가 env 직접 체크) |

실제 PR 존재·gh 인증 여부는 **미리 확인하지 않는다** — offer "예" 이후 publish skill의
기존 Degrade(gh 부재/미인증 → loud artifact-only, PR 부재 → create 경로)가 처리한다
(harness-lightness: 중복 가드 금지, publish가 이미 소유한 로직 재구현 금지).

**advisory (review 반영):** offer 문구에 sentinel의 `verdict`를 끼워 넣으므로, verdict가
`failed`/`SKIP_WITH_EVIDENCE`인 완료에서도 사용자가 상태를 인지한 채 게시를 선택한다
(이해글은 findings-free 서술이라 verdict와 독립 — NG2).

## 7. 컴포넌트 격리 & 불변식 보존

- **gh reach — 이 설계는 새 gh 도달을 추가하지 않는다(정확한 불변식; review 64af83fe 반영).**
  파이프라인 SKILL은 `Skill`/gh를 얻지 않고(NG6), gh는 `publishing-pr-understanding` skill
  스크립트에 캡슐화된 채로다. 커맨드는 그 skill을 **호출**할 뿐 gh-특정 grant를 새로 얻지
  않는다. **단, 과대주장 금지:** `commands/qg.md`는 *이미* bare `"Bash"` grant를 갖고 있어
  (setup-qg.sh·`--reset` 복합 셸·`--gc` python3 실행용, 이 설계 이전부터) 이론상 `gh`를 직접
  부를 수 있다 — 즉 커맨드 계층의 "no gh"는 **물리적 tool-deny가 아니라 관례**다. 따라서 이
  설계가 주장하는 불변식은 좁게: *"이 설계는 파이프라인·커맨드에 **새로운** gh/`Skill` 도달을
  더하지 않는다"* 뿐이다. README "gh는 위 두 **게이트** 어디에도 없다"는 **게이트(리뷰어·
  runtime)** 에 관한 것으로 그대로 참(커맨드는 예나 지금이나 thin dispatcher). qg.md의 bare
  `Bash`를 scoped 패턴으로 좁혀 물리 강제로 승격하는 것은 **별도 hardening**(§8 C7) — 이 설계의
  주장 근거가 아니다.
- **Law 2 (writer ≠ reviewer)** 무변경: 리뷰어 4종 read-only, runtime-verifier sandbox
  executor 유지. offer는 커맨드의 단순 분기라 새 writer/reviewer 축을 만들지 않는다.
- **생성 ↔ 게시 물리 분리** 무변경: `pr-understanding-builder`(tool 0개)가 저술, publish
  skill만 gh 보유. offer는 이 경계를 건드리지 않고 publish skill을 **통째로** 호출.
- **P17 (consent)** 강화: offer(1차) → publish informed-consent(2차). 둘 다 사용자 명시 동의.
  AP2 polite-handoff의 반대 — narrate만 하지 않고 명시 게이트를 띄운다.

## 8. Constraints

- **C1.** offer "예"는 반드시 `Skill("quality-gates:publishing-pr-understanding")`로 위임 —
  커맨드/파이프라인 안에서 gh·게시 로직을 **재구현하지 않는다**(단일 통제 채널; INVARIANT 보존).
- **C2.** publish skill 내부(Preflight~Report)는 이 변경으로 **한 줄도 바뀌지 않는다**(offer는
  호출부만 추가). secret-scan은 여전히 `scan_ok: yes` 리터럴로만 판정 + FAIL-CLOSED.
- **C3.** language law는 `pr-understanding-builder` 페르소나 **텍스트**로만 추가 — 스키마
  블록(마커·헤더·placeholder 순서)은 불변(NG3). persona는 보안-민감 파일이나 이 변경은
  reviewer 규칙 **약화가 아님**(untrusted-input norm·schema·safety law 전부 유지, style law만 추가).
- **C4.** **R5(single-dispatch-per-turn) 스코프 명확화.** 파이프라인 R5는 파이프라인 **자신의**
  스크립트(setup-qg·check-trivia·reviewer dispatch)의 turn 내 중복을 금한다. publish skill은
  파이프라인 스킬이 **완전히 종료해 커맨드로 제어가 돌아온 뒤** 별도 command→skill로 실행되며,
  자신의 독립 Preflight(gh auth·gh-identity — 오늘날 `/qg-publish` 단독 실행과 동일)를 갖는다.
  파이프라인-내부 재dispatch가 아니므로 R5와 충돌하지 않는다(review (c) 반영).
- **C5.** eligible-sentinel은 `.claude/quality-gates/<sid>/` 하위에만 산다(git-ignored, plugin
  namespace). `/qg --reset`의 rm 목록에 추가(stale 누수 방지). 파이프라인은 Preflight서 stale
  삭제 후 완료 시 재기록(§5-A) — sentinel이 항상 이번 run을 반영.
- **C6.** CLAUDE.md: quality-gates를 건드리므로 같은 PR에서 `plugin.json` version bump
  (`2.9.0` → `2.10.0`, minor = 새 표면) + `CHANGELOG.md` `[2.10.0]` 항목.
- **C7 (선택 hardening — 이 설계의 주장 근거 아님).** `commands/qg.md`의 bare `"Bash"` grant를
  scoped 패턴으로 좁히면 §7의 "커맨드 no-gh"를 관례에서 물리 강제로 승격할 수 있다. 단
  **naive drop 금지**: bare `Bash`는 `--gc`의 `python3 qg-gc.py`와 `--reset`의 복합 셸(`SID=…;
  if …; rm -rf`)을 태우므로, 제거하려면 그에 대응하는 scoped `Bash(python3 …qg-gc.py:*)` 등
  패턴을 먼저 추가해야 한다(안 그러면 기존 커맨드 기능이 깨짐). 이는 **분리 가능한 follow-up**로
  두고, 이 PR은 §7의 좁은 불변식("새 gh 도달 없음")만 주장한다 — plan은 원하면 별도 task로 편입.

## 9. Files to Modify

| 파일 | 변경 |
|---|---|
| `skills/quality-pipeline/SKILL.md` | (1) Preflight에 stale `publish-eligible.md` 삭제. (2) `## Final Summary`에서 disposition≠aborted면 sentinel Write; 단일 게이트 verdict emit 지점(§5-A (b))에서도 동일. (3) `description`의 "zero-click" 문구 정제(게이트=zero-click, publish=별도 opt-in). **`allowed-tools` 무변경(`Skill` 미추가)**. |
| `commands/qg.md` | (1) post-pipeline step 추가: sentinel+kill-switch 체크 → offer `AskUserQuestion` → "예" 시 `Skill(publishing-pr-understanding)`, 실패 시 `/qg-publish` fallback 출력. (2) `allowed-tools`에 `AskUserQuestion` 추가. (3) Quick Reference에 종료 offer 한 줄. |
| `agents/pr-understanding-builder.md` | "Audience & plain-language lever" 섹션에 Korean-primary style law 1개 추가(G3 — 독립 변경). |
| `README.md` | NG5/"auto-chain 없음"/"manual" 프레이밍 정제(L136, L151-158): "종료 시 command-layer opt-in offer는 있으나 자동 실행 아님(offer + 자체 consent = 2 touchpoint)". "gh는 게이트에 없다"·"세 번째 게이트 아님"은 **유지**(§7). Hooks/Principles 표에 offer 반영. |
| `skills/publishing-pr-understanding/SKILL.md` | L114 NG5 문구 동기화(manual → "종료 시 command-layer offer로 이어질 수 있으나 자동 실행 아님"). |
| `.claude-plugin/plugin.json` | `version` `2.9.0` → `2.10.0`. |
| `CHANGELOG.md` | `## [2.10.0] — 2026-07-07` Added(종료 offer + language law) / Changed(NG5 정제). |
| `tests/test_skill_orchestration.sh` 또는 `tests/harness/test_skill_orchestration_behavior.sh` | 파이프라인 sentinel-Write 지점 + Preflight stale-delete + `allowed-tools`에 `Skill` **부재** 회귀. |
| `tests/test_qg_publish_command.sh` (또는 신규) | 커맨드 post-pipeline step: offer 리터럴 + `Skill(publishing-pr-understanding)` 위임 + `/qg-publish` fallback + `AskUserQuestion` in allowed-tools. |
| `tests/test_qg_publish_docs.sh` | NG5 정제 문구 doc-lock 동기화. |
| `tests/` (신규 또는 기존 language 테스트) | builder Korean-primary law grep(G3 독립). |

## 10. Verification Plan

- **정적/회귀(결정론):**
  - 파이프라인 SKILL: `## Final Summary` 및 단일 게이트 emit 지점에 `publish-eligible.md`
    Write 리터럴 존재 + Preflight stale-delete 존재 + `allowed-tools`에 `Skill`이 **없음**을
    assert(NG6 회귀 락).
  - 커맨드 SKILL: post-pipeline 블록 내에 offer 질문 리터럴(`PR-이해글을 생성해서 게시할까요`),
    `Skill("quality-gates:publishing-pr-understanding")` 위임, `/qg-publish` fallback, 그리고
    `allowed-tools: AskUserQuestion`이 존재. **grep-teeth: 헤더 아닌 body-unique 문구를 섹션
    윈도우에서 grep + 해당 블록만 삭제한 mutation으로 teeth 증명**([[grep_lock_header_satisfiable]]).
  - `pr-understanding-builder`에 Korean-primary law 리터럴 존재(G3 독립 테스트).
  - NG5 정제 문구가 README·publish SKILL·doc-lock 테스트에서 **동기화**(drift 0).
- **behavioral(가드 — prose-존재 아님):** sentinel 유무로 offer 발동을 검증한다.
  - trivia 입력 → 파이프라인 실행 후 `publish-eligible.md` **부재** assert.
  - Stop-abort 시나리오 → sentinel **부재** assert.
  - 정상 완료 → sentinel **존재** assert(+ `verdict:` 줄 형식).
  - 이는 §5-A 반전(default-off)이 abort 전 분기를 열거 없이 닫음을 실증(review 1c1f256c 반영).
- **기존 스위트 무회귀:** `plugins/quality-gates/tests/` 전체 그린(특히 `test_qg_publish_*`,
  `test_kill_switches.py`, `test_publish_*`).
- **수동 e2e:** (1) bare `/qg` 완료 → offer → "예" → publish preview 진입. (2) `/qg both` 완료
  → offer(클릭 1회 추가 확인). (3) trivia → offer 없음. (4) Review iter `Stop` → offer 없음.
  (5) `DEVBREW_QG_DISABLE_PUBLISH=1 /qg` → offer 없음. (6) artifact prose 한국어-primary 육안.

## 11. Acceptance Criteria

- **AC1.** 전체 파이프라인 비중단 완료 시 `## Final Summary` 렌더 직후 파이프라인이
  `publish-eligible.md`를 기록하고(disposition≠aborted), 커맨드가 offer `AskUserQuestion`을 발동한다.
- **AC2.** 단일 `/qg review`·`/qg runtime` 정상 verdict 경로도 sentinel을 기록하고 동일 offer가
  발동한다.
- **AC3.** offer "예" → 커맨드가 `Skill("quality-gates:publishing-pr-understanding")` 호출;
  "아니오" → 종료. **graceful floor는 "post-step은 실행됐으나 두 번째 `Skill` 호출이 관측
  가능하게 에러"한 경우에 한해** crash 없이 `/qg-publish` 한 줄을 출력한다(§5-B). *커맨드
  재진입 자체가 일어나지 않는* 실패모드는 이 floor가 아니라 Plan Task 0(build-time 게이트)의
  아키텍처 분기가 담당 — 둘은 서로 다른 실패모드다.
- **AC4.** Trivia escape 경로에서 sentinel 미기록 → offer 미발동.
- **AC5.** 사용자 Stop/abort(Review iter·max-iter·Runtime resolve·Retry "Abort retry") 경로에서
  sentinel 미기록 → offer 미발동.
- **AC6.** `DEVBREW_QG_DISABLE_PUBLISH=1`이면 커맨드가 offer를 skip한다.
- **AC7.** `commands/qg.md` `allowed-tools`에 `AskUserQuestion`이 포함되고, **`quality-pipeline`
  `allowed-tools`에는 `Skill`이 없다**(NG6 — 새 gh/`Skill` 도달 없음). *이 AC는 물리적 gh-deny를
  주장하지 않는다* — 커맨드의 기존 bare `Bash`는 이 설계가 바꾸지 않으며, no-gh는 §7의 좁은
  불변식(관례) 수준이다(선택 물리 강제는 C7).
- **AC8.** publish skill의 consent 게이트·secret-scan·멱등 upsert는 무변경 — offer는 GitHub
  write를 pre-consent하지 않는다(publish 진입 후에도 informed-consent가 반드시 fire).
- **AC9.** `pr-understanding-builder` 페르소나에 명시적 Korean-primary style law가 있고, 고정
  영문 섹션 헤더는 유지된다(스키마 shape 불변). **G3는 offer 파일들과 독립적으로 구현·테스트 가능.**
- **AC10.** README + publish SKILL의 NG5/"auto-chain 없음"/"manual" 문구가 "종료 시 command-layer
  opt-in offer는 있으나 자동 실행 아님; 여전히 consent-gated; 세 번째 게이트 아님; gh는 게이트에
  없음"으로 정합된다.
- **AC11.** `plugin.json` = `2.10.0`, `CHANGELOG.md`에 `[2.10.0]` 항목.
- **AC12.** eligible-sentinel은 Preflight서 stale 삭제 후 완료 시 재기록되고 `/qg --reset` rm
  목록에 포함된다(C5) — sentinel이 항상 이번 run을 반영.
- **AC13.** 회귀 테스트가 offer 앵커·`Skill`-부재·sentinel behavioral 가드·language law·NG5
  doc-lock을 커버하고, offer-literal + fallback teeth가 증명된다.

## 12. Rejected Alternatives

- **skill→skill 중첩(파이프라인 `allowed-tools`에 bare `Skill`).** 원설계 1안. 이 리포에
  전례 0, feasibility 미검증, bare grant가 임의 skill 호출을 허용해 격리 원칙 위배, R5·double-
  preflight 미검토(review a3e98bda). → command→skill(검증된 패턴)로 대체.
- **시작 모달의 두 번째 문항 (원래 요청).** `/qg both` 등 인자 경로엔 Decision-1 모달이 없어
  붙일 곳이 없고 intent 상태 배선 필요. 종료 지점 offer가 모든 경로 공유 + context-aware → 채택.
- **offer를 파이프라인 SKILL 내부 종결 단계로.** 파이프라인은 자기 종결에 확실히 도달하지만,
  종결이 여러 분기(Final Summary·단일 게이트 R6 5갈래·`/qg runtime`이 Dispatch Loop 우회)로
  흩어져 offer site가 다중화되고 single-gate exit-site가 SKILL 구조상 모호(review 4541d40c).
  command-layer는 단일 site → 채택. (파이프라인은 sentinel "신호"만 담당.)
- **`--publish`/`--no-publish` 인자 플래그.** 표면 증가. 사용자가 "모든 경로에서 묻기" 선택 →
  단일 offer로 충분 → 거절.
- **offer 없이 자동 publish.** P17 정신·NG5 위반(사람 동의 없이 GitHub write). 거절.
- **스키마 헤더까지 한국어화.** idempotency 마커·doc-lock·스키마 shape 리스크. prose law로
  충분 → 거절(design-lightness).
- **"예" 시 체이닝 없이 `/qg-publish` 안내만.** 가장 약하지만 확실. 사용자 의도("이어서 동작")에
  못 미쳐 **primary로는 거절**하되, **체이닝 불가 시 graceful floor**로 채택(§5-B, AC3).

## Handoff Context

**TL;DR** — `/qg` 파이프라인 완료 시 사람에게 "PR 이해글 이어서 게시?"를 묻고, "예"면 기존
`publishing-pr-understanding` skill을 command-layer(command→skill, 검증된 패턴)로 이어 실행한다.
파이프라인은 tool-set 무변경 + 비중단 완료 시 `publish-eligible.md` sentinel만 Write하고, 커맨드
`/qg.md`가 그 sentinel+kill-switch를 보고 offer→체이닝을 소유한다. 별도로 `pr-understanding-builder`
에 Korean-primary style law를 추가(G3, 독립).

**Implicit context (plan이 알아야 할 것):**
- **Plan Task 0 (feasibility 확인 — 구현 전 게이트).** 커맨드가 파이프라인 스킬 종료 **뒤에**
  post-pipeline 단계(sentinel 읽기 + offer + 두 번째 `Skill` 호출)로 이어지는지 확인. 근거:
  `qg.md`는 이미 멀티-스텝(① setup-qg.sh Bash → ② `Skill(quality-pipeline)`)이라 "커맨드가
  tool 호출 뒤 다음 지시를 계속 실행"은 검증된 동작 — 이를 ③ post-skill 단계로 확장할 뿐.
  **만약** 하니스가 파이프라인 스킬 뒤 커맨드 재진입을 신뢰성 있게 하지 않으면, 대안:
  offer를 파이프라인 종결 단계로 옮기고 "예" 시 `/qg-publish` **안내만**(§5-B floor)으로 강등
  — 어느 쪽이든 skill→skill 중첩은 쓰지 않는다.
- **eligible-sentinel 경로**: `.claude/quality-gates/<sid>/publish-eligible.md`, `<sid>`=
  `$CLAUDE_CODE_SESSION_ID`(파이프라인 state file과 동일 sid). 기존 `publish-active.md`
  sentinel 패턴(post-tool-use.py)과 동일 관례.
- **단일 게이트 emit 지점**: `/qg review`는 Review gate verdict, `/qg runtime`은 R6의
  clean/FAIL/SKIP_WITH_EVIDENCE 종결. plan이 SKILL.md에서 이 정확한 라인을 특정해 sentinel
  Write를 배선해야 함(4541d40c). Stop/NEEDS_RESOLUTION→Stop은 제외.
- **테스트 러너**: python은 `-m unittest`, bash는 repo root 실행. qg는 CI 없음 + main에 일부
  pre-existing red 가능 — 작업 전 baseline 캡처(참조: 프로젝트 메모리).
- **subagent-driven 구현 권장**: 각 task 2단계 리뷰 + whole-branch 리뷰 + `/qg` 도그푸드
  (codex model-diversity가 fail-open 적발 선례 다수).

**Deferred to plan:** 정확한 SKILL.md 편집 라인, sentinel Write의 exact bash, 회귀 테스트
파일 배치·teeth mutation, CHANGELOG/README 문구, version bump commit.

## 13. Metadata

- **author:** Jeongho-K (brainstorming w/ Claude)
- **date:** 2026-07-07
- **plugin version target:** quality-gates `2.10.0`
- **status:** design — **approved (round 4)**, writing-plans handoff 준비됨
- **related principles:** Law 2(격리 무변경), P17(consent 강화), NG5(정제), design-lightness,
  harness-lightness(중복 가드 금지·과대주장 금지), untrusted-input norm(persona 무약화)
- **review history:**
  - round 1 = needs_revise (7 issues: a3e98bda 메커니즘 재설계, be017f45 Handoff 추가,
    4541d40c/5099daa4 가드 fail-safe화, 1c1f256c behavioral 테스트, 9a078c24 fallback,
    c9ca6b6b G3 독립) → 전부 RESOLVED (round-2 verify 확인).
  - round 2 = needs_revise (2 new issues: 64af83fe gh-격리 overclaim → §7/AC7 정직 완화 +
    C7 분리, a8af3a4f §5-B floor vs Task-0 두 실패모드 혼동 → §5-B·AC3 명시 분리) → 반영·RESOLVED.
  - round 3 = needs_revise (1 issue: ad1600e8 — §7/AC7 정정이 NG2·§5-B에 미전파) → 좁은-형태
    통일 + `gh tool을` grep 0 확인 → RESOLVED.
  - round 4 = **approved** (전 이슈 수렴, stagnation false; handoff ready).
- **advisory (non-blocking, plan hygiene):** offer-triggered `Skill(publishing-pr-understanding)`
  dispatch는 `qg-publish.md`의 기존 dispatch와 동일 호출이므로, 두 call site가 drift하지 않도록
  plan이 공유/참조 구조를 고려(Law 3 위생 — 강제 아님).
