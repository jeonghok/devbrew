# 감사 하니스 — 테스트 & 실행 순서

## 테스트 실행
- Python: `python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -v` (리포 root에서.
  `-t .`는 이 리포에서 구조적으로 불가능 — 플러그인 디렉토리 이름의 하이픈이 점 경로 패키지를 막는다.
  `-t`는 항상 그 디렉토리 자신.)
- Node:   `node --test plugins/plugin-audit/tests/*.test.mjs` (bare 디렉토리 형태
  `node --test plugins/plugin-audit/tests/`는 이 harness가 검증한 Node 버전에서
  `MODULE_NOT_FOUND`로 실패한다 — 디렉토리를 모듈 진입점으로 취급하는 호출부 문제이지 테스트 실패가
  아니다. glob 형태만 쓴다.)

## 감사 RUN 순서 (orchestrator = 메인 루프, 설계 §6·§20)
1. **agent 파일 커밋 + 세션 재시작** — 레지스트리는 세션 시작에 스냅샷된다 (가정 i).
2. **phase 0** 지출 동의 게이트 (`AskUserQuestion`, fanout 30) → consent artifact. clean worktree 선결.
3. **pre-0** `check-law2.py` (audit + smoke) → `check-no-verdict-injection.py` → 미니-workflow 스모크
   (sentinel 파일 부재를 디스크에서 확인).
4. **pre-1** LD5-0 스냅샷 → 대상 자체 테스트 실행(`-B`) → `check-staleness.py` → evidence pack 조립
   → codex blind(`-s read-only`) → LD5-1=BEFORE + `LD5-0==LD5-1` 검사.
5. **Workflow** `audit-workflow.js` (6축 pipeline) → findings 반환.
6. **post-1** AFTER#1 → audit-data.json 조립(codex D/OQ/NOQ 병합 + **배정 D/OQ backfill** + cross-model +
   **gate-E→NOQ 회수** + steelman pending 해소) → secret scan → journal 복사 →
   `validate-audit-data.py --data` → `render-audit-report.py` → CLAUDE.md 포인터 →
   `validate-audit-data.py --artifacts` → AFTER#2 → 커밋(scripts/** 포함).

## Law 2 3층 (설계 §16)
(a) agent `tools:` allowlist ✅ · (b) 미니-workflow 스모크 ✅(이 계획) · (c) 무결성 스냅샷 ✅.
