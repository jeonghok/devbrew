# Changelog

## [4.4.0] — 2026-09-24

minor 인 이유 — 새 surface 가 셋이다: 조사 주장 계약의 정본(`references/research-claims.md`)과 그
배달 펜스, 세 dispatch 자리의 입력 슬롯 둘(`claims_contract` · `open_decisions`), 그리고
`check_brief.py` 의 조사 축 술어 다섯. 삭제는 리터럴 마커 하나(`[from-code][auto-confirmed]`,
15사이클 0건)뿐이라 호출 계약은 줄지 않는다. 설계
`docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md`.

### Added

- **조사 주장 계약이 정본을 갖는다.** `references/research-claims.md` 가 `evidence[]`(외부) ·
  `repo_claims[]`(내부) 두 모양을 담고 신설 필드 둘을 정의한다 — `decides`(닿는 열린 결정 `OQ<n>`)와
  `id: RC<n>`(payload·audit 을 잇는 id). 기존 `touches`(전제 `P<n>`)의 뜻은 **바뀌지 않는다**:
  `steelman.md` Step 2 대조 · Step 2.5 재검토 자격 · 4-block 라벨 · audit 템플릿의 「부착 주장 → P<n>」
  넷이 그 키잉에 의존한다.
- **계약이 네 자리에 걸린다.** dispatch 셋(`coverage-mapper` · `blind-spot-prober` ·
  `steelman-builder`)이 `<claims_contract>`·`<open_decisions>` 두 슬롯을 받고, C43 경로 (a) 자동확인은
  orchestrator 가 직접 수행한다(네 번째 dispatch 자리를 만들지 않는다 — 기본 탑재 subagent 는
  처분 락의 agent 집합 밖이라 앵커만 +1 되어 「앵커 수 == dispatch 수」가 red 가 된다).
- **검문소 셋.** V1(라운드 규약 안, 무조건 — 경로 → 앵커 → 「그 자리가 주장과 맞는가」) ·
  V2(`finishing.md`, 무조건, 누락 대조만) · V3(게이트, 형태 ∀). 앞 둘은 웹 스위치와 steelman
  trigger 에 종속되지 않는다.
- **state `orchestration.open_decisions[]`** — 인터뷰 중 결정의 유일한 거처이자 `OQ<n>` 의 산출자.
  해결된 결정도 지우지 않고 상태 토큰으로 구분한다. 초기값은 빈 목록이고(스키마의 항목 형식은 주석 —
  값으로 실으면 새 세션이 유령 `OQ1` 을 seed 한다), 라운드 규약의 «다음 결정» 템플릿 줄이 `OQ<n>:`
  자리를 싣는다(새 결정은 새 번호, 이어가는 결정은 기존 번호). dispatch 의 `<open_decisions>` 에는
  열린 것만 `OQ<n>: <한 줄>` 로 싣는다.
- **`derived:internal_research` admit** — 어느 자리든(경로 (a) · coverage-mapper · blind-spot-prober ·
  steelman) `repo_claims[]` 가 처음 산출되면 그 자리에서 원장에 admit 한다. 경로 (a) 에만 걸면 mapper
  첫 dispatch(D6 의무)가 먼저 RC 를 낸 인터뷰가 게이트에 막히고 유일한 탈출이 RC 삭제다.
- **게이트 술어 다섯** — 연결 ∀ · 연결 대상 실재 · 역참조 ∀(§3·§0 양쪽) · 이름 정확 일치
  `derived:internal_research` + `closed`(조건부) · 확인 줄 ∀. **차단 판정에 개수가 없다** — 전부 ∀ 이고
  순회 항목이 0건이면 공허 통과한다. 개수는 조건 분기와 advisory 에만 들어간다.
  - 결정 연결은 조사 항목 줄 끝의 **넷** 중 하나다 — 레포 `[RC<n> → OQ<n>]` · `[RC<n> → 없음]`, 웹
    `[→ OQ<n>]` · `[→ 없음]`. **레포 주장은 연결 안에 항상 `RC<n>` 을 싣는다** — `[→ 없음]` 으로만 쓰면
    RC 가 줄에서 사라져 확인 줄 ∀ · 이름 정확 일치 derived · V2 가 그 주장을 못 본다. 게이트가 이것을
    집행한다: `RC<n>` 을 실은 항목 줄에 웹 형식 연결이 붙으면 연결 ∀ 가 그 줄을 연결 없음으로 센다 —
    웹 형식이면 역참조 ∀ 의 요구가 통째로 빠지기 때문이다.
  - id 비교는 **토큰**이다 — 부분 문자열이면 `RC12` 가 `RC1` 역참조를 만족시켰다. id 의 끝 경계는
    `\b` 가 아니라 ASCII 낱말 문자의 부재라, 조사가 붙은 `RC3에` · `OQ1은` 도 그 id 로 읽는다.
  - 「그 `OQ<n>` 줄」은 **선두**가 그 `OQ<n>` 인 항목 줄이다(연결 대상 실재의 결정 선언도 같은 규칙).
    줄 중간의 `OQ<n>` 은 상호참조라 근거 id 를 요구받지 않는다 — 어디서든 언급한 줄로 읽으면 정직한
    상호참조가 red 였다.
  - 역참조 검사는 **반대 방향**도 본다 — §3·§0 이 가리키는 `RC<n>` 은 조사 항목(§4·§5)에 실재해야
    한다(`payload_rc_ids ⊇ 인용 RC`). 출처 없는 역참조 id 는 확인 줄 ∀ 의 순회 밖이라 아무 검사도 받지
    않았다. 게이트 문구는 두 방향을 담아 「역참조 불일치」다.
- **`contract: v2` 옵트인** — 술어 다섯이 이 frontmatter 필드가 있을 때만 발동한다. 기존 §4 보유
  픽스처 81개를 한 글자도 고치지 않는 장치이고, 없을 때는 advisory 「신 계약 미적용 brief」가
  Step B 게이트로 간다. 「내부 조사 0건」도 같은 채널이다 — 침묵과 0 은 다른 사실이다. 키가 **있는데**
  `v2` 로 읽히지 않으면(중복 키 · `V2` · 모르는 값) 부재가 아니라 red 다 — 부재로 읽으면 다섯 술어가
  조용히 꺼지고 advisory 는 「없다」고 오진한다.
- 락: `tests/test_research_claims_contract.sh` 여섯 축(A 산문 · B 양의 짝 · C 펜스 · X 차가운 셸
  실행 · D 정본↔사본 집합 등호 · E `fail-closed` 값). 축 E 가 처분 락의 공시된 한계(어휘만 보고 값을
  단언하지 않는다)를 이 자리에서 메운다. 게이트 술어 다섯의 mutation 매트릭스(g1–g8)로 이빨을
  실측했다 — g1(표기 · `$` 줄끝 앵커)·g7(⟨C5⟩ 개수 가드 삽입) 이 최초 toothless 였고
  `test_check_brief.sh` 단언으로 닫았다. g7 은 리터럴 임계값(`> 3`)에 맞춘 동적 단언 하나뿐이라
  다른 임계값(예: `>= 10`)엔 무력했던 것을 재비판이 드러내, 다섯 술어 함수 + 결정 판독 헬퍼 둘
  (`_declared_decisions` · `_leading_oq`) + `contract: v2` 분기 전체를 대상으로 하는 임계값-무관 정적
  AST 락(⟨C5⟩(정적) — `len()` 호출·정수 리터럴 비교 부재를 잰다)을 추가로 얹어 닫았다. 정적 락은
  슬라이스 truthiness(`lm and not lm[4:]`) 같은 임계를 못 보므로, 연결 누락 1·5·12 건을 모두 red 로
  요구하는 동적 짝을 함께 둔다. 변이 셀 헬퍼(`v2mut` · `v2frag`)는 변형기가 죽거나 아무것도 안 바꾸면
  그 셀을 실패로 센다 — 그러지 않으면 green 기대 셀이 원본 fixture 를 재며 공허하게 통과한다.

### Changed

- **dispatch 통제가 상한에서 «자격 + 예산»으로.** 자격 = 그 장치가 채우는 차원에 닿는 열린 결정이
  아직 있는가(열린 결정이 0이면 예산이 남아도 부르지 않는다) · 예산 = `1 + 재개방`.
  첫 dispatch 는 두 장치 모두 1회 필수이고 **자격을 보지 않는다** — 자격은 «다시» 부를 조건이다
  (blind-spot-prober 의 첫 dispatch 에 자격을 걸면 그 차원의 결정이 prober 출력 뒤에야 생기므로
  구조적으로 굶는다). 옛 문구
  (`상한 2` · `fan-out 1` · `인터뷰당 1회` · `bounded dispatch`)는 두 장치의 **열네 자리**에서
  교체했다 — 착수 시 grep 으로 전수 재도출했고 설계가 열거한 여섯은 `agents/` 만의 전수였다.
  엔진의 `재리뷰 상한 2` · 확정 재제시 `상한 2회` · `rhythm guard 3` 은 **다른 것을 세므로 건드리지
  않았다**.
- **C44 면제.** 산출 항목의 `decides` 가 `status: open` 이고 `touched: false` 인 결정을 하나라도
  담으면 `non_user_streak` +0, 아니면 +1. **순서가 계약이다 — 「계수 먼저, 표시 나중」**: 반대로 두면
  계수 시점에 「아직 안 닿은 것」이 항상 공집합이라 첫 연결부터 +1 이 되고 면제가 영구히 발화하지
  않는다. 면제 예산은 그 집합 크기로 유한하다.
- **처분 방향 셋이 `fail-open` → `fail-closed`.** 막는 것은 «그 dispatch» 이고 인터뷰가 아니다 —
  계약 펜스가 실패하면 그 장치를 부르지 않고, 인터뷰는 계속하며 그 차원을 자동으로 닫지 않고
  advisory 가 사람에게 간다.
- **`blind_spot_dispatched: bool` → `blind_spot_dispatches: int`** — 개명이라 값을 이월한다
  (`true → 1`, `false → 0`)고 옛 키를 지운다. 부재 키 규칙만 쓰면 이미 dispatch 한 세션이 `0` 을
  받아 AP16 가드가 재무장된다.
- 템플릿 둘이 세 방향을 예시로 보인다 — 템플릿이 red 를 가르치면 첫 게이트가 항상 red 다.
- SKILL.md 순감 래칫 둘을 순증 수용으로 다시 조였다(실측 + 8). 설계가 로드 표면 순증을 명시적으로
  수용했고 삭제가 0이다.

### Removed

- 리터럴 마커 `[from-code][auto-confirmed]` — 15사이클 0건이고 같은 행위가 audit §5 에
  `auto-confirmed:` 라는 다른 표기로 이미 실재했다. 갈라진 사본은 「한쪽만 고치는」 결함을 부른다.
  개념은 계약으로 흡수된다.

### 알려진 한계 (설계 §알려진 한계 전량이 그대로 유효하다)

- **조건부 발동이 피검자 산출물에 앵커돼 있다** — `RC<n>` 을 0건 내면 ①·②·④·⑤ 넷은 순회 항목·조건
  자체가 공집합이라 발동하지 않는다(공허 통과 또는 조건부 조기 반환). **③ 은 예외다** — forward
  (그 `OQ<n>` 줄이 근거를 되가리키는가)는 함께 잠들지만, reverse(§3·§0 이 인용한 `RC<n>` 이 조사
  항목에 실재해야 한다는 검사, Ruling 76)는 `payload_rc_ids` 가 공집합이어도 §3·§0 줄을 그대로
  순회하므로 계속 발동한다 — 출처 없는 RC 인용은 0건 상황에서도 잡힌다. `check_brief.py` 는
  brief 파일만 읽으므로(모듈 불변식) 「조사를 했어야 했는가」를 알 방법이 없다. backstop 은 0건
  advisory 가 Step B 게이트 텍스트로 사람에게 가는 것이다.
- **면제 판정은 자기 신고다** — `non_user_streak`·`touched` 는 세션 state 에만 살고 게이트는 state 를
  읽지 않는다. 이 릴리스가 더한 것은 산출자와 거처이고, 값이 정직한지는 여전히 모델의 자기 신고다.
- **「열려 있음」은 검사하지 않는다** — 연결 대상 실재는 목록에 있는가만 보고 상태 토큰은 보지 않는다.
  의도된 선택이다: 상태를 보면 결정을 해결하는 데 기여한 조사가 red 가 된다.
- **V1 의 3단계는 기계가 대신할 수 없다** — 「주장이 그 자리와 맞는가」는 내용 이해다. V2·V3 가 보는
  것은 「그 확인 줄이 항목마다 있는가」까지다.
- **정본과 사본이 둘 남는다** — 락 축 D 가 필드 이름 집합의 등호를 지키지만 **설명 산문의 갈라짐은
  못 잡는다**.
- **`derived` 행의 `closed` 요구는 「근거가 적혀 있는가」까지다** — `coverage_anchor_failures` 가
  form-only 라 실재하는 아무 `S<N>` 이든 받는다.
- **확인 판정이 두 자리에 기록된다** — steelman 경로는 audit §3(`ST<N>` 블록)과 §5(`확인 RC<n>`)에
  같은 판정을 적는다. 확인 «행위» 는 한 번이고 기록만 둘이다.
- **§H 표기층은 리뷰로 검증되지 않았다** — 설계 라운드 3 을 돌지 않았고, 이 릴리스의 red/green 짝과
  변이가 그 절의 유일한 검증이다.
- **§4 가 없는 payload 는 §5 의 `RC<n>` 줄 연결도 검사하지 않는다** — 연결 ∀ · 연결 대상 실재 · 역참조
  셋은 §4 와 §5 가 둘 다 있을 때만 돈다. §4 부재는 이미 다른 red(누락 절)라 게이트를 통과하지는 않지만,
  그 red 를 고치기 전에는 §5 연결의 결함이 함께 보고되지 않는다.

## [4.3.0] — 2026-09-24

minor 인 이유 — `shared/docreview/` 의 agent 표면(재비판자의 입력 슬롯)이 늘었다. 슬롯이 optional 이라 기존 dispatch 는 그대로 통과한다(major 아님).

### Added

- **`agents/doc-recritic.md` 에 `diff` 선택 슬롯**(`kind: repo_context`, `optional: true`) — 재비판자가 「이 변경이 도입했는가」 축을 쓸 수 있다(설계 §6.3.4, AC18). 페르소나 본문의 입력 목록도 `diff` 를 나열하고, 그것이 프레이밍이 아니라 그 축을 위한 **1차 자료**임을 명시한다. **이 플러그인의 문서 경로 — `reviewing-spec` · `reviewing-brief` · `framing-requests`, 세 dispatch 자리 전부 — 는 `diff` 를 싣지 않는다**고 그 자리에서 명시한다: 싣는 것은 코드 경로뿐이고, 못 받으면 재비판자는 그 축을 쓰지 않는다. 정본은 `shared/docreview/agents/doc-recritic.md` 이고 `plugins/spec-distill/agents/doc-recritic.md` 는 그 바이트 사본이다.

### Changed

- **`shared/adjudication/adjudication.py`(symlink 로 이 플러그인에도 배송되는 정본)의 `Ledger` 가 `items_unaccounted()` · `primary_source_failed()` 두 accessor 를 얻었다.** 기존 `blocks()` 는 그 둘의 `or` 로 **값 동치**(독립 진리표 대조) — `docreview_route.py` 등 다른 소비자는 안 깨진다.

## [4.2.4] — 2026-09-24

patch 인 이유 — 보안 수정이다. 절대 경로 항목만 있는 PATH 에서는 고르는 인터프리터가 전과 같다.

### Security

- **훅 해석기가 PATH 의 절대 경로가 아닌 항목을 통해 작업 디렉토리의 파일을 실행했다.** 빈 항목 · `.` · 상대 경로 · 빈 PATH 는 셸이 cwd 로 풀고, 훅의 cwd 는 사용자가 연 리포다. 그런 PATH 를 가진 사용자가 공격자가 만든 리포를 열면 `SessionEnd` 에서 리포 안의 `python3` · `python3.<무엇이든>` 이 실행됐다(격리 재현). `scripts/devbrew-python.sh` 의 두 탐색 — 2단계 `python3` 와 3단계 `python3.*` 글롭 — 이 이제 절대 경로 항목만 본다. `hooks/hooks.json` 의 자리도 해석기를 bare `sh` 대신 `/bin/sh` 로 부른다 — bare `sh` 도 같은 탐색으로 cwd 의 `sh` 를 집었다.
- **대가** — PATH 에 상대 경로나 따옴표 안의 `~`(전개되지 않은 틸드)로 인터프리터를 두던 사용자는 훅이 그것을 못 찾는다. `$DEVBREW_PYTHON` 에 절대 경로를 지정하라.
- **범위** — 훅 command 의 `sh` 탐색과 해석기가 인터프리터 파일을 고르는 탐색만 닫는다. 고른 인터프리터가 `#!/usr/bin/env` shim(pyenv · asdf)일 때 그 안의 탐색과, 그런 PATH 가 devbrew 밖에서 이미 여는 노출은 이 수정 밖이다. 설계 `docs/superpowers/specs/2026-09-23-python-resolver-absolute-path-only-design.md` 의 L4 · L7.

## [4.2.3] — 2026-09-24

patch 인 이유 — 이미 적혀 있던 회계 계약(「항목이 소실되면 막는다」)이 한 경로에서 집행되지 않던 결함의 수정이다. 새 필드·새 surface 없음. **다만 동작이 바뀐다** — 아래 첫 항목.

### Fixed

- **critic·codex 의 파손 항목이 계수 없이 사라져 `blocks` 가 거짓이었다.** `cmd_prepare` 는 두 출처의 항목을 `normalize()` 로 정규화하며 원장을 직접 넘겼는데, `cmd_finalize` 는 prepare 가 `events` 로 기록한 호출만 재생한다. 그래서 `normalize()` 의 `hold`(anchor·summary 없는 파손 항목)와 `coerced`(어휘 밖 처분)가 프로세스 경계에서 사라졌다 — 실측 `held=0 · coerced=0 · blocks=False`. 회계 계약은 `blocks() == held > 0 …` 이므로 이것은 차단 통제의 fail-open 이었다. 4.2.1 의 「Known gaps」 가 disposition 강제 하나로 적었던 결함이 실제로는 파손 항목의 소실까지 포함했다. `normalize()` 에는 이제 `hold`·`coerced` 두 이름만 가진 기록 원장을 넘긴다(`ev()` 와 같은 메커니즘 — 다른 메서드를 부르면 조용히 사라지지 않고 `AttributeError` 로 죽는다).
  - **달라지는 동작:** critic 이든 codex 든 파손 항목을 하나라도 내면 `finalize` 의 보고(`fin.json`)가 이제 `blocks: true` · `adjudication_held ≥ 1` 이고 `advisory` 에 「항목 파손」이 실린다. 보조 출처(codex)의 파손도 같다 — 계약의 「항목이 소실되면 막는다」에 출처 예외가 없다(사용자 결정). **바뀐 것은 이 보고 필드까지다** — 게이트 요약(`approval_ready` · `round_reviewed`)은 held 를 읽지 않으므로, 막는 것은 `fin.json` 의 `blocks` 를 읽는 오케스트레이터다(skill 의 degrade 채널 절이 그것을 읽으라고 요구한다).
  - **남은 공시 공백(고치지 않음):** codex 가 없는 라운드에서는 게이트 렌더 첫 줄이 `codex 없음` 을 `advisory` 보다 앞서 싣고 끝나, 같은 라운드의 「항목 파손」이 그 줄에 안 보인다(`docreview_state.py` 의 `render_gate`). 정보는 `fin.json` 의 `advisory[]`·`blocks` 로는 닿는다. 층 2 `uncountable` 과 재비판 unknown-f hold 에 이미 있던 가림이고, 이 수정이 그 경로를 더 자주 태운다.
  - 락 — `normalize()` 호출 자리 셋(critic 층 1 · 층 2 · codex)에 파손 항목을 하나씩 두어 `held == 3` 을 잰다. 한 자리만 원장 직결로 되돌려도 떨어진다. 어휘 밖 처분은 재비판이 처분을 **직접** 매기게 해 `_apply_recritic` 의 `None → "ask"` 스윕이 가려 주지 못하는 경로에서 `coerced == 1` 을 잰다. 변이 다섯(자리 셋 각각 · `hold` 미기록 · `coerced` 미기록)이 전부 RED.
- 사실과 어긋나게 된 주석 넷(미계수 마커 · 「경계를 못 넘는다」 설명 셋)을 고쳤다. `tools/adjudication/check_wiring.py` 의 EXEMPT 열 자리를 재앵커했다(가드 텍스트·사유 무변경).

## [4.2.2] — 2026-09-23

patch 인 이유 — 전부 `Fixed` 다. 새 필드·새 surface 없음.

### Fixed

- **codex 쪽 finding 이 `replacement`·`if_unfixed` 를 늘 잃었다.** 러너 프롬프트는 `decide` 에 두 칸을 요구하는데, 출력이 지나는 `codex_findings_to_yaml.py` 의 닫힌 키 목록 `DOCREVIEW_KEYS` 가 그 둘을 몰라 변환에서 버렸다. codex 가 값을 적어도 게이트는 「(대체안 미작성)」·「(리뷰어가 안 적음)」을 냈다 — 4.2.1 이 후속 finding 에서 닫은 것과 같은 뒤집힘(값이 있는데 침묵 리터럴)이 codex 입구로 들어오고 있었다. Task 20 e2e(과설계 셋을 심은 설계문서)에서 critic·codex 둘 다 셋을 맞는 태그로 잡았는데 게이트의 `overdesign` 셋이 전부 대체안 없이 떴다.
- **`same_as` 흡수가 흡수된 쪽의 산문 칸을 함께 버렸다.** 생존자는 (처분 순위, f 번호) 최대이고 f 번호는 요약 sha1 순이라 출처와 무관하게 갈린다 — 한쪽만 `replacement`·`if_unfixed`·`evidence` 를 적었는데 빈 쪽이 남으면 값이 사라졌다. 생존자 선택 규칙은 그대로 두고(변이 ⑩ 이 그 줄을 잡는다) 생존자의 **빈 칸만** 형제에게서 채운다. 적힌 칸은 덮지 않는다. 위 결함만 고쳐도 e2e 증상은 사라지지만 이 결함은 「한쪽만 칸을 가진 쌍」에서 잠복한다.

락 — `test_codex_findings_to_yaml.py` 가 `└ 천장: …`(`: ` 를 품는 값)을 넣어 파서로 **바이트 그대로** 되읽는다. `test_docreview_route.sh` 는 두 요약을 맞바꿔 두 번 돌려 빈 쪽이 생존자인 방향을 반드시 태우고, 그 방향이 실제로 돌았는지를 따로 단언한다. 변이 셋(덮지 않음 가드 제거 · 채움 제거 · `if_unfixed` 만 빼기)이 전부 RED. 헬퍼는 서브셸 없이 부른다 — `$( )` 안의 실패 계수는 사라져 첫 초안이 ✗ 를 찍고도 스위트 rc 0 이었다.

`tools/adjudication/check_wiring.py` 의 EXEMPT 여덟 자리를 +8 재앵커했다(가드 텍스트·사유 무변경). 채움을 `break`·필터 컴프리헨션 없이 쓴 이유는 그 둘이 각각 새 미배선 버리기·컴프리헨션 내포 증가로 잡혔기 때문이다 — 아무것도 버리지 않지만 면제·baseline 을 늘리는 대신 모양을 바꿨다.

## [4.2.1] — 2026-09-23

patch 인 이유 — 전부 `Fixed` 다. 새 필드·새 커맨드·새 surface 는 없다. 하나 새
행동처럼 보이는 것(필드 값의 공백을 뭉치고 그 강제를 계수하는 것)은 프로필이
이미 말하던 규칙(「한 줄, 개행 없이」)을 아무것도 강제하지 않던 자리에 강제를
채운 것이라 결함의 수정이지 새 능력이 아니다. 4.2.0 이 새로 들인 갈래 2 필드
(`replacement`·`if_unfixed`) 가 실제로 쓰이기 시작하면서(PR 4 종단 리뷰) 갈래
사이 이음매에서 드러난 결함 일곱을 닫는다 — 사람이 손으로 고쳤다면 놓쳤을
자리들이다.

### Fixed

- **escalated·reraise 후속이 `replacement`·`if_unfixed` 를 잃어 리뷰어의 판단을 침묵으로 오독시켰다.** `docreview_route.py` 의 `_auto_decides` 가 짓는 escalated·reraise 두 후속 dict 는 원본 finding(f0)에서 layer·category·anchor 등 여덟 필드를 물려받지만 `replacement`·`if_unfixed` 는 빠져 있었다 — 이 dict 들은 `normalize()` 를 거치지 않으므로 두 키가 아예 존재하지 않았고, 렌더는 「값이 있는데 못 읽었다」를 「(대체안 미작성)」(리뷰어가 정말 아무것도 안 쓴 경우의 리터럴)으로 냈다. 침묵과 판단이 다르게 읽혀야 한다는, 이 기능 전체가 존재하는 이유인 그 계약을 후속 항목에서 다시 깬 것이다. `f0.get("replacement")`/`f0.get("if_unfixed")` 로 원본 값을 잇고, `test_docreview_route.sh` 에 두 락(`case_I1_escalated_carries_replacement_fields`·`case_I1_reraise_carries_replacement_fields`)을 추가 — reraise 쪽을 escalated 와 별도로 덮는 이유는, 출시된 `overdesign` 축이 `decide` finding 만 내고 escalate 경로를 안 타 그쪽 락이 혼자서는 못 잡기 때문이다. 골든 픽스처(`case_T22_reraise_appears_in_next_round.fin.json`)도 두 키를 null 로 내도록 재생성했다(`normalize()` 가 부재를 null 로 내는 것과 같은 스키마).

- **처분 안내 · agent persona 사본 넷 · codex 프롬프트가 갈래 2 이전 필드 사상을 가리키고 있었다.** `design-doc.md` 의 처분 안내 줄이 「변경 내용 · 근거 · 대안 · 영향을 summary/evidence 에 채운다」는 옛 문구 그대로였는데, 몇 줄 위 필드 사상은 이미 대안을 `replacement` 로, 그대로 두면 남는 결과를 `if_unfixed` 로 보낸다 — 옛 문구를 따르면 대안이 summary 에 뭉쳐 게이트가 헤더에 문제+대안을 욱여넣은 채 「고치면: (대체안 미작성)」을 낸다(바로 위 항목과 같은 부류의 역전). `brief.md` 는 같은 어휘의 처분 안내 줄이 없어 대응하는 결함이 없다 — 확인만 하고 손대지 않았다. `shared/docreview/agents/{doc-critic,doc-critic-web}.md` 와 그 copy-of 사본(`plugins/spec-distill/agents/{doc-critic,doc-critic-web}.md`, byte-identical) 네 벌도 전부 `summary` 에 **변경 내용**을 담으라고 했다 — 그 항목은 이제 렌더에 없다. 네 파일 모두 `evidence`·`replacement`·`if_unfixed` 세 칸으로 고쳤다. `run_docreview_codex_reviewer.sh`(symlink, `quality-gates` 도 동일 파일을 심볼릭 링크로 배송)의 codex 프롬프트에 낀 콤마 스플라이스도 마침표로 갈랐다.

- **`replacement` 는 한 줄이라야 하는데, 그 규칙 바로 위 템플릿 자체가 두 줄이었다.** `brief.md`·`design-doc.md` 두 프로필의 판정 한 줄 펜스가 대안 줄 + 들여쓴 `└ 천장` 줄의 두 줄 모양이었던 반면, 바로 아래 필드 사상 문단은 둘을 `replacement` 에 한 줄·개행 없이 실으라고 했다 — 펜스를 그대로 베끼면 그 모순이 실제 개행으로 나타나 렌더의 여섯 줄 게이트 블록이 여덟 줄이 되고 `└ 천장` 조각이 다음 줄 첫 칸에 떨어져 최상위 게이트 줄과 구별되지 않는다. 펜스를 `<대안>. └ 천장: <조건>` 한 줄로 합치고, 「└ 들여쓰기는…」 문구도 더 이상 없는 들여쓰기를 안 가리키게 고쳤다. `test_overdesign_rubric.sh` 에 펜스가 실제로 한 줄인지 재는 락 둘을 추가(옛 두 줄 모양으로 RED, 고친 모양으로 GREEN 실측). 엔진 쪽 강제 — 값을 한 줄로 뭉치고 그 강제를 계수하는 것 — 은 `quality-gates` `[8.2.1]` 참조(심볼릭 링크로 양쪽에 같은 파일이 나간다).

- **AC7·AC11 배너가 이름과 실측 사이가 벌어져 있었다 — mutation 으로 증명.** AC7(「판정 한 줄의 형식」)은 `└ 천장` 잔해 유무 하나만 쟀다 — 템플릿 줄(`<앵커>: <태그> <무엇이 과한가>. <더 단순한 대안>.`) 을 통째로 지워도 「└ 천장」 잔해만 남으면 그대로 통과했다. AC11(「상한 N=3 과 그 근거」)은 숫자도 근거 문장도 안 읽어 「3건」→「30건」과 근거 문장을 통째로 지워도 통과했다. 템플릿 다섯 슬롯(`<앵커>`·`<태그>`·`<무엇이 과한가>`·`<더 단순한 대안>`·`<이 판정이 틀릴 조건>`) 개별 실패로, 상한 숫자는 부분 문자열로 안 걸리는 `has … '3건'` 로, 근거는 결론절 「한 호출을 혼자 채우지 못한다」로 각각 핀. 두 mutation 모두 옛 배너로는 GREEN, 새 배너로는 RED 를 실측했다 — 프로필 파일 자체는 이미 옳은 모양이라 손대지 않았다.

- **AC18′ 첫 절(같은 anchor 항목이 인접해 묶음 마커를 갖는다는 보장)을 철회하고, 같은 자리의 사실 오류 둘을 고쳤다.** `GATE_ROWS` 를 정렬하는 id prefix 가 `(layer, category, anchor)` 의 sha1 추첨이라, 같은 anchor 라도 category 가 다르면(overdesign·architecture 조합이 가장 흔한 입력) 인접이 보장되지 않는다 — 보장하려면 게이트를 재정렬해야 하는데 그것은 「오케스트레이터가 새 순위를 매기지 않는다」는 원칙과 부딪힌다. 사용자는 재정렬 대신 AC18′ 첫 절 철회를 선택했다(둘째 절 — 질문 수·선택권 불변 — 은 그대로 선다. 설계 결정 기록에 P23 재결정으로 기록). 뒤이은 수정이 같은 자리의 사실 오류 둘을 고쳤다 — 두 트리에서 서로 다른 줄(이 브랜치 91, origin/main 85)을 가리키던 인용을 다음 편집에서도 안 썩게 `_bucket()` 심볼 인용으로 바꾸고, 「인접하지 않은 항목은 절대 마커를 안 갖는다」는 거짓 전칭부정을 재리뷰의 구성적 반증(#2-goals 에 열린 항목이 overdesign·architecture 둘뿐이면 인접이 강제돼 마커가 붙는다)으로 잡아낸 뒤 참인 약한 문장(「인접이 보장되지 않는다」)으로 교체했다. AC19′·AC19″ 의 다른 줄 인용은 범위 밖이라 손대지 않았다.

### Known gaps

- **`normalize()` 의 disposition 강제가 critic/codex 경로에서 여전히 소실될 수 있다 — 오늘의 마스킹은 보장이 아니다.** `ledger.coerced("disposition", disp, None)` 은 `cmd_prepare` 의 Ledger 로 불려 그 라운드 events 만 `cmd_finalize` 로 넘어가는 탓에 조용히 소실된다 — `replacement` 강제가 가졌던 것과 같은 경계 결함이다(위 항목). 오늘은 `_apply_recritic` 의 무조건 `None → "ask"` 루프가 우연히 가리고 있을 뿐이고, 재비판 verdict 가 아직 None 인 항목에 처분을 직접 매기는 경로에서는 그 루프가 안 돌아 계수가 **0 으로 끝난다** — 과소집계가 아니라 총 소실이다. 결함 자리에 발견 마커만 달았고 행동은 바꾸지 않았으며 락도 추가하지 않았다 — `ev()` 래퍼로 옮기는 것은 prepare→finalize 계약을 바꾸는 별도 작업이고, 지금 락을 추가하면 알려진 결함을 의도된 것처럼 고정하게 된다.
- 이번에도 `tools/adjudication/check_wiring.py` 의 줄-핀 EXEMPT 키 열 자리가 재앵커됐다(주석 6줄이 밀어 전부 이동, 가드 텍스트·사유는 무변경) — 이 기능에서 벌써 네 번째다. 줄번호로 면제를 고정하는 방식의 상시 세금으로 기록해 둔다.

## [4.2.0] — 2026-09-23

minor 인 이유 — 새 surface 가 하나다: 두 문서 자리(`brief.md`·`design-doc.md`)의
`layer_rubric.layer1` 에 축 `overdesign` 이 늘어(brief 1→2, design-doc 8→9) 리뷰어가 받는 계약이
바뀐다. 설계 `docs/superpowers/specs/2026-09-21-designer-lens-review-design.md` §5.1~§5.6.

### Added

- **새 축 `overdesign`.** 두 문서 자리 모두에 신설. **실측** — design-doc 기존 여덟 축은
  프로필 본문을 읽으면 전부 「맞는가」 방향(정렬·정합·준수·폐쇄·존재)이고, 새 축의 술어 셋(①
  과함 · ② 왜곡 · ③ 층위 이탈)과 겹치는 자리는 정확히 둘뿐이다 — `data_flow` 의 「소비자 없는
  산출물」이 ponytail `delete:` 와, 층 2 `scope_creep`(분해 안 되는 묶음)이 「과함」과 부분적으로
  겹친다. 절차를 얹어도 「같은 것을 겨누는가」에서 「goal 에 비해 과한가」는 안 나온다(§1.1).
  ★ **두 자리에서 술어 ① 의 기준은 같은 모양이다** — 「**상류가 말한 goal** 대비 과한가」.
  brief 의 상류는 사용자 원문, design-doc 의 상류는 브리프 §1 Goal 이라 **상류만 다르다**(§5.1).
- **술어 ② 는 brief 자리에 없다** — 그 술어의 대상은 구조·구현이고 brief 자리에는 그것이 없다
  (D11). brief 는 ①③ 만, design-doc 은 ①②③ 전부를 갖는다.
- **태그 다섯**(`delete:`·`yagni:`·`shrink:`·`bent:`·`altitude:`) — 셋(`delete:`·`yagni:`·
  `shrink:`)은 ponytail(`DietrichGebert/ponytail` HEAD `e3ba2aa`)에서 그대로 가져왔고, 둘
  (`bent:`·`altitude:`)은 이 리포에서 만들었다. **「외부에 없더라」는 측정이고 「그러면 리포에서
  만든다」는 결정이다** — ponytail 저장소 전수 grep 이 술어 ②③ 의 판정 기준을 0건으로 확인했고
  (측정), 그 근거로 ②③ 을 리포 자신(D22 · CLAUDE.md Forbidden Patterns · design-doc 층 2
  `testing` 의 반대 방향)에서 만들기로 한 것은 별도의 선택이다. 이것은 브리프 C26 의 확정
  (「과설계 판정 기준을 외부 자료를 전문 조사해 끌어온다」)을 근거를 대고 뒤집은 **P23 재결정**으로
  기록했다 — 설계 [결정 기록](../../docs/superpowers/specs/2026-09-21-designer-lens-review-design.md#결정-기록)
  표 세 번째 행, 사용자 동의 2026-09-21(리뷰 라운드 1 · D1.7).
- 판정 한 줄의 형식(`<앵커>: <태그> <무엇이 과한가>. <더 단순한 대안>.` + `└ 천장:`), 금지 어법
  (헤지형 의문문 금지), Lazy Ladder 문서판 5단(ponytail 7단 정본을 문서 자리로 접음, 「성립하는
  첫 단에서 멈춘다」), 오탐 가드 여덟(ponytail 다섯 + 재논쟁 금지 + 「사다리는 해답을 줄이지
  읽기를 줄이지 않는다」 + 스코프 배제), 상한 N=3.
- **사다리의 "higher rung" 모호성을 이 설계가 정의한다.** ponytail 원문 `Two rungs work → take
  the higher one` 은 「higher」의 방향이 저장소 어디에도 정의돼 있지 않다(전수 grep 확인). 이
  설계는 **번호가 작은 쪽**(더 많이 자르는 해석)을 채택했다 — 「첫 단에서 멈춘다」와 일관되기
  때문이다. **그 대가** — 작은 쪽은 언제나 더 많이 자르는 해석이라 동점마다 판정이 절감 쪽으로
  기울어 §7·OQ-E 의 「한 방향 압력」을 **증폭한다.** 균형 장치는 `└ 천장` 하나뿐이고, 그것은
  줄임을 되돌릴 조건을 적을 뿐 줄임 자체를 막지 않는다(§5.3). 이 비대칭은 이번 설계에서
  해소되지 않는다.
- **0건 출구는 ponytail 원문의 부분 이식이다.** `overdesign` finding 이 하나도 없으면 「이
  문서는 이미 최소다.」 한 줄만 적고 정당화를 붙이지 않는다 — 여기까지는 원문 그대로다. 원문의
  `... and stop.` 은 **가져오지 않는다** — `doc-critic` 은 `docreview-layer1`·`docreview-layer2`
  두 sentinel 블록을 항상 내야 하고, 층 1 이 비면 엔진이 `critic_dead`(주 판정자 사망)로 읽어
  라운드가 「미검증」으로 닫힌다(`docreview_route.py:156-168`). 과설계가 0건이어도 기존 축의
  결함은 있을 수 있으므로 0건 규약은 「이 축의 finding 을 지어내지 않는다」로만 한정하고, 리뷰
  자체를 끝내는 `and stop.` 의 의미는 이 자리에 없다(§5.4).
- **상한은 판정자별이고 라운드 총량을 약속하지 않는다.** N=3 은 한 판정자가 한 라운드에 낼 수
  있는 이 축의 finding 수다 — 게이트가 `AskUserQuestion` 을 4개씩 나눠 부르므로 3 이면 판정자
  하나가 한 호출을 혼자 채우지 못한다는 근거다. 총량은 **2N+α** 다(판정자 둘이 각 3건이면
  6건이라 한 호출의 질문 네 개가 전부 이 축일 수 있다) — 게이트는 상태 범주·id 순으로만
  정렬하고 축별 자리를 예약하지 않는다. **이 상한을 강제하는 기계는 없다** — 프로필
  frontmatter 에 담을 필드가 없어 강제 없는 rubric 산문으로만 존재한다(§5.4).
- **`layer1:` 은 한 줄로 적는다 — 줄바꿈이 판정자 하나를 조용히 끈다.** codex 러너의 프로필
  파서는 줄 단위(`run_docreview_codex_reviewer.sh:302` 의
  `re.fullmatch(r"  ([a-z_][a-z0-9_]*): (.+)", line)`)이고, 이어진 줄은 `line outside the line
  grammar` 로 rc 5 `profile_parse_ambiguous` 다. T13 의 `lay_of` 도 `head -1` 이라 첫 줄만 읽어
  축을 덜 잰다. 반면 Python 게이트는 PyYAML 이라 **통과한다**(`docreview_state.py:120-126`).
  즉 줄바꿈 하나로 codex 축만 죽고 락은 조용히 덜 재는데 Python 쪽은 GREEN 이라, 그 죽음이 §7
  위험의 「축이 무이빨」 오진으로 읽힌다. 현행 네 프로필은 전부 한 줄이다(§5.1).
- **T13(`test_brief_review_ng3.sh`)을 부재 열거(금지 셋) → 허용 목록으로 전환한다 — fail-open
  이었던 것을 fail-closed 로 바꾼다.** 옛 판정은 `goal_fit`·`architecture`·`tradeoffs` 셋만
  금지해 나머지 다섯 축(`problem_definition`·`scope`·`component_relations`·`data_flow`·
  `feasibility`)이 brief 자리에 새어 들어가도 무언이었다. 새 단언 ④가 `brief 층1 ∩ design 층1
  ⊆ SHARED` 를 허용 목록으로 재고 `SHARED = {overdesign}` 을 락 파일에 명시 열거한다 — 목록
  밖 공유는 전부 걸린다. 새 단언 ⑤는 `SHARED` 의 각 축이 두 프로필 본문에서 서로 다른
  문장으로(자기 상류를 기준어로 — brief 는 「사용자 원문」, design-doc 은 「브리프 §1 Goal」)
  정의됨을 잰다. **⑤ 의 한계** — 리터럴 핀이고 **바이트를 잰다.** 두 불릿을 무의미하게 다르게
  써도 통과하고, 잡는 것은 한쪽을 다른 쪽에 통째로 베껴 넣는 것뿐이다. 의미는 못 잰다(§5.6).
  기존 단언 ①②③ 은 그대로 남는다.
- `shared/tests/test_docreview_profile_schema.sh` 는 프로필에서 도출한 이름 전부에 사상이
  있는가만 재므로 `overdesign` 이 두 자리에 실려도 새 RED 를 내지 않는다.

### Known gaps

- **계측기 부재(OQ-A).** 게이트 회계에 「열린 `decide` 수」도 「카테고리별 수」도 없다. **이
  변경이 무엇을 바꿨는지 원리적으로 못 잰다** — 사전 baseline 없이 두 갈래(축 신설 · 렌더 밀도)를
  한꺼번에 고치면 증거가 사후 인상뿐이고, 그 인상은 아래 수용률 역설로 낙관 편향된다. 계측 칸
  추가는 이번 범위 밖(브리프 S5).
- **수용률 역설(OQ-F).** 설명이 좋아지면(갈래 2) 팀 정확도가 아니라 AI 제안의 **수용률**이
  오른다(«bansal-chi2021» «automation-bias»). 갈래 2 의 성공이 갈래 1(새 축)의 판정을 무르게
  만들 수 있고, 「멈칫」이 사라진 것이 판단이 좋아진 신호가 아닐 수 있다 — 두 goal 이 독립이라는
  전제가 여기서 깨진다. 완화 불가. 측정 수단은 OQ-A 에 종속.
- **한 방향 압력(OQ-E).** 사다리는 「쓰인 것」에만 적용되어 판정이 항상 「줄여라」로 나고
  과소설계는 원리적으로 못 잡는다. ponytail 원문도 한 방향이고 균형을 리뷰어 **밖**(빌드
  페르소나의 하한선 + 다른 패스로의 라우팅)에서 잡는다. 이 설계는 `└ 천장` 장치로 리뷰어
  **안**에 일부를 들이는데 **검증된 선례가 없다.**
- **rubric 항목 수 증가(OQ-G).** design-doc 은 이미 층 1 아홉 + 층 2 일곱이 된다. 체크리스트
  항목 수를 늘리면 평가자 간 신뢰도가 떨어진다(«checklist-length-reliability») — 그 임계가
  어디인지 이 변경은 모른다.
- 그 밖에 이 PR 이 닫지 않는 것 — 반증 불가 축(OQ-D, `doc-recritic` 은 `reject` 에만 문서 내
  인용을 요구하는데 「이건 과설계다」는 문서 내용으로 반증되지 않는다) · 상한의 무이빨(강제하는
  기계가 없다) · T13 ⑤ 의 바이트 판정 한계(위 참조) · 설치 캐시(실행 시 agent 정의는 리포가
  아니라 설치 캐시에서 온다 — 이번 태스크 범위 밖, 다음 태스크에서 확인).

## [4.1.0] — 2026-09-22

minor 인 이유 — 새 surface 가 둘이다: 리뷰어 출력 스키마의 칸 둘(`replacement`·`if_unfixed`, `doc-critic`·`doc-critic-web`·`doc-recritic` 세 에이전트 + codex 러너 프롬프트)과 `disposition_lines()`(공유 `shared/adjudication/render_disposition.py`, 심볼릭 링크로 배송)의 4-튜플 반환. 후자는 호출 계약이 바뀐다 — 위치 언패킹이 깨진다(기존 3-튜플 언패킹은 `ValueError`). 다만 이 플러그인 자신은 그 함수의 호출자가 0 이고(소비자 셋은 전부 `plugins/quality-gates/scripts/`, 전문은 `plugins/quality-gates/CHANGELOG.md` `[7.7.0]`), `shared/adjudication/` 은 배포 심볼릭 링크로만 나가 외부 플러그인이 부를 표면이 아니므로 이 플러그인 쪽에서 깨지는 외부 계약은 없다. 설계 `docs/superpowers/specs/2026-09-21-designer-lens-review-design.md` §5.7·§5.8·§5.9·§6.

### Changed

- **decision_view 의 동어반복 제거.** 「변경」 줄은 `it["summary"]` 였고 헤더가 이미 그 문자열을 냈다 — 정보량 0 인 줄이었다. 대신 `replacement`(「고치면 무엇이 되는가」)·`if_unfixed`(「그대로 두면 무엇이 남는가」) 두 칸을 낸다. 부재 리터럴 둘은 **다르게** 둔다 — 침묵(「(대체안 미작성)」·「(리뷰어가 안 적음)」)과 판정(「대체안 없음 — 그냥 뺀다」, 리뷰어가 그 문자열을 실제로 냈을 때만)은 다른 사실이라, 같은 글자로 메우면 아무도 제안하지 않은 삭제가 제안으로 전달된다.
- **`PUBLIC_FIELDS`(`docreview_state.py`)에 `replacement`·`if_unfixed` 를 top-level 로 추가.** 닫힌 열거가 셋이다 — `PROFILE_FIELDS` · `normalize()` 반환 · `PUBLIC_FIELDS`. 앞의 둘만 고치면 새 칸이 렌더까지는 가도 원장에 안 남아 다음 라운드가 못 본다. `decision_view` 통로는 `disposition == "decide"` 에만 열리므로(`docreview_route.py` 의 `_remap_blocks`, decide 분기에서만 `_decision_view()` 를 부른다) 그쪽에만 실으면 `fix`·`defer`·`ask` 로 난 항목의 대체안이 원장에 한 글자도 안 남는다.
- **선택지 라벨이 상태의 함수가 됐다** (`choice_label(choice, kind)`). `cmd_decide` 가 `kind == "post"` 인 finding 의 `reject` 선택에 `kind: "revert"` permit 을 만들므로(그 자리에서 「그대로 둔다」는 실제로는 원복이다) 상태를 안 가리는 고정 라벨은 그 자리에서 동작을 **반대로** 설명하고 있었다(codex 단독 적발) — 그 결함을 고치는 김에 새 결함을 만드는 길이었다. 라벨 리터럴은 `choice_label()` 한 곳에만 산다 — 이전엔 아홉 자리에 복제돼 있었다.
- **게이트 「자리」줄에 category 사람말을 붙인다** (`CATEGORY_GLOSS` · `category_gloss()`). 사상 코퍼스는 **네 프로필(brief·design-doc·seed·generic)의 층 1·2 축 전부 + 엔진이 직접 만드는 category**(`frozen_change`·`other`) 다 — 렌더가 프로필별이 아니라 엔진 하나뿐이라, 두 프로필로 좁히면 가장 흔한 항목(`frozen_change`)이 상시 advisory 경로가 된다. 사상 없는 category 는 원래 이름을 그대로 내고 `category_unglossed` 로 그 사실을 공시한다(조용히 빈칸으로 두지 않는다). `CATEGORY_GLOSS` 는 `overdesign` 을 **이미** 담고 있는데, 그 축을 선언하는 프로필은 아직 하나도 없다 — 그 축을 더하는 후속 PR 이 `docreview_state.py` 를 0줄 건드리고도 단독 머지되게 하기 위해서다. 여분 항목은 무해하다: `test_docreview_profile_schema.sh` 는 ∀(프로필에서 도출한 이름 전부에 사상이 있는가) 만 재고, 사상에 프로필보다 많은 이름이 있는 것은 그 축의 부정이 아니다.
- **「대안」줄을 조건 없이 낸다.** `shared/tests/fixtures/docreview/cases.sh` 의 「제안 = 수용」 락이 이 줄의 존재를 발동 조건으로 쓴다 — 사라지면(예: 대안이 비었다고 줄 자체를 생략하면) 그 단언이 평범한 open·재상승 항목에 대한 렌더-측 채널을 통째로 잃는다.
- **게이트 머리에 순서의 뜻을, 같은 자리 항목에 묶음 표시를.** `GATE_ROWS` 10행은 이미 결정론이지만 «상태 범주» 순이라 그 뜻이 안 보였다 — 순위를 새로 매기지 않고(오케스트레이터가 순위를 매기면 그 자체가 판단이고 사용자가 그 위험을 받아들인다고 말한 적이 없다) 있는 순서의 뜻만 한 줄로 낸다(「열린 결정 먼저 · 그다음 관측 대기 · 막힌 것 · 미적용 수정 · 질문」). 같은 자리를 건드리는 연속 항목은 「같은 자리」로 묶어 «표시»만 한다 — 질문 수도 항목별 선택권도 안 바꾼다.
- **`AskUserQuestion` 라벨의 항목별 내용을 규약으로 못 박았다** (`reviewing-spec` `## 게이트`). 상태별 라벨만 담으면 같은 라운드의 여러 항목이 전부 같은 글자가 되어 「라벨만 읽고 고른다」가 원리적으로 안 닫힌다 — 라벨은 상태별 라벨 + `replacement` 1–5 낱말 압축이고, 같은 라운드의 두 항목은 같은 라벨을 갖지 않는다(둘 다 부재면 부재 건수를 공시해 규약이 공허해지지 않게 한다). **한계 공시** — 이 규약을 재는 락(`shared/tests/test_docreview_round_gate_split.sh`, AC17″)은 규약의 실재(문구가 절차서·SKILL 본문에 있는가)만 재고, 오케스트레이터가 런타임에 그 규약을 실제로 지키는지는 못 잰다. 라벨을 짓는 것은 엔진이 아니라 런타임의 오케스트레이터다.
- `doc-critic`·`doc-critic-web`·`doc-recritic` 출력 스키마에 `replacement`·`if_unfixed` 두 칸을 추가(에이전트 정의). `added` 항목(재비판이 새로 낸 finding)도 같은 `normalize()` 를 지나므로 두 칸을 실을 수 있는데, 에이전트 본문에 안 적으면 그 경로가 대체안 없이 렌더로 간다.
- codex 러너 프롬프트(`run_docreview_codex_reviewer.sh`)가 출력 형식 예시에 `replacement`·`if_unfixed` 를 요구한다 — codex finding 도 Claude 쪽과 같은 `normalize()` 를 지나 같은 두 칸을 낼 수 있는데, 프롬프트에 적어야 실제로 난다.
- 엔진 링크(`scripts/{docreview_state,docreview_route,run_docreview_codex_reviewer.sh}` · `scripts/{adjudication,render_disposition}.py`, 전부 심볼릭 링크)가 위 전부와 `render_disposition.py` 의 4-튜플 반환을 함께 나른다(cache key) — 후자는 이 플러그인의 호출자가 여전히 0 이다.

### Fixed

- **`case_decision_view_absence_is_literal` 가 실제로 T35 시퀀스를 타지 않던 결함.** 케이스 주석은 "route_r1 → next_round → ..." 라고 적었지만 코드는 bare `r1` 을 불러 round 1 을 전혀 finalize 하지 않고 건너뛰었다 — 엔진이 실제 운용에서 도달할 수 없는 상태(round 1 미완결)를 테스트하고 있었다. `route_r1` 로 교체해 주석을 사실로 만들었다.
- **`held_fix`·`held_decide` 대응의 자기모순을 없앴다.** 「미적용 수정」 대응에 `held_fix` 를 넣어 놓고 바로 아래 `held_decide` 문단은 "보류는 어느 구절도 못 담는다"고 적어 `held_fix` 자신이 그 문장의 반례였다. 실제 이유는 더 좁다 — 「미적용 수정」은 `fixes` 원장 세 행을 하위 상태와 무관하게 «원장 전체» 로 묶지만(pending·escalated·held 셋 다 「아직 적용 안 됨」은 같은 사실), `decides` segment 의 세 구절은 각각 특정 하위 상태만 가리켜 「상태 무관」 자리가 애초에 없다. 코드 동작은 안 바뀐다 — 주석뿐이다.

## [4.0.1] — 2026-09-22

### Fixed

- **`doc-critic` 층 1 이 축 이름과 판정 관계를 리터럴 산문으로 쥐고 있었다 — 네 자리 중 하나에만 맞는 문장이었다.** 본문(`shared/docreview/agents/doc-critic.md:47` + 사본 셋)이 「목표·문제정의·범위·아키텍처·컴포넌트 관계·데이터 흐름·trade-off·구현 가능성」을 열거했는데 그것은 design-doc 프로필의 `layer_rubric.layer1` 뿐이다. brief 는 `[direction]`, seed 는 `[unfounded_addition, …]`, `/qg` generic 은 `[logic, assumption]` 이다. 한편 codex 러너는 이미 프로필의 `layer_rubric.layer1` 을 읽어 프롬프트에 싣는다(`run_docreview_codex_reviewer.sh:372`·`:427`) — **같은 라운드의 두 판정자가 다른 rubric 으로 돌고 있었다.** 그 줄을 붙드는 락은 **하나도 없었다**(테스트 전수 grep 0건).
- **판정 관계를 프로필로 옮긴다.** agent 본문은 `layer_rubric.layer1` 을 참조하고, 「무엇과 대조하는가」는 각 프로필 본문의 「**층 1 판정 관계** —」 줄이 소유한다. 축 이름만 넘기고 관계를 리터럴로 두면 넷 중 하나에만 맞던 문장이 넷 중 둘에만 맞는 문장이 될 뿐이다.
- **근거 요구의 조건절은 남기되 축 이름에서 푼다.** 「**구현 가능성** finding 은 …」 → 「**리포 사실을 단정하는** finding 은 …」. 축이 사라져도 요구가 같이 사라지지 않는다. 「예외 없이 모든 층 1 finding」으로 넓히지 않는다 — 문서 내부 모순처럼 리포를 볼 필요가 없는 finding 에까지 인용을 요구하면 그 판정이 갈 곳을 잃는다.

### Added

- `shared/tests/test_docreview_layer1_wiring.sh` — 위임(agent 가 프로필을 참조하는가)과 소유(프로필 넷이 각자 관계를 갖는가)를 **함께** 잰다. 한쪽만 재면 다른 쪽이 조용히 빈다. 프로필 코퍼스는 글롭 도출이라 다섯째 자리가 생겨도 자동으로 계약에 든다. 판정 관계 네 줄이 서로 다름을 별도 축(B2)으로 재 복사-붙여넣기 재발을 막는다.

## [4.0.0] — 2026-09-22

major 인 이유 — **설치 요구사항이 하나 늘어난다.** 이 플러그인의 훅은 이제 Python 3.12
이상을 요구하고, 바닥 미만 머신에서는 돌지 않는다(막지는 않는다 — 건너뛴다).

### Changed

- **훅이 `python3` 를 직접 부르지 않는다.** `hooks.json` 의 자리가 `sh
  ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event … --plugin … --hook … <훅.py>` 로
  바뀌었다. 해석기는 kill switch 를 먼저 보고(정본과 같은 판정), `$DEVBREW_PYTHON` →
  `python3` → PATH 의 `python3.*` 순으로 바닥을 만족하는 인터프리터를 찾아 `exec` 한다.
  마이너 버전을 열거하지 않으며 `python3` 로 fallback 하지 않는다.
- **TTL-GC 자식을 `sys.executable` 로 띄운다** (`scripts/hook_common.py`). `python3` 로
  띄우면 해석의 효력이 프로세스 경계에서 끊겨 자식만 바닥 미만으로 떨어진다.

### Added

- `scripts/devbrew-python.sh` — `shared/python/devbrew-python.sh` 의 물리 사본
  (`# copy-of:`). 심볼릭 링크면 `plugin-audit` 의 containment 검사가 `shared/` 로 풀려
  거짓 「kill switch 부재」를 낸다.
- README 에 `Python 3.12+` prerequisite 와 바닥의 **도출 규칙**.

## [3.2.0] — 2026-09-19

minor 인 이유 — 새 surface 가 셋이다: seed 자리의 문서 리뷰 엔진 배선(재설계 PR 5), 스크립트 셋(`scripts/seed_review_log.py` · `scripts/seed_edit_diff.py` · `scripts/seed_provenance.py`), 번들 조립기의 `--for detect|recritic`. 지운 넷(격리 critic · seed 전용 codex 러너 · 빌더 · 체크리스트)은 `framing-requests` 안에서만 쓰이던 내부 파일이라 이 플러그인 밖의 호출 계약은 바뀌지 않는다. 설계 `docs/superpowers/specs/2026-09-16-framing-intent-drift-design.md`.

### Added

- **seed 리뷰의 처분 주체가 사용자다.** `framing-requests` 가 저자 편집을 처분 뒤로 미루고(단계 순서), 엔진이 라운드 게이트를 열지 않는 `fix` · `ask` 까지 사용자 앞에 올리며, 문구 없는 `drop` 을 라운드 게이트 뒤와 확정 게이트 직전에 막는다(`scripts/seed_review_log.py check-drops` — 엔진 공개 요약의 `dropped` 대 audit `## 6. 리뷰 결정`).
- **저자 편집 공시.** 헤딩 없는 seed 는 엔진 얼림이 꺼진다 — 기준 사본 diff(`scripts/seed_edit_diff.py`)를 라운드 게이트와 확정 게이트 앞에서 덩어리마다 「그대로 둔다 / 되돌린다」로 처분받는다. 기준 사본은 공시 뒤에만 교체된다.
- **형성 라운드의 확인 질문.** «원문과 다른 점» 자기보고 블록 대신 풀이를 질문 문구 · 원문과 나란히 놓고 양의 선택으로 묻는다. 압축이 고친 문장의 «(사용자 확인)» 은 `scripts/seed_provenance.py marks` 가 뗀다.
- **Phase 1 출처 대조.** `/interview` 가 seed 경로에서 audit 경로를 도출해 한 줄로 넘기고, `conducting-interview` 가 `seed_provenance.py classify` 로 출처와 확인을 두 축으로 가른다. `S1` 은 그대로다.
- **저자 편집 공시는 보인 판본에 묶인다.** `seed_edit_diff.py hunks` 가 비교한 seed 를 기준 사본 옆 `.shown` 에 기록하고, 그 뒤 seed 가 바뀌면 `revert` · `accept` 가 rc 4 로 거부한다 — 공시되지 않은 편집이 기준 사본으로 흡수되지 않는다.
- **확인과 출처는 문장 단위 일치로 가른다.** `seed_provenance.py` 는 부분 문자열이 아니라 문장 전체가 같아야 확인 · 사용자 출처로 친다 — 압축이 앞을 깎은 문장은 미확인 · 저자로 떨어진다. audit 의 `## 1` · `## 2` 가 없거나 템플릿 절 제목이 중복되면 `unavailable` 로 낸다.
- **seed audit 의 절 경계는 한 곳에서 계산한다.** `seed_review_log.section_body` 가 템플릿 절 제목에서만 끊는다. 템플릿 절 제목이 중복되면 번들을 만들지 않고(rc 2), 세 원문 자리 안의 제목 모양 줄은 게이트 공시로 올린다(판정 정규식은 `section6.py` 에 둔다). 붙여 넣은 원문 때문에 막히면 사용자가 「멈춘다 / 그 줄만 인용 표시로 감싼다」를 고른다.
- **확정 직전 검사는 엔진 자리가 없어도 오진하지 않는다.** 세션 정리로 엔진 자리가 걷혔으면 표시 · 공시 검사가 자리를 다시 만들고(공시는 기준 사본 부재 경로로), 엔진 원장이 없으면 문구 없는 drop 검사가 audit `## 6` 의 엔진 drop 줄로 대조하며 그 사실을 게이트 텍스트에 싣는다. audit 을 읽지 못하면 위반이 아니라 «검사 불가»다(`check-drops` rc 2 를 그대로 넘긴다).
- 락: `tests/test_seed_review_profile.sh` · `test_seed_review_log.sh` · `test_seed_edit_diff.sh` · `test_seed_provenance.sh` · `test_framing_review_contract.sh` · `test_seed_input_provenance.sh`.
- **사용자 문구 · 리뷰어 요약은 셸 인자로 넘기지 않는다.** `framing-requests` 가 받은 문구와 항목 요약을 Write 도구로 엔진 자리의 **항목별** 파일(`said-<id>.txt` · `note-<id>.txt` · `said-hunk-<k>.txt` · `said-extra-r<n>.txt`)에 쓰고, `seed_review_log.py log` 에는 `--quote-file` · `--note-file` 로, 엔진의 `decide --quote` · `fix --event drop --reason` · `begin-round --extra-approval` 에는 새 `seed_review_log.py one-line <파일>` 로 먼저 받아 rc 를 본 값을 `=` 꼴로 넘긴다 — 큰따옴표 안의 백틱 · `$( )` 가 셸에서 실행되지 않고, 문구 파일이 없으면 처분을 누르지 않는다. 파일은 기록이 성공하면 지우고 덩어리 문구는 공시마다 지운다 — 한 항목의 Write 를 빠뜨려도 다른 항목의 문구가 쓰이지 않는다. 여러 줄 문구는 한 줄로 이어 적고(둘째 줄이 엔진 기록 줄 모양이어도 기록이 되지 않는다), 빈 문구는 적지 않으며(rc 2), `답` · `거부` 는 같은 기록 줄을 다시 적지 않는다(대상이 finding id 라 줄이 처분을 유일하게 가리킨다).

### Changed

- **seed 프로필** — `ground_truth` 를 줄 단위로(audit `## 1` 전부 · `## 2` 의 «당신이 답한 것» 줄 · `## 6` 의 사용자 문구), 처분 안내에서 `ask` 를 빼고 앵커 리터럴 `#__doc__` 과 세 원문 자리의 비신뢰 경계를 적었다. `decision_log` 이 `## 8.` 에서 `## 6. 리뷰 결정` 으로. 앵커 부류는 비운 채 그대로다.
- **audit 템플릿** — `## 2` 의 줄 모양(«당신이 답한 것» · 확인 질문), `## 4` 가 엔진 산출물 자리, `## 6. 리뷰 결정` 절 추가.
- **번들** — 재료 다섯(초안 · `## 1` · `## 2` · `## 6` · CLAUDE.md). 재비판자는 판정 이력 대신 사용자 문구만 받는다.
- 락: `test_seed_gate_wiring.sh`(차가운 셸 실행) · `test_seed_codex_axes.sh`(옛 파일 부재 + 엔진 양의 짝) 재작성. 상한 락에 framing-requests 숫자 부재 검사(`ABSENT`). 에이전트 하한 20 → 19(`shared/tests/test_variant_of_contract.sh`).
- **`/qg` Review gate 뒤 고친 것**(같은 3.2.0 안):
  - `seed_provenance.py` 가 `## 1` 원문 단위를 **문단마다** 만든다 — 문장부호 없는 앞 문단(인사말 · 라벨)이 다음 문단의 온전한 사용자 문장을 «감싼 줄의 뒷토막» 으로 만들어 저자로 떨어뜨리던 것을 고쳤다. «(사용자 확인)» 도 문장 경계로 친다. 표시가 있는데 `## 2` 에 풀이 줄이 하나도 없거나(`no_reading_lines`) 모양이 어긋난 풀이 줄이 하나라도 있으면(`malformed_reading_lines`) 떼지 않고 판단을 거부한다(rc 2). 어긋난 줄은 `## 2` 안 **번호로만** 가리킨다 — 그 글자는 요청문에서 온 것이고 stderr 는 게이트 텍스트를 거쳐 셸 인자에 실린다. 템플릿이 예시로 남긴 자리표 줄(`「<풀이 문장>」 — <고름 | 고르지 않음>`)은 어긋난 풀이로 세지 않는다(템플릿을 그대로 복사한 audit 이 막히지 않는다).
  - 저자 편집 처분 펜스는 한 목록(`PAIRS` — 덩어리마다 「번호:처분」)이 되돌리기와 기록을 함께 몰고, 문구 파일이 하나라도 없으면 아무것도 바꾸지 않으며, 기록이 전부 성공했을 때만 기준 사본을 교체한다 — 기록이 실패해도 교체되어 그 편집이 다시 공시되지 않던 것을 고쳤다. 부분 실패 뒤에는 펜스를 통째로 다시 돌린다: `seed_edit_diff.py revert` 가 `<base>.reverted` 표지로 같은 공시의 같은 되돌리기를 다시 하지 않고(다른 되돌리기는 rc 4 — 번호가 다시 매겨진 덩어리를 되돌리지 않는다), `편집` 기록 줄은 다시 돈 만큼 겹친다 — `log` 의 같은 줄 건너뛰기는 `답` · `거부` 에만 쓴다. 덩어리 번호는 공시마다 1 부터 다시 시작하고 문구는 고른 라벨이라 다른 공시의 다른 처분이 글자까지 같은 줄이 되고, 그 줄을 「이미 있다」로 읽으면 그 처분 기록이 조용히 사라진다(AC6). 겹친 줄은 지우지 않는다 — 재실행으로 겹친 줄과 다른 공시의 다른 처분을 글자로 가를 수 없고, 겹침은 소비자를 상하게 하지 않는다. `ask_open` 의 답도 기록이 성공했을 때만 ask 를 닫는다.
  - `fix` 적용은 `check-intent` 한 번이다 — 그 호출이 통과 · escalate 를 스스로 적으므로 뒤따르던 `fix --event intent-pass` · `--event escalate` 지시를 뺐다.
  - 번들 조립기는 `## 1. 원문` 이 없거나 비면 조립하지 않는다(rc 2). 나머지 절의 부재 · 빈 `## 2` 는 `[spec-distill]` 경고로 내고, 그 줄과 codex 펜스가 낸 건너뛴 사유가 라운드 게이트 텍스트로 간다.
  - `check-drops` 는 템플릿 절 제목이 중복된 audit 을 판단하지 않는다(rc 2). 세 스크립트의 예상 못 한 예외는 rc 2 로 낸다 — rc 1 은 위반에만 쓴다. `seed_edit_diff.py` 는 빈 경로 인자를 rc 2 로 거부한다.
  - 냉독 출력은 `append-verbatim` 으로 audit `## 4` 에 인용 블록째 옮기고, `append-verbatim` 은 읽는 쪽과 같은 `str.splitlines` 로 줄을 나눈다(다른 줄 구분자 뒤의 제목 모양 글자가 인용 밖으로 새지 않는다). codex 러너가 산출물을 못 쓴 라운드(rc 3)도 `[spec-distill]` 줄로 게이트 텍스트에 간다. seed 프로필 처분 안내 · audit 템플릿 `## 5` 설명 · SKILL 의 문서 밖 인용 둘을 바로잡았다. `scripts/runner_common.sh` 사본의 러너 수(셋 → 둘)와 호출자 없는 `codex_extract_or_fallback` 을 주석으로 밝혔다(삭제는 별도 PR).
  - 락: 계약 락에 차단 문장 다섯(변이 포함) · 답 기록 · 공시 펜스 둘의 기준 사본 있는 실행 · 처분 펜스의 성공 경로와 기록 실패 경로. `check-drops` rc 2 네 모양 · 여러 줄 문구 · `one-line`. 문단 경계 · 표시 경계(변이 포함) · 템플릿에서 도출한 풀이 줄. `seed_edit_diff` 의 rc 모서리. seed 프로필 `ground_truth` 의 배제 절과 정답 목록 고정(`shared/tests/test_docreview_profiles.sh`, 넓힘 변이 넷). 처분 펜스의 두 덩어리 부분 실패 · 재실행 · 문구 파일 재사용 없음, drop · decide 처분 펜스, revert 표지, 다른 줄 구분자(U+2028 · U+0085 · U+000B), codex 건너뜀 줄의 `[spec-distill]` 접두(`test_seed_gate_wiring.sh`).

### Removed

- `agents/seed-critic.md` · `scripts/run_seed_codex_reviewer.sh` · `scripts/build_seed_codex_prompt.py` · `scripts/seed-codex-suppression-checklist.md` — seed 자리의 탐지 · codex 는 엔진이 진다.

## [3.1.1] — 2026-09-15

patch 인 이유 — 새 surface 가 없다. 바뀌는 것은 skill · reference 펜스가 플러그인 루트를 얻는 방식뿐이다.

### Security

- **skill 이 사용자 저장소의 스크립트를 실행하던 cwd fallback 을 없앴다.** `reviewing-brief`(13줄) · `framing-requests`(3줄) · `reviewing-spec`(펜스 다섯 · `PROFILE=` 셋)의 `${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}` 과 끝자락 `|| SD="./plugins/spec-distill"` 는 Bash 도구 환경에 그 변수가 없어 언제나 cwd 상대로 풀렸다 — devbrew 밖에서는 사용자 저장소의 `plugins/spec-distill/scripts/*` 를, devbrew 의 옛 체크아웃 · 포크 안에서는 다른 버전의 스크립트를 조용히 실행했다. 이제 펜스는 SKILL.md 를 로드할 때 절대 경로로 치환되는 bare `${CLAUDE_PLUGIN_ROOT}` 에서 루트를 받고, 빈 값이면 `[spec-distill] 플러그인 루트 미해석 — …` 를 stderr 로 내고 비0 으로 멈춘다. `reviewing-spec` 의 가드 메시지는 그 skill 의 다른 비-리뷰 출구와 같은 복귀 지시로 끝난다.
- **reference `skills/conducting-interview/references/finishing.md` 의 펜스 둘이 같은 가드를 지난다.** `Read` 로 연 reference 에는 치환이 오지 않아 bare 토큰이 Bash 에서 빈 값이 되어 `/scripts/…` 로 깨졌다. 여는 쪽 `conducting-interview/SKILL.md` 의 `Read` 줄은 로드 시 치환되는 `${CLAUDE_PLUGIN_ROOT}/skills/conducting-interview/references/finishing.md` 가 되고, 바로 아래 한 줄이 그 파일의 루트 변수를 무엇으로 바꿔 넣을지와, 경로가 절대 경로로 보이지 않으면 cwd 에서 찾지 말고 멈춘다는 것을 알린다.
- 집행은 새 공용 락 `shared/tests/test_plugin_root_no_cwd_fallback.sh` 가 한다.

**알려진 결과 둘**

- **devbrew 안 dogfooding 이 바뀐다.** 설치본 skill 이 이제 워킹트리가 아니라 설치본 스크립트를 돈다. 워킹트리 코드를 돌리려면 `claude --plugin-dir ./plugins/spec-distill` 로 로드한다.
- **skill 본문 치환이 없는 하니스에서는 멈춘다.** 경로를 추측하지 않고 가드에서 복구 지시와 함께 멈춘다. 어느 하니스가 그런지는 모른다 — 2.1.270 에서는 치환된다.

### Fixed

- **`tests/test_finishing_block_scope.py` 머리말.** 「`CLAUDE_PLUGIN_ROOT` 는 Claude Code 가 export 한다」는 틀렸다 — Bash 도구 환경에는 그 변수가 없다. 모델이 SKILL.md 가 보여 준 경로로 바꿔 넣고, 빠뜨리면 가드가 멈춘다고 고쳤다.
- **`tests/test_reviewing_spec_entry_fence.sh` 의 무치환 기대.** 진입 · `## 입력` 펜스가 판결 없이 비0 으로 멈추고, cwd 의 미끼 스크립트(`./plugins/spec-distill/scripts/`)를 돌리지 않으며, 원인과 복귀 지시를 한 줄로 낸다.

## [3.1.0] — 2026-09-14

minor 인 이유 — interview brief 리뷰 자리(`reviewing-brief`)가 공유 문서 리뷰 엔진(`shared/docreview/`)의 두 번째 껍데기가 됐다. 새 surface(웹 있는 탐지 사본 `agents/doc-critic-web.md` · 엔진 게이트 요약의 필드 넷 · 엔진 서브커맨드 `state-dir-for`)가 들고, 바뀌는 호출 계약(`reviewing-brief` 의 인자 넷 → 둘)은 `user-invocable: false` skill 의 유일한 호출자 `conducting-interview` 를 같은 릴리스에서 함께 고쳤다. 이 플러그인은 엔진을 `scripts/{docreview_state,docreview_route,adjudication}.py` · `scripts/run_docreview_codex_reviewer.sh` · `references/reviewing-document.md` 심볼릭 링크로 배포하므로 엔진 변경도 이 블록에 적는다(cache key). **3.0.1 위의 minor 다** — 3.0.0 · 3.0.1 과 병합한 뒤에도 위 새 surface 가 그대로 들고, 3.0.0 이 정한 `reviewing-spec` 진입 계약(진입 펜스 · 호출 인자 · 미커밋 펜스)과 후보 펜스의 **동작**은 바꾸지 않는다(후보 펜스의 텍스트는 아래 Fixed 항목대로 바뀌었다). 그 골격 위에서 엔진 상태만 세션 디렉토리에서 문서별 디렉토리로 옮겼다(아래 Fixed 첫 항목 · 업그레이드 주의 첫째).

**업그레이드 주의 셋**

- **진행 중인 리뷰는 라운드가 한 번 리셋된다.** 엔진 상태가 문서별 디렉토리(`state-dir-for`)로 옮겨, 이 버전 이전에 시작된 리뷰는 새 자리에서 라운드 1 로 다시 시작하고 재리뷰 상한도 한 번 리셋된다.
- **중복 키가 있는 사용자 프로필은 진입에서 멈춘다.** 게이트 `profile-check` 와 `init` 이 같은 로더로 `duplicate_key:` 를 거절하고, `init` 의 rc 가 0 이 아니면 라운드를 진행하지 않는다.
- **허용 문법 밖의 프로필은 codex 축이 공시와 함께 멈춘다.** 러너가 프로필 frontmatter 를 YAML 보다 좁은 한 줄 완결 문법으로만 읽는다 — 주석 · 홑따옴표 · 여러 줄 값을 쓰는 프로필은 게이트를 통과해도 `profile_parse_ambiguous` 로 codex 를 부르지 않는다. 배포 프로필 넷은 무편집으로 맞는다.

### Added

- **웹 있는 탐지 리뷰어 사본 `agents/doc-critic-web.md`.** 정본 `shared/docreview/agents/doc-critic-web.md` 의 `# copy-of:` 바이트 동일 사본이고, 그 정본은 `doc-critic` 의 `variant-of:` 다. 도구는 `doc-critic` 의 `Read, Grep, Glob` 에 `WebSearch` · `WebFetch` 를 더한 것이다. 프로필이 `web: true` 인 자리만 지명한다 — 오늘은 brief 자리 하나다(사용자 결정). brief 자리의 Claude 쪽 웹 근거(층 1 방향성의 외부 선례)가 이것으로 돌아왔다. 나머지 자리의 탐지는 웹 없는 `doc-critic` 그대로다.
- **엔진 서브커맨드 `docreview_state.py state-dir-for --root --session --doc`.** 세션과 문서 경로의 순수 함수로 문서별 상태 디렉토리를 낸다.
- **엔진 게이트 요약의 필드 넷.** `unverified`(`critic_dead` · `finalize_incomplete` · null) · `approval_label`(「미검증」 또는 null) · `round_reviewed`(이번 라운드의 finalize 보고서가 있고 「미검증」이 아닐 때만 참) · `unreviewed_reason`(`round_reviewed` 가 거짓인 모든 라운드의 사유 — 「미검증」 둘 또는 `unrouted`). 동작은 아래 Fixed 에 있다.
### Changed

- **brief 자리를 공유 엔진으로 전환 (`reviewing-brief`).** 3단계 파이프라인(방향성 → 충실도 → 냉독)이 엔진 여덟 단계(스냅샷 → kill switch → 탐지 → codex → 익명화 → 재비판 → 얼림 검사·라우팅 → 게이트)와 라운드마다 앞서는 진입 게이트 둘(`check_brief.py gate` · `check_verbatim_coverage.py`), 엔진 밖 냉독(`brief-readback`, advisory)으로 바뀌었다. 방향성과 충실도는 brief 프로필(`references/docreview-profiles/brief.md`)의 층 1 · 층 2 로 한 라운드에서 본다. 탐지 · 재비판 · codex 는 payload 와 audit 원문을 조립한 **번들**을 라운드마다 받는다. 결정 기록은 audit 의 `## 8. 리뷰 결정`(프로필 `decision_log`)으로 간다. 승인 게이트 2단계(진행 옵션 넷)는 이 skill 이 띄우지 않고 호출자 Step B 가 묻는다.
- **`cost_class: high` → `medium`, 진입 지출 승인 게이트 제거 (사용자 결정).** 지출 상한은 엔진의 재리뷰 상한이 맡는다 — 라운드 3 까지 돌고, 라운드 4 이상은 사용자가 승인 게이트에서 자기 문구로 열어야만 돈다.
- **`conducting-interview` 가 `reviewing-brief` 를 인자 둘(`$PAYLOAD $AUDIT`, 절대경로)로 부른다.** 옛 codex 산출물 경로 두 인자는 skill 이 스스로 도출한다. Step B 가 받는 산출물이 넷(확정 후보 / 방향성 C4 / readback + gap / degrade)에서 셋(엔진 게이트 결과 / 냉독 요약 + gap / degrade 채널)으로 바뀌었고, audit 템플릿의 brief 리뷰 절이 그 모양이다.
- **절차서가 엔진 스크립트를 배포 경로에서 부르라고 명시한다 (Park P10).** 정본 경로(`shared/docreview/scripts/`)에서 부르면 형제 파일에 기대는 스크립트 둘이 죽는다 — 셸 러너는 fail-closed 로 `runner_common_unloadable` 을 기록하고 rc 0 으로 끝나고, `docreview_route.py` 는 `ModuleNotFoundError` 로 rc 1 에 죽는다. `reviewing-spec` codex 펜스의 rc 3 서술은 종료점 열거 대신 메커니즘으로 적었다(Park P5 ④).
- **상한 도달 시 승인 게이트는 열린 것이 0 이어도 항상 두 단계다 (Park P3, 사용자 결정).** 1단계에 「추가 라운드 1회 열기」가 선다. 열린 것이 0 이면 「추가 라운드 1회 열기 / 진행 옵션으로」 둘뿐인 질문 하나이고, 열린 것이 있으면 열린 항목들 뒤에 별개 항목으로 서서 같은 4개씩 분할에 세어진다. 고르면 다음 라운드 1단계가 `begin-round --extra-approval "<사용자 문구>"` 로 돈다.
- **라운드 게이트가 한 `AskUserQuestion` 에 안 들어가면 질문 최대 4개씩 연속 호출로 나눈다 (Park P4, 사용자 결정 · 설계 §8.1 · AC8 수정).** 결정 하나에 질문 하나를 유지하고, 매 호출 첫 질문의 첫 줄은 렌더 첫 줄(degrade 공시)이다.
- **`DEVBREW_SPEC_DISTILL_DISABLE_WEB` 이 brief 자리에서 하는 일.** 탐지 dispatch 직전의 선택 펜스가 웹 사본 대신 웹 도구 없는 `doc-critic` 을 **지명**하고 loud advisory 와 degrade record(`critic` / `direction` / `degraded`)를 남긴다. 펜스는 dispatch 대상을 결정론적으로 이름 짓고 dispatch 는 지명된 블록을 따른다 — 그 선택을 강제하는 훅은 없다. 물리적인 것은 웹 없는 사본의 `tools:` 에 웹 도구가 없다는 것뿐이다. 커밋 `1eec5870` 메시지의 「물리적으로 끈다」는 과장이고 이 서술이 정정본이다. codex 쪽 웹 검색은 공유 러너가 끈다.
- **codex 프롬프트가 프로필의 `ground_truth` 와 본문을 싣는다 — 네 자리 공통 (Park P11 · 사용자 결정).** 전에는 `layer_rubric` · `allowed_dispositions` · `web` 만 실었다. 본문은 `<review_profile>` 절로 가고, 탐지 · 재비판 agent 가 읽는 것과 같은 루브릭이다. **design doc 자리의 codex 프롬프트도 바뀐다.** 지워진 옛 brief codex 체크리스트 둘의 실질 항목이 이 경로로 codex 에 간다. 순서는 형제 codex 빌더 셋과 같은 「지시 → P21 preamble → 입력 → 출력 형식」이다.
- **공유 절차서 3단계가 「진입 skill 이 고른 탐지 리뷰어(기본 `doc-critic`)」를 dispatch 한다.** 이 절차서의 배포 링크는 이 플러그인뿐이다(`references/reviewing-document.md`).
- **지워진 옛 파이프라인을 다른 이름으로 부르던 참조를 정리했다** — 식별자 축과 개념 별칭 축 둘로 훑었고, 모델이 읽는 산문이 없는 파일을 가리키던 자리도 포함한다. 다른 플러그인 쪽(quality-gates 러너 둘 주석 · SKILL 둘 산문 · plugin-audit 러너 주석 둘)은 각 플러그인 CHANGELOG 에 적었다.
- **README 를 엔진 전환 뒤 사실로 맞추고, 죽은 술어를 잡는 락을 더했다.** 흐름도의 brief 단계 · Principles Instantiated(Law 2 · Law 3 의 brief 자리 · 처분 회계 소비자 · 에이전트 목록 · P22) · kill switch 셋(`DISABLE_CODEX` · `DISABLE_WEB` · `DISABLE_BRIEF_REVIEW`)이 지워진 agent · 스크립트와 은퇴한 「재dispatch 상한」 · 「호출 지점 3곳」을 현재형으로 적고 있었다. `tests/test_readme_sync.sh` 는 키워드의 «존재»만 재서 이것을 못 잡았다. 부재 단언과 양의 짝을 쌍으로 더했다. (1) README 의 살아 있는 줄(버전 이력 문단 `**vX.Y.Z**` 제외)이 이름으로 대는 `.py` · `.sh` 파일은 전부 리포에 실재한다 — 도출 ∀ 이고 추출기 양성 대조를 함께 건다. 짝은 지금 소비자 · 러너(`docreview_route.py` · `run_docreview_codex_reviewer.sh`)를 이름으로 대는가다. (2) AP9 의 에이전트 목록은 이름마다 `agents/` 에 실재하고, 개수가 그 디렉토리와 같다. (3) 옛 brief agent 이름 둘과 「재dispatch 상한」이 살아 있는 줄에 없다 — 짝은 Principles 의 brief 자리 불릿이 `reviewing-brief` · `doc-critic-web` · `doc-recritic` 를 한 줄에 대는가다 — 줄머리 `- **Law 2` 로 묶었다. 머리 없이 재면 세 이름을 우연히 함께 대는 AP9 목록 줄이 짝을 대신 만족시켜, 불릿을 통째로 지워도 GREEN 이었다(변이로 확인). `tests/test_brief_review_meta.sh` 의 C4 는 `3곳|세 곳` 을 요구하던 단언을 두 엔진 자리 · 공유 러너 · 펜스 표지로 재조준했고, 「펜스 하나」 주장을 두 SKILL 에서 도출해 잰다. (1) 은 첫 실행에서 이 전환과 무관한 선재 거짓 인용 하나도 잡았다 — `## Hooks Installed` 의 Output schema 문단이 quality-gates 에서 이미 지워진 Stop 훅(`dd8d1911`)을 레퍼런스 패턴의 현재 위치로 대고 있었다. 그 문단은 3.0.0 이 리뷰 훅 삭제와 함께 SessionEnd 훅의 출력 서술로 다시 썼고, 병합이 그쪽을 따랐다.
- **동작 변화 (주의).** 「미검증」 라운드에 이전 라운드의 열린 항목이 있으면 라운드 게이트 대신 두 단계 승인 게이트가 뜬다(1단계는 라운드 게이트와 같은 형태). 같은 라운드에서 `finalize` 를 두 번 부르면(첫 번 성공 뒤) 그 라운드는 「미검증」이 된다 — 닫힌 쪽 오판이고 다음 정상 라운드에서 풀린다.
- **락 수치 셋이 한 번 더 내려갔다.** `shared/tests/test_adjudication_wiring.sh` 의 `COMP_BASELINE` 48(병합 직전 origin/main 의 값) → 40 — 이 릴리스가 지운 병합 스크립트 둘(`merge_brief_review.py` 2 · `merge_review.py` 6)의 컴프리헨션이 파일과 함께 빠졌다. `tools/adjudication/check_wiring.py` 의 `EXEMPT_BASELINE` 17(같은 main 의 값) → 11 — 같은 두 파일의 면제 여섯(`merge_brief_review.py` 1 · `merge_review.py` 5)이 키째 사라졌다. 둘 다 병합 트리 스캔(`run_wiring_scan.py`) 실측이다. 3.0.0 이 지운 리뷰 훅의 몫(세 트리 스캔의 차이로 잰 값: 컴프리헨션 4 · 면제 10)과 파일이 달라 겹치지 않는다. `tests/test_brief_agents.sh` 의 격리 목록 4 → 3 — 옛 `brief-critic` 삭제. 세 락의 비교 방향(이하 · 등식)은 그대로다.
- **공유 절차서 8단계의 완료 기록 규칙을 호스트 중립으로 다시 썼다.** design doc 자리의 기록자(arm 원장)는 [3.0.0] 이 지웠고, 규칙은 brief 자리의 audit 기록(§5 「리뷰 완료」 칸)에 남는다 — 「리뷰 완료를 기록하는 호스트는 그 기록을 요약의 `round_reviewed` 가 참일 때만 남긴다(거짓이면 완료로 적지 않고 `unreviewed_reason` 을 함께 적는다)」. 정의 문장(`round_reviewed` 는 이번 라운드가 리뷰 완료인가다)도 더했고, `shared/tests/test_docreview_procedure_paths.sh` 가 규칙과 정의 둘 다 잰다. `reviewing-spec` 의 「미검증」 라운드 단락도 원장 문장만 뺀 채 남았다 — 라벨 · finalize rc 규칙 · `unrouted` 공시는 그대로다.

### Removed

- **옛 brief 리뷰 파이프라인.** agent `brief-critic` · `brief-direction-reviewer`(탐지 · 재비판은 엔진의 `doc-critic` / `doc-critic-web` · `doc-recritic`), 스크립트 `merge_brief_review.py` · `build_brief_codex_prompt.py` · `run_brief_codex_reviewer.sh`(라우팅은 `docreview_route.py`, codex 는 `run_docreview_codex_reviewer.sh`), codex 체크리스트 둘(`brief-codex-fidelity-checklist.md` · `brief-codex-direction-checklist.md` — 실질 항목은 프로필 본문으로 codex 에 간다).
- **옛 design doc verdict 파이프라인의 마지막 두 파일** — `merge_review.py` · `compute_issue_id.py` (1.0.0 이월, Park P8). README 의 `Phase 3` 잔존 인용도 정리했다(P6).
- 피검자가 사라진 테스트 여섯 — `test_merge_brief_review.py` · `test_merge_brief_adjudication.py` · `test_merge_review.py` · `test_merge_review_adjudication.py` · `test_compute_issue_id.py` · `test_degrade_alias_single_definition.py`.
- **`brief_review_state.py` 가 아무도 읽지 않던 옛 키 둘(`brief_review_stage` · `brief_critic_rounds`)을 심던 것과, 그 키만 쓰던 서브커맨드 셋.** degrade 원장(`brief_review_degradations`)은 그대로다.

### Fixed

- **엔진 상태가 문서를 넘어 재사용되던 결함.** `init` 이 이미 있는 원장이 다른 문서 · 프로필의 것이면 `state_doc_mismatch`(`state_profile_mismatch`) rc 1 로 거부하고 원장 바이트를 건드리지 않는다. 상태 디렉토리가 문서별이고(`state-dir-for`) codex 산출물도 그 안에 있다. 전에는 한 세션의 둘째 문서가 첫 문서의 라운드 · 재리뷰 상한 · finding 을 조용히 물려받았다 — design doc 자리에서도 도달했다. [3.0.0] 의 `reviewing-spec` `## 입력` 은 세션 디렉토리(`$ROOT/$harness_sid`)를 엔진 상태로 썼다 — 병합이 그 골격(SD 관용구 · 상태 리졸버 부재 · sid 미해석 분기) 위에 문서별 도출을 얹었다. 그 자리를 세션 값으로 핀하던 [3.0.0] 의 락 셋 — `tests/test_reviewing_spec_entry_fence.sh`(상태 디렉토리 펜스의 선택 키 · 값) · `tests/test_review_hook_removed.py`(새 입력 계약의 리터럴) · `tests/test_reviewing_spec_state_keying.sh` S2 · S3 — 은 문서별 값으로 재조준했다. 펜스에 문서 경로를 주면 값이 `state-dir-for` 의 출력과 같고 `<state root>/<sid>/docreview/` 바로 아래이며, 한 세션의 이름이 같은 두 문서가 다른 값을 받는다. 문서 경로가 없으면 빈 값과 사유(`doc_empty`)다. codex 산출물은 그 문서 디렉토리 안이고(`CODEX_YAML` 대입 전부), `STATE_DIR` 대입은 실패 분기의 `STATE_DIR=""` 리셋을 빼고 전부 문서별 도출이다.
- **TTL-GC 가 진행 중인 설계문서 리뷰의 세션 폴더를 걷을 수 있었다 (병합 리뷰 I1).** GC 는 세션 폴더의 나이를 **직속 파일**의 최신 mtime 으로 쟀다(직속 파일이 없으면 폴더 자신의 mtime). 병합 전에는 두 쓰기가 그 나이를 새로 했다 — [3.0.0] 의 엔진 원장은 `<sid>/docreview-state.md` 로 세션 폴더에 바로 써졌고, 그 전에는 지금은 없는 Stop 훅이 dispatch · 발견 커서 전진 · 구조 실패 등 때때로 `<sid>/state.local.md`(arm 원장)를 새로 썼다(턴마다는 아니다). 이 릴리스에서는 둘 다 없다 — 엔진 상태가 `<sid>/docreview/<문서별>/` 아래로 내려갔고(위 항목) 그 훅은 [3.0.0] 이 지웠다. 그래서 설계문서만 리뷰한 세션은 `<sid>/` 에 직속 파일이 없거나 늙은 것뿐이다. 첫 리뷰로 `docreview/` 를 만든 뒤 TTL(기본 24시간)이 지나면, 같은 저장소의 다른 세션이 끝날 때 도는 GC 가 방금 쓴 엔진 원장째 폴더를 걷을 수 있었다. 다음 `init` 은 라운드 1 · 재리뷰 상한 · 결정 · permit 이 비어 있는 새 원장을 조용히 만들었다. 이제 나이는 폴더 자신과 그 아래 **모든 항목**(깊이 무관)의 최신 mtime 이다. `os.walk(followlinks=False)` 와 `os.lstat` 로 재고 링크는 따라가지 않는다(링크 자신의 mtime 만 센다). 잰 집합은 예전의 상위집합이라 GC 는 덜 지우는 쪽으로만 바뀐다. 예외가 하나 있다 — 예전에는 세션 폴더의 **직속** 링크를 따라가 링크 너머 파일의 mtime 을 썼고, 이제는 그러지 않는다(폴더 안 링크가 밖의 신선한 파일을 가리켜 폴더를 살려 두지 못한다). 순회 중 항목이나 하위 디렉토리가 사라지면 그 스냅숏은 불안정하다 — `SnapshotUnstable`(`OSError` 의 하위)을 올려 이번 실행은 그 폴더를 수집하지 않고, 다음 실행이 다시 잰다. 한 번의 걷기 안에서는 부모 디렉토리와 원래 파일을 이미 늙은 값으로 쟀을 수 있다. 그래서 원자적 교체(tmp 쓰기 → rename)의 tmp 를 건너뛰면 두 스냅숏이 같은 늙은 값으로 남아 진행 중인 세션이 걷힌다(codex 교차 리뷰 적발 — 한때 건너뛰던 판정을 고쳤다). 두 번째 스캔 뒤 · rename 전의 쓰기는 여전히 못 본다 — 이 릴리스 이전부터 있던 창이고, TTL 넘게 멈췄던 세션이 다른 세션 GC 의 짧은 창에 재개할 때만 걸린다(후속). 읽지 못하는 하위 디렉토리가 있으면 그 폴더는 수집하지 않는다. 루트 탈출 · 링크 루트 거부는 그대로다. 정본은 `shared/gc/gc_common.py` 이고, 사본 `scripts/gc_common.py` 로 이 플러그인과 quality-gates 가 함께 싣는다(quality-gates CHANGELOG `[7.6.0]`). 락은 `tests/test_gc.py` 의 두 클래스다:
  - `NestedAgeTest` — 두 층 아래 신선한 원장이면 보존한다(수정 전 RED). 모든 깊이가 늙었으면 수집한다. 깊은 링크든 직속 링크든 밖의 신선한 파일을 가리켜도 수집한다(직속 링크 셀은 수정 전 RED).
  - `SnapshotUnstableTest` — 두 번째 스캔 중 사라진 파일이나 순회 중 사라진 하위 디렉토리가 있으면 `gc_one` 이 수집하지 않는다(둘 다 수정 전 RED). 안정적으로 늙은 폴더는 수집한다(양의 짝). 함수는 `SnapshotUnstable` 을 올린다.

  늙은 세션을 흉내 내던 픽스처(`tests/test_gc.py` 둘 · `tests/test_session_end_cleanup.py` 둘 · `tests/test_kill_switches_v060.sh` 둘)는 폴더 자신의 mtime 도 늙힌다 — 실제로 늙은 세션은 폴더 mtime 도 늙었다. 늙히지 않으면 방금 만든 폴더의 mtime 이 폴더를 살린다. 수집을 기대하는 칸은 RED 가 되고, kill switch 로 보존을 기대하는 칸(`test_kill_switches_v060.sh` case 2)은 스위치와 무관하게 GREEN 인 공허한 칸이 된다. 링크 자식 거부 칸(`tests/test_gc.py` `test_13`)은 링크 자신의 mtime 도 늙힌다 — 늙히지 않으면 방금 만든 링크의 mtime 이 링크 자식 skip 없이도 링크를 살려 그 칸이 공허해진다(재리뷰 N-1). `skills/framing-requests/SKILL.md` 의 폴더 나이 서술도 고쳤다.
- **`reviewing-spec` 후보 펜스의 awk 가 `$0` 을 썼다([3.0.0]) — 잠복 결함.** 로드된 skill 본문의 `$0` 은 첫 Skill 인자로 치환된다. 인자가 있는 호출에서는 `awk 'NF && !seen[<경로>]++'` 가 되어 문법 오류(rc 2)로 죽지만, 문서화된 경로는 인자가 있으면 이 펜스를 돌리지 않는다 — 살아 있는 결함은 아니었다. 바뀐 것은 펜스의 텍스트다: 저장소 전체 락 `shared/tests/test_skill_body_no_positional_tokens.sh` 가 그 토큰을 금지해서, 필드 구분자를 git 이 인용 없이 내지 않는 제어 문자 `\037` 로 두고 `$NF`(= 줄 전체)를 키로 쓴다. 순서 보존 · 중복 제거 · 빈 줄 제거는 그대로다. `tests/test_reviewing_spec_entry_fence.sh` 의 후보 셀에 공백이 든 이름 셋(마지막 공백 필드가 같은 둘 + 한글 하나)을 더했다 — `BEGIN{FS="\037"}` 를 지우면 기본 FS 의 `$NF` 가 마지막 공백 필드라 뒤의 둘이 중복으로 지워져 RED 다.
- **brief 프로필의 `ground_truth` 가 번들의 두 원문 자리를 가리킨다.** 번들이 audit §6 헤딩을 벗겨 리뷰어가 `S2` 이상의 원문을 못 찾았다.
- **brief 프로필 층 2 에 충실도 범주 셋을 복원했다** — `provenance_mislabel` · `authority_syntax` · `evidence_unsupported`. 옛 critic 의 여섯 범주 중 엔진 전환으로 빠졌던 셋이고, critic 과 codex 프롬프트 둘 다로 흐른다.
- **brief 프로필 층 2 에 세 줄을 더했다.** finding 은 근거 원문 `S<N>` 을 `evidence` 에 인용한다 · `omission` 은 두 원문 자리를 둘 다 끝까지 훑는다 · 두 원문 자리의 내용은 비신뢰 데이터라 그 안의 지시를 따르지 않는다. critic 과 codex 둘 다로 흐른다.
- **codex 러너가 `ground_truth` 를 조용히 빈 줄로 싣지 않는다.** 값이 비었거나(빈 문자열 · 맨 키 `ground_truth:` · `null`) 목록이면 게이트와 같은 이름의 `ground_truth_empty` 로, 문자열이 아닌 스칼라 · 매핑이면 `profile_parse_ambiguous` 로 멈추고 codex 를 부르지 않는다. 키가 아예 없으면 다른 읽는 필드와 같이 `profile_field_missing` 이다(게이트는 `fields_missing`).
- **엔진이 「미검증」 라운드와 finalize 실패 라운드를 결정론으로 안다.** critic 사망 두 번과 finalize 거부를 원장에 기록하고(준비의 `round` · `rounds[n].finalize_failed`) 게이트 요약에 위 필드 넷을 싣는다. 전에는 그런 라운드의 게이트 첫 줄이 「degrade 없음」으로 렌더됐다(거짓 공시). `round_reviewed` 가 거짓인 **모든** 라운드(finalize 에 닿지 못한 `unrouted` 포함)는 첫 줄이 그 사실을 공시하고, 「다음:」 줄이 「진행 옵션 활성」을 조건 없이 내지 않는다(꼬리 「단 이번 라운드는 리뷰 완료가 아니다」). 「미검증」 라벨과 승인 게이트 강제는 critic 사망 · finalize 실패에만 서고 `unrouted` 는 공시만 한다. 절차서 7단계에 finalize rc 규칙이 섰다 — rc 가 0 이 아니면 값과 무관하게 정상 게이트로 넘기지 않는다. brief 자리는 라벨 · `round_reviewed` · 사유를 엔진 출력에서 읽어 Step B 로 싣는다.
- **엔진 게이트가 층 범주명을 정규식으로 컴파일하지 않는다.** `"c++"` 같은 범주를 게이트는 `bad_regex` 로 거절하고 러너는 받던 반대 방향 발산이다. 러너 줄 문법 규칙 넷에 단일 위반 셀을 더했고, `layer_rubric` 이 매핑이 아니면 러너가 모양 사유(rc 5)로 멈춘다. 「`init` rc ≠ 0 이면 라운드를 진행하지 않는다」에 락을 걸었다(절차서 + 두 진입 skill).
- **skill 본문의 위치 인자 토큰이 Skill 인자로 치환돼 사용자 audit 을 지울 수 있던 결함.** Claude Code 는 로드된 SKILL.md 본문의 `$N`(0부터 — `$1` 은 둘째 인자)을 호출 인자로 치환하고, 인자가 없는 자리의 토큰은 그대로 둔다. `reviewing-brief` 는 인자 둘(payload · audit)로 불리므로 codex 게이트 펜스의 잔존물 중화 함수 `neutralise` 의 `rm -f "$1"` 이 로드된 본문에서 `rm -f "<audit 절대경로>"` 가 됐다(PR 3 관측 태스크 T9 의 헤드리스 세션 기록). 모델이 펜스를 문자 그대로 돌리면 함수는 자기 인자를 무시하고 **사용자의 추적 audit sidecar 를 지웠고**(지우지 못하면 0바이트로 절단했고), 정작 직전 라운드 codex 산출물은 중화되지 않아 5단계의 시점 판별 하나에 맡겨졌다. 같은 치환으로 탐지 선택 펜스의 `record_web` 은 degrade 사유 대신 audit 경로를 기록했다. 인자 하나로 불린 `reviewing-spec` 에서는 같은 토큰이 치환되지 않고 남았다 — 같은 모양이라 함께 고쳤다. 두 함수는 이제 이름 있는 변수(`NEUTRALISE_TARGET` · `WEB_REASON`)를 읽는다. 새 락 `shared/tests/test_skill_body_no_positional_tokens.sh` 가 저장소 전체의 skill · command 본문(frontmatter · 펜스 안팎)에서 `$0`–`$9` · `${0`–`${9` · `$@` · `$*` · `$#` 와 frontmatter `arguments:` 선언(선언된 이름의 `$name` 이 치환된다)을 금지한다. 허용은 `$ARGUMENTS` · `$ARGUMENTS[N]` 이다.
- **탐지 · 재비판 리뷰어가 프로필을 «경로»로 받던 결함 (PR 3 최종 리뷰 F1).** 두 엔진 자리(`reviewing-brief` · `reviewing-spec`)의 dispatch 블록이 `<profile>${PROFILE}</profile>` 에 경로를 실었다. 설치본에서 프로필은 플러그인 캐시(사용자 프로젝트 밖)에 있어 리뷰어의 Read 가 권한 거부됐고(PR 3 관측 태스크 T9), 리뷰어는 이 릴리스가 되살린 프로필 루브릭(층 2 충실도 범주 · `S<N>` 인용 · 원문 = 비신뢰 데이터) 없이 판정했으며 엔진은 그것을 몰랐다. 이제 두 skill 이 탐지 dispatch 직전의 `profile-content` 펜스에서 `cat "$PROFILE"` 로 내용을 얻어 탐지 · 재비판 슬롯에 싣는다. 읽지 못하면 dispatch 하지 않고 critic 출력을 비워 두어 5단계가 critic 사망 → 재dispatch 1회 → 「미검증」으로 닫는다(brief 는 degrade 원장에도 남긴다). 템플릿 변수 `${PROFILE}` · agent `input_slots` 는 그대로다. 락 `tests/test_dispatch_profile_inline.sh` 가 두 skill 의 문구 · 슬롯 수 · 펜스를 재고 펜스를 차가운 셸에서 실행한다.
- **7단계 얼림 검사와 permit 관측이 오케스트레이터가 쓰는 diff 파일에 묶여 있던 결함 — 엔진이 원장의 라운드별 스냅숏으로 계산한다 (PR 3 최종 리뷰 F2 · qg iter 1 · 2 · 3).** 절차서 7단계가 `diff prev.json snap.json` 으로 직전 라운드 스냅숏을 읽는데 그것을 쓰는 줄이 없었고, `finalize` 는 라운드 ≥ 2 에서 `--diff` 가 없으면 얼림 검사(`frozen_change` 자동 `decide`)를 공시 없이 건너뛰었다. 그 diff 파일의 실패 모양(부재 · 0바이트 · JSON 아님 · 읽기 실패)을 소비자마다 공시로 막던 중간 수정들은 복구 없는 공시라, 관측하지 못한 permit 을 이후 라운드가 다시 보지 않고 그 결정이 `adopted` 로 남아 재결정도 거부되는 봉인을 낳았다. 이제 `finalize` 가 pending 가드 뒤 · 어떤 소비보다 앞에서 permit · fix 적용을 관측하고 얼림 diff 를 원장의 스냅숏(1단계 `begin-round` 가 저장한다)으로 스스로 계산한다 — `observe-diff` · `finalize` 는 `--diff` 를 받지 않고, 절차서 7단계는 `finalize` 한 호출이다. 관측은 `round ≤ n` 인 미소비 permit 전부를 각자 자기 라운드의 스냅숏 쌍으로 본다 — 관측을 건너뛴 라운드(critic 사망으로 6~7단계를 건너뛴 라운드 · finalize 가 거부된 라운드)의 permit 을 뒤 라운드가 따라잡고, 원복 permit 은 그 permit 라운드의 스냅숏으로 판정한다. **따라잡는 것은 permit · fix 관측뿐이다** — 그런 라운드 k 자신의 얼림 검사(스냅숏 k−1→k 의 허가 없는 변경 → `frozen_change`)는 뒤 라운드가 따라잡지 않는다. 뒤 라운드의 `finalize` 는 자기 창(n−1→n)만 보므로 그 창의 변경은 결정으로 올라오지 않는다 — 이 릴리스 이전부터 같은 알려진 한계다(후속). 관측 없이는 만료하지 않는다 — 필요한 스냅숏이 원장에 없으면 `observe-diff` · `finalize` 가 rc 1 `snapshot_missing` 으로 아무것도 소비하지 않고, `finalize` 는 준비를 치우기 전에 멈춰 게이트가 「미검증」(`finalize_incomplete`)으로 연다(모양이 틀린 permit 은 `permit_corrupt`). 얼림 면제 집합의 permit 은 소비 여부와 무관하다(관측으로 소비한 뒤 diff 를 계산한다). 따라잡은 적용은 관측한 라운드의 `progress` 로 센다(stagnation 입력 — 선택). 관측할 것이 없는 `observe-diff` 는 원장을 쓰지 않는다. `diff_snapshots` · `resolve_scope` 는 `scripts/docreview_anchor.py` 에서 `docreview_state.py` 로 옮겼다(`docreview_anchor.py diff` 의 출력은 그대로다). 락: 엔진 케이스 여섯 — `case_E1_skipped_round_permit_caught_up`(수정 전 엔진에서 RED — 봉인 재현) · `case_E1b_skipped_round_unedited_permit_expires` · `case_E2_finalize_observes_idempotent` · `case_E3_consumed_permit_exempt_from_freeze` · `case_E4_snapshot_missing_unverified` · `case_E5_revert_caught_up_by_its_round_snapshot`. 변이 다섯(관측 필터 `== n` · 면제에서 소비된 permit 제외 · 원복을 현재 스냅숏으로 · finalize 의 관측 제거 · 스냅숏 부재를 빈 diff 로)에 각 케이스가 RED 인 것은 **한 번 측정**했다 — `shared/tests/test_docreview_mutations.sh` 에 등록하지 않아 다시 재지 않는다(후속). `shared/tests/test_docreview_procedure_paths.sh` 의 도출 ∀(절차서가 대는 `*.json` 마다 그것을 쓰는 `> <이름>` 이 같은 문서에 있다)는 하한을 남은 이름 수 3 에 맞췄다. `case_AC21_reraise_accumulates` 는 라운드 3 이 관측을 쓰도록 탈것을 옮겼다(단언 무변경). 파손 diff 로 `finalize` 를 죽이던 `case_T46_finalize_failed_unverified` 는 탈것을 비-UTF-8 재비판 출력으로 옮겼다(단언 무변경).
- **비-UTF-8 critic 출력이 critic 사망이 아니라 `unreadable` rc 1 로 끝나던 결함 (PR 3 최종 리뷰 F6 · F7).** 설계 §9 는 탐지 리뷰어 출력의 sentinel 블록이 없거나 깨지면 주 판정자 실패(critic 사망 → 재dispatch 1회 → 「미검증」)로 친다. `prepare-recritic` 이 디코드 예외를 잡지 않아 rc 1 `unreadable` 로 끝났고, 재시도 없이 라벨 없는 `unrouted` 로 갔다. 이제 디코드 실패는 sentinel 깨짐과 같은 판정이다(rc 4 · `critic_dead` · 사유 `layer1 block undecodable`). 그 입력을 `unrouted` 공시의 탈것으로 쓰던 엔진 케이스는 「5~7단계를 건너뛴 라운드」로 탈것을 옮겼고, 라운드 2 · 이전 라운드의 열린 항목이 남은 `unrouted` 라운드(가장 흔한 재리뷰 모양)의 렌더 첫 줄 공시와 「다음:」 꼬리를 재는 케이스를 더했다 — 전에는 그 공시를 `approval_ready` 갈래에서만 쟀다.
- **공시 · 기록 문구가 사실과 다른 두 자리 (PR 3 최종 리뷰 F9).** (a) `reviewing-brief` codex 게이트의 SKIPPED 공시가 「이 리뷰에는 모델 다양성도 외부 웹 근거도 없었다」였다 — 탐지가 `doc-critic-web` 으로 웹을 쓴 라운드에서 거짓이다(PR 3 관측 T9 — URL 인용 2건). 「codex 쪽의 모델 다양성과 웹 근거가 없었다」로 고쳤다(관측 락들이 재는 `codex co-review SKIPPED (reason: …)` 머리는 그대로). (b) audit 템플릿(`templates/interview-audit-template.md`) §5 의 brief 리뷰 절에 리뷰 완료 여부 칸이 없고 웹 칸이 한쪽 모양이라, `reviewing-brief` 가 「템플릿 줄 모양대로」 채우는 기록에 엔진의 `round_reviewed` · `unreviewed_reason`(`unrouted` 포함)과 두 쪽 웹 공시가 닿지 않았다. 라운드 줄에 「리뷰 완료: <예 | 아니오 — <unreviewed_reason>>」를, 웹 칸을 SKILL `## degrade 채널` 의 웹 줄과 같은 `웹: Claude <…> · codex <…>` 모양으로 바꿨다. `tests/test_brief_review_entry.sh` 가 두 칸을 재고, 웹 칸의 기대 모양은 SKILL 에서 도출한다.
- **라운드 시작보다 오래된 critic 출력을 이번 라운드의 탐지로 섭취하던 결함 (PR 3 qg iter 1).** 위 F1 수정은 프로필을 읽지 못한 라운드에 dispatch 하지 않고 critic 출력 파일을 「빈 채로 둔다」고 적었지만 그 파일을 비우는 것이 없었고(맨 이름 `critic.txt` 는 cwd 기준이라 다른 문서 · 세션의 잔존물도 섞일 수 있었다), 엔진의 시점 판별은 codex 에만 있었다 — 라운드 2 이상에서 그 펜스가 실패하면 직전 라운드의 탐지 출력이 rc 0 · `critic_dead` 거짓으로 이번 라운드의 탐지가 됐다. 이제 (1) 엔진 `prepare-recritic` 이 codex 와 같은 판별(공유 함수)을 critic 에도 적용한다 — 라운드 시작 표식보다 먼저(또는 같은 시각에) 쓰인 critic 파일은 내용과 무관하게 critic 사망(rc 4 · 사유 `layer1 block critic_predates_round`)이다. 표식이 없거나 정수가 아니면 critic 은 닫지 않는다(그 두 사유는 전처럼 codex 축만 부재로 닫는다). (2) 두 skill 이 critic 출력 자리를 `$STATE_DIR/critic.txt`(문서별 상태 디렉토리)로 못박고, 프로필 펜스의 실패 분기가 그 파일을 비운다(`$STATE_DIR` 이 비면 건너뛴다) — `reviewing-spec` 펜스는 그 도출을 위해 `## 입력` 의 도출 줄을 싣는다. (3) 절차서 5단계에 critic 쪽 규칙 한 문장. 락: 엔진 케이스 `case_critic_predates_round_dead`(라운드 1 의 critic 을 라운드 2 에 그대로 넘기면 rc 4 · 섭취 0, 양의 짝: 새로 쓴 critic 은 rc 0). 커밋된 critic 픽스처를 라운드 시작 뒤에 넘기던 엔진 케이스 38곳과 `route_r1` 의 기본값은 `critic_now`(라운드 시작 뒤 복사 — `codex_now` 와 같은 모양)로 탈것만 옮겼다(단언 무변경). `tests/test_dispatch_profile_inline.sh` 가 두 skill 펜스를 차가운 셸에서 실패시킬 때 미리 채운 `$STATE_DIR/critic.txt` 가 비워지는지와, 성공 경로는 그 파일을 건드리지 않는지를 잰다.
- **`tests/test_reviewing_brief_skill.sh` 의 머리 동일성 락이 `## dispatch 블록 둘` 절의 모든 bash 블록을 잰다 (PR 3 qg iter 1 · 재리뷰 NB-1).** 그 절의 첫 bash 블록만 재서, F1 의 프로필 내용 펜스가 첫 블록이 된 뒤로 탐지 선택 펜스의 머리는 어느 락도 재지 않았다(선택 펜스 락은 `## 입력` 블록을 앞에 붙여 돌려 머리가 흘러가도 가려진다). 이제 절의 bash 블록 수(2 이상)를 양의 짝으로 재고 블록마다 머리를 대조한다 — 선택 펜스 머리에서 `STATE=` · `DEGRADE_FALLBACK_FILE=` 두 줄을 지우는 변이가 수정 전 GREEN · 수정 뒤 RED 다.
- **critic 시점 판별 불가를 공시한다 (PR 3 qg iter 2 F-e).** 라운드 시작 표식이 없거나 정수가 아니면 critic 은 전처럼 죽지 않는다(사용자 결정). 그러나 codex 파일을 넘기지 않는 라운드(kill switch · `residue_unclearable`)에서는 그 라운드의 시작이 기록되지 않았다는 사실이 어디에도 남지 않았다. 이제 `prepare-recritic` 이 codex 경로와 독립으로 `degrade.critic_freshness_unknown` 에 사유를 남기고 `finalize` 가 「critic 시점 판별 불가 (<사유>)」를 `advisory[]` 에 싣는다(차단 아님 · 키는 그때만 생긴다). 락: `case_critic_freshness_unknown_disclosed`(두 사유 + 양의 짝). 같은 자리의 층 1 판정은 사유 문자열 · 동작을 바꾸지 않고 형 좁히기를 되돌렸다(F-b).
- **프로필 펜스가 비우지 않은 critic 출력을 「비우고」라고 말하던 결함 (PR 3 qg iter 2 F-c).** 두 skill 의 실패 분기가 비우기 전에 그렇게 말하고, `$STATE_DIR` 이 비면 조용히 건너뛰었다. `reviewing-spec` 은 `$STATE_DIR` 을 `$spec_path` 로 도출하는데 같은 Bash 호출에서 대입하라는 말이 없었다. 이제 비운 뒤에 「비웠다」를 말하고, 못 비우면 「비우지 못했다」, `$STATE_DIR` 이 없으면 「비우지 않았다 — STATE_DIR 도출 실패(…)」다. `reviewing-spec` 산문은 `$spec_path` 를 이 펜스와 같은 Bash 호출에서 대입하라고 적는다(`reviewing-brief` 의 `$PAYLOAD` 는 `## 입력` 이 이미 요구한다). `tests/test_dispatch_profile_inline.sh` 가 「비웠다」 보고와 문서 슬롯 없이 돈 실패 분기의 건너뜀 공시 · 파일 무접촉을 잰다.

### Security

- **`layer_rubric` 의 허용 키를 `{layer1, layer2}` 로 닫았다 (Park P1).** 셋째 키의 블록 스칼라 미끼가 codex 러너의 파서를 속이던 경로다. 게이트가 `layer_rubric_fields_unknown:` 으로 거절하고, `init` 이 같은 로더라 그 프로필로는 라운드가 시작되지 않는다.
- **kill switch 잔존물 경계 셋 (Park P5 ①②③).** 상태 디렉토리와 codex 파일이 쓰기 불가여도 라운드가 전진하는 권한 조합이 실측으로 도달 가능했다. 이제 1단계 `begin-round` 가 라운드 시작을 기록하고, 5단계 `prepare-recritic` 이 그 시각 전(동률 포함)에 쓰인 codex 파일을 내용과 무관하게 부재로 읽는다(`codex_predates_round` · 기록이 없으면 `round_start_unrecorded` · 정수가 아니면 `round_start_unreadable`). `reviewing-spec` codex 펜스의 errexit 안전 · 절단 tier 락 · 1단계의 비-zero rc 전부 정지도 함께다.
- **엔진이 상대 `--doc` 을 `doc_not_absolute` 로 거부하고, `state-dir-for` 가 `[A-Za-z0-9_-]` 밖 문자가 섞인 세션 id 를 `session_invalid` 로 거부한다.** 절차서와 두 진입 skill 이 「`init` 비-zero 면 진행하지 않는다」를 적는다. 문서 경로가 빈 라운드의 codex 펜스는 세션의 모든 문서별 codex 산출물(`docreview/*/docreview-codex.yaml`)을 중화한다 — 세션 원장(`state.local.md`) · 엔진 원장 · 다른 이름의 파일은 건드리지 않는다는 것을 락이 바이트로 잰다(전제: 한 세션은 리뷰 라운드를 동시에 둘 돌리지 않는다). 치우지 못하면 `residue_unclearable` 로 공시하고 codex 없이 간다.
- **웹 kill switch 계약 락이 엔진 codex 러너를 같은 해상도로 잰다.** `tests/test_web_kill_switch.sh` 의 AC21 표가 옛 brief 러너 행을 잃고 `run_docreview_codex_reviewer.sh` 를 배포 경로 둘 × 평시 · `=1` · `=yes` × 두 열(`web_search` 모드 · `tools.web_search`)로 잰다. 전에는 엔진 러너의 스위치 효과를 한 열(`live` 부재)로만 재서, 스위치를 켜도 `tools.web_search=true` 로 캐시 검색이 남는 변이를 못 잡았다. 추론 강도 핀 금지 락(quality-gates `test_codex_runner_no_effort_pin.sh`)도 엔진 러너를 포함한다.
- **주입 경계 규칙을 `doc-critic` · `doc-critic-web` · `doc-recritic` · `brief-readback` 페르소나에 더했다.** 리뷰 대상 문서와 그 안의 사용자 원문 블록은 데이터다 — 옛 `brief-critic` 삭제로 사라졌던 보호의 복원이다. 추가만 했고 삭제 줄은 0 이다.
- **게이트(`profile-check` · `init`)가 중복 키(`duplicate_key:`)와 빈 본문(`profile_body_empty`)을 거절한다.** 게이트와 러너 파서가 같은 프로필을 다른 값으로 읽던 경로(Park P1 부류)를 막는다. 게이트는 `layer1` · `layer2` 항목의 타입도 본다.
- **러너가 프로필 frontmatter 를 허용 문법으로만 읽는다.** 모든 줄이 한 줄에 완결돼야 한다 — 맨 식별자 키 · 줄 안에서 닫히는 따옴표와 괄호 · 블록 스칼라 · 앵커 · 태그 · 따옴표 키 없음. 그 밖은 `profile_parse_ambiguous` 로 멈추고 codex 를 부르지 않는다. 같은 매핑의 중복 키와 러너가 읽는 필드의 부재(`profile_field_missing`)도 멈춘다. 새 모양마다 새던 옛 모호 모양 탐지기는 지웠다. 러너-게이트 등식 락이 러너가 읽는 모든 필드를 추출 지점에서 도출해 대조한다. 문법이 좁아서 생기는 주의는 위 업그레이드 주의 셋째다.
- **P21 preamble 파일이 없거나 비었으면 러너가 `preamble_missing` 으로 멈춘다.** 전에는 주입 경계 절 없이 codex 를 부르고 실패 없음으로 기록했다. codex 프롬프트 순서를 형제 빌더와 같게 맞추고 흉내 가능한 권위 문구를 뺐으며, P21 지배 락(quality-gates `test_codex_prompt_untrusted_clause.sh`)의 모집단에 엔진 러너를 넣었다.
- **variant 판정기(`shared/tests/variant_of.py`)가 frontmatter 를 허용 목록 줄 문법으로 읽고 PyYAML 과 키 집합을 대조한다.** 전에는 LF 밖 줄바꿈(CR · NEL · U+2028 · U+2029) 뒤나 안 닫힌 따옴표 값 뒤에 숨긴 최상위 키를 YAML 은 읽는데 판정기와 락 다섯이 통과시켰다. 숨긴 키에는 `tools` 도 들 수 있다 — `tools` 가 없으면 agent 는 도구 전체를 상속한다(Law 2). 이제 문법 밖 줄 · 그 네 문자 · 탭 시작 줄은 판정 불가이고, PyYAML 을 import 할 수 없어도 판정 불가(`pyyaml_unavailable`)다. 추적되는 모든 agent 정의 파일에 그 네 문자를 금지하는 파일 전체 락도 섰다(`shared/tests/test_variant_of_contract.sh`).
- **공유 중복 락(`shared/tests/test_no_new_duplication.sh`)에 면제 ③ — 락 약화라 보안 리뷰를 거쳤다.** `variant-of:` 표지 쌍이고 agent 정의 파일로 한정된다. `variant_of.py` 가 두 파일이 이름 · 설명 · 도구와 삽입 블록 하나만 다른지를 이 락 안에서 판정한다. 표지 계약 락 `shared/tests/test_variant_of_contract.sh` 가 모든 표지를 범위 · 대상 실재 · 관계로 잰다.

## [3.0.1] — 2026-09-13

### Changed

- **GC 의 루트 락과 루트 탈출 판정이 공용 정본으로 옮겨갔다.** `scripts/spec-distill-gc.py` 가 직접 쓰던 루트 디렉토리 fd 락은 `gc_common.locked_root` 가, 루트 탈출 판정은 `gc_common.root_escapes` 가 한다. `state_path.state_root_escapes` 는 없어졌고 두 호출자(GC · SessionEnd 정리 훅)가 그 함수를 직접 부른다 — `state_path.py` 는 설치본 펜스가 홀로 부르는 CLI 라 `gc_common` 에 기대지 않게 뒀다. 이관 자체는 동작을 바꾸지 않는다(바뀐 두 가지는 아래 Fixed). quality-gates 7.5.3 이 같은 함수로 자기 GC 의 같은 결함을 고친다. `scripts/gc_common.py` 사본을 정본에 맞췄다.

### Fixed

- **3.0.0 이 공용 락 `shared/tests/test_skill_reference_pointers.sh` 를 RED 로 남겼다.** `reviewing-spec` 의 두 `PROFILE=` 줄(`## 프로필` · codex 게이트 펜스)이 `$SD/references/…` 모양이 되어, 그 락이 알아보는 포인터 접두사(`${CLAUDE_PLUGIN_ROOT…}/…` · `plugins/<p>/…` · `(../)*references/…`) 밖으로 나갔다 — 락은 모르는 접두사를 재해석하지 않고 거부한다. 두 줄을 `${CLAUDE_PLUGIN_ROOT:-$SD}/references/…` 로 바꿨다. 실행 시 값은 같다 — 이 형태는 로드 시 치환되지 않고 Bash 환경에 `CLAUDE_PLUGIN_ROOT` 가 없으면 `$SD` 로 풀린다. 3.0.0 의 검증이 spec-distill 스위트와 공용 락 둘만 돌려 이 락을 보지 못했다.
- **GC 가 매달린 루트 링크에서 조용히 끝났다.** 존재 검사가 탈출 판정보다 앞이라, `.claude/spec-distill` 이 없는 곳을 가리키는 링크면 거부 줄 없이 끝났다. 이제 탈출 판정이 먼저다 — realpath 는 없는 경로도 풀므로 `.claude` 가 없는 저장소는 거부되지 않는다.
- **거부 줄 두 곳(GC · SessionEnd 정리)이 링크 대상 경로를 옮겨 적었다.** 저장소가 정한 문자열이다. 이제 「state root '<루트>' 가 심볼릭 링크를 거쳐 제자리 밖으로 풀린다」로 끝나고 대상은 적지 않는다. 앞머리(`[spec-distill] GC 거부` · `세션 정리 거부`)는 그대로다.
- 락: `tests/test_gc.py` 의 `test_15_dangling_root_link_announced` · `test_16_refusal_line_does_not_echo_link_target`, `tests/test_session_end_cleanup.py` 의 `test_refusal_lines_do_not_echo_link_target`.

## [3.0.0] — 2026-09-13

major인 이유: **설계문서 리뷰의 자동 진입 계약이 깨진다.** Stop 훅(`hooks/review-dispatch.py`)이 턴 경계에서 `reviewing-spec` 을 강제하던 경로를 없애고, 리뷰 진입을 오케스트레이터가 인터뷰 핸드오프 문구와 skill description 을 읽고 스스로 부르는 것으로 바꾼다. 이 자리의 집행(철학 P13 의 hook)이 사라졌다는 사실을 숨기지 않는다 — 리뷰어 분리(Law 2 `tools:` allowlist)는 그대로다. 표준 흐름에서 그 훅은 이미 발동하지 않고 있었다: brainstorming 이 턴 안에서 설계문서를 커밋하고, 훅의 발견은 dirty·untracked 문서만 보았다. 설계: `docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md`.

**알려진 결과** — (1) 리뷰 진입에 강제가 없다. `/brainstorming` 직접 경로는 `reviewing-spec` description 하나에 기댄다 — 건너뛰면 `/spec-distill:reviewing-spec <경로>` 로 부른다. (2) CLAUDE.md Law 1 필수 섹션 게이트의 리포 내 구현이 0 이 됐다(사용자 결정 D10 — 유일한 구현이던 spec 모드 검사는 생산자가 없어 발동하지 않았다). (3) `spec-distill:Stop`·`:review-dispatch` 로 자동 리뷰를 꺼 둔 사용자는 리뷰가 되살아나고(advisory 가 알린다), 같은 토큰이 부수효과로 막던 TTL-GC 도 advisory 없이 다시 돈다(D9). (4) 저자 쪽 Handoff Context 계약의 기계 앵커가 사라졌다(아래 Changed). (5) deprecation window 면제의 근거가 약하다(아래 Deprecated). (6) 하니스가 skill 본문을 전혀 치환하지 않고 Bash 환경에도 `CLAUDE_PLUGIN_ROOT` 가 없으면 펜스의 플러그인 루트가 cwd 상대 `./plugins/spec-distill` 로 떨어진다 — cwd 에 그 디렉토리가 없을 때만 진입 검사가 fail-closed 로 끝나 리뷰가 돌지 않고(「모듈 부재」 → 복귀 지시), 사용자 저장소에 `plugins/spec-distill/` 이 있으면 그 저장소의 스크립트가 돈다(후속 과제). `reviewing-spec` 의 펜스가 고친 것은 bare `${CLAUDE_PLUGIN_ROOT}` 가 로드 시 치환되는 경우뿐이다.

### Added

- **`scripts/review_entry.py` — `reviewing-spec` 진입 검사.** 끄기 판정(`DEVBREW_SPEC_DISTILL_DISABLE=1` · `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` · `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`)과 은퇴 스위치 공시를 stdout JSON 한 줄(`disabled` · `reason` · `advisories`)로 낸다. 새 kill switch 이름 `spec-distill:review-entry` 가 여기서 생긴다 — 공용 헬퍼 `kill_switch_active` 가 이름을 요구하고, 이름은 스크립트 이름을 따른다(`spec-distill-gc` 와 같은 관례). skill 이름 `reviewing-spec` 을 쓰지 않은 이유: `check_names.py` 가 README 참조를 skill 이름으로도 해소해 수신처가 사라져도 매달림으로 잡히지 않는다. 락: `tests/test_review_entry.py`.
- **`reviewing-spec` 의 두 리터럴 펜스.** 진입 펜스(`<!-- review-entry:begin -->`)가 `review_entry.py` 를 부르고 모듈 부재 · rc≠0 · JSON 파싱 실패 · 스키마 위반(최상위 객체 · `disabled` boolean · `reason` 문자열|null · `advisories` 문자열 배열)을 전부 `DISABLED:entry_check_failed` 로 친다(fail-closed) — 끔 여부를 모르는 채 리뷰하면 사용자가 끈 스위치를 무시할 수 있고, 끔으로 치면 잃는 것은 자동 리뷰 한 번이다. skill 산문은 펜스 출력의 마지막 줄(판결)만 읽는다. 끔이면 판결 앞 단락이 끈 스위치를 이름으로 대고(`설계문서 리뷰가 꺼져 있다 — <사유>`), 출력 계약 검사기 자신이 죽어도 그 사실을 사유 줄로 낸다 — 검사기는 stdin 을 UTF-8 로 읽고 stdout 을 UTF-8 로 써서 `PYTHONIOENCODING=ascii` 같은 환경에서도 한글 advisory 에 죽지 않는다. 진입 펜스는 skill 에서 맨 먼저 — 인자 해석·후보 제시보다 앞에 — 돈다. 미커밋 펜스(`<!-- uncommitted-check:begin -->`)는 승인 게이트 ①/② 직전에 `git -C <dir> status --porcelain --ignored --untracked-files=all -- <basename>` 을 돌려(`--untracked-files=all` 이 사용자의 `status.showUntrackedFiles` 설정을 덮는다), rc≠0(작업 트리 밖 · git 오류)이면 그 사실을, 출력이 있으면 미커밋을(untracked · gitignore 된 문서 포함) advisory 로 낸다 — 출력이 비었다는 이유로 깨끗함으로 읽지 않는다. `$spec_path` 가 비면(Bash 호출마다 새 셸이라 대입이 안 넘어온 경우) git 을 돌리지 않고 입력 부재를 댄다. 경로가 working-tree 에 없어도 git 을 돌리지 않고 대상 부재를 댄다 — 저장소 안의 없는 파일에 git 은 rc 0 · 빈 출력을 내서 깨끗함과 구별되지 않는다. 락: `tests/test_reviewing_spec_entry_fence.sh`(진입 · 상태 디렉토리 · 미커밋 · 후보 펜스를 잘라내 실행). 진입 펜스의 플러그인 루트는 로드 시 치환되는 `${CLAUDE_PLUGIN_ROOT}` 를 기본값으로 쓰고, 치환이 없고 변수도 없을 때만 `./plugins/spec-distill` 로 떨어진다 — Bash 도구 환경에는 `CLAUDE_PLUGIN_ROOT` 가 없어서, cwd 상대 경로만 두면 devbrew 밖에서 진입 검사가 늘 「모듈 부재」로 끝난다.
- **부재 락 `tests/test_review_hook_removed.py`(AC1 · AC2 · AC7).** 검사 목록을 손으로 적지 않는다 — base 커밋의 삭제 파일에서 파일 이름 · 공개 이름 · 상태 키 · 환경변수 · 하이픈 문자열을 도출하고, base 에서 이 변경이 손대지 않은 파일에 이미 나오는 이름은 살아 있는 어휘로 뺀다. 면제 코퍼스는 역사(CHANGELOG · archive · 설계·계획·인터뷰 문서 · 날짜 붙은 감사) + 은퇴 토큰 리터럴(`review_entry.py` · 그 테스트 · 진입 펜스를 은퇴 토큰 값으로 실행하는 `tests/test_reviewing_spec_entry_fence.sh` · README 은퇴 절에서 토큰 리터럴만)이다. 전체 형태의 은퇴 토큰(`spec-distill:` · `DEVBREW_` 로 시작하는 것)은 도출과 무관하게 늘 스캔 집합에 들어가고 살아 있는 스위치로도 빠지지 않는다 — 가려지는 것은 그 면제 자리에서뿐이다. 개념 별칭 13개(`Stop 훅` · `mandate` · `arm-once` · `구조 검증` 등)는 spec-distill 배포 파일과 설계 §5 공용 파일로 한정해 잰다. 양성 대조로 base README(변경 전)에서 잔존을 실제로 잡는지 확인한다. **재지 못하는 것**: 수정 목록(`EDITED`)에서 빠진 인용 파일이 있으면 그 파일이 인용한 이름은 살아 있는 어휘로 오인된다 — 제외 목록과 사유 파일을 출력한다.

### Changed

- **TTL-GC 기동자가 SessionEnd 훅으로 옮겨왔다.** 그전의 유일한 기동자는 삭제된 Stop 훅이었다. `hooks/session-end-cleanup.py` 가 ① 자기 kill switch → ② 끝나는 세션의 폴더 삭제 → ③ `finally` 에서 `fire_and_forget_gc()` 순으로 돈다 — payload 가 JSON 이 아니거나 sid 가 없거나 stdin 디코딩이 실패해도 GC 는 돈다. 그래서 **`DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd`(와 `:session-end-cleanup`)는 이제 세션 정리와 TTL-GC 를 함께 끈다** — GC 만 끄려면 `spec-distill:spec-distill-gc`. GC 의 루트는 옛 훅과 같이 프로세스 cwd 의 state root 다. `fire_and_forget_gc` 는 이름과 달리 동기(timeout 5초)라 훅 timeout 을 넘기면 끊기는 것은 맨 뒤의 GC 뿐이다. `tests/test_session_end_cleanup.py` 의 `run_hook` 은 이제 `cwd` 를 필수로 받는다 — 비우면 러너 cwd 의 실제 상태 루트에서 GC 가 돈다.
- **Handoff Context 두 락이 리뷰어 쪽만 잰다.** `test_handoff_context_empty_subsections.sh` · `test_handoff_conversation_reference.sh` 는 저자 쪽 계약의 정답 출처로 `templates/spec-template.md` 를 썼다. 템플릿이 사라져 두 락은 `design-doc.md` 프로필(`defer_target` · `handoff_incomplete` rubric)만 잰다. **잃은 것**: Handoff Context 를 `TL;DR` · `Implicit context` · `Deferred to plan` 세 항목으로 쓰라는 저자 지시와 「대화 컨텍스트 가정 금지」 지시의 기계 앵커. brainstorming 은 그 템플릿을 읽지 않았으므로 실제 저자에게 닿던 지시는 아니었다.
- **`reviewing-spec` 입력 계약.** 설계문서 경로는 **호출 인자**다. 인자가 없으면 설계문서(`-design.md`)를 추가한 최근 커밋 50개에서 나온 것 중 최신 5개와 untracked 전부를 후보로 보이고 고르게 한다 — 고르지 않으면 대상 부재 경로다. 후보 펜스(`<!-- review-candidates:begin -->`)의 두 git 호출은 `-c core.quotePath=false` 로 한글 등 비-ASCII 파일명을 인용 없이 낸다(기본값이면 8진 인용된, 실재하지 않는 경로가 나온다). 두 줄 모두 working-tree 에 실재하는 경로만 낸다 — `git rm` 으로 지워진 설계문서는 목록에 나오지 않고 최신 5개 자리를 차지하지 않으며, 저장소 경로에 `&` 가 있어도 경로가 깨지지 않는다. 상태 리졸버가 없거나(플러그인 루트 미해석) 세션 상태 디렉토리를 풀지 못하면(session id 또는 state root 미해석) 그 원인을 소리 내고 끝난다 — 대상 부재의 하위 경우다. 옛 mandate 의 `mode:` 슬롯은 없다(프로필은 `design-doc.md` 고정). 게이트 없이 끝나는 두 경로(대상 부재 — 상태 리졸버·session id 출구 포함 · 진입 검사의 끔 — 검사 실패 포함)의 advisory 는 같은 복귀 지시로 끝난다: 「리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).」 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` 의 집행 지점이 옛 `resolve_mode.py` 에서 이 진입 검사로 옮겨 오며 **뜻이 끄는 쪽으로 넓어졌다** — 예전에는 자동 리뷰와 구조 검사만 껐고 수동 호출은 살아 있었지만, 이제는 수동 호출까지 끈다. content-aware 판별(접미사 없는 `.md` 를 frontmatter 로 design 분류)도 함께 없어졌다. `test_reviewing_spec_state_keying.sh` 는 sid·`STATE_DIR` 도출만 잰다(원장 호출 창 단언은 대상과 함께 지웠다). `test_reviewing_spec_design_only.sh` 의 양성 단언은 「프로필 `design-doc.md` 고정」 문장으로 증인을 옮겼다.
- **`reviewing-spec` 의 두 `Read ${CLAUDE_PLUGIN_ROOT}/references/…` 줄**(`## 절차` 의 `reviewing-document.md` · `## 게이트` 의 `proceed-gate.md`)이 `${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}` fallback 을 잃고 bare 형태가 됐다 — bare 형태는 skill 로드 시 하니스가 치환하고, `:-` 를 낀 형태는 치환되지 않는다. 같은 이유로 나머지 bash 펜스의 다섯 줄(`## 입력` 상태 펜스의 둘 · `## 프로필` · codex 게이트의 `SD=` · `PROFILE=`)은 진입 펜스의 관용구 `SD="${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}"; [ -n "$SD" ] || SD="./plugins/spec-distill"` 를 그대로 쓴다 — 플러그인이 cwd 밖에 있고 변수가 없는 설치본에서 진입 검사는 통과하는데 `## 입력` 이 상태 리졸버를 못 찾아 리뷰가 거기서 끝났다. 리졸버가 없으면 `## 입력` 은 이제 그 원인을 댄다(「상태 리졸버 부재: <경로> (플러그인 루트 미해석)」 + 같은 복귀 지시). 락: `tests/test_reviewing_spec_entry_fence.sh` 의 설치본 흉내(cwd 밖 플러그인 · 변수 없음 · bare 만 치환)와 무치환 변형.
- **핸드오프가 리뷰 순서를 싣는다.** 인터뷰 종료 게이트의 ① `/compact` 템플릿 「다음 단계:」, ② brainstorming 호출 프롬프트, brief 템플릿 §7 이 brainstorming → 설계문서 작성·커밋 → 그 경로로 `spec-distill:reviewing-spec` → 승인 게이트 뒤 writing-plans 순서를 적는다. ② 는 「brainstorming 의 『다음은 writing-plans 뿐』 지시보다 이 순서가 우선한다」와 「reviewing-spec 이 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다」를 함께 싣는다 — brainstorming 은 spec-distill 을 모르므로 규약의 거처는 호출 프롬프트다(`finishing.md` 「규약의 거처 (C5)」). ① 은 compact 요약이 운반자라 손실이 있을 수 있다. `reviewing-spec` 의 description 은 「brainstorming 이 설계문서를 쓰고 커밋한 직후, writing-plans 전에 쓴다 · 사용자 리뷰 게이트를 대신한다 · 경로를 인자로 받는다」로 바뀌었다 — `/brainstorming` 직접 경로는 이 한 줄에 기댄다. 락: `tests/test_review_handoff_order.sh`(정적 — 문구의 존재와 순서만 잰다).
- **삭제된 대상을 현재형으로 가리키던 인용 여섯을 고쳤다** — `scripts/state_path.py`(session-id CLI 주석) · `scripts/check_brief.py`(docstring 의 「같은 층」 비교) · `skills/reviewing-brief/SKILL.md`(「훅이 읽는 파일과 같은 리졸버」) · `shared/docreview/scripts/docreview_state.py`(`state.local.md` 소유자) · `shared/codex/codex_prompt_common.py` 와 사본 둘(형제 관용구 인용) · `tools/adjudication/check_names.py`(`dispatch` 가 든 키 이름의 예). `scripts/hook_common.py` 의 모듈 docstring 은 소비자 목록을 현재 둘로 다시 썼다. 동작 무변경. quality-gates 는 사본·링크 때문에 7.5.2 로 함께 bump.
- **README.** 흐름도의 Stop 상자를 「오케스트레이터가 그 경로로 reviewing-spec 호출 — 훅 강제 없음」으로, Principles Instantiated 에서 훅·원장·구조 검증 서술을 걷고 「리뷰 진입은 집행이 아니다」(P13 기준 이 자리의 집행 소실)와 「Law 1 필수 섹션 게이트 구현 0」을 명시했다. Hooks Installed 는 SessionEnd 한 행(TTL-GC 기동 포함, 스위치가 두 층을 함께 끈다), kill switch 절은 「먼저 — 설계문서 리뷰를 끄는 법」 + `DESIGN_MODE_DISABLE` 재정의 + `spec-distill:review-entry` 추가, 은퇴 절은 3.0.0 토큰 둘을 더하고 v0.36.0 항목의 「끄려면 `spec-distill:Stop`」 권고를 걷었다(훅 삭제 뒤 거짓이 되는 문장). 「발견의 한계」 · 「행동 케이스 테스트」 · 「무엇이 리뷰의 범위를 정하는가」 절은 대상과 함께 지웠다. `tests/test_readme_sync.sh` 의 키워드는 `armed_paths` · `arm-once` → `spec-distill:review-entry` · `review_entry.py`. Prerequisites 의 `jq` 줄도 뺐다(쓰는 파일이 없다).

### Deprecated

- **one-minor deprecation window 를 두지 않고 한 번에 제거한다(사용자 결정 D3).** 근거는 선례(이 파일의 환경변수 어순 통일 항목)와 같은 조건이다 — 현재 제3자 설치가 없다(CLAUDE.md §메타데이터의 one-minor deprecation window 와의 충돌을 그 조건 아래 수용). 확인 시점의 사실: 리포 PUBLIC · fork 0 · star 0 (2026-09-10). **이것은 설치가 없다는 증명이 아니다** — PUBLIC 리포는 누구든 마켓플레이스로 추가할 수 있다. **제3자 설치가 확인되면 이 근거가 바뀐다** — 그때는 다음 제거에 예고 릴리스를 둔다.
- 다른 선례(`project-init` 의 docs-lint 훅 제거 · quality-gates)가 window 면제에 함께 쓴 「기능이 사라졌으므로 조용한 재활성화가 일어날 수 없다」는 **여기서 성립하지 않는다 — 이 제거는 끈 것을 되살린다.** `DEVBREW_SKIP_HOOKS=spec-distill:Stop` · `:review-dispatch` 로 자동 리뷰를 꺼 둔 사용자에게 설계문서 리뷰가 다시 돌고(D9 — 은퇴 토큰은 리뷰를 막지 않는다), 같은 토큰이 부수효과로 멈추던 TTL-GC 도 다시 돈다. 그래서 `reviewing-spec` 의 진입 검사(`scripts/review_entry.py`)가 리뷰를 부를 때마다 사용자의 토큰을 되읽는 advisory 를 내고 살아 있는 끄기 스위치(`DEVBREW_SKIP_HOOKS=spec-distill:review-entry` · `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`)를 댄다. TTL-GC 재개에는 advisory 가 없다.

### Removed

- **`hooks/review-dispatch.py`(Stop 훅)와 `hooks/hooks.json` 의 `Stop` 항목.** 발견(`git status` 로 dirty·untracked 문서) → Layer 1 구조 검증 → 다음 턴 `reviewing-spec` 강제의 셋이 함께 사라진다.
- **그 훅만 쓰던 코드**: `scripts/arm_ledger.py`(arm 원장 — 같은 문서의 반복 강제를 막던 `armed_paths` · `inflight_paths` · `dispatch_attempts`) · `scripts/discover_candidates.py`(발견) · `scripts/parse_spec_structure.py` + `scripts/ambiguity-blacklist.txt`(구조 검증 — placeholder 4토큰 · 영어 모호어 10개 · spec 모드 필수 섹션) · `scripts/resolve_mode.py`(content-aware 모드 판정) · `templates/spec-template.md` · `scripts/hook_common.py` 의 `LAST_DISPATCHED_RE` · `parse_iso` · `state_file_for` · `configure_utf8_streams`.
- **`state.local.md` 필드**: `last_dispatched_at` · `armed_paths` · `inflight_paths` · `dispatch_attempts` · `validation_attempts` · `discovery_cursor` · `git_unavailable_advised` · `retired_token_advised`.
- **환경변수 `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`** — 끄기 스위치가 아니라 조율 값이라 advisory 대상이 아니다. README 스위치 목록에서도 뺐다.
- **테스트 13 · fixture 9** — 삭제된 코드만 재던 것(`test_arm_ledger.py` · `test_arm_ledger_timing.sh` · `test_arm_once.sh` · `arm_test_helpers.sh` · `test_discover_candidates.py` · `test_discovery_driven_dispatch.py` · `test_parse_spec_structure.sh` · `test_resolve_mode_scope.sh` · `test_review_dispatch.sh` · `test_review_dispatch_design_mandate.sh` · `test_review_dispatch_disposition.sh` · `test_stop_absorbs_validation.py` · `test_write_path_behavior.sh`, fixture 는 이들만 쓰던 7개 + `shared/tests/fixtures/adjudication/` 의 둘). `test_hook_output_schema.py` 는 NG9 cross-resolver 케이스만 남는다 — 은퇴 스위치 케이스는 `test_review_entry.py` 로 옮겼다. `test_stale_terms.sh` V11(원장·훅 본문의 존재 요구)은 대상과 함께 지웠다.
- **공용 도구의 삭제된 훅 항목** — `tools/adjudication/check_wiring.py` 의 `EXEMPT` 열 자리 · `TERMINAL_CONSUMERS` 한 항목 · 사유 상수 다섯. `EXEMPT_BASELINE` 과 `test_adjudication_wiring.sh` 의 `COMP_BASELINE` 은 삭제 뒤 스캔으로 재계수했다. 두 락(`test_adjudication_consumed.sh` · `test_adjudication_wiring.sh`)의 `# guards:` 에서 `plugins/*/hooks/*.py` 를 뺐다 — 그 글롭이 덮던 유일한 파일이 삭제된 훅이었다.
- **`reviewing-spec` 의 `## 원장` 절** — `mark-reviewed` · `check-born` · `clear-inflight` A/B 네 호출과 `$STATE`(원장 파일)·「read==write 디렉토리 불변식」 서술. `check-born` 이 사용자에게 주던 미커밋 advisory 만 원장 없이 남긴다(위 Added).

### Security

- **TTL-GC 와 SessionEnd 정리가 심볼릭 링크를 거쳐 풀리는 state root 를 거부한다.** 저장소가 `.claude/spec-distill`(또는 `.claude`)을 링크로 커밋하면 — 예: `.claude/spec-distill -> ../..` — state root 가 저장소 밖으로 풀린다. GC 는 그 너머에서 세션 이름 패턴(`^[A-Za-z0-9_-]{8,}$`)에 맞고 직속 파일이 TTL(24시간)보다 늙은 디렉토리를 개명·삭제했고 `.gc.lock` 을 저장소 밖에 만들었다(실측: 클론 옆 형제 디렉토리 삭제). SessionEnd 정리도 payload sid 와 이름이 같은 링크 너머 디렉토리를 나이와 무관하게 지울 수 있었다. 판정은 `scripts/state_path.py` 의 `state_root_escapes` 한 곳이다 — 루트의 realpath 가 `realpath(루트의 조부모)/.claude/spec-distill` 과 다르면 거부한다(조상 경로의 링크, 예: macOS `/tmp` → `/private/tmp` 는 양쪽이 같이 풀려 통과한다). `scripts/spec-distill-gc.py` 는 락을 잡기 전에, `hooks/session-end-cleanup.py` 는 삭제 전에 거부하고 stderr 한 줄로 알린다. 훅은 rc 0 으로 끝난 GC 의 stderr 도 옮긴다 — 그전에는 rc≠0 일 때만 옮겨서, rc 0 인 GC 의 거부 줄은 버려졌다. GC 는 루트 안의 링크 자식도 세션 폴더로 보지 않는다. 공용 `gc_common.safe_rmtree` 는 바꾸지 않았다 — 그 경로 검증만 realpath 로 굳혀서는 루트 자신이 링크인 경우가 닫히지 않는다(루트와 대상이 같은 링크를 거쳐 함께 풀린다). **3.0.0 이전에도 있던 결함이다** — 삭제된 리뷰 훅이 턴마다 같은 GC 를 돌렸다. 락: `tests/test_session_end_cleanup.py` 의 `SymlinkedStateRootTest`(양성 짝은 같은 파일의 `test_9_gc_collects_stale_other_session`) · `tests/test_gc.py` 의 `test_13`·`test_14`.
- **TTL-GC 가 락 파일을 쓰지 않고 state root 디렉토리 자신을 잠근다.** GC 는 루트 아래 고정 이름 `.gc.lock` 을 만들고(`touch`) 쓰기 모드로 열었다(`open(…, "w")` — `O_CREAT | O_TRUNC`). 둘 다 링크를 따라가므로, 저장소가 진짜 `.claude/spec-distill/` 디렉토리 안에 `.gc.lock -> ../../../<파일>` 링크를 커밋하면 SessionEnd 한 번에 저장소 밖 파일이 잘렸고(실측: 32바이트 센티널 → 0바이트) 매달린 링크면 저장소 밖에 파일이 생겼다. `.gc.lock` 을 디렉토리로 심으면 `open` 이 실패해 GC 가 영구히 멈췄다. 이제 GC 는 루트를 `os.open(root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)` 로 열어 그 fd 에 `flock` 을 건다 — 루트 아래 이름을 만들지도 열지도 않으므로 심은 `.gc.lock`(링크든 디렉토리든)은 무시된다. 이 열기가 실패하면(루트가 디렉토리가 아니거나 열 수 없을 때 — 검사 뒤 링크로 바뀐 경우 포함) stderr 한 줄로 거부한다. 앞 항목의 판정과 함께, 링크가 저장소 **안**을 가리켜도(`.claude` 나 `.claude/spec-distill` 이 링크) 정리와 GC 가 멈춰 상태 폴더가 쌓인다 — 신호는 SessionEnd stderr 뿐이다. 사용자 루트에 이미 남은 `.gc.lock` 파일은 해가 없다(세션 이름 패턴에 맞는 디렉토리가 아니다). **3.0.0 이전에도 있던 결함이다.** 락: `tests/test_gc.py` 의 `GcLockLeafTest`(심은 링크 · 매달린 링크 · 디렉토리 · 락 파일 부재와 수집 · 루트 디렉토리 락 경합) · `tests/test_session_end_cleanup.py` 의 `test_planted_gc_lock_link_not_followed`(훅 경유).

## [2.0.0] — 2026-09-11

major인 이유: **dispatch 가능한 agent 하나(`spec-distill:depth-auditor`)가 사라지고, 인터뷰의 라운드 형식과 audit §2 형식이 바뀐다.** 인터뷰 종료 직전의 사후 깊이 측정(Step A.7) 전체와, 그 측정이 읽던 라운드 형식(«직전 답에서» 블록 + 질문 둘)을 제거했다. 라운드는 «지금 이해 / 다음 결정 / 질문 하나»로 돈다. 사용자 결정(2026-09-10)의 이유는 셋이다 — 쓰이지 않는 무게(0.57.0 도입 뒤 측정 기록 0건 · 사람 e2e 미실행), 인터뷰가 번거로움, 방향이 틀렸다. 설계: `docs/superpowers/specs/2026-09-10-remove-depth-audit-design.md`.

### Removed

- **사후 깊이 측정 층 전체** — `agents/depth-auditor.md` · `scripts/depth_pairs.py` · `scripts/depth_record.py`, 그 테스트 셋(`test_depth_pairs.py` · `test_depth_record.py` · `test_depth_auditor_frontmatter.sh`)과 fixture 11개(`tests/fixtures/depth-state-*.md`), 측정 원장 디렉토리 `docs/superpowers/interview/depth/`. 함께 사라진 것: `finishing.md` Step A.7 절, 종료 시 사람 라벨 질문(≤4개), proceed 게이트 질문의 «깊이:» 슬롯, audit §2 의 깊이 네 줄.
- **판정자 투입 조건**(누적 5건 · not_dug 30% · 일치 70%) — 닫힘 거부권 에이전트를 언제 들일지 알려 주던 유일한 신호였다(설계 OQ3 로 이월).
- **라운드의 «직전 답에서» 블록과 질문 둘** — 네 줄(함의 · 상충 · 확인한 사실 · 위험) 블록, Q1 되비추기 확인 · Q2 새 결정, Q1 수정 시 재되비추기, Q2 독립성 규칙, 인자 없는 경로의 R1 블록 면제, «되묻기로 바뀌는 조건» 절, `steelman.md` 의 «상충 줄에도 한 줄로 싣는다» 문단.
- **`provisional_on`** — `user_statements` 스키마 필드와 그 규칙. 진행 중 세션에 남은 필드는 읽는 자가 없어 무해하므로 마이그레이션을 두지 않는다.

### Changed

- **라운드 규약** — `## R<n>` 한 라운드 = 지금 이해 / 다음 결정 / 질문 / 답. AskUserQuestion 1회에 질문 1개, 첫 선택지가 추천(`(권장)`). 약한 답(보류 · 한 단어 · 이유 없는 추천 수락 · 근거 없는 단정)에는 이유 · 사례 · 실패 조건 중 하나를 되묻고, 같은 주제의 연속 되묻기는 최대 2회다(그 뒤엔 기록하고 넘어간다 · 차원을 자동으로 닫지 않는다). 한 라운드에 겹치면 되묻기 → 외부 근거 처분 → 새 결정 순. `references/steelman.md` 가 묻는 질문은 그 파일의 규약을 따른다.
- **옮겨 간 규칙 다섯** — 닫힘 근거(«그 차원에 관한 질문에 사용자가 답한 S» — blind-spot-prober 절의 전이 문장도 처분 S 뒤로 맞췄다) · landscape 닫힘 발화(«외부 근거 처분 S», SKILL · `finishing.md` 양쪽) · 재개방 표시 자리(«상충» 줄 → 그 라운드의 «지금 이해». `reopen_log` · audit §1 접미는 그대로) · seed «다시 검증할 것» 문단의 소비 자리(R1 «지금 이해»·질문의 재료 + coverage-mapper 첫 dispatch 입력 — `seed-input.md` · `framing-requests` · seed 템플릿) · C43 경로 표시 자리(«지금 이해»·«질문»).
- **audit 템플릿 §2** — 데이터 줄 하나(질문 라운드 · agent dispatch · coverage-mapper `<k>` · codex 실호출). 게이트가 보는 `coverage-mapper <k>` 는 그대로다.
- **proceed 게이트 질문 텍스트** — «깊이:» 슬롯 제거. `check_brief` advisories 슬롯은 유지.
- **`shared/tests/test_adjudication_wiring.sh` 의 `COMP_BASELINE` 58 → 52** — `depth_record.py` 가 더했던 컴프리헨션이 파일과 함께 사라졌다(`ast` 실측).
- **락** — `tests/test_stale_terms.sh` V13(식별자 축은 README 포함 · 개념 별칭 축은 README 제외 · 새 라운드 규약의 양성 짝 둘) · V10 부재 목록 20 → 37 · `test_conducting_interview_stage.sh` 의 라운드 규약 · 닫힘 · 재개방 · landscape 발화 · blind-spot 전이 · seed 문단 · C43 경로 표시 락을 재조준 · 신설 · `test_request_framing_command.sh` 의 seed 문단 소비 락 · `test_finishing_block_scope.py` 의 양성 대조를 남는 펜스의 게이트 호출로 · `test_brief_agents.sh` 격리 목록 5 → 4.

### Deprecated

- `spec-distill:depth-auditor` agent · 두 측정 스크립트 · 옛 라운드 형식 · audit §2 깊이 네 줄은 **fallback 없이 즉시 제거**됐다 — CLAUDE.md 메타데이터의 one-minor deprecation window 규정과 충돌한다. 이 충돌을 다음 조건 아래 수용한다: 이 플러그인의 제3자 설치가 현재 없다(사용자 확인, 2026-09-10). **제3자 설치가 생기면 이 근거가 사라지므로, 그 뒤의 제거에는 창을 둔다.**

### Verification

- **회귀 0** — spec-distill 셸 스위트 · `python3 -m unittest discover -s plugins/spec-distill/tests` · `shared/tests` 를 (파일, 실패 식별자) 멀티셋으로 기록해 «완료 − 기준선 = ∅» 를 확인했다. 최종 기준선은 머지 직전에 합친 `origin/main` 끝 커밋 `bf626555`(1.2.0)이고, 기준선에 이미 있던 실패(`plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` 1건 · unittest `test_hook_output_schema.TestCrossResolverAdvisory.test_python_and_bash_resolvers_agree`)는 그대로다. task 커밋은 각각 그때의 착수 전 기준선(`efb8aa16` 을 합친 `f4e5de79`) 대비로 같은 판정을 거쳤다.
- **완료 증거** — 셸 파일마다 요약 줄(`Total: …`) 또는 기준선과 같은 마지막 출력 줄을 요구했다. 단언 없이 죽은 파일이 `(파일, rc=<N>)` 로 잡히는 것과, 기존 실패 하나를 찍고 중단된 실행이 멀티셋 비교를 통과하지 못하는 것을 합성 양성 대조로 확인했다.
- **변이** — 새로 쓰거나 고친 락을 통째 삭제 · 문구 반전 · 값 변경 · 위치 변경 · 문장 추가로 흔들어 30건을 돌렸다. 29건은 해당 단언 하나만 RED 였고, 1건(README 별칭 면제)은 의도대로 GREEN 이었다. 변이하지 않은 새 락: 라운드 규약 절의 소제목 넷 · `## R<n>` 헤딩 · description 문구 · 되묻기 세 축 · SKILL 줄 수 상한, coverage-mapper 절의 인자 없는 경로 첫 dispatch 시점, V13 의 두 번째 양성 짝, 절 추출 양성 대조.
- **사람 e2e** — 결과 미보고: 체크리스트 5항목을 안내했으나 사용자가 결과 보고 없이 릴리스 진행을 지시했다(2026-09-11). 항목별 통과/실패 기록 없음.

## [1.2.0] — 2026-09-11

minor 인 이유: `/interview` 가 새 입력 모양 `@<seed 경로>` 를 받는다 — 새 surface 다. 옛 입력(rough request · seed 전문 붙여넣기)은 그대로 동작한다.

### Added

- **`/interview` Step 1.5 — `@경로` 인자 풀기.** 앞뒤 공백을 걷은 인자가 `@` 로 시작하는 공백 없는 한 토큰이면 그 파일을 Read 로 읽어 frontmatter 포함 전문을 「풀린 입력」으로 삼고, Step 2(trivia) · Step 2.5(seed 판별) · Step 3(`Skill conducting-interview`)이 그 값을 쓴다. 읽기 실패면 사유를 담은 문구를 내고 인터뷰를 시작하지 않는다. 입구에서 직접 푸는 이유: 2026-09-10 헤드리스 실측(`claude -p`)에서 커맨드 인자의 `@경로` 는 `$ARGUMENTS` 에 리터럴로 남고 파일이 첨부되지 않았다(평문 프롬프트의 `@경로` 는 첨부됐다). 대화형 입력은 재지 않았다 — 거기서 첨부되더라도 command 본문이 읽는 것은 치환된 인자라 이 단계가 필요하다.
- `tests/test_seed_at_path_handoff.sh` — framing 옵션 표 · 호출 모양 · 두 가드 · 공유 계약(정본 자체) · Step 1.5 · 옛 호출 모양 부재(코퍼스 멤버십 양성 짝 포함) · 이름 가드 공백 거부(case 패턴을 실제로 돌린다). 단언 종류마다 삭제 · 치환 · 순서 뒤집기 · 재삽입 변이로 RED 를 확인했다.
- 실동작 확인(2026-09-11, 헤드리스 `claude -p` + `--plugin-dir`, sonnet, 1회): `/spec-distill:interview @<seed>` 가 픽스처를 절대경로로 읽고 frontmatter 포함 전문을 바꾸지 않고 `conducting-interview` 에 넘겼다(넘긴 인자 = 픽스처 전문). 「`/request-framing` 을 먼저」 조언은 나오지 않았다. 없는 경로는 부재 문구를 내고 인터뷰를 시작하지 않았다. 재지 못한 것: 첫 라운드 — 헤드리스 세션에 작업 디렉토리 밖 읽기 권한이 없어 `conducting-interview` 의 참조 파일을 읽지 못했고, 인터뷰 질문 대신 그 제약을 알리고 진행 방식을 물으며 끝났다(그 글은 seed 주제를 언급했다). Step 2(trivia 대조)도 같은 이유(`references/trivia-escape.md` Read 가 작업 디렉토리 밖이라 거부)로 관측되지 못했다. 대화형 입력도 재지 않았다.

### Changed

- **framing 게이트의 핸드오프가 `/interview @<seed 경로>` 로 바뀌었다.** 옵션은 ① `/new` 후 `/interview @<seed 경로>`(권장) · ② `/compact` 후 같은 명령 · ③ 수정 · ④ 멈춤이다. ①/② 는 두 줄 명령을 노출하고 턴을 끝낸다. 「바로 `/interview`」 옵션은 없어졌다 — `AskUserQuestion` 한 질문의 옵션 상한이 4 다. `/new` 는 `/clear [name]` 의 별칭이라 같은 줄 뒤 텍스트가 세션 이름이 되므로 두 줄을 따로 입력하게 안내한다. 권장이 `/new` 인 이유: seed 는 framing 대화를 대신하려고 존재하고, `/compact` 는 그 대화의 요약을 남긴다.
- **공유 게이트 계약(`references/proceed-gate.md`)의 ①/② 를 「권장/차선 핸드오프」로 일반화했다.** 핸드오프 종류(`/compact` · `/new` · 바로 진행)와 노출할 명령은 각 skill 이 채운다. 가드 2 는 명령을 노출하는 모든 옵션에 걸리고 바로 진행 옵션이 예외다. 가드 1 의 완료 동작은 핸드오프 종류가 정한다. Step A 는 「핸드오프 명령도 노출하지 않는다」. `reviewing-spec` · `conducting-interview` 는 새 표에 그대로 맞아 바뀌지 않았다. **이 릴리스가 닫지 않는 것**: 두 skill 의 가드 1 문면(「①/② 선택 후 … 다음 단계 진입을 skip 하면 polite stop」)이 자기 ① 의 정지 요건과 어긋나는 것은 이번 변경 전부터 있던 불일치다.
- framing 의 이름 가드(`TOPIC` · `IV_NAME`)가 공백을 거부한다 — seed 경로가 한 토큰이어야 `/interview` 가 `@경로` 로 푼다. 공백 든 경로를 사람이 손으로 넘기면 Step 1.5 는 발동하지 않고 거친 요청으로 받는다.
- 옛 핸드오프(「다음 세션 첫 턴에 붙여넣는 메시지」)를 풀어 쓴 문장을 `commands/request-framing.md` · `conducting-interview/references/seed-input.md` · `finishing.md` 의 S1 문장 · `templates/interview-seed-audit-template.md` · README 흐름도에서 새 모양으로 바꿨다. README 의 v0.41.0 이력 단락은 그 버전이 한 일의 기록이라 그대로 뒀다.

## [1.1.0] — 2026-09-10

### Changed

- **steelman 게이트가 추천을 출처별로 표시한다 — 재결정.** `skills/conducting-interview/references/steelman.md` Step 3 의 질문 규칙. 선택지 순서(유지 / 보완 / 전환 / 보류)는 고정 그대로이고 추천을 첫 자리로 옮기지 않는다. 표시는 선택지마다 붙는다 — builder 가 추천한 선택지, orchestrator 판정 선택지, 두 추천이 같은 선택지면 공동 라벨 하나. 확인된 전제 충돌이 0건인데 builder 가 전환을 추천하면 그 전환 라벨에 「전제 충돌 없음」이 함께 붙는다 — Step 2.5 의 전환 봉쇄는 추천·라벨 층에 있으므로, 게이트 선택지에 표시가 생기면 봉쇄도 거기까지 따라가야 표시가 봉쇄를 무력화하지 않는다. 출처 라벨이 유일한 추천 표시다 — 도구(`AskUserQuestion`)와 이 skill 라운드 규약의 기본 추천 접미사는 붙이지 않는다. 1.0.1 까지는 도구 쪽 접미사만 금지했고, 라운드 규약의 접미사 금지는 이번에 새로 들어갔다. web 부재 시의 수동 의심 게이트는 builder 추천이 없어 바뀌지 않는다.
  - **재결정 기록 (P23).** 원래 — C11(`docs/superpowers/interview/2026-09-05-steelman-goal-fit-interview.md:185`, 사용자 발화 S12) 원문: 「builder 추천은 4-block 추천 답안 블록에 orchestrator 의견과 나란히 표시하고, 선택지는 항상 유지/보완/전환/보류 순으로 고정하며 Recommended 라벨로 첫 자리에 올리지 않는다」. S12 는 「builder 추천의 게이트 노출」 질문의 답이었다(`2026-09-05-steelman-goal-fit-interview.audit.md:252`). 0.55.0 이 그 답을 선택지에 도구 쪽 추천 접미사를 붙이지 않는 것으로 구현했다(steelman.md 도입). 기각 이유는 같은 인터뷰 §5 의 `:242`(compromise effect 와 앵커링 재현을 피한다)이고, 원천은 추천을 추천 답안 블록에「만」 두라고 명시하지는 않는다. 재결정 — 게이트 선택지에 도구 쪽 접미사만 금지하고 추천 표시는 규정하지 않던 규칙을 바꿔, 출처별 표시를 규정한다. C11 의 글자(나란히 표시 · 순서 고정 · 첫 자리 승격 금지)는 그대로 지켜진다. 근거 — 사용자 재결정(2026-09-10). 새 외부 근거는 없다. 받아들인 비용은 둘이다 — 앵커링(보이는 추천이 판단을 자기 쪽으로 끌어당긴다)에 대한 방어가 약해진다. 그리고 순서 고정은 추천이 선택지를 첫 자리로 옮기는 경로만 막는다(인터뷰 `:255` 의 확정 대응) — 보완은 순서상 여전히 가운데다. 확인된 전제 충돌이 0건이면 orchestrator 판정이 유지·보완뿐이라 그 가운데 선택지에 추천 표시가 붙을 수 있다 — 위치 효과 위에 얹히는 새 압력이다.
- **4-block 의 orchestrator 줄이 「판정 — 이유」 형식이 됐다.** 표시가 가리킬 선택지가 정해지게 하려는 것이다. 판정은 유지 / 보완 / 전환 중 하나이고 보류는 들지 않는다 — C15(보류는 게이트에서 사람만 고른다)를 그대로 지킨다. 확인된 전제 충돌이 0건이면 Step 2.5 가 이것을 다시 유지·보완으로 좁힌다.
- **`tests/test_conducting_interview_stage.sh` — 표시 규칙 락.** 질문 줄 하나를 코퍼스로, 리터럴 일곱(순서 고정·첫 자리 금지 · builder 라벨 · orchestrator 라벨 · 두 추천이 다를 때와 같을 때 · 충돌 0건 전환 라벨과 그 조건 · 기본 추천 접미사 금지 · kept/refined/switched 대응)이 그 한 줄에 함께 있는지 잰다 — 그중 출처 라벨이 걸린 넷은 조건과 라벨을 한 문자열로 묶었다. 라벨만 재면 두 출처의 라벨을 맞바꾸거나 조건을 지워도 통과하므로 묶어 잰다. 질문 규칙은 steelman.md 에서 한 물리 줄이어야 한다. 금지 문장을 도려낸 R3 블록에서 기본 추천 접미사의 부재를 잰다 — 다른 자리에 허용 문장이 새로 들어오는 것을 잡는다. R3 블록 전체에서는 orchestrator 줄 형식(보류 제외 포함)을 재고, Step 2.5 의 충돌 0건 항목 하나를 한 줄로 이어 붙여 그 항목의 두 규칙(orchestrator 판정의 유지·보완 제한 · 줄바꿈 너머의 조건까지 포함한 builder 전환 옆 라벨)을 잰다 — Step 2.5 의 두 규칙은 이번 변경 전부터 있었지만 잠겨 있지 않던 전제다. 한계 — 존재 락은 그 문자열이 정해진 자리에 있는지만 본다: 리터럴이 끝난 뒤에 덧붙인 부정, 리터럴 밖의 변경, 동의어로 바꿔 쓴 규칙은 못 잡는다. 부재 락은 R3 블록 안의 괄호형 두 접미사 리터럴만 본다. 어느 락도 모델이 실제로 라벨을 그렇게 붙이는지는 재지 않는다.

## [1.0.1] — 2026-09-10

### Fixed

- **`framing-requests` — 빈 요청일 때 첫 행동이 둘로 갈리던 것.** `/request-framing` 은 인자가 비면 「무엇을 맡기려 하시나요」로 시작한다고 적었고, skill 의 `## 워크트리 — 진입 직후` 는 워크트리 질문이 첫 행동이라고 적었다. 빈 요청에는 `feature/<kebab-topic>` 도 audit 이름도 댈 주제가 없다. 이제 순서는 skill 절 한 곳이 정한다 — 빈 요청이면 주제 질문이 워크트리 질문보다 앞서고(답으로도 주제를 못 대면 좁혀 다시 묻는다 · 워크트리를 건너뛰는 경우도 같다), 그 답들은 audit `## 1. 원문` 의 첫 항목부터 옮겨진다. «첫 행동» 문장은 그 예외를 스스로 밝힌다. command 는 주제가 먼저라는 것만 적고 나머지 순서는 그 절을 가리킨다. `tests/test_request_framing_command.sh` 에 단언 다섯(질문 앞 위치 · 건너뛰는 경로 · «첫 행동» 예외 · 원문 이관 · command 포인터).

## [1.0.0] — 2026-09-09

major인 이유: **design doc 자리(`reviewing-spec`)의 verdict 계약이 깨진다.** `approved`/`needs_revise` 산출물은 더 이상 나오지 않는다 — 승인은 문서 리뷰 엔진(`shared/docreview/`)의 게이트 판정(`approval_gate_open`, 열린 항목이 없으면 즉시 · 상한 도달·stagnation 이면 승인 게이트 1단계 경유)을 **집계**해서 도출된다. `reviewing-spec/SKILL.md` 는 235줄(base 297줄)로 재작성된 엔진 껍데기가 됐다 — 절차 8단계의 정본은 `shared/docreview/references/reviewing-document.md` 하나이고, 이 skill 에는 이 자리의 것(입력 슬롯 · 프로필 선택 · dispatch 둘 · 원장 갱신 · 게이트 진입)만 남는다. `description` 의 "design docs reviewed by a physically-separated Law 2 reviewer" 문구는 여전히 참이다 — `doc-critic`·`doc-recritic` 도 `tools:` 에 쓰기가 없다. 바뀐 것은 리뷰어의 이름뿐이다.

### Removed

- **`agents/spec-reviewer.md`** — 유일한 dispatch 자리였던 껍데기화 전 `reviewing-spec/SKILL.md` 와 함께 삭제. 대체는 `shared/docreview/agents/{doc-critic,doc-recritic}.md` 를 `# copy-of:` 마커로 바이트 동일하게 배포한 `agents/doc-critic.md` · `agents/doc-recritic.md` (심볼릭 링크가 아니라 물리 사본 — dispatch 검증상 심볼릭 링크 agent 는 실제로 호출되지 않는다).
- **`scripts/run_spec_codex_reviewer.sh`** · **`scripts/build_spec_codex_prompt.py`** — codex 병렬 co-reviewer 러너/프롬프트 빌더. 대체는 `shared/docreview/scripts/run_docreview_codex_reviewer.sh`(프로필 인자로 자리를 흡수, 심볼릭 링크 배포).
- **`DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK` (README 문서화 제거).** 이 kill switch 의 유일한 집행 지점이 `spec-reviewer.md` 였다 — 그 agent 가 사라지며 집행 지점이 0 이 됐다. 리포 전체(`shared/`·엔진 스크립트·모든 프로필·모든 skill)를 대상으로 독자를 확인했고 살아 있는 읽기 지점이 없다(전수 확인: `git grep -n`). 이 스위치가 끄던 검사(`handoff_incomplete`)는 이제 `design-doc.md` 프로필의 layer2 rubric 항목이라, 그 opt-out 은 이제 프로필을 고치는 것이다(P21 — 집행 없는 switch 를 문서화하면 "껐다고 믿게만" 만든다). `test_handoff_kill_switch.sh` 의 코퍼스를 같은 커밋에서 README 로 넓혀, 이 스위치 이름이 design 자리 표면(엔진 포함)에 재등장하면 RED 가 나도록 했다.
- 고아가 된 테스트 6개(`test_spec_reviewer_frontmatter.sh` · `test_spec_reviewer_design_checklist.sh` · `test_run_spec_codex_reviewer.sh` · `test_build_spec_codex_prompt.sh` · `test_reviewing_spec_codex_merge.sh` · `test_reviewing_spec_design_routing.sh`) — 피검자가 사라져 함께 삭제.

### Changed

- **재리뷰 상한 5 → 2.** 정본은 `shared/docreview/references/reviewing-document.md` 의 `` `rereview_cap: 2` `` 한 줄이고, `docreview_state.py` 의 `REREVIEW_CAP` · `reviewing-spec/SKILL.md` · 이 README(흐름도 + AP16, 2곳) 넷을 `test_rereview_cap_consistency.sh` 가 cross-file 로 대조한다(∀ 짝 — 옛 값 5 를 이름으로 금지하지 않고, 상한 어휘가 나오는 모든 자리의 숫자가 정본과 같은지를 잰다). 라운드 4 이상은 여전히 사용자가 승인 게이트에서 열어야만 돈다.
- **능력 축소 — design doc 리뷰의 외부 prior-art 대조가 Claude·codex 양쪽에서 동시에 0 이 됐다.** 옛 `spec-reviewer` 는 `tools:` 에 `WebSearch, WebFetch` 를 가졌고 `run_spec_codex_reviewer.sh` 는 codex 웹 검색을 기본 ON 으로 켰다. 새 `doc-critic`·`doc-recritic` 은 `tools: Read, Grep, Glob` 뿐이고 `design-doc.md` 프로필은 `web: false` 를 고정한다 — 이 결정은 설계 §5.3·OQ-C 의 의도이고 이 릴리스는 그것을 뒤집지 않는다. `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 은 이제 소비자 **둘**(interview 웹 리서치 · codex brief co-reviewer)만 끄고, design-doc 리뷰는 이 스위치의 대상이 아니다 — 프로필이 이미 꺼 놨으므로 켜고 끌 것이 없다.
- **엔진 결함 후속 수정 (PR 2, 리뷰 라운드).** `doc-critic`/`doc-recritic` 이 첫 호출자로 붙은 뒤 리뷰가 추가로 적발한 결함들 — 재상승(reraise) 후속이 원본의 `kind`·`prev_hash` 를 물려받게(원복 의무 강등 방지) · 사후 고지 꼬리(`_post_kind_notice`)가 만료된 원본뿐 아니라 후속에도 닿게 · 재상승·`escalated` 예약 양쪽의 누적·dedup·미소비 계수 통일 · 재상승 후속의 「보류」 거부(제안 선택지와 받아주는 선택지를 한 함수로) · 상태 축의 정본 표(`is_open`·`gate_summary`·`render_gate` 한 표에서 도출) · golden `fin.json` 재캡처. 전부 `shared/docreview/scripts/docreview_state.py`·`docreview_route.py` 쪽 수정이라 이 플러그인은 심볼릭 링크로 함께 받는다(cache key).

### Fixed

- **`reviewing-spec` 의 codex 게이트 펜스가 그대로는 돌지 않았다 (whole-branch 리뷰 I1).** 펜스가 러너에 넘기는 네 인자 중 `$spec_path`·`$CODEX_YAML` 둘이 그 파일 어디에서도 대입되지 않았다 — Bash 도구는 호출마다 새 셸이라 앞 펜스의 값이 오지 않는데, 펜스는 `SD`·`PROFILE` 만 다시 세우고 멈춰 있었다. 빈 산출물 경로를 받은 러너는 usage 로 **rc 2** 에 죽고, 펜스의 유일한 rc 처리(rc 3 → `rm -f`)가 그 값을 안 봐서 stale 방지가 발화하지 않았다 — 직전 라운드 YAML 이 이번 라운드 판정으로 읽히는 자리다. 셋을 고쳤다: (a) `$CODEX_YAML` 을 세션의 순수 함수로 펜스 «안»에서 도출(값이 이미 있으면 그것을 쓴다), (b) `$spec_path`(훅 mandate 슬롯이라 디스크에서 도출되지 않는다)나 산출물 경로가 비면 형제 `framing-requests` 와 같은 모양의 입력-부재 분기가 `skip_reason=gate_inputs_missing` 으로 **소리를 내고** codex 축을 건너뛴다, (c) ~~잔존물 제거 조건을 `rc == 3` 에서 `rc != 0` 으로 넓혀 「러너가 이번 실행에서 그 파일을 쓰지 못한」 모든 종료를 덮는다.~~ **〔이 릴리스에 그 규칙은 없다 — 아래 「kill switch 를 켠 라운드가…」 항목이 되돌렸다.〕** 그 근거였던 「기록을 남기는 러너 종료는 전부 exit 0」이 거짓이고(EXIT 트랩은 원래 실패의 rc 를 그대로 두고 기록을 남긴다), 넓힌 술어가 대신 막는 것은 없다. **이 릴리스가 shipping 하는 조건은 `rc == 3`** 이다. 펜스 본문을 잘라 cold shell 에서 실행해 검증했다(수정 전: 빈 인자 → rc 2 · 잔존물 잔류. 수정 후: 입력 부재 → 러너 미호출 + 공시 / 입력 있음 → 산출물 경로 도출 + codex 1회).
- **그 보안 성질에 회귀 락이 없었다 — `tests/test_reviewing_spec_residue.sh` 신설 (재리뷰 2 NEW-4).** 진입 중화를 가용성 분기 «안»으로 되돌리는 변이를 넣으면 결함이 완전히 되살아나는데 리포의 셸 락 전수가 GREEN 이었다. 이 성질은 네 번 산문으로 주장되고 **한 번도 집행되지 않았다** — 그것이 같은 자리에서 fail-open 이 반복된 이유다. 형제 `framing-requests` 가 바로 그 락(`test_seed_gate_wiring.sh` 의 `residue_case` 행렬)을 갖고 있으므로 모양을 새로 발명하지 않고 그것을 따랐다. 다만 **관측 대상이 다르다**: 형제 펜스는 산출물을 자기 안에서 읽어 stdout 으로 판정하지만 이 펜스는 읽지 않는다(소비자는 다음 Bash 호출의 5단계다). 그래서 ①펜스를 잘라 실행한 뒤 **디스크의 사후상태**(부재 또는 0바이트 — 둘 다 하류 fail-closed)를 skip 네 경로 + 러너 rc 3 에서 재고, ②한 셀은 **end-to-end** 로 `prepare-recritic` 까지 돌려 「직전 라운드 마커 0건 · `codex_absent: true`」를 기계 채널에서 직접 확인하며 파일이 애초에 없던 라운드와 **완전히 같은 판정**인지 대조한다. 부재 단언뿐이면 「언제나 지운다」가 전부 만족시키므로 **양성 짝 둘**을 함께 건다 — 러너가 이번 라운드 산출물을 쓰고 정상 종료한 경우와, 정직한 degrade 기록을 남기고 **non-zero** 로 죽은 경우(둘 다 살아남아야 한다). 락 자신의 vacuity 바닥도 뒀다: 쓰는 세션 이름이 `state_path.py` 검사를 통과하는지 먼저 확인한다 — 짧은 이름을 쓰면 도출이 조용히 실패해 「중화 안 됨」과 「아무것도 재지 않음」이 같은 모양이 되고, 이 락을 처음 돌렸을 때 실제로 셀 하나가 그렇게 무의미했다.
- **진입 중화가 「시도」였고 「보장」이 아니었다 (재리뷰 2 NEW-1).** `rm -f` 의 rc 를 보지 않아, 상태 디렉토리가 쓰기 불가면 삭제가 rc 1 로 실패하고 잔존물이 살아남아 **N1 이 수정 후에도 완전히 재현**됐다(실측: kill switch ON · items 10 · `codex_absent=False` · 직전 마커 2건). 게다가 그 상태는 두 채널이 모순된다 — 사람이 읽는 stderr 는 degraded 라 하고 기계가 읽는 채널은 codex 정상이라 한다. unlink 는 **디렉토리** 권한을, 절단은 **파일** 권한을 요구하므로 둘은 함께 실패하지 않는다는 사실을 이용해 3단으로 만들었다: 지운다 → 못 지우면 0바이트로 절단한다(하류 fail-closed) → 둘 다 실패하면 조용히 넘어가지 않고 `residue_unclearable` 사유로 codex 축을 끄고, 경로를 대며 5단계에 넘기지 말라고 알린다.
- **kill switch 를 켠 라운드가 직전 라운드의 codex 결과를 삼키고 「모델 다양성 정상」으로 보고했다 (재리뷰 N1 — 보안).** codex 산출물 경로가 세션의 순수 함수가 되면서 라운드마다 같은 파일을 가리키게 됐는데, 잔존물 제거가 `if [[ "$codex_avail" == "true" ]]` **안**에만 있었다. codex 를 건너뛰는 네 경로(kill switch · 미설치 · 감지기 부재 · 게이트 입력 부재)는 전부 그 분기에 들어가지 않으므로 직전 라운드의 YAML 이 그대로 남고, 5단계 `prepare-recritic` 은 그 파일의 `codex_failed: false` 하나로 이번 라운드 판정으로 읽는다 — 실측: 잔존물이 있으면 `codex_absent: false` · degrade 없음 · 항목 10(대조군 8), 없으면 `codex_absent: true`. **사용자가 끈 축이 켜진 것으로 보고되는 라운드**이고, kill switch 는 P21 보안 컨트롤이므로 「껐다고 믿게만 만드는」 이 상태가 결함의 핵심이다. 제거를 **가용성 판정 앞**으로 옮겨 진입 제거로 만들었다(형제 `framing-requests` 와 같은 모양). **판별자는 내용이 아니라 시점이다** — 직전 라운드의 산출물과 이번 라운드의 정직한 실패 기록은 스키마도 마커도 같아 내용으로 못 가르지만, 진입에서 지우면 그 뒤 그 자리에 있는 것은 이 실행이 쓴 것뿐이다. 그래서 무조건 제거를 분기 «뒤»로 옮기는 처방과 다르다: 러너가 `trap … EXIT`·`emit_fallback` 으로 남기는 이번 라운드의 degrade 기록은 지움 뒤에 쓰이므로 살아남아 사유를 그대로 전한다(실측: codex 가 이번 라운드에 실패하면 수정 후에도 `reason: exit_nonzero` 가 하류에 도달한다). 분기 안의 껍데기 정리는 형제와 같은 `rc == 3` 이다. **〔정정 — 앞선 판본의 근거는 거짓이었다〕** 이 자리는 한때 「기록을 남기는 러너 종료는 전부 exit 0 이라 `!= 0` 이 정직한 기록을 지우는 일은 없다」는 이유로 `!= 0` 을 썼다. EXIT 트랩은 자기 rc 를 갖는 종료 지점이 아니라 모든 종료에 얹히므로 **원래 실패의 rc 를 그대로 둔 채** 기록을 남긴다 — 실측: 트랩 무장 뒤 SIGTERM 이면 `rc 143` + `reason: aborted_before_completion` 인 정직한 기록이 함께 나온다. 그리고 `!= 0` 이 대신 막아 주는 것은 없다(껍데기가 생기는 유일한 자리는 rc 3 이고, 0바이트는 하류에서 이미 fail-closed — 실측 `codex_absent: true`). 넓은 술어는 사는 것 없이 정직한 사유만 잃으므로 `== 3` 으로 되돌렸다.
- **공유 절차서가 옛 규칙을 계속 가르쳤다 (재리뷰 N2).** `shared/docreview/references/reviewing-document.md` 4단계가 여전히 `rc 3` → `rm -f codex.yaml` 이라, 자리 셋이 이 문서를 보고 자기 펜스를 쓸 때 같은 구멍을 다시 판다. 새 규칙(진입 중화 + `rc == 3`)으로 맞추되 **값이 아니라 이유를 가르치도록** 썼다 — 왜 중화가 가용성 판정 앞이어야 하는가(skip 네 경로가 분기를 우회한다), 판별자가 왜 시점인가(내용으로는 못 가른다), 중화가 왜 「시도」가 아니라 「보장」이어야 하는가(rc 미검사면 쓰기 불가 디렉토리에서 결함이 재현된다), 그리고 왜 `!= 0` 이 아니라 `== 3` 인가(위 항목의 정정 — EXIT 트랩이 원래 실패의 rc 를 그대로 두고 기록을 남긴다).
- **같은 부류를 손-목록이 아니라 「도출」로 닫았다 — 살아 있는 인용 다섯.** 앞의 두 건을 손-목록으로 고치고도 같은 결함이 대상만 바꿔 계속 나왔다. 원인이 남은 대상이 아니라 방식이었으므로, 이 전환이 **무엇을 개명하고 무엇을 재평가했는가**(절 이름 `Phase 5` · `Steps` · `Deterministic Routing Table` · `Approve handoff sequence` · `In-flight state migration` · `Step 3`, 그리고 값 재리뷰 상한 5→2)를 base 대비 헤딩 diff 로 **도출**한 뒤, 각각의 **개념 별칭까지** 리포 전체에서 쓸었다(`git grep -n` 사용 + `.claude/` 는 명시적으로 따로 확인 — 셸 `grep -r` 은 숨김 디렉토리를 건너뛴다). 138줄이 매치했고 114줄은 역사(archive · interview · 옛 plan · past spec · CHANGELOG), 1줄은 이 PR 자신의 계획, 24줄이 심사 대상이었으며 그중 **5줄이 살아 있는 결함**이었다: 이 README 의 AP2 instantiation 둘(`:91` · `:134` — 현재형으로 없는 절을 가리키고, `:134` 는 삭제된 `Approve handoff sequence` 의 내용까지 인용했다), `scripts/arm_ledger.py` 의 CLI 주석(`reviewing-spec Step 3 (verdict)` — 절도 verdict 계약도 사라졌고 호출 시점도 승인 게이트 뒤로 옮겨졌다), 철학 P18 코드 지도(아래 항목), quality-gates 의 governance 락 주석. 나머지 19줄은 결함이 아니다 — 대상이 다르거나(`conducting-interview` 자신의 `## In-flight state migration`, brief 파이프라인의 Human Gate, `CANDIDATE_CAP` 의 `cap 5`) 개명 자체를 기록하는 문장이다. **〔이 도출의 알려진 구멍 — 이 릴리스에 잔여가 남아 있다〕** 개명 목록을 뽑을 때 헤딩 diff 가 `##`·`###` 만 보고 **`#` 를 보지 않았다.** 그래서 옛 H1 `# Reviewing Spec (Phase 3)` 이 애초에 목록에 들어오지 않았고, 그 이름을 현재형으로 인용하는 자리 둘(`README.md` 의 codex CLI 항목 · `scripts/merge_review.py` 의 모듈 docstring)이 **고쳐지지 않은 채 남는다.** 이 릴리스는 그 둘을 닫지 않는다 — 인계로 넘긴다.
- **철학 문서 P18 코드 지도가 옛 상한 값을 안고 살아남았다 — 그리고 그것을 놓친 락을 함께 고쳤다.** `docs/philosophy/devbrew-harness-philosophy.md` 의 P18 이 `reviewing-spec/SKILL.md (re-review cap 5)` 를 가리켰다: 값도 낡았고 소유자도 옮겨갔다(정본은 이제 엔진 절차서의 한 줄, stagnation 술어는 `docreview_state.py` 의 `gate_summary`). 코드 지도는 다음 세션이 원칙의 살아 있는 instantiation 을 찾는 경로라, 여기서의 오류는 「그 원칙은 구현이 없다」로 읽힌다. 인용을 정본 쪽으로 재조준하되 **숫자를 다시 적지 않았다.** 그리고 값이 바뀐 릴리스에서 아무것도 발화하지 않은 이유 — 그 파일이 `test_rereview_cap_consistency.sh` 의 코퍼스 밖이었다 — 를 닫았다: 파일을 ∀ 전용 코퍼스에 넣었다. **M4 의 위험(같은 어휘를 쓰는 「다른」 상한)을 넣기 전에 점검했고**, 이 파일에서 상한 어휘가 매치하는 자리는 그 P18 줄 하나뿐이며 나머지 상한 언급(「max-iteration cap」 · 「qg Review fix-loop」)에는 숫자가 없어 줄-스코프가 불필요했다 — 다만 그 줄이 「qg Review fix-loop」를 나란히 적으므로 누가 그 상한을 숫자로 쓰면 좁혀야 한다는 것을 락 주석에 이름 붙여 남겼다.
- **절 이름 변경이 리포 밖 인용 둘을 dangling 으로 남겼다.** `reviewing-spec/SKILL.md` 의 `Phase 5` 는 **절 라벨**이었고 이 브랜치가 그 라벨을 없앴다(절 자체는 `## 게이트` 로 살아 있고 `references/proceed-gate.md` 도 그대로다) — 그런데 그 이름을 인용하던 리포 루트 `CLAUDE.md` 의 「Polite handoff」와 `docs/philosophy/devbrew-harness-philosophy.md` 의 P17 코드 지도가 함께 갱신되지 않았다. 주장은 여전히 참이고 **이름만 틀렸다**. 그 차이가 특히 나쁜 이유: 인용된 이름을 grep 한 독자는 아무것도 못 찾고 「그 메커니즘이 사라졌다」로 읽는다 — 철학 문서의 코드 지도는 다음 세션이 원칙의 살아 있는 instantiation 을 찾는 바로 그 경로다. 둘 다 `## 게이트` 절로 재조준했다(동작 무변경). 이 플러그인 파일은 바뀌지 않았다.
- **상한 락의 코퍼스가 이 전환이 손댄 자리 셋을 안 봤다 (리뷰 M4).** `test_rereview_cap_consistency.sh` 의 코퍼스는 파일 넷이었고, 이 PR 이 상한 인용을 재조준한 `references/proceed-gate.md` · `conducting-interview/references/finishing.md` · `reviewing-brief/SKILL.md` 은 그 밖이었다 — 그 자리들이 숫자를 되찾아도 아무것도 발화하지 않았다. 앞의 둘은 **∀ 전용**으로(양의 하한을 두면 「숫자가 없어서 RED」가 되어 옳은 상태를 벌한다), 셋째는 **줄-스코프 ∀** 로 넓혔다 — 그 파일에는 브리프 critic 의 재dispatch 상한이 `재리뷰 상한 2` 라는 같은 어휘로 적혀 있어 통째로 넣으면 독립된 두 값이 묶인다. 넓힌 코퍼스에는 비공허 하한을 함께 걸었다: 코퍼스 파일이 읽히지 않으면 `grep` 실패를 `|| true` 가 삼켜 **조용히** 빠지므로 실재를 먼저 묻고, 줄-스코프 자리는 잘린 줄 수의 하한 1 을 둔다.
- **`GATE_ROWS` 의 `open` 열에 행동 락이 없었다 (리뷰 M3).** 그 열을 어느 방향으로 뒤집어도 스위트 전체가 GREEN 이었고, 유일한 방어선은 리터럴 증인 표 하나였다 — 그런데 그 표의 헤더는 행이 바뀌면 손으로 고치라고 명시적으로 지시하므로, 지시받은 손질이 곧 방어선의 해제가 된다. `open` 은 `is_open` → `_refresh_open_lineages` → 라운드 원장의 「열린 계보」로 흘러 §8.4 stagnation 술어의 입력이 되므로 조용한 반전은 정체 감지를 바꾼다. `test_docreview_gate_visibility.sh` 에 축이 다른 두 단언을 더했다 — (A) **차단 ⟹ 열림**(기대값을 `blocks` 열에서 도출해 `open` 열도 증인 표도 읽지 않는다. §8.4 「기각된 계보는 열린 집합에서 빠진다」의 대우), (B) 렌더되는 모든 행의 **행동 기대표**((A) 의 사정거리 밖인 비차단 행의 반전을 양방향으로 잡는다. 행 집합 등식 + 양방향 하한으로 미기재·쏠림을 막는다).
- **README 의 P17·P18 이 삭제된 구성물을 현재형으로 서술했다 (리뷰 I2).** P18 은 옛 stagnation 술어를, P17 은 사라진 Phase 5 의 「Human Review」를 가리키고 있었다 — 둘 다 이 전환 뒤에는 생산자도 소비자도 없다. 지금 코드가 하는 것(열린 계보 집합 동일 + 진행 0 → 승인 게이트 즉시 개방 / 승인 게이트의 진행 선택)으로 고쳤다. **그리고 이것을 통과시킨 검사를 함께 고쳤다** — `test_readme_sync.sh` 는 키워드가 «있는가»만 물어서, 대상이 삭제된 술어의 서술이 남아도 조용했다. 부재 단언(옛 카운터 이름이 README 에 없다)과 그 **양성 짝**(지금 술어를 `open_lineages`·`gate_summary` 로 이름 댄다)을 한 쌍으로 더했다 — 부재 단언 혼자면 그 줄을 통째로 지우는 것만으로 만족되므로 이빨이 없다.
- **`reviewing-spec` 의 degrade 채널 서술이 게이트 첫 줄의 내용을 잘못 적었다 (리뷰 M1).** `render_gate` 의 첫 줄은 degrade 공시 하나이고 라운드 번호·재리뷰 카운트는 둘째 줄이다. AC8 의 문자 그대로의 대상이 그 첫 줄이라, 서술이 그 자리에서 틀리면 다음 독자가 대조할 것이 없다.
- **엔진 러너의 PyYAML 의존 제거 · 배선 락의 심볼릭 링크 맹점 (Task 6b).** `run_docreview_codex_reviewer.sh` 의 프로필 파서가 stdlib 만으로 `layer_rubric`·`allowed_dispositions`·`web` 을 읽고, `check_wiring.py` 류의 배선 락이 심볼릭 링크로 배포된 엔진 스크립트를 실제로 검사한다.

## [0.58.0] — 2026-09-08

### Fixed

- **문서 리뷰 엔진 `shared/docreview/` 의 엔진 결함 일곱 (호출자 여전히 0, PR 1b).** 아직 어떤 자리도 이 엔진을 부르지 않는다 — 첫 호출자가 붙기 «전에» 이 일곱을 닫는다. **전부는 아니다** — 재상승(reraise) 후속 사슬 한 hop 뒤에서 다시 열리는 셋의 알려진 한계가 남아 있고(설계 §6.4 「알려진 한계 셋」), 첫 호출자가 붙는 PR 2 가 고쳐야 한다. 이 플러그인은 `scripts/docreview_{state,anchor,route}.py` 심볼릭 링크로 엔진을 배포하므로 같이 bump 한다(cache key).
  - **승인 차단 술어를 전방 포인터로 (AC20).** 만료된 decide 의 차단 해제를 「후속이 존재하는가」의 **역방향** `supersedes` 스캔이 아니라 `st["decides"][fid]["superseded_by"]` **전방 포인터**로 판정한다. 역방향 스캔은 의무와 무관한 후속(같은 bucket 에 우연히 들어온 새 finding)에도 풀려 승인 게이트를 조용히 열었다. 포인터는 후속의 최종 id 가 확정된 뒤 한 곳에서만 쓰이고, 관측·재결정 시점에 초기화된다.
  - **재상승 예약의 누적·dedup·계수 (AC21).** `cmd_observe_diff` 가 예약을 **대입**으로 덮어써, finalize 를 건너뛴 조기 반환 라운드의 예약이 다음 관측에서 사라졌다. 누적 + 같은 `finding_id` dedup 으로 바꾸고, 대상 finding 이 없어 소비되지 못한 예약은 버리지 않고 `reraise_unconsumed` 로 **센다**(CLAUDE.md 「판정기가 항목을 버리면 센다」).
  - **만료 재결정 탈출구 (AC22).** `cmd_decide` 가 `expired` 상태를 받는다 — 채택·기각 둘만, 「보류」는 거부한다(보류 한 번에 승인이 열리는 구멍). 후속이 끝내 안 생기면 사용자에게 길이 없던 영구 차단이 열린다. `post` 만료는 원복 관측 생략을 렌더가 밝힌다. 재결정 시점에 자기 자신의 낡은 전방 포인터를 지운다. **그 구멍은 한 hop 떨어진 곳에서 다시 열린다** — 이 가드는 `expired` 만 겨누는데, 전방 포인터가 원본의 차단을 재상승 후속에게 넘긴 뒤 그 후속은 평범한 `open` decide 라 같은 가드가 안 걸리고 「보류」가 통과한다(설계 §6.4 알려진 한계 (a) · §8.2).
  - **check-intent 일반 fix 경로의 앵커 실재 검사 (AC23).** 슬러그 오타 하나가 보호·불변 검사를 통째로 건너뛰었다 — insert-after 분기에만 있던 실재 검사를 일반 경로에도 세웠다.
  - **`_permit_covers` 의 라운드 경계에 이빨 (AC24).** 조건 자체는 있었으나 그것을 재는 케이스가 없어, 조건을 지워도 매트릭스가 조용했다. 낡은 permit 픽스처로 「지난 라운드의 permit 은 이번 라운드의 보호 승격을 막지 못한다」를 잰다.
  - **어휘 밖 재비판 verdict 의 강제 계수 (AC27).** `confirm`/`raise`/`reject` 밖의 값이 조용히 `confirm` 으로 흘렀다 — 형제 `normalize()` 가 처분에 대해 하는 것과 같은 계약으로 `coerced` 에 센다.
  - **`same_as` 허상 타겟의 병합 스킵 계수 (AC27 쌍둥이).** union-find 의 `parent` 에 없는 대상을 가리킨 병합 지시가 아무 원장에도 안 남고 사라졌다. 두 변(`x`·`y`)을 독립으로 세서 「하나가 허상」과 「둘 다 허상」을 뭉개지 않는다.

### Changed

- **`cmd_finalize` 를 책임 단위 아홉으로 분해 (AC26).** 재비판 읽기 · 재비판 반영 · `same_as` 흡수 · 프로필/보호 분류 · 사후·이월 auto decide 생성 · id/계보 해소 · `blocks` 재매핑 · 보고서 조립이 한 함수에 있었다. 값은 인자와 반환값으로만 오가고 `nonlocal` 은 분해 전과 같이 계보 해소의 하나뿐이다. 부수 성과: 「재상승 후속은 `items` 파이프라인(같은 라운드의 `same_as` 흡수·재비판 `reject`·처분 강제)을 안 지난다」는 불변식이 **줄 위치가 아니라 스코프로** 보장된다 — `_auto_decides()` 에 `items` 가 아예 없다.

### Added

- **AC26 오라클 — 골든 락 `shared/tests/test_docreview_golden.sh`.** 대표 케이스 셋의 실제 `fin.json`·`docreview-state.md` 를 `capture_finalize_golden.sh` 로 다시 떠서 바이트 비교한다. 어떤 단언도 읽지 않는 출력 필드(`by_disposition`·`defers`·`advisory`·`blocks`·`adjudication_*`)의 회귀는 케이스 스위트가 **원리적으로** 못 본다 — 양성 대조로 실증했다(`finalize` 출력에서 `defers` 키를 빼면 골든 락이 3 RED 인데 그 세 케이스의 단언은 0 fail). 골든은 캡처 스크립트가 케이스 몸통을 안 건드리고 `rm` 을 함수 스코프에서만 shadow 해 가로채고, `state.md` 의 `doc:`·`profile:` 절대경로는 `<REPO_ROOT>` 로 정규화해 다른 클론·CI 에서도 성립한다. 락은 코퍼스 하한(6파일)과 절대경로 부재 + 그 짝인 placeholder 실재까지 함께 잰다 — 하한이 없으면 골든을 지운 상태에서 공허하게 통과한다.
- **변이 셀 스무 개** (매트릭스 12 → 31 셀 — 12 + 20 은 32 지만, 승인 차단 술어가 역방향 `supersedes` 스캔에서 전방 포인터로 바뀌며(AC20) 대상 문장이 사라져 은퇴한 옛 셀 `expired_blocks_forever`(⑫) 하나만큼 줄어든다; 번호는 당겨 채우지 않는다). 계보 해소 2패스 순서 · `blocks` 의 `keep_of` 재매핑 · `escalated` 이월 · bucket 충돌 계수 · 재상승 불변식을 겨눈 다섯은 **분해 «전에»** 세웠다 — 분해가 그것을 깨면 소리가 나게. 분해가 앵커를 녹인 셀 둘(`freeze_off`·`reraise_leaks_into_items`)은 재앵커하고 before/after 를 셀 주석에 남겼다.
- **치환 앵커 소실 가드** — 각 변이 셀이 자기 diff 규모를 `<삭제줄>/<추가줄>` 로 선언하고 계측기가 판정 «전에» 대조한다. `sed` 는 매치 0 건에도 성공을 내므로, 리팩터가 대상 줄의 모양을 바꾸면 셀이 아무것도 안 바꾸면서 판정을 계속 낸다 — 그 결말이 셋이고 뒤로 갈수록 나쁘다: 전량 소실은 `no_teeth`, 다중 치환의 일부 소실은 `unmeasurable`, 그리고 **독립적인 일부 소실은 `caught`** 다(규칙의 절반만 재면서 이빨이 있다고 보고하며, 총합에도 grep 에도 안 보인다). 불일치는 규칙 판정이 아니라 계측기 고장으로 낸다.
- **행동 케이스 열여섯** (`cases.sh` 62 → 78, 삭제 0) + 상태 강제 픽스처 셋(`st_set_reraise.py`·`st_set_stale_pointer.py`·`st_open_permit.py`). 픽스처는 `load_state`/`save_state` 를 **사본이 아니라 리포에서** import 한다 — 지금은 무해하지만 상태 직렬화기 자체를 겨눈 미래 셀에는 눈이 멀므로 매트릭스 헤더에 사각지대로 기록했다.

## [0.57.0] — 2026-09-07

### Added

- **라운드 규약 — «직전 답에서 — S<k>» 블록 + AskUserQuestion 질문 둘** (`conducting-interview`, spec
  `docs/superpowers/specs/2026-09-06-interview-depth-redesign-design.md` §1). 매 라운드는 직전 답마다
  함의·상충·확인한 사실·위험 네 줄로 시작하고, Q1 은 그 되비추기의 확인(«맞다/모르겠다», 수정은 «기타»),
  Q2 는 새 결정 하나. 넷 다 «없음»이면 Q1 은 되묻기(이유·사례·실패 조건). state 본문이 이 형식 그대로다
  (`## R<n>` 헤딩은 `depth_pairs.py` 가 읽는 계약).
- **닫힘 = 사용자 발화 앵커** — `check_brief.py` 에 `coverage_anchor_failures`(닫힌 행 evidence 의
  `S<N>` 실재, floor·derived·박제 전부)와 `budget_mapper_failures`(§2 `coverage-mapper <k>` k≥1,
  `0 (unavailable: …)` 은 advisory). **0.57.0 이전 brief 는 새 게이트를 통과하지 않는다** — 아카이브는
  재게이트 대상이 아니다. 기존 fixture 93개는 `tests/fixtures/sweep_anchor_fixtures.py` 로 정합했다
  (`*.audit.md` 95개 중 seed audit 2개는 원장이 없어 대상 밖. 실행 전후 `test_check_brief.sh`
  ok/no 집합 동일).
- **재개방** — `closed → open`, `reopened`/`reopen_log`, 상충 줄 «→ <차원> 재개방», audit §1 접미
  `(재개방 n회 — 사유)`. 상한 없음(사용자가 시계).
- **사후 깊이 측정 세 층** — `scripts/depth_pairs.py`(짝·표본 ≤4·rc 3 측정 불가), `agents/depth-auditor.md`
  (`tools: []`, `depth-audit` 센티널), `scripts/depth_record.py`(병합·audit §2 네 줄·
  `docs/superpowers/interview/depth/<basename>.json`·판정자 조건 A 30%/B 70%/적격 5건). finishing
  Step A.7. **게이트 아님** — 어떤 결과도 종료를 막지 않는다.
- **Phase 0 — seed 산문 규약**: seed 의 «(사용자 확인)» 표시(무표시 = 미확인)와 «다시 검증할 것 —»
  마지막 문단(`framing-requests` SKILL · `references/compression.md` · seed 템플릿). `conducting-interview`
  의 seed 입력 절이 그 문단을 R1 의 S1 되비추기와 coverage-mapper 입력으로 쓴다. `check_seed.py` 는 무변경.
- **`framing-requests` — 진입 직후 워크트리 질문 + 5단계 절차 + handoff 직전 커밋 +
  kill switch (AC12·AC13).** `## 확산` 앞에 `## 워크트리 — 진입 직후` 절을 추가했다 —
  이 skill 에 들어온 첫 행동으로 단독 `AskUserQuestion` 하나를 띄우고(승낙 시
  `EnterWorktree` → `git branch -m` → audit·seed 를 그 안에 쓰기 → proceed 게이트
  ①/②에서 handoff 직전 커밋 1회 → 게이트 텍스트에 워크트리 절대경로), 거절·도구
  부재·kill switch(`DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE=1`) 는 현재 디렉토리로
  진행하며 audit §5 에 «워크트리 없음 — <이유>» 한 줄을 남긴다(어느 경우도 seed
  작성을 막지 않는다). 커밋 메시지 리터럴은 `docs(interview): <topic> interview
  seed + audit`.
  **실측 근거**: 격리 헤드리스 probe(`.claude/spec-distill/idr-scratch/v6/results.md`,
  Task 1) — `EnterWorktree(name=X)` 는 브랜치명에 `worktree-` 접두를 붙인다(요청한
  이름 그대로가 아니다, 디렉토리명은 접두 없음) → 그래서 절차가 항상 `git branch -m`
  으로 명시적으로 rename 한다(슬래시 포함 이름을 넣어 접두를 우회하는 것은 실측
  범위 밖이라 가정하지 않았다). `git branch -m` · `git commit -F` 는 실측에서 거부
  없이 성공했다. **기본 base 는 origin 의 기본 브랜치이고 로컬 전용 커밋은 빠진다**
  (`worktree.baseRef=head` 로 바꿀 수 있음) — 이 절은 그 설정을 자동으로 바꾸지
  않고 사실만 알린다. 종료 후 워크트리·브랜치가 lock 이 걸린 채 잔존한다는 관측은
  근거 등급이 한 단계 낮고(raw 파일 없이 전사한 기록) 사람의 정상 `ExitWorktree`
  종료까지 재현되는지는 미확인이라 이번 절차(진입·rename·커밋·경로 안내)에는
  반영하지 않았다 — Task 15(e2e) 관찰 항목.
  `templates/interview-seed-audit-template.md` §5 설명에도 같은 문구를 추가해
  producer(SKILL.md)와 exemplar(template)를 동기화했다.
  Test: `tests/test_request_framing_command.sh` (AC12 블록, 삭제-방향 뮤테이션으로
  이빨 확인).

### Changed

- coverage-mapper dispatch: «연속 3 probe 무진전 / floor 첫 전이마다» → **R1 첫 질문 전 필수 1회 + 재개방 시
  ≤1회 (상한 2, `orchestration.coverage_mapper_dispatches`)**. 첫 사이클 실측: 정체 트리거 0회 발화,
  첫 전이 dispatch 4/9 미이행. `agents/coverage-mapper.md` 의 description·Input·동작 규칙 4번도 같은
  계약으로 옮겼다(입력이 «최근 probe 의 no_progress 신호»에서 «seed 전문 + 원장 상태 + 재개방이면 그
  차원의 `reopen_log` 마지막 항목»으로).
- state 스키마: floor/derived 에 `reopened`·`reopen_log`. migration advisory v0.57.0.
- proceed 게이트(Step B) question 에 깊이 측정 요약과 `check_brief` advisories 슬롯.
- **`conducting-interview/SKILL.md` 조건부 로드 분리** — `## seed 를 입력으로 받았을 때` →
  `references/seed-input.md`(23줄), `## In-flight state migration` → `references/state-migration.md`(27줄).
  **내용 삭제 0** — 그대로 옮기고 SKILL.md 에는 `finishing.md` 가 이미 쓰는 것과 같은 모양의 포인터(조건 +
  Read 줄 + 레포·설치본 양쪽에서 resolve 되는 경로 문구)만 남겼다. 순감의 실제 목표는 «매 인터뷰가 지는
  무게»이고, 남은 삭제 후보가 실제 내용뿐이 됐을 때 커트를 멈춘 결과다. 락 셋(`mig_block`·`mig_ir_count`·
  `seed_block`)과 `test_stale_terms.sh` 의 `interview_round` confinement(V7b-1·V7b-2)는 삭제가 아니라
  새 파일로 재포인트했고 mutation 으로 각각 여전히 무는 것을 확인했다.
- `scripts/check_brief.py` 의 `MAPPER_RE` 가 형제 regex(`ENTRY_BULLET_RE`·`BODY_ITEM_RE`)와 같은 `[-*]`
  불릿 어휘를 쓴다. 게이트를 «불릿 줄»에 앵커하면서 불릿 문자를 `-` 단독으로 좁혔더니, `*` 로 쓴 정당한
  §2 데이터 줄이 «없는 줄»로 읽혀 `coverage-mapper <k> line missing` 오탐-red 가 났다(이 파일이 이미 한 번
  겪은 결함이 방향만 바꿔 재발). 회귀 락은 통과가 정답인 단언이라 **양성 대조**(변형이 실제로 `*` 불릿을
  만들었고 `-` 쪽 줄이 남아 있지 않은지)를 먼저 재고 나서 통과를 단언한다.
- `commands/interview.md` 의 첫 라운드 설명이 «4-block Korean format» → ««직전 답에서» 블록 + 질문 둘».
- `shared/tests/test_adjudication_wiring.sh` 의 `COMP_BASELINE` 33 → 38 — `depth_record.py` 가 `Ledger`
  import 로 스캔 대상에 들어오며 더한 컴프리헨션 다섯. 다섯 전부 «항목을 버리는 자리»가 아니라 «세거나
  목록을 만드는 자리»임을 코드를 열어 확인한 근거를 그 자리 주석에 남겼다(baseline 은 요구가 아니라 회귀 축).

### Removed

- teach-beat 절(teach-lite/heavy — 첫 사이클 열린 질문 8/8 소실), **라운드 규약의** 4-block 형식, SKILL C43
  경로 (c)(general-purpose adversarial draft, 사용 기록 0), C51 라벨 강제, 정체 트리거와 state 필드
  `no_progress_streak`·`stall_episode`·`coverage_mapper_dispatched_episode`(`test_stale_terms.sh` V12 등재).
  `conducting-interview/SKILL.md` 386줄(0.54.0: 408 — G7 락은 `< 408`).
  **범위 — 줄 수**: 그 22줄이 전부 이 릴리스의 삭제는 아니다. 아래 수는 전부
  `git show <ref>:plugins/spec-distill/skills/conducting-interview/SKILL.md | wc -l` 로 **직접 센 값**이다 —
  `319ed43`(0.54.0, 이 브랜치의 main 쪽 base) **408** · `6d77183`(이 브랜치가 merge 하기 직전의 tip)
  **405** · `353b4a6`(upstream 0.55.0) **387** · `27c596d`(merge) **386**.
  즉 **이 브랜치 자신의 순감은 −3**(408 → 405)이고 **upstream 의 순감은 −21**(408 → 387).
  −3 은 조건부 로드 분리 하나의 몫이 아니라 SKILL.md 를 건드린 이 브랜치 커밋 **여섯**
  (`a82c57b`·`cc25708`·`a7af882`·`f09b321`·`8693087`·`f8a1b53`)의 합이다.
  **그리고 두 순감은 더해지지 않는다** — 408 − 3 − 21 = 384 인데 병합 결과는 386 이다(+2). 양쪽이
  **같은** R3/steelman 영역을 고쳐서, merge 가 독립적인 두 삭감을 합산한 것이 아니라 겹침을 해소했기
  때문이다. 빼서 384 가 나온 독자가 changelog 를 의심하지 않도록 여기 적어 둔다 — 386 과 `< 408` 은
  그 해소 **뒤**의 실측값이고 둘 다 참이다(G7 락이 그 값을 쓴다).
  **범위 — 4-block**: 위에서 빠진 것은 «라운드 규약의» 4-block 이고, **형식 자체는 리포에 남아 있다** —
  R3 steelman 게이트가 `references/steelman.md` Step 3 에서 제시 형식으로 그대로 쓴다. 같은 어휘를 쓰는
  다른 물건이라, `test_conducting_interview_stage.sh` 의 G7 부재 락은 그 파일 하나만 예외로 두되 그
  예외가 vacuous 하지 않은지(그 파일이 실제로 그 어휘를 갖는지)를 양성 대조로 함께 잰다.

### Fixed

- **최종 리뷰 fix wave** (좌석 둘 — 같은 계열 whole-branch · codex cross-family — 이 서로 blind 로
  돌아 거의 다른 것을 찾았다. 아래는 판정 후 고친 것):
  - **AC3 닫힘 게이트 fail-open** — `coverage_ledger_failures`(derived 를 `startswith` 로만 셈)와
    `coverage_anchor_failures`(세 부분 요구, 매치 실패는 조용히 `continue`)의 **엄격도 비대칭**으로,
    derived 닫힘 행에서 근거 «필드 자체»를 지우면 게이트가 `{"pass": true}` rc=0 을 냈다. 두 함수가
    하나의 `LEDGER_ROW_RE` 를 공유하게 하고, `floor:`/`derived:` 로 시작하는데 그 형태로 안 읽히는
    줄을 그 자체로 failure 로 만들었다. 구분자 앞 공백을 요구해(`\s+—`) 이름에 em-dash 가 든 행이
    **오파싱되어 닫힌 행이 열린 행으로 재분류**되던 두 번째 증상도 닫는다.
  - **Step A.7 측정 원장이 영영 안 써지던 것** — 두 번째 bash 블록이 첫 블록에서만 정의된
    `$PR`·`$PAIRS`·`$AUD_RAW`·`$ROOT`·`$harness_sid` 를 썼다. 두 블록 사이에 `Agent` dispatch 와
    `AskUserQuestion` 이 있어 반드시 새 셸이다(`can't open file '/scripts/depth_record.py'` rc=2).
    Step B-0 과 같은 관례로 블록 머리에서 재도출한다.
  - **출하 audit 템플릿이 게이트의 답을 미리 채우던 것** — `coverage-mapper` 만 리터럴 통과값 `1` 을
    달고 있어 dispatch 0 회 턴이 그대로 옮겨 적으면 게이트가 조용히 통과했다. `<k>` 로 되돌리고,
    R18 이 막던 것(산문이 판정을 짐)은 **숫자를 치환한 합성 사본**에 대해 잰다.
  - **측정이 거짓말하던 자리 넷** — 파손된 auditor 펜스가 「측정했고 0」으로 기록되던 것(이제
    못 읽은 줄을 계수하고 항목 0 이면 unavailable) · 같은 S 의 상충 판정이 무공시 흡수되던 것(이제
    hold, 같은 라벨 중복은 흡수로 계수) · `user_statements` 항목의 **필드 순서**만 달라도 한 답의
    본문이 다른 S 에 붙던 것(이제 불릿이 항목 경계, id 부재는 rc 3) · 중간 라운드 결번이 terminal 로
    오계수돼 적격 답이 사람 표본에서 사라지던 것(spec §3.2 의 정의대로 «뒤에 라운드가 없을 때»만
    terminal). `agreement` 이형 값이 uncaught `ValueError` 로 「항상 exit 0」 계약을 깨던 것도 닫았다.
    `depth_pairs.py` 가 늘 세던 `skipped` 를 영구 기록·표시 **양쪽에** 실어 누락이 하류에서 보이게 했다.
  - **산문이 코드와 어긋나던 여섯** — 필수 첫 coverage-mapper dispatch 가 계약이 요구한 seed 입력을
    안 싣던 것(슬롯 `seed`·`reverify` 추가 — 첫 dispatch 는 R1 전이라 원장만으로는 **주제를 못 본다**) ·
    migration 이 «직전 released 스키마»(구조는 있고 새 키 셋만 없음)를 안 덮던 것(판정을 키 단위로) ·
    워크트리 발산 경고가 tracking branch 를 재던 것(워크트리가 실제 쓰는 origin 기본 브랜치 기준으로) ·
    README 안의 `4-path`/`3-path` 자기모순 · 삭제된 C51 5-type 규칙의 거짓 인용 ·
    `DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE` 의 README 등재부 누락.
  - **이빨 없던 락 둘** — Step A.7 락이 `grep -qF '<파일명>'` 이라 산문·처분 줄이 만족시켜 **호출 두
    줄을 지워도 GREEN** 이었다(bash 펜스 안 호출 «형태»로 교체). AC10 템플릿 락이 깊이 줄 셋만 세어
    `- 판정자 조건:` 줄을 지워도 GREEN 이었다(넷 다 센다).
- steelman dispatch 의 web kill switch 확인이 dispatch **뒤**에 놓여 있어(`SKILL.md` R3, 선재 결함), 위에서
  아래로 읽는 모델이 `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 인 채로 dispatch 할 수 있었다. `test_web_kill_switch.sh`
  의 guard-window 락(dispatch 줄 위 40줄 안에 스위치 확인)은 이것을 잡지 못했다 — steelman dispatch 바로
  위가 아니라 9줄 위의 R2 landscape 절 **자신의** kill switch 언급에 우연히 걸려 green 이었다. 확인 문단을
  다른 두 dispatch 와 같은 모양으로 dispatch 직전에 옮겼다. **그런데 이 수정은 병합에서 살아남은 것이
  아니라 더 강한 수정으로 대체됐다** — 0.55.0 merge 가 R3 절차 전문을 `references/steelman.md` 로 옮겼고,
  upstream 은 같은 클래스를 그 파일에서 **다른 층위로** 고쳤다(아래 `[0.55.0]` 의 Fixed). 우리 것은
  advisory **문단**을 dispatch 위로 올린 «산문 순서»였고, upstream 은 `Agent(...)` **호출 자체**를 `else`
  가지 안에 넣어 스위치가 켜지면 dispatch 가 **구조적으로 도달 불가**가 되게 했다. 순서는 읽는 모델에
  기대고 도달 불가는 기대지 않는다 — 병합 후 순 표면에 남는 것은 후자이고, 그것이 더 강하다.

### Verification

- **V6 실측** (native 워크트리, 격리 헤드리스 — 기본 baseRef / `worktree.baseRef=head` 두 실행 + 훅 전용
  보충 실행 1회. 근거: `.claude/spec-distill/idr-scratch/v6/results.md`):
  - (a) 브랜치명 — `EnterWorktree(name=X)` 가 만드는 브랜치는 `worktree-X`(요청한 이름 그대로가 아니다);
    워크트리 **디렉토리**는 접두 없이 `X`. 두 실행 동일.
  - (b) base ref — 기본은 origin 의 기본 브랜치라 **로컬 전용 커밋이 빠지고**, `worktree.baseRef=head`
    면 로컬 HEAD 라 들어온다.
  - (c) 훅 · `CLAUDE_PLUGIN_ROOT` — 훅은 워크트리 안에서도 정상 발화하고 훅 커맨드 문자열의
    `${CLAUDE_PLUGIN_ROOT}` 는 플러그인 절대경로로 치환된다. 그러나 에이전트가 실행하는 **일반 Bash
    세션에는 export 되지 않는다**(`unset`) — 두 컨텍스트를 «훅 발화 여부» 하나로 뭉뚱그리지 말 것.
  - (d) 종료 후 잔존 — 헤드리스(`ExitWorktree` 미호출) 종료 뒤 워크트리·브랜치가 **lock 걸린 채 잔존**하고
    `git worktree remove --force` 는 거부돼 `-f -f` 가 필요했다. **근거 등급이 (a)(b)(e) 보다 한 단계 낮다** —
    도구가 낸 JSON 필드가 아니라 `git worktree list` 출력을 수기로 전사한 기록이다.
  - (e) `git branch -m` · `git commit -F` — 격리 세션의 git 가드에 **둘 다 거부 없이 성공**. `tool_available=yes`.
  - **미측정 셋**(단정하지 않는다): ① 슬래시 포함 브랜치명(`EnterWorktree(name="feature/<topic>")`)이
    무엇이 되는지 ② 사람이 대화형 `ExitWorktree` 로 **정상 종료**했을 때도 (d) 의 lock 잔존이 재현되는지
    ③ keep/remove 프롬프트의 모양 — 대화형 UI 라 `-p` 헤드리스에서 트리거되지 않는다.
- **V1 mutation** — 앵커 문자 삭제 / 앵커 번호를 §6 에 없는 값으로 / 원장 행 통째 삭제 셋을 스윕된
  `interview-brief-valid` 쌍 사본에 수동으로 넣어 전부 red 를 확인했다(무변이 baseline 은 pass;
  `.claude/spec-distill/idr-scratch/ac3_mutation.txt`). `coverage-mapper 1 → 0`(사유 없음)·줄 부재·
  `0 (unavailable: …)` advisory 는 `test_check_brief.sh` AC4 블록의 in-test 변형이 상시 고정한다.
- **V5 baseline** — 착수 전 실패 3줄 → 완료 후 3줄, 새 실패 0. 그 3줄은 이 릴리스와 무관한 선재 RED 이고
  clean `origin/main` 체크아웃에서도 바이트 동일하다(plan 부록 B 에 줄과 면제 사유).
- **V7 사람 e2e**: 실행하지 않았다 — 사용자가 이번 릴리스에서 사람 e2e 인터뷰 실행을 하지 않기로
  결정했다. **AC16 미충족.** 이 릴리스가 더한 것 중 모델이 실행하는 산문 — 라운드 규약(«직전 답에서»
  블록 + 질문 둘), Step A.7 사후 깊이 측정 절차, `framing-requests` 워크트리 질문, 종료 시
  사람-라벨링 질문 — 은 라이브 세션에서 한 번도 실행되지 않았다. 결정론적 스위트(V1~V5)는
  통과했으나 그것이 검증하는 범위 밖이다.
- **알려진 한계 — 씨드 경로의 `S1→R1` 쌍이 측정 밖**: 씨드로 시작한 인터뷰는 state 의
  `user_statements` 번호를 `S2` 부터 매긴다(`S1` 은 §6 예약, state 미기록) — 그래서 `S1` 은
  `depth_pairs.py` 에 닿지 않고, 그 스크립트가 내는 `total`/`eligible` 은 R1 의 되비추기를
  체계적으로 뺀다. 방향은 낙관 쪽이다: 빠지는 답은 seed 의 «다시 검증할 것» 문단에서 그대로
  채워지는 반사(파고든 것이 아니라 미리 쓰인 것)일 확률이 가장 높은 자리라, 측정된 dug-rate 를
  실제보다 높게 보이게 한다 — spec §3.4 의 판정자 조건 임계치(A 30%/B 70%)가 바로 그 비율을
  읽는다. 고치는 방법은 설계 결정이다(`S1` 을 state 에 실제로 넣을지, 스크립트가 §6 예약을
  알게 할지) — 이번 사이클에서는 하지 않는다.

## [0.56.0] — 2026-09-06

### Added

- **문서 리뷰 엔진 `shared/docreview/`(호출자 0, PR 1/5).** 네 문서 리뷰 자리(design doc·brief·seed·generic)를 하나로 통일하는 엔진의 기반을 심는다 — 탐지 agent `doc-critic`(층별 sentinel 블록 둘)·프레이밍을 못 보는 재비판 agent `doc-recritic`(입력 슬롯 셋)·스크립트 넷(`docreview_state`·`docreview_anchor`·`docreview_route`·codex 러너)·절차 reference. 산출물은 verdict 가 아니라 처분(decide·ask·fix·defer·drop)이 붙은 finding 목록이다. 회귀는 편집 범위 선언·헤딩 단위 얼림·보호 부류·패치 의도로 막고, 결정론은 헤딩 diff 와 보호 목록 둘뿐이다. 이 릴리스는 `scripts/` 링크 넷만 심고 **아직 어느 진입 skill 도 부르지 않는다** — 자리별 전환은 PR 2(design doc, major)·3(brief)·5(seed).
- 프로필 셋 `references/docreview-profiles/{design-doc,brief,seed}.md` — 자리별 정답 출처·허용 처분·층 rubric·결정 기록 목적지를 데이터로 선언(열 필드 스키마, `docreview_state.py profile-check` 가 검증).
- `codex_findings_to_yaml.py --emit-keys docreview`(`shared/codex/` 정본에 keyset 추가, 기존 `default`·`design` 출력 바이트 불변).

### Changed

- `shared/tests/test_skill_reference_pointers.sh` 의 플러그인-레벨 `references/` 코퍼스를 「한 단계」로 좁힘 — git pathspec 의 `*` 가 `/` 를 넘어 이 패턴이 재귀적이었고, 그래서 스크립트가 먹는 호스트 데이터(`references/docreview-profiles/*.md`)까지 절차서 고아 검사에 들어왔다. 코퍼스 건수 불변 + 진짜 고아는 여전히 RED(양성 대조).

## [0.55.0] — 2026-09-06

### Added

- `skills/conducting-interview/references/steelman.md` — R3 절차 전문. 전제 P1..Pn·goal 원문·제약 원문 전량을
  dispatch 에 싣고, 게이트 전에 repo_claims(경로+앵커)와 양성 `touches` 부착 주장을 orchestrator 가 확인하며,
  확인된 전제 충돌 0 이면 「재검토 사유 없음」 라벨(사용자가 그래도 전환하면 `사용자 override` 로 기록).
  4-block 은 builder 추천과 orchestrator 의견을 나란히, 선택지는 유지/보완/전환/보류 고정 순서.
- `scripts/skepticism.py` — payload §5 skepticism 검사(`VALID_VERDICTS` · verdict 형식 · `검토 —` 항목 · 폐쇄 판정 ·
  bijection A). `check_brief.py` 는 절을 잘라 넘기기만 한다. 의존 방향은 check_brief → skepticism 하나.
- 폐쇄 요구: verdict 항목 0건이면 `- 검토 — steelman 0건: 검토한 방향 N개 · 전제 … · trigger 후보 … → 기각 이유 …`
  항목이 없으면 gate RED(브리프 C26). `보류 —` 접두의 deferred 항목은 verdict 로 세되 R4 기각으로 세지 않는다.
- steelman-builder 슬롯 셋: `goal`(artifact) · `premises`(orchestrator_framing, `tools/adjudication/check_slots.py`
  면제 5번째) · `constraints`(artifact). 출력 스키마: `case_for_alternative` → `case_for_current` →
  `premise_refutation` → `premise_list_challenge` → `recommendation` → `refined_takes/drops` → `evidence[].touches` →
  `repo_claims[].path/anchor/touches`.
- steelman-builder 재론 방지 규칙(동작 규칙 10번): `premise_refutation.hits` 가 비어 있으면
  `recommendation: switched` 를 낼 수 없다 — 전제 충돌이 없는 근거는 `case_for_current` 강화나
  `refined` 경계를 다듬는 데만 쓴다. 「전제 충돌만이 확정된 방향을 다시 연다」는 재설계 원칙이
  실행 가능한 규칙으로 존재하는 자리.
- 픽스처 6쌍(`steelman-empty-norecord` · `verdict-refined` · `verdict-defended` · `review-record-malformed` ·
  `verdict-deferred-hold` · `review-only-no-reject`) + `tests/test_skepticism_module.sh`.

### Changed

- steelman 의 목적이 「원안 뒤집기」에서 「사용자 goal 에 가장 적합한 방향 찾기」로. 페르소나 역할은 「대안의 옹호자 ·
  원안의 옹호자 아님」에서 「양쪽 케이스를 같은 기준으로 쓰는 분석자 · 어느 한 편의 옹호자 아님」으로.
- verdict 토큰 `defended` → `kept`, `refined` 신설(`switched` · `deferred` 그대로). 픽스처 141 과 템플릿을 기계 치환,
  과거 brief 의 기계 토큰 2줄(08-16 → refined · 08-22 → kept)과 이 브랜치 brief ST1(→ refined, 사용자 판정이
  「보완」이었다)은 산문을 읽고 값을 골라 `(이관 2026-09-06)` 표기. 산문·verbatim 원문은 시점 기록이라 건드리지 않았다.
  **별칭 없음** — spec-distill 은 v0.x 라 one-minor deprecation window 면제.
- `tests/test_conducting_interview_stage.sh` 의 R3 블록은 `references/steelman.md` 에서 뜬다. `coverage-mapper neglect`
  존재 락을 부재 락으로 반전(양성 짝: trigger 3값·검토·보류·새 어휘).

### Removed

- R3 trigger 「coverage-mapper neglect」 — 커버리지 공백은 probe 질문으로 간다(브리프 C18).
- steelman-builder 의 `confidence` 필드와 「confidence < 0.4 면 원안 defend 합리적」 규칙 — `recommendation: kept` 와
  `case_for_alternative.strongest` 가 같은 정보를 이산값으로 준다.

### Fixed

- `references/steelman.md` 의 web kill switch 확인이 dispatch 를 감싸는 조건문 밖 별도 코드 펜스에
  `Agent({...})` 를 두고 있어, 스위치가 켜져 있어도 「steelman 자동 생략」 advisory 만 출력하고 그대로
  dispatch 했다 — `steelman-builder` 는 `WebSearch`/`WebFetch` 를 보유하고 자기 스위치를 읽지 않으므로
  차단은 orchestrator 단독 책임이었다. dispatch 를 `else` 가지 안으로 옮기고 `if < else < Agent < fi`
  순서 관계를 락으로 고정.
- `tests/test_conducting_interview_stage.sh` 의 AC6 어휘 락이 맨 토큰 grep(`kept` 등)을 써서 부분
  문자열에 먹혔다 — `kept` 가 `s(kept)icism` 다섯 자리에 걸려, 진짜 verdict 자리 셋을 전부 지워도
  매치 5건을 내고 스위트가 GREEN 이었다. 한↔영 짝 리터럴(`유지(kept)`·`보완(refined)`·`전환(switched)`·
  `보류(deferred)`)로 교체.
- `SKILL.md` 5의례 요약 표의 R3 행이 통과 기준을 여전히 2값(「steelman 후 *방어 또는 전환*」)으로 적어
  4값 게이트(유지/보완/전환/보류)와 모순이었다. 4값으로 정정하고 옛 어휘 부재 + 새 어휘 존재 양성 짝
  단언 추가.
- `references/steelman.md` Step 2 가 확인도 반증도 못 한 `repo_claims` 항목에 `[미확인]` 라벨을 약속하는데,
  Step 3 의 4-block 서술은 `evidence[]` 만 항목화하고 `repo_claims` 는 집계로 접어 그 라벨이 나타날 자리가
  없었다 — Step 2 가 금지한 조용한 흡수로 귀결된다. Step 3 에 항목별 라벨 줄을 더했다.
- `tests/test_conducting_interview_stage.sh` 의 R3 trigger 존재 락이 토큰 `제약` 을 써서 코퍼스의 다른 세
  줄에 걸려 통과했다 — 트리거 줄에서 그 문구를 지워도 스위트가 GREEN 이었다. body-unique 인
  `제약과의 충돌` 로 좁혔다.

## [0.54.0] — 2026-09-06

### Changed

- **agent frontmatter 의 `model: inherit` 를 제거했다 — `inherit` 는 사용자의 subagent
  기본 티어 설정을 덮어쓴다 (CLI 2.1.261 실측, 2026-09-06).** frontmatter 에 `model` 키가
  없으면 하니스가 「`CLAUDE_CODE_SUBAGENT_MODEL` → 세션 모델」 순으로 위임하고, `inherit` 는
  그 첫 단계를 건너뛴다(헤드리스 probe 6회, 설계 §A). 설정이 없는 환경은 동작이 같다.
  규약·락은 「키 부재」 단언으로 반전 — 정본은
  `docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md`.

## [0.53.1] — 2026-09-05

### Fixed

- **이 브랜치가 선재 락 하나를 깨뜨렸다 — mandate 의 꼬리를 잘랐다 (최종 수정
  라운드 2, R-A).** `hooks/review-dispatch.py` 의 `_block_with_ledger()` 가 처분
  두 줄을 `reason` **뒤**에 붙이면서,
  `tests/test_hook_output_schema.py::test_normal_dispatch_states_mandate_lifetime`
  이 요구하는 `reason.rstrip().endswith("이 mandate는 이번 dispatch 1회에만 유효하다.")`
  가 깨졌다. 실측 대조: 같은 파일이 `origin/main` 에서 **1 failure**, 이 브랜치
  HEAD 에서 **3 failures** — 둘이 회귀였다.
  **고침**: 처분 두 줄(+advisory)을 `reason` **앞**으로 옮긴다. `reason` 은 다시
  수명 문장으로 끝나고, 공시는 모델 채널에 그대로 남는다.
  **왜 그쪽이 이기는가**: `endswith` 형태는 «측정된 두 번의 실패»에서 의도적으로
  골라진 구조적 가드다 — mandate 뒤에 재발동 조건을 덧붙이려는 시도가 두 번 있었고
  두 번 다 거짓이었다(커밋 단정 → git fail-open · 재편집 단정 → mark_reviewed 경로).
  그래서 의미 판단을 버리고 「꼬리에 아무것도 붙지 않는다」는 형태를 택했다. 이
  브랜치의 배치 단언은 실패 측정이 아니라 선호에서 나왔다 — **충돌하면 측정된
  실패가 뒤에 있는 쪽이 이긴다.**
  **버린 대안**: ⑴ 선재 락을 「미래형 단정만 금지」로 좁히기 — 두 번 틀린 그 의미
  판단을 되살린다. ⑵ 처분을 `systemMessage` 로 옮기기 — 그 채널은 모델 도달
  **0/14** 로 측정됐다(Task 11). 공시가 사라진다.
  **비용**: 모델이 지시문 앞에 회계 두 줄을 먼저 읽는다(두 줄).
  이 브랜치가 넣은 반대 방향 단언(`tests/test_review_dispatch_disposition.sh` 의
  「MANDATORY 가 처분 줄보다 앞」)을 **반전**시키고, 그 자리에 **왜 반전했는지**를
  적었다 — 다음 사람이 다시 뒤집지 않도록.

- **이 브랜치가 기존 락 하나를 «공허»하게 만들었다 (최종 수정 라운드 2, R-B).**
  decision emit 이 `main()` 의 bare `print(json.dumps({"decision": ...}))` 에서
  `_block_with_ledger()` 로 옮겨가자, `main()` 의 문(statement)만 훑던
  `test_ast_rewrite_before_print` 의 AST 스캐너가 아무 emit 도 못 찾았다. **그 락은
  정직했다** — 통과하지 않고 「내가 잴 대상이 사라졌다」로 실패했다.
  **복구(약화 아님)**: 스캐너가 **도출**로 emit 을 따라간다. 헬퍼 «이름»을
  하드코딩하지 않는다 — ⑴ 이 모듈이 정의한 함수 호출이면 그 본문을 호출 자리에
  펼치고(재귀 가드), ⑵ decision 성(性)을 호출 «인자»에서 전파한다(헬퍼 안의 print 는
  `{"decision": …}` 리터럴을 자기 안에 갖지 않는다 — 그 리터럴은 호출 자리에 있다),
  ⑶ `file=` 키워드가 붙은 print(=stderr 진단)는 계속 제외한다. 문 «타입»도 열거하지
  않는다 — `return helper({...})` 처럼 `ast.Expr` 이 아닌 자리로 옮겨간 것이 정확히
  이 락을 눈멀게 한 변화다. 순서 비교는 **줄번호가 아니라 이벤트 순서**로 한다(펼친
  헬퍼는 호출 자리보다 «위»에 정의돼 있어 줄번호가 거꾸로 돈다).
  등가 확인: 같은 스캐너를 `origin/main` 판 훅에 돌리면 이벤트 모양이 동일하다
  (emit 2 · rewrite 1, 같은 순서) — 복구이지 완화가 아니다.
  「도달 못 했다」는 실패 메시지도 「통과시키지 마라」로 강화했다.

- **위 R-A 가 `check_wiring.py` 의 면제 키 열 개를 밀었다 — 락이 잡았고, 정체로
  다시 못 박았다.** `_block_with_ledger()` 의 docstring 이 늘면서 그 아래
  `review-dispatch.py` 의 버리는 분기 열 자리가 +17 줄 이동했다. 같은 파가 조금
  전에 넣은 3-튜플 키(`(경로, 줄, 정체)`)가 그것을 **미배선 10 + 낡은 면제 10**
  으로 이름과 함께 냈고, 정체(`kind`·`func`·`guard`)가 같은 행을 찾는 방식으로
  **줄번호만** 기계 갱신했다(판정·사유 무변경 — 손으로 세지 않았다). 이 사건 자체를
  `check_wiring.py` 의 해당 주석 블록에 기록했다.

### Note

세 양성 대조 전건 확인 — ⑴ 처분 줄을 다시 꼬리로 → `test_hook_output_schema.py`
RED(2건) · ⑵ 처분 두 줄을 아예 삭제 → `test_review_dispatch_disposition.sh`
RED(5건) · ⑶ `rewrite_state` 를 emit 뒤로 → `test_ast_rewrite_before_print` RED
(+형제 락 둘도 함께). 셋 다 원복 후 GREEN.

## [0.53.0] — 2026-09-05

### Changed

- **`blind-spot-prober.framing` 의 `kind` 를 정직하게 고쳤다 (최종 리뷰 K3).**
  `artifact` 로 선언돼 있었으나 `conducting-interview/SKILL.md` 가 그 슬롯에 싣는 값은
  **오케스트레이터가 직접 쓴 재구성 요약**(「지금까지의 framing(재구성된 문제정의 +
  사용자 제약 요지)」)이라 금지 종류 `orchestrator_framing` 이다 — 선언이 그 사실을
  가려 `tools/adjudication/check_slots.py` 의 (b) 축을 우회하고 있었다.
  `kind: orchestrator_framing` 으로 바꾸고 `EXEMPT_SLOTS` 에 **C6(1) 인용과 함께**
  등재했다(구조가 같은 `adversarial.phase1_findings` 의 선례). 사유: 이 agent 의 과업이
  「지금의 framing 에 대한」 premortem 이라 프로브의 대상이 정의상 그 재구성 자체다 —
  다른 값을 넣으면 프로버가 자기 framing 을 새로 세우고 그것을 치게 되어 이 agent 가
  존재하는 이유를 잃는다. **잔여 위험은 남긴다**: 재구성이 이미 잃은 것은 프로버도 못
  본다 — 그 축은 `reviewing-brief` 의 충실도 단계가 §6 원문 대비로 따로 잰다.
  양성 대조: 면제를 지우면 `test_agent_input_slots.sh` 가
  `PROBLEM forbidden_kind spec-distill:blind-spot-prober … kind=orchestrator_framing`
  으로 RED(실측).
- **같은 축을 전수로 다시 훑었다.** Task 14 의 스윕은 `prior_verdict` 축만 돌았고
  `orchestrator_framing` 축은 안 돌았다. 20 개 agent 의 선언 슬롯 전부에 대해 dispatch
  가 싣는 값의 «출처»를 읽어 다섯으로 분류한 결과 이 축에 걸리는 것은 **하나**뿐이었다.
  지목됐던 `steelman-builder.direction`/`trigger` 는 ⓐ(과업의 대상·enum)로 판정 —
  `direction` 은 사용자가 고른 방향의 재진술이고 `trigger` 는 게이트를 발동시킨 네 값
  중 하나를 대는 enum 이라, 둘 다 「agent 가 내야 할 대안에 대한 오케스트레이터의
  기대」가 아니다. 도출 근거는 `check_slots.py` 의 `EXEMPT_SLOTS` 위 주석에 남겼다.

### Fixed

- **줄번호 인용을 심볼 인용으로 (최종 리뷰 K7).** `tests/test_merge_brief_adjudication.py`
  의 `shared/adjudication/adjudication.py:110` → `reasons()`. 이 브랜치가 그 파일에
  31줄을 더해 밀린 자리다(순수 self-shift).
- **README 의 「Principles Instantiated」에 이 사이클의 instantiation 이 없었다
  (최종 리뷰 K6b).** `처분`·`adjudication`·`Ledger`·`input_slots` 를 전수 grep 하면
  히트 0 이었다 — Law 3 의 discoverability 요구를 못 채운다. 처분 회계와 `input_slots`
  두 줄을 더하고, 각각의 **범위 한계**(축 C 는 채널 이름의 실재까지만 잰다)를 함께 적었다.

## [0.52.4] — 2026-09-05

### Fixed
- **Task 15 수정 라운드 2 (I1, Important) — F6 이 닫았다고 주장한 부류가
  판정기를 «부르는» 러너 자신에서 다시 열려 있었다.** F6 은
  `tools/adjudication/check_*.py`(락이 import 하는 대상) 넷을 `# guards:`
  에 편입했지만, F4 의 실제 결함 자리는 `check_slots.py` 가 아니라 그것을
  «부르는» `shared/tests/fixtures/adjudication/run_slots.py` 의 print
  루프였고 — 그 러너를 코퍼스로 갖는 락은 하나도 없었다. F1 이 새로 만든
  `run_block_disposition_count.py` 도 같은 무방비 상태로 태어났다. F6 과
  정확히 같은 도출(열거가 아니라 그 `.sh` 가 실제로 실행하는 러너 파일명을
  찾아서)로 다섯 러너를 각자의 유일한 소비자 락에 편입했다:
  `run_block_disposition_count.py` → `test_review_dispatch_disposition.sh`
  (이 플러그인), `run_wiring_scan.py`/`run_wiring_probe.py` →
  `test_adjudication_wiring.sh`, `run_consumed.py` →
  `test_adjudication_consumed.sh`, `run_slots.py` →
  `test_agent_input_slots.sh`, `run_names.py` → `test_dispatch_name_defined.sh`
  (뒤 넷은 `shared/tests/`, 이 플러그인 버전과 무관하지만 같은 커밋이라
  여기 함께 기록 — F4 도 같은 이유로 quality-gates CHANGELOG 에 소급
  기록했다, m3). `--emit-scanned` 도 맞춰 갱신 —
  `test_guards_coverage_bidirectional.sh` 92/92 GREEN 유지.
- **Task 15 수정 라운드 2 (I2, Important) — `test_review_dispatch_disposition.sh`
  의 T5-2(dispatch 강제) 값 검사가 후보 문서를 «하나만» 놓아 「0 vs 1」은
  갈라도 「1 vs N」은 못 갈랐다.** 같은 파일 :148-150 의 형제 절(T5-1)이
  이미 경고하는 off-by-one 함정 — 실패 문서가 하나면 "메시지 줄마다 부른다"
  류 회귀가 안 보여 T5-1 은 그래서 실패 문서를 둘 쓰는데 T5-2 는 하나였다.
  후보 문서를 둘로 늘리고 "후보 수와 무관하게 미판정은 정확히 1"(dispatch
  는 여전히 한 턴에 하나만 고른다, A11)을 못박았다. 양성 대조: `L.hold()`
  를 선택된 후보 하나가 아니라 «모든 후보»에 대해 부르도록 되돌리는
  회귀를 주입하면(후보 1개였다면 이 값이 우연히 1 이라 안 보였을 시나리오)
  이제 미판정=2 로 RED — 후보 1개 상태에서는 이 회귀가 구조적으로 안 보임을
  먼저 확인한 뒤 후보 2개로 고쳐서 다시 걸었다. 원복 후 14/14 GREEN.

## [0.52.3] — 2026-09-04

### Fixed
- **Task 15 수정 라운드 1 (F1, Critical) — `test_review_dispatch_disposition.sh`
  의 정적 카운트 절이 `grep -c '\.(hold|reject|source_failed|uncountable)\('`
  였다.** `review-dispatch.py:222` 의 설명 주석 안 리터럴 `` `L.reject(...)` ``
  텍스트가 이 정규식을 그대로 만족시켜, 진짜 처분 호출(:804 의
  `L.hold(str(cand.path), ...)`) 하나가 지워져도 카운트가 2→2 로 안 줄었다
  (코디네이터가 9개 락 전수로 재현: 변이 후에도 9/9 rc=0). `shared/tests/
  fixtures/adjudication/run_block_disposition_count.py` 신설 — `ast` 로
  `ast.Call`(func.attr in `tools/adjudication/check_wiring.DISPOSITION`) 과
  `ast.Dict`(`"decision": "block"`) 만 센다(주석·문자열 리터럴은 원리적으로
  안 잡힘). decoy fixture(`block_disposition_decoy.py`, 위 :222 패턴 재현)
  로 계측기 자신도 검증한다 — grep 기반이면 ndisp=1(오검출), ast 기반은
  ndisp=0(정답).
- **Task 15 수정 라운드 1 (F2, Critical) — 같은 파일 실행 절이 `**처분:**`
  라벨의 «존재»만 grep 했다.** `disposition_lines()` 는 원장이 비어도 그
  라벨을 무조건 찍으므로, 위 :804 호출을 지우면 "미판정 0" 이 찍혀도
  `assert_grep '\*\*처분:\*\*'` 는 통과했다. T5-1(구조 검증 실패 경로)이
  이미 하던 것과 같은 방식으로 T5-2(dispatch 강제 경로)에도 「미판정」
  «값»(정규식으로 추출) 을 `assert_eq` 로 재는 절을 추가 — 후보 문서 1건 →
  미판정 정확히 1.
- **양성 대조 (F1+F2)** — 두 수정 전: 위 :804 삭제(Task 15 μ11) 시 11/11
  GREEN(무검출). 수정 후 같은 삭제: F1 이 "차단 자리 2 중 1 곳이 처분을 안
  부른다" 로, F2 가 "미판정 1" 기대·"0" 실제로 각각 RED (12/14, 새 항목
  포함 14 개 중 2 개 실패). 원복 후 14/14 GREEN.
- **Task 15 수정 라운드 1 (F6, Important) — `tools/adjudication/` 아래 판정기
  넷(check_wiring/consumed/slots/names)이 `# guards:` 선언 27개 어디에도
  없었다.** 판정기를 약화시켜도 그 사실을 재는 락이 CI 선택에서 빠질 수
  있었다는 뜻이다. `fixtures/adjudication/run_*.py` 의 실제 import(`from
  check_wiring import ...` 등, 열거가 아니라 소스 grep 으로 도출)를 따라
  `test_review_dispatch_disposition.sh`(check_wiring, F1 신설분) ·
  `shared/tests/test_adjudication_wiring.sh`(check_wiring) 가 자기 판정기를
  declare 하도록 고쳤다. `test_adjudication_consumed.sh`·`test_agent_input_
  slots.sh`·`test_dispatch_name_defined.sh` 세 개는 shared/tests/ 소속이라
  이 플러그인 버전과 무관 — quality-gates CHANGELOG 가 아니라 여기 함께
  적는 이유는 이 라운드가 하나의 수정 커밋이기 때문이다(코드 변경 자체는
  플러그인 파일 밖).

## [0.52.2] — 2026-09-04

### Fixed
- **Task 14 수정 라운드 2 — v0.52.0 이 이 파일의 `## [0.51.8]` 헤딩을 `## [0.52.0]`
  으로 제자리 교체했다(Critical, 코디네이터 리뷰가 잡고 독립 재현).** 본문은
  남았지만 `[0.52.0]` 절 아래 두 번째 `### Fixed` 로 잘못 귀속됐고 `[0.51.8]`
  헤딩은 파일 어디에도 없었다 — v0.52.0/v0.52.1 커밋 로그의 "기존 최신 절 위에
  새 절을 추가했다"는 서술이 이 한 파일에 대해 거짓이었다(다른 세 CHANGELOG는
  옳았다). `git show 83754af~1` 에서 `[0.51.8]` 원문(제목+본문)을 바이트 단위로
  복원해 `[0.52.0]`·`[0.51.7]` 사이 제자리로 되돌렸다 — `diff` 로 본문 무결성
  확인.
- **이 결함이 `test_changelog_integrity.sh`(33/33 통과 상태)에 안 걸린 이유** —
  그 락의 `ver_adjacent()`(`shared/tests/test_changelog_integrity.sh:171-172`)가
  minor 경계를 넘는 인접 판정에서 **위(HI) 버전의 patch 가 0 인지만** 검사하고
  **아래(LO) 버전의 patch 값(`l3`)은 그 분기에서 전혀 읽지 않는다.** 헤딩이
  `[0.52.0]` 바로 다음에 `[0.51.7]` 로 이어지면(원래는 `[0.51.8]` 이 있어야 할
  자리) `h2 == l2+1` 이고 `h3 == 0` 이라 무조건 "인접·gap 없음"으로 판정된다 —
  중간에 통째로 빠진 patch 버전(들)이 있어도 이 분기는 그것을 볼 방법이 없다.
  실제로 재현: `ver_adjacent(0.52.0, 0.51.7)` 경로를 코드로 직접 추적하면 `l3`
  값이 조건식 어디에도 등장하지 않는다. **이 락은 고치지 않는다** — 락 강화는
  별도 판정으로 코디네이터에게 넘긴다.

## [0.52.1] — 2026-09-04

### Fixed
- **Task 14 수정 라운드 1** — `tools/adjudication/check_slots.py` 의 dispatch 펜스
  스캐너가 들여쓴 펜스(`^\s*```` 로 수정)를 이제 보고, 펜스 하나에 subagent_type
  둘 이상이면 세어서 드러낸다(`multi_agent_fences`). 이 판정기는 여러 플러그인의
  agent 정의(`plugins/*/agents/*.md`)를 검사하는 공유 파일이라 이 브랜치의 선례대로
  agent-transparency·plugin-audit·quality-gates·spec-distill 을 함께 bump(상세는
  quality-gates CHANGELOG v6.6.1 참조). 이 플러그인 몫으로 v0.52.0 이 남긴
  reviewing-spec/SKILL.md·conducting-interview/SKILL.md 의 두 dispatch 펜스
  들여쓰기를 **원복**했다 — 스캐너가 이제 들여쓴 펜스를 읽으므로 문서를 도구
  사정에 맞춰 바꿔 둘 필요가 없어졌다.

## [0.52.0] — 2026-09-04

### Added
- **agent 9개 전부(seed-readback·seed-critic·brief-critic·brief-readback·
  spec-reviewer·brief-direction-reviewer·coverage-mapper·blind-spot-prober·
  steelman-builder)에 frontmatter `input_slots:` 선언 — L3(adjudication-topology
  Task 14, 전량 GREEN).** 각 agent 가 dispatch 로 실제로 받는 (태그, 변수, `kind`)
  삼중항을 선언하고, `shared/tests/test_agent_input_slots.sh` 가 선언과 SKILL 의
  실제 dispatch 표기(`<tag>${VAR}</tag>`)가 일치하는지 + 선언된 `kind` 가 금지
  어휘(`prior_verdict`/`score`/`orchestrator_framing`)가 아닌지를 잰다.
  spec-reviewer 의 `issue_history` 는 **같은 spec 의 과거 라운드 이력**이라
  `same_origin_history` — Law 2 가 막는 "다른 리뷰어의 판정"과는 다른 축이다.

### Fixed
- reviewing-spec/SKILL.md 의 spec-reviewer dispatch 펜스와
  conducting-interview/SKILL.md 의 steelman-builder dispatch 펜스가 3-space
  들여쓰기(번호 목록 continuation)였다 — `test_agent_input_slots.sh` 의 fence
  스캐너(`re.match(r'^```')`, 줄 시작 앵커)가 들여쓰인 펜스의 시작 자체를 못 봐서
  두 dispatch 자리가 통째로 관측 밖에 있었다. 들여쓰기를 제거해 dispatch 코퍼스에
  실재하게 했다 — 내용은 무변경.

## [0.51.8] — 2026-09-04

### Fixed
- **`shared/tests/test_runner_disposition.sh`(codex 러너 처분 락)가 `consumer=` 값의
  참·거짓을 재지 못했다(adjudication-topology Task 13 수정 라운드 2).** 상세는
  quality-gates 쪽 `CHANGELOG.md` v6.5.5 참조 — `shared/tests/` 공유 파일이라 이
  락의 코퍼스(`guards: plugins/*/scripts/*codex*.sh`)에 러너가 있는 세 플러그인
  (plugin-audit·quality-gates·spec-distill, 이 플러그인 몫은
  `run_brief_codex_reviewer.sh`·`run_seed_codex_reviewer.sh`·
  `run_spec_codex_reviewer.sh` 셋) 모두 함께 bump. 요약: `consumer=`가 경로 모양이면
  `git ls-files` 정확일치로 추적 여부 + `plugins/<name>` 세그먼트로 동일-플러그인
  여부를 검사하고, `orchestrator`/`human`은 `unverifiable_consumer=N`으로 개수만
  낸다.

## [0.51.7] — 2026-09-04

### Fixed
- **codex 러너 셋(`run_brief_codex_reviewer.sh`·`run_seed_codex_reviewer.sh`·
  `run_spec_codex_reviewer.sh`)이 자기 처분을 밝히지 않고 있었다 —
  `shared/tests/test_runner_disposition.sh`(adjudication-topology Task 13) 가 여섯
  러너 26 단언 중 24 를 RED 로 잡았다(이 플러그인 몫 셋 포함, 나머지 셋은
  quality-gates·plugin-audit 쪽 CHANGELOG 참조).** 도출은 그 락의
  `# guards: plugins/*/scripts/*codex*.sh` 코퍼스에서 직접 했다(스크래치 파일 아님).
  각 러너 상단에 `**처분** — consumer=<...> · fail-<open|closed> · disclosure=<리터럴>`
  앵커를 추가했다.
  - `run_brief_codex_reviewer.sh`: `consumer=plugins/spec-distill/scripts/merge_brief_review.py`
    (충실도 축 — `reviewing-brief/SKILL.md` 가 `--codex-yaml` 로 직접 넘긴다) ·
    `fail-open`(`merge_brief_review.py` 자신의 주석대로 "codex는 모델 다양성 보조다 —
    파손을 공시하되 차단하지 않는다(primary=False)": critic 판정이 살아 있으면 codex
    실패가 approved 를 막지 않고 `advisory[]` 로만 공시된다. 방향성 축은 병합기가 없어
    SKILL.md 게이트 블록이 직접 읽어 나란히 보여준다 — 두 축 모두 codex 는 주 판정자가
    아니다) · `disclosure=advisory`.
  - `run_seed_codex_reviewer.sh`: `consumer=orchestrator`(이 축엔 병합기가 없다 —
    `framing-requests/SKILL.md` 의 codex-gate 블록 자신이 `$CODEX_YAML` 을 유일하게
    읽어 `codex_status` 를 echo 하고 격리 critic 의 findings 와 나란히 보여준다) ·
    `fail-open`(codex 가 죽어도 격리 critic 이 남는다) ·
    `disclosure=framing_degradations`.
  - `run_spec_codex_reviewer.sh`: `consumer=plugins/spec-distill/scripts/merge_review.py`
    (`reviewing-spec/SKILL.md` 가 `--codex-yaml` 로 직접 넘긴다) · `fail-open`(codex 가
    죽어도 Claude 리뷰는 이미 돌았다 — `codex_degraded: true` + `advisory[]` 로 공시하되
    `combined_verdict` 는 `claude_verdict` 를 그대로 쓴다) · `disclosure=advisory`.
  - 기존 `shared/tests/test_dispatch_disposition.sh`(Task 5 산출물, Agent()/subagent
    dispatch 축) 는 19/19 Pass 로 무변경 — 이번 앵커는 다른 락(`test_runner_disposition.sh`)
    의 코퍼스(bash 코덱스 러너 스크립트)를 대상으로 한다.

## [0.51.6] — 2026-09-04

### Fixed
- **`tools/adjudication/check_names.py` 의 `scanned_paths()` 가 `dangling()` 이 실제로 소비하는 kill-switch 코퍼스를 빠뜨리고 있었다(adjudication-topology Task 12b 수정 라운드 1, 리뷰 Critical).** 상세는 quality-gates 쪽 `CHANGELOG.md` v6.5.3 참조 — `shared/tests/`·`tools/adjudication/` 공유 파일이라 두 플러그인 다 bump. 요약: `_KILLSWITCH_GLOB` 상수를 신설해 `killswitch_keys()`·`scanned_paths()` 가 같은 글롭(`plugins/*/**/*.py`)을 쓰게 묶었고, `test_dispatch_name_defined.sh` 의 `# guards:` 에 그 bash-safe 형태(`plugins/*/*.py`)를 추가했다. 판정기의 실제 스캔 범위는 좁히지 않았다.

## [0.51.5] — 2026-09-04

### Fixed
- **새 락 여섯(+발견된 일곱째)에 `--emit-scanned` 구현 — `test_guards_coverage_bidirectional.sh` 커버리지 계약 충족(adjudication-topology Task 12b, `shared/tests/` 다섯 개가 quality-gates·spec-distill 두 플러그인 파일을 함께 검사해 두 플러그인 다 bump).** `plugins/spec-distill/tests/test_review_dispatch_disposition.sh` — 브리프가 지정한 여섯에는 없었지만(Task 11 산출물, 계획 작성 시점 이후 등장) 같은 결함 signature(`--emit-scanned` 미구현 → 자기 전체 PASS/FAIL 출력이 "스캔된 경로"로 오파싱)를 가져 함께 고쳤다 — 코퍼스가 상수(`review-dispatch.py` 하나)라 그대로 낸다.
- **`shared/tests/test_adjudication_consumed.sh` — 코퍼스에 `shared/adjudication/*.py` 를 더한다(`check_consumed.py` 의 `_closure()` 가 실제로 여는 파일).** `# guards:` 를 `plugins/*/scripts/*.py plugins/*/hooks/*.py` 에서 `shared/adjudication/*.py` 추가로 넓혔다 — 소비자 5개 전부가 `adjudication.py`·`render_disposition.py` 를 import 해 closure 에 들어오는 것을 실측 확인.
- **`shared/tests/test_agent_input_slots.sh`·`test_dispatch_name_defined.sh` — `commands/**/*.md` 를 `commands/*.md` 로 교정.** `# guards:` 를 소비하는 bash `case` 패턴에서 `**` 는 인접한 리터럴 `/` 를 요구하는데, 실제 명령 파일은 전부 flat(`commands/<name>.md`, 하위 디렉터리 없음)이라 `**` 버전은 구조적으로 아무것도 못 덮는다(`plugins/quality-gates/scripts/compute-test-scope-candidates.sh` 도 같은 bash case 매칭을 실제 테스트-스코프 선택에 쓴다 — 이 오탈자는 커버리지 락뿐 아니라 그 선택 정밀도의 실사용 버그였다). `test_dispatch_name_defined.sh` 는 `plugins/*/README.md` 도 추가(`check_names.references()` 가 이미 읽고 있었으나 선언에 빠져 있었다).

## [0.51.4] — 2026-09-04

### Fixed
- **배선 락(`shared/tests/test_adjudication_wiring.sh`)이 이 브랜치에서 처음으로 `Fail: 0` — 계획이 배정하지 않았던 네 자리(Task 11b, `merge_review.py`).** PR1 배선 baseline=미배선 14, 앞 Task 열이 review-dispatch.py 쪽 10을 닫았다고 전제했으나 계획의 어느 Task 도 `merge_review.py`의 남은 4자리(`:155`·`:160`·`:229`·`:270`)를 배정하지 않아 대표 단언이 원리적으로 GREEN이 될 수 없었다. 넷을 코드로 검증해 전부 **배선 불필요**로 판정(면제): `:155`·`:160`(`parse_codex_yaml`)은 codex YAML 파일의 텍스트 줄을 도는 라인 파서의 섹션 헤더 전이일 뿐 판정 항목이 아니다(`:160`은 오히려 `meta:` 전환 전에 `findings.append(cur)`로 진행 중이던 finding을 먼저 보존한다); `:229`(`derive_codex_verdict`)의 fold 조기 `return`은 `codex_findings` 전체가 이 함수와 무관하게 `build_ledger()`의 `for f in codex_findings:`(`:363`, 이미 배선됨)로 전수 재순회되고 표시 채널도 별도로 전체를 순회하므로 소실이 아니다; `:270`(`build_codex_findings_display`)의 `isinstance` 방어는 유일한 호출자(`main():555`)가 `parse_codex_yaml()`의 반환값을 변형 없이 넘기고 그 함수의 `findings`가 dict 항목만 생성하므로 도달 불가능하다(배선하면 Task 10의 `phase_key`와 같은 죽은 코드가 된다). `tools/adjudication/check_wiring.py`의 `EXEMPT`에 C6⑴ 인용과 함께 등재.
- **`EXEMPT`의 `review-dispatch.py` 항목 10개가 줄번호 drift로 stale — 배선 락이 이미 승인된 자리를 "미배선"으로 오탐지하고 있었다.** v0.51.2/v0.51.3(`07c9991`·`6d87b2c`)가 `select_dispatch_target()`보다 앞선 코드(`_block_with_ledger` 재작성 + import 한 줄)를 늘려 그 함수 전체가 +13(이후 구간은 +14)줄 밀렸는데, `EXEMPT`는 (파일, 줄번호) 키라 이동에 조용히 stale해졌다 — Task 11b 실측(스캔 unwired=14, 브리프 전제=4)이 적발. 코드·판정은 무변경, 10개 키의 줄번호만 현재 위치(`:340`·`:342`·`:344`·`:346`·`:348`·`:350`·`:351`·`:543`·`:546`·`:603`)로 교정하고 내부 인용 줄번호(`capped_advisory` flush 지점 등)도 함께 갱신했다.
- **`_T5_SELECT_LOOP` 면제 사유의 "다음 Stop 후보 목록에 다시 나타난다"가 두 영속-상태 필터(`DISPATCH_ATTEMPT_CAP`·`VALIDATION_ATTEMPT_CAP`)에는 거짓이었다(Task 11 리뷰가 잡은 것).** `arm_ledger.record_attempt()`가 상한 도달과 같은 write에서 `armed_paths`에도 추가하므로, 그 두 필터는 다음 Stop에 재통과하지 않는다. 결론(배선 불필요)은 그대로 두고 사유를 진짜 근거로 교체 — 상한 도달 사실은 상한에 닿던 그 dispatch 시도에서 이미 공시됐다(`DISPATCH_ATTEMPT_CAP`: `review-dispatch.py:765-770`의 mandate 메시지, `VALIDATION_ATTEMPT_CAP`: 같은 Stop 안에서 `main()`의 검증 대상 선별 루프가 만드는 `capped_advisory`). 전용 상수 `_T5_SELECT_LOOP_DISPATCH_CAP`·`_T5_SELECT_LOOP_VALIDATION_CAP` 신설.
- **`EXEMPT`와 `TERMINAL_CONSUMERS`의 C6 인용 검사가 비대칭이었다(Task 11 리뷰가 잡은 것).** `run_wiring_scan.py`의 `exempt_uncited`는 값에 리터럴 `"C6"`가 있는지 보는데 `terminal_uncited`는 빈 문자열만 아니면 통과했다 — 같은 CLAUDE.md 요구가 두 등록부에서 다른 엄격도로 걸렸다. `terminal_uncited`를 `EXEMPT`와 같은 `"C6" not in str(v)` 규율로 맞추고 `TERMINAL_CONSUMERS`의 유일한 항목에 C6⑴ 인용을 명시했다. 양성 대조: 그 항목에서 `C6`만 지우고 나머지 문장을 남긴 채 `terminal_uncited=1`로 RED가 되는지 확인 후 원복.

## [0.51.3] — 2026-09-04

### Fixed
- **T5-1(구조 검증 실패)의 원장이 「문서」가 아니라 「메시지 줄」을 세고 있었다 — 회계가 틀린 값을 냈다.** `for line in lines: L.hold(line[:60], ...)`가 `lines`(안내 헤더 + 실패 문서 목록 + 상한 도달 안내)를 통째로 돌아, 실패 문서가 N개여도 hold() 가 N+1(헤더 포함) 또는 N+2(헤더+상한 안내 포함)회 불렸다 — 자기 안내 메시지의 헤더 줄까지 "보류된 항목"으로 셌다. 이 값은 `items="closed"`라 다음 턴의 기계 소비자에게 그대로 전달된다. `failures.append(...)`를 도는 자리에서 `key`(실패한 문서 자체)를 `failed_keys`에 모으고, `L.hold()`는 이제 `failed_keys`를 돈다 — 문서 하나당 정확히 한 번. `reached_cap`은 이미 `failed_keys`의 부분집합이라 별도로 `hold()`하지 않는다(이중 계수 방지) — 상한 도달이 구조 검증 실패와 다른 사건으로서 별도 칸(`suppressed()` 등)이 필요한지는 열린 질문으로 남긴다. `plugins/spec-distill/tests/test_review_dispatch_disposition.sh`에 실패 문서 2개짜리 실행 케이스를 더해 "실패 문서 수 == disposition_lines() 의 배관 손실 칸 수"를 직접 못박는다(양성 대조로 이빨 확인) — 문서가 하나뿐이면 이 off-by-one이 안 보이므로 반드시 둘 이상으로 재야 한다.

## [0.51.2] — 2026-09-04

### Fixed
- **훅의 차단 결정 두 자리가 소비 락(L2)을 다시 침묵시키고 있었다 — `reasons()` 대신 공유 렌더러로 바꾼다.** 전량 회귀 스윕이 `shared/tests/test_adjudication_consumed.sh`를 다시 RED(`unconsumed_total=8`)로 잡았다. `_block_with_ledger()`가 `ledger.reasons()`(`shared/adjudication/adjudication.py:136-149`)만 읽었는데, 그 함수는 `held`·`unknown`·`sources_failed`·`coerced(gate=True)` 넷만 낸다 — `accepted`/`rejected`/`absorbed`/`suppressed`는 한 줄도 안 낸다. 오늘 이 훅이 `hold()`만 불러 우연히 전부 덮였을 뿐, 앞으로 이 훅에 `L.reject(...)` 하나만 늘어도 공시가 조용히 사라지는 구조였다("오늘은 맞고 내일은 침묵"). `_block_with_ledger()`가 이제 원장 `report()`/`held_by_class()`를 공유 렌더러 `disposition_lines(report, held_classes)`(`shared/adjudication/render_disposition.py`, 소비자 넷이 이미 쓰는 것)로 낸다 — 카운트 이름을 손으로 다시 적지 않는다. **배치가 계약이다**: 이 훅의 `reason`은 모델을 움직이는 지시문(카나리 7/7 도달)이므로 지시문을 먼저 두고 처분 두 줄(+advisory)을 **뒤에** 붙인다. `plugins/spec-distill/tests/test_review_dispatch_disposition.sh`에 실행 절을 더해 실제 `decision:"block"`을 발생시켜 `reason`이 "MANDATORY..." 뒤에 "**처분:**"/"**배관 손실:**" 줄을 순서대로 담는지, `systemMessage`에는 처분 줄이 새지 않는지를 직접 검증한다 — 이전 판의 `assert_grep 'reasons\(\)'`는 구현이 바뀐 뒤에도 이 테스트 파일 자신의 설명 주석이 그 문자열을 우연히 담고 있어 계속 GREEN이었다(값싼 검사였다는 신호). 기존 `.reason` 내용을 못박는 두 테스트(`test_review_dispatch.sh` Case 11·17, `test_review_dispatch_design_mandate.sh` AC2·AC12)는 이 변경으로 깨지지 않는다 — 처분 줄을 기존 지시문 **뒤에 추가만** 하므로 `contains(...)` 단언이 그대로 성립한다(16/16 GREEN 확인).

## [0.51.1] — 2026-09-04

### Fixed
- **v0.51.0 Known gaps 둘 중 하나 — `:533` 면제 사유가 범주 착오였다.** 최초 사유는 "`systemMessage`는 모델 도달 카나리 0/14라 채널 효과가 의심된다"였다 — 그러나 `systemMessage`는 애초에 **사람의 터미널** 채널이지 모델 컨텍스트 채널이 아니다(CLAUDE.md: "미판정 항목의 방향은 다음 소비자가 정한다: 기계면 제외, 사람이면 라벨을 붙여 보여준다"). T5-1·T5-2가 채널을 `reason`으로 정한 이유는 그 두 자리의 소비자가 **모델**(다음 턴 dispatch 판단)이었기 때문이고, `:533`의 소비자는 **사람**(세션을 보는 사람에게 "자동 검증을 안 하는 문서가 있다"고 알리는 것)이다 — 모델 미도달은 이 채널의 설계이지 결함이 아니다. `tools/adjudication/check_wiring.py`의 `EXEMPT[:533]` 사유를 다시 썼다. **면제 자체(C6⑴)와 "최종 리뷰 재검토" 표시는 그대로 유지** — 이 스킵이 규칙(상한값)이 정한 배제라는 점에서 `suppressed()` 재분류 후보라는 열린 질문은 남아 있다.
- **v0.51.0 Known gaps 둘 중 다른 하나 — import·앵커 대칭 락을 개수 비교에서 집합 비교로 강화.** `shared/tests/test_adjudication_wiring.sh`의 `assert_eq "$n_import" "$n_anchor"`(개수만 비교)는 대리지표였다 — 한 파일이 import에서 빠지고 무관한 다른 파일이 anchor에 들어와도 개수가 같으면 그대로 통과한다. 두 단언으로 교체: **① `ANCHOR ⊆ IMPORT` (예외 없음)** — dispatch 자리가 `consumer=`로 선언한 파일이 실제로 원장을 import하지 않으면 거짓 선언이다. **② `(IMPORT \ ANCHOR) ⊆ TERMINAL_CONSUMERS`** — 앵커 없이 import만 하는 파일은 새 상수 `tools/adjudication/check_wiring.py::TERMINAL_CONSUMERS`(`EXEMPT`와 같은 규율: 사유 없는 항목은 그 자체로 RED)에 "왜 dispatch 앵커를 가질 수 없는가"를 사유와 함께 등재해야 한다. `review-dispatch.py`를 등재 — 종단(terminal) 결정자라 이름 붙일 dispatch 자리가 원리적으로 없다(subagent findings를 판정하는 소비자가 아니라 자기 자신의 `decision:"block"`을 직접 정한다). `shared/tests/fixtures/adjudication/run_wiring_scan.py`가 `IMPORT`/`ANCHOR`/`TERMINAL` 세 목록(집합)과 `terminal_total`/`terminal_uncited`를 새로 낸다.

## [0.51.0] — 2026-09-04

### Added
- **훅(`review-dispatch.py`)의 차단 결정 두 자리가 원장 어휘로 자기 처분을 밝힌다(T5, adjudication-topology Task 11).** `from adjudication import Ledger`를 더해 이 훅이 처음으로 회계 소비자(㉮)에 들어온다. 구조 검증 실패 자리(구 `:605`대, 재도출 `:621`대)는 실패한 문서마다 `L.hold(line[:60], "항목 파손: 스코프 문서 구조 검증 실패")`를, 다음 턴 dispatch 강제 자리(구 `:758`대, 재도출 `:774`대)는 `L.hold(str(cand.path), "판정자 부재: 리뷰가 아직 안 돌았다 — 다음 턴에 강제한다")`를 부른다. 새 헬퍼 `_block_with_ledger()`가 `ledger.reasons()`의 줄을 `reason` 필드에 실어 낸다 — **채널은 `reason`이다.** 같은 두 자리가 이미 내는 `systemMessage`는 인터뷰 카나리 실측(14개 중 0개 모델 도달) 때문에 쓰지 않는다; `reason`은 차단 결정에 딸릴 때 7/7 도달한다. 원장 객체는 프로세스와 함께 사라지므로 `reasons()`의 줄을 `reason`에 실어 보내는 것으로 이 층의 회계가 완료된다(코드 주석에 근거 기록).
- `plugins/spec-distill/tests/test_review_dispatch_disposition.sh` — 두 차단 자리 각각이 처분 호출(`hold`/`reject`/`source_failed`/`uncountable`)을 갖는지, `reasons()`를 읽는지, 그 사유를 `systemMessage`가 아니라 `reason`에 싣는지를 검사한다.
- `tools/adjudication/check_wiring.py`의 `EXEMPT`에 `review-dispatch.py`의 열 자리(㉮ 편입으로 새로 대상이 된 `select_dispatch_target()`의 선택 루프 7곳 + `main()`의 검증 대상 선별 루프 3곳)를 C6⑴ 인용과 함께 등재. 근거는 코드를 읽고 확인했다: `discover()`가 매 Stop마다 git status로 무상태 재스캔하므로 이번 턴에 선택되지 않은 후보는 다음 턴에 다시 나타난다 — 소실 개념 자체가 성립하지 않는다.

### Known gaps
- **T5-1·T5-2가 배선한 `Ledger` import가 `shared/tests/test_adjudication_wiring.sh`의 import·앵커 대칭 축(㉮ 두 도출 경로가 같은 개수여야 한다)을 깬다.** `by_import`는 5(review-dispatch.py 포함)인데 `by_anchor`는 4로 그대로다 — 어떤 skill/command/agent 문서도 `consumer=review-dispatch.py`를 인용하지 않는다. 이 훅은 스킬이 dispatch한 subagent 결과를 받아 회계하는 소비자가 아니라 자기 자신의 `decision:"block"` 판단을 직접 회계하는 종단(terminal) 소비자라, 기존 앵커 대칭 검사가 전제하는 "모든 import 소비자는 어딘가 `consumer=`로 인용된다"는 가정이 이 범주(훅)에는 처음부터 성립하지 않을 수 있다. `derive_consumers()`/`test_adjudication_wiring.sh`를 훅과 스크립트 두 범주로 나눌지는 설계 판단이 필요해 이번 Task(T5, 파일 범위: 훅 + 새 테스트 + plugin.json/CHANGELOG)에서는 고치지 않았다 — 다음 리뷰가 볼 것.
- **`tools/adjudication/check_wiring.py`의 EXEMPT `:533`(검증 상한 도달 스킵)은 경계 사례다.** 항목(`c.key`)은 `capped`→`capped_advisory`를 타고 실제로 이번 턴 JSON 출력의 `systemMessage`에 실리므로 C6⑴(대응물 없음)로 면제했지만, 바로 이 Task가 옆 두 `decision:"block"` 자리에서 실측한 사실 — `systemMessage`는 모델 컨텍스트 도달 카나리 0/14 — 이 이 채널에도 적용될 가능성이 있다. 소실은 아니나 채널 효과가 의심되는 자리라 규칙 억제(`suppressed()`)로 재분류할 후보로 남긴다.

## [0.50.1] — 2026-09-04

### Changed
- **`merge_brief_review.py`가 형제 `merge_review.py`와 같은 모양으로 처분 회계를 stdout에 낸다(v0.50.0 Known gaps 해소, Task 10 수정 라운드 1).** 원장이 하나(`Ledger(items="open")`, `:228`)뿐이라 형제처럼 셋을 합칠 필요는 없다 — 그 하나의 `report()`/`held_by_class()`를 `disposition_report()`로 이름을 펴 `adjudication_held`/`adjudication_unknown`(기존 두 키) 뒤에 나머지 열한 개(`adjudication_accepted`/`rejected`/`absorbed`/`coerced`/`sources_failed`/`suppressed`/`unknown_counts`/`degraded`/`held_unadjudicated`/`held_malformed`/`held_other`)를 더한다. `reviewing-brief/SKILL.md:323`의 키 열거를 갱신 — 형제 `reviewing-spec/SKILL.md:116`만 갱신돼 있던 비대칭을 없앤다.
- **락 우회가 아니라 락 갱신.** `test_merge_brief_adjudication.py::TestExternalKeysUnchanged::test_top_level_keys_are_exactly_the_declared_set`(2026-08-23, `7e6ad51`)이 top-level 키를 정확히 8개로 고정하던 것은 «신규 키 금지»가 아니라 «선언 없는 신규 키 금지»(신중함 게이트)였다 — `DECLARED_KEYS`에 새 키 13개를 리터럴로 추가하고 `assertEqual`은 그대로 유지해(부분집합 검사로 바꾸지 않음) 그 계약을 21개로 다시 선언했다. `test_garbled_differs_materially_from_control`(clean 라운드 `advisory == []` 고정)은 실측으로 **깨지지 않았다** — 새 키는 전부 top-level이지 `advisory` 항목이 아니고, `disposition_report()`가 내는 `reasons`/`held_by_class`는 루프가 건너뛴다. `test_merge_brief*.py` 40/40 GREEN(직접 확인).

## [0.50.0] — 2026-09-04

### Added
- `plugins/spec-distill/scripts/render_disposition.py` — `shared/adjudication/render_disposition.py`로 가는 git 심볼릭 링크(mode 120000, `adjudication.py`와 같은 방식). `disposition_lines()`/`disposition_report()` 두 함수를 quality-gates와 공유한다.

### Changed
- `merge_review.py`가 세 원장(claude·codex·history)의 `report()`/`held_by_class()`를 합산해 `disposition_report()`로 이름을 편 뒤, 기존 `adjudication_held`/`adjudication_unknown` 두 키 뒤에 `adjudication_accepted`/`adjudication_rejected`/`adjudication_absorbed`/`adjudication_coerced`/`adjudication_sources_failed`/`adjudication_suppressed`/`adjudication_unknown_counts`/`adjudication_degraded`/`adjudication_held_unadjudicated`/`adjudication_held_malformed`/`adjudication_held_other`를 stdout에 더한다. 카운트 이름을 손으로 다시 적지 않는다 — 공유 헬퍼가 편 dict 를 루프로 돈다(L2 코퍼스가 그 import를 따라간다). `reviewing-spec/SKILL.md:116`의 키 열거를 새 키 전부를 반영하도록 갱신.

### Known gaps
- **`merge_brief_review.py`는 이 릴리스에서 `adjudication_*` 키를 하나도 내지 않는다** — 형제 `merge_review.py`와 달리 오늘 하나도 없어 전부 신규였는데, 그대로 추가하면 두 기존 락이 깨진다: (1) `test_merge_brief_adjudication.py::TestExternalKeysUnchanged::test_top_level_keys_are_exactly_the_declared_set`(2026-08-23, `7e6ad51`)가 top-level 키를 정확히 8개로 고정하고 "새 top-level 키를 추가하지 않는다 — 회계는 이미 escape되는 `advisory`에만 싣는다"를 명시적으로 선언한다. (2) `test_merge_brief_review.py::test_garbled_differs_materially_from_control`가 clean 라운드의 `advisory == []`를 고정한다 — disposition 두 줄을 advisory에 무조건 추가해도 이 락이 깨진다. 두 락 모두 이 브랜치 이전부터 있던 계약이라 판정 없이 넘어가지 않았다. 이 파일이 남아 있는 한 `shared/tests/test_adjudication_consumed.sh`(L2)는 이 파일에 대해 8개 키 전부 미소비로 RED다.

## [0.49.0] — 2026-09-03

### Added
- `Ledger.suppressed(item, why)` — 규칙 억제를 기각과 분리된 칸으로 센다. 차단도 degrade 도 아니다.
- `Ledger.held_by_class()` — `hold()` 사유의 접두별 개수. 미지 접두는 「기타」로 세어 합이 `held` 총계와 항상 일치한다.

### Changed
- `report()["counts"]` 에 `suppressed` 추가 (여섯 → 일곱).

## [0.48.0] — 2026-09-03

### Fixed

- **`reviewing-brief`가 더 이상 배포 단위 밖 파일(`docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`)을
  실행 시점 선결조건으로 읽지 않는다.** 그 파일은 플러그인 배포 단위 밖이라 devbrew 리포 밖
  사용자에게는 존재하지 않았고, fail-closed가 곧 100% 차단이었다. 판정이 이미 `ZERO_TOOL_OK`
  였으므로 오늘 도는 갈래(`tools: []`)만 남기고 probe 이진 분기 자체를 지웠다 — 완화가 아니라
  유지다. 감사 문서(`docs/audits/2026-07-27-...md`)는 근거 기록으로 남긴다 — 지우는 것은
  그것을 실행 시점에 읽던 코드이지 기록이 아니다.
- `test_brief_agents.sh`의 probe 판정 판독 + 분기별 `tools:` 대조를 **집합 등식 L**로
  올렸다: 스캔한 `tools: []` 집합 == 리터럴 이름 넷(`brief-critic`·`brief-readback`·
  `seed-critic`·`seed-readback`). 대상을 `tools: []`에서 도출하면 하나를 넓히는 변이가
  대상 집합을 벗어나 공허참으로 통과하므로, 우변을 리터럴로 고정했다. 신규
  `test_brief_review_no_external_precondition.sh`(B1)가 감사 문서 없는 임시 루트에서
  격리 락이 실제로 돌고 통과함을 양성 증인으로 확인한다.
- `merge_brief_review.py`·`README.md`·`build_brief_inline_blob.py`의 조건부 서술("zero-tool
  probe 통과 분기에서만 차단" / "실패 분기·통과 분기")을 무조건 서술로 고쳤다 — 분기 자체가
  사라져 조건부 문장이 자기 코드의 반대를 주장하고 있었다.
- `check_brief.py`의 `frontmatter_errors()`가 더 이상 `next_phase` 값을 판정하지 않는다.
  `next_phase: superpowers:brainstorming` 정확 일치를 요구해, superpowers 미설치 사용자에게
  구조 게이트가 통과 불가였다. 이 필드를 읽는 런타임 소비자는 0이다(템플릿·픽스처·이
  게이트뿐). 필드 자체는 템플릿에 정보성 메타데이터로 남긴다 —
  `test_brief_no_statement_cap.sh`가 그 줄을 앵커로 쓴다. 신규
  `test_check_brief_frontmatter.py`가 `next_phase` 축의 무판정과 나머지 축(`type`·
  `audit_file`·`user_sourced_items`)의 판정 유지를 함께 확인한다.
- **`/compact` 안내에서 확인되지 않는 도착 주장을 걷어냈다.** "compact 후 brainstorming
  진입 준비됨"은 압축 뒤의 상태에 대한 주장인데 아무도 확인하지 않는다. 사람이 다음 턴에
  무엇을 하는지로 바꿨다 — 이 자리의 유일한 운반자가 사람임을 숨기지 않는 문면이다.
  인터뷰가 확정한 C12(PreCompact matcher=manual 신설)를 재결정했다 — 이 리포에
  PreCompact/PostCompact 훅이 0개라 채널 선택이 아니라 신설이고 brief의 Non-goal이
  막으며, `finishing.md:243-244`가 이미 사람을 유일 트리거로 적고 있어 철회할 자동
  이어짐 약속이 애초에 없었다. 측정(`MEASUREMENT.md`의 `COMPACT_CHANNEL_OK`)은 원안을
  지지했다 — 기각 근거는 "되지 않는다"가 아니라 "새로 만들 값어치가 없다"다.
  `<brief-path>` 치환 지시를 더했으나 락은 없다(Known gaps 참고).
- **핸드오프가 네 인자를 넘긴다.** `finishing.md:101`이 `$PAYLOAD`·`$AUDIT`·
  `$CODEX_DIR_YAML`·`$CODEX_FID_YAML` 넷 중 셋만 넘겨 `$AUDIT`가 빠졌다. 조용히 죽지는
  않지만 두 소비자가 함께 무너진다 — `build_brief_bundle.py`가 rc 2로 충실도 리뷰를
  통째 skip하고, `check_verbatim_coverage.py`의 §6 원문 완전성 결정론 검사가 같은 빈
  값으로 깨진다. `test_brief_review_entry.sh:172`·`:190`의 락이 결함을 **요구**하고
  있었으므로(세 변수만 순회·세 할당만 확인) 같은 커밋에서 넷으로 고쳤다. 앞선 논거
  하나도 철회했다 — brief §6 S1이 "v0.47.0이 빌더 쪽에서 스스로 구하게 고쳤다"고
  적었으나 코드는 반대다: `build_brief_bundle.py:106`이 audit을 위치 인자로 요구한다.
  v0.47.0이 더한 것은 자기 도출이 아니라 신원 대조였다.

### Changed

- `hooks/review-dispatch.py`의 목적지 skill 이름이 **모듈 상수 한 자리**에서 온다.
  런타임 메시지 6곳이 각자 `"reviewing-spec"`을 리터럴로 들고 있었다. 상수는
  `hook_common.py`가 아니라 이 파일에 둔다 — 소비자가 이 파일 하나뿐이다. 락은
  「런타임 메시지 전부가 상수 값을 포함한다」로 세웠다 — 삭제 변이로는 이빨을 못 잰다
  (상수를 지우면 import 에러로 전부 죽어 "함께 죽었다"가 "한 자리에서 온다"의 증거가
  되지 못한다), 그래서 값 변경 변이로 잡는 형태다. 그 락 자신도 구멍이 있었다 —
  재도출한 현재 상수 값으로 grep했기 때문에, 상수를 바꾸고 한 자리만 옛 리터럴로
  되돌리는 보간-실패 변이(MU9b)에서 grep 키가 새 이름이라 그 자리가 애초에 매치
  후보가 아니어서 GREEN으로 통과했다. 재도출 키(현재 값의 벌거벗은 사본)와 핀한
  리터럴(보간 실패 포착) 둘 다 두어 고쳤고, 보간 자체의 양성 증인도 앞에 세웠다 —
  없으면 런타임 메시지를 통째로 지워도 부재 단언 둘이 공허하게 통과한다.

### Known gaps

- `hooks/review-dispatch.py:16`의 모듈 docstring은 목적지 skill 이름을 리터럴로
  적는다 — f-string이 될 수 없어 손 갱신으로 남고, 상수 값과 갈리는 드리프트를 잡는
  자리가 없다.
- `/compact` 템플릿의 `<brief-path>` 치환에는 **기계가 없다** — 모델이 사용자에게
  보여준 텍스트를 읽는 훅이 리포에 없다. 이번 작업이 검사와 함께 완료를 주장하는
  아홉 자리 중 이 한 조각만 검사 없이 남아, 완료 주장이 아홉이 아니라 **여덟**이다.
- 병합 완료로 판정한 형제 설계 문서(`docs/superpowers/specs/2026-08-05-...design.md`
  등, 머지 시점에 실재 확인된 것들)는 제거된 zero-tool probe 분기를 여전히 살아 있는
  것으로 서술한다 — 머지된 설계 문서는 그 순간의 기록이라 의도적으로 다시 쓰지
  않았다.
- `shared/tests/assert.sh`에는 `pass`/`fail` 카운터가 없다(`_ASSERT_PASS`/
  `_ASSERT_FAIL`만 있다). 그런데도 `set -u -o pipefail` 아래서 `$((pass+fail))`을
  참조하는 조기 종료 관용구가 이 파일을 source하는 여러 테스트에 남아 있다
  (`plugins/spec-distill/tests/test_brief_codex_axes.sh:21`·
  `test_handoff_design_mode.sh:29` 등). **직접 재현**: 같은 참조라도 구문 위치에
  따라 결과가 갈린다 — `test_handoff_design_mode.sh:29`처럼 `if [[ -z … ]]; then
  …; fi` 블록 **안**에서 걸리면 `set -u`의 unbound-variable abort가 **exit 0** 로
  관측된다(동형 스크립트로 rc=0 실측) — 진짜 실패를 안은 실행이 rc만 보는 상위
  러너(`run-baseline.sh` 포함)에 PASS 로 잡힌다. `test_brief_codex_axes.sh:21`처럼
  최상위 `||` 형태로 걸리면 rc=1 로 죽어 이쪽은 여전히 FAIL 로 잡힌다(메시지만
  깨진다). 같은 결함이 구문 위치에 따라 fail-open 과 fail-closed 로 갈리는 것이다.
  이번 범위 밖 — 별도 수정이 필요하다.

### Removed

- `reviewing-brief/SKILL.md`의 `## zero-tool 격리 선결 조건` 절(probe 통과/실패 두 갈래 +
  실패 분기의 degrade record 2건). `test_reviewing_brief_skill.sh`의 T23 probe 이진 분기
  검사. `test_brief_review_state.py`의 probe 실패 2-record 전제 테스트.
  `test_brief_review_meta.sh`·`interview-audit-template.md`의 `zero-tool` 항목.

## [0.47.0] — 2026-08-31

### Fixed

- **§6 경계를 세 소비자가 각자 계산하던 것을 한 곳으로 모았다 — `scripts/section6.py` 신설.**
  v0.46.0 은 §6 의 **시작** 좌표만 못 박았는데, §6 은 (시작, 종결) 두 좌표를 갖고 세 소비자의
  종결 규칙이 서로 달랐다: 게이트는 펜스 **밖** `^##\s+\d+\.` · `build_brief_bundle.py`는
  **원문** `^##\s+\d+\.` · `check_verbatim_coverage.py`는 **원문** `^##\s`. 그래서 audit §6
  **안**에 **펜스로 감싼** `## 7.` 한 줄을 두면 게이트는 rc 0 인데 번들은 거기서 잘렸다 —
  실측 두 형태: ① 삭제형 — `<<<AUDIT-VERBATIM>>>` 블록이 **비고**(진짜 `S2`+ 전량 소실)
  ② 위조형 — 그 자리에 심은 `S2` 가 ground truth 로 실리고 진짜는 사라진다. v0.46.0 이 닫은
  audit-펜스 공격(F)과 **바이트 단위로 같은 결함**이 종결 좌표에서 재발한 것이다.
  **「종결도 못 박는다」로 고치지 않았다** — 그러면 세 번째 좌표에서 또 난다. 술어를 올렸다:
  **§6 은 모든 소비자에게 같은 영역으로 해석돼야 한다.** 구현은 계산기를 셋에서 하나로 줄이는
  것이고(어긋남이 「지금 없다」가 아니라 **생길 자리가 없다**), 판정은 **가장 관대한 읽기와
  가장 엄격한 읽기가 일치하는가** 한 술어다 — 두 극단은 위 표의 실제 소비자 규칙에서 뽑았지,
  손으로 고르지 않았다. 시작 후보는 **제목을 요구하지 않는다**(`^##\s*6\.`) — 요구하면
  `## 6. 참고 자료` 같은 줄이 후보에서 빠지는데, 옛 `check_verbatim_coverage.SECTION6_RE`는
  실제로 그런 줄을 §6 시작으로 골랐다. 죽은 경계 계산기(`_first_unfenced`·`_fence_spans`·
  `PAYLOAD_SECTION6_RE`·`ANY_SECTION_HEADING_RE`)는 걷어냈다 — 남겨 두면 다음 사람이 그것을
  다시 쓴다.
- **`build_brief_bundle.py`가 게이트가 축복한 audit 을 싣는다 (신원 결속).** 게이트는
  `resolve_audit(payload)` = `<stem>.audit.md` 를 검사하는데 빌더는 호출자가 준 `$AUDIT` 를
  읽었고, **둘을 묶는 것이 아무것도 없었다** — `reviewing-brief` SKILL 은 `$AUDIT` 를
  「호출자가 넘기는 값」이라 적고, 그 호출자(`finishing.md` Step A.5)는 세 변수를 넘기는데
  그중에 `$AUDIT` 가 없다. 실측: 게이트가 `I.audit.md` 로 통과시킨 payload 로 빌더에 전혀
  다른 파일을 넘기면 위조 원문이 ground truth 로 rc 0 에 실린다. 빌더가 이제 조립 **전에**
  `check_brief.resolve_audit()` 로 payload 가 선언한 sidecar 를 구해 인자와 대조하고, 다르면
  rc 2·무조립이다. **경로를 유추하지 않는다는 원칙은 그대로다** — 호출자는 여전히 명시해야
  하고, 빌더는 그 명시가 게이트의 해석과 다를 때 **거절**한다(`resolve_audit` 자신이
  「찾는 것이 아니라 고르지 못하게 거절하는 것」이라 적은 그 층).
- **`reviewing-brief` 가 첫 번들 조립 전에 구조 게이트를 돌린다 (순서 결속).** 이 skill 은
  model-invocable 이고 description 이 직접 진입을 초대하는데, 파일 안에서 게이트가 도는
  유일한 자리는 2-c(충실도 수정 **후** 재실행)였다 — 진입 첫 액션은 강등 가능한
  `check_verbatim_coverage.py` 이고, 유일한 사전 게이트는 **다른 skill**
  (`conducting-interview/references/finishing.md`)에 있다. 즉 이 skill 로 직접 들어오면
  **첫 번들이 게이트를 통과한 적 없는 payload 로 조립됐다.** 2-a 조립 블록 머리에서 게이트를
  돌리고 미통과면 진입 자체를 중단한다.
- **충실도 축 `omission` 정의의 코퍼스 검사가 어구 검사였다 (v0.46.0 F15 ②의 결함).**
  「`ground truth` 라는 어구가 있으면 두 위치에 위임한 것으로 본다」였는데, 그것은 범위가
  아니라 어구를 쟀다 — 「something load-bearing in the **audit** ground truth …」로 고쳐 쓰면
  형용사 하나로 코퍼스가 절반이 되는데 어구는 그대로라 **rc 0 · 94/94** 였다(실측). 위임
  분기를 없애고 **두 표지 리터럴의 동시 존재**를 요구한다 — 형용사로는 만족시킬 수 없다.
  체크리스트의 `omission` 불릿도 두 위치를 직접 열거하도록 고쳤다.

### Added

- **`test_check_brief.sh` — §6 단일화 파생 락.** 소비자 목록을 손으로 적지 않는다:
  `scripts/*.py` 의 `re.compile` 문자열 리터럴을 `ast` 로 전수 수집해 「`##` 헤딩 마커를
  실제로 소비하는」 패턴(프로브 매치가 `end>=3` — 주석 패턴 `^\s*#` 는 `end==1` 로 걸러진다)을
  고르고, 그런 패턴이 `section6.py` **밖**에 있으면 red. 새 소비자가 자기 규칙을 들고
  나타나는 순간 걸린다. **계측기 대조**를 함께 돌린다 — 같은 탐지기를 stray 를 심은 합성
  소스에 돌려 실제로 잡는지 확인한다(없으면 「밖에 없다」와 「탐지기가 안 봤다」가 구별되지
  않는다). 파싱 실패 파일도 red 로 낸다(코퍼스 누락 = 침묵).
- **`test_check_brief.sh` — 3소비자 행동 대조 락.** 같은 문서에서 세 소비자의 §6 답을
  나란히 놓고 **셋이 같은지**만 본다(어느 답이 옳은지는 판정하지 않는다 — 피검자에서
  기대값을 끌어오지 않기 위해). 정상 문서의 공통 답이 비면 등식이 「셋 다 아무것도 못 봤다」로
  공허해지므로 그 경우를 따로 red 로 낸다.
- **`test_check_brief.sh` — N1c 축을 종결 좌표까지 넓혔다.** 케이스 8 → **12**(시작 4값 +
  종결 2값, 각각 armed/중화 짝). 중화판은 주입한 줄에서 헤딩 표기만 없앤 것이라, red 의 원인이
  그 줄임을 증명한다.
- **`test_check_brief.sh` — 경계 매처 관대함 락(양성 5 + 음성 6).** v0.46.0 의 mutation 은
  펜스 축만 흔들어 **제목 축이 열려 있었다** — 매처에 제목을 요구하도록 좁혀도 157/157 이었다.
  좁히는 변이(제목 요구)와 넓히는 변이(`## 16.` 까지 매치) 양쪽이 물린다.
- **`test_brief_bundle.sh` — T15 신원 결속 락 · T16 종결 좌표 락.** T15 는 **내용이 아니라
  신원**을 잰다: 바이트가 같은 audit 을 다른 이름으로 넘기면 rc 2, 올바른 이름이면 rc 0
  (양성 짝이 없으면 「항상 거절」인 빌더도 통과한다). T16 은 거절 시 **아무것도 내보내지
  않음**까지 단언한다 — 빈 ground truth 로 「왜곡 없음」이 나오는 경로가 이 결함의 본체였다.
- **`test_reviewing_brief_skill.sh` — ORD 순서 락.** 문면이 아니라 **위치**를 잰다: SKILL 의
  bash 라인을 순서대로 놓고 첫 `check_brief.py gate` 인덱스 < 첫 `build_brief_bundle.py`
  인덱스. 두 앵커의 실재를 먼저 단언해 부등식이 공허해지지 않게 한다.

### Changed

- **`check_verbatim_coverage.py` 의 §6 경계 모호는 `ParseError`(검사 불가, exit 3)가 아니라
  `StructuralViolation`(위반, exit 1)이다.** 「어느 §6 을 봤어야 하는지 모른다」를 검사 불가로
  내리면 전 statement 의 L1·L2 가 조용히 skip 된다.

### Known gaps

이 릴리스가 닫지 못한 것. **이 절이 이 사실들이 살아남는 유일한 자리다** —
`.superpowers/sdd/` 는 `.gitignore` 가 `*` 라 프로젝트 종료 시 사라진다.

- **G — `landscape_unkeyed`(#13)의 펜스 코퍼스 구멍. 열려 있다.** §4 항목을 ```펜스``` 안에
  적으면 「항목마다 «출처키»」 ∀ 를 통과하는데 그 주장은 payload 에 그대로 실려 나간다.
  재현: `interview-brief-valid.md` §4 항목 줄 **뒤에** 펜스 블록을 넣고 그 안에
  `- 출처 없는 landscape 주장 — [취함] — 근거 없음` 한 줄 → `gate` **rc 0**,
  `landscape-keys` → `{"unkeyed": []}`. §6 계열(N1a/N1b)과 **같은 결함 계열**(검사의 코퍼스가
  출하되는 텍스트를 조용히 제외)이지만 다른 검사다. 안 닫은 이유: `_body()` 의 펜스 스트립은
  **존재 검사에서는 의도된 엄격함**(F4 — 펜스 안 헤딩으로 절 존재를 만족시키는 우회 차단)이라,
  「펜스 안 항목이 저술된 주장인가 예시인가」는 이 수정이 혼자 내릴 판단이 아니다.
- **`check_verbatim_coverage.py` 는 여전히 게이트보다 **먼저** 돈다.** v0.47.0 이 닫은 것은
  「게이트 → 첫 번들」 순서이고, `reviewing-brief` 의 **진입 첫 액션**은 그대로 완전성
  검사다. 즉 그 스크립트는 아직 게이트를 통과하지 않은 payload 를 볼 수 있다. 보안 관련
  순서(검증되지 않은 원문이 ground truth 로 나가는 경로)는 닫혔고, 남은 것은 강등 가능한
  advisory 검사가 미검증 문서에서 혼란스러운 메시지를 낼 수 있다는 것이다.
- **존재 기반 락은 부정문을 못 잡는다.** F15 ②는 `omission` 불릿이 두 표지를 **둘 다** 담을
  것을 요구하는데, 둘을 다 적고 「두 번째는 무시하라」를 덧붙인 문면은 통과한다. 문면의
  의미를 기계로 재는 방법이 이 층에 없다.
- **`section6.py` 는 형제 모듈 import 다.** 스크립트 하나만 다른 디렉토리로 복사해 돌리면
  `ModuleNotFoundError` 로 죽는다(fail-closed이지만, 변이 하니스처럼 파일을 옮겨 돌리는
  관행은 sibling 을 함께 옮겨야 한다 — `test_check_verbatim_coverage.sh` C1 을 그렇게 고쳤다).
- **§6 «내부» 위조는 아직 열려 있다 (선재).** audit §6 **안에** 백틱 펜스를 두고 그 안에
  `- **S9** …` 를 적으면 `gate` **rc 0** 이고 번들이 그것을 `<<<AUDIT-VERBATIM>>>` 안에
  ground truth 로 싣는다. `check_verbatim_coverage` 도 못 잡는다 — L1 이 「state ⊆ items」라
  **추가된** 발화는 정의상 위반이 아니다. 경계 불변식은 §6 이 *어디서 시작해 어디서 끝나는지*를
  못 박지, 그 **안**에 무엇이 들어오는지는 재지 않는다. `51312e6` 에서도 동일하게 재현된다.
- **`~~~` 물결 펜스는 두 읽기 모두 펜스로 보지 않는다 (선재).** audit §6 안에 `~~~` 로 감싼
  `## 7.` 을 두면 관대·엄격 두 읽기가 **함께** 거기서 자르므로 「유일하게 해석된다」가 참이 되고,
  그 뒤의 `S<N>` 이 번들에서 조용히 사라진다. 실측에서 게이트가 빨간 경우가 있으나 그것은
  **N2 가 §7 이 비었음을 우연히 눈치챈 것**이지 경계 검사가 잡은 것이 아니다 — 그 backstop 이
  걸리지 않는 배치에서는 통과한다.
- **「§6 이 모든 소비자에게 한 영역으로 확정된다」는 출하 코드에 대해 아직 참이 아니다.**
  `ast` 도출 락이 수확하는 것은 **모듈 수준 `re.compile(<문자열 리터럴>)`** 뿐인데,
  `check_brief.py` 의 `_section_text` 는 f-string + `re.search` 로 §6 경계를 계산해 수확에
  잡히지 않고, 그 함수를 쓰는 `verbatim_anchors()` 가 살아 있는 audit §6 소비자다. TRI 락도
  준수 경로인 `payload_verbatim_anchors` 만 비교하고 발산하는 `verbatim_anchors` 는 안 본다.
- **ORD 락은 «텍스트»를 묶지 «효과»를 묶지 않는다.** 게이트 호출을 실행 없는 `echo` 로
  바꿔도 통과한다(호출을 통째로 지우면 잡힌다). 순서는 지켜지되 그 게이트가 실제로 도는지는
  이 락이 재지 않는다.
- **codex co-reviewer 가 이 작업 전체에서 사용 불가였다(한도 소진, 호출 0회).** 설계 8라운드와
  v0.46.0·v0.47.0 두 릴리스 전부가 **단일 모델 계열**의 판단이다. 이 리포 이력상 단일 계열이
  가장 자주 놓치는 것이 fail-open·조용한-0건 계열이고, 이 두 릴리스가 고친 결함이 정확히 그
  계열이다. 여기 적힌 판단들은 증명이 아니라 표본으로 읽어야 한다.

## [0.46.0] — 2026-08-31

### Fixed

- **N1c 신설 — payload·audit의 §6 헤딩 유일성을 불변식으로 못 박았다 (선재 갭 C).**
  N1a의 코퍼스는 「payload에서 §6을 뺀 나머지」이고 N1b의 코퍼스는 「payload §6」이다 —
  **둘은 서로의 여집합이라 §6 경계가 유일할 때만 정의된다.** 게이트는 그 유일성을 한
  번도 단언하지 않았고, 그래서 두 검사는 「첫 번째 §6 헤딩」을 골라야 했다. 그 선택이
  곧 **저자가 옮길 수 있는 경계**였다. 실측 셋(전부 `9698670`에서 rc 0) — ① §4 꼬리에
  펜스 **없는** 두 번째 `## 6. 사용자 원문` + 그 아래 URL → 통과 · ② 같은 줄을
  **frontmatter 안**에 → v0.44.0이 닫은 frontmatter 인라인-주석 통로가 그대로 다시 열림 ·
  ③ **audit**에 펜스 안 가짜 `## 6.`을 진짜 앞에 두면 `build_brief_bundle.py`가 펜스를
  무시하고 첫 헤딩부터를 원문 블록으로 실어, 충실도 리뷰어가 받는 ground truth가
  **위조본으로 통째 교체**된다(진짜 `S2`+는 아예 도달하지 않는다). ③은 PR이 적은 두
  선재 갭 어느 쪽도 아니다.
  **「첫 번째를 고르는 규칙」을 고치는 방향으로는 닫히지 않는다 — 고르는 행위 자체가
  구멍이다.** 유일성 위반을 red로 내고, 경계가 비유일하면 N1a는 **한 글자도 빼지 않는다**
  (fail-closed 두 번째 방벽 — N1c를 지워도 ①·②가 다시 열리지 않는다). 유일성은 §6을
  실제로 잘라 쓰는 **가장 관대한 소비자**의 매처(`^##\s*6\.`, 펜스 무시 —
  `check_verbatim_coverage.py:parse_section6`)로 판정한다. 좁은 매처로 물으면 「이 문서의
  §6은 하나다」가 참인 채로 다른 소비자는 다른 절을 §6으로 읽는 상태가 통과한다.
  경계가 비유일하면 N1b·bijection C는 묻지 않는다 — 그 상태의 앵커 집합은 공집합이라
  「앵커가 없다」는 **원인과 어긋난 red**가 되고, 저자를 엉뚱한 수정으로 보낸다.
- **N1b의 코퍼스를 `_body()`에서 payload 원문 §6 span으로 옮겼다 (선재 갭 D).**
  `_body()`는 펜스를 벗기므로 payload §6 **안**의 펜스에 `- **S5**`를 적으면 앵커 집합이
  `{"S1"}`으로 계산돼 등식이 만족됐는데(실측 rc 0), 그 줄은 payload에 그대로 남아 번들에
  실려 충실도 리뷰어에게 **원문으로** 나갔다. C와 같은 결함 계열이다 — 검사의 코퍼스가
  하류로 출하되는 텍스트를 조용히 제외한다. N1a와 N1b는 이제
  `payload_section6_span()`이 **원문 위에서** 잡은 **하나의** 경계를 공유한다. audit 쪽
  앵커(`verbatim_anchors`, bijection C의 우변)는 그대로 `_body()` 코퍼스를 쓴다 — 그쪽은
  존재 검사이고 이 릴리스의 갭이 아니다. 두 함수의 docstring이 어느 쪽이 무엇인지 적는다.
- **`_body()` docstring의 거짓 문장을 사실로 교정했다 (갭 B).** *"부재 검사(N1a)는 이
  코퍼스를 쓰면 안 된다"*는 N1b에 대해 거짓이었다 — N1b가 정확히 그 코퍼스를 쓰고 있었다.
  위 D 수정이 그 상태를 끝냈으므로, docstring은 **지금 사실인 것**을 적는다: 「payload
  §6을 경계로 쓰는 검사(N1a·N1b)는 이 코퍼스를 쓰지 않는다」. 산문은 틀려도 소리를
  안 내므로 `ast` 호출그래프 락으로 집행한다(아래).
- **충실도 축의 `omission` 정의가 락 밖이었다 (갭 A).** F14의 코퍼스는 「ground truth를
  말하면서 표지를 하나라도 대는 문단」이라 **피검자가 스스로 빠져나갈 수 있었다** —
  `omission` 불릿을 「`<<<AUDIT-VERBATIM>>>` 블록에서 빠진 것」으로 되돌리면 그 문단은
  *ground truth*라는 어구를 잃어 후보에서 탈락하고 스위트는 90/90 초록을 유지한다(실측).
  출하된 dogfood payload에 `evidence: S1` 항목이 4건이라 가정이 아니다.

### Added

- **`test_check_brief.sh` — N1c 락(축 4값 × 양성 짝 8케이스).** 축은 「두 번째 §6 헤딩이
  **어디에** 놓이는가」다: frontmatter · §4 꼬리(펜스 밖) · 펜스 안 · audit 파일. 값 하나만
  잡으면 락이 그 자리에만 이빨을 갖는다 — v0.44.0이 «펜스 안»만 닫고 «펜스 밖»을 열어 둔
  것이 정확히 그 실패였다. 각 값마다 **중화판**(주입한 줄에서 `##`만 없앤 판본)이 green임을
  함께 단언한다 — 그래야 red의 원인이 그 헤딩임이 증명된다. 케이스 생성기 rc + 행 수
  **리터럴 8**로 「추출기가 죽어 단언이 조용히 사라지는」 실패형을 막는다. fail-closed
  폴백은 유닛으로 직접 단언한다(비유일 → 코퍼스 == 전문 · 유일 → 코퍼스 < 전문, 양성 짝).
- **`test_check_brief.sh` — N1b 락(펜스 안/밖 두 표기 + 양성 짝).** 같은 `S5` 앵커가 펜스
  안이든 밖이든 같은 판정이어야 한다. 양성 짝은 **앵커 줄만 뺀 같은 펜스**가 green임을
  단언한다 — red의 원인이 「펜스가 있다」가 아니라 「§6이 `S1` 아닌 앵커를 준다」임을 가른다.
- **`test_check_brief.sh` — 코퍼스 분리의 기계 집행(`ast` 호출그래프).** N1a·N1b 두 루트에서
  `_body`/`_section_text`로 가는 경로가 없음을 단언한다. 셸 본문 추출기는 조용히 깨지므로
  `ast.parse`로 판다. **양성 대조가 핵심이다** — 같은 분석기가 `_body()`를 실제로 쓰는
  `landscape_unkeyed`에서는 HIT을 내야 한다(안 그러면 「금지 호출을 못 찾았다」와 「분석기가
  아무것도 안 봤다」가 구별되지 않는다). 두 루트가 `payload_section6_span`을 실제로
  경유하는지도 함께 단언한다. 행 수 리터럴 5.
- **`test_brief_agents.sh` — F15 락(축 정의 불릿).** 대상을 문면이 아니라 **구조**에서
  도출한다: 여섯 축 정의 불릿을 `- \`<name>\` —` 경계로 잘라 내고, ① 어느 축 정의도 비신뢰
  원문 두 위치 중 **한쪽만** 이름으로 대지 않는다(∀) · ② `omission`은 자기 코퍼스를
  **말해야 한다** — 두 표지를 다 열거하거나, 위 문단이 두 위치로 정의한 *ground truth*라는
  용어에 위임하거나. 다른 다섯 축은 `S<N>` 앵커를 따라가므로 위치와 무관하지만, omission은
  「무엇이 빠졌나」라 코퍼스 **전체**를 훑어야 답이 나온다 — 범위를 안 말하면 한쪽만 읽고
  「빠진 것 없음」이 나온다. 불릿 이름 집합은 셸이 리터럴로 대조하고(기대값을 피검자와 같은
  층에 두지 않는다), 행 수 리터럴 2로 추출기 사망을 가른다.

### Known gaps

- **G — `landscape_unkeyed`(#13)의 펜스 코퍼스 구멍.** 이 릴리스가 찾았고 닫지 않았다.
  §4 항목을 펜스 안에 적으면 «출처키» ∀ 를 통과하는데 그 주장은 payload 에 실려 나간다.
  재현·판단 근거는 `0.47.0` 의 Known gaps 에 적었다(거기서도 열려 있다).
- **§6 경계의 «종결» 좌표는 이 릴리스에서 못 박히지 않았다.** N1c 는 시작 좌표만 봤고,
  audit §6 안의 **펜스로 감싼** `## 7.` 로 같은 공격이 그대로 들어왔다 — `0.47.0` 이 닫았다.
- **게이트가 축복한 audit 과 번들이 싣는 audit 을 묶는 것이 없었다** — `0.47.0` 이 닫았다.
- **codex co-reviewer 사용 불가(한도 소진).** 이 릴리스의 모든 판단이 단일 모델 계열이다.

## [0.45.0] — 2026-08-31

### Added

- **`build_brief_bundle.py` 신설 — 충실도 축 두 리뷰어가 공유하는 번들 (payload + audit
  §6).** 앞선 두 단위가 사용자 원문·외부 URL을 payload에서 audit 사이드카로 옮기면서,
  §2 요약이 §6 원문을 왜곡했는지 판정하는 충실도 리뷰어들이 payload만 읽어서는 대조할
  원본을 잃었다 — 원문 없이 왜곡을 물으면 "왜곡 없음"이 공허하게 나온다. 이 스크립트가
  그 원문을 되돌려준다. 형제 `build_seed_inline_blob.py`의 구조(명시 경로 → 라벨 붙은
  조립 → stdout)를 이식했지만, 실패 정책은 반대다 — 형제는 원문 절이 없으면 stderr
  경고 후 그대로 조립하고(fail-open), 여기서는 exit 2·무출력·무디스패치다.
- **라벨은 마크다운 헤딩이 아니다 — `<<<PAYLOAD>>>` / `<<<AUDIT-VERBATIM>>>`.** payload의
  `## 6. 사용자 원문`과 audit의 동명 절을 그냥 이어 붙이면 "§6을 보라"는 하류 지시가
  먼저 나오는 payload 쪽(원문 한 항목뿐)에 걸린다 — 이 태스크가 막으려는 공허 리뷰가
  수정 안에서 재발하는 경우다. audit 쪽 절 헤딩은 실을 때 벗긴다(안 벗기면 payload의
  헤딩과 바이트 동일해 라벨을 붙여도 소용없다).
  audit 경로는 인자로만 받는다(유추 금지) — 게이트의 `resolve_audit()`이 stem을
  유도하는 것과는 층이 다르다(그건 찾기가 아니라 payload의 자기-선언 audit을 못
  바꾸게 하는 거절이다).
- **rc 표.** `0` 정상 dispatch · `2` payload/audit 부재·읽기 실패·audit §6 없음(전부
  무디스패치, 무출력) · `3` 위생 미달(번들 payload 부분에 `.audit.md` 문자열 잔존 —
  degrade 기록 후 dispatch). 위생 스캔은 **payload 부분에만** 건다 — 번들이 audit
  내용을 의도적으로 싣게 됐으므로 전체를 스캔하면 정상 동작이 매번 exit 3을 낸다.
- **`test_brief_bundle.sh` 신설 (T1–T8).** 라벨 존재(T2/T3)와 실린 내용(T5)을 분리해
  검사한다 — 라벨만 있고 원문이 비어도 통과하는 락은 이 실패를 못 잡는다. T4는
  `## 6. 사용자 원문` 헤딩이 번들에 최대 1개임을 세어 확인(동명 헤딩 충돌 재발 방지).
- **번들이 리뷰 층에 배선됐다 (task-10) — 세 축이 셋으로 갈린다.** `reviewing-brief`
  SKILL의 critic dispatch(2-a)와 fidelity codex 호출 두 곳(2-b 최초 · 2-c 재실행)이
  이제 `build_brief_bundle.py`가 만든 번들(payload + audit §6 전량)을 받는다 — direction
  축(1-c)과 readback(3-a)은 `$PAYLOAD` 그대로 유지한다(direction은 도구로 스스로 audit을
  열 수 있고, readback은 하류가 실제로 받는 문서의 읽힘을 재야 하므로 번들을 주면 안
  된다). 번들은 세션 디렉토리에 **한 번만** 조립해 critic(문자열 보간)과 codex 러너(파일
  경로)가 같은 바이트를 나눠 갖는다.
- **`brief-codex-fidelity-checklist.md`·`agents/brief-critic.md`가 라벨 토큰을 가리킨다.**
  두 파일이 헤딩 리터럴 `§6 사용자 원문`을 ground truth로 지목하던 것을 `<<<AUDIT-VERBATIM>>>`
  다음 블록으로 바꿨다 — 번들에 audit §6을 실어도 지시문이 여전히 payload의 `S1` 하나만
  가리키면 codex·critic이 원문 전량을 못 보고 판정한다.
- **`build_brief_codex_prompt.py`의 비신뢰-verbatim 경계 문장이 두 축을 함께 덮는다.**
  direction 축은 payload(`## 6. 사용자 원문`)를, fidelity 축은 번들(`<<<AUDIT-VERBATIM>>>`)을
  받으므로 한쪽 위치만 가리키면 다른 축에서 injection 경계 표시가 사라진다.
  `merge_brief_review.py`·`test_merge_brief_review.py`의 같은 취지 주석도 주입 표면이
  "payload §6의 `S1` 1건"에서 "번들의 audit §6 전량"으로 늘어난 사실을 반영해 갱신했다.
- **`build_brief_inline_blob.py`가 readback 전용으로 재서술됐다.** docstring의 "충실도
  판정은 body §2 ↔ §6 대조"는 번들 도입 이후 거짓이다 — 이 blob의 유일한 소비자는 이제
  냉독이다. `tests/test_brief_inline_blob.sh`의 T24(§6 원문·헤딩 보존)는 변경 없이 GREEN을
  유지한다(축 분리의 양성 대조).
- **G6 gap 클래스 추가 (Law 3 compounding).** 냉독 3-b의 다섯 클래스에 *"상태 표기와 본문
  서술의 불일치"*를 더했다 — 이 설계의 리뷰 8라운드에서 반복 관측됐다. 성공 조건도
  `G1–G5 전부 0건`에서 `G1–G6 전부 0건`으로 함께 고쳤다(안 고치면 새 클래스가 관측돼도
  아무것도 안 막는다).
- **`test_reviewing_brief_skill.sh`에 U4 계약 락 4건 추가.** fidelity codex 호출 개수와
  번들 인자 개수의 등식(하나라도 payload면 fail-open 재발) · 냉독의 payload-only 유지
  (반대 방향 양성 짝) · 체크리스트·critic 정의의 라벨 토큰 참조 · G6의 성공 조건 포함.
  기존 T8·BLOB(2-a/3-a) 락도 2-a가 이제 `build_brief_bundle.py`를 호출하는 사실에 맞춰
  갱신했다(BLOB 루프는 섹션별로 다른 빌더 호출 패턴을 요구하도록 분기했다 — 한 정규식으로
  두 섹션을 함께 검사하면 한쪽 빌더 호출이 사라져도 다른 쪽 매치로 조용히 통과한다).
- **`references/compression.md`의 예약 해소 (task-12) — brief도 이 계약을 게이트로
  집행한다.** U1–U5(이 릴리스)가 실제로 landing시킨 것을 정본이 뒤늦게 인정한다:
  payload 외부 URL 금지(N1a) · §6은 `S1`만(N1b) · landscape 원자료는 audit 결속(N2).
  집행 지점만 seed(`check_seed.py`)와 brief(`check_brief.py`)가 다르다. 절 구조 분기
  (seed는 메시지형·brief는 문서형)와 "원문·근거·전량을 payload에 요구하지 않는다"는
  불변은 그대로 둔다 — 바뀌는 것은 어느 쪽이 게이트로 강제받는가뿐이다.
- **`test_compression_adopters.sh`의 채택자 도출이 `conducting-interview`로 확장.**
  `references/finishing.md`에 압축 규약 포인터 + 확산-후-압축 어휘를 추가해
  `conducting-interview`도 도출 대상(2개)이 됐다 — 채택자 도출은 열거가 아니라 정본
  포인터에서 나오므로, 추가하지 않으면 정본의 새 문구("brief도 집행한다")와 락이 실제로
  재는 집합이 어긋난다. guards 선언에 `plugins/spec-distill/skills/*/references/*.md`를
  되돌리고(fix round 1이 예고한 대로), "오늘 집행 대상은 seed 하나뿐"이라던 주석의
  stale 주장을 갱신했다.
  **fix round 3 (코디네이터 오버룰) — 하한을 1에서 2로 올렸다.** 실측: `finishing.md`의
  포인터+어휘 문장 두 줄을 지우면 도출이 2→1이 되는데, 하한 1에서는 그래도 통과했다
  (rc=0, silently green) — brief가 채택자 집합에서 조용히 빠져도 이 락은 몰랐다. 정본의
  새 heading("seed와 brief 둘 다 게이트로 집행한다")이 세우는 대칭 주장을 하한 1은
  지키지 못하므로, 형제 락(`test_proceed_gate_adopters.sh`)과 같은 근거로 하한을 2로
  맞췄다. 대안(리터럴 EXPECTED 튜플을 박고 `test_brief_agents.sh` F3처럼 missing/extra
  양방향 대조)은 검토 후 채택하지 않았다 — "extra"도 실패시키면 정당한 셋째 채택자가
  생길 때마다 이 테스트를 손으로 고쳐야 하는 열거 락이 되어, 이 파일 자신이 선언하는
  "열거가 아니라 도출" 원칙과 충돌한다. 잔여 위험(구성원 치환 — 하나가 빠지고 무관한
  셋째가 우연히 채워지면 개수 2는 그대로라 하한이 못 잡는다)은 주석에 명시적으로
  남겼다 — 형제 락은 같은 간극을 "정본이 이름을 대는 skill을 합집합으로 더하는" 방식으로
  닫았지만, `compression.md`는 skill 디렉터리 이름을 한 번도 쓰지 않는 문서라 이번
  fix round 범위로 그 편집을 옮기지 않았다.

### Fixed

- **`build_brief_bundle.py`의 setext heading 충돌 (task-9 재리뷰 결함).** `assemble()`이
  라벨 다음 줄에 payload의 frontmatter `---`를 바로 이어 붙였다 — CommonMark는 단락 바로
  다음 줄이 전부 `-`(또는 `=`)면 그 단락을 setext heading으로 승격시키므로, 모든 호출에서
  `<<<PAYLOAD>>>` 라벨이 `<h2>`가 되어 `## 6. 사용자 원문`과 같은 헤딩 네임스페이스에
  들어갔다 — 이 파일이 막으려던 헤딩 충돌이 라벨 도입 자체로 재발하는 경로였다. 각 라벨
  다음에 빈 줄을 둬서 고쳤다. `test_brief_bundle.sh`에 T13/T14를 추가해 라벨 **다음 줄**이
  setext underline이 아님을 잠근다 — T10/T11은 라벨 자기 줄만 보고 구조적으로 이 결함을
  못 본다.

**(task-10 fix round 1, F2)** 위 문단이 "known gap"으로 적어둔 것은 오판이었다 —
`n_bundle == n_fid`(codex 호출이 `"$BUNDLE"`을 인자로 받는지)와는 다른 축의 락이 실제로
가능했다: 조립 호출 자체를 실행-라인 앵커로 세면 된다(`grep -cE '^[[:space:]]*python3
"\$PR/scripts/build_brief_bundle\.py"'`, 이 파일이 이미 `n_bundle`/`n_fid`에 쓰는 것과
같은 관용구). `test_reviewing_brief_skill.sh`에 **F2** 락을 추가했다 — 스코프는 전체
파일이 아니라 **2-a~2-b 구간**(2-c 헤더 직전에서 끊는다): 2-c의 fresh critic 재dispatch는
오늘 "2-a 블록 그대로"라는 참조뿐이라 리터럴 조립 호출이 파일 전체에 1개뿐이지만, 그
참조를 나중에 명시적 리터럴 재조립으로 펼쳐 쓰는 것은 정당한 설계 변경이다(수정된
payload/audit에서 다시 조립해야 하므로) — 전체-파일 `== 1`은 그 정당한 변경에 거짓 RED를
낸다. 2-a~2-b 구간 안에서는 "같은 라운드의 critic·codex #1가 같은 바이트를 본다"는
불변식이 항상 참이어야 하므로 그 구간에 대해서만 `== 1`을 무조건 강제한다. 위에서
재현한 mutation(2-b에 재조립 호출 삽입)으로 이 락이 RED(count 2)를 내는 것을 실측
확인했다.

**(최종 whole-branch 리뷰 fix, I3)** `test_brief_agents.sh`의 **F3** 락이 **대상이
개명되면 공허하게 초록**이었다. `build_brief_bundle.py`의 `UNTRUSTED_VERBATIM_MARKERS`를
다른 이름으로 바꾸면(정의 + 유일 사용처, 2 insertions / 2 deletions) 임베디드 python이
`AttributeError`로 죽고 트레이스백은 stderr로 가 `$F3_REPORT`가 빈 문자열이 된다. 그러면
`^MISSING`·`^EXTRA`·`^NO_BOUNDARY_PARAGRAPH` 세 grep이 전부 「없어야 할 것이 없다」로
통과하고, `COVERED` 행을 순회하는 while 루프는 한 번도 돌지 않아 단언 2개가 **조용히
사라진다** — 스위트는 rc 0·77/77(기준선 79/79)을 냈다. 남은 세 줄은 존재하지 않는 상수에
대해 *"계약이 필수 2곳을 전부 포함한다"*고 **적극적으로 성공을 주장**하고 있었다. 형제 락
T12(`test_brief_bundle.sh`의 `n_pairs -eq 3`)가 같은 함정을 이미 행 수 리터럴로 막고
있었고 F3는 그 관용구를 베끼면서 이 가드만 빠뜨렸다. 추출기 rc를 붙잡고 커버리지 행 수를
**리터럴 2**로 못 박았다(`len(EXPECTED)`로 유도하면 빈 튜플 변형에서 `0 == 0`으로 다시
공허해진다). 실측: 개명 mutation → exit 1, 복원 → exit 0.

**(최종 whole-branch 리뷰 fix, I1)** **N1a의 코퍼스가 설계 §2.3보다 좁았고, 외부 URL이
열거되지 않은 문 둘로 빠져나갔다.** `_body_excluding_section6()`이 `_body()` 위에 얹혀
있어 실제 코퍼스는 「payload − §6」이 아니라 「payload − §6 − frontmatter − 펜스」였다.
실측 — payload §4의 ```펜스``` 안 `https://` 2건이 `{"pass": true}` rc 0이고 펜스 두 줄만
지우면 `payload에 외부 URL 2건` rc 1 · frontmatter `statement:` 뒤 인라인 주석의 URL도
같은 방식으로 통과. 둘 다 하류로 나가는 문서에 **축자로 살아남는다** — N1a가 막으려는
바로 그 해다. §3.2의 탈출로 표는 **삭제** 3종만 열거했고 이 둘은 표에 없었다. `_body()`는
존재 검사들이 계속 쓰므로 **전역으로 고치지 않고**, N1a 전용 코퍼스
`_payload_excluding_section6()`를 원문 위에 세웠다(두 코퍼스가 공존하는 값은 양쪽
docstring에 어느 쪽이 무엇이고 왜인지를 적어 치른다). §6 경계는 **펜스 밖 헤딩**으로만
찾는다 — 안 그러면 펜스 안 가짜 `## 6. 사용자 원문`이 그 지점부터 다음 `## N.`까지를
코퍼스에서 잘라내, 두 문을 닫으면서 같은 모양의 세 번째 문을 여는 꼴이 된다. 락은
`test_check_brief.sh`의 **U3-T8c**: 세 문 각각 → red + **코퍼스 구성 5행 양성 대조**
(§6 헤딩이 원본에 있다/코퍼스에서 빠졌다/§6 본문 첫 줄이 빠졌다/frontmatter를 담는다/
펜스를 담는다) + 추출기 rc + 행 수 리터럴 5. 부재 술어의 초록은 그 자체로 증거가 아니다 —
「URL을 못 찾았다」와 「아무것도 안 읽었다」를 이 다섯 행이 가른다. 기존 픽스처는 하나도
편집하지 않았다(변형은 TMPD에서 `interview-brief-valid.md`로부터 만든다).

**(최종 whole-branch 리뷰 fix, I2)** **충실도 축이 명시한 ground truth 코퍼스가 `S1`을
빼고 있었다.** `agents/brief-critic.md`의 본문과 frontmatter `description`·
`scripts/brief-codex-fidelity-checklist.md`·`reviewing-brief` SKILL의 2-a dispatch
프롬프트 **넷**이 코퍼스를 `<<<AUDIT-VERBATIM>>>` 다음 블록 **하나**로 지목했는데, `build_brief_bundle.py`는 payload §6(`S1`, 바이트
그대로)을 그 라벨 **앞에** 싣는다. 출하된 dogfood payload만 해도 `evidence:`가 `S1`인
항목이 4건이고 두 템플릿의 예시 항목도 `S1`에 앵커하므로, 그 항목들의 `distortion`·
`evidence_unsupported` 판정이 「대조할 원문이 코퍼스 밖」인 채로 났다. 비대칭이 신호였다 —
F3는 *비신뢰 경계* 문장에 두 위치를 강제하는데 *ground truth* 문장에는 아무 강제가 없었다.
네 자리를 두 위치를 함께 이름으로 대도록 고치고(체크리스트의 `omission`·
`evidence_unsupported` 정의에 박혀 있던 한 위치 고정도 함께 풀었다), **F14** 락을
`test_brief_agents.sh`에 추가했다 — F3와 같은 산출자 상수에서 파생한다. 술어는 **∀**다:
*위치를 하나라도 이름으로 대는* ground-truth 문단은 두 곳을 전부 대야 한다(∃로 두면 같은
파일의 다른 문단이 정작 깨진 문장을 대신 만족시킨다). 후보 0은 red라 `all([])`의 공허
참이 막힌다. 산문 앵커로 잡히지 않는 두 자리는 **구조로** 잘라낸다 — 2-a dispatch는
`subagent_type` 리터럴을 감싸는 `Agent({ … })` 호출로, frontmatter `description`은 `---`
구분자로(이 자리는 'ground truth'라는 어구를 지우기만 하면 산문 앵커 밖으로 빠져나갔다 —
실측으로 확인하고 네 번째 자리로 승격했다). 행 수는 리터럴 8(4 자리 × 2 위치). 실측: 네
자리 각각을 한 위치로 되돌리는 mutation 4종 + dispatch 앵커 개명 + 산출자 상수 개명, 전부
exit 1.

**(최종 whole-branch 리뷰 fix, M1)** **G6가 `SKILL.md` 안에서만 살았다.**
`templates/interview-audit-template.md`의 냉독 행은 `<G1..G5 중 어느 클래스>`,
`README.md`는 두 자리 다 `G1–G5` — G6 관측을 적을 칸이 출하 템플릿에 없으면 그 클래스는
실무에서 존재하지 않는 것과 같다. 세 파일을 맞추고, `test_reviewing_brief_skill.sh`에
**M1** 락을 더했다: 상한 값을 세 파일에서 각각 읽고 **셋이 같다**는 관계를 단언한다
(기대값을 피검자에서 끌어오지 않는다). 관계만 두면 셋이 함께 사라질 때 공허해지므로 표에서
도출한 상한의 하한 6과 파일당 범위 표기 ≥1을 함께 못 박았다. README의 bare `G6`(리뷰
dispatch 상한 — 다른 네임스페이스)와 섞이지 않도록 **범위 표기**만 센다.

**(최종 whole-branch 리뷰 fix, M2)** `templates/interview-brief-template.md`의 §2 헤더
주석이 *"원문은 §6"*, frontmatter 주석이 *"§6의 어느 발화에서 나왔는가"*로 남아 있었다 —
같은 파일 다른 줄이 *"payload §6엔 S1만 산다"*로 이미 옳게 적고 있었으므로 앞선 산문
스윕이 이 두 자리만 놓친 것이다. 원문이 payload §6(`S1`)과 audit §6(`S2` 이상)에 나뉜다는
사실로 고쳤다.

**(최종 whole-branch 리뷰 fix, M3)** `test_check_brief.sh`의 **T17 앞 절반**을 걷어냈다 —
web 비활성이 §4/§5의 URL 요구를 완화하는지 재던 단언인데, v0.44.0이 그 요구를 지운 뒤로
**web ON에서도 그대로 green**이라 kill switch에 대해 아무것도 재지 않았다. 지운 자리에
그 사실을 적어 둔다(삭제된 규칙이 거짓 인용을 남기지 않도록). ST 참조 요구가 완화되지
않음을 재는 뒷 절반은 살아 있으므로 그대로 둔다.

### Known gaps

**PR #136이 표로 적은 갭 A–D 넷은 `0.46.0`에서 닫혔다** — A·B는 이 브랜치의 것이고,
C·D는 **이 브랜치 이전부터 열려 있던 선재 갭**이다(이 브랜치가 닫은 것은 같은 계열의
«펜스» 변종 하나였다). 아래 둘은 여전히 열려 있다.

- **dogfood 이관은 브리프 1쌍뿐이다 — `docs/superpowers/interview/`의 나머지 3쌍은
  구 포맷 그대로 남는다(task-11).** 근거: `check_brief.py gate` 호출 지점 셋(SKILL 훅·
  명령·테스트 스위트) 전부가 「방금 쓴 파일」만 대상으로 하고, 옛 brief를 다시 게이트에
  태우는 경로가 리포 안에 없다. **대가** — 누군가 옛 brief 3쌍 중 하나에 `check_brief.py
  gate`를 손으로 걸면 §6 앵커·URL·«키» 축에서 **원인 불명 RED**를 만난다. 이 문단이 그
  판단의 소재다.
- **선재 결함 4건 — 이 릴리스가 만든 것도, 고친 것도 아니다(task-8 스윕, `check_brief.py`).**
  `ST_REF_RE.sub`(statement-length 계산, `skepticism_malformed` 내부, G) · `_strip_bullet()`
  호출(`coverage_ledger_failures`, audit §1 행 파싱, I) · `_entry_lines()`의 맨 `-`/`*`
  단독 줄 제외(J) · 같은 statement-length 계산 안의 `_strip_bullet()` 서브스텝(K, 위
  `ST_REF_RE`와 분리했을 때) 넷 다, 그 결함을 드러낼 fixture가 리포에 없어 **관측
  불가능**하다(무결함이 아니라 무증거) — 스윕 당시 URL/N1a 내용과 무관하다고 판단해
  fixture를 새로 만들지 않았다. **선재·범위 밖** — 이 릴리스가 만든 것도 고친 것도
  아니다. 다음에 이 근방을 건드리는 사람이 "왜 안 고쳤나"를 묻지 않도록 여기 남긴다 —
  이 결정을 낳은 스크래치 워크스페이스가 프로젝트 종료 시 삭제되므로 이 CHANGELOG가
  이 사실이 살아남는 유일한 자리다.

## [0.44.0] — 2026-08-31

### Changed

- **`landscape_uncited` → `landscape_unkeyed`(#13) — §4 술어를 URL 인용에서 «출처키»로
  바꿨다, ∀는 유지.** URL을 요구하는 것과 «출처키»를 요구하는 것은 다른 강도다 — 그대로
  맞바꾸면 인용 없는 §4 항목 여덟 개 + audit에 URL 한 개가 통과해버려 강도가 내려간다.
  그래서 URL이라는 **술어만** audit 쪽(N2)으로 가고, ∀(§4 항목마다 무언가 필수)는
  payload에 그대로 남는다 — 새 정규식 `SOURCE_KEY_RE = re.compile(r"«([^»]+)»")`가
  그 무언가를 정의한다. **web kill switch로 완화하지 않는다** — 웹이 꺼져도 출처를
  말로 댈 수 있고, web-off brief는 §4에 순회할 항목이 없어 공허하게 통과하는 것이
  옳다(조사하지 않았으면 인용할 것도 없다). 그래서 이 함수의 `_web_disabled()` 조기
  반환을 지웠다.
- **N2 신설 — `landscape_keys_declared(payload_text, audit_text)`.** payload §4가 쓴
  «출처키» 집합이 audit `## 7. 확산 원자료`가 선언한 키 집합에 포함되는지를 확인한다.
  **개수가 아니라 집합이다** — 개수 결속은 세 가지로 틀린다: web-off brief(§4 항목
  1건, §7 0건)가 `1 ≤ 0`으로 red · 두 §4 항목이 같은 출처를 인용하면 `2 ≤ 1`로 red ·
  §7을 산문 전문으로 적으면 "항목"의 계수 단위가 미정이라 집행 불가. 집합이면 셋
  다 통과한다. **조건부다** — audit §7 헤딩 자체가 없으면(이미 `missing audit
  sections`가 잡는다) 건너뛴다. payload가 «출처키»를 하나도 안 썼으면 공집합이
  무엇의 부분집합이든 자동 만족되므로 kill switch 코드가 필요 없다. **보장하지
  않는 것**: 어느 키가 어느 원자료를 가리키는지(키를 지어내도 통과한다) — 그 해석까지
  묶는 교차 bijection은 설계 단계에서 검토 후 기각됐다.
- **`AUDIT_SECTIONS`에 `("7", "확산 원자료")`를 뒤에 덧붙였다.**
- **CLI 서브커맨드 개명 — `landscape-citations` → `landscape-keys`, JSON 키
  `"uncited"` → `"unkeyed"`.** 개명은 함수 하나가 아니라 CLI 표면 전체다 — 이 서브
  커맨드를 web 킬 스위치 완화 목록(`main()`의 `sub in (...)` 분기)에서도 뺐다:
  `landscape_unkeyed`가 더 이상 web 상태에 좌우되지 않으므로 완화할 대상이 없다.
  `skepticism`은 아직 §5 verdict의 URL 요구를 갖고 있어(다음 단위가 지운다) 그
  목록에 남긴다. 서브커맨드가 이름은 "citations"인데 실제로는 키를 재는 상태로
  남으면 그 출력을 읽는 쪽을 오도하므로, 남은 옛 이름 참조(테스트 R12의 직접 호출
  포함)를 전수 스윕해 함께 고쳤다.
- **두 템플릿을 갱신했다** — `interview-brief-template.md` §4 설명을 "출처 URL
  필수"에서 "«출처키» 필수"로 바꾸고 예시 항목에 `«example»`을 추가했다(원자료
  URL은 audit §7이 나른다는 설명과 함께). `interview-audit-template.md`에
  `## 7. 확산 원자료` 절을 신설하고 같은 `«example»` 키를 선언해, 출하 템플릿
  쌍이 새 #13·N2 둘 다에서 자기 게이트를 통과하게 했다(T-TPL 락 유지).
- **F13 락을 새 술어로 갱신했다** — 옛 실패 문구 `'uncited landscape'`는 개명으로
  더 이상 나오지 않아 그대로 두면 조용히 GREEN이 된다. grep 문자열을
  `'unkeyed landscape'`로 바꾸고, 픽스처 `interview-brief-star-bullet-uncited.md`의
  `-` 항목에 «키»를 붙여(그리고 audit §7에 그 키를 선언해) #13·N2 둘 다에서
  무결함을 먼저 확정한 뒤, `*` 항목만 무키로 남겨 red 이유를 불릿 비대칭
  하나로 고정했다.
- **픽스처 3건 추가** — `interview-brief-unkeyed-entry`(§4 항목 하나가 무키 → #13
  단독 red), `interview-brief-key-undeclared`(payload가 쓴 키가 audit §7에 없음 →
  N2 단독 red), `interview-brief-dup-key`(두 §4 항목이 같은 키를 쓰고 audit §7엔
  1건만 선언 → GREEN, 집합 포함이 개수 결속이 아님을 증명). 셋 다 `interview-brief-valid`
  쌍에서 파생했고, 각각 정확히 한 축에서만 실패(혹은 통과)하도록 확인했다.
- **N1a 신설 — `payload_url_free(text)`.** payload에서 §6 사용자 원문을 뺀 나머지에
  외부 URL(`https?://`)이 0개인지 본다(부재 술어). §6이 예외인 이유는 편의가 아니다 —
  사용자가 자기 요청에 직접 쓴 URL을 지우는 것은 압축이 아니라 원문 훼손이고, 지우면
  `check_verbatim_coverage.py`의 L2(정규화 후 containment)가 `not_contained`로 exit 1을
  내 게이트가 **동시 만족 불가능**해진다. 이 검사의 이빨은 그 자신 안에 없다 — 대상 절을
  통째로 지우면 공허하게 통과하므로 `find_missing_sections`(§4/§5 헤딩 삭제) ·
  `landscape_present`(§4 항목 전부 삭제) · `tried_discarded_ok`(§5 항목 전부 삭제) 셋이
  삭제 우회로를 막아야 이빨을 갖는다(세 검사 전부 확인 완료). web kill switch로 완화하지
  않는다 — 웹이 꺼져도 payload에 URL을 넣을 이유가 생기지 않는다.
- **payload §4·§5 fixture 일괄 변환 — URL → «출처키», 짝은 audit §7로.** 일회용
  변환기(`.claude/urls-to-keys.py`, 커밋 대상 아님)로 payload 69개의 §4·§5 URL을
  걷어냈다: §4는 기존 키가 없으면 도메인에서 유도한 «키»를 삽입하고 그 짝을 같은
  stem의 audit §7에 append, 기존 키가 있으면 URL만 지우고 키·audit 선언은 그대로
  둔다(멱등, 남의 판단 없이 내용 기반). §5는 URL만 지운다 — §5는 애초에 «키» 요구가
  없고(#13/N2는 §4 전용), `skepticism_malformed`가 URL 제거 후 남는 텍스트를
  statement로 재므로 §5에 키 텍스트를 끼워 넣으면 라벨 없는 줄의 "statement<10c"
  판정을 우연히 반증할 위험이 있다 — 그 위험을 §5 키 삽입 자체를 안 하는 것으로
  구조적으로 없앴다. **순서가 결과를 바꾼다(Ruling F2)**: 일괄 변환을 먼저 하고 나서
  §0(b)의 의도적으로 깨진 픽스처를 그 위에 만들었다 — 거꾸로 하면 일괄 변환이
  `url-in-sec4` 픽스처의 URL까지 지워 N1a 첫 단언이 거짓 GREEN이 된다.
- **변환에서 손대지 않은 두 픽스처 — 리즈닝으로 찾음, 목록을 베끼지 않음.**
  (1) `interview-brief-unkeyed-entry.md`는 §4 항목 하나가 무키임을 시험하는 유일한
  픽스처다(U3-T7) — 일괄 변환이 순진하게 «키»를 붙이면 이 assertion이 거짓 GREEN이
  된다는 것을 실행으로 확인한 뒤, 그 파일만 URL을 지우되 키는 붙이지 않고 audit §7
  선언도 원복했다(N1a는 만족, #13은 여전히 red). (2) `interview-brief-web-disabled.md`는
  URL이 원래 하나도 없어 변환기가 자연히 no-op이지만, "여기에 «키»를 손으로 붙여
  AC8을 고치자"는 유혹이 F8("web 켜짐에서 무키 §4 항목은 red")을 거짓 GREEN으로
  만든다는 것을 실행으로 확인했다 — v0.44.0 이후 이 두 락(F8·AC8)은 같은 파일로
  동시에 만족될 수 없는 서로 다른 조건이 됐으므로(#13이 web 무관 ∀가 됐고 skepticism의
  URL 요구도 없어져, 이 파일의 gate() 결과가 web 상태와 완전히 무관해졌다), AC8을
  이 파일이 아니라 실제로 남은 유일한 완화 지점(sentinel-only.md, #12)으로 재배선해
  둘을 함께 지켰다.
- **`landscape_present`(#12) sentinel 경로를 `_web_disabled()`로 좁혔다.** v0.44.0
  이전까지는 §4 본문에 "생략" 한 단어만 있어도 True였고 URL 요구가 그것을 덮어
  무해했다 — N1a 체제에서는 이것이 **N1a의 공허 우회로를 여는 유일한 문**이 된다(§4에
  "생략"만 쓰면 URL도 «키»도 없는 payload가 통과한다). 이제 web이 실제로 꺼져 있을
  때만 sentinel이 유효하고, 켜져 있으면 항목 없음과 동일하게 취급한다. **내구성
  대가**: 이 함수가 처음으로 환경변수에 의존한다 — web-off로 저술된 brief가 다른
  세션에서 그 변수 없이 재게이트되면 RED가 된다. 그래서 audit 템플릿 `## 4. 게이트
  실행 기록`에 `web: <enabled|disabled>` 칸을 추가해, 저술 시점의 환경을 아티팩트가
  나르게 했다.
- **`skepticism_malformed`(§5)에서 URL 요구를 지웠다.** `require_url`·`has_url`·
  `no-url` 세 갈래를 제거 — payload 외부 URL은 이제 N1a가 §6 예외 하나만 두고 전면
  금지하므로, 이 함수가 §5 항목에서 URL 유무를 스스로 요구/거부할 이유가 없다.
  `verdict:`·statement·ST 참조 요구는 그대로 남는다. URL을 먼저 벗겨낸 뒤 ST<N>을
  찾는 방어(`ln_no_url`)도 남긴다 — URL 요구와 무관하게, 우연히 낀 phantom ST 참조를
  막는 별개의 defense다. **양성 대조**: §5 verdict 항목에서 URL을 빼면 GREEN이지만
  같은 줄에서 `verdict:` 절까지 빼면(그 줄이 더 이상 verdict 항목으로 안 보여
  audit §3의 ST 선언이 orphan이 된다) bijection A가 여전히 RED를 낸다 — 두 assertion을
  짝으로 뒀다(T11/no-url).
- **`WEB_DISABLED_ADVISORY` 문면을 실제 완화 범위로 재작성했다.** 이전 문면은
  "§4 출처 URL 인용 요구 + §5 verdict URL 요구가 완화됨"이라 적었는데, 이 커밋 이후
  그 둘 다 존재하지 않는다(§4는 키 요구로 바뀌어 완화되지 않고, §5 URL 요구는
  방금 지웠다). 완화되는 것은 `landscape_present`(#12)의 sentinel 경로 **하나**뿐이라고
  정확히 적었다. `main()`의 서브커맨드별 kill-switch advisory 분기(`skepticism` 전용)도
  지웠다 — 이제 kill switch로 완화되는 단독 서브커맨드가 하나도 없다(유일한 완화
  지점은 `gate()` 내부에만 있다). **양성/음성 대조 락**: `landscape_present`만
  `_web_disabled()`를 부르고 `landscape_unkeyed`·`skepticism_malformed`·
  `payload_url_free`는 부르지 않는다는 것을 함수 본문 도려내기로 확인한다(개수가
  아니라 함수별 호출 지점 — advisory *배출*과 실제 *완화*를 혼동하지 않는다).
- **fixture 6건 추가(U3-T8)** — `interview-brief-url-in-sec4`(§4에 키+URL 동시 →
  N1a 단독 red), `interview-brief-url-in-s1` + `.audit.md` + `state-url-in-s1`(§6 S1
  안의 URL → GREEN, 같은 URL을 §4로 옮기면 RED — N1a §6 예외와 L2 동시 만족 확인),
  `interview-brief-no-sec4`/`sec4-header-only`/`sec5-no-entries`(N1a의 세 삭제
  우회로 각각 단독 red), `interview-brief-sentinel-only`(§4 "생략" 한 단어만 —
  web ON red / web OFF green).

## [0.43.0] — 2026-08-31

### Changed

- **`AUDIT_SECTIONS`에 `("6", "사용자 원문")`을 뒤에 덧붙였다** — audit 사이드카가 이제
  6절 계약이다. 게이트가 audit §6 헤딩 부재를 `missing audit sections`로 red 처리한다.
- **`attribution_block_missing`의 검사 대상이 payload §6에서 audit §6으로 이사했다** —
  brief 재구조화(§7.1)의 첫 단계로, `S1`을 제외한 사용자 원문 전량이 audit으로 옮겨가는
  하류 작업(별도 Task)의 선행 조건이다. 시그니처는 여전히 `(str) -> bool`이지만 인자
  이름을 `audit_text`로 바꿔 의미 변화를 드러냈다. `gate()`의 검사 배선도 payload 텍스트
  블록에서 audit 텍스트 블록(`amiss` 계산 다음, `pair` 검사 뒤)으로 옮기고, audit §6이
  통째로 없는 경우(#9가 이미 그 red를 낸 경우)와 중복 보고되지 않도록
  `audit_sec6_absent` 가드를 추가했다.
- **두 템플릿을 갱신했다** — `interview-audit-template.md`에 `## 6. 사용자 원문`
  절(append-only, `S1` 제외 전량, 출처 표기 블록 포함)을 §5 뒤에 추가했고,
  `interview-brief-template.md` §6은 `S1` 최초 요청 하나만 남기고 출처 표기 블록을
  지웠다(그 검사가 audit으로 이사했으므로). payload §6이 `S1`만 남으면서 예시
  `user_sourced_items`의 `D2.evidence`가 더 이상 payload §6에서 해석되지 않는
  `S2`를 참조하고 있었다(bijection C) — 출하 템플릿 자체가 자기 게이트에 걸리는
  것을 막기 위해 예시 `D2`의 evidence를 `S1`로 바꿨다(payload §6에 실재하는 유일한
  앵커). `S2` 이상 원문을 근거로 삼는 실제 제약의 bijection C 재해석(양쪽 파일의
  합집합 대조)은 하류 Task가 맡는다.
- **N1b 신설 — `payload_verbatim_is_s1_only()`가 payload §6 앵커 집합이 정확히
  `{"S1"}`인지 등식으로 확인한다.** `⊆`가 아니라 `==`다 — `⊆`로 쓰면 빈 §6이
  통과하는데, `user_sourced_items`가 0건인 payload에서는 bijection C의 순회 자체가
  비어 그 구멍을 대신 막아주지 못한다(등식 술어가 스스로 양성인 이유). `gate()`는
  `sec6_absent` 가드 아래 이 검사를 새로 배선했다.
- **`bijection_c_errors()`가 2인자(`payload_text, audit_text`)로 바뀌었다** — 앵커
  집합이 이제 payload §6 ∪ audit §6이다(`S1`은 payload에, `S2` 이상은 audit에 살므로
  한쪽만 보면 반대쪽 인용 전량이 dangling으로 오탐된다). 단방향은 유지 — 인용된
  `evidence: S<N>`의 존재만 확인하고 역방향(모든 앵커가 인용될 것)은 요구하지 않는다.
  `gate()`의 호출 자리를 audit 해석 블록 안(`pair` 검사 뒤)으로 옮겨 audit 텍스트를
  받을 수 있게 했고, `items` 서브커맨드(`main()`)도 같은 시그니처 변경의 소비자라
  `gate()`와 같은 방식(`resolve_audit` → 실패 시 판정-불가 문구, 성공 시 두 텍스트로
  호출)으로 함께 고쳤다 — 안 그러면 옛 1인자 호출이 `TypeError`로 죽는다.
- **픽스처 4쌍 추가** — `interview-brief-payload-s2`(N1b 위쪽: payload §6에 `S2`가
  남아있으면 red), `interview-brief-payload-empty-sec6`(N1b 아래쪽: 빈 §6도 red),
  `interview-brief-zero-items`(`user_sourced_items: []` + §2 항목 불릿 제거 +
  frontmatter AC12 sentinel 보존 — bijection C가 공허해지는 유일한 상태에서 N1b가
  단독 방어선임을 확인), `interview-brief-audit-drop-s5`(payload에 `evidence: S5`
  항목을 추가하고 audit §6에는 `S2`만 실어 `S5`를 dangling으로 남김 — 합집합 해석의
  audit 쪽이 실제로 읽힘을 확인). 넷 다 hand-add한 audit §6(헤딩 + 출처 표기 블록)을
  가진다 — 그렇지 않으면 전부 `missing audit sections`로만 red가 나 자신이 시험하려는
  축을 재지 못한다.
- **부수 수정: `interview-brief-payload-attr-missing.md`에서 payload §6의 `S2` 항목을
  뺐다(`S1`만 남김).** 이 fixture는 U2-T2(payload attribution 무관 확인)가 `rc==0`을
  요구하는데, valid.md에서 파생된 payload §6이 원래 `{S1, S2}`를 그대로 갖고 있어
  N1b 신설과 충돌해 `rc==0` 단언이 회귀했다(`git diff` 전/후로 확인). audit
  사이드카가 이미 `S2`를 §6에 갖고 있어 `D2.evidence: S2`는 union으로 계속 해석된다
  — attribution 무관성이라는 이 fixture의 원래 취지는 그대로다.

- **`check_verbatim_coverage.py`가 3인자(`<payload> <state.local.md> <audit>`)로
  바뀌었다** — `parse_payload_section6`을 `parse_section6(text, label)`로 개명해
  payload·audit 양쪽에서 재사용하고, `parse_section6_union()`을 신설해 `S1`(payload)
  ∪ `S2` 이상(audit)을 대조 코퍼스로 합친다. 한쪽 §6이 없으면 조용한 코퍼스 축소가
  아니라 그대로 `ParseError`(호출자가 exit 3으로 매핑)를 낸다 — 부분 코퍼스로
  "완전성 통과"를 내지 않는다. 같은 앵커가 payload·audit 양쪽에 있으면
  append-only 위반(exit 1)이다 — 오늘 payload 내부 중복이 구조 위반인 것과 같은
  이유이며, 집행이 이제 합집합 위에서 돈다. audit 경로는 **호출자가 명시**한다 —
  `check_brief.py`의 `resolve_audit()`처럼 payload 파일명에서 유도하지 않는다(그
  유도는 남의 audit 채택을 거절하는 목적이고, 여기는 반대로 무엇을 재료로 쓸지
  유추가 실패했을 때 조용한 것이 더 나쁘다).
- **`reviewing-brief` SKILL.md의 두 실행 라인**(진입 첫 액션, 2-c 충실도 재실행)이
  `"$AUDIT"`를 세 번째 인자로 넘긴다. `$AUDIT`은 `$PAYLOAD`와 같은 층의 호출자
  공급 입력이라 `## 상태`의 캐스팅 목록에 추가했다(스킬 자신이 정의하지 않는다).
  `test_reviewing_brief_skill.sh`의 AC1 호출-라인 락도 2인자 접두 일치만으로는
  3인자 호출을 구분 못 해(끝 앵커가 없어 부분 일치로 계속 통과) 3인자 전체를
  요구하도록 좁혔다.
- **`test_check_verbatim_coverage.sh`가 U2-T4(합집합) 4단언을 추가하고 기존
  invocation을 전부 3인자로 이관했다.** `brief-verbatim-*` 12종 fixture에 audit
  사이드카를 새로 만들었다(payload §6에서 `S1`을 제외한 전량을 떼어 옮김 — 아래
  "Known gap"의 74+개 `interview-brief-*` legacy fixture와는 다른 파일군이라 그
  일괄 이관 대상이 아니다). S2 이상을 겨냥하던 mutation 락(T2 절단 3종)은 대상이
  audit 파일로 옮겨간 것을 따라 mutation 지점도 audit 사본으로 옮겼다 — payload는
  그대로 두고 audit만 mutate해도 union 위에서 여전히 위반이 잡히는지가 이 락의
  이빨이다. 교차 파일 중복 앵커(`brief-verbatim-dup-across.{md,audit.md}`)와 audit
  §6 부재(`brief-verbatim-audit-no-sec6.audit.md`) 전용 fixture 2종을 손으로
  추가했다. 사이드카 생성에 쓴 변환 스크립트(`mk-sidecar.py`)는 일회용이라
  리포에 남기지 않았다(git-ignored `.claude/` 하위, 설계 §7.2).
- **일괄 이관 완료 — 아래 "Known gap"이 닫혔다.** `interview-brief-*` payload
  62건(§6에 `S2` 이상을 지녔던 63건 중 `interview-brief-payload-s2`는 N1b 위반을
  영구히 유지해야 하는 대조군이라 제외)의 payload §6을 `S1`만 남도록 줄이고, 그
  §2 앵커 순회 중 이미 자기 §6을 가진 3개 사이드카(`audit-attr-missing`·
  `payload-attr-missing`·`audit-no-sec6`)와 audit_file 자체가 없는 3개
  (`borrowed-audit`·`dup-auditfile`·`empty-auditfile`)를 제외한 나머지 사이드카에
  `S2` 이상을 옮겨 실었다. `interview-brief-audit-no-sec6.audit.md`는 payload만
  줄이고 audit은 손대지 않았다 — `## 6.` 헤딩 자체가 없는 것이 그 fixture의
  존재 이유라, 헤딩을 새로 붙이면 결함이 지워진다. `interview-brief-no-attribution`·
  `interview-brief-attribution-partial`은 표준 출처 표기 블록을 합성하지 않고
  기존 payload가 갖고 있던 (없거나 부분적인) 표기 줄을 그대로 이사시켜, T18이
  attribution 검사 자체에서 red가 나는지 확인했다(이전엔 `missing audit sections`가
  먼저 걸려 우연히 green이었다 — 확인: `check_brief.py gate` 단독 실행으로 두
  fixture 모두 실패 사유가 `출처 표기 블록 부재`로 바뀐 것을 확인). 변환은
  일회용 `.claude/move-verbatim.py`(git-ignored, 리포에 남기지 않음)로 했다 —
  Task 4의 `mk-sidecar.py`가 가졌던 결함(`split_section6()`이 §6 부재 시 2-tuple,
  존재 시 3-tuple을 반환해 3-value unpack과 arity가 어긋남 — 이 태스크의 62건
  전량이 §6을 이미 갖고 있어 그 경로가 실제로 발동하지는 않았다)을 고쳐 항상
  3-tuple을 반환하도록 했다.

### Known gap (하류 Task로 이관) — RESOLVED (이 유닛에서 닫힘)

- 이 절이 서술하던 두 공백(`interview-brief-*` legacy fixture 74건의 audit §6
  부재로 인한 `test_check_brief.sh` 12건 + `test_brief_no_statement_cap.sh` L3의
  regress, 그리고 T18 두 단언이 잘못된 이유로 green이던 문제)은 바로 위 "일괄 이관
  완료" 항목이 닫혔다. `bash .claude/check-regression.sh` 재확인: `NOT-CLEAN` 없음,
  82개 파일 검사, `test_check_brief.sh` 106/106·`test_brief_no_statement_cap.sh`
  전 단언 green.

- **`test_reviewing_brief_skill.sh`의 AC1 check_verbatim_coverage.py 콜사이트 락(grep count 오라클)에
  알려진 한계 — 변수로 우회한 호출(예: `CVC="python3 $PR/scripts/check_verbatim_coverage.py"` 뒤
  `$CVC ...`)은 두 카운트 모두에서 보이지 않아 등식이 공허하게 성립한다. 고치지 않는다 — 데이터
  흐름 추적은 grep count와 질적으로 다른 도구고 콜사이트 2개짜리 점검에 과하다(락 자신의 주석에도
  같은 한계가 적혀 있다).

### Changed (Task 6 — 원문 거처를 서술하는 산문 정정)

코드·픽스처 이관(Task 2–5)이 끝난 뒤에도, 인터뷰를 실제로 작성하는 모델이 읽는 산문
쪽에는 「사용자 원문 전량이 payload §6에 있다」는 옛 서술이 남아 있었다 — 그대로 두면
그 문면을 따라 쓴 brief가 N1b에 즉시 걸린다.

- **`finishing.md` 세 문장**: ① `user_sourced_items` 직렬화 절의 원문 거처 지시를
  「`S1`만 payload §6에, 나머지 전량은 audit §6에 전문 보존(append-only)」으로 고쳤다.
  ② 「원문 보존은 관례가 아니라 요구」 서술의 게이트 항목 수를 15→16(N1b 신설 1건)으로
  갱신하고, 대상을 「원문 보존 전반」에서 「나머지 발화가 실제로 audit §6로 옮겨졌는가」로
  좁혔다 — N1b가 `S1`의 payload 잔류는 이미 못박으므로, 게이트가 여전히 못 잡는 것은
  전량 이관 여부뿐이다(설계 §10 넷째 gap, 아래 "Known gaps" 참조). ③ `/compact` 보존
  리터럴의 「§6 사용자 원문」을 「§6 사용자 원문 중 `S1`」으로 좁혔다 — payload §6엔
  이제 `S1`만 산다.
  `S1`의 배치·번호 공식을 지시하는 문장(`$ARGUMENTS` → `S1` → §6 맨 앞)은 그대로
  뒀다 — `S1`이 payload 잔류 예외이므로 여전히 참이고, 이를 리터럴로 잠근 기존 락도
  그대로 옳다.
- **신규 락 `U2-T6`** (`test_conducting_interview_stage.sh`) — 위 ①의 규칙에는 §번호도
  절 제목도 개명 식별자도 없어 이 스위트의 도출 규칙(①–④)이 못 잡는다. 양성 대조
  (`user_statements` 리터럴로 코퍼스를 실제로 읽었음을 먼저 확인) + 목적지 존재
  (`audit §6`) + 옛 지시 부재, 세 단언 구조다. **1차 버전은 목적지 존재 단언을 그냥
  `audit §6`로 앵커했다가, 실제로 ①의 문장을 통째로 지우고 돌려본 결과 조용히 green을
  유지하는 것을 확인했다** — 바로 아래 ②의 게이트-집행 서술 문장이 독립적으로
  `audit §6`를 담고 있어(body-unique 위반), ①만 지워도 이 단언이 그 문장으로 계속
  만족됐다. 복합 리터럴 `전량은 **audit §6**에`(①에서만 나는 문구)로 좁혀 고쳤다 —
  같은 자리에 두 grep 앵커가 겹치면 한쪽이 죽어도 안 잡히는, 이 리포가 반복해 겪은
  락 실패 클래스의 실측 사례다.
- **`reviewing-brief/SKILL.md` 넷** — (a) `## 수정 권한` 표의 `§6 사용자 원문` 단일 행을
  `payload §6 사용자 원문 (S1)`(불변, 추가도 금지 — 앵커 집합이 `{S1}`로 고정, N1b) /
  `audit §6 사용자 원문 (S2+)`(append-only, 기존과 동일)로 분할했다 — 관할은 「전량
  이동」이 아니라 「`S1` 잔류 예외를 따라가는 분할」이고, payload 행의 「기존 항목 본문
  변경 금지」가 설계 §2.3·§10이 기록한 URL 통로를 막는 유일한 장치라 지우지 않았다.
  (b) 방향성 재결정 절차(1-d)의 「그 결정 발화를 §6에 새 `S<N>`으로 추가」의 목적지를
  `audit §6`로 좁혔다. (c) 「진입 첫 액션」헤더를 `(payload §6 ∪ audit §6 ↔ state
  원장)`으로, rc=1 행의 「§6를 보완」을 `audit §6를 보완(payload §6은 S1으로 불변)`으로
  명시했다. (d) 「orchestrator의 허용 행위 — 닫힌 열거」표에 `audit §6에 S<N> 추가`를
  명시로 올리고(전에는 `§6`로만 적혀 있어 payload/audit 어느 파일인지 불명), 금지 행도
  `payload §6(S1) 변경 또는 추가` / `audit §6 기존 항목 본문 변경` 둘로 나눴다 — 닫힌
  열거라 audit 파일 편집이 목록에 없으면 새 append 흐름이 규약상 금지된 채 남는다.
- **`conducting-interview/SKILL.md` 둘** — P21 placeholder 문면의 「§6 원문 대조」를
  「payload §6 ∪ audit §6 원문 대조」로, seed 재결정(P23) 절의 「그 뒤집음을 §6에 새
  `S<N>`으로 추가」를 `audit §6`로 좁혔다(payload §6은 `S1`으로 불변이므로 새 앵커는
  audit에만 붙는다).
- **`README.md` 둘** — 파이프라인 다이어그램의 「진입 첫 액션: check_verbatim_coverage.py
  (§6 원문 ↔ state 원장)」을 `(payload §6 ∪ audit §6 ↔ state 원장)`으로, Law 1 핸드오프
  게이트 서술의 bijection C 대상 「`evidence: S<N>` → §6」을 `payload §6 ∪ audit §6`으로
  갱신했다.
- **`framing-requests/SKILL.md:466`은 확인만 하고 고치지 않았다** — 「사용자가 방금
  확정한 요청이 brief §6에 보존되지 않습니다」는 `$ARGUMENTS`가 **비었을 때**의 실패
  서술이다. 그 경우 `finishing.md`의 규약대로 `S1` 자체가 생성되지 않으므로(인자 없이
  호출되면 `S1`을 만들지 않는다), 원문이 payload/audit 어느 쪽에도 들어가지 않는다는
  주장은 이관과 무관하게 그대로 참이다. 근거 없는 편집을 넣지 않는다 — 다음 세션이
  "왜 바뀌었나"를 묻게 만들 뿐이다.

### Known gaps (Task 6 — mutation 실측, 설계 §7.1/§10)

설계 §7.1의 U2 mutation 표 중 GREEN이 기대인 행은 락이 아니라 구조적 구멍의 실재를
고정하는 행이다. 실측 결과를 여기 기록한다 — 기록하지 않으면 다음 세션이 이것을
결함으로 오인해 "고치려" 든다.

- **payload §6 `S1`에 문장을 덧붙이면 게이트가 통과한다.** `check_verbatim_coverage.py`의
  L2는 containment(포함) 검사라 초과분을 막지 않는다 — `S1`의 본문이 사용자가 실제로
  말하지 않은 텍스트를 흡수할 수 있다(설계 §2.3·§10이 기록한 통로). `reviewing-brief`
  수정 권한 표의 「payload §6(S1) 변경 또는 추가 금지」는 이 구멍에 대한 **규범적**
  가드일 뿐 기계 집행은 아니다 — 삭제·변형은 L2가 잡지만(§6 `S1`에서 문장을 지우면
  RED) 첨가는 잡지 못한다.
- **모든 `user_sourced_items` 항목이 `evidence: S1`만 인용하는 brief에서 audit §6의
  `S2` 이상 앵커를 전부 비워도 `check_brief.py gate`가 통과한다.** bijection C는
  *인용된* 앵커의 존재만 확인하는 단방향 검사라, 아무도 인용하지 않는 원문이 실제로
  audit으로 옮겨졌는지는 게이트 시점에 검증되지 않는다(설계 §10 넷째 gap). 이
  불변식은 `check_verbatim_coverage.py`(L1, `reviewing-brief` 진입 첫 액션)가 게이트
  **밖**에서 채운다 — 같은 조건에서 L1은 여전히 `missing_ids`로 RED를 낸다(실측
  확인, `check_brief.py`의 bijection C를 무력화해도 L1은 독립적으로 RED).
- (참고, gap은 아니고 이관 완료의 확인) **audit §6에서 출처 표기 블록(`🗣·☑·✎`)을
  지우면 RED지만, 같은 블록을 payload §6에서 지우는 것은 지금은 no-op이다** —
  `attribution_block_missing()`이 `audit_text`만 읽으므로(v0.43.0 이관), payload §6엔
  애초에 그 블록이 존재하지 않는다(이관 전 상태의 양성 대조는 Task 2 Step 1 기록).

## [0.42.0] — 2026-08-31

### Removed
- `STATEMENT_MAX = 160` 상한과 그 전 표현을 지운다 — `check_brief.py` 의 게이트 검사,
  `finishing.md` 의 「160자 이내」지시, 픽스처 2쌍(`interview-brief-statement-160/161`
  및 각 audit)과 그것을 소비하던 `test_check_brief.sh` T23 단언. 상한이 잰 것은
  과잉결정이 아니라 부피였다 — 과잉결정은 대리 지표가 아니라 brief-readback 이 직접 잰다.
  삭제 전 양성 대조를 기록했다: `interview-brief-statement-161.md` 가 변경 전
  `rc=1` · `"C1: statement 161자 > 160 (hard cap)"` 이었다. 회귀 락
  `test_brief_no_statement_cap.sh` 는 3층(양성 대조 → 부재 → 행동)으로 재발을 막는다.

### Fixed

- **`test_brief_no_statement_cap.sh` L3 를 메시지 리터럴 앵커에서 rc(종료 코드) 앵커로
  바꿨다.** mutation 축 (c)(이름만 바꿔 상한을 되살림 —
  `if len(stmt) > 160: errs.append(f"{iid}: too long")`)로 처음 드러난 gap: 이
  mutation 을 적용하면 게이트는 실제로 200자 statement 를 거부하는데(`rc=1`,
  `"user_sourced_items: ['C1: too long']"`), 옛 L3 는 `grep -q 'hard cap'` 로 **그
  문구만** 찾아 "too long" 은 못 잡고 `ok`(안 걸림)를 냈다 — L3 가 사실상 L2(리터럴
  부재 검사)의 중복이었다. 지금은 파생 fixture 의 `audit_file`/`payload` 역참조를
  새 파일명에 맞춰 함께 갱신해(사이드카 짝을 완성해) 게이트가 그 fixture 에 대해
  `rc==0`·`"pass": true`·무-failures 를 내는 것을 cap 제거 후의 유일하게 옳은 결과로
  확정했고, L3 는 이제 `rc == 0`(그 어떤 이름의 상한도 재도입되지 않았다)을 1차
  단언으로, `hard cap` 리터럴 grep 을 진단용 보조 단언으로 둔다. 재검증: 같은
  mutation(`ev = it.get("evidence")` 앵커, `git diff --stat` 으로 실제 3줄 삽입
  확인)을 다시 적용하자 L3 가 이번엔 RED(`rc=1`)를 냈다 — 리네임을 실제로 잡는다.
  mutation (a)/(b) 는 각각 `git diff --stat` 으로 실제 코드 변경을 확인한 뒤 기대대로
  rc=1(L1 NO / L2 NO) 을 냈다 — 브리프가 준 (c) 의 원래 anchor 문자열
  (`errs.append(f"{iid}: id 형식`)은 현재 `check_brief.py` 에 존재하지 않아 최초
  실행은 무변경 no-op 이었다(diff 없음) — anchor 를 `ev = it.get("evidence")` 줄로
  교체해 실제 변경을 확인한 뒤 재실행했다.
- **출하 템플릿(`templates/interview-brief-template.md:20`)이 상한을 도로 가르치고
  있었다.** `finishing.md` Step A가 이 템플릿을 매 인터뷰가 읽는 살아있는 소스로
  지정하므로, 코드에서 지운 `STATEMENT_MAX` 를 이 파일의 주석(`# 160자 이내(hard) —
  ...`)이 모든 미래 brief 작성에 재교육하고 있었다 — 브리프의 "Files to Modify" 목록
  누락. `160자 이내(hard) — ` 절만 제거했고 나머지 주석(모델이 쓴 요약이라는 것,
  P21 secret placeholder 치환)은 그대로 남겼다 — 그 부분은 여전히 유효하다. 이 편집이
  템플릿 자신의 `check_brief.py gate` rc(=1, `audit_file` sidecar 불일치 — 상한과
  무관한 기존 사유)와 T-TPL 스위트 결과를 바꾸지 않음을 확인했다.
  `test_brief_no_statement_cap.sh` 의 코퍼스도 넓혔다 — 이전에는 `check_brief.py`
  와 `finishing.md` 만 읽어 이 템플릿 잔존을 못 봤다(재실행해도 GREEN 이었다). L1 에
  템플릿 전용 양성 대조 행(`next_phase: superpowers:brainstorming` 앵커 — L2 가 찾는
  상한 리터럴과 다른 줄이라 둘이 같은 원인으로 동시에 반응하지 않는다)을, L2 에 템플릿
  상한 부재 행을 추가했다. mutation 으로 검증: (1) 템플릿에 cap 절을 재삽입 →
  `git diff --stat` 으로 실변경 확인 후 새 L2 템플릿 행이 RED. (2) 템플릿 파일을
  통째로 비움 → L1 템플릿 행이 RED(부재 검사가 빈 파일에도 통과하는 공허함이 아님을
  확인). 둘 다 복원 후 `git status --porcelain plugins/spec-distill` 깨끗함.
- **템플릿 L2 부재 행은 리터럴 grep 이라 다른 어휘의 상한을 놓친다 — `# max 160 chars,
  strictly enforced` 처럼 영어로, 다른 표현으로 다시 써넣으면 옛 L2 는 GREEN 을 냈다**
  (재리뷰 실증). `id`/`P21` 같은 값이 그 줄에 정당하게 들어 있어 숫자 기반 검사는
  오탐하고, 상한 어휘를 두 언어로 열거하는 것도 조용히 낡는 추측이다 — 이 저장소는
  이미 이 한계를 판정해 뒀다(`test_probe_sweep_residue.sh`): grep 오라클은 식별자와
  인접 단어를 재지 의미를 재지 않으며, 그 너머를 지키는 것은 락이 아니라 리뷰의 일이다.
  그래서 `templates/interview-brief-template.md` 의 C1 `statement:` 주석 **한 줄만**
  부재가 아니라 **정확한 등가**로 고정했다 — `# 모델이 쓴 요약. P21 secret placeholder
  치환` 과 정확히 같아야 하고, 그 줄에 무엇을 덧붙이든(어떤 언어의 상한이든, 숫자든)
  등가가 깨져 red 가 된다. 앵커는 파일 위치(20행)나 "첫 statement: 매치"가 아니라
  `id: C1` 항목 다음에 나오는 첫 statement: 줄이다 — 파일에 statement: 가 둘(C1/D2)
  있고 주석은 C1 쪽에만 있어, 위치나 순서에 기대면 그 순서·개수가 바뀔 때 엉뚱한 줄을
  잰다. mutation 4종으로 검증(각각 `git diff --stat` 으로 실변경 확인 후 실행,
  복원 후 `git status --porcelain plugins/spec-distill` 깨끗함 확인): (1) 옛 한국어
  cap 절 재삽입 → RED. (2) 다른 숫자·영어 cap(`# max 200 chars, strictly enforced`)
  재삽입 → RED — 이것이 옛 L2 가 놓치던 바로 그 경우다. (3) 주석 전체 삭제(값만
  bare) → RED. (4) 템플릿 전체를 비움 → L1 템플릿 행 RED(round 2와 동일, 재확인).
  **이 등가 행이 못 미치는 것**: C1 statement 주석 한 줄 밖에서 상한이 재도입되거나
  (예: D2 statement 주석, 혹은 이 파일 밖 다른 모델-지시 채널), 이 락이 안 읽는 완전히
  다른 경로로 모델에게 상한이 재학습되는 경우는 여전히 이 락의 사각지대다 — 그 너머는
  리뷰가 계속 맡는다.

## [0.41.0] — 2026-08-29

### Changed
- 인터뷰 R1 이 `Reframe (메타 프롬프트)` 에서 **`Problem Reframe`** 으로. 「받은 요청 재구성」은 `request-framing` 이 하고, 여기서는 **seed 가 가리키는 작업 뒤의 진짜 문제**를 재구성한다. 명칭 변경이 아니라 R&R 이동이다.
- `commands/interview.md` 의 trivia 5패턴이 `references/trivia-escape.md` 포인터로.

### Added
- `conducting-interview` 에 seed 입력 규약. seed 본문은 §6 `S1` 이 되고, 인터뷰 중 사용자가 seed 를 뒤집으면 **새 발화가 이기며** 그 재결정이 §5 에 기록된다(P23).
- `/interview` 가 seed 아닌 입력에 조언 한 줄을 낸다 — **차단하지 않는다**(호환 유지).

### 검증 경계 — 이 판본에서 실제로 관측한 것

- **진짜 codex 바이너리를 태운 실행은 이 판본에 0회다**(한도 소진). v0.39.0 이 seed codex
  러너를 「배선되어 실제로 호출된다」고 쓴 것은 **배선의 계약**을 서술한 것이고, 관측으로
  확인된 것은 셋이다: ① 게이트 블록을 잘라내 stub/mock 위에서 돌렸을 때 **mock 이 실제로
  호출됐고**(sentinel 실재) 그 argv 가 계약대로였다는 것, ② kill switch · 감지기 부재 ·
  `exit 3` · 게이트 입력 부재 각 경로의 fail-closed 처리가 관측된 사후상태와 일치한다는
  것, ③ 산출물 판정이 성공 마커 **양성 요구**로 돈다는 것. **모델 다양성이 실제로 확보되는지는
  한도가 풀린 뒤 실호출로 확인해야 한다** — 지금까지의 GREEN 은 그 사실의 증거가 아니다.

## [0.40.0] — 2026-08-29

### Added
- **`/request-framing` — 파이프라인 Phase 0.** 사용자의 의도·steering·방향·goal을 싱크해
  새 세션의 첫 턴 메시지 `interview-seed`로 압축한다. 산출물은 문서가 아니라 **붙여넣는
  메시지**이며 절·라벨·태그·URL이 없다.
- `skills/framing-requests/` — 확산 후 압축 절차. `proceed-gate.md`·`compression.md`·
  `trivia-escape.md` 채택.
- `agents/seed-critic.md` · `agents/seed-readback.md` — 둘 다 `tools: []`. critic은 억제
  네 축, readback은 냉독이며 **판정은 사용자가 한다**.
- `references/compression.md` — 압축 규약 공유 계약. **오늘 게이트로 집행하는 것은
  seed뿐**이고 brief는 재구조화 이후에 채택한다.
- `references/trivia-escape.md` — 5패턴 정의 정본. `commands/request-framing.md`와
  `framing-requests`가 가리킨다(`commands/interview.md`는 아직 자기 인라인 사본을 쓴다).
- `scripts/check_seed.py` — 게이트 다섯: seed 본문 슬롯 부재 검사 셋(답-슬롯 헤딩·태그·
  URL) + 본문 전체가 비어 있지 않은지 보는 파일-전체 존재 검사 하나(check 0) + audit 쪽
  `## 1. 원문` 절 존재 검사 하나. seed 본문에 대한 **슬롯** 존재 검사는 없다.
- seed 억제 축 codex 러너·빌더·체크리스트(`run_seed_codex_reviewer.sh`·
  `build_seed_codex_prompt.py`·`seed-codex-suppression-checklist.md`)가
  `framing-requests` skill의 게이트 블록에 배선되어 실제로 호출된다.
  `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1`이 호출자 책임으로 그 호출을 막고, 러너가
  산출물을 못 쓰고 죽으면(`exit 3`) 직전 라운드 잔존물을 지운다. 억제 findings는 어떤
  병합기도 거치지 않고 사용자에게 직접 간다.

### Fixed
- `skills/framing-requests/SKILL.md` — `interview-basename` 파일이 생기는 시점 서술을
  실제 조건(블록의 `TOPIC` 자리표가 실값으로 치환된 실행)에 맞췄다. 자리표가 그대로면
  블록이 돌아도 파일을 만들지 않고 advisory만 낸다.

## [0.39.0] — 2026-08-28

### Added
- `scripts/brief_review_state.py`에 `--ledger-key`(닫힌 열거: `brief_review_degradations`·
  `framing_degradations`, `get`·`degrade-append` 양쪽). 다른 파이프라인이 같은 writer로
  자기 원장에 쓴다 — 읽기·쓰기·기본값이 `LEDGER_KEYS` 하나를 거친다(리터럴 산개 금지).
- `AXES`에 `suppression` — seed 억제 축의 degrade record를 위한 `affected_axis` 값.

## [0.38.0] — 2026-08-28

### Removed
- `scripts/probe_budget.py` 와 그 전용 테스트·픽스처(`tests/test_probe_budget.sh`,
  `tests/fixtures/state-probe-at-cap.md`, `tests/fixtures/state-probe-within.md`). 인터뷰
  질문·라운드에 상한을 두지 않는다 — 질문 루프는 매 반복마다 사용자가 답해야 돌므로 묶을
  자율이 없다.
- `DEVBREW_SPEC_DISTILL_PROBE_CAP` kill switch (대상이 사라졌다).
- `skills/conducting-interview/SKILL.md`의 `## probe 백스톱 (C1/C10 …)` 절과
  `probe_count`/`probe_cap_override` state 필드 — 아래 coverage-mapper 재dispatch
  바운드가 이 카운터를 대체한다.

### Changed
- coverage-mapper 재dispatch 바운드를 `probe_count` 단위에서 **에피소드 필드 둘**
  (`orchestration.stall_episode` · `orchestration.coverage_mapper_dispatched_episode`)로
  이식. 재dispatch 조건은 `no_progress_streak >= 3 AND coverage_mapper_dispatched_episode
  != stall_episode` — 판정은 여전히 디스크 두 값의 비교(무상태)이고 한 정체 구간당
  정확히 1회다. 회귀락을 토큰 공존이 아니라 이 AND 관계 전체에 걸도록 강화했다
  (리뷰가 `AND`→`OR` 반전을 놓치던 결함 1건을 실측 적발).
- floor 탈출구의 발동 조건이 카운터에서 **사용자 발화**로. 사용자가 언제든 종료를
  요청하면 미충족 floor 는 사용자-승인 박제로 닫고(`evidence` 에 `사용자-승인 박제(@사용자
  종료 요청)` 기록) payload §3 Open Questions 로 이월한다. 박제 표식이 원장에 남으므로
  silent bypass 가 아니다.
- audit `## 2. Budget` 절의 본문이 상한 서술에서 **지출 기록**(`질문 라운드: <n> · agent
  dispatch: <n> · codex 실호출: <n> (성공 <n>)`)으로.
- `skills/conducting-interview/SKILL.md`의 `S<N>` id 번호 공식이 최초 요청 원문(`S1`)
  예약을 반영 — 원문이 있으면 `user_statements` 는 `S2`부터, 없으면 `S1`부터 시작한다.
  이 정합이 없으면 payload §6 에 `S1` 앵커가 중복되거나 payload·state 의 `S1`이 서로
  다른 텍스트를 가리켜 `check_verbatim_coverage.py`가 red 를 낸다(§6 원문 완전성 검사).

### Added
- `finishing.md`에 최초 요청 원문(`$ARGUMENTS`)을 §6 `S1`로 보존하는 요구. 지금까지는
  관례였고 게이트 15항 어디에도 이 요구가 없어 원문이 보존되지 않은 인터뷰도 통과했다.
  `test_conducting_interview_stage.sh`에 이 요구와 번호 공식 정합을 파일 전체·내용
  표지 위 **∀**(모든 매치가 정본과 일치)로 결속하는 단언을 추가하고,
  `test_check_verbatim_coverage.sh`에 영구 픽스처 2쌍(정상 공식 / 구-공식 회귀)을 넣었다.
- `tests/test_probe_sweep_residue.sh` — probe 어휘 스윕 완결성의 단측 단언. 식별자 열거
  (`ALIAS_RE`)뿐 아니라 개념명 근접 스캔(`CONCEPT_RE` — "probe 상한"이 다른 이름으로
  재작성되는 것에 대한 좁은 방어)까지 스캔하고, 세 예외(`tests/fixtures/` ·
  `CHANGELOG.md` · 이 파일 자신)의 자기지시를 제외한다. 양성 대조를 계열별(별칭/개념
  각각)로 분리해 — 합본 하나만 걸던 대조는 한쪽 계열만 깨져도 통과했다(실측:
  `ALIAS_RE`만 깨도 GREEN) — 두 계열이 각자 이빨을 갖게 했다.

## [0.37.0] — 2026-08-27

### Added
- 재결정 규약(P23)을 `references/proceed-gate.md` 계약의 절로 승격. 확정된 항목은 재논의 대상이 아니지만 **반증 대상**이며, 근거와 사용자 동의가 있으면 피벗할 수 있다.
- `skills/reviewing-spec/SKILL.md` 에 이 skill 어휘의 재결정 규약 절.
- `tests/test_proceed_gate_adopters.sh` 에 네 번째 채택자 앵커(P23).

## [0.36.0] — 2026-08-27

게이트의 연료를 «어떤 도구가 돌았나»에서 «git 이 무엇을 dirty 로 보나»로 바꾼다.
쓰기-도구 matcher 가 만들던 우회가 사라져, Bash heredoc·`sed -i`·외부 편집기로 쓴
스코프 문서도 턴 끝에 구조 검증과 리뷰 dispatch 를 지난다.

### Removed
- **`hooks/spec-write-validator.py` (PostToolUse, `matcher: "Write|Edit|MultiEdit"`)** — 쓰기-도구
  matcher 는 Bash heredoc·`sed -i` 로 쓴 파일을 보지 못한다. 이 리포에서 실제로 발생했다:
  세션 지시가 Bash 쓰기를 요구했고 `docs/superpowers/specs/` 문서 3개가 Law 1 게이트를 한
  번도 통과하지 않은 채 커밋됐다. kill switch 는 켜지지 않았다 — 게이트는 꺼졌다고 **말하지
  않고** 꺼졌다.
- **`hooks/pending-review-reminder.py` (UserPromptSubmit)** — `pending_review:` 만 소비했다.
  그 계약이 은퇴하면서 함께 사라진다. 그 훅이 `PENDING_RE` 검사 **이전에** 돌던 두 가지는
  인계를 확인했다: `fire_and_forget_gc()` 는 `review-dispatch.py` 가 같은 자리에서 이미
  부르고(Stop 은 매 턴 돌아 빈도가 같거나 높다), state 판독 실패 advisory 는 같은 훅이 같은
  조건에서 낸다.
- `pending_review:` 상태 블록 · `arm_ledger.strip_pending`·`strip_pending_file` ·
  CLI `strip-pending` · `hook_common.PENDING_RE`
- `tests/{test_spec_write_validator.sh,test_design_mode_validator.sh,test_reminder_hook.sh,test_stale_state_truncate.sh}`
- **`DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`** — 이 변수를 읽던 유일한 지점(위 write-time
  validator)이 사라져 더 이상 아무것도 끄지 않는다. **지정 대체재는 없다** — 이 변수가 주던
  능력 자체가 이 릴리스에서 사라졌다(아래 Changed 의 첫 BREAKING 항목).

### Added
- **`scripts/discover_candidates.py`** — 스코프 문서 발견. `git status` 에 **pathspec 을 주지
  않고** dirty 집합 전체를 상계로 받은 뒤 `arm_ledger.canonical_key` 로 좁힌다. wildmatch 를
  방정식에서 빼므로, 판본 4·5 가 연속으로 낸 pathspec 결함이 재발할 수 없다.
- 원장 블록 `inflight_paths:` (TTL `INFLIGHT_TTL_SEC` = 900초) 와 `validation_attempts:`
  (상한 3, `dispatch_attempts` 와 **별도**). CLI `clear-inflight`.
- `scripts/resolve_mode.py` — 삭제되는 훅에서 동작 무변경으로 옮겨왔다.
- `tests/test_write_path_behavior.sh` — 실제 `claude -p` 턴으로 A7·A8·A9·A18 을 잰다. 정적
  락이 볼 수 없는 «훅이 정말 발화하는가»만 여기서 잰다. API 크레딧을 쓰므로 기본은 skip 이고
  `DEVBREW_BEHAVIOR_TESTS=1` 일 때만 돈다.

### Changed
- **`Stop` 훅(`review-dispatch.py`)이 발견·Layer 1 구조 검증·리뷰 dispatch 를 모두 수행한다.**
  구조 검증은 파서를 `subprocess` 로 부르지 않고 import 한다 — 훅 timeout 이 10초인데
  `call_parser` 가 호출마다 `timeout=10` 을 걸어 중첩 timeout 을 만들던 구조가 사라진다.
  순서는 구조 검증 → TTL 가드 → dispatch 로 고정되며, 구조 실패가 있으면 그 사유만 block 으로
  나가고 dispatch 는 그 턴에 없다.
- 턴당 검증 문서 상한 5(`CANDIDATE_CAP`). 정렬이 안정적이라는 사실 자체가 기아의 원인이므로
  그 위에 **커서 회전**을 얹는다. 실측(문서 7개·3턴): 1턴 doc1–5 → 2턴 doc6·doc7·doc1–3 →
  2턴째에 7개 전부가 최소 1회 검증된다. 회전을 제거한 변이에서는 doc6·doc7 이 영구히 굶는다.
- 훅이 4개에서 2개(`Stop`·`SessionEnd`)로 줄었다. **신규 훅 0개.**
- `agents/spec-reviewer.md` — 삭제된 경로(`hooks/spec-write-validator.py:resolve_mode`)와 은퇴한
  `pending_review.mode` 계약의 **인용만** 갱신했다(각각 `scripts/resolve_mode.py` 와 prompt 의
  `mode:` 로). 리뷰 규칙·임계·판정 기준은 한 줄도 건드리지 않았다.
- **BREAKING — «구조 검증(Layer 1)은 유지한 채 자동 리뷰 dispatch 만 중단» 능력이 사라졌다.**
  등가 스위치가 없다 — `DEVBREW_SKIP_HOOKS=spec-distill:Stop` 은 발견·구조 검증·dispatch 셋을
  **함께** 끈다(셋이 한 훅의 한 진입점 뒤에 있다). 그 능력의 복원은 이 릴리스의 범위 밖이며
  신규 기능 작업이다.
- **BREAKING — dispatch 가 더 이상 «그 문서가 구조 검증을 통과했다»를 함의하지 않는다.**
  검증은 상한 5의 회전 창을 훑고, dispatch 선택은 후보 목록을 **0번부터** 훑는다. 두 술어가
  다르므로 dirty 문서가 5개를 넘으면 어긋날 수 있다 — 실측: 커서가 앞쪽을 지난 뒤 정렬상 맨
  앞에 오는 문서가 새로 dirty 가 되면, 그 문서는 검증 창 밖인 채로 dispatch 된다. 좁고
  자기교정적이지만(다음 회전이 잡는다) 변경 전의 불변식은 사라졌다.
- **BREAKING — «재편집하면 재발동» 트리거가 은퇴했다.** 이미 dirty 인 untracked 문서를 다시
  편집해도 `git status` 가 보고하는 것은 달라지지 않으므로, 재편집은 더 이상 관측 가능한
  트리거가 아니다. 리뷰되지 않은 문서는 이제 **in-flight TTL 만료**(`INFLIGHT_TTL_SEC`, 900초)로
  돌아온다. «파일을 건드려 리뷰어를 다시 부른다»는 이제 그만큼의 기다림이다.
  **그 창 동안 멈추는 것은 dispatch 뿐이 아니다** — 아래 Known limitations 의 in-flight 항목.

### Fixed
- **구조 검증 상한 advisory 가 `systemMessage` 로 나간다.** 이전 판은 stderr 에만 냈는데,
  같은 파일이 네 곳에서 근거로 드는 사실(exit 0 의 stderr 는 전달되지 않는다) 때문에 그것은
  전달되지 않는 채널이었다 — 형제 advisory 셋(git 불능 · state 판독 실패 · 은퇴 스위치)은
  이미 `systemMessage` 를 쓴다. 이 통지는 그 문서가 **이 세션의 Law 1 게이트를 영구히
  벗어난다**는 사실이라 조용하면 설계 §4.4 를 어긴다. 같은 턴에 block 이 함께 나갈 수
  있으므로 별도 emit 이 아니라 그 JSON 의 `systemMessage` 에 합쳐 낸다(stdout 의 JSON 은
  하나여야 한다 — 둘이면 파싱이 깨져 block 이 조용히 사라진다). 같은 상한의 **동턴 절반**
  (`reached_cap`)은 이전부터 block `reason` 을 타고 전달됐고 그대로다.
- **원장 블록 기록 실패가 block 루프를 만들지 않는다.** `rewrite_state` 의
  `record_attempt`(G6 상한)·`mark_inflight`(발견 제외) 실패는 이전 판에서 stderr 로 적히고
  **그대로 block 을 냈다**. 연료가 `pending_review` 이던 시절에는 그 소비가 무조건 일어나
  대가가 «dispatch 한 번 더» 였지만, 발견이 무상태가 된 뒤로는 소모될 연료가 없고 두 억제자가
  **둘 다** 그 실패 뒤에 있다 — 남는 상한이 30초 TTL 하나뿐이라 사람의 턴 간격이 그것을 매번
  넘긴다(재현: 두 함수를 raise 로 갈아끼우고 `main()` 4회 연속 → 4회 모두 `decision: block`).
  이제 `OSError` 와 **같은 처분**을 받는다: loud 하게 적고 emit 없이 접는다. 안전한 근거는
  이 릴리스 자신의 논거다 — 발견은 무상태라 다음 Stop 이 같은 문서를 다시 찾는다.
  `select_dispatch_target` 의 원장 조회 실패가 이미 같은 논거로 같은 선택을 한다.

### Deprecated
- kill switch 토큰 `DEVBREW_SKIP_HOOKS=spec-distill:validator` · `spec-distill:PostToolUse` ·
  `spec-distill:reminder` · `spec-distill:UserPromptSubmit` 은 가리킬 대상을 잃었다.
  **구조 검증이 `Stop` 훅으로 옮겨왔으므로 이 토큰들로 껐던 사용자는 검증이 말없이 되살아난
  것을 보게 된다** — `review-dispatch.py` 가 세션당 1회 그 사실을 알린다.
  가장 가까운 스위치는 `DEVBREW_SKIP_HOOKS=spec-distill:Stop` 이지만 **등가 대체재가 아니라
  더 넓다.** `:validator`/`:PostToolUse` 는 write-time 훅 하나만 껐고 dispatch 는 그때
  `Stop` 훅에 있어 계속 돌았다 — 즉 그 토큰들도 «검증만 끄기»였다. `:Stop` 은 발견·검증·
  dispatch 를 함께 끈다. 바로 아래 `SKIP_AUTOREVIEW` 항목과 **같은 종류의 비대칭**이며,
  차이는 이쪽엔 그나마 더 넓은 스위치라도 있다는 것뿐이다.
- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` 도 같은 릴리스에서 죽었으나 **대체재가 지정되지
  않는다** — 위 Removed 를 보라. `spec-distill:Stop` 을 대체재로 적지 않는 이유는 그것이 둘을
  함께 끄기 때문이다. 같은 것이라고 적으면 거짓이 된다.

### Security
- 은퇴한 kill switch 다섯(`spec-distill:PostToolUse`/`:validator`,
  `spec-distill:UserPromptSubmit`/`:reminder`, `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`)을
  Stop 훅이 **세션당 1회** 공시한다. 전부 fail-open 방향으로 죽었다 — 껐다고 믿는 동작이
  말없이 되살아나므로, 침묵은 kill switch 를 보안 컨트롤로 다루는 CLAUDE.md 조항과 어긋난다.
  각 스위치는 **원래 읽히던 방식 그대로** 대조한다(토큰은 콤마 분리 + 전체 토큰, 환경변수는
  `== "1"`) — 다르게 매칭하면 공시가 사용자 자신의 설정에 대해 거짓을 말한다. 공시는 **구조
  검증 뒤·dispatch 앞**에서 나가므로 Layer 1 을 늦추지 않는다.

### Performance
기준선 `origin/main` **983d7d7** 대 이 브랜치, 같은 시나리오(도구 호출 약 30회 — Read 20 ·
Bash 5–7 · Write 3), 세 플러그인을 함께 로드, **팔당 2회**. 계측 래퍼는 스크래치 사본에만
넣었고 배포본에는 없다. 측정 환경: macOS · Claude Code 2.1.241.

- **없앤 훅의 비용 (Write 3회 + 프롬프트 1회 — 두 팔에서 동일):** 기준선 **384.6 / 398.7 ms**,
  이 브랜치 **0 ms**. 내역 — `spec-write-validator.py` ×3 = 110.4/121.3 ms,
  `pending-review-reminder.py` ×1 = 83.1/87.6 ms, quality-gates
  `post-tool-use-session-tracker.py` ×3 = 91.8/90.5 ms, project-init `docs-lint.py` ×3 =
  99.3/99.2 ms.
- **늘어난 것:** `Stop:review-dispatch.py` 가 발견·검증을 흡수해 80.5/84.6 ms → 109.1/100.2 ms
  (**+15.6 ~ +28.6 ms**). **이 증가분은 잡음과 분리되지 않는다** — 이 브랜치가 건드리지도
  않은 `spec-distill SessionEnd:session-end-cleanup.py` 가 **같은 팔 안에서** 65.6 → 43.7 ms
  (21.9 ms) 흔들렸다. 프로세스 기동 잡음이 증가분과 같은 자릿수라는 뜻이므로, 위 두 수를
  «Stop 훅이 정확히 그만큼 느려졌다»로 읽으면 안 된다. 아래 순감이 견고한 이유는 반대다 —
  없앤 385~399 ms 가 이 잡음보다 한 자릿수 크다.
- **시나리오당 순감 −356 ~ −383 ms.** 설계 §8 의 예측(≈244 ms)보다 크고, 격차(140~155 ms)의
  원인은 **둘**이다. ① 예측이 `pending-review-reminder.py` 를 실측값 부재로 제외했다
  (83.1/87.6 ms). ② **쓰기 훅 3개만 따로 봐도 예측이 낮았다** — 설계는 Write 1회당
  31.6+23.6+26.2 = **81.4 ms** 를 가정했는데 실측은 **≈100 ms/회**(3회 합 301.5/311.0 ms 대
  예측 244.2 ms)였다. 추정치를 다시 세울 사람에게는 ②가 ①보다 이월 가치가 크다 — ①은
  이 릴리스에서 사라지는 항목이고, ②는 훅 프로세스 기동 비용 자체의 보정값이다.
  비교군이 기준선보다 크지 않으므로 설계 §8 이 요구한 역행 advisory 는 해당 없음.
- **벽시계는 이 변경의 신호가 아니다.** 기준선 73.79/55.89 s, 이 브랜치 54.92/59.24 s — 두 팔의
  범위가 겹친다. 실행 간 벽시계 산포(≈18 s)가 훅 시간 차이(≈0.37 s)보다 두 자릿수 크므로,
  이 시나리오의 벽시계는 모델 지연을 재고 있다. 이 수치를 머지 게이트로 쓰지 않는다.

### Known limitations
- **in-flight 표시는 dispatch 만이 아니라 구조 검증도 멈춘다 — 최대 900초.** `A12` 와 설계
  §4.1 은 리뷰 진행 중인 문서를 «발견 결과에서 제외» 하라고 하고, 발견 결과가 곧 검증 후보
  집합이다. 그래서 dispatch 된 문서는 `INFLIGHT_TTL_SEC`(900초) 또는 verdict 중 먼저 오는
  것까지 **Layer 1 구조 검증을 받지 않는다 — 어떤 도구로 쓰든**. 창을 여는 조건은 좁다:
  모델이 dispatch mandate 를 무시해야 하고, 그 문서는 이미 리뷰 큐에 들어가 있다. 구현은
  명세대로이고 이것은 **명세 쪽 미결**이다 — 좁히려면 발견 제외와 검증 제외를 서로 다른
  술어로 가르는 설계 변경이 필요하며(armed 게이트를 그렇게 가른 전례가 이 릴리스에 있다),
  그 판단은 이 릴리스에서 하지 않았다. 다시 열 사람에게 필요한 사실은 이 세 가지다:
  창의 상한(900초) · 여는 조건(mandate 무시) · 대가(그 문서에 한해 Layer 1 정지).
- 발견은 훅의 cwd 리포만 본다. 다른 체크아웃의 문서는 `git status` 에 나오지 않는다 — 그
  워크트리에서 세션을 열면 커버된다.
- git 이 없거나 리포가 아니면 검증·dispatch 가 일어나지 않고 세션당 1회 loud advisory 가 나간다.
- **이 설계에는 cross-family 리뷰가 없었다.** 설계 리뷰 5라운드가 전부 Claude 단독이었다
  (codex 사용 한도가 2026-09-17 까지 소진). 어떤 종류의 공유-맹점이 남아 있는지 아무도 모른다.
- **선재 RED 면제 1건** (이 릴리스가 만든 것이 아니고, 이 릴리스가 고치지도 않는다):
  `tests/test_hook_output_schema.py::TestCrossResolverAdvisory.test_python_and_bash_resolvers_agree`
  는 **워크트리 안에서만** 돈다(`@unittest.skipUnless`)  — 그리고 워크트리 안에서는 구조적으로
  항상 실패한다. `scripts/state_path.py` 의 python 해석기는 `git rev-parse --git-common-dir` 로
  **메인 리포**의 `.claude/spec-distill` 을 가리키는 반면, 테스트가 비교하는 bash 식은
  `${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill` 로 워크트리 경로를 그대로 쓴다. 그 클래스의
  docstring 이 이미 «NG9 … the follow-up unification PR is needed» 라고 적어 둔 기지의 미해결
  항목이고, 두 훅의 output schema 와는 무관하다(나머지 21개는 통과). 면제 사유를 여기 적는
  이유: 이유 없는 면제 목록은 그 질문을 영구히 닫는다.

## [0.35.3] — 2026-08-25

### Added
- `tests/test_merge_review_adjudication.py` — degrade 사유가 **`advisory` 채널로**
  나가는지 잠그는 단언 3건. 계수(`adjudication_held`)와 사유는 다른 채널이라
  계수만 단언하면 사유 채널을 통째로 끊어도 GREEN 이었다 — 실제로 `advisory.extend`
  를 지우고 옛 키를 되살렸을 때 전 스위트가 통과했다. 주(主) 입력 실패 케이스는
  `held` 가 0이라 `advisory` 가 **유일한 신호**이고, 그 자리를 계측기로 삼는다.
  양성 짝(아무것도 안 버린 실행에는 사유가 없다)을 함께 건다.

## [0.35.2] — 2026-08-25

### Changed
- `scripts/merge_review.py` — 처분 원장의 degrade 사유를 `adjudication_reasons:` 대신
  `advisory` 리스트로 보낸다. `skills/reviewing-spec/SKILL.md`의 "그대로 표시"·"degrade
  없음" 판정은 `advisory` 에만 걸려 있어서, `load_history` 실패는 표시 규칙 없는 키로
  가고 그 짝 `_write_history` 실패는 `advisory` 로 가는 비대칭이 표시 층에 남아 있었다
  (설계 §7 #3 이 결함으로 지목한 바로 그 비대칭). 형제 `merge_brief_review.py:325-328`
  과 같은 선택. 사유는 이제 `emit()` 의 `_yaml_scalar` escape 를 탄다.
- `skills/reviewing-spec/SKILL.md` — 파싱 키 열거를 실제 stdout 과 맞추고, degrade 사유가
  `advisory:` 로 온다는 것과 `adjudication_held`/`adjudication_unknown` 이 degrade 의
  유일한 신호가 될 수 없다는 것을 명시.

### Removed
- `scripts/merge_review.py` stdout 의 `adjudication_reasons:` 키. `[0.35.0]` 에서 추가돼
  같은 브랜치 안에서만 존재했고 `main` 에 배포된 적이 없다 — deprecation window 대상 아님.
  `adjudication_held`/`adjudication_unknown` 두 계수 키는 그대로다.

## [0.35.1] — 2026-08-23

### Added
- dispatch 자리(7곳)에 처분 앵커 — `**처분** — consumer=… · fail-… [· disclosure=…]`. `shared/tests/test_dispatch_disposition.sh` 축 A①②③④·B·C 가 집행한다.

## [0.35.0] — 2026-08-23

새 표면 3개(minor) — `merge_review.py` stdout에 subagent 발견의 처분 회계 채널을 얹는다.

### Added
- `scripts/merge_review.py` stdout에 `adjudication_held` / `adjudication_unknown` /
  `adjudication_reasons` 세 키 추가 — 판정(verdict)과 별개 채널로 처분 회계(수용/보류/
  입력실패/원리적 미상/강제)를 싣는다. `skills/reviewing-spec/SKILL.md`가 이 세 키를
  orchestrator가 파싱하는 stdout 키 목록에 나열.

### Fixed
- `scripts/merge_review.py`의 회계 결함 6건: ⑴ claude sentinel의 non-dict 원소를 조용히
  버리던 것을 `hold()`로 계수. ⑵ sentinel 부재·JSONDecodeError·payload 형태 불일치 세 경로를
  「0건」이 아니라 원리적 미상(`uncountable`)으로 구별 — issues 리스트가 아직 만들어지지
  않은 지점이라 개수를 알 방법이 없다. ⑶ YAML 마커 위반으로 폐기된 codex finding 개수를
  `reason` 문자열에 인코딩하지 않고(파일이 공급하는 `meta.reason:`과 충돌해 `int()` 크래시
  가능) out-of-band 4번째 반환값으로 보고. ⑷ `load_history()`가 원장 전체 손실
  (OSError/JSONDecodeError/비-list)과 id 없는 레코드를 침묵하지 않고 `source_failed`/`hold`로
  계수 — 짝 `_write_history`는 실패 시 advisory를 내는데 이쪽만 침묵하던 비대칭을 해소. ⑸
  `raised_count` 강제 변환(문자열→0)이 `>=3` 정체 게이트를 무력화하는데도 미보고이던 것을
  `gate=True` 강제로 기록. ⑹ category·target_section이 둘 다 빈 codex finding이 원장에도
  회계에도 안 잡히던 것을 `hold()`로 계수. 더불어 hold() 사유 문자열을 `str()`로 담으면
  summary 안의 개행이 stdout에 두 번째 `combined_verdict:` 줄을 주입할 수 있던 경로를
  `repr()` + `_yaml_scalar` escape로 닫았다(verdict-injection).

### Changed
- `scripts/merge_brief_review.py`를 shared `Ledger`(`scripts/adjudication.py` 심볼릭 링크)로
  전환 — critic 축의 비-dict 원소(findings로 승격 못 하는 **소실** → `hold()`)와 필수 필드가
  나빠도 그대로 싣는 §9.1 fail-open 데이터 경로(소실 아님 → `accept()`)를 서로 다른 Ledger
  어휘로 구별해 회계한다. codex 축의 malformed 개수도 `merge_review.py`와 같은 관례로
  `hold()`. 새 top-level 출력 키 없음 — 회계는 이미 escape되는 기존 `advisory` 채널에 얹는다.
  외부 출력 8개 키와 verdict 경로(`escalates`/`codex_degraded`가 평가하는 표현식) 무변경.

### Known gaps
- `merge_review.py`의 mixed-round 경로(`codex_failed: true`인 라운드에 findings가 이미
  파싱돼 있는 경우)는 여전히 그 codex finding **자체**를 원장에서 폐기한다 — 이번 수정으로
  폐기된 개수는 `adjudication_held`로 계수되지만, finding의 내용(category/severity/summary
  등)은 복원되지 않는다. `merge_brief_review.py`(brief 경로)는 이미 findings를 보존한 채
  degrade 마커를 함께 낸다 — 남은 격차는 공유 경로(`merge_review.py`, design-doc 리뷰) 한 곳.

## [0.34.0] — 2026-08-23

### Added
- `scripts/adjudication.py` — `shared/adjudication/adjudication.py` 정본을 가리키는 상대 심볼릭 링크. subagent 발견의 처분 회계(`수용·기각·보류` + 흡수·강제·입력실패·원리적 미상). 리포 최초의 import-only `.py` 심볼릭 링크.
## [0.33.1] — 2026-08-23

`run_spec_codex_reviewer.sh` 가 `CLAUDE_PLUGIN_ROOT` 를 기본값 없이 참조해,
스킬의 bash 블록에서 호출되면 `set -u` 아래에서 **codex 에 도달하기 전에** 죽던
결함을 고친다. `reviewing-spec` 의 codex co-review 는 그 경로에서 한 번도 실행되지
않았고, 산출물은 매번 `aborted_before_completion` 이었다 — 실패는 loud 했지만
모델 다양성은 상시 0이었다.

**Fixed**
- `scripts/run_spec_codex_reviewer.sh`: 형제 `run_brief_codex_reviewer.sh` 와 같은
  `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"`
  를 추가하고 내부 참조 2곳을 `${PLUGIN_ROOT}` 로 통일(우회 경로 0).

**Added**
- `tests/test_run_spec_codex_reviewer.sh`: FALLBACK 회귀 락 — 환경변수를 지우고
  mock codex 를 태워 `codex_failed: false` + finding 산출을 요구한다. "exit 0 +
  YAML 존재"로는 고장난 러너도 통과하므로(degrade 계약이 그렇게 설계돼 있다)
  결과를 잰다. mutation 3축(fallback 삭제 · 경로 파손 · 참조 1곳 되돌림) 전부 RED 확인.
- `shared/tests/abort_trigger.sh`(신규 공용 모듈)를 사용하도록 ABORT 블록 전환.

**Changed**
- ABORT 계약 검증의 트리거를 환경변수 제거에서 **SIGTERM** 으로 교체. fallback 이
  생기면서 예전 트리거는 더 이상 중단을 일으키지 않아, 그대로 두면 assertion 이
  abort 경로를 한 번도 밟지 않은 채 GREEN 이 된다(2026-08-23 실측). 판정도
  `codex_failed: true` 에서 `reason: aborted_before_completion` 으로 좁혔다.

## [0.33.0] — 2026-08-22

interview brief 의 **분량 상한을 제거**한다. 절별 `≤N줄` 예산도, 150줄 트립와이어도,
그 지표를 계산하던 코드도 없다.

**Removed**
- `templates/interview-brief-template.md` 의 절별 분량 예산 7개 — §0 `≤15줄` · §1
  `≤12줄` · §2 `≤30줄` · §3 `≤25줄` · §4 `≤20줄` · §5 `≤25줄` · §7 `≤10줄`(합 137).
- `scripts/check_brief.py` 의 `LINE_TRIPWIRE = 150` 상수, advisory 분기,
  `payload_body_lines_excl_verbatim()` 함수, `gate` JSON 의 동명 키, 그리고
  `metrics` 서브커맨드. `metrics` 는 이제 unknown subcommand 로 rc 64.
- `tests/test_check_brief.sh` 의 "Task 5: 분량 지표" 블록과 그 블록만 쓰던 픽스처 4개
  (`interview-brief-over-budget.{md,audit.md}` · `interview-brief-long-verbatim.{md,audit.md}`).

**왜** — 상한의 원래 목적은 "짧게 써라"가 아니라 *"brief 가 해답을 미리 정해버리지
않게"* 였다(`2026-07-25-spec-distill-brief-format-producer-design.md` §5.3 + 같은
문서 Implicit context: superpowers 6.2.0 이 `Key Principles` 에서 *"Explore
alternatives"* 줄을 지워 하류 탐색 지시가 약해졌으므로 brief 의 과잉결정이 더
해롭다). 줄 수는 그 목적의 **대리 지표**인데 대상을 안 잰다 — 길이 ≠ 과잉결정이고,
오히려 §3 Open Questions(과잉결정의 정반대 절)를 성실히 채운 brief 가 예산을 태워
벌을 받는 방향으로 틀렸다. 실측으로도 오발했다: 2026-08-16 인터뷰에서 본문 153줄·
166줄로 두 번 발화했다
(`docs/superpowers/interview/2026-08-16-devbrew-weight-reduction-interview.audit.md:131,201`).

과잉결정은 이제 대리 지표가 아니라 **직접 측정기**가 본다 — `brief-readback` 이 묻는
두 번째 질문이 *"무엇이 확정이고 무엇이 아직 열려 있는가"* 다. 그 리뷰어 3종은
v0.24.0 에 생겼고 137/150 은 그 앞 버전 v0.23.0 의 산물이라, 대리 지표가 먼저 있었고
직접 측정기가 나중에 왔다. 게이트 코드 스스로도 *"분량은 목표이지 정확성 조건이
아니다"* 라고 적어 두고 있었다 — 결정론적 검사의 자리가 아니었다는 뜻이다.

하류에 기계적 한계는 없다: brief 는 `codex exec -`(stdin)로 들어가고 blob·프롬프트
빌더 어디에도 크기 상한이나 잘림이 없다.

**Changed**
- 숫자가 대리하던 계약은 **문장으로 남겼다.** §0 머리에 *"이 절은 요약이다 — 본문을
  여기 옮겨 적는 자리가 아니라, 다음 세션이 여기만 읽고도 방향을 잡을 수 있어야 하는
  자리다"*. §2 의 *"한 줄이 frontmatter 한 항목의 렌더다"*(bijection B)와 §4 의
  *"1항목 = 1줄"* 은 분량이 아니라 렌더 계약이라 그대로 둔다. `≤N줄` 이 이 문장들과
  **같은 괄호 안에** 있었으므로 괄호째 지웠다면 계약도 함께 사라졌을 것이다.
- `advisories` 채널 자체는 유지. `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 킬 스위치가 같은
  채널로 강등을 알리며, 그것은 분량과 무관한 graceful degradation 통보다.

**Added**
- `tests/test_brief_no_length_cap.sh` — 4층 회귀 락. **부재 검사만으로 된 락은 대상
  파일을 통째로 지워도 통과하므로** 층 1(양성 대조: 템플릿 8섹션 헤더 + `gate()` 존재)이
  "이 락이 실제로 그 코퍼스를 읽었다"를 먼저 증명한다. 층 2 는 보존 계약 3개를 **섹션
  윈도우 안에서** 본다(파일 전체 grep 이면 주석이나 다른 절이 대신 만족시킨다). 층 3 은
  개념 별칭(`최대 N줄` · `N줄 이내`)까지 덮는다 — 식별자만 잠그면 같은 것을 다른
  이름으로 부른 재삽입이 살아남는다. 층 4 는 grep 이 아니라 실제 호출로 gate JSON 키
  부재와 `metrics` rc 64 를 잰다.
- 기존 Task 5 블록을 "고치지" 않고 걷어낸 이유도 같다 — 트립와이어가 없는 지금 거기
  부정 assertion 만 남기면 무엇을 지워도 통과하는 빈 락이 된다.

## [0.32.7] — 2026-08-22

`tests/test_run_spec_codex_reviewer.sh` 의 FAKE_ROOT 를 **설치본 모양**으로 깐다.

**Fixed**
- FIX1 시나리오의 FAKE_ROOT 는 빌더 하나만 심볼릭 링크하고 형제
  `codex_prompt_common.py` 를 안 깔았다. 그런데도 통과했다 — CPython 은 링크된
  스크립트의 `sys.path[0]` 을 realpath 로 잡으므로(3.9.6 실측) 링크된 빌더가 형제를
  **정본 옆**에서 찾아냈다. 통과하지만 **설치본의 모양을 재고 있지 않았다**(감사 §7-9).
- 이제 빌더·`codex_prompt_common.py`·`prompt-preamble.md` 를 모두 **물리 사본**으로
  깐다(설치 시 링크가 역참조되는 실제 배포 모양). 실측: 형제 모듈을 빼면
  `ModuleNotFoundError`, 프리앰블을 빼면 로더가 **FAKE_ROOT 안의 경로**를 못 찾아
  실패한다 — 두 형제가 실제로 load-bearing 이 됐다는 증거다(수정 전에는 형제가
  아예 없어도 GREEN 이었다).

**Added**
- FAKE_ROOT/scripts 에 심볼릭 링크가 0개인지, 파일이 셋 다 깔렸는지 단언하는 회귀 락.
  다시 `ln -s` 로 돌아가면 realpath 우회가 되살아나고 사본이 dead weight 가 되는데,
  그 상태는 조용하다(시나리오는 계속 통과한다). 그래서 모양 자체를 잰다.

**동작 무변경** — 테스트 하니스만 바뀌었고 shipping 코드는 그대로다.

## [0.32.6] — 2026-08-22

`scripts/codex_prompt_common.py` 의 〔앵커 주의〕 주석 블록을 **제거**한다.

**Changed**
- `scripts/codex_prompt_common.py` — `scripts/prompt-preamble.md` 리터럴이
  `test_copy_of_contract.sh` 축 1a 의 도출 앵커라고 경고하던 주석 4줄을 삭제.
- **v0.32.5 의 "이 리터럴은 앵커다" 항목은 이제 유효하지 않다.** 그 축은 배포
  지점을 구조(인덱스∪워킹트리에 실재하는 `plugins/*/scripts/<파일>`)에서 도출하고
  산문은 거기에 더하기만 한다 — 빼지 못한다(감사 §7-8 해소). 실측: 같은 리터럴을
  다시 걷어내도 도출은 3건 그대로이고 락은 GREEN 이다(v0.32.5 때는 3→2 로 줄며 RED).

**동작 무변경** — 주석만 지웠고 실행 경로는 그대로다.

## [0.32.5] — 2026-08-22

Task 35 Step 0 — P21 프리앰블 로더 4벌을 `shared/codex/codex_prompt_common.py` 정본으로
통합. shipping 동작 무변경(네 빌더가 내는 프롬프트 바이트 동일 — 실측).

**Added**
- **`scripts/codex_prompt_common.py`** — `shared/codex/codex_prompt_common.py` 의 물리
  사본(`# copy-of:` 마커). 심볼릭 링크로 배포하지 않는 이유와 축 1c 의 ∀ 계약은
  quality-gates CHANGELOG `[4.1.10]` 과 같다(같은 정본의 두 배포 지점).
- **`shared/tests/test_no_new_duplication.sh`** — 새 중복의 **유입**을 막는 락(20줄 이상
  완전히 같은 블록이 `copy-of` 로 설명되지 않으면 RED). 위 통합 대상을 적발한 스캐너라
  같은 릴리스에 기록한다. `# guards: plugins/** shared/**` 로 다섯 플러그인 전체를
  지키며, `[0.32.4]` 의 귀속 관례에 따라 이 릴리스가 노트를 쓴 두 플러그인 엔트리에 함께
  적는다. 계약·면제 술어·vacuous 가드(단위별 등식)의 상세는 quality-gates CHANGELOG `[4.1.10]`
  과 같다(같은 파일, 두 기록 자리).

**Changed**
- **`scripts/build_spec_codex_prompt.py` · `scripts/build_brief_codex_prompt.py`** — stdout
  인코딩 가드와 P21(신뢰불가 입력 프리앰블) 로더를 형제 사본에서 import 한다.
  `build_brief_codex_prompt.py` 는 20줄 스캐너가 적발한 3쌍에 **들어 있지 않았다** —
  같은 블록을 갖고 있지만 중간에 무관한 주석(`AXES` + §6 근거)이 끼어 20줄 연속이 끊겼기
  때문이다. 크기 임계 아래에 숨은 같은 보안 컨트롤 사본이므로 함께 통합했다.
- **`scripts/codex_prompt_common.py` 의 `scripts/prompt-preamble.md` 리터럴은 앵커다** —
  `test_copy_of_contract.sh` 축 1a 의 참조원 도출이 이 문자열로 배포 지점 플러그인을
  고른다. 통합 초안이 빌더에서 그 리터럴을 걷어냈을 때 spec-distill 이 도출 3건→2건으로
  조용히 이탈했고(실측 RED), 정본 주석에 리터럴과 경고를 함께 넣어 복구했다.

## [0.32.4] — 2026-08-21

Task 33 fix round 5 (마지막). 한 항목 — fix round 4 가 만든 **단일 실패 지점**에 짝을 붙인다.

**귀속**: 새 파일 둘은 `shared/tests/` 에 있어 어느 플러그인 소유도 아니다. 이 리포의
선례(`shared/tests/test_skill_reference_pointers.sh` 를 Task 31 이 quality-gates 엔트리로,
Task 33 이 spec-distill 엔트리로 적은 것)를 따라 **그 이빨을 쓰는 락이 사는 플러그인**에
귀속한다 — 세 소비자가 전부 spec-distill 이므로 여기다.

**Added**
- **`shared/tests/test_presence_corpus_behavior.sh`** (14 단언) — `presence_corpus.sh` 의
  **행동**을 고정한다. fix round 4 가 24줄 중복을 지우면서 세 락의 이빨을 헬퍼 한 파일로
  모았고, 그 한 곳이 조용히 무력화되면 **세 락이 동시에** 이빨을 잃는다. 헬퍼는 라이브러리라
  `# guards:` 도 `--emit-scanned` 도 없다 — `assert.sh` 와 같은 상황이고 이 리포는 그것을
  `test_assert_behavior.sh` 로 답했다. 이 파일이 그 짝이며 같은 관례를 따른다(자체
  `t_ok`/`t_no` 카운터 · 픽스처 probe · rc 로 판정 관측 · `--emit-scanned` 응답).
  - **(1) 분류기 판정** — 소유 두 모양 통과(양의 짝) · **플러그인 레벨 공유 계약 거절**
    (대상은 열거 아닌 `git ls-files` 도출 + 도출 0건이면 loud FAIL) · 혼합 코퍼스는
    한 건만 소유 밖이어도 실패 · `plugins/` 밖 경로 거절.
  - **(2) 세 소비자를 실제로 돌려** 헬퍼 판정 줄이 나오는지와 코퍼스 크기(구조적 하한 2)를
    읽는다. 소비자의 GREEN/RED 자체는 보지 않는다 — 다른 이유로 RED 인 소비자와 묶지 않기 위해.
  - **(3) 채택자 락의 격리 불변식**을 **산술**로 잰다: Σ(채택자별 자기-파일 수) = 전체
    코퍼스 크기. 루프가 합집합을 넘기면 Σ = 채택자수 × 전체 가 되어 어긋난다.
  - (2)·(3)은 fix round 4 에서 **한 번 손으로 돌린 통제**다 — 매 실행마다 돌게 옮겼다.

**Fixed**
- **`presence_corpus.sh` 가 빈 코퍼스를 조용히 통과시켰다.** `own=0 foreign=0` 에 `ok` 를
  냈다〔실측: `rc=0`, *"presence 대상 0개가 전부 skill 소유 표면"*〕. 소비자의 도출이 깨져
  0건이 되면 그 스위트의 존재 검사가 **전부 vacuous** 해지는데 이 가드가 그 위에 초록을
  찍는다 — 세 락이 동시에 이빨을 잃는 바로 그 경로이고, 헬퍼가 그것을 감춰 준다.
  이제 시끄럽게 실패한다. 이 결함은 **행동 락을 쓰다가** 드러났다.

**Docs**
- `test_skill_reference_pointers.sh` 주석에 **자기 보증 금지가 막지 못하는 것**을 적었다:
  identity 만 막고 A→B/B→A **상호 보증**은 막지 않는다. skill 레벨은 소유 SKILL.md 를
  계속 요구하므로 이 구멍은 **플러그인 레벨 파일이 둘 이상**이어야 열린다(오늘 1개).
  둘째를 추가하는 사람이 서 있을 자리에 뒀다.

**양성 통제 4종** (전부 리포 원래 경로에서, 기대 방향으로 떨어진 것만으로는 증거가 아님)
- 분류기 반전(플러그인 레벨을 소유로) → 거절·혼합 두 단언 RED.
- 빈-코퍼스 수리 되돌리기 → vacuity 단언만 RED.
- 헬퍼의 판정 줄 제거 → (2) 섹션 4건 RED(세 소비자 전부 + 하한).
- 채택자 루프 격리 파괴 → (3) 산술 RED(**합 6 ≠ 전체 3** = 채택자 2 × 파일 3).
- 복원 → 14/14 GREEN, 두 파일 해시 일치.

## [0.32.3] — 2026-08-21

Task 33 fix round 4 (PR5 출하 전 마지막). 전-브랜치 seam 리뷰 = **merge 안전**.
이 라운드는 그 리뷰가 지목한 **브랜치가 만든 seam 결함 둘**을 닫는다.

**Fixed**
- **포인터 락이 자기 유일한 실사례를 안 보고 있었다 (seam).** Task 31 이 그 락을 쓸 때
  `references/*.md` 는 **잎**이었다 — 가리켜지기만 했다. Task 33 이 그 전제를 깼다:
  `conducting-interview` 는 공유 계약을 자기 SKILL.md 가 아니라 `references/finishing.md`
  에서 가리킨다. 정방향 코퍼스는 `SKILL.md` 뿐이라 **그 포인터를 한 번도 열지 않았다.**
  같은 브랜치의 `test_proceed_gate_adopters.sh` 는 반대로 그 자리를 **의도적으로** 포인터
  출처로 인정한다 — 두 락이 서로 모순인 채 출하됐다.
  - 정방향 fail-open: 세 번째 skill 이 자기 `references/*.md` 에서만, 오타로 가리키면
    포인터 락은 침묵(파일을 안 연다)하고 채택자 락도 침묵(오타라 채택자로 안 세어 ≥2 하한
    유지)한다. 런타임에 없는 경로를 Read 하고 공유 계약이 조용히 사라진다.
    〔차분〕 `finishing.md` 에 오타 포인터 주입 → **c8e6869 GREEN / 이번 RED**.
  - 역방향 false-RED: 플러그인 레벨 정본을 SKILL.md 포인터 **하나**가 지탱해, 그쪽 표기가
    바뀌면 `finishing.md` 가 여전히 가리키는데 "고아"가 된다.
    〔차분〕 그 상황 구성 → **c8e6869 RED(거짓 고아) / 이번 GREEN**.
  - 수리: 정방향 출처를 **SKILL.md ∪ 모든 references/*.md** 로 넓혔다. 넓힌 대가로 생기는
    유일한 새 구멍(어떤 파일이 출처이자 대상)은 **자기 보증 금지**로 막는다 — 자기 자신을
    가리키는 포인터는 소유 증거로 기록하지 않고 loud FAIL 한다(mutation 실증).
    `plugin_root` 도출도 두 모양 다 맞게 일반화했다(`${x%/skills/*}` 는 플러그인 레벨
    출처에서 경로 전체를 돌려준다).
- **중복 제거가 산출물인 태스크가 24줄 바이트-동일 중복을 만들었다.** `d7356ea` 가
  `test_brief_review_entry.sh` 와 `test_conducting_interview_stage.sh` 에 같은 가드 블록을
  복제했고, 한 라운드 뒤 "통과 시 침묵" 결함을 **양쪽에 따로** 고쳐야 했다.
  `copy-of` 마커는 **전체 파일** 사본을 다루는 메커니즘이라 조각에는 맞지 않는다 —
  그래서 마킹이 아니라 **추출**했다: `shared/tests/presence_corpus.sh` 의
  `assert_presence_corpus_skill_owned`. 세 소비자(위 둘 + `test_proceed_gate_adopters.sh`
  의 모양 가드)가 한 벌을 공유한다. 〔통제〕 헬퍼의 `ok` 를 지우면 **세 소비자 전부** 단언
  −1, 소유 패턴을 깨뜨리면 **세 소비자 전부** RED — 사본이 아니라 실제로 그것을 쓴다.

**Docs**
- 감사문서 §6 표: **「면역(도출)」이 판정이 아니라 그날의 관측**임을 경고로 못 박고
  **「측정 시점」열**을 추가했다. 두 행(`test_reviewing_spec_design_only.sh` ·
  `test_brief_review_meta.sh`)이 「면역」으로 적혀 있었지만 실제로는 **열거된 `grep -r` 루트**
  였고 Task 33 이 둘 다 손수리했다 — §3 이 "absence 만 수리 대상"이라 말하므로 낡은
  「면역」칸은 다음 사람에게 **건너뛰라고 지시한다.** 상속-대신-도출을 막으려 쓴 문서가
  정확히 그 상속을 부르는 열을 갖고 있었다. 이 브랜치가 만든 독자
  (`test_proceed_gate_adopters.sh`)와 라이브러리(`reconstruct-skill.sh`)도 표에 넣었다.
- 감사문서 §7-6: 거부 표면을 **전수 프로브로 재측정**했다. 앞 판본이 적은 "외부 URL 인용"만이
  아니라 **포인터 의도가 있는 표기 둘**(`./references/x.md` · 백틱 없는 표 셀)도 거부된다 —
  즉 "인용을 포인터로 오해한다"가 아니라 "인식 형태 열거가 좁다"가 옳은 서술이고, 앞 판본이
  유일한 처방으로 적은 "URL 스킴 배제"는 그 두 행을 못 덮는다. 표로 적고 선택지를 넷으로 넓혔다.
- 감사문서 **§7-7** 신설: 계약의 **요약본**(`spec-distill/README.md` · `CLAUDE.md`)이
  자제(自制)만으로 지켜진다. §8 이 기록한 *"자제 규칙은 지켜지지 않는다"* 가 그대로 적용되며
  근거는 이 태스크 자신의 초고다. 발동 조건 + 왜 지금 술어를 만들지 않는지 + 가장 그럴듯한
  좁은 술어를 적었다.

## [0.32.2] — 2026-08-21

Task 33 fix round 3 (마지막). 스코프 재리뷰는 **모든 지적 반영 / load-bearing 신규 없음**
이었고, 남은 다섯은 전부 문서 정합 또는 한 줄 위생이다. 하나는 계측기 결함이었다.

**Fixed**
- **정본이 자기 측정자 인벤토리를 낡은 채로 뒀다.** round 2 가 세 번째 측정 스캔
  (`test_proceed_gate_adopters.sh`)을 추가하고 「검증」 1항에서 이름까지 댔으면서,
  「앵커는 각 skill 에」 절은 여전히 **"두 측정 스캔"** 을 열거하고 "두 테스트 / 두 presence
  검사 / 두 락" 으로 이어갔다. `reviewing-spec/SKILL.md` 도 같은 문장을 안고 있었다.
  **F1 의 결함이 F1 의 수리 안에서 재발한 것** — 부정확한 자기 서술이 하필 진짜 위험이
  있는 자리에 서 있다. 규칙을 **개수 없는 한 문장**("이 계약의 앵커를 재는 스캔은 전부
  코퍼스를 그 skill 소유 표면으로 한정한다")으로 바꾸고 목록은 예시로 격하했다 — 넷째가
  생겨도 고칠 필요가 없다.
- **정본이 자기 앵커 리터럴을 하나 적게 셌다.** "위 Step B 표의 ① 행과 가드 2 본문"이라
  적었으나 실측 3줄(**25 · 60 · 78**)이고 78 은 그 문단이 설명하는 「검증」 절 안이다.
  목록을 고치되 **개수를 세지 말라**는 지시를 함께 넣었다 — 그 수는 안전과 무관하고
  (안전은 코퍼스 경계가 지탱한다) 이 목록이 정확히 유지된다는 보장이 없다(실제로 낡았다).
- **[0.32.1] 의 P5 통제 수치 정정.** *"정본에서 4줄을 세어 만족"* 이라 적었다. 재측정하면
  **3줄**(+ `polite stop` 5줄)이다. 〔경위〕 그 4 는 측정 시점(`d7356ea`)에는 **맞았다** —
  round 2 자신이 「검증」 1항을 다시 쓰면서 `다음 턴` 이 줄바꿈 경계에 걸려 4→3 이 됐다.
  즉 전사(轉寫) 오류가 아니라 **내 편집이 내 측정을 낡게 만든** 경우다. 그래도 지금은
  틀린 수이므로 정정하고, 이빨을 증명하는 통제 행이라 재측정으로 갈음했다.
- **round 1 의 F1 가드 둘이 통과 시 침묵했다.** `test_conducting_interview_stage.sh` ·
  `test_brief_review_entry.sh` 의 가드는 `*)` 분기에서만 `no` 를 불렀다. 〔실측〕 가드를
  통째로 제거해도 단언 수·출력이 **완전히 동일**(92/36 → 92/36) — 감사문서 「계측기」 절이
  기록한 *"아무것도 안 하면서 GREEN"* 클래스다. round 2 의 같은 가드는 통과 시 `ok` 를
  낸다. 둘을 거기에 맞췄고, 이제 가드를 제거하면 93→92 · 37→36 으로 **관측된다**.

**Added**
- **채택자마다 `degrade 채널` 절의 존재를 잰다.** 정본 Step B 의 의무 중 **라벨**
  (이름 붙은 절이 있는가)은 채널 *형태*를 건드리지 않고 한 줄로 잴 수 있다 —
  `grep -cF 'degrade 채널'`. 계약이 두려워한 실패(새 채택자가 "해당 없음"으로 넘김)를
  정확히 그것이 잡는다. 통제: 한쪽 절 삭제 → 그 채택자만 RED(다른 쪽 GREEN) · 양쪽 삭제 →
  RED 2 (정본이 같은 라벨을 2줄 담고 있으나 **코퍼스 밖이라 구제하지 못한다**).

**Docs**
- 감사문서 §7-5 를 **형태 검증**으로 좁혔다. 앞 판본은 "의무 전체가 기계화 불가"라 적었는데
  그 사유(형태가 skill 마다 다르다)는 형태에만 해당했다 — **연기의 사유가 연기의 범위보다
  좁으면 그 차이만큼 공짜로 미뤄진다**는 교훈을 항목에 적었다.
- 감사문서 **§7-6** 신설: 포인터 락의 접두사 거부가 **리포 전역**이고 산문이 방아쇠라,
  미래 SKILL.md 가 포인터 의도 없이 `…/references/*.md` 를 담은 외부 URL 을 인용만 해도
  공유 락이 RED 가 된다. 발동 조건 + 선택지 셋(가장 좁은 것은 URL 스킴 배제).
- `test_proceed_gate_adopters.sh` 주석: 채택자 하한은 **개수이지 구성원이 아니다**
  (오늘 치환이 RED 인 것은 대체 후보에 앵커가 없어서인 **우연**) · 도출은 리터럴 등장을
  셀 뿐이라 HTML 주석·예시 언급도 채택자로 등록된다(거짓 RED, fail-closed).
- `test_brief_review_entry.sh` 의 `CI_FILES` 정의부(:20)에 가드로 가는 포인터 한 줄 —
  가드와 그 근거가 110줄 아래에 있어, 넓히려는 사람이 서는 자리에서는 안 보였다.
- `test_conducting_interview_stage.sh` 의 §8/§9 잔존 검사 옆에 주의 한 줄: `CI_ALL` 에 든
  공유 계약은 **다른 문서의** 절 번호를 인용할 수 있고 이 검사는 그것을 payload 좌표와
  구별하지 못한다(실측: 감사문서 `§8` 인용 하나로 발화 — 이번 라운드에 실제로 밟았다).
  공유 계약에서는 절을 번호가 아니라 제목으로 인용하는 것이 회피책이다.

## [0.32.1] — 2026-08-21

Task 33 fix round 2 — 한 항목. `proceed-gate.md` 와 `reviewing-spec/SKILL.md` 가 **존재하지
않는 락을 인용**하고 있었다.

**Fixed**
- **`reviewing-spec` 표면의 기계적 앵커를 아무도 재지 않았다.** 정본 「검증」 절은
  *"**각 skill 표면에** 정지 어휘가 실재하는지를 grep 이 잰다"* 고 적고,
  `reviewing-spec/SKILL.md` 의 AC19 불릿은 *"기계적 검증 앵커가 사는 곳이 거기다"* 라고
  한 걸음 더 나간다. 〔실측〕 `턴 종료|다음 턴` 을 재는 단언은 리포 전체에 둘뿐이고
  (`test_conducting_interview_stage.sh` 의 `ci_cat` · `test_brief_review_entry.sh` 의
  `CI_FILES`) **둘 다 conducting-interview 표면만 본다.** 계약을 통일해 놓고 이행 검증은
  한쪽에만 있었다 — 삭제된 규칙이 아니라 **처음부터 없던 규칙을 인용하는** 형태다.
  주장을 약화하는 대신 **참으로 만들었다**: 두 게이트를 같은 방식으로 잰다.

**Added**
- **`tests/test_proceed_gate_adopters.sh`** — 공통 계약의 **채택자 대칭** 락.
  채택자를 열거하지 않고 **정본을 가리키는 포인터에서 도출**하고(세 번째 skill 이 채택하면
  자동으로 같은 요구를 받는다), 채택자마다 **자기 표면**에서 가드 2 기계적 앵커(정지 어휘)와
  가드 1 앵커(polite stop)를 잰다. 기존 `reviewing-spec` 테스트에 끼워 넣지 않은 이유는
  그러면 같은 검사가 두 벌 독립 저술되고 스코프 규칙이 갈라지기 때문이다 — **이 결함을 만든
  바로 그 구조**다.
  - **F1 위험이 여기에도 그대로 적용된다**: 정본은 앵커 리터럴을 계약 어휘로 담고 있어,
    코퍼스에 들어오면 채택 skill 이 문구를 다 잃어도 GREEN 이 된다. 〔실증〕 정본을 코퍼스에
    넣고 구조적 가드를 뺀 변형에서 `reviewing-spec` 의 정지 어휘·polite stop 을 통째로
    지워도 **GREEN**(정본에서 4줄을 세어 만족) / 스코프 복원 시 **RED 2건**.
    그래서 코퍼스는 채택자 소유 표면으로만 구성하고, 구조적 가드 두 개(모양 검사 + 정본
    이름 검사)로 그 편집을 막는다.
  - **채택자 하한이 1 이 아니라 2 인 이유**: 이 파일이 플러그인 레벨에 사는 근거가 "두 skill 이
    공유한다"이다. 1 로 떨어지면 정상 상태가 아니라 **한쪽이 조용히 이탈**한 것이고, 이탈한
    skill 은 그 순간 측정 밖으로 나간다 — 코퍼스 축소가 vacuity(≥1)를 통과하는 바로 그 모양.
    숫자를 박은 것이 아니라 **파일의 배치 근거**에서 도출한 하한이다.
  - 양성 통제 7종: 단언 7건이 실제로 실행·계수됨(도달성) · `reviewing-spec` 정지 어휘만 제거
    → 그 줄만 RED, interview 는 GREEN(채택자별 스코프 실증) · polite stop 만 제거 → 가드 1 만
    RED · 포인터 제거 → 채택자 1 → 하한 RED · 위 fail-open 차분 · 복원 GREEN + 해시 일치.

**Docs**
- 정본 「검증」 1항이 **재는 주체를 이름으로** 댄다(주장에서 확인 가능한 사실로).
- 감사문서 §7-5 신설 — 공유 계약의 **degrade 채널 의무**는 아직 산문일 뿐이고, 기계화는
  **세 번째 채택자**가 나와야 형태가 생긴다. 발동 조건과 "오늘 만들지 않는 이유"를 적었다.
- 포인터 락 주석에 리졸버 form ②(`plugins/<p>/…`)가 오늘 **살아 있는 인스턴스 0** 이고
  합성 케이스로만 검증됐음을 기록(코퍼스가 아니라 갈래이므로 vacuity 대상 아님).

## [0.32.0] — 2026-08-21

Task 33 fix round 1. 리뷰 판정은 **Spec PASS / Quality FAIL** 이었고, 결함은 리팩터가
만들어 낸 **산문 계약** 쪽에 몰려 있었다 — 엔지니어링(1:1 접두사 리졸버 · presence/absence
코퍼스 분리 · 여섯 코퍼스 수리 · 격리 설치 실측)은 독립 재도출로 유지됐다.

**Added**
- **정본이 각 skill 에 `degrade 채널`의 이름을 요구한다 (F2).** [0.31.0] 의 정본은
  *"모든 degrade record 를 출력하고 없으면 `degrade 없음`"* 을 계약으로 적었는데, 그 문장은
  `conducting-interview` 의 메커니즘(`brief_review_degradations` 원장)을 계약으로 승격시킨
  것이었다. `reviewing-spec` 에는 그런 원장이 없다 — `merge_review` 플래그와 파싱-시점
  `advisory:` 줄이 있을 뿐이고 게이트 템플릿에는 degrade 슬롯조차 없었다. 그래서 Phase 5 는
  `codex_degraded: true` 인 라운드에도 `degrade 없음` 을 내거나(사용자에게 리뷰 커버리지에
  대한 거짓 진술) 방금 따르라고 지시받은 계약을 무시하거나 둘 중 하나였다.
  정본은 이제 **채널-중립**으로 의무만 정하고(감추지 않는다), 각 skill 이 자기 채널을 이름으로
  대게 한다. 채널이 없다는 사실 자체가 degrade 이며, 채널을 대지 않은 채 "없음"을 내는 것은
  금지다. `reviewing-spec` 은 실제 채널(`codex_degraded`·`claude_degraded`·
  `claude_verdict_unrecoverable` + `advisory:`)을 명시하고 게이트 `question` 에 degrade
  슬롯을 얻었다. `conducting-interview` 는 `brief_review_degradations` 원장을 이름으로 댄다.
- **presence 코퍼스 구조적 가드 (F1).** `test_conducting_interview_stage.sh` ·
  `test_brief_review_entry.sh` 에 "`CI_FILES` 에 이 skill 소유가 아닌 파일이 들어오면 즉시
  FAIL" 을 넣었다. 〔실측〕 가드 없이 `CI_FILES` 를 `plugins/spec-distill/references/*.md` 까지
  넓힌 상태에서 `finishing.md` 의 옵션 ① 정지 어휘와 `polite stop` 을 통째로 지워도 두 락이
  **GREEN** 이었다. 그 편집은 그럴듯하다 — [0.31.0] 이 네 개의 *부재* 코퍼스에 정확히 같은
  편집을 했기 때문이다. 주석이 아니라 가드여야 하는 이유가 그것이다.
- **스캔 루트 실재 단언 (F4).** `test_brief_review_meta.sh` · `test_reviewing_spec_design_only.sh`
  는 `grep -r` 루트에 문자열을 덧붙이기만 했다. 오타·개명이면 *No such file* 이 `2>/dev/null`
  에 삼켜지고 부재 단언은 좁아진 코퍼스 위에서 통과한다. 〔차분 실측〕 공유 계약 디렉터리를
  치운 상태에서 **[0.31.0] 판본 GREEN / 이번 판본 RED**.

**Changed**
- **정본의 「검증」 절이 참인 이유를 다시 적었다 (F1).** [0.31.0] 은 *"이 파일은 앵커의 사본을
  두지 않는다"* 고 적었으나 **거짓**이었다 — `grep -cE '턴 종료|다음 턴'` = 4 (Step B 표 ① 행 +
  가드 2 본문). 그 리터럴은 계약의 어휘라 뺄 수 없고, 빼려고 계약을 약하게 쓰는 것이 더 나쁘다.
  진짜 보호는 자제가 아니라 **코퍼스 경계**(두 측정 스캔이 skill 소유 표면으로 한정)이며,
  틀린 이유를 적어두면 진짜 위험 경로를 가린다. 이제 그 경계와 위 구조적 가드를 명시한다.
- **`reviewing-spec` 의 "Step C" 지시대상 모호성 제거 (F3).** 이 SKILL 에는 `### Step C —
  응답 처리` 가 이미 있는데 [0.31.0] 이 정본의 `## Step C — 두 가드` 를 인접한 두 불릿에서
  같은 짧은 이름으로 인용했다. 기계적 앵커를 찾는 사람이 정본으로 가서 거기서 리터럴을 보고
  "공유 앵커"라 결론지어 이 SKILL 의 문구를 지우는 경로가 열린다. 두 인용을 완전한 이름으로
  적고, 앵커가 사는 곳이 어디인지 명시했다.
- `finishing.md` B-2 의 *"reviewing-spec Phase 5 Step A와 대칭으로"* 를 정본 `## Step A`
  인용으로 교체 (F8) — 60줄 위에서 은퇴시킨 skill-대-skill 대칭 모델을 그 문장이 되살리고 있었다.

**Fixed**
- **[0.31.0] 엔트리의 수 정정 (F7).** "부재 락 **4건**"이라 적고 **다섯**을 나열했다. 옳은 수는
  **6** 이다(여섯째 `quality-gates/tests/test_law2_prose.sh` 는 그 플러그인 CHANGELOG 에 있다).
- **[0.31.0] 엔트리의 성격 규정 정정 (F7).** "전부 `skills/*/references/` 까지만 도출하고 있었다"
  는 **둘에 대해 거짓**이다: `test_brief_review_meta.sh` 는 `grep -rnE … "$SD/scripts" "$SD/skills"`
  였고 `test_reviewing_spec_design_only.sh` 는 `references/` 글롭이 아예 없는 전-트리 재귀
  루트였다. 공통점은 글롭의 모양이 아니라 **`skills/` 밖을 못 봤다**는 것이다.
- **포인터 락: 역방향이 접미사로 소유를 판정하던 것 (F5).** 정방향만 as-written 으로 조이고
  역방향은 `sed 's|.*/\(references/\)|\1|'` 로 접미사를 잘라 비교했다. 그래서
  `${CLAUDE_PLUGIN_ROOT}/references/notes.md` 포인터가 `skills/<s>/references/notes.md` 의
  소유 증거로도 인정됐다 — 동명 파일이 양쪽에 있으면 skill 레벨 파일이 **아무도 안 가리키는데도**
  고아로 안 잡힌다. 이제 정방향이 만든 `(SKILL.md, 해석된 대상)` **쌍**을 그대로 되쓴다.
  〔차분 실측〕 그 상황을 구성해 **[0.31.0] 판본 GREEN / 이번 판본 RED**.
- **포인터 락: 인식 못 하는 접두사가 거부가 아니라 절단됐다 (F6).** 접두사를 열거해 골라 받는
  정규식은 열거 밖 형태에서 실패한 뒤 문자열 **중간**의 맨몸 `references/…` 에서 매치를 시작해,
  그 표기를 조용히 "스킬 디렉터리 상대"로 재해석했다 — 헤더와 설계 노트가 "폴백 없음"이라
  주장하는 자리에 **절단형 폴백**이 있었다. 토큰을 통째로 삼키는 클래스로 잡은 뒤 형태를
  판정하고, 세 형태 중 어느 것도 아니면 loud FAIL 한다. 〔차분 실측〕 중괄호 없는
  `$CLAUDE_PLUGIN_ROOT/references/x.md` + 동명 skill 레벨 파일 → **[0.31.0] 판본 GREEN
  (조용한 재해석) / 이번 판본 RED**. 인식하는 세 형태와 `**볼드**` 표기는 거짓 거부 없음(11/11).

**Docs**
- `docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md` 에 §8 신설(공유 참조 파일 —
  처방을 거꾸로 적용하지 않기), §7-3 해소 기록, §7-4 신규 이월 항목
  (`quality-gates/tests/test_no_secret_prompts.py` 의 한 칸 위 맹점), §6 재도출 실측(21+1) 추가.

## [0.31.0] — 2026-08-21

Task 33 — `/compact` proceed 게이트 **두 벌의 공통 골격을 한 파일로**. 사용자 요청
*"저장소 전반의 `/compact` 방식을 점검하고 일관된 형태로 통일해"* 의 마지막 축이다.

**Added**
- **`references/proceed-gate.md` (플러그인 레벨, 71줄).** `reviewing-spec` Phase 5 와
  `conducting-interview` 종료 Step B 가 공유하는 **골격 · 두 가드 · 예외 경로**의 정본.
  두 skill 이 공유하므로 어느 skill 밑에도 두지 않았다 — 이 리포의 첫
  `plugins/<p>/references/` 파일이다.
  〔격리 설치 실측〕 이 모양이 실제로 배포되는지 재봤다(`CLAUDE_CONFIG_DIR=<tmp>` 로
  사용자 `~/.claude` 격리 증명 후 `plugin marketplace add` + `plugin install`).
  설치본 `…/spec-distill/0.31.0/references/proceed-gate.md` 로 **그대로 실린다** —
  `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 포인터가 설치본에서 resolve 된다.
  플러그인 루트의 새 디렉터리가 설치에서 누락될 가능성은 측정으로 배제됐다.

**Changed**
- **두 게이트가 자기 어휘만 인라인으로 남긴다.** 각 skill 에 남은 것: 정본을 가리키는
  `Read` 포인터 · 자기 어휘의 `AskUserQuestion` 옵션 라벨 · verbatim `/compact` 템플릿 ·
  skill 고유 스텝(interview 의 B-0 확정 후보·재제시 상한, reviewing-spec 의 `spec_path`
  선검증·AC8 경계). 옵션 ① 의 정지 문구(`턴 종료`·`다음 턴`)는 **각 skill 에 그대로 남는다**
  — 기계적 검증 앵커가 거기 살고, 정본이 그 리터럴을 복사하면 자기 인용이 락을 먹는다.
- `conducting-interview/references/finishing.md` 의 Step B 머리에서 *"같은 두 가드를
  interview 어휘로 **독립 저술**합니다"* 를 삭제 — 더 이상 참이 아니다.
- **`tests/test_conducting_interview_stage.sh` 의 코퍼스를 presence/absence 로 분리.**
  `CI_FILES`(이 skill 자신의 표면)는 **존재** 검사용, `CI_ALL`(+ 플러그인 레벨 정본)은
  **부재** 검사용. 공유 파일을 존재 검사에 넣으면 "이 skill 이 자기 어휘를 잃었다"를
  공유 파일이 대신 만족시킨다(§4 거울 클래스).

**Fixed**
- **부재 락 4건이 플러그인 레벨 `references/` 를 못 보고 조용히 약해지는 것을 차단.**
  전부 `skills/*/references/` 까지만 도출하고 있었다 — 한 칸 위는 밖이었다. 금지 토큰을
  정본 파일에 주입해 **수정 전 GREEN(fail-open 실증) / 수정본 RED** 차분으로 각각 실증했다:
  `tests/test_no_wall_clock.sh`(`wall_clock_started_at`) ·
  `tests/test_web_kill_switch.sh`(`SWEEP_CAP`) ·
  `tests/test_conducting_interview_stage.sh`(`breadth-keeper`) ·
  `tests/test_brief_review_meta.sh`(E10 스캔 루트) ·
  `tests/test_reviewing_spec_design_only.sh`(F9-D 스캔 루트, `drafting-spec`).
  합집합 vacuity 만으로는 부족하다 — 플러그인 레벨 글롭이 깨져도 `skills/` 쪽 도출로
  통과하기 때문에, **디렉터리가 있는데 도출이 0이면** 따로 loud FAIL 한다(기대값
  하드코딩 없이 디렉터리 실재라는 독립 신호에서 도출).

**Docs**
- `README.md` AP2 항목이 두 가드를 **세 번째로 저술**하고 있었다 — 정본 포인터를 달고
  "아래는 요약이지 별개 저술이 아니다"를 명시. v0.13.0 항목에도 통합 사실을 덧붙였다.

## [0.30.1] — 2026-08-21

Task 32 fix round 1 — 전부 **문서**다. 코드·락 동작은 무변경(리뷰가 Spec PASS /
Quality PASS 로 엔지니어링을 독립 재도출로 확인).

**Fixed**
- **[0.30.0] 엔트리의 overclaim 정정 (F2).** 두 스위트의 섹션 윈도우가 똑같이 위치
  무관해졌다고 적었으나 사실이 아니다. `test_brief_review_entry.sh` 만 그렇고
  (`scoped_window()` 가 `"${CI_FILES[@]}"` 위에서 돈다),
  `test_conducting_interview_stage.sh` 의 다섯 창은 `$FIN` 하드코딩이다. 결과는
  조용한 구멍이 아니라 시끄러운 false-RED 지만, 산문이 코드보다 강한 주장을 하고
  있었다. 해당 엔트리를 파일·처방별로 갈라 다시 적었다.
- **[0.30.0] **Fixed** 헤딩의 undercount 정정 (F3).** "부재 락 3건"으로 읽히지만
  실제는 **4파일 / 10단언**이다(네 번째가 `test_conducting_interview_stage.sh` 의 7건,
  같은 파일의 windowed 수리와 묶여 **Changed** 에 있었다).
- **독자 열거 수 정정 (F1).** 보고서가 12로 적은 것은 **15 + 비독자 1**이 옳다.
  누락된 넷은 전부 부재 클래스이지만 코퍼스를 `grep -r`·`find` 로 **도출**하므로
  새 참조 파일을 자동으로 삼킨다 — 오늘 동작상 결과는 없다:
  `quality-gates/tests/test_governance_no_capability_caps.sh` ·
  `tests/test_reviewing_spec_design_only.sh` · `tests/test_brief_review_meta.sh` ·
  `quality-gates/tests/test_codex_runner_no_effort_pin.sh`.
  반대로 `shared/tests/test_changelog_integrity.sh` 는 **독자가 아니다**(`SKILL.md` 를
  한 번도 읽지 않는다 — `plugin.json` + `CHANGELOG.md` 만 본다). 버전영향이지
  코퍼스영향이 아니다.
  그중 `test_governance_no_capability_caps.sh` 는 구조적으로 중요하다 — [0.30.0] 이
  "아무도 고려하지 않은 클래스"로 지목한 **플러그인 경계를 넘는 repo-wide 부재 스캔**의
  **두 번째** 인스턴스다. 그 면역은 분석의 결과가 아니라 **구성의 운**이었다.

**Added**
- `docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md` (+ `docs/audits/README.md`
  인덱스 줄) — 이 실패 클래스의 **영구 기록**. 앞선 보고서는 `.superpowers/` 아래
  git-ignored 라 커밋되지 않아 미래 세션이 **읽을 수 없다**; 아무도 열지 못하는 파일의
  숫자를 고치는 것은 아무것도 고치지 않는다. 문서가 담는 것: 실패 클래스 · 독자 열거
  6 도달 경로(`.py`·플러그인 경계 포함) · 면역 조건(도출 vs 열거) · 포인터가 presence
  락을 header-satisfiable 하게 만드는 **거울 클래스** · 차분 실증의 계측기 위생 2함정 ·
  이월 미해결 3건.
  `docs/` 와 `docs/audits/` 는 **어느 플러그인에도 속하지 않는다** — 이 bump 를
  촉발한 것은 그 문서가 아니라 위 **Fixed** 의 `plugins/spec-distill/CHANGELOG.md`
  산문 수정이다. 감사 문서 자체는 무-플러그인 자산으로 이 엔트리에 귀속만 시킨다.

**Notes**
- [0.30.0] 의 "순수 예방적"이라는 자기평가는 **과소 주장**이었다. `test_law2_prose.sh`
  수리가 새로 덮는 코퍼스는 이번 분할분 232줄이 아니라 Task 31 산출물
  (`runtime-gate.md` 1,189 + `state-file-format.md` 78)을 더한 **1,499줄**이고, 그
  전량이 clean 하다(28/28). 참인 주장은 더 강하다 — **새로 덮인 코퍼스 전체에서**
  어떤 수리된 락도 잡을 것이 없었다.
- 측정 정정 2건(둘 다 결론 불변): `GUARD_WINDOW` 가드 줄 목록에서 **330** 이 빠져
  있었다(여전히 < 341, 짝짓기는 `g ≤ d` 만 보므로 무영향). 줄번호 검사 지점은 "정확히
  두 곳"이 아니라 **셋**이다 — `test_brief_review_entry.sh:172` 의
  `n5="$(wc -l <<<"$WA5")"; [[ "$n5" -le 30 ]]` 가 창 크기를 재는 줄-거리 검사다.
  Step A.5 는 분할 전 395–424 로 이동 구간에 통째로 들어 있어 창이 온전히 따라갔고
  현재 28 ≤ 30 으로 GREEN. Ruling 67 의 "재조립 불필요" 결론은 그대로다.

## [0.30.0] — 2026-08-21

Task 32(무게 감축): `conducting-interview` SKILL.md의 `## 종료 — brief 작성 + optional
handoff` 절차 전문(232줄, 분할 전 파일(614줄)의 37.8%)을
`skills/conducting-interview/references/finishing.md`로 분리했다. SKILL.md에는 같은
`## 종료` 헤딩 아래 포인터 산문만 남는다 — floor 5차원이 전부 `closed`가 되어 brief
작성으로 넘어갈 때만 그 파일을 Read 하고, 인터뷰가 진행 중인 동안은 읽지 않는다(조건부
로드). 이 파일에는 목차도 내부 `](#anchor)` 링크도 없어 깨질 앵커가 없다.
on-demand 로드 표면(SKILL·agent·command 전량)은 이 분리로 5,406줄 → 5,188줄
(Δ −218)로 줄었다.

**Added**
- `skills/conducting-interview/references/finishing.md` — 종료 절차 전문(Step A ·
  Step A.5 · Step B B-0…B-4). 분할 전 SKILL.md에서 **바이트 그대로** 이동했고 내용
  변경은 없다(재조립 후 원본과 diff 0줄 — 의도적으로 SKILL.md에 남긴 구분용 빈 줄
  하나 제외).

**Fixed**
- **분할로 조용히 약해진 부재 락 — 4파일 / 10단언.** (아래 3건 + **Changed** 의
  `test_conducting_interview_stage.sh` 7단언. 그 7건은 같은 실패 클래스이지만 같은
  파일의 windowed 수리와 한 덩어리라 Changed 에 적었다.) 부재 락("이 문자열이 나타나면 안 된다")은
  코퍼스가 줄어도 RED가 되지 않고 **조용히 약해진다** — Task 31이 이 방식으로 P21
  secret 스캔의 범위를 잃었다. 세 락 모두 분리 직후 GREEN이었고, 금지 문자열을
  `finishing.md`에 주입해 **수정본 RED / 수정 전 GREEN**의 차분으로 fail-open을
  실증한 뒤 고쳤다. 세 곳 다 열거가 아니라 **도출**(`references/*.md` 글롭)로
  고쳐 새 참조 파일이 생기면 자동으로 대상이 되게 했고, 도출 0건이면 loud FAIL
  하는 vacuity 단언을 함께 넣었다.
  - `tests/test_no_wall_clock.sh` — 순수 전-파일 부재 락. 하드코딩된 3-파일 배열이라
    분리분을 못 봤다. 하필 종료 절차가 "얼마나 걸렸나"를 다시 재고 싶어지는 가장
    그럴듯한 자리다. 실측: 주입 후 수정 전 9/9 GREEN → 수정본 2건 RED.
  - `tests/test_web_kill_switch.sh` — 두 부재 검사(느슨한 참 판정 · 상한 게이트
    재도입)가 `dispatch_lines` 없으면 `continue`로 빠지는 자리에 있어, dispatch가
    없는 분리분은 영영 검사되지 않았다. 부재 검사를 `continue` **위로** 끌어올려
    표면 전량에서 돌게 했다. 실측: 주입 후 수정 전 32/32 GREEN → 수정본 2건 RED.
  - `plugins/quality-gates/tests/test_law2_prose.sh` — `find plugins/*/skills -name
    'SKILL.md'` 코퍼스라 **모든** 플러그인의 `references/*.md`를 못 봤다. Task 31이
    만든 `runtime-gate.md`(1,189줄) **와** `state-file-format.md`(78줄) 둘 다 이미 이 락
    밖에 있었으므로 그 잔여 구멍도 함께 닫힌다 — 수리 후 AC16-1 에 새 파일 줄이 3건
    (두 quality-gates 참조 + `finishing.md`) 늘어난 것으로 확인된다.
    실측: 주입 후 수정 전 24/24 GREEN → 수정본 4건 RED.

**Changed**
- 두 스위트의 **전-파일 검사**(존재·부재 양쪽)는 스킬 표면(SKILL.md + `references/*.md`)을
  하나로 보도록 코퍼스를 도출로 바꿨다. `test_conducting_interview_stage.sh`의 부재 7건은
  주입 차분으로 이빨을 확인했다(수정 전 7/7 GREEN → 수정본 7/7 RED).
- **섹션 윈도우의 처방은 두 파일이 다르다** — 앞선 판본의 이 항목은 둘 다 위치
  무관해졌다고 적었으나 사실이 아니다:
  - `tests/test_brief_review_entry.sh` — `scoped_window()`가 `"${CI_FILES[@]}"` 위에서
    돌아 **위치 무관**이다. `### Step A.5`·`#### B-2`가 어느 파일에 있든 창이 잡힌다.
  - `tests/test_conducting_interview_stage.sh` — 다섯 창(`#### B-0`…`#### B-3` · `## 종료`,
    `:57 :72 :92 :113 :208`)은 **`$FIN` 하드코딩**이다. 나중에 `#### B-2`가 제3의 파일로
    옮겨가면 `b2_block`이 비어 그 assert들이 RED가 된다. 다만 `[[ -f "$FIN" ]]`(`:24`)와
    `[[ -n "$b2_block" ]]` 빈-창 가드가 있어 **조용한 구멍이 아니라 시끄러운 false-RED**이고,
    수리는 창 소스 한 줄 교체다. 위치 무관화는 이 사이클 범위 밖으로 남긴다.

**Notes**
- **재조립 헬퍼(`reconstruct-skill.sh`)를 쓰지 않았다 — 측정 결과 필요 없었다.**
  Task 31이 그 헬퍼를 만든 이유는 두 테스트가 섹션 경계를 가로질러 **줄 번호로**
  순서·거리를 쟀기 때문이다. 이 스킬의 소비자 전량을 훑어 그런 검사를 찾았고,
  줄 번호 산술은 두 곳뿐이었다: `test_web_kill_switch.sh`의 dispatch↔kill switch
  근접 검사(`GUARD_WINDOW=40`)는 dispatch 254·269·320행을 가드 245·302·311행과
  짝지어 **전부 경계(341행) 아래**에 있고, `test_check_verbatim_coverage.sh`의
  `sed -n "${P21_LINES},+3p"`는 첫 `REDACTED`(63행) 기준이라 63–66행에 머문다.
  경계를 가로지르는 쌍이 0건이므로 재조립은 불필요하고, 근-중복 66줄 파일을
  새로 만들지 않았다.

## [0.29.0] — 2026-08-20 (BREAKING)

Task 25(무게 감축): 환경변수 어순을 `DEVBREW_<PLUGIN>_<REST>` 하나로 통일. 이
플러그인이 소유한 kill switch·설정 변수:

| 옛 이름 | 새 이름 |
|---|---|
| `DEVBREW_DISABLE_SPEC_DISTILL` | `DEVBREW_SPEC_DISTILL_DISABLE` |
| `DEVBREW_DISABLE_SPEC_DISTILL_CODEX` | `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` |
| `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW` | `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW` |
| `DEVBREW_RHYTHM_GUARD_THRESHOLD` (플러그인 토큰 없던 패턴 D) | `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` |

이미 `DEVBREW_SPEC_DISTILL_*` 어순을 쓰던 변수(`DISABLE_WEB`·`DESIGN_MODE_DISABLE`·
`TTL_HOURS`·`PROBE_CAP` 등)는 무변경. `shared/killswitch/kill_switch_active.py`
정본(과 이 플러그인의 `scripts/kill_switch_active.py` 물리 사본)의 전역 스위치
**도출식** 자체도 `DEVBREW_DISABLE_<PLUGIN>` → `DEVBREW_<PLUGIN>_DISABLE`로 바뀌었다
— 리터럴 문자열 치환으로는 안 잡히는 자리였다(태스크 실행 중 burn-test로 실측:
`test_kill_switches_v060.sh` case 1–4가 이 도출식 미수정 상태에서 RED였다).

### Deprecated
- 환경변수 어순을 `DEVBREW_<PLUGIN>_<REST>` 하나로 통일. 옛 이름(`DEVBREW_DISABLE_SPEC_DISTILL_CODEX` 등)은
  **fallback 없이 즉시 제거**됐다. 근거: 현재 제3자 설치가 없다 (CLAUDE.md §메타데이터의
  one-minor deprecation window 와의 충돌을 그 조건 아래 수용). **제3자 설치가 생기면 이 근거가
  바뀐다** — 그때는 다음 rename 에 fallback 창을 둔다.

### Changed (devbrew weight-reduction Task 29)
- **`reviewing-brief` SKILL의 헤딩을 `## kill switch (먼저 확인)`에서
  `## kill switch`로 줄였다.** "먼저 확인"은 순서 계약(이 skill의 어떤
  dispatch보다도 먼저 평가한다)이었으므로 삭제하지 않고 본문 첫 줄 문장으로
  내렸다 — 헤딩만 보고 넘어가면 그 계약이 사라지므로.

### Fixed (devbrew weight-reduction Task 30)
- **`hooks/spec-write-validator.py:137`에 `encoding="utf-8"` 명시.** 나머지
  `write_text` 호출(255·276번 줄)은 조사 결과 이미 `encoding="utf-8"`을 다음
  줄에 갖고 있었다 — 같은 줄만 보는 grep이 오탐한 자리였다(quality-gates
  Task 30 CHANGELOG의 axis 2 참조).

## [0.28.0] — 2026-08-17

Task 17(무게 감축) + fix round 1: `scripts/codex_findings_to_yaml.py`가 물리 사본에서 `shared/codex/
codex_findings_to_yaml.py`를 가리키는 상대 심볼릭 링크로 바뀌었다(quality-gates와
공유하는 정본). emit keyset(`category`·`target_section` — design-doc 리뷰 어휘)은
더 이상 사본 하드코딩이 아니라 정본의 새 `--emit-keys design` 인자다. patch가 아니라
**minor**인 이유(S3): 이전에는 이 플러그인의 codex 소비 경로가 design keyset을
암묵적으로 항상 받았지만, 이제는 호출자(`run_brief_codex_reviewer.sh`·
`run_spec_codex_reviewer.sh`)가 명시적으로 요청해야 한다 — 잊으면 `category`/
`target_section`이 조용히 빠진다(같은 파일 경로로 새 configurability 노출, detect_codex.sh
선례와 같은 판단 기준).

Task 19(무게 감축): kill switch 판정 12정의를 `shared/killswitch/kill_switch_active.py`
정본으로 통합. 이 플러그인이 그중 5곳(훅 4 + `scripts/spec-distill-gc.py`)을 갖고 있었다.

Task 22(무게 감축): **같은 플러그인 안의** 중복을 `scripts/hook_common.py` 하나로 접었다.
`shared/` 정본과 달리 플러그인-로컬이라 `copy-of` 마커도 사본 동일성 검사도 붙지 않는다 —
같은 플러그인 안에서는 import 하나로 중복 자체가 소멸한다(설계 §6.1③). 두 훅
(`review-dispatch.py` ↔ `pending-review-reminder.py`)의 최장 공유 구간이 **24줄 → 11줄**
로 내려갔다(20줄 창 5개 → 0개). `_yaml_scalar` 는 **행동이 바뀐다** — 아래 Fixed 참조.

### Added
- `scripts/hook_common.py` — 두 훅이 공유하던 조각의 단일 정의:
  `configure_utf8_streams()` · `PENDING_RE` · `LAST_DISPATCHED_RE` · `GC_SCRIPT` ·
  `fire_and_forget_gc()` · `parse_iso()` · `state_file_for()` · `_yaml_scalar()`.
  `kill_switch_active`(Task 19의 `shared/` 정본)와 `resolve_session_id`/`state_root`
  (`state_path.py` 소유)는 담지 않는다 — 가져오면 정본이 둘이 된다.
- `tests/test_yaml_scalar_single_definition.py` — 정의가 하나이고(구조 스캔), 소비자
  셋이 **같은 함수 객체**를 부르며(텍스트가 아니라 identity 로 잰다), 그 하나가
  합집합 행동을 갖는지. 각 단언은 세 사본 중 적어도 하나가 갖지 못했던 성질이라,
  어느 옛 본문으로 되돌려도 하나는 RED 가 된다. `float` 분기는 단언하지 않는다 —
  없어도 `str(v)` 경로가 같은 값을 내 어떤 입력으로도 구분되지 않는다(이빨 없는 단언).
- `tests/test_yaml_scalar_single_definition.py` `TestCanonicalAgreesWithSharedCodex`
  — 이 플러그인의 `_yaml_scalar` 와 `shared/codex/` 정본이 **같은 입력을 인용하는지**.
  케이스 목록(내가 떠올린 값)과 상수 자체 비교(내가 안 떠올린 문자) 두 겹으로 잰다.
  인용 표기(`ensure_ascii`)는 다를 수 있으므로 `json.loads` 로 되돌린 뒤 비교한다.
  위치 축의 **음의 짝**(`codex-reviewer`·`fail-safe` 처럼 첫 글자가 아닌 지시자는
  bare 로 남는다)도 같이 잰다 — 없으면 "전부 인용" 으로 도망갈 수 있다.
- `tests/test_codex_findings_to_yaml.py` `TestSummaryScalarRoundTrip` — 정본
  스크립트를 실제로 태워 산출 YAML 을 **파싱해서 원문과 정확히 같은지** 잰다.
  텍스트 겹(인용됐는가)과 왕복 겹(되돌아오는가)을 갈라 둬서, PyYAML 이 없는 환경에서도
  텍스트 겹은 이빨을 유지한다.

### Changed
- `review-dispatch.py`·`pending-review-reminder.py` 가 UTF-8 프리앰블·`PENDING_RE`·
  `LAST_DISPATCHED_RE`·`GC_SCRIPT`·GC fire-and-forget 블록·`parse_iso` 자체 정의를
  버리고 `hook_common` 에서 import 한다. `pending-review-reminder.py` 는 인라인으로
  조립하던 상태 파일 경로도 `state_file_for()` 로 바꿨다(같은 표현식의 세 번째 사본).
- `scripts/arm_ledger.py` 의 `state_file_for` 정의를 지우고 `hook_common` 에서 import.
  `arm_ledger.state_file_for` 로 부르는 소비자(`spec-write-validator.py`)는 그대로다.
  그 docstring("저장소 위치 변경 시 이 한 곳만 갱신")이 두 번째 정의 때문에 거짓이었는데
  이제 다시 참이다(census #122).
- `merge_review.py`·`merge_brief_review.py`·`brief_review_state.py` 가 각자의
  `_yaml_scalar` 정의를 버리고 `hook_common` 에서 import(census #45의 spec-distill 부분).
- `tests/test_arm_ledger.py` 의 착지점 계산이 `arm_ledger.state_root()`(소유하지 않는
  이름의 re-export)가 아니라 `state_path.state_root()` 를 직접 쓴다. 피검자의 경로 조립
  함수를 쓰지 않는 것은 의도적이다 — 그 함수의 버그가 traversal 테스트를 눈멀게 한다.

### Fixed
- **`_yaml_scalar` 세 사본이 갈라져 있었다** — 빈 문자열 가드가 `merge_review` 에만
  없었고, flow indicator(`[]{}`) escape 가 `brief_review_state` 에만 있었고, None 분기가
  `brief_review_state` 에만 없었다. 합집합으로 접었다(더 인용하는 것은 파싱 결과를 바꾸지
  않고, 덜 인용하는 것만 바꾼다). 그래서 **출력이 바뀌는 자리가 있다**: `[` 로 시작하고
  `:` 를 갖지 않는 advisory 문구가 이제 따옴표로 감싸여 나간다. 이관 전에는 인용 없이 나가
  YAML flow sequence 로 읽혔다 — 두 merge 스크립트의 advisory 리터럴 **5건**이 이 모양이었다
  (예: "[spec-distill v0.20.0] review indeterminate …", "[spec-distill v0.24.0] critic
  sentinel 블록 …"). 빈 문자열과 None 쪽은 현재 소비자 경로로는 도달하지 않는다.
- **정본(`shared/codex/codex_findings_to_yaml.py`)의 `_yaml_scalar` 도 같은 술어로
  맞췄다** (2026-08-19). 사본 셋을 합집합으로 접는 동안 그 사본들이 모여야 할 정본은
  옛 술어를 그대로 갖고 있었다 — 통합이 뒤집혀 있던 셈이다. 실측(정본 종단):
  `summary` 가 `[` 로 시작하면(`"[CRITICAL] …"` — 리뷰어가 흔히 쓰는 모양) 인용 없이
  나가 **문서 전체가 ParserError** 로 죽었고, 소비자
  (`merge_review.parse_codex_yaml`)는 그 파일을 읽지 못해 그 라운드의 findings 가
  통째로 소실됐다. 빈 문자열은 `null` 로, `{` 로 시작하는 값은 매핑으로 읽혔다.
- **위치 축(`_YAML_UNSAFE_FIRST`)을 새로 넣었다 — 합집합에도 없던 잔여 구멍이다.**
  세 사본의 합집합은 **문자 멤버십** 하나뿐이라, block sequence 지시자로 시작하는 값
  (`- dash`)이나 backtick 으로 시작하는 값(``"`handler()` 가 null 을 반환한다"``)은
  여전히 인용 없이 나가 ScannerError 를 냈다. 첫 글자를 0x20–0x7E 전수로 돌려
  `k: <값>` 을 파싱하는 방식으로 위험 집합을 **측정해서** 얻었고, 그중 기존 검사가
  덮지 못하는 잔여를 상수로 뒀다. 정본과 이 파일이 같은 두 상수를 쓴다.
- **표기(`ensure_ascii`)까지 같아졌다** — 정본만 기본값(True)이라 인용된 한국어가
  `\uXXXX` 로 나갔고, 인용 술어를 넓히면서 그 노출이 늘어 정본을 `False` 로 맞췄다.
  이제 두 `_yaml_scalar` 의 출력은 **바이트로 동일**하고,
  `TestCanonicalAgreesWithSharedCodex` 가 여부·표기 둘 다 락으로 고정한다.

### Added
- `scripts/kill_switch_active.py` — `shared/killswitch/kill_switch_active.py` 의
  `# copy-of:` 물리 사본. 설치본에는 `shared/` 가 없으므로 형제 사본이어야 import 가 풀린다.
- **`DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc`** — `scripts/spec-distill-gc.py` 만
  끈다. 이관 전 이 파일은 `DEVBREW_SKIP_HOOKS` 를 **아예 읽지 않았다** — 사용자가 그 변수로
  껐다고 믿어도 GC 는 계속 돌았다(이관 전 HEAD 판본을 실제로 태워 확인). 훅이 아니지만
  지목할 이름을 갖는 쪽이 더 잘 꺼지는 방향이라 회귀가 아니다.
- `hooks/session-end-cleanup.py` 가 훅명 별칭 `spec-distill:session-end-cleanup` 도 받는다
  (이관 전에는 이벤트명 `spec-distill:SessionEnd` 하나뿐이었다).

### Changed
- 훅 4종(`review-dispatch.py`·`pending-review-reminder.py`·`spec-write-validator.py`·
  `session-end-cleanup.py`)과 `scripts/spec-distill-gc.py` 에서 자체 판정 정의
  (`kill_switch_active()` 3 + `_disabled()` 2)를 지우고 정본 호출로 교체. 기존 토큰
  (`:Stop`/`:review-dispatch` · `:UserPromptSubmit`/`:reminder` · `:PostToolUse`/`:validator` ·
  `:SessionEnd`)과 전역 `DEVBREW_DISABLE_SPEC_DISTILL=1` 의 동작은 전부 불변이다.
- `run_brief_codex_reviewer.sh`·`run_spec_codex_reviewer.sh` 두 호출 모두
  `--emit-keys design`을 명시(행동 불변 — 이전 하드코딩과 동치).
- `extract_last_agent_message`(codex JSONL 이벤트 파서)를 `shared/codex/
  codex_jsonl.py` 정본으로 흡수. `codex_findings_to_yaml.py`가 여기서 import한다
  (quality-gates·plugin-audit 세 사본이 있던 것 중 이 플러그인 몫).
- `tests/test_codex_findings_to_yaml.py`의 design-keyset 단언 2건이 이제
  `--emit-keys design`을 명시적으로 넘긴다(스크립트 기본값이 바뀌었으므로).

### Fixed (2026-08-17 fix round 1)
- **codex 리뷰어가 설치본에서 100% 죽는 결함(CRIT-1).** 정본의 `codex_jsonl` import가
  `.resolve()`를 써서, `claude plugin install`이 서브트리를 벗어나는 심볼릭 링크를
  실제 파일로 역참조하는 설치본(설계 §16.1)에서 sibling `codex_jsonl.py`를 못 찾고
  `ImportError`가 났다. `.resolve()`를 버리고(bare `.parent`) `codex_jsonl.py`의
  copy-of 물리 사본을 `plugins/spec-distill/scripts/`에도 배포했다(quality-gates·
  plugin-audit과 동일 패턴).
- `run_brief_codex_reviewer.sh`가 `--emit-keys design`을 잃어도 어떤 테스트도
  빨개지지 않던 결함(F1) — `tests/test_brief_codex_axes.sh`에 `run_spec_codex_reviewer.sh`
  쪽과 대칭인 assertion + mutation 증명을 추가했다.
- 공백 가드의 방향 정정(F2) — "공백-only를 거른다"가 아니라 "뒤따르는 빈 후보가
  앞선 유효한 메시지를 덮어쓰지 못하게 한다"이며, 이 플러그인이 이전에 배포하던
  것 대비 fail-open 방향의 판정 변경이다(뒤이어 빈 `agent_message`가 흐르면
  `codex_failed`가 `true → false`로 뒤집히고 finding이 살아난다). 새 테스트
  `test_codex_findings_to_yaml.py::test_trailing_blank_agent_message_does_not_clobber_real_one`가
  고정한다.
- "행동 불변" 프레이밍 정정(F8) — 정본화 이전에는 `agent_message.text`가
  문자열이 아니면 크래시(rc=1)했다. 지금은 `codex_jsonl.py`의 타입 가드가 크래시
  없이 rc=0 + `reason: missing_result`로 degrade한다 — 개선이지만 사유 문자열이
  바뀐다.

### Fixed (2026-08-17 fix round 2)
- **F1 mutation 이 플래그 줄에 도달조차 못 하던 결함(R2-5·R2-6).**
  `tests/test_brief_codex_axes.sh` 의 mutation 은 러너 사본을 temp dir 에서 돌리는데
  `CLAUDE_PLUGIN_ROOT` 를 넘기지 않아 `PLUGIN_ROOT` 유도가 어긋났고, 프롬프트 빌더를
  못 찾아 `reason: prompt_build_failed` 로 조기 종료했다 — 그런데도 락은 "이빨 있음"
  을 출력했다(**플래그와 무관한 실패를 플래그 증거로 보고**). 형제 락
  `test_run_spec_codex_reviewer.sh` 처럼 `CLAUDE_PLUGIN_ROOT` 를 명시로 넘기고,
  ① **identity 사본**(플래그 그대로 위치만 이동) 통제와 ② 변이본이 조기 degrade
  없이 변환까지 갔는지 확인하는 원인-확정 단언을 더했다. 양방향 증명: identity
  사본(플래그 온전)에서는 **계측기 줄이 GREEN** 이고 락이 "이빨 있음"을 거짓으로
  내지 않는다 — 그 거짓을 막는 것은 **mutation 줄이 RED 로 가는 것**이다(실측:
  40 중 1 RED, 계측기 줄과 원인-확정 줄은 둘 다 GREEN). 실제 플래그 제거에서는
  "이빨 있음"을 낸다. 계측기 줄이 RED 로 가는 경우는 계측기 자체(`F1ENV` 의
  `CLAUDE_PLUGIN_ROOT`)가 깨졌을 때다(실측: 40 중 2 RED). 〔2026-08-17 fix round 3,
  R3-5 — 앞 판본은 identity 일 때 "계측기 RED" 라 적어 `task-17-report-r2.md:158`
  과 모순이었다.〕
- `codex_jsonl.py` 사본의 docstring 정정(정본과 동기) — 없는 테스트 파일 인용 제거,
  배포 지점 도출 규칙 명시(R2-4·R2-11).

### Fixed (2026-08-17 fix round 3)
- **원인-확정 판별자 자신이 두 방향으로 fail-open 이던 결함(R3-1).**
  round 2 가 더한 `tests/test_brief_codex_axes.sh` 의 원인-확정 검사는 ① 맨 `grep` 이라
  **출력 파일 부재를 PASS 분기로 라우팅**했고(변이본이 구문 파손돼 아무것도 안 남겨도
  40/40 GREEN + "이빨 있음"), ② degrade 사유를 **하드코딩**해 러너가 내지 않는
  `extract_failed` 를 열거하면서 러너가 실제로 내는 여섯(`runner_incomplete` ·
  `payload_missing` · `missing_project_dir` · `project_dir_unreachable` ·
  `scratch_dir_uncreatable` · `codex_not_installed`)을 빠뜨렸다 — 그래서
  `reason: codex_not_installed` 로 degrade 한 변이본도 "원인 확정" 을 통과했다.
  즉 R2-6 이 닫혔다고 주장한 실패가 그대로 재현됐다. 두 판정 모두
  `shared/tests/assert.sh` 의 `assert_file_absent`(파일 부재 = `no()`)로 바꾸고,
  사유 열거는 러너의 `emit_fallback`/`write_failclosed` 호출부에서 **도출**한다
  (현재 9종). 도출이 0건이면 vacuous 로 보고 RED. 실측: 구문 파손 변이 → 2 RED,
  `codex_not_installed` degrade 변이 → 1 RED, 무변이 40/40 GREEN.

### Added (Task 20 — codex 러너 공통 조각)

- `scripts/runner_common.sh` — `shared/codex/runner_common.sh` 의 `copy-of` 물리 사본
  (`_degrade_if_empty` · `write_failclosed` 정본).

### Changed (Task 20)

- `run_spec_codex_reviewer.sh` · `run_brief_codex_reviewer.sh` 가 두 함수를 자체 정의하지
  않고 위 정본을 source 한다(census #24·#125 — 두 파일에 그대로 복제돼 있었다).
- **`write_failclosed` 의 시그니처가 `<output_path> <reason>` 두 인자로 바뀌었다.** 이전에는
  reason 한 인자만 받고 경로는 전역 `$OUTPUT_PATH` 에서 읽었다 — 공유 파일이 호출자의 전역을
  읽으면 그 전역 이름이 조용한 계약이 된다. 호출부 셋(`emit_fallback` ×2 · `seed_failclosed`)이
  모두 `"$OUTPUT_PATH"` 를 먼저 넘기도록 바뀌었고, 정본에 빈-인자 가드가 있어 옛 형태로
  부르면 rc=1 로 거절된다(빠뜨린 호출이 `runner_incomplete` 라는 **파일 이름**으로 쓰기를
  시도하던 실패원을 조용히 통과시키지 않는다).
- `emit_fallback` 은 정본화하지 **않는다** — `exit 0` 으로 호출자 프로세스를 끝내는 제어흐름
  래퍼라, 아끼는 3줄보다 공유 계약이 무겁다(census #126).

### Fixed (Task 20)

- **정본 로드 실패 시 stale/0바이트 산출물이 남던 새 경로** 봉쇄 — quality-gates 3.4.0 의
  같은 항목과 동형(`[ -r ]` + `bash -n` 선검사 → `reason: runner_common_unloadable`).
  `run_brief_codex_reviewer.sh` 쪽은 특히 `seed_failclosed` 에 **닿기 전에** 죽는 형태라
  직전 라운드 YAML 이 그대로 이번 판정으로 읽혔다.
- `tests/test_brief_codex_axes.sh` 의 mutation fixture가 러너를 다른 디렉토리로 옮기면서
  형제 정본을 두고 가, 사본이 로드 가드에 걸려 **조기 degrade** 했다 — 그 상태에서 mutation 은
  변이가 아니라 위치 때문에 실패한다(도달 불가). 이 테스트의 계측기 assertion 둘이 그것을
  RED 로 잡아냈고, fixture 가 정본을 함께 옮기도록 고쳤다.

### Added (Task 21 — GC 공통 조각)

- `scripts/gc_common.py` — `shared/gc/gc_common.py` 의 물리 사본(머리 한 줄 마커).
  quality-gates 와 공유하는 정본이다.

### Changed (Task 21)

- `scripts/spec-distill-gc.py` 가 `_ttl_ns`·`_folder_mtime_ns`·`_within_grace`·`_gc_one` 과
  상수 셋(`GRACE_NS`·`DOUBLE_STAT_DELAY_S`·`GC_PENDING_PREFIX`)을 지우고 `gc_common` 을
  부른다. `GC_PENDING_PREFIX` 를 정본에서 가져오는 것이 특히 중요하다 — 그 접두를 **쓰는**
  쪽(`gc_one`)과 **줍는** 쪽(`_sweep_gc_pending`)이 갈라지면 고아가 영원히 안 지워진다.
  남은 고유 본문은 git-aware state root 와 `.gc-pending-*` 고아 스윕이다.
- `hooks/session-end-cleanup.py` 와 위 고아 스윕의 삭제가 `gc_common.safe_rmtree` 를 거쳐
  root 밖 경로를 거부한다. 이 플러그인은 `SESSION_PATTERN` charset 검증을 이미 갖고 있어
  동작 변화가 없다 — 그 패턴이 완화되는 편집이 곧바로 root 밖 삭제가 되지 않도록 하는
  두 번째 겹이다.
- **state root 해석은 공통 조각에 넣지 않았다.** 이 플러그인은 git-aware
  (`git rev-parse --git-common-dir`, worktree 호환)이고 quality-gates 는 payload cwd
  상대다 — 부분 사본의 "각자 고유 본문"이라 플러그인 경계를 넘는 통합은 하지 않는다.

### Changed (Task 23 — `state_path.py` 를 `hooks/` 에서 `scripts/` 로)

- `hooks/state_path.py` → `scripts/state_path.py` (본문 무변경, git 인식 rename).
  `hooks/` 에는 `hooks.json` 이 등록한 훅 4개와 `hooks.json` 만 남는다 — 이 리포의
  어느 플러그인 `hooks/` 에도 비-등록 `.py` 가 없다(이동 전 1건).
- SKILL 실행 라인 9곳이 `${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py` 를 부른다
  (`conducting-interview` 5 · `reviewing-brief` 2 · `reviewing-spec` 2).
  이 세 SKILL 에는 `allowed-tools` frontmatter 가 없어 함께 고칠 권한 선언이 없다.
- `scripts/{arm_ledger,spec-distill-gc,hook_common}.py` 가 `state_path` 를 찾으려고
  형제 디렉토리 `hooks/` 를 `sys.path` 에 얹던 것을 **자기 디렉토리**로 바꿨다.
  훅 4개는 이미 `scripts/` 를 `sys.path[0]` 에 얹고 있어 import 경로 변경이 없다.

### Fixed (Task 23)

- **설치본에서 `scripts/spec-distill-gc.py` 가 홀로 배포되면 죽던 잠복 결함**(Task 19
  발견 · Task 21 확대 확인). 이 파일은 `state_path` 를 `hooks/` 에서 풀었는데,
  `shared/` 정본 형제 락(`test_copy_of_contract.sh` 축 1c)의 설치본 대역은 소비자마다
  디렉토리를 도출해 편다 — 이 소비자만 격리하면 `hooks/` 가 트리에 없어
  `ModuleNotFoundError: No module named 'state_path'` 였다. 지금까지 GREEN 이었던 것은
  락이 SIM 트리를 코호트로 공유하고 `git ls-files` 가 `hooks/*` 를 `scripts/*` 앞에
  정렬해, 앞선 훅 소비자가 이미 `hooks/` 를 펴 두었기 때문이다 — 통과가 **코호트와
  순서에 의존**했다. 이동 후 소비자 19건 전부가 격리에서 GREEN 이다(측정: 이동 전
  트리에서 같은 계측기가 이 파일 하나만, 두 코호트 모두에서 RED).
- `plugins/plugin-audit/scripts/check-shape-completeness.py` 의 over-glob 방어 주석이
  들던 실측 사례가 이 이동으로 사라졌다 — 주석을 과거 사례로 표시하고, 사례가 없다고
  가드를 지우면 안 된다는 이유를 남겼다(정의부만 옮기고 인용부를 남기면 없는 것을
  근거로 내세우는 서술이 된다).

## [0.27.0] — 2026-08-17

Task 15(무게 감축) + fix round 1. patch가 아니라 **minor**인 이유(S3): 새
`skip_reason` 3종 + 새 필수 형제 payload 파일(`codex-killswitch.conf`)이 새 surface다.

`scripts/detect_codex.sh`가 물리 사본에서 `shared/codex/detect_codex.sh`를 가리키는
상대 심볼릭 링크로 바뀌었다(quality-gates·plugin-audit와 공유하는 정본). kill switch
변수명(`DEVBREW_DISABLE_SPEC_DISTILL_CODEX`)은 형제 설정 파일
`scripts/codex-killswitch.conf`로 분리 — 설정 부재 시 fail-closed
(`skip_reason: killswitch_config_missing`).

### Fixed
- **(fix round 1, 보안)** 정본의 kill switch 가드가 값이 비어 있지 않기만 하면
  통과시켜, CRLF·공백만·탭·셸 메타문자 값이 bash 3.2의 `${!VAR:-0}` 간접 확장에서
  에러 없이 `0`으로 평가돼 kill switch가 fail-open하는 결함을 닫았다(정본 공유 —
  `plugins/quality-gates/CHANGELOG.md` [3.3.0] 참조). `CODEX_KILL_SWITCH_VAR` 값이
  POSIX 식별자가 아니면 `skip_reason: killswitch_config_invalid`로 거절한다.
- `reviewing-brief`·`reviewing-spec` 두 SKILL의 codex 게이트가 "감지기 실행 자체
  실패"와 "codex 미설치"를 구별하지 못하던 결함을 `skip_reason: detector_not_runnable`
  로 닫았다. 가드 조건도 `-z codex_avail && -z skip_reason`에서
  `-z codex_avail` 단독으로 좁혔다 — 정본은 성공 실행 시 항상 exit 0이라 이쪽이
  더 정확하다(I6).
- `tests/test_detect_codex.sh`의 kill-switch 변수명 양/음 assertion 2개가 심볼릭
  링크 전환 뒤 정본 본문을 grep해 자기 변수도 못 찾고(양 — RED) 이웃 변수도 못
  찾는(음 — 조용히 vacuous 통과) 상태였다. 형제 `codex-killswitch.conf`로
  재조준했고, 위 fail-open 수정의 회귀 락(malformed conf fail-closed, CRLF·공백만)
  을 추가했다.
- `tests/test_reviewing_brief_skill.sh`의 `skip_reason=` 검사가 real capture line과
  new fallback line 둘 다 만족시켜 header-satisfiable했다(진짜 캡처를 지워도
  GREEN). `skip_reason="\$\(`로 캡처 형태에 앵커했다(mutation으로 확인).

## [0.26.2] — 2026-08-17

devbrew-weight-reduction Task 14 — 자체 판정 헬퍼 이관. `tests/` 46개 파일이 각자
정의하던 `note`/`pass`/`fail`/`ag` 판정 헬퍼(주로 `note PASS/FAIL <msg>` 디스패처
관용구)를 지우고 `shared/tests/assert.sh` 정본을 source. 호출부는 `note PASS`→`ok`,
`note FAIL`→`no`로 개명(`arm_test_helpers.sh`는 두 소비 파일—`test_arm_once.sh`·
`test_arm_ledger_timing.sh`, Task 14 스코프 밖—의 `note PASS/FAIL` 호출 계약을 유지한
채 정본 `ok`/`no`로 위임하는 얇은 wrapper로). `test_detect_codex.sh`의 3-인자 `ag`는
`assert_grep`으로 인자 순서를 재배열(desc가 마지막 인자로).

### Changed
- `tests/*.sh` 46개 — 자체 헬퍼 정의 삭제, 정본 source, 종료를 `finish`로 통일.
  assertion 판정 로직·개수 불변(파일별 감소 0), 전량 GREEN 유지.

## [0.26.1] — 2026-08-17

### Fixed

- **`tests/` 셸 테스트 14개의 실행비트 부재.** qg 셸 테스트 어댑터는 실행비트 있는
  `test_*.sh`만 후보로 고른다 — 비트가 없으면 어댑터가 그 파일을 조용히 건너뛴다.
  동작 계약(테스트 내용)은 무변경, 발견 가능성만 복구.

## [0.26.0] — 2026-08-10

### Fixed

- **`run_spec_codex_reviewer.sh` 의 guard 위치** (`/qg` whole-branch 리뷰 2026-08-13).
  세 조기 분기(`missing_project_dir`·`project_dir_unreachable`·`scratch_dir_uncreatable`)
  가 guarded truncate 보다 **앞**에서 `>` 로 산출물에 직접 썼다. `set -euo pipefail`
  에서 산출물 경로가 쓰기 불가면 그 리다이렉트가 실패해 스크립트가 **exit 1** 로 죽는데
  (EXIT 트랩도 아직 미무장), 계약과 호출 SKILL 은 `rc == 3` 에서만 stale 을 지운다 —
  이전 라운드의 YAML 이 양성 `codex_failed: false` 를 단 채 이번 라운드의 판정으로
  읽혔다(indeterminate ≠ clean 위반). 형제 `run_brief_codex_reviewer.sh` 의 seed 형태
  (절대화 직후 fail-closed 선-기록 + `write_failclosed`/`emit_fallback`)를 그대로
  채용했다. 실측: 쓰기 불가 산출물 → rc=3 + stale 바이트 무변경, 정상 degrade →
  rc=0 + `codex_failed: true`. 전문은
  `docs/audits/2026-08-13-codex-unification-branch-review.md`.

### Added

- `build_spec_codex_prompt.py`·`build_brief_codex_prompt.py` 에 untrusted-data(P21) 절 +
  무조건 blanket 문장 + 무조건 action 금지 문장(codex 프롬프트 빌더 4종 공통, 나머지
  둘은 quality-gates 쪽). brief 경로가 가장 첨예하다 — Claude critic 은 가려진 사본을
  받는데 codex 는 원본 payload 를 받고, `merge_brief_review.py` 가 그 §6 을
  "비신뢰 verbatim" 이라 명시한다.
- `run_spec_codex_reviewer.sh` 에 웹 검색 + `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 확인.
- `run_brief_codex_reviewer.sh` 에 degrade 계약(시작 시 truncate + 완료 전 중단 시
  degrade YAML) 백포트 — 형제 러너와 동형.
- `rc == 3`(fail-closed 산출물을 못 쓰면 죽는 러너) 소비자 의무를
  `reviewing-spec`·`reviewing-brief` SKILL 에 명문화.

### Fixed

- **`reviewing-spec` 의 codex 게이트가 산문이었다.** `:81` 이 "codex_avail=true일 때만"
  이라고 문장으로 적고 `:82-85` bash fence 는 무조건 실행됐다 — 그 파일에 `codex_avail`
  을 검사하는 `if` 가 없었다. kill switch 는 P21 보안 컨트롤이라 그 상태는 "껐다고
  믿게만" 만든다. `reviewing-brief` 와 동형인 리터럴 게이트로 전환.
- **`codex_findings_to_yaml.py` 헤더의 거짓 주장** — "ONLY adaptation … the emit keyset"
  은 사실이 아니었다(CR-2 검증이 이 사본에만 있었다). 동일성은 이제 주석이 아니라
  `quality-gates/tests/test_codex_copies_agree.sh` 가 보증한다(mock 자산 사본 8그룹도
  같은 락에 편입).

### Changed

- 러너 2종이 프롬프트를 **stdin** 으로 넘긴다 (`codex exec -`).
- `detect_codex.sh` 가 `0.118.0` 버전 바닥과 semver 판독 실패를 낸다.
- `tests/test_detect_codex.sh` 가 14-케이스 합집합.
- `codex_degraded` 의 정의가 **한 곳**(`merge_review.codex_degraded_from`)에만 있다.
  두 병합기가 각자 인라인 계산하고 있었다.
- `tests/test_web_kill_switch.sh` 의 소비자 도출이 **플러그인 횡단**이고 술어가
  **값을 인식**한다 — 웹을 *끄는* 호출부에 죽은 스위치를 요구하지 않는다.

## [0.25.2] — 2026-08-06

### Fixed

- **Stop 훅의 mandate 가 자기 수명을 밝히지 않아, "이번 리뷰만 멈춰달라"는 요청이
  세션 전체 kill switch 로 응답되던 것.** 실사용에서 적발됐다 — 사용자가 훅을 이번
  한 번만 멈추려 했는데 `DEVBREW_DISABLE_SPEC_DISTILL=1` + 재시작이 답으로 나왔다.
  스위치가 없어서가 아니다. 훅 4개 전부 `main()` 첫 문장에서 kill switch 를 존중하고
  스위치는 3단(전역·훅단위·`SKIP_AUTOREVIEW`)으로 이미 있었다. **없던 것은 범위
  정보다** — `reason` 이 "MANDATORY: reviewing-spec 호출"만 말하고 그 강제가 언제까지
  유효한지 적지 않으니, 읽는 쪽이 영구로 가정하고 최대 화력을 골랐다. 게다가 항상
  로드되는 리포 `CLAUDE.md` 의 kill switch 조항은 **보안 요구사항**("모든 훅은 꺼질 수
  있어야 한다")이라 scoping 질문에 재사용되면 all-or-nothing 만 가르친다.
  → `reason` 에 수명 한 문장 추가: *"이 mandate는 이번 dispatch 1회에만 유효하다.
  재발동은 이 문서를 다시 편집할 때 일어난다."* 두 절 **모두 무조건 참**인 것만 남겼다
  (아래 리뷰 라운드 참조).
  **범위는 알리되 면제는 알리지 않는다** — "건너뛰어도 된다"·"무시하면 재발동하지
  않는다" 같은 집행 공백은 적지 않는다. 그것은 모델이 스스로 리뷰를 면제할 근거가 되어
  Law 2 를 뚫는다. 수명 사실은 반대로 "지금 안 하면 사라진다"는 즉시 이행 압력이다.
- **두 수명 문장의 상호배타.** G6 상한에 닿은 dispatch 에서는 "재편집하면 재발동" 이
  **거짓**이다 — 그 문서는 이 세션에서 이미 중단됐다. 상한 문구와 수명 문구를 `if/else`
  로 갈라 어느 분기에서도 훅이 같은 숨결로 모순되는 두 수명을 주장하지 않게 했다.

### Changed

- `README.md` Kill switches 섹션 맨 앞에 **범위 사다리 표**. 기존 목록이 전부 세션
  스코프·재시작 필요라, "이번 한 번만" 에 해당하는 두 행(단발성 / 문서 커밋)이 어디에도
  없었다. 두 행은 env var 가 아니라 arm-once(v0.25.0) 설계에서 따라 나오는 성질이다.
  이 표는 mandate 문장의 **참조본**이지 유일한 전달 경로가 아니다 — 찾아보지 않는 문서는
  이 실패를 못 막는다는 것이 이번 건의 요지다.
- `systemMessage`(사용자향)는 **무변경**. 같은 사건에 사용자와 Claude 가 서로 다른
  강도의 신호를 받으면(사용자 화면 "1회" vs Claude "MANDATORY") 두 참여자가 다른
  구속력을 믿은 채 대화하게 된다 — 지금보다 나쁘다.

### Added

- `tests/test_hook_output_schema.py` `TestReviewDispatchMandateScope` 3종 — 존재
  1 + 상호배타 2(양방향). **mutation 3축 전부 RED 로 이빨 증명**: M1 문장 삭제 →
  RED, M2 `else`→`if True`(상한에서 두 문장 동시 방출) → RED, M3 문자열은 파일에
  남기되 `msg_lines` 에 안 싣기 → RED. **M3 가 요점이다** — grep 기반 락이었다면
  GREEN 이었을 mutation 에서 RED 가 나므로 이 락은 문자열의 존재가 아니라 그것이
  `reason` 채널에 실리는지를 잰다. 단방향으로 두면 두 문장을 모두 내보내는 mutation 이
  통과하므로 상호배타 두 방향은 함께 있어야 한다.

### 리뷰 라운드 (codex 독립 감사, 머지 전)

별-모델 독립 리뷰가 **작성자가 놓친 4건**을 적발했고 전부 이 릴리스에서 수정했다.

- **[C1] README 사다리가 모델에게 skip 을 지시하고 있었다.** 첫 판본의 "이번 dispatch
  한 번만" 행이 *"그냥 이번 턴에 리뷰를 건너뛰면 된다"* 였다 — `reason` 에는 면제 문구를
  넣지 않으려고 신중히 썼으면서, **같은 PR 의 README 가 그 절제를 무효화**했다. writer
  턴이 자기 리뷰를 skip 할 근거가 되므로 Law 2 위반이다. 표를 *"어떻게 건너뛰나"* 에서
  *"무엇이 범위를 정하나"* 로 재구성했다(열 제목 `방법` → `그 범위를 만드는 것`).
  이 PR 의 e2e 가 이미 신호를 줬으나(README 만 있는 arm 에서 3/3 이 "그냥 건너뛰면
  됩니다") 작성자는 그것을 *"README 도 효과 있다"* 로만 읽고 반대 해석을 놓쳤다.
- **[C2] mandate 가 fail-open 경로에서 거짓을 주장했다.** *"커밋하면 더 이상 arm 되지
  않는다"* 는 무조건 단정이었는데, `is_born()` 은 git 판정 실패(`ls-files` timeout·rc 128)를
  **전부 arm 쪽으로 fail-open** 한다 — 커밋된 문서도 arm 될 수 있다. `arm_ledger` import
  실패 시 `cap=0` 이 되어 같은 `else` 로 떨어지는 경로도 같은 거짓을 낸다. 커밋 절을
  mandate 에서 **제거**했다. 커밋 권고는 approve 시점 `check-born` advisory 가 이미
  담당하며, 거기서는 실제 git 판정 결과를 손에 쥐고 말하므로 거짓이 될 수 없다.
- **[C3] "커밋하면 영구히" 가 이미 걸린 dispatch 도 멈추는 것처럼 읽혔다.** Stop 은 pending 을
  찾은 뒤 `armed_paths` 만 조회하고 git 추적 여부를 재검사하지 않으므로, pending 생성 후
  같은 턴에 커밋해도 그 dispatch 는 실행된다. README 에 명시했다.
- **[C4] 락이 문구의 존재만 재고 진위는 재지 않았다.** C2 의 거짓 단정이 있어도 문구 락
  3종은 전부 GREEN 이었다. `TestMandateClaimsAreTrue` 3종 추가 — validator·Stop·상태
  파일을 실제로 태워 남은 두 주장 각각을 검증하고, 무조건 커밋 단정의 재도입을 금지한다.

**mutation 6축 전부 RED.** 문구 락 3(M1 삭제 / M2 `else`→`if True` / M3 문자열은 파일에
남기고 채널만 끊기) + 진위 락 3(N1 pending 소진 제거 / N2 `should_arm` 상시 False /
N3 커밋 단정 재도입). 그 과정에서 **계측기 결함 2건**을 잡았다:

- 진위 락 초판은 N1 에서 GREEN 이었다 — 두 번째 Stop 의 침묵을 만든 것이 pending
  소진이 아니라 **30초 redispatch TTL 가드**였다. 락이 엉뚱한 메커니즘을 재고 있었다.
  `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0` 으로 TTL 을 끄자 침묵을 설명할 수 있는
  것이 pending 소진뿐이 되어 RED 로 전환됐다.
- M2 mutation 앵커 `"    else:\n"` 가 파일에서 유일하지 않아 **첫 else 에 착지**해
  대상 분기를 건드리지 못한 채 GREEN 이 났다. 앵커를 본문 고유 문자열로 좁혀 해결.

## [0.25.1] — 2026-08-05

### Fixed

- **`parse_spec_structure.py` ambiguity 게이트 검출력 회귀 (Law 1).** 라운드 3 `/qg`가 적발.
  Task 10이 하이픈 복합어 오탐(`fast-forward`)을 막으려고 경계를
  `(?<![\w-])…(?![\w-])`로 잡았는데, **뒤쪽까지 단어문자를 막아** blacklist 어간의 접미
  굴절형이 전부 통과하게 됐다 — `seamlessly`·`efficiently`·`Robustness`·`faster`가 모두
  게이트를 빠져나갔다. 선언된 동기는 하이픈뿐이었고 T6-4/T6-5는 이 방향을 측정하지 않는다.
  → 경계를 **비대칭**으로 정정: `(?<![\w-])…(?!-)`. 앞은 단어·하이픈 금지(→ `breakfast`,
  `inefficient` 오탐 계속 차단), 뒤는 **하이픈만** 금지(→ 굴절형 복구). 오탐 1종을 막으려다
  미탐 다수를 만든 교환을 되돌린다.

### Added

- `tests/test_parse_spec_structure.sh` T6-6 — 접미 굴절형(`-ly`/`-ness`/`-er`)이 계속 hit되는지
  측정. T6-4(오탐 없음)와 T6-5(어간 그대로는 hit)만으로는 이 방향이 비어 있어서, 경계를 양쪽
  다 막아도 둘 다 GREEN이었다.

## [0.25.0] — 2026-08-02

design doc auto-review 를 **문서가 처음 생길 때 한 번만** 발동시키고, 그 재발동을 막으려
v0.14.0–v0.18.0 에 쌓인 방어층 4개를 원인과 함께 걷어냈다. 교훈 한 줄: **원인을 지우면
그 원인을 막던 방어층도 같이 지워진다** — 셋 다 사용자 기능이 아니라 훅이 자기가 만든
문제를 자기가 막는 내부 하니스였다.

### Changed
- **arm 조건이 `(세션 원장에 없음) AND (git 이 모르는 문서)` 로 바뀌었다.** 판정은
  `scripts/arm_ledger.py` 의 `should_arm()` 한 곳에만 존재하고 훅은 그것만 부른다.
  두 조건이 서로 다른 시간축을 덮는다 — 원장 단독이면 세션마다 한 번씩 다시 리뷰되고,
  git 단독이면 커밋 전 fix 루프에서 계속 재arm 된다.
- **원장 기록자가 둘로 확정됐다** — verdict 가 나온 리뷰(완료) 와 G6 상한(3회)에 닿은
  Stop 훅(포기). validator·skill 진입, 그리고 **상한 미달의 정상 dispatch** 는 쓰지
  않는다. 그 셋 중 어디에 써도 "리뷰를 받지 않았는데 표시된" 창이 생기고, 삭제된
  락이 TTL 로 얻던 자기치유를 잃는다. verdict 시점 기록은 TTL 을 새로 만들지 않고
  같은 자기치유를 얻는다 — **표시되지 않은 문서는 다음 arming 편집에서 다시 dispatch 되기 때문**.
  두 기록자의 결론은 같다("더 이상 dispatch 안 함"), 그리고 어느 쪽도 문서를 쓴 턴이 아니다.
- **리뷰 진행 중 오발 방지가 락에서 pending strip + 원장 게이트로 바뀌었다.** dispatch 의
  연료는 `pending_review` 이므로 `reviewing-spec` 진입 시 연료를 없애면 락이 필요 없다.
  다만 진입 strip 하나만으로는 부족하다 — skill 이 Step 1(strip-pending)과 Step 3
  (mark-reviewed)을 분리된 두 bash 블록으로 실행하므로, Step 1 이 빠지면 pending 이
  살아남고 실제 리뷰는 30초 TTL 을 넘겨 다음 Stop 이 이미 리뷰된 문서에 다시 block 을
  낸다. 그래서 **Stop·UserPromptSubmit 두 소비자가 emit 전에 `armed_paths` 를 조회**한다
  (Stop 은 남은 stale pending 도 함께 정리하고 결과를 보고한다; `armed_paths` 는 건드리지
  않으므로 상한 미달 무-기록 성질은 유지). 조회 실패는 dispatch 쪽 fail-open.
- **`is_born` 의 cwd 의존을 제거했다.** 전에는 raw_path 를 cwd 상대 git pathspec 으로
  넘겨, 하위 디렉토리에서 부르면 **커밋된 문서가 not-born** 으로 떨어졌다 (v0.14.0 에
  출하됐던 버그와 같은 모양이며 그 락은 승계 없이 삭제돼 있었다). 이제 **상대경로만**
  `:(top,literal)`+canonical_key 로 리포 루트에 고정하고, **절대경로는 접지 않는다** —
  접으면 다른 체크아웃의 문서를 이 리포 파일로 오판한다(아래 Fixed 참조).
- **제어문자가 든 경로는 원장에 들어가지 못한다 (Security).** 상태 파일은 0-indent 블록으로
  파싱되는 마크다운이라, 개행이 든 `tool_input.file_path` 가 그대로 보간되면 `armed_paths:`
  를 위조해 **다른 문서**의 리뷰를 영구 억제할 수 있었다(T16 mutation 으로 실증 — 가드를
  빼면 위조가 성공한다). 차단은 **writer**(`write_state`)에 둔다 — reader 마다 거르면 새
  reader 가 생길 때마다 두더지잡기가 된다. `canonical_key` 도 방어적으로 함께 거부한다.
- **`_read_body` 가 부재(`""`)와 판독 실패(`None`)를 구분한다.** 빈 body 로의 degrade 는
  읽기 술어(`is_armed`·`skip_reason`)에는 옳지만(미기록 → arm, 안전한 방향),
  read-modify-write 인 `mark_reviewed`·`strip_pending_file` 에서는 판독 불가 원장을
  통째로 덮어써 다른 문서의 `armed_paths` 와 살아있는 `pending_review` 를 함께 지웠다.
  이제 두 쓰기 경로는 보존하고 멈춘다(P14). 훅 두 곳의 `except OSError` 도
  `(OSError, UnicodeDecodeError)` 로 넓혔다 — `UnicodeDecodeError` 는 `ValueError`
  하위라 좁은 절이 판독 불가 원장에서 훅을 죽여 dispatch 를 통째로 없애고 있었다.
- **PostToolUse arm-skip advisory 가 사유를 세 가지로 구분**한다 — 세션 내 리뷰 완료 /
  git 이 아는 문서 / G6 상한 도달. 앞의 둘과 셋째는 사용자가 취해야 할 행동이 다르다.

### Added
- **G6 재시도 상한 (세션당·문서당 3회).** verdict 없이 끝난 dispatch 의 재시도는
  의도된 동작이지만 무한하면 Forbidden Pattern(*Unbounded autonomy*)이다.
  `dispatch_attempts` 가 3 에 닿는 dispatch 가 마지막이고, 그 emit 이 상한을 알린다.
  경계가 세션당인 이유: 그 상태는 세션 스코프이고, 문서 생애 상한으로 만들려면
  세션 밖에 살아남는 저장소가 필요한데 그것은 NG4 가 배제한다. 세션을 넘겨도 멈추게
  하는 진짜 수단은 문서를 커밋하는 것이고 approve 시점 `check-born` advisory 가 그것을 촉구한다.
- 회귀 락 T1–T19 (`tests/test_arm_once.sh` T1–T3·T13–T19, `tests/test_stale_terms.sh`
  V9·V10 = T4·T5, `tests/test_arm_ledger_timing.sh` T6–T12) + `tests/test_arm_ledger.py`
  유닛 · `tests/arm_test_helpers.sh` 공유 하니스 —
  전부 mutation 으로 이빨을 증명했다. T7·T8 은 서로 반대 방향이라 함께 있어야 이빨이
  생기고, T10 은 `arm_ledger` CLI 의미가 아니라 **상한 미달 dispatch 단독에서의 Stop 훅
  원장 무-기록**을 잰다(상한에 닿는 dispatch 는 반대로 기록한다 — 그 구분이 T10 의 요지).
- 승계 락 S5–S8 (`tests/test_reviewing_spec_state_keying.sh`) — 삭제된 AC8-c·AC11-a·
  AC11-b·AC8-a/b 가 잠그던 불변식의 승계처. 세 섹션 윈도우는 종료 앵커의 존재를 먼저
  확인한다: `sed` 의 범위 주소는 종료 주소가 매칭되지 않으면 EOF 까지 출력하므로,
  그 확인이 없으면 무관한 라벨 rename 한 번에 "공존" 락이 조용히 file-wide 존재
  확인으로 바뀐다(측정: 12줄 → 130줄, 스위트는 GREEN).
- T17 — 세 훅의 UTF-8 stdio 고정 회귀 락. **트리거는 `LC_ALL=C` 가 아니다**: macOS
  CPython 은 C 로케일에서도 stdio 를 UTF-8 로 강제해, 로케일 축으로는 핀을 통째로
  제거해도 차이가 없다(측정 8회). 실제로 갈리는 축은 `PYTHONIOENCODING` 이며 T17 은
  그쪽을 잰다.
- `tests/test_arm_ledger.py` 유닛 4종 추가 — `armed_paths` 위조(splitlines 경계),
  교차-체크아웃 `is_born`, `PATH_PREFIX`↔`PREFIX` 계약, `strip_pending_file` 의
  판독불가 보존(모듈이 "유일한 비대칭 방어" 라 부르는 쌍의 나머지 절반).

### Fixed
- `is_born()` 이 다른 체크아웃의 문서를 이 리포의 동명 파일로 판정하던 결함. pathspec 을
  `:/{canonical_key}` 로 접으면 **어느 체크아웃이었는지가 사라진다** — 접힌 키가 이 리포
  index 에 있으면 born=True 가 되고 `should_arm` 이 False 로 떨어져 그 문서의 Law 1
  게이트가 조용히 꺼진다. 현실적 트리거는 이 프로젝트 자신의 레이아웃이었다(cwd = main
  repo, 편집 대상 = `.claude/worktrees/<name>/docs/superpowers/specs/…`). 이제 절대경로는
  접지 않고 git 이 소속 리포를 판정하게 두며(리포 밖이면 128 → loud → arm), 상대경로만
  `:(top,literal)` 로 리포 루트에 고정한다. `--` 는 옵션 파싱만 멈출 뿐 wildmatch 를 끄지
  않으므로 `literal` 매직이 함께 필요하다 — 그전엔 파일명 속 `*` 하나로 존재한 적 없는
  문서가 born 이 됐다.
- pending 기록에 실패한 편집에도 "Reviewer will be dispatched at turn end" advisory 가
  나가던 결함. `write_state` 가 실패 **사유**를 반환하고 호출부가 그것을 소비해
  `emit_arm_skip_advisory` 로 진실을 보고한 뒤 성공 advisory 앞에서 종료한다. 기록이
  안 됐는데 리뷰를 약속하면 모델은 오지 않을 리뷰를 기다린다(under-review 방향).
- writer 와 `canonical_key` 가 서로 다른 문자 집합을 거부하던 결함. 차집합(탭·NBSP·ZWSP 등)
  에 속하는 파일명은 pending 은 쓰이는데 원장엔 기록될 수 없어 `dispatch_attempts` 가
  오르지 않았고, G6 상한(3)이 **구조적으로 무력화**돼 편집마다 영구 재발동했다. 이제
  writer 가 `canonical_key` 를 술어로 쓴다(판정 지점 1곳).
- Stop 훅 원장 게이트에서 `return 0` 이 `try` 안에 있어, veto 확정 **이후** sweep 이
  던진 예외가 dispatch 경로로 흘러 이미 기록된 문서를 다시 dispatch 하던 결함. 판정과
  부작용의 `try` 를 분리했고, sweep 실패 시 문구도 사실에 맞췄다(조회는 성공했다).
- validator 의 stdin `except` 가 `OSError` 까지 삼키면서 arm 지점에서 rc 0 + 무출력이
  되던 결함. 형제 두 훅은 같은 릴리스에서 advisory 를 받았고 이 파일만 빠져 있었다.
- **arm 은 됐는데 기록이 안 된 모든 분기가 성공 advisory 로 새던 결함.** pending 이
  없으면 Stop 훅이 볼 것이 없어 리뷰는 영영 발동하지 않는데, `write_state` 실패·세션 id
  미해석·`SKIP_AUTOREVIEW=1` 세 경로가 그대로 "Reviewer will be dispatched at turn end"
  로 흘렀다. 이제 각 경로가 사유 sentinel 과 함께 arm-skip advisory 를 내고 종료한다
  (T18·T19 가 stdout 을 두 축으로 잰다 — arm-skip 이 **있고** 성공 문구가 **없다**).
- **`unkeyable()` 의 예외 폭·검사 범위 정렬.** `ImportError` 만 잡아 `arm_ledger` 의
  `SyntaxError`(머지 충돌 마커 등)가 arm 게이트에서 degrade 된 뒤 writer 에서 다시 터져
  훅이 rc≠0 + 무-stdout 으로 죽었다(HEAD 에서는 정상 arm 되던 입력). 또 fallback 이
  경로 **전체**를 검사해 `canonical_key`(PREFIX 이후만 검사)와 어긋났고, 그 방향이
  fail-**closed** 였다. 둘 다 맞췄다.
- **인코딩 불가 상태 값이 훅을 죽이던 결함.** `os.getcwd()` 의 surrogateescape 문자열은
  줄 수 검사를 통과하고 `write_text` 에서 `UnicodeEncodeError` 를 던지는데, 그건
  `ValueError` 하위라 호출부의 `except (PermissionError, OSError)` 를 그대로 통과했다.
  선제 인코딩 검사 + `UnicodeError` 절.
- **`skip_reason` 이 "스코프 밖"과 "키 불가"를 뭉개던 결함.** 파일명의 보이지 않는 문자
  하나로 자동 리뷰를 잃은 문서가 "스코프 밖 경로"로 보고돼 원인도 조치도 알 수 없었다.
- **`bounded_window` 의 순서 역전 구멍.** 종료 앵커의 *존재*만 확인하면, 앵커가 시작보다
  앞에 있을 때 범위가 그대로 EOF 까지 흐른다(실측 12줄 → 129줄, GREEN). 이제 출력의
  마지막 줄이 종료 앵커인지 — 즉 범위가 **거기서 끝났는지** — 를 잰다. 같은 파일의 S1 이
  `pipefail` 아래에서 `grep -q` 로 파이프하던 것도 herestring 으로 바꿨다(SIGPIPE 141 이
  매치 성공을 FAIL 로 뒤집는다).
- **T17 의 거짓 진단.** `'제어문자'` 를 앵커로 쓰면 인코딩 주장이 어느 가드가 처리했는지에
  묶여, 다른 가드를 지웠을 때 "stdio 고정 없음" 이라고 잘못 보고했다. 두 가드에 공통인
  문구로 옮겨 두 성질을 분리했다.

### Security
- `canonical_key` 가 `str.splitlines()` 경계를 명시적으로 거부한다. 원장 reader
  (`armed_keys`·`attempts`)는 `splitlines()` 로 줄을 나누는데 그건 `\n` 뿐 아니라
  VT·FF·FS·GS·RS·NEL·U+2028·U+2029 에서도 쪼갠다. 반면 `ARMED_RE` 의 `[^\n]+` 는 그것들을
  전부 통과시키므로, U+2028 이 든 키는 **물리적으로 한 줄**로 기록되고 **두 개의 키**로
  읽혀 다른 문서의 리뷰를 영구 억제할 수 있었다(유닛으로 실증). `isprintable()` 이 부수적
  으로 같은 문자를 막고 있었으나 선언이 아니었고, 실제로 리뷰에서 "그 절을 좁히자"는
  제안이 나왔다 — 그 mutation 은 이제 RED 다.
- `write_state` 가 완성된 pending 블록의 줄 수를 reader 와 **같은 함수**로 검사한다.
  `path` 외에 `mode`·`worktree_path`(=`os.getcwd()`, POSIX 디렉토리명에 개행 허용) 도
  같은 보간 지점이라, 값마다 술어를 늘리는 대신 블록 전체를 한 번 센다.

### Removed
- `scripts/review_lock.py`(240) · `scripts/cancel_review.py`(99) ·
  `scripts/approve_handoff.sh`(98) · `scripts/suppress_state.py`(242) — 합계 679 줄이
  사라지고 `scripts/arm_ledger.py` 한 파일이 그 자리를 대신한다(순감소 ~240줄).
  <!-- 대체 파일의 절대 줄수는 적지 않는다: 같은 릴리스 안에서 이 파일을 고칠 때마다
       숫자가 낡고, 실제로 리뷰에서 369→410 불일치로 적발됐다. 삭제분 679 는 확정값. -->
- `/spec-distill:cancel-review` 커맨드. 네 용도 중 (a) approve 후 재arm 억제와
  (b) 고착 pending 정리는 **대상이 소멸**했고, (c) 미리 옵트아웃은 **인정된 손실**이며
  (남는 비용은 미커밋인 채 넘긴 세션당 dispatch 1회, `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`
  로 0 이 된다), (d) `harness_sid` 미해석 시 수동 억제는 대체 안내로 지정했다
  (그 지시는 원래도 부정확했다 — sid 가 없으면 그 커맨드도 상태를 못 썼다).
- 환경변수 `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` (락 소멸).
- 전용 테스트 7종 중 **6종 삭제 + 1종은 개명·축소 승계**(`tests/test_reviewing_spec_lock.sh`
  → `tests/test_reviewing_spec_state_keying.sh`, Task 7 — 삭제가 아니다). 삭제된 6종 중
  두 handoff 테스트(`test_handoff_compact_chain.sh`·`test_handoff_spec_path_validation.sh`)가
  잠그던 dangling-경로 무-abort 불변식은 T11 이 승계.

### Fixed
- `tests/test_stale_terms.sh` 의 production 파일 필터가 앵커 없는 `*/.claude/*` 라,
  하니스 워크트리(`<repo>/.claude/worktrees/`) 안에서 production 47 개를 전부 삼켰다.
  락은 empty-guard 로 FAIL 했지만(fail-closed 설계가 제 역할을 했다) **워크트리에서는
  실행 자체가 불가능**했다. `$SD` 기준으로 앵커했다.
## [0.24.17] — 2026-08-05

### Fixed

- **`agents/blind-spot-prober.md`의 고아 인용 제거.** `fan-out 1`을 정당화하며 `devbrew N≥5 게이트 미해당`을 근거로 들었는데 그 게이트는 이 sweep이 삭제했다. persona 산문은 이 리포에서 보안-민감 코드로 취급된다.
- **`commands/interview.md` trivia 목록을 philosophy P12와 정합화.** P12가 `파일 수와 무관하게`로 완화됐는데도 이 파일 — **P12가 자기 집행 지점으로 지목한 곳** — 은 `단일 파일 formatting`·`단일 파일 내 단일 식별자 rename`을 그대로 요구했다. 판정 기준을 파일 수에서 "한 문장으로 설명 가능한가"로 되돌린다.
- `README.md`의 P12 자격 서술도 같이 정합화.

## [0.24.16] — 2026-08-05

### Security

- **web kill switch가 egress를 가진 dispatch 두 곳을 덮지 못하던 공백 봉쇄** (`/qg branch` 라운드 2, codex·silent-failure-hunter 적발). 0.24.15가 `coverage-mapper`에 `WebSearch`/`WebFetch`를, `spec-reviewer`에 `WebSearch`를 **새로 부여**했는데 `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`은 둘 다 막지 못했다:
  - `reviewing-spec/SKILL.md` — 스위치 참조 **0건**인 채로 `spec-reviewer`를 dispatch.
  - `conducting-interview/SKILL.md` — `coverage-mapper` dispatch에 게이트 없음(형제 3경로는 전부 보유).
  두 agent 모두 `tools:`에 `Bash`가 없어 스스로 스위치를 읽을 수 없다(Law 2) — orchestrator가 유일한 집행 지점이다. **안 죽이는 kill switch는 없는 것보다 나쁘다**: 사용자가 egress가 꺼졌다고 *믿고* 행동한다.

### Fixed

- **`test_web_kill_switch.sh`의 앵커를 피검자 손에서 회수** (adversarial `meta_note`가 명명한 *verifier-steerable anchor*). 판정이 `grep -q "spec-distill:$a"`였으므로, 접두사 없이 `subagent_type: "spec-reviewer"`로 쓴 저자는 **자기 skill을 감사 대상에서 스스로 제외**했다 — 검사받는 파일이 자기가 검사받을지를 결정하는 구조. reviewing-spec이 정확히 그렇게 누락돼 있었다. → 접두사를 선택적(`(spec-distill:)?`)으로.
- **파일 전역 존재 검사를 dispatch 지점별 지배 관계로 교체.** "이 파일 어딘가에 확인이 있다"는 명제는 dispatch가 열 개여도 가드가 하나면 참이다. 이제 각 dispatch 줄마다 위 40줄 안에 확인이 있어야 한다.

## [0.24.15] — 2026-08-04

### Fixed

- `README.md:74`·`:110` — Law 2 선언이 실제 `tools:` allowlist보다 **좁게** 적혀
  있었다. `spec-reviewer`와 `coverage-mapper`가 이 sweep에서 `WebSearch`/`WebFetch`를
  받았는데 README는 옛 목록을 유지해 **부여된 egress를 문서가 은폐**했다
  (`/qg branch` 라운드 1, security-reviewer + code-reviewer 독립 적발).
  `tests/test_readme_sync.sh:52`는 agent *이름*만 grep해 이 drift를 못 본다.
  - **미해결로 남긴 것**: `coverage-mapper`의 본문은 웹 조사를 요구하지 않는데도
    egress를 갖는다(설계 goal-3의 자기 기준 미충족). adversarial은 SUGGESTION으로
    강등했고 — 설계 AC3가 의도적으로 부여했으므로 exfiltration 판정은 성립하지
    않는다 — 되돌리려면 frontmatter·AC3·frontmatter 락 2개를 **한 커밋에 함께**
    고쳐야 한다. 이번 라운드 범위 밖.

### Changed

- `tests/test_web_kill_switch.sh` — 소비자 목록을 열거에서 **도출**로, 앵커를
  선언에서 **소비**로 (0.24.14 항목 참조).

## [0.24.14] — 2026-08-04

### Fixed

- **`run_spec_codex_reviewer.sh` — 완료 전 중단이 조용히 지나가던 경로**
  (`/qg branch` 라운드 1, silent-failure-hunter). `set -u` 위반(예:
  `CLAUDE_PLUGIN_ROOT` 미설정)으로 abort하면 EXIT trap을 지나며 산출물이
  만들어지지 않았고, 더 나쁘게는 **이전 run이 남긴 파일이 살아남아 이번 라운드의
  리뷰 결과로 재사용**됐다.
  - 보고된 fix(`rc=$?` 보존)는 **이 플랫폼에서 동작하지 않는다**: bash 3.2.57은
    `set -u` abort 시 트랩 핸들러에 `$?`를 **0으로** 넘긴다(최소 재현 확인).
    게다가 이 스크립트의 계약은 "항상 exit 0 + 항상 YAML"이라 비-0 강제는 계약
    위반이다. 그래서 종료 코드가 아니라 **산출물**로 판정한다 — 시작 시 truncate로
    stale을 제거하고, 트랩에서 비어 있으면 `codex_failed: true` degrade를 채운다.
  - trap arm은 한 줄로 유지했다: C7 순서 락(AC6)이 `trap.*rm -rf.*SCRATCH.*EXIT`를
    한 줄 정규식으로 앵커하므로, 여러 줄로 펼치면 그 락이 trap을 못 보고 guard
    순서 검사가 통째로 무력화된다.

### Added

- `tests/test_run_spec_codex_reviewer.sh` — ABORT 케이스 2종(중단 시 degrade YAML
  실재 / 이전 run의 stale 산출물 미재사용). 종료 코드가 아니라 산출물을 잰다.

## [0.24.13] — 2026-08-03

### Fixed
- `scripts/parse_spec_structure.py`의 `scan_ambiguity()`가 blacklist 문구를
  `re.escape(phrase)` bare substring으로 찾아 하이픈 복합어·접두 결합 안에서도
  발화했다 (`fast-forward`의 `fast`, `inefficient`의 `efficient` 등) —
  ambiguity 없는 정상 기술 문서의 write를 Law 1 게이트가 거짓으로 막는
  harness-capability-suppression-sweep S3f. **이 문서를 쓰는 동안 실제로 이
  검사가 write를 세 번 exit 2로 막았다.** 단순 `\b` 감싸기는 이 버그를
  고치지 못한다 — 하이픈은 `\w`가 아니라서 `\bfast\b`도 `fast-forward` 안의
  `fast`에 그대로 매치한다. 경계 판정을 `(?<![\w-])phrase(?![\w-])`로 교체해
  하이픈을 경계 문자 집합에 포함시켰다 — `~phrase` opt-out(문구 직전이 `~`가
  아닌지 별도 확인)은 `~`가 `\w`도 `-`도 아니므로 그대로 동작한다.

## [0.24.12] — 2026-08-03

### Removed
- `scripts/web_budget.py` + `tests/test_web_sweep_bound.sh` + 관련 픽스처 4개
  (`state-web-within.md`·`state-web-over-sweep.md`·`state-web-over-session.md`·
  `state-web-commented-overcap.md`) — web landscape 조사의 per-sweep(≤4)/
  per-session(≤8) 상한 enforcer를 제거 (harness-capability-suppression-sweep
  S3d, Task 8). **내부 스크립트라 one-minor deprecation window 대상이 아니다** —
  유일한 소비자가 이 플러그인 안의 두 곳(`conducting-interview` R2,
  `reviewing-brief` 1-a)뿐이라 외부 breaking-change 표면이 없다.
- state schema(`conducting-interview`)와 `templates/interview-audit-template.md`의
  `web_sweep_count`/`web_search_count` 카운터 — 상한 게이트가 사라져 죽은 상태였다
  (`probe_count`는 유지 — 그 상한은 살아 있다).

### Security
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB` kill switch를 `web_budget.py` 삭제와 함께
  잃지 않도록 두 소비자에 각각 인라인으로 이식 — `conducting-interview` R2와
  `reviewing-brief` 1-a가 `run_brief_codex_reviewer.sh:96-99`와 동일한 계약으로
  독립 확인한다(정확히 문자열 `"1"`만 참, 미설정 시 웹 활성, 매 웹 작업 직전 평가,
  소비자별 소유·공유 헬퍼 없음).

## [0.24.11] — 2026-08-03

### Fixed
- `build_spec_codex_prompt.py`의 `PROMPT_TEMPLATE`에서 프롬프트 서두(:29-31)와
  `other` 항목(:44)은 0.24.10에서 "여섯 개는 시작 어휘, 닫힌 목록 아니다"로
  열었지만, 같은 템플릿의 JSON 출력 계약(`"category": "placeholder | ... |
  testing"`, :59)은 여전히 6개로 닫혀 있었다 — prose는 열렸는데 contract는
  안 열린 자기모순. 구조화 출력을 쓰는 모델은 prose와 schema가 충돌하면
  schema를 따른다: 여섯 이름 어디에도 안 맞는 진짜 결함을 발견한 리뷰어는
  prose로는 "`other`를 자유롭게 쓰라"는 지시를, contract로는 "`other`는 허용
  값이 아니다"는 지시를 동시에 받는다 — 이 태스크가 없애려던 바로 그 drop이
  한 레이어 아래로 옮겨갔을 뿐이었다. `:59`의 pipe-list에 기존 6개 순서를
  그대로 두고 `| other`를 추가.
  (참고: 같은 파일 module docstring `:5`의 "same 6 judgment categories the
  Claude spec-reviewer uses"는 검증 결과 그대로 두는 것이 맞다 — Claude
  spec-reviewer(`agents/spec-reviewer.md:121,149,155`)는 여전히 정확히 6개
  닫힌 taxonomy를 쓰고, 이 문장은 codex 프롬프트가 그 6개와 "동일한 6개"를
  기준으로 시작한다는 서술이지 codex 쪽 categoy가 6개로 닫혀 있다는 주장이
  아니라서 열린 `other`와 모순되지 않는다. codex 프롬프트 밖의 순수 문서라
  codex가 실제로 읽는 계약에도 영향 없다.)

### Added
- `test_build_spec_codex_prompt.sh`에 AC16b 락 추가 — JSON 출력 계약의
  `"category":` 힌트 줄에 `other`가 없으면 RED. 기존 AC16(prose `other` 존재)
  과 독립: prose만 보는 전-출력 grep이었다면 `other`가 이미 흔한 단어라(prose
  bullet 자신, ":33"의 "or other unfinished text") schema가 닫힌 채로도
  통과했을 것 — `"category":` 줄에 앵커링해 계약 표면만 정확히 겨냥.

## [0.24.10] — 2026-08-03

### Changed
- `build_spec_codex_prompt.py`의 `PROMPT_TEMPLATE`에서 "Review the document
  below for these SIX judgment categories only:" 를 "이 여섯 개는 하류 merge가
  가장 자주 기대하는 시작 어휘일 뿐, 닫힌 목록이 아니다"로 교체하고 여섯 항목
  뒤에 `other` 탈출구를 추가 — codex co-reviewer에게 "여섯 개뿐"이라고 지시하면
  그 어느 이름에도 안 맞는 진짜 결함은 merge/dedup 로직이 보기도 전에 프롬프트
  단에서 버려진다. 하류 파서는 바꾸지 않는다: `merge_review.py:86`은
  `str(it.get("category", ""))`로 자유 문자열을 통과시키고, `:319`/`:326`은
  `compute_issue_id.compute(category, target_section)`으로 해시 입력에만 쓴다.
  `codex_findings_to_yaml.py`·`compute_issue_id.py` 어디에도 6개 화이트리스트
  필터가 없다(실측 확인) — 따라서 파서 변경 없이 프롬프트만 여는 것이 정확하다.

### Added
- `test_build_spec_codex_prompt.sh`에 AC16 락 신설 — 닫힌-6개 문구 재삽입 시
  RED, `other` 항목 삭제 시 RED (프롬프트 레이어).
- `test_merge_review.py`에 `test_unknown_category_survives_merge` 신설 —
  codex YAML에 `category: other`인 finding을 넣고 실제 merge를 돌려 그 항목이
  `codex_findings` 표시 블록에 살아 있고, 6개 카테고리와 같은 해시 경로로
  issue_id를 받고, severity가 여전히 verdict를 escalate함을 확인한다
  (파이프라인 레이어 — 프롬프트 락과 분리: 프롬프트가 `other`를 광고해도
  미래에 파서가 화이트리스트 필터를 넣으면 조용히 drop될 수 있는 경로를
  독립적으로 잠근다).

## [0.24.9] — 2026-08-03

### Changed
- `conducting-interview` SKILL.md의 R3 steelman dispatch 지시(`:306`)에서
  `**순차** dispatch(병렬·투기적 금지 — C5)` 문구를 삭제 — 0.24.8에서 `steelman-builder`
  에이전트 persona에서 지운 것과 같은 억제가 오케스트레이터 쪽 dispatch 지시문에도
  거울처럼 남아 있었다(0.24.8의 브리프 file list 누락, 이번 sweep의 repo-wide 판별
  질의가 적발). 인용된 두 근거 다 성립하지 않는다: `C5`는 web 부재 시 graceful
  degradation을 가리키지 dispatch 순서와 무관하고(design.md:107), `AP9`의 병렬 fan-out
  게이트는 N≥5부터인데(philosophy.md:95-96) R3는 의심 트리거당 steelman 1회로 fan-out=1
  이라 그 문턱에 닿지 않는다. `투기적 금지`는 R3의 numbered step이 의심 트리거가 이미
  발화한 뒤에만 도달하므로 애초에 발생 불가능한 경로를 금지하는 무의미한 문구였다.
  `:311`의 "한 방향당 steelman 1회(재steelman 금지 — AP16 harassment 방지)" load-bearing
  bound는 그대로 둔다.

### Added
- `test_conducting_interview_stage.sh`에 R3-스코프 E10 락 신설 — 기존 `r3_block`
  awk 윈도우(`### R3 — Steelman` ~ 다음 `### `/`## ` 헤딩)를 재사용해 병렬·투기적 금지
  문구 재삽입 시 RED. 전-파일 grep이 아니라 R3 윈도우로 스코프한 이유: 같은 SKILL에
  `:122`의 `teach-beat 최대 1회`, `:438`의 `2회까지`가 legitimately 남아있다.

## [0.24.8] — 2026-08-03

### Changed
- `steelman-builder` · `blind-spot-prober`의 "Required research" 절에서 `1–2회`
  검색 횟수 상한과 `**순차 호출**(병렬·투기적 금지, C5/AP9)` 문구를 삭제. 두 에이전트는
  인터뷰 턴이 놓친 근거를 찾는 게 존재 이유인데, 호출 수 상한과 직렬화 강제 둘 다
  아무것도 보호하지 않으면서 조사 폭을 하니스가 대신 정하는 것이었다. 이제
  "필요한 만큼 찾는다"(steelman-builder) / 횟수·병렬 제약 없이 수집(blind-spot-prober).
  `blind-spot-prober.md`의 "web 부재 시 SKILL이 inline premortem으로 강등(C5)" 절은
  상한이 아니라 graceful degradation이므로 그대로 둔다.

### Added
- `test_steelman_builder_scope.sh` · `test_blind_spot_prober_frontmatter.sh`에 E10
  락 신설(`test_brief_agents.sh:194`의 단일 호출 상한 부재 락을 숫자 범위·병렬 금지
  패턴으로 확장) — 단일 호출 상한 표현(`최대 N회`/`N회까지`/`N–N회`/`N-N회`/
  `max_x = N`) 또는 병렬·투기적 금지 문구가 재삽입되면 RED.

## [0.24.7] — 2026-08-03

### Changed
- `spec-reviewer`의 `tools:`에 `WebSearch` 추가 — 기존 `Read, Grep, Glob, WebFetch`는
  URL은 열 수 있는데 찾을 수는 없는 비대칭이었다(순수 억제, 아무것도 보호하지 않음).
  이제 `Read, Grep, Glob, WebSearch, WebFetch`.
- `coverage-mapper`의 `tools:`에 `WebSearch, WebFetch` 추가 — 주제가 요구하는 커버리지
  차원을 제안하는 역할인데 웹 도구가 아예 없었다. 이제 `Read, Grep, Glob, WebSearch, WebFetch`.

### Added
- `test_spec_reviewer_frontmatter.sh` · `test_coverage_mapper_frontmatter.sh`에
  조용한-열화 방지 락 신설 — `tools:`에서 `WebSearch`/`WebFetch`가 사라지면 RED.
  Law 2 `for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor` 루프와 `mcp__`
  assert는 그대로 두었다 — 두 도구 추가가 그 루프를 통과하는지 GREEN으로 확인.

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
