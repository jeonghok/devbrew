---
name: spec-distill-remove-interview-trigger
version: 1.3.0
created_at: 2026-05-22
session_id: brainstorm-2026-05-22
status: locked
next_phase: writing-plans
source: superpowers/brainstorming + 사용자 결정 (interview-trigger 훅 제거 + cleanup_stale_states 동반 제거[A]) + 본 세션 포렌식 (~/.claude/projects transcript hook-attachment 전수 스캔) + spec-review round 1 (spec-reviewer adversarial, 4 issue 반영)
---

# spec-distill — Dead-code 제거 디자인 스펙: interview-trigger 훅 + cleanup_stale_states (v0.7.0)

> **For agentic workers:** 이 문서는 `plugins/spec-distill/`에서 두 개의 dead code를 **제거**하는 v0.7.0 변경 명세이다: (1) `hooks/interview-trigger.sh` (UserPromptSubmit advisory 훅), (2) `hooks/state_path.py`:`cleanup_stale_states()` (v0.6.0에 deprecated된 no-op, CHANGELOG가 이미 "Removed in v0.7.0"로 약속). 근거는 포렌식 사실 + 아키텍처 통찰: interview-trigger는 ~80개 세션 트랜스크립트 전수 스캔 결과 **3주간 0회 발화**했고, spec-distill에서 훅이 load-bearing인 이유는 "interview 진입 권유"가 아니라 **"spec-review 강제" (Law 2)**이다. 더해, advisory 훅(`additionalContext`)은 모델이 무시할 수 있어 비결정적이며, 결정적 강제는 Stop 훅의 `decision:"block"`만이 보장한다 — interview-trigger는 전자(무시 가능), review 강제 체인은 후자(무시 불가)이므로 전자만 제거한다. 제거 후 남는 훅은 전부 review 강제 체인 + read-only advisor이다. 다음 단계는 superpowers `writing-plans` skill로 implementation plan을 생성하는 것이다.

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

두 개의 dead code(`interview-trigger.sh` 훅, `cleanup_stale_states()` 함수)와 그 모든 활성 참조(hooks.json 등록·description, 테스트, README 행)를 제거하고, 제거를 메타데이터(plugin.json minor bump + CHANGELOG v0.7.0)에 기록한다. 제거 후에도 spec-distill의 review 강제 체인·스킬·명령은 동작 불변이며 전체 test suite는 green을 유지한다.

## Context / Why

본 세션은 "spec-distill 훅이 동작 안 함"이라는 사용자 보고로 시작해, `~/.claude/projects/.../*.jsonl` 트랜스크립트의 hook attachment를 전수 스캔하여 다음을 확정했다:

| spec-distill 훅 | 실제 발화 (전 세션) | 판정 |
|---|---:|---|
| PostToolUse (spec-write-validator) | 323회 | ✅ 정상 |
| SessionStart (session-anchor) | 19회 | ✅ 정상 |
| Stop (review-dispatch) | 9회 | ✅ 정상 |
| UserPromptSubmit (pending-review-reminder) | 1회 (정상 주입 확인) | ✅ 메커니즘 작동 |
| **UserPromptSubmit (interview-trigger)** | **0회 (ever)** | ⚠️ dead code |

근거 세 가지:

1. **포렌식 사실 — interview-trigger는 dead code.** trigger gate는 `(build|make|create|... 키워드) AND word_count < 20 AND not /interview`. 같은 UserPromptSubmit 블록의 `pending-review-reminder.py`는 발화했으므로(= Claude Code가 그 블록을 실행함) interview-trigger도 매 프롬프트마다 *실행은 됐으나* 조건 미충족으로 무출력 exit 0 했다. `<20단어` AND가 킬러 — 맥락 있는 build 요청은 대부분 20단어를 넘는다.

2. **아키텍처 통찰 — 훅의 정당성은 review 강제이지 interview nudge가 아니다.** spec-distill 훅이 load-bearing인 이유는 Law 2: writer(spec 작성 턴)가 reviewer(reviewing-spec)를 건너뛸 수 없게 자동 강제하는 것이다 (PostToolUse 감지 → Stop block mandate → UserPromptSubmit reminder redundancy). interview 진입은 `/interview` 직접 호출로 충분한 advisory이므로 훅으로 가로챌 가치가 없다.

3. **강제력 통찰 (compounding) — advisory는 모델이 무시할 수 있다.** 훅 출력은 두 강제력으로 나뉜다: `additionalContext`/`systemMessage`(advisory — context 주입만, 모델이 무시·미표시 가능, 비결정적) vs Stop 훅 `decision:"block"`(모델 stop을 물리적으로 막아 continue 강제, 무시 불가). 따라서 "훅 발화 ≠ 모델 행동". interview-trigger는 advisory-only라 발화해도 모델이 무시 가능 → 신뢰 불가. review 강제 체인의 핵심인 review-dispatch는 `decision:"block"`이라 무시 불가. **이 split이 제거(advisory)/보존(block) 기준이다.** (본 세션에서 spec write 직후 Stop 훅이 이 review를 실제로 강제한 것이 그 산 증거.)

추가로, `cleanup_stale_states()`는 v0.6.0에서 no-op로 deprecated되었고 CHANGELOG가 명시적으로 "Removed in v0.7.0"으로 약속했다. 본 PR이 0.7.0을 bump하므로, 약속 이행 차원에서 동반 제거하여 version story를 정직하게 유지한다(spec-review round 1, issue cd9bc879/c1d6c80a). 현재 `review-dispatch.py`는 이 함수를 호출하지 않으므로(grep 확인) 제거는 안전하며, 호출 경로는 `state_path.py:main()` CLI 분기뿐이다.

따라서 본 PR은 (a) 두 dead code 정리이자 (b) "훅 surface = review 강제"라는 설계 의도를 코드와 일치시키는 정합 작업이다.

## Goals

- `hooks/interview-trigger.sh` 파일 및 `hooks.json` UserPromptSubmit 등록 제거.
- `hooks.json` 최상단 `description`에서 "interview" 문구 제거(stale 잔존 방지, issue da7c35b6).
- `hooks/state_path.py`:`cleanup_stale_states()` **함수 전체 블록(정의·docstring·본문)** + `DEPRECATION_MARKER` 상수 + 모듈 docstring의 `cleanup` CLI 줄 + `main()`의 `cleanup` 분기·usage 토큰 제거(CHANGELOG 약속 이행, issue cd9bc879/564603f5/a3f9b201).
- interview-trigger / cleanup_stale_states를 다루던 테스트를 제거하고, hook 개수 단언/주석(docstring "5 hook" 포함)을 4로 동기화.
- README "Hooks Installed" 표에서 interview-trigger 행 제거 및 hook 수 정합.
- `plugin.json` minor bump (`0.6.0` → `0.7.0`) + `CHANGELOG.md` v0.7.0 Removed 항목(두 제거 모두 기재).
- 제거 후 남는 훅은 전부 **review 강제 체인 + read-only advisor**임을 README가 반영.

## Non-goals

- **`pending-review-reminder.py` 제거 안 함** — review 강제의 L4b redundancy 계층. 제거 후에도 UserPromptSubmit 이벤트는 이 훅 하나로 유지된다.
- **`/interview` 명령 및 `conducting-interview` / `drafting-spec` / `reviewing-spec` 스킬, `agents/`, `session-anchor` 불변.**
- **review 강제 체인의 동작 로직 변경 안 함** — spec-write-validator / review-dispatch / pending-review-reminder의 enforcement는 불변(코드 이동·삭제 없음).
- **SessionEnd-never-fires 하드닝은 별도 PR** — 본 세션에서 발견한 latent 취약점(정리가 GC fallback 단일 의존)이나 현재 GC가 메우고 있어 무해. 본 PR 범위 밖.
- **`state_path.py`의 `resolve_session_id` / `state_root` 등 다른 helper 불변** — 제거 대상은 `cleanup_stale_states` 단 하나.
- **`docs/superpowers/plans/*` · `docs/superpowers/specs/*` 과거 문서 및 CHANGELOG 과거 entry rewrite 안 함** — dated 역사 기록. 본 신규 spec + CHANGELOG v0.7.0이 현재 상태를 기록한다.
- **background에서 UserPromptSubmit이 발화하지 않는 플랫폼 동작 수정 안 함** — Claude Code 사양(미문서화), 플러그인 범위 밖.

## Constraints

- **SemVer:** spec-distill은 0.x(pre-1.0). hook surface + deprecated 함수 제거는 0.x minor bump (`0.6.0` → `0.7.0`). deprecation window는 v≥1.0.0 규정이라 면제 — interview-trigger는 advisory·0회 발화, cleanup_stale_states는 이미 v0.6.0에 deprecated된 no-op라 둘 다 사용자 영향 0.
- **테스트 green:** 변경/삭제 반영 후 `tests/` 전체 통과.
- **킬스위치 유효성 유지:** `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit`는 남는 `pending-review-reminder.py`에 그대로 적용.
- **Korean-primary 문서.**
- **hooks.json 유효성:** 제거 후에도 valid JSON, 5개 이벤트 키 유지(UserPromptSubmit는 reminder 하나만).
- **CHANGELOG 과거 항목 보존:** v0.5.0/v0.6.0 entry의 interview-trigger / cleanup_stale_states 언급은 역사 기록이므로 삭제하지 않고, v0.7.0 Removed 항목을 추가한다.

## Acceptance Criteria

- **AC1** — `plugins/spec-distill/hooks/interview-trigger.sh` 부재.
- **AC2** — `hooks/hooks.json`이 valid JSON이고 `.hooks.UserPromptSubmit[0].hooks`가 길이 1, 유일 엔트리 command가 `pending-review-reminder.py`를 가리킴.
- **AC3** — `.hooks`의 나머지 4개 이벤트(SessionStart/PostToolUse/Stop/SessionEnd) 등록 내용 불변.
- **AC4** — `plugins/spec-distill/`의 `*.sh`/`*.py`/`*.json`/`README.md`에서 `interview-trigger`/`interview_trigger` 활성 참조 0. (CHANGELOG 과거 entry는 예외 보존.)
- **AC5** — `hooks/hooks.json` `description`에 "interview" 문구 없음(예: `"... UserPromptSubmit reminder, SessionStart anchor, ..."`).
- **AC6** — `hooks/state_path.py`에서 `cleanup_stale_states` 함수 전체 블록(정의·docstring·본문)이 삭제되어 정의·호출이 없고, `DEPRECATION_MARKER` 상수, 모듈 docstring의 `cleanup` 줄, `main()`의 `cleanup` 분기 및 usage 문자열의 `cleanup` 토큰이 모두 없음. `resolve_session_id`/`state_root`/`SESSION_PATTERN` 및 `main()`의 `state-root` 분기는 보존(diff로 확인).
- **AC7** — `plugins/spec-distill/`의 `*.py`/`*.sh`에서 `cleanup_stale_states` 및 `DEPRECATION_MARKER` 활성 참조 0, `state_path.py` 모듈 docstring에 `cleanup` 서브커맨드 언급 없음. (CHANGELOG 과거 entry 예외.) `tests/test_state_cleanup.sh`는 삭제됨.
- **AC8** — `tests/test_hook_output_schema.py`에서 `TestInterviewTriggerSchema` 클래스(docstring·메서드·`AC4-a` 데코레이터 포함) + `test_global_disable_silences_interview_trigger` 제거, 모듈 docstring line 4 "AC1–AC5 (5 hook output schemas)"의 hook 수를 4로 갱신(AC4=interview-trigger 제거 반영). **session-anchor 클래스의 내부 `AC5`/`AC5-a` 라벨은 renumber하지 않음** — historical 라벨이라 번호 gap(AC4 부재)을 허용; renumber는 churn·혼동(round-3 c5a71f38은 renumber 미수행으로 자동 소멸). 파일 전체 통과.
- **AC9** — `tests/test_hooks.sh`에서 `TRIGGER` 변수 정의(line 11)와 interview-trigger 테스트 섹션(lines 27–75) 제거. **파일은 삭제되지 않음** — session-anchor 테스트(`ANCHOR` 변수 line 12 + lines 78–114)가 잔류하므로. 제거 후 잔류 session-anchor 테스트가 전부 통과(exit 0)하는 것이 통과 조건.
- **AC10** — `README.md` "Hooks Installed" 표에 interview-trigger 행 없음. output-schema 등 hook 개수 언급이 남는 훅 구성과 정합.
- **AC11** — `.claude-plugin/plugin.json` `version == "0.7.0"`.
- **AC12** — `CHANGELOG.md`에 `## [0.7.0] — 2026-05-22` 섹션 + `### Removed`에 interview-trigger.sh + cleanup_stale_states 제거 사유 기재.

## Files to Modify

| 파일 | 변경 | AC |
|---|---|---|
| `plugins/spec-distill/hooks/interview-trigger.sh` | **삭제** | AC1 |
| `plugins/spec-distill/hooks/hooks.json` | UserPromptSubmit 배열에서 interview-trigger 엔트리 제거(reminder만 남김) + 최상단 `description`에서 "interview" 제거 | AC2, AC3, AC5 |
| `plugins/spec-distill/hooks/state_path.py` | `cleanup_stale_states()` 함수 전체 블록(정의·docstring·본문) + `DEPRECATION_MARKER` 상수 + 모듈 docstring `cleanup` 줄 + `main()`의 `cleanup` 분기·usage 토큰 제거. `resolve_session_id`/`state_root`/`SESSION_PATTERN`/`main()` state-root 분기 보존 | AC6, AC7 |
| `plugins/spec-distill/tests/test_state_cleanup.sh` | **삭제**(제거된 함수 전용 테스트) | AC7 |
| `plugins/spec-distill/tests/test_hook_output_schema.py` | interview-trigger 케이스 + `test_global_disable_silences_interview_trigger` 제거, docstring/단언 hook 수 5→4 | AC8 |
| `plugins/spec-distill/tests/test_hooks.sh` | `TRIGGER` 변수(line 11) + interview-trigger 섹션(lines 27–75) 제거 (AC4 grep `*.sh` 범위 — interview-trigger 참조 전량 제거 필수). session-anchor 테스트(line 12, 78–114) 잔류로 파일 **유지** | AC4, AC9 |
| `plugins/spec-distill/README.md` | Hooks Installed 표 interview-trigger 행 제거 + hook 수 정합 | AC10 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | `version` `0.6.0` → `0.7.0` | AC11 |
| `plugins/spec-distill/CHANGELOG.md` | `## [0.7.0] — 2026-05-22` + Removed 항목(2건) | AC12 |

## Verification Plan

```bash
# AC1 — 파일 부재
test ! -f plugins/spec-distill/hooks/interview-trigger.sh && echo "AC1 ok"

# AC2/AC3 — hooks.json UserPromptSubmit 구성 + 키 보존
jq -e '.hooks.UserPromptSubmit[0].hooks | length == 1
       and (.[0].command | test("pending-review-reminder.py"))
       and (.[0].command | test("interview-trigger") | not)' \
   plugins/spec-distill/hooks/hooks.json && echo "AC2 ok"
jq -e '.hooks | keys == ["PostToolUse","SessionEnd","SessionStart","Stop","UserPromptSubmit"]' \
   plugins/spec-distill/hooks/hooks.json && echo "AC3 keys ok"

# AC5 — description에 interview 없음
jq -e '.description | test("interview") | not' plugins/spec-distill/hooks/hooks.json && echo "AC5 ok"

# AC4 — interview-trigger 활성 참조 0
! grep -rn "interview-trigger\|interview_trigger" plugins/spec-distill \
    --include='*.sh' --include='*.py' --include='*.json' --include='README.md' \
  && echo "AC4 ok"

# AC6/AC7 — cleanup_stale_states 제거 + helper 보존
! grep -rn "cleanup_stale_states\|DEPRECATION_MARKER" plugins/spec-distill --include='*.py' --include='*.sh' \
  && echo "AC7 ok (no active refs)"
! grep -in "cleanup" plugins/spec-distill/hooks/state_path.py && echo "AC6 no cleanup residue"
grep -q "def resolve_session_id" plugins/spec-distill/hooks/state_path.py \
  && grep -q "def state_root" plugins/spec-distill/hooks/state_path.py && echo "AC6 helpers preserved"
test ! -f plugins/spec-distill/tests/test_state_cleanup.sh && echo "AC7 test deleted ok"

# AC8/AC9 — 테스트 green ('&&'로 실패 마스킹 방지; test_hooks.sh는 삭제/존재 양쪽 처리)
python3 plugins/spec-distill/tests/test_hook_output_schema.py && echo "AC8 ok"
if [ -f plugins/spec-distill/tests/test_hooks.sh ]; then
  bash plugins/spec-distill/tests/test_hooks.sh && echo "AC9 ok (tests pass)"
else
  echo "AC9 ok (file deleted)"
fi

# AC11 — 버전
test "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" = "0.7.0" && echo "AC11 ok"

# AC12 — CHANGELOG 항목
grep -q "## \[0.7.0\] — 2026-05-22" plugins/spec-distill/CHANGELOG.md && echo "AC12 ok"
```

## Rejected Alternatives

- **Approach A(휴리스틱 재보정) / B(모델 위임) / C(UserPromptSubmit 의존 축소).** 거절 이유: 모두 "interview nudge를 훅으로 유지"하는 방향. dead heuristic 튜닝은 false-positive 위험, 모델 위임은 훅 surface 확대, C는 큰 재설계. 본 PR은 nudge를 훅에서 *빼는* 것이 목표. (§Context 2·3)
- **cleanup_stale_states 제거를 defer (Option B).** 거절 이유: CHANGELOG가 이미 "Removed in v0.7.0"로 약속했으므로, 0.7.0을 bump하면서 안 지우면 CHANGELOG가 허위가 되고 dead no-op 함수가 영구 잔류. dead-code 정리라는 동일 테마 + 작은 변경(state_path.py 1곳, 호출처 없음)이라 동반 제거가 정직. (사용자 결정: A, spec-review issue cd9bc879/c1d6c80a)
- **과거 `docs/...` 문서 및 CHANGELOG 과거 entry의 interview-trigger/cleanup_stale_states 언급 일괄 삭제.** 거절 이유: append-only 역사 기록의 rewrite. 현재 상태는 본 신규 spec + CHANGELOG v0.7.0이 기록한다.

## Metadata

- **Plugin:** `spec-distill` — `0.6.0` → `0.7.0` (minor; hook surface 축소 + deprecated 함수 제거 — 두 삭제를 한 version story로).
- **Principles instantiated:** Law 2(훅 surface를 review 강제로 정렬), Law 3(advisory-vs-block 강제력 split을 spec에 capture — compounding), AP "dead code 정리", devbrew "design lightness"(신규 P# 없이 기존 surface 축소).
- **보안 검토:** 해당 없음 — 제거 대상은 advisory non-blocking 훅과 no-op 함수이며 reviewer persona/게이트가 아니다. review 강제 체인(spec-write-validator/review-dispatch/pending-review-reminder)은 불변.
- **Cross-plugin 의존:** 없음.
- **Review:** round 1 needs_revise 4-issue 반영(da7c35b6/64169938/cd9bc879/c1d6c80a). round 2 needs_revise 2-issue 반영(564603f5 cleanup 완결성: DEPRECATION_MARKER+docstring+usage; AC9 `;`→if/else 마스킹 수정). round 3 needs_revise 4-issue 반영(a3f9b201 함수 전체 블록 명시; b7d4e209 test_hooks.sh는 session-anchor 잔류로 비삭제 정정; d2e4f011 AC4-test_hooks.sh 연결). **권고 1건 기각**: round-2/3의 `TestSessionAnchorSchema` AC5→AC4 renumber는 historical-라벨 churn이라 미수행(c5a71f38 자동 소멸) — receiving-code-review 기술 판단. 3 round 모두 Stagnation_signal: false (issue 추세: 설계→실질→구현정밀도, diminishing returns).
- **다음 단계:** superpowers `writing-plans` skill로 implementation plan 생성.
