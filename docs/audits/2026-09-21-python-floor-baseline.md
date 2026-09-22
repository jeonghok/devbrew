# Python 바닥 상향 — 착수 전 baseline (base `d24d3045`)

> 구현 후 회귀 판정의 기준선. **rc 만이 아니라 실패 「줄 수」와 `Ran N` 을 함께** 적는다 —
> rc 만 보면 이미 RED 인 자리 **안**의 새 실패가 원리적으로 안 보인다.

- 측정일: 2026-09-21
- base: `d24d3045` (#159 머지 — agent-transparency 제거 반영)
- 인터프리터: `python3` = `/usr/bin/python3` = **3.9.6** (macOS 26 / Darwin 25.6.0)
- 관련 설계: [`../superpowers/specs/2026-09-21-python-floor-and-uv-design.md`](../superpowers/specs/2026-09-21-python-floor-and-uv-design.md)

## 1. 코퍼스와 배제

| 축 | 도출 | 수 |
|---|---|---|
| bash | `git ls-files '*/tests/*.sh'` 에서 `/(mocks\|lib\|harness\|fixtures\|spike)/` 배제 | **205** |
| python | `git ls-files '*/tests/test_*.py'` → `dirname -u`, 같은 규칙으로 배제 | **4 디렉토리 / 648 tests** |

**배제 19건의 이유** — 전부 「테스트가 아닌 것」이다:

| 디렉토리 | 이유 |
|---|---|
| `mocks/` | codex 응답을 흉내내는 스텁. 단독 실행에 의미가 없고 `mock-codex-hang.sh` 는 **이름 그대로 매달린다** |
| `lib/` | 테스트가 `source` 하는 헬퍼 |
| `harness/` | 테스트를 **돌리는** 쪽 |
| `fixtures/` | 피검 대상 샘플. `fixtures/test-scope/outdated/tests/test_legacy.py` 는 `from src.legacy import parse_v1  # <- references removed symbol` 로 **의도적으로 깨뜨린** 입력이다 |
| `spike/` | 일회성 탐침 |

`shared/tests/` 의 `test_` 접두어 없는 5개(`assert.sh` · `presence_corpus.sh` ·
`docreview_fixture_corpus.sh` · `adopter_derivation.sh` · `abort_trigger.sh`)는 라이브러리로 보이지만
**배제하지 않았다** — 배제 판단이 틀리면 진짜 테스트를 잃는데, 포함은 타임아웃으로 안전하게 묶이기 때문이다.

## 2. 결과

```
bash    205 자리 → RED 3
python    4 자리 → 648 tests, RED 1
```

### 선재 RED 4건 — 각각의 이유

| 자리 | rc | 이유 |
|---|---|---|
| `plugins/spec-distill/tests` (`Ran 157`, `failures=1`) | 1 | `TestCrossResolverAdvisory.test_python_and_bash_resolvers_agree`. **워크트리 안에서 항상 실패** — 파이썬 `state_path` 는 메인 체크아웃의 `.claude/spec-distill` 을(설계 §4.8 대로), bash resolver 는 워크트리 경로를 반환해 「disagree」. 환경 의존이며 회귀가 아니다 |
| `plugins/quality-gates/tests/test_runner_adapters.sh` (`Total 53`, `Fail 1`) | 1 | `case_qg_test_scripts_are_executable` — `plugins/quality-gates/tests/test_cancel_all_fence.sh` 만 mode `100644` 다. 같은 디렉토리의 나머지 **115개가 전부 `100755`** 이므로 규약을 깬 한 파일이 원인 |
| `plugins/quality-gates/tests/test_codex_backward_compat.sh` | 1 | **126초** 뒤 실패. 90초 상한에서는 `rc 124`(타임아웃)로 보였으나 600초를 주면 완주 후 rc 1 이다 — 「매달림」이 아니라 「느린 진짜 RED」 |
| `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` | 1 | 「양성 대조 실패: Bash matcher 훅이 1개뿐」. 리포의 Bash matcher 는 `plugins/project-init/hooks/hooks.json:6` 하나다. **#159 가 만든 것이 아니다** — 병합 양쪽 부모(`d24d3045^1`·`^2`) 모두 이미 1개였다 |

### 타임아웃으로 오분류될 뻔한 자리

| 자리 | 90초 | 600초 | 판정 |
|---|---|---|---|
| `shared/tests/test_docreview_mutations.sh` | rc 124 | **rc 0 · 113초** | GREEN — 그냥 느리다 |
| `plugins/quality-gates/tests/test_codex_backward_compat.sh` | rc 124 | **rc 1 · 126초** | 진짜 RED |

같은 `rc 124` 가 정반대 두 사실을 덮고 있었다. 상한을 늘리지 않았다면 전자는 「깨진 테스트」로,
후자는 「환경 문제」로 오분류됐을 것이고 **틀리는 방향이 반대라 평균으로도 맞지 않는다.**

## 3. 러너

자리당 상한 90초(타임아웃 자리만 600초 재시도), `PYTHONDONTWRITEBYTECODE=1`.
`timeout` 은 coreutils 의 것이다(macOS 기본이 아니다).

```bash
#!/bin/bash
set -u
W=<리포 루트>; OUT="$1"; TMO=$(command -v timeout || command -v gtimeout); LIMIT=90
export PYTHONDONTWRITEBYTECODE=1
cd "$W" || exit 1
: > "$OUT"
printf '# baseline @ %s  %s\n' "$(git rev-parse --short HEAD)" "$(date -u +%FT%TZ)" >> "$OUT"
printf '# interpreter: %s\n' "$(python3 -V 2>&1)" >> "$OUT"

echo "## BASH" >> "$OUT"
git ls-files '*/tests/*.sh' | grep -vE '/(mocks|lib|harness|fixtures|spike)/' | sort | while IFS= read -r t; do
  o=$("$TMO" "$LIMIT" bash "$t" 2>&1); rc=$?
  n=$(printf '%s\n' "$o" | grep -ciE '^(not ok|FAIL|✗|ERROR)')
  echo "$rc $n $t" >> "$OUT"
done

echo "## PYTHON" >> "$OUT"
git ls-files '*/tests/test_*.py' | grep -vE '/(mocks|lib|harness|fixtures|spike)/' \
  | xargs -n1 dirname | sort -u | while IFS= read -r d; do
  o=$(cd "$W/$d" && "$TMO" "$LIMIT" python3 -m unittest discover -s . -t . -p 'test_*.py' 2>&1); rc=$?
  ran=$(printf '%s\n' "$o" | grep -oE 'Ran [0-9]+ test' | grep -oE '[0-9]+' | tail -1)
  fe=$(printf '%s\n' "$o" | grep -oE '(failures|errors)=[0-9]+' | tr '\n' ',')
  echo "$rc ran=${ran:-?} ${fe:-ok} $d" >> "$OUT"
done
```

## 4. 이 기록이 말하지 않는 것

- **자리별 실패 «줄 수»는 bash 쪽만 있다.** python 쪽은 디렉토리 단위 `Ran N / failures=M` 이므로,
  한 디렉토리 안에서 실패가 **다른 테스트로 옮겨가도** 수가 같으면 안 보인다. 회귀 판정 시
  `failures` 수뿐 아니라 실패한 **테스트 이름**을 대조해야 한다.
- **`/qg` 가 고르는 코퍼스와 이 목록은 다르다.** 이것은 전수 실행이고, `/qg` 는 `# guards:` 선언과
  변경 파일로 고른다.
- **설치본에서의 동작은 재지 않았다.** 이 실행은 전부 리포 워크트리 안이다.
