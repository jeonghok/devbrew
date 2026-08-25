# 감사 인덱스

> 플러그인 감사는 이제 `/plugin-audit <target>` (plugins/plugin-audit/)로 실행한다 — repo-root `scripts/*` + `.claude/agents/{plugin-auditor,audit-refuter,smoke-probe}.md` 원본은 이관 완료 후 삭제됨. 산출물 위치·인덱스 관례는 변경 없음.

- [2026-07-15-project-init-audit](../archive/audits/2026-07-15-project-init-audit.md) — 2026-07-15
- [2026-07-27-spec-distill-zero-tool-probe](2026-07-27-spec-distill-zero-tool-probe.md) — 2026-07-27
- [2026-07-28-agent-tools-lock-value-path-gaps](../archive/audits/2026-07-28-agent-tools-lock-value-path-gaps.md) — 2026-07-28 · Law 2 락 값 경로의 선행 결함 4건 (기록 전용, 미수정)
- [2026-08-02-harness-capability-suppression-census](../archive/audits/2026-08-02-harness-capability-suppression-census.md) — 2026-08-02 · 하니스 능력 억제 전수 census (10축 read-only + 양방향 반증, 110+14 findings). 제거 설계는 [`2026-08-02-harness-capability-suppression-sweep-design.md`](../superpowers/specs/2026-08-02-harness-capability-suppression-sweep-design.md)
- [2026-08-13-codex-unification-branch-review](../archive/audits/2026-08-13-codex-unification-branch-review.md) — 2026-08-13 · `feature/codex-usage-unification` whole-branch 리뷰 (리뷰어 5 + adversarial, 0 CRITICAL / 17 IMPORTANT / 32 SUGGESTION, 기각 4). 수정 순서 제약과 grep 함정은 §5
- [2026-08-21-skill-split-lock-corpus-shrink](2026-08-21-skill-split-lock-corpus-shrink.md) — 2026-08-21 · SKILL.md 섹션을 `references/`로 분리하면 **부재 락이 RED 없이 조용히 약해진다**. 실패 클래스 · 독자 열거 방법(6 도달 경로, `.py`·플러그인 경계 포함) · 면역 조건(도출 vs 열거) · 포인터가 presence 락을 header-satisfiable 하게 만드는 거울 클래스 · 차분 실증 계측기 위생. 분할 태스크 착수 전 필독
- [2026-08-23-dispatch-lock-mutations](2026-08-23-dispatch-lock-mutations.md) — 2026-08-23 · dispatch 처분 락(6축 A①②③④·B·C) mutation M1~M18(+M8b) 전건 실행 기록. M8a/M8b 는 macOS bash 3.2 가 멀티바이트 문자 뒤 `set -u` 아래서 스크립트를 크래시시키는 셋째 결과(두 가설 모두 아님)를 냈다 — **락을 지금 고칠 사유는 아니다**: 정정된 것은 계획서의 footgun 서술이고, 전수 스윕 결과 이 패턴을 실행 코드로 갖는 인스턴스는 리포에 없다
