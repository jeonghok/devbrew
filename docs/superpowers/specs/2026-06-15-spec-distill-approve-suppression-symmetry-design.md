# spec-distill approve→suppress 대칭화 (v0.15.0)

> approve된 design 문서가 같은 턴에 review hook을 다시 발동시키는 버그를, 억제(suppress) 경로를
> 트리거 경로만큼 견고하게 만들어 닫는다.

## Context / Why

사용자 보고: reviewing-spec Phase 5에서 **① `/compact` 후 writing-plans**(또는 ② 바로 writing-plans)을
골라 design을 approve해도, **같은 턴에** Stop hook이 reviewing-spec를 다시 dispatch한다. 사용자 직관:
"approve되는 순간 hook이 cancel되어야 하지 않나."

근본 원인은 devbrew Law 2의 **비대칭**이다:

| | 트리거(리뷰 강제) | 억제(approve 취소) |
|---|---|---|
| 권위 | hook 구조적 (PostToolUse arm + Stop dispatch) — 불변 | `approve_handoff.sh`를 모델이 prose 지시대로 실행 |
| 실패 모드 | 없음 | W1 미실행 / W2-path `-f` 조기 exit / W2-suppress Stop이 suppressed_paths 무시 |

`review-dispatch.py`는 dispatch 시 `pending_review` 블록을 strip한다. 따라서 reviewing-spec가 도는
턴 시작엔 pending이 비어 있어야 한다. **같은-턴 재발 = 그 턴 안에서 `*-design.md` 쓰기가 PostToolUse를
통해 pending을 재arm했고, approve의 strip이 그걸 못 덮었다**는 뜻이다.

### 재현으로 좁힌 원인 (격리된 throwaway repo, 실제 hook 3개 구동)

| 조건 | spec_path / cwd | approve_handoff | pending | Stop hook |
|---|---|---|---|---|
| C1 절대경로, cwd=repo root (현실) | 절대 / root | rc=0, suppress 기록 | 제거 | 재발 안 함 |
| C2 상대경로, cwd=repo root | 상대 / root | rc=0, suppress 기록 | 제거 | 재발 안 함 |
| C3 상대경로, cwd=서브디렉토리 | 상대 / subdir | rc=1 "not found in working tree" | 남음 | 재발함 |
| C4 approve_handoff 미실행 (W1) | — | 미실행 | 남음 | 재발함 |

결론:

1. 현실 조건(C1·C2, Claude Code Edit는 절대경로 강제)에서 메커니즘은 **견고**하다.
2. W2-path(C3)는 *상대경로 AND cwd=서브디렉토리*에서만 재현된다. 원인은 `approve_handoff.sh`의
   `[[ -f "$spec_path" ]]` 검사가 suppress 기록(`suppress_state.py add`)보다 **먼저** 실행돼, 실패 시
   `canonical_key`(파일 존재 불필요) 기반 suppress조차 못 남기고 exit하는 **순서 버그**다.
3. W1(모델이 bash 자체 미실행, C4)은 C3와 관측상 동일하며 절대경로 세션에선 더 유력한 원인이다.

### B(approve를 hook으로 구조적 cancel)는 제외 — 깨끗하게 불가능

claude-code-guide의 공식 문서 확인 결과 **UNVERIFIED-BY-DOCS**: PostToolUse가 AskUserQuestion에
발동하는지, 발동해도 사용자가 고른 옵션이 payload에 노출되는지 문서가 명시하지 않는다.
AskUserQuestion은 user-interaction 필수 특수 툴이라 표준 lifecycle을 안 따를 수 있고, `answers`도
"Claude가 set하지 않음"이다. 남은 경로(transcript 파싱 hook, 미문서화 동작 의존)는 모두 brittle하며
devbrew lightness에 위배된다. 따라서 W1을 구조적으로 막는 길은 현재 없다.

## Goals

- G1. C3(순서 버그) 같은-턴 재발을 **결정론적으로** 제거한다.
- G2. approve된 문서는 Stop hook이 **권위 레이어에서** 절대 재dispatch하지 않도록 Law 2 대칭을 복원한다
  (PostToolUse가 이미 가진 suppress 체크를 Stop에도 둔다).
- G3. W1에 대해서는 모델 신뢰 + 기존 `/spec-distill:cancel-review` escape hatch를 명시적 stance로 채택하고,
  재발을 줄이는 최소 prose 시퀀싱만 강화한다.

## Non-goals

- NG1. PostToolUse/PreCompact/transcript 파싱으로 approve를 구조적 감지하는 **새 hook을 추가하지 않는다**
  (B 제외, lightness).
- NG2. review **강제** 경로(PostToolUse arm, Stop dispatch의 기본 동작)는 건드리지 않는다 — 약화 금지.
- NG3. spec-distill state 저장 위치/세션 스킴/GC 정책은 변경하지 않는다.
- NG4. design-mode 라우팅 테이블·re-review cap·stagnation 로직은 변경하지 않는다.

## Constraints

- 새 hook 추가 금지(NG1). 변경은 기존 스크립트 3개 + SKILL.md prose + 문서로 한정.
- 모든 hook의 kill switch(`DEVBREW_DISABLE_SPEC_DISTILL=1` 등)와 graceful degradation 규약 유지.
- A2의 실패-안전 방향은 **"리뷰가 일어나는 쪽"**: suppress 체크가 실패하면 dispatch한다(과리뷰가
  under-review보다 안전 — Law 1 게이트).
- 정규화·pending strip·suppress의 단일 소스는 `suppress_state.py`(C4/AC17) — 새 정규화 로직을 다른
  파일에 만들지 않는다.
- 플러그인 touch → `plugin.json` SemVer bump 동반(0.14.0 → 0.15.0) + CHANGELOG 항목.

## Design

### A1 — `approve_handoff.sh` 순서 뒤집기 (G1)

현재: ①`-f` 존재검사(실패 시 `exit 1`) → ②main_repo 해석 → ③미커밋 advisory → ④suppress 기록.

변경 후: ①kill switch·charset guard(불변) → ②**suppress 기록을 먼저**(`suppress_state.py add` —
`canonical_key`만 쓰므로 파일 존재 불필요) → ③main_repo 해석 → ④`-f` 존재검사를 **non-blocking
advisory로 강등**(stale/dangling 경로 안내, 더 이상 조기 exit 아님) → ⑤미커밋 advisory(파일 존재 시).

- 이로써 dangling·상대경로·서브디렉토리 cwd 어떤 경우에도 strip+suppress가 무조건 기록된다.
- exit code: arg/charset 검증 실패만 `exit 1`(기존 유지). in-scope spec_path가 working-tree에 없어도
  suppress는 기록됐으므로 `exit 0` + stale advisory. out-of-scope 경로(PREFIX 없음)는 `suppress_path`가
  False → 기존처럼 advisory + 비-suppress(canonical_key 없음).
- 보존되는 의미: 기존 `-f`가 막던 "dangling worktree 경로" 시나리오는 여전히 **advisory로 노출**되어
  사용자가 stale state를 인지한다. 잃는 것은 "조기 abort"뿐이고, 그 abort가 바로 버그였다.

### A2 — `review-dispatch.py`가 `suppressed_paths` 존중 (G2)

`PENDING_RE` 매치로 pending을 찾은 직후, 그 `path`가 현재 세션 suppressed면 dispatch하지 않는다:

- `suppress_state`를 import(`spec-write-validator.py`와 동일하게 `SCRIPTS_DIR` sys.path 추가).
- `suppress_state.is_suppressed(state_file, spec_path)`가 True면 → stale pending을 strip(`rewrite_state`
  재사용: strip + `last_dispatched_at` 갱신) → `return 0`(emit 없음, dispatch 없음).
- import/체크 예외는 loud stderr 후 **정상 dispatch로 진행**(실패-안전 = 리뷰 발생).
- PostToolUse는 이미 arm 직전 `is_suppressed`로 arm-skip한다. A2는 그 체크가 graceful-degrade(현
  코드 `except Exception` → 정상 arm)로 빠져 pending이 armed된 경우의 defense-in-depth이자, Stop을
  "트리거+억제 두 신호를 모두 읽는" 권위 레이어로 만드는 대칭 복원이다.

### A3 — W1 stance + 최소 prose 하드닝 (G3)

- `reviewing-spec/SKILL.md` Phase 5 Step C: approve(①/②) 응답 수신 시 **approve_handoff 호출을 어떤
  narration보다 먼저** 수행하도록 시퀀싱을 명시(기존 polite-stop 금지 prose 강화, 새 메커니즘 아님).
- "Approve handoff sequence"·"실패 시 state 보존" 절을 A1의 새 동작(순서 역전, suppress 무조건 기록,
  exit 1은 arg/charset만)에 맞춰 갱신.
- W1 잔여 위험은 `/spec-distill:cancel-review` escape hatch로 커버. 재발이 W1로 증명되면 Law 3대로
  잡았어야 할 skill/persona를 편집한다(코드 패치가 아니라).

## Acceptance Criteria

- AC1. approve_handoff에 in-scope spec_path를 주되 파일이 working-tree에 없을 때, suppressed_paths에
  canonical key가 기록되고 같은-키 pending이 strip되며 종료코드는 0이다(C3 회귀 테스트).
- AC2. approve_handoff는 arg/charset 검증 실패에서만 exit 1을 반환한다.
- AC3. Stop hook은 pending의 path가 suppressed면 dispatch하지 않고 stale pending을 strip한다.
- AC4. Stop hook의 suppress 체크가 예외로 실패하면 정상 dispatch한다(실패-안전).
- AC5. suppressed가 아닌 pending에 대해 Stop hook은 기존대로 dispatch한다(회귀 없음).
- AC6. C1·C2(절대/상대경로 + cwd=repo root)에서 approve 후 같은-턴 재발이 없다(기존 동작 유지).
- AC7. 기존 단위 테스트 전부 통과(억제·취소·validator·state 스위트 회귀 0).

## Files to Modify

- `plugins/spec-distill/scripts/approve_handoff.sh` — A1 순서 역전 + exit 의미 갱신 + 헤더 주석.
- `plugins/spec-distill/hooks/review-dispatch.py` — A2 suppress 존중 분기 + import.
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — A3 prose(시퀀싱·handoff 절·실패 절).
- `plugins/spec-distill/.claude-plugin/plugin.json` — version 0.14.0 → 0.15.0.
- `plugins/spec-distill/CHANGELOG.md` — `## [0.15.0]` (Fixed: C3 순서 버그 / Changed: Stop suppress 존중).
- `plugins/spec-distill/README.md` — "Principles Instantiated"에 Law 2 트리거/억제 대칭 한 줄(해당 시).
- 테스트 파일(기존 억제/state 스위트에 케이스 추가) — `tests/` 하위 해당 모듈.

## Verification Plan

- 단위 테스트(`python3 -m unittest`로만 실행 — 직접 실행은 vacuous): AC1–AC5 각각의 테스트 추가.
  - approve_handoff: 임시 git repo + in-scope-but-missing spec_path → suppressed_paths 기록 + exit 0 단언.
  - review-dispatch: state에 suppressed pending 주입 → no-dispatch + pending strip 단언; 비-suppressed →
    dispatch 단언; suppress import 모킹 실패 → dispatch 단언.
- 회귀: 기존 spec-distill 테스트 스위트 전체 green(AC7).
- 격리 재현 하니스(이번 설계의 4-조건 표)를 재실행해 C3·C4가 의도대로 바뀌는지 확인(C3 → 재발 안 함,
  C4는 W1이라 여전히 재발 — A3 stance대로 escape hatch가 정답).
- `/qg`로 review 게이트 통과(spec-conformance: 본 AC 기준).

## Rejected Alternatives

- **B — PostToolUse/transcript hook으로 approve 순간 구조적 cancel.** "approve되는 순간 cancel hook"
  문자 그대로지만, 공식 문서가 PostToolUse의 AskUserQuestion 응답 노출을 보장하지 않음(UNVERIFIED).
  transcript 파싱은 brittle + 모든 AskUserQuestion에 발동하는 결합 → lightness 위배. 제외.
- **A2를 PostToolUse 강화로 대체(Stop은 그대로).** PostToolUse는 이미 is_suppressed를 본다. 같은-턴
  증상의 권위 레이어는 Stop이므로, Stop이 신호를 읽는 대칭이 더 옳다. PostToolUse만 강화하면 Stop은
  여전히 트리거 신호만 보는 비대칭 유지.
- **W1을 위해 approve_handoff를 Stop hook이 대신 실행.** Stop은 사용자의 approve 의도를 모른다
  (verdict·선택을 못 봄) → approve 없이 무조건 suppress하면 review 게이트 자체가 무력화(Law 1 위배). 제외.

## Metadata

- 대상 플러그인: spec-distill (main = 0.14.0 → 0.15.0)
- 관련 메모리: [[feedback_harness_lightness_trust_model]], [[project_spec_distill_cancel_suppress]],
  [[reference_spec_distill_test_runner]], [[feedback_subagent_security_repro_isolation]]
- 근거: 격리 재현 하니스(4-조건) + claude-code-guide 문서 확인(B feasibility)
- 작성일: 2026-06-15
