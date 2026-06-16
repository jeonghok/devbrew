# spec-distill SessionStart anchor 훅 제거 (v0.16.0)

> `/interview resume`는 더 이상 존재하지 않는다. 그 죽은 명령을 매 세션 시작마다 안내하던
> SessionStart `session-anchor.sh` 훅을 완전히 제거해, live 플러그인의 stale advisory와
> 마지막 resume 잔재를 닫는다(아카이브 plan 문서의 역사적 언급은 NG5로 제외).

## Context / Why

`hooks/session-anchor.sh`는 SessionStart 훅으로, `.claude/spec-distill/<session-id>/state.local.md`
디렉토리가 남아 있으면 이를 감지해 다음 advisory를 주입한다:

> "이전 인터뷰 세션이 있습니다. `/interview resume`로 재진입하거나, 새 세션은 `/interview` 그대로 시작."

문제는 **`/interview resume`가 구현돼 있지 않다**는 것이다. `commands/interview.md`는 kill-switch →
trivia escape → `conducting-interview` dispatch만 수행하며 resume 분기가 없다. state-storage
재설계 과정에서 resume 커맨드는 사라졌으나 이를 안내하던 SessionStart anchor만 살아남았다.
따라서 이 훅은 매 세션 시작마다 **실행 불가능한 조언을 LLM context에 주입하는 stale advisory**다.

live 플러그인 surface(`plugins/spec-distill/`)에서 `resume` 문자열은 단 두 곳에만 존재한다 — 이 훅의
메시지(`session-anchor.sh:44`)와 README의 Hooks Installed 표에서 이 훅을 설명하는 행(`README.md:108`).
**두 곳 모두 이번 제거 대상에 포함**되므로, 훅을 완전히 제거하면 live 플러그인의 죽은 resume 참조가
0건으로 떨어진다.

아카이브 plan 문서 `docs/superpowers/plans/2026-05-09-spec-distill.md`("spec-distill v0.1.0 Implementation
Plan")에는 역사적 `/interview resume`(L508)와 `SessionStart anchor for resumed sessions`(L349·L524) 언급이
남아 있으나, 이는 v0.1.0 시점 상태를 기록한 아카이브라 CHANGELOG history와 동일하게 **수정 대상이 아니다**
(NG5). 따라서 본 작업의 resume 0건 목표는 **live 플러그인 surface 한정**이며(G2), 검증 grep도 그 스코프로
측정한다(AC3). (레포의 다른 `resume` hit — quality-gates 세션 resume, philosophy P15 Initializer/Resumer —
는 본 작업과 무관하다.)

제거 안전성: 이 훅은 P14 read-only advisor라 출력을 프로그램적으로 소비하는 곳이 없다. 리뷰 흐름의
상태(`pending_review` / `suppressed_paths`)는 `pending-review-reminder.py`(UserPromptSubmit)와
`review-dispatch.py`(Stop)가 **독립적으로** 소비하므로, SessionStart 훅 제거는 리뷰 파이프라인에
영향을 주지 않는다. devbrew CLAUDE.md의 "훅 공존"(이벤트별 격리) 원칙이 이 제거를 국소화한다.

## Goals

- G1. SessionStart `session-anchor.sh` 훅과 그 `hooks.json` 등록을 완전히 제거한다.
- G2. live 플러그인 surface(`plugins/spec-distill/`)에서 죽은 `/interview resume` 참조를 0건으로 만든다
  (아카이브 plan 문서의 역사적 언급은 NG5로 명시 제외 — CHANGELOG history와 동일 취급).
- G3. 문서·테스트·버전을 동기화해 drift 없는 상태를 유지한다(README Hooks Installed / kill switch /
  output-schema, CHANGELOG, plugin.json, test 기대 버전).
- G4. SessionStart 훅이 실수로 되살아나는 것을 막는 최소 회귀 락을 남긴다(Law 3 compounding).

## Non-goals

- NG1. 인터뷰의 per-session state 디렉토리(`.claude/spec-distill/<sid>/`) 작성 메커니즘은 변경하지
  않는다 — 리뷰·세션 내 상태에 여전히 사용되며 cleanup은 SessionEnd / TTL-GC가 담당한다.
- NG2. 나머지 4개 훅(UserPromptSubmit reminder, PostToolUse validator, Stop review-dispatch,
  SessionEnd cleanup)의 동작은 건드리지 않는다.
- NG3. state-storage 위치·세션 스킴·GC 정책의 대규모 재설계는 별도 작업으로 남긴다.
- NG4. `/interview resume`를 다시 **구현**하지 않는다 — 이번 작업은 죽은 안내의 제거이지 기능 복원이 아니다.
- NG5. 아카이브 plan 문서(`docs/superpowers/plans/`, 특히 `2026-05-09-spec-distill.md`)와 CHANGELOG 역사
  항목의 `/interview resume`·`SessionStart anchor` 언급은 **수정하지 않는다** — 이는 그 시점 상태를 기록한
  point-in-time 문서이며, 역사 기록을 사후 편집하면 위조가 된다. (레포 밖 개인 메모리도 당연히 비대상.)

## Constraints

- devbrew CLAUDE.md: 플러그인을 touch하는 PR마다 `plugin.json` SemVer bump 동반. surface(훅) 제거는
  0.x에서 minor → **0.15.0 → 0.16.0**. CHANGELOG에 대응 항목 필수.
- 훅 변경 시 README "Hooks Installed" 표와 kill switch 목록을 같은 변경에서 동기화(drift 금지).
- spec-distill은 v0.x라 CLAUDE.md의 "v1.0.0+ one-minor deprecation window" 면제 → 즉시 제거 허용.
- Korean-primary 문서 규약 유지.
- 이 설계 문서 자체는 design-mode 검증(ambiguity + placeholder 스캔) 대상이므로 placeholder
  토큰과 ambiguity-blacklist 구문을 포함하지 않는다.

## Design

### D1 — 훅 파일·등록 제거 (G1)

- `hooks/session-anchor.sh` 파일을 삭제한다.
- `hooks/hooks.json`에서 `SessionStart` 키 블록을 통째로 제거한다(현재 L15-25). 최상위 `description`
  문자열에서 "SessionStart anchor," 조각을 제거해 남은 4개 훅만 나열되도록 한다.

### D2 — 회귀 락으로 테스트 슬롯 재활용 (G4)

`tests/test_hooks.sh`는 현재 전체(케이스 9-12)가 session-anchor 동작 테스트다. 빈 파일로 두거나
삭제하는 대신, **"SessionStart 훅이 되살아나지 않는다"**는 두 단언으로 재작성한다:

- 단언 1: `hooks/hooks.json`에 `SessionStart` 키가 없다.
- 단언 2: `hooks/session-anchor.sh` 파일이 존재하지 않는다.

이미 편집할 파일을 1:1로 repurpose하는 것이라 새 가드 레이어를 쌓지 않는다. hooks.json은 머지
사고로 SessionStart가 실수로 재등록되기 쉬운 파일이라, 이 락은 그 단일 회귀를 결정론적으로 잡는다.

### D3 — 단위 테스트에서 anchor 단언 제거 (G3)

`tests/test_hook_output_schema.py`에서 다음을 제거한다:

- `class TestSessionAnchorSchema`(AC5 — jq 경로 + no-jq fallback 두 테스트).
- `TestKillSwitches`의 `test_global_disable_silences_session_anchor` 메서드.

다른 훅 테스트와 섞여 있지 않으므로 외과적으로 제거 가능하다. 제거 후 파일이 import 오류 없이
green인지 확인한다(예: 쓰이지 않게 된 import가 있으면 정리).

### D4 — 문서 동기화 (G2, G3)

- `README.md`:
  - Hooks Installed 표에서 SessionStart 행(L108)을 삭제한다 — 이로써 마지막 live resume 참조가 사라진다.
  - Output-schema 문장(L114)에서 dual-target 이벤트 목록 중 "SessionStart"만 제거한다. 현재 문자열
    `` `hookSpecificOutput.additionalContext` for PostToolUse/UserPromptSubmit/SessionStart, `decision:"block" + reason` for Stop ``
    → 수정 후 `` `hookSpecificOutput.additionalContext` for PostToolUse/UserPromptSubmit, `decision:"block" + reason` for Stop `` (나머지 3개 이벤트의 dual-target 기술은 그대로 성립; `decision`/`reason` for Stop 부분 불변).
  - Kill switches 목록에서 `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` 항목(L120)을 삭제한다.
  - 잔여 `anchor` / `resume` / `SessionStart` 언급을 grep으로 스윕해 dangling 참조가 없는지 확인한다
    (CHANGELOG의 역사 항목은 보존 대상이므로 제외).
- `CHANGELOG.md`: `## [0.16.0] — 2026-06-16` 항목을 추가하고 `### Removed`에 SessionStart 훅 제거를
  기록한다. 기존 역사 항목(v0.5.0 silent-failure fix 등 session-anchor 언급)은 보존한다.

### D5 — 버전·테스트 기대값 (G3)

- `.claude-plugin/plugin.json`: version `0.15.0` → `0.16.0`.
- `tests/test_readme_sync.sh`: 기대 버전 단언을 `0.15.0` → `0.16.0`으로, CHANGELOG 기대 항목을
  `[0.16.0]`로 갱신한다(L2 주석 + L13-16).

## Acceptance Criteria

- AC1. `hooks/session-anchor.sh` 파일이 존재하지 않는다.
- AC2. `hooks/hooks.json`에 `SessionStart` 키가 없고, `description` 문자열에 "SessionStart anchor"가
  없으며, JSON이 유효하다(`python3 -c 'import json; json.load(open(...))'` 통과).
- AC3. `grep -rni "resume" plugins/spec-distill --include='*.md' --include='*.sh' --include='*.py'
  --include='*.json'`에서 CHANGELOG 역사 항목(`CHANGELOG.md`)을 제외한 결과가 0건이다. 스코프는 **live
  플러그인 한정**(G2/NG5) — `docs/superpowers/plans/` 아카이브는 의도적으로 grep 대상 밖이다.
- AC4. README Hooks Installed 표에 SessionStart 행이 없고, Output-schema 문장에 "SessionStart"가 없으며,
  Kill switches 목록에 `spec-distill:SessionStart` 항목이 없다.
- AC5. `.claude-plugin/plugin.json`의 version이 `0.16.0`이고, CHANGELOG에 ISO 날짜를 가진
  `## [0.16.0] — 2026-06-16` 항목과 `### Removed`가 있다.
- AC6. `bash tests/test_hooks.sh`가 회귀 락 두 단언(SessionStart 키 부재 + 파일 부재)으로 통과한다.
- AC7. `python3 -m unittest`로 실행한 `test_hook_output_schema` 스위트가 anchor 클래스·global-disable
  테스트 제거 후 green이다.
- AC8. `bash tests/test_readme_sync.sh`가 0.16.0 기대값으로 green이다.
- AC9. spec-distill 전체 테스트 스위트(bash + python 혼합) 회귀 0.

## Files to Modify

- `plugins/spec-distill/hooks/session-anchor.sh` — **삭제**(D1).
- `plugins/spec-distill/hooks/hooks.json` — SessionStart 블록 제거 + description 갱신(D1).
- `plugins/spec-distill/tests/test_hooks.sh` — 회귀 락 두 단언으로 재작성(D2).
- `plugins/spec-distill/tests/test_hook_output_schema.py` — `TestSessionAnchorSchema` +
  `test_global_disable_silences_session_anchor` 제거(D3).
- `plugins/spec-distill/README.md` — Hooks Installed 행 / Output-schema / Kill switch 동기화 + grep 스윕(D4).
- `plugins/spec-distill/CHANGELOG.md` — `## [0.16.0]` Removed 항목 추가(D4).
- `plugins/spec-distill/.claude-plugin/plugin.json` — version 0.16.0(D5).
- `plugins/spec-distill/tests/test_readme_sync.sh` — 기대 버전 0.16.0 갱신(D5).

## Verification Plan

- 러너 규약([[reference_spec_distill_test_runner]]): bash 스위트는 `bash tests/<name>.sh`로, python
  스위트는 `python3 -m unittest`로 실행한다(python 직접 실행은 vacuous).
- TDD 순서: D2의 회귀 락은 hooks.json/파일이 아직 그대로면 RED여야 정상 — 단언을 먼저 작성하면
  현 상태에서 실패하고(파일·키가 존재), D1 제거와 같은 변경에서 green으로 전환한다.
- `bash tests/test_hooks.sh`(AC6), `python3 -m unittest discover -s tests`(또는 모듈 지정,
  AC7), `bash tests/test_readme_sync.sh`(AC8) green 확인.
- AC2: `python3 -c "import json,sys; json.load(open('plugins/spec-distill/hooks/hooks.json'))"` 무오류.
- AC3: 위 grep 명령(live 플러그인 스코프, `*.json` 포함, `CHANGELOG.md` 제외)을 수동 실행해 0건 확인.
  아카이브 plan 문서·CHANGELOG history·레포 밖 개인 메모리는 NG5로 스코프 밖이라 검증 불필요(수정 안 하므로).
- 회귀: spec-distill 디렉토리의 모든 `.sh` + `.py` 테스트를 한 번 돌려 회귀 0(AC9).
- `/qg`로 review 게이트 통과(spec-conformance: 본 AC 기준).

## Rejected Alternatives

- **메시지만 수정(훅 유지).** 죽은 `/interview resume` 안내만 빼고 SessionStart 감지·advisory는 유지하는
  안. 사용자가 "훅 완전 제거"를 명시적으로 선택했고, resume 제거 후 anchor가 안내할 actionable 동작이
  남지 않으므로(리뷰 알림은 다른 훅이 담당) 제외.
- **테스트를 회귀 락 없이 그냥 삭제.** `tests/test_hooks.sh`를 통째 삭제하는 가장 가벼운 안. 비용은
  거의 같으나 SessionStart 재도입을 막는 가드가 사라진다. 이미 편집하는 파일을 repurpose하는 것이라
  추가 ceremony가 아니라고 판단해 회귀 락(D2)을 채택.
- **deprecation window 경유 제거.** CLAUDE.md의 one-minor deprecation window는 v1.0.0+ 적용이고
  spec-distill은 v0.x라 면제. 즉시 제거가 규약에 부합.
- **resume 잔재 전수 audit(레포 전역).** full 훅 제거가 이미 두 resume 참조를 모두 포함하므로 별도
  전역 audit이 불필요하다(AC3가 0건으로 검증).

## Handoff Context

**TL;DR (구현자가 먼저 알 것):** 훅 1개(`session-anchor.sh`)를 삭제하고 `hooks.json`의 SessionStart
등록을 제거한다. 새 surface는 없다 — 순수 제거 + 문서/테스트/버전 동기화. 테스트는 두 파일에서만
anchor 단언을 떼면 되고(`test_hooks.sh` 재작성, `test_hook_output_schema.py`의 anchor 클래스·global-disable
제거), 버전은 0.15.0 → 0.16.0이며 `test_readme_sync.sh`의 기대값을 같이 올린다.

**Implicit context (plan이 가정해도 되는 것):**
- session-anchor는 P14 read-only advisor라 출력 소비처 추적이 불필요하다 — 제거 blast radius는 자기 자신
  + 문서/테스트로 한정된다.
- **live 플러그인의** resume 참조는 정확히 두 곳(`session-anchor.sh:44`, `README.md:108`)이며 둘 다 제거
  대상이다. full 제거 후 `plugins/spec-distill` 스코프 `grep -i resume`는 `CHANGELOG.md` 역사를 제외하면
  0건이어야 한다(AC3). 아카이브 plan 문서(`docs/superpowers/plans/2026-05-09-spec-distill.md`)의 역사적
  `/interview resume`·`SessionStart anchor` 언급은 NG5로 **건드리지 않는다** — 거기까지 청소하려 들지 말 것.
- 리뷰 흐름(`pending_review`/`suppressed_paths`)은 UserPromptSubmit/Stop 훅이 독립 소비하므로
  SessionStart 제거가 리뷰를 깨뜨리지 않는다(NG2).
- 회귀 락(D2)은 보안/정확성 게이트가 아니라 "이미 떼어낼 테스트 파일의 1:1 repurpose"다 — devbrew
  lightness([[feedback_harness_lightness_trust_model]])와 충돌하지 않는 범위로 둔다(키 부재 + 파일 부재
  두 단언 이상으로 확장하지 말 것).

**Deferred to plan (이 design이 결정하지 않은 것):**
- 회귀 락의 정확한 셸 단언 표현(`jq -e` vs `grep -q '"SessionStart"'`, `[[ -e ]]` 등)은 plan/TDD에서 확정.
- `test_hook_output_schema.py`에서 anchor 클래스 제거 후 쓰이지 않게 되는 import(예: `shutil`)가 다른
  테스트에서도 안 쓰이면 정리 여부는 plan에서 grep으로 판단.
- CHANGELOG `[0.16.0]` 항목의 정확한 문구(Removed 한두 줄)는 plan에서 확정.

## Metadata

- 대상 플러그인: spec-distill (main = 0.15.0 → 0.16.0)
- 변경 성격: SessionStart 훅 surface 제거(removal) + 문서/테스트/버전 동기화
- 관련 메모리: [[feedback_harness_lightness_trust_model]], [[reference_spec_distill_test_runner]],
  [[project_spec_distill_interview_frontstage]], [[project_spec_distill_interview_compact_handoff]]
- 근거: live 플러그인 grep(resume 2건, 둘 다 제거 대상) + interview.md에 resume 분기 부재 확인 +
  아카이브 plan 문서(2026-05-09)의 역사적 resume 언급은 NG5로 스코프 밖(수정 안 함)
- round-1 spec-reviewer 수정 반영: repo-wide→live-plugin 스코프 정정(G2/AC3), NG5 아카이브 제외 명시,
  AC3 `*.json` 추가, D4 L114 after-string 명시
- 작성일: 2026-06-16
