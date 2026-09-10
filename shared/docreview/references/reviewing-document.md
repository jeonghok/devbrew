# 한 문서 리뷰 라운드의 절차

## 상한

`rereview_cap: 2` — 최초 리뷰가 라운드 1(`rereview_count` 0), 저자 수정 뒤 리뷰마다 +1, 2 에서 상한(라운드 3). 라운드 4 는 사용자가 승인 게이트에서 열어야만 돈다. 이 값의 정본은 이 한 줄이다.

## 한 라운드

진입 skill 은 이 순서를 한 턴 안에서 돈다. 상태는 `<state-dir>/docreview-state.md` 하나(`docreview_state.py`).

**선결(1단계 앞, 매 라운드)** — `mkdir -p <state-dir>` 그다음 `docreview_state.py init --state-dir D --doc <doc> --profile <profile>`.
`init` 은 멱등이다(이미 있으면 `{"created": false}` rc 0). 건너뛰면 1단계 `begin-round` 가 `state_missing` rc 1 이고, 디렉토리가 없으면 `init` 이 `state_dir_missing` rc 1 이다.

**왜 배포 경로에서 부르는가.** 스크립트는 배포 경로(`<플러그인 루트>/scripts/…`)에서 부른다. 정본(`shared/docreview/scripts/`)에서 부르면 안 된다 — 스크립트는 형제 파일에 의존하는데(셸 러너는 `runner_common.sh` 를, `docreview_route.py` 는 `adjudication` 모듈을) 그 형제는 배포 디렉토리에만 있다(정본 트리에서는 다른 자리에 산다). 그래서 정본에서 부르면 죽는 방식도 다르다: 셸 러너는 fail-closed 로 `codex_failed: true · reason: runner_common_unloadable` 을 기록하고 rc 0 으로 끝나고, `docreview_route.py` 는 `ModuleNotFoundError` 로 rc 1 에 죽는다.

1. **스냅샷** — `docreview_anchor.py snapshot <doc> > snap.json`. `docreview_state.py begin-round --state-dir D --snapshot snap.json` (라운드 4 이상은 `--extra-approval "<사용자 문구>"`; rc 3 이면 상한 — 승인 없이 진행하지 않는다).
2. **kill switch** — dispatch 직전에 확인하고 캐시하지 않는다. `DEVBREW_<HOST>_DISABLE`(전체)·`…_DISABLE_CODEX`·`…_DISABLE_WEB`·`…_DISABLE_RECRITIC`.
3. **탐지** — `doc-critic` 을 한 번 dispatch. 입력 슬롯: 문서(또는 번들) · 프로필 · (있으면) 같은 출처의 이전 라운드 finding id. 출력을 verbatim 파일로 저장한다.
4. **codex** — 산출물 경로는 **라운드마다 같아야 한다**(세션의 순수 함수 — `mktemp` 은 다음 셸이 재발견하지 못한다). 아래에서 `codex.yaml` 이라 부르는 것은 **그렇게 도출한 절대 경로**이지 벗은 상대 이름이 아니다 — 상대 이름은 cwd 의 함수라 동시 세션 둘이 같은 파일을 공유한다. 그래서 이 단계는 **그 경로의 중화로 시작한다**(아래 첫 불릿). 그다음 kill switch 가 codex 를 끄지 않았으면 `run_docreview_codex_reviewer.sh <profile> <doc> <project_dir> codex.yaml`, 그리고 `rc == 3` 이면 `rm -f codex.yaml`.
   - **왜 중화가 앞인가.** 5단계는 `meta.codex_failed` **하나로** 이 파일을 이번 라운드의 판정으로 읽는다. 직전 라운드가 성공했으면 그 파일에 `codex_failed: false` 가 남아 있고, codex 를 **건너뛴** 라운드(kill switch · 미설치 · 감지기 부재 · 게이트 입력 부재)는 그 잔존물을 이번 라운드의 codex 결과로 삼켜 `codex_absent: false` · degrade 없음으로 보고한다. 제거를 가용성 분기 **안**에 두면 그 넷이 전부 우회한다 — 사용자가 끈 라운드가 「모델 다양성 정상」으로 보이는 것은 P21 위반이다(kill switch 는 보안 컨트롤).
   - **판별자는 내용이 아니라 시점이다.** 직전 라운드의 산출물과 이번 라운드의 정직한 실패 기록은 스키마도 마커도 같아 내용으로 못 가른다. 진입에서 지우면 그 뒤에 있는 것은 이 실행이 쓴 것뿐이고, 러너가 `trap … EXIT`·`emit_fallback` 으로 남기는 이번 라운드의 degrade 기록(`codex_failed: true` + 사유)은 지움 **뒤**에 쓰이므로 살아남는다. 그러므로 **무조건 지움을 분기 뒤로 옮기지 마라** — 그러면 이번 라운드의 정직한 사유가 `yaml_missing_or_broken` 으로 뭉개진다.
   - **중화는 「시도」가 아니라 「보장」이어야 한다.** `rm -f` 의 rc 를 보지 않으면 이 규칙은 무조건형으로 적히고 조건부로 동작한다 — 실측: 상태 디렉토리가 쓰기 불가면 `rm` 이 rc 1 로 실패하고 파일이 살아남아 위 결함이 그대로 재현된다. unlink 는 **디렉토리** 권한을, 절단은 **파일** 권한을 요구하므로 둘은 함께 실패하지 않는다: 지우지 못하면 `: > codex.yaml` 로 0바이트로 만든다(0바이트는 5단계에서 이미 fail-closed 다 — 실측 `codex_absent: true`). 둘 다 실패하면 **조용히 넘어가지 말고** 그 라운드의 codex 축을 끄고 사유(`residue_unclearable`)와 함께 공시한다 — 그리고 5단계의 `--codex` 에 그 경로를 넘기지 않는다.
   - **왜 `rc == 3` 인가(그리고 `rc != 0` 이 왜 틀렸나).** 〔정정〕 이 자리는 한때 *"기록을 남기는 러너 종료는 전부 exit 0"* 이라는 이유로 `!= 0` 을 가르쳤다. **그 전제는 거짓이다.** EXIT 트랩은 「자기 rc 를 갖는 종료 지점」이 아니라 모든 종료에 얹히므로 **원래 실패의 rc 를 그대로 둔 채** 기록을 남긴다 — 실측: 트랩 무장 뒤 SIGTERM 이면 `rc 143` 과 `reason: aborted_before_completion` 인 정직한 이번 라운드 기록이 함께 나온다. 그래서 `!= 0` 은 바로 위 불릿이 「살아남는다」고 가르치는 그 기록을 지운다(같은 단계 안에서 자기모순이었다). 반대로 `!= 0` 이 대신 막아 주는 것은 **없다**: 0바이트 껍데기가 생기는 유일한 자리는 `runner_common` 미로드 + 기록 실패이고 그것은 rc **3** 이며(rc 2 는 절단 이전이라 파일 자체가 없다), 껍데기는 5단계에서 이미 fail-closed 다. 넓은 술어가 사는 것은 없고 잃는 것은 정직한 사유이므로 **`== 3` 이 `!= 0` 을 지배한다.** 형제 `framing-requests` 도 `-eq 3` 이다.
5. **익명화** — `docreview_route.py prepare-recritic --state-dir D --critic critic.txt --codex codex.yaml > prep.json`. rc 4 면 critic 사망 — 라운드를 세지 않고 재dispatch 1회, 또 실패면 승인 게이트를 「미검증」으로 연다. `prep.json` 의 `items` 가 재비판 입력이다.
6. **재비판** — recritic kill switch 가 아니면 `doc-recritic` 을 한 번 dispatch. 입력 슬롯 셋: 문서 · `prep.json` 의 items(출처 라벨 없음) · 프로필. 그 외 아무것도 넣지 않는다(프레이밍 차단). 출력을 verbatim 파일로.
7. **얼림 검사 + 라우팅** — 라운드 ≥ 2 면 `docreview_state.py exempt-anchors > ex.json` → `docreview_anchor.py diff prev.json snap.json --exempt ex.json > diff.json` → `docreview_state.py observe-diff --diff diff.json`(permit·fix 적용 관측). 그다음 `docreview_route.py finalize --state-dir D [--recritic recritic.txt | --recritic-skipped] [--diff diff.json] --doc <doc> > fin.json`.
8. **게이트** — `docreview_state.py gate --state-dir D --render`. `round_gate_needed` 면 라운드 게이트(`decide` 묶음 + 차단 `ask`)를 `AskUserQuestion` 하나로. 사용자 응답을 `decide`·`fix`·`ask` 서브커맨드로 반영. `approval_gate_open` 이면 승인 게이트(열린 것이 남아 있으면 두 단계). 진행 옵션의 정본은 `proceed-gate.md`.

## 배달

- `decide` → 라운드 게이트(결정 묶음). `defer` → `docreview_state.py defer --log-file <목적지>`. `fix` → 저자가 `check-intent <id> --intent <scope> --state-dir D` 통과 후 적용. `drop`·recritic `reject` → 회계에만 남고 게이트 텍스트에 개수 공시.
- 채택된 `decide` 의 적용은 `check-intent <id> --intent <scope> --state-dir D --decision-id <D#>`(permit 계약).

## degrade

codex 부재·critic 층 2 부재·recritic 부재는 `fin.json` 의 `advisory[]` 와 게이트 첫 줄로 공시한다. 막는 것은 critic 사망(주 판정자)·항목 소실·셀 수 없음뿐이다(`fin.json` 의 `blocks`).
