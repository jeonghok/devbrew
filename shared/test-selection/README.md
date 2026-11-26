# `shared/test-selection/` — 차등 테스트 실행 공유본

qg 차등 테스트가 쓰는 스크립트 넷의 정본이다. 플러그인은 이 파일들을 자기 `scripts/` 에 같은 이름의 상대 심볼릭 링크로 둔다(`shared/docreview/` 와 같은 방식). 설치할 때 링크가 실제 내용으로 풀린다.

## 소비자 규칙

- **넷을 전부 링크한다** — `run-test-selection.sh` · `diff-test-results.py` · `compute-test-scope-candidates.sh` · `resolve-baseline.sh`. 셋만 링크하면 설치본에서 형제를 못 찾는다: `compute-test-scope-candidates.sh` 는 링크를 풀지 않은 자기 폴더에서 `resolve-baseline.sh` 를 부르고(`:20 · :56`), `diff-test-results.py` 는 링크를 푼 자기 폴더에서 `run-test-selection.sh` 를 찾는다(`:146`).
- 링크는 `ln -s ../../../shared/test-selection/<이름> plugins/<플러그인>/scripts/<이름>` 꼴의 상대 경로다.
- 바이트 그대로 옮긴 파일이라 qg 이름이 계약에 들어 있다. 차등 테스트를 끄는 변수는 어느 플러그인에서 불러도 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이다(`run-test-selection.sh:22`). 배정 · 행 파일의 꼬리 줄 `#qg-assign` · `#qg-rows`(`:13` · `:15`)는 소유자 이름이 아니라 형식 표지로 읽는다. 이름을 바꾸려면 kill switch 는 옛 이름을 별칭으로 계속 읽어야 한다.
- 이 파일들의 동작을 바꾸는 변경은 공유본 변경이다 — 링크한 모든 플러그인의 스위트로 잰다.
- 배정 파일의 둘째 칸은 러너 이름이거나 `unclaimed` · `support` 다. 둘 다 러너가 아니다 — 배정을 읽어 `run` 을 부르는 소비자는 두 값을 함께 거른다.

## 지원 파일(`support`)

- 지원 파일은 경로에 `tests` · `test` 폴더가 있고 이름이 테스트 꼴이 아닌 파일이다. 테스트 꼴 이름은 마지막 성분이 `test_` 로 시작하거나 `_test.<확장자>` · `.test.<확장자>` · `.spec.<확장자>` 로 끝나는 것이다.
- 길 위 폴더는 그 파일이 든 폴더부터 가장 가까운 `tests` · `test` 폴더까지다(둘 다 포함). 하위 폴더로는 내려가지 않는다.
- `compute-test-scope-candidates.sh` 는 바뀐 지원 파일마다 길 위 폴더에 바로 든 테스트 꼴 파일을 후보에 더한다.
- `run-test-selection.sh assign` 은 흡수 러너(cargo · make · npm-script)가 없을 때 맡지 않은 지원 파일을 가른다. 같은 입력에서 러너가 맡은 파일(패키지로 접기 전 경로)이 길 위 폴더에 바로 있으면 `support`, 없으면 `unclaimed` 다. 흡수 러너가 있으면 지금처럼 `BULK` 가 흡수한다.
- `diff-test-results.py` 는 `support` 행을 unit 전체 · `unclaimed` · `silent-drop` 에서 빼고 `support: [...]` · `support_tests: <n>` 을 낸다. `support_tests` 는 길 위 폴더에 바로 든, 러너가 맡은 행의 수다(겹치면 한 번).

## unittest 맡기(`run-test-selection.sh assign`)

- 이름이 테스트 꼴인 `.py` 가운데 모듈 수준 `def test…` 가 있는 파일은 글자로 거른다 — 불러 보지 않고 맡지 않는다.
- 나머지는 루프 뒤에 한 번 불러 본다(`unittest_probe`). 관문은 이 순서다: 일회용 트리인가(`tree_is_disposable` — `run` 과 같은 검사) → `adapter_usable`(kill switch → 감지 → 환경 폴더 무시 여부 → 준비 → 러너). 어느 하나에서 멈추면 불러 보지 않고 그 사유를 표준 오류에 남긴 채 unittest 가 맡지 않는다.
- 불러 보기는 실행 줄과 같은 파이썬 · 같은 작업 폴더 · 같은 경로 꼴(`__init__.py` 가 있으면 점 이름, 없으면 그 폴더를 앞에 둔 바탕 이름)로 폴더마다 한 번 돈다. 그 모듈에서 정의된 모듈 수준 클래스 가운데 이름이 `Test` 로 시작하거나 `test` 로 시작하는 이름(물려받은 것 포함)을 가진 것이 모두 `unittest.TestCase` 의 자손일 때만 맡는다. 불러오지 못하면 맡지 않는다. 판정은 결과 파일의 줄로만 받는다 — 모듈의 표준 출력 · 종료 코드는 보지 않는다.
- 지원 파일의 `support` / `unclaimed` 는 불러 보기가 끝난 뒤의 맡음으로 가른다.
- unittest 실행은 테스트 0개로 끝나면 종료 코드 5(행 상태 `error`)다 — 파이썬 판(3.12 미만은 0, 3.12 부터는 5)에 따라 갈리지 않는다.
- 비용: 불러 보기는 준비(`uv sync` 등)를 먼저 한 번 돈다. 스위트 대조의 대체 경로(spec-distill `merge_check.assignment`)는 `assign` 을 두 번 부르므로 준비와 불러 보기도 두 번 돈다.

## 기준선(`resolve-baseline.sh`)

- 기준 브랜치는 `origin/HEAD` 가 가리키는 브랜치 하나다. `origin/main` · `origin/master` · 로컬 `main` · `master` 로 대신하지 않는다.
- 출력은 키 일곱 줄이다: `base` · `base_ref` · `merge_base` · `degraded` · `degraded_reason` · `same_as_head` · `ahead`. 소비자는 줄 번호가 아니라 키로 읽는다.
- `base` 는 짧은 이름(`main`), `base_ref` 는 전체 이름(`refs/remotes/origin/main`)이다. `origin/main` 이라는 로컬 브랜치가 있어도 기준이 바뀌지 않는다.
- `degraded_reason` 은 `-`(풀림) · `no-default-branch` · `not-a-repo` · `no-head` · `detached` · `shallow` · `merge-base` 중 하나다.
- `origin/HEAD` 가 없거나 가리키는 브랜치가 없으면 `degraded_reason: no-default-branch` 와 함께 stderr 에 안내 한 줄을 낸다. `git remote set-head origin --auto` 로 고친다.
- stderr 를 버리는 소비자(`compute-test-scope-candidates.sh` 등)는 `degraded_reason` 을 읽어 같은 안내를 자기 이름으로 낸다.
