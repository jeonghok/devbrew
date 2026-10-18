# `shared/test-selection/` — 차등 테스트 실행 공유본

qg 차등 테스트가 쓰는 스크립트 넷의 정본이다. 플러그인은 이 파일들을 자기 `scripts/` 에 같은 이름의 상대 심볼릭 링크로 둔다(`shared/docreview/` 와 같은 방식). 설치할 때 링크가 실제 내용으로 풀린다.

## 소비자 규칙

- **넷을 전부 링크한다** — `run-test-selection.sh` · `diff-test-results.py` · `compute-test-scope-candidates.sh` · `resolve-baseline.sh`. 셋만 링크하면 설치본에서 형제를 못 찾는다: `compute-test-scope-candidates.sh` 는 링크를 풀지 않은 자기 폴더에서 `resolve-baseline.sh` 를 부르고(`:18 · :54`), `diff-test-results.py` 는 링크를 푼 자기 폴더에서 `run-test-selection.sh` 를 찾는다(`:142`).
- 링크는 `ln -s ../../../shared/test-selection/<이름> plugins/<플러그인>/scripts/<이름>` 꼴의 상대 경로다.
- 바이트 그대로 옮긴 파일이라 qg 이름이 계약에 들어 있다. 차등 테스트를 끄는 변수는 어느 플러그인에서 불러도 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이다(`run-test-selection.sh:22`). 배정 · 행 파일의 꼬리 줄 `#qg-assign` · `#qg-rows`(`:13` · `:15`)는 소유자 이름이 아니라 형식 표지로 읽는다. 이름을 바꾸려면 kill switch 는 옛 이름을 별칭으로 계속 읽어야 한다.
- 이 파일들의 동작을 바꾸는 변경은 공유본 변경이다 — 링크한 모든 플러그인의 스위트로 잰다.
