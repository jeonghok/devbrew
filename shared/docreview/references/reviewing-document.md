# 한 문서 리뷰 라운드의 절차

## 상한

`rereview_cap: 2` — 최초 리뷰가 라운드 1(`rereview_count` 0), 저자 수정 뒤 리뷰마다 +1, 2 에서 상한(라운드 3). 라운드 4 는 사용자가 승인 게이트에서 열어야만 돈다. 이 값의 정본은 이 한 줄이다.

## 한 라운드

진입 skill 은 이 순서를 한 턴 안에서 돈다. 상태는 `<state-dir>/docreview-state.md` 하나(`docreview_state.py`).

1. **스냅샷** — `docreview_anchor.py snapshot <doc> > snap.json`. `docreview_state.py begin-round --state-dir D --snapshot snap.json` (라운드 4 이상은 `--extra-approval "<사용자 문구>"`; rc 3 이면 상한 — 승인 없이 진행하지 않는다).
2. **kill switch** — dispatch 직전에 확인하고 캐시하지 않는다. `DEVBREW_<HOST>_DISABLE`(전체)·`…_DISABLE_CODEX`·`…_DISABLE_WEB`·`…_DISABLE_RECRITIC`.
3. **탐지** — `doc-critic` 을 한 번 dispatch. 입력 슬롯: 문서(또는 번들) · 프로필 · (있으면) 같은 출처의 이전 라운드 finding id. 출력을 verbatim 파일로 저장한다.
4. **codex** — kill switch 가 codex 를 끄지 않았으면 `run_docreview_codex_reviewer.sh <profile> <doc> <project_dir> codex.yaml`. rc 3 이면 `rm -f codex.yaml`(stale 방지).
5. **익명화** — `docreview_route.py prepare-recritic --state-dir D --critic critic.txt --codex codex.yaml > prep.json`. rc 4 면 critic 사망 — 라운드를 세지 않고 재dispatch 1회, 또 실패면 승인 게이트를 「미검증」으로 연다. `prep.json` 의 `items` 가 재비판 입력이다.
6. **재비판** — recritic kill switch 가 아니면 `doc-recritic` 을 한 번 dispatch. 입력 슬롯 셋: 문서 · `prep.json` 의 items(출처 라벨 없음) · 프로필. 그 외 아무것도 넣지 않는다(프레이밍 차단). 출력을 verbatim 파일로.
7. **얼림 검사 + 라우팅** — 라운드 ≥ 2 면 `docreview_state.py exempt-anchors > ex.json` → `docreview_anchor.py diff prev.json snap.json --exempt ex.json > diff.json` → `docreview_state.py observe-diff --diff diff.json`(permit·fix 적용 관측). 그다음 `docreview_route.py finalize --state-dir D [--recritic recritic.txt | --recritic-skipped] [--diff diff.json] --doc <doc> > fin.json`.
8. **게이트** — `docreview_state.py gate --state-dir D --render`. `round_gate_needed` 면 라운드 게이트(`decide` 묶음 + 차단 `ask`)를 `AskUserQuestion` 하나로. 사용자 응답을 `decide`·`fix`·`ask` 서브커맨드로 반영. `approval_gate_open` 이면 승인 게이트(열린 것이 남아 있으면 두 단계). 진행 옵션의 정본은 `proceed-gate.md`.

## 배달

- `decide` → 라운드 게이트(결정 묶음). `defer` → `docreview_state.py defer --log-file <목적지>`. `fix` → 저자가 `check-intent <id> --intent <scope> --state-dir D` 통과 후 적용. `drop`·recritic `reject` → 회계에만 남고 게이트 텍스트에 개수 공시.
- 채택된 `decide` 의 적용은 `check-intent <id> --intent <scope> --state-dir D --decision-id <D#>`(permit 계약).

## degrade

codex 부재·critic 층 2 부재·recritic 부재는 `fin.json` 의 `advisory[]` 와 게이트 첫 줄로 공시한다. 막는 것은 critic 사망(주 판정자)·항목 소실·셀 수 없음뿐이다(`fin.json` 의 `blocks`).
