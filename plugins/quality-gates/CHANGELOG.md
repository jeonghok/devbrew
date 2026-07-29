# 변경 로그

`quality-gates` 플러그인의 주요 변경 사항을 기록합니다.
포맷은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), 버전 규칙은 [SemVer](https://semver.org/spec/v2.0.0.html)를 따릅니다.

## [2.14.3] — 2026-07-29

### Fixed
- **Law 2 도구 표면 락이 빈 코퍼스 위에서 PASS를 내던 것** — `shopt -s nullglob` 하에서
  `plugins/*/agents/*.md`가 하나도 안 맞으면 루프가 통째로 skip되고 `violations=0`이라
  *"PASS: 모든 agent 가 tools: allowlist 를 선언하고…"* 가 rc 0으로 출력됐다. **0개 파일을
  검사하고 전칭명제를 참이라 선언**한 것이다. glob 불일치(디렉토리 구조 변경·오타난 fixture
  root·잘못된 cwd)는 위장이 아니라 흔한 편집 사고이고, 그 사고가 보안 락을 조용히 0으로
  만든다. 스캔 개수를 먼저 세어 0이면 FAIL하고, PASS 문구가 **실제 스캔 개수**를 보고한다.

## [2.14.2] — 2026-07-28

독립 Claude 리뷰와 codex conformance 감사가 v2.14.0/v2.14.1 이 락에 **새로 집어넣은** 결함
세 건을 실측으로 잡았다. 이번 라운드는 그 셋만 닫는다 — 락의 선행(pre-existing) 값-경로
결함 4건은 사용자 결정으로 별도 사이클에 남겼고 기록만 했다
(`docs/audits/2026-07-28-agent-tools-lock-value-path-gaps.md`).

### Fixed
- **A-1 (Critical) 진단 env var 가 진짜 위반을 은폐** — v2.14.1 이 추가한 `DECL` 진단은
  agent 루프 **안에서 fd 1** 로 printf 했다. stdout 이 쓰기 불가면(`>&-`) 그 printf 는
  실패하지만 bash 의 stdio 버퍼에 내용이 **남고**, 바로 뒤 L3 토큰 루프의 process
  substitution 이 fork 하는 자식이 그 버퍼를 상속해 **토큰 파이프로 flush** 한다. 토큰 루프는
  도구 이름 대신 DECL 텍스트를 읽고 금지 도구를 놓쳤다. 실측(`tools: Read, Write` 픽스처):

  | | 정상 stdout | stdout 닫힘(`>&-`) |
  |---|---|---|
  | EMIT 미설정 | rc=1 | rc=1 |
  | EMIT=1 | rc=1 | **rc=0** ← 진짜 Law 2 위반이 PASS |
  | `5b0caff`(브랜치 이전) | — | rc=1 |

  진단은 이제 **전용 fd 3** 으로만 나간다. fd 3 은 시작 시 *호출자 제공 → stdout 복제 →
  `/dev/null`* 순으로 **항상 쓰기 가능**하게 확정하므로 실패한 쓰기가 없고, 따라서 상속될
  버퍼도 없다. `exec` 리다이렉션은 영구적이라 `2>/dev/null` 은 그룹으로 스코프한다(안 그러면
  이후 모든 FAIL 메시지가 조용히 사라진다).
- **A-2 (Critical) 파서가 못 읽는 문서에 "도구 0개" 를 단언** — `tools:[]` 처럼 콜론 뒤
  구분자가 없으면 YAML 에서 그 콜론은 mapping indicator 가 **아니다**. 실측(PyYAML 6.0.3):
  `tools:[]` 와 `tools:Read, Grep` 은 둘 다 ScannerError(문서 전체가 root scalar). 그런데
  v2.14.0 카브아웃은 정규형 판정을 `tools:*` glob 으로만 해서 이 줄을 통과시켰고, 그 위에서
  `[]` 정확 일치가 걸려 basis `zero-seq` — 즉 *"이 agent 는 도구가 0개"* 를 **적극적으로
  단언**했다. `5b0caff` FAIL → `c982607` PASS → `199d682` PASS 로, 카브아웃 커밋이 만든 결함.
  이제 값 해석 **前에** 콜론 뒤 YAML 구분자(space/tab/줄끝)를 요구하고 그 밖은 FAIL.
- **A-4 절반만 쓸린 stale count** — 락 본문의 "8 실 agent" 서술을 실제 수(17)로 정정.
  같은 라운드가 파일 상단의 형제 occurrence 만 고치고 이 줄을 남겼다. mutation 하니스의
  동일 서술과 stale 케이스 수도 함께 정정.

### Changed
- **A-3 형태 화이트리스트의 경계를 의도적으로 재설정** — v2.14.1 의 여집합 화이트리스트가
  거절하던 네 형태를 codex 가 "정당한 YAML" 로 보고했는데, PyYAML 로 재보니 **둘만** 진짜
  over-reject 였다. 그 둘만 연다:
  - column-0 블록 시퀀스 항목(`skills:` 다음 줄의 `- code-review`) — 단, **직전 column-0 키의
    값이 비어 있을 때만** 허용한다. `tools: []` 뒤의 column-0 `- Write` 는 파서에게
    ParserError 이므로(실측) 계속 거절해야 한다 — 완화가 새 lock-GREEN/파서-불가 간극을
    열지 않게 하는 조건이다.
  - `.` 을 포함하거나 `_` 로 시작하는 최상위 키(`x.y: 1`, `_foo: 1`). 키 정규식을
    `^[A-Za-z_][A-Za-z0-9_.-]*:` 로 넓혔다 — 이 문자들로는 `tools` 라는 키 이름을 만들 수
    없으므로 "키 문자열 = 바이트 그대로" 근거가 그대로 성립한다.

  나머지 셋은 **계속 거절하고, 그 근거를 코드 옆에 적었다**("이건 유효한 YAML 을 거절한다"는
  버그 리포트를 받고 이 목록을 푸는 다음 사람을 위해):
  - merge key `<<: *anchor` — 앵커가 `tools` 를 실으면 파서는 column-0 `tools:` 줄이 **하나도
    없는 문서에** 도구 목록을 부여한다(실측 `tools: ['Write']`). 다만 정직하게: 거기에
    column-0 `tools: []` 를 덧붙이면 YAML merge 의미론상 **명시 키가 merge 를 이긴다**(실측
    `tools=[]`). 그래서 이 거절은 오늘 유일한 방벽이 아니라 **두 번째 독립 방벽**이다 —
    유지하는 이유는 락이 앵커를 따라갈 수 없고, 거절을 풀면 안전성이 *"부재 검사 + 파서의
    merge 우선순위"* 라는 **락이 실행하지 않는 파서의 두 성질**에 얹히기 때문이다.
  - document-end 마커 `...` — 파서도 못 읽는다(ParserError). 통과시키면 A-2 와 같은 클래스다.
  - 인용 키 — 열면 `"tools":` / `'tools':` / `"\x74ools":` 스펠링이 같이 열린다. 이
    화이트리스트가 존재하는 이유가 바로 그 열거를 닫는 것이다(v2.14.1 S-1). 실 agent 17개 중
    인용 키를 쓰는 파일은 0개라 거절 비용도 0.

### Added
- mutation 하니스에 **A-1 회귀 락 16 케이스** — `EMIT` 값(미설정/`0`/`1`/임의) × stdout
  가용성(정상/닫힘)의 **모든 조합**이 위반 코퍼스에서 RED, 정상 코퍼스에서 GREEN 이어야
  한다. 이빨 증명: 진단 emission 의 `>&3` 을 지우는 **한 줄 수정**으로
  `EMIT=1 · stdout=closed` 케이스가 GREEN 으로 뒤집힌다(45→61 assertion).
- differential 하니스에 **A-2/A-3 코퍼스 12 케이스** — 구분자 없는 두 형태, 완화된 네 형태
  (블록 시퀀스 · 빈-값 키의 인라인 주석 · dotted key · leading-underscore key), 유지된 네
  형태(merge key 2 변형 · document-end · 인용 키), 그리고 완화가 새로 열지 않았는지 확인하는
  세 가드. 각 케이스는 락 verdict 와 **PyYAML 이 같은 바이트에서 실제로 resolve 하는 값**을
  동시에 못 박아 경계가 우연이 아니라 의도로 고정된다(60→92 assertion).
- differential 하니스의 DECL 소비를 fd 3 계약으로 전환(`3>&1 1>/dev/null`). 진단이 stdout 을
  공유하면 A-1 이 부활하므로 채널을 호출자가 명시적으로 주는 것이 그 계약이다.

## [2.14.1] — 2026-07-28

두 건의 독립 감사가 v2.14.0 카브아웃을 **우회 가능**하다고 보고했다. 락은 frontmatter 를
`grep`/`sed`/`case` 로 읽는데 실제 소비자는 YAML 파서다 — 둘이 *어느 줄이 `tools` 키인가* 와
*그 값이 무엇인가* 에 대해 서로 다를 수 있었고, 카브아웃이 그 간극의 가장 나쁜 사례를
도달 가능하게 만들었다. 이번 수정의 원칙은 **스펠링을 하나 더 열거하지 않는 것**이다.

### Fixed
- **S-1 중복 키 fail-open** — 중복 가드의 `^tools:` 정규식은 콜론 앞 공백을 못 봤다. 실측:
  `tools: []` + `tools : [Write]` 에서 가드가 발화하지 않고 `grep -m1` 이 `tools: []` 를 집어
  카브아웃으로 통과, 그런데 PyYAML 은 같은 문서를 `{'tools': ['Write']}` 로 resolve 한다 —
  락은 zero-tool 이라 믿고 런타임은 `Write` 를 부여한다(Law 2 보장 전면 무효화).
  `"tools":` · `'tools':` · `tools   :` 도 같은 키로 resolve 된다.
  - 대응 (1) — 중복/정규형 판정을 인용 키와 콜론 앞 공백까지 포함하도록 넓힘.
    후보가 2개 이상이면 중복으로 FAIL, 1개인데 column 0 의 정규 `tools:` 가 아니면 FAIL.
  - 대응 (2) **닫힘 보증** — (1) 은 여전히 열거이고 `!!str tools:` · `&a tools:` ·
    `? tools\n: …` · `"tools":` · flow mapping 은 열거로 잡히지 않는다(전부 실측으로
    같은 `tools` 키로 resolve 확인). 그래서 **여집합**으로 닫는다: frontmatter 의 column-0
    줄은 `# 주석` 이거나 `^[A-Za-z][A-Za-z0-9_-]*:` 여야 한다. 이 형태 안에서는 키 문자열이
    바이트 그대로라(plain scalar 에는 인용·이스케이프·태그·앵커가 없다) 대체 스펠링이
    **원리적으로** 존재할 수 없다. block mapping 의 키는 반드시 column 0 이고 값의
    continuation 은 반드시 들여쓰기되므로 키 공간이 전부 덮인다.
- **S-2 값 패딩 fail-open** — 값 정규화의 POSIX `[[:space:]]` 트림이 코드 주석과 CHANGELOG 가
  주장해 온 "수평 공백"보다 넓었다. `tools: <CR>[]` 는 v2.14.0 에서 RED→GREEN 으로 뒤집혔고
  (`[[:space:]]` 에 CR/VT/FF 포함), UTF-8 로케일에서는 `tools: <NBSP>[]` 의 트림 결과가 정확히
  `5b 5d` 가 되어 카브아웃이 열렸다 — 파서는 그 값을 빈 시퀀스가 아니라 **문자열** `'\xa0[]'`
  로 읽는다. 코드포인트 열거(U+1680·U+2000..200A·U+202F·U+205F·U+3000·U+FEFF…)는 닫히지
  않으므로 여집합으로 간다:
  - 값에 ASCII 제어문자(tab 포함)가 있으면 FAIL. 실측(PyYAML 6.0.3): `tools:` 값 안의
    CR/VT/FF/TAB 은 위치를 불문하고 ScannerError/ReaderError 다(YAML 은 tab 을 노드 구분자로
    금지) — 즉 파서가 읽지도 못하는 선언이므로 거절이 곧 **정확한 합치**다.
  - 값의 패딩 자리(첫 graphic 문자 앞 / 마지막 graphic 문자 뒤)에 ASCII space 아닌 바이트가
    있으면 FAIL. 인라인 주석은 파서가 값에서 버리므로 검사 사본에서만 벗겨 한국어 주석을
    over-reject 하지 않는다(본 흐름은 무변경 — 주석 제거를 앞당기면 `tools: [] # x` 가
    카브아웃으로 새어 수용이 **넓어진다**).
  - 트림을 `LC_ALL=C` 의 `[[:blank:]]`(= space + tab) 로 좁혀 문서가 주장하는 것과 일치시킴.
- 같은 클래스의 파생 — 주석 introducer 판정도 `LC_ALL=C [[:blank:]]` 로 고정. YAML 이 `#` 을
  주석 시작으로 보는 조건은 space/tab 선행뿐이라 NBSP 선행 `#` 은 파서에게 값의 일부인데,
  로케일 의존 `[[:space:]]` 는 그것을 주석으로 벗겨 `tools: Read<NBSP># x, Write` 의 `Write` 를
  놓쳤다.

### Added
- `tests/test_agent_tools_lock_differential.sh` — **파서 합치 증명**(S-3). 60 assertion.
  `test_agent_tools_lock_mutation.sh` 는 락 **술어의 모양**만 증명한다 — 그 45 케이스는 위
  두 우회를 **45/45 GREEN 인 채로** 통과시켰다. 이 하니스는 코퍼스마다 락 verdict 를 PyYAML 이
  같은 바이트에서 실제로 resolve 하는 값과 대조해 *"락이 GREEN 을 준 파일은 파서가 실제로
  파싱할 수 있어야 하고, zero-tool 근거로 통과했다면 파서도 **실제 빈 시퀀스**로 resolve 해야
  하며, scalar 근거로 통과했다면 토큰 집합이 정확히 같아야 한다"* 를 단언한다.
  - 두 레이어를 분리해 센다: **L1 verdict** 는 의존성이 없어 항상 실행되고, **L2 파서 합치**는
    테스트-타임 의존성(PyYAML)이 없으면 **loud 하게 skip** 한다(`‼️ DEGRADED` 배너 + 요약의
    `SKIPPED` 카운트). 조용히 pass 로 세지 않는다. 락 자체는 regex 기반 fail-closed 로 남는다 —
    파서는 락을 **검증**하는 도구이지 락을 **실행**하는 도구가 아니다.
  - "락이 믿은 값" 은 재구현하지 않고 `DEVBREW_AGENT_TOOLS_LOCK_EMIT=1` 진단 emission(verdict
    무영향, 기본 off)에서 읽는다. 테스트에 재구현하면 같은 버그를 두 번 쓰게 되어(순환)
    NBSP 우회가 그대로 새어나간다.

### Changed
- v2.14.0 항목의 *"콜론 앞뒤 수평 공백은 기존 trim 이 이미 처리"* 서술을 정정(아래 주석 참조).
  히스토리를 조용히 고쳐 쓰지 않고 해당 항목에 정정 주석을 남긴다.

## [2.14.0] — 2026-07-28

repo-wide Law 2 락 `tests/test_agent_frontmatter_keys.sh`에 **리터럴 빈 시퀀스 카브아웃**을
추가. 락은 flow-sequence `tools: [...]`를 통째로 거절했는데, 그 결과 *"도구를 하나도 갖지
않는다"* 를 선언할 수 있는 형태가 리포에 하나도 남지 않았다 — zero-tool 격리 리뷰어를
선언하려는 플러그인이 이 락과 자기 락 사이에서 어떤 형태로도 양쪽을 만족할 수 없었다.
**보안 컨트롤 편집이므로 카브아웃은 가능한 가장 좁게** 열었다.

### Changed
- `tests/test_agent_frontmatter_keys.sh` L2 — `tools:` 값이 **정확히 `[]`** 이면(콜론 앞뒤
  수평 공백은 기존 trim 이 이미 처리 — ⚠️ **정정: 아래 주석 참조**) flow-seq 거절을 면제한다.
  flow-seq 전면 거절의 근거는
  *"토큰이 다음 줄로 이어지거나 쪼개져/숨어 금지 이름 정확매칭을 피할 수 있다"* 인데, 리터럴
  빈 시퀀스에는 **숨길 토큰이 0개**라 그 근거가 적용되지 않는다.
- 같은 FAIL 메시지에 *"도구를 하나도 주지 않으려면 정확히 `tools: []` 로 쓸 것"* 안내를 추가.

**카브아웃이 열지 **않는** 것 (전부 계속 FAIL, mutation 으로 락함):**
`tools: [Write]` · `tools: [ Read ]` · `tools: [Read, Write]` · `tools: [ ]`(내부 공백만 있어도
정확 일치가 아니다) · `tools: [], Write` · `tools: []Write` · `tools: []` 다음 줄의 들여쓴
continuation · bare `tools:`(YAML null — 런타임이 *"키 미설정 = 전 도구 허용"* 으로 읽을 수 있는
silent fail-open 이며 빈 시퀀스와 **다른 값**이다).

카브아웃 술어는 2바이트 문자열 `[]` 에 대한 **정확 일치**이고 `case` glob 이 아니라 `[ = ]`
문자열 비교다(`case` 패턴의 `[]` 는 bracket expression 으로 해석될 여지가 있어 조용히 뜻이
달라진다). 그리고 카브아웃은 이 `case` 의 거절만 면제하고 **`continue` 하지 않는다** — 아래
multiline continuation 가드를 건너뛰면 `tools: []` 다음 줄에 들여쓴 `Write` 를 붙이는 우회가
열린다(그 케이스도 mutation 으로 락함).

### Added
- `tests/test_agent_tools_lock_mutation.sh` — 카브아웃 경계 11 케이스(GREEN 3 / RED 8). 34 → 45.

> ⚠️ **정정 (v2.14.1, 2026-07-28)** — 위 *"콜론 앞뒤 수평 공백은 기존 trim 이 이미 처리"* 는
> **사실이 아니었다.** 당시 trim 은 POSIX `[[:space:]]` 였고 이는 수평 공백보다 넓다 — CR·VT·FF
> 는 물론 UTF-8 로케일에서는 NBSP(U+00A0) 등 비-ASCII 공백까지 먹었다. 그래서 `tools: <CR>[]`
> 가 이 릴리스에서 RED→GREEN 으로 뒤집혔고 `tools: <NBSP>[]` 도 카브아웃을 통과했다(파서는
> 후자를 빈 시퀀스가 **아니라** 문자열 `'\xa0[]'` 로 읽는다). 또한 위 *"전부 계속 FAIL,
> mutation 으로 락함"* 목록은 **중복 키 우회를 포함하지 않는다** — `tools: []` + `tools : [Write]`
> 는 이 릴리스의 45 mutation 을 전부 통과했다. v2.14.1 이 두 결함을 모두 닫고 트림을 실제로
> 수평 공백(`LC_ALL=C [[:blank:]]`)으로 좁혔다. 이 항목은 히스토리 보존을 위해 원문을 남기고
> 정정만 덧붙인다.

## [2.13.0] — 2026-07-19

Review gate 리뷰어 구성을 **고정 로스터 → 스코프-구동 동적 구성**으로 전환. 오케스트레이터가
diff 스코프로 Tier C 전문가를 선택(모델 판단 + scout 힌트 + review-pr §4 rubric + scope-signal
팔레트)하고, 고정 보안 floor(security-reviewer + adversarial)와 codex availability-floor는
스코프 무관 항상 유지. **qg 에이전트 tool posture는 #104 락(`Read, Grep, Glob`) 그대로 무변경** —
순수 라우팅 기능.

### Added
- Review gate 3-tier 리뷰어 구성: Tier A floor(security-reviewer + adversarial, 항상) /
  Tier B codex(availability-floor) / Tier C 스코프-선택 전문가(pr-review-toolkit 5 +
  feature-dev:code-architect, 최대 6 후보).
- review-pr §4 rubric(스코프 신호 → 전문가 매핑) + scope-signal 팔레트(역직렬화·인젝션·XSS·
  crypto·TLS·XXE·GHA·SRI·deps·migration·public-API·삭제 파일) SKILL embed.
- 매 iteration 선택/제외 transparency 라인(`> [quality-gates] Review iter N — 선택:… / 제외:…`).
- scout `docs_touched` 입력 신호(경계 = filter-docs.sh doc-path 집합) → docs 변경 시
  comment-analyzer를 phase2 힌트로.
- Tier C 미설치 시 graceful degradation loud log(floor + codex는 무영향).

### Changed
- scout.py를 권위 selector에서 **힌트 provider로 강등**(결정론 로직·테스트 유지; 선택은 모델 판단).
- README §166 Review 단계를 3-tier 모델로 재작성 + prerequisites에 pr-review-toolkit·feature-dev를
  Tier C optional dependency로 선언.
- README의 fan-out consent 게이트(`len(phase1)+len(phase2)>=4 → AskUserQuestion`) 주장을 전 위치에서
  reconcile — 이 게이트는 구현된 적 없다(documented-not-implemented). P22 instantiation을
  transparency 라인 + 선언된 max fan-out(phase-1 병렬 ≤ 8, 총/iteration ≤ 10) + authoring
  hard-review 기반으로 restate.
- stale RED 회복: `test_codex_dispatch_invariant.sh`·`test_scout_codex_integration.sh`를 새
  3-tier dispatch 구조에 맞게 갱신.

### Fixed
- codex depth-계약 whole-file reconcile(`/qg` self-dogfood C5): §166이 codex를
  availability-floor(전 depth)로 재작성했으나 Cost 섹션은 `standard`/`deep`-only를 계속 주장한
  자기모순 해소 — README Cost 노트를 availability-floor화 + Deep 비용행의 codex depth-귀속 제거.
- `test_codex_backward_compat.sh` Check 2를 폐기된 standard/deep-only 계약 assert에서 v2.13.0
  availability-floor 계약(무조건·스코프 무관 + unavailable-degrade)으로 재작성(body-unique
  anchor·mutation-teeth). Check 3의 무관한 pre-existing red는 범위 밖 잔존.
- `test_readme_scope_reconcile.sh`에 codex-depth 재정합 회귀 락 추가(Law 3 compounding):
  fan-out 전용이던 lock이 못 본 C5 부류를 봉쇄 — availability-floor positive +
  standard/deep-only negative(teeth 검증).

### Principles Instantiated
- P8 (determinism-economy / harness lightness) — 리뷰어 선택은 model-owned routing; 결정론은
  floor 불변·transparency·rubric-embed에만.
- Law 2 (Writer ≠ Reviewer) — qg floor tool posture 무변경(#104 `Read, Grep, Glob` 락 유지).
- Law 3 (Compounding) — scout 힌트·rubric·팔레트가 미래 리뷰어 선택의 학습 substrate.

## [2.12.0] — 2026-07-19

### Security
- **`pr-understanding-builder` MCP 유출 경로 봉쇄** — 이 agent 는 README 가 *"파일시스템·네트워크 tool 0개"* pwn-request 방어로 광고해 왔으나, 실효 격리는 존재하지 않는 필드(`allowedTools`) + 11개 이름 denylist 였고 **그 denylist 에 `mcp__*` 가 없어** tavily 웹검색·chrome-devtools 브라우저 제어를 보유하고 있었다. `tools:` 단일 무해 항목 allowlist 로 전환해 광고된 계약을 **처음으로 사실로** 만들었다.
- **8개 agent 전부 `tools:` allowlist 로 전환** (fail-closed). 이전에는 8/8 이 denylist 만으로 격리돼 `Agent`(위임 사슬)·`Bash`·모든 MCP 도구를 보유했다 — 트랜스크립트 census 실측으로 리뷰어 3종이 서브에이전트를 실제 스폰했고 그중 둘이 `general-purpose`(Write 보유)를 띄운 것이 확인됐다.

### Changed
- **`allowedTools` 키 제거 (BREAKING for agent 저자)** — 공식 subagent 규격의 필드가 아니라 조용히 무시된다. agent 격리는 `tools:` allowlist 로 선언한다. `allowed-tools`(command/skill)와 `--allowedTools`(CLI)는 **실재·정상**이며 무관하다.
- `runtime-verifier` 의 죽은 `allowedTools` 22개를 `tools:` 로 이관 + `list_network_requests` 1개 추가 = 23개 — chrome-devtools 는 **per-tool 그대로**(서버 단위 grant 는 표면을 넓혀 `upload_file` 유출 벡터를 준다). network 도구는 persona Hard Rule 5 의 network-status 증거를 위해 추가하되 `get_network_request`(auth 헤더·토큰 노출)는 least-privilege 로 제외. `Bash`·`Write`·`Edit`·`MultiEdit` 는 `# TOOL-EXCEPTION:` 마커로 근거를 명시.
- **`artifact-critic`·`artifact-adversarial`(v2.11.0 산출물 비평 루프의 신규 agent)도 `tools: Read, Grep, Glob` allowlist 로 이관** — origin/main 병합 시 repo-wide 락 불변식(모든 agent = `tools:` allowlist) 유지.
- 레거시 AC15 락(`tests/test_agent_frontmatter_keys.sh`)이 **camelCase 허구 대신 `tools:` allowlist 를 강제**하도록 뒤집힘. **34 mutation 으로 이빨 증명**(YAML 우회 17종 RED + over-reject 방지 GREEN; 락은 '단일 라인 plain scalar 만 허용, 그 외 전부 거절' whitelist).
- 레거시 AC14 스캐너(`hooks/session-start-advisor.py`)가 죽은 `allowedTools` 를 경고. kill switch 불변.

### Fixed
- `README.md` 의 거짓 서술 정정 — *"실제 키 `allowedTools`"* · *"Layer 1 없이 Layer 2/3 는 불완전"* · *"네트워크 tool 0개"*. `codex-reviewer` 의 3-layer 서술은 이중으로 죽어 있었다: 필드가 무시됐고, T3-3 에서 agent 자체가 스크립트로 이관돼 frontmatter 가 사라졌다.
- **`/qg` self-dogfood(Review gate) 하드닝** — publishing SKILL 의 빌더 격리 서술을 정직화(빌더가 inert `Read` 를 보유한다는 사실 반영; prose lock 을 조사 변종까지 확장). frontmatter 락의 YAML-구문 우회(inline-comment·anchor·tag·multiline)를 whitelist 재설계로 봉쇄. codex 독립 재검증 3라운드가 적발한 self-regression 다수 수정.

## [2.11.0] — 2026-07-17

`/qg`에 비-코드 산출물(문서·스펙·계획·설정·산문)용 **비평 → 수정 → 재비평** 자율 루프
모드를 추가한다. inherit-tier `artifact-critic` + `artifact-adversarial`(+ 설치 시 codex
co-reviewer)가 read-only로 §10 스키마 finding을 내고, 오케스트레이터(writer)가 수정 →
**라운드별 git 커밋** → 재비평한다. 판정(수렴·수정·stagnation)은 산문이 아니라 결정론
헬퍼(순수 함수)가 내려 테스트·감사 가능. 별도 skill `critiquing-artifacts`로 위임 —
기존 2게이트(Review/Runtime) 파이프라인은 무변경.

### Added
- `commands/qg.md` `critique` 라우팅: `/qg critique <path>` 또는 자연어 비평 의도 →
  `Skill("quality-gates:critiquing-artifacts")` (코드 파이프라인 우회; 결정론 진입 +
  모델-소유 NL 라우팅, P8).
- skill `critiquing-artifacts`: 진입 게이트(E0 kill switch → E1 코드/비-코드 분류 →
  E2 브랜치 안전 → E2b clean 전제 → E3 upfront 동의)와 bounded 루프(critic → 조건부 codex
  → adversarial → synthesize → 수렴 → 수정 → **커밋-전 변경신호** → 커밋 → stagnation).
- 에이전트 `artifact-critic`·`artifact-adversarial` (`model: inherit`, read-only —
  `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`).
- 결정론 헬퍼: `classify_artifact_target.py`(E1 3분기), `artifact_branch_guard.sh`(C4/AC8),
  `artifact_path_auth.py`(symlink 가드), `artifact_change_signal.sh`(커밋-전 신호),
  `artifact_commit.sh`(원자적 단일-경로 커밋), `synthesize_artifact_findings.py`
  (key+synth: dedup/verdict/kept/수렴/degraded), `artifact_max_rounds.sh`(clamp),
  `artifact_stagnation.py`(predicate).
- codex 산출물 서브파이프라인: `build_artifact_codex_prompt.py` +
  `extract_codex_artifact_yaml.py` + `run_artifact_codex_reviewer.sh`(`-s read-only`;
  미가용/런타임 실패 각각 구분된 graceful degrade).
- kill switch `DEVBREW_QG_DISABLE_CRITIQUE`(모드 전용); env `DEVBREW_QG_CRITIQUE_MAX_ROUNDS`
  (0..10 clamp, 기본 5).

### Changed
- **버전 2.10.3 → 2.11.0** (minor — 새 표면: 산출물 비평 루프 모드).
- `tests/test_qg_publish_docs.sh` 버전 핀을 `2.10.x` → `≥2.10 minor`로 완화(minor bump
  stale-red 방지; publish 표면 shipped 불변식은 유지).

### Principles Instantiated
- Law 1 (Clarity Before Code) — 자율 수정 전 E3 upfront 동의 게이트.
- Law 2 (Writer ≠ Reviewer) — read-only 리뷰어 + 오케스트레이터 writer + 매 라운드 독립
  critic 게이트.
- Law 3 (Compounding) — 라운드별 커밋 감사추적; 버그가 리뷰 탈출 시 critic/adversarial
  페르소나 편집이 compounding 이벤트.
- P18 (bounded autonomy) — max-rounds + stagnation predicate + kill switch.
- P8 (determinism-economy) — NL 라우팅은 모델 신뢰, 결정론은 `critique <path>` + §10 스키마.

## [2.10.0] — 2026-07-07

`/qg` 파이프라인이 비중단 완료되면 커맨드 계층이 "PR 이해글을 이어서 생성·게시?"를
한 번 opt-in offer한다("예" → 기존 `publishing-pr-understanding` skill을 command→skill
체이닝으로 실행; consent·secret-scan 게이트 무변경 — offer + 자체 consent = 2 touchpoint).
파이프라인 tool-set 무변경(`Skill` 미추가, NG6) — 비중단 완료 시 fail-safe
`publish-eligible.md` sentinel만 Write하고 커맨드가 그걸 보고 offer한다. 부수로
`pr-understanding-builder`가 PR 이해글을 한국어-primary로 저술.

### Added
- `commands/qg.md` post-pipeline publish offer (kill-switch → sentinel 유효성 →
  `AskUserQuestion` → "예" 시 `Skill(publishing-pr-understanding)`, 관측가능 실패 시
  `/qg-publish` floor). `allowed-tools`에 `AskUserQuestion` 추가.
- `quality-pipeline` SKILL이 비중단 완료 시 `.claude/quality-gates/<sid>/publish-eligible.md`
  sentinel Write(Final Summary disposition≠aborted + Runtime R6 비중단 terminal).
- `pr-understanding-builder` Korean-primary style law(G3, 독립 — 고정 영문 스키마
  헤더 유지).
- 종료 offer는 `DEVBREW_QG_DISABLE_PUBLISH=1`뿐 아니라 전역 `DEVBREW_DISABLE_QUALITY_GATES=1`
  에서도 skip된다(offer step-1이 두 kill switch를 모두 존중 — 전역 kill이 setup-qg의 stale-sentinel
  삭제보다 먼저 exit하므로 offer가 직접 체크; kill switch는 보안 컨트롤).

### Changed
- `setup-qg.sh`가 매 Preflight마다 stale `publish-eligible.md`를 지운다(--ensure
  조기 exit 앞) — sentinel이 항상 이번 run 반영. `/qg --reset` rm 목록에도 포함.
- `setup-qg.sh` 전역 kill(`DEVBREW_DISABLE_QUALITY_GATES=1`) 브랜치도 stale sentinel을
  구조적으로 지운다(arg-parse보다 앞이므로 `CLAUDE_CODE_SESSION_ID`로 resolve + 패턴
  guard) — offer 미발동을 qg.md step-1 prose뿐 아니라 sentinel 부재로도 보장. cleanup
  실패(예: non-writable dir) 시 `set -e`가 kill-switch advisory를 마스킹하지 않도록
  loud WARN(`>&2`)으로 degrade하고 advisory·exit는 그대로 도달.
- README·publish SKILL NG5 프레이밍 정합: "종료 시 command-layer opt-in offer는
  있으나 자동 실행 아님(consent-gated; 세 번째 게이트 아님; gh는 게이트에 없음)".
- **버전 2.9.0 → 2.10.0** (minor — 새 표면: 종료 시 publish continuation offer).

## [2.9.0] — 2026-07-05

코드를 읽지 않는 사람이 PR을 이해하도록 하는 PR-understanding 산출물 생성(read-only
opus 빌더, blob-only) + consent·시크릿 가드 하의 멱등 게시(별도 skill, gh 격리)를 추가.
결정론은 비가역 체크포인트 2곳(secret-scan 값-차단 / marker 모호-REFUSE)에만; 나머지는
페르소나 + preview 경고(§8 lightness). Review gate 순수성(gh 부재) 보존.

### Added
- `pr-understanding-builder` 에이전트 (`model: opus`, `allowedTools: []` — 파일시스템
  tool 0개; 유일 입력 = inlined build-pr-context.sh blob).
- `publishing-pr-understanding` skill (`/qg-publish [--dry-run]`) — gh를 가진 유일
  orchestrator. preflight→build→generate→scan→preview→consent→publish→report.
- 스크립트: build-pr-context.sh, diagram-facts.sh, secret-scan.py(FAIL CLOSED),
  pr-detect.sh, comment-upsert.py(comment.user.id 스코프 멱등), render-terminal.py(공용
  STATUS 표 + ASCII diagram + accuracy-warnings), gh-identity.sh(인증 user login+numeric
  id 조회; `gh api user` 캡슐화 — SKILL 본문엔 raw gh api 없음, empty id는 fail-closed).
- kill switch `DEVBREW_QG_DISABLE_PUBLISH` (최내부 sink, fail-closed).

### Changed
- `quality-pipeline` Final Summary를 render-terminal.py 공용 STATUS 표+트리로 (always-on
  `/qg` 출력; publish opt-in과 분리된 core 변경).
- `post-tool-use.py` — publish sentinel 존재 시 `/qg` 재유도 억제 (AC11).
- **버전 2.8.0 → 2.9.0** (minor — 새 surface: PR-understanding generate/publish):
  `plugin.json`, README "인스턴스화한 원칙"/설치된 Hook/Kill switches/Cost/구조,
  `commands/qg.md` Quick Reference 동기화.

### Security
- **Sink fail-closed 하드닝** (Review gate self-dogfood — codex/security-reviewer/
  silent-failure-hunter가 잡은 fail-open 3건):
  - `pr-create.sh` — `set -euo pipefail` + `git push`/`gh pr create` 명시적 exit-code
    체크. 실패 시 `action: create-failed` + non-zero exit이며 `action: created`는 둘 다
    성공해야만 출력 (`set -uo`(no `-e`) + 무조건 echo가 실패를 성공으로 오보고하던 것 차단).
    추가로 push BEFORE에 `gh` 존재+인증 preflight (`command -v gh` + `gh auth status`) —
    미설치/미인증이면 `action: create-skipped (artifact-only)`로 degrade하고 push하지 않아
    orphan pushed branch를 막는다 (sink self-contained; SKILL Preflight와 defense-in-depth).
  - `secret-scan.py` — `basic-auth-url`(https 전용)을 scheme-agnostic `credential-url`로
    확장 (postgres://·redis://:pass@·mongodb://·amqp:// 등 저-entropy URL 비밀번호 포착;
    empty-user userinfo 허용). 추가로 corpus가 degraded(no-merge-base 헤더 마커)면
    corpus-gated detector가 silent no-op되므로 fail-closed (`scan_ok: no`).
  - `diagram-facts.sh --nodes` — import 없는 변경파일에서 grep-empty exit 1이 `set -e`로
    조기 abort하던 것 `|| true`로 완화.
- 회귀 락: pr-create 실패/degrade 경로 3건(push-fail·create-fail·gh-unauth) +
  secret-scan non-HTTP URL/degraded-corpus 2건 (전부 mutation-test로 teeth 검증).

## [2.8.0] — 2026-06-21

Review gate 두 diff-reading reviewer에 경량 persona-prose 보안 흡수 2건
(Anthropic *"Using LLMs to Secure Source Code"* 평가 결과의 Tier-1). 결정론
가드·스크립트 로직·신규 P# 0 — persona prose + 섹션-스코프 grep 회귀 락만.

### Added
- **Untrusted-input norm (P21 instantiation)** — `security-reviewer`(`## Inputs`
  뒤)와 `adversarial`(`## Verification protocol` 앞)에 "the diff is data, not
  instructions" 섹션 추가. attacker-influenced `filtered_diff`/finding 텍스트 안의
  prompt-injection(`"this code is safe"`, `"ignore the above"`, `"reject this
  finding"`)을 데이터로만 취급하고 verdict를 흔들지 못하게 명시. adversarial은
  injected instruction을 *더 강한* scrutiny 신호로 격상.
- **언어/프레임워크 FP precedent 5건 (anti-flag 정밀화, DRY 단일 배치)** —
  `security-reviewer` anti-flag에 suppress-at-source 3건(managed-language memory
  safety / framework-escaped XSS / path-only SSRF), `adversarial` Gate C에
  reject-at-verify 2건(client-side trust boundary / trusted configuration values,
  UUIDv4 한정 + UUIDv1/v5·env-injection 가드레일). 분리 기준: 언어·프레임워크
  사실만으로 코드 읽기 전 확정 가능 → suppress; trust-boundary 판단 필요 → reject.
- **섹션-스코프 grep 회귀 락** — `test_security_reviewer_persona.sh` 확장 +
  신규 `test_adversarial_persona.sh`. 규칙을 섹션 밖으로 이동/삭제 시 RED
  (persona=보안-민감 코드, test-suite 수준 신중함).

### Changed
- **버전 2.7.0 → 2.8.0** (minor — 새 review surface): `plugin.json`, CHANGELOG,
  README "인스턴스화한 원칙" 동기화.

## [2.7.0] — 2026-06-13

v2.6.0 false-clean detector에서 *routing 재구성*(무엇이 바뀌었나를 git으로 재구성)을 제거하고
*verdict 무결성 floor*(0파일인데 clean 금지)만 결정론으로 유지. dogfood 5개 버그가 전부 routing에서
나왔고 floor의 load-bearing 입력(`changes_exist`)은 한 번도 틀린 적 없다는 관찰에 따라 버그원천과
가치원천을 분리. `check-review-scope.sh`는 `changes_exist`만 emit하는 103줄(로직 52줄)로 축소되고, redirect
게이트·`$effective_diff_scope`·`DEVBREW_QG_DISABLE_SCOPE_REDIRECT`는 제거. routing은 모델 +
`/qg branch` escape hatch + 정직 norm 한 줄에 위임. 정상 경로(scope>0 / genuine no-op)는 무변경.
devbrew P8 determinism-economy + harness lightness instantiation(결정론은 load-bearing 무결성
floor 한 점에만; routing은 모델 신뢰).

### Removed
- **Empty-scope redirect 게이트** (SKILL Step 1b + `## Empty-scope redirect decision` 섹션 전체):
  빈 scope 시 3옵션 AskUserQuestion(branch diff / honest-empty / stop) + union 재계산. routing은
  모델 영역이므로 구조적 게이트 불필요(lightness; 사용자 "구조적 redirect 제거" 결정).
- **`$effective_diff_scope` single-source 변수 배선** (SKILL Step 1 + scout/dispatch/inlined-blob):
  redirect 전파용 캐시 변수. redirect 제거로 소비자 소멸 — scout/reviewer dispatch/codex blob은
  이제 모델-소유 scope를 직접 참조.
- **kill switch `DEVBREW_QG_DISABLE_SCOPE_REDIRECT`** (SKILL / qg.md / README): redirect 게이트와
  함께 제거. floor는 kill switch 없는 load-bearing 컨트롤로 유지.
- **`check-review-scope.sh`의 routing 출력**: `signal`(4-way) / `resolved_count` / `merge_base` emit,
  `mode`(session/branch/paths) 인자, `paths` glob union. 단위 테스트의 mode/paths/signal 케이스 제거.

### Changed
- **`scripts/check-review-scope.sh` 139줄 → 103줄 (로직 52줄)**: 단일 책임을 *"resolved scope가 비었는데 변경이
  있나?"*에서 *"브랜치/워킹트리에 변경이 존재하나?"*로 좁힘. emit = `changes_exist` / `branch_ahead_count`
  (변경 파일 수) / `worktree_dirty` / `base` / `degraded`. load-bearing fix 보존(F2 remote-only base
  `base`/`base_ref` 분리, NG4 `--exclude-standard` untracked, degraded fail-open + loud advisory).
- **정직-verdict floor (SKILL Step 4.5)**: 캐시된 `$scope_signal == empty_scope_with_changes` 대신
  `$resolved_scope_file_count == 0 AND $changes_exist == yes`(두 결정론 신호의 곱)로 발동. 차단력
  무손실 — `changes_exist`는 모델 clean 주장과 무관한 객관 신호. degraded면 fail-open + loud advisory.
- **honesty norm 한 줄 추가 (SKILL Step 1b)**: 모델이 review-scope를 소유하고, 빈 scope + 변경 시
  `/qg branch` 제안 또는 honest verdict를 내도록 명시. routing(모델)/integrity(floor) 분리.
- **버전 2.6.0 → 2.7.0** (minor — surface 제거 + 동작 단순화, false-clean 차단 contract 보존):
  `plugin.json`, SKILL 제목 + Final Summary, harness 버전 assertion(`v2.6.0`→`v2.7.0`) 동기화.
- **README `인스턴스화한 원칙` self-honest-floor bullet + `commands/qg.md` Scope/kill-switch 문서** 갱신.
- **신규 테스트 `tests/test_qg_false_clean_floor.sh`** (fail-closed e2e): false-clean 차단 + happy-path
  clean + genuine no-op clean + degraded fail-open.

### Fixed
- **degraded 신호가 shallow clone을 실제로 감지** (`check-review-scope.sh`: `git rev-parse
  --is-shallow-repository` 가드 추가): SKILL degraded advisory와 AC4가 v2.6.0부터 "shallow → degraded"를
  광고했으나 스크립트는 shallow를 체크하지 않아, merge-base가 grafted boundary commit으로 해석되는
  shallow 클론에서 약속된 fail-open이 발동하지 않던 doc↔impl gap을 봉쇄. `tests/test_check_review_scope.sh`에
  shallow 회귀 케이스 추가(fixture `--is-shallow-repository == true` 자체를 단언해 vacuous-pass 방지).
- **harness floor anchor 강건화** (`tests/harness/test_skill_orchestration_behavior.sh`): `changes_exist == yes`가
  honesty-norm 라인에도 등장해 단독 grep이 floor 회귀 시에도 vacuous PASS하던 문제를, floor 라인에만 유일한
  결합 패턴(`resolved_scope_file_count == 0 AND …changes_exist == yes`)으로 교체.
- **데이터 git-query를 C2 fail-open으로 통일** (`check-review-scope.sh`): `branch_ahead_count` 계산이
  `git diff … | wc -l` 파이프(파이프라인 exit status가 `wc`의 것 → git 실패가 삼켜짐)였고 `worktree_dirty`가
  `-n "$(git diff/ls-files …)"`였던 탓에, sanity/base 통과 후 git 쿼리가 실패하면 `changes_exist: no` +
  `degraded: no`(false-clean 방향 fail-CLOSED)가 되어 스크립트 자신의 C2 "fail-open on uncertainty" 계약을
  위반하던 문제를 봉쇄. 세 쿼리를 모두 `var=$(git …) || emit_degraded` 직접-할당 idiom(line 64 merge_base와
  동일)으로 전환 → 실패 시 fail-open(degraded). `tests/test_check_review_scope.sh`에 git-shim 회귀 케이스 추가.

## [2.6.0] — 2026-06-07

Review gate가 *검토받았다고 믿는 scope*와 *실제 resolve한 scope*가 silent하게 발산할 때
("커밋 후 빈 세션 → resolved scope 0 → clean"의 false-clean)를 봉쇄. 새 read-only 신호
`check-review-scope.sh`가 단일 `signal`을 emit하면 SKILL이 Review iter-1에서 1회 호출·캐시해
(A) redirect 게이트(P17, kill 가능)와 (B) 정직-verdict floor(P8, kill 불가)로 소비. Runtime은
R2 직후 비대칭 명시 한 줄만 additive. session 기본값·genuine no-op clean·`/qg branch`는 무변경.
devbrew P8 determinism-economy instantiation(결정론은 정확성 floor 한 점에만; redirect/routing은
모델 신뢰).

### Added
- **`scripts/check-review-scope.sh` (신규, read-only)**: scope mode(session/branch/paths)별
  `resolved_count` / `branch_ahead_count` / `worktree_dirty` / `base` / `signal`을 emit.
  signal ∈ {`empty_scope_with_changes`, `normal`, `genuine_noop`, `degraded`}. 단일 base
  진실원(origin/HEAD → origin/main → origin/master → local main → master); 불확실 환경은
  `degraded` + exit 0 fail-open. `tests/test_check_review_scope.sh` (AC1–AC5).
- **Empty-scope redirect 게이트 (SKILL Step 1b + `## Empty-scope redirect decision`)**:
  `signal == empty_scope_with_changes` AND kill switch 미설정일 때만 1회 발화(앵커
  `review scope is empty`, 고유). 3옵션(branch diff / honest-empty / stop) 각각 관측 가능한
  출력 라인. kill switch `DEVBREW_QG_DISABLE_SCOPE_REDIRECT=1`.
- **정직-verdict floor (SKILL Step 4.5, 결정론)**: `signal == empty_scope_with_changes`이면
  clean으로 귀결되는 두 sub-case(`suppressed=0`·`suppressed>0`) 모두에서 verdict 라벨을
  `no scope reviewed … NOT certified clean`으로 교체. redirect 게이트와 같은 캐시 신호를 소비해
  발산 불가; 게이트 우회·kill switch에도 불변(load-bearing).
- **Runtime scope transparency 라인 (SKILL Step R2→R3, additive)**: `> Runtime scope: full project …
  regardless of Review scope`. 새 게이트·diff-scope 강제·동작 변경 없음.
- **Degraded scope 신호 loud advisory (SKILL Step 1b)**: git 부재/detached HEAD/no-base/shallow 등으로
  scope 신호가 `degraded`면 fail-open(redirect 게이트·floor 미발화)하되 그 사실을 1줄 loud advisory로
  노출(`> [quality-gates] scope check degraded … verdict not floor-protected this run.`) — CLAUDE.md
  loud-logging graceful degradation 준수.

### Changed
- **버전 2.5.0 → 2.6.0** (minor, 새 surface): `plugin.json`, SKILL 제목 + Final Summary,
  `test_skill_orchestration_behavior.sh` 버전 assertion(`v2.5.0`→`v2.6.0`) 동기화.
- **Empty-scope verdict 라벨**: resolved scope=0 + 변경 존재 시 더 이상 단독 `clean`이 아님.
  genuine no-op(변경 없음)·`normal`·`degraded` 경로의 `clean`/transparency 문구는 무변경.
- **README `인스턴스화한 원칙`**: P8 self-honest verdict floor bullet 추가.
- **`docs/philosophy/devbrew-harness-philosophy.md`**: P8 determinism-economy에 self-honest
  verdict floor 흡수(새 P# 없음).

### Fixed
- **Remote-only base branch fail-open (`check-review-scope.sh`)**: `origin/main`은 있으나
  local `main`이 없는 흔한 토폴로지(fresh clone / CI checkout / worktree)에서 base가 bare 이름
  (`main`)으로 resolve돼 `git merge-base main HEAD`가 실패→`degraded` fail-open→false-clean 보호가
  *모든 모드(`/qg branch` 포함)에서* 무력화되던 결함을 봉쇄. 표시용 `base`(short name)와 git-usable
  `base_ref`(실제 존재하는 ref, 예 `origin/main`)를 분리해 merge-base/diff에 `base_ref` 사용.
  회귀 테스트 `case_base_origin_head_no_local_main` 추가(기존 `case_base_origin_head`는 local main을
  유지해 이 경로를 한 번도 검증하지 못한 커버리지 갭이었음). codex 모델-다양성 리뷰 + adversarial
  repro로 발견·확정.
- **정직-floor가 "Review branch diff" redirect에서 over-fire (SKILL Step 1b/4.5)**: redirect로 scope를
  branch로 재해석한 뒤에도 iter-1에 캐시된 `$scope_signal`(=`empty_scope_with_changes`)을 갱신하지
  않아, 실제로 검토된 깨끗한 branch(kept=0)를 floor가 `0 files reviewed … NOT certified clean`으로
  잘못 라벨하던 결함(안전 방향이나 자기모순 메시지)을 수정. redirect 분기에서 `$scope_signal=normal`로
  갱신하고, 검토 타깃을 재-resolve 가능한 이름 대신 script가 emit한 `$merge_base` 커밋 SHA로 사용해
  orchestration 계층의 동일 fail-open도 함께 제거. `check-review-scope.sh`가 `merge_base` 필드를 추가
  emit; harness AC13 앵커를 SHA-reuse로 갱신.
- **Stale-after-redirect: reviewer dispatch가 redirect 후에도 preflight scope를 읽던 결함 (SKILL)**:
  "Review branch diff" redirect가 scope를 branch로 재해석해도 reviewer dispatch(`diff_scope`)·scout·
  inlined diff blob은 *preflight* scope("as resolved at preflight")를 읽어, redirect 후에도 비었던
  session scope(0 files)를 리뷰해 redirect가 silent하게 무력화될 수 있었다(F1과 동일 결함 class —
  redirect가 갱신한 값을 downstream consumer가 stale하게 읽음). 단일 `$effective_diff_scope` 변수를
  Step 1에서 정의하고 redirect 분기에서 `$scope_signal=normal`과 **함께** 갱신, 모든 consumer
  (scout C1 / dispatch C2 / inlined blob C4)가 이를 읽도록 배선. 모순되던 "as resolved at preflight"
  문구 제거. harness에 negative guard(해당 문구 부재) + redirect가 두 값 모두 갱신하는지 정적 검증 추가.
  adversarial completeness sweep로 consumer 전수(C1–C8) 확정(C5 floor는 F1에서 이미 봉쇄).
- **paths-mode가 committed branch-ahead 파일을 empty로 오신호 (`check-review-scope.sh`)**: `/qg --paths
  <committed-file>`가 clean tree에서 `git diff HEAD`만 세어 resolved_count=0→`empty_scope_with_changes`로
  오신호(안전 방향 over-review지만 redirect 잡음). resolved_count를 `(git diff HEAD) ∪ (merge_base..HEAD)`
  교집합 globs로 계산(중복 제거)해 committed 매치도 포함 — count를 올릴 뿐 false-clean은 불가능.
  회귀 테스트 `case_paths_committed_branch_ahead` 추가.
- **worktree-only trigger에서 redirect FALSE-CLEAN (SKILL Step 1b redirect)**: `empty_scope_with_changes`는
  worktree-only(`worktree_dirty=yes`, `branch_ahead_count=0`)에서도 발화하는데, 추천 옵션 "Review branch
  diff"가 `merge_base..HEAD`(committed-only, 이 경우 **빈** diff)를 리뷰하고도 `scope_signal=normal`을 설정해
  **0 files를 clean으로 인증**하던 결함(unsafe direction — 이 기능이 막으려던 바로 그 harm). redirect 리뷰
  대상을 signal을 유발한 **모든 변경의 UNION** = `git diff $merge_base`(merge_base SHA→워킹트리, committed-ahead
  + tracked-uncommitted 포함) + non-ignored untracked로 변경. two-dot `$merge_base..HEAD` 대신 working-tree
  inclusive `git diff $merge_base` 사용 — `branch_ahead_count=0`이면 `HEAD==merge_base`라 워킹트리 변경을 실제로
  리뷰. union이 `changes_exist`(branch_ahead OR worktree_dirty)와 정확히 일치하므로 `normal` 설정이 항상 valid.
  `<M>` 표시·question 문구를 union count로 정정(worktree-only에서 오해 소지 있는 "0 ahead" 제거). harness
  union/false-clean 정적 가드 추가. codex closure pass로 발견.
- **redirect scope가 retry iteration에서 preflight로 revert (SKILL Step 1)**: redirect는 iter-1 Step 1b에서만
  `$effective_diff_scope`를 갱신하는데 retry(iter 2-5)는 Step 1로 돌아가 raw preflight scope를 재해석할 수
  있었다(Step 1b는 N=1-only). redirect 해소 후 `$effective_diff_scope`/`$scope_signal`을 **모든 잔여
  iteration에서 canonical**로 고정(iter 2-5는 preflight 재해석 금지). harness persistence 정적 가드 추가.
- **F2 회귀 테스트 하드닝 (`test_check_review_scope.sh`)**: `case_base_origin_head_no_local_main`에 명시적
  `git fetch -q origin` + `merge_base != '-'` assertion 추가(remote-tracking ref 생성을 git config 무관하게
  보장 + 토폴로지가 조용히 degrade-fail-open하지 않았음을 입증).

## [2.5.0] — 2026-06-07

암묵 session scope로 Review gate가 돌 때 그 사실을 사용자-가시 한 줄로 밝히는 **scope 투명성**을
추가. 버려진 결정론적 under-coverage 경고(B1 후보)를 결정론 가드가 아니라 *모델 행동*으로 대체 —
git 비교·차단 로직 없음. devbrew P8 determinism-economy refinement instantiation
(철학 §P8 / §5.6 "Zero hooks" 일반화; "harness lightness — trust the model").

### Added
- **Scope 투명성 (SKILL diff-scope step, iteration N=1)**: scope가 암묵 default(session)로 풀릴 때
  1회 `> Review scope: session (N files this session). 전체 PR/브랜치는 /qg branch.` 출력.
  명시적 `/qg branch`·`--paths`는 침묵. 결정론 가드 아님("scope==session?"만 봄, git 비교 없음).
- **NL scope-의도 trust note (SKILL + `commands/qg.md`)**: 자연어 branch/전체 리뷰 의도를 모델이
  별도 토큰 parser 없이 branch scope로 해석. `/qg branch`는 결정론적 escape hatch로 유지.

### Changed
- **버전 2.4.0 → 2.5.0** (minor, 새 surface): `plugin.json`, SKILL 제목(L39)+Final Summary,
  `test_skill_orchestration_behavior.sh` 버전 assertion(`v2.4.0`→`v2.5.0`) 동기화.
- **README `인스턴스화한 원칙`**: P8 determinism-economy bullet 추가.

## [2.4.0] — 2026-06-04

full `/qg`(gate arg 없음)가 trivia escape 후 어떤 게이트도 돌기 전에 **gate-scope 질문**
(Review gate only / Run both gates)을 1회 발화한다. devbrew Law 1(Clarity Before Code)
instantiation — 실행 범위를 의식적 결정으로 승격. 무클릭 둘 다는 새 `/qg both` arg로.

### Added
- **Upfront gate-scope 결정 (SKILL `## Upfront Execution Plan` Decision 1)**: trivia escape 후
  Review gate dispatch 전, binary AskUserQuestion(앵커 `both gates`, header `Gate scope`).
  "Review gate only" → Runtime 단계 short-circuit; "Run both gates" → Decision 2(runtime scope)로.
- **`/qg both` arg**: `gate` 도메인에 `both` 추가 — gate-scope 질문 없이 두 게이트 실행
  (`review`/`runtime`과 대칭). gate scope만 pre-answer하므로 `requires_decision` surface가 있으면
  Decision 2는 그대로 발화(오늘날 무인자 `/qg`와 동일).
- **신규 protocol-shape assertion** (`test_skill_orchestration_behavior.sh`): gate-scope 질문 존재
  (`question:.*both gates` + header `Gate scope`) · 순서(Review gate dispatch 앞 + runtime-scope 질문 앞) ·
  앵커 고유성 · `gate both` 문서화 · `gate=` precedence advisory · Dispatch Loop↔Upfront 정합.

### Changed
- **기본 동작**: full `/qg`(gate arg 없음)가 더 이상 무클릭으로 둘 다 돌지 않고 gate scope를
  1회 묻는다. 무클릭 둘 다는 `/qg both`. "zero-click happy path"는 *재정의* — gate-scope는 1회
  upfront 클릭(또는 `/qg both|review|runtime`이면 0), 이후 happy path는 무클릭.
- **버전 2.3.0 → 2.4.0** (minor, 새 surface): `plugin.json`, SKILL 제목 + Final Summary,
  `test_skill_orchestration_behavior.sh` 버전 assertion(`v2.3.0`→`v2.4.0`) 동기화.
- **SKILL frontmatter description / `commands/qg.md` / README P18**: gate-scope always-asks 정합.

### Fixed
- **`commands/qg.md`**: stale "3-gate" → "2-gate" 파이프라인 레이블 정정 (v2.0.0에서 게이트 2개로
  축소된 뒤 잔존한 라벨; adversarial agent의 per-finding 3-gate 검증과는 무관).
- **single-gate `/qg runtime` manifest 회귀 (self-`/qg` review 적발)**: `detect-runtime.sh`를
  Decision 2(gate scope=both 전용)로 옮기면서 Dispatch Loop를 우회하는 `/qg runtime`이
  `manifest`/`approved_surfaces`/`block_policy` 없이 R3에 도달 — spec §3 Non-goal("single-gate
  동작 무변경") 위반이었다. Runtime gate에 **Step R-init** 추가: 해당 입력이 미설정이면
  `detect-runtime.sh` + runtime-scope 기본값을 그 자리에서 생성(Decision 2 이미 실행 시 no-op).
- **Review-only 모드의 "Proceed to Runtime gate" 모순 (self-`/qg` review 적발)**: Decision 1에서
  "Review gate only" 선택 후에도 iter-boundary/max-iter 결정이 "Proceed to Runtime gate"를 제시해
  방금 한 gate-scope 선택과 충돌했다. 두 결정에 **gate-scope conditional** 절 추가: review-only이면
  "Proceed (accept findings, finalize)"(→ final summary)로 대체.
- **`/qg both`가 preflight에서 깨짐 (self-`/qg` review codex conf 10 적발)**: SKILL/command/docs에 `both`를
  추가했지만 `scripts/setup-qg.sh`는 `review|runtime`만 파싱 → `both`가 `Unknown argument: both`로 exit 1,
  skill 진입 전 파이프라인 abort. setup-qg.sh가 `both`를 수용(case arm + `branch` lookahead + help +
  Full-Pipeline 배너)하도록 수정. `test_setup_qg.sh` Case 6 회귀 가드 추가.
- **`gate=` precedence가 skip 로직에 미배선 (self-`/qg` review codex 적발)**: Decision 1의 "명시 `gate=`가
  `--skip-runtime`을 이긴다" 규칙이 문서에만 있고 실제 skip 검사는 raw `skip_runtime`을 봐서
  `/qg runtime --skip-runtime`이 runtime을 조용히 skip할 수 있었다. `effective_skip_runtime` 정규화
  도입(Arguments) + Dispatch Loop step 4 / Runtime gate 진입 검사를 그 값으로 전환. `setup-qg.sh` 배너도
  동일 precedence 반영(`both`/`runtime` + `--skip-runtime` → 모순적 "skipped" 대신 advisory; codex 2차 적발).
- 위 **네 회귀**는 다단계 subagent 리뷰(per-task spec+quality + 최종 Opus whole-branch)를 모두 통과했고
  **codex 독립 리뷰(read-only 샌드박스) + pr-review-toolkit code-reviewer가 self-`/qg`에서 적발** —
  Claude-only 리뷰가 full-pipeline 경로만 추적해 single-gate / preflight-script 경로를 놓쳤다. 보안·정합
  컨트롤엔 codex 독립 리뷰 필수(메모리 재확인). 신규 protocol-shape + setup-qg assertion으로 전부 박제.

## [2.3.0] — 2026-06-04

Review gate가 각 iteration 종료 시 `synthesize_findings.py`의 finding 상세(표 +
counts + suggested fixes)를 결정 tool **이전에** 사용자에게 surface한다. 이전에는
AskUserQuestion `<summary>` 한 줄만 노출됐고 상세는 접힌 tool 출력에 묻혔다.
가시성=명확성(Law 1) 개선이며 reviewer persona(`agents/*.md`)는 무변경(보안 리뷰 불필요).

### Added
- **`synthesize_findings.py` 표 렌더**: `render()`가 불릿 목록 대신 Markdown 표
  `| Sev | Path:Line | Conf | Summary | Source |` + `**Findings:**` counts 헤더
  (severity별 count, 항상 3-severity) + 표 밖 `**Suggested fixes:**` 리스트를 emit.
- **SKILL Review gate `Step 4.5 — Surface findings`**: kept(표시) finding 수 기준으로
  boundary를 판정하고, kept>0이면 script stdout 전체를 결정 tool 직전 surface.
  AskUserQuestion `<summary>`·`## History` 항목은 counts line을 verbatim 추출.
- **신규 테스트**: `test_synthesize_findings.sh` counts/caveat/suppressed-notice/
  fixes/conf-boundary/all-suppressed 케이스, `test_skill_orchestration_behavior.sh`
  surface-순서 `assert_order`(section-heading anchor 금지).
- **표 셀 무결성 (self-`/qg` review hardening)**: `render()`가 셀 값(summary/source/
  file)의 `|`를 `\|`로 이스케이프하고 CR/LF를 공백으로 접어 reviewer LLM 텍스트의
  파이프/개행이 표 구조를 깨지 않게 한다. 미지의 severity는 SUGGESTION으로 정규화
  (stderr 경고)해 counts==렌더 행을 보장 — SKILL boundary가 보이는 finding을 clean
  (kept=0)으로 오판하는 경로 차단. (R4 dogfood `/qg`에서 codex 모델-diversity가 적발,
  code-reviewer 독립 확증.)

### Changed
- **confidence rubric (C30 4-tier)**: `suppress()`가 binary(conf<7 억제)에서 3-way로 —
  conf 5–6은 표시하되 `*` caveat, conf ≤4 비-CRITICAL만 억제, CRITICAL은 confidence
  무관 항상 표시(conf ≤6이면 `*`). caveat 단일 규칙: 표시된 finding의 confidence ≤ 6 ⟺ `*`.
- **`## History` 라인 포맷**: gate verdict 단어 대신 severity count
  (`iter N: 1 CRITICAL / 2 IMPORTANT / 1 SUGGESTION → user chose Retry`).
  `references/state-file-format.md` 예시 동기화.
- **버전 2.2.0 → 2.3.0** (minor, 새 surface): `plugin.json`, SKILL 제목 + Final
  Summary, `test_skill_orchestration_behavior.sh` 버전 assertion 동기화.

## [2.2.0] — 2026-05-31

`runtime-verifier`를 read-only 관찰자에서 **git-worktree 샌드박스 기능-executor**로 전환.
서비스를 띄우고 real user flow를 구동하며 spec Acceptance Criteria 대비 동작을
**증거-접지** 방식으로 단언한다. Write를 허용하되, orchestrator가 immutable baseline
commit 대비 `git diff`로 product 변경을 ground-truth로 잡아 **PASS를 구조적으로 차단**하고
무커밋·샌드박스 폐기로 Law 2 self-approval을 물리적으로 봉쇄한다. 운영 DB/네트워크는
git-ignored 파일(prod `.env`) 미복사로 원천 미접근.

### Added
- **`scripts/qg-worktree.sh create-sandbox`**: working-tree를 byte-faithful 반영한
  일회용 detached worktree 생성(`cp -a`로 mode/symlink/binary 보존, git-ignored 미복사,
  deletion 반영) + immutable baseline commit `B` 봉인. 출력=경로+SHA 2줄.
- **`scripts/qg-worktree.sh mutation-guard`**: `(sandbox, B)`만 입력받는 순수-git product-
  mutation oracle. `tracked_diff` / `disallowed_new_files`(신규 non-ignored 파일 + 모든 신규
  symlink) / `forced_downgrade` emit. verifier 자기판단과 독립 → Law 2 구조적 가드.
- **`detect-runtime.sh` blast-radius 분류**: process-start kind(dev/start/serve, cargo-run,
  go-run, makefile run/serve) + 네트워크/배포/파괴 신호 매칭 surface에 `requires_decision: true`.
  test runner kind은 자동.
- **Upfront Execution Plan** (SKILL): `requires_decision` surface가 있을 때만 1회 발화해
  gate 범위·runtime 범위(`approved_surfaces`)·block 정책(`stop`/`skip`/`ask`)을 확정.
  그 외 zero-click.
- **신규 테스트**: `test_qg_runtime_sandbox.sh`, `test_qg_mutation_guard.sh`,
  `test_detect_runtime.sh` blast-radius 확장, fixtures `gate3/cli-tool`·`gate3/danger-signal`·`gate3/force-flag`.
- **kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`**: 샌드박스 끄고 read-only smoke
  fallback + loud log.

### Changed
- **`agents/runtime-verifier.md`**: `model: sonnet → inherit`; `allowedTools`에
  `Write`/`Edit`/`MultiEdit` + chrome-devtools 상호작용 도구(click/fill/fill_form/type_text/
  hover/press_key/evaluate_script) 추가; `disallowedTools`는 `NotebookEdit`만 유지.
  body를 sandbox-executor 정체성 + spec AC 기능 단언 + evidence-log
  `writes`/`functional_assertions` 섹션으로 재작성.
- **`SKILL.md`**: Runtime gate를 R0(sandbox)~R6(routing)로 재배선, mutation-guard 결과로
  verdict ≤FAIL 강제, spec AC thread, blocked-path 정책 라우팅, cost heads-up. v2.2.0.
- **`check-allowed-tools-order.sh`**: 정전 allowlist에 `qg-worktree.sh` 추가.

### Security
- **Law 2 메커니즘 이전 (도구 deny → git-diff 가드).** `runtime-verifier`의 self-approval
  방지가 `disallowedTools: [Write]`(behavioral tool deny)에서 **orchestrator의 immutable-
  baseline git-diff 가드**(구조적, verifier 주장과 독립)로 이동. 외부 표면(`/qg`)은
  하위호환(additive + gated)이라 minor bump. `test-scope-validator`/`security-reviewer`/
  `adversarial`은 read-only reviewer로 불변. persona 편집은 보안-민감 변경.
- **운영 안전.** 샌드박스가 git-ignored 파일(prod `.env`/자격증명/deps)을 복사하지 않아
  운영 DB/네트워크 접근 경로를 원천 차단. process-start/네트워크/파괴 surface는 upfront
  승인 게이트(blast-radius) 뒤로. OS-수준 egress 격리는 명시적 non-goal(한계 인정).
- **fallback Law 2 보존.** `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`로 샌드박스를 끈 경우에도 verifier는 frontmatter상 Write를 갖지만, orchestrator가 R3 dispatch 전후의 `git status --porcelain` 차이로 실제 working-tree mutation을 잡아 verdict를 ≤FAIL로 강제 + loud warn — 구조적 Law 2 보장이 fallback에서도 유지(behavioral-only로 격하되지 않음).

### Fixed
- **mutation-guard 5개 우회 봉쇄 (보안).** diff 기반 oracle을 **snapshot + content
  tree-hash + ignore/config-tamper + snapshot-delta**(전부 fail-closed) 4계층으로 재작성.
  닫힌 우회: C-A `info/exclude`/`core.excludesFile`/`.gitignore` 밀반입,
  C-B git-failure fail-open(rc 캡처 → exit 4), C-D `stash`/`commit+reset --hard`
  (reflog/stash snapshot-delta) + 영구 `logAllRefUpdates=false` 억제(config tamper),
  C-E `assume-unchanged`/`skip-worktree` index 비트(fresh-index content-hash).
  snapshot은 per-worktree gitdir 사이드채널(출력 계약 2줄 무변경). 우회별 회귀 테스트 동반.
- **mutation-guard round-2: 6번째 우회(C-NEW-1) + 오탐(I-NEW-2) 봉쇄 (보안).** round-1.5 hardening의
  snapshot이 verifier-writable gitdir에 살아 피검증자가 신뢰 기준을 위조 가능했던 master-key 결함을
  **orchestrator-held digest seal**로 닫음: `create-sandbox`가 snapshot digest를 출력 line 3로 emit →
  orchestrator(SKILL)가 verifier-unreachable 채널로 보유 → `mutation-guard`가 3번째 인자로 받아 신뢰 전
  recompute·비교(위조 시 `guard_fail` exit 4). 추가로 snapshot-독립 **b-precise** 계층 1b를 도입 —
  baseline `.gitignore`만 신뢰 ignore 소스로 인정하고 `info/exclude`·`core.excludesFile`로만 숨겨진 신규
  파일(일반 파일 + symlink)을 2차 baseline-anchored read-tree pass의 git-diff 집합차로 포착(I-NEW-1
  symlink-only 갭 흡수, `node_modules` 등 baseline-ignored 산출물은 미플래그하여 usability 보존).
  I-NEW-2(empty-index false-positive)는 계층 1 임시 index를 `read-tree B^{tree}`로 시드해 제거
  (force-tracked ignored 파일 무변경 시 `forced=no`; C-E catch·`.env` PASS 보존).
- **Law-3 review-mechanism 강화.** 이 우회를 놓친 `security-reviewer`/`adversarial` persona에 "가드가
  신뢰하는 artifact(snapshot/baseline/config)를 피검증자(Write 보유 subagent·샌드박스 Bash)가 쓰거나
  경로 계산할 수 있는가" 체크 추가 + vacuous H-AC3(ii) 테스트를 rule-only 격리 케이스 + Layer-2 비활성
  mutation-test로 재작성. 출력 계약 2줄 → 3줄(snapshot digest)로 정직하게 변경.
- **mutation-guard F1: b-precise `.qgbak` 백업 경로 무결성 봉쇄 (보안-무결성; codex 모델-diversity 리뷰).**
  round-2 b-precise(계층 1b) crash-recovery가 신뢰하던 *예측가능·verifier-writable* `.qgbak` 백업 경로에서
  모델-diverse codex 리뷰가 6개 무결성 변종(codex-1..6)을 적발 — **전부 self-approval 우회가 아니라**, 가드가
  orchestrator 자신의 `info/exclude`(로컬 ignore 파일)를 손상시키거나 탐지 증거를 지우는 결함. 봉쇄:
  pre-restore를 digest seal **이후**로 이동 + 봉인 snapshot sha와 일치할 때만 복원 + live가
  crash-placeholder(부재/빈 파일) 상태일 때만 복원(rule-only tamper 증거 보존, codex-6) + live/백업
  비정규-파일타입(디렉토리) fail-closed(codex-2/3) + hash-object 실패 fail-closed(codex-4) +
  `restore_excludes`는 *이번 실행이 생성한 백업만* 복원(codex-5) + 계층 1b의 두 `git diff` 파이프라인
  exit-check(codex-1). 변종별 회귀 테스트 R3-AC1(a–e)/R3-AC2(a–b) 동반. **잔여 follow-up**(전부 무결성,
  우회 아님): codex-7 symlink 파일타입, codex-8 restore-`mv` exit-check, codex-9 `cut`/`sort`/`comm`
  exit-check. 근본 재설계(예측가능 경로 → guard-created `mktemp`)는 검토 후 보류(draft 스펙
  `docs/superpowers/specs/2026-06-03-qg-bprecise-backup-mktemp-design.md`).
- **C-C SKILL R4 fail-closed 라우팅.** errored/garbled 가드(exit 4 / `guard_error` /
  무효 key)를 PASS가 아니라 ≤FAIL로 라우팅 + stderr verbatim surface.
- **I-A/I-B fallback SKIP cap.** `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` fallback verdict를
  SKIP_WITH_EVIDENCE로 cap(절대 PASS 아님) + 단일 `runtime_project_dir`(unset `sandbox_dir`
  하드코딩 제거) + real-tree 변경 loud 경고.
- **I-C evidence durability.** evidence-log/스크린샷을 메인 repo 절대 `evidence_dir`
  (`.claude/quality-gates/<sid>/`)에 기록 → 샌드박스 폐기(R5) 생존.
- **I-D YAML escape.** single-quote 파일명을 `yq()`로 escape → 유효 YAML.
- **I-E kill-switch 문서화.** `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX`를 README source-of-truth
  표 + qg.md env 표에 등재.
- **I-F detect-runtime `${HOME:-}`.** unset `$HOME`이 manifest emit을 abort시키던 것 차단.
- **I-G retry baseline 재캡처.** NEEDS_RESOLUTION retry가 새 `sandbox_dir` + `baseline_sha`를
  둘 다 재캡처(옛 sha 재사용 false-FAIL 제거).
- **S-A/S-B create-sandbox 견고화.** overlay `cp`/`mkdir`/deletion + `cd` command-sub에 `|| die`.

> non-goal(한계 인정): `logAllRefUpdates` *flip-and-restore* 변종(끄고→commit+reset→복원)은
> git ground-truth에 흔적이 없어 OS-수준 통제 없이는 구조적으로 닫을 수 없다(spec §3).
> 단 이 변종도 shipping product == baseline.

## [2.1.0] — 2026-05-31

qg가 처음으로 **사용자 프로젝트 spec을 단일 truth로 read**. cycle 위계(spec=truth ⊃
plan=구현 방식)를 instantiate — 그동안 qg는 plan만 읽고 spec은 한 번도 읽지 않아
`test-scope-validator`가 입력을 "spec/plan"으로 융합하고 있었음. spec-conformance는
코드가 *존재*해야만 가능하므로 review/verify 단계인 qg만 닫을 수 있는 비중복 루프
(plan-verify를 v2.0.0이 제거한 것과 비대칭). **advisory only — gate를 block하지 않음.**

### Added
- **`scripts/discover-spec.sh`** + **`tests/test_discover_spec.sh`**: 프로젝트 spec
  우선순위 탐색(`--spec` → `docs/superpowers/specs/*.md`). AC-섹션 적격성 + 최신 mtime
  tiebreak. legacy-global 소스 없음(spec은 프로젝트 artifact). `discover-plan.sh` 거울.
- **`test-scope-validator` `ac_coverage` advisory 블록**: spec 발견 시 AC별
  covered/uncovered + `covered_by` 테스트 ref. note "advisory only — does not block".
- **codex `<spec_context>` 슬롯**: v2.0.0에서 `/dev/null`로 죽어 있던 `<plan_context>`
  슬롯을 부활 — `run_codex_reviewer.sh`가 spec AC 섹션을 script-internal로 추출·주입.
- **kill switch `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`**: spec이 있어도 no-spec 경로
  강제(ac_coverage 생략, codex spec context 비움; validator는 plan-기반 계속).
- **README "Spec Discovery Sources"** 절 + "Principles Instantiated"에 **C66**.

### Changed
- **`test-scope-validator` 기준 축 전환**: 입력 융합(`spec/plan markdown`)을
  `spec_path`(AC truth, primary) + `plan_path`(구현-방식 보조 hint)로 분리.
  cherry-pick-suspicion 기준이 "plan scope" → "spec acceptance criteria scope에
  orthogonal"로 재정의. plan은 강등(제거 아님).
- **`build_codex_prompt.py`**: `<plan_context>`/`{{PLAN_SUMMARY}}`/`<plan_summary_file>`
  → `<spec_context>`/`{{SPEC_AC}}`/`<spec_ac_file>`.
- **`run_codex_reviewer.sh`**: `PLAN_SUMMARY_FILE`/`PLAN_SUMMARY` → `SPEC_AC_FILE`/`SPEC_AC`;
  spec discovery + AC 섹션 awk 추출 + spec 부재 시 loud log를 script-internal로 추가.
- **`SKILL.md`**: `spec_path` 인자 문서화 + test-scope-validator dispatch에 `spec_path:` 줄.
  `allowed-tools` frontmatter는 불변(invocation parity).

### Fixed
- **`agents/test-scope-validator.md:54` spec/plan 융합 해소**: 입력을 문자 그대로
  "path to the spec/plan markdown"으로 적어 spec(truth)과 plan(파생 hint)을 교환 가능한
  한 덩어리로 취급하던 버그 수정 — 위계 복원.

### Unchanged (의도적 보존)
- **`scripts/discover-plan.sh` + `tests/test_discover_plan.sh`**: byte-identical.
  plan *discovery*는 존속(보조 hint), plan *verify*만 v2.0.0이 제거.
- **철학 문서**: 새 P#/AP# 없음 — C66 + Law 1 instantiation(devbrew design-lightness).
- **reviewer agent `disallowedTools` 격리**: 불변(Law 2). spec 읽기는 read-only.
- **advisory invariant**: `ac_coverage`·spec-conformance는 Runtime gate를 block 안 함.

## [2.0.0] — 2026-05-30

**BREAKING.** Gate 1(plan verification) 제거 + wall-clock budget 제거 + 두 게이트
비수치 rename. plan 검증은 상류 `superpowers:writing-plans` / `spec-distill`가 담당하는
중복 단계였고, v1.32.0 single-turn 재설계 후 남은 wall-clock 잔재를 정리.

### Removed
- **`agents/plan-verifier.md`** + **`tests/test_plan_verifier_behavior.py`**: Gate 1
  plan-verifier agent 완전 제거. plan 검증은 writing-plans/spec-distill 소관.
- **`/qg gate1` 서브커맨드**: 제거 (alias 없음).
- **scout `gate1_verdict` 입력 필드** + reviewer dispatch의 `gate1_summary` 핸드오프: 제거.
- **codex per-call 600s wall-clock timeout** (`run_codex_reviewer.sh`의 `timeout 600`
  래퍼·`no_timeout_binary` 분기·`OVERRIDE_REASON=timeout`): 제거. hang 위험은 수용 —
  backstop은 Bash tool timeout + `DEVBREW_DISABLE_QG_CODEX=1` + `/cancel-qg`.
- **README wall-clock budget deferred 노트** + codex "Per-call wall-clock ceiling: 600s"
  표현: 제거.
- **철학 문서 AP16 `(b) wall-clock budget` guard**: 제거 (autonomous-loop guard 4→3개:
  max-iter / repeat 감지 / kill switch).
- **state-file-format `wall_clock_deadline_at`** 행: 제거.

### Changed
- **게이트 비수치 rename**: `Gate 2: PR Review` → **Review gate**, `Gate 3: Runtime
  Verification` → **Runtime gate**. "gate" 명사는 플러그인 이름·`/qg`와 정합 위해 유지.
- **서브커맨드**: `/qg gate2` → `/qg review`, `/qg gate3` → `/qg runtime`.
- **env var**: `DEVBREW_GATE3_MAX_RESOLUTIONS` → `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`;
  `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` → `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION`.
- **hook 키**: `quality-gates:gate3-test-scope` → `quality-gates:runtime-test-scope`.
- **state 필드**: `gate3_max_resolutions` → `runtime_max_resolutions`.
- **내부 식별자**: `max_gate2_iterations` → `max_review_iterations`; `gate3-evidence.md`
  → `runtime-evidence.md`; `gate3_fail` → `runtime_fail`; `gate3_repeat_detected` →
  `runtime_repeat_detected`; synthesize heading `## Gate 2 Findings` → `## Review Findings`.
- **유지**: `scripts/discover-plan.sh` + "Plan Discovery Sources" 문서 (Runtime gate의
  test-scope-validator가 `plan_path:auto`로 소비 — plan *verify*만 제거, plan *discovery*는 존속).
  P22 Cost Awareness·`cost_class`·Cost Class % 표·`detect_codex.sh` 5s probe도 유지.

### Migration (1.32.3 → 2.0.0)

**Deprecated alias 없음** — clean break (P17 사용자 주권 우선, P23 deprecation-window
하우스 룰의 의도적 예외; major bump가 breaking을 신호). 구→신 매핑:

| old | new |
|---|---|
| `/qg gate1` | *(제거 — plan 검증은 writing-plans/spec-distill)* |
| `/qg gate2` | `/qg review` |
| `/qg gate3` | `/qg runtime` |
| `DEVBREW_GATE3_MAX_RESOLUTIONS` | `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` |
| `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` | `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION` |
| `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope` | `...=quality-gates:runtime-test-scope` |

구 `gate1`/`gate2`/`gate3` 서브커맨드와 `DEVBREW_GATE3_*` env는 **즉시 무효** — 스크립트·CI에서
참조 중이면 위 표대로 갱신 필요.

## [1.32.3] — 2026-05-28

PR #71 (v1.32.0 → v1.32.2) merge 후 deferred된 6건의 follow-up.
모든 변경은 비기능적 polish/defense-in-depth (breaking change 없음).
3-round spec review 통과 (8 + 4 + 0 issues 모두 흡수).

### Added
- **`scripts/read-frontmatter.py`**: frontmatter `key: "value"` 파싱
  helper. escape-aware regex로 embedded `\"` / `\\` 처리. 3 call site
  (`pre-pipeline-check.sh` × 2, `cancel-qg-core.sh` × 1)의 `awk -F'"'`
  패턴 대체 (MED-3).
- **`scripts/check-allowed-tools-order.sh`**: SKILL.md `allowed-tools`
  pipeline-order 검증 linter. Canonical source = 내부 `EXPECTED_ORDER`
  배열 (single source of truth). 16 tools 5 groups (I-D).
- **`scripts/check-changelog-korean-primary.py`**: CHANGELOG `[1.32.0]`
  Korean-primary 컨벤션 단락 단위 검증 (I-C). 영구 보존 (향후 항목
  추가 시 재검증 가능).
- **`tests/test_read_frontmatter.sh`**: 5 케이스 — quoted / unquoted /
  missing / embedded-quote (val"ue) / embedded-backslash (a\b).
- **`tests/test_cancel_qg_med4.sh`**: MED-4 검증. mv backup + cp stub +
  `trap '...' EXIT` 패턴으로 fixture stub 통한 실패 경로 검증 (3 assertion:
  stub 메시지 prefix / exit code 1 라인 / sed invocation 0건).
- **`tests/test_check_allowed_tools_order.sh`**: linter 4 시나리오 —
  canonical PASS / within-group swap FAIL / cross-group move FAIL /
  unknown tool FAIL.
- **`tests/fixtures/qg-worktree-fail-stub.sh`**: MED-4 영구 fixture.
  qg-worktree.sh 실패 simulator (exit 1 + stderr 메시지).

### Changed
- **`cancel-qg-core.sh`**:
  - MED-1: qg-worktree.sh 부재/비실행 메시지 self-actionable화. MISSING
    vs EXISTS-but-not-executable 구별, 사용자 직접 실행 명령
    (`git worktree remove --force "<path>"`) 명시.
  - MED-4: pipe-to-stream-editor 제거. `cmd | sed` 대신 stdout/stderr
    병합 capture + 수동 prefix. `if/else` 형태로 `set -e` 안전하게 exit
    code 캡처. qg-worktree.sh 출력 계약(병합 스트림 prefix-emit) 보존.
  - MED-3 transition: `awk -F'"'` 호출부를 `read-frontmatter.py` 호출로
    교체. `SCRIPT_DIR` 변수를 file top으로 끌어올려 lowercase `script_dir`
    정의와 통일.
- **`pre-pipeline-check.sh`**: MED-3 transition 2 site
  (`branch` / `session_id` 파싱). `tr -d '[:space:]'` 제거 (helper가
  `.strip()` 내부 처리). `SCRIPT_DIR` 변수 file top에 추가.
- **`skills/quality-pipeline/SKILL.md`**: `allowed-tools` frontmatter
  pipeline-order 재정렬 (I-D). 5 group 경계를 YAML comment로 inline 문서화.
- **`CHANGELOG.md` `[1.32.0]` body**: English prose → Korean-primary 변환
  (I-C). Technical 사실 변경 없음.

### Fixed
- **`tests/test_pre_pipeline_check.sh`**: MED-2 SID guard 4 boundary
  케이스 추가 — empty / too-short (7 char) / invalid-char (`abc/def123`) /
  valid (15 char + sandbox `git init` + fresh state로 isolation).

### Acceptance Criteria
- AC1 (MED-1): cancel-qg-core.sh stderr 메시지 검증
- AC2 (MED-2): 4 SID boundary 케이스 PASS
- AC3 (MED-3 transition): `awk -F'"'` 0 hits, `SCRIPT_DIR` 정의 확인
- AC4 (MED-3 unit): 5 helper 케이스 PASS
- AC5 (MED-4): sed 0건, exit code 라인 검증
- AC6 (I-C): `check-changelog-korean-primary.py` PASS
- AC7 (I-D ordering): linter exit 0
- AC8 (I-D linter unit): 4 scenarios PASS
- AC9 (regression): 기존 testsuite + 신규 7 test 전체 PASS
- AC10: `plugin.json.version` == `"1.32.3"`
- AC11: 이 CHANGELOG entry 존재

## [1.32.2] — 2026-05-28

### Fixed (Gate 2 iter-2 review-driven follow-up, same PR #71)

- **CRIT-1-iter2**: `pre-pipeline-check.sh` `no_session_id` 와
  `invalid_session_id` 분기에서 `exit 1`로 변경 (이전 `exit 0`).
  setup-qg.sh와 대칭 의미론. SKILL.md preflight P3에 result-code
  enumeration 추가 — 모든 알려진 코드별 downstream action 명시 +
  unknown code는 contract violation으로 abort. silent fall-through
  방지.
- **CRIT-2-iter2**: `cancel-qg-core.sh`에서 `DEVBREW_QG_KEEP_WORKTREE=1`
  시 worktree AND state folder를 unit으로 보존. 이전: state folder만
  무조건 삭제되어 worktree path 가 영구 leak. 이제: 둘 다 보존하고
  loud advisory 출력하여 사용자가 미래 `/cancel-qg`로 회수 가능.
  qg-worktree.sh missing case도 loud diagnostic.
- **I-A-iter2**: plugin.json 1.32.1 → 1.32.2 bump.
  `feedback_plugin_version_bump.md` 메모리 + CLAUDE.md "every PR
  touching plugins/<name>/ must bump that plugin's version field in
  the same commit" 준수. iter-1 commit 이후 cache key 무효화 보장.
- **I-B-iter2**: `commands/cancel-qg.md`의 "v1.32.0 minimal schema"
  표기를 "v1.32.1 minimal schema"로 정정. `gate3_max_resolutions:`는
  v1.32.1에서 추가된 필드 (C3 복구).
- **HIGH-1-iter2**: `LEGACY_V1_KEYS` invariant 주석을 실제 enforcement
  형태와 일치시키고 새로운 V8d source-text 테스트 추가. 이전 주석은
  "AC17 unsplit literal forms do NOT appear" 라는 존재하지 않는 test를
  주장. 이제: behavioral (V8c) + source-text (V8d) 이중 enforcement.
  V8d는 split form 양쪽 존재 + unsplit literal 절대 부재를 grep으로
  검증 — ruff/black auto-fix merging 방어.

## [1.32.1] — 2026-05-28

### Fixed (Gate 2 iter-1 review-driven follow-up, same PR #71)

- **C1-iter1**: `SKILL.md` frontmatter `allowed-tools`에 `AskUserQuestion`
  + `detect-runtime.sh` + `compute-test-scope-candidates.sh` + `detect_codex.sh`
  추가. v1.32.0 단일-턴 설계가 의존하는 도구들이 누락되어 있었음.
- **I-iter1-2**: `commands/cancel-qg.md` v1.32.0 minimal schema에 정렬.
  제거된 v1.5.x 필드(`status`/`current_gate`/`gate2_iteration`) 참조 제거.
- **I-iter1-3**: `scripts/cancel-qg-core.sh` worktree-aware cleanup —
  `pipeline.md`에 `worktree_path:`가 있으면 `qg-worktree.sh remove`
  먼저 호출 (DEVBREW_QG_KEEP_WORKTREE=1 가드). session-end-cleanup.py와
  대칭 의미론.
- **I-iter1-4**: `LEGACY_V1_KEYS` invariant 주석 정확도 개선. `status:`는
  split 안 하는 이유(자기-참조 substring 부재 + 일반성) 명시.
- **I-iter1-5**: `scripts/pre-pipeline-check.sh` SESSION_ID pattern guard
  추가 (`^[A-Za-z0-9_-]{8,}$`). `setup-qg.sh`/`cancel-qg-core.sh`와 일관.
- **I-iter1-6**: SKILL.md Retry error handling option labels 재조정 —
  "Abort retry" / "Skip this file" (이전: "Skip retry / abort" / "Continue
  with next file" — 의미 역전).
- **I-iter1-7**: `references/state-file-format.md` v1.32.1 schema에 정렬.
  `gate2_iteration: 0` 제거 → Removed Fields에 이동. `gate3_max_resolutions:`
  활성 필드로 추가.
- **I-iter1-8**: `agents/runtime-verifier.md`의 `project_dir` input에
  "절대 재계산 금지" 강제 문구 + Forbidden 섹션 항목 추가. 나머지 3개
  reviewer agent와 동일 contract.
- **I-iter1-9**: CHANGELOG C1 entry English-prose → Korean-primary로 재작성.
- **I-iter1-10**: state file watermark `(v1.32.0)` → `(v1.32.1)`
  (setup-qg.sh + state-file-format.md).

### Fixed (Gate 2 review-driven, PR #71)

- **C1**: `SKILL.md` — `project_dir:` threading을 4개 reviewer dispatch
  (`adversarial`, `test-scope-validator`, `security-reviewer`,
  `runtime-verifier`) 전체에 복구. 신규 preflight P0 step에서
  `project_dir=$(pwd)`로 도출 후 매 dispatch에 전달. 워크트리 모드에서
  agent가 `pwd`/`git rev-parse`로 재도출 시 발생하는 coordinate drift 차단.
- **C2**: `pre-pipeline-check.sh` 세션 ID 가드 추가. 같은 세션이
  소유한 `pipeline.md`는 절대 삭제 안 함 (setup-qg P2 → pre-pipeline-check
  P3 race 차단). stderr 권고: `pre-pipeline-check: preserving
  session-owned state file`.
- **C3**: `DEVBREW_GATE3_MAX_RESOLUTIONS` 검증 블록 `setup-qg.sh`에
  복구. 정수 파싱 + clamp 0..10 + default 3. state 파일에
  `gate3_max_resolutions:` 필드로 기록. P18 unbounded-autonomy
  guard 회귀 해소.
- **C4**: `tests/test_setup_qg.sh` v1.32.1 schema 기준으로 재작성.
  제거된 9개 stale assertion (removed schema keys, removed stderr
  warnings) 정리. 새 assertion: --ensure 멱등성, clamp 값, per-session
  folder isolation, schema invariants.
- **C5**: v1 `tests/test_session_start_advisor.py` 삭제. v2 shell
  wrapper (V8a/V8b/V8c)가 대체.
- **C6**: 새로운 `tests/harness/test_skill_orchestration_behavior.sh` —
  SKILL.md orchestration의 protocol-shape 검증 (순서/근접성/섹션
  멤버십). 12개 assertion. V7 tautological substring grep은 같은
  commit에서 삭제 (`grep -c 'PASS'`가 항상 0을 반환해 negative-assertion
  path가 unreachable이었음).
- **I1**: `test_kill_switches.py` advisor sanity 검사를 stderr로 전환
  (v1.32.0 advisor는 stdout이 아닌 stderr에 출력).
- **I2**: `test_worktree.sh` T5 4개 reviewer 모두에 대해 uniform
  `quality-gates:<name>` subagent_type anchor 사용. T9 (state
  frontmatter `project_dir:`) 제거 — v1.32.0 schema에서 의도적으로
  제거된 필드.
- **I3**: `setup-qg.sh` 헤더 주석에서 "Stop hook-based" 표현 제거,
  "in-turn pipeline orchestration (AskUserQuestion-iteration model;
  no Stop hook continuation)"로 교체.
- **I4/I5**: `session-start-advisor.py` silent-failure (OSError /
  JSONDecodeError) diagnostic stderr로 전환. 빈 fallback은 유지
  (advisor가 SessionStart를 crash시키면 안 됨).
- **I6**: SKILL.md Retry path error handling — `Edit` 실패 시
  AskUserQuestion으로 사용자에게 surface ("Retry failed at <file>:
  <reason>. Skip retry / abort? / Continue with next file."). silent
  skip 금지.
- **I7**: `check-trivia.sh` exit code 2 분기 SKILL.md에서 제거
  (script가 절대 2로 종료하지 않음 — unreachable). 0/1 이외의
  non-zero는 script crash로 propagate되어 파이프라인 abort.
- **I8**: README v1.5.0 Stop-hook ASCII 다이어그램 제거. v1.32.0
  AskUserQuestion 다이어그램만 남음. 주변 prose의 "Stop hook" 참조
  제거.
- **I9**: `tests/e2e-scenarios.md` v1.5.0 잔재 (stop-hook.py,
  `<qg-signal>`, gate2_repeat_detected) 4곳 정리.
- **I10**: SKILL.md Retry path file-write safety — reviewer 공급
  `file:` 필드를 `os.path.realpath` + `os.path.commonpath`로 양쪽
  canonicalize. `project_dir` 외부로 escape하는 경로는 `SecurityError`
  raise. AskUserQuestion description에 full canonicalized path
  list 노출. symlink-traversal 회피.
- **I11**: `setup-qg.sh` state 템플릿에서 `gate2_iteration: 0`
  phantom 필드 제거. 실제 iteration counter는 History 섹션에 기록됨
  (spec/plan은 SKILL.md frontmatter에 있다고 잘못 명시했지만, 실제
  위치는 state 템플릿).
- **I12**: `tests/test_readme_state_diagram_complete.sh` v1.32.1 README
  기준으로 전면 재작성. v1.5.0 Mermaid stateDiagram-v2 13-transition
  assertion 삭제, v1.32.0 ASCII pipeline 다이어그램의 10개
  protocol-shape marker 검증으로 전환.

### Fixed (Medium tier)

- LEGACY_V1_KEYS 두 번째 split 완성 (`consecutive_no_signal:` →
  string-concat 형식). v1.32.0이 `current_gate:`만 split한 half-applied
  fix 완성. Invariant 주석 추가 (AC17 acceptance criterion 명시).
- `cancel-qg-core.sh` 추출 (TQ-2): commands/cancel-qg.md와
  tests/test_cancel_qg.sh가 동일 helper 호출. SID pattern guard
  (`[A-Za-z0-9_-]{8,}`) 헬퍼 내장. command-test drift 차단.
- 새 `tests/test_pre_pipeline_check.sh` (C2 회귀 방지). 4 cases:
  fresh_start / same_session_preserved / cross_session_deleted /
  advisory_emitted.
- `test_kill_switches.py`에 `test_skill_setup_qg_honors_disable_kill_switch`
  케이스 추가. `setup-qg.sh`가 SKILL preflight P1 외에 자체적으로도
  `DEVBREW_DISABLE_QUALITY_GATES=1`을 honor (defense in depth).
- `test_skill_orchestration.sh` V2b anchor uniqueness 강화: `findings
  remain`이 `question:` 라인 정확히 1회만 등장해야 함 (다른 AskUserQuestion
  섹션으로의 복사-붙여넣기 차단).
- `test_session_start_advisor_v2.sh` V8 → V8a/V8b/V8c 분리.
  V8a (per-session fixture only), V8b (flat-legacy fixture only),
  V8c (LEGACY_V1_KEYS 3-token fixture-based regression).
- `test_branch_worktree.sh` comment drift 4곳 정리 (stop-hook 참조 →
  AskUserQuestion-cleanup 표현; 삭제된 test_stop_hook_worktree_cleanup.py
  참조 acknowledge).

### Security

- I10: reviewer 공급 path가 `project_dir` 외부로 escape하는 것을 차단
  (`realpath` + `commonpath` 양쪽 normalisation). symlink-traversal
  회피. AskUserQuestion description에 full canonicalized file list
  노출하여 사용자가 매 write surface 가시화.

## [1.32.0] — 2026-05-27

### Breaking
- **Stop hook 제거.** `hooks/stop-hook.py` (1205 LOC, 13-transition state
  machine, wall-clock guard, no-signal counter)가 `hooks.json`의 `Stop`
  event 등록과 함께 삭제됨. Pipeline progression은 이제 `quality-pipeline`
  SKILL 안에서 in-turn serial dispatch로 전적으로 처리됨.
- **`<qg-signal>` emission contract 제거.** SKILL이 더 이상 signal tag를
  emit하지 않음. `# QG-STOP-HOOK-CONTINUATION` sentinel은 어떤 코드 경로에서도
  인식되지 않음.
- **State file shape 변경.** v1.32.0 state file은 minimal: `session_id`,
  `started_at`, `worktree_path` (optional), `gate2_iteration`. 제거된 필드:
  `status`, `current_gate`, `consecutive_no_signal`,
  `max_gate2_iterations`, `gate3_resolution_iter`, `last_gate3_needed_hash`,
  `max_gate3_resolutions`, `skip_runtime`, `single_gate`, `plan_file`,
  `pr_url`, `available_plugins`, `wall_clock_deadline_at`, `project_dir`.
- **Env vars 제거.** `DEVBREW_QG_DEADLINE_MIN`과
  `DEVBREW_QG_NO_SIGNAL_MAX`가 더 이상 존재하지 않음 (wall-clock guard와
  no-signal counter는 stop-hook과 함께 사라짐). 다른 env vars는 미변경.

### Added
- **AskUserQuestion progression primitive.** SKILL이 Gate 1 FAIL, Gate 2
  iter boundary (매 iteration), Gate 2 max-iter (silent halt 대체), Gate 3
  NEEDS_RESOLUTION에서 AskUserQuestion 호출. Same-turn tool 결과가 다음
  dispatch를 구동.
- **Static SKILL orchestration test:** `tests/test_skill_orchestration.sh`
  (V2a gate-order + V2b context-anchor + V7 PASS-proximity heuristic).
- **`/cancel-qg`, `/qg --reset`, `/qg --gc` fixture test:**
  `tests/test_cancel_qg.sh`.
- **Session-start advisor v2 test:** `tests/test_session_start_advisor_v2.sh`
  (V8 legacy advisory + V8-pre code-structure guard).

### Changed
- **SKILL.md** single-gate-per-turn에서 AskUserQuestion gating의
  single-turn-serial dispatch로 재작성.
- **setup-qg.sh**가 minimal state schema를 emit; wall-clock과 gate3-max
  계산 제거.
- **session-start-advisor.py**는 in-flight pipeline detection을 drop;
  legacy v1.x state file을 감지해 one-shot `/cancel-qg` stderr advisory
  emit. Frontmatter scan sub-feature는 미변경.
- **commands/qg.md** Pipeline Rules 섹션 재작성; "Stop hook handles
  progression" 주장 제거.
- **README.md** Hook 테이블이 더 이상 stop-hook.py를 나열하지 않음;
  state diagram은 ASCII single-turn sequence로 교체; Principles 섹션에
  P22 일반화 노트 추가.

### Removed
- `hooks/stop-hook.py`
- `hooks/hooks.json`의 `Stop` event block
- SKILL / scripts / hooks 의 모든 `<qg-signal>` 참조
- stop-hook semantics에 coupled된 obsolete test
  (`test_forward_only_prose.sh` + Task 7에서 감지된 stop-hook-coupled test)

### Migration
v1.x in-flight pipeline은 v1.32.0에서 resume 불가. 업그레이드 후
`/cancel-qg` (per-session) 또는 `/qg --reset` (legacy flat files)을
실행해 옛 state를 clear. SessionStart advisor가 다음 session 시작 시
guide를 emit함.

## [1.31.0] — 2026-05-20

### Changed
- `agents/adversarial.md` — persona 강화. sonnet 시절의 미니멀 "calibration only" 프롬프트를 opus-critic에 맞는 다단계 검증으로 확장: per-finding **3-gate** (real in code? / introduced by THIS diff? / handled elsewhere?), CRITICAL/IMPORTANT용 **severity realist check** (이론적 최악 아닌 현실적 최악 + mitigation, 단 data-loss/security/auth-bypass/financial은 절대 다운그레이드 금지), **cross-reviewer corroboration** 신호, **evidence bar** (증거 없는 CRITICAL/IMPORTANT은 opinion → reject/downgrade), manufactured-outrage 금지. 강화만 — 임계치 완화·규칙 제거 없음 (persona는 보안-민감 코드). 역할(verdict-only, no new findings)·cwd 금지 규칙 보존.
- `agents/adversarial.md` — 출력 스키마를 top-level `verdicts:` wrapper로 정렬 (synthesizer는 이미 wrapper와 bare list 둘 다 수용 — `synthesize_findings.py:32`; behavioral 테스트 fixture와도 일치). `finding_id: <agent>-<file>-<line>` 매칭 키 보존.

### Fixed
- adversarial reviewer model 선언 drift 정합. `agents/adversarial.md` frontmatter와 README 모델 노트는 `sonnet`이라 적혀 있었으나 `SKILL.md` Phase 1.5 dispatch가 `model="opus"`로 frontmatter를 덮어, 실제로는 **opus로 실행**되고 있었음 (세 사이트 불일치). adversarial은 Sonnet Phase 1 워커 위의 **Opus-critic** — Gate 2의 유일한 모델-기반 판단 게이트 — 이므로 의도된 모델은 opus. 세 사이트를 모두 opus로 정합: frontmatter `model: opus`, SKILL은 dispatch override를 제거하고 frontmatter에 위임(다른 qg-owned agent 관례와 일치), README 모델 노트를 opus 근거로 재작성. effective 모델은 변화 없음(원래도 opus 실행); 선언 정합 + persona 강화가 본 릴리스의 변경.

### Added
- `tests/test_adversarial_model_consistency.sh` — drift 가드. 세 선언 사이트(frontmatter / SKILL dispatch / README 모델 노트 + phase 다이어그램)가 opus로 일관됨을 검증. 미래 단일 사이트 편집(예: cost-cut으로 한 곳만 sonnet 변경)이 CI에서 즉시 fail. CLAUDE.md Law 3 — "리뷰를 탈출한 drift는 코드만 패치하지 말고 재발을 잡는 가드를 신설".

## [1.30.1] — 2026-05-20

### Changed
- `agents/security-reviewer.md` — `color: red` → `color: purple`. Cosmetic only; 채도 높은 red가 눈에 쨍해 차분한 purple로 교체. 격리(`disallowedTools`)·로직 영향 없음.

## [1.30.0] — 2026-05-19

### Added
- 5 behavioral test files for surviving leaf agents (plan-verifier, security-reviewer, adversarial, test-scope-validator, runtime-verifier). Each test uses `tests/harness/agent_stub.py` to short-circuit dispatch with frozen YAML fixtures — deterministic, hermetic, no LLM call. 3 tests per agent (AC45 schema/enum, AC46 missing-key-raises, AC47 invalid-yaml-raises) = 15 total. Completes CLAUDE.md Law 3 (Compounding) for the qg agent surface: any future drift in output contract fails CI immediately (T3-4, AC45-AC48).

### Reached
- v1.30.0 — spec upper bound. All 56 acceptance criteria from `docs/superpowers/specs/2026-05-17-qg-tier2-3-improvements-design.md` implemented. Tier 2 + Tier 3 cycle complete.

## [1.29.0] — 2026-05-19

### Removed
- `agents/scout.md` — replaced by `scripts/scout.py`. Depth-decision table was already deterministic in v1.x; LLM was only applying the rules. Saves ~5-15K input + 500 output tokens per Gate 2 iteration. Eliminates scout-fallback path (script can't JSON-parse-fail) — `fallback: false` always (T3-1, AC29-AC33).

### Added
- `scripts/scout.py` — ~70-line rule-based depth + agent selection. Stdin JSON → stdout YAML with `depth`, `phase1_agents`, `phase2_agents`, `rationale`, `fallback`.
- `tests/test_scout_script.sh` — 5 fixture tests covering AC29-AC33 (small whitespace / medium new-files / large config / large+type / large+test).

### Changed
- SKILL.md Phase 0 prose: scout invocation now `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/scout.py` (was: `Agent(subagent_type="quality-gates:scout", ...)`). Frontmatter `allowed-tools` extended.
- `tests/test_scout_codex_integration.sh`: anchor patterns updated to reference scout.py.
- `tests/test_worktree.sh` T5/T8 loops drop `scout` (no longer applies).

## [1.28.0] — 2026-05-19

### Removed
- `agents/synthesizer.md` — replaced by `scripts/synthesize_findings.py`. Algorithm is fully deterministic (5 steps: apply verdict / dedup / suppress<7 except CRITICAL / sort / render Markdown). No LLM judgment was being used; dispatch cost (~3K tokens × every Gate 2 iteration) eliminated (T3-2, AC34-AC39).

### Added
- `scripts/synthesize_findings.py` — ~120-line deterministic post-processor. Accepts `--adversarial <yaml> --findings <yaml>`, emits Markdown to stdout matching the v1.x synthesizer schema.
- `tests/test_synthesize_findings.sh` — 6 fixture-based tests covering AC34-AC39.

### Changed
- SKILL.md Phase 1.6 prose: synthesizer is now invoked via `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_findings.py ...` (was: `Agent(subagent_type="quality-gates:synthesizer", ...)`). Frontmatter `allowed-tools` extended with the new script entry.
- `tests/test_worktree.sh` T8 loop drops `synthesizer` (no longer applies). T5 loop also drops `synthesizer` (no longer an Agent() dispatch).

## [1.27.0] — 2026-05-19

### Removed
- `agents/codex-reviewer.md` — replaced by `scripts/run_codex_reviewer.sh`. Layer 1 isolation now provided by SKILL.md narrow Bash allowlist instead of agent frontmatter `disallowedTools`. Layer 3 sandbox (`codex exec -s read-only`) preserved inside the script (T3-3, AC40-AC44).

### Added
- `scripts/run_codex_reviewer.sh` — independent codex review subprocess (88 lines). Takes `<diff_path> <project_dir> <output_yaml_path>`; emits canonical Phase 1 finding YAML.
- `tests/test_skill_bash_allowlist_narrow.sh` — AC44 regression: SKILL.md `allowed-tools` frontmatter must enumerate specific script paths, never `Bash(*)` wildcard.

### Changed
- `tests/test_codex_reviewer_frontmatter.sh` — rewritten: was a frontmatter grep on the deleted agent; now asserts agent absence + script existence + Layer 3 sandbox preservation.
- `tests/test_codex_dispatch_invariant.sh` — anchor patterns updated to reference the new script invocation prose instead of agent dispatch.
- `tests/test_worktree.sh` T8 — codex-reviewer removed from agent-file project_dir loop (no longer applicable post-T3-3).
- SKILL.md Phase 1 dispatch prose: codex-reviewer invocation is now a Bash script call, not an Agent() dispatch. Frontmatter gains narrow `allowed-tools` entry for the new script.

## [1.26.0] — 2026-05-19

### Fixed
- `tests/harness/agent_stub.py` `run_agent_stub`: guard against `yaml.safe_load` returning `None` for empty/whitespace/`null`/`~` input. Previously the None propagated silently to callers; now raises `AssertionError` naming the agent and fixture. Caught by qg self-review Gate 2 silent-failure-hunter (confirmed by adversarial).
- `tests/harness/agent_stub.py` `assert_yaml_schema`: changed `if enum:` to `if enum is not None:` so an empty `enum={}` dict is treated as "validate against zero constraints" (no-op loop) rather than "skip validation entirely" (silent green). Empty-dict was a real risk for programmatic enum builders that produce zero entries.

### Added
- `tests/test_agent_stub_harness.py`: 2 regression tests covering both fixes (`test_run_agent_stub_raises_on_empty_yaml` over 5 empty-form variants, `test_assert_yaml_schema_empty_enum_dict_is_not_skipped` over no-violation + missing-key compositions). 9/9 tests PASS.

## [1.25.0] — 2026-05-19

### Added
- color: <enum> frontmatter on 5 agents that previously lacked it: adversarial=orange, codex-reviewer=pink, scout=purple, security-reviewer=red, synthesizer=blue. Total 8 agents now color-coded from Claude Code 8-color palette (cyan/green/yellow/blue/red/purple/orange/pink). UX: parallel dispatch threads are visually distinguishable when 5+ reviewers fire concurrently in Gate 2 deep mode (T2-9).
- tests/test_agent_color.sh — dynamic AC53/AC55 verification: every extant agent file has color from the 8-color enum. Survives T3-1/2/3 refactor (which deletes scout/synthesizer/codex-reviewer.md).

## [1.24.0] — 2026-05-19

### Changed
- agents/adversarial.md: model downgrade opus → sonnet. Adversarial task is calibration (confirm/downgrade/reject verdict mapping per finding) — not new generation. Sonnet sufficient at ~5x lower cost per dispatch; savings compound across 3-5 iter Gate 2 fix-loop (T2-8).
- README Cost Class section adds Adversarial reviewer model subsection documenting downgrade rationale + infrastructure-dispatch exclusion policy (scout/adversarial/synthesizer not counted in AskUserQuestion fan-out prompt).

## [1.23.0] — 2026-05-19

### Added
- README §파이프라인 흐름: Mermaid `stateDiagram-v2` block enumerating all 13 stop-hook transition types (`next_gate`, `retry_gate`, `complete`, `abort`, `continue`, `gate2_user_choice`, `max_gate2_exceeded`, `gate3_fail`, `gate3_needs_resolution`, `gate3_repeat_detected`, `wall_clock_exceeded`, `no_signal_inc`, `no_signal_max`). New contributors can see forward-only invariants at a glance — NEEDS_RESTART → user gate (not auto-retry), terminal cleanup paths, both stuck-state guards (T2-7).
- `tests/test_readme_state_diagram_complete.sh` — grep-based drift detection: diagram set must equal authoritative 13-row set (no missing, no superset).

## [1.22.0] — 2026-05-19

### Fixed
- `stop-hook.py` step 8 `except Exception` block: PIPELINE_ERROR routing broadened from `{gate3_needs_resolution, gate3_repeat_detected}` to ALL non-terminal transitions. Forward-progress writes (`next_gate`, `retry_gate`, `continue`, `gate2_user_choice`, `max_gate2_exceeded`, `gate3_fail`) now also abort on persist failure rather than falling through with stale in-memory state. Terminal (complete/abort) intentionally fall through to step 9 cleanup which is independently resilient (T2-6).
- New `TestStateWriteFailureBroadening` contract tests covering AC22 (8 forward-progress transition types emit error) and AC23 (2 terminal transitions are silent).

## [1.21.0] — 2026-05-19

### Added
- SKILL.md `Codex skip 안내` visibility-policy section — for `codex_available: false` responses, 4 of 6 `skip_reason` enum values now emit a one-line stderr message explaining the cause (`not_installed`, `auth_missing`, `timeout_binary_missing`, `known_bad_version`). The other 2 (`kill_switch`, `inside_codex_sandbox`) remain silent by policy (user-intended disable / recursion guard). Fulfills CLAUDE.md "loud logging + graceful degradation" promise — users paying for Codex now know why dispatch was skipped (T2-5).
- `tests/test_skill_codex_skip_prose.sh` — grep-based AC19/AC20/AC21 verification.

## [1.20.0] — 2026-05-19

### Changed
- SKILL.md Phase 1 dispatch: unified `#### Phase 1 (unified dispatch)` section replaces dual headings (primary `#### Phase 1: Critical Analysis` + `#### Phase 1 (legacy/fallback)`). Two parallel gate-path sections collapse into one 4-step linear flow — single dispatch builder = single source of truth for future persona edits (T2-2 / T3-5). Raw line count change is small (+76/-47); the structural gain is removing the dual-path dispatch logic split.
- AskUserQuestion fan-out gate now applies to BOTH primary and fallback paths (was: fallback skipped the gate — degraded paths got less friction, not more, contradicting graceful-degradation principle).

### Fixed
- Fallback dispatch path no longer silently skips the user-cost-consent prompt at fan-out ≥4.

## [1.19.0] — 2026-05-19

### Added
- `check-trivia.sh` new detector kinds: `comment` (comment-only diffs ≤3 lines), `typo` (single-token substitution with length-diff ≤2), `untracked-newfile` (single new file ≤3 lines, all blank/comment/shebang). Fulfills CLAUDE.md P12 anti-corollary 4-axis coverage promise (T2-1).
- New `tests/test_check_trivia.sh` with 6 fixture-based AC tests (AC1..AC6).
- README §Trivia detector coverage subsection documenting all 5 kinds.

### Fixed
- Untracked single-file additions no longer fall through to full pipeline when they qualify as trivia (regression: previous `gd --name-only` did not see untracked files).
- `test_check_trivia.sh` `run_case`: added `trap RETURN` for tmpdir cleanup so a failing setup-fn under `set -euo pipefail` does not leak tmpdirs.

### Changed
- SKILL.md propagates `--paths` argument to `check-trivia.sh` so user-supplied scope is honored.
- `check-trivia.sh`: renamed diff-context `line_count` variable to `diff_line_count` so it does not shadow the untracked-newfile detector's physical-line-count variable. Behavior unchanged.
- `test_check_trivia.sh`: added comment documenting `$TRIVIA_ARGS` unquoted-by-design (word-split intended for multi-token args).

## [1.18.0] — 2026-05-19

### Added
- `DEVBREW_QG_NO_SIGNAL_MAX` (default 3, `0`=disabled) — stop-hook counter that prevents infinite re-injection when the model fails to emit `<qg-signal>` for N consecutive turns. New transition types `no_signal_inc` (silent increment) and `no_signal_max` (user-choice intercept) (T2-4).
- `compute_no_signal_transition(state, max_no_signal)` pure helper and `reset_no_signal(state)` helper for testability.

### Fixed
- `_persist_no_signal_counter`: wrap initial `open()` in `(IOError, OSError)` handler to match `update_state_file`'s established pattern.
- `compute_no_signal_transition`: ceiling-value semantics — `no_signal_max` branch now returns `new_count = cur` (not `cur+1`) so persisted and user-facing counter values agree.
- `main()` no-signal branch: mirror `new_count` into in-memory `state["consecutive_no_signal"]` before `build_special_prompt` so fmt rendering uses the post-increment count.

### Changed
- `setup-qg.sh`: state frontmatter adds `consecutive_no_signal: 0` initial field.
- `parse_state_file`: defaults `consecutive_no_signal` to 0 for backward-compat with v1.16.x state files.
- `USER_CHOICE_TYPES` set extended with `"no_signal_max"`; `build_system_message` user-choice branch updated.

## [1.17.0] — 2026-05-19

### Added
- `DEVBREW_QG_DEADLINE_MIN` (default 30 min, `0`=disabled) — pipeline wall-clock budget. main() 흐름에서 `deadline_exceeded(state, now=None)` pure helper로 검사 후 `wall_clock_exceeded` user-choice transition emit. CLAUDE.md `P18 anti-corollary` 4-가드 중 누락되었던 wall-clock 추가 (T2-3).

### Fixed
- Wall-clock budget no longer overrides terminal/self-acknowledging transitions: added `BUDGET_SKIPPABLE = frozenset({"abort", "complete", "wall_clock_exceeded"})` module constant; step 7.5 in `main()` consults it before re-injecting `wall_clock_exceeded`. Previous behavior caused unescapable loop once the deadline was past (T2-3 round 1 fix in `14dab3a`).
- `wall_clock_exceeded` prompt's "Accept partial" option now instructs the model to emit `<qg-signal action="complete" />` (was `gate="N" verdict="PASS_WITH_WARNINGS"`). The previous wording routed Accept-partial → `next_gate` on Gates 1/2, which step 7.5 re-overrode — second loop. Now Accept-partial finalizes the pipeline via `complete`, matching user intent ("stop spending more time; finalize as-is") (T2-3 round 2 fix in `e570780`).
- `setup-qg.sh` GNU `date -d` fallback now suppresses stderr and degrades gracefully to no-deadline mode if neither BSD nor GNU `date` variant works (loud-logging via stderr warning, no abort under `set -euo pipefail`).

### Changed
- `setup-qg.sh`: state frontmatter에 `wall_clock_deadline_at: "<ISO8601>"` 신설.
- `stop-hook.py`: `_SPECIAL_PROMPTS`에 `wall_clock_exceeded` entry, `USER_CHOICE_TYPES`에 동일 추가.
- `BUDGET_SKIPPABLE` promoted to module-level `frozenset` (was local set in `main()`); test fixtures import `stop_hook.BUDGET_SKIPPABLE` so any future divergence between production and test fails immediately.
- `USER_CHOICE_TYPES_FOR_HINT` aliasing removed — `USER_CHOICE_TYPES` is the single source.

## [1.16.0] — 2026-05-17

### Security
- `commands/cancel-qg.md`: `$CLAUDE_CODE_SESSION_ID`가 비어있거나 패턴이 깨졌을 때 `rm -rf ".claude/quality-gates/$SID"`가 plugin 루트(`. claude/quality-gates/`)로 expand되어 동시에 실행 중인 모든 세션 폴더를 wipe하는 catastrophic 경로를 차단. 모든 destructive Bash 블록에 `[[ -n "$SID" && "$SID" =~ ^[A-Za-z0-9_-]{8,}$ ]]` SID-pattern 가드를 강제 (LLM prose 가드 → 셸-level 가드 격상). `--all` 경로에도 `[[ -d ".claude/quality-gates" ]]` 존재 가드 추가. Origin: Tier 1 audit U-7. *Persona-as-security-code 트리거: 향후 cancel-qg 가드 약화는 security review 대상.*

### Changed
- `README.md` "인스턴스화한 원칙" 섹션의 AP-ID cite drift 수정. `AP3 (Trivia ceremony)` → `P12 anti-corollary (former AP5)` (AP3는 §11.1 migration table 상 *Self-Approval*, AP5가 *Trivia Pipeline Overhead*였음). `AP9` → `P22 anti-corollary (former AP9)`, `AP16` → `P18 anti-corollary (former AP16)`로 post-restructure cite style로 정렬. Trivia 항목엔 현재 coverage(whitespace+rename only)와 deferred 확장 추적을 명시. Origin: Tier 1 audit F-3.
- `README.md` `## 설정` 섹션을 `### Tuning knobs` + `### Kill switches (보안 컨트롤)` 두 subsection으로 재구성. 모든 component disable env var (`DEVBREW_DISABLE_QUALITY_GATES`, `DEVBREW_DISABLE_QG_CODEX`, `DEVBREW_DISABLE_QG_SECURITY_REVIEWER`, `DEVBREW_DISABLE_GATE3_TEST_VALIDATION`, `DEVBREW_QG_DISABLE_BRANCH_WORKTREE`) + 모든 hook 키 (`stop-hook`, `session-tracker`, `post-tool-use`, `session-start-advisor`, `session-start-advisor:frontmatter-scan`, `session-end-cleanup`, `gate3-test-scope`)을 표 형식으로 통합. CLAUDE.md *"kill switch는 보안 컨트롤"* 원칙 instantiation: 보이지 않는 보안 컨트롤은 컨트롤이 아님. Origin: Tier 1 audit U-3 + U-4.
- `agents/plan-verifier.md`, `agents/runtime-verifier.md`, `agents/test-scope-validator.md`: opening identity prompt에 *"You are NOT responsible for ..."* clause 추가. CLAUDE.md Plugin Shape > Component Isolation의 *"You are X. You are responsible for Y. You are NOT responsible for Z."* triad 완성. Z 절은 persona-as-security-code의 scope-creep 방지 lock — 향후 PR에서 이 문장이 weakened되면 security-review trigger. Origin: Tier 1 audit F-8.
- `skills/quality-pipeline/SKILL.md`: 1349줄 SKILL 상단에 `## Contents` TOC 추가 (Workflow / Per-gate dispatch logic / Output templates 세 그룹). CLAUDE.md `docs/**.md ~300줄 이상이면 TOC 필수` 규정 instantiation. Origin: Tier 1 audit A-12.

### Removed
- `hooks/stop-hook.py` + `skills/quality-pipeline/SKILL.md`: dead `extend` transition 제거. v1.5.0이 cross-gate restart 메커니즘을 삭제하면서 `extend` action은 effective no-op이 되었으나 (update_state_file에서 no replacements, main에서 `("continue", "extend")` 공동 분기) 코드와 docstring·signal example에 잔존. `compute_transition`의 `action == "extend"` 분기, `update_state_file`의 trailing comment, `main()`의 합쳐진 elif 분기, signal example (`<qg-signal action="extend" />`) 모두 제거. 테스트 영향 없음 (extend signal 참조하는 테스트 0개). Origin: Tier 1 audit A-9.

### Deferred (Tier 2/3 spec)
- 다음 항목은 별도 spec 파일 `docs/superpowers/specs/2026-05-17-qg-tier2-3-improvements-design.md`로 분리되어 다음 release cycle에서 처리:
  - **Tier 2 (correctness)**: trivia escape coverage 확장 (comment-only, `--paths` 전파, untracked single-file), scout fallback의 AskUserQuestion 게이트 우회 차단 + Phase 1 dual-dispatch 통합, pipeline wall-clock budget, stop-hook no-signal infinite re-injection counter, codex 미설치 시 loud logging, state-write 실패 시 forward-progress 경로 routing, README state-machine diagram, adversarial 비용 prompt 포함.
  - **Tier 3 (refactor)**: scout/synthesizer/codex-reviewer를 deterministic script로 (LLM 판단 없는 layer), 8개 에이전트 중 7개의 behavioral test backfill.

## [1.15.0] — 2026-05-17

### Added
- `/qg branch <name>` — 다른 브랜치를 격리된 detached worktree에서 검사하는 새 surface. 현재 작업트리 무손상.
- `scripts/qg-worktree.sh` — worktree 라이프사이클 헬퍼 (`sanitize` / `validate-branch` / `create` / `remove` subcommands).
- State file schema fields: `worktree_path`, `target_branch` (worktree 모드일 때만 frontmatter에 emit).
- `tests/test_qg_worktree_helper.sh` — 18 unit cases (sanitize 6 + validate-branch 3 + create 6 + remove 3).
- `tests/test_branch_worktree.sh` — 20 integration cases (AC1–AC11 from spec).
- `tests/test_stop_hook_worktree_cleanup.py` — 6 unit cases (complete/abort/KEEP/legacy + AC8 preservation).
- `tests/test_session_end_cleanup.py` — 2 new cases for dangling worktree safety net.
- Kill switches: `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1` (기능 차단), `DEVBREW_QG_KEEP_WORKTREE=1` (cleanup 차단).
- README "Recipes" 섹션 — PR 브랜치 검사 워크플로우 + worktree 보존/비활성화 가이드.
- Principles Instantiated 2 entries — Law 1 (7 rejection scenarios → AC1–AC11) + Law 3 (worktree path convention §4.8).

### Changed
- `scripts/setup-qg.sh`: `branch` 키워드 뒤 non-flag non-gate 토큰을 `<target-branch>`로 해석. 해당 모드에서 `qg-worktree.sh create`를 호출하고 state frontmatter의 `project_dir`을 worktree absolute path로 freeze. 새 토큰이 없으면 기존 `/qg branch` 동작 보존.
- `hooks/stop-hook.py`: terminal status (`complete`/`abort`) 분기에서 state의 `worktree_path` 존재 시 자동 cleanup (`DEVBREW_QG_KEEP_WORKTREE` 존중). non-terminal status에서는 보존 + stderr 안내 메시지로 사용자에게 worktree 경로 표시.
- `hooks/session-end-cleanup.py`: dangling worktree safety net — 세션 종료 시 state에 `worktree_path`가 있고 KEEP env가 미설정이면 `qg-worktree.sh remove` 호출.
- `commands/qg.md`: argument-hint 갱신 (`branch [<name>]`), Quick Reference에 `/qg branch <name>` 행 + 두 kill switch 환경변수 행 추가.

### Upgrade notes
- v1.14.x state file은 새 필드 `worktree_path` / `target_branch` 부재 → 기존 로직으로 fall through (stop-hook이 `state.get("worktree_path", "")` 빈 문자열 → cleanup 분기 미진입). Migration 없음.
- 기존 `/qg branch` (인자 없음) 동작 100% 보존 — argument-hint도 backward-compatible (`[branch [<name>]|...]`).
- v1.14.0의 worktree cwd contract (`project_dir` state frontmatter) 위에 올려짐. v1.14.0 미만에서 in-flight pipeline은 새 surface 사용 불가 (state schema 호환성 누락).

## [1.14.0] — 2026-05-16

### Added
- State file schema field `project_dir` (frontmatter) — single pipeline coordinate frozen at preflight (AC6, B6 fix).
- `project_dir` input contract on 6 Gate-2 agents: scout, codex-reviewer, adversarial, synthesizer, test-scope-validator, security-reviewer (AC2).
- `tests/test_hook_cwd_contract.py` — payload cwd contract for post-tool-use-session-tracker and session-start-advisor.
- `tests/test_worktree.sh` T5/T6/T7/T8/T9 — regression guards for SKILL dispatch, hook AST, codex-reviewer plugin paths, agent.md drift, state schema.
- `tests/test_codex_dispatch_invariant.sh` Scenario 4 — anchor-then-window awk for Pattern-P and Pattern-L dispatch blocks.

### Changed
- `hooks/stop-hook.py`: removed module-level `ROOT` constant; introduced `_state_root(hook_input)` helper deriving state path from payload cwd. `state_file_for(session_id, hook_input)` signature updated.
- `hooks/stop-hook.py:build_gate_prompt()`: all 3 gate branches now inject `project_dir: {state["project_dir"]}` into continuation prompts, ensuring gate-boundary cwd persistence.
- `hooks/stop-hook.py:parse_state_file()`: surfaces `project_dir` with v1.13.x backward-compat fallback (`os.getcwd()` + stderr warning, mirroring `gate3_resolution_iter` pattern at L114-120).
- `hooks/post-tool-use-session-tracker.py`: state path and `abs_path` resolution base both derived from payload cwd.
- `hooks/session-start-advisor.py`: `_scan_agent_frontmatter_keys` now takes payload arg and derives `repo_root` from payload cwd instead of `Path.cwd()`.
- `agents/codex-reviewer.md`: bash block guards empty `project_dir`, `cd "$project_dir"`, `REPO_ROOT="$project_dir"` (no more `git rev-parse`); plugin scripts called via `${CLAUDE_PLUGIN_ROOT}/scripts/` instead of `$REPO_ROOT/plugins/quality-gates/scripts/` (which only existed in devbrew's self-test).
- `skills/quality-pipeline/SKILL.md`: 4 Pattern-P dispatch blocks (scout/adversarial/synthesizer/test-scope-validator) and 1 Pattern-L block (Agent D security-reviewer) now declare `project_dir: <current working directory>` in their prompts.

### Fixed
- **B1**: stop-hook.py `ROOT` constant relative-path bug — state file path now derived from payload cwd (worktree-safe).
- **B2**: post-tool-use-session-tracker.py `Path(".claude/quality-gates")` relative bug + `abs_path` resolution against wrong base.
- **B3**: session-start-advisor.py `Path.cwd()` worktree blindness.
- **B4**: SKILL.md missing `project_dir` in dispatches to scout/codex-reviewer/adversarial/synthesizer/test-scope-validator/security-reviewer.
- **B5**: codex-reviewer.md (a) `$REPO_ROOT/plugins/quality-gates/scripts/...` path broken outside devbrew, (b) missing `cd "$project_dir"` causing subprocess cwd nondeterminism.
- **B6**: state file schema lacked `project_dir`; stop-hook `build_gate_prompt()` never propagated it across gate boundaries — caused gate2/3 continuations to re-evaluate cwd in main repo when pipeline was launched from worktree.
- **B3 completion**: session-start-advisor primary advisory path (sibling-count + self-pipeline check) now derives state root from payload cwd, matching the frontmatter-scan sub-feature fix.
- **B7 (new)**: session-end-cleanup.py removed module-level relative ROOT; per-session folder cleanup now anchored to payload cwd, eliminating silent state-leak when session ends with process-cwd different from worktree.

### Upgrade notes
- In-flight v1.13.x pipelines: state file lacks `project_dir`; `parse_state_file()` falls back to `os.getcwd()` + stderr warning. If your continuation is running from a worktree, expect one warning per gate transition. For clean state, run `/cancel-qg && /qg` after upgrade.
- No state-file format break: v1.13.x state files remain readable; v1.14.0 state files have one additional `project_dir:` line that older code would simply ignore.

## [1.13.0] — 2026-05-16

### Added

- **Phase 1 always-run `security-reviewer` agent.** Code-level security review now runs on every Gate 2 invocation (all 3 depth tiers: quick / standard / deep). Hunts injection, authn/authz bypass, secrets, SSRF + path traversal, insecure deserialization, cryptographic misuse, raw-HTML escape hatches, and dependency manifest changes. Emits canonical finding YAML schema (`adversarial.md:22-30`). Persona declares `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` for Law 2 physical isolation; `cost_class: medium`; `model: inherit`.
- **Kill switch `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`.** Mirrors codex-reviewer's `DEVBREW_DISABLE_QG_CODEX` pattern. Loud-logging graceful degradation: stderr emits `security-reviewer disabled via DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1` on activation; other Phase 1 reviewers continue to run.
- **Structural tests.** `tests/test_security_reviewer_persona.sh` (frontmatter + schema keyword + role declaration grep) and `tests/test_security_reviewer_kill_switch.sh` (SKILL.md kill switch reference grep).
- **Integration smoke fixtures.** `tests/fixtures/security-reviewer/{sql-concat,clean,expected}/` — opt-in, CI-non-blocking (LLM non-determinism).

### Changed

- **Phase 1 dispatch fan-out.** Phase 1 catalog grows by 1 (now: code-reviewer, silent-failure-hunter, feature-dev:code-reviewer, security-reviewer + conditional codex-reviewer). On `deep` depth with codex-reviewer available, `phase1_agents = 4` + `external_reviewers = 1` = 5, exceeding the AskUserQuestion fan-out gate (≥ 4) — users see an explicit confirm before parallel dispatch.
- **Synthesizer suppression rule (`synthesizer.md` step 4).** Was: "Suppress entries where confidence < 7." Now: "Suppress entries where confidence < 7 AND severity != CRITICAL." Honors spec §4.4 "P0 + anchor 50 always reports" — a critical-impact finding surfaces even at low confidence. Applies to all Phase 1 reviewers (not just security-reviewer). Output section label updated to `### Suppressed (confidence < 7, severity != CRITICAL)`.

### Security

- New `security-reviewer` persona file is security-sensitive code per CLAUDE.md ("Persona 파일은 보안-민감 코드"). PRs weakening hunt categories, lowering anchored confidence rubric, or removing the forced-findings prohibition rule require security review.

## [1.12.0] — 2026-05-14

### Added

- `tests/test_agent_frontmatter_keys.sh` — repo-wide agent frontmatter convention deny-list (AC15).
- `hooks/session-start-advisor.py` 에 frontmatter scan sub-feature 확장 + `_subfeature_disabled()` helper (AC14).
- `tests/test_consent_marker_write_failure.sh` (AC11 검증).
- `tests/test_codex_dispatch_invariant.sh` scenario 3 (AC13 fallback).
- `tests/fixtures/codex_findings_dict_input.json`, `codex_findings_string_input.json`, `codex_two_fenced_blocks.json` (AC9 fixtures).

### Changed

- `scripts/detect_codex.sh` — `codex --version` 호출을 `timeout 5` 로 래핑. 7번째 case `skip_reason: timeout_binary_missing` 추가 (AC7).
- `agents/codex-reviewer.md` agent body — TIMEOUT_CMD/REPO_ROOT empty 검사 + prompt builder exit-code 검사 (AC8/AC10).
- `README.md` — 디렉토리 트리에 codex 관련 4파일 추가, Gate 2 stage diagram에 codex-reviewer 노드, Fan-out 11→12, Principles Instantiated에 Law 2/Law 3 instantiation (AC16).
- `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` — 스크립트 파일명 dashes → underscores (AC17).

### Fixed

- `scripts/codex_findings_to_yaml.py`:
  - non-list findings → `meta.reason: schema_mismatch` + `meta.raw_findings_type` surface (silent coerce 종료) (AC9a).
  - `parse_fenced_json` last block 선택 (prompt injection 차단) (AC9b).
  - `AUTH_ERROR_RE` 확장: 401/403/forbidden/quota/expired 등 (AC9c).
  - stderr 읽기 실패 시 `meta.stderr_read_error: <errno>` (AC9d).
- `skills/quality-pipeline/SKILL.md`:
  - cost consent marker write 실패 시 stderr 메시지 — fenced bash block + `# QG-CONSENT-MARKER-WRITE` 식별 주석으로 V14가 추출 검증 가능 (AC11).
  - detect_codex.sh manifest schema validation (AC12).
  - scout-fallback 분기에서도 codex 가용 + consent 시 codex-reviewer dispatch + 명시적 stderr 메시지 (AC13).

### Notes

- Spec: `docs/superpowers/specs/2026-05-14-qg-codex-reviewer-recovery-design.md` (AC7–AC19).
- Audit: `docs/research/2026-05-14-pr33-pr32-retroactive-audit.md`.
- Law 2 instantiation: 3-layer reviewer-writer isolation (codex-reviewer)가 v1.11.1에서 복구된 후 v1.12.0에서 schema/auth/timeout 안전성 추가.
- Law 3 instantiation: agent frontmatter convention drift 재발을 차단하는 compounding mechanism (advisor + bash test) 신설.

## [1.11.1] — 2026-05-14

### Fixed

- `agents/codex-reviewer.md` frontmatter key를 `allowed-tools` (kebab-case) → `allowedTools` (camelCase) 로 수정. v1.11.0에서 Layer 2 isolation (narrow Bash whitelist)이 잘못된 키 때문에 실질적으로 비활성이었음. `tests/test_codex_reviewer_frontmatter.sh` 도 같은 잘못된 키를 검사하던 4 occurrences를 함께 수정.
- `agents/scout.md`에서 codex-reviewer dispatch instruction 제거. v1.11.0에서 scout이 `phase1_agents`에 codex-reviewer를 추가하면 SKILL.md validation FAIL → scout-fallback → codex-reviewer silently dropped 상태였음. dispatch 단일 진실은 SKILL.md로 이동 (manifest 가용성 + consent 기반).
- `skills/quality-pipeline/SKILL.md` Phase 1 dispatch logic: codex 가용 + consent OK 시 codex-reviewer를 in-process subagent 3개와 parallel dispatch에 무조건 포함. codex 미가용 시 v1.10.x byte-equivalent 3-agent dispatch 유지.

### Security

- 3-layer reviewer-writer isolation의 Layer 2 (`allowedTools` deny-list/allow-list narrow whitelist) 복구. v1.11.0의 광고된 보안 보장이 실제로 작동 시작.

### Notes

**SemVer 분류 근거**: v1.11.0의 codex-reviewer dispatch는 C1+C2 결함으로 인해 production에서 실제로 작동하지 않았음 — 본 PR의 "scout codex emit 제거"는 SemVer 의미상 "deprecation of never-working behavior" 이므로 backward-incompatible 변경 아님. devbrew CLAUDE.md "one-minor deprecation window" 요건은 본 케이스에 적용되지 않음.

Audit findings: `docs/research/2026-05-14-pr33-pr32-retroactive-audit.md` (C1, C2, I-부분).
Spec: `docs/superpowers/specs/2026-05-14-qg-codex-reviewer-recovery-design.md` (AC1–AC6).

## [1.11.0] — 2026-05-14

### Added

- `codex-reviewer` agent: independent code reviewer dispatched as a separate process via `codex exec --json -s read-only` when Codex CLI is detected. Adds OS-process + model-family separation to QG Gate 2 Phase 1, strengthening Law 2 (writer-reviewer physical separation).
- `scripts/detect_codex.sh`: 6-case probe (not_installed, kill_switch, inside_codex_sandbox, auth_missing, known_bad_version, ok). Read-only, exit 0 always. Known-bad version regex covers Codex CLI 0.120.0-0.120.2 (stdin deadlock bug).
- `scripts/codex_findings_to_yaml.py`: JSONL stream parser with 3-stage fallback chain (fenced JSON → raw JSON → malformed_json). Handles both Codex 0.130+ nested `item.completed` event shape and legacy top-level `agent_message` shape. Includes stderr capture for `auth_error_in_stderr` (Codex exit 0 + auth failure pattern). Supports `--meta-override-exit-code` and `--meta-override-reason` flags for agent-side timeout/exit-nonzero classification.
- `scripts/build_codex_prompt.py`: safe prompt construction — reads inputs from file paths, substitutes via `str.replace` with no shell/Python literal injection vector.
- First-use cost consent gate: `AskUserQuestion`-based prompt with marker file at `~/.claude/quality-gates/codex-cost-consent.md`. Silent after first approval. Test harness uses `QG_MOCK_ASKUSER_PATH` env var for deterministic verification.
- Kill switch: `DEVBREW_DISABLE_QG_CODEX=1` disables codex-reviewer globally.
- Task 0 prompt-engineering spike (`tests/spike/`) — empirically validated codex emits fenced JSON in `agent_message` ≥2/3 runs. Frozen sample (`fixtures/codex_jsonl_sample.json`) serves as regression anchor against future codex event-schema drift.

### Changed

- `agents/scout.md`: dispatch input now includes `codex_manifest` (backwards-compatible — when `codex_available: false`, Phase 1 dispatch list is unchanged from prior behavior).
- `skills/quality-pipeline/SKILL.md`: Gate 2 Phase 0 prerequisite now runs `detect_codex.sh` and synthesizes the manifest into Scout's input. Cost consent gate fires between probe and Scout dispatch.

### Security

- 3-layer reviewer-writer isolation for codex-reviewer agent:
  1. Frontmatter `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit, Glob]`
  2. Frontmatter `allowed-tools` narrow Bash whitelist (no `Bash(cat *)` — prevents redirection bypass)
  3. `codex exec -s read-only` OS-level sandbox
- Closed prompt-injection vector during Task 4 review: agent body now writes inputs to scratch files via single-quoted heredocs (`<<'EOF'`) and substitutes via Python `str.replace` on file paths — adversarial PR content (e.g., `"""` in diff text) cannot escape into outer agent execution.

### Notes

- Bumps QG Gate 2 max parallel fan-out from 11 → 12 (deep depth with codex-reviewer in Phase 1 + all Phase 2 specialists). Still within declared fan-out regime.
- AC7 (backward-compat regression) is verified structurally (probe + scout-rule + existing test suite) rather than via synthesizer baseline diff. See `tests/fixtures/baseline_capture_README.md` for the deferral rationale.
- Spec: `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` v3.1 (3 rounds adversarial review, 29 issues addressed).

## [1.10.0] — 2026-05-13

### Changed
- **SKILL.md prose** aligned with the v1.5.0 forward-only state machine. Five
  sites in `skills/quality-pipeline/SKILL.md` had carried the pre-1.5.0
  "auto-restart from Gate 1" vocabulary; they now describe the actual
  Stop-hook behavior (user-choice prompt; user re-runs `/qg`).
- **`GATE3_FAIL` prompt option 1 label** is now `"Fix and re-run /qg"`
  (was `"Fix issues (will restart from Gate 1)"`). User-visible string
  change; semantics already matched the new label since v1.5.0.
- **Example history log** in `references/state-file-format.md` no longer
  shows `Restarting from Gate 1 (iteration 2)` — replaced with the
  forward-only termination line.

### Removed
- **`total_iterations` / `max_total_iterations`** state-file fields. Deprecated
  in v1.5.0, never written since, and (discovered during this cleanup) the
  `extend` branch in `update_state_file` that incremented `new_max_total`
  was already a dead write because `max_total_iterations` had been absent
  from the `replacements` dict for a year. Removed from `parse_state_file`,
  `update_state_file`, schema doc, and three fixture files. The
  `test_no_max_total_iterations_constant` gate test is preserved.

### Fixed
- **Doc-vs-code drift**: SKILL.md verdict definitions, GATE3_FAIL prompt,
  and Gate 2 output format no longer mis-instruct reviewers that the
  pipeline auto-restarts from Gate 1. Locked by the new
  `tests/test_forward_only_prose.sh` grep guard (AC1–AC8 + NG7,
  8 assertions, exit 0 on PASS).
- **Stale comment in `main()` extend branch** (`# State file already
  updated with new max`) replaced with an accurate description: the prior
  `new_max_total += additional` was a silent no-op since v1.5.0 because
  `max_total_iterations` was never in the replacements dict. Caught during
  Task 3 code review; CLAUDE.md Law 3 compounding.

### Internal
- **`build_special_prompt`** refactored from a 6-case if/elif ladder
  (~146 LoC) to a module-level `_SPECIAL_PROMPTS` per-case dict + a 43-line
  dispatcher. Semantics preserved; locked by `tests/test_stop_hook_unit.py`
  (5 invariants: exact case-tag header prefix, length > 200, `<qg-signal`
  ≥ 2 directives, abort option present, exact `PIPELINE_ERROR\n\n`
  prefix on unknown transitions).
- **`main()` transition-handler** collapses 4 duplicated
  `print(json.dumps({...})); sys.exit(0)` blocks into a single
  `emit_continuation` helper called after a small prompt-selector
  dispatch. Handler block shrank ~73 → ~51 LoC (-22).
- **`hooks/stop-hook.py` LoC**: before 960, after 964. The spec's
  ≤ 800 target turned out to be over-optimistic — the `_SPECIAL_PROMPTS`
  dict for 7 cases is roughly as long as the original if/elif ladder
  (data encoding doesn't compress over branches). The realistic floor
  for D1+D2+D3 was ~950–960. The substantive win is structural (one
  source of truth per case, unified trailer) and the unit-test net
  protects against future drift, not raw LoC.

### Notes
- Stop-hook itself remains. The spec's "Stop-hook review" section enumerates
  6 responsibilities (turn-boundary auto-progression, multi-turn Gate 2
  fix-loop, user-choice prompt injection, state-file management, repeat-
  detection invariant, mid-session cleanup); none can be moved into the
  skill without losing automatic continuation or the code-enforced
  AP15 *"loop without repeat detection"* guard. The user-prompted
  re-evaluation ("이제와서는 stop hook이 반드시 필요할지도 검토해봐")
  is preserved in the spec's §Context for future readers.

## [1.9.0] — 2026-05-12

### Added
- **Gate 3 Step 2.5 — Test scope validator** (informational, non-blocking).
  New `test-scope-validator` agent classifies scope-relevant test files as
  `aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear`
  before `runtime-verifier` executes them. Surfaces silent failure modes
  (outdated tests against post-refactor behavior; tautological assertions
  added for coverage padding) without blocking Gate 3.
- `scripts/compute-test-scope-candidates.sh` — deterministic candidate
  resolver (Python/JS/TS heuristic src→test mapping + changed-test fallback).
- `agents/test-scope-validator.md` — read-only agent with `Write`/`Edit`
  disallowed (Law 2 3-way separation: writer / test-scope-validator /
  runtime-verifier).
- `tests/test_compute_test_scope_candidates.sh`, `tests/test_test_scope_validator_frontmatter.sh`
- `tests/fixtures/test-scope/{aligned,outdated,cherry-pick}/` — reference
  fixtures for manual verification.

### Changed
- `skills/quality-pipeline/SKILL.md` — Gate 3 gained Step 2.5 between
  Step 2 (Upfront resolution) and Step 3 (Dispatch runtime-verifier).
  Existing verdict model and stop-hook continuation prompts unchanged.

### Environment
- New: `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1` — skip Step 2.5 entirely.
- New: `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope` — alternate kill
  switch (consistent with existing skip-hook pattern).

## [1.8.1] — 2026-05-12

### Added
- **Worktree regression guards** (`tests/test_worktree.sh`, `tests/test_isolation.sh`): hermetic mktemp-based tests that lock in qg's PWD-relative state-path contract — the structural property that makes git-worktree isolation work without any worktree-specific code in the plugin. `test_worktree.sh` (10 assertions) verifies setup/discover/trivia/pre-check all read worktree-local context and never leak into the origin repo's `.claude/`. `test_isolation.sh` (11 assertions) verifies bidirectional isolation under a shared session ID (worktree ↔ origin), distinct-inode property of the two pipeline.md files, and that two concurrent sessions in the same directory remain independent. These tests will fail if anyone introduces `git rev-parse --git-common-dir` / `--show-toplevel`-rooted state paths, which would silently break worktree isolation.

## [1.8.0] — 2026-05-11

### Added
- **Pre-flight runtime detector** (`scripts/detect-runtime.sh`): `project_type`, `runnable_surfaces` (docker-compose / npm-script / pytest / cargo / go / makefile), `test_runners`, `mcp_browser` (chrome-devtools / playwright / none), `app_url_candidates`, `env_status`, `plan_features` (`PLAN_PATH` env에서 추출) 를 YAML manifest로 산출하는 결정적 bash script. read-only.
- **Fast-path SKIP_WITH_EVIDENCE**: detector가 runnable_surfaces / test_runners / plan_features 모두 비어있다고 보고하면 Gate 3가 agent dispatch 없이 즉시 SKIP_WITH_EVIDENCE emit (token cost = 0).
- **Mid-run NEEDS_RESOLUTION escalation**: agent가 fixable한 missing resource에 대해 사용자 해결을 요청 가능. Skill이 3자 ping-pong (skill ↔ user ↔ agent)을 AskUserQuestion 으로 중재. `max_gate3_resolutions` (기본 3) 으로 묶임.
- **`DEVBREW_GATE3_MAX_RESOLUTIONS` env override** (0..10 clamp). `0` 으로 설정 시 mid-run escalation 비활성화 (Approach 2 mode — 첫 NEEDS_RESOLUTION 이 바로 `gate3_fail` transition 으로 가서 user에게 fix/skip/abort 선택 제시).
- **Repeat detection** (`needed_hash` 기반): 같은 missing resource가 2회 연속이면 `gate3_repeat_detected` → user choice (proceed_with_warnings / abort).
- **Evidence-log validation** (skill 측): manifest의 모든 항목이 attempted entry를 가져야 함; 누락된 항목이 있으면 SKIP_WITH_EVIDENCE 를 자동 FAIL 로 격상.
- **Fixture 기반 테스트**: 4개 fixture (web-compose / web-example-only / library-tests / markdown-only), `tests/test_detect_runtime.sh` 의 30+ assertion, `TestGate3ResolutionState` 의 10+ 신규 state-machine 테스트, frontmatter lint 테스트, secret-leakage regression 테스트 (AC12 / P21).

### Changed
- **`runtime-verifier.md` 재작성 (v2)**:
  - Frontmatter 가 `allowedTools: [Read, Bash, Grep, Glob, mcp__plugin_chrome-devtools-mcp_*]` 와 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 명시 — CLAUDE.md Plugin Shape "default-everything 금지" 위반 fix.
  - `cost_class: variable` (기존 `low` 에서 변경 — iteration loop 가능).
  - Body: manifest-driven attempt 흐름, evidence-log 작성 의무, 4-verdict 체계 (PASS / FAIL / SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION), secret 값 요청 금지 P21 guard 명시.
- **SKILL.md Gate 3 섹션** 6 단계 재작성 (detect → fast-path → upfront resolution → dispatch → evidence validation → NEEDS_RESOLUTION).
- **stop-hook.py**: 신규 transition `gate3_needs_resolution`, `gate3_repeat_detected`; 신규 state field `gate3_resolution_iter`, `max_gate3_resolutions`, `last_gate3_needed_hash`. 기존 `SKIP` verdict 는 그대로 `complete` 로 라우팅 (back-compat); `SKIP_WITH_EVIDENCE` 와 `PASS_WITH_WARNINGS` 가 같은 complete-bucket 에 합류.

### Fixed
- **Gate 3 의 silent SKIP regression**: 이전엔 project type detection fall-through (`package.json scripts.dev` 없음, `manage.py` 없음) 시 silently `unknown` → SKIP 으로 빠지면서 user 에게 알림이 없었음. 이제 evidence-required SKIP 이 이 경로를 거부; skill 이 fast-path SKIP (evidence log 동반) 으로 처리하거나 incomplete attempt 를 FAIL 로 격상.
- **chrome-devtools MCP under-utilization**: 이전엔 agent 가 사용 가능한 browser MCP tool 을 runtime keyword search 로 발견해야 했음. 이제 detector 가 `mcp_browser: chrome-devtools | playwright | none` 을 manifest 에 결정적으로 inject.

## [1.7.0] — 2026-05-10

### Added
- **Project-local plan discovery** (`scripts/discover-plan.sh`): Gate 1 plan-verifier가 `docs/superpowers/plans/` (superpowers:writing-plans 의 기본 저장 경로)을 1순위로, `~/.claude/plans/`를 legacy fallback으로 consult. 이전에는 `~/.claude/plans/`만 봐서 superpowers 워크플로우로 만든 plan이 항상 SKIP 되거나 옛 plan을 false-match 하던 버그 fix.
- **`Source` 필드** Gate 1 report에 추가 — 어떤 source(explicit / project-local / legacy-global)에서 plan을 가져왔는지 사용자가 즉시 인지 가능.
- **단위 테스트 10 개** (`tests/test_discover_plan.sh`): 양쪽 source 비어있음, project-local 우선, legacy fallback, non-plan 파일 필터, explicit override, mtime tiebreaker, `--plan` 인자 누락 regression(T10) 등 매트릭스 커버.

### Changed
- Discovery 알고리즘이 `agents/plan-verifier.md` prose 안의 자유서술에서 결정적 bash script로 이동. 미래 source 추가도 회귀 없이 가능. (Law 2 정신 — agent 자유서술 vs script contract.)
- Legacy source (`~/.claude/plans/`) 사용 시 `agents/plan-verifier.md`가 `⚠️ Legacy plan source ... Consider migrating ...` 1줄 deprecation 경고를 report 헤더 직전에 emit. project-local hit이면 silent.
- README "Principles Instantiated" 섹션에 Law 3 cross-plugin compounding 항목 추가 — `superpowers:writing-plans`의 출력 위치를 sister-plugin contract로 명시.
- `discover-plan.sh`가 `plan_path` 필드를 절대 경로로 emit (Task 2 fix). agent의 `Read` 호출이 cwd와 무관하게 작동.

### Fixed
- **Path mismatch (Gate 1 SKIP/false-match bug)**: `superpowers:writing-plans` 가 `docs/superpowers/plans/` 에 plan을 저장하는데 plan-verifier 는 `~/.claude/plans/`만 스캔해서 (a) 사용자의 최신 plan을 찾지 못하거나 (b) `~/.claude/plans/` 의 옛날 무관한 plan을 잘못 verify 하던 문제. 1.7.0 부터 priority 기반 discovery 로 정확히 매칭.
- **`--plan <missing>` 무한 루프**: `discover-plan.sh --plan` (path 인자 누락) 시 `shift 2` 실패가 silent하게 묵살되어 무한 루프에 빠지던 corner case. `[[ $# -lt 2 ]]` 가드 + exit 2 처리 + T10 regression test.

## [1.6.3] — 2026-05-10

### Fixed
- **Step 0 review-range fallback** (skill `quality-pipeline`): 작업 트리가 깨끗할 때(모두 commit됨) 기존 bash block은 빈 `git diff`로 fall-through해 review 대상이 0줄이 되던 문제. 이제 working tree가 dirty면 unstaged diff(기존), clean이면서 `main..HEAD`에 commit이 있으면 자동으로 `main...HEAD` 누적 branch diff로 전환. 6개의 `git diff` 호출 모두 통일된 `$REVIEW_RANGE`를 사용. (qg self-review §5.1 — v1.6.2 dogfood에서 발견)
- **Test detection regex**: `^tests?/`가 top-level `tests/`만 매칭해 nested `<sub>/tests/` (monorepo / plugin marketplace 구조)에서 `test_change=0` false negative 발생. `(^|/)tests?/`로 변경 — top-level + nested 모두 매칭.
- **`set -e` 제거 (Step 0 bash block)**: 모든 명령이 이미 `|| true` / `|| echo 0`으로 실패 처리하고 있어 `set -e`는 redundant했고, subshell command substitution과 상호작용하면서 fix-loop iteration에서 silent abort 유발. 제거 후 각 명령의 failure mode가 local + 예측 가능.

### Changed
- Step 0 JSON output에 `review_range` 필드 추가 — 어떤 모드(unstaged / `main...HEAD`)로 review됐는지 사용자가 보이도록.

## [1.6.2] — 2026-05-10

### Fixed
- v1.6.1의 kill switch fix가 5개 hook 중 3개만 다룬 상태였음 — `session-start-advisor.py`와 `session-end-cleanup.py`는 글로벌 `DEVBREW_DISABLE_QUALITY_GATES=1`만 honor하고 per-hook `DEVBREW_SKIP_HOOKS=quality-gates:<key>`을 무시했음. 두 hook 모두 `_disabled()`에 SKIP_HOOKS 체크 추가 (skip key: `quality-gates:session-start-advisor`, `quality-gates:session-end-cleanup`). 이제 README의 "All hooks honor..." 약속이 5/5 hook에서 코드로 지켜짐.
- **CRITICAL — substring prefix collision**: 5개 hook 모두 `_disabled()`에서 raw `"quality-gates:<key>" in skip` 형태의 substring match를 사용해, 사용자가 `DEVBREW_SKIP_HOOKS=quality-gates:post-tool-use-session-tracker`을 설정하면 (script filename을 key로 잘못 사용한 자연스러운 실수) `quality-gates:post-tool-use`가 그 안에 prefix로 포함되어 `post-tool-use.py`도 함께 silently 비활성화됨. 5개 hook 모두 whole-token match로 변경 — `skip.split(",")` 후 `t.strip()`된 토큰 set에 정확히 매칭. CLAUDE.md "kill switch는 보안 컨트롤" 규정의 contract 위반 fix. (Gate 2 pipeline review에서 발견)

### Added
- `tests/test_kill_switches.py` 회귀 테스트: 5개 hook 모두에 대해 글로벌 + per-hook + CSV 형태 SKIP_HOOKS가 side effect를 차단하는지 검증. side effect 검출은 hook별로 differentiated (state mutation / `systemMessage` injection / `files.md` 생성 / advisor stdout / 폴더 삭제). sanity test로 *kill switch 없을 때* setup이 실제로 side effect를 일으키는지도 검증해 trivial pass 방지.
- `test_per_hook_skip_does_not_cross_contaminate` — 위 substring prefix collision 회귀 가드. `DEVBREW_SKIP_HOOKS=quality-gates:post-tool-use-session-tracker` 설정 시 `post-tool-use.py`가 *여전히* 작동(`systemMessage` emit) 확인.
- `test_all_hooks_declare_kill_switch_strings` — `hooks/*.py`를 동적으로 enumerate해서 각 파일에 `DEVBREW_DISABLE_QUALITY_GATES`와 `DEVBREW_SKIP_HOOKS` 문자열이 모두 존재하는지 source-text static check. 새 hook이 `HOOK_CONTRACTS` static list에 추가되지 않은 채 kill switch 없이 ship되는 회귀 패턴(v1.6.1, v1.6.2의 동일 원인)을 merge time에 잡음.
- `_assert_no_side_effect`의 stop-hook assertion에 `proc.stdout.strip() == ""` 추가 — 기존엔 `pipeline.md` 미변경만 체크해 `_disabled()`가 silently broken되어도 통과했음 (no-signal stop-hook 정상 path도 pipeline.md를 변경하지 않으므로). stdout 체크가 두 path를 discriminate.
- sanity test의 stop-hook 분기를 bare `pass`에서 `assertIn("decision", proc.stdout)`로 교체 — sanity test가 stop-hook에 대해서도 진짜 차이를 검증.

## [1.6.1] — 2026-05-10

### Fixed
- **CRITICAL**: `stop-hook.py`와 `post-tool-use.py`에 `DEVBREW_DISABLE_QUALITY_GATES=1` 및 hook 단위 `DEVBREW_SKIP_HOOKS=quality-gates:<hook>` kill switch 누락. README는 "All hooks honor..."를 보장하지만 두 hook은 환경변수를 무시하고 fire하던 상태. CLAUDE.md "kill switch는 보안 컨트롤" 규정 위반 fix. fail-closed 패턴(부수효과 발생 전 `sys.exit(0)`)으로 main() 진입점 최상단에 추가.
- README "Principles Instantiated" 섹션의 stale 문구 *"once that file lands on `main`"* 제거 — `docs/philosophy/devbrew-harness-philosophy.md`는 이미 main에 있음.

### Changed
- `README.md`를 Korean-primary로 재작성. CLAUDE.md "Korean-primary, English-terms-only" 정책 적용 (식별자·고유명사·원문 인용·번역 어색한 기술 용어에만 영어 허용).
- `CHANGELOG.md`를 Korean-primary로 재작성. 기존 영문 prose를 한국어로 번역, Keep a Changelog 섹션 헤더(Added/Changed/Fixed/Security 등)는 컨벤션상 영어 유지.

### Removed
- `README.ko.md`와 `CHANGELOG.ko.md` 동반 파일 삭제. CLAUDE.md "`*.ko.md` 동반 파일 모델은 폐기 (drift 비용 > 이중 노출 가치)" 규정 적용.

## [1.6.0] — 2026-05-08

### Added
- SessionEnd hook (`session-end-cleanup.py`) — 정상 종료 시 per-session state cleanup.
- `scripts/qg-gc.py`: `fcntl` lock + double-stat ns race guard + rename-then-rmtree로 보호된 TTL 기반 GC 헬퍼.
- 환경변수: `DEVBREW_QG_TTL_HOURS` (기본 24), `DEVBREW_QG_GC_VERBOSE` (기본 off).
- `/cancel-qg --gc` (TTL sweep)와 `/cancel-qg --all` (active sibling 리스트 + confirm 후 전체 wipe).
- `/qg --gc` flag — 명시적 GC 호출.
- `setup-qg.sh --session-id <id>` 인자 — `CLAUDE_CODE_SESSION_ID` env var 미설정 시 fallback.
- `post-tool-use.py`를 `hooks.json`에 PostToolUse(Bash) hook으로 등록 (이전엔 orphan 상태).

### Changed
- state 위치를 flat `.claude/quality-gates*.local.md` (5 파일)에서 per-session `.claude/quality-gates/<session-id>/{pipeline,files,branch}.md` + `{diff-cache,code-paths}` 로 이동.
- `session-start-advisor.py`가 이제 현재 세션만 scope하고 read-only (CLAUDE.md "SessionStart never mutates" 룰).
- `setup-qg.sh`가 `CLAUDE_CODE_SESSION_ID`도 `--session-id`도 없으면 hard-fail.
- `setup-qg.sh`가 시작 시 `qg-gc.py` 호출 (best-effort; 실패해도 setup은 abort 안 함).
- `/qg --reset`이 현재 세션 폴더 + legacy v1.5.0 파일을 wipe (이전엔 flat 파일만).
- README "Principles Instantiated": P21 mis-citation을 P5 (Filesystem as Memory) + P14 (State Survives Compaction) + §4.8 (State File)로 정정. state 파일 룰은 P21 (Security & Supply Chain)에 속한 적이 없음.

### Fixed
- 같은 프로젝트의 동시 세션이 더 이상 서로의 state를 corrupt하지 않음 (이전엔 5개 공유 `.claude/` 파일).
- crash/close된 세션의 stale state가 무관한 새 세션에서 misleading "in-flight pipeline" advice를 트리거하지 않음.
- `post-tool-use.py`의 "active pipeline" 체크가 호출 세션만 scope (이전엔 어느 세션의 파이프라인이라도 auto-trigger를 차단).

### Removed
- flat per-project state file 모델. 5개 legacy 파일(`quality-gates.local.md`, `quality-gates-session.local.md`, `quality-gates-branch.local.md`, `qg-diff-cache.txt`, `qg-code-paths.tmp`)은 upgrade 후 첫 `/qg` 실행 시 stderr 경고와 함께 unlink.

### Migration
- `session-start-advisor`가 legacy 파일 발견 시 일회성 stdout 메시지 (read-only — 절대 삭제 안 함).
- in-flight v1.5.0 파이프라인은 자동 마이그레이션되지 않음. 이전 session_id는 그 prior 세션에만 의미가 있으므로, `/qg` 재실행.

## [1.5.0] — 2026-04-30

### Added
- Phase 0 `scout` agent: Sonnet, 모델 기반 Gate 2 dispatch planner. 필터링된 diff + Gate 1 summary를 읽어 구조화된 YAML dispatch plan (depth + phase1_agents + phase2_agents + rationale)을 생성.
- Phase 1.5 `adversarial` agent: Opus, Phase 1+2 finding의 false-positive 사냥 (confirm/downgrade/reject 판정). 노이즈에 의한 fix-loop 반복을 줄이며 리뷰를 강화.
- Phase 1.6 `synthesizer` agent: Sonnet, finding을 dedupe/rank (severity × confidence), confidence < 7 suppress, 사용자에게 보일 prioritized Markdown 산출.
- `PostToolUse` hook `post-tool-use-session-tracker.py`: Edit/Write/MultiEdit 파일 경로를 `.claude/quality-gates-session.local.md`에 누적해 `/qg` scope을 좁힘.
- `SessionStart` hook `session-start-advisor.py`: 변경 없는 read-only advisor — in-flight 파이프라인을 알림 (CLAUDE.md hook coexistence 룰 준수).
- `/qg branch`, `/qg --paths <glob>`, `/qg --reset` flag 지원.
- pipeline skill과 모든 신규 agent에 `cost_class` 선언.
- Trivia escape (`scripts/check-trivia.sh`): 단일 파일·≤3줄 whitespace/rename 시 파이프라인 전체 자동 skip.
- Docs 필터 (`scripts/filter-docs.sh`): `*.md` / `docs/**` / `CHANGELOG*` / `README*`을 코드 reviewer scope에서 제외 (Gate 1 plan-verifier는 raw diff를 그대로 봄).
- Repeat-detection: 두 iteration 연속으로 scout dispatch plan + synthesizer 출력이 동일하면 `gate2_repeat_detected` user choice 발동 (philosophy AP15 인스턴스화).
- Gate 1 → Gate 2 핸드오프 포맷: 구조화된 `gate1_summary` YAML 블록; FAIL 시 Gate 2 진입 차단 (Law 1).
- Phase 1+2 dispatch 수가 ≥4일 때 AskUserQuestion hard gate (philosophy AP9 인스턴스화).
- Pre-pipeline check (`scripts/pre-pipeline-check.sh`): 세션 라이프사이클 처리 (active resume / branch mismatch / staleness / fresh start).
- `tests/` 신규 테스트: `test_session_tracker.py` (7), `test_session_start_advisor.py` (10), `test_stop_hook_state_machine.py` (6).

### Changed
- 기본 review scope이 풀 브랜치 diff가 아니라 **현재 Claude Code 세션에서 편집한 파일들**로 변경. 기존 동작은 `/qg branch`로 사용.
- Gate 2 Phase 1 fan-out이 scout의 plan에 따라 depth별로 다름 (1 / 2 / 3 agent; 더 이상 항상 3개 아님).
- Gate 2 내부 fix-loop이 매 iteration마다 delta diff (이전 iter 이후 변경된 파일만)로 scout을 재실행.
- `total_iterations`와 `max_total_iterations`는 더 이상 `setup-qg.sh`가 작성하지 않음; `stop-hook.py`는 stale state 파일 호환을 위해 읽기만 함.
- 시스템 메시지 포맷 갱신: `iter N/M`은 Gate 2만 표시; 다른 게이트는 게이트 이름만 표시.

### Removed
- **Cross-gate restart 루프**: Gate 2 / Gate 3 `NEEDS_RESTART`가 더 이상 Gate 1으로 자동 재진입하지 않음. user-choice prompt ("변경을 적용하고 /qg 재실행")로 종료.
- `MAX_TOTAL_ITERATIONS` 상수와 `restart` transition을 `stop-hook.py`와 `setup-qg.sh` 양쪽에서 모두 제거.
- SKILL.md의 룰 기반 `SCOPE_*` env-var Phase 2 게이팅 제거 (scout의 `phase2_agents` 필드로 대체; scout 실패 시 fallback으로 레거시 코드 유지).

### Fixed
- Gate 1 plan-verifier 출력 포맷 표준화: 구조화된 `gate1_summary` YAML 블록 필수 (이전엔 자유 산문). 결정론적 Gate 2 dispatch 가능.
- Stop-hook state machine: `compute_transition`을 top-level 순수 함수로 추출 (이전엔 `main()` 안에 inline). 단위 테스트 가능.

### Security
- 모든 신규 reviewer agent (`scout`, `adversarial`, `synthesizer`)가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언 (Law 2 강제).

## [1.4.0] — 이전

- Gate 2 orchestration을 `quality-pipeline` skill 안으로 이동 (PR #14).

## [1.3.0] — 이전

- Stop-hook 기반 파이프라인 진행 + Gate 2 토큰 절감 (PR #12).

## 그 이전

- 초기 Stop-hook 기반 파이프라인 (PR #10), 시그널 검출 수정 (PR #11).
