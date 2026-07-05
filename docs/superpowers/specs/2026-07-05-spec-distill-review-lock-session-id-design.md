# Design — spec-distill review-in-progress 락 session-id split 수정 (v0.19.0)

> **One-line:** `reviewing-spec` 스킬이 리뷰 락·suppress·approve를 **interview UUID**로 keyed 하는데 훅은 **harness sid**로 읽는다 → 락 미발견 → Stop 재강제 루프. 스킬이 hook-facing trio(pending_review·lock·suppress)의 읽기/쓰기 모두에 harness sid를 쓰도록 bridge 한다.

- **상태:** 설계 (brainstorming 산출, round 3 — spec-reviewer round-1·2 needs_revise 반영).
- **영향 버전:** spec-distill `0.18.0` (main `00415d9`) → `0.19.0`.
- **Fix 브랜치:** `fix/spec-distill-review-lock-session-id` (main에서 분기).

---

## Context / Why

v0.18.0이 도입한 document-keyed `review_in_progress` 락은 subagent(async) dispatch 중 메인 `Stop` 훅이 진행 중인 리뷰를 재강제(중복 A / 절단 B)하는 오발을 봉쇄하려 했다. 그러나 락을 **쓰는 쪽**(reviewing-spec 스킬)과 **읽는 쪽**(Stop / UserPromptSubmit 훅)이 서로 다른 session-id 네임스페이스를 쓴다:

- **훅(reader)** — 세 훅 모두 `state_path.resolve_session_id(payload)`로 id를 얻는다. precedence는 `DEVBREW_SPEC_DISTILL_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → `payload["session_id"]` = **harness session id**. 상태 파일은 `<state_root>/<harness-sid>/state.local.md`. 특히 `spec-write-validator.py`의 `write_state()`는 `pending_review:` 블록을 **항상 harness-sid 디렉토리**에 기록한다(interview-uuid 디렉토리에 쓰는 경로가 없음).
- **스킬(writer)** — `reviewing-spec` Step 1이 상태 파일을 로드할 때 *어떻게* 그 파일을 해석하는지 명시가 없고(현행 SKILL.md에 `state_path.py` 호출 부재), frontmatter의 `session_id`(= 인터뷰가 자체 생성한 **interview UUID**)를 `$session_id`로 채택할 수 있다. 이 값으로 `review_lock.py set`/`pause`·`approve_handoff.sh`를 호출 → 락·suppress가 `<interview-uuid>/state.local.md`에 기록된다.

두 파일이 다르므로 훅의 `is_review_active`가 harness-sid 파일에서 그 문서의 락 엔트리를 못 찾고 `False`(= fail-safe 강제)를 반환한다. → v0.18.0이 막으려던 바로 그 재강제가 **interview-originated 플로우에서 여전히 발생**한다. harness sid는 `/compact`/resume 경계에서 drift 하고 interview UUID는 그 사이 stable 하므로, 인터뷰를 이전 턴/`/compact` 전에 시작한 모든 실사용 경로에서 split 이 재현된다.

**소스 검증 + spec-reviewer round-1·2 확인:** handoff가 "별도 조사 필요"로 남긴 `cancel_review.py`는 실제로 `resolve_session_id()`(env-first → harness sid)를 이미 쓴다 → split 대상이 **아니다**. `approve_handoff.sh`·`review_lock.py`는 넘겨받은 `<sid>` arg 를 `state_file_for(sid)`로 그대로 passthrough 한다(로직 무변경, transitive fix). split 은 오직 `reviewing-spec/SKILL.md`의 **정확히 세 호출 지점**(line 23 `set`, 118 `pause`, 136 `approve_handoff.sh`)에서만 발생한다(4번째 mis-keyed writer 없음 — repo-wide grep 확인). 이 fix 는 그 세 지점 + Step 1 의 pending/spec 읽기 디렉토리를 harness-sid 로 **명시적·결정론적**으로 고정한다. **continuity 카운터(`rereview_count`/`issue_history`)의 읽기·쓰기는 이 fix 범위 밖이며 `$harness_sid`로 collapse 하지 않는다**(§C7/N1 — collapse 시 인터뷰-선행 플로우에서 재-review cap 이 조용히 리셋될 위험, round-2 Issue e89c8825).

## Handoff Context

**TL;DR:** 리뷰 락/suppress/approve 를 쓰는 `reviewing-spec` 스킬은 interview UUID 로, 읽는 훅은 harness sid 로 keyed → 두 파일이 갈려 락이 안 보임 → Stop 재강제 루프. `state_path.py`에 env-only `session-id` CLI 서브커맨드를 추가하고, 스킬의 **세** hook-facing 호출 지점(락 set:23, pause:118, approve:136)과 Step 1 의 pending/spec 읽기를 그 CLI 가 주는 harness sid 로 고정한다. `cancel_review.py`·`approve_handoff.sh`·`review_lock.py`는 무변경(각각 이미 harness sid 이거나 sid passthrough). version `0.18.0 → 0.19.0`(minor).

**Implicit context (구현자 필독):**
- **hooks(reader)는 이미 옳다** — 세 훅 전부 `resolve_session_id(payload)`(env-first harness sid). PostToolUse `write_state()`는 `pending_review`를 **항상 harness-sid dir**에 기록. 그래서 fix 는 훅이 아니라 **스킬**만 건드린다.
- **정확히 3개 call site** (`SKILL.md:23` set, `:118` pause, `:136` approve_handoff.sh) — round-2 에서 byte-단위 재확인. 4번째 없음. `review_lock.py`·`approve_handoff.sh`는 넘긴 sid 를 `state_file_for(sid)`로 passthrough 하므로 **로직 무변경**(fix 는 caller-transitive).
- **continuity read collapse 금지** — `rereview_count`/`issue_history`는 인터뷰 선행 시 interview-UUID 파일에 쌓인다(`conducting-interview/SKILL.md:35-37` schema 확인). Step 1 의 pending/spec 읽기를 harness-sid 로 옮기되 continuity 읽기·쓰기(Step 5)는 **함께 옮기지 말 것** — 옮기면 인터뷰-선행 플로우에서 rereview_count 가 0 으로 리셋돼 re-review cap(5)/stagnation 조기-exit 가 약화된다(round-2 e89c8825).
- **fail-safe 방향 불변** — 락 부재/stale/env-unset 은 전부 정상 dispatch(리뷰 강제). 이 fix 는 강제 계약을 약화하지 않는다.
- **teeth 함정** — regression grep 은 명령-라인 고유 토큰을 grep 하고 헤더-satisfiable 을 피한다(memory `feedback_grep_lock_header_satisfiable`). POS/NEG fixture + 헤더-only mutation → red 로 증명.
- **root-cause chain**: `write_state`(harness-sid)→`is_review_active`(harness-sid) vs `review_lock.py set "$session_id"`(interview-UUID, `SKILL.md:23`→`review_lock.py:225`) → 락 미발견 → `review-dispatch.py:208` block 재emit.

**Deferred to plan:**
- 세 테스트의 정확한 grep 패턴·POS/NEG fixture·윈도우 경계(`sed -n` 범위)·exit-code 단언은 plan 에서 확정. 선례: `tests/test_reviewing_spec_lock.sh`(body-unique/POS-NEG), `tests/test_review_dispatch.sh`(임시 state_root + payload 구동), `tests/test_session_id_resolution.sh`(`env -i` clean-env).
- `state_path.py session-id` 구현 세부(exit code·stderr 문구)는 기존 `resolve_session_id` 재사용이라 trivial — plan 에서 6-라인 스케치.
- continuity-file 해석 메커니즘의 근본 정합화(interview-UUID 파일을 어떻게 찾는가)는 **이 fix 밖**(N4, pre-existing). plan 은 collapse-금지 가드만 건다.
- `## Handoff Context` 결정론적 훅 repro(§아래)는 문서-내 자기완결; plan 은 이를 T1 임시-state_root 패턴으로 코드화.

**결정론적 훅-레벨 repro (plan 이 T1 로 코드화):**
```bash
ROOT=$(mktemp -d); export DEVBREW_SPEC_DISTILL_SESSION_ID=hsid-aaaaaaaa
DOC='docs/superpowers/specs/2026-07-05-x-design.md'; mkdir -p "$ROOT/hsid-aaaaaaaa"
printf -- '---\nsession_id: hsid-aaaaaaaa\n---\n\npending_review:\n  path: %s\n  mode: design\n  triggered_at: 2000-01-01T00:00:00Z\n' "$DOC" > "$ROOT/hsid-aaaaaaaa/state.local.md"
python3 scripts/review_lock.py set iuuid-bbbbbbbb "$DOC"    # 버그: 락을 interview UUID에
echo '{"session_id":"hsid-aaaaaaaa"}' | python3 hooks/review-dispatch.py   # 기대: {"decision":"block",…}
python3 scripts/review_lock.py set hsid-aaaaaaaa "$DOC"     # fix: 락을 harness sid에
echo '{"session_id":"hsid-aaaaaaaa"}' | python3 hooks/review-dispatch.py   # 기대: 빈 stdout
```

## Goals

- G1. 훅이 읽는 harness-sid 상태 파일에 리뷰 락이 기록되어, 진행 중인 리뷰가 Stop / UserPromptSubmit 재강제를 no-op 시킨다 (재강제 루프 봉쇄).
- G2. approve(①/②) 및 pause(④) 시 suppress·lock-clear 도 harness-sid 파일에 반영되어, approve 후 같은 design 재편집 시 재-arm 되지 않는다 (suppress 대칭 복원).
- G3. 리뷰 강제 계약(Law 1) 100% 보존 — 락 부재/stale/env-unset 중 하나라도면 정상 dispatch (fail-safe = 강제) 방향 유지.
- G4. 회귀 락: split 재도입(세 호출 지점 중 어느 하나라도 interview UUID로 되돌림, 또는 continuity read 를 harness-sid 로 collapse) 시 테스트가 red.

## Non-goals

- N1. interview-continuity state(`rereview_count`/`issue_history`/web budgets/`locked_directions`)의 저장 위치 재설계 및 그 파일 해석 메커니즘 정합화. 이 신호들은 훅이 읽지 않으므로 read==write 불변식(C7) 대상이 **아니다** — 이 fix 는 hook-facing trio 만 harness-sid 로 고정하고 continuity 읽기·쓰기는 **건드리지 않는다**(collapse 금지). 인터뷰 선행 시 continuity 는 interview-UUID 파일에, 인터뷰 없이 brainstorming 진입 시 harness-sid 파일에 co-locate 됨(기존 동작 유지).
- N2. `conducting-interview` 스킬 수정. 인터뷰의 self-UUID 채택은 턴-경계 안정성의 근거이므로 보존한다.
- N3. 과거 세션의 interview-UUID 파일에 남은 stranded 락 엔트리 정리. 훅이 읽지 않아 무해하고, TTL 경과로 inert 하며, 세션 dir 은 SessionEnd / TTL-GC 가 제거한다.
- N4. continuity-state 파일을 어떻게 찾는가(interview-UUID dir 해석)의 근본 정합화 — pre-existing latent 이며 이 버그와 별개. 이 fix 는 그것을 *악화시키지 않음*(collapse 금지 가드)만 보장하고, 정합화 자체는 별도 작업으로 남긴다.

## Constraints

- C1. **소스에만 수정** — `plugins/spec-distill/`. 캐시는 건드리지 않는다.
- C2. **devbrew SemVer bump** — `plugin.json` `0.18.0 → 0.19.0` (**minor**). 근거: (a) `hooks/state_path.py`에 신규 `session-id` CLI 서브커맨드 추가 = 새 surface, (b) 이 플러그인의 확립된 관례상 버그-fix 도 minor 로 릴리스됨(CHANGELOG 확인: v0.15.0 Fixed, v0.16.0/v0.17.0 Removed 모두 minor). patch(0.18.1) 대신 minor 로 history 와 정합.
- C3. **CHANGELOG** — `## [0.19.0] — YYYY-MM-DD`에 `### Fixed`(락 session-id split → Stop 재강제 봉쇄; suppress/approve 대칭) + `### Added`(`state_path.py session-id` CLI 서브커맨드) 항목.
- C4. **DRY 리졸버** — 스킬과 훅이 *정의상* 같은 sid 를 얻도록 `resolve_session_id`를 단일 소스로 재사용한다. 스킬이 raw `$CLAUDE_CODE_SESSION_ID`를 읽으면 `DEVBREW_SPEC_DISTILL_SESSION_ID` override + charset 검증과 어긋날 수 있으므로 금지.
- C5. **Law 1 fail-safe 방향** — 이 fix 는 리뷰 강제 계약을 *약화*하지 않는다. 락 부재/stale/env-unset 은 전부 정상 dispatch 로 귀결(과리뷰 > under-review).
- C6. **테스트 실행** — repo root 에서 `bash tests/…` / `-m unittest`.
- C7. **read==write 디렉토리 불변식(hook-facing trio 한정)** — 스킬의 `pending_review`/`spec_path`/`mode` READ(Step 1)와 락·suppress·approve WRITE 는 **동일한** `state_path.py session-id`(harness sid)로 해석한 `$ROOT/$harness_sid/state.local.md` 를 대상으로 한다. **continuity(`rereview_count`/`issue_history`)는 이 불변식 대상이 아니며 `$harness_sid`로 collapse 하지 않는다**(N1).

## Acceptance Criteria

- AC1. `hooks/state_path.py`에 `session-id` CLI 서브커맨드 추가: env-only(`resolve_session_id(None)`) 결과를 stdout 에 print(exit 0); 미해석 시 stdout 무출력 + exit 1.
- AC2. `skills/reviewing-spec/SKILL.md` Step 1 이 (a) `harness_sid="$(python3 .../state_path.py session-id)"` + `ROOT="$(python3 .../state_path.py state-root)"` 로 상태 파일을 명시적으로 해석하고 그 파일에서 `pending_review`/`spec_path`/`mode` 를 읽으며, (b) `review_lock.py set` 에 `$harness_sid` 를 넘긴다(`$session_id` 아님). **(c) `rereview_count`/`issue_history` 읽기·쓰기(Step 1 continuity read + Step 5)는 이 변경에 포함하지 않는다 — `$harness_sid`로 치환 금지(collapse 방지, N1).**
- AC3. 같은 스킬의 Phase 5 ④ `review_lock.py pause`(현 line 118)와 Approve handoff `approve_handoff.sh`(현 line 136)도 `$harness_sid`를 넘긴다.
- AC4. 스킬 산문에 불변식 명시(한 문장): "hook-facing trio(`pending_review`·lock·suppress)의 read/write 는 harness sid; `rereview_count`/`issue_history` continuity 는 이 fix 가 건드리지 않고 harness-sid 로 collapse 하지 않는다". read==write 디렉토리 동일성(C7)도 명시.
- AC5. 스킬에 degradation 경로 + **verbatim advisory 문자열** 명시 — `$harness_sid`가 빈 값(env unset)일 때:
  - **`set`(Step 1):** 리뷰 락 refresh skip + 리뷰 강제 유지. SKILL.md 는 body-unique 문구 **`리뷰 락 refresh skip (리뷰 강제 유지)`** 를 포함한다.
  - **`pause`(④)/`approve_handoff`(①②):** 조용한 swallow 금지 — SKILL.md 는 body-unique 문구 **`이 stop/approve는 기록되지 않음`** 를 포함하고 `/spec-distill:cancel-review` 수동 경로를 안내한다.
- AC6. `plugin.json` version = `0.19.0`, `CHANGELOG.md`에 `[0.19.0]` `### Fixed` + `### Added` 항목 존재.
- AC7. **T1(behavioral, primary):** harness-sid state 에 `pending_review`(doc X) 세팅 후 — 락을 *interview UUID*에 set → `review-dispatch.py`(payload sid=harness) 실행 시 stdout 에 `"decision":"block"` **존재**(RED-repro); 락을 *harness sid*에 set → 동일 실행 시 stdout **빈**(no block)(GREEN). 두 assert 공존.
- AC8. **T2(skill doc 락, mutation-proven, 세 지점 전부):** `reviewing-spec/SKILL.md`의 **세 호출 지점 각각**을 자기 윈도우 안에서 명령-라인 고유 토큰으로 grep — `review_lock.py" set "$harness_sid`(Step 1 윈도우), `review_lock.py" pause "$harness_sid`(④ 윈도우), `approve_handoff.sh" "$harness_sid`(Approve handoff 윈도우). 각 지점 POS fixture(`$harness_sid`) 매치 / NEG fixture(`$session_id`) 비매치. 헤더-satisfiable 함정 회피(명령-라인 고유 토큰 + 헤더-only mutation → red).
- AC9. **T3(CLI unit):** `state_path.py session-id` — env set → 그 값 print + exit 0; env unset → exit 1 + `<none>` 미출력. `env -i "PATH=$PATH"` clean-env 패턴 재사용(`test_session_id_resolution.sh`).
- AC10. **cancel_review 회귀 락(경량):** `cancel_review.py`가 `resolve_session_id()`(env-first harness sid)를 계속 쓰는지 assert(`test_cancel_review.py` 확장 또는 grep 락) — 미래에 interview UUID 인자로 되돌리는 회귀 차단.
- AC11. **AC5 degradation 프로즈 락(teeth, exact literal):** `reviewing-spec/SKILL.md` 안에서 AC5 가 지정한 **정확한 body-unique 문자열** 두 개(`리뷰 락 refresh skip (리뷰 강제 유지)` 와 `이 stop/approve는 기록되지 않음`)를 `grep -F` 로 확인. 두 문자열은 헤더/불변식 산문에 등장하지 않는 명령-인접 프로즈이므로 header-satisfiable 아님. 해당 가드 프로즈 삭제 mutation → red.
- AC12. **read==write 디렉토리 프로즈 락(Issue e89c8825 round-1):** Step 1 윈도우 안에서 `state_path.py" session-id` 리터럴이 pending/spec 읽기 해석에 쓰임을 grep. 리터럴 삭제 mutation → red.
- AC13. **continuity non-collapse 락(Issue e89c8825 round-2, teeth):** `reviewing-spec/SKILL.md` 안에 body-unique 문구 **`continuity read collapse 금지`** 가 존재함을 `grep -F` 로 확인(AC2c/AC4 의 non-collapse 불변식 프로즈). 이 문구 삭제 mutation → red. (인터뷰-선행 rereview_count 보존의 완전한 behavioral 테스트는 prose-skill 특성상 불가 — 이 grep 락이 pragmatic teeth이고, AC8 이 `$harness_sid`를 정확히 3 지점에만 도입함을 POS/NEG 로 잠근다.)
- AC14. 기존 spec-distill 테스트 스위트 그대로 통과(회귀 0).

## Files to Modify

| 파일 | 변경 | AC |
|---|---|---|
| `plugins/spec-distill/hooks/state_path.py` | `main()`에 `session-id` 서브커맨드 추가 | AC1 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | Step 1 상태 해석 명시(session-id+state-root) + 3 호출 지점 `$harness_sid` + 불변식·non-collapse·degradation 산문 | AC2–AC5, AC13 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | version `0.18.0 → 0.19.0` | AC6 |
| `plugins/spec-distill/CHANGELOG.md` | `[0.19.0]` `### Fixed` + `### Added` | AC6 |
| `plugins/spec-distill/tests/test_review_lock_session_id.sh` (신규) | T1 behavioral repro/fix | AC7 |
| `plugins/spec-distill/tests/test_reviewing_spec_lock.sh` (확장) | T2 세 지점 mutation POS/NEG + AC11 degradation exact-literal + AC12 read-resolve + AC13 non-collapse | AC8, AC11–AC13 |
| `plugins/spec-distill/tests/test_session_id_resolution.sh` (확장) | T3 `session-id` 서브커맨드 케이스 | AC9 |
| `plugins/spec-distill/tests/test_cancel_review.py` (확장) | AC10 경량 회귀 락 | AC10 |

**변경 불필요(fix 는 transitive):** `scripts/cancel_review.py`(이미 harness sid — reviewer 확인), `scripts/approve_handoff.sh`·`scripts/review_lock.py`(넘겨받은 `<sid>` passthrough — reviewer 확인).

## Verification Plan

1. **RED-before-fix 증명:** T1 의 GREEN assert 와 T2 의 각 POS assert 가 fix 전에는 red(스킬이 interview UUID 로 set → 락이 harness-sid 파일에 없어 dispatch 억제 실패).
2. **T1/T2/T3 + AC10/AC11/AC12/AC13** 신규·확장 테스트 통과.
3. **전체 스위트 회귀 0** — `tests/` 의 모든 `bash tests/…`/`-m unittest` green (repo root 실행).
4. **teeth 증명(mutation):** 세 명령 라인을 각각 `$session_id`로 되돌리면 해당 T2 assert red + 헤더-only mutation red. AC11 의 두 exact-literal 삭제 → red. AC12 리터럴 삭제 → red. AC13 non-collapse 문구 삭제 → red.
5. **결정론적 훅 repro:** §Handoff Context 스크립트로 harness-sid 락 → no block / interview-UUID 락 → block 육안 확인.
6. **degradation 경로:** env unset 에서 `state_path.py session-id` exit 1 → 스킬 프로즈대로 advisory + set-skip(리뷰 강제 유지)임을 T3 + AC11 로 잠금.

## Rejected Alternatives

- **Strategy B — Unify at root.** `conducting-interview`가 self-UUID 대신 harness sid 를 채택 → 모든 state 가 한 dir. 기각: harness sid 는 `/compact`/resume 에서 drift(handoff §3c 실측 `56f2bbd4`→`76305ecd`)하므로 continuity state 가 orphan → 인터뷰↔리뷰 연속성이 깨진다. 락 split 을 고치려다 continuity-orphan 이라는 다른 버그를 낳는다.
- **Strategy C — 스킬이 raw `$CLAUDE_CODE_SESSION_ID` 직접 읽기.** 기각: `DEVBREW_SPEC_DISTILL_SESSION_ID` override + charset/length 검증을 우회 → 훅과 sid 가 어긋날 수 있다. CLI 리졸버가 precedence 를 한 곳에 유지(C4).
- **Runtime heuristic — `pending_review`가 실제 있는 dir 를 스캔해 그 sid 사용.** 기각: 여러 dir 에 `pending_review`가 있거나 없을 때 모호. `resolve_session_id(None)` env-precedence 가 훅과 정의상 동일하므로 더 결정론적.
- **continuity 도 harness-sid 로 collapse(review 전역 단일 파일).** 기각(round-2 e89c8825): 인터뷰-선행 플로우에서 `rereview_count`가 0 으로 리셋돼 re-review cap/stagnation 이 약화된다. 이 fix 는 trio 만 옮기고 continuity 는 보존한다.
- **patch bump(0.18.1) 유지.** 기각(round-1 advisory): 신규 CLI 서브커맨드 = 새 surface + 플러그인의 minor-for-fix 관례와 정합 위해 minor(0.19.0) 채택.

## Metadata

- **Author:** brainstorming (spec-distill fix 세션), 2026-07-05. Round 3 (spec-reviewer round-1 5-issue + round-2 3-issue 반영).
- **Source handoff:** `docs/superpowers/handoffs/2026-07-05-spec-distill-review-lock-session-id-split.md` (같은 브랜치 동봉 — in-situ 해석 가능).
- **Related memory:** `reference_spec_distill_session_id_split`, `feedback_grep_lock_header_satisfiable`, `feedback_review_subagent_baseline_checkout_detaches_head`, `evidence_before_approved`, `reference_spec_distill_test_runner`, `feedback_git_merge_over_rebase`.
- **Cross-ref:** CHANGELOG [0.18.0] "subagent 경계 Stop 재발동" — 이 fix 는 그 fix 가 interview-originated 플로우에서 미완(락은 도입됐으나 잘못된 sid 로 keyed)임을 닫는다.
- **Next step:** `superpowers:writing-plans`.
