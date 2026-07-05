# Design — spec-distill review-in-progress 락 session-id split 수정 (v0.18.1)

> **One-line:** `reviewing-spec` 스킬이 리뷰 락·suppress·approve를 **interview UUID**로 keyed 하는데 훅은 **harness sid**로 읽는다 → 락 미발견 → Stop 재강제 루프. 스킬이 훅-facing 호출에 harness sid를 넘기도록 bridge 한다.

- **상태:** 설계 (brainstorming 산출). 근거는 `docs/superpowers/handoffs/2026-07-05-spec-distill-review-lock-session-id-split.md` (live 재현·확정) + 본 세션의 소스 검증.
- **영향 버전:** spec-distill `0.18.0` (main `00415d9`).
- **Fix 브랜치:** `fix/spec-distill-review-lock-session-id` (main에서 분기).

---

## Context / Why

v0.18.0이 도입한 document-keyed `review_in_progress` 락은 subagent(async) dispatch 중 메인 `Stop` 훅이 진행 중인 리뷰를 재강제(중복 A / 절단 B)하는 오발을 봉쇄하려 했다. 그러나 락을 **쓰는 쪽**(reviewing-spec 스킬)과 **읽는 쪽**(Stop / UserPromptSubmit 훅)이 서로 다른 session-id 네임스페이스를 쓴다:

- **훅(reader)** — 세 훅 모두 `state_path.resolve_session_id(payload)`로 id를 얻는다. precedence는 `DEVBREW_SPEC_DISTILL_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → `payload["session_id"]` = **harness session id**. 상태 파일은 `<state_root>/<harness-sid>/state.local.md`.
- **스킬(writer)** — `reviewing-spec` Step 1이 continuity state(`rereview_count`/`issue_history`)가 사는 상태 파일을 로드하고 그 frontmatter의 `session_id`(= 인터뷰가 자체 생성한 **interview UUID**)를 `$session_id`로 채택한다. 이 값으로 `review_lock.py set`/`pause`·`approve_handoff.sh`를 호출 → 락·suppress가 `<interview-uuid>/state.local.md`에 기록된다.

두 파일이 다르므로 훅의 `is_review_active`가 harness-sid 파일에서 그 문서의 락 엔트리를 못 찾고 `False`(= fail-safe 강제)를 반환한다. → v0.18.0이 막으려던 바로 그 재강제가 **interview-originated 플로우에서 여전히 발생**한다. harness sid는 `/compact`/resume 경계에서 drift 하고 interview UUID는 그 사이 stable 하므로, 인터뷰를 이전 턴/`/compact` 전에 시작한 모든 실사용 경로에서 split 이 재현된다.

**본 세션 소스 검증에서 확인한 refinement:** handoff가 "별도 조사 필요"로 남긴 `cancel_review.py`는 실제로는 `resolve_session_id()`(env-first → harness sid)를 이미 쓴다 → split 대상이 **아니다**. split 은 오직 `reviewing-spec/SKILL.md`의 세 호출 지점에서만 발생한다. `approve_handoff.sh`는 자신의 `$1` sid 를 그대로 suppress/clear 로 전달하므로, 스킬이 넘기는 값이 잘못돼서 mis-keyed 될 뿐 스크립트 자체 로직은 정상이다.

## Goals

- G1. 훅이 읽는 harness-sid 상태 파일에 리뷰 락이 기록되어, 진행 중인 리뷰가 Stop / UserPromptSubmit 재강제를 no-op 시킨다 (재강제 루프 봉쇄).
- G2. approve(①/②) 및 pause(④) 시 suppress·lock-clear 도 harness-sid 파일에 반영되어, approve 후 같은 design 재편집 시 재-arm 되지 않는다 (suppress 대칭 복원).
- G3. 리뷰 강제 계약(Law 1) 100% 보존 — 락 부재/stale/env-unset 중 하나라도면 정상 dispatch (fail-safe = 강제) 방향 유지.
- G4. 회귀 락: split 재도입(스킬이 다시 interview UUID로 락을 set) 시 테스트가 red.

## Non-goals

- N1. interview-continuity state(`rereview_count`/`issue_history`/web budgets/`locked_directions`)의 저장 위치 변경. 이 신호들은 훅이 읽지 않으므로 interview UUID 파일에 그대로 둔다.
- N2. `conducting-interview` 스킬 수정. 인터뷰의 self-UUID 채택은 턴-경계 안정성의 근거이므로 보존한다.
- N3. 과거 세션의 interview-UUID 파일에 남은 stranded 락 엔트리 정리. 훅이 읽지 않아 무해하고, TTL 경과로 inert 하며, 세션 dir 은 SessionEnd / TTL-GC 가 제거한다.
- N4. continuity-state 파일 위치를 `/compact` drift 에 강하게 만드는 작업 — pre-existing 이며 이 버그와 별개. 인접 한계로 기록만 한다.

## Constraints

- C1. **소스에만 수정** — `plugins/spec-distill/`. 캐시(`~/.claude/plugins/cache/…/0.18.0/`)는 설치 산출물이라 건드리지 않는다.
- C2. **devbrew SemVer bump** — `plugin.json` `0.18.0 → 0.18.1` (patch: 버그 수정, 사용자-facing surface 무추가). 신규 `session-id` CLI 서브커맨드는 내부 헬퍼이지 command/skill/agent/hook surface 가 아니다.
- C3. **CHANGELOG** — `## [0.18.1] — YYYY-MM-DD`에 `### Fixed` 항목(락 session-id split → Stop 재강제 봉쇄; suppress/approve 대칭 포함).
- C4. **DRY 리졸버** — 스킬과 훅이 *정의상* 같은 sid 를 얻도록 `resolve_session_id`를 단일 소스로 재사용한다. 스킬이 raw `$CLAUDE_CODE_SESSION_ID`를 읽으면 `DEVBREW_SPEC_DISTILL_SESSION_ID` override + charset 검증과 어긋날 수 있으므로 금지.
- C5. **Law 1 fail-safe 방향** — 이 fix 는 리뷰 강제 계약을 *약화*하지 않는다. 락 부재/stale/env-unset 은 전부 정상 dispatch 로 귀결(과리뷰 > under-review).
- C6. **테스트 실행** — repo root 에서 `bash tests/…` / `-m unittest`. 직접 실행은 vacuous (memory `spec-distill test runner`).

## Acceptance Criteria

- AC1. `hooks/state_path.py`에 `session-id` CLI 서브커맨드 추가: env-only(`resolve_session_id(None)`) 결과를 stdout 에 print(exit 0); 미해석 시 stdout 무출력 + exit 1.
- AC2. `skills/reviewing-spec/SKILL.md` Step 1 락 refresh 가 `state_path.py session-id`로 얻은 `$harness_sid`를 `review_lock.py set`에 넘긴다 (`$session_id` 아님).
- AC3. 같은 스킬의 Phase 5 ④ `review_lock.py pause`(현 line 118)와 Approve handoff `approve_handoff.sh`(현 line 136)도 `$harness_sid`를 넘긴다.
- AC4. 스킬 산문에 불변식 명시: "락/suppress = harness sid(훅-facing); rereview_count/issue_history = interview UUID(continuity)".
- AC5. 스킬에 degradation 경로 명시: `$harness_sid`가 빈 값(env unset)이면 loud advisory + 락 op skip — 리뷰 강제는 유지(fail-safe).
- AC6. `plugin.json` version = `0.18.1`, `CHANGELOG.md`에 `[0.18.1]` `### Fixed` 항목 존재.
- AC7. **T1(behavioral, primary):** harness-sid state 에 `pending_review`(doc X) 세팅 후 — 락을 *interview UUID*에 set → `review-dispatch.py`(payload sid=harness) 실행 시 stdout 에 `"decision":"block"` **존재**(RED-repro); 락을 *harness sid*에 set → 동일 실행 시 stdout **빈**(no block)(GREEN). 두 assert 공존.
- AC8. **T2(skill doc 락, mutation-proven):** Step 1 윈도우 안에서 명령-라인 고유 토큰(`review_lock.py" set "$harness_sid`)을 grep. POS fixture(`set "$harness_sid"`) 매치 / NEG fixture(`set "$session_id"`) 비매치. 헤더-satisfiable 함정 회피(명령 라인 고유 토큰, 헤더만 남긴 mutation → red 증명).
- AC9. **T3(CLI unit):** `state_path.py session-id` — env set → 그 값 print + exit 0; env unset → exit 1 + `<none>` 미출력. `env -i "PATH=$PATH"` clean-env 패턴 재사용.
- AC10. **cancel_review 회귀 락(경량):** `cancel_review.py`가 `resolve_session_id()`(env-first harness sid)를 계속 쓰는지 assert — 미래에 interview UUID 인자로 되돌리는 회귀 차단.
- AC11. 기존 spec-distill 테스트 스위트 그대로 통과(회귀 0).

## Files to Modify

| 파일 | 변경 | AC |
|---|---|---|
| `plugins/spec-distill/hooks/state_path.py` | `main()`에 `session-id` 서브커맨드 추가 | AC1 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | 3 호출 지점(락 set/pause, approve_handoff)에 `$harness_sid` 사용 + 불변식·degradation 산문 | AC2–AC5 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | version `0.18.0 → 0.18.1` | AC6 |
| `plugins/spec-distill/CHANGELOG.md` | `[0.18.1]` `### Fixed` 항목 | AC6 |
| `plugins/spec-distill/tests/test_review_lock_session_id.sh` (신규) | T1 behavioral repro/fix | AC7 |
| `plugins/spec-distill/tests/test_reviewing_spec_lock.sh` (확장) | T2 mutation POS/NEG | AC8 |
| `plugins/spec-distill/tests/test_session_id_resolution.sh` (확장) | T3 `session-id` 서브커맨드 케이스 | AC9 |
| `plugins/spec-distill/tests/test_cancel_review.py` (확장) 또는 기존 assert 확인 | AC10 경량 회귀 락 | AC10 |

**변경 불필요(fix 는 transitive):** `scripts/cancel_review.py`(이미 harness sid), `scripts/approve_handoff.sh`(자신의 `$1` sid 를 정상 전달), `scripts/review_lock.py`(이미 `<sid>` arg 를 받음 — 로직 무변경).

## Verification Plan

1. **RED-before-fix 증명:** T1 의 GREEN assert 와 T2 의 POS assert 가 fix 전에는 red 임을 확인(스킬이 interview UUID 로 set 하는 현행에서 락이 harness-sid 파일에 없으므로 dispatch 억제 실패).
2. **T1/T2/T3/AC10** 신규·확장 테스트 통과.
3. **전체 스위트 회귀 0** — `tests/` 의 모든 `bash tests/…`/`-m unittest` green (repo root 실행).
4. **teeth 증명(mutation):** T2 에서 명령 라인을 `$session_id`로 되돌리면 red, 헤더만 남긴 mutation 도 red 임을 확인.
5. **결정론적 훅 repro:** handoff §3d 스크립트 형태로 harness-sid 락 → no block / interview-UUID 락 → block 을 육안 확인.
6. **저장소 문화 실행 형태:** subagent-driven, task 2-단계 리뷰 + whole-branch 리뷰 + `/qg`(codex 모델-다양성 포함).

## Rejected Alternatives

- **Strategy B — Unify at root.** `conducting-interview`가 self-UUID 대신 harness sid 를 채택 → 모든 state 가 한 dir. 기각: harness sid 는 `/compact`/resume 에서 drift(handoff §3c 실측 `56f2bbd4`→`76305ecd`)하므로 continuity state 가 orphan → 인터뷰↔리뷰 연속성이 깨진다. 락 split 을 고치려다 continuity-orphan 이라는 다른 버그를 낳는다.
- **Strategy C — 스킬이 raw `$CLAUDE_CODE_SESSION_ID` 직접 읽기.** 기각: `DEVBREW_SPEC_DISTILL_SESSION_ID` override + charset/length 검증을 우회 → 훅과 sid 가 어긋날 수 있다. CLI 리졸버가 precedence 를 한 곳에 유지(C4).
- **Runtime heuristic — `pending_review`가 실제 있는 dir 를 스캔해 그 sid 사용.** 기각: 여러 dir 에 `pending_review`가 있거나 없을 때 모호. `resolve_session_id(None)` env-precedence 가 훅과 정의상 동일하므로 더 결정론적.

## Metadata

- **Author:** brainstorming (spec-distill fix 세션), 2026-07-05.
- **Source handoff:** `docs/superpowers/handoffs/2026-07-05-spec-distill-review-lock-session-id-split.md`.
- **Related memory:** `reference_spec_distill_session_id_split`, `grep_lock_header_satisfiable`, `feedback_review_subagent_baseline_checkout_detaches_head`, `evidence_before_approved`, `reference_spec_distill_test_runner`.
- **Cross-ref:** CHANGELOG [0.18.0] "subagent 경계 Stop 재발동" — 이 fix 는 그 fix 가 interview-originated 플로우에서 미완(락은 도입됐으나 잘못된 sid 로 keyed)임을 닫는다.
- **Next step:** `superpowers:writing-plans`.
