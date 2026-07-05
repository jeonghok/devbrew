# Design — spec-distill review-in-progress 락 session-id split 수정 (v0.19.0)

> **One-line:** `reviewing-spec` 스킬이 리뷰 락·suppress·approve를 **interview UUID**로 keyed 하는데 훅은 **harness sid**로 읽는다 → 락 미발견 → Stop 재강제 루프. 스킬이 훅-facing 읽기/쓰기 모두에 harness sid를 쓰도록 bridge 한다.

- **상태:** 설계 (brainstorming 산출, round 2 — spec-reviewer needs_revise 반영).
- **영향 버전:** spec-distill `0.18.0` (main `00415d9`) → `0.19.0`.
- **Fix 브랜치:** `fix/spec-distill-review-lock-session-id` (main에서 분기).

---

## Context / Why

v0.18.0이 도입한 document-keyed `review_in_progress` 락은 subagent(async) dispatch 중 메인 `Stop` 훅이 진행 중인 리뷰를 재강제(중복 A / 절단 B)하는 오발을 봉쇄하려 했다. 그러나 락을 **쓰는 쪽**(reviewing-spec 스킬)과 **읽는 쪽**(Stop / UserPromptSubmit 훅)이 서로 다른 session-id 네임스페이스를 쓴다:

- **훅(reader)** — 세 훅 모두 `state_path.resolve_session_id(payload)`로 id를 얻는다. precedence는 `DEVBREW_SPEC_DISTILL_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → `payload["session_id"]` = **harness session id**. 상태 파일은 `<state_root>/<harness-sid>/state.local.md`. 특히 `spec-write-validator.py`의 `write_state()`는 `pending_review:` 블록을 **항상 harness-sid 디렉토리**에 기록한다(interview-uuid 디렉토리에 쓰는 경로가 없음).
- **스킬(writer)** — `reviewing-spec` Step 1이 상태 파일을 로드할 때 *어떻게* 그 파일을 해석하는지 명시가 없고(현행 SKILL.md에 `state_path.py` 호출 부재), frontmatter의 `session_id`(= 인터뷰가 자체 생성한 **interview UUID**)를 `$session_id`로 채택할 수 있다. 이 값으로 `review_lock.py set`/`pause`·`approve_handoff.sh`를 호출 → 락·suppress가 `<interview-uuid>/state.local.md`에 기록된다.

두 파일이 다르므로 훅의 `is_review_active`가 harness-sid 파일에서 그 문서의 락 엔트리를 못 찾고 `False`(= fail-safe 강제)를 반환한다. → v0.18.0이 막으려던 바로 그 재강제가 **interview-originated 플로우에서 여전히 발생**한다. harness sid는 `/compact`/resume 경계에서 drift 하고 interview UUID는 그 사이 stable 하므로, 인터뷰를 이전 턴/`/compact` 전에 시작한 모든 실사용 경로에서 split 이 재현된다.

**본 세션 소스 검증 + spec-reviewer round-1 확인:** handoff가 "별도 조사 필요"로 남긴 `cancel_review.py`는 실제로는 `resolve_session_id()`(env-first → harness sid)를 이미 쓴다 → split 대상이 **아니다**. `approve_handoff.sh`·`review_lock.py`는 넘겨받은 `<sid>` arg 를 그대로 passthrough 한다(로직 무변경, transitive fix). split 은 오직 `reviewing-spec/SKILL.md`의 **정확히 세 호출 지점**(line 23 `set`, 118 `pause`, 136 `approve_handoff.sh`)에서만 발생한다(4번째 mis-keyed writer 없음 — reviewer 확인). 근본 모호성은 스킬이 hook-facing 상태를 어느 디렉토리에서 읽고 쓰는지가 암묵적이라는 점이다 — 이 fix 는 그 디렉토리를 harness-sid 로 **명시적·결정론적**으로 고정한다.

## Handoff Context

이 절은 구현 세션(writing-plans/executor)이 대화 맥락 없이 착수하도록 자기완결적 재현·증거를 담는다. 더 상세한 진단 원문은 같은 브랜치에 동봉한 `docs/superpowers/handoffs/2026-07-05-spec-distill-review-lock-session-id-split.md`.

### Root-cause chain (파일:라인)

| # | 링크 | 파일:라인 | keyed by |
|---|---|---|---|
| 1 | PostToolUse가 `pending_review`를 harness-sid 파일에 기록 | `spec-write-validator.py:271-273, 145-149` | **harness sid** |
| 2 | Stop이 harness-sid 파일로 `is_review_active` 조회 | `review-dispatch.py:118, 158-168` | **harness sid** |
| 3 | UserPromptSubmit reminder도 harness-sid 파일 조회 | `pending-review-reminder.py:86-89, 100-113` | **harness sid** |
| 4 | 스킬이 `review_lock.py set "$session_id"` (interview UUID) | `reviewing-spec/SKILL.md:23` → `review_lock.py:225` | interview UUID |
| 5 | 락 미발견 → `is_review_active` False → 재강제 | `review_lock.py:199-210` → `review-dispatch.py:208` | — |

### 결정론적 훅-레벨 repro (파일만으로)

```bash
ROOT=$(mktemp -d)
export DEVBREW_SPEC_DISTILL_SESSION_ID=hsid-aaaaaaaa      # 훅이 볼 harness sid
DOC='docs/superpowers/specs/2026-07-05-x-design.md'
mkdir -p "$ROOT/hsid-aaaaaaaa"
cat > "$ROOT/hsid-aaaaaaaa/state.local.md" <<EOF
---
session_id: hsid-aaaaaaaa
---

pending_review:
  path: $DOC
  mode: design
  triggered_at: 2000-01-01T00:00:00Z
EOF
# 버그 재현: 락을 interview UUID에 set → Stop이 락 못 봄 → BLOCK(재강제)
python3 scripts/review_lock.py set iuuid-bbbbbbbb "$DOC"
echo '{"session_id":"hsid-aaaaaaaa"}' | python3 hooks/review-dispatch.py   # 기대: {"decision":"block",…}
# fix 검증: 락을 harness sid에 set → Stop no-op
python3 scripts/review_lock.py set hsid-aaaaaaaa "$DOC"
echo '{"session_id":"hsid-aaaaaaaa"}' | python3 hooks/review-dispatch.py   # 기대: 빈 stdout
```
(state_root 라우팅 때문에 실제 실행은 `test_review_dispatch.sh`의 임시 state_root + `state_file_for` monkeypatch 패턴을 따른다.)

### Live 증거 (본 세션 state_root 실측)

`state_root = <main_repo>/.claude/spec-distill`. 현 harness sid `186da17d-…`의 파일에는 `last_dispatched_at`만, 과거 세션 dir `5e42358f-…`/`bcccf21f-…`에는 clear 되지 못한 stranded `review_in_progress` 락이 남아 split 을 corroborate 한다.

### 환경·규약

- **소스만 수정**: `plugins/spec-distill/`. 캐시(`~/.claude/plugins/cache/…/0.18.0/`)는 설치 산출물 — 다음 설치 시 교체되므로 건드리지 않는다.
- **테스트 실행**: repo root 에서 `bash tests/…` / `python3 -m unittest`. 직접 실행은 vacuous(memory `reference_spec_distill_test_runner`).
- **저장소 문화**: subagent-driven, task 2-단계 리뷰 + whole-branch 리뷰 + `/qg`(codex 모델-다양성 포함). merge 는 merge-commit(rebase 금지 — memory `feedback_git_merge_over_rebase`).
- **base sid 관찰**: 훅이 실제로 `CLAUDE_CODE_SESSION_ID`(env)로 dispatch dir 를 정함을 확인함 — 이 env 값이 스킬 런타임에서도 읽히므로 bridge 경로가 성립.

## Goals

- G1. 훅이 읽는 harness-sid 상태 파일에 리뷰 락이 기록되어, 진행 중인 리뷰가 Stop / UserPromptSubmit 재강제를 no-op 시킨다 (재강제 루프 봉쇄).
- G2. approve(①/②) 및 pause(④) 시 suppress·lock-clear 도 harness-sid 파일에 반영되어, approve 후 같은 design 재편집 시 재-arm 되지 않는다 (suppress 대칭 복원).
- G3. 리뷰 강제 계약(Law 1) 100% 보존 — 락 부재/stale/env-unset 중 하나라도면 정상 dispatch (fail-safe = 강제) 방향 유지.
- G4. 회귀 락: split 재도입(세 호출 지점 중 어느 하나라도 interview UUID로 되돌림) 시 테스트가 red.

## Non-goals

- N1. interview-continuity state(`rereview_count`/`issue_history`/web budgets/`locked_directions`)의 저장 위치 자체를 재설계. 이 신호들은 훅이 읽지 않으므로 이 fix 의 read==write 불변식(§Constraints C7) 대상이 **아니다** — hook-facing trio(`pending_review`·lock·suppress)만 harness-sid 로 고정한다. 인터뷰가 선행한 경우 continuity 는 interview-UUID 파일에 남고, 인터뷰 없이 brainstorming 에서 시작한 경우 harness-sid 파일에 co-locate 된다.
- N2. `conducting-interview` 스킬 수정. 인터뷰의 self-UUID 채택은 턴-경계 안정성의 근거이므로 보존한다.
- N3. 과거 세션의 interview-UUID 파일에 남은 stranded 락 엔트리 정리. 훅이 읽지 않아 무해하고, TTL 경과로 inert 하며, 세션 dir 은 SessionEnd / TTL-GC 가 제거한다.
- N4. continuity-state 파일 위치를 `/compact` drift 에 강하게 만드는 작업 — pre-existing 이며 이 버그와 별개. 인접 한계로 기록만 한다. (reviewer round-1 Issue 5 가 지적한 continuity↔trigger 디렉토리 경계의 근본 정합화는 여기 포함되지 않는다 — 이 fix 는 hook-facing trio 의 read==write 만 확립한다.)

## Constraints

- C1. **소스에만 수정** — `plugins/spec-distill/`. 캐시는 건드리지 않는다.
- C2. **devbrew SemVer bump** — `plugin.json` `0.18.0 → 0.19.0` (**minor**). 근거: (a) `hooks/state_path.py`에 신규 `session-id` CLI 서브커맨드 추가 = 새 surface, (b) 이 플러그인의 확립된 관례상 버그-fix 도 minor 로 릴리스됨(v0.15.0 Fixed, v0.16.0/v0.17.0 Removed 모두 minor). patch(0.18.1) 대신 minor 를 채택해 history 와 정합.
- C3. **CHANGELOG** — `## [0.19.0] — YYYY-MM-DD`에 `### Fixed`(락 session-id split → Stop 재강제 봉쇄; suppress/approve 대칭) + `### Added`(`state_path.py session-id` CLI 서브커맨드) 항목.
- C4. **DRY 리졸버** — 스킬과 훅이 *정의상* 같은 sid 를 얻도록 `resolve_session_id`를 단일 소스로 재사용한다. 스킬이 raw `$CLAUDE_CODE_SESSION_ID`를 읽으면 `DEVBREW_SPEC_DISTILL_SESSION_ID` override + charset 검증과 어긋날 수 있으므로 금지.
- C5. **Law 1 fail-safe 방향** — 이 fix 는 리뷰 강제 계약을 *약화*하지 않는다. 락 부재/stale/env-unset 은 전부 정상 dispatch 로 귀결(과리뷰 > under-review).
- C6. **테스트 실행** — repo root 에서 `bash tests/…` / `-m unittest`.
- C7. **read==write 디렉토리 불변식(hook-facing trio)** — 스킬의 `pending_review`/`spec_path`/`mode` READ(Step 1)와 락·suppress·approve WRITE 는 **동일한** `state_path.py session-id`(harness sid)로 해석한 `$ROOT/$harness_sid/state.local.md` 를 대상으로 한다. 두 경로가 같은 함수로 해석되므로 read 와 write 가 정의상 같은 파일을 가리킨다.

## Acceptance Criteria

- AC1. `hooks/state_path.py`에 `session-id` CLI 서브커맨드 추가: env-only(`resolve_session_id(None)`) 결과를 stdout 에 print(exit 0); 미해석 시 stdout 무출력 + exit 1.
- AC2. `skills/reviewing-spec/SKILL.md` Step 1 이 (a) `harness_sid="$(python3 .../state_path.py session-id)"` + `ROOT="$(python3 .../state_path.py state-root)"` 로 상태 파일을 명시적으로 해석하고 그 파일에서 `pending_review`/`spec_path`/`mode` 를 읽으며, (b) `review_lock.py set` 에 `$harness_sid` 를 넘긴다(`$session_id` 아님).
- AC3. 같은 스킬의 Phase 5 ④ `review_lock.py pause`(현 line 118)와 Approve handoff `approve_handoff.sh`(현 line 136)도 `$harness_sid`를 넘긴다.
- AC4. 스킬 산문에 불변식 명시: "hook-facing trio(`pending_review`·lock·suppress)의 read/write 는 harness sid; `rereview_count`/`issue_history` continuity 는 인터뷰 선행 시 interview UUID(N1)". read==write 디렉토리 동일성(C7)을 한 문장으로 명시.
- AC5. 스킬에 degradation 경로 명시 — `$harness_sid`가 빈 값(env unset)일 때:
  - **`set`(Step 1):** loud advisory + 락 set skip — 리뷰 강제는 유지(fail-safe, Law 1).
  - **`pause`(④)/`approve_handoff`(①②):** loud advisory 로 "stop/approve 를 기록하지 못했다"를 노출(조용한 swallow 금지) + `/spec-distill:cancel-review` 수동 경로 안내. (over-nagging 방향이라 Law 1 위반 아님 — 단 사용자 의도 미반영을 명시적으로 알린다.)
- AC6. `plugin.json` version = `0.19.0`, `CHANGELOG.md`에 `[0.19.0]` `### Fixed` + `### Added` 항목 존재.
- AC7. **T1(behavioral, primary):** harness-sid state 에 `pending_review`(doc X) 세팅 후 — 락을 *interview UUID*에 set → `review-dispatch.py`(payload sid=harness) 실행 시 stdout 에 `"decision":"block"` **존재**(RED-repro); 락을 *harness sid*에 set → 동일 실행 시 stdout **빈**(no block)(GREEN). 두 assert 공존.
- AC8. **T2(skill doc 락, mutation-proven, 세 지점 전부):** `reviewing-spec/SKILL.md`의 **세 호출 지점 각각**을 자기 윈도우 안에서 명령-라인 고유 토큰으로 grep — `review_lock.py" set "$harness_sid`(Step 1 윈도우), `review_lock.py" pause "$harness_sid`(④ 윈도우), `approve_handoff.sh" "$harness_sid`(Approve handoff 윈도우). 각 지점 POS fixture(`$harness_sid`) 매치 / NEG fixture(`$session_id`) 비매치. 헤더-satisfiable 함정 회피(명령-라인 고유 토큰 + 헤더만 남긴 mutation → red 증명, memory `feedback_grep_lock_header_satisfiable`).
- AC9. **T3(CLI unit):** `state_path.py session-id` — env set → 그 값 print + exit 0; env unset → exit 1 + `<none>` 미출력. `env -i "PATH=$PATH"` clean-env 패턴 재사용(`test_session_id_resolution.sh`).
- AC10. **cancel_review 회귀 락(경량):** `cancel_review.py`가 `resolve_session_id()`(env-first harness sid)를 계속 쓰는지 assert(`test_cancel_review.py` 확장 또는 grep 락) — 미래에 interview UUID 인자로 되돌리는 회귀 차단.
- AC11. **AC5 degradation 프로즈 락(teeth):** `reviewing-spec/SKILL.md` 안에서 `$harness_sid` 빈-값 가드 + "락 skip / 리뷰 강제 유지"(set) + "stop/approve 미기록 advisory"(pause/approve)가 존재함을 body-unique grep 으로 확인. 가드 프로즈 삭제 mutation → red.
- AC12. **read==write 디렉토리 프로즈 락(Issue 5):** Step 1 윈도우 안에서 `state_path.py" session-id` 리터럴이 pending/spec 읽기 해석에 쓰임을 grep. 이 리터럴 삭제 mutation → red.
- AC13. 기존 spec-distill 테스트 스위트 그대로 통과(회귀 0).

## Files to Modify

| 파일 | 변경 | AC |
|---|---|---|
| `plugins/spec-distill/hooks/state_path.py` | `main()`에 `session-id` 서브커맨드 추가 | AC1 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | Step 1 상태 해석 명시(session-id+state-root) + 3 호출 지점 `$harness_sid` + 불변식·degradation 산문 | AC2–AC5 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | version `0.18.0 → 0.19.0` | AC6 |
| `plugins/spec-distill/CHANGELOG.md` | `[0.19.0]` `### Fixed` + `### Added` | AC6 |
| `plugins/spec-distill/tests/test_review_lock_session_id.sh` (신규) | T1 behavioral repro/fix | AC7 |
| `plugins/spec-distill/tests/test_reviewing_spec_lock.sh` (확장) | T2 세 지점 mutation POS/NEG + AC11 degradation 프로즈 + AC12 read-resolve 프로즈 | AC8, AC11, AC12 |
| `plugins/spec-distill/tests/test_session_id_resolution.sh` (확장) | T3 `session-id` 서브커맨드 케이스 | AC9 |
| `plugins/spec-distill/tests/test_cancel_review.py` (확장) | AC10 경량 회귀 락 | AC10 |

**변경 불필요(fix 는 transitive):** `scripts/cancel_review.py`(이미 harness sid — reviewer 확인), `scripts/approve_handoff.sh`·`scripts/review_lock.py`(넘겨받은 `<sid>` passthrough — reviewer 확인).

## Verification Plan

1. **RED-before-fix 증명:** T1 의 GREEN assert 와 T2 의 각 POS assert 가 fix 전에는 red 임을 확인(스킬이 interview UUID 로 set 하는 현행에서 락이 harness-sid 파일에 없어 dispatch 억제 실패).
2. **T1/T2/T3 + AC10/AC11/AC12** 신규·확장 테스트 통과.
3. **전체 스위트 회귀 0** — `tests/` 의 모든 `bash tests/…`/`-m unittest` green (repo root 실행).
4. **teeth 증명(mutation, 세 지점 전부):** T2 에서 세 명령 라인을 각각 `$session_id`로 되돌리면 해당 assert red, 헤더만 남긴 mutation 도 red. AC11/AC12 의 가드/리터럴 삭제도 red.
5. **결정론적 훅 repro:** §Handoff Context 스크립트로 harness-sid 락 → no block / interview-UUID 락 → block 을 육안 확인.
6. **degradation 경로:** env unset 상태에서 `state_path.py session-id` exit 1 → 스킬 프로즈대로 advisory + set-skip(리뷰 강제 유지)임을 T3 + AC11 로 잠금.

## Rejected Alternatives

- **Strategy B — Unify at root.** `conducting-interview`가 self-UUID 대신 harness sid 를 채택 → 모든 state 가 한 dir. 기각: harness sid 는 `/compact`/resume 에서 drift(handoff §3c 실측 `56f2bbd4`→`76305ecd`)하므로 continuity state 가 orphan → 인터뷰↔리뷰 연속성이 깨진다. 락 split 을 고치려다 continuity-orphan 이라는 다른 버그를 낳는다.
- **Strategy C — 스킬이 raw `$CLAUDE_CODE_SESSION_ID` 직접 읽기.** 기각: `DEVBREW_SPEC_DISTILL_SESSION_ID` override + charset/length 검증을 우회 → 훅과 sid 가 어긋날 수 있다. CLI 리졸버가 precedence 를 한 곳에 유지(C4).
- **Runtime heuristic — `pending_review`가 실제 있는 dir 를 스캔해 그 sid 사용.** 기각: 여러 dir 에 `pending_review`가 있거나 없을 때 모호. `resolve_session_id(None)` env-precedence 가 훅과 정의상 동일하므로 더 결정론적.
- **patch bump(0.18.1) 유지.** 기각(round-1 advisory): 신규 CLI 서브커맨드 = 새 surface + 플러그인의 minor-for-fix 관례와 정합 위해 minor(0.19.0) 채택.

## Metadata

- **Author:** brainstorming (spec-distill fix 세션), 2026-07-05. Round 2 (spec-reviewer round-1 needs_revise 5-issue 반영).
- **Source handoff:** `docs/superpowers/handoffs/2026-07-05-spec-distill-review-lock-session-id-split.md` (같은 브랜치 동봉 — in-situ 해석 가능).
- **Related memory:** `reference_spec_distill_session_id_split`, `feedback_grep_lock_header_satisfiable`, `feedback_review_subagent_baseline_checkout_detaches_head`, `evidence_before_approved`, `reference_spec_distill_test_runner`, `feedback_git_merge_over_rebase`.
- **Cross-ref:** CHANGELOG [0.18.0] "subagent 경계 Stop 재발동" — 이 fix 는 그 fix 가 interview-originated 플로우에서 미완(락은 도입됐으나 잘못된 sid 로 keyed)임을 닫는다.
- **Next step:** `superpowers:writing-plans`.
