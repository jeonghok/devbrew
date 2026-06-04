---
description: 진행 중이거나 완료된 design 문서의 spec-distill auto-review를 취소·억제 (또는 --reset으로 재활성화). per-doc·session-scoped. devbrew P17 instantiation.
argument-hint: "[path] | --reset <path>"
---

# /spec-distill:cancel-review

현재(또는 지정한) design 문서의 `pending_review`를 취소하고, 그 문서가 이번 세션
동안 다시 auto-review로 arm되지 않도록 억제합니다. 리뷰 *완료* 후 또는 *중단* 요청
후에도 같은 `-design.md`를 재편집하면 reviewing-spec가 재dispatch되던 문제를 끄는
사용자 주권(P17) 경로입니다. cost_class: low.

## Step 1: kill switch 존중

`DEVBREW_DISABLE_SPEC_DISTILL=1` 이 set이면 즉시 종료 (no-op). 스크립트도 동일하게
존중하므로 그대로 실행해도 안전합니다.

## Step 2: 실행

다음을 그대로 실행하고 stderr advisory를 사용자에게 보여주십시오:

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/cancel_review.py" $ARGUMENTS
```

## 사용법

- **인자 없음** — 현재 `pending_review` 문서를 취소 + 세션 억제. 이번 턴 Stop dispatch와
  다음 턴 reminder, 이후 같은 문서 edit이 모두 no-op이 됩니다.
- **`<path>`** — 그 문서를 억제. 현재 pending이 *같은* 문서면 함께 취소하고, *다른*
  문서의 pending은 보존합니다 (특정 문서 targeting / 사전 억제).
- **`--reset <path>`** — 억제 해제 → 그 문서 재편집 시 auto-review 재개.

## 동작 경계

- 억제는 **session-scoped**입니다. 새 세션은 SessionEnd cleanup 후 fresh 상태로
  시작하므로 stale 억제가 누출되지 않습니다.
- **Layer 1 구조 검증은 직교**합니다 — 억제는 arm/dispatch(Layer 2)만 끄며, 문서의
  ambiguity/placeholder 구조 검사는 그대로 동작합니다.
- 스코프(`docs/superpowers/specs/`) 밖 경로, session_id 미해석, kill switch는 상태를
  바꾸지 않고 loud advisory만 출력합니다.
