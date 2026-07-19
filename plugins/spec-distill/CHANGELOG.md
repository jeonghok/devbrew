# Changelog

## [0.21.0] — 2026-07-19

### Changed
- **agent 3종(`spec-reviewer`·`breadth-keeper`·`steelman-builder`)을 `tools:` allowlist 로 전환** (fail-closed). 이전에는 denylist 만으로 격리돼 `Agent`·`Bash`·모든 MCP 도구를 보유했다 — denylist 는 공간(열거 누락)뿐 아니라 **시간에 대해서도 fail-open** 이다(내일 추가될 도구는 오늘 열거할 수 없다).
- 목록은 **트랜스크립트 census 실측**으로 도출했다. `spec-reviewer` 는 persona 가 한 번도 지시하지 않는 `Bash` 를 45회 부르고 **선언에 없는 `WebFetch`** 로 공식 문서를 가져와 검증한다 — persona 독해로 만든 목록은 안 쓰는 도구를 주고 쓰는 도구를 뺏었을 것이다.
- 죽은 `allowedTools` 키 제거 (`spec-reviewer`·`steelman-builder`) — 공식 subagent 규격의 필드가 아니라 무시된다.

### Added
- `spec-reviewer`·`breadth-keeper` 도구 표면 회귀 락 신설 — 가장 많이 dispatch 되는 리뷰어인데 락이 없었다.

## [0.20.0] — 2026-07-15

### Added
- **codex 병렬 독립 co-reviewer (Phase 3 design-doc 리뷰)** — model diversity를 quality-gates code-review에서 spec-distill의 design-doc 리뷰로 이식. `reviewing-spec`가 Claude `spec-reviewer`와 나란히 codex를 독립 실행하고, `scripts/merge_review.py`(결정론 merge/ledger 엔진)가 **보수적 병합**(precedence `needs_interview > needs_revise > approved`)으로 두 verdict를 합친다 — codex가 Claude의 approved를 needs_revise로 뒤집을 수 있다(fail-open 포착). codex는 `codex exec -s read-only` OS 샌드박스(Law 2 구조적).
- `scripts/detect_codex.sh` (vendored) — codex 가용성 감지. kill switch `DEVBREW_DISABLE_SPEC_DISTILL_CODEX`.
- `scripts/build_spec_codex_prompt.py` — design-doc 전용 codex 프롬프트(6 판단형 category, path-only 입력, severity vocab `block|high|medium`).
- `scripts/run_spec_codex_reviewer.sh` — 독립 codex subprocess(**discover-spec.sh AC 주입 없음** — 순환 footgun 회피, C3; mktemp C7 가드).
- `scripts/codex_findings_to_yaml.py` (vendored) — codex JSONL→YAML, emit 키셋에 `category`/`target_section` 추가.
- `scripts/compute_issue_id.py` — 중앙화 issue_id helper(`sha256_short(category + ":" + target_section)`). 두 리뷰어 이슈 모두 여기로 — cross-reviewer collision integrity.
- `scripts/merge_review.py` — 결정론 merge/ledger 엔진: 양쪽 출력 스크립트 파싱(LLM 전사 없음), verdict 유도, 보수적 병합, 4-branch degrade 계층(sentinel/`**Status:**`/codex-alone/fail-safe), 통합-원장 stagnation 스캔.
- tests: `test_detect_codex.sh`, `test_build_spec_codex_prompt.sh`, `test_codex_findings_to_yaml.py`, `test_compute_issue_id.py`, `test_run_spec_codex_reviewer.sh`, `test_merge_review.py`, `test_reviewing_spec_codex_merge.sh` + codex mocks.

### Changed
- `skills/reviewing-spec/SKILL.md` — ⟦detect⟧/⟦review-codex⟧/⟦merge⟧ 스텝 추가, "Stagnation detection" 절을 merge_review의 **통합-원장 스캔 flag**로 재작성(codex-only 반복 이슈 escalate; Claude self-report는 보조 신호). combined_verdict를 기존 routing table에 투입(표 불변). C8 verbatim `--claude-output` 저장.
- `agents/spec-reviewer.md` — issue를 **sentinel-fenced JSON block**(` ```spec-review-issues `, category/target_section/severity/message)으로 emit + top-level `**Status:**` verdict 라인 유지. issue_id self-report 제거(compute_issue_id가 계산). codex 존재 blind 유지.

### Security
- 두 리뷰어 모두 write-denied(codex `-s read-only` 샌드박스 + Claude disallowedTools), 리뷰 pass 상호 blind. codex 부재/실패는 fail-open(조용한 통과)도 fail-closed(spurious block)도 아닌 loud degrade.

### Fixed
- **fail-closed 하드닝 (`/qg` self-dogfood iter-1 적발; codex+silent-failure 모델다양성이 whole-branch·code-reviewer가 놓친 verdict-path fail-open 수렴 적발)** — `merge_review.py` 3건: (1) `parse_codex_yaml`이 opt-in-to-failed였음 — 존재하지만 비어있는/절단된 codex YAML(외부 SIGKILL/OOM/disk-full로 `OUTPUT_PATH`가 0-byte)이 `codex_failed` 마커 부재 시 **성공한 빈 리뷰로 오인** → advisory 없이 `approved`로 silently 통과(다른 모든 degrade 경로가 올리는 human-gate advisory backstop 무력화). opt-in-to-success로 반전 — **정확히 하나의** exact `true`/`false` 마커만 신뢰(부재·empty·garbage value·**중복 마커** 모두 fail-closed degrade + partial findings 폐기; `failed`는 sticky-True로 마커 순서 무관). isfile() 통과 후 open 실패(permission/TOCTOU/vanished)도 uncaught OSError crash가 아닌 loud degrade(`codex_yaml_unreadable`, `load_history` 가드와 대칭). (2) `derive_codex_verdict`가 off-vocab/missing severity(LLM drift `"critical"`/`""`)를 **approved 방향으로** 흘려보냄 → `CODEX_SEVERITY_KNOWN` 도입, 인식 불가 severity는 escalate(`medium`만 non-escalating 유지, §8). (3) `_write_history` `except OSError: pass`가 silent였음 → bool 반환 + 실패 시 loud advisory(원장 기록 실패 = cross-round stagnation degraded 명시) + orphan `.tmp` 정리. 3건 모두 mutation-test로 이빨 검증.
- `emit()` codex_findings 표시 블록 + degrade advisory가 `ensure_ascii=True`로 한국어를 `\uXXXX` escape → `ensure_ascii=False`로(Korean-primary 충실성, sibling `check_brief.py` 선례).
- `build_ledger`의 미사용 `codex_avail` 파라미터 제거(원장이 codex-availability-aware라는 오해 신호 + Pyright dead-param).

## [0.19.0] — 2026-07-05

### Fixed
- **review-lock session-id split → Stop 재강제 루프**: `reviewing-spec` 스킬이 리뷰 락·suppress·approve 를 **interview UUID** 로 keyed 했으나 훅(Stop/UserPromptSubmit/PostToolUse)은 **harness sid**(`resolve_session_id` env-first)로 상태를 읽어, 두 파일이 갈려 `is_review_active` 가 락을 못 찾고 `False`(fail-safe = 강제)를 반환 → v0.18.0 이 막으려던 subagent-경계 Stop 재강제가 **인터뷰-선행 플로우에서 여전히 발생**했다(harness sid 는 `/compact`/resume 에서 drift, interview UUID 는 stable). `reviewing-spec/SKILL.md` Step 1 이 `state_path.py session-id` + `state-root` 로 상태 파일을 명시 해석하고 세 hook-facing 호출 지점(락 `set`·`pause`, `approve_handoff.sh`)에 `$harness_sid` 를 넘겨 락·suppress·approve 가 훅이 읽는 파일에 기록되게 한다(read==write 디렉토리 불변식). approve 후 같은 design 재편집 시 재-arm 도 함께 해소(suppress 대칭 복원). `cancel_review.py`·`approve_handoff.sh`·`review_lock.py` 는 무변경(각각 이미 harness sid 이거나 sid passthrough). continuity(`rereview_count`/`issue_history`)는 harness-sid 로 collapse 하지 않아 인터뷰-선행 re-review cap/stagnation 을 보존(N1).

### Added
- `hooks/state_path.py` — `session-id` CLI 서브커맨드: env-only `resolve_session_id(None)` 결과를 stdout 에 print(exit 0), 미해석 시 stdout 무출력 + exit 1. 스킬과 훅이 *정의상 동일한* sid 를 얻는 단일 진입점(DRY 리졸버).
- `tests/test_review_lock_session_id.sh`(T1 behavioral 훅 repro) + `tests/test_reviewing_spec_lock.sh`·`tests/test_session_id_resolution.sh`·`tests/test_cancel_review.py` 회귀 락 확장(세 지점 mutation POS/NEG + degradation exact-literal + continuity non-collapse + cancel_review env-resolver 계약).

## [0.18.0] — 2026-07-02

### Added
- `scripts/review_lock.py` — **document-keyed(multi-key) `review_in_progress` 락**의 단일 소스. `set_lock`(그 키 엔트리 upsert/refresh, 나머지 보존)·`clear_lock`(그 키만 제거)·`pause`(clear + 같은-키 pending strip, suppress 없음 — resumable)·`is_review_active(body, pending_key, now, ttl)` + `{set|clear|pause}` CLI. 원자적 write(flush+fsync), stale prune, kill switch. `canonical_key`는 `suppress_state`에서 import(단일 정규화 소스).
- state.local.md `review_in_progress:` 엔트리 리스트(`suppressed_paths`와 동형) + `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` env(default 1800).
- `tests/test_review_lock.py`(유닛+CLI), `tests/test_reviewing_spec_lock.sh`(SKILL teeth 락).

### Changed
- `hooks/review-dispatch.py`(Stop) + `hooks/pending-review-reminder.py`(UserPromptSubmit) — suppress 체크 뒤·TTL 가드 앞에 `is_review_active` 게이트. 이 문서 락이 신선하면 no-op(pending 보존), 엔트리 부재/stale/파싱·import 예외면 정상 dispatch(fail-safe = 강제, Law 1). 다른 문서의 신선 엔트리는 pending_key 조회라 이 문서를 억제하지 않음(AC16).
- `skills/reviewing-spec/SKILL.md` — Step 1(매 진입)에서 `review_lock.py set`으로 그 문서 엔트리 refresh + Phase 5 옵션↔락 매핑표(①②=`approve_handoff.sh` clear, ③=재진입 refresh, ④=`review_lock.py pause`).
- `scripts/approve_handoff.sh` — suppress와 함께 `review_lock.py clear` 호출(그 문서 엔트리만). `scripts/cancel_review.py` — 취소 문서 키 엔트리 `clear`(approve 대칭, AC11).

### Fixed
- **subagent 경계 Stop 재발동**: `reviewing-spec`가 `spec-reviewer`를 async dispatch하고 await하려 턴을 멈출 때 발생하는 메인 `Stop`이, revise로 재-arm된 pending을 집어 리뷰를 (A) 중복 강제 / (B) 흐름 절단하던 오발. 문서별 락으로 "그 문서 리뷰 진행 중"을 표현해 봉쇄하되 리뷰 강제 계약(Law 1/2)은 100% 보존. 인터리브 2-문서 리뷰에서도 각 문서 보호 유지(multi-key, 한 문서 set이 다른 문서 락을 clobber 안 함).

### Removed
- `scripts/approve_handoff.sh`의 dead `git_common_dir`/`main_repo` 블록(v0.14.0에서 `rm -rf` 제거된 뒤 미사용).

## [0.17.0] — 2026-06-17

### Removed
- 인터뷰 월클락 메커니즘 **완전 제거**: `wall_clock_started_at` state 필드(conducting-interview schema) + reviewing-spec `## Steps` item 2의 wall-clock 체크(구 AC14) + Step 1 reader + `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` env var(양쪽 SKILL kill-switch + README) + README AP16 라인의 `wall-clock 30min` 토큰. 시계가 인터뷰 시작 시 켜지고 re-review 루프에서 트립해 *agent 자율성이 아니라 사람의 숙고 시간*을 오측정하던 footgun이었다 — AP16의 load-bearing 가드는 같은 루프의 re-review hard cap(5) + round-level stagnation early-exit이므로 월클락은 중복(redundant) 4번째 바운드였다. 구 세션 state의 잔여 `wall_clock_started_at` 키는 reader 부재로 무해하게 무시됨(migration 코드 불필요 — forward-compatible). harness-lightness(결정론은 load-bearing 게이트에만) + qg v2.0.0 월클락 budget 제거 선례에 정합. spec-distill은 v0.x라 one-minor deprecation window 면제 → 즉시 제거.

### Added
- `tests/test_no_wall_clock.sh` — 월클락 토큰(`wall_clock_started_at` / `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` / `wall-clock`) 재도입 방지 회귀 락. 라이브 surface 3파일(conducting-interview SKILL, reviewing-spec SKILL, README) 스캔, CHANGELOG는 history 보존이라 제외. v0.16.0 `test_hooks.sh` regression-lock 선례 패턴(repurpose 아닌 신규 파일).

### Changed
- `tests/test_readme_sync.sh` — 버전 기대값 0.16.0 → 0.17.0.

## [0.16.0] — 2026-06-16

### Removed
- `hooks/session-anchor.sh` (SessionStart 훅) + `hooks/hooks.json`의 SessionStart 등록. 이 훅은 이전 인터뷰 세션 디렉토리를 감지해 `/interview resume` 재진입을 안내했으나, `/interview resume`는 구현된 적이 없다(`commands/interview.md`에 resume 분기 부재) — state-storage 재설계에서 resume 커맨드가 사라진 뒤에도 안내 훅만 남아 매 세션 시작마다 실행 불가능한 조언을 LLM context에 주입하던 stale advisory였다. 훅은 P14 read-only advisor라 출력 소비처가 없고, 리뷰 흐름 상태(`pending_review`/`suppressed_paths`)는 UserPromptSubmit/Stop 훅이 독립 소비하므로 제거가 리뷰 파이프라인에 영향 없음. spec-distill은 v0.x라 one-minor deprecation window 면제 → 즉시 제거.

### Changed
- `tests/test_hooks.sh` — session-anchor 동작 테스트(기존 케이스 9–12)를 SessionStart 재도입 방지 회귀 락(hooks.json에 SessionStart 키 부재 + `session-anchor.sh` 파일 부재 두 단언)으로 재작성.
- `tests/test_hook_output_schema.py` — `TestSessionAnchorSchema` 클래스 및 `TestKillSwitches.test_global_disable_silences_session_anchor` 메서드 제거(`import shutil`은 다른 테스트가 사용하므로 유지).
- `README.md` — Hooks Installed 표의 SessionStart 행, Output schema 문장의 SessionStart 이벤트, Kill switches의 `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` 항목 제거.
- `tests/test_readme_sync.sh` — 버전 기대값 0.15.0 → 0.16.0.

## [0.15.0] — 2026-06-16

### Fixed
- `scripts/approve_handoff.sh` — **같은-턴 재dispatch 순서 버그**: `suppress_state.py add`(approved 키 기록 + same-key pending strip)를 working-tree 존재검사(`[[ -f ]]`) *앞으로* 이동. 기존엔 dangling/상대경로/서브디렉토리 cwd에서 `-f`가 먼저 `exit 1`로 빠져 suppress가 누락 → approve해도 같은 턴에 Stop hook이 재dispatch했다. canonical_key 기반 suppress는 파일 존재가 불필요하므로 이제 무조건 기록된다. (AC1)

### Changed
- `scripts/approve_handoff.sh` — `[[ -f ]]` 존재검사를 early-exit에서 **non-blocking advisory**로 강등. `exit 1`은 이제 **session_id charset/arg 검증 실패에 한정**(AC2). in-scope spec_path가 working-tree에 없어도 suppress 기록 + `exit 0` + stale advisory. 헤더 주석·최종 메시지를 v0.15.0 동작으로 갱신.
- `hooks/review-dispatch.py` (Stop) — pending의 path가 현재 세션 `suppressed_paths`에 있으면 **dispatch하지 않고** stale pending을 `suppress_state.strip_pending`으로 제거한다. **`last_dispatched_at`은 건드리지 않음**(TTL window 방지 — `cancel-review --reset` 직후 정당한 pending이 막히지 않도록, AC3b). `SCRIPTS_DIR`를 sys.path에 추가하고 `import suppress_state`를 `main()` try 블록 안에서 deferred 수행 — import 포함 모든 suppress-체크 예외는 fail-open(정상 dispatch, 과리뷰가 under-review보다 안전). Law 2 트리거/억제 대칭 복원. (AC3/AC4/AC5)
- `skills/reviewing-spec/SKILL.md` — "Approve handoff sequence" + "실패 시 state 보존" 절을 새 순서·exit 의미로 동기화.
- `tests/test_handoff_spec_path_validation.sh` — AC4a/AC4b를 새 계약(missing/dangling in-scope → `exit 0` + suppress 기록 + pending strip + advisory + dir 보존)으로 전환. `tests/test_review_dispatch.sh` — suppressed→no-dispatch+strip+TTL불변 / non-suppressed→dispatch 케이스 추가. `tests/test_hook_output_schema.py` — suppress import 실패 fail-open 단언 추가. `tests/test_readme_sync.sh` — 버전 0.14.0 → 0.15.0.
- `README.md` — Flow(v0.15.0) + Principles(Law 2 트리거/억제 대칭) 동기화.

### Notes
- W1(모델이 approve_handoff 자체를 미실행)은 구조적으로 막을 수단(PostToolUse가 AskUserQuestion approve를 감지)이 공식 문서상 보장되지 않아 제외 — `/spec-distill:cancel-review` escape hatch + (재발 증명 시) Law 3 persona/skill 편집이 stance.

## [0.14.0] — 2026-06-05

### Added
- `scripts/suppress_state.py` — per-doc·session-scoped `suppressed_paths` 집합의 **단일 소스**(정규화·pending strip·suppress). Python API(`canonical_key`/`pending_path`/`suppressed_keys`/`strip_pending`/`state_file_for`/`is_suppressed`/`add`/`remove`/`suppress_path`) + thin CLI(`{add|remove|is-suppressed} <sid> <raw_path>`). 정규화는 이 파일에만 존재 — 호출자는 raw 경로 위임(C4/AC17).
- `scripts/cancel_review.py` + `commands/cancel-review.md` — `/spec-distill:cancel-review [path] | --reset <path>`. 현재/지정 design 문서의 auto-review를 취소·억제(또는 재활성화). 리뷰 완료/중단 후 같은 문서 재편집 시 reviewing-spec가 재dispatch되던 두 gap(증상 A/B)을 끄는 사용자 주권(P17) 경로.
- Tests: `tests/test_cancel_review.py`(suppress_state 단위 + cancel_review 통합, AC1–AC8/AC11/AC14/AC17/AC19) + `test_spec_write_validator.sh`/`test_approve_handoff.sh` 확장.

### Changed
- `hooks/spec-write-validator.py` — Layer 1 통과 후 `write_state` 직전 `suppress_state.is_suppressed` 게이트: suppressed 문서는 arm skip + 전용 suppress advisory(기존 "Reviewer will be dispatched" 출력 *교체*) + return 0(AC9/AC18). Layer 1 구조 검증 불변(NG1/AC10). inline pending-strip re.sub → `suppress_state.strip_pending`(중복 제거).
- `scripts/approve_handoff.sh` — 세션 dir `rm -rf` → `suppress_state.py add`(approved 키 기록 + same-key pending strip). dir cleanup은 SessionEnd/TTL-GC로 이관 — 삭제 시 "승인됨" 기억 소실로 증상 A 재발(AC12). "idempotent by statelessness" → "idempotent by set-membership". `skills/reviewing-spec/SKILL.md`의 approve-handoff 계약 서술도 동기화.
- `tests/test_readme_sync.sh` — 버전 기대값 0.13.0 → 0.14.0 + `cancel-review` README 동기화 체크. `tests/test_handoff_compact_chain.sh` — approve가 dir 보존 + suppressed_paths 기록함을 검증하도록 계약 갱신.
- `README.md` — Flow(v0.14.0) + Hooks Installed(PostToolUse suppression 게이트) + Principles(P17 cancel/reset) + Kill switches(per-doc suppression 안내).

### Notes
- suppression은 **session-scoped**: SessionEnd cleanup이 dir를 삭제해 다음 세션은 fresh(NG4/AC15). 재리뷰는 `--reset <path>`, 다른 경로의 새 문서, 또는 reviewing-spec 직접 호출.
- `review-dispatch.py`(Stop)·`pending-review-reminder.py`(UserPromptSubmit)는 무변경 — pending_review가 안 생기므로 자연 no-op.

## [0.13.0] — 2026-06-04

### Added
- `skills/conducting-interview/SKILL.md` Step B — interview→brainstorming 핸드오프를 단일 `AskUserQuestion` **proceed 게이트**(3옵션: ① `/compact` 후 brainstorming 권장 / ② 바로 brainstorming / ③ brief만 종료)로 재작성. `reviewing-spec` Phase 5의 `/compact` 게이트와 **대칭** — 긴 인터뷰 context(round 대화·web sweep·steelman 중간산출)를 해답공간 진입 *전에* 정리할 수 있게. 두 가드 명문화: AP2 polite-stop 금지 + cross-compact 조기진행 금지(옵션 ① 노출 후 같은 턴 brainstorming 직진 금지, AC19 대칭, AC21). superpowers 부재 시 graceful degradation(brief terminal + loud advisory + STOP, 게이트 없음)은 보존(AC13). NG7(handoff 비강제)은 옵션 ③으로 가시화.
- Tests: `tests/test_conducting_interview_stage.sh`에 AC20(3옵션 게이트 + verbatim /compact) / AC21(i)(cross-compact stop wording, mechanical layer) / AC22(AP2 polite-stop ban) grep assert 추가.

### Changed
- `tests/test_readme_sync.sh` — 버전 동기화 기대값 `0.12.0 → 0.13.0`.
- `README.md` — Flow 다이어그램에 interview→brainstorming proceed 게이트 표기 + "Principles Instantiated" AP2에 interview-side `/compact` 대칭 게이트 한 줄.

### Notes
- `approve_handoff.sh`는 interview 쪽에서 **호출하지 않음** — brief는 같은 턴에 막 작성 + `check_brief.py` 검증되어 stale 위험이 없고, 세션 cleanup은 하류(brainstorming→reviewing-spec→spec→writing-plans의 approve_handoff) 또는 SessionEnd가 담당. 옵션 ① 노출 전 `[[ -f <brief-path> ]]` 경량 존재 가드만 둠(게이트 아님).
- `reviewing-spec` Phase 5는 무변경 — 본 작업은 interview 쪽 비대칭만 해소.

## [0.12.0] — 2026-06-01

### Added
- `scripts/web_budget.py` — interview web-research budget enforcer (per-sweep ≤4 / per-session ≤8, state-file counters). Subcommands `check` / `increment` (read-modify-write +1 both counters, preserving inline comments, then check) / `reset-sweep` (sweep boundary). The parser tolerates the schema's inline-comment counter format and fails closed on a present-but-non-numeric counter (never silent-0). Kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` short-circuits to ok (graceful degradation). (AC7/AC8/PN3)
- `scripts/check_brief.py` — interview-brief structural gate (7 sections / non-empty cited landscape / steelman-log well-formedness + frontmatter↔§4 cross-consistency / tried-&-discarded). Strips fenced code blocks before section detection (quoted headers can't satisfy the gate); an unreadable brief emits structured failure JSON, not a traceback. The Law 1 5-ritual termination gate, made mechanical. (AC2/AC4/AC5)
- `agents/steelman-builder.md` — scoped read-only adversarial counter-case builder (`disallowedTools: Write/Edit/MultiEdit/NotebookEdit`; `allowedTools` include WebSearch/WebFetch). Security-sensitive persona. (AC5/AC6)
- `templates/interview-brief-template.md` — canonical 7-section meta-prompt format. (AC1)
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` kill switch — disables interview web research, landscape skipped with loud log.
- Tests: `test_web_sweep_bound.sh`, `test_check_brief.sh`, `test_steelman_builder_scope.sh`, `test_conducting_interview_stage.sh`, `test_reviewing_spec_design_only.sh`, `test_readme_sync.sh` + brief/state fixtures; `test_hook_output_schema.py` design-doc + interview/-exclusion regression.

### Changed
- `skills/conducting-interview/SKILL.md` — re-positioned as a strong problem-space stage (Double Diamond 1st diamond): 5 통과 의례 (R1 Reframe / R2 Landscape / R3 Skepticism / R4 Tried-&-Discarded / R5 Open-Questions) as a Law 1 structural gate; web path(a) expansion; steelman gate; terminal interview-brief output at `docs/superpowers/interview/`; optional `superpowers:brainstorming` handoff. `cost_class: medium → variable`. State writes via Bash (worktree-safe — PN1).
- `commands/interview.md` — role reframed to problem-space stage (trivia escape unchanged, NG6).
- `skills/reviewing-spec/SKILL.md` — **design-mode only**: spec-mode routing rows + `[3.5]` re-consensus gate + `mode_b_violation` handling + `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS` removed (dead paths after drafting-spec removal). Design-doc review + Phase 5 proceed gate unchanged (Law 2 intact).
- `agents/spec-reviewer.md` — description/role refreshed for the design-only flow; clarified the interview brief is NOT its target (NG3). Mode branches + categories unchanged (C3 — not weakened).

### Removed
- `skills/drafting-spec/` (Mode A + Mode B) — the interview now produces a self-complete brief and brainstorming writes the design doc; design revisions are author-regression edits by the main agent, so the spec-writer skill is obsolete. (decision #10)
- Tests/fixtures for removed paths: `run-fixture-ac1.sh`, `interview-transcript-bbda.md`, `mode-b-guard-case.md`, `reconsensus-loop-case.md`, `routing-trace-cases.md`, `stagnation-cases.md`.

### Notes
- superpowers (`brainstorming`/`writing-plans`) remains an optional external plugin. With it absent, `/interview` completes at the brief and logs a loud advisory — no crash, no spec-mode fallback (AC13).
- Hooks are unchanged: `spec-write-validator.py` already classifies `-design.md` under `docs/superpowers/specs/` as design mode and auto-excludes `docs/superpowers/interview/` (outside `PATH_PREFIX`, C8).

## [0.11.3] — 2026-05-31

### Changed
- `tests/test_conducting_interview_internal.sh` — AC1 가드를 frontmatter 블록 한정으로 강화. 기존 `grep -q '^user-invocable: false$' "$SKILL"`는 파일 전체를 검사해, 이론적으로 키가 frontmatter 밖 본문에 있어도 통과할 수 있었음 (menu-visibility를 제어하지 않는 위치). `awk '/^---$/{c++} c==1'`로 첫 `---`…두 번째 `---` 블록만 추출 후 grep하여, 키가 실제로 frontmatter 안에 있을 때만 PASS. 파이프 대신 command-substitution+herestring으로 `set -uo pipefail` SIGPIPE 오탐 회피. 회귀: body-only 키 fixture로 AC1 FAIL 확인. (quality-gates v2.1.0 codex SUGGESTION #1, adversarial conf 3 — 비차단 polish.)

## [0.11.2] — 2026-05-31

### Changed
- `skills/conducting-interview/SKILL.md` — frontmatter에 `user-invocable: false` 추가. 내부 인터뷰 엔진 스킬을 `/` 슬래시 메뉴에서 숨겨 사용자 진입점을 `/interview` 하나로 단일화 (`/conducting-interview` 직접 호출 시 command의 kill switch·trivia escape 게이트 우회 → Law 1 진입 규율 무결성 보호). CC 공식 doc verbatim: `user-invocable`은 *"only controls menu visibility, not Skill tool access"* — command의 `Skill conducting-interview` dispatch·`reviewing-spec` re-entry·모델 자동 트리거는 전부 보존. `disable-model-invocation`은 정반대 효과(Skill tool 차단)라 미사용.

### Added
- `tests/test_conducting_interview_internal.sh` — 회귀 가드. `user-invocable: false` 존재(AC1) + 기존 frontmatter 3키 보존(AC2) + command dispatch·reviewing-spec re-entry 프로그램 호출 경로 보존(AC3). 누가 필드를 지우거나 dispatch 라인을 깨면 fail (Law 3 compounding).

## [0.11.0] — 2026-05-29

### Removed
- `hooks/compact-induction.py` — marker 기반 Stop-hook `/compact` 재주입 폐기. /compact 추천은 reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트로 이동 (hook은 AskUserQuestion을 띄울 수 없음).
- `hooks/compact-detect.py` — marker 삭제용 UserPromptSubmit hook. marker 부재로 무의미.
- `.claude/spec-distill/.markers/` marker 메커니즘 전체 + `approve_handoff.sh`의 named-status 상수(`HANDOFF_STATUS_*`)·packet emit·`dirty_blocked` exit-1.
- `scripts/spec-distill-gc.py`의 `_sweep_markers` — marker 미생성으로 sweep 대상 부재. **marker GC coverage 포기는 의도적** (markers는 v0.11.0부터 생성되지 않음).
- 테스트: `test_compact_induction_hook.sh`, `test_compact_induction_stagnation.sh`, `test_compact_detect_hook.sh`, `test_handoff_approve_packet_emit.sh`, `test_handoff_status_named.sh`, `test_gc.py`의 marker 케이스(test_13~16).

### Changed
- `skills/reviewing-spec/SKILL.md` Phase 5 — 단일 `AskUserQuestion` proceed 게이트(① /compact 후 writing-plans 권장 / ② 바로 writing-plans / ③ 수정 / ④ 멈춤)로 재구성. approve 후 2차 질문 없음. polite-stop(AP2) + cross-compact 조기 진행 금지(AC19) verifiable 기준 명문화. (구 packet의 verbatim `/compact` 명령 템플릿 — 본문 preserve / 인터뷰·기각대안·중간추론 drop / writing-plans next-step — 은 option ① prose로 이전.)
- `scripts/approve_handoff.sh` — thin finalizer로 축소: spec_path working-tree 존재 검증 + 세션 cleanup. 미커밋 검사는 advisory(non-blocking, exit 0).
- `hooks/hooks.json` — Stop=review-dispatch만, UserPromptSubmit=pending-review-reminder만. description 갱신.

### Fixed
- dangling `spec_path` 핸드오프 예외 — `[[ -f "$spec_path" ]]` working-tree 가드를 모든 git 조회 *이전*에 수행. 삭제된 worktree 경로(git HEAD tracked but working-tree absent)가 `git rev-parse HEAD` 성공으로 통과하던 결함 봉쇄.

### Added
- `tests/test_handoff_spec_path_validation.sh` — AC4a(부재) + AC4b(dangling worktree) 회귀.

### Security
- 없음. review-dispatch / pending-review-reminder / spec-reviewer persona 무변경 — review 강제(Law 1/2) 유지.

## [0.10.0] — 2026-05-27

### Added
- `hooks/compact-induction.py` — Stop event hook. `.claude/spec-distill/.markers/<sid>.emitted` marker 감지 시 `hookSpecificOutput.additionalContext`로 verbatim `/compact` 명령 + `Skill superpowers:writing-plans` 안내 emit. 5회 fire 도달 시 self-cleanup + stagnation advisory.
- `hooks/compact-detect.py` — UserPromptSubmit event hook. `user_prompt`/`user_message`/`prompt` 필드 lstrip + startswith로 `/compact` 또는 `Skill superpowers:writing-plans` 시작 감지 시 marker 삭제.
- `tests/test_handoff_status_named.sh` — Ouroboros named-status invariant (3 readonly 상수).
- `tests/test_compact_induction_hook.sh` — AC4/AC6/AC7/AC8 Stop hook contract.
- `tests/test_compact_detect_hook.sh` — AC5 lstrip+startswith 7-case.
- `tests/test_compact_induction_stagnation.sh` — AC6 5-fire self-cleanup.
- `tests/test_handoff_compact_chain.sh` — V9 end-to-end hook chain JSON contract.

### Changed
- `scripts/approve_handoff.sh` — **commit 단계 완전 제거** (LD4: spec은 사용자 책임). idempotent state machine으로 재설계: `HANDOFF_STATUS_ALREADY_DONE` / `HANDOFF_STATUS_DIRTY_BLOCKED` / `HANDOFF_STATUS_EMITTED` 3-status named-status (Ouroboros `handoff_contract.py` 패턴). marker file `.claude/spec-distill/.markers/<sid>.emitted`에 `STATUS=`/`TIMESTAMP=`/`FIRE_COUNT=`/`SPEC_PATH=` plaintext key=value 기록. 재호출 시 TIMESTAMP 보존 (dedupe invariant).
- `hooks/hooks.json` — UserPromptSubmit에 compact-detect.py, Stop에 compact-induction.py 등록 (기존 hook과 공존).
- `tests/test_approve_handoff.sh` — Case 1/5/7을 AC1/AC2/AC3 의미로 재작성. dirty_blocked stderr 4-token assertion + idempotent re-run TIMESTAMP preservation 검증. 모든 tmpfile은 per-run mktemp dir 안에서 처리 (CI parallel 안전).
- `scripts/spec-distill-gc.py` — `_sweep_markers()` 신규 헬퍼 + `gc()` 메인 루프에 한 줄 추가. `.markers/` 디렉토리의 24h+ stale marker 파일 정리 (기존 fcntl lock / TTL 패턴 재사용).

### Notes
- v0.9.0 에서 생성된 spec 파일은 grandfather migration 없음 (NG5). 기존 `.handoff-status` marker 부재 시 첫 approve_handoff.sh 호출에서 정상 생성.
- compact-detect.py는 `user_prompt`/`user_message`/`prompt` 세 키 모두 읽음 (Claude Code hook schema tolerance — 셋 중 하나 존재 시 처리. 실제 schema는 `user_prompt`이지만 spec 가정과의 forward compat 위해 fallback 유지).
- compact-induction.py와 review-dispatch.py는 같은 Stop 이벤트에 공존. 실 운영에서는 pending_review block 정리 후 marker가 생성되므로 두 hook이 동시에 emit하지는 않음.

## [0.9.0] — 2026-05-26

### Added
- `templates/spec-template.md` — `## Handoff Context` 섹션 신설 (`## Goal` 직후). TL;DR / Implicit context / Deferred to plan 3개 하위 항목. spec/design 파일 self-containedness baseline (G2, AC1).
- `agents/spec-reviewer.md` — `handoff_incomplete` block-severity 카테고리 (spec mode 11→12 카테고리, design mode 6→7 카테고리). 3개 sub-pattern (섹션 부재 / 하위 항목 미작성 / conversation reference 검출). 15개 conversation reference 패턴 enumerated (영어 8 + 한국어 7). v0.10.0+ list 확장 정책 명시.
- `scripts/approve_handoff.sh` — Step 2 출력 교체: minimal 2-line "다음 단계:"에서 3-block "Handoff packet" (divider / `/compact` 명령 with preserve+drop+next-step embed / `[2]` standalone safety net Skill writing-plans 라인 / 종료 divider). /compact preserve directive에 next-step instruction embed로 compact-survival best-effort 지원.
- `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` kill switch — `handoff_incomplete` 카테고리만 우회, 다른 검사는 정상. loud warning stderr 출력.
- `tests/test_handoff_*.sh` 6개 신규 test — AC2/AC3/AC4/AC5/AC6/AC7 (모두 `test_handoff_*` prefix로 V1 glob 일관).

### Changed
- spec/design 파일의 review 통과 기준이 self-containedness까지 확장. /compact 경계를 spec lifecycle의 1급 시민으로 승격 — Law 1 (Clarity Before Code) 자연스러운 확장.

### Notes
- Pre-v0.9.0 spec.md grandfather 처리 안 함 (design 문서 NG8 / R6). 기존 spec 재review 시 사용자가 `## Handoff Context` 섹션을 30초 분량 수동 추가 필요. reviewer가 추가 위치/내용을 recommendation으로 안내.

## [0.8.1] — 2026-05-26

### Fixed
- `agents/spec-reviewer.md` — Input/Design Mode Branch wording이 v0.8.0의 content-aware scope 확대를 반영하지 못하던 drift 정정. Input path는 `<file>-spec.md` 한정에서 `docs/superpowers/specs/` hierarchy 안 임의 `.md`로 일반화. Design Mode Branch trigger는 (a) `*-design.md` suffix, (b) suffix 없는 `.md`가 frontmatter `locked_decisions` 부재로 content-aware 판별, (c) dispatcher `mode: design` 명시 — 세 갈래를 명시. Hook 결정론과 reviewer self-narrative 정렬 (Law 2 baseline operability).
- `hooks/spec-write-validator.py` docstring + `README.md` Hooks 표 + `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` 설명에 "sub-folder hierarchy 포함" 명시. v0.8.0 시점부터 `resolve_mode()`의 `PATH_PREFIX in file_path` substring 매칭이 sub-folder를 자동 포함하던 것을 contract로 박제.
- `skills/reviewing-spec/SKILL.md` — `mode: design` 분기 설명에서 "brainstorming의 design.md" → "design 모드 파일 (suffix 또는 content-aware)"로 mechanism-agnostic 표현으로 정정.

### Added
- `tests/test_resolve_mode_scope.sh` — sub-folder 회귀 가드 5 case 추가 (depth-1 `-spec.md`, depth-1 `-design.md`, depth-2 content-aware spec, depth-1 content-aware design, hierarchy boundary 위반 false-positive 차단 `specs_archive/`).

## [0.8.0] — 2026-05-22

### Changed
- `hooks/spec-write-validator.py`:`resolve_mode()` — review 게이트 범위를 `docs/superpowers/specs/` 아래 **모든 `.md`**로 확대(기존: `-spec.md`/`-design.md` suffix만). suffix 없는 `.md`는 신규 `_frontmatter_has_locked_decisions()` inline 헬퍼로 mode 판별: 첫 `---`…`---` frontmatter 블록에 `locked_decisions` 키 있으면 `spec`, 없으면 `design`. body 언급·unclosed frontmatter·디코드 실패는 `design`(안전 fallback) + loud stderr. reviewing-spec routing·검사 로직·state 스키마 불변. review 강제(Law 2)가 파일명 컨벤션에 의존하던 취약점 제거.

## [0.7.0] — 2026-05-22

### Removed
- `hooks/interview-trigger.sh` + `hooks.json` UserPromptSubmit 등록 — advisory build/make nudge 훅. ~80개 세션 트랜스크립트 hook-attachment 전수 스캔 결과 3주간 0회 발화 (trigger 조건 `키워드 + <20단어`가 실사용 프롬프트와 미매칭). 훅 surface는 review 강제(Law 2)로 정당화되며 interview 진입은 `/interview` 직접 호출로 충분 — advisory(`additionalContext`)는 모델이 무시 가능해 비결정적. `hooks.json` `description`에서 "interview" 문구 제거.
- `hooks/state_path.py`:`cleanup_stale_states()` 함수 전체 블록 + `DEPRECATION_MARKER` 상수 + 모듈 docstring `cleanup` CLI 줄 + `main()`의 `cleanup` 분기·usage 토큰 — v0.6.0에 deprecated된 no-op(약속대로 제거). 호출처 없음 (TTL-GC + SessionEnd hook이 정리 담당). `tests/test_state_cleanup.sh` 삭제.
- 테스트 정리: `tests/test_hook_output_schema.py`의 `TestInterviewTriggerSchema` + `test_global_disable_silences_interview_trigger`, `tests/test_hooks.sh`의 interview-trigger 섹션, `README.md` Hooks Installed 표의 interview-trigger 행.

## [0.6.0] — 2026-05-19

### Added
- `hooks/session-end-cleanup.py` — SessionEnd hook for deterministic per-session state cleanup (qg pattern adaptation, git-aware path).
- `scripts/spec-distill-gc.py` — TTL-based GC (24h) with fcntl lock + double-stat ns + rename-then-rmtree race guard. `.gc-pending-*` orphan sweep (>60s) on each invocation.
- `scripts/approve_handoff.sh` — atomic AC11 approve handoff (4-step: commit / handoff pointer / cleanup / termination). Extracted from `skills/reviewing-spec/SKILL.md` prose.
- `hooks/state_path.py`:`resolve_session_id(payload)` + `SESSION_PATTERN` — single source of truth for session_id, charset/length validation.
- 7 new tests: `test_session_id_resolution.sh`, `test_session_end_cleanup.py`, `test_gc.py`, `test_approve_handoff.sh`, `test_stale_state_truncate.sh`, `test_brainstorming_entry.sh`, `test_kill_switches_v060.sh`.

### Changed
- `hooks/spec-write-validator.py`, `hooks/review-dispatch.py`, `hooks/pending-review-reminder.py` — session_id source switched from `os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")` literal fallback to `resolve_session_id(payload)`. Production now resolves from `CLAUDE_CODE_SESSION_ID`. `DEVBREW_SPEC_DISTILL_SESSION_ID` retained as test override.
- `hooks/spec-write-validator.py`:`write_state` — defensive truncate when existing state.local.md frontmatter `session_id` ≠ current (defense-in-depth).
- `hooks/spec-write-validator.py` — AC14 legacy advisory: detect `.claude/spec-distill/default/` and emit one-shot stderr advisory (marker `.legacy-advisory-emitted-v060`).
- `hooks/hooks.json` — SessionEnd event registered.
- `skills/reviewing-spec/SKILL.md` — AC11 4-step prose replaced with 1-line `approve_handoff.sh` script call.

### Deprecated
- `hooks/state_path.py`:`cleanup_stale_states` — no-op + marker-based one-shot deprecation stderr. Removed in v0.7.0.

### Fixed
- 잔여 frontmatter bug (사용자 보고 2026-05-19): `.claude/spec-distill/default/state.local.md`에 이전 세션의 frontmatter가 누적되어 새 세션이 stale data 위에 쓰는 증상. Root cause: `DEVBREW_SPEC_DISTILL_SESSION_ID` 부재 시 모든 hook이 `"default"` literal로 fallback → singleton file 공유. Fix: `CLAUDE_CODE_SESSION_ID` 단일 source + SessionEnd hook + TTL-GC + write_state defensive truncate (4-layer defense).

### Security
- session_id charset validation `^[A-Za-z0-9_-]{8,}$` 모든 cleanup path (SessionEnd hook, TTL-GC, approve_handoff.sh, write_state)에 적용 — `../traversal` 등 path injection 차단.

## [0.5.1] — 2026-05-17

### Fixed
- `reviewing-spec/SKILL.md` Re-review cap drift — v0.3.0가 body section의 hard cap을 `>= 3` → `>= 5`로 상향했으나 동일 파일의 (a) frontmatter description (`max 3`), (b) Deterministic Routing Table 5개 행 (spec `< 3` / `>= 3` × 2 + design `< 3` / `>= 3`), (c) `README.md` ASCII flow `max 3`, (d) `tests/test_reviewing_spec_design_routing.sh`의 `count >= 3` assertion이 갱신되지 않아 cap=5가 *dead code*였음. Routing table의 `>= 3` 행이 먼저 fire하여 v0.2.0의 cap=3과 동등하게 동작. 본 PR이 5개 위치 모두 5로 통일하여 v0.3.0 의도가 비로소 enforce됨. **Behavioral change**: re-review가 이제 실제로 4–5회 반복 가능 (이전엔 3회에서 forced Human Gate).

### Added
- `tests/test_rereview_cap_consistency.sh` — cross-file invariant test. SKILL.md body의 `Hard cap**: \`rereview_count >= N\`` 라인에서 N을 source-of-truth로 추출 후 8개 derived 위치 (SKILL.md frontmatter + routing 4행 + README ASCII flow + README AP16 + design-routing test)가 모두 같은 N을 사용하는지 검증. devbrew Law 3 (Compounding) instantiation — 미래 cap 변경 시 derived 갱신을 빠뜨리면 즉시 fail.

## [0.5.0] — 2026-05-17

### Fixed
- 5개 hook (`review-dispatch.py`, `spec-write-validator.py` advisory 분기, `pending-review-reminder.py`, `interview-trigger.sh`, `session-anchor.sh`) 의 stdout JSON이 Claude LLM context로 도달하지 않던 silent failure. `systemMessage` 필드는 Claude Code 사양상 user transcript 표시 전용이며 LLM context inject 메커니즘이 아니다. 올바른 필드는 `hookSpecificOutput.additionalContext` (PostToolUse/UserPromptSubmit/SessionStart) 또는 Stop hook의 `decision:"block" + reason` 페어. dual-target 출력 (Claude-target field + `systemMessage` 짧은 흔적, ≤120자, "[spec-distill]" prefix) 으로 정정 — Claude는 context로 받고 user는 transcript에서 발화 흔적 확인 가능.
- `review-dispatch.py` `rewrite_state()` 호출 순서 정정 (write-before-emit, AC7.1). `rewrite_state()` 본문에 `f.flush()` + `os.fsync(f.fileno())` 추가하여 OS-level durability 보장. 이전 ordering (print → rewrite) 은 동일 turn 안에서 두 번째 Stop fire가 stale state를 읽고 두 번째 block 출력하는 block storm을 일으킬 수 있었음.
- `review-dispatch.py` rewrite OSError 시 `{}` exit 0 (block emit 안 함, AC7.2). 이번 dispatch 1회는 누락되나 L4b UserPromptSubmit reminder가 다음 user prompt에서 dispatch를 살림 — block storm 회피가 우선.
- `interview-trigger.sh` no-jq fallback에 `tr -d '\r'` 추가하여 session-anchor.sh와 CR 처리 대칭.

### Changed
- Stop hook (`review-dispatch.py`) 의 `decision:"block"` 이 Stop을 막고 Claude를 즉시 continue 시키므로 "다음 turn 첫 액션은 reviewing-spec" 강제가 user 입력 대기 없이 작동. 기존 30초 TTL guard (`DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`) 가 무한 block 루프 방지를 그대로 담당.

### Added
- `tests/test_hook_output_schema.py` — Python `unittest` 기반 통합 회귀 방지 test. 5개 hook 모두에 대해 happy-path schema assertion + AC1a 인코딩 round-trip + AC7.2 fault injection + AC7.3 ordering 3-prong (AST inspection + mock-based trace) + AC10/AC11 kill switch + NG9 cross-resolver advisory (skipUnless worktree). bash fallback (jq-없는 환경) 케이스는 `unittest.skipUnless`로 환경 감지.

### Security
- kill switch 5개 (`DEVBREW_DISABLE_SPEC_DISTILL=1` 전역 + `DEVBREW_SKIP_HOOKS=spec-distill:<event>` hook 단위) 모두 무변경. 신규 env var 없음.
- bash hook no-jq fallback escape scope: backslash + double-quote + LF + CR만 처리. null byte / 기타 control char / non-BMP unicode는 처리 범위 밖 — jq path에서 full JSON escape 처리.

## [0.4.0] — 2026-05-17

### Added
- `hooks/state_path.py` — main repo root 해석 helper (`git rev-parse --git-common-dir` 기반). state 파일을 항상 main repo `.claude/spec-distill/` 아래에 기록 (worktree 호출 시에도). cwd fallback + stderr loud log (philosophy §4.8 instantiation).
- `hooks/pending-review-reminder.py` — UserPromptSubmit hook. pending_review가 살아있고 last_dispatched_at > TTL(30s)이면 mandate 재emit (L4b redundancy). Kill switch `spec-distill:UserPromptSubmit` / `spec-distill:reminder`.
- State cleanup 정책: pending_review `triggered_at` > 24h → block auto-purge, last_dispatched_at만 있는 state file > 7일 → file auto-delete. 신규 env var 없이 하드코딩.
- reviewing-spec SKILL.md — Step 1 `pending_review.mode` 분기 + Routing Table에 design rows 3개 추가 (approved → writing-plans, needs_revise < 3 → brainstorming author 회귀, needs_revise ≥ 3 → forced Human Gate). drafting-spec Mode B는 design.md에 호출하지 *않음*.
- agents/spec-reviewer.md — design mode checklist 분기 섹션 6 카테고리 (placeholder / ambiguity / scope_creep / approaches_comparison / isolation / testing). spec mode 본문 무손상.
- 신규 test 6개: `test_state_path.sh`, `test_state_cleanup.sh`, `test_design_mode_validator.sh`, `test_review_dispatch_design_mandate.sh`, `test_reminder_hook.sh`, `test_reviewing_spec_design_routing.sh`, `test_spec_reviewer_design_checklist.sh`.
- 신규 fixture 2개: `tests/fixtures/2026-05-17-test-design.md` (valid), `tests/fixtures/2026-05-17-test-design-bad.md` (placeholder + ambiguity hits).

### Changed
- `hooks/spec-write-validator.py` — state path을 `state_path.state_root()`로 해석, pending_review block에 `worktree_path:` 필드 추가.
- `hooks/review-dispatch.py` — state path을 state_path helper로 해석, mandate systemMessage 본문에 "타 terminal handoff(writing-plans 등) 보류" 문구 + worktree_path 포함, fire마다 `cleanup_stale_states` 호출.
- `hooks/hooks.json` — UserPromptSubmit에 reminder hook 등록 (기존 interview-trigger.sh 옆).

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중. 신규 env var 없음 (LD10 일관성).
- bare repo / submodule / nested worktree / `.git` symlink는 supported scope 밖 — state_path cwd fallback + loud log로 운영자 인지 (NG6).

## [0.3.0] — 2026-05-16

### Added
- PostToolUse hook `hooks/spec-write-validator.py` — spec/design 파일 write를 file-system level에서 가로채 Layer 1 mechanical 검증 (11 sections, frontmatter, locked_decisions schema, ambiguity blacklist, design-mode placeholder scan).
- Stop hook `hooks/review-dispatch.py` — `pending_review:` ledger 기반 결정론적 reviewer dispatch (systemMessage 주입).
- `scripts/parse_spec_structure.py` — frontmatter / sections / locked-decisions / ambiguity / placeholders CLI subcommand 라이브러리.
- `scripts/ambiguity-blacklist.txt` — 측정 불가 키워드 + `~` escape 지원.
- design.md (brainstorming upstream 산출물) 커버리지 — suffix-based mode 분기, frontmatter optional, ambiguity + placeholder만 검사.
- 7 fixture 파일 (`tests/fixtures/`) + `test_spec_write_validator.sh` + `test_review_dispatch.sh`.
- Kill switches: `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`, `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<sec>`.

### Changed
- `reviewing-spec/SKILL.md` Step 1 — dispatch trigger가 hook-driven (file ledger `pending_review:` block) 임을 명시.
- `reviewing-spec/SKILL.md` Re-review cap — hard cap `>= 3` → `>= 5` + round-level stagnation early-exit (verdict `needs_revise` + `Stagnation_signal: true` → 즉시 [5] Human Gate). multi-round drift detection을 위한 budget 확장.
- `drafting-spec/SKILL.md` Mode A/B — handoff 단계에서 명시 reviewing-spec 호출 불필요, hook이 결정론 dispatch함을 note.

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중.
- PostToolUse exit 2 + stderr 차단 패턴 + stdout `{"decision":"block"}` 이중 안전.

## [0.2.0] — 2026-05-13

### Added
- Re-consensus gate (Phase [3.5]) — locked-affecting reviewer issue가 자동 Mode B로 가지 않고 `AskUserQuestion` 3-옵션 (수용/유지/추가 인터뷰)으로 사용자 게이트.
- spec.md frontmatter `locked_decisions:` 리스트 — `LD1, LD2, ...` ID로 인터뷰 (b)/(d) path 합의를 self-contained contract로 기록.
- state.local.md 신규 필드: `pending_locked_decisions`, `issue_history[].dismissed_by_user`, `issue_history[].accepted_by_user`, `issue_history[].reconsensus_count`, `reconsensus_accepted_ids`.
- drafting-spec Mode B `allowed_issue_ids` 입력 contract — 위반 시 abort + `git restore` + state.local.md `mode_b_violation` marker + reviewing-spec [3.5] re-entry.
- spec-reviewer agent 출력에 issue별 `affects_locked_decisions: [LD ids]` 필드.
- Escalate priority table (P1–P4): C3 global cap (≥4 locked-affecting → spec 전체 [5]) > AC9 per-issue (`reconsensus_count >= 2`) > P18 stagnation > reviewer-persona warn.
- Kill switch `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` (loud warning).
- v0.1.x in-flight state migration — missing field 자동 promote (non-mutating read).
- V0 pre-gate (fixture 존재 검증) + `set -e -o pipefail` 전역 적용.

### Changed
- P18 stagnation 판정 조건: `raised_count >= 3` → `raised_count >= 3 AND dismissed_by_user == 0` (사용자 명시 거절을 stagnation에서 제외).
- spec-reviewer agent — frontmatter `Read` tool 사용 허용 (locked_decisions 추출 목적).
- drafting-spec Mode A — interview transcript에서 `pending_locked_decisions`를 frontmatter `locked_decisions:`로 변환.
- README "Principles Instantiated"에 P17 explicit instantiation 한 줄 추가.
