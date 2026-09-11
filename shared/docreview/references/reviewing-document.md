# 한 문서 리뷰 라운드의 절차

## 상한

`rereview_cap: 2` — 최초 리뷰가 라운드 1(`rereview_count` 0), 저자 수정 뒤 리뷰마다 +1, 2 에서 상한(라운드 3). 라운드 4 는 사용자가 승인 게이트에서 열어야만 돈다. 이 값의 정본은 이 한 줄이다.

## 한 라운드

진입 skill 은 이 순서를 한 턴 안에서 돈다. 상태는 `<state-dir>/docreview-state.md` 하나(`docreview_state.py`).

**선결(1단계 앞, 매 라운드)** — `mkdir -p <state-dir>` 그다음 `docreview_state.py init --state-dir D --doc <doc> --profile <profile>`.
상태 디렉토리는 **문서별**이어야 한다 — `docreview_state.py state-dir-for --root <상태 루트> --session <세션 id> --doc <doc>` 가 세션과 문서 경로의 순수 함수로 그 자리를 내고, `init` 은 이미 있는 원장이 다른 문서(또는 다른 프로필)의 것이면 `state_doc_mismatch`(`state_profile_mismatch`) rc 1 로 거부한다 — 한 디렉토리를 문서 둘이 쓰면 라운드·재리뷰 상한·finding 이 문서를 넘어 섞인다. 같은 문서면 `init` 은 멱등이다(이미 있으면 `{"created": false}` rc 0 — 경로는 절대경로·심볼릭 링크를 풀어 비교하고 프로필은 이름으로 비교한다). 건너뛰면 1단계 `begin-round` 가 `state_missing` rc 1 이고, 디렉토리가 없거나 빈 값이면 `init` 이 `state_dir_missing` rc 1 이다. `--doc` 은 절대경로여야 한다(상대경로는 `doc_not_absolute` — 문서의 정체가 cwd 의 함수가 된다). **`init` 의 rc 가 0 이 아니면 값과 무관하게 이 라운드를 진행하지 않는다** — `begin-round` 는 문서를 보지 않으므로, 거부를 넘어 진행하면 다른 문서의 원장 위에서 라운드가 돈다.

**왜 배포 경로에서 부르는가.** 스크립트는 배포 경로(`<플러그인 루트>/scripts/…`)에서 부른다. 정본(`shared/docreview/scripts/`)에서 부르면 안 된다 — 스크립트는 형제 파일에 의존하는데(셸 러너는 `runner_common.sh` 를, `docreview_route.py` 는 `adjudication` 모듈을) 그 형제는 배포 디렉토리에만 있다(정본 트리에서는 다른 자리에 산다). 그래서 정본에서 부르면 죽는 방식도 다르다: 셸 러너는 fail-closed 로 `codex_failed: true · reason: runner_common_unloadable` 을 기록하고 rc 0 으로 끝나고, `docreview_route.py` 는 `ModuleNotFoundError` 로 rc 1 에 죽는다.

1. **스냅샷** — `docreview_anchor.py snapshot <doc> > snap.json`. `docreview_state.py begin-round --state-dir D --snapshot snap.json` (라운드 4 이상은 `--extra-approval "<사용자 문구>"`; rc 3 이면 상한 — 승인 없이 진행하지 않는다). **rc 가 0 이 아니면 값과 무관하게 이 라운드를 진행하지 않는다** — rc 3 밖의 non-zero 는 이번 라운드 시작 표식이 기록됐다고 믿을 수 없다는 뜻이고, 5단계의 시점 판별(4단계 중화가 불가능한 조합의 집행)이 그 표식에 기댄다.
2. **kill switch** — dispatch 직전에 확인하고 캐시하지 않는다. `DEVBREW_<HOST>_DISABLE`(전체)·`…_DISABLE_CODEX`·`…_DISABLE_WEB`·`…_DISABLE_RECRITIC`.
3. **탐지** — 진입 skill 이 고른 탐지 리뷰어를 한 번 dispatch. 기본은 `doc-critic` 이고, 프로필이 `web: true` 인 자리는 자기 선택 펜스로 웹 사본 `doc-critic-web` 을 지명할 수 있다(어느 쪽인지는 진입 skill 이 정한다). 입력 슬롯: 문서(또는 번들) · 프로필 · (있으면) 같은 출처의 이전 라운드 finding id. 출력을 verbatim 파일로 저장한다.
4. **codex** — 산출물 경로는 **같은 문서의 라운드마다 같아야 한다**(세션과 문서의 순수 함수 — 문서별 상태 디렉토리 안에 둔다. `mktemp` 은 다음 셸이 재발견하지 못한다). 아래에서 `codex.yaml` 이라 부르는 것은 **그렇게 도출한 절대 경로**이지 벗은 상대 이름이 아니다 — 상대 이름은 cwd 의 함수라 동시 세션 둘이 같은 파일을 공유한다. 그래서 이 단계는 **그 경로의 중화로 시작한다**(아래 첫 불릿). 그다음 kill switch 가 codex 를 끄지 않았으면 `run_docreview_codex_reviewer.sh <profile> <doc> <project_dir> codex.yaml`, 그리고 `rc == 3` 이면 `rm -f codex.yaml`.
   - **왜 중화가 앞인가.** 파일 내용으로 5단계가 볼 수 있는 것은 `meta.codex_failed` 하나다. 직전 라운드가 성공했으면 그 파일에 `codex_failed: false` 가 남아 있고, codex 를 **건너뛴** 라운드(kill switch · 미설치 · 감지기 부재 · 게이트 입력 부재)가 그것을 남기면 5단계가 이번 라운드의 codex 결과로 삼켜 `codex_absent: false` · degrade 없음으로 보고할 수 있다(5단계의 시점 판별은 1단계가 이번 라운드 시작을 기록했다는 전제 위에 있다 — 이 중화는 그 전제에 기대지 않는다). 제거를 가용성 분기 **안**에 두면 그 넷이 전부 우회한다 — 사용자가 끈 라운드가 「모델 다양성 정상」으로 보이는 것은 P21 위반이다(kill switch 는 보안 컨트롤).
   - **판별자는 내용이 아니라 시점이다.** 직전 라운드의 산출물과 이번 라운드의 정직한 실패 기록은 스키마도 마커도 같아 내용으로 못 가른다. 진입에서 지우면 그 뒤에 있는 것은 이 실행이 쓴 것뿐이고, 러너가 `trap … EXIT`·`emit_fallback` 으로 남기는 이번 라운드의 degrade 기록(`codex_failed: true` + 사유)은 지움 **뒤**에 쓰이므로 살아남는다. 그러므로 **무조건 지움을 분기 뒤로 옮기지 마라** — 그러면 이번 라운드의 정직한 사유가 `yaml_missing_or_broken` 으로 뭉개진다.
   - **중화는 「시도」가 아니라 「보장」이어야 한다.** `rm -f` 의 rc 를 보지 않으면 이 규칙은 무조건형으로 적히고 조건부로 동작한다 — 실측: 상태 디렉토리가 쓰기 불가면 `rm` 이 rc 1 로 실패하고 파일이 살아남아 위 결함이 그대로 재현된다. unlink 는 **디렉토리** 권한을, 절단은 **파일** 권한을 요구한다: 지우지 못하면 `: > codex.yaml` 로 0바이트로 만든다(0바이트는 5단계에서 이미 fail-closed 다 — 실측 `codex_absent: true`). 둘 다 실패하면(디렉토리·파일 모두 쓰기 불가) **조용히 넘어가지 말고** 그 라운드의 codex 축을 끄고 사유(`residue_unclearable`)와 함께 공시한다 — 그리고 5단계의 `--codex` 에 그 경로를 넘기지 않는다. 1단계가 이번 라운드에 rc 0 으로 끝났다면 5단계의 시점 판별이 그 파일을 부재로 읽지만(`codex_predates_round`), 그것은 그 전제 위의 두 번째 방어다.
   - **왜 `rc == 3` 인가(그리고 `rc != 0` 이 왜 틀렸나).** 〔정정〕 이 자리는 한때 *"기록을 남기는 러너 종료는 전부 exit 0"* 이라는 이유로 `!= 0` 을 가르쳤다. **그 전제는 거짓이다.** EXIT 트랩은 「자기 rc 를 갖는 종료 지점」이 아니라 모든 종료에 얹히므로 **원래 실패의 rc 를 그대로 둔 채** 기록을 남긴다 — 실측: 트랩 무장 뒤 SIGTERM 이면 `rc 143` 과 `reason: aborted_before_completion` 인 정직한 이번 라운드 기록이 함께 나온다. 그래서 `!= 0` 은 바로 위 불릿이 「살아남는다」고 가르치는 그 기록을 지운다(같은 단계 안에서 자기모순이었다). 반대로 `!= 0` 이 대신 막아 주는 것은 **없다** — 0바이트 껍데기는 러너가 출력 경로를 절단한 뒤 자신의 EXIT 트랩(`_degrade_if_empty`)이 기록을 끝내기 전에 죽으면 생기고, 그 죽음은 rc 하나로 안 좁혀진다(실측: 트랩 자체가 못 뜨는 신호 종료 SIGKILL·SIGXFSZ 둘 다 같은 껍데기를 남겼다). 트랩이 뜨는 종료(SIGTERM, 위 문단)는 이미 정직한 기록을 남기고, 트랩이 못 뜨는 나머지는 5단계(익명화)가 빈 파일을 이미 fail-closed 로 읽으므로(실측 `codex_absent: true`) 술어를 넓힐 이유가 없다. `rc == 3` 이 실제로 디스크에 남기는 것은 새 껍데기가 아니라 **원래 있던 것 그대로**다(실측: 경로가 애초에 쓰기 불가면 파일 자체가 없고, 사전에 0바이트 껍데기나 이전 라운드의 실 데이터가 있었으면 그 내용이 손대지 않은 채 남는다) — 그래서 이 단계 맨 앞의 `rc == 3` 이면 `rm -f codex.yaml` 이 정확히 이 잔존을 치우는 조치다. 잃는 것은 정직한 사유뿐이므로 **`== 3` 이 `!= 0` 을 지배한다.** 형제 `framing-requests` 도 `-eq 3` 이다.
5. **익명화** — `docreview_route.py prepare-recritic --state-dir D --critic critic.txt --codex codex.yaml > prep.json`. `codex.yaml` 이 1단계 `begin-round` 가 기록한 이번 라운드 시작보다 먼저(또는 같은 시각에) 쓰였으면 내용과 무관하게 부재로 읽는다(`codex_predates_round`; 기록이 없으면 `round_start_unrecorded`, 정수가 아니면 `round_start_unreadable`) — 4단계의 중화가 불가능한 권한 조합(상태 디렉토리와 그 파일이 둘 다 쓰기 불가, 상태 파일은 쓰기 가능 — 이때 1단계는 통과한다)의 집행 지점이 여기다. rc 4 면 critic 사망 — 라운드를 세지 않고 재dispatch 1회, 또 실패면 6~7단계를 건너뛰고 8단계로 가 승인 게이트를 「미검증」으로 연다. 그 사실은 엔진이 안다 — 이 단계가 이번 라운드의 준비에 critic 사망을 남기고 그 준비는 7단계의 성공만 치우므로, 8단계 요약이 `unverified: critic_dead` 를 내고 렌더 첫 줄이 그 공시로 시작한다. `prep.json` 의 `items` 가 재비판 입력이다.
6. **재비판** — recritic kill switch 가 아니면 `doc-recritic` 을 한 번 dispatch. 입력 슬롯 셋: 문서 · `prep.json` 의 items(출처 라벨 없음) · 프로필. 그 외 아무것도 넣지 않는다(프레이밍 차단). 출력을 verbatim 파일로.
7. **얼림 검사 + 라우팅** — 라운드 ≥ 2 면 `docreview_state.py exempt-anchors > ex.json` → `docreview_anchor.py diff prev.json snap.json --exempt ex.json > diff.json` → `docreview_state.py observe-diff --diff diff.json`(permit·fix 적용 관측). 그다음 `docreview_route.py finalize --state-dir D [--recritic recritic.txt | --recritic-skipped] [--diff diff.json] --doc <doc> > fin.json`. **`finalize` 의 rc 가 0 이 아니면 값과 무관하게 이 라운드를 정상 게이트로 넘기지 않는다** — 그 `fin.json` 은 비었거나 직전 라운드 것이라 판정에 쓰지 않고, 8단계는 엔진이 「미검증」으로 낸 게이트다(`unverified: finalize_incomplete`): 실패한 `finalize` 는 이번 라운드의 준비를 치우지 못했거나(라우팅 전에 죽었다) 이번 라운드 자리에 거부 표지를 남긴다(준비가 없거나 다른 라운드 것이라 소비하지 않았다). 모양은 선결 `init` · 1단계의 rc 규칙(값과 무관하게)과 같되, 탐지가 이미 돈 뒤라 라운드를 되돌리지 않고 critic 사망과 같은 「미검증」 게이트로 닫는다 — 둘 다 이번 라운드의 판정이 원장에 없다는 같은 사실이라 막는 것은 같고, 공시하는 사유만 다르다.
8. **게이트** — `docreview_state.py gate --state-dir D --render`. `round_gate_needed` 면 라운드
게이트(`decide` 묶음 + 차단 `ask`, 렌더 순서)를 **`AskUserQuestion` 최대 4개씩 연속 호출**로 나눠
띄운다 — 도구가 호출당 질문을 4개로 제한하고, 한 결정을 다른 결정의 질문에 묶으면 그 결정의
선택지가 사라지기 때문이다. 매 호출 첫 질문의 첫 줄은 렌더 첫 줄(degrade 공시)과 같다. 사용자
응답을 `decide`·`fix`·`ask` 서브커맨드로 반영. `approval_gate_open` 이면 승인 게이트. 열린 것이
남아 있으면 두 단계다(**1단계는 라운드 게이트와 같은 형태라 같은 분할이 적용된다**, §6.4).
**상한 도달이면 열린 것이 0 이어도 항상 두 단계다** — 그때 1단계는 열린 것의 유무로 갈린다:
**열린 것이 0 이면 1단계 선택지는 「추가 라운드 1회 열기」와 「진행 옵션으로」 둘뿐인 질문
하나다.** **열린 것이 있으면 그 열린 항목들과 함께 「추가 라운드 1회 열기」가 별개 항목으로
렌더 순서 맨 끝에 서고, 같은 4개씩 분할에 함께 세어지며, 선택지 「열기 / 열지 않음」 둘뿐인 그
자신의 질문이다**(열린 항목을 마저 처리하는 것과는 독립적으로 고른다 — 다른 항목의 질문에
얹지 않는다). 「추가 라운드 1회 열기」를 고르면 다음 라운드 1단계가 `begin-round --extra-approval "<사용자
자신의 문구>"` 로 돈다(그 문구가 `extra_rounds` 에 개별 기록된다). 2단계(네 옵션)의 정본은
`proceed-gate.md`. 요약(`gate --state-dir D`, `--render` 없이)의 `approval_label` 이 있으면(「미검증」) 승인
게이트를 그 라벨로 연다 — 라벨의 정본은 엔진 출력이고, 사유는 `unverified`(`critic_dead` · `finalize_incomplete`)다.
리뷰 완료 기록(호스트의 mark-reviewed 류)은 그 요약의 `round_reviewed` 가 참일 때만 남긴다 — 이번 라운드가
`finalize` 로 끝나지 않았거나 「미검증」이면 거짓이고, 다음 라운드가 정상으로 끝나면 다시 참이 된다. 거짓인 라운드는
요약의 `unreviewed_reason` 이 사유를 말하고(「미검증」 둘, 또는 finalize 보고서가 없는 `unrouted` — `unrouted` 에는 라벨이
붙지 않는다) 렌더 첫 줄이 그것을 공시하며 「다음:」 줄에 리뷰 완료가 아니라는 꼬리가 붙는다.

## 배달

- `decide` → 라운드 게이트(결정 묶음). `defer` → `docreview_state.py defer --log-file <목적지>`. `fix` → 저자가 `check-intent <id> --intent <scope> --state-dir D` 통과 후 적용. `drop`·recritic `reject` → 회계에만 남고 게이트 텍스트에 개수 공시.
- 채택된 `decide` 의 적용은 `check-intent <id> --intent <scope> --state-dir D --decision-id <D#>`(permit 계약).

## degrade

codex 부재·critic 층 2 부재·recritic 부재는 `fin.json` 의 `advisory[]` 와 게이트 첫 줄로 공시한다. 막는 것은 critic 사망(주 판정자)·항목 소실·셀 수 없음뿐이다(`fin.json` 의 `blocks`). critic 사망과 `finalize` 실패는 `fin.json` 이 없는 라운드에서도 게이트 요약(`unverified` · `round_reviewed`)과 렌더 첫 줄이 말한다.
