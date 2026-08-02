# Changelog

## [0.24.6] — 2026-08-03

### Changed
- `run_codex_reviewer.sh` · `run_artifact_codex_reviewer.sh`(qg) /
  `run_spec_codex_reviewer.sh`(spec-distill)에서 `-c 'model_reasoning_effort="medium"'`
  실행 인자 삭제. 하니스가 medium을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고,
  그 하향은 codex co-review의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다.
  `run_brief_codex_reviewer.sh`가 이미 쓰던 계약을 전파한 것이다.
  **load-bearing 플래그는 그대로다** — `-s read-only`(샌드박스) · `-C`(작업디렉토리 핀) ·
  `--json`(파싱 계약) · `< /dev/null`(stdin detach).

### Added
- codex 러너 상한 부재 락(양방향) — 상한 재삽입과 샌드박스 제거 **둘 다** RED.
  한 방향만 재면 "상한만 사라졌다"를 증명하지 못한다.

## [0.24.5] — 2026-08-03

### Changed
- `spec-reviewer` · `coverage-mapper` · `blind-spot-prober` · `steelman-builder`의
  `model: sonnet` 리터럴 핀을 `model: inherit`으로 교체. **실측된 활성 손실이다** —
  지난 일주일 spec-review 6회가 전부 opus-5 세션에서 sonnet-5로 실행됐다(리뷰어가
  writer보다 약한 상태가 매 dispatch 재현). steelman-builder 1회도 같은 패턴.

### Added
- 네 에이전트 frontmatter 테스트에 **양방향 모델 락 신설** — 이전에는 `model:`에 대한
  assert가 아예 없어서 `haiku`로 강등해도 스위트가 GREEN이었다(신설 전 mutation으로 확인).
  positive(`inherit` 실재) + negative(고정 티어 부재) 둘 다 둔다.

## [0.24.4] — 2026-07-29

v0.24.3의 **자기 수정을 독립 리뷰**한 결과(리뷰어 5 + codex). 그 라운드가 만든 신규 결함과
못 닫은 경로를 고친다. 교훈 한 줄: **검증할 수 없는 것을 통과/차단으로 가르려 하지 말고,
검증하지 못했다는 사실을 사람에게 도달시켜라.**

### Changed
- **P21 placeholder 관여 시 판정을 포기한다 (`exit 3`).** v0.24.3은 `masked_contains`라는
  부분 매칭 술어를 도입해 "토큰이 덮는 span만 면제"하려 했으나, 리뷰어 4/4가 독립적으로
  CRITICAL 판정했다: 양끝이 암묵 와일드카드라 **누락 세탁**이 그대로 통과했고(`"브리프에
  <REDACTED:rest>"` → rc 0), 방향이 반전돼 원문에 맥락을 덧붙인 **정당한 payload를 새로
  차단**했으며, 토큰 개수가 무제한이라 in-order subsequence 검사가 되어 의미 반전이
  통과했다. 세 실패는 같은 함수의 양면이라 앵커를 어디에 걸어도 동시에 없앨 수 없다 —
  redaction 뒤를 알 수 없다는 것은 원리적 한계이기 때문이다. 술어를 제거하고, 이 경로의
  결과를 clean도 violation도 아닌 **검사 불가**로 통일했다. 원래 결함의 본질은 "통과했다"가
  아니라 **"강등이 조용했다"** 였고, `exit 3`은 호출자 rc 표에서 degradation record가
  **의무**인 행이라 Step B 사용자에게 반드시 도달한다.
- **Status 충돌 시 마지막 판정을 채택**하고 충돌은 advisory로만 올린다. v0.24.3의
  무조건 `needs_revise`는 `approved`를 **도달 불가**로 만들었다 — agent 파일 출력 형식 절에
  리터럴 Status 두 줄이 있어 critic이 자기 형식을 복창하면 매 라운드 충돌이 잡히고 재리뷰
  상한 2를 전부 태운다.

### Fixed
- **빈 원장이 "전건 검증 완료"로 집계되던 것** — `user_statements: []`면 루프가 0회 돌고
  `EXIT_OK`가 났다. 원장을 비우는 것만으로 L1·L2가 조용히 우회된다. 빈 전칭명제는 clean이
  아니다 → `exit 3`.
- **state 판독 실패가 payload 구조 위반을 선점하던 것** — 파싱 순서 때문에 state에서 키
  하나만 빼면 §6 앵커 중복(차단)이 검사 불가(계속)로 되돌아갔다. payload를 먼저 판다.
- **한국어 출력이 비-UTF-8 locale에서 exit 1을 내던 것** — `LC_ALL=C`에서
  `UnicodeEncodeError` → Python 기본 exit 1이고, 호출자 표는 1을 "위반 → 차단"으로 읽어
  멀쩡한 brief를 막는다. stdout/stderr를 UTF-8로 고정.
- **merge verdict가 보이지 않게 된 것** — v0.24.3이 exit code를 잡으려고 stdout을 파일로
  리다이렉트했는데 그 파일을 아무도 열지 않았다. 2-c는 `needs_revise → approved` 전이가
  일어나는 라운드다. `cat`을 되돌렸다.
- **codex 러너 `exit 3`이 라우팅되지 않던 것** — seed가 산출물을 **쓰지 못하면** 아무것도
  안 남기고 죽어, 막으려던 stale-YAML 경로가 그대로 재현된다. 호출 지점에서 rc 3이면
  잔존물을 제거한다. 러너 헤더의 "항상 exit 0" 계약도 실제와 맞췄다.
- **두 번째 degrade 채널이 재실행마다 truncate되던 것** — 변수를 정의하는 유일한 블록이
  동시에 `: >`로 비웠고, fallback 경로는 `$$`(PID)라 Bash 호출마다 달라 재발견이 불가능했다.
  경로를 세션의 순수 함수로 고정하고 truncate 대신 `touch`.
- **sentinel 블록 다중성 무가드** — 마지막을 조용히 채택하면 §6에 심긴 블록이 권위를 갖는다.
  마지막을 쓰되 판독 불가로 표시해 escalate시킨다.
- **직접 실행 시 신규 테스트 8개가 조용히 누락되던 것** — 클래스가 `if __name__` 가드 뒤에
  정의돼 `python3 test_x.py`가 23개 중 19개만 돌고 `OK`를 찍었다.

### Added
- **이빨 없던 자체 락 4종 교정** (전부 iter-2가 mutation으로 실증): BLOB catch-all이
  전체파일 `grep -c == 2`라 한 섹션에 둘 다 넣어도 통과 → 각 dispatch 지점 윈도우로 스코프 /
  MERGE 락이 bash **주석**만으로 충족 → 실행 라인·분기 본문 앵커로 교체 / C1 mutation이
  `def` rename의 `NameError`(exit 4)를 "세탁 통과"로 오독 → 호출 지점을 흔들고 **정확한
  기대값(exit 0)** 요구 / `**NOT**` 불릿 `-ge 2`가 3개 중 하나를 지워도 통과(맨끝이 Law 2
  역할 경계였다) → `-eq 3` / 빈 `SENTINEL_LIT`이면 `grep -qF ""`가 전부 매치해 가짜 PASS →
  추출 실패 시 FAIL / direction sentinel 추출이 tautology → 소비자 표기에서 뽑아 양방향 rename에 red.

## [0.24.3] — 2026-07-29

`/qg` 브랜치 리뷰(6 독립 리뷰어 + adversarial 선별)가 적발한 CRITICAL 4 + IMPORTANT 15 수정.
지배 원칙은 0.24.2와 같다: **`indeterminate ≠ clean`**. 이번 라운드가 더한 것은
**"강등이 사람에게 닿지 않으면 그것은 강등이 아니라 통과다"**.

### Fixed
- **P21 placeholder 한 토큰이 §6 원문 대조를 통째로 무력화하던 것** (CRITICAL) —
  `check_verbatim_coverage.py`가 `P21_PLACEHOLDER_RE.search()`로 **문자열 전체**를 훑어,
  어느 한쪽에 토큰이 하나만 있어도 그 statement의 L2 containment를 waive하고 EXIT_OK를 냈다.
  SKILL이 허용하는 유일한 §6 편집(P21 치환)이 곧 검사를 끄는 편집이 되어 append-only
  세탁방지가 우회됐다. 이제 **payload 쪽** 토큰은 자기가 덮는 span만 면제하고 나머지 문면을
  그대로 대조한다(`masked_contains`). **state 쪽** 토큰은 원 진실 자체가 미지이므로 기존
  강등을 유지한다 — 좁힌 것은 공격자가 통제하는 면뿐이라 정당한 redaction 3종은 무변경.
- **§6 앵커 중복이 "검사 불가"로 흘러 전 statement 검사를 끄던 것** (CRITICAL) —
  중복 `**S<N>**`이 `ParseError` → exit 3(degrade 후 계속)이었고, 중복 항목뿐 아니라
  **모든** statement의 L1·L2가 함께 skip됐다. 위임 대상이라던 `check_brief.py`는 §6 앵커를
  `set()`으로 모아 중복을 아예 보지 않으므로 그 위임은 실재하지 않았다. 신규
  `StructuralViolation` → exit 1(차단). 판독 실패가 아니라 규칙 위반이다.
- **확정 위반이 뒤 항목의 불확정에 밀려 강등되던 것** (CRITICAL) — `EXIT_INDETERMINATE`
  반환이 statement 루프 **안**에 있어 이미 누적된 `not_contained`를 버리고 rc 3으로 나갔다.
  판정을 루프 밖으로 옮겨 **위반 > 불확정** 순으로 결정한다.
- **비-UTF-8 payload가 빈 `<brief>` 디스패치로 새던 것** (CRITICAL) —
  `build_brief_inline_blob.py`의 `read_text()`가 try 밖이라 `UnicodeDecodeError`가 Python
  기본 **exit 1**로 나갔고, 호출 SKILL의 표는 0/2/3만 라우팅해 어느 분기에도 안 걸렸다.
  `BLOB`이 빈 문자열인 채 프롬프트에 보간돼 critic이 빈 문서를 리뷰하고 "왜곡 없음"을
  보고한다. 읽기 실패를 문서화된 exit 2로 매핑 + 두 호출 지점 표에 **catch-all 행** 추가
  (코드가 아니라 계약을 닫는다 — 다음 미지의 코드가 같은 구멍으로 새지 않도록).
- **rc-0 run의 advisory가 전량 폐기되던 것** — 검사는 *"이 발화는 대조하지 못했다"* 를
  advisory로 말할 수 있는데 rc 표 row `0`의 동작이 "1단계로"뿐이었다. record로 라우팅하는
  행이 3·4뿐이라 P21 강등 문구가 기록되자마자 버려졌다. row 0에 조건부 액션 추가.
- **`vc_rc` 차단 행이 서술뿐이고 실행형이 아니던 것** — 확정 §6 위반(exit 1)이 차단 없이
  can-redispatch → bump → 재리뷰로 흘러갔다. 바로 위 `gate_rc`와 같은 실행형 `if`로 교정.
- **merge 호출만 exit code 계약이 없던 것** — 그 stdout이 2-c 분기 전체가 읽는 verdict인데
  rc도 표도 없었다. `merge_rc` + **빈 출력**(잘린 write는 exit code로 안 잡힌다) 라우팅 추가.
- **두 번째 degrade 채널이 Bash 호출 간 소멸하던 것** — `$DEGRADE_FALLBACK`은 셸 변수인데
  `Bash` 도구는 호출마다 새 셸이다(유지되는 것은 cwd뿐, 실측). 재도출 가능한 값과 달리
  **누산기**라 매 append가 빈 값에서 시작해 Step B에서 비어 있었다 — 원장이 죽었을 때만
  작동하는 백업이 침묵하면 그 침묵이 곧 `degrade 없음`이다. 파일(`$DEGRADE_FALLBACK_FILE`,
  `>>` append)로 교체.
- **`skip_reason`을 버리면서 advisory 템플릿이 그것을 요구하던 것** + **direction 축에
  fail-closed 리더가 없던 것** — `codex_failed: true`가 "없는지"만 보면 부재·0바이트·잘림·
  직전 라운드 잔존이 전부 "정상"으로 읽힌다. `meta.codex_failed: false` **양성 요구**로 전환.
- **codex 러너의 stale YAML이 이번 라운드 판정으로 읽히던 것** — `OUTPUT_PATH`를
  선-truncate하지 않아 조기 exit·SIGKILL이 직전 라운드 산출을 남겼고, 호출자가 러너의 exit
  code를 잡지 않으므로 merge가 그것을 이번 라운드 codex 판정으로 읽었다(`codex_degraded:
  false` → approved, 흔적 0). fail-closed 산출물 **선-기록**(seed) 후 성공이 덮어쓰도록 전환.
- **critic의 first-match `**Status:**` / sentinel 파싱** — 형제 규칙
  (`codex_findings_to_yaml.py`: "last block defeats injected earlier blocks")의 정확한 역이었고,
  `brief-critic.md` 출력 형식 절에 리터럴 Status 두 줄이 디코이로 있다. §6(비신뢰 원문)이
  프롬프트에 inline되므로 주입 표면이기도 하다. 값이 다른 Status 공존 → **fail-closed
  needs_revise + advisory**, sentinel은 마지막 블록 채택.
- **degradation 원장만 값 검증이 없던 것** — 형제 두 키는 빈 값·열거 밖·비-digit에
  `ValueError`를 내는데 원장은 `[]`/`[ ]`만 특수 처리해 `null`·임의 스칼라가 빈 리스트로
  읽혔다(손상 원장과 깨끗한 run의 Step B 텍스트가 바이트 동일). `degrade-append`도 스칼라
  아래 splice + `{"ok": true}`를 냈다. 양쪽 fail-closed.
- **NG3 stale claim 세 번째 인스턴스** — `reviewing-spec/SKILL.md`가 현재시제로 "design doc만
  Law 2 분리 reviewer 대상"을 단언한 채 출하됐다. 회귀 락이 알려진 2개 경로를 하드코딩해
  세 번째를 구조적으로 볼 수 없었다 — **개념 별칭 스윕**으로 전환(식별자 grep은 같은 것을
  다른 이름으로 부른 참조를 놓친다).

### Changed
- design 문서 §6.3 teeth 표의 **거짓 ✅ 두 개를 ⚠️로 정정**. (1) zero-tool probe 분기는
  "런타임 — 저자도 리뷰어도 쓰지 않음"이라 적혀 있었으나 분기 앵커가 오케스트레이터가 쓸 수
  있는 audit 파일 한 줄이고 테스트도 기대값을 같은 줄에서 도출한다(협조적 flip = 스위트
  green). (2) merge 입력이 "리뷰어 findings — 저자가 쓰지 않음"이라 적혀 있었으나 critic이
  `tools: []`이라 전사는 저자가 한다. 둘 다 봉쇄 조건을 표에 함께 명시.
- Step B 전달 항목 4 → **5**: critic 원문 전문(`$CRITIC_OUT`)을 병합 결과와 나란히 올려
  사람이 전사본과 파싱된 판정을 대조할 수 있게 했다(검증 불가능한 프로즈 의무 → 확인 가능).

### Added
- 회귀 락 전부 **mutation으로 이빨 증명**: C1 마스킹 제거 → 세탁 통과, blob 읽기 가드 제거
  → exit 1 재발, codex seed 제거 → stale 생존, critic sentinel·`**Status:**`·`**NOT**` 불릿·
  direction sentinel 각각 rename/치환 → RED. 생산자 쪽 계약은 리터럴을 테스트에 박지 않고
  **소비자 코드에서 추출**해 대조한다(어느 쪽에서 rename해도 red).
- `test_brief_agents.sh`의 `grep -q "NOT"`이 **"NOTE"로 충족되던** 것을 마커 형태 + 열거
  크기 핀으로 교체하고 대상을 세 agent 전부로 확대(`brief-direction-reviewer` 본문은
  그동안 완전 무테스트였다).

## [0.24.2] — 2026-07-29

지배 원칙 하나: **`indeterminate ≠ clean`** — 돌지 못한 검사는 통과한 검사로 기록되지 않는다.

### Fixed
- **state 기록 실패가 "degrade 0건"으로 렌더되던 것** — `brief_review_state.py`의 쓰기
  서브커맨드는 state 부재·판독 불가·쓰기 불가·frontmatter 손상에 exit 1 + `{"ok": false}`를
  내는데 `reviewing-brief`가 그 종료 코드를 한 번도 보지 않았다. `init`이 실패하면 이후
  `degrade-append`가 전부 실패하고 마지막 `get`도 실패해, *"모든 degradation을 Step B에
  올린다"* 는 요구가 조용히 *"degrade 없음"* 으로 바뀐다. `init_rc` 캡처 + `$DEGRADE_FALLBACK`
  턴-내 사본 채널(§5.6이 요구하는 즉시 표면화의 나머지 절반) + `get` 실패를 *비어 있음* 과
  구분해 명시.
- **`check_verbatim_coverage.py`가 malformed 원장을 exit 0으로 통과시키던 것** — (a) `- id:`로
  시작하지 않는 리스트 항목은 통째로 무시됐고, (b) `text` 키 부재는 advisory 한 줄 뒤 success,
  (c) `text`가 비었거나 정규화 후 비면 역시 advisory 후 계속이었다. 셋 다 그 발화가 payload §6과
  **한 번도 대조되지 않았는데** 호출자는 0을 "위반 없음"으로 매핑한다. 셋을 exit 3(검사 불가)로.
  세 가드는 서로 겹치지 않게 갈랐다 — 겹치면 어느 쪽을 지워도 회귀 테스트가 green이라
  mutation으로 이빨을 증명할 수 없다.
- **방향성 축에 unavailable 경로가 없던 것** — 냉독은 빈 출력을 명시적으로 degrade하는데
  방향성은 `brief-direction-findings` 센티널 검증도 record도 없었다. 리뷰어가 죽고 codex #1도
  없는(kill switch·미설치·스키마 파손) 라운드에서 축 전체가 미검증인 채 원장이 침묵했다.
  냉독과 대칭인 결정론 검증 + `component: direction_reviewer` / `verification_status: unavailable`.
- **`can-redispatch`의 exit 1이 두 사실을 싣던 것** — escalate(상한 도달)와 `_fail`(state
  부재·손상)이 같은 코드다. 스킬의 `else`가 둘 다 escalate로 취급해, state가 죽었을 뿐인
  라운드에 *"재리뷰 상한 2 초과, 미해결 findings 잔존"* 이라는 사실이 아닌 record를 남겼다.
  실패 페이로드에 없는 `escalate` 키로 가른다.
- **웹 예산이 상한을 1회 넘겨 dispatch할 수 있던 것** — `check`는 `> 8`만 거부하므로
  `session == 8`에서 통과하고, dispatch 후 `increment`가 9를 만든다. `web_budget.py check
  --prospective`(`count + 1`로 평가)를 추가해 사전 게이트가 *"지금 하려는 이 호출이 예산에
  들어가는가"* 를 묻게 했다. 기존 `check` 계약과 `increment`의 bump-then-check는 무변경 —
  increment-before-dispatch로 이미 올바른 `conducting-interview` 호출자에 영향이 없다.
- **`inc_rc != 0`을 "카운터가 오르지 않았다"로 서술하던 것** — `increment`는 bump-then-check라
  예산 경계에서는 카운터를 **올린 뒤** 1을 낸다(기록은 성공). 그 상태에서 *"웹 예산 increment
  실패"* record가 Step B 질문에 렌더되면 거짓 degrade다. 1-a가 이미 쓰는 방식대로 JSON `reason`
  으로 갈랐다.
- **`build_brief_inline_blob.py`의 `\s`-개행 버그** — `^(key\s*:\s*)(.*)$`에서 `\s*`가 개행을
  넘어, 값이 빈 redact 키가 **다음 줄을 삼켜** 그 줄을 `<redacted>`로 갈아치웠다(실측: 빈
  `audit_file:` 다음의 `created_at:` 줄이 삭제). `check_brief.py`의 frontmatter 검증이
  `name`·`created_at`을 보지 않으므로 빈 `name:`이 구조 게이트를 통과한 뒤 한 줄이 지워진
  사본이 격리 critic에게 가는, 도달 가능한 경로였다. `brief_review_state.py`가 같은 클래스를
  두 번 닫았고 이 파일이 남은 하나였다 — 형제들과 같이 `[ \t]*`로.
- **핸드오프 invocation이 인자를 주석 안에서만 넘기던 것** — `Skill spec-distill:reviewing-brief
  # 인자: $PAYLOAD, …`. callee는 이 세 값을 스스로 정의하지 않는다고 명시하므로 호출은 인자
  없이 나간다. 인자를 호출 라인 위로 옮겼다.

### Changed
- **codex 추론 강도 핀 제거** — `run_brief_codex_reviewer.sh`가 `model_reasoning_effort="medium"`
  을 박아 사용자 codex 설정을 조용히 하향시켰다. `high`/`xhigh`로 설정한 사용자가 medium으로
  깎이고, 그 하향은 이 co-reviewer의 유일한 존재 이유(별-모델 적발력)를 정확히 겨냥한다.
  하니스는 능력을 억제하지 않는다 — 이제 사용자 설정이 지배한다.
- **진입 승인 게이트가 상한을 말한다** — 2-c 재실행이 들어오면서 실제 천장은 에이전트 5 +
  codex 4인데, 사용자가 실제로 승인하는 `AskUserQuestion` 질문 텍스트는 하한(3 + 2)만 말했다.
  `cost_class: high` 게이트가 싣는 숫자는 상한이어야 한다. 하한/상한 표를 명시하고 호출자
  (`conducting-interview`)의 같은 주장도 동기화.
- **P21 placeholder 집합을 producer ↔ checker 합치** — `conducting-interview`가 예시로 드는
  `<REDACTED:라벨>`이 checker의 라벨 문자류(`[A-Za-z0-9._-]`)에 안 잡혀 정당한 치환이 hard
  violation으로 갔다. **checker 쪽을** 넓혀 맞췄다(`[\w.-]`) — 한국어 라벨은 이 리포의
  Korean-primary 규약상 정상이고 producer를 ASCII로 좁히면 규약과 싸운다. 넓힌 것은 글자
  종류뿐이고 공백·`<`·`>` 불가와 길이 상한 64는 그대로라, 산문을 라벨로 위장해 L2 비교를
  통째로 강등시키는 경로는 열리지 않는다.
- **README가 코드를 따라잡았다** — `## Flow (v0.24.0)`으로 버전만 올라가고 다이어그램은
  brief를 Step B로 직행시키고 있었다. 리뷰 3단계를 다이어그램에 그리고, 붙을 리스트가 없던
  `5.5.` 고아 번호를 형제와 같은 버전 노트 문단으로, `DEVBREW_DISABLE_SPEC_DISTILL_CODEX`
  항목에 brief 파이프라인 호출 지점 3곳(1-c · 2-b · 2-c)과 호출자-게이트 규약을 명시.
- **회귀 락 하드닝(teeth)** — 이번 wave가 추가·수정한 assert 32개 전부 mutation으로 이빨을
  확인했다(각 assert를 red로 만드는 단일 편집 수행 → 확인 → 바이트 동일 복원). 주요한 것:
  README 락이 컴포넌트 이름을 섹션 전체에서 찾아 **다이어그램을 통째로 지워도 산문으로
  충족**되던 것을 펜스 안 다이어그램 순서 락으로 교체. 핸드오프 인자 락이 `#` 뒤 텍스트를
  세어 **주석을 보호하며 green**이던 것을, 같은 사이클이 만든 따옴표-상태 스캐너에 마커
  인자만 추가해 재사용하는 방식으로 교체(두 번째 스트리퍼 금지). §6.3 열거표는 스스로
  *"기계가 열거 완전성을 본다"* 고 적어놓았지만 그 기계가 없어서(리터럴 4개 존재 확인뿐)
  실제 열거 대조를 구현했고, 표에 행이 없는 shipping 체크 2건을 **선언된 gap 목록**으로
  리포에 박았다(아래 Known gaps).
- **테스트 위생** — 픽스처 `.replace()`가 조용히 no-op이 되면 시나리오가 뒤바뀌어도 green이던
  것을 `sub1()` 치환-확인 헬퍼로 봉쇄. `test -f … || note FAIL` 가드가 정상 경로에서 note를
  안 불러 출력 Total이 조건부이던 것, 두 섹션 캡처를 구분자 없이 이어붙이던 것, 실패 메시지에
  이스케이프된 정규식이 그대로 찍히던 것을 수정. `scoped_window()`/`fence()`가 패턴을 `awk -v`로
  넘겨 `\[`·`\$`가 뭉개지던 것(지금 패턴이 `\.`뿐이라 **우연히** 무해했다)을 `ENVIRON`으로 통일.
  `codex_findings_to_yaml.py`의 `meta` 추론 타입을 `dict[str, object]`로 명시.

### Known gaps
- 설계 문서 §6.3 결정론 체크 열거표에 **행이 없는 shipping 체크 2건**:
  `build_brief_inline_blob.py`의 exit-3 잔존 검사, `brief_review_state.py`의 닫힌 열거 검증 ·
  rounds clamp · `can-redispatch` 게이트. 특히 후자는 통과 조건(`brief_critic_rounds`)을
  **orchestrator 자신이 쓰므로** 표가 존재하는 이유인 범주에 해당하고, 이빨 등급 판정은 기계가
  못 한다. 설계 문서 수정은 사람 몫이라 이 사이클에서는 문서를 건드리지 않고
  `test_brief_review_meta.sh`의 `DESIGN_GAP` 선언으로 gap을 greppable·강제 가능하게만 만들었다
  — 새 체크가 표 없이 들어오거나, 표에서 행이 사라지거나, 사람이 표를 채운 뒤 waiver를
  안 비우면 전부 red다.
- `merge_review.py`(design-doc 리뷰 경로, 이 브랜치 밖)가 `codex_failed: true`인 라운드에서
  파싱된 codex findings를 **전량 폐기**한다. mixed 라운드(정상 finding 1 + malformed 원소 1)에서
  `combined_verdict: approved` + degrade advisory만 남고 `severity: high` finding이 사라지는 것을
  실측했다. `merge_brief_review.py`(brief 경로)는 이미 findings를 보존한 채 degrade 마커를 함께
  낸다 — 남은 격차는 공유 경로 한 곳이다. blast radius가 이 브랜치 밖이라 미변경.

## [0.24.1] — 2026-07-29

### Fixed
- **`DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`이 충실도 축에서 무시되던 것** — `reviewing-brief`의
  가용성 게이트가 1-c 방향성 호출만 감쌌고, 2-b 충실도 호출과 2-c 재실행 호출은 무조건
  실행됐다. 러너는 이 변수를 보지 않으므로(호출자-게이트 규약) `cost_class: high` skill에서
  사용자의 명시적 opt-out이 무시된 채 외부 모델에 지출이 나갔고, 1-c가 남기는
  `affected_axis: all` record가 거짓이 됐다. 세 지점을 모두 같은 `$codex_avail`로 게이트한다.
  skip 라운드에도 병합은 그대로 돌아 `codex_degraded: true`로 loud하게 보고하므로 kill switch가
  강제 수정 루프로 바뀌지 않는다. 2-b의 `codex_degraded` record에는 `codex_avail == true`
  전제를 달아 skip의 결과에 중복 record를 남기지 않는다.
- **구조 게이트 실패 분기가 차단하지 않던 것** — 2-c의 `gate_rc != 0` 분기가 하던 일은
  `exit_reason=` 변수 대입 하나였고 그 변수를 읽는 곳은 리포 전체에 0곳이었다. 분기는 그대로
  흘러내려 완전성 검사·`can-redispatch`·`bump-critic-round`·재dispatch를 전부 실행했다.
  서술은 차단이라고 단언했으므로 문서가 shipping보다 강했다. `exit 1`로 실제 정지를 넣었다.

### Changed
- **회귀 락 하드닝(teeth)** — 이빨 없이 green이던 assert들을 교체했다. codex 호출 락은 축별로
  세고(방향성 ≥ 1 · 충실도 ≥ 2 — 합산 하한 2는 재실행이 3번째 호출이 된 순간 방향성 호출을
  통째로 지워도 green이었다), 구조 게이트 락은 분기 **본문**의 정지 동작을 요구하며, codex
  재실행 락은 존재에 더해 **순서**(게이트 → `can-redispatch` → 재실행 → 재병합)와 `can == 0`
  분기 내 포함까지 본다. 실행 라인이 주어인 assert는 전부 줄-시작 앵커로 바꿨다 — 같은 문구를
  실은 산문 한 줄로 satisfiable했다. `run_brief_codex_reviewer.sh` 호출 3개가 전부 게이트
  본문 안에 있는지 세는 락을 새로 추가했다.
- `test_brief_review_entry.sh`의 `strip_trailing_linecomment()`가 문자열 경계를 줄의 마지막
  따옴표로 잡아, 트레일링 코멘트가 따옴표 쌍을 품으면 통째로 no-op이었다. 왼쪽에서 오른쪽으로
  훑는 따옴표-상태 스캔으로 교체(`\"` 이스케이프 존중, `"`·`'`·`` ` `` 세 종류).
- 락의 들여쓰기 강제(`^[[:space:]]+`)를 완화(`*`) — 호출이 살아 있는데 dedent만으로 RED가
  나던 false-red였다.

## [0.24.0] — 2026-07-27

### Added
- **brief 리뷰 파이프라인 (Law 2 분리 리뷰)** — `skills/reviewing-brief/`가 3단계를 돌린다:
  방향성(Claude + codex, 보고만) → 충실도(격리 critic + codex, fail-closed 합집합) → 냉독.
  Spec A(v0.23.0)가 *"신규 에이전트 0개 — 리뷰 파이프라인은 후속"* 으로 미룬 것이다.
- `agents/brief-critic.md` — 충실도 리뷰어. payload **전문 inline**(경로 미제공),
  `audit_file`·`name`·`created_at` redact. `category` 6종(`distortion`/`omission`/`insertion`/
  `provenance_mislabel`/`authority_syntax`/`evidence_unsupported`)을 각각 점검한다.
- `agents/brief-direction-reviewer.md` — 방향성 리뷰어. repo + 웹. **판정이 아니라 질문**을
  낸다(각 finding에 사용자가 결정할 질문 1개 필수 — C4가 사문이 되지 않게).
- `agents/brief-readback.md` — 냉독. 출력 스키마·판정 기준을 **주지 않는다**(형식이 오염원).
- `scripts/check_verbatim_coverage.py` — payload §6 ↔ state `user_statements` 대조(L1/L2).
  정규화 N1–N5(순서 고정, **NFC**), exit `1` 위반 / `3` 검사불가 / `4` 내부오류로 분리.
- `scripts/brief_review_state.py` — state 키 3개 소유. 재리뷰 상한 2 경계값(`== 2` escalate),
  도달 불가 값 clamp, degradation record 4필드 닫힌 enum.
- `scripts/merge_brief_review.py` — 충실도 fail-closed 합집합. codex는 **binding**이며 단독으로
  verdict를 만든다. `codex_isolated: false`는 저자용 라벨이고 verdict 입력이 아니다.
- `scripts/build_brief_codex_prompt.py` + `brief-codex-{direction,fidelity}-checklist.md` +
  `run_brief_codex_reviewer.sh` — codex 축별 2회. **코드 1곳 + 데이터 2곳.**
- `scripts/build_brief_inline_blob.py` — critic·readback 공용 redacted blob.
- kill switch `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` — 파이프라인 전체 skip + record.

### Changed
- `conducting-interview` Step A.5로 리뷰 파이프라인 진입(한 블록). Step B 게이트가 산출물 4종과
  **모든 degrade record를 question 텍스트에** 싣는다 — 사용자가 옵션을 고르기 *전에* 본다.
- **NG3 서술 교정**(`check_brief.py` docstring · `agents/spec-reviewer.md`): *"brief는 분리 리뷰를
  받지 않는다"* 가 이 버전으로 거짓이 됐다. 게이트는 여전히 Law 1이고 그 위에 Law 2가 얹혔다.
- `templates/interview-audit-template.md` §4·§5에 리뷰 라운드 텔레메트리 — **기록이며 게이트
  통과 조건이 아니다**(검사 대상이 통과 조건을 직접 쓰는 검사는 이빨이 없다).
- P21 치환 토큰을 `<REDACTED>` 계열로 못 박았다 — producer와 checker가 같은 집합을 봐야 L2
  advisory 강등이 발화한다.

### Security
- 신규 에이전트 3개 전부 fail-closed `tools:` allowlist, 쓰기·실행·위임 도구 **0개**(Law 2).
  `model:`은 전부 `inherit`(리터럴 핀 금지 — 세션이 더 강한 모델일 때 downgrade 방지).
- 격리는 **zero-tool probe 이진 분기**로 성립한다. probe 통과 시 `tools: []`로 도달 경로가
  물리적으로 없고 충실도가 hard gate. 실패 시 `tools: Read` + 충실도 **advisory 강등** +
  record 2건 + D2 미충족 사용자 보고 — 보장되지 않는 격리 위에 hard gate를 얹지 않는다.
  실측 기록: `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`.
- **훅 0개 추가** — `hooks/` 파일 집합과 `hooks.json`이 무변경이다.

## [0.23.0] — 2026-07-26

### Added
- **brief 2파일 계약** — payload(`<topic>-interview.md`, 8섹션 역피라미드)와 audit
  (`<topic>-interview.audit.md`, 5섹션 텔레메트리)로 분할. payload frontmatter의 `audit_file`
  (basename만 — traversal 거부)이 audit을 가리키고, 게이트가 두 파일을 함께 검사한다.
  audit 부재·미해석은 fail-closed.
- `templates/interview-audit-template.md` — Coverage Ledger / Budget / Steelman 원문 /
  게이트 실행 기록 / 프로세스 로그.
- **frontmatter `user_sourced_items[]` 계약** — `id`/`source`(`verbatim`|`chosen`)/`status`
  (`confirmed`|`provisional`|`open`)/`statement`(160자 hard cap)/`evidence`(`S<N>`, 필수).
  `source: inferred`는 이 리스트에 들어갈 수 없다 — 모델 추론은 본문 ✎ 프로즈로만 산다.
- **audit 페어링 검사(`session_id` 바인딩)** — audit이 *이 payload의* sidecar인지 확인한다.
  `audit_file`만으로는 basename이 같은 디렉토리에 존재하기만 하면 통과해서, payload가 **다른
  인터뷰의 audit**을 가리켜 그 §1 Coverage Ledger(Law 1 종료 판정의 근거)를 상속할 수 있었다 —
  끝나지 않은 인터뷰가 `audit_file` 한 줄만 바꿔 exit 1에서 exit 0이 됐다. 결합은 파일명이 아닌
  `session_id` 동등성 + audit `type`으로 건다.
  1차 방어는 **이름 유도**다 — `audit_file`은 `<payload stem>.audit.md`여야 한다. 신뢰하지 않는
  값을 검증하는 대신 아예 받지 않는 쪽이다: payload가 자기 audit을 고를 수 있는 한, 세션 id
  동등성만으로는 부족했다(`SKILL`이 세션 id 재사용을 규정해 한 세션의 두 인터뷰가 같은 id를
  가지므로 *동일 세션* 차용이 그대로 통과했다 — 실측 exit 0). `session_id`/`type` 검사는 파일
  이동·개명에 대한 2차 방어로 남는다. 3차 방어는 audit이 스스로 선언하는 **`payload:` 역참조**다 —
  이름 유도는 *어느 파일을 읽을지*만 고정하므로, 남의 audit **내용**을 유도 경로에 복사해 넣으면
  그대로 통과했다(실측 exit 0). 이 필드는 두 템플릿과 모든 fixture가 이미 담고 있으면서 아무도
  읽지 않던 것이다 — 선언만 있고 읽는 코드가 없으면 계약이 아니다.
- **web 킬 스위치 완화를 advisory로 알린다** — `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`은 §4 인용
  요구와 §5 verdict URL 요구를 동시에 완화해 같은 brief를 red에서 green으로 바꾸는데 지금까지
  아무 흔적도 남기지 않았다(이전 세션의 export가 남아 있으면 이후 모든 brief가 이유 없이 통과).
  CLAUDE.md의 loud-degradation 요구. `gate`는 advisories JSON으로, `_web_disabled()`가 결과를
  바꾸는 나머지 서브커맨드(`landscape-citations`·`skepticism`)는 stderr로 알린다 — stdout은
  JSON 계약이라 섞으면 소비자 파싱이 깨진다.
  부재도, **중복 키도** 불일치와 동일하게 red — 못 읽은 값을 일치로 간주하거나 모호한 입력에서
  값을 하나 골라주면 이 검사 자체가 fail-open이 된다(첫 매치만 쓰면 남의 audit 맨 앞에 맞는
  `session_id` 한 줄을 얹어 바인딩을 우회할 수 있다). frontmatter 키-값 구분자는 `\s*`가 아니라
  `[ \t]*`다 — `\s`는 개행을 포함해 값이 빈 키가 **다음 줄 토큰을 값으로 포획**하고, payload와
  audit이 둘 다 `session_id`를 비우면 양쪽이 똑같이 아래 `source:`로 읽혀 페어링이 상수로
  붕괴했다. `audit_file`·`type`도 같은 모양이라 셋을 함께 고쳤다.
- **세 bijection** — A: payload §5 `ST<N>` ↔ audit §3 `#### ST<N>`(양방향, 공집합 허용) /
  B: body §2 ↔ frontmatter(id·기호·status·`⟨S<N>⟩`·**statement 내용**까지) /
  C: 모든 `evidence: S<N>`가 payload §6에서 해석됨.
- **종료 확정 확인** — proceed 게이트에 흡수(상호작용 1회 유지). 재제시 상한 2회, 초과 시
  전 항목 `provisional` 강등 + 고정 advisory.
- 분량 지표 `payload_body_lines_excl_verbatim`(§6 제외) — 150 초과 시 advisory, **fail 안 함**.
- `check_brief.py items` / `metrics` 서브커맨드.
- `tests/test_stale_terms.sh` V8 — 권위 문법 6개 리터럴 회귀 락 + mutation 이빨 증명.
- **AC12 sentinel 앵커링** — `confirmed` 0건 brief는 `# confirmed 0건 — 사용자가 전부 잠정으로
  판단`이 **한 줄 전체**로 frontmatter에 있어야 통과한다. 다른 문장 안에 인용된 같은 문자열
  (템플릿 안내 주석, `statement` 값 등)은 sentinel이 아니다 — substring 검사였다면 템플릿대로
  만든 brief가 확인-게이트 우회 검출을 통째로 우회했다.

### Changed
- **라운드별 잠금 producer 제거** — 매 round 끝 `locked?` decision table이 사라지고,
  판정 없는 `user_statements`(`{id: S<N>, source, round, text}`) 기록으로 대체. `status`도
  해답공간 `section:` 앵커도 붙이지 않는다. 과거 brief의 LD 9/6/5는 모델의 과잉 잠금이 아니라
  skill이 지시한 대로 동작한 결과였다.
- brief 템플릿을 8섹션 역피라미드로 재작성 — 행동 항목(제약·Open Questions)이 앞, 근거·원문이
  뒤. 사용자 원문은 §6에 전문 보존(허용 변환은 P21 placeholder 치환·공백 정리·인용 래핑뿐).
- Coverage Ledger 검증이 payload §6 → audit §1로 이동.
- `user_sourced_items[]` 항목 필드도 값 뒤 YAML 인라인 주석(`status: provisional  # …`)을
  떼어낸다 — `audit_file`과 같은 규칙(같은 frontmatter를 두 규칙이 반대로 읽던 불일치 해소).
  따옴표 스칼라 안의 `#`는 값의 일부로 보존한다. 블록 안의 주석 줄도 항목 파싱을 끊지 않는다.
- R4 통과 의례가 payload §5 `기각` 항목 문법으로 이관 — 0건이면 명시 N/A sentinel 없이 fail.
- **섹션 항목 추출이 `-`와 `*` 불릿을 모두 받는다** — body §2를 읽는 `BODY_ITEM_RE`는 `[-*]`를
  받는데 §4·§5·audit §1을 읽는 `_entry_lines`는 `- `만 받아, 같은 아티팩트를 두 규칙이 다른
  관례로 읽었다. §4에 인용된 `-` 항목과 인용 없는 `*` 항목을 함께 두면 `landscape_present`는
  만족되고 `landscape_uncited`는 `*`를 못 봐서 R2의 "출처 URL 필수"가 불릿 한 글자로 우회됐다.
- `/compact` 핸드오프 문구가 새 섹션명을 가리키고 **C4 재결정 프로토콜**을 함께 싣는다.
  직행 경로(옵션 ②)의 호출 프롬프트에도 같은 문장이 실린다 — 규약은 brief가 아니라
  호출 프롬프트에 산다(C5).
- `agents/{blind-spot-prober,steelman-builder,coverage-mapper}.md`의 Input 절이
  `locked_directions` 대신 "사용자 제약 요지"를 받는다.

### Removed
- frontmatter `locked_directions[]` 및 state `pending_locked_decisions[]`.
- brief §2 *"Locked Directions"* 섹션과 *"재논쟁 금지"* 헤더 문구.
- `check_brief.py`의 `steelman_unlogged()` — frontmatter `steelman:` 라벨이 사라져 죽은 코드가
  됐고, 그 보장은 bijection A가 이어받는다.

## [0.22.0] — 2026-07-21

### Added
- **커버리지-구동 인터뷰 재구성** — 종료 driver를 고정 `interview_round` 카운터에서 미지-차원
  커버리지 원장(고정 floor 5 + 주제-도출 차원, 각 status ∈ {open, in-progress, closed})으로 교체.
  집요함·깊이·차원이 주제에 적응한다(길이 아님).
- `scripts/probe_budget.py` — Unbounded-autonomy 백스톱(check/increment/raise-cap; base_cap 12 +
  probe_cap_override; env `DEVBREW_SPEC_DISTILL_PROBE_CAP`). `web_budget.py` sibling, mutation-testable.
- `agents/blind-spot-prober.md` — blind_spot floor 차원을 구현하는 적대적 premortem 에이전트
  (read-only, fan-out 1, hidden_assumptions/failure_modes 출력).
- brief 템플릿 §5 Blind Spots & Premortem + §6 Coverage Ledger 신규 섹션. `check_brief.py`가 원장 form
  (floor all-closed + evidence non-empty + derived)을 게이트.
- teach-beat — 모든 probe teach-lite(≤1문장) + 열거 신호 시 teach-heavy(≥1 URL/prior-art 인용). 발화
  시점은 model-judged(C12, 결정론 미기계화).

### Changed
- `agents/breadth-keeper.md` → `agents/coverage-mapper.md` 재명명·재목적화 — tunneling 검출에서
  주제-도출 차원 advisory 제안자로 승격(원장 admit 판정은 orchestrator, Law 2). `coverage-mapper`
  dispatch 트리거를 `interview_round >= 2`에서 C11 커버리지 조건(연속 3 probe 무진전 OR floor 첫
  open→in-progress) + redispatch 바운드로 교체.
- `skills/conducting-interview/SKILL.md` — 상태 스키마(interview_round 제거, coverage/probe_count/
  probe_cap_override/orchestration 추가), 종료 게이트(floor all-closed), probe 백스톱 호출, rhythm-guard
  probe 재프레임, in-flight 마이그레이션(구세션 fresh seed).
- `agents/steelman-builder.md` — description 용어 'breadth-keeper' → 'coverage-mapper'(terminology-only).

### Security
- 신규/변경 에이전트(coverage-mapper·blind-spot-prober)는 `tools:` allowlist fail-closed(Write/Edit 물리
  부재) — Law 2 read-only 불변. probe 백스톱은 기계적 집행(프로즈 self-tracking 아님).

## [0.21.0] — 2026-07-19

### Changed
- **agent 3종(`spec-reviewer`·`breadth-keeper`·`steelman-builder`)을 `tools:` allowlist 로 전환** (fail-closed). 이전에는 denylist 만으로 격리돼 `Agent`·`Bash`·모든 MCP 도구를 보유했다 — denylist 는 공간(열거 누락)뿐 아니라 **시간에 대해서도 fail-open** 이다(내일 추가될 도구는 오늘 열거할 수 없다).
- 목록은 **트랜스크립트 census 실측**으로 도출했다. `spec-reviewer` 는 persona 가 한 번도 지시하지 않는 `Bash` 를 45회 부르고 **선언에 없는 `WebFetch`** 로 공식 문서를 가져와 검증한다 — persona 독해로 만든 목록은 안 쓰는 도구를 주고 쓰는 도구를 뺏었을 것이다.
- 죽은 `allowedTools` 키 제거 (`spec-reviewer`·`steelman-builder`) — 공식 subagent 규격의 필드가 아니라 무시된다.

### Added
- `spec-reviewer`·`breadth-keeper` 도구 표면 회귀 락 신설 — 가장 많이 dispatch 되는 리뷰어인데 락이 없었다.

## [0.20.0] — 2026-07-15

### Added
- **codex 병렬 독립 co-reviewer (Phase 3 design-doc 리뷰)** — model diversity를 quality-gates code-review에서 spec-distill의 design-doc 리뷰로 이식. `reviewing-spec`가 Claude `spec-reviewer`와 나란히 codex를 독립 실행하고, `scripts/merge_review.py`(결정론 merge/ledger 엔진)가 **보수적 병합**(precedence `needs_interview > needs_revise > approved`)으로 두 verdict를 합친다 — codex가 Claude의 approved를 needs_revise로 뒤집을 수 있다(fail-open 포착). codex는 `codex exec -s read-only` OS 샌드박스(Law 2 구조적).
- `scripts/detect_codex.sh` (vendored) — codex 가용성 감지. kill switch `DEVBREW_DISABLE_SPEC_DISTILL_CODEX`.
- `scripts/build_spec_codex_prompt.py` — design-doc 전용 codex 프롬프트(6 판단형 category, path-only 입력, severity vocab `block|high|medium`).
- `scripts/run_spec_codex_reviewer.sh` — 독립 codex subprocess(**discover-spec.sh AC 주입 없음** — 순환 footgun 회피, C3; mktemp C7 가드).
- `scripts/codex_findings_to_yaml.py` (vendored) — codex JSONL→YAML, emit 키셋에 `category`/`target_section` 추가.
- `scripts/compute_issue_id.py` — 중앙화 issue_id helper(`sha256_short(category + ":" + target_section)`). 두 리뷰어 이슈 모두 여기로 — cross-reviewer collision integrity.
- `scripts/merge_review.py` — 결정론 merge/ledger 엔진: 양쪽 출력 스크립트 파싱(LLM 전사 없음), verdict 유도, 보수적 병합, 4-branch degrade 계층(sentinel/`**Status:**`/codex-alone/fail-safe), 통합-원장 stagnation 스캔.
- tests: `test_detect_codex.sh`, `test_build_spec_codex_prompt.sh`, `test_codex_findings_to_yaml.py`, `test_compute_issue_id.py`, `test_run_spec_codex_reviewer.sh`, `test_merge_review.py`, `test_reviewing_spec_codex_merge.sh` + codex mocks.

### Changed
- `skills/reviewing-spec/SKILL.md` — ⟦detect⟧/⟦review-codex⟧/⟦merge⟧ 스텝 추가, "Stagnation detection" 절을 merge_review의 **통합-원장 스캔 flag**로 재작성(codex-only 반복 이슈 escalate; Claude self-report는 보조 신호). combined_verdict를 기존 routing table에 투입(표 불변). C8 verbatim `--claude-output` 저장.
- `agents/spec-reviewer.md` — issue를 **sentinel-fenced JSON block**(` ```spec-review-issues `, category/target_section/severity/message)으로 emit + top-level `**Status:**` verdict 라인 유지. issue_id self-report 제거(compute_issue_id가 계산). codex 존재 blind 유지.

### Security
- 두 리뷰어 모두 write-denied(codex `-s read-only` 샌드박스 + Claude disallowedTools), 리뷰 pass 상호 blind. codex 부재/실패는 fail-open(조용한 통과)도 fail-closed(spurious block)도 아닌 loud degrade.

### Fixed
- **fail-closed 하드닝 (`/qg` self-dogfood iter-1 적발; codex+silent-failure 모델다양성이 whole-branch·code-reviewer가 놓친 verdict-path fail-open 수렴 적발)** — `merge_review.py` 3건: (1) `parse_codex_yaml`이 opt-in-to-failed였음 — 존재하지만 비어있는/절단된 codex YAML(외부 SIGKILL/OOM/disk-full로 `OUTPUT_PATH`가 0-byte)이 `codex_failed` 마커 부재 시 **성공한 빈 리뷰로 오인** → advisory 없이 `approved`로 silently 통과(다른 모든 degrade 경로가 올리는 human-gate advisory backstop 무력화). opt-in-to-success로 반전 — **정확히 하나의** exact `true`/`false` 마커만 신뢰(부재·empty·garbage value·**중복 마커** 모두 fail-closed degrade + partial findings 폐기; `failed`는 sticky-True로 마커 순서 무관). isfile() 통과 후 open 실패(permission/TOCTOU/vanished)도 uncaught OSError crash가 아닌 loud degrade(`codex_yaml_unreadable`, `load_history` 가드와 대칭). (2) `derive_codex_verdict`가 off-vocab/missing severity(LLM drift `"critical"`/`""`)를 **approved 방향으로** 흘려보냄 → `CODEX_SEVERITY_KNOWN` 도입, 인식 불가 severity는 escalate(`medium`만 non-escalating 유지, §8). (3) `_write_history` `except OSError: pass`가 silent였음 → bool 반환 + 실패 시 loud advisory(원장 기록 실패 = cross-round stagnation degraded 명시) + orphan `.tmp` 정리. 3건 모두 mutation-test로 이빨 검증.
- `emit()` codex_findings 표시 블록 + degrade advisory가 `ensure_ascii=True`로 한국어를 `\uXXXX` escape → `ensure_ascii=False`로(Korean-primary 충실성, sibling `check_brief.py` 선례).
- `build_ledger`의 미사용 `codex_avail` 파라미터 제거(원장이 codex-availability-aware라는 오해 신호 + Pyright dead-param).

## [0.19.0] — 2026-07-05

### Fixed
- **review-lock session-id split → Stop 재강제 루프**: `reviewing-spec` 스킬이 리뷰 락·suppress·approve 를 **interview UUID** 로 keyed 했으나 훅(Stop/UserPromptSubmit/PostToolUse)은 **harness sid**(`resolve_session_id` env-first)로 상태를 읽어, 두 파일이 갈려 `is_review_active` 가 락을 못 찾고 `False`(fail-safe = 강제)를 반환 → v0.18.0 이 막으려던 subagent-경계 Stop 재강제가 **인터뷰-선행 플로우에서 여전히 발생**했다(harness sid 는 `/compact`/resume 에서 drift, interview UUID 는 stable). `reviewing-spec/SKILL.md` Step 1 이 `state_path.py session-id` + `state-root` 로 상태 파일을 명시 해석하고 세 hook-facing 호출 지점(락 `set`·`pause`, `approve_handoff.sh`)에 `$harness_sid` 를 넘겨 락·suppress·approve 가 훅이 읽는 파일에 기록되게 한다(read==write 디렉토리 불변식). approve 후 같은 design 재편집 시 재-arm 도 함께 해소(suppress 대칭 복원). `cancel_review.py`·`approve_handoff.sh`·`review_lock.py` 는 무변경(각각 이미 harness sid 이거나 sid passthrough). continuity(`rereview_count`/`issue_history`)는 harness-sid 로 collapse 하지 않아 인터뷰-선행 re-review cap/stagnation 을 보존(N1).

### Added
- `hooks/state_path.py` — `session-id` CLI 서브커맨드: env-only `resolve_session_id(None)` 결과를 stdout 에 print(exit 0), 미해석 시 stdout 무출력 + exit 1. 스킬과 훅이 *정의상 동일한* sid 를 얻는 단일 진입점(DRY 리졸버).
- `tests/test_review_lock_session_id.sh`(T1 behavioral 훅 repro) + `tests/test_reviewing_spec_lock.sh`·`tests/test_session_id_resolution.sh`·`tests/test_cancel_review.py` 회귀 락 확장(세 지점 mutation POS/NEG + degradation exact-literal + continuity non-collapse + cancel_review env-resolver 계약).

## [0.18.0] — 2026-07-02

### Added
- `scripts/review_lock.py` — **document-keyed(multi-key) `review_in_progress` 락**의 단일 소스. `set_lock`(그 키 엔트리 upsert/refresh, 나머지 보존)·`clear_lock`(그 키만 제거)·`pause`(clear + 같은-키 pending strip, suppress 없음 — resumable)·`is_review_active(body, pending_key, now, ttl)` + `{set|clear|pause}` CLI. 원자적 write(flush+fsync), stale prune, kill switch. `canonical_key`는 `suppress_state`에서 import(단일 정규화 소스).
- state.local.md `review_in_progress:` 엔트리 리스트(`suppressed_paths`와 동형) + `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` env(default 1800).
- `tests/test_review_lock.py`(유닛+CLI), `tests/test_reviewing_spec_lock.sh`(SKILL teeth 락).

### Changed
- `hooks/review-dispatch.py`(Stop) + `hooks/pending-review-reminder.py`(UserPromptSubmit) — suppress 체크 뒤·TTL 가드 앞에 `is_review_active` 게이트. 이 문서 락이 신선하면 no-op(pending 보존), 엔트리 부재/stale/파싱·import 예외면 정상 dispatch(fail-safe = 강제, Law 1). 다른 문서의 신선 엔트리는 pending_key 조회라 이 문서를 억제하지 않음(AC16).
- `skills/reviewing-spec/SKILL.md` — Step 1(매 진입)에서 `review_lock.py set`으로 그 문서 엔트리 refresh + Phase 5 옵션↔락 매핑표(①②=`approve_handoff.sh` clear, ③=재진입 refresh, ④=`review_lock.py pause`).
- `scripts/approve_handoff.sh` — suppress와 함께 `review_lock.py clear` 호출(그 문서 엔트리만). `scripts/cancel_review.py` — 취소 문서 키 엔트리 `clear`(approve 대칭, AC11).

### Fixed
- **subagent 경계 Stop 재발동**: `reviewing-spec`가 `spec-reviewer`를 async dispatch하고 await하려 턴을 멈출 때 발생하는 메인 `Stop`이, revise로 재-arm된 pending을 집어 리뷰를 (A) 중복 강제 / (B) 흐름 절단하던 오발. 문서별 락으로 "그 문서 리뷰 진행 중"을 표현해 봉쇄하되 리뷰 강제 계약(Law 1/2)은 100% 보존. 인터리브 2-문서 리뷰에서도 각 문서 보호 유지(multi-key, 한 문서 set이 다른 문서 락을 clobber 안 함).

### Removed
- `scripts/approve_handoff.sh`의 dead `git_common_dir`/`main_repo` 블록(v0.14.0에서 `rm -rf` 제거된 뒤 미사용).

## [0.17.0] — 2026-06-17

### Removed
- 인터뷰 월클락 메커니즘 **완전 제거**: `wall_clock_started_at` state 필드(conducting-interview schema) + reviewing-spec `## Steps` item 2의 wall-clock 체크(구 AC14) + Step 1 reader + `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` env var(양쪽 SKILL kill-switch + README) + README AP16 라인의 `wall-clock 30min` 토큰. 시계가 인터뷰 시작 시 켜지고 re-review 루프에서 트립해 *agent 자율성이 아니라 사람의 숙고 시간*을 오측정하던 footgun이었다 — AP16의 load-bearing 가드는 같은 루프의 re-review hard cap(5) + round-level stagnation early-exit이므로 월클락은 중복(redundant) 4번째 바운드였다. 구 세션 state의 잔여 `wall_clock_started_at` 키는 reader 부재로 무해하게 무시됨(migration 코드 불필요 — forward-compatible). harness-lightness(결정론은 load-bearing 게이트에만) + qg v2.0.0 월클락 budget 제거 선례에 정합. spec-distill은 v0.x라 one-minor deprecation window 면제 → 즉시 제거.

### Added
- `tests/test_no_wall_clock.sh` — 월클락 토큰(`wall_clock_started_at` / `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` / `wall-clock`) 재도입 방지 회귀 락. 라이브 surface 3파일(conducting-interview SKILL, reviewing-spec SKILL, README) 스캔, CHANGELOG는 history 보존이라 제외. v0.16.0 `test_hooks.sh` regression-lock 선례 패턴(repurpose 아닌 신규 파일).

### Changed
- `tests/test_readme_sync.sh` — 버전 기대값 0.16.0 → 0.17.0.

## [0.16.0] — 2026-06-16

### Removed
- `hooks/session-anchor.sh` (SessionStart 훅) + `hooks/hooks.json`의 SessionStart 등록. 이 훅은 이전 인터뷰 세션 디렉토리를 감지해 `/interview resume` 재진입을 안내했으나, `/interview resume`는 구현된 적이 없다(`commands/interview.md`에 resume 분기 부재) — state-storage 재설계에서 resume 커맨드가 사라진 뒤에도 안내 훅만 남아 매 세션 시작마다 실행 불가능한 조언을 LLM context에 주입하던 stale advisory였다. 훅은 P14 read-only advisor라 출력 소비처가 없고, 리뷰 흐름 상태(`pending_review`/`suppressed_paths`)는 UserPromptSubmit/Stop 훅이 독립 소비하므로 제거가 리뷰 파이프라인에 영향 없음. spec-distill은 v0.x라 one-minor deprecation window 면제 → 즉시 제거.

### Changed
- `tests/test_hooks.sh` — session-anchor 동작 테스트(기존 케이스 9–12)를 SessionStart 재도입 방지 회귀 락(hooks.json에 SessionStart 키 부재 + `session-anchor.sh` 파일 부재 두 단언)으로 재작성.
- `tests/test_hook_output_schema.py` — `TestSessionAnchorSchema` 클래스 및 `TestKillSwitches.test_global_disable_silences_session_anchor` 메서드 제거(`import shutil`은 다른 테스트가 사용하므로 유지).
- `README.md` — Hooks Installed 표의 SessionStart 행, Output schema 문장의 SessionStart 이벤트, Kill switches의 `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` 항목 제거.
- `tests/test_readme_sync.sh` — 버전 기대값 0.15.0 → 0.16.0.

## [0.15.0] — 2026-06-16

### Fixed
- `scripts/approve_handoff.sh` — **같은-턴 재dispatch 순서 버그**: `suppress_state.py add`(approved 키 기록 + same-key pending strip)를 working-tree 존재검사(`[[ -f ]]`) *앞으로* 이동. 기존엔 dangling/상대경로/서브디렉토리 cwd에서 `-f`가 먼저 `exit 1`로 빠져 suppress가 누락 → approve해도 같은 턴에 Stop hook이 재dispatch했다. canonical_key 기반 suppress는 파일 존재가 불필요하므로 이제 무조건 기록된다. (AC1)

### Changed
- `scripts/approve_handoff.sh` — `[[ -f ]]` 존재검사를 early-exit에서 **non-blocking advisory**로 강등. `exit 1`은 이제 **session_id charset/arg 검증 실패에 한정**(AC2). in-scope spec_path가 working-tree에 없어도 suppress 기록 + `exit 0` + stale advisory. 헤더 주석·최종 메시지를 v0.15.0 동작으로 갱신.
- `hooks/review-dispatch.py` (Stop) — pending의 path가 현재 세션 `suppressed_paths`에 있으면 **dispatch하지 않고** stale pending을 `suppress_state.strip_pending`으로 제거한다. **`last_dispatched_at`은 건드리지 않음**(TTL window 방지 — `cancel-review --reset` 직후 정당한 pending이 막히지 않도록, AC3b). `SCRIPTS_DIR`를 sys.path에 추가하고 `import suppress_state`를 `main()` try 블록 안에서 deferred 수행 — import 포함 모든 suppress-체크 예외는 fail-open(정상 dispatch, 과리뷰가 under-review보다 안전). Law 2 트리거/억제 대칭 복원. (AC3/AC4/AC5)
- `skills/reviewing-spec/SKILL.md` — "Approve handoff sequence" + "실패 시 state 보존" 절을 새 순서·exit 의미로 동기화.
- `tests/test_handoff_spec_path_validation.sh` — AC4a/AC4b를 새 계약(missing/dangling in-scope → `exit 0` + suppress 기록 + pending strip + advisory + dir 보존)으로 전환. `tests/test_review_dispatch.sh` — suppressed→no-dispatch+strip+TTL불변 / non-suppressed→dispatch 케이스 추가. `tests/test_hook_output_schema.py` — suppress import 실패 fail-open 단언 추가. `tests/test_readme_sync.sh` — 버전 0.14.0 → 0.15.0.
- `README.md` — Flow(v0.15.0) + Principles(Law 2 트리거/억제 대칭) 동기화.

### Notes
- W1(모델이 approve_handoff 자체를 미실행)은 구조적으로 막을 수단(PostToolUse가 AskUserQuestion approve를 감지)이 공식 문서상 보장되지 않아 제외 — `/spec-distill:cancel-review` escape hatch + (재발 증명 시) Law 3 persona/skill 편집이 stance.

## [0.14.0] — 2026-06-05

### Added
- `scripts/suppress_state.py` — per-doc·session-scoped `suppressed_paths` 집합의 **단일 소스**(정규화·pending strip·suppress). Python API(`canonical_key`/`pending_path`/`suppressed_keys`/`strip_pending`/`state_file_for`/`is_suppressed`/`add`/`remove`/`suppress_path`) + thin CLI(`{add|remove|is-suppressed} <sid> <raw_path>`). 정규화는 이 파일에만 존재 — 호출자는 raw 경로 위임(C4/AC17).
- `scripts/cancel_review.py` + `commands/cancel-review.md` — `/spec-distill:cancel-review [path] | --reset <path>`. 현재/지정 design 문서의 auto-review를 취소·억제(또는 재활성화). 리뷰 완료/중단 후 같은 문서 재편집 시 reviewing-spec가 재dispatch되던 두 gap(증상 A/B)을 끄는 사용자 주권(P17) 경로.
- Tests: `tests/test_cancel_review.py`(suppress_state 단위 + cancel_review 통합, AC1–AC8/AC11/AC14/AC17/AC19) + `test_spec_write_validator.sh`/`test_approve_handoff.sh` 확장.

### Changed
- `hooks/spec-write-validator.py` — Layer 1 통과 후 `write_state` 직전 `suppress_state.is_suppressed` 게이트: suppressed 문서는 arm skip + 전용 suppress advisory(기존 "Reviewer will be dispatched" 출력 *교체*) + return 0(AC9/AC18). Layer 1 구조 검증 불변(NG1/AC10). inline pending-strip re.sub → `suppress_state.strip_pending`(중복 제거).
- `scripts/approve_handoff.sh` — 세션 dir `rm -rf` → `suppress_state.py add`(approved 키 기록 + same-key pending strip). dir cleanup은 SessionEnd/TTL-GC로 이관 — 삭제 시 "승인됨" 기억 소실로 증상 A 재발(AC12). "idempotent by statelessness" → "idempotent by set-membership". `skills/reviewing-spec/SKILL.md`의 approve-handoff 계약 서술도 동기화.
- `tests/test_readme_sync.sh` — 버전 기대값 0.13.0 → 0.14.0 + `cancel-review` README 동기화 체크. `tests/test_handoff_compact_chain.sh` — approve가 dir 보존 + suppressed_paths 기록함을 검증하도록 계약 갱신.
- `README.md` — Flow(v0.14.0) + Hooks Installed(PostToolUse suppression 게이트) + Principles(P17 cancel/reset) + Kill switches(per-doc suppression 안내).

### Notes
- suppression은 **session-scoped**: SessionEnd cleanup이 dir를 삭제해 다음 세션은 fresh(NG4/AC15). 재리뷰는 `--reset <path>`, 다른 경로의 새 문서, 또는 reviewing-spec 직접 호출.
- `review-dispatch.py`(Stop)·`pending-review-reminder.py`(UserPromptSubmit)는 무변경 — pending_review가 안 생기므로 자연 no-op.

## [0.13.0] — 2026-06-04

### Added
- `skills/conducting-interview/SKILL.md` Step B — interview→brainstorming 핸드오프를 단일 `AskUserQuestion` **proceed 게이트**(3옵션: ① `/compact` 후 brainstorming 권장 / ② 바로 brainstorming / ③ brief만 종료)로 재작성. `reviewing-spec` Phase 5의 `/compact` 게이트와 **대칭** — 긴 인터뷰 context(round 대화·web sweep·steelman 중간산출)를 해답공간 진입 *전에* 정리할 수 있게. 두 가드 명문화: AP2 polite-stop 금지 + cross-compact 조기진행 금지(옵션 ① 노출 후 같은 턴 brainstorming 직진 금지, AC19 대칭, AC21). superpowers 부재 시 graceful degradation(brief terminal + loud advisory + STOP, 게이트 없음)은 보존(AC13). NG7(handoff 비강제)은 옵션 ③으로 가시화.
- Tests: `tests/test_conducting_interview_stage.sh`에 AC20(3옵션 게이트 + verbatim /compact) / AC21(i)(cross-compact stop wording, mechanical layer) / AC22(AP2 polite-stop ban) grep assert 추가.

### Changed
- `tests/test_readme_sync.sh` — 버전 동기화 기대값 `0.12.0 → 0.13.0`.
- `README.md` — Flow 다이어그램에 interview→brainstorming proceed 게이트 표기 + "Principles Instantiated" AP2에 interview-side `/compact` 대칭 게이트 한 줄.

### Notes
- `approve_handoff.sh`는 interview 쪽에서 **호출하지 않음** — brief는 같은 턴에 막 작성 + `check_brief.py` 검증되어 stale 위험이 없고, 세션 cleanup은 하류(brainstorming→reviewing-spec→spec→writing-plans의 approve_handoff) 또는 SessionEnd가 담당. 옵션 ① 노출 전 `[[ -f <brief-path> ]]` 경량 존재 가드만 둠(게이트 아님).
- `reviewing-spec` Phase 5는 무변경 — 본 작업은 interview 쪽 비대칭만 해소.

## [0.12.0] — 2026-06-01

### Added
- `scripts/web_budget.py` — interview web-research budget enforcer (per-sweep ≤4 / per-session ≤8, state-file counters). Subcommands `check` / `increment` (read-modify-write +1 both counters, preserving inline comments, then check) / `reset-sweep` (sweep boundary). The parser tolerates the schema's inline-comment counter format and fails closed on a present-but-non-numeric counter (never silent-0). Kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` short-circuits to ok (graceful degradation). (AC7/AC8/PN3)
- `scripts/check_brief.py` — interview-brief structural gate (7 sections / non-empty cited landscape / steelman-log well-formedness + frontmatter↔§4 cross-consistency / tried-&-discarded). Strips fenced code blocks before section detection (quoted headers can't satisfy the gate); an unreadable brief emits structured failure JSON, not a traceback. The Law 1 5-ritual termination gate, made mechanical. (AC2/AC4/AC5)
- `agents/steelman-builder.md` — scoped read-only adversarial counter-case builder (`disallowedTools: Write/Edit/MultiEdit/NotebookEdit`; `allowedTools` include WebSearch/WebFetch). Security-sensitive persona. (AC5/AC6)
- `templates/interview-brief-template.md` — canonical 7-section meta-prompt format. (AC1)
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` kill switch — disables interview web research, landscape skipped with loud log.
- Tests: `test_web_sweep_bound.sh`, `test_check_brief.sh`, `test_steelman_builder_scope.sh`, `test_conducting_interview_stage.sh`, `test_reviewing_spec_design_only.sh`, `test_readme_sync.sh` + brief/state fixtures; `test_hook_output_schema.py` design-doc + interview/-exclusion regression.

### Changed
- `skills/conducting-interview/SKILL.md` — re-positioned as a strong problem-space stage (Double Diamond 1st diamond): 5 통과 의례 (R1 Reframe / R2 Landscape / R3 Skepticism / R4 Tried-&-Discarded / R5 Open-Questions) as a Law 1 structural gate; web path(a) expansion; steelman gate; terminal interview-brief output at `docs/superpowers/interview/`; optional `superpowers:brainstorming` handoff. `cost_class: medium → variable`. State writes via Bash (worktree-safe — PN1).
- `commands/interview.md` — role reframed to problem-space stage (trivia escape unchanged, NG6).
- `skills/reviewing-spec/SKILL.md` — **design-mode only**: spec-mode routing rows + `[3.5]` re-consensus gate + `mode_b_violation` handling + `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS` removed (dead paths after drafting-spec removal). Design-doc review + Phase 5 proceed gate unchanged (Law 2 intact).
- `agents/spec-reviewer.md` — description/role refreshed for the design-only flow; clarified the interview brief is NOT its target (NG3). Mode branches + categories unchanged (C3 — not weakened).

### Removed
- `skills/drafting-spec/` (Mode A + Mode B) — the interview now produces a self-complete brief and brainstorming writes the design doc; design revisions are author-regression edits by the main agent, so the spec-writer skill is obsolete. (decision #10)
- Tests/fixtures for removed paths: `run-fixture-ac1.sh`, `interview-transcript-bbda.md`, `mode-b-guard-case.md`, `reconsensus-loop-case.md`, `routing-trace-cases.md`, `stagnation-cases.md`.

### Notes
- superpowers (`brainstorming`/`writing-plans`) remains an optional external plugin. With it absent, `/interview` completes at the brief and logs a loud advisory — no crash, no spec-mode fallback (AC13).
- Hooks are unchanged: `spec-write-validator.py` already classifies `-design.md` under `docs/superpowers/specs/` as design mode and auto-excludes `docs/superpowers/interview/` (outside `PATH_PREFIX`, C8).

## [0.11.3] — 2026-05-31

### Changed
- `tests/test_conducting_interview_internal.sh` — AC1 가드를 frontmatter 블록 한정으로 강화. 기존 `grep -q '^user-invocable: false$' "$SKILL"`는 파일 전체를 검사해, 이론적으로 키가 frontmatter 밖 본문에 있어도 통과할 수 있었음 (menu-visibility를 제어하지 않는 위치). `awk '/^---$/{c++} c==1'`로 첫 `---`…두 번째 `---` 블록만 추출 후 grep하여, 키가 실제로 frontmatter 안에 있을 때만 PASS. 파이프 대신 command-substitution+herestring으로 `set -uo pipefail` SIGPIPE 오탐 회피. 회귀: body-only 키 fixture로 AC1 FAIL 확인. (quality-gates v2.1.0 codex SUGGESTION #1, adversarial conf 3 — 비차단 polish.)

## [0.11.2] — 2026-05-31

### Changed
- `skills/conducting-interview/SKILL.md` — frontmatter에 `user-invocable: false` 추가. 내부 인터뷰 엔진 스킬을 `/` 슬래시 메뉴에서 숨겨 사용자 진입점을 `/interview` 하나로 단일화 (`/conducting-interview` 직접 호출 시 command의 kill switch·trivia escape 게이트 우회 → Law 1 진입 규율 무결성 보호). CC 공식 doc verbatim: `user-invocable`은 *"only controls menu visibility, not Skill tool access"* — command의 `Skill conducting-interview` dispatch·`reviewing-spec` re-entry·모델 자동 트리거는 전부 보존. `disable-model-invocation`은 정반대 효과(Skill tool 차단)라 미사용.

### Added
- `tests/test_conducting_interview_internal.sh` — 회귀 가드. `user-invocable: false` 존재(AC1) + 기존 frontmatter 3키 보존(AC2) + command dispatch·reviewing-spec re-entry 프로그램 호출 경로 보존(AC3). 누가 필드를 지우거나 dispatch 라인을 깨면 fail (Law 3 compounding).

## [0.11.0] — 2026-05-29

### Removed
- `hooks/compact-induction.py` — marker 기반 Stop-hook `/compact` 재주입 폐기. /compact 추천은 reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트로 이동 (hook은 AskUserQuestion을 띄울 수 없음).
- `hooks/compact-detect.py` — marker 삭제용 UserPromptSubmit hook. marker 부재로 무의미.
- `.claude/spec-distill/.markers/` marker 메커니즘 전체 + `approve_handoff.sh`의 named-status 상수(`HANDOFF_STATUS_*`)·packet emit·`dirty_blocked` exit-1.
- `scripts/spec-distill-gc.py`의 `_sweep_markers` — marker 미생성으로 sweep 대상 부재. **marker GC coverage 포기는 의도적** (markers는 v0.11.0부터 생성되지 않음).
- 테스트: `test_compact_induction_hook.sh`, `test_compact_induction_stagnation.sh`, `test_compact_detect_hook.sh`, `test_handoff_approve_packet_emit.sh`, `test_handoff_status_named.sh`, `test_gc.py`의 marker 케이스(test_13~16).

### Changed
- `skills/reviewing-spec/SKILL.md` Phase 5 — 단일 `AskUserQuestion` proceed 게이트(① /compact 후 writing-plans 권장 / ② 바로 writing-plans / ③ 수정 / ④ 멈춤)로 재구성. approve 후 2차 질문 없음. polite-stop(AP2) + cross-compact 조기 진행 금지(AC19) verifiable 기준 명문화. (구 packet의 verbatim `/compact` 명령 템플릿 — 본문 preserve / 인터뷰·기각대안·중간추론 drop / writing-plans next-step — 은 option ① prose로 이전.)
- `scripts/approve_handoff.sh` — thin finalizer로 축소: spec_path working-tree 존재 검증 + 세션 cleanup. 미커밋 검사는 advisory(non-blocking, exit 0).
- `hooks/hooks.json` — Stop=review-dispatch만, UserPromptSubmit=pending-review-reminder만. description 갱신.

### Fixed
- dangling `spec_path` 핸드오프 예외 — `[[ -f "$spec_path" ]]` working-tree 가드를 모든 git 조회 *이전*에 수행. 삭제된 worktree 경로(git HEAD tracked but working-tree absent)가 `git rev-parse HEAD` 성공으로 통과하던 결함 봉쇄.

### Added
- `tests/test_handoff_spec_path_validation.sh` — AC4a(부재) + AC4b(dangling worktree) 회귀.

### Security
- 없음. review-dispatch / pending-review-reminder / spec-reviewer persona 무변경 — review 강제(Law 1/2) 유지.

## [0.10.0] — 2026-05-27

### Added
- `hooks/compact-induction.py` — Stop event hook. `.claude/spec-distill/.markers/<sid>.emitted` marker 감지 시 `hookSpecificOutput.additionalContext`로 verbatim `/compact` 명령 + `Skill superpowers:writing-plans` 안내 emit. 5회 fire 도달 시 self-cleanup + stagnation advisory.
- `hooks/compact-detect.py` — UserPromptSubmit event hook. `user_prompt`/`user_message`/`prompt` 필드 lstrip + startswith로 `/compact` 또는 `Skill superpowers:writing-plans` 시작 감지 시 marker 삭제.
- `tests/test_handoff_status_named.sh` — Ouroboros named-status invariant (3 readonly 상수).
- `tests/test_compact_induction_hook.sh` — AC4/AC6/AC7/AC8 Stop hook contract.
- `tests/test_compact_detect_hook.sh` — AC5 lstrip+startswith 7-case.
- `tests/test_compact_induction_stagnation.sh` — AC6 5-fire self-cleanup.
- `tests/test_handoff_compact_chain.sh` — V9 end-to-end hook chain JSON contract.

### Changed
- `scripts/approve_handoff.sh` — **commit 단계 완전 제거** (LD4: spec은 사용자 책임). idempotent state machine으로 재설계: `HANDOFF_STATUS_ALREADY_DONE` / `HANDOFF_STATUS_DIRTY_BLOCKED` / `HANDOFF_STATUS_EMITTED` 3-status named-status (Ouroboros `handoff_contract.py` 패턴). marker file `.claude/spec-distill/.markers/<sid>.emitted`에 `STATUS=`/`TIMESTAMP=`/`FIRE_COUNT=`/`SPEC_PATH=` plaintext key=value 기록. 재호출 시 TIMESTAMP 보존 (dedupe invariant).
- `hooks/hooks.json` — UserPromptSubmit에 compact-detect.py, Stop에 compact-induction.py 등록 (기존 hook과 공존).
- `tests/test_approve_handoff.sh` — Case 1/5/7을 AC1/AC2/AC3 의미로 재작성. dirty_blocked stderr 4-token assertion + idempotent re-run TIMESTAMP preservation 검증. 모든 tmpfile은 per-run mktemp dir 안에서 처리 (CI parallel 안전).
- `scripts/spec-distill-gc.py` — `_sweep_markers()` 신규 헬퍼 + `gc()` 메인 루프에 한 줄 추가. `.markers/` 디렉토리의 24h+ stale marker 파일 정리 (기존 fcntl lock / TTL 패턴 재사용).

### Notes
- v0.9.0 에서 생성된 spec 파일은 grandfather migration 없음 (NG5). 기존 `.handoff-status` marker 부재 시 첫 approve_handoff.sh 호출에서 정상 생성.
- compact-detect.py는 `user_prompt`/`user_message`/`prompt` 세 키 모두 읽음 (Claude Code hook schema tolerance — 셋 중 하나 존재 시 처리. 실제 schema는 `user_prompt`이지만 spec 가정과의 forward compat 위해 fallback 유지).
- compact-induction.py와 review-dispatch.py는 같은 Stop 이벤트에 공존. 실 운영에서는 pending_review block 정리 후 marker가 생성되므로 두 hook이 동시에 emit하지는 않음.

## [0.9.0] — 2026-05-26

### Added
- `templates/spec-template.md` — `## Handoff Context` 섹션 신설 (`## Goal` 직후). TL;DR / Implicit context / Deferred to plan 3개 하위 항목. spec/design 파일 self-containedness baseline (G2, AC1).
- `agents/spec-reviewer.md` — `handoff_incomplete` block-severity 카테고리 (spec mode 11→12 카테고리, design mode 6→7 카테고리). 3개 sub-pattern (섹션 부재 / 하위 항목 미작성 / conversation reference 검출). 15개 conversation reference 패턴 enumerated (영어 8 + 한국어 7). v0.10.0+ list 확장 정책 명시.
- `scripts/approve_handoff.sh` — Step 2 출력 교체: minimal 2-line "다음 단계:"에서 3-block "Handoff packet" (divider / `/compact` 명령 with preserve+drop+next-step embed / `[2]` standalone safety net Skill writing-plans 라인 / 종료 divider). /compact preserve directive에 next-step instruction embed로 compact-survival best-effort 지원.
- `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` kill switch — `handoff_incomplete` 카테고리만 우회, 다른 검사는 정상. loud warning stderr 출력.
- `tests/test_handoff_*.sh` 6개 신규 test — AC2/AC3/AC4/AC5/AC6/AC7 (모두 `test_handoff_*` prefix로 V1 glob 일관).

### Changed
- spec/design 파일의 review 통과 기준이 self-containedness까지 확장. /compact 경계를 spec lifecycle의 1급 시민으로 승격 — Law 1 (Clarity Before Code) 자연스러운 확장.

### Notes
- Pre-v0.9.0 spec.md grandfather 처리 안 함 (design 문서 NG8 / R6). 기존 spec 재review 시 사용자가 `## Handoff Context` 섹션을 30초 분량 수동 추가 필요. reviewer가 추가 위치/내용을 recommendation으로 안내.

## [0.8.1] — 2026-05-26

### Fixed
- `agents/spec-reviewer.md` — Input/Design Mode Branch wording이 v0.8.0의 content-aware scope 확대를 반영하지 못하던 drift 정정. Input path는 `<file>-spec.md` 한정에서 `docs/superpowers/specs/` hierarchy 안 임의 `.md`로 일반화. Design Mode Branch trigger는 (a) `*-design.md` suffix, (b) suffix 없는 `.md`가 frontmatter `locked_decisions` 부재로 content-aware 판별, (c) dispatcher `mode: design` 명시 — 세 갈래를 명시. Hook 결정론과 reviewer self-narrative 정렬 (Law 2 baseline operability).
- `hooks/spec-write-validator.py` docstring + `README.md` Hooks 표 + `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` 설명에 "sub-folder hierarchy 포함" 명시. v0.8.0 시점부터 `resolve_mode()`의 `PATH_PREFIX in file_path` substring 매칭이 sub-folder를 자동 포함하던 것을 contract로 박제.
- `skills/reviewing-spec/SKILL.md` — `mode: design` 분기 설명에서 "brainstorming의 design.md" → "design 모드 파일 (suffix 또는 content-aware)"로 mechanism-agnostic 표현으로 정정.

### Added
- `tests/test_resolve_mode_scope.sh` — sub-folder 회귀 가드 5 case 추가 (depth-1 `-spec.md`, depth-1 `-design.md`, depth-2 content-aware spec, depth-1 content-aware design, hierarchy boundary 위반 false-positive 차단 `specs_archive/`).

## [0.8.0] — 2026-05-22

### Changed
- `hooks/spec-write-validator.py`:`resolve_mode()` — review 게이트 범위를 `docs/superpowers/specs/` 아래 **모든 `.md`**로 확대(기존: `-spec.md`/`-design.md` suffix만). suffix 없는 `.md`는 신규 `_frontmatter_has_locked_decisions()` inline 헬퍼로 mode 판별: 첫 `---`…`---` frontmatter 블록에 `locked_decisions` 키 있으면 `spec`, 없으면 `design`. body 언급·unclosed frontmatter·디코드 실패는 `design`(안전 fallback) + loud stderr. reviewing-spec routing·검사 로직·state 스키마 불변. review 강제(Law 2)가 파일명 컨벤션에 의존하던 취약점 제거.

## [0.7.0] — 2026-05-22

### Removed
- `hooks/interview-trigger.sh` + `hooks.json` UserPromptSubmit 등록 — advisory build/make nudge 훅. ~80개 세션 트랜스크립트 hook-attachment 전수 스캔 결과 3주간 0회 발화 (trigger 조건 `키워드 + <20단어`가 실사용 프롬프트와 미매칭). 훅 surface는 review 강제(Law 2)로 정당화되며 interview 진입은 `/interview` 직접 호출로 충분 — advisory(`additionalContext`)는 모델이 무시 가능해 비결정적. `hooks.json` `description`에서 "interview" 문구 제거.
- `hooks/state_path.py`:`cleanup_stale_states()` 함수 전체 블록 + `DEPRECATION_MARKER` 상수 + 모듈 docstring `cleanup` CLI 줄 + `main()`의 `cleanup` 분기·usage 토큰 — v0.6.0에 deprecated된 no-op(약속대로 제거). 호출처 없음 (TTL-GC + SessionEnd hook이 정리 담당). `tests/test_state_cleanup.sh` 삭제.
- 테스트 정리: `tests/test_hook_output_schema.py`의 `TestInterviewTriggerSchema` + `test_global_disable_silences_interview_trigger`, `tests/test_hooks.sh`의 interview-trigger 섹션, `README.md` Hooks Installed 표의 interview-trigger 행.

## [0.6.0] — 2026-05-19

### Added
- `hooks/session-end-cleanup.py` — SessionEnd hook for deterministic per-session state cleanup (qg pattern adaptation, git-aware path).
- `scripts/spec-distill-gc.py` — TTL-based GC (24h) with fcntl lock + double-stat ns + rename-then-rmtree race guard. `.gc-pending-*` orphan sweep (>60s) on each invocation.
- `scripts/approve_handoff.sh` — atomic AC11 approve handoff (4-step: commit / handoff pointer / cleanup / termination). Extracted from `skills/reviewing-spec/SKILL.md` prose.
- `hooks/state_path.py`:`resolve_session_id(payload)` + `SESSION_PATTERN` — single source of truth for session_id, charset/length validation.
- 7 new tests: `test_session_id_resolution.sh`, `test_session_end_cleanup.py`, `test_gc.py`, `test_approve_handoff.sh`, `test_stale_state_truncate.sh`, `test_brainstorming_entry.sh`, `test_kill_switches_v060.sh`.

### Changed
- `hooks/spec-write-validator.py`, `hooks/review-dispatch.py`, `hooks/pending-review-reminder.py` — session_id source switched from `os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")` literal fallback to `resolve_session_id(payload)`. Production now resolves from `CLAUDE_CODE_SESSION_ID`. `DEVBREW_SPEC_DISTILL_SESSION_ID` retained as test override.
- `hooks/spec-write-validator.py`:`write_state` — defensive truncate when existing state.local.md frontmatter `session_id` ≠ current (defense-in-depth).
- `hooks/spec-write-validator.py` — AC14 legacy advisory: detect `.claude/spec-distill/default/` and emit one-shot stderr advisory (marker `.legacy-advisory-emitted-v060`).
- `hooks/hooks.json` — SessionEnd event registered.
- `skills/reviewing-spec/SKILL.md` — AC11 4-step prose replaced with 1-line `approve_handoff.sh` script call.

### Deprecated
- `hooks/state_path.py`:`cleanup_stale_states` — no-op + marker-based one-shot deprecation stderr. Removed in v0.7.0.

### Fixed
- 잔여 frontmatter bug (사용자 보고 2026-05-19): `.claude/spec-distill/default/state.local.md`에 이전 세션의 frontmatter가 누적되어 새 세션이 stale data 위에 쓰는 증상. Root cause: `DEVBREW_SPEC_DISTILL_SESSION_ID` 부재 시 모든 hook이 `"default"` literal로 fallback → singleton file 공유. Fix: `CLAUDE_CODE_SESSION_ID` 단일 source + SessionEnd hook + TTL-GC + write_state defensive truncate (4-layer defense).

### Security
- session_id charset validation `^[A-Za-z0-9_-]{8,}$` 모든 cleanup path (SessionEnd hook, TTL-GC, approve_handoff.sh, write_state)에 적용 — `../traversal` 등 path injection 차단.

## [0.5.1] — 2026-05-17

### Fixed
- `reviewing-spec/SKILL.md` Re-review cap drift — v0.3.0가 body section의 hard cap을 `>= 3` → `>= 5`로 상향했으나 동일 파일의 (a) frontmatter description (`max 3`), (b) Deterministic Routing Table 5개 행 (spec `< 3` / `>= 3` × 2 + design `< 3` / `>= 3`), (c) `README.md` ASCII flow `max 3`, (d) `tests/test_reviewing_spec_design_routing.sh`의 `count >= 3` assertion이 갱신되지 않아 cap=5가 *dead code*였음. Routing table의 `>= 3` 행이 먼저 fire하여 v0.2.0의 cap=3과 동등하게 동작. 본 PR이 5개 위치 모두 5로 통일하여 v0.3.0 의도가 비로소 enforce됨. **Behavioral change**: re-review가 이제 실제로 4–5회 반복 가능 (이전엔 3회에서 forced Human Gate).

### Added
- `tests/test_rereview_cap_consistency.sh` — cross-file invariant test. SKILL.md body의 `Hard cap**: \`rereview_count >= N\`` 라인에서 N을 source-of-truth로 추출 후 8개 derived 위치 (SKILL.md frontmatter + routing 4행 + README ASCII flow + README AP16 + design-routing test)가 모두 같은 N을 사용하는지 검증. devbrew Law 3 (Compounding) instantiation — 미래 cap 변경 시 derived 갱신을 빠뜨리면 즉시 fail.

## [0.5.0] — 2026-05-17

### Fixed
- 5개 hook (`review-dispatch.py`, `spec-write-validator.py` advisory 분기, `pending-review-reminder.py`, `interview-trigger.sh`, `session-anchor.sh`) 의 stdout JSON이 Claude LLM context로 도달하지 않던 silent failure. `systemMessage` 필드는 Claude Code 사양상 user transcript 표시 전용이며 LLM context inject 메커니즘이 아니다. 올바른 필드는 `hookSpecificOutput.additionalContext` (PostToolUse/UserPromptSubmit/SessionStart) 또는 Stop hook의 `decision:"block" + reason` 페어. dual-target 출력 (Claude-target field + `systemMessage` 짧은 흔적, ≤120자, "[spec-distill]" prefix) 으로 정정 — Claude는 context로 받고 user는 transcript에서 발화 흔적 확인 가능.
- `review-dispatch.py` `rewrite_state()` 호출 순서 정정 (write-before-emit, AC7.1). `rewrite_state()` 본문에 `f.flush()` + `os.fsync(f.fileno())` 추가하여 OS-level durability 보장. 이전 ordering (print → rewrite) 은 동일 turn 안에서 두 번째 Stop fire가 stale state를 읽고 두 번째 block 출력하는 block storm을 일으킬 수 있었음.
- `review-dispatch.py` rewrite OSError 시 `{}` exit 0 (block emit 안 함, AC7.2). 이번 dispatch 1회는 누락되나 L4b UserPromptSubmit reminder가 다음 user prompt에서 dispatch를 살림 — block storm 회피가 우선.
- `interview-trigger.sh` no-jq fallback에 `tr -d '\r'` 추가하여 session-anchor.sh와 CR 처리 대칭.

### Changed
- Stop hook (`review-dispatch.py`) 의 `decision:"block"` 이 Stop을 막고 Claude를 즉시 continue 시키므로 "다음 turn 첫 액션은 reviewing-spec" 강제가 user 입력 대기 없이 작동. 기존 30초 TTL guard (`DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`) 가 무한 block 루프 방지를 그대로 담당.

### Added
- `tests/test_hook_output_schema.py` — Python `unittest` 기반 통합 회귀 방지 test. 5개 hook 모두에 대해 happy-path schema assertion + AC1a 인코딩 round-trip + AC7.2 fault injection + AC7.3 ordering 3-prong (AST inspection + mock-based trace) + AC10/AC11 kill switch + NG9 cross-resolver advisory (skipUnless worktree). bash fallback (jq-없는 환경) 케이스는 `unittest.skipUnless`로 환경 감지.

### Security
- kill switch 5개 (`DEVBREW_DISABLE_SPEC_DISTILL=1` 전역 + `DEVBREW_SKIP_HOOKS=spec-distill:<event>` hook 단위) 모두 무변경. 신규 env var 없음.
- bash hook no-jq fallback escape scope: backslash + double-quote + LF + CR만 처리. null byte / 기타 control char / non-BMP unicode는 처리 범위 밖 — jq path에서 full JSON escape 처리.

## [0.4.0] — 2026-05-17

### Added
- `hooks/state_path.py` — main repo root 해석 helper (`git rev-parse --git-common-dir` 기반). state 파일을 항상 main repo `.claude/spec-distill/` 아래에 기록 (worktree 호출 시에도). cwd fallback + stderr loud log (philosophy §4.8 instantiation).
- `hooks/pending-review-reminder.py` — UserPromptSubmit hook. pending_review가 살아있고 last_dispatched_at > TTL(30s)이면 mandate 재emit (L4b redundancy). Kill switch `spec-distill:UserPromptSubmit` / `spec-distill:reminder`.
- State cleanup 정책: pending_review `triggered_at` > 24h → block auto-purge, last_dispatched_at만 있는 state file > 7일 → file auto-delete. 신규 env var 없이 하드코딩.
- reviewing-spec SKILL.md — Step 1 `pending_review.mode` 분기 + Routing Table에 design rows 3개 추가 (approved → writing-plans, needs_revise < 3 → brainstorming author 회귀, needs_revise ≥ 3 → forced Human Gate). drafting-spec Mode B는 design.md에 호출하지 *않음*.
- agents/spec-reviewer.md — design mode checklist 분기 섹션 6 카테고리 (placeholder / ambiguity / scope_creep / approaches_comparison / isolation / testing). spec mode 본문 무손상.
- 신규 test 6개: `test_state_path.sh`, `test_state_cleanup.sh`, `test_design_mode_validator.sh`, `test_review_dispatch_design_mandate.sh`, `test_reminder_hook.sh`, `test_reviewing_spec_design_routing.sh`, `test_spec_reviewer_design_checklist.sh`.
- 신규 fixture 2개: `tests/fixtures/2026-05-17-test-design.md` (valid), `tests/fixtures/2026-05-17-test-design-bad.md` (placeholder + ambiguity hits).

### Changed
- `hooks/spec-write-validator.py` — state path을 `state_path.state_root()`로 해석, pending_review block에 `worktree_path:` 필드 추가.
- `hooks/review-dispatch.py` — state path을 state_path helper로 해석, mandate systemMessage 본문에 "타 terminal handoff(writing-plans 등) 보류" 문구 + worktree_path 포함, fire마다 `cleanup_stale_states` 호출.
- `hooks/hooks.json` — UserPromptSubmit에 reminder hook 등록 (기존 interview-trigger.sh 옆).

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중. 신규 env var 없음 (LD10 일관성).
- bare repo / submodule / nested worktree / `.git` symlink는 supported scope 밖 — state_path cwd fallback + loud log로 운영자 인지 (NG6).

## [0.3.0] — 2026-05-16

### Added
- PostToolUse hook `hooks/spec-write-validator.py` — spec/design 파일 write를 file-system level에서 가로채 Layer 1 mechanical 검증 (11 sections, frontmatter, locked_decisions schema, ambiguity blacklist, design-mode placeholder scan).
- Stop hook `hooks/review-dispatch.py` — `pending_review:` ledger 기반 결정론적 reviewer dispatch (systemMessage 주입).
- `scripts/parse_spec_structure.py` — frontmatter / sections / locked-decisions / ambiguity / placeholders CLI subcommand 라이브러리.
- `scripts/ambiguity-blacklist.txt` — 측정 불가 키워드 + `~` escape 지원.
- design.md (brainstorming upstream 산출물) 커버리지 — suffix-based mode 분기, frontmatter optional, ambiguity + placeholder만 검사.
- 7 fixture 파일 (`tests/fixtures/`) + `test_spec_write_validator.sh` + `test_review_dispatch.sh`.
- Kill switches: `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`, `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<sec>`.

### Changed
- `reviewing-spec/SKILL.md` Step 1 — dispatch trigger가 hook-driven (file ledger `pending_review:` block) 임을 명시.
- `reviewing-spec/SKILL.md` Re-review cap — hard cap `>= 3` → `>= 5` + round-level stagnation early-exit (verdict `needs_revise` + `Stagnation_signal: true` → 즉시 [5] Human Gate). multi-round drift detection을 위한 budget 확장.
- `drafting-spec/SKILL.md` Mode A/B — handoff 단계에서 명시 reviewing-spec 호출 불필요, hook이 결정론 dispatch함을 note.

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중.
- PostToolUse exit 2 + stderr 차단 패턴 + stdout `{"decision":"block"}` 이중 안전.

## [0.2.0] — 2026-05-13

### Added
- Re-consensus gate (Phase [3.5]) — locked-affecting reviewer issue가 자동 Mode B로 가지 않고 `AskUserQuestion` 3-옵션 (수용/유지/추가 인터뷰)으로 사용자 게이트.
- spec.md frontmatter `locked_decisions:` 리스트 — `LD1, LD2, ...` ID로 인터뷰 (b)/(d) path 합의를 self-contained contract로 기록.
- state.local.md 신규 필드: `pending_locked_decisions`, `issue_history[].dismissed_by_user`, `issue_history[].accepted_by_user`, `issue_history[].reconsensus_count`, `reconsensus_accepted_ids`.
- drafting-spec Mode B `allowed_issue_ids` 입력 contract — 위반 시 abort + `git restore` + state.local.md `mode_b_violation` marker + reviewing-spec [3.5] re-entry.
- spec-reviewer agent 출력에 issue별 `affects_locked_decisions: [LD ids]` 필드.
- Escalate priority table (P1–P4): C3 global cap (≥4 locked-affecting → spec 전체 [5]) > AC9 per-issue (`reconsensus_count >= 2`) > P18 stagnation > reviewer-persona warn.
- Kill switch `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` (loud warning).
- v0.1.x in-flight state migration — missing field 자동 promote (non-mutating read).
- V0 pre-gate (fixture 존재 검증) + `set -e -o pipefail` 전역 적용.

### Changed
- P18 stagnation 판정 조건: `raised_count >= 3` → `raised_count >= 3 AND dismissed_by_user == 0` (사용자 명시 거절을 stagnation에서 제외).
- spec-reviewer agent — frontmatter `Read` tool 사용 허용 (locked_decisions 추출 목적).
- drafting-spec Mode A — interview transcript에서 `pending_locked_decisions`를 frontmatter `locked_decisions:`로 변환.
- README "Principles Instantiated"에 P17 explicit instantiation 한 줄 추가.
