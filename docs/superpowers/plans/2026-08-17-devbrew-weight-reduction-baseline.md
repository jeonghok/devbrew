# 기준선 — devbrew 무게 감축 사이클

측정 시점: 2026-08-16T16:24:56Z, HEAD = `ee1d95f55afdeac0698fb644e93ae97b560100ca` (branch `feature/devbrew-weight-reduction`)

## 셸 (실행비트가 선 tests/*.sh, mocks·fixtures·harness·tests/lib 제외)

- 코퍼스: `git ls-files 'plugins/*' | grep -E '(^|/)tests?/.*\.sh$'` → 165개 → `*/mocks/*`·`*/fixtures/*`·`*/harness/*`·`*/tests/lib/*` 제외 → 151개 → 실행비트 있는 것 **136개**를 실행
- 실행: 136개 / GREEN: 132 / RED: 4

### 선재 RED 목록

| 파일 | rc | 첫 실패 줄 |
|---|---|---|
| `plugins/agent-transparency/tests/ab_gate.sh` | 1 | `plugins/agent-transparency/tests/ab_gate.sh: line 23: AB_MODEL: parameter null or not set` |
| `plugins/quality-gates/tests/spike/test_codex_json_extraction.sh` | 1 | `no fenced JSON` (3회 실행 모두 실패) → `Spike result: 0/3 passed` / `FAIL: spike threshold not met. Halt before Task 4.` |
| `plugins/quality-gates/tests/test_consent_marker_write_failure.sh` | 1 | `FAIL: AC11: # QG-CONSENT-MARKER-WRITE block not found in SKILL.md` |
| `plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh` | 1 | `FAIL: kill switch env var present (got 0, expected >= 1)` (+ `FAIL: disable log message present (got 0, expected >= 1)`; 3건 중 1건만 PASS) |

## 파이썬 (`python3 -m unittest discover` per 테스트 디렉토리)

`find . -name __pycache__ -type d -prune -exec rm -rf {} +` + `PYTHONDONTWRITEBYTECODE=1` 적용 후 `plugins/*/tests`, `plugins/*/scripts/tests`, `plugins/*/hooks/tests` 6개 디렉토리에 대해 `python3 -m unittest discover -s "$d" -t .` 실행 (python3 = 3.9.6).

| 디렉토리 | rc | Ran | 비고 |
|---|---|---|---|
| `plugins/agent-transparency/tests` | 1 | 0 | `ImportError: Start directory is not importable` — 디렉토리에 `__init__.py` 없음. `test_*.py` 5개가 존재하지만 이 정확한 호출(`-t .`)로는 하나도 실행되지 않는다 |
| `plugins/project-init/tests` | 1 | 0 | 동일 ImportError. 이 디렉토리는 최상위에 `test_*.py`가 0개(셸 테스트만 있음)라 이 경로 자체가 애초에 파이썬 테스트를 담고 있지 않음 |
| `plugins/quality-gates/tests` | 1 | 0 | 동일 ImportError. `test_*.py` 18개가 존재하지만 실행되지 않음 |
| `plugins/spec-distill/tests` | 1 | 0 | 동일 ImportError. `test_*.py` 10개가 존재하지만 실행되지 않음 |
| `plugins/plugin-audit/scripts/tests` | 0 | 249 | GREEN — `tests/__init__.py` 존재 |
| `plugins/project-init/hooks/tests` | 0 | 95 | GREEN — `tests/__init__.py` 존재 |

**근본 원인**: `python3 -m unittest discover -s <dir> -t .`는 `start_dir`이 `top_level_dir`(레포 루트)에서 내려오는 파이썬 패키지로 import 가능해야 하는데, RED인 4개 디렉토리는 자기 자신에 `__init__.py`가 없다(`plugins/`도 없음). GREEN인 2개는 `tests/__init__.py`가 있어 이 조건을 만족한다. 이것은 코드 결함이 아니라 **이 정확한 호출 방식과 디렉토리 구조의 불일치**이며, 4개 디렉토리의 파이썬 테스트(합계 33개 `test_*.py` 파일, `project-init/tests`는 0개)는 이 방식으로는 구조적으로 한 번도 실행되지 않는다. 브리프의 정확한 커맨드를 그대로 실행한 결과이므로 그대로 기록한다 — 이 사이클에서 고치지 않는다.

## 실행비트 없는 셸 테스트 (선택 불가 — Task 4 대상)

`git ls-files 'plugins/*' | grep -E '(^|/)tests?/.*\.sh$' | grep -vE '(/mocks/|/fixtures/|/harness/|/tests/lib/)'` 중 실행비트 없는 15개, 전부 `plugins/spec-distill/tests/`:

- `plugins/spec-distill/tests/arm_test_helpers.sh`
- `plugins/spec-distill/tests/test_brainstorming_entry.sh`
- `plugins/spec-distill/tests/test_brief_agents.sh`
- `plugins/spec-distill/tests/test_brief_codex_axes.sh`
- `plugins/spec-distill/tests/test_brief_inline_blob.sh`
- `plugins/spec-distill/tests/test_brief_review_entry.sh`
- `plugins/spec-distill/tests/test_build_spec_codex_prompt.sh`
- `plugins/spec-distill/tests/test_detect_codex.sh`
- `plugins/spec-distill/tests/test_kill_switches_v060.sh`
- `plugins/spec-distill/tests/test_no_wall_clock.sh`
- `plugins/spec-distill/tests/test_parse_spec_structure.sh`
- `plugins/spec-distill/tests/test_probe_budget.sh`
- `plugins/spec-distill/tests/test_readme_sync.sh`
- `plugins/spec-distill/tests/test_reviewing_spec_design_only.sh`
- `plugins/spec-distill/tests/test_session_id_resolution.sh`

## 계획-시점 측정치와의 차이

계획(`main = b28b88e`)은 "셸 테스트 152개 중 실행비트가 있는 것은 137개, 없는 15개는 전부 spec-distill"이라고 적었다. 이 태스크의 실측은 **151개 중 136개**(실행비트 없는 15개는 계획과 목록까지 정확히 일치)다.

이 차이(152→151, 137→136, 둘 다 정확히 -1)는 **브랜치 변경 때문이 아니다**:
- `git diff --summary b28b88e HEAD` — 저장소 전체에서 모드(실행비트) 변경 0건
- `b28b88e..HEAD` 8개 커밋은 전부 `docs/**`만 건드림 (`git diff --name-status b28b88e HEAD` 확인, `plugins/**` 무변경)
- `git ls-files 'plugins/*' | grep -E '(^|/)tests?/.*\.sh$'`로 뽑은 파일 목록 자체가 HEAD와 `b28b88e` 사이에 diff 없음(완전 동일)

즉 두 커밋 사이에 추가/삭제/모드변경된 파일이 하나도 없어 **특정 파일 하나가 차이를 설명하지 않는다** — 계획 문서의 152/137 수치 자체가 집계 시점의 오프바이원 오기(誤記)였던 것으로 결론짓는다. 이 태스크의 151/136(그리고 15개 목록)이 두 개의 독립적 방법(`[ -x "$f" ]`, `find "$f" -perm -u+x`)으로 교차검증된 값이며, 이후 모든 태스크는 이 문서의 151/136을 기준으로 삼는다.

## 이 문서의 용도

이후 모든 PR에서 "새 RED"는 **이 목록에 없는 RED**를 뜻한다. 선재 RED를 이 사이클에서
고치지 않는다 — 범위 밖이고, 고치면 그 자체가 회귀 판정을 흐린다.
