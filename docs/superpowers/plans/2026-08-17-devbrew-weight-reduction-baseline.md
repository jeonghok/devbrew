# 기준선 — devbrew 무게 감축 사이클

측정 시점: 2026-08-16T16:24:56Z, HEAD = `ee1d95f55afdeac0698fb644e93ae97b560100ca` (branch `feature/devbrew-weight-reduction`)

## 셸 (실행비트가 선 tests/*.sh, mocks·fixtures·harness·tests/lib 제외)

- 코퍼스: `git ls-files 'plugins/*' | grep -E '(^|/)tests?/.*\.sh$'` → 165개 → `*/mocks/*`·`*/fixtures/*`·`*/harness/*`·`*/tests/lib/*` 제외 → 151개 → 실행비트 있는 것 **136개**를 실행 (측정 시점 `ee1d95f`, 이 수치는 그 시점의 스냅샷으로 보존 — 아래 "Task 4 갱신" 참조)
- 실행: 136개 / GREEN: 132 / RED: 4

**Task 4 갱신 (2026-08-17)**: 아래 "실행비트 없는 셸 테스트" 절의 15개 중 14개(`test_*.sh`, 전부 `plugins/spec-distill/tests/`)에 실행비트를 부여했다 — `arm_test_helpers.sh`(source 전용 헬퍼)는 제외. 갱신 후 코퍼스 151개 중 실행비트 있는 것 **150개**(원 136 + 신규 14, 실행비트 없는 것은 헬퍼 1개만 남음). 신규 14개를 각 1회 실행 → **GREEN 14 / RED 0**(신규 RED 없음 — "선재 RED 목록" 표에 추가된 행 없음). 이 14개는 지금부터 §셸 코퍼스와 다음 절 "선재 RED 목록" 표의 새-RED 판정 대상에 포함된다.

### 선재 RED 목록

| 파일 | rc | 첫 실패 줄 |
|---|---|---|
| `plugins/agent-transparency/tests/ab_gate.sh` | 1 | `plugins/agent-transparency/tests/ab_gate.sh: line 23: AB_MODEL: parameter null or not set` |
| `plugins/quality-gates/tests/spike/test_codex_json_extraction.sh` | 1 | `no fenced JSON` (3회 실행 모두 실패) → `Spike result: 0/3 passed` / `FAIL: spike threshold not met. Halt before Task 4.` |
| `plugins/quality-gates/tests/test_consent_marker_write_failure.sh` | 1 | `FAIL: AC11: # QG-CONSENT-MARKER-WRITE block not found in SKILL.md` |
| `plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh` | 1 | `FAIL: kill switch env var present (got 0, expected >= 1)` (+ `FAIL: disable log message present (got 0, expected >= 1)`; 3건 중 1건만 PASS) |

**Task 4 점검 결과**: 새로 실행비트를 받은 14개(`plugins/spec-distill/tests/test_*.sh`, 목록은 아래 "실행비트 없는 셸 테스트" 절)를 각 1회 실행 — RED 0건. 표에 추가할 행 없음. 이 14개는 이 사이클에서 처음 실행된 것이라 이 표가 그 실행 결과의 유일한 기록이다.

## 파이썬 (`python3 -m unittest discover -s "$d" -t "$d"` per 테스트 디렉토리)

`find . -name __pycache__ -type d -prune -exec rm -rf {} +` + `PYTHONDONTWRITEBYTECODE=1` 적용 후 `plugins/*/tests`, `plugins/*/scripts/tests`, `plugins/*/hooks/tests` 6개 디렉토리에 대해 `python3 -m unittest discover -s "$d" -t "$d"` 실행 (python3 = 3.9.6). **`-t`를 레포 루트(`.`)가 아니라 디렉토리 자신으로 맞춘다** — 이유는 아래 "측정 노트" 참조.

| 디렉토리 | rc | Ran | 결과 |
|---|---|---|---|
| `plugins/agent-transparency/tests` | 0 | 283 | GREEN — OK |
| `plugins/project-init/tests` | 0 | 0 | GREEN — OK (이 디렉토리엔 `test_*.py`가 0개, 파이썬 테스트 자체가 없음 — 셸 전용) |
| `plugins/quality-gates/tests` | 0 | 128 | GREEN — OK |
| `plugins/spec-distill/tests` | 0 | 202 | GREEN — OK (skipped=1) |
| `plugins/plugin-audit/scripts/tests` | 0 | 249 | GREEN — OK |
| `plugins/project-init/hooks/tests` | 0 | 95 | GREEN — OK |

실행 6개 디렉토리 전부 GREEN, 합계 **957개** 테스트가 실제로 실행됨(283+0+128+202+249+95). 이 회차엔 기록할 선재 RED가 없다 — 아래 "측정 노트"가 설명하듯, 최초 측정에서 RED로 보였던 4개 디렉토리는 실제로는 테스트가 전혀 실행되지 않았던 것이었다.

### 측정 노트 — `-t .` 형태는 이 레포에서 구조적으로 불가능하다 (Task 30 근거, 삭제하지 않음)

브리프 Step 3 원문의 커맨드는 `python3 -m unittest discover -s "$d" -t .`였다. 이 형태는 이 레포 구조에서 **어떤 플러그인 디렉토리에도 성립할 수 없다** — `-t .`는 레포 루트를 import root로 삼으므로 `$d`가 거기서 내려오는 import 가능한 파이썬 패키지 경로여야 하는데, 대상 플러그인 이름(`spec-distill`, `quality-gates`, `plugin-audit`, `project-init`, `agent-transparency`) 전부 하이픈을 포함하고 **하이픈은 파이썬 식별자에 쓸 수 없다**. `__init__.py` 존재 여부와 무관하게 항상 `ImportError: Start directory is not importable`로 실패한다.

실측 비교(spec-distill 예):
```
-s plugins/spec-distill/tests -t .                          -> ImportError: Start directory is not importable
-s plugins/spec-distill/tests -t plugins/spec-distill/tests -> Ran 202 tests in 8.8s, OK (skipped=1)
```

Task 1 최초 실행(브리프 원문 그대로)에서 `agent-transparency`·`project-init`·`quality-gates`·`spec-distill` 4개 디렉토리는 "선재 RED"로 잘못 분류됐다 — 실제로는 **측정 자체가 불가능했던 것**이고 그 뒤에 613개(283+128+202)의 실제 테스트가 가려져 있었다. `-t .`로 몇 번을 다시 재보아도 항상 이 ImportError만 재현되므로, **이 형태의 커맨드는 회귀 판정에 쓸 수 없다**. 이 사실 자체는 지우지 않고 보존한다 — Task 30("python 테스트 실행 통일")이 레포 전역 파이썬 테스트 실행 방식을 하나로 정할 때, 하이픈 플러그인명 때문에 `-t .`가 원천 불가하다는 이 근거를 입력으로 쓴다.

## 실행비트 없는 셸 테스트 (Task 4에서 14개 해소 — 원 목록, 이력 보존)

측정 시점(`ee1d95f`)에 `git ls-files 'plugins/*' | grep -E '(^|/)tests?/.*\.sh$' | grep -vE '(/mocks/|/fixtures/|/harness/|/tests/lib/)'` 중 실행비트 없는 15개는 전부 `plugins/spec-distill/tests/`였다. **Task 4(2026-08-17)가 아래 14개(`test_*.sh`)에 실행비트를 부여했다** — qg 셸 어댑터(`run-test-selection.sh:383` `has_exec_shell_tests`의 `-perm -u+x`, `:825` `shell_unit_in_scope`의 `[[ -x ]]`)가 이제 이 14개를 선택할 수 있다. 실행비트 부여 자체는 이 문서 위 "Task 4 갱신" 절에 기록. 원 목록을 상태 표기와 함께 이력으로 보존한다:

- `plugins/spec-distill/tests/arm_test_helpers.sh` — **실행비트 없음, 의도적으로 유지**(Task 4가 제외). source 전용 헬퍼라 실행비트를 주면 qg 어댑터가 이를 독립 테스트 unit으로 오인해, source되도록 쓰인 코드를 단독 실행하게 된다. 향후 이 파일에 `chmod +x`를 하는 것은 "완료"가 아니라 회귀다.
- `plugins/spec-distill/tests/test_brainstorming_entry.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_brief_agents.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_brief_codex_axes.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_brief_inline_blob.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_brief_review_entry.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_build_spec_codex_prompt.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_detect_codex.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_kill_switches_v060.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_no_wall_clock.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_parse_spec_structure.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_probe_budget.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_readme_sync.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_reviewing_spec_design_only.sh` — 실행비트 부여됨 (Task 4)
- `plugins/spec-distill/tests/test_session_id_resolution.sh` — 실행비트 부여됨 (Task 4)

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

- 셸의 새-RED 점검은 §셸 표(위 "선재 RED 목록")를 기준으로 삼는다 — Task 4가 실행비트를 부여한 14개도 그 표의 "Task 4 점검 결과" 메모를 통해 이 기준에 포함된다.
- **파이썬의 새-RED 점검은 반드시 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$d" -t "$d"`(디렉토리마다 `-t`를 그 디렉토리 자신으로 맞춘 형태)로 재실행해서 §파이썬 표와 비교한다.** `-t .` 형태는 "측정 노트"가 설명하듯 이 레포에서 모든 플러그인에 대해 항상 실패하므로(하이픈 플러그인명), 어떤 후속 태스크도 이 형태를 회귀 판정에 재도입해서는 안 된다 — 재도입하면 4개 디렉토리 613개 테스트가 다시 "측정 불가"로 가려지고 그것이 다시 "선재 RED"로 오분류된다.
