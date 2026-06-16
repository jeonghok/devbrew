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

### 진단 신뢰도와 한계 (이슈 g0e2d417 — 의식적 채택)

A1+A2는 **C3(순서 버그)와 latent W2-suppress를 결정론적으로 닫는다**. 그러나 절대경로 세션에서 더
유력한 원인은 W1(모델이 approve_handoff 미실행)이며, W1이 사용자 실제 증상의 진짜 원인이라면
A1+A2만으로는 같은-턴 재발이 **남는다**(suppressed_paths가 비어 있어 A2도 못 막음). 이 한계는 알고도
채택한 것이다: W1을 구조적으로 막을 유일 수단 B가 불가능하므로(위), W1은 A3의 stance —
`/spec-distill:cancel-review` escape hatch + 재발 증명 시 Law 3 persona/skill 편집 — 로 다룬다.
즉 본 설계는 "C3가 유일 원인"이라 단정하지 않으며, 결정론으로 닫을 수 있는 것(C3·W2-suppress)은 닫고
닫을 수 없는 것(W1)은 escape hatch로 두는 **혼합 stance**다. 사용자 합의(A1+A2+prose)에 부합한다.

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
- dir-safety(이슈 b9d3e501): suppress 기록은 state 파일/디렉토리 부재에도 안전하다 — approve 시점엔
  PostToolUse arm이 이미 `~/.claude/spec-distill/<sid>/`를 만들었고, 추가로 `suppress_state._commit`이
  `state_file.parent.mkdir(parents=True, exist_ok=True)`로 멱등 생성한다.

### A2 — `review-dispatch.py`가 `suppressed_paths` 존중 (G2)

`PENDING_RE` 매치로 pending을 찾은 직후, 그 `path`가 현재 세션 suppressed면 dispatch하지 않는다:

- **import 경로(이슈 d7b1f923)**: `review-dispatch.py`는 현재 `sys.path`에 `hooks/`(SCRIPT_DIR)만
  넣는다. `suppress_state.py`는 `scripts/`에 있으므로, `spec-write-validator.py:35-36`처럼
  `SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"`를 sys.path에 **명시적으로 추가**해야 한다. 추가를
  빠뜨리면 import가 조용히 실패 → 아래 예외 경로로 fail-open(정상 dispatch)된다.
- `suppress_state.is_suppressed(state_file, spec_path)`가 True면 → stale pending을 strip하되
  **`last_dispatched_at`은 건드리지 않는다**(이슈 c4f2a810): `rewrite_state`(strip + `last_dispatched_at`
  갱신)를 재사용하지 *않고*, `suppress_state.strip_pending(body)` 결과를 직접 write → `return 0`
  (emit 없음, dispatch 없음). 이유: suppress는 "dispatch"가 아니므로 TTL 시계를 시작시키면 안 된다.
  `rewrite_state`를 재사용하면 `/spec-distill:cancel-review --reset`로 억제 해제 직후
  `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`(기본 30초) 동안 정당한 pending이 block돼 재발 window가 생긴다.
- import/체크 예외는 loud stderr 후 **정상 dispatch로 진행**(실패-안전 = 리뷰 발생).
- PostToolUse는 이미 arm 직전 `is_suppressed`로 arm-skip한다. A2는 그 체크가 graceful-degrade(현
  코드 `except Exception` → 정상 arm)로 빠져 pending이 armed된 경우의 defense-in-depth이자, Stop을
  "트리거+억제 두 신호를 모두 읽는" 권위 레이어로 만드는 대칭 복원이다.

### A3 — W1 stance + 최소 prose 하드닝 (G3)

- `reviewing-spec/SKILL.md` Phase 5 Step C: approve(①/②) 응답 수신 시 **approve_handoff 호출을 어떤
  narration보다 먼저** 수행하도록 시퀀싱을 명시(기존 polite-stop 금지 prose 강화, 새 메커니즘 아님).
- W1 잔여 위험은 `/spec-distill:cancel-review` escape hatch로 커버. 재발이 W1로 증명되면 Law 3대로
  잡았어야 할 skill/persona를 편집한다(코드 패치가 아니라).

**SKILL.md 정확 before/after (이슈 a1e4c2f7 — exit code 서술 불일치 차단):**

"Approve handoff sequence" 절의 단계 서술 —
- before: "(2) **spec_path working-tree 존재 검증** (`[[ -f ]]`, 모든 git 조회 이전 — 부재 시 exit 1 +
  advisory + suppress 미기록, state 보존), (3) 미커밋 spec advisory (non-blocking, exit 0), (4) **approved
  spec를 `suppressed_paths`에 기록 + 그 문서의 pending strip**"
- after: "(2) **approved spec를 `suppressed_paths`에 기록 + 같은-키 pending strip** (`suppress_state.py
  add` — canonical_key 기반, 파일 존재 불필요), (3) spec_path working-tree 존재 검증을 **non-blocking
  advisory로** (부재 시 stale/dangling 안내; suppress는 이미 (2)에서 기록됨, exit 0), (4) 미커밋 spec
  advisory (non-blocking)"

"실패 시 state 보존" 절 —
- before: "approve_handoff.sh가 exit 1 시(spec_path 부재 … 또는 session_id charset/arg 검증 실패)
  state.local.md 보존 + suppress 미기록"
- after: "approve_handoff.sh의 exit 1은 **session_id charset/arg 검증 실패에 한정**한다. spec_path가
  in-scope(`docs/superpowers/specs/` prefix)이면 working-tree 부재여도 suppress를 기록하고 exit 0 +
  stale advisory를 낸다(부재가 더 이상 abort 아님)."

## Acceptance Criteria

- AC1. approve_handoff에 in-scope spec_path를 주되 파일이 working-tree에 없을 때, suppressed_paths에
  canonical key가 기록되고 같은-키 pending이 strip되며 종료코드는 0이다(C3 회귀 테스트).
- AC2. approve_handoff는 arg/charset 검증 실패에서만 exit 1을 반환한다.
- AC3. Stop hook은 pending의 path가 suppressed면 dispatch하지 않고 stale pending을 strip한다.
- AC3b. Stop hook의 suppress-strip 경로는 `last_dispatched_at`을 **갱신하지 않는다**(TTL window 방지,
  이슈 c4f2a810): suppress된 state에 알려진 `last_dispatched_at`을 넣고 Stop 실행 후 그 값이 불변임을 단언.
- AC4. Stop hook의 suppress 체크가 예외로 실패하면(예: import 모킹 실패) 정상 dispatch한다(실패-안전).
- AC5. suppressed가 아닌 pending에 대해 Stop hook은 기존대로 dispatch한다(회귀 없음).
- AC6. (단위-테스트 proxy, 이슈 e5c3b204) approve_handoff 성공 후 state는 **pending 없음 AND
  suppressed_paths에 canonical key 있음** — 이 두 조건이 같은-턴 재발을 막는 기계적 보증이다. "같은-턴
  재발 없음" 자체는 런타임 속성이므로 §Verification의 격리 재현 하니스(4-조건)로 확인한다(C1·C2 → 재발
  안 함; C3 → 본 수정 후 재발 안 함; C4=W1 → 여전히 재발, A3 stance가 정답).
- AC7. 기존 단위 테스트 전부 통과(bash `.sh` + python `.py` 혼합 스위트 회귀 0).

## Files to Modify

- `plugins/spec-distill/scripts/approve_handoff.sh` — A1 순서 역전 + exit 의미 갱신 + 헤더 주석.
- `plugins/spec-distill/hooks/review-dispatch.py` — A2 suppress 존중 분기 + import.
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — A3 prose(시퀀싱·handoff 절·실패 절).
- `plugins/spec-distill/.claude-plugin/plugin.json` — version 0.14.0 → 0.15.0.
- `plugins/spec-distill/CHANGELOG.md` — `## [0.15.0]` (Fixed: C3 순서 버그 / Changed: Stop suppress 존중).
- `plugins/spec-distill/README.md` — "Principles Instantiated"에 Law 2 트리거/억제 대칭 한 줄(해당 시).
- `plugins/spec-distill/tests/test_approve_handoff.sh` — **기존 파일**(신규 아님, 이슈 f6d1c309 정정).
  기존 Case 1–7은 모두 spec 파일이 working-tree에 *존재하는* 셋업이라 C3(파일 부재)를 커버하지 않는다.
  → **신규 Case 8**(in-scope-but-missing spec_path → suppressed_paths 키 기록 + 같은-키 pending strip +
  exit 0, AC1) + Case 9(arg/charset 실패만 exit 1, AC2)를 추가한다.
- `plugins/spec-distill/tests/test_review_dispatch.sh` — **기존 파일**: suppressed pending → no-dispatch +
  strip + `last_dispatched_at` 불변(A2, AC3·AC3b); 비-suppressed → dispatch(AC5); import 실패 → dispatch
  (AC4). python 단언이 더 자연스러운 케이스는 `tests/test_hook_output_schema.py`에 추가 가능.

## Verification Plan

- 러너 규약([[reference_spec_distill_test_runner]]): bash 스위트는 `bash tests/<name>.sh`로, python
  스위트는 `python3 -m unittest`로 실행(python을 직접 실행하면 vacuous). 본 변경의 신규 케이스는 대상이
  bash 스크립트/hook이므로 주로 `.sh` 스위트에 추가.
- approve_handoff(`test_approve_handoff.sh`, AC1·AC2): 임시 git repo + in-scope-but-missing spec_path →
  `suppressed_paths` 키 기록 + 같은-키 pending strip + exit 0 단언; arg/charset 실패만 exit 1 단언.
- review-dispatch(`test_review_dispatch.sh`, AC3–AC5): suppressed pending 주입 → no-dispatch + strip +
  `last_dispatched_at` 불변(AC3b) 단언; 비-suppressed → dispatch 단언(AC5); `suppress_state` import 실패
  모킹 → dispatch 단언(AC4).
- 순서(이슈 NEW-002): A2/A3가 단언하는 신규 동작 테스트(AC3·AC3b·AC4·AC5의 suppress 분기)는 현재
  코드에 그 분기가 없어 **추가 즉시 RED(정상 TDD)** 다 — vacuous가 아니라 올바른 failing test. A2 구현과
  **같은 change에서** green으로 전환한다(테스트만 먼저 커밋해 CI를 깨지 말 것).
- 회귀: 기존 spec-distill 테스트 스위트 전체 green(AC7) — bash+python 혼합.
- 격리 재현 하니스(이번 설계의 4-조건 표)를 재실행해 C3·C4가 의도대로 바뀌는지 확인(C3 → 재발 안 함,
  C4는 W1이라 여전히 재발 — A3 stance대로 escape hatch가 정답)(AC6 런타임 확인).
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

## Handoff Context

**TL;DR (구현자가 먼저 알 것):** 단 3개 surface를 건드린다 — `approve_handoff.sh`(suppress 기록을 `-f`
검사 *앞으로*, `-f`는 non-blocking advisory로 강등), `review-dispatch.py`(pending이 suppressed면
dispatch 안 함 + `last_dispatched_at` 안 건드리고 strip; SCRIPTS_DIR sys.path 추가; import 실패는
fail-open), `reviewing-spec/SKILL.md`(approve_handoff를 narration 앞에 + exit-code 서술 갱신). 새 hook
없음. 0.14.0 → 0.15.0 + CHANGELOG.

**Implicit context (plan이 가정해도 되는 것):**
- 정규화·pending strip·suppress 단일 소스는 `suppress_state.py` — 새 정규화 로직 만들지 말 것(C4/AC17).
- `suppress_state.strip_pending(body)`는 `last_dispatched_at`을 건드리지 않는 순수 pending 제거이므로 A2의
  TTL-safe strip에 그대로 쓴다. `rewrite_state`(review-dispatch.py)는 dispatch 전용으로 남긴다.
- 재현 근거는 격리 하니스 4-조건(C1–C4)이며 본 design §Context 표에 박제됨. 구현 후 같은 하니스로 C3가
  "재발 안 함"으로 바뀌는지 확인(AC6 런타임).
- fail-safe 방향은 항상 "리뷰가 일어나는 쪽" — A2의 모든 예외/불확실 경로는 dispatch로 귀결.
- (이슈 NEW-001) A2의 fail-open(`except → dispatch`)은 **suppress 체크를 감싸는 단일 try/except 블록
  내부에서만** 적용된다 — `import suppress_state` 실패를 포함한 모든 suppress-체크 예외가 그 블록을 통해
  dispatch로 귀결되도록 설계한다(블록 밖 일반 흐름의 dispatch 동작은 기존과 동일, 무변경).

**Deferred to plan (이 design이 결정하지 않은 것):**
- 신규 테스트 케이스의 정확한 fixture 셋업 코드(임시 git repo 헬퍼 재사용 여부)는 plan/TDD에서 결정.
- (이슈 c4f2a810 잔여) A2의 suppress 분기에서 pending strip을 `suppress_state.strip_pending` 직접
  write로 할지, `suppress_state.suppress_path`(멱등 re-add + 같은-키 strip) 재사용으로 할지는 plan 판단.
  두 경로 모두 `last_dispatched_at`을 건드리지 않아 AC3b를 충족한다(key는 이미 suppressed_paths에 있으므로
  re-add는 no-op). 기능 동치 → 구현자 재량.
- README "Principles Instantiated" 한 줄 문구는 plan에서 확정(해당 시).

**Plan advisories (round-3 spec-reviewer, 비차단):**
- A1 구현 시 `approve_handoff.sh` 헤더 주석(현 line 5–8, v0.11.0 기준 "validates spec_path … exit 1")을
  실제 동작(suppress 먼저, `-f`는 advisory)으로 갱신 — exit-code 표 포함, 주석-코드 drift 방지.
- Verification의 "테스트만 먼저 커밋해 CI 깨지 말 것" = 테스트와 A2 구현을 **분리 커밋하지 말고 같은
  커밋/연속 커밋**으로 묶으라는 뜻(TDD RED 자체는 정상). plan 서술에서 풀어쓸 것.
- c4f2a810 잔여: A2는 `is_suppressed == True` 확인 *뒤*이므로, `suppress_path` 재사용 시 같은-키 strip
  조건이 항상 충족된다(혼선 방지 한 줄).

## Metadata

- 대상 플러그인: spec-distill (main = 0.14.0 → 0.15.0)
- 관련 메모리: [[feedback_harness_lightness_trust_model]], [[project_spec_distill_cancel_suppress]],
  [[reference_spec_distill_test_runner]], [[feedback_subagent_security_repro_isolation]]
- 근거: 격리 재현 하니스(4-조건) + claude-code-guide 문서 확인(B feasibility)
- 작성일: 2026-06-15
