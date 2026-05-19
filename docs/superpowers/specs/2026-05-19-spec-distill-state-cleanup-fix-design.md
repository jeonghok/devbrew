---
name: spec-distill-state-cleanup-fix
version: 1.0.0
created_at: 2026-05-19
session_id: brainstorm-2026-05-19
status: locked
next_phase: writing-plans
source: superpowers/brainstorming + 사용자 보고 (state.local.md 잔여 frontmatter 흔적) + plugins/quality-gates reference 패턴 (setup-qg.sh:108-128, qg-gc.py 전체, hooks/session-end-cleanup.py 전체)
---

# spec-distill — State Cleanup Residue Fix 디자인 스펙 (v0.6.0)

> **For agentic workers:** 이 문서는 `plugins/spec-distill/`의 state 잔여 frontmatter 버그를 수정하기 위한 v0.6.0 변경 명세이다. Root cause는 (a) `session_id`가 모든 hook에서 `"default"` literal로 collapse하는 singleton, (b) AC11 cleanup이 SKILL.md prose에 묻혀 Claude 실행 의존, (c) write_state가 stale body를 보존, (d) cleanup_stale_states가 significant marker로 over-protected. Fix는 plugins/quality-gates의 검증된 패턴을 흡수: `CLAUDE_CODE_SESSION_ID`를 single source of truth로, 4-layer cleanup defense (SessionEnd hook + TTL-GC + approve_handoff script + write_state defensive truncate)로 전환. 다음 단계는 superpowers `writing-plans` skill로 implementation plan을 생성하는 것이다.

## 목차

- §1 [Goal](#goal)
- §2 [Context / Why](#context--why)
- §3 [Goals](#goals)
- §4 [Non-goals](#non-goals)
- §5 [Constraints](#constraints)
- §6 [Acceptance Criteria](#acceptance-criteria)
- §7 [Files to Modify](#files-to-modify)
- §8 [Verification Plan](#verification-plan)
- §9 [Rejected Alternatives](#rejected-alternatives)
- §10 [Metadata](#metadata)

## Goal

본 PR은 **4개 독립 deliverable**을 한 묶음으로 ship한다. 각 deliverable은 독립적으로 implementation 가능하지만 한 PR로 머지하는 이유는 §Coupling 근거에 명시.

- **(a) session_id 소스 교체 (load-bearing 변경)**: `hooks/spec-write-validator.py`, `hooks/review-dispatch.py`, `hooks/pending-review-reminder.py` 3개 hook의 `os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")` 패턴을 `resolve_session_id(payload)` 단일 helper 호출로 통합. helper는 `hooks/state_path.py`에 추가, precedence `DEVBREW_SPEC_DISTILL_SESSION_ID` (테스트 override) → `CLAUDE_CODE_SESSION_ID` (production) → `payload["session_id"]` (PostToolUse fallback). 검증 실패 시 `None` 반환 + loud stderr advisory + state write skip (advisory output은 유지). `"default"` literal fallback 완전 제거.

- **(b) SessionEnd hook 신설 (compounding 산출물)**: `hooks/session-end-cleanup.py` 신규 — qg `hooks/session-end-cleanup.py` 패턴 흡수. stdin payload의 `session_id` + `cwd`로 `.claude/spec-distill/<session_id>/` 통째 `shutil.rmtree(ignore_errors=True)`. Kill switch `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` + `DEVBREW_DISABLE_SPEC_DISTILL=1`. `hooks/hooks.json`에 SessionEnd event 등록.

- **(c) TTL-GC + approve_handoff script 추출**: `scripts/spec-distill-gc.py` 신규 — qg `scripts/qg-gc.py` 패턴 흡수 (fcntl lock + double-stat ns + rename-then-rmtree race guard, 24h TTL, self-session protection, grace window 60s). `pending-review-reminder.py` (UserPromptSubmit)가 fire-and-forget subprocess로 호출. 기존 `cleanup_stale_states` 함수는 deprecate (v0.7.0 제거 예정 주석). `scripts/approve_handoff.sh` 신규 — `skills/reviewing-spec/SKILL.md` AC11 섹션 (line 134-157)의 4-step shell snippet을 atomic script로 추출. SKILL.md AC11 섹션은 1-line script 호출로 단순화.

- **(d) write_state 방어적 truncate + 메타데이터/문서 동기화**: `hooks/spec-write-validator.py`의 `write_state` 함수에 stale-session detection 추가 — 기존 state.local.md frontmatter `session_id:` ≠ 현재 session_id이면 wipe-and-rewrite. `plugin.json` v0.5.1 → v0.6.0 minor bump. `CHANGELOG.md`에 `[0.6.0] — 2026-05-19` Added/Changed/Deprecated/Fixed entry. `README.md` Hooks 섹션에 SessionEnd 추가 + "Principles Instantiated"에 P3/P14/Law 2 instantiation 라인 추가.

**Coupling 근거 (왜 4개 deliverable을 한 PR에)**: 4개는 *서로 다른 trigger condition을 갖는 4-layer defense* 의 부품이다. (a)는 정상 path에서 session_id 충돌 자체를 제거 — 충돌이 사라지면 (d)는 거의 fire 안 함. (b)는 AC11 누락 시의 backup. (c)는 SessionEnd마저 누락된 orphan의 회수. 셋 중 하나만 머지하면:
- (a)만: brainstorming entry는 cover하지만 사용자 강제 종료(Ctrl+C) 시 잔류 영구.
- (b)만: session_id가 여전히 `"default"`로 collapse, 충돌 그대로.
- (c)만: production이 아닌 orphan만 회수, 본 세션 잔류는 24h 동안 살아있음.

3-layer가 모두 같은 사용자 증상 (잔여 frontmatter 노출) 을 차단하는 *서로 보완*인 defense이므로 한 PR로 머지. 롤백 단위(`git revert <pr-merge-sha>`)도 단일 commit이 되어 단순. (d)의 defensive truncate는 *마지막 보루* — (a)+(b)+(c) 모두 실패해도 다음 write가 검출.

## Context / Why

사용자가 본 세션 직전에 다음 incident를 보고했다:

> "state.local.md에 이전 세션(2026-05-17-spec-distill-hook-context-injection-design.md)의 잔여 frontmatter가 남아 있었음. spec-distill의 AC11 cleanup step이 정상 fire되지 않았다는 신호 — 이건 본 작업 무관한 spec-distill 자체의 follow-up 가치가 있는 버그."

진단 (4개 hook 코드 + AC11 SKILL.md prose + cleanup_stale_states 모듈 직접 read로 검증):

| Layer | 상태 | 비고 |
|---|---|---|
| `hooks/spec-write-validator.py:160` session_id 소스 | ❌ singleton `"default"` | env var 없으면 모든 세션이 `.claude/spec-distill/default/state.local.md` 공유 |
| `hooks/review-dispatch.py:94` session_id 소스 | ❌ 동일 | 위 동일 패턴 |
| `hooks/pending-review-reminder.py:62` session_id 소스 | ❌ 동일 | 위 동일 패턴 |
| `write_state` 기존 파일 처리 | ❌ stale body 보존 | `pending_review:` block만 regex-strip, 나머지 frontmatter/body 모두 보존 (line 91-100) |
| `skills/reviewing-spec/SKILL.md` AC11 cleanup | ❌ prose-only | line 134-157의 4-step shell snippet, Claude가 prose 읽고 실행해야 발동. polite-stop/세션 중단/error 시 누락 |
| `state_path.py:cleanup_stale_states` | ❌ over-protected | `phase:`/`issue_history:` 같은 significant marker 있으면 7d TTL이어도 삭제 안 함 (line 113-127). active state는 사실상 영구 잔류 |
| Cross-plugin reference (`plugins/quality-gates/`) | ✅ pattern available | `CLAUDE_CODE_SESSION_ID` source + SessionEnd hook + TTL-GC 3-layer + 정확한 race guard |

Root cause는 4-layer compound failure이지만 *근본 원인 하나*는 분명: spec-distill이 v0.1.0부터 자체적인 session_id 발급 메커니즘을 발명하지 않고 `"default"` literal로 fallback하기로 결정한 것. 이 결정 자체가 Claude Code가 모든 hook payload + env에 항상 `CLAUDE_CODE_SESSION_ID`를 supply한다는 사실을 모른 채 만들어졌다 (qg는 같은 시기에 이 사실을 인지하고 hard-fail 패턴을 채택, `setup-qg.sh:113-122`).

증상의 시간 흐름 (가장 가까운 시나리오 추정 — 시나리오 C, design doc 섹션 3 참조):
1. 2026-05-17 spec-distill-hook-context-injection 작업 세션: state.local.md 생성, session_id frontmatter = `"default"`.
2. 사용자가 "approve" 누르지 않고 다른 옵션 선택 또는 세션 강제 종료 → AC11 prose의 `rm -rf` 실행 안 됨.
3. `cleanup_stale_states`는 significant marker (phase/issue_history) 있어 file 삭제 보호.
4. 새 세션 시작 → 동일 `.claude/spec-distill/default/state.local.md` 가 PostToolUse hook에 발견됨 → write_state가 잔류 body 위에 `pending_review:` 블록만 갱신 → 사용자가 *이전 세션의 frontmatter를 본 세션에서 봄*.

devbrew CLAUDE.md *§The Three Laws*: "**Law 2 — Writer and Reviewer Must Never Share a Pass.** ... 검증은 load-bearing 인프라, 나중 생각이 아님." 본 fix는 Law 2의 spirit을 cleanup에 확장 — load-bearing cleanup도 인프라(코드)여야 하고 prose가 아님.

devbrew CLAUDE.md *§Plugin Shape*: "**JSON이 아니라 마크다운 state.** State는 `.claude/<plugin>.local.md`에 살음 (git-ignored, *성공 시 auto-delete*, 실패 시 디버깅을 위해 보존). per-session 격리가 필요하면 `.claude/<plugin>/<session-id>/...`". 본 incident는 *성공 시 auto-delete*가 사실상 작동하지 않은 케이스 — Plugin Shape의 explicit 약속을 위반했다.

Law 3 (Compounding) instantiation: (a) hook 코드 수정 + (b) SessionEnd hook + (c) TTL-GC + approve_handoff script + (d) 회귀 방지 test 7개 (`test_session_id_resolution.sh`, `test_session_end_cleanup.py`, `test_gc.py`, `test_approve_handoff.sh`, `test_brainstorming_entry.sh`, `test_stale_state_truncate.sh`, `test_kill_switches_v060.sh`) + 본 design doc + CHANGELOG/README의 명시적 기록. 회귀가 다시 발생하면 test가 잡고, 패턴이 잊혀지면 design doc과 README가 다시 찾아준다.

## Goals

- **G1 — session_id가 production에서 절대 `"default"`로 collapse하지 않음**: 3개 hook 모두 `resolve_session_id(payload)` 호출. precedence는 test override (env) → `CLAUDE_CODE_SESSION_ID` → payload. 검증 실패 시 `None` + loud stderr + state write skip. `"default"` literal 코드베이스 어디에도 없음.

- **G2 — 세션 종료 시 deterministic cleanup**: SessionEnd hook이 본 세션 `.claude/spec-distill/<session_id>/` 통째 삭제. Claude 활동 / AC11 prose 실행 여부와 무관. kill switch `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` + global `DEVBREW_DISABLE_SPEC_DISTILL=1` 존중.

- **G3 — Orphan 24h내 회수**: TTL-GC가 self-session protection 하에 24h 초과 폴더 정리. fcntl lock + double-stat + rename-then-rmtree race guard. PostToolUse / UserPromptSubmit hook이 fire-and-forget으로 호출 (timeout 5s, GC 실패 시 main flow 영향 zero).

- **G4 — AC11 cleanup이 prose가 아니라 script**: `scripts/approve_handoff.sh <session_id> <spec_path>`가 4-step (commit / handoff pointer / cleanup / termination) atomic 실행. session_id charset guard 내장. SKILL.md AC11 섹션은 1-line script 호출로 단순화.

- **G5 — 잔여 frontmatter 검출 시 자가 truncate**: `write_state`가 기존 state.local.md의 frontmatter `session_id:` ≠ 현재 session_id이면 전체 wipe + 새 frontmatter rewrite. (a)~(c) 모두 실패해도 다음 write가 catch — defense in depth의 last resort.

- **G6 — 기존 테스트 매트릭스 호환 + 신규 test 7개로 회귀 방지**: `DEVBREW_SPEC_DISTILL_SESSION_ID` 환경변수는 test override로 *유지*. 모든 기존 spec-distill test 무변경 통과. 신규 7 test가 5 component (resolve_session_id, SessionEnd, GC, approve_handoff, write_state truncate, brainstorming entry, kill switch) 각각 회귀 방지.

- **G7 — 메타데이터 + 문서 동기화**: `plugin.json` v0.6.0 bump, `CHANGELOG.md` entry, `README.md`의 Hooks/Principles Instantiated 갱신.

## Non-goals

- **N1 — `/cancel-spec-distill --gc` 같은 user-triggered GC command**: qg는 `/qg --gc` / `/cancel-qg --gc/--all`을 가지지만 spec-distill은 v0.6.0에서 도입 안 함. follow-up.

- **N2 — v0.5.x `.claude/spec-distill/default/` 자동 마이그레이션**: 기존 사용자 환경의 `default/` 폴더를 자동 삭제하지 않음. 첫 hook fire 시 stderr advisory만 emit ("v0.6.0 detected: `.claude/spec-distill/default/` legacy folder, manual cleanup recommended"). qg는 `setup-qg.sh:164-184`에서 legacy cleanup 자동화하지만 spec-distill은 사용자 in-flight 작업 risk 회피 — P14 우선.

- **N3 — AC11 polite-stop 자체 detection**: "approved!"만 narrate하고 script 호출 skip하는 행동을 자동 detect하지 않음. 3-layer defense로 *사용자 노출 증상*은 차단되므로 OK. polite-stop 자체 행동 교정은 `agents/spec-reviewer.md` persona file 영역, 별도 PR.

- **N4 — `cleanup_stale_states` 즉시 제거**: v0.6.0에서는 deprecate 주석 + no-op 호환 layer. v0.7.0에서 제거. one-minor deprecation window 준수 (CLAUDE.md §메타데이터).

- **N5 — `state.local.md` 자체의 schema migration / version bump**: state schema는 v0.5.x 그대로. session_id 소스만 변경 — in-flight state는 새 session_id로 재발급되므로 자연스럽게 마이그레이션됨.

- **N6 — 동시 다중 spec-distill 세션 지원 명시화**: Claude Code가 보통 단일 세션이라 in-scope 아님. 하지만 본 fix의 부산물로 *불가능에서 가능해짐* — 각 세션이 unique CLAUDE_CODE_SESSION_ID 가지므로 자연스럽게 격리.

- **N7 — reviewer persona file 편집**: `agents/spec-reviewer.md` 무변경. 본 incident는 reviewer 호출 자체가 안 일어난 게 아니라 cleanup이 안 된 케이스 — persona 책임 영역 아님.

## Constraints

- **C1 — kill switch 우선순위**: `DEVBREW_DISABLE_SPEC_DISTILL=1`은 모든 신규 component (SessionEnd hook, GC script, approve_handoff script)에서도 instant no-op exit 0. payload read 이전에 체크.

- **C2 — `CLAUDE_CODE_SESSION_ID` 가용성**: Claude Code가 모든 hook event payload + env에 supply (qg 사용 패턴으로 검증). 일부 테스트 환경/sub-shell에서 부재 가능 — `DEVBREW_SPEC_DISTILL_SESSION_ID`가 그 케이스의 override.

- **C3 — Session pattern 호환**: `SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")` — qg와 동일. Claude Code 실제 session_id (UUID 형식) 통과.

- **C4 — `cleanup_stale_states` deprecate 시 호환 layer**: 함수 자체 유지 (import 호환), 함수 body는 no-op + deprecation warning stderr. v0.7.0에서 제거.

- **C5 — `DEVBREW_SPEC_DISTILL_SESSION_ID` precedence**: production에서 사용자가 실수로 set한 경우 *그것이 우선*. 테스트 의도가 production에 leak하면 발생하는 케이스 — README에서 "this var is for tests only, do not set in shell rc" 명시.

- **C6 — `approve_handoff.sh` 실행 권한**: `chmod 755`로 추가. devbrew 다른 scripts도 동일 패턴.

- **C7 — TTL-GC 호출 cost**: PostToolUse 또는 UserPromptSubmit 마다 fire-and-forget이지만 subprocess 비용 (~50ms python 기동). hook timeout 5s 내. fcntl lock contention 시 즉시 return.

- **C8 — 동시성**: SessionEnd hook과 approve_handoff.sh가 동시 실행될 수 있는 (이론적) edge case에서 `shutil.rmtree(ignore_errors=True)` + `rm -rf -- <path>` 둘 다 idempotent. race 보강 추가 없음.

- **C9 — Worktree 호환 (spec-distill divergence from qg)**: `state_path.state_root()` 함수는 `git rev-parse --git-common-dir` 기반으로 worktree에서도 main repo의 `.claude/spec-distill/` 로 resolve. 신규 `session-end-cleanup.py` + `spec-distill-gc.py`는 qg의 단순 `Path(cwd) / .claude / quality-gates` 패턴을 *그대로 흡수하지 않고* spec-distill의 git-aware `state_root(cwd)`를 호출해야 함. 이유: spec-write-validator가 main repo에 state를 쓰는데 SessionEnd가 worktree-local `.claude/`를 보면 cleanup miss. 4-layer defense가 layer 사이 path divergence로 깨지는 걸 방지.

- **C10 — Secret 기록 금지 (P21)**: session_id가 보안-민감 데이터로 간주되지 않지만, stderr log는 `[:32]` truncate로 fingerprint 노출 최소화.

## Acceptance Criteria

각 AC는 measurable + verifiable.

- **AC1 — session_id 해석 단일화**: `state_path.py`에 `resolve_session_id(payload: dict | None = None) -> str | None` 함수 export. precedence: `DEVBREW_SPEC_DISTILL_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → `payload["session_id"]`. 검증 실패 시 `None` + stderr. Verify: `tests/test_session_id_resolution.sh` 11 케이스 전부 통과.

- **AC2 — 3개 hook이 `resolve_session_id` 사용**: `spec-write-validator.py:160`, `review-dispatch.py:94`, `pending-review-reminder.py:62` 의 기존 패턴 모두 `resolve_session_id(payload)` 호출로 교체. grep으로 코드베이스에서 `"default"` literal 부재 확인.

- **AC3 — `"default"` literal 완전 제거**: `grep -rn '"default"' plugins/spec-distill/hooks/` 결과 0건. (테스트 fixture 제외 — `tests/` 디렉토리는 별도 grep으로 확인하고 의도된 사용만 남김.)

- **AC4 — SessionEnd hook 등록 + 작동**: `hooks/hooks.json`에 SessionEnd event 등록. `tests/test_session_end_cleanup.py` 8 케이스 전부 통과 (happy path / folder absent / JSON decode fail / session_id missing / charset reject / cwd missing / global kill switch / granular kill switch).

- **AC5 — TTL-GC 작동**: `scripts/spec-distill-gc.py` 신규. `tests/test_gc.py` 11 케이스 전부 통과 (TTL respect / self-protection / grace window / fcntl contention / double-stat / charset filter / TTL override / kill switch / verbose / empty root).

- **AC6 — `approve_handoff.sh` 작동**: `scripts/approve_handoff.sh` 신규. `tests/test_approve_handoff.sh` 7 케이스 전부 통과 (happy path / charset reject / empty args / git commit fail / rm fail / idempotent re-run).

- **AC7 — `reviewing-spec/SKILL.md` AC11 섹션 simplification**: line 130-159의 4-step shell snippet이 1-line script call로 교체. SKILL.md word count 감소 확인 (~30 lines → ~5 lines).

- **AC8 — `write_state` 방어적 truncate**: `spec-write-validator.py`의 `write_state` 함수가 stale session_id 검출 시 wipe-and-rewrite. `tests/test_stale_state_truncate.sh` 4 케이스 전부 통과 (stale detected → truncate / matching session_id → append / no frontmatter → backward compat / unreadable → preserve).

- **AC9 — brainstorming entry 회귀 방지**: `tests/test_brainstorming_entry.sh` 3 케이스 — /interview 진입 없이 design.md write → state 생성 with proper session_id, `"default"` literal 부재, SessionEnd cleanup 발동.

- **AC10 — kill switch 매트릭스**: `tests/test_kill_switches_v060.sh` 6+ 케이스 — 모든 신규 hook/script가 `DEVBREW_DISABLE_SPEC_DISTILL=1` + `DEVBREW_SKIP_HOOKS=spec-distill:<event>` 존중.

- **AC11 — 메타데이터 bump**: `plugin.json` `version: "0.6.0"`. `CHANGELOG.md`에 `## [0.6.0] — 2026-05-19` entry with Added/Changed/Deprecated/Fixed 섹션. README.md "Hooks Installed" 섹션에 SessionEnd 한 줄 추가, "Principles Instantiated"에 Law 2 / P3 / P14 instantiation 추가.

- **AC12 — `cleanup_stale_states` deprecation**: 함수 body가 no-op + 첫 호출 시 한 번만 stderr deprecation warning. v0.7.0 제거 예정 명시 주석.

- **AC13 — 기존 테스트 무변경 통과**: `cd plugins/spec-distill && bash tests/test_state_path.sh && bash tests/test_spec_write_validator.sh && bash tests/test_review_dispatch.sh && bash tests/test_reminder_hook.sh && bash tests/test_design_mode_validator.sh && python3 -m unittest tests.test_hook_output_schema` 모두 통과.

- **AC14 — v0.5.x legacy advisory**: 첫 hook fire 시 `.claude/spec-distill/default/` 존재 검출하면 stderr advisory 한 번 emit. 자동 삭제 안 함.

## Files to Modify

### Modified

- `plugins/spec-distill/hooks/state_path.py`
  - 신규 export: `SESSION_PATTERN` 상수, `resolve_session_id(payload)` 함수.
  - `cleanup_stale_states` 함수 body → no-op + deprecation stderr (한 번만, module-level flag).

- `plugins/spec-distill/hooks/spec-write-validator.py`
  - line 160: `session_id = resolve_session_id(payload)` 호출. None 처리 (advisory only, state skip).
  - `write_state` 함수 (line 80-100): stale-session detection 추가, wipe-and-rewrite path.

- `plugins/spec-distill/hooks/review-dispatch.py`
  - line 94: `resolve_session_id` 호출.
  - line 91: `cleanup_stale_states` 호출 제거 → `scripts/spec-distill-gc.py` subprocess fire-and-forget.

- `plugins/spec-distill/hooks/pending-review-reminder.py`
  - line 62: `resolve_session_id` 호출.
  - line 73: `cleanup_stale_states` 호출 → GC subprocess fire-and-forget.

- `plugins/spec-distill/hooks/hooks.json`
  - SessionEnd event 등록 (`python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py`, timeout 10).

- `plugins/spec-distill/skills/reviewing-spec/SKILL.md`
  - "## Approve handoff sequence (AC11)" 섹션 (line 130-159): 4-step prose → 1-line script call.

- `plugins/spec-distill/.claude-plugin/plugin.json`
  - `version`: `"0.5.1"` → `"0.6.0"`.

- `plugins/spec-distill/CHANGELOG.md`
  - `## [0.6.0] — 2026-05-19` entry: Added (SessionEnd hook, TTL-GC, approve_handoff script, resolve_session_id helper, 7 tests), Changed (3 hooks session_id source, AC11 SKILL.md simplification, write_state truncate), Deprecated (cleanup_stale_states, DEVBREW_SPEC_DISTILL_SESSION_ID production use), Fixed (잔여 frontmatter bug — incident 인용).

- `plugins/spec-distill/README.md`
  - "Hooks Installed" 섹션: SessionEnd 라인 추가 + "왜 skill이 아닌가" justification.
  - "Principles Instantiated" 섹션: Law 2 (load-bearing cleanup is code, not prose), P3 (graceful degradation when session_id unresolvable), P14 (write_state preserves unreadable state for debug) instantiation 추가.

### New

- `plugins/spec-distill/hooks/session-end-cleanup.py` — SessionEnd hook, qg 패턴 흡수.
- `plugins/spec-distill/scripts/spec-distill-gc.py` — TTL-GC, qg `qg-gc.py` 패턴 흡수.
- `plugins/spec-distill/scripts/approve_handoff.sh` — AC11 atomic script (`chmod 755`).
- `plugins/spec-distill/tests/test_session_id_resolution.sh` — AC1 verification (11 케이스).
- `plugins/spec-distill/tests/test_session_end_cleanup.py` — AC4 verification (8 케이스).
- `plugins/spec-distill/tests/test_gc.py` — AC5 verification (11 케이스).
- `plugins/spec-distill/tests/test_approve_handoff.sh` — AC6 verification (7 케이스).
- `plugins/spec-distill/tests/test_stale_state_truncate.sh` — AC8 verification (4 케이스).
- `plugins/spec-distill/tests/test_brainstorming_entry.sh` — AC9 verification (3 케이스).
- `plugins/spec-distill/tests/test_kill_switches_v060.sh` — AC10 verification (6+ 케이스).

### Untouched (intentionally)

- `plugins/spec-distill/agents/` — persona file 무변경 (N7).
- `plugins/spec-distill/skills/conducting-interview/SKILL.md` — session_id schema 문서는 v0.7.0에서 정리 (in-memory schema는 그대로).
- `plugins/spec-distill/skills/drafting-spec/SKILL.md` — 무변경.
- `plugins/spec-distill/hooks/interview-trigger.sh` — session_id 안 다룸.
- `plugins/spec-distill/hooks/session-anchor.sh` — 현재 advisory-only, session_id 직접 안 씀.

## Verification Plan

PR 머지 전 다음 명령이 모두 통과해야 한다:

```bash
cd plugins/spec-distill/

# 신규 테스트
bash tests/test_session_id_resolution.sh
python3 -m unittest tests.test_session_end_cleanup
python3 -m unittest tests.test_gc
bash tests/test_approve_handoff.sh
bash tests/test_brainstorming_entry.sh
bash tests/test_stale_state_truncate.sh
bash tests/test_kill_switches_v060.sh

# 기존 테스트 (무변경 통과)
bash tests/test_state_path.sh
bash tests/test_spec_write_validator.sh
bash tests/test_review_dispatch.sh
bash tests/test_reminder_hook.sh
bash tests/test_design_mode_validator.sh
bash tests/test_review_dispatch_design_mandate.sh
python3 -m unittest tests.test_hook_output_schema

# Negative checks (`"default"` literal 부재)
! grep -rn '"default"' hooks/  # 0건이어야 함
grep -rn 'resolve_session_id' hooks/  # 3개 hook + state_path.py 정의

# Cross-plugin reference (qg 패턴 alignment)
diff <(python3 -c "import importlib.util, hashlib; spec = importlib.util.spec_from_file_location('gc', 'scripts/spec-distill-gc.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); print(m.SESSION_PATTERN.pattern)") \
     <(python3 -c "import importlib.util, hashlib; spec = importlib.util.spec_from_file_location('qg', '../quality-gates/scripts/qg-gc.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); print(m.SESSION_PATTERN.pattern)")
# SESSION_PATTERN 두 plugin에서 동일해야 함

# Manual smoke (PR reviewer 권장)
DEVBREW_SPEC_DISTILL_SESSION_ID="smoke-12345678" \
  echo '{"tool_name":"Write","tool_input":{"file_path":"docs/superpowers/specs/2026-05-19-test-design.md"}}' \
  | python3 hooks/spec-write-validator.py
ls .claude/spec-distill/smoke-12345678/  # state.local.md 존재

echo '{"session_id":"smoke-12345678","cwd":"'"$PWD"'"}' \
  | python3 hooks/session-end-cleanup.py
ls .claude/spec-distill/  # smoke-12345678 폴더 부재
```

**Quality-gates Gate 2 (security review) 명시 항목**:
- `approve_handoff.sh`의 `rm -rf -- "$path"`가 `--`로 path injection 방어. session_id charset guard로 `..` traversal 차단.
- `spec-distill-gc.py`의 `SESSION_PATTERN`이 GC iteration의 SSRF/path-traversal 1차 방어. `.gc-pending-<uuid>` 임시명도 charset에 포함되지 않으므로 GC 자기 자신 정리 안 함.
- SessionEnd hook stdin payload의 `cwd`가 user-controlled but session_id를 charset filter로 통과 → cleanup path는 `<user-cwd>/.claude/spec-distill/<filtered-sid>/` 형태로 traversal 불가.

**Quality-gates Gate 3 (runtime verification)**:
- 본 fix는 CLI scripts + hooks (모두 STDIN/STDOUT JSON). chrome-devtools-mcp / docker-compose / npm:dev 같은 surface 없음 → Gate 3은 hook smoke test로 충족.

## Rejected Alternatives

**채택된 접근 (옵션 D)**: §Goal에 명시된 4-deliverable 패턴 — `CLAUDE_CODE_SESSION_ID` 단일 소스 + 4-layer cleanup defense (SessionEnd hook + TTL-GC + approve_handoff script + write_state defensive truncate). qg의 검증된 패턴을 흡수, P12 (lightness) 준수.

아래는 brainstorming 과정에서 explore했으나 거절된 대안들.

### 옵션 A — `/interview` Step 0에 init 게이트
- conducting-interview Step 0에서 기존 state.local.md 발견 시 `AskUserQuestion`으로 `resume | start fresh | abort` 선택.
- **거절 이유**: 사용자 지적 — "interview 없이도 hook이 brainstorming을 통해 발동되기도해". /interview 진입을 init boundary로 쓰면 brainstorming-via-PostToolUse 경로를 커버 못 함. 진입 지점에 의존하는 fix는 spec-distill의 multi-entry 본질과 충돌.

### 옵션 B — 자체 session_id 발급 메커니즘
- `/interview` 진입 시 `YYYY-MM-DD-<8char-suffix>` 생성, `.claude/spec-distill/current-session` 파일에 영속화. 3 hook이 env var 부재 시 이 파일에서 read.
- **거절 이유**: `CLAUDE_CODE_SESSION_ID`가 이미 Claude Code-supplied unique session id로 모든 hook payload + env에 있다. 자체 발급은 중복 인프라이며 qg와 alignment 약화. P12 (lightness — 기존 검증된 메커니즘 흡수 우선)에 위배.

### 옵션 C — Stop hook의 phase marker 기반 자동 cleanup + write_state truncate
- Stop hook이 `phase: approved` marker 감지 시 directory 삭제.
- **거절 이유**: phase marker 의미가 새로 load-bearing이 됨. 현재 phase는 advisory + workflow tracking 용도. cleanup load-bearing으로 격상하면 phase 누락/오기재 시 cleanup 실패. SessionEnd hook이 phase 마커와 무관하게 *세션 종료라는 명백한 신호* — Claude Code lifecycle 이벤트 — 에 묶이는 게 의미론적으로 더 정확. 또한 `phase: approved`를 누가 언제 쓰는지 새로 정의 필요 — 변경 표면 증가.

### 옵션 E — `cleanup_stale_states` 즉시 활성화 + significant marker 제거
- 기존 함수의 significant marker 보호 제거, 24h TTL을 file에도 적용.
- **거절 이유**: race guard 없음 (qg-gc.py의 fcntl + double-stat + rename-then-rmtree와 비교). spec-distill이 동시 다중 hook 호출되면 race. 또한 cleanup 호출 trigger가 `review-dispatch.py` + `pending-review-reminder.py` 두 곳에 중복 — qg는 setup-qg.sh 단일 trigger + cancel command. 본 fix의 TTL-GC는 qg 패턴 그대로 흡수해 race guard + verbose + self-protection을 무료로 얻음.

### 옵션 F — DEVBREW_SPEC_DISTILL_SESSION_ID env var 제거
- 테스트 override env var 자체를 폐기, 테스트도 `CLAUDE_CODE_SESSION_ID` 사용.
- **거절 이유**: 기존 7개 테스트 파일이 `DEVBREW_SPEC_DISTILL_SESSION_ID`로 작성됨. 테스트 매트릭스 전체 rewrite cost > test override 1 var 유지 cost. CLAUDE.md "Surgical Changes" 원칙. 또한 production에서 사용자가 의도적으로 다중 세션을 분리하고 싶을 때의 escape hatch도 제공.

## Metadata

- **Spec author**: spec-distill self-fix (Korean Socratic via /brainstorming).
- **Source chain**: 사용자 보고 (state.local.md 2026-05-17 잔여 frontmatter) → /brainstorming 5-section (architecture / components / data flow / error handling / testing) → 본 design doc.
- **Implementation plan target**: 다음 단계는 superpowers `writing-plans` skill로 task breakdown 생성. Task 순서 권장: (1) C1 `state_path.py` extension → (2) C4/C5/C6 신규 file 작성 (병렬 가능) → (3) C2/C3 기존 hook 변경 (C1 의존) → (4) SKILL.md / hooks.json / plugin.json / CHANGELOG / README 동기화 → (5) 7개 신규 test 추가 + 기존 test 통과 확인.
- **PR scope**: 1 PR (feature/spec-distill-state-cleanup-fix). 4 deliverable 묶음 (§Goal coupling 근거).
- **Branch**: `feature/spec-distill-state-cleanup-fix` from `main`. Conventional Commits: `feat(spec-distill): session-id resolution + 4-layer cleanup defense (v0.6.0)`.
- **Risk profile**: 
  - High-confidence: qg 패턴 그대로 흡수 (검증된 production 코드 100+ commits).
  - Medium: write_state defensive truncate는 신규 path, 신규 test로 cover.
  - Low: AC11 script extraction은 기존 prose의 1:1 변환.
- **Rollback**: `git revert <pr-merge-sha>`. v0.5.1 코드는 변경 없이 보존되므로 single-commit revert가 working state.
- **Cost class**: low (코드 수정 + 신규 hook/script). 사용자 인터랙션 발생 surface 없음.
- **Compounding artifact**: 본 design doc + 7개 신규 test + CHANGELOG entry. 미래 spec-distill 작업이 grep "잔여 frontmatter" / "default literal" / "session_id collision"으로 찾을 수 있음.
