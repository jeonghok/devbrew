# PR #33 + PR #32 Retroactive QG Audit (2026-05-14)

## 개요

PR #33 (`worktree-qg-codex-spec`, MERGED 2026-05-14, codex-reviewer 기능)과 PR #32 (`worktree-qg-forward-only-cleanup`, MERGED 2026-05-13, v1.10.0)에 대한 post-merge 검증. devbrew Law 3 ("Every Cycle Must Leave the System Smarter") compounding substrate.

## 방법

- 2 detached git worktrees 생성 (각 PR의 머지 베이스에 위치, PR diff를 unstaged로 apply).
- 6 reviewers parallel dispatch (3 per PR):
  - PR #33: `pr-review-toolkit:code-reviewer`, `pr-review-toolkit:silent-failure-hunter`, `pr-review-toolkit:comment-analyzer`
  - PR #32: `pr-review-toolkit:code-reviewer`, `pr-review-toolkit:pr-test-analyzer`, `pr-review-toolkit:comment-analyzer`
- Findings dedupe + ranking + worktree cleanup.

## PR #33 findings (codex-reviewer 도메인)

### Critical (4)

- **C1**: `plugins/quality-gates/agents/codex-reviewer.md:6` frontmatter가 `allowed-tools` (kebab-case). camelCase `allowedTools`가 agent frontmatter 컨벤션 — Layer 2 isolation 비기능. 테스트(`tests/test_codex_reviewer_frontmatter.sh:61`)도 같은 잘못된 키 검사 → invariant 자체가 verify 안 됨.
- **C2**: `SKILL.md:438`의 validation `phase1_agents ⊆ {code-reviewer, silent-failure-hunter, feature-dev:code-reviewer}` 와 `scout.md:65-66`의 codex-reviewer를 `phase1_agents`에 추가하라는 instruction 불일치. validation FAIL → scout-fallback engage → codex-reviewer silently dropped. **결과: production에서 codex-reviewer가 dispatch되지 않음.**
- **C3**: `detect_codex.sh:38`의 `codex --version` 호출에 timeout 래핑 없음. 무한 hang 위험.
- **C4**: `codex-reviewer.md:45` `TIMEOUT_CMD="$(command -v gtimeout || command -v timeout)"` empty 시 600s ceiling 무력화 — macOS 기본 환경에서 promised cost ceiling 실패.

### Important (11)

- **I1**: 프롬프트 빌더 실패 시 codex가 빈 prompt로 호출 (silent pass).
- **I2**: `codex_findings_to_yaml.py:192-197` findings non-list silent coerce to `[]`.
- **I3**: `parse_fenced_json` picks FIRST block — prompt injection 가능.
- **I4**: `AUTH_ERROR_RE` 협소 — 401/403/forbidden/quota/expired 누락.
- **I5**: cost consent marker write 실패 silently.
- **I6**: `detect_codex.sh` schema validation 부재.
- **I7**: spec 파일명 dashes vs 실제 underscores 영구 불일치.
- **I8**: README 디렉토리 트리에 신규 4파일 누락.
- **I9**: README Gate 2 stage diagram + fan-out 11→12 미반영.
- **I10**: spec 버전 v3 vs v3.1 정합성 (CHANGELOG/plan).
- **I11**: scout-fallback engage 시 codex-reviewer 제거 신호 사용자 visibility 부재.

## PR #32 findings (forward-only cleanup 도메인)

### Critical (4)

- **C5**: `SKILL.md:1104-1110` GATE2_NEEDS_RESTART option count 불일치 — doc 2 옵션 vs stop-hook 3 옵션 (Apply changes and re-run 누락).
- **C6**: `test_forward_only_prose.sh:33,45` 정규식 협소 — `re-enter Gate 1`, `loops back`, `auto-restart to` 미catch.
- **C7**: Gate-2 max-iteration 경계 테스트 부재.
- **C8**: `test_stop_hook_unit.py:58` `test_each_case_is_substantial`이 옵션 누락 catch 못함.

### Important (6)

- **I12**: `stop-hook.py:723-725` `_SPECIAL_PROMPTS.get() or fallback` 시 unknown `prompt_key` silently 흡수.
- **I13**: `extend` action 문서화돼 있지만 v1.5.0 이후 no-op.
- **I14**: `state-file-format.md:61` 예시 라인에 stop-hook이 안 쓰는 annotation.
- **I15**: v1.10.0 CHANGELOG에 GATE2_NEEDS_RESTART 2→3 옵션 변경 누락.
- **I16**: main() → build_special_prompt routing seam 통합 테스트 부재.
- **I17**: state-dict 부분 populate 시 `compute_transition` `KeyError` 가능.

## 본 spec(sub-project A) 대응 범위

PR #33 영역(C1–C4 + I1–I11)만 본 spec (`2026-05-14-qg-codex-reviewer-recovery-design.md`)이 다룸. PR #32 영역(C5–C8 + I12–I17)은 sub-project B (별도 spec)로 분리.

AC-매핑:
- C1 → AC1 + AC14 + AC15 (frontmatter fix + advisor + bash test)
- C2 → AC2 + AC3 + AC4 (validation 유지 + scout 책임 축소 + dispatch logic)
- C3 → AC7 (detect_codex.sh timeout)
- C4 → AC8 (agent body TIMEOUT_CMD 검사)
- I1 → AC10 (prompt builder exit-code 검사)
- I2 → AC9(a) (non-list coerce + meta.reason)
- I3 → AC9(b) (last-fence selection)
- I4 → AC9(c) (AUTH_ERROR_RE 확장)
- I5 → AC11 (consent marker write 실패 처리)
- I6 → AC12 (manifest schema validation)
- I7 → AC17 (spec 파일명 underscore 정리)
- I8 → AC16 (README 디렉토리 트리)
- I9 → AC16 (Gate 2 diagram + fan-out)
- I10 → OQ1 (placeholder fallback)
- I11 → AC13 (fallback codex inclusion + visibility 메시지)

## Positive findings (회귀 방지)

본 audit이 추가로 확인한 정상 동작 — 본 spec에서 변경 시 회귀 위험:

- PR #33 heredoc 안전성 (`<<'INPUT_EOF'`): single-quoted, shell expansion 비활성 — Task 4 fix는 구조적 sound.
- known-bad version regex (`0\.120\.(0|1|2)`): 정확히 anchored.
- PR #32 deprecated-field removal: 12 라인 제거는 fixture cleanup만, coverage loss 없음.
- forward-only invariant: `stop-hook.py`에 `goto_gate=1` resurrection 경로 없음.

## Limitations

- Audit은 인스턴스 1회. Round 1만 수행 (multi-round adversarial 없음).
- 6 reviewer parallel — 동일 reviewer를 다른 prompt로 cross-check 안 함.
- 본 audit이 PR #33/PR #32 머지 *전*에 수행됐다면 회피 가능했을 결함 다수. Pre-merge audit 도입 권장 (별도 ticket).

## 관련 파일

- 본 spec: `/Users/jeonghokim/Downloads/devbrew/docs/superpowers/specs/2026-05-14-qg-codex-reviewer-recovery-design.md`
- sub-project B (PR #32 영역): 미작성 (별도 spec).
- PR #33 spec: `/Users/jeonghokim/Downloads/devbrew/docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md`
- PR #32 spec: `/Users/jeonghokim/Downloads/devbrew/docs/superpowers/specs/2026-05-13-qg-forward-only-cleanup-and-stop-hook-trim-design.md`
